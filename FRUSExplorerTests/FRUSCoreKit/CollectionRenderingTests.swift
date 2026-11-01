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
// SHA-256 is CryptoKit's on Apple platforms; on Linux the web edition supplies swift-crypto's Crypto.
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

// MARK: - CollectionRenderingFixtures

/// Collections as values, for the suites below: every item kind the exporters render, every
/// composition option, the publication frame, figures and a word cloud.
///
/// Everything an export reads is in the values, its date included: a day fixed in a calendar
/// fixed, so the Word cover and the colophon print "October 25, 2026" wherever the suite runs.
///
/// Version history:
///   1.0 — 2026-10-25 (FRUS Explorer Light, S18a): initial implementation, with the exporters'
///          move into the kit
///   1.1 — 2026-10-31: the everything collection holds a structured summary (`d11`, `meeting`), at
///          summary depth with a structured headnote
enum CollectionRenderingFixtures {

    /// The Meeting Record template's fields, as `SummarizationPromptSeeder` seeds them.
    static let meeting = StructuredSummarySchema(fields: [
        .init(name: "KeyParticipants", description: "Principal speakers"),
        .init(name: "Topics", description: "Main subjects discussed"),
        .init(name: "Agreements", description: "Points of consensus"),
        .init(name: "Disagreements", description: "Points of divergence"),
    ])

    /// A headnote's fields.
    static let headnoteFields = StructuredSummarySchema(fields: [
        .init(name: "Subject", description: ""), .init(name: "Outcome", description: ""),
    ])

    /// 2026-10-25 at noon UTC, written in `en_US`, read in UTC.
    static let exportDate = CollectionExportDate(
        date: Date(timeIntervalSince1970: 1_792_929_600),
        locale: Locale(identifier: "en_US"),
        timeZone: TimeZone(identifier: "UTC"))

    /// A 3×2 PNG, a figure's image.
    static let figurePNG = Data(base64Encoded:
        "iVBORw0KGgoAAAANSUhEUgAAAAMAAAACCAIAAAASFvFNAAAAEElEQVR42mM4IScHQQxwFgBBAAYZ1ETuGQAAAABJRU5ErkJggg==")!

    /// A 4×1 PNG, the word cloud.
    static let cloud = CollectionWordCloud(
        png: Data(base64Encoded:
            "iVBORw0KGgoAAAANSUhEUgAAAAQAAAABCAIAAAB2XpiaAAAADUlEQVR42mOQszkBRwAa2QSJDqOG5AAAAABJRU5ErkJggg==")!,
        pixelWidth: 4, pixelHeight: 1)

    /// Every figure's image is the same three-by-two PNG, whatever its volume.
    struct FixedFigureImages: FigureImageSource {
        func data(for image: FigureImageName) -> Data? { image.graphic == "fig1" ? CollectionRenderingFixtures.figurePNG : nil }
    }

    /// A telegram with a source note and a footnote, italics and bold, a labelled list with a head,
    /// a table, a figure with a head and a closer.
    static let telegramXML = """
    <div type="document" subtype="historical-document" n="7" xml:id="d7">
      <head>7. Telegram From the Embassy in France to the Department of State<note n="0" type="source" xml:id="d7fn0">Source: Department of State, Central Files, 611.3722/10–2262. Secret; Niact.</note></head>
      <opener><dateline rendition="#right"><placeName>Paris</placeName>, <date calendar="gregorian" when="1962-10-22">October 22, 1962</date>, 5 p.m.</dateline></opener>
      <p>The Ambassador saw the Foreign Minister <hi rend="italic">this morning</hi> and spoke of <hi rend="strong">the quarantine</hi>.<note n="1" xml:id="d7fn1">See Document 6.</note></p>
      <list>
        <head>Points made:</head>
        <label>1.</label>
        <item>The line would hold.</item>
        <label>2.</label>
        <item>The allies had been told.</item>
      </list>
      <table cols="2">
        <row><cell>Ship</cell><cell>Position</cell></row>
        <row><cell>Alpha</cell><cell>North of the line</cell></row>
      </table>
      <figure>
        <head>The quarantine line</head>
        <graphic url="fig1"/>
      </figure>
      <closer><signed><persName corresp="#p_GJ1">Gavin</persName></signed></closer>
    </div>
    """

