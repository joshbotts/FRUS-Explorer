// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import FRUSCoreKit
import Foundation
import Testing
@testable import VolumeAnnotationsIndexGeneratorCore

// MARK: - VolumeAnnotationsIndexGeneratorTests

/// Tests for the volume-annotations generator: the TEI scan's rules, the counting over a volume
/// indexed through the kit's own pipeline (so the index's SQL is checked against the rows the
/// pipeline really writes), the file's determinism and the refusals.
///
/// The fixture volume carries every category once or more. Its d1 prints its marking after a
/// citation ending "Vol. I." and its d2 before a remark that opens with a digit, the two notes
/// index version 73 reads (#1857); d3 is an editorial note; d4 prints a despatch serial; d5's
/// source note is a despatch number, as `frus1870`'s are, which the source-note count leaves out;
/// and d6's is a file number printed above the heading.
///
/// Version history:
///   1.0 — 2026-11-06: the editors' annotations design, lane A
///   1.1 — 2026-11-06: a volume that names its people and terms on each document's `@ana`
///          (`frus1981-88v16`), and one that prints an Index of Persons (`frus1941-43`, index
///          version 74)
///   1.2 — 2026-11-08: the editors' bracketed omissions and the header's publication year (Lane 1
///          of `Planning/Editors-Annotations-Followups-2026-11-08.md`): the rule's positives and
///          negatives, the own-text walk, and the 1925 gate through the pipeline
@Suite("VolumeAnnotationsIndexGenerator — what each volume's editors annotated")
struct VolumeAnnotationsIndexGeneratorTests {

    static let volume = "frus1969-76v99"

