// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData
import Testing
@testable import FRUSExplorer

// MARK: - CollectionImportHeadnoteDraftTests (#1999)

/// A `.fruscollection` file names a headnote by its draft's id, and an import opened on its author's
/// own account used to point its entry at the original's draft: editing the copy's headnote deleted the
/// original's, and deleting the copy took them all (#1999). Seen in 1.0 (1861) before the fix, in the Mac
/// check copy at `1.0-release` on 2026-11-27: after the imported copy's headnote was edited, the original's
/// read *No headnote yet*, and its entry still named a draft the store no longer held. The import now gives
/// each such entry a draft of its own, as Duplicate does; a document's own summary stays shared, and an id
/// this account does not hold is kept as the file wrote it.
///
/// Version history:
///   1.0 — L29 (#1999, the import's half): initial implementation
@Suite("A collection file opened on its author's account makes its own headnote drafts (#1999)", .serialized)
@MainActor
struct CollectionImportHeadnoteDraftTests {

    static let volume = "frus1961-63v01"

    /// A saved collection of one document whose headnote is the reader's own draft, as Edit saves one.
    static func authorsCollection(in context: ModelContext, headnote: GeneratedSummary)
        throws -> (Collection, CollectionEntry) {
        let collection = Collection(name: "L29 Original")
        context.insert(collection)
        let entry = CollectionEntry(collectionId: collection.id, documentId: "d1", volumeId: volume, sortOrder: 0)
        entry.collection = collection
        entry.includeHeadnote = true
        context.insert(entry)
        context.insert(headnote)
        entry.headnoteSummaryId = headnote.id
        try context.save()
        return (collection, entry)
    }

    /// `collection` written to a shared file and opened again through the import every path calls.
    static func reimported(_ collection: Collection, in context: ModelContext) throws -> Collection {
        let file = NativeCollectionSerializer.makeFile(from: collection, includeNotes: false) { _ in [] }
        let decoded = try NativeCollectionSerializer.decode(try NativeCollectionSerializer.encode(file))
        let copy = NativeCollectionSerializer.apply(decoded, into: context)
        try context.save()
        return copy
    }

    static func summary(_ id: UUID, in context: ModelContext) throws -> GeneratedSummary? {
        try context.fetch(FetchDescriptor<GeneratedSummary>(predicate: #Predicate { $0.id == id })).first
    }

    @Test("An imported entry whose headnote names a draft on this account gets a draft of its own")
    func importCopiesTheDraft() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let draft = GeneratedSummary(documentId: "d1", volumeId: Self.volume, promptId: UUID(),
                                     responseText: "ORIGINAL headnote written by the author.",
                                     authorship: .userWritten, isHeadnoteDraft: true)
        let (original, entry) = try Self.authorsCollection(in: context, headnote: draft)

        let copy = try Self.reimported(original, in: context)
        let copied = try #require(copy.documentEntries?.first)
        let copiedId = try #require(copied.headnoteSummaryId, "the import dropped the headnote")
        #expect(copiedId != draft.id, "the imported entry names the original's draft, which its edits delete")
        let copiedDraft = try #require(try Self.summary(copiedId, in: context))
        #expect(copiedDraft.isHeadnoteDraft && copiedDraft.authorship == .userWritten)
        #expect(copiedDraft.responseText == "ORIGINAL headnote written by the author.")
        #expect(copiedDraft.documentId == "d1" && copiedDraft.volumeId == Self.volume)

        // What the copy's Edit does to its own draft, and what deleting the copy does: neither reaches the
        // original's headnote.
        GeneratedSummary.deleteHeadnoteDraft(for: copied, in: context)
        copy.deleteWithChildren(in: context)
        try context.save()
        #expect(try Self.summary(draft.id, in: context)?.responseText == "ORIGINAL headnote written by the author.",
                "the original's headnote went with the copy's")
        #expect(entry.headnoteSummaryId == draft.id)
        withExtendedLifetime(container) {}
    }

