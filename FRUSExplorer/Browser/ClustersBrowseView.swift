// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftUI
import SwiftData

// MARK: - ClustersAxis

/// The Semantic Clusters browse axis's pure logic (#1051 B-7, A-8): ordering, row
/// labels, the era mini-histogram derivation, the honesty caption, and the one-pass
/// membership enumeration — split from the views for testability.
///
/// ## What this axis is, and the disclosures it owes
/// The 179 clusters are HDBSCAN's grouping of the corpus's own language, read from the
/// bundled `semantic-map-index.json`. Three disclosures are mandatory on every surface
/// (the design-requirements A-8 list) and each is a sentence this axis renders:
/// labels are sampled c-TF-IDF terms, **not subject headings**; 88,207 documents
/// (28.0%) belong to no cluster and are unreachable from any cluster list; era
/// histograms bucket each document by its VOLUME's coverage era, not its own date.
/// Every figure is computed from the live artifact — never hard-coded — so a
/// regenerated artifact re-states its own truth.
///
/// ## The durability rule this axis is built around
/// Cluster ids re-mint per artifact generation (168 of 179 labels changed in one
/// regeneration), so an id is valid only against the artifact that minted it. Nothing
/// here persists one: navigation state is in-memory, a saved corpus materializes
/// `"volumeId/documentId"` keys at capture (the `WorkingCorpus` pattern), and the
/// "See on map" cross-link carries the artifact's provenance digest beside the id so
/// a restored window can refuse a focus minted against a different generation.
///
/// Version history:
///   1.0 — #1051 B-7: initial implementation
enum ClustersAxis {

    // MARK: Ordering and labels

    /// The index order: largest cluster first, artifact id as the tiebreak.
    ///
    /// The labels are machine terms with no alphabetical meaning and the artifact's id
    /// order is arbitrary layout output, so size is the one axis a reader can predict —
    /// the biggest groupings of the corpus's language come first.
    ///
    /// - Parameter clusters: The artifact's roster.
    /// - Returns: The display order.
    static func ordered(_ clusters: [SemanticMapArtifacts.Cluster]) -> [SemanticMapArtifacts.Cluster] {
        clusters.sorted {
            if $0.documentCount != $1.documentCount { return $0.documentCount > $1.documentCount }
            return $0.id < $1.id
        }
    }

    /// The row label: all four sampled terms, separated so they read as a term list
    /// rather than a phrase (`shah · iran · iranian · mosadeq`).
    ///
    /// - Parameter cluster: The cluster.
    /// - Returns: The label.
    static func rowLabel(_ cluster: SemanticMapArtifacts.Cluster) -> String {
        cluster.terms.joined(separator: " · ")
    }

    /// The three-term space-joined form the MAP uses for a region's name — reused for
    /// corpus naming so a set saved here and a set saved on the map read as the same
    /// region in the corpora list.
    ///
    /// - Parameter cluster: The cluster.
    /// - Returns: The map-style name.
    static func mapStyleName(_ cluster: SemanticMapArtifacts.Cluster) -> String {
        cluster.terms.prefix(3).joined(separator: " ")
    }

    // MARK: Era mini-histogram

    /// One bar of the era mini-histogram.
    struct EraBar: Equatable {
        /// The era, or `nil` for the pooled bucket of non-era keys (the export's
        /// "Undated volumes" rule — rows must sum to the cluster's count).
        let era: CoverageEra?
        /// Documents in this bucket.
        let count: Int
        /// Whether this bar is one of the two largest — the design's accented pair.
        let isPeak: Bool
    }

