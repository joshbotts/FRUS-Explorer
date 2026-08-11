// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import Charts

// MARK: - ArchivalAnalyticsView

/// Where the FRUS editors found what they published — the Archival Analytics surface (#765),
/// joining Corpus, Person, Cross-Reference, and Word Cloud in the Analytics family.
///
/// Four modes. **Collections** ranks the archival units each era's volumes drew on, corpus-wide,
/// from the bundled authority and usage index. **Network** draws the co-citation neighbourhood of
/// one collection in custodian sectors. **Flows** maps where the editors sent the reader when they
/// cross-referenced one document from another. **Your Library** counts the same things in the
/// volumes this reader has actually indexed.
///
/// Network owns its own gestures and so bypasses the shell's `ScrollView`; see
/// ``ArchivalAnalyticsMode/isFullFrameCanvas``.
///
/// `AppState` is read as an **optional** environment value, the defensive pattern every
/// analytics surface here follows: an absent environment degrades to an empty state instead of
/// trapping.
///
/// Version history:
///   1.0 — Session 2026-08-09: #765 stage 1 (Collections + Your Library)
///   1.1 — Session 2026-08-09: #765 stage 2 adds Network and Flows
///   1.2 — Session 2026-08-10: #832(c) removes the lifecycle card; the mode ends with a
///          pointer to where one collection's own timing lives
///   1.3 — Session 2026-08-10: #826 adds the denominator line above the ranking and the
///          "Inside these families" leaf list below it
///   1.4 — Session 2026-08-10: #825(a, c) — ranking rows open a destination, and the row cap
///          gains a way out through the uncapped all-units table
struct ArchivalAnalyticsView: View {

    /// Optional so a missing environment yields an empty state rather than a trap.
    @Environment(AppState.self) private var appState: AppState?
    @Environment(\.dismiss) private var dismiss
    /// The hosting scene, so hand-offs target this window (#338).
    @Environment(\.sceneID) private var sceneID
    @Environment(\.openWindow) private var openWindow
    #if os(iOS)
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows
    #endif

    /// The active mode.
    @State private var mode: ArchivalAnalyticsMode = .collections

    /// The era band the Collections ranking covers.
    ///
    /// Opens on 1948–1960: the first band in which named collections and central-file classes
    /// are both well populated, so the unit switch means something on the first screen. The
    /// earlier band is dominated by classes and the later ones by libraries.
    @State private var band: ArchivalEraBand = ArchivalEraBand.all[1]

    /// Named collections or central-file classes. Persisted — it is a way of working, not a
    /// per-visit selection.
    @AppStorage("frus.archivalAnalytics.unitLens")
    private var unitLensRaw: String = ArchivalUnitLens.namedCollections.rawValue
    /// Documents or volumes. Persisted for the same reason.
    @AppStorage("frus.archivalAnalytics.weight")
    private var weightRaw: String = ArchivalWeight.documents.rawValue

    /// Whether the `Central Files` umbrella is filtered out. Per-visit, like every other
    /// narrowing in the analytics family.
    @State private var hidesUmbrella = true

    /// The corpus-wide derivation, `nil` until the first load finishes.
    @State private var collectionsData: ArchivalCollectionsData?
    /// The local profile, `nil` until the first load finishes.
    @State private var libraryProfile: ArchivalLibraryProfile?
    /// Whether the library query has been kicked off, so re-entering the mode does not re-run
    /// it on every appearance.
    @State private var hasLoadedLibrary = false

    /// The chart whose data the table inspector is showing.
    @State private var inspectorData: ChartInspectorData?
    /// The collection record to present, set when a ranking row is opened (#825a).
    @State private var collectionDetail: AuthorityCollectionRecord?
    /// Whether the uncapped "every unit in this era" table is up (#825c).
    @State private var showsAllUnits = false
    /// The file waiting to be shared (iOS) after an export.
    @State private var exportShareItem: AnalyticsExportFile?
    /// An export failure, surfaced rather than swallowed.
    @State private var exportError: String?
    #if os(iOS)
    /// The iPhone fallback target for Archival Neighbors, where there are no extra windows.
    @State private var neighborsTarget: ArchivalLibraryNeighborsTarget?
    /// The same fallback for a class-keyed neighbours query.
    @State private var classNeighborsTarget: ArchivalClassNeighborsTarget?
    #endif

    private var unitLens: ArchivalUnitLens {
        ArchivalUnitLens(rawValue: unitLensRaw) ?? .namedCollections
    }

    /// The weight actually in force.
    ///
    /// Falls back to volumes when the usage index did not load, because the stored preference
    /// outlives the artifact: a reader who last chose Documents would otherwise open onto an
    /// empty chart with no indication that the weight, not the era, was the reason. The caveat
    /// block says which fallback happened.
    private var weight: ArchivalWeight {
        let stored = ArchivalWeight(rawValue: weightRaw) ?? .documents
        guard stored == .documents else { return stored }
        return (collectionsData?.supportsDocumentWeight ?? true) ? .documents : .volumes
    }

    /// Re-runs the library query when the mode changes **or** the search infrastructure finishes
    /// booting. Without the second half, a view that appeared before `indexingPipeline` existed
    /// would show an empty library for the rest of the session — the macOS window and the iOS
    /// sheet can both open mid-boot.
    private var libraryLoadToken: String {
        "\(mode.rawValue)|\(appState?.indexingPipeline == nil ? "waiting" : "ready")"
    }

