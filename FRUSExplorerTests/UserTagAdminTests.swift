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
import SwiftData
import Testing
@testable import FRUSExplorer

// MARK: - UserTagAdminTests

/// The bulk tag writer and its Undo, against a real store (#1576 lane 5).
///
/// The rule under test is that Add Tags **adds**. The tag picker's own writer, opened on one
/// document, replaces that document's tag set; run over a selection it would take every other tag
/// off every document in it. Each test here drives `UserTagAdmin.assign` or
/// `UserTagAdmin.removeAssignments` itself and reads the rows back from the store.
///
/// Version history:
///   1.0 — #1576 lane 5: initial implementation
@Suite("Bulk tag assignment (#1576 lane 5)")
@MainActor
struct UserTagAdminTests {

    private static let tagA = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!
    private static let tagB = UUID(uuidString: "BBBBBBBB-0000-0000-0000-000000000002")!
    private static let tagC = UUID(uuidString: "CCCCCCCC-0000-0000-0000-000000000003")!

    private struct Refused: Error {}

    private func doc(_ documentId: String) -> CollectionDocumentRef {
        CollectionDocumentRef(volumeId: "vol1", documentId: documentId)
    }

    /// A store, with the container returned so that it outlives the context.
    private func makeStore() throws -> (container: ModelContainer, context: ModelContext) {
        let container = try ModelContainer.makeTestContainer()
        return (container, ModelContext(container))
    }

    private func give(_ tagId: UUID, to documentId: String, in context: ModelContext) -> UUID {
        let row = DocumentTagAssignment(volumeId: "vol1", documentId: documentId, tagId: tagId)
        context.insert(row)
        return row.id
    }

    /// Every row in the store, as "document=tag", sorted: duplicates show as repeats.
    private func rows(in context: ModelContext) throws -> [String] {
        try context.fetch(FetchDescriptor<DocumentTagAssignment>())
            .map { "\($0.documentId)=\($0.tagId.uuidString.prefix(1))" }
            .sorted()
    }

    // MARK: assign

