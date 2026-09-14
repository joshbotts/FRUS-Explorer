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
///   1.1 — #1297: `notApplied`, the operands a query typed but its expression leaves out, and
///         `hasUncountedOperands` / `replacingOperands(_:)`, so neither the count offer nor the
///         scoped-count rebuild reads past `operands` or loses a field
///   1.2 — #1297 join: `isApproximate`, carried by `replacingOperands(_:)`; the operands now include
///         the structured phrase, prefix and excluded terms, from the same combined parse the search runs
struct QueryInspection: Sendable, Equatable {

    /// The MATCH expression the query rendered to, or `nil` when there is none.
    let expression: RenderedExpression?

    /// The query's searchable units, in the order typed, each with what the index knows
    /// about it.
    let operands: [InspectedOperand]

    /// How many volumes this device has indexed — the denominator every count needs.
    ///
    /// Per-device and live. The corpus has 553 published volumes; what a count is "out
    /// of" is how many of them are indexed *here*, which is the number the researcher's
    /// claim actually rests on.
    let indexedVolumeCount: Int

    /// True when the query carries no FTS terms at all — a person filter alone, say.
    ///
    /// `SearchService.makeMatchExpressions` returns `(nil, nil)` for these and the search
    /// runs as a filter-only query. There is no expression to show, and saying so is
    /// better than showing an empty strip.
    let isFilterOnly: Bool

    /// Operands the researcher typed that the search leaves out, in the order typed.
    ///
    /// FTS5 has no universal set, so an `OR` alternative made only of exclusions — the
    /// `-korea` in `cold OR -korea` — has nothing to search for. The parser leaves it out of
    /// the expression and reports its operands in `ParsedQuery.droppedOperands`; they are
    /// carried here so the inspector can say they were **not applied**, rather than listing
    /// them among ``operands`` as if they had excluded something.
    ///
    /// Every one is an excluded term. The parser pushes a negation inward before deciding what to
    /// leave out, so `cold OR -(war -korea)` searches `korea` and leaves out only `war`; and beside a
    /// structured phrase or prefix nothing is left out at all, because that part gives every
    /// exclusion something to exclude from.
    ///
    /// Never counted and never blamed: ``QueryInspector/scopedCounts(for:parameters:)``,
    /// ``QueryInspector/emptyConjuncts(in:parameters:)`` and ``hasUncountedOperands`` read
    /// ``operands`` only, because a number for a term the query did not use describes
    /// nothing in the result set.
    ///
    /// A `var` with a default so every memberwise call site that predates it compiles
    /// unchanged — which is also why ``replacingOperands(_:)`` exists.
    var notApplied: [ParsedOperand] = []

    /// Whether the expression matches only part of what the query means — `ParsedQuery.isApproximate`.
    ///
    /// Not the same as `!notApplied.isEmpty`. Pushing a negation inward can leave out nothing but an
    /// operator word demoted to a search word, which has no operand row: `-( -korea NOT )` searches
    /// `korea` alone. The strip's narrower-than-typed caption reads this, so that case is still reported.
    ///
    /// A `var` with a default for the same reason as ``notApplied``.
    var isApproximate: Bool = false

    /// Whether every operand is present and none of them is the problem.
    var hasOperands: Bool { !operands.isEmpty }

    /// Whether the strip shows term rows at all: applied operands, or operands the query typed
    /// but did not apply.
    ///
    /// Not `hasOperands` alone: `and OR -korea` applies no operand (the literal `and` is not
    /// one) yet leaves `korea` out, and that row is the only place the researcher learns it.
    var showsTermRows: Bool { hasOperands || !notApplied.isEmpty }

    /// Whether any applied operand that is not excluded still lacks its scoped count — the
    /// condition for offering "Count each term in scope…".
    ///
    /// An excluded operand has no hit count to fetch, and a ``notApplied`` one was never
    /// searched, so neither may keep the offer open.
    var hasUncountedOperands: Bool {
        operands.contains { $0.scopedCount == nil && !$0.operand.isNegated }
    }

