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

// MARK: - Fixture Helpers

private func makeVolume(
    title: String,
    editors: [String],
    generalEditor: String? = nil,
    publicationDate: String = "1972",
    publicationPlace: String = "Washington",
    publisher: String = "Government Printing Office"
) -> FRUSVolumeMetadata {
    FRUSVolumeMetadata(
        title: title,
        editors: editors,
        generalEditor: generalEditor,
        publicationDate: publicationDate,
        publicationPlace: publicationPlace,
        publisher: publisher
    )
}

private func makeDocument(
    documentId: String = "d1",
    documentNumber: String? = "1",
    header: String = "Memorandum of Conversation",
    dateline: String? = "Washington, January 20, 1969."
) -> FRUSDocumentMetadata {
    FRUSDocumentMetadata(
        documentId: documentId,
        documentNumber: documentNumber,
        header: header,
        dateline: dateline
    )
}

// MARK: - CitationFormatterTests

struct CitationFormatterTests {

    private let formatter = HistoryAtStateCitationFormatter()

    // MARK: - Standard Citation

    @Test("Standard citation with two editors produces correct output")
    func standardCitation() {
        let volume = makeVolume(
            title: "Foreign Relations of the United States, 1969–1976, Volume I, Foundations of Foreign Policy, 1969–1972",
            editors: ["Louis J. Smith", "David H. Herschler"],
            generalEditor: "David S. Patterson",
            publicationDate: "1972"
        )
        let doc = makeDocument(documentNumber: "1")

        let result = formatter.format(document: doc, volume: volume)

        #expect(result == "_Foreign Relations of the United States_, 1969–1976, Volume I, Foundations of Foreign Policy, 1969–1972, eds. Louis J. Smith and David H. Herschler (Washington: Government Printing Office, 1972), Document 1.")
    }

    // MARK: - Multiple Editors

    @Test("Three editors use Oxford comma format")
    func multipleEditors() {
        let volume = makeVolume(
            title: "Foreign Relations of the United States, 1969–1976, Volume XIX, Part 1, Korea, 1969–1972",
            editors: ["Daniel J. Lawler", "Erin R. Mahan", "Adam M. Howard"],
            publicationDate: "2010"
        )
        let doc = makeDocument(documentNumber: "75")

        let result = formatter.format(document: doc, volume: volume)

        #expect(result == "_Foreign Relations of the United States_, 1969–1976, Volume XIX, Part 1, Korea, 1969–1972, eds. Daniel J. Lawler, Erin R. Mahan, and Adam M. Howard (Washington: Government Printing Office, 2010), Document 75.")
    }

    @Test("Single editor uses singular 'ed.' prefix")
    func singleEditor() {
        let volume = makeVolume(
            title: "Foreign Relations of the United States, 1977–1980, Volume I, Foundations of Foreign Policy",
            editors: ["Kristin L. Ahlberg"],
            publicationDate: "2014"
        )
        let doc = makeDocument(documentNumber: "12")

        let result = formatter.format(document: doc, volume: volume)

        #expect(result.contains("ed. Kristin L. Ahlberg"))
        #expect(!result.contains("eds."))
    }

    // MARK: - No Dateline

    @Test("Document without dateline produces identical citation to one with dateline")
    func noDateline() {
        let volume = makeVolume(
            title: "Foreign Relations of the United States, 1969–1976, Volume I, Foundations of Foreign Policy, 1969–1972",
            editors: ["Louis J. Smith", "David H. Herschler"],
            publicationDate: "1972"
        )
        let docWithDateline = makeDocument(documentNumber: "5", dateline: "Washington, March 15, 1969.")
        let docWithoutDateline = makeDocument(documentNumber: "5", dateline: nil)

        let withDateline = formatter.format(document: docWithDateline, volume: volume)
        let withoutDateline = formatter.format(document: docWithoutDateline, volume: volume)

        // Dateline is not part of the history.state.gov citation style
        #expect(withDateline == withoutDateline)
        #expect(!withDateline.contains("Washington, March 15"))
    }

    // MARK: - Editorial Note (No Document Number)

    @Test("Editorial note without document number omits 'Document N' and ends with period")
    func editorialNote() {
        let volume = makeVolume(
            title: "Foreign Relations of the United States, 1969–1976, Volume I, Foundations of Foreign Policy, 1969–1972",
            editors: ["Louis J. Smith", "David H. Herschler"],
            publicationDate: "1972"
        )
        let doc = FRUSDocumentMetadata(
            documentId: "edn-01",
            documentNumber: nil,
            header: "Editorial Note",
            dateline: nil
        )

        let result = formatter.format(document: doc, volume: volume)

        #expect(!result.contains("Document"))
        #expect(result.hasSuffix("."))
        #expect(result == "_Foreign Relations of the United States_, 1969–1976, Volume I, Foundations of Foreign Policy, 1969–1972, eds. Louis J. Smith and David H. Herschler (Washington: Government Printing Office, 1972).")
    }

    // MARK: - Subseries

    @Test("Subseries identifier appears correctly after italicized series name")
    func subseriesInCitation() {
        let volume = makeVolume(
            title: "Foreign Relations of the United States, 1977–1980, Volume XXXVIII, Part 1, Foundations of Foreign Policy",
            editors: ["Adam M. Howard"],
            publicationDate: "2015",
            publisher: "United States Government Publishing Office"
        )
        let doc = makeDocument(documentNumber: "42")

        let result = formatter.format(document: doc, volume: volume)

        #expect(result.hasPrefix("_Foreign Relations of the United States_, 1977–1980,"))
        #expect(result.contains("1977–1980, Volume XXXVIII, Part 1"))
    }

    // MARK: - Historical Series Variant