    @Test("A document tagged A and B gains C and keeps A and B")
    func addingKeepsWhatIsThere() throws {
        let (container, context) = try makeStore()
        _ = container
        _ = give(Self.tagA, to: "d1", in: context)
        _ = give(Self.tagB, to: "d1", in: context)
        try context.save()

        let outcome = try UserTagAdmin.assign(tagIds: [Self.tagC], to: [doc("d1"), doc("d2")], context: context)

        #expect(try rows(in: context) == ["d1=A", "d1=B", "d1=C", "d2=C"])
        #expect(outcome.insertedAssignmentIds.count == 2)
        #expect(outcome.taggedDocuments == [doc("d1"), doc("d2")])
        #expect(outcome.alreadyTagged == 0)
        #expect(outcome.tagIdsByDocument == [doc("d1").key: [Self.tagA, Self.tagB, Self.tagC],
                                             doc("d2").key: [Self.tagC]])
        // Saved here, not left to an autosave: a second context on the store sees the rows.
        #expect(try rows(in: ModelContext(container)) == ["d1=A", "d1=B", "d1=C", "d2=C"])
    }

    @Test("A second run inserts nothing, and does not save")
    func aSecondRunInsertsNothing() throws {
        let (container, context) = try makeStore()
        _ = container
        try UserTagAdmin.assign(tagIds: [Self.tagA, Self.tagB], to: [doc("d1"), doc("d2")], context: context)
        var saves = 0

        let again = try UserTagAdmin.assign(tagIds: [Self.tagA, Self.tagB], to: [doc("d1"), doc("d2")],
                                            context: context, save: { _ in saves += 1 })

        #expect(again.insertedAssignmentIds.isEmpty)
        #expect(again.taggedDocuments.isEmpty)
        #expect(again.alreadyTagged == 2)
        #expect(saves == 0, "with nothing to insert, nothing is saved")
        #expect(try rows(in: context) == ["d1=A", "d1=B", "d2=A", "d2=B"])
        #expect(again.tagIdsByDocument[doc("d1").key] == [Self.tagA, Self.tagB],
                "the rows are still told what the documents carry")
    }

    /// Two devices that tagged the same document before they synced leave two rows for one pair.
    @Test("A pair the store already holds twice counts as present, and a missing tag is still added")
    func aDuplicateCountsAsPresent() throws {
        let (container, context) = try makeStore()
        _ = container
        _ = give(Self.tagA, to: "d1", in: context)
        _ = give(Self.tagA, to: "d1", in: context)
        try context.save()

        let outcome = try UserTagAdmin.assign(tagIds: [Self.tagA, Self.tagB], to: [doc("d1")], context: context)

        #expect(try rows(in: context) == ["d1=A", "d1=A", "d1=B"], "no third row for A")
        #expect(outcome.insertedAssignmentIds.count == 1)
        #expect(outcome.taggedDocuments == [doc("d1")], "it gained B")
        #expect(outcome.alreadyTagged == 0)
    }

    /// A result row's tags are a snapshot from when its search ran. The answer is read from the
    /// store, so a tag the document was given since is in it.
    @Test("The answer carries each document's tags as the store has them, a tag given since the search included")
    func theAnswerIsTheStores() throws {
        let (container, context) = try makeStore()
        _ = container
        // Given after the search ran, on this device or another: no row on screen shows it.
        _ = give(Self.tagB, to: "d1", in: context)
        try context.save()

        let outcome = try UserTagAdmin.assign(tagIds: [Self.tagA], to: [doc("d1")], context: context)

        #expect(outcome.tagIdsByDocument == [doc("d1").key: [Self.tagA, Self.tagB]])
    }

    @Test("A document named twice is one document, and a tag named twice is given once")
    func repeatsAreTakenOnce() throws {
        let (container, context) = try makeStore()
        _ = container
        let outcome = try UserTagAdmin.assign(tagIds: [Self.tagA, Self.tagA],
                                              to: [doc("d1"), doc("d2"), doc("d1")], context: context)
        #expect(try rows(in: context) == ["d1=A", "d2=A"])
        #expect(outcome.taggedDocuments == [doc("d1"), doc("d2")], "in the order given, each once")
        #expect(outcome.insertedAssignmentIds.count == 2)
    }

    @Test("Some documents carry the tag already: they are counted, and the rest are tagged")
    func someAlreadyTagged() throws {
        let (container, context) = try makeStore()
        _ = container
        _ = give(Self.tagA, to: "d2", in: context)
        try context.save()
        let outcome = try UserTagAdmin.assign(tagIds: [Self.tagA], to: [doc("d1"), doc("d2"), doc("d3")],
                                              context: context)
        #expect(outcome.taggedDocuments == [doc("d1"), doc("d3")])
        #expect(outcome.alreadyTagged == 1)
        #expect(try rows(in: context) == ["d1=A", "d2=A", "d3=A"])
    }

    @Test("A list over the limit is refused before anything is read or written")
    func overTheLimit() throws {
        let (container, context) = try makeStore()
        _ = container
        let limit = CollectionDocumentDiscovery.bulkDocumentLimit
        #expect(limit == 1_000, "fixture: the owner's decision 5")
        var reads = 0
        let atLimit = (0..<limit).map { doc("d\($0)") }
        #expect(throws: UserTagAssignRefusal.overLimit(count: limit + 1, limit: limit)) {
            try UserTagAdmin.assign(tagIds: [Self.tagA], to: atLimit + [doc("extra")], context: context,
                                    fetch: { _ in reads += 1; return [] })
        }
        #expect(reads == 0)
        #expect(try rows(in: context).isEmpty)

        // A thousand is taken, the same document named a second time included.
        let outcome = try UserTagAdmin.assign(tagIds: [Self.tagA], to: atLimit + [doc("d0")], context: context)
        #expect(outcome.taggedDocuments.count == limit)
    }

    /// The trap the command is written around: read as "no tags yet", a failed fetch would have
    /// every pair inserted a second time.
    @Test("A fetch that fails stops the command and inserts nothing")
    func aFailedFetchStopsTheCommand() throws {
        let (container, context) = try makeStore()
        _ = container
        _ = give(Self.tagA, to: "d1", in: context)
        try context.save()
        var saves = 0
        #expect(throws: Refused.self) {
            try UserTagAdmin.assign(tagIds: [Self.tagA], to: [doc("d1")], context: context,
                                    fetch: { _ in throw Refused() }, save: { _ in saves += 1 })
        }
        #expect(saves == 0)
        #expect(try rows(in: context) == ["d1=A"], "no second row for a pair the store could not be asked about")
    }

    @Test("A save that fails inserts nothing, and the next try inserts once")
    func aFailedSaveInsertsNothing() throws {
        let (container, context) = try makeStore()
        _ = container
        #expect(throws: Refused.self) {
            try UserTagAdmin.assign(tagIds: [Self.tagA], to: [doc("d1"), doc("d2")], context: context,
                                    save: { _ in throw Refused() })
        }
        #expect(try rows(in: context).isEmpty, "the rows are taken back out of the context")

        try UserTagAdmin.assign(tagIds: [Self.tagA], to: [doc("d1"), doc("d2")], context: context)
        #expect(try rows(in: context) == ["d1=A", "d2=A"])
    }

    /// The writer reads the store through the context, which leaves out a row that has been
    /// deleted and not yet saved. Such a pair is not there, and is given again.
    @Test("A row deleted and not yet saved is not counted as present")
    func aRowDeletedAndUnsavedIsNotPresent() throws {
        let (container, context) = try makeStore()
        _ = container
        _ = give(Self.tagA, to: "d1", in: context)
        try context.save()
        let row = try #require(try context.fetch(FetchDescriptor<DocumentTagAssignment>()).first)
        context.delete(row)   // not saved

        let outcome = try UserTagAdmin.assign(tagIds: [Self.tagA], to: [doc("d1")], context: context)

        #expect(outcome.insertedAssignmentIds.count == 1, "the deleted row does not stand for the pair")
        #expect(outcome.taggedDocuments == [doc("d1")])
        #expect(try rows(in: ModelContext(container)) == ["d1=A"], "one row, after the save: the old one went with it")
    }

    @Test("With no tag asked for, nothing is written")
    func noTagAskedFor() throws {
        let (container, context) = try makeStore()
        _ = container
        var saves = 0
        let outcome = try UserTagAdmin.assign(tagIds: [], to: [doc("d1")], context: context,
                                              save: { _ in saves += 1 })
        #expect(outcome.insertedAssignmentIds.isEmpty && outcome.taggedDocuments.isEmpty)
        #expect(saves == 0)
        #expect(try rows(in: context).isEmpty)
    }

    // MARK: removeAssignments

    @Test("Undo removes exactly the rows the command inserted, and says what each document keeps")
    func undoRemovesWhatTheCommandInserted() throws {
        let (container, context) = try makeStore()
        _ = container
        _ = give(Self.tagA, to: "d1", in: context)
        try context.save()
        let outcome = try UserTagAdmin.assign(tagIds: [Self.tagB], to: [doc("d1"), doc("d2")], context: context)
        // Given after the command, by hand: not the command's to take back.
        _ = give(Self.tagC, to: "d2", in: context)
        try context.save()

        let removal = try UserTagAdmin.removeAssignments(withIds: outcome.insertedAssignmentIds, context: context)

        #expect(try rows(in: context) == ["d1=A", "d2=C"])
        #expect(removal.documents == [doc("d1"), doc("d2")])
        #expect(removal.tagIdsByDocument == [doc("d1").key: [Self.tagA], doc("d2").key: [Self.tagC]])
        #expect(try rows(in: ModelContext(container)) == ["d1=A", "d2=C"], "saved")
    }

    @Test("A row that is gone already is not an error, and a document left with no tag is still named")
    func aMissIsNotAnError() throws {
        let (container, context) = try makeStore()
        _ = container
        let outcome = try UserTagAdmin.assign(tagIds: [Self.tagA], to: [doc("d1"), doc("d2")], context: context)
        // d1's row is removed some other way before the Undo: the picker, or another device.
        let gone = try #require(try context.fetch(FetchDescriptor<DocumentTagAssignment>())
            .first { $0.documentId == "d1" })
        context.delete(gone)
        try context.save()

        let removal = try UserTagAdmin.removeAssignments(withIds: outcome.insertedAssignmentIds, context: context)

        #expect(removal.documents == [doc("d2")], "one row was there to remove")
        #expect(removal.tagIdsByDocument == [doc("d2").key: []], "d2 keeps nothing, and its row on screen must be told so")
        #expect(try rows(in: context).isEmpty)
    }

    /// The other device's row for the same pair is not this command's.
    @Test("A tag the document also carries by another row stays in what it keeps")
    func aTagHeldByAnotherRowStays() throws {
        let (container, context) = try makeStore()
        _ = container
        let outcome = try UserTagAdmin.assign(tagIds: [Self.tagA], to: [doc("d1")], context: context)
        _ = give(Self.tagA, to: "d1", in: context)   // arrives from another device
        try context.save()

        let removal = try UserTagAdmin.removeAssignments(withIds: outcome.insertedAssignmentIds, context: context)

        #expect(try rows(in: context) == ["d1=A"])
        #expect(removal.tagIdsByDocument == [doc("d1").key: [Self.tagA]])
    }

    @Test("With nothing to remove, nothing is read or saved")
    func nothingToRemove() throws {
        let (container, context) = try makeStore()
        _ = container
        _ = give(Self.tagA, to: "d1", in: context)
        try context.save()
        var reads = 0, saves = 0

        let none = try UserTagAdmin.removeAssignments(withIds: [], context: context,
                                                      fetch: { _ in reads += 1; return [] }, save: { _ in saves += 1 })
        #expect(none.documents.isEmpty && reads == 0 && saves == 0)

        let unknown = try UserTagAdmin.removeAssignments(withIds: [UUID()], context: context,
                                                         save: { _ in saves += 1 })
        #expect(unknown.documents.isEmpty && saves == 0, "an id that finds nothing saves nothing")
        #expect(try rows(in: context) == ["d1=A"])
    }

    /// Nothing is put back after a failed save: the rows are deleted in the context, and go for
    /// good with its next save. The error is the caller's to show.
    @Test("A removal whose save fails throws, with the rows out of the context and unsaved")
    func aFailedSaveOfARemovalThrows() throws {
        let (container, context) = try makeStore()
        _ = container
        let outcome = try UserTagAdmin.assign(tagIds: [Self.tagA], to: [doc("d1"), doc("d2")], context: context)
        #expect(throws: Refused.self) {
            try UserTagAdmin.removeAssignments(withIds: outcome.insertedAssignmentIds, context: context,
                                               save: { _ in throw Refused() })
        }
        #expect(try rows(in: context).isEmpty, "deleted in this context")
        #expect(try rows(in: ModelContext(container)) == ["d1=A", "d2=A"], "and still on disk")
    }

    @Test("A removal whose fetch fails throws and removes nothing")
    func aFailedFetchRemovesNothing() throws {
        let (container, context) = try makeStore()
        _ = container
        let outcome = try UserTagAdmin.assign(tagIds: [Self.tagA], to: [doc("d1")], context: context)
        #expect(throws: Refused.self) {
            try UserTagAdmin.removeAssignments(withIds: outcome.insertedAssignmentIds, context: context,
                                               fetch: { _ in throw Refused() })
        }
        #expect(try rows(in: context) == ["d1=A"])
    }
}

