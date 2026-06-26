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

// MARK: - RISExporterTests

/// Tests for `RISExporter`, in particular the `export(zoteroItem:)` converter
/// that backs the collection "Send to Zotero" export (Session 164 — switched
/// from the Zotero-API JSON envelope, which standard/iOS Zotero cannot import,
/// to RIS).
struct RISExporterTests {

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

    // MARK: - export(document:volume:year:url:)

    @Test("export(document:) emits a well-formed CHAP record opening with TY and closing with ER")
    func documentRecordIsWellFormed() {
        let ris = RISExporter().export(
            document: document, volume: volume, year: "1972",
            url: "https://history.state.gov/historicaldocuments/frus1969-76v01/d1")

        #expect(ris.hasPrefix("TY  - CHAP"))
        #expect(ris.contains("\nER  - "))
        #expect(ris.contains("TI  - Memorandum of Conversation"))
        #expect(ris.contains("A3  - Louis J. Smith"))
        #expect(ris.contains("A3  - David H. Herschler"))
        // Document number → Extra (M2), not Notes (N1), to avoid a spurious note.
        #expect(ris.contains("M2  - FRUS Document 1"))
        #expect(!ris.contains("N1  - "))
    }

    // MARK: - export(zoteroItem:)

    @Test("export(zoteroItem:) maps Item fields onto RIS tags including editor, tags, and notes")
    func zoteroItemMapsToRIS() {
        let item = ZoteroJSONExporter.makeItem(
            document: document,
            volume: volume,
            year: "1972",
            url: "https://history.state.gov/historicaldocuments/frus1969-76v01/d1",
            isEditorialNote: false,
            tags: ["NATO"],
            notes: ["My research note"]
        )

        let ris = RISExporter().export(zoteroItem: item)

        #expect(ris.hasPrefix("TY  - CHAP"))            // itemType bookSection -> CHAP
        #expect(ris.contains("TI  - Document 1: Memorandum of Conversation"))
        #expect(ris.contains("T2  - \(volume.title)"))
        #expect(ris.contains("A3  - Louis J. Smith"))    // editor -> A3
        #expect(ris.contains("A3  - David H. Herschler"))
        #expect(ris.contains("PB  - Government Printing Office"))
        #expect(ris.contains("CY  - Washington, D.C."))
        #expect(ris.contains("PY  - 1972"))
        #expect(ris.contains("UR  - https://history.state.gov/historicaldocuments/frus1969-76v01/d1"))
        #expect(ris.contains("KW  - NATO"))              // tag -> KW
        #expect(ris.contains("N1  - My research note"))  // note -> N1
        #expect(ris.hasSuffix("ER  - "))
    }

    @Test("export(zoteroItem:) omits optional tags when the Item carries none")
    func zoteroItemOmitsAbsentFields() {
        let unedited = FRUSVolumeMetadata(
            title: "Untitled Volume", editors: [], generalEditor: nil,
            publicationDate: "1972", publicationPlace: "Washington, D.C.", publisher: "Government Printing Office")

        let item = ZoteroJSONExporter.makeItem(
            document: document, volume: unedited, year: "1972", url: nil, isEditorialNote: false)

        let ris = RISExporter().export(zoteroItem: item)

        #expect(!ris.contains("KW  - "))
        #expect(!ris.contains("A3  - "))
        #expect(!ris.contains("UR  - "))
        #expect(ris.hasPrefix("TY  - CHAP"))
        #expect(ris.hasSuffix("ER  - "))
    }

    // MARK: - Single-document "Send to Zotero" path (tags + notes)

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

    @Test("Single-document Zotero RIS carries the document's tags (KW) and research notes (N1)")
    @MainActor
    func singleDocumentRISIncludesTagsAndNotes() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let tag = UserTag(name: "NATO")
        context.insert(tag)
        context.insert(DocumentTagAssignment(volumeId: "frus1969-76v01", documentId: "d1", tagId: tag.id))
        context.insert(ResearchNote(documentId: "d1", volumeId: "frus1969-76v01", bodyText: "Key turning point."))

        // Mirrors the single-document "Send to Zotero" pipeline: resolve annotations,
        // build the Item, then render RIS.
        let resolved = ZoteroJSONExporter.fetchTagsAndNotes(
            documentId: "d1", volumeId: "frus1969-76v01", context: context)
        let item = ZoteroJSONExporter.makeItem(
            document: document, volume: volume, year: "1972",
            url: "https://history.state.gov/historicaldocuments/frus1969-76v01/d1",
            isEditorialNote: false, tags: resolved.tags, notes: resolved.notes)

        let ris = RISExporter().export(zoteroItem: item)

        #expect(ris.contains("KW  - NATO"))
        #expect(ris.contains("N1  - Key turning point."))
    }
}
