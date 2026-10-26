// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

#if os(macOS)
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - MacCollectionManagerView

/// Root view for the "Collections" window on macOS.
///
/// Presents a `NavigationSplitView`:
///   - **Sidebar** — list of all collections (filtered to active project); supports
///     selection, deletion via context menu, and creating new collections.
///   - **Detail** — inline editor for the selected collection: editable name and note
///     (auto-saved), reorderable document list, per-document note management, and
///     toolbar actions for Add Documents, Sort by Date, and Export.
///
/// Version history:
///   1.0 — Session 73: initial implementation replacing CollectionListView in the
///          Collections window scene; NavigationSplitView with inline editing.
///   1.1 — Session 74: two-line research note preview added to MacEntryRow beneath
///          volume title; caption2/tertiary styling; fixedSize for correct wrapping
///   1.2 — Session 89: manual entry deletion before collection delete (deleteRule .nullify)
///   1.3 — Session 130: drop outer ScrollView from CollectionDetailPane so the document
///          List fills available window height instead of being fixed to entry-count height
///   1.4 — Session 130: document header (from document_cache) shown in each row;
///          per-row delete button; multi-note support via selectedNoteIds; inline
///          Sort by Date control in Documents section header; toolbar tooltip improvements
///   1.5 — Session 2026-07-02: consumes appState.pendingCollectionSelection so an
///          open-with .fruscollection import lands on the imported collection
///   1.5 — Authoring Phase 1: header/date loading and Sort by Date moved to the shared
///          `CollectionEntryData` (behavior-identical; now also used by the iOS editor);
///          `.unrecognized` entries render as an inert row; import fileImporter narrowed
///          from `.data` to the declared `.fruscollection` UTI
///   1.6 — Authoring Phase 1 shell: Composition moved from a bounded popover to an inline
///          collapsed disclosure at the top of the entries List — inline as the scope asks,
///          but inside the scrolling region so expansion can never grow the fixed header
///          past the window (the constraint that forced the popover)
///   1.7 — Authoring Phase 2b: detail pane gains a toolbar-toggled side-by-side live
///          preview (`CollectionPreviewView`) to the right of the editor column
///   1.8 — Authoring Phase 3: toolbar "Add by Tag" replaced by "Add Documents…"
///          (`CollectionAddDocumentsSheet`: Search | Browse | Citations | Tags, ⇧⌘A);
///          added documents append at the end of the entry list in selection order;
///          `appendEntries` allows duplicates (A4) via the shared
///          `CollectionDocumentDiscovery.appendEntries`, with repeated documents
///          badged "Also in collection" on their rows
///   1.9 — Authoring Phase 4 (editor step): the entries List renders the derived outline
///          (rows indent by `CollectionOutline` depth; headings step typography, gain
///          collapse chevrons — view state only — and the section context menu with
///          rename / indent / outdent / delete-heading vs delete-section); dragging a
///          heading moves its whole section as one block via the shared
///          `CollectionOutline.applyingMove` engine; the fixed header gains compact
///          subtitle/author fields and a Front Matter disclosure (introduction rich text
///          + colophon toggle) joins Composition inside the scrolling list (respecting
///          the no-fixed-header-growth constraint), all live-autosaved
///   1.10 — Authoring Phase 4 review fix: `finishOutlineMutation` reindexes `sortOrder`
///          BEFORE `CollectionOutline.normalize` (matching iOS) — normalize linearizes
///          by `sortOrder`, so the previous order made the post-move normalization pass
///          a silent no-op and let orphan heading levels persist
///   1.11 — Authoring Phase 5 (excerpts): the structural add menu gains "Add Highlighted
///          Passages…" (`CollectionAddHighlightsSheet`); `.excerpt` entries render as
///          `CollectionExcerptRow` (inline trash; movable like prose); `MacEntryRow`'s
///          inspector gains the per-highlight "Insert as Excerpt" callback
///   1.12 — Authoring Phase 6 (generated apparatus): the structural add menu gains an
///          "Apparatus" submenu listing the five `CollectionGeneratedBlockType`s;
///          insertion honors the type's default position hint (front matter → before
///          the first entry, back matter → the end — fully movable afterwards);
///          `.generated` entries render as `CollectionGeneratedEntryRow` (inline trash;
///          movable like prose; no body-depth or inspector controls)
///   1.13 — Session 2026-07-04 (macOS UI audit B8): the per-entry inspector left its
///          modal sheet for a selection-driven trailing `.inspector` column on the
///          detail pane (each ⓘ opens/retargets/toggles it; deletions close it) —
///          coexisting with the live preview (inspector trailing-most) so override
///          edits show their effect in the preview instead of hiding it; document
///          rows (`MacEntryRow.onInspect`) and heading rows
///          (`CollectionHeadingRow.onInspect`) both route into the column. The
///          fixed-height header is untouched — the inspector is a sibling column,
///          not header content
///   1.14 — Session 2026-07-04 (macOS UI audit gaps 5 + A7): the window publishes
///          the "Collection" menu's focused-scene values — the root view publishes
///          `CollectionManagerCommandActions` (New Collection ⌥⌘N) and the detail
///          pane `CollectionDetailCommandActions` (Add Documents ⌘⇧A — the key
///          equivalent moved off the toolbar button so the menu is its single
///          owner — Add Section Heading, Add Note Block, Show Preview ⌥⌘P,
///          Export ⌘E); the outline List gains selection (A7): ↑/↓ traverse
///          entries, ↩ (and double-click on document rows) toggles the selected
///          entry's inspector column
///   1.15 — Session 2026-07-04 (UI audit A4): every entry row exposes Move Up /
///          Move Down as VoiceOver actions + context-menu items via the shared
///          `entryMoveControls`; `moveVisibleRowUp/Down` reuse the drag engine
///          (`moveVisibleRows`) in visible-row coordinates, so headings carry their
///          sections and collapsed sections are hopped whole
///   1.16 — Collections Manager M2 (D3): `MacEntryRow` became a pure report — its inline
///          note previews and multi-note picker (`noteMenu`) were removed in favor of the
///          shared read-only `entryStatusChips`; all per-document editing (body depth, note
///          selection) now lives in the trailing `CollectionEntryInspector` column, whose
///          "New Note…" opens the `InlineNoteCreateSheet` still hosted here at the pane
///          level via `noteCreateContext`
///   1.17 — 2026-09-23: #1358 — the collection picker's menu items, its label and the
///          Manage Collections rows print `Collection.documentCount`; all three counted every
///          entry, so a section heading or a prose block added one to the number
///   1.18 — 2026-09-23: #1359 — the detail pane's title goes through the iOS editor's
///          `CollectionEditorNaming.navigationTitle`: trimmed, and "Untitled Collection" localized
///   1.19 — 2026-09-24: #1359 review — the detail pane's name follow compares through the iOS
///          editor's `CollectionEditorNaming.fieldAgrees`, trimmed, instead of `!=`
///   1.20 — 2026-09-25: #1416 — the detail pane's outline follows entries another writer adds,
///          removes or moves (`CollectionEntriesModelSync`), so a document added from a document
///          window appears in the open pane, its preview and its export, and is seeded in the follow's
///          own order; appends and renumbering go through the iOS editor's `CollectionEntryOrdering`, so
///          an append no longer shares a position with one made in another window of the Mac; the
///          inline New Note sheet names its entry by id, since the outline can now change under it
///   1.21 — 2026-10-01 (MACCOL): the toolbar picker caps a long collection name at
///          `collectionNameMaxWidth`, and its counts and Manage Collections' rows' print grouped (#1446); the
///          ⚙ popover's Note rests capped in the shared editor's plain-text mode (#1449); and the detail pane
///          commits only the field the reader edits and follows every field another writer changes — the iOS
///          editor's `CollectionEditorCommit` and `FrontMatterModelSync` — where `saveMetadata()` wrote all seven
///          fields from stale copies on every edit (#1413's shape on the Mac)
///   1.22 — 2026-10-15: #1619 — a smart collection reads "Smart collection" where the picker's menu and
///          Manage Collections' rows printed its count of ignored entries, and a bolt where the picker's label
///          did; the detail pane's Contents opens with the picker's sentence, the toolbar's Add menu and the
///          Collection menu disable Add Documents, Add Section Heading, Add Note Block and Add Passages, and the
///          inspector offers no Insert as Excerpt (`SmartCollectionRule`); Add to Archives Visit… says why when the
///          search cannot run
///   1.23 — 2026-10-15: #1619 review — the ⚙ popover shows a smart collection's link with Unlink
///          (`SmartCollectionLinkRows`), whether or not its saved search can still be found: the window that refuses
///          a smart collection's hand-added entries had no way to unlink one
///   1.24 — 2026-10-16: #1619, decision 22 of the 2026-10-14 plan of record — a smart collection's Contents lists only
///          the entries it keeps (`CollectionOutline.contentsRows`), and its entries from before its link follow in a
///          section of their own under a dimmed heading, with Remove These Entries, which asks first
///          (`SmartCollectionEntriesFromBeforeLink`, the iOS editor's); its apparatus rows print no document count
///   1.25 — 2026-10-20: #1687, decision 70 of the 2026-10-14 plan of record — the ⚙ popover's Smart Collection section
///          offers Link to Saved Search… for a collection that is not linked (`SmartCollectionLinkButton`), which closes
///          the popover and opens the editor's picker on the pane (`LinkSavedSearchPicker`); on the Mac a collection
///          could be linked only while Add to Collection's New Collection created it
///   1.26 — 2026-10-25: #1791 — the window reads one copy of each note and saved search, however many are stored
///          under one id, so an entry's notes, the exports and Link to Saved Search… list each once
struct MacCollectionManagerView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow

    @Query(sort: \Collection.lastModified, order: .reverse) private var allCollections: [Collection]
    @Query(sort: \ResearchNote.lastModified, order: .reverse) private var allNoteCopies: [ResearchNote]
    @Query(sort: \UserTag.name) private var allTags: [UserTag]
    @Query(sort: \Project.name) private var allProjects: [Project]

    @State private var selectedId: UUID? = nil
    @State private var showNewCollection = false
    /// User override of the active-project filter, toggled from `projectFilterBanner`.
    ///
    /// Defaults to `true` (issue #213): the Collections window opens showing collections
    /// from *every* project, at parity with the iOS Collection Manager, and the user may
    /// narrow to the active project via the banner. Ephemeral `@State` — resets to the
    /// all-project default when the window is recreated.
    @State private var showAllCollections = Collection.managerDefaultShowAllCollections
    /// Drives the `.fruscollection` file importer.
    @State private var isImporting = false
    /// Non-nil to present an import-failure alert.
    @State private var importError: String? = nil
    /// Non-nil to present a smart-collection snapshot-failure alert.
    @State private var snapshotError: String? = nil
    /// Composer v2 (§B): the "Manage Collections…" sheet (rename / delete), reached from the toolbar
    /// collection picker.
    @State private var showManageCollections = false

    private var filteredCollections: [Collection] {
        Collection.visibleCollections(allCollections,
                                      activeProjectId: appState.activeProjectId,
                                      showAll: showAllCollections)
    }

    /// The `Project` named by `appState.activeProjectId`, resolved for `projectFilterBanner`.
    private var activeProject: Project? {
        guard let projectId = appState.activeProjectId else { return nil }
        return allProjects.first { $0.id == projectId }
    }

    /// Display name for `activeProject`, falling back to a localized placeholder.
    private var activeProjectDisplayName: String {
        guard let project = activeProject, !project.name.isEmpty else {
            return String(localized: "collections.filterBanner.untitledProject",
                          defaultValue: "Untitled Project")
        }
        return project.name
    }

    /// Count of collections hidden when scoped to the active project — drives whether the
    /// banner offers "Show All" and the wording of the scoped-state message.
    private var hiddenCollectionCount: Int {
        guard let projectId = appState.activeProjectId else { return 0 }
        return allCollections.filter { !$0.projectIds.contains(projectId) }.count
    }

    private var selectedCollection: Collection? {
        allCollections.first { $0.id == selectedId }
    }

    /// The display name for a collection: trimmed, and "Untitled Collection" for an untitled one — what every list
    /// row reads (#1464).
    private func collectionDisplayName(_ c: Collection) -> String {
        CollectionEditorNaming.listName(savedName: c.name)
    }

    /// The widest the toolbar picker draws the collection's name, in points; a longer name is cut at the tail and the
    /// picker's menu still lists it whole (#1446).
    ///
    /// The toolbar gives each item its content's own width, so the picker grew with the name, point for point, and a
    /// long name pushed Add, Sort, Collection settings, Export and the inspector toggle behind the overflow chevron. The
    /// Archives Visits window had the same defect and measured this cap (#1378). Measured in this window too (MACCOL
    /// review round 1, macOS 27: a scratch copy of the app reading `NSToolbar.visibleItems` as it widened the window
    /// 2 pt at a time): with the 77-character name #1378 used, every item shows from 1,080 pt uncapped and 828 pt capped,
    /// and from 1,102 and 854 pt with a 1,234-document count; uncapped, below 884 pt the picker itself went behind the
    /// chevron. A 13- or 33-character name, under the cap, fits from 656 or 790 pt either way. The window opens at 1,180.
    static let collectionNameMaxWidth: CGFloat = 260

    /// Composer v2 (§B): the toolbar collection PICKER — the everyday switcher that replaces the
    /// permanent sidebar. Its label shows the current collection + document count; the menu body is
    /// an inline Picker of collections (a ✓ marks the current) plus New / Import / Manage actions.
    private var collectionPickerMenu: some View {
        Menu {
            Picker(selection: $selectedId) {
                ForEach(filteredCollections) { c in
                    // #1619: a smart collection's count is of entries everything it produces ignores.
                    let contents = c.savedSearchId == nil ? c.documentCount.formatted() : SmartCollectionRule.listLabel
                    Text(verbatim: "\(collectionDisplayName(c))  ·  \(contents)")
                        .tag(Optional(c.id))
                }
            } label: { EmptyView() }
            .pickerStyle(.inline)

            Divider()
            Button { showNewCollection = true } label: {
                Label(String(localized: "collections.picker.new", defaultValue: "New Collection…"),
                      systemImage: "plus")
            }
            Button { isImporting = true } label: {
                Label(String(localized: "collections.toolbar.import", defaultValue: "Import Collection…"),
                      systemImage: "square.and.arrow.down")
            }
            Button { showManageCollections = true } label: {
                Label(String(localized: "collections.picker.manage", defaultValue: "Manage Collections…"),
                      systemImage: "list.bullet")
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal")
                Text(selectedCollection.map(collectionDisplayName)
                     ?? String(localized: "collections.picker.title", defaultValue: "Collections"))
                    .fontWeight(.semibold)
                    // One line, cut at the tail (#1446). The maximum width is what does the cutting: a toolbar
                    // item is as wide as its content wants, so a line limit alone leaves a long name whole.
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: Self.collectionNameMaxWidth, alignment: .leading)
                if let c = selectedCollection {
                    if c.savedSearchId == nil {
                        Text(verbatim: c.documentCount.formatted())
                            .foregroundStyle(.secondary)
                    } else {
                        // #1619: a bolt rather than the words, so the toolbar keeps the width
                        // `collectionNameMaxWidth` was measured at.
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(SmartCollectionRule.listLabel)
                    }
                }
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // #213 project-scope banner, rehomed from the removed sidebar (Composer v2 §B) — a slim
            // strip above the detail so the all-projects default and "Scope to project" survive.
            projectFilterBanner
            if let c = selectedCollection {
                CollectionDetailPane(collection: c, allNotes: allNotes, allTags: allTags)
                    .id(c.id)
            } else {
                ContentUnavailableView {
                    // Its own key: `collections.empty.title` means "you have no collections" in
                    // CollectionListView. This is the detail pane with nothing selected — the
                    // opposite situation, and it was sharing that key.
                    Label(String(localized: "collections.noSelection.title",
                                 defaultValue: "No Collection Selected"),
                          systemImage: "folder.badge.person.crop")
                } description: {
                    Text(String(localized: "collections.empty.description.picker",
                                defaultValue: "Choose a collection from the picker in the toolbar, or create a new one."))
                } actions: {
                    Button(String(localized: "collections.new.button", defaultValue: "New Collection")) {
                        showNewCollection = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showNewCollection) {
            NewCollectionSheet { id in selectedId = id }
                .environment(appState)
        }
        // Composer v2 (§B): the "Manage Collections…" sheet — rename / delete, keeping the current
        // sort. Reached from the toolbar collection picker (which replaces the sidebar's management
        // role in Step 3).
        .sheet(isPresented: $showManageCollections) {
            MacManageCollectionsSheet(
                collections: filteredCollections,
                selectedId: $selectedId,
                onWordCloud: {
                    appState.openWordCloud(.collection(id: $0.id), from: nil)   // #338: macOS singleton window
                    // The Collections manager has no document-host provenance — clear the word
                    // cloud's binding so a spawned document open resolves via the D3 recency
                    // fallback, not a stale host.
                    appState.bindTool(.wordCloud, to: nil)
                    openWindow.fronting(id: "frus.wordcloud")            // #334: open directly, not via MainWindowView's observer
                },
                onSnapshot: { c in Task { await snapshotSmartCollection(c) } }
            )
            .environment(appState)
        }
        // Composer v2 (§B): the toolbar collection PICKER — the everyday switcher. Coexists with the
        // sidebar until Step 3 removes it; both write `selectedId`.
        .toolbar {
            ToolbarItem(placement: .navigation) {
                collectionPickerMenu
            }
        }
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
        // Select a collection handed off from another surface — today the open-with
        // `.fruscollection` import in FRUSExplorerApp, which sets the hand-off right
        // before opening this window. `.task` consumes a hand-off already pending when
        // the window is freshly created by that `openWindow(id:)`; `.onChange` consumes
        // one arriving while the window is already open. Consume-and-clear, mirroring
        // the `pendingSearch` pattern, so each hand-off fires once.
        .task { consumePendingCollectionSelection() }
        .onChange(of: appState.pendingCollectionSelection) { _, id in
            if id != nil { consumePendingCollectionSelection() }
        }
        // "Collection" menu wiring (UI audit gap 5): New Collection is published
        // from the window root — it must work while nothing is selected — and is
        // therefore available whenever this window is key. The selection-dependent
        // items are published separately by CollectionDetailPane. Optional-typed so
        // the Equatable focusedSceneValue overload is selected.
        .focusedSceneValue(
            \.collectionManagerCommands,
            CollectionManagerCommandActions(newCollection: { showNewCollection = true })
                as CollectionManagerCommandActions?
        )
    }

    /// Applies a `pendingCollectionSelection` hand-off to the sidebar selection, then
    /// clears it so it fires once.
    private func consumePendingCollectionSelection() {
        guard let id = appState.pendingCollectionSelection else { return }
        appState.pendingCollectionSelection = nil
        selectedId = id
    }

    /// Resolves a smart collection's saved search now and materializes the results into a new
    /// static collection (D8), then selects it. Non-destructive: the smart collection is untouched.
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
            let results = try await searchService.search(
                parameters: savedSearch.searchParameters,
                limit: SearchViewModel.searchHardLimit)
            let refs = results.map { (documentId: $0.documentId, volumeId: $0.volumeId) }
            let snapshot = SmartCollectionSnapshot.create(from: collection, results: refs, into: modelContext)
            if let pid = appState.activeProjectId, !snapshot.projectIds.contains(pid) {
                snapshot.projectIds.append(pid)
            }
            try modelContext.save()
            selectedId = snapshot.id
        } catch {
            snapshotError = error.localizedDescription
        }
    }

    /// Imports a user-picked `.fruscollection` file, then selects the reconstructed collection.
    private func importCollection(from result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importError = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let imported = try NativeCollectionSerializer.importCollection(from: url, into: modelContext)
                // Scope the import to the active project (as new collections are) so it isn't
                // hidden by the sidebar's active-project filter; imported files carry no projectIds.
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
                selectedId = imported.id
            } catch {
                importError = error.localizedDescription
            }
        }
    }

    // MARK: - Project scope banner (rehomed from the removed sidebar, Composer v2 §B)

    /// Informs the user when the window is scoped to the active project and lets them
    /// override that scoping (and back again) — the macOS parity of the iOS
    /// `CollectionListView.projectFilterBanner`. Hidden when there is no active project.
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

}

