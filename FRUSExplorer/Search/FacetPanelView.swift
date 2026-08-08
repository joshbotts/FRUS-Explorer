// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import TipKit

// MARK: - FacetNarrowing

/// How a facet row narrows the search — and, for one section, that it cannot.
///
/// ## Four of five narrow through fields that already exist
/// The design's requirement is that a facet click applies through the **existing**
/// `SearchSQLFilters` fields, so facets and the filter sheet can never disagree. That holds
/// for years (`dateRange`), volumes (`volumeIds`), people (`personRollupId`) and document
/// type (`documentTypeFilter`) — and two of those already read back in the macOS filter row
/// for free, because that row is driven from the same parameters.
///
/// ## Provenance cannot, and pretending otherwise would be the wrong fix
/// `SearchSQLFilters` has no repository, record-group or citation-era field, and the design
/// is explicit that no new filter plumbing should be added here. So the provenance section
/// is **descriptive only**: it tells the researcher how the match is sourced without
/// offering a click that would have to invent a filter dimension. A disabled-looking row
/// that silently does nothing would be worse; the section says why instead.
///
/// Version history:
///   1.0 — R-1b: initial implementation
enum FacetNarrowing: Sendable, Equatable {

    /// Restrict to a single year.
    case year(String)
    /// Restrict to a single volume.
    case volume(String)
    /// Restrict to one person rollup.
    case person(Int)
    /// Restrict to primary documents or editorial notes.
    case documentType(DocumentTypeFilter)

    /// The narrowing a bucket in `section` represents, or `nil` when that section is
    /// descriptive only.
    static func forBucket(_ bucket: FacetBucket, in section: FacetSection) -> FacetNarrowing? {
        switch section {
        case .years:
            return .year(bucket.key)
        case .volumes:
            return .volume(bucket.key)
        case .people:
            return Int(bucket.key).map { .person($0) }
        case .documentType:
            // The aggregate keys on `is_editorial_note`, so "1" is the notes bucket.
            return .documentType(bucket.key == "1" ? .editorialNotesOnly : .documentsOnly)
        case .provenance:
            return nil
        }
    }

    /// Whether a section offers click-to-narrow at all.
    static func isNarrowable(_ section: FacetSection) -> Bool { section != .provenance }

    /// Applies this narrowing to `parameters`, in place.
    ///
    /// Every case writes a field the filter sheet also owns, which is what makes the two
    /// surfaces incapable of disagreeing.
    func apply(to parameters: inout SearchParameters) {
        switch self {
        case .year(let year):
            parameters.dateRange = DateRange(earliest: "\(year)-01-01", latest: "\(year)-12-31")
        case .volume(let volumeId):
            parameters.volumeIds = [volumeId]
        case .person(let rollupId):
            parameters.personRollupId = rollupId
            // A rollup and a single ref are alternative expressions of the same filter;
            // leaving a stale ref set would AND them and silently return fewer documents
            // than the facet promised.
            parameters.personRef = nil
        case .documentType(let filter):
            parameters.documentTypeFilter = filter
        }
    }
}

// MARK: - ActiveNarrowing

/// One narrowing currently in force, as something a surface can show and clear.
///
/// Derived from live filter state rather than remembered from the tap that set it, so it
/// cannot drift from what is actually filtering — and so it also covers filters set in the
/// filter sheet, not only those set from a facet.
///
/// Version history:
///   1.0 — R-1c: initial implementation
struct ActiveNarrowing: Sendable, Equatable, Identifiable {

    /// A stable key naming which dimension this is, used to clear it.
    let id: String

    /// What to show.
    let label: String
}

// MARK: - FacetPanelController

/// Owns the facet panel's state, and decides what is affordable to compute.
///
/// ## Lazy per section, cached per match
/// Decision R-1-1: a section is computed when it is first opened, not when the search runs.
/// Results are cached against a signature of the query and filters, so re-opening a section
/// is free while a new search invalidates everything — which matters because a stale facet
/// describing the *previous* result set is a wrong answer that looks entirely plausible.
///
/// Version history:
///   1.0 — R-1b: initial implementation
///   1.1 — Session 2026-08-07: per-section sort / page / filter state (#586)
@Observable
@MainActor
final class FacetPanelController {

