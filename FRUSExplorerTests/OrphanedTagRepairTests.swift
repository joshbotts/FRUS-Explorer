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

        UserTagAdmin.deleteCascading(victim, context: context)

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
}
