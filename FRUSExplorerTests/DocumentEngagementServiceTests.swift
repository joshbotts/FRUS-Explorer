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

// MARK: - DocumentEngagementServiceTests

/// The per-kind engagement partition behind the coverage map (W-13 session 1).
///
/// The assertions worth knowing about: every count is checked against a fixture where the *wrong*
/// rule would produce a different number, not merely a plausible one. A partition that forgot to
/// intersect with the corpus, one that ranked `collected` above `annotated`, and one that counted
/// a highlight belonging to another project's note all fail here.
///
/// Version history:
///   1.0 — W-13 session 1: initial implementation
@Suite("Document engagement — coverage partition")
struct DocumentEngagementServiceTests {

    /// A store holding every model the gatherers read.
    @MainActor
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: ReadingHistoryEntry.self, ResearchNote.self,
                 DocumentHighlight.self, Collection.self, CollectionEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }

    // MARK: - The arithmetic

    /// **The intersection is the assertion.** The gatherers answer for the whole library, so a note
    /// on a document outside this corpus must not raise its coverage. Without the intersection this
    /// fixture reports 3 of 2 documents worked on — a sentence that cannot be true.
    @Test("Engagement outside the corpus is not counted")
    func intersectsWithTheCorpus() {
        let coverage = DocumentEngagementService.partition(
            corpusKeys: ["v1/d1", "v1/d2"],
            opened: ["v1/d1", "v9/d9"],
            annotated: ["v9/d9"],
            collected: [],
            isOpenedComplete: true)
        #expect(coverage.totalCount == 2)
        #expect(coverage.engagedCount == 1)
        #expect(coverage.openedCount == 1)
        #expect(coverage.annotatedCount == 0)
        #expect(coverage.engagement(for: "v9/d9") == [])
    }

    /// The kinds co-occur, and each is counted in its own column while the document counts once
    /// toward coverage. A type that could hold one kind per document would report 3 engaged here.
    @Test("One document in all three kinds is engaged once and counted three times")
    func kindsCoOccur() {
        let coverage = DocumentEngagementService.partition(
            corpusKeys: ["v1/d1", "v1/d2", "v1/d3"],
            opened: ["v1/d1"], annotated: ["v1/d1"], collected: ["v1/d1"],
            isOpenedComplete: true)
        #expect(coverage.engagedCount == 1)
        #expect(coverage.openedCount == 1)
        #expect(coverage.annotatedCount == 1)
        #expect(coverage.collectedCount == 1)
        #expect(coverage.untouchedCount == 2)
        #expect(coverage.engagement(for: "v1/d1") == [.opened, .annotated, .collected])
    }

    /// The denominator is the corpus, so the untouched remainder is a real number and not a
    /// residue of what happened to be gathered.
    @Test("Untouched is the corpus minus the engaged")
    func untouchedIsTheRemainder() {
        let coverage = DocumentEngagementService.partition(
            corpusKeys: (1...10).map { "v1/d\($0)" },
            opened: ["v1/d1", "v1/d2"], annotated: ["v1/d3"], collected: [],
            isOpenedComplete: true)
        #expect(coverage.engagedCount == 3)
        #expect(coverage.untouchedCount == 7)
        #expect(coverage.totalCount == 10)
    }

    /// **The display rank, pinned in the order it must hold.** Each case names a document engaged
    /// in *several* ways, so a rule that returned the first kind it found, or the last, would give
    /// a different answer for at least one of them.
    @Test("A row shows the most deliberate engagement it has")
    func stateRanking() {
        #expect(DocumentEngagement([]).state == .untouched)
        #expect(DocumentEngagement([.opened]).state == .opened)
        #expect(DocumentEngagement([.opened, .collected]).state == .collected)
        #expect(DocumentEngagement([.opened, .annotated]).state == .annotated)
        #expect(DocumentEngagement([.collected, .annotated]).state == .annotated)
        #expect(DocumentEngagement([.opened, .collected, .annotated]).state == .annotated)
        // The untouched row is the one with no badge, and it is the only one.
        #expect(DocumentEngagement.State.untouched.symbolName == nil)
        for state in DocumentEngagement.State.allCases where state != .untouched {
            #expect(state.symbolName != nil, "\(state) needs a badge")
        }
        // Every state is speakable, untouched included — VoiceOver has no absence to perceive.
        #expect(DocumentEngagement.State.allCases.allSatisfy { !$0.label.isEmpty })
    }

    // MARK: - The sentences

    /// Both numbers, always — the ``WorkingCorpusResolution`` rule. A bare "3 worked on" invites
    /// the reader to supply a denominator they do not have.
    @Test("The coverage sentence states both numbers, and the breakdown defines it")
    func sentences() {
        let coverage = DocumentEngagementService.partition(
            corpusKeys: (1...10).map { "v1/d\($0)" },
            opened: ["v1/d1", "v1/d2"], annotated: ["v1/d3"], collected: ["v1/d4"],
            isOpenedComplete: true)
        #expect(coverage.coverageDescription.contains("4"))
        #expect(coverage.coverageDescription.contains("10"))
        let breakdown = try? #require(coverage.breakdownDescription)
        #expect(breakdown?.contains("2") == true)
        #expect(coverage.loggingCaveat == nil)
    }

    /// An empty corpus says its headline and withholds a breakdown of three zeroes.
    @Test("Nothing engaged means no breakdown line")
    func breakdownIsWithheldWhenNothingIsEngaged() {
        let coverage = DocumentEngagementService.partition(
            corpusKeys: ["v1/d1"], opened: [], annotated: [], collected: [],
            isOpenedComplete: true)
        #expect(coverage.engagedCount == 0)
        #expect(coverage.breakdownDescription == nil)
        #expect(coverage.coverageDescription.contains("0"))
    }

    /// **The caveat is the honesty of the opened column.** Logging off does not zero the count —
    /// rows written before the switch was flipped remain — so the number must ship with the
    /// sentence saying it is a floor.
    @Test("A logging-off partition still counts, and says the count is a floor")
    func loggingOffCarriesTheCaveat() {
        let coverage = DocumentEngagementService.partition(
            corpusKeys: ["v1/d1", "v1/d2"],
            opened: ["v1/d1"], annotated: [], collected: [],
            isOpenedComplete: false)
        #expect(coverage.openedCount == 1, "history already written must still be counted")
        #expect(coverage.isOpenedComplete == false)
        #expect(coverage.loggingCaveat != nil)
    }
}

