// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif

// MARK: - PlanFixtures

/// The documents L34's suites draw: one of each shape the plan decides by.
///
/// Version history:
///   1.0 — L34: initial implementation
enum PlanFixtures {

    /// From 1955 on: the heading opens on the volume's number and calls the source note, numbered, as
    /// `frus1977-80v06` d1 does; a body note; an attachment with its own heading.
    static let modern = """
    <div type="document" subtype="historical-document" n="1" xml:id="d1">
      <head>1. Letter From President Carter to Soviet General Secretary Brezhnev<note n="1" type="source" xml:id="d1fn1">Source: Carter Library, Presidential Papers. Secret.</note></head>
      <opener><dateline rendition="#right"><placeName>Washington</placeName>, <date calendar="gregorian" when="1977-01-26">January 26, 1977</date>.</dateline></opener>
      <p>Dear Mr. General Secretary: I write to you early in my term.<note n="2" xml:id="d1fn2">Brezhnev replied on February 4.</note></p>
      <frus:attachment><head>Enclosure</head><p>A list of the points made.</p></frus:attachment>
    </div>
    """

    /// The volume's printed source note before 1955: unnumbered, leading the document above its
    /// heading, as `frus1946v06` d475 prints it; the notes the volume numbers 44 and 45.
    static let early = """
    <div type="document" subtype="historical-document" n="475" xml:id="d475">
      <note rend="inline" type="source">861.00/2–2246: Telegram</note>
      <head>The Chargé in the Soviet Union (Kennan) to the Secretary of State</head>
      <opener><dateline rendition="#right"><placeName>Moscow</placeName>, <date calendar="gregorian" when="1946-02-22">February 22, 1946—9 p.m.</date></dateline></opener>
      <p>511. Answer to Dept’s 284, Feb 3 [13]<note n="44" xml:id="d475fn44">Not printed.</note> involves questions so intricate.<note n="45" xml:id="d475fn45">See footnote 44.</note></p>
    </div>
    """

    /// A dateline in the closer alone, and a note inside it.
    static let closerDateline = """
    <div type="document" subtype="historical-document" n="9" xml:id="d9">
      <head>9. Letter From Chairman Khrushchev to President Kennedy</head>
      <p>Dear Mr. President, I have received your letter.</p>
      <closer><dateline><placeName>Moscow</placeName><note n="3" xml:id="d9fn3">Delivered by hand.</note>, <date when="1962-10-26">October 26, 1962</date>.</dateline></closer>
    </div>
    """

    /// An editorial note: its heading is inside the wrapper the parser makes.
    static let editorialNote = """
    <div type="document" subtype="editorial-note" n="12" xml:id="d12">
      <head>12. Editorial Note</head>
      <p>The President met the Secretary on the morning of the 14th.</p>
    </div>
    """

    /// The source note's text the index stores for each fixture.
    static let modernSource = "Source: Carter Library, Presidential Papers. Secret."
    static let earlySource = "861.00/2–2246: Telegram"

    /// A document of `xml`, resolved as the assembly resolves it: the one reading of its parse as its
    /// heading and dateline.
    static func document(_ xml: String, id: String, volume: String = "frus1977-80v06", depth: CollectionBodyDepth = .full,
                         title: String? = nil, sourceNote: String? = nil, notes: [String] = [],
                         includeHeadnote: Bool = false, headnote: String? = nil,
                         footnotes: Bool? = nil, citationNumber: String? = nil) async throws -> CollectionExportDocument {
        let ast = try await ListShapeFixtures.ast(xml)
        var converter = ASTToRenderNodeConverter()
        let model = converter.convert(ast)
        let reading = DocumentHeadingReading(documentNodes: ast.nodes)
        let number = citationNumber ?? String(id.dropFirst())
        return CollectionExportDocument(
            documentId: id, volumeId: volume, sortOrder: 0, bodyDepth: depth, title: "\(volume) — \(id)",
            titleOverride: title, bodyText: buildFlatText(from: model), noteTexts: notes,
            citation: "Foreign Relations of the United States, _Volume VI_, Document \(number).",
            historyStateGovURL: "https://history.state.gov/historicaldocuments/\(volume)/\(id)",
            renderModel: model, header: reading.printedHeading, dateline: reading.dateline,
            summaryText: depth == .summaryOnly ? "A summary." : nil,
            sourceNoteText: sourceNote, includeHeadnote: includeHeadnote, headnoteText: headnote,
            includeFootnotesOverride: footnotes)
    }

    /// The document part of `html` whose anchor is `anchor`.
    static func section(_ html: String, anchor: String) throws -> String {
        let start = try #require(html.range(of: "<section id=\"\(anchor)\""))
        let end = html.range(of: "<section id=\"doc-", range: start.upperBound..<html.endIndex)?.lowerBound
            ?? html.range(of: "</body>", range: start.upperBound..<html.endIndex)?.lowerBound ?? html.endIndex
        return String(html[start.lowerBound..<end])
    }

    /// The Word package's text as a string: its parts are stored, not compressed.
    static func package(_ items: [CollectionExportItem], options: CollectionExportOptions) -> String {
        let data = DocxCollectionExporter().documentData(
            metadata: CollectionExportMetadata(name: "Plan", note: nil, exportDate: CollectionRenderingFixtures.exportDate),
            items: items, options: options)
        return String(decoding: data, as: UTF8.self)
    }

    /// The web page for `items`.
    static func page(_ items: [CollectionExportItem], options: CollectionExportOptions, preview: Bool = false) -> String {
        var renderer = CollectionItemHTMLRenderer(options: options)
        renderer.showsSummaryPlaceholders = preview
        return renderer.pageHTML(metadata: CollectionExportMetadata(name: "Plan", note: nil), items: items)
    }

    /// The paragraphs of `package` holding `text`, each whole.
    static func paragraphs(in package: String, holding text: String) -> [String] {
        package.components(separatedBy: "<w:p>").filter { $0.contains(text) }
    }
}

