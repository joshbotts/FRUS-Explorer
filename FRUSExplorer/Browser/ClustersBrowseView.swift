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
/// The 171 clusters are HDBSCAN's grouping of the corpus's own language, read from the
/// bundled `semantic-map-index.json`. Three disclosures are mandatory on every surface
/// (the design-requirements A-8 list) and each is a sentence this axis renders:
/// labels are sampled c-TF-IDF terms, **not subject headings**; 89,449 documents
/// (28.4%) belong to no cluster and are unreachable from any cluster list; era
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
    /// `withUnsafeBytes` 314,571 times per scan.
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

// MARK: - ClusterDrillState

/// Everything ``ClusterDocumentsView`` holds for **one** cluster, carried with that cluster's own
/// id (#1301 round 3; writes refused unless the current load issued them, round 4).
///
/// ## Why the identity is in the value
/// Round 2 keyed this view's two load tasks under the reuse contract and stopped there, so the
/// reuse the key exists for would have had a worse screen than the one it prevents: `cluster`,
/// `keys`, `shownCount` and `unavailable` all survived the update, and `loadMembership()` assigns
/// them only after an awaited detached scan over tens of thousands of members (the shipped
/// artifact's largest cluster holds 37,865) — so the PREVIOUS cluster's document list rendered
/// under the new cluster's title while that ran. Worse, the two never converged when the new cluster
/// was missing from the artifact: that path sets `unavailable` and returns without touching
/// `cluster`, and the body prefers `if let cluster`.
///
/// A reset at the top of the keyed task would have fixed it, and would have been one more line
/// nothing could hold anyone to — the same line whose deletion from `CollectionDetailView` left
/// every suite green. Here a reader asks for a value *for a cluster* and gets one only when the
/// stored values are that cluster's.
///
/// ## Why a write needs a ticket (round 4)
/// Round 3 let a write naming another cluster **replace** the value, which had two faults. A
/// superseded scan's late write — awaiting a detached task's `value` is not a cancellation point —
/// erased the cluster the view had moved to, and left it on its spinner with nothing to re-run the
/// membership task. And because the view starts at ``noCluster``, EVERY real drill depended on that
/// adopt line, which no test ever took: deleting it left every cluster drill spinning with every
/// suite green.
///
/// So a load now starts with ``open(for:)``, which makes this value the cluster's and issues its
/// ``Ticket``; a membership write presents the ticket its load was issued and is **dropped** when
/// the ticket names another cluster. There is no other way to obtain a ticket, so a load cannot
/// skip the opening and still write, and the opening — the one line the view's path from
/// ``noCluster`` runs through — is a function the unit tests call from where the view starts.
///
/// The saved-corpus confirmation travels with the rest: "Saved “…”" is a fact about the cluster it
/// was captured from, and under another cluster's title it would name a set the reader is not
/// looking at. It and "Show more" are actions on what is DISPLAYED, so they are addressed by the
/// cluster on screen rather than by a ticket, and refused for any other.
///
/// Version history:
///   1.0 — #1301 round 3: initial implementation
///   1.1 — #1301 round 4: ``open(for:)`` and ``Ticket``. A membership write for another cluster is
///          dropped rather than adopted, and the adoption itself moves into ``open(for:)``, which
///          keeps what the value holds when it is opened again for the same cluster
struct ClusterDrillState {

    /// The id no cluster has, for the value a fresh view starts with. Cluster ids are the
    /// artifact's own non-negative row numbers.
    static let noCluster = Int.min

    /// The cluster these values describe.
    private let clusterId: Int

    private var resolved: SemanticMapArtifacts.Cluster?
    private var memberKeys: [String]
    private var shown: Int
    private var unavailableReason: SemanticUnavailable?
    private var savedName: String?
    private var savedResult: SemanticMapPicking.LassoResult?

