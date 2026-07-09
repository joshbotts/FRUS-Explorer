// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - UserTagPickerSheet

/// Document-level user-tag picker, shared by every platform.
///
/// Lists all `UserTag` records from SwiftData and lets the user toggle which tags apply
/// to the current document. A "New Tag" field creates tags inline. This is the single
/// consolidation of the two former near-duplicate pickers — `MacTagPickerSheet` (macOS,
/// in `SupportingViews.swift`) and `TagPickerSheetView` (iOS, in `DocumentView.swift`) —
/// which shared their `@Query`, tag-toggle rows, new-tag field, and the entire
/// create / cancel / save / sync-to-SwiftData logic and differed only in navigation chrome.
///
/// ## Platform layout
/// On macOS, `NavigationStack { List }` inside a `.sheet()` renders the list as a collapsed
/// sidebar with an empty detail area, hiding all controls, so `macBody` uses a plain `VStack`
/// with explicit Cancel / Done buttons. `iOSBody` (iPhone + iPad) keeps the `NavigationStack`
/// toolbar approach with medium/large sheet detents.
///
/// ## Persistence
/// On appear the caller passes the document's current tag IDs as `initialTagIds`. On Done the
/// updated set is written to both `DocumentTagAssignment` (SwiftData/CloudKit) and, via
/// `IndexingPipeline.updateUserTagIds`, to `document_cache` + the FTS5 index. If
/// `indexingPipeline` is nil (document not yet indexed) the FTS5 write is skipped and the
/// sheet dismisses normally.
///
/// Version history:
///   1.0 — Session 1 / #242: consolidated from `MacTagPickerSheet` (v1.3) and
///          `TagPickerSheetView` (v1.2). Behaviour preserved on both platforms; the macOS
///          title's "— Doc N" fragment is now localized and the title reads as one
///          accessibility element. The `tags.picker.*` localization family is retained.
struct UserTagPickerSheet: View {
    let entry: DocumentBrowserEntry
    let indexingPipeline: IndexingPipeline?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \UserTag.name) private var allTags: [UserTag]
    @State private var selectedTagIds: Set<UUID>
    @State private var newTagName: String = ""
    /// Tags inserted during this session — deleted if the user cancels rather than
    /// saves, preventing orphan `UserTag` records when Cancel is tapped.
    @State private var newlyCreatedTags: [UserTag] = []

    init(entry: DocumentBrowserEntry,
         indexingPipeline: IndexingPipeline?,
         initialTagIds: Set<UUID>) {
        self.entry = entry
        self.indexingPipeline = indexingPipeline
        _selectedTagIds = State(initialValue: initialTagIds)
    }

    var body: some View {
        #if os(macOS)
        macBody
        #else
        iOSBody
        #endif
    }

    // MARK: - Tag List Content (shared between both platforms)

    /// The toggle rows and the new-tag field — identical content on both platforms.
    private var tagListContent: some View {
        Group {
            if allTags.isEmpty {
                Section {
                    Text(String(localized: "tags.picker.empty",
                                defaultValue: "No user tags yet. Type a name below to create one."))
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            } else {
                Section(String(localized: "tags.picker.section.yourTags",
                               defaultValue: "Your Tags")) {
                    ForEach(allTags) { tag in
                        Toggle(isOn: Binding(
                            get: { selectedTagIds.contains(tag.id) },
                            set: { on in
                                if on { selectedTagIds.insert(tag.id) }
                                else  { selectedTagIds.remove(tag.id) }
                            }
                        )) {
                            Text(tag.name)
                        }
                    }
                }
            }

            Section(String(localized: "tags.picker.section.newTag", defaultValue: "New Tag")) {
                HStack {
                    TextField(String(localized: "tags.picker.newTag.placeholder",
                                     defaultValue: "Tag name…"), text: $newTagName)
                        .onSubmit { createTag() }
                    Button(String(localized: "tags.picker.newTag.add",
                                  defaultValue: "Add"), action: createTag)
                        .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    /// The document-scoped sheet title, including the document number when known.
    private var navTitle: String {
        if let docNum = entry.documentNumber {
            return String(localized: "tags.picker.nav.titleDoc",
                          defaultValue: "Tags — Doc \(docNum)")
        }
        return String(localized: "tags.picker.nav.title", defaultValue: "Tags")
    }

    // MARK: - macOS Body

    #if os(macOS)
    private var macBody: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text(String(localized: "tags.picker.nav.title",
                            defaultValue: "Tags"))
                    .font(.headline)
                if let docNum = entry.documentNumber {
                    Text(String(localized: "tags.picker.nav.docSuffix",
                                defaultValue: "— Doc \(docNum)"))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            // Read the two-part title as a single element ("Tags — Doc N") rather than
            // letting VoiceOver land on the dash fragment separately.
            .accessibilityElement(children: .combine)
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Divider()

            List {
                tagListContent
            }
            .listStyle(.inset)

            Divider()

            // Button bar
            HStack {
                Button(String(localized: "tags.picker.cancel", defaultValue: "Cancel")) {
                    cancelAndDismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(String(localized: "tags.picker.done", defaultValue: "Done")) {
                    saveAndDismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 340, minHeight: 300)
    }
    #endif

    // MARK: - iOS Body

    #if os(iOS)
    private var iOSBody: some View {
        NavigationStack {
            List {
                tagListContent
            }
            .listStyle(.inset)
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "tags.picker.cancel",
                                  defaultValue: "Cancel")) { cancelAndDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "tags.picker.done",
                                  defaultValue: "Done")) { saveAndDismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    #endif

    // MARK: - Helpers

    private func createTag() {
        let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let tag = UserTag(name: name)
        modelContext.insert(tag)
        newlyCreatedTags.append(tag)
        selectedTagIds.insert(tag.id)
        newTagName = ""
    }

    private func cancelAndDismiss() {
        for tag in newlyCreatedTags { modelContext.delete(tag) }
        dismiss()
    }

    private func saveAndDismiss() {
        // SwiftData write and dismissal happen immediately on the main thread.
        // The FTS5 virtual table update (delete + full re-insert) can take 100–500 ms
        // on iPhone storage; running it in the background eliminates visible lag.
        // For unindexed documents the FTS5 path is skipped entirely.
        syncAssignmentsToSwiftData()
        dismiss()
        guard let pipeline = indexingPipeline else { return }
        let tagString = selectedTagIds.isEmpty
            ? nil
            : selectedTagIds.map(\.uuidString).joined(separator: " ")
        let vId = entry.volumeId
        let dId = entry.documentId
        Task.detached(priority: .utility) {
            try? await pipeline.updateUserTagIds(
                volumeId: vId,
                documentId: dId,
                userTagIds: tagString
            )
        }
    }

    /// Replaces all `DocumentTagAssignment` records for the current document with the
    /// current `selectedTagIds` selection, then saves the context.
    ///
    /// This keeps `DocumentTagAssignment` (SwiftData/CloudKit) in sync with
    /// `document_cache.user_tag_ids` (SQLite/FTS5) written by the pipeline.
    private func syncAssignmentsToSwiftData() {
        let vId = entry.volumeId
        let dId = entry.documentId

        // Delete all existing assignments for this document.
        let descriptor = FetchDescriptor<DocumentTagAssignment>(
            predicate: #Predicate<DocumentTagAssignment> { a in
                a.volumeId == vId && a.documentId == dId
            }
        )
        for assignment in (try? modelContext.fetch(descriptor)) ?? [] {
            modelContext.delete(assignment)
        }

        // Insert a new assignment for each selected tag.
        for tagId in selectedTagIds {
            modelContext.insert(DocumentTagAssignment(
                volumeId: vId, documentId: dId, tagId: tagId
            ))
        }

        try? modelContext.save()
    }
}
