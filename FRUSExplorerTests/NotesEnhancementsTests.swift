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

import Testing
import Foundation
import SwiftData
@testable import FRUSExplorer

/// The #1275 notes work: the reader's own list order, the formatted body, and the FTS5 column the
/// note editor used to overwrite.
///
/// Version history:
///   1.0 — #1275: initial implementation
@Suite("Notes enhancements (#1275)")
@MainActor
struct NotesEnhancementsTests {

    // MARK: - The reader's own order

    private struct Named: Identifiable {
        let id: UUID
        let name: String
    }

    private static func named(_ names: String...) -> [Named] {
        names.map { Named(id: UUID(), name: $0) }
    }

    @Test("A stored order is a permutation of the baseline, not a replacement for it")
    func orderPermutesRatherThanReplaces() {
        let items = Self.named("Alpha", "Bravo", "Charlie", "Delta")
        // The reader pulled the third and first to the top; the rest must keep the baseline's own
        // sequence exactly, which is what makes this a permutation.
        let order = [items[2].id, items[0].id]
        let result = ListOrderPreferences.apply(items, order: order, id: \.id)
        #expect(result.map(\.name) == ["Charlie", "Alpha", "Bravo", "Delta"])
    }

    @Test("An item the order does not name is kept, not dropped")
    func unorderedItemsSurvive() {
        let items = Self.named("Alpha", "Bravo")
        // A tag created after the reader last reordered. Dropping it would make a new tag invisible
        // in the one list that is supposed to show every tag.
        let result = ListOrderPreferences.apply(items, order: [items[1].id], id: \.id)
        #expect(result.map(\.name) == ["Bravo", "Alpha"])
        #expect(result.count == items.count)
    }

    @Test("An order naming something that no longer exists is ignored, not obeyed")
    func staleIdsAreIgnored() {
        let items = Self.named("Alpha", "Bravo")
        // A tag merged or deleted on another device. Its id stays in the stored order until the
        // reader next reorders, and must not disturb what survives.
        let result = ListOrderPreferences.apply(items, order: [UUID(), items[1].id, UUID()], id: \.id)
        #expect(result.map(\.name) == ["Bravo", "Alpha"])
    }

    @Test("No stored order leaves the baseline exactly as it was")
    func emptyOrderIsIdentity() {
        let items = Self.named("Alpha", "Bravo", "Charlie")
        let result = ListOrderPreferences.apply(items, order: [], id: \.id)
        #expect(result.map(\.name) == ["Alpha", "Bravo", "Charlie"])
    }

