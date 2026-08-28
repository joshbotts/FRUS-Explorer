// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// Generates candidates by wording overlap — "more like this", computed live from the
/// local FTS5 index with no bundled artifact (W-17, the approved query-time variant of
/// the withdrawn lexical-neighbors artifact; `Completed/Lexical-Similarity-Neighbors-
/// Assessment.md` §0.12 is the binding shape).
///
/// ## The pipeline
/// 1. The anchor's body text is tokenised into surface words and the most distinctive
///    are selected by `tf/df` (term frequency in the anchor against corpus document
///    frequency from `fts5vocab`). **Surface forms, never lemmas**: the query terms are
///    re-stemmed by SQLite's own tokenizer at query time, so they hit exactly the index
///    terms the anchor's occurrences produced — an NLTagger lemma is a different
///    vocabulary (`alliance` → `alli` vs the index's `allianc`) and can name a term the
///    engine never wrote.
/// 2. The terms run as one `body_text`-restricted BM25 OR-query
///    (`FTS5Store.lexicalCandidates`), which also enforces the df ceiling — a
///    correctness guard, not a knob: a pathological anchor costs 2.9 s without one.
/// 3. Each candidate's strength is the **`bm25(candidate) / bm25(anchor)` self-ratio**,
///    absolute in `[0, 1]` by construction (the anchor contains every query term, so it
///    scores at or near the top; a rare candidate outscoring it clamps to 1 in the
///    ranker). The axis is `isSelfNormalising`, so the ranker clamps rather than
///    dividing by the list's own max — the #643 escape, same as the semantic axis.
///
/// ## The four assessment traps, and where each lands
/// - **Column restriction** and the **df ceiling** live in `FTS5Store.lexicalCandidates`.
/// - **Scope is never pushed into SQL** (`volume_id` is unindexed there): the volume
///   fence is applied here, in Swift, after the query.
/// - **The anchor is excluded** from the candidates — it ranks in its own top-11 every
///   time — but its row is read first as the ratio's denominator.
///
/// ## Experimental
/// Ships at weight 0 with "experimental" in the name. Its evaluation pairs with W-9's
/// instrument (one measure judging the lexical and semantic routes), so until that runs
/// the axis is a slider a researcher may raise, not a graded feature.
///
/// Version history:
///   1.0 — W-17 session 2: initial implementation
@MainActor
struct LexicalSimilarityGenerator: SimilarityGenerator {

    var axis: SimilarityAxis { .lexicalSimilarity }

    /// How many admitted terms the OR-query carries. Eight is enough for the ratio to
    /// discriminate (one shared rare term ≈ 0.1–0.2, most of the vocabulary ≈ 1.0) while
    /// keeping the posting-list work bounded.
    static let queryTermLimit = 8

    /// How many tf-ranked words are priced against the vocabulary before the `tf/df`
    /// selection. Pricing is two actor hops per word, so this bounds that cost.
    static let selectionPoolLimit = 32

    /// The corpus document frequency above which a term is refused as a query term.
    ///
    /// A cost guard, not relevance tuning — relevance is the `tf/df` selection's job.
    /// 10,000 documents is ~3% of the corpus: eight such terms bound the BM25 scoring
    /// work at ~80k postings, tens of milliseconds, where one unceilinged "the"-class
    /// term costs 2.9 s (measured). Enforced twice on purpose: here during selection and
    /// again inside `FTS5Store.lexicalCandidates`.
    static let dfCeiling = 10_000

    /// Creates the generator.
    init() {}