// MARK: - NewCollectionSheet

private struct NewCollectionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let onCreated: (UUID) -> Void

    @State private var name = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("New Collection").font(.headline)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Divider()

            Form {
                Section("Name") {
                    TextField("Collection Name", text: $name)
                        .onSubmit { createAndDismiss() }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create") { createAndDismiss() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 360, minHeight: 150)
    }

    private func createAndDismiss() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let c = Collection(name: trimmed)
        if let pid = appState.activeProjectId { c.projectIds = [pid] }
        modelContext.insert(c)
        try? modelContext.save()
        onCreated(c.id)
        dismiss()
    }
}

// MARK: - MacManageCollectionsSheet (Composer v2 §B)

/// The "Manage Collections…" sheet reached from the toolbar collection picker — the full list of
/// collections with inline rename and delete (keeping the current sort; no manual reorder). Takes
/// over the permanent sidebar's management role.
private struct MacManageCollectionsSheet: View {
    /// The collections to manage (already project-filtered by the caller).
    let collections: [Collection]
    /// The manager's current selection, cleared if the selected collection is deleted here.
    @Binding var selectedId: UUID?
    /// Opens a word cloud for a collection (rehomed from the removed sidebar context menu).
    let onWordCloud: (Collection) -> Void
    /// Snapshots a smart collection into a static one (rehomed from the removed sidebar).
    let onSnapshot: (Collection) -> Void
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(String(localized: "collections.manage.title", defaultValue: "Manage Collections"))
                    .font(.headline)
                Spacer()
                Button(String(localized: "common.done", defaultValue: "Done")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(20)
            Divider()
            if collections.isEmpty {
                ContentUnavailableView {
                    Label(String(localized: "collections.manage.empty", defaultValue: "No Collections"),
                          systemImage: "tray")
                }
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(collections) { c in
                        ManageCollectionRow(
                            collection: c,
                            onWordCloud: { onWordCloud(c) },
                            onSnapshot: c.savedSearchId != nil ? { onSnapshot(c) } : nil)
                    }
                    .onDelete { offsets in
                        for i in offsets {
                            let c = collections[i]
                            if selectedId == c.id { selectedId = nil }
                            GeneratedSummary.deleteHeadnoteDrafts(for: c, in: modelContext)
                            for entry in c.documentEntries ?? [] { modelContext.delete(entry) }
                            modelContext.delete(c)
                        }
                        try? modelContext.save()
                    }
                }
            }
        }
        .frame(minWidth: 440, minHeight: 420)
    }
}

