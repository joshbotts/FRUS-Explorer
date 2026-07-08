// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - VolumeSourcesView

/// Shows the archival sources list from a volume's front-matter `<div type="sources">` section.
///
/// Sources are loaded from `IndexingPipeline.volumeSources(forVolumeId:)`, which queries the
/// `volume_sources` SQLite table populated during indexing. Entries are shown in insertion
/// order (matching the TEI source list). Each entry displays:
/// - `rawText`: the full human-readable citation string (always present)
/// - `recordGroup` / `repository` / `lotFile` / `seriesName` as secondary metadata when non-nil
///
/// The view is embedded inside `CompilationView` when the browser navigates to a
/// `<div type="sources">` structural section.
///
/// ## Indexing Dependency
/// The `volume_sources` table is populated during indexing — volumes that have not been
/// indexed yet will show an empty list with a prompt to index the volume.
///
/// Version history:
///   1.0 — Session 2026-06-08: initial implementation
///   1.1 — Session 2026-07-03: sheet presentation HOISTED to the embedding parents
///          (CompilationView / the macOS corpus-browser section view). Modifiers on
///          `Group`/`Section` inside `List` content apply per child/row, so any
///          `.sheet(item:)` attached in this section-emitting view creates multiple
///          presenters over one binding — the reported Archival Neighbors open/close
///          loop (the first fix moved the anchor from the Group to a Section, which
///          did not help for the same reason). Targets are now `@Binding`s; the target
///          types and `VolumeSourcesCrossVolumeSheet` became internal for the parents
///   1.2 — Session 2026-07-03 (Source Explorer Phase 3 step 2): `makeNeighborsTarget`
///          gains the presidential-library and decimal-class target kinds (and became
///          a testable static); bibliography rows render as plain rows in their own
///          section, excluded by construction from every neighbor/catalog affordance.
///   1.3 — Session 2026-07-03 (Phase 3 adversarial-review fixes): the bibliography
///          kind is now detected from the encodings the corpus actually uses
///          (`Published Sources` pseudo-heading subtrees and published-sources
///          section heads, not just the corpus-unused `listofworks`), so this view's
///          Published Sources section renders for real volumes.
///   1.4 — Session 2026-07-03 (Source Explorer Phase 4 step 2): rows that resolve to
///          a bundled collection-authority record (`CollectionAuthorityStore`, via the
///          shared `CollectionKeying.frontMatterIdentity` derivation) upgrade the
///          cross-volume affordance to the full Collection detail (aliases, NAID link,
///          S5 local counts, sub-series); the old `VolumeSourcesIndexStore` cross-
///          volume sheet remains as the fallback for headings the authority does not
///          track. Neighbors targets carry the record's alias fallback for the
///          display-time grain-mismatch retry in the matcher.
///   1.5 — Session 2026-07-04 (Source Explorer Phase 5 step 1): three-state neighbor
///          affordance. After `loadSources`, ONE batched query
///          (`IndexingPipeline.archivalNeighborCounts(forKeys:)`) resolves neighbor
///          counts for every keyed entry (grouped per key family — no per-row
///          queries), and rows render: no key → no affordance; keyed with 0 → a
///          subdued affordance with an honest "nothing in your index cites this"
///          hint; keyed with N → the button with a count badge. Counts use the
///          direct key paths only — the Phase-4 alias fallback is excluded (cost:
///          it fans out per record; see `archivalNeighborCounts`), so an opened
///          sheet can exceed its badge (including 0 → N) when the fallback fires.
///   1.6 — Session 2026-07-04 (Source Explorer Phase 5 S6): on macOS the neighbors
///          affordance opens the Archival Neighbors WINDOW
///          (`openWindow(value: ArchivalNeighborsRequest(volumeSource:))`) instead of
///          setting the hoisted sheet binding — `openWindow` is an action, not a
///          presentation modifier, so it is safe inside this section-emitting view.
///          `sourceNeighborsTarget` is now written on iOS only.
///   1.7 — Session 2026-07-04 (Phase 5 adversarial-review fixes): neighbor-count
///          badges refresh when a bulk indexing run finishes
///          (`currentIndexingProgress` → `nil`, mirroring CompilationView's
///          observer) — previously a stale subdued 0 kept asserting "no documents
///          in your indexed volumes cite this collection" after the user indexed
///          more volumes mid-session.
///   1.8 — Session 2026-07-04 (macOS UI audit B2): on macOS the cross-volume
///          affordance opens the Cross-Volume Provenance WINDOW
///          (`openWindow(value: CrossVolumeProvenanceRequest(…))`) instead of setting
///          the hoisted sheet binding — mirroring the S6 neighbors conversion.
///          `crossVolumeTarget` is now written on iOS only.
struct VolumeSourcesView: View {