    func candidates(
        for anchor: DocumentKey,
        anchorYear: Int?,
        limit: Int,
        scopeVolumeIds: Set<String>?,
        appState: AppState
    ) async throws -> GeneratedPool {
        guard let pipeline = appState.indexingPipeline,
              let searchService = appState.searchService else { return .empty }

        // The anchor's own text is the query's source. A row with no body text (a
        // container quasi-document, an unindexed anchor) has no wording to match.
        let anchorKey = WordCloudDocumentKey(volumeId: anchor.volumeId, documentId: anchor.documentId)
        guard let texts = try? await pipeline.documentBodyTextsByKey(forKeys: [anchorKey]),
              let anchorText = texts["\(anchor.volumeId)/\(anchor.documentId)"],
              !anchorText.isEmpty else { return .empty }

        // Stage 1: surface words by anchor term frequency.
        let ranked = Self.wordCounts(
            in: anchorText,
            stopwords: WordCloudStopwords.active(includeDiplomatic: true))
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .prefix(Self.selectionPoolLimit)
        guard !ranked.isEmpty else { return .empty }

        // Stage 2: price each word's stem against fts5vocab and select by tf/df.
        var priced: [(word: String, tfOverDf: Double)] = []
        for (word, tf) in ranked {
            guard let stem = try? await searchService.indexStem(of: word),
                  let entry = try? await searchService.corpusTermProfile(forStem: stem),
                  entry.documentFrequency > 0, entry.documentFrequency <= Self.dfCeiling
            else { continue }
            priced.append((word: word, tfOverDf: Double(tf) / Double(entry.documentFrequency)))
        }
        let queryTerms = priced
            .sorted { $0.tfOverDf == $1.tfOverDf ? $0.word < $1.word : $0.tfOverDf > $1.tfOverDf }
            .prefix(Self.queryTermLimit)
            .map(\.word)
        guard !queryTerms.isEmpty else { return .empty }

        // Stage 3: one column-restricted BM25 query. The fetch is sized so the anchor's
        // own row — the ratio's denominator — and a full candidate pool both fit after
        // the Swift-side scope fence below.
        let fetchLimit = max(limit + 1, 2 * limit)
        let (rows, _) = try await searchService.lexicalCandidates(
            terms: queryTerms, dfCeiling: Self.dfCeiling, limit: fetchLimit)
        guard let anchorScore = rows.first(where: {
            $0.volumeId == anchor.volumeId && $0.documentId == anchor.documentId
        })?.bm25, anchorScore < 0 else {
            // No denominator, no honest ratio. The anchor ranks in its own top-11 every
            // time (measured), so an absence means the query missed it structurally —
            // return nothing rather than scores on an invented scale.
            return .empty
        }

        // Stage 4: the volume fence, in Swift (never in the SQL), then the ratio.
        let eligibleVolumes = SemanticSimilarityGenerator.eligibleVolumeIDs(
            indexed: appState.indexedVolumeIds, scope: scopeVolumeIds)
        var keys: [DocumentKey] = []
        var scoreByKey: [DocumentKey: Double] = [:]
        for row in rows {
            let key = DocumentKey(volumeId: row.volumeId, documentId: row.documentId)
            guard key != anchor, eligibleVolumes.contains(row.volumeId) else { continue }
            // Both scores are negative (SQLite bm25): the ratio is positive, and a
            // candidate weaker than the anchor lands below 1.
            keys.append(key)
            scoreByKey[key] = row.bm25 / anchorScore
            if keys.count >= limit { break }
        }
        guard !keys.isEmpty else { return .empty }

        let records = try await pipeline.candidateRecords(forKeys: keys)
        return GeneratedPool(
            candidates: keys.compactMap { key in
                guard let record = records[key], let score = scoreByKey[key] else { return nil }
                // Raw ratio; the axis is `isSelfNormalising`, so the ranker clamps it
                // to [0, 1] rather than dividing by this list's own max (#643).
                return GeneratedCandidate(key: key, record: record, strength: score)
            },
            // nil: the query was cut at `fetchLimit` and never counted the corpus-wide
            // match total. Unknown, which `GeneratedPool` keeps distinct from complete.
            availableTotal: nil)
    }

    /// Term frequencies of the query-eligible surface words in a text: lowercased,
    /// letters only, at least four characters, stopwords out.
    ///
    /// Four characters and the shared stopword payload are the word-cloud tuning's
    /// floor; the pricing stage then drops anything the index has never seen, so
    /// tokenisation debris cannot reach the query. Stopwords are injected so the
    /// function is pure and testable without the bundle.
    nonisolated static func wordCounts(in text: String, stopwords: Set<String>) -> [String: Int] {
        var counts: [String: Int] = [:]
        var current: [Character] = []
        func flush() {
            defer { current.removeAll(keepingCapacity: true) }
            guard current.count >= 4 else { return }
            let word = String(current).lowercased()
            guard !stopwords.contains(word) else { return }
            counts[word, default: 0] += 1
        }
        for character in text {
            if character.isLetter { current.append(character) } else { flush() }
        }
        flush()
        return counts
    }
}
