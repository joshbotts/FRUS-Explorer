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
import PDFKit
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
        let items: [CollectionExportItem] = [.heading("Section", level: 1), .document(d1),
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

    @Test("ProseRichText: a legacy Phase 3b JSON blob exports as RTF (text + bold intact) and migrates the entry")
    func proseLegacyJSONBlobExportsAndMigrates() throws {
        // What a Phase 3b build persisted: the AttributedString's own Codable encoding,
        // with bold carried as Foundation inlinePresentationIntent — not RTF.
        var legacy = AttributedString("Legacy prose survives.")
        if let range = legacy.range(of: "Legacy") {
            legacy[range].inlinePresentationIntent = .stronglyEmphasized
        }
        let blob = try JSONEncoder().encode(legacy)

        let entry = CollectionEntry(collectionId: UUID(), documentId: "", volumeId: "", sortOrder: 0)
        entry.entryKind = .prose
        entry.richText = blob
        entry.text = "Legacy prose survives."

        let ns = try NSAttributedString(data: ProseRichText.exportRTF(from: entry),
                                        options: [.documentType: NSAttributedString.DocumentType.rtf],
                                        documentAttributes: nil)
        #expect(ns.string == "Legacy prose survives.")
        var sawBold = false
        ns.enumerateAttributes(in: NSRange(location: 0, length: ns.length)) { attrs, _, _ in
            #if canImport(UIKit)
            if let font = attrs[.font] as? UIFont, font.fontDescriptor.symbolicTraits.contains(.traitBold) { sawBold = true }
            #elseif canImport(AppKit)
            if let font = attrs[.font] as? NSFont, font.fontDescriptor.symbolicTraits.contains(.bold) { sawBold = true }
            #endif
        }
        #expect(sawBold)   // Phase 3b bold (inlinePresentationIntent) survives the conversion
        // exportRTF heals the store in place: the entry now holds RTF, not the legacy JSON.
        #expect(ProseRichText.decodedRTF(entry.richText ?? Data()) != nil)
    }

    @Test("ProseRichText: an unrecognizable richText blob falls back to the plain text projection")
    func proseUnrecognizableBlobFallsBack() throws {
        let garbage = Data([0x00, 0xFF, 0x13, 0x37])
        let entry = CollectionEntry(collectionId: UUID(), documentId: "", volumeId: "", sortOrder: 0)
        entry.entryKind = .prose
        entry.richText = garbage
        entry.text = "Only the plain projection is left."

        let ns = try NSAttributedString(data: ProseRichText.exportRTF(from: entry),
                                        options: [.documentType: NSAttributedString.DocumentType.rtf],
                                        documentAttributes: nil)
        #expect(ns.string == "Only the plain projection is left.")
        // The unrecognizable blob is left in place (never destroyed), not "migrated".
        #expect(entry.richText == garbage)
    }

    @Test("CollectionProse: a legacy Phase 3b JSON payload decodes to paragraphs — the exporter-side data-loss guard")
    func collectionProseLegacyFallback() throws {
        var legacy = AttributedString("First paragraph.\n\nSecond, emphasized.")
        if let range = legacy.range(of: "emphasized") {
            legacy[range].inlinePresentationIntent = .emphasized
        }
        let blob = try JSONEncoder().encode(legacy)

        let paragraphs = CollectionProse.paragraphs(fromRTF: blob)
        try #require(paragraphs.count == 2)   // blank line still splits paragraphs
        #expect(paragraphs[0].map(\.text).joined() == "First paragraph.")
        #expect(paragraphs[1].map(\.text).joined() == "Second, emphasized.")
        #expect(paragraphs[1].contains { $0.italic && $0.text == "emphasized" })
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
        let items: [CollectionExportItem] = [.heading("Chapter One", level: 1), .prose(rtf), .document(doc)]

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
            .heading("Part I", level: 1), .prose(rtf), .document(d1),
            .heading("Part II", level: 1), .document(d2),
        ]

        let url = try await PDFCollectionExporter().export(
            metadata: CollectionExportMetadata(name: "Structured PDF", note: nil), items: items)
        let data = try Data(contentsOf: url)
        #expect(!data.isEmpty)
        #expect(data.prefix(4) == Data([0x25, 0x50, 0x44, 0x46])) // "%PDF"
    }

    // MARK: - LegacyProseExportTest (data-loss guard)

    @Test("LegacyProseExport: a Phase 3b JSON prose payload still appears in HTML, DOCX, and PDF exports")
    func exportsRecoverLegacyProse() async throws {
        // A raw legacy blob reaching an exporter directly (e.g. synced from a Phase 3b
        // device, or carried by a pre-fix .fruscollection file) must render its text —
        // before the fix, all three exporters silently omitted the block.
        let blob = try JSONEncoder().encode(AttributedString("Irreplaceable editorial commentary."))
        let doc = CollectionExportDocument(documentId: "d1", volumeId: "v1", sortOrder: 1,
                                           title: "A Memo", bodyText: "Body.")
        let items: [CollectionExportItem] = [.heading("Part I", level: 1), .prose(blob), .document(doc)]
        let metadata = CollectionExportMetadata(name: "Legacy Prose", note: nil)

        let htmlURL = try await HTMLCollectionExporter().export(metadata: metadata, items: items)
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        #expect(html.contains("Irreplaceable editorial commentary."))

        // The stored-mode ZIP keeps document.xml uncompressed, so the prose text (in an
        // otherwise-valid package) appears verbatim in the archive bytes.
        let docxURL = try await DocxCollectionExporter().export(metadata: metadata, items: items)
        let docxData = try Data(contentsOf: docxURL)
        #expect(docxData.range(of: Data("Irreplaceable editorial commentary.".utf8)) != nil)

        // PDF content streams aren't byte-searchable; drawing the recovered prose without
        // error into a valid %PDF is the meaningful assertion here (span recovery itself is
        // covered by collectionProseLegacyFallback).
        let pdfURL = try await PDFCollectionExporter().export(metadata: metadata, items: items)
        let pdfData = try Data(contentsOf: pdfURL)
        #expect(pdfData.prefix(4) == Data([0x25, 0x50, 0x44, 0x46])) // "%PDF"
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

    // MARK: - SmartCollectionSnapshotTest (Phase 4 / D8)

    @Test("SmartCollectionSnapshot: materializes results into a new static collection, non-destructively")
    func smartSnapshot() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)

        let projectId = UUID()
        let smart = Collection(name: "Cuba 1962", projectIds: [projectId])
        smart.savedSearchId = UUID()
        smart.defaultBodyDepth = "summaryOnly"
        smart.tocStyle = "headerAndDateline"
        context.insert(smart)
        try context.save()

        let results: [SmartCollectionSnapshot.DocumentRef] = [
            (documentId: "d1", volumeId: "frus1961-63v11"),
            (documentId: "d2", volumeId: "frus1961-63v11"),
        ]
        let snap = SmartCollectionSnapshot.create(from: smart, results: results, into: context)
        try context.save()

        // The snapshot is a static, editable collection with copied composition.
        #expect(snap.savedSearchId == nil)
        #expect(snap.id != smart.id)
        #expect(snap.name.contains("Cuba 1962"))
        #expect(snap.name.contains("Snapshot"))
        #expect(snap.defaultBodyDepth == "summaryOnly")
        #expect(snap.tocStyle == "headerAndDateline")
        #expect(snap.projectIds == [projectId])

        let entries = (snap.documentEntries ?? []).sorted { $0.sortOrder < $1.sortOrder }
        #expect(entries.count == 2)
        #expect(entries.allSatisfy { $0.entryKind == .document })
        #expect(entries.map(\.documentId) == ["d1", "d2"])
        #expect(entries.map(\.sortOrder) == [0, 1])

        // Non-destructive: the original smart collection is untouched.
        #expect(smart.savedSearchId != nil)
        #expect((smart.documentEntries ?? []).isEmpty)
    }

    // MARK: - NativeCollectionFormatTests (Phase 4 / D9 core)

    /// Builds a source collection with a heading (section depth), a document (+ a linked note),
    /// and a rich-text prose block. Returns the collection and the note it created.
    @discardableResult
    private func makeNativeSourceCollection(in context: ModelContext) throws -> (Collection, ResearchNote) {
        let coll = Collection(name: "Berlin Crisis", note: "Key cables.")
        coll.defaultBodyDepth = "summaryOnly"
        coll.footnoteStyle = "sourceNoteOnly"
        coll.tocStyle = "headerAndDateline"
        coll.applyHighlights = true
        coll.includeNotes = true
        coll.includeWordCloud = true
        context.insert(coll)

        let note = ResearchNote(documentId: "d1", volumeId: "frus1961-63v14",
                                bodyText: "Compare with the Clay telegrams.")
        context.insert(note)

        let heading = CollectionEntry(collectionId: coll.id, documentId: "", volumeId: "", sortOrder: 0)
        heading.entryKind = .heading
        heading.text = "Opening Moves"
        heading.bodyDepthOverride = "index"
        heading.collection = coll

        let docEntry = CollectionEntry(collectionId: coll.id, documentId: "d1",
                                       volumeId: "frus1961-63v14", sortOrder: 1)
        docEntry.bodyDepthOverride = "full"
        docEntry.selectedNoteIds = [note.id]
        docEntry.collection = coll

        let prose = CollectionEntry(collectionId: coll.id, documentId: "", volumeId: "", sortOrder: 2)
        prose.entryKind = .prose
        let m = NSMutableAttributedString(string: "Editorial note.")
        #if canImport(UIKit)
        m.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 12), range: NSRange(location: 0, length: 4))
        #elseif canImport(AppKit)
        m.addAttribute(.font, value: NSFontManager.shared.convert(.systemFont(ofSize: 12), toHaveTrait: .boldFontMask),
                       range: NSRange(location: 0, length: 4))
        #endif
        prose.text = m.string
        prose.richText = try m.data(from: NSRange(location: 0, length: m.length),
                                    documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        prose.collection = coll

        context.insert(heading); context.insert(docEntry); context.insert(prose)
        try context.save()
        return (coll, note)
    }

    /// Resolves a document entry's linked note bodies from a context (mirrors the app's export path).
    private func noteTextResolver(_ context: ModelContext) -> (CollectionEntry) -> [String] {
        let all = (try? context.fetch(FetchDescriptor<ResearchNote>())) ?? []
        return { entry in
            entry.selectedNoteIds.compactMap { id in all.first { $0.id == id }?.bodyText }
        }
    }

    @Test("NativeFormat: composition, structure, prose, and opt-in notes round-trip onto a fresh store")
    func nativeRoundTrip() throws {
        let source = try ModelContainer.makeTestContainer()
        let sourceCtx = ModelContext(source)
        let (coll, _) = try makeNativeSourceCollection(in: sourceCtx)

        let file = NativeCollectionSerializer.makeFile(
            from: coll, includeNotes: true, resolveNoteTexts: noteTextResolver(sourceCtx))
        let data = try NativeCollectionSerializer.encode(file)
        #expect(!data.isEmpty)

        // Import into a *fresh* store (simulating another device).
        let dest = try ModelContainer.makeTestContainer()
        let destCtx = ModelContext(dest)
        let decoded = try NativeCollectionSerializer.decode(data)
        let imported = NativeCollectionSerializer.apply(decoded, into: destCtx)
        try destCtx.save()

        // Metadata + composition.
        #expect(imported.name == "Berlin Crisis")
        #expect(imported.note == "Key cables.")
        #expect(imported.defaultBodyDepth == "summaryOnly")
        #expect(imported.footnoteStyle == "sourceNoteOnly")
        #expect(imported.tocStyle == "headerAndDateline")
        #expect(imported.applyHighlights == true)
        #expect(imported.includeWordCloud == true)
        #expect(imported.id != coll.id)            // fresh identity
        #expect(imported.projectIds.isEmpty)       // device-local, dropped

        // Structure, in order.
        let entries = (imported.documentEntries ?? []).sorted { $0.sortOrder < $1.sortOrder }
        #expect(entries.count == 3)
        #expect(entries[0].entryKind == .heading)
        #expect(entries[0].text == "Opening Moves")
        #expect(entries[0].bodyDepthOverride == "index")     // section depth survives
        #expect(entries[1].entryKind == .document)
        #expect(entries[1].documentId == "d1")
        #expect(entries[1].volumeId == "frus1961-63v14")
        #expect(entries[1].bodyDepthOverride == "full")
        #expect(entries[2].entryKind == .prose)

        // Prose rich text survives and stays introspectable.
        let back = try NSAttributedString(data: #require(entries[2].richText),
                                          options: [.documentType: NSAttributedString.DocumentType.rtf],
                                          documentAttributes: nil)
        #expect(back.string == "Editorial note.")

        // Opt-in note travelled: a new ResearchNote with the same text, linked to the doc entry.
        let importedNotes = try destCtx.fetch(FetchDescriptor<ResearchNote>())
        #expect(importedNotes.contains { $0.bodyText == "Compare with the Clay telegrams." })
        #expect(entries[1].selectedNoteIds.count == 1)
    }

    @Test("NativeFormat: notes off (D9a default) omits note text and creates no ResearchNote on import")
    func nativeNotesOptOut() throws {
        let source = try ModelContainer.makeTestContainer()
        let sourceCtx = ModelContext(source)
        let (coll, _) = try makeNativeSourceCollection(in: sourceCtx)

        // includeNotes == false: the resolver would return text, but it must not be called/emitted.
        let file = NativeCollectionSerializer.makeFile(
            from: coll, includeNotes: false, resolveNoteTexts: { _ in ["SHOULD NOT APPEAR"] })
        let data = try NativeCollectionSerializer.encode(file)
        let json = String(decoding: data, as: UTF8.self)
        #expect(!json.contains("SHOULD NOT APPEAR"))
        #expect(!json.contains("Compare with the Clay telegrams."))

        let dest = try ModelContainer.makeTestContainer()
        let destCtx = ModelContext(dest)
        let imported = NativeCollectionSerializer.apply(try NativeCollectionSerializer.decode(data), into: destCtx)
        try destCtx.save()
        #expect((try destCtx.fetch(FetchDescriptor<ResearchNote>())).isEmpty)   // no notes created
        let docEntry = (imported.documentEntries ?? []).first { $0.entryKind == .document }
        #expect(docEntry?.selectedNoteIds.isEmpty == true)
    }

    @Test("Sync guard: unknown entry kinds read as .unrecognized, are never persisted, and are skipped by native export/import")
    func unrecognizedKindGuard() throws {
        let container = try ModelContainer.makeTestContainer()
        let ctx = ModelContext(container)
        let coll = Collection(name: "Future")
        ctx.insert(coll)
        let entry = CollectionEntry(collectionId: coll.id, documentId: "", volumeId: "", sortOrder: 0)
        entry.collection = coll
        // A kind raw value written by a hypothetical newer build ("excerpt" became real
        // in Authoring Phase 5, so the stand-in future kind is now "hologram").
        entry.kind = "hologram"
        ctx.insert(entry)

        // Accessor: unknown raw values surface as .unrecognized, not as a junk .document.
        #expect(entry.entryKind == .unrecognized)

        // Setter: the fallback is never persisted — the newer build's raw value survives.
        entry.entryKind = .unrecognized
        #expect(entry.kind == "hologram")

        // Native export omits the entry this build can't represent.
        let file = NativeCollectionSerializer.makeFile(
            from: coll, includeNotes: false, resolveNoteTexts: { _ in [] })
        #expect(file.entries.isEmpty)

        // Native import skips a file entry with an unknown kind instead of misdecoding it.
        let futureEntry = FRUSCollectionFile.Entry(
            kind: "hologram", documentId: "d1", volumeId: "frus1961-63v14",
            bodyDepthOverride: nil, text: nil, richText: nil, notes: nil)
        let fileWithFuture = FRUSCollectionFile(
            format: NativeCollectionSerializer.formatIdentifier, formatVersion: 1,
            name: "Future", note: nil, composition: file.composition, entries: [futureEntry])
        let dest = try ModelContainer.makeTestContainer()
        let destCtx = ModelContext(dest)
        let imported = NativeCollectionSerializer.apply(fileWithFuture, into: destCtx)
        try destCtx.save()
        #expect((imported.documentEntries ?? []).isEmpty)
    }

    @Test("NativeFormat: importCollection reads a file from disk, decodes, and reconstructs it")
    func nativeImportFromFile() throws {
        let source = try ModelContainer.makeTestContainer()
        let sourceCtx = ModelContext(source)
        let (coll, _) = try makeNativeSourceCollection(in: sourceCtx)

        let file = NativeCollectionSerializer.makeFile(
            from: coll, includeNotes: false, resolveNoteTexts: { _ in [] })
        let data = try NativeCollectionSerializer.encode(file)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("import-test.\(NativeCollectionSerializer.fileExtension)")
        try data.write(to: url, options: .atomic)
        defer { try? FileManager.default.removeItem(at: url) }

        let dest = try ModelContainer.makeTestContainer()
        let destCtx = ModelContext(dest)
        let imported = try NativeCollectionSerializer.importCollection(from: url, into: destCtx)
        try destCtx.save()

        #expect(imported.name == "Berlin Crisis")
        #expect((imported.documentEntries ?? []).count == 3)
        #expect(imported.id != coll.id)

        // A non-collection file surfaces a NativeCollectionError, not a crash.
        let junkURL = FileManager.default.temporaryDirectory.appendingPathComponent("junk.txt")
        try Data("not a collection".utf8).write(to: junkURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: junkURL) }
        #expect(throws: (any Error).self) {
            try NativeCollectionSerializer.importCollection(from: junkURL, into: destCtx)
        }
    }

    @Test("ExportFormat: native format has no CollectionExporter and the .fruscollection extension")
    func nativeExportFormatWiring() {
        #expect(ExportFormat.fruscollection.makeExporter() == nil)   // handled by the serializer path
        #expect(ExportFormat.fruscollection.fileExtension == "fruscollection")
        #expect(ExportFormat.pdf.makeExporter() != nil)              // rendered formats still make one
        #expect(ExportFormat.bibtex.makeExporter() != nil)
        #expect(ExportFormat.allCases.contains(.fruscollection))
    }

    @Test("NativeFormat: decode rejects a non-collection JSON file and a future-version file")
    func nativeDecodeGuards() throws {
        // Wrong format discriminator.
        let notOurs = Data(#"{"format":"other","formatVersion":1,"name":"x","composition":{"defaultBodyDepth":"full","footnoteStyle":"all","tocStyle":"citation","applyHighlights":false,"includeNotes":true,"includeWordCloud":false},"entries":[]}"#.utf8)
        #expect(throws: NativeCollectionError.self) { try NativeCollectionSerializer.decode(notOurs) }

        // Future format version.
        let future = Data(#"{"format":"fruscollection","formatVersion":9999,"name":"x","composition":{"defaultBodyDepth":"full","footnoteStyle":"all","tocStyle":"citation","applyHighlights":false,"includeNotes":true,"includeWordCloud":false},"entries":[]}"#.utf8)
        #expect(throws: NativeCollectionError.self) { try NativeCollectionSerializer.decode(future) }
    }

    // MARK: - CollectionContentResolverTests (Authoring Phase 2a)

    /// Short label for an export item's kind, for order assertions.
    private func kindLabel(_ item: CollectionExportItem) -> String {
        switch item {
        case .heading:  return "heading"
        case .prose:    return "prose"
        case .excerpt:  return "excerpt"
        case .document: return "document"
        }
    }

    /// The `.document` payload of an item, or `nil`.
    private func docPayload(_ item: CollectionExportItem) -> CollectionExportDocument? {
        if case .document(let doc) = item { return doc }
        return nil
    }

    @Test("Resolver golden fixture: kinds, order, depth cascade, note links, and citation fallbacks match the pre-extraction resolveItems behavior")
    @MainActor
    func resolverGoldenFixture() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        let appState = AppState()   // no downloadManager/pipeline: volumes resolve citation-only

        let coll = Collection(name: "Golden")
        coll.defaultBodyDepth = "full"
        context.insert(coll)

        let selNote = ResearchNote(documentId: "d2", volumeId: "goldenvol", bodyText: "Selected note.")
        let legNote = ResearchNote(documentId: "d3", volumeId: "goldenvol", bodyText: "Legacy note.")
        context.insert(selNote)
        context.insert(legNote)

        // Part I sets a section body-depth override; Part II clears it.
        let h1 = CollectionEntry(collectionId: coll.id, documentId: "", volumeId: "", sortOrder: 0)
        h1.entryKind = .heading
        h1.text = "Part I"
        h1.bodyDepthOverride = "index"

        let d1 = CollectionEntry(collectionId: coll.id, documentId: "d1", volumeId: "goldenvol", sortOrder: 1)

        let prose = CollectionEntry(collectionId: coll.id, documentId: "", volumeId: "", sortOrder: 2)
        prose.entryKind = .prose
        prose.text = "Editorial context."

        let d2 = CollectionEntry(collectionId: coll.id, documentId: "d2", volumeId: "goldenvol", sortOrder: 3)
        d2.bodyDepthOverride = "full"          // entry override beats the section override
        d2.selectedNoteIds = [selNote.id]

        let h2 = CollectionEntry(collectionId: coll.id, documentId: "", volumeId: "", sortOrder: 4)
        h2.entryKind = .heading
        h2.text = "Part II"

        let d3 = CollectionEntry(collectionId: coll.id, documentId: "d3", volumeId: "goldenvol",
                                 sortOrder: 5, researchNoteId: legNote.id)

        let future = CollectionEntry(collectionId: coll.id, documentId: "", volumeId: "", sortOrder: 6)
        future.kind = "hologram"               // unrecognized kind from a newer build — skipped

        let malformed = CollectionEntry(collectionId: coll.id, documentId: "", volumeId: "", sortOrder: 7)
        // kind stays "document" with empty ids — skipped defensively

        let all = [h1, d1, prose, d2, h2, d3, future, malformed]
        for entry in all { context.insert(entry) }
        try context.save()

        let resolver = CollectionContentResolver(appState: appState, modelContext: context)
        // Entries passed shuffled to prove the resolver orders by sortOrder.
        let items = try await resolver.resolve(
            collection: coll,
            entries: [d2, h1, d3, prose, h2, d1, future, malformed],
            allNotes: [selNote, legNote],
            purpose: .export)

        // Kinds and order — unrecognized and malformed entries are dropped.
        #expect(items.map(kindLabel) == ["heading", "document", "prose", "document", "heading", "document"])

        // Heading texts pass through.
        if case .heading(let t1, let l1) = items[0] {
            #expect(t1 == "Part I")
            #expect(l1 == 1)   // Phase 4: flat headings resolve to level 1
        } else { Issue.record("items[0] should be a heading") }
        if case .heading(let t2, let l2) = items[4] {
            #expect(t2 == "Part II")
            #expect(l2 == 1)
        } else { Issue.record("items[4] should be a heading") }

        // Prose round-trips through the RTF pipeline.
        if case .prose(let rtf) = items[2] {
            let ns = try NSAttributedString(data: rtf,
                                            options: [.documentType: NSAttributedString.DocumentType.rtf],
                                            documentAttributes: nil)
            #expect(ns.string == "Editorial context.")
        } else {
            Issue.record("items[2] should be prose")
        }

        // Documents: depth cascade + note links + citation-only fallbacks (no volume XML).
        let docs = items.documents
        try #require(docs.count == 3)

        #expect(docs[0].documentId == "d1")
        #expect(docs[0].bodyDepth == .index)                 // section override from Part I
        #expect(docs[0].citation == "goldenvol/d1")          // manifest-less fallback
        #expect(docs[0].title == "goldenvol — d1")
        #expect(docs[0].historyStateGovURL == "https://history.state.gov/historicaldocuments/goldenvol/d1")
        #expect(docs[0].bodyText.isEmpty)
        #expect(docs[0].renderModel == nil)
        #expect(docs[0].noteTexts.isEmpty)
        #expect(docs[0].highlights.isEmpty)
        #expect(docs[0].sourceNoteText == nil)
        #expect(docs[0].zoteroItem == nil)                   // no manifest volume metadata
        #expect(docs[0].date == nil)
        #expect(docs[0].sortOrder == 1)

        #expect(docs[1].documentId == "d2")
        #expect(docs[1].bodyDepth == .full)                  // entry override wins over section
        #expect(docs[1].noteTexts == ["Selected note."])     // selectedNoteIds path

        #expect(docs[2].documentId == "d3")
        #expect(docs[2].bodyDepth == .full)                  // Part II reset the section override
        #expect(docs[2].noteTexts == ["Legacy note."])       // legacy researchNoteId path
    }

    @Test("Unified smart path: smart documents now carry collection-level composition (notes, highlights, body depth)")
    @MainActor
    func smartPathHonorsCollectionComposition() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        let appState = AppState()

        let coll = Collection(name: "Smart")
        coll.defaultBodyDepth = "full"
        coll.applyHighlights = true
        context.insert(coll)

        let note = ResearchNote(documentId: "d7", volumeId: "smartvol", bodyText: "Smart doc note.")
        context.insert(note)
        let hl = DocumentHighlight(volumeId: "smartvol", documentId: "d7",
                                   startOffset: 0, endOffset: 4,
                                   colorTag: "green", renderingVersion: "v")
        context.insert(hl)
        try context.save()

        let resolver = CollectionContentResolver(appState: appState, modelContext: context)
        let refs = [CollectionContentResolver.SmartDocumentRef(documentId: "d7", volumeId: "smartvol", sortOrder: 0)]
        let items = await resolver.resolveSmartItems(refs, collection: coll, allNotes: [note])

        try #require(items.count == 1)
        let doc = try #require(docPayload(items[0]))
        // Pre-unification, the smart clone dropped all of these.
        #expect(doc.noteTexts == ["Smart doc note."])        // includeNotes composition honored
        #expect(doc.highlights.count == 1)                   // applyHighlights honored
        #expect(doc.highlights.first?.color == .green)
        #expect(doc.bodyDepth == .full)                      // collection default (no overrides exist)
        #expect(doc.summaryText == nil)

        // The collection default body depth flows through — including .summaryOnly —
        // without any generation happening in the core pipeline.
        coll.defaultBodyDepth = "summaryOnly"
        let summaryItems = await resolver.resolveSmartItems(refs, collection: coll, allNotes: [note])
        let summaryDoc = try #require(docPayload(summaryItems[0]))
        #expect(summaryDoc.bodyDepth == .summaryOnly)
        #expect(summaryDoc.summaryText == nil)
    }

    @Test("Preview purpose: never generates summaries — stored summaries attach, missing ones stay nil; export still requires a prompt")
    @MainActor
    func previewNeverGeneratesSummaries() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        let appState = AppState()

        let coll = Collection(name: "Preview")
        coll.defaultBodyDepth = "summaryOnly"
        context.insert(coll)
        let entry = CollectionEntry(collectionId: coll.id, documentId: "d1", volumeId: "prevvol", sortOrder: 0)
        context.insert(entry)
        try context.save()

        let resolver = CollectionContentResolver(appState: appState, modelContext: context)

        // No prompt configured: preview succeeds with a nil summary…
        let noPrompt = try await resolver.resolve(collection: coll, entries: [entry],
                                                  allNotes: [], purpose: .preview)
        let noPromptDoc = try #require(docPayload(noPrompt[0]))
        #expect(noPromptDoc.bodyDepth == .summaryOnly)
        #expect(noPromptDoc.summaryText == nil)
        // …while export fails exactly as before the extraction.
        await #expect(throws: CollectionResolveError.self) {
            _ = try await resolver.resolve(collection: coll, entries: [entry],
                                           allNotes: [], purpose: .export)
        }

        // Prompt configured but nothing stored: preview keeps the nil summary (placeholder
        // territory); export attempts generation and fails (no AI service in tests).
        let promptId = UUID()
        coll.summaryPromptId = promptId
        let unstored = try await resolver.resolve(collection: coll, entries: [entry],
                                                  allNotes: [], purpose: .preview)
        #expect(try #require(docPayload(unstored[0])).summaryText == nil)
        await #expect(throws: ExportError.self) {
            _ = try await resolver.resolve(collection: coll, entries: [entry],
                                           allNotes: [], purpose: .export)
        }

        // A stored summary for the prompt attaches in preview — still no generation.
        let stored = GeneratedSummary(documentId: "d1", volumeId: "prevvol",
                                      promptId: promptId, responseText: "Stored summary.")
        context.insert(stored)
        try context.save()
        let withStored = try await resolver.resolve(collection: coll, entries: [entry],
                                                    allNotes: [], purpose: .preview)
        #expect(try #require(docPayload(withStored[0])).summaryText == "Stored summary.")
    }

    @Test("Preview purpose: never prepares (downloads) volumes; export does")
    @MainActor
    func previewNeverPreparesVolumes() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        let appState = AppState()

        let coll = Collection(name: "Gate")
        context.insert(coll)
        let entry = CollectionEntry(collectionId: coll.id, documentId: "d1", volumeId: "gatevol", sortOrder: 0)
        context.insert(entry)
        try context.save()

        // Observe the purpose gating through the overridable preparation seam.
        let spy = PrepareVolumesSpyResolver(appState: appState, modelContext: context)
        _ = try await spy.resolve(collection: coll, entries: [entry], allNotes: [], purpose: .preview)
        #expect(spy.preparedVolumeIdSets.isEmpty, ".preview must never prepare volumes")
        _ = try await spy.resolve(collection: coll, entries: [entry], allNotes: [], purpose: .export)
        #expect(spy.preparedVolumeIdSets == [Set(["gatevol"])], ".export prepares exactly the referenced volumes")

        // End-to-end: a live DownloadManager sees no enqueue from a .preview resolve.
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("resolver-preview-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let counter = TransferCallCounter()
        let dm = DownloadManager(
            volumesDirectory: dir,
            concurrencyLimit: 1,
            downloadTask: { _ in
                await counter.increment()
                throw URLError(.cancelled)
            },
            onStateChanged: { _ in }
        )
        appState.downloadManager = dm

        let real = CollectionContentResolver(appState: appState, modelContext: context)
        _ = try await real.resolve(collection: coll, entries: [entry], allNotes: [], purpose: .preview)

        let state = await dm.currentState
        #expect(!state.activeVolumeIds.contains("gatevol"))
        #expect(!state.pendingVolumeIds.contains("gatevol"))
        #expect(await counter.count == 0, "a .preview resolve must trigger no transfers")
    }

    // MARK: - ExporterContractTest (Authoring Phase 2b)

    /// Builds the shared exporter-contract fixture: one item of EVERY `CollectionExportItem`
    /// case — a section heading, a rich-text prose block (RTF via `ProseRichText`, exactly as
    /// the native editor stores it), and a resolved document carrying a Zotero item so the
    /// reference exporters have something to emit.
    ///
    /// **Discipline:** every exporter must handle this list without crashing. Whenever a
    /// `CollectionExportItem` case is added (Phases 4–6), extend this fixture and the two
    /// contract tests below in the same commit.
    @MainActor
    private func makeExporterContractFixture() -> (metadata: CollectionExportMetadata,
                                                   items: [CollectionExportItem]) {
        let entry = CollectionEntry(collectionId: UUID(), documentId: "", volumeId: "", sortOrder: 1)
        entry.entryKind = .prose
        entry.text = "Editorial contract prose."
        entry.richText = nil
        let rtf = ProseRichText.exportRTF(from: entry)

        let zotero = ZoteroJSONExporter.Item(
            itemType: "bookSection",
            title: "Contract Memo",
            bookTitle: "Foreign Relations of the United States, Contract Volume",
            date: "1972",
            url: "https://history.state.gov/historicaldocuments/frusvol/d9")
        let doc = CollectionExportDocument(
            documentId: "d9", volumeId: "frusvol", sortOrder: 2,
            title: "Contract Memo",
            bodyText: "Contract body paragraph.",
            citation: "Contract Citation Label",
            historyStateGovURL: "https://history.state.gov/historicaldocuments/frusvol/d9",
            zoteroItem: zotero)

        let excerpt = CollectionExportExcerpt(
            text: "Contract excerpt passage.",
            documentId: "d9", volumeId: "frusvol",
            citation: "Contract Excerpt Citation",
            colorTag: "green")

        let items: [CollectionExportItem] = [
            .heading("Contract Part I", level: 1),
            .prose(rtf),
            .document(doc),
            .excerpt(excerpt),                           // Phase 5: frozen quotation
            .heading("Contract Nested Sub", level: 2),   // Phase 4: leveled headings
        ]
        return (CollectionExportMetadata(name: "Exporter Contract", note: nil), items)
    }

    @Test("ExporterContract: HTML, DOCX, and PDF render every CollectionExportItem case")
    func exporterContractRenderingFormats() async throws {
        let (metadata, items) = await makeExporterContractFixture()

        // HTML — all three kinds appear, and the document keeps its stable anchor id.
        let htmlURL = try await HTMLCollectionExporter().export(metadata: metadata, items: items)
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        #expect(html.contains("Contract Part I"))                    // .heading
        #expect(html.contains("class=\"section-heading\""))          // …as a section heading
        #expect(html.contains("<h2 class=\"section-heading\">Contract Part I</h2>"))   // level 1 = pre-Phase-4 h2
        #expect(html.contains("<h3 class=\"section-heading\">Contract Nested Sub</h3>")) // level 2 steps to h3
        #expect(html.contains("Editorial contract prose."))          // .prose
        #expect(html.contains("class=\"prose-block\""))              // …as a prose block
        #expect(html.contains("Contract Citation Label"))            // .document citation heading
        #expect(html.contains("Contract body paragraph."))           // .document body
        #expect(html.contains("id=\"doc-frusvol-d9\""))              // stable document anchor
        #expect(html.contains("Contract excerpt passage."))          // .excerpt passage
        #expect(html.contains("excerpt-block excerpt-green"))        // …styled + colour accent
        #expect(html.contains("class=\"excerpt-source\">Contract Excerpt Citation"))  // source line
        #expect(html.contains("figure.excerpt-block"))               // excerptCSS emitted when used

        // DOCX — the stored-mode ZIP keeps document.xml uncompressed, so the emitted XML
        // text appears verbatim in the archive bytes.
        let docxURL = try await DocxCollectionExporter().export(metadata: metadata, items: items)
        let docx = try Data(contentsOf: docxURL)
        func docxContains(_ s: String) -> Bool { docx.range(of: Data(s.utf8)) != nil }
        #expect(docxContains("Contract Part I"))                     // .heading
        #expect(docxContains("Contract Nested Sub"))                 // level-2 heading text
        #expect(docxContains("SectionHeading2"))                     // …styled distinguishably (outlineLvl 1)
        #expect(docxContains("Editorial contract prose."))           // .prose
        #expect(docxContains("Contract Citation Label"))             // .document
        #expect(docxContains("Contract excerpt passage."))           // .excerpt passage
        #expect(docxContains("ExcerptQuote"))                        // …quote-styled paragraphs
        #expect(docxContains("Contract Excerpt Citation"))           // …source line (ExcerptSource)
        #expect(docxContains("ExcerptSource"))
        // The ToC field's `\o` level range is content-driven (Phase 4 review fix): this
        // fixture's deepest authored heading is level 2, so the field must stay the exact
        // pre-Phase-4 `\o "1-2"` — because `\o` bounds the `\u` outline-level sweep, a
        // wider range would pull every in-document TEI heading and "Summary" label
        // (built-in Heading3, outlineLvl 2) into Word's regenerated ToC.
        #expect(docxContains("TOC \\o \"1-2\""))
        #expect(!docxContains("TOC \\o \"1-3\""))
        // Only an authored level-3 section widens the field to `\o "1-3"`.
        let deepItems = items + [.heading("Contract Deep Sub", level: 3)]
        let deepDocx = try Data(contentsOf: try await DocxCollectionExporter().export(
            metadata: metadata, items: deepItems))
        #expect(deepDocx.range(of: Data("TOC \\o \"1-3\"".utf8)) != nil)

        // PDF — content streams aren't byte-searchable, so extract the page text with
        // PDFKit and assert every item kind's content actually made it onto a page
        // (a bare %PDF check cannot catch silently dropped content).
        let pdfURL = try await PDFCollectionExporter().export(metadata: metadata, items: items)
        let pdf = try Data(contentsOf: pdfURL)
        #expect(pdf.prefix(4) == Data([0x25, 0x50, 0x44, 0x46]))     // "%PDF"
        let pdfDocument = try #require(PDFDocument(data: pdf))
        let pdfText = (0..<pdfDocument.pageCount)
            .compactMap { pdfDocument.page(at: $0)?.string }
            .joined(separator: "\n")
        #expect(pdfText.contains("Contract Part I"))                 // .heading
        #expect(pdfText.contains("Contract Nested Sub"))             // level-2 heading (indent/size stepped)
        #expect(pdfText.contains("Editorial contract prose."))      // .prose
        #expect(pdfText.contains("Contract body paragraph."))       // .document body
        #expect(pdfText.contains("Contract excerpt passage."))      // .excerpt passage
        #expect(pdfText.contains("Contract Excerpt Citation"))      // …source line
    }

    @Test("ExporterContract: Zotero RIS and BibTeX export the document and skip structural items")
    func exporterContractReferenceFormats() async throws {
        let (metadata, items) = await makeExporterContractFixture()

        // Zotero RIS — a flat reference list: exactly one record (the document);
        // headings and prose have no Zotero representation and are legitimately dropped.
        let risURL = try await ZoteroCollectionExporter().export(metadata: metadata, items: items)
        let ris = try String(contentsOf: risURL, encoding: .utf8)
        #expect(ris.components(separatedBy: "TY  - ").count - 1 == 1)
        #expect(ris.contains("Contract Memo"))
        #expect(!ris.contains("Contract Part I"))
        #expect(!ris.contains("Editorial contract prose."))
        #expect(!ris.contains("Contract excerpt passage."))   // excerpts skipped by design

        // BibTeX — same discipline; records are keyed volumeId_documentId.
        let bibURL = try await BibTeXCollectionExporter().export(metadata: metadata, items: items)
        let bib = try String(contentsOf: bibURL, encoding: .utf8)
        #expect(bib.contains("@incollection{frusvol_d9,"))
        #expect(bib.contains("Contract Memo"))
        #expect(!bib.contains("Contract Part I"))
        #expect(!bib.contains("Editorial contract prose."))
        #expect(!bib.contains("Contract excerpt passage."))   // excerpts skipped by design
    }

    @Test("SharedRenderer: the HTML export file is byte-identical to CollectionItemHTMLRenderer.pageHTML")
    func htmlExportMatchesSharedRenderer() async throws {
        // The no-drift guarantee of Authoring Phase 2b: the exporter writes exactly what the
        // shared renderer assembles, so the live preview (same pageHTML call) cannot diverge
        // from the exported file.
        let (metadata, items) = await makeExporterContractFixture()
        let options = CollectionExportOptions()

        let url = try await HTMLCollectionExporter().export(
            metadata: metadata, items: items, options: options)
        let exported = try String(contentsOf: url, encoding: .utf8)
        let assembled = CollectionItemHTMLRenderer(options: options)
            .pageHTML(metadata: metadata, items: items)
        #expect(exported == assembled)
    }

    // MARK: - Phase 4 publication frame

    @Test("Phase4 frame: a collection using no new feature emits the exact pre-Phase-4 HTML")
    func htmlFrameDormantByteCompat() {
        // Frozen pre-Phase-4 fragments: these literals are the byte-identity contract for
        // old collections — a change here means already-exported files would re-export
        // differently, which the migration section of the authoring scope forbids.
        let doc = CollectionExportDocument(
            documentId: "d1", volumeId: "v1", sortOrder: 1,
            title: "Memo", bodyText: "Body.",
            citation: "Plain Citation",
            historyStateGovURL: "")
        let items: [CollectionExportItem] = [.heading("Part I", level: 1), .document(doc)]
        let metadata = CollectionExportMetadata(name: "Plain", note: "A note.")
        let renderer = CollectionItemHTMLRenderer()

        // Header block: no subtitle/author lines when unset.
        #expect(renderer.headerHTML(metadata: metadata) ==
                "<header>\n  <h1>Plain</h1>\n  <p class=\"collection-note\">A note.</p>\n</header>\n\n")

        // Level-1 heading fragment: the exact pre-Phase-4 <h2>.
        #expect(renderer.itemHTML(.heading("Part I", level: 1)) ==
                "<h2 class=\"section-heading\">Part I</h2>\n\n")

        // All-level-1 ToC: the exact pre-Phase-4 flat list — no nested markup.
        #expect(renderer.tableOfContentsHTML(for: items) ==
                "<nav>\n  <h2>Contents</h2>\n  <ol>\n"
                + "    <li class=\"toc-section\">Part I</li>\n"
                + "    <li><a href=\"#doc-v1-d1\">Plain Citation</a></li>\n"
                + "  </ol>\n</nav>\n\n")

        // Full page: no frame markup and no frame/preview stylesheet layers — the shared
        // CSS runs straight into the closing </style> exactly as before Phase 4.
        let page = renderer.pageHTML(metadata: metadata, items: items)
        #expect(!page.contains("toc-sub"))
        #expect(!page.contains("collection-subtitle"))
        #expect(!page.contains("collection-author"))
        #expect(!page.contains("colophon"))
        #expect(!page.contains("headnote"))   // Phase 5 layer stays dormant too
        #expect(!page.contains("excerpt"))    // Phase 5 excerpt layer stays dormant too
        #expect(page.contains(CollectionItemHTMLRenderer.embeddedCSS + "\n  </style>"))
    }

    @Test("Phase4 frame: nested headings produce nested ToC lists and stepped heading tags")
    func htmlNestedToCStructure() {
        let d1 = CollectionExportDocument(documentId: "d1", volumeId: "v1", sortOrder: 1,
                                          title: "t1", bodyText: "", citation: "Doc One")
        let d2 = CollectionExportDocument(documentId: "d2", volumeId: "v1", sortOrder: 3,
                                          title: "t2", bodyText: "", citation: "Doc Two")
        let items: [CollectionExportItem] = [
            .heading("Part I", level: 1), .document(d1),
            .heading("Section A", level: 2), .document(d2),
            .heading("Detail 1", level: 3),
            .heading("Part II", level: 1),
        ]
        let renderer = CollectionItemHTMLRenderer()
        let toc = renderer.tableOfContentsHTML(for: items)

        // Two nested lists open (level 2 and level 3) and both close again.
        #expect(toc.components(separatedBy: "<li class=\"toc-sub\"><ol>").count - 1 == 2)
        #expect(toc.components(separatedBy: "</ol></li>").count - 1 == 2)
        // The document after the level-2 heading nests inside the sub-list (deeper indent).
        #expect(toc.contains("      <li><a href=\"#doc-v1-d2\">Doc Two</a></li>"))
        // Part II returns to base level after both closes.
        if let lastClose = toc.range(of: "</ol></li>", options: .backwards),
           let partII = toc.range(of: "    <li class=\"toc-section\">Part II</li>") {
            #expect(lastClose.upperBound <= partII.lowerBound)
        } else {
            Issue.record("expected nested closes and a base-level Part II row in the ToC")
        }

        // Heading fragments step h2 → h3 → h4; absurd synced levels clamp to the deepest tag.
        #expect(renderer.itemHTML(.heading("Section A", level: 2)).hasPrefix("<h3 class=\"section-heading\">"))
        #expect(renderer.itemHTML(.heading("Detail 1", level: 3)).hasPrefix("<h4 class=\"section-heading\">"))
        #expect(renderer.itemHTML(.heading("X", level: 42)).hasPrefix("<h4 class=\"section-heading\">"))
        #expect(renderer.itemHTML(.heading("Y", level: -7)).hasPrefix("<h2 class=\"section-heading\">"))
    }

    @Test("Phase4 frame: title page, introduction, and colophon appear in all three formats only when set")
    func frontMatterAcrossFormats() async throws {
        let doc = CollectionExportDocument(
            documentId: "d1", volumeId: "frusframe", sortOrder: 1,
            title: "Framed Memo", bodyText: "Framed body paragraph.",
            citation: "Framed Citation")
        let introRTF = try #require(ProseRichText.exportRTF(
            richText: nil, plainText: "An introduction to the record."))
        // The resolver emits the introduction as the leading .prose item (metadata carries
        // the title page + colophon opt-in) — mirror that shape here.
        let framedItems: [CollectionExportItem] = [
            .prose(introRTF), .heading("Part I", level: 1), .document(doc)]
        let plainItems: [CollectionExportItem] = [
            .heading("Part I", level: 1), .document(doc)]
        let framed = CollectionExportMetadata(
            name: "Framed", note: nil, subtitle: "A Documentary Record",
            authorLine: "Assembled by the Researcher", includeColophon: true)
        let plain = CollectionExportMetadata(name: "Framed", note: nil)

        // HTML — present when set…
        let htmlOnURL = try await HTMLCollectionExporter().export(metadata: framed, items: framedItems)
        let htmlOn = try String(contentsOf: htmlOnURL, encoding: .utf8)
        #expect(htmlOn.contains("class=\"collection-subtitle\">A Documentary Record"))
        #expect(htmlOn.contains("class=\"collection-author\">Assembled by the Researcher"))
        #expect(htmlOn.contains("An introduction to the record."))
        #expect(htmlOn.contains("<footer class=\"colophon\">"))
        #expect(htmlOn.contains("Compiled with FRUS Explorer"))
        #expect(htmlOn.contains("1 document"))
        // …and absent when not.
        let htmlOffURL = try await HTMLCollectionExporter().export(metadata: plain, items: plainItems)
        let htmlOff = try String(contentsOf: htmlOffURL, encoding: .utf8)
        #expect(!htmlOff.contains("collection-subtitle"))
        #expect(!htmlOff.contains("collection-author"))
        #expect(!htmlOff.contains("colophon"))
        #expect(!htmlOff.contains("Compiled with FRUS Explorer"))

        // DOCX — the stored-mode ZIP keeps document.xml uncompressed.
        let docxOn = try Data(contentsOf: try await DocxCollectionExporter().export(
            metadata: framed, items: framedItems))
        func onContains(_ s: String) -> Bool { docxOn.range(of: Data(s.utf8)) != nil }
        #expect(onContains("A Documentary Record"))
        #expect(onContains("CollectionSubtitle"))       // subtitle style referenced
        #expect(onContains("Assembled by the Researcher"))
        #expect(onContains("An introduction to the record."))
        #expect(onContains("Compiled with FRUS Explorer"))
        let docxOff = try Data(contentsOf: try await DocxCollectionExporter().export(
            metadata: plain, items: plainItems))
        func offContains(_ s: String) -> Bool { docxOff.range(of: Data(s.utf8)) != nil }
        #expect(!offContains("A Documentary Record"))
        #expect(!offContains("Assembled by the Researcher"))
        #expect(!offContains("Compiled with FRUS Explorer"))

        // PDF — extract page text with PDFKit.
        let pdfOn = try Data(contentsOf: try await PDFCollectionExporter().export(
            metadata: framed, items: framedItems))
        let pdfOnDoc = try #require(PDFDocument(data: pdfOn))
        let pdfOnText = (0..<pdfOnDoc.pageCount)
            .compactMap { pdfOnDoc.page(at: $0)?.string }.joined(separator: "\n")
        #expect(pdfOnText.contains("A Documentary Record"))
        #expect(pdfOnText.contains("Assembled by the Researcher"))
        #expect(pdfOnText.contains("An introduction to the record."))
        #expect(pdfOnText.contains("Compiled with FRUS Explorer"))
        let pdfOff = try Data(contentsOf: try await PDFCollectionExporter().export(
            metadata: plain, items: plainItems))
        let pdfOffDoc = try #require(PDFDocument(data: pdfOff))
        let pdfOffText = (0..<pdfOffDoc.pageCount)
            .compactMap { pdfOffDoc.page(at: $0)?.string }.joined(separator: "\n")
        #expect(!pdfOffText.contains("A Documentary Record"))
        #expect(!pdfOffText.contains("Compiled with FRUS Explorer"))
    }

    @Test("Phase4 frame: the resolver prepends a set introduction as the leading prose item")
    @MainActor
    func resolverIntroductionItem() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        let appState = AppState()

        let coll = Collection(name: "Framed")
        context.insert(coll)
        let heading = CollectionEntry(collectionId: coll.id, documentId: "", volumeId: "", sortOrder: 0)
        heading.entryKind = .heading
        heading.text = "Part I"
        context.insert(heading)
        try context.save()

        let resolver = CollectionContentResolver(appState: appState, modelContext: context)

        // No introduction → the pre-Phase-4 item list, exactly.
        let bare = try await resolver.resolve(
            collection: coll, entries: [heading], allNotes: [], purpose: .preview)
        #expect(bare.map(kindLabel) == ["heading"])

        // Plain-text introduction → a leading .prose item carrying it as RTF.
        coll.introductionText = "Why these documents matter."
        let framed = try await resolver.resolve(
            collection: coll, entries: [heading], allNotes: [], purpose: .preview)
        #expect(framed.map(kindLabel) == ["prose", "heading"])
        if case .prose(let rtf) = framed[0] {
            #expect(ProseRichText.decodedRTF(rtf)?.string == "Why these documents matter.")
        } else {
            Issue.record("framed[0] should be the introduction prose item")
        }
        if case .heading(_, let level) = framed[1] { #expect(level == 1) }

        // Rich introduction wins over the plain projection.
        let richNS = NSAttributedString(string: "Rich introduction.")
        coll.introductionRichText = try #require(ProseRichText.rtfData(from: richNS))
        let rich = try await resolver.resolve(
            collection: coll, entries: [heading], allNotes: [], purpose: .preview)
        if case .prose(let rtf) = rich[0] {
            #expect(ProseRichText.decodedRTF(rtf)?.string == "Rich introduction.")
        } else {
            Issue.record("rich[0] should be the introduction prose item")
        }
    }

    // MARK: - Phase 3: Citation line pipeline (Add Documents sheet)

    /// A document-level citation match with the given strategy.
    private static func makeMatch(
        documentId: String, volumeId: String = "frus1969-76v01",
        rank: Int = 1, strategy: MatchStrategy = .exactDocumentNumber,
        note: String? = nil
    ) -> CitationMatch {
        CitationMatch(documentId: documentId, volumeId: volumeId, rank: rank,
                      matchStrategy: strategy, confidenceLabel: "label-\(rank)",
                      correctionNote: note)
    }

    @Test("AddDocuments citations: line splitting drops empty lines and trims whitespace")
    func citationLineSplitting() {
        let text = "  FRUS, 1969–76, I, doc. 15  \n\n\nline two\n   \nline three\n"
        let lines = CollectionCitationLineResolver.lines(from: text)
        #expect(lines == ["FRUS, 1969–76, I, doc. 15", "line two", "line three"])
    }

    @Test("AddDocuments citations: history.state.gov URLs resolve directly, without the engine")
    func citationURLRecognition() async {
        // The URL matcher extracts the exact TEI identifiers from the site path.
        let ref = CollectionCitationLineResolver.documentReference(
            inURLLine: "see https://history.state.gov/historicaldocuments/frus1969-76v01/d42 for details")
        #expect(ref?.volumeId == "frus1969-76v01")
        #expect(ref?.documentId == "d42")
        // Case-insensitive matching normalizes BOTH components to the canonical
        // lowercase TEI form — an uppercase volume id would match nothing downstream.
        let shouty = CollectionCitationLineResolver.documentReference(
            inURLLine: "HTTPS://HISTORY.STATE.GOV/HISTORICALDOCUMENTS/FRUS1969-76V01/D42")
        #expect(shouty?.volumeId == "frus1969-76v01")
        #expect(shouty?.documentId == "d42")
        // Non-document paths and non-FRUS volume components are rejected.
        #expect(CollectionCitationLineResolver.documentReference(
            inURLLine: "https://history.state.gov/historicaldocuments/frus1969-76v01") == nil)
        #expect(CollectionCitationLineResolver.documentReference(
            inURLLine: "https://history.state.gov/historicaldocuments/about-frus/d1") == nil)

        // A URL line never reaches parse/match: both stages would fail loudly here.
        let resolver = CollectionCitationLineResolver(
            parse: { _ in CitationInput(rawText: nil) },   // not actionable
            match: { _ in Issue.record("match must not run for URL lines"); return [] })
        let outcome = await resolver.resolve(
            line: "https://history.state.gov/historicaldocuments/frus1861/d7")
        #expect(outcome == .resolved(volumeId: "frus1861", documentId: "d7", note: nil))
    }

    @Test("AddDocuments citations: resolved / ambiguous / unresolved bucketing from injected results")
    func citationLineBucketing() async {
        // Injected matcher: behavior keyed off the parsed document number — the engine
        // is never constructed (the per-line pipeline takes parse/match closures).
        let resolver = CollectionCitationLineResolver(
            parse: { CitationParser().parse($0) },
            match: { input in
                switch input.documentNumber {
                case 1:   // lone exact match → resolved
                    return [Self.makeMatch(documentId: "d1")]
                case 2:   // fuzzy strategy → ambiguous, top match surfaced
                    return [Self.makeMatch(documentId: "d90", rank: 1,
                                           strategy: .fuzzyDocumentNumber(nearest: 90))]
                case 3:   // several document-level candidates, none exact → ambiguous
                    return [Self.makeMatch(documentId: "d3", volumeId: "frusA", rank: 1,
                                           strategy: .pageRange),
                            Self.makeMatch(documentId: "d3", volumeId: "frusB", rank: 2,
                                           strategy: .pageRange)]
                case 4:   // volume-only result (un-downloaded volume) → unresolved w/ reason
                    return [CitationMatch(documentId: "", volumeId: "frusC", rank: 1,
                                          matchStrategy: .manifestOnly,
                                          confidenceLabel: "Volume identified",
                                          requiresDownload: true)]
                default:  // nothing at all
                    return []
                }
            })

        let text = """
        FRUS, 1969-76, vol. I, doc. 1
        FRUS, 1969-76, vol. I, doc. 2
        FRUS, 1969-76, vol. I, doc. 3
        FRUS, 1969-76, vol. I, doc. 4
        FRUS, 1969-76, vol. I, doc. 5
        not a citation at all
        """
        let results = await resolver.resolve(text: text)
        #expect(results.count == 6)

        // Line 1: lone exact → resolved.
        #expect(results[0].outcome == .resolved(volumeId: "frus1969-76v01",
                                                documentId: "d1", note: nil))
        // Line 2: fuzzy strategy → ambiguous with the engine's rank note.
        guard case .ambiguous(let vol2, let doc2, _) = results[1].outcome else {
            Issue.record("expected ambiguous, got \(results[1].outcome)"); return
        }
        #expect(vol2 == "frus1969-76v01" && doc2 == "d90")
        // Line 3: competing candidates → ambiguous, top match surfaced with count.
        guard case .ambiguous(let vol3, let doc3, let note3) = results[2].outcome else {
            Issue.record("expected ambiguous, got \(results[2].outcome)"); return
        }
        #expect(vol3 == "frusA" && doc3 == "d3")
        #expect(note3.contains("2"))
        // Line 4: volume-only → unresolved carrying the engine's explanation.
        #expect(results[3].outcome == .unresolved(reason: "Volume identified"))
        // Line 5: empty result set → unresolved.
        guard case .unresolved = results[4].outcome else {
            Issue.record("expected unresolved, got \(results[4].outcome)"); return
        }
        // Line 6: unparseable → unresolved, never silently dropped.
        guard case .unresolved = results[5].outcome else {
            Issue.record("expected unresolved, got \(results[5].outcome)"); return
        }
    }

    @Test("AddDocuments citations: a matcher error buckets the line as unresolved")
    func citationLineMatchError() async {
        struct StubError: LocalizedError {
            var errorDescription: String? { "index unavailable" }
        }
        let resolver = CollectionCitationLineResolver(
            parse: { CitationParser().parse($0) },
            match: { _ in throw StubError() })
        let outcome = await resolver.resolve(line: "FRUS, 1969-76, vol. I, doc. 12")
        #expect(outcome == .unresolved(reason: "index unavailable"))
    }

    @Test("AddDocuments citations: a volume-only candidate outranking the document hit downgrades to ambiguous")
    func citationOutrankedByVolumeOnlyCandidate() async {
        // Engine shape when the rank-1 volume isn't downloaded: manifestOnly(volA, rank 1)
        // then exactDocumentNumber(volB, rank 2). The old bucketer filtered volume-only
        // matches away and confidently resolved to volB, discarding the engine's own
        // top-ranked candidate.
        let resolver = CollectionCitationLineResolver(
            parse: { CitationParser().parse($0) },
            match: { _ in
                [CitationMatch(documentId: "", volumeId: "frus1969-76v01", rank: 1,
                               matchStrategy: .manifestOnly,
                               confidenceLabel: "Volume identified — download to find the specific document",
                               requiresDownload: true),
                 Self.makeMatch(documentId: "d4", volumeId: "frus1969-76v02", rank: 2)]
            })
        let outcome = await resolver.resolve(line: "FRUS, 1969-76, vol. I, doc. 4")
        guard case .ambiguous(let vol, let doc, let note) = outcome else {
            Issue.record("expected ambiguous, got \(outcome)"); return
        }
        #expect(vol == "frus1969-76v02" && doc == "d4")
        // The note surfaces the discarded higher-ranked competitor.
        #expect(note.contains("frus1969-76v01"))
    }

    @Test("AddDocuments citations: a parse with no volume identity never resolves confidently")
    func citationNoVolumeIdentityIsAtMostAmbiguous() async {
        // A bare "Document 129" parses with neither subseries nor volume number, so
        // the engine matched against an arbitrary manifest prefix — even a lone
        // exact-strategy hit is a guess, not a resolution.
        let resolver = CollectionCitationLineResolver(
            parse: { line in CitationInput(rawText: line, documentNumber: 129) },
            match: { _ in
                [Self.makeMatch(documentId: "d129", volumeId: "frus1861",
                                strategy: .superimposedDocumentNumber)]
            })
        let outcome = await resolver.resolve(line: "Document 129")
        guard case .ambiguous(let vol, let doc, _) = outcome else {
            Issue.record("expected ambiguous, got \(outcome)"); return
        }
        #expect(vol == "frus1861" && doc == "d129")
    }

    // MARK: - Phase 3: Tag-union gathering

    @Test("AddDocuments tags: note tags ∪ DocumentTagAssignment, deduplicated, notes first")
    @MainActor
    func tagUnionGathering() throws {
        let tagId = UUID()
        let otherTag = UUID()

        let note1 = ResearchNote(documentId: "d1", volumeId: "v1", bodyText: "a")
        note1.userTagIds = [tagId]
        let note2 = ResearchNote(documentId: "d2", volumeId: "v1", bodyText: "b")
        note2.userTagIds = [tagId, otherTag]
        let noteOther = ResearchNote(documentId: "d9", volumeId: "v1", bodyText: "c")
        noteOther.userTagIds = [otherTag]

        let assignments = [
            DocumentTagAssignment(volumeId: "v1", documentId: "d2", tagId: tagId), // dup of note2
            DocumentTagAssignment(volumeId: "v2", documentId: "d3", tagId: tagId), // unique
            DocumentTagAssignment(volumeId: "v2", documentId: "d4", tagId: otherTag), // wrong tag
        ]

        let refs = CollectionDocumentDiscovery.tagDocumentRefs(
            tagId: tagId, notes: [note1, note2, noteOther], assignments: assignments)

        #expect(refs.map { "\($0.volumeId)/\($0.documentId)" } == ["v1/d1", "v1/d2", "v2/d3"])
    }

    // MARK: - Phase 3: Duplicate detection (A4)

    @Test("A4 duplicates: duplicateDocumentKeys flags only repeated document entries")
    @MainActor
    func duplicateKeyDetection() throws {
        let collectionId = UUID()
        func entry(_ doc: String, _ vol: String, kind: CollectionEntryKind = .document,
                   order: Int) -> CollectionEntry {
            let e = CollectionEntry(collectionId: collectionId, documentId: doc,
                                    volumeId: vol, sortOrder: order)
            e.entryKind = kind
            return e
        }
        let entries = [
            entry("d1", "v1", order: 0),
            entry("d2", "v1", order: 1),
            entry("d1", "v1", order: 2),               // duplicate of d1
            entry("d1", "v2", order: 3),               // same doc id, different volume — not a dup
            entry("", "", kind: .heading, order: 4),   // structural entries never count
            entry("", "", kind: .heading, order: 5),
        ]
        let dups = CollectionDocumentDiscovery.duplicateDocumentKeys(in: entries)
        #expect(dups == ["v1/d1"])
    }

    @Test("A4 duplicates: appendEntries no longer skips documents already in the collection")
    @MainActor
    func appendEntriesAllowsDuplicates() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)

        let collection = Collection(name: "Dup Test")
        context.insert(collection)
        var entries: [CollectionEntry] = []

        CollectionDocumentDiscovery.appendEntries(
            [(documentId: "d1", volumeId: "v1"), (documentId: "d2", volumeId: "v1")],
            collection: collection, sortedEntries: &entries, modelContext: context)
        // Re-adding d1 (plus a new d3) appends BOTH — duplicates allowed (A4).
        CollectionDocumentDiscovery.appendEntries(
            [(documentId: "d1", volumeId: "v1"), (documentId: "d3", volumeId: "v2")],
            collection: collection, sortedEntries: &entries, modelContext: context)

        #expect(entries.map(\.documentId) == ["d1", "d2", "d1", "d3"])
        #expect(entries.map(\.sortOrder) == [0, 1, 2, 3])
        #expect(entries.allSatisfy { $0.collection === collection })
        // The repeated document is exactly what the badge set reports.
        #expect(CollectionDocumentDiscovery.duplicateDocumentKeys(in: entries) == ["v1/d1"])
    }

    // MARK: - CollectionOutlineTests (Authoring Phase 4)

    /// Builds one detached entry for outline tests (no persistence needed — the outline
    /// is a pure derivation).
    private func outlineEntry(kind: CollectionEntryKind, level: Int = 1, order: Int,
                              depthOverride: String? = nil,
                              text: String? = nil) -> CollectionEntry {
        let e = CollectionEntry(collectionId: UUID(), documentId: kind == .document ? "d\(order)" : "",
                                volumeId: kind == .document ? "vol" : "", sortOrder: order)
        e.entryKind = kind
        e.level = level
        e.bodyDepthOverride = depthOverride
        e.text = text
        return e
    }

    @Test("Outline: linearize sorts by sortOrder, nests by level, clamps to 1...3, and corrects orphan jumps")
    func outlineLinearization() {
        let h1 = outlineEntry(kind: .heading, level: 1, order: 0)
        let d1 = outlineEntry(kind: .document, order: 1)
        let h2 = outlineEntry(kind: .heading, level: 2, order: 2)
        let d2 = outlineEntry(kind: .document, order: 3)
        let h3 = outlineEntry(kind: .heading, level: 99, order: 4)   // clamps to 3
        let h4 = outlineEntry(kind: .heading, level: -5, order: 5)   // clamps to 1
        let orphan = outlineEntry(kind: .heading, level: 3, order: 6) // jump 1→3: clamps to 2
        let preHeadingDoc = outlineEntry(kind: .document, order: -1)  // before any heading

        // Passed shuffled to prove sortOrder wins.
        let items = CollectionOutline.linearize([h3, d1, orphan, h1, h4, d2, h2, preHeadingDoc])
        #expect(items.map(\.entry.sortOrder) == [-1, 0, 1, 2, 3, 4, 5, 6])
        // Depths: doc before headings = 0; docs take the owning heading's level;
        // 99 clamps to 3 (2+1 also allows 3); -5 clamps to 1; the 1→3 jump clamps to 2.
        #expect(items.map(\.depth) == [0, 1, 1, 2, 2, 3, 1, 2])
        // Linearize never mutates the model.
        #expect(h3.level == 99)
        #expect(orphan.level == 3)

        // A first heading deeper than 1 resolves to 1 (no parent exists).
        let deepFirst = CollectionOutline.linearize([outlineEntry(kind: .heading, level: 3, order: 0)])
        #expect(deepFirst.map(\.depth) == [1])

        // Normalize writes exactly the resolved depths back onto headings.
        CollectionOutline.normalize([h1, d1, h2, d2, h3, h4, orphan, preHeadingDoc])
        #expect(h1.level == 1)
        #expect(h2.level == 2)
        #expect(h3.level == 3)
        #expect(h4.level == 1)
        #expect(orphan.level == 2)
        #expect(preHeadingDoc.level == 1)   // non-headings untouched
    }

    @Test("Outline: sectionRange owns the heading plus everything until a same-or-shallower heading; canIndent/canOutdent enforce the invariants")
    func outlineSectionRangesAndIndentPredicates() {
        // 0:H1 "Part I"  1:doc  2:H2  3:doc  4:H2  5:doc  6:H1 "Part II"  7:doc
        let entries = [
            outlineEntry(kind: .heading, level: 1, order: 0),
            outlineEntry(kind: .document, order: 1),
            outlineEntry(kind: .heading, level: 2, order: 2),
            outlineEntry(kind: .document, order: 3),
            outlineEntry(kind: .heading, level: 2, order: 4),
            outlineEntry(kind: .document, order: 5),
            outlineEntry(kind: .heading, level: 1, order: 6),
            outlineEntry(kind: .document, order: 7),
        ]
        let items = CollectionOutline.linearize(entries)

        // Part I owns itself + everything until Part II (same level).
        #expect(CollectionOutline.sectionRange(of: 0, in: items) == 0..<6)
        // The first H2 owns itself + its doc, stopping at the sibling H2.
        #expect(CollectionOutline.sectionRange(of: 2, in: items) == 2..<4)
        // The second H2 stops at the shallower Part II.
        #expect(CollectionOutline.sectionRange(of: 4, in: items) == 4..<6)
        // The trailing section runs to the end.
        #expect(CollectionOutline.sectionRange(of: 6, in: items) == 6..<8)
        // A non-heading index degenerates to a single-item range.
        #expect(CollectionOutline.sectionRange(of: 1, in: items) == 1..<2)

        // Indent: the first heading never can (no parent); the first H2 can't go to 3
        // (its predecessor is only level 1 — orphan jump); its level-2 sibling can (its
        // predecessor is level 2); Part II (level 1 after a level-2 heading) can indent to 2.
        #expect(!CollectionOutline.canIndent(0, in: items))     // first heading: no parent
        #expect(!CollectionOutline.canIndent(2, in: items))     // 2 → 3 needs prev heading >= 2; H1 is 1
        #expect(CollectionOutline.canIndent(4, in: items))      // sibling H2 → 3 (prev H2 is 2)
        #expect(CollectionOutline.canIndent(6, in: items))      // Part II 1 → 2 (prev level 2 >= 1)
        #expect(!CollectionOutline.canIndent(1, in: items))     // non-heading

        // A max-level heading can't indent even with a deep predecessor.
        let deep = CollectionOutline.linearize([
            outlineEntry(kind: .heading, level: 1, order: 0),
            outlineEntry(kind: .heading, level: 2, order: 1),
            outlineEntry(kind: .heading, level: 3, order: 2),
            outlineEntry(kind: .heading, level: 3, order: 3),
        ])
        #expect(!CollectionOutline.canIndent(3, in: deep))      // 3 is the cap
        #expect(CollectionOutline.canIndent(2, in: deep) == false) // 3 is the cap
        #expect(CollectionOutline.canIndent(1, in: deep) == false) // 2→3 needs prev >= 2; prev is 1

        // Outdent: any heading deeper than 1; never level-1 headings or non-headings.
        #expect(CollectionOutline.canOutdent(2, in: items))
        #expect(CollectionOutline.canOutdent(4, in: items))
        #expect(!CollectionOutline.canOutdent(0, in: items))
        #expect(!CollectionOutline.canOutdent(6, in: items))
        #expect(!CollectionOutline.canOutdent(1, in: items))
    }

    @Test("Outline: ancestor body-depth cascade — a deeper heading's override shadows a shallower ancestor's; a heading without one inherits; siblings reset")
    func outlineAncestorDepthCascade() {
        // 0:H1(index)  1:doc  2:H2(full)  3:doc  4:H2(nil)  5:doc  6:H1(nil)  7:doc
        let refs: [CollectionOutline.StructuralRef] = [
            .init(isHeading: true,  level: 1, bodyDepthOverride: "index"),
            .init(isHeading: false, level: 1, bodyDepthOverride: nil),
            .init(isHeading: true,  level: 2, bodyDepthOverride: "full"),
            .init(isHeading: false, level: 1, bodyDepthOverride: nil),
            .init(isHeading: true,  level: 2, bodyDepthOverride: nil),
            .init(isHeading: false, level: 1, bodyDepthOverride: nil),
            .init(isHeading: true,  level: 1, bodyDepthOverride: nil),
            .init(isHeading: false, level: 1, bodyDepthOverride: nil),
        ]
        let overrides = CollectionOutline.sectionBodyDepthOverrides(refs)
        #expect(overrides[1] == "index")   // under H1(index)
        #expect(overrides[3] == "full")    // level-2 override beats the level-1 ancestor
        #expect(overrides[5] == "index")   // sibling H2 without one inherits the ancestor's
        #expect(overrides[7] == nil)       // new level-1 section resets everything

        // All-level-1 collections behave exactly like the Phase 3c flat rule: a nil
        // override on the nearest heading resets the section (no sibling inheritance).
        let flat: [CollectionOutline.StructuralRef] = [
            .init(isHeading: true,  level: 1, bodyDepthOverride: "index"),
            .init(isHeading: false, level: 1, bodyDepthOverride: nil),
            .init(isHeading: true,  level: 1, bodyDepthOverride: nil),
            .init(isHeading: false, level: 1, bodyDepthOverride: nil),
        ]
        let flatOverrides = CollectionOutline.sectionBodyDepthOverrides(flat)
        #expect(flatOverrides == ["index", "index", nil, nil])

        // Entries before any heading have no section override.
        let preamble: [CollectionOutline.StructuralRef] = [
            .init(isHeading: false, level: 1, bodyDepthOverride: nil),
            .init(isHeading: true,  level: 1, bodyDepthOverride: "index"),
        ]
        #expect(CollectionOutline.sectionBodyDepthOverrides(preamble)[0] == nil)
    }

    @Test("Resolver + outline: a nested section's documents inherit the nearest ancestor override; a synced out-of-range level clamps instead of corrupting")
    @MainActor
    func resolverNestedDepthCascade() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        let appState = AppState()

        let coll = Collection(name: "Nested")
        coll.defaultBodyDepth = "full"
        context.insert(coll)

        let h1 = CollectionEntry(collectionId: coll.id, documentId: "", volumeId: "", sortOrder: 0)
        h1.entryKind = .heading
        h1.text = "Part I"
        h1.bodyDepthOverride = "index"

        let h2 = CollectionEntry(collectionId: coll.id, documentId: "", volumeId: "", sortOrder: 1)
        h2.entryKind = .heading
        h2.text = "Subsection"
        h2.level = 2                       // no override: inherits Part I's "index"
        let d1 = CollectionEntry(collectionId: coll.id, documentId: "d1", volumeId: "nestvol", sortOrder: 2)

        let h3 = CollectionEntry(collectionId: coll.id, documentId: "", volumeId: "", sortOrder: 3)
        h3.entryKind = .heading
        h3.text = "Deep dive"
        h3.level = 42                      // synced junk: clamps (2+1 = 3), never corrupts
        h3.bodyDepthOverride = "summaryOnly"
        let d2 = CollectionEntry(collectionId: coll.id, documentId: "d2", volumeId: "nestvol", sortOrder: 4)

        let entries = [h1, h2, d1, h3, d2]
        for e in entries { context.insert(e) }
        try context.save()

        let resolver = CollectionContentResolver(appState: appState, modelContext: context)
        let items = try await resolver.resolve(collection: coll, entries: entries,
                                               allNotes: [], purpose: .preview)
        let docs = items.documents
        try #require(docs.count == 2)
        #expect(docs[0].bodyDepth == .index)         // inherited from the level-1 ancestor
        #expect(docs[1].bodyDepth == .summaryOnly)   // the deeper heading's own override wins
    }

    // MARK: - NativeCollectionFormat v2 tests (Authoring Phase 4)

    @Test("NativeFormat v2: front matter and heading levels survive export → import; a v1 file leaves the defaults untouched")
    func nativeV2RoundTrip() throws {
        let source = try ModelContainer.makeTestContainer()
        let sourceCtx = ModelContext(source)

        let coll = Collection(name: "Framed", note: "One-liner.")
        coll.subtitle = "Documents and Commentary"
        coll.authorLine = "A. Historian"
        coll.introductionText = "Why these cables matter."
        coll.introductionRichText = Data("{\\rtf1 intro}".utf8)
        coll.includeColophon = true
        sourceCtx.insert(coll)

        let h1 = CollectionEntry(collectionId: coll.id, documentId: "", volumeId: "", sortOrder: 0)
        h1.entryKind = .heading
        h1.text = "Part I"
        h1.collection = coll
        let h2 = CollectionEntry(collectionId: coll.id, documentId: "", volumeId: "", sortOrder: 1)
        h2.entryKind = .heading
        h2.text = "Subsection"
        h2.level = 2
        h2.collection = coll
        let d1 = CollectionEntry(collectionId: coll.id, documentId: "d1", volumeId: "v14", sortOrder: 2)
        d1.collection = coll
        sourceCtx.insert(h1); sourceCtx.insert(h2); sourceCtx.insert(d1)
        try sourceCtx.save()

        let file = NativeCollectionSerializer.makeFile(
            from: coll, includeNotes: false, resolveNoteTexts: { _ in [] })
        #expect(file.formatVersion == 2)
        #expect(file.minimumReaderVersion == 1)   // levels/front matter degrade, never raise

        let data = try NativeCollectionSerializer.encode(file)
        let dest = try ModelContainer.makeTestContainer()
        let destCtx = ModelContext(dest)
        let imported = NativeCollectionSerializer.apply(
            try NativeCollectionSerializer.decode(data), into: destCtx)
        try destCtx.save()

        #expect(imported.subtitle == "Documents and Commentary")
        #expect(imported.authorLine == "A. Historian")
        #expect(imported.introductionText == "Why these cables matter.")
        #expect(imported.introductionRichText == Data("{\\rtf1 intro}".utf8))
        #expect(imported.includeColophon == true)
        let entries = (imported.documentEntries ?? []).sorted { $0.sortOrder < $1.sortOrder }
        try #require(entries.count == 3)
        #expect(entries[0].level == 1)
        #expect(entries[1].level == 2)   // the nested heading survived

        // A v1 file (no v2 keys at all) reconstructs today's defaults.
        let v1JSON = Data(#"{"format":"fruscollection","formatVersion":1,"name":"Old","composition":{"defaultBodyDepth":"full","footnoteStyle":"all","tocStyle":"citation","applyHighlights":false,"includeNotes":true,"includeWordCloud":false},"entries":[{"kind":"heading","text":"Part I"}]}"#.utf8)
        let old = NativeCollectionSerializer.apply(
            try NativeCollectionSerializer.decode(v1JSON), into: destCtx)
        #expect(old.subtitle == nil)
        #expect(old.authorLine == nil)
        #expect(old.introductionText == nil)
        #expect(old.introductionRichText == nil)
        #expect(old.includeColophon == false)
        #expect((old.documentEntries ?? []).first?.level == 1)
    }

    @Test("NativeFormat v2 write-minimum: a collection using no v2 feature emits formatVersion 1 with no v2 keys — byte-identical to a pre-Phase-4 file")
    func nativeV2WriteMinimum() throws {
        let container = try ModelContainer.makeTestContainer()
        let ctx = ModelContext(container)

        // Structure and composition, but nothing Phase 4 added: level-1 headings only,
        // no front matter, colophon off (all the defaults).
        let coll = Collection(name: "Flat", note: "Plain.")
        coll.defaultBodyDepth = "summaryOnly"
        ctx.insert(coll)
        let h = CollectionEntry(collectionId: coll.id, documentId: "", volumeId: "", sortOrder: 0)
        h.entryKind = .heading
        h.text = "Part I"
        h.bodyDepthOverride = "index"
        h.collection = coll
        let d = CollectionEntry(collectionId: coll.id, documentId: "d1", volumeId: "v14", sortOrder: 1)
        d.collection = coll
        ctx.insert(h); ctx.insert(d)
        try ctx.save()

        let file = NativeCollectionSerializer.makeFile(
            from: coll, includeNotes: false, resolveNoteTexts: { _ in [] })
        #expect(file.formatVersion == 1)          // write-minimum, computed from content
        #expect(file.minimumReaderVersion == nil)

        let data = try NativeCollectionSerializer.encode(file)
        let json = String(decoding: data, as: UTF8.self)
        for v2Key in ["minimumReaderVersion", "subtitle", "authorLine",
                      "introductionText", "introductionRichText", "includeColophon", "level",
                      // Phase 5 optional keys — absent from a write-minimum file.
                      "includeFootnotes", "includeSourceNote",
                      "includeHeadnote", "headnoteSummaryId",
                      // Phase 5 excerpt anchors — likewise absent.
                      "excerptStart", "excerptEnd",
                      "excerptRenderingVersion", "excerptColorTag"] {
            #expect(!json.contains("\"\(v2Key)\""), "write-minimum file must not carry '\(v2Key)'")
        }

        // Byte-identity: a pre-Phase-4 serializer would have encoded exactly this DTO —
        // the v1 fields only, formatVersion 1 (the sorted-keys encoder omits every nil
        // v2 key, so the key set — and therefore the bytes — match the old struct's).
        let prePhase4 = FRUSCollectionFile(
            format: "fruscollection",
            formatVersion: 1,
            name: "Flat",
            note: "Plain.",
            composition: .init(defaultBodyDepth: "summaryOnly", footnoteStyle: "all",
                               tocStyle: "citation", applyHighlights: false,
                               includeNotes: true, includeWordCloud: false),
            entries: [
                .init(kind: "heading", documentId: nil, volumeId: nil,
                      bodyDepthOverride: "index", text: "Part I", richText: nil, notes: nil),
                .init(kind: "document", documentId: "d1", volumeId: "v14",
                      bodyDepthOverride: nil, text: nil, richText: nil, notes: nil),
            ])
        #expect(data == (try NativeCollectionSerializer.encode(prePhase4)))

        // Flipping any single v2 feature flips the file to v2.
        coll.includeColophon = true
        let v2 = NativeCollectionSerializer.makeFile(
            from: coll, includeNotes: false, resolveNoteTexts: { _ in [] })
        #expect(v2.formatVersion == 2)
        #expect(v2.minimumReaderVersion == 1)
        coll.includeColophon = false
        h.level = 2   // orphan first heading: resolves to 1, so still NOT a v2 feature
        let stillV1 = NativeCollectionSerializer.makeFile(
            from: coll, includeNotes: false, resolveNoteTexts: { _ in [] })
        #expect(stillV1.formatVersion == 1)
    }

    @Test("NativeFormat v2 tolerant reader: unknown keys are ignored and unknown entry kinds are skipped, never misdecoded")
    func nativeV2ForwardCompat() throws {
        // A hypothetical v3 writer: unknown top-level key, unknown per-entry key, an
        // unknown entry kind — and minimumReaderVersion 1 because it is all degradable.
        let v3JSON = Data("""
        {"format":"fruscollection","formatVersion":3,"minimumReaderVersion":1,
         "name":"Future","futureTopLevelKey":{"nested":true},
         "composition":{"defaultBodyDepth":"full","footnoteStyle":"all","tocStyle":"citation",
                        "applyHighlights":false,"includeNotes":true,"includeWordCloud":false},
         "entries":[
           {"kind":"heading","text":"Part I","level":2,"futureEntryKey":7},
           {"kind":"hologram","documentId":"d9","volumeId":"v9"},
           {"kind":"document","documentId":"d1","volumeId":"v14"}
         ]}
        """.utf8)

        let file = try NativeCollectionSerializer.decode(v3JSON)   // accepted: 1 <= 2
        let container = try ModelContainer.makeTestContainer()
        let ctx = ModelContext(container)
        let imported = NativeCollectionSerializer.apply(file, into: ctx)
        try ctx.save()

        let entries = (imported.documentEntries ?? []).sorted { $0.sortOrder < $1.sortOrder }
        try #require(entries.count == 2)                     // the hologram was skipped
        #expect(entries[0].entryKind == .heading)
        #expect(entries[0].text == "Part I")
        // Import clamps the stored level defensively; here the first heading keeps its
        // file value (2 is within 1...3 — read-time orphan correction is the outline's job).
        #expect(entries[0].level == 2)
        #expect(entries[1].entryKind == .document)
        #expect(entries[1].documentId == "d1")

        // An out-of-range level in a file clamps on import.
        let clampJSON = Data(#"{"format":"fruscollection","formatVersion":2,"minimumReaderVersion":1,"name":"Clamp","composition":{"defaultBodyDepth":"full","footnoteStyle":"all","tocStyle":"citation","applyHighlights":false,"includeNotes":true,"includeWordCloud":false},"entries":[{"kind":"heading","text":"Deep","level":99}]}"#.utf8)
        let clamped = NativeCollectionSerializer.apply(
            try NativeCollectionSerializer.decode(clampJSON), into: ctx)
        #expect((clamped.documentEntries ?? []).first?.level == 3)
    }

    @Test("NativeFormat v2: minimumReaderVersion gates decoding — a required-3 file rejects; formatVersion 3 with floor 1 accepts; legacy formatVersion-only files keep their gate")
    func nativeV2MinimumReaderVersion() throws {
        let composition = #""composition":{"defaultBodyDepth":"full","footnoteStyle":"all","tocStyle":"citation","applyHighlights":false,"includeNotes":true,"includeWordCloud":false}"#

        // A file that *requires* a version-3 reader rejects, whatever its formatVersion.
        let requires3 = Data(#"{"format":"fruscollection","formatVersion":3,"minimumReaderVersion":3,"name":"x",\#(composition),"entries":[]}"#.utf8)
        #expect(throws: NativeCollectionError.self) {
            try NativeCollectionSerializer.decode(requires3)
        }

        // A newer file whose features degrade (floor 1) accepts.
        let degradable3 = Data(#"{"format":"fruscollection","formatVersion":3,"minimumReaderVersion":1,"name":"x",\#(composition),"entries":[]}"#.utf8)
        #expect(try NativeCollectionSerializer.decode(degradable3).formatVersion == 3)

        // No minimumReaderVersion: formatVersion is the gate (v1 semantics preserved) —
        // 2 accepts (defaulted floor 2 <= 2), 3 rejects.
        let bare2 = Data(#"{"format":"fruscollection","formatVersion":2,"name":"x",\#(composition),"entries":[]}"#.utf8)
        #expect(try NativeCollectionSerializer.decode(bare2).minimumReaderVersion == nil)
        let bare3 = Data(#"{"format":"fruscollection","formatVersion":3,"name":"x",\#(composition),"entries":[]}"#.utf8)
        #expect(throws: NativeCollectionError.self) {
            try NativeCollectionSerializer.decode(bare3)
        }
    }

    @Test("Front matter defaults: a new collection carries no front matter and no colophon (pre-Phase-4 behavior)")
    func frontMatterDefaults() {
        let collection = Collection(name: "Defaults")
        #expect(collection.subtitle == nil)
        #expect(collection.authorLine == nil)
        #expect(collection.introductionText == nil)
        #expect(collection.introductionRichText == nil)
        #expect(collection.includeColophon == false)
        let entry = CollectionEntry(collectionId: collection.id, documentId: "d1",
                                    volumeId: "v1", sortOrder: 0)
        #expect(entry.level == 1)
    }

    // MARK: - Footnote pair + headnotes (Authoring Phase 5)

    @Test("Footnote pair derivation: a nil pair derives each legacy tri-state value exactly; unknown raw values fall back like .all")
    func footnotePairDerivation() {
        // The mapping contract: all→(true,false), sourceNoteOnly→(false,true),
        // none→(false,false) — an untouched collection composes exactly as before.
        let cases: [(style: String, footnotes: Bool, sourceNote: Bool)] = [
            ("all",            true,  false),
            ("sourceNoteOnly", false, true),
            ("none",           false, false),
            ("garbage",        true,  false),   // unknown raw → the legacy `?? .all` fallback
        ]
        for c in cases {
            let coll = Collection(name: "Derive-\(c.style)")
            coll.footnoteStyle = c.style
            #expect(coll.includeFootnotes == nil)      // untouched: pair stays nil
            #expect(coll.includeSourceNote == nil)
            #expect(coll.effectiveIncludeFootnotes == c.footnotes,
                    "style \(c.style) should derive includeFootnotes=\(c.footnotes)")
            #expect(coll.effectiveIncludeSourceNote == c.sourceNote,
                    "style \(c.style) should derive includeSourceNote=\(c.sourceNote)")
        }
    }

    @Test("Footnote pair end-to-end: the resolver's options carry the derived pair for every legacy style, and an explicit pair overrides")
    @MainActor
    func footnotePairResolutionOptions() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        let resolver = CollectionContentResolver(appState: AppState(), modelContext: context)

        let coll = Collection(name: "Options")
        for (style, footnotes, sourceNote) in [("all", true, false),
                                               ("sourceNoteOnly", false, true),
                                               ("none", false, false)] {
            coll.footnoteStyle = style
            coll.includeFootnotes = nil
            coll.includeSourceNote = nil
            let options = resolver.resolutionOptions(for: coll)
            #expect(options.includeFootnotes == footnotes, "style \(style)")
            #expect(options.includeSourceNote == sourceNote, "style \(style)")
        }

        // The previously inexpressible combination: footnotes AND the source note.
        coll.effectiveIncludeFootnotes = true
        coll.effectiveIncludeSourceNote = true
        let both = resolver.resolutionOptions(for: coll)
        #expect(both.includeFootnotes == true)
        #expect(both.includeSourceNote == true)
    }

    @Test("Footnote pair setters: writes freeze both Bools and keep a best-fit legacy footnoteStyle for old readers; (true,true) writes 'all'")
    func footnotePairWriteThrough() {
        // Toggling one flag must freeze the OTHER's currently-derived value first —
        // otherwise rewriting footnoteStyle would silently flip the untouched flag.
        let coll = Collection(name: "Freeze")
        coll.footnoteStyle = "sourceNoteOnly"          // derived pair: (false, true)
        coll.effectiveIncludeFootnotes = true          // user turns footnotes ON
        #expect(coll.includeFootnotes == true)
        #expect(coll.includeSourceNote == true)        // frozen, not re-derived from "all"
        #expect(coll.effectiveIncludeSourceNote == true)
        // (true, true) is inexpressible in the tri-state: best fit writes "all".
        #expect(coll.footnoteStyle == "all")

        // Each expressible pair round-trips to its exact legacy raw value.
        coll.effectiveIncludeSourceNote = false        // (true, false)
        #expect(coll.footnoteStyle == "all")
        coll.effectiveIncludeFootnotes = false         // (false, false)
        #expect(coll.footnoteStyle == "none")
        coll.effectiveIncludeSourceNote = true         // (false, true)
        #expect(coll.footnoteStyle == "sourceNoteOnly")
    }

    @Test("Resolver headnote: chosen summary id wins; nil id prefers the collection prompt's summary; nothing stored keeps a nil headnote (never generates)")
    @MainActor
    func resolverHeadnoteResolution() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        let appState = AppState()

        let promptId = UUID()
        let coll = Collection(name: "Headnotes")
        coll.summaryPromptId = promptId
        context.insert(coll)

        let entry = CollectionEntry(collectionId: coll.id, documentId: "d1",
                                    volumeId: "hnvol", sortOrder: 0)
        entry.includeHeadnote = true
        context.insert(entry)
        try context.save()

        let resolver = CollectionContentResolver(appState: appState, modelContext: context)

        // Nothing stored: the headnote request travels, the text stays nil — headnote
        // resolution never generates, in either purpose.
        let missing = try await resolver.resolve(collection: coll, entries: [entry],
                                                 allNotes: [], purpose: .preview)
        let missingDoc = try #require(docPayload(missing[0]))
        #expect(missingDoc.includeHeadnote == true)
        #expect(missingDoc.headnoteText == nil)

        // Two stored summaries: with a nil pick, the collection's prompt is preferred.
        let other = GeneratedSummary(documentId: "d1", volumeId: "hnvol",
                                     promptId: UUID(), responseText: "Other prompt summary.")
        let preferred = GeneratedSummary(documentId: "d1", volumeId: "hnvol",
                                         promptId: promptId, responseText: "Preferred prompt summary.")
        context.insert(other)
        context.insert(preferred)
        try context.save()
        let auto = try await resolver.resolve(collection: coll, entries: [entry],
                                              allNotes: [], purpose: .preview)
        #expect(try #require(docPayload(auto[0])).headnoteText == "Preferred prompt summary.")

        // An explicit pick wins over the prompt preference.
        entry.headnoteSummaryId = other.id
        let chosen = try await resolver.resolve(collection: coll, entries: [entry],
                                                allNotes: [], purpose: .preview)
        #expect(try #require(docPayload(chosen[0])).headnoteText == "Other prompt summary.")

        // A dangling pick (deleted summary) falls back rather than dropping the headnote.
        entry.headnoteSummaryId = UUID()
        let dangling = try await resolver.resolve(collection: coll, entries: [entry],
                                                  allNotes: [], purpose: .preview)
        #expect(try #require(docPayload(dangling[0])).headnoteText == "Preferred prompt summary.")

        // An entry that never asked for a headnote carries neither flag nor text.
        entry.includeHeadnote = false
        let off = try await resolver.resolve(collection: coll, entries: [entry],
                                             allNotes: [], purpose: .preview)
        let offDoc = try #require(docPayload(off[0]))
        #expect(offDoc.includeHeadnote == false)
        #expect(offDoc.headnoteText == nil)
    }

    @Test("Headnote rendering: the italic abstract (or its placeholder) appears in HTML, DOCX, and PDF only when the entry requested one")
    func headnoteAcrossFormats() async throws {
        let withHeadnote = CollectionExportDocument(
            documentId: "d1", volumeId: "hnvol", sortOrder: 1,
            title: "Headnoted Memo", bodyText: "Headnoted body paragraph.",
            citation: "Headnoted Citation",
            includeHeadnote: true, headnoteText: "A concise scholarly abstract.")
        let placeholder = CollectionExportDocument(
            documentId: "d2", volumeId: "hnvol", sortOrder: 2,
            title: "Pending Memo", bodyText: "Pending body paragraph.",
            citation: "Pending Citation",
            includeHeadnote: true, headnoteText: nil)
        let plain = CollectionExportDocument(
            documentId: "d3", volumeId: "hnvol", sortOrder: 3,
            title: "Plain Memo", bodyText: "Plain body paragraph.",
            citation: "Plain Citation")
        let items: [CollectionExportItem] = [
            .document(withHeadnote), .document(placeholder), .document(plain)]
        let plainItems: [CollectionExportItem] = [.document(plain)]
        // Name must not contain "Headnote" — the absence assertions scan whole outputs.
        let metadata = CollectionExportMetadata(name: "Abstract Fixture", note: nil)

        // HTML — headnote block, the abstract, and the placeholder note; the headnote
        // stylesheet is emitted only on this page, never for a headnote-free one.
        let htmlURL = try await HTMLCollectionExporter().export(metadata: metadata, items: items)
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        #expect(html.contains("class=\"headnote\""))
        #expect(html.contains("<em>A concise scholarly abstract.</em>"))
        #expect(html.contains("class=\"headnote-missing\""))
        #expect(html.contains("No stored summary for this document"))
        let htmlOffURL = try await HTMLCollectionExporter().export(metadata: metadata, items: plainItems)
        let htmlOff = try String(contentsOf: htmlOffURL, encoding: .utf8)
        #expect(!htmlOff.contains("headnote"))

        // DOCX — label + italic abstract + placeholder; absent without a request.
        let docx = try Data(contentsOf: try await DocxCollectionExporter().export(
            metadata: metadata, items: items))
        func docxContains(_ s: String) -> Bool { docx.range(of: Data(s.utf8)) != nil }
        #expect(docxContains("Headnote"))
        #expect(docxContains("A concise scholarly abstract."))
        #expect(docxContains("No stored summary for this document"))
        let docxOff = try Data(contentsOf: try await DocxCollectionExporter().export(
            metadata: metadata, items: plainItems))
        #expect(docxOff.range(of: Data("Headnote".utf8)) == nil)

        // PDF — extract page text with PDFKit.
        let pdf = try Data(contentsOf: try await PDFCollectionExporter().export(
            metadata: metadata, items: items))
        let pdfDoc = try #require(PDFDocument(data: pdf))
        let pdfText = (0..<pdfDoc.pageCount)
            .compactMap { pdfDoc.page(at: $0)?.string }.joined(separator: "\n")
        #expect(pdfText.contains("Headnote"))
        #expect(pdfText.contains("A concise scholarly abstract."))
        #expect(pdfText.contains("No stored summary for this document"))
        let pdfOff = try Data(contentsOf: try await PDFCollectionExporter().export(
            metadata: metadata, items: plainItems))
        let pdfOffDoc = try #require(PDFDocument(data: pdfOff))
        let pdfOffText = (0..<pdfOffDoc.pageCount)
            .compactMap { pdfOffDoc.page(at: $0)?.string }.joined(separator: "\n")
        #expect(!pdfOffText.contains("Headnote"))
    }

    @Test("HTML footnote gate: options.includeFootnotes drives footnote emission for a rendered model — the legacy .all/.none behaviors, now independently combinable with the source note")
    func htmlFootnoteGate() {
        let model = FRUSDocumentRenderModel(
            documentId: "d1",
            bodyNodes: [.paragraph([.plainText("Gated body."),
                                    .footnoteMarker(id: "fn1", displayLabel: "1")])],
            footnotes: [.footnoteBody(id: "fn1", type: .editorial, printedNumber: "1",
                                      sequentialNumber: 1, displayLabel: "1",
                                      children: [.plainText("The footnote text.")])])
        let doc = CollectionExportDocument(
            documentId: "d1", volumeId: "fnvol", sortOrder: 1,
            title: "Footnoted", bodyText: "Gated body.",
            citation: "Footnoted Citation", renderModel: model,
            sourceNoteText: "RG 59, Central Files.")
        let items: [CollectionExportItem] = [.document(doc)]
        let metadata = CollectionExportMetadata(name: "Gate", note: nil)

        // includeFootnotes=true (legacy .all): footnote text renders; source note renders
        // too — the combination the tri-state could never express.
        var options = CollectionExportOptions()
        options.includeFootnotes = true
        options.includeSourceNote = true
        let on = CollectionItemHTMLRenderer(options: options).pageHTML(metadata: metadata, items: items)
        #expect(on.contains("The footnote text."))
        #expect(on.contains("RG 59, Central Files."))

        // includeFootnotes=false (legacy .none/.sourceNoteOnly): footnotes are stripped.
        options.includeFootnotes = false
        let off = CollectionItemHTMLRenderer(options: options).pageHTML(metadata: metadata, items: items)
        #expect(!off.contains("The footnote text."))
        #expect(off.contains("RG 59, Central Files."))   // source note is independent now
    }

    @Test("NativeFormat v2 Phase 5 keys: footnote pair and headnote fields round-trip; absent keys leave the model defaults (nil pair, no headnote)")
    func nativePhase5RoundTrip() throws {
        let container = try ModelContainer.makeTestContainer()
        let sourceCtx = ModelContext(container)

        let coll = Collection(name: "P5")
        coll.effectiveIncludeFootnotes = true
        coll.effectiveIncludeSourceNote = true
        sourceCtx.insert(coll)
        let pickedSummaryId = UUID()
        let d = CollectionEntry(collectionId: coll.id, documentId: "d1", volumeId: "v1", sortOrder: 0)
        d.includeHeadnote = true
        d.headnoteSummaryId = pickedSummaryId
        d.collection = coll
        sourceCtx.insert(d)
        try sourceCtx.save()

        let file = NativeCollectionSerializer.makeFile(
            from: coll, includeNotes: false, resolveNoteTexts: { _ in [] })
        // Phase 5 features ride v2 under the tolerant reader — no new bump, floor stays 1.
        #expect(file.formatVersion == 2)
        #expect(file.minimumReaderVersion == 1)
        #expect(file.composition.includeFootnotes == true)
        #expect(file.composition.includeSourceNote == true)
        #expect(file.composition.footnoteStyle == "all")   // legacy raw still written
        #expect(file.entries.first?.includeHeadnote == true)
        #expect(file.entries.first?.headnoteSummaryId == pickedSummaryId)

        // encode → decode → apply reconstructs everything.
        let data = try NativeCollectionSerializer.encode(file)
        let destContainer = try ModelContainer.makeTestContainer()
        let destCtx = ModelContext(destContainer)
        let imported = NativeCollectionSerializer.apply(
            try NativeCollectionSerializer.decode(data), into: destCtx)
        try destCtx.save()
        #expect(imported.includeFootnotes == true)
        #expect(imported.includeSourceNote == true)
        #expect(imported.footnoteStyle == "all")
        let importedEntry = try #require((imported.documentEntries ?? []).first)
        #expect(importedEntry.includeHeadnote == true)
        #expect(importedEntry.headnoteSummaryId == pickedSummaryId)

        // A v1 file (no Phase 5 keys) leaves the defaults: nil pair, headnote off.
        let v1JSON = Data(#"{"format":"fruscollection","formatVersion":1,"name":"Old","composition":{"defaultBodyDepth":"full","footnoteStyle":"sourceNoteOnly","tocStyle":"citation","applyHighlights":false,"includeNotes":true,"includeWordCloud":false},"entries":[{"kind":"document","documentId":"d1","volumeId":"v1"}]}"#.utf8)
        let old = NativeCollectionSerializer.apply(
            try NativeCollectionSerializer.decode(v1JSON), into: destCtx)
        #expect(old.includeFootnotes == nil)
        #expect(old.includeSourceNote == nil)
        #expect(old.effectiveIncludeSourceNote == true)   // derived from the legacy style
        let oldEntry = try #require((old.documentEntries ?? []).first)
        #expect(oldEntry.includeHeadnote == false)
        #expect(oldEntry.headnoteSummaryId == nil)
    }

    @Test("NativeFormat write-minimum: any Phase 5 feature — a pair member or a headnote — flips the file to v2; clearing them restores v1")
    func nativePhase5WriteMinimumFlips() throws {
        let container = try ModelContainer.makeTestContainer()
        let ctx = ModelContext(container)
        let coll = Collection(name: "Flip")
        ctx.insert(coll)
        let d = CollectionEntry(collectionId: coll.id, documentId: "d1", volumeId: "v1", sortOrder: 0)
        d.collection = coll
        ctx.insert(d)
        try ctx.save()

        func makeFile() -> FRUSCollectionFile {
            NativeCollectionSerializer.makeFile(
                from: coll, includeNotes: false, resolveNoteTexts: { _ in [] })
        }
        #expect(makeFile().formatVersion == 1)             // untouched: write-minimum v1

        coll.includeFootnotes = true                       // one pair member set → v2
        #expect(makeFile().formatVersion == 2)
        coll.includeFootnotes = nil
        #expect(makeFile().formatVersion == 1)

        d.includeHeadnote = true                           // a headnote request → v2
        #expect(makeFile().formatVersion == 2)
        d.includeHeadnote = false
        #expect(makeFile().formatVersion == 1)

        d.headnoteSummaryId = UUID()                       // a pick alone → v2
        #expect(makeFile().formatVersion == 2)
        d.headnoteSummaryId = nil
        #expect(makeFile().formatVersion == 1)
    }

    // MARK: - Excerpt entries (Authoring Phase 5)

    @Test("Excerpt factory: highlight → capture → entry copies passage, provenance, anchors, and colour; textless highlights yield no capture")
    @MainActor
    func excerptFactoryFieldCopy() throws {
        let highlight = DocumentHighlight(
            volumeId: "frus1969-76v01", documentId: "d42",
            startOffset: 120, endOffset: 168,
            colorTag: "blue",
            selectedText: "The frozen verbatim passage.",
            renderingVersion: "abcdef0123456789")

        let capture = try #require(CollectionExcerpts.capture(from: highlight))
        #expect(capture.text == "The frozen verbatim passage.")
        #expect(capture.volumeId == "frus1969-76v01")
        #expect(capture.documentId == "d42")
        #expect(capture.start == 120)
        #expect(capture.end == 168)
        #expect(capture.renderingVersion == "abcdef0123456789")
        #expect(capture.colorTag == "blue")

        let collectionId = UUID()
        let entry = CollectionExcerpts.makeEntry(from: capture, collectionId: collectionId,
                                                 sortOrder: 3)
        #expect(entry.entryKind == .excerpt)
        #expect(entry.kind == "excerpt")
        #expect(entry.text == "The frozen verbatim passage.")
        #expect(entry.documentId == "d42")
        #expect(entry.volumeId == "frus1969-76v01")
        #expect(entry.sortOrder == 3)
        #expect(entry.excerptStart == 120)
        #expect(entry.excerptEnd == 168)
        #expect(entry.excerptRenderingVersion == "abcdef0123456789")
        #expect(entry.excerptColorTag == "blue")

        // A pre-Session-131 highlight (no stored text) has no passage to freeze.
        let textless = DocumentHighlight(
            volumeId: "v", documentId: "d1", startOffset: 0, endOffset: 5,
            selectedText: "", renderingVersion: "ffff000011112222")
        #expect(CollectionExcerpts.capture(from: textless) == nil)

        // A text-only selection capture (footnote selection: no offsets, no version)
        // still freezes into a valid entry with nil anchors.
        let selectionOnly = CollectionExcerptCapture(
            text: "Footnote passage.", volumeId: "v", documentId: "d2",
            start: nil, end: nil, renderingVersion: nil, colorTag: nil)
        let plainEntry = CollectionExcerpts.makeEntry(from: selectionOnly,
                                                      collectionId: collectionId, sortOrder: 0)
        #expect(plainEntry.entryKind == .excerpt)
        #expect(plainEntry.excerptStart == nil)
        #expect(plainEntry.excerptEnd == nil)
        #expect(plainEntry.excerptRenderingVersion == nil)
        #expect(plainEntry.excerptColorTag == nil)
    }

    @Test("Resolver excerpt pass-through: frozen text + citation fallback + colour; empty-text excerpts are skipped; the source volume is never required")
    @MainActor
    func resolverExcerptPassThrough() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        let appState = AppState()   // no downloadManager/pipeline — nothing to parse

        let coll = Collection(name: "Excerpted")
        context.insert(coll)

        let h = CollectionEntry(collectionId: coll.id, documentId: "", volumeId: "", sortOrder: 0)
        h.entryKind = .heading
        h.text = "Part I"

        let ex = CollectionEntry(collectionId: coll.id, documentId: "d7",
                                 volumeId: "excerptvol", sortOrder: 1)
        ex.entryKind = .excerpt
        ex.text = "Quoted passage.\n\nSecond paragraph."
        ex.excerptStart = 10
        ex.excerptEnd = 55
        ex.excerptRenderingVersion = "0011223344556677"
        ex.excerptColorTag = "pink"

        let empty = CollectionEntry(collectionId: coll.id, documentId: "d8",
                                    volumeId: "excerptvol", sortOrder: 2)
        empty.entryKind = .excerpt
        empty.text = ""    // malformed: nothing to quote — skipped defensively

        for entry in [h, ex, empty] { context.insert(entry) }
        try context.save()

        let resolver = CollectionContentResolver(appState: appState, modelContext: context)
        let items = try await resolver.resolve(
            collection: coll, entries: [ex, empty, h], allNotes: [], purpose: .preview)

        #expect(items.map(kindLabel) == ["heading", "excerpt"])
        guard case .excerpt(let payload) = items[1] else {
            Issue.record("items[1] should be an excerpt")
            return
        }
        #expect(payload.text == "Quoted passage.\n\nSecond paragraph.")   // verbatim
        #expect(payload.documentId == "d7")
        #expect(payload.volumeId == "excerptvol")
        #expect(payload.citation == "excerptvol/d7")   // manifest-less fallback, like documents
        #expect(payload.colorTag == "pink")
        #expect(payload.color == .pink)
    }

    @Test("NativeFormat excerpts: any excerpt forces v2 (a v1 reader can never see one); content + anchors round-trip; the source highlight's UUID never serializes")
    @MainActor
    func nativeExcerptRoundTrip() throws {
        let container = try ModelContainer.makeTestContainer()
        let sourceCtx = ModelContext(container)

        let coll = Collection(name: "Quotations")
        sourceCtx.insert(coll)
        let highlight = DocumentHighlight(
            volumeId: "frus1969-76v01", documentId: "d42",
            startOffset: 5, endOffset: 30, colorTag: "yellow",
            selectedText: "A quoted line of despatch text.",
            renderingVersion: "1234abcd5678ef90")
        sourceCtx.insert(highlight)
        let capture = try #require(CollectionExcerpts.capture(from: highlight))
        let entry = CollectionExcerpts.makeEntry(from: capture, collectionId: coll.id,
                                                 sortOrder: 0)
        entry.collection = coll
        sourceCtx.insert(entry)
        try sourceCtx.save()

        func makeFile() -> FRUSCollectionFile {
            NativeCollectionSerializer.makeFile(
                from: coll, includeNotes: false, resolveNoteTexts: { _ in [] })
        }

        // Write-minimum can't apply once an excerpt exists: the file is v2, so an
        // old-style (v1-only) reader never sees the excerpt kind at all.
        let file = makeFile()
        #expect(file.formatVersion == 2)
        #expect(file.minimumReaderVersion == 1)
        let fileEntry = try #require(file.entries.first)
        #expect(fileEntry.kind == "excerpt")
        #expect(fileEntry.text == "A quoted line of despatch text.")
        #expect(fileEntry.documentId == "d42")
        #expect(fileEntry.volumeId == "frus1969-76v01")
        #expect(fileEntry.excerptStart == 5)
        #expect(fileEntry.excerptEnd == 30)
        #expect(fileEntry.excerptRenderingVersion == "1234abcd5678ef90")
        #expect(fileEntry.excerptColorTag == "yellow")

        // Content + colour + provenance + anchors — NEVER the highlight's UUID.
        let json = String(decoding: try NativeCollectionSerializer.encode(file), as: UTF8.self)
        #expect(!json.contains(highlight.id.uuidString))

        // Round-trip onto a fresh store reconstructs the excerpt entry.
        let destContainer = try ModelContainer.makeTestContainer()
        let destCtx = ModelContext(destContainer)
        let imported = NativeCollectionSerializer.apply(
            try NativeCollectionSerializer.decode(Data(json.utf8)), into: destCtx)
        try destCtx.save()
        let importedEntry = try #require((imported.documentEntries ?? []).first)
        #expect(importedEntry.entryKind == .excerpt)
        #expect(importedEntry.text == "A quoted line of despatch text.")
        #expect(importedEntry.documentId == "d42")
        #expect(importedEntry.volumeId == "frus1969-76v01")
        #expect(importedEntry.excerptStart == 5)
        #expect(importedEntry.excerptEnd == 30)
        #expect(importedEntry.excerptRenderingVersion == "1234abcd5678ef90")
        #expect(importedEntry.excerptColorTag == "yellow")

        // Deleting the excerpt restores the v1 write-minimum (nothing else v2 here).
        sourceCtx.delete(entry)
        try sourceCtx.save()
        #expect(makeFile().formatVersion == 1)

        // Tolerant reader: a hypothetical FUTURE kind in a v2 file still skips —
        // excerpts didn't weaken the unknown-kind guard.
        let futureJSON = Data(#"{"format":"fruscollection","formatVersion":2,"minimumReaderVersion":1,"name":"F","composition":{"defaultBodyDepth":"full","footnoteStyle":"all","tocStyle":"citation","applyHighlights":false,"includeNotes":true,"includeWordCloud":false},"entries":[{"kind":"hologram","text":"x"},{"kind":"excerpt","documentId":"d1","volumeId":"v1","text":"Kept."}]}"#.utf8)
        let futureImport = NativeCollectionSerializer.apply(
            try NativeCollectionSerializer.decode(futureJSON), into: destCtx)
        let futureEntries = (futureImport.documentEntries ?? [])
        try #require(futureEntries.count == 1)          // hologram skipped, excerpt kept
        #expect(futureEntries[0].entryKind == .excerpt)
        #expect(futureEntries[0].text == "Kept.")
    }

    @Test("Move engine: excerpt entries move as single rows (like prose) and travel inside their section's block")
    func excerptMovesLikeProse() {
        // Model-backed: [H A, excerpt, doc, H B, doc] — dragging H A to the end takes
        // its excerpt and document along as one block.
        let hA = outlineEntry(kind: .heading, level: 1, order: 0, text: "A")
        let ex = outlineEntry(kind: .excerpt, order: 1, text: "Quoted.")
        let d1 = outlineEntry(kind: .document, order: 2)
        let hB = outlineEntry(kind: .heading, level: 1, order: 3, text: "B")
        let d2 = outlineEntry(kind: .document, order: 4)
        let entries = [hA, ex, d1, hB, d2]

        let sectionMove = CollectionOutline.applyingMove(entries, fromIndex: 0, toOffset: 5)
        #expect(sectionMove?.map(\.text) == [Optional("B"), nil, Optional("A"), Optional("Quoted."), nil])

        // The excerpt itself moves as a single row (non-heading), with onMove semantics:
        // dropped at the very end, past H B's document.
        let rowMove = CollectionOutline.applyingMove(entries, fromIndex: 1, toOffset: 5)
        #expect(rowMove?.map(\.text) == [Optional("A"), nil, Optional("B"), nil, Optional("Quoted.")])
        // Self-drop is a no-op, exactly like prose/document rows.
        #expect(CollectionOutline.applyingMove(entries, fromIndex: 1, toOffset: 2) == nil)

        // The editors' post-move tail applies unchanged: reindex leaves 0..n.
        for (i, e) in (rowMove ?? []).enumerated() { e.sortOrder = i }
        #expect(rowMove?.map(\.sortOrder) == [0, 1, 2, 3, 4])
    }

    // MARK: - Outline editor engine tests (Authoring Phase 4, editor step)

    /// Structural shorthand for the pure move/collapse cores.
    private func ref(heading: Bool, level: Int = 1) -> CollectionOutline.StructuralRef {
        .init(isHeading: heading, level: level, bodyDepthOverride: nil)
    }

    @Test("Move engine: a heading drags its whole section; self-drops are refused; documents keep single-row moves; applyingMove + reindex leaves sortOrder 0..n")
    func outlineMoveEngine() {
        // 0:H-A  1:doc  2:doc  3:H-B  4:doc  5:H-B2(l2)  6:doc  7:H-C  8:doc
        let refs: [CollectionOutline.StructuralRef] = [
            ref(heading: true),  ref(heading: false), ref(heading: false),
            ref(heading: true),  ref(heading: false), ref(heading: true, level: 2),
            ref(heading: false), ref(heading: true),  ref(heading: false),
        ]

        // Section A (0..<3) dropped before H-C: B's whole section slides up.
        #expect(CollectionOutline.movedOrder(refs, fromIndex: 0, toOffset: 7)
                == [3, 4, 5, 6, 0, 1, 2, 7, 8])
        // Section B (3..<7, including its level-2 subsection) dropped at the very top.
        #expect(CollectionOutline.movedOrder(refs, fromIndex: 3, toOffset: 0)
                == [3, 4, 5, 6, 0, 1, 2, 7, 8])
        // The level-2 subsection (5..<7) moves as its own block, out past H-C.
        #expect(CollectionOutline.movedOrder(refs, fromIndex: 5, toOffset: 8)
                == [0, 1, 2, 3, 4, 7, 5, 6, 8])
        // Dropping section B into its own range is forbidden — anywhere from its start
        // through the slot just past its end (which is also the no-op position).
        #expect(CollectionOutline.movedOrder(refs, fromIndex: 3, toOffset: 3) == nil)
        #expect(CollectionOutline.movedOrder(refs, fromIndex: 3, toOffset: 5) == nil)
        #expect(CollectionOutline.movedOrder(refs, fromIndex: 3, toOffset: 7) == nil)
        // ...but one slot further actually moves it below H-C's row.
        #expect(CollectionOutline.movedOrder(refs, fromIndex: 3, toOffset: 8)
                == [0, 1, 2, 7, 3, 4, 5, 6, 8])
        // A document moves as a single row with SwiftUI onMove semantics.
        #expect(CollectionOutline.movedOrder(refs, fromIndex: 1, toOffset: 5)
                == [0, 2, 3, 4, 1, 5, 6, 7, 8])
        // Single-row no-ops: dropping onto itself or the slot just past it.
        #expect(CollectionOutline.movedOrder(refs, fromIndex: 1, toOffset: 1) == nil)
        #expect(CollectionOutline.movedOrder(refs, fromIndex: 1, toOffset: 2) == nil)
        // Out-of-range inputs are refused, never trap.
        #expect(CollectionOutline.movedOrder(refs, fromIndex: 99, toOffset: 0) == nil)
        #expect(CollectionOutline.movedOrder(refs, fromIndex: 0, toOffset: 99) == nil)

        // Model-backed wrapper: same move, then the editor's reindex leaves 0..n.
        let entries = [
            outlineEntry(kind: .heading,  level: 1, order: 0, text: "A"),
            outlineEntry(kind: .document, order: 1),
            outlineEntry(kind: .heading,  level: 1, order: 2, text: "B"),
            outlineEntry(kind: .document, order: 3),
        ]
        let moved = CollectionOutline.applyingMove(entries, fromIndex: 0, toOffset: 4)
        #expect(moved?.map(\.text) == [Optional("B"), nil, Optional("A"), nil])
        for (i, e) in (moved ?? []).enumerated() { e.sortOrder = i }
        #expect(moved?.map(\.sortOrder) == [0, 1, 2, 3])
        // A heading dropped into its own section leaves the model untouched.
        #expect(CollectionOutline.applyingMove(entries, fromIndex: 2, toOffset: 3) == nil)
    }

    @Test("Move engine: the editors' post-move tail (reindex THEN normalize) persists resolved levels — a level-2 section dragged to the top is written back at level 1")
    func outlineMoveThenReindexThenNormalize() throws {
        // Regression guard for the macOS Phase 4 review fix: normalize linearizes by
        // `sortOrder`, so running it BEFORE reindexing sees the stale pre-move order,
        // silently no-ops, and lets the orphan level persist (the section would then
        // re-nest under a sibling on a later drag). Both editors must reindex first.
        // 0:H-A(1)  1:doc  2:H-B(1)  3:H-C(2)  4:doc — drag H-C's section to the top.
        let hA = outlineEntry(kind: .heading, level: 1, order: 0, text: "A")
        let d1 = outlineEntry(kind: .document, order: 1)
        let hB = outlineEntry(kind: .heading, level: 1, order: 2, text: "B")
        let hC = outlineEntry(kind: .heading, level: 2, order: 3, text: "C")
        let d2 = outlineEntry(kind: .document, order: 4)

        let reordered = try #require(CollectionOutline.applyingMove(
            [hA, d1, hB, hC, d2], fromIndex: 3, toOffset: 0))
        // H-C's section (the heading + the trailing doc) leads the new order.
        #expect(reordered.map(\.text) == [Optional("C"), nil, Optional("A"), nil, Optional("B")])

        // The shared mutation tail, in the editors' order: reindex sortOrder 0..n FIRST,
        // then normalize against the now-current order.
        for (i, entry) in reordered.enumerated() { entry.sortOrder = i }
        CollectionOutline.normalize(reordered)

        // H-C now opens the outline, so its stored level must be written back to 1 —
        // not left at the stale 2 the reversed (normalize-first) order preserved.
        #expect(hC.level == 1)
        #expect(hA.level == 1)
        #expect(hB.level == 1)
    }

    @Test("Indent/outdent: the section shifts as a unit (descendant headings included), clamps at the cap, and normalize keeps the invariants")
    func outlineIndentOutdentSectionShift() {
        // 0:H-A(1)  1:H-B(1)  2:H-B2(2)  3:doc  4:H-C(1)
        let hA = outlineEntry(kind: .heading, level: 1, order: 0, text: "A")
        let hB = outlineEntry(kind: .heading, level: 1, order: 1, text: "B")
        let hB2 = outlineEntry(kind: .heading, level: 2, order: 2, text: "B2")
        let doc = outlineEntry(kind: .document, order: 3)
        let hC = outlineEntry(kind: .heading, level: 1, order: 4, text: "C")
        let entries = [hA, hB, hB2, doc, hC]

        // Indent B: B and its descendant B2 shift together (1→2, 2→3).
        CollectionOutline.indentSection(at: 1, in: entries)
        #expect(hB.level == 2)
        #expect(hB2.level == 3)
        #expect(hA.level == 1)
        #expect(hC.level == 1)

        // Indent B again: forbidden — its predecessor A is level 1, so 2→3 would be an
        // orphan jump. canIndent gates it; a no-op.
        CollectionOutline.indentSection(at: 1, in: entries)
        #expect(hB.level == 2)
        #expect(hB2.level == 3)

        // Outdent B back down: the section shifts −1 as a unit (B 2→1, B2 3→2).
        CollectionOutline.outdentSection(at: 1, in: entries)
        #expect(hB.level == 1)
        #expect(hB2.level == 2)

        // Outdent at level 1 is a no-op; the first heading can never indent.
        CollectionOutline.outdentSection(at: 1, in: entries)
        #expect(hB.level == 1)
        CollectionOutline.indentSection(at: 0, in: entries)
        #expect(hA.level == 1)

        // Cap clamp: indenting a section whose deepest heading already sits at the cap
        // merges that heading up (A6 degradation — flattened, never corrupted).
        // 0:X(1)  1:Y(1)  2:Z(2)  3:W(3)
        let hX = outlineEntry(kind: .heading, level: 1, order: 0, text: "X")
        let hY = outlineEntry(kind: .heading, level: 1, order: 1, text: "Y")
        let hZ = outlineEntry(kind: .heading, level: 2, order: 2, text: "Z")
        let hW = outlineEntry(kind: .heading, level: 3, order: 3, text: "W")
        CollectionOutline.indentSection(at: 1, in: [hX, hY, hZ, hW])
        #expect(hY.level == 2)
        #expect(hZ.level == 3)
        #expect(hW.level == 3)   // clamped at maxLevel, merging up one step
    }

    @Test("Collapse derivation: a collapsed heading hides its section rows (heading stays); nested and non-heading collapse states are handled")
    func outlineCollapseDerivation() {
        // 0:H-A  1:doc  2:H-A2(l2)  3:doc  4:H-B  5:doc
        let refs: [CollectionOutline.StructuralRef] = [
            ref(heading: true),  ref(heading: false), ref(heading: true, level: 2),
            ref(heading: false), ref(heading: true),  ref(heading: false),
        ]
        // No collapse: everything visible.
        #expect(CollectionOutline.visibleIndices(refs, collapsedHeadingIndices: [])
                == [0, 1, 2, 3, 4, 5])
        // Collapsing A hides its whole section (the nested subsection included).
        #expect(CollectionOutline.visibleIndices(refs, collapsedHeadingIndices: [0])
                == [0, 4, 5])
        // Collapsing only the subsection hides just its row content.
        #expect(CollectionOutline.visibleIndices(refs, collapsedHeadingIndices: [2])
                == [0, 1, 2, 4, 5])
        // Collapsing both is the union; a non-heading index is ignored.
        #expect(CollectionOutline.visibleIndices(refs, collapsedHeadingIndices: [0, 2])
                == [0, 4, 5])
        #expect(CollectionOutline.visibleIndices(refs, collapsedHeadingIndices: [1, 99])
                == [0, 1, 2, 3, 4, 5])

        // Model-backed rows: keyed by entry id, carrying index + resolved depth.
        let hA = outlineEntry(kind: .heading, level: 1, order: 0, text: "A")
        let d1 = outlineEntry(kind: .document, order: 1)
        let hB = outlineEntry(kind: .heading, level: 1, order: 2, text: "B")
        let items = CollectionOutline.linearize([hA, d1, hB])
        let rows = CollectionOutline.visibleRows(in: items, collapsedHeadingIds: [hA.id])
        #expect(rows.map(\.index) == [0, 2])
        #expect(rows.map(\.id) == [hA.id, hB.id])
        #expect(rows.map(\.depth) == [1, 1])
        // A document id in the collapse set changes nothing (only headings collapse).
        let all = CollectionOutline.visibleRows(in: items, collapsedHeadingIds: [d1.id])
        #expect(all.map(\.index) == [0, 1, 2])
    }
}

// MARK: - Resolver test doubles

/// Records `prepareVolumesForExport` calls instead of downloading/indexing, proving the
/// resolver's purpose gating: `.preview` must never reach the preparation step at all.
@MainActor
private final class PrepareVolumesSpyResolver: CollectionContentResolver {
    /// The volume-id set passed to each recorded preparation call, in call order.
    private(set) var preparedVolumeIdSets: [Set<String>] = []

    /// Records the call; performs no downloads or indexing.
    override func prepareVolumesForExport(_ neededVolumeIds: Set<String>) async {
        preparedVolumeIdSets.append(neededVolumeIds)
    }
}

/// Serialized invocation counter for observing test download-task calls.
private actor TransferCallCounter {
    /// Number of recorded invocations.
    private(set) var count = 0

    /// Records one invocation.
    func increment() { count += 1 }
}