// MARK: - DocumentHeadingReadingTests

/// The one reading of a heading and a dateline (L34; the design's §3.4), which every place that
/// quotes a heading reads.
@Suite("L34: the one reading of a document's heading and dateline")
struct DocumentHeadingReadingTests {

    @Test("The volume's own number is read by its form, in either form the corpus prints (J23, #2002)")
    func numberByItsForm() {
        let cases: [(String, String?, String)] = [
            ("1. Letter From President Carter to Soviet General Secretary Brezhnev", "1.",
             "Letter From President Carter to Soviet General Secretary Brezhnev"),
            ("373a. Memorandum for the Record", "373a.", "Memorandum for the Record"),
            ("No. 98. Mr. Fish to Mr. Mathews.", "No. 98.", "Mr. Fish to Mr. Mathews."),
            ("No. 75 Mr. Low to Mr. Fish.", "No. 75", "Mr. Low to Mr. Fish."),
            ("No. 194 a. Mr. Campbell to Mr. Fish.", "No. 194 a.", "Mr. Campbell to Mr. Fish."),
            ("No. 5525.—United States of America.", "No. 5525.", "United States of America."),
            ("No. 2.", "No. 2.", ""),
            ("The Chargé in the Soviet Union (Kennan) to the Secretary of State", nil,
             "The Chargé in the Soviet Union (Kennan) to the Secretary of State"),
            // Not a document's number: a decimal, a year with no stop, a bracketed page.
            ("1.5 Million Tons of Wheat", nil, "1.5 Million Tons of Wheat"),
            ("1946 Annual Report", nil, "1946 Annual Report"),
            ("[238] *No. 2.—the arman contract.", nil, "[238] *No. 2.—the arman contract."),
        ]
        for (heading, number, words) in cases {
            let split = DocumentHeadingReading.splitNumber(heading)
            #expect(split.number == number && split.words == words, "\(heading) → \(split)")
        }
    }

    @Test("A heading's call and the volume's number are apart from its words (#1992, #2002)")
    func headingWithACall() async throws {
        let reading = DocumentHeadingReading(documentNodes: try await ListShapeFixtures.ast(PlanFixtures.modern).nodes)
        #expect(reading.words == "Letter From President Carter to Soviet General Secretary Brezhnev")
        #expect(reading.number == "1." && reading.calls == ["1"])
        #expect(reading.printedHeading == "1. Letter From President Carter to Soviet General Secretary Brezhnev")
        #expect(!reading.printedHeading.contains("["), "a call is written into the heading")
        #expect(reading.dateline == "Washington, January 26, 1977.")
    }

    @Test("A dateline is read in an opener, and in a closer where there is no other, its call apart (#1994)")
    func datelines() async throws {
        let early = DocumentHeadingReading(documentNodes: try await ListShapeFixtures.ast(PlanFixtures.early).nodes)
        #expect(early.dateline == "Moscow, February 22, 1946—9 p.m.")
        #expect(early.number == nil && early.words == "The Chargé in the Soviet Union (Kennan) to the Secretary of State")
        let closer = DocumentHeadingReading(documentNodes: try await ListShapeFixtures.ast(PlanFixtures.closerDateline).nodes)
        #expect(closer.dateline == "Moscow, October 26, 1962.")
        #expect(closer.datelineCalls == ["3"])
    }

    @Test("An editorial note's heading is read inside its wrapper (#2003)")
    func editorialNote() async throws {
        let ast = try await ListShapeFixtures.ast(PlanFixtures.editorialNote)
        guard case .editorialNote? = ast.nodes.first else { Issue.record("the parser did not wrap the note"); return }
        let reading = DocumentHeadingReading(documentNodes: ast.nodes)
        #expect(reading.number == "12." && reading.words == "Editorial Note")
        // L26's rule: a note that prints no source note of its own gives no dateline.
        #expect(reading.dateline == nil)
    }

    @Test("The index's two strings read the same way, with what the index holds")
    func fromTheIndex() {
        let reading = DocumentHeadingReading(indexedHeader: " No. 98.  Mr. Fish to Mr. Mathews. ",
                                             indexedDateline: "Washington, January 1, 1873.")
        #expect(reading.number == "No. 98." && reading.words == "Mr. Fish to Mr. Mathews.")
        #expect(reading.dateline == "Washington, January 1, 1873." && reading.calls.isEmpty)
        #expect(DocumentHeadingReading(indexedHeader: "", indexedDateline: "  ").dateline == nil)
    }
}

// MARK: - CollectionDocumentPlanTests

/// One plan for three formats (L34; the design's §3.8): what each document prints, in what order and
/// under what words, decided once in the kit and drawn the same by the web page and Word (the PDF's
/// half is the app's, in `CollectionExportParityTests`).
@Suite("L34: one plan for the web page, Word and the PDF")
struct CollectionDocumentPlanTests {

    typealias F = PlanFixtures

    // MARK: The three openings