    /// A memorandum with small capitals and a footnote in the middle of a paragraph.
    static let memorandumXML = """
    <div type="document" subtype="historical-document" n="8" xml:id="d8">
      <head>8. Memorandum From the President’s Special Assistant (<persName corresp="#p_BMG1">Bundy</persName>) to President Kennedy</head>
      <opener><dateline rendition="#right"><placeName>Washington</placeName>, <date calendar="gregorian" when="1962-10-23">October 23, 1962</date>.</dateline></opener>
      <p rend="center"><hi rend="smallcaps">Subject</hi></p>
      <p>The Executive Committee met at 10 a.m.<note n="1" xml:id="d8fn1">No record of the meeting has been found.</note> It agreed on the text of the proclamation.</p>
    </div>
    """

    /// `text`'s UTF-16 range in `flat`, as a highlight stores it.
    static func highlight(_ text: String, in flat: String, color: HighlightColor) throws -> ExportHighlight {
        let range = try #require(flat.range(of: text), "the flat text has no \(text.debugDescription)")
        let start = flat.utf16.distance(from: flat.utf16.startIndex, to: range.lowerBound)
        return ExportHighlight(startOffset: start, endOffset: start + text.utf16.count, color: color)
    }

    static func span(_ text: String, bold: Bool = false, italic: Bool = false, underline: Bool = false,
                     color: String? = nil, link: String? = nil) -> ProseFormattedSpan {
        ProseFormattedSpan(text: text, bold: bold, italic: italic, underline: underline, colorHex: color,
                           linkURL: link)
    }

    static func zoteroItem(_ title: String, volume: String, document: String, note: String) -> ZoteroJSONExporter.Item {
        ZoteroJSONExporter.Item(
            itemType: "bookSection", title: title,
            creators: [ZoteroJSONExporter.Creator(creatorType: "editor", name: "Edward C. Keefer")],
            bookTitle: "Foreign Relations of the United States, 1961–1963, Volume XI, Cuban Missile Crisis and Aftermath",
            date: "1996", publisher: "United States Government Printing Office", place: "Washington",
            url: "https://history.state.gov/historicaldocuments/\(volume)/\(document)",
            extra: "Document 7", tags: [ZoteroJSONExporter.Tag(tag: "Quarantine")],
            notes: [ZoteroJSONExporter.Note(note: note)])
    }

