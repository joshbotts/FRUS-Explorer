// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - ProjectHomeRequest

/// The window value for the macOS Project Home window group (#377 Phase 1).
///
/// Value-based (like `NoteComposerRequest` / `DocumentWindowID`) so the window keeps
/// off the macOS Window menu and identity is the project it shows: opening Project
/// Home for the same project focuses the existing window, while a different project
/// opens its own — a multi-project researcher can keep several project homes open.
/// A dedicated type (rather than a raw `UUID`) makes the `WindowGroup(for:)` target
/// unambiguous.
///
/// Version history:
///   1.0 — #377 Phase 1: initial implementation
struct ProjectHomeRequest: Codable, Hashable {
    /// The `Project.id` this window's dashboard shows.
    let projectId: UUID
}

// MARK: - ProjectHomeView

/// The **Project Home** dashboard (#377 Phase 1) — a project's activity workspace.
///
/// Surfaces the project's research question (inline-editable) and date focus, a live
/// activity summary (collections / notes / documents visited / searches), a reserved
/// slot for the Phase-3 "Project Leads" discovery feed, recent activity, and quick jumps.
///
/// Data comes from reactive `@Query`s filtered to the active project in memory (the
/// same approach `GlobalContextViewModel` uses, since SwiftData `#Predicate` support
/// for "`[UUID]` contains" is unreliable), so counts refresh live while the window is
/// open. Presented as the `frus.projectHome` window on macOS (Research ▸ Project
/// Home, ⌘P) and as a screen on iOS/iPadOS.
///
/// Version history:
///   1.0 — #377 Phase 1: initial implementation
struct ProjectHomeView: View {

    /// The project this dashboard shows.
    let projectId: UUID

    /// Called just before this view hands off to another surface (opening a document, or a quick
    /// action to Collections/Research/Search). A **modal** presenter — the iOS Research-tab sheet —
    /// passes `{ dismiss the sheet }` so the hand-off isn't left invisibly behind the modal;
    /// the non-modal presenters (the macOS `frus.projectHome` window and the Settings-tab push)
    /// leave it `nil` and stay put. (#377 Phase 1 iOS follow-up.)
    var onNavigateAway: (() -> Void)? = nil

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    // Reactive activity — fetched whole, filtered to the project in `summary`.
    @Query(sort: \Project.name) private var projects: [Project]
    @Query(sort: \ResearchNote.lastModified, order: .reverse) private var allNotes: [ResearchNote]
    @Query(sort: \Collection.lastModified, order: .reverse) private var allCollections: [Collection]
    @Query(sort: \ReadingHistoryEntry.accessedAt, order: .reverse) private var allVisits: [ReadingHistoryEntry]
    @Query(sort: \SearchHistoryEntry.executedAt, order: .reverse) private var allSearches: [SearchHistoryEntry]

    /// Local draft of the research question, loaded from the model on appearance and
    /// saved live on every edit (like the collection editors) — so an in-progress edit
    /// is never lost if the window closes before the field would have "committed".
    @State private var questionDraft: String = ""

    private var project: Project? { projects.first { $0.id == projectId } }

    private var summary: ProjectHomeSummary {
        ProjectHomeSummary(
            notes:       allNotes.filter { $0.projectIds.contains(projectId) },
            collections: allCollections.filter { $0.projectIds.contains(projectId) },
            visits:      allVisits.filter { $0.projectId == projectId },
            searches:    allSearches.filter { $0.projectId == projectId }
        )
    }

    var body: some View {
        ScrollView {
            if let project {
                VStack(alignment: .leading, spacing: 28) {
                    header(project)
                    summarySection
                    leadsSection
                    recentSection
                    quickActions
                }
                .padding(24)
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ContentUnavailableView(
                    String(localized: "project.home.missing.title", defaultValue: "No Project Selected"),
                    systemImage: "folder",
                    description: Text(String(localized: "project.home.missing.detail",
                                             defaultValue: "Choose a project from the project picker to see its workspace."))
                )
                .padding(.top, 80)
            }
        }
        .navigationTitle(project?.name ?? String(localized: "project.home.title", defaultValue: "Project Home"))
        .task(id: projectId) { questionDraft = project?.researchQuestion ?? "" }
    }