    /// Derives the mini-histogram: one bar per `CoverageEra` in era order (zero-count
    /// eras keep their slot so every row's histogram is positionally comparable), plus
    /// a trailing pooled bar only when the artifact carries non-era keys. The two
    /// largest non-zero bars are marked as peaks; a tie goes to the earlier slot.
    ///
    /// - Parameter eraCounts: The cluster's `eraCounts`, keyed by `CoverageEra` raw
    ///   value as a string (the artifact's wire form).
    /// - Returns: The bars, oldest era first.
    static func eraBars(_ eraCounts: [String: Int]) -> [EraBar] {
        var pooled = 0
        var byEra: [CoverageEra: Int] = [:]
        for (key, count) in eraCounts {
            if let raw = Int(key), let era = CoverageEra(rawValue: raw) {
                byEra[era, default: 0] += count
            } else {
                pooled += count
            }
        }
        var slots: [(era: CoverageEra?, count: Int)] = CoverageEra.ordered.map { ($0, byEra[$0] ?? 0) }
        if pooled > 0 { slots.append((nil, pooled)) }
        // The two peaks, by count then earlier slot — indices, so equal counts cannot
        // both win a single peak place.
        let peaks = slots.indices
            .filter { slots[$0].count > 0 }
            .sorted { slots[$0].count != slots[$1].count ? slots[$0].count > slots[$1].count : $0 < $1 }
            .prefix(2)
        return slots.indices.map { i in
            EraBar(era: slots[i].era, count: slots[i].count, isPeak: peaks.contains(i))
        }
    }

    // MARK: The honesty caption

    /// The index-level caption, computed entirely from the live artifact (the design
    /// 1j text with the era disclosure appended — every figure re-states itself after
    /// a regeneration).
    ///
    /// - Parameters:
    ///   - clusterCount: `clusters.count`.
    ///   - unclusteredCount: `layout.unclusteredCount`.
    ///   - documentCount: The artifact's total placed documents.
    /// - Returns: The caption.
    static func indexCaption(clusterCount: Int, unclusteredCount: Int, documentCount: Int) -> String {
        let percent = documentCount > 0
            ? Double(unclusteredCount) / Double(documentCount) * 100
            : 0
        let percentText = percent.formatted(.number.precision(.fractionLength(1)))
        return String(localized: "browser.clusters.caption",
                      defaultValue: """
                      \(clusterCount) clusters computed from document text. Labels are the most \
                      distinctive sampled terms, not subject headings. \(unclusteredCount) documents \
                      (\(percentText)%) belong to no cluster and cannot be reached from this list. \
                      Era bars reflect each volume's coverage era, not document dates.
                      """)
    }

    // MARK: Membership enumeration

    /// Every artifact row in one cluster, in one pass over the mapped placements.
    ///
    /// Composes the shipped rule (`SemanticMapPicking.rows(inCluster:)` — one
    /// implementation, so the browse drill and the map's capture cannot disagree about
    /// membership) with the raw-pointer read `SemanticMapColouring.scopeMask` uses,
    /// because the obvious alternative — `placement(at:)` per row — re-enters
    /// `withUnsafeBytes` 314,483 times per scan.
    ///
    /// `nonisolated`, deliberately: both inputs are `Sendable` value types over an
    /// mmapped file, so the scan runs off the main actor.
    ///
    /// - Parameters:
    ///   - map: The mapped placements.
    ///   - clusterId: The artifact's cluster id.
    /// - Returns: The rows, ascending (= volume order), and the honest total (equal
    ///   here, since the drill takes every row; the capture cap is applied later, at
    ///   key grain, where the truncation disclosure lives).
    nonisolated static func membershipRows(
        in map: SemanticMapVectors, clusterId: Int
    ) -> (rows: [Int], total: Int) {
        guard let cluster = UInt16(exactly: clusterId),
              cluster != SemanticMapArtifacts.unclustered else { return ([], 0) }
        return map.withPlacements { base, count in
            SemanticMapPicking.rows(
                inCluster: cluster,
                count: count,
                clusterAt: { row in
                    base.loadUnaligned(
                        fromByteOffset: row * SemanticMapArtifacts.bytesPerDocument + 4,
                        as: UInt16.self).littleEndian
                },
                limit: count)
        }
    }

    /// Materializes rows into `"volumeId/documentId"` keys — the identity that
    /// SURVIVES an artifact regeneration, which is why anything that outlives this
    /// screen (a saved corpus) stores these and never a cluster id.
    ///
    /// - Parameters:
    ///   - rows: Artifact rows, ascending.
    ///   - index: The vector index that keys them.
    /// - Returns: The keys, in row (= volume) order.
    nonisolated static func documentKeys(rows: [Int], index: SemanticVectorIndex) -> [String] {
        var keys: [String] = []
        keys.reserveCapacity(rows.count)
        for row in rows {
            guard let document = index.document(at: row) else { continue }
            keys.append("\(document.volumeID)/\(document.documentID)")
        }
        return keys
    }
}

// MARK: - ClusterEraHistogramView

