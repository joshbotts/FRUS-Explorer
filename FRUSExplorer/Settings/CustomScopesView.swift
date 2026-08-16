// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - CustomScopesView

/// The management pane for user-defined volume scopes (#258 Phase 1): list, create,
/// edit, delete. Follows the `UserTagsView` pane pattern (a `@Query`-driven List row
/// in Settings → Research).
///
/// Each row shows the scope's **"N of M indexed"** state (the reviewed sketch's picker
/// rule): a scope may legitimately name volumes the user has not downloaded — raw
/// manifest membership, §8-Q1(a) — and this is where that becomes visible instead of
/// surprising.
///
/// iOS-first (Phase 1); the macOS `FRUSSettingsView` pane is Phase 2. The *records*
/// sync everywhere via CloudKit regardless, and the shared `SearchFilterView` scope
/// section already consumes them on both platforms.
///
/// Version history:
///   1.0 — #258 Phase 1: initial implementation
///   1.1 — #258 Phase 4: the editor gains the four rich selection facets ("Add Volumes
///          By…" — subject / person / manifest tag / coverage-years+editor), each a
///          picker whose matches UNION into the selection; the person facet reuses
///          PersonMergePickerSheet with a facet title
///   1.2 — #332 review: the three new facet pickers gain explicit macOS sheet chromes
///          (plain VStack + header / search field / bottom-right buttons — the
///          `PersonMergePickerSheet` idiom; no `NavigationStack`-in-sheet on macOS);
///          Save is disabled while a person-facet union is still resolving, so a fast
///          Save can no longer snapshot the selection before the volumes land
///   1.3 — #258 Phase 5: scope rows gain a "Word Cloud" context-menu launch
///          (`pendingWordCloud` hand-off, the SavedSearchesView row idiom; disabled
///          while no member volume is indexed)
///   1.5 — S-3b: the "New Scope…" row ends the list on both platforms, replacing the navigation-bar
///          "+" — which, with the old `ContentUnavailableView` filling the whole List, was the only
///          way into an empty Scopes screen
///   1.4 — #366: the coverage facet accepts an editor name with no year range
///          (editor-only matching, ignoring coverage dates); a half-entered range gets a
///          targeted prompt; `save()` no longer swallows a throwing `modelContext.save()`
struct CustomScopesView: View {

