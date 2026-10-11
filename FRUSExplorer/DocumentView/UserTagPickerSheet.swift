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
///   1.1 — Session 1 / #242: tags created in this sheet session are pinned to the top of
///          "Your Tags" (newest-first, with a "New" badge) instead of materialising at their
///          alphabetical position off-screen; the New Tag field moves above the list so
///          creation and the pinned tag are co-located; creating a tag moves VoiceOver focus
///          onto the new row and announces it.
///   1.2 — Session 1 review pass: restored two iOS parity losses from consolidating toward
///          the old struct's never-compiled iOS body (`.insetGrouped` list style; documentId
///          title fallback for unnumbered documents); empty-state copy re-pointed "above"
///          under a new key after the field reorder; Cancel now clears `newlyCreatedTags`
///          before deleting so `displayTags` never renders context-deleted models
///          (mid-dismissal SwiftData trap).
///   1.3 — #1275: "Your Tags" follows the reader's own order over the alphabetical baseline; tags
///          created in this session still pin to the top.
///   1.4 — #1576 lane 5: an adding mode, for the documents of a search result or a selection.
///          Its Done adds the tags switched on and takes none off: the writer that replaces a
///          document's tag set takes the one document as its argument, and the adding mode has
///          none to give it.
struct UserTagPickerSheet: View {

    /// What the sheet writes on Done.
    private enum Mode {
        /// One document. The toggles show its tags, and Done replaces its tag set with them.
        case document(DocumentBrowserEntry)
        /// The documents of a command chosen on search results (#1576 lane 5). Every toggle
        /// starts off, and Done adds the tags switched on to each document, keeping the tags it
        /// has. The list is frozen by the request that carries it.
        case adding([CollectionDocumentRef])
    }