// MARK: - DocumentEngagementGathererTests

/// The three gatherers, against a real store (W-13 session 1).
///
/// Each fixture holds documents that belong to **another** project as well as this one, because a
/// gatherer that ignored its scope entirely would still pass a fixture where everything belonged
/// to the project under test.
///
/// Version history:
///   1.0 — W-13 session 1: initial implementation
@Suite("Document engagement — gatherers")
struct DocumentEngagementGathererTests {

    private let mine = UUID()
    private let theirs = UUID()

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: ReadingHistoryEntry.self, ResearchNote.self,
                 DocumentHighlight.self, Collection.self, CollectionEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }

    /// A visit belongs to the project that was active when it was recorded, and to no other. The
    /// unscoped read is the whole device — the state a reader with no project sees.
    @Test("Visits are attributed by their own project, and unscoped means every visit")
    @MainActor
    func openedKeysHonourScope() throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(ReadingHistoryEntry(documentId: "d1", volumeId: "v1",
                                           displayTitle: nil, projectId: mine))
        context.insert(ReadingHistoryEntry(documentId: "d2", volumeId: "v1",
                                           displayTitle: nil, projectId: theirs))
        context.insert(ReadingHistoryEntry(documentId: "d3", volumeId: "v1",
                                           displayTitle: nil, projectId: nil))
        // A blank identifier is not a document; it must never become the key "/".
        context.insert(ReadingHistoryEntry(documentId: "", volumeId: "v1",
                                           displayTitle: nil, projectId: mine))
        try context.save()

        #expect(DocumentEngagementService.openedKeys(forProject: mine, in: context) == ["v1/d1"])
        #expect(DocumentEngagementService.openedKeys(forProject: theirs, in: context) == ["v1/d2"])
        #expect(DocumentEngagementService.openedKeys(forProject: nil, in: context)
                == ["v1/d1", "v1/d2", "v1/d3"])
    }

    /// **The highlight join, which is the awkward part of this feature.** `DocumentHighlight`
    /// carries no `projectId` — only an optional `noteId` — so a highlight reaches a project
    /// through its note or not at all. This fixture has one of each kind: a highlight on my note,
    /// one on theirs, and a standalone one no project can claim.
    @Test("Highlights inherit their note's project, and a standalone one belongs to no project")
    @MainActor
    func annotatedKeysJoinHighlightsThroughNotes() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let myNote = ResearchNote(documentId: "d1", volumeId: "v1",
                                  bodyText: "mine", projectIds: [mine])
        let theirNote = ResearchNote(documentId: "d2", volumeId: "v1",
                                     bodyText: "theirs", projectIds: [theirs])
        context.insert(myNote)
        context.insert(theirNote)
        context.insert(DocumentHighlight(volumeId: "v1", documentId: "d3", startOffset: 0,
                                         endOffset: 4, noteId: myNote.id, renderingVersion: "1"))
        context.insert(DocumentHighlight(volumeId: "v1", documentId: "d4", startOffset: 0,
                                         endOffset: 4, noteId: theirNote.id, renderingVersion: "1"))
        context.insert(DocumentHighlight(volumeId: "v1", documentId: "d5", startOffset: 0,
                                         endOffset: 4, noteId: nil, renderingVersion: "1"))
        try context.save()

        // d1 is my note; d3 is the highlight hanging off it. d4 and d5 are not mine.
        #expect(DocumentEngagementService.annotatedKeys(forProject: mine, in: context)
                == ["v1/d1", "v1/d3"])
        #expect(DocumentEngagementService.annotatedKeys(forProject: theirs, in: context)
                == ["v1/d2", "v1/d4"])
        // Unscoped, the standalone highlight is visible — it is a real annotation with no owner.
        #expect(DocumentEngagementService.annotatedKeys(forProject: nil, in: context)
                == ["v1/d1", "v1/d2", "v1/d3", "v1/d4", "v1/d5"])
    }

    /// A collection holds headings and prose beside its documents, and neither is a document read.
    /// Counting them would inflate coverage against a denominator that has no room for them.
    @Test("Only document entries count, and only from collections in scope")
    @MainActor
    func collectedKeysSkipNonDocumentEntries() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let myCollection = Collection(name: "Mine", projectIds: [mine])
        let theirCollection = Collection(name: "Theirs", projectIds: [theirs])
        context.insert(myCollection)
        context.insert(theirCollection)

        func add(_ collection: Collection, _ documentId: String,
                 kind: CollectionEntryKind = .document, order: Int) {
            let row = CollectionEntry(collectionId: collection.id, documentId: documentId,
                                      volumeId: "v1", sortOrder: order)
            row.kind = kind.rawValue
            context.insert(row)
            // The INVERSE, not `collection.documentEntries?.append(row)`. On a freshly-inserted
            // collection that relationship is still `nil`, so the append is a silent no-op and
            // every collected count comes back zero.
            row.collection = collection
        }
        add(myCollection, "d1", order: 0)
        add(myCollection, "d2", kind: .heading, order: 1)
        add(myCollection, "d3", kind: .prose, order: 2)
        add(theirCollection, "d4", order: 0)
        try context.save()

        #expect(DocumentEngagementService.collectedKeys(forProject: mine, in: context) == ["v1/d1"])
        #expect(DocumentEngagementService.collectedKeys(forProject: theirs, in: context) == ["v1/d4"])
        #expect(DocumentEngagementService.collectedKeys(forProject: nil, in: context)
                == ["v1/d1", "v1/d4"])
    }

    /// End to end, through the entry point a view actually calls. The gate is passed explicitly
    /// rather than driven through `UserDefaults.standard`, which no test may mutate.
    @Test("Coverage carries the research-logging gate into the partition")
    @MainActor
    func coverageReadsTheLoggingGate() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(ReadingHistoryEntry(documentId: "d1", volumeId: "v1",
                                           displayTitle: nil, projectId: mine))
        let note = ResearchNote(documentId: "d2", volumeId: "v1", bodyText: "n", projectIds: [mine])
        context.insert(note)
        try context.save()

        let on = await DocumentEngagementService.coverage(
            forCorpusKeys: ["v1/d1", "v1/d2", "v1/d3"], project: mine,
            container: container, isOpenedComplete: true)
        #expect(on.openedCount == 1)
        #expect(on.annotatedCount == 1)
        #expect(on.engagedCount == 2)
        #expect(on.untouchedCount == 1)
        #expect(on.isOpenedComplete)
        #expect(on.loggingCaveat == nil)

        let off = await DocumentEngagementService.coverage(
            forCorpusKeys: ["v1/d1", "v1/d2", "v1/d3"], project: mine,
            container: container, isOpenedComplete: false)
        #expect(off.openedCount == 1, "the gate describes the count; it does not erase it")
        #expect(!off.isOpenedComplete)
        #expect(off.loggingCaveat != nil)
    }
}
