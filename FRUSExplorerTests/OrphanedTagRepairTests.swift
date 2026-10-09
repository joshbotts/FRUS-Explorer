// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
import SwiftData
@testable import FRUSExplorer

// MARK: - OrphanedTagRepairTests (#406)

/// Covers the #406 fix: cascading tag deletion (`UserTagAdmin.deleteCascading`), orphaned-tag
/// reconstruction (`OrphanedTagRepair`), and the placeholder-aware dedupe keeper
/// (`DuplicateRecordCleanup`). All tests run on the main actor because these types are
/// `@MainActor`-isolated.
@MainActor
struct OrphanedTagRepairTests {

    // Stable ids so the deterministic ordering/naming is checkable.
    private static let realId   = UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!
    private static let orphanB  = UUID(uuidString: "11111111-1111-1111-1111-1111111111BB")!
    private static let orphanC  = UUID(uuidString: "22222222-2222-2222-2222-2222222222CC")!
    private static let orphanD  = UUID(uuidString: "33333333-3333-3333-3333-3333333333DD")!

    private func makeContext() throws -> ModelContext {
        ModelContext(try ModelContainer.makeTestContainer())
    }

    // MARK: - placeholders(...) pure logic

    @Test("placeholders: only ids referenced-but-absent become placeholders, keyed by earliest date")
    func placeholdersComputesOrphansWithEarliestDate() throws {
        let early = Date(timeIntervalSince1970: 1_000)
        let late  = Date(timeIntervalSince1970: 2_000)

        // Real tag (present) referenced by an assignment — must NOT become a placeholder.
        let aReal = DocumentTagAssignment(volumeId: "v1", documentId: "d1", tagId: Self.realId)
        aReal.createdAt = late
        // Orphan B referenced by two assignments (late, then early) — placeholder date = early.
        let aB1 = DocumentTagAssignment(volumeId: "v1", documentId: "d2", tagId: Self.orphanB)
        aB1.createdAt = late
        let aB2 = DocumentTagAssignment(volumeId: "v2", documentId: "d3", tagId: Self.orphanB)
        aB2.createdAt = early
        // Orphan C referenced only by an assignment.
        let aC = DocumentTagAssignment(volumeId: "v1", documentId: "d4", tagId: Self.orphanC)
        aC.createdAt = late

        // Orphan D referenced ONLY by a note; real id also on the note (must be ignored).
        let note = ResearchNote(documentId: "d5", volumeId: "v1",
                                userTagIds: [Self.orphanD, Self.realId])
        note.createdAt = early

        let result = OrphanedTagRepair.placeholders(
            assignments: [aReal, aB1, aB2, aC],
            notes: [note],
            existingTagIds: [Self.realId]
        )

        let byId = Dictionary(uniqueKeysWithValues: result.map { ($0.id, $0) })
        #expect(Set(byId.keys) == [Self.orphanB, Self.orphanC, Self.orphanD])
        #expect(byId[Self.realId] == nil)                       // present tag never reconstructed
        #expect(byId[Self.orphanB]?.createdAt == early)         // earliest of its two assignments
        #expect(byId[Self.orphanC]?.createdAt == late)
        #expect(byId[Self.orphanD]?.createdAt == early)         // from the note
        #expect(byId[Self.orphanB]?.name.hasPrefix(OrphanedTagRepair.placeholderNamePrefix) == true)
        // Deterministic sort by uuidString.
        #expect(result.map(\.id) == [Self.orphanB, Self.orphanC, Self.orphanD])
    }

    @Test("placeholders: empty when every referenced id has a tag")
    func placeholdersEmptyWhenNoOrphans() throws {
        let a = DocumentTagAssignment(volumeId: "v1", documentId: "d1", tagId: Self.realId)
        let result = OrphanedTagRepair.placeholders(
            assignments: [a], notes: [], existingTagIds: [Self.realId]
        )
        #expect(result.isEmpty)
    }

    // MARK: - run(context:) reconstruction