    /// The everything collection: every item kind, at every body depth, with every per-document
    /// override, under the full publication frame, its word cloud and its figures.
    static func everything() async throws -> (metadata: CollectionExportMetadata, items: [CollectionExportItem],
                                              options: CollectionExportOptions) {
        let telegram = try await ListShapeFixtures.renderModel(telegramXML)
        let memorandum = try await ListShapeFixtures.renderModel(memorandumXML)
        let flat = buildFlatText(from: telegram)
        let volume = "frus1961-63v11"
        let metadata = CollectionExportMetadata(
            name: "  The Crisis: A Reader  ", note: "Cables and memoranda of _October 1962_.",
            subtitle: "A _documentary_ record", authorLine: "Compiled by A. Researcher",
            projectName: "Crisis Diplomacy", projectResearchQuestion: "How did _quarantine_ become the word?",
            includeColophon: true,
            methodAppendixLines: ["Method", "Searched “quarantine” in 3 volumes.", "", "Read 12 documents."],
            exportDate: exportDate)
        let items: [CollectionExportItem] = [
            .prose([
                [span("An "), span("introduction", bold: true), span(" with "),
                 span("a link", link: "https://history.state.gov/"), span(".")],
                [span("A second paragraph,\nwith a line break, in "), span("colour", color: "CC1919"),
                 span(" and "), span("underlined italics", italic: true, underline: true), span(".")],
            ]),
            .heading("Part I: _The Discovery_", level: 1),
            .document(CollectionExportDocument(
                documentId: "d7", volumeId: volume, sortOrder: 1, bodyDepth: .full,
                title: "Cuban Missile Crisis — d7", date: "1962-10-22", bodyText: flat,
                noteTexts: ["Compare the _Paris_ reading\n\nwith London's.", "A second note."],
                citation: "Foreign Relations of the United States, 1961–1963, _Volume XI_, Document 7.",
                historyStateGovURL: "https://history.state.gov/historicaldocuments/\(volume)/d7",
                renderModel: telegram, header: "7. Telegram From the Embassy in France",
                dateline: "Paris, October 22, 1962, 5 p.m.",
                highlights: [try highlight("this morning", in: flat, color: .yellow),
                             try highlight("the quarantine", in: flat, color: .blue)],
                sourceNoteText: "Source: Department of State, Central Files, 611.3722/10–2262. Secret; Niact.",
                includeHeadnote: true, headnoteText: "The Embassy reports the Foreign Minister's view.",
                headnoteAuthorship: .aiGenerated,
                relatedDocumentCitations: ["Foreign Relations of the United States, 1961–1963, _Volume XI_, Document 8."],
                zoteroItem: zoteroItem("Telegram From the Embassy in France", volume: volume, document: "d7",
                                       note: "Compare the Paris reading."))),
            .heading("Section A", level: 2),
            .excerpt(CollectionExportExcerpt(
                text: "First paragraph of the quotation.\n\nSecond paragraph, \"quoted\" <verbatim> & kept.",
                documentId: "d7", volumeId: volume,
                citation: "Foreign Relations of the United States, 1961–1963, _Volume XI_, Document 7.",
                colorTag: "yellow")),
            .heading("Subsection i", level: 3),
            .document(CollectionExportDocument(
                documentId: "d8", volumeId: volume, sortOrder: 2, bodyDepth: .summaryOnly,
                title: "Cuban Missile Crisis — d8", bodyText: "", noteText: "A note on the summary.",
                citation: "Foreign Relations of the United States, 1961–1963, _Volume XI_, Document 8.",
                historyStateGovURL: "https://history.state.gov/historicaldocuments/\(volume)/d8",
                renderModel: memorandum, header: "8. Memorandum", summaryText: "Bundy reports.\n\nThe text is agreed.",
                includeHeadnote: true, headnoteText: "An edited headnote.", headnoteAuthorship: .aiEdited,
                zoteroItem: zoteroItem("Memorandum From the President’s Special Assistant", volume: volume,
                                       document: "d8", note: "On the proclamation."))),
            .document(CollectionExportDocument(
                documentId: "d9", volumeId: volume, sortOrder: 3, bodyDepth: .index,
                title: "Cuban Missile Crisis — d9", bodyText: "Not printed at index depth.",
                noteTexts: ["An index entry's note."], citation: "",
                historyStateGovURL: "")),
            .document(CollectionExportDocument(
                documentId: "d10", volumeId: "frus1958-60v06", sortOrder: 4, bodyDepth: .full,
                title: "Cuba — d10", titleOverride: "The _Havana_ despatch",
                bodyText: "The first paragraph of a body with no model.\n\nThe second, on two\nlines.",
                noteTexts: ["Not printed: the override turns notes off."],
                citation: "Foreign Relations of the United States, 1958–1960, Volume VI, Document 10.",
                historyStateGovURL: "https://history.state.gov/historicaldocuments/frus1958-60v06/d10",
                includeHeadnote: true, headnoteText: "A headnote written by hand.",
                headnoteAuthorship: .userWritten, includeNotesOverride: false)),
            .document(CollectionExportDocument(
                documentId: "d7", volumeId: "frus1961-63v11b", sortOrder: 5, bodyDepth: .full,
                title: "Cuban Missile Crisis — d7 again", bodyText: flat,
                citation: "Foreign Relations of the United States, 1961–1963, Volume XI, Document 7, again.",
                historyStateGovURL: "https://history.state.gov/historicaldocuments/frus1961-63v11b/d7",
                renderModel: telegram,
                highlights: [try highlight("this morning", in: flat, color: .green)],
                includeHeadnote: true, headnoteText: nil,
                applyHighlightsOverride: false, includeFootnotesOverride: false)),
            // A structured summary and headnote, stored as their JSON: members out of the schema's
            // order, an empty field, and text the page and the package escape.
            .document(CollectionExportDocument(
                documentId: "d11", volumeId: volume, sortOrder: 6, bodyDepth: .summaryOnly,
                title: "Cuban Missile Crisis — d11", bodyText: "",
                citation: "Foreign Relations of the United States, 1961–1963, _Volume XI_, Document 11.",
                historyStateGovURL: "https://history.state.gov/historicaldocuments/\(volume)/d11",
                summaryText: #"{"Disagreements": "", "Topics": "The quarantine & its <terms>", "KeyParticipants": "The President; Bundy"}"#,
                summaryFormat: .structured(schema: meeting),
                includeHeadnote: true, headnoteText: #"{"Outcome": "Agreed.", "Subject": "The \"quarantine\""}"#,
                headnoteFormat: .structured(schema: headnoteFields), headnoteAuthorship: .aiGenerated)),
            .excerpt(CollectionExportExcerpt(text: "An unattributed passage.", documentId: "", volumeId: "",
                                             citation: "", colorTag: nil)),
            .generated(CollectionGeneratedBlock(type: .archivalSources, title: "Sources & Archives", rows: [
                CollectionGeneratedRow(text: "Record Group 59"),
                CollectionGeneratedRow(text: "Central Files", secondaryText: "Documents 7, 8",
                                       url: "https://catalog.archives.gov/id/302021", indentLevel: 1),
                CollectionGeneratedRow(text: "_Lot_ 66 D 110", indentLevel: 2),
            ])),
            .generated(CollectionGeneratedBlock(type: .bibliography, title: "Bibliography", rows: [
                CollectionGeneratedRow(text: "Foreign Relations of the United States, 1961–1963, _Volume XI_, Document 7."),
            ])),
        ]
        var options = CollectionExportOptions()
        options.includeSourceNote = true
        options.applyHighlights = true
        options.includeWordCloud = true
        return (metadata, items, options)
    }

