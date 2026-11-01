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
/// ## Rename, duplicate and delete (#1823)
/// A row's menu (touch and hold) offers Rename, Duplicate, Word Cloud and, on a smart collection,
/// Create Static Snapshot, then Delete. Rename asks for the name in an alert
/// (`collectionRenameAlert`); an empty name keeps the old one. Delete is reached three ways — a
/// row's swipe, which no longer completes on a full swipe; its menu; and Edit, which chooses several
/// rows for the toolbar's Delete — and every route asks first (`collectionDeleteConfirmation`),
/// because a collection's headings, note blocks and headnotes go with it on every device. A row's
/// dialog hangs from the row, and Edit's from its Delete button, so that on an iPad the popover points
/// at what asked (#1357's rule). The delete itself is `Collection.deleteWithChildren(in:)`: the
/// relationship is `.nullify` for CloudKit, so entries are deleted explicitly.
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
///   1.8 — 2026-09-23: #1358 — a row's "N documents" reads `Collection.documentCount`; it
///          counted every entry, so six documents under two headings and a prose block read
///          "9 documents"
///   1.9 — 2026-10-15: #1619 — a smart collection's row reads "Smart collection"
///          (`SmartCollectionRule.listLabel`) where it printed its count of ignored entries
///   1.10 — 2026-10-21: #1761 — at an accessibility text size a row puts what the collection holds
///          above its date, so "Smart collection" no longer breaks inside a word at the largest size
///   1.11 — 2026-10-27 (FRUS Explorer Light, S18b): Snapshot runs the saved search through FRUSCoreKit's
///          `SmartCollectionSnapshot.documentRefs`, at the same ceiling
///   1.12 — 2026-11-01: #1823 — a row's menu gains Rename and Delete; swipe, menu and Edit's Delete all
///          ask first; Edit chooses several collections to delete at once
struct CollectionListView: View {

    /// Pass `false` when this view is the root content of a `Window` scene; in that
    /// context the OS window chrome (red button / ⌘W) already provides dismissal.
    var showDoneButton: Bool = true

    @Environment(AppState.self) private var appState
    /// #338 step 2: this scene's identity, so a word-cloud hand-off is addressed to THIS window.
    @Environment(\.sceneID) private var sceneID
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
    /// The collection the Rename alert renames; `nil` while the alert is closed (#1823).
    @State private var renaming: Collection? = nil
    /// The Rename alert's field, seeded with the collection's name as the alert opens.
    @State private var renameText = ""
    /// The collection whose row is asking whether to delete it — its swipe or its menu's Delete asked (#1823). The
    /// dialog hangs from that row.
    @State private var pendingDeletionId: UUID? = nil
    #if os(iOS)
    /// Whether the list is in Edit, where rows are chosen to delete several collections at once (#1823).
    @State private var isEditing = false
    /// The collections chosen in Edit, by id.
    @State private var selection = Set<UUID>()
    /// Whether Edit's Delete is asking whether to delete the chosen collections.
    @State private var isConfirmingBulkDeletion = false
    #endif

    /// User override of the active-project filter, toggled from `projectFilterBanner`.
    ///
    /// Defaults to `true` (issue #213): the Collection Manager opens showing collections
    /// from *every* project, and the user may narrow to the active project via the banner's
    /// "Scope to …" button. The choice is ephemeral `@State` — it resets to the all-project
    /// default whenever the view is recreated (e.g. the window is reopened), so a transient
    /// "Scope to project" choice doesn't silently persist across sessions.
    @State private var showAllCollections = Collection.managerDefaultShowAllCollections

