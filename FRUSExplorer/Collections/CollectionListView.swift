// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - CollectionListView

/// Displays all `Collection` records visible in the current project context.
///
/// ## Filtering
/// When `activeProjectId` is non-nil, only collections whose `projectIds`
/// contains that ID are shown by default, and a banner above the list explains
/// the filter and offers a "Show All" button (see `projectFilterBanner`) — the
/// `ResearchView` "By Collection" sidebar queries `Collection` directly with no
/// such filter, so without this banner a collection visible there could appear
/// to have vanished from this list with no explanation. Tapping "Show All" sets
/// `showAllCollections = true`, which the banner then reflects with a "Scope to
/// Project" button to restore the filter. When `activeProjectId` is nil, all
/// collections are shown unconditionally (global view; no banner).
///
/// ## Navigation
/// Tapping a row navigates to `CollectionEditorView` for that collection.
/// The "+" toolbar button creates a new collection and navigates to its editor.
///
/// ## Deletion
/// Swipe-to-delete removes the collection and all its entries. Entries are deleted
/// explicitly before the parent collection because `deleteRule: .nullify` is used for
/// CloudKit compatibility (cascade rules are not supported by CloudKit).
///
/// Version history:
///   1.0 — Session 22: initial implementation
///   1.1 — Session 35: macOS compatibility — guard `.insetGrouped` list style
///   1.2 — Session 55: add Done toolbar button on macOS (previously no close control)
///   1.3 — Add `showDoneButton` parameter; set to `false` when hosted in a Window scene
///   1.4 — Session 89: manual entry deletion before collection delete (deleteRule .nullify)
///   1.5 — Session 2026-06-07: project-filter banner with a "Show All" override —
///          previously the active-project filter was silent, so a collection visible
///          in `ResearchView` (which queries `Collection` with no project filter)
///          could appear to be missing here with no indication why or how to see it
struct CollectionListView: View {

    /// Pass `false` when this view is the root content of a `Window` scene; in that
    /// context the OS window chrome (red button / ⌘W) already provides dismissal.
    var showDoneButton: Bool = true

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    #if !os(iOS)
    @Environment(\.dismiss) private var dismiss
    #endif

    @Query(sort: \Collection.lastModified, order: .reverse) private var allCollections: [Collection]
    @Query(sort: \Project.name) private var allProjects: [Project]

    @State private var collectionToEdit: Collection? = nil
    @State private var isCreating = false