// MARK: - UserTagAssignIndexTests

/// The bulk tag writer through a real index (#1576 lane 5): what the search filter sees.
///
/// Version history:
///   1.0 — #1576 lane 5: initial implementation
@Suite("Bulk tag assignment, through a real index (#1576 lane 5)")
@MainActor
struct UserTagAssignIndexTests {

    private static let tagA = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!
    private static let tagB = UUID(uuidString: "BBBBBBBB-0000-0000-0000-000000000002")!

    private func doc(_ documentId: String) -> CollectionDocumentRef {
        CollectionDocumentRef(volumeId: "vol1", documentId: documentId)
    }

    /// A store and an index of one volume of four documents, `d1` to `d4`, each holding the
    /// word "containment".
    private func makeFixture() async throws
        -> (dir: URL, container: ModelContainer, context: ModelContext, pipeline: IndexingPipeline,
            service: SearchService) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSTagAssign-\(UUID().uuidString)", isDirectory: true)
        let volumes = dir.appendingPathComponent("volumes", isDirectory: true)
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        var xml = "<?xml version=\"1.0\"?>\n<TEI><text><body>\n"
        for index in 1...4 {
            xml += "<div type=\"document\" xml:id=\"d\(index)\"><head>\(index). Item</head>"
                + "<p>The doctrine of containment.</p></div>\n"
        }
        xml += "</body></text></TEI>"
        try Data(xml.utf8).write(to: volumes.appendingPathComponent("vol1.xml"))
        let database = dir.appendingPathComponent("test.sqlite")
        let store = try FTS5Store(databaseURL: database)
        let pipeline = try IndexingPipeline(fts5Store: store, databaseURL: database, volumesDirectory: volumes,
                                            concurrencyLimit: 1)
        try await pipeline.indexVolume("vol1")
        let container = try ModelContainer.makeTestContainer()
        return (dir, container, ModelContext(container), pipeline,
                SearchService(fts5Store: store, pipeline: pipeline))
    }

    /// The documents a keyword search filtered by `tag` lists.
    private func tagged(_ tag: UUID, by service: SearchService) async throws -> [String] {
        var parameters = SearchParameters(keywords: "containment")
        parameters.userTagIds = [tag.uuidString]
        return try await service.search(parameters: parameters).map(\.documentId).sorted()
    }

    /// The index's tag column of a document, read once the rewrites asked for so far have run.
    /// A rewrite is a detached task, as it is in the app, and the writer keeps the last one.
    private func column(_ pipeline: IndexingPipeline, _ documentId: String) async throws -> String? {
        await UserTagAdmin.pendingReindex?.value
        return try await pipeline.userTagIdsForTesting(volumeId: "vol1", documentId: documentId)
    }

    @Test("A search filtered by the tag returns exactly the tagged documents, and none after Undo")
    func theFilterSeesTheTagging() async throws {
        let (dir, container, context, pipeline, service) = try await makeFixture()
        _ = container
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(try await tagged(Self.tagA, by: service).isEmpty, "fixture: nothing is tagged yet")

        let outcome = try UserTagAdmin.assignAndIndex(tagIds: [Self.tagA], to: [doc("d1"), doc("d3")],
                                                      context: context, pipeline: pipeline)
        #expect(try await column(pipeline, "d1") == Self.tagA.uuidString)
        #expect(try await column(pipeline, "d3") == Self.tagA.uuidString)
        #expect(try await column(pipeline, "d2") == nil, "a document that was not asked for is not written")
        #expect(try await tagged(Self.tagA, by: service) == ["d1", "d3"])

        try UserTagAdmin.removeAssignmentsAndIndex(withIds: outcome.insertedAssignmentIds,
                                                   context: context, pipeline: pipeline)
        #expect(try await column(pipeline, "d1") == nil)
        #expect(try await column(pipeline, "d3") == nil)
        #expect(try await tagged(Self.tagA, by: service).isEmpty)
    }

    /// A recorder two tasks write to, and a gate the first of them waits at.
    private actor Order {
        private(set) var entries: [String] = []
        private(set) var isOpen = false
        func add(_ entry: String) { entries.append(entry) }
        func open() { isOpen = true }
    }

    /// A rewrite reads the store once and then writes a row at a time. Two of them side by side
    /// could finish in either order, and the one asked for first could then write last. So each
    /// waits for the one before it.
    @Test("A rewrite asked for second does not start until the first has finished")
    func theSecondWaitsForTheFirst() async throws {
        let order = Order()
        let first = UserTagAdmin.after(nil) {
            while await !order.isOpen { try? await Task.sleep(for: .milliseconds(10)) }
            await order.add("first")
        }
        let second = UserTagAdmin.after(first) { await order.add("second") }

        // Long enough for the second to have run, were it not waiting.
        try await Task.sleep(for: .milliseconds(300))
        #expect(await order.entries.isEmpty, "the second ran while the first was still at work")
        await order.open()
        await second.value
        #expect(await order.entries == ["first", "second"])
    }

    /// The link above, as the writer uses it. The tagging's rewrite is held where a real one would
    /// be between its read of the store and its writes; the Undo's must not have started.
    @Test("An Undo's rewrite does not start while the tagging's is still at work")
    func theUndosRewriteWaitsForTheTaggings() async throws {
        let (dir, container, context, pipeline, _) = try await makeFixture()
        _ = container
        defer { try? FileManager.default.removeItem(at: dir) }
        let order = Order()

        let outcome = try UserTagAdmin.assignAndIndex(
            tagIds: [Self.tagA], to: [doc("d1")], context: context, pipeline: pipeline,
            rewrite: { _, _, _ in
                while await !order.isOpen { try? await Task.sleep(for: .milliseconds(10)) }
                await order.add("tagging")
            })
        try UserTagAdmin.removeAssignmentsAndIndex(
            withIds: outcome.insertedAssignmentIds, context: context, pipeline: pipeline,
            rewrite: { _, _, _ in await order.add("undo") })

        // Long enough for the Undo's rewrite to have run, were it not waiting.
        try await Task.sleep(for: .milliseconds(300))
        #expect(await order.entries.isEmpty, "the Undo's rewrite ran while the tagging's was still at work")
        await order.open()
        await UserTagAdmin.pendingReindex?.value
        #expect(await order.entries == ["tagging", "undo"])
    }

    /// An Undo pressed straight after a tagging: its rewrite is asked for while the tagging's may
    /// not have run. Whatever the two tasks' order of starting, the index must end as the store is.
    @Test("A tagging and its Undo asked for back to back leave the index as the store is, without the tag")
    func rewritesRunInTheOrderAsked() async throws {
        let (dir, container, context, pipeline, service) = try await makeFixture()
        _ = container
        defer { try? FileManager.default.removeItem(at: dir) }
        let documents = (1...4).map { doc("d\($0)") }
        for round in 1...5 {
            let outcome = try UserTagAdmin.assignAndIndex(tagIds: [Self.tagA, Self.tagB], to: documents,
                                                          context: context, pipeline: pipeline)
            try UserTagAdmin.removeAssignmentsAndIndex(withIds: outcome.insertedAssignmentIds,
                                                       context: context, pipeline: pipeline)
            for document in documents {
                #expect(try await column(pipeline, document.documentId) == nil,
                        "round \(round): \(document.documentId) kept a tag the store no longer has")
            }
        }
        #expect(try await tagged(Self.tagA, by: service).isEmpty)
    }

    /// The string the index is given is the document's whole tag set, read from the store. A
    /// string made of the new tag alone would take the document out of its other tag's filter.
    @Test("The index is given the document's whole tag set: the tag it had is still found beside the new one")
    func theIndexKeepsTheTagTheDocumentHad() async throws {
        let (dir, container, context, pipeline, service) = try await makeFixture()
        _ = container
        defer { try? FileManager.default.removeItem(at: dir) }
        context.insert(DocumentTagAssignment(volumeId: "vol1", documentId: "d2", tagId: Self.tagA))
        try context.save()
        try await pipeline.updateUserTagIds(volumeId: "vol1", documentId: "d2", userTagIds: Self.tagA.uuidString)

        try UserTagAdmin.assignAndIndex(tagIds: [Self.tagB], to: [doc("d2")], context: context, pipeline: pipeline)
        let both = try #require(DocumentTagAssignment.tagColumnValue([Self.tagA, Self.tagB]))
        #expect(try await column(pipeline, "d2") == both)

        #expect(try await tagged(Self.tagA, by: service) == ["d2"])
        #expect(try await tagged(Self.tagB, by: service) == ["d2"])
    }

    @Test("With no index, the store is written and nothing else is asked for")
    func noIndexIsNotAnError() async throws {
        let (dir, container, context, _, _) = try await makeFixture()
        _ = container
        defer { try? FileManager.default.removeItem(at: dir) }
        let outcome = try UserTagAdmin.assignAndIndex(tagIds: [Self.tagA], to: [doc("d1")],
                                                      context: context, pipeline: nil)
        #expect(outcome.taggedDocuments == [doc("d1")])
        #expect(try context.fetch(FetchDescriptor<DocumentTagAssignment>()).count == 1)
    }
}