    /// The brief's kit test: for each of the three openings, which line is the document's heading, and that
    /// *As published:* is inside the volume's heading, read in the web page and in the Word package.
    @Test("Each opening says which line is the document's heading, with As published: inside the volume's, in the page and the package")
    func threeOpenings() async throws {
        let untitled = try await F.document(F.early, id: "d475", volume: "frus1946v06")
        let titled = try await F.document(F.early, id: "d475", volume: "frus1946v06", title: "The Long Telegram")
        let anchor = "doc-frus1946v06-d475"

        // The citation leads: 1.0's opening.
        let citation = CollectionDocumentPlan(document: untitled, options: CollectionExportOptions())
        #expect(citation.opening == .citation)
        #expect(citation.headingLine?.role == .citation && citation.headingLine?.headingLevel == 2)
        var html = try F.section(F.page([.document(untitled)], options: CollectionExportOptions()), anchor: anchor)
        #expect(html.contains("<h2 class=\"doc-lead\"><a href=\"https://history.state.gov/historicaldocuments/frus1946v06/d475\""))
        #expect(html.contains("<h3 class=\"doc-heading\">The Chargé in the Soviet Union"), "the volume's heading is one level down")
        #expect(!html.contains("As published"))

        // A title of the author's leads, the volume's heading one level down with As published: inside it.
        let title = CollectionDocumentPlan(document: titled, options: CollectionExportOptions())
        #expect(title.opening == .title && title.headingLine?.role == .title && title.headingLine?.text == "The Long Telegram")
        #expect(title.lines.map(\.role).prefix(3) == [.title, .citation, .address])
        html = try F.section(F.page([.document(titled)], options: CollectionExportOptions()), anchor: anchor)
        #expect(html.contains("<h2 class=\"doc-lead\">The Long Telegram</h2>"))
        #expect(html.contains("<p class=\"doc-citation\"><a href="))
        #expect(html.contains("<h3 class=\"doc-heading\"><span class=\"as-published\" data-skip=\"1\">As published: </span>The Chargé"),
                "As published: is not inside the volume's heading")
        var package = F.package([.document(titled)], options: CollectionExportOptions())
        // The contents row holds the title too; the document's own paragraph is the heading.
        let lead = F.paragraphs(in: package, holding: "The Long Telegram</w:t>").filter { $0.contains("Heading2") }
        #expect(lead.count == 1 && lead.first?.contains("<w:outlineLvl w:val=\"1\"/>") == true, "\(lead)")
        let published = F.paragraphs(in: package, holding: "As published: </w:t>")
        #expect(published.count == 1)
        #expect(published.first?.contains("<w:pStyle w:val=\"Heading3\"/><w:outlineLvl w:val=\"2\"/>") == true
                && published.first?.contains("The Chargé in the Soviet Union") == true, "\(published)")

        // The volume's heading leads: the citation is a small line before it, and the region carries its number.
        var options = CollectionExportOptions()
        options.volumeHeadingLeads = true
        let volume = CollectionDocumentPlan(document: untitled, options: options)
        #expect(volume.opening == .volumeHeading && volume.headingLine == nil, "the heading is the text's own")
        #expect(volume.lines.first(where: { $0.role == .text })?.drawing?.headingLevel == 2)
        #expect(volume.regionName == "Document 475")
        html = try F.section(F.page([.document(untitled)], options: options), anchor: anchor)
        #expect(html.hasPrefix("<section id=\"\(anchor)\" aria-label=\"Document 475\">"), "\(html.prefix(80))")
        #expect(html.contains("<p class=\"doc-citation\">") && html.contains("<h2 class=\"doc-heading\">The Chargé"))
        package = F.package([.document(untitled)], options: options)
        let small = F.paragraphs(in: package, holding: "Document 475.</w:t>")
        #expect(small.contains { $0.contains("<w:pStyle w:val=\"DocCitation\"/><w:keepNext/>") },
                "Word does not keep the citation line with its heading (J16): \(small)")
        #expect(F.paragraphs(in: package, holding: "The Chargé in the Soviet Union (Kennan)")
            .contains { $0.contains("<w:outlineLvl w:val=\"1\"/>") }, "the volume's heading is not the document's")
    }

    @Test("Where the text does not print, a title stands over As published: and the volume's heading and dateline (#1998, J16)")
    func titleAtSummaryDepth() async throws {
        let titled = try await F.document(F.early, id: "d475", volume: "frus1946v06", depth: .summaryOnly,
                                          title: "The Long Telegram")
        let plan = CollectionDocumentPlan(document: titled, options: CollectionExportOptions())
        #expect(plan.lines.map(\.role) == [.title, .citation, .address, .volumeHeading, .dateline, .summary])
        let heading = try #require(plan.lines.first { $0.role == .volumeHeading })
        #expect(heading.label == "As published:" && heading.headingLevel == 3)
        #expect(plan.lines.first { $0.role == .dateline }?.text == "Moscow, February 22, 1946—9 p.m.")
        let html = F.page([.document(titled)], options: CollectionExportOptions())
        #expect(html.contains("<h3 class=\"doc-heading\"><span class=\"as-published\">As published: </span>The Chargé"))
        // 1.0's opening is unchanged: an untitled document at summary depth prints no volume's heading.
        let untitled = try await F.document(F.early, id: "d475", volume: "frus1946v06", depth: .summaryOnly)
        #expect(!CollectionDocumentPlan(document: untitled, options: CollectionExportOptions()).lines
            .contains { $0.role == .volumeHeading })
    }

    // MARK: The source note, once (#1991)

    @Test("The source note prints once, where the volume puts it: on the heading from 1955, as Source: before (#1991)")
    func sourceNoteOnce() async throws {
        var both = CollectionExportOptions()
        both.includeSourceNote = true
        // From 1955: the heading's note is kept among the footnotes, and the Source: line is left out.
        let modern = try await F.document(F.modern, id: "d1", sourceNote: F.modernSource)
        let modernPlan = CollectionDocumentPlan(document: modern, options: both)
        #expect(!modernPlan.lines.contains { $0.role == .sourceNote })
        var html = F.page([.document(modern)], options: both)
        #expect(html.components(separatedBy: "Carter Library, Presidential Papers").count - 1 == 2,
                "the source note's text is not in the popover and the notes list alone")
        #expect(!html.contains("class=\"source-note\""))
        // Before 1955: the labelled Source: line is kept, and the unlabelled copy and its glyph are left out.
        let early = try await F.document(F.early, id: "d475", volume: "frus1946v06", sourceNote: F.earlySource)
        let earlyPlan = CollectionDocumentPlan(document: early, options: both)
        #expect(earlyPlan.lines.contains { $0.role == .sourceNote && $0.text == F.earlySource })
        html = F.page([.document(early)], options: both)
        #expect(html.components(separatedBy: "861.00/2–2246").count - 1 == 1, "the note prints more than once")
        // The class with its element: the page's stylesheet, the reader's, names the class alone.
        #expect(!html.contains("class=\"fn-marker fn-marker-unnumbered\""), "the glyph of a note that does not print is drawn")
        #expect(html.contains("popovertarget=\"fn-doc-frus1946v06-d475-x-d475fn44\""), "note 44 stopped printing")
        let package = F.package([.document(early)], options: both)
        #expect(package.components(separatedBy: "861.00/2–2246").count - 1 == 1)
        // Footnotes off: the Source: line is the one copy, in either era, as in 1.0.
        var sourceOnly = both
        sourceOnly.includeFootnotes = false
        #expect(CollectionDocumentPlan(document: modern, options: sourceOnly).lines.contains { $0.role == .sourceNote })
        // Source note off: the footnote copy prints, as in 1.0.
        let footnotesOnly = CollectionExportOptions()
        let noLine = try await F.document(F.early, id: "d475", volume: "frus1946v06")
        #expect(F.page([.document(noLine)], options: footnotesOnly).contains("class=\"fn-marker fn-marker-unnumbered\""))
    }

    // MARK: A call with no note behind it (#2007)

    @Test("With footnotes off a call is the volume's number as text, and no button names a missing note (#2007)")
    func callsAsText() async throws {
        var off = CollectionExportOptions()
        off.includeFootnotes = false
        let early = try await F.document(F.early, id: "d475", volume: "frus1946v06")
        let html = try F.section(F.page([.document(early)], options: off), anchor: "doc-frus1946v06-d475")
        #expect(!html.contains("popovertarget"), "a call is still a button with no popover behind it")
        #expect(html.contains("[13]<sup class=\"fn-call\" data-skip=\"1\">44</sup>")
                && html.contains("<sup class=\"fn-call\" data-skip=\"1\">45</sup>"), "the volume's numbers are gone")
        #expect(!html.contains("fn-glyph") && !html.contains("\u{2022}"), "a mark of the app's own stays without its note")
        // The serializer's reader path is unchanged: every note, every call a button.
        let model = try #require(early.renderModel)
        let reader = FRUSRenderNodeHTMLSerializer().serialize(model)
        #expect(reader.components(separatedBy: "popovertarget=").count - 1 == 3)
    }

    // MARK: Word prints the volume's numbers (#2001)

    @Test("Word prints the volume's number at a call and at its note, never its own count (#2001)")
    func wordCustomMarks() async throws {
        let early = try await F.document(F.early, id: "d475", volume: "frus1946v06")
        let package = F.package([.document(early)], options: CollectionExportOptions())
        #expect(package.contains("[13]</w:t></w:r><w:r><w:rPr><w:rStyle w:val=\"FootnoteReference\"/></w:rPr>"
                                 + "<w:footnoteReference w:customMarkFollows=\"1\" w:id=\"2\"/>"
                                 + "<w:t xml:space=\"preserve\">44</w:t></w:r>"), "the call after [13] is not 44")
        #expect(package.contains("<w:footnote w:id=\"2\">"))
        let notes = try #require(package.range(of: "<w:footnotes")).lowerBound
        let notesPart = String(package[notes...])
        #expect(notesPart.contains("<w:rStyle w:val=\"FootnoteReference\"/></w:rPr><w:t xml:space=\"preserve\">44</w:t></w:r>"))
        #expect(notesPart.contains("<w:t xml:space=\"preserve\">45</w:t>"))
        #expect(!package.contains("<w:footnoteRef/>"), "a note opens on Word's own count")
        // The unnumbered source note, printed among the footnotes here, is marked as the PDF marks it.
        #expect(notesPart.contains("<w:t xml:space=\"preserve\">\u{2022}</w:t>"))
    }

    // MARK: No placeholder in an export (J10)

    @Test("A requested headnote with nothing stored prints nothing in an export, and its placeholder in the preview (J10)")
    func noPlaceholderInAnExport() async throws {
        let doc = try await F.document(F.modern, id: "d1", includeHeadnote: true, headnote: nil)
        let missing = "generate one in the document view"
        #expect(!F.page([.document(doc)], options: CollectionExportOptions()).contains(missing))
        #expect(!F.package([.document(doc)], options: CollectionExportOptions()).contains(missing))
        #expect(F.page([.document(doc)], options: CollectionExportOptions(), preview: true).contains(missing))
        #expect(!CollectionDocumentPlan(document: doc, options: CollectionExportOptions()).lines.contains { $0.role == .headnote })
    }

    // MARK: One heading rule for every level (J32)

    @Test("Each heading takes its level in the collection's outline, in the page and the package (J32)")
    func headingLevels() async throws {
        let doc = try await F.document(F.modern, id: "d1", title: "The first letter")
        let items: [CollectionExportItem] = [.heading("Part", level: 1), .heading("Chapter", level: 2),
                                             .heading("Section", level: 3), .document(doc)]
        let plan = CollectionExportPlan(items: items, options: CollectionExportOptions())
        #expect(plan.items.map(\.headingLevel) == [2, 3, 4, 5])
        let drawing = try #require(plan.items[3].document?.lines.first { $0.role == .text }?.drawing)
        #expect(drawing.headingLevel == 6 && drawing.attachmentHeadingLevel == 7 && drawing.notesHeadingLevel == 6)
        let html = F.page(items, options: CollectionExportOptions())
        #expect(html.contains("<h5 class=\"doc-lead\">The first letter</h5>"))
        #expect(html.contains("<h6 class=\"doc-heading\"><span class=\"as-published\" data-skip=\"1\">As published: </span>1. Letter From"))
        #expect(html.contains("<p class=\"attachment-heading\" role=\"heading\" aria-level=\"7\">Enclosure</p>"),
                "past six levels a heading is not drawn as a paragraph with its level")
        #expect(html.contains("<h6 class=\"fn-section-heading\">Footnotes</h6>"))
        let package = F.package(items, options: CollectionExportOptions())
        // The heading's paragraph, not the contents' row that names it first.
        #expect(F.paragraphs(in: package, holding: ">Chapter</w:t>").contains { $0.contains("<w:pStyle w:val=\"SectionHeading2\"/>") })
        #expect(F.paragraphs(in: package, holding: ">The first letter</w:t>").contains { $0.contains("<w:outlineLvl w:val=\"4\"/>") })
        #expect(F.paragraphs(in: package, holding: ">Enclosure</w:t>").first?.contains("<w:outlineLvl w:val=\"6\"/>") == true)
    }

    // MARK: The contents rows (#1993, #1994, #1998, #2002, J46)

    @Test("The contents rows number the documents alone, alike in the page and the package (#1993)")
    func contentsNumbers() async throws {
        let first = try await F.document(F.modern, id: "d1")
        let second = try await F.document(F.early, id: "d475", volume: "frus1946v06")
        let items: [CollectionExportItem] = [
            .heading("Part One", level: 1), .document(first), .heading("Part Two", level: 1), .document(second),
            .generated(CollectionGeneratedBlock(type: .bibliography, title: "Bibliography", rows: [])),
        ]
        let rows = CollectionContentsRow.rows(for: items, style: .citation)
        #expect(rows.map(\.number) == [nil, 1, nil, 2, nil])
        let html = F.page(items, options: CollectionExportOptions())
        #expect(html.contains("<ol role=\"list\">"))
        #expect(html.contains("<span class=\"toc-number\">1.</span>") && html.contains("<span class=\"toc-number\">2.</span>"))
        #expect(!html.contains("<span class=\"toc-number\">3.</span>"), "a section or a block is numbered")
        let package = F.package(items, options: CollectionExportOptions())
        #expect(package.contains("<w:t xml:space=\"preserve\">2. </w:t></w:r><w:r><w:rPr></w:rPr><w:t xml:space=\"preserve\">Foreign Relations"))
        // Each row links to its entry, and ends at its words: in the Word and Pages run no application
        // filled a page field (the owner's choice of 2026-11-27, Drop the field).
        #expect(package.contains("<w:hyperlink w:anchor=\"frus_row_4\" w:history=\"1\">"))
        #expect(package.contains("<w:bookmarkStart w:id=\"4\" w:name=\"frus_row_4\"/>"))
        #expect(!package.contains("PAGEREF") && !package.contains("w:leader=\"dot\""))
        #expect(!package.contains("TOC \\o"), "Word's contents is still a field it rebuilds from the styles")
    }

    @Test("A Header & Dateline row reads the heading's words and the dateline, never a second number (#1994, #2002)")
    func headerAndDatelineRows() async throws {
        let modern = try await F.document(F.modern, id: "d1")
        let early = try await F.document(F.early, id: "d475", volume: "frus1946v06")
        let closer = try await F.document(F.closerDateline, id: "d9")
        let rows = CollectionContentsRow.rows(for: [.document(modern), .document(early), .document(closer)],
                                              style: .headerAndDateline)
        #expect(rows.map(\.numberedText) == [
            "1. Letter From President Carter to Soviet General Secretary Brezhnev — Washington, January 26, 1977.",
            "2. The Chargé in the Soviet Union (Kennan) to the Secretary of State — Moscow, February 22, 1946—9 p.m.",
            "3. Letter From Chairman Khrushchev to President Kennedy — Moscow, October 26, 1962.",
        ])
        let noLines = rows.allSatisfy { $0.lines.isEmpty }
        #expect(noLines)
    }

    @Test("A titled row has As published: and the volume's heading under it, and the citation after them in Citation style (#1998, J46)")
    func titledRows() async throws {
        let titled = try await F.document(F.modern, id: "d1", title: "The first letter")
        let byHeader = CollectionContentsRow.rows(for: [.document(titled)], style: .headerAndDateline)[0]
        #expect(byHeader.text == "The first letter")
        #expect(byHeader.lines == ["As published: 1. Letter From President Carter to Soviet General Secretary Brezhnev — Washington, January 26, 1977."])
        let byCitation = CollectionContentsRow.rows(for: [.document(titled)], style: .citation)[0]
        #expect(byCitation.lines == ["As published: 1. Letter From President Carter to Soviet General Secretary Brezhnev",
                                     "Foreign Relations of the United States, _Volume VI_, Document 1."])
        let html = F.page([.document(titled)], options: CollectionExportOptions())
        #expect(html.contains("<span class=\"toc-line\">As published: 1. Letter From President Carter"))
    }

    /// L49 (the owner's "Wherever a document repeats"): a row cites its document by the short form the assembly made,
    /// under the author's title too, since the export prints the full citation at the document's head; a document
    /// made with no short form, as a host may make one, keeps the full citation, as every row did before L49.
    @Test("A row cites its document by the short form, under a title too, and in full where none was made (L49)")
    func shortFormRows() {
        let full = "_Foreign Relations of the United States_, 1946, Eastern Europe, The Soviet Union, Volume VI, Document 475."
        let short = "_FRUS_, 1946, vol. VI, doc. 475."
        func document(title: String? = nil, shortCitation: String) -> CollectionExportDocument {
            CollectionExportDocument(documentId: "d475", volumeId: "frus1946v06", sortOrder: 0,
                                     title: "frus1946v06 — d475", titleOverride: title, bodyText: "",
                                     citation: full, shortCitation: shortCitation,
                                     header: "475. The Chargé in the Soviet Union (Kennan) to the Secretary of State")
        }
        func row(_ doc: CollectionExportDocument) -> CollectionContentsRow {
            CollectionContentsRow.rows(for: [.document(doc)], style: .citation)[0]
        }
        #expect(row(document(shortCitation: short)).text == short)
        let titled = row(document(title: "The Long Telegram", shortCitation: short))
        #expect(titled.text == "The Long Telegram")
        #expect(titled.lines == ["As published: 475. The Chargé in the Soviet Union (Kennan) to the Secretary of State",
                                 short], "\(titled.lines)")
        #expect(row(document(shortCitation: "")).text == full)
    }

    // MARK: #2005 and decision 165

    @Test("A headnote the app's model wrote names the model among the export's sources (#2005)")
    func generatedHeadnoteSource() async throws {
        var doc = try await F.document(F.modern, id: "d1", includeHeadnote: true, headnote: "The President writes early.")
        #expect([CollectionExportItem.document(doc)].provenanceSources.contains(.appModel))
        doc = try await F.document(F.modern, id: "d1", includeHeadnote: true, headnote: nil)
        #expect(![CollectionExportItem.document(doc)].provenanceSources.contains(.appModel), "a headnote that does not print")
        let written = CollectionExportDocument(documentId: "d1", volumeId: "v", sortOrder: 0, title: "t", bodyText: "",
                                               includeHeadnote: true, headnoteText: "Mine.", headnoteAuthorship: .userWritten)
        #expect(![CollectionExportItem.document(written)].provenanceSources.contains(.appModel))
    }

    @Test("A citation record's title names the document's number once, and no call (decision 165)")
    func recordTitles() async throws {
        let volume = FRUSVolumeMetadata(title: "Foreign Relations of the United States, 1977–1980, Volume VI, Soviet Union",
                                        editors: [], generalEditor: nil, publicationDate: "2013",
                                        publicationPlace: "Washington", publisher: "GPO")
        func title(_ header: String, _ number: String?) -> String {
            ZoteroJSONExporter.makeItem(document: FRUSDocumentMetadata(documentId: "d1", documentNumber: number,
                                                                       header: header, dateline: nil),
                                        volume: volume, year: "2013", url: nil, isEditorialNote: false).title
        }
        #expect(title("1. Letter From President Carter to Soviet General Secretary Brezhnev", "1")
                == "Document 1: Letter From President Carter to Soviet General Secretary Brezhnev")
        #expect(title("No. 98. Mr. Fish to Mr. Mathews.", "100") == "Document 100: Mr. Fish to Mr. Mathews.")
        #expect(title("No. 2.", "95") == "Document 95: No. 2.", "a heading that is its number alone")
        #expect(title("No. 98. Mr. Fish to Mr. Mathews.", nil) == "No. 98. Mr. Fish to Mr. Mathews.")
        #expect(title("", "7") == "Document 7: d1")
        // The collection's record of the fixture reads its heading through the one reading: no "[1]".
        let doc = try await F.document(F.modern, id: "d1")
        #expect(!doc.header.contains("["))
    }
}

