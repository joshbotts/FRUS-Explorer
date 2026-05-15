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

// MARK: - CollectionTests

struct CollectionTests {

    // MARK: - CollectionCreationTest

    @Test("CollectionCreationTest: new collection persists with correct name and project tag")
    func collectionCreation() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)

        let projectId = UUID()
        let collection = Collection(name: "Nixon-Kissinger Backchannel", projectIds: [projectId])
        context.insert(collection)
        try context.save()

        let descriptor = FetchDescriptor<Collection>(
            predicate: #Predicate { $0.name == "Nixon-Kissinger Backchannel" }
        )
        let results = try context.fetch(descriptor)

        #expect(results.count == 1)
        #expect(results.first?.projectIds.contains(projectId) == true)
        #expect(results.first?.createdAt != nil)
    }

    // MARK: - DocumentNoteAssociationTest

    @Test("DocumentNoteAssociationTest: CollectionEntry stores and retrieves researchNoteId")
    func documentNoteAssociation() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)

        let collection = Collection(name: "Test Collection")
        context.insert(collection)

        let note = ResearchNote(documentId: "d5", volumeId: "vol1", bodyText: "Key insight.")
        context.insert(note)

        let entry = CollectionEntry(
            collectionId: collection.id,
            documentId: "d5",
            volumeId: "vol1",
            sortOrder: 0,
            researchNoteId: note.id
        )
        entry.collection = collection
        context.insert(entry)
        try context.save()

        // Re-fetch entry
        let descriptor = FetchDescriptor<CollectionEntry>(
            predicate: #Predicate { $0.documentId == "d5" }
        )
        let fetched = try context.fetch(descriptor)
        #expect(fetched.count == 1)
        #expect(fetched.first?.researchNoteId == note.id)
    }

    // MARK: - AddByTagTest

    @Test("AddByTagTest: documents from notes with a given tag map correctly to (documentId, volumeId) pairs")
    func addByTag() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)

        let tag = UserTag(name: "Key Source")
        context.insert(tag)

        let note1 = ResearchNote(documentId: "d1", volumeId: "vol1",
                                 userTagIds: [tag.id])
        let note2 = ResearchNote(documentId: "d2", volumeId: "vol1",
                                 userTagIds: [tag.id])
        let note3 = ResearchNote(documentId: "d9", volumeId: "vol2",
                                 userTagIds: []) // different tag
        context.insert(note1)
        context.insert(note2)
        context.insert(note3)
        try context.save()

        // Simulate the add-by-tag lookup
        let descriptor = FetchDescriptor<ResearchNote>()
        let allNotes = try context.fetch(descriptor)
        let pairs = allNotes
            .filter { $0.userTagIds.contains(tag.id) }
            .map { (documentId: $0.documentId, volumeId: $0.volumeId) }

        #expect(pairs.count == 2)
        let documentIds = Set(pairs.map(\.documentId))
        #expect(documentIds == Set(["d1", "d2"]))
        #expect(!documentIds.contains("d9"))
    }

    // MARK: - SortByDateTest

    @Test("SortByDateTest: sortOrder is reassigned correctly after sorting by volume date")
    func sortByDate() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)

        let collection = Collection(name: "Date Sort Test")
        context.insert(collection)

        let entryA = CollectionEntry(collectionId: collection.id,
                                     documentId: "dA", volumeId: "vol1980",
                                     sortOrder: 0)
        let entryB = CollectionEntry(collectionId: collection.id,
                                     documentId: "dB", volumeId: "vol1960",
                                     sortOrder: 1)
        let entryC = CollectionEntry(collectionId: collection.id,
                                     documentId: "dC", volumeId: "vol1970",
                                     sortOrder: 2)
        entryA.collection = collection
        entryB.collection = collection
        entryC.collection = collection
        context.insert(entryA)
        context.insert(entryB)
        context.insert(entryC)
        try context.save()

        // Simulate a volume date map: vol1960 < vol1970 < vol1980
        let volumeDateMap: [String: String] = [
            "vol1960": "1960-01-01",
            "vol1970": "1970-01-01",
            "vol1980": "1980-01-01",
        ]

        var entries = [entryA, entryB, entryC]
        entries.sort { a, b in
            let aDate = volumeDateMap[a.volumeId] ?? "9999"
            let bDate = volumeDateMap[b.volumeId] ?? "9999"
            return aDate < bDate
        }
        for (i, e) in entries.enumerated() { e.sortOrder = i }

        #expect(entries[0].volumeId == "vol1960")
        #expect(entries[1].volumeId == "vol1970")
        #expect(entries[2].volumeId == "vol1980")
        #expect(entries[0].sortOrder == 0)
        #expect(entries[1].sortOrder == 1)
        #expect(entries[2].sortOrder == 2)
    }

    // MARK: - PDFExportTest

    @Test("PDFExportTest: PDFCollectionExporter writes a non-empty file starting with %PDF")
    func pdfExport() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)

        let collection = Collection(name: "SALT I Negotiations")
        context.insert(collection)
        try context.save()

        let docs: [CollectionExportDocument] = [
            CollectionExportDocument(
                documentId: "d1", volumeId: "frus1969-76v14",
                sortOrder: 0,
                title: "Memorandum of Conversation — Kissinger and Dobrynin",
                date: "1972-05-26",
                bodyText: "The meeting began at 9:00 PM in the Map Room. Kissinger opened by noting that progress on SALT depended on the Soviets accepting the principle of equal aggregates.",
                noteText: "Critical backchannel exchange — compare with formal Delegation records."
            ),
            CollectionExportDocument(
                documentId: "d2", volumeId: "frus1969-76v14",
                sortOrder: 1,
                title: "Telegram From the Embassy in Moscow",
                date: "1972-05-27",
                bodyText: "The Ambassador reported that Soviet counterparts indicated flexibility on the submarine launcher ceiling.",
                noteText: nil
            ),
        ]

        let exporter = PDFCollectionExporter()
        let url = try await exporter.export(collection: collection, documents: docs)

        #expect(FileManager.default.fileExists(atPath: url.path))
        let data = try Data(contentsOf: url)
        #expect(!data.isEmpty)
        // PDF files start with the %PDF header bytes
        let pdfHeader = Data([0x25, 0x50, 0x44, 0x46]) // "%PDF"
        #expect(data.prefix(4) == pdfHeader)
    }

    // MARK: - HTMLExportTest

    @Test("HTMLExportTest: HTMLCollectionExporter writes a UTF-8 HTML file with collection title and document anchors")
    func htmlExport() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)

        let collection = Collection(name: "Vietnam War Documents",
                                     note: "Key decisions from 1964–1968.")
        context.insert(collection)
        try context.save()

        let docs: [CollectionExportDocument] = [
            CollectionExportDocument(
                documentId: "d10", volumeId: "frus1964-68v04",
                sortOrder: 0,
                title: "Memorandum of Meeting — NSC Principals",
                date: "1964-08-04",
                bodyText: "The President asked for an assessment of Gulf of Tonkin options.",
                noteText: "Compare with McNamara's later recollection in retrospective."
            ),
        ]

        let exporter = HTMLCollectionExporter()
        let url = try await exporter.export(collection: collection, documents: docs)

        #expect(FileManager.default.fileExists(atPath: url.path))
        let html = try String(contentsOf: url, encoding: .utf8)
        #expect(!html.isEmpty)
        #expect(html.contains("<!DOCTYPE html>"))
        #expect(html.contains("Vietnam War Documents"))
        #expect(html.contains("Key decisions from 1964"))
        #expect(html.contains("Memorandum of Meeting"))
        #expect(html.contains("id=\"doc-"))
    }
}
