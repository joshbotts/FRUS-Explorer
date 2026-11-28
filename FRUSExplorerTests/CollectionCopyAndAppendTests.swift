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
/// **Since L58 the file carries a headnote as its text** (decision 166) and no longer names its draft, so a file the
/// app writes now makes its own draft from the text on every import. A file 1.0 wrote still names a draft by its id,
/// and the import still copies it where it resolves: the id path is tested on such a file (`asOneZeroWrote`).
///
/// Version history:
///   1.0 — L29 (#1999, the import's half): initial implementation
///   1.1 — L58: the file carries the headnote as its text; the id path is held on a file as 1.0 wrote it
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

    /// `collection` written to a shared file and opened again through the import every path calls: the file this
    /// build writes, or, with `asOneZeroWrote`, the file 1.0 wrote, which names each headnote by its summary's id and
    /// carries none of its text (`NativeCollectionFormat.swift` before L58).
    static func reimported(_ collection: Collection, in context: ModelContext,
                           asOneZeroWrote: Bool = false) throws -> Collection {
        var file = NativeCollectionSerializer.makeFile(from: collection, includeNotes: false) { _ in [] }
        if asOneZeroWrote {
            let entries = (collection.documentEntries ?? []).sorted { $0.sortOrder < $1.sortOrder }
            for index in file.entries.indices where index < entries.count {
                file.entries[index].headnote = nil
                file.entries[index].headnoteSummaryId = entries[index].headnoteSummaryId
            }
        }
        let decoded = try NativeCollectionSerializer.decode(try NativeCollectionSerializer.encode(file))
        let copy = NativeCollectionSerializer.apply(decoded, into: context)
        try context.save()
        return copy
    }

    static func summary(_ id: UUID, in context: ModelContext) throws -> GeneratedSummary? {
        try context.fetch(FetchDescriptor<GeneratedSummary>(predicate: #Predicate { $0.id == id })).first
    }

    @Test("An imported entry whose headnote names a draft on this account gets a draft of its own",
          arguments: [false, true])
    func importCopiesTheDraft(asOneZeroWrote: Bool) throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let draft = GeneratedSummary(documentId: "d1", volumeId: Self.volume, promptId: UUID(),
                                     responseText: "ORIGINAL headnote written by the author.",
                                     authorship: .userWritten, isHeadnoteDraft: true)
        let (original, entry) = try Self.authorsCollection(in: context, headnote: draft)

        // This build's file carries the text, and 1.0's the id: either way the copy's draft is its own.
        let copy = try Self.reimported(original, in: context, asOneZeroWrote: asOneZeroWrote)
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

    @Test("In a file 1.0 wrote, a headnote that names the document's own summary stays shared, and an id this account lacks stays as written")
    func importKeepsSummariesAndUnknownIds() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        // A document summary belongs to the document, not to the entry: Duplicate shares it too.
        let documentSummary = GeneratedSummary(documentId: "d1", volumeId: Self.volume, promptId: UUID(),
                                               responseText: "A summary of the document.")
        let (original, _) = try Self.authorsCollection(in: context, headnote: documentSummary)
        let copy = try Self.reimported(original, in: context, asOneZeroWrote: true)
        #expect(copy.documentEntries?.first?.headnoteSummaryId == documentSummary.id)

        // A colleague's file names a draft of theirs, which this store lacks: kept, so the resolver falls back
        // as before, and nothing is made.
        let elsewhere = UUID()
        original.documentEntries?.first?.headnoteSummaryId = elsewhere
        try context.save()
        let before = try context.fetchCount(FetchDescriptor<GeneratedSummary>())
        let colleagues = try Self.reimported(original, in: context, asOneZeroWrote: true)
        #expect(colleagues.documentEntries?.first?.headnoteSummaryId == elsewhere)
        #expect(try context.fetchCount(FetchDescriptor<GeneratedSummary>()) == before)

        // The file this build writes carries the headnote the document prints as its text, the document's own
        // summary here, and the import makes a draft of its own from it (L58; decision 166).
        let current = try Self.reimported(original, in: context)
        let currentId = try #require(current.documentEntries?.first?.headnoteSummaryId)
        #expect(currentId != documentSummary.id && currentId != elsewhere)
        let made = try #require(try Self.summary(currentId, in: context))
        #expect(made.isHeadnoteDraft && made.responseText == "A summary of the document." && made.authorship == .aiGenerated)
        #expect(made.writerName == nil, "Apple Intelligence's headnote names no person")
        withExtendedLifetime(container) {}
    }

    /// L58 (decisions 166, 193 and 194): a headnote travels as its text with its writer's name, Off as Off, and every
    /// import makes a draft of its own, so a recipient's export names the sender, and two imports of one file share
    /// nothing with each other or with the original.
    @Test("A file carries a headnote as its text and its writer, Off as Off; each import makes its own draft")
    func headnoteTravelsAsItsText() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let draft = GeneratedSummary(documentId: "d1", volumeId: Self.volume,
                                     promptId: GeneratedSummaryExport.headnoteDraftPromptId,
                                     responseText: "Jane's headnote.", authorship: .aiEdited,
                                     isHeadnoteDraft: true, writerName: "Jane Doe")
        let (original, _) = try Self.authorsCollection(in: context, headnote: draft)
        original.defaultIncludeHeadnote = true
        original.authorLine = "Jane Doe"
        // A second document switched Off, with a draft of its own that must not travel (decision 193).
        let off = CollectionEntry(collectionId: original.id, documentId: "d2", volumeId: Self.volume, sortOrder: 1)
        off.collection = original
        off.includeHeadnote = false
        context.insert(off)
        let abandoned = GeneratedSummary(documentId: "d2", volumeId: Self.volume,
                                         promptId: GeneratedSummaryExport.headnoteDraftPromptId,
                                         responseText: "An abandoned draft.", authorship: .userWritten,
                                         isHeadnoteDraft: true)
        context.insert(abandoned)
        off.headnoteSummaryId = abandoned.id
        try context.save()

        let file = NativeCollectionSerializer.makeFile(from: original, includeNotes: false) { _ in [] }
        #expect(file.entries[0].headnote == FRUSCollectionFile.Headnote(text: "Jane's headnote.", format: "general",
                                                                        authorship: "aiEdited", writerName: "Jane Doe"))
        #expect(file.entries[1].includeHeadnote == false && file.entries[1].headnote == nil)
        let json = String(decoding: try NativeCollectionSerializer.encode(file), as: UTF8.self)
        #expect(!json.contains("An abandoned draft.") && !json.contains(draft.id.uuidString))

        let first = try Self.reimported(original, in: context)
        let second = try Self.reimported(original, in: context)
        let firstEntries = (first.documentEntries ?? []).sorted { $0.sortOrder < $1.sortOrder }
        let secondEntries = (second.documentEntries ?? []).sorted { $0.sortOrder < $1.sortOrder }
        let firstId = try #require(firstEntries.first?.headnoteSummaryId)
        let secondId = try #require(secondEntries.first?.headnoteSummaryId)
        #expect(Set([firstId, secondId, draft.id]).count == 3, "each import's draft is its own")
        let made = try #require(try Self.summary(firstId, in: context))
        #expect(made.responseText == "Jane's headnote." && made.authorship == .aiEdited && made.isHeadnoteDraft)
        #expect(made.writerName == "Jane Doe", "the sender's name stays on the sender's headnote")
        #expect(firstEntries.last?.includeHeadnote == false, "Off arrives Off (J6)")
        #expect(firstEntries.last?.headnoteSummaryId == nil)

        // The recipient renames the copy's author line: the sender's headnote keeps the sender's name.
        first.authorLine = "The Recipient"
        #expect(CollectionHeadnoteWriter(authorship: made.authorship ?? .aiGenerated, storedName: made.writerName,
                                         authorLine: first.authorLine) == .personFromDraft(name: "Jane Doe"))
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
        // L43: the collection's own facts.
        collection.citationStyle = CitationStyle.turabian.rawValue
        collection.opening = CollectionDocumentPlan.Opening.volumeHeading.rawValue
        collection.labelsJSON = #"{"contents":"Documents","marginalia":"A later build's"}"#
        collection.defaultIncludeRelatedDocuments = true
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
            // L43: an entry's own facts.
            entry.dateLine = "Moscow, 22 February 1946"
            entry.headnoteDefault = false
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

