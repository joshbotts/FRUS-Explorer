// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - CorpusView

/// The top-level Browser view: an inline volume search, the cross-volume index doors, and
/// the "Browse by" axis tiles (#1051 root direction 2a).
///
/// ## The 2a shape, and the constraint it deliberately bends
/// The subseries list — the root's whole content since Session 11 — now lives one tap deep
/// behind the double-width "Subseries" tile (`BrowserLevel.subseriesIndex`), so the root can
/// hold the browse-axes program's doors without scrolling. The owner explicitly accepted
/// that trade (decision register Q-9, Browse-Axes-Development-Plan.md §2): the tile's width,
/// icon, and count copy carry the hierarchy's primacy instead of its position.
///
/// ## What is pinned
/// People stays the FIRST cross-volume row — two UI-test doc comments and
/// `testBrowseIsTwoPaneOnWideiPad` use it as the two-pane list-pane oracle. The search
/// field row sits above the section (it is a text field, not a cross-volume row), and
/// `ResumeReadingRow` stays first of all.
///
/// ## Search
/// The root search is an INLINE field, not `.searchable`, on purpose: in the two-pane
/// layout this view is a persistent list pane inside the same navigation container as the
/// detail pane, and two `.searchable` sources on one container (this plus a pushed level's,
/// e.g. the catalogue's) is an unsupported composition. An inline row is deterministic in
/// both layouts and matches the 2a mock. While a query is active the doors give way to the
/// matching volume rows.
///
/// Version history:
///   1.0 — Session 11: initial implementation
///   1.1 — Session 58: wrap bare interpolation in accessibilityLabel with String(localized:) (F-022)
///   1.2 — Session 87: People cross-volume index entry
///   1.3 — Session 130: removed CorpusStatsView section (volume/document counts and date ranges
///          from the manifest were inaccurate or irrelevant to in-app navigation)
///   1.4 — #312: both row types are now tappable across the full row width. They were
///          `Button … .buttonStyle(.plain)` wrapping an intrinsically-sized label, so only the
///          label's own glyphs were hit-testable and most of a ~370pt row was dead space —
///          for a finger, not just for the UI-test harness that spent three investigations
///          (`UIObstructionTests` 1.6/1.7/1.9) blaming XCUITest for it.
///   2.0 — #1051 B-1 (root direction 2a): inline volume search; the subseries list moves
///          behind the "Subseries" tile (`.subseriesIndex`); "Browse by" tile section with
///          the Subseries and All Volumes doors (the grid grows an axis tile per session —
///          Administrations/Editors land with B-2, and the section becomes a 2-column grid
///          when it holds four); `SubseriesRowLabel` moved to `SubseriesDirectoryView.swift`
///          with its dead `totalDocuments` gate rewired to the R-2 accessor
///   2.1 — #1051 B-2: the section reached four doors, so the 2a grid arrives — the
///          Subseries tile double-width above a two-column `LazyVGrid` (All Volumes,
///          Administrations, Editors), tiles painting their own cards in one
///          chrome-free row
struct CorpusView: View {

    let vm: BrowserViewModel

    /// Whether this instance carries the "Working on:" research-question navigation subtitle
    /// (UI review F-2).
    ///
    /// Both this view and every pushed level apply `.workingOnSubtitle()`, and until F-2 only one
    /// of the two was ever on screen. In the two-pane layout both are, so the question would
    /// render twice; the list pane keeps it because it is the pane that is always present.
    var showsWorkingOnSubtitle: Bool = true

    @Environment(AppState.self) private var appState

    /// The user's scopes, for the Your Sets row's count (#1051 B-3).
    @Query private var scopes: [CustomVolumeScope]

    /// The user's working corpora, for the Your Sets row's count (#1051 B-4).
    @Query private var corpora: [WorkingCorpus]

    /// The root search query. Inline state, deliberately not `.searchable` — see the type doc.
    @State private var searchText: String = ""

