// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import FRUSExplorer

// MARK: - Fixtures

private let document = FRUSDocumentMetadata(
    documentId: "d1",
    documentNumber: "1",
    header: "Memorandum of Conversation",
    dateline: "Washington, January 1, 1972"
)

private let volume = FRUSVolumeMetadata(
    title: "Foreign Relations of the United States, 1969–1976, Volume I",
    editors: ["Louis J. Smith", "David H. Herschler"],
    generalEditor: nil,
    publicationDate: "1972",
    publicationPlace: "Washington, D.C.",
    publisher: "Government Printing Office"
)

// MARK: - Creator splitting

struct ZoteroAPICreatorTests {

    @Test("Creator: splits a full name on the last space into first/last")
    func splitsName() {
        let c = ZoteroAPICreator.from(type: "editor", fullName: "Louis J. Smith")
        #expect(c.creatorType == "editor")
        #expect(c.firstName == "Louis J.")
        #expect(c.lastName == "Smith")
        #expect(c.name == nil)
    }

    @Test("Creator: single-token name falls back to the single-field form")
    func singleTokenName() {
        let c = ZoteroAPICreator.from(type: "author", fullName: "Department")
        #expect(c.firstName == nil)
        #expect(c.lastName == nil)
        #expect(c.name == "Department")
    }
}

// MARK: - Item mapping + encoding

struct ZoteroAPIItemTests {

    private func sampleItem() -> ZoteroJSONExporter.Item {
        ZoteroJSONExporter.makeItem(
            document: document, volume: volume, year: "1972",
            url: "https://history.state.gov/historicaldocuments/frus1969-76v01/d1",
            isEditorialNote: false, tags: ["NATO"], notes: ["My research note"]
        )
    }

    @Test("ZoteroAPIItem: maps fields, tags, split creators, and the collection key")
    func mapsFromItem() {
        let api = ZoteroAPIItem(item: sampleItem(), collectionKey: "COLL1")
        #expect(api.itemType == "bookSection")
        #expect(api.title == "Document 1: Memorandum of Conversation")
        #expect(api.tags.map(\.tag) == ["NATO"])
        #expect(api.collections == ["COLL1"])
        #expect(api.creators.contains { $0.firstName == "Louis J." && $0.lastName == "Smith" })
        #expect(api.creators.allSatisfy { $0.creatorType == "editor" })
    }

    @Test("ZoteroAPIItem: nil collection key yields an empty collections array")
    func noCollectionKey() {
        let api = ZoteroAPIItem(item: sampleItem(), collectionKey: nil)
        #expect(api.collections.isEmpty)
    }

    @Test("ZoteroAPIItem: encodes split creators and omits nil fields")
    func encodingShape() throws {
        let api = ZoteroAPIItem(item: sampleItem(), collectionKey: "COLL1")
        let data = try JSONEncoder().encode(api)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["itemType"] as? String == "bookSection")
        let creators = try #require(json["creators"] as? [[String: Any]])
        #expect(creators.first?["firstName"] as? String == "Louis J.")
        #expect(creators.first?["lastName"] as? String == "Smith")
        #expect(creators.first?["name"] == nil) // single-field form omitted
        #expect((json["collections"] as? [String]) == ["COLL1"])
    }
}

// MARK: - Notes (child items)

struct ZoteroAPINoteTests {

    @Test("htmlify: escapes entities and wraps blocks in paragraphs")
    func htmlifyEscapesAndWraps() {
        let html = ZoteroAPINote.htmlify("First & <best>\n\nSecond line")
        #expect(html.contains("&amp;"))
        #expect(html.contains("&lt;best&gt;"))
        #expect(html.contains("<p>First &amp; &lt;best&gt;</p>"))
        #expect(html.contains("<p>Second line</p>"))
    }

    @Test("htmlNote: attaches to the parent item")
    func htmlNoteParent() {
        let note = ZoteroAPINote.htmlNote(parentItem: "ITEMKEY1", text: "hi")
        #expect(note.itemType == "note")
        #expect(note.parentItem == "ITEMKEY1")
        #expect(note.note == "<p>hi</p>")
    }
}

// MARK: - Response decoding

struct ZoteroResponseTests {

    @Test("ZoteroWriteResponse: decodes successful/failed and maps index→key")
    func decodesWriteResponse() throws {
        let json = """
        { "successful": { "0": { "key": "ITEMKEY1", "version": 1 },
                          "2": { "key": "ITEMKEY3", "version": 1 } },
          "success": { "0": "ITEMKEY1", "2": "ITEMKEY3" },
          "unchanged": {},
          "failed": { "1": { "code": 400, "message": "bad" } } }
        """
        let resp = try JSONDecoder().decode(ZoteroWriteResponse.self, from: Data(json.utf8))
        #expect(resp.keysByIndex[0] == "ITEMKEY1")
        #expect(resp.keysByIndex[2] == "ITEMKEY3")
        #expect(resp.failed["1"]?.code == 400)
    }

    @Test("ZoteroKeyInfo: decodes userID and write/notes access")
    func decodesKeyInfo() throws {
        let json = """
        { "key": "abc", "userID": 12345, "username": "researcher",
          "access": { "user": { "library": true, "write": true, "notes": true } } }
        """
        let info = try JSONDecoder().decode(ZoteroKeyInfo.self, from: Data(json.utf8))
        #expect(info.userID == 12345)
        #expect(info.username == "researcher")
        #expect(info.canWriteNotes)
    }

    @Test("ZoteroKeyInfo: read-only key is rejected by canWriteNotes")
    func readOnlyKey() throws {
        let json = """
        { "userID": 1, "access": { "user": { "library": true, "write": false } } }
        """
        let info = try JSONDecoder().decode(ZoteroKeyInfo.self, from: Data(json.utf8))
        #expect(!info.canWriteNotes)
    }
}