// MARK: - CollectionAppendBeforeBackMatterTests (#1995)

/// An entry added to a collection used to take one past the highest position, so once a template had placed
/// a Bibliography at the end, every document, passage, heading and note block added afterwards was listed
/// and printed after it (#1995). Each append now lands ahead of the run of apparatus blocks that ends the
/// collection, and leaves room there, so an append from another device that has not seen this one's lands
/// ahead of them too.
///
/// The tests call the append functions the picker, the reader and both editors call, and follow the model
/// as an open editor does (`CollectionEntryOrdering.reconciled`) where an append came from outside it.
///
/// Version history:
///   1.0 — L29 (#1995): initial implementation
@Suite("An entry added to a collection lands before its back matter (#1995)", .serialized)
@MainActor
struct CollectionAppendBeforeBackMatterTests {

    static let volume = "frus1961-63v11"

    /// A saved collection of `documents` followed by `blocks`, numbered as an editor numbers its outline
    /// after a template places them, and the outline an open editor holds.
    static func collection(_ documents: [String], blocks: [CollectionGeneratedBlockType],
                           in context: ModelContext) throws -> (Collection, [CollectionEntry]) {
        let collection = Collection(name: "Ends in apparatus")
        context.insert(collection)
        var outline: [CollectionEntry] = []
        CollectionDocumentDiscovery.appendEntries(documents.map { (documentId: $0, volumeId: volume) },
                                                  collection: collection, sortedEntries: &outline,
                                                  modelContext: context)
        for type in blocks {
            let block = CollectionEntry(collectionId: collection.id, documentId: "", volumeId: "", sortOrder: 0)
            block.entryKind = .generated
            block.generatedBlockType = type.rawValue
            block.collection = collection
            context.insert(block)
            switch type.defaultPosition {
            case .frontMatter: outline.insert(block, at: 0)
            case .backMatter: outline.append(block)
            }
        }
        CollectionEntryOrdering.renumber(outline, in: collection)
        try context.save()
        return (collection, outline)
    }