    /// User override of the active-project filter, toggled from `projectFilterBanner`.
    /// Resets implicitly whenever the view is recreated (e.g. the window is reopened),
    /// so a "Show All" choice doesn't silently persist across sessions and surprise the
    /// user the next time they're scoped to a different project.
    @State private var showAllCollections = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                projectFilterBanner
                Group {
                    if filteredCollections.isEmpty {
                        emptyState
                    } else {
                        collectionList
                    }
                }
            }
            .navigationTitle(String(localized: "collections.nav.title",
                                    defaultValue: "Collections"))
            .toolbar {
                #if !os(iOS)
                if showDoneButton {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "collections.toolbar.done",
                                      defaultValue: "Done")) {
                            dismiss()
                        }
                    }
                }
                #endif
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isCreating = true
                    } label: {
                        Label(String(localized: "collections.toolbar.new",
                                     defaultValue: "New Collection"),
                              systemImage: "plus")
                    }
                    .accessibilityLabel(String(localized: "collections.toolbar.new.accessibility",
                                               defaultValue: "Create new collection"))
                }
            }
            .sheet(isPresented: $isCreating) {
                CollectionEditorView(collection: nil)
            }
            .sheet(item: $collectionToEdit) { collection in
                CollectionEditorView(collection: collection)
            }
        }
    }

    // MARK: - Subviews

    private var collectionList: some View {
        List {
            ForEach(filteredCollections) { collection in
                CollectionRow(collection: collection)
                    .contentShape(Rectangle())
                    .onTapGesture { collectionToEdit = collection }
            }
            .onDelete { indexSet in
                deleteCollections(at: indexSet)
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(
                String(localized: "collections.empty.title", defaultValue: "No Collections"),
                systemImage: "tray"
            )
        } description: {
            Text(String(localized: "collections.empty.description",
                        defaultValue: "Create a collection to group documents for export."))
        } actions: {
            Button(String(localized: "collections.empty.action",
                          defaultValue: "New Collection")) {
                isCreating = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Filtering

    private var filteredCollections: [Collection] {
        guard let projectId = appState.activeProjectId, !showAllCollections else {
            return allCollections
        }
        return allCollections.filter { $0.projectIds.contains(projectId) }
    }

    /// The `Project` named by `appState.activeProjectId`, resolved against `allProjects`
    /// for display in `projectFilterBanner`. `nil` both when there's no active project
    /// and (defensively) when the active project's record can't be found — e.g. it was
    /// deleted on another device and the deletion hasn't synced down yet.
    private var activeProject: Project? {
        guard let projectId = appState.activeProjectId else { return nil }
        return allProjects.first { $0.id == projectId }
    }

    /// Display name for `activeProject`, falling back to a localized placeholder for
    /// untitled projects or — defensively — unresolved IDs (see `activeProject`).
    private var activeProjectDisplayName: String {
        guard let project = activeProject, !project.name.isEmpty else {
            return String(localized: "collections.filterBanner.untitledProject",
                          defaultValue: "Untitled Project")
        }
        return project.name
    }

    /// Count of collections hidden by the active-project filter — i.e. collections that
    /// exist but aren't associated with `activeProjectId`. Drives whether the banner
    /// offers a "Show All" button (no point offering it when nothing is hidden) and the
    /// wording of the filtered-state message.
    private var hiddenCollectionCount: Int {
        guard let projectId = appState.activeProjectId else { return 0 }
        return allCollections.filter { !$0.projectIds.contains(projectId) }.count
    }

    // MARK: - Project Filter Banner

    /// Informs the user when this list is currently scoped to the active project, and
    /// lets them override that scoping to see every collection regardless of project
    /// association (and back again).
    ///
    /// Exists because `filteredCollections` silently hides collections that aren't
    /// associated with `appState.activeProjectId` — and `ResearchView`'s "By Collection"
    /// sidebar queries `Collection` directly with no such filter, so a collection visible
    /// there could appear to have vanished from this list with no explanation. Hidden
    /// entirely when there's no active project (global view; nothing to explain).
    @ViewBuilder
    private var projectFilterBanner: some View {
        if appState.activeProjectId != nil {
            HStack(spacing: 8) {
                Image(systemName: showAllCollections ? "tray.full" : "line.3.horizontal.decrease.circle")
                    .foregroundStyle(.secondary)
                    .imageScale(.small)

                if showAllCollections {
                    Text(String(localized: "collections.filterBanner.showingAll",
                                defaultValue: "Showing collections from every project, including ones outside “\(activeProjectDisplayName)”."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Button(String(localized: "collections.filterBanner.scopeToProject",
                                  defaultValue: "Scope to “\(activeProjectDisplayName)”")) {
                        showAllCollections = false
                    }
                    .font(.caption)
                } else {
                    let hidden = hiddenCollectionCount
                    Text(hidden > 0
                         ? String(localized: "collections.filterBanner.filtered.withHidden",
                                  defaultValue: "Showing collections for “\(activeProjectDisplayName)” — \(hidden) other collection\(hidden == 1 ? "" : "s") hidden.")
                         : String(localized: "collections.filterBanner.filtered.noHidden",
                                  defaultValue: "Showing collections for “\(activeProjectDisplayName)”."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if hidden > 0 {
                        Spacer(minLength: 8)
                        Button(String(localized: "collections.filterBanner.showAll",
                                      defaultValue: "Show All")) {
                            showAllCollections = true
                        }
                        .font(.caption)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.1))
        }
    }

    // MARK: - Actions

    private func deleteCollections(at indexSet: IndexSet) {
        for index in indexSet {
            let c = filteredCollections[index]
            for entry in c.documentEntries ?? [] { modelContext.delete(entry) }
            modelContext.delete(c)
        }
        try? modelContext.save()
    }
}

// MARK: - CollectionRow

private struct CollectionRow: View {
    let collection: Collection

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(collection.name.isEmpty
                 ? String(localized: "collections.row.untitled", defaultValue: "Untitled Collection")
                 : collection.name)
                .font(.body)

            HStack(spacing: 6) {
                let count = collection.documentEntries?.count ?? 0
                Text(String(localized: "collections.row.count",
                            defaultValue: "\(count) document\(count == 1 ? "" : "s")"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let date = collection.lastModified {
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
