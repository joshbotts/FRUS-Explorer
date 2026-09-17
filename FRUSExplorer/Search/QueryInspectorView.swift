// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - QueryInspectorController

/// Owns the inspector's state and decides when it is affordable to refresh.
///
/// ## Why a controller rather than a `.task` in the view
/// The two passes cost wildly different amounts — the cheap one is three lookups, the
/// expensive one is a real query per operand at 6–12 s each on a full corpus. Keeping that
/// decision in one observable object means a view cannot accidentally trigger the
/// expensive pass by re-rendering, which is exactly the mistake a `.task(id:)` on a
/// frequently-changing value invites.
///
/// Version history:
///   1.0 — Q-2b: initial implementation
///   1.1 — #1297: the scoped-count update rebuilds through `replacingOperands(_:)`, so the
///         not-applied operands survive a request for counts
///   1.2 — #1297 round 2: `refresh` keeps the zero-result blame when the new inspection's operands are the old ones,
///         so a filter-only refresh landing after the new search's decomposition no longer wipes what it measured (A4)
@Observable
@MainActor
final class QueryInspectorController {

    /// The current inspection, or `nil` before the first one completes.
    private(set) var inspection: QueryInspection?

    /// Operands that returned nothing on their own, naming why a query came back empty.
    private(set) var emptyConjuncts: [ParsedOperand] = []

    /// Whether the expensive scoped-count pass is running.
    private(set) var isCountingScoped = false

    /// How long typing must settle before the cheap pass runs.
    ///
    /// Matches the `.task(id:)`-plus-sleep idiom used elsewhere in the app
    /// (`PersonCorrectionsView`, `ProjectHomeView`, `CollectionPreviewView`). Note the
    /// design handoff cites `SearchFilterView`'s reach counts as the precedent; that file
    /// contains no debounce at all — its reach values are precomputed taxonomy counts —
    /// so the idiom is taken from the three views that actually implement one.
    static let debounce: Duration = .milliseconds(300)

    /// Refreshes the cheap pass for `parameters`, after the debounce.
    ///
    /// Cancellation-aware: driven from `.task(id:)`, a new keystroke cancels the previous
    /// call during its sleep, so only the settled query costs anything.
    ///
    /// Clears ``emptyConjuncts`` only when the operands change. The blame names operands, and a change that keeps them —
    /// a filter or a scope — re-runs the search, whose own decomposition (keyed on the executed search, never on this
    /// refresh) replaces the blame. Clearing it here as well raced that decomposition: when the search and its
    /// per-operand counts finished inside the debounce, this refresh landed last and left the zero-result view claiming
    /// every term matches on its own, which nothing had measured (#1297 round 2, A4).
    func refresh(parameters: SearchParameters, service: SearchService?, indexedVolumeCount: Int) async {
        guard let service else { return }
        try? await Task.sleep(for: Self.debounce)
        guard !Task.isCancelled else { return }

        let inspector = QueryInspector(searchService: service)
        let result = await inspector.inspect(parameters: parameters,
                                             indexedVolumeCount: indexedVolumeCount)
        guard !Task.isCancelled else { return }
        // Edited terms invalidate the previous decomposition: leaving it up would blame a term the researcher has
        // since edited away. The same terms under a new filter do not, and their new decomposition is not ours to wipe.
        if result.operands.map(\.operand) != inspection?.operands.map(\.operand) {
            emptyConjuncts = []
        }
        inspection = result
    }

    /// Runs the expensive per-operand scoped counts on demand.
    func loadScopedCounts(parameters: SearchParameters, service: SearchService?) async {
        guard let service, let current = inspection, !isCountingScoped else { return }
        isCountingScoped = true
        defer { isCountingScoped = false }
        let counted = await QueryInspector(searchService: service)
            .scopedCounts(for: current, parameters: parameters)
        guard !Task.isCancelled else { return }
        // Every other fact — the not-applied operands included — carries across unchanged.
        inspection = current.replacingOperands(counted)
    }