    /// This inspection with its operands replaced and every other fact carried across.
    ///
    /// The scoped-count pass rebuilds the operand list. Rebuilding the whole value at that
    /// call site would repeat every field, and a field added later with a default — as
    /// ``notApplied`` was — would silently fall back to it there, so the not-applied rows
    /// would vanish the moment the researcher asked for counts.
    func replacingOperands(_ operands: [InspectedOperand]) -> QueryInspection {
        QueryInspection(expression: expression, operands: operands,
                        indexedVolumeCount: indexedVolumeCount, isFilterOnly: isFilterOnly,
                        notApplied: notApplied, isApproximate: isApproximate)
    }
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

    /// How many times this operand's stem occurs in total, corpus-wide and unfiltered.
    ///
    /// The other half of the `fts5vocab` row that ``corpusDocumentFrequency`` reads — it was being
    /// fetched and discarded. Always `>= corpusDocumentFrequency` when both are present: a document
    /// containing the stem contains it at least once.
    ///
    /// `nil` on the same terms as ``corpusDocumentFrequency``.
    let corpusOccurrences: Int?

    /// Average corpus-wide occurrences per document containing the stem, or `nil` when either half
    /// is missing.
    ///
    /// The dispersion signal in one number. Near 1.0 the term is mentioned once wherever it appears;
    /// well above it, discussion concentrates. Both inputs are corpus-wide, so this says nothing
    /// about the researcher's current scope — and the surface that shows it must say so.
    var corpusOccurrencesPerDocument: Double? {
        guard let corpusOccurrences, let corpusDocumentFrequency, corpusDocumentFrequency > 0
        else { return nil }
        return Double(corpusOccurrences) / Double(corpusDocumentFrequency)
    }

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
///   **expensive**: one `searchCount` per operand, each a real query, run serially.
///
///   This doc previously put a common term at 6–12 s, which was measured but misattributed.
///   The Q-M2 prerequisite work found the cost was the unfiltered count's redundant join
///   against a 1.8 GB table; removing it took `"government"` (195,519 matches on the real
///   store) from **2.55 s to 0.011 s** cold for the same answer. A per-operand pass is now
///   sub-second per operand rather than ~9 s. It stays on demand anyway — serial, N
///   queries, and unbounded in N — but it is no longer the head-of-line blocker it was.
///
/// The split is the whole reason decision Q-2-1 lands where it does: the unscoped estimate
/// is what a type-ahead can afford, and the scoped exact count is what a published claim
/// needs.
///
/// Version history:
///   1.0 — Q-2a: initial implementation
///   1.1 — #1297: the parser's dropped operands become `QueryInspection.notApplied`, uncounted
///         and unblamed; `inspect(parsed:parameters:indexedVolumeCount:)` takes a caller's parse
///   1.2 — #1297 join: inspects `SearchService.parsedQuery(for:)`, the combined parse the search
///         renders, and carries its `isApproximate`; a structured operand is narrowed for counting
///         through its own field
struct QueryInspector: Sendable {

    /// The service every lookup runs through — counts, stems and vocabulary alike.
    ///
    /// One dependency rather than two, so the stems the inspector displays and the counts
    /// it reports provably come from the same store the search itself queries.
    let searchService: SearchService

    /// Creates an inspector.
    init(searchService: SearchService) {
        self.searchService = searchService
    }

    // MARK: - The cheap pass

    /// Describes `parameters` without running a search.
    ///
    /// - Parameter indexedVolumeCount: how many volumes this device has indexed. Supplied
    ///   by the caller because it is app state (`AppState.indexedVolumeIds`), and because
    ///   passing it in keeps this type testable without one.
    func inspect(parameters: SearchParameters, indexedVolumeCount: Int) async -> QueryInspection {
        // The corpus parse, unscoped: operands and their reporting do not depend on the column
        // prefix, and the corpus expression is the one the strip displays first.
        await inspect(parsed: SearchService.parsedQuery(for: parameters), parameters: parameters,
                      indexedVolumeCount: indexedVolumeCount)
    }

