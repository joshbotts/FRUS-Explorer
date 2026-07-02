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

    // MARK: - LegacyProseExportTest (data-loss guard)

    @Test("LegacyProseExport: a Phase 3b JSON prose payload still appears in HTML, DOCX, and PDF exports")
    func exportsRecoverLegacyProse() async throws {
        // A raw legacy blob reaching an exporter directly (e.g. synced from a Phase 3b
        // device, or carried by a pre-fix .fruscollection file) must render its text —
        // before the fix, all three exporters silently omitted the block.
        let blob = try JSONEncoder().encode(AttributedString("Irreplaceable editorial commentary."))
        let doc = CollectionExportDocument(documentId: "d1", volumeId: "v1", sortOrder: 1,
                                           title: "A Memo", bodyText: "Body.")
        let items: [CollectionExportItem] = [.heading("Part I"), .prose(blob), .document(doc)]
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
        // A kind raw value written by a hypothetical newer build (e.g. Phase 5's excerpt).
        entry.kind = "excerpt"
        ctx.insert(entry)

        // Accessor: unknown raw values surface as .unrecognized, not as a junk .document.
        #expect(entry.entryKind == .unrecognized)

        // Setter: the fallback is never persisted — the newer build's raw value survives.
        entry.entryKind = .unrecognized
        #expect(entry.kind == "excerpt")

        // Native export omits the entry this build can't represent.
        let file = NativeCollectionSerializer.makeFile(
            from: coll, includeNotes: false, resolveNoteTexts: { _ in [] })
        #expect(file.entries.isEmpty)

        // Native import skips a file entry with an unknown kind instead of misdecoding it.
        let futureEntry = FRUSCollectionFile.Entry(
            kind: "excerpt", documentId: "d1", volumeId: "frus1961-63v14",
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
        future.kind = "excerpt"                // unrecognized kind from a newer build — skipped

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
        if case .heading(let t1) = items[0] { #expect(t1 == "Part I") } else { Issue.record("items[0] should be a heading") }
        if case .heading(let t2) = items[4] { #expect(t2 == "Part II") } else { Issue.record("items[4] should be a heading") }

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

        let items: [CollectionExportItem] = [
            .heading("Contract Part I"),
            .prose(rtf),
            .document(doc),
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
        #expect(html.contains("Editorial contract prose."))          // .prose
        #expect(html.contains("class=\"prose-block\""))              // …as a prose block
        #expect(html.contains("Contract Citation Label"))            // .document citation heading
        #expect(html.contains("Contract body paragraph."))           // .document body
        #expect(html.contains("id=\"doc-frusvol-d9\""))              // stable document anchor

        // DOCX — the stored-mode ZIP keeps document.xml uncompressed, so the emitted XML
        // text appears verbatim in the archive bytes.
        let docxURL = try await DocxCollectionExporter().export(metadata: metadata, items: items)
        let docx = try Data(contentsOf: docxURL)
        func docxContains(_ s: String) -> Bool { docx.range(of: Data(s.utf8)) != nil }
        #expect(docxContains("Contract Part I"))                     // .heading
        #expect(docxContains("Editorial contract prose."))           // .prose
        #expect(docxContains("Contract Citation Label"))             // .document

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
        #expect(pdfText.contains("Editorial contract prose."))      // .prose
        #expect(pdfText.contains("Contract body paragraph."))       // .document body
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

        // BibTeX — same discipline; records are keyed volumeId_documentId.
        let bibURL = try await BibTeXCollectionExporter().export(metadata: metadata, items: items)
        let bib = try String(contentsOf: bibURL, encoding: .utf8)
        #expect(bib.contains("@incollection{frusvol_d9,"))
        #expect(bib.contains("Contract Memo"))
        #expect(!bib.contains("Contract Part I"))
        #expect(!bib.contains("Editorial contract prose."))
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
