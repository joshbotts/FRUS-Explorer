// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

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
///   1.6 — Authoring Phase 1: import fileImporter narrowed from `.data` to the declared
///          `.fruscollection` UTI
///   1.7 — Authoring Phase 1 shell (iOS): the editor is pushed onto the tab's
///          NavigationStack (`navigationDestination`) instead of presented as a sheet
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
    /// Drives the `.fruscollection` file importer.
    @State private var isImporting = false
    /// Non-nil to present an import-failure alert.
    @State private var importError: String? = nil
    /// Non-nil to present a smart-collection snapshot-failure alert.
    @State private var snapshotError: String? = nil

    /// User override of the active-project filter, toggled from `projectFilterBanner`.
    ///
    /// Defaults to `true` (issue #213): the Collection Manager opens showing collections
    /// from *every* project, and the user may narrow to the active project via the banner's
    /// "Scope to …" button. The choice is ephemeral `@State` — it resets to the all-project
    /// default whenever the view is recreated (e.g. the window is reopened), so a transient
    /// "Scope to project" choice doesn't silently persist across sessions.
    @State private var showAllCollections = Collection.managerDefaultShowAllCollections

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
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        isImporting = true
                    } label: {
                        Label(String(localized: "collections.toolbar.import",
                                     defaultValue: "Import Collection…"),
                              systemImage: "square.and.arrow.down")
                    }
                }
            }
            // iOS: the editor is a pushed screen — a place, not a sheet (Authoring
            // Phase 1 shell). Non-iOS presentation contexts keep the modal sheet.
            #if os(iOS)
            .navigationDestination(isPresented: $isCreating) {
                CollectionEditorView(collection: nil, presentationStyle: .pushed)
            }
            .navigationDestination(item: $collectionToEdit) { collection in
                CollectionEditorView(collection: collection, presentationStyle: .pushed)
            }
            #else
            .sheet(isPresented: $isCreating) {
                CollectionEditorView(collection: nil)
            }
            .sheet(item: $collectionToEdit) { collection in
                CollectionEditorView(collection: collection)
            }
            #endif
            .fileImporter(isPresented: $isImporting,
                          allowedContentTypes: [.fruscollection],
                          allowsMultipleSelection: false) { result in
                importCollection(from: result)
            }
            .alert(String(localized: "collections.import.error.title",
                          defaultValue: "Couldn’t Import Collection"),
                   isPresented: Binding(get: { importError != nil },
                                        set: { if !$0 { importError = nil } })) {
                Button(String(localized: "collections.import.error.ok", defaultValue: "OK"),
                       role: .cancel) { importError = nil }
            } message: {
                Text(importError ?? "")
            }
            .alert(String(localized: "collection.snapshot.error.title",
                          defaultValue: "Couldn’t Create Snapshot"),
                   isPresented: Binding(get: { snapshotError != nil },
                                        set: { if !$0 { snapshotError = nil } })) {
                Button(String(localized: "collections.import.error.ok", defaultValue: "OK"),
                       role: .cancel) { snapshotError = nil }
            } message: {
                Text(snapshotError ?? "")
            }
        }
    }

    /// Resolves a smart collection's saved search now and materializes the results into a new
    /// static collection (D8), then opens it. Non-destructive: the smart collection is untouched.
    private func snapshotSmartCollection(_ collection: Collection) async {
        guard let searchId = collection.savedSearchId else { return }
        guard let searchService = appState.searchService else {
            snapshotError = String(localized: "export.smart.noSearchService",
                                   defaultValue: "Search service unavailable. Please try again.")
            return
        }
        let descriptor = FetchDescriptor<SavedSearch>(predicate: #Predicate { $0.id == searchId })
        guard let savedSearch = try? modelContext.fetch(descriptor).first else {
            snapshotError = String(localized: "export.smart.missingSearch",
                                   defaultValue: "The linked saved search could not be found. It may have been deleted.")
            return
        }
        do {
            let results = try await searchService.search(
                parameters: savedSearch.searchParameters,
                limit: SearchViewModel.searchHardLimit)
            let refs = results.map { (documentId: $0.documentId, volumeId: $0.volumeId) }
            let snapshot = SmartCollectionSnapshot.create(from: collection, results: refs, into: modelContext)
            if let pid = appState.activeProjectId, !snapshot.projectIds.contains(pid) {
                snapshot.projectIds.append(pid)
            }
            try modelContext.save()
            collectionToEdit = snapshot
        } catch {
            snapshotError = error.localizedDescription
        }
    }

    /// Imports a user-picked `.fruscollection` file, then opens the reconstructed collection.
    private func importCollection(from result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importError = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let imported = try NativeCollectionSerializer.importCollection(from: url, into: modelContext)
                // Scope the import to the active project (as new collections are) so it isn't
                // hidden by the active-project filter; imported files carry no projectIds.
                if let pid = appState.activeProjectId { imported.projectIds = [pid] }
                try modelContext.save()
                collectionToEdit = imported
            } catch {
                importError = error.localizedDescription
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
                    .contextMenu {
                        Button {
                            _ = collection.duplicate(in: modelContext)
                            try? modelContext.save()
                        } label: {
                            Label(String(localized: "collection.duplicate.action", defaultValue: "Duplicate"),
                                  systemImage: "plus.square.on.square")
                        }
                        Divider()
                        Button {
                            appState.pendingWordCloud = .collection(id: collection.id)
                        } label: {
                            Label { Text(String(localized: "collection.wordCloud",
                                                defaultValue: "Word Cloud")) }
                                icon: { Image(systemName: WordCloudGlyph.symbol) }
                        }
                        if collection.savedSearchId != nil {
                            Divider()
                            Button {
                                Task { await snapshotSmartCollection(collection) }
                            } label: {
                                Label(String(localized: "collection.snapshot.action",
                                             defaultValue: "Create Static Snapshot"),
                                      systemImage: "camera")
                            }
                        }
                    }
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
        Collection.visibleCollections(allCollections,
                                      activeProjectId: appState.activeProjectId,
                                      showAll: showAllCollections)
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
            GeneratedSummary.deleteHeadnoteDrafts(for: c, in: modelContext)
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
