// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// Progress callback for long-running word-cloud computation: `(documents
/// processed, total documents)`. Invoked from the service's actor; handlers that
/// touch UI state must hop to the main actor themselves.
typealias WordCloudProgress = @Sendable (Int, Int) -> Void

/// Computes word-cloud frequency data for a body of FRUS material.
///
/// This is the inverse of `CorpusAnalyticsService`: instead of "how many
/// documents match this term?", it answers "what are the most frequent terms in
/// this set of documents?". Both share the same caching idiom and the `TermCount`
/// result type.
///
/// ## Pipeline
/// 1. Resolve the scope to a set of `WordCloudDocumentKey` (bounded scopes are
///    resolved by the caller and passed in; `.corpus` is enumerated here).
/// 2. Fetch each document's `body_text` from the index in chunks.
/// 3. Tokenise and lemmatise via `WordCloudTokenizer`, dropping stopwords.
/// 4. Tally counts and return the top-N as descending `TermCount`s.
///
/// Results are cached in memory keyed by `(scope signature, limit, stopword
/// policy)`, bounded by a small LRU, and flushed by `invalidateCache()` when the
/// index changes — called by `AppState.connectIndexingProgress` on each volume's
/// `.complete` event and by `ResetService` after the index is cleared. Corpus
/// computation can be long-running; callers should invoke it from a cancellable
/// background `Task` and show progress.
///
/// Version history:
///   1.0 — Word Cloud feature: initial implementation
///   1.1 — Word Cloud fixes: `invalidateCache()` is now actually wired to indexing
///          completion and reset (the in-memory key has no index fingerprint, so
///          nothing else evicts results computed against a since-changed index)
///   1.2 — #1373: every result carries the tagger verdict it was counted under
///          (`WordCloudResult.languageAnalysis`); the disk cache neither stores a result whose
///          tagger failed its lens nor reuses one that does not say
///   1.3 — #1421 review: every result also carries the installed index version its text was read
///          at (`WordCloudResult.indexVersion`), and the disk cache reuses one only while that is
///          still the installed version — a re-index that rewrites every body keeps the count the
///          key fingerprints
actor WordFrequencyService {

    // MARK: - Dependencies

    private let pipeline: IndexingPipeline

    // MARK: - Cache

    private var cache: [String: WordCloudResult] = [:]
    private var cacheOrder: [String] = []
    private let cacheLimit = 24

    /// Documents fetched and tokenised per chunk when folding a large scope, kept
    /// modest so peak memory stays bounded even for the whole corpus.
    private let chunkSize = 400

    // MARK: - Init

    /// Creates the service.
    /// - Parameter pipeline: The indexing pipeline providing document text.
    init(pipeline: IndexingPipeline) {
        self.pipeline = pipeline
    }

    // MARK: - Cache Management

    /// Flushes all cached word-cloud results. Call after the index is modified —
    /// wired to `AppState.connectIndexingProgress`'s per-volume `.complete` event
    /// and to `ResetService.resetLocalData()`. Only the in-memory cache needs this:
    /// the disk cache keys itself on an index fingerprint, and reuses an entry only while the
    /// entry's own `indexVersion` stamp is the installed index version (#1421 review).
    func invalidateCache() {
        cache.removeAll()
        cacheOrder.removeAll()
    }

    // MARK: - Queries

    /// Top terms for a bounded scope whose document keys are already resolved.
    ///
    /// - Parameters:
    ///   - signature: The scope's stable cache signature (`WordCloudScope.signature`).
    ///   - keys: The documents whose text feeds the cloud.
    ///   - limit: Maximum number of terms to return.
    ///   - includeDiplomaticStopwords: When `true`, FRUS-boilerplate words are
    ///     excluded in addition to the always-on English stopwords.
    ///   - extraStopwords: Additional per-scope terms to exclude (e.g. words the
    ///     user has hidden from this cloud). Folded into the cache key.
    ///   - persistent: When `true`, the result is also read from and written to the
    ///     on-disk cache (keyed by an index fingerprint), so heavy scopes survive
    ///     relaunch. Reserved for corpus and large subseries.
    ///   - progress: Optional per-chunk progress callback `(processed, total)`.
    /// - Returns: The computed word-cloud result.
    func topTerms(
        signature: String,
        keys: [WordCloudDocumentKey],
        limit: Int,
        includeDiplomaticStopwords: Bool,
        extraStopwords: Set<String> = [],
        lens: WordCloudLens = .allTerms,
        tuning: WordCloudTuning = .standard,
        persistent: Bool = false,
        progress: WordCloudProgress? = nil
    ) async throws -> WordCloudResult {
        // What the tagger can do in this process (#1373). Awaited rather than read, so a cloud
        // opened while the launch warm-up is still waiting on its assets waits here, suspended,
        // instead of blocking this actor's thread inside the tokenizer.
        let languageAnalysis = await NaturalLanguageReadiness.verdictWhenReady().health
        // The text generation this count reads (#1421 review). Taken before the count, so a
        // re-index that finishes while it runs leaves the result stamped with the version it
        // began on, and the next open counts again.
        let indexVersion = pipeline.installedDateIndexVersion
        let extrasToken = Self.extrasToken(extraStopwords)
        // Fold the lens into the signature so non-default lenses get their own cache
        // entries while `.allTerms` keeps its existing (precomputed) keys.
        let effectiveSignature = lens == .allTerms ? signature : "\(signature)|lens=\(lens.rawValue)"
        let cacheKey = Self.cacheKey(signature: effectiveSignature, limit: limit,
                                     includeDiplomatic: includeDiplomaticStopwords,
                                     extras: extrasToken, tuning: tuning.cacheToken)
        if let cached = cache[cacheKey] {
            progress?(cached.documentCount, cached.documentCount)
            return cached
        }

        // Heavy scopes consult the on-disk cache, keyed by an index fingerprint.
        var diskKey: String?
        if persistent {
            let fingerprint = (try? await pipeline.documentCacheCount()) ?? 0
            let key = WordCloudDiskCache.key(
                signature: effectiveSignature, limit: limit,
                includeDiplomatic: includeDiplomaticStopwords,
                extras: extrasToken, tuning: tuning.cacheToken, fingerprint: fingerprint
            )
            diskKey = key
            // Only a result whose own stamps say its tagger counted this lens as designed, from
            // the text the index holds now. An entry written before #1373 carries no tagger stamp
            // and cannot say — and on the iOS 27.0 simulators the tagger had been failing
            // unnoticed, so an unstamped Topics entry may be a stored zero. An entry written
            // before the index stamp cannot say which text it counted (#1421 review). Unknown is
            // not the same as safe; either is recomputed once.
            if let disk = WordCloudDiskCache.load(key: key),
               Self.isReusable(disk, for: lens, indexVersion: indexVersion) {
                store(disk, for: cacheKey)
                progress?(disk.documentCount, disk.documentCount)
                return disk
            }
        }

        let tokenizer = WordCloudTokenizer.configured(
            tuning: tuning,
            lens: lens,
            includeDiplomatic: includeDiplomaticStopwords,
            extraStopwords: extraStopwords
        )
        let total = keys.count
        var counts: [String: Int] = [:]
        var tokenTotal = 0
        var documentCount = 0
        var index = 0
        while index < keys.count {
            try Task.checkCancellation()
            let chunk = Array(keys[index..<min(index + chunkSize, keys.count)])
            index += chunkSize
            let texts = try await pipeline.documentBodyTexts(forKeys: chunk)
            documentCount += texts.count
            for text in texts { tokenTotal += tokenizer.accumulate(from: text, into: &counts) }
            progress?(min(index, total), total)
        }

        var result = Self.finalize(counts: counts, documentCount: documentCount,
                                   totalTokens: tokenTotal, limit: limit,
                                   minimumCount: tuning.minimumCount)
        // Stamp the lens before persisting: the disk cache names files by a digest of the key,
        // so this is the only way a later reader (the settings bench) can tell an entity cloud
        // from a word cloud. See `WordCloudResult.lens`.
        result.lens = lens
        result.languageAnalysis = languageAnalysis
        result.indexVersion = indexVersion
        store(result, for: cacheKey)
        // The disk cache outlives this process, and the next one's tagger may work: persisting a
        // cloud counted without the tagger this lens reads would hand it a stored zero, or a
        // cloud of printed forms, for as long as the index fingerprint holds. The in-memory
        // entry above stays, because this process's verdict cannot change.
        if let diskKey, Self.isPersistable(countedUnder: languageAnalysis, lens: lens) {
            WordCloudDiskCache.save(result, key: diskKey)
        }
        return result
    }

    /// The tagger half of ``isReusable(_:for:indexVersion:)``: whether a stored result's own stamp
    /// says the tagger counted `lens` as designed (#1373).
    ///
    /// An entry written before #1373 carries no stamp, and one written since without a working
    /// tagger is never saved — but the stamp is checked on the way back in as well, because the
    /// file is outside this process's control.
    ///
    /// The settings bench asks this half alone, on purpose: it samples a stored cloud as the
    /// reader's vocabulary, to show what the length and occurrence thresholds would keep, and a
    /// count read before a re-index is still that vocabulary. It never stands in for a count.
    static func isReusable(_ stored: WordCloudResult, for lens: WordCloudLens) -> Bool {
        stored.languageAnalysis?.countsAsDesigned(for: lens) == true
    }

    /// Whether a result read back from the disk cache may stand in for a fresh count under `lens`,
    /// over an index installed at `indexVersion`.
    ///
    /// Both of its stamps must say so: the tagger's (``isReusable(_:for:)``), and the index's
    /// (#1421 review). The disk key fingerprints the index by its document count, which a re-index
    /// that rewrites every body leaves as it was — v59 re-joined 313,949 of them — so only the
    /// stamp can tell a count read from the old text from one read from the new. An entry written
    /// before the stamp has none, and is counted again once.
    ///
    /// - Parameters:
    ///   - stored: The result read back from the disk cache.
    ///   - lens: The lens the caller is counting under.
    ///   - indexVersion: `IndexingPipeline.installedDateIndexVersion` as the count begins.
    static func isReusable(_ stored: WordCloudResult, for lens: WordCloudLens,
                           indexVersion: Int) -> Bool {
        isReusable(stored, for: lens) && stored.indexVersion == indexVersion
    }

    /// Whether a result counted under `languageAnalysis` may be written to the disk cache.
    ///
    /// Only when every tagger `lens` reads worked. A later process may have a tagger that does, and
    /// the stored result would otherwise answer for it — a zero for Topics, or printed forms where
    /// that process would count dictionary forms.
    static func isPersistable(countedUnder languageAnalysis: NaturalLanguageHealth,
                              lens: WordCloudLens) -> Bool {
        languageAnalysis.countsAsDesigned(for: lens)
    }

    /// Top terms across the entire indexed corpus.
    ///
    /// Enumerates every document key and folds their text in chunks so the corpus
    /// text is never all resident at once. Long-running; run from a cancellable
    /// background task. Results are persisted to disk and reused across launches
    /// until the index changes.
    ///
    /// - Parameters:
    ///   - limit: Maximum number of terms to return.
    ///   - includeDiplomaticStopwords: See `topTerms(signature:keys:limit:includeDiplomaticStopwords:persistent:progress:)`.
    ///   - progress: Optional per-chunk progress callback `(processed, total)`.
    /// - Returns: The computed corpus word-cloud result.
    func corpusTopTerms(
        limit: Int,
        includeDiplomaticStopwords: Bool,
        extraStopwords: Set<String> = [],
        lens: WordCloudLens = .allTerms,
        tuning: WordCloudTuning = .standard,
        progress: WordCloudProgress? = nil
    ) async throws -> WordCloudResult {
        let keys = try await pipeline.allDocumentKeys()
        return try await topTerms(
            signature: WordCloudScope.corpus.signature,
            keys: keys,
            limit: limit,
            includeDiplomaticStopwords: includeDiplomaticStopwords,
            extraStopwords: extraStopwords,
            lens: lens,
            tuning: tuning,
            persistent: true,
            progress: progress
        )
    }

    // MARK: - Private

    /// Builds the descending top-N term list from a raw tally, dropping terms below
    /// the minimum occurrence count.
    private static func finalize(
        counts: [String: Int],
        documentCount: Int,
        totalTokens: Int,
        limit: Int,
        minimumCount: Int = 1
    ) -> WordCloudResult {
        let top = counts
            .filter { $0.value >= minimumCount }
            .map { TermCount(term: $0.key, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.term < $1.term }
            .prefix(limit)
        return WordCloudResult(terms: Array(top), documentCount: documentCount, totalTokenCount: totalTokens)
    }

    /// Composite cache key combining the scope signature with the parameters that
    /// also affect the result.
    private static func cacheKey(signature: String, limit: Int, includeDiplomatic: Bool,
                                 extras: String, tuning: String) -> String {
        "\(signature)|n=\(limit)|diplo=\(includeDiplomatic)|x=\(extras)|t=\(tuning)"
    }

    /// A stable token summarising a per-scope extra-stopword set for cache keys.
    private static func extrasToken(_ extras: Set<String>) -> String {
        extras.isEmpty ? "" : extras.sorted().joined(separator: ",")
    }

    /// Inserts a result, evicting the oldest entry past the cache limit.
    private func store(_ result: WordCloudResult, for key: String) {
        if cache[key] == nil { cacheOrder.append(key) }
        cache[key] = result
        while cacheOrder.count > cacheLimit {
            let evicted = cacheOrder.removeFirst()
            cache.removeValue(forKey: evicted)
        }
    }
}