    /// The right to write a membership load into a ``ClusterDrillState``, issued by
    /// ``open(for:)`` to the load it is starting (#1301 round 4).
    ///
    /// Only ``open(for:)`` can make one — its initialiser is `fileprivate` — so a load cannot write
    /// without first opening the value for its own cluster.
    ///
    /// Version history:
    ///   1.0 — #1301 round 4: initial implementation
    struct Ticket: Equatable {
        /// The cluster the load was started for.
        fileprivate let clusterId: Int
    }

    /// An empty value for `clusterId`.
    ///
    /// - Parameter clusterId: The cluster about to be loaded, or ``noCluster``.
    init(for clusterId: Int) {
        self.clusterId = clusterId
        self.resolved = nil
        self.memberKeys = []
        self.shown = 0
        self.unavailableReason = nil
        self.savedName = nil
        self.savedResult = nil
    }

    /// Makes this value the one for `clusterId` and issues the ticket that load's writes must carry.
    ///
    /// **This is the line every real drill runs through**: the view starts at ``noCluster``, so its
    /// first load always replaces the value here. A value holding **another** cluster is replaced by
    /// an empty one; a value already holding `clusterId`'s drill keeps it, because the membership
    /// task re-runs every time the view re-appears — returning from a document, say — and blanking
    /// the list the reader is returning to would swap it for a spinner and lose their place.
    ///
    /// - Parameter clusterId: The cluster the load is for.
    /// - Returns: The ticket every membership write of that load presents.
    mutating func open(for clusterId: Int) -> Ticket {
        if self.clusterId != clusterId { self = ClusterDrillState(for: clusterId) }
        return Ticket(clusterId: clusterId)
    }

    /// The resolved cluster, **only** when it was resolved for this one.
    ///
    /// - Parameter clusterId: The cluster on screen now.
    /// - Returns: The cluster, or `nil` — which this view draws as a spinner.
    func cluster(for clusterId: Int) -> SemanticMapArtifacts.Cluster? {
        self.clusterId == clusterId ? resolved : nil
    }

    /// The member document keys, **only** when they were enumerated for this cluster.
    ///
    /// - Parameter clusterId: The cluster on screen now.
    /// - Returns: The keys, in row (= volume) order, or none.
    func keys(for clusterId: Int) -> [String] {
        self.clusterId == clusterId ? memberKeys : []
    }

    /// How many of ``keys(for:)`` the list currently shows.
    ///
    /// - Parameter clusterId: The cluster on screen now.
    /// - Returns: The paging cursor, `0` for any other cluster.
    func shownCount(for clusterId: Int) -> Int {
        self.clusterId == clusterId ? shown : 0
    }

    /// Why the drill is empty, when it is — **only** for this cluster.
    ///
    /// - Parameter clusterId: The cluster on screen now.
    /// - Returns: The reason, or `nil`.
    func unavailable(for clusterId: Int) -> SemanticUnavailable? {
        self.clusterId == clusterId ? unavailableReason : nil
    }

    /// The name of the working corpus last saved **from this cluster**.
    ///
    /// - Parameter clusterId: The cluster on screen now.
    /// - Returns: The name, or `nil`.
    func savedCorpusName(for clusterId: Int) -> String? {
        self.clusterId == clusterId ? savedName : nil
    }

    /// What that save captured, for the truncation line.
    ///
    /// - Parameter clusterId: The cluster on screen now.
    /// - Returns: The capture, or `nil`.
    func savedCapture(for clusterId: Int) -> SemanticMapPicking.LassoResult? {
        self.clusterId == clusterId ? savedResult : nil
    }

    /// Stores a completed membership load — **dropped** unless `ticket` was issued for the cluster
    /// this value holds.
    ///
    /// - Parameters:
    ///   - cluster: The cluster the artifact resolved.
    ///   - keys: Its members' `"volumeId/documentId"` keys, in row order.
    ///   - shownCount: How many to show first.
    ///   - ticket: What ``open(for:)`` issued the load that asked.
    mutating func record(cluster: SemanticMapArtifacts.Cluster,
                         keys: [String],
                         shownCount: Int,
                         with ticket: Ticket) {
        guard ticket.clusterId == clusterId else { return }
        resolved = cluster
        memberKeys = keys
        shown = shownCount
    }

