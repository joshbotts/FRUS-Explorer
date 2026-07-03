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
///          a testable static); bibliography (`listofworks`) rows render as plain rows
///          in their own section, excluded by construction from every neighbor/catalog
///          affordance.
struct VolumeSourcesView: View {

    /// The volume whose sources list is being shown.
    let volumeId: String

    @Environment(AppState.self) private var appState

    @State private var sources: [VolumeSourceEntry] = []
    @State private var isLoading = true
    /// Guards `loadSources()` against duplicate runs. The body is a `Group` emitting list
    /// sections, and SwiftUI applies `Group` modifiers to each child — so `.task` fires
    /// again for every section that appears when the loading branch swaps to the loaded
    /// one. Without the guard each re-run rebuilt `collectionTree` with fresh node UUIDs,
    /// collapsing the outline's disclosure state.
    @State private var didLoad = false
    /// When set by a row's button, the PARENT presents the Archival Neighbors sheet.
    ///
    /// Presentation state is deliberately hoisted to the embedding view: this view emits
    /// list sections, and modifiers attached to `Group`/`Section` inside `List` content
    /// are applied per child/row — several presenters sharing one item binding ping-pong
    /// present/dismiss after close (the twice-reported Archival Neighbors open/close
    /// loop). The `.sheet(item:)` must anchor exactly once, on the parent's `List`.
    @Binding var sourceNeighborsTarget: VolumeSourceNeighborsTarget?
    /// When set by a row's button, the PARENT presents the cross-volume provenance sheet
    /// (see `sourceNeighborsTarget` for why presentation is hoisted).
    @Binding var crossVolumeTarget: CrossVolumeTarget?

    /// The narrative "Note on Sources" paragraphs, shown as flowing prose.
    private var proseEntries: [VolumeSourceEntry] { sources.filter { $0.kind == .prose } }

    /// Published-works bibliography rows (`listofworks`), shown as plain rows —
    /// deliberately without neighbor or catalog affordances (they cite books, not
    /// archival collections; audit §2.3 counted 2,634 masquerading as resolvable).
    private var bibliographyEntries: [VolumeSourceEntry] { sources.filter { $0.kind == .bibliography } }

    /// The archival-collection outline, built **once** in `loadSources`. It must be stored
    /// (not recomputed per render): `SourceTreeNode` ids are `UUID`s, so rebuilding the tree
    /// on each body evaluation would hand `OutlineGroup` fresh identities and collapse the
    /// user's expanded disclosure state on any re-render (e.g. opening the neighbors sheet).
    @State private var collectionTree: [SourceTreeNode] = []

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
    }

    /// One archival-collection outline row: its own text (bold for a major named collection —
    /// a `<hi rend="strong">` heading), a link to the resolved NARA Catalog record where the
    /// collection resolved, an Archival Neighbors affordance where the node carries a
    /// resolvable match key (lot file, or record group + series), and — for a major
    /// collection cited by more than one volume — a cross-volume provenance affordance.
    private func sourceNodeRow(_ entry: VolumeSourceEntry) -> some View {
        // O(1) lookups into the bundled resolution index (decoded once, warmed off-main).
        let resolution = VolumeSourcesIndexStore.shared?.resolution(
            recordGroup: entry.recordGroup, lotFile: entry.lotFile)
        let crossVolume: MajorCollectionRecord? = entry.isHeading
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
                if let target = Self.makeNeighborsTarget(for: entry) {
                    Button {
                        sourceNeighborsTarget = target
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
            if let crossVolume, crossVolume.volumeIds.count > 1 {
                Button {
                    crossVolumeTarget = CrossVolumeTarget(
                        title: entry.rawText, volumeIds: crossVolume.volumeIds)
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
    nonisolated static func makeNeighborsTarget(for entry: VolumeSourceEntry) -> VolumeSourceNeighborsTarget? {
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
            decimalClass: cls
        )
    }

    // MARK: - Data Loading

    private func loadSources() async {
        guard !didLoad else { return }
        didLoad = true
        // Warm the bundled resolution index (one ~1 MB decode) off the main thread so the
        // per-row catalog / cross-volume lookups in `sourceNodeRow` never block rendering.
        await Task.detached(priority: .utility) { _ = VolumeSourcesIndexStore.shared }.value
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

// MARK: - VolumeSourcesCrossVolumeSheet

/// Lists the volumes whose front-matter Sources sections cite a given archival collection —
/// the cross-volume provenance folded by the `VolumeSourcesIndexGenerator`. Read-only: it
/// answers "which other FRUS volumes drew on this same collection?" for a researcher tracing
/// a body of records across the series.
struct VolumeSourcesCrossVolumeSheet: View {

    /// The collection's display text, shown as context.
    let collectionTitle: String
    /// The citing volumes, sorted (as stored in the authority).
    let volumeIds: [String]

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(volumeIds, id: \.self) { volumeId in
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
                    Text(String(localized: "browser.sources.crossVolume.sheet.header",
                                defaultValue: "Volumes Citing This Collection"))
                } footer: {
                    Text(collectionTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
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