// MARK: - SearchResultTagRefreshTests

/// A result row copied with other tags (#1576 lane 5). `SearchResult` is the kit's and every
/// field is a `let`, so the app's one copy of it names each field; a field added to the kit and
/// not carried here would be dropped from a tagged row.
///
/// Version history:
///   1.0 — #1576 lane 5: initial implementation
@Suite("A result row's tags, refreshed (#1576 lane 5)")
struct SearchResultTagRefreshTests {

    private static let tagA = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!
    private static let tagB = UUID(uuidString: "BBBBBBBB-0000-0000-0000-000000000002")!

    /// A result with every field set to something its default is not.
    private static let full = SearchResult(
        documentId: "d42", volumeId: "frus1969-76v01", documentNumber: "42a", header: "Telegram",
        dateline: "Washington, May 1", dateISO: "1971-05-01", sourceNote: "Source: National Archives.",
        snippet: "a snippet", bm25Score: -3.5, semanticScore: 0.75, subjectTagIds: ["s1", "s2"],
        userTagIds: ["old"], isEditorialNote: true, isFrontMatter: true)

    @Test("A row is copied with its new tags, in the index's order, and nothing else changed")
    func everyOtherFieldIsCarried() {
        // Four, so that a set's own order is not the sorted one by luck more than one time in 24.
        let tagC = UUID(uuidString: "CCCCCCCC-0000-0000-0000-000000000003")!
        let tagD = UUID(uuidString: "DDDDDDDD-0000-0000-0000-000000000004")!
        let copy = Self.full.replacingUserTagIds([tagD, Self.tagB, tagC, Self.tagA])
        #expect(copy.userTagIds == [Self.tagA, Self.tagB, tagC, tagD].map(\.uuidString))
        #expect(copy.userTagIds.joined(separator: " ")
                == DocumentTagAssignment.tagColumnValue([Self.tagA, Self.tagB, tagC, tagD]),
                "the order is the index column's own")
        #expect(copy.id == Self.full.id)

