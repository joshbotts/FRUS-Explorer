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
/// Two modes ship here. **Collections** ranks the archival units each era's volumes drew on,
/// corpus-wide, from the bundled authority and usage index; **Your Library** counts the same
/// thing in the volumes this reader has actually indexed. The design's other two modes,
/// Network and Flows, are the custom-drawn `Canvas` surfaces and follow in their own change —
/// ``ArchivalAnalyticsMode`` has no case for them, so the picker never offers a dead segment.
///
/// `AppState` is read as an **optional** environment value, the defensive pattern every
/// analytics surface here follows: an absent environment degrades to an empty state instead of
/// trapping.
///
/// Version history:
///   1.0 — Session 2026-08-09: #765 stage 1 (Collections + Your Library)
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
    #if os(iOS)
    /// The iPhone fallback target for Archival Neighbors, where there are no extra windows.
    @State private var neighborsTarget: ArchivalLibraryNeighborsTarget?
    #endif

    private var unitLens: ArchivalUnitLens {
        ArchivalUnitLens(rawValue: unitLensRaw) ?? .namedCollections
    }
    private var weight: ArchivalWeight {
        ArchivalWeight(rawValue: weightRaw) ?? .documents
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    switch mode {
                    case .collections: collectionsMode
                    case .yourLibrary: yourLibraryMode
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
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
        #endif
        .task {
            await loadCollections()
            await loadLibraryIfNeeded()
        }
        .onChange(of: mode) { _, _ in
            Task { await loadLibraryIfNeeded() }
        }
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
            .help(String(localized: "archival.mode.help",
                         defaultValue: "Switch between the corpus-wide collection rankings and the archival profile of your own indexed volumes."))
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

    // MARK: - Collections mode

    @ViewBuilder
    private var collectionsMode: some View {
        if let data = collectionsData {
            let ranking = data.ranking(band: band, lens: unitLens, weight: weight,
                                       hidingUmbrella: hidesUmbrella)
            collectionsIntro
            filterRow(data: data)
            rankingCard(ranking, data: data)
            if unitLens == .namedCollections {
                lifecycleCard(data)
            }
            collectionsCaveats(data: data, ranking: ranking)
        } else {
            loadingState(String(localized: "archival.collections.loading",
                                defaultValue: "Reading the archival authority…"))
        }
    }

    private var collectionsIntro: some View {
        Text(String(localized: "archival.collections.intro",
                    defaultValue: "Every published FRUS document carries a source note naming the archival file it came from. Clustered across the whole series, those notes show which bodies of records each era's editors actually worked in — and how the documentary base of American foreign relations moved out of the State Department's own filing rooms and into the White House."))
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
            // Documents needs the usage index. Disabling the whole menu would also strand the
            // user on whichever weight they last chose, so the menu stays and the unavailable
            // option is the thing that dims.
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

    // MARK: - Card 1: the ranking

    @ViewBuilder
    private func rankingCard(_ ranking: ArchivalRanking, data: ArchivalCollectionsData) -> some View {
        let title = unitLens == .namedCollections
            ? String(localized: "archival.ranking.title.collections",
                     defaultValue: "Top collections by era")
            : String(localized: "archival.ranking.title.classes",
                     defaultValue: "Top central-file classes by era")
        SeriesChartCard(
            title: title,
            caption: rankingCaption(ranking),
            inspector: rankingInspector(ranking),
            onInspect: { inspectorData = $0 }
        ) {
            if ranking.rows.isEmpty {
                Text(String(localized: "archival.ranking.empty",
                            defaultValue: "No archival units resolved in this era under the current unit and weight."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 12)
            } else {
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
                .frame(height: CGFloat(ranking.rows.count) * 26 + 60)
            }
        }
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

    private func rankingInspector(_ ranking: ArchivalRanking) -> ChartInspectorData? {
        guard !ranking.rows.isEmpty else { return nil }
        return ChartInspectorData(
            id: "archival.ranking",
            title: String(localized: "archival.ranking.title.collections",
                          defaultValue: "Top collections by era"),
            columns: [
                String(localized: "archival.table.unit", defaultValue: "Archival unit"),
                String(localized: "archival.table.custodian", defaultValue: "Custodian"),
                weight.title,
            ],
            rowCells: ranking.rows.map { [$0.label, $0.category.displayName, "\($0.value)"] })
    }

    // MARK: - Card 2: lifecycles

    private func lifecycleCard(_ data: ArchivalCollectionsData) -> some View {
        let spans = data.lifecycleSpans
        return SeriesChartCard(
            title: String(localized: "archival.lifecycle.title",
                          defaultValue: "Collection lifecycles in FRUS sourcing"),
            caption: String(localized: "archival.lifecycle.caption",
                            defaultValue: "The coverage years spanned by the volumes that cite each of the most widely-drawn-on collections — where a body of records enters the published record and how long the editors keep returning to it. This card does not change with the era filter."),
            inspector: ChartInspectorData(
                id: "archival.lifecycle",
                title: String(localized: "archival.lifecycle.title",
                              defaultValue: "Collection lifecycles in FRUS sourcing"),
                columns: [
                    String(localized: "archival.table.unit", defaultValue: "Archival unit"),
                    String(localized: "archival.table.custodian", defaultValue: "Custodian"),
                    String(localized: "archival.table.first", defaultValue: "First coverage year"),
                    String(localized: "archival.table.last", defaultValue: "Last coverage year"),
                    String(localized: "archival.weight.volumes", defaultValue: "Volumes"),
                ],
                rowCells: spans.map {
                    [$0.label, $0.category.displayName, "\($0.firstYear)", "\($0.lastYear)",
                     "\($0.volumeCount)"]
                }),
            onInspect: { inspectorData = $0 }
        ) {
            Chart {
                ForEach(spans) { span in
                    BarMark(
                        xStart: .value(String(localized: "archival.table.first",
                                              defaultValue: "First coverage year"), span.firstYear),
                        xEnd: .value(String(localized: "archival.table.last",
                                            defaultValue: "Last coverage year"), span.lastYear),
                        y: .value(String(localized: "archival.ranking.y",
                                         defaultValue: "Archival unit"), span.label)
                    )
                    .foregroundStyle(by: .value(
                        String(localized: "archival.ranking.legend", defaultValue: "Custodian"),
                        span.category.displayName))
                    .cornerRadius(3)
                    .accessibilityLabel(Text(span.label))
                    .accessibilityValue(Text(String(
                        format: String(localized: "archival.lifecycle.a11y %lld %lld %lld",
                                       defaultValue: "%1$lld to %2$lld, cited by %3$lld volumes"),
                        Int64(span.firstYear), Int64(span.lastYear), Int64(span.volumeCount))))
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
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: SeriesChartKind.yearAxisFormat)
                }
            }
            .chartXAxisLabel(String(localized: "archival.lifecycle.x",
                                    defaultValue: "Coverage year"))
            .frame(height: CGFloat(spans.count) * 24 + 60)
        }
    }

    // MARK: - Collections caveats

    private func collectionsCaveats(data: ArchivalCollectionsData,
                                    ranking: ArchivalRanking) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "archival.caveats.title", defaultValue: "About these figures"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            if let hidden = ranking.hiddenUmbrellaValue {
                Text(String(format: String(
                    localized: "archival.caveats.umbrella %lld %@ %@",
                    defaultValue: "The Central Files umbrella record is hidden here: it accounts for %1$lld %2$@ in the %3$@ volumes on its own, and its bar would flatten the scale. The era-specific Central Files records are not hidden."),
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
                        defaultValue: "These figures are parsed out of document source notes, not read from an archive's catalog: they say where the editors drew documents from, which is an editorial and archival signal rather than a census of the records themselves. The two weights count different populations. Documents come from the usage index, which resolves a note to a collection only when the citation names one; volumes come from the collection authority, where a volume counts if its front matter or any document note names the collection — so a collection can have volumes and no documents. Coverage is uneven by era on purpose, and the unit switch is the way through it: named collections are scarce before 1948, where the central-file classes carry almost the whole record, and classes all but disappear after 1976, where the presidential libraries carry it. Class keys hold two filing systems — the decimal classes of the pre-1963 central files and the subject-numeric designators that replaced them — because FRUS cites both. Collections are clustered across volumes by name, so an under-merge leaves the same body of records under two nearby names rather than combining them."))
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
        SeriesChartCard(
            title: String(localized: "archival.library.composition.title",
                          defaultValue: "Where your documents come from"),
            caption: String(localized: "archival.library.composition.caption",
                            defaultValue: "Every source note in your index, divided among the kinds of archival collection they cite."),
            inspector: ChartInspectorData(
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
                }),
            onInspect: { inspectorData = $0 }
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
        SeriesChartCard(
            title: String(localized: "archival.library.bands.title",
                          defaultValue: "Citation forms across your volumes"),
            caption: String(localized: "archival.library.bands.caption",
                            defaultValue: "The same composition, split by the era your volumes cover. Read left to right it is the shift from the State Department's decimal file, through the postwar bureau lot files, to the presidential libraries."),
            inspector: ChartInspectorData(
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
                }),
            onInspect: { inspectorData = $0 }
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

    @ViewBuilder
    private func libraryCollectionsCard(_ profile: ArchivalLibraryProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "archival.library.collections.title",
                        defaultValue: "Your most-cited collections"))
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            if profile.collections.isEmpty {
                Text(String(localized: "archival.library.collections.empty",
                            defaultValue: "None of your volumes' source notes name a collection the bundled authority recognises."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(profile.collections) { item in
                    Button {
                        openNeighbors(for: item.record)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.record.name).font(.callout)
                                if let repository = item.record.repository {
                                    Text(repository).font(.caption2).foregroundStyle(.secondary)
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

    private func libraryFooter(_ profile: ArchivalLibraryProfile) -> some View {
        let indexed = appState?.indexedVolumeIds.count ?? profile.volumeCount
        let total = corpusVolumeCount
        return VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "archival.caveats.title", defaultValue: "About these figures"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(String(format: String(
                localized: "archival.library.footer %lld %lld",
                defaultValue: "Counted from the %1$lld volumes you have indexed; %2$lld more exist in the series. Index more volumes and these charts change with you — the Collections mode is independent of what you have downloaded."),
                Int64(indexed), Int64(max(total - indexed, 0))))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(String(format: String(
                localized: "archival.library.footer.detail %lld %lld",
                defaultValue: "A source note is not a document: only documents whose editors recorded where the original was found appear here, so this total is smaller than your indexed document count, and volumes carrying no source notes contribute nothing. The collections list resolves a citation to a named body of records; %1$lld notes cite the central files, which are a filing system rather than a collection and are counted in the composition above, and %2$lld more name something the bundled authority does not recognise."),
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

    // MARK: - Data

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
    private func loadLibraryIfNeeded() async {
        guard mode == .yourLibrary, !hasLoadedLibrary else { return }
        hasLoadedLibrary = true
        guard let pipeline = appState?.indexingPipeline else {
            libraryProfile = .empty
            return
        }
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

#endif
