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

// MARK: - ResearchDocumentAggregationTests

/// `ResearchView`'s document aggregation, now six sources wide (R-5 P2).
///
/// The design's §5.6 counted four sources — notes, tags, collections, highlights — and P2 adds
/// the two a correction is most likely to supersede: a `GeneratedSummary` is derived from the
/// text, and an `ArchiveVisitDocument`'s plan from the source note. Each case here plants a
/// document carrying ONLY one source, because that is the document the pre-P2 view never listed.
/// The set is also what the storage hubs' post-update summary intersects with, so it is pinned
/// once here for both.
///
/// Version history:
///   1.0 — R-5 P2: initial implementation
///   1.1 — R-5 P3b-4: the collections source admits excerpt entries (design Q-7 b)
@Suite("Research aggregation — the six annotation sources")
struct ResearchDocumentAggregationTests {

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: ResearchNote.self, DocumentTagAssignment.self, Collection.self, CollectionEntry.self,
                 DocumentHighlight.self, GeneratedSummary.self,
                 ArchiveVisitPlan.self, ArchiveVisitDocument.self, ArchiveVisitTarget.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }

    /// One document per source, none overlapping, so each key's presence names its source.
    @Test("Each of the six sources contributes its own document")
    @MainActor
    func eachSourceContributes() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let note = ResearchNote(documentId: "d1", volumeId: "v1", bodyText: "a note", projectIds: [])
        context.insert(note)
        context.insert(DocumentTagAssignment(volumeId: "v1", documentId: "d2", tagId: UUID()))
        let collection = Collection(name: "C", projectIds: [])
        context.insert(collection)
        let entry = CollectionEntry(collectionId: collection.id, documentId: "d3", volumeId: "v1", sortOrder: 0)
        entry.kind = CollectionEntryKind.document.rawValue
        context.insert(entry)
        entry.collection = collection    // the inverse; `documentEntries?.append` no-ops on a fresh collection
        context.insert(DocumentHighlight(volumeId: "v1", documentId: "d4", startOffset: 0, endOffset: 3,
                                         noteId: nil, renderingVersion: "1"))
        context.insert(GeneratedSummary(documentId: "d5", volumeId: "v1", promptId: UUID(), responseText: "sum"))
        let plan = ArchiveVisitPlan(name: "Trip")
        context.insert(plan)
        context.insert(ArchiveVisitDocument(planId: plan.id, documentKey: "v1/d6"))
        try context.save()

        let keys = ResearchDocumentAggregation.annotatedKeys(
            notes: try context.fetch(FetchDescriptor<ResearchNote>()),
            tagAssignments: try context.fetch(FetchDescriptor<DocumentTagAssignment>()),
            collections: try context.fetch(FetchDescriptor<Collection>()),
            highlights: try context.fetch(FetchDescriptor<DocumentHighlight>()),
            summaries: try context.fetch(FetchDescriptor<GeneratedSummary>()),
            visitDocuments: try context.fetch(FetchDescriptor<ArchiveVisitDocument>()))
        #expect(keys == ["v1/d1", "v1/d2", "v1/d3", "v1/d4", "v1/d5", "v1/d6"])
    }

    /// R-5 P3b-5 (design Q-11 b). The row is a way IN to a note, not a place to read it, so it
    /// prints the note's first line and never its body.
    @Test("A note row shows its first line, trimmed, and says so when there is nothing to show")
    func noteRowTitles() {
        func note(_ body: String) -> ResearchNote {
            ResearchNote(documentId: "d1", volumeId: "v1", bodyText: body, projectIds: [])
        }
        #expect(DocumentChangeReviewSheet.noteRowTitle(note("Ambassador's read of the meeting"))
                == "Ambassador's read of the meeting")
        // Only the FIRST line: a long note must not push every other row off the sheet.
        #expect(DocumentChangeReviewSheet.noteRowTitle(note("First line\nSecond line\nThird"))
                == "First line")
        // Leading whitespace is the ordinary shape of a pasted note.
        #expect(DocumentChangeReviewSheet.noteRowTitle(note("   indented\nmore")) == "indented")
        // An empty note is reachable: the editor saves a row before the reader types.
        let placeholder = DocumentChangeReviewSheet.noteRowTitle(note(""))
        #expect(placeholder == "Open note")
        #expect(DocumentChangeReviewSheet.noteRowTitle(note("\n\n")) == placeholder)
        // The first line with something IN it, not literally the first line: a note that opens on a
        // blank line still has a first line worth showing, and printing the placeholder for it
        // would hide a note that is not empty at all.
        #expect(DocumentChangeReviewSheet.noteRowTitle(note("   \n x")) == "x")
        #expect(DocumentChangeReviewSheet.noteRowTitle(note("\n\nAmbassador's read")) == "Ambassador's read")
        // CRLF. `CharacterSet.whitespaces` is space and tab only, so trimming with it would leave a
        // carriage return here and print an invisible control character as the row's title.
        #expect(DocumentChangeReviewSheet.noteRowTitle(note("\r\n\r\nAmbassador's read\r\nmore"))
                == "Ambassador's read")
        #expect(DocumentChangeReviewSheet.noteRowTitle(note("\r\n\r\n")) == placeholder)
    }

    /// Design Q-7 (b). The excerpt is the annotation whose entire content is a verbatim copy of
    /// the text an update corrects, and before P3b-4 a document carrying only one was absent from
    /// "All Research Documents" and from "Changed by an update" — while the SAME document appeared
    /// under its collection in the same sidebar, because that grouping counts every entry with a
    /// document id.
    @Test("An excerpt-only document is annotated; a heading, prose, generated or future entry is not")
    @MainActor
    func excerptEntriesCount() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let collection = Collection(name: "C", projectIds: [])
        context.insert(collection)

        // Every non-excerpt kind is planted WITH a document id, so the test proves the kind rule
        // rather than the empty-id guard that `blankIdsAreSkipped` already covers.
        func entry(_ kind: String, _ documentId: String, order: Int) {
            let e = CollectionEntry(collectionId: collection.id, documentId: documentId,
                                    volumeId: "v1", sortOrder: order)
            e.kind = kind
            context.insert(e)
            e.collection = collection
        }
        entry(CollectionEntryKind.document.rawValue, "d1", order: 0)
        entry(CollectionEntryKind.excerpt.rawValue, "d2", order: 1)
        entry(CollectionEntryKind.heading.rawValue, "d3", order: 2)
        entry(CollectionEntryKind.prose.rawValue, "d4", order: 3)
        entry(CollectionEntryKind.generated.rawValue, "d5", order: 4)
        entry("someKindAFutureBuildWrote", "d6", order: 5)
        try context.save()

        let keys = ResearchDocumentAggregation.annotatedKeys(
            notes: [], tagAssignments: [],
            collections: try context.fetch(FetchDescriptor<Collection>()),
            highlights: [], summaries: [], visitDocuments: [])
        #expect(keys == ["v1/d1", "v1/d2"])
    }

    /// The Research sidebar's per-collection number. It must equal the length of the list the row
    /// opens, which is why it is a set of documents and not a count of entries: the old
    /// `documentEntries.count` counted a heading and a prose block as documents, and after P3b-4
    /// would additionally have counted an excerpt and its own document entry as two.
    @Test("The sidebar count is distinct documents, not entries")
    @MainActor
    func sidebarCountIsDistinctDocuments() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let collection = Collection(name: "C", projectIds: [])
        context.insert(collection)
        func entry(_ kind: CollectionEntryKind, _ documentId: String, _ volumeId: String = "v1", order: Int) {
            let e = CollectionEntry(collectionId: collection.id, documentId: documentId,
                                    volumeId: volumeId, sortOrder: order)
            e.kind = kind.rawValue
            context.insert(e)
            e.collection = collection
        }
        entry(.document, "d1", order: 0)
        entry(.document, "d2", order: 1)
        // The same document, quoted twice and also present as a document entry: ONE document.
        entry(.excerpt, "d2", order: 2)
        entry(.excerpt, "d2", order: 3)
        // A document reached only by a quotation still counts.
        entry(.excerpt, "d3", order: 4)
        // Structure carries no document even when the ids are filled in.
        entry(.heading, "d4", order: 5)
        entry(.prose, "d5", order: 6)
        entry(.generated, "d6", order: 7)
        // The same document id in a different volume is a different document.
        entry(.document, "d1", "v2", order: 8)
        try context.save()

        let entries = try #require(try context.fetch(FetchDescriptor<Collection>()).first?.documentEntries)
        #expect(entries.count == 9, "the fixture must plant every entry, or the count proves nothing")
        let keys = ResearchDocumentAggregation.distinctDocumentKeys(in: entries)
        #expect(keys == ["v1/d1", "v1/d2", "v1/d3", "v2/d1"])
        #expect(keys.count == 4, "nine entries, four documents")
    }

    /// The rule itself, so the three engagement consumers that must NOT widen have something to
    /// point at: they test `.document` directly and never call this.
    @Test("countsAsAnnotation admits document and excerpt, and refuses every other kind by name")
    func countsAsAnnotationVocabulary() {
        #expect(ResearchDocumentAggregation.countsAsAnnotation(CollectionEntryKind.document.rawValue))
        #expect(ResearchDocumentAggregation.countsAsAnnotation(CollectionEntryKind.excerpt.rawValue))
        for kind in [CollectionEntryKind.heading, .prose, .generated, .unrecognized] {
            #expect(!ResearchDocumentAggregation.countsAsAnnotation(kind.rawValue),
                    "\(kind.rawValue) must not put a document into the reader's research")
        }
        #expect(!ResearchDocumentAggregation.countsAsAnnotation(""))
        #expect(!ResearchDocumentAggregation.countsAsAnnotation("someKindAFutureBuildWrote"))
    }

    @Test("A summary-only document and a visit-plan-only document are the two P2 adds")
    func theTwoAdds() {
        let summaries = [GeneratedSummary(documentId: "d5", volumeId: "v1", promptId: UUID(), responseText: "s")]
        let visits = [ArchiveVisitDocument(planId: UUID(), documentKey: "v2/d9")]
        let withBoth = ResearchDocumentAggregation.annotatedKeys(
            notes: [], tagAssignments: [], collections: [], highlights: [],
            summaries: summaries, visitDocuments: visits)
        #expect(withBoth == ["v1/d5", "v2/d9"])
        let withoutEither = ResearchDocumentAggregation.annotatedKeys(
            notes: [], tagAssignments: [], collections: [], highlights: [], summaries: [], visitDocuments: [])
        #expect(withoutEither.isEmpty)
    }

    @Test("Blank ids never mint a key")
    func blankIdsAreSkipped() {
        let keys = ResearchDocumentAggregation.annotatedKeys(
            notes: [ResearchNote(documentId: "", volumeId: "v1", bodyText: "x", projectIds: [])],
            tagAssignments: [DocumentTagAssignment(volumeId: "", documentId: "d1", tagId: UUID())],
            collections: [], highlights: [],
            summaries: [GeneratedSummary(documentId: "d1", volumeId: "", promptId: UUID(), responseText: "s")],
            visitDocuments: [ArchiveVisitDocument(planId: UUID(), documentKey: "")])
        #expect(keys.isEmpty)
    }

    /// The row's sentence per kind — the three the index writes, and nothing for one it does not.
    @Test("changeLine names each kind and hedges only the body kind")
    func changeLines() throws {
        func rev(_ kind: String?) -> IndexingPipeline.DocumentRevision {
            .init(volumeId: "v1", documentId: "d1", contentHash: "c", bodyHash: "b",
                  changedAt: "2026-09-03T00:00:00Z", changeKind: kind, reviewedAt: nil)
        }
        let body = try #require(ResearchDocumentAggregation.changeLine(for: rev("body")))
        let apparatus = try #require(ResearchDocumentAggregation.changeLine(for: rev("apparatus")))
        let vanished = try #require(ResearchDocumentAggregation.changeLine(for: rev("vanished")))
        #expect(body.hasPrefix("Text changed") && body.contains("may have moved"))
        #expect(apparatus.hasPrefix("Footnotes, source note, or heading changed") && apparatus.contains("the text did not"))
        #expect(vanished.contains("No longer in the volume"))
        #expect(ResearchDocumentAggregation.changeLine(for: rev(nil)) == nil)
        #expect(ResearchDocumentAggregation.changeLine(for: rev("renumbered")) == nil)
    }

    /// Design Q-8: a headnote draft is collection-private and excluded from every carousel, so it
    /// must not make a document "annotated" by itself, nor count as one of its summaries.
    @Test("Headnote drafts neither annotate a document nor count as its summaries")
    func draftsAreExcluded() {
        let draft = GeneratedSummary(documentId: "d7", volumeId: "v1", promptId: UUID(), responseText: "own words",
                                     isHeadnoteDraft: true)
        let live = GeneratedSummary(documentId: "d8", volumeId: "v1", promptId: UUID(), responseText: "ai")
        let keys = ResearchDocumentAggregation.annotatedKeys(
            notes: [], tagAssignments: [], collections: [], highlights: [],
            summaries: [draft, live], visitDocuments: [])
        #expect(keys == ["v1/d8"])
        let counts = ResearchDocumentAggregation.summaryCounts([draft, live, live])
        #expect(counts == ["v1/d8": 2])
    }

    /// Design Q-11 (h): a vanished document routes to the review sheet whether or not its change
    /// has been reviewed — vanished-ness is a fact about the volume, review state is not. The
    /// first version keyed on the unreviewed row and lost the route the moment Mark Reviewed ran.
    @Test("rowDestination: vanished routes to the sheet regardless of review state; everything else opens the document")
    func rowDestination() {
        func rev(_ kind: String?, reviewed: Bool = false) -> IndexingPipeline.DocumentRevision {
            .init(volumeId: "v1", documentId: "d1", contentHash: "c", bodyHash: "b",
                  changedAt: "2026-09-03T00:00:00Z", changeKind: kind, reviewedAt: reviewed ? "2026-09-03T01:00:00Z" : nil)
        }
        #expect(ResearchDocumentAggregation.rowDestination(revision: rev("vanished"), isVanished: true) == .reviewSheet)
        #expect(ResearchDocumentAggregation.rowDestination(revision: nil, isVanished: true) == .reviewSheet)
        #expect(ResearchDocumentAggregation.rowDestination(revision: rev("vanished", reviewed: true), isVanished: true) == .reviewSheet)
        #expect(ResearchDocumentAggregation.rowDestination(revision: rev("body"), isVanished: false) == .document)
        #expect(ResearchDocumentAggregation.rowDestination(revision: rev("apparatus"), isVanished: false) == .document)
        #expect(ResearchDocumentAggregation.rowDestination(revision: nil, isVanished: false) == .document)
    }
}