    @Test("Early-series title 'Papers Relating to...' is correctly italicized")
    func historicalSeriesTitle() {
        let volume = makeVolume(
            title: "Papers Relating to the Foreign Relations of the United States, Transmitted to Congress, 1870",
            editors: [],
            publicationDate: "1871"
        )
        let doc = FRUSDocumentMetadata(documentId: "d1", documentNumber: nil, header: "Note", dateline: nil)

        let result = formatter.format(document: doc, volume: volume)

        #expect(result.hasPrefix("_Papers Relating to the Foreign Relations of the United States_"))
    }

    // MARK: - Publication Year Extraction

    @Test("Year is extracted from a range-style publicationDate string")
    func yearFromRange() {
        let year = FRUSVolumeMetadata.firstYear(in: "1967 to 1972")
        #expect(year == 1967)
    }

    @Test("Year is extracted from a plain year string")
    func yearFromPlain() {
        let year = FRUSVolumeMetadata.firstYear(in: "2010")
        #expect(year == 2010)
    }

    @Test("Publisher is GPO for pre-2014 year")
    func publisherPreGPORename() {
        let entry = VolumeManifestEntry(
            volumeId: "frus1969-76v01",
            filename: "frus1969-76v01.xml",
            subseries: "1969-76",
            title: "Foreign Relations of the United States, 1969–1976, Volume I, Test",
            dateRange: DateRange(earliest: nil, latest: nil),
            publicationDate: "1972",
            status: .published,
            editors: ["Test Editor"],
            generalEditor: nil,
            documentCount: 0,
            sizeBytes: 0,
            tags: []
        )
        let meta = FRUSVolumeMetadata(entry)
        #expect(meta.publisher == "Government Printing Office")
    }

    @Test("Publisher is USGPO for post-2014 year")
    func publisherPostGPORename() {
        let entry = VolumeManifestEntry(
            volumeId: "frus2020v01",
            filename: "frus2020v01.xml",
            subseries: "2020",
            title: "Foreign Relations of the United States, 2020, Volume I",
            dateRange: DateRange(earliest: nil, latest: nil),
            publicationDate: "2020",
            status: .published,
            editors: ["Test Editor"],
            generalEditor: nil,
            documentCount: 0,
            sizeBytes: 0,
            tags: []
        )
        let meta = FRUSVolumeMetadata(entry)
        #expect(meta.publisher == "United States Government Publishing Office")
    }

    @Test("Title whitespace is normalized from TEI multi-line format")
    func titleNormalization() {
        let entry = VolumeManifestEntry(
            volumeId: "frus1969-76v01",
            filename: "frus1969-76v01.xml",
            subseries: "1969-76",
            title: "Foreign Relations of the United States, 1969–1976, Volume I,\n                    Foundations of Foreign Policy, 1969–1972",
            dateRange: DateRange(earliest: nil, latest: nil),
            publicationDate: "1972",
            status: .published,
            editors: [],
            generalEditor: nil,
            documentCount: 0,
            sizeBytes: 0,
            tags: []
        )
        let meta = FRUSVolumeMetadata(entry)
        #expect(!meta.title.contains("\n"))
        #expect(!meta.title.contains("  "))
        #expect(meta.title == "Foreign Relations of the United States, 1969–1976, Volume I, Foundations of Foreign Policy, 1969–1972")
    }
}

// MARK: - ChicagoCitationFormatterTests

struct ChicagoCitationFormatterTests {

    private let formatter = ChicagoCitationFormatter()

    @Test("Standard citation with two editors uses 'edited by' and full title")
    func standardCitation() {
        let volume = makeVolume(
            title: "Foreign Relations of the United States, 1969–1976, Volume I, Foundations of Foreign Policy, 1969–1972",
            editors: ["Louis J. Smith", "David H. Herschler"],
            publicationDate: "1972"
        )
        let doc = makeDocument(documentNumber: "1")

        let result = formatter.format(document: doc, volume: volume)

        #expect(result == "*Foreign Relations of the United States, 1969–1976, Volume I, Foundations of Foreign Policy, 1969–1972*, edited by Louis J. Smith and David H. Herschler (Washington: Government Printing Office, 1972), Document 1.")
    }

    @Test("Three editors use Oxford comma format with 'edited by'")
    func multipleEditors() {
        let volume = makeVolume(
            title: "Foreign Relations of the United States, 1969–1976, Volume XIX, Part 1, Korea, 1969–1972",
            editors: ["Daniel J. Lawler", "Erin R. Mahan", "Adam M. Howard"],
            publicationDate: "2010"
        )
        let doc = makeDocument(documentNumber: "75")

        let result = formatter.format(document: doc, volume: volume)

        #expect(result.contains("edited by Daniel J. Lawler, Erin R. Mahan, and Adam M. Howard"))
        #expect(result.hasSuffix("Document 75."))
    }

    @Test("Single editor uses 'edited by' without 'ed./eds.' prefix")
    func singleEditor() {
        let volume = makeVolume(
            title: "Foreign Relations of the United States, 1977–1980, Volume I, Foundations of Foreign Policy",
            editors: ["Kristin L. Ahlberg"],
            publicationDate: "2014"
        )
        let doc = makeDocument(documentNumber: "12")

        let result = formatter.format(document: doc, volume: volume)

        #expect(result.contains("edited by Kristin L. Ahlberg"))
        #expect(!result.contains("ed."))
    }

    @Test("Editorial note without document number omits 'Document N' and ends with period")
    func editorialNote() {
        let volume = makeVolume(
            title: "Foreign Relations of the United States, 1969–1976, Volume I, Foundations of Foreign Policy, 1969–1972",
            editors: ["Louis J. Smith", "David H. Herschler"],
            publicationDate: "1972"
        )
        let doc = FRUSDocumentMetadata(
            documentId: "edn-01",
            documentNumber: nil,
            header: "Editorial Note",
            dateline: nil
        )

        let result = formatter.format(document: doc, volume: volume)

        #expect(!result.contains("Document"))
        #expect(!result.contains("edn-01"))
        #expect(result == "*Foreign Relations of the United States, 1969–1976, Volume I, Foundations of Foreign Policy, 1969–1972*, edited by Louis J. Smith and David H. Herschler (Washington: Government Printing Office, 1972).")
    }