    @Test("run: reconstructs a placeholder UserTag with the exact orphaned id, and is idempotent")
    func runReconstructsAndIsIdempotent() throws {
        let context = try makeContext()

        // One real tag + assignment, plus two orphaned assignments (no matching UserTag).
        let real = UserTag(name: "Supply Chain Security in Field")
        real.id = Self.realId
        context.insert(real)
        context.insert(DocumentTagAssignment(volumeId: "v1", documentId: "d1", tagId: Self.realId))
        context.insert(DocumentTagAssignment(volumeId: "v1", documentId: "d2", tagId: Self.orphanB))
        context.insert(DocumentTagAssignment(volumeId: "v2", documentId: "d3", tagId: Self.orphanC))
        try context.save()

        let created = OrphanedTagRepair.run(context: context)
        #expect(created == 2)

        let tags = try context.fetch(FetchDescriptor<UserTag>())
        #expect(tags.count == 3)
        let ids = Set(tags.map(\.id))
        #expect(ids == [Self.realId, Self.orphanB, Self.orphanC])
        // The reconstructed records carry the orphaned ids (so associations re-attach) and are
        // marked as placeholders.
        let reconstructed = tags.filter { $0.id != Self.realId }
        #expect(reconstructed.allSatisfy { OrphanedTagRepair.isPlaceholderName($0.name) })

        // Idempotent: a second run finds no orphans.
        #expect(OrphanedTagRepair.run(context: context) == 0)
        #expect(try context.fetch(FetchDescriptor<UserTag>()).count == 3)
    }

    // MARK: - deleteCascading

    @Test("deleteCascading: removes the tag AND its assignments and note references, sparing others")
    func deleteCascadingLeavesNoOrphans() throws {
        let context = try makeContext()

        let victim = UserTag(name: "Doomed")
        let keep   = UserTag(name: "Keep")
        context.insert(victim)
        context.insert(keep)

        // Two assignments for the victim, one for the tag we keep.
        context.insert(DocumentTagAssignment(volumeId: "v1", documentId: "d1", tagId: victim.id))
        context.insert(DocumentTagAssignment(volumeId: "v1", documentId: "d2", tagId: victim.id))
        context.insert(DocumentTagAssignment(volumeId: "v1", documentId: "d3", tagId: keep.id))

        // A note carrying both tags.
        let note = ResearchNote(documentId: "d1", volumeId: "v1", userTagIds: [victim.id, keep.id])
        context.insert(note)
        try context.save()

        UserTagAdmin.deleteCascading(victim, context: context, pipeline: nil)

        // Tag gone.
        #expect(try context.fetch(FetchDescriptor<UserTag>()).map(\.name).sorted() == ["Keep"])
        // No assignment references the victim; the kept tag's assignment survives.
        let assignments = try context.fetch(FetchDescriptor<DocumentTagAssignment>())
        #expect(assignments.allSatisfy { $0.tagId != victim.id })
        #expect(assignments.contains { $0.tagId == keep.id })
        // Note no longer carries the victim id, still carries the kept one.
        let notes = try context.fetch(FetchDescriptor<ResearchNote>())
        #expect(notes.first?.userTagIds == [keep.id])

        // And crucially: after a cascading delete there is nothing for the repair to resurrect.
        #expect(OrphanedTagRepair.run(context: context) == 0)
    }

    // MARK: - Project tag-focus hygiene (#377 Phase 3)

    @Test("deleteCascading strips the deleted tag from every project's tag focus")
    func deleteCascadingStripsProjectFocus() throws {
        let context = try makeContext()
        let victim = UserTag(name: "Doomed")
        let keep   = UserTag(name: "Keep")
        context.insert(victim); context.insert(keep)
        let project = Project(name: "P")
        project.defaultUserTagIds = [victim.id, keep.id]
        context.insert(project)
        try context.save()

        UserTagAdmin.deleteCascading(victim, context: context, pipeline: nil)

        let p = try #require(try context.fetch(FetchDescriptor<Project>()).first)
        #expect(p.defaultUserTagIds == [keep.id])   // victim stripped, keep survives
    }

    @Test("repointTagInProjectFocus re-points a merged tag's focus id to the target (deduped)")
    func repointProjectFocusOnMerge() throws {
        let context = try makeContext()
        let source = UUID(); let target = UUID(); let other = UUID()
        let onlySource = Project(name: "A"); onlySource.defaultUserTagIds = [source, other]
        let bothAlready = Project(name: "B"); bothAlready.defaultUserTagIds = [source, target]
        context.insert(onlySource); context.insert(bothAlready)
        try context.save()

        UserTagAdmin.repointTagInProjectFocus(from: source, to: target, in: context)

        let byName = Dictionary(uniqueKeysWithValues:
            (try context.fetch(FetchDescriptor<Project>())).map { ($0.name, $0) })
        #expect(Set(byName["A"]!.defaultUserTagIds) == [other, target])   // source → target
        #expect(byName["B"]!.defaultUserTagIds == [target])               // already had target: no dup
    }