    /// The breakdown so far. Sections not yet opened are empty in it.
    private(set) var facets: ResultSetFacets?

    /// Sections currently being computed, so each can show its own progress.
    private(set) var loadingSections: Set<FacetSection> = []

    /// Sections that have been computed for the current match.
    private(set) var loadedSections: Set<FacetSection> = []

    /// The last error, if a section failed. Kept per-panel rather than per-section: a
    /// failure here is a database error, not a per-facet condition.
    private(set) var failure: String?

    /// The match size immediately before the last facet narrow, so a count line can say what
    /// it narrowed *from*.
    ///
    /// This cannot be read off `facets` after the fact: a narrow re-runs the search, which
    /// invalidates the panel, and the recomputed sections describe the **narrowed** set. The
    /// figure only exists at the moment of the click, so it is captured there.
    private(set) var narrowedFrom: Int?

    /// Per-section sort, page size, page, and filter (#586).
    ///
    /// Here rather than in the view because the panel's lifetime is the panel's, not the
    /// match's: `FacetPanelView` keeps its identity across searches, so `@State` would carry a
    /// stale page index into a result set that has no such page.
    private(set) var display: [FacetSection: FacetDisplayState] = [:]

    /// Set by ``recordNarrowing(from:)`` and promoted by the next ``invalidate(signature:)``.
    ///
    /// `invalidate` fires for two different reasons — a facet narrow and an unrelated new
    /// query — and only the first should preserve a "narrowed from". The hand-off through a
    /// pending slot is what tells them apart.
    private var pendingNarrowedFrom: Int?

    /// The match this data describes. Changing it clears everything.
    private var signature: String?

    /// Discards everything when the search changes.
    ///
    /// Called with a signature derived from the query and filters. A section computed for
    /// one result set must never be shown beside another.
    func invalidate(signature newSignature: String) {
        guard newSignature != signature else { return }
        signature = newSignature
        facets = nil
        loadedSections = []
        loadingSections = []
        failure = nil
        // A narrow hands its pre-count forward exactly once; any other new search clears it,
        // so "narrowed from" never survives into a query it does not describe.
        narrowedFrom = pendingNarrowedFrom
        pendingNarrowedFrom = nil
        // Sort and page size are the researcher's stated preference and survive; the page
        // index and the filter text describe the *previous* result set and do not. Carrying
        // "Dulles" into a narrowed match would show an empty People section with a filter the
        // user has stopped looking at, which reads as a broken facet rather than a filtered
        // one — the same reason the panel invalidates its rows at all.
        for key in display.keys {
            display[key]?.pageIndex = 0
            display[key]?.filterText = ""
        }
    }

    /// The display state for `section`, defaulted on first use.
    func displayState(for section: FacetSection) -> FacetDisplayState {
        display[section] ?? .standard(for: section)
    }

    /// Reorders `section`, returning to its first page.
    ///
    /// The page index cannot survive a re-sort: page 4 of an alphabetical list holds different
    /// people from page 4 of a count-ordered one, so keeping the number would move the reader
    /// somewhere they did not ask to go.
    func setSort(_ sort: FacetSort, for section: FacetSection) {
        var state = displayState(for: section)
        state.sort = sort
        state.pageIndex = 0
        display[section] = state
    }

    /// Resizes `section`'s page, returning to its first page.
    func setPageSize(_ size: FacetPageSize, for section: FacetSection) {
        var state = displayState(for: section)
        state.pageSize = size
        state.pageIndex = 0
        display[section] = state
    }

    /// Turns to a page. Out-of-range values are clamped by ``FacetPaging``, not here, so the
    /// clamp is applied against the rows that actually exist.
    func setPage(_ index: Int, for section: FacetSection) {
        var state = displayState(for: section)
        state.pageIndex = max(0, index)
        display[section] = state
    }

    /// Filters `section` by label substring, returning to its first page.
    func setFilter(_ text: String, for section: FacetSection) {
        var state = displayState(for: section)
        state.filterText = text
        state.pageIndex = 0
        display[section] = state
    }

    /// Records the match size a facet click is about to narrow away from.
    ///
    /// Call immediately before applying the narrowing, while the figure still exists.
    func recordNarrowing(from matchCount: Int?) {
        pendingNarrowedFrom = matchCount
    }

