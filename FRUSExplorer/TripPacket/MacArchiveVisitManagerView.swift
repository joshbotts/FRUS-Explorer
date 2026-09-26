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

import Foundation

// MARK: - ArchiveVisitWindowHandoff

/// Which plan the Mac Archives Visits window shows when another surface asks it to open one (#1462).
///
/// On the Mac, Project Home's Plan a Visit and Review Changes' Open the plan open the plan in this
/// window rather than a sheet: the editor's Mac controls are the window's toolbar, and a macOS sheet
/// draws none of them, and the editor has no size of its own, so a sheet collapsed it to a strip
/// holding only Done. The window's selection is its own state, so the request travels through
/// `AppState.pendingArchiveVisitSelection` and the window resolves it here.
///
/// Platform-independent, unlike the window, so the rule is unit-tested on the iOS test host.
///
/// Version history:
///   1.0 — #1462: initial implementation
enum ArchiveVisitWindowHandoff {

    /// What a resolution decided.
    struct Outcome: Equatable, Sendable {
        /// The plan the window shows.
        let selection: UUID?
        /// Whether the request is spent and should be cleared.
        let consumed: Bool
    }

    /// Resolves a pending request against the window's plans.
    ///
    /// A request for a plan the window lists selects it and is spent. A request for a plan the
    /// window does not list yet leaves the selection as it is and stays pending, so the window can
    /// take it when the plan appears in its list; a later request replaces it. No request changes
    /// nothing.
    ///
    /// - Parameters:
    ///   - request: the pending plan id, if any.
    ///   - selection: the plan the window shows now.
    ///   - planIds: the plans the window lists.
    static func resolve(request: UUID?, selection: UUID?, planIds: [UUID]) -> Outcome {
        guard let request, planIds.contains(request) else {
            return Outcome(selection: selection, consumed: false)
        }
        return Outcome(selection: request, consumed: true)
    }
}

#if os(macOS)
import SwiftUI
import SwiftData

// MARK: - Opening a plan in the window

extension AppState {

    /// Opens `plan` in the Archives Visits window, bringing the window forward on it (#1462).
    ///
    /// The Mac's route to a plan from anywhere outside the window — Project Home's Plan a Visit and
    /// Review Changes' Open the plan. They presented the editor in a sheet, and a macOS sheet draws
    /// none of the editor's toolbar (the Targets | Documents switcher, Filter, Export packet, About
    /// research targets, ⋯) and gives its `List` no size, so it showed a strip holding only Done.
    /// The request is set before the window is fronted, so a window created by the fronting takes
    /// it on appear rather than opening on whichever plan it was last on.
    ///
    /// - Parameters:
    ///   - plan: the plan to show.
    ///   - openWindow: the calling view's `openWindow`.
    func openArchiveVisitWindow(on plan: ArchiveVisitPlan, using openWindow: OpenWindowAction) {
        pendingArchiveVisitSelection = plan.id
        openWindow.fronting(id: "frus.archiveVisits")
    }
}

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
///   1.1 — #1366: New creates through `ArchiveVisitPlan.make`, under the active project
///   1.2 — #1378: the picker's plan name keeps to one line within ``planNameMaxWidth``, cut at
///         the tail, so a long name cannot widen the toolbar
///   1.3 — #1462: the window takes a plan handed to it (`AppState.pendingArchiveVisitSelection`,
///         resolved by ``ArchiveVisitWindowHandoff``) on appear, when the request changes and when its
///         plans change, so Project Home and Review Changes open the plan here rather than in a sheet
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

    /// The widest the toolbar picker draws the plan's name, in points; a longer name is cut at
    /// the tail (#1378).
    ///
    /// The toolbar gives each item its content's own width, so the picker used to grow with the
    /// name, point for point, until Filter, Export packet and About research targets went behind
    /// the overflow chevron. Measured on macOS 27 with the name uncapped, every item showed from
    /// 808 pt with a 13-character name and only from 1,234 pt with a 77-character one; with this
    /// cap, from 982 pt with the 77-character one. 260 pt holds the manual capture's "The Long
    /// Telegram and Its Readers" (33 characters, 221 pt) whole and draws 37 characters of the
    /// longer name before the ellipsis; the menu's own list still shows every name in full.
    static let planNameMaxWidth: CGFloat = 260

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
                                 defaultValue: "No Archives Visit Selected"),
                          systemImage: "building.columns")
                } description: {
                    Text(String(localized: "archiveVisit.mac.noSelection.detail",
                                defaultValue: "Choose a plan from the picker in the toolbar, or create a new one. Plans can also be seeded from Source Explorer, Archival Neighbors, a collection, or a project."))
                } actions: {
                    Button(String(localized: "archiveVisit.new",
                                  defaultValue: "New Archives Visit")) {
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
        // Open on the plan another surface handed off (#1462), or else on the most recent plan — an
        // empty pane in a window whose plans exist would make every launch start with a picker trip.
        .onAppear {
            takePendingSelection()
            if selectedId == nil { selectedId = plans.first?.id }
        }
        // A plan handed off while the window is already open (#1462).
        .onChange(of: appState.pendingArchiveVisitSelection) { _, _ in takePendingSelection() }
        // A request for a plan this window does not list yet stays pending until it does.
        .onChange(of: plans.map(\.id)) { _, _ in takePendingSelection() }
    }

    /// Shows the plan another surface asked this window to show — Project Home's Plan a Visit or
    /// Review Changes' Open the plan (#1462) — and clears the request once it is shown.
    private func takePendingSelection() {
        let outcome = ArchiveVisitWindowHandoff.resolve(request: appState.pendingArchiveVisitSelection,
                                                        selection: selectedId,
                                                        planIds: plans.map(\.id))
        selectedId = outcome.selection
        if outcome.consumed { appState.pendingArchiveVisitSelection = nil }
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
                             defaultValue: "New Archives Visit…"),
                      systemImage: "plus")
            }
            Button {
                showManage = true
            } label: {
                Label(String(localized: "archiveVisit.picker.manage",
                             defaultValue: "Manage Archives Visits…"),
                      systemImage: "list.bullet")
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal")
                Text(selectedPlan?.displayName
                     ?? String(localized: "archiveVisit.list.title",
                               defaultValue: "Archives Visits"))
                    .fontWeight(.semibold)
                    // One line, cut at the tail (#1378). The maximum width is what does the
                    // cutting: a toolbar item is as wide as its content wants, so a line limit
                    // alone leaves a long name whole and the toolbar still overflows.
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: Self.planNameMaxWidth, alignment: .leading)
                if let plan = selectedPlan {
                    Text(verbatim: (plan.documents ?? []).count.formatted())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Creates and selects a plan with no seeds — the same starting state the iOS list's New row
    /// produces: under the active project when there is one, with its research question as the
    /// inquiry topic (#1366).
    private func createPlan() {
        let plan = ArchiveVisitPlan.make(name: "", activeProjectId: appState.activeProjectId,
                                         in: modelContext)
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
                            defaultValue: "Manage Archives Visits"))
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
                                 defaultValue: "No Archives Visits"),
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
                   defaultValue: "Delete this Archives Visit?"),
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
                // #1374 review, round 1: the Mac twin of the plans list's seed count.
                Text(CountCopy.documents((plan.documents ?? []).count))
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