    /// Describes `parameters` from a parse the caller has already made, without running a
    /// search.
    ///
    /// ``inspect(parameters:indexedVolumeCount:)`` is this with the parse made by
    /// `SearchService.parsedQuery(for:)`, and is its only production caller. The split lets a
    /// test hand the inspector a `ParsedQuery` of a chosen shape — dropped operands included —
    /// and check what the inspector does with it against a real index, without depending on
    /// which queries the parser of the day happens to drop.
    ///
    /// - Parameters:
    ///   - parsed: the combined parse of `parameters.keywords` and its structured phrase, prefix
    ///     and excluded terms, or `nil` for none. Its `operands` are inspected; its
    ///     `droppedOperands` become ``QueryInspection/notApplied``; its `isApproximate` becomes
    ///     ``QueryInspection/isApproximate``.
    ///   - parameters: the query, which still supplies the rendered expression and the filters.
    ///   - indexedVolumeCount: how many volumes this device has indexed.
    func inspect(
        parsed: ParsedQuery?, parameters: SearchParameters, indexedVolumeCount: Int
    ) async -> QueryInspection {
        let expression = await renderedExpression(for: parameters)
        let operands = parsed?.operands ?? []

        var inspected: [InspectedOperand] = []
        for operand in operands {
            let stem = await stem(for: operand)
            // One `fts5vocab` row carries both halves; reading only `doc` fetched `cnt` and
            // discarded it. Same query, same cost.
            var profile: (documentFrequency: Int, occurrences: Int)?
            if let stem {
                profile = try? await searchService.corpusTermProfile(forStem: stem)
            }
            inspected.append(InspectedOperand(
                operand: operand, stem: stem,
                scopedCount: nil,
                corpusDocumentFrequency: profile?.documentFrequency,
                corpusOccurrences: profile?.occurrences))
        }

        return QueryInspection(
            expression: expression,
            operands: inspected,
            indexedVolumeCount: indexedVolumeCount,
            isFilterOnly: expression == nil && parameters.supportsFilterOnlySearch,
            // No stem or vocabulary lookup for these: a count beside a term the search did not
            // use would read as evidence about the result set.
            notApplied: parsed?.droppedOperands ?? [],
            isApproximate: parsed?.isApproximate ?? false
        )
    }

    /// The index term an operand's word resolves to, or `nil` when it has no single one.
    ///
    /// Only a bare word has a stem worth showing. A phrase is several words, a prefix is
    /// deliberately many, and a `NEAR(...)` is a whole expression — labelling any of them
    /// with one stem would be a lie of convenience.
    private func stem(for operand: ParsedOperand) async -> String? {
        guard operand.kind == .word else { return nil }
        return try? await searchService.indexStem(of: operand.text)
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
    /// beside the others would read as a hit count. Operands in
    /// ``QueryInspection/notApplied`` are not visited at all — the search never used them.
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
                scopedCount: count,
                corpusDocumentFrequency: item.corpusDocumentFrequency,
                corpusOccurrences: item.corpusOccurrences))
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
    /// query is empty. Neither is a ``QueryInspection/notApplied`` operand, which is not
    /// visited: the search never used it, whatever it would match on its own.
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

    /// Rebuilds `parameters` so its text is a single operand, keeping every filter and scope
    /// flag intact.
    ///
    /// Keeping the filters is what makes the answer useful: the question is "does this
    /// term match anything *here*", not "anywhere". The operand's own marks are restored
    /// so an exact term is counted exactly and a prefix as a prefix — counting
    /// `=containment` as plain `containment` would report a number the query never used.
    ///
    /// A typed operand is re-spelled as search-box text. A structured one goes back into its own
    /// field instead, because the two spellings are not always the same query: the prefix field
    /// `neg:oti` renders `"neg oti"*`, while typed `neg oti*` renders `"neg" AND "oti"*`. A
    /// structured operand is only ever a phrase or a prefix here — an excluded term is negated,
    /// and negated operands are never narrowed to.
    static func parameters(
        _ base: SearchParameters, narrowedTo operand: ParsedOperand
    ) -> SearchParameters {
        var narrowed = base
        // Every text field is cleared first; leaving one set would AND it into a count that is
        // supposed to be about one operand.
        narrowed.keywords = nil
        narrowed.phrase = nil
        narrowed.prefixWildcard = nil
        narrowed.excludedTerms = []
        switch operand.source {
        case .typed:
            narrowed.keywords = queryText(for: operand)
        case .structured:
            switch operand.kind {
            case .phrase:
                narrowed.phrase = operand.text
            case .prefix:
                // `text` carries the `*` the field appends itself.
                narrowed.prefixWildcard = String(operand.text.dropLast())
            case .word, .proximity:
                narrowed.keywords = queryText(for: operand)
            }
        }
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