    /// Computes `section` if it has not been computed for the current match.
    func load(
        _ section: FacetSection,
        parameters: SearchParameters,
        service: SearchService?,
        pipeline: IndexingPipeline?
    ) async {
        guard let service, let pipeline else { return }
        guard !loadedSections.contains(section), !loadingSections.contains(section) else { return }
        loadingSections.insert(section)
        defer { loadingSections.remove(section) }

        do {
            let expressions = try await service.matchExpressions(for: parameters)
            let filters = await service.filtersForTesting(parameters)
            let computed = try await pipeline.resultSetFacets(
                corpusMatch: expressions.corpus, userContentMatch: expressions.userContent,
                filters: filters, request: .one(section))
            guard !Task.isCancelled else { return }
            facets = Self.merge(computed, into: facets, section: section)
            loadedSections.insert(section)
            failure = nil
        } catch {
            // A filter-only query with no filters throws `emptyQuery`; that is not a facet
            // failure and should not paint an error into the panel.
            if case FTS5Error.emptyQuery = error { return }
            failure = String(describing: error)
        }
    }

    /// Folds one freshly-computed section into the accumulated breakdown.
    ///
    /// Only the requested section's rows and bound are taken, so a section computed earlier
    /// is not clobbered by a later request that did not ask for it.
    static func merge(
        _ new: ResultSetFacets, into existing: ResultSetFacets?, section: FacetSection
    ) -> ResultSetFacets {
        let base = existing ?? .empty(matchCount: new.matchCount)
        var bounds = base.bounds
        if let bound = new.bounds[section] { bounds[section] = bound }
        return ResultSetFacets(
            // The match count comes from whichever computation ran most recently; every one
            // of them measures the same set.
            matchCount: new.matchCount,
            years: section == .years ? new.years : base.years,
            undatedCount: section == .years ? new.undatedCount : base.undatedCount,
            volumes: section == .volumes ? new.volumes : base.volumes,
            people: section == .people ? new.people : base.people,
            documentTypes: section == .documentType ? new.documentTypes : base.documentTypes,
            provenance: section == .provenance ? new.provenance : base.provenance,
            provenanceCoverage: section == .provenance
                ? new.provenanceCoverage : base.provenanceCoverage,
            bounds: bounds)
    }
}

// MARK: - FacetPanelView

/// The facet panel: what the result set contains, broken down five ways.
///
/// Shared so R-1c's iOS sheet renders the identical content; only the container differs.
///
/// Version history:
///   1.0 — R-1b: initial implementation
///   1.1 — Session 2026-08-07: sort pickers, paging, and a filter field (#586)
struct FacetPanelView: View {

    /// The panel's state.
    let controller: FacetPanelController

    /// The match size, from the search itself — the denominator the panel describes.
    ///
    /// Passed in rather than read from `facets` so the preamble can be honest before any
    /// section has loaded, and `nil` when the search could not count it (see the Q-M2 work).
    let matchCount: Int?

    /// How many results the list is currently showing, for the checklist-mode note.
    let displayedCount: Int

    /// Whether the match behind these facets is a subset of the answer to the question — because
    /// the fetch capped, or because the search is inside a corpus that was itself a capped capture.
    ///
    /// Beside ``matchCount`` deliberately: it is the qualifier on that denominator.
    let isPartialEvidence: Bool

    /// Whether checklist mode is hiding reviewed rows.
    let isChecklistHiding: Bool

    /// Called when a facet row is clicked, for the sections that can narrow.
    let onNarrow: (FacetNarrowing) -> Void

    /// Called when a section is first disclosed, so the controller can compute it.
    let onDiscloseSection: (FacetSection) -> Void

    @State private var expanded: Set<FacetSection> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                preamble
                if isChecklistHiding { checklistNote }
                if let failure = controller.failure { failureNote(failure) }