    @Test("No editors omits 'edited by' clause")
    func noEditors() {
        let volume = makeVolume(
            title: "Papers Relating to the Foreign Relations of the United States, Transmitted to Congress, 1870",
            editors: [],
            publicationDate: "1871"
        )
        let doc = makeDocument(documentNumber: "3")

        let result = formatter.format(document: doc, volume: volume)

        #expect(!result.contains("edited by"))
        #expect(result.hasPrefix("*Papers Relating to the Foreign Relations of the United States"))
    }
}

// MARK: - TurabianCitationFormatterTests

struct TurabianCitationFormatterTests {

    private let formatter = TurabianCitationFormatter()

    @Test("Standard citation with two editors uses period-delimited sentences")
    func standardCitation() {
        let volume = makeVolume(
            title: "Foreign Relations of the United States, 1969–1976, Volume I, Foundations of Foreign Policy, 1969–1972",
            editors: ["Louis J. Smith", "David H. Herschler"],
            publicationDate: "1972"
        )
        let doc = makeDocument(documentNumber: "1")

        let result = formatter.format(document: doc, volume: volume)

        #expect(result == "*Foreign Relations of the United States, 1969–1976, Volume I, Foundations of Foreign Policy, 1969–1972*. Edited by Louis J. Smith and David H. Herschler. Washington: Government Printing Office, 1972. Document 1.")
    }

    @Test("Three editors use Oxford comma format with 'Edited by'")
    func multipleEditors() {
        let volume = makeVolume(
            title: "Foreign Relations of the United States, 1969–1976, Volume XIX, Part 1, Korea, 1969–1972",
            editors: ["Daniel J. Lawler", "Erin R. Mahan", "Adam M. Howard"],
            publicationDate: "2010"
        )
        let doc = makeDocument(documentNumber: "75")

        let result = formatter.format(document: doc, volume: volume)

        #expect(result.contains("Edited by Daniel J. Lawler, Erin R. Mahan, and Adam M. Howard"))
        #expect(result.hasSuffix("Document 75."))
    }

    @Test("Editorial note without document number omits 'Document N' and ends after publication sentence")
    func editorialNote() {
        let volume = makeVolume(
            title: "Foreign Relations of the United States, 1969–1976, Volume I, Foundations of Foreign Policy, 1969–1972",
            editors: ["Louis J. Smith", "David H. Herschler"],
            publicationDate: "1972"
        )
        let doc = FRUSDocumentMetadata(
            documentId: "edn-01",
            documentNumber: nil,
            header: "Editorial Note",
            dateline: nil
        )

        let result = formatter.format(document: doc, volume: volume)

        #expect(!result.contains("Document"))
        #expect(!result.contains("edn-01"))
        #expect(result == "*Foreign Relations of the United States, 1969–1976, Volume I, Foundations of Foreign Policy, 1969–1972*. Edited by Louis J. Smith and David H. Herschler. Washington: Government Printing Office, 1972.")
    }

    @Test("No editors omits 'Edited by' sentence")
    func noEditors() {
        let volume = makeVolume(
            title: "Papers Relating to the Foreign Relations of the United States, Transmitted to Congress, 1870",
            editors: [],
            publicationDate: "1871"
        )
        let doc = makeDocument(documentNumber: "3")

        let result = formatter.format(document: doc, volume: volume)

        #expect(!result.contains("Edited by"))
        #expect(result.hasPrefix("*Papers Relating to the Foreign Relations of the United States"))
    }
}

// MARK: - CitationStyleTests

struct CitationStyleTests {

    @Test("CitationStyle.current defaults to historyAtState when unset")
    func defaultsToHistoryAtState() {
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: SettingsKeys.citationStyle)
        defer {
            if let saved { defaults.set(saved, forKey: SettingsKeys.citationStyle) }
            else { defaults.removeObject(forKey: SettingsKeys.citationStyle) }
        }
        defaults.removeObject(forKey: SettingsKeys.citationStyle)

        #expect(CitationStyle.current == .historyAtState)
    }

    @Test("CitationStyle.current persists and round-trips through UserDefaults")
    func persistsAndRoundTrips() {
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: SettingsKeys.citationStyle)
        defer {
            if let saved { defaults.set(saved, forKey: SettingsKeys.citationStyle) }
            else { defaults.removeObject(forKey: SettingsKeys.citationStyle) }
        }

        CitationStyle.current = .chicago
        #expect(CitationStyle.current == .chicago)
        #expect(defaults.string(forKey: SettingsKeys.citationStyle) == "chicago")

        CitationStyle.current = .turabian
        #expect(CitationStyle.current == .turabian)
    }

    @Test("makeFormatter() resolves each style to its expected formatter type")
    func makeFormatterResolvesEachStyle() {
        #expect(CitationStyle.historyAtState.makeFormatter() is HistoryAtStateCitationFormatter)
        #expect(CitationStyle.chicago.makeFormatter() is ChicagoCitationFormatter)
        #expect(CitationStyle.turabian.makeFormatter() is TurabianCitationFormatter)
    }
}

// MARK: - CitationPunctuationTests

/// Pins `CitationPunctuation.withoutTerminalPeriod(_:)` (#1392), the one rule every caller that
/// continues a citation shares: the Archives Visit packet's "Pointed at" and drawn-from lines and
/// the collection exporters' "See also:" line.
///
/// Its doc comment claims that ALL THREE formatters end every citation with a period, with a
/// printed number and without one. That claim is what makes removing one period safe, so the
/// first test checks it for every `CitationStyle` and both branches, against a real manifest
/// entry rather than a hand-built volume.
struct CitationPunctuationTests {