    /// The plain collection: no frame, no heading, no prose; contents by header and dateline, no
    /// footnotes, highlights or notes, and no word cloud.
    static func plain() async throws -> (metadata: CollectionExportMetadata, items: [CollectionExportItem],
                                         options: CollectionExportOptions) {
        let telegram = try await ListShapeFixtures.renderModel(telegramXML)
        let memorandum = try await ListShapeFixtures.renderModel(memorandumXML)
        let metadata = CollectionExportMetadata(name: "", note: nil, exportDate: exportDate)
        let items: [CollectionExportItem] = [
            .document(CollectionExportDocument(
                documentId: "d7", volumeId: "frus1961-63v11", sortOrder: 0, title: "Cuban Missile Crisis — d7",
                bodyText: buildFlatText(from: telegram), noteText: "Hidden by the options.",
                citation: "Foreign Relations of the United States, 1961–1963, Volume XI, Document 7.",
                historyStateGovURL: "https://history.state.gov/historicaldocuments/frus1961-63v11/d7",
                renderModel: telegram, header: "7. Telegram From the Embassy in France to the Department of State",
                dateline: "Paris, October 22, 1962, 5 p.m.")),
            .document(CollectionExportDocument(
                documentId: "d8", volumeId: "frus1961-63v11", sortOrder: 1, title: "Cuban Missile Crisis — d8",
                bodyText: buildFlatText(from: memorandum), renderModel: memorandum, header: "",
                dateline: nil)),
        ]
        let options = CollectionExportOptions(tocStyle: .headerAndDateline, includeFootnotes: false,
                                              applyHighlights: false, includeNotes: false)
        return (metadata, items, options)
    }

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - CollectionRenderingPinTests

/// What the kit's exporters write for the collections above, pinned by SHA-256 and length: the HTML
/// page, the Word package, the BibTeX and the RIS. The suite runs in Xcode, in `swift test` on a Mac
/// and on Linux in FRUS Explorer Light's CI, so passing everywhere is the claim that the same values
/// render the same bytes on every platform the kit is built for.
///
/// The pins were taken at the exporters' move into the kit (2026-10-25), which the app's own
/// exports, compared byte for byte before and after the move, showed changes no byte. A change to
/// what an export prints moves them: re-take each from the failure message, and say why here.
///
/// Re-taken 2026-10-31 for `everything.html` and `everything.docx`, because the everything collection
/// gained `d11`, a structured summary at summary depth with a structured headnote, which the exporters
/// print as its fields from that day. Rendered by the new code with `d11` taken out, both matched their
/// 2026-10-25 pins (42,639 and 36,190 bytes), so no byte of the documents already pinned moved; BibTeX
/// and RIS print no summary, and `d11` has no Zotero item, so their pins hold.
///
/// Version history:
///   1.0 — 2026-10-25 (FRUS Explorer Light, S18a): initial implementation
///   1.1 — 2026-10-31: `structuredSummaryFields`; the page and the package re-pinned for `d11`
@Suite("A collection renders the same HTML, Word, BibTeX and RIS from the same values")
struct CollectionRenderingPinTests {