    #if os(iOS)
    /// #369 BUG-12: applies (once) a `pendingCollectionSelection` hand-off — pushes the imported
    /// collection's editor so the user lands on it after an open-with import. macOS has the twin in
    /// `MacCollectionManagerView`; this is iOS-only to avoid a double-consume race with that window.
    ///
    /// #752 / M-25: reads the **scene-addressed** slot, so an open-with delivered to one window
    /// surfaces there rather than in whichever window's Collections tab happened to be mounted.
    /// `orAnyWindow` keeps the wildcard working for a producer with no scene to name.
    private func consumePendingCollectionSelection() {
        guard let sceneID,
              let id = appState.consumeHandoff(\.pendingCollectionSelectionScene,
                                               for: sceneID, orAnyWindow: true) else { return }
        if let collection = allCollections.first(where: { $0.id == id }) {
            collectionToEdit = collection
        }
    }
    #endif

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
                #if os(iOS)
                // #1823: Edit, while there is a collection to choose (or Edit is on, so Done stays reachable).
                if isEditing || !filteredCollections.isEmpty {
                    ToolbarItem(placement: .topBarLeading) { editButton }
                }
                #endif
                ToolbarItem(placement: .primaryAction) {
                    #if os(iOS)
                    if isEditing {
                        bulkDeleteButton
                    } else {
                        newCollectionButton
                    }
                    #else
                    newCollectionButton
                    #endif
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
            // #369 BUG-12: iOS consumer for the open-with import hand-off (macOS consumes it in
            // MacCollectionManagerView; iOS previously had no reader, so the tab switched but the
            // imported collection was never surfaced). `.task` covers a fresh mount, `.onChange` a
            // live one — mirroring the macOS pattern.
            .task { consumePendingCollectionSelection() }
            .onChange(of: appState.pendingCollectionSelectionScene) { _, handoff in
                if handoff != nil { consumePendingCollectionSelection() }
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
            .collectionRenameAlert($renaming, name: $renameText)
            #if os(iOS)
            // #1823: Edit ends when the last collection goes, so the list never sits in Edit with nothing to choose.
            .onChange(of: filteredCollections.isEmpty) { _, isEmpty in
                if isEmpty { endEditing() }
            }
            #endif
        }
    }

    /// Resolves a smart collection's saved search now and materializes the results into a new
    /// static collection (D8), then opens it. Non-destructive: the smart collection is untouched.
    private func snapshotSmartCollection(_ collection: Collection) async {
        guard let searchId = collection.savedSearchId else { return }
        guard let searchService = appState.searchService else {
            snapshotError = String(localized: "export.smart.noSearchService.v2",
                                   defaultValue: "Search is not ready yet. Try again in a moment.")
            return
        }
        let descriptor = FetchDescriptor<SavedSearch>(predicate: #Predicate { $0.id == searchId })
        guard let savedSearch = try? modelContext.fetch(descriptor).first else {
            snapshotError = String(localized: "export.smart.missingSearch",
                                   defaultValue: "The linked saved search could not be found. It may have been deleted.")
            return
        }
        do {
            // The saved search's run is FRUSCoreKit's (FRUS Explorer Light, S18b), at the iOS search's ceiling.
            let refs = try await SmartCollectionSnapshot.documentRefs(
                parameters: savedSearch.searchParameters, searchService: searchService,
                limit: SearchViewModel.searchHardLimit)
                .map { (documentId: $0.documentId, volumeId: $0.volumeId) }
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
                // The notes it brought are searchable at once, not at the next launch.
                if let pipeline = appState.indexingPipeline {
                    let context = modelContext
                    Task {
                        await NativeCollectionSerializer.indexImportedNotes(of: imported, in: context,
                                                                            pipeline: pipeline)
                    }
                }
                collectionToEdit = imported
            } catch {
                importError = error.localizedDescription
            }
        }
    }

    // MARK: - Subviews

    private var collectionList: some View {
        #if os(iOS)
        // #1823: Edit chooses rows (the List's own selection, by id), and the toolbar's Delete deletes them.
        List(selection: isEditing ? $selection : nil) {
            ForEach(filteredCollections) { collection in row(collection) }
        }
        // On the List, never a Section (the measured reorder trap), and constant: the List's swipe must not turn Edit on.
        .environment(\.editMode, .constant(isEditing ? .active : .inactive))
        .listStyle(.insetGrouped)
        #else
        List {
            ForEach(filteredCollections) { collection in row(collection) }
        }
        .listStyle(.inset)
        #endif
    }