    @Test("A headnote that names the document's own summary stays shared, and an id this account lacks stays as written")
    func importKeepsSummariesAndUnknownIds() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        // A document summary belongs to the document, not to the entry: Duplicate shares it too.
        let documentSummary = GeneratedSummary(documentId: "d1", volumeId: Self.volume, promptId: UUID(),
                                               responseText: "A summary of the document.")
        let (original, _) = try Self.authorsCollection(in: context, headnote: documentSummary)
        let copy = try Self.reimported(original, in: context)
        #expect(copy.documentEntries?.first?.headnoteSummaryId == documentSummary.id)

        // A colleague's file names a draft of theirs, which this store lacks: kept, so the resolver falls back
        // as before, and nothing is made.
        let elsewhere = UUID()
        original.documentEntries?.first?.headnoteSummaryId = elsewhere
        try context.save()
        let before = try context.fetchCount(FetchDescriptor<GeneratedSummary>())
        let colleagues = try Self.reimported(original, in: context)
        #expect(colleagues.documentEntries?.first?.headnoteSummaryId == elsewhere)
        #expect(try context.fetchCount(FetchDescriptor<GeneratedSummary>()) == before)
        withExtendedLifetime(container) {}
    }
}

// MARK: - CollectionDuplicateSettingsTests (#1996)

/// Duplicate copied a collection's settings by name, and left out *Stamp active project* and *Append the
/// query log* (#1996). The test compares the two collections as the research data export records them,
/// every stored field, so a setting added later and left out of Duplicate fails here once the export
/// carries it. (The walk over the schema itself is L43's, with what a snapshot must not copy.)
///
/// Version history:
///   1.0 — L29 (#1996): initial implementation
@Suite("Duplicate copies every setting of a collection (#1996)", .serialized)
@MainActor
struct CollectionDuplicateSettingsTests {

    /// A collection with every setting away from its default, and one entry of each kind.
    static func everySetting(in context: ModelContext) -> Collection {
        let collection = Collection(name: "Everything", note: "A note.", projectIds: [UUID()])
        collection.subtitle = "A reader"
        collection.authorLine = "A. Researcher"
        collection.introductionText = "An introduction."
        collection.introductionRichText = Data("{\\rtf1 An introduction.}".utf8)
        collection.includeColophon = true
        collection.includeProjectProvenance = true
        collection.includeMethodAppendix = true
        collection.savedSearchId = UUID()
        collection.defaultBodyDepth = "index"
        collection.effectiveIncludeFootnotes = false
        collection.effectiveIncludeSourceNote = true
        collection.tocStyle = "headerAndDateline"
        collection.applyHighlights = true
        collection.includeNotes = false
        collection.includeWordCloud = true
        collection.defaultIncludeHeadnote = true
        collection.summaryPromptId = UUID()
        context.insert(collection)
        let kinds: [CollectionEntryKind] = [.heading, .document, .prose, .excerpt, .generated]
        for (index, kind) in kinds.enumerated() {
            let entry = CollectionEntry(collectionId: collection.id, documentId: kind == .document ? "d1" : "",
                                        volumeId: kind == .document ? "frus1961-63v01" : "", sortOrder: index,
                                        researchNoteId: UUID(), selectedNoteIds: [UUID()])
            entry.entryKind = kind
            entry.collection = collection
            entry.text = "Text \(index)"
            entry.level = 2
            entry.titleOverride = "Title \(index)"
            entry.bodyDepthOverride = "summaryOnly"
            entry.applyHighlightsOverride = true
            entry.includeNotesOverride = false
            entry.includeSourceNoteOverride = true
            entry.includeFootnotesOverride = false
            entry.summaryPromptIdOverride = UUID()
            entry.selectedHighlightIds = [UUID()]
            entry.includeRelatedDocuments = true
            entry.includeHeadnote = true
            entry.headnoteSummaryId = UUID()
            entry.excerptStart = 3
            entry.excerptEnd = 9
            entry.excerptRenderingVersion = "v1"
            entry.excerptColorTag = "green"
            entry.generatedBlockType = kind == .generated ? CollectionGeneratedBlockType.chronology.rawValue : nil
            context.insert(entry)
        }
        return collection
    }

    /// The collection's values with what a copy makes new left out: its id, its name, its dates.
    static func settings(of collection: Collection) -> CollectionExport {
        var value = CollectionExport(collection, entries: [])
        value.id = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        value.name = ""
        value.createdAt = nil
        value.lastModified = nil
        return value
    }

