// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - QueryInspection

/// What the Query Inspector knows about a query: what it became, what each part of it
/// matches, and — when nothing matched — which part is responsible.
///
/// ## Why this is a value, not a view
/// Every claim the inspector makes is a factual one a researcher may put in a method
/// appendix, so the claims are computed and tested here rather than assembled in a view
/// body where nothing can check them.
///
/// Version history:
///   1.0 — Q-2a: initial implementation
struct QueryInspection: Sendable, Equatable {

    /// The MATCH expression the query rendered to, or `nil` when there is none.
    let expression: RenderedExpression?

    /// The query's searchable units, in the order typed, each with what the index knows
    /// about it.
    let operands: [InspectedOperand]

    /// How many volumes this device has indexed — the denominator every count needs.
    ///
    /// Per-device and live. The corpus has 552 published volumes; what a count is "out
    /// of" is how many of them are indexed *here*, which is the number the researcher's
    /// claim actually rests on.
    let indexedVolumeCount: Int

    /// True when the query carries no FTS terms at all — a person filter alone, say.
    ///
    /// `SearchService.makeMatchExpressions` returns `(nil, nil)` for these and the search
    /// runs as a filter-only query. There is no expression to show, and saying so is
    /// better than showing an empty strip.
    let isFilterOnly: Bool

    /// Whether every operand is present and none of them is the problem.
    var hasOperands: Bool { !operands.isEmpty }
}

// MARK: - RenderedExpression

/// The FTS5 expression(s) a query produced.
///
/// There are two because the app searches two tables — the corpus (`frus_documents`) and
/// user content (summaries and notes). Under the shipped defaults both scope flags are on
/// and the two strings are **byte-identical**; they diverge only when exactly one of
/// Notes/Summaries is enabled, at which point the user-content one carries a
/// `{summary_text}:` or `{note_text}:` column prefix.
///
/// Version history:
///   1.0 — Q-2a: initial implementation
struct RenderedExpression: Sendable, Equatable {

    /// The corpus expression, or `nil` when document text is out of scope.
    let corpus: String?

    /// The user-content expression, or `nil` when both summaries and notes are out of scope.
    let userContent: String?

    /// The expression to display: the corpus one when there is one, else user content.
    ///
    /// Never a synthesized string. The mock in the design bundle shows a
    /// `{header dateline source_note body_text}:` prefix on the corpus expression, which
    /// the app cannot emit — `renderExpression` passes `columns: nil` for the corpus, so
    /// the prefix is empty. Displaying a prefix the engine never saw would make the
    /// "rendered expression" column non-reproducible, which defeats the point.
    var displayed: String? { corpus ?? userContent }

    /// Whether the two expressions differ, which is worth saying out loud because it
    /// means the two halves of the search asked different questions.
    var expressionsDiffer: Bool {
        guard let corpus, let userContent else { return false }
        return corpus != userContent
    }
}

// MARK: - InspectedOperand

/// One operand, with what the index knows about it.
///
/// ## Two counts, and the gap between them is information
/// `scopedCount` is exact within the researcher's current filters; `corpusDocumentFrequency`
/// is the whole local index, unscoped. Decision Q-2-1 keeps both and labels which is
/// which, because a term that is common corpus-wide but rare in scope — or the reverse —
/// is telling you something about your scope, not just about the term.
///
/// Version history:
///   1.0 — Q-2a: initial implementation
struct InspectedOperand: Sendable, Equatable {

    /// The parsed operand this describes.
    let operand: ParsedOperand

    /// The index term this operand's word resolves to, from SQLite's own tokenizer.
    ///
    /// `nil` for phrases, prefixes and proximity operands, which have no single stem, and
    /// for words that tokenize to more than one term.
    let stem: String?

    /// Exact hit count within the current filters, or `nil` when it has not been computed.
    ///
    /// Populated only by the explicit, expensive pass — see
    /// ``QueryInspector/scopedCounts(for:parameters:)``.
    let scopedCount: Int?

    /// How many indexed documents contain this operand's stem, corpus-wide and unfiltered.
    ///
    /// One `fts5vocab` lookup, no search. `nil` when the operand has no single stem.
    let corpusDocumentFrequency: Int?

    /// Whether the tokenizer broadened this word — the stem differs from what was typed.
    ///
    /// This is the stemming trap in one boolean. It is deliberately *not* the same as
    /// "this is a problem": `europe → europ` differs and matches nothing extra, while
    /// `containment → contain` is the one that misleads. Telling those apart needs the
    /// stem→surface-forms map that decision Q-3-1 deferred to D-1, so the inspector
    /// reports the fact and the count and lets the researcher judge.
    var isStemBroadening: Bool {
        guard let stem, operand.kind == .word else { return false }
        return stem != operand.text.lowercased()
    }
}

// MARK: - QueryInspector

/// Builds a ``QueryInspection`` from a query.
///
/// ## Two passes, priced differently, on purpose
/// - ``inspect(parameters:indexedVolumeCount:)`` is **cheap**: it parses, asks SQLite for
///   each word's stem, and does one `fts5vocab` lookup per operand. No search runs. This
///   is the pass that can be driven live from typing.
/// - ``scopedCounts(for:parameters:)`` and ``emptyConjuncts(in:parameters:)`` are
///   **expensive**: one `searchCount` per operand, each a real query. At full corpus a
///   common term is 6–12 s, so these run on demand — the zero path, or an explicit
///   request — never on a keystroke.
///
/// The split is the whole reason decision Q-2-1 lands where it does: the unscoped estimate
/// is what a type-ahead can afford, and the scoped exact count is what a published claim
/// needs.
///
/// Version history:
///   1.0 — Q-2a: initial implementation
struct QueryInspector: Sendable {