    /// One collection's row: a tap opens its editor (in Edit the List chooses the row instead), a swipe or the menu's
    /// Delete asks before deleting it, and the menu renames, duplicates, opens a word cloud and snapshots a smart one.
    @ViewBuilder
    private func row(_ collection: Collection) -> some View {
        CollectionRow(collection: collection)
            .contentShape(Rectangle())
            // Off in Edit (`.subviews` turns this gesture off and leaves the List's own row selection), where a tap on
            // the row's text would otherwise open the editor rather than choose the row.
            .gesture(TapGesture().onEnded { collectionToEdit = collection },
                     including: isEditingList ? .subviews : .all)
            // Asks rather than deleting on a full swipe (#1823): a collection's headings and note blocks go with it.
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    pendingDeletionId = collection.id
                } label: {
                    Label(CollectionDeletion.action, systemImage: "trash")
                }
            }
            .contextMenu {
                Button {
                    renameText = collection.name
                    renaming = collection
                } label: {
                    Label(String(localized: "common.rename", defaultValue: "Rename"), systemImage: "pencil")
                }
                Button {
                    _ = collection.duplicate(in: modelContext)
                    try? modelContext.save()
                } label: {
                    Label(String(localized: "collection.duplicate.action", defaultValue: "Duplicate"),
                          systemImage: "plus.square.on.square")
                }
                Divider()
                Button {
                    appState.openWordCloud(.collection(id: collection.id), from: sceneID)
                } label: {
                    Label { Text(String(localized: "collection.wordCloud",
                                        defaultValue: "Word Cloud")) }
                        icon: { Image(systemName: WordCloudGlyph.symbol) }
                }
                if collection.savedSearchId != nil {
                    Button {
                        Task { await snapshotSmartCollection(collection) }
                    } label: {
                        Label(String(localized: "collection.snapshot.action",
                                     defaultValue: "Create Static Snapshot"),
                              systemImage: "camera")
                    }
                }
                Divider()
                Button(role: .destructive) {
                    pendingDeletionId = collection.id
                } label: {
                    Label(CollectionDeletion.action, systemImage: "trash")
                }
            }
            // On the row, so an iPad's popover points at the row that asked (#1357's rule); the swipe button cannot be
            // the source, since the swipe closes when it is tapped.
            .collectionDeleteConfirmation(
                isPresented: Binding(get: { pendingDeletionId == collection.id },
                                     set: { if !$0, pendingDeletionId == collection.id { pendingDeletionId = nil } }),
                deleting: [collection]
            ) { doomed in
                delete(doomed)
            }
    }

    /// Whether the list is in Edit — always `false` where Edit does not exist.
    private var isEditingList: Bool {
        #if os(iOS)
        isEditing
        #else
        false
        #endif
    }

    /// The toolbar's New Collection button.
    private var newCollectionButton: some View {
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

    #if os(iOS)
    /// Edit / Done (#1823): Edit chooses rows to delete several collections at once; Done ends it and forgets the choice.
    private var editButton: some View {
        Button {
            if isEditing {
                endEditing()
            } else {
                withAnimation { isEditing = true }
            }
        } label: {
            Text(isEditing
                 ? String(localized: "collections.toolbar.edit.done", defaultValue: "Done")
                 : String(localized: "collections.toolbar.edit", defaultValue: "Edit"))
                .fontWeight(isEditing ? .semibold : .regular)
        }
    }

    /// The collections chosen in Edit, in the list's order — only those the list still shows.
    private var chosenCollections: [Collection] {
        filteredCollections.filter { selection.contains($0.id) }
    }

    /// Edit's Delete: deletes the chosen collections once the reader confirms. Its dialog hangs from the button, so an
    /// iPad's popover points at it (#1357's rule).
    private var bulkDeleteButton: some View {
        Button(role: .destructive) {
            isConfirmingBulkDeletion = true
        } label: {
            Text(CollectionDeletion.action)
        }
        .disabled(chosenCollections.isEmpty)
        .collectionDeleteConfirmation(isPresented: $isConfirmingBulkDeletion,
                                      deleting: chosenCollections) { doomed in
            delete(doomed)
            endEditing()
        }
    }

    /// Leaves Edit and forgets the rows it chose.
    private func endEditing() {
        withAnimation { isEditing = false }
        selection = []
    }
    #endif

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

    /// Deletes `doomed`, which the reader has just confirmed, and drops them from Edit's choice.
    private func delete(_ doomed: [Collection]) {
        pendingDeletionId = nil
        #if os(iOS)
        selection.subtract(doomed.map(\.id))
        #endif
        CollectionDeletion.delete(doomed, in: modelContext)
    }
}