/// The row's era mini-histogram: one capsule per bar, peaks accented (design 1j).
/// Decorative — the row's accessibility label carries the counts.
///
/// Version history:
///   1.0 — #1051 B-7: initial implementation
struct ClusterEraHistogramView: View {

    /// The bars, oldest era first.
    let bars: [ClustersAxis.EraBar]

    private static let maxBarHeight: CGFloat = 18
    private static let minBarHeight: CGFloat = 2

    var body: some View {
        let peak = bars.map(\.count).max() ?? 0
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(bars.enumerated()), id: \.offset) { _, bar in
                Capsule(style: .continuous)
                    .fill(bar.isPeak ? Color.accentColor : Color.secondary.opacity(0.35))
                    .frame(width: 5, height: barHeight(bar.count, peak: peak))
            }
        }
        .frame(height: Self.maxBarHeight, alignment: .bottom)
        .accessibilityHidden(true)
    }

    private func barHeight(_ count: Int, peak: Int) -> CGFloat {
        guard peak > 0, count > 0 else { return Self.minBarHeight }
        return max(Self.minBarHeight, Self.maxBarHeight * CGFloat(count) / CGFloat(peak))
    }
}

// MARK: - ClustersIndexView

/// The Semantic Clusters level (#1051 B-7, design 1j): every cluster in the bundled
/// map artifact, largest first — label · count · era mini-histogram — behind one
/// selection closure so both platforms mount it (iOS pushes `.clusterDocuments`,
/// macOS pushes `CorpusNavValue.clusterDocuments`).
///
/// ## The load path (the plan's "decide first" item, decided by measurement)
/// This level loads through `BundledSemanticMap.prepare()` — the shipped loader with
/// both provenance refusals — rather than the metadata-only decode the plan preferred.
/// The preference guarded against forcing an otherwise-unneeded vector-binary load,
/// and that premise no longer holds: `BundledSemanticVectors.prepare()` runs
/// unconditionally at every launch (`FRUSExplorerApp`'s main-window `.task`), the
/// binary is mmapped rather than read, and the drill needs the placements anyway. A
/// second decode path would be a second place for the generation-mixing rule to
/// drift, to save a load that already happened.
///
/// Version history:
///   1.0 — #1051 B-7: initial implementation
struct ClustersIndexView: View {

    /// Opens a cluster's document drill with its id and breadcrumb label.
    let onSelectCluster: @MainActor (Int, String) -> Void

    /// The decoded artifact, once loaded.
    @State private var mapIndex: SemanticMapArtifacts.MapIndex?
    /// Why it is not loaded, when it is not — `.pending` while another surface's
    /// in-flight load settles.
    @State private var unavailable: SemanticUnavailable?