// MARK: - CollectionFactsPlanTests (L43)

/// The new facts a collection's plan reads (L43): the author's date line under a title, the collection's own words
/// for the export's labels, and the options a collection's values give.
@Suite("L43: the date line, the collection's words and its facts in the plan")
struct CollectionFactsPlanTests {

    typealias F = PlanFixtures

    /// `doc` with `dateLine`, as the assembly resolves an entry that stores one.
    static func withDateLine(_ doc: CollectionExportDocument, _ dateLine: String?) -> CollectionExportDocument {
        CollectionExportDocument(
            documentId: doc.documentId, volumeId: doc.volumeId, sortOrder: doc.sortOrder, bodyDepth: doc.bodyDepth,
            title: doc.title, titleOverride: doc.titleOverride, dateLine: dateLine, bodyText: doc.bodyText,
            noteTexts: doc.noteTexts, citation: doc.citation, historyStateGovURL: doc.historyStateGovURL,
            renderModel: doc.renderModel, header: doc.header, dateline: doc.dateline,
            sourceNoteText: doc.sourceNoteText, includeHeadnote: doc.includeHeadnote, headnoteText: doc.headnoteText,
            relatedDocumentCitations: doc.relatedDocumentCitations)
    }

    /// Decision 163, the design's §3.3: the author's date line stands under their title, above the citation and the
    /// words *As published:*, in the plan, the web page and Word.
    @Test("The author's date line stands under the title, above the citation, in the plan, the page and Word")
    func dateLineUnderTitle() async throws {
        let titled = Self.withDateLine(
            try await F.document(F.early, id: "d475", volume: "frus1946v06", title: "The Long Telegram"),
            "  Moscow, 22 February 1946 ")
        let plan = CollectionDocumentPlan(document: titled, options: CollectionExportOptions())
        #expect(plan.lines.map(\.role).prefix(4) == [.title, .titleDateLine, .citation, .address])
        #expect(plan.lines[1].text == "Moscow, 22 February 1946", "trimmed")
        #expect(plan.lines[1].headingLevel == nil, "the date line is no heading")

        let html = try F.section(F.page([.document(titled)], options: CollectionExportOptions()),
                                 anchor: "doc-frus1946v06-d475")
        let title = try #require(html.range(of: "<h2 class=\"doc-lead\">The Long Telegram</h2>"))
        let line = try #require(html.range(of: "<p class=\"dateline title-date-line\">Moscow, 22 February 1946</p>"))
        let published = try #require(html.range(of: "As published: </span>"))
        #expect(title.upperBound <= line.lowerBound && line.upperBound <= published.lowerBound, "out of order")

        let package = F.package([.document(titled)], options: CollectionExportOptions())
        let paragraphs = F.paragraphs(in: package, holding: "Moscow, 22 February 1946</w:t>")
        #expect(paragraphs.contains { $0.contains("<w:pStyle w:val=\"Dateline\"/>") }, "\(paragraphs)")

        let row = CollectionContentsRow.rows(for: [.document(titled)], style: .citation)[0]
        #expect(row.text == "The Long Telegram — Moscow, 22 February 1946", "the row names the title and its date line")
    }

