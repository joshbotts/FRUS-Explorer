// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Charts
import SwiftUI

// MARK: - CollectionDetailView

/// The shared "Collection" surface (Source Explorer Phase 4): everything the app knows
/// about one archival collection from the bundled cross-volume authority, wherever a
/// researcher meets it — a volume's front-matter Sources list, a document's Source
/// Explorer sheet, or the browse-by-collection list.
///
/// ## Sections
/// - **Overview** — canonical name, repository, record group, lot key, and the alias
///   forms the corpus actually writes (the grain-mismatch bridges).
/// - **NARA Catalog** — the offline-resolved catalog record link, when one exists.
/// - **In Your Library** — the S5 local counts ("N documents in M of your indexed
///   volumes", always recomputed from the user's own index via
///   `IndexingPipeline.localCollectionStats`) and the Archival Neighbors action.
/// - **Related Collections** (#762) — the collections cited alongside this one in the
///   same volumes' source lists, ranked by overlap coefficient; each row pushes its own
///   detail. Shown only for records citing two or more volumes.
/// - **Cited Over Time** (#762) — the citing volumes on a coverage-era axis, with a
///   caption generated from the data. Shown only when they reach two or more eras.
/// - **Divided at NARA** (#762) — the several NARA series claiming this record's lot,
///   when NARA divided it (`lot-claimants-index.json`, #675).
/// - **Cited Across the Series** — the corpus-wide citing-volume list from the
///   artifact (the "Cited in N volumes" affordance, upgraded).
/// - **Sub-series** — the record's level-2 children (S4: two levels); class-keyed
///   children carry their own Archival Neighbors action (their citing documents are
///   local `decimal_class` queries — S5).
///
/// Push-friendly: this view is plain `List` content with a navigation title, so it can
/// be pushed inside an existing `NavigationStack` (the iOS Source Explorer sheet, the
/// macOS Source Explorer window) or wrapped in ``CollectionDetailSheet`` for
/// `.sheet(item:)` presentation from list surfaces.
///
/// Version history:
///   1.0 — Session 2026-07-03 (Source Explorer Phase 4 step 2): initial implementation
///   1.1 — Session 2026-07-04 (Phase 4 adversarial review): the collection-level
///          Archival Neighbors action runs `IndexingPipeline.collectionNeighbors`
///          (the same OR-union clause the S5 count uses), so the sheet total always
///          equals the "N documents in M volumes" line
///   1.2 — Session 2026-07-04 (Source Explorer Phase 5 S6): both Archival Neighbors
///          actions (collection-level and class sub-series) open the value-based
///          window on macOS (`ArchivalNeighborsRequest.collection` /
///          `.decimalClass`); the sheet, its target, and its loader are now iOS-only
///   1.3 — Session 2026-08-08 (#762, archival analytics Phase 1): Related Collections,
///          Cited Over Time, and Divided at NARA; the citing-volume list gains the same
///          preview-plus-"Show all" disclosure the new sections use
struct CollectionDetailView: View {

    /// The bundled authority record being shown.
    let record: AuthorityCollectionRecord

    @Environment(AppState.self) private var appState
    /// #338 step 4: the scene this view renders in (nil inside the SourceExplorer aux window), so the
    /// Archival-Neighbors sheet's open-document action targets a window — or `.anyWindow` if scene-less.
    @Environment(\.sceneID) private var sceneID
    /// Opens the S6 Archival Neighbors window (`WindowGroup(for: ArchivalNeighborsRequest.self)`)
    /// — macOS, and iPad with Stage Manager as of #241.
    @Environment(\.openWindow) private var openWindow
    #if os(iOS)
    /// Gates the neighbors window on iOS: false on iPhone (the sheet remains the
    /// presentation); on iPad the value is plist-derived, NOT strictly "Stage Manager on" —
    /// a Full Screen Apps-mode iPad may still report true, giving a full-screen window
    /// (#241 review finding; runtime probe still owed).
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows
    #endif