    @Test("placeholders reconstructs an orphan referenced only by a project's tag focus")
    func placeholdersFromProjectOnlyOrphan() throws {
        let project = Project(name: "P")
        project.defaultUserTagIds = [Self.orphanB]
        let result = OrphanedTagRepair.placeholders(
            assignments: [], notes: [], existingTagIds: [], projects: [project])
        #expect(result.map(\.id) == [Self.orphanB])
    }

    // MARK: - DuplicateRecordCleanup keeper preference

    @Test("dedupe: a real UserTag always wins over a placeholder that shares its id")
    func dedupePrefersRealOverPlaceholder() throws {
        let context = try makeContext()

        // A returning real record and a reconstructed placeholder that share one id.
        let real = UserTag(name: "Berlin Crisis")
        real.id = Self.orphanB
        real.createdAt = Date(timeIntervalSince1970: 500)          // earlier (as a real tag would be)
        let placeholder = UserTag(name: OrphanedTagRepair.placeholderNamePrefix + "11111111")
        placeholder.id = Self.orphanB
        placeholder.createdAt = Date(timeIntervalSince1970: 1_000) // later (min-assignment date)
        context.insert(real)
        context.insert(placeholder)
        try context.save()

        DuplicateRecordCleanup.run(context: context)

        let tags = try context.fetch(FetchDescriptor<UserTag>())
        #expect(tags.count == 1)
        #expect(tags.first?.name == "Berlin Crisis")               // real name preserved, placeholder dropped
        #expect(tags.first?.id == Self.orphanB)                    // id (and associations) preserved
    }

    @Test("dedupe: prefers the real record even when the placeholder is the earlier one")
    func dedupePrefersRealEvenWhenPlaceholderIsEarlier() throws {
        let context = try makeContext()

        // Adversarial: placeholder has the EARLIER createdAt, so a pure earliest-wins rule would
        // keep it. The non-placeholder preference must still keep the real record.
        let placeholder = UserTag(name: OrphanedTagRepair.placeholderNamePrefix + "22222222")
        placeholder.id = Self.orphanC
        placeholder.createdAt = Date(timeIntervalSince1970: 100)
        let real = UserTag(name: "Named By User")
        real.id = Self.orphanC
        real.createdAt = Date(timeIntervalSince1970: 900)
        context.insert(placeholder)
        context.insert(real)
        try context.save()

        DuplicateRecordCleanup.run(context: context)

        let tags = try context.fetch(FetchDescriptor<UserTag>())
        #expect(tags.count == 1)
        #expect(tags.first?.name == "Named By User")
    }

    @Test("isPlaceholderName: matches the reconstruction prefix only")
    func isPlaceholderNameMatches() {
        #expect(OrphanedTagRepair.isPlaceholderName("Recovered Tag abcd1234"))
        #expect(!OrphanedTagRepair.isPlaceholderName("Berlin Crisis"))
        #expect(!OrphanedTagRepair.isPlaceholderName(""))
    }

    // MARK: - #406 review folds

    @Test("dedupe-then-repair: a late-synced real tag collapses a prior placeholder, leaving one real record")
    func dedupeThenRepairCollapsesLateDuplicate() throws {
        let context = try makeContext()

        // Reproduces the post-import debounce state (#406 review, Finding 2): an earlier debounce
        // minted a placeholder for an orphaned id, then the genuine tag arrived in a later import.
        // Both rows now coexist plus an assignment keyed on the shared id. The debounce runs dedupe
        // BEFORE repair so this duplicate collapses immediately (real record kept) instead of
        // lingering — visibly duplicated in pickers — until the next cold boot.
        let placeholder = UserTag(name: OrphanedTagRepair.placeholderNamePrefix + "11111111")
        placeholder.id = Self.orphanB
        placeholder.createdAt = Date(timeIntervalSince1970: 1_000)
        let real = UserTag(name: "Berlin Crisis")
        real.id = Self.orphanB
        real.createdAt = Date(timeIntervalSince1970: 500)
        context.insert(placeholder)
        context.insert(real)
        context.insert(DocumentTagAssignment(volumeId: "v1", documentId: "d1", tagId: Self.orphanB))
        try context.save()

        DuplicateRecordCleanup.run(context: context)          // dedupe first: drop the placeholder
        #expect(OrphanedTagRepair.run(context: context) == 0) // id now has a real tag → nothing to repair

        let tags = try context.fetch(FetchDescriptor<UserTag>())
        #expect(tags.count == 1)
        #expect(tags.first?.name == "Berlin Crisis")          // real kept, placeholder dropped
        let assignments = try context.fetch(FetchDescriptor<DocumentTagAssignment>())
        #expect(assignments.count == 1)
        #expect(assignments.first?.tagId == tags.first?.id)   // association re-attaches to the survivor
    }