    /// The store the vocabulary lookups run against.
    let fts5Store: FTS5Store

    /// The service the scoped counts run through, so they use the identical query path
    /// the search itself uses.
    let searchService: SearchService

    /// Creates an inspector.
    init(fts5Store: FTS5Store, searchService: SearchService) {
        self.fts5Store = fts5Store
        self.searchService = searchService
    }

    // MARK: - The cheap pass

    /// Describes `parameters` without running a search.
    ///
    /// - Parameter indexedVolumeCount: how many volumes this device has indexed. Supplied
    ///   by the caller because it is app state (`AppState.indexedVolumeIds`), and because
    ///   passing it in keeps this type testable without one.
    func inspect(parameters: SearchParameters, indexedVolumeCount: Int) async -> QueryInspection {
        let expression = await renderedExpression(for: parameters)
        let parsed = parameters.keywords.map { FTS5InlineQueryParser.parseDetailed($0) }
        let operands = parsed?.operands ?? []

        var inspected: [InspectedOperand] = []
        for operand in operands {
            let stem = await stem(for: operand)
            var frequency: Int?
            if let stem {
                frequency = try? await fts5Store.vocabularyEntry(stem: stem)?.documentFrequency
            }
            inspected.append(InspectedOperand(
                operand: operand, stem: stem,
                scopedCount: nil, corpusDocumentFrequency: frequency))
        }

        return QueryInspection(
            expression: expression,
            operands: inspected,
            indexedVolumeCount: indexedVolumeCount,
            isFilterOnly: expression == nil && (parameters.personRef != nil
                                                || parameters.personRollupId != nil)
        )
    }

    /// The index term an operand's word resolves to, or `nil` when it has no single one.
    ///
    /// Only a bare word has a stem worth showing. A phrase is several words, a prefix is
    /// deliberately many, and a `NEAR(...)` is a whole expression — labelling any of them
    /// with one stem would be a lie of convenience.
    private func stem(for operand: ParsedOperand) async -> String? {
        guard operand.kind == .word else { return nil }
        return try? await fts5Store.indexStem(of: operand.text)
    }

    /// Renders the query's MATCH expression(s), or `nil` when it has none.
    private func renderedExpression(for parameters: SearchParameters) async -> RenderedExpression? {
        guard let pair = try? await searchService.matchExpressions(for: parameters) else { return nil }
        guard pair.corpus != nil || pair.userContent != nil else { return nil }
        return RenderedExpression(corpus: pair.corpus, userContent: pair.userContent)
    }

    // MARK: - The expensive passes

    /// Runs one exact `searchCount` per operand, within the current filters.
    ///
    /// Returns the operands with `scopedCount` filled in. Operand order is preserved so a
    /// view can diff against the cheap pass without re-keying.
    ///
    /// A **negated** operand is skipped rather than counted: "how many documents contain
    /// the thing you excluded" is not a number the result set contains, and showing it
    /// beside the others would read as a hit count.
    func scopedCounts(
        for inspection: QueryInspection, parameters: SearchParameters
    ) async -> [InspectedOperand] {
        var out: [InspectedOperand] = []
        for item in inspection.operands {
            guard !item.operand.isNegated else { out.append(item); continue }
            let count = try? await searchService.searchCount(
                parameters: Self.parameters(parameters, narrowedTo: item.operand))
            out.append(InspectedOperand(
                operand: item.operand, stem: item.stem,
                scopedCount: count, corpusDocumentFrequency: item.corpusDocumentFrequency))
        }
        return out
    }

    /// Names the operands that return nothing on their own — the reason a conjunctive
    /// query came back empty.
    ///
    /// This is the whole point of the zero path. "No results" is indistinguishable from a
    /// typo, a stemming surprise and a genuine historical absence; "*guarantee* matches
    /// 41 documents here, *Formosa* matches 0" is a finding.
    ///
    /// Negated operands are excluded: an excluded term matching nothing is not why the
    /// query is empty.
    func emptyConjuncts(
        in inspection: QueryInspection, parameters: SearchParameters
    ) async -> [ParsedOperand] {
        var empty: [ParsedOperand] = []
        for item in inspection.operands where !item.operand.isNegated {
            let count = try? await searchService.searchCount(
                parameters: Self.parameters(parameters, narrowedTo: item.operand))
            if count == 0 { empty.append(item.operand) }
        }
        return empty
    }

    /// Rebuilds `parameters` with its keyword text replaced by a single operand, keeping
    /// every filter and scope flag intact.
    ///
    /// Keeping the filters is what makes the answer useful: the question is "does this
    /// term match anything *here*", not "anywhere". The operand's own marks are restored
    /// so an exact term is counted exactly and a prefix as a prefix — counting
    /// `=containment` as plain `containment` would report a number the query never used.
    static func parameters(
        _ base: SearchParameters, narrowedTo operand: ParsedOperand
    ) -> SearchParameters {
        var narrowed = base
        narrowed.keywords = queryText(for: operand)
        // The structured fields are alternative ways of specifying keywords; leaving them
        // set would AND them into a count that is supposed to be about one operand.
        narrowed.phrase = nil
        narrowed.prefixWildcard = nil
        narrowed.excludedTerms = []
        return narrowed
    }

    /// The search-box text that reproduces one operand on its own.
    static func queryText(for operand: ParsedOperand) -> String {
        switch operand.kind {
        case .word:
            return operand.isExact ? "=\(operand.text)" : operand.text
        case .phrase:
            return "\"\(operand.text)\""
        case .prefix, .proximity:
            // `text` already carries the `*` for a prefix and the whole `NEAR(...)` for a
            // proximity operand.
            return operand.text
        }
    }
}
