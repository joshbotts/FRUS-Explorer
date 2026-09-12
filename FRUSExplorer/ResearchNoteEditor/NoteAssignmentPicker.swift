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

import SwiftUI

// MARK: - NoteAssignmentPicker

/// The note editor's tag and project selectors: what is chosen, and a door to change it (#1275).
///
/// ## What it replaces
/// Both sections used to render one `Toggle` per tag and one per project, unbounded and — measured
/// — in no order at all, since the editor was the single surface in the app fetching either list
/// without a `sortBy:`. A reader with forty tags scrolled past forty switches to reach the Projects
/// section, every time they wrote a note. This shows the chosen ones and nothing else, with the
/// full list one tap away.
///
/// ## Why the list is in a CHILD sheet and not `.searchable` in place
/// The editor's Save is a `ToolbarItem(placement: .confirmationAction)`, and this repo has already
/// measured what an active `.searchable` does to that on iPhone: `CustomScopesView` records Save
/// "present before the filter is touched and **absent after it is used** — an active `.searchable`
/// takes the navigation bar over, and takes the primary action with it". On a sheet whose Save is
/// the only way a note survives, losing it loses the note. So the search lives in a sheet of its
/// own, whose Done sits in the bottom bar for the same reason.
///
/// Version history:
///   1.0 — #1275: initial implementation
struct NoteAssignmentPicker: View {

    /// One choosable thing — a tag or a project — reduced to what this control needs.
    struct Item: Identifiable, Hashable {
        /// The model's id.
        let id: UUID
        /// What the reader sees.
        let name: String
    }

    /// The section heading.
    let title: String
    /// Every item the reader could choose, already in the order they should appear.
    let items: [Item]
    /// The chosen ids.
    @Binding var selection: [UUID]
    /// The sheet's title when the full list opens.
    let pickerTitle: String
    /// Shown in place of the chips when nothing is chosen.
    let emptySelectionLabel: String
    /// Shown in place of everything when there is nothing to choose from.
    let emptyCatalogLabel: String
    /// Which stored order the picker's reorder control writes (#1275).
    let orderedList: ListOrderPreferences.List

    @State private var showsPicker = false

    /// The chosen items, in the catalogue's order rather than the order they were tapped — so the
    /// chips do not reshuffle as the reader works.
    private var chosen: [Item] { items.filter { selection.contains($0.id) } }

    var body: some View {
        Section(title) {
            if items.isEmpty {
                Text(emptyCatalogLabel)
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                Button {
                    showsPicker = true
                } label: {
                    HStack(alignment: .firstTextBaseline) {
                        if chosen.isEmpty {
                            Text(emptySelectionLabel).foregroundStyle(.secondary)
                        } else {
                            // Plain text, not a wrapping chip cloud: a `Form` row that grows with
                            // the selection pushes the body editor off an iPhone screen, which is
                            // the complaint this control exists to answer.
                            Text(chosen.map(\.name).joined(separator: ", "))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 8)
                        Text("\(chosen.count)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(chosen.isEmpty
                    ? "\(title). \(emptySelectionLabel)"
                    : "\(title). \(chosen.map(\.name).joined(separator: ", "))")
                .accessibilityHint(String(localized: "note.editor.picker.hint",
                                          defaultValue: "Opens the full list"))
            }
        }
        .sheet(isPresented: $showsPicker) {
            NoteAssignmentPickerSheet(title: pickerTitle, items: items, selection: $selection,
                                      orderedList: orderedList)
        }
    }
}

// MARK: - NoteAssignmentPickerSheet

/// The full list, searchable, behind ``NoteAssignmentPicker``'s one door.
private struct NoteAssignmentPickerSheet: View {

    let title: String
    let items: [NoteAssignmentPicker.Item]
    @Binding var selection: [UUID]
    let orderedList: ListOrderPreferences.List

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var query = ""

    /// The list as shown, so a drag reorders something the reader can see. Seeded from `items` and
    /// only ever changed by a move — the editor behind this sheet re-reads the stored order when it
    /// next loads.
    @State private var ordered: [NoteAssignmentPicker.Item] = []

    private var filtered: [NoteAssignmentPicker.Item] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return ordered }
        return ordered.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    /// Whether a drag would mean anything right now.
    ///
    /// **Reordering is offered only while the list is UNFILTERED.** A move inside a filtered subset
    /// has no defined meaning — the two rows either side of the one being dragged may not be its
    /// neighbours in the real list — and guessing one would store an order the reader did not make.
    private var canReorder: Bool { query.trimmingCharacters(in: .whitespaces).isEmpty }

    /// The move handler, or `nil` while a filter makes a move meaningless.
    ///
    /// Spelled as a typed property rather than a ternary at the call site: `canReorder ? move : nil`
    /// gave the type-checker an optional-closure-from-method-reference to infer and it reported the
    /// failure on the toolbar twenty lines below, which is not where it was.
    private var reorderAction: ((IndexSet, Int) -> Void)? {
        canReorder ? { source, destination in move(from: source, to: destination) } : nil
    }

    /// Persists the reader's order after a drag.
    private func move(from source: IndexSet, to destination: Int) {
        ordered.move(fromOffsets: source, toOffset: destination)
        ListOrderPreferences.setOrder(ordered.map(\.id), for: orderedList, in: modelContext)
    }

    var body: some View {
        NavigationStack {
            List {
                if filtered.isEmpty {
                    Text(String(localized: "note.editor.picker.noMatches",
                                defaultValue: "Nothing matches that."))
                        .foregroundStyle(.secondary)
                }
                ForEach(filtered) { item in
                    Toggle(item.name, isOn: Binding(
                        get: { selection.contains(item.id) },
                        set: { isOn in
                            if isOn {
                                if !selection.contains(item.id) { selection.append(item.id) }
                            } else {
                                selection.removeAll { $0 == item.id }
                            }
                        }
                    ))
                }
                .onMove(perform: reorderAction)
            }
            .navigationTitle(title)
            .onAppear { if ordered.isEmpty { ordered = items } }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            // **The drawer placement, and Done in the BOTTOM bar.** Both are `CustomScopesView`'s
            // measured fixes for the same shape: an active `.searchable` takes the navigation bar
            // and any primary action with it, and the search field can otherwise render under the
            // keyboard at `isHittable == false`.
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
            .keyboardDismissBar()
            .toolbar {
                // One group, not two items: reordering is the reader's own priority order (#1275),
                // and Done must sit beside it in the BOTTOM bar, where an active `.searchable`
                // cannot take it.
                ToolbarItemGroup(placement: .bottomBar) {
                    // iOS only — `EditButton` is UIKit-backed and does not exist on macOS, where
                    // a `List` with `.onMove` is draggable without one. The `.onMove` itself is
                    // outside this branch, so both platforms reorder; only the affordance differs.
                    if canReorder { EditButton() }
                    Spacer()
                    Button(String(localized: "note.editor.picker.done", defaultValue: "Done")) {
                        dismiss()
                    }
                }
            }
            #else
            .searchable(text: $query)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "note.editor.picker.done", defaultValue: "Done")) {
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .frame(minWidth: 360, minHeight: 420)
            #endif
        }
    }
}