    /// What an entry reads as in the order: its block type, its document, or its kind and text.
    static func label(_ entry: CollectionEntry) -> String {
        switch entry.entryKind {
        case .generated: return entry.generatedBlockType ?? "?"
        case .document: return entry.documentId
        default: return "\(entry.kind):\(entry.text ?? "")"
        }
    }

    static func capture(_ documentId: String) -> CollectionExcerptCapture {
        CollectionExcerptCapture(text: "A passage.", volumeId: volume, documentId: documentId, start: 0, end: 10,
                                 renderingVersion: nil, colorTag: nil)
    }

    @Test("A document, a heading, a note block and a passage added to a collection that ends in two blocks are each ahead of both, in the order added")
    func appendsLandAheadOfTheBackMatter() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let (collection, opened) = try Self.collection(["d1", "d2"], blocks: [.bibliography, .personsIndex],
                                                       in: context)
        var outline = opened

        // From the reader, with the editor open: the editor follows the model.
        CollectionDocumentDiscovery.appendToCollection(documentId: "d3", volumeId: Self.volume,
                                                       collection: collection, modelContext: context)
        outline = CollectionEntryOrdering.reconciled(outline, with: collection) ?? outline
        // From the editor: a heading and a note block, each numbered after as the editors do.
        for kind in [CollectionEntryKind.heading, .prose] {
            let block = try #require(CollectionEntryOrdering.appendBlock(kind: kind, to: collection,
                                                                         outline: &outline, modelContext: context))
            block.text = kind == .heading ? "Part II" : "A note"
            CollectionEntryOrdering.renumber(outline, in: collection)
        }
        // A passage from the reader, then the editor's Add Documents.
        CollectionExcerpts.appendToCollection(Self.capture("d1"), collection: collection, modelContext: context)
        outline = CollectionEntryOrdering.reconciled(outline, with: collection) ?? outline
        CollectionDocumentDiscovery.appendEntries([(documentId: "d4", volumeId: Self.volume)],
                                                  collection: collection, sortedEntries: &outline,
                                                  modelContext: context)
        try context.save()

        let expected = ["d1", "d2", "d3", "heading:Part II", "prose:A note", "excerpt:A passage.", "d4",
                        "bibliography", "personsIndex"]
        #expect(CollectionEntryOrdering.modelOrder(of: collection).map(Self.label) == expected)
        #expect(outline.map(Self.label) == expected, "the editor's outline does not list what the model holds")
        let positions = (collection.documentEntries ?? []).map(\.sortOrder)
        #expect(Set(positions).count == positions.count, "two entries share a position: \(positions.sorted())")
        withExtendedLifetime(container) {}
    }

    @Test("A Chronology a template put at the head stays ahead: a document added goes after it, before the back matter")
    func frontMatterStaysAhead() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let (collection, _) = try Self.collection([], blocks: [.chronology, .bibliography], in: context)
        CollectionDocumentDiscovery.appendToCollection(documentId: "d1", volumeId: Self.volume,
                                                       collection: collection, modelContext: context)
        try context.save()
        #expect(CollectionEntryOrdering.modelOrder(of: collection).map(Self.label)
                == ["chronology", "d1", "bibliography"])

        // A collection whose last entry is not a block takes an append at its end, as before.
        let (plain, _) = try Self.collection(["d1"], blocks: [.chronology], in: context)
        CollectionDocumentDiscovery.appendToCollection(documentId: "d2", volumeId: Self.volume,
                                                       collection: plain, modelContext: context)
        #expect(CollectionEntryOrdering.modelOrder(of: plain).map(Self.label) == ["chronology", "d1", "d2"])
        withExtendedLifetime(container) {}
    }

    /// Two devices that append to one collection before either has synced: each writes its own entries, and a
    /// block's position is whichever device's write CloudKit keeps (last writer wins, per record). Each device's
    /// store here is a container of its own holding the same records, and the merge is taken both ways.
    @Test("Two appends from two devices that have not seen each other still end ahead of the blocks")
    func twoDevicesAppendAheadOfTheBlocks() throws {
        let collectionId = UUID()
        let ids = (0..<4).map { _ in UUID() }
        func device() throws -> (ModelContainer, Collection) {
            let container = try ModelContainer.makeTestContainer()
            let context = container.mainContext
            let collection = Collection(name: "Shared")
            collection.id = collectionId
            context.insert(collection)
            for (index, label) in ["d1", "d2", "bibliography", "personsIndex"].enumerated() {
                let isBlock = index >= 2
                let entry = CollectionEntry(collectionId: collectionId, documentId: isBlock ? "" : label,
                                            volumeId: isBlock ? "" : Self.volume, sortOrder: index)
                entry.id = ids[index]
                if isBlock {
                    entry.entryKind = .generated
                    entry.generatedBlockType = label
                }
                entry.collection = collection
                context.insert(entry)
            }
            try context.save()
            return (container, collection)
        }
        let (containerA, onA) = try device()
        let (containerB, onB) = try device()
        CollectionDocumentDiscovery.appendToCollection(documentId: "d3", volumeId: Self.volume,
                                                       collection: onA, modelContext: containerA.mainContext)
        try CollectionDocumentDiscovery.appendDocuments(
            ["d4", "d5", "d6"].map { CollectionDocumentRef(volumeId: Self.volume, documentId: $0) },
            to: onB, modelContext: containerB.mainContext)
        try containerA.mainContext.save()

        let a = Dictionary(uniqueKeysWithValues: (onA.documentEntries ?? []).map { ($0.id, $0) })
        let b = Dictionary(uniqueKeysWithValues: (onB.documentEntries ?? []).map { ($0.id, $0) })
        let added = a.values.filter { !ids.contains($0.id) } + b.values.filter { !ids.contains($0.id) }
        #expect(added.map(\.documentId).sorted() == ["d3", "d4", "d5", "d6"])
        for blockKeptFrom in [a, b] {
            let blocks = ids[2...].map { blockKeptFrom[$0]!.sortOrder }
            let late = added.filter { entry in blocks.contains { $0 <= entry.sortOrder } }.map(\.documentId)
            #expect(late.isEmpty, "\(late) sit at or after a block at \(blocks): added \(added.map { ($0.documentId, $0.sortOrder) })")
        }
        withExtendedLifetime((containerA, containerB)) {}
    }
}