    typealias F = CollectionRenderingFixtures

    /// Each output's SHA-256 and byte count.
    static let pins: [String: (sha256: String, bytes: Int)] = [
        "everything.html": ("96c80c78cae33b6bd8ebdf8aa1bb5251b55c51f69e5e5159d9c40766dfe11eb1", 43_927),
        "everything.docx": ("93c70b760ebc3b07076c052dcac71e64adb2119aa408df746b71286aaeb1943b", 38_622),
        "everything.bib": ("e04c1eb921acae782e6113bcc18055dc81e9e43dbb9eca97848c6356c78df7ad", 1_061),
        "everything.ris": ("25e92393bdda73437bfcf1879d65cb790eb62df10c964a135d596faabcdc4fbc", 810),
        "plain.html": ("5d4be78dba1e92b929c95e99e0dea797efda25287c99a8ddcc91564e46a5b661", 28_266),
        "plain.docx": ("f2e01009a8d85ecfd56b42fc60e1b54b8df41a0ed4ed795d79fa3e3d2b6acea9", 14_952),
        "preview.html": ("03909788a8c46611ff4667337150806f173677dd518ad78d8e093bfd0ca19f42", 27_129),
    ]

    static func expectPin(_ name: String, _ data: Data, sourceLocation: SourceLocation = #_sourceLocation) {
        let pin = Self.pins[name]
        let actual = (F.sha256(data), data.count)
        #expect(pin?.sha256 == actual.0 && pin?.bytes == actual.1,
                "\(name) is \(actual.1) bytes, SHA-256 \(actual.0); its pin is \(pin.map { "\($0.bytes) bytes, \($0.sha256)" } ?? "missing")",
                sourceLocation: sourceLocation)
    }

    @Test("The everything collection's HTML page")
    func everythingHTML() async throws {
        let (metadata, items, options) = try await F.everything()
        var renderer = CollectionItemHTMLRenderer(options: options)
        renderer.figureImages = F.FixedFigureImages()
        let html = renderer.pageHTML(metadata: metadata, items: items,
                                     wordCloudPNGBase64: F.cloud.png.base64EncodedString())
        // What the pin holds, in part.
        #expect(html.contains("<title>The Crisis: A Reader</title>"))
        #expect(html.contains("· October 25, 2026</p>"), "the colophon is not dated by the export's date")
        #expect(html.contains("src=\"data:image/png;base64,\(F.figurePNG.base64EncodedString())\""), "the figure is not embedded")
        #expect(html.contains("<a href=\"https://history.state.gov/\">a link</a>"))
        #expect(html.contains("<span style=\"color:#CC1919\">colour</span>"))
        #expect(html.contains("<h4 class=\"section-heading\">Subsection i</h4>"))
        Self.expectPin("everything.html", Data(html.utf8))
    }

    @Test("The everything collection's Word package")
    func everythingDocx() async throws {
        let (metadata, items, options) = try await F.everything()
        let data = DocxCollectionExporter(figureImages: F.FixedFigureImages())
            .documentData(metadata: metadata, items: items, options: options, wordCloud: F.cloud)
        let package = String(decoding: data, as: UTF8.self)
        #expect(package.contains("Exported October 25, 2026"), "the cover is not dated by the export's date")
        #expect(package.contains("word/media/wordcloud.png") && package.contains("word/media/figure1.png"))
        #expect(package.contains("<w:highlight w:val=\"yellow\"/>"))
        Self.expectPin("everything.docx", data)
    }