    /// The volume #1392's type case sits beside — its editor list prints "Sanford, Jr., and",
    /// so a citation from it contains ".," that no rule may touch.
    private static let volumeId = "frus1952-54v01p1"

    @Test("Every style ends in one period, and exactly that one comes off (#1392)",
          arguments: CitationStyle.allCases)
    @MainActor
    func everyStyleLosesExactlyItsTerminalPeriod(style: CitationStyle) throws {
        let entry = try #require(
            ManifestStore().bundledEntries.first { $0.volumeId == Self.volumeId },
            "the bundled manifest must carry \(Self.volumeId)")
        let volume = FRUSVolumeMetadata(entry)
        var checked = 0
        for number in ["41", nil] as [String?] {
            let document = FRUSDocumentMetadata(documentId: "d41", documentNumber: number,
                                                header: "", dateline: nil)
            let citation = style.makeFormatter().format(document: document, volume: volume)
            let stripped = CitationPunctuation.withoutTerminalPeriod(citation)
            #expect(citation.hasSuffix("."), """
                \(style) \(number == nil ? "without" : "with") a number no longer ends in a \
                period, so the helper's premise is false for it: \(citation)
                """)
            #expect(stripped + "." == citation, "exactly one character, the period, comes off")
            #expect(!stripped.hasSuffix("."), "\(style) left a period behind: \(stripped)")
            #expect(stripped.contains("Sanford, Jr., and"),
                    "the editor list's own punctuation must survive — the rule touches the end only")
            checked += 1
        }
        #expect(checked == 2)
    }

    /// The other branch: a string with no terminal period comes back as it was. That is the
    /// data sources' `volumeId/documentId` fallback for a volume the manifest does not know,
    /// which a caller then ends with its own period ("frus1952-54v99/d4, footnote 3.").
    @Test("A citation without a terminal period is returned unchanged (#1392)")
    func noTerminalPeriodIsUnchanged() {
        #expect(CitationPunctuation.withoutTerminalPeriod("frus1952-54v99/d4") == "frus1952-54v99/d4")
        #expect(CitationPunctuation.withoutTerminalPeriod("").isEmpty)
    }

    /// "Exactly one": a string ending in two periods keeps one. No formatter produces that, but
    /// the doc comment promises it, and a `while hasSuffix(".")` loop would break the promise on
    /// a designation that ends in an abbreviation followed by a stop.
    @Test("Only the last of two trailing periods is removed (#1392)")
    func removesOnlyOnePeriod() {
        #expect(CitationPunctuation.withoutTerminalPeriod("Paris Peace Conf..") == "Paris Peace Conf.")
    }
}

// MARK: - CitableDocumentNumberTests (#1406)

/// The one rule every export site that starts from an id now calls (#1406), branch by branch.
///
/// Every fixture is a real corpus shape: 83 `d373a`-style ids whose `@n` is the id's tail, 628
/// microfiche-supplement ids (`eta_d1`, `@n` `ETA–1`), 19 appendix ids (`appA`, `@n` `331`), 217
/// Potsdam ids whose `@n` is a bracketed description, and 313,622 `d` + integer ids whose `@n` is
/// the integer (three with a trailing space).
@Suite("Citable document number (#1406)")
struct CitableDocumentNumberTests {

    /// Potsdam's unnumbered documents carry this `@n` (`frus1945Berlinv02/d710a-1`).
    static let potsdamN = "[Unnumbered document following Document 710 (#1)]"

    @Test("A stored number is cited as printed")
    func storedNumberIsCitedAsPrinted() {
        #expect(CitableDocumentNumber.resolve(printed: "373a", documentId: "d373a") == "373a")
        #expect(CitableDocumentNumber.resolve(printed: "ETA–1", documentId: "eta_d1") == "ETA–1")
        #expect(CitableDocumentNumber.resolve(printed: "331", documentId: "appA") == "331")
        #expect(CitableDocumentNumber.resolve(printed: "12", documentId: "d12") == "12")
        // frus1917-72PubDipv07/d151 stores "151 " — the parser trims, and so does the rule.
        #expect(CitableDocumentNumber.resolve(printed: "151 ", documentId: "d151") == "151")
    }

    /// The bracketed description is not a number, and the id is NOT tried in its place — even an
    /// id that would spell one. One fixture per id shape, so neither conjunct stands in for the
    /// other.
    @Test("A bracketed @n cites no number, and never falls back to the id")
    func bracketedDescriptionCitesNoNumber() {
        #expect(CitableDocumentNumber.resolve(printed: Self.potsdamN, documentId: "d710a-1") == nil)
        #expect(CitableDocumentNumber.resolve(printed: Self.potsdamN, documentId: "d710") == nil,
                "a stored description must win over an id that happens to spell a number")
        #expect(CitableDocumentNumber.isEditorialDescription(Self.potsdamN))
        #expect(!CitableDocumentNumber.isEditorialDescription("373a"))
    }

    /// Nothing stored — the volume is not indexed here — so the id stands in where it IS the
    /// number, and nowhere else.
    @Test("With nothing stored, only an id that spells the number is used",
          arguments: [("d12", "12"), ("d0012", "12"), ("d373a", "373a"), ("d550A", "550A")])
    func unindexedIdsThatSpellANumber(_ id: String, _ expected: String) {
        #expect(CitableDocumentNumber.resolve(printed: nil, documentId: id) == expected)
        // An empty stored value counts as none.
        #expect(CitableDocumentNumber.resolve(printed: "", documentId: id) == expected)
        #expect(CitableDocumentNumber.resolve(printed: "  ", documentId: id) == expected)
    }

    @Test("With nothing stored, every other id shape is number-less",
          arguments: ["eta_d1", "d710a-1", "appA", "appendix-A", "s05sub04", "d", "dx", "d12ab"])
    func unindexedIdsThatDoNot(_ id: String) {
        #expect(CitableDocumentNumber.resolve(printed: nil, documentId: id) == nil,
                "\(id) names a record, not a printed number")
    }

    /// The Mac collection row's label — both branches.
    @Test("The row label reads \"Document N\" when there is a number, else the id")
    func rowLabel() {
        #expect(CitableDocumentNumber.rowLabel(printed: "373a", documentId: "d373a") == "Document 373a")
        #expect(CitableDocumentNumber.rowLabel(printed: "ETA–1", documentId: "eta_d1") == "Document ETA–1")
        #expect(CitableDocumentNumber.rowLabel(printed: nil, documentId: "d12") == "Document 12")
        #expect(CitableDocumentNumber.rowLabel(printed: Self.potsdamN, documentId: "d710a-1") == "d710a-1")
        #expect(CitableDocumentNumber.rowLabel(printed: nil, documentId: "eta_d1") == "eta_d1")
    }
}

// MARK: - PrintedDocumentNumberExportTests (#1406)

/// The printed number reaches every export site, through the real index (#1406).
///
/// One fixture volume, indexed once per test: `frus1865p1` (so the bundled manifest supplies real
/// volume metadata) holding `d373` (`@n` 373), `d373a` (`@n` 373a — the real `frus1865p1/d373a`),
/// an appendix-shaped `appA` (`@n` 331, as in `frus1981-88v11`), a microfiche-supplement-shaped
/// `eta_d1` (`@n` ETA–1) and a Potsdam-shaped `d710a-1` whose `@n` is the editors' bracketed
/// description. Before #1406 every site parsed the number from the id, so `d373a`, `appA` and
/// `eta_d1` were cited with NO number.
///
/// **`appA` and `eta_d1` are the fixtures that pin each SITE**, and `d373a` cannot be: with nothing
/// stored, `CitableDocumentNumber` still reads `373a` out of the id, so a site that dropped the
/// stored number would pass every `d373a` assertion. The other two numbers exist only in the index.
@Suite("Printed document numbers in exports (#1406)")
@MainActor
struct PrintedDocumentNumberExportTests {

    static let volumeId = "frus1865p1"

    /// The fixture's five documents. d373 cross-references d373a and appA (the "See also:" line);
    /// d373a and eta_d1 carry a footnote citing an unresolvable lot (a pointed-at seeding in a
    /// packet); every document has a source note (a drawn-from seeding).
    static let volumeXML = """
        <TEI xmlns:frus="http://history.state.gov/frus/ns/1.0"><text><body>
          <div type="document" xml:id="d373" n="373">
            <head>Mr. Seward to Mr. Adams<note n="1" type="source" xml:id="d373fn1">Source: Department of State, Central Files, 611.93/12–854. Secret.</note></head>
            <p>See <ref target="#d373a">the enclosure</ref> and <ref target="#appA">the appendix</ref>.</p>
          </div>
          <div type="document" xml:id="d373a" n="373a">
            <head>Mr. Seward to Mr. Adams<note n="1" type="source" xml:id="d373afn1">Source: Department of State, Central Files, 611.93/12–954. Secret.</note></head>
            <p>Body.<note n="2" xml:id="d373afn2">Not printed. (Department of State, Lot 99 D 999, CF 1)</note></p>
          </div>
          <div type="document" xml:id="appA" n="331">
            <head>Appendix A<note n="1" type="source" xml:id="appAfn1">Source: Department of State, Central Files, 611.93/12–1254. Secret.</note></head>
            <p>Body.</p>
          </div>
          <div type="document" xml:id="eta_d1" n="ETA–1">
            <head>Telegram<note n="1" type="source" xml:id="eta_d1fn1">Source: Department of State, Central Files, 611.93/12–1154. Secret.</note></head>
            <p>Body.<note n="2" xml:id="eta_d1fn2">Not printed. (Department of State, Lot 99 D 998, CF 2)</note></p>
          </div>
          <div type="document" xml:id="d710a-1" n="[Unnumbered document following Document 710 (#1)]">
            <head>Joint Chiefs of Staff Minutes<note n="1" type="source" xml:id="d710a-1fn1">Source: Department of State, Central Files, 611.93/12–1054. Secret.</note></head>
            <p>Body.</p>
          </div>
        </body></text></TEI>
        """

    /// The fixture's manifest entry.
    static func manifestEntry() throws -> VolumeManifestEntry {
        try #require(ManifestStore().bundledEntries.first { $0.volumeId == volumeId },
                     "the bundled manifest must carry \(volumeId)")
    }

    /// Indexes the fixture into a fresh database under `dir`.
    static func indexedPipeline(in dir: URL) async throws -> (IndexingPipeline, URL) {
        let volumes = dir.appendingPathComponent("volumes", isDirectory: true)
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        try Data(volumeXML.utf8).write(to: volumes.appendingPathComponent("\(volumeId).xml"))
        let dbURL = dir.appendingPathComponent("test.sqlite")
        let pipeline = try IndexingPipeline(fts5Store: try FTS5Store(databaseURL: dbURL),
                                            databaseURL: dbURL, volumesDirectory: volumes,
                                            concurrencyLimit: 1)
        try await pipeline.indexVolume(volumeId)
        return (pipeline, dbURL)
    }

    /// A fresh temp directory, removed by the caller's `defer`.
    static func tempDir() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("printed-number-\(UUID().uuidString)", isDirectory: true)
    }

    /// The citation's tail after the publication parenthetical — what #1406 is about.
    static let publication = "(Washington, D.C.: Government Printing Office, 1866)"

    @Test("The batched read returns what the index stores, across a chunk boundary")
    func batchedReadReturnsStoredNumbers() async throws {
        let dir = Self.tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let (pipeline, _) = try await Self.indexedPipeline(in: dir)
        // d373 in the first 500-key statement, the other four in the second; 600 absent keys.
        var keys: [(volumeId: String, documentId: String)] = [(Self.volumeId, "d373")]
        keys += (0..<600).map { (volumeId: Self.volumeId, documentId: "absent\($0)") }
        keys += ["d373a", "appA", "eta_d1", "d710a-1"].map { (volumeId: Self.volumeId, documentId: $0) }
        let numbers = try await pipeline.documentNumbersByKey(keys)
        #expect(numbers == [
            "frus1865p1/d373": "373",
            "frus1865p1/d373a": "373a",
            "frus1865p1/appA": "331",
            "frus1865p1/eta_d1": "ETA–1",
            "frus1865p1/d710a-1": CitableDocumentNumberTests.potsdamN,
        ], "got \(numbers)")
        #expect(try await pipeline.documentNumbersByKey([]).isEmpty)
    }

    /// The trip packet: both channels — the drawn-from seeding and the pointed-at seeding — cite
    /// the printed number.
    @Test("A trip packet cites the printed number in both channels, and the Potsdam document with none")
    func tripPacketCitesThePrintedNumber() async throws {
        let dir = Self.tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let (pipeline, _) = try await Self.indexedPipeline(in: dir)
        let dataSource = TripPacketDataSource(pipeline: pipeline,
                                              manifestMap: [Self.volumeId: try Self.manifestEntry()])
        let model = await TripPacketBuilder.build(
            documents: ["d373", "d373a", "eta_d1", "d710a-1"].map { (Self.volumeId, $0) },
            researchQuestion: nil, dataSource: dataSource)

        let drawn = model.targets.flatMap(\.drawnFrom)
        let pointed = model.targets.flatMap(\.pointedAt)
        try #require(drawn.count == 4, "four drawn-from seedings, got \(drawn.count)")
        func drawnCitation(_ id: String) throws -> String {
            try #require(drawn.first { $0.documentId == id }, "no drawn-from seeding for \(id)").citation
        }
        func pointedCitation(_ id: String) throws -> String {
            try #require(pointed.first { $0.documentId == id },
                         "\(id)'s footnote must seed the pointed-at channel").citation
        }
        let plain = try drawnCitation("d373")
        let lettered = try drawnCitation("d373a")
        let supplement = try drawnCitation("eta_d1")
        let unnumbered = try drawnCitation("d710a-1")
        let letteredFootnote = try pointedCitation("d373a")
        let supplementFootnote = try pointedCitation("eta_d1")
        #expect(plain.hasSuffix("\(Self.publication), Document 373."), "drawn-from: \(plain)")
        #expect(lettered.hasSuffix("\(Self.publication), Document 373a."), "drawn-from: \(lettered)")
        #expect(supplement.hasSuffix("\(Self.publication), Document ETA–1."), "drawn-from: \(supplement)")
        #expect(unnumbered.hasSuffix("\(Self.publication)."), """
            A document the volume prints without a number is cited without one, never as \
            "Document [Unnumbered …]": \(unnumbered)
            """)
        #expect(letteredFootnote.hasSuffix("\(Self.publication), Document 373a."),
                "pointed-at: \(letteredFootnote)")
        #expect(supplementFootnote.hasSuffix("\(Self.publication), Document ETA–1."),
                "pointed-at: \(supplementFootnote)")
    }

    /// The collection export: the document heading, the excerpt's source line, the "See also:"
    /// line and the bibliography block — four sites, one resolve.
    @Test("A collection export cites the printed number at every site that names a document")
    func collectionExportCitesThePrintedNumber() async throws {
        let dir = Self.tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let (pipeline, dbURL) = try await Self.indexedPipeline(in: dir)
        let appState = AppState()
        appState.indexingPipeline = pipeline
        appState.crossReferenceStore = try CrossReferenceStore(databaseURL: dbURL)

        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        let coll = Collection(name: "Numbers")
        context.insert(coll)
        func entry(_ documentId: String, _ order: Int) -> CollectionEntry {
            let entry = CollectionEntry(collectionId: coll.id, documentId: documentId,
                                        volumeId: Self.volumeId, sortOrder: order)
            entry.collection = coll
            context.insert(entry)
            return entry
        }
        let plain = entry("d373", 0)
        plain.includeRelatedDocuments = true
        let lettered = entry("d373a", 1)
        let appendix = entry("appA", 2)
        let unnumbered = entry("d710a-1", 3)
        // eta_d1 is quoted but is NOT a document entry, so no other read reaches its number: the
        // excerpt's source line gets it only if the batch reads the excerpts' documents too.
        let excerpts = ["d373a", "eta_d1"].enumerated().map { offset, id in
            let excerpt = entry(id, 4 + offset)
            excerpt.entryKind = .excerpt
            excerpt.text = "A quoted passage."
            return excerpt
        }
        let bibliography = CollectionEntry(collectionId: coll.id, documentId: "", volumeId: "",
                                           sortOrder: 6)
        bibliography.entryKind = .generated
        bibliography.generatedBlockType = CollectionGeneratedBlockType.bibliography.rawValue
        bibliography.collection = coll
        context.insert(bibliography)
        try context.save()

        let resolver = CollectionContentResolver(appState: appState, modelContext: context)
        let items = try await resolver.resolve(
            collection: coll,
            entries: [plain, lettered, appendix, unnumbered] + excerpts + [bibliography],
            allNotes: [], purpose: .preview)

        // The document headings.
        let docs = items.documents
        try #require(docs.map(\.documentId) == ["d373", "d373a", "appA", "d710a-1"],
                     "four document items in order, got \(docs.map(\.documentId))")
        #expect(docs[0].citation.hasSuffix("\(Self.publication), Document 373."), "\(docs[0].citation)")
        #expect(docs[1].citation.hasSuffix("\(Self.publication), Document 373a."), "\(docs[1].citation)")
        #expect(docs[2].citation.hasSuffix("\(Self.publication), Document 331."), "\(docs[2].citation)")
        #expect(docs[3].citation.hasSuffix("\(Self.publication)."),
                "the Potsdam shape stays number-less: \(docs[3].citation)")

        // The "See also:" line — d373 cross-references two members.
        let seeAlso = docs[0].relatedDocumentCitations
        try #require(seeAlso.count == 2, "d373's See also: line cites its two members: \(seeAlso)")
        #expect(seeAlso.contains { $0.hasSuffix("\(Self.publication), Document 373a.") }, "\(seeAlso)")
        #expect(seeAlso.contains { $0.hasSuffix("\(Self.publication), Document 331.") }, "\(seeAlso)")

        // The excerpts' source lines.
        let quoted = items.compactMap { item -> CollectionExportExcerpt? in
            if case .excerpt(let payload) = item { return payload }
            return nil
        }
        try #require(quoted.map(\.documentId) == ["d373a", "eta_d1"])
        #expect(quoted[0].citation.hasSuffix("\(Self.publication), Document 373a."), "\(quoted[0].citation)")
        #expect(quoted[1].citation.hasSuffix("\(Self.publication), Document ETA–1."), "\(quoted[1].citation)")

        // The bibliography block, in series order: 331 < 373 < 373a, number-less last.
        let blocks = items.compactMap { item -> CollectionGeneratedBlock? in
            if case .generated(let block) = item { return block }
            return nil
        }
        try #require(blocks.count == 1)
        let rows = blocks[0].rows.map(\.text)
        try #require(rows.count == 4, "one bibliography row per member, got \(rows)")
        #expect(rows[0].hasSuffix("Document 331."), "series order: \(rows)")
        #expect(rows[1].hasSuffix("Document 373."), "series order: \(rows)")
        #expect(rows[2].hasSuffix("Document 373a."), "373a sorts after 373: \(rows)")
        #expect(rows[3].hasSuffix("\(Self.publication)."), "number-less last: \(rows)")
    }

    /// The inspector's placeholder citation — the indexed path and the no-index fallback.
    @Test("The inspector's export citation names the printed number, with or without an index")
    func inspectorCitation() async throws {
        let dir = Self.tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let (pipeline, _) = try await Self.indexedPipeline(in: dir)
        let entry = try Self.manifestEntry()
        func citation(_ id: String, _ pipeline: IndexingPipeline?) async -> String {
            await CollectionEntryInspector.exportCitation(
                documentId: id, volumeId: Self.volumeId, manifestEntry: entry, pipeline: pipeline)
        }

        let indexed = await citation("eta_d1", pipeline)
        #expect(indexed.hasSuffix("\(Self.publication), Document ETA–1."), "\(indexed)")
        let lettered = await citation("d373a", pipeline)
        #expect(lettered.hasSuffix("\(Self.publication), Document 373a."), "\(lettered)")
        let potsdam = await citation("d710a-1", pipeline)
        #expect(potsdam.hasSuffix("\(Self.publication)."), "\(potsdam)")
        // No index: the id stands in where it spells the number, and nowhere else.
        let unindexed = await citation("d373a", nil)
        #expect(unindexed.hasSuffix("\(Self.publication), Document 373a."), "\(unindexed)")
        let supplement = await citation("eta_d1", nil)
        #expect(supplement.hasSuffix("\(Self.publication)."), "\(supplement)")
    }

    /// The macOS manager's row numbers come from this load; the label itself is
    /// `CitableDocumentNumber.rowLabel`, tested above. (The row is macOS-only, so no iOS test can
    /// draw it; the macOS build compiles the wiring.)
    @Test("The collection manager's number load reads the index, and is empty without one")
    func managerNumberLoad() async throws {
        let dir = Self.tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let (pipeline, _) = try await Self.indexedPipeline(in: dir)
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        let coll = Collection(name: "Rows")
        context.insert(coll)
        let heading = CollectionEntry(collectionId: coll.id, documentId: "", volumeId: "", sortOrder: 0)
        heading.entryKind = .heading
        let entries = [heading] + ["d373a", "eta_d1", "d710a-1"].enumerated().map {
            CollectionEntry(collectionId: coll.id, documentId: $0.element,
                            volumeId: Self.volumeId, sortOrder: $0.offset + 1)
        }
        for entry in entries { context.insert(entry) }

        let appState = AppState()
        #expect(await CollectionEntryData.documentNumbers(for: entries, appState: appState).isEmpty,
                "no index, no numbers — the rows fall back to what the id spells")
        appState.indexingPipeline = pipeline
        let numbers = await CollectionEntryData.documentNumbers(for: entries, appState: appState)
        #expect(numbers == ["frus1865p1/d373a": "373a",
                            "frus1865p1/eta_d1": "ETA–1",
                            "frus1865p1/d710a-1": CitableDocumentNumberTests.potsdamN],
                "got \(numbers)")
        #expect(CitableDocumentNumber.rowLabel(printed: numbers["frus1865p1/eta_d1"],
                                               documentId: "eta_d1") == "Document ETA–1")
    }
}

// MARK: - GeneratedBlockNumberTests (#1406)

/// A block conformer whose citation SHOWS the printed number it was handed, so each block is seen
/// to read the numbers it fetched — the hermetic sibling of `CollectionTests`'s fixture, which
/// holds only unindexed documents.
@MainActor
private struct NumberedBlockSource: CollectionGeneratedBlockDataSource {
    /// The printed numbers the index "stores", keyed `volumeId/documentId`.
    var numbers: [String: String]
    /// `document_sources` rows.
    var sources: [CollectionGeneratedBlocks.SourceRecord] = []
    /// Rollup mentions.
    var mentions: [CollectionGeneratedBlocks.PersonMention] = []
    /// User tags.
    var tags: [CollectionGeneratedBlocks.TagRecord] = []

    func citation(volumeId: String, documentId: String, printedNumber: String?) -> String {
        "\(volumeId)/\(documentId) n=\(printedNumber ?? "nil")"
    }
    func documentNumbers(for documents: [(volumeId: String, documentId: String)])
        async -> [String: String] {
        let keys = Set(documents.map { "\($0.volumeId)/\($0.documentId)" })
        return numbers.filter { keys.contains($0.key) }
    }
    func dateMetadata(for documents: [(volumeId: String, documentId: String)])
        async -> [String: DocumentDateMetadata] { [:] }
    func documentSources(for documents: [(volumeId: String, documentId: String)])
        async -> [CollectionGeneratedBlocks.SourceRecord] { sources }
    func archivalResolution(recordGroup: String?, lotFile: String?)
        -> CollectionGeneratedBlocks.ArchivalLink? { nil }
    func personMentions(for documents: [(volumeId: String, documentId: String)])
        async -> [CollectionGeneratedBlocks.PersonMention] { mentions }
    func tagRecords() async -> [CollectionGeneratedBlocks.TagRecord] { tags }
}

/// Every generated block names a document by its printed number (#1406).
@Suite("Generated blocks read printed numbers (#1406)")
@MainActor
struct GeneratedBlockNumberTests {

    static let volume = "v"
    /// `eta_d1`'s number exists only here, so it is the fixture that shows a block READ the
    /// stored number (a block that dropped it would still read `373a` out of `d373a`).
    static let numbers = [
        "v/d373": "373", "v/d373a": "373a", "v/d374": "374", "v/eta_d1": "ETA–1",
        "v/d710a-1": CitableDocumentNumberTests.potsdamN,
    ]
    static func docs(_ ids: [String]) -> [(volumeId: String, documentId: String)] {
        ids.map { (volumeId: volume, documentId: $0) }
    }

    @Test("The bibliography sorts 373 < 373a < 374 < ETA–1, number-less last, and hands each citation its number")
    func bibliographyOrderAndNumbers() async {
        let block = await CollectionGeneratedBlocks.resolve(
            type: .bibliography, documents: Self.docs(["d374", "d710a-1", "eta_d1", "d373a", "d373"]),
            dataSource: NumberedBlockSource(numbers: Self.numbers))
        #expect(block.rows.map(\.text) == [
            "v/d373 n=373", "v/d373a n=373a", "v/d374 n=374", "v/eta_d1 n=ETA–1",
            "v/d710a-1 n=\(CitableDocumentNumberTests.potsdamN)",
        ])
    }

    /// Two documents printing the same number sort by id — the tie-break the comparison needs to
    /// be a strict order (no two ids in one shipped volume share an `@n`, so this is a guard).
    @Test("Two documents printing one number sort by id")
    func equalNumbersSortById() async {
        let block = await CollectionGeneratedBlocks.resolve(
            type: .bibliography, documents: Self.docs(["d331", "appA"]),
            dataSource: NumberedBlockSource(numbers: ["v/d331": "331", "v/appA": "331"]))
        #expect(block.rows.map(\.text) == ["v/appA n=331", "v/d331 n=331"])
    }

    @Test("The chronology's undated rows hand each citation its number")
    func chronologyCitations() async {
        let block = await CollectionGeneratedBlocks.resolve(
            type: .chronology, documents: Self.docs(["d373a"]),
            dataSource: NumberedBlockSource(numbers: Self.numbers))
        #expect(block.rows.map(\.text).contains("v/d373a n=373a"), "\(block.rows.map(\.text))")
    }

    @Test("Sources, persons and thematic rows name the printed number; a number-less document keeps its id")
    func referenceTokens() async {
        let record = { (id: String) in
            CollectionGeneratedBlocks.SourceRecord(
                volumeId: Self.volume, documentId: id, repository: nil, recordGroup: "59",
                lotFile: "63 D 351", seriesName: nil, rawText: "Lot 63 D 351",
                citationEra: "lot_file")
        }
        let source = NumberedBlockSource(
            numbers: Self.numbers,
            sources: [record("d373a"), record("eta_d1"), record("d710a-1")],
            mentions: ["d373", "d373a", "eta_d1"].map {
                .init(identityKey: "r1", name: "Seward", description: nil, role: nil,
                      volumeId: Self.volume, documentId: $0)
            },
            tags: [.init(name: "Slave trade", documents: Self.docs(["d373a", "eta_d1"]))])

        let sources = await CollectionGeneratedBlocks.resolve(
            type: .archivalSources, documents: Self.docs(["d373a", "eta_d1", "d710a-1"]),
            dataSource: source)
        #expect(sources.rows.map(\.text).contains("Document 373a"), "\(sources.rows.map(\.text))")
        #expect(sources.rows.map(\.text).contains("Document ETA–1"), "\(sources.rows.map(\.text))")
        #expect(sources.rows.map(\.text).contains("Document d710a-1"), """
            a document the volume prints without a number keeps its id in a token, as before: \
            \(sources.rows.map(\.text))
            """)

        let persons = await CollectionGeneratedBlocks.resolve(
            type: .personsIndex, documents: Self.docs(["d373", "d373a", "eta_d1"]), dataSource: source)
        #expect(persons.rows.first?.secondaryText == "Documents 373, 373a, ETA–1",
                "\(String(describing: persons.rows.first?.secondaryText))")

        let thematic = await CollectionGeneratedBlocks.resolve(
            type: .thematicIndex, documents: Self.docs(["d373a", "eta_d1"]), dataSource: source)
        #expect(thematic.rows.map(\.text) == ["Slave trade", "Document 373a", "Document ETA–1"],
                "\(thematic.rows.map(\.text))")
    }
}
