// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#if os(macOS)
import SwiftUI
import SwiftData

// MARK: - MacArchiveVisitManagerView

/// The macOS Archive Visits window root — the `MacCollectionManagerView` shape, replacing
/// the iOS push-navigation shell the window shipped with (a back chevron in a Mac singleton
/// window, the owner's screenshot).
///
/// The window is a flat pane: a toolbar plan PICKER at `.navigation` (the everyday
/// switcher — its menu holds an inline Picker of plans plus New and Manage actions), the
/// selected plan's `ArchiveVisitEditorView` as the always-present detail, a
/// `ContentUnavailableView` with a New button when nothing is selected, and a Manage sheet
/// (inline rename rows, duplicate, confirmed delete) for list CRUD. No `NavigationStack`,
/// no pushes.
///
/// The window title stays "Archive Visits" (the scene's) — the picker label names the
/// current plan, exactly as the Collections window does.
///
/// Version history:
///   1.0 — Archive Visits UI pass: initial implementation
struct MacArchiveVisitManagerView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ArchiveVisitPlan.lastModified, order: .reverse)
    private var plans: [ArchiveVisitPlan]

    @State private var selectedId: UUID?
    @State private var showManage = false

    private var selectedPlan: ArchiveVisitPlan? {
        plans.first { $0.id == selectedId }
    }

    var body: some View {
        Group {
            if let plan = selectedPlan {
                // `.id` so switching plans rebuilds the editor's state (derivation, tab,
                // filters) rather than leaking one plan's into the next.
                ArchiveVisitEditorView(plan: plan)
                    .id(plan.id)
            } else {
                ContentUnavailableView {
                    Label(String(localized: "archiveVisit.mac.noSelection.title",
                                 defaultValue: "No Archive Visit Selected"),
                          systemImage: "building.columns")
                } description: {
                    Text(String(localized: "archiveVisit.mac.noSelection.detail",
                                defaultValue: "Choose a plan from the picker in the toolbar, or create a new one. Plans can also be seeded from Source Explorer, Archival Neighbors, a collection, or a project."))
                } actions: {
                    Button(String(localized: "archiveVisit.new",
                                  defaultValue: "New Archive Visit")) {
                        createPlan()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 640, minHeight: 460)
        .toolbar {
            ToolbarItem(placement: .navigation) { planPickerMenu }
        }
        .sheet(isPresented: $showManage) {
            MacManageArchiveVisitsSheet(plans: plans, selectedId: $selectedId)
                .environment(appState)
        }
        // Open on the most recent plan — an empty pane in a window whose plans exist
        // would make every launch start with a picker trip.
        .onAppear {
            if selectedId == nil { selectedId = plans.first?.id }
        }
    }

    /// The toolbar plan picker — the Collections window's `collectionPickerMenu` grammar:
    /// label = current plan (+ seed count), menu = inline Picker + New + Manage.
    private var planPickerMenu: some View {
        Menu {
            Picker(selection: $selectedId) {
                ForEach(plans) { plan in
                    Text(verbatim: "\(plan.displayName)  ·  \((plan.documents ?? []).count.formatted())")
                        .tag(Optional(plan.id))
                }
            } label: { EmptyView() }
            .pickerStyle(.inline)

            Divider()
            Button {
                createPlan()
            } label: {
                Label(String(localized: "archiveVisit.picker.new",
                             defaultValue: "New Archive Visit…"),
                      systemImage: "plus")
            }
            Button {
                showManage = true
            } label: {
                Label(String(localized: "archiveVisit.picker.manage",
                             defaultValue: "Manage Archive Visits…"),
                      systemImage: "list.bullet")
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal")
                Text(selectedPlan?.displayName
                     ?? String(localized: "archiveVisit.list.title",
                               defaultValue: "Archive Visits"))
                    .fontWeight(.semibold)
                if let plan = selectedPlan {
                    Text(verbatim: (plan.documents ?? []).count.formatted())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Creates and selects an empty plan — the same starting state the iOS list's New row
    /// produces.
    private func createPlan() {
        let plan = ArchiveVisitPlan(name: "")
        modelContext.insert(plan)
        try? modelContext.save()
        selectedId = plan.id
    }
}

// MARK: - MacManageArchiveVisitsSheet

/// The Manage sheet — `MacManageCollectionsSheet`'s shape: plain-VStack chrome, inline
/// rename rows, and delete. One deliberate departure: deletion CONFIRMS here, because a
/// plan delete cascades over tiers and hand-typed notes on every device (the same reason
/// the iOS list arms a confirmation instead of allowing a full swipe).
///
/// Version history:
///   1.0 — Archive Visits UI pass: initial implementation
private struct MacManageArchiveVisitsSheet: View {

    let plans: [ArchiveVisitPlan]
    /// The manager's selection, cleared if the selected plan is deleted here.
    @Binding var selectedId: UUID?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var deleting: ArchiveVisitPlan?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(String(localized: "archiveVisit.manage.title",
                            defaultValue: "Manage Archive Visits"))
                    .font(.headline)
                Spacer()
                Button(String(localized: "common.done", defaultValue: "Done")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(20)
            Divider()
            if plans.isEmpty {
                ContentUnavailableView {
                    Label(String(localized: "archiveVisit.empty.title",
                                 defaultValue: "No Archive Visits"),
                          systemImage: "building.columns")
                }
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(plans) { plan in
                        ManageArchiveVisitRow(plan: plan,
                                              onDuplicate: { duplicate(plan) },
                                              onDelete: { deleting = plan })
                    }
                }
            }
        }
        .frame(minWidth: 440, minHeight: 420)
        .confirmationDialog(
            String(localized: "archiveVisit.delete.title",
                   defaultValue: "Delete this Archive Visit?"),
            isPresented: Binding(get: { deleting != nil },
                                 set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible
        ) {
            Button(String(localized: "common.delete", defaultValue: "Delete"),
                   role: .destructive) { commitDelete() }
            Button(String(localized: "common.cancel", defaultValue: "Cancel"), role: .cancel) {
                deleting = nil
            }
        } message: {
            Text(String(localized: "archiveVisit.delete.message",
                        defaultValue: "This deletes the plan, its priority tiers, and its per-target notes — from your other devices too, after sync. Documents and volumes are untouched."))
        }
    }

    private func duplicate(_ plan: ArchiveVisitPlan) {
        let copy = plan.duplicate(in: modelContext)
        try? modelContext.save()
        selectedId = copy.id
    }

    private func commitDelete() {
        guard let plan = deleting else { return }
        if selectedId == plan.id { selectedId = nil }
        // Through the explicit cascade — the `.nullify` relationships would orphan every
        // child row under a bare delete (§4a).
        plan.deleteWithChildren(in: modelContext)
        try? modelContext.save()
        deleting = nil
    }
}

// MARK: - ManageArchiveVisitRow

/// One editable row: an inline rename field (committed through `rename(to:)`; an empty
/// commit reverts, the list's rule) + the seed count and modification date, with
/// Duplicate/Delete in a context menu.
private struct ManageArchiveVisitRow: View {

    @Bindable var plan: ArchiveVisitPlan
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var draftName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            TextField(ArchiveVisitPlan.untitledName, text: $draftName)
                .textFieldStyle(.plain)
                .font(.body)
                .onSubmit { commitRename() }
            HStack(spacing: 4) {
                Text(String(localized: "archiveVisit.manage.docCount",
                            defaultValue: "\((plan.documents ?? []).count.formatted()) documents"))
                if let modified = plan.lastModified {
                    Text(verbatim: "·")
                    Text(String(format: String(localized: "archiveVisit.list.modified %@",
                                               defaultValue: "Modified %@"),
                                modified.formatted(date: .abbreviated, time: .omitted)))
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button {
                onDuplicate()
            } label: {
                Label(String(localized: "common.duplicate", defaultValue: "Duplicate"),
                      systemImage: "plus.square.on.square")
            }
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label(String(localized: "common.delete", defaultValue: "Delete"),
                      systemImage: "trash")
            }
        }
        .task(id: plan.id) { draftName = plan.name }
    }

    private func commitRename() {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            draftName = plan.name
        } else if trimmed != plan.name {
            plan.rename(to: trimmed)
            try? modelContext.save()
        }
    }
}
#endif