    /// The volume whose sources list is being shown.
    let volumeId: String

    @Environment(AppState.self) private var appState
    #if os(macOS)
    /// Opens the S6 Archival Neighbors window (`WindowGroup(for: ArchivalNeighborsRequest.self)`).
    /// Calling `openWindow` from row content is safe — unlike presentation modifiers,
    /// it is an action, so the Group/Section-in-List anchoring rule does not apply.
    @Environment(\.openWindow) private var openWindow
    #endif

    @State private var sources: [VolumeSourceEntry] = []
    @State private var isLoading = true
    /// Guards `loadSources()` against duplicate runs. The body is a `Group` emitting list
    /// sections, and SwiftUI applies `Group` modifiers to each child — so `.task` fires
    /// again for every section that appears when the loading branch swaps to the loaded
    /// one. Without the guard each re-run rebuilt `collectionTree` with fresh node UUIDs,
    /// collapsing the outline's disclosure state.
    @State private var didLoad = false
    /// When set by a row's button, the PARENT presents the Archival Neighbors sheet.
    /// **iOS only** — on macOS the row opens the S6 Archival Neighbors window directly
    /// and this binding is never written.
    ///
    /// Presentation state is deliberately hoisted to the embedding view: this view emits
    /// list sections, and modifiers attached to `Group`/`Section` inside `List` content
    /// are applied per child/row — several presenters sharing one item binding ping-pong
    /// present/dismiss after close (the twice-reported Archival Neighbors open/close
    /// loop). The `.sheet(item:)` must anchor exactly once, on the parent's `List`.
    @Binding var sourceNeighborsTarget: VolumeSourceNeighborsTarget?
    /// When set by a row's button, the PARENT presents the cross-volume provenance sheet
    /// (see `sourceNeighborsTarget` for why presentation is hoisted). **iOS only** —
    /// on macOS the row opens the B2 Cross-Volume Provenance window directly and this
    /// binding is never written.
    @Binding var crossVolumeTarget: CrossVolumeTarget?
    /// When set by a row's button, the PARENT presents the Collection detail sheet for
    /// a bundled authority record (see `sourceNeighborsTarget` for why presentation is
    /// hoisted).
    @Binding var collectionDetailTarget: AuthorityCollectionRecord?

    /// The narrative "Note on Sources" paragraphs, shown as flowing prose.
    private var proseEntries: [VolumeSourceEntry] { sources.filter { $0.kind == .prose } }

    /// Published-works bibliography rows (a `Published Sources` pseudo-heading
    /// subtree, a published-sources section, or `listofworks`), shown as plain rows —
    /// deliberately without neighbor or catalog affordances (they cite books, not
    /// archival collections; audit §2.3 counted 2,634 masquerading as resolvable).
    private var bibliographyEntries: [VolumeSourceEntry] { sources.filter { $0.kind == .bibliography } }

    /// The archival-collection outline, built **once** in `loadSources`. It must be stored
    /// (not recomputed per render): `SourceTreeNode` ids are `UUID`s, so rebuilding the tree
    /// on each body evaluation would hand `OutlineGroup` fresh identities and collapse the
    /// user's expanded disclosure state on any re-render (e.g. opening the neighbors sheet).
    @State private var collectionTree: [SourceTreeNode] = []

    /// Neighbor counts for every keyed entry, resolved by ONE batched query after
    /// `loadSources` (`IndexingPipeline.archivalNeighborCounts(forKeys:)` — grouped
    /// per key family, never per row). `nil` until loaded (rows show the plain
    /// button); once loaded, every keyed row renders its three-state affordance
    /// (0 → subdued + honest hint, N → count badge). Counts use direct keys only —
    /// no alias fallback — so an opened sheet may exceed its badge.
    @State private var neighborCounts: [IndexingPipeline.ArchivalNeighborCountKey: Int]? = nil

