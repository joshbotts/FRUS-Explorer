// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - NotesSettingsView

/// Settings → Research → Notes — every research note on this device.
///
/// Shared by both platforms. It was macOS-only until the research-session gap was traced — the
/// "Log Research Sessions" switch used to live here, and iOS had no control for it at all. The
/// switch has since moved to its own `ResearchSessionsView`, where it belongs; what this pane
/// keeps is the reason iOS still wants it: a flat, note-grained browser the platform never had
/// (its Research tab lists documents, never notes).
///
/// ## What changed in S-5b (macOS)
/// - Native `Form(.grouped)` replaces the bespoke split layout (a padded header block, a
///   `Divider`, then a greedy full-height `List`), which was the last hand-rolled pane.
/// - The pane shows the five most recent notes and puts the whole list behind one door — the
///   grammar the Volumes & Storage hub already ships for downloaded volumes. A `Form` cannot
///   host a full-height scrolling list, and a `Section` of three hundred notes would be three
///   hundred eagerly-composed rows inside another scroll view.
/// - Three live `@Query`s become one `NotesPaneSnapshot`, refreshed on appear and after every
///   mutation. See that type for why.
/// - Rows are `Button`s, not `.onTapGesture` on a `VStack` — a tap gesture is invisible to
///   VoiceOver and unreachable from the keyboard.
/// - The "Untagged" project filter used to be tagged with the all-zeros UUID and matched with
///   `projectIds.contains(_:)`, so it could never return anything. It is a real case now.
/// - The editor sheet receives `indexingPipeline` and `AppState`, so a note edited here reaches
///   FTS5 like one edited anywhere else. It did not before.
struct NotesSettingsView: View {

    /// How many notes the pane lists before deferring to the full-list sheet. The hub uses three
    /// for one-line volume rows; note rows are two lines, and five is about a screen-third —
    /// enough to answer "did my last note save?" without the pane becoming a list.
    private static let inlineNoteLimit = 5

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    #if os(macOS)
    /// Whether the Settings window is the active one. On macOS Settings is a sibling window, not
    /// a modal — the main window stays live behind it, so a note written or deleted there must
    /// re-read here when the user comes back. A one-shot `.task` alone would show them the state
    /// of the world when they opened the pane.
    @Environment(\.controlActiveState) private var controlActiveState
    #else
    /// The iOS equivalent of the above: Settings is a tab, and a note can be written in the
    /// Research tab or a document while this view stays alive in the background.
    @Environment(\.scenePhase) private var scenePhase
    #endif

    @State private var snapshot: NotesPaneSnapshot = .empty
    @State private var editingNote: ResearchNote?
    @State private var showsAllNotes = false

    var body: some View {
        Form {
            notesSection
        }
        #if os(macOS)
        .formStyle(.grouped)
        #endif
        .navigationTitle(String(localized: "settings.pane.notes", defaultValue: "Notes"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(macOS)
        .frame(maxWidth: .infinity)
        .scrollIndicators(.visible)
        #endif
        .task { refresh() }
        #if os(macOS)
        .onChange(of: controlActiveState) { _, state in
            if state != .inactive { refresh() }
        }
        #else
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh() }
        }
        #endif
        // The whole list is a sheet on macOS (the Settings window has no navigation chrome to
        // push into) and a push on iOS (where it does, and where a second modal over a tab reads
        // as a dead end). Same screen either way.
        #if os(macOS)
        .sheet(isPresented: $showsAllNotes, onDismiss: refresh) {
            AllNotesScreen(snapshot: snapshot, onChanged: refresh)
        }
        #else
        .navigationDestination(isPresented: $showsAllNotes) {
            AllNotesScreen(snapshot: snapshot, onChanged: refresh)
                .onDisappear { refresh() }
        }
        #endif
        .sheet(item: $editingNote, onDismiss: refresh) { note in
            noteEditorSheet(for: note)
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var notesSection: some View {
        Section {
            if snapshot.total == 0 {
                Text(String(localized: "settings.notes.empty",
                            defaultValue: "No notes yet. Notes you write from a document appear here."))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(snapshot.rows.prefix(Self.inlineNoteLimit)) { row in
                    noteRow(row)
                }
                Button {
                    showsAllNotes = true
                } label: {
                    HStack {
                        Label(String(localized: "settings.notes.showAll", defaultValue: "All Notes"),
                              systemImage: "note.text")
                            .labelStyle(.titleAndIcon)
                        Spacer(minLength: 8)
                        Text(NotesPaneSnapshot.noteCount(snapshot.total))
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
            }
        } header: {
            Text(String(localized: "settings.notes.recent.header", defaultValue: "Recent Notes"))
        } footer: {
            if snapshot.total > 0 {
                Text(NotesPaneSnapshot.showingCount(
                    shown: min(Self.inlineNoteLimit, snapshot.total), of: snapshot.total))
            }
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private func noteRow(_ row: NotesPaneSnapshot.Row) -> some View {
        Button {
            // A nil lookup means the snapshot is stale — the note went away since the row was
            // drawn. Re-read rather than leave a ghost row that does nothing when clicked.
            guard let note = NotesPaneSnapshot.note(id: row.id, in: modelContext) else {
                refresh()
                return
            }
            editingNote = note
        } label: {
            HStack {
                SettingsNavRow(label: row.title,
                               detail: row.detail,
                               value: row.lastModified.map {
                                   $0.formatted(date: .abbreviated, time: .omitted)
                               })
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .lineLimit(2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(String(localized: "settings.notes.row.a11y",
                                  defaultValue: "Opens the research note editor"))
    }

    // MARK: - Editor

    private func noteEditorSheet(for note: ResearchNote) -> some View {
        ResearchNoteEditorView(
            documentId: note.documentId,
            volumeId: note.volumeId,
            activeProjectId: nil,
            noteToEdit: note,
            indexingPipeline: appState.indexingPipeline
        )
        .environment(appState)
    }

    // MARK: - State

    private func refresh() {
        snapshot = NotesPaneSnapshot.fetch(from: modelContext)
    }
}

// MARK: - AllNotesScreen

/// The whole note list, behind the Notes pane's one door (S-5b).
///
/// A real `List` rather than a `Form` section, because this is the surface that has to stay
/// usable at three hundred notes. The filters the old pane crammed into a 180-point `HStack`
/// live here as labelled controls and gain a text field — the thing actually missing once the
/// list is long enough to need filtering at all.
private struct AllNotesScreen: View {

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
            header
            Divider()
            #endif
            filters
            Divider()
            list
            #if os(macOS)
            Divider()
            footer
            #endif
        }
        #if os(macOS)
        .frame(minWidth: 560, minHeight: 480)
        #else
        // Pushed, so the navigation bar carries the title and the count the macOS header block
        // draws for itself, and the system supplies the way back.
        .navigationTitle(String(localized: "settings.notes.all.title", defaultValue: "All Notes"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(String(localized: "settings.notes.all.title", defaultValue: "All Notes"))
                        .font(.headline)
                    Text(NotesPaneSnapshot.showingCount(shown: filtered.count, of: current.total))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
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
        modelContext.delete(note)
        // Flush, so the cross-context @Query consumers (the Research window, Project Home)
        // see the removal promptly — the same reason ResearchNoteEditorView saves after delete.
        try? modelContext.save()
        refresh()
    }

    private func refresh() {
        localSnapshot = NotesPaneSnapshot.fetch(from: modelContext)
        onChanged()
    }
}