    /// The third review's J41: a date line is given only under a title, and one stored without a title, as 1.0 leaves
    /// it when a title is cleared, prints nowhere: not in the plan, the page, Word or the contents row.
    @Test("A date line with no title prints nowhere (J41)")
    func dateLineWithoutTitle() async throws {
        let untitled = Self.withDateLine(try await F.document(F.early, id: "d475", volume: "frus1946v06"),
                                         "Moscow, 22 February 1946")
        #expect(untitled.printedDateLine == nil)
        let plan = CollectionDocumentPlan(document: untitled, options: CollectionExportOptions())
        #expect(!plan.lines.contains { $0.role == .titleDateLine })
        #expect(!F.page([.document(untitled)], options: CollectionExportOptions()).contains("22 February 1946"))
        #expect(!F.package([.document(untitled)], options: CollectionExportOptions()).contains("22 February 1946"))
        let row = CollectionContentsRow.rows(for: [.document(untitled)], style: .headerAndDateline)[0]
        #expect(!row.text.contains("22 February"))
        // An empty date line under a title prints nothing either.
        let blank = Self.withDateLine(try await F.document(F.early, id: "d475", volume: "frus1946v06",
                                                           title: "The Long Telegram"), "   ")
        #expect(blank.printedDateLine == nil)
    }