    @Test("dedupe: a renamed placeholder that outranks a returning original still preserves the association")
    func dedupeRenamedPlaceholderPreservesAssociations() throws {
        let context = try makeContext()

        // Finding 1 (#406 review): after the user RENAMES a recovered placeholder, its name no
        // longer carries the "Recovered Tag" prefix, so the keeper's non-placeholder tier no longer
        // separates it from a returning original; and if `mergeTag` had re-pointed an OLDER
        // assignment, the placeholder's createdAt can be earlier than the original's. The keeper
        // then picks the renamed placeholder. This is acceptable — the two rows share an id, so the
        // assignment re-attaches to whichever survives and NO annotation is lost.
        let renamedPlaceholder = UserTag(name: "Renamed By User")        // was a placeholder, now renamed
        renamedPlaceholder.id = Self.orphanC
        renamedPlaceholder.createdAt = Date(timeIntervalSince1970: 100)  // merge-poisoned earlier date
        let original = UserTag(name: "Original Name")
        original.id = Self.orphanC
        original.createdAt = Date(timeIntervalSince1970: 900)
        context.insert(renamedPlaceholder)
        context.insert(original)
        context.insert(DocumentTagAssignment(volumeId: "v1", documentId: "d1", tagId: Self.orphanC))
        try context.save()

        DuplicateRecordCleanup.run(context: context)

        let tags = try context.fetch(FetchDescriptor<UserTag>())
        #expect(tags.count == 1)                              // collapsed to a single row
        #expect(tags.first?.id == Self.orphanC)               // id preserved …
        let assignments = try context.fetch(FetchDescriptor<DocumentTagAssignment>())
        #expect(assignments.count == 1)
        #expect(assignments.first?.tagId == tags.first?.id)   // … so the association survives either way
    }
}

// MARK: - TagColumnReconcileTests (#1591)

/// The index's copy of a document's tags, `document_cache.user_tag_ids`, kept level with the
/// reader's `DocumentTagAssignment` records (#1591).
///
/// The launch pass wrote the column for every document that had an assignment and visited no
/// other, so a document whose last tag went away without a write on this device (removed on
/// another, or deleted with its tag in Settings) stayed tagged in Search for good. The plan is
/// pure and is driven with no store; the reconcile, the delete and the row reader are driven
/// through a store and an index of one small volume.
///
/// Version history:
///   1.0 — Session 2026-10-09: #1591
@Suite("The index's tag column follows the assignments (#1591)")
@MainActor
struct TagColumnReconcileTests {

    private static let tagA = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!
    private static let tagB = UUID(uuidString: "BBBBBBBB-0000-0000-0000-000000000002")!
    private static var a: String { tagA.uuidString }
    private static var b: String { tagB.uuidString }

    private typealias Assignment = (volumeId: String, documentId: String, tagId: UUID)
    private typealias Row = (volumeId: String, documentId: String, userTagIds: String)

    private func plan(_ assignments: [Assignment]?, carrying: [Row], sweeping: Bool = true)
        -> (writes: [String], clears: [String]) {
        let plan = DocumentTagAssignment.tagColumnPlan(for: assignments, carrying: carrying,
                                                       sweepingStaleRows: sweeping)
        return (plan.writes.map { "\($0.volumeId)/\($0.documentId)=\($0.userTagIds)" },
                plan.clears.map { "\($0.volumeId)/\($0.documentId)" })
    }

    // MARK: The plan

    @Test("A row whose document has no assignment left is cleared, and only that row")
    func aRowNoAssignmentAccountsForIsCleared() {
        let result = plan([("v1", "d1", Self.tagA)],
                          carrying: [("v1", "d1", Self.a), ("v1", "d2", Self.b), ("v2", "d1", Self.a)])
        #expect(result.clears == ["v1/d2", "v2/d1"], "got \(result.clears)")
        #expect(result.writes.isEmpty, "d1 already names its tag: \(result.writes)")
    }