    /// Works out which conjunct is empty, for the zero-result surface.
    func decomposeZeroResult(parameters: SearchParameters, service: SearchService?) async {
        guard let service, let current = inspection else { return }
        let found = await QueryInspector(searchService: service)
            .emptyConjuncts(in: current, parameters: parameters)
        guard !Task.isCancelled else { return }
        emptyConjuncts = found
    }
}

// MARK: - QueryInspectorStrip

/// The inspector's content: what the query became, and what each part of it matches.
///
/// Shared by both platforms — the macOS search window hosts it as a full-width strip
/// between the control rows and the sort bar, and iOS hosts it inside a disclosure card
/// under the search field.
///
/// ## The expression row never disappears
/// Decision Q-2-2, settled: the audience is researchers who publish method appendices, so
/// hiding the raw expression behind a "show technical detail" toggle optimises for the
/// wrong user. The disclosure collapses the *detail* rows, never the expression.
///
/// Version history:
///   1.0 — Q-2b: initial implementation
///   1.1 — #1297: a NOT APPLIED row for each operand the expression leaves out, never counted
///         or offered for counting; the excluded operand's line points at the expression shown above
///         ("removed wherever the expression above applies it", `search.inspector.excludedDetail.v2`),
///         because no shorter statement of where an exclusion applies holds for every query
///   1.2 — #1297 join: an ADVANCED tag on operands from the structured fields
///         (`search.inspector.structuredTag`), and a narrower-than-typed caption under the MATCH
///         line whenever the expression is an approximation (`search.inspector.approximateCaption`)
///   1.3 — #1297 fixes: both gates are read from the model — `QueryInspection.showsApproximateCaption` and
///         `InspectedOperand.showsStructuredTag` — so they are tested at runtime, not only by reading this file
///   1.4 — #1297 round 1: a refused query gets a line saying it cannot run (`search.inspector.refused`) where it
///         used to get nothing, or "filters only" beside a filter; the NOT APPLIED line no longer blames an OR
///         alternative, since `-(war -korea)` leaves war out with no OR typed (`search.inspector.notAppliedDetail`,
///         unshipped and reworded in place)
///   1.5 — #1297 round 2: the EXACT tag reads the operand's `isExactApplied`, which parser 6.4 decides per operand, so in
///         `(=cold OR war) =cold` only the second cold is tagged (A1); through `QueryInspection.isRefused`, the refused
///         line shows only for a query holding something searchable, never a lone `"` or `(` typed on the way to one (A2)
struct QueryInspectorStrip: View {

    /// What to render.
    let inspection: QueryInspection

    /// Whether the detail rows (operands, stems) are shown.
    let isExpanded: Bool

    /// Whether the expensive scoped-count pass is running.
    let isCountingScoped: Bool