/// One editable row in the Manage Collections sheet: an inline rename field + the document count.
private struct ManageCollectionRow: View {
    @Bindable var collection: Collection
    @Environment(\.modelContext) private var modelContext
    /// Opens a word cloud for this collection (rehomed from the removed sidebar context menu).
    let onWordCloud: () -> Void
    /// Snapshots this smart collection into a static one; `nil` for a non-smart collection.
    let onSnapshot: (() -> Void)?

    var body: some View {
        HStack {
            TextField(String(localized: "collection.untitled.name", defaultValue: "Untitled Collection"),
                      text: $collection.name)
                .textFieldStyle(.plain)
            Spacer()
            // #1619: a smart collection's count is of entries everything it produces ignores.
            if collection.savedSearchId == nil {
                Text(verbatim: collection.documentCount.formatted())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Label(SmartCollectionRule.listLabel, systemImage: "bolt.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button {
                _ = collection.duplicate(in: modelContext)
                try? modelContext.save()
            } label: {
                Label(String(localized: "collection.duplicate.action", defaultValue: "Duplicate"),
                      systemImage: "plus.square.on.square")
            }
            Divider()
            Button(action: onWordCloud) {
                Label { Text(String(localized: "collection.wordCloud", defaultValue: "Word Cloud")) }
                    icon: { Image(systemName: WordCloudGlyph.symbol) }
            }
            if let onSnapshot {
                Button(action: onSnapshot) {
                    Label(String(localized: "collection.snapshot.action",
                                 defaultValue: "Create Static Snapshot"),
                          systemImage: "camera")
                }
            }
        }
    }
}

// MARK: - CollectionDetailPane

/// Detail pane that lets the user edit a single selected collection.
private struct CollectionDetailPane: View {

    let collection: Collection
    let allNotes: [ResearchNote]
    let allTags: [UserTag]

    @Environment(AppState.self) private var appState
    /// #755: opens a collection entry in the reader, minting a window when no host is live.
    @Environment(\.openWindow) private var openWindow
    @Environment(\.modelContext) private var modelContext

    /// Projects, for the author-line placeholder (the active project's name is offered
    /// as a suggestion only — never persisted automatically).
    @Query(sort: \Project.name) private var allProjects: [Project]
    /// Saved searches, for the name of the one a smart collection is linked to, in the ⚙ popover's Smart Collection
    /// rows (#1619 review).
    @Query(sort: \SavedSearch.createdAt, order: .reverse) private var allSavedSearchCopies: [SavedSearch]

    @State private var name: String
    @State private var note: String
    @State private var sortedEntries: [CollectionEntry]
    /// Front matter (Authoring Phase 4): title-page subtitle, live-autosaved like name.
    @State private var subtitle: String
    /// Front matter: title-page author line (placeholder = active Project name).
    @State private var authorLine: String
    /// Front matter: whether exports end with the colophon (default off).
    @State private var includeColophon: Bool
    /// Front matter: whether exports stamp the active project on the title page (#377 Phase 4, default off).
    @State private var includeProjectProvenance: Bool
    /// Front matter: whether exports append the project's query log as a method appendix
    /// (M-2, default off). This pane is a **parallel** implementation of
    /// `CollectionEditorView.frontMatterRows`; #617 added the toggle there and not here, so the
    /// macOS Collections window — the surface a Mac user actually reaches at ⌘⇧K — had no way to
    /// turn it on. `CollectionExportToggleParityTests` now fails if the two lists diverge again.
    @State private var includeMethodAppendix: Bool
    /// Headings whose sections are collapsed in the outline — VIEW STATE only (Phase 4):
    /// never persisted, never synced; keyed by entry id so it survives moves.
    @State private var collapsedHeadingIds: Set<UUID> = []
    @State private var showAddDocuments = false
    /// A transient "Added N documents" confirmation toast after the Add Documents sheet commits (5).
    @State private var addDocumentsToast: String?
    /// Presents the bulk "Add Highlighted Passages" sheet (Authoring Phase 5).
    @State private var showAddHighlights = false
    @State private var showExport = false
    /// #830 / Phase 3: the Add-to-Archive-Visit picker for this collection. This pane is
    /// where macOS actually edits a collection, so the control and the presenter both live here.
    @State private var planPickerRequest: PlanPickerRequest?
    /// Why Add to Archives Visit… could not resolve this smart collection's search, while its alert shows (#1619).
    @State private var addToVisitError: String?
    /// Composer v2 (§B): the ⚙ Collection settings popover — the metadata / front-matter /
    /// composition surface that replaces the fixed header + inline Composition/Front-Matter
    /// disclosures (which are gone).
    @State private var showCollectionSettingsPopover = false
    /// The Link to Saved Search picker (`LinkSavedSearchPicker`, #1687), presented on this pane once the ⚙ popover whose
    /// Link to Saved Search… asked for it has closed.
    @State private var showLinkSavedSearch = false
    /// Set by the ⚙ popover's Link to Saved Search…, which closes the popover; the popover's going presents the picker
    /// (#1687). The pane presents it, not the popover, and only once the popover has gone, so the sheet opens on the
    /// window rather than on the popover, as the pane's other sheets do.
    @State private var opensLinkPickerOnClose = false
    /// Live preview pane visibility. Defaults **on** so the manager opens with the live
    /// "exactly what exports" preview beside the outline (Composer redesign 4 — the 4-pane
    /// intent), and persists the researcher's toolbar/Collection-menu toggle across sessions.
    @AppStorage("collections.mac.showPreview") private var showPreview = true
    /// The id of the entry shown in the trailing inspector column (UI audit B8), or
    /// `nil` when the column is closed. Selection-driven: each row's ⓘ sets it (a
    /// second click on the same row's ⓘ closes the column), so clicking another ⓘ
    /// retargets the open inspector. View state only — never persisted.
    @State private var inspectedEntryId: UUID? = nil
    /// The outline row selected in the entries List (UI audit A7): gives the list
    /// native ↑/↓ keyboard traversal, and ↩ toggles the selected entry's inspector.
    /// Distinct from `inspectedEntryId` — selection moves freely without opening
    /// the inspector column. View state only — never persisted.
    @State private var selectedEntryId: UUID? = nil
    /// The preview's "Render All" cap lift, hoisted here so hiding/showing the pane
    /// doesn't reset it (one detail-pane session = one lift).
    @State private var previewRenderAll = false
    @State private var noteCreateContext: NoteCreateContext? = nil
    /// Document headers loaded asynchronously from `document_cache`.
    /// Keyed by `"volumeId/documentId"`.
    @State private var documentHeaders: [String: String] = [:]
    /// Per-document ISO-8601 dates loaded from `document_dates` for chronological sorting.
    /// Keyed by `"volumeId/documentId"`. Documents without a parseable date are absent.
    @State private var documentDates: [String: String] = [:]
    /// The printed document numbers the rows label documents with (#1406), keyed
    /// `"volumeId/documentId"`; unindexed documents are absent.
    @State private var documentNumbers: [String: String] = [:]

    /// The document an inline note-create sheet is for; `entryId` names the owning entry to link — an id, not an
    /// outline index, since the outline can change under the open sheet when another writer adds or removes an entry
    /// (#1416).
    private struct NoteCreateContext: Identifiable {
        let id = UUID()
        let documentId: String
        let volumeId: String
        let entryId: UUID
    }