    /// The design's §5.2: the collection's own words print where the app's would, in the plan's labels and the
    /// contents heading of the page and Word; *Source:* and *As published:* are not the author's to change.
    @Test("The collection's own words print over the headnote, summary, See also, research note and contents")
    func wordingPrints() async throws {
        var json: String?
        for (label, word) in [(CollectionWording.Label.headnote, "Abstract"), (.researchNote, "Commentary"),
                              (.seeAlso, "Compare"), (.contents, "Documents"), (.bibliography, "Works Cited")] {
            json = CollectionWording.updating(json, label: label, with: word)
        }
        var options = CollectionExportOptions()
        options.wording = CollectionWording(json: json)
        let base = try await F.document(F.early, id: "d475", volume: "frus1946v06", sourceNote: F.earlySource,
                                        notes: ["My note."], includeHeadnote: true, headnote: "Kennan's answer.")
        let doc = CollectionExportDocument(
            documentId: base.documentId, volumeId: base.volumeId, sortOrder: 0, title: base.title, bodyText: base.bodyText,
            noteTexts: base.noteTexts, citation: base.citation, historyStateGovURL: base.historyStateGovURL,
            renderModel: base.renderModel, header: base.header, dateline: base.dateline,
            sourceNoteText: base.sourceNoteText, includeHeadnote: true, headnoteText: "Kennan's answer.",
            relatedDocumentCitations: ["Foreign Relations of the United States, Document 473."])
        let plan = CollectionDocumentPlan(document: doc, options: options)
        #expect(plan.lines.first { $0.role == .headnote }?.label == "Abstract")
        #expect(plan.lines.first { $0.role == .researchNote }?.label == "Commentary")
        #expect(plan.lines.first { $0.role == .seeAlso }?.label == "Compare")
        #expect(plan.lines.first { $0.role == .sourceNote }?.label == CollectionDocumentPlan.sourceLabel, "Source: is fixed")

        #expect(F.page([.document(doc)], options: options).contains("<h2>Documents</h2>"))
        #expect(F.package([.document(doc)], options: options).contains(">Documents</w:t>"))
        // The app's words where the collection has none.
        #expect(F.page([.document(doc)], options: CollectionExportOptions()).contains("<h2>Contents</h2>"))

        // A block takes the collection's word for its title, and keeps the app's where there is none.
        let block = CollectionGeneratedBlock(type: .bibliography, title: CollectionGeneratedBlockType.bibliography.displayName,
                                             rows: [])
        #expect(CollectionContentAssembly.worded(block, options: options).title == "Works Cited")
        let chronology = CollectionGeneratedBlock(type: .chronology, title: "Chronology", rows: [])
        #expect(CollectionContentAssembly.worded(chronology, options: options).title == "Chronology")
    }

