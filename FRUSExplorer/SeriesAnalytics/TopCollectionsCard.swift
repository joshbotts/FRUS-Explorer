// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - TopCollectionsCard

/// "Which collections carried this scope" — the collection-grain narrative on the Archival
/// Sourcing page (#835).
///
/// ## Why the narrative lives here and the instrument does not
/// The page above this card answers *what kind* of record FRUS drew on, in ten broad provenance
/// categories. It has never been able to name one. This card names them — and stops there. The
/// query-driven instrument (era switching, unit lens, weights, co-citation, flows) stays in
/// Archival Analytics: §8's assessment of the owner's relocation question was **relocate no,
/// layer yes**, because the guide's three containers cannot host a gesture-owning full-frame
/// canvas, while the *narrative* is series-analytics subject matter by the governance blueprint's
/// own line test.
///
/// ## One derivation, and why that is not a slogan
/// The rows come from ``ArchivalCollectionsData/ranking(bands:lens:weight:hidingUmbrella:limit:)``
/// — the same call the Collections mode makes, over a coverage map built by the same shared
/// ``ArchivalVolumeCoverage/map(from:limitedTo:)``. Nothing about the ranking is re-implemented
/// here, which is what makes the parity test meaningful: it drives both surfaces' calls over one
/// real subseries and compares the rows.
///
/// ## Three things this card must say, and does
/// 1. **Its population is not the charts' population.** `SourceProvenanceData` floors at decade
///    1900 and its artifact covers 522 volumes; the archival authority covers 552 and has no
///    floor. Sixty-eight volumes sit in coverage decades before 1900. Rows here can therefore rest
///    on volumes no chart above draws.
/// 2. **Its colours are not the charts' colours.** Above, ten `SourceProvenanceCategory` cases
///    classify the *parsed source note*; here, four `ArchivalRepositoryCategory` cases classify
///    the *collection's holder*. `ArchivalAnalyticsAxes` argues at length why the two must not be
///    folded, so the card carries its own legend and says what it is colouring.
/// 3. **Its eras are coarser than the charts' decades.** The year range selects the era bands it
///    OVERLAPS, so a range ending 1965 still shows the whole 1961–1968 band.
///
/// ## Cost
/// The two bundled artifacts behind this are ~2.5 MB of JSON. They are lazy `static let` globals,
/// so whichever thread touches one first pays its decode — and this page is reachable
/// mid-onboarding. Both touches therefore happen inside a detached task, and the reload is keyed
/// on the **scope** only: dragging the year range re-ranks an in-memory table and must never
/// rebuild the derivation.
///
/// Version history:
///   1.0 — Session 2026-08-11: #835
struct TopCollectionsCard: View {

    /// The manifest entries the coverage map is built from — the page's own, so the card and the
    /// charts above it read one manifest.
    let entries: [VolumeManifestEntry]
    /// The page's active scope.
    let scope: SeriesScope
    /// The page's year range, which selects the era bands this card covers.
    let yearStart: Int
    /// The end of the page's year range.
    let yearEnd: Int
    /// Whether the reader is mid-onboarding, which lowers the load's priority.
    var isOnboarding: Bool = false
    /// Opens a collection's record. `nil` withholds the affordance rather than drawing a row that
    /// does nothing.
    var onOpenCollection: ((AuthorityCollectionRecord) -> Void)?

    /// The derivation, `nil` until the first load finishes.
    @State private var data: ArchivalCollectionsData?

    /// How many rows the card draws — the instrument's own cap, so the two agree row for row.
    private static let rowLimit = ArchivalCollectionsData.rowCap

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if let data {
                let ranking = ranking(from: data)
                if ranking.rows.isEmpty {
                    emptyState
                } else {
                    rows(ranking)
                    legend
                    footnotes(ranking, data: data)
                }
            } else {
                loading
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Keyed on the SCOPE, never the year range: the range picks bands out of a table that is
        // already built, and rebuilding 2.5 MB on a slider drag would be a stall per frame.
        .task(id: scopeSignature) { await load() }
    }

    // MARK: - Derivation

    /// The scope as one comparable value, so `.task(id:)` can watch it.
    private var scopeSignature: String {
        scope.volumeIds.map { $0.sorted().joined(separator: ",") } ?? "whole"
    }

    /// The era bands the page's year range OVERLAPS.
    ///
    /// Overlap, not containment: the first band runs 1861–1947 and holds 261 of the 552 volumes,
    /// so "the band starts inside the range" would drop it for any range beginning after 1861 —
    /// silently discarding almost half the series. The default 1861…1993 selects all five.
    private var bands: [ArchivalEraBand] {
        ArchivalEraBand.all.filter { $0.startYear <= yearEnd && $0.endYear >= yearStart }
    }

    /// Documents where the usage index supports it, volumes otherwise.
    ///
    /// Not a preference: without the usage index there are no document counts at all, and a card
    /// that silently drew an empty ranking would read as "FRUS cites nothing here".
    private var weight: ArchivalWeight {
        (data?.supportsDocumentWeight ?? true) ? .documents : .volumes
    }

    private func ranking(from data: ArchivalCollectionsData) -> ArchivalRanking {
        data.ranking(bands: bands, lens: .namedCollections, weight: weight,
                     hidingUmbrella: true, limit: Self.rowLimit)
    }