    @Environment(AppState.self) private var appState
    /// #338 step 2: this scene's identity, so a word-cloud hand-off is addressed to THIS window.
    @Environment(\.sceneID) private var sceneID
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \CustomVolumeScope.name) private var scopes: [CustomVolumeScope]

    /// The scope being edited in the sheet, or `nil`. A fresh unsaved instance for
    /// "create" (inserted only on Save), an existing record for "edit".
    @State private var editorTarget: CustomVolumeScope?
    /// Whether `editorTarget` is a not-yet-inserted draft (create) vs a live record (edit).
    @State private var editorIsDraft = false
    /// The scope pending delete confirmation, or `nil`.
    ///
    /// A bare `.onDelete` was enabling SwiftUI's default full-swipe, so one uninterrupted gesture
    /// destroyed a hand-curated volume set with no confirmation and no undo. macOS has always
    /// asked ("Delete Scope?"); this asks the same question in the same words.
    @State private var scopeToDelete: CustomVolumeScope?

    var body: some View {
        List {
            Section {
                if scopes.isEmpty {
                    Text(String(localized: "settings.scopes.empty.detail",
                                defaultValue: "Create a named set of volumes to use as a search scope — for example, every volume covering a crisis, a region, or an administration."))
                        .foregroundStyle(.secondary)
                        .font(.callout)
                } else {
                    ForEach(scopes) { scope in
                        Button {
                            editorIsDraft = false
                            editorTarget = scope
                        } label: {
                            scopeRow(scope)
                        }
                        .buttonStyle(.plain)
                        // `allowsFullSwipe: false` rather than a bare `.onDelete`: the swipe arms
                        // the confirmation instead of performing the delete, so a stray full
                        // swipe cannot destroy a hand-curated scope.
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                scopeToDelete = scope
                            } label: {
                                Label(String(localized: "common.delete", defaultValue: "Delete"),
                                      systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            wordCloudAction(scope)
                        }
                    }
                }

                // S-3b: every list ends with its New row. The old "+" lived in the navigation bar,
                // where a reader who had never gone looking for it never found it — and with the
                // empty state occupying the whole List, an empty Scopes screen offered no way in
                // at all except that "+".
                SettingsNewItemRow(label: String(localized: "settings.scopes.new",
                                                 defaultValue: "New Scope…")) {
                    editorIsDraft = true
                    editorTarget = CustomVolumeScope(name: "")
                }
            } footer: {
                Text(String(localized: "settings.scopes.footer",
                            defaultValue: "Scopes sync to your other devices via iCloud. Deleting a scope does not affect searches already run with it."))
            }
        }
        .navigationTitle(String(localized: "settings.scopes.title",
                                defaultValue: "Volume Scopes"))
        .sheet(item: $editorTarget) { target in
            CustomScopeEditorView(scope: target, isDraft: editorIsDraft)
                .environment(appState)
        }
        // The same dialog the macOS pane raises, in the same words and under the same keys.
        .confirmationDialog(
            String(localized: "settings.scopes.delete.title", defaultValue: "Delete Scope?"),
            isPresented: Binding(get: { scopeToDelete != nil },
                                 set: { if !$0 { scopeToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button(String(localized: "common.delete", defaultValue: "Delete"),
                   role: .destructive) {
                if let scope = scopeToDelete {
                    modelContext.delete(scope)
                    try? modelContext.save()
                }
                scopeToDelete = nil
            }
            Button(String(localized: "common.cancel", defaultValue: "Cancel"),
                   role: .cancel) { scopeToDelete = nil }
        } message: {
            Text(String(localized: "settings.scopes.delete.message",
                        defaultValue: "Searches already run with this scope are unaffected."))
        }
    }

    /// The row context menu's word-cloud launch (#258 Phase 5): hands the scope to
    /// the shared `pendingWordCloud` sheet (the `SavedSearchesView` row idiom).
    /// Disabled when nothing is indexed — the cloud reads indexed text, so a
    /// zero-indexed scope could only ever render an empty cloud.
    @ViewBuilder
    private func wordCloudAction(_ scope: CustomVolumeScope) -> some View {
        let resolution = CustomScopeResolver.indexedResolution(
            memberVolumeIds: scope.volumeIds, indexed: appState.indexedVolumeIds)
        Button {
            appState.openWordCloud(.customScope(id: scope.id), from: sceneID)
        } label: {
            Label { Text(String(localized: "settings.scopes.row.wordCloud",
                                defaultValue: "Word Cloud")) }
                icon: { Image(systemName: WordCloudGlyph.symbol) }
        }
        .disabled(resolution == .noIndexedMembers)
    }

    /// One scope row: name, member count, and the indexed-coverage state.
    @ViewBuilder
    private func scopeRow(_ scope: CustomVolumeScope) -> some View {
        let indexed = CustomScopeResolver.indexedResolution(
            memberVolumeIds: scope.volumeIds, indexed: appState.indexedVolumeIds)
        VStack(alignment: .leading, spacing: 3) {
            Text(scope.name.isEmpty
                 ? String(localized: "settings.scopes.unnamed", defaultValue: "Untitled Scope")
                 : scope.name)
                .font(.body)
            HStack(spacing: 6) {
                if case .resolved(let ids) = indexed {
                    Text(String(format: String(
                        localized: "settings.scopes.row.indexed %lld %lld",
                        defaultValue: "%lld of %lld volumes indexed"),
                        Int64(ids.count), Int64(scope.volumeIds.count)))
                } else {
                    Label(String(format: String(
                        localized: "settings.scopes.row.noneIndexed %lld",
                        defaultValue: "%lld volumes — none indexed yet"),
                        Int64(scope.volumeIds.count)),
                          systemImage: "exclamationmark.triangle")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - CustomScopeEditorView

/// The scope editor (#258 Phase 1): name + volume multi-select over the **whole
/// manifest** (§8-Q1(a) — membership is meaningful before download), with the two
/// cheap selection facets from the sketch's §5: subseries grouping (with per-subseries
/// add/remove-all — the subseries facet) and title search (the title facet). The
/// richer facets (subject tags, people-mentions, coverage dates) are Phase 4.
///
/// Saving replaces `volumeIds` **wholesale** (deduped, sorted) — never an in-place
/// mutation (the `Project.swift` sync-hazard warning) — and stamps `lastModified`.
///
/// ## Platform bodies (#258 Phase 2)
/// iOS keeps the `NavigationStack` + `.searchable` sheet. macOS gets its own explicit
/// chrome — header / inline filter field / list / bottom-right Cancel–Save — the repo's
/// established mac-sheet idiom, resolving Phase 1's caution against `.searchable` inside
/// a sheet-hosted stack on macOS. The list content and save logic are shared.
struct CustomScopeEditorView: View {

    /// The record being edited. For a draft (create), it is not yet in the context and
    /// is inserted on Save; cancelling discards it entirely.
    let scope: CustomVolumeScope
    /// `true` when `scope` is an uninserted draft.
    let isDraft: Bool

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selection: Set<String> = []
    @State private var filterText: String = ""

    /// Which rich-facet picker is presented (#258 Phase 4), or `nil`.
    @State private var facetSheet: FacetSheet?

    /// In-flight person-facet unions (#332 review). The person facet is the one facet
    /// whose volume set resolves asynchronously (a `PersonMentionStore` query) AFTER the
    /// picker dismisses — so a fast Save could snapshot `selection` before the union
    /// lands and silently drop the person's volumes. Save is disabled while nonzero.
    @State private var pendingPersonUnions = 0

    /// The four rich selection facets (sketch §5). Each presents a picker whose result
    /// is UNIONED into `selection` — facets add, they never replace.
    private enum FacetSheet: String, Identifiable {
        case subject, person, tag, coverage
        var id: String { rawValue }
    }

    /// The whole manifest (known entries, falling back to the bundled manifest before the
    /// first live fetch), grouped by subseries in chronological order.
    private var subseriesGroups: [(subseries: String, volumes: [VolumeManifestEntry])] {
        let all = appState.manifestStore.diffResult?.known ?? appState.manifestStore.bundledEntries
        let filtered = filterText.isEmpty
            ? all
            : all.filter {
                $0.title.localizedCaseInsensitiveContains(filterText)
                    || $0.volumeId.localizedCaseInsensitiveContains(filterText)
            }
        return Dictionary(grouping: filtered, by: \.subseries)
            .map { (subseries: $0.key, volumes: $0.value.sorted { $0.volumeId < $1.volumeId }) }
            .sorted { $0.subseries < $1.subseries }
    }

    /// How many selected members are currently indexed — the honesty line the reviewed
    /// sketch requires wherever a scope is shown.
    private var indexedSelectedCount: Int {
        selection.intersection(appState.indexedVolumeIds).count
    }

    var body: some View {
        #if os(macOS)
        macBody
        #else
        iosBody
        #endif
    }

    /// The editor's title, shared by both chromes.
    private var editorTitle: String {
        isDraft
            ? String(localized: "settings.scopes.editor.title.new", defaultValue: "New Scope")
            : String(localized: "settings.scopes.editor.title.edit", defaultValue: "Edit Scope")
    }

    /// The shared footer line: selection + indexed counts.
    private var footerText: String {
        String(format: String(
            localized: "settings.scopes.editor.footer %lld %lld",
            defaultValue: "%lld volumes selected · %lld indexed. Volumes you haven't downloaded stay in the scope and take effect once indexed."),
            Int64(selection.count), Int64(indexedSelectedCount))
    }

    /// Whether Save is allowed: a non-blank name, at least one member, and no
    /// person-facet union still resolving (#332 review — see `pendingPersonUnions`).
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !selection.isEmpty
            && pendingPersonUnions == 0
    }

    /// Seeds editor state from the record (both chromes' onAppear).
    private func seed() {
        name = scope.name
        selection = Set(scope.volumeIds)
    }

    /// The "Add Volumes By…" facet menu (#258 Phase 4): the four rich facets, each
    /// opening a picker that UNIONS matches into the selection. Shared by both bodies.
    private var addByFacetMenu: some View {
        Menu {
            Button {
                facetSheet = .subject
            } label: {
                Label(String(localized: "settings.scopes.facet.subject",
                             defaultValue: "Subject…"), systemImage: "text.book.closed")
            }
            .disabled(VolumeSubjectProfilesStore.shared == nil)
            Button {
                facetSheet = .person
            } label: {
                Label(String(localized: "settings.scopes.facet.person",
                             defaultValue: "Person…"), systemImage: "person")
            }
            .disabled(appState.personMentionStore == nil)
            Button {
                facetSheet = .tag
            } label: {
                Label(String(localized: "settings.scopes.facet.tag",
                             defaultValue: "Manifest Tag…"), systemImage: "tag")
            }
            Button {
                facetSheet = .coverage
            } label: {
                Label(String(localized: "settings.scopes.facet.coverage",
                             defaultValue: "Coverage Years / Editor…"), systemImage: "calendar")
            }
        } label: {
            Label(String(localized: "settings.scopes.facet.menu",
                         defaultValue: "Add Volumes By…"), systemImage: "plus.circle")
        }
        .accessibilityHint(String(localized: "settings.scopes.facet.menu.hint",
                                  defaultValue: "Adds matching volumes to the scope — additions never remove volumes already selected"))
    }


    /// All manifest entries (the facet pickers' universe — whole manifest, §8-Q1(a)).
    private var allManifestEntries: [VolumeManifestEntry] {
        appState.manifestStore.diffResult?.known ?? appState.manifestStore.bundledEntries
    }

    /// Handles a person facet pick: resolves the person's mention volumes via the #264
    /// primitive and unions them (only indexed volumes have mention rows — that subset
    /// is inherent to the facet and disclosed in the picker's hint).
    private func addVolumes(forPerson entry: PersonIndexEntry) {
        guard let store = appState.personMentionStore,
              let rollupId = entry.rollupId else { return }
        pendingPersonUnions += 1
        Task {
            // The View is MainActor-isolated, so this non-detached Task inherits it —
            // both mutations below are main-thread. `defer` re-enables Save even when
            // the query fails or the person has no mention rows.
            defer { pendingPersonUnions -= 1 }
            guard let counts = try? await store.volumeMentionCounts(forRollupId: rollupId) else { return }
            selection.formUnion(counts.map(\.volumeId))
        }
    }

    /// The subseries-grouped selection list, shared by both platform bodies.
    private var groupList: some View {
        ForEach(subseriesGroups, id: \.subseries) { group in
            Section {
                ForEach(group.volumes, id: \.volumeId) { entry in
                    volumeRow(entry)
                }
            } header: {
                HStack {
                    Text(group.subseries)
                    Spacer()
                    subseriesToggle(group)
                }
            }
        }
    }

    #if os(iOS)
    /// iOS chrome: NavigationStack sheet with `.searchable` and nav-bar actions.
    private var iosBody: some View {
        NavigationStack {
            List {
                Section {
                    TextField(String(localized: "settings.scopes.editor.name",
                                     defaultValue: "Scope name"),
                              text: $name)
                    addByFacetMenu
                } footer: {
                    Text(footerText)
                }
                groupList
            }
            .sheet(item: $facetSheet) { facet in
                facetPicker(facet)
            }
            // **`.navigationBarDrawer(.always)` is the fix for #862, and it is not cosmetic.**
            // Measured on iPhone (iOS 26): with the default placement, Save is present before the
            // filter is touched and **absent after it is used** — an active `.searchable` takes
            // the navigation bar over, and Save is a `.confirmationAction` toolbar item living in
            // it. So a reader who filtered to find the volumes they wanted — the entire purpose of
            // the field — lost the only way to keep the scope. "Custom volume scopes do not save
            // on iOS" is that, exactly.
            //
            // A drawer keeps the field *below* the bar instead of replacing it, so the toolbar
            // survives, and `.always` stops it hiding on scroll and taking Save with it again.
            .searchable(text: $filterText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: String(localized: "settings.scopes.editor.search",
                                       defaultValue: "Filter volumes by title"))
            .navigationTitle(editorTitle)
            .navigationBarTitleDisplayMode(.inline)
            // **Cancel and Save sit in the BOTTOM bar, not the navigation bar (#862).** Measured on
            // iPhone (iOS 26): with them as `.cancellationAction`/`.confirmationAction`, Save is
            // present before the volume filter is used and **absent after** — an active
            // `.searchable` takes the navigation bar over, and takes the primary action with it. A
            // reader who filtered to find the volumes they wanted (the field's whole purpose) was
            // left with no way to keep the scope, which is "custom volume scopes do not save on
            // iOS" exactly. The bottom bar is a separate surface that search does not touch.
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button(String(localized: "common.cancel", defaultValue: "Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .bottomBar) { Spacer() }
                ToolbarItem(placement: .bottomBar) {
                    Button(String(localized: "common.save", defaultValue: "Save")) {
                        save()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
            .onAppear(perform: seed)
            // #861/#862: measured on iPhone (402x874), this sheet's `.searchable` filter renders
            // at y 803-841 while the keyboard occupies y 583-816 — so with the name field's
            // keyboard up the filter is UNDER it and reports isHittable == false. Nothing else on
            // this screen dismisses the keyboard, which is why the scope could not be completed.
            .keyboardDismissBar()
        }
    }
    #endif

    #if os(macOS)
    /// macOS chrome (Phase 2): explicit header / inline filter / list / bottom-right
    /// Cancel–Save — the repo's mac-sheet idiom; no `.searchable`-in-sheet.
    private var macBody: some View {
        VStack(spacing: 0) {
            HStack {
                Text(editorTitle).font(.headline)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Divider()

            HStack(spacing: 8) {
                TextField(String(localized: "settings.scopes.editor.name",
                                 defaultValue: "Scope name"),
                          text: $name)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 220)
                TextField(String(localized: "settings.scopes.editor.search",
                                 defaultValue: "Filter volumes by title"),
                          text: $filterText)
                    .textFieldStyle(.roundedBorder)
                addByFacetMenu
                    .menuStyle(.borderlessButton)
                    .fixedSize()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .sheet(item: $facetSheet) { facet in
                facetPicker(facet)
            }

            List {
                groupList
            }

            Divider()

            HStack {
                Text(footerText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(String(localized: "common.cancel", defaultValue: "Cancel")) {
                    dismiss()
                }
                Button(String(localized: "common.save", defaultValue: "Save")) {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 520, minHeight: 560)
        .onAppear(perform: seed)
    }
    #endif

    /// One selectable volume row: title, id, and an indexed marker.
    @ViewBuilder
    private func volumeRow(_ entry: VolumeManifestEntry) -> some View {
        let isSelected = selection.contains(entry.volumeId)
        Button {
            if isSelected { selection.remove(entry.volumeId) }
            else { selection.insert(entry.volumeId) }
        } label: {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title).font(.callout).lineLimit(2)
                    HStack(spacing: 6) {
                        Text(entry.volumeId)
                        if appState.indexedVolumeIds.contains(entry.volumeId) {
                            Text(String(localized: "settings.scopes.editor.indexedBadge",
                                        defaultValue: "Indexed"))
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// The per-subseries add/remove-all control — the subseries selection facet.
    @ViewBuilder
    private func subseriesToggle(_ group: (subseries: String, volumes: [VolumeManifestEntry])) -> some View {
        let ids = Set(group.volumes.map(\.volumeId))
        let allSelected = ids.isSubset(of: selection)
        Button(allSelected
               ? String(localized: "settings.scopes.editor.removeAll", defaultValue: "Remove All")
               : String(localized: "settings.scopes.editor.addAll", defaultValue: "Add All")) {
            if allSelected { selection.subtract(ids) } else { selection.formUnion(ids) }
        }
        .font(.caption)
        .textCase(nil)
    }

    /// Builds the picker for a facet (#258 Phase 4). Every picker UNIONS into
    /// `selection`; the person facet reuses the corrections flow's searchable picker
    /// with a facet title.
    @ViewBuilder
    private func facetPicker(_ facet: FacetSheet) -> some View {
        switch facet {
        case .subject:
            SubjectFacetPicker(currentSelection: selection) { ids in
                selection.formUnion(ids)
            }
        case .person:
            PersonMergePickerSheet(excludingRollupId: nil,
                                   onPick: { addVolumes(forPerson: $0) },
                                   title: String(localized: "settings.scopes.facet.person.title",
                                                 defaultValue: "Add Volumes by Person"))
                .environment(appState)
        case .tag:
            TagFacetPicker(entries: allManifestEntries, currentSelection: selection) { ids in
                selection.formUnion(ids)
            }
        case .coverage:
            CoverageFacetSheet(entries: allManifestEntries) { ids in
                selection.formUnion(ids)
            }
        }
    }

    /// Commits the edit: wholesale membership replacement (deduped, sorted), name trim,
    /// `lastModified` stamp; inserts the record when it is a draft.
    private func save() {
        scope.name = name.trimmingCharacters(in: .whitespaces)
        scope.volumeIds = Array(selection).sorted()   // wholesale replace — never mutate in place
        scope.lastModified = Date()
        if isDraft { modelContext.insert(scope) }
        do {
            try modelContext.save()
        } catch {
            // A swallowed save error would present as a silent no-op to the user (#366). We
            // can't raise a blocking alert from here without more plumbing, but never lose it.
            #if DEBUG
            print("[CustomScopeEditorView] save failed: \(error)")
            #endif
        }
        dismiss()
    }
}

// MARK: - SubjectFacetPicker (#258 Phase 4)

/// Searchable list of the frus-subjects catalog; tapping a subject UNIONS its volumes
/// into the scope. Rows show reach and a checkmark once every covered volume is already
/// selected. Volume-grain by construction (the profiles are volume-grain).
private struct SubjectFacetPicker: View {

    /// The editor's current selection, for the already-added checkmarks.
    let currentSelection: Set<String>
    /// Unions the subject's volumes into the editor's selection.
    let onAdd: (Set<String>) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    /// Live view of what has been added THIS presentation (checkmarks update as taps land).
    @State private var addedThisSession: Set<String> = []

    private var catalog: [ScopeFacets.SubjectEntry] {
        guard let profiles = VolumeSubjectProfilesStore.shared else { return [] }
        let all = ScopeFacets.subjectCatalog(resolvedByVolume: profiles.resolvedByVolume,
                                             volumesBySubjectRef: profiles.volumesBySubjectRef)
        guard !searchText.isEmpty else { return all }
        return all.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.category.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// The picker's chrome title, shared by both platform bodies.
    private var pickerTitle: String {
        String(localized: "settings.scopes.facet.subject.title",
               defaultValue: "Add Volumes by Subject")
    }

    /// The search prompt, shared by both platform bodies.
    private var searchPrompt: String {
        String(localized: "settings.scopes.facet.subject.prompt",
               defaultValue: "Search subjects")
    }

    var body: some View {
        // #332 review: platform-split chrome — a `NavigationStack` (and `.searchable`)
        // inside a macOS sheet renders sidebar-style artifacts, so macOS gets the plain
        // `PersonMergePickerSheet` chrome. The list itself is shared.
        #if os(macOS)
        VStack(spacing: 0) {
            HStack {
                Text(pickerTitle).font(.headline)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)
            macSearchField
            Divider()
            catalogList
                .listStyle(.inset)
            Divider()
            HStack {
                Spacer()
                Button(String(localized: "common.done", defaultValue: "Done")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 420, minHeight: 480)
        #else
        NavigationStack {
            catalogList
                .searchable(text: $searchText, prompt: searchPrompt)
                .navigationTitle(pickerTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "common.done", defaultValue: "Done")) { dismiss() }
                    }
                }
        }
        #endif
    }

    #if os(macOS)
    /// The mac chrome's inline search field (mirrors `PersonMergePickerSheet.searchField`).
    private var macSearchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(searchPrompt, text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
    #endif

    /// The searchable catalog list, shared by both platform chromes.
    private var catalogList: some View {
        List(catalog) { entry in
            let volumes = VolumeSubjectProfilesStore.shared.map {
                ScopeFacets.volumeIds(forSubjectRef: entry.ref,
                                      volumesBySubjectRef: $0.volumesBySubjectRef)
            } ?? []
            let fullyAdded = volumes.isSubset(of: currentSelection.union(addedThisSession))
            Button {
                onAdd(volumes)
                addedThisSession.formUnion(volumes)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name)
                        Text(String(format: String(
                            localized: "settings.scopes.facet.subject.row %@ %lld",
                            defaultValue: "%@ · %lld volumes"),
                            entry.category, Int64(entry.volumeCount)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: fullyAdded ? "checkmark.circle.fill" : "plus.circle")
                        .foregroundStyle(fullyAdded ? Color.secondary : Color.accentColor)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(fullyAdded)
            .accessibilityLabel(entry.name)
            .accessibilityHint(String(localized: "settings.scopes.facet.add.hint",
                                      defaultValue: "Adds this facet's volumes to the scope"))
        }
    }
}

// MARK: - TagFacetPicker (#258 Phase 4)

/// Searchable list of the manifest's OH tag slugs; tapping a tag UNIONS its volumes into
/// the scope. Same interaction contract as `SubjectFacetPicker`.
private struct TagFacetPicker: View {

    /// The facet universe (whole manifest).
    let entries: [VolumeManifestEntry]
    /// The editor's current selection, for the already-added checkmarks.
    let currentSelection: Set<String>
    /// Unions the tag's volumes into the editor's selection.
    let onAdd: (Set<String>) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var addedThisSession: Set<String> = []

    private var catalog: [ScopeFacets.TagEntry] {
        let all = ScopeFacets.tagCatalog(entries)
        guard !searchText.isEmpty else { return all }
        return all.filter { $0.slug.localizedCaseInsensitiveContains(searchText) }
    }

    /// The picker's chrome title, shared by both platform bodies.
    private var pickerTitle: String {
        String(localized: "settings.scopes.facet.tag.title",
               defaultValue: "Add Volumes by Tag")
    }

    /// The search prompt, shared by both platform bodies.
    private var searchPrompt: String {
        String(localized: "settings.scopes.facet.tag.prompt",
               defaultValue: "Search tags")
    }

    var body: some View {
        // #332 review: same platform split as `SubjectFacetPicker` — no
        // `NavigationStack`-in-sheet on macOS.
        #if os(macOS)
        VStack(spacing: 0) {
            HStack {
                Text(pickerTitle).font(.headline)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)
            macSearchField
            Divider()
            catalogList
                .listStyle(.inset)
            Divider()
            HStack {
                Spacer()
                Button(String(localized: "common.done", defaultValue: "Done")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 380, minHeight: 460)
        #else
        NavigationStack {
            catalogList
                .searchable(text: $searchText, prompt: searchPrompt)
                .navigationTitle(pickerTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "common.done", defaultValue: "Done")) { dismiss() }
                    }
                }
        }
        #endif
    }

    #if os(macOS)
    /// The mac chrome's inline search field (mirrors `PersonMergePickerSheet.searchField`).
    private var macSearchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(searchPrompt, text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
    #endif

    /// The searchable catalog list, shared by both platform chromes.
    private var catalogList: some View {
        List(catalog) { tag in
            let volumes = ScopeFacets.volumeIds(taggedWith: tag.slug, entries: entries)
            let fullyAdded = volumes.isSubset(of: currentSelection.union(addedThisSession))
            Button {
                onAdd(volumes)
                addedThisSession.formUnion(volumes)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tag.slug)
                        Text(String(format: String(
                            localized: "settings.scopes.facet.tag.row %lld",
                            defaultValue: "%lld volumes"), Int64(tag.volumeCount)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: fullyAdded ? "checkmark.circle.fill" : "plus.circle")
                        .foregroundStyle(fullyAdded ? Color.secondary : Color.accentColor)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(fullyAdded)
            .accessibilityLabel(tag.slug)
            .accessibilityHint(String(localized: "settings.scopes.facet.add.hint",
                                      defaultValue: "Adds this facet's volumes to the scope"))
        }
    }
}

// MARK: - CoverageFacetSheet (#258 Phase 4)

/// The coverage facet: adds every volume whose coverage years intersect a range,
/// optionally narrowed by an editor-name substring. Volumes without parseable coverage
/// are excluded (absent evidence, no claim) — the live match count makes that visible.
private struct CoverageFacetSheet: View {

    /// The facet universe (whole manifest).
    let entries: [VolumeManifestEntry]
    /// Unions the matching volumes into the editor's selection.
    let onAdd: (Set<String>) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var fromYearText = ""
    @State private var toYearText = ""
    @State private var editorFilter = ""

    /// The live match for the current inputs, or `nil` when nothing is matchable yet.
    /// Two paths (#366): a **year range** (both years parse, `from ≤ to`), optionally
    /// narrowed by an editor substring; or an **editor-only** filter when both year fields
    /// are blank. A partial or inverted year range yields `nil` (the disabled prompt).
    private var matches: Set<String>? {
        let editor = editorFilter.trimmingCharacters(in: .whitespaces)
        let fromTrimmed = fromYearText.trimmingCharacters(in: .whitespaces)
        let toTrimmed = toYearText.trimmingCharacters(in: .whitespaces)
        if let from = Int(fromTrimmed), let to = Int(toTrimmed), from <= to {
            return ScopeFacets.volumeIds(coverageIntersecting: from, toYear: to,
                                         editorContains: editor.isEmpty ? nil : editor,
                                         entries: entries)
        }
        // Editor-only: both year fields blank and an editor name supplied.
        if fromTrimmed.isEmpty, toTrimmed.isEmpty, !editor.isEmpty {
            return ScopeFacets.volumeIds(editorContains: editor, entries: entries)
        }
        return nil
    }

    /// Whether exactly one year field is filled — a half-entered range that blocks both the
    /// range path and the editor-only fallback, so the prompt should say *why* (F2/#366).
    private var hasPartialYearRange: Bool {
        fromYearText.trimmingCharacters(in: .whitespaces).isEmpty
            != toYearText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// The sheet's chrome title, shared by both platform bodies.
    private var pickerTitle: String {
        String(localized: "settings.scopes.facet.coverage.title",
               defaultValue: "Add Volumes by Coverage or Editor")
    }

    /// The explanatory footer, shared by both platform bodies.
    private var footerString: String {
        String(localized: "settings.scopes.facet.coverage.footer",
               defaultValue: "Adds volumes whose coverage overlaps the years you set. You can also narrow by editor. Leave both years blank to add by editor name alone. Volumes with no coverage dates in the manifest never match a year range.")
    }

    /// The add button's live label: match count, or an input prompt. A half-entered range
    /// gets a targeted hint (the editor field alone can't rescue it) rather than the generic
    /// prompt that would misleadingly read as already-satisfied when an editor name is present.
    @ViewBuilder
    private var addButtonLabel: some View {
        if let matches {
            Text(String(format: String(
                localized: "settings.scopes.facet.coverage.add %lld",
                defaultValue: "Add %lld matching volumes"), Int64(matches.count)))
        } else if hasPartialYearRange {
            Text(String(localized: "settings.scopes.facet.coverage.partialRange",
                        defaultValue: "Enter both years, or clear them to match by editor"))
        } else {
            Text(String(localized: "settings.scopes.facet.coverage.invalid",
                        defaultValue: "Enter a year range or an editor name"))
        }
    }

    /// Commits the current matches and dismisses.
    private func performAdd() {
        if let matches { onAdd(matches); dismiss() }
    }

    var body: some View {
        // #332 review: same platform split as the other facet pickers — the mac chrome
        // is a plain VStack (no `NavigationStack`-in-sheet), fields inline, Cancel–Add
        // at the bottom right per the repo's mac-sheet idiom.
        #if os(macOS)
        VStack(spacing: 0) {
            HStack {
                Text(pickerTitle).font(.headline)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                TextField(String(localized: "settings.scopes.facet.coverage.from",
                                 defaultValue: "From year (e.g. 1961)"),
                          text: $fromYearText)
                    .textFieldStyle(.roundedBorder)
                TextField(String(localized: "settings.scopes.facet.coverage.to",
                                 defaultValue: "To year (e.g. 1968)"),
                          text: $toYearText)
                    .textFieldStyle(.roundedBorder)
                TextField(String(localized: "settings.scopes.facet.coverage.editor",
                                 defaultValue: "Editor name contains (optional)"),
                          text: $editorFilter)
                    .textFieldStyle(.roundedBorder)
                Text(footerString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)

            Spacer(minLength: 0)

            Divider()

            HStack {
                Spacer()
                Button(String(localized: "common.cancel", defaultValue: "Cancel")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button {
                    performAdd()
                } label: {
                    addButtonLabel
                }
                .keyboardShortcut(.defaultAction)
                .disabled(matches?.isEmpty ?? true)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 380, minHeight: 300)
        #else
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "settings.scopes.facet.coverage.from",
                                     defaultValue: "From year (e.g. 1961)"),
                              text: $fromYearText)
                    TextField(String(localized: "settings.scopes.facet.coverage.to",
                                     defaultValue: "To year (e.g. 1968)"),
                              text: $toYearText)
                    TextField(String(localized: "settings.scopes.facet.coverage.editor",
                                     defaultValue: "Editor name contains (optional)"),
                              text: $editorFilter)
                } footer: {
                    Text(footerString)
                }
                Section {
                    Button {
                        performAdd()
                    } label: {
                        addButtonLabel
                    }
                    .disabled(matches?.isEmpty ?? true)
                }
            }
            .navigationTitle(pickerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel", defaultValue: "Cancel")) { dismiss() }
                }
            }
            // #861: the three year/editor fields here are `.numberPad`-adjacent free text with no
            // submit action, and this sheet has no Done — so the keyboard could only be dismissed
            // by cancelling the sheet, losing the entry.
            .keyboardDismissBar()
        }
        #endif
    }
}