                section(.years, title: String(localized: "facets.years", defaultValue: "Years"))
                section(.volumes, title: String(localized: "facets.volumes", defaultValue: "Volumes"))
                section(.people, title: String(localized: "facets.people", defaultValue: "People"))
                section(.documentType,
                        title: String(localized: "facets.documentType", defaultValue: "Document type"))
                section(.provenance,
                        title: String(localized: "facets.provenance", defaultValue: "Archival provenance"))
            }
            .padding(.vertical, 12)
        }
    }

    // MARK: - Preamble

    private var preamble: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(matchCount.map {
                String(localized: "facets.preamble",
                       defaultValue: "Describing all \($0.formatted()) matches")
            } ?? String(localized: "facets.preamble.unknown",
                        defaultValue: "Describing this result set — total unavailable"))
                .font(.callout.weight(.medium))
            // The distinction the design asks for, and the one the Q-M2 work showed matters:
            // the result *list* is capped while these counts are not.
            Text(String(localized: "facets.preamble.detail",
                        defaultValue: "Facets read the whole match, before any narrowing you apply below."))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        // #597 Phase 1, and the one SHARED anchor in the set — this file carries no `#if os` gate
        // and is hosted by both SearchView and SearchSheet, so one modifier reaches every platform.
        // On the preamble, not the rows: attaching to the row Button would mint one popover per
        // facet row, dozens per section.
        .popoverTip(FacetNarrowTip())
    }

    private var checklistNote: some View {
        Label(
            String(localized: "facets.checklistNote",
                   defaultValue: "Checklist mode is hiding reviewed results. These facets still describe the whole match, not the \(displayedCount.formatted()) shown."),
            systemImage: "checklist")
            .font(.caption2)
            .foregroundStyle(.orange)
            .padding(.horizontal)
    }

    private func failureNote(_ message: String) -> some View {
        Label(
            String(localized: "facets.failure",
                   defaultValue: "This breakdown could not be computed."),
            systemImage: "exclamationmark.triangle")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .help(message)
            .padding(.horizontal)
    }

    // MARK: - Sections

    @ViewBuilder
    private func section(_ kind: FacetSection, title: String) -> some View {
        AnalyticsCollapsibleSection(
            title: title,
            isExpanded: Binding(
                get: { expanded.contains(kind) },
                set: { isOpen in
                    if isOpen {
                        expanded.insert(kind)
                        // Lazy per decision R-1-1: nothing is computed until it is asked for.
                        onDiscloseSection(kind)
                    } else {
                        expanded.remove(kind)
                    }
                }),
            controls: { sectionControls(kind) }
        ) {
            sectionBody(kind)
        }
    }

    // MARK: - Section controls (#586)

    /// The sort picker, page-size picker, and filter field for one section.
    ///
    /// Rendered only once the section's rows exist and only where each control earns its
    /// space: a sort picker on the three sections whose ordering is a real choice, a page-size
    /// picker only when there is more than one page's worth to show, and a filter field only
    /// where the list is long enough that reading it is not an option.
    @ViewBuilder
    private func sectionControls(_ kind: FacetSection) -> some View {
        if let facets = controller.facets, case let buckets = rows(for: kind, in: facets),
           !buckets.isEmpty {
            let state = controller.displayState(for: kind)
            let sorts = FacetSort.choices(for: kind)
            let needsPaging = buckets.count > (FacetPageSize.top5.rowCount ?? 5)

            if !sorts.isEmpty || needsPaging {
                HStack(spacing: 8) {
                    if !sorts.isEmpty {
                        Menu {
                            Picker(String(localized: "facets.sort.label", defaultValue: "Sort"),
                                   selection: Binding(
                                    get: { state.sort },
                                    set: { controller.setSort($0, for: kind) })) {
                                ForEach(sorts, id: \.self) { sort in
                                    Text(sort.title(for: kind)).tag(sort)
                                }
                            }
                            .pickerStyle(.inline)
                            .labelsHidden()
                        } label: {
                            controlLabel("arrow.up.arrow.down", state.sort.title(for: kind))
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                        .accessibilityLabel(String(localized: "facets.sort.a11y",
                                                   defaultValue: "Sort order"))
                    }

                    if needsPaging {
                        Menu {
                            Picker(String(localized: "facets.page.label", defaultValue: "Show"),
                                   selection: Binding(
                                    get: { state.pageSize },
                                    set: { controller.setPageSize($0, for: kind) })) {
                                ForEach(FacetPageSize.allCases, id: \.self) { size in
                                    Text(size.title).tag(size)
                                }
                            }
                            .pickerStyle(.inline)
                            .labelsHidden()
                        } label: {
                            controlLabel("list.bullet", state.pageSize.title)
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                        .accessibilityLabel(String(localized: "facets.page.a11y",
                                                   defaultValue: "Rows per page"))
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal)
            }

            // Only where a page turner alone would not be navigation. Measured: a whole-corpus
            // match spans 16,385 person rollups, which is 656 pages of 25 — reachable in
            // principle and findable by nobody.
            //
            // Never on a bounded section, even a long one: years runs to 203 rows, but
            // "filter the years by substring" is not a thing a reader wants, and offering it
            // would make the control mean something different in different sections.
            if !kind.hasBoundedDomain, buckets.count > Self.filterFieldThreshold {
                facetFilterField(kind, rowCount: buckets.count, text: state.filterText)
            }
        }
    }

    /// The row count above which an unbounded section gets a filter field.
    ///
    /// Above four pages of 25 the list has stopped being something a reader scans.
    static let filterFieldThreshold = 100

    private func facetFilterField(_ kind: FacetSection, rowCount: Int, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField(
                String(localized: "facets.filter.prompt",
                       defaultValue: "Filter \(rowCount.formatted()) rows"),
                text: Binding(get: { text },
                              set: { controller.setFilter($0, for: kind) }))
                .textFieldStyle(.plain)
                .font(.caption)
                #if os(iOS)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                #endif
            if !text.isEmpty {
                Button {
                    controller.setFilter("", for: kind)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "facets.filter.clear",
                                           defaultValue: "Clear filter"))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal)
    }

    private func controlLabel(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: symbol)
            Text(text)
            Image(systemName: "chevron.down")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func sectionBody(_ kind: FacetSection) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if controller.loadingSections.contains(kind) {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text(String(localized: "facets.counting", defaultValue: "Counting…"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else if let facets = controller.facets {
                let buckets = rows(for: kind, in: facets)
                if buckets.isEmpty {
                    Text(String(localized: "facets.none",
                                defaultValue: "Nothing to break down here."))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    let page = FacetPaging.page(buckets,
                                                with: controller.displayState(for: kind))
                    if page.rows.isEmpty {
                        // Only reachable through the filter field — the empty aggregate is
                        // handled above — so it names the filter as the cause rather than
                        // letting the section look like it holds nothing.
                        Text(String(localized: "facets.filter.noMatches",
                                    defaultValue: "No rows contain that. Clear the filter to see all \(page.totalCount.formatted())."))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(page.rows) { bucket in
                        row(bucket, in: kind, matchCount: facets.matchCount)
                    }
                    pageFooter(page, in: kind)
                    if kind == .years, facets.undatedCount > 0 {
                        // Reported, not dropped: otherwise the bars sum to less than the
                        // match with nothing explaining the gap.
                        Text(String(localized: "facets.undated",
                                    defaultValue: "\(facets.undatedCount.formatted()) matched documents carry no date and appear in no year above."))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    if let bound = facets.bounds[kind], bound.isTruncated {
                        // The house rule: no silent truncation. Since #586 this fires only if
                        // the 20,000-row fetch ceiling bit, which no real section reaches —
                        // the largest measured is 16,385 person rollups. The everyday "you are
                        // seeing part of this" is `pageFooter`'s to say.
                        Text(String(localized: "facets.bound",
                                    defaultValue: "This breakdown stopped at \(bound.shown.formatted()) of \(bound.total.formatted()) values."))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    if kind == .provenance { provenanceCaveat(facets.provenanceCoverage) }
                    // Suppressed outright when the evidence is partial. "The top three hold
                    // 60%" over a BM25-selected subset is partly a statement about the ranking
                    // that selected it, and unlike a count there is no caveat that repairs a
                    // concentration figure — the honest move is not to make the claim.
                    if kind == .volumes, !isPartialEvidence, let share = facets.topVolumeShare(3) {
                        // Computed, never templated: the design's "Top 3 hold 60%" is 1.7%
                        // for a common term across 552 volumes, so it is only worth saying
                        // when it is actually a concentration.
                        if share >= 0.25 {
                            Text(String(localized: "facets.concentration",
                                        defaultValue: "The top three hold \(Int((share * 100).rounded()))% of the match."))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    /// What the section is showing, and the controls to see the rest (#586).
    ///
    /// The count line is unconditional whenever the rows are a subset — of the section or of
    /// the filter — because the house rule that made the old "Showing the top 50 of 552"
    /// caption exist applies just as much to a page as to a cut. It is suppressed only when
    /// the reader is already looking at everything.
    @ViewBuilder
    private func pageFooter(_ page: FacetPage, in kind: FacetSection) -> some View {
        let isShowingEverything = !page.hasMultiplePages && !page.isFiltered
        if !isShowingEverything, !page.rows.isEmpty {
            HStack(spacing: 8) {
                Text(page.isFiltered
                     ? String(localized: "facets.page.rangeFiltered",
                              defaultValue: "\(page.firstRowNumber)–\(page.firstRowNumber + page.rows.count - 1) of \(page.matchingCount.formatted()) matching, \(page.totalCount.formatted()) in all")
                     : String(localized: "facets.page.range",
                              defaultValue: "Showing \(page.firstRowNumber)–\(page.firstRowNumber + page.rows.count - 1) of \(page.matchingCount.formatted())"))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer(minLength: 0)
                if page.hasMultiplePages {
                    Button {
                        controller.setPage(page.pageIndex - 1, for: kind)
                    } label: { Image(systemName: "chevron.left") }
                        .buttonStyle(.plain)
                        .disabled(page.pageIndex == 0)
                        .accessibilityLabel(String(localized: "facets.page.previous",
                                                   defaultValue: "Previous page"))
                    Text(String(localized: "facets.page.indicator",
                                defaultValue: "\(page.pageIndex + 1) / \(page.pageCount)"))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Button {
                        controller.setPage(page.pageIndex + 1, for: kind)
                    } label: { Image(systemName: "chevron.right") }
                        .buttonStyle(.plain)
                        .disabled(page.pageIndex >= page.pageCount - 1)
                        .accessibilityLabel(String(localized: "facets.page.next",
                                                   defaultValue: "Next page"))
                }
            }
            .font(.caption2)
            .padding(.top, 2)
        }
    }

    private func rows(for kind: FacetSection, in facets: ResultSetFacets) -> [FacetBucket] {
        switch kind {
        case .years: return facets.years
        case .volumes: return facets.volumes
        case .people: return facets.people
        case .documentType: return facets.documentTypes.map {
            FacetBucket(key: $0.key,
                        label: $0.key == "1"
                            ? String(localized: "facets.type.editorialNotes",
                                     defaultValue: "Editorial notes")
                            : String(localized: "facets.type.documents",
                                     defaultValue: "Documents"),
                        count: $0.count)
        }
        case .provenance: return facets.provenance
        }
    }

    @ViewBuilder
    private func row(_ bucket: FacetBucket, in kind: FacetSection, matchCount: Int) -> some View {
        let narrowing = FacetNarrowing.forBucket(bucket, in: kind)
        let content = HStack(spacing: 6) {
            Text(bucket.label)
                .font(.caption)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(bucket.count.formatted())
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())

        if let narrowing {
            Button {
                // The user learned that rows are filters — retire the tip.
                FacetNarrowTip().invalidate(reason: .actionPerformed)
                onNarrow(narrowing)
            } label: { content }
                .buttonStyle(.plain)
                .help(String(localized: "facets.row.help",
                             defaultValue: "Narrow the search to \(bucket.label)"))
        } else {
            // Descriptive only — see `FacetNarrowing`. No button, so there is nothing to
            // click that would do nothing.
            content
        }
    }

    private func provenanceCaveat(_ coverage: ProvenanceCoverage) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            // Two denominators, because "parsed at all" and "named a record group" are
            // different numbers and the design's single caveat conflates them.
            Text(String(localized: "facets.provenance.coverage",
                        defaultValue: "Source notes parsed for \(coverage.parsed.formatted()) of \(coverage.matchCount.formatted()) matches; \(coverage.withRecordGroup.formatted()) name a record group."))
            Text(String(localized: "facets.provenance.descriptiveOnly",
                        defaultValue: "Descriptive only — the search has no provenance filter to narrow to."))
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }
}