// MARK: - CollectionRow

private struct CollectionRow: View {
    let collection: Collection

    /// The reader's text size: at an accessibility size what the collection holds and its date stack.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // The name as every list row reads it, trimmed and with the shared fallback (#1464).
            Text(CollectionEditorNaming.listName(savedName: collection.name))
                .font(.body)

            // What the collection holds and when it changed: side by side, and one above the other at an accessibility
            // text size. Side by side at the largest on an iPhone 17, the date left "Smart collection" so little room
            // that it broke inside its first word, "Sm" / "art collec-tion" (#1761).
            let stacked = dynamicTypeSize.isAccessibilitySize
            let layout = stacked
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
                : AnyLayout(HStackLayout(spacing: 6))
            layout {
                if collection.savedSearchId != nil {
                    // #1619: a smart collection's documents come from its saved search, so its count of hand-added
                    // entries, which everything it produces ignores, read "0 documents" for a search of hundreds.
                    Label(SmartCollectionRule.listLabel, systemImage: "bolt.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        // As tall as its words need, so it wraps between them: stacked at the largest text size it was
                        // given one line and cut to "Smart collec…" (iPhone 17, iOS 27.0; #1761).
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    // Documents, not entries: headings and prose blocks are not documents (#1358).
                    let count = collection.documentCount
                    Text(String(localized: "collections.row.count",
                                defaultValue: "\(count) document\(count == 1 ? "" : "s")"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let date = collection.lastModified {
                    if !stacked {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
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

// MARK: - Rename and delete, shared with the Mac Collections window (#1823)

extension View {
    /// Presents the Rename Collection alert while `renaming` names a collection: a field holding `name`, which the caller
    /// seeds with the collection's name as it sets `renaming`, and Save, which commits it through
    /// `CollectionEditorCommit.rename` (trimmed, and an empty field keeps the old name) and saves.
    ///
    /// The iPhone and iPad Collections list's Rename and the Mac Collections window's Collection ▸ Rename Collection… both
    /// present it.
    func collectionRenameAlert(_ renaming: Binding<Collection?>, name: Binding<String>) -> some View {
        modifier(CollectionRenameAlert(renaming: renaming, name: name))
    }

    /// Asks before `collections` are deleted, with `CollectionDeletion`'s title, message and Delete; `onDelete` runs with
    /// them when the reader confirms, and does the deleting (`CollectionDeletion.delete(_:in:)`).
    ///
    /// Every surface that deletes a collection asks through this (#1823). Hang it where the delete was asked: on an iPad
    /// a confirmation dialog is a popover whose arrow points at the view that carries it (#1357).
    func collectionDeleteConfirmation(isPresented: Binding<Bool>, deleting collections: [Collection],
                                      onDelete: @escaping ([Collection]) -> Void) -> some View {
        confirmationDialog(CollectionDeletion.title(for: collections), isPresented: isPresented,
                           titleVisibility: .visible, presenting: collections) { doomed in
            Button(CollectionDeletion.action, role: .destructive) { onDelete(doomed) }
            Button(String(localized: "common.cancel", defaultValue: "Cancel"), role: .cancel) {}
        } message: { doomed in
            Text(CollectionDeletion.message(count: doomed.count))
        }
    }
}

/// The Rename Collection alert behind `View.collectionRenameAlert(_:name:)`, which reads the context it saves from the
/// environment.
private struct CollectionRenameAlert: ViewModifier {
    /// The collection being renamed; `nil` closes the alert.
    @Binding var renaming: Collection?
    /// The alert's field.
    @Binding var name: String
    @Environment(\.modelContext) private var modelContext

    func body(content: Content) -> some View {
        content.alert(String(localized: "collection.rename.title", defaultValue: "Rename Collection"),
                      isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } }),
                      presenting: renaming) { collection in
            TextField(String(localized: "collection.editor.name.placeholder", defaultValue: "Collection Name"),
                      text: $name)
            Button(String(localized: "common.cancel", defaultValue: "Cancel"), role: .cancel) {}
            Button(String(localized: "common.save", defaultValue: "Save")) {
                if CollectionEditorCommit.rename(name, to: collection) { try? modelContext.save() }
            }
        }
    }
}