    /// Collapses the replicated `onChange` firings from the Group-modifier gotcha (this
    /// body emits multiple sections, so modifiers on the `Group` apply per child) into
    /// one count refresh per indexing-run completion. Set synchronously on the main
    /// actor before the refresh `Task` starts, so sibling firings bail out.
    @State private var isRefreshingCounts = false

    var body: some View {
        Group {
            if isLoading {
                Section {
                    HStack {
                        ProgressView()
                        Text(String(localized: "browser.sources.loading",
                                    defaultValue: "Loading sources…"))
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                    .padding(.vertical, 4)
                }
            } else if sources.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "browser.sources.empty.title",
                                    defaultValue: "No Sources Listed"))
                            .font(.headline)
                        Text(String(localized: "browser.sources.empty.detail",
                                    defaultValue: "Index this volume to load its archival sources list."))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            } else {
                // The section's narrative introduction, then the nested outline of the
                // archival collections it drew on (mirroring history.state.gov/…/sources).
                if !proseEntries.isEmpty {
                    Section(header: Text(String(localized: "browser.sources.about.header",
                                                defaultValue: "About These Sources"))) {
                        ForEach(Array(proseEntries.enumerated()), id: \.offset) { _, entry in
                            Text(entry.rawText)
                                .font(.callout)
                                .textSelection(.enabled)
                                .padding(.vertical, 2)
                        }
                    }
                }
                if !collectionTree.isEmpty {
                    // NO presentation modifiers here: a `.sheet` attached to this Section
                    // (or the enclosing Group) is applied per row inside the parent List,
                    // creating multiple presenters over one binding — the open/close loop.
                    // The sheets anchor once, on the parent's List (see the bindings above).
                    Section(header: Text(String(localized: "browser.sources.collections.header",
                                                defaultValue: "Archival Collections"))) {
                        OutlineGroup(collectionTree, children: \.children) { node in
                            sourceNodeRow(node.entry)
                        }
                    }
                }
                if !bibliographyEntries.isEmpty {
                    // Plain rows only: published works carry no archival match keys, so
                    // no neighbor or catalog affordance can ever attach to them.
                    Section(header: Text(String(localized: "browser.sources.bibliography.header",
                                                defaultValue: "Published Sources"))) {
                        ForEach(Array(bibliographyEntries.enumerated()), id: \.offset) { _, entry in
                            Text(entry.rawText)
                                .font(.callout)
                                .textSelection(.enabled)
                                .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
        .task { await loadSources() }
        // Refresh the count badges when a bulk indexing run finishes (Settings-triggered
        // or otherwise): newly indexed volumes can add neighbors, and a stale subdued 0
        // asserts "no documents in your indexed volumes cite this collection" — now
        // false. Mirrors CompilationView's `currentIndexingProgress` observer for its
        // document list. The `isRefreshingCounts` flag absorbs the Group-modifier
        // replication (this body emits sections, so `.onChange` fires once per child).
        .onChange(of: appState.currentIndexingProgress) { _, progress in
            guard progress == nil, didLoad, !isRefreshingCounts else { return }
            isRefreshingCounts = true
            Task {
                await loadNeighborCounts()
                isRefreshingCounts = false
            }
        }
    }

    /// One archival-collection outline row: its own text (bold for a major named collection —
    /// a `<hi rend="strong">` heading), a link to the resolved NARA Catalog record where the
    /// collection resolved, an Archival Neighbors affordance where the node carries a
    /// resolvable match key (lot file, or record group + series), and — for a major
    /// collection cited by more than one volume — a cross-volume provenance affordance.
    private func sourceNodeRow(_ entry: VolumeSourceEntry) -> some View {
        // O(1) lookups into the bundled indexes (decoded once, warmed off-main).
        let resolution = VolumeSourcesIndexStore.shared?.resolution(
            recordGroup: entry.recordGroup, lotFile: entry.lotFile)
        // Phase 4: the collection-authority record this row resolves to, via the
        // shared front-matter identity derivation (lot key, else repository-scoped
        // leading segment, else unambiguous alias).
        let authority = CollectionAuthorityStore.shared?.record(
            forFrontMatterText: entry.rawText, repository: entry.repository,
            lotFileNorm: entry.lotFileNorm, decimalClass: entry.decimalClass)
        // Legacy cross-volume fallback for headings the authority does not track.
        let crossVolume: MajorCollectionRecord? = (entry.isHeading && authority == nil)
            ? VolumeSourcesIndexStore.shared?.authority(
                recordGroup: entry.recordGroup, lotFile: entry.lotFile, text: entry.rawText)
            : nil
        return VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .top, spacing: 8) {
                Text(entry.rawText)
                    .font(entry.isHeading ? .callout.weight(.semibold) : .callout)
                    .textSelection(.enabled)
                Spacer(minLength: 8)
                if let url = resolution?.url {
                    Link(destination: url) {
                        Image(systemName: "building.columns")
                    }
                    .buttonStyle(.borderless)
                    .help(String(localized: "browser.sources.catalog.help",
                                 defaultValue: "View this collection in the National Archives Catalog"))
                    .accessibilityLabel(String(localized: "browser.sources.catalog",
                                               defaultValue: "View in National Archives Catalog"))
                }
                if let target = Self.makeNeighborsTarget(for: entry, volumeId: volumeId) {
                    // Three-state affordance (Phase 5): nil count = batch still
                    // loading (plain button), 0 = subdued + honest hint (still
                    // tappable — the alias fallback may rescue the opened sheet),
                    // N = count badge.
                    let count = neighborCount(for: target)
                    Button {
                        // The authority record's lot key and alias forms ride along for
                        // the matcher's display-time fallback when the direct key misses.
                        var presented = target
                        if let authority {
                            presented.aliasFallback = .init(record: authority)
                        }
                        #if os(macOS)
                        // S6: neighbors open in their own window (browsable beside
                        // the reading window); iOS keeps the hoisted parent sheet.
                        openWindow(value: ArchivalNeighborsRequest(volumeSource: presented))
                        #else
                        sourceNeighborsTarget = presented
                        #endif
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "archivebox")
                            if let count {
                                Text(count, format: .number)
                                    .font(.caption.monospacedDigit())
                            }
                        }
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(count == 0 ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.tint))
                    .help(count == 0
                          ? String(localized: "browser.sources.archivalNeighbors.zero.help",
                                   defaultValue: "No documents in your indexed volumes cite this collection — indexing more volumes may surface some")
                          : String(localized: "browser.sources.archivalNeighbors.help",
                                   defaultValue: "Show indexed documents drawn from this archival source"))
                    .accessibilityLabel(neighborsAccessibilityLabel(count: count))
                }
            }
            if let authority {
                // The upgraded cross-volume affordance: the full Collection detail
                // (aliases, catalog link, S5 local counts, citing volumes, sub-series).
                Button {
                    collectionDetailTarget = authority
                } label: {
                    Label {
                        Text(String(localized: "browser.sources.collection",
                                    defaultValue: "Collection · cited in \(authority.volumeIds.count) volumes"))
                    } icon: {
                        Image(systemName: "books.vertical")
                    }
                    .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .accessibilityHint(String(localized: "browser.sources.collection.hint",
                                          defaultValue: "Opens the collection's cross-volume detail"))
            } else if let crossVolume, crossVolume.volumeIds.count > 1 {
                Button {
                    // B2: window on macOS (browsable beside the volumes it names);
                    // hoisted parent sheet on iOS. `openWindow` is an action, so it
                    // is safe inside this section-emitting view (unlike a sheet).
                    #if os(macOS)
                    openWindow(value: CrossVolumeProvenanceRequest(
                        title: entry.rawText, volumeIds: crossVolume.volumeIds))
                    #else
                    crossVolumeTarget = CrossVolumeTarget(
                        title: entry.rawText, volumeIds: crossVolume.volumeIds)
                    #endif
                } label: {
                    Label {
                        Text(String(localized: "browser.sources.crossVolume",
                                    defaultValue: "Cited in \(crossVolume.volumeIds.count) volumes"))
                    } icon: {
                        Image(systemName: "books.vertical")
                    }
                    .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .accessibilityHint(String(localized: "browser.sources.crossVolume.hint",
                                          defaultValue: "Lists the other volumes that cite this collection"))
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Neighbor Counts (Phase 5)

    /// The batched neighbor count for a row's target: `nil` while the batch is
    /// loading (or when the batch failed — the row keeps the plain button rather
    /// than lying with a 0), otherwise the count under the row's derived key.
    private func neighborCount(for target: VolumeSourceNeighborsTarget) -> Int? {
        guard let counts = neighborCounts,
              let key = IndexingPipeline.neighborCountKey(
                  forLotFile: target.lotFile, recordGroup: target.recordGroup,
                  series: target.series, repository: target.repository,
                  decimalClass: target.decimalClass) else { return nil }
        return counts[key] ?? 0
    }

    /// VoiceOver label for the three-state neighbors affordance.
    private func neighborsAccessibilityLabel(count: Int?) -> String {
        switch count {
        case .some(0):
            return String(localized: "browser.sources.archivalNeighbors.zero.accessibility",
                          defaultValue: "Archival Neighbors — no documents in your indexed volumes cite this collection; indexing more volumes may surface some")
        case .some(let n):
            return String(format: String(localized: "browser.sources.archivalNeighbors.count.accessibility %lld",
                                         defaultValue: "Archival Neighbors — %lld indexed documents"),
                          Int64(n))
        case nil:
            return String(localized: "browser.sources.archivalNeighbors",
                          defaultValue: "Archival Neighbors")
        }
    }

    // MARK: - Outline Reconstruction

    /// Rebuilds the collection outline from the flat, pre-ordered `.item` rows using each
    /// row's `depth` (0 = a top-level collection). Parents precede their children in the
    /// input, so a single left-to-right pass with a recursive descent suffices.
    static func buildTree(_ items: [VolumeSourceEntry]) -> [SourceTreeNode] {
        var index = 0
        return build(items, &index, depth: 0)
    }

    private static func build(_ items: [VolumeSourceEntry], _ index: inout Int, depth: Int) -> [SourceTreeNode] {
        var nodes: [SourceTreeNode] = []
        while index < items.count {
            let item = items[index]
            if item.depth < depth { break }   // belongs to an ancestor level
            // Process the row at this level, then collect children relative to its *own*
            // depth. A row deeper than expected (an orphan from a skipped/empty container
            // level) is clamped here rather than dropped, so no subtree is ever lost.
            index += 1
            let children = build(items, &index, depth: item.depth + 1)
            nodes.append(SourceTreeNode(entry: item, children: children.isEmpty ? nil : children))
        }
        return nodes
    }

    /// Builds an archival-neighbors target for a source entry, or `nil` when the entry
    /// has no match key on any path. Used to gate the per-row "Archival Neighbors"
    /// affordance so it only appears where a query can return results.
    ///
    /// Target kinds (mirroring `IndexingPipeline.archivalNeighbors(forLotFile:…)`):
    /// - **Lot file** (`lotFile`).
    /// - **Decimal / subject-numeric class leaf** (`decimalClass`).
    /// - **Presidential library**: `repository` names a library and a collection name
    ///   exists. Library children rarely pass the series-name gate (it requires an
    ///   RG or lot on the row), so the entry's own text — which *is* the collection
    ///   name in the library outline — stands in. The library heading row itself
    ///   (own text naming the repository) gets no target: its "collection" would be
    ///   the library's name, not a match key.
    /// - **Record group + series** (`recordGroup` + `series`).
    ///
    /// Bibliography rows never produce a target (published works, not collections).
    /// Pure and `nonisolated static` so tests can exercise the gating without a
    /// rendered view or a main-actor hop.
    nonisolated static func makeNeighborsTarget(for entry: VolumeSourceEntry, volumeId: String) -> VolumeSourceNeighborsTarget? {
        guard entry.kind == .item else { return nil }
        func trimmed(_ s: String?) -> String? {
            guard let t = s?.trimmingCharacters(in: .whitespaces), !t.isEmpty else { return nil }
            return t
        }
        let lot  = trimmed(entry.lotFile)
        let cls  = trimmed(entry.decimalClass)
        let rg   = trimmed(entry.recordGroup)
        let repo = trimmed(entry.repository)
        var series = trimmed(entry.seriesName)
        var libraryRepo: String? = nil
        if let repo, IndexingPipeline.isLibraryRepository(repo) {
            if series == nil,
               !entry.rawText.localizedCaseInsensitiveContains(repo),
               entry.rawText.count >= 4 {
                series = entry.rawText
            }
            if series != nil { libraryRepo = repo }
        }
        let hasKey = lot != nil || cls != nil || libraryRepo != nil
            || (rg != nil && series != nil)
        guard hasKey else { return nil }
        return VolumeSourceNeighborsTarget(
            lotFile:      lot,
            recordGroup:  rg,
            series:       series,
            repository:   libraryRepo,
            decimalClass: cls,
            volumeId:     volumeId
        )
    }

    // MARK: - Data Loading

    private func loadSources() async {
        guard !didLoad else { return }
        didLoad = true
        // Warm the bundled indexes (a ~1 MB and a ~2 MB decode) off the main thread so
        // the per-row catalog / collection-authority lookups in `sourceNodeRow` never
        // block rendering.
        await Task.detached(priority: .utility) {
            _ = VolumeSourcesIndexStore.shared
            _ = CollectionAuthorityStore.shared
        }.value
        guard let pipeline = appState.indexingPipeline else {
            isLoading = false
            return
        }
        let entries = (try? await pipeline.volumeSources(forVolumeId: volumeId)) ?? []
        sources = entries
        collectionTree = Self.buildTree(entries.filter { $0.kind == .item })
        isLoading = false
        #if DEBUG
        print("[VolumeSourcesView] Loaded \(entries.count) sources for \(volumeId)")
        #endif
        // Phase 5: ONE batched round-trip per key family resolves neighbor counts
        // for every keyed entry (never per-row). Runs after the rows render, so the
        // list never waits on the counts; rows upgrade in place when they arrive.
        await loadNeighborCounts()
    }

    /// Resolves (or re-resolves) the batched neighbor counts for the loaded entries —
    /// ONE `IndexingPipeline.archivalNeighborCounts(forKeys:)` round-trip per call,
    /// never per row. Called once from `loadSources()` and again whenever a bulk
    /// indexing run finishes (`currentIndexingProgress` → `nil`): newly indexed
    /// volumes can turn a subdued 0 badge into a real count, and a stale 0 would
    /// falsely assert "no documents in your indexed volumes cite this collection".
    private func loadNeighborCounts() async {
        guard let pipeline = appState.indexingPipeline else { return }
        let keys = sources.compactMap { entry -> IndexingPipeline.ArchivalNeighborCountKey? in
            guard let target = Self.makeNeighborsTarget(for: entry, volumeId: volumeId) else { return nil }
            return IndexingPipeline.neighborCountKey(
                forLotFile: target.lotFile, recordGroup: target.recordGroup,
                series: target.series, repository: target.repository,
                decimalClass: target.decimalClass)
        }
        neighborCounts = keys.isEmpty
            ? [:]
            : try? await pipeline.archivalNeighborCounts(forKeys: keys)
        #if DEBUG
        print("[VolumeSourcesView] Neighbor counts loaded for \(keys.count) keyed entries")
        #endif
    }
}

// MARK: - VolumeSourceNeighborsTarget

/// Identifiable `.sheet(item:)` target carrying a volume source entry's archival match
/// keys for the Archival Neighbors sheet: lot file, record group + series,
/// presidential-library repository + collection (in `series`), or decimal /
/// subject-numeric class. Fields mirror the parameters of
/// `IndexingPipeline.archivalNeighbors(forLotFile:recordGroup:series:repository:decimalClass:limit:)`.
struct VolumeSourceNeighborsTarget: Identifiable {
    let lotFile: String?
    let recordGroup: String?
    let series: String?
    /// Set only when the entry routes through the presidential-library match path.
    let repository: String?
    /// The decimal / subject-numeric class-leaf key, when the entry is a class leaf.
    let decimalClass: String?
    /// The volume this front-matter source entry belongs to — seeds the "This volume"
    /// default scope of the Archival Neighbors picker (#217).
    let volumeId: String
    /// The bundled authority record's keys and alias forms (Phase 4), consulted by the
    /// matcher only when every direct key path returns zero — see
    /// `IndexingPipeline.archivalNeighbors(forLotFile:…)` for the documented order.
    var aliasFallback: IndexingPipeline.CollectionAliasFallback? = nil
    let id = UUID()
}

// MARK: - SourceTreeNode

/// A node in the reconstructed archival-collection outline, for `OutlineGroup`. `children`
/// is `nil` for a leaf so the disclosure triangle only appears where there is something to
/// expand.
struct SourceTreeNode: Identifiable {
    let id = UUID()
    let entry: VolumeSourceEntry
    var children: [SourceTreeNode]?
}

// MARK: - CrossVolumeTarget

/// Identifiable `.sheet(item:)` target carrying a major collection's cross-volume authority:
/// the collection's display text and the volumes whose Sources sections cite it.
struct CrossVolumeTarget: Identifiable {
    let title: String
    let volumeIds: [String]
    let id = UUID()
}

// MARK: - CrossVolumeProvenanceRequest

/// A **value-typed, restorable description** of one cross-volume provenance listing —
/// the hand-off payload for the macOS Cross-Volume Provenance window scene
/// (`WindowGroup(for: CrossVolumeProvenanceRequest.self)`, UI audit B2).
///
/// The payload is fully self-contained: the citing-volume ids come from the bundled
/// `volume-sources-index.json` authority at the moment the row is tapped, and volume
/// titles resolve at render time against the always-available bundled manifest — so a
/// window restored at relaunch renders complete rows immediately, with **no**
/// `indexingPipeline` dependency and therefore no boot race and no possible false
/// empty state (the S6 "Preparing your index…" guard is not needed here by
/// construction; `volumeIds` is non-empty at every call site).
///
/// The request is deliberately the **legacy** (title + volume ids) shape, not a
/// Phase-4 authority-record key: rows that resolve to a bundled
/// `AuthorityCollectionRecord` never present this surface at all — they upgrade to
/// the full Collection detail (`CollectionDetailSheet` / the Source Explorer
/// window), which already lists citing volumes. This window exists precisely for
/// the headings the authority does not track.
///
/// Identity is the full payload: `openWindow(value:)` focuses an existing window
/// whose request compares equal and opens a new one otherwise — one window per
/// distinct collection heading, browsable side by side.
///
/// Version history:
///   1.0 — Session 2026-07-04 (macOS UI audit B2): initial implementation
struct CrossVolumeProvenanceRequest: Codable, Hashable, Sendable {
    /// The collection's front-matter display text, shown as context.
    let title: String
    /// The citing volumes, sorted (as stored in the bundled authority).
    let volumeIds: [String]
}

// MARK: - CrossVolumeProvenanceContent

/// The shared **core** of both cross-volume provenance presentations: the citing-volume
/// list with navigable rows. Chrome stays with the callers — `VolumeSourcesCrossVolumeSheet`
/// wraps it in a `NavigationStack` with a Done button (iOS sheets), and the macOS
/// `CrossVolumeProvenanceWindowView` shows it bare under a window title/subtitle.
///
/// Row taps post the volume to `AppState.pendingBrowseVolume` (consumed by the
/// Corpus Browser window on macOS and the Browse tab on iOS — UI audit gap 12: the
/// rows used to be dead ends) and then invoke `onNavigate`: the sheet passes
/// `dismiss`, the window passes nothing so the list stays open beside the browser.
///
/// Version history:
///   1.0 — Session 2026-07-04 (macOS UI audit B2/gap 12): extracted from
///          `VolumeSourcesCrossVolumeSheet`; rows became navigable
struct CrossVolumeProvenanceContent: View {

    /// The collection's display text, shown as the list footer.
    let collectionTitle: String
    /// The citing volumes, sorted (as stored in the authority).
    let volumeIds: [String]
    /// Invoked after a row tap posts its navigation hand-off. The iOS sheet dismisses
    /// here; the macOS window intentionally stays open (browsable alongside the browser).
    var onNavigate: (() -> Void)? = nil

    @Environment(AppState.self) private var appState
    #if os(macOS)
    /// Opens the Corpus Browser window for a tapped volume row.
    @Environment(\.openWindow) private var openWindow
    #endif

    var body: some View {
        List {
            Section {
                ForEach(volumeIds, id: \.self) { volumeId in
                    Button {
                        open(volumeId)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(appState.manifestStore.entry(forVolumeId: volumeId)?.title ?? volumeId)
                                .font(.callout)
                            Text(volumeId)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(String(localized: "browser.sources.crossVolume.row.hint",
                                              defaultValue: "Opens this volume in the browser"))
                }
            } header: {
                Text(String(localized: "browser.sources.crossVolume.sheet.header",
                            defaultValue: "Volumes Citing This Collection"))
            } footer: {
                Text(collectionTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Navigates to the tapped volume (Browse tab on iOS; the Corpus Browser window on
    /// macOS, via the `pendingBrowseVolume` hand-off both consume).
    private func open(_ volumeId: String) {
        appState.pendingBrowseVolume = volumeId
        #if os(macOS)
        openWindow(id: "frus.corpusBrowser")
        bringMacWindowToFront(id: "frus.corpusBrowser")
        #else
        appState.activeTab = .browse
        #endif
        onNavigate?()
    }
}

// MARK: - VolumeSourcesCrossVolumeSheet

/// Lists the volumes whose front-matter Sources sections cite a given archival collection —
/// the cross-volume provenance folded by the `VolumeSourcesIndexGenerator`. It answers
/// "which other FRUS volumes drew on this same collection?" for a researcher tracing
/// a body of records across the series; each row opens its volume in the browser.
///
/// Version history:
///   1.0 — Session 2026-07-03 (Source Explorer Phase 3/4 work): read-only volume list
///   1.1 — Session 2026-07-04 (macOS UI audit B2/gap 12): list core extracted into the
///          shared `CrossVolumeProvenanceContent` and rows became navigable
///          (dismiss-and-navigate, like the Archival Neighbors sheet). On macOS every
///          surface now opens the `CrossVolumeProvenanceRequest` window instead of
///          this sheet, so the sheet is presented by the iOS surfaces only.
struct VolumeSourcesCrossVolumeSheet: View {

    /// The collection's display text, shown as context.
    let collectionTitle: String
    /// The citing volumes, sorted (as stored in the authority).
    let volumeIds: [String]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            CrossVolumeProvenanceContent(
                collectionTitle: collectionTitle,
                volumeIds: volumeIds,
                onNavigate: { dismiss() }
            )
            .navigationTitle(String(localized: "browser.sources.crossVolume.sheet.title",
                                    defaultValue: "Cross-Volume Provenance"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done", defaultValue: "Done")) { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 420)
        #endif
    }
}

#if os(macOS)

// MARK: - CrossVolumeProvenanceWindowView

/// Content for the macOS **Cross-Volume Provenance window** (UI audit B2): the shared
/// `CrossVolumeProvenanceContent` under window chrome — the title names the surface,
/// the subtitle names the collection.
///
/// A window, not a sheet, because the list is read *alongside* the volumes it names:
/// a researcher tracing a body of records across the series steps through the citing
/// volumes one by one, and a sheet died on its Done button with no way to keep the
/// list in view. Here a row tap hands the volume to the Corpus Browser window
/// (`pendingBrowseVolume`) and this window **stays open** beside it.
///
/// Version history:
///   1.0 — Session 2026-07-04 (macOS UI audit B2): initial implementation
struct CrossVolumeProvenanceWindowView: View {

    /// The restorable listing description this window presents.
    let request: CrossVolumeProvenanceRequest

    var body: some View {
        CrossVolumeProvenanceContent(
            collectionTitle: request.title,
            volumeIds: request.volumeIds,
            onNavigate: nil   // the window stays open — that is the point of B2
        )
        .navigationTitle(String(localized: "browser.sources.crossVolume.sheet.title",
                                defaultValue: "Cross-Volume Provenance"))
        .navigationSubtitle(request.title)
        .frame(minWidth: 400, minHeight: 420)
    }
}

#endif // os(macOS)