    /// Invoked when the researcher asks for exact in-scope counts.
    let onRequestScopedCounts: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            expressionRow
            if isExpanded {
                if inspection.showsTermRows { operandRows }
                denominatorCaption
            }
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private var expressionRow: some View {
        if let expression = inspection.expression?.displayed {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                microTag(String(localized: "search.inspector.matchTag", defaultValue: "MATCH"))
                Text(expression)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(3)
                Spacer(minLength: 0)
            }
            // Here rather than among the detail rows: this row never collapses, and when what was
            // left out is a demoted operator word there is no NOT APPLIED row to say anything.
            if inspection.showsApproximateCaption {
                Text(String(localized: "search.inspector.approximateCaption",
                            defaultValue: "Narrower than typed: part of this query only excludes terms, and a search needs something to find, so that part was left out."))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if inspection.expression?.expressionsDiffer == true {
                Text(String(localized: "search.inspector.expressionsDiffer",
                            defaultValue: "Documents and your own summaries/notes are searched with different expressions, because only some of them are in scope."))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } else if inspection.isFilterOnly {
            Text(String(localized: "search.inspector.filterOnly",
                        defaultValue: "No text search — this query is filters only, so there is no expression to show."))
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if inspection.isRefused {
            Text(String(localized: "search.inspector.refused",
                        defaultValue: "No expression — this query cannot run: nothing is left to search for once its exclusions apply, or its parentheses nest more than \(FTS5InlineQueryParser.maximumGroupDepth) deep."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var operandRows: some View {
        ForEach(Array(inspection.operands.enumerated()), id: \.offset) { _, item in
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(item.operand.text)
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.medium)
                    if item.operand.isNegated {
                        microTag(String(localized: "search.inspector.excludedTag",
                                        defaultValue: "EXCLUDED"))
                    }
                    // Only where the search filters on the literal word, operand by operand: in `=cold OR war`
                    // no tag, and in `(=cold OR war) =cold` only on the second cold.
                    if item.operand.isExactApplied {
                        microTag(String(localized: "search.inspector.exactTag",
                                        defaultValue: "EXACT"))
                    }
                    // A term the researcher did not type into the box — a restored saved search's
                    // phrase, prefix or excluded term. No control sets those fields any more (the
                    // Advanced Filters sheet and popover lost them in Session 2026-06-08), so the tag
                    // names the Advanced fields the search was saved with, not a place to edit it.
                    if item.showsStructuredTag {
                        microTag(String(localized: "search.inspector.structuredTag",
                                        defaultValue: "ADVANCED"))
                    }
                    Spacer(minLength: 0)
                }
                Text(countLine(for: item))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if item.isStemBroadening, let stem = item.stem {
                    Label(
                        String(localized: "search.inspector.stemWarning",
                               defaultValue: "\(item.operand.text) is searched as \(stem) — other words with that root match too"),
                        systemImage: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }

        // Beside the operands, and before the count offer, which reads `operands` only: a term
        // the search did not use has no count to fetch.
        ForEach(Array(inspection.notApplied.enumerated()), id: \.offset) { _, operand in
            notAppliedRow(for: operand)
        }

        if !isCountingScoped, inspection.hasUncountedOperands {
            Button(String(localized: "search.inspector.countInScope",
                          defaultValue: "Count each term in scope…")) {
                onRequestScopedCounts()
            }
            .font(.caption2)
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
        } else if isCountingScoped {
            Text(String(localized: "search.inspector.counting", defaultValue: "Counting…"))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    /// One operand the expression leaves out: its text, a NOT APPLIED tag, and why.
    ///
    /// No count line, stem warning, or EXCLUDED/EXACT tag: each describes how a term took
    /// part in the search, and this one took none. The row is one accessibility element so
    /// VoiceOver reads the term, the tag and the reason together rather than as three
    /// unrelated fragments — where the strip is hosted directly, as in the macOS Search window.
    /// On iOS the strip sits inside a disclosure Button whose own accessibility label currently
    /// replaces all of its content, so VoiceOver reaches none of these rows there (a separate
    /// fix, not part of #1297).
    private func notAppliedRow(for operand: ParsedOperand) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 6) {
                Text(operand.text)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                microTag(String(localized: "search.inspector.notAppliedTag",
                                defaultValue: "NOT APPLIED"))
                Spacer(minLength: 0)
            }
            // Not "an OR alternative": `-(war -korea)` leaves war out with no OR typed, because pushing the
            // negation inward makes `NOT war` a part of its own beside `korea`.
            Text(String(localized: "search.inspector.notAppliedDetail",
                        defaultValue: "not searched — this part of the query only excludes, and a search needs something to find, so it was left out"))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    /// Every count names its scope, because a bare number is the thing this workstream
    /// exists to stop producing.
    private func countLine(for item: InspectedOperand) -> String {
        if item.operand.isNegated {
            // v2 (#1297): v1 said "documents containing this are removed", a removal from the
            // whole result set that was never true across OR — `cold -korea OR war` keeps war
            // documents that mention korea. Nor is "the terms typed with it" always the scope:
            // `NOT (cold OR -korea)` renders `"korea" NOT "cold"`, so cold is removed from korea's
            // matches across the OR it was typed in. The expression shown above is the one
            // statement that holds in every shape, so the line points at it.
            return String(localized: "search.inspector.excludedDetail.v2",
                          defaultValue: "excluded — documents containing this are removed wherever the expression above applies it")
        }
        var parts: [String] = []
        if let scoped = item.scopedCount {
            parts.append(String(localized: "search.inspector.scopedCount",
                                defaultValue: "\(scoped) in your current scope"))
        }
        if let corpus = item.corpusDocumentFrequency {
            parts.append(String(localized: "search.inspector.corpusCount",
                                defaultValue: "\(corpus) across everything you have indexed"))
        }
        // Occurrences, and only when they say something the document count does not.
        //
        // The two numbers can point in opposite directions: on this corpus "Article 43" appears in
        // 34 documents in 1948 and 11 in 1949, while its occurrences RISE 77 → 92, because one 1949
        // document carries 54 of them. A document count alone reads that as a topic disappearing.
        //
        // Shown only above 1.5 per document, because at 1.0-1.1 — which is most words — the ratio
        // is noise and a second number per pill would cost more attention than it returns. The
        // threshold is a display choice, not a claim about the data, so the number itself is always
        // exact when shown. Both figures are corpus-wide; `denominatorCaption` carries that.
        if let occurrences = item.corpusOccurrences,
           let perDocument = item.corpusOccurrencesPerDocument, perDocument >= 1.5 {
            parts.append(String(localized: "search.inspector.corpusOccurrences",
                                defaultValue: "\(occurrences) occurrences, \(perDocument.formatted(.number.precision(.fractionLength(1)))) per document"))
        }
        if parts.isEmpty {
            return String(localized: "search.inspector.noCount",
                          defaultValue: "no corpus count — this term has no single index form")
        }
        return parts.joined(separator: " · ")
    }

    private var denominatorCaption: some View {
        Text(String(localized: "search.inspector.denominator",
                    defaultValue: "Counts are over the \(inspection.indexedVolumeCount) volumes indexed on this device — not the whole published series."))
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }

    private func microTag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 3))
    }
}

// MARK: - QueryZeroResultView

/// What to show instead of "Try different keywords" — the reason the query is empty.
///
/// "No results" is indistinguishable from a typo, a stemming surprise, and a genuine
/// historical absence. Naming the conjunct that matched nothing tells those apart, and the
/// third case is a finding rather than a failure.
///
/// Version history:
///   1.0 — Q-2b: initial implementation
struct QueryZeroResultView: View {

    /// The inspection for the empty query.
    let inspection: QueryInspection

    /// Operands that matched nothing on their own.
    let emptyConjuncts: [ParsedOperand]

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(String(localized: "search.empty.title", defaultValue: "No Results"))
                .font(.headline)

            if emptyConjuncts.isEmpty {
                // Either the decomposition has not run, or every term matches on its own
                // and it is their combination that is empty — which is itself the answer.
                Text(inspection.hasOperands
                     ? String(localized: "search.empty.combination",
                              defaultValue: "Each of your terms matches something on its own — it is the combination that appears in no single document.")
                     : String(localized: "search.empty.detail",
                              defaultValue: "Try different keywords or adjust your filters."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text(emptyConjuncts.count == 1
                     ? String(localized: "search.empty.oneEmpty",
                              defaultValue: "\(emptyConjuncts[0].text) matches no document in your current scope. The rest of your query is not the problem.")
                     : String(localized: "search.empty.severalEmpty",
                              defaultValue: "\(emptyConjuncts.map(\.text).joined(separator: ", ")) match no document in your current scope."))
                    .font(.callout)
                    .multilineTextAlignment(.center)
            }

            Text(String(localized: "search.empty.denominator",
                        defaultValue: "0 here means 0 in what you have indexed — \(inspection.indexedVolumeCount) volumes on this device."))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: 420)
    }
}