    @Test("No assignment at all clears nothing: a store that has not loaded is not a reader with no tags")
    func anEmptyStoreClearsNothing() {
        let result = plan([], carrying: [("v1", "d2", Self.b)])
        #expect(result.clears.isEmpty)
        #expect(result.writes.isEmpty)
    }

    @Test("Assignments that could not be read plan nothing, writes included")
    func unreadableAssignmentsPlanNothing() {
        let result = plan(nil, carrying: [("v1", "d2", Self.b)])
        #expect(result.clears.isEmpty && result.writes.isEmpty)
    }

    @Test("Without the sweep nothing is cleared, and a changed row is still written")
    func theSweepIsSeparableFromTheWrite() {
        let result = plan([("v1", "d1", Self.tagA)],
                          carrying: [("v1", "d1", Self.b), ("v1", "d2", Self.b)], sweeping: false)
        #expect(result.clears.isEmpty)
        #expect(result.writes == ["v1/d1=\(Self.a)"])
    }

    @Test("A row that names the document's tags in another order, or one twice, is left as it is")
    func aRowNamingTheSameTagsIsNotRewritten() {
        let assignments: [Assignment] = [("v1", "d1", Self.tagA), ("v1", "d1", Self.tagB)]
        #expect(plan(assignments, carrying: [("v1", "d1", "\(Self.b) \(Self.a) \(Self.a)")]).writes.isEmpty)
        // One tag short, and one tag over, are both rewritten, to the ids in order.
        #expect(plan(assignments, carrying: [("v1", "d1", Self.b)]).writes == ["v1/d1=\(Self.a) \(Self.b)"])
        #expect(plan([("v1", "d1", Self.tagB)], carrying: [("v1", "d1", "\(Self.a) \(Self.b)")]).writes
                == ["v1/d1=\(Self.b)"])
    }

    @Test("A document the index does not yet carry is written, keyed by volume and document")
    func aNewlyTaggedDocumentIsWritten() {
        // The same document id in two volumes is two documents; the fetch's order is not the plan's.
        let result = plan([("v2", "d1", Self.tagB), ("v1", "d9", Self.tagA),
                           ("v1", "d1", Self.tagB), ("v1", "d1", Self.tagA)], carrying: [])
        #expect(result.writes == ["v1/d1=\(Self.a) \(Self.b)", "v1/d9=\(Self.a)", "v2/d1=\(Self.b)"],
                "got \(result.writes)")
        #expect(result.clears.isEmpty)
    }

    @Test("A row holding an empty string is cleared with the rest")
    func anEmptyStringRowIsCleared() {
        let result = plan([("v1", "d1", Self.tagA)], carrying: [("v1", "d1", Self.a), ("v1", "d2", "")])
        #expect(result.clears == ["v1/d2"])
    }

    // MARK: Through a store and an index

    /// A store and an index of one volume of four documents, `d1` to `d4`.
    private func makeFixture() async throws
        -> (dir: URL, container: ModelContainer, context: ModelContext, pipeline: IndexingPipeline) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSTagColumn-\(UUID().uuidString)", isDirectory: true)
        let volumes = dir.appendingPathComponent("volumes", isDirectory: true)
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        var xml = "<?xml version=\"1.0\"?>\n<TEI><text><body>\n"
        for index in 1...4 {
            xml += "<div type=\"document\" xml:id=\"d\(index)\"><head>\(index). Item</head><p>Text.</p></div>\n"
        }
        xml += "</body></text></TEI>"
        try Data(xml.utf8).write(to: volumes.appendingPathComponent("vol1.xml"))
        let database = dir.appendingPathComponent("test.sqlite")
        let pipeline = try IndexingPipeline(fts5Store: try FTS5Store(databaseURL: database),
                                            databaseURL: database, volumesDirectory: volumes,
                                            concurrencyLimit: 1)
        try await pipeline.indexVolume("vol1")
        let container = try ModelContainer.makeTestContainer()
        return (dir, container, ModelContext(container), pipeline)
    }

    private func column(_ pipeline: IndexingPipeline, _ documentId: String) async throws -> String? {
        try await pipeline.userTagIdsForTesting(volumeId: "vol1", documentId: documentId)
    }

    @Test("The reconcile clears the row of a document whose last tag is gone, and writes the rest")
    func theReconcileClearsWhatNoAssignmentAccountsFor() async throws {
        let (dir, container, context, pipeline) = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        // d1 still has its tag. d2's was removed on another device: the index still carries it.
        // d3 was tagged on another device: the index does not carry it yet.
        context.insert(DocumentTagAssignment(volumeId: "vol1", documentId: "d1", tagId: Self.tagA))
        context.insert(DocumentTagAssignment(volumeId: "vol1", documentId: "d3", tagId: Self.tagB))
        try context.save()
        try await pipeline.updateUserTagIds(volumeId: "vol1", documentId: "d1", userTagIds: Self.a)
        try await pipeline.updateUserTagIds(volumeId: "vol1", documentId: "d2", userTagIds: Self.b)

        let outcome = await DocumentTagAssignment.reconcileTagColumn(
            container: container, pipeline: pipeline, sweepingStaleRows: true)

        #expect(try await column(pipeline, "d2") == nil, "the stale tag must leave the index")
        #expect(try await column(pipeline, "d1") == Self.a)
        #expect(try await column(pipeline, "d3") == Self.b)
        #expect(try await column(pipeline, "d4") == nil)
        #expect(outcome.written == 1 && outcome.cleared == 1, "got \(outcome)")
        // The row reader, which the next pass subtracts from, no longer reports d2.
        #expect(try pipeline.documentsWithUserTagIds().map(\.documentId) == ["d1", "d3"])
    }

    @Test("Without the sweep, and with no assignment in the store, the reconcile leaves a row alone")
    func theReconcileRefusesWhenItShould() async throws {
        let (dir, container, context, pipeline) = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        try await pipeline.updateUserTagIds(volumeId: "vol1", documentId: "d2", userTagIds: Self.b)

        // The store holds no assignment: the floor.
        await DocumentTagAssignment.reconcileTagColumn(
            container: container, pipeline: pipeline, sweepingStaleRows: true)
        #expect(try await column(pipeline, "d2") == Self.b)

        // The store holds one, and the sweep is off: launch with iCloud on.
        context.insert(DocumentTagAssignment(volumeId: "vol1", documentId: "d1", tagId: Self.tagA))
        try context.save()
        await DocumentTagAssignment.reconcileTagColumn(
            container: container, pipeline: pipeline, sweepingStaleRows: false)
        #expect(try await column(pipeline, "d2") == Self.b)
        #expect(try await column(pipeline, "d1") == Self.a, "the write half still runs")

        // The same store with the sweep on clears it: the two refusals above were the floor's and
        // the parameter's, not a reconcile that never clears.
        await DocumentTagAssignment.reconcileTagColumn(
            container: container, pipeline: pipeline, sweepingStaleRows: true)
        #expect(try await column(pipeline, "d2") == nil)
    }

    /// Waits for `documentId`'s column to read `expected`: `deleteCascading` rewrites the index in
    /// a task of its own.
    private func waitForColumn(_ pipeline: IndexingPipeline, _ documentId: String,
                               toBe expected: String?) async throws -> String? {
        var value = try await column(pipeline, documentId)
        for _ in 0..<200 where value != expected {
            try await Task.sleep(for: .milliseconds(50))
            value = try await column(pipeline, documentId)
        }
        return value
    }

    @Test("Deleting a tag rewrites the rows of the documents that carried it, at once")
    func deletingATagRewritesItsDocuments() async throws {
        let (dir, container, context, pipeline) = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let doomed = UserTag(name: "Doomed")
        doomed.id = Self.tagA
        let kept = UserTag(name: "Kept")
        kept.id = Self.tagB
        context.insert(doomed)
        context.insert(kept)
        // d1 carries only the doomed tag, d2 both, d3 only the kept one.
        for (document, tag) in [("d1", Self.tagA), ("d2", Self.tagA), ("d2", Self.tagB), ("d3", Self.tagB)] {
            context.insert(DocumentTagAssignment(volumeId: "vol1", documentId: document, tagId: tag))
        }
        try context.save()
        await DocumentTagAssignment.reconcileTagColumn(
            container: container, pipeline: pipeline, sweepingStaleRows: true)
        #expect(try await column(pipeline, "d1") == Self.a)
        #expect(try await column(pipeline, "d2") == "\(Self.a) \(Self.b)")

        let touched = UserTagAdmin.deleteCascading(doomed, context: context, pipeline: pipeline)

        #expect(touched.map(\.documentId).sorted() == ["d1", "d2"])
        #expect(try await waitForColumn(pipeline, "d1", toBe: nil) == nil)
        #expect(try await waitForColumn(pipeline, "d2", toBe: Self.b) == Self.b)
        #expect(try await column(pipeline, "d3") == Self.b)
        _ = container
    }

    @Test("Deleting a reader's only tag clears its documents, which the sweep's floor would refuse")
    func deletingTheOnlyTagClearsItsDocuments() async throws {
        let (dir, container, context, pipeline) = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let only = UserTag(name: "Only")
        only.id = Self.tagA
        context.insert(only)
        context.insert(DocumentTagAssignment(volumeId: "vol1", documentId: "d1", tagId: Self.tagA))
        try context.save()
        try await pipeline.updateUserTagIds(volumeId: "vol1", documentId: "d1", userTagIds: Self.a)

        UserTagAdmin.deleteCascading(only, context: context, pipeline: pipeline)

        #expect(try await waitForColumn(pipeline, "d1", toBe: nil) == nil)
        #expect(try context.fetch(FetchDescriptor<DocumentTagAssignment>()).isEmpty)
        _ = container
    }

    @Test("Finding the tagged rows walks the partial index, not the table")
    func theRowReaderUsesItsIndex() async throws {
        let (dir, container, _, pipeline) = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(try await pipeline.indexNamesForTesting(onTable: "document_cache")
                    .contains("idx_document_cache_user_tag_ids"))
        let plan = try await pipeline.queryPlanForTesting(IndexingPipeline.documentsWithUserTagIdsSQL)
        #expect(plan.contains("USING INDEX idx_document_cache_user_tag_ids"), "got: \(plan)")
        _ = container
    }

    // MARK: The result rows' chips

    @Test("A result row shows a chip for each stored id the tag list names, and none for any other")
    func chipsNameOnlyKnownTags() {
        let first = UserTag(name: "First")
        first.id = Self.tagA
        let second = UserTag(name: "Second")
        second.id = Self.tagB
        let deleted = "CCCCCCCC-0000-0000-0000-000000000003"
        // The stored order is kept, the deleted tag's id has no chip, and an id stored twice has one.
        #expect(UserTag.chips(for: [Self.b, deleted, Self.a, Self.b], among: [first, second])
                == [UserTagChip(id: Self.b, name: "Second"), UserTagChip(id: Self.a, name: "First")])
        #expect(UserTag.chips(for: [deleted], among: [first, second]).isEmpty)
        #expect(UserTag.chips(for: [Self.a], among: []).isEmpty)
    }

    // MARK: The wiring

    /// The text of each call to `name(` in `source`, from the name to its closing parenthesis.
    private func calls(to name: String, in source: String) -> [String] {
        var found: [String] = []
        var search = source.startIndex..<source.endIndex
        while let hit = source.range(of: name + "(", range: search) {
            var depth = 0
            var end = hit.upperBound
            for index in source[hit.lowerBound...].indices {
                if source[index] == "(" { depth += 1 }
                if source[index] == ")" {
                    depth -= 1
                    if depth == 0 { end = source.index(after: index); break }
                }
            }
            found.append(String(source[hit.lowerBound..<end]))
            search = end..<source.endIndex
        }
        return found
    }

    @Test("The app reconciles at launch and when an import settles, and sweeps at launch only with iCloud off")
    func theAppReconcilesInBothPlaces() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appending(path: "FRUSExplorer/App/FRUSExplorerApp.swift"),
                              encoding: .utf8)
        #expect(text.count > 50_000, "FRUSExplorerApp.swift read back as \(text.count) characters")
        // Comment lines out: the launch pass's own doc comment names the reconcile with its
        // arguments, and a mention is not a call.
        let source = text.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        let reconciles = calls(to: "DocumentTagAssignment.reconcileTagColumn", in: source)
        #expect(reconciles.count == 2, "got \(reconciles.count) calls")
        #expect(reconciles.filter { $0.contains("sweepingStaleRows: true") }.count == 1,
                "one call, the import-settle one, always sweeps")
        #expect(reconciles.filter { $0.contains("sweepingStaleRows: !_containerSetup.cloudKitEnabled") }.count == 1,
                "the launch call sweeps only with iCloud off")
        // The launch pass no longer writes the column itself.
        #expect(calls(to: "pipeline.updateUserTagIds", in: source).isEmpty)
    }
}
