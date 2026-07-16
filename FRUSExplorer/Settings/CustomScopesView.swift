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
struct CustomScopesView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \CustomVolumeScope.name) private var scopes: [CustomVolumeScope]

    /// The scope being edited in the sheet, or `nil`. A fresh unsaved instance for
    /// "create" (inserted only on Save), an existing record for "edit".
    @State private var editorTarget: CustomVolumeScope?
    /// Whether `editorTarget` is a not-yet-inserted draft (create) vs a live record (edit).
    @State private var editorIsDraft = false

    var body: some View {
        List {
            if scopes.isEmpty {
                ContentUnavailableView(
                    String(localized: "settings.scopes.empty.title",
                           defaultValue: "No Volume Scopes"),
                    systemImage: "square.stack.3d.up",
                    description: Text(String(localized: "settings.scopes.empty.detail",
                                             defaultValue: "Create a named set of volumes to use as a search scope — for example, every volume covering a crisis, a region, or an administration."))
                )
            } else {
                Section {
                    ForEach(scopes) { scope in
                        Button {
                            editorIsDraft = false
                            editorTarget = scope
                        } label: {
                            scopeRow(scope)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        for index in offsets { modelContext.delete(scopes[index]) }
                        try? modelContext.save()
                    }
                } footer: {
                    Text(String(localized: "settings.scopes.footer",
                                defaultValue: "Scopes sync to your other devices via iCloud. Deleting a scope does not affect searches already run with it."))
                }
            }
        }
        .navigationTitle(String(localized: "settings.scopes.title",
                                defaultValue: "Volume Scopes"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editorIsDraft = true
                    editorTarget = CustomVolumeScope(name: "")
                } label: {
                    Label(String(localized: "settings.scopes.add", defaultValue: "New Scope"),
                          systemImage: "plus")
                }
            }
        }
        .sheet(item: $editorTarget) { target in
            CustomScopeEditorView(scope: target, isDraft: editorIsDraft)
                .environment(appState)
        }
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
/// > Phase-2 caution (pre-merge review): this editor compiles on macOS but is unreached
/// > there in Phase 1. It uses `.searchable` inside a sheet-hosted `NavigationStack` plus
/// > a macOS min-frame — verify that layout renders sanely (or restyle for the settings
/// > pane idiom) before wiring it into `FRUSSettingsView`; do not adopt it naively.
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
        NavigationStack {
            List {
                Section {
                    TextField(String(localized: "settings.scopes.editor.name",
                                     defaultValue: "Scope name"),
                              text: $name)
                } footer: {
                    Text(String(format: String(
                        localized: "settings.scopes.editor.footer %lld %lld",
                        defaultValue: "%lld volumes selected · %lld indexed. Volumes you haven't downloaded stay in the scope and take effect once indexed."),
                        Int64(selection.count), Int64(indexedSelectedCount)))
                }

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
            .searchable(text: $filterText,
                        prompt: String(localized: "settings.scopes.editor.search",
                                       defaultValue: "Filter volumes by title"))
            .navigationTitle(isDraft
                ? String(localized: "settings.scopes.editor.title.new", defaultValue: "New Scope")
                : String(localized: "settings.scopes.editor.title.edit", defaultValue: "Edit Scope"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel", defaultValue: "Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.save", defaultValue: "Save")) {
                        save()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty
                              || selection.isEmpty)
                }
            }
            .onAppear {
                name = scope.name
                selection = Set(scope.volumeIds)
            }
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 520)
        #endif
    }

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

    /// Commits the edit: wholesale membership replacement (deduped, sorted), name trim,
    /// `lastModified` stamp; inserts the record when it is a draft.
    private func save() {
        scope.name = name.trimmingCharacters(in: .whitespaces)
        scope.volumeIds = Array(selection).sorted()   // wholesale replace — never mutate in place
        scope.lastModified = Date()
        if isDraft { modelContext.insert(scope) }
        try? modelContext.save()
        dismiss()
    }
}