    /// A structured summary was printed as its stored JSON until 2026-10-31; the readers showed its
    /// fields from that day, and the exports print them as the readers do: a paragraph a field, in the
    /// schema's order, each opening with its label in bold, the headnote's in italics as well.
    @Test("A structured summary and headnote print as their fields, in the page and the package")
    func structuredSummaryFields() async throws {
        let (metadata, items, options) = try await F.everything()
        let html = CollectionItemHTMLRenderer(options: options).pageHTML(metadata: metadata, items: items)
        for paragraph in ["<p><strong>Key Participants:</strong> The President; Bundy</p>",
                          "<p><strong>Topics:</strong> The quarantine &amp; its &lt;terms&gt;</p>",
                          "<p><strong>Disagreements:</strong></p>",
                          "<p><em><strong>Subject:</strong> The &quot;quarantine&quot;</em></p>",
                          "<p><em><strong>Outcome:</strong> Agreed.</em></p>"] {
            #expect(html.contains(paragraph), "\(paragraph)")
        }
        let subject = try #require(html.range(of: "<strong>Subject:</strong>"))
        let outcome = try #require(html.range(of: "<strong>Outcome:</strong>"))
        #expect(subject.lowerBound < outcome.lowerBound, "the headnote's fields are not in the schema's order")
        #expect(!html.contains("{&quot;"), "a stored JSON object is printed")

        let package = String(decoding: DocxCollectionExporter().documentData(metadata: metadata, items: items,
                                                                              options: options),
                             as: UTF8.self)
        let bold = #"<w:r><w:rPr><w:b/></w:rPr><w:t xml:space="preserve">"#
        let boldItalic = #"<w:r><w:rPr><w:b/><w:i/></w:rPr><w:t xml:space="preserve">"#
        for runs in [bold + #"Key Participants:</w:t></w:r><w:r><w:t xml:space="preserve"> The President; Bundy</w:t></w:r>"#,
                     bold + "Disagreements:</w:t></w:r>\n",
                     boldItalic + #"Subject:</w:t></w:r><w:r><w:rPr><w:i/></w:rPr><w:t xml:space="preserve"> The &quot;quarantine&quot;</w:t></w:r>"#] {
            #expect(package.contains(runs), "\(runs)")
        }
        #expect(!package.contains("{&quot;") && !package.contains(#"{"Outcome""#), "a stored JSON object is printed")
    }

    @Test("The everything collection's BibTeX and RIS")
    func everythingReferences() async throws {
        let (_, items, options) = try await F.everything()
        let bib = BibTeXCollectionExporter().bibTeX(for: items, options: options)
        let ris = ZoteroCollectionExporter().ris(for: items, options: options)
        #expect(bib.components(separatedBy: "@incollection{").count - 1 == 2)
        #expect(ris.components(separatedBy: "TY  - CHAP").count - 1 == 2)
        Self.expectPin("everything.bib", Data(bib.utf8))
        Self.expectPin("everything.ris", Data(ris.utf8))
    }

    @Test("The plain collection's HTML page and Word package")
    func plain() async throws {
        let (metadata, items, options) = try await F.plain()
        let html = CollectionItemHTMLRenderer(options: options).pageHTML(metadata: metadata, items: items)
        #expect(html.contains("<title>Untitled Collection</title>"))
        #expect(!html.contains("footer class=\"colophon\""))
        Self.expectPin("plain.html", Data(html.utf8))
        let data = DocxCollectionExporter().documentData(metadata: metadata, items: items, options: options)
        Self.expectPin("plain.docx", data)
    }