    private let mode: Mode
    let indexingPipeline: IndexingPipeline?
    /// Told what an adding-mode Done did, and the names of the tags it gave.
    private let onTagged: ((UserTagAssign, [String]) -> Void)?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \UserTag.name) private var allTags: [UserTag]
    /// The preferences record carrying the reader's own tag order (#1275).
    @Query(sort: \SyncedPreferences.createdAt) private var preferences: [SyncedPreferences]
    @State private var selectedTagIds: Set<UUID>
    @State private var newTagName: String = ""
    /// Tags inserted during this session — deleted if the user cancels rather than
    /// saves, preventing orphan `UserTag` records when Cancel is tapped.
    ///
    /// This array is also the *source of truth for the pin-to-top ordering* (#242): it is
    /// synchronous state, so a freshly created tag can be shown at the top of the list
    /// immediately, without waiting for the alphabetical `@Query` (`allTags`) to refresh.
    @State private var newlyCreatedTags: [UserTag] = []
    /// Drives VoiceOver focus onto a tag row the moment it is created, confirming the
    /// creation to a VoiceOver user even though the field they were typing in is elsewhere.
    @AccessibilityFocusState private var focusedTagID: UUID?
    /// Adding mode: how many of the documents carry each tag already, read once as the sheet
    /// opens. Empty in document mode, and when the assignments could not be read.
    @State private var carriedCounts: [UUID: Int] = [:]
    /// Adding mode: why Done added nothing, shown as an alert; `nil` otherwise.
    @State private var addFailure: String?
    /// Whether Done or Cancel has already closed the sheet. One of the two, once, to a
    /// presentation: the sheet stays up for a moment after it is dismissed, and a second Return or
    /// Esc in that moment would run the other. Cancel after a Done deletes the tags made in the
    /// sheet, which documents have just been given; a second Done in the adding mode adds nothing
    /// and replaces the line that offered to undo the first.
    @State private var isClosed = false

    init(entry: DocumentBrowserEntry,
         indexingPipeline: IndexingPipeline?,
         initialTagIds: Set<UUID>) {
        self.mode = .document(entry)
        self.indexingPipeline = indexingPipeline
        self.onTagged = nil
        _selectedTagIds = State(initialValue: initialTagIds)
    }

    /// The picker in its adding mode (#1576 lane 5).
    ///
    /// - Parameters:
    ///   - documents: The documents to tag, frozen when the command was chosen.
    ///   - indexingPipeline: The index whose tag column is rewritten for the documents that gain
    ///     a tag, or `nil` when there is none.
    ///   - onTagged: Told what Done did and the names of the tags it gave.
    init(adding documents: [CollectionDocumentRef],
         indexingPipeline: IndexingPipeline?,
         onTagged: ((UserTagAssign, [String]) -> Void)?) {
        self.mode = .adding(documents)
        self.indexingPipeline = indexingPipeline
        self.onTagged = onTagged
        _selectedTagIds = State(initialValue: [])
    }

    /// The documents of the adding mode, or `nil` in document mode.
    private var addingDocuments: [CollectionDocumentRef]? {
        if case .adding(let documents) = mode { return documents }
        return nil
    }

    var body: some View {
        platformBody
            .onAppear {
                guard let documents = addingDocuments, carriedCounts.isEmpty else { return }
                // A failed fetch leaves the counts out. Done makes the same read, and its alert
                // says the tags could not be read or saved.
                let assignments = (try? modelContext.fetch(FetchDescriptor<DocumentTagAssignment>())) ?? []
                carriedCounts = UserTagPickerCopy.carriedCounts(
                    of: documents,
                    in: assignments.map { (volumeId: $0.volumeId, documentId: $0.documentId, tagId: $0.tagId) })
            }
            // The adding mode's write can be refused, and its fetch or save can fail. One alert
            // on the body, as the collection picker has for its own.
            .alert(UserTagPickerCopy.addFailedTitle,
                   isPresented: Binding(get: { addFailure != nil },
                                        set: { if !$0 { addFailure = nil } })) {
                Button(String(localized: "tags.picker.addFailed.ok", defaultValue: "OK")) {
                    addFailure = nil
                }
            } message: {
                Text(addFailure ?? "")
            }
    }

    @ViewBuilder
    private var platformBody: some View {
        #if os(macOS)
        macBody
        #else
        iOSBody
        #endif
    }

    // MARK: - Tag List Content (shared between both platforms)

    /// Set of IDs for tags created during this sheet session (pinned to the top).
    private var newTagIDs: Set<UUID> { Set(newlyCreatedTags.map(\.id)) }

    /// The tag list in display order: tags created this session first (newest-first),
    /// then the remaining tags in the reader's own order over the alphabetical baseline (#1275). Built from the
    /// synchronous `newlyCreatedTags` state so a just-created tag appears at the top
    /// immediately rather than materialising at its alphabetical position off-screen.
    private var displayTags: [UserTag] {
        let ordered = ListOrderPreferences.apply(
            allTags, order: ListOrderPreferences.order(for: .tags, in: preferences), id: \.id)
        guard !newlyCreatedTags.isEmpty else { return ordered }
        let pinned = newTagIDs
        return newlyCreatedTags.reversed() + ordered.filter { !pinned.contains($0.id) }
    }

    /// The toggle rows and the new-tag field — identical content on both platforms.
    ///
    /// The New Tag field sits at the *top* so creation and the freshly-pinned tag are
    /// co-located: a tag created here jumps to the head of "Your Tags" directly below,
    /// giving immediate visible confirmation without scrolling (#242).
    private var tagListContent: some View {
        Group {
            Section(String(localized: "tags.picker.section.newTag", defaultValue: "New Tag")) {
                HStack {
                    TextField(String(localized: "tags.picker.newTag.placeholder",
                                     defaultValue: "Tag name…"), text: $newTagName)
                        .accessibilityLabel(String(localized: "tags.picker.newTag.field.a11y",
                                                   defaultValue: "New tag name"))
                        .onSubmit { createTag() }
                    Button(String(localized: "tags.picker.newTag.add",
                                  defaultValue: "Add"), action: createTag)
                        .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            if displayTags.isEmpty {
                Section {
                    // New key (not tags.picker.empty): the field moved above this message,
                    // so the directional copy changed meaning.
                    Text(String(localized: "tags.picker.empty.fieldAbove",
                                defaultValue: "No user tags yet. Type a name above to create one."))
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            } else {
                yourTagsSection {
                    ForEach(displayTags) { tag in
                        Toggle(isOn: Binding(
                            get: { selectedTagIds.contains(tag.id) },
                            set: { on in
                                if on { selectedTagIds.insert(tag.id) }
                                else  { selectedTagIds.remove(tag.id) }
                            }
                        )) {
                            HStack(spacing: 8) {
                                Text(tag.name)
                                if newTagIDs.contains(tag.id) {
                                    // A text badge (not colour alone) so the non-alphabetical
                                    // position is self-explanatory and survives VoiceOver /
                                    // colour-blind viewing.
                                    Text(String(localized: "tags.picker.badge.new",
                                                defaultValue: "New"))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 1)
                                        .background(.quaternary, in: Capsule())
                                }
                                // Adding mode: how many of the documents carry this tag already,
                                // so the reader sees what switching it on would change.
                                if let documents = addingDocuments,
                                   let carried = UserTagPickerCopy.carried(carriedCounts[tag.id] ?? 0,
                                                                           of: documents.count) {
                                    Spacer(minLength: 8)
                                    Text(carried)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .accessibilityFocused($focusedTagID, equals: tag.id)
                    }
                }
            }
        }
    }

    /// The "Your Tags" section around its rows. The document mode's is the titled section it has always
    /// been; the adding mode's has under it the line that tags are only added, wrapped on the Mac (#1475).
    @ViewBuilder
    private func yourTagsSection<Rows: View>(@ViewBuilder rows: () -> Rows) -> some View {
        let title = String(localized: "tags.picker.section.yourTags", defaultValue: "Your Tags")
        if addingDocuments != nil {
            WrappingFooterSection {
                rows()
            } header: {
                Text(title)
            } footer: {
                Text(UserTagPickerCopy.addingFooter)
            }
        } else {
            Section(title) {
                rows()
            }
        }
    }

    /// The document-scoped sheet title: "Tags — Doc N" when the printed document number is
    /// known, falling back to the document's xml:id (editorial notes and unnumbered
    /// front-matter entries have no number) so the sheet always identifies WHICH document is
    /// being tagged — parity with the original iOS picker.
    private var navTitle: String {
        switch mode {
        case .adding(let documents):
            return UserTagPickerCopy.addingTitle(count: documents.count)
        case .document(let entry):
            if let docNum = entry.documentNumber {
                return String(localized: "tags.picker.nav.titleDoc",
                              defaultValue: "Tags — Doc \(docNum)")
            }
            return String(localized: "tags.picker.nav.titleId",
                          defaultValue: "Tags — \(entry.documentId)")
        }
    }

    // MARK: - macOS Body

    #if os(macOS)
    private var macBody: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                switch mode {
                case .adding(let documents):
                    Text(UserTagPickerCopy.addingTitle(count: documents.count))
                        .font(.headline)
                case .document(let entry):
                    Text(String(localized: "tags.picker.nav.title",
                                defaultValue: "Tags"))
                        .font(.headline)
                    if let docNum = entry.documentNumber {
                        Text(String(localized: "tags.picker.nav.docSuffix",
                                    defaultValue: "— Doc \(docNum)"))
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
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
            // .insetGrouped, matching the shipped iOS picker (which used the platform
            // default) and the sibling document sheets — NOT .inset, which came from the
            // never-compiled iOSBody of the old macOS struct.
            .listStyle(.insetGrouped)
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
        // The new tag is now pinned at the top of "Your Tags" and selected. Move VoiceOver
        // focus onto it and announce, so a VoiceOver user (whose focus was in the field)
        // gets confirmation that the tag was created and applied (#242).
        focusedTagID = tag.id
        AccessibilityNotification.Announcement(
            String(localized: "tags.picker.created.a11y",
                   defaultValue: "Tag \(name) created and selected")
        ).post()
    }

    private func cancelAndDismiss() {
        guard !isClosed else { return }
        isClosed = true
        // Snapshot-and-clear BEFORE deleting: `displayTags`/`newTagIDs` render directly from
        // `newlyCreatedTags`, and deleting a model the body still references re-renders the
        // sheet mid-dismissal against context-deleted instances (SwiftData traps on property
        // access once the deletion saves). Clearing first drops every render path back to the
        // `@Query`, which removes deleted models atomically.
        let doomed = newlyCreatedTags
        newlyCreatedTags.removeAll()
        for tag in doomed { modelContext.delete(tag) }
        dismiss()
    }

    /// Done. Each mode has a writer of its own, and the one that replaces a tag set is given the
    /// one document it replaces them for: the adding mode has no such document to hand it.
    private func saveAndDismiss() {
        guard !isClosed else { return }
        switch mode {
        case .document(let entry):
            replaceTags(of: entry)
        case .adding(let documents):
            // A write that was refused or failed has said why, and the sheet stays up.
            guard addTags(to: documents) else { return }
        }
        isClosed = true
        dismiss()
    }

    /// The adding mode's Done (#1576 lane 5): gives each document the tags switched on, keeping
    /// the tags it has, and tells the host.
    ///
    /// - Returns: Whether the sheet may close. `false` when the write was refused or failed: the
    ///   alert says why, and the sheet stays up.
    private func addTags(to documents: [CollectionDocumentRef]) -> Bool {
        // In the order the list shows them, which is the order the outcome names them in.
        let chosen = displayTags.filter { selectedTagIds.contains($0.id) }
        guard !chosen.isEmpty else {
            keepNewTags()
            return true
        }
        do {
            let outcome = try UserTagAdmin.assignAndIndex(
                tagIds: chosen.map(\.id), to: documents, context: modelContext, pipeline: indexingPipeline)
            keepNewTags()
            onTagged?(outcome, chosen.map(\.name))
            return true
        } catch {
            addFailure = UserTagPickerCopy.addFailure(error)
            return false
        }
    }

    /// Saves a tag made in this sheet that Done did not give to any document: one made and then
    /// switched off. The bulk writer saves only when it inserts an assignment, and the document
    /// mode's Done always saves, so without this the two modes would differ in whether such a
    /// tag is on disk when the sheet closes.
    private func keepNewTags() {
        guard !newlyCreatedTags.isEmpty, modelContext.hasChanges else { return }
        try? modelContext.save()
    }

    /// The document mode's Done: replaces the document's tag set with the toggles', in the store
    /// and then in the index.
    private func replaceTags(of entry: DocumentBrowserEntry) {
        // The SwiftData write happens at once on the main thread, and the caller dismisses.
        // The index write runs in the background. For unindexed documents it is skipped.
        syncAssignmentsToSwiftData(for: entry)
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

    /// Replaces all `DocumentTagAssignment` records for one document with the
    /// current `selectedTagIds` selection, then saves the context.
    ///
    /// This keeps `DocumentTagAssignment` (SwiftData/CloudKit) in sync with
    /// `document_cache.user_tag_ids` (SQLite/FTS5) written by the pipeline.
    ///
    /// - Parameter entry: The document whose tag set is replaced. A parameter and not a property:
    ///   the adding mode has many documents and must never reach this.
    private func syncAssignmentsToSwiftData(for entry: DocumentBrowserEntry) {
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

// MARK: - UserTagPickerCopy

/// The words and the one count of the tag picker's adding mode, apart from the view so that a
/// test can read them off the main actor (#1576 lane 5).
///
/// Version history:
///   1.0 — #1576 lane 5: initial implementation
enum UserTagPickerCopy {

    /// The adding mode's title: "Tag 37 Documents", and "Tag 1 Document" for one.
    ///
    /// - Parameters:
    ///   - count: The documents the command carries.
    ///   - locale: The locale that groups the count; the user's own unless a test passes one.
    static func addingTitle(count: Int, locale: Locale = .autoupdatingCurrent) -> String {
        CountCopy.phrase(
            count,
            one: String(localized: "tags.picker.adding.title.one %@", defaultValue: "Tag %@ Document"),
            many: String(localized: "tags.picker.adding.title.many %@", defaultValue: "Tag %@ Documents"),
            locale: locale)
    }

    /// The line under the adding mode's tags.
    static var addingFooter: String {
        String(localized: "tags.picker.adding.footer",
               defaultValue: "Tags are added. A document keeps the tags it already has.")
    }

    /// Beside a tag in the adding mode: how many of the documents carry it already. Nothing when
    /// none does, so that the common case is a plain list.
    ///
    /// - Parameters:
    ///   - carried: Documents of the command that carry the tag.
    ///   - total: Documents the command carries.
    ///   - locale: The locale that groups the counts; the user's own unless a test passes one.
    /// - Returns: The words, or `nil` when no document carries the tag.
    static func carried(_ carried: Int, of total: Int, locale: Locale = .autoupdatingCurrent) -> String? {
        guard carried > 0, total > 0 else { return nil }
        if total == 1 {
            return String(localized: "tags.picker.adding.carried.single", defaultValue: "Already has it")
        }
        if carried >= total {
            return String(format: String(localized: "tags.picker.adding.carried.all %@",
                                         defaultValue: "All %@ have it"),
                          total.formatted(.number.locale(locale)))
        }
        return CountCopy.phrase(
            carried,
            one: String(localized: "tags.picker.adding.carried.one %@ %@", defaultValue: "%1$@ of %2$@ has it"),
            many: String(localized: "tags.picker.adding.carried.many %@ %@", defaultValue: "%1$@ of %2$@ have it"),
            then: [total.formatted(.number.locale(locale))], locale: locale)
    }

    /// How many of `documents` carry each tag, from every assignment in the store. A tag a
    /// document carries twice (two devices tagged it before they synced) is counted once for it.
    ///
    /// - Parameters:
    ///   - documents: The documents the command carries.
    ///   - assignments: Every assignment in the store.
    /// - Returns: For each tag at least one of the documents carries, how many carry it.
    static func carriedCounts(
        of documents: [CollectionDocumentRef],
        in assignments: [(volumeId: String, documentId: String, tagId: UUID)]
    ) -> [UUID: Int] {
        let asked = Set(documents)
        var holders: [UUID: Set<CollectionDocumentRef>] = [:]
        for assignment in assignments {
            let document = CollectionDocumentRef(volumeId: assignment.volumeId, documentId: assignment.documentId)
            guard asked.contains(document) else { continue }
            holders[assignment.tagId, default: []].insert(document)
        }
        return holders.mapValues(\.count)
    }

    /// The title of the alert a failed adding-mode Done shows.
    static var addFailedTitle: String {
        String(localized: "tags.picker.addFailed.title", defaultValue: "Not Tagged")
    }

    /// What a failed adding-mode Done says.
    ///
    /// - Parameters:
    ///   - error: What `UserTagAdmin.assign` threw.
    ///   - locale: The locale that groups the counts; the user's own unless a test passes one.
    /// - Returns: The alert's message.
    static func addFailure(_ error: any Error, locale: Locale = .autoupdatingCurrent) -> String {
        switch error as? UserTagAssignRefusal {
        case .overLimit(let count, let limit):
            return String(format: String(
                localized: "tags.picker.addFailed.overLimit %@ %@",
                defaultValue: "Up to %2$@ can be tagged at a time, and %1$@ were chosen."),
                CountCopy.documents(count, locale: locale),
                CountCopy.documents(limit, locale: locale))
        case nil:
            return String(format: String(
                localized: "tags.picker.addFailed.save %@",
                defaultValue: "The tags could not be read or saved, so no document was tagged. %@"),
                error.localizedDescription)
        }
    }
}