    /// The S5 local counts, loaded from the user's index on appear.
    @State private var localStats: IndexingPipeline.CollectionLocalStats? = nil
    /// #762: collections cited alongside this one, ranked off-main on appear. `nil` while
    /// the scan is still running; empty when nothing clears the shared-volume floor.
    @State private var related: [RelatedCollection]? = nil
    /// Whether the Related Collections list is expanded past ``CollectionRelations/previewRowCap``.
    @State private var showsAllRelated = false
    /// #762: citing volumes bucketed by coverage era. Empty when they reach fewer than two eras.
    @State private var timeline: [CollectionEraCount] = []
    /// Whether the citing-volume list is expanded past ``CollectionRelations/previewRowCap``.
    @State private var showsAllVolumes = false
    #if os(iOS)
    /// When set, the Archival Neighbors sheet presents for the collection (or one of
    /// its class-keyed sub-series). Anchored once, on this view's `List`. iOS only —
    /// macOS opens the S6 Archival Neighbors window instead.
    @State private var neighborsTarget: CollectionNeighborsTarget? = nil
    #endif

    /// Maximum alias forms shown in the Overview section.
    private static let aliasDisplayCap = 6

    /// Whether to surface this record's NARA Catalog link (#351). A lot cluster whose baked
    /// NAID traces to a central-files `fileUnit`/flagged mis-resolution (the 60 D 627 →
    /// "Operation Mongoose" class the #335 audit flagged) is suppressed here — the downstream
    /// `collection-authority` bundle still carries the wrong NAID until the keyed re-resolution
    /// (#352), so the guard is applied at render time against the trusted central-files set. The
    /// collection identity, citing-volume list, and sub-series still show; only the wrong NARA
    /// link is withheld.
    private var showsCatalogLink: Bool {
        record.url != nil
            && CentralFilesIndexStore.shared?.isUntrustworthyNAID(record.naId) != true
    }

    /// The NARA series claiming this record's lot, when NARA divided it across more than one
    /// (#675). `nil` for every record that is not lot-keyed, and for the great majority of
    /// those that are — 113 of the 4,423 shipped records reach a divided lot.
    private var dividedLotClaimants: [LotClaimant]? {
        guard let lot = record.lotFileNorm else { return nil }
        return LotClaimantsIndexStore.shared?.claimants(forRawLot: lot)
    }

