// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - KeynessScore

/// How distinctive one term is in a set of documents, measured against a reference corpus.
///
/// Version history:
///   1.0 — S-1: initial implementation
struct KeynessScore: Equatable, Sendable, Identifiable {

    /// The term, in whatever normalised form both sides were counted in.
    let term: String

    /// Occurrences in the documents being described.
    let scopeCount: Int
    /// Occurrences in the reference corpus.
    let referenceCount: Int

    /// Log-likelihood (G²), **signed**: positive when the term is over-represented in the scope,
    /// negative when under-represented.
    ///
    /// Unsigned G² answers "is this distribution unlikely by chance", which is true of a term that is
    /// conspicuously *absent* just as much as one that is conspicuously present. A keyness list
    /// showing both without distinguishing them would put the vocabulary a set avoids beside the
    /// vocabulary it favours, unlabelled.
    let logLikelihood: Double

    /// Log-2 ratio of the two relative frequencies — the **effect size**.
    ///
    /// Reported alongside G² because G² alone conflates effect size with sample size, and that is
    /// not a subtlety: a term occurring 50 times against 50 scores G² = 323.9, while one occurring
    /// once against once scores 6.5 — yet both are exactly 100× over-represented and share a log
    /// ratio of 6.64. Ranking on G² alone therefore ranks by how much text you have, which for a
    /// researcher comparing a 20-document set against a 200-document one is actively misleading.
    let logRatio: Double

    var id: String { term }

    /// Whether the term is over-represented in the scope.
    var isOverused: Bool { logLikelihood > 0 }

    /// The effect size as a plain multiple: how many times more often the term is used here than in
    /// the reference, per word of text.
    ///
    /// ``logRatio`` is log₂, which is the corpus-linguistics convention and what an export should
    /// carry for citation — but it is not a number a reader can act on. 5.26 and 8.32 are "38×" and
    /// "320×", and the gap between those two claims is far larger than the gap between the logs
    /// makes it look. Lives here rather than in a view so it can be tested: a renderer that printed
    /// `logRatio` directly would understate a 320× concentration as "8×" and nothing about the
    /// screen would look wrong.
    var foldOverRepresentation: Double { pow(2, logRatio) }
}

// MARK: - Keyness

/// Computes keyness — which words are distinctive of a set of documents, rather than merely frequent
/// in it.
///
/// ## The measure
/// Log-likelihood (G²), per decision S-1-1: it is the corpus-linguistics standard, so a figure here
/// is comparable with published keyness figures, and it behaves better than chi-square on the sparse
/// counts a small document set produces.
///
/// ## Both sides must be counted the same way
/// This is the one thing that cannot be got wrong, and it is not a detail of implementation — it is
/// what the number means. `scopeCounts` and `referenceCounts` must come from the **same tokenizer
/// over the same fields**. FRUS Explorer has two tokenisations in play: the word cloud's NLTagger
/// lemmas over `body_text`, and SQLite's `porter unicode61` stems over header, dateline, source note
/// and body. Dividing one by the other produces a ratio of two different vocabularies over two
/// different populations, and it fails *systematically* rather than randomly — every word whose lemma
/// and stem diverge is mis-scored in the same direction. ``vocabularyOverlap(scopeCounts:referenceCounts:)`` exists so a
/// caller can assert the pairing rather than assume it.
///
/// Version history:
///   1.0 — S-1: initial implementation
enum Keyness {

    /// Minimum occurrences in the scope for a term to be ranked at all.
    ///
    /// Without a floor, a term appearing **once** in the scope and once in the corpus scores
    /// G² = 6.48 — nominally significant, and enough to top a list. That is not a finding about the
    /// documents; it is a finding about the corpus being large. The plan asks that "a term appearing
    /// twice cannot top the ranking", so the floor is 3.
    static let defaultMinimumScopeCount = 3

    /// Scores every term in `scopeCounts` against `referenceCounts`.
    ///
    /// - Parameters:
    ///   - scopeCounts: term → occurrences in the documents being described.
    ///   - referenceCounts: term → occurrences in the reference corpus. A term absent here is
    ///     treated as zero, which is a real and interesting case (a word unique to the scope), not
    ///     an error.
    ///   - scopeTotal: total tokens in the scope. Pass the true total, not the sum of the top-N
    ///     `scopeCounts` — a truncated denominator inflates every relative frequency.
    ///   - referenceTotal: total tokens in the reference corpus, with the same caveat.
    ///   - minimumScopeCount: the low-frequency floor.
    /// - Returns: scores sorted by descending log-likelihood — most distinctive first.
    static func score(
        scopeCounts: [String: Int],
        referenceCounts: [String: Int],
        scopeTotal: Int,
        referenceTotal: Int,
        minimumScopeCount: Int = defaultMinimumScopeCount
    ) -> [KeynessScore] {
        guard scopeTotal > 0, referenceTotal > 0 else { return [] }
        let c = Double(scopeTotal)
        let d = Double(referenceTotal)

        return scopeCounts.compactMap { term, rawScope -> KeynessScore? in
            guard rawScope >= minimumScopeCount else { return nil }
            let a = Double(rawScope)
            let b = Double(referenceCounts[term] ?? 0)

            let expectedScope = c * (a + b) / (c + d)
            let expectedReference = d * (a + b) / (c + d)

            // 0·ln(0) is 0 by convention, and reaching for it is not pedantry: a term absent from the
            // reference corpus is exactly the case a researcher most wants surfaced, so it must score
            // rather than produce a NaN that sorts unpredictably.
            var g = 0.0
            if a > 0, expectedScope > 0 { g += a * log(a / expectedScope) }
            if b > 0, expectedReference > 0 { g += b * log(b / expectedReference) }
            g *= 2

            let scopeRate = a / c
            let referenceRate = b / d
            let signed = scopeRate >= referenceRate ? g : -g

            // Standard +0.5 continuity correction so a term absent from the reference has a large
            // finite effect size rather than an infinity that breaks every sort and formatter.
            let ratio = log2(((a > 0 ? a : 0.5) / c) / ((b > 0 ? b : 0.5) / d))

            return KeynessScore(term: term, scopeCount: rawScope, referenceCount: Int(b),
                                logLikelihood: signed, logRatio: ratio)
        }
        // Descending G², with the term as a tiebreak so the order is total — two terms with equal
        // scores must not swap between renders.
        .sorted { $0.logLikelihood == $1.logLikelihood
            ? $0.term < $1.term
            : $0.logLikelihood > $1.logLikelihood }
    }

    /// Whether two frequency tables can legitimately be compared.
    ///
    /// A cheap structural check, not a proof: it verifies the two sides share enough vocabulary to
    /// plausibly come from the same tokeniser. Two tokenisations of the same English corpus — lemmas
    /// versus Porter stems — overlap only partly (`treaty`/`treati`, `alliance`/`alli`), so a very
    /// low overlap is strong evidence of a mismatched pairing.
    ///
    /// Returns the overlap as a fraction of the scope's vocabulary. A caller comparing like with like
    /// should see a high value; anything low means the baseline is counting something else.
    static func vocabularyOverlap(
        scopeCounts: [String: Int], referenceCounts: [String: Int]
    ) -> Double {
        guard !scopeCounts.isEmpty else { return 0 }
        let shared = scopeCounts.keys.filter { referenceCounts[$0] != nil }.count
        return Double(shared) / Double(scopeCounts.count)
    }
}