// MARK: - CollectionFactsCopyTests (L43)

/// What a copy of a collection carries of L43's facts, and the walk over the schema that holds every stored property
/// of a collection and its entries to the values Duplicate and Create Static Snapshot are compared by (the plan's L43
/// brief; the third review's J39). `CollectionDuplicateSettingsTests` and `SmartCollectionSnapshotInsertTests` compare
/// copies by those values, with every setting changed, the new facts among them.
///
/// Version history:
///   1.0 — L43: initial implementation
@Suite("L43: a collection's facts in copies, a new collection's, and a headnote's writer", .serialized)
@MainActor
struct CollectionFactsCopyTests {

    /// The stored properties of `type` the schema mirrors, by their Swift names.
    static func storedProperties(of type: any PersistentModel.Type) -> Set<String> {
        let prefix = "CD_\(type)."
        return Set(CloudKitSchemaInventory.mirroredIdentifiers(of: Schema([type]))
            .filter { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count + 3)) })
    }

    /// The fields a value carries, by their Swift names.
    static func fields(of value: Any) -> Set<String> {
        Set(Mirror(reflecting: value).children.compactMap(\.label))
    }

    /// Every stored property of a collection and its entries is a field of the values the copies are compared by, but
    /// for the ones the walk names, each with its reason. A property added to a model and not to its values fails
    /// here, so it cannot be dropped by Duplicate or the snapshot unnoticed.
    @Test("Every stored property of a collection and its entries is carried by the values a copy is compared by")
    func schemaWalk() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let collection = CollectionDuplicateSettingsTests.everySetting(in: context)
        let entry = try #require(collection.documentEntries?.first)

        // A collection's entries are its relationship, `documentEntries`, which the values carry as `entries`.
        let collectionLeftOut = Self.storedProperties(of: Collection.self)
            .subtracting(Self.fields(of: CollectionExport(collection)))
        #expect(collectionLeftOut == ["documentEntries"], "\(collectionLeftOut.sorted())")
        // An entry's parent, which every copy makes new: the relationship and the parent's id.
        let entryLeftOut = Self.storedProperties(of: CollectionEntry.self)
            .subtracting(Self.fields(of: CollectionEntryExport(entry)))
        #expect(entryLeftOut == ["collection", "collectionId"], "\(entryLeftOut.sorted())")
        // And L43's seven are in the schema the walk reads.
        #expect(Self.storedProperties(of: Collection.self).isSuperset(
            of: ["citationStyle", "opening", "labelsJSON", "defaultIncludeRelatedDocuments"]))
        #expect(Self.storedProperties(of: CollectionEntry.self).isSuperset(of: ["dateLine", "headnoteDefault"]))
        #expect(Self.storedProperties(of: GeneratedSummary.self).contains("writerName"))

        // What a copy makes new, and what a snapshot must not copy (J39): its saved-search link first, which would
        // make the snapshot the smart collection again. Duplicate keeps it, as a copy of a smart collection is one.
        let duplicate = collection.duplicate(in: context)
        #expect(duplicate.savedSearchId == collection.savedSearchId)
        let snapshot = SmartCollectionSnapshot.create(from: collection, results: [], into: context)
        #expect(snapshot.savedSearchId == nil)
        #expect(snapshot.citationStyle == collection.citationStyle && snapshot.opening == collection.opening)
        #expect(snapshot.labelsJSON == collection.labelsJSON, "a later build's word travels too")
        withExtendedLifetime(container) {}
    }

    /// Decisions 159 and 160: a collection the reader makes opens on the volume's heading, in the style chosen in
    /// Settings ▸ Display; both are written, so CloudKit makes both fields from the first one made.
    @Test("A new collection opens on the volume's heading, in the style chosen in Settings")
    func newCollectionDefaults() {
        let collection = Collection(name: "New")
        #expect(collection.citationStyle == nil && collection.opening == nil, "1.0's collection names neither")
        collection.applyNewCollectionDefaults(citationStyle: .turabian)
        #expect(collection.citationStyle == "turabian")
        #expect(collection.opening == CollectionDocumentPlan.Opening.volumeHeading.rawValue)
        let options = CollectionExportOptions(composing: collection)
        #expect(options.volumeHeadingLeads && options.citationStyle == .turabian)
    }

    /// Decisions 194 and 234: a headnote the reader writes carries the collection's author line, trimmed, as its
    /// writer's name, and a copy of the draft keeps it.
    @Test("A headnote carries its writer's name, the author line, and a copy of the draft keeps it")
    func headnoteWriter() throws {
        #expect(CollectionEntryInspector.headnoteWriterName(authorLine: "  Jane Doe ") == "Jane Doe")
        #expect(CollectionEntryInspector.headnoteWriterName(authorLine: "  ") == nil)
        #expect(CollectionEntryInspector.headnoteWriterName(authorLine: nil) == nil)

        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let collection = Collection(name: "Headnotes")
        context.insert(collection)
        let entry = CollectionEntry(collectionId: collection.id, documentId: "d1", volumeId: "frus1946v06", sortOrder: 0)
        entry.collection = collection
        context.insert(entry)
        let draft = GeneratedSummary(documentId: "d1", volumeId: "frus1946v06",
                                     promptId: GeneratedSummaryExport.headnoteDraftPromptId,
                                     responseText: "Kennan's answer.", authorship: .userWritten,
                                     isHeadnoteDraft: true, writerName: "Jane Doe")
        context.insert(draft)
        entry.headnoteSummaryId = draft.id
        try context.save()

        let copy = collection.duplicate(in: context)
        try context.save()
        let copiedId = try #require(copy.documentEntries?.first?.headnoteSummaryId)
        #expect(copiedId != draft.id)
        let copied = try #require(try context.fetch(FetchDescriptor<GeneratedSummary>(
            predicate: #Predicate { $0.id == copiedId })).first)
        #expect(copied.writerName == "Jane Doe" && copied.isHeadnoteDraft)
        withExtendedLifetime(container) {}
    }

    /// The third review's J45: the research export carries a collection's headnote drafts whatever the AI-summaries
    /// switch says, since a draft is the author's own headnote; the switch governs the AI's summaries alone.
    @Test("The research export carries headnote drafts with the AI-summaries switch off (J45)")
    func exportCarriesHeadnoteDrafts() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let draft = GeneratedSummary(documentId: "d1", volumeId: "frus1946v06",
                                     promptId: GeneratedSummaryExport.headnoteDraftPromptId,
                                     responseText: "My headnote.", authorship: .userWritten,
                                     isHeadnoteDraft: true, writerName: "Jane Doe")
        let summary = GeneratedSummary(documentId: "d1", volumeId: "frus1946v06", promptId: UUID(),
                                       responseText: "The model's summary.")
        context.insert(draft)
        context.insert(summary)
        try context.save()

        let off = try ResearchDataExporter.makeEnvelope(modelContext: context, includeGeneratedSummaries: false)
        #expect(off.summaries.map(\.id) == [draft.id], "the switch left the author's headnote out")
        #expect(off.summaries.first?.writerName == "Jane Doe")
        let on = try ResearchDataExporter.makeEnvelope(modelContext: context, includeGeneratedSummaries: true)
        #expect(Set(on.summaries.map(\.id)) == [draft.id, summary.id])
        withExtendedLifetime(container) {}
    }
}