    var body: some View {
        Group {
            if let mapIndex {
                clusterList(mapIndex)
            } else {
                ContentUnavailableView(
                    String(localized: "browser.clusters.unavailable.title",
                           defaultValue: "Clusters Unavailable"),
                    systemImage: SemanticGlyph.clusters,
                    description: Text(unavailableText)
                )
            }
        }
        .navigationTitle(String(localized: "browser.clusters.title", defaultValue: "Clusters"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await load() }
    }

    private var unavailableText: String {
        switch unavailable {
        case .pending, nil:
            return String(localized: "browser.clusters.pending",
                          defaultValue: "Loading the cluster data…")
        case .provenanceMismatch:
            return String(localized: "browser.clusters.mismatch",
                          defaultValue: "The cluster data and the semantic vectors come from different releases, so the list is not shown.")
        default:
            return String(localized: "browser.clusters.missing",
                          defaultValue: "This build’s cluster data could not be read. Reinstalling the app restores it.")
        }
    }

    @ViewBuilder
    private func clusterList(_ index: SemanticMapArtifacts.MapIndex) -> some View {
        List {
            Section {
                Text(ClustersAxis.indexCaption(
                    clusterCount: index.clusters.count,
                    unclusteredCount: index.layout.unclusteredCount,
                    documentCount: index.documentCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                ForEach(ClustersAxis.ordered(index.clusters), id: \.id) { cluster in
                    row(cluster)
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
    }

    @ViewBuilder
    private func row(_ cluster: SemanticMapArtifacts.Cluster) -> some View {
        let label = ClustersAxis.rowLabel(cluster)
        Button {
            onSelectCluster(cluster.id, label)
            #if DEBUG
            print("[ClustersIndexView] Navigate → cluster \(cluster.id)")
            #endif
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(String(localized: "browser.clusters.row.count",
                                defaultValue: "\(cluster.documentCount) documents"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                ClusterEraHistogramView(bars: ClustersAxis.eraBars(cluster.eraCounts))
            }
            // Both modifiers, in this order — the #312 full-row tap-target idiom.
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            String(localized: "browser.clusters.row.a11y",
                   defaultValue: "\(label), \(cluster.documentCount) documents")
        )
        .help(String(localized: "browser.clusters.row.help",
                     defaultValue: "Browse this cluster’s documents, grouped by volume"))
    }

    /// Loads the artifact, riding out another surface's in-flight load.
    ///
    /// `BundledSemanticMap.prepare()` returns immediately for a second caller while a
    /// first is mid-load (`loadStarted` guards re-entry, not completion), so a bounded
    /// retry converts that `.pending` window — a fraction of a second in practice —
    /// into the loaded list rather than a stuck placeholder.
    private func load() async {
        for _ in 0..<40 {
            await BundledSemanticMap.prepare()
            if let index = BundledSemanticMap.index {
                mapIndex = index
                unavailable = nil
                return
            }
            unavailable = BundledSemanticMap.unavailableReason
            guard unavailable == .pending else { return }
            try? await Task.sleep(nanoseconds: 150_000_000)
        }
    }
}

// MARK: - ClusterDocumentsView

/// One cluster's document drill (#1051 B-7): the R-3 degraded-row list over the
/// cluster's whole membership, paged — cluster 8 holds 38,652 documents against the
/// ~250 floor, and Browse has no precedent for a list that size (the map's only
/// enumeration is a capped capture). Reuses `CorporaAxis`'s key-generic grouping,
/// ordering and row-state logic verbatim, and the B-4 bulk metadata loads.
///
/// The map card's behaviors travel: the labels-are-sampled-terms and era-midpoint
/// sentences render above the list, Save as Working Corpus captures materialized
/// document keys with the 7,500 truncation disclosure, and "See on map" opens the
/// semantic map focused on this cluster — the focus request carries the artifact's
/// provenance digest beside the id, so a request restored against a regenerated
/// artifact is refused rather than landing on whatever re-minted cluster now wears
/// this number.
///
/// Version history:
///   1.0 — #1051 B-7: initial implementation
struct ClusterDocumentsView: View {

    /// The artifact's cluster id — valid only against the loaded generation, which is
    /// why it never outlives this navigation stack.
    let clusterId: Int
    /// The breadcrumb/title label the index minted.
    let label: String
    /// Opens an indexed document — iOS pushes `.document`, macOS routes through the
    /// corpus browser's document host.
    let onOpenDocument: @MainActor (DocumentBrowserEntry) -> Void
    /// Opens the semantic map focused on this cluster, when the host offers a route.
    let onSeeMap: (@MainActor (SemanticMapRequest) -> Void)?

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    /// The cluster's metadata, re-resolved live from the loaded artifact.
    @State private var cluster: SemanticMapArtifacts.Cluster?
    /// Every member's `"volumeId/documentId"` key, in row (= volume) order.
    @State private var keys: [String] = []
    /// How many keys the list currently shows (the paging cursor).
    @State private var shownCount = 0
    /// Why the drill is empty, when it is.
    @State private var unavailable: SemanticUnavailable?
    /// Bulk-loaded display metadata, keyed by `"volumeId/documentId"`.
    @State private var headers: [String: String] = [:]
    @State private var dates: [String: String] = [:]
    /// The last save's outcome, for the confirmation + truncation lines.
    @State private var savedCorpusName: String?
    @State private var savedCapture: SemanticMapPicking.LassoResult?

    /// Documents added per "Show more".
    private static let pageSize = 500

    var body: some View {
        Group {
            if let cluster {
                documentList(cluster)
            } else if unavailable != nil {
                ContentUnavailableView(
                    String(localized: "browser.clusters.unavailable.title",
                           defaultValue: "Clusters Unavailable"),
                    systemImage: SemanticGlyph.clusters,
                    description: Text(String(localized: "browser.clusters.drill.unavailable",
                                             defaultValue: "This cluster’s data could not be loaded."))
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(label)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await loadMembership() }
        // Re-keyed on the indexed-volume count so finishing an index pass upgrades the
        // degraded rows without navigating away (the B-4 idiom).
        .task(id: appState.indexedVolumeIds.count) { await loadMetadata() }
    }

    @ViewBuilder
    private func documentList(_ cluster: SemanticMapArtifacts.Cluster) -> some View {
        List {
            aboutSection(cluster)
            actionsSection(cluster)
            ForEach(CorporaAxis.volumeSections(from: Array(keys.prefix(shownCount)))) { section in
                volumeSection(section)
            }
            if shownCount < keys.count {
                showMoreSection
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
    }

    // MARK: The cluster's own card

    @ViewBuilder
    private func aboutSection(_ cluster: SemanticMapArtifacts.Cluster) -> some View {
        // Coverage in the resolver's own vocabulary — the same code that decides what a
        // captured corpus can search (the map's throwaway-model precedent), so the
        // number shown here and the number a capture reports cannot disagree.
        let resolution = WorkingCorpusResolver(indexedVolumeIds: appState.indexedVolumeIds)
            .resolve(WorkingCorpus(name: "", documentKeys: keys))
        Section {
            LabeledContent(String(localized: "browser.clusters.drill.count",
                                  defaultValue: "Documents in the series"),
                           value: cluster.documentCount.formatted())
            ForEach(SemanticMapRegionRows.eraRows(cluster), id: \.label) { row in
                LabeledContent(row.label, value: row.count)
            }
            if !keys.isEmpty {
                Text(resolution.coverageDescription)
                    .font(.caption)
                    .foregroundStyle(resolution.isComplete ? Color.secondary : Color.orange)
            }
        } footer: {
            // The map card's two mandatory sentences, in this surface's vocabulary: a
            // cluster is machine grouping, its label sampled terms; eras are the
            // volume's coverage, not the document's date.
            Text(String(localized: "browser.clusters.drill.footer",
                        defaultValue: "A cluster is a group the corpus fell into on its own — documents whose language reads alike, found by clustering rather than chosen by an editor. Its label is the most distinctive words in a sample of those documents, not a subject heading. Era counts reflect each volume’s coverage era, not each document’s own date."))
        }
    }

    @ViewBuilder
    private func actionsSection(_ cluster: SemanticMapArtifacts.Cluster) -> some View {
        Section {
            if let onSeeMap, let digest = BundledSemanticMap.index?.provenanceDigest {
                Button {
                    onSeeMap(SemanticMapRequest(
                        volumeIDs: nil, scopeLabel: nil,
                        lensRawValue: SemanticMapLens.cluster.rawValue,
                        focusClusterID: clusterId,
                        focusClusterDigest: digest))
                    #if DEBUG
                    print("[ClusterDocumentsView] See on map → cluster \(clusterId)")
                    #endif
                } label: {
                    Label(String(localized: "browser.clusters.seeOnMap",
                                 defaultValue: "See on the semantic map"),
                          systemImage: SemanticGlyph.feature)
                }
            }
            Button {
                saveAsWorkingCorpus(cluster)
            } label: {
                Label(String(localized: "browser.clusters.saveCorpus",
                             defaultValue: "Save as Working Corpus"),
                      systemImage: "tray.and.arrow.down")
            }
            .disabled(keys.isEmpty)
        } footer: {
            if let savedCorpusName, let savedCapture {
                if savedCapture.isTruncated {
                    Text(String(localized: "browser.clusters.saved.truncated",
                                defaultValue: "Saved “\(savedCorpusName)” with the first \(savedCapture.documentKeys.count) of \(savedCapture.total) documents."))
                        .foregroundStyle(.orange)
                } else {
                    Text(String(localized: "browser.clusters.saved",
                                defaultValue: "Saved “\(savedCorpusName)”."))
                }
            }
        }
    }

    // MARK: The paged document list (the B-4 R-3 shape)

    @ViewBuilder
    private func volumeSection(_ section: CorporaAxis.VolumeSection) -> some View {
        let entry = appState.manifestStore.entry(forVolumeId: section.volumeId)
        let state = CorporaAxis.rowState(
            volumeIndexed: appState.indexedVolumeIds.contains(section.volumeId),
            volumeDownloaded: appState.downloadManager?.isVolumeDownloaded(section.volumeId) ?? false
        )
        let isDownloading = appState.downloadQueue.contains(section.volumeId)
        Section(entry?.title ?? section.volumeId) {
            ForEach(CorporaAxis.ordered(section.documents, dates: dates,
                                        volumeEarliest: entry?.dateRange.earliest)) { ref in
                documentRow(ref, state: state, entry: entry, isDownloading: isDownloading)
            }
        }
    }

    @ViewBuilder
    private var showMoreSection: some View {
        Section {
            Button {
                shownCount = min(keys.count, shownCount + Self.pageSize)
                Task { await loadMetadata() }
                #if DEBUG
                print("[ClusterDocumentsView] Show more → \(shownCount) of \(keys.count)")
                #endif
            } label: {
                Text(String(localized: "browser.clusters.showMore",
                            defaultValue: "Show more"))
            }
        } footer: {
            Text(String(localized: "browser.clusters.paging",
                        defaultValue: "Showing the first \(shownCount) of \(keys.count) documents, in volume order."))
        }
    }

    @ViewBuilder
    private func documentRow(_ ref: CorporaAxis.DocumentRef,
                             state: CorporaAxis.RowState,
                             entry: VolumeManifestEntry?,
                             isDownloading: Bool) -> some View {
        switch state {
        case .open:
            Button {
                onOpenDocument(DocumentBrowserEntry(
                    documentId: ref.documentId,
                    volumeId: ref.volumeId,
                    documentNumber: nil,
                    header: headers[ref.key] ?? ref.documentId,
                    dateline: nil,
                    sourceNote: nil
                ))
                #if DEBUG
                print("[ClusterDocumentsView] Open \(ref.key)")
                #endif
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(headers[ref.key] ?? ref.documentId)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                    if let date = dates[ref.key] {
                        Text(date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                // Both modifiers, in this order — the #312 full-row tap-target idiom.
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        case .needsIndex, .needsDownload:
            // The degraded row: gray ids, and the affordance — never a dead end.
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(ref.volumeId) · \(ref.documentId)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text(String(localized: "browser.clusters.row.notIndexed",
                                defaultValue: "Not indexed on this device"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 8)
                if isDownloading {
                    ProgressView()
                        .controlSize(.small)
                } else if state == .needsDownload {
                    Button {
                        if let entry, let dm = appState.downloadManager {
                            Task { await dm.enqueueDownload(entry) }
                        }
                    } label: {
                        Text(String(localized: "browser.clusters.download",
                                    defaultValue: "Download"))
                    }
                    .buttonStyle(.bordered)
                    .disabled(entry?.downloadUrl == nil || appState.downloadManager == nil)
                    .help(String(localized: "browser.clusters.download.help",
                                 defaultValue: "Download this volume to open its documents"))
                } else {
                    Button {
                        if let pipeline = appState.indexingPipeline {
                            Task { try? await pipeline.indexVolume(ref.volumeId) }
                        }
                    } label: {
                        Text(String(localized: "browser.clusters.index", defaultValue: "Index"))
                    }
                    .buttonStyle(.bordered)
                    .disabled(appState.indexingPipeline == nil)
                    .help(String(localized: "browser.clusters.index.help",
                                 defaultValue: "Index this downloaded volume to open its documents"))
                }
            }
        }
    }

    // MARK: Loading

    /// Loads the artifact, resolves the cluster, and enumerates its membership once.
    ///
    /// The scan and key minting run off the main actor — both readers are `Sendable`
    /// values over an mmapped file, and the largest cluster mints 38,652 keys.
    private func loadMembership() async {
        for _ in 0..<40 {
            await BundledSemanticMap.prepare()
            if BundledSemanticMap.index != nil { break }
            guard BundledSemanticMap.unavailableReason == .pending else { break }
            try? await Task.sleep(nanoseconds: 150_000_000)
        }
        guard let mapIndex = BundledSemanticMap.index,
              let map = BundledSemanticMap.vectors,
              let vectorIndex = BundledSemanticVectors.index,
              let resolved = mapIndex.clusters.first(where: { $0.id == clusterId }) else {
            unavailable = BundledSemanticMap.unavailableReason ?? .malformedArtifact("cluster \(clusterId) not in artifact")
            return
        }
        let id = clusterId
        let loadedKeys = await Task.detached(priority: .userInitiated) { () -> [String] in
            let found = ClustersAxis.membershipRows(in: map, clusterId: id)
            return ClustersAxis.documentKeys(rows: found.rows, index: vectorIndex)
        }.value
        cluster = resolved
        keys = loadedKeys
        shownCount = min(loadedKeys.count, Self.pageSize)
        await loadMetadata()
        #if DEBUG
        print("[ClusterDocumentsView] Cluster \(id): \(loadedKeys.count) members enumerated")
        #endif
    }

    /// The bulk metadata load for the VISIBLE slice — one chunked call per store,
    /// never per-key queries (the B-4 rule; a page is 500 keys, not 38,652).
    private func loadMetadata() async {
        let visible = Array(keys.prefix(shownCount))
        guard !visible.isEmpty else { return }
        let pairs = visible.compactMap { key -> (volumeId: String, documentId: String)? in
            let parts = key.split(separator: "/", maxSplits: 1)
            guard parts.count == 2 else { return nil }
            return (String(parts[0]), String(parts[1]))
        }
        if let store = appState.crossReferenceStore,
           let loaded = try? await store.documentHeaders(for: pairs) {
            headers = loaded
        }
        if let pipeline = appState.indexingPipeline,
           let loaded = try? await pipeline.datesByDocumentKey(pairs) {
            dates = loaded
        }
    }

    // MARK: Capture

    /// Saves the cluster's membership as a working corpus — materialized document
    /// keys, never the cluster id (the WorkingCorpus pattern), capped at the record's
    /// 7,500 budget with the truncation said out loud.
    private func saveAsWorkingCorpus(_ cluster: SemanticMapArtifacts.Cluster) {
        let capture = SemanticMapPicking.LassoResult(
            documentKeys: Array(keys.prefix(SemanticMapPicking.corpusCaptureLimit)),
            total: keys.count,
            regionNames: [ClustersAxis.mapStyleName(cluster)])
        // The map's naming rule: names are looked up BY NAME elsewhere, so the capture
        // time disambiguates two saves of the same cluster.
        let stamp = Date().formatted(date: .abbreviated, time: .shortened)
        let name = "\(capture.regionNames.joined(separator: ", ")) — \(stamp)"
        let corpus = WorkingCorpus(
            name: name,
            documentKeys: capture.documentKeys,
            // No query produced this set and a cluster id cannot re-derive it across
            // artifact generations, so sourceQuery stays empty rather than claiming a
            // re-derivable origin.
            sourceQuery: nil,
            sourceDescription: String(localized: "browser.clusters.corpus.source",
                                      defaultValue: "Semantic cluster, browsed"),
            indexedVolumeCountAtCapture: appState.indexedVolumeIds.count,
            wasTruncatedAtCapture: capture.isTruncated,
            totalMatchCountAtCapture: capture.total)
        modelContext.insert(corpus)
        do {
            try modelContext.save()
            savedCorpusName = name
            savedCapture = capture
        } catch {
            savedCorpusName = nil
            savedCapture = nil
            #if DEBUG
            print("[ClusterDocumentsView] corpus save failed: \(error)")
            #endif
        }
    }
}

// MARK: - iOS mounts

#if os(iOS)

/// The iOS mount of the Clusters index (`BrowserLevel.clusters`).
///
/// Version history:
///   1.0 — #1051 B-7: initial implementation
struct BrowseClustersLevel: View {
    let vm: BrowserViewModel

    var body: some View {
        ClustersIndexView(onSelectCluster: { [vm] id, label in
            vm.navigationPath.append(.clusterDocuments(id: id, label: label))
        })
    }
}

/// The iOS mount of a cluster's document drill (`BrowserLevel.clusterDocuments`) —
/// indexed rows push `.document` in the Browse stack; "See on map" routes through the
/// host's presenter so multi-window iPads get the map window and iPhones the sheet.
///
/// Version history:
///   1.0 — #1051 B-7: initial implementation
struct BrowseClusterDocumentsLevel: View {
    let vm: BrowserViewModel
    let clusterId: Int
    let label: String
    let onSeeMap: @MainActor (SemanticMapRequest) -> Void

    var body: some View {
        ClusterDocumentsView(
            clusterId: clusterId,
            label: label,
            onOpenDocument: { [vm] entry in
                vm.navigationPath.append(.document(entry))
            },
            onSeeMap: onSeeMap
        )
    }
}

#endif // os(iOS)
