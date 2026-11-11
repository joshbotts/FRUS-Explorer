// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - OccurrenceAvailability

/// Whether a query's occurrences can be counted honestly, and if not, why.
///
/// ## Why this is a type and not an optional
/// Occurrence counting is available for *some* query shapes and impossible for others. A count that
/// silently means something different per shape is the defect this whole workstream exists to stop:
/// for `NEAR(a b, 5)` an instance-mode count is "every instance of a plus every instance of b,
/// wherever they are", which is not what the researcher asked and is larger than the truth; for
/// `a OR b` any single number is a sum of two unrelated quantities; for `=word` the index stores only
/// stems, so exact occurrences cannot be recovered from it at all.
///
/// Returning `nil` or `0` for those would put a wrong number, or a number-shaped blank, next to a
/// document count that *is* right. So the unavailable cases carry a **reason**, the UI states it, and
/// the chart shows documents instead. A blank cell would leave the researcher to guess whether the
/// answer is zero or unknown.
///
/// ## The shapes, and why each falls where it does
/// | shape | available | why |
/// |---|---|---|
/// | single word | yes | one stem, one posting list; the count is exactly the stem's instances |
/// | prefix `navig*` | no | matches many stems; instance mode is per-term, so this needs a term-range walk PR-D does not do |
/// | phrase `"a b"` | no | needs adjacency, i.e. an offset self-join reimplementing FTS5's own matcher |
/// | `NEAR(...)` | no | composite: the honest answer is per-operand, not one total |
/// | boolean `AND`/`OR` | no | same — any single total sums unrelated quantities |
/// | exact `=word` | no | impossible from a stemmed index, at any cost — where the mark applies (see below) |
/// | multi-token (`U.S.S.R.`) | no | tokenizes to several terms with no way to attribute them |
/// | negated-only | no | there is no positive term to count |
///
/// Prefix and phrase are "not yet" rather than "never"; the others are "never". The distinction is
/// deliberately **not** exposed to the researcher, who cannot act on it — the reason strings say what
/// is true now.
///
/// A mark applies only where every match must contain the word through a marked operand — a required mark, or a mark in
/// every `OR` alternative — and then on every positive mark on that word: `ParsedOperand.isExactApplied`, whose terms
/// are `ParsedQuery.exactTerms` (parser 6.5, D4). Anywhere else Search ignores it and runs the word by its stem, so the
/// query is classified by its shape like any other: `=containment OR alliance`,
/// `(=containment OR alliance) containment` and `=containment OR containment alliance` are composite queries, and
/// `=containment OR =containment alliance` is an exact-word one. A word is what the exact-word filter reads (parser
/// 6.6), whatever the capitalisation, the accents the filter folds (not letters such as `ø` or `ł`) or punctuation at
/// either end of each mark, so `=Containment. OR =containment alliance` is an exact-word query too.
///
/// Version history:
///   1.0 — R-2 PR-D: initial implementation
///   1.1 — #1297 round 1 (docs only): the exact-word refusal covers the marks parser 6.3 applies, the words
///         every match must contain; a mark it ignores is classified by the query's shape
///   1.2 — #1297 round 2 (docs only): the refusal follows parser 6.4's per-operand `isExactApplied`, so a mark beside the
///         same word required without one is classified by shape
///   1.3 — #1297 round 3 (docs only): parser 6.5 (D4) applies a mark on a word marked in every alternative, which this
///         classifies as exact-word
///   1.4 — #1297 round 4 (docs only): parser 6.6 compares marks by word, so one word marked in every alternative in two
///         spellings is exact-word; `exactWord`'s doc says a mark is ignored when only one alternative marks the word,
///         not "in one alternative", which D4 made false for a word every alternative marks
enum OccurrenceAvailability: Equatable, Sendable {

    /// Occurrences can be counted, for the single index term named.
    case available(stem: String)

    /// Occurrences cannot be counted honestly for this query.
    case unavailable(reason: Reason)