    @Test("The two lists are stored independently in one record")
    func tagsAndProjectsDoNotOverwriteEachOther() throws {
        let container = try ModelContainer.makeTestContainer()
        let ctx = container.mainContext
        let tagOrder = [UUID(), UUID()]
        let projectOrder = [UUID()]

        ListOrderPreferences.setOrder(tagOrder, for: .tags, in: ctx)
        ListOrderPreferences.setOrder(projectOrder, for: .projects, in: ctx)

        #expect(ListOrderPreferences.order(for: .tags, in: ctx) == tagOrder, """
            Writing the project order cleared the tag order. The two share one JSON property to \
            cost one CloudKit identifier rather than two, so each write has to merge into what is \
            already there.
            """)
        #expect(ListOrderPreferences.order(for: .projects, in: ctx) == projectOrder)

        // One record, not one per write — `SettingsSyncCoordinator` resolves the same way.
        #expect(try ctx.fetch(FetchDescriptor<SyncedPreferences>()).count == 1)
    }

    @Test("A reader who has never reordered has no stored order")
    func noRecordMeansNoOrder() throws {
        let container = try ModelContainer.makeTestContainer()
        #expect(ListOrderPreferences.order(for: .tags, in: container.mainContext).isEmpty)
    }

    // MARK: - The formatted body

    @Test("A saved note carries both the formatted body and its plain projection")
    func saveStoresRichTextBesideBodyText() throws {
        let container = try ModelContainer.makeTestContainer()
        let ctx = container.mainContext
        let vm = ResearchNoteEditorViewModel(documentId: "d1", volumeId: "frus1969-76v01",
                                             activeProjectId: nil)
        vm.bodyText = "A plain projection."
        vm.richText = Data("{\\rtf1}".utf8)
        vm.save(context: ctx)

        let note = try #require(try ctx.fetch(FetchDescriptor<ResearchNote>()).first)
        #expect(note.bodyText == "A plain projection.", """
            `bodyText` must stay authoritative: search, the Zotero and Obsidian exports, the JSON \
            envelope and all five in-app previews read it and know nothing about formatting.
            """)
        #expect(note.richText == Data("{\\rtf1}".utf8))
    }

    @Test("Editing an existing note stores the formatted body too")
    func editingAnExistingNoteStoresRichText() throws {
        // The sibling test above creates a NEW note, which is the `else` branch of `save`. Both
        // branches have to carry `richText`, and only this one covers the edit path — measured, on
        // the mutation that dropped it: with only the create test, deleting the assignment on the
        // edit branch changed nothing that any test could see.
        let container = try ModelContainer.makeTestContainer()
        let ctx = container.mainContext
        let existing = ResearchNote(documentId: "d1", volumeId: "frus1969-76v01",
                                    bodyText: "Before.")
        ctx.insert(existing)

        let vm = ResearchNoteEditorViewModel(documentId: "d1", volumeId: "frus1969-76v01",
                                             activeProjectId: nil, noteToEdit: existing)
        vm.bodyText = "After."
        vm.richText = Data("{\\rtf1 edited}".utf8)
        vm.save(context: ctx)

        #expect(existing.bodyText == "After.")
        #expect(existing.richText == Data("{\\rtf1 edited}".utf8), """
            Formatting applied to an existing note was discarded on save — the reader would format             a note, close it, and find plain text.
            """)
    }

    @Test("Inserting a summary tells the editor to reload, and drops the stale formatting")
    func promotingASummaryRemountsTheBody() throws {
        let container = try ModelContainer.makeTestContainer()
        let ctx = container.mainContext
        let summary = GeneratedSummary(documentId: "d1", volumeId: "frus1969-76v01",
                                       promptId: UUID(), responseText: "The summary text.")
        ctx.insert(summary)

        let vm = ResearchNoteEditorViewModel(documentId: "d1", volumeId: "frus1969-76v01",
                                             activeProjectId: nil)
        vm.bodyText = "Existing prose."
        vm.richText = Data("{\\rtf1 stale}".utf8)
        let before = vm.bodyRevision

        vm.promoteSummary(summary)

        #expect(vm.bodyText == "Existing prose.\n\nThe summary text.")
        #expect(vm.bodyRevision > before, """
            The rich-text editor loads its content ONCE by design, so a body written from code is \
            invisible until something tells it to remount. Without this counter the Insert button \
            recorded the summary, changed the model, and left the screen alone — a dead button.
            """)
        #expect(vm.richText == nil, """
            The formatted copy cannot survive a wholesale replacement of the text it formatted; \
            keeping it would show the reader their previous prose back.
            """)
    }

    @Test("Typing does not remount the editor")
    func typingLeavesTheRevisionAlone() {
        let vm = ResearchNoteEditorViewModel(documentId: "d1", volumeId: "frus1969-76v01",
                                             activeProjectId: nil)
        let before = vm.bodyRevision
        vm.bodyText = "typed"
        vm.bodyText = "typed more"
        #expect(vm.bodyRevision == before, """
            Only a programmatic replacement bumps the revision. If typing did, the editor would \
            remount mid-word and take the reader's cursor with it.
            """)
    }

    @Test("Plain typing drops the formatted copy it has just made stale")
    func plainTypingClearsRichText() {
        let vm = ResearchNoteEditorViewModel(documentId: "d1", volumeId: "frus1969-76v01",
                                             activeProjectId: nil)
        vm.bodyText = "Formatted prose."
        vm.richText = Data("{\\rtf1 formatted}".utf8)

        vm.setPlainBody("Rewritten plainly.")

        #expect(vm.bodyText == "Rewritten plainly.")
        #expect(vm.richText == nil, """
            A note edited with formatting OFF kept its old RTF, and `save` stores both. The rich \
            editor prefers a decodable `richText` over its plain fallback, so reopening with \
            formatting ON showed the reader their PREVIOUS prose — and the first keystroke there \
            serialises the whole storage back, overwriting what they actually wrote. This is the \
            line that keeps the two copies from diverging.
            """)
    }

    @Test("A stored order carrying the same id twice does not trap")
    func duplicateIdsInAStoredOrderAreSurvivable() {
        let items = Self.named("Alpha", "Bravo")
        let duplicated = items[1].id
        // Not hypothetical: `DuplicateRecordCleanup` exists because CloudKit can deliver two records
        // with one identity, so an order built from a list holding both would carry the id twice.
        // `Dictionary(uniqueKeysWithValues:)` TRAPS on that — it does not throw — so this crashed
        // the note editor on open rather than failing an assertion.
        let result = ListOrderPreferences.apply(items, order: [duplicated, duplicated], id: \.id)
        #expect(result.map(\.name) == ["Bravo", "Alpha"])
    }

    @Test("Reordering with settings sync off does not arm an adopt that wipes the device's settings")
    func mintingThePreferencesRecordSeedsItFromThisDevice() throws {
        let container = try ModelContainer.makeTestContainer()
        let ctx = container.mainContext

        // A reorder is not the sync opt-in, but it is the first thing that can mint the record —
        // and `SettingsSyncCoordinator` decides between seeding the cloud and ADOPTING from it
        // purely on whether one exists. A record left at type defaults would turn the reader's next
        // "turn sync on" into an adopt of blanks over their own settings.
        ListOrderPreferences.setOrder([UUID()], for: .tags, in: ctx)

        let record = try #require(try ctx.fetch(FetchDescriptor<SyncedPreferences>()).first)
        #expect(record.wcMinLength == WordCloudSettings.minimumLength, """
            The minted record was not seeded from this device, so enabling settings sync later \
            would pull these defaults back over the reader's own word-cloud thresholds.
            """)
        #expect(record.wcMinCount == WordCloudSettings.minimumCount)
        #expect(record.researchLoggingEnabled
                    == AppState.isResearchLoggingEnabled(in: .standard))
    }

    @Test("Reopening a note restores the formatting it was saved with")
    func loadRestoresRichText() throws {
        let container = try ModelContainer.makeTestContainer()
        let ctx = container.mainContext
        let existing = ResearchNote(documentId: "d1", volumeId: "frus1969-76v01", bodyText: "Body.")
        existing.richText = Data("{\\rtf1 saved}".utf8)
        ctx.insert(existing)

        let vm = ResearchNoteEditorViewModel(documentId: "d1", volumeId: "frus1969-76v01",
                                             activeProjectId: nil, noteToEdit: existing)
        // `init` mirrors four fields off the note and NOT this one — `load` is what restores it, and
        // both platform bodies call `load` from `.onAppear`. Nothing else could repopulate it: the
        // editor's representable loads content once and its change callback fires only on a real
        // edit, so a note reopened without this would come back unformatted.
        vm.load(context: ctx)
        #expect(vm.richText == Data("{\\rtf1 saved}".utf8))
    }

    // MARK: - The column the editor used to overwrite

    /// `user_tag_ids` is a per-DOCUMENT column whose authoritative writer is the document tag
    /// picker. The note editor knows one note's tags, so writing them there narrowed a document's
    /// set to one note's — and a note with no tags passed `nil`, which the binder writes as SQL
    /// NULL rather than skipping, erasing the column outright.
    ///
    /// Asserted by reading the source, because the damage is a write that should not happen: no
    /// runtime assertion over the pipeline can distinguish "did not write" from "wrote the same
    /// value", and the call sites are in views a unit test cannot drive.
    @Test("No note-grained caller writes the document's tag column")
    func noteWritersDoNotSpeakForTheDocumentTagColumn() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer")
        // #1280 moved the note-to-index push behind ONE writer, and this guard followed it — which
        // is what the `calls > 0` assertion below exists to force. The editor and the collection
        // editor now call `ResearchNote.reindexNoteText` and reach no pipeline method of their own;
        // `NoteTextWriterScanTests` is what keeps them that way.
        let files = ["Models/ResearchNote.swift",
                     "App/FRUSExplorerApp.swift"]
        for relative in files {
            let source = try String(contentsOf: root.appendingPathComponent(relative),
                                    encoding: .utf8)
            let code = source.split(separator: "\n", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.hasPrefix("//") && !$0.hasPrefix("///") && !$0.hasPrefix("*") }
                .joined(separator: "\n")

            // Scoped to `updateNoteText(` calls, NOT to the argument label on its own. The label is
            // correct — and load-bearing — on `updateUserTagIds`, the document-grained writer that
            // replays `DocumentTagAssignment` at boot; a bare search for it fails on that, which is
            // exactly the "fix it by writing MORE" mistake this test exists to discourage.
            var searched = code[...]
            var calls = 0
            while let call = searched.range(of: "updateNoteText(") {
                let tail = searched[call.upperBound...]
                let arguments = tail.prefix(while: { $0 != ")" })
                calls += 1
                #expect(!arguments.contains("userTagIds"), """
                    \(relative) passes tags into `updateNoteText`, which writes the per-DOCUMENT \
                    `user_tag_ids` column. A note carrying {A} rewrites a document tagged {A,B,C} \
                    down to "A", and a note with none passes nil — which the binder writes as SQL \
                    NULL rather than skipping, erasing the column. Use the text-only overload; it \
                    exists for exactly this caller. Do NOT instead send the document's whole set \
                    from here: that column has one authoritative writer already.
                    """)
                searched = tail
            }
            #expect(calls > 0, """
                \(relative) no longer calls `updateNoteText` at all. If the note-to-index push \
                moved, this guard moved with it — and nothing else asserts the column is left alone.
                """)
        }
    }
}