    /// The design's §7.3, the first review's first finding: the labels are one map, read and written as a plain map,
    /// so a build that does not know a label's name carries it through an edit of another.
    @Test("A label this build does not know survives an edit of another")
    func unknownLabelSurvives() throws {
        let later = #"{"marginalia":"Margin notes","headnote":"Abstract"}"#
        let edited = try #require(CollectionWording.updating(later, label: .contents, with: "Documents"))
        let map = try JSONDecoder().decode([String: String].self, from: Data(edited.utf8))
        #expect(map == ["marginalia": "Margin notes", "headnote": "Abstract", "contents": "Documents"])
        // Emptying a label, or giving it the app's own word, returns it to the app's word; the rest stay.
        let cleared = try #require(CollectionWording.updating(edited, label: .headnote, with: "  "))
        #expect(CollectionWording(json: cleared).ownWord(for: .headnote) == nil)
        #expect(CollectionWording(json: cleared).storedWords["marginalia"] == "Margin notes")
        let appWord = CollectionWording.updating(cleared, label: .contents, with: CollectionWording.Label.contents.appWord)
        #expect(CollectionWording(json: appWord).ownWord(for: .contents) == nil)
        #expect(CollectionWording(json: appWord).storedWords == ["marginalia": "Margin notes"])
        // The last own word gone leaves nothing to store; a value that is not a map reads as the app's words.
        #expect(CollectionWording.updating(#"{"contents":"Documents"}"#, label: .contents, with: "") == nil)
        #expect(CollectionWording(json: "not json").text(for: .summary) == CollectionWording.Label.summary.appWord)
        #expect(CollectionWording(json: later).rewordedLabels == [.headnote])
    }