    init(collection: Collection, allNotes: [ResearchNote], allTags: [UserTag]) {
        self.collection = collection
        self.allNotes = allNotes
        self.allTags = allTags
        _name = State(initialValue: collection.name)
        _note = State(initialValue: collection.note ?? "")
        _subtitle = State(initialValue: collection.subtitle ?? "")
        _authorLine = State(initialValue: collection.authorLine ?? "")
        _includeColophon = State(initialValue: collection.includeColophon)
        _includeProjectProvenance = State(initialValue: collection.includeProjectProvenance)
        _includeMethodAppendix = State(initialValue: collection.includeMethodAppendix)
        // The follow's own order (#1416): its `onChange` never runs for the value it starts on, so an outline seeded
        // any other way — an entry deleted but not yet saved, a shared position — would stay until the model moved.
        _sortedEntries = State(initialValue: CollectionEntryOrdering.modelOrder(of: collection))
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            // Composer v2 (§B): the single middle column is the Contents outline (bounded ~372 so the
            // live preview takes the rest). Name / note / front matter / composition all moved to the
            // ⚙ Collection popover; the editor column and control ribbon are gone.
            documentsSection
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(minWidth: 340, idealWidth: 372, maxWidth: showPreview ? 460 : .infinity)

            // Live preview pane (Authoring Phase 2b) — side-by-side, toolbar-toggled.
            if showPreview {
                Divider()
                CollectionPreviewView(collection: collection,
                                      entries: sortedEntries,
                                      allNotes: allNotes,
                                      renderAll: $previewRenderAll)
                    .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(CollectionEditorNaming.navigationTitle(savedName: name, isNewCollection: false))
        .toolbar { toolbarContent }
        // Each field commits ITSELF, from its own control (`committing`, `commitNote`), through the iOS editor's
        // rules (`CollectionEditorCommit`): only that field, and only when the edit changes what is saved. Before,
        // seven `onChange` handlers each ran `saveMetadata()`, which wrote all seven fields from this pane's one-time
        // `@State` copies — so any edit put stale copies back over a description, subtitle, author line or flag
        // another writer had changed (iCloud bringing an edit from another device), and following a rename from the
        // Manage Collections sheet wrote the other six back. That was #1413's shape, which the iOS editor shed.
        // Follow every field another writer changes — the Manage Collections sheet's rename (`$collection.name`), iCloud
        // — so a field the reader edits next starts from what the collection holds. `FrontMatterModelSync` only
        // writes the pane's copies, never the collection, and compares text trimmed, so the pane's own trimmed commit
        // comes back as a value the field already agrees with (the #1359 rule) and a space just typed stays put.
        // Not while the ⚙ popover is open, for its Note and Introduction: each editor reads its text once, when the
        // popover opens, so a change from another device reaches `note` (the Introduction has no copy here) and not the
        // editor on screen, and the reader's next keystroke there writes the editor's text back over it. (Before MACCOL
        // nothing followed the Note at all.)
        .modifier(FrontMatterModelSync(
            collectionName: $name,
            collectionNote: $note,
            collectionSubtitle: $subtitle,
            collectionAuthorLine: $authorLine,
            includeColophon: $includeColophon,
            includeProjectProvenance: $includeProjectProvenance,
            includeMethodAppendix: $includeMethodAppendix,
            collection: collection))
        // #1416: the outline follows entries another writer adds, removes or moves — a document window's Add to
        // Collection, iCloud — so the rows, the live preview and the export sheet all see them.
        .modifier(CollectionEntriesModelSync(outline: $sortedEntries, collection: collection))
        // Reload document headers and per-document dates whenever the entry list changes.
        .task(id: sortedEntries.map(\.id)) {
            (documentHeaders, documentDates) =
                await CollectionEntryData.load(for: sortedEntries, appState: appState)
            documentNumbers =
                await CollectionEntryData.documentNumbers(for: sortedEntries, appState: appState)
        }
        .sheet(isPresented: $showAddDocuments) {
            CollectionAddDocumentsSheet(
                allTags: allTags,
                allNotes: allNotes,
                existingDocumentKeys: existingDocumentKeys
            ) { picks in
                if appendEntries(picks.map { (documentId: $0.documentId, volumeId: $0.volumeId) }) {
                    addDocumentsToast = CollectionDocumentDiscovery.addedToastMessage(picks.count)
                }
            }
            .environment(appState)
        }
        .transientToast($addDocumentsToast)
        .sheet(item: $planPickerRequest) { request in
            // Membership resolved through the ONE `TripPacketSeed.resolve` rule the iOS editor's
            // two menus use, so the three collection surfaces cannot describe different sets.
            PlanPickerSheet(request: request)
                .environment(appState)
        }
        // #1619 (#1558's reading): a smart collection whose search cannot run says why, where the item did nothing.
        .alert(
            String(localized: "archiveVisit.collection.error.title", defaultValue: "Couldn’t Add to Archives Visit"),
            isPresented: Binding(
                get: { addToVisitError != nil },
                set: { if !$0 { addToVisitError = nil } }
            ),
            presenting: addToVisitError
        ) { _ in
            Button(String(localized: "common.ok", defaultValue: "OK"), role: .cancel) {}
        } message: { msg in
            Text(msg)
        }
        .sheet(isPresented: $showAddHighlights) {
            CollectionAddHighlightsSheet(
                documentKeys: orderedDocumentKeys,
                documentLabels: documentHeaders
            ) { captures in
                appendExcerpts(captures)
            }
        }
        .sheet(isPresented: $showExport) {
            ExportSheetView(
                collection: collection,
                entries: sortedEntries,
                allNotes: allNotes,
                appState: appState
            )
        }
        // #1687: the ⚙ popover's Link to Saved Search… opens the editor's picker here, and the link commits as the
        // popover's Unlink does, through the editor's rule.
        .sheet(isPresented: $showLinkSavedSearch) {
            LinkSavedSearchPicker(
                savedSearches: allSavedSearches,
                onLink: { searchId in
                    if CollectionEditorCommit.savedSearch(searchId, to: collection) { try? modelContext.save() }
                    showLinkSavedSearch = false
                },
                onCancel: { showLinkSavedSearch = false })
        }
        .sheet(item: $noteCreateContext) { ctx in
            InlineNoteCreateSheet(
                documentId: ctx.documentId,
                volumeId: ctx.volumeId,
                activeProjectId: appState.activeProjectId
            ) { newNote in
                // D5: the new note is on this document, so an untouched entry (empty
                // selection = all) already includes it — do nothing. Only when the user
                // has an explicit partial selection do we append it so it's included.
                if let entry = sortedEntries.first(where: { $0.id == ctx.entryId }),
                   !entry.selectedNoteIds.isEmpty {
                    entry.selectedNoteIds.append(newNote.id)
                }
            }
            .environment(appState)
        }
        // Entry inspector (UI audit B8): a trailing `.inspector` column replacing the
        // per-row modal sheet, so the outline stays visible — and editable — while the
        // inspector's overrides and "Insert as Excerpt" act on it. It coexists with the
        // live preview pane (the inspector sits trailing-most) deliberately: the
        // inspector edits per-entry export overrides whose effect renders live in the
        // preview, which a toggle would have hidden at exactly the moment it matters.
        // `.id(entry.id)` re-creates the inspector per entry so its `@State` loads fresh.
        .inspector(isPresented: Binding(
            get: { inspectedEntryId != nil },
            set: { if !$0 { inspectedEntryId = nil } }
        )) {
            if let entry = inspectedEntry {
                CollectionEntryInspector(
                    entry: entry,
                    // #1619: no Insert as Excerpt into a smart collection, which leaves hand-added passages out of
                    // every export.
                    onInsertExcerpt: takesHandAddedEntries ? { capture in appendExcerpts([capture]) } : nil,
                    // D5: "New Note…" in the inspector's per-note list opens the same
                    // inline note-create sheet the row's note menu used to (now removed),
                    // targeting this entry so the created note links to it.
                    onNewNote: entry.entryKind == .document ? {
                        if sortedEntries.contains(where: { $0.id == entry.id }) {
                            noteCreateContext = NoteCreateContext(
                                documentId: entry.documentId,
                                volumeId: entry.volumeId,
                                entryId: entry.id)
                        }
                    } : nil,
                    isInspectorColumn: true,
                    // Composer v2 (§B): document-only. The whole-collection settings and
                    // composition (name / front matter / preset grid) live in the ⚙ Collection
                    // popover now, so the per-entry Configure inspector omits the collection
                    // section to avoid rendering — and letting the user edit — the same recipe twice.
                    showsCollectionSettings: false
                )
                .id(entry.id)
                .environment(appState)
            }
        }
        // "Collection" menu wiring (UI audit gap 5): the selection-dependent
        // authoring/export items act on this pane's existing controls; nil (items
        // disabled) whenever no collection is selected, since this pane then
        // doesn't exist. Optional-typed so the Equatable focusedSceneValue
        // overload is selected.
        .focusedSceneValue(\.collectionDetailCommands, detailCommands)
    }

    /// The "Collection" menu's selected-collection command surface (UI audit
    /// gap 5). Every closure routes to a control that already exists in this
    /// pane: the Add Documents / Export toolbar buttons, the structural-add
    /// menu's heading/prose items, and the Preview toolbar toggle. Equality
    /// contract (see `CollectionDetailCommandActions`): the closures capture only
    /// this pane's stable `@State` storage, so they cannot go stale while the
    /// compared identity fields are unchanged.
    private var detailCommands: CollectionDetailCommandActions? {
        CollectionDetailCommandActions(
            collectionId: collection.id,
            isPreviewShown: showPreview,
            // Mirrors the Export toolbar button's `.disabled` condition — a smart
            // collection (savedSearchId set) exports with zero static entries.
            canExport: !sortedEntries.isEmpty || collection.savedSearchId != nil,
            hasEntries: !sortedEntries.isEmpty,
            hasDocuments: !orderedDocumentKeys.isEmpty,
            takesHandAddedEntries: takesHandAddedEntries,
            addDocuments: { showAddDocuments = true },
            addHeading: { addStructuralEntry(kind: .heading) },
            addProse: { addStructuralEntry(kind: .prose) },
            addHighlights: { showAddHighlights = true },
            addApparatus: { addGeneratedEntry(type: $0) },
            sortByDate: { sortByDate() },
            togglePreview: { showPreview.toggle() },
            toggleSettings: { showCollectionSettingsPopover.toggle() },
            exportCollection: { showExport = true }
        )
    }

    /// The entry targeted by the inspector column, resolved by id so deletions and
    /// reorderings never leave the inspector pointing at a stale model object.
    private var inspectedEntry: CollectionEntry? {
        inspectedEntryId.flatMap { id in sortedEntries.first { $0.id == id } }
    }

    /// Toggles `entryId` in the inspector column (each row's ⓘ): opens it, retargets
    /// an open column to another entry, or closes it when it's already showing.
    /// Opens a collection entry in this Mac's reader (#755 / audit M-19).
    ///
    /// Routes through the provenance chain like every other macOS list surface, which mints a
    /// standalone window when no document host is live — so the open never silently does nothing.
    private func openInReader(_ entry: CollectionEntry) {
        appState.openDocument(
            DocumentBrowserEntry(documentId: entry.documentId,
                                 volumeId: entry.volumeId,
                                 header: entry.titleOverride ?? entry.documentId),
            from: .global,
            using: openWindow)
    }

    private func toggleInspector(for entryId: UUID) {
        inspectedEntryId = (inspectedEntryId == entryId) ? nil : entryId
    }

    /// Refocuses the inspector on `entryId` — but only when it is already open (#188-E). A
    /// single click while the inspector column is showing moves it to the clicked row; when the
    /// inspector is closed, single-click stays pure list selection (double-click / ↩ / the ⓘ
    /// button open it), so normal navigation is preserved.
    private func refocusInspectorIfOpen(for entryId: UUID) {
        if inspectedEntryId != nil { inspectedEntryId = entryId }
    }

    // Composer v2 (§B): the editor column and the CollectionRibbonView control ribbon are gone —
    // the middle column is the Contents outline only (see `body`), and every authoring verb moved to
    // the pane toolbar (`toolbarContent`). Name/note/front-matter/composition live in the
    // ⚙ Collection popover (`macCollectionSettingsForm`).

    /// The active project's name as the author-line placeholder (suggestion only —
    /// never written to the model unless the user types it).
    private var authorPlaceholder: String {
        if let pid = appState.activeProjectId,
           let project = allProjects.first(where: { $0.id == pid }),
           !project.name.isEmpty {
            return project.name
        }
        return String(localized: "collection.frontmatter.author.placeholder",
                      defaultValue: "Author")
    }

    // MARK: - Collection settings popover (Composer v2 §B)

    /// The ⚙ Collection settings popover content: the collection's metadata (name / subtitle /
    /// author / note), title-page front matter (rich-text introduction + colophon), and the presets
    /// + three grouped composition sections. Replaces the fixed header + inline Composition/Front-
    /// Matter disclosures (removed in Step 4). `presetsCompact: false` renders the 2×2 preset grid —
    /// a popover is wide enough. Each control commits its own field as it is edited (`committing`, `commitNote`).
    private var macCollectionSettingsForm: some View {
        Form {
            Section {
                TextField(String(localized: "collection.editor.name.placeholder",
                                 defaultValue: "Collection Name"),
                          text: committing($name) { CollectionEditorCommit.name($0, to: collection) })
                TextField(String(localized: "collection.frontmatter.subtitle.placeholder",
                                 defaultValue: "Subtitle (title page)"),
                          text: committing($subtitle) { CollectionEditorCommit.text($0, to: \.subtitle, of: collection) })
                TextField(authorPlaceholder,
                          text: committing($authorLine) { CollectionEditorCommit.text($0, to: \.authorLine, of: collection) })
            } header: {
                Text(String(localized: "collection.editor.settings.name", defaultValue: "Name"))
            }

            Section {
                // #1449: rests capped at six lines with an ellipsis, like the Introduction below it — the fixed
                // 60–140 pt `TextEditor` it replaces scrolled a long note and cut it through a line. Plain-text mode,
                // because the note is a plain `String?` on the model and a rich one would be a stored property, a
                // CloudKit schema change. Loaded from `note` when the popover opens; edits commit through `commitNote`.
                RichTextEditor(initialRTF: nil, plainFallback: note, restingCap: .noteInPopover,
                               plainText: true) { _, plain in
                    commitNote(plain)
                }
            } header: {
                Text(String(localized: "collection.editor.note", defaultValue: "Note"))
            }

            Section {
                RichTextEditor(initialRTF: collection.introductionRichText,
                               plainFallback: collection.introductionText ?? "",
                               restingCap: .introductionInPopover) { rtf, plain in
                    saveIntroduction(rtf: rtf, plain: plain)
                }
                Toggle(String(localized: "collection.frontmatter.colophon.toggle",
                              defaultValue: "Include colophon"),
                       isOn: committing($includeColophon) { CollectionEditorCommit.flag($0, to: \.includeColophon, of: collection) })
                Toggle(String(localized: "collection.frontmatter.projectProvenance.toggle",
                              defaultValue: "Stamp active project on export"),
                       isOn: committing($includeProjectProvenance) {
                           CollectionEditorCommit.flag($0, to: \.includeProjectProvenance, of: collection)
                       })
                // M-2. Two `Text`s rather than one, because this is the only export toggle that
                // puts the text of the researcher's own searches into a document they may be
                // about to publish, and that has to be legible at the moment of the click.
                Toggle(isOn: committing($includeMethodAppendix) {
                    CollectionEditorCommit.flag($0, to: \.includeMethodAppendix, of: collection)
                }) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "collection.frontmatter.methodAppendix.toggle",
                                    defaultValue: "Append the query log"))
                        Text(String(localized: "collection.frontmatter.methodAppendix.subtitle",
                                    defaultValue: "Every search you ran under the active project, with its scope and result count."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text(String(localized: "collection.frontmatter.titlePage",
                            defaultValue: "Title Page & Introduction"))
            }

            CollectionCompositionRows(collection: collection,
                                      onApplyPreset: { applyPreset($0) },
                                      presetsCompact: false)

            // #1619 review: a smart collection takes no hand-added entry, so the window that refuses them offers the
            // way back, Unlink, whether or not the saved search can still be found. #1687 (decision 70): and a
            // collection that is not linked offers the link, which on the Mac had been made only while Add to
            // Collection's New Collection created a collection. Its picker is the editor's (`LinkSavedSearchPicker`),
            // presented on the pane once this popover has closed.
            Section {
                if let searchId = collection.savedSearchId {
                    SmartCollectionLinkRows(
                        savedSearchName: allSavedSearches.first(where: { $0.id == searchId })?.name,
                        onUnlink: {
                            if CollectionEditorCommit.savedSearch(nil, to: collection) { try? modelContext.save() }
                        })
                } else {
                    SmartCollectionLinkButton(hasSavedSearches: !allSavedSearches.isEmpty) {
                        opensLinkPickerOnClose = true
                        showCollectionSettingsPopover = false
                    }
                }
            } header: {
                Text(String(localized: "collection.editor.smart.header", defaultValue: "Smart Collection"))
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 420, idealWidth: 420, minHeight: 480, idealHeight: 560)
    }

    // MARK: - Documents

    @ViewBuilder
    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section header with inline sort control
            HStack(spacing: 8) {
                // Collections Manager M1: the region is now labeled "Contents"
                // (D1) — it holds documents plus headings, prose, excerpts, and
                // apparatus, not documents alone. All list-level authoring verbs
                // (Sort, Add-structural, Apparatus, Add Documents) moved up into
                // `CollectionRibbonView`, so this header is now just its label.
                Text(String(localized: "collection.section.documents",
                            defaultValue: "Contents"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer()
            }

            // Selection (UI audit A7) makes the outline rows first-class keyboard
            // citizens: click (or Tab into the list) then ↑/↓ to traverse — List
            // selection is what gives SwiftUI's NSTableView-backed list its native
            // arrow-key behavior — and ↩ toggles the selected entry's inspector
            // column. Coexists with drag reorder (`onMove` is unaffected by
            // selection) and with every in-row control (buttons/menus keep
            // receiving their own clicks; the row background click selects).
            List(selection: $selectedEntryId) {
                // #1619: a smart collection says what it is first, whatever it holds — the iOS editor's row. Untagged,
                // so selection skips it.
                if !takesHandAddedEntries {
                    Label(SmartCollectionRule.sentence, systemImage: "bolt.fill")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                if sortedEntries.isEmpty {
                    if takesHandAddedEntries {
                        Text(String(localized: "collection.documents.empty",
                                    defaultValue: "No content yet. Use the Add menu in the toolbar to add documents, headings, notes, and apparatus."))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                } else {
                    let duplicateKeys = duplicateDocumentKeys
                    let outline = CollectionOutline.linearize(sortedEntries)
                    // #1619, decision 22: a smart collection's rows are only the entries it keeps, its apparatus; its
                    // entries from before its link are listed apart, below.
                    let rows = CollectionOutline.contentsRows(
                        in: outline, collapsedHeadingIds: collapsedHeadingIds, savedSearchId: collection.savedSearchId)
                    ForEach(rows) { row in
                        outlineRow(row, outline: outline, duplicateKeys: duplicateKeys,
                                   rows: rows)
                            .padding(.leading, outlineIndent(for: row))
                            // Selectable identity for A7 keyboard traversal — the
                            // Composition/Front Matter sections above carry no tag,
                            // so they stay unselectable.
                            .tag(row.id)
                    }
                    .onMove { from, to in
                        moveVisibleRows(from, to: to, visible: rows.map(\.index))
                    }
                }
                // #1619, decision 22: a smart collection's entries from before its link, under a dimmed heading that
                // says why they are not part of it, with a button that removes them once the reader confirms — the iOS
                // editor's section. Its rows refuse selection (`selectionDisabled`), so ↩ and the inspector skip them.
                let fromBeforeLink = SmartCollectionRule.entriesFromBeforeLink(
                    in: sortedEntries, savedSearchId: collection.savedSearchId)
                if !fromBeforeLink.isEmpty {
                    // The heading is a row here: this inset list sets a section header on one line.
                    SmartCollectionEntriesFromBeforeLink(entries: fromBeforeLink, documentHeaders: documentHeaders,
                                                         onRemove: { removeEntriesFromBeforeLink() },
                                                         headingIsRow: true)
                }
            }
            .listStyle(.inset)
            // ↩ toggles the selected entry's inspector (A7) — same action as the
            // row's ⓘ button, gated to the kinds the inspector supports. Fires only
            // while focus is inside the List (an in-row text field consumes its own
            // Return before it can bubble here); `.ignored` hands anything else back
            // to the system.
            .onKeyPress(.return) {
                guard let id = selectedEntryId,
                      let entry = sortedEntries.first(where: { $0.id == id }),
                      isInspectable(entry)
                else { return .ignored }
                toggleInspector(for: id)
                return .handled
            }
            .frame(minHeight: 200, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Outline rows (Authoring Phase 4)

    /// Builds the view for one visible outline row (see the iOS editor's counterpart).
    /// Bindings index into `sortedEntries`, kept in `sortOrder` order (reindexed 0..n
    /// after every mutation), so positions align with the linearized outline. `rows`
    /// (the full visible-row list) locates this row's visible position for the A4
    /// Move Up / Move Down actions.
    @ViewBuilder
    private func outlineRow(_ row: CollectionOutline.VisibleRow,
                            outline: [CollectionOutline.OutlineItem],
                            duplicateKeys: Set<String>,
                            rows: [CollectionOutline.VisibleRow]) -> some View {
        let entry = sortedEntries[row.index]
        // A4 reorder closures: nil at the outline's edges so the actions disappear
        // rather than silently no-op.
        let pos = rows.firstIndex { $0.id == row.id } ?? 0
        let moveUp: (() -> Void)? = pos > 0
            ? { moveVisibleRowUp(pos, rows: rows) } : nil
        let moveDown: (() -> Void)? = canMoveVisibleRowDown(pos, rows: rows)
            ? { moveVisibleRowDown(pos, rows: rows) } : nil
        switch entry.entryKind {
        case .document:
            let nodeKey = "\(entry.volumeId)/\(entry.documentId)"
            MacEntryRow(
                entry: $sortedEntries[row.index],
                availableNotes: notes(for: entry),
                volumeTitle: volumeTitle(for: entry),
                documentHeader: documentHeaders[nodeKey],
                printedNumber: documentNumbers[nodeKey],
                isDuplicate: duplicateKeys.contains(nodeKey),
                onInspect: { toggleInspector(for: entry.id) },
                onOpenDocument: { openInReader(entry) },
                onDelete: { deleteEntry(at: row.index) },
                onMoveUp: moveUp,
                onMoveDown: moveDown
            )
            // Double-click opens/toggles the inspector (A7), matching the ↩ key on
            // the selected row. `simultaneousGesture` so the first click still
            // reaches List selection and the in-row controls keep their own clicks.
            // Heading rows deliberately get ↩ only — their title TextField owns
            // double-click for word selection.
            .simultaneousGesture(TapGesture(count: 2).onEnded {
                toggleInspector(for: entry.id)
            })
            // Single click refocuses the inspector on this row when it's already open (#188-E),
            // matching the iPad whole-row tap; when the inspector is closed this is a no-op so
            // the click stays pure list selection.
            .simultaneousGesture(TapGesture().onEnded {
                refocusInspectorIfOpen(for: entry.id)
            })
        case .heading:
            let range = CollectionOutline.sectionRange(of: row.index, in: outline)
            CollectionHeadingRow(
                entry: $sortedEntries[row.index],
                onDelete: { deleteEntry(at: row.index) },
                showsInlineDelete: true,
                depth: row.depth,
                isCollapsed: collapsedHeadingIds.contains(row.id),
                sectionEntryCount: range.count - 1,
                onToggleCollapse: { toggleCollapse(row.id) },
                canIndent: CollectionOutline.canIndent(row.index, in: outline),
                canOutdent: CollectionOutline.canOutdent(row.index, in: outline),
                onIndent: { indentSection(at: row.index) },
                onOutdent: { outdentSection(at: row.index) },
                onDeleteSection: { deleteSection(at: row.index) },
                onInspect: { toggleInspector(for: entry.id) },
                onMoveUp: moveUp,
                onMoveDown: moveDown
            )
        case .prose:
            CollectionProseRow(entry: $sortedEntries[row.index],
                               onDelete: { deleteEntry(at: row.index) },
                               onMoveUp: moveUp,
                               onMoveDown: moveDown)
        case .excerpt:
            CollectionExcerptRow(entry: entry,
                                 volumeTitle: volumeTitle(for: entry),
                                 onDelete: { deleteEntry(at: row.index) },
                                 onMoveUp: moveUp,
                                 onMoveDown: moveDown)
        case .generated:
            // No count for a smart collection's (#1619, decision 22): the block lists the saved search's documents,
            // and the ones the collection holds are entries from before its link, which it leaves out.
            CollectionGeneratedEntryRow(entry: entry,
                                        documentCount: takesHandAddedEntries
                                            ? sortedEntries.count { $0.entryKind == .document } : nil,
                                        onDelete: { deleteEntry(at: row.index) },
                                        onMoveUp: moveUp,
                                        onMoveDown: moveDown)
        case .unrecognized:
            // Deliberately no reorder actions: the entry belongs to a newer build
            // (Authoring Phase 1 sync guard) and offers no controls at all.
            UnrecognizedEntryRow()
        }
    }

    /// Leading indentation for a row: headings indent by their depth above level 1;
    /// body rows indent one step inside their owning section.
    private func outlineIndent(for row: CollectionOutline.VisibleRow) -> CGFloat {
        let steps = sortedEntries[row.index].entryKind == .heading
            ? max(0, row.depth - 1)
            : row.depth
        return CGFloat(steps) * 16
    }

    /// Toggles a section's collapse chevron (view state only).
    private func toggleCollapse(_ headingId: UUID) {
        if collapsedHeadingIds.contains(headingId) {
            collapsedHeadingIds.remove(headingId)
        } else {
            collapsedHeadingIds.insert(headingId)
        }
    }

    /// Moves the dragged visible row (mapped back to full-outline coordinates) through
    /// the shared engine: a heading takes its whole section with it, a document moves
    /// alone; a section dropped into its own range is refused.
    private func moveVisibleRows(_ indices: IndexSet, to newOffset: Int, visible: [Int]) {
        guard let firstVisible = indices.min(), visible.indices.contains(firstVisible) else { return }
        let from = visible[firstVisible]
        let to = newOffset >= visible.count ? sortedEntries.count : visible[newOffset]
        guard let reordered = CollectionOutline.applyingMove(
            sortedEntries, fromIndex: from, toOffset: to) else { return }
        sortedEntries = reordered
        finishOutlineMutation()
    }

    // MARK: - Move Up / Move Down (UI audit A4)

    /// Moves the visible row at `pos` one visible position up — inserts it before the
    /// previous visible row (hopping a collapsed section whole, matching what the user
    /// sees). Drives the rows' VoiceOver/context-menu Move Up action; the same engine
    /// as drag reorder, so heading rows carry their sections.
    private func moveVisibleRowUp(_ pos: Int, rows: [CollectionOutline.VisibleRow]) {
        guard pos > 0 else { return }
        moveVisibleRows(IndexSet(integer: pos), to: pos - 1, visible: rows.map(\.index))
    }

    /// Whether the visible row at `pos` can move down: a listed row must sit past its moved
    /// block (a heading's block is its whole `sectionRange`), which `moveVisibleRowDown`
    /// moves it after. In an outline every entry after the block is listed whenever this row
    /// is (a block is followed by a same-or-shallower item whose ancestors are also this row's
    /// ancestors); a smart collection's Contents leaves out its entries from before its link
    /// (`CollectionOutline.contentsRows`, #1619), so the rows are asked rather than the entries.
    private func canMoveVisibleRowDown(_ pos: Int, rows: [CollectionOutline.VisibleRow]) -> Bool {
        guard rows.indices.contains(pos) else { return false }
        let blockEnd = movedBlockEnd(of: rows[pos].index)
        return rows[(pos + 1)...].contains { $0.index >= blockEnd }
    }

    /// Moves the visible row at `pos` one visible position down — inserts it after the
    /// first visible row past its own moved block (so an expanded heading hops its next
    /// sibling block, and a collapsed section below is hopped whole). Drives the rows'
    /// VoiceOver/context-menu Move Down action.
    private func moveVisibleRowDown(_ pos: Int, rows: [CollectionOutline.VisibleRow]) {
        let visible = rows.map(\.index)
        guard rows.indices.contains(pos) else { return }
        let blockEnd = movedBlockEnd(of: visible[pos])
        guard let nextPos = visible.indices.first(where: { visible[$0] >= blockEnd }) else { return }
        moveVisibleRows(IndexSet(integer: pos), to: nextPos + 1, visible: visible)
    }

    /// The exclusive end of the block `applyingMove` would carry for the entry at
    /// `fullIndex`: a heading's whole `sectionRange`, any other row just itself.
    private func movedBlockEnd(of fullIndex: Int) -> Int {
        guard sortedEntries.indices.contains(fullIndex) else { return sortedEntries.count }
        if sortedEntries[fullIndex].entryKind == .heading {
            let items = CollectionOutline.linearize(sortedEntries)
            return CollectionOutline.sectionRange(of: fullIndex, in: items).upperBound
        }
        return fullIndex + 1
    }

    /// Deletes a single entry (a document/prose row's inline trash, or a heading's
    /// "Delete Heading Only" — its contents stay and sub-headings bubble up).
    private func deleteEntry(at index: Int) {
        guard sortedEntries.indices.contains(index) else { return }
        collapsedHeadingIds.remove(sortedEntries[index].id)
        if inspectedEntryId == sortedEntries[index].id { inspectedEntryId = nil }
        if selectedEntryId == sortedEntries[index].id { selectedEntryId = nil }
        GeneratedSummary.deleteHeadnoteDraft(for: sortedEntries[index], in: modelContext)
        modelContext.delete(sortedEntries[index])
        sortedEntries.remove(at: index)
        finishOutlineMutation()
    }

    /// Deletes the heading at `index` and every entry in its section range (the user
    /// confirmed in the row's dialog).
    private func deleteSection(at index: Int) {
        let items = CollectionOutline.linearize(sortedEntries)
        let range = CollectionOutline.sectionRange(of: index, in: items)
        guard range.upperBound <= sortedEntries.count else { return }
        for i in range.reversed() {
            collapsedHeadingIds.remove(sortedEntries[i].id)
            if inspectedEntryId == sortedEntries[i].id { inspectedEntryId = nil }
            if selectedEntryId == sortedEntries[i].id { selectedEntryId = nil }
            GeneratedSummary.deleteHeadnoteDraft(for: sortedEntries[i], in: modelContext)
            modelContext.delete(sortedEntries[i])
            sortedEntries.remove(at: i)
        }
        finishOutlineMutation()
    }

    /// Removes a smart collection's entries from before its link (the reader confirmed in
    /// `SmartCollectionEntriesFromBeforeLink`'s dialog; #1619, decision 22), through the rule the iOS
    /// editor calls too, then forgets any view state that named them.
    private func removeEntriesFromBeforeLink() {
        let removed = CollectionEntryOrdering.removeEntriesFromBeforeLink(
            of: collection, outline: &sortedEntries, modelContext: modelContext)
        guard !removed.isEmpty else { return }
        collapsedHeadingIds.subtract(removed)
        if let inspected = inspectedEntryId, removed.contains(inspected) { inspectedEntryId = nil }
        if let selected = selectedEntryId, removed.contains(selected) { selectedEntryId = nil }
        finishOutlineMutation()
    }

    /// Indents the section at `index` one level via the shared outline mutation.
    private func indentSection(at index: Int) {
        CollectionOutline.indentSection(at: index, in: sortedEntries)
        try? modelContext.save()
    }

    /// Outdents the section at `index` one level via the shared outline mutation.
    private func outdentSection(at index: Int) {
        CollectionOutline.outdentSection(at: index, in: sortedEntries)
        try? modelContext.save()
    }

    /// The shared tail of every outline mutation: reindex `sortOrder` 0..n, normalize
    /// heading levels (no orphan jumps persist), and save — in that order, matching the
    /// iOS editor (`CollectionEditorView.finishOutlineMutation`). Reindexing must come
    /// FIRST: `CollectionOutline.normalize` linearizes by `sortOrder`, so running it
    /// against stale pre-mutation orders would reconstruct the old arrangement and
    /// silently no-op, persisting orphan levels. The numbering is `CollectionEntryOrdering.renumber`
    /// (#1416), which also numbers, after the outline, an entry added elsewhere that the outline has
    /// not followed yet.
    private func finishOutlineMutation() {
        CollectionEntryOrdering.renumber(sortedEntries, in: collection)
        CollectionOutline.normalize(sortedEntries)
        try? modelContext.save()
    }

    /// Writes the introduction onto the model, live. An effectively empty introduction
    /// stores `nil` in both fields, so exports omit the block entirely.
    private func saveIntroduction(rtf: Data?, plain: String) {
        let trimmed = plain.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            collection.introductionText = nil
            collection.introductionRichText = nil
        } else {
            collection.introductionText = plain
            collection.introductionRichText = rtf
        }
        try? modelContext.save()
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup {
            // Composer v2 (§B): the unified pane toolbar — ＋ Add · Sort · ⚙ Collection · Export ·
            // inspector toggle. (The everyday collection picker is a leading `.navigation` item on
            // the root view.) Lifts the authoring verbs from the deleted CollectionRibbonView.
            Menu {
                // #1619: a smart collection takes none of the four hand-added kinds (its Contents says why); the
                // Apparatus blocks stay, since its exports build them over its search's documents.
                Button { showAddDocuments = true } label: {
                    Label(String(localized: "collection.ribbon.addDocuments", defaultValue: "Add Documents…"),
                          systemImage: "plus.rectangle.on.folder")
                }
                .disabled(!takesHandAddedEntries)
                Button { addStructuralEntry(kind: .heading) } label: {
                    Label(String(localized: "collection.add.heading", defaultValue: "Add Section Heading"),
                          systemImage: "number")
                }
                .disabled(!takesHandAddedEntries)
                Button { addStructuralEntry(kind: .prose) } label: {
                    Label(String(localized: "collection.add.prose", defaultValue: "Add Note Block"),
                          systemImage: "text.alignleft")
                }
                .disabled(!takesHandAddedEntries)
                Button { showAddHighlights = true } label: {
                    Label(String(localized: "collection.ribbon.addPassages", defaultValue: "Add Passages…"),
                          systemImage: "text.quote")
                }
                .disabled(orderedDocumentKeys.isEmpty || !takesHandAddedEntries)
                Divider()
                // #830: the macOS half of the collection entry point, absent until now. Reuses the
                // iOS menus' localization key so the three surfaces cannot state different things.
                Button {
                    Task {
                        do {
                            let docs = try await TripPacketSeed.resolve(
                                collection: collection, appState: appState,
                                modelContext: modelContext)
                            planPickerRequest = PlanPickerRequest(
                                documents: docs, includeSource: true, includeExternalRefs: true,
                                // The collection as every list row names it, and the plan after its trimmed name — an
                                // unnamed one makes an untitled plan (#1464 review, round 1).
                                basis: String(format: String(
                                    localized: "archiveVisit.basis.collection %@",
                                    defaultValue: "from the collection “%@”"),
                                    CollectionEditorNaming.listName(savedName: collection.name)),
                                suggestedName: collection.name.trimmingCharacters(in: .whitespacesAndNewlines))
                        } catch {
                            addToVisitError = error.localizedDescription
                        }
                    }
                } label: {
                    Label(String(localized: "collection.addToVisit",
                                 defaultValue: "Add to Archives Visit…"),
                          systemImage: "building.columns")
                }
                // Content or a saved search — the same rule `canExport` applies (:848) and the
                // same one the iOS editor's gates now state. Excerpts carry real document
                // provenance; a smart collection resolves at build time (Phase 0).
                .disabled(orderedDocumentKeys.isEmpty
                          && !sortedEntries.contains { $0.entryKind == .excerpt
                              && !$0.volumeId.isEmpty && !$0.documentId.isEmpty }
                          && collection.savedSearchId == nil)
                Divider()
                Menu {
                    ForEach(CollectionGeneratedBlockType.allCases) { blockType in
                        Button { addGeneratedEntry(type: blockType) } label: {
                            Label(blockType.displayName, systemImage: blockType.systemImage)
                        }
                    }
                } label: {
                    Label(String(localized: "collection.add.apparatus", defaultValue: "Apparatus"),
                          systemImage: "list.bullet.rectangle")
                }
            } label: {
                Label(String(localized: "collection.ribbon.add", defaultValue: "Add"), systemImage: "plus")
            }
            .help(String(localized: "collection.ribbon.add.help",
                         defaultValue: "Add documents, a section heading, a note block, passages, or a generated apparatus block"))

            Menu {
                ForEach(CollectionDateSortScope.allCases, id: \.self) { scope in
                    Button { sortByDate(scope) } label: {
                        Label(scope.displayLabel, systemImage: scope.systemImage)
                    }
                }
            } label: {
                // Composer v2 §Export: the trigger reads "Sort" (the menu supplies the ⌄); the two
                // date-sort scopes live inside.
                Label(String(localized: "collection.sort.short", defaultValue: "Sort"),
                      systemImage: "arrow.up.arrow.down")
            }
            .accessibilityLabel(String(localized: "collection.sort.date.accessibility",
                                       defaultValue: "Sort by date"))
            .disabled(sortedEntries.isEmpty)

            Button { showCollectionSettingsPopover = true } label: {
                Label(String(localized: "collection.toolbar.settings", defaultValue: "Collection"),
                      systemImage: "gearshape")
            }
            .help(String(localized: "collection.toolbar.settings.help",
                         defaultValue: "Edit this collection’s name, front matter, and composition"))
            .popover(isPresented: $showCollectionSettingsPopover, arrowEdge: .top) {
                macCollectionSettingsForm
                    // #1687: Link to Saved Search… closes the popover, and its going opens the picker on the pane.
                    .onDisappear {
                        guard opensLinkPickerOnClose else { return }
                        opensLinkPickerOnClose = false
                        showLinkSavedSearch = true
                    }
            }

            Button { showExport = true } label: {
                Label(String(localized: "collection.toolbar.export", defaultValue: "Export…"),
                      systemImage: "square.and.arrow.up")
            }
            .help(String(localized: "collection.toolbar.export.help",
                         defaultValue: "Export this collection as a PDF, HTML page, or Word document — includes document text and any attached research notes"))
            // A smart collection (savedSearchId set) exports with zero static entries.
            .disabled(sortedEntries.isEmpty && collection.savedSearchId == nil)

            // Document inspector toggle — opens/closes the trailing inspector on the selected (or
            // first) document/heading entry.
            Button {
                if inspectedEntryId != nil {
                    inspectedEntryId = nil
                } else {
                    // Gate the target to the kinds the inspector supports (document/heading),
                    // exactly like the ↩ handler and the per-row ⓘ. `selectedEntryId` can be any
                    // kind (every outline row is `.tag`-selectable), so a prose/apparatus selection
                    // would otherwise open a blank document-shaped inspector; fall back to the first
                    // inspectable entry when the selection isn't one.
                    let selectedInspectable = selectedEntryId.flatMap { id in
                        sortedEntries.first { $0.id == id && isInspectable($0) }?.id
                    }
                    inspectedEntryId = selectedInspectable ?? sortedEntries.first { isInspectable($0) }?.id
                }
            } label: {
                Label(String(localized: "collection.toolbar.inspector", defaultValue: "Document Inspector"),
                      systemImage: "sidebar.trailing")
            }
            // Enabled only when there is an inspectable entry — otherwise the button would be a
            // silent no-op (a collection of only prose/apparatus rows has nothing to inspect, and
            // nor has a smart collection, whose documents and headings it leaves out).
            .disabled(!sortedEntries.contains { isInspectable($0) })
        }
    }

    // MARK: - Helpers

    /// Whether the entry inspector opens on `entry` — from ↩, the toolbar's Document Inspector or its fallback: a
    /// document or a section heading that Contents lists. Not a smart collection's entries from before its link
    /// (#1619, decision 22), which Contents lists apart and nothing the collection produces reads, so their overrides
    /// would change nothing; a smart collection has nothing to inspect.
    private func isInspectable(_ entry: CollectionEntry) -> Bool {
        (entry.entryKind == .document || entry.entryKind == .heading)
            && !SmartCollectionRule.leavesOut(entry.entryKind, savedSearchId: collection.savedSearchId)
    }

    private func notes(for entry: CollectionEntry) -> [ResearchNote] {
        allNotes.filter { $0.documentId == entry.documentId && $0.volumeId == entry.volumeId }
    }

    private func volumeTitle(for entry: CollectionEntry) -> String {
        let manifest = appState.manifestStore.diffResult?.known
            ?? appState.manifestStore.bundledEntries
        return manifest.first(where: { $0.volumeId == entry.volumeId })?.title ?? entry.volumeId
    }

    /// Numbers the outline `0..<n` in its order, and after it any entry the model holds that the outline has not
    /// followed yet (`CollectionEntryOrdering.renumber`, #1416), then saves.
    private func reindexEntries() {
        CollectionEntryOrdering.renumber(sortedEntries, in: collection)
        // Persist the new sort orders immediately so they survive the next render cycle.
        try? modelContext.save()
    }

    /// Whether this collection takes documents, headings, note blocks and passages added by hand: not when it is linked
    /// to a saved search (`SmartCollectionRule`, #1619). Read from the model, so a link made on another device counts.
    private var takesHandAddedEntries: Bool {
        SmartCollectionRule.takesHandAddedEntries(savedSearchId: collection.savedSearchId)
    }

    /// Appends a structural entry (a section heading or a prose block) to the collection, through the append the iOS
    /// editor shares (`CollectionEntryOrdering.appendBlock`, #1416). Heading/prose entries carry empty document
    /// identifiers and use `text` (Phase 3a). A smart collection takes neither (#1619), and its outline is not
    /// renumbered and saved for nothing: a position written, even unchanged, stamps the entry modified.
    private func addStructuralEntry(kind: CollectionEntryKind) {
        guard CollectionEntryOrdering.appendBlock(kind: kind, to: collection, outline: &sortedEntries,
                                                  modelContext: modelContext) != nil else { return }
        reindexEntries()
    }

    /// Inserts a generated apparatus entry (Authoring Phase 6) at the block type's
    /// default position — front-matter types before the first entry, back-matter types
    /// at the end. The entry stores only the block TYPE; it stays fully movable and
    /// deletable like a prose block afterwards.
    private func addGeneratedEntry(type: CollectionGeneratedBlockType) {
        let entry = CollectionEntry(
            collectionId: collection.id,
            documentId: "",
            volumeId: "",
            sortOrder: 0
        )
        entry.entryKind = .generated
        entry.generatedBlockType = type.rawValue
        entry.collection = collection
        modelContext.insert(entry)
        switch type.defaultPosition {
        case .frontMatter: sortedEntries.insert(entry, at: 0)
        case .backMatter:  sortedEntries.append(entry)
        }
        reindexEntries()
    }

    /// Applies a one-tap composition preset (Composer redesign 4a): overwrites the collection's
    /// composition fields, then inserts the preset's not-yet-present apparatus blocks through
    /// `addGeneratedEntry` so the `sortedEntries` outline mirror and `sortOrder` stay consistent.
    /// Non-destructive: existing apparatus and document entries are kept.
    private func applyPreset(_ preset: CollectionPreset) {
        preset.applyFields(to: collection)
        let present = Set(sortedEntries.compactMap {
            $0.entryKind == .generated ? $0.generatedBlockType : nil
        })
        for block in preset.apparatusBlocks(notAlreadyIn: present) {
            addGeneratedEntry(type: block)
        }
    }

    /// Appends document entries at the end of the entry list in the given order.
    /// Duplicates are allowed (A4) — repeats get an "Also in collection" badge instead
    /// of being silently skipped.
    ///
    /// - Returns: Whether the collection took them: `false` for a smart collection (#1619), so
    ///   the Add Documents sheet's commit confirms nothing it did not add.
    @discardableResult
    private func appendEntries(_ pairs: [(documentId: String, volumeId: String)]) -> Bool {
        CollectionDocumentDiscovery.appendEntries(
            pairs, collection: collection,
            sortedEntries: &sortedEntries, modelContext: modelContext)
    }

    /// Document keys appearing on more than one entry, for the "Also in collection"
    /// badge (A4). Cheap O(n) recompute over the pane-level entry list.
    private var duplicateDocumentKeys: Set<String> {
        CollectionDocumentDiscovery.duplicateDocumentKeys(in: sortedEntries)
    }

    /// Keys of every document currently in the collection, handed to the Add Documents
    /// sheet for its "In collection" row indicator.
    private var existingDocumentKeys: Set<String> {
        Set(sortedEntries.filter { $0.entryKind == .document }
            .map { CollectionDocumentDiscovery.documentKey(volumeId: $0.volumeId,
                                                           documentId: $0.documentId) })
    }

    /// Ordered (deduplicated) keys of the collection's document entries — scopes the
    /// Add Highlighted Passages sheet to this collection's documents, in reading order.
    private var orderedDocumentKeys: [String] {
        var seen: Set<String> = []
        return sortedEntries.filter { $0.entryKind == .document }
            .map { CollectionDocumentDiscovery.documentKey(volumeId: $0.volumeId,
                                                           documentId: $0.documentId) }
            .filter { seen.insert($0).inserted }
    }

    /// Appends excerpt entries (Authoring Phase 5) at the end of the entry list via the
    /// shared `CollectionExcerpts` factory, then saves — the excerpt sibling of
    /// `appendEntries`. A smart collection takes none, and nothing is saved (#1619).
    private func appendExcerpts(_ captures: [CollectionExcerptCapture]) {
        guard CollectionExcerpts.append(captures, to: collection,
                                        sortedEntries: &sortedEntries, modelContext: modelContext) else { return }
        try? modelContext.save()
    }

    /// Sorts `sortedEntries` in ascending chronological order, then persists the new
    /// `sortOrder` values to SwiftData.
    ///
    /// **Sort key hierarchy (most precise wins):**
    /// 1. Per-document `date_iso` from `document_dates` (loaded asynchronously at pane entry).
    ///    This gives individual-document precision within a volume — e.g. memoranda from
    ///    the same subseries sort correctly relative to each other.
    /// 2. Volume `dateRange.earliest` from the manifest. Used when a document isn't indexed
    ///    or genuinely lacks a date, so all documents from a later volume still sort after
    ///    those from an earlier volume.
    /// 3. `"9999"` sentinel — documents with no date information sort to the end.
    private func sortByDate(_ scope: CollectionDateSortScope = .wholeCollection) {
        let manifest = appState.manifestStore.diffResult?.known
            ?? appState.manifestStore.bundledEntries
        sortedEntries = CollectionEntryData.sortedByDate(
            sortedEntries, documentDates: documentDates, manifest: manifest,
            withinSections: scope == .withinSections)
        reindexEntries()
    }

    // MARK: - Committing edits (#1413's shape on the Mac)

    /// A binding to one of the pane's own field copies whose setter also commits the reader's edit to the collection:
    /// `commit` — a `CollectionEditorCommit` rule — writes that one field when the edit changes what is saved (trimmed,
    /// `nil` when empty, for text) and says whether it did, and a write is then saved, so it survives the app being
    /// closed. Only the reader's edits come through here: `FrontMatterModelSync` follows a change made elsewhere by
    /// writing the copy directly, so following never commits anything. The iOS editor's `committing` is the same
    /// shape; this one records no active project, which the Mac pane never added.
    private func committing<Value>(_ field: Binding<Value>,
                                   _ commit: @escaping (Value) -> Bool) -> Binding<Value> {
        Binding(get: { field.wrappedValue }, set: { newValue in
            field.wrappedValue = newValue
            if commit(newValue) { try? modelContext.save() }
        })
    }

    /// Commits the Note the popover's editor reports (#1449) — its plain text, the note being a plain `String?` — the
    /// way `committing` commits a bound field: the pane's copy follows the editor, and the collection's note is written,
    /// and saved, only when the edit changes it.
    private func commitNote(_ plain: String) {
        note = plain
        if CollectionEditorCommit.text(plain, to: \.note, of: collection) { try? modelContext.save() }
    }
}

// MARK: - MacEntryRow

/// A single **document** row in the collection's outline — a pure report (Collections
/// Manager M2, D3). Displays document number, header (loaded from `document_cache`), and
/// volume title, plus the shared read-only `entryStatusChips` (body depth, note count or
/// "Notes off", override flags). All per-document editing — body depth and per-note
/// selection — lives in the trailing `CollectionEntryInspector` column, not the row; the
/// row's earlier inline note previews and multi-note picker are gone. Provides:
/// - A delete button that removes this entry from the collection
/// - An external-link button to open the document on history.state.gov
/// - An ⓘ button that shows the entry in the pane's trailing `.inspector` column
///   (UI audit B8 — previously a modal sheet that blocked the outline)
/// - Move Up / Move Down as VoiceOver actions + context-menu items (UI audit A4)
///
/// The document number is the volume's printed one (#1406): "Document 373a" for `d373a`, which
/// used to show its raw id because only `d` + an integer read as a number.
private struct MacEntryRow: View {

    @Binding var entry: CollectionEntry
    let availableNotes: [ResearchNote]
    let volumeTitle: String
    /// Document header fetched from `document_cache` by `CollectionDetailPane`.
    let documentHeader: String?
    /// The printed document number the index stores (`document_cache.document_number`), fetched
    /// by `CollectionDetailPane`; `nil` when the document is not indexed. No default, so the
    /// row's one construction site cannot leave it out and silently show `eta_d1` and `appA`
    /// rows by their raw ids again — no test draws this macOS-only row, and the compiler is the
    /// guard (#1406 review).
    let printedNumber: String?
    /// Whether this document appears on more than one entry of the collection — shows
    /// the subtle "Also in collection" badge (A4, duplicates allowed).
    var isDuplicate: Bool = false
    /// Toggles this entry in the pane's inspector column (UI audit B8): the ⓘ button
    /// calls it, and `CollectionDetailPane` shows/retargets/closes the trailing
    /// `CollectionEntryInspector` accordingly.
    let onInspect: () -> Void
    /// Opens this entry in the app's reader (#755 / audit M-19). The external history.state.gov
    /// button beside it stays — the published text is a legitimately different destination — but it
    /// was the ONLY open on the row, which made the app's own reader unreachable from a collection.
    let onOpenDocument: () -> Void
    let onDelete: () -> Void
    /// Moves the row one visible position up (UI audit A4); `nil` omits the action.
    var onMoveUp: (() -> Void)? = nil
    /// Moves the row one visible position down (UI audit A4); `nil` omits the action.
    var onMoveDown: (() -> Void)? = nil

    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Document info column
            VStack(alignment: .leading, spacing: 2) {
                Text(documentLabel)
                    .font(.body)

                if let header = documentHeader, !header.isEmpty {
                    Text(header)
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(volumeTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                // Duplicate marker (A4): the same document appears on another entry.
                if isDuplicate {
                    Label(String(localized: "collection.entry.duplicate",
                                 defaultValue: "Also in collection"),
                          systemImage: "doc.on.doc")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Read-only status chips (Collections Manager M2, D3): the row is now a
                // pure report — body depth, note count, and override flags project the
                // inspector's state so the list stays scannable. All editing is in the ⓘ
                // inspector.
                BreadcrumbFlowLayout(horizontalSpacing: 4, verticalSpacing: 4) {
                    entryStatusChips(entry: entry, availableNoteCount: availableNotes.count)
                }
                .padding(.top, 2)
            }

            Spacer()

            // Action controls
            HStack(spacing: 6) {
                // Document Configure (Composer v2 §D) — a labeled pill, not a bare ⓘ glyph; opens
                // (or retargets/closes) the trailing Document inspector column (B8).
                ConfigurePill(action: onInspect)
                    .help(String(localized: "collection.entry.inspect.help",
                                 defaultValue: "Show this document’s notes, highlights, tags, and provenance in the inspector panel — click again to close it"))

                // Open in the app's reader (#755) — placed BEFORE the external link, because the
                // in-app document (with its notes, highlights and cross-references) is what a
                // researcher reviewing their own collection almost always wants.
                Button {
                    onOpenDocument()
                } label: {
                    Image(systemName: "book.pages")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(String(localized: "collection.entry.openInApp.help",
                             defaultValue: "Open this document in FRUS Explorer"))

                // Open on history.state.gov
                Button {
                    if let url = URL(string:
                        "https://history.state.gov/historicaldocuments/\(entry.volumeId)/\(entry.documentId)"
                    ) {
                        openURL(url)
                    }
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(String(localized: "collection.entry.openExternal.help",
                             defaultValue: "Open this document on history.state.gov"))

                // Delete from collection
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red.opacity(0.6))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "collection.entry.delete.a11y",
                                           defaultValue: "Remove entry"))
                .help(String(localized: "collection.entry.delete.help",
                             defaultValue: "Remove this document from the collection"))
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 4)
        .entryMoveControls(onMoveUp: onMoveUp, onMoveDown: onMoveDown)
    }

    // MARK: - Helpers

    /// The row's document label — "Document N" with the volume's printed number, "Unnumbered (d710a-1)" for a
    /// document the volume prints without one (#1493), else the raw id (`CitableDocumentNumber.rowLabel`, #1406).
    private var documentLabel: String {
        CitableDocumentNumber.rowLabel(printed: printedNumber, documentId: entry.documentId)
    }
}

// MARK: - One copy of each note and saved search (#1791)

extension MacCollectionManagerView {
    /// Every note, one copy of each however many are stored under its id (`DuplicateCopies`),
    /// newest first: what the detail pane's entries, note pickers and exports read.
    private var allNotes: [ResearchNote] { ResearchNote.oneCopyEach(allNoteCopies) }
}

extension CollectionDetailPane {
    /// Every saved search, one copy of each, newest first: what Link to Saved Search… offers and
    /// what names a smart collection's search.
    private var allSavedSearches: [SavedSearch] { SavedSearch.oneCopyEach(allSavedSearchCopies) }
}

#endif