    var body: some View {
        List {
            // #754: the one thing a relaunch gives back. Offered, never forced — see
            // `ResumeReadingRow`. Renders nothing when there is no resumable read.
            ResumeReadingRow { entry in
                vm.select(.document(entry))
            }

            searchFieldSection

            if searchTrimmed.isEmpty {
                crossVolumeIndicesSection
                browseBySection
                yourSetsSection
            } else {
                searchResultsSection
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
        .navigationTitle(String(localized: "browser.corpus.title", defaultValue: "FRUS Corpus"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        // #377 Phase 5: on regular-width iPad the top-inset "Working on:" banner is suppressed (it
        // collides with the floating tab bar, #238); surface the research question here instead.
        .workingOnSubtitle(isActive: showsWorkingOnSubtitle)
    }

    // MARK: - Search

    private var searchTrimmed: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Volumes matching the root query, on title or volume number, in manifest order.
    private var searchMatches: [VolumeManifestEntry] {
        let query = searchTrimmed
        guard !query.isEmpty else { return [] }
        return vm.allVolumes.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.volumeId.localizedCaseInsensitiveContains(query)
        }
    }

    private var searchFieldSection: some View {
        Section {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField(
                    String(localized: "browser.corpus.search.prompt",
                           defaultValue: "Search \(vm.allVolumes.count) volumes by title or number"),
                    text: $searchText
                )
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .accessibilityIdentifier("browse.root.searchField")
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(
                        String(localized: "browser.corpus.search.clear.a11y",
                               defaultValue: "Clear volume search")
                    )
                }
            }
        }
    }

    /// The matching volume rows, replacing the doors while a query is active.
    private var searchResultsSection: some View {
        let matches = searchMatches
        return Section(header: Text(
            matches.isEmpty
                ? String(localized: "browser.corpus.search.none", defaultValue: "No Matching Volumes")
                : String(localized: "browser.corpus.search.header",
                         defaultValue: "Volumes (\(matches.count))")
        )) {
            if matches.isEmpty {
                Text(String(localized: "browser.corpus.search.emptyDetail",
                            defaultValue: "No volume title or number matches this search."))
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                ForEach(matches) { entry in
                    Button {
                        // Root-level selection ASSIGNS the path (the list-pane contract) —
                        // a volume chosen from root search is a fresh start, not a push.
                        vm.select(.volume(entry))
                        #if DEBUG
                        print("[BrowserView] Root search → volume \(entry.volumeId)")
                        #endif
                    } label: {
                        VolumeRowLabel(
                            volume: entry,
                            isDownloaded: vm.isDownloaded(entry.volumeId),
                            isIndexed: vm.isIndexed(entry.volumeId),
                            isDownloading: appState.downloadQueue.contains(entry.volumeId),
                            documentCount: appState.administrationProfilesStore
                                .documentCount(forVolumeId: entry.volumeId)
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Cross-volume indices

    private var crossVolumeIndicesSection: some View {
        Section {
            Button {
                vm.select(.people)
            } label: {
                Label(
                    String(localized: "browser.corpus.people", defaultValue: "People"),
                    systemImage: "person.2"
                )
                .foregroundStyle(.primary)
                // Both modifiers are required, and in this order. `.contentShape` reshapes the
                // hit area WITHIN the view's frame; it does not widen the frame, and a bare
                // `Label` in a List row is only as wide as its glyphs (~65pt of a ~370pt row).
                // So contentShape alone buys nothing here — it just fills the gaps between the
                // glyphs it already covers.
                //
                // A/B-MEASURED, not assumed (iPhone 17, iOS 26.3.1), against
                // `UIObstructionTests.testBreadcrumbBarNotObstructingFirstRow`, which taps a row
                // and requires a push: with contentShape ALONE the test FAILS ("did not push a
                // browser level"); with the frame restored it PASSES, on iPhone and iPad both.
                // Do not "simplify" by deleting the frame — that silently restores the dead zone
                // and turns that test red. Same idiom as the Settings rows, where the greed comes
                // from an `HStack { … Spacer() }` rather than an explicit frame.
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                String(localized: "browser.corpus.people.a11y",
                       defaultValue: "Browse people mentioned across all indexed volumes")
            )
            .help(String(localized: "browser.corpus.people.help",
                         defaultValue: "Browse an alphabetical index of all people mentioned across your indexed volumes — tap a name to search for every document where they appear"))

            // BELOW People, deliberately. Two UI-test doc comments state that the corpus list's
            // FIRST cross-volume row "since Session 87 is People", and
            // `testBrowseIsTwoPaneOnWideiPad` uses that row as its list-pane oracle. Inserting
            // above would make both stale without failing anything.
            Button {
                vm.select(.subjects)
            } label: {
                Label(
                    String(localized: "browser.corpus.subjects", defaultValue: "Topics"),
                    systemImage: "tag"
                )
                .foregroundStyle(.primary)
                // Both modifiers, in this order — see the A/B measurement on the row above.
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                String(localized: "browser.corpus.subjects.a11y",
                       defaultValue: "Browse detected topics across the whole series")
            )
            .help(String(localized: "browser.corpus.subjects.help",
                         defaultValue: "Browse an index of the topics detected across the whole series — including volumes you have not downloaded. Tap one to see its reach and find documents on it"))
        }
    }

    // MARK: - Browse by (the axis doors, 2a)

    /// The axis doors: the double-width Subseries tile above the two-column grid — the 2a
    /// shape, which arrived when the section reached four doors (B-2). Each later session
    /// appends its axis's grid tile (the sets in B-3/B-4, Archives in B-5, Clusters in
    /// B-7). The tiles paint their own cards because the section's one row clears the
    /// grouped-list chrome to host the grid.
    private var browseBySection: some View {
        Section(header: Text(String(localized: "browser.corpus.browseBy.header",
                                    defaultValue: "Browse by"))) {
            VStack(spacing: 10) {
                BrowseAxisTile(
                    title: String(localized: "browser.corpus.tile.subseries", defaultValue: "Subseries"),
                    caption: subseriesTileCaption,
                    systemImage: "books.vertical",
                    accessibilityIdentifier: "browse.root.subseriesTile"
                ) {
                    vm.select(.subseriesIndex)
                    #if DEBUG
                    print("[BrowserView] Navigate → subseries directory")
                    #endif
                }
                .accessibilityLabel(
                    String(localized: "browser.corpus.tile.subseries.a11y",
                           defaultValue: "Browse by subseries")
                )
                .help(String(localized: "browser.corpus.tile.subseries.help",
                             defaultValue: "Browse the series era by era — every subseries with its volumes"))

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())],
                          spacing: 10) {
                    BrowseAxisGridTile(
                        title: String(localized: "browser.corpus.tile.catalogue",
                                      defaultValue: "All Volumes"),
                        systemImage: "line.3.horizontal.decrease.circle",
                        accessibilityIdentifier: "browse.root.catalogueTile"
                    ) {
                        vm.select(.catalogue)
                        #if DEBUG
                        print("[BrowserView] Navigate → All Volumes catalogue")
                        #endif
                    }
                    .accessibilityLabel(
                        String(localized: "browser.corpus.tile.catalogue.a11y",
                               defaultValue: "Browse all volumes")
                    )
                    .help(String(localized: "browser.corpus.tile.catalogue.help",
                                 defaultValue: "One catalogue of every volume — search it, or arrange it by title, publication year, era, or length"))

                    BrowseAxisGridTile(
                        title: String(localized: "browser.corpus.tile.administrations",
                                      defaultValue: "Administrations"),
                        systemImage: "building.columns",
                        accessibilityIdentifier: "browse.root.administrationsTile"
                    ) {
                        vm.select(.administrations)
                        #if DEBUG
                        print("[BrowserView] Navigate → administrations index")
                        #endif
                    }
                    .accessibilityLabel(
                        String(localized: "browser.corpus.tile.administrations.a11y",
                               defaultValue: "Browse by administration")
                    )
                    .help(String(localized: "browser.corpus.tile.administrations.help",
                                 defaultValue: "Volumes filed by the presidency their documents cover"))

                    BrowseAxisGridTile(
                        title: String(localized: "browser.corpus.tile.editors",
                                      defaultValue: "Editors"),
                        systemImage: "person.text.rectangle",
                        accessibilityIdentifier: "browse.root.editorsTile"
                    ) {
                        vm.select(.editors)
                        #if DEBUG
                        print("[BrowserView] Navigate → editors index")
                        #endif
                    }
                    .accessibilityLabel(
                        String(localized: "browser.corpus.tile.editors.a11y",
                               defaultValue: "Browse by editor")
                    )
                    .help(String(localized: "browser.corpus.tile.editors.help",
                                 defaultValue: "Volumes filed by the editors named on their title pages"))

                    BrowseAxisGridTile(
                        title: String(localized: "browser.corpus.tile.archives",
                                      defaultValue: "Archives"),
                        systemImage: "archivebox",
                        accessibilityIdentifier: "browse.root.archivesTile"
                    ) {
                        vm.select(.archives)
                        #if DEBUG
                        print("[BrowserView] Navigate → archives axis")
                        #endif
                    }
                    .accessibilityLabel(
                        String(localized: "browser.corpus.tile.archives.a11y",
                               defaultValue: "Browse by archival provenance")
                    )
                    .help(String(localized: "browser.corpus.tile.archives.help",
                                 defaultValue: "Volumes filed by the kind of file their documents came from, and the archival collections FRUS drew on"))
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - Your sets (#1051 B-3)

    /// The user's own collections of the corpus — My Scopes now, Working Corpora with B-4.
    /// Rows, not tiles: the 1d/2a design keeps Your Sets as a row section with counts.
    private var yourSetsSection: some View {
        Section(header: Text(String(localized: "browser.corpus.yourSets.header",
                                    defaultValue: "Your sets"))) {
            Button {
                vm.select(.scopes)
                #if DEBUG
                print("[BrowserView] Navigate → my scopes")
                #endif
            } label: {
                HStack {
                    Label(
                        String(localized: "browser.corpus.scopes", defaultValue: "My Scopes"),
                        systemImage: "square.stack.3d.up"
                    )
                    .foregroundStyle(.primary)
                    Spacer(minLength: 8)
                    if !scopes.isEmpty {
                        Text("\(scopes.count)")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                // Both modifiers, in this order — see the People row's A/B measurement.
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("browse.root.scopesRow")
            .accessibilityLabel(
                String(localized: "browser.corpus.scopes.a11y",
                       defaultValue: "Browse your custom volume scopes")
            )
            .help(String(localized: "browser.corpus.scopes.help",
                         defaultValue: "Volume sets you assemble yourself — browse, edit, or narrow the whole Browse tab to one"))

            Button {
                vm.select(.corpora)
                #if DEBUG
                print("[BrowserView] Navigate → working corpora")
                #endif
            } label: {
                HStack {
                    Label(
                        String(localized: "browser.corpus.corpora", defaultValue: "Working Corpora"),
                        systemImage: "tray.full"
                    )
                    .foregroundStyle(.primary)
                    Spacer(minLength: 8)
                    if !corpora.isEmpty {
                        Text("\(corpora.count)")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                // Both modifiers, in this order — see the People row's A/B measurement.
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("browse.root.corporaRow")
            .accessibilityLabel(
                String(localized: "browser.corpus.corpora.a11y",
                       defaultValue: "Browse your working corpora")
            )
            .help(String(localized: "browser.corpus.corpora.help",
                         defaultValue: "Fixed document sets captured from Search results or the semantic map — browse each one's documents, grouped by volume"))
        }
    }

    /// "552 volumes by era, 1861–1988" — counts and years from the live manifest, never
    /// hard-coded (side-loaded volumes move both). The year scan lives on
    /// `VolumeCatalogueGrouping`, NOT here: a `View`'s statics are MainActor-isolated, so a
    /// helper parked on the view type crashes a nonisolated test that calls it (the
    /// move-the-rule-don't-annotate lesson).
    private var subseriesTileCaption: String {
        let volumes = vm.allVolumes
        let years = volumes.flatMap { VolumeCatalogueGrouping.fourDigitRuns(in: $0.subseries) }
        if let min = years.min(), let max = years.max(), min < max {
            return String(localized: "browser.corpus.tile.subseries.caption",
                          defaultValue: "\(volumes.count) volumes by era, \(String(min))–\(String(max))")
        }
        return String(localized: "browser.corpus.tile.subseries.caption.plain",
                      defaultValue: "\(volumes.count) volumes by era")
    }
}

// MARK: - BrowseAxisTile

/// The card ground the axis tiles paint, since their section row clears the grouped-list
/// chrome to host the 2a grid.
enum BrowseTileChrome {
    /// The tile card color — the grouped list's own card color, so the tiles read as
    /// native rows that happen to sit in a grid.
    static var cardColor: Color {
        #if os(iOS)
        Color(uiColor: .secondarySystemGroupedBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }
}

/// The double-width "Browse by" door on the corpus root (#1051 2a): icon, title, caption,
/// chevron — the Subseries tile's shape, whose width and count copy carry the hierarchy's
/// primacy (the trade Q-9 signed off). The action assigns the path via `vm.select` at the
/// call site — root doors assign, never append.
///
/// Version history:
///   1.0 — #1051 B-1: initial implementation
///   1.1 — #1051 B-2: paints its own card (the section row's chrome is cleared for the
///          2a grid)
struct BrowseAxisTile: View {
    let title: String
    let caption: String
    let systemImage: String
    var accessibilityIdentifier: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 21))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 30)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            // Both modifiers, in this order — the #312 full-row tap-target idiom.
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(BrowseTileChrome.cardColor,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .modifier(OptionalAccessibilityIdentifier(identifier: accessibilityIdentifier))
    }
}

// MARK: - BrowseAxisGridTile

/// One half-width "Browse by" door in the 2a grid: icon plus a single-line label
/// (the 1d/2a tile shape — 21pt icon, 14pt medium label, radius-12 card).
///
/// Version history:
///   1.0 — #1051 B-2: initial implementation
struct BrowseAxisGridTile: View {
    let title: String
    let systemImage: String
    var accessibilityIdentifier: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 21))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            // Both modifiers, in this order — the #312 full-row tap-target idiom.
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(BrowseTileChrome.cardColor,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .modifier(OptionalAccessibilityIdentifier(identifier: accessibilityIdentifier))
    }
}

/// Applies an accessibility identifier only when one is provided.
private struct OptionalAccessibilityIdentifier: ViewModifier {
    let identifier: String?

    func body(content: Content) -> some View {
        if let identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}