    /// Stores the reason this cluster has no drill — **dropped** unless `ticket` was issued for the
    /// cluster this value holds.
    ///
    /// - Parameters:
    ///   - unavailable: Why.
    ///   - ticket: What ``open(for:)`` issued the load that asked.
    mutating func record(unavailable: SemanticUnavailable, with ticket: Ticket) {
        guard ticket.clusterId == clusterId else { return }
        unavailableReason = unavailable
    }

    /// Advances the paging cursor by one page, for the cluster on screen.
    ///
    /// Refused for any other cluster: "Show more" is an action on what is displayed, and there is
    /// nothing displayed for a cluster whose load has not landed.
    ///
    /// - Parameters:
    ///   - pageSize: Documents per page.
    ///   - clusterId: The cluster on screen now.
    mutating func showMore(_ pageSize: Int, for clusterId: Int) {
        guard self.clusterId == clusterId else { return }
        shown = min(memberKeys.count, shown + pageSize)
    }

    /// Records the outcome of a Save as Working Corpus, or clears it after a failed save.
    ///
    /// - Parameters:
    ///   - savedCorpusName: The name saved, or `nil`.
    ///   - capture: What it captured, or `nil`.
    ///   - clusterId: The cluster it was saved from.
    mutating func record(savedCorpusName: String?,
                         capture: SemanticMapPicking.LassoResult?,
                         for clusterId: Int) {
        guard self.clusterId == clusterId else { return }
        savedName = savedCorpusName
        savedResult = capture
    }
}

// MARK: - ClusterDocumentsView

