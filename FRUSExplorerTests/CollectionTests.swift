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
import SQLite3
import Vision
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

    // MARK: - ScopeFilterTest (issue #213)

    @Test("VisibleCollections: the shared scope filter honors showAll / active-project / global")
    func visibleCollectionsScopeFilter() {
        let projectA = UUID()
        let projectB = UUID()
        let inA = Collection(name: "In A", projectIds: [projectA])
        let inB = Collection(name: "In B", projectIds: [projectB])
        let inBoth = Collection(name: "In Both", projectIds: [projectA, projectB])
        let unscoped = Collection(name: "Unscoped", projectIds: [])
        let all = [inA, inB, inBoth, unscoped]

        // (1) showAll == true with an active project → every collection, including ones
        //     whose projectIds excludes the active project. This is the issue #213 default.
        let showingAll = Collection.visibleCollections(all, activeProjectId: projectA, showAll: true)
        #expect(showingAll.count == 4)

        // (2) showAll == false → only collections tagged to the active project.
        let scoped = Collection.visibleCollections(all, activeProjectId: projectA, showAll: false)
        #expect(scoped.map(\.name).sorted() == ["In A", "In Both"])
        #expect(!scoped.contains { $0.name == "In B" })
        #expect(!scoped.contains { $0.name == "Unscoped" })

        // (3) No active project (Global Context) → all, regardless of the showAll flag.
        #expect(Collection.visibleCollections(all, activeProjectId: nil, showAll: false).count == 4)
        #expect(Collection.visibleCollections(all, activeProjectId: nil, showAll: true).count == 4)

        // (4) Pin the #213 default itself: both managers open at all-project scope. Guards
        //     against a silent revert of the @State default that the pure-function checks
        //     above would not catch.
        #expect(Collection.managerDefaultShowAllCollections == true)
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

    // MARK: - DocumentCountTest (#1358)

    /// `documentCount` counts `.document` entries and nothing else.
    ///
    /// The fixture carries one entry of EVERY authorable kind (iterated from
    /// `CollectionEntryKind.allCases`, so a kind added later joins it without an edit), the first
    /// document added twice more, and a `kind` raw value no build knows — what a newer app version
    /// syncs in. The excerpt quotes a document that is NOT in the collection as a `.document`.
    /// That shape gives every candidate rule a different answer, so no wrong one can pass:
    ///  - this property (`.document` entries): 3;
    ///  - the raw entry count the Collections list row used, `documentEntries?.count`: 8 — the
    ///    fault #1358 photographed as "9 documents" over six;
    ///  - distinct `.document` keys (Project Home's collections sheet): 1;
    ///  - distinct documents with excerpts admitted (the Research sidebar): 2;
    ///  - `.document` entries plus excerpt-only documents, undeduplicated: 4.
    /// The property's contract is that a document added three times counts three times.
    @Test("DocumentCount: counts .document entries only — not headings, prose, excerpts, generated or unknown kinds")
    func documentCountCountsDocumentEntriesOnly() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)

        let collection = Collection(name: "Berlin Crisis")
        context.insert(collection)

        var order = 0
        func add(documentId: String? = nil, _ configure: (CollectionEntry) -> Void) {
            let entry = CollectionEntry(collectionId: collection.id, documentId: documentId ?? "d\(order)",
                                        volumeId: "frus1961-63v14", sortOrder: order)
            configure(entry)
            entry.collection = collection
            context.insert(entry)
            order += 1
        }
        for kind in CollectionEntryKind.allCases {
            // The excerpt quotes a document the collection does not hold as a .document entry.
            add(documentId: kind == .excerpt ? "d99" : (kind == .document ? "d0" : nil)) { $0.entryKind = kind }
        }
        add(documentId: "d0") { $0.entryKind = .document }  // the first document, added again…
        add(documentId: "d0") { $0.entryKind = .document }  // …and a third time
        add { $0.kind = "marginalia" }                      // a newer build's kind: reads .unrecognized
        try context.save()

        // The fixture is what it claims: every authorable kind, one document three times, one unknown.
        let entries = try #require(collection.documentEntries)
        #expect(entries.count == CollectionEntryKind.allCases.count + 3)
        #expect(Set(entries.map(\.entryKind)) == Set(CollectionEntryKind.allCases + [.unrecognized]))
        let documentKeys = entries.filter { $0.entryKind == .document }.map { "\($0.volumeId)/\($0.documentId)" }
        #expect(documentKeys == Array(repeating: "frus1961-63v14/d0", count: 3))
        // ...and every other candidate rule reads a different number from this one.
        #expect(Set(documentKeys).count == 1, "distinct .document keys")
        #expect(ResearchDocumentAggregation.distinctDocumentKeys(in: entries).count == 2,
                "distinct documents with the excerpt admitted")
        let excerptOnly = Set(entries.filter { $0.entryKind == .excerpt }.map(\.documentId))
            .subtracting(entries.filter { $0.entryKind == .document }.map(\.documentId))
        #expect(documentKeys.count + excerptOnly.count == 4, "document entries plus excerpt-only documents")

        #expect(collection.documentCount == 3)

        // A collection with no entries yet reads zero, not a crash or a nil.
        let empty = Collection(name: "Empty")
        context.insert(empty)
        #expect(empty.documentCount == 0)
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

    // MARK: - ProseLinkTest (Session 2026-07-03: editor Link control)

    /// RTF carrying a `.link` attribute over part of the text, exactly as the editor's
    /// Link control stores it (an `NSURL`-valued attribute, written as an RTF
    /// `HYPERLINK` field).
    private func makeLinkedProseRTF() throws -> Data {
        let m = NSMutableAttributedString(string: "See the archive for details.")
        m.addAttribute(.link, value: URL(string: "https://history.state.gov/frus")!,
                       range: NSRange(location: 4, length: 11))   // "the archive"
        return try m.data(from: NSRange(location: 0, length: m.length),
                          documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
    }

    @Test("ProseLink: a .link attribute survives RTF storage and decodes into span linkURL")
    func proseLinkRTFRoundTripsToSpans() throws {
        let rtf = try makeLinkedProseRTF()

        // The stored blob is valid RTF (the editor's persistence path is unchanged)…
        let entry = CollectionEntry(collectionId: UUID(), documentId: "", volumeId: "", sortOrder: 0)
        entry.entryKind = .prose
        entry.richText = rtf
        entry.text = "See the archive for details."
        let exported = ProseRichText.exportRTF(from: entry)

        // …and the shared decoder exposes the link on exactly the linked span.
        let paragraphs = CollectionProse.paragraphs(fromRTF: exported)
        try #require(paragraphs.count == 1)
        let spans = paragraphs[0]
        #expect(spans.map(\.text).joined() == "See the archive for details.")
        let linked = spans.filter { $0.linkURL != nil }
        try #require(linked.count == 1)
        #expect(linked[0].text == "the archive")
        #expect(linked[0].linkURL == "https://history.state.gov/frus")
        // Unlinked spans stay unlinked.
        #expect(spans.filter { $0.linkURL == nil }.allSatisfy { $0.text != "the archive" })
    }

    @Test("ProseLink: a linked prose span renders as <a href> in HTML, <w:hyperlink> in DOCX, and visible URL text in PDF")
    func proseLinkExportsAcrossFormats() async throws {
        let rtf = try makeLinkedProseRTF()
        let metadata = CollectionExportMetadata(name: "Link Contract", note: nil)
        let items: [CollectionExportItem] = [.prose(rtf)]

        // HTML (export + live preview share this renderer): a real anchor around the
        // linked text only.
        let htmlURL = try await HTMLCollectionExporter().export(metadata: metadata, items: items)
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        #expect(html.contains("<a href=\"https://history.state.gov/frus\">the archive</a>"))
        #expect(html.contains("See "))

        // DOCX: a real external hyperlink — <w:hyperlink r:id> + Hyperlink rStyle +
        // TargetMode="External" relationship (the Phase 6 relationship plumbing).
        let docxURL = try await DocxCollectionExporter().export(metadata: metadata, items: items)
        let docx = try Data(contentsOf: docxURL)
        func docxContains(_ s: String) -> Bool { docx.range(of: Data(s.utf8)) != nil }
        #expect(docxContains("<w:hyperlink r:id=\"rId3\">"))
        #expect(docxContains("<w:rStyle w:val=\"Hyperlink\"/>"))
        #expect(docxContains("Target=\"https://history.state.gov/frus\" TargetMode=\"External\""))
        #expect(docxContains("the archive"))

        // PDF: the linked text plus the URL as visible parenthetical text (bare CoreText
        // frame drawing has no link annotations — the documented v1.14 tradeoff).
        let pdfURL = try await PDFCollectionExporter().export(metadata: metadata, items: items)
        let pdfDocument = try #require(PDFDocument(data: try Data(contentsOf: pdfURL)))
        let pdfText = (0..<pdfDocument.pageCount)
            .compactMap { pdfDocument.page(at: $0)?.string }
            .joined(separator: "\n")
        #expect(pdfText.contains("the archive"))
        #expect(pdfText.contains("history.state.gov/frus"))
    }

    @Test("ProseLink: a link with mixed inline formatting prints the PDF URL parenthetical once, after the run — not once per span")
    func proseLinkMixedFormattingPrintsURLOnceInPDF() async throws {
        // One user-applied link over "the archive", with "archive" additionally bolded —
        // the attribute change splits the linked range into two consecutive runs that
        // BOTH carry the linkURL (the PDF v1.18 regression shape: v1.16 printed the
        // visible-URL parenthetical after every span, injecting it mid-phrase).
        let m = NSMutableAttributedString(string: "See the archive for details.")
        m.addAttribute(.link, value: URL(string: "https://history.state.gov/frus")!,
                       range: NSRange(location: 4, length: 11))   // "the archive"
        #if canImport(AppKit)
        m.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize),
                       range: NSRange(location: 8, length: 7))    // "archive"
        #else
        m.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: UIFont.labelFontSize),
                       range: NSRange(location: 8, length: 7))    // "archive"
        #endif
        let rtf = try m.data(from: NSRange(location: 0, length: m.length),
                             documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])

        // Precondition: the decoder really does emit multiple spans sharing one linkURL.
        let spans = try #require(CollectionProse.paragraphs(fromRTF: rtf).first)
        #expect(spans.filter { $0.linkURL == "https://history.state.gov/frus" }.count == 2)

        let metadata = CollectionExportMetadata(name: "Link Once", note: nil)
        let pdfURL = try await PDFCollectionExporter().export(metadata: metadata, items: [.prose(rtf)])
        let pdfDocument = try #require(PDFDocument(data: try Data(contentsOf: pdfURL)))
        let pdfText = (0..<pdfDocument.pageCount)
            .compactMap { pdfDocument.page(at: $0)?.string }
            .joined(separator: "\n")
        // The URL appears exactly once — after the whole linked phrase, never mid-phrase.
        let occurrences = pdfText.components(separatedBy: "history.state.gov/frus").count - 1
        #expect(occurrences == 1)
        let normalized = pdfText.replacingOccurrences(of: "\n", with: " ")
        #expect(!normalized.contains("(https://history.state.gov/frus)archive"))
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

    // MARK: - Research-rail Collections membership (Phase E)

    @Test("RailMembershipPredicate: the rail's membership query keeps only kind == \"document\" entries")
    func railMembershipQueryFiltersToDocumentKind() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)

        let collection = Collection(name: "Berlin Crisis")
        context.insert(collection)

        // One real document membership + three decoys of other kinds for the SAME (volume, document).
        // The rail's Collections accordion counts/lists only `.document` entries (owner decision D5):
        // headings / prose / excerpts are composed-collection structure, not document memberships.
        let doc = CollectionEntry(collectionId: collection.id, documentId: "d5", volumeId: "vol1", sortOrder: 0)
        doc.collection = collection
        context.insert(doc)
        for (i, kind) in [CollectionEntryKind.heading, .prose, .excerpt].enumerated() {
            let decoy = CollectionEntry(collectionId: collection.id, documentId: "d5", volumeId: "vol1", sortOrder: i + 1)
            decoy.collection = collection
            decoy.entryKind = kind
            context.insert(decoy)
        }
        try context.save()

        // Fetch with the PRODUCTION predicate (shared with the rail's `memberships` @Query) so this
        // test breaks if the shipped filter is ever weakened — not a hand-copy that could drift.
        let descriptor = FetchDescriptor<CollectionEntry>(
            predicate: ResearchRailView.membershipPredicate(volumeId: "vol1", documentId: "d5"))
        let membership = try context.fetch(descriptor)

        #expect(membership.count == 1)
        #expect(membership.first?.entryKind == .document)
    }

    @Test("RailDistinctCollections: dedupes repeat memberships, drops nil-collection orphans, sorts by name")
    func railDistinctCollectionsDedupesOrphansAndSorts() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)

        let beta = Collection(name: "Berlin")
        let alpha = Collection(name: "Algiers")
        context.insert(beta)
        context.insert(alpha)

        func entry(_ collection: Collection?, order: Int) -> CollectionEntry {
            let e = CollectionEntry(collectionId: collection?.id ?? UUID(),
                                    documentId: "d5", volumeId: "vol1", sortOrder: order)
            e.collection = collection
            context.insert(e)
            return e
        }
        // Two entries into Berlin (the document appears twice → must dedupe to one), one into Algiers,
        // and one orphan whose collection was deleted under `.nullify` (relationship left nil → drop).
        let memberships = [
            entry(beta, order: 0),
            entry(beta, order: 1),
            entry(alpha, order: 2),
            entry(nil, order: 3),
        ]
        try context.save()

        let distinct = ResearchRailView.distinctCollections(from: memberships)

        #expect(distinct.map(\.name) == ["Algiers", "Berlin"])   // deduped + name-sorted, orphan dropped
    }

    // MARK: - HeadnoteDraftCleanup

    @Test("HeadnoteDraftCleanup: deleting an entry removes its isHeadnoteDraft summary; a real summary pointed at by headnoteSummaryId is left intact")
    func headnoteDraftCleanup() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)

        let collection = Collection(name: "Test Collection")
        context.insert(collection)

        // Entry A owns an edited headnote draft.
        let draft = GeneratedSummary(documentId: "d1", volumeId: "vol1",
                                     promptId: UUID(), responseText: "Key takeaway.",
                                     authorship: .userWritten, isHeadnoteDraft: true)
        context.insert(draft)
        let entryA = CollectionEntry(collectionId: collection.id, documentId: "d1",
                                     volumeId: "vol1", sortOrder: 0)
        entryA.collection = collection
        entryA.headnoteSummaryId = draft.id
        context.insert(entryA)

        // Entry B points its headnote at a REAL (non-draft) document summary.
        let realSummary = GeneratedSummary(documentId: "d2", volumeId: "vol1",
                                           promptId: UUID(), responseText: "Doc summary.")
        context.insert(realSummary)
        let entryB = CollectionEntry(collectionId: collection.id, documentId: "d2",
                                     volumeId: "vol1", sortOrder: 1)
        entryB.collection = collection
        entryB.headnoteSummaryId = realSummary.id
        context.insert(entryB)
        try context.save()

        // Deleting entry A removes its draft only.
        GeneratedSummary.deleteHeadnoteDraft(for: entryA, in: context)
        try context.save()
        var all = try context.fetch(FetchDescriptor<GeneratedSummary>())
        #expect(!all.contains { $0.id == draft.id })
        #expect(all.contains { $0.id == realSummary.id })

        // Deleting entry B leaves the real summary intact (the isHeadnoteDraft guard).
        GeneratedSummary.deleteHeadnoteDraft(for: entryB, in: context)
        try context.save()
        all = try context.fetch(FetchDescriptor<GeneratedSummary>())
        #expect(all.contains { $0.id == realSummary.id })
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

    // MARK: - Sort modes (whole-collection vs within-sections)

    /// Builds a detached document entry with a known key, for the sort-scope fixtures.
    private func makeDoc(_ documentId: String, _ volumeId: String, _ order: Int) -> CollectionEntry {
        let e = CollectionEntry(collectionId: UUID(), documentId: documentId,
                                volumeId: volumeId, sortOrder: order)
        e.entryKind = .document
        return e
    }

    /// Builds a detached heading entry, for the sort-scope fixtures.
    private func makeHeading(_ text: String, _ order: Int) -> CollectionEntry {
        let e = CollectionEntry(collectionId: UUID(), documentId: "", volumeId: "", sortOrder: order)
        e.entryKind = .heading
        e.text = text
        return e
    }

    @Test("SortScope: withinSections keeps documents inside their heading-delimited section")
    func sortWithinSectionsKeepsDocsUnderHeading() {
        // Fixture: [Heading A, DocB(1962), DocA(1961), Heading B, DocD(1964), DocC(1963)]
        let hA = makeHeading("A", 0)
        let docB = makeDoc("dB", "vol", 1)
        let docA = makeDoc("dA", "vol", 2)
        let hB = makeHeading("B", 3)
        let docD = makeDoc("dD", "vol", 4)
        let docC = makeDoc("dC", "vol", 5)
        let entries = [hA, docB, docA, hB, docD, docC]
        let dates: [String: String] = [
            "vol/dA": "1961-01-01", "vol/dB": "1962-01-01",
            "vol/dC": "1963-01-01", "vol/dD": "1964-01-01",
        ]

        let sectioned = CollectionEntryData.sortedByDate(
            entries, documentDates: dates, manifest: [], withinSections: true)
        // Within-sections: [Heading A, DocA, DocB, Heading B, DocC, DocD] — no doc crosses B.
        #expect(sectioned.map(\.documentId) == ["", "dA", "dB", "", "dC", "dD"])

        let global = CollectionEntryData.sortedByDate(
            entries, documentDates: dates, manifest: [], withinSections: false)
        // Global threads all four docs into one chronology through the fixed headings:
        // slots are [heading, doc, doc, heading, doc, doc] → dA,dB,dC,dD in order.
        #expect(global.map(\.documentId) == ["", "dA", "dB", "", "dC", "dD"])
    }

    @Test("SortScope: global threads docs across a heading; within-sections does not")
    func sortGlobalCrossesHeadingSectionedDoesNot() {
        // Section A holds a LATE doc; section B holds an EARLY doc. Globally the early doc
        // must move into the first doc-slot (section A), crossing heading B; sectioned it
        // stays under B.
        let hA = makeHeading("A", 0)
        let docLate = makeDoc("dLate", "vol", 1)   // 1970
        let hB = makeHeading("B", 2)
        let docEarly = makeDoc("dEarly", "vol", 3) // 1950
        let entries = [hA, docLate, hB, docEarly]
        let dates = ["vol/dLate": "1970-01-01", "vol/dEarly": "1950-01-01"]

        let global = CollectionEntryData.sortedByDate(
            entries, documentDates: dates, manifest: [], withinSections: false)
        // Doc-slots are positions 1 and 3; sorted docs [dEarly, dLate] fill them in order,
        // so the early doc lands in section A — it crossed heading B.
        #expect(global.map(\.documentId) == ["", "dEarly", "", "dLate"])

        let sectioned = CollectionEntryData.sortedByDate(
            entries, documentDates: dates, manifest: [], withinSections: true)
        // Each section has one doc, so nothing moves — the early doc stays under B.
        #expect(sectioned.map(\.documentId) == ["", "dLate", "", "dEarly"])
    }

    @Test("SortScope: with no headings, within-sections is identical to global")
    func sortNoHeadingsDegeneracy() {
        let docB = makeDoc("dB", "vol", 0)
        let docA = makeDoc("dA", "vol", 1)
        let docC = makeDoc("dC", "vol", 2)
        let entries = [docB, docA, docC]
        let dates = ["vol/dA": "1961", "vol/dB": "1962", "vol/dC": "1963"]

        let global = CollectionEntryData.sortedByDate(
            entries, documentDates: dates, manifest: [], withinSections: false)
        let sectioned = CollectionEntryData.sortedByDate(
            entries, documentDates: dates, manifest: [], withinSections: true)
        #expect(global.map(\.documentId) == sectioned.map(\.documentId))
        #expect(sectioned.map(\.documentId) == ["dA", "dB", "dC"])
    }

    @Test("SortScope: a non-document anchor inside a section stays put within that section")
    func sortWithinSectionsProseAnchorStaysPut() {
        // Section: [Heading, Doc(1963), Prose, Doc(1961)] — sorting the two docs must not
        // move the prose block; it anchors in place while the docs sort into their slots.
        let h = makeHeading("H", 0)
        let docLate = makeDoc("dLate", "vol", 1)   // 1963
        let prose = CollectionEntry(collectionId: UUID(), documentId: "", volumeId: "", sortOrder: 2)
        prose.entryKind = .prose
        let docEarly = makeDoc("dEarly", "vol", 3) // 1961
        let entries = [h, docLate, prose, docEarly]
        let dates = ["vol/dLate": "1963", "vol/dEarly": "1961"]

        let sectioned = CollectionEntryData.sortedByDate(
            entries, documentDates: dates, manifest: [], withinSections: true)
        // Kinds unchanged in position; docs sorted into the two doc-slots (early first).
        #expect(sectioned.map(\.entryKind) == [.heading, .document, .prose, .document])
        #expect(sectioned.map(\.documentId) == ["", "dEarly", "", "dLate"])
    }

    @Test("SortScope: the leading run before the first heading sorts among itself")
    func sortWithinSectionsLeadingRunSorts() {
        // [DocB(1962), DocA(1961), Heading, DocD(1964), DocC(1963)] — the pre-heading run
        // sorts internally; the post-heading section sorts internally; neither crosses.
        let docB = makeDoc("dB", "vol", 0)
        let docA = makeDoc("dA", "vol", 1)
        let h = makeHeading("H", 2)
        let docD = makeDoc("dD", "vol", 3)
        let docC = makeDoc("dC", "vol", 4)
        let entries = [docB, docA, h, docD, docC]
        let dates = ["vol/dA": "1961", "vol/dB": "1962", "vol/dC": "1963", "vol/dD": "1964"]

        let sectioned = CollectionEntryData.sortedByDate(
            entries, documentDates: dates, manifest: [], withinSections: true)
        #expect(sectioned.map(\.documentId) == ["dA", "dB", "", "dC", "dD"])
    }

    @Test("SortScope: undated documents still sort last within their own run")
    func sortWithinSectionsUndatedLastPerRun() {
        // Section: [Heading, DocUndated, DocDated(1961)] — the dated doc must sort before
        // the undated one WITHIN the section (undated → "9999" sentinel, last).
        let h = makeHeading("H", 0)
        let docUndated = makeDoc("dUndated", "vol", 1)
        let docDated = makeDoc("dDated", "vol", 2)
        let entries = [h, docUndated, docDated]
        let dates = ["vol/dDated": "1961-01-01"] // dUndated absent → sentinel

        let sectioned = CollectionEntryData.sortedByDate(
            entries, documentDates: dates, manifest: [], withinSections: true)
        #expect(sectioned.map(\.documentId) == ["", "dDated", "dUndated"])
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

    /// M2 (D5): `selectedNoteIds` is device-local and must never be serialized into a
    /// `.fruscollection` file (mirroring `selectedHighlightIds`) — a recipient lacks the
    /// referenced notes. Only the *resolved* note texts travel (in the `notes` array),
    /// and only when notes are opted in. The exported JSON must not contain the note id.
    @Test("M2 D5: selectedNoteIds note ids are never serialized into the .fruscollection file")
    func nativeSelectedNoteIdsNotSerialized() throws {
        let source = try ModelContainer.makeTestContainer()
        let sourceCtx = ModelContext(source)
        let (coll, note) = try makeNativeSourceCollection(in: sourceCtx)   // doc entry links note

        // Notes OPTED IN: the note *text* travels, but the id must not.
        let file = NativeCollectionSerializer.makeFile(
            from: coll, includeNotes: true, resolveNoteTexts: noteTextResolver(sourceCtx))
        let json = String(decoding: try NativeCollectionSerializer.encode(file), as: UTF8.self)

        #expect(json.contains("Compare with the Clay telegrams."))   // resolved text travels
        #expect(!json.contains(note.id.uuidString))                  // the id does not
        #expect(!json.lowercased().contains("selectednoteids"))      // no such key in the schema
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
        case .heading:   return "heading"
        case .prose:     return "prose"
        case .excerpt:   return "excerpt"
        case .generated: return "generated"
        case .document:  return "document"
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

    // MARK: - Collections Manager M2 (D5: notes default = all)

    /// D5: an untouched document entry (empty `selectedNoteIds`, no legacy link) now
    /// resolves to **all** of the document's notes — mirroring `selectedHighlightIds`.
    /// Deselecting one (an explicit partial selection) narrows the export to the rest,
    /// and the legacy single-note link is still honored for un-migrated entries.
    @Test("M2 D5: empty selectedNoteIds resolves to all doc notes; partial narrows; legacy link honored")
    @MainActor
    func notesEmptyMeansAll() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        let appState = AppState()   // citation-only resolution (no manifest/XML)

        let coll = Collection(name: "Notes M2")
        coll.defaultBodyDepth = "full"
        context.insert(coll)

        // Three notes on d1, one on d2 (the legacy-link document).
        let n1 = ResearchNote(documentId: "d1", volumeId: "m2vol", bodyText: "Note one.")
        let n2 = ResearchNote(documentId: "d1", volumeId: "m2vol", bodyText: "Note two.")
        let n3 = ResearchNote(documentId: "d1", volumeId: "m2vol", bodyText: "Note three.")
        let legacy = ResearchNote(documentId: "d2", volumeId: "m2vol", bodyText: "Legacy note.")
        for n in [n1, n2, n3, legacy] { context.insert(n) }

        // Untouched entry on d1 — empty selection, no legacy link (D5 = all).
        let dAll = CollectionEntry(collectionId: coll.id, documentId: "d1", volumeId: "m2vol", sortOrder: 0)
        dAll.collection = coll
        // Partial-selection entry on d1 — two of the three notes chosen.
        let dPartial = CollectionEntry(collectionId: coll.id, documentId: "d1", volumeId: "m2vol", sortOrder: 1)
        dPartial.selectedNoteIds = [n1.id, n3.id]
        dPartial.collection = coll
        // Legacy single-note link on d2.
        let dLegacy = CollectionEntry(collectionId: coll.id, documentId: "d2", volumeId: "m2vol",
                                      sortOrder: 2, researchNoteId: legacy.id)
        dLegacy.collection = coll

        for e in [dAll, dPartial, dLegacy] { context.insert(e) }
        try context.save()

        let resolver = CollectionContentResolver(appState: appState, modelContext: context)
        let items = try await resolver.resolve(
            collection: coll,
            entries: [dAll, dPartial, dLegacy],
            allNotes: [n1, n2, n3, legacy],
            purpose: .export)
        let docs = items.documents
        try #require(docs.count == 3)

        // Untouched entry (empty = all): every note on d1 travels.
        #expect(Set(docs[0].noteTexts) == ["Note one.", "Note two.", "Note three."])
        // Partial selection: only the two chosen notes.
        #expect(Set(docs[1].noteTexts) == ["Note one.", "Note three."])
        // Legacy researchNoteId path still resolves the single linked note.
        #expect(docs[2].noteTexts == ["Legacy note."])
    }

    /// The inspector's uncheck-last convention (D5, mirroring `setHighlightIncluded`):
    /// deselecting the final note collapses `selectedNoteIds` to empty **and** turns the
    /// notes gate off — since empty means "all", "none" must be the override-off flag.
    /// Verified through the resolver: with the gate off, no notes export even though the
    /// document has notes and the collection default includes them.
    @Test("M2 D5: uncheck-last (selectedNoteIds empty + includeNotesOverride false) exports no notes")
    @MainActor
    func notesUncheckLastGatesOff() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        let appState = AppState()

        let coll = Collection(name: "Gate")
        coll.defaultBodyDepth = "full"
        coll.includeNotes = true                 // collection default: notes on
        context.insert(coll)

        let n = ResearchNote(documentId: "d1", volumeId: "gatevol", bodyText: "Only note.")
        context.insert(n)

        // The uncheck-last end state: empty selection + gate explicitly off.
        let gated = CollectionEntry(collectionId: coll.id, documentId: "d1", volumeId: "gatevol", sortOrder: 0)
        gated.selectedNoteIds = []
        gated.includeNotesOverride = false
        gated.collection = coll
        context.insert(gated)
        try context.save()

        let resolver = CollectionContentResolver(appState: appState, modelContext: context)
        let items = try await resolver.resolve(
            collection: coll, entries: [gated], allNotes: [n], purpose: .export)
        let docs = items.documents
        try #require(docs.count == 1)
        // The renderers read `includeNotesOverride ?? options.includeNotes` as the
        // whether-gate; the uncheck-last convention set the override to false, so no
        // notes render for this entry even though the collection default includes them.
        #expect(docs[0].includeNotesOverride == false)
    }

    /// D5 empty=all must hold on the native `.fruscollection` export too, not just the
    /// rendered formats: an untouched entry (empty `selectedNoteIds`, no legacy link) whose
    /// notes are opted into the shared file must carry **all** of the document's notes in
    /// the `notes` array — matching what the resolver produces for PDF/HTML/DOCX. This pins
    /// the closure in `CollectionExportSheet.runNativeExport`, which is the sole production
    /// caller of `NativeCollectionSerializer.makeFile`, so the two paths cannot drift.
    @Test("M2 D5: native .fruscollection export carries all doc notes for an untouched entry (empty = all)")
    func nativeEmptyNotesMeansAll() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)

        let coll = Collection(name: "Native Notes")
        coll.includeNotes = true
        context.insert(coll)

        // Two notes on d1 (the untouched entry) + one on d2 (a partial-selection entry).
        let a = ResearchNote(documentId: "d1", volumeId: "nvol", bodyText: "Alpha note.")
        let b = ResearchNote(documentId: "d1", volumeId: "nvol", bodyText: "Beta note.")
        let c = ResearchNote(documentId: "d2", volumeId: "nvol", bodyText: "Gamma note.")
        let unrelated = ResearchNote(documentId: "d9", volumeId: "othervol", bodyText: "Unrelated note.")
        for n in [a, b, c, unrelated] { context.insert(n) }

        // Untouched entry: empty selection, no legacy link → D5 all.
        let untouched = CollectionEntry(collectionId: coll.id, documentId: "d1", volumeId: "nvol", sortOrder: 0)
        untouched.collection = coll
        // Partial-selection entry on d2: only Gamma explicitly chosen.
        let partial = CollectionEntry(collectionId: coll.id, documentId: "d2", volumeId: "nvol", sortOrder: 1)
        partial.selectedNoteIds = [c.id]
        partial.collection = coll
        for e in [untouched, partial] { context.insert(e) }
        try context.save()

        // Mirrors the production closure in CollectionExportSheet.runNativeExport (D5).
        let allNotes = [a, b, c, unrelated]
        let resolveNoteTexts: (CollectionEntry) -> [String] = { entry in
            if !entry.selectedNoteIds.isEmpty {
                return entry.selectedNoteIds.compactMap { id in
                    allNotes.first { $0.id == id }?.bodyText
                }.filter { !$0.isEmpty }
            }
            if let legacyId = entry.researchNoteId,
               let legacy = allNotes.first(where: { $0.id == legacyId }) {
                return legacy.bodyText.isEmpty ? [] : [legacy.bodyText]
            }
            return allNotes
                .filter { $0.documentId == entry.documentId && $0.volumeId == entry.volumeId }
                .map(\.bodyText)
                .filter { !$0.isEmpty }
        }

        let file = NativeCollectionSerializer.makeFile(
            from: coll, includeNotes: true, resolveNoteTexts: resolveNoteTexts)
        let docEntries = file.entries.filter { $0.kind == CollectionEntryKind.document.rawValue }
        try #require(docEntries.count == 2)

        // Untouched d1 entry: both of its notes travel; the unrelated-doc note does not.
        #expect(Set(docEntries[0].notes ?? []) == ["Alpha note.", "Beta note."])
        // Partial d2 entry: only the explicitly chosen note.
        #expect(docEntries[1].notes == ["Gamma note."])
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
        // Phase 5 overrides: synthetic smart entries carry none — smart collections
        // keep collection-level behavior by construction.
        #expect(doc.applyHighlightsOverride == nil)
        #expect(doc.includeNotesOverride == nil)
        #expect(doc.includeFootnotesOverride == nil)
        #expect(doc.summaryPromptIdOverride == nil)
        #expect(doc.relatedDocumentCitations.isEmpty)

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
            // Phase 5: the related-documents payload rides the document (no new item
            // case) — every rendering format must emit the "See also:" line.
            relatedDocumentCitations: ["Related Contract Citation"],
            zoteroItem: zotero)

        let excerpt = CollectionExportExcerpt(
            text: "Contract excerpt passage.",
            documentId: "d9", volumeId: "frusvol",
            citation: "Contract Excerpt Citation",
            colorTag: "green")

        // Phase 6: a pre-resolved generated apparatus block, exercising every row
        // feature (secondary text, external URL, indent level).
        let generated = CollectionGeneratedBlock(
            type: .archivalSources,
            title: "Contract Apparatus Block",
            rows: [
                CollectionGeneratedRow(text: "Record Group 59"),
                CollectionGeneratedRow(text: "Contract Central Files",
                                       secondaryText: "Documents 1, 2",
                                       url: "https://catalog.archives.gov/id/302021",
                                       indentLevel: 1),
            ])

        let items: [CollectionExportItem] = [
            .heading("Contract Part I", level: 1),
            .prose(rtf),
            .document(doc),
            .excerpt(excerpt),                           // Phase 5: frozen quotation
            .heading("Contract Nested Sub", level: 2),   // Phase 4: leveled headings
            .generated(generated),                       // Phase 6: apparatus block
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
        #expect(html.contains("class=\"see-also\""))                 // related-documents line
        #expect(html.contains("See also:"))
        #expect(html.contains("Related Contract Citation"))
        #expect(html.contains(".see-also {"))                        // relatedCSS emitted when used
        #expect(html.contains("generated-block generated-archivalSources"))  // .generated section
        #expect(html.contains("class=\"generated-title\">Contract Apparatus Block"))
        #expect(html.contains("Record Group 59"))                    // plain row
        #expect(html.contains("<li class=\"generated-row indent-1\">"))      // indented row
        #expect(html.contains("<a href=\"https://catalog.archives.gov/id/302021\""))  // row link
        #expect(html.contains("class=\"generated-secondary\">Documents 1, 2"))
        #expect(html.contains("section.generated-block"))            // generatedCSS emitted when used
        #expect(html.contains("<li class=\"toc-section\">Contract Apparatus Block</li>"))  // ToC by title

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
        #expect(docxContains("See also:"))                           // related-documents line
        #expect(docxContains("Related Contract Citation"))
        // .generated block (Phase 6): SectionHeading title (enters Word's ToC field),
        // GeneratedRow rows, a real external hyperlink relationship, and the xmlns:r
        // declaration that appears only when a hyperlink exists.
        #expect(docxContains("Contract Apparatus Block"))
        #expect(docxContains("GeneratedRow"))
        #expect(docxContains("Record Group 59"))
        #expect(docxContains("Documents 1, 2"))
        #expect(docxContains("<w:hyperlink r:id=\"rId3\">"))
        #expect(docxContains("Target=\"https://catalog.archives.gov/id/302021\" TargetMode=\"External\""))
        #expect(docxContains("xmlns:r="))
        #expect(docxContains("<w:ind w:left=\"360\"/>"))             // indent-1 row
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
        #expect(pdfText.contains("See also:"))                      // related-documents line
        #expect(pdfText.contains("Related Contract Citation"))
        #expect(pdfText.contains("Contract Apparatus Block"))       // .generated title (body + cover ToC)
        #expect(pdfText.contains("Record Group 59"))                // …row
        #expect(pdfText.contains("Documents 1, 2"))                 // …secondary text
        #expect(pdfText.contains("catalog.archives.gov/id/302021")) // …URL as visible text (v1.14 tradeoff)
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
        #expect(!ris.contains("Related Contract Citation"))   // related docs skipped too
        #expect(!ris.contains("Contract Apparatus Block"))    // generated blocks skipped too
        #expect(!ris.contains("Record Group 59"))

        // BibTeX — same discipline; records are keyed volumeId_documentId.
        let bibURL = try await BibTeXCollectionExporter().export(metadata: metadata, items: items)
        let bib = try String(contentsOf: bibURL, encoding: .utf8)
        #expect(bib.contains("@incollection{frusvol_d9,"))
        #expect(bib.contains("Contract Memo"))
        #expect(!bib.contains("Contract Part I"))
        #expect(!bib.contains("Editorial contract prose."))
        #expect(!bib.contains("Contract excerpt passage."))   // excerpts skipped by design
        #expect(!bib.contains("Related Contract Citation"))   // related docs skipped too
        #expect(!bib.contains("Contract Apparatus Block"))    // generated blocks skipped too
        #expect(!bib.contains("Record Group 59"))
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
        #expect(!page.contains("collection-project"))   // #377 Phase 4 provenance layer stays dormant
        #expect(!page.contains("colophon"))
        #expect(!page.contains("headnote"))   // Phase 5 layer stays dormant too
        #expect(!page.contains("excerpt"))    // Phase 5 excerpt layer stays dormant too
        #expect(!page.contains("see-also"))   // Phase 5 related-documents layer too
        #expect(!page.contains("See also"))
        #expect(!page.contains("generated-block"))   // Phase 6 apparatus layer stays dormant too
        #expect(!page.contains("ai-attribution"))    // AI-attribution layer stays dormant too
        #expect(page.contains(CollectionItemHTMLRenderer.embeddedCSS + "\n  </style>"))
    }

    @Test("Phase4 provenance: projectProvenance gates on the toggle + a non-empty active project name")
    func projectProvenanceGating() {
        // Enabled + active project → name + question.
        let on = CollectionExportMetadata.projectProvenance(
            enabled: true, projectName: "Cuban Missile Crisis", researchQuestion: "How was ExComm briefed?")
        #expect(on.name == "Cuban Missile Crisis")
        #expect(on.question == "How was ExComm briefed?")
        // Disabled → nothing, even with an active project.
        let off = CollectionExportMetadata.projectProvenance(
            enabled: false, projectName: "X", researchQuestion: "Q")
        #expect(off.name == nil && off.question == nil)
        // Enabled but no active project → nothing.
        #expect(CollectionExportMetadata.projectProvenance(
            enabled: true, projectName: nil, researchQuestion: nil).name == nil)
        // Blank name → nothing (the name is the anchor).
        #expect(CollectionExportMetadata.projectProvenance(
            enabled: true, projectName: "   ", researchQuestion: "Q").name == nil)
        // Blank question → dropped, but the name is kept.
        let noQ = CollectionExportMetadata.projectProvenance(
            enabled: true, projectName: "P", researchQuestion: "  ")
        #expect(noQ.name == "P" && noQ.question == nil)
    }

    @Test("Phase4 provenance: headerHTML places the project line after the author, before the note")
    func htmlProjectProvenancePlacement() {
        let metadata = CollectionExportMetadata(
            name: "Berlin", note: "A note.", authorLine: "The Researcher",
            projectName: "Berlin Crisis", projectResearchQuestion: "Who decided?")
        let html = CollectionItemHTMLRenderer().headerHTML(metadata: metadata)
        #expect(html.contains("<p class=\"collection-project\">Project: Berlin Crisis</p>"))
        #expect(html.contains("<p class=\"collection-project-question\">Who decided?</p>"))
        // Order: author < project < question < note.
        let iAuthor = html.range(of: "collection-author")!.lowerBound
        let iProject = html.range(of: "collection-project\"")!.lowerBound
        let iQuestion = html.range(of: "collection-project-question")!.lowerBound
        let iNote = html.range(of: "collection-note")!.lowerBound
        #expect(iAuthor < iProject && iProject < iQuestion && iQuestion < iNote)
        // No project markup when the name is absent (matches the dormant byte-compat contract).
        let bare = CollectionExportMetadata(name: "Berlin", note: "A note.")
        #expect(!CollectionItemHTMLRenderer().headerHTML(metadata: bare).contains("collection-project"))
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
        // Bind through an explicit `Data` so #require actually unwraps: assigning straight
        // into the `Data?` property let T infer as `Data?`, so the macro asserted nothing.
        let richRTF: Data = try #require(ProseRichText.rtfData(from: richNS))
        coll.introductionRichText = richRTF
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
        coll.includeProjectProvenance = true
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
        #expect(imported.includeProjectProvenance == true)
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
        #expect(old.includeProjectProvenance == false)
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
                      "introductionText", "introductionRichText", "includeColophon",
                      "includeProjectProvenance", "level",
                      // Phase 5 optional keys — absent from a write-minimum file.
                      "includeFootnotes", "includeSourceNote",
                      "includeHeadnote", "headnoteSummaryId",
                      // Phase 5 excerpt anchors — likewise absent.
                      "excerptStart", "excerptEnd",
                      "excerptRenderingVersion", "excerptColorTag",
                      // Phase 5 per-entry overrides — likewise absent…
                      "applyHighlightsOverride", "includeNotesOverride",
                      "includeSourceNoteOverride", "includeFootnotesOverride",
                      "summaryPromptIdOverride", "includeRelatedDocuments",
                      // Phase 6 generated-block key — likewise absent.
                      "generatedBlockType",
                      // …and selectedHighlightIds NEVER serializes, in any file.
                      "selectedHighlightIds"] {
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

    // MARK: - The published write-minimum (W-19 row L-1)

    /// The exact bytes published as the write-minimum in `Docs/Agentic-Analysis-Guide.md` §15.
    ///
    /// Kept verbatim rather than built from the DTO on purpose: the point of the spec is that an
    /// outside writer with no Swift can produce a file this app opens, so the test has to start
    /// from text, the way that writer does. If the guide's example and this literal ever diverge,
    /// the promise the guide makes is no longer the promise the app keeps.
    private static let publishedWriteMinimum = Data("""
    {
      "format": "fruscollection",
      "formatVersion": 1,
      "name": "Escalation rhetoric — round 1",
      "composition": {
        "defaultBodyDepth": "full",
        "footnoteStyle": "all",
        "tocStyle": "citation",
        "applyHighlights": false,
        "includeNotes": true,
        "includeWordCloud": false
      },
      "entries": [
        { "kind": "heading", "text": "Strong candidates" },
        { "kind": "document", "volumeId": "frus1961-63v11", "documentId": "d1" },
        { "kind": "document", "volumeId": "frus1964-68v32", "documentId": "d17" }
      ]
    }
    """.utf8)

    @Test("The guide's published write-minimum decodes and imports, with no key the spec omits")
    func publishedWriteMinimumConforms() throws {
        let file = try NativeCollectionSerializer.decode(Self.publishedWriteMinimum)
        #expect(file.name == "Escalation rhetoric — round 1")
        #expect(file.minimumReaderVersion == nil, "the minimum carries no floor; formatVersion is the gate")

        let container = try ModelContainer.makeTestContainer()
        let ctx = ModelContext(container)
        let imported = NativeCollectionSerializer.apply(file, into: ctx)
        try ctx.save()

        let entries = (imported.documentEntries ?? []).sorted { $0.sortOrder < $1.sortOrder }
        try #require(entries.count == 3)
        #expect(entries[0].entryKind == .heading)
        #expect(entries[1].documentId == "d1")
        #expect(entries[2].volumeId == "frus1964-68v32")
    }

    @Test("The guide's §15 example and this fixture are the same file")
    func publishedExampleMatchesTheGuide() throws {
        // The doc comment above promises the literal and the guide agree. Discipline is not a
        // mechanism, so this checks it: pull the first JSON block out of §15 and require it to
        // decode to the same value. An editor improving the guide's prose cannot silently move
        // the spec away from what the app accepts.
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let guideURL = root.appendingPathComponent("Docs/Agentic-Analysis-Guide.md")
        let guide = try String(contentsOf: guideURL, encoding: .utf8)

        let section = try #require(guide.range(of: "### 15.1 The write-minimum"),
                                   "the guide lost §15.1")
        let after = guide[section.upperBound...]
        let open = try #require(after.range(of: "```json\n"), "§15.1 lost its JSON block")
        let rest = after[open.upperBound...]
        let close = try #require(rest.range(of: "\n```"), "§15.1's JSON block is unterminated")
        let published = Data(rest[..<close.lowerBound].utf8)

        let fromGuide = try NativeCollectionSerializer.decode(published)
        let fromFixture = try NativeCollectionSerializer.decode(Self.publishedWriteMinimum)
        #expect(fromGuide == fromFixture,
                "the guide publishes a different file from the one this suite proves opens")
    }

    @Test("An agent may add a generator key: unknown top-level keys are free, and the app does not preserve them")
    func generatorKeyIsFreeAndNotPreserved() throws {
        // §15 tells agents they may stamp provenance with a `generator` key. That costs no format
        // change — the DTO has no such property and synthesized decoding never enumerates the
        // container — so this pins the tolerance the guide relies on.
        let stamped = Data("""
        {"format":"fruscollection","formatVersion":1,"name":"Stamped",
         "generator":"some-agent/1.0",
         "composition":{"defaultBodyDepth":"full","footnoteStyle":"all","tocStyle":"citation",
                        "applyHighlights":false,"includeNotes":true,"includeWordCloud":false},
         "entries":[{"kind":"document","volumeId":"v1","documentId":"d1"}]}
        """.utf8)
        let file = try NativeCollectionSerializer.decode(stamped)
        #expect(file.name == "Stamped")

        // And it is dropped on re-export, which the guide states rather than hides: a file the app
        // wrote was not written by that agent, so carrying the stamp forward would be a false claim.
        let reEncoded = try NativeCollectionSerializer.encode(file)
        let text = String(decoding: reEncoded, as: UTF8.self)
        #expect(!text.contains("generator"), "a re-export must not claim agent provenance it lacks")
    }

    @Test("The write-minimum's one unenforced constraint: a document entry missing its ids imports and then resolves to nothing")
    func documentEntryWithoutIdsIsAcceptedThenIgnored() throws {
        // §15 states this as a MUST because the app does not enforce it. The file opens, the
        // editor shows a populated collection, and every export is empty — the worst shape of
        // failure for an agent-written file, so the spec has to name it and the test has to prove
        // the app really is silent.
        let missingIds = Data("""
        {"format":"fruscollection","formatVersion":1,"name":"Broken",
         "composition":{"defaultBodyDepth":"full","footnoteStyle":"all","tocStyle":"citation",
                        "applyHighlights":false,"includeNotes":true,"includeWordCloud":false},
         "entries":[{"kind":"document"},{"kind":"document","volumeId":"v1"}]}
        """.utf8)
        let container = try ModelContainer.makeTestContainer()
        let ctx = ModelContext(container)
        let imported = NativeCollectionSerializer.apply(
            try NativeCollectionSerializer.decode(missingIds), into: ctx)
        try ctx.save()

        let entries = (imported.documentEntries ?? [])
        #expect(entries.count == 2, "both entries import — nothing rejects them")
        #expect(entries.allSatisfy { $0.documentId.isEmpty || $0.volumeId.isEmpty },
                "and both carry an empty id, which every resolver filters out downstream")
    }

    @Test("Front matter defaults: a new collection carries no front matter and no colophon (pre-Phase-4 behavior)")
    func frontMatterDefaults() {
        let collection = Collection(name: "Defaults")
        #expect(collection.subtitle == nil)
        #expect(collection.authorLine == nil)
        #expect(collection.introductionText == nil)
        #expect(collection.introductionRichText == nil)
        #expect(collection.includeColophon == false)
        #expect(collection.includeProjectProvenance == false)
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

    @Test("Headnote provenance: the attribution label honors authorship, and the resolver threads it to the export document")
    @MainActor
    func headnoteProvenance() async throws {
        // The attribution caption honors authorship (Composer redesign): AI keeps the label, an
        // AI-edited headnote discloses the edit, a user-written one carries no AI attribution.
        #expect(CollectionAIAttribution.headnoteLabel(authorship: .aiGenerated)?.contains("AI-generated") == true)
        #expect(CollectionAIAttribution.headnoteLabel(authorship: .aiEdited)?.contains("edited by you") == true)
        #expect(CollectionAIAttribution.headnoteLabel(authorship: .userWritten) == nil)

        // The resolver carries the pointed summary's authorship onto the export document, so the
        // renderers can suppress the AI attribution for a user-written headnote.
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        let appState = AppState()
        let coll = Collection(name: "Prov")
        context.insert(coll)
        let entry = CollectionEntry(collectionId: coll.id, documentId: "d1", volumeId: "pvol", sortOrder: 0)
        entry.includeHeadnote = true
        context.insert(entry)
        let userSummary = GeneratedSummary(documentId: "d1", volumeId: "pvol", promptId: UUID(),
                                           responseText: "A key takeaway I wrote.", authorship: .userWritten)
        context.insert(userSummary)
        entry.headnoteSummaryId = userSummary.id
        try context.save()

        let resolver = CollectionContentResolver(appState: appState, modelContext: context)
        let items = try await resolver.resolve(collection: coll, entries: [entry],
                                               allNotes: [], purpose: .preview)
        let doc = try #require(docPayload(items[0]))
        #expect(doc.headnoteText == "A key takeaway I wrote.")
        #expect(doc.headnoteAuthorship == .userWritten)
    }

    @Test("Legacy summary with a NULL authorship column (a row persisted before the field existed, or CloudKit-synced) reads back as .aiGenerated instead of trapping — guards the SwiftData optional-enum migration fix")
    @MainActor
    func legacyNilAuthorshipResolvesToAIGenerated() async throws {
        // Reproduces the crash a user hit on iPad: `Could not cast Optional<Any> to SummaryAuthorship`
        // at `GeneratedSummary.authorship.getter`. A non-optional enum property force-casts the NULL
        // that SwiftData reads for a pre-migration row. `authorship` is now optional, and every read
        // site coerces `nil` to `.aiGenerated`, so a legacy summary is attributed exactly as before.
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        let appState = AppState()
        let coll = Collection(name: "Legacy")
        context.insert(coll)
        let entry = CollectionEntry(collectionId: coll.id, documentId: "d1", volumeId: "lvol", sortOrder: 0)
        entry.includeHeadnote = true
        context.insert(entry)
        let legacy = GeneratedSummary(documentId: "d1", volumeId: "lvol", promptId: UUID(),
                                      responseText: "A pre-migration summary.")
        // Simulate a row whose `authorship` column is NULL (only possible now that the field is optional).
        legacy.authorship = nil
        context.insert(legacy)
        entry.headnoteSummaryId = legacy.id
        try context.save()

        // Reading `.authorship` on the NULL row must not trap; the resolver coerces it to the default.
        let resolver = CollectionContentResolver(appState: appState, modelContext: context)
        let items = try await resolver.resolve(collection: coll, entries: [entry],
                                               allNotes: [], purpose: .preview)
        let doc = try #require(docPayload(items[0]))
        #expect(doc.headnoteText == "A pre-migration summary.")
        #expect(doc.headnoteAuthorship == .aiGenerated)
    }

    @Test("Headnote draft flag persists: a GeneratedSummary created with isHeadnoteDraft round-trips through SwiftData (guards the draft-isolation contract that keeps drafts out of the document's summary carousel)")
    func headnoteDraftFlagPersists() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        let draft = GeneratedSummary(documentId: "d1", volumeId: "hvol", promptId: UUID(),
                                     responseText: "Private draft.", authorship: .aiGenerated,
                                     isHeadnoteDraft: true)
        context.insert(draft)
        let ordinary = GeneratedSummary(documentId: "d1", volumeId: "hvol", promptId: UUID(),
                                        responseText: "Ordinary summary.")
        context.insert(ordinary)
        try context.save()

        // Fetch back from a fresh context — the flag must survive persistence, or the entire
        // draft-isolation mechanism (carousel/picker/resolver-fallback exclusion) silently breaks.
        let fresh = ModelContext(container)
        let all = try fresh.fetch(FetchDescriptor<GeneratedSummary>())
        let savedDraft = try #require(all.first { $0.responseText == "Private draft." })
        let savedOrdinary = try #require(all.first { $0.responseText == "Ordinary summary." })
        #expect(savedDraft.isHeadnoteDraft == true)
        #expect(savedOrdinary.isHeadnoteDraft == false)
    }

    @Test("Body-depth chip label: the compact row pill uses the short form, distinct from the full control name")
    func bodyDepthChipLabel() {
        #expect(CollectionBodyDepth.full.chipLabel == "Full")
        #expect(CollectionBodyDepth.summaryOnly.chipLabel == "Summary")
        #expect(CollectionBodyDepth.index.chipLabel == "Index")
        // The chip label is deliberately briefer than the full display name ("Summary only").
        #expect(CollectionBodyDepth.summaryOnly.chipLabel != CollectionBodyDepth.summaryOnly.displayName)
    }

    @Test("Headnote chip resolution: an explicit per-entry override wins; a Default (nil) inherits the collection's defaultIncludeHeadnote")
    @MainActor
    func headnoteChipResolution() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        let collOn = Collection(name: "On")
        collOn.defaultIncludeHeadnote = true
        context.insert(collOn)
        let collOff = Collection(name: "Off")
        collOff.defaultIncludeHeadnote = false
        context.insert(collOff)

        func entry(in coll: Collection, includeHeadnote: Bool?) -> CollectionEntry {
            let e = CollectionEntry(collectionId: coll.id, documentId: "d1", volumeId: "v1", sortOrder: 0)
            e.collection = coll   // set the relationship the resolver reads
            e.includeHeadnote = includeHeadnote
            context.insert(e)
            return e
        }
        // Explicit per-entry override wins over the collection default (both directions).
        #expect(collectionEntryHeadnoteIsResolvedOn(entry(in: collOff, includeHeadnote: true)) == true)
        #expect(collectionEntryHeadnoteIsResolvedOn(entry(in: collOn, includeHeadnote: false)) == false)
        // Default (nil) inherits the collection default — the resolution-aware chip behavior.
        #expect(collectionEntryHeadnoteIsResolvedOn(entry(in: collOn, includeHeadnote: nil)) == true)
        #expect(collectionEntryHeadnoteIsResolvedOn(entry(in: collOff, includeHeadnote: nil)) == false)
    }

    @Test("Preset composition: applyFields overwrites every field per the recipe; apparatusBlocks(notAlreadyIn:) is append-only")
    @MainActor
    func presetApply() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        let coll = Collection(name: "Preset")
        context.insert(coll)

        // Teaching reader: full text, notes + source note on, Header & Dateline ToC, +persons/chronology.
        CollectionPreset.teachingReader.applyFields(to: coll)
        #expect(coll.defaultBodyDepth == CollectionBodyDepth.full.rawValue)
        #expect(coll.includeNotes == true)
        #expect(coll.effectiveIncludeSourceNote == true)
        #expect(coll.effectiveIncludeFootnotes == false)
        #expect(coll.defaultIncludeHeadnote == false)
        #expect(coll.applyHighlights == false)
        #expect(coll.tocStyle == CollectionToCStyle.headerAndDateline.rawValue)
        #expect(CollectionPreset.teachingReader.apparatusBlocks == [.personsIndex, .chronology])

        // Briefing packet: summary-only, headnotes + word cloud on; highlights on (inert with
        // summary-only body, by design); no apparatus.
        CollectionPreset.briefingPacket.applyFields(to: coll)
        #expect(coll.defaultBodyDepth == CollectionBodyDepth.summaryOnly.rawValue)
        #expect(coll.defaultIncludeHeadnote == true)
        #expect(coll.includeWordCloud == true)
        #expect(coll.applyHighlights == true)
        #expect(coll.tocStyle == CollectionToCStyle.headerAndDateline.rawValue)
        #expect(CollectionPreset.briefingPacket.apparatusBlocks.isEmpty)

        // Source dossier: index/outline body, footnotes off, source note on, Citation ToC.
        CollectionPreset.sourceDossier.applyFields(to: coll)
        #expect(coll.defaultBodyDepth == CollectionBodyDepth.index.rawValue)
        #expect(coll.effectiveIncludeFootnotes == false)
        #expect(coll.effectiveIncludeSourceNote == true)
        #expect(coll.tocStyle == CollectionToCStyle.citation.rawValue)
        #expect(CollectionPreset.sourceDossier.apparatusBlocks == [.archivalSources])

        // Scholarly edition: everything on; all five apparatus.
        CollectionPreset.scholarlyEdition.applyFields(to: coll)
        #expect(coll.effectiveIncludeFootnotes == true)
        #expect(coll.effectiveIncludeSourceNote == true)
        #expect(coll.includeNotes == true)
        #expect(coll.defaultIncludeHeadnote == true)
        #expect(coll.applyHighlights == true)
        #expect(coll.includeWordCloud == true)
        #expect(coll.tocStyle == CollectionToCStyle.citation.rawValue)
        #expect(Set(CollectionPreset.scholarlyEdition.apparatusBlocks) == Set(CollectionGeneratedBlockType.allCases))

        // Append-only, non-destructive: apparatusBlocks(notAlreadyIn:) drops blocks already present.
        #expect(CollectionPreset.teachingReader.apparatusBlocks(notAlreadyIn: []) == [.personsIndex, .chronology])
        #expect(CollectionPreset.teachingReader.apparatusBlocks(
            notAlreadyIn: [CollectionGeneratedBlockType.personsIndex.rawValue]) == [.chronology])
        let allPresent = Set(CollectionGeneratedBlockType.allCases.map(\.rawValue))
        #expect(CollectionPreset.scholarlyEdition.apparatusBlocks(notAlreadyIn: allPresent).isEmpty)
    }

    @Test("Composition summary sentence: leads with the body-depth phrasing and lists the enabled content")
    func compositionSummarySentence() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        let coll = Collection(name: "Summary")
        context.insert(coll)

        // Full body, nothing else enabled → just the lead phrase, no "with" clause.
        coll.defaultBodyDepth = CollectionBodyDepth.full.rawValue
        coll.includeNotes = false
        coll.effectiveIncludeFootnotes = false
        coll.effectiveIncludeSourceNote = false
        coll.defaultIncludeHeadnote = false
        coll.applyHighlights = false
        coll.includeWordCloud = false
        #expect(coll.compositionSummarySentence == "Exports the full text of each document.")

        // Summary-only + headnotes + notes + footnotes → AI-summary lead + a "with" list.
        coll.defaultBodyDepth = CollectionBodyDepth.summaryOnly.rawValue
        coll.defaultIncludeHeadnote = true
        coll.includeNotes = true
        coll.effectiveIncludeFootnotes = true
        let s = coll.compositionSummarySentence
        #expect(s.contains("AI summary of each document"))
        #expect(s.contains("headnotes"))
        #expect(s.contains("your notes"))
        #expect(s.contains("footnotes"))
        #expect(s.hasSuffix("."))

        // Index/outline uses the citation-only-index lead.
        coll.defaultBodyDepth = CollectionBodyDepth.index.rawValue
        #expect(coll.compositionSummarySentence.contains("citation-only index"))
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

    @Test("AI attribution: exported generated summaries carry the Apple Intelligence caption in HTML, DOCX, and PDF; placeholders and summary-free collections carry none")
    func aiAttributionAcrossFormats() async throws {
        let label = CollectionAIAttribution.label()
        #expect(label.contains("AI-generated"))
        #expect(label.contains("Apple Intelligence"))
        // The future model-name seam takes precedence when a name is ever stored.
        #expect(CollectionAIAttribution.label(modelName: "TestModel 1").contains("TestModel 1"))

        let summaryDoc = CollectionExportDocument(
            documentId: "d1", volumeId: "aivol", sortOrder: 1,
            bodyDepth: .summaryOnly, title: "Summarized Memo",
            bodyText: "Full body never rendered.",
            citation: "Summarized Citation", summaryText: "A generated precis.")
        let headnoteDoc = CollectionExportDocument(
            documentId: "d2", volumeId: "aivol", sortOrder: 2,
            title: "Headnoted Memo", bodyText: "Headnoted body paragraph.",
            citation: "Headnoted Citation",
            includeHeadnote: true, headnoteText: "A generated abstract.")
        let placeholderDoc = CollectionExportDocument(
            documentId: "d3", volumeId: "aivol", sortOrder: 3,
            title: "Pending Memo", bodyText: "Pending body paragraph.",
            citation: "Pending Citation",
            includeHeadnote: true, headnoteText: nil)
        let plainDoc = CollectionExportDocument(
            documentId: "d4", volumeId: "aivol", sortOrder: 4,
            title: "Plain Memo", bodyText: "Plain body paragraph.",
            citation: "Plain Citation")
        let items: [CollectionExportItem] = [
            .document(summaryDoc), .document(headnoteDoc),
            .document(placeholderDoc), .document(plainDoc)]
        // A placeholder headnote renders no AI text, so it must NOT flip the
        // attribution layer on — only the plain and placeholder docs travel here.
        let offItems: [CollectionExportItem] = [.document(placeholderDoc), .document(plainDoc)]
        let metadata = CollectionExportMetadata(name: "Attribution Fixture", note: nil)

        // HTML — one caption per rendered summary (summary body + filled headnote),
        // none for the placeholder; the stylesheet is emitted only when a caption is.
        let htmlURL = try await HTMLCollectionExporter().export(metadata: metadata, items: items)
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        #expect(html.components(separatedBy: "class=\"ai-attribution\"").count - 1 == 2)
        #expect(html.contains(label))
        let htmlOffURL = try await HTMLCollectionExporter().export(metadata: metadata, items: offItems)
        let htmlOff = try String(contentsOf: htmlOffURL, encoding: .utf8)
        #expect(!htmlOff.contains("ai-attribution"))
        #expect(!htmlOff.contains("AI-generated"))

        // DOCX — the caption paragraph follows the summary and the filled headnote.
        let docx = try Data(contentsOf: try await DocxCollectionExporter().export(
            metadata: metadata, items: items))
        #expect(docx.range(of: Data(label.utf8)) != nil)
        let docxOff = try Data(contentsOf: try await DocxCollectionExporter().export(
            metadata: metadata, items: offItems))
        #expect(docxOff.range(of: Data("AI-generated".utf8)) == nil)

        // PDF — extract page text with PDFKit.
        let pdf = try Data(contentsOf: try await PDFCollectionExporter().export(
            metadata: metadata, items: items))
        let pdfDoc = try #require(PDFDocument(data: pdf))
        let pdfText = (0..<pdfDoc.pageCount)
            .compactMap { pdfDoc.page(at: $0)?.string }.joined(separator: "\n")
        #expect(pdfText.contains("AI-generated summary"))
        #expect(pdfText.contains("Apple Intelligence"))
        let pdfOff = try Data(contentsOf: try await PDFCollectionExporter().export(
            metadata: metadata, items: offItems))
        let pdfOffDoc2 = try #require(PDFDocument(data: pdfOff))
        let pdfOffText2 = (0..<pdfOffDoc2.pageCount)
            .compactMap { pdfOffDoc2.page(at: $0)?.string }.joined(separator: "\n")
        #expect(!pdfOffText2.contains("AI-generated"))
    }

    @Test("HTML footnote gate: options.includeFootnotes drives footnote emission for a rendered model — the legacy .all/.none behaviors, now independently combinable with the source note")
    func htmlFootnoteGate() {
        let model = FRUSDocumentRenderModel(
            documentId: "d1",
            bodyNodes: [.paragraph([.plainText("Gated body."),
                                    .footnoteMarker(id: "fn1", type: .editorial, sequentialNumber: 1, displayLabel: "1")])],
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

    @Test("PDF/DOCX footnote gate (owner decision 2026-07-03): includeFootnotes now drives footnote emission in both formats — false drops the footnote bodies (markers stay, matching HTML); an untouched collection's derived (true,false) pair keeps footnotes, byte-identically for DOCX")
    func pdfDocxFootnoteGate() async throws {
        // Same fixture as htmlFootnoteGate: one paragraph with a marker + one footnote.
        let model = FRUSDocumentRenderModel(
            documentId: "d1",
            bodyNodes: [.paragraph([.plainText("Gated body."),
                                    .footnoteMarker(id: "fn1", type: .editorial, sequentialNumber: 1, displayLabel: "1")])],
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

        var onOptions = CollectionExportOptions()
        onOptions.includeFootnotes = true
        onOptions.includeSourceNote = true
        var offOptions = onOptions
        offOptions.includeFootnotes = false

        // DOCX — the stored-mode ZIP keeps document.xml/footnotes.xml uncompressed, so
        // XML substrings are directly searchable in the package bytes.
        let docxOn = try Data(contentsOf: try await DocxCollectionExporter().export(
            metadata: metadata, items: items, options: onOptions))
        func onContains(_ s: String) -> Bool { docxOn.range(of: Data(s.utf8)) != nil }
        #expect(onContains("The footnote text."))
        #expect(onContains("<w:footnoteReference w:id="))
        #expect(onContains("RG 59, Central Files."))
        let docxOff = try Data(contentsOf: try await DocxCollectionExporter().export(
            metadata: metadata, items: items, options: offOptions))
        func offContains(_ s: String) -> Bool { docxOff.range(of: Data(s.utf8)) != nil }
        #expect(!offContains("The footnote text."))
        #expect(!offContains("<w:footnoteReference w:id="))
        #expect(offContains("Gated body."))
        // Markers survive as plain superscript label runs — HTML likewise keeps its
        // .fn-marker buttons when footnote bodies are dropped.
        #expect(offContains("<w:vertAlign w:val=\"superscript\"/>"))
        #expect(offContains("RG 59, Central Files."))   // source note is independent

        // PDF — extract page text with PDFKit.
        let pdfOn = try Data(contentsOf: try await PDFCollectionExporter().export(
            metadata: metadata, items: items, options: onOptions))
        let pdfOnDoc = try #require(PDFDocument(data: pdfOn))
        let pdfOnText = (0..<pdfOnDoc.pageCount)
            .compactMap { pdfOnDoc.page(at: $0)?.string }.joined(separator: "\n")
        #expect(pdfOnText.contains("The footnote text."))
        #expect(pdfOnText.contains("RG 59, Central Files."))
        let pdfOff = try Data(contentsOf: try await PDFCollectionExporter().export(
            metadata: metadata, items: items, options: offOptions))
        let pdfOffDoc = try #require(PDFDocument(data: pdfOff))
        let pdfOffText = (0..<pdfOffDoc.pageCount)
            .compactMap { pdfOffDoc.page(at: $0)?.string }.joined(separator: "\n")
        #expect(!pdfOffText.contains("The footnote text."))
        #expect(pdfOffText.contains("Gated body."))
        #expect(pdfOffText.contains("RG 59, Central Files."))

        // Untouched-collection identity: a legacy footnoteStyle "all" collection with a
        // nil pair derives (true, false) — building options from it produces DOCX bytes
        // identical to the default-options path (the ZIP writer zeroes timestamps and
        // the cover date is day-granular), and the footnote text still renders. This is
        // exactly today's ungated output for an untouched collection; only legacy
        // none/sourceNoteOnly collections change, BY DESIGN (owner decision 2026-07-03).
        let untouched = Collection(name: "Untouched")
        #expect(untouched.includeFootnotes == nil)
        var derived = CollectionExportOptions()
        derived.includeFootnotes = untouched.effectiveIncludeFootnotes
        derived.includeSourceNote = untouched.effectiveIncludeSourceNote
        let derivedDocx = try Data(contentsOf: try await DocxCollectionExporter().export(
            metadata: metadata, items: items, options: derived))
        let defaultDocx = try Data(contentsOf: try await DocxCollectionExporter().export(
            metadata: metadata, items: items))
        #expect(derivedDocx == defaultDocx)
        #expect(derivedDocx.range(of: Data("The footnote text.".utf8)) != nil)
        // (No source-note assertion here: that gate lives in the resolver — it only
        // populates `sourceNoteText` when includeSourceNote is on — and this fixture
        // sets the field directly, bypassing the resolver.)
        // PDF, same derivation: footnotes render for the untouched default.
        let derivedPDF = try Data(contentsOf: try await PDFCollectionExporter().export(
            metadata: metadata, items: items, options: derived))
        let derivedPDFDoc = try #require(PDFDocument(data: derivedPDF))
        let derivedPDFText = (0..<derivedPDFDoc.pageCount)
            .compactMap { derivedPDFDoc.page(at: $0)?.string }.joined(separator: "\n")
        #expect(derivedPDFText.contains("The footnote text."))
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

        // A v1 file (no Phase 5 keys) leaves the defaults: nil pair, headnote at Default (nil).
        // Composer redesign widened includeHeadnote to optional, so an absent key now imports as
        // nil (Default → inherits the collection default, false here) rather than an explicit false —
        // the same "no headnote" behavior, a different sentinel.
        let v1JSON = Data(#"{"format":"fruscollection","formatVersion":1,"name":"Old","composition":{"defaultBodyDepth":"full","footnoteStyle":"sourceNoteOnly","tocStyle":"citation","applyHighlights":false,"includeNotes":true,"includeWordCloud":false},"entries":[{"kind":"document","documentId":"d1","volumeId":"v1"}]}"#.utf8)
        let old = NativeCollectionSerializer.apply(
            try NativeCollectionSerializer.decode(v1JSON), into: destCtx)
        #expect(old.includeFootnotes == nil)
        #expect(old.includeSourceNote == nil)
        #expect(old.effectiveIncludeSourceNote == true)   // derived from the legacy style
        let oldEntry = try #require((old.documentEntries ?? []).first)
        #expect(oldEntry.includeHeadnote == nil)
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

        coll.defaultIncludeHeadnote = true                 // the collection headnote default → v2
        #expect(makeFile().formatVersion == 2)
        #expect(makeFile().composition.defaultIncludeHeadnote == true)
        coll.defaultIncludeHeadnote = false                // cleared → omitted → v1
        #expect(makeFile().formatVersion == 1)
        #expect(makeFile().composition.defaultIncludeHeadnote == nil)

        d.applyHighlightsOverride = true                   // any override → v2
        #expect(makeFile().formatVersion == 2)
        d.applyHighlightsOverride = nil
        #expect(makeFile().formatVersion == 1)

        d.includeRelatedDocuments = true                   // the A10 opt-in → v2
        #expect(makeFile().formatVersion == 2)
        d.includeRelatedDocuments = nil
        #expect(makeFile().formatVersion == 1)

        // selectedHighlightIds alone must NOT flip the file: it never serializes
        // (device-local highlight UUIDs — the highlights don't travel with the file).
        d.selectedHighlightIds = [UUID()]
        #expect(makeFile().formatVersion == 1)
        d.selectedHighlightIds = []
    }

    // MARK: - Override cascade + related documents (Authoring Phase 5)

    @Test("Outline generic cascade: a deeper heading's value shadows a shallower ancestor's; a valueless sibling resets to the ancestor; typed values, one walk per field")
    func outlineGenericOverrideCascade() {
        func heading(_ level: Int) -> CollectionOutline.StructuralRef {
            .init(isHeading: true, level: level, bodyDepthOverride: nil)
        }
        let doc = CollectionOutline.StructuralRef(isHeading: false, level: 1,
                                                  bodyDepthOverride: nil)
        // H1(l1,true) H2(l2,false) doc H3(l2,nil) doc H4(l1,nil) doc
        let refs = [heading(1), heading(2), doc, heading(2), doc, heading(1), doc]
        let values: [Bool?] = [true, false, nil, nil, nil, nil, nil]
        let resolved = CollectionOutline.sectionOverrideValues(refs, headingValues: values)
        #expect(resolved == [true, false, false, true, true, nil, nil])

        // The body-depth cascade is the same core (delegation check).
        let depthRefs = [
            CollectionOutline.StructuralRef(isHeading: true, level: 1, bodyDepthOverride: "index"),
            doc,
            CollectionOutline.StructuralRef(isHeading: true, level: 1, bodyDepthOverride: nil),
            doc,
        ]
        #expect(CollectionOutline.sectionBodyDepthOverrides(depthRefs) ==
                ["index", "index", nil, nil])
    }

    @Test("Override cascade: entry beats section beats collection, per field — resolved through the one resolver pipeline")
    @MainActor
    func overrideCascadeResolution() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        let appState = AppState()

        let promptB = UUID()
        let promptC = UUID()
        let coll = Collection(name: "Cascade")
        coll.defaultBodyDepth = "full"
        coll.applyHighlights = false          // collection default: highlights off
        context.insert(coll)

        // One highlight each on d1 and d2, so the highlight gate is observable.
        for did in ["d1", "d2"] {
            context.insert(DocumentHighlight(
                volumeId: "cascvol", documentId: did,
                startOffset: 0, endOffset: 4,
                colorTag: "yellow", selectedText: "text",
                renderingVersion: "cascade000000000"))
        }

        // d0 precedes every heading: pure collection defaults.
        let d0 = CollectionEntry(collectionId: coll.id, documentId: "d0",
                                 volumeId: "cascvol", sortOrder: 0)
        // The heading sets section defaults for everything below it.
        let h = CollectionEntry(collectionId: coll.id, documentId: "", volumeId: "",
                                sortOrder: 1)
        h.entryKind = .heading
        h.text = "Part I"
        h.applyHighlightsOverride = true
        h.includeNotesOverride = false
        h.includeFootnotesOverride = false
        h.summaryPromptIdOverride = promptB
        // d1 has no overrides of its own: the section's apply.
        let d1 = CollectionEntry(collectionId: coll.id, documentId: "d1",
                                 volumeId: "cascvol", sortOrder: 2)
        // d2 sets its own: the entry beats the section.
        let d2 = CollectionEntry(collectionId: coll.id, documentId: "d2",
                                 volumeId: "cascvol", sortOrder: 3)
        d2.applyHighlightsOverride = false
        d2.includeFootnotesOverride = true
        d2.summaryPromptIdOverride = promptC
        for entry in [d0, h, d1, d2] { context.insert(entry) }
        try context.save()

        let resolver = CollectionContentResolver(appState: appState, modelContext: context)
        let items = try await resolver.resolve(collection: coll, entries: [d0, h, d1, d2],
                                               allNotes: [], purpose: .preview)
        let docs = items.documents
        try #require(docs.count == 3)

        // d0: nothing resolved anywhere — payload overrides nil, collection gates apply.
        #expect(docs[0].applyHighlightsOverride == nil)
        #expect(docs[0].includeNotesOverride == nil)
        #expect(docs[0].includeFootnotesOverride == nil)
        #expect(docs[0].summaryPromptIdOverride == nil)
        #expect(docs[0].highlights.isEmpty)               // collection applyHighlights false

        // d1: the section defaults apply — including the highlight fetch itself.
        #expect(docs[1].applyHighlightsOverride == true)
        #expect(docs[1].includeNotesOverride == false)
        #expect(docs[1].includeFootnotesOverride == false)
        #expect(docs[1].summaryPromptIdOverride == promptB)
        #expect(docs[1].highlights.count == 1)            // section turned highlights on

        // d2: its own overrides beat the section's.
        #expect(docs[2].applyHighlightsOverride == false)
        #expect(docs[2].includeFootnotesOverride == true)
        #expect(docs[2].summaryPromptIdOverride == promptC)
        #expect(docs[2].highlights.isEmpty)               // entry turned highlights back off
        #expect(docs[2].includeNotesOverride == false)    // un-overridden field: section's
    }

    @Test("Per-highlight selection (A8): selectedHighlightIds filter the injected set; empty means all; stale ids just filter")
    @MainActor
    func selectedHighlightFiltering() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        let appState = AppState()

        let coll = Collection(name: "Selection")
        coll.defaultBodyDepth = "full"
        coll.applyHighlights = true
        context.insert(coll)

        var highlights: [DocumentHighlight] = []
        for (i, offset) in [0, 10, 20].enumerated() {
            let hl = DocumentHighlight(
                volumeId: "selvol", documentId: "d1",
                startOffset: offset, endOffset: offset + 4,
                colorTag: i == 1 ? "green" : "yellow",
                selectedText: "pass", renderingVersion: "selection0000000")
            context.insert(hl)
            highlights.append(hl)
        }
        let entry = CollectionEntry(collectionId: coll.id, documentId: "d1",
                                    volumeId: "selvol", sortOrder: 0)
        context.insert(entry)
        try context.save()

        let resolver = CollectionContentResolver(appState: appState, modelContext: context)

        // Empty selection = all highlights (the pre-override behavior).
        let all = try await resolver.resolve(collection: coll, entries: [entry],
                                             allNotes: [], purpose: .preview)
        #expect(try #require(docPayload(all[0])).highlights.count == 3)

        // A subset selection filters to exactly those highlights.
        entry.selectedHighlightIds = [highlights[0].id, highlights[2].id]
        let subset = try await resolver.resolve(collection: coll, entries: [entry],
                                                allNotes: [], purpose: .preview)
        let picked = try #require(docPayload(subset[0])).highlights
        #expect(picked.count == 2)
        #expect(Set(picked.map(\.startOffset)) == [0, 20])

        // Stale ids (deleted/unsynced highlights) simply filter — never crash, never all.
        entry.selectedHighlightIds = [UUID()]
        let stale = try await resolver.resolve(collection: coll, entries: [entry],
                                               allNotes: [], purpose: .preview)
        #expect(try #require(docPayload(stale[0])).highlights.isEmpty)
    }

    @Test("Related documents (A10): only in-collection targets survive, in collection order, deduplicated, self excluded")
    func relatedDocumentsInCollectionOnly() {
        let membership: [(volumeId: String, documentId: String)] = [
            ("v1", "d1"), ("v1", "d2"), ("v2", "d5"), ("v1", "d9"),
        ]
        // Outbound edges from v1/d1: an in-collection target twice (dedupe), a target
        // outside the collection (dropped), itself (excluded), and a later member.
        let targets: [(volumeId: String, documentId: String)] = [
            ("v1", "d9"), ("v3", "d7"), ("v1", "d1"), ("v1", "d2"), ("v1", "d2"),
        ]
        let related = CollectionContentResolver.relatedDocumentTargets(
            outboundTargets: targets,
            selfVolumeId: "v1", selfDocumentId: "d1",
            collectionDocuments: membership)
        #expect(related.map { "\($0.volumeId)/\($0.documentId)" } == ["v1/d2", "v1/d9"])

        // No outbound edges → empty; a document not in the membership referencing
        // members still yields collection-ordered results.
        #expect(CollectionContentResolver.relatedDocumentTargets(
            outboundTargets: [], selfVolumeId: "v1", selfDocumentId: "d1",
            collectionDocuments: membership).isEmpty)
    }

    @Test("Summary prompt override: the effective prompt picks the stored summary per entry; un-overridden entries keep the collection prompt")
    @MainActor
    func summaryPromptOverridePick() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        let appState = AppState()

        let promptA = UUID()
        let promptB = UUID()
        let coll = Collection(name: "Prompts")
        coll.defaultBodyDepth = "summaryOnly"
        coll.summaryPromptId = promptA
        context.insert(coll)

        context.insert(GeneratedSummary(documentId: "d1", volumeId: "provol",
                                        promptId: promptA, responseText: "Prompt A summary."))
        context.insert(GeneratedSummary(documentId: "d2", volumeId: "provol",
                                        promptId: promptA, responseText: "Prompt A other."))
        context.insert(GeneratedSummary(documentId: "d2", volumeId: "provol",
                                        promptId: promptB, responseText: "Prompt B summary."))

        let e1 = CollectionEntry(collectionId: coll.id, documentId: "d1",
                                 volumeId: "provol", sortOrder: 0)
        let e2 = CollectionEntry(collectionId: coll.id, documentId: "d2",
                                 volumeId: "provol", sortOrder: 1)
        e2.summaryPromptIdOverride = promptB
        context.insert(e1)
        context.insert(e2)
        try context.save()

        let resolver = CollectionContentResolver(appState: appState, modelContext: context)
        let items = try await resolver.resolve(collection: coll, entries: [e1, e2],
                                               allNotes: [], purpose: .preview)
        let docs = items.documents
        try #require(docs.count == 2)
        #expect(docs[0].summaryText == "Prompt A summary.")   // collection prompt
        #expect(docs[1].summaryText == "Prompt B summary.")   // entry override wins
        #expect(docs[1].summaryPromptIdOverride == promptB)
    }

    @Test("NativeFormat overrides: the six override keys round-trip on documents and headings; selectedHighlightIds never serializes and imports empty")
    func nativeOverrideRoundTrip() throws {
        let container = try ModelContainer.makeTestContainer()
        let ctx = ModelContext(container)

        let promptId = UUID()
        let highlightId = UUID()
        let coll = Collection(name: "Overrides")
        ctx.insert(coll)
        let h = CollectionEntry(collectionId: coll.id, documentId: "", volumeId: "",
                                sortOrder: 0)
        h.entryKind = .heading
        h.text = "Part I"
        h.includeNotesOverride = false
        h.includeRelatedDocuments = true
        h.collection = coll
        let d = CollectionEntry(collectionId: coll.id, documentId: "d1", volumeId: "v1",
                                sortOrder: 1)
        d.applyHighlightsOverride = true
        d.includeSourceNoteOverride = true
        d.includeFootnotesOverride = false
        d.summaryPromptIdOverride = promptId
        d.selectedHighlightIds = [highlightId]     // device-local: must NOT travel
        d.collection = coll
        ctx.insert(h); ctx.insert(d)
        try ctx.save()

        let file = NativeCollectionSerializer.makeFile(
            from: coll, includeNotes: false, resolveNoteTexts: { _ in [] })
        #expect(file.formatVersion == 2)            // overrides are a v2 feature
        #expect(file.minimumReaderVersion == 1)     // …but degradable: floor stays 1

        let data = try NativeCollectionSerializer.encode(file)
        let json = String(decoding: data, as: UTF8.self)
        for key in ["applyHighlightsOverride", "includeNotesOverride",
                    "includeSourceNoteOverride", "includeFootnotesOverride",
                    "summaryPromptIdOverride", "includeRelatedDocuments"] {
            #expect(json.contains("\"\(key)\""), "override key '\(key)' should serialize")
        }
        // The highlight-UUID-leak guard: no key, no value.
        #expect(!json.contains("selectedHighlightIds"))
        #expect(!json.contains(highlightId.uuidString))

        // Import onto a fresh store: overrides reconstruct; the highlight selection
        // resets to empty = all-of-the-recipient's-highlights semantics.
        let container2 = try ModelContainer.makeTestContainer()
        let ctx2 = ModelContext(container2)
        let imported = NativeCollectionSerializer.apply(
            try NativeCollectionSerializer.decode(data), into: ctx2)
        try ctx2.save()
        let entries = (imported.documentEntries ?? []).sorted { $0.sortOrder < $1.sortOrder }
        try #require(entries.count == 2)
        #expect(entries[0].entryKind == .heading)
        #expect(entries[0].includeNotesOverride == false)
        #expect(entries[0].includeRelatedDocuments == true)
        #expect(entries[0].applyHighlightsOverride == nil)
        #expect(entries[1].applyHighlightsOverride == true)
        #expect(entries[1].includeSourceNoteOverride == true)
        #expect(entries[1].includeFootnotesOverride == false)
        #expect(entries[1].summaryPromptIdOverride == promptId)
        #expect(entries[1].selectedHighlightIds.isEmpty)

        // Export → import → export is byte-identical (round-trip invariant).
        let file2 = NativeCollectionSerializer.makeFile(
            from: imported, includeNotes: false, resolveNoteTexts: { _ in [] })
        #expect(try NativeCollectionSerializer.encode(file2) == data)
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

    @Test("Excerpt capture contract: a flat-text span crossing block boundaries restores paragraph breaks, excludes offset-invisible content, and renders one <p> per paragraph")
    func blockAwareExcerptCapture() {
        // Two paragraphs plus a footnote marker: the flat text fuses the paragraphs
        // with no separator ("…the proposal.The Secretary…") and the marker digit is
        // offset-invisible (data-skip) — the two defects a raw slice / raw
        // sel.toString() capture exhibits.
        let model = FRUSDocumentRenderModel(
            documentId: "d1",
            bodyNodes: [
                .paragraph([.plainText("They agreed to the proposal."),
                            .footnoteMarker(id: "fn1", type: .editorial, sequentialNumber: 1, displayLabel: "1")]),
                .paragraph([.plainText("The Secretary replied at once.")]),
            ],
            footnotes: [])

        // The block partition is exactly the flat text, re-cut at block seams — so
        // flat-text offsets index into the joined blocks unchanged.
        let flat = buildFlatText(from: model)
        #expect(flat == "They agreed to the proposal.The Secretary replied at once.")
        #expect(buildFlatTextBlocks(from: model).joined() == flat)

        // A cross-paragraph span keeps its paragraph break; the marker digit the
        // offsets exclude never appears in the frozen passage.
        let spanning = flatTextExcerpt(from: model, start: 15, end: flat.utf16.count)
        #expect(spanning == "the proposal.\n\nThe Secretary replied at once.")

        // A single-block span is exactly the raw flat-text slice (pre-fix behavior).
        #expect(flatTextExcerpt(from: model, start: 0, end: 4) == "They")

        // Empty/inverted spans return nil — callers fall back to their old behavior.
        #expect(flatTextExcerpt(from: model, start: 5, end: 5) == nil)
        #expect(flatTextExcerpt(from: model, start: -1, end: 4) == nil)

        // The frozen two-paragraph passage renders two <p> elements inside the
        // excerpt blockquote (the HTML renderer serves export, preview, and PDF;
        // DOCX splits on the same "\n\n").
        let excerpt = CollectionExportExcerpt(
            text: spanning ?? "", documentId: "d1", volumeId: "v1",
            citation: "", colorTag: nil)
        let html = CollectionItemHTMLRenderer(options: CollectionExportOptions())
            .itemHTML(.excerpt(excerpt))
        #expect(html.contains("<p>the proposal.</p>"))
        #expect(html.contains("<p>The Secretary replied at once.</p>"))
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

    // MARK: - Generated apparatus blocks (Authoring Phase 6)

    @Test("Generated block vocabulary: raw values are the frozen serialization strings; position hints and kind membership hold")
    func generatedBlockTypeVocabulary() {
        // The raw values are persisted (entry field + .fruscollection key) — renaming
        // any of them is a data-format break, so they are pinned here.
        #expect(CollectionGeneratedBlockType.allCases.map(\.rawValue) ==
                ["bibliography", "chronology", "archivalSources", "personsIndex", "thematicIndex"])
        // Chronology opens the reader (front matter); everything else is back matter.
        #expect(CollectionGeneratedBlockType.chronology.defaultPosition == .frontMatter)
        for type in CollectionGeneratedBlockType.allCases where type != .chronology {
            #expect(type.defaultPosition == .backMatter)
        }
        // `.generated` is an authorable kind (unlike `.unrecognized`, which stays out).
        #expect(CollectionEntryKind.allCases.contains(.generated))
        #expect(!CollectionEntryKind.allCases.contains(.unrecognized))
        // An unknown raw value degrades to nil, never to some other block type.
        #expect(CollectionGeneratedBlockType(rawValue: "starCharts") == nil)
    }

    @Test("Resolver generated blocks: placeable anywhere, identical in preview and export, real rows resolve (degrading to fallbacks without an index), unknown block types are skipped")
    @MainActor
    func resolverGeneratedBlockResolution() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        let appState = AppState()   // no downloadManager/pipeline — resolution is read-only

        let coll = Collection(name: "Apparatus")
        context.insert(coll)

        // Front-placed chronology, a heading, a document, then a back-placed
        // bibliography — proving placement is positional, not fixed.
        let chron = CollectionEntry(collectionId: coll.id, documentId: "", volumeId: "", sortOrder: 0)
        chron.entryKind = .generated
        chron.generatedBlockType = CollectionGeneratedBlockType.chronology.rawValue
        let h = CollectionEntry(collectionId: coll.id, documentId: "", volumeId: "", sortOrder: 1)
        h.entryKind = .heading
        h.text = "Part I"
        let d = CollectionEntry(collectionId: coll.id, documentId: "d3", volumeId: "appvol", sortOrder: 2)
        let bib = CollectionEntry(collectionId: coll.id, documentId: "", volumeId: "", sortOrder: 3)
        bib.entryKind = .generated
        bib.generatedBlockType = CollectionGeneratedBlockType.bibliography.rawValue
        // A block type from a newer build: skipped at resolve, never junk output.
        let future = CollectionEntry(collectionId: coll.id, documentId: "", volumeId: "", sortOrder: 4)
        future.entryKind = .generated
        future.generatedBlockType = "starCharts"
        // A malformed generated entry with no type at all: likewise skipped.
        let typeless = CollectionEntry(collectionId: coll.id, documentId: "", volumeId: "", sortOrder: 5)
        typeless.entryKind = .generated

        let entries = [chron, h, d, bib, future, typeless]
        for entry in entries {
            entry.collection = coll
            context.insert(entry)
        }
        try context.save()

        let resolver = CollectionContentResolver(appState: appState, modelContext: context)
        let preview = try await resolver.resolve(
            collection: coll, entries: entries, allNotes: [], purpose: .preview)
        #expect(preview.map(kindLabel) == ["generated", "heading", "document", "generated"])

        guard case .generated(let first) = preview[0],
              case .generated(let last) = preview[3] else {
            Issue.record("expected generated items at positions 0 and 3")
            return
        }
        #expect(first.type == .chronology)
        #expect(first.title == CollectionGeneratedBlockType.chronology.displayName)
        // No indexing pipeline in this AppState: the document has no date, so the
        // chronology degrades to the trailing "Undated" group — never an empty section.
        #expect(!first.rows.isEmpty)
        #expect(first.rows.first?.text == "Undated")
        #expect(first.rows.last?.indentLevel == 1)
        #expect(last.type == .bibliography)
        // Unknown volume: the bibliography cites via the "volumeId/documentId" fallback.
        #expect(last.rows.map(\.text) == ["appvol/d3"])

        // Block resolution is read-only and purpose-independent: an export resolve
        // renders the identical blocks (no downloads, no generation involved).
        let export = try await resolver.resolve(
            collection: coll, entries: entries, allNotes: [], purpose: .export)
        #expect(export.map(kindLabel) == preview.map(kindLabel))
        if case .generated(let exportFirst) = export[0] {
            #expect(exportFirst.rows.map(\.text) == first.rows.map(\.text))
        } else {
            Issue.record("export items[0] should be a generated block")
        }
    }

    @Test("Bibliography block: dedupes by document key, sorts by volume then document number (series order), cites through the data source")
    @MainActor
    func generatedBibliographyBlock() async {
        var fixture = FixtureBlockDataSource()
        fixture.citations = [
            "v1/d2":   "Doc 2 of Volume One",
            "v1/d10":  "Doc 10 of Volume One",
            "v1/app1": "Appendix of Volume One",
            "v2/d2":   "Doc 2 of Volume Two",
        ]
        // Duplicated membership + shuffled order: dedupe by key, then series order —
        // volume id first, numeric document number within it (d10 after d2, never
        // lexicographic), non-numeric ids after the numbered documents.
        let documents: [(volumeId: String, documentId: String)] = [
            ("v2", "d2"), ("v1", "d10"), ("v1", "app1"), ("v1", "d2"), ("v1", "d10"),
        ]
        let block = await CollectionGeneratedBlocks.resolve(
            type: .bibliography, documents: documents, dataSource: fixture)
        #expect(block.title == CollectionGeneratedBlockType.bibliography.displayName)
        #expect(block.rows.map(\.text) == [
            "Doc 2 of Volume One", "Doc 10 of Volume One",
            "Appendix of Volume One", "Doc 2 of Volume Two",
        ])
        #expect(block.rows.allSatisfy { $0.indentLevel == 0 && $0.url == nil })
    }

    @Test("Chronology block: date order with precision-honest labels and ranges, citations as secondary text, undated documents in a trailing indented group")
    @MainActor
    func generatedChronologyBlock() async {
        var fixture = FixtureBlockDataSource()
        fixture.citations = ["v1/d1": "Cite 1", "v1/d2": "Cite 2",
                             "v1/d3": "Cite 3", "v1/d4": "Cite 4", "v1/d5": "Cite 5"]
        fixture.dates = [
            "v1/d1": DocumentDateMetadata(dateISO: "1969-02-15", dateISOMax: nil,
                                          precision: .day, certainty: nil),
            "v1/d2": DocumentDateMetadata(dateISO: "1969-01-01", dateISOMax: nil,
                                          precision: .year, certainty: nil),
            "v1/d4": DocumentDateMetadata(dateISO: "1968-12-01", dateISOMax: nil,
                                          precision: .day, certainty: nil),
            "v1/d5": DocumentDateMetadata(dateISO: "1969-03-01", dateISOMax: "1969-04-30",
                                          precision: .month, certainty: nil),
        ]
        // d3 has no date row → the Undated group.
        let documents: [(volumeId: String, documentId: String)] =
            [("v1", "d1"), ("v1", "d2"), ("v1", "d3"), ("v1", "d4"), ("v1", "d5")]
        let block = await CollectionGeneratedBlocks.resolve(
            type: .chronology, documents: documents, dataSource: fixture)

        // 4 dated rows in date order, then the Undated heading + 1 indented document.
        #expect(block.rows.count == 6)
        #expect(block.rows[0].secondaryText == "Cite 4")   // 1968-12-01
        #expect(block.rows[0].text.contains("1968"))
        #expect(block.rows[1].text == "1969")              // year precision — never "January 1"
        #expect(block.rows[1].secondaryText == "Cite 2")
        #expect(block.rows[2].secondaryText == "Cite 1")   // 1969-02-15
        #expect(block.rows[3].text.contains("–"))          // month-precision range
        #expect(block.rows[3].secondaryText == "Cite 5")
        #expect(block.rows[4].text == "Undated")
        #expect(block.rows[5].text == "Cite 3")
        #expect(block.rows[5].indentLevel == 1)
    }

    @Test("Sources & Archives block: groups document_sources by archival collection, enriches with the bundled NARA resolution, lists referencing documents at indent 1")
    @MainActor
    func generatedArchivalSourcesBlock() async {
        typealias Record = CollectionGeneratedBlocks.SourceRecord
        var fixture = FixtureBlockDataSource()
        fixture.sources = [
            Record(volumeId: "v1", documentId: "d1", repository: nil, recordGroup: "59",
                   lotFile: "64 D 199", seriesName: "Conference Files", rawText: "raw a"),
            Record(volumeId: "v1", documentId: "d2", repository: nil, recordGroup: "59",
                   lotFile: "64 D 199", seriesName: "Conference Files", rawText: "raw b"),
            Record(volumeId: "v2", documentId: "d3", repository: "Truman Library",
                   recordGroup: nil, lotFile: nil, seriesName: nil, rawText: "raw c"),
        ]
        fixture.links = ["59|64 D 199": CollectionGeneratedBlocks.ArchivalLink(
            title: "Conference Files, 1949–1963",
            urlString: "https://catalog.archives.gov/id/123")]
        let documents: [(volumeId: String, documentId: String)] =
            [("v1", "d1"), ("v1", "d2"), ("v2", "d3"), ("v2", "d4")]  // d4 has no source row

        let block = await CollectionGeneratedBlocks.resolve(
            type: .archivalSources, documents: documents, dataSource: fixture)
        // Two groups sorted by label; members follow at indent 1 in collection order,
        // volume-qualified because the membership spans two volumes.
        #expect(block.rows.map(\.text) == [
            "Conference Files, Lot 64 D 199, RG 59",
            "Document 1 (v1)", "Document 2 (v1)",
            "Truman Library",
            "Document 3 (v2)",
        ])
        #expect(block.rows[0].secondaryText == "Conference Files, 1949–1963")
        #expect(block.rows[0].url == "https://catalog.archives.gov/id/123")
        #expect(block.rows.map(\.indentLevel) == [0, 1, 1, 0, 1])
        #expect(block.rows[3].secondaryText == nil)   // repository-only: no NARA match
        #expect(block.rows[3].url == nil)
    }

    /// `document_sources.record_group` stores two forms, and the fixture above uses the rarer
    /// one. Where a citation *names* its record group the parser captures a bare `"59"`; where
    /// it names none — a decimal file number does not — the parser **infers** one and writes
    /// the literal `"RG-59"`. Measured on the owner's index, the prefixed form is 93% of the
    /// corpus's export groups, so this is the shape the block almost always renders.
    ///
    /// Interpolating it after the label's literal `"RG "` printed **"RG RG-59"**. Source
    /// Explorer hit the identical bug and patched it (`SourceExplorerView.swift:466`); this
    /// surface never got the fix.
    @Test("Archival Sources block: the parser's RG- prefix is not doubled in the row label")
    @MainActor
    func generatedArchivalSourcesRecordGroupPrefix() async {
        typealias Record = CollectionGeneratedBlocks.SourceRecord
        var fixture = FixtureBlockDataSource()
        fixture.sources = [
            // The inferred form, as a lot-less decimal citation stores it.
            Record(volumeId: "v1", documentId: "d1", repository: "Department of State",
                   recordGroup: "RG-59", lotFile: nil,
                   seriesName: "740.00119 (Potsdam)/5-2446", rawText: "raw a"),
            // The captured form, for the same record group — both must render identically.
            Record(volumeId: "v1", documentId: "d2", repository: "Department of State",
                   recordGroup: "59", lotFile: nil,
                   seriesName: "740.00119 (Potsdam)/5-2446", rawText: "raw b"),
            // RG-256 exercises a second group number, so the fix cannot be a "59" special case.
            Record(volumeId: "v1", documentId: "d3", repository: nil,
                   recordGroup: "RG-256", lotFile: nil, seriesName: "Paris Peace Conf. 180.03101",
                   rawText: "raw c"),
        ]
        let documents: [(volumeId: String, documentId: String)] =
            [("v1", "d1"), ("v1", "d2"), ("v1", "d3")]
        let block = await CollectionGeneratedBlocks.resolve(
            type: .archivalSources, documents: documents, dataSource: fixture)

        let labels = block.rows.filter { $0.indentLevel == 0 }.map(\.text)
        #expect(!labels.contains { $0.contains("RG RG-") },
                "the doubled prefix is back: \(labels)")
        #expect(labels.contains("740.00119 (Potsdam)/5-2446, RG 59, Department of State"))
        #expect(labels.contains("Paris Peace Conf. 180.03101, RG 256"))
        // The two spellings of RG 59 still group separately — `groupKey` keys on the stored
        // value, which this change deliberately does not touch — but they now READ the same.
        #expect(labels.filter { $0.hasPrefix("740.00119") }.count == 2)
        #expect(Set(labels.filter { $0.hasPrefix("740.00119") }).count == 1,
                "both spellings must render to one identical label")
        // And no row carries a record-group catalog link any more (N-5 follow-up, decision C).
        #expect(block.rows.allSatisfy { $0.url == nil },
                "a document citation must not link to its whole record group")
    }

    @Test("Persons Index block: reuses the rollup identities, applies the >=2-of->=4 threshold (>=1 for small collections), alphabetical with document-number reference lists")
    @MainActor
    func generatedPersonsIndexThreshold() async {
        typealias Mention = CollectionGeneratedBlocks.PersonMention
        var fixture = FixtureBlockDataSource()
        fixture.mentions = [
            Mention(identityKey: "r1", name: "Alice", description: "Secretary of State",
                    role: nil, volumeId: "v1", documentId: "d1"),
            Mention(identityKey: "r1", name: "Alice", description: "Secretary of State",
                    role: nil, volumeId: "v1", documentId: "d2"),
            Mention(identityKey: "r1", name: "Alice", description: "Secretary of State",
                    role: nil, volumeId: "v1", documentId: "d3"),
            Mention(identityKey: "r2", name: "Bob", description: nil,
                    role: "diplomat", volumeId: "v1", documentId: "d2"),
            Mention(identityKey: "r2", name: "Bob", description: nil,
                    role: "diplomat", volumeId: "v1", documentId: "d4"),
            Mention(identityKey: "r3", name: "Carol", description: nil,
                    role: nil, volumeId: "v1", documentId: "d3"),
        ]
        let four: [(volumeId: String, documentId: String)] =
            [("v1", "d1"), ("v1", "d2"), ("v1", "d3"), ("v1", "d4")]

        // ≥ 4 documents → threshold 2: Carol (one mention) is filtered out.
        let block = await CollectionGeneratedBlocks.resolve(
            type: .personsIndex, documents: four, dataSource: fixture)
        #expect(block.rows.map(\.text) == ["Alice", "Bob"])
        #expect(block.rows[0].secondaryText == "Secretary of State — Documents 1, 2, 3")
        #expect(block.rows[1].secondaryText == "diplomat — Documents 2, 4")

        // 3 documents → threshold 1: every mentioned identity appears; Bob's list is
        // restricted to the membership and a single reference reads "Document N".
        let three = Array(four.prefix(3))
        let small = await CollectionGeneratedBlocks.resolve(
            type: .personsIndex, documents: three, dataSource: fixture)
        #expect(small.rows.map(\.text) == ["Alice", "Bob", "Carol"])
        #expect(small.rows[1].secondaryText == "diplomat — Document 2")
    }

    @Test("Thematic Index block: notes+assignments tag union intersected with the membership, alphabetical, tags reaching no collection document are skipped")
    @MainActor
    func generatedThematicIndexBlock() async {
        typealias Tag = CollectionGeneratedBlocks.TagRecord
        var fixture = FixtureBlockDataSource()
        fixture.tags = [
            Tag(name: "Zebra", documents: [("v1", "d1")]),
            Tag(name: "Trade", documents: [("v1", "d2"), ("v1", "d1"), ("v9", "d9")]),
            Tag(name: "Unused", documents: [("v9", "d9")]),   // no overlap → skipped
        ]
        let documents: [(volumeId: String, documentId: String)] = [("v1", "d1"), ("v1", "d2")]
        let block = await CollectionGeneratedBlocks.resolve(
            type: .thematicIndex, documents: documents, dataSource: fixture)
        // Alphabetical tags; members at indent 1 in collection order (d1 before d2 even
        // though the tag's own reach lists d2 first); single volume → bare numbers.
        #expect(block.rows.map(\.text) ==
                ["Trade", "Document 1", "Document 2", "Zebra", "Document 1"])
        #expect(block.rows.map(\.indentLevel) == [0, 1, 1, 0, 1])
    }

    @Test("Empty blocks: every type degrades to the single localized nothing-to-list row — never an empty section")
    @MainActor
    func generatedBlockEmptyStates() async {
        let fixture = FixtureBlockDataSource()
        // Empty membership: all five types.
        for type in CollectionGeneratedBlockType.allCases {
            let block = await CollectionGeneratedBlocks.resolve(
                type: type, documents: [], dataSource: fixture)
            #expect(block.rows.count == 1)
            #expect(block.rows[0].text == CollectionGeneratedBlocks.emptyRowText)
            #expect(block.rows[0].indentLevel == 0 && block.rows[0].url == nil)
        }
        // Non-empty membership but no backing data: the data-driven blocks (sources,
        // persons, tags) still fall back to the same row.
        let documents: [(volumeId: String, documentId: String)] = [("v1", "d1")]
        for type in [CollectionGeneratedBlockType.archivalSources, .personsIndex, .thematicIndex] {
            let block = await CollectionGeneratedBlocks.resolve(
                type: type, documents: documents, dataSource: fixture)
            #expect(block.rows.map(\.text) == [CollectionGeneratedBlocks.emptyRowText])
        }
    }

    @Test("Persons Index determinism: distinct identities sharing a canonical name keep a stable order — identity key breaks the tie, launch after launch")
    @MainActor
    func generatedPersonsIndexTieBreak() async {
        typealias Mention = CollectionGeneratedBlocks.PersonMention
        var fixture = FixtureBlockDataSource()
        // Two DISTINCT rollups with the same canonical name — routine at FRUS scale —
        // plus a differently named identity proving names still sort first.
        fixture.mentions = [
            Mention(identityKey: "r9", name: "John Smith", description: "the ambassador",
                    role: nil, volumeId: "v1", documentId: "d1"),
            Mention(identityKey: "r2", name: "John Smith", description: "the admiral",
                    role: nil, volumeId: "v1", documentId: "d2"),
            Mention(identityKey: "r5", name: "Alice", description: nil,
                    role: nil, volumeId: "v1", documentId: "d1"),
        ]
        let documents: [(volumeId: String, documentId: String)] = [("v1", "d1"), ("v1", "d2")]
        // Dictionary iteration order is seeded per launch and `sorted(by:)` is not
        // stable, so equal-named rows would swap between runs without the key
        // tie-break. Resolve repeatedly — the order must be identical every time:
        // name first, then identityKey ("r2" < "r9").
        for _ in 0..<8 {
            let block = await CollectionGeneratedBlocks.resolve(
                type: .personsIndex, documents: documents, dataSource: fixture)
            #expect(block.rows.map(\.text) == ["Alice", "John Smith", "John Smith"])
            #expect(block.rows[1].secondaryText?.hasPrefix("the admiral") == true)
            #expect(block.rows[2].secondaryText?.hasPrefix("the ambassador") == true)
        }
    }

    @Test("NativeFormat generated blocks: any block forces v2; only the TYPE serializes (never rows); round-trip reconstructs; an unknown block-type string imports inert and re-exports intact")
    @MainActor
    func nativeGeneratedBlockRoundTrip() throws {
        let container = try ModelContainer.makeTestContainer()
        let sourceCtx = ModelContext(container)

        let coll = Collection(name: "Indexed")
        sourceCtx.insert(coll)
        let entry = CollectionEntry(collectionId: coll.id, documentId: "", volumeId: "", sortOrder: 0)
        entry.entryKind = .generated
        entry.generatedBlockType = CollectionGeneratedBlockType.personsIndex.rawValue
        entry.collection = coll
        sourceCtx.insert(entry)
        try sourceCtx.save()

        func makeFile() -> FRUSCollectionFile {
            NativeCollectionSerializer.makeFile(
                from: coll, includeNotes: false, resolveNoteTexts: { _ in [] })
        }

        // Write-minimum can't apply once a generated entry exists: the file is v2, so
        // a v1-only reader never sees the kind; the floor stays 1 (degradable).
        let file = makeFile()
        #expect(file.formatVersion == 2)
        #expect(file.minimumReaderVersion == 1)
        let fileEntry = try #require(file.entries.first)
        #expect(fileEntry.kind == "generated")
        #expect(fileEntry.generatedBlockType == "personsIndex")

        // Only the TYPE serializes — no rows key exists in the schema, and the encoded
        // JSON carries nothing but kind + generatedBlockType for this entry.
        let json = String(decoding: try NativeCollectionSerializer.encode(file), as: UTF8.self)
        #expect(!json.contains("\"rows\""))

        // Round-trip onto a fresh store reconstructs the generated entry.
        let destContainer = try ModelContainer.makeTestContainer()
        let destCtx = ModelContext(destContainer)
        let imported = NativeCollectionSerializer.apply(
            try NativeCollectionSerializer.decode(Data(json.utf8)), into: destCtx)
        try destCtx.save()
        let importedEntry = try #require((imported.documentEntries ?? []).first)
        #expect(importedEntry.entryKind == .generated)
        #expect(importedEntry.generatedBlockType == "personsIndex")

        // Deleting the block restores the v1 write-minimum (nothing else v2 here).
        sourceCtx.delete(entry)
        try sourceCtx.save()
        #expect(makeFile().formatVersion == 1)

        // Tolerant reader: an unknown generatedBlockType STRING (a future writer's
        // vocabulary) imports as an INERT generated entry — placement preserved,
        // skipped at resolve (see resolverGeneratedBlockResolution) — never dropped
        // and never misread; an unknown entry KIND is still skipped (Phase 1 rule).
        let futureJSON = Data(#"{"format":"fruscollection","formatVersion":2,"minimumReaderVersion":1,"name":"F","composition":{"defaultBodyDepth":"full","footnoteStyle":"all","tocStyle":"citation","applyHighlights":false,"includeNotes":true,"includeWordCloud":false},"entries":[{"kind":"hologram","text":"x"},{"kind":"generated","generatedBlockType":"starCharts"},{"kind":"generated","generatedBlockType":"bibliography"}]}"#.utf8)
        let futureImport = NativeCollectionSerializer.apply(
            try NativeCollectionSerializer.decode(futureJSON), into: destCtx)
        try destCtx.save()
        let futureEntries = (futureImport.documentEntries ?? []).sorted { $0.sortOrder < $1.sortOrder }
        try #require(futureEntries.count == 2)             // hologram skipped, both blocks kept
        #expect(futureEntries[0].entryKind == .generated)
        #expect(futureEntries[0].generatedBlockType == "starCharts")   // raw string preserved
        #expect(futureEntries[1].generatedBlockType == "bibliography")

        // Re-exporting the imported collection keeps the unknown block intact — the
        // inert entry round-trips rather than silently vanishing from shared files.
        let reExport = NativeCollectionSerializer.makeFile(
            from: futureImport, includeNotes: false, resolveNoteTexts: { _ in [] })
        #expect(reExport.formatVersion == 2)
        #expect(reExport.entries.map(\.generatedBlockType) == ["starCharts", "bibliography"])
    }

    @Test("Move engine: generated entries move as single rows (like prose) and travel inside their section's block")
    func generatedMovesLikeProse() {
        // Model-backed: [H A, generated, doc, H B, doc] — dragging H A to the end takes
        // its generated block and document along as one block.
        let hA = outlineEntry(kind: .heading, level: 1, order: 0, text: "A")
        let gen = outlineEntry(kind: .generated, order: 1, text: nil)
        gen.generatedBlockType = CollectionGeneratedBlockType.thematicIndex.rawValue
        let d1 = outlineEntry(kind: .document, order: 2)
        let hB = outlineEntry(kind: .heading, level: 1, order: 3, text: "B")
        let d2 = outlineEntry(kind: .document, order: 4)
        let entries = [hA, gen, d1, hB, d2]

        let sectionMove = CollectionOutline.applyingMove(entries, fromIndex: 0, toOffset: 5)
        #expect(sectionMove?.map(\.generatedBlockType) == [nil, nil, nil, "thematicIndex", nil])
        #expect(sectionMove?.map(\.text) == [Optional("B"), nil, Optional("A"), nil, nil])

        // The generated entry itself moves as a single row (non-heading), dropped at
        // the very end, past H B's document.
        let rowMove = CollectionOutline.applyingMove(entries, fromIndex: 1, toOffset: 5)
        #expect(rowMove?.map(\.generatedBlockType) == [nil, nil, nil, nil, "thematicIndex"])
        // Self-drop is a no-op, exactly like prose/document rows.
        #expect(CollectionOutline.applyingMove(entries, fromIndex: 1, toOffset: 2) == nil)

        // The editors' post-move tail applies unchanged: reindex leaves 0..n.
        for (i, e) in (rowMove ?? []).enumerated() { e.sortOrder = i }
        #expect(rowMove?.map(\.sortOrder) == [0, 1, 2, 3, 4])
    }

    @Test("Smart path resolves generated blocks: front matter before the smart items, back matter after; fullRefs keeps block membership at the FULL result set under a preview cap; unknown types skipped")
    @MainActor
    func smartPathResolvesGeneratedBlocks() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        let appState = AppState()

        let coll = Collection(name: "Smart Apparatus")
        coll.savedSearchId = UUID()   // smart; resolveSmartItems itself is search-free
        context.insert(coll)
        let chron = CollectionEntry(collectionId: coll.id, documentId: "", volumeId: "", sortOrder: 0)
        chron.entryKind = .generated
        chron.generatedBlockType = CollectionGeneratedBlockType.chronology.rawValue
        let bib = CollectionEntry(collectionId: coll.id, documentId: "", volumeId: "", sortOrder: 1)
        bib.entryKind = .generated
        bib.generatedBlockType = CollectionGeneratedBlockType.bibliography.rawValue
        // A newer build's block type: skipped on the smart path too, never junk.
        let future = CollectionEntry(collectionId: coll.id, documentId: "", volumeId: "", sortOrder: 2)
        future.entryKind = .generated
        future.generatedBlockType = "starCharts"
        for entry in [chron, bib, future] {
            entry.collection = coll
            context.insert(entry)
        }
        try context.save()

        let resolver = CollectionContentResolver(appState: appState, modelContext: context)
        typealias Ref = CollectionContentResolver.SmartDocumentRef
        let refs = [Ref(documentId: "d1", volumeId: "smartvol", sortOrder: 0),
                    Ref(documentId: "d2", volumeId: "smartvol", sortOrder: 1)]

        // Full resolve: chronology (front matter) frames the smart documents with the
        // bibliography (back matter) — the smart-collection Apparatus wiring the
        // editors' ungated menu and the manuals promise.
        let items = await resolver.resolveSmartItems(refs, collection: coll, allNotes: [])
        #expect(items.map(kindLabel) == ["generated", "document", "document", "generated"])
        guard case .generated(let front) = items[0],
              case .generated(let back) = items[3] else {
            Issue.record("expected generated items framing the smart documents")
            return
        }
        #expect(front.type == .chronology)
        #expect(back.type == .bibliography)
        // Block membership is the smart result set (fallback citations — no manifest
        // volume metadata in tests).
        #expect(back.rows.map(\.text) == ["smartvol/d1", "smartvol/d2"])

        // Capped preview: per-document resolution sees only the first ref, but blocks
        // (fed fullRefs) still reflect the FULL result set — matching the export.
        let capped = await resolver.resolveSmartItems(
            Array(refs.prefix(1)), collection: coll, allNotes: [], fullRefs: refs)
        #expect(capped.map(kindLabel) == ["generated", "document", "generated"])
        if case .generated(let cappedBack) = capped[2] {
            #expect(cappedBack.rows.map(\.text) == ["smartvol/d1", "smartvol/d2"])
        } else {
            Issue.record("expected the back-matter bibliography in the capped resolve")
        }
    }

    @Test("Preview cap: generated entries survive the cap wherever they sit — documents and headings past the cap stay excluded")
    @MainActor
    func previewCapKeepsGeneratedEntries() {
        var entries: [CollectionEntry] = []
        let chron = outlineEntry(kind: .generated, order: 0)
        chron.generatedBlockType = CollectionGeneratedBlockType.chronology.rawValue
        entries.append(chron)
        for i in 1...25 { entries.append(outlineEntry(kind: .document, order: i)) }
        entries.append(outlineEntry(kind: .heading, level: 1, order: 26, text: "Past the cap"))
        let bib = outlineEntry(kind: .generated, order: 27)
        bib.generatedBlockType = CollectionGeneratedBlockType.bibliography.rawValue
        entries.append(bib)

        let capped = CollectionPreviewView.capEntries(entries, cap: 20)
        // Front-matter block + first 20 documents + the trailing back-matter block —
        // where addGeneratedEntry default-inserts it. The 5 documents and the heading
        // past the cap are excluded, exactly as before.
        #expect(capped.count == 22)
        #expect(capped.first?.entryKind == .generated)
        #expect(capped.filter { $0.entryKind == .document }.count == 20)
        #expect(!capped.contains { $0.entryKind == .heading })
        #expect(capped.last?.entryKind == .generated)
        #expect(capped.last?.generatedBlockType
                == CollectionGeneratedBlockType.bibliography.rawValue)
    }

    @Test("DOCX generated rows: the citation formatter's _…_ series-title markers render as italic runs — never literal underscores (hyperlink and secondary runs included)")
    @MainActor
    func docxGeneratedRowItalics() async throws {
        let block = CollectionGeneratedBlock(
            type: .bibliography,
            title: "Bibliography",
            rows: [
                CollectionGeneratedRow(
                    text: "_Foreign Relations of the United States_, 1969–1976, Volume I, Document 5"),
                CollectionGeneratedRow(
                    text: "Linked Collection",
                    secondaryText: "See _Foreign Relations_ series",
                    url: "https://catalog.archives.gov/id/1"),
            ])
        let url = try await DocxCollectionExporter().export(
            metadata: CollectionExportMetadata(name: "Italics", note: nil),
            items: [.generated(block)])
        let docx = try Data(contentsOf: url)
        func docxContains(_ s: String) -> Bool { docx.range(of: Data(s.utf8)) != nil }
        // The marked span became a real italic run…
        #expect(docxContains(
            "<w:rPr><w:i/></w:rPr><w:t xml:space=\"preserve\">Foreign Relations of the United States</w:t>"))
        // …the hyperlink row keeps the Hyperlink rStyle on its runs…
        #expect(docxContains(
            "<w:rStyle w:val=\"Hyperlink\"/></w:rPr><w:t xml:space=\"preserve\">Linked Collection</w:t>"))
        // …the secondary text's marked span is italic alongside its gray/small rPr…
        #expect(docxContains(
            "<w:i/></w:rPr><w:t xml:space=\"preserve\">Foreign Relations</w:t>"))
        // …and no literal underscore-wrapped series title survives anywhere.
        #expect(!docxContains("_Foreign Relations"))
    }

    @Test("PDF generated rows: a single row taller than a full page continues onto following pages instead of being clipped below the media box")
    @MainActor
    func pdfGeneratedRowContinuation() async throws {
        // A persons-index-shaped row whose volume-qualified reference list far
        // exceeds one page at the row's 9-pt secondary size.
        let refList = (1...2000).map { "\($0) (frus1969-76v\($0 % 10))" }
            .joined(separator: ", ")
        let block = CollectionGeneratedBlock(
            type: .personsIndex,
            title: "Persons Index",
            rows: [CollectionGeneratedRow(text: "Smith, John",
                                          secondaryText: "Documents " + refList + ", ZZZTAIL")])
        let url = try await PDFCollectionExporter().export(
            metadata: CollectionExportMetadata(name: "Overflow", note: nil),
            items: [.generated(block)])
        let pdf = try Data(contentsOf: url)
        let document = try #require(PDFDocument(data: pdf))
        let text = (0..<document.pageCount)
            .compactMap { document.page(at: $0)?.string }
            .joined(separator: "\n")
        #expect(text.contains("Smith, John"))
        // The tail of the overtall row made it onto a page (pre-fix it was drawn into
        // a rect extending below the media box and clipped away by viewers).
        #expect(text.contains("ZZZTAIL"))
        // And the continuation actually spanned pages: cover + several flow pages.
        #expect(document.pageCount >= 3)
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

    // MARK: - M3 title override (D4)

    @Test("M3 exportHeading/tocLabel: a non-empty titleOverride wins for the heading and for BOTH ToC styles; unset falls back to citation-else-title exactly as before")
    func m3ExportHeadingAndToC() {
        // With an override: the heading and both ToC styles all read the override,
        // regardless of citation/header/dateline.
        let overridden = CollectionExportDocument(
            documentId: "d1", volumeId: "v1", sortOrder: 0,
            title: "Vol I — d1", titleOverride: "Kennan's Long Telegram",
            bodyText: "", citation: "Telegram 511, Feb 22, 1946",
            header: "861.00/2-2246: Telegram", dateline: "Moscow, February 22, 1946")
        #expect(overridden.exportHeading == "Kennan's Long Telegram")
        #expect(overridden.tocLabel(style: .citation) == "Kennan's Long Telegram")
        #expect(overridden.tocLabel(style: .headerAndDateline) == "Kennan's Long Telegram")

        // Empty override string is treated as unset (write-on-clear → nil, but a stray "" degrades safely).
        let empty = CollectionExportDocument(
            documentId: "d1", volumeId: "v1", sortOrder: 0,
            title: "Vol I — d1", titleOverride: "", bodyText: "",
            citation: "Telegram 511")
        #expect(empty.exportHeading == "Telegram 511")
        #expect(empty.tocLabel(style: .citation) == "Telegram 511")

        // No override: byte-for-byte the pre-M3 derivation (citation, else title).
        let plain = CollectionExportDocument(
            documentId: "d1", volumeId: "v1", sortOrder: 0,
            title: "Vol I — d1", bodyText: "", citation: "Telegram 511",
            header: "The Header", dateline: "Moscow")
        #expect(plain.exportHeading == "Telegram 511")
        #expect(plain.tocLabel(style: .citation) == "Telegram 511")
        #expect(plain.tocLabel(style: .headerAndDateline) == "The Header — Moscow")
        // No citation, no override: title is the ultimate fallback.
        let bare = CollectionExportDocument(
            documentId: "d1", volumeId: "v1", sortOrder: 0,
            title: "Vol I — d1", bodyText: "")
        #expect(bare.exportHeading == "Vol I — d1")
        #expect(bare.tocLabel(style: .citation) == "Vol I — d1")
    }

    @Test("M3 renderers: an entry's titleOverride shows in the HTML document heading AND its ToC entry; the DOCX heading carries it too; an unset override renders byte-identically to today")
    func m3RenderersShowOverride() async throws {
        let overridden = CollectionExportDocument(
            documentId: "d1", volumeId: "v1", sortOrder: 0,
            title: "Vol I — d1", titleOverride: "Kennan Long Telegram",
            bodyText: "Body.", citation: "Boring Citation 511")
        let items: [CollectionExportItem] = [.document(overridden)]
        let metadata = CollectionExportMetadata(name: "M3", note: nil)

        // HTML: both the ToC entry and the <h2> document heading carry the override,
        // and the boring citation never appears as a heading.
        let html = CollectionItemHTMLRenderer().pageHTML(metadata: metadata, items: items)
        #expect(html.contains("Kennan Long Telegram"))
        #expect(!html.contains("Boring Citation 511"))

        // DOCX: the stored-mode ZIP keeps document.xml uncompressed, so the heading text
        // appears verbatim in the archive bytes.
        let docxURL = try await DocxCollectionExporter().export(metadata: metadata, items: items)
        let docxData = try Data(contentsOf: docxURL)
        #expect(docxData.range(of: Data("Kennan Long Telegram".utf8)) != nil)

        // PDF: the export succeeds (glyphs are compressed; the exportHeading unit above
        // pins the value the PDF draws).
        let pdfURL = try await PDFCollectionExporter().export(metadata: metadata, items: items)
        #expect(try Data(contentsOf: pdfURL).prefix(4) == Data([0x25, 0x50, 0x44, 0x46]))

        // Unset override → byte-identical to the pre-M3 render (the citation heading).
        let plain = CollectionExportDocument(
            documentId: "d1", volumeId: "v1", sortOrder: 0,
            title: "Vol I — d1", bodyText: "Body.", citation: "Boring Citation 511")
        let plainHTML = CollectionItemHTMLRenderer()
            .pageHTML(metadata: metadata, items: [.document(plain)])
        #expect(plainHTML.contains("Boring Citation 511"))
        #expect(!plainHTML.contains("Kennan Long Telegram"))

        // M3 finding 2: the un-downloaded-volume *preview card* also honors the override —
        // an author who sets a title and previews a not-yet-downloaded document sees the
        // override in the card, matching the exported heading. With no override the card
        // still shows the citation (byte-identical to the pre-finding-2 behavior).
        var previewRenderer = CollectionItemHTMLRenderer()
        previewRenderer.citationOnlyVolumeIds = ["v1"]
        let cardHTML = previewRenderer.pageHTML(metadata: metadata, items: items)
        #expect(cardHTML.contains("Kennan Long Telegram"))
        #expect(!cardHTML.contains("Boring Citation 511"))
        let plainCardHTML = previewRenderer.pageHTML(metadata: metadata, items: [.document(plain)])
        #expect(plainCardHTML.contains("Boring Citation 511"))
    }

    @Test("M3 serialization: a non-empty titleOverride forces v2 and round-trips (export→import); an empty/absent override stays formatVersion 1 byte-identical to pre-M3; a v1 file with no key imports as nil (derived title)")
    func m3SerializationRoundTrip() throws {
        let container = try ModelContainer.makeTestContainer()
        let ctx = ModelContext(container)
        let coll = Collection(name: "Titled")
        ctx.insert(coll)
        let d = CollectionEntry(collectionId: coll.id, documentId: "d1", volumeId: "v1", sortOrder: 0)
        d.collection = coll
        ctx.insert(d)
        try ctx.save()

        func makeFile() -> FRUSCollectionFile {
            NativeCollectionSerializer.makeFile(
                from: coll, includeNotes: false, resolveNoteTexts: { _ in [] })
        }

        // Untouched: write-minimum v1, and the key is absent from the bytes.
        #expect(makeFile().formatVersion == 1)
        let v1Data = try NativeCollectionSerializer.encode(makeFile())
        #expect(!String(decoding: v1Data, as: UTF8.self).contains("titleOverride"))

        // An empty override is treated as unset — still v1, byte-identical to the above.
        d.titleOverride = ""
        #expect(makeFile().formatVersion == 1)
        #expect(try NativeCollectionSerializer.encode(makeFile()) == v1Data)

        // A non-empty override forces v2, floor stays 1, and the key carries the text.
        d.titleOverride = "Kennan Long Telegram"
        let file = makeFile()
        #expect(file.formatVersion == 2)
        #expect(file.minimumReaderVersion == 1)
        #expect(file.entries.first?.titleOverride == "Kennan Long Telegram")

        // encode → decode → apply reconstructs the override (it IS portable content).
        let data = try NativeCollectionSerializer.encode(file)
        let destCtx = ModelContext(try ModelContainer.makeTestContainer())
        let imported = NativeCollectionSerializer.apply(
            try NativeCollectionSerializer.decode(data), into: destCtx)
        try destCtx.save()
        let importedEntry = try #require((imported.documentEntries ?? []).first)
        #expect(importedEntry.titleOverride == "Kennan Long Telegram")

        // Forward/backward compat: a pre-M3 v1 file with no titleOverride key imports as
        // nil → the derived title, never corrupts.
        let v1JSON = Data(#"{"format":"fruscollection","formatVersion":1,"name":"Old","composition":{"defaultBodyDepth":"full","footnoteStyle":"all","tocStyle":"citation","applyHighlights":false,"includeNotes":true,"includeWordCloud":false},"entries":[{"kind":"document","documentId":"d1","volumeId":"v1"}]}"#.utf8)
        let old = NativeCollectionSerializer.apply(
            try NativeCollectionSerializer.decode(v1JSON), into: destCtx)
        #expect((old.documentEntries ?? []).first?.titleOverride == nil)
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

// MARK: - Generated-block fixture data source (Phase 6)

/// Hermetic `CollectionGeneratedBlockDataSource`: canned answers keyed by
/// `"volumeId/documentId"`, no SQLite, no SwiftData, no bundle resources — so the
/// per-block resolution logic (dedupe, ordering, grouping, thresholds, enrichment)
/// is tested in isolation from the live stores.
@MainActor
private struct FixtureBlockDataSource: CollectionGeneratedBlockDataSource {
    /// Citation per document key; unlisted keys fall back to the key itself.
    var citations: [String: String] = [:]
    /// Date metadata per document key; unlisted keys are "undated".
    var dates: [String: DocumentDateMetadata] = [:]
    /// The corpus of `document_sources` rows (filtered to the requested documents).
    var sources: [CollectionGeneratedBlocks.SourceRecord] = []
    /// NARA resolutions keyed `"recordGroup|lotFile"` (empty string for nil).
    var links: [String: CollectionGeneratedBlocks.ArchivalLink] = [:]
    /// The corpus of rollup mentions (filtered to the requested documents).
    var mentions: [CollectionGeneratedBlocks.PersonMention] = []
    /// Every user tag with its full document reach.
    var tags: [CollectionGeneratedBlocks.TagRecord] = []

    func citation(volumeId: String, documentId: String) -> String {
        citations["\(volumeId)/\(documentId)"] ?? "\(volumeId)/\(documentId)"
    }

    func dateMetadata(
        for documents: [(volumeId: String, documentId: String)]
    ) async -> [String: DocumentDateMetadata] {
        let keys = Set(documents.map { "\($0.volumeId)/\($0.documentId)" })
        return dates.filter { keys.contains($0.key) }
    }

    func documentSources(
        for documents: [(volumeId: String, documentId: String)]
    ) async -> [CollectionGeneratedBlocks.SourceRecord] {
        let keys = Set(documents.map { "\($0.volumeId)/\($0.documentId)" })
        return sources.filter { keys.contains("\($0.volumeId)/\($0.documentId)") }
    }

    func archivalResolution(recordGroup: String?, lotFile: String?)
        -> CollectionGeneratedBlocks.ArchivalLink? {
        links["\(recordGroup ?? "")|\(lotFile ?? "")"]
    }

    func personMentions(
        for documents: [(volumeId: String, documentId: String)]
    ) async -> [CollectionGeneratedBlocks.PersonMention] {
        let keys = Set(documents.map { "\($0.volumeId)/\($0.documentId)" })
        return mentions.filter { keys.contains("\($0.volumeId)/\($0.documentId)") }
    }

    func tagRecords() async -> [CollectionGeneratedBlocks.TagRecord] { tags }
}

// MARK: - Export Parity (#960)

/// The three exporters against ONE fixture, pinned to the same block inventory.
///
/// ## Why this suite exists
/// The in-app preview **is** the HTML renderer (`CollectionPreviewView` assembles with
/// `CollectionItemHTMLRenderer.pageHTML`), so HTML matches the preview by construction —
/// and PDF and DOCX are independent re-implementations with nothing pinning them to it.
/// #960 measured the drift on a real export: DOCX silently dropped the word cloud (the
/// option was never read) and shipped an unpopulated TOC field; the PDF wasted a blank
/// page; and all three doubled the `Source:` label on post-1969 notes, the preview
/// included. Every rule here is one of those measured defects, generalized.
@Suite("Collection export parity — #960")
@MainActor
struct CollectionExportParityTests {

    // ── The fixture: every block the composer can ask for, in every format. ──

    private static func fixtureDocuments() -> [CollectionExportDocument] {
        // Body long enough to paginate in PDF, ending in trailing newlines — the shape
        // that produced the blank page: an overflow opens a fresh page and a
        // whitespace-only remainder draws nothing on it.
        let longBody = Array(repeating: "The negotiations proceeded through the autumn, "
            + "and each session returned to the question of the islands. ", count: 260)
            .joined() + "\n\n\n"
        return [
            CollectionExportDocument(
                documentId: "d1", volumeId: "frus1952-54v03", sortOrder: 0,
                title: "Memorandum by the Director",
                bodyText: longBody,
                citation: "Foreign Relations of the United States, 1952\u{2013}1954, "
                    + "United Nations Affairs, Volume III, Document 931.",
                historyStateGovURL: "https://history.state.gov/historicaldocuments/frus1952-54v03/d931",
                header: "Memorandum by the Director",
                sourceNoteText: "ODA files, lot 62 D 225, \u{201C}Trust Territory\u{201D}"),
            CollectionExportDocument(
                documentId: "d2", volumeId: "frus1977-80v22", sortOrder: 1,
                title: "Telegram From the Embassy in Australia",
                bodyText: "The Embassy reported on regional reactions.",
                citation: "Foreign Relations of the United States, 1977\u{2013}1980, "
                    + "Volume XXII, Document 288.",
                historyStateGovURL: "https://history.state.gov/historicaldocuments/frus1977-80v22/d288",
                header: "Telegram From the Embassy in Australia",
                // The post-1969 shape: the stored note ALREADY leads with the label.
                sourceNoteText: "Source: Washington National Records Center, RG 330, "
                    + "OSD Files: FRC 330\u{2013}86\u{2013}0054. Confidential."),
        ]
    }

    private static var options: CollectionExportOptions {
        var o = CollectionExportOptions()
        o.includeSourceNote = true
        o.includeWordCloud = true
        return o
    }

    private static let metadata = CollectionExportMetadata(
        name: "Parity Fixture", note: "Two documents, every shared block.")

    // ── 1. The block inventory: what one format carries, all three carry. ──

    @Test("Citation, URL, body, and source note reach every format")
    func sharedBlocksReachEveryFormat() async throws {
        let docs = Self.fixtureDocuments()
        let html = try String(contentsOf: try await HTMLCollectionExporter().export(
            metadata: Self.metadata, documents: docs, options: Self.options), encoding: .utf8)
        let docxData = try Data(contentsOf: try await DocxCollectionExporter().export(
            metadata: Self.metadata, documents: docs, options: Self.options))
        let pdfText = try Self.pdfFullText(try await PDFCollectionExporter().export(
            metadata: Self.metadata, documents: docs, options: Self.options))

        let probes = ["Document 931", "Document 288",
                      "history.state.gov/historicaldocuments/frus1952-54v03/d931",
                      "regional reactions",
                      "ODA files, lot 62 D 225"]
        for probe in probes {
            #expect(html.contains(probe), "HTML lacks: \(probe)")
            #expect(docxData.range(of: Data(probe.utf8)) != nil, "DOCX lacks: \(probe)")
        }
        // PDF text extraction normalizes some punctuation; probe on stable substrings.
        for probe in ["Document 931", "Document 288", "regional reactions", "lot 62 D 225"] {
            #expect(pdfText.contains(probe), "PDF lacks: \(probe)")
        }
    }

    // ── 2. The word cloud: the option honoured by every format that was asked. ──

    @Test("includeWordCloud produces an image in every format")
    func wordCloudReachesEveryFormat() async throws {
        let docs = Self.fixtureDocuments()
        let html = try String(contentsOf: try await HTMLCollectionExporter().export(
            metadata: Self.metadata, documents: docs, options: Self.options), encoding: .utf8)
        #expect(html.contains("data:image/png;base64,"), "HTML cloud missing")

        let pdfData = try Data(contentsOf: try await PDFCollectionExporter().export(
            metadata: Self.metadata, documents: docs, options: Self.options))
        #expect(pdfData.range(of: Data("/Subtype /Image".utf8)) != nil
                || pdfData.range(of: Data("/Subtype/Image".utf8)) != nil,
                "PDF cloud missing")

        let docxURL = try await DocxCollectionExporter().export(
            metadata: Self.metadata, documents: docs, options: Self.options)
        let docx = try Data(contentsOf: docxURL)
        #expect(docx.range(of: Data("word/media/".utf8)) != nil, """
            The DOCX carries no image at all: `includeWordCloud` is silently ignored \
            (DocxCollectionExporter never reads the option — #960 item 1). The user ticked \
            a box and nothing says it did nothing.
            """)
    }

    // ── 3. The label rule: `Source:` appears once, in every format and the preview. ──

    @Test("A stored note already leading with Source: is not double-labelled")
    func sourceLabelIsNeverDoubled() async throws {
        let docs = Self.fixtureDocuments()
        let html = try String(contentsOf: try await HTMLCollectionExporter().export(
            metadata: Self.metadata, documents: docs, options: Self.options), encoding: .utf8)
        // The HTML label carries markup, so the doubled form is `Source:</strong> Source:` —
        // the exact shape that hid this from #960's first scan.
        #expect(!html.contains("Source:</strong> Source:"), """
            The preview double-labels post-1969 source notes (the stored note already \
            leads with `Source:` and the renderer prepends its own).
            """)
        let docxData = try Data(contentsOf: try await DocxCollectionExporter().export(
            metadata: Self.metadata, documents: docs, options: Self.options))
        #expect(docxData.range(of: Data("Source: Source:".utf8)) == nil, "DOCX double-labels")
        let pdfText = try Self.pdfFullText(try await PDFCollectionExporter().export(
            metadata: Self.metadata, documents: docs, options: Self.options))
        #expect(!pdfText.contains("Source: Source:"), "PDF double-labels")
    }

    // ── 4. PDF: no page may be blank. ──

    @Test("No PDF page is empty of both text and images")
    func noBlankPDFPages() async throws {
        let docs = Self.fixtureDocuments()
        let url = try await PDFCollectionExporter().export(
            metadata: Self.metadata, documents: docs, options: Self.options)
        let pdf = try #require(PDFDocument(url: url))
        #expect(pdf.pageCount >= 3, "the fixture should paginate; got \(pdf.pageCount) pages")
        for i in 0..<pdf.pageCount {
            let text = (pdf.page(at: i)?.string ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            // A page whose only text is its folio is the #960 blank page. The word-cloud
            // page is exempt: its content is an image (folio-only text is correct there),
            // and it is page 2 by construction.
            if i == 1 { continue }
            #expect(text.count > 4, """
                Page \(i + 1) is blank except its folio. The known mechanism: an overflow \
                opens a fresh page and a whitespace-only remainder draws nothing on it \
                (trailing newlines in the composed body).
                """)
        }
    }

    // ── 5. DOCX: the TOC field ships with populated cached content. ──

    @Test("The DOCX TOC shows the contents without requiring a refresh")
    func docxTOCIsPopulated() async throws {
        let docs = Self.fixtureDocuments()
        let docxData = try Data(contentsOf: try await DocxCollectionExporter().export(
            metadata: Self.metadata, documents: docs, options: Self.options))
        #expect(docxData.range(of: Data("Right-click to update".utf8)) == nil, """
            The TOC field's cached content is a placeholder sentence, so every viewer \
            that does not auto-refresh fields (Pages, Quick Look, Word before update) \
            shows an empty contents where the preview shows the citation list. The field \
            may stay (Word still refreshes page numbers); its cached content should be \
            the real entries.
            """)
        #expect(docxData.range(of: Data("Document 931".utf8)) != nil)
    }

    // ── 6. "See also:" — real citations joined once, in every format (#1392). ──

    /// The related-documents line joins citations with "; ", and every citation the formatter
    /// returns ends in a period, so until #1392 all three formats printed "…, Document 3.; …".
    /// The contract fixture passes one hand-written citation with no period and could not see
    /// it.
    ///
    /// This drives the REAL resolver instead of formatting citations in the test: the last
    /// document in a collection cross-references the two before it (one in its own volume, one
    /// in another), and `CollectionContentResolver` turns those edges into the "See also:"
    /// citations from the bundled manifest, exactly as an export does. `frus1952-54v01p1`'s
    /// editor list prints "William F. Sanford, Jr., and" — which is why the assertions name the
    /// join and never refuse ".," outright. The citing document comes LAST so that in the PDF,
    /// whose text cannot be cut at a paragraph, the line runs to the end of the text.
    @Test("See also joins real citations with one period, in HTML, DOCX and PDF (#1392)")
    func seeAlsoJoinsRealCitationsOnce() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("seealso-1392-\(UUID().uuidString)", isDirectory: true)
        let volumes = dir.appendingPathComponent("volumes", isDirectory: true)
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let dbURL = dir.appendingPathComponent("xref.sqlite")
        // The pipeline owns the schema and its migrations (`is_broken` among them).
        _ = try IndexingPipeline(fts5Store: try FTS5Store(databaseURL: dbURL), databaseURL: dbURL,
                                 volumesDirectory: volumes, concurrencyLimit: 1)
        try Self.insertCrossReferences(dbURL: dbURL, [
            (source: "d1", targetVolume: nil, target: "d3"),                  // same volume
            (source: "d1", targetVolume: "frus1952-54v02p1", target: "d7"),  // another volume
        ], sourceVolume: "frus1952-54v01p1")

        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        let appState = AppState()
        appState.crossReferenceStore = try CrossReferenceStore(databaseURL: dbURL)
        let collection = Collection(name: "See also")
        context.insert(collection)
        var entries: [CollectionEntry] = []
        for (order, (volume, document)) in [("frus1952-54v01p1", "d3"),
                                            ("frus1952-54v02p1", "d7"),
                                            ("frus1952-54v01p1", "d1")].enumerated() {
            let entry = CollectionEntry(collectionId: collection.id, documentId: document,
                                        volumeId: volume, sortOrder: order)
            entry.collection = collection
            context.insert(entry)
            entries.append(entry)
        }
        entries[2].includeRelatedDocuments = true
        try context.save()

        let items = try await CollectionContentResolver(appState: appState, modelContext: context)
            .resolve(collection: collection, entries: entries, allNotes: [], purpose: .preview)
        let citing = try #require(items.compactMap { item -> CollectionExportDocument? in
            if case .document(let doc) = item, doc.documentId == "d1" { return doc }
            return nil
        }.first)
        // The teeth: the related citations are the formatter's, each ending in its period. Were
        // they the `volumeId/documentId` fallback there would be nothing to double.
        let related = citing.relatedDocumentCitations
        try #require(related.count == 2, "expected two See-also citations, got \(related)")
        #expect(related[0].hasSuffix(", Document 3."), "got \(related[0])")
        #expect(related[1].hasSuffix(", Document 7."), "got \(related[1])")
        #expect(related.allSatisfy { $0.hasPrefix("_Foreign Relations of the United States_") })

        let html = try String(contentsOf: try await HTMLCollectionExporter().export(
            metadata: Self.metadata, items: items), encoding: .utf8)
        let docx = String(decoding: try Data(contentsOf: try await DocxCollectionExporter().export(
            metadata: Self.metadata, items: items)), as: UTF8.self)
        let pdf = try Self.pdfFullText(try await PDFCollectionExporter().export(
            metadata: Self.metadata, items: items))

        let htmlLine = try #require(Self.slice(html, from: "<p class=\"see-also\">", through: "</p>"),
                                    "the HTML has no See-also paragraph")
        // The DOCX line is one paragraph of runs; its text is what is left without the tags.
        let docxLine = try #require(Self.slice(docx, from: "See also:", through: "</w:p>"),
                                    "the DOCX has no See-also paragraph")
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        // PDF text breaks lines where the page does; a break is not a character of the line.
        let pdfLine = try #require(Self.slice(pdf, from: "See also:", through: nil),
                                   "the PDF has no See-also line")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        for (format, line) in [("HTML", htmlLine), ("DOCX", docxLine), ("PDF", pdfLine)] {
            #expect(line.contains("Document 3; "), "\(format): the first citation must end at \"; \": \(line)")
            #expect(!line.contains(".;"), "\(format): a citation's period doubled before \"; \": \(line)")
            #expect(line.contains("Document 7."), "\(format): the line must end in a period: \(line)")
            #expect(!line.contains("Document 7.."), "\(format): the closing period doubled: \(line)")
        }
    }

    /// Inserts `cross_references` rows straight into the database, bypassing the pipeline's TEI
    /// walk — the resolver reads the table, not how it was filled.
    private static func insertCrossReferences(
        dbURL: URL,
        _ edges: [(source: String, targetVolume: String?, target: String)],
        sourceVolume: String
    ) throws {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK,
              let handle = db else {
            sqlite3_close(db)
            throw CrossReferenceError.databaseOpenFailed(message: "insertCrossReferences")
        }
        defer { sqlite3_close_v2(handle) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for edge in edges {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(handle, """
                INSERT INTO cross_references
                (source_volume_id, source_document_id, target_volume_id, target_document_id,
                 reference_type, context)
                VALUES (?, ?, ?, ?, 'ref', NULL)
                """, -1, &stmt, nil) == SQLITE_OK else {
                throw CrossReferenceError.queryFailed(message: "prepare")
            }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, sourceVolume, -1, transient)
            sqlite3_bind_text(stmt, 2, edge.source, -1, transient)
            if let volume = edge.targetVolume {
                sqlite3_bind_text(stmt, 3, volume, -1, transient)
            } else {
                sqlite3_bind_null(stmt, 3)
            }
            sqlite3_bind_text(stmt, 4, edge.target, -1, transient)
            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw CrossReferenceError.queryFailed(message: "insert")
            }
        }
    }

    /// The text from `start` through the first `end` after it (inclusive), or through the end of
    /// `text` when `end` is nil; nil when either marker is missing.
    private static func slice(_ text: String, from start: String, through end: String?) -> String? {
        guard let lower = text.range(of: start) else { return nil }
        guard let end else { return String(text[lower.lowerBound...]) }
        guard let upper = text.range(of: end, range: lower.upperBound..<text.endIndex) else {
            return nil
        }
        return String(text[lower.lowerBound..<upper.upperBound])
    }

    // ── PDF text helper ──

    private static func pdfFullText(_ url: URL) throws -> String {
        let pdf = try #require(PDFDocument(url: url))
        return (0..<pdf.pageCount).compactMap { pdf.page(at: $0)?.string }.joined(separator: "\n")
    }
}


// MARK: - CollectionAttachmentTests

/// How a `CollectionEntry` is attached to its `Collection` — the relationship, not just the id.
///
/// ## The asymmetry these pin
/// Four attach paths existed and three assigned `entry.collection = collection` (the inverse),
/// letting SwiftData maintain `Collection.documentEntries` from it:
/// `CollectionExcerpts.append`, `CollectionExcerpts.appendToCollection`,
/// `CollectionDocumentDiscovery.appendEntries` and `CaptureStateSeeder.seed`. The fourth —
/// `CollectionPickerSheet.addDocument`, the document branch — instead did
/// `collection.documentEntries?.append(entry)`, which is a **total no-op** while that
/// relationship is `nil`: nothing is appended and the inverse is never set.
///
/// ## The measurements these encode
/// `documentEntries` is `nil` on a constructed collection and on an inserted-but-unsaved one, and
/// `Optional([])` from the first save onward. So the old picker line was correct for every saved
/// collection and silently wrong for one created moments earlier — which the picker's own
/// "New Collection" button does. `CollectionEditorView` saves on the first name keystroke
/// (`CollectionEditorCommit.name`, from the name field's own binding), so a named collection closes the window;
/// nothing guarantees it otherwise.
///
/// The orphan is permanent: a later save does not repair it, and `DuplicateRecordCleanup`
/// re-parents only entries that already carry a `collection`.
///
/// Version history:
///   1.0 — the picker's document branch moved onto the shared inverse-assigning factory
@Suite("Collection entry attachment")
struct CollectionAttachmentTests {

    /// The precondition the whole defect rests on. Stated as its own test so that if a future
    /// SwiftData release starts materialising the relationship as `[]` at insert, this fails
    /// **here** — naming the changed platform behaviour — rather than quietly turning the two
    /// tests below into tautologies that pass against a reverted fix.
    @Test("`documentEntries` is nil until the collection's first save, then []")
    @MainActor
    func relationshipIsNilBeforeFirstSave() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext

        let collection = Collection(name: "Backchannel")
        #expect(collection.documentEntries == nil, """
            A constructed collection's relationship is nil, not []. If this now holds [], the \
            optional-chained append is no longer a no-op and the two tests below no longer \
            distinguish the fix from the bug.
            """)

        context.insert(collection)
        #expect(collection.documentEntries == nil,
                "Inserting does not materialise the relationship — only saving does.")

        try context.save()
        #expect(collection.documentEntries?.isEmpty == true,
                "After the first save the relationship is Optional([]), so an append would work.")
    }

    /// The regression test. Drives the real emitter — `CollectionPickerSheet.addDocument` routes
    /// straight to this factory — against a collection whose `documentEntries` is nil, and asserts
    /// the entry is reachable **both** ways.
    ///
    /// This fails on the old code: the append no-ops, so `documentEntries` stays nil and
    /// `entry.collection` stays nil, while `collectionId` is set either way. Asserting only the id
    /// (or only one direction) would pass against the bug.
    @Test("Adding to an unsaved collection links the entry in both directions")
    @MainActor
    func appendToUnsavedCollectionLinksBothWays() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext

        // Exactly the state the picker's "New Collection" button leaves behind: inserted, never
        // saved, so the relationship is still nil.
        let collection = Collection(name: "Created moments ago")
        context.insert(collection)
        try #require(collection.documentEntries == nil)

        let entry = CollectionDocumentDiscovery.appendToCollection(
            documentId: "d12", volumeId: "frus1969-76v01",
            collection: collection, modelContext: context)

        // Direction 1 — the relationship-keyed readers (the editors, export, the document count,
        // `ResearchRailView.distinctCollections`, the picker's own duplicate guard).
        #expect(collection.documentEntries?.count == 1, """
            The entry is not reachable from the collection. This is the defect: \
            `collection.documentEntries?.append(entry)` against a nil relationship appends nothing.
            """)
        #expect(collection.documentEntries?.first?.documentId == "d12")

        // Direction 2 — the inverse, which is what `ResearchRailView.distinctCollections` reads
        // and drops the entry for when it is nil.
        #expect(entry.collection?.id == collection.id, """
            The inverse is unset, so the entry is an orphan carrying only `collectionId` — \
            counted by the id-keyed readers and invisible to every relationship-keyed one.
            """)

        // Direction 3 — the plain id, which was ALWAYS set. Pinned so a future reader can see
        // that this is the property that masked the defect, not evidence the attach worked.
        #expect(entry.collectionId == collection.id)

        // And it survives the save that the old code's orphan never recovered from.
        try context.save()
        let refetched = try #require(try ModelContext(container)
            .fetch(FetchDescriptor<Collection>()).first)
        #expect(refetched.documentEntries?.count == 1)
    }

    /// The saved-collection case, which the old code handled correctly — pinned so the fix is not
    /// mistaken for a behaviour change, and so a "fix" that double-linked would be caught.
    @Test("Adding to a saved collection appends exactly one entry, at max sortOrder + 1")
    @MainActor
    func appendToSavedCollectionDoesNotDuplicate() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext

        let collection = Collection(name: "Saved")
        context.insert(collection)
        try context.save()
        try #require(collection.documentEntries?.isEmpty == true)

        let first = CollectionDocumentDiscovery.appendToCollection(
            documentId: "d1", volumeId: "v1", collection: collection, modelContext: context)
        let second = CollectionDocumentDiscovery.appendToCollection(
            documentId: "d2", volumeId: "v1", collection: collection, modelContext: context)
        try context.save()

        // Assigning the inverse already adds to `documentEntries`; the relationship is idempotent,
        // so neither entry lands twice.
        #expect(collection.documentEntries?.count == 2)
        #expect(try ModelContext(container)
            .fetch(FetchDescriptor<CollectionEntry>()).count == 2)

        // End of the list, no renumbering — the `max + 1` contract this overload exists for.
        #expect(first.sortOrder == 0)
        #expect(second.sortOrder == 1)
    }
}

// MARK: - CollectionEditorNamingTests (#1359, #1413, #1415)

/// The collection editor's title reads the collection's name, and the editor's name field follows a rename made
/// somewhere else instead of writing the old name back over it (#1359). The editor also keeps what the reader types in
/// Collection settings however they leave it (#1415), and what a heading's Section defaults sheet writes is neither
/// hidden from the editor nor overwritten by its next edit (#1413).
///
/// ## Four layers
/// - **The rules** are called directly: `CollectionEditorNaming` (what the navigation bar says for a saved name, and
///   when the name field and the saved name agree) and `CollectionEditorCommit` (when an edit is written, and how).
/// - **The modifier**, `FrontMatterModelSync`, is HOSTED on its own: put in a real window over bindings into an
///   `@Observable` stand-in for the editor's `@State`, so a write to the model reaches it through SwiftUI's own
///   observation and `onChange`, the mechanism the editor relies on. That is where each follow and its whitespace
///   guard are pinned, because only the stand-in can set a field to a pasted value. It builds its OWN call to the
///   modifier, so it cannot see how the editor calls it.
/// - **The editor**, `CollectionEditorView` itself, is hosted too, with a real `AppState` and container, and watched
///   through the model and UIKit: a change made elsewhere reaches its fields and survives its next edit, following
///   one writes nothing back, and an edit typed on its covered Collection settings screen is written and saved as it
///   is typed. Those catch what the stand-in cannot — the editor passing the modifier a binding it cannot write, or
///   saving from an `onChange` (#1359 removed one for the name; #1415 removed the rest).
/// - **The wiring nothing hosted reaches** — the three front-matter toggles and the smart link — is pinned by reading
///   the editor's source (`everyEditorControlCommitsThroughItsBinding`).
///
/// **A negative assertion needs a positive signal.** "The field was not rewritten" and "nothing was written" are only
/// evidence once an update pass that could have done it has demonstrably run. So each such test waits for something
/// the same pass carries: a front-matter flag followed by the same modifier, or, in the real editor, the navigation
/// bar showing a later rename.
///
/// **Hosting decides whether the covered-editor tests can fail** (`RealEditorHost`): only an editor PUSHED onto a
/// stack, as the Collections tab shows it, stops running `onChange` when Collection settings covers it. They use
/// `pushed: true`. They were measured failing on the pre-#1415 editor on an iPhone 17 host; the host forces the compact
/// layout, so an iPad host should draw the same screens, but none was run on one.
///
/// `CollectionEditorTitleTests` (UI) drives the real title, the Collections-tab exit and the Section defaults sheet on
/// iPhone and iPad; this suite is where the rename follow is tested, because nothing in the app's own UI can rename a
/// collection while its editor is open on iOS in the same window — the writers are another iPad window and iCloud.
///
/// Version history:
///   1.0 — #1359: initial implementation
///   1.1 — #1359 review: the real editor hosted; the new-collection session; the macOS pane's call sites; a real name
///         edit saves exactly once
///   1.2 — #1359 review, round 2: the session judges "untouched" from the model; a list row's name (`listName`), and
///         the Add to Collection picker's and the Research rail's rows read
///   1.3 — #1415 / #1413: the editor hosted pushed; edits on its covered settings screen; the Section defaults follows;
///         `CollectionEditorCommit`'s rules; the wiring scan. The modifier no longer saves, so its save-count tests
///         became rule tests, and "Following a rename does not save it again" was retired — the modifier has no way to
///         save, and the real editor's echo test covers the claim
///   1.4 — #1415 / #1413 review, round 1: the per-field test sets a smart link from elsewhere, so an edit that writes
///         every field again fails it (the name could not show that); the scan finds a link assignment however it is
///         spelled, and any `$linkedSavedSearchId` binding
@Suite("Collection editor naming and edits — #1359, #1413, #1415", .serialized)
@MainActor
struct CollectionEditorNamingTests {

    /// The three optional text fields the editor follows from the model and commits one at a time (#1413): its
    /// description (`note`), subtitle and author line — the three a heading's Section defaults sheet also writes.
    enum OptionalText: String, CaseIterable, Sendable {
        /// The description.
        case note
        /// The title-page subtitle.
        case subtitle
        /// The title-page author line.
        case authorLine

        /// The collection property the field shows and writes.
        var keyPath: ReferenceWritableKeyPath<Collection, String?> {
            switch self {
            case .note: \.note
            case .subtitle: \.subtitle
            case .authorLine: \.authorLine
            }
        }
    }

    // MARK: - The title

    @Test("The title is the saved name, trimmed")
    func titleReadsTheSavedName() {
        #expect(CollectionEditorNaming.navigationTitle(savedName: "Cuban Missile Crisis", isNewCollection: false)
                == "Cuban Missile Crisis")
        // A collection this editor created reads its name as soon as it has one, not "New Collection".
        #expect(CollectionEditorNaming.navigationTitle(savedName: "Cuban Missile Crisis", isNewCollection: true)
                == "Cuban Missile Crisis")
        // A name written untrimmed by another writer is shown the way this editor would have saved it.
        #expect(CollectionEditorNaming.navigationTitle(savedName: "  Berlin Crisis \n", isNewCollection: false)
                == "Berlin Crisis")
    }

    /// Each fallback branch has its own expectation: the collection this editor created, one it opened, and a name
    /// that is only whitespace, which is no name.
    @Test("With no name, the title says how the editor was opened")
    func titleFallsBackByHowTheEditorWasOpened() {
        #expect(CollectionEditorNaming.navigationTitle(savedName: "", isNewCollection: true) == "New Collection")
        #expect(CollectionEditorNaming.navigationTitle(savedName: "", isNewCollection: false)
                == "Untitled Collection")
        #expect(CollectionEditorNaming.navigationTitle(savedName: "   ", isNewCollection: false)
                == "Untitled Collection")
    }

    /// What a list row prints. The fallback is the case the rule exists for: a new collection is in the store, with no
    /// name, for as long as its editor waits in the Collections tab.
    @Test("A list row prints the saved name, trimmed, or \"Untitled Collection\"")
    func listNameFallsBackToUntitled() {
        #expect(CollectionEditorNaming.listName(savedName: "Cuban Missile Crisis") == "Cuban Missile Crisis")
        #expect(CollectionEditorNaming.listName(savedName: "  Berlin Crisis \n") == "Berlin Crisis")
        #expect(CollectionEditorNaming.listName(savedName: "") == "Untitled Collection")
        #expect(CollectionEditorNaming.listName(savedName: "   ") == "Untitled Collection")
    }

    @Test("A word cloud of an unnamed collection is titled \"Untitled Collection\", not blank")
    func wordCloudTitlesAnUnnamedCollection() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let collection = Collection(name: "  ")
        context.insert(collection)
        let resolver = WordCloudScopeResolver(manifestStore: ManifestStore(bundledEntries: []), pipeline: nil,
                                              searchService: nil, modelContext: context)
        let resolved = try await resolver.resolve(.collection(id: collection.id))
        #expect(resolved.title == CollectionEditorNaming.listName(savedName: ""))
        #expect(!resolved.title.trimmingCharacters(in: .whitespaces).isEmpty)
        withExtendedLifetime(container) {}
    }

    // MARK: - Agreement

    /// Agreement is the test both directions of the sync turn on. Whitespace is the conjunct worth a fixture each way:
    /// the editor trims before it saves, so a field holding a space the user has just typed says the same thing as
    /// the saved name — and treating it as a disagreement would save for nothing on the save side, and on the follow
    /// side delete the whitespace of a pasted name under the user's cursor.
    @Test("The field agrees with the saved name once both are trimmed")
    func fieldAgreesWithTheSavedNameOnceTrimmed() {
        #expect(CollectionEditorNaming.fieldAgrees("Cuban Missile Crisis", withSavedName: "Cuban Missile Crisis"))
        #expect(CollectionEditorNaming.fieldAgrees("Cuban Missile Crisis ", withSavedName: "Cuban Missile Crisis"))
        #expect(CollectionEditorNaming.fieldAgrees(" Cuban Missile Crisis", withSavedName: "Cuban Missile Crisis"))
        #expect(CollectionEditorNaming.fieldAgrees("Cuban Missile Crisis", withSavedName: "Cuban Missile Crisis  "))
        #expect(CollectionEditorNaming.fieldAgrees("   ", withSavedName: ""))
        #expect(!CollectionEditorNaming.fieldAgrees("Cuban Missile Crisis", withSavedName: "Berlin Crisis"))
        #expect(!CollectionEditorNaming.fieldAgrees("Cuban Missile Crisis", withSavedName: ""))
        #expect(!CollectionEditorNaming.fieldAgrees("", withSavedName: "Cuban Missile Crisis"))
    }

    // MARK: - The macOS collection window

    /// No test target runs macOS code, so the macOS collection window's two call sites are pinned by reading them:
    /// its title and its name follow must go through the same rules the iOS editor uses. Scoped to
    /// `CollectionDetailPane`, and to the calls themselves — each must be the only one of its kind there, spelled
    /// exactly — so prose about them, or the right call somewhere else, cannot satisfy it.
    @Test("The macOS collection window titles and follows its name through the same rules")
    func macWindowUsesTheSharedNamingRules() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/Collections/MacCollectionManagerView.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        let start = try #require(source.range(of: "// MARK: - CollectionDetailPane"),
                                 "CollectionDetailPane's MARK is gone — moved or renamed?")
        let end = try #require(source.range(of: "// MARK: - MacEntryRow", range: start.upperBound..<source.endIndex),
                               "The MARK after CollectionDetailPane is gone, so the pane's extent is unknown")
        let code = source[start.upperBound..<end.lowerBound]
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") }

        let titles = code.filter { $0.hasPrefix(".navigationTitle(") }
        #expect(titles == [".navigationTitle(CollectionEditorNaming.navigationTitle(savedName: name, isNewCollection: false))"],
                "CollectionDetailPane's title is not the shared rule for a collection it opened: \(titles)")

        let follow = try #require(code.firstIndex(of: ".onChange(of: collection.name) { _, newValue in"),
                                  "CollectionDetailPane no longer follows collection.name")
        #expect(code.filter { $0.hasPrefix(".onChange(of: collection.name)") }.count == 1,
                "CollectionDetailPane follows collection.name more than once")
        #expect(code[follow + 1] == "if !CollectionEditorNaming.fieldAgrees(name, withSavedName: newValue) { name = newValue }",
                "CollectionDetailPane's name follow does not compare through fieldAgrees: \(code[follow + 1])")
    }

    /// The blank row (#1359 review, round 2). While a new collection's editor waits in the Collections tab, the
    /// collection is in the store with no name, and a document's Add to Collection picker lists it; printed bare, it
    /// was a blank row reading "0 documents". The row's one name-printing call is pinned by reading `collectionRow`:
    /// it must print through `listName`, and nothing there may print the name another way. Hosting the real picker
    /// was tried first and read nothing — in the test host's window it exposed no accessibility label at all, not
    /// even its navigation bar's — so this reads the source, and `listNameFallsBackToUntitled` pins what it prints.
    @Test("The Add to Collection picker's row prints a collection's name through listName")
    func pickerRowUsesListName() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/Collections/CollectionPickerSheet.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        let start = try #require(source.range(of: "private func collectionRow(_ collection: Collection) -> some View {"),
                                 "CollectionPickerSheet.collectionRow is gone — moved or renamed?")
        let end = try #require(source.range(of: "// MARK: - macOS Body", range: start.upperBound..<source.endIndex),
                               "The MARK after collectionRow is gone, so its extent is unknown")
        let names = source[start.upperBound..<end.lowerBound]
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") && $0.contains("collection.name") }
        #expect(names == ["Text(CollectionEditorNaming.listName(savedName: collection.name))"],
                "The picker's row prints a collection's name some other way: \(names)")
    }

    /// The Research rail's Collections section lists the collections a document is in, so a document added from the
    /// rail's own Add to Collection to a new collection whose editor waits in the Collections tab is listed under a
    /// collection with no name. Nothing hosts the rail here, so its one name-printing call is pinned by reading
    /// `collectionsAccordion`: it must print through `listName`, and nothing there may print the name another way.
    @Test("The Research rail's Collections section prints a collection's name through listName")
    func railCollectionsSectionUsesListName() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/DocumentView/ResearchRailView.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        let start = try #require(source.range(of: "private var collectionsAccordion: some View {"),
                                 "ResearchRailView.collectionsAccordion is gone — moved or renamed?")
        let end = try #require(source.range(of: "// MARK: - Classification", range: start.upperBound..<source.endIndex),
                               "The MARK after collectionsAccordion is gone, so its extent is unknown")
        let names = source[start.upperBound..<end.lowerBound]
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") && $0.contains("collection.name") }
        #expect(names == ["Text(CollectionEditorNaming.listName(savedName: collection.name))"],
                "The rail's Collections section prints a collection's name some other way: \(names)")
    }

    #if os(iOS)
    // MARK: - The wiring, hosted

    /// The acceptance case: another writer renames the collection, and the editor's name field says so. Without it
    /// the field keeps the old name, and the reader's next edit to it builds on the name the editor opened with.
    @Test("A rename made elsewhere reaches the editor's name field")
    func aRenameMadeElsewhereReachesTheNameField() async throws {
        try await Self.withHostedEditor(named: "Cuban Missile Crisis") { collection, editor in
            collection.name = "Berlin Crisis"
            let followed = await Self.settle { editor.name == "Berlin Crisis" }
            #expect(followed, "The name field still reads \"\(editor.name)\" after the model was renamed")
        }
    }

    /// #1413: a description, subtitle or author line a heading's Section defaults sheet writes onto the model reaches
    /// the editor's field, so the editor shows it and the reader's next edit there builds on it — and cleared there,
    /// empties it. One run per field, because each has its own follow; each is written untrimmed, as the sheet writes
    /// while the reader types.
    @Test("A description, subtitle or author line written elsewhere reaches the editor's field (#1413)",
          arguments: OptionalText.allCases)
    func anOptionalTextWrittenElsewhereReachesTheField(_ text: OptionalText) async throws {
        try await Self.withHostedEditor(named: "Cuban Missile Crisis") { collection, editor in
            collection[keyPath: text.keyPath] = "Draft "
            #expect(await Self.settle { editor.field(text) == "Draft " },
                    "The \(text) field still reads \"\(editor.field(text))\" after the model was changed")

            // Cleared elsewhere, the field empties too: the saved `nil` reads as an empty field.
            collection[keyPath: text.keyPath] = nil
            #expect(await Self.settle { editor.field(text).isEmpty },
                    "The \(text) field still reads \"\(editor.field(text))\" after the model cleared it")
        }
    }

    /// The editor's own commit, seen from the follow side: the reader has pasted a name ending in a space, the editor's
    /// commit (`CollectionEditorCommit.name`, the rule its name field's binding calls) has written it trimmed, and the
    /// model's change comes back through `onChange`. The field must keep its space — a follow that compared untrimmed
    /// text would delete it under the cursor, and the next word would run into this one.
    ///
    /// Ordinary typing never builds this state (a typed trailing space does not change the trimmed name, so nothing
    /// comes back), which is why `CollectionEditorTitleTests` passes against an untrimmed rule and this fixture does
    /// not. It passes on the pre-#1359 editor too, which followed nothing; the untrimmed-rule mutant is what it kills.
    @Test("The editor's own trimmed commit does not rewrite the name field")
    func theEditorsOwnTrimmedCommitDoesNotRewriteTheField() async throws {
        try await Self.withHostedEditor(named: "Cuban") { collection, editor in
            // The field as the reader left it; the model as the editor's commit leaves it.
            editor.name = "Cuban Missile Crisis "
            try #require(CollectionEditorCommit.name(editor.name, to: collection),
                         "The edit that sets up the fixture was not written")
            try #require(collection.name == "Cuban Missile Crisis", "The commit wrote \"\(collection.name)\"")

            collection.includeColophon = true
            try #require(await Self.settle { editor.includeColophon },
                         "The modifier never carried the marker flag, so no pass is known to have seen the commit")
            #expect(editor.name == "Cuban Missile Crisis ",
                    "The field was rewritten to \"\(editor.name)\"; the trailing space the reader typed is gone")
        }
    }

    /// The same for each of #1413's three follows: the editor's own trimmed commit comes back, and the field keeps the
    /// space the reader typed. One run per field, because each follow has its own agreement guard.
    @Test("The editor's own trimmed commit does not rewrite a description, subtitle or author line (#1413)",
          arguments: OptionalText.allCases)
    func theEditorsOwnTrimmedCommitDoesNotRewriteAnOptionalText(_ text: OptionalText) async throws {
        try await Self.withHostedEditor(named: "Cuban Missile Crisis") { collection, editor in
            editor.setField(text, to: "Draft ")
            try #require(CollectionEditorCommit.text(editor.field(text), to: text.keyPath, of: collection),
                         "The edit that sets up the fixture was not written")
            try #require(collection[keyPath: text.keyPath] == "Draft",
                         "The commit wrote \(String(describing: collection[keyPath: text.keyPath]))")

            collection.includeColophon = true
            try #require(await Self.settle { editor.includeColophon },
                         "The modifier never carried the marker flag, so no pass is known to have seen the commit")
            #expect(editor.field(text) == "Draft ",
                    "The \(text) field was rewritten to \"\(editor.field(text))\"; the reader's trailing space is gone")
        }
    }

    // MARK: - Committing an edit (#1415, #1413)

    /// The name's commit rule, both conjuncts: a keystroke that changes only whitespace writes nothing, and one that
    /// changes the name writes it trimmed — once.
    @Test("A name edit is written, trimmed, only when it changes the saved name")
    func aNameEditIsWrittenOnlyWhenItChangesTheSavedName() {
        let collection = Collection(name: "Cuban Missile Crisis")
        #expect(!CollectionEditorCommit.name("Cuban Missile Crisis ", to: collection),
                "A keystroke adding only a trailing space was written")
        #expect(collection.name == "Cuban Missile Crisis")
        #expect(CollectionEditorCommit.name(" Cuban Missile Crisis, 1962 ", to: collection),
                "A keystroke that changed the name was not written")
        #expect(collection.name == "Cuban Missile Crisis, 1962", "The name was written as \"\(collection.name)\"")
        #expect(!CollectionEditorCommit.name("Cuban Missile Crisis, 1962", to: collection),
                "The same name was written a second time")
    }

    /// The rule the description, subtitle and author line commit through (#1413): trimmed, `nil` when nothing is left,
    /// and nothing at all when the field says what is saved — including a value another writer saved UNtrimmed, which
    /// the editor must not rewrite trimmed under them.
    @Test("An optional text is written trimmed, nil when blank, and only when it changes what is saved")
    func anOptionalTextIsWrittenOnlyWhenItChanges() {
        let collection = Collection(name: "Cuban Missile Crisis")
        #expect(!CollectionEditorCommit.text("   ", to: \.subtitle, of: collection),
                "A blank field over no subtitle was written")
        #expect(collection.subtitle == nil)
        #expect(CollectionEditorCommit.text(" Draft ", to: \.subtitle, of: collection), "A new subtitle was not written")
        #expect(collection.subtitle == "Draft", "The subtitle was written as \(String(describing: collection.subtitle))")
        #expect(!CollectionEditorCommit.text("Draft ", to: \.subtitle, of: collection),
                "A keystroke adding only a trailing space was written")

        collection.subtitle = "Draft "
        #expect(!CollectionEditorCommit.text("Draft", to: \.subtitle, of: collection),
                "A field agreeing with another writer's untrimmed subtitle wrote over it")
        #expect(collection.subtitle == "Draft ", "Another writer's subtitle was rewritten trimmed")

        #expect(CollectionEditorCommit.text("", to: \.subtitle, of: collection), "Clearing the field was not written")
        #expect(collection.subtitle == nil, "A cleared subtitle was saved as \(String(describing: collection.subtitle))")
    }

    /// The flag and smart-link rules: a write only on a change, so setting a toggle to the value the model already
    /// holds writes nothing.
    @Test("A toggle or the smart link is written only when it changes")
    func aFlagOrLinkIsWrittenOnlyWhenItChanges() {
        let collection = Collection(name: "Cuban Missile Crisis")
        #expect(!CollectionEditorCommit.flag(false, to: \.includeColophon, of: collection),
                "An unchanged flag was written")
        #expect(CollectionEditorCommit.flag(true, to: \.includeColophon, of: collection),
                "A changed flag was not written")
        #expect(collection.includeColophon)

        let search = UUID()
        #expect(CollectionEditorCommit.savedSearch(search, to: collection), "Linking a saved search was not written")
        #expect(collection.savedSearchId == search)
        #expect(!CollectionEditorCommit.savedSearch(search, to: collection), "The same link was written a second time")
        #expect(CollectionEditorCommit.savedSearch(nil, to: collection), "Unlinking was not written")
        #expect(collection.savedSearchId == nil)
    }

    // MARK: - The real editor, hosted

    /// The acceptance case one layer up: a rename made elsewhere reaches the REAL editor's name field — here the field
    /// on its Collection settings screen — and the editor's next edit, typed there into another field, is written
    /// without writing the name the editor opened with. Fails if the editor passes the modifier a binding it cannot
    /// write (`.constant(collectionName)`) or follows nothing. It cannot see an edit that writes every field the editor
    /// holds again (the pre-#1413 `saveLive()`): by then the editor has followed the rename, so its copy of the name IS
    /// the rename. `eachSettingsFieldWritesItsOwnProperty` catches that shape, through the smart link.
    @Test("A rename made elsewhere reaches the real editor's name field and survives its next edit")
    func aRenameMadeElsewhereSurvivesTheEditorsNextEdit() async throws {
        try await Self.withRealEditor(named: "Cuban Missile Crisis", pushed: true) { collection, editor, activeProject in
            try #require(await Self.settle { editor.title == "Cuban Missile Crisis" },
                         "The hosted editor never showed its title (read \(editor.title ?? "nil")), so it is not on screen")
            collection.name = "Berlin Crisis"
            try #require(await Self.settle { editor.title == "Berlin Crisis" },
                         "The editor's title never read the rename, so no pass is known to have seen it")

            try #require(await editor.openSettings(),
                         "Collection settings did not open over the editor; the bar reads \(editor.title ?? "nil")")
            let name = try #require(editor.textField(placeholder: "Collection Name"),
                                    "Collection settings shows no name field")
            #expect(name.text == "Berlin Crisis",
                    "The editor's name field reads \"\(name.text ?? "")\", not the rename made elsewhere")

            let subtitle = try #require(editor.textField(placeholder: "Subtitle (title page)"),
                                        "Collection settings shows no subtitle field")
            try #require(editor.type("Draft", into: subtitle), "The subtitle field would not take focus")
            try #require(await Self.settle { collection.projectIds.contains(activeProject) },
                         "The editor never recorded the subtitle edit, so what its commit writes was not tested")
            #expect(collection.subtitle == "Draft",
                    "The subtitle typed in the editor reads \(String(describing: collection.subtitle))")
            #expect(collection.name == "Berlin Crisis",
                    "The editor's next edit wrote \"\(collection.name)\" over the rename")
        }
    }

    /// Following a rename in the REAL editor writes nothing: the other writer's note survives, and the editor does not
    /// tag the collection into this device's active project. Fails if the editor's body saves on every change to its
    /// name field again — the `.onChange(of: collectionName) { saveLive() }` #1359 removed, and the shape every
    /// `onChange` save #1415 removed had — which the modifier-only tests above cannot see because they build their own
    /// call.
    @Test("Following a rename in the real editor writes nothing back")
    func followingARenameInTheEditorWritesNothingBack() async throws {
        try await Self.withRealEditor(named: "Cuban Missile Crisis", note: "The editor's note") {
            collection, editor, activeProject in
            try #require(await Self.settle { editor.title == "Cuban Missile Crisis" },
                         "The hosted editor never showed its title (read \(editor.title ?? "nil")), so it is not on screen")
            // Another writer changes the name and the note together, as one iCloud import would.
            collection.name = "Berlin Crisis"
            collection.note = "Their note"
            try #require(await Self.settle { editor.title == "Berlin Crisis" },
                         "The editor's title never read the rename, so it was never followed")
            // The marker: the bar shows a SECOND rename, so the pass after the first follow — the one an echo save
            // would run in — has run.
            collection.name = "Berlin Crisis, 1961"
            try #require(await Self.settle { editor.title == "Berlin Crisis, 1961" },
                         "The editor's title never read the second rename, so no later pass is known to have run")
            #expect(collection.note == "Their note",
                    "Following the rename wrote the editor's note back: the note reads \"\(collection.note ?? "nil")\"")
            #expect(!collection.projectIds.contains(activeProject),
                    "Following the rename saved, tagging the collection into this device's active project")
        }
    }

    // MARK: - Edits on the covered settings screen (#1415)

    /// On the compact layout Collection settings is PUSHED over the editor, and an editor itself pushed — as the
    /// Collections tab shows it — runs no `onChange` while it is covered. So an edit made there must reach the
    /// collection, and be saved, as it is made, not when the editor comes back: left by the Collections tab, or by the
    /// app being killed, the editor never does. Going back afterwards is the control that the typing reached the
    /// editor at all. Hosted pushed because hosting matters: see `RealEditorHost`.
    @Test("A name typed on the covered Collection settings screen is saved as it is typed (#1415)")
    func aNameTypedOnTheCoveredSettingsScreenIsSavedAsTyped() async throws {
        try await Self.withRealEditor(named: "", pushed: true) { collection, editor, _ in
            try #require(await editor.openSettings(),
                         "Collection settings did not open over the editor; the bar reads \(editor.title ?? "nil")")
            let field = try #require(editor.textField(placeholder: "Collection Name"),
                                     "Collection settings shows no name field")
            try #require(editor.type("Cuban Missile Crisis", into: field), "The name field would not take focus")
            #expect(await Self.settle { collection.name == "Cuban Missile Crisis" }, """
                The name typed in Collection settings had not reached the collection 5 s later, with the settings screen \
                still covering the editor: it reads "\(collection.name)". Left by the Collections tab, or by the app being \
                killed, the name is lost.
                """)
            #expect(collection.modelContext?.hasChanges == false,
                    "The typed name reached the collection but was not saved, so killing the app would lose it")

            try #require(await editor.goBack(), "Back did not leave Collection settings")
            #expect(await Self.settle { collection.name == "Cuban Missile Crisis" },
                    "Even back on the editor, the typed name never reached the collection: it reads \"\(collection.name)\"")
        }
    }

    /// The rest of the covered screen's text, field by field: each lands on ITS OWN property while the screen still
    /// covers the editor, is saved, and records the edit against the active project; and none of them writes a field
    /// it does not edit. The name cannot show that last part: the editor's copy of it is the saved name, so writing it
    /// again changes nothing. So once the editor is open, the collection is given a smart link from elsewhere — the
    /// one field the editor does not follow, so its copy stays `nil`. An edit that wrote every field the editor holds
    /// (#1413's `saveLive()` shape, moved into the commit) would write that `nil` over the link; each commit writing
    /// only its own field leaves it. The description starts non-empty, so its field is on screen without "Add a note".
    @Test("Each text field on the covered Collection settings screen writes its own property as it is typed (#1415)")
    func eachSettingsFieldWritesItsOwnProperty() async throws {
        try await Self.withRealEditor(named: "Cuban Missile Crisis", note: "Old note", pushed: true) {
            collection, editor, activeProject in
            try #require(await editor.openSettings(),
                         "Collection settings did not open over the editor; the bar reads \(editor.title ?? "nil")")
            // Set only now: the settings screen is up, so the editor has taken its copies, and its link is `nil`.
            let linkSetElsewhere = UUID()
            collection.savedSearchId = linkSetElsewhere
            let subtitle = try #require(editor.textField(placeholder: "Subtitle (title page)"),
                                        "Collection settings shows no subtitle field")
            try #require(editor.type("Draft", into: subtitle), "The subtitle field would not take focus")
            #expect(await Self.settle { collection.subtitle == "Draft" },
                    "The subtitle typed in covered settings reads \(String(describing: collection.subtitle))")

            // The marker project is in no `Project` row, so the author field's placeholder is the plain "Author".
            let author = try #require(editor.textField(placeholder: "Author"),
                                      "Collection settings shows no author-line field")
            try #require(editor.type("J. Smith", into: author), "The author-line field would not take focus")
            #expect(await Self.settle { collection.authorLine == "J. Smith" },
                    "The author line typed in covered settings reads \(String(describing: collection.authorLine))")

            let note = try #require(editor.textView(holding: "Old note"),
                                    "Collection settings shows no description holding the collection's note")
            try #require(editor.type(", revised", into: note), "The description would not take focus")
            #expect(await Self.settle { collection.note == "Old note, revised" },
                    "The description typed in covered settings reads \(String(describing: collection.note))")

            #expect(collection.name == "Cuban Missile Crisis",
                    "An edit to another field wrote the name as \"\(collection.name)\"")
            #expect(collection.savedSearchId == linkSetElsewhere, """
                An edit to another field wrote the editor's copy of the smart link over the one set elsewhere: it \
                reads \(collection.savedSearchId?.uuidString ?? "nil"). The editor writes every field it holds on an \
                edit again.
                """)
            #expect(collection.projectIds.contains(activeProject),
                    "The edits reached the collection without being recorded against the active project")
            #expect(collection.modelContext?.hasChanges == false,
                    "The edits reached the collection but were not saved, so killing the app would lose them")
        }
    }

    /// The wiring nothing else can reach. The unit tests type into the text fields and `CollectionEditorTitleTests`
    /// flips the colophon toggle; this pins the rest by reading `CollectionEditorView.swift`. Every binding of the
    /// editor's own field state handed to a control goes through `committing(`, so it is written as it is edited
    /// (#1415): outside the `FrontMatterModelSync` call, which follows the model and must never commit, no `$field`
    /// appears bare. And the smart-collection link is assigned only inside the function that commits it — however the
    /// assignment is spelled, `self.` included — and no control binds it at all. Whole-line comments are blanked first,
    /// so a comment quoting either shape can neither satisfy nor fail the scan.
    @Test("Every control bound to the editor's fields commits through its binding, and one function writes the link (#1415)")
    func everyEditorControlCommitsThroughItsBinding() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/Collections/CollectionEditorView.swift")
        let code = try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces).hasPrefix("//") ? "" : String($0) }
            .joined(separator: "\n")
        let fields = ["collectionName", "collectionNote", "collectionSubtitle", "collectionAuthorLine",
                      "includeColophon", "includeProjectProvenance", "includeMethodAppendix"]

        // The follow's call, balanced from its opening parenthesis.
        let syncStart = try #require(code.range(of: ".modifier(FrontMatterModelSync("),
                                     "CollectionEditorView no longer applies FrontMatterModelSync")
        var depth = 0
        var syncEnd = syncStart.lowerBound
        for index in code[syncStart.lowerBound...].indices {
            if code[index] == "(" { depth += 1 }
            if code[index] == ")" { depth -= 1; if depth == 0 { syncEnd = code.index(after: index); break } }
        }
        let sync = syncStart.lowerBound..<syncEnd
        #expect(!sync.isEmpty && depth == 0, "The FrontMatterModelSync call never closes")

        var committed: Set<String> = []
        var bare: [String] = []
        for field in fields {
            for hit in code.ranges(of: "$\(field)") where !sync.contains(hit.lowerBound) {
                let line = code[..<hit.lowerBound].count { $0 == "\n" } + 1
                if code[..<hit.lowerBound].hasSuffix("committing(") {
                    committed.insert(field)
                } else {
                    bare.append("$\(field) at line \(line)")
                }
            }
            #expect(code[sync].contains("$\(field)"), "FrontMatterModelSync is not given $\(field) to follow")
        }
        #expect(bare.isEmpty, "A control is bound to the editor's own state without committing it: \(bare)")
        #expect(committed == Set(fields),
                "No control commits \(Set(fields).subtracting(committed).sorted()) — read \(committed.count) of \(fields.count)")

        // The function that commits the link: its body, balanced from its opening brace.
        let linkStart = try #require(code.range(of: "private func linkSavedSearch(_ id: UUID?) {"),
                                     "CollectionEditorView has no linkSavedSearch(_:) — moved or renamed?")
        var braces = 0
        var linkEnd = linkStart.upperBound
        for index in code[linkStart.lowerBound...].indices {
            if code[index] == "{" { braces += 1 }
            if code[index] == "}" { braces -= 1; if braces == 0 { linkEnd = code.index(after: index); break } }
        }
        let linkBody = linkStart.lowerBound..<linkEnd

        // Every assignment to the editor's copy of the link — `linkedSavedSearchId = …` or `self.linkedSavedSearchId =
        // …`, though not the `_linkedSavedSearchId` storage `init` seeds, nor a `==` — sits in that body. And no
        // control binds the copy: the link is in no `committing(`, so a `$linkedSavedSearchId` binding would set it
        // without committing it — the shape the Unlink button and both pickers had before #1415, which left the save
        // to an `onChange` a covered, pushed editor never ran.
        let assignment = try NSRegularExpression(pattern: #"(?<![\w$])linkedSavedSearchId\s*=(?!=)"#)
        let linkWrites = assignment.matches(in: code, range: NSRange(code.startIndex..., in: code))
            .compactMap { Range($0.range, in: code) }
        let strayLinkWrites = linkWrites.filter { !linkBody.contains($0.lowerBound) }
            .map { "line \(code[..<$0.lowerBound].count { $0 == "\n" } + 1)" }
        #expect(!linkWrites.isEmpty, "The scan found no assignment to linkedSavedSearchId at all — renamed?")
        #expect(strayLinkWrites.isEmpty,
                "The smart-collection link is assigned outside the function that commits it, at \(strayLinkWrites)")
        let linkBindings = code.ranges(of: "$linkedSavedSearchId")
            .map { "line \(code[..<$0.lowerBound].count { $0 == "\n" } + 1)" }
        #expect(linkBindings.isEmpty, "A control binds the editor's smart link, which nothing commits: \(linkBindings)")

        // …and that function commits it: it sets the field and records a write.
        let link = code[linkBody]
            .split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        #expect(link.contains("linkedSavedSearchId = id"), "linkSavedSearch(_:) does not set the editor's link")
        #expect(link.contains("if CollectionEditorCommit.savedSearch(id, to: collection) { recordEdit() }"),
                "linkSavedSearch(_:) does not commit the link to the collection: \(link)")
    }

    // MARK: - Edits made in a heading's Section defaults (#1413)

    /// A heading's Section defaults sheet (`CollectionAttributesRows`) writes the collection's description, subtitle
    /// and author line straight onto the model, untrimmed, as the reader types — and its colophon toggle beside them.
    /// The editor follows the toggle; before #1413 following it saved EVERY field the editor held, from the copies it
    /// took when it opened, so the three were put back as they were. Following must write nothing — the marker project
    /// stays out of `projectIds` too. The second rename is the positive signal that the pass after the follow, the one
    /// such a save ran in, has run.
    @Test("A description, subtitle and author line set in Section defaults survive a toggle in the same sheet (#1413)")
    func sectionDefaultsFieldsSurviveAToggleInTheSameSheet() async throws {
        try await Self.withRealEditor(named: "Cuban Missile Crisis") { collection, editor, activeProject in
            try #require(await Self.settle { editor.title == "Cuban Missile Crisis" },
                         "The hosted editor never showed its title (read \(editor.title ?? "nil")), so it is not on screen")
            collection.note = "A working note"
            collection.subtitle = "Draft"
            collection.authorLine = "J. Smith "
            collection.includeColophon = true
            collection.name = "Berlin Crisis"
            try #require(await Self.settle { editor.title == "Berlin Crisis" },
                         "The editor's title never read the rename, so no pass is known to have followed the toggle")
            collection.name = "Berlin Crisis, 1961"
            try #require(await Self.settle { editor.title == "Berlin Crisis, 1961" },
                         "The editor's title never read the second rename, so no later pass is known to have run")
            #expect(collection.note == "A working note",
                    "The toggle's follow wrote the editor's description back: it reads \(String(describing: collection.note))")
            #expect(collection.subtitle == "Draft",
                    "The toggle's follow wrote the editor's subtitle back: it reads \(String(describing: collection.subtitle))")
            #expect(collection.authorLine == "J. Smith ", """
                The toggle's follow rewrote the author line the sheet wrote: it reads \
                \(String(describing: collection.authorLine))
                """)
            #expect(collection.includeColophon, "The colophon turned on in the sheet was turned off again")
            #expect(!collection.projectIds.contains(activeProject),
                    "Following the toggle saved, tagging the collection into this device's active project")
        }
    }

    /// The editor's own Subtitle field — on the compact layout, the covered settings screen — reads a subtitle set in
    /// Section defaults, and the reader's next edit there builds on it rather than on the copy the editor opened with.
    @Test("Collection settings shows a subtitle set in Section defaults, and the next edit there carries it (#1413)")
    func settingsShowsASubtitleSetInSectionDefaults() async throws {
        try await Self.withRealEditor(named: "Cuban Missile Crisis", pushed: true) { collection, editor, _ in
            try #require(await Self.settle { editor.title == "Cuban Missile Crisis" },
                         "The hosted editor never showed its title (read \(editor.title ?? "nil")), so it is not on screen")
            collection.subtitle = "Draft"
            collection.name = "Berlin Crisis"
            try #require(await Self.settle { editor.title == "Berlin Crisis" },
                         "The editor's title never read the rename, so no pass is known to have seen the subtitle")
            try #require(await editor.openSettings(),
                         "Collection settings did not open over the editor; the bar reads \(editor.title ?? "nil")")
            let field = try #require(editor.textField(placeholder: "Subtitle (title page)"),
                                     "Collection settings shows no subtitle field")
            #expect(field.text == "Draft", """
                Collection settings' Subtitle reads "\(field.text ?? "")", not the subtitle set in Section defaults: the \
                editor still holds the copy it opened with.
                """)
            try #require(editor.type(", revised", into: field), "The subtitle field would not take focus")
            #expect(await Self.settle { collection.subtitle == "Draft, revised" }, """
                The subtitle edited in Collection settings reads \(String(describing: collection.subtitle)), not \
                "Draft, revised"
                """)
        }
    }

    /// A control on the defect, and the guard on its fix. Section defaults writes as the reader types, so a subtitle
    /// can reach the model ending in the space just typed. Following it must not save it back trimmed, or the space
    /// disappears under the reader's cursor in the sheet. The pre-#1413 editor followed nothing and passes; an editor
    /// that followed the field and then saved on the field's change, as its flags did, fails.
    @Test("A subtitle written untrimmed in Section defaults is not trimmed back by the editor (#1413)")
    func anUntrimmedSubtitleIsNotTrimmedBack() async throws {
        try await Self.withRealEditor(named: "Cuban Missile Crisis") { collection, editor, activeProject in
            try #require(await Self.settle { editor.title == "Cuban Missile Crisis" },
                         "The hosted editor never showed its title (read \(editor.title ?? "nil")), so it is not on screen")
            collection.subtitle = "Draft "
            collection.name = "Berlin Crisis"
            try #require(await Self.settle { editor.title == "Berlin Crisis" },
                         "The editor's title never read the rename, so no pass is known to have seen the subtitle")
            collection.name = "Berlin Crisis, 1961"
            try #require(await Self.settle { editor.title == "Berlin Crisis, 1961" },
                         "The editor's title never read the second rename, so no later pass is known to have run")
            #expect(collection.subtitle == "Draft ",
                    "The editor wrote the subtitle back as \(String(describing: collection.subtitle))")
            #expect(!collection.projectIds.contains(activeProject),
                    "Following the subtitle saved, tagging the collection into this device's active project")
        }
    }

    // MARK: - The new-collection session

    /// The rule `NewCollectionSession` applies when the editor is dismissed, and its two guards: nothing happens
    /// before the editor has inserted the collection (the copies its repeated `init` builds and throws away), and
    /// nothing happens twice (Back reports itself through `onChange` AND `onDisappear`).
    @Test("A new collection's session ends once, and only after it begins")
    func aNewCollectionSessionEndsOnceAndOnlyAfterItBegins() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext

        let stray = Collection(name: "")
        stray.note = "A note, so the collection would be kept and named"
        let straySession = NewCollectionSession(collection: stray)
        straySession.end()
        #expect(stray.name.isEmpty, "A session the editor never began named its collection \"\(stray.name)\"")

        let untouched = Collection(name: "")
        context.insert(untouched)
        let untouchedSession = NewCollectionSession(collection: untouched)
        untouchedSession.begin(in: context)
        untouchedSession.end()
        #expect(try !context.fetch(FetchDescriptor<Collection>()).contains { $0.id == untouched.id },
                "An untouched new collection outlived its editor")

        let kept = Collection(name: "")
        context.insert(kept)
        let keptSession = NewCollectionSession(collection: kept)
        keptSession.begin(in: context)
        kept.subtitle = "A subtitle"
        keptSession.end()
        #expect(kept.name == "Untitled Collection", "A kept, unnamed collection was named \"\(kept.name)\"")
        kept.name = ""
        keptSession.end()
        #expect(kept.name.isEmpty, "The session ended twice: the second end named the collection again")
        withExtendedLifetime(container) {}
    }

    /// The backstop: a pushed editor taken off the stack while a screen it pushed covers it gets no view event, and
    /// its session ends when the editor's state lets it go. `CollectionEditorTitleTests` drives that route on an
    /// iPhone; this pins the mechanism.
    @Test("A session the editor never ended ends when it is released")
    func aSessionNeverEndedEndsWhenReleased() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let kept = Collection(name: "")
        context.insert(kept)
        do {
            let session = NewCollectionSession(collection: kept)
            session.begin(in: context)
            kept.subtitle = "A subtitle"
        }
        #expect(await Self.settle { kept.name == "Untitled Collection" },
                "Releasing a session the editor never ended left its collection named \"\(kept.name)\"")
        withExtendedLifetime(container) {}
    }

    /// The tab switch (#1359 review, round 2). A tab switch does not end the session, so while the editor waits in the
    /// Collections tab the collection can gain an entry somewhere else — a document's Add to Collection picker lists
    /// it — and the editor's own outline, loaded once, never hears of it. "Untouched" must be read from the model:
    /// judged from the editor's outline, this collection was deleted at Back and its new entry left pointing at nothing.
    /// The entry is added through `CollectionDocumentDiscovery.appendToCollection`, the call the picker makes.
    @Test("A new collection that gained an entry somewhere else is kept, and named")
    func aNewCollectionThatGainedAnEntryElsewhereIsKept() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let collection = Collection(name: "")
        context.insert(collection)
        let session = NewCollectionSession(collection: collection)
        session.begin(in: context)

        let entry = CollectionDocumentDiscovery.appendToCollection(
            documentId: "d164", volumeId: "frus1961-63v11", collection: collection, modelContext: context)
        session.end()

        #expect(try context.fetch(FetchDescriptor<Collection>()).contains { $0.id == collection.id }, """
            A new collection that gained a document from another tab was discarded as untouched when its editor was \
            dismissed: the rule read the editor's outline, not the model.
            """)
        #expect(collection.name == "Untitled Collection",
                "The kept, unnamed collection was named \"\(collection.name)\"")
        #expect(entry.collection?.id == collection.id, "The entry added from another tab lost its collection")
        withExtendedLifetime(container) {}
    }

    /// The other side of reading the model: an entry the context has deleted is not content. Added and removed again
    /// before the editor goes, it leaves the collection as untouched as the editor's outline says it is. Measured: until
    /// the context saves, `documentEntries` still lists the deleted entry, so a rule that asked only whether it was
    /// empty kept this collection.
    @Test("An entry added and removed again leaves a new collection untouched")
    func anEntryAddedAndRemovedAgainLeavesItUntouched() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let collection = Collection(name: "")
        context.insert(collection)
        let session = NewCollectionSession(collection: collection)
        session.begin(in: context)

        let entry = CollectionDocumentDiscovery.appendToCollection(
            documentId: "d164", volumeId: "frus1961-63v11", collection: collection, modelContext: context)
        context.delete(entry)
        // The rule's `isDeleted` filter exists because, until the context saves, the relationship still lists the
        // deleted entry. Pin that precondition: if SwiftData ever drops it at `delete`, this test would otherwise
        // pass against the plain-`isEmpty` rule without saying so.
        #expect(collection.documentEntries?.contains { $0.id == entry.id } == true,
                "the deleted entry has left documentEntries before a save, so this fixture no longer tests the isDeleted filter")
        session.end()

        #expect(try !context.fetch(FetchDescriptor<Collection>()).contains { $0.id == collection.id }, """
            A new collection whose only entry was removed again outlived its editor, named "\(collection.name)": \
            the rule counted an entry the context had deleted.
            """)
        withExtendedLifetime(container) {}
    }

    // MARK: - Fixtures

    /// Containers whose host outlived its window, and every container a test typed into (see `withRealEditor`). Kept
    /// for the life of the process, because releasing one resets its context and destroys its models, and a surviving
    /// view that then read `collection.name` would stop the test host with "This model instance was destroyed by
    /// calling ModelContext.reset" — which is how the first run of this suite ended, and why teardown is ordered below.
    private static var parkedContainers: [ModelContainer] = []

    /// Hosts the modifier over a saved collection named `name` — the state an open editor's collection is in — runs
    /// `body`, then takes the host down BEFORE the container goes, and waits for it to deallocate so no view is left
    /// observing a model the container's release is about to destroy.
    private static func withHostedEditor(
        named name: String,
        _ body: @MainActor (Collection, EditorFieldsHost) async throws -> Void
    ) async throws {
        let container = try ModelContainer.makeTestContainer()
        let collection = Collection(name: name)
        container.mainContext.insert(collection)
        try container.mainContext.save()
        let editor = try EditorFieldsHost(collection: collection)

        var failure: (any Error)?
        do { try await body(collection, editor) } catch { failure = error }
        if !(await editor.close()) {
            parkedContainers.append(container)
            Issue.record("The hosted view outlived its window; its container is kept so its models stay valid")
        }
        withExtendedLifetime(container) {}
        if let failure { throw failure }
    }

    /// Hosts the REAL `CollectionEditorView` over a saved collection named `name`, with a fresh `AppState` whose
    /// active project is a marker: the editor's save adds the active project to the collection, so the marker
    /// appearing in `projectIds` is the positive signal that the editor saved. Takes the host down before the
    /// container goes, and restores the active project the test host had. `pushed` hosts the editor as the Collections
    /// tab does — pushed, at a compact width, so its Collection settings is pushed over it (`RealEditorHost`).
    private static func withRealEditor(
        named name: String,
        note: String? = nil,
        pushed: Bool = false,
        _ body: @MainActor (Collection, RealEditorHost, UUID) async throws -> Void
    ) async throws {
        let container = try ModelContainer.makeTestContainer()
        let collection = Collection(name: name)
        collection.note = note
        container.mainContext.insert(collection)
        try container.mainContext.save()
        let appState = AppState()
        let previousProject = appState.activeProjectId
        let activeProject = UUID()
        appState.activeProjectId = activeProject
        let editor = try RealEditorHost(collection: collection, container: container, appState: appState,
                                        pushed: pushed)

        var failure: (any Error)?
        do { try await body(collection, editor, activeProject) } catch { failure = error }
        if !(await editor.close()) {
            parkedContainers.append(container)
            Issue.record("The hosted editor outlived its window; its container is kept so its models stay valid")
        } else if pushed {
            // A pushed host is one a test types into, and a view can outlive the hosting controller there. Three runs
            // of this suite — two on the pre-#1415 editor, one on a mutant — lost the test host in the test AFTER a
            // typing test, after `close()` had seen the controller go. Only the mutant run's log carries the cause,
            // "This model instance was destroyed by calling ModelContext.reset"; the other two logs show only
            // xcodebuild relaunching the host at the same point, and none of the three left a crash report, so theirs
            // is inferred from the place, not observed. So a typing test's container is kept for the life of the
            // process.
            parkedContainers.append(container)
        }
        appState.activeProjectId = previousProject
        withExtendedLifetime(container) {}
        if let failure { throw failure }
    }

    /// Pumps the main run loop until `condition` holds or `timeout` passes, and reports whether it held.
    private static func settle(timeout: Duration = .seconds(5), until condition: () -> Bool) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }
    #endif
}

#if os(iOS)
/// Stands in for `CollectionEditorView`'s `@State` fields and hosts `FrontMatterModelSync` — the modifier the editor
/// applies — over bindings into them, in a window of the test host's own scene. `@Observable`, so a change to a field
/// re-renders the host the way a change to the editor's `@State` re-renders the editor.
@MainActor
@Observable
private final class EditorFieldsHost {
    /// The name field.
    var name: String
    /// The description (note) field.
    var note: String
    /// The subtitle field.
    var subtitle: String
    /// The author-line field.
    var authorLine: String
    /// The colophon toggle — the marker the tests use as a positive signal.
    var includeColophon: Bool
    /// The project-provenance toggle.
    var includeProjectProvenance: Bool
    /// The method-appendix toggle.
    var includeMethodAppendix: Bool
    /// The window hosting the modifier; `nil` once closed.
    @ObservationIgnored private var window: UIWindow?

    /// Seeds the fields from `collection`, as the editor's `init` does, and hosts the modifier in a visible window.
    init(collection: Collection) throws {
        name = collection.name
        note = collection.note ?? ""
        subtitle = collection.subtitle ?? ""
        authorLine = collection.authorLine ?? ""
        includeColophon = collection.includeColophon
        includeProjectProvenance = collection.includeProjectProvenance
        includeMethodAppendix = collection.includeMethodAppendix
        let scene = try #require(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first,
            "The test host has no window scene to host the modifier in")
        let sync = FrontMatterModelSync(
            collectionName: Binding(get: { self.name }, set: { self.name = $0 }),
            collectionNote: Binding(get: { self.note }, set: { self.note = $0 }),
            collectionSubtitle: Binding(get: { self.subtitle }, set: { self.subtitle = $0 }),
            collectionAuthorLine: Binding(get: { self.authorLine }, set: { self.authorLine = $0 }),
            includeColophon: Binding(get: { self.includeColophon }, set: { self.includeColophon = $0 }),
            includeProjectProvenance: Binding(get: { self.includeProjectProvenance },
                                              set: { self.includeProjectProvenance = $0 }),
            includeMethodAppendix: Binding(get: { self.includeMethodAppendix },
                                           set: { self.includeMethodAppendix = $0 }),
            collection: collection)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(rootView: Color.clear.modifier(sync))
        window.isHidden = false
        window.layoutIfNeeded()
        self.window = window
    }

    /// The field that shows `text`.
    func field(_ text: CollectionEditorNamingTests.OptionalText) -> String {
        switch text {
        case .note: note
        case .subtitle: subtitle
        case .authorLine: authorLine
        }
    }

    /// Sets the field that shows `text`, as the reader's typing does.
    func setField(_ text: CollectionEditorNamingTests.OptionalText, to value: String) {
        switch text {
        case .note: note = value
        case .subtitle: subtitle = value
        case .authorLine: authorLine = value
        }
    }

    /// Takes the window down and waits for the hosting controller to deallocate, so one test's view cannot answer
    /// another's model writes or outlive its container. Returns whether it went.
    func close() async -> Bool {
        weak let controller = window?.rootViewController
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(2))
        while controller != nil, clock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        return controller == nil
    }
}

/// Hosts the REAL `CollectionEditorView` in a window of the test host's scene, with a real `AppState` and the
/// collection's container — by default in its sheet presentation, which brings its own navigation stack.
///
/// With `pushed`, it is hosted the way the Collections tab shows it instead: PUSHED onto a navigation stack
/// (`PushedEditorRoot`, the `.navigationDestination` + `.pushed` pair `CollectionListView` uses), at a compact width
/// whatever the test host's device. So it draws the iPhone layout, and its Collection settings row pushes the settings
/// screen over it — the state #1415 is about. The distinction is measured, not assumed: an editor at the ROOT of its
/// stack (the sheet presentation) went on running `onChange` under the pushed settings screen, so the pre-#1415
/// editor saved a name typed there at once and a test hosted that way passed on it. The host can open that screen,
/// type into its fields and go back, through UIKit: the list's own delegate calls for a row tap, `insertText` for the
/// keyboard, and the navigation controller's pop for Back.
@MainActor
private final class RealEditorHost {
    /// The window hosting the editor; `nil` once closed.
    private var window: UIWindow?

    /// Hosts the editor over `collection`, which `container` holds — pushed at a compact width when `pushed` is set.
    init(collection: Collection, container: ModelContainer, appState: AppState, pushed: Bool = false) throws {
        let scene = try #require(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first,
            "The test host has no window scene to host the editor in")
        let presented = pushed
            ? AnyView(PushedEditorRoot(collection: collection).environment(\.horizontalSizeClass, .compact))
            : AnyView(CollectionEditorView(collection: collection))
        let editor = presented
            .environment(appState)
            .modelContainer(container)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(rootView: editor)
        window.isHidden = false
        window.layoutIfNeeded()
        self.window = window
    }

    /// The editor's navigation-bar title, as UIKit shows it — once a screen is pushed over the editor, that screen's.
    var title: String? {
        window.flatMap { Self.navigationBarTitle(in: $0) }
    }

    private static func navigationBarTitle(in view: UIView) -> String? {
        if let bar = view as? UINavigationBar, let title = bar.topItem?.title { return title }
        for subview in view.subviews {
            if let title = navigationBarTitle(in: subview) { return title }
        }
        return nil
    }

    /// Opens Collection settings the way a tap on its row does, on the compact layout: the row is the first in the
    /// editor's list, and the host makes the calls UIKit makes for a tap — should-select, select, did-select, then
    /// the primary action — through the list's own delegate, once any push that brought the editor has finished.
    /// Returns whether the settings screen came up.
    func openSettings() async -> Bool {
        guard let window else { return false }
        let row = IndexPath(item: 0, section: 0)
        let ready = await Self.settle {
            Self.navigationController(from: window.rootViewController)?.transitionCoordinator == nil
                && Self.all(UICollectionView.self, in: window).first.map {
                    $0.numberOfSections > 0 && $0.numberOfItems(inSection: 0) > 0
                } ?? false
        }
        guard ready, let list = Self.all(UICollectionView.self, in: window).first,
              let delegate = list.delegate else { return false }
        if delegate.collectionView?(list, shouldSelectItemAt: row) ?? true {
            list.selectItem(at: row, animated: false, scrollPosition: [])
            delegate.collectionView?(list, didSelectItemAt: row)
        }
        delegate.collectionView?(list, performPrimaryActionForItemAt: row)
        return await Self.settle { self.title == "Collection settings" }
    }

    /// The text field anywhere in the window whose placeholder is `placeholder`.
    func textField(placeholder: String) -> UITextField? {
        window.flatMap { Self.all(UITextField.self, in: $0).first { $0.placeholder == placeholder } }
    }

    /// Types `text` at the end of `field`, as the keyboard does. Returns whether the field took focus.
    func type(_ text: String, into field: UITextField) -> Bool {
        window?.makeKey()
        guard field.becomeFirstResponder() else { return false }
        field.selectedTextRange = field.textRange(from: field.endOfDocument, to: field.endOfDocument)
        field.insertText(text)
        return true
    }

    /// The multi-line text view anywhere in the window whose text is `text` — a `TextField(axis: .vertical)` is drawn
    /// by one, as the collection's description is.
    func textView(holding text: String) -> UITextView? {
        window.flatMap { Self.all(UITextView.self, in: $0).first { $0.text == text } }
    }

    /// Types `text` at the end of `textView`, as the keyboard does. Returns whether the view took focus.
    func type(_ text: String, into textView: UITextView) -> Bool {
        window?.makeKey()
        guard textView.becomeFirstResponder() else { return false }
        textView.selectedRange = NSRange(location: (textView.text as NSString).length, length: 0)
        textView.insertText(text)
        return true
    }

    /// Goes back from the screen pushed over the editor, as its Back button does. Returns whether the editor's own
    /// title came back.
    func goBack() async -> Bool {
        guard let window, let stack = Self.navigationController(from: window.rootViewController) else { return false }
        stack.popViewController(animated: false)
        return await Self.settle { self.title != nil && self.title != "Collection settings" }
    }

    /// Every `View` in `view`'s tree, `view` included, outermost first.
    private static func all<View: UIView>(_ type: View.Type, in view: UIView) -> [View] {
        var found: [View] = []
        if let match = view as? View { found.append(match) }
        for subview in view.subviews { found += all(type, in: subview) }
        return found
    }

    /// The first navigation controller at or under `controller`, following children and then presentations.
    private static func navigationController(from controller: UIViewController?) -> UINavigationController? {
        guard let controller else { return nil }
        if let stack = controller as? UINavigationController { return stack }
        for child in controller.children {
            if let stack = navigationController(from: child) { return stack }
        }
        return navigationController(from: controller.presentedViewController)
    }

    /// Pumps the main run loop until `condition` holds or 5 s pass, and reports whether it held.
    private static func settle(until condition: () -> Bool) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(5))
        while clock.now < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    /// Ends any editing a test began (so no field typed into is left first responder), takes the window down, and
    /// waits for the hosting controller to deallocate. Returns whether it went.
    func close() async -> Bool {
        weak let controller = window?.rootViewController
        window?.endEditing(true)
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(2))
        while controller != nil, clock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        return controller == nil
    }
}

/// A navigation stack that pushes `CollectionEditorView` over its root as soon as it appears, with the `.pushed`
/// presentation — how `CollectionListView` shows the editor on iOS (`.navigationDestination(isPresented:)`).
private struct PushedEditorRoot: View {
    /// The collection the pushed editor edits.
    let collection: Collection
    /// Whether the editor is pushed; set once the stack has appeared.
    @State private var showsEditor = false

    var body: some View {
        NavigationStack {
            Color.clear
                .navigationTitle("Collections")
                .navigationDestination(isPresented: $showsEditor) {
                    CollectionEditorView(collection: collection, presentationStyle: .pushed)
                }
                .task { showsEditor = true }
        }
    }
}
#endif

// MARK: - ListExportTests (#1371)

/// The DOCX and PDF exporters read the same `.listBlock` the reader does, and both hard-coded a
/// `"• "` where the volume printed `(1)`, `2.` or `a.` (#1371). They now print the label, the
/// list's heading, and the other children of `<list>` the converter keeps — without letting any
/// of that text advance the highlight tracker, which counts only the flat text.
///
/// The DOCX package is written stored (uncompressed), so `word/document.xml` is searchable in
/// the archive bytes; the PDF is read back through PDFKit.
@Suite("List heads and labels in DOCX and PDF exports (#1371)")
struct ListExportTests {

    /// Exports `model` as one collection document and returns the DOCX package bytes as text.
    private func docxText(_ model: FRUSDocumentRenderModel,
                          highlights: [ExportHighlight] = []) async throws -> String {
        let doc = CollectionExportDocument(
            documentId: model.documentId, volumeId: "frus1961-63v05", sortOrder: 1,
            title: "Memorandum of Conversation", bodyText: "", renderModel: model,
            highlights: highlights)
        var options = CollectionExportOptions()
        options.applyHighlights = !highlights.isEmpty
        let url = try await DocxCollectionExporter().export(
            metadata: CollectionExportMetadata(name: "Lists", note: nil),
            items: [.document(doc)], options: options)
        return String(decoding: try Data(contentsOf: url), as: UTF8.self)
    }

    /// Exports `model` as one collection document and returns the PDF's page text.
    private func pdfText(_ model: FRUSDocumentRenderModel) async throws -> String {
        let doc = CollectionExportDocument(
            documentId: model.documentId, volumeId: "frus1961-63v05", sortOrder: 1,
            title: "Memorandum of Conversation", bodyText: "", renderModel: model)
        let url = try await PDFCollectionExporter().export(
            metadata: CollectionExportMetadata(name: "Lists", note: nil), items: [.document(doc)])
        let pdf = try #require(PDFDocument(data: try Data(contentsOf: url)))
        return (0..<pdf.pageCount).compactMap { pdf.page(at: $0)?.string }.joined(separator: "\n")
    }

    /// The `<w:p>…</w:p>` paragraph of `xml` that contains `needle`.
    private func paragraph(containing needle: String, in xml: String) throws -> String {
        let hit = try #require(xml.range(of: needle), "\"\(needle)\" is not in document.xml")
        let open = try #require(xml.range(of: "<w:p>", options: .backwards,
                                           range: xml.startIndex..<hit.lowerBound))
        let close = try #require(xml.range(of: "</w:p>", range: hit.upperBound..<xml.endIndex))
        return String(xml[open.lowerBound..<close.upperBound])
    }

    /// d84's labelled list sits inside a `<p>`, which Word cannot hold; the exporter splits the
    /// paragraph around it (`paragraphsDocx`), so its six labels print too. `everyChild`'s list
    /// is a direct child of the document; d84's two headed lists are direct children too.
    @Test("DOCX prints each printed label where the bullet was, and the list's heading")
    func docxPrintsLabelsAndHeadings() async throws {
        let d84 = try await docxText(try await ListShapeFixtures.renderModel(ListShapeFixtures.d84))
        #expect(d84.contains("SUBJECT"))
        #expect(d84.contains("PARTICIPANTS:"))
        // The two unlabelled items (SUBJECT's and PARTICIPANTS') keep their bullet.
        let subject = try paragraph(containing: "Vienna Meeting Between", in: d84)
        #expect(subject.contains("•"))
        // The labelled list inside the paragraph: the paragraph's own words, then each item.
        let lead = try paragraph(containing: "During lunch the conversation", in: d84)
        #expect(!lead.contains("During the discussion"), "the list must not print as runs of the paragraph: \(lead)")
        for (label, words) in [("(1)", "During the discussion"), ("(2)", "In discussing agricultural"),
                               ("(3)", "With reference to Gagarin"), ("(6)", "In response to the toast")] {
            let para = try paragraph(containing: words, in: d84)
            let labelAt = try #require(para.range(of: ">\(label)<"), "\(label) is not in the paragraph of \"\(words)\"")
            let wordsAt = try #require(para.range(of: words))
            #expect(labelAt.lowerBound < wordsAt.lowerBound, "\(label) must precede its item")
        }

        let xml = try await docxText(try await ListShapeFixtures.renderModel(ListShapeFixtures.everyChild))
        #expect(xml.contains("Recommendations:"))
        for (label, words) in [("a.", "First item text."), ("b.", "Second item text."),
                               ("c", "Third item text.")] {
            let para = try paragraph(containing: words, in: xml)
            let labelAt = try #require(para.range(of: ">\(label)<"), "\(label) is not in the paragraph of \"\(words)\"")
            let wordsAt = try #require(para.range(of: words))
            #expect(labelAt.lowerBound < wordsAt.lowerBound, "\(label) must precede its item")
            #expect(!para.contains("•"), "a labelled item must not also carry a bullet: \(para)")
        }
    }

    @Test("PDF prints each printed label before its item, and the list's heading")
    func pdfPrintsLabelsAndHeadings() async throws {
        let model = try await ListShapeFixtures.renderModel(ListShapeFixtures.d84)
        let text = try await pdfText(model)
        for printed in ["SUBJECT", "PARTICIPANTS:", "(1) During the discussion",
                        "(2) In discussing agricultural", "(6) In response to the toast"] {
            #expect(text.contains(printed), "the PDF does not print \"\(printed)\"")
        }
        #expect(!text.contains("• (1)") && !text.contains("•(1)"))
    }

    @Test("Every other list child prints in DOCX and PDF, and a page break between items does not split the list in Word")
    func everyListChildPrints() async throws {
        let model = try await ListShapeFixtures.renderModel(ListShapeFixtures.everyChild)
        let xml = try await docxText(model)
        for printed in ["Recommendations:", "By desire and on behalf of the meeting:",
                        ">a.<", ">b.<", "Henry A. Kissinger", "[Figure: figure_0732]"] {
            #expect(xml.contains(printed), "DOCX does not print \(printed)")
        }
        // Two <pb/>s sit between items b. and c. A page break inside an item has always been
        // silent in Word; one between items stays silent too rather than breaking a numbered
        // list. (The package has page breaks of its own — after the cover — so the check is
        // scoped to the list.)
        let second = try #require(xml.range(of: "Second item text."))
        let third = try #require(xml.range(of: "Third item text."))
        #expect(second.upperBound < third.lowerBound)
        let between = xml[second.upperBound..<third.lowerBound]
        #expect(between.contains("[Figure: figure_0732]"), "the figure between the page breaks must print")
        #expect(!between.contains("<w:br w:type=\"page\"/>"), "a <pb/> between two items broke the page: \(between)")
        let text = try await pdfText(model)
        for printed in ["Recommendations:", "By desire and on behalf of the meeting:",
                        "Henry A. Kissinger", "First item text."] {
            #expect(text.contains(printed), "the PDF does not print \"\(printed)\"")
        }
    }

    /// Before "Second item text." the list draws a heading, a salute, two labels, a line break and
    /// two footnote markers, none of it flat text; if any of it advanced the tracker the painted
    /// run would start early.
    @Test("A highlight over a labelled item paints exactly that item's words in DOCX")
    func docxHighlightIgnoresLabelsAndHeadings() async throws {
        let model = try await ListShapeFixtures.renderModel(ListShapeFixtures.everyChild)
        let flat = buildFlatText(from: model)
        let target = "Second item text."
        let range = try #require(flat.range(of: target))
        let start = flat.utf16.distance(from: flat.utf16.startIndex, to: range.lowerBound)
        let xml = try await docxText(model, highlights: [
            ExportHighlight(startOffset: start, endOffset: start + target.utf16.count, color: .yellow)
        ])
        let runs = xml.matches(of: /<w:highlight w:val="yellow"\/><\/w:rPr><w:t xml:space="preserve">([^<]*)<\/w:t>/)
        let painted = runs.map { String($0.output.1) }.joined()
        #expect(painted == target,
                "the tracker counted text outside the flat text: painted \"\(painted)\"")
    }

    /// PDFKit reads a page's text back but not the rectangles drawn behind it, so this reads the
    /// shading from `bodyAttributedString` — the step the export itself calls.
    @Test("A highlight over a labelled item shades exactly that item's words in PDF")
    @MainActor
    func pdfHighlightIgnoresLabelsAndHeadings() async throws {
        let model = try await ListShapeFixtures.renderModel(ListShapeFixtures.everyChild)
        let flat = buildFlatText(from: model)
        let target = "Second item text."
        let range = try #require(flat.range(of: target))
        let start = flat.utf16.distance(from: flat.utf16.startIndex, to: range.lowerBound)
        let body = PDFCollectionExporter().bodyAttributedString(
            for: model,
            highlights: [ExportHighlight(startOffset: start, endOffset: start + target.utf16.count, color: .yellow)],
            includeFootnotes: false)
        var painted = ""
        body.enumerateAttribute(PDFCollectionExporter.highlightAttrKey,
                                in: NSRange(location: 0, length: body.length)) { value, range, _ in
            if value != nil { painted += (body.string as NSString).substring(with: range) }
        }
        #expect(painted == target,
                "the tracker counted text outside the flat text: shaded \"\(painted)\"")
        // The body still prints what the tracker skipped. (Label a. carries a footnote marker,
        // so it prints as "a.2 ".)
        for printed in ["Recommendations:", "b. ", "c. ", "Henry A. Kissinger"] {
            #expect(body.string.contains(printed), "the PDF body does not print \"\(printed)\"")
        }
    }

    /// After the last item come a gap and a closer, drawn but not flat text. A highlight on the
    /// paragraph after the list is the one they could drag onto themselves.
    @Test("A highlight after a list's closing children shades exactly its own words in PDF")
    @MainActor
    func pdfHighlightAfterTheListIgnoresItsTrailingChildren() async throws {
        let model = try await ListShapeFixtures.renderModel(ListShapeFixtures.everyChild)
        let flat = buildFlatText(from: model)
        let target = "Closing paragraph."
        let range = try #require(flat.range(of: target))
        let start = flat.utf16.distance(from: flat.utf16.startIndex, to: range.lowerBound)
        let body = PDFCollectionExporter().bodyAttributedString(
            for: model,
            highlights: [ExportHighlight(startOffset: start, endOffset: start + target.utf16.count, color: .yellow)],
            includeFootnotes: false)
        #expect(body.string.contains("Henry A. Kissinger"), "the closer after the last item must print")
        var painted = ""
        body.enumerateAttribute(PDFCollectionExporter.highlightAttrKey,
                                in: NSRange(location: 0, length: body.length)) { value, range, _ in
            if value != nil { painted += (body.string as NSString).substring(with: range) }
        }
        #expect(painted == target, "the tracker counted the list's closing children: shaded \"\(painted)\"")
    }

    /// The text each Word highlight colour shades, in document order.
    private func docxPainted(_ xml: String) -> [String: String] {
        var painted: [String: String] = [:]
        for match in xml.matches(of: /<w:highlight w:val="([a-z]+)"\/><\/w:rPr><w:t xml:space="preserve">([^<]*)<\/w:t>/) {
            painted[String(match.output.1), default: ""] += String(match.output.2)
        }
        return painted
    }

    /// Exports `model` with one highlight per `(text, colour)` over that text's flat-text range.
    private func docxText(_ model: FRUSDocumentRenderModel,
                          marking marks: [(String, DocumentHighlight.Color)]) async throws -> String {
        let flat = buildFlatText(from: model)
        let highlights = try marks.map { text, color in
            let range = try #require(flat.range(of: text), "\"\(text)\" is not in the flat text")
            let start = flat.utf16.distance(from: flat.utf16.startIndex, to: range.lowerBound)
            return ExportHighlight(startOffset: start, endOffset: start + text.utf16.count, color: color)
        }
        return try await docxText(model, highlights: highlights)
    }

    /// Outside footnote bodies, 33,572 `<p>`s and 38,372 lists sit directly in an `<item>` in the
    /// corpus. Word printed an item through runs, whose block arm printed nothing and left the
    /// highlight tracker behind, so such an item printed as its bare label and every highlight
    /// after it moved. (A footnote body still prints as one paragraph of runs, and the list
    /// holding such an item prints nothing there: #1414.)
    @Test("An item's own paragraphs and a list nested in an item print in Word, and a highlight after them keeps its words")
    func docxPrintsAnItemsParagraphsAndNestedList() async throws {
        let model = try await ListShapeFixtures.renderModel("""
        <div type="document" xml:id="d1">
          <p>Opening paragraph.</p>
          <list>
            <label>(1)</label>
            <item>First point.</item>
            <label>(2)</label>
            <item><p>Second point, first paragraph.</p><p>Second point, second paragraph.</p></item>
            <label>(3)</label>
            <item>Third point:<list><label>(a)</label><item>Nested point.</item></list></item>
          </list>
          <p>Closing paragraph.</p>
        </div>
        """)
        let xml = try await docxText(model, marking: [("Second point, second paragraph.", .yellow),
                                                      ("Nested point.", .green),
                                                      ("Closing paragraph.", .blue)])
        // The label opens the item's first paragraph; the item's second paragraph is its own,
        // indented as the item is; the nested list is indented a step further.
        let first = try paragraph(containing: "Second point, first paragraph.", in: xml)
        #expect(first.contains(">(2)<") && first.contains("<w:ind w:left=\"360\"/>"), "\(first)")
        let second = try paragraph(containing: "Second point, second paragraph.", in: xml)
        #expect(!second.contains("(2)") && second.contains("<w:ind w:left=\"360\"/>"), "\(second)")
        #expect(try paragraph(containing: "Third point:", in: xml).contains(">(3)<"))
        let nested = try paragraph(containing: "Nested point.", in: xml)
        #expect(nested.contains(">(a)<") && nested.contains("<w:ind w:left=\"720\"/>"), "\(nested)")
        #expect(docxPainted(xml) == ["yellow": "Second point, second paragraph.",
                                     "green": "Nested point.", "cyan": "Closing paragraph."],
                "a highlight shaded the wrong words: \(docxPainted(xml))")
    }

    /// Outside footnote bodies, 53,759 lists sit directly in a `<p>` and 91,332 `<p>`s in a
    /// `<quote>` inside one. Word cannot put either inside a paragraph, so a body paragraph is
    /// split around them — and the words after them, in the same `<p>` and after it, keep their
    /// highlights. A footnote body is not split: it still prints as one paragraph of runs, so a
    /// list inside it, or a paragraph quoted inside the note's own `<p>`, prints nothing (#1414).
    /// (A paragraph quoted directly in the note, with no `<p>` of the note's around it, prints,
    /// run into the note's one paragraph.)
    @Test("A list or quoted paragraphs inside a paragraph print in Word, and highlights after them keep their words")
    func docxPrintsBlocksInsideAParagraph() async throws {
        let model = try await ListShapeFixtures.renderModel("""
        <div type="document" xml:id="d1">
          <p>The points were these: <list>
              <label>(1)</label><item>First point.</item>
              <label>(2)</label><item>Second point.</item>
            </list> and nothing more.</p>
          <p>He wrote: <quote><p>Quoted first.</p><p>Quoted second.</p></quote></p>
          <p>Before a bare figure <figure/> and after it.</p>
          <p>Closing paragraph.</p>
        </div>
        """)
        let xml = try await docxText(model, marking: [("Second point.", .yellow), ("nothing more.", .green),
                                                      ("Quoted second.", .blue), ("Closing paragraph.", .pink)])
        let opening = try paragraph(containing: "The points were these:", in: xml)
        #expect(!opening.contains("First point."), "the list must be split out of the paragraph: \(opening)")
        for (label, words) in [("(1)", "First point."), ("(2)", "Second point.")] {
            #expect(try paragraph(containing: words, in: xml).contains(">\(label)<"), "\(label) is not beside \(words)")
        }
        let after = try paragraph(containing: "nothing more.", in: xml)
        #expect(!after.contains("Second point."), "the words after the list must open a paragraph of their own: \(after)")
        #expect(!(try paragraph(containing: "Quoted second.", in: xml)).contains("Quoted first."),
                "each quoted paragraph is a paragraph")
        // A figure with no graphic prints nothing, so it must not split its paragraph in two.
        #expect(try paragraph(containing: "Before a bare figure", in: xml).contains("and after it."),
                "a block that prints nothing split its paragraph")
        #expect(docxPainted(xml) == ["yellow": "Second point.", "green": "nothing more.",
                                     "cyan": "Quoted second.", "magenta": "Closing paragraph."],
                "a highlight shaded the wrong words: \(docxPainted(xml))")
    }

    /// A paragraph a split opens begins with its words (#1371 review, round 2). Whitespace
    /// normalisation keeps one space where the TEI had whitespace before a text node, so the words
    /// after a list or a quote in a `<p>` begin with it (" thereafter", " then"); opening a Word
    /// paragraph of their own, it printed as a visible indent. The exporter trims it from the
    /// paragraph's first run only, after the tracker has counted it: a highlight on the first word
    /// after the block, or one that starts on the trimmed space itself, shades exactly its words,
    /// and the highlight after both still keeps its own.
    @Test("The words after a block that splits a paragraph open their Word paragraph without a leading space, and their highlights keep their words")
    func docxTrimsTheSpaceThatOpensASplitParagraph() async throws {
        let model = try await ListShapeFixtures.renderModel("""
        <div type="document" xml:id="d1">
          <p>The points were these: <list>
              <label>(1)</label><item>First point.</item>
            </list> thereafter nothing more.</p>
          <p>He wrote: <quote><p>Quoted words.</p></quote> then stopped short.</p>
          <p>Closing paragraph.</p>
        </div>
        """)
        // "thereafter" is the first word after the list; " then" starts on the space itself.
        let xml = try await docxText(model, marking: [("thereafter", .yellow), (" then", .green),
                                                      ("Closing paragraph.", .blue)])
        // Checked first: a tracker out of step splits the words the lookups below search for.
        #expect(docxPainted(xml) == ["yellow": "thereafter", "green": "then", "cyan": "Closing paragraph."],
                "a highlight shaded the wrong words: \(docxPainted(xml))")
        func printed(_ para: String) -> String {
            para.matches(of: /<w:t(?: xml:space="preserve")?>([^<]*)<\/w:t>/).map { String($0.output.1) }.joined()
        }
        let afterList = printed(try paragraph(containing: "nothing more.", in: xml))
        #expect(afterList == "thereafter nothing more.", "the paragraph after the list prints \"\(afterList)\"")
        let afterQuote = printed(try paragraph(containing: "stopped short.", in: xml))
        #expect(afterQuote == "then stopped short.", "the paragraph after the quote prints \"\(afterQuote)\"")
        // Only a split paragraph's opening space goes: the paragraph before the block keeps the
        // space it ends on, and the spaces between words stay. That paragraph opens on a word in
        // this fixture, so nothing here would see a trim of a leading space of its own.
        let before = printed(try paragraph(containing: "The points were these:", in: xml))
        #expect(before == "The points were these: ", "the paragraph before the list prints \"\(before)\"")
        #expect(!xml.contains("<w:t xml:space=\"preserve\"></w:t>"), "a run that held only the space printed empty")
    }

    /// Outside footnote bodies, a table cell directly holds a `<p>`, a list or a table 1,136 times
    /// in the corpus. A Word cell may hold several paragraphs and a table, but must end in a paragraph.
    @Test("A cell's paragraphs, list and nested table print in Word, and a highlight after the table keeps its words")
    func docxPrintsBlocksInsideATableCell() async throws {
        let model = try await ListShapeFixtures.renderModel("""
        <div type="document" xml:id="d1">
          <table><row><cell>Plain cell</cell><cell><p>Cell paragraph.</p><list><item>Cell item.</item></list></cell><cell><table><row><cell>Inner cell</cell></row></table></cell></row></table>
          <p>Closing paragraph.</p>
        </div>
        """)
        let xml = try await docxText(model, marking: [("Cell item.", .yellow), ("Closing paragraph.", .green)])
        for printed in ["Plain cell", "Cell paragraph.", "Cell item.", "Inner cell"] {
            #expect(xml.contains(printed), "the table does not print \(printed)")
        }
        #expect(xml.contains("</w:tbl>\n<w:p/></w:tc>"), "a cell ending in a table must still end in a paragraph")
        #expect(docxPainted(xml) == ["yellow": "Cell item.", "green": "Closing paragraph."],
                "a highlight shaded the wrong words: \(docxPainted(xml))")
    }

    @Test("A label with no item after it prints in DOCX, in a paragraph after the list")
    func docxPrintsATrailingLabel() async throws {
        let model = try await ListShapeFixtures.renderModel("""
        <div type="document" xml:id="d1">
          <list><label>1.</label><item>One.</item><label>2.</label></list>
        </div>
        """)
        let xml = try await docxText(model)
        let para = try paragraph(containing: ">2.<", in: xml)
        #expect(!para.contains("One."), "the dangling label must print in a paragraph of its own: \(para)")
    }
}

// MARK: - FootnoteBlockDocxTests (#1414)

/// Real footnotes that hold a block, for `FootnoteBlockDocxTests` (#1414).
///
/// Each `<note>` is copied from its volume at corpus `550a8c5c5` with its markup intact and only its indentation
/// changed; `opensWithTable` keeps three of its table's twenty rows. Each sits in a document cut down to its heading
/// (the heading's own notes removed) and the paragraph, heading or item that carries the marker, whose prose is cut
/// before and after the note. The documents keep their `@n` and `xml:id`, and drop the `frus:doc-dateTime` attributes.
///
/// Measured over the 553 manifest volumes, counting every `<note>` inside a `div[@type="document"]` (a note nested in a
/// note counted on its own, its content excluded from the outer note's): 2,076 `<p>`s sit in a `<quote>` inside a
/// `<p>` of a note, in 941 documents; notes hold 566 outermost lists (142 labelled) in 491 documents and 61 outermost
/// tables in 52 documents — 1,571 notes, in 1,409 documents, hold at least one of the three. 8,342 notes, in 7,726
/// documents, have two or more `<p>`s of their own, and 1,069 more have one `<p>` beside words or elements of the
/// note's own. 154 more quoted `<p>`s sit in a `<quote>` directly in a note (148) or in a `<cit>` there (6, in 3 notes),
/// in 65 notes with no `<p>` of their own.
enum FootnoteBlockFixtures {

    /// `frus1940v05/d16` fn 32: a note whose `<p>` quotes two paragraphs — the commonest shape #1414 names.
    static let quotedParagraphs = """
    <div type="document" subtype="historical-document" n="16" xml:id="d16">
      <head><hi rend="italic">The Under Secretary of State</hi> (<persName type="from"><hi rend="italic">Welles</hi></persName>) <hi rend="italic">to President <persName type="to">Roosevelt</persName></hi></head>
      <p><hi rend="smallcaps">Dear Mr. President</hi>: As Chairman of the Liaison Committee, and with the full concurrence of the other members, Admiral Stark and General Marshall,<note n="32"
            xml:id="d16fn1"><p>Following notations appear at end of
                letter: <quote rend="blockquote">
                    <p>“I recommend this action. G. C. Marshall.”</p>
                    <p>“I concur H. R. Stark.”</p></quote></p></note></p>
    </div>
    """

    /// `frus1930v01/d215` fn 22: a labelled list inside the note's `<p>`, the note itself in an item of a labelled list.
    static let labelledList = """
    <div type="document" subtype="historical-document" n="215" xml:id="d215">
      <head><hi rend="italic">Protocol Relating to Military Obligations in Certain Cases of Double Nationality, Signed at The Hague, April 12, 1930</hi></head>
      <list>
        <item><hi rend="italic">The Netherlands</hi></item>
        <item>Les Pays-Bas: <list>
                <label>1°</label>
                <item>Excluent de leur acceptation Particle 3;</item>
                <label>2°</label>
                <item>N’entendent assumer aucune obligation en ce qui
                    concerne les Indes néerlandaises, le Surinam et
                        Curaçao.<note n="22" xml:id="d215fn22"
                          ><p>Translation: The Netherlands: <list>
                          <label>1.</label>
                          <item>Exclude from acceptance Article 3;</item>
                          <label>2.</label>
                          <item>Do not intend to assume any obligation as
                          regards Netherlands Indies, Surinam and
                          Curaçao.</item>
                          </list></p></note>
                    <list>
                        <item><hi rend="smallcaps">v. Eysinga</hi></item>
                        <item><hi rend="smallcaps">J. Kosters</hi></item>
                    </list></item>
            </list></item>
      </list>
    </div>
    """

    /// `frus1919Parisv03/d1` fn *: a table inside the note's first `<p>`, then a second `<p>`.
    static let tableThenParagraph = """
    <div type="document" subtype="historical-document" n="1" xml:id="d1">
      <head>PART I. Composition of the Conference</head>
      <p rend="center">UNITED STATES OF AMERICA<note n="*" xml:id="d1fn1"><p>Index
                of abbreviations: <table cols="2" rows="2">
                    <row>
                        <cell>U. S. A.</cell>
                        <cell>United States Army.</cell>
                    </row>
                    <row>
                        <cell>U. S. N.</cell>
                        <cell>United States Navy.</cell>
                    </row>
                </table></p>
            <p>[Footnote in the original.]</p></note></p>
    </div>
    """

    /// `frus1946v02/d210` fn 44: two `<p>`s, the second ending in a table — so the note ends in a table, one of 21 in
    /// the manifest volumes that do.
    static let endsInTable = """
    <div type="document" subtype="historical-document" n="210" xml:id="d210">
      <head><hi rend="italic">United States Delegation Record, Council of Foreign Ministers, Second Session, Twenty-Eighth Meeting, Palais du Luxembourg, Paris, June 27, 1946, 4 p.m.</hi></head>
      <p>6. The Bulgarian Navy (<gloss target="#t_CFM461">CFM (46)</gloss> 155<note
            n="44" xml:id="d210fn44"><p>Dated June 26, this document (<gloss
                    target="#t_CFM1">C.F.M.</gloss> Files, Lot M–88, Box 2063,
                    <gloss target="#t_CFM1">CFM</gloss> Documents) set forth the 7th
                Report of the Naval Committee which read, in full, as follows:</p>
            <p>“With reference to the naval limitations to be imposed on Bulgaria,
                the Naval Committee have agreed to recommend as follows: <table
                    cols="2" rend="width: 50%" rendition="#center-block" rows="2">
                    <row>
                        <cell>Tonnage limitation</cell>
                        <cell role="num">7250</cell>
                        <cell>tons</cell>
                    </row>
                    <row>
                        <cell>Personnel limitation</cell>
                        <cell role="num">3500.</cell>
                        <cell>”</cell>
                    </row>
                </table></p></note></p>
    </div>
    """

    /// `frus1969-76v41/d86` fn 7: a note that OPENS with a table (with a `<head>`), then a `<p>` — one of 8 notes in the
    /// manifest volumes that open with a table, and 5 with a list. Three of the table's twenty rows are kept.
    static let opensWithTable = """
    <div type="document" subtype="historical-document" n="86" xml:id="d86">
      <head>86. National Intelligence Estimate</head>
      <p>the <gloss target="#t_EC_1">EC</gloss> as a unit means more to the
            other (non-member) European economies than does the US.<note n="7"
            xml:id="d86fn7">
            <table>
                <head>SELECTED COUNTRIES’ TRADE WITH THE US AND THE <gloss
                        target="#t_EC_1">EC</gloss> OF NINE* </head>
                <row>
                    <cell>Country</cell>
                    <cell>Percent of Exports to the US</cell>
                    <cell>Percent of Imports from the US</cell>
                    <cell>Percent of Exports to <gloss target="#t_EC_1"
                            >EC</gloss> of Nine</cell>
                    <cell>Percent of Imports from <gloss target="#t_EC_1"
                            >EC</gloss> of Nine</cell>
                </row>
                <row>
                    <cell>Germany</cell>
                    <cell role="num">10</cell>
                    <cell role="num">13</cell>
                    <cell role="num">47</cell>
                    <cell role="num">57</cell>
                </row>
                <row>
                    <cell>Spain</cell>
                    <cell role="num">15</cell>
                    <cell role="num">16</cell>
                    <cell role="num">47</cell>
                    <cell role="num">42</cell>
                </row>
            </table>
            <p>*All data are for calendar year 1971. [Footnote is in the
                original.]</p>
        </note></p>
    </div>
    """

    /// `frus1955-57v07/d354` fn 11: words directly in the note, then a `<p>`, an unlabelled list and another `<p>` — a
    /// note whose blocks are its own children, with no `<p>` of the note around them.
    static let runsThenBlocks = """
    <div type="document" subtype="historical-document" n="354" xml:id="d354">
      <head>354. National Intelligence Estimate</head>
      <p>Present coffee shipments are moving at a higher rate than in
            1954 and 1955, and prices have risen somewhat above 1955 levels.<note
            n="11" xml:id="d354fn11"><hi rend="underline">Average Coffee Prices
                Table:</hi> (Santos 4’s)<p>July 1954 - 88¢</p>
            <list>
                <item>February 1955 - 54¢</item>
                <item>February 1956 - 58¢</item>
                <item>December 1956 - 60¢</item>
            </list>
            <p>[Footnote in the source text.]</p></note></p>
    </div>
    """

    /// `frus1948v08/d854` fn 10: a note of two `<p>`s, written with nothing between them, and no block — one of the
    /// 8,342 notes with two or more `<p>`s of their own. The note is in the document's heading.
    static let twoParagraphs = """
    <div type="document" subtype="historical-document" n="854" xml:id="d854">
      <head><hi rend="italic">The <gloss type="from">Acting Secretary of State</gloss> to the Secretary of the Navy</hi> (<persName type="to"><hi rend="italic">Sullivan</hi></persName>)<note n="10"
            xml:id="d854fn10"><p>Marginal notation by the Chief of the Division
                of Chinese Affairs (Sprouse):</p><p>“This letter has been
                cleared by Mr. Lovett with the President and the N[ational]
                S[ecurity] C[ouncil], 12–10–48.”</p></note></head>
    </div>
    """

    /// `frus1945Berlinv02/d710a-13` fn 6: a `<quote>` of two paragraphs directly in a note that has no `<p>` of its own
    /// — one of the 65 such notes, whose 154 quoted `<p>`s #1414's own count of quoted paragraphs leaves out.
    static let quoteInTheNote = """
    <div type="document" subtype="historical-document" n="[Unnumbered document following Document 710 (#13)]"
         xml:id="d710a-13">
      <head><hi rend="italic">Rapporteur’s Report</hi></head>
      <p>especially the arrangements for the early holding of free and unfettered elections.<note n="6"
            xml:id="d710a-13fn6">Following this
                paragraph are the following manuscript notations by <persName
                    corresp="#p_THS1">Truman</persName>: <quote
                    rend="blockquote">
                    <p>“Poles should go back to Poland.”</p>
                    <p>“Agreed to for change in Soviet wording.”</p>
                </quote></note></p>
    </div>
    """
}

/// A footnote in a Word export prints every block it holds (#1414).
///
/// `DocxCollectionExporter` wrote each note as ONE `FootnoteText` paragraph of runs, and a block in a run context
/// prints nothing there — so a paragraph quoted in a note, a list or a table in one, vanished from `word/footnotes.xml`
/// while HTML and PDF printed it, and a note's own paragraphs ran together into one. Eight tests export one real note
/// (`FootnoteBlockFixtures`) through the real exporter; three export a note of their own, each saying why in its doc.
/// Every test reads the printed footnote back out of the package, which the exporter writes stored (uncompressed), so
/// the part is searchable in the archive bytes.
///
/// `printed` trims each paragraph's text, so the tests that read paragraphs through it cannot see a space at either end
/// of one. The spacing is pinned by the two tests that compare a footnote's exact XML: `blockFreeNoteIsUnchanged` and
/// `aNotesParagraphOpensOnItsFirstWord`.
///
/// The suite runs on any destination: nothing here depends on the device.
@Suite("A footnote's quoted paragraphs, lists and tables print in Word (#1414)")
struct FootnoteBlockDocxTests {

    /// One paragraph as Word prints it.
    struct Printed: Equatable, CustomStringConvertible {
        /// The text of its runs, trimmed of the spaces either side — so a doubled or missing space at a paragraph's
        /// edge is invisible here, and only an exact-XML test can see it.
        let text: String
        /// Its paragraph style, or `nil` when it names none.
        let style: String?
        /// Whether it carries the footnote's own number (`<w:footnoteRef/>`).
        let carriesNumber: Bool
        /// Whether it is a paragraph of a table cell.
        let inTable: Bool
        /// Its left indent, in twentieths of a point, when it states one.
        let indent: String?

        /// The paragraph as a failure message prints it: its style and place, then its text.
        var description: String {
            "[\(style ?? "-")\(carriesNumber ? " #" : "")\(inTable ? " cell" : "")\(indent.map { " ind \($0)" } ?? "")] \(text)"
        }
    }

    /// Exports `documentXML` as one collection document, with footnotes on, and returns its `word/footnotes.xml` part.
    private func footnotesPart(_ documentXML: String) async throws -> String {
        let model = try await ListShapeFixtures.renderModel(documentXML)
        let doc = CollectionExportDocument(
            documentId: model.documentId, volumeId: "frus1940v05", sortOrder: 1,
            title: "Footnote fixture", bodyText: "", renderModel: model)
        var options = CollectionExportOptions()
        options.includeFootnotes = true
        // A name of its own: the tests run in parallel, and each writes a file named after its collection.
        let url = try await DocxCollectionExporter().export(
            metadata: CollectionExportMetadata(name: "Footnotes \(UUID().uuidString)", note: nil),
            items: [.document(doc)], options: options)
        defer { try? FileManager.default.removeItem(at: url) }
        let package = String(decoding: try Data(contentsOf: url), as: UTF8.self)
        let open = try #require(package.range(of: "<w:footnotes "), "the package has no word/footnotes.xml")
        let close = try #require(package.range(of: "</w:footnotes>", range: open.upperBound..<package.endIndex))
        return String(package[open.lowerBound..<close.upperBound])
    }

    /// The `<w:footnote w:id="…">…</w:footnote>` element of `part` that holds `needle`.
    private func footnote(containing needle: String, in part: String) throws -> String {
        let hit = try #require(part.range(of: needle), "\"\(needle)\" is not in word/footnotes.xml")
        let open = try #require(part.range(of: "<w:footnote w:id=", options: .backwards,
                                           range: part.startIndex..<hit.lowerBound))
        let close = try #require(part.range(of: "</w:footnote>", range: hit.upperBound..<part.endIndex))
        return String(part[open.lowerBound..<close.upperBound])
    }

    /// Every paragraph of `xml` in document order, a table's cell paragraphs at their place among the rest.
    private func printed(_ xml: String) -> [Printed] {
        var depth = 0
        var paragraphs: [Printed] = []
        for match in xml.matches(of: /<w:tbl>|<\/w:tbl>|<w:p\/>|<w:p>(.*?)<\/w:p>/.dotMatchesNewlines()) {
            switch match.output.0 {
            case "<w:tbl>": depth += 1
            case "</w:tbl>": depth -= 1
            default:
                let body = match.output.1.map(String.init) ?? ""
                let text = body.matches(of: /<w:t(?: xml:space="preserve")?>([^<]*)<\/w:t>/)
                    .map { String($0.output.1) }.joined()
                paragraphs.append(Printed(
                    text: text.trimmingCharacters(in: .whitespaces),
                    style: body.firstMatch(of: /<w:pStyle w:val="([^"]+)"\/>/).map { String($0.output.1) },
                    carriesNumber: body.contains("<w:footnoteRef/>"),
                    inTable: depth > 0,
                    indent: body.firstMatch(of: /<w:ind w:left="([0-9]+)"\/>/).map { String($0.output.1) }))
            }
        }
        return paragraphs
    }

    @Test("A paragraph quoted in a note's own paragraph prints in Word, each as a paragraph of the note")
    func quotedParagraphsPrint() async throws {
        let note = try footnote(containing: "Following notations appear",
                                in: try await footnotesPart(FootnoteBlockFixtures.quotedParagraphs))
        let paragraphs = printed(note)
        #expect(paragraphs.map(\.text) == ["Following notations appear at end of letter:",
                                           "“I recommend this action. G. C. Marshall.”",
                                           "“I concur H. R. Stark.”"],
                "\(paragraphs)")
        // The number opens the note once, on its first words.
        #expect(paragraphs.map(\.carriesNumber) == [true, false, false], "\(paragraphs)")
        #expect(paragraphs.allSatisfy { $0.style == "FootnoteText" }, "\(paragraphs)")
    }

    @Test("A labelled list in a note prints in Word, each label before its item, at the note's size")
    func labelledListPrints() async throws {
        let note = try footnote(containing: "Translation: The Netherlands:",
                                in: try await footnotesPart(FootnoteBlockFixtures.labelledList))
        let paragraphs = printed(note)
        #expect(paragraphs.map(\.text) == [
            "Translation: The Netherlands:",
            "1. Exclude from acceptance Article 3;",
            "2. Do not intend to assume any obligation as regards Netherlands Indies, Surinam and Curaçao.",
        ], "\(paragraphs)")
        #expect(paragraphs.map(\.carriesNumber) == [true, false, false], "\(paragraphs)")
        // An item is a footnote paragraph, indented as a list's item is in the body.
        #expect(paragraphs.map(\.style) == ["FootnoteText", "FootnoteText", "FootnoteText"], "\(paragraphs)")
        #expect(paragraphs.map(\.indent) == [nil, "360", "360"], "\(paragraphs)")
    }

    @Test("A table in a note prints in Word between the note's paragraphs, and the note's second paragraph is its own")
    func tableAndSecondParagraphPrint() async throws {
        let note = try footnote(containing: "Index of abbreviations:",
                                in: try await footnotesPart(FootnoteBlockFixtures.tableThenParagraph))
        let paragraphs = printed(note)
        #expect(paragraphs.map(\.text) == ["Index of abbreviations:", "U. S. A.", "United States Army.",
                                           "U. S. N.", "United States Navy.", "[Footnote in the original.]"],
                "\(paragraphs)")
        #expect(paragraphs.map(\.inTable) == [false, true, true, true, true, false], "\(paragraphs)")
        #expect(paragraphs.allSatisfy { $0.style == "FootnoteText" }, "a cell must print at the note's size: \(paragraphs)")
        #expect(note.matches(of: /<w:tbl>/).count == 1, "\(note)")
    }

    /// Word ends every story on a paragraph; a footnote whose last block is a table gets an empty one after it.
    @Test("A note that ends in a table prints the table and closes on a paragraph of its own")
    func noteEndingInATableClosesOnAParagraph() async throws {
        let note = try footnote(containing: "Report of the Naval Committee",
                                in: try await footnotesPart(FootnoteBlockFixtures.endsInTable))
        let paragraphs = printed(note)
        #expect(paragraphs.map(\.text) == [
            "Dated June 26, this document (C.F.M. Files, Lot M–88, Box 2063, CFM Documents) set forth the 7th Report of the Naval Committee which read, in full, as follows:",
            "“With reference to the naval limitations to be imposed on Bulgaria, the Naval Committee have agreed to recommend as follows:",
            "Tonnage limitation", "7250", "tons", "Personnel limitation", "3500.", "”",
            "",
        ], "\(paragraphs)")
        #expect(paragraphs.last == Printed(text: "", style: "FootnoteText", carriesNumber: false, inTable: false,
                                           indent: nil),
                "\(paragraphs)")
        let body = note.replacing(/\s*<\/w:footnote>$/, with: "")
        #expect(body.hasSuffix("</w:p>"), "the footnote must end on a paragraph: \(note)")
    }

    @Test("A note that opens with a table prints its number on a line before the table")
    func noteOpeningWithATablePrintsItsNumberFirst() async throws {
        let note = try footnote(containing: "All data are for calendar year 1971.",
                                in: try await footnotesPart(FootnoteBlockFixtures.opensWithTable))
        let paragraphs = printed(note)
        let first = try #require(paragraphs.first)
        #expect(first == Printed(text: "", style: "FootnoteText", carriesNumber: true, inTable: false, indent: nil),
                "\(paragraphs)")
        let cells = paragraphs.dropFirst().prefix(while: \.inTable).map(\.text)
        #expect(cells == ["Country", "Percent of Exports to the US", "Percent of Imports from the US",
                          "Percent of Exports to EC of Nine", "Percent of Imports from EC of Nine",
                          "Germany", "10", "13", "47", "57", "Spain", "15", "16", "47", "42"],
                "\(paragraphs)")
        #expect(paragraphs.last?.text == "*All data are for calendar year 1971. [Footnote is in the original.]",
                "\(paragraphs)")
        #expect(paragraphs.filter(\.carriesNumber).count == 1, "\(paragraphs)")
    }

    @Test("A note's own words, a paragraph and a list directly in the note each print in Word, in order")
    func runsThenBlocksPrintInOrder() async throws {
        let note = try footnote(containing: "Average Coffee Prices",
                                in: try await footnotesPart(FootnoteBlockFixtures.runsThenBlocks))
        let paragraphs = printed(note)
        #expect(paragraphs.map(\.text) == ["Average Coffee Prices Table: (Santos 4’s)", "July 1954 - 88¢",
                                           "• February 1955 - 54¢", "• February 1956 - 58¢",
                                           "• December 1956 - 60¢", "[Footnote in the source text.]"],
                "\(paragraphs)")
        #expect(paragraphs.map(\.carriesNumber) == [true, false, false, false, false, false], "\(paragraphs)")
        // The words before the first block keep their formatting.
        #expect(note.contains("<w:u w:val=\"single\"/></w:rPr><w:t xml:space=\"preserve\">Average Coffee Prices"),
                "\(note)")
    }

    /// Before #1414 the two paragraphs, written with nothing between them, printed as one: "(Sprouse):“This letter".
    @Test("A note's own paragraphs print as paragraphs of the note in Word, not run together")
    func notesOwnParagraphsStayApart() async throws {
        let note = try footnote(containing: "Marginal notation",
                                in: try await footnotesPart(FootnoteBlockFixtures.twoParagraphs))
        let paragraphs = printed(note)
        #expect(paragraphs.map(\.text) == [
            "Marginal notation by the Chief of the Division of Chinese Affairs (Sprouse):",
            "“This letter has been cleared by Mr. Lovett with the President and the N[ational] S[ecurity] C[ouncil], 12–10–48.”",
        ], "\(paragraphs)")
        #expect(paragraphs.map(\.carriesNumber) == [true, false], "\(paragraphs)")
    }

    /// The note has no `<p>` of its own, so the converter wraps its words and the `<quote>` in one paragraph, and the old
    /// footnote printed that paragraph's runs, in which each quoted `<p>` printed nothing: Truman's two notations
    /// vanished, and the note ended on "by Truman:".
    @Test("A quote of paragraphs directly in a note prints in Word, each as a paragraph of the note")
    func quoteDirectlyInTheNotePrints() async throws {
        let note = try footnote(containing: "Following this paragraph",
                                in: try await footnotesPart(FootnoteBlockFixtures.quoteInTheNote))
        let paragraphs = printed(note)
        #expect(paragraphs.map(\.text) == ["Following this paragraph are the following manuscript notations by Truman:",
                                           "“Poles should go back to Poland.”",
                                           "“Agreed to for change in Soviet wording.”"],
                "\(paragraphs)")
        #expect(paragraphs.map(\.carriesNumber) == [true, false, false], "\(paragraphs)")
        #expect(paragraphs.allSatisfy { $0.style == "FootnoteText" }, "\(paragraphs)")
    }

    /// No note in the manifest volumes holds a list head, a salute, a trailing label, a figure with a graphic, a
    /// heading, a dateline or an attachment, and none has a table in a table; this one holds them all, and a page break
    /// in its attachment, so every paragraph a block can make inside a footnote is checked for the footnote's style. It
    /// fails if any of them prints as a body paragraph, or if the page break breaks the page. It also holds a quoted
    /// paragraph beside its labelled list and its table, the three shapes #1414's triage asked to see in one note.
    @Test("Every paragraph a footnote prints in Word is a footnote paragraph, whatever block made it")
    func everyFootnoteParagraphIsFootnoteText() async throws {
        let part = try await footnotesPart("""
        <div type="document" xml:id="d1">
          <p>Body text.<note n="1" xml:id="d1fn1"><p>Lead words.<quote><p>A quoted paragraph.</p></quote></p><head>A heading in a note</head><dateline>A dateline in a note</dateline><list><head>Heads:</head><salute>By desire:</salute><label>a.</label><item>One.</item><label>b.</label></list><figure><graphic url="figure_0001"/></figure><frus:attachment><head>An attachment heading</head>Loose attachment words.<pb n="5" xml:id="pg_5"/><p>Attachment words.</p></frus:attachment><table><row><cell>Outer cell</cell><cell><table><row><cell>Inner cell</cell></row></table></cell></row></table></note></p>
        </div>
        """)
        let note = try footnote(containing: "Lead words.", in: part)
        let paragraphs = printed(note)
        // The attachment's rule is the paragraph with no words before its heading; the two empty paragraphs at
        // the end close the cell that ends in a table and the note that ends in one.
        #expect(paragraphs.map(\.text) == ["Lead words.", "A quoted paragraph.", "A heading in a note",
                                           "A dateline in a note", "Heads:", "By desire:", "a. One.", "b.",
                                           "[Figure: figure_0001]", "", "An attachment heading",
                                           "Loose attachment words.", "Attachment words.", "Outer cell", "Inner cell",
                                           "", ""],
                "\(paragraphs)")
        #expect(paragraphs.count == 17)
        #expect(paragraphs.allSatisfy { $0.style == "FootnoteText" }, "\(paragraphs)")
        // Nothing in the footnotes part is a body paragraph, and no page breaks inside a note.
        for bodyStyle in ["Normal", "Heading3", "Dateline", "AttachmentHeading"] {
            #expect(!part.contains("<w:pStyle w:val=\"\(bodyStyle)\"/>"), "a footnote printed a \(bodyStyle) paragraph")
        }
        #expect(!part.contains("<w:br w:type=\"page\"/>"), "a page break inside a note broke the page: \(note)")
        #expect(note.contains("<w:pBdr>"), "the attachment's rule did not print")
    }

    /// A control, not a guard: it passes before #1414's fix and after. A note that holds no block and one paragraph —
    /// nearly every note in the corpus — prints the exact XML it always has. It takes the same split as every other
    /// note, not a way around it: the converter wraps a note of words in one paragraph, and a paragraph is a block to
    /// `paragraphsDocx`, so this pins the split's output for the commonest note.
    @Test("A note holding no block prints in Word exactly as it always has")
    func blockFreeNoteIsUnchanged() async throws {
        let part = try await footnotesPart("""
        <div type="document" xml:id="d1">
          <p>Body text.<note n="1" xml:id="d1fn1">A plain note, with <hi rend="italic">italics</hi>.</note></p>
        </div>
        """)
        let note = try footnote(containing: "A plain note", in: part)
        #expect(note == "<w:footnote w:id=\"1\">\n"
                + "        <w:p><w:pPr><w:pStyle w:val=\"FootnoteText\"/></w:pPr>"
                + "<w:r><w:rPr><w:rStyle w:val=\"FootnoteReference\"/></w:rPr><w:footnoteRef/></w:r>"
                + "<w:r><w:t xml:space=\"preserve\"> </w:t></w:r>"
                + "<w:r><w:t xml:space=\"preserve\">A plain note, with </w:t></w:r>"
                + "<w:r><w:rPr><w:i/></w:rPr><w:t xml:space=\"preserve\">italics</w:t></w:r>"
                + "<w:r><w:t xml:space=\"preserve\">.</w:t></w:r></w:p>\n"
                + "      </w:footnote>")
    }

    /// Whitespace normalisation keeps one space where a note's text opened on whitespace, and the old footnote printed
    /// it after the space that follows the number: two spaces. Eight footnotes in the manifest volumes open that way,
    /// counting through an inline element to the first words it prints (`<persName>` excepted, since the parser strips
    /// the space at its own edge). Five are notes of bare words: one opens on the space itself (`frus1977-80v27` d113
    /// fn 7), three inside a `<hi>` (`frus1872p2v3` d5 fn 24 ` Ubi supra`, `frus1925v02` d601 fn 3 ` Ibid`,
    /// `frus1951v01` d39 fn 1 ` Ante`) and one inside a `<ref>` (`frus1969-76v41` d76 fn 4 ` Document 71`). Three
    /// open in their first `<p>` (`frus1958-60v16` d335 fn 3, d341 fn 3, d358 fn 2). Each paragraph a split opens now
    /// starts on its first word (`trimmingLeadingSpace(ofFirstRun:)`), and every shape reaches it: a note of bare words
    /// is wrapped in a paragraph, and the trim cuts the first `<w:t>` of the first run whatever formatting that run
    /// carries. `printed` trims, so only the exact XML can show the space; this pins it for bare words, for an italic
    /// and a cross-reference run (notes 3 and 4 are `frus1925v02` d601 fn 3 and `frus1969-76v41` d76 fn 4), for a
    /// `<p>`, for a second paragraph that opens on a line break, and for a space inside a paragraph, which stays.
    @Test("Each paragraph of a note in Word opens on its first word, with one space after the number")
    func aNotesParagraphOpensOnItsFirstWord() async throws {
        let part = try await footnotesPart("""
        <div type="document" xml:id="d1">
          <p>Body text.<note n="1" xml:id="d1fn1"> Bare words open on a space.</note> More body text.<note n="2"
              xml:id="d1fn2"><p> Words open on a space.</p>
              <p>
                  A second paragraph, with <hi rend="italic">italics</hi>.</p></note> Still more.<note n="3"
              xml:id="d1fn3"><hi
                  rend="italic"> Ibid</hi>., pp. 3149, 3226.</note> And more.<note n="4"
              xml:id="d1fn4">
              <ref target="#d71"> Document 71</ref>.</note></p>
        </div>
        """)
        let pPr = "<w:pPr><w:pStyle w:val=\"FootnoteText\"/></w:pPr>"
        let number = "<w:r><w:rPr><w:rStyle w:val=\"FootnoteReference\"/></w:rPr><w:footnoteRef/></w:r>"
            + "<w:r><w:t xml:space=\"preserve\"> </w:t></w:r>"
        let bareNote = try footnote(containing: "Bare words", in: part)
        let paragraphNote = try footnote(containing: "Words open on", in: part)
        let italicNote = try footnote(containing: "3149", in: part)
        let refNote = try footnote(containing: "Document 71", in: part)
        #expect(italicNote == "<w:footnote w:id=\"3\">\n"
                + "        <w:p>\(pPr)\(number)"
                + "<w:r><w:rPr><w:i/></w:rPr><w:t xml:space=\"preserve\">Ibid</w:t></w:r>"
                + "<w:r><w:t xml:space=\"preserve\">., pp. 3149, 3226.</w:t></w:r></w:p>\n"
                + "      </w:footnote>")
        #expect(refNote == "<w:footnote w:id=\"4\">\n"
                + "        <w:p>\(pPr)\(number)"
                + "<w:r><w:t xml:space=\"preserve\">Document 71</w:t></w:r>"
                + "<w:r><w:t xml:space=\"preserve\">.</w:t></w:r></w:p>\n"
                + "      </w:footnote>")
        #expect(bareNote == "<w:footnote w:id=\"1\">\n"
                + "        <w:p>\(pPr)\(number)"
                + "<w:r><w:t xml:space=\"preserve\">Bare words open on a space.</w:t></w:r></w:p>\n"
                + "      </w:footnote>")
        #expect(paragraphNote == "<w:footnote w:id=\"2\">\n"
                + "        <w:p>\(pPr)\(number)"
                + "<w:r><w:t xml:space=\"preserve\">Words open on a space.</w:t></w:r></w:p>\n"
                + "        <w:p>\(pPr)<w:r><w:t xml:space=\"preserve\">A second paragraph, with </w:t></w:r>"
                + "<w:r><w:rPr><w:i/></w:rPr><w:t xml:space=\"preserve\">italics</w:t></w:r>"
                + "<w:r><w:t xml:space=\"preserve\">.</w:t></w:r></w:p>\n"
                + "      </w:footnote>")
    }
}

// MARK: - CollectionExportNamingTests (#1463)

/// An unnamed collection exports as "Untitled Collection", in its file name and in its title, and no export is ever a
/// hidden file (#1463).
///
/// Every exporter named its file `sanitized(name) + extension`, and the sanitizer only replaced `/:\?%*|"<>`: a
/// collection whose name had been cleared exported as `.html`, `.docx`, `.pdf`, `.bib` — hidden dotfiles — or
/// `-zotero.ris`, and a name opening with a dot did the same. Its HTML `<title>` and `<h1>`, Word cover heading and PDF
/// cover title were blank, because the export sheet passed the stored name through while the live preview put
/// "Untitled Collection" in its place. Each test drives the real exporter, or the native file's real writer.
///
/// The suite is serialized because the exporters name their files after the collection, so two tests exporting the
/// same name in parallel would write one file. It runs on any destination.
@Suite("An unnamed collection exports as Untitled Collection, never as a hidden file (#1463)", .serialized)
struct CollectionExportNamingTests {

    /// Every rendered format, with what its exporter appends to the collection's name.
    static let formats: [(format: ExportFormat, suffix: String)] = [
        (.pdf, ".pdf"), (.html, ".html"), (.docx, ".docx"), (.bibtex, ".bib"), (.zoteroJSON, "-zotero.ris"),
    ]

    /// Exports an empty collection named `name` through `format`'s real exporter and returns the file's name.
    @MainActor
    private func exportedFileName(_ format: ExportFormat, name: String) async throws -> String {
        let exporter = try #require(format.makeExporter(), "\(format) has no exporter")
        let url = try await exporter.export(metadata: CollectionExportMetadata(name: name, note: nil), items: [])
        defer { try? FileManager.default.removeItem(at: url) }
        return url.lastPathComponent
    }

    @Test("A collection with no name exports in every format as Untitled Collection", arguments: formats.indices)
    @MainActor
    func emptyNameExportsAsUntitled(_ index: Int) async throws {
        let (format, suffix) = Self.formats[index]
        for name in ["", "   ", "\n\t"] {
            let file = try await exportedFileName(format, name: name)
            #expect(file == "Untitled Collection" + suffix, "\(format) named \(name.debugDescription) wrote \(file)")
        }
    }

    @Test("A name that opens with a dot never exports as a hidden file", arguments: formats.indices)
    @MainActor
    func leadingDotNeverHidesTheFile(_ index: Int) async throws {
        let (format, suffix) = Self.formats[index]
        for (name, expected) in [(".hidden", "hidden"), ("..", "Untitled Collection"), (" ...", "Untitled Collection"),
                                 ("./Suez", "-Suez"), (". . Suez", "Suez")] {
            let file = try await exportedFileName(format, name: name)
            #expect(file == expected + suffix, "\(format) named \(name.debugDescription) wrote \(file)")
            #expect(!file.hasPrefix("."), "\(format) named \(name.debugDescription) wrote a hidden file \(file)")
        }
    }

    /// A control, not a guard: it passes before #1463's fix and after.
    @Test("A named collection keeps its name, with the characters a file name cannot hold replaced", arguments: formats.indices)
    @MainActor
    func namedCollectionKeepsItsName(_ index: Int) async throws {
        let (format, suffix) = Self.formats[index]
        let file = try await exportedFileName(format, name: "Suez: 1956/57")
        #expect(file == "Suez- 1956-57" + suffix)
    }

    /// The shareable `.fruscollection` fell back to the lower-case stem `collection`, and kept a leading dot.
    @Test("The shareable file of an unnamed collection is Untitled Collection, and never a hidden file")
    @MainActor
    func nativeFileIsNamedLikeTheOthers() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        for (name, expected) in [("", "Untitled Collection"), ("   ", "Untitled Collection"), (".hidden", "hidden"),
                                 ("Suez: 1956/57", "Suez- 1956-57")] {
            let collection = Collection(name: name)
            context.insert(collection)
            let file = NativeCollectionSerializer.makeFile(from: collection, includeNotes: false,
                                                           resolveNoteTexts: { _ in [] })
            let url = try NativeCollectionSerializer.writeTemporaryFile(file)
            defer { try? FileManager.default.removeItem(at: url) }
            #expect(url.lastPathComponent == expected + ".fruscollection",
                    "a collection named \(name.debugDescription) wrote \(url.lastPathComponent)")
            // The file itself still carries the name the collection has, so an import restores it as it was.
            #expect(try NativeCollectionSerializer.decode(Data(contentsOf: url)).name == name)
        }
    }

    /// Exports `collection` through the metadata the export sheet and the preview build, as HTML, Word and PDF, and
    /// returns each file's text: the page, `word/document.xml`, and the PDF's first page.
    @MainActor
    private func titlePages(_ metadata: CollectionExportMetadata) async throws -> (html: String, docx: String, pdf: String) {
        let html = try await HTMLCollectionExporter().export(metadata: metadata, items: [])
        let docx = try await DocxCollectionExporter().export(metadata: metadata, items: [])
        let pdf = try await PDFCollectionExporter().export(metadata: metadata, items: [])
        defer { for url in [html, docx, pdf] { try? FileManager.default.removeItem(at: url) } }
        let document = try #require(PDFDocument(url: pdf))
        return (try String(contentsOf: html, encoding: .utf8),
                String(decoding: try Data(contentsOf: docx), as: UTF8.self),
                try #require(document.page(at: 0)?.string))
    }

    @Test("An unnamed collection's export is titled Untitled Collection in HTML, Word and PDF")
    @MainActor
    func exportOfAnUnnamedCollectionIsTitled() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        let collection = Collection(name: "")
        context.insert(collection)
        let metadata = CollectionExportMetadata.forExport(of: collection, activeProject: nil, modelContext: context)
        #expect(metadata.name == "Untitled Collection")
        let pages = try await titlePages(metadata)
        #expect(pages.html.contains("<title>Untitled Collection</title>"), "the HTML <title> is not the fallback")
        #expect(pages.html.contains("<h1>Untitled Collection</h1>"), "the HTML <h1> is not the fallback")
        #expect(pages.docx.contains("<w:pStyle w:val=\"Heading1\"/></w:pPr>\n      <w:r><w:t xml:space=\"preserve\">Untitled Collection</w:t>"),
                "the Word cover heading is not the fallback")
        #expect(pages.pdf.hasPrefix("Untitled Collection"), "the PDF cover title is not the fallback: \(pages.pdf.prefix(80))")
    }

    /// The name is resolved where the metadata is made, so metadata built by hand — as the Zotero RIS path builds it —
    /// titles and names its file the same way.
    @Test("Metadata made with a blank name reads Untitled Collection, and a name keeps its words")
    func metadataNameFallsBack() {
        #expect(CollectionExportMetadata(name: "", note: nil).name == "Untitled Collection")
        #expect(CollectionExportMetadata(name: " \n ", note: nil).name == "Untitled Collection")
        #expect(CollectionExportMetadata(name: "  Suez  ", note: nil).name == "Suez")
    }
}

#if os(iOS)
// MARK: - RichTextRestingCapTests (#1360)

/// A rich-text editor that opts into a resting cap (#1360) is drawn, when nobody is editing it, as its opening lines
/// ending in an ellipsis and sized to them; editing lifts the cap, and ending the edit restores it, scrolled back to
/// the top.
///
/// Before #1360 the collection outline's prose row was a scrolling `UITextView` inside a 60–220 pt frame: a long block
/// was cut through a line at the frame's edge, and one typed in place was left scrolled to its END, because the text
/// view follows the caret and nothing scrolled it back.
///
/// Every test but the two that read the Mac's code from source (no test target hosts the Mac) hosts the REAL
/// ``RichTextEditor`` in a key window of the test host's own scene and drives it through UIKit's own focus and typing
/// calls — and the formatting bar's own actions — so the delegate wiring and SwiftUI's sizing are what is under test,
/// not a copy of them. The measurements not taken from the code under test come from probe text views given the same
/// text: the uncapped height, the yardstick that says the cap actually removed something, and the capped height at a
/// width the editor is not laid out at. Where a test's claim is about what the block DRAWS — an ellipsis — it renders
/// the text view and asks Vision what it reads, because nothing else can see it.
///
/// Version history:
///   1.0 — #1360: initial implementation
///   1.1 — #1360 review, round 1: a block never shrinks when editing begins; the formatting bar's colour picker and
///          link alert leave it open; paragraphs rest on an ellipsis; the size follows a width the editor is NOT laid
///          out at; the no-cap control pins SwiftUI's own sizing; titles say what is asserted, not what is drawn
///   1.2 — #1360 review, round 2: a change to a resting block is reported with its paragraph breaks; the swap leaves
///          nothing to undo; the link alert's Cancel leaves the block open only with focus; and the Mac's report path
///          and resting wiring, which no test target hosts, are read from the source
@MainActor
@Suite("A capped rich-text editor rests on its opening lines and lifts the cap to edit (#1360)", .serialized)
struct RichTextRestingCapTests {

    /// Four lines at rest, at least 60 pt, at most 220 pt while editing.
    static let cap = RichTextRestingCap(lines: 4, minHeight: 60, editingMaxHeight: 220)
    /// Twelve lines at rest but at most 150 pt while editing: the resting lines outgrow the editing height, as the
    /// note block's six do at AX3 (292 pt against 220) — the shape of the inversion, at the default text size.
    static let tallRestCap = RichTextRestingCap(lines: 12, minHeight: 60, editingMaxHeight: 150)
    /// The width the editor is offered.
    static let width: CGFloat = 400
    /// A block that runs well past four lines — and past 220 pt — at 400 pt.
    static let longText = String(repeating: "The allies must decide before the ministers meet whether to propose "
                                 + "an interim arrangement for the access routes. ", count: 10)
    /// Three lines at 400 pt and more at 250 pt, under the four-line cap at 400: the width decides its height.
    static let mediumText = "The allies must decide before the ministers meet whether to propose an interim "
        + "arrangement for the access routes, and when."
    /// One short line: under the cap and under the least height.
    static let shortText = "A short note."
    /// Five one-line paragraphs with a blank line between each, as `CollectionProse` splits them: at 400 pt the lines
    /// run paragraph, blank, paragraph, … so a cap of five ends on a paragraph's own last line and a cap of six on a
    /// blank line — the two places a text view's tail truncation draws no ellipsis, because the cut is not inside a
    /// paragraph.
    static let paragraphs = ["First paragraph ends here.", "Second paragraph ends here.", "Third paragraph ends here.",
                             "Fourth paragraph ends here.", "Fifth paragraph ends here."].joined(separator: "\n\n")

    @Test("At rest, a long block does not scroll, is capped at four lines truncating its tail, and is sized to them")
    func aLongBlockRestsCapped() async throws {
        let host = try RestingCapEditorHost(text: Self.longText, cap: Self.cap, width: Self.width)
        let textView = try #require(host.textView, "The hosted editor has no UITextView")
        #expect(!textView.isScrollEnabled, "A resting capped editor still scrolls")
        #expect(textView.textContainer.maximumNumberOfLines == Self.cap.lines)
        #expect(textView.textContainer.lineBreakMode == .byTruncatingTail)
        let capped = RestingCapEditorHost.fittingHeight(of: textView, width: Self.width)
        let uncapped = RestingCapEditorHost.uncappedHeight(like: textView, width: Self.width)
        #expect(capped * 2 < uncapped, "The cap removed too little to test: \(capped) of \(uncapped) pt")
        let settled = await RestingCapEditorHost.settle { abs(textView.frame.height - max(capped, 60)) < 1 }
        #expect(settled, "The resting editor is \(textView.frame.height) pt tall, not its capped \(capped) pt")
        #expect(await host.close(), "The hosting controller outlived the test")
    }

    /// The drawn half of the resting claim, over the text a real block holds: paragraphs split by blank lines. Measured
    /// on the first build of #1360, a cap that fell on a blank line or on a one-line paragraph drew those lines clean,
    /// with nothing to say there was more — the complaint #1360 was filed for.
    @Test("A block of paragraphs rests on an ellipsis whether the cap falls on a blank line or on a paragraph's end",
          arguments: [5, 6])
    func paragraphsRestOnAnEllipsis(lines: Int) async throws {
        let cap = RichTextRestingCap(lines: lines, minHeight: 60, editingMaxHeight: 220)
        let host = try RestingCapEditorHost(text: Self.paragraphs, cap: cap, width: Self.width)
        let textView = try #require(host.textView, "The hosted editor has no UITextView")
        let resting = max(RestingCapEditorHost.fittingHeight(of: textView, width: Self.width), cap.minHeight)
        let settled = await RestingCapEditorHost.settle { abs(textView.frame.height - resting) < 1 }
        #expect(settled, "The resting editor is \(textView.frame.height) pt tall, not its capped \(resting) pt")
        let drawn = try RestingCapEditorHost.recognizedLines(in: textView)
        #expect(drawn.first == "First paragraph ends here.", "Vision did not read the block's opening line: \(drawn)")
        #expect(!drawn.contains { $0.hasPrefix("Fifth") }, "The resting block drew its last paragraph: \(drawn)")
        let last = drawn.last ?? ""
        #expect(last.hasSuffix("...") || last.hasSuffix("…"),
                "Capped at \(lines) lines, the block's last drawn line \"\(last)\" ends in no ellipsis: \(drawn)")
        #expect(await host.close(), "The hosting controller outlived the test")
    }

    /// The paragraph breaks a resting block DRAWS differently are a layout matter: the text the reader edits, and the
    /// text the editor reports, keep every one, and swapping them leaves nothing to undo.
    @Test("Editing a resting block of paragraphs gets every paragraph break back, with nothing to undo, and the editor reports them")
    func editingGetsTheParagraphBreaksBack() async throws {
        let reported = ReportedText()
        let host = try RestingCapEditorHost(text: Self.paragraphs, cap: Self.cap, width: Self.width) { _, plain in
            reported.plain.append(plain)
        }
        let textView = try #require(host.textView, "The hosted editor has no UITextView")
        #expect(textView.becomeFirstResponder(), "The hosted editor could not take focus")
        #expect(textView.text == Self.paragraphs, "Editing began on text that is not the block's: \(textView.text!)")
        let undo = try #require(textView.undoManager, "The hosted editor has no undo manager to ask")
        #expect(!undo.canUndo, "Resting the block and lifting its cap left something to undo before anything was typed")
        textView.selectedRange = NSRange(location: (textView.text as NSString).length, length: 0)
        textView.insertText(" Typed.")
        #expect(reported.plain.last == Self.paragraphs + " Typed.",
                "The editor reported \(reported.plain.last.map { "\"\($0)\"" } ?? "nothing") for the typed block")
        #expect(textView.resignFirstResponder(), "The hosted editor could not give up focus")
        #expect(textView.becomeFirstResponder(), "The hosted editor could not take focus again")
        #expect(textView.text == Self.paragraphs + " Typed.", "A second edit began on changed text: \(textView.text!)")
        #expect(textView.resignFirstResponder(), "The hosted editor could not give up focus")
        #expect(reported.plain.count == 1, "Resting and lifting the cap reported \(reported.plain.count - 1) edits")
        #expect(await host.close(), "The hosting controller outlived the test")
    }

    /// A resting block can be CHANGED. On the Mac the formatting bar sits above every block and its buttons take no
    /// focus, so Bold pressed after focus left a block applies to its kept selection, on a storage that draws its
    /// paragraph breaks as line breaks. Measured on the Mac before review round 2 — a harness hosting the real editor,
    /// real clicks on the bar — the report carried U+2028 where every break was, in the RTF and in the plain text, and
    /// the block's paragraphs were saved as one. No test target hosts the Mac, and the report is shared, so this drives
    /// the same sequence through the iOS twin: a change to the resting storage, then the text-changed callback the
    /// Mac's `didChangeText` makes. ``everyReportPutsTheBreaksBack()`` pins that the Mac reports through the same code.
    @Test("A change to a resting block is reported with its paragraph breaks, and the block goes on resting")
    func aChangeToARestingBlockIsReportedWithItsParagraphBreaks() async throws {
        let reported = ReportedText()
        let host = try RestingCapEditorHost(text: Self.paragraphs, cap: Self.cap, width: Self.width) { rtf, plain in
            reported.rtf.append(rtf)
            reported.plain.append(plain)
        }
        let textView = try #require(host.textView, "The hosted editor has no UITextView")
        #expect(!textView.isFirstResponder, "The fixture's block is being edited, so it does not rest")
        #expect(textView.text.contains("\u{2028}"),
                "The resting block draws no paragraph break as a line break, so this test exercises nothing")

        // Bold over the first word of a text view without focus, then the text-changed callback: what the Mac bar's
        // Bold does to its text view (`shouldChangeText`, the storage, `didChangeText`).
        textView.textStorage.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 17),
                                          range: NSRange(location: 0, length: 5))
        textView.delegate?.textViewDidChange?(textView)

        #expect(reported.plain.count == 1, "The change was reported \(reported.plain.count) times, not once")
        let plain = reported.plain.last.map { "\"\($0)\"" } ?? "nothing"
        #expect(reported.plain.last == Self.paragraphs, "The editor reported \(plain), not the block's paragraphs")
        let rtf = try #require(reported.rtf.last ?? nil, "The editor reported no RTF")
        let stored = try #require(ProseRichText.decodedRTF(rtf), "The reported RTF does not decode")
        #expect(stored.string == Self.paragraphs,
                "The reported RTF holds \"\(stored.string)\", not the block's paragraphs")
        let font = try #require(stored.attribute(.font, at: 0, effectiveRange: nil) as? UIFont,
                                "The reported RTF carries no font on its first word")
        #expect(font.fontDescriptor.symbolicTraits.contains(.traitBold), "The reported RTF lost the change it reported")
        // The breaks went back on a copy: the block still rests, drawing them as lines.
        #expect(textView.text.contains("\u{2028}"), "Reporting the change took the resting block's line breaks away")
        #expect(textView.textContainer.maximumNumberOfLines == Self.cap.lines, "Reporting the change lifted the cap")
        #expect(await host.close(), "The hosting controller outlived the test")
    }

    @Test("Editing lifts the cap within the editing height; ending it restores the cap, scrolled back to the top")
    func editingLiftsTheCapAndEndingRestoresIt() async throws {
        let host = try RestingCapEditorHost(text: Self.longText, cap: Self.cap, width: Self.width)
        let textView = try #require(host.textView, "The hosted editor has no UITextView")
        let restingHeight = max(RestingCapEditorHost.fittingHeight(of: textView, width: Self.width),
                                Self.cap.minHeight)

        #expect(textView.becomeFirstResponder(), "The hosted editor could not take focus")
        #expect(textView.isScrollEnabled, "An editor being edited does not scroll")
        #expect(textView.textContainer.maximumNumberOfLines == 0, "Editing did not lift the cap")
        let grown = await RestingCapEditorHost.settle { abs(textView.frame.height - Self.cap.editingMaxHeight) < 1 }
        #expect(grown, "While editing, the editor is \(textView.frame.height) pt, not the 220 pt editing height")

        // Where following the caret leaves a long block: scrolled down. A positive control that the offset took.
        textView.setContentOffset(CGPoint(x: 0, y: 150), animated: false)
        #expect(textView.contentOffset.y == 150, "The fixture could not scroll the editor")

        #expect(textView.resignFirstResponder(), "The hosted editor could not give up focus")
        #expect(!textView.isScrollEnabled, "The end of editing left the editor scrolling")
        #expect(textView.textContainer.maximumNumberOfLines == Self.cap.lines, "The end of editing left the cap off")
        #expect(textView.textContainer.lineBreakMode == .byTruncatingTail)
        #expect(textView.contentOffset.y == -textView.adjustedContentInset.top,
                "The end of editing left the editor scrolled to \(textView.contentOffset.y), not the top")
        let rested = await RestingCapEditorHost.settle { abs(textView.frame.height - restingHeight) < 1 }
        #expect(rested, "After editing, the editor is \(textView.frame.height) pt, not its resting \(restingHeight) pt")
        #expect(await host.close(), "The hosting controller outlived the test")
    }

    /// The cap counts LINES and the editing height POINTS, so a large enough text size puts the resting lines past the
    /// editing height: at AX3 the note block rested at 292 pt against its 220 pt ceiling, and a tap SHRANK it. The
    /// fixture reaches the same shape at the default size with a twelve-line cap and a 150 pt ceiling.
    @Test("Beginning to edit never makes a block shorter than it rested, when its resting lines outgrow the editing height")
    func editingNeverShrinksTheBlock() async throws {
        let host = try RestingCapEditorHost(text: Self.longText, cap: Self.tallRestCap, width: Self.width)
        let textView = try #require(host.textView, "The hosted editor has no UITextView")
        let resting = max(RestingCapEditorHost.fittingHeight(of: textView, width: Self.width),
                          Self.tallRestCap.minHeight)
        #expect(resting > Self.tallRestCap.editingMaxHeight,
                "The fixture rests at \(resting) pt, under its \(Self.tallRestCap.editingMaxHeight) pt editing height")
        let rested = await RestingCapEditorHost.settle { abs(textView.frame.height - resting) < 1 }
        #expect(rested, "The resting editor is \(textView.frame.height) pt, not its \(resting) pt")

        #expect(textView.becomeFirstResponder(), "The hosted editor could not take focus")
        #expect(textView.textContainer.maximumNumberOfLines == 0, "Editing did not lift the cap")
        #expect(textView.isScrollEnabled, "An editor being edited does not scroll")
        let kept = await RestingCapEditorHost.holds(for: .milliseconds(400)) {
            abs(textView.frame.height - resting) < 1
        }
        #expect(kept, "Beginning to edit made the block \(textView.frame.height) pt, from its resting \(resting) pt")

        textView.selectedRange = NSRange(location: (textView.text as NSString).length, length: 0)
        textView.insertText(Self.longText)
        let stillKept = await RestingCapEditorHost.holds(for: .milliseconds(400)) {
            abs(textView.frame.height - resting) < 1
        }
        #expect(stillKept, "Typing on made the block \(textView.frame.height) pt, from its resting \(resting) pt")
        #expect(textView.resignFirstResponder(), "The hosted editor could not give up focus")
        #expect(await host.close(), "The hosting controller outlived the test")
    }

    @Test("While editing, the editor grows with its text, and stops at the editing height")
    func editingGrowsWithTheText() async throws {
        let host = try RestingCapEditorHost(text: Self.shortText, cap: Self.cap, width: Self.width)
        let textView = try #require(host.textView, "The hosted editor has no UITextView")
        #expect(textView.becomeFirstResponder(), "The hosted editor could not take focus")
        let floor = await RestingCapEditorHost.settle { abs(textView.frame.height - Self.cap.minHeight) < 1 }
        #expect(floor, "A one-line block being edited is \(textView.frame.height) pt, not the 60 pt least height")

        textView.selectedRange = NSRange(location: (textView.text as NSString).length, length: 0)
        textView.insertText(" A second sentence, long enough to wrap onto a line of its own, and then onto a third "
                            + "line and a fourth, so that the block outgrows the least height.")
        let middle = RestingCapEditorHost.fittingHeight(of: textView, width: Self.width)
        #expect(middle > Self.cap.minHeight && middle < Self.cap.editingMaxHeight,
                "The fixture's middle height \(middle) pt does not sit between the two bounds")
        let followed = await RestingCapEditorHost.settle { abs(textView.frame.height - middle) < 1 }
        #expect(followed, "After typing, the editor is \(textView.frame.height) pt, not its text's \(middle) pt")

        textView.insertText(Self.longText)
        let stopped = await RestingCapEditorHost.settle { abs(textView.frame.height - Self.cap.editingMaxHeight) < 1 }
        #expect(stopped, "A long block being edited is \(textView.frame.height) pt, not the 220 pt editing height")
        #expect(textView.resignFirstResponder(), "The hosted editor could not give up focus")
        #expect(await host.close(), "The hosting controller outlived the test")
    }

    /// The formatting bar's Text Color presents the system colour picker. Opening it leaves the text view focused —
    /// measured on iPad (a popover) and iPhone (a sheet), iOS 26.5 — but typing a value into the picker's own Sliders
    /// fields takes focus, which ENDS editing while the reader is still formatting. On #1360's first build that ending
    /// collapsed a long block to its resting lines behind the picker, scrolled to the top, hiding the range being
    /// coloured. The test takes the focus away itself, as the picker's field does, so it asks the same question on
    /// either host.
    @Test("While the colour picker is up, losing focus does not close the block behind it; when the picker is done and focus has not come back, the block rests")
    func theColorPickerKeepsTheBlockOpen() async throws {
        let host = try RestingCapEditorHost(text: Self.longText, cap: Self.cap, width: Self.width)
        let textView = try #require(host.textView, "The hosted editor has no UITextView")
        let resting = max(RestingCapEditorHost.fittingHeight(of: textView, width: Self.width), Self.cap.minHeight)
        let open = try await host.openMidEdit(textView, selecting: NSRange(location: 300, length: 12))
        #expect(open, "The fixture's block did not open to the 220 pt editing height")

        #expect(RestingCapEditorHost.sendFormattingAction("Text Color", of: textView), "The bar has no Text Color")
        let picker = try #require(await host.presented(UIColorPickerViewController.self),
                                  "Text Color presented no colour picker")
        if textView.isFirstResponder {
            #expect(textView.resignFirstResponder(), "The hosted editor could not give up focus to the picker")
        }
        let keptOpen = await RestingCapEditorHost.holds(for: .milliseconds(500)) { host.isOpen(textView) }
        #expect(keptOpen, """
            Behind the colour picker the block is \(textView.frame.height) pt, capped at \
            \(textView.textContainer.maximumNumberOfLines) lines and scrolled to \(textView.contentOffset.y)
            """)

        // The picker is done and focus has not come back — as when the reader closes it from its own field: the edit
        // ended with the picker, so the block rests.
        let delegate = try #require(textView.delegate as? UIColorPickerViewControllerDelegate,
                                    "The editor's coordinator is not the colour picker's delegate")
        delegate.colorPickerViewControllerDidFinish?(picker)
        let rested = await RestingCapEditorHost.settle {
            !textView.isScrollEnabled && textView.textContainer.maximumNumberOfLines == Self.cap.lines
                && textView.contentOffset.y == -textView.adjustedContentInset.top
                && abs(textView.frame.height - resting) < 1
        }
        #expect(rested, """
            After the picker, with focus elsewhere, the block is \(textView.frame.height) pt, capped at \
            \(textView.textContainer.maximumNumberOfLines) lines and scrolled to \(textView.contentOffset.y)
            """)
        #expect(await host.close(), "The hosting controller outlived the test")
    }

    /// The formatting bar's Link presents an alert whose text field takes focus from the text view. When the reader is
    /// done with it — here Cancel, whose handler is the editor's own — the block is open exactly when focus came back
    /// to it, and stays so. Measured in this host, focus DOES come back once the alert has gone (the log line below),
    /// so the block must stay open: a sheet's end that rested it regardless would close the block being typed in.
    @Test("The link alert takes focus without closing the block behind it; after Cancel the block is open only with focus")
    func theLinkAlertKeepsTheBlockOpen() async throws {
        let host = try RestingCapEditorHost(text: Self.longText, cap: Self.cap, width: Self.width)
        let textView = try #require(host.textView, "The hosted editor has no UITextView")
        let open = try await host.openMidEdit(textView, selecting: NSRange(location: 300, length: 12))
        #expect(open, "The fixture's block did not open to the 220 pt editing height")

        #expect(RestingCapEditorHost.sendFormattingAction("Link selected text to a URL", of: textView),
                "The bar has no Link")
        let alert = try #require(await host.presented(UIAlertController.self), "Link presented no alert")
        let tookFocus = await RestingCapEditorHost.settle { !textView.isFirstResponder }
        #expect(tookFocus, "The link alert did not take focus, so this test exercises nothing")
        let keptOpen = await RestingCapEditorHost.holds(for: .milliseconds(500)) { host.isOpen(textView) }
        #expect(keptOpen, """
            Behind the link alert the block is \(textView.frame.height) pt, capped at \
            \(textView.textContainer.maximumNumberOfLines) lines and scrolled to \(textView.contentOffset.y)
            """)

        // Cancel, as a tap runs it: the alert goes, then the action's handler runs.
        let cancel = try #require(alert.actions.first { $0.style == .cancel }, "The link alert has no Cancel")
        let handler = try #require(RestingCapEditorHost.handler(of: cancel), "Cancel carries no handler to run")
        #expect(await host.dismissPresented(), "The link alert did not go")
        handler(cancel)
        let consistent: () -> Bool = {
            textView.isFirstResponder
                ? textView.isScrollEnabled && textView.textContainer.maximumNumberOfLines == 0
                : !textView.isScrollEnabled && textView.textContainer.maximumNumberOfLines == Self.cap.lines
        }
        // Arrive — a block without focus rests on the next turn — and then STAY: a wrong rest also comes a turn late.
        let settled = await RestingCapEditorHost.settle(until: consistent)
        let stayed = await RestingCapEditorHost.holds(for: .milliseconds(500), consistent)
        print("[RichTextRestingCapTests] after the link alert's Cancel, focus came back: \(textView.isFirstResponder)")
        #expect(settled && stayed, """
            After the link alert's Cancel the block \(textView.isFirstResponder ? "has" : "does not have") focus, but \
            is capped at \(textView.textContainer.maximumNumberOfLines) lines with scrolling \
            \(textView.isScrollEnabled ? "on" : "off")
            """)
        #expect(await host.close(), "The hosting controller outlived the test")
    }

    @Test("A short block rests at the least height")
    func aShortBlockRestsAtTheLeastHeight() async throws {
        let host = try RestingCapEditorHost(text: Self.shortText, cap: Self.cap, width: Self.width)
        let textView = try #require(host.textView, "The hosted editor has no UITextView")
        #expect(!textView.isScrollEnabled, "A resting capped editor still scrolls")
        let fitting = RestingCapEditorHost.fittingHeight(of: textView, width: Self.width)
        #expect(fitting < Self.cap.minHeight, "The fixture's short text is \(fitting) pt, not under the least height")
        let settled = await RestingCapEditorHost.settle { abs(textView.frame.height - Self.cap.minHeight) < 1 }
        #expect(settled, "A one-line block rests at \(textView.frame.height) pt, not the 60 pt least height")
        #expect(await host.close(), "The hosting controller outlived the test")
    }

    /// The branch every editor that does NOT opt in takes — the research note's body among them. A control on the
    /// unfixed code, where every editor scrolled. It is sized by its caller's frame, as before #1360 — here a fixed
    /// 333 pt, a height no capped layout of this text lands on — and its text is never drawn any differently.
    @Test("An editor with no resting cap stays a scrolling editor, sized by its caller, at rest and after an edit")
    func anEditorWithNoCapKeepsScrolling() async throws {
        let framed: CGFloat = 333
        let host = try RestingCapEditorHost(text: Self.paragraphs, cap: nil, width: Self.width, height: framed)
        let textView = try #require(host.textView, "The hosted editor has no UITextView")
        #expect(textView.isScrollEnabled, "An editor with no cap stopped scrolling at rest")
        #expect(textView.textContainer.maximumNumberOfLines == 0, "An editor with no cap was capped at rest")
        #expect(textView.text == Self.paragraphs, "An editor with no cap changed its text at rest")
        let sized = await RestingCapEditorHost.settle { abs(textView.frame.height - framed) < 1 }
        #expect(sized, "An editor with no cap is \(textView.frame.height) pt, not its caller's \(framed) pt frame")
        #expect(textView.becomeFirstResponder(), "The hosted editor could not take focus")
        textView.insertText(" Typed.")
        #expect(textView.text.contains("Typed."), "The fixture could not type into the editor")
        #expect(textView.resignFirstResponder(), "The hosted editor could not give up focus")
        #expect(textView.isScrollEnabled, "An editor with no cap stopped scrolling after an edit")
        #expect(textView.textContainer.maximumNumberOfLines == 0, "An editor with no cap was capped after an edit")
        let stillSized = await RestingCapEditorHost.holds(for: .milliseconds(300)) {
            abs(textView.frame.height - framed) < 1
        }
        #expect(stillSized, "After an edit, an editor with no cap is \(textView.frame.height) pt, not \(framed) pt")
        #expect(await host.close(), "The hosting controller outlived the test")
    }

    /// The sizing the representable hands SwiftUI, called directly for the proposals no hosted layout makes on demand.
    @Test("The capped size takes the offered width, ignores the offered height, and defers to SwiftUI when no finite width is offered")
    func theCappedSizeTakesTheOfferedWidth() async throws {
        let host = try RestingCapEditorHost(text: Self.longText, cap: Self.cap, width: Self.width)
        let textView = try #require(host.textView, "The hosted editor has no UITextView")
        let resting = max(RestingCapEditorHost.fittingHeight(of: textView, width: Self.width), Self.cap.minHeight)
        #expect(RichTextRestingLayout.size(for: ProposedViewSize(width: Self.width, height: nil), of: textView,
                                           cap: Self.cap, editing: false)
                == CGSize(width: Self.width, height: resting))
        // The height a parent offers is not the editor's height: a capped editor is as tall as its lines.
        #expect(RichTextRestingLayout.size(for: ProposedViewSize(width: Self.width, height: 900), of: textView,
                                           cap: Self.cap, editing: false)?.height == resting)
        #expect(RichTextRestingLayout.size(for: ProposedViewSize(width: nil, height: 300), of: textView,
                                           cap: Self.cap, editing: false) == nil,
                "An unspecified width must defer to SwiftUI rather than invent one")
        #expect(RichTextRestingLayout.size(for: ProposedViewSize(width: .infinity, height: 300), of: textView,
                                           cap: Self.cap, editing: false) == nil,
                "An unbounded width must defer to SwiftUI rather than lay the text out on one line")
        #expect(await host.close(), "The hosting controller outlived the test")
    }

    /// SwiftUI can ask for a size at a width the view is not yet laid out at — a freshly made editor has zero bounds,
    /// and a rotation offers the new width before the frame changes — so the height must be measured at the width
    /// OFFERED. Measured against a probe at that width, never against the editor's own arithmetic.
    @Test("The capped size is measured at the width offered, not the width the editor is laid out at")
    func theCappedSizeIsMeasuredAtTheOfferedWidth() async throws {
        let host = try RestingCapEditorHost(text: Self.mediumText, cap: Self.cap, width: Self.width)
        let textView = try #require(host.textView, "The hosted editor has no UITextView")
        let laidOut = await RestingCapEditorHost.settle { abs(textView.bounds.width - Self.width) < 1 }
        #expect(laidOut, "The editor is laid out \(textView.bounds.width) pt wide, not the fixture's \(Self.width)")
        let narrow: CGFloat = 250
        let atNarrow = RestingCapEditorHost.restingHeight(like: textView, width: narrow, cap: Self.cap)
        let atLaidOut = RestingCapEditorHost.restingHeight(like: textView, width: Self.width, cap: Self.cap)
        #expect(atNarrow > atLaidOut,
                "The fixture rests \(atNarrow) pt tall at \(narrow) pt and \(atLaidOut) pt at \(Self.width): no difference to see")
        #expect(RichTextRestingLayout.size(for: ProposedViewSize(width: narrow, height: nil), of: textView,
                                           cap: Self.cap, editing: false)
                == CGSize(width: narrow, height: atNarrow),
                "Offered \(narrow) pt, the editor did not measure its lines at \(narrow) pt")
        #expect(await host.close(), "The hosting controller outlived the test")
    }

    // MARK: The Mac, read from source

    /// No test target hosts the Mac, so the Mac half of ``aChangeToARestingBlockIsReportedWithItsParagraphBreaks()`` is
    /// read from the source: the Mac coordinator's `textDidChange` — where every formatting-bar action, and every typed
    /// change, arrives — reports through the one `report(_:)` that test drives, and that function puts the breaks back
    /// BEFORE its platform branch, so the Mac compiles the same restore. Before review round 2 it did not, and the Mac
    /// saved a block formatted at rest with its paragraphs run together.
    @Test("Every report, the Mac's included, puts a resting block's paragraph breaks back before it serialises")
    func everyReportPutsTheBreaksBack() throws {
        let code = try Self.editorSource()
        let report = try Self.body(of: "fileprivate func report(_ storage: NSAttributedString)", in: code)
        let restore = try #require(report.range(of: "let stored = RichTextRestingText.withBreaksRestored(storage)"),
                                   "report(_:) serialises the storage without putting its paragraph breaks back")
        let branch = try #require(report.range(of: "#if os(iOS)"), "report(_:) no longer has its platform branch")
        #expect(restore.upperBound <= branch.lowerBound,
                "report(_:) puts the breaks back inside its iOS branch, so the Mac never does")
        #expect(!report[restore.upperBound...].contains("storage"),
                "report(_:) serialises the storage itself somewhere after putting the breaks back on a copy")
        #expect(Self.calls(of: "onChange", in: code) == 1 && report.contains("onChange("),
                "Something other than report(_:) hands the editor's text to onChange")
        let macChange = try Self.body(of: "func textDidChange(_ notification: Notification)", in: code)
        #expect(Self.calls(of: "report", in: macChange) == 1 && macChange.contains("report(storage)"),
                "The Mac's textDidChange does not report through report(_:)")
    }

    /// The Mac-only resting wiring, which no hosted test reaches: a new width counts the resting lines again (the
    /// harness measured 250 pt → six lines, 420 pt → five, the ellipsis drawn at each), a rest draws the counted lines
    /// and keeps the selection the swap would move, and a recount lays the viewport out again — without which a new
    /// count kept the old truncation and drew no ellipsis.
    @Test("On the Mac a new width recounts a resting block's lines, and a rest draws the count and keeps the selection")
    func theMacRestingWiringIsInPlace() throws {
        let code = try Self.editorSource()
        let setFrame = try Self.body(of: "override func setFrameSize(_ newSize: NSSize)", in: code)
        #expect(setFrame.contains("if widthChanged { onWidthChange?() }"),
                "RichTextFocusTextView does not report a change of width")
        let make = try Self.body(of: "func makeNSView(context: Context) -> NSScrollView", in: code)
        let onWidth = try Self.body(of: "textView.onWidthChange = ", in: make)
        #expect(onWidth.contains("coordinator.widthChanged(in: scroll)"),
                "The Mac editor does not hand a change of width to its coordinator")
        let widthChanged = try Self.body(of: "fileprivate func widthChanged(in scrollView: NSScrollView)", in: code)
        #expect(widthChanged.contains("RichTextRestingLayout.recount(scrollView, cap: restingCap)"),
                "A change of width does not recount a resting block's lines")
        let recount = try Self.body(of: "static func recount(_ scrollView: NSScrollView, cap: RichTextRestingCap)",
                                    in: code)
        #expect(recount.contains("restingLines(of: textView, width: scrollView.frame.width, cap: cap)"),
                "A recount does not count the resting lines at the new width")
        #expect(recount.contains("layout.textViewportLayoutController.layoutViewport()"),
                "A recount does not lay the viewport out again, so the old truncation stays drawn")
        let rest = try Self.body(of: "static func rest(_ scrollView: NSScrollView, cap: RichTextRestingCap)", in: code)
        #expect(rest.contains("maximumNumberOfLines = restingLines(of: textView, width: scrollView.frame.width,"),
                "A Mac rest does not draw the counted resting lines")
        let save = try #require(rest.range(of: "let selection = textView.selectedRanges"),
                                "A Mac rest does not save the selection before swapping the breaks")
        let swap = try #require(rest.range(of: "RichTextRestingText.drawBreaksAsLines(in: storage)"),
                                "A Mac rest does not draw the breaks as lines")
        let keep = try #require(rest.range(of: "textView.selectedRanges = selection"),
                                "A Mac rest does not put the selection back after swapping the breaks")
        #expect(save.upperBound <= swap.lowerBound && swap.upperBound <= keep.lowerBound,
                "A Mac rest saves or restores the selection on the wrong side of the swap")
    }

    /// `CollectionRichTextEditor.swift`, read from the source tree.
    private static func editorSource() throws -> String {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "FRUSExplorer/Collections/CollectionRichTextEditor.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// The braces-inclusive body `header` opens — from the first `{` after it to the `}` that closes that one. `header`
    /// must occur exactly once in `code`, so a test never reads the wrong declaration's body.
    private static func body(of header: String, in code: String) throws -> String {
        let occurrences = code.components(separatedBy: header).count - 1
        #expect(occurrences == 1, "\"\(header)\" occurs \(occurrences) times, not once")
        let start = try #require(code.range(of: header), "No \"\(header)\" in the source")
        let open = try #require(code[start.upperBound...].firstIndex(of: "{"), "\"\(header)\" opens no body")
        var depth = 0
        var cursor = open
        while cursor < code.endIndex {
            if code[cursor] == "{" { depth += 1 }
            if code[cursor] == "}" {
                depth -= 1
                if depth == 0 { return String(code[open...cursor]) }
            }
            cursor = code.index(after: cursor)
        }
        Issue.record("\"\(header)\"'s body never closes")
        return ""
    }

    /// How many times `code` calls a function named `name` — `name(` not preceded by an identifier character or a dot,
    /// so neither `onChangeOf(` nor a `.onChange(` modifier counts as an `onChange(`.
    private static func calls(of name: String, in code: String) -> Int {
        var count = 0
        var searchStart = code.startIndex
        while let range = code.range(of: name + "(", range: searchStart..<code.endIndex) {
            searchStart = range.upperBound
            if range.lowerBound > code.startIndex {
                let before = code[code.index(before: range.lowerBound)]
                if before.isLetter || before.isNumber || before == "_" || before == "." { continue }
            }
            count += 1
        }
        return count
    }
}

/// What an editor reported, in order — a reference, so a hosting closure can append to it.
@MainActor
private final class ReportedText {
    /// Each report's plain-text projection.
    var plain: [String] = []
    /// Each report's RTF.
    var rtf: [Data?] = []
}

/// Hosts one real ``RichTextEditor`` at the top of a key window in the test host's own scene, offered `width` points.
@MainActor
private final class RestingCapEditorHost {
    /// The window hosting the editor; `nil` once closed.
    private var window: UIWindow?

    /// Hosts an editor over `text`, capped by `cap` (or not, for `nil`), in a frame `width` wide and — when `height`
    /// is given — that tall; `onReport` receives each edit's RTF and plain-text projection.
    init(text: String, cap: RichTextRestingCap?, width: CGFloat, height: CGFloat? = nil,
         onReport: @escaping (Data?, String) -> Void = { _, _ in }) throws {
        let scene = try #require(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first,
            "The test host has no window scene to host the editor in")
        let editor = VStack(spacing: 0) {
            RichTextEditor(initialRTF: nil, plainFallback: text, restingCap: cap) { rtf, plain in onReport(rtf, plain) }
                .frame(width: width, height: height)
            Spacer(minLength: 0)
        }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(rootView: editor)
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        self.window = window
    }

    /// The editor's text view, found in the window's view tree.
    var textView: UITextView? {
        window.flatMap { Self.firstTextView(in: $0) }
    }

    private static func firstTextView(in view: UIView) -> UITextView? {
        if let textView = view as? UITextView { return textView }
        for subview in view.subviews {
            if let found = firstTextView(in: subview) { return found }
        }
        return nil
    }

    /// Begins editing `textView`, waits for it to open to ``RichTextRestingCapTests/cap``'s editing height, selects
    /// `range`, and scrolls the view down as following the caret would. Returns whether it opened.
    func openMidEdit(_ textView: UITextView, selecting range: NSRange) async throws -> Bool {
        #expect(textView.becomeFirstResponder(), "The hosted editor could not take focus")
        let open = await Self.settle { abs(textView.frame.height - RichTextRestingCapTests.cap.editingMaxHeight) < 1 }
        textView.selectedRange = range
        try? await Task.sleep(for: .milliseconds(100))
        textView.setContentOffset(CGPoint(x: 0, y: 150), animated: false)
        #expect(textView.contentOffset.y > Self.scrolledDown, "The fixture could not scroll the editor")
        return open
    }

    /// How far down an editor must still be scrolled to count as left where the edit put it, rather than put back at
    /// the top — UIKit may nudge the offset to keep a selection in view, so this is a floor, not the offset set.
    static let scrolledDown: CGFloat = 50

    /// Whether `textView` is open as an edit left it: uncapped, scrolling, still scrolled down, at the editing height.
    func isOpen(_ textView: UITextView) -> Bool {
        textView.isScrollEnabled && textView.textContainer.maximumNumberOfLines == 0
            && textView.contentOffset.y > Self.scrolledDown
            && abs(textView.frame.height - RichTextRestingCapTests.cap.editingMaxHeight) < 1
    }

    /// The view controller this window's root presents, once it is a `T` — `nil` if none appears within 3 s.
    func presented<T: UIViewController>(_ type: T.Type) async -> T? {
        var found: T?
        _ = await Self.settle {
            found = window?.rootViewController?.presentedViewController as? T
            return found != nil
        }
        return found
    }

    /// Dismisses what this window's root presents, as a tap on an alert action does before running its handler, and
    /// waits for it to go. Returns whether it went.
    func dismissPresented() async -> Bool {
        guard let root = window?.rootViewController, root.presentedViewController != nil else { return false }
        root.dismiss(animated: false)
        return await Self.settle { root.presentedViewController == nil }
    }

    /// The handler a tap on `action` runs, read off the action — UIKit offers no public way to run one — or `nil` when
    /// the action does not carry it under that name.
    static func handler(of action: UIAlertAction) -> ((UIAlertAction) -> Void)? {
        typealias Handler = @convention(block) (UIAlertAction) -> Void
        guard action.responds(to: NSSelectorFromString("handler")),
              let block = action.value(forKey: "handler") else { return nil }
        let handler = unsafeBitCast(block as AnyObject, to: Handler.self)
        return { handler($0) }
    }

    /// Sends the action of the formatting bar's item labelled `label` — the bar the editor hangs on its keyboard — as
    /// a tap would. Returns whether the bar had the item and the action was delivered.
    static func sendFormattingAction(_ label: String, of textView: UITextView) -> Bool {
        guard let item = (textView.inputAccessoryView as? UIToolbar)?.items?
                .first(where: { $0.accessibilityLabel == label }),
              let action = item.action else { return false }
        return UIApplication.shared.sendAction(action, to: item.target, from: item, for: nil)
    }

    /// The height `textView` fits its text in at `width` under its current container settings, rounded up.
    static func fittingHeight(of textView: UITextView, width: CGFloat) -> CGFloat {
        textView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height.rounded(.up)
    }

    /// The height of `textView`'s text with no cap at all — from a probe text view, never from the one under test.
    static func uncappedHeight(like textView: UITextView, width: CGFloat) -> CGFloat {
        let probe = UITextView()
        probe.font = textView.font
        probe.attributedText = textView.attributedText
        return fittingHeight(of: probe, width: width)
    }

    /// The height `textView`'s text rests at under `cap` at `width` — from a probe text view given the resting text
    /// and the resting layout, never from the one under test.
    static func restingHeight(like textView: UITextView, width: CGFloat, cap: RichTextRestingCap) -> CGFloat {
        let probe = UITextView()
        probe.font = textView.font
        probe.attributedText = textView.attributedText
        probe.isScrollEnabled = false
        probe.textContainer.maximumNumberOfLines = cap.lines
        probe.textContainer.lineBreakMode = .byTruncatingTail
        return max(fittingHeight(of: probe, width: width), cap.minHeight)
    }

    /// The lines Vision reads in `view` as drawn, top to bottom.
    static func recognizedLines(in view: UIView) throws -> [String] {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let background = UIColor.systemBackground.resolvedColor(with: view.traitCollection)
        let image = UIGraphicsImageRenderer(bounds: view.bounds, format: format).image { context in
            background.setFill()
            context.fill(view.bounds)
            view.layer.render(in: context.cgContext)
        }
        let cgImage = try #require(image.cgImage, "The rendered text view has no bitmap")
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: cgImage).perform([request])
        return (request.results ?? [])
            .sorted { $0.boundingBox.maxY > $1.boundingBox.maxY }
            .compactMap { $0.topCandidates(1).first?.string }
    }

    /// Pumps the main run loop until `condition` holds or `timeout` passes, and reports whether it held.
    static func settle(timeout: Duration = .seconds(3), until condition: () -> Bool) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    /// Pumps the main run loop for `duration`, and reports whether `condition` held at every look — for a state that
    /// must not merely arrive but stay.
    static func holds(for duration: Duration, _ condition: () -> Bool) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: duration)
        while clock.now < deadline {
            if !condition() { return false }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    /// Takes the window down — dismissing anything its root presents — and waits for the hosting controller to
    /// deallocate. Returns whether it went.
    func close() async -> Bool {
        weak let controller = window?.rootViewController
        if let presenter = window?.rootViewController, presenter.presentedViewController != nil {
            presenter.dismiss(animated: false)
        }
        window?.endEditing(true)
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(2))
        while controller != nil, clock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        return controller == nil
    }
}
#endif
