// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

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
/// ## The count (FRUS Explorer Light, S29b)
/// The count itself, steps 2 to 4, is FRUSCoreKit's `WordCloudCount`, with `finalize` and the rules by
/// which a stored result stands in for a fresh count, so that a host counts a scope by the same rules
/// with a tagger of its own. This actor keeps what is the app's: its caches, in memory and on disk, the
/// readiness gate it awaits before it counts, and the tokenizer's assembly from the settings and the
/// bundled lists. It hands the count NaturalLanguage's tagger, so it counts as it did, an autorelease
/// pool for each document included (#1798, `WordCloudCount`'s "Memory").
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
///   1.4 — #1539: the in-memory cache reuses a count not made as designed only under the verdict it
///          was counted under (`isReusableInMemory`), since a re-check can now replace the verdict
///   1.5 — #1608: the tokenizer counts in the form of the verdict the result is stamped with, so a
///          result stamped "no lemmatiser" is a count of printed forms throughout
///   1.6 — #1798: an autorelease pool for each document (see "Memory")
///   1.7 — 2026-11-24 (FRUS Explorer Light, S29b): the count, its `finalize` and its results' reuse and
///          persistence rules moved into FRUSCoreKit (`WordCloudCount`), with `WordCloudProgress`; this
///          actor keeps its caches and the gate, and counts with NaturalLanguage's tagger, as before
actor WordFrequencyService {

    // MARK: - Dependencies

    private let pipeline: IndexingPipeline

    // MARK: - Cache

    private var cache: [String: WordCloudResult] = [:]
    private var cacheOrder: [String] = []
    private let cacheLimit = 24

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
        return try await topTerms(
            signature: signature, keys: keys, limit: limit,
            includeDiplomaticStopwords: includeDiplomaticStopwords, extraStopwords: extraStopwords,
            lens: lens, tuning: tuning, persistent: persistent,
            countedUnder: languageAnalysis, progress: progress)
    }

    /// The count itself, under a verdict the caller read.
    ///
    /// ``topTerms(signature:keys:limit:includeDiplomaticStopwords:extraStopwords:lens:tuning:persistent:progress:)``
    /// awaits this process's verdict and calls it; nothing else in the app does. It is a method of
    /// its own so a test can count under a verdict its host does not have (#1608): the words are
    /// counted in that verdict's form and the result is stamped with it, and Distinctive ranks the
    /// result against the reference counted in that form, so the three have to be one value.
    ///
    /// - Parameter languageAnalysis: The verdict the count is made under and stamped with.
    func topTerms(
        signature: String,
        keys: [WordCloudDocumentKey],
        limit: Int,
        includeDiplomaticStopwords: Bool,
        extraStopwords: Set<String> = [],
        lens: WordCloudLens = .allTerms,
        tuning: WordCloudTuning = .standard,
        persistent: Bool = false,
        countedUnder languageAnalysis: NaturalLanguageHealth,
        progress: WordCloudProgress? = nil
    ) async throws -> WordCloudResult {
        // The warm-up before anything below tags (#1373). The app's one caller has awaited it;
        // awaited here too, so a caller that hands in a verdict cannot make the process's first
        // tagging block this actor's thread inside the tokenizer.
        _ = await NaturalLanguageReadiness.verdictWhenReady()
        // The text generation this count reads (#1421 review). Taken before the count, so a
        // re-index that finishes while it runs leaves the result stamped with the version it
        // began on, and the next open counts again.
        let indexVersion = pipeline.installedDateIndexVersion
        let extrasToken = Self.extrasToken(extraStopwords)
        let effectiveSignature = Self.effectiveSignature(signature, lens: lens)
        let cacheKey = Self.cacheKey(signature: effectiveSignature, limit: limit,
                                     includeDiplomatic: includeDiplomaticStopwords,
                                     extras: extrasToken, tuning: tuning.cacheToken)
        // A count this process made earlier answers again only while it is still the count this
        // process would make (#1539): a re-check can replace the verdict it was counted under.
        if let cached = cache[cacheKey],
           Self.isReusableInMemory(cached, for: lens, countedUnder: languageAnalysis) {
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
            extraStopwords: extraStopwords,
            // The form of the verdict this result is stamped with below (#1608). Distinctive
            // re-ranks these counts against the reference counted in the stamp's form, so the
            // counts have to be in it from the first word to the last, whatever the lemmatiser does
            // while they are made.
            wordForm: languageAnalysis.wordForm
        )
        // The count, FRUSCoreKit's since S29b, on this actor as before: the documents' text in chunks,
        // each tagged in an autorelease pool of its own (#1798), the result stamped with the lens, the
        // verdict and the index version before it is stored. NaturalLanguage's tagger, through the
        // readiness gate, is the one the tokenizer counted with before the count moved.
        let result = try await WordCloudCount.count(
            keys: keys, pipeline: pipeline, tokenizer: tokenizer,
            tagger: NaturalLanguageWordCloudTagger(),
            countedUnder: languageAnalysis, indexVersion: indexVersion,
            limit: limit, minimumCount: tuning.minimumCount, progress: progress)
        store(result, for: cacheKey)
        // The disk cache outlives this process, and the next one's tagger may work: persisting a
        // cloud counted without the tagger this lens reads would hand it a stored zero, or a
        // cloud of printed forms, for as long as the index fingerprint holds. The in-memory
        // entry above stays, but answers again only under the verdict it was counted under
        // (`isReusableInMemory`), since a re-check can replace that verdict (#1539).
        if let diskKey, Self.isPersistable(countedUnder: languageAnalysis, lens: lens) {
            WordCloudDiskCache.save(result, key: diskKey)
        }
        return result
    }

    /// The tagger half of ``isReusable(_:for:indexVersion:)``: FRUSCoreKit's `WordCloudCount.isReusable(_:for:)`
    /// since S29b, under the name the settings bench calls.
    static func isReusable(_ stored: WordCloudResult, for lens: WordCloudLens) -> Bool {
        WordCloudCount.isReusable(stored, for: lens)
    }

    /// Whether a result read back from the disk cache may stand in for a fresh count under `lens`, over
    /// an index installed at `indexVersion`: `WordCloudCount.isReusable(_:for:indexVersion:)` since S29b.
    static func isReusable(_ stored: WordCloudResult, for lens: WordCloudLens,
                           indexVersion: Int) -> Bool {
        WordCloudCount.isReusable(stored, for: lens, indexVersion: indexVersion)
    }

    /// Whether a count this process made earlier, held in the in-memory cache, may answer a request
    /// counted under `current` (#1539): `WordCloudCount.isReusableInMemory(_:for:countedUnder:)` since S29b.
    static func isReusableInMemory(_ cached: WordCloudResult, for lens: WordCloudLens,
                                   countedUnder current: NaturalLanguageHealth) -> Bool {
        WordCloudCount.isReusableInMemory(cached, for: lens, countedUnder: current)
    }

    /// The memory and disk caches' signature for `signature` under `lens`: `.allTerms` keeps the
    /// scope's own signature, and every other lens folds its name in, so each lens has its own
    /// entries.
    private static func effectiveSignature(_ signature: String, lens: WordCloudLens) -> String {
        lens == .allTerms ? signature : "\(signature)|lens=\(lens.rawValue)"
    }

    #if DEBUG
    /// Test seam (#1539): puts `result` in the in-memory cache under the key ``topTerms(signature:keys:limit:includeDiplomaticStopwords:extraStopwords:lens:tuning:persistent:progress:)``
    /// builds for the same arguments, so a test can drive the memory cache's reuse rule through the
    /// service. `WordFrequencyServiceStampWiringTests`' three #1539 memory-cache tests are its only callers.
    func storeInMemoryForTesting(_ result: WordCloudResult, signature: String, limit: Int,
                                 includeDiplomaticStopwords: Bool, lens: WordCloudLens = .allTerms,
                                 tuning: WordCloudTuning = .standard) {
        let key = Self.cacheKey(signature: Self.effectiveSignature(signature, lens: lens), limit: limit,
                                includeDiplomatic: includeDiplomaticStopwords,
                                extras: Self.extrasToken([]), tuning: tuning.cacheToken)
        store(result, for: key)
    }
    #endif

    /// Whether a result counted under `languageAnalysis` may be written to the disk cache:
    /// `WordCloudCount.isPersistable(countedUnder:lens:)` since S29b.
    static func isPersistable(countedUnder languageAnalysis: NaturalLanguageHealth,
                              lens: WordCloudLens) -> Bool {
        WordCloudCount.isPersistable(countedUnder: languageAnalysis, lens: lens)
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
