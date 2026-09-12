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
import SwiftData

// MARK: - AllNotesScreen

/// The whole note list (S-5b), now a Research destination rather than a Settings door (#1275).
///
/// A real `List` rather than a `Form` section, because this is the surface that has to stay
/// usable at three hundred notes. The filters the old pane crammed into a 180-point `HStack`
/// live here as labelled controls and gain a text field — the thing actually missing once the
/// list is long enough to need filtering at all.
///
/// ## Why it moved
/// It was reached through Settings ▸ Notes, a pane that held no settings at all — a list of content
/// behind a gear icon. #1275 moves the list to the Research tab, where the reader's other research
/// objects already live, and retires the pane on the precedent `SettingsPaneModel` set when
/// `.researchGuide` left for the same reason: "it is content, not a setting".
///
/// ## Two presentations, one screen
/// ``Presentation/sheet`` keeps the chrome the Settings door needed — a macOS header and a Done
/// footer, an iOS principal title — while ``Presentation/embedded`` drops all of it, because in
/// Research the surrounding split view or navigation stack supplies the title and the way back.
/// The list, its filters and its editor are identical either way.
///
/// Version history:
///   1.0 — S-5b: the Notes pane's one door
///   1.1 — #1275: moved out of `NotesSettingsView` into Research; gained ``Presentation``
struct AllNotesScreen: View {

    /// Where this screen is being shown, which decides only its chrome.
    enum Presentation {
        /// Presented modally with its own header/footer (the macOS Settings door; retired with the
        /// pane, kept because a sheet host may want it again).
        case sheet
        /// Embedded in a navigation container that supplies the title and the way back.
        case embedded
    }

    /// Which chrome to draw. Defaults to the historical sheet shape.
    var presentation: Presentation = .sheet

    /// The rows to browse. Passed in rather than re-fetched so the sheet and the pane behind it
    /// cannot disagree about what exists.
    let snapshot: NotesPaneSnapshot
    /// Called after a delete, so the pane re-reads.
    let onChanged: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @State private var projectFilter: NotesPaneSnapshot.ProjectFilter = .any
    @State private var tagFilter: UUID?
    @State private var query = ""
    @State private var editingNote: ResearchNote?
    @State private var rowToDelete: NotesPaneSnapshot.Row?
    @State private var localSnapshot: NotesPaneSnapshot?

    /// The snapshot to render — the locally refreshed one once this sheet has deleted something,
    /// otherwise the one handed in.
    private var current: NotesPaneSnapshot { localSnapshot ?? snapshot }

