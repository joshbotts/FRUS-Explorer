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
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
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

    // MARK: - CompositionDefaultsTest

    @Test("CompositionDefaults: a new collection's composition matches the prior export defaults")
    func compositionDefaults() {
        let collection = Collection(name: "Test")
        // These defaults preserve the pre-Phase-1a behavior for existing/new collections.
        #expect(collection.defaultBodyDepth == "full")
        #expect(collection.footnoteStyle == "all")
        #expect(collection.tocStyle == "citation")
        #expect(collection.applyHighlights == false)
        #expect(collection.includeNotes == true)
        #expect(collection.includeWordCloud == false)
        #expect(collection.summaryPromptId == nil)
        // The stored raw values round-trip through the export enums.
        #expect(CollectionBodyDepth(rawValue: collection.defaultBodyDepth) == .full)
        #expect(CollectionFootnoteStyle(rawValue: collection.footnoteStyle) == .all)
        #expect(CollectionToCStyle(rawValue: collection.tocStyle) == .citation)
    }

    // MARK: - CompositionPersistenceTest

    @Test("CompositionPersistence: edited composition survives a save/fetch round-trip")
    func compositionPersistence() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)

        let collection = Collection(name: "Briefing")
        context.insert(collection)
        collection.defaultBodyDepth = CollectionBodyDepth.summaryOnly.rawValue
        collection.footnoteStyle = CollectionFootnoteStyle.sourceNoteOnly.rawValue
        collection.includeNotes = false
        let promptId = UUID()
        collection.summaryPromptId = promptId
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Collection>()).first
        #expect(fetched?.defaultBodyDepth == "summaryOnly")
        #expect(fetched?.footnoteStyle == "sourceNoteOnly")
        #expect(fetched?.includeNotes == false)
        #expect(fetched?.summaryPromptId == promptId)
    }

    // MARK: - PerEntryBodyDepthTest

    @Test("PerEntryBodyDepth: override wins; nil follows the collection default")
    func perEntryBodyDepth() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)

        let collection = Collection(name: "Mixed")
        collection.defaultBodyDepth = CollectionBodyDepth.full.rawValue
        context.insert(collection)

        let e1 = CollectionEntry(collectionId: collection.id, documentId: "d1", volumeId: "v1", sortOrder: 0)
        let e2 = CollectionEntry(collectionId: collection.id, documentId: "d2", volumeId: "v1", sortOrder: 1)
        e2.bodyDepthOverride = CollectionBodyDepth.index.rawValue
        context.insert(e1)
        context.insert(e2)
        try context.save()

        // The effective-depth rule used by resolveDocuments: override, else collection default.
        func effective(_ e: CollectionEntry) -> CollectionBodyDepth {
            CollectionBodyDepth(rawValue: e.bodyDepthOverride ?? collection.defaultBodyDepth) ?? .full
        }
        #expect(e1.bodyDepthOverride == nil)
        #expect(effective(e1) == .full)          // nil override → collection default
        #expect(effective(e2) == .index)         // explicit override wins
    }

    // MARK: - WithSummaryTest

    @Test("WithSummary: sets summary text and preserves the per-document body depth")
    func withSummaryPreservesDepth() {
        let doc = CollectionExportDocument(
            documentId: "d1", volumeId: "v1", sortOrder: 0,
            bodyDepth: .summaryOnly, title: "t", bodyText: "body")
        let out = doc.withSummary("A summary.")
        #expect(out.summaryText == "A summary.")
        #expect(out.bodyDepth == .summaryOnly)
        #expect(out.documentId == "d1")
        #expect(out.bodyText == "body")
    }

    // MARK: - EntryKindTest

    @Test("EntryKind: kind/text persist; entryKind accessor round-trips; default is document")
    func entryKindPersistence() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)

        let heading = CollectionEntry(collectionId: UUID(), documentId: "", volumeId: "", sortOrder: 0)
        heading.entryKind = .heading
        heading.text = "Background"
        context.insert(heading)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<CollectionEntry>()).first
        #expect(fetched?.kind == "heading")
        #expect(fetched?.entryKind == .heading)
        #expect(fetched?.text == "Background")

        // A plain document entry defaults to .document.
        let doc = CollectionEntry(collectionId: UUID(), documentId: "d1", volumeId: "v1", sortOrder: 1)
        #expect(doc.entryKind == .document)
    }

    // MARK: - ExportItemsTest

    @Test("ExportItems: .documents extracts document payloads in order, dropping headings/prose")
    func exportItemsDocuments() {
        let d1 = CollectionExportDocument(documentId: "d1", volumeId: "v1", sortOrder: 0, title: "t1", bodyText: "")
        let d2 = CollectionExportDocument(documentId: "d2", volumeId: "v1", sortOrder: 1, title: "t2", bodyText: "")
        let items: [CollectionExportItem] = [.heading("Section"), .document(d1),
                                             .prose(Data()), .document(d2)]
        let docs = items.documents
        #expect(docs.count == 2)
        #expect(docs.map(\.documentId) == ["d1", "d2"])
    }

    // MARK: - SectionBodyDepthTest (Phase 3c)

    @Test("SectionBodyDepth: cascade — entry override > section (heading) override > collection default")
    func sectionBodyDepthCascade() {
        // Entry override wins over everything.
        #expect(CollectionBodyDepth.resolve(entryOverride: "index", sectionOverride: "summaryOnly",
                                            collectionDefault: "full") == .index)
        // Section (heading) override applies when the entry has none.
        #expect(CollectionBodyDepth.resolve(entryOverride: nil, sectionOverride: "summaryOnly",
                                            collectionDefault: "full") == .summaryOnly)
        // Collection default when neither is set.
        #expect(CollectionBodyDepth.resolve(entryOverride: nil, sectionOverride: nil,
                                            collectionDefault: "index") == .index)
        // A malformed raw value falls back to `.full`.
        #expect(CollectionBodyDepth.resolve(entryOverride: "bogus", sectionOverride: nil,
                                            collectionDefault: "full") == .full)
    }

    @Test("SectionBodyDepth: a heading entry persists a bodyDepthOverride (the section default)")
    func headingSectionOverridePersists() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        let heading = CollectionEntry(collectionId: UUID(), documentId: "", volumeId: "", sortOrder: 0)
        heading.entryKind = .heading
        heading.text = "Cuba"
        heading.bodyDepthOverride = CollectionBodyDepth.summaryOnly.rawValue
        context.insert(heading)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<CollectionEntry>()).first
        #expect(fetched?.entryKind == .heading)
        #expect(fetched?.bodyDepthOverride == "summaryOnly")
    }

    // MARK: - ProseRichTextTest

    @Test("ProseRichText: exportRTF for a plain prose entry yields RTF whose plain text matches")
    func proseExportRTFPlain() throws {
        let entry = CollectionEntry(collectionId: UUID(), documentId: "", volumeId: "", sortOrder: 0)
        entry.entryKind = .prose
        entry.text = "Editorial commentary."
        entry.richText = nil
        let rtf = ProseRichText.exportRTF(from: entry)
        #expect(!rtf.isEmpty)
        let ns = try NSAttributedString(data: rtf,
                                        options: [.documentType: NSAttributedString.DocumentType.rtf],
                                        documentAttributes: nil)
        #expect(ns.string == "Editorial commentary.")
    }

    @Test("ProseRichText: concrete bold + colour in RTF round-trips and stays introspectable (export pipeline)")
    func proseRTFFormattingRoundTrips() throws {
        // Simulate what the native editor stores: concrete NSFont bold + coloured text.
        let m = NSMutableAttributedString(string: "Bold red")
        #if canImport(UIKit)
        m.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 14), range: NSRange(location: 0, length: 4))
        m.addAttribute(.foregroundColor, value: UIColor.red, range: NSRange(location: 5, length: 3))
        #elseif canImport(AppKit)
        m.addAttribute(.font, value: NSFontManager.shared.convert(.systemFont(ofSize: 13), toHaveTrait: .boldFontMask),
                       range: NSRange(location: 0, length: 4))
        m.addAttribute(.foregroundColor, value: NSColor.red, range: NSRange(location: 5, length: 3))
        #endif
        let rtf = try m.data(from: NSRange(location: 0, length: m.length),
                             documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])

        let entry = CollectionEntry(collectionId: UUID(), documentId: "", volumeId: "", sortOrder: 0)
        entry.entryKind = .prose
        entry.richText = rtf
        entry.text = m.string

        let back = try NSAttributedString(data: ProseRichText.exportRTF(from: entry),
                                          options: [.documentType: NSAttributedString.DocumentType.rtf],
                                          documentAttributes: nil)
        var sawBold = false, sawRed = false
        back.enumerateAttributes(in: NSRange(location: 0, length: back.length)) { a, _, _ in
            #if canImport(UIKit)
            if let f = a[.font] as? UIFont, f.fontDescriptor.symbolicTraits.contains(.traitBold) { sawBold = true }
            if let c = a[.foregroundColor] as? UIColor {
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, al: CGFloat = 0
                c.getRed(&r, green: &g, blue: &b, alpha: &al)
                if r > 0.5, g < 0.4 { sawRed = true }
            }
            #elseif canImport(AppKit)
            if let f = a[.font] as? NSFont, f.fontDescriptor.symbolicTraits.contains(.bold) { sawBold = true }
            if let c = (a[.foregroundColor] as? NSColor)?.usingColorSpace(.sRGB), c.redComponent > 0.5, c.greenComponent < 0.4 { sawRed = true }
            #endif
        }
        #expect(sawBold)   // native-editor bold survives store → export
        #expect(sawRed)    // native-editor colour survives store → export
        #expect(entry.text == "Bold red")
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
        let metadata = CollectionExportMetadata(name: collection.name, note: collection.note)
        let url = try await exporter.export(metadata: metadata, documents: docs)

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
        let metadata = CollectionExportMetadata(name: collection.name, note: collection.note)
        let url = try await exporter.export(metadata: metadata, documents: docs)

        #expect(FileManager.default.fileExists(atPath: url.path))
        let html = try String(contentsOf: url, encoding: .utf8)
        #expect(!html.isEmpty)
        #expect(html.contains("<!DOCTYPE html>"))
        #expect(html.contains("Vietnam War Documents"))
        #expect(html.contains("Key decisions from 1964"))
        #expect(html.contains("Memorandum of Meeting"))
        #expect(html.contains("id=\"doc-"))
    }

    // MARK: - DOCXStructureTest (Phase 3 structure rendering)

    @Test("DOCXStructure: composed section headings and rich prose render into the .docx package")
    func docxStructure() async throws {
        // A fully-bold prose block, stored as RTF the way the native editor would.
        let m = NSMutableAttributedString(string: "Commentary")
        #if canImport(UIKit)
        m.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 12),
                       range: NSRange(location: 0, length: m.length))
        #elseif canImport(AppKit)
        m.addAttribute(.font, value: NSFontManager.shared.convert(.systemFont(ofSize: 12), toHaveTrait: .boldFontMask),
                       range: NSRange(location: 0, length: m.length))
        #endif
        let rtf = try m.data(from: NSRange(location: 0, length: m.length),
                             documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])

        let doc = CollectionExportDocument(
            documentId: "d1", volumeId: "v1", sortOrder: 2,
            title: "A Memorandum", bodyText: "Body text here.")
        let items: [CollectionExportItem] = [.heading("Chapter One"), .prose(rtf), .document(doc)]

        let url = try await DocxCollectionExporter().export(
            metadata: CollectionExportMetadata(name: "Structured", note: nil), items: items)
        let data = try Data(contentsOf: url)
        #expect(!data.isEmpty)

        // The stored-mode ZIP keeps document.xml / styles.xml uncompressed, so the emitted
        // XML appears verbatim in the archive bytes.
        func contains(_ s: String) -> Bool { data.range(of: Data(s.utf8)) != nil }
        #expect(contains("SectionHeading"))   // section-heading style defined + referenced
        #expect(contains("Chapter One"))       // authored heading text present
        #expect(contains("Commentary"))        // prose text present
        #expect(contains("A Memorandum"))      // document heading present
    }

    // MARK: - PDFStructureTest (Phase 3 structure rendering)

    @Test("PDFStructure: a composed collection with headings and long prose writes a valid %PDF")
    func pdfStructure() async throws {
        // A long prose block to exercise the multi-page structural flow.
        let longText = String(repeating: "This is an editorial paragraph exercising the prose flow. ", count: 200)
        let rtf = try NSAttributedString(string: longText)
            .data(from: NSRange(location: 0, length: longText.count),
                  documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])

        let d1 = CollectionExportDocument(documentId: "d1", volumeId: "v1", sortOrder: 1,
                                          title: "First Memo", bodyText: "Alpha.")
        let d2 = CollectionExportDocument(documentId: "d2", volumeId: "v1", sortOrder: 3,
                                          title: "Second Memo", bodyText: "Beta.")
        let items: [CollectionExportItem] = [
            .heading("Part I"), .prose(rtf), .document(d1),
            .heading("Part II"), .document(d2),
        ]

        let url = try await PDFCollectionExporter().export(
            metadata: CollectionExportMetadata(name: "Structured PDF", note: nil), items: items)
        let data = try Data(contentsOf: url)
        #expect(!data.isEmpty)
        #expect(data.prefix(4) == Data([0x25, 0x50, 0x44, 0x46])) // "%PDF"
    }

    // MARK: - BibTeXExportTest (Phase 4 / D7)

    @Test("BibTeXExport: emits @incollection records with citation keys; research notes honor includeNotes")
    func bibtexExport() async throws {
        let item = ZoteroJSONExporter.Item(
            itemType: "bookSection",
            title: "Memorandum of Conversation",
            creators: [ZoteroJSONExporter.Creator(creatorType: "editor", name: "Louis J. Smith")],
            bookTitle: "Foreign Relations of the United States, 1969–1976, Volume I",
            date: "1972",
            publisher: "Government Printing Office",
            place: "Washington, D.C.",
            url: "https://history.state.gov/historicaldocuments/frus1969-76v01/d1",
            // A `%` in a tag (BibTeX comment char) must survive as `\%`; braces in a note
            // must be neutralized so they can't unbalance the field.
            tags: [ZoteroJSONExporter.Tag(tag: "100% verified")],
            notes: [ZoteroJSONExporter.Note(note: "Compare with {the} Delegation records.")]
        )
        let doc = CollectionExportDocument(
            documentId: "d1", volumeId: "frus1969-76v01", sortOrder: 0,
            title: "t", bodyText: "", zoteroItem: item)
        let metadata = CollectionExportMetadata(name: "SALT", note: nil)

        // includeNotes == true (default): research note travels as `annote`.
        let onURL = try await BibTeXCollectionExporter().export(metadata: metadata, documents: [doc])
        let onText = try String(contentsOf: onURL, encoding: .utf8)
        #expect(onText.contains("@incollection{frus1969-76v01_d1,"))
        #expect(onText.contains("title     = {Memorandum of Conversation}"))
        #expect(onText.contains("keywords  = {100\\% verified}"))   // `%` stays escaped, not bare
        #expect(onText.contains("annote"))
        #expect(onText.contains("Compare with (the) Delegation records."))  // braces neutralized
        #expect(!onText.contains("{the}"))

        // includeNotes == false: notes stripped, tags kept.
        var noNotes = CollectionExportOptions()
        noNotes.includeNotes = false
        let offURL = try await BibTeXCollectionExporter().export(
            metadata: metadata, documents: [doc], options: noNotes)
        let offText = try String(contentsOf: offURL, encoding: .utf8)
        #expect(!offText.contains("annote"))
        #expect(offText.contains("keywords  = {100\\% verified}"))  // tags still kept
    }
}