// MARK: - NoteOnTheTextSettingsLineTests (L58)

/// The Note on the Text's line in the collection's settings (L58; the design's §3.6): shown where the collection has no
/// Note and one would have something to say, by the rule its export reads, the headnotes looked up in the store only
/// where nothing else would be said.
///
/// Version history:
///   1.0 — L58: initial implementation
@Suite("The collection settings offer a Note on the Text where it would say something (L58)", .serialized)
@MainActor
struct NoteOnTheTextSettingsLineTests {

    @Test("Offered where the Note would say something and the collection has none; never for a smart collection")
    func offeredWhereItWouldSpeak() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let collection = Collection(name: "Line")
        context.insert(collection)
        let entry = CollectionEntry(collectionId: collection.id, documentId: "d1", volumeId: "frus1946v06", sortOrder: 0)
        entry.collection = collection
        context.insert(entry)
        try context.save()
        #expect(!CollectionApparatusStep.wantsNoteOnTheText(collection), "a document printed whole: nothing to say")

        // A headnote of Apple Intelligence's, found in the store: the Note would name its writer.
        entry.includeHeadnote = true
        #expect(!CollectionApparatusStep.wantsNoteOnTheText(collection), "a headnote with nothing stored prints none")
        let summary = GeneratedSummary(documentId: "d1", volumeId: "frus1946v06", promptId: UUID(),
                                       responseText: "The model's summary.")
        context.insert(summary)
        try context.save()
        #expect(CollectionApparatusStep.wantsNoteOnTheText(collection))
        entry.includeHeadnote = nil

        entry.titleOverride = "The Long Telegram"
        #expect(CollectionApparatusStep.wantsNoteOnTheText(collection), "a title of the compiler's")

        let note = CollectionEntry(collectionId: collection.id, documentId: "", volumeId: "", sortOrder: 1)
        note.entryKind = .generated
        note.generatedBlockType = CollectionGeneratedBlockType.noteOnTheText.rawValue
        note.collection = collection
        context.insert(note)
        try context.save()
        #expect(!CollectionApparatusStep.wantsNoteOnTheText(collection), "the collection has its Note")

        context.delete(note)
        collection.savedSearchId = UUID()
        try context.save()
        #expect(!CollectionApparatusStep.wantsNoteOnTheText(collection), "a smart collection's settings run no search")
        withExtendedLifetime(container) {}
    }
}