    /// Why a query cannot be counted by occurrence.
    enum Reason: String, Equatable, Sendable, CaseIterable {
        /// `=word`, applied as an exact-word filter — the index holds stems, so exact-word instances are not
        /// recoverable. A mark the parser ignores (when only one `OR` alternative marks the word, say) is not this
        /// reason.
        case exactWord
        /// A phrase, prefix, or `NEAR(...)` operand: no single stem to count.
        case multiTermOperand
        /// More than one operand — the honest answer is per-operand, not one number.
        case compositeQuery
        /// The word tokenizes to several index terms, or to none.
        case notASingleToken
        /// Nothing positive to count (empty, or exclusions only).
        case noPositiveTerm

        /// One sentence, for the researcher. States what is true, not what might change.
        var explanation: String {
            switch self {
            case .exactWord:
                return String(localized: "analytics.occurrences.unavailable.exact",
                              defaultValue: "Occurrence counts aren’t available for exact-word searches: the index stores word stems, so it cannot tell one exact spelling’s occurrences from another’s.")
            case .multiTermOperand:
                return String(localized: "analytics.occurrences.unavailable.multiTerm",
                              defaultValue: "Occurrence counts aren’t available for phrases, wildcards or proximity searches — those match several index terms, which have no single occurrence count.")
            case .compositeQuery:
                return String(localized: "analytics.occurrences.unavailable.composite",
                              defaultValue: "Occurrence counts aren’t available for queries with more than one term: adding up occurrences of each would count two different things as one.")
            case .notASingleToken:
                return String(localized: "analytics.occurrences.unavailable.notSingleToken",
                              defaultValue: "This term indexes as several separate words, so it has no single occurrence count.")
            case .noPositiveTerm:
                return String(localized: "analytics.occurrences.unavailable.noPositive",
                              defaultValue: "This query has nothing to count — it only excludes terms.")
            }
        }
    }

    /// The stem to count, or `nil` when unavailable.
    var stem: String? {
        if case .available(let stem) = self { return stem }
        return nil
    }

    /// Whether occurrences can be counted.
    var isAvailable: Bool { stem != nil }

    /// The reason, or `nil` when available.
    var reason: Reason? {
        if case .unavailable(let reason) = self { return reason }
        return nil
    }

    // MARK: - Classification

    /// Decides whether `term` can be counted by occurrence, from its parsed shape.
    ///
    /// Pure and cheap — a parse, no I/O — except for `resolveStem`, which the caller supplies so the
    /// stem comes from SQLite's own tokenizer rather than a second implementation of Porter that
    /// could name a term the engine never wrote.
    ///
    /// - Parameters:
    ///   - term: the analytics term as typed.
    ///   - resolveStem: maps a word to its index term, or `nil` if it is not exactly one token.
    ///     Pass `FTS5Store.indexStem(of:)`.
    static func classify(term: String, resolveStem: (String) -> String?) -> OccurrenceAvailability {
        let parsed = FTS5InlineQueryParser.parseDetailed(term)

        // Exact-word first: it is checked before operand shape because `=word` parses as an ordinary
        // word operand, so a shape-first check would call it available and count the stem — the exact
        // defect PR-A removed from the document numerator. `exactTerms` holds only the marks Search
        // applies (the parser's `isExactApplied`, decided by requirement over marked operands); an
        // ignored mark falls through to the shape checks, as its word is stemmed.
        guard parsed.exactTerms.isEmpty else { return .unavailable(reason: .exactWord) }

        let positive = parsed.operands.filter { !$0.isNegated }
        guard !positive.isEmpty else { return .unavailable(reason: .noPositiveTerm) }
        guard positive.count == 1 else { return .unavailable(reason: .compositeQuery) }

        let operand = positive[0]
        guard operand.kind == .word else { return .unavailable(reason: .multiTermOperand) }
        guard let stem = resolveStem(operand.text) else {
            return .unavailable(reason: .notASingleToken)
        }
        return .available(stem: stem)
    }
}