    private var filtered: [NotesPaneSnapshot.Row] {
        let matches = current.filtered(project: projectFilter, tagId: tagFilter)
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return matches }
        return matches.filter {
            $0.bodyText.localizedCaseInsensitiveContains(trimmed)
                || $0.volumeId.localizedCaseInsensitiveContains(trimmed)
                || $0.documentId.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            #if os(macOS)
            if presentation == .sheet {
                header
                Divider()
            }
            #endif
            filters
            Divider()
            list
            #if os(macOS)
            if presentation == .sheet {
                Divider()
                footer
            }
            #endif
        }
        // #1070's affordance. The field was three taps deep in Settings; #1275 makes it a top-level
        // Research destination, which is a material change in how often an iPhone reader meets a
        // search field with no way to put the keyboard away.
        .keyboardDismissBar()
        #if os(macOS)
        .frame(minWidth: presentation == .sheet ? 560 : 420,
               minHeight: presentation == .sheet ? 480 : 320)
        #else
        // Pushed, so the navigation bar carries the title and the count the macOS header block
        // draws for itself, and the system supplies the way back.
        //
        // **The principal item is sheet-only.** In the iPad two-pane Research layout the sidebar and
        // the detail are siblings inside ONE `NavigationStack`, so a `.principal` item installed
        // here writes into the same navigation bar the sidebar's own title uses — no other Research
        // detail does that, and `documentList` sets a plain `.navigationTitle` and nothing else.
        .navigationTitle(String(localized: "settings.notes.all.title", defaultValue: "All Notes"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if presentation == .sheet {
                    VStack(spacing: 1) {
                        Text(String(localized: "settings.notes.all.title",
                                    defaultValue: "All Notes"))
                            .font(.headline)
                        Text(NotesPaneSnapshot.showingCount(shown: filtered.count,
                                                            of: current.total))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        #endif
        .task { localSnapshot = NotesPaneSnapshot.fetch(from: modelContext) }
        .sheet(item: $editingNote, onDismiss: refresh) { note in
            ResearchNoteEditorView(
                documentId: note.documentId,
                volumeId: note.volumeId,
                activeProjectId: nil,
                noteToEdit: note,
                indexingPipeline: appState.indexingPipeline
            )
            .environment(appState)
        }
        .confirmationDialog(
            String(localized: "settings.notes.delete.title", defaultValue: "Delete Note?"),
            isPresented: Binding(get: { rowToDelete != nil },
                                 set: { if !$0 { rowToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button(String(localized: "settings.notes.delete.confirm", defaultValue: "Delete"),
                   role: .destructive) {
                if let row = rowToDelete { delete(row) }
                rowToDelete = nil
            }
            Button(String(localized: "settings.notes.delete.cancel", defaultValue: "Cancel"),
                   role: .cancel) { rowToDelete = nil }
        } message: {
            Text(String(localized: "settings.notes.delete.message",
                        defaultValue: "This note will be permanently deleted."))
        }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "settings.notes.all.title", defaultValue: "All Notes"))
                    .font(.headline)
                Text(NotesPaneSnapshot.showingCount(shown: filtered.count, of: current.total))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var filters: some View {
        #if os(macOS)
        macFilters
        #else
        // Stacked, not a row: three controls side by side do not fit an iPhone's width, and the
        // menu labels are the only thing telling the two pickers apart.
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                projectPicker
                tagPicker
            }
            searchField
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        #endif
    }

    #if os(macOS)
    private var macFilters: some View {
        HStack(spacing: 12) {
            projectPicker
            tagPicker
            searchField
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    #endif

    private var projectPicker: some View {
        Picker(String(localized: "settings.notes.filter.project", defaultValue: "Project"),
               selection: $projectFilter) {
            Text(String(localized: "settings.notes.filter.project.all",
                        defaultValue: "All projects")).tag(NotesPaneSnapshot.ProjectFilter.any)
            Text(String(localized: "settings.notes.filter.project.unfiled",
                        defaultValue: "Not in a project")).tag(NotesPaneSnapshot.ProjectFilter.unfiled)
            ForEach(current.projects, id: \.id) { project in
                Text(project.name).tag(NotesPaneSnapshot.ProjectFilter.id(project.id))
            }
        }
        .frame(maxWidth: 220)
    }

    private var tagPicker: some View {
        Picker(String(localized: "settings.notes.filter.tag", defaultValue: "Tag"),
               selection: $tagFilter) {
            Text(String(localized: "settings.notes.filter.tag.all",
                        defaultValue: "All tags")).tag(UUID?.none)
            ForEach(current.tags, id: \.id) { tag in
                Text(tag.name).tag(UUID?.some(tag.id))
            }
        }
        .frame(maxWidth: 200)
    }

    private var searchField: some View {
        TextField(String(localized: "settings.notes.filter.search",
                         defaultValue: "Search notes…"), text: $query)
            .textFieldStyle(.roundedBorder)
            .frame(minWidth: 140)
            #if os(iOS)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            #endif
    }

    @ViewBuilder
    private var list: some View {
        if filtered.isEmpty {
            ContentUnavailableView(
                String(localized: "settings.notes.none.title", defaultValue: "No Notes"),
                systemImage: "note.text",
                description: Text(current.total == 0
                    ? String(localized: "settings.notes.empty",
                             defaultValue: "No notes yet. Notes you write from a document appear here.")
                    : String(localized: "settings.notes.none.filtered",
                             defaultValue: "No notes match the selected filters."))
            )
            .frame(maxHeight: .infinity)
        } else {
            List(filtered) { row in
                Button {
                    guard let note = NotesPaneSnapshot.note(id: row.id, in: modelContext) else {
                        refresh()
                        return
                    }
                    editingNote = note
                } label: {
                    SettingsNavRow(label: row.title,
                                   detail: row.detail,
                                   value: row.lastModified.map {
                                       $0.formatted(date: .abbreviated, time: .omitted)
                                   })
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) {
                        rowToDelete = row
                    } label: {
                        Label(String(localized: "settings.notes.delete.confirm",
                                     defaultValue: "Delete"), systemImage: "trash")
                    }
                }
            }
            .listStyle(.inset)
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button(String(localized: "settings.notes.done", defaultValue: "Done")) { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Mutations

    private func delete(_ row: NotesPaneSnapshot.Row) {
        guard let note = NotesPaneSnapshot.note(id: row.id, in: modelContext) else {
            // Already gone — the snapshot is stale, so re-read instead of silently doing nothing.
            refresh()
            return
        }
        let volumeId = note.volumeId
        let documentId = note.documentId
        modelContext.delete(note)
        // Flush, so the cross-context @Query consumers (the Research window, Project Home)
        // see the removal promptly — the same reason ResearchNoteEditorView saves after delete.
        try? modelContext.save()
        // #1280: and tell the index. `note_text` is one column per DOCUMENT, so a deletion has to
        // rewrite it from the notes that REMAIN — or clear it when none do. Nothing else does this,
        // so before #1280 a deleted note stayed searchable indefinitely.
        pushRemainingNotesToFTS5(volumeId: volumeId, documentId: documentId)
        refresh()
    }

    /// Rewrites a document's indexed note text from the notes still on it, or clears it (#1280).
    private func pushRemainingNotesToFTS5(volumeId: String, documentId: String) {
        guard let pipeline = appState.indexingPipeline else { return }
        Task {
            await ResearchNote.reindexNoteText(volumeId: volumeId, documentId: documentId,
                                               in: modelContext, pipeline: pipeline)
        }
    }

    private func refresh() {
        localSnapshot = NotesPaneSnapshot.fetch(from: modelContext)
        onChanged()
    }
}
