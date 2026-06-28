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
/// index changes. Corpus computation can be long-running; callers should invoke
/// it from a cancellable background `Task` and show progress.
///
/// Version history:
///   1.0 — Word Cloud feature: initial implementation
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

    /// Flushes all cached word-cloud results. Call after the index is modified.
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
            if let disk = WordCloudDiskCache.load(key: key) {
                store(disk, for: cacheKey)
                progress?(disk.documentCount, disk.documentCount)
                return disk
            }
        }

        let tokenizer = WordCloudTokenizer(
            stopwords: WordCloudStopwords.active(includeDiplomatic: includeDiplomaticStopwords)
                .union(extraStopwords),
            minimumLength: tuning.minimumLength,
            foldPlurals: tuning.foldPlurals,
            lens: lens,
            lexicon: WordCloudLexicons.filter(for: lens),
            markings: tuning.filterMarkings ? WordCloudStopwords.markings : []
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

        let result = Self.finalize(counts: counts, documentCount: documentCount,
                                   totalTokens: tokenTotal, limit: limit,
                                   minimumCount: tuning.minimumCount)
        store(result, for: cacheKey)
        if let diskKey { WordCloudDiskCache.save(result, key: diskKey) }
        return result
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
