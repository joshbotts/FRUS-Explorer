// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - SearchService + collocation

/// The collocation panel's measure over a retained result set, kept in the app because it tags
/// with NaturalLanguage and tokenises through WordCloudKit, which the kit cannot import. It reads
/// the service's pipeline and positive terms, which the kit keeps internal for it.
///
/// Version history:
///   1.0 — Session 2026-10-04 (FRUSCoreKit, part 2): moved out of `SearchService.swift` verbatim
///         when the service moved into FRUSCoreKit
extension SearchService {

    /// Words the query's matches keep company with, ranked by how distinctive that company is.
    ///
    /// ## Why this takes the whole retained set where the concordance takes a page
    /// The concordance shows *these lines*, so it must agree with the rows on screen. A collocation
    /// is a *measure*, and a measure over twenty-five documents cannot clear its own floor: a page
    /// yields ~400 window tokens across ~290 distinct lemmas, so almost nothing reaches three
    /// occurrences and the panel reads as broken rather than bounded. Measured on the real index:
    /// the whole retained iOS set is 4.3 MB and about 1.4 s; a page is 0.1 MB and empty.
    ///
    /// ## The bound is on MATCHES, not documents or bytes
    /// Cost has two drivers and they scale differently. Bytes drive the fetch and the scan; matches
    /// drive the `NLTagger` pass, which is the expensive one — measured at 80,124 surviving
    /// tokens/sec, a dense query over a full macOS set is 6.4 s of tagging against 4.2 s of
    /// everything else. A byte cap leaves that unbounded. `maxMatches` caps the term that actually
    /// costs, and ``CollocationResult/wasBounded`` reports when it bit.
    ///
    /// - Parameters:
    ///   - results: the retained result set — everything the user could page to, not the page.
    ///   - parameters: the executed query, for its positive terms.
    ///   - windowSize: words either side of each match.
    ///   - configuration: the resolved live tokenisation. The caller resolves it on the main actor.
    func collocation(
        for results: [SearchResult],
        parameters: SearchParameters,
        windowSize: Int,
        configuration: CollocationConfiguration,
        reference: (terms: [String: Int], totalTokens: Int, cutoffCount: Int),
        generated: String?,
        maxMatches: Int? = nil
    ) async throws -> CollocationAnalysis.Outcome {
        // The tagger's verdict before anything below tokenizes (#1373). Both callers await it on the
        // main actor already; awaiting it here too means a caller that forgets cannot make the
        // process's first tagging block this actor — and every search behind it — for as long as
        // the warm-up waits on its assets.
        _ = await NaturalLanguageReadiness.verdictWhenReady()
        let maxMatches = maxMatches ?? Self.collocationMatchBudget(windowSize: windowSize)
        // The same set the concordance and the highlighter anchor on, so the words treated as
        // matches are the words the reader sees marked. For a `NEAR(a b, N)` query that set holds
        // BOTH operands, so the collocates are of the pair — the right reading of "what appears
        // near this query", and worth stating on screen.
        let terms = positiveTerms(from: parameters)
        let stems = terms.map { PorterStemmer.stem($0.lowercased()) }
        guard !results.isEmpty, !stems.isEmpty else { return .unavailable(.noMatches) }

        let keys = results.map {
            WordCloudDocumentKey(volumeId: $0.volumeId, documentId: $0.documentId)
        }
        var counts: [String: Int] = [:]
        var windowTokenCount = 0
        var documentsScanned = 0
        var anchorCount = 0
        var omittedAnchorCount = 0
        var budgetSpent = 0
        var documentsOffered = 0

        // Chunked the way every other bulk body-text reader in the app is: one keyed fetch per 400
        // documents, scanned, then dropped. The whole retained set is never resident at once, which
        // is what keeps a 7,500-result macOS search from holding 32 MB of prose.
        var offset = 0
        while offset < keys.count, budgetSpent < maxMatches {
            try Task.checkCancellation()
            let chunk = Array(keys[offset..<min(offset + Self.collocationChunkSize, keys.count)])
            offset += Self.collocationChunkSize
            let bodies = try await pipeline.documentBodyTextsByKey(forKeys: chunk)

            // The scan is per-document and independent, so it fans out. Measured single-threaded, a
            // dense macOS set is ~2.7 s of scanning alone; this is the difference between a panel
            // that appears and one that looks hung.
            let scans = await withTaskGroup(of: CollocationWindow.DocumentScan.self) { group in
                for key in chunk {
                    guard let body = bodies["\(key.volumeId)/\(key.documentId)"] else { continue }
                    group.addTask {
                        CollocationWindow.scan(body: body, stems: stems, windowSize: windowSize)
                    }
                }
                var collected: [CollocationWindow.DocumentScan] = []
                for await scan in group { collected.append(scan) }
                return collected
            }

            // Runs are joined with a newline, never a space: two passages from opposite ends of a
            // document are not a sentence, and the lemmatiser is context-dependent. A line break is
            // the cheapest boundary it respects.
            var windowText: [String] = []
            documentsOffered += chunk.count
            for scan in scans {
                documentsScanned += 1
                anchorCount += scan.anchorCount
                omittedAnchorCount += scan.omittedAnchorCount
                budgetSpent += scan.anchorCount
                windowText.append(contentsOf: scan.runs)
            }
            if !windowText.isEmpty {
                // One tokenizer pass per CHUNK rather than per window: `accumulate` builds a fresh
                // `NLTagger` on every call, and a window-at-a-time loop would construct thousands.
                windowTokenCount += configuration.tokenizer
                    .accumulate(from: windowText.joined(separator: "\n"), into: &counts)
            }
        }

        // The query's own terms, in the form the collocates are counted in, so the exclusion
        // compares like with like. Stems would not match — the counts are lemmas.
        var anchorLemmas: [String: Int] = [:]
        configuration.tokenizer.accumulate(from: terms.joined(separator: "\n"), into: &anchorLemmas)

        return CollocationAnalysis.rank(
            counts: counts,
            windowTokenCount: windowTokenCount,
            anchorLemmas: Set(anchorLemmas.keys),
            windowSize: windowSize,
            documentsScanned: documentsScanned,
            documentsInScope: results.count,
            // What the BUDGET stopped, distinct from what simply had no cached body text.
            // `documentsScanned < documentsInScope` conflates the two, and a scan that covered
            // everything it was offered must not report itself as truncated.
            documentsOffered: documentsOffered,
            anchorCount: anchorCount,
            omittedAnchorCount: omittedAnchorCount,
            reference: reference,
            generated: generated
        )
    }

