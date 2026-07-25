// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - TagEditorView

/// The editor behind a tag row — rename, merge, delete (S-3b).
///
/// ## Why this exists
/// Tag administration used to be three different gestures on two platforms. On iOS you renamed by
/// *tapping the row* (or swiping right, if you knew), merged from a small text button, and deleted
/// by swiping left — and the list's footer had to spell all of it out: "Tap or swipe right to
/// rename. Swipe left to delete." An action a footer has to teach is an action nobody finds. On
/// macOS the same three lived behind an unlabelled `•••` menu.
///
/// This is the same editor anatomy `ProjectEditorView` uses — name, then a Manage section with the
/// two consequential actions and a footer that states what each one costs. Both platforms get it,
/// and the swipes stay on iOS as shortcuts for people who already know them.
///
/// The merge picker is presented by the *host* rather than from inside this sheet: a sheet
/// presented from within a sheet is a layout hazard on macOS, and the lists already own
/// `MergeTagSheet`.
///
/// Version history:
///   1.0 — S-3b: initial implementation, replacing macOS `TagRenameSheet` and the iOS
///          tap-to-rename / swipe-to-delete pair
struct TagEditorView: View {

    /// The tag being edited.
    let tag: UserTag
    /// How much is attached to it, so the editor can state the cost of deleting.
    let tally: ResearchItemCounts.TagTally
    /// How many tags exist, so Merge can disable itself when there is nothing to merge into.
    let peerTagCount: Int
    /// Asked to merge this tag into another. `nil` hides the row.
    let onMergeRequested: ((UserTag) -> Void)?
    /// Called after the tag has been deleted, so the host can re-tally. `nil` hides the row.
    let onDeleted: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var showDeleteConfirmation = false

    init(tag: UserTag,
         tally: ResearchItemCounts.TagTally = .init(),
         peerTagCount: Int = 0,
         onMergeRequested: ((UserTag) -> Void)? = nil,
         onDeleted: (() -> Void)? = nil) {
        self.tag = tag
        self.tally = tally
        self.peerTagCount = peerTagCount
        self.onMergeRequested = onMergeRequested
        self.onDeleted = onDeleted
        _name = State(initialValue: tag.name)
    }

    /// Whether Save is disabled (an empty name would leave an unidentifiable tag).
    private var saveDisabled: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var editorTitle: String {
        String(localized: "tag.editor.title", defaultValue: "Edit Tag")
    }

    var body: some View {
        #if os(macOS)
        macBody
        #else
        iOSBody
        #endif
    }

    // MARK: - Platform bodies

    #if os(macOS)
    /// Header row + form + bottom button bar — the repo's macOS sheet idiom. No `NavigationStack`
    /// inside a macOS sheet (it can push Form content outside the visible bounds).
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

            editorForm
                .formStyle(.grouped)

            Divider()

            HStack {
                Button(String(localized: "tag.editor.cancel", defaultValue: "Cancel")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(String(localized: "tag.editor.save", defaultValue: "Save")) {
                    commit()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(saveDisabled)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 420, minHeight: 300)
    }
    #else
    private var iOSBody: some View {
        NavigationStack {
            editorForm
                .navigationTitle(editorTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "tag.editor.cancel", defaultValue: "Cancel")) {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "tag.editor.save", defaultValue: "Save")) {
                            commit()
                            dismiss()
                        }
                        .disabled(saveDisabled)
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }
    #endif

    // MARK: - Form

    private var editorForm: some View {
        Form {
            Section {
                TextField(String(localized: "tag.editor.name.placeholder", defaultValue: "Tag name"),
                          text: $name)
                    .accessibilityLabel(String(localized: "tag.editor.name.a11y",
                                               defaultValue: "Tag name"))
            } header: {
                Text(String(localized: "tag.editor.name.header", defaultValue: "Name"))
            } footer: {
                Text(tally.summary)
            }

            if onMergeRequested != nil || onDeleted != nil {
                Section {
                    if let onMergeRequested {
                        Button {
                            dismiss()
                            onMergeRequested(tag)
                        } label: {
                            Label(String(localized: "tag.editor.merge",
                                         defaultValue: "Merge into Another Tag…"),
                                  systemImage: "arrow.triangle.merge")
                        }
                        .disabled(peerTagCount < 2)
                    }
                    if onDeleted != nil {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label(String(localized: "tag.editor.delete", defaultValue: "Delete Tag"),
                                  systemImage: "trash")
                        }
                    }
                } header: {
                    Text(String(localized: "tag.editor.manage.header", defaultValue: "Manage"))
                } footer: {
                    Text(peerTagCount < 2
                         ? String(localized: "tag.editor.manage.footer.only",
                                  defaultValue: "Merging needs a second tag to merge into. Deleting removes this tag from every note and document that carries it; nothing else is deleted.")
                         : String(localized: "tag.editor.manage.footer",
                                  defaultValue: "Merging re-tags everything here with the tag you choose, then removes this one. Deleting removes this tag from every note and document that carries it; nothing else is deleted."))
                }
            }
        }
        .confirmationDialog(
            String(localized: "tag.editor.delete.title", defaultValue: "Delete Tag?"),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "tag.editor.delete.confirm", defaultValue: "Delete"),
                   role: .destructive) {
                UserTagAdmin.deleteCascading(tag, context: modelContext)
                onDeleted?()
                dismiss()
            }
            Button(String(localized: "tag.editor.delete.cancel", defaultValue: "Cancel"),
                   role: .cancel) {}
        } message: {
            Text(deleteMessage)
        }
    }

    /// Names what the delete will actually touch, using the same tally the row showed.
    private var deleteMessage: String {
        guard tally.notes > 0 || tally.documents > 0 else {
            return String(localized: "tag.editor.delete.message.unused",
                          defaultValue: "This tag isn't applied to anything.")
        }
        return String(localized: "tag.editor.delete.message",
                      defaultValue: "This tag is removed from \(tally.summary). The notes and documents themselves are kept.")
    }

    // MARK: - Save

    private func commit() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != tag.name else { return }
        tag.name = trimmed
    }
}