    /// J16: where the volume's heading leads, the document's region is named by its citation's number, which a Chicago
    /// or Turabian note gives as "doc. 475" (L43).
    @Test("A note's doc. N names the document's region as History at State's Document N does (J16)")
    func regionNameFromANote() {
        #expect(CollectionDocumentPlan.citationNumber("…(Government Printing Office, 1969), Document 475.") == "Document 475")
        #expect(CollectionDocumentPlan.citationNumber("…, in _Foreign Relations_, vol. 6 (Government Printing Office, 1969), doc. 475.")
                == "Document 475")
        #expect(CollectionDocumentPlan.citationNumber("Memorandum, Washington, May 5, 1962, in _FRUS_ (GPO, 1960).") == nil)
    }

    /// The options a collection's values give (L43): each fact read as 1.0 prints where it is absent or unknown.
    @Test("A collection's values give its style, opening, words and See also; absent ones read as 1.0's")
    func optionsReadTheFacts() {
        let untouched = CollectionExportOptions(composing: CollectionExport(id: UUID(), name: "1.0's", projectIds: [],
                                                                            entries: []))
        #expect(untouched.citationStyle == .historyAtState && !untouched.volumeHeadingLeads)
        #expect(untouched.wording == CollectionWording() && !untouched.includeRelatedDocumentsDefault)

        let set = CollectionExportOptions(composing: CollectionExport(
            id: UUID(), name: "1.1's", projectIds: [], entries: [], citationStyle: "turabian", opening: "volumeHeading",
            labelsJSON: #"{"contents":"Documents"}"#, defaultIncludeRelatedDocuments: true))
        #expect(set.citationStyle == .turabian && set.volumeHeadingLeads && set.includeRelatedDocumentsDefault)
        #expect(set.wording.text(for: .contents) == "Documents")

        let unknown = CollectionExportOptions(composing: CollectionExport(
            id: UUID(), name: "A later build's", projectIds: [], entries: [], citationStyle: "mla", opening: "margin"))
        #expect(unknown.citationStyle == .historyAtState && !unknown.volumeHeadingLeads)
    }
}

// MARK: - CollectionDocumentCopyAnchorTests

/// A document entered twice is two places on the web page (L36, #2004): each copy has its own section,
/// contents row and note ids, and a document entered once keeps the anchor it has always had.
@Suite("L36: a document entered twice is two places on the web page (#2004)")
struct CollectionDocumentCopyAnchorTests {

    private typealias F = PlanFixtures

    /// The values of every `attribute="…"` in `html`, in order.
    static func values(of attribute: String, in html: String) -> [String] {
        var values: [String] = []
        var rest = html[...]
        while let start = rest.range(of: " \(attribute)=\"") {
            let tail = rest[start.upperBound...]
            guard let end = tail.firstIndex(of: "\"") else { break }
            values.append(String(tail[..<end]))
            rest = tail[end...]
        }
        return values
    }

    /// The page's contents list, from `<nav>` to `</nav>`.
    static func contents(_ html: String) throws -> String {
        let start = try #require(html.range(of: "<nav>"))
        let end = try #require(html.range(of: "</nav>", range: start.upperBound..<html.endIndex))
        return String(html[start.lowerBound..<end.upperBound])
    }

    @Test("Each id is written once, each contents row leads to its own copy, and the second copy's calls open its own notes")
    func aDocumentEnteredTwiceIsTwoPlaces() async throws {
        let doc = try await F.document(F.modern, id: "d1", sourceNote: F.modernSource)
        let items: [CollectionExportItem] = [.document(doc), .heading("Part Two", level: 1), .document(doc)]
        for preview in [false, true] {
            let page = preview ? "the preview" : "the export"
            let html = F.page(items, options: CollectionExportOptions(), preview: preview)
            let ids = Self.values(of: "id", in: html)
            let repeated = Set(ids.filter { id in ids.filter { $0 == id }.count > 1 }).sorted()
            #expect(repeated.isEmpty, "\(page) writes these ids more than once: \(repeated)")
            let rows = Self.values(of: "href", in: try Self.contents(html))
                .filter { $0.hasPrefix("#") }.map { String($0.dropFirst()) }
            #expect(rows == ["doc-frus1977-80v06-d1", "doc-frus1977-80v06-d1_2"],
                    "\(page)'s contents rows lead to \(rows)")
            for row in rows {
                #expect(html.contains("<section id=\"\(row)\""), "\(page) has no section for its row \(row)")
            }
            guard rows.count == 2, rows[0] != rows[1] else { continue }
            let second = try F.section(html, anchor: rows[1])
            let calls = Self.values(of: "popovertarget", in: second)
            #expect(!calls.isEmpty, "\(page)'s second copy has no note call to follow")
            let own = Set(Self.values(of: "id", in: second))
            for call in calls {
                #expect(own.contains(call), "in \(page) a call in the second copy opens \(call), outside it")
            }
        }
    }

    @Test("A document entered once keeps the anchor it has always had, and so do its notes")
    func aDocumentEnteredOnceKeepsItsAnchor() async throws {
        let doc = try await F.document(F.modern, id: "d1", sourceNote: F.modernSource)
        let other = try await F.document(F.early, id: "d475", volume: "frus1946v06")
        let html = F.page([.document(doc), .document(other)], options: CollectionExportOptions())
        #expect(html.contains("<section id=\"doc-frus1977-80v06-d1\""))
        #expect(html.contains("<section id=\"doc-frus1946v06-d475\""))
        #expect(!html.contains("d1_") && !html.contains("d475_"), "a document entered once was numbered as a copy")
        #expect(Self.values(of: "popovertarget", in: html).allSatisfy { $0.hasPrefix("fn-doc-frus1977-80v06-d1-") || $0.hasPrefix("fn-doc-frus1946v06-d475-") },
                "a note's id is no longer scoped by its document's anchor")
    }

    @Test("The numbering is by anchor: a third entry is _3, and two ids the sanitiser writes alike are two places too")
    func theNumberingIsByAnchor() {
        let keys: [(volumeId: String, documentId: String)] = [
            ("frus1946v06", "d475"), ("frus1946v06", "d1"), ("frus1946v06", "d475"), ("frus1946v06", "d475"),
            ("frus1946v06", "a_b"), ("frus1946v06", "a-b"),
        ]
        #expect(CollectionItemHTMLRenderer.anchorIds(forKeys: keys) == [
            "doc-frus1946v06-d475", "doc-frus1946v06-d1", "doc-frus1946v06-d475_2", "doc-frus1946v06-d475_3",
            "doc-frus1946v06-a-b", "doc-frus1946v06-a-b_2",
        ])
        #expect(CollectionItemHTMLRenderer.anchorIds(forKeys: []).isEmpty)
    }
}
