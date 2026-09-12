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
import SQLite3
@testable import FRUSExplorer

// MARK: - Fixture

private func makeNoteVolumeXML() -> String {
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <TEI xmlns="http://www.tei-c.org/ns/1.0">
    <teiHeader><fileDesc><titleStmt><title>Test Volume</title></titleStmt>
    <publicationStmt><p>Test</p></publicationStmt>
    <sourceDesc><p>Test</p></sourceDesc></fileDesc></teiHeader>
    <text><body>
    <div type="document" xml:id="d1">
      <head>1. Memorandum of Conversation</head>
      <p>The corpus body of the first document.</p>
    </div>
    <div type="document" xml:id="d2">
      <head>2. Telegram From the Embassy</head>
      <p>The corpus body of the second document.</p>
    </div>
    </body></text></TEI>
    """
}

/// A real index over a real SQLite file, a real `SearchService`, and a real SwiftData store —
/// the four pieces the defect lived between.
private func makeNoteFixture() async throws
    -> (dir: URL, service: SearchService, pipeline: IndexingPipeline, container: ModelContainer) {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("FRUSNoteText-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let dbURL = dir.appendingPathComponent("test.sqlite")
    let volDir = dir.appendingPathComponent("volumes")
    try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
    try makeNoteVolumeXML().data(using: .utf8)!
        .write(to: volDir.appendingPathComponent("vol1.xml"))

    let fts5 = try FTS5Store(databaseURL: dbURL)
    let pipeline = try IndexingPipeline(
        fts5Store: fts5, databaseURL: dbURL, volumesDirectory: volDir, concurrencyLimit: 1)
    try await pipeline.indexVolume("vol1")
    let container = try ModelContainer(
        for: ResearchNote.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    return (dir, SearchService(fts5Store: fts5, pipeline: pipeline), pipeline, container)
}

/// Searches note text ONLY, so nothing can match from the corpus body or a summary.
private func noteSearch(_ service: SearchService, _ keywords: String) async throws -> Set<String> {
    var parameters = SearchParameters(keywords: keywords)
    parameters.includeDocumentText = false
    parameters.includeSummaries = false
    parameters.includeNotes = true
    return Set(try await service.search(parameters: parameters, limit: 100).map(\.documentId))
}

/// Makes a note with a pinned `createdAt`, since the ordering rule reads it.
@MainActor
private func makeNote(_ body: String, on documentId: String, in context: ModelContext,
                      createdAt: Date) -> ResearchNote {
    let note = ResearchNote(documentId: documentId, volumeId: "vol1", bodyText: body)
    note.createdAt = createdAt
    context.insert(note)
    return note
}

// MARK: - NoteTextPerDocumentTests

/// `document_cache.note_text` holds ONE text per document, while a document may carry many notes
/// (#1280).
///
/// Four writers each pushed a single note's body into it, so all but one of a document's notes were
/// unsearchable — and the boot replay looped over an unsorted fetch, so which one survived changed
/// between launches. Nothing cleared the column at all, so a deleted note stayed searchable for the
/// life of the install.
///
/// **The behavioural half drives the shipped writer over a real index and asks a real query.** The
/// whole defect was that the column's contents did not match the reader's notes, and a test that
/// mirrored the join would have agreed with itself while search stayed wrong.
///
/// Version history:
///   1.0 — #1280: initial implementation
@Suite("note_text is one text per document")
struct NoteTextPerDocumentTests {

    // MARK: - The join

    @MainActor
    @Test("Every note on a document reaches the indexed text, oldest first")
    func allNotesOnADocumentAreJoined() throws {
        let base = Date(timeIntervalSince1970: 1_000_000)
        let first = ResearchNote(documentId: "d1", volumeId: "vol1", bodyText: "Bonn conversation.")
        first.createdAt = base
        let second = ResearchNote(documentId: "d1", volumeId: "vol1", bodyText: "Follow up in March.")
        second.createdAt = base.addingTimeInterval(60)

        // Handed over newest-first, because the boot replay's fetch has no order and the bug was
        // that whichever note came last won.
        let rows = ResearchNote.indexedTextPerDocument([second, first])
        #expect(rows.count == 1)
        let row = try #require(rows.first)
        #expect(row.text == "Bonn conversation.\n\nFollow up in March.")
        #expect(row.volumeId == "vol1")
        #expect(row.documentId == "d1")
    }

    @MainActor
    @Test("Two documents keep their own texts")
    func documentsAreKeyedSeparately() {
        let a = ResearchNote(documentId: "d1", volumeId: "vol1", bodyText: "About d1.")
        let b = ResearchNote(documentId: "d2", volumeId: "vol1", bodyText: "About d2.")
        let rows = ResearchNote.indexedTextPerDocument([a, b])
        #expect(rows.count == 2)
        #expect(rows.first(where: { $0.documentId == "d1" })?.text == "About d1.")
        #expect(rows.first(where: { $0.documentId == "d2" })?.text == "About d2.")
    }

    @MainActor
    @Test("A document with the same id in two volumes is two documents")
    func volumeIsPartOfTheKey() {
        let a = ResearchNote(documentId: "d1", volumeId: "vol1", bodyText: "In vol1.")
        let b = ResearchNote(documentId: "d1", volumeId: "vol2", bodyText: "In vol2.")
        let rows = ResearchNote.indexedTextPerDocument([a, b])
        // `d1` is a volume-relative id — every FRUS volume has one — so keying on it alone would
        // join two unrelated documents' notes and write the pair into both rows.
        #expect(rows.count == 2)
        #expect(rows.first(where: { $0.volumeId == "vol1" })?.text == "In vol1.")
        #expect(rows.first(where: { $0.volumeId == "vol2" })?.text == "In vol2.")
    }

    @MainActor
    @Test("A document whose notes are all empty yields no row, rather than a row of separators")
    func emptyNotesYieldNothing() {
        let blank = ResearchNote(documentId: "d1", volumeId: "vol1", bodyText: "   ")
        let alsoBlank = ResearchNote(documentId: "d1", volumeId: "vol1", bodyText: "")
        #expect(ResearchNote.indexedTextPerDocument([blank, alsoBlank]).isEmpty, """
            An empty note must not contribute a separator. A row holding only "\\n\\n" is not \
            nothing: it would keep the column non-empty, so the reconciliation pass would read the \
            document as still carrying indexed text and never clear it.
            """)
    }

    @MainActor
    @Test("An empty note between two written ones does not double the separator")
    func emptyNotesDoNotPadTheJoin() throws {
        let base = Date(timeIntervalSince1970: 3_000_000)
        let first = ResearchNote(documentId: "d1", volumeId: "vol1", bodyText: "Written.")
        first.createdAt = base
        let blank = ResearchNote(documentId: "d1", volumeId: "vol1", bodyText: "  \n ")
        blank.createdAt = base.addingTimeInterval(1)
        let last = ResearchNote(documentId: "d1", volumeId: "vol1", bodyText: "Also written.")
        last.createdAt = base.addingTimeInterval(2)

        let row = try #require(ResearchNote.indexedTextPerDocument([first, blank, last]).first)
        #expect(row.text == "Written.\n\nAlso written.")
    }

    @MainActor
    @Test("The replay writes the same text whichever order the fetch hands the notes over")
    func theReplayIsOrderIndependent() {
        // The defect was only ever visible ACROSS LAUNCHES, which is why nobody noticed it: the
        // boot replay fetches every note with no `sortBy:` and used to write them one over another,
        // so which of a document's notes search could see was decided by whatever order SwiftData
        // happened to return that morning.
        let base = Date(timeIntervalSince1970: 5_000_000)
        let bodies = ["First.", "Second.", "Third."]
        let notes = bodies.enumerated().map { offset, body -> ResearchNote in
            let note = ResearchNote(documentId: "d1", volumeId: "vol1", bodyText: body)
            note.createdAt = base.addingTimeInterval(Double(offset) * 60)
            return note
        }
        let expected = "First.\n\nSecond.\n\nThird."
        // Every rotation and the reversal — six orders over three notes, one assertion each.
        for order in [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]] {
            let shuffled = order.map { notes[$0] }
            #expect(ResearchNote.indexedTextPerDocument(shuffled).first?.text == expected,
                    "fetch order \(order) produced a different indexed text")
        }
    }

    @MainActor
    @Test("Notes with the same timestamp order reproducibly")
    func tiesBreakOnIdentity() {
        let when = Date(timeIntervalSince1970: 2_000_000)
        let a = ResearchNote(documentId: "d1", volumeId: "vol1", bodyText: "A.")
        let b = ResearchNote(documentId: "d1", volumeId: "vol1", bodyText: "B.")
        a.createdAt = when
        b.createdAt = when
        // Two devices replaying the same notes must write byte-identical text, or each device's
        // replay rewrites the other's row and churns the FTS5 index on every launch.
        let once = ResearchNote.indexedTextPerDocument([a, b]).first?.text
        let again = ResearchNote.indexedTextPerDocument([b, a]).first?.text
        #expect(once == again)
        let expected = a.id.uuidString < b.id.uuidString ? "A.\n\nB." : "B.\n\nA."
        #expect(once == expected)
    }

    @MainActor
    @Test("A note with no document is skipped rather than keyed on an empty pair")
    func blankKeysAreSkipped() {
        let orphan = ResearchNote(documentId: "", volumeId: "", bodyText: "Nowhere.")
        let halfKeyed = ResearchNote(documentId: "d1", volumeId: "", bodyText: "Half.")
        #expect(ResearchNote.indexedTextPerDocument([orphan, halfKeyed]).isEmpty)
    }

    @MainActor
    @Test("A note with no createdAt sorts first rather than crashing the comparison")
    func missingTimestampsAreOrdered() throws {
        // `createdAt` is optional on the model — CloudKit delivers a record whose fields are all
        // nullable — so the rule has to order one, and the sort must stay a strict weak ordering.
        let dated = ResearchNote(documentId: "d1", volumeId: "vol1", bodyText: "Dated.")
        dated.createdAt = Date(timeIntervalSince1970: 4_000_000)
        let undated = ResearchNote(documentId: "d1", volumeId: "vol1", bodyText: "Undated.")
        undated.createdAt = nil

        let row = try #require(ResearchNote.indexedTextPerDocument([dated, undated]).first)
        #expect(row.text == "Undated.\n\nDated.")
    }

    // MARK: - The behaviour, through the shipped writer and a real query

    @MainActor
    @Test("Both of a document's notes are findable, not just one")
    func bothNotesAreSearchable() async throws {
        let (dir, service, pipeline, container) = try await makeNoteFixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let context = container.mainContext
        let base = Date(timeIntervalSince1970: 1_000_000)
        _ = makeNote("Kissinger backchannel.", on: "d1", in: context, createdAt: base)
        _ = makeNote("Verify the dateline.", on: "d1", in: context,
                     createdAt: base.addingTimeInterval(60))
        try context.save()

        await ResearchNote.reindexNoteText(volumeId: "vol1", documentId: "d1",
                                           in: context, pipeline: pipeline)

        #expect(try await noteSearch(service, "backchannel") == ["d1"])
        #expect(try await noteSearch(service, "dateline") == ["d1"], """
            The second note's words are not findable. Before #1280 each writer pushed ONE note's \
            body into a per-document column, so whichever note it happened to hold was the only \
            one search could see.
            """)
    }

    @MainActor
    @Test("Which note the writer is told about does not decide which one is findable")
    func theWriterReadsTheDocumentRatherThanTheNote() async throws {
        let (dir, service, pipeline, container) = try await makeNoteFixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let context = container.mainContext
        let base = Date(timeIntervalSince1970: 1_000_000)
        _ = makeNote("Kissinger backchannel.", on: "d1", in: context, createdAt: base)
        try context.save()
        await ResearchNote.reindexNoteText(volumeId: "vol1", documentId: "d1",
                                           in: context, pipeline: pipeline)

        // A second note is written in the editor. The old writer pushed the note in front of the
        // reader, which silently unindexed the first one — the exact report in #1280.
        _ = makeNote("Verify the dateline.", on: "d1", in: context,
                     createdAt: base.addingTimeInterval(60))
        try context.save()
        await ResearchNote.reindexNoteText(volumeId: "vol1", documentId: "d1",
                                           in: context, pipeline: pipeline)

        #expect(try await noteSearch(service, "backchannel") == ["d1"], """
            Writing a SECOND note took the FIRST one out of the index.
            """)
        #expect(try await noteSearch(service, "dateline") == ["d1"])
    }

    @MainActor
    @Test("Deleting one note leaves the other findable, and takes the deleted words out")
    func deletingOneNoteRewritesTheRest() async throws {
        let (dir, service, pipeline, container) = try await makeNoteFixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let context = container.mainContext
        let base = Date(timeIntervalSince1970: 1_000_000)
        let doomed = makeNote("Kissinger backchannel.", on: "d1", in: context, createdAt: base)
        _ = makeNote("Verify the dateline.", on: "d1", in: context,
                     createdAt: base.addingTimeInterval(60))
        try context.save()
        await ResearchNote.reindexNoteText(volumeId: "vol1", documentId: "d1",
                                           in: context, pipeline: pipeline)

        context.delete(doomed)
        try context.save()
        await ResearchNote.reindexNoteText(volumeId: "vol1", documentId: "d1",
                                           in: context, pipeline: pipeline)

        #expect(try await noteSearch(service, "dateline") == ["d1"], """
            Deleting one note took the OTHER one out of the index.
            """)
        #expect(try await noteSearch(service, "backchannel").isEmpty, """
            A deleted note's words are still searchable. The column is per document, so a deletion \
            has to rewrite it from what is left.
            """)
    }

    @MainActor
    @Test("Deleting the last note clears the column instead of freezing its text")
    func deletingTheLastNoteClearsTheColumn() async throws {
        let (dir, service, pipeline, container) = try await makeNoteFixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let context = container.mainContext
        let only = makeNote("Kissinger backchannel.", on: "d1", in: context,
                            createdAt: Date(timeIntervalSince1970: 1_000_000))
        try context.save()
        await ResearchNote.reindexNoteText(volumeId: "vol1", documentId: "d1",
                                           in: context, pipeline: pipeline)
        #expect(try await noteSearch(service, "backchannel") == ["d1"])

        context.delete(only)
        try context.save()
        await ResearchNote.reindexNoteText(volumeId: "vol1", documentId: "d1",
                                           in: context, pipeline: pipeline)

        #expect(try await noteSearch(service, "backchannel").isEmpty, """
            Nothing cleared this column before #1280, and a writer that only pushes the notes that \
            EXIST can never empty it — so a deleted note's words stayed searchable for the life of \
            the install.
            """)
    }

    @MainActor
    @Test("Rewriting one document's notes leaves another document's alone")
    func siblingDocumentsAreUntouched() async throws {
        let (dir, service, pipeline, container) = try await makeNoteFixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let context = container.mainContext
        let when = Date(timeIntervalSince1970: 1_000_000)
        let doomed = makeNote("Kissinger backchannel.", on: "d1", in: context, createdAt: when)
        _ = makeNote("Bonn conversation.", on: "d2", in: context, createdAt: when)
        try context.save()
        for document in ["d1", "d2"] {
            await ResearchNote.reindexNoteText(volumeId: "vol1", documentId: document,
                                               in: context, pipeline: pipeline)
        }
        #expect(try await noteSearch(service, "bonn") == ["d2"])

        context.delete(doomed)
        try context.save()
        await ResearchNote.reindexNoteText(volumeId: "vol1", documentId: "d1",
                                           in: context, pipeline: pipeline)

        #expect(try await noteSearch(service, "backchannel").isEmpty)
        #expect(try await noteSearch(service, "bonn") == ["d2"], """
            The clear reached a document it was not asked about.
            """)
    }

    @MainActor
    @Test("Notes that could not be read mean SKIP, and no notes at all mean CLEAR")
    func unreadableNotesAreNotAnEmptySet() {
        // The two are one `?? []` apart at every call site, and the app already logs a fetch it
        // could not perform as an empty result in a dozen places. Here the difference is
        // destructive: reading a failure as "this document has no notes" erases the notes it
        // really has from the index, and they stay gone until the next launch's replay.
        #expect(ResearchNote.noteTextWrite(for: nil) == .skip)
        #expect(ResearchNote.noteTextWrite(for: []) == .clear, """
            A document really holding no notes must CLEAR — nothing else ever empties this column.
            """)

        let note = ResearchNote(documentId: "d1", volumeId: "vol1", bodyText: "Kept.")
        #expect(ResearchNote.noteTextWrite(for: [note]) == .write("Kept."))

        let blank = ResearchNote(documentId: "d1", volumeId: "vol1", bodyText: "   ")
        #expect(ResearchNote.noteTextWrite(for: [blank]) == .clear, """
            A document whose only note the reader emptied has nothing to index, so the column has \
            to go back to empty rather than keep what it last held.
            """)
    }

    // MARK: - Reconciliation

    @MainActor
    @Test("The replay sweeps the rows a deletion left behind, and only those")
    func theReplaySweepsWhatNoNoteAccountsFor() async throws {
        let (dir, service, pipeline, container) = try await makeNoteFixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let context = container.mainContext
        let when = Date(timeIntervalSince1970: 1_000_000)
        _ = makeNote("Kept text.", on: "d1", in: context, createdAt: when)
        let orphaned = makeNote("Orphaned text.", on: "d2", in: context, createdAt: when)
        try context.save()
        for document in ["d1", "d2"] {
            await ResearchNote.reindexNoteText(volumeId: "vol1", documentId: document,
                                               in: context, pipeline: pipeline)
        }
        #expect(try await noteSearch(service, "orphaned") == ["d2"])

        // The shape the reconciliation exists for: the note is gone and NOTHING told the index —
        // a deletion on another device, or one made before #1280 shipped at all.
        context.delete(orphaned)
        try context.save()
        await ResearchNote.reconcileNoteText(container: container, pipeline: pipeline,
                                             sweepingStaleRows: true)

        #expect(try await noteSearch(service, "orphaned").isEmpty, """
            A note no live record accounts for is still searchable. Nothing but this sweep would \
            ever remove it: the write half visits only documents that still HAVE a note.
            """)
        #expect(try await noteSearch(service, "kept") == ["d1"], "the sweep took a live note with it")
        #expect(try pipeline.documentsWithNoteText().map(\.documentId) == ["d1"])
    }

    @MainActor
    @Test("A store that has not loaded is not a reader with no notes — the sweep refuses it")
    func anEmptyStoreDoesNotEmptyTheIndex() async throws {
        let (dir, service, pipeline, container) = try await makeNoteFixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let context = container.mainContext
        let note = makeNote("Kissinger backchannel.", on: "d1", in: context,
                            createdAt: Date(timeIntervalSince1970: 1_000_000))
        try context.save()
        await ResearchNote.reindexNoteText(volumeId: "vol1", documentId: "d1",
                                           in: context, pipeline: pipeline)

        // `PendingStoreReset` — Settings ▸ Data & Recovery ▸ Fix iCloud Sync — deletes
        // `default.store` and lets CloudKit refill it. `frus.db` is a different file and survives,
        // so at the next launch the fetch SUCCEEDS and returns nothing while the index still holds
        // every note row. A `?? []` here, or a plan that trusted an empty result, would empty the
        // reader's whole indexed annotation layer at the exact moment their notes are safe in
        // CloudKit and have simply not arrived.
        context.delete(note)
        try context.save()
        await ResearchNote.reconcileNoteText(container: container, pipeline: pipeline,
                                             sweepingStaleRows: true)

        #expect(try await noteSearch(service, "backchannel") == ["d1"], """
            The sweep emptied the index on an empty note set. That reading is available to it only \
            when the store cannot be trusted; a reader who really deleted their last note in the \
            app has already had it cleared by `reindexNoteText`.
            """)
    }

    @MainActor
    @Test("The write half runs without the sweep, and only the sweep clears")
    func theSweepIsSeparableFromTheWrite() async throws {
        let (dir, service, pipeline, container) = try await makeNoteFixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let context = container.mainContext
        let when = Date(timeIntervalSince1970: 1_000_000)
        _ = makeNote("Kept text.", on: "d1", in: context, createdAt: when)
        let orphaned = makeNote("Orphaned text.", on: "d2", in: context, createdAt: when)
        try context.save()
        await ResearchNote.reconcileNoteText(container: container, pipeline: pipeline,
                                             sweepingStaleRows: true)
        context.delete(orphaned)
        try context.save()

        // What boot does while CloudKit is on: replay every note, sweep nothing. The floor cannot
        // tell a half-imported store from a finished one, so the destructive half waits for the
        // import-settle debounce — and the write half, which is idempotent, does not.
        await ResearchNote.reconcileNoteText(container: container, pipeline: pipeline,
                                             sweepingStaleRows: false)
        #expect(try await noteSearch(service, "kept") == ["d1"], "the write half did not run")
        #expect(try await noteSearch(service, "orphaned") == ["d2"], """
            `sweepingStaleRows: false` cleared a row. That is the boot path on every launch with \
            iCloud on, where the store may still be filling.
            """)

        // And what the import-settle debounce does once the store has stopped moving.
        await ResearchNote.reconcileNoteText(container: container, pipeline: pipeline,
                                             sweepingStaleRows: true)
        #expect(try await noteSearch(service, "orphaned").isEmpty)
        #expect(try await noteSearch(service, "kept") == ["d1"])
    }

    @MainActor
    @Test("Notes that could not be read plan nothing at all")
    func anUnreadableLibraryPlansNothing() {
        let carrying = [(volumeId: "vol1", documentId: "d1"), (volumeId: "vol1", documentId: "d2")]
        let plan = ResearchNote.noteTextPlan(for: nil, carrying: carrying)
        #expect(plan.writes.isEmpty)
        #expect(plan.clears.isEmpty)
    }

    @MainActor
    @Test("A reader whose notes are all EMPTY still clears — the floor counts records, not text")
    func aLibraryOfEmptyNotesStillClears() {
        // The distinguishing case, and the reason the floor is written on `notes.isEmpty` rather
        // than on the joined text being empty. Those two read identically on every input except
        // this one: a store that plainly loaded — it has records — belonging to a reader who
        // emptied every note body. Their column should go back to empty, and a floor written on
        // the text would have refused, leaving the old words searchable forever.
        let blank = ResearchNote(documentId: "d1", volumeId: "vol1", bodyText: "   ")
        let carrying = [(volumeId: "vol1", documentId: "d1")]
        let plan = ResearchNote.noteTextPlan(for: [blank], carrying: carrying)
        #expect(plan.writes.isEmpty)
        #expect(plan.clears.map(\.documentId) == ["d1"])
    }

    @MainActor
    @Test("A fresh index carrying nothing is not swept")
    func aFreshIndexIsNotSwept() {
        let note = ResearchNote(documentId: "d1", volumeId: "vol1", bodyText: "First note.")
        let plan = ResearchNote.noteTextPlan(for: [note], carrying: [])
        #expect(plan.writes.count == 1)
        #expect(plan.clears.isEmpty)
    }

    @MainActor
    @Test("A legacy empty-string row is normalised to NULL by one sweep, and then stays out")
    func legacyEmptyStringRowsAreNormalised() async throws {
        let (dir, _, pipeline, container) = try await makeNoteFixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let context = container.mainContext
        _ = makeNote("Kept.", on: "d1", in: context, createdAt: Date(timeIntervalSince1970: 1))
        try context.save()
        await ResearchNote.reindexNoteText(volumeId: "vol1", documentId: "d1",
                                           in: context, pipeline: pipeline)
        // What a pre-#1280 writer left when the reader emptied a note's body: not NULL, indexing
        // nothing, and counted by `COUNT(note_text)` as an annotated document.
        try await pipeline.updateNoteText(volumeId: "vol1", documentId: "d2", bodyText: "")
        #expect(try pipeline.documentsWithNoteText().map(\.documentId) == ["d1", "d2"], """
            An empty-string row must be REPORTED, not filtered out — reporting it is what lets one \
            sweep normalise it to NULL. Filtering it here would freeze it for the life of the \
            install, and the guide's `COUNT(note_text)` sentence with it.
            """)

        await ResearchNote.reconcileNoteText(container: container, pipeline: pipeline,
                                             sweepingStaleRows: true)

        #expect(try pipeline.documentsWithNoteText().map(\.documentId) == ["d1"])
        // And it stays out: the row is NULL now, so the next sweep has nothing to do. Without this,
        // a row cleared on every launch forever would be a plausible reading of the first assert.
        await ResearchNote.reconcileNoteText(container: container, pipeline: pipeline,
                                             sweepingStaleRows: true)
        #expect(try pipeline.documentsWithNoteText().map(\.documentId) == ["d1"])
    }

    @MainActor
    @Test("A document that never had a note is not in the reconciliation set")
    func documentsWithoutNotesAreAbsent() async throws {
        let (dir, _, pipeline, _) = try await makeNoteFixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        // Both documents are indexed; neither has note text. A set that returned every indexed
        // document would make the boot sweep clear the whole column on every launch.
        #expect(try pipeline.documentsWithNoteText().isEmpty)
    }
}

// MARK: - NoteTextWriterScanTests

/// `note_text` has ONE writer, and this is what keeps it that way (#1280).
///
/// The column had four, each a copy of "fetch the document's notes, join, write or clear", and one
/// of them had already drifted to a different answer — the collection editor's inline note creator
/// fell back to the note being written and never cleared at all. The lesson is the Source Explorer
/// twins': a rule written out four times is four places for it to diverge, and the divergence is
/// invisible because each copy reads correctly on its own.
///
/// Scoped to the CALL: comment lines are stripped before the search, as the sibling guard in
/// `NotesEnhancementsTests` strips them, so a doc line naming the method neither satisfies this
/// test nor trips it. The needles carry a leading dot so the declarations in `IndexingPipeline`
/// — `func updateNoteText(`, with no receiver — are not calls either.
///
/// Version history:
///   1.0 — #1280: initial implementation
@Suite("note_text has one writer")
struct NoteTextWriterScanTests {

    /// The files allowed to reach the two column methods directly.
    ///
    /// `ResearchNote` is the writer. `FRUSExplorerApp` is the boot and post-download REPLAY, which
    /// is batch-grained on purpose — it walks every note once and then reconciles the rows no note
    /// accounts for, which a per-document call cannot express.
    private static let permitted: Set<String> = [
        "FRUSExplorer/Models/ResearchNote.swift",
        "FRUSExplorer/Search/IndexingPipeline.swift",
        "FRUSExplorer/App/FRUSExplorerApp.swift",
    ]

    @Test("The app's replays reach the column through the shared reconcile, never their own sweep")
    func theReplaysDoNotOpenCodeTheSubtraction() throws {
        // **This is the test for the failure that actually happened.** The boot replay's conversion
        // to `reconcileNoteText` was written and never reached disk — the old open-coded subtraction
        // was still there, still compiling, with none of the refusals the tests and the doc comments
        // described. Every test stayed green, because they all drive the extracted function. Nothing
        // in the suite asserted that the APP calls it.
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let app = try String(
            contentsOf: root.appendingPathComponent("FRUSExplorer/App/FRUSExplorerApp.swift"),
            encoding: .utf8)
        let code = app.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") && !$0.hasPrefix("*") }
            .joined(separator: "\n")

        #expect(!code.contains(".clearNoteText("), """
            A replay clears the column itself. The clear half carries a floor and an ordering rule \
            that only `ResearchNote.reconcileNoteText` applies; a loop here has neither.
            """)
        #expect(!code.contains("documentsWithNoteText("), """
            A replay reads the carried-rows set itself, which is the first half of open-coding the \
            subtraction — the shape whose second half is a `clearNoteText` loop.
            """)

        // Two calls, and each one's `sweepingStaleRows:` is the whole argument of this design: the
        // boot pass may sweep only with CloudKit off, and the import-settle pass is where a synced
        // reader's sweep belongs.
        #expect(code.contains("sweepingStaleRows: !cloudKitOn"), """
            The boot replay no longer gates its sweep on CloudKit being off. With iCloud on it would \
            sweep against a store that may still be filling, and one arrived note disarms the floor.
            """)
        #expect(code.contains("sweepingStaleRows: true"), """
            Nothing sweeps on the import-settle debounce, so a note deleted on another device stays \
            searchable until the next cold launch — and for a reader with iCloud on, the boot pass \
            does not sweep at all, so nothing ever reconciles.
            """)
    }

    @Test("No view writes the note column itself")
    func onlyTheSharedWriterTouchesTheColumn() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let appDir = root.appendingPathComponent("FRUSExplorer")
        let files = FileManager.default.enumerator(at: appDir, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" } ?? []
        #expect(files.count > 100, "the scan found almost no source — it is looking in the wrong place")

        var offenders: [String] = []
        // PER NEEDLE, not one shared counter: a single total is satisfied by either needle alone,
        // so a stale `.clearNoteText(` would pass on the strength of `.updateNoteText(` matching.
        var callSites: [String: Int] = [:]
        for file in files {
            guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
            let relative = file.path.replacingOccurrences(of: root.path + "/", with: "")
            // Comments stripped first: this suite's whole claim is that it matches a CALL, and the
            // files it watches discuss these methods at length in prose.
            let code = text.split(separator: "\n", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.hasPrefix("//") && !$0.hasPrefix("*") }
                .joined(separator: "\n")
            for needle in [".updateNoteText(", ".clearNoteText("] where code.contains(needle) {
                callSites[needle, default: 0] += 1
                if !Self.permitted.contains(relative) { offenders.append("\(relative) — \(needle)") }
            }
        }
        // Counted, because a needle that stopped matching anything would pass this test silently.
        for needle in [".updateNoteText(", ".clearNoteText("] {
            #expect((callSites[needle] ?? 0) > 0, "the scan matched no `\(needle)` call — stale needle")
        }
        #expect(offenders.isEmpty, """
            These write `note_text` without going through `ResearchNote.reindexNoteText`, which is \
            how the column came to hold one note's body on a document carrying several: \
            \(offenders.joined(separator: "; "))
            """)
    }
}
