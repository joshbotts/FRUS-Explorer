// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

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
                })
        ) {
            sectionBody(kind)
        }
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
                    ForEach(buckets) { bucket in
                        row(bucket, in: kind, matchCount: facets.matchCount)
                    }
                    if kind == .years, facets.undatedCount > 0 {
                        // Reported, not dropped: otherwise the bars sum to less than the
                        // match with nothing explaining the gap.
                        Text(String(localized: "facets.undated",
                                    defaultValue: "\(facets.undatedCount.formatted()) matched documents carry no date and appear in no year above."))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    if let bound = facets.bounds[kind], bound.isTruncated {
                        // The house rule: no silent truncation. And the total is real —
                        // one common-term match spans 552 volumes and 14,615 person rollups.
                        Text(String(localized: "facets.bound",
                                    defaultValue: "Showing the top \(bound.shown) of \(bound.total.formatted())."))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    if kind == .provenance { provenanceCaveat(facets.provenanceCoverage) }
                    if kind == .volumes, let share = facets.topVolumeShare(3) {
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
            Button { onNarrow(narrowing) } label: { content }
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