    var body: some View {
        NavigationStack {
            Group {
                // Network owns its own pinch and pan. Nesting it in the shell's ScrollView would
                // put two gesture recognisers on the same drag, so the full-frame modes bypass
                // the scroll container entirely rather than fighting it.
                if mode.isFullFrameCanvas {
                    networkMode
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            switch mode {
                            case .collections: collectionsMode
                            case .flows: flowsMode
                            case .yourLibrary: yourLibraryMode
                            case .network: EmptyView()   // handled above
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            #if os(macOS)
            .navigationTitle(String(localized: "archival.title", defaultValue: "Archival Analytics"))
            #else
            .accessibilityElement(children: .contain)
            .accessibilityLabel(String(localized: "archival.title", defaultValue: "Archival Analytics"))
            #endif
            .toolbar { toolbarContent }
        }
        #if os(macOS)
        .frame(minWidth: 720, minHeight: 580)
        #endif
        .sheet(item: $inspectorData) { ChartDataInspectorView(data: $0) }
        .sheet(item: $collectionDetail) { record in
            CollectionDetailSheet(record: record)
                .environment(appState)
                .environment(\.sceneID, sceneID ?? .anyWindow)
        }
        .sheet(isPresented: $showsAllUnits) {
            if let data = collectionsData {
                ArchivalAllUnitsSheet(
                    band: band, lens: unitLens, weight: weight, hidingUmbrella: hidesUmbrella,
                    data: data, indexedVolumeCount: appState?.indexedVolumeIds.count ?? 0,
                    onOpen: { row in
                        showsAllUnits = false
                        open(row, data: data)
                    },
                    canOpen: { canOpen($0, data: data) })
            }
        }
        // D3 (#787): anchored on the outermost view, not on a `Group` child — see the
        // Group-modifier gotcha, which applies the presentation once per child.
        .sheet(item: $exportShareItem) { AnalyticsExportShareSheet(item: $0) }
        .alert(String(localized: "analytics.export.error.title", defaultValue: "Export Failed"),
               isPresented: Binding(get: { exportError != nil },
                                    set: { if !$0 { exportError = nil } })) {
            Button(String(localized: "common.ok", defaultValue: "OK")) { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
        #if os(iOS)
        .sheet(item: $neighborsTarget) { target in
            if let appState {
                ArchivalNeighborsSheet(appState: appState) { scopeVolumeIds in
                    await loadNeighbors(for: target.record, scopeVolumeIds: scopeVolumeIds)
                }
                .environment(appState)
                .environment(\.sceneID, sceneID ?? .anyWindow)
            }
        }
        .sheet(item: $classNeighborsTarget) { target in
            if let appState {
                ArchivalNeighborsSheet(appState: appState) { scopeVolumeIds in
                    guard let pipeline = appState.indexingPipeline else { return ([], 0, nil) }
                    return (try? await pipeline.archivalNeighbors(
                        forLotFile: nil, recordGroup: nil, series: nil, repository: nil,
                        decimalClass: target.classKey,
                        scopeVolumeIds: scopeVolumeIds)) ?? ([], 0, nil)
                }
                .environment(appState)
                .environment(\.sceneID, sceneID ?? .anyWindow)
            }
        }
        #endif
        .task { await loadCollections() }
        .task(id: libraryLoadToken) { await loadLibraryIfNeeded() }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Picker(String(localized: "archival.mode.picker", defaultValue: "Mode"),
                   selection: $mode) {
                ForEach(ArchivalAnalyticsMode.allCases) { m in
                    Text(m.title).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .help(String(localized: "archival.mode.help.v2",
                         defaultValue: "Switch between the era rankings, the co-citation network, the reference hand-off diagram, and the archival profile of your own indexed volumes."))
        }
        ToolbarItem(placement: .primaryAction) {
            FeatureInfoButton.archivalAnalytics
        }
        #if os(iOS)
        ToolbarItem(placement: .confirmationAction) {
            Button(String(localized: "archival.done", defaultValue: "Done")) { dismiss() }
        }
        #endif
    }

    // MARK: - Network mode

    @ViewBuilder
    private var networkMode: some View {
        if let collections = CollectionAuthorityStore.shared?.collections, !collections.isEmpty {
            ArchivalNetworkView(
                collections: collections,
                indexedVolumeCount: appState?.indexedVolumeIds.count ?? 0,
                usage: CollectionUsageIndexStore.shared,
                onOpenNeighbors: { openNeighbors(for: $0) },
                onOpenClassNeighbors: { openClassNeighbors($0) },
                onExport: { deliver($0) })
        } else {
            unavailableState(String(localized: "archival.network.unavailable",
                                    defaultValue: "The bundled collection authority is unavailable in this build, so the network cannot be drawn."))
        }
    }

    // MARK: - Flows mode

    @ViewBuilder
    private var flowsMode: some View {
        if let index = ProvenanceFlowIndexStore.shared,
           let authority = CollectionAuthorityStore.shared {
            ArchivalFlowsView(index: index,
                              externalIndex: ExternalCitationIndexStore.shared,
                              entriesById: manifestEntriesById,
                              authority: authority,
                              onOpenNeighbors: { openNeighbors(for: $0) },
                              indexedVolumeCount: appState?.indexedVolumeIds.count ?? 0,
                              onExport: { deliver($0) })
        } else {
            unavailableState(String(localized: "archival.flows.unavailable",
                                    defaultValue: "The bundled reference-flow index is unavailable in this build, so hand-offs cannot be shown. This is not the same as the series having none."))
        }
    }

    /// A missing bundled artifact reads as "unavailable", never as "there is nothing here".
    private func unavailableState(_ message: String) -> some View {
        ContentUnavailableView(
            String(localized: "archival.unavailable.title", defaultValue: "Data Unavailable"),
            systemImage: "exclamationmark.triangle",
            description: Text(message)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Collections mode

    @ViewBuilder
    private var collectionsMode: some View {
        if let data = collectionsData {
            let ranking = data.ranking(band: band, lens: unitLens, weight: weight,
                                       hidingUmbrella: hidesUmbrella)
            collectionsIntro
            filterRow(data: data)
            denominatorLine(ranking, data: data)
            rankingCard(ranking, data: data)
            showAllUnitsButton(ranking)
            classFamilies(ranking)
            collectionsCaveats(data: data, ranking: ranking)
            perCollectionTimingPointer
        } else {
            loadingState(String(localized: "archival.collections.loading",
                                defaultValue: "Reading the archival authority…"))
        }
    }

    private var collectionsIntro: some View {
        Text(String(localized: "archival.collections.intro",
                    defaultValue: "Every published FRUS document carries a source note naming the archival file it came from. Grouped across the whole series, those notes show which bodies of records each era's editors actually worked in. They also track how the documentary base of American foreign relations moved from the State Department's filing rooms to the White House."))
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The era / units / weight controls, wrapped so they stack on a narrow window.
    private func filterRow(data: ArchivalCollectionsData) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { filterChips(data: data); Spacer(minLength: 0) }
            VStack(alignment: .leading, spacing: 8) { filterChips(data: data) }
        }
    }

    @ViewBuilder
    private func filterChips(data: ArchivalCollectionsData) -> some View {
        Menu {
            Picker(String(localized: "archival.filter.era", defaultValue: "Coverage era"),
                   selection: $band) {
                ForEach(ArchivalEraBand.all) { b in Text(b.title).tag(b) }
            }
        } label: {
            chipLabel(systemImage: "calendar",
                      caption: String(localized: "archival.filter.era", defaultValue: "Coverage era"),
                      value: band.title)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)

        Menu {
            Picker(String(localized: "archival.filter.units", defaultValue: "Units"),
                   selection: $unitLensRaw) {
                ForEach(ArchivalUnitLens.allCases) { lens in
                    Text(lens.title).tag(lens.rawValue)
                }
            }
        } label: {
            chipLabel(systemImage: "archivebox",
                      caption: String(localized: "archival.filter.units", defaultValue: "Units"),
                      value: unitLens.title)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)

        Menu {
            Picker(String(localized: "archival.filter.weight", defaultValue: "Weight"),
                   selection: $weightRaw) {
                ForEach(ArchivalWeight.allCases) { w in
                    Text(w.title).tag(w.rawValue)
                }
            }
            // Documents needs the usage index. The picker dims whole rather than per-option,
            // because a stored Documents preference has already been overridden by `weight` —
            // an enabled control whose selection the view ignores is worse than a disabled one.
            .disabled(!data.supportsDocumentWeight)
        } label: {
            chipLabel(systemImage: "doc.on.doc",
                      caption: String(localized: "archival.filter.weight", defaultValue: "Weight"),
                      value: weight.title)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)

        if unitLens == .namedCollections {
            Button {
                hidesUmbrella.toggle()
            } label: {
                chipLabel(systemImage: hidesUmbrella ? "eye.slash" : "eye",
                          caption: String(localized: "archival.filter.umbrella",
                                          defaultValue: "Central Files umbrella"),
                          value: hidesUmbrella
                              ? String(localized: "archival.filter.umbrella.hidden", defaultValue: "Hidden")
                              : String(localized: "archival.filter.umbrella.shown", defaultValue: "Shown"),
                          showsChevron: false)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel(String(localized: "archival.filter.umbrella.a11y",
                                       defaultValue: "Central Files umbrella record"))
            .accessibilityValue(hidesUmbrella
                                ? String(localized: "archival.filter.umbrella.hidden", defaultValue: "Hidden")
                                : String(localized: "archival.filter.umbrella.shown", defaultValue: "Shown"))
        }
    }

    /// The Wave-B chip label: icon, caption, value, chevron.
    private func chipLabel(systemImage: String, caption: String, value: String,
                           showsChevron: Bool = true) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage).font(.caption2)
            Text(caption).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.caption.weight(.medium))
            if showsChevron {
                Image(systemName: "chevron.down").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - The denominator line (#826/R-5)

    /// What the drawn rows account for, against the band's own source-note total.
    ///
    /// The shipped artifact has carried `volumeNoteCounts` since #763 — described in its own
    /// generator notes as "the per-volume source-note totals every share needs as a denominator"
    /// — and nothing read it. Without it the mode opens on 1948–1960 drawing twelve bars that
    /// account for **9.4%** of the band's sourced documents, with nothing on screen saying so.
    /// The era asymmetry the caveat block describes in prose is, stated this way, the finding.
    ///
    /// The share is withheld rather than approximated under the volumes weight: the numerator
    /// would be volumes and the denominator notes.
    @ViewBuilder
    private func denominatorLine(_ ranking: ArchivalRanking,
                                 data: ArchivalCollectionsData) -> some View {
        if let notes = data.noteCount(band: band) {
            VStack(alignment: .leading, spacing: 2) {
                Text(denominatorSentence(ranking, notes: notes))
                    .font(.footnote.weight(.medium))
                if let pointer = denominatorPointer(data: data) {
                    Text(pointer).font(.footnote)
                }
            }
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// "N source notes in this era. The M rows below account for X% of them."
    private func denominatorSentence(_ ranking: ArchivalRanking, notes: Int) -> String {
        guard let share = ranking.shownShare(weight: weight) else {
            return String(format: String(
                localized: "archival.denominator.notes %lld %@",
                defaultValue: "%1$lld source notes in %2$@."), Int64(notes), band.title)
        }
        return String(format: String(
            localized: "archival.denominator.share %lld %@ %lld %@",
            defaultValue: "%1$lld source notes in %2$@. The %3$lld rows below account for %4$@ of them."),
            Int64(notes), band.title, Int64(ranking.rows.count), Self.shareText(share))
    }

    /// A share, never rounded to a number that reads as nothing.
    ///
    /// `fractionLength` has a *minimum* of zero, so a plain percent style renders the class
    /// lens's 1977–1992 share — 3 documents in 12,609 notes — as "0%", which states that the
    /// rows below account for none of the era while three bars sit under it. Anything below a
    /// percent says so in words instead.
    static func shareText(_ share: Double) -> String {
        guard share >= 0.01 else {
            return String(localized: "archival.denominator.underOnePercent",
                          defaultValue: "under 1%")
        }
        return share.formatted(.percent.precision(.fractionLength(share < 0.1 ? 1 : 0)))
    }

    /// The one comparison the collection/class overlap does not spoil: whether the *other* lens
    /// reaches materially more of this band, which in the early eras it does by an order of
    /// magnitude and is the whole reason the unit switch exists.
    private func denominatorPointer(data: ArchivalCollectionsData) -> String? {
        let other: ArchivalUnitLens = unitLens == .namedCollections ? .centralFileClasses
                                                                    : .namedCollections
        let mine = data.reach(band: band, lens: unitLens)
        let theirs = data.reach(band: band, lens: other)
        guard theirs > mine * 2 else { return nil }
        switch other {
        case .centralFileClasses:
            return String(localized: "archival.denominator.tryClasses",
                          defaultValue: "Most of this era's sourcing names a central-file number rather than a named collection — switch the unit to File numbers to rank those.")
        case .namedCollections:
            return String(localized: "archival.denominator.tryCollections",
                          defaultValue: "Most of this era's sourcing names a collection rather than a central-file number — switch the unit to Collections to rank those.")
        }
    }

    // MARK: - Every unit (#825c)

    /// The way out of the row cap.
    ///
    /// The chart draws twelve bars and the caption has always counted the units reached in the
    /// hundreds, but until now those rows existed nowhere the reader could get at them: the
    /// table inspector and the CSV both carried the capped twelve, so the full list was
    /// unobtainable in the app *and* out of it. Withheld when nothing is capped.
    @ViewBuilder
    private func showAllUnitsButton(_ ranking: ArchivalRanking) -> some View {
        if ranking.unitsReached > ranking.rows.count {
            Button {
                showsAllUnits = true
            } label: {
                Label(String(format: String(
                    localized: "archival.allUnits.button %lld",
                    defaultValue: "Show all %lld units in this era"),
                    Int64(ranking.unitsReached)), systemImage: "tablecells")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: - Opening a row (#825a)

    /// Where a ranking row goes when it is opened.
    ///
    /// The two lenses rank different kinds of thing and so have different destinations, which is
    /// the whole reason this is one function rather than a tap handler per surface:
    ///
    /// - A **collection** is a body of records, so it opens its authority record — the one screen
    ///   holding the NARA catalog link, the aliases, the citing volumes and Divided at NARA. A row
    ///   whose id the authority does not carry simply does not open (see
    ///   ``ArchivalCollectionsData/record(forId:)``); it has no record to show, and inventing a
    ///   destination would be worse than the dead end this issue is closing.
    /// - A **class** is a subject heading inside a filing system, not a body of records. There is
    ///   nothing to open, so it routes to the class-keyed Archival Neighbors — the documents
    ///   themselves.
    private func open(_ row: ArchivalRankingRow, data: ArchivalCollectionsData) {
        switch unitLens {
        case .namedCollections:
            guard let record = data.record(forId: row.id) else { return }
            collectionDetail = record
        case .centralFileClasses:
            openClassNeighbors(row.id)
        }
    }

    /// Whether a row has somewhere to go, so a list can withhold the affordance rather than
    /// offering a control that does nothing.
    private func canOpen(_ row: ArchivalRankingRow, data: ArchivalCollectionsData) -> Bool {
        unitLens == .centralFileClasses || data.record(forId: row.id) != nil
    }

    // MARK: - Class families (#826/R-4)

    /// The way back from a folded family to the leaf a pull slip actually names.
    ///
    /// The fold is what makes the class lens rankable — at leaf grain half the subject-numeric
    /// keys carry a single document — but `POL 27 VIET S` is what a researcher writes at NARA,
    /// and `POL 27` is not. So every folded row can be opened to its leaves with their own
    /// counts. Rows that fold nothing (every decimal file number, and a family with one leaf
    /// under its own name) are omitted rather than listed as empty disclosures.
    ///
    /// A list below the chart rather than expansion inside it: the ranking is a Swift Charts
    /// `Chart` whose categorical axis is one row per bar, and inserting leaf rows into it would
    /// redraw the bars at a grain the axis does not describe.
    /// The families list's caption, which has to change with the weight because the arithmetic
    /// does: document counts add up to the bar, distinct-volume counts do not.
    private var familiesCaption: String {
        weight == .documents
            ? String(localized: "archival.families.caption.documents",
                     defaultValue: "Related file numbers are ranked together. Open one for the exact designator a pull slip needs; its parts add up to the bar above.")
            : String(localized: "archival.families.caption.volumes",
                     defaultValue: "Related file numbers are ranked together. Open one for the exact designator a pull slip needs. Each line counts the volumes citing that designator, so they overlap and do not add up to the bar: a volume citing two of them counts once for the group.")
    }

    @ViewBuilder
    private func classFamilies(_ ranking: ArchivalRanking) -> some View {
        let families = ranking.rows.filter(\.isFamily)
        if unitLens == .centralFileClasses, !families.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "archival.families.title",
                            defaultValue: "Inside these families"))
                    .font(.subheadline.weight(.semibold))
                Text(familiesCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(families) { family in
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 4) {
                            // Ordered by the weight on screen. The stored order is by documents,
                            // which under Count-by = Volumes draws a visibly non-monotonic
                            // column — measured on POL 27, 5 of 20 adjacent pairs inverted.
                            ForEach(family.leaves.sorted {
                                $0.value(weight: weight) != $1.value(weight: weight)
                                    ? $0.value(weight: weight) > $1.value(weight: weight)
                                    : $0.key < $1.key
                            }) { leaf in
                                HStack(alignment: .firstTextBaseline) {
                                    Text(leaf.key)
                                        .font(.caption.monospaced())
                                    Spacer(minLength: 12)
                                    // The weight's own unit. Under Documents the leaves sum to
                                    // the bar; under Volumes they do NOT, and must not be added:
                                    // each leaf counts its own distinct volumes while the bar
                                    // counts their union, so a volume citing two designators is
                                    // one bar-volume and two leaf-volumes. The caption says so.
                                    Text(leaf.value(weight: weight), format: .number)
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                        .padding(.top, 2)
                    } label: {
                        HStack(alignment: .firstTextBaseline) {
                            Text(family.name).font(.callout)
                            Spacer(minLength: 12)
                            Text(String(format: String(
                                localized: "archival.families.count %lld",
                                defaultValue: "%lld in family"), Int64(family.leaves.count)))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - The ranking card

    @ViewBuilder
    private func rankingCard(_ ranking: ArchivalRanking, data: ArchivalCollectionsData) -> some View {
        let title = rankingTitle
        let table = rankingInspector(ranking, title: title)
        let provenance = ArchivalAnalyticsExport.ranking(
            band: band, lens: unitLens, weight: weight,
            hiddenUmbrella: ranking.hiddenUmbrellaValue, unitsReached: ranking.unitsReached,
            bandVolumeCount: ranking.bandVolumeCount,
            indexedVolumeCount: appState?.indexedVolumeIds.count ?? 0,
            noteCount: ranking.bandNoteCount, shownValue: ranking.shownValue)
        SeriesChartCard(
            title: title,
            caption: rankingCaption(ranking),
            inspector: table,
            onInspect: { inspectorData = $0 },
            controls: {
                exportControl(table: table, provenance: provenance) { format in
                    deliverFigure(format, provenance: provenance,
                                  chartHeight: CGFloat(ranking.rows.count) * 26 + 60) {
                        rankingChart(ranking)
                    }
                }
            }
        ) {
            if ranking.rows.isEmpty {
                Text(String(localized: "archival.ranking.empty",
                            defaultValue: "No archival units resolved in this era under the current unit and weight."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 12)
            } else {
                interactiveRankingChart(ranking, data: data)
                    .frame(height: CGFloat(ranking.rows.count) * 26 + 60)
            }
        }
    }

    /// The ranking chart itself, separated from its card so the figure exporter can render it.
    ///
    /// `AnalyticsFigureCanvas` renders detached from the view hierarchy and inherits no
    /// environment, so everything this reads — the weight's title, the category colours, the row
    /// labels — must already be resolved by the time it is called. All of it is.
    /// The ranking chart with its tap-through, for the screen only.
    ///
    /// Interaction is added here rather than inside ``rankingChart(_:)`` because that body is
    /// also what the figure exporter rasterises, and a hit-test overlay in a PNG is dead weight
    /// — the same split Person Analytics draws between its screen chart and its export.
    private func interactiveRankingChart(_ ranking: ArchivalRanking,
                                         data: ArchivalCollectionsData) -> some View {
        rankingChart(ranking)
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            guard let anchor = proxy.plotFrame else { return }
                            let plot = geo[anchor]
                            // The Y axis is categorical on `label`, which `disambiguate` has
                            // already made unique within the ranking — so the label round-trips
                            // to exactly one row.
                            guard let label = proxy.value(atY: location.y - plot.origin.y,
                                                          as: String.self),
                                  let row = ranking.rows.first(where: { $0.label == label })
                            else { return }
                            open(row, data: data)
                        }
                }
            }
    }

    @ViewBuilder
    private func rankingChart(_ ranking: ArchivalRanking) -> some View {
        Chart {
            ForEach(ranking.rows) { row in
                BarMark(
                    x: .value(weight.title, row.value),
                    y: .value(String(localized: "archival.ranking.y",
                                     defaultValue: "Archival unit"), row.label)
                )
                .foregroundStyle(by: .value(
                    String(localized: "archival.ranking.legend", defaultValue: "Custodian"),
                    row.category.displayName))
                .annotation(position: .trailing, alignment: .leading) {
                    Text(row.value, format: .number)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel(Text(row.label))
                .accessibilityValue(Text(accessibilityValue(for: row)))
            }
        }
        .chartForegroundStyleScale(
            domain: ArchivalRepositoryCategory.ordered.map(\.displayName),
            range: ArchivalRepositoryCategory.ordered.map(\.color))
        .chartYAxis {
            AxisMarks(preset: .extended, position: .leading) { _ in
                AxisValueLabel(horizontalSpacing: 8)
            }
        }
        .chartXAxisLabel(weight.title)
    }

    /// The ranking card's title, which follows the unit lens — the two lenses rank different
    /// kinds of thing and one title for both would be wrong on one of them.
    private var rankingTitle: String {
        unitLens == .namedCollections
            ? String(localized: "archival.ranking.title.collections",
                     defaultValue: "Top collections by era")
            : String(localized: "archival.ranking.title.classes",
                     defaultValue: "Top central-file classes by era")
    }

    private func rankingCaption(_ ranking: ArchivalRanking) -> String {
        let units = unitLens == .namedCollections
            ? String(localized: "archival.ranking.caption.units.collections",
                     defaultValue: "collections")
            : String(localized: "archival.ranking.caption.units.classes", defaultValue: "classes")
        return String(format: String(
            localized: "archival.ranking.caption %@ %lld %@ %lld",
            defaultValue: "Volumes covering %1$@ — %2$lld of them — draw on %3$lld %4$@. Bars are coloured by who holds the records."),
            band.title, Int64(ranking.bandVolumeCount), Int64(ranking.unitsReached), units)
    }

    private func accessibilityValue(for row: ArchivalRankingRow) -> String {
        String(format: String(localized: "archival.ranking.a11y %lld %@ %@",
                              defaultValue: "%1$lld %2$@, %3$@"),
               Int64(row.value), weight.title.lowercased(), row.category.displayName)
    }

    private func rankingInspector(_ ranking: ArchivalRanking, title: String)
        -> ChartInspectorData? {
        guard !ranking.rows.isEmpty else { return nil }
        return ChartInspectorData(
            id: "archival.ranking",
            title: title,
            columns: [
                String(localized: "archival.table.unit", defaultValue: "Archival unit"),
                String(localized: "archival.table.custodian", defaultValue: "Custodian"),
                weight.title,
            ],
            rowCells: ranking.rows.map { [$0.label, $0.category.displayName, "\($0.value)"] })
    }

    /// The per-card export control, in `SeriesChartCard`'s controls slot.
    ///
    /// Per-card rather than one control for the view, because this surface shows several charts
    /// at once and a single control would be ambiguous about which it acts on — the same reason
    /// Person and Cross-Reference Analytics put theirs per section.
    @ViewBuilder
    private func exportControl(table: ChartInspectorData?, provenance: AnalyticsProvenance,
                               onFigure: ((AnalyticsFigureFormat) -> Void)? = nil) -> some View {
        HStack {
            Spacer()
            AnalyticsSectionExportControl(
                isEnabled: !(table?.rows.isEmpty ?? true),
                exportCSV: { if let table { deliver(table, provenance) } },
                exportFigure: onFigure)
        }
    }

    // MARK: - Collections caveats

    /// Where a *single* collection's timing lives, now that the corpus-wide lifecycle card is gone.
    ///
    /// The card this replaces ranked collections by citing volumes and drew each one's first-to-last
    /// coverage span. Two things made it an accident of derivation order rather than a finding: it
    /// ignored the umbrella chip, so `Central Files` topped it whatever the reader had chosen, and
    /// repository-grain records ranked beside collections. The same question — when did this body of
    /// records enter the published series, and how long did the editors keep returning to it — is
    /// answered per collection, and correctly, by `CollectionDetailView`'s Cited Over Time chart.
    private var perCollectionTimingPointer: some View {
        Label {
            Text(String(localized: "archival.collections.timingPointer",
                        defaultValue: "When one collection entered the published record, and how long the editors kept returning to it, is on that collection's own record, under Cited Over Time."))
        } icon: {
            Image(systemName: "info.circle")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func collectionsCaveats(data: ArchivalCollectionsData,
                                    ranking: ArchivalRanking) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "archival.caveats.title", defaultValue: "About these figures"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            if let hidden = ranking.hiddenUmbrellaValue {
                Text(String(format: String(
                    localized: "archival.caveats.umbrella %lld %@ %@",
                    defaultValue: "The Central Files umbrella record is hidden here. On its own it accounts for %1$lld %2$@ in the %3$@ volumes, and its bar would flatten the scale. The era-specific Central Files records are still shown."),
                    Int64(hidden), weight.title.lowercased(), band.title))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !data.supportsDocumentWeight {
                Text(String(localized: "archival.caveats.noUsageIndex",
                            defaultValue: "Document counts are unavailable in this build — the bundled usage index did not load — so only the volume weight is offered."))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(String(localized: "archival.caveats.body",
                        defaultValue: "These figures are parsed from document source notes, not read from an archive's catalog. They say where the editors drew documents from. That is an editorial and archival signal, not a census of the records themselves. The two weights count different things. A document counts only when its own source note names the collection. A volume counts when either its front matter or any document source note names the collection. So a collection can have volumes and no documents. Coverage is uneven by era, and switching the unit is the way through it. Named collections are scarce before 1948, where central-file classes carry almost the whole record. Classes all but disappear after 1976, where the presidential libraries carry it. The class list holds two filing systems, because FRUS cites both: the decimal classes of the pre-1963 central files, and the subject-numeric designators that replaced them. They are ranked at one depth. A decimal file number stands for itself; subject-numeric designators are grouped to their category and number, because at full length half of them carry a single document. Open a grouped row under the chart for the exact designator a pull slip needs. Collections are grouped across volumes by name. When two spellings of one name fail to merge, the same body of records appears twice under nearby names."))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    // MARK: - Your Library mode

    @ViewBuilder
    private var yourLibraryMode: some View {
        if let profile = libraryProfile {
            if profile.isEmpty {
                libraryEmptyState
            } else {
                libraryIntro(profile)
                libraryCompositionCard(profile)
                libraryBandsCard(profile)
                libraryCollectionsCard(profile)
                libraryFooter(profile)
            }
        } else {
            loadingState(String(localized: "archival.library.loading",
                                defaultValue: "Counting your indexed source notes…"))
        }
    }

    private func libraryIntro(_ profile: ArchivalLibraryProfile) -> some View {
        Text(String(format: String(
            localized: "archival.library.intro %lld %lld",
            defaultValue: "The archival profile of **your** library — computed from the %1$lld source notes across the %2$lld indexed volumes that carry them, not from the bundled corpus-wide aggregates."),
            Int64(profile.noteCount), Int64(profile.volumeCount)))
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func libraryCompositionCard(_ profile: ArchivalLibraryProfile) -> some View {
        let provenance = ArchivalAnalyticsExport.library(
            title: String(localized: "archival.library.composition.title",
                          defaultValue: "Where your documents come from"),
            axisLabel: String(localized: "archival.export.axis.composition",
                              defaultValue: "Divided by kind of archival collection"),
            profile: profile, indexedVolumeCount: appState?.indexedVolumeIds.count ?? 0,
            corpusVolumeCount: corpusVolumeCount)
        return SeriesChartCard(
            title: String(localized: "archival.library.composition.title",
                          defaultValue: "Where your documents come from"),
            caption: String(localized: "archival.library.composition.caption",
                            defaultValue: "Every source note in your index, divided among the kinds of archival collection they cite."),
            inspector: libraryCompositionTable(profile),
            onInspect: { inspectorData = $0 },
            controls: {
                exportControl(table: libraryCompositionTable(profile), provenance: provenance)
            }
        ) {
            Chart {
                ForEach(profile.composition) { item in
                    BarMark(
                        x: .value(String(localized: "archival.table.documents",
                                         defaultValue: "Documents"), item.documentCount),
                        y: .value(String(localized: "archival.library.composition.y",
                                         defaultValue: "Your library"), "")
                    )
                    .foregroundStyle(by: .value(
                        String(localized: "archival.table.provenance", defaultValue: "Provenance"),
                        item.category.displayName))
                    .accessibilityLabel(Text(item.category.displayName))
                    .accessibilityValue(Text(String(
                        format: String(localized: "archival.library.composition.a11y %lld %@",
                                       defaultValue: "%1$lld documents, %2$@"),
                        Int64(item.documentCount),
                        percentString(item.documentCount, of: profile.noteCount))))
                }
            }
            .chartForegroundStyleScale(
                domain: SourceProvenanceCategory.ordered.map(\.displayName))
            .chartYAxis(.hidden)
            .frame(height: 120)
        }
    }

    private func libraryBandsCard(_ profile: ArchivalLibraryProfile) -> some View {
        let provenance = ArchivalAnalyticsExport.library(
            title: String(localized: "archival.library.bands.title",
                          defaultValue: "Citation forms across your volumes"),
            axisLabel: String(localized: "archival.export.axis.bands",
                              defaultValue: "Divided by coverage era and kind of collection"),
            profile: profile, indexedVolumeCount: appState?.indexedVolumeIds.count ?? 0,
            corpusVolumeCount: corpusVolumeCount)
        return SeriesChartCard(
            title: String(localized: "archival.library.bands.title",
                          defaultValue: "Citation forms across your volumes"),
            caption: String(localized: "archival.library.bands.caption",
                            defaultValue: "The same composition, split by the era your volumes cover. Read left to right it is the shift from the State Department's decimal file, through the postwar bureau lot files, to the presidential libraries."),
            inspector: libraryBandsTable(profile),
            onInspect: { inspectorData = $0 },
            controls: {
                exportControl(table: libraryBandsTable(profile), provenance: provenance)
            }
        ) {
            Chart {
                ForEach(profile.bands) { band in
                    ForEach(band.categories) { item in
                        BarMark(
                            x: .value(String(localized: "archival.filter.era",
                                             defaultValue: "Coverage era"), band.band.title),
                            y: .value(String(localized: "archival.table.documents",
                                             defaultValue: "Documents"), item.documentCount)
                        )
                        .foregroundStyle(by: .value(
                            String(localized: "archival.table.provenance",
                                   defaultValue: "Provenance"), item.category.displayName))
                        .accessibilityLabel(Text("\(band.band.title), \(item.category.displayName)"))
                        .accessibilityValue(Text(item.documentCount, format: .number))
                    }
                }
            }
            .chartForegroundStyleScale(
                domain: SourceProvenanceCategory.ordered.map(\.displayName))
            .chartXAxisLabel(String(localized: "archival.filter.era", defaultValue: "Coverage era"))
            .chartYAxisLabel(String(localized: "archival.table.documents",
                                    defaultValue: "Documents"))
            .frame(height: 260)
        }
    }

    /// The composition card's table, shared by the inspector and the export.
    private func libraryCompositionTable(_ profile: ArchivalLibraryProfile) -> ChartInspectorData {
        ChartInspectorData(
            id: "archival.library.composition",
            title: String(localized: "archival.library.composition.title",
                          defaultValue: "Where your documents come from"),
            columns: [
                String(localized: "archival.table.provenance", defaultValue: "Provenance"),
                String(localized: "archival.table.documents", defaultValue: "Documents"),
                String(localized: "archival.table.share", defaultValue: "Share"),
            ],
            rowCells: profile.composition.map {
                [$0.category.displayName, "\($0.documentCount)",
                 percentString($0.documentCount, of: profile.noteCount)]
            })
    }

    /// The era-band card's table, shared by the inspector and the export.
    private func libraryBandsTable(_ profile: ArchivalLibraryProfile) -> ChartInspectorData {
        ChartInspectorData(
            id: "archival.library.bands",
            title: String(localized: "archival.library.bands.title",
                          defaultValue: "Citation forms across your volumes"),
            columns: [
                String(localized: "archival.filter.era", defaultValue: "Coverage era"),
                String(localized: "archival.table.provenance", defaultValue: "Provenance"),
                String(localized: "archival.table.documents", defaultValue: "Documents"),
            ],
            rowCells: profile.bands.flatMap { band in
                band.categories.map {
                    [band.band.title, $0.category.displayName, "\($0.documentCount)"]
                }
            })
    }

    /// Your most-cited collections.
    ///
    /// A `SeriesChartCard` like its siblings even though its content is a list rather than a
    /// chart: #765 shipped it as a bare `VStack`, so it was the one card on this surface with
    /// neither a table inspector nor an export — and it is the card whose rows a reader is most
    /// likely to want to take away.
    private func libraryCollectionsCard(_ profile: ArchivalLibraryProfile) -> some View {
        let provenance = ArchivalAnalyticsExport.library(
            title: String(localized: "archival.library.collections.title",
                          defaultValue: "Your most-cited collections"),
            axisLabel: String(localized: "archival.export.axis.collections",
                              defaultValue: "Ranked by documents drawn from the collection"),
            profile: profile, indexedVolumeCount: appState?.indexedVolumeIds.count ?? 0,
            corpusVolumeCount: corpusVolumeCount)
        return SeriesChartCard(
            title: String(localized: "archival.library.collections.title",
                          defaultValue: "Your most-cited collections"),
            caption: String(format: String(
                localized: "archival.library.collections.caption %lld %lld",
                defaultValue: "Matched from your own source notes against the archival authority list in the app. %1$lld notes cite the central files, which are a filing system rather than a collection. Another %2$lld name something the list does not recognise. Neither group is listed here."),
                Int64(profile.centralFileNoteCount),
                Int64(profile.unresolvedCollectionNoteCount)),
            inspector: libraryCollectionsTable(profile),
            onInspect: { inspectorData = $0 },
            controls: {
                exportControl(table: libraryCollectionsTable(profile), provenance: provenance)
            }
        ) {
            if profile.collections.isEmpty {
                Text(String(localized: "archival.library.collections.empty",
                            defaultValue: "None of your volumes' source notes name a collection the bundled authority recognises."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(profile.collections) { item in
                        Button {
                            openNeighbors(for: item.record)
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.record.name).font(.callout)
                                    if let repository = item.record.repository {
                                        Text(repository).font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer(minLength: 8)
                                Text(String(format: String(
                                    localized: "archival.library.collections.count %lld",
                                    defaultValue: "%lld docs"), Int64(item.documentCount)))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(String(localized: "archival.library.collections.hint",
                                                  defaultValue: "Shows the documents in your index drawn from this collection"))
                        Divider()
                    }
                }
            }
        }
    }

    /// The collections list's table, shared by the inspector and the export.
    private func libraryCollectionsTable(_ profile: ArchivalLibraryProfile) -> ChartInspectorData {
        ChartInspectorData(
            id: "archival.library.collections",
            title: String(localized: "archival.library.collections.title",
                          defaultValue: "Your most-cited collections"),
            columns: [
                String(localized: "archival.table.unit", defaultValue: "Archival unit"),
                String(localized: "archival.table.custodian", defaultValue: "Custodian"),
                String(localized: "archival.table.documents", defaultValue: "Documents"),
            ],
            rowCells: profile.collections.map {
                [$0.record.name,
                 $0.record.repository ?? ArchivalRepositoryCategory.from($0.record).displayName,
                 "\($0.documentCount)"]
            })
    }

    private func libraryFooter(_ profile: ArchivalLibraryProfile) -> some View {
        let indexed = appState?.indexedVolumeIds.count ?? profile.volumeCount
        let total = corpusVolumeCount
        return VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "archival.caveats.title", defaultValue: "About these figures"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(String(format: String(
                localized: "archival.library.footer %lld %lld",
                defaultValue: "Counted from the %1$lld volumes you have indexed. %2$lld more exist in the series. Index more and these charts change with you. The Collections mode is different: it does not depend on what you have downloaded."),
                Int64(indexed), Int64(max(total - indexed, 0))))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(String(format: String(
                localized: "archival.library.footer.detail %lld %lld",
                defaultValue: "A source note is not a document. Only documents whose editors recorded where the original was found appear here. So this total is smaller than your indexed document count, and volumes with no source notes add nothing. The collections list matches each citation to a named body of records. %1$lld notes cite the central files, which are a filing system rather than a collection; those notes are counted in the composition above. Another %2$lld name something the app's authority list does not recognise."),
                Int64(profile.centralFileNoteCount),
                Int64(profile.unresolvedCollectionNoteCount)))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    private var libraryEmptyState: some View {
        ContentUnavailableView(
            String(localized: "archival.library.empty.title", defaultValue: "No Source Notes Yet"),
            systemImage: "archivebox",
            description: Text(String(localized: "archival.library.empty.detail",
                                     defaultValue: "Download and index a volume and this page will show where its documents came from. The Collections mode works without any downloads."))
        )
    }

    // MARK: - Shared chrome

    private func loadingState(_ message: String) -> some View {
        HStack(spacing: 8) {
            ProgressView()
            Text(message).font(.footnote).foregroundStyle(.secondary)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func percentString(_ value: Int, of total: Int) -> String {
        guard total > 0 else { return "0%" }
        return (Double(value) / Double(total))
            .formatted(.percent.precision(.fractionLength(0...1)))
    }

    // MARK: - Export (D3, #787)

    /// Writes one table with its methods statement above it, and shares or saves the result.
    ///
    /// The preamble is the whole point: an archival table that leaves the app without one carries
    /// no scope, no weight, no era band, and none of the two caveats that make its numbers
    /// readable — and those numbers are the ones on this surface most easily misread.
    private func deliver(_ table: ChartInspectorData, _ provenance: AnalyticsProvenance) {
        let filename = AnalyticsExportDelivery.filenameStem(title: provenance.figureTitle) + ".csv"
        switch AnalyticsExportDelivery.deliver(text: table.provenancedCSV(provenance),
                                               filename: filename) {
        case .share(let item): exportShareItem = item
        case .saved, .cancelled: break
        case .failed(let reason): exportError = reason
        }
    }

    /// Renders one Swift Charts card as a publication figure.
    ///
    /// Offered only on the Swift Charts cards. The two `Canvas` modes export their data and not a
    /// figure: nothing in this app has ever rendered a `Canvas` through `AnalyticsFigureExporter`,
    /// and shipping an unproven render path would be worse than a CSV that works.
    private func deliverFigure<Content: View>(_ format: AnalyticsFigureFormat,
                                              provenance: AnalyticsProvenance,
                                              chartHeight: CGFloat,
                                              @ViewBuilder chart: @escaping () -> Content) {
        let canvas = AnalyticsFigureCanvas(provenance: provenance, chartHeight: chartHeight,
                                            content: chart)
        guard let data = AnalyticsFigureExporter.render(canvas, format: format) else {
            exportError = String(localized: "analytics.export.error.render",
                                 defaultValue: "The figure could not be rendered.")
            return
        }
        let filename = AnalyticsExportDelivery.filenameStem(title: provenance.figureTitle)
            + "." + format.pathExtension
        switch AnalyticsExportDelivery.deliver(data: data, filename: filename,
                                               contentType: format.contentType) {
        case .share(let item): exportShareItem = item
        case .saved, .cancelled: break
        case .failed(let reason): exportError = reason
        }
    }

    /// The export a `Canvas` mode hands up, already carrying its own provenance.
    private func deliver(_ request: ArchivalExportRequest) {
        deliver(request.table, request.provenance)
    }

    // MARK: - Data

    /// Manifest entries by volume id, for the Flows mode's unprinted layer (#784).
    ///
    /// `browsableEntries` rather than the catalogue, so a side-loaded volume is not silently
    /// missing from an era span it belongs to (#777).
    @MainActor
    private var manifestEntriesById: [String: VolumeManifestEntry] {
        guard let store = appState?.manifestStore else { return [:] }
        return Dictionary(store.browsableEntries.map { ($0.volumeId, $0) },
                          uniquingKeysWith: { first, _ in first })
    }

    /// The manifest volumes' coverage spans — the join both modes bucket by.
    ///
    /// Read on the main actor because `ManifestStore` is `@MainActor`; the value is a plain
    /// dictionary, so the derivations that consume it can run anywhere.
    @MainActor
    private func volumeCoverage() -> [String: ArchivalVolumeCoverage] {
        guard let store = appState?.manifestStore else { return [:] }
        let entries = store.diffResult?.known ?? store.bundledEntries
        var result: [String: ArchivalVolumeCoverage] = [:]
        result.reserveCapacity(entries.count)
        for entry in entries {
            let first = FRUSVolumeMetadata.firstYear(in: entry.dateRange.earliest)
            let last = FRUSVolumeMetadata.firstYear(in: entry.dateRange.latest)
            guard let start = first ?? last, let end = last ?? first else { continue }
            result[entry.volumeId] = ArchivalVolumeCoverage(firstYear: start, lastYear: end)
        }
        return result
    }

    /// Volumes in the series, for the library footer's "more exist" clause.
    private var corpusVolumeCount: Int {
        guard let store = appState?.manifestStore else { return 0 }
        return (store.diffResult?.known ?? store.bundledEntries).count
    }

    /// Builds the corpus-wide derivation off the main actor.
    private func loadCollections() async {
        guard collectionsData == nil else { return }
        let coverage = volumeCoverage()
        let authority = CollectionAuthorityStore.shared?.collections ?? []
        let usage = CollectionUsageIndexStore.shared
        collectionsData = await Task.detached(priority: .userInitiated) {
            ArchivalCollectionsData.make(authority: authority, usage: usage, coverage: coverage)
        }.value
    }

    /// Runs the two grouped queries and folds them, once per visit.
    ///
    /// The "loaded" flag is set only once a pipeline actually exists, so a call that arrives
    /// mid-boot leaves the loading state up and the next token change retries.
    private func loadLibraryIfNeeded() async {
        guard mode == .yourLibrary, !hasLoadedLibrary,
              let pipeline = appState?.indexingPipeline else { return }
        hasLoadedLibrary = true
        let coverage = volumeCoverage()
        let authority = CollectionAuthorityStore.shared
        do {
            let groups = try await pipeline.archivalLibraryGroups()
            let collectionGroups = try await pipeline.archivalLibraryCollectionGroups()
            libraryProfile = ArchivalLibraryProfile.make(
                groups: groups, collectionGroups: collectionGroups,
                coverage: coverage, authority: authority)
        } catch {
            #if DEBUG
            print("[ArchivalAnalyticsView] library profile failed — \(error)")
            #endif
            libraryProfile = .empty
        }
    }

    /// Opens Archival Neighbors for a collection, following the same window-where-windows-exist
    /// rule the collection detail uses (#241 S6): a window wherever windows exist — the
    /// neighbour list is a work list and must survive navigation — and a sheet only on iPhone.
    private func openNeighbors(for record: AuthorityCollectionRecord) {
        let request = ArchivalNeighborsRequest(collectionRecord: record)
        #if os(iOS)
        guard supportsMultipleWindows else {
            neighborsTarget = ArchivalLibraryNeighborsTarget(record: record)
            return
        }
        appState?.openAuxWindow(request, from: sceneID, using: openWindow)
        #else
        // This view is hosted in the Archival Analytics window, so the neighbours window
        // inherits the analytics provenance.
        appState?.bindTool(.archivalNeighbors(request),
                           to: appState?.provenance(of: .analytics))
        openWindow(value: request)
        #endif
    }

    /// Opens Archival Neighbors for a central-file class.
    ///
    /// A class routes to the class-keyed request, never to a collection detail — it is a subject
    /// heading inside a filing system, not a body of records, and there is no record to open.
    private func openClassNeighbors(_ classKey: String) {
        let request = ArchivalNeighborsRequest.decimalClass(classKey)
        #if os(iOS)
        guard supportsMultipleWindows else {
            classNeighborsTarget = ArchivalClassNeighborsTarget(classKey: classKey)
            return
        }
        appState?.openAuxWindow(request, from: sceneID, using: openWindow)
        #else
        appState?.bindTool(.archivalNeighbors(request),
                           to: appState?.provenance(of: .analytics))
        openWindow(value: request)
        #endif
    }

    #if os(iOS)
    /// The iPhone sheet's loader — the same record-level query the collection detail runs.
    private func loadNeighbors(for record: AuthorityCollectionRecord,
                               scopeVolumeIds: Set<String>?) async -> ArchivalNeighborsResult {
        guard let pipeline = appState?.indexingPipeline else { return ([], 0, nil) }
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

// MARK: - ArchivalLibraryNeighborsTarget

/// `.sheet(item:)` target for the Your Library collection rows on iPhone, where there are no
/// extra windows to open the neighbour list into.
private struct ArchivalLibraryNeighborsTarget: Identifiable {
    /// The collection whose neighbours to show.
    let record: AuthorityCollectionRecord
    let id = UUID()
}

// MARK: - ArchivalClassNeighborsTarget

/// The same `.sheet(item:)` fallback for a central-file class, whose neighbours are a
/// `decimal_class` query rather than a collection match.
private struct ArchivalClassNeighborsTarget: Identifiable {
    /// The class key.
    let classKey: String
    let id = UUID()
}

#endif