    /// Builds the derivation off the main actor.
    private func load() async {
        let requested = scopeSignature
        let coverage = ArchivalVolumeCoverage.map(from: entries, limitedTo: scope.volumeIds)
        // Onboarding is already indexing the reader's first volumes; this is a page they are
        // reading, not waiting on.
        let priority: TaskPriority = isOnboarding ? .utility : .userInitiated
        let built = await Task.detached(priority: priority) {
            // Both `.shared` touches are INSIDE the detached block — see the type's note on cost.
            ArchivalCollectionsData.make(
                authority: CollectionAuthorityStore.shared?.collections ?? [],
                usage: CollectionUsageIndexStore.shared,
                coverage: coverage)
        }.value
        guard requested == scopeSignature else { return }
        data = built
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(String(localized: "series.provenance.topCollections.title",
                        defaultValue: "Which collections carried this scope"))
                .font(.headline)
            Text(String(localized: "series.provenance.topCollections.caption",
                        defaultValue: "The charts above group source notes into broad kinds of record. These are the individual bodies of records inside them, ranked by how many documents each supplied."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var loading: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text(String(localized: "series.provenance.topCollections.loading",
                        defaultValue: "Reading the archival authority…"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }

    private var emptyState: some View {
        Text(String(localized: "series.provenance.topCollections.empty",
                    defaultValue: "No named collection is recorded for the volumes in this scope. That is an answer about the scope, not a gap in the app — before 1948 the volumes cite filing-system classes far more often than named collections."))
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func rows(_ ranking: ArchivalRanking) -> some View {
        let maximum = max(ranking.rows.first?.value ?? 1, 1)
        VStack(alignment: .leading, spacing: 6) {
            ForEach(ranking.rows) { row in
                collectionRow(row, maximum: maximum)
            }
        }
    }

    @ViewBuilder
    private func collectionRow(_ row: ArchivalRankingRow, maximum: Int) -> some View {
        let opens = onOpenCollection != nil && data?.record(forId: row.id) != nil
        Button {
            guard let record = data?.record(forId: row.id) else { return }
            onOpenCollection?(record)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    // `label`, not `name`: the ranking appends the repository to names carried by
                    // more than one record, and several libraries hold a "White House Central
                    // Files".
                    Text(row.label)
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(row.value, format: .number)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    if opens {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                GeometryReader { proxy in
                    Capsule()
                        .fill(row.category.color)
                        .frame(width: max(proxy.size.width * bar(row, maximum: maximum), 2))
                }
                .frame(height: 5)
            }
            // A greedy frame first, then the shape: without both, only the glyphs are tappable.
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!opens)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(row.name)
        .accessibilityValue(row.category.displayName)
        .accessibilityAddTraits(opens ? .isButton : [])
    }

    private func bar(_ row: ArchivalRankingRow, maximum: Int) -> Double {
        min(1, max(0, Double(row.value) / Double(maximum)))
    }

    /// The custodian legend — its own, because these four buckets are not the ten above.
    private var legend: some View {
        HStack(spacing: 10) {
            ForEach(ArchivalRepositoryCategory.ordered, id: \.self) { category in
                HStack(spacing: 4) {
                    Circle().fill(category.color).frame(width: 7, height: 7)
                    Text(category.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, 2)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func footnotes(_ ranking: ArchivalRanking, data: ArchivalCollectionsData) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(coverageSentence(ranking))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let withheld = ranking.hiddenUmbrellaValue {
                // No umbrella chip on this page, so the withheld figure is stated rather than
                // offered: the State Department's central files supply more than twice the next
                // collection, and a bar for them would flatten every other one.
                Text(String(format: String(
                    localized: "series.provenance.topCollections.umbrella %lld",
                    defaultValue: "The State Department's central files are withheld from this ranking — one undifferentiated record carrying %lld here, which would flatten every other bar. Archival Analytics can show it."),
                    Int64(withheld)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !data.supportsDocumentWeight {
                Text(String(localized: "series.provenance.topCollections.volumesFallback",
                            defaultValue: "Counted in volumes, not documents: the document-level index is unavailable in this build, so these bars say how many volumes drew on each collection."))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(String(localized: "series.provenance.topCollections.method",
                        defaultValue: "Colours group collections by who holds the records — four custodians, not the ten categories above, which classify the citation rather than its holder. Eras here are coarser than the decades above, so a year range ending mid-era still covers the whole era. This ranking reads the archival authority, which spans all 552 catalogued volumes and has no 1900 floor, so it can rest on volumes the charts above leave out."))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 2)
    }

    /// How much of the scope the drawn rows account for — never a bare "top 12".
    private func coverageSentence(_ ranking: ArchivalRanking) -> String {
        let eras = bands.map(\.title).joined(separator: ", ")
        if let share = ranking.shownShare(weight: weight) {
            let percent = share < 0.01
                ? String(localized: "series.provenance.topCollections.share.tiny",
                         defaultValue: "under 1%")
                : share.formatted(.percent.precision(.fractionLength(0)))
            return String(format: String(
                localized: "series.provenance.topCollections.coverage %lld %lld %@ %@",
                defaultValue: "Showing %1$lld of %2$lld collections reached across %3$@. Together they account for %4$@ of the source notes those volumes carry."),
                Int64(ranking.rows.count), Int64(ranking.unitsReached), eras, percent)
        }
        return String(format: String(
            localized: "series.provenance.topCollections.coverage.noShare %lld %lld %@",
            defaultValue: "Showing %1$lld of %2$lld collections reached across %3$@."),
            Int64(ranking.rows.count), Int64(ranking.unitsReached), eras)
    }
}