/// One cluster's document drill (#1051 B-7): the R-3 degraded-row list over the
/// cluster's whole membership, paged — cluster 15 holds 37,865 documents against the
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
///   1.1 — #1301: both load tasks are keyed on `clusterId`, under the reuse contract at
///          `BrowserView.levelView`. Latent — no row appends `.clusterDocuments` from a
///          `.clusterDocuments` — but this is a payload-carrying level view, which is the shape
///          the contract covers without exceptions
///   1.2 — #1301 round 2: both keys come from `BrowseLoadKey`, where a test holds each to varying
///          with every component of its payload. Nothing behavioural can reach these two (the
///          self-to-self step does not exist yet), so a value assertion is the only gate there is
///   1.3 — #1301 round 3: both loads go through modifiers that derive their own keys, and the
///          view's per-cluster state moves into ``ClusterDrillState``. Round 2 keyed this view
///          and did not clear it, so the reuse the key exists for would have shown the previous
///          cluster's document list under the new cluster's title — and, when the new cluster is
///          missing from the artifact, kept showing it, because that path sets `unavailable` and
///          returns without touching `cluster`
///   1.4 — #1301 round 4: the membership load opens ``ClusterDrillState`` for its cluster and
///          writes with the ticket that issues, so a superseded scan's late write is dropped rather
///          than erasing the cluster on screen; and both loads stop at a cancellation, which is the
///          only guard the title and date dictionaries have. The metadata load's indexed-volume
///          count — round 3 counted it among the closed survivors — is recorded as ACCEPTED at its
///          call site, with the reason no walk can see it against the UI-test fixture
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

    /// Everything this view holds for the cluster it is showing, carried with that cluster's id
    /// (#1301 round 3). The six accessors below read through it; see ``ClusterDrillState``.
    @State private var drill = ClusterDrillState(for: ClusterDrillState.noCluster)

    /// The cluster's metadata, re-resolved live from the loaded artifact — `nil` until it has been
    /// resolved **for this cluster**.
    private var cluster: SemanticMapArtifacts.Cluster? { drill.cluster(for: clusterId) }
    /// Every member's `"volumeId/documentId"` key, in row (= volume) order.
    private var keys: [String] { drill.keys(for: clusterId) }
    /// How many keys the list currently shows (the paging cursor).
    private var shownCount: Int { drill.shownCount(for: clusterId) }
    /// Why the drill is empty, when it is.
    private var unavailable: SemanticUnavailable? { drill.unavailable(for: clusterId) }
    /// The last save's outcome, for the confirmation + truncation lines.
    private var savedCorpusName: String? { drill.savedCorpusName(for: clusterId) }
    private var savedCapture: SemanticMapPicking.LassoResult? { drill.savedCapture(for: clusterId) }

    /// Bulk-loaded display metadata, keyed by `"volumeId/documentId"`.
    ///
    /// Deliberately NOT part of ``ClusterDrillState``: these are addressed by document key, not by
    /// cluster, so an entry left over from another cluster is only ever read for the document it
    /// describes — and `loadMetadata()` replaces the whole dictionary on every page it loads.
    @State private var headers: [String: CrossReferenceStore.DocumentTitleFacts] = [:]
    @State private var dates: [String: String] = [:]

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
        // Keyed on the cluster, under the reuse contract at `BrowserView.levelView` (#1301; welded
        // into a modifier in round 3, so neither call site here holds a key). This is a level view
        // with a payload, and on iPad the detail pane renders the level in place, so a
        // `.clusterDocuments → .clusterDocuments` step would reuse this view and a bare `.task`
        // would never re-run for the new cluster — the #1301 shape exactly. No row appends that
        // step today, so no walk can gate it; `ClusterDrillState` is what keeps the OTHER half
        // from mattering, by refusing to report one cluster's rows under another's title and
        // dropping a superseded load's late write.
        .clusterMembershipLoad(clusterId: clusterId) { await loadMembership() }
        // Re-keyed on the indexed-volume count so finishing an index pass upgrades the
        // degraded rows without navigating away (the B-4 idiom), and on the cluster for the
        // reason above. Both components are arguments to the modifier, which derives the key:
        // the count-only form still re-keys on indexing, so as a key written here it read in a
        // diff as the working idiom.
        //
        // THE COUNT COMPONENT IS ACCEPTED, NOT GATED (#1301 round 4; round 3 counted it closed, and
        // it is not). Passing a constant count here, or loading metadata from the membership key
        // instead, compiles and leaves every suite green: `clusterMetadataKeyVariesWithBothComponents`
        // holds the key FUNCTION and cannot see this call. The harm needs no self-to-self step. Tap
        // **Index** on a degraded row, or finish any index elsewhere, and the rows turn openable —
        // `rowState` reads `indexedVolumeIds` live — but `headers` and `dates` are never asked for
        // again, so they keep a fallback title and no date until the reader leaves the drill. That is
        // mild, and no walk can see it against the UI-test fixture: the seeded volume DOES appear in
        // cluster drills as degraded rows (cluster 169's first page holds its d15, d43, d98, d115 and
        // d119, measured from the shipped artifact), but the fixture holds none of those documents —
        // its d1–d3 are unclustered and n1, n2 and t1 are not in the artifact — so indexing it from a
        // drill fills no title under this code or under the mutant. A walk needs a fixture document
        // with a clustered id, which moves every suite that reads the fixture.
        .clusterMetadataLoad(clusterId: clusterId,
                             indexedVolumeCount: appState.indexedVolumeIds.count) {
            await loadMetadata()
        }
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
            // R-1b: the LAYOUT identity, not the family digest. A cluster id means nothing outside
            // the layout that minted it, and the family digest is unchanged by a relayout — see
            // `SemanticMapArtifacts.MapIndex.layoutIdentity`.
            if let onSeeMap, let digest = BundledSemanticMap.index?.layoutIdentity {
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
                drill.showMore(Self.pageSize, for: clusterId)
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
                    header: DocumentDisplayTitle.text(headers[ref.key], documentId: ref.documentId),
                    dateline: nil,
                    sourceNote: nil
                ))
                #if DEBUG
                print("[ClusterDocumentsView] Open \(ref.key)")
                #endif
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(DocumentDisplayTitle.text(headers[ref.key], documentId: ref.documentId))
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
    /// values over an mmapped file, and the largest cluster in the shipped artifact mints
    /// 37,865 keys.
    private func loadMembership() async {
        let id = clusterId
        // OPENED FIRST (#1301 round 4). The view starts at `ClusterDrillState.noCluster`, so this
        // is where every real drill becomes this cluster's, and the ticket it issues is the only
        // way the writes below can land — a load that skipped it would not compile.
        let ticket = drill.open(for: id)
        for _ in 0..<40 {
            await BundledSemanticMap.prepare()
            if BundledSemanticMap.index != nil { break }
            guard BundledSemanticMap.unavailableReason == .pending else { break }
            try? await Task.sleep(nanoseconds: 150_000_000)
        }
        // A cancelled task spins through the loop above — `Task.sleep` throws at once and `try?`
        // swallows it — and would then record `.pending` as this cluster's reason, which a value
        // re-opened for the same cluster keeps: "Clusters Unavailable" on the way back to a drill
        // whose artifact was merely still loading when the reader left it.
        guard !Task.isCancelled else { return }
        guard let mapIndex = BundledSemanticMap.index,
              let map = BundledSemanticMap.vectors,
              let vectorIndex = BundledSemanticVectors.index,
              let resolved = mapIndex.clusters.first(where: { $0.id == id }) else {
            drill.record(
                unavailable: BundledSemanticMap.unavailableReason
                    ?? .malformedArtifact("cluster \(id) not in artifact"),
                with: ticket)
            return
        }
        let loadedKeys = await Task.detached(priority: .userInitiated) { () -> [String] in
            let found = ClustersAxis.membershipRows(in: map, clusterId: id)
            return ClustersAxis.documentKeys(rows: found.rows, index: vectorIndex)
        }.value
        // `.task(id:)` cancels this task when the level moves to another cluster, but awaiting a
        // detached task's `value` is not a cancellation point, so execution reaches here either
        // way. Two guards, and the ticket is the one the tests pin: a cancelled load stops here —
        // before a metadata load for a cluster it no longer shows — and a write that got past this
        // anyway is dropped unless its ticket names the cluster the value now holds.
        guard !Task.isCancelled else { return }
        drill.record(cluster: resolved,
                     keys: loadedKeys,
                     shownCount: min(loadedKeys.count, Self.pageSize),
                     with: ticket)
        await loadMetadata()
        #if DEBUG
        print("[ClusterDocumentsView] Cluster \(id): \(loadedKeys.count) members enumerated")
        #endif
    }

    /// The bulk metadata load for the VISIBLE slice — one chunked call per store,
    /// never per-key queries (the B-4 rule; a page is 500 keys, not 37,865).
    private func loadMetadata() async {
        let visible = Array(keys.prefix(shownCount))
        guard !visible.isEmpty else { return }
        let pairs = visible.compactMap { key -> (volumeId: String, documentId: String)? in
            let parts = key.split(separator: "/", maxSplits: 1)
            guard parts.count == 2 else { return nil }
            return (String(parts[0]), String(parts[1]))
        }
        // Each write stops at a cancellation (#1301 round 4). These two dictionaries are NOT in
        // `ClusterDrillState` — they are addressed by document key — so no ticket protects them, and
        // each assignment REPLACES the whole dictionary: a superseded load landing after the
        // current one would put back the page it was asked for and take away this one's titles and
        // dates. The metadata task is re-keyed by every index pass, so the load it supersedes is
        // usually for the same cluster, and this check is what keeps the newer load's answer.
        if let store = appState.crossReferenceStore,
           let loaded = try? await store.documentTitleFacts(for: pairs) {
            guard !Task.isCancelled else { return }
            headers = loaded
        }
        if let pipeline = appState.indexingPipeline,
           let loaded = try? await pipeline.datesByDocumentKey(pairs) {
            guard !Task.isCancelled else { return }
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
            drill.record(savedCorpusName: name, capture: capture, for: clusterId)
        } catch {
            drill.record(savedCorpusName: nil, capture: nil, for: clusterId)
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
