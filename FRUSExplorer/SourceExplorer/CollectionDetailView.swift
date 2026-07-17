// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

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
struct CollectionDetailView: View {

    /// The bundled authority record being shown.
    let record: AuthorityCollectionRecord

    @Environment(AppState.self) private var appState
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

    var body: some View {
        List {
            overviewSection
            if showsCatalogLink {
                catalogSection
            }
            localSection
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
        }
        #endif
        .task {
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
                        #endif
                        openWindow(value: ArchivalNeighborsRequest(collectionRecord: record))
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

    // MARK: - Citing volumes (corpus-wide, from the artifact)

    @ViewBuilder
    private var citingVolumesSection: some View {
        Section {
            ForEach(record.volumeIds, id: \.self) { volumeId in
                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.manifestStore.entry(forVolumeId: volumeId)?.title ?? volumeId)
                        .font(.callout)
                    Text(volumeId)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
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
                            #endif
                            openWindow(value: ArchivalNeighborsRequest.decimalClass(cls))
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