    var body: some View {
        List {
            overviewSection
            if showsCatalogLink {
                catalogSection
            }
            localSection
            if record.volumeIds.count >= CollectionRelations.minimumSharedVolumes {
                relatedCollectionsSection
            }
            if !timeline.isEmpty {
                citedOverTimeSection
            }
            if let claimants = dividedLotClaimants {
                dividedAtNARASection(claimants)
            }
            citingVolumesSection
            if !record.children.isEmpty {
                subSeriesSection
            }
        }
        .navigationTitle(String(localized: "collection.detail.title",
                                defaultValue: "Collection"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $neighborsTarget) { target in
            ArchivalNeighborsSheet(appState: appState) { scopeVolumeIds in
                await loadNeighbors(for: target, scopeVolumeIds: scopeVolumeIds)
            }
            .environment(appState)
            .environment(\.sceneID, sceneID ?? .anyWindow)
        }
        #endif
        .task {
            loadTimeline()
            await loadRelated()
            await loadLocalStats()
        }
    }

    // MARK: - Overview

    @ViewBuilder
    private var overviewSection: some View {
        Section {
            Text(record.name)
                .font(.headline)
                .textSelection(.enabled)
            if let repository = record.repository {
                LabeledContent(
                    String(localized: "collection.detail.repository", defaultValue: "Repository"),
                    value: repository
                )
            }
            if let rg = record.recordGroup {
                LabeledContent(
                    String(localized: "collection.detail.recordGroup", defaultValue: "Record Group"),
                    value: "RG \(rg)"
                )
            }
            if let lot = record.lotFileNorm {
                LabeledContent(
                    String(localized: "collection.detail.lot", defaultValue: "Lot File"),
                    value: lot
                )
            }
            if !record.aliases.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text(String(localized: "collection.detail.aliases",
                                defaultValue: "Also cited as"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(record.aliases.prefix(Self.aliasDisplayCap), id: \.self) { alias in
                        Text(alias)
                            .font(.caption)
                            .textSelection(.enabled)
                    }
                    if record.aliases.count > Self.aliasDisplayCap {
                        Text(String(format: String(
                            localized: "collection.detail.aliases.more %lld",
                            defaultValue: "%lld more variant forms"),
                            Int64(record.aliases.count - Self.aliasDisplayCap)))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text(String(localized: "collection.detail.overview.header",
                        defaultValue: "Archival Collection"))
        }
    }

    // MARK: - NARA Catalog

    @ViewBuilder
    private var catalogSection: some View {
        Section(String(localized: "collection.detail.catalog.header",
                       defaultValue: "NARA Catalog")) {
            if let url = record.url {
                Link(destination: url) {
                    Label(String(localized: "collection.detail.catalog.open",
                                 defaultValue: "View in National Archives Catalog"),
                          systemImage: "building.columns")
                }
                .help(String(localized: "browser.sources.catalog.help",
                             defaultValue: "View this collection in the National Archives Catalog"))
            }
            if let naId = record.naId {
                Text(String(format: String(localized: "collection.detail.catalog.naid %@",
                                           defaultValue: "NAID %@ — resolved offline from the bundled index; no API key required."),
                            naId))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Local stats (S5)

    @ViewBuilder
    private var localSection: some View {
        Section {
            if let stats = localStats {
                if stats.documentCount > 0 {
                    Text(String(format: String(
                        localized: "collection.detail.local.counts %lld %lld",
                        defaultValue: "%lld documents in %lld of your indexed volumes cite this collection."),
                        Int64(stats.documentCount), Int64(stats.volumeCount)))
                        .font(.callout)
                    Button {
                        // S6/#241: window wherever windows exist (macOS; iPad with Stage
                        // Manager) — the neighbor list is a work list and must survive row
                        // navigation; sheet only where they do not.
                        #if os(iOS)
                        guard supportsMultipleWindows else {
                            neighborsTarget = CollectionNeighborsTarget(decimalClass: nil)
                            return
                        }
                        appState.openAuxWindow(ArchivalNeighborsRequest(collectionRecord: record), from: sceneID, using: openWindow)
                        #else
                        // This view is hosted in the Source Explorer window's Collections
                        // segment — the neighbors window inherits its provenance.
                        let request = ArchivalNeighborsRequest(collectionRecord: record)
                        appState.bindTool(.archivalNeighbors(request),
                                          to: appState.provenance(of: .sourceExplorer))
                        openWindow(value: request)
                        #endif
                    } label: {
                        Label(String(localized: "collection.detail.neighbors",
                                     defaultValue: "Show Archival Neighbors"),
                              systemImage: "archivebox")
                    }
                    .accessibilityHint(String(localized: "collection.detail.neighbors.hint",
                                              defaultValue: "Lists your indexed documents drawn from this collection"))
                } else {
                    Text(String(localized: "collection.detail.local.empty",
                                defaultValue: "Nothing in your index cites this collection yet. Index more of its citing volumes to surface documents."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack {
                    ProgressView()
                    Text(String(localized: "collection.detail.local.loading",
                                defaultValue: "Counting your indexed documents…"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text(String(localized: "collection.detail.local.header",
                        defaultValue: "In Your Library"))
        } footer: {
            Text(String(localized: "collection.detail.local.footer",
                        defaultValue: "Counted from your own indexed volumes — the series-wide list below is independent of what you have downloaded."))
        }
    }

    // MARK: - Related collections (#762-A)

    @ViewBuilder
    private var relatedCollectionsSection: some View {
        Section {
            if let related {
                if related.isEmpty {
                    Text(String(localized: "collection.detail.related.empty",
                                defaultValue: "No other collection is cited alongside this one in two or more volumes."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    let shown = showsAllRelated
                        ? related
                        : Array(related.prefix(CollectionRelations.previewRowCap))
                    ForEach(shown) { item in
                        NavigationLink {
                            CollectionDetailView(record: item.record)
                                .environment(appState)
                        } label: {
                            relatedRow(item)
                        }
                    }
                    if related.count > CollectionRelations.previewRowCap {
                        Button {
                            showsAllRelated.toggle()
                        } label: {
                            Text(showsAllRelated
                                 ? String(localized: "collection.detail.related.showFewer",
                                          defaultValue: "Show fewer")
                                 : String(format: String(
                                    localized: "collection.detail.related.showAll %lld",
                                    defaultValue: "Show all %lld related collections"),
                                    Int64(related.count)))
                        }
                    }
                }
            } else {
                HStack {
                    ProgressView()
                    Text(String(localized: "collection.detail.related.loading",
                                defaultValue: "Finding collections cited alongside this one…"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text(String(localized: "collection.detail.related.header",
                        defaultValue: "Related Collections"))
        } footer: {
            Text(String(localized: "collection.detail.related.footer",
                        defaultValue: "Cited alongside this collection in the same volumes' source lists — ranked by overlap coefficient to damp umbrella records. Volume-grain: shared volumes co-fed one compilation, not document-level affinity."))
        }
    }

    /// One Related Collections row: identity on the left, the shared count and an overlap
    /// meter on the right. The meter is the ranking made visible — the list is ordered by it.
    @ViewBuilder
    private func relatedRow(_ item: RelatedCollection) -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.record.name)
                    .font(.callout)
                if let provenance = Self.provenanceCaption(for: item.record) {
                    Text(provenance)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: String(
                    localized: "collection.detail.related.shared %lld",
                    defaultValue: "%lld shared vols"),
                    Int64(item.sharedVolumeCount)))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                overlapMeter(item.overlap)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(String(format: String(
            localized: "collection.detail.related.overlap.value %@",
            defaultValue: "Overlap %@"),
            item.overlap.formatted(.percent.precision(.fractionLength(0))))))
    }

    /// The 56×4pt overlap meter. Decorative — the coefficient reaches VoiceOver through the
    /// row's accessibility value, so the shape itself is hidden rather than announced twice.
    private func overlapMeter(_ overlap: Double) -> some View {
        let fraction = min(max(overlap, 0), 1)
        return Capsule()
            .fill(.quaternary)
            .frame(width: 56, height: 4)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: max(2, 56 * fraction), height: 4)
            }
            .accessibilityHidden(true)
    }

    /// `"Department of State · RG 59"` — whichever of the two the record carries, or `nil`.
    private static func provenanceCaption(for record: AuthorityCollectionRecord) -> String? {
        let parts = [record.repository, record.recordGroup.map { "RG \($0)" }].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: - Cited over time (#762-C)

    @ViewBuilder
    private var citedOverTimeSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                let peak = max(timeline.map(\.volumeCount).max() ?? 1, 1)
                Chart {
                    ForEach(timeline) { bucket in
                        BarMark(
                            x: .value(String(localized: "collection.detail.timeline.x",
                                             defaultValue: "Coverage era"),
                                      bucket.era.shortLabel),
                            y: .value(String(localized: "collection.detail.timeline.y",
                                             defaultValue: "Citing volumes"),
                                      bucket.volumeCount)
                        )
                        // Tint tracks height so the shape survives a glance at 92pt, where
                        // three bars within one volume of each other are otherwise level.
                        .foregroundStyle(Color.accentColor
                            .opacity(0.45 + 0.55 * Double(bucket.volumeCount) / Double(peak)))
                        .accessibilityLabel(Text(bucket.era.fullLabel))
                        .accessibilityValue(Text(bucket.volumeCount, format: .number))
                    }
                }
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                    }
                }
                .frame(height: 92)
                Text(String(format: String(
                    localized: "collection.detail.timeline.caption %@",
                    defaultValue: "Citing volumes by coverage era (the citing-volume list × the manifest's date ranges). %@"),
                    CollectionRelations.timelineNarrative(for: timeline)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
        } header: {
            Text(String(localized: "collection.detail.timeline.header",
                        defaultValue: "Cited Over Time"))
        }
    }

    // MARK: - Divided at NARA (#762-F)

    @ViewBuilder
    private func dividedAtNARASection(_ claimants: [LotClaimant]) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: String(
                    localized: "collection.detail.divided.intro %lld",
                    defaultValue: "NARA later distributed material cited as this lot across %lld catalog series."),
                    Int64(claimants.count)))
                    .font(.callout)
                if let naId = record.naId, claimants.contains(where: { $0.naId == naId }) {
                    Text(String(localized: "collection.detail.divided.oneOfThem",
                                defaultValue: "The NARA Catalog link above points to one of them; the citation alone does not say which holds a given document."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
            ForEach(Array(claimants.enumerated()), id: \.offset) { _, claimant in
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(claimant.title)
                            .font(.callout)
                            .textSelection(.enabled)
                        Text(Self.claimantCaption(claimant))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if let entries = claimant.hmsMlrEntryNumbers, !entries.isEmpty {
                            Text(String(format: String(
                                localized: "collection.detail.divided.entries %@",
                                defaultValue: "Entry %@"),
                                entries.joined(separator: ", ")))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Spacer(minLength: 8)
                    if let url = URL(string: claimant.catalogURL) {
                        Link(String(localized: "collection.detail.divided.view",
                                    defaultValue: "View"),
                             destination: url)
                            .font(.callout)
                    }
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text(String(localized: "collection.detail.divided.header",
                        defaultValue: "Divided at NARA"))
        } footer: {
            Text(String(format: String(
                localized: "collection.detail.divided.footer %lld",
                defaultValue: "From the bundled lot-claimants index — %lld lots series-wide are claimed by more than one NARA series. Offline; no API key required."),
                Int64(LotClaimantsIndexStore.shared?.lots.count ?? 0)))
        }
    }

    /// `"NAID 4682721 · RG 59 · 1948–1961"` — every field NARA states about the claiming
    /// series. Deliberately not a per-series document count: a FRUS citation names a lot and
    /// never a series, so which of the claimants holds a given document is exactly the fact
    /// NARA's division destroyed.
    private static func claimantCaption(_ claimant: LotClaimant) -> String {
        var parts = [String(format: String(localized: "collection.detail.divided.naid %@",
                                           defaultValue: "NAID %@"), claimant.naId)]
        if let rg = claimant.recordGroup { parts.append("RG \(rg)") }
        if let dates = claimant.dateRange { parts.append(dates) }
        return parts.joined(separator: " · ")
    }

    // MARK: - Citing volumes (corpus-wide, from the artifact)

    @ViewBuilder
    private var citingVolumesSection: some View {
        Section {
            let shown = showsAllVolumes
                ? record.volumeIds
                : Array(record.volumeIds.prefix(CollectionRelations.previewRowCap))
            ForEach(shown, id: \.self) { volumeId in
                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.manifestStore.entry(forVolumeId: volumeId)?.title ?? volumeId)
                        .font(.callout)
                    Text(volumeId)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
            if record.volumeIds.count > CollectionRelations.previewRowCap {
                Button {
                    showsAllVolumes.toggle()
                } label: {
                    Text(showsAllVolumes
                         ? String(localized: "collection.detail.volumes.showFewer",
                                  defaultValue: "Show fewer")
                         : String(format: String(
                            localized: "collection.detail.volumes.showAll %lld",
                            defaultValue: "Show all %lld volumes"),
                            Int64(record.volumeIds.count)))
                }
            }
        } header: {
            Text(String(format: String(
                localized: "collection.detail.volumes.header %lld",
                defaultValue: "Cited Across the Series (%lld volumes)"),
                Int64(record.volumeIds.count)))
        }
    }

    // MARK: - Sub-series (S4 level 2)

    @ViewBuilder
    private var subSeriesSection: some View {
        Section {
            ForEach(Array(record.children.enumerated()), id: \.offset) { _, child in
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(child.name)
                            .font(.callout)
                            .textSelection(.enabled)
                        if child.volumeIds.count > 1 {
                            Text(String(format: String(
                                localized: "collection.detail.child.volumes %lld",
                                defaultValue: "Cited in %lld volumes"),
                                Int64(child.volumeIds.count)))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 8)
                    if let cls = child.decimalClass {
                        Button {
                            // Same gate as the record-level action above (#241).
                            #if os(iOS)
                            guard supportsMultipleWindows else {
                                neighborsTarget = CollectionNeighborsTarget(decimalClass: cls)
                                return
                            }
                            appState.openAuxWindow(ArchivalNeighborsRequest.decimalClass(cls), from: sceneID, using: openWindow)
                            #else
                            // Same provenance inheritance as the record-level action above.
                            let request = ArchivalNeighborsRequest.decimalClass(cls)
                            appState.bindTool(.archivalNeighbors(request),
                                              to: appState.provenance(of: .sourceExplorer))
                            openWindow(value: request)
                            #endif
                        } label: {
                            Image(systemName: "archivebox")
                        }
                        .buttonStyle(.borderless)
                        .help(String(localized: "browser.sources.archivalNeighbors.help",
                                     defaultValue: "Show indexed documents drawn from this archival source"))
                        .accessibilityLabel(String(localized: "browser.sources.archivalNeighbors",
                                                   defaultValue: "Archival Neighbors"))
                    }
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text(String(localized: "collection.detail.children.header",
                        defaultValue: "Sub-Series"))
        }
    }

    // MARK: - Loading

    /// Ranks the collections cited alongside this one (#762-A).
    ///
    /// Off-main because it intersects this record's volume list against all 4,423 shipped
    /// records; sub-millisecond in practice, but it runs on the same appear as the SQLite
    /// local-stats query and neither should be able to hold a frame.
    private func loadRelated() async {
        let focus = record
        related = await Task.detached(priority: .userInitiated) {
            guard let index = CollectionAuthorityStore.shared else { return [RelatedCollection]() }
            return CollectionRelations.related(to: focus, in: index.collections)
        }.value
    }

    /// Buckets the citing volumes by coverage era (#762-C).
    ///
    /// Main-thread on purpose: it is one O(1) manifest lookup per citing volume (157 at the
    /// widest record in the corpus), and `ManifestStore` is main-actor isolated.
    private func loadTimeline() {
        let midpoints = record.volumeIds.compactMap { volumeId -> Int? in
            guard let entry = appState.manifestStore.entry(forVolumeId: volumeId) else { return nil }
            return CollectionRelations.midpointYear(earliest: entry.dateRange.earliest,
                                                    latest: entry.dateRange.latest)
        }
        timeline = CollectionRelations.citedOverTime(volumeMidpoints: midpoints)
    }

    /// Loads the S5 local counts from the user's index.
    private func loadLocalStats() async {
        guard let pipeline = appState.indexingPipeline else {
            localStats = IndexingPipeline.CollectionLocalStats(documentCount: 0, volumeCount: 0)
            return
        }
        localStats = (try? await pipeline.localCollectionStats(
            lotFileNorm: record.lotFileNorm,
            repository: record.repository,
            recordGroup: record.recordGroup,
            names: [record.name] + record.aliases
        )) ?? IndexingPipeline.CollectionLocalStats(documentCount: 0, volumeCount: 0)
    }

    #if os(iOS)
    /// Runs the Archival Neighbors query for the collection (or a class sub-series).
    /// iOS sheet loader only — the macOS window reconstructs the identical queries
    /// from its `ArchivalNeighborsRequest` value.
    ///
    /// The collection-level query is `IndexingPipeline.collectionNeighbors` — the
    /// same OR-union clause `localCollectionStats` counts with, so the sheet's total
    /// always equals the "N documents in M volumes" line above the button.
    private func loadNeighbors(for target: CollectionNeighborsTarget,
                               scopeVolumeIds: Set<String>?) async -> ArchivalNeighborsResult {
        guard let pipeline = appState.indexingPipeline else { return ([], 0, nil) }
        if let cls = target.decimalClass {
            return (try? await pipeline.archivalNeighbors(
                forLotFile: nil, recordGroup: nil, series: nil,
                repository: nil, decimalClass: cls,
                scopeVolumeIds: scopeVolumeIds)) ?? ([], 0, nil)
        }
        return (try? await pipeline.collectionNeighbors(
            lotFileNorm: record.lotFileNorm,
            repository: record.repository,
            recordGroup: record.recordGroup,
            names: [record.name] + record.aliases,
            scopeVolumeIds: scopeVolumeIds)) ?? ([], 0, nil)
    }
    #endif
}

#if os(iOS)

// MARK: - CollectionNeighborsTarget

/// Identifiable `.sheet(item:)` target for the detail view's Archival Neighbors
/// actions: `decimalClass == nil` queries the collection itself; a class key queries
/// one class-keyed sub-series. iOS only — macOS routes both actions to the S6
/// Archival Neighbors window via `ArchivalNeighborsRequest`.
private struct CollectionNeighborsTarget: Identifiable {
    /// The sub-series class key, or `nil` for the collection-level query.
    let decimalClass: String?
    let id = UUID()
}

#endif

// MARK: - CollectionDetailSheet

/// `.sheet(item:)` wrapper around ``CollectionDetailView`` for list surfaces (the
/// volume Sources list, the browse-by-collection list): its own `NavigationStack`
/// and a Done button.
struct CollectionDetailSheet: View {

    /// The bundled authority record being shown.
    let record: AuthorityCollectionRecord

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            CollectionDetailView(record: record)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "common.done", defaultValue: "Done")) { dismiss() }
                    }
                }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 480)
        #endif
    }
}