    /// Window tokens collected before the scan stops — the budget on the term that actually costs.
    ///
    /// 200,000 surviving tokens is about 2.5 s of tagging at the measured 80,124 tokens/sec. That
    /// covers every iOS result set outright and every sparse macOS one; it clips only a dense query
    /// over a full macOS set, where the collocates drawn from a 200,000-token sample are
    /// statistically indistinguishable from those drawn from the whole.
    static let collocationTokenBudget = 200_000

    /// Matches affordable at a given window size.
    ///
    /// The budget is on TOKENS, not matches, because a match is not a fixed amount of work: at ±10 a
    /// match contributes ~10 surviving tokens, at ±50 about five times that. A fixed match budget
    /// calibrated at ±10 would let the ±50 the picker offers cost five times its measurement — 12 s
    /// where 2.5 s was intended, on a control the user is invited to move.
    static func collocationMatchBudget(windowSize: Int) -> Int {
        // ~48% of raw words survive stopwording and the length floor, measured corpus-wide:
        // 1,286 MB of body text yields 94.6M surviving tokens, ~13.6 bytes each against ~6.5
        // bytes per raw word.
        let tokensPerMatch = max(1, Int((Double(2 * windowSize) * 0.48).rounded()))
        return max(1, collocationTokenBudget / tokensPerMatch)
    }

    /// Documents per keyed body-text fetch, matching every other bulk reader in the app (400 pairs
    /// is 800 binds, under SQLite's 999-variable limit).
    static let collocationChunkSize = 400
}
