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
