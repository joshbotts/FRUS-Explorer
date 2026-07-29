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
    func refresh(parameters: SearchParameters, service: SearchService?, indexedVolumeCount: Int) async {
        guard let service else { return }
        try? await Task.sleep(for: Self.debounce)
        guard !Task.isCancelled else { return }

        let inspector = QueryInspector(searchService: service)
        let result = await inspector.inspect(parameters: parameters,
                                             indexedVolumeCount: indexedVolumeCount)
        guard !Task.isCancelled else { return }
        inspection = result
        // A fresh query invalidates the previous decomposition. Leaving it up would blame
        // a term the researcher has since edited away.
        emptyConjuncts = []
    }

    /// Runs the expensive per-operand scoped counts on demand.
    func loadScopedCounts(parameters: SearchParameters, service: SearchService?) async {
        guard let service, let current = inspection, !isCountingScoped else { return }
        isCountingScoped = true
        defer { isCountingScoped = false }
        let counted = await QueryInspector(searchService: service)
            .scopedCounts(for: current, parameters: parameters)
        guard !Task.isCancelled else { return }
        inspection = QueryInspection(
            expression: current.expression, operands: counted,
            indexedVolumeCount: current.indexedVolumeCount, isFilterOnly: current.isFilterOnly)
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
                if inspection.hasOperands { operandRows }
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
                    if item.operand.isExact {
                        microTag(String(localized: "search.inspector.exactTag",
                                        defaultValue: "EXACT"))
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

        if !isCountingScoped, inspection.operands.contains(where: { $0.scopedCount == nil && !$0.operand.isNegated }) {
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

    /// Every count names its scope, because a bare number is the thing this workstream
    /// exists to stop producing.
    private func countLine(for item: InspectedOperand) -> String {
        if item.operand.isNegated {
            return String(localized: "search.inspector.excludedDetail",
                          defaultValue: "excluded — documents containing this are removed")
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