        let before = Mirror(reflecting: Self.full).children.map { ($0.label ?? "?", String(describing: $0.value)) }
        let after = Mirror(reflecting: copy).children.map { ($0.label ?? "?", String(describing: $0.value)) }
        #expect(before.count == 14, """
            SearchResult has \(before.count) stored fields where it had 14. `replacingUserTagIds` names \
            each field it carries: add the new one there and to `full` above, then change this count.
            """)
        var compared = 0
        for (old, new) in zip(before, after) where old.0 != "userTagIds" {
            #expect(old.0 == new.0 && old.1 == new.1, "\(old.0) was \(old.1) and is \(new.1)")
            compared += 1
        }
        #expect(compared == 13)
    }

    @Test("A document left with no tag has a row with none")
    func noTags() {
        #expect(Self.full.replacingUserTagIds([]).userTagIds.isEmpty)
    }
}

// MARK: - TagPickerAddingModeTests

/// The tag picker's adding mode: its words, its count, and the one thing its Done must never do
/// (#1576 lane 5).
///
/// Version history:
///   1.0 — #1576 lane 5: initial implementation
@Suite("The tag picker's adding mode (#1576 lane 5)")
struct TagPickerAddingModeTests {

    private static let enUS = Locale(identifier: "en_US")
    private static let tagA = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!
    private static let tagB = UUID(uuidString: "BBBBBBBB-0000-0000-0000-000000000002")!

    private static func doc(_ documentId: String) -> CollectionDocumentRef {
        CollectionDocumentRef(volumeId: "vol1", documentId: documentId)
    }

    @Test("The title counts the documents")
    func title() {
        #expect(UserTagPickerCopy.addingTitle(count: 1, locale: Self.enUS) == "Tag 1 Document")
        #expect(UserTagPickerCopy.addingTitle(count: 37, locale: Self.enUS) == "Tag 37 Documents")
        #expect(UserTagPickerCopy.addingTitle(count: 1_000, locale: Self.enUS) == "Tag 1,000 Documents")
    }

    @Test("A tag says how many of the documents carry it already, and nothing when none does")
    func carried() {
        #expect(UserTagPickerCopy.carried(0, of: 37, locale: Self.enUS) == nil)
        #expect(UserTagPickerCopy.carried(1, of: 37, locale: Self.enUS) == "1 of 37 has it")
        #expect(UserTagPickerCopy.carried(12, of: 1_200, locale: Self.enUS) == "12 of 1,200 have it")
        #expect(UserTagPickerCopy.carried(37, of: 37, locale: Self.enUS) == "All 37 have it")
        #expect(UserTagPickerCopy.carried(1, of: 1, locale: Self.enUS) == "Already has it")
        #expect(UserTagPickerCopy.carried(0, of: 1, locale: Self.enUS) == nil)
    }

    @Test("The count is of the command's documents only, and a tag a document carries twice is counted once")
    func carriedCounts() {
        let counts = UserTagPickerCopy.carriedCounts(
            of: [Self.doc("d1"), Self.doc("d2"), Self.doc("d3")],
            in: [("vol1", "d1", Self.tagA), ("vol1", "d1", Self.tagA),   // twice on d1
                 ("vol1", "d2", Self.tagA), ("vol1", "d2", Self.tagB),
                 ("vol1", "d9", Self.tagA),                              // not one of the three
                 ("vol2", "d1", Self.tagB)])                             // another volume's d1
        #expect(counts == [Self.tagA: 2, Self.tagB: 1])
    }

    @Test("The footer and the two failures")
    func footerAndFailures() {
        #expect(UserTagPickerCopy.addingFooter == "Tags are added. A document keeps the tags it already has.")
        #expect(UserTagPickerCopy.addFailedTitle == "Not Tagged")
        #expect(UserTagPickerCopy.addFailure(UserTagAssignRefusal.overLimit(count: 1_250, limit: 1_000),
                                             locale: Self.enUS)
                == "Up to 1,000 documents can be tagged at a time, and 1,250 documents were chosen.")
        struct Disk: LocalizedError { var errorDescription: String? { "The disk is full." } }
        // One sentence for a read that failed and a save that failed: the writer makes both.
        #expect(UserTagPickerCopy.addFailure(Disk(), locale: Self.enUS)
                == "The tags could not be read or saved, so no document was tagged. The disk is full.")
    }

    // MARK: The sheet, read from source

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// `source` without its comment lines and with every run of whitespace removed.
    private static func squeezedCode(_ source: String) -> String {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
            .filter { !$0.isWhitespace }
    }

    private static func squeezed(_ text: String) -> String { text.filter { !$0.isWhitespace } }

    /// The declaration that opens with `header`, to the line that closes it at the header's own
    /// indentation.
    private static func declaration(_ header: String, in source: String) throws -> String {
        let start = try #require(source.range(of: header), "\(header) is gone: moved or renamed?")
        let lineStart = source[..<start.lowerBound].lastIndex(of: "\n").map(source.index(after:)) ?? source.startIndex
        let indent = source[lineStart..<start.lowerBound]
        let close = try #require(source.range(of: "\n\(indent)}\n", range: start.upperBound..<source.endIndex))
        return String(source[start.lowerBound..<close.upperBound])
    }

    /// The writer that replaces a document's tag set deletes every assignment the document has.
    /// Reached from the adding mode it would take every other tag off every document of a
    /// selection. So it takes the one document as its argument, and the adding mode's Done is a
    /// function of its own that calls the bulk writer and nothing else that writes.
    @Test("Done has a writer for each mode, and the adding mode's cannot reach the one that replaces a tag set")
    func doneCannotReplaceInAddingMode() throws {
        let sheet = try Self.source("FRUSExplorer/DocumentView/UserTagPickerSheet.swift")
        #expect(Self.squeezedCode(try Self.declaration("private func saveAndDismiss() {", in: sheet))
            == Self.squeezed("""
                private func saveAndDismiss() {
                    guard !isClosed else { return }
                    switch mode {
                    case .document(let entry):
                        replaceTags(of: entry)
                    case .adding(let documents):
                        guard addTags(to: documents) else { return }
                    }
                    isClosed = true
                    dismiss()
                }
                """))
        let adding = Self.squeezedCode(try Self.declaration(
            "private func addTags(to documents: [CollectionDocumentRef]) -> Bool {", in: sheet))
        #expect(adding.contains(Self.squeezed("""
            let outcome = try UserTagAdmin.assignAndIndex(
                tagIds: chosen.map(\\.id), to: documents, context: modelContext, pipeline: indexingPipeline)
            keepNewTags()
            onTagged?(outcome, chosen.map(\\.name))
            return true
            """)))
        #expect(adding.contains(Self.squeezed("""
            addFailure = UserTagPickerCopy.addFailure(error)
            return false
            """)), "a write that failed says why and keeps the sheet up")
        for forbidden in ["syncAssignmentsToSwiftData", "replaceTags", "modelContext.delete", "updateUserTagIds"] {
            #expect(!adding.contains(forbidden), "the adding mode's Done must not call \(forbidden)")
        }
        // The replacing writer is called from one place, and that place from one place.
        let code = sheet.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
        #expect(code.filter { $0.contains("syncAssignmentsToSwiftData(for:") && !$0.contains("func ") }.count == 1)
        #expect(code.filter { $0.contains("replaceTags(of:") && !$0.contains("func ") }.count == 1)
        #expect(sheet.contains("private func syncAssignmentsToSwiftData(for entry: DocumentBrowserEntry) {"),
                "the document is the writer's argument: the adding mode has none to give it")
    }

    /// The sheet stays on screen for a moment after it is dismissed. A second Return in that
    /// moment would add nothing and replace the line that offered to undo the first; an Esc would
    /// delete a tag made in the sheet that documents had just been given.
    @Test("Done and Cancel each run once to a presentation, and not one after the other")
    func oneCloseToAPresentation() throws {
        let sheet = try Self.source("FRUSExplorer/DocumentView/UserTagPickerSheet.swift")
        #expect(Self.squeezedCode(try Self.declaration("private func cancelAndDismiss() {", in: sheet))
            .hasPrefix(Self.squeezed("""
                private func cancelAndDismiss() {
                    guard !isClosed else { return }
                    isClosed = true
                """)))
        #expect(Self.squeezedCode(try Self.declaration("private func saveAndDismiss() {", in: sheet))
            .hasPrefix(Self.squeezed("""
                private func saveAndDismiss() {
                    guard !isClosed else { return }
                """)))
        // The flag is set by these two and by nothing else, and Done sets it only where it closes.
        let code = sheet.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
        #expect(code.filter { $0.contains("isClosed = true") }.count == 2)
        #expect(code.filter { $0.contains("dismiss()") && !$0.contains("func ") }.count == 2,
                "each closes the sheet in one place, after it has set the flag")
    }

    @Test("The adding mode starts with every toggle off, reads how many documents carry each tag as it opens, and says a failure")
    func addingModeOpens() throws {
        let sheet = try Self.source("FRUSExplorer/DocumentView/UserTagPickerSheet.swift")
        let code = Self.squeezedCode(sheet)
        #expect(code.contains(Self.squeezed("""
            self.mode = .adding(documents)
            self.indexingPipeline = indexingPipeline
            self.onTagged = onTagged
            _selectedTagIds = State(initialValue: [])
            """)))
        #expect(code.contains(Self.squeezed("""
            guard let documents = addingDocuments, carriedCounts.isEmpty else { return }
            let assignments = (try? modelContext.fetch(FetchDescriptor<DocumentTagAssignment>())) ?? []
            carriedCounts = UserTagPickerCopy.carriedCounts(
                of: documents,
                in: assignments.map { (volumeId: $0.volumeId, documentId: $0.documentId, tagId: $0.tagId) })
            """)), "in the adding mode only, and not again once counts are in hand")
        #expect(code.contains(Self.squeezed("addFailure = UserTagPickerCopy.addFailure(error)")))
        #expect(code.contains(Self.squeezed(".alert(UserTagPickerCopy.addFailedTitle,")))
        // The line under the tags is the adding mode's, in the section whose footer wraps on the
        // Mac (#1475). The document mode's section is the titled one it has always been, so that
        // its sheet is drawn as it was.
        #expect(code.contains(Self.squeezed("""
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
            """)))
    }
}

// MARK: - ResultTaggingWiringTests

/// Add Tags in the two search hosts, read from source (#1576 lane 5): each makes its request from
/// the row or the selection, and neither builds the tag picker itself.
///
/// Version history:
///   1.0 — #1576 lane 5: initial implementation
@Suite("Result tagging, the hosts' wiring (#1576 lane 5)")
struct ResultTaggingWiringTests {

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// `source` without its comment lines.
    private static func code(_ source: String) -> String {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private static func squeezed(_ text: String) -> String { text.filter { !$0.isWhitespace } }

    @Test("Each search host makes the tag request from the row, frozen, and builds no tag picker of its own",
          arguments: [
            (path: "FRUSExplorer/Search/SearchView.swift", model: "vm", voiceOverAction: true),
            (path: "FRUSExplorer/App/SearchSheet.swift", model: "searchVM", voiceOverAction: false),
          ])
    func hostMakesTheTagRequestFromTheRow(host: (path: String, model: String, voiceOverAction: Bool)) throws {
        let code = Self.code(try Self.source(host.path))
        let squeezed = Self.squeezed(code)
        #expect(squeezed.contains(Self.squeezed("""
            private func addTagsRequest(for result: SearchResult) -> BulkResultRequest? {
                BulkResultRequest(.addTags, results: [result],
                                  fromMeaningSearch: \(host.model).resultsAreSemantic)
            }
            """)), "\(host.path) does not build the tag request from the row")

        // The row's item, directly after its Add to Collection….
        let items = Self.squeezed("""
                    Button {
                        bulkRequest = addToCollectionRequest(for: result)
                    } label: {
                        Label(BulkResultCopy.addToCollection, systemImage: "plus.circle")
                    }
                    Button {
                        bulkRequest = addTagsRequest(for: result)
                    } label: {
                        Label(BulkResultCopy.addTags, systemImage: "tag")
                    }
            """)
        #expect(squeezed.contains(items), "\(host.path): the row's menu has no Add Tags… after Add to Collection…")

        let makers = code.components(separatedBy: "bulkRequest = addTagsRequest(for: result)").count - 1
        if host.voiceOverAction {
            // On iPhone and iPad the row is one accessibility element and carries the command as
            // a named action too, after the collection's.
            #expect(makers == 2, "\(host.path): the row's menu item and its VoiceOver action must each make the request")
            #expect(squeezed.contains(Self.squeezed("""
                .accessibilityAction(named: Text(BulkResultCopy.addToCollection)) {
                    bulkRequest = addToCollectionRequest(for: result)
                }
                .accessibilityAction(named: Text(BulkResultCopy.addTags)) {
                    bulkRequest = addTagsRequest(for: result)
                }
                """)), "\(host.path): the row has no Add Tags action")
        } else {
            #expect(makers == 1, "\(host.path): the menu item alone makes the request")
        }

        // The sheet is the presenter's, built from the request. A host that built the picker
        // itself would read whatever is on screen when the sheet opens (#862).
        #expect(!code.contains("UserTagPickerSheet(adding:"),
                "\(host.path) builds the tag picker itself, where it should hand over a request")
        #expect(!code.contains("UserTagAdmin.assign"),
                "\(host.path) writes tags itself: the picker's adding mode is the one writer")
    }

    /// The Undo's index half. Taking the rows out of the store alone would leave the tag in the
    /// search filter until the next launch.
    @Test("Each host's Undo of a tagging rewrites the index for the documents it touched")
    func undoRewritesTheIndex() throws {
        for path in ["FRUSExplorer/Search/SearchView.swift", "FRUSExplorer/App/SearchSheet.swift"] {
            let squeezed = Self.squeezed(Self.code(try Self.source(path)))
            #expect(squeezed.contains(Self.squeezed("""
                removingTagAssignments: { ids in
                    try UserTagAdmin.removeAssignmentsAndIndex(
                        withIds: ids, context: modelContext, pipeline: appState.indexingPipeline)
                })
                """)), "\(path)")
            #expect(!squeezed.contains("UserTagAdmin.removeAssignments(withIds"),
                    "\(path) removes the rows and leaves the index's copy of the tag behind")
        }
        // And the two functions that pair a store write with the index's.
        let admin = Self.squeezed(Self.code(try Self.source("FRUSExplorer/Models/UserTagAssign.swift")))
        #expect(admin.contains(Self.squeezed("""
            let outcome = try assign(tagIds: tagIds, to: documents, context: context)
            reindex(outcome.taggedDocuments, container: context.container, pipeline: pipeline, rewrite: rewrite)
            return outcome
            """)))
        #expect(admin.contains(Self.squeezed("""
            let removal = try removeAssignments(withIds: ids, context: context)
            reindex(removal.documents, container: context.container, pipeline: pipeline, rewrite: rewrite)
            return removal
            """)))
        // What rewrites the column, unless a test says otherwise, is the #1591 fix's own function,
        // which re-reads the store. `UserTagAssignIndexTests` runs the chain the two go through.
        #expect(admin.components(separatedBy: Self.squeezed(
            "rewrite: @escaping TagColumnRewrite = DocumentTagAssignment.reindexTagColumn")).count - 1 == 2)
    }
}