    /// The live preview's affordances, which only the preview sets: a citation card for a volume
    /// not on the device, the placeholder for a summary to come, and an untitled section.
    @Test("The preview's page")
    func preview() async throws {
        let telegram = try await ListShapeFixtures.renderModel(F.telegramXML)
        let metadata = CollectionExportMetadata(name: "Preview", note: nil, exportDate: F.exportDate)
        let items: [CollectionExportItem] = [
            .heading("  ", level: 1),
            .document(CollectionExportDocument(
                documentId: "d7", volumeId: "frus1961-63v11", sortOrder: 0, title: "Cuban Missile Crisis — d7",
                bodyText: "", citation: "Foreign Relations of the United States, 1961–1963, Volume XI, Document 7.")),
            .document(CollectionExportDocument(
                documentId: "d7", volumeId: "frus1961-63v11b", sortOrder: 1, bodyDepth: .summaryOnly,
                title: "Cuban Missile Crisis — d7", bodyText: "", renderModel: telegram)),
        ]
        var renderer = CollectionItemHTMLRenderer()
        renderer.citationOnlyVolumeIds = ["frus1961-63v11"]
        renderer.showsSummaryPlaceholders = true
        let html = renderer.pageHTML(metadata: metadata, items: items)
        #expect(html.contains("Untitled section"))
        // The elements, not the class names, which the preview's stylesheet holds as well.
        #expect(html.contains("<div class=\"citation-card\">"))
        #expect(html.contains("<div class=\"summary-placeholder\">"))
        Self.expectPin("preview.html", Data(html.utf8))
    }

    /// The export's date as the app leaves it, `nil`: the device's calendar, as the exporters'
    /// own formatters were. A named one is written in its locale and read in its time zone.
    @Test("An export is dated in the device's calendar unless the host names one")
    func exportDate() {
        let now = CollectionExportDate()
        #expect(now.locale == nil && now.timeZone == nil)
        let device = DateFormatter(); device.dateStyle = .long; device.timeStyle = .none
        #expect(now.formatter.string(from: F.exportDate.date) == device.string(from: F.exportDate.date))
        #expect(F.exportDate.formatter.string(from: F.exportDate.date) == "October 25, 2026")
        // 03:00 UTC on the 26th is the evening of the 25th in Los Angeles: the zone decides the day.
        let moment = Date(timeIntervalSince1970: 1_792_983_600)
        let utc = CollectionExportDate(date: moment, locale: Locale(identifier: "en_US"),
                                       timeZone: TimeZone(identifier: "UTC"))
        let pacific = CollectionExportDate(date: moment, locale: Locale(identifier: "en_US"),
                                           timeZone: TimeZone(identifier: "America/Los_Angeles"))
        #expect(utc.formatter.string(from: moment) == "October 26, 2026")
        #expect(pacific.formatter.string(from: moment) == "October 25, 2026")
        #expect(CollectionColophon.text(for: [], dated: F.exportDate)
                == "Compiled with FRUS Explorer · 0 documents from 0 volumes · October 25, 2026")
    }
}

// MARK: - CollectionOutlineCoreTests

/// The outline's value core, which the resolver runs and a host's collections nest by: three levels
/// deep, over `StructuralRef`s alone.
///
/// Version history:
///   1.0 — 2026-10-25 (FRUS Explorer Light, S18a): initial implementation, with the core's move into
///          the kit
@Suite("A collection's outline, three levels deep, over values")
struct CollectionOutlineCoreTests {

    static func heading(_ level: Int, bodyDepth: String? = nil) -> CollectionOutline.StructuralRef {
        CollectionOutline.StructuralRef(isHeading: true, level: level, bodyDepthOverride: bodyDepth)
    }
    static let entry = CollectionOutline.StructuralRef(isHeading: false, level: 1, bodyDepthOverride: nil)

    @Test("Depths clamp to three, an orphan jump lifts to one below its predecessor, and an entry takes its heading's")
    func depths() {
        let refs = [Self.entry, Self.heading(1), Self.entry, Self.heading(3), Self.entry,
                    Self.heading(3), Self.heading(7), Self.entry, Self.heading(0), Self.entry]
        #expect(CollectionOutline.maxLevel == 3)
        #expect(CollectionOutline.resolvedDepths(refs) == [0, 1, 1, 2, 2, 3, 3, 3, 1, 1])
    }

    @Test("An export leaves out an untitled heading and lifts what it owns one level")
    func exportLevels() {
        let refs = [Self.heading(1), Self.heading(2), Self.heading(3), Self.entry, Self.heading(2), Self.entry]
        let untitled = [false, true, false, false, false, false]
        #expect(CollectionOutline.exportLevels(refs, untitled: untitled) == [1, nil, 2, 2, 2, 2])
    }