    /// An entry's values with what a copy makes new left out: its id, its collection's id, its dates.
    static func values(of entry: CollectionEntry) -> CollectionEntryExport {
        var value = CollectionEntryExport(entry)
        value.id = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        value.createdAt = nil
        value.lastModified = nil
        return value
    }

    @Test("A duplicate of a collection with every setting changed equals it but for its id, name and dates")
    func duplicateCopiesEverySetting() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let source = Self.everySetting(in: context)
        try context.save()
        let copy = source.duplicate(in: context)
        try context.save()

        #expect(copy.includeProjectProvenance && copy.includeMethodAppendix,
                "Duplicate dropped Stamp active project or Append the query log")
        #expect(Self.settings(of: copy) == Self.settings(of: source))
        #expect(copy.id != source.id && copy.name == "Everything copy")
        let sourceEntries = CollectionEntryOrdering.modelOrder(of: source)
        let copyEntries = CollectionEntryOrdering.modelOrder(of: copy)
        #expect(copyEntries.map(Self.values) == sourceEntries.map(Self.values))
        #expect(Set(copyEntries.map(\.id)).isDisjoint(with: sourceEntries.map(\.id)))
        withExtendedLifetime(container) {}
    }
}

// MARK: - SmartCollectionSnapshotInsertTests (#1996, J39)

/// What Create Static Snapshot inserts: every setting of the smart collection but its link, and its own
/// apparatus blocks in their places around the search's documents (the design's §4.5; the third review's
/// J39). Until L29 the snapshot carried the composition alone and no block. The kit's
/// `CollectionValuesTests.snapshotCarriesSettingsAndBlocks` holds the values; this holds what the app's
/// `create(from:results:into:)` makes of them.
///
/// Version history:
///   1.0 — L29 (#1996, J39): initial implementation
@Suite("Create Static Snapshot inserts every setting and the smart collection's own blocks (#1996, J39)", .serialized)
@MainActor
struct SmartCollectionSnapshotInsertTests {

    @Test("The snapshot inserted holds every setting but the link, and the blocks before and after the results")
    func snapshotInsertsSettingsAndBlocks() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        // A smart collection's own entries are its blocks: here a Chronology among four entries from before its
        // link, which stay behind, and a Bibliography.
        let smart = CollectionDuplicateSettingsTests.everySetting(in: context)
        let back = CollectionEntry(collectionId: smart.id, documentId: "", volumeId: "", sortOrder: 9)
        back.entryKind = .generated
        back.generatedBlockType = CollectionGeneratedBlockType.bibliography.rawValue
        back.collection = smart
        context.insert(back)
        // A Persons Index the reader deleted a moment ago, before a save processed it: still listed, never carried.
        let deleted = CollectionEntry(collectionId: smart.id, documentId: "", volumeId: "", sortOrder: 10)
        deleted.entryKind = .generated
        deleted.generatedBlockType = CollectionGeneratedBlockType.personsIndex.rawValue
        deleted.collection = smart
        context.insert(deleted)
        try context.save()
        context.delete(deleted)

        let snapshot = SmartCollectionSnapshot.create(from: smart, results: [("d8", "v1"), ("d2", "v2")],
                                                      into: context)
        try context.save()

        var expected = CollectionDuplicateSettingsTests.settings(of: smart)
        expected.savedSearchId = nil
        #expect(CollectionDuplicateSettingsTests.settings(of: snapshot) == expected)
        #expect(snapshot.savedSearchId == nil && snapshot.name == "Everything (Snapshot)")
        let entries = CollectionEntryOrdering.modelOrder(of: snapshot)
        #expect(entries.map { $0.generatedBlockType ?? "\($0.volumeId)/\($0.documentId)" }
                == [CollectionGeneratedBlockType.chronology.rawValue, "v1/d8", "v2/d2",
                    CollectionGeneratedBlockType.bibliography.rawValue])
        #expect(entries.map(\.sortOrder) == [0, 1, 2, 3])
        #expect(entries.filter { $0.entryKind == .generated }.count == 2)
        withExtendedLifetime(container) {}
    }
}
