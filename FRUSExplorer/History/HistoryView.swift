// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - HistoryView

/// The research trail — every document opened and every search run — on both platforms.
///
/// ## Why this is shared
/// `HistoryWindowView` was `#if os(macOS)`, so iPhone and iPad had **no** view over the trail at
/// all: the nearest thing was Project Home's per-project recents, and only while a project was
/// active. The one browsable history on iOS was the Session Log in Settings, which shows
/// `ResearchSession`/`SessionEvent` — the store nothing else in the app reads. The Wave R
/// contract calls this the largest remaining "my Mac can do things my iPad cannot", and this view
/// closes it: macOS renders it in the existing `frus.history` window (see ``HistoryWindowView``),
/// iOS pushes it from the Research tab.
///
/// ## What it does that the old window did not
/// - **Scope (contract D4).** All projects / Not in a Project / a named project, pushed into the
///   fetch predicate rather than applied afterwards. Both trail types carry a scalar
///   `projectId: UUID?`, so no new model and no schema change was needed.
/// - **Free-text filter.** Titles and volume/document identifiers for visits, query text for
///   searches. Filters the loaded page — see ``HistoryPaneSnapshot`` on why the term is not
///   pushed into the fetch, and note that the section header states the page size whenever it is
///   showing less than everything.
/// - **Per-entry delete.** `SearchHistoryEntry` previously had no delete path anywhere in the
///   app: the app recorded the user's search text, synced it to their iCloud private database,
///   and offered no way to remove it. A trail-wide delete remains R-5's.
///
/// ## Why not a `@Query`
/// The window this replaces held two live, unbounded `@Query`s over tables that nothing prunes.
/// See ``HistoryPaneSnapshot`` for the full argument; in short, a `@Query` re-renders its whole
/// pane on every CloudKit drip-import and both types are CloudKit-mirrored. This holds a bounded
/// one-shot snapshot in `@State` and re-reads it on appear, on a scope change, on "Show More",
/// and after a delete — the cadence `ResearchItemCounts` and `NotesPaneSnapshot` established.
///
/// Version history:
///   1.0 — Wave R-3: initial implementation, replacing `HistoryWindowView`'s macOS-only body
///   1.1 — Wave R-2a review fixes: a third section for `ExportHistoryEntry`, with the same
///          per-row delete; the deletes key on `entryID` rather than the row's display identity
struct HistoryView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    /// #338: this scene's identity, so an iPad hand-off is addressed to THIS window.
    @Environment(\.sceneID) private var sceneID
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    /// Whether the app is currently recording the trail. Read through `AppState`'s constant, never
    /// a re-declared literal; the default of `true` is the absent-means-on convention that
    /// `AppState.isResearchLoggingEnabled(in:)` documents and `SettingsSyncCoordinator` relies on.
    @AppStorage(AppState.researchLoggingPreferenceKey) private var loggingEnabled = true

    /// The loaded page. Replaced wholesale by ``refresh()``; never mutated in place.
    @State private var snapshot: HistoryPaneSnapshot = .empty
    /// Which slice of the trail to show. Global by default (contract D4).
    @State private var scope: HistoryScope = .all
    /// The free-text filter over the loaded page.
    @State private var query = ""
    /// Rows per section. Raised in ``HistoryPaneSnapshot/pageIncrement`` steps by "Show More".
    @State private var pageLimit = HistoryPaneSnapshot.defaultPageLimit

    // MARK: - Derived

    private var visibleDocuments: [HistoryPaneSnapshot.DocumentRow] {
        snapshot.filteredDocuments(matching: query)
    }

    private var visibleSearches: [HistoryPaneSnapshot.SearchRow] {
        snapshot.filteredSearches(matching: query)
    }

    private var visibleExports: [HistoryPaneSnapshot.ExportRow] {
        snapshot.filteredExports(matching: query)
    }

    /// Whether any filter is narrowing the view, which decides whether an empty section reads
    /// "nothing recorded" or "nothing matches".
    private var isFiltering: Bool {
        scope != .all || !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            filters
            Divider()
            list
        }
        .navigationTitle(String(localized: "history.window.title", defaultValue: "History"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear { refresh() }
        .onChange(of: scope) { _, _ in refresh() }
        .onChange(of: pageLimit) { _, _ in refresh() }
    }

    // MARK: - Filters

    @ViewBuilder
    private var filters: some View {
        #if os(macOS)
        HStack(spacing: 12) {
            scopePicker
            searchField
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        #else
        // Stacked, not a row: a picker and a text field side by side do not fit an iPhone's
        // width — the same call `AllNotesScreen` makes for the same reason. The picker is pinned
        // leading by a trailing `Spacer`; a bare `.menu` Picker centres itself, which reads as a
        // title rather than a control and leaves it misaligned with the field below.
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                scopePicker
                Spacer(minLength: 0)
            }
            searchField
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        #endif
    }

    private var scopePicker: some View {
        Picker(String(localized: "history.scope.label", defaultValue: "Project"),
               selection: $scope) {
            Text(String(localized: "history.scope.all", defaultValue: "All Projects"))
                .tag(HistoryScope.all)
            Text(String(localized: "history.scope.unfiled", defaultValue: "Not in a Project"))
                .tag(HistoryScope.unfiled)
            ForEach(snapshot.projects, id: \.id) { project in
                Text(project.name).tag(HistoryScope.project(project.id))
            }
        }
        .accessibilityLabel(String(localized: "history.scope.a11y",
                                   defaultValue: "Filter history by project"))
        #if os(macOS)
        .frame(maxWidth: 240)
        .help(String(localized: "history.scope.help",
                     defaultValue: "Show only history recorded while a specific project was active"))
        #endif
    }

    private var searchField: some View {
        TextField(String(localized: "history.search.field", defaultValue: "Search history…"),
                  text: $query)
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel(String(localized: "history.search.a11y",
                                       defaultValue: "Search history"))
            #if os(iOS)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            #else
            .frame(minWidth: 160)
            #endif
    }

    // MARK: - List

    private var list: some View {
        List {
            documentsSection
            searchesSection
            exportsSection
        }
        #if os(macOS)
        .listStyle(.inset)
        #else
        .listStyle(.insetGrouped)
        #endif
    }

    private var documentsSection: some View {
        Section {
            if visibleDocuments.isEmpty {
                emptyState(
                    title: isFiltering
                        ? String(localized: "history.filtered.empty.title", defaultValue: "No Matches")
                        : String(localized: "history.documents.empty.title",
                                 defaultValue: "No Documents Visited"),
                    systemImage: "doc.text",
                    detail: isFiltering
                        ? String(localized: "history.filtered.empty.detail",
                                 defaultValue: "No history matches the current filters.")
                        : String(localized: "history.documents.empty.detail",
                                 defaultValue: "Documents you open will appear here."))
            } else {
                ForEach(visibleDocuments) { row in
                    documentRow(row)
                }
                if snapshot.hasMoreDocuments { showMoreButton }
            }
        } header: {
            sectionHeader(
                title: String(localized: "history.section.documents",
                              defaultValue: "Documents Visited"),
                shown: snapshot.documents.count,
                total: snapshot.totalDocuments)
        } footer: {
            loggingFooter
        }
    }

    private var searchesSection: some View {
        Section {
            if visibleSearches.isEmpty {
                emptyState(
                    title: isFiltering
                        ? String(localized: "history.filtered.empty.title", defaultValue: "No Matches")
                        : String(localized: "history.searches.empty.title",
                                 defaultValue: "No Searches Executed"),
                    systemImage: "magnifyingglass",
                    detail: isFiltering
                        ? String(localized: "history.filtered.empty.detail",
                                 defaultValue: "No history matches the current filters.")
                        : String(localized: "history.searches.empty.detail",
                                 defaultValue: "Searches you run will appear here."))
            } else {
                ForEach(visibleSearches) { row in
                    searchRow(row)
                }
                if snapshot.hasMoreSearches { showMoreButton }
            }
        } header: {
            sectionHeader(
                title: String(localized: "history.section.searches",
                              defaultValue: "Searches Executed"),
                shown: snapshot.searches.count,
                total: snapshot.totalSearches)
        }
    }

    /// The third trail type. It had no section here until the R-2a review: the migration's
    /// accepted duplicate residual is justified by every row being "visible and individually
    /// deletable", which an export the History surface never drew could not be.
    private var exportsSection: some View {
        Section {
            if visibleExports.isEmpty {
                emptyState(
                    title: isFiltering
                        ? String(localized: "history.filtered.empty.title", defaultValue: "No Matches")
                        : String(localized: "history.exports.empty.title",
                                 defaultValue: "No Collections Exported"),
                    systemImage: "square.and.arrow.up",
                    detail: isFiltering
                        ? String(localized: "history.filtered.empty.detail",
                                 defaultValue: "No history matches the current filters.")
                        : String(localized: "history.exports.empty.detail",
                                 defaultValue: "Collections you export will appear here."))
            } else {
                ForEach(visibleExports) { row in
                    exportRow(row)
                }
                if snapshot.hasMoreExports { showMoreButton }
            }
        } header: {
            sectionHeader(
                title: String(localized: "history.section.exports",
                              defaultValue: "Collections Exported"),
                shown: snapshot.exports.count,
                total: snapshot.totalExports)
        }
    }

    /// A section header carrying its title and, only when the page is smaller than the scope,
    /// the honest "Showing N of M" line.
    private func sectionHeader(title: String, shown: Int, total: Int) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
            if let showing = HistoryPaneSnapshot.showingCount(shown: shown, of: total) {
                Text(showing)
                    .font(FRUSTheme.captionSmallFont)
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }
        }
    }

    /// Says plainly that nothing new is being recorded, so an empty or stale History is not read
    /// as a bug. Wave R-1 made the "Log Research Sessions" switch govern this store; the label
    /// stays engineering-flavoured by owner decision, so the explaining is done where the
    /// consequence shows up.
    @ViewBuilder
    private var loggingFooter: some View {
        if !loggingEnabled {
            Text(String(localized: "history.logging.off",
                        defaultValue: "Research logging is off, so new activity is not being recorded. Turn it back on in Settings under Research Sessions."))
        }
    }

    /// Raises the page limit. Deliberately a row in the list rather than a toolbar control: it
    /// belongs at the end of the rows it extends.
    private var showMoreButton: some View {
        Button {
            pageLimit += HistoryPaneSnapshot.pageIncrement
        } label: {
            Text(String(localized: "history.showMore", defaultValue: "Show More"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
    }

    private func emptyState(title: String, systemImage: String, detail: String) -> some View {
        ContentUnavailableView(title, systemImage: systemImage, description: Text(detail))
    }

    // MARK: - Rows

    private func documentRow(_ row: HistoryPaneSnapshot.DocumentRow) -> some View {
        Button {
            openDocument(row)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .font(.body)
                    .lineLimit(2)
                    .foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Text(row.volumeId)
                        .font(FRUSTheme.captionFont)
                        .foregroundStyle(.secondary)
                    if let date = row.accessedAt {
                        Text(verbatim: "·").foregroundStyle(.tertiary)
                        Text(date, style: .relative)
                            .font(FRUSTheme.captionFont)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.vertical, 2)
            // `.contentShape` alone does NOT widen a plain-Button List row's tap target; the
            // greedy frame has to come first (measured, #312).
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu { deleteButton { deleteDocument(row) } }
        #if os(iOS)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { deleteDocument(row) } label: {
                Label(String(localized: "history.delete", defaultValue: "Delete"),
                      systemImage: "trash")
            }
        }
        #endif
    }

    private func searchRow(_ row: HistoryPaneSnapshot.SearchRow) -> some View {
        Button {
            runSearch(row)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.queryText)
                    .font(.body)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Text(String(localized: "history.searches.resultCount",
                                defaultValue: "\(row.resultCount) results"))
                        .font(FRUSTheme.captionFont)
                        .foregroundStyle(.secondary)
                    if let date = row.executedAt {
                        Text(verbatim: "·").foregroundStyle(.tertiary)
                        Text(date, style: .relative)
                            .font(FRUSTheme.captionFont)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu { deleteButton { deleteSearch(row) } }
        #if os(iOS)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { deleteSearch(row) } label: {
                Label(String(localized: "history.delete", defaultValue: "Delete"),
                      systemImage: "trash")
            }
        }
        #endif
    }

    /// An export is a record of something that already left the app, so — unlike a visit or a
    /// search — there is nothing to re-run and the row is not a button. Delete is the only action.
    private func exportRow(_ row: HistoryPaneSnapshot.ExportRow) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(row.title)
                .font(.body)
                .lineLimit(2)
                .foregroundStyle(.primary)
            HStack(spacing: 6) {
                Text(row.formatDisplayName)
                    .font(FRUSTheme.captionFont)
                    .foregroundStyle(.secondary)
                Text(verbatim: "·").foregroundStyle(.tertiary)
                Text(String(localized: "history.exports.documentCount",
                            defaultValue: "\(row.documentCount) documents"))
                    .font(FRUSTheme.captionFont)
                    .foregroundStyle(.secondary)
                if let date = row.exportedAt {
                    Text(verbatim: "·").foregroundStyle(.tertiary)
                    Text(date, style: .relative)
                        .font(FRUSTheme.captionFont)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .contextMenu { deleteButton { deleteExport(row) } }
        #if os(iOS)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { deleteExport(row) } label: {
                Label(String(localized: "history.delete", defaultValue: "Delete"),
                      systemImage: "trash")
            }
        }
        #endif
    }

    /// The context-menu delete, shared by all three row kinds.
    ///
    /// No confirmation dialog: a history row is a record of something the reader can recreate by
    /// opening the document or running the search again, and the platform convention for a
    /// history list (Safari's, Mail's) is an immediate delete. The destructive actions this app
    /// *does* confirm — erasing everything, deleting a note — destroy authored work.
    private func deleteButton(_ action: @escaping () -> Void) -> some View {
        Button(role: .destructive, action: action) {
            Label(String(localized: "history.delete", defaultValue: "Delete"),
                  systemImage: "trash")
        }
    }

    // MARK: - Navigation

    /// Re-opens the document: on macOS in this window's provenance host, on iOS as a
    /// scene-addressed hand-off to the Browse tab (the shape `ResearchView.openDocument` uses).
    private func openDocument(_ row: HistoryPaneSnapshot.DocumentRow) {
        let entry = DocumentBrowserEntry(
            documentId: row.documentId,
            volumeId: row.volumeId,
            header: row.title
        )
        #if os(macOS)
        appState.openDocument(entry, from: .tool(.history), using: openWindow)
        #else
        appState.openBrowseDocument(entry, from: sceneID)
        appState.openTab(.browse, from: sceneID)
        #endif
    }

    /// Re-runs the search: on macOS in the Search window (which inherits this window's
    /// provenance), on iOS in the Search tab of this same scene.
    private func runSearch(_ row: HistoryPaneSnapshot.SearchRow) {
        #if os(macOS)
        appState.openSearch(SearchParameters(keywords: row.queryText), from: nil)
        appState.bindTool(.search, to: appState.provenance(of: .history))
        openWindow(id: "frus.search")
        bringMacWindowToFront(id: "frus.search")   // #369 BUG-9: match the sibling producers
        #else
        appState.openSearch(SearchParameters(keywords: row.queryText), from: sceneID)
        appState.openTab(.search, from: sceneID)
        #endif
    }

    // MARK: - Mutations

    private func deleteDocument(_ row: HistoryPaneSnapshot.DocumentRow) {
        // `entryID`, not `id`: the row's own identity is display-only (see `HistoryRowID`), and
        // the delete removes every copy sharing the entry id.
        HistoryTrailAdmin.deleteDocumentVisit(id: row.entryID, in: modelContext)
        // Re-read whether or not the entry was found: a `false` return means the snapshot is
        // stale, which is precisely when a refresh is most useful.
        refresh()
    }

    private func deleteSearch(_ row: HistoryPaneSnapshot.SearchRow) {
        HistoryTrailAdmin.deleteSearch(id: row.entryID, in: modelContext)
        refresh()
    }

    private func deleteExport(_ row: HistoryPaneSnapshot.ExportRow) {
        HistoryTrailAdmin.deleteExport(id: row.entryID, in: modelContext)
        refresh()
    }

    // MARK: - State

    private func refresh() {
        snapshot = HistoryPaneSnapshot.fetch(from: modelContext, scope: scope, limit: pageLimit)
        // A scope can disappear from under the picker — a project deleted in another window, or
        // a CloudKit import that removed it. Fall back to the global scope rather than showing an
        // empty list under a selection whose menu item no longer exists.
        if case .project(let id) = scope, !snapshot.projects.contains(where: { $0.id == id }) {
            scope = .all
        }
    }
}
