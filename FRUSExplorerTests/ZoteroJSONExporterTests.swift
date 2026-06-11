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

// MARK: - ZoteroJSONExporterTests

/// Tests for `ZoteroJSONExporter` (Session 155 — Zotero export, Option B).
struct ZoteroJSONExporterTests {

    private let document = FRUSDocumentMetadata(
        documentId: "d1",
        documentNumber: "1",
        header: "Memorandum of Conversation",
        dateline: "Washington, January 1, 1972"
    )

    private let volume = FRUSVolumeMetadata(
        title: "Foreign Relations of the United States, 1969–1976, Volume I, Foundations of Foreign Policy, 1969–1972",
        editors: ["Louis J. Smith"],
        generalEditor: nil,
        publicationDate: "1972",
        publicationPlace: "Washington, D.C.",
        publisher: "Government Printing Office"
    )

    private var todayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date())
    }

    // MARK: - makeItem

    @Test("makeItem maps title, bookTitle, creators, date, publisher, place, url, and accessDate")
    func makeItemMapsCoreFields() {
        let item = ZoteroJSONExporter.makeItem(
            document: document,
            volume: volume,
            year: "1972",
            url: "https://history.state.gov/historicaldocuments/frus1969-76v01/d1",
            isEditorialNote: false,
            tags: ["NATO"],
            notes: ["My research note"]
        )

        #expect(item.itemType == "bookSection")
        #expect(item.title == "Document 1: Memorandum of Conversation")
        #expect(item.bookTitle == volume.title)
        #expect(item.creators == [ZoteroJSONExporter.Creator(creatorType: "editor", name: "Louis J. Smith")])
        #expect(item.date == "1972")
        #expect(item.publisher == "Government Printing Office")
        #expect(item.place == "Washington, D.C.")
        #expect(item.url == "https://history.state.gov/historicaldocuments/frus1969-76v01/d1")
        #expect(item.accessDate == todayString)
        #expect(item.tags == [ZoteroJSONExporter.Tag(tag: "NATO")])
        #expect(item.notes == [ZoteroJSONExporter.Note(note: "My research note")])
    }

    @Test("makeItem uses the bare header as title when documentNumber is nil")
    func makeItemWithoutDocumentNumber() {
        let undatedDocument = FRUSDocumentMetadata(
            documentId: "d1", documentNumber: nil,
            header: "Editorial Note", dateline: nil)

        let item = ZoteroJSONExporter.makeItem(
            document: undatedDocument, volume: volume, year: "1972", url: nil, isEditorialNote: false)

        #expect(item.title == "Editorial Note")
    }

    @Test("makeItem includes 'Editorial note' and 'Document date:' lines in extra")
    func makeItemEditorialNoteExtra() {
        let item = ZoteroJSONExporter.makeItem(
            document: document, volume: volume, year: "1972", url: nil, isEditorialNote: true)

        #expect(item.extra == "Editorial note\nDocument date: Washington, January 1, 1972")
    }

    @Test("makeItem leaves extra nil when there is no editorial note or dateline")
    func makeItemExtraNilWhenEmpty() {
        let undatedDocument = FRUSDocumentMetadata(
            documentId: "d1", documentNumber: "1", header: "Memorandum", dateline: nil)

        let item = ZoteroJSONExporter.makeItem(
            document: undatedDocument, volume: volume, year: "1972", url: nil, isEditorialNote: false)

        #expect(item.extra == nil)
    }

    @Test("makeItem leaves creators, tags, and notes nil when empty")
    func makeItemOmitsEmptyCollections() {
        let unedited = FRUSVolumeMetadata(
            title: "Untitled Volume", editors: [], generalEditor: nil,
            publicationDate: "1972", publicationPlace: "Washington, D.C.", publisher: "Government Printing Office")

        let item = ZoteroJSONExporter.makeItem(
            document: document, volume: unedited, year: "1972", url: nil, isEditorialNote: false)

        #expect(item.creators == nil)
        #expect(item.tags == nil)
        #expect(item.notes == nil)
    }

    // MARK: - exportData

    @Test("exportData round-trips through JSONDecoder and preserves item order")
    func exportDataRoundTrips() throws {
        let item1 = ZoteroJSONExporter.makeItem(
            document: document, volume: volume, year: "1972", url: nil, isEditorialNote: false)
        let item2 = ZoteroJSONExporter.makeItem(
            document: FRUSDocumentMetadata(documentId: "d2", documentNumber: "2", header: "Telegram", dateline: nil),
            volume: volume, year: "1972", url: nil, isEditorialNote: false)

        let data = try ZoteroJSONExporter().exportData(items: [item1, item2])

        let decoded = try JSONDecoder().decode(ZoteroJSONExporter.Envelope.self, from: data)
        #expect(decoded.version == 5)
        #expect(decoded.items == [item1, item2])
    }

    @Test("exportData top-level keys match the Zotero JSON exchange format")
    func exportDataKeysMatchSchema() throws {
        let item = ZoteroJSONExporter.makeItem(
            document: document, volume: volume, year: "1972", url: nil, isEditorialNote: false)

        let data = try ZoteroJSONExporter().exportData(items: [item])

        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(json.keys) == ["version", "items"])
        #expect(json["version"] as? Int == 5)
    }

    // MARK: - fetchTagsAndNotes

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            UserTag.self,
            DocumentTagAssignment.self,
            ResearchNote.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    @Test("fetchTagsAndNotes combines direct tag assignments with note tags, and returns non-empty note bodies")
    @MainActor
    func fetchTagsAndNotesCombinesAssignmentsAndNoteTags() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let natoTag = UserTag(name: "NATO")
        let coldWarTag = UserTag(name: "Cold War")
        context.insert(natoTag)
        context.insert(coldWarTag)

        let assignment = DocumentTagAssignment(volumeId: "frus1969-76v01", documentId: "d1", tagId: natoTag.id)
        context.insert(assignment)

        let note = ResearchNote(
            documentId: "d1", volumeId: "frus1969-76v01",
            bodyText: "Key turning point.", userTagIds: [coldWarTag.id])
        context.insert(note)

        let emptyNote = ResearchNote(documentId: "d1", volumeId: "frus1969-76v01", bodyText: "")
        context.insert(emptyNote)

        let result = ZoteroJSONExporter.fetchTagsAndNotes(documentId: "d1", volumeId: "frus1969-76v01", context: context)

        #expect(result.tags == ["Cold War", "NATO"])
        #expect(result.notes == ["Key turning point."])
    }

    @Test("fetchTagsAndNotes returns empty results for a document with no tags or notes")
    @MainActor
    func fetchTagsAndNotesEmptyForUnannotatedDocument() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let result = ZoteroJSONExporter.fetchTagsAndNotes(documentId: "d99", volumeId: "frus1969-76v01", context: context)

        #expect(result.tags.isEmpty)
        #expect(result.notes.isEmpty)
    }
}
