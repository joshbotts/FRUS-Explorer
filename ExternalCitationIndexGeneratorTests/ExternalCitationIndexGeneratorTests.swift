// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import ExternalCitationIndexGeneratorCore
import CollectionAuthorityGeneratorCore
import SourceExplorerExportGeneratorCore
import SourceNoteKit

// MARK: - FootnoteCitationGrammarTests

/// The anchor-first grammar (#784) — what it reads, and the four things it refuses.
///
/// Every fixture in the refusal section is a **real corpus shape** that the first implementation
/// got wrong, not an invented adversarial string. They are the reason the generator writes a
/// sample file at all.
///
/// Version history:
///   1.0 — Session 2026-08-10: #784
@Suite("Footnote citation grammar (#784)")
struct FootnoteCitationGrammarTests {

    /// Runs one note through a fresh scanner, as if it were a document's only footnote.
    private func scan(_ note: String) -> [FootnoteArchivalCitation] {
        var scanner = FootnoteCitationScanner()
        scanner.beginDocument()
        return scanner.scan(note: note)
    }

    // MARK: - The two anchors

    @Test("A D-designator lot is read with the parser's own regex, so it normalises identically")
    func readsDesignatorLot() throws {
        let found = scan("A copy is in Department of State, S/S – NSC Files: Lot 63 D 351, NSC 68 Series.")
        let citation = try #require(found.first)
        #expect(citation.anchor == .lotFile)
        guard case .lotFile(let rg, let lot, _) = citation.parsed else {
            Issue.record("expected .lotFile, got \(citation.parsed)"); return
        }
        #expect(lot == "63 D 351")
        #expect(rg == "RG-59")
        #expect(SourceNoteParser.lotFileNorm(lot) == "63D351", """
            The normal form is the join key to `document_sources.lot_file_norm` and to the \
            authority's `lot:` records. If this drifts, the harvest resolves to nothing.
            """)
    }

    @Test("An F-designator lot is attributed to RG 84, like a source note's")
    func readsPostRecordsLot() throws {
        let found = scan("The despatch is in Saigon Embassy Files: Lot 68 F 8.")
        guard case .lotFile(let rg, _, _)? = found.first?.parsed else {
            Issue.record("expected .lotFile"); return
        }
        #expect(rg == "RG-84")
    }

    @Test("A bare-number lot is read only behind the `Files: Lot` anchor")
    func readsBareLotOnlyBehindItsAnchor() {
        #expect(scan("A revised draft is in FE Files, Lot 244.").count == 1,
                "the pre-1950 form, and the shape SourceNoteParser.tryInlineLotFile also requires")
        #expect(scan("The delegation drew lot 3 and went second.").isEmpty, """
            A bare `lot N` in running prose must not mint a citation. The `Files` anchor is what \
            separates an archival lot number from the ordinary English word.
            """)
    }

    @Test("A library citation takes the comma segment after the library as its collection")
    func readsLibraryAndCollection() throws {
        let found = scan("A copy is in the Johnson Library, National Security File, Country File, Vietnam.")
        let citation = try #require(found.first)
        #expect(citation.anchor == .presidentialLibrary)
        guard case .presidentialLibrary(let library, let collection, _) = citation.parsed else {
            Issue.record("expected .presidentialLibrary"); return
        }
        #expect(library == "Johnson Library")
        #expect(collection == "National Security File")
    }

    @Test("A full-name library keeps its forename initials")
    func readsFullLibraryName() throws {
        let found = scan("Copy obtained from the Franklin D. Roosevelt Library, Hyde Park, N. Y.")
        guard case .presidentialLibrary(let library, _, _)? = found.first?.parsed else {
            Issue.record("expected .presidentialLibrary"); return
        }
        #expect(library == "Franklin D. Roosevelt Library", """
            The clause splitter must not cut at `D.` or `N.` — a single-letter word before a \
            period is an initial, not a sentence end. Splitting there yields `Franklin D` and \
            destroys the anchor.
            """)
    }

    @Test("A note may point at several units, and all of them are kept")
    func keepsEveryCitationInANote() {
        let found = scan("""
            Drafts are in Department of State, Conference Files: Lot 60 D 627, CF 200; \
            another copy is in the Eisenhower Library, Whitman File.
            """)
        #expect(found.count == 2, """
            The `citations.first` truncation is exactly what #783 removed from document_sources \
            (1,182 of 3,208 discarded). Got: \(found.map(\.citation))
            """)
    }

    @Test("A footnote that cites nothing archival yields nothing")
    func ignoresOrdinaryProse() {
        #expect(scan("Assistant Under Secretary in the British Foreign Office.").isEmpty)
        #expect(scan("For previous documentation, see Foreign Relations, 1951, vol. I, p. 12.").isEmpty)
    }

    // MARK: - Refusal 1: absence claims

    @Test("An archive named inside a `not found` clause is refused")
    func refusesAbsenceClaims() {
        var scanner = FootnoteCitationScanner()
        scanner.beginDocument()
        // frus1952-54v01p2/d140 fn2, in full.
        #expect(scanner.scan(note: "Not found in Department of State files or at the Truman Library.").isEmpty)
        // frus1942v03, verbatim. This is the load-bearing fixture: the library is followed by a
        // segment, so without the guard it *would* be harvested — which is what the
        // `absenceBlockedCount` assertion below proves, since the counter only rises when the
        // refused clause actually carried a unit.
        #expect(scanner.scan(note: "No record of this discussion found in Department files or at the Franklin D. Roosevelt Library, Hyde Park, N. Y.").isEmpty)
        #expect(scanner.absenceBlockedCount == 1, """
            One of the two, not both: `at the Truman Library.` names a repository and no \
            collection, so it is not a unit this grammar reads and the guard has nothing to \
            remove. The counter exists so the guard reports its cost instead of hiding it.
            """)
    }

    @Test("A library with no collection after it is not a unit")
    func refusesABareRepository() {
        #expect(scan("The memorandum is at the Truman Library.").isEmpty, """
            #784's scope is "library **and** collection". A bare repository cannot resolve \
            against the authority, which is keyed on the collection segment, so storing one \
            would add a row that no surface can do anything with.
            """)
    }

    @Test("The absence guard is per clause, so a real citation beside one still lands")
    func absenceGuardIsScopedToItsClause() throws {
        let found = scan("Not printed. (Truman Library, Papers of Clark M. Clifford, National Military Establishment)")
        #expect(found.count == 1, """
            `Not printed` is a statement about the volume, not about an archive. The citation \
            lives in the next clause and both readings are correct.
            """)
        guard case .presidentialLibrary(let library, _, _)? = found.first?.parsed else {
            Issue.record("expected .presidentialLibrary"); return
        }
        #expect(library == "Truman Library")
    }

    // MARK: - Refusal 3 + the Ibid. state machine

    /// Scans several notes in order through one scanner — the document-ordered pass.
    private func scanDocument(_ notes: [String]) -> [[FootnoteArchivalCitation]] {
        var scanner = FootnoteCitationScanner()
        scanner.beginDocument()
        return notes.map { scanner.scan(note: $0) }
    }

    @Test("A bare Ibid. inherits the unit named in a preceding footnote")
    func bareIbidInherits() throws {
        let found = scanDocument([
            "The report is in Department of State, S/S – NSC Files: Lot 63 D 351.",
            "Ibid.",
        ])
        let inherited = try #require(found[1].first)
        #expect(inherited.inherited)
        guard case .lotFile(_, let lot, _) = inherited.parsed else {
            Issue.record("expected .lotFile"); return
        }
        #expect(lot == "63 D 351")
    }

    @Test("An Ibid. naming its own collection does NOT inherit the previous one")
    func ibidNamingACollectionDoesNotInherit() {
        // The first corpus run recorded this footnote against `Recordings and Transcripts`,
        // because it inherited the previous unit and ignored the collection the clause names.
        let found = scanDocument([
            "The tape is in the Johnson Library, Recordings and Transcripts, Tape F65.06.",
            "(Ibid., National Security File, Country File, Vietnam, HARVAN Misc)",
        ])
        #expect(found[1].isEmpty, """
            `Ibid., <collection>` means the same *library*, a different collection — not the same \
            unit. Inheriting here files a footnote under a collection it explicitly did not name.
            """)
    }

    @Test("An Ibid. naming a decimal file does NOT inherit a lot")
    func ibidNamingADecimalFileDoesNotInherit() {
        // Also from the first corpus run: recorded against `Conference Files: Lot 62 D 181`.
        let found = scanDocument([
            "The memorandum is in Department of State, Conference Files: Lot 62 D 181.",
            "(ibid., Central Files, 684A.86/8–956)",
        ])
        #expect(found[1].isEmpty, """
            A decimal file is a unit this grammar deliberately does not read (#784 scope). \
            Inheriting the previous lot invents an archival location the editor never wrote.
            """)
    }

    @Test("An Ibid. carrying only a box or a date still inherits")
    func ibidWithAFinerLocationInherits() throws {
        let found = scanDocument([
            "The memorandum is in the Johnson Library, Fowler Papers.",
            "Not attached, but a copy is ibid., 10/27/65, Box 53.",
        ])
        let inherited = try #require(found[1].first)
        #expect(inherited.inherited)
        guard case .presidentialLibrary(_, let collection, let fileId) = inherited.parsed else {
            Issue.record("expected .presidentialLibrary"); return
        }
        #expect(collection == "Fowler Papers")
        #expect(fileId == "Box 53", "the box is a finer location inside the inherited unit")
    }

    @Test("A bare Ibid. after a publication citation inherits nothing")
    func bareIbidDoesNotReachPastAPublication() {
        // The mutation sweep is why this test exists. Its sibling below passes even with the
        // note-level state clearing removed, because `Ibid., p. 68.` is caught one step earlier by
        // the clause's own publication cue. This fixture has no cue in the `Ibid.` clause at all,
        // so the only thing that can stop it inheriting the lot from two footnotes back is the
        // publication note in between invalidating the state — which is what a reader does, and
        // what mutation M3 undid while every test still passed.
        let found = scanDocument([
            "The paper is in Department of State, PPS Files: Lot 65 D 101.",
            "For the text, see Foreign Relations, 1952–1954, vol. III, p. 12.",
            "Ibid.",
        ])
        #expect(found[2].isEmpty, """
            The `Ibid.` refers to Foreign Relations, the thing last cited — not to the lot file \
            named before it. Inheriting the lot here files a printed-book reference as an \
            archival citation.
            """)
    }

    @Test("An Ibid. carrying a page reference is a publication reference, not an archival one")
    func ibidWithAPageReferenceIsNotArchival() {
        let found = scanDocument([
            "The paper is in Department of State, PPS Files: Lot 65 D 101.",
            "For the text, see Foreign Relations, 1952–1954, vol. III, p. 12.",
            "Ibid., p. 68.",
        ])
        #expect(found[2].isEmpty, """
            In the 19th-century volumes the commonest `Ibid.` refers to a book. A machine that \
            inherited "the last archive named" would attribute `(Ibid., p. 68.)` to an archive \
            several footnotes away.
            """)
    }

    @Test("An Ibid. does not reach back further than the printed page's neighbourhood")
    func ibidReachIsBounded() {
        let filler = Array(repeating: "The Ambassador was in Geneva.",
                           count: FootnoteCitationScanner.ibidReach)
        let found = scanDocument(["A copy is in FE Files: Lot 55 D 128."] + filler + ["Ibid."])
        #expect(found.last?.isEmpty == true)
    }

    @Test("Ibid. state resets at a document boundary")
    func ibidStateResetsPerDocument() {
        var scanner = FootnoteCitationScanner()
        scanner.beginDocument()
        _ = scanner.scan(note: "A copy is in Department of State, S/S – NSC Files: Lot 63 D 351.")
        scanner.beginDocument()
        #expect(scanner.scan(note: "Ibid.").isEmpty, """
            A footnote in document 12 cannot refer to a footnote in document 11 — they are \
            separately numbered on the printed page.
            """)
    }

    @Test("A document's first footnote cannot inherit from its source note")
    func ibidIsNotSeededFromTheSourceNote() {
        var scanner = FootnoteCitationScanner()
        scanner.beginDocument()
        #expect(scanner.scan(note: "Ibid.").isEmpty, """
            Seeding from the document's own unit would record a self-reference as an *external* \
            citation — the opposite of what this harvest measures.
            """)
    }
}

// MARK: - DocumentFootnoteExtractorTests

/// Which notes reach the grammar (#784) — and which must not.
///
/// Version history:
///   1.0 — Session 2026-08-10: #784
@Suite("Body footnote extraction (#784)")
struct DocumentFootnoteExtractorTests {

    private func extract(_ xml: String) -> [DocumentFootnoteExtractor.DocumentFootnotes] {
        DocumentFootnoteExtractor.extract(fromXML: Data(xml.utf8))
    }

    @Test("Body footnotes come back in reading order")
    func readsBodyFootnotesInOrder() throws {
        let documents = extract("""
        <TEI><text><body>
          <div type="document" xml:id="d1">
            <head>A memorandum</head>
            <p>First<note n="1" xml:id="d1fn1">Note one.</note> and second<note n="2" xml:id="d1fn2">Note two.</note>.</p>
          </div>
        </body></text></TEI>
        """)
        let document = try #require(documents.first)
        #expect(document.documentId == "d1")
        #expect(document.footnotes == ["Note one.", "Note two."])
    }

    @Test("The source note is excluded, and says why")
    func excludesTheSourceNote() throws {
        let document = try #require(extract("""
        <TEI><text><body>
          <div type="document" xml:id="d1">
            <note rend="inline" type="source">Camp files, lot 55 D 105.</note>
            <head>A memorandum</head>
            <p>Body<note n="1" xml:id="d1fn1">Note one.</note>.</p>
          </div>
        </body></text></TEI>
        """).first)
        #expect(document.footnotes == ["Note one."])
        #expect(document.excluded.map(\.reason) == [.sourceNote])
    }

    @Test("A head-nested note is excluded — it is the printed document's own provenance")
    func excludesHeadNestedNotes() throws {
        // frus1937v01/d29's real shape: the decimal file in a source note, and a *second*
        // provenance statement as footnote 1 inside the head.
        let document = try #require(extract("""
        <TEI><text><body>
          <div type="document" xml:id="d29">
            <note rend="inline" type="source">740.00/95½</note>
            <head>The Ambassador in Poland to President Roosevelt<note n="1" xml:id="d29fn1">Photostatic copy obtained from the Franklin D. Roosevelt Library, Hyde Park, N. Y.</note></head>
            <p>Body<note n="2" xml:id="d29fn2">A real footnote.</note>.</p>
          </div>
        </body></text></TEI>
        """).first)
        #expect(document.footnotes == ["A real footnote."], """
            Harvesting the head note would report the editors pointing *outside* the printed \
            record when they were describing where the printed record came from.
            """)
        #expect(document.excluded.contains { $0.reason == .headNested })
        #expect(document.excluded.filter { $0.reason == .headNested }
            .allSatisfy { FootnoteCitationScanner.carriesArchivalAnchor($0.text) }, """
            This fixture is only meaningful if the excluded note *would* have produced a citation.
            """)
    }

    @Test("A note carrying a source segment is excluded")
    func excludesSourceSegmentNotes() throws {
        let document = try #require(extract("""
        <TEI><text><body>
          <div type="document" xml:id="d1">
            <note n="1" xml:id="d1fn1"><seg type="source">Johnson Library, National Security File.</seg></note>
            <p>Body<note n="2" xml:id="d1fn2">A real footnote.</note>.</p>
          </div>
        </body></text></TEI>
        """).first)
        #expect(document.footnotes == ["A real footnote."])
        #expect(document.excluded.map(\.reason) == [.sourceSegment])
    }

    @Test("An editorial note's footnotes ARE read")
    func readsEditorialNoteFootnotes() throws {
        let document = try #require(extract("""
        <TEI><text><body>
          <div type="document" subtype="editorial-note" xml:id="d5">
            <head>Editorial Note</head>
            <p>The Council met<note n="1" xml:id="d5fn1">Minutes are in OCB Files: Lot 62 D 430.</note>.</p>
          </div>
        </body></text></TEI>
        """).first)
        #expect(document.footnotes == ["Minutes are in OCB Files: Lot 62 D 430."], """
            `DocumentNoteExtractor` yields nothing for these documents because the app stores no \
            source note for them. A footnote walk recurses, so both sides must read them — and \
            editorial notes are the documents most likely to cite unprinted material.
            """)
    }

    @Test("A note inside a note is not captured twice")
    func doesNotDoubleCountNestedNotes() throws {
        let document = try #require(extract("""
        <TEI><text><body>
          <div type="document" xml:id="d1">
            <p>Body<note n="1" xml:id="d1fn1">Outer<note n="2" xml:id="d1fn2">inner</note> tail.</note>.</p>
          </div>
        </body></text></TEI>
        """).first)
        #expect(document.footnotes.count == 1)
        #expect(document.footnotes[0].contains("inner"),
                "the outer note's text already contains the inner one")
    }
}

// MARK: - ExternalCitationIndexRunnerTests

/// The aggregation behind `external-citation-index.json` (#784), over a fixture corpus.
///
/// Version history:
///   1.0 — Session 2026-08-10: #784
@Suite("External citation index — generator")
struct ExternalCitationIndexRunnerTests {

    private func fixtureAuthority() -> AuthorityLookup {
        AuthorityLookup(collections: [
            AuthorityCollection(id: "lot:63D351", name: "S/S–NSC Files: Lot 63 D 351",
                                lotFileNorm: "63D351"),
            AuthorityCollection(id: "lot:60D627", name: "Conference Files: Lot 60 D 627",
                                lotFileNorm: "60D627"),
            AuthorityCollection(id: "txt:johnson library|national security file",
                                name: "National Security File", repository: "Johnson Library"),
        ])
    }

    /// A volume whose documents carry a source note and a list of body footnotes.
    private func volume(_ id: String, documents: [(source: String, footnotes: [String])],
                        in directory: URL) throws -> URL {
        let divs = documents.enumerated().map { index, document in
            let notes = document.footnotes.enumerated().map { i, text in
                "<note n=\"\(i + 1)\" xml:id=\"d\(index + 1)fn\(i + 1)\">\(text)</note>"
            }.joined()
            return """
              <div type="document" xml:id="d\(index + 1)">
                <note type="source">\(document.source)</note>
                <head>Document \(index + 1)</head>
                <p>Body.\(notes)</p>
              </div>
            """
        }.joined(separator: "\n")
        let url = directory.appendingPathComponent("\(id).xml")
        try Data("<TEI><text><body>\n\(divs)\n</body></text></TEI>".utf8).write(to: url)
        return url
    }

    private func fixtureCorpus() throws -> [URL] {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("extcit-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return [
            try volume("frus1952-54v01", documents: [
                (source: "Source: Department of State, Conference Files: Lot 60 D 627, CF 200.",
                 footnotes: [
                    "A copy is in Department of State, S/S – NSC Files: Lot 63 D 351.",
                    "Ibid.",
                    "Not found in Department of State files or at the Truman Library.",
                 ]),
            ], in: root),
            try volume("frus1964-68v02", documents: [
                (source: "Source: Johnson Library, National Security File, Country File, Vietnam.",
                 footnotes: [
                    "Another copy is in the Johnson Library, National Security File, Komer Files.",
                    // #834's decimal channel. The corpus writes these with the class LEADING a
                    // comma segment; buried behind prose in its own segment it is not found, which
                    // is a property of `decimalClassLocation` and not of this fixture.
                    //
                    // It is here because `build` THROWS when the decimal channel resolves nothing
                    // — a guard that is right for the 552-volume corpus and was wrong for a
                    // fixture corpus with no decimal citation in it. Adding one keeps the guard
                    // meaningful AND gives the generator suite its only class-axis coverage;
                    // relaxing the guard would have removed a real protection to accommodate a
                    // thin fixture.
                    "Telegram 1345 from Moscow, March 5, 763.72/9732.",
                 ]),
            ], in: root),
            // A volume whose footnotes cite nothing — most of the corpus looks like this.
            try volume("frus1969-76v03", documents: [
                (source: "Source: Department of State, Conference Files: Lot 60 D 627, CF 300.",
                 footnotes: ["Assistant Secretary of State for European Affairs."]),
            ], in: root),
        ]
    }

    private func build(_ files: [URL]) throws -> ExternalCitationIndexRunner.BuildResult {
        // #834 commit 2 gave `build` the classification schedule the decimal channel needs. The
        // SHIPPED table is used rather than a fixture: the rule under test is "does this key
        // compose under the State Department's real schedule", and a two-class stub would answer a
        // different question while looking like the same test.
        try ExternalCitationIndexRunner.build(files: files, authority: fixtureAuthority(),
                                              authorityCollectionCount: 3,
                                              schedule: try DecimalChannelMeasurement
                                                  .ScheduleValidator(labelsPath: labelsPath),
                                              sampleEvery: 0,
                                              generated: "2026-08-10")
    }

    /// The bundled 1910-1949 schedule, from the repo rather than a bundle: this is an SPM test
    /// target with no app bundle to read from.
    private var labelsPath: String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()      // ExternalCitationIndexGeneratorTests
            .deletingLastPathComponent()      // repo root
            .appendingPathComponent("FRUSExplorer/Resources/decimal-class-labels.json")
            .path
    }

    @Test("References are counted per target unit and per volume")
    func aggregatesByTargetAndVolume() throws {
        let index = try build(try fixtureCorpus()).index
        #expect(index.volumes == ["frus1952-54v01", "frus1964-68v02"],
                "a volume with no references is not an axis position")
        let nsc = try #require(index.targets.first {
            index.targetIds[$0.key] == "lot:63D351"
        })
        #expect(nsc.total == 2, "the direct citation and the Ibid. that inherits it")
        #expect(index.coverage.referencesInherited == 1)
        #expect(index.coverage.absenceClaimsRefused == 0, """
            The fixture's absence note is `Not found in Department of State files or at the \
            Truman Library.` — refused, but it named no collection, so it was never a unit and \
            the counter (which measures what the guard *removed*) stays at zero. \
            `FootnoteCitationGrammarTests.refusesAbsenceClaims` covers the case where it rises.
            """)
    }

    @Test("A pair joins the citing document's own unit to the unit its footnote points at")
    func buildsPairsFromBothEnds() throws {
        let index = try build(try fixtureCorpus()).index
        let sourceIndex = try #require(index.sourceIds.firstIndex(of: "lot:60D627"))
        let targetIndex = try #require(index.targetIds.firstIndex(of: "lot:63D351"))
        let pair = try #require(index.pairs.first {
            $0.source == sourceIndex && $0.target == targetIndex
        })
        #expect(pair.count == 2, """
            The editors, annotating material drawn from Conference Files, pointed the reader at \
            material in the NSC files. That is the claim the Flows layer draws.
            """)
    }

    @Test("A same-unit reference is stored and counted, never silently dropped")
    func storesSameUnitReferences() throws {
        let index = try build(try fixtureCorpus()).index
        #expect(index.coverage.sameUnitReferences == 1, """
            frus1964-68v02's document is drawn from the National Security File and its footnote \
            points at more of the National Security File. No diagram draws that, but an artifact \
            that had dropped it could not disclose what the exclusion removed.
            """)
        let selfIndex = try #require(index.sourceIds.firstIndex(of: "txt:johnson library|national security file"))
        #expect(index.pairs.contains { $0.source == selfIndex })
    }

    @Test("The head-nested exclusion is measured, not merely applied")
    func reportsWhatTheHeadNestedGuardCost() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("extcit-head-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("frus1952-54v01.xml")
        try Data("""
        <TEI><text><body>
          <div type="document" xml:id="d1">
            <note type="source">Source: Department of State, Conference Files: Lot 60 D 627, CF 200.</note>
            <head>A telegram<note n="1" xml:id="d1fn1">Copy obtained from the Franklin D. Roosevelt Library, Hyde Park, N. Y.</note></head>
            <p>Body<note n="2" xml:id="d1fn2">A copy is in Department of State, S/S – NSC Files: Lot 63 D 351.</note>.</p>
          </div>
        </body></text></TEI>
        """.utf8).write(to: url)
        let index = try build([url]).index
        #expect(index.coverage.headNestedExcluded == 1)
        #expect(index.coverage.headNestedExcludedWithAnchor == 1)
        #expect(index.coverage.referencesFound == 1, "only the body footnote is harvested")
    }

    @Test("A run that joins nothing throws rather than writing an index of zeroes")
    func refusesABrokenJoin() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("extcit-empty-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let files = [try volume("frus1952-54v01", documents: [
            (source: "Source: Department of State, Central Files, 611.41/3–553.",
             footnotes: ["The Ambassador was in Geneva."]),
        ], in: root)]
        #expect(throws: ExternalCitationError.self) { _ = try build(files) }
    }

    @Test("Two builds of the same corpus are byte-identical")
    func isDeterministic() throws {
        let files = try fixtureCorpus()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let first = try encoder.encode(try build(files).index)
        let second = try encoder.encode(try build(files).index)
        #expect(first == second)
    }

    @Test("A row whose parallel arrays have drifted apart is refused at decode")
    func refusesDriftedRows() {
        let json = Data(#"{"k":0,"v":[0,1],"n":[3]}"#.utf8)
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode(ExternalCitationIndex.UnitRow.self, from: json)
        }
    }
}