    @Test("A heading owns everything to the next heading at its level or shallower")
    func sectionRanges() {
        let refs = [Self.heading(1), Self.heading(2), Self.entry, Self.heading(3), Self.entry,
                    Self.heading(2), Self.entry, Self.heading(1)]
        #expect(CollectionOutline.sectionRange(of: 1, refs: refs) == 1..<5)
        #expect(CollectionOutline.sectionRange(of: 0, refs: refs) == 0..<7)
        #expect(CollectionOutline.sectionRange(of: 2, refs: refs) == 2..<3, "an entry owns itself")
    }

    @Test("A heading moves with its section, and a drop into it is refused")
    func moves() {
        let refs = [Self.heading(1), Self.entry, Self.heading(2), Self.entry, Self.heading(1), Self.entry]
        #expect(CollectionOutline.movedOrder(refs, fromIndex: 2, toOffset: 6) == [0, 1, 4, 5, 2, 3])
        #expect(CollectionOutline.movedOrder(refs, fromIndex: 0, toOffset: 2) == nil)
        #expect(CollectionOutline.movedOrder(refs, fromIndex: 5, toOffset: 0) == [5, 0, 1, 2, 3, 4])
    }

    @Test("A collapsed heading hides its section but itself")
    func collapse() {
        let refs = [Self.heading(1), Self.heading(2), Self.entry, Self.heading(3), Self.entry, Self.heading(1)]
        #expect(CollectionOutline.visibleIndices(refs, collapsedHeadingIndices: [1]) == [0, 1, 5])
        #expect(CollectionOutline.visibleIndices(refs, collapsedHeadingIndices: [2]) == [0, 1, 2, 3, 4, 5],
                "an entry cannot collapse")
    }

    @Test("A deeper heading's default shadows its ancestors', and a sibling without one resets")
    func cascades() {
        let refs = [Self.heading(1, bodyDepth: "index"), Self.entry, Self.heading(2, bodyDepth: "full"), Self.entry,
                    Self.heading(2), Self.entry, Self.heading(1), Self.entry]
        #expect(CollectionOutline.sectionBodyDepthOverrides(refs)
                == ["index", "index", "full", "full", "index", "index", nil, nil])
        let flags: [Bool?] = [true, nil, nil, nil, false, nil, nil, nil]
        #expect(CollectionOutline.sectionOverrideValues(refs, headingValues: flags)
                == [true, true, true, true, false, false, nil, nil])
    }
}

// MARK: - CollectionProseSpanTests

/// The rules a prose block's runs become spans by, which every host's reader of the stored RTF calls.
///
/// Version history:
///   1.0 — 2026-10-25 (FRUS Explorer Light, S18a): initial implementation, with the rules' move into
///          the kit
@Suite("A prose block's runs become paragraphs of spans")
struct CollectionProseSpanTests {

    @Test("A blank line starts a paragraph, and an empty part makes no span")
    func paragraphs() {
        var paragraphs: [[ProseFormattedSpan]] = [[]]
        CollectionProse.append(text: "One\n\nTwo, ", bold: false, italic: false, underline: false,
                               colorHex: nil, linkURL: nil, to: &paragraphs)
        CollectionProse.append(text: "bold\n\n\n\nThree", bold: true, italic: false, underline: false,
                               colorHex: "CC1919", linkURL: nil, to: &paragraphs)
        #expect(paragraphs.map { $0.map(\.text) } == [["One"], ["Two, ", "bold"], [], ["Three"]])
        #expect(paragraphs[1][1].bold && paragraphs[1][1].colorHex == "CC1919")
    }

    @Test("A colour is uppercase RRGGBB, and near-black is none")
    func hex() {
        #expect(CollectionProse.hex(r: 0.079, g: 0.0, b: 0.07) == nil)
        #expect(CollectionProse.hex(r: 1, g: 0, b: 0) == "FF0000")
        #expect(CollectionProse.hex(r: 0.5, g: 0.08, b: 0.999) == "7F14FE")
    }
}