    // MARK: - Header (name + research question + focus)

    @ViewBuilder
    private func header(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(project.name)
                .font(.largeTitle.weight(.semibold))

            TextField(
                String(localized: "project.home.question.placeholder",
                       defaultValue: "What is this project's research question?"),
                text: $questionDraft,
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .font(.title3)
            .foregroundStyle(.secondary)
            .lineLimit(1...4)
            // Save live — `commitQuestion` no-ops when unchanged, so the initial `.task` load
            // (which sets `questionDraft` to the model's value) never writes a spurious edit.
            .onChange(of: questionDraft) { _, _ in commitQuestion(project) }

            if let range = dateFocusText(project) {
                Label(range, systemImage: "calendar")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
    }

    /// A readable date-focus chip from the project's default date range, or `nil` if unset.
    private func dateFocusText(_ project: Project) -> String? {
        let cal = Calendar.current
        func year(_ date: Date?) -> Int? { date.map { cal.component(.year, from: $0) } }
        switch (year(project.defaultDateRangeStart), year(project.defaultDateRangeEnd)) {
        case let (start?, end?): return "\(start)–\(end)"
        case let (start?, nil):  return String(localized: "project.home.dateFrom", defaultValue: "From \(start)")
        case let (nil, end?):    return String(localized: "project.home.dateTo", defaultValue: "Through \(end)")
        case (nil, nil):         return nil
        }
    }

    /// Writes the draft back to the model only when it actually changed.
    private func commitQuestion(_ project: Project) {
        let trimmed = questionDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let newValue = trimmed.isEmpty ? nil : trimmed
        if project.researchQuestion != newValue {
            project.researchQuestion = newValue
        }
    }

    // MARK: - Activity summary

    private var summarySection: some View {
        let s = summary
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            statTile(s.collectionCount,
                     String(localized: "project.home.stat.collections", defaultValue: "Collections"),
                     "tray.2")
            statTile(s.noteCount,
                     String(localized: "project.home.stat.notes", defaultValue: "Notes"),
                     "note.text")
            statTile(s.documentsVisitedCount,
                     String(localized: "project.home.stat.visited", defaultValue: "Documents Visited"),
                     "book")
            statTile(s.searchCount,
                     String(localized: "project.home.stat.searches", defaultValue: "Searches Run"),
                     "magnifyingglass")
        }
    }

    private func statTile(_ count: Int, _ label: String, _ systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(label).font(.caption).foregroundStyle(.secondary)
            } icon: {
                Image(systemName: systemImage).foregroundStyle(.secondary)
            }
            Text("\(count)")
                .font(.title.weight(.semibold))
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Project Leads slot (Phase 3 placeholder)

    private var leadsSection: some View {
        sectionCard(String(localized: "project.home.leads.title", defaultValue: "Suggested Next")) {
            Label {
                Text(String(localized: "project.home.leads.placeholder",
                            defaultValue: "As you add documents to this project's collections, related documents you haven't gathered yet will surface here."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "sparkles").foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Recent activity

    @ViewBuilder
    private var recentSection: some View {
        let s = summary
        if s.isEmpty {
            sectionCard(String(localized: "project.home.recent.title", defaultValue: "Recent Activity")) {
                Text(String(localized: "project.home.recent.empty",
                            defaultValue: "No activity in this project yet. Read documents, take notes, or build a collection while this project is active and it will appear here."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            if !s.recentVisits.isEmpty {
                sectionCard(String(localized: "project.home.recent.documents", defaultValue: "Recently Read")) {
                    ForEach(s.recentVisits) { visit in
                        recentRow(title: visit.displayTitle ?? "\(visit.volumeId) · \(visit.documentId)",
                                  systemImage: "book") {
                            openDocument(volumeId: visit.volumeId, documentId: visit.documentId,
                                         title: visit.displayTitle)
                        }
                    }
                }
            }
            if !s.recentNotes.isEmpty {
                sectionCard(String(localized: "project.home.recent.notes", defaultValue: "Recent Notes")) {
                    ForEach(s.recentNotes) { note in
                        recentRow(title: noteTitle(note), systemImage: "note.text") {
                            openDocument(volumeId: note.volumeId, documentId: note.documentId, title: nil)
                        }
                    }
                }
            }
            if !s.recentSearches.isEmpty {
                sectionCard(String(localized: "project.home.recent.searches", defaultValue: "Recent Searches")) {
                    ForEach(s.recentSearches) { search in
                        // Display-only in Phase 1; re-run arrives with project-scoped search (Phase 2).
                        Label {
                            HStack {
                                Text(search.queryText.isEmpty
                                     ? String(localized: "project.home.search.untitled", defaultValue: "(no query text)")
                                     : search.queryText)
                                Spacer()
                                Text(String(localized: "project.home.search.results",
                                            defaultValue: "\(search.resultCount) results"))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    private func noteTitle(_ note: ResearchNote) -> String {
        "\(note.volumeId) · \(note.documentId)"
    }

    private func recentRow(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label {
                Text(title).lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
            } icon: {
                Image(systemName: systemImage).foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 3)
    }

    // MARK: - Quick actions

    private var quickActions: some View {
        HStack(spacing: 12) {
            quickButton(String(localized: "project.home.action.collections", defaultValue: "Collections"),
                        "tray.2") { openSurface("frus.collections") }
            quickButton(String(localized: "project.home.action.research", defaultValue: "Research"),
                        "note.text") { openSurface("frus.research") }
            quickButton(String(localized: "project.home.action.search", defaultValue: "Search"),
                        "magnifyingglass") { openSurface("frus.search") }
        }
    }

    private func quickButton(_ title: String, _ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
    }

    // MARK: - Section card

    private func sectionCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Navigation actions

    private func openDocument(volumeId: String, documentId: String, title: String?) {
        let entry = DocumentBrowserEntry(
            documentId: documentId,
            volumeId: volumeId,
            header: title ?? "\(volumeId) · \(documentId)"
        )
        performNavigation {
            #if os(iOS)
            // The document lands in the Browse tab's stack; bring that tab forward so the tap isn't a
            // silent no-op (Project Home is reached from the Settings tab). Mirrors the other callers.
            appState.openTab(.browse, from: nil)
            #endif
            appState.openBrowseDocument(entry, from: nil)
        }
    }

    private func openSurface(_ windowId: String) {
        performNavigation {
            #if os(macOS)
            openWindow(id: windowId)
            bringMacWindowToFront(id: windowId)
            #else
            // AppTab is iOS-only; map the shared window id to the matching tab.
            let tab: AppTab
            switch windowId {
            case "frus.collections": tab = .collections
            case "frus.research":    tab = .research
            case "frus.search":      tab = .search
            default:                 tab = .browse
            }
            appState.openTab(tab, from: nil)
            #endif
        }
    }

    /// Runs a navigation hand-off, dismissing a modal presenter first (if any).
    ///
    /// When there IS a modal presenter (the iOS Research-tab sheet passes `onNavigateAway`), the
    /// hand-off is deferred one main-actor tick so the sheet's dismissal and the tab-switch/document
    /// push don't land in a single SwiftUI update — doing both in one frame trips
    /// "NavigationRequestObserver tried to update multiple times per frame" and the push is dropped
    /// (#431 on-device). The non-modal presenters (macOS window, Settings push) have no dismissal to
    /// collide with, so they run the hand-off synchronously as before.
    private func performNavigation(_ handoff: @escaping @MainActor () -> Void) {
        guard let onNavigateAway else {
            handoff()
            return
        }
        onNavigateAway()
        Task { @MainActor in handoff() }
    }
}
