// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftUI
import SwiftData

// MARK: - ScopeEditorView

/// The in-Browse scope editor (#1051 B-3, design 3a): rename, remove members, and add
/// volumes through the All Volumes catalogue in picker mode — a PUSHED level on both
/// platforms, never a new window (#824).
///
/// ## What it writes, and the #862 heritage
/// Mutations touch only the model's existing `name`/`volumeIds`/`lastModified` — no
/// schema change, no CloudKit deploy. Every membership write is a full-array
/// REASSIGNMENT through `ScopeAxis` (a `@Model` array's `didSet` never fires in-place),
/// and the editor resolves its scope through a live `@Query` by id, so a scope edited or
/// deleted elsewhere is reflected rather than clobbered — the #862 class was two pieces
/// of state that had to agree; here the store is the only state.
///
/// Version history:
///   1.0 — #1051 B-3: initial implementation
///   1.1 — #1070: adopts the #861 keyboard Done bar — the name field re-introduced the
///          exact stuck-TextField shape the bar was written for
struct ScopeEditorView: View {

    /// The scope under edit, resolved live.
    let scopeId: UUID
    /// Pops the level (the hosts own their paths; `dismiss()` cannot pop a two-pane
    /// level rendered outside a navigation container).
    let onDone: @MainActor () -> Void

    @Query private var scopes: [CustomVolumeScope]
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    /// The Add Volumes picker's working selection, seeded from membership on present.
    @State private var pickerSelection: Set<String> = []
    @State private var showingPicker = false

    init(scopeId: UUID, onDone: @escaping @MainActor () -> Void) {
        self.scopeId = scopeId
        self.onDone = onDone
        _scopes = Query(filter: #Predicate<CustomVolumeScope> { $0.id == scopeId })
    }

    private var scope: CustomVolumeScope? { scopes.first }

    var body: some View {
        Group {
            if let scope {
                editor(for: scope)
            } else {
                // Deleted under us (another device, or Settings) — an explicit state,
                // never a blank form writing into nothing.
                ContentUnavailableView(
                    String(localized: "browser.scopeEditor.unavailable.title",
                           defaultValue: "Scope Unavailable"),
                    systemImage: "square.stack.3d.up.slash",
                    description: Text(String(
                        localized: "browser.scopeEditor.unavailable.detail",
                        defaultValue: "This scope no longer exists — it may have been deleted on another device."))
                )
            }
        }
        .navigationTitle(String(localized: "browser.scopeEditor.title", defaultValue: "Edit Scope"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    try? modelContext.save()
                    onDone()
                } label: {
                    Text(String(localized: "browser.scopeEditor.done", defaultValue: "Done"))
                        .bold()
                }
            }
        }
        // #1070 (via #861): the name field is a plain TextField in a List — the exact
        // stuck shape the original scope editor shipped (#862's other end), re-introduced
        // here by B-3. The keyboard-placement bar coexists with the toolbar above.
        .keyboardDismissBar()
        .onDisappear {
            // Belt to Done's braces: a Back/pop must not drop edits either.
            try? modelContext.save()
        }
    }

    @ViewBuilder
    private func editor(for scope: CustomVolumeScope) -> some View {
        List {
            Section(String(localized: "browser.scopeEditor.name.header", defaultValue: "Name")) {
                HStack {
                    TextField(
                        String(localized: "browser.scopeEditor.name.prompt",
                               defaultValue: "Scope name"),
                        text: Binding(
                            get: { scope.name },
                            set: { newValue in
                                scope.name = newValue
                                scope.lastModified = Date()
                            }
                        )
                    )
                    if !scope.name.isEmpty {
                        Button {
                            scope.name = ""
                            scope.lastModified = Date()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(
                            String(localized: "browser.scopeEditor.clearName.a11y",
                                   defaultValue: "Clear the scope name")
                        )
                    }
                }
            }

            Section {
                ForEach(scope.volumeIds, id: \.self) { volumeId in
                    memberRow(volumeId, in: scope)
                }
                Button {
                    pickerSelection = Set(scope.volumeIds)
                    showingPicker = true
                } label: {
                    Label {
                        Text(String(localized: "browser.scopeEditor.addVolumes",
                                    defaultValue: "Add Volumes…"))
                            .foregroundStyle(Color.accentColor)
                    } icon: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.green)
                    }
                    // Both modifiers, in this order — the #312 idiom.
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(String(localized: "browser.scopeEditor.addVolumes.help",
                             defaultValue: "Choose volumes from the All Volumes catalogue"))
            } header: {
                Text(String(localized: "browser.scopeEditor.volumes.header",
                            defaultValue: "Volumes (\(scope.volumeIds.count))"))
            } footer: {
                Text(String(localized: "browser.scopeEditor.footer",
                            defaultValue: "Removing a volume never deletes it from this device. Changes sync via iCloud."))
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
        .sheet(isPresented: $showingPicker) {
            volumePicker(for: scope)
        }
    }

    @ViewBuilder
    private func memberRow(_ volumeId: String, in scope: CustomVolumeScope) -> some View {
        HStack(spacing: 10) {
            Button {
                if ScopeAxis.remove(volumeId, from: scope) {
                    try? modelContext.save()
                }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(
                String(localized: "browser.scopeEditor.remove.a11y",
                       defaultValue: "Remove \(volumeId) from this scope")
            )
            if let entry = appState.manifestStore.entry(forVolumeId: volumeId) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        Text(entry.volumeId)
                        if let year = VolumeCatalogueGrouping.publicationYear(of: entry) {
                            Text("· \(String(year))")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } else {
                // A member the current catalogue cannot resolve — kept, disclosed, and
                // removable, never silently dropped from the model.
                VStack(alignment: .leading, spacing: 2) {
                    Text(volumeId)
                        .font(.callout)
                    Text(String(localized: "browser.scopeEditor.unresolved",
                                defaultValue: "Not in this device’s catalogue"))
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    @ViewBuilder
    private func volumePicker(for scope: CustomVolumeScope) -> some View {
        NavigationStack {
            VolumeCatalogueView(
                entries: appState.manifestStore.browsableEntries,
                documentCount: { [store = appState.administrationProfilesStore] id in
                    store.documentCount(forVolumeId: id)
                },
                status: { [appState] id in
                    VolumeCatalogueStatus(
                        isDownloaded: appState.downloadManager?.isVolumeDownloaded(id) ?? false,
                        isIndexed: (try? appState.indexingPipeline?.isVolumeIndexed(id)) == true,
                        isDownloading: appState.downloadQueue.contains(id)
                    )
                },
                selection: $pickerSelection,
                onSelect: { _ in }
            )
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "browser.scopeEditor.picker.done",
                                  defaultValue: "Done")) {
                        // Apply as one sorted reassignment (the @Model array rule).
                        scope.volumeIds = pickerSelection.sorted()
                        scope.lastModified = Date()
                        try? modelContext.save()
                        showingPicker = false
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "browser.scopeEditor.picker.cancel",
                                  defaultValue: "Cancel")) {
                        showingPicker = false
                    }
                }
            }
        }
    }
}