    static let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <teiHeader><fileDesc><titleStmt><title>frus1969-76v99</title></titleStmt>
          <publicationStmt><date calendar="gregorian" type="publication-date">2026</date></publicationStmt>
          <sourceDesc><p>Test fixture</p></sourceDesc></fileDesc></teiHeader>
          <text>
            <front>
              <div type="section" subtype="preface" xml:id="preface"><head>Preface</head><p>The editors chose these documents.</p></div>
              <div type="section" subtype="sources" xml:id="sources"><head>Sources</head><p>The Department's central files.</p></div>
              <div type="section" subtype="index" xml:id="terms"><head>Abbreviations and Terms</head>
                <list>
                  <item><term xml:id="t_AEC1">AEC</term>, Atomic Energy Commission</item>
                  <item><term xml:id="t_NSC1">NSC</term>, National Security Council</item>
                </list>
              </div>
              <div type="section" subtype="index" xml:id="persons"><head>Persons</head>
                <list>
                  <item><persName xml:id="p_KHA1">Kissinger, Henry A.</persName>, Assistant to the President</item>
                  <item><persName xml:id="p_NRM1">Nixon, Richard M.</persName>, President of the United States</item>
                  <item><persName xml:id="p_RWP1">Rogers, William P.</persName>, Secretary of State</item>
                </list>
              </div>
            </front>
            <body><div type="compilation" xml:id="comp1"><head>China</head>
              <div type="document" xml:id="d1" n="1" subtype="historical-document"><head>1. Memorandum From <persName corresp="#p_KHA1" type="from">Kissinger</persName> to President <persName corresp="#p_NRM1" type="to">Nixon</persName><note n="0" type="source" xml:id="d1fn0">Source: National Archives, Nixon Presidential Materials, NSC Files, Box 518, Country Files, Far East, China, Vol. I. Secret. Sent for action.</note></head>
                <opener><dateline><placeName>Washington</placeName>, <date when="1969-02-01">February 1, 1969</date>.</dateline></opener>
                <list type="subject"><item>SUBJECT</item><item>China Policy</item></list>
                <p>The <gloss target="#t_NSC1">NSC</gloss> met.<note n="1" xml:id="d1fn1">See <ref target="#d2">Document 2</ref>.</note> [1 paragraph (2 lines) not
                declassified]</p></div>
              <div type="document" xml:id="d2" n="2" subtype="historical-document"><head>2. Memorandum of Conversation<note n="0" type="source" xml:id="d2fn0">Source: Department of State, Central Files, POL CHICOM–US. Confidential. 1 page of source text not declassified.</note></head>
                <list type="participants"><item>PARTICIPANTS</item><item>Secretary <persName corresp="#p_RWP1">Rogers</persName></item></list>
                <p>See <ref target="#d1fn1">footnote 1 to Document 1</ref>, <ref target="frus1964-68v30#d5">the earlier volume</ref> and <ref target="#pg_3">page 3</ref>.</p></div>
              <div type="document" xml:id="d3" n="3" subtype="editorial-note"><head>3. Editorial Note</head>
                <p>The <gloss target="#t_AEC1">AEC</gloss> reported.<seg type="margin">A marginal note.</seg></p>
                <figure><head>A chart</head><graphic url="fig1"/></figure></div>
              <div type="document" xml:id="d4" n="4" subtype="historical-document"><head>Mr. Seward to Mr. Adams</head>
                <opener><seg rendition="#left">No. 74.]</seg></opener>
                <p>Sir: <persName corresp="#p_RWP1">Rogers</persName> acknowledged your despatch.</p></div>
              <div type="document" xml:id="d5" n="5" subtype="historical-document"><note type="source" rend="inline" xml:id="d5fn0">No. 3.</note><head>Mr. Fish to Mr. Bancroft</head>
                <p>Sir: I enclose the papers.</p></div>
              <div type="document" xml:id="d6" n="6" subtype="historical-document"><note type="source" rend="inline" xml:id="d6fn0">File No. 711.00/12.</note><head>Mr. Root to Mr. Bryce</head>
                <p>Sir: I have the honor to transmit the treaty.</p></div>
            </div></body>
          </text>
        </TEI>
        """

    /// A volume that names its people and terms only on each document div's `@ana`, as
    /// `frus1981-88v16` does: no `persName/@corresp` and no `gloss`. d368 is that volume's, its
    /// pointers trimmed to four. d369's term pointer is into another file, which none of the
    /// volume's are, so it names nothing here; d370 names no one.
    static let annotatedXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <teiHeader><fileDesc><titleStmt><title>frus1969-76v99</title></titleStmt>
          <publicationStmt><date>2026</date></publicationStmt>
          <sourceDesc><p>Test fixture</p></sourceDesc></fileDesc></teiHeader>
          <text>
            <front>
              <div type="section" subtype="index" xml:id="terms"><head>Abbreviations and Terms</head>
                <list>
                  <item><term xml:id="t_EXDIS_1">EXDIS</term>, exclusive distribution</item>
                  <item><term xml:id="t_OAS_1">OAS</term>, Organization of American States</item>
                </list>
              </div>
              <div type="section" subtype="index" xml:id="persons"><head>Persons</head>
                <list>
                  <item><persName xml:id="p_HAMJ_1">Haig, Alexander M., Jr.</persName>, Secretary of State</item>
                  <item><persName xml:id="p_RRW_1">Reagan, Ronald W.</persName>, President of the United States</item>
                </list>
              </div>
            </front>
            <body><div type="chapter" xml:id="ch1"><head>Central America</head>
              <div type="document" xml:id="d368" n="368" subtype="historical-document" ana="#p_HAMJ_1 #p_RRW_1 #t_EXDIS_1 #t_OAS_1"><head>368. Telegram From the Department of State to the Embassy in Ecuador</head>
                <p>The Secretary met the President.</p></div>
              <div type="document" xml:id="d369" n="369" subtype="historical-document" ana="#p_RRW_1 frus1981-88v11#t_OAS_1"><head>369. Memorandum for the Record</head>
                <p>The President spoke.</p></div>
              <div type="document" xml:id="d370" n="370" subtype="historical-document"><head>370. Memorandum for the Record</head>
                <p>No one is named.</p></div>
            </div></body>
          </text>
        </TEI>
        """

    /// `frus1941-43`'s "Index of Persons" as the TEI encodes it, trimmed: a List of Persons'
    /// attributes, a `<list type="index">`, and entries with page references and no id. Its id
    /// here is `persname`, a persons list's too, since the fixture's List of Persons has `persons`.
    /// Read as a list, three of its entries were people ("Gauss, … 807n", "Hull, …", "Views on").
    static let indexOfPersons = """
        <div type="section" subtype="index" xml:id="persname"><head>Index of Persons</head>
          <list type="index">
            <item>Acheson, Dean G., Assistant Secretary of State, <ref target="#pg_62">62</ref></item>
            <item>Gauss, Clarence E., Ambassador in China, <ref target="#pg_807">807<hi rend="italic">n</hi></ref></item>
            <item>Hull, Cordell, Secretary of State: <list><item>Meetings: <list><item>With Litvinov, <ref target="#pg_133">133</ref></item></list></item></list></item>
            <item>Views on: <list><item>Aircraft production, <ref target="#pg_110">110</ref></item></list></item>
          </list>
        </div>
        """

    /// The editors' bracketed omissions, one case a document, and a header whose publication date
    /// the gate reads. The brackets are the corpus's (`Planning/editors-annotations/omission-markers.out`):
    /// o1 "[Here follows …]"; o2 the same bracket inside a footnote, which is not the document's own
    /// text; o3 a redaction phrased as an omission, the Redactions layer's; o4 the editors' remark on
    /// a garbled telegram; o5 a bracket broken across a printed line; o6 "[Omitted here is …]"; o7
    /// "… here omitted …"; o8 a bracket in the source note alone; o9 "Omitted here is …" after a
    /// stage direction; o10 a lower-case opener, which the case-sensitive rule leaves out; o11
    /// "printed infra", an omission in place, which counts. Six of the eleven link a person, so the
    /// volume carries people tagging and the run does not refuse it.
    static func omissionsXML(publicationDate: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <teiHeader><fileDesc><titleStmt><title>frus1969-76v99</title></titleStmt>
          <publicationStmt>\(publicationDate)</publicationStmt>
          <sourceDesc><p>Test fixture</p></sourceDesc></fileDesc></teiHeader>
          <text>
            <front>
              <div type="section" subtype="index" xml:id="persons"><head>Persons</head>
                <list><item><persName xml:id="p_KHA1">Kissinger, Henry A.</persName></item></list>
              </div>
            </front>
            <body><div type="compilation" xml:id="comp1"><head>Omissions</head>
              <div type="document" xml:id="o1" n="1"><head>1. Memorandum</head>
                <p><persName corresp="#p_KHA1">Kissinger</persName> spoke.</p>
                <p>[Here follows discussion of unrelated matters.]</p></div>
              <div type="document" xml:id="o2" n="2"><head>2. Memorandum</head>
                <p><persName corresp="#p_KHA1">Kissinger</persName> was present.</p>
                <p>The text.<note n="1" xml:id="o2fn1">[Here follows a table showing the number of members in each party.]</note></p></div>
              <div type="document" xml:id="o3" n="3"><head>3. Estimate</head>
                <p><persName corresp="#p_KHA1">Kissinger</persName> was present.</p>
                <p>[Here follow 6-1/2 pages of source text scheduled for inclusion in the Supplement but not declassified.]</p></div>
              <div type="document" xml:id="o4" n="4"><head>4. Telegram</head>
                <p><persName corresp="#p_KHA1">Kissinger</persName> was present.</p>
                <p>The Minister [apparent omission] the note [omission?] and [sic] the rest [omission in the original].</p></div>
              <div type="document" xml:id="o5" n="5"><head>5. Telegram</head>
                <p><persName corresp="#p_KHA1">Kissinger</persName> was present.</p>
                <p>[Here<lb/>follows the text of the note, printed on page 80.]</p></div>
              <div type="document" xml:id="o6" n="6"><head>6. Paper</head>
                <p><persName corresp="#p_KHA1">Kissinger</persName> was present.</p>
                <p>[Omitted here is the Table of Contents.]</p></div>
              <div type="document" xml:id="o7" n="7"><head>7. Telegram</head>
                <p>[The paragraph here omitted summarized telegram 2385, July 1, printed supra.]</p></div>
              <div type="document" xml:id="o8" n="8"><head>8. Memorandum<note type="source" xml:id="o8fn0">Source: [Here follows the file citation.] Secret.</note></head>
                <p>The text alone.</p></div>
              <div type="document" xml:id="o9" n="9"><head>9. Conversation</head>
                <p>[Agnew left at 10:35 a.m. Omitted here is discussion unrelated to the Vice President.]</p></div>
              <div type="document" xml:id="o10" n="10"><head>10. Despatch</head>
                <p>The consul wrote as follows: [here follows copy of the consul’s letter of 17th April].</p></div>
              <div type="document" xml:id="o11" n="11"><head>11. Telegram</head>
                <p>[Here follows text of the aide-mémoire of May 9, 1938, from the French Embassy, printed infra.]</p></div>
            </div></body>
          </text>
        </TEI>
        """
    }

    /// A header's publication date, as the corpus prints it: the year as text, or on `@when`.
    static let published1924 = #"<date calendar="gregorian" type="publication-date">1924</date>"#
    static let published1925 = #"<date calendar="gregorian" type="publication-date">1925</date>"#
    static let publishedOnWhen = #"<date calendar="gregorian" type="publication-date" when="1996-05-01"></date>"#

    // MARK: Helpers

    /// A corpus folder holding `xml` as one volume, a manifest naming it, and the run's paths.
    private static func corpus(xml: String = Self.xml) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("volume-annotations-tests-\(UUID().uuidString)", isDirectory: true)
        let volumes = root.appendingPathComponent("corpus", isDirectory: true)
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        try Data(xml.utf8).write(to: volumes.appendingPathComponent("\(volume).xml"))
        let manifest = #"[{"volumeId": "\#(volume)", "filename": "\#(volume).xml", "subseries": "1969-76"}]"#
        try Data(manifest.utf8).write(to: root.appendingPathComponent("manifest.json"))
        return root
    }

    private static func configuration(_ root: URL,
                                      index: VolumeAnnotationsIndexConfiguration.IndexSource? = nil)
        -> VolumeAnnotationsIndexConfiguration {
        VolumeAnnotationsIndexConfiguration(
            volumesDirectory: root.appendingPathComponent("corpus", isDirectory: true),
            manifest: root.appendingPathComponent("manifest.json"),
            output: root.appendingPathComponent("volume-annotations-index.json"),
            corpusCommit: "fixture", generated: "2026-11-06",
            index: index ?? .build(keptIn: root.appendingPathComponent("index", isDirectory: true)))
    }

    // MARK: Rules

    @Test("A reference's target is classed by the design's TEI rule")
    func referenceKinds() {
        #expect(ReferenceKind(target: "#d12") == .document)
        #expect(ReferenceKind(target: "#d12fn3") == .footnote)
        #expect(ReferenceKind(target: "#ch1fn2") == .footnote)
        #expect(ReferenceKind(target: "#pg_123") == .page)
        #expect(ReferenceKind(target: "frus1964-68v30#pg_5") == .page)
        #expect(ReferenceKind(target: "frus1964-68v30#d5") == .otherVolume)
        #expect(ReferenceKind(target: "frus1964-68v30") == .otherVolume)
        #expect(ReferenceKind(target: "#persons") == .internalOther)
        #expect(ReferenceKind(target: "https://history.state.gov") == .url)
    }

    @Test("A heading is numbered when it opens with its printed number")
    func printedNumbers() {
        #expect(VolumeAnnotationsAssembly.opensWithPrintedNumber("12. Telegram From the Embassy"))
        #expect(VolumeAnnotationsAssembly.opensWithPrintedNumber("  12A. Memorandum"))
        #expect(!VolumeAnnotationsAssembly.opensWithPrintedNumber("Mr. Seward to Mr. Adams"))
        #expect(!VolumeAnnotationsAssembly.opensWithPrintedNumber("12 Telegram"))
        #expect(!VolumeAnnotationsAssembly.opensWithPrintedNumber("12.Telegram"))
        #expect(!VolumeAnnotationsAssembly.opensWithPrintedNumber(""))
    }

    @Test("A source note's form is where the TEI prints it, and a despatch number is not one")
    func sourceNoteForms() {
        let form = VolumeAnnotationsAssembly.sourceNoteForm
        #expect(form("Source: Department of State, Central Files.", false) == .sourceCitation)
        #expect(form("File No. 763.72119/1098.", true) == .sourceFileNumber)
        #expect(form("751G.00/2–152: Telegram", true) == .sourceFileNumber)
        // A microfiche supplement's summary note opens with neither form; it is a footnote.
        #expect(form("NSC Actions 2374–2377 on Polaris program. Confidential. 3 pp.", false) == .sourceCitation)
        // Despatch numbers (frus1870, frus1872p2v5, frus1915) are not source notes …
        #expect(form("No. 3.", true) == nil)
        #expect(form("No. 1315.]", true) == nil)
        // … but a file number printed "No." is one: the Numerical File and the decimal file.
        #expect(form("No. 8130/11.", true) == .sourceFileNumber)
        #expect(form("No. 711.1215/448a.", true) == .sourceFileNumber)
        #expect(form("  ", true) == nil)
        #expect(form(nil, false) == nil)
    }

    @Test("A bracket marks an omission by the three patterns, and not when it says not declassified")
    func omissionMarkers() {
        let marks: (String) -> Bool = { EditorialOmissionMarkers.isMarkedOmission(Substring($0)) }
        // Pattern 1.
        #expect(marks("Here follows discussion of Vietnam."))
        #expect(marks("Here follow the names of the signatories."))
        #expect(marks(" Here follows, in the Spanish text, the same message."))
        // Pattern 2, at the start and after a stage direction.
        #expect(marks("Omitted here is the Table of Contents."))
        #expect(marks("Omitted here are two paragraphs on Laos."))
        #expect(marks("Omitted from this document is the annex."))
        #expect(marks("Omitted are paragraphs 1–44."))
        #expect(marks("The recording began while the meeting was in progress. Omitted here is discussion of domestic support."))
        // Pattern 3, anywhere.
        #expect(marks("The next three paragraphs, which have been omitted, are the same, mutatis mutandis."))
        #expect(marks("The letter has been omitted."))
        #expect(marks("The final paragraph, which is omitted, listed the positions of the leaders."))
        #expect(marks("For texts of articles XIX and XXVI which are omitted, see the draft treaty."))
        #expect(marks("The paragraph here omitted summarized telegram 2385."))
        #expect(marks("A few sentences of remarks by the Shah are here omitted."))
        // An omission in place counts (the owner's decision of 2026-11-08).
        #expect(marks("Here follows text of the aide-mémoire of May 9, 1938, printed infra."))
        // A nested bracket is read whole.
        #expect(marks("Here follows the text [sic] of the note."))
        // A redaction phrased as an omission is the Redactions layer's.
        #expect(!marks("Here follows a short paragraph not declassified by the NSC Staff."))
        #expect(!marks("Here follow paragraphs 6–14, which contain an assessment of [text not declassified]."))
        #expect(!marks("1 paragraph (2 lines) not declassified"))
        // The editors' remarks on a garbled original.
        #expect(!marks("apparent omission"))
        #expect(!marks("omission?"))
        #expect(!marks("omission in the original"))
        #expect(!marks("sic"))
        #expect(!marks("omitted from?"))
        // Phrasings the rule leaves out, each recorded by the sweep.
        #expect(!marks("here follows copy of the consul’s letter"))
        #expect(!marks("Letter omitted."))
        #expect(!marks("Chinese text not printed."))
        #expect(!marks("A broad-ranging discussion of 39 minutes was not transcribed."))
        #expect(!marks("The meeting ended."))
        #expect(!marks(""))
    }

    @Test("Brackets are read whole, nesting followed; a stray closer and an unclosed opener are passed over")
    func bracketsFollowNesting() {
        let text = "No. 1315.] Sir: [Here follows the text [sic] of the note.] Then [apparent omission] and [an opener that never closes"
        #expect(EditorialOmissionMarkers.brackets(in: text).map(String.init)
                == ["Here follows the text [sic] of the note.", "apparent omission"])
        #expect(EditorialOmissionMarkers.brackets(in: "no brackets").isEmpty)
        #expect(EditorialOmissionMarkers.marksAnOmission(in: text))
        #expect(!EditorialOmissionMarkers.marksAnOmission(in: "Here follows the text, unbracketed."))
        let long = "[" + String(repeating: "x", count: EditorialOmissionMarkers.longestBracket + 10) + "]"
        #expect(EditorialOmissionMarkers.brackets(in: long).isEmpty, "a bracket past the cap is passed over")
    }

    @Test("A publication year is the header's first four-digit run, from the text or from @when")
    func publicationYears() {
        #expect(EditorialOmissionMarkers.year(in: "1948") == 1948)
        #expect(EditorialOmissionMarkers.year(in: "2026-03-15") == 2026)
        #expect(EditorialOmissionMarkers.year(in: " 1861 ") == 1861)
        #expect(EditorialOmissionMarkers.year(in: "n.d.") == nil)
        #expect(EditorialOmissionMarkers.year(in: "") == nil)
    }

    @Test("The TEI scan reads omissions from the document's own text, notes left out, and the header's year")
    func scanReadsOmissionsAndThePublicationYear() throws {
        let scan = try TEIAnnotationScanner.scan(data: Data(Self.omissionsXML(publicationDate: Self.published1925).utf8))
        #expect(scan.publicationYear == 1925)
        #expect(scan.documentIds.count == 11)
        func omits(_ id: String) -> Bool { scan.features[id]?.editorialOmissions == true }
        #expect(omits("o1") && omits("o5") && omits("o6") && omits("o7") && omits("o9") && omits("o11"))
        // A bracket inside a footnote is the note's, not the document's; the footnote still counts.
        #expect(!omits("o2") && scan.features["o2"]?.footnotes == true)
        // A redaction phrased as an omission: the Redactions layer's, never this one.
        #expect(!omits("o3") && scan.features["o3"]?.excisions == true)
        #expect(!omits("o4") && !omits("o8") && !omits("o10"))
        #expect(scan.features["o8"]?.excisions == false)
        // The year from @when where the text is empty, and none where the header prints none.
        #expect(try TEIAnnotationScanner.scan(data: Data(Self.omissionsXML(publicationDate: Self.publishedOnWhen).utf8))
                    .publicationYear == 1996)
        #expect(try TEIAnnotationScanner.scan(data: Data(Self.omissionsXML(publicationDate: "<date>1996</date>").utf8))
                    .publicationYear == nil)
        // The main fixture's year, and that its one bracket, a redaction, marks no omission.
        let main = try TEIAnnotationScanner.scan(data: Data(Self.xml.utf8))
        #expect(main.publicationYear == 2026)
        #expect(main.features.values.allSatisfy { !$0.editorialOmissions })
    }

    @Test("The TEI scan credits each feature to its document")
    func scanRecordsEachDocumentsFeatures() throws {
        let scan = try TEIAnnotationScanner.scan(data: Data(Self.xml.utf8))
        #expect(scan.documentIds == ["d1", "d2", "d3", "d4", "d5", "d6"])
        let d1 = try #require(scan.features["d1"])
        #expect(d1.correspondents && d1.subjects && d1.footnotes && d1.xrefDocuments && d1.excisions)
        #expect(d1.glossTargets == ["t_NSC1"])
        #expect(!d1.participants && !d1.xrefFootnotes && !d1.isEditorialNote)
        let d2 = try #require(scan.features["d2"])
        #expect(d2.participants && d2.xrefFootnotes && d2.xrefVolumes && d2.xrefPages && d2.excisions)
        #expect(!d2.footnotes, "d2's only note is its source note")
        let d3 = try #require(scan.features["d3"])
        #expect(d3.isEditorialNote && d3.marginalNotes && d3.figures && d3.glossTargets == ["t_AEC1"])
        #expect(scan.features["d4"] == TEIDocumentFeatures())
        #expect(scan.features["d5"] == TEIDocumentFeatures(inlineSourceNote: true))
        #expect(scan.features["d6"] == TEIDocumentFeatures(inlineSourceNote: true))
        #expect(scan.features["d1"]?.inlineSourceNote == false)
    }

    @Test("The TEI scan keeps the ids a document's @ana names in its volume")
    func scanRecordsAnnotatedIds() throws {
        let scan = try TEIAnnotationScanner.scan(data: Data(Self.annotatedXML.utf8))
        #expect(scan.documentIds == ["d368", "d369", "d370"])
        #expect(scan.features["d368"]?.annotatedIds == ["p_HAMJ_1", "p_RRW_1", "t_EXDIS_1", "t_OAS_1"])
        // A pointer into another file names nothing in this volume, as in the reader.
        #expect(scan.features["d369"]?.annotatedIds == ["p_RRW_1"])
        #expect(scan.features["d370"] == TEIDocumentFeatures())
        #expect(scan.features["d368"]?.glossTargets.isEmpty == true)
    }

    // MARK: Through the pipeline

    @Test("A volume indexed through the kit's pipeline is counted by the app's rules")
    func countsAVolumeIndexedThroughThePipeline() async throws {
        let root = try Self.corpus()
        defer { try? FileManager.default.removeItem(at: root) }
        let index = try await VolumeAnnotationsIndexRunner.build(Self.configuration(root))
        #expect(index.indexVersion == IndexingPipeline.currentDateIndexVersion)
        #expect(index.corpusCommit == "fixture" && index.generated == "2026-11-06")
        let volume = try #require(index[Self.volume])
        #expect(volume.era == .from1969)
        #expect(volume.publicationYear == 2026)
        #expect(volume.documents == 6 && volume.historicalDocuments == 5)
        #expect(volume.personsListed == 3 && volume.termsListed == 2)
        // d5's "No. 3." is a despatch number, so the one file-number note is d6's.
        let expected: [AnnotationCategory: Int] = [
            .people: 3, .abbreviations: 2, .correspondents: 1, .subjects: 1, .participants: 1,
            .sourceCitation: 2, .sourceFileNumber: 1, .classification: 2, .excisions: 2, .despatch: 1,
            .numbered: 3, .xrefDocuments: 1, .xrefFootnotes: 1, .xrefVolumes: 1, .xrefPages: 1,
            .editorialNotes: 1, .footnotes: 1, .marginalNotes: 1, .figures: 1,
        ]
        for category in AnnotationCategory.allCases {
            #expect(volume.count(category) == (expected[category] ?? 0), "\(category.rawValue)")
        }
        // Three of six documents: half, so both are carried.
        #expect(volume.carries(.people) && volume.carriesSourceNotes)
        #expect(Set(["preface", "sources", "terms", "persons"]).isSubset(of: volume.sections))
        #expect(!volume.sections.contains("compilation"))
    }

    @Test("People and terms named only on a document's @ana are counted, as the reader lists them")
    func countsTheDocumentsAnaPointers() async throws {
        let root = try Self.corpus(xml: Self.annotatedXML)
        defer { try? FileManager.default.removeItem(at: root) }
        let volume = try #require(try await VolumeAnnotationsIndexRunner.build(Self.configuration(root))[Self.volume])
        #expect(volume.documents == 3 && volume.personsListed == 2 && volume.termsListed == 2)
        // People through the index's mentions (#1599, index version 67); terms through the scan.
        #expect(volume.count(.people) == 2)
        // d368 names two terms; d369's one points into another file, and d370 names none.
        #expect(volume.count(.abbreviations) == 1)
    }

    @Test("An Index of Persons lists no one, and is an index among the volume's sections")
    func anIndexOfPersonsListsNoOne() async throws {
        let xml = Self.xml.replacingOccurrences(of: "</body>", with: "</body><back>\(Self.indexOfPersons)</back>")
        #expect(xml != Self.xml)
        let root = try Self.corpus(xml: xml)
        defer { try? FileManager.default.removeItem(at: root) }
        let volume = try #require(try await VolumeAnnotationsIndexRunner.build(Self.configuration(root))[Self.volume])
        // The List of Persons' three; until index version 74 the index added its three fragments.
        #expect(volume.personsListed == 3)
        #expect(volume.sections.contains("index") && volume.sections.contains("persons"))
        #expect(volume.count(.people) == 3)
    }

    @Test("Bracketed omissions are counted whatever the year, and carried only from 1925")
    func theGateOnBracketedOmissions() async throws {
        let before = try Self.corpus(xml: Self.omissionsXML(publicationDate: Self.published1924))
        defer { try? FileManager.default.removeItem(at: before) }
        let gated = try #require(try await VolumeAnnotationsIndexRunner.build(Self.configuration(before))[Self.volume])
        #expect(gated.publicationYear == 1924)
        #expect(gated.count(.editorialOmissions) == 6, "o1, o5, o6, o7, o9 and o11")
        #expect(!gated.carries(.editorialOmissions) && gated.publishedBeforeEditorialOmissionsOrder)
        // The gate is the layer's alone: the redaction o3 marks is carried.
        #expect(gated.carries(.excisions) && gated.count(.excisions) == 1)

        let from = try Self.corpus(xml: Self.omissionsXML(publicationDate: Self.published1925))
        defer { try? FileManager.default.removeItem(at: from) }
        let carried = try #require(try await VolumeAnnotationsIndexRunner.build(Self.configuration(from))[Self.volume])
        #expect(carried.publicationYear == 1925)
        #expect(carried.count(.editorialOmissions) == 6 && carried.carries(.editorialOmissions))
        #expect(!carried.publishedBeforeEditorialOmissionsOrder)
        // The year is in the file, and comes back.
        let data = try VolumeAnnotationsIndex(generated: "2026-11-08", corpusCommit: "fixture", indexVersion: 1,
                                              volumes: [Self.volume: gated]).shippingData()
        #expect(String(decoding: data, as: UTF8.self).contains(",1924]"))
        #expect(try JSONDecoder().decode(VolumeAnnotationsIndex.self, from: data)[Self.volume]?.publicationYear == 1924)
    }

    @Test("The file is the same bytes run to run, and reads back as written")
    func theFileIsDeterministicAndRoundTrips() async throws {
        let root = try Self.corpus()
        defer { try? FileManager.default.removeItem(at: root) }
        let first = try await VolumeAnnotationsIndexRunner.build(Self.configuration(root))
        // The second run reads the index the first one kept.
        let second = try await VolumeAnnotationsIndexRunner.build(Self.configuration(
            root, index: .existing(root.appendingPathComponent("index/frus.db"))))
        let data = try first.shippingData()
        let again = try second.shippingData()
        #expect(data == again)
        #expect(try JSONDecoder().decode(VolumeAnnotationsIndex.self, from: data) == first)
    }

    // MARK: Refusals

    @Test("A run without CORPUS_COMMIT is refused")
    func refusesWithoutACorpusCommit() {
        #expect(throws: VolumeAnnotationsIndexError.missingCorpusCommit) {
            _ = try VolumeAnnotationsIndexConfiguration(environment: ["VOLUMES_DIR": "/tmp"])
        }
    }

    @Test("A manifest volume with no file is refused")
    func refusesAMissingVolume() async throws {
        let root = try Self.corpus()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.removeItem(at: root.appendingPathComponent("corpus/\(Self.volume).xml"))
        await #expect(throws: VolumeAnnotationsIndexError.missingVolumes([Self.volume])) {
            _ = try await VolumeAnnotationsIndexRunner.build(Self.configuration(root))
        }
    }

    @Test("A corpus where no volume carries people tagging is refused")
    func refusesACorpusWithNoPeopleTagging() async throws {
        let untagged = Self.xml.replacingOccurrences(of: "corresp=\"#p_", with: "data-corresp=\"#p_")
        let root = try Self.corpus(xml: untagged)
        defer { try? FileManager.default.removeItem(at: root) }
        await #expect(throws: VolumeAnnotationsIndexError.noPeopleTagging) {
            _ = try await VolumeAnnotationsIndexRunner.build(Self.configuration(root))
        }
    }

    @Test("An INDEX_DB that names no file is refused")
    func refusesAMissingIndexDatabase() async throws {
        let root = try Self.corpus()
        defer { try? FileManager.default.removeItem(at: root) }
        let missing = root.appendingPathComponent("absent.db")
        await #expect(throws: VolumeAnnotationsIndexError.noIndex(missing.path)) {
            _ = try await VolumeAnnotationsIndexRunner.build(Self.configuration(root, index: .existing(missing)))
        }
    }
}
