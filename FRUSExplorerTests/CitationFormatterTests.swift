// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
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
