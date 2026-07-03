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

// MARK: - SourceExplorerTests

struct SourceExplorerTests {

    private let parser = SourceNoteParser()

    // MARK: - ParserTest

    @Test("ParserTest: each provenance type is correctly identified from representative source notes")
    func parserRecognizesAllProvenanceTypes() {
        // CFPF — Central Foreign Policy File with reel identifier
        let cfpfNarrative = "Source: Department of State, Central Foreign Policy File, Electronic Telegrams, D891080-0768. Secret; Exdis. Sent Immediate."
        if case .cfpfFile(_) = parser.parse(cfpfNarrative) {
            // pass — correctly classified as CFPF
        } else {
            Issue.record("Expected .cfpfFile for CFPF narrative, got \(parser.parse(cfpfNarrative))")
        }

        // Era 4 — State Dept. central files (non-CFPF full narrative)
        let centralNarrative = "Source: Department of State, Central Files 1967-69, POL 7 VIET S. Confidential."
        if case .centralFiles(let rg, _) = parser.parse(centralNarrative) {
            #expect(rg == "RG-59")
        } else {
            Issue.record("Expected .centralFiles for central files narrative, got \(parser.parse(centralNarrative))")
        }

        // Era 3b — lot file (inline)
        let lotFileInline = "SPA Files: Lot 61-D 146, Box 4581"
        if case .lotFile(_, let lot, _) = parser.parse(lotFileInline) {
            #expect(lot.contains("61-D 146"))
        } else {
            Issue.record("Expected .lotFile for inline lot file, got \(parser.parse(lotFileInline))")
        }

        // Era 4 — presidential library
        let libraryNarrative = "Source: Kennedy Library, National Security Files, Vietnam Country Series, CIA Cables. Confidential."
        if case .presidentialLibrary(let library, _, _) = parser.parse(libraryNarrative) {
            #expect(library.contains("Kennedy"))
        } else {
            Issue.record("Expected .presidentialLibrary, got \(parser.parse(libraryNarrative))")
        }

        // Previously published
        let published = "Source: Foreign Relations of the United States, 1952-1954, vol. XIV, p. 823."
        if case .previouslyPublished(_) = parser.parse(published) {
            // pass
        } else {
            Issue.record("Expected .previouslyPublished, got \(parser.parse(published))")
        }

        // Unrecognized
        let unknown = "Obtained from private collection."
        if case .unrecognized(_) = parser.parse(unknown) {
            // pass
        } else {
            Issue.record("Expected .unrecognized, got \(parser.parse(unknown))")
        }
    }

    // MARK: - MultiEraTest

    @Test("MultiEraTest: parser handles source notes from different historical eras without error")
    func multiEraParserHandlesAllFormats() {
        let fixtures: [(note: String, era: String)] = [
            // Era 2 — bare file number (1906–1910)
            ("File No. 17529.", "Era 2"),
            // Era 3a — decimal file (1910–1963)
            ("862S.01/10-1646", "Era 3a"),
            // Era 3b — lot file inline (1910–1963)
            ("EUR Files: Lot 61-D 48, Box 12", "Era 3b"),
            // Era 3c / Era 4 — full narrative
            ("Source: Department of State, Central Files. Secret; Priority.", "Era 3c/4 central"),
            ("Source: National Archives, Record Group 59, Central Foreign Policy File, 1964-66, POL 7 USSR. Confidential.", "Era 4 RG-59"),
            ("Source: Johnson Library, National Security Files, Memos to the President—Walt Rostow. Top Secret.", "Era 4 library"),
            ("Source: Department of State, EUR/SOV Files: Lot 70 D 417. Confidential.", "Era 4 lot"),
        ]

        for (note, era) in fixtures {
            let result = parser.parse(note)
            // Simply verify no crash and result is a valid case
            switch result {
            case .centralFiles, .lotFile, .presidentialLibrary, .foreignGovernmentArchive,
                    .previouslyPublished, .unrecognized, .naraCollection, .ciaCollection,
                    .cfpfFile, .namedFileSeries:
                break // any structured result is acceptable
            }
            _ = era // suppress unused warning
        }
    }

    // MARK: - NoMatchTest

    @Test("NoMatchTest: unrecognizable source note returns .unrecognized gracefully")
    func noMatchReturnsUnrecognized() {
        let bizarre = "Provenance unknown. Document acquired through informal channels circa 1970."
        let result = parser.parse(bizarre)

        guard case .unrecognized(let rawText) = result else {
            Issue.record("Expected .unrecognized for bizarre note, got \(result)")
            return
        }
        #expect(rawText.contains("Provenance unknown"))
    }

    @Test("NoMatchTest: empty string returns .unrecognized without crashing")
    func emptyStringReturnsUnrecognized() {
        let result = parser.parse("")
        if case .unrecognized(_) = result {
            // pass
        } else {
            Issue.record("Expected .unrecognized for empty string, got \(result)")
        }
    }

    // MARK: - APIKeyAbsenceTest

    @Test("APIKeyAbsenceTest: NARACatalogClient.hasAPIKey() returns false when no key stored")
    func apiKeyAbsenceReturnsFalse() async {
        // Use a fresh KeychainStore with nil access group (test partition)
        let store = KeychainStore(service: "test.nara-key-absence.\(UUID().uuidString)",
                                   accessGroup: nil)
        let client = NARACatalogClient(keychainStore: store)
        let hasKey = await client.hasAPIKey()
        #expect(hasKey == false)
    }

    @Test("APIKeyAbsenceTest: resolveLotFile throws .missingAPIKey when no key is stored")
    func lotFileThrowsMissingKeyWhenNoKey() async throws {
        let store = KeychainStore(service: "test.nara-missing-key.\(UUID().uuidString)",
                                   accessGroup: nil)
        let client = NARACatalogClient(keychainStore: store)
        do {
            _ = try await client.resolveLotFile(lotNumber: "61-D 146")
            Issue.record("Expected NARACatalogError.missingAPIKey to be thrown")
        } catch NARACatalogError.missingAPIKey {
            // Expected — pass
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    // MARK: - CentralFilesURLTest

    @Test("CentralFilesURLTest: resolveRG59CentralFiles returns URL containing the file identifier")
    func centralFilesURLContainsIdentifier() async {
        let client = NARACatalogClient()
        let identifier = "862S.01/10-1646"
        let url = await client.resolveRG59CentralFiles(fileIdentifier: identifier)

        let urlString = url.absoluteString
        #expect(urlString.contains("catalog.archives.gov"))
        // URL-encoded form of the identifier should appear
        let encoded = identifier.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        ) ?? identifier
        #expect(urlString.contains("862S") || urlString.contains(encoded))
    }

    @Test("CentralFilesURLTest: resolveRG59CentralFiles includes RG-59 parent description filter")
    func centralFilesURLIncludesRG59Filter() async {
        let client = NARACatalogClient()
        let url = await client.resolveRG59CentralFiles(fileIdentifier: "711.94/3-251")
        #expect(url.absoluteString.contains("parentDescriptionNaId"))
    }

    // MARK: - LotNumberNormalisationTest

    @Test("LotNorm: compact 63D135 produces three variants including spaced form")
    func compactLotNumberProducesVariants() {
        let variants = NARACatalogClient.lotNumberVariants(from: "63D135")
        #expect(variants.count == 3)
        #expect(variants[0] == "63D135")     // compact
        #expect(variants[1] == "63 D 135")   // spaced
        #expect(variants[2] == "63 D135")    // mixed
    }

    @Test("LotNorm: 'Lot 72D316' strips prefix and produces correct variants")
    func lotPrefixStripped() {
        let variants = NARACatalogClient.lotNumberVariants(from: "Lot 72D316")
        #expect(variants.contains("72D316"))
        #expect(variants.contains("72 D 316"))
    }

    @Test("LotNorm: spaced input 63 D 135 normalises to compact form first")
    func spacedLotNumberNormalisesToCompact() {
        let variants = NARACatalogClient.lotNumberVariants(from: "63 D 135")
        #expect(variants[0] == "63D135")
    }

    @Test("LotNorm: dashed input 63-D-135 normalises to compact form first")
    func dashedLotNumberNormalisesToCompact() {
        let variants = NARACatalogClient.lotNumberVariants(from: "63-D-135")
        #expect(variants[0] == "63D135")
    }

    @Test("LotNorm: 3-digit prefix 123D4567 preserved in all variants")
    func threeDigitPrefixPreserved() {
        let variants = NARACatalogClient.lotNumberVariants(from: "123D4567")
        #expect(variants[0] == "123D4567")
        #expect(variants[1] == "123 D 4567")
    }

    // MARK: - CFPFTest

    @Test("CFPF: 'Central Foreign Policy File' narrative parses as .cfpfFile")
    func cfpfNarrativeParsesCFPF() {
        let note = "Source: National Archives, RG 59, Central Foreign Policy File, P840114–1808. Secret."
        let result = parser.parse(note)
        guard case .cfpfFile(let fid) = result else {
            Issue.record("Expected .cfpfFile, got \(result)")
            return
        }
        #expect(fid == "P840114–1808")
    }

    @Test("CFPF: D-Reel identifier parses as .cfpfFile")
    func cfpfDReelParsesCFPF() {
        let note = "Source: National Archives, RG 59, Central Foreign Policy File, D740218–0840. Confidential."
        guard case .cfpfFile(let fid) = parser.parse(note) else {
            Issue.record("Expected .cfpfFile for D-Reel note")
            return
        }
        #expect(fid == "D740218–0840")
    }

    @Test("CFPF: AAD Electronic Telegrams reference parses as .cfpfFile")
    func aadTelegramParsesCFPF() {
        let note = "Part of the on-line Access to Archival Databases: Electronic Telegrams, P-Reel I."
        guard case .cfpfFile(_) = parser.parse(note) else {
            Issue.record("Expected .cfpfFile for AAD telegram note, got \(parser.parse(note))")
            return
        }
    }

    @Test("CFPF: 'Central Foreign Policy Files' (plural) also parses as .cfpfFile")
    func cfpfPluralParsesCFPF() {
        let note = "Source: National Archives, RG 59, Central Foreign Policy Files. Secret; Exdis."
        guard case .cfpfFile(_) = parser.parse(note) else {
            Issue.record("Expected .cfpfFile for CFPF plural note, got \(parser.parse(note))")
            return
        }
    }

    // MARK: - LotFileDesignatorTest

    @Test("LotFile: F-designator lot file returns RG-84")
    func fDesignatorLotFileIsRG84() {
        let note = "Cairo Legation Files: Lot 52F34"
        guard case .lotFile(let rg, let lot, _) = parser.parse(note) else {
            Issue.record("Expected .lotFile for F-designator note, got \(parser.parse(note))")
            return
        }
        #expect(rg == "RG-84")
        #expect(lot.contains("52F34") || lot.contains("52 F 34"))
    }

    @Test("LotFile: F-designator with spaces returns RG-84")
    func fDesignatorWithSpacesIsRG84() {
        let note = "Moscow Embassy Files: Lot 53 F 11"
        guard case .lotFile(let rg, _, _) = parser.parse(note) else {
            Issue.record("Expected .lotFile, got \(parser.parse(note))")
            return
        }
        #expect(rg == "RG-84")
    }

    @Test("LotFile: D-designator lot file returns RG-59")
    func dDesignatorLotFileIsRG59() {
        let note = "SPA Files: Lot 63D135, Box 12"
        guard case .lotFile(let rg, _, _) = parser.parse(note) else {
            Issue.record("Expected .lotFile for D-designator note, got \(parser.parse(note))")
            return
        }
        #expect(rg == "RG-59")
    }

    // MARK: - DecimalFilePeriodTest

    @Test("DecimalPeriod: pre-1906 year routes to 1789-1906 NARA page")
    func pre1906RoutesTo1789Period() async {
        let client = NARACatalogClient()
        let url = client.decimalFilePeriodURL(year: 1898)
        #expect(url.absoluteString.contains("1789-1906"))
        let label = client.decimalFilePeriodLabel(year: 1898)
        #expect(label == "1789–1906")
    }

    @Test("DecimalPeriod: year 1908 routes to 1906-1910 NARA page")
    func year1908RoutesTo1906Period() async {
        let client = NARACatalogClient()
        let url = client.decimalFilePeriodURL(year: 1908)
        #expect(url.absoluteString.contains("1906-1910"))
        let label = client.decimalFilePeriodLabel(year: 1908)
        #expect(label == "1906–1910")
    }

    @Test("DecimalPeriod: year 1965 routes to 1963-1973 NARA page")
    func year1965RoutesTo1963Period() async {
        let client = NARACatalogClient()
        let url = client.decimalFilePeriodURL(year: 1965)
        #expect(url.absoluteString.contains("1963-1973"))
        let label = client.decimalFilePeriodLabel(year: 1965)
        #expect(label == "1963–1973")
    }

    @Test("DecimalPeriod: filing manual for 1947 returns 1910-49 PDF")
    func filingManual1947Returns191049PDF() async {
        let client = NARACatalogClient()
        let url = client.filingManualURL(year: 1947)
        #expect(url != nil)
        #expect(url!.absoluteString.contains("manual-1910-49.pdf"))
    }

    @Test("DecimalPeriod: filing manual for 1963 returns 1963 classification handbook")
    func filingManual1963Returns1963Handbook() async {
        let client = NARACatalogClient()
        let url = client.filingManualURL(year: 1963)
        #expect(url != nil)
        #expect(url!.absoluteString.contains("1963.pdf"))
    }

    @Test("DecimalPeriod: filing manual for 1970 returns 1965-1973 handbook")
    func filingManual1970Returns19651973Handbook() async {
        let client = NARACatalogClient()
        let url = client.filingManualURL(year: 1970)
        #expect(url != nil)
        #expect(url!.absoluteString.contains("1965-1973.pdf"))
    }

    @Test("DecimalPeriod: filing manual for 1800 returns nil")
    func filingManual1800ReturnsNil() async {
        let client = NARACatalogClient()
        let url = client.filingManualURL(year: 1800)
        #expect(url == nil)
    }

    @Test("DecimalPeriod: CFPF FAQ and AAD URLs are archives.gov and aad.archives.gov")
    func cfpfURLsAreCorrect() async {
        let client = NARACatalogClient()
        #expect(client.cfpfFAQURL.absoluteString.contains("archives.gov"))
        #expect(client.cfpfFAQURL.absoluteString.contains("cfpf-faqs.pdf"))
        #expect(client.cfpfAADURL.absoluteString.contains("aad.archives.gov"))
    }

    // NARA removed the seven decimal-file sub-period pages (HTTP 404, verified
    // 2026-06-04) and consolidated them onto the 1910-1963 parent page — see
    // `decimalFilePeriodURL`. Every decimal-era year must therefore route to the
    // parent page, never to a sub-period path, while the human-readable *label*
    // stays period-specific.

    @Test("DecimalPeriod: year 1946 routes to the consolidated 1910-1963 page with a 1945–1949 label")
    func year1946RoutesToCorrectPeriod() async {
        let client = NARACatalogClient()
        let url = client.decimalFilePeriodURL(year: 1946)
        #expect(url.absoluteString.hasSuffix("rg-59-central-files/1910-1963"),
                "decimal-era years must use the consolidated parent page (sub-period pages 404)")
        let label = client.decimalFilePeriodLabel(year: 1946)
        #expect(label == "1945–1949")
    }

    @Test("DecimalPeriod: year 1912 routes to the consolidated 1910-1963 page with a 1910–1929 label")
    func year1912RoutesToCorrectPeriod() async {
        let client = NARACatalogClient()
        let url = client.decimalFilePeriodURL(year: 1912)
        #expect(url.absoluteString.hasSuffix("rg-59-central-files/1910-1963"))
        #expect(client.decimalFilePeriodLabel(year: 1912) == "1910–1929")
    }

    @Test("DecimalPeriod: year 1961 routes to the consolidated 1910-1963 page with a 1960–January 1963 label")
    func year1961RoutesToCorrectPeriod() async {
        let client = NARACatalogClient()
        let url = client.decimalFilePeriodURL(year: 1961)
        #expect(url.absoluteString.hasSuffix("rg-59-central-files/1910-1963"))
        #expect(client.decimalFilePeriodLabel(year: 1961) == "1960–January 1963")
    }

    @Test("DecimalPeriod: all 7 periods return archives.gov URLs")
    func allPeriodsReturnArchivesGovURLs() async {
        let client = NARACatalogClient()
        for year in [1915, 1935, 1942, 1947, 1952, 1957, 1961] {
            let url = client.decimalFilePeriodURL(year: year)
            #expect(url.absoluteString.contains("archives.gov"))
        }
    }

    // MARK: - LibraryFallbackTest

    @Test("LibraryFallback: Kennedy Library routes to jfklibrary.org")
    func kennedyFallbackURL() async {
        let client = NARACatalogClient()
        let url = client.libraryFallbackURL(libraryName: "Kennedy Library")
        #expect(url.absoluteString.contains("jfklibrary.org"))
    }

    @Test("LibraryFallback: Nixon Materials routes to nixonlibrary.gov")
    func nixonFallbackURL() async {
        let client = NARACatalogClient()
        let url = client.libraryFallbackURL(libraryName: "Nixon Presidential Materials")
        #expect(url.absoluteString.contains("nixonlibrary.gov"))
    }

    @Test("LibraryFallback: unknown library routes to archives.gov/presidential-libraries")
    func unknownLibraryDefaultURL() async {
        let client = NARACatalogClient()
        let url = client.libraryFallbackURL(libraryName: "Unknown Institute")
        #expect(url.absoluteString.contains("archives.gov/presidential-libraries"))
    }

    // MARK: - CIAResearchURLTest

    @Test("CIA: job number pre-populated in CREST search URL")
    func ciaJobNumberInURL() async {
        let client = NARACatalogClient()
        let url = client.ciaResearchURL(jobNumber: "80B01285A")
        #expect(url.absoluteString.contains("cia.gov/readingroom"))
        #expect(url.absoluteString.contains("80B01285A"))
    }

    @Test("CIA: nil job number returns general reading room URL")
    func ciaNoJobReturnsReadingRoom() async {
        let client = NARACatalogClient()
        let url = client.ciaResearchURL(jobNumber: nil)
        #expect(url.absoluteString == "https://www.cia.gov/readingroom/")
    }
}

// MARK: - SourceNoteExtractionTests

/// Tests for `extractSourceNote(from:)` covering all three placement patterns found
/// in actual FRUS TEI XML across different eras of the series.
struct SourceNoteExtractionTests {

    // MARK: - Standard placement

    @Test("Standard: <note type='source'> as direct child of document div")
    func standardDocumentLevelSourceNote() {
        // Most common pattern: <note type="source" n="1"> is a top-level sibling of
        // <head>, <dateline>, and <p> inside <div type="document">.
        let nodes: [FRUSASTNode] = [
            .head(children: [.text("1. Memorandum From the Secretary of State to the President")]),
            .dateline(children: [.text("Washington, January 20, 1969.")]),
            .paragraph(children: [.text("Body text.")]),
            .footnote(id: "d1fn1", type: .source, printedNumber: "1",
                      children: [.text("Source: National Archives, RG 59, Central Foreign Policy File, D890001-0001.")])
        ]
        let result = extractSourceNote(from: nodes)
        #expect(result == "Source: National Archives, RG 59, Central Foreign Policy File, D890001-0001.")
    }

    @Test("Standard: returns nil when no source note is present")
    func noSourceNoteReturnsNil() {
        let nodes: [FRUSASTNode] = [
            .head(children: [.text("Editorial Note")]),
            .paragraph(children: [.text("This is an editorial note with no source footnote.")])
        ]
        #expect(extractSourceNote(from: nodes) == nil)
    }

    @Test("Standard: ignores numbered footnotes that are not type=source")
    func regularFootnoteNotExtracted() {
        let nodes: [FRUSASTNode] = [
            .head(children: [.text("1. Telegram")]),
            .paragraph(children: [.text("Text.")]),
            .footnote(id: "d1fn1", type: .footnote, printedNumber: "1",
                      children: [.text("This is a regular editorial footnote, not a source note.")])
        ]
        #expect(extractSourceNote(from: nodes) == nil)
    }

    // MARK: - Nixon-Ford era: <seg type="source"> inside generic <note>

    @Test("Nixon-Ford: <seg type='source'> inside untyped <note> — bare seg child")
    func nixonFordSegSourceBare() {
        // Nixon-Ford era electronic volumes use a single <note n="1"> containing both
        // <seg type="summary"> and <seg type="source"> as direct children.
        let nodes: [FRUSASTNode] = [
            .head(children: [.text("1. Memorandum of Conversation")]),
            .footnote(
                id: "d1fn1", type: .unclassified, printedNumber: "1",
                children: [
                    .unknown(name: "seg", attributes: ["type": "summary"], children:
                             [.text("Summary: Kissinger met with Dobrynin to discuss SALT.")]),
                    .unknown(name: "seg", attributes: ["type": "source"], children:
                             [.text("Source: Library of Congress, Manuscript Division, Kissinger Papers, Box 374, Chronological File.")])
                ]
            )
        ]
        let result = extractSourceNote(from: nodes)
        #expect(result == "Source: Library of Congress, Manuscript Division, Kissinger Papers, Box 374, Chronological File.")
    }

    @Test("Nixon-Ford: <seg type='source'> wrapped in <p> inside untyped <note>")
    func nixonFordSegSourceInParagraph() {
        // Some Nixon-Ford volumes wrap each seg in a <p> element.
        let nodes: [FRUSASTNode] = [
            .head(children: [.text("1. Backchannel Message")]),
            .footnote(
                id: "d1fn1", type: .unclassified, printedNumber: "1",
                children: [
                    .paragraph(children: [
                        .unknown(name: "seg", attributes: ["type": "summary"], children: [.text("Summary: Discussed arms control.")])
                    ]),
                    .paragraph(children: [
                        .unknown(name: "seg", attributes: ["type": "source"], children: [.text("Source: National Security Archive, Kissinger Transcripts.")])
                    ])
                ]
            )
        ]
        let result = extractSourceNote(from: nodes)
        #expect(result == "Source: National Security Archive, Kissinger Transcripts.")
    }

    @Test("Nixon-Ford: untyped note without a source seg returns nil")
    func nixonFordUntypedNoteWithoutSourceSegReturnsNil() {
        let nodes: [FRUSASTNode] = [
            .footnote(
                id: "d1fn1", type: .unclassified, printedNumber: "1",
                children: [
                    .unknown(name: "seg", attributes: ["type": "summary"], children: [.text("Summary: Only a summary, no source.")])
                ]
            )
        ]
        #expect(extractSourceNote(from: nodes) == nil)
    }

    // MARK: - Source note inside <head>

    @Test("Head-placement: <note type='source'> nested inside <head> element")
    func sourceNoteInsideHead() {
        // Some volumes (particularly earlier eras) embed the source note inside the
        // document heading rather than as a separate sibling of the heading.
        let nodes: [FRUSASTNode] = [
            .head(children: [
                .text("1. Telegram From the Embassy in Moscow to the Department of State"),
                .footnote(id: "d1fn1", type: .source, printedNumber: "1",
                          children: [.text("Source: Department of State, Central Files, 761.00/1-2069.")])
            ]),
            .paragraph(children: [.text("Body text.")])
        ]
        let result = extractSourceNote(from: nodes)
        #expect(result == "Source: Department of State, Central Files, 761.00/1-2069.")
    }

    // MARK: - Withheld inline source note

    @Test("Withheld inline: <note type='source' rend='inline'> produces extractable .footnote node")
    func withheldInlineSourceNoteIsExtractable() {
        // <note type="source" rend="inline"> is used for withheld documents.
        // The parser must NOT make these transparent (isTransparent returns false when
        // type="source"), so a .footnote(type: .source) node is created and is
        // reachable by extractSourceNote.
        let nodes: [FRUSASTNode] = [
            .head(children: [.text("2. Memorandum")]),
            // This node is what the parser produces after the isTransparent fix:
            // rend="inline" type="source" → NOT transparent → .footnote(type: .source)
            .footnote(id: nil, type: .source, printedNumber: nil,
                      children: [.text("[Source: Johnson Library, National Security File, Vietnam, Vol. I. No classification marking. 2 pages of source text. Not declassified.]")]),
            .paragraph(children: [.text("[Not declassified.]")])
        ]
        let result = extractSourceNote(from: nodes)
        #expect(result?.contains("Johnson Library") == true)
        #expect(result?.contains("Not declassified") == true)
        // Phase 1 wrapper normalisation: the "[Source: …]" brackets collapse so both
        // encodings store one shape and the "Source:" narrative parser branch fires.
        #expect(result?.hasPrefix("Source:") == true)
        #expect(result?.hasSuffix("]") == false)
    }

    // MARK: - Priority and edge cases

    @Test("Priority: 'Source:'-prefixed head-nested note found before top-level one (import.xq chain)")
    func headNestedTakesPriorityOverTopLevel() {
        // When both patterns are present and the head-nested note carries the
        // `Source:` prefix, the head-nested note wins — the frus-sources locator
        // chain (import.xq) checks head/note[@type='source'] before the top-level
        // inline note. 29 corpus documents carry both encodings; in the ones where
        // the head note is the real citation (e.g. frus1952-54v07p1 d57/d64,
        // frus1952-54v14p1 d75, whose top-level note is just "[Translation]" /
        // "[Extract]"), it is `Source:`-prefixed.
        let nodes: [FRUSASTNode] = [
            .head(children: [
                .text("Document"),
                .footnote(id: "head-fn", type: .source, printedNumber: nil,
                          children: [.text("Source: Head-nested note.")])
            ]),
            .footnote(id: "div-fn", type: .source, printedNumber: "1",
                      children: [.text("Source: Top-level note.")])
        ]
        #expect(extractSourceNote(from: nodes) == "Source: Head-nested note.")
    }

    @Test("Priority: dual-encoding — top-level citation wins over a non-prefixed head remark")
    func topLevelCitationWinsOverHeadRemark() {
        // 25 pre-1955 documents (frus1949v01, frus1952-54v01p2/v03/v05p1) nest an
        // editorial remark — no `Source:` prefix — in <head> while the real
        // decimal/lot citation is the top-level inline note. The head remark must
        // defer to the top-level citation, or the document loses its citation_era
        // and archival-neighbor keys (adversarial-review finding 1; modeled on
        // frus1952-54v03 d453).
        let nodes: [FRUSASTNode] = [
            .head(children: [
                .text("Memorandum by the Deputy Assistant Secretary of State"),
                .footnote(id: "head-fn", type: .source, printedNumber: "1",
                          children: [.text("Source text indicates this memorandum was dictated Nov. 13.")])
            ]),
            .footnote(id: "div-fn", type: .source, printedNumber: nil,
                      children: [.text("310.2/8–2753")])
        ]
        #expect(extractSourceNote(from: nodes) == "310.2/8–2753")
    }

    @Test("Priority: non-prefixed head remark is still used when no top-level note exists")
    func headRemarkFallbackWhenNoTopLevelNote() {
        // ~1,991 corpus documents (frus1961-63 microfiche supplements, 1931–48
        // volumes) have a non-`Source:`-prefixed head-nested note and NO top-level
        // alternative — the deferred whole-note fallback must still serve them.
        let nodes: [FRUSASTNode] = [
            .head(children: [
                .text("Telegram"),
                .footnote(id: "head-fn", type: .source, printedNumber: "1",
                          children: [.text("Department of State, Central Files, 611.61/4–1861.")])
            ]),
            .paragraph(children: [.text("Body text.")])
        ]
        #expect(extractSourceNote(from: nodes)
                == "Department of State, Central Files, 611.61/4–1861.")
    }

    @Test("Edge: source note with whitespace-only children returns nil")
    func whitespaceOnlyChildrenReturnsNil() {
        let nodes: [FRUSASTNode] = [
            .footnote(id: "d1fn1", type: .source, printedNumber: "1",
                      children: [.text("   \n  ")])
        ]
        #expect(extractSourceNote(from: nodes) == nil)
    }
}

// MARK: - ClassificationMarkingTests

/// Verifies `SourceNoteParser.classificationMarking(fromSourceNote:)` — the S1
/// sentence-2 split (frus-sources sentence model): sentence 1 = archival citation,
/// sentence 2 = classification markings, remainder = remarks. The extractor must be
/// conservative: nil rather than junk when sentence 2 is not markings.
@Suite("ClassificationMarkingTests")
struct ClassificationMarkingTests {

    @Test("real markings: simple level plus caveat")
    func levelPlusCaveat() {
        let note = "Source: Department of State, Central Files, 396.1 GE/7–854. Secret; Nodis."
        #expect(SourceNoteParser.classificationMarking(fromSourceNote: note) == "Secret; Nodis")
    }

    @Test("real markings: Top Secret with multi-word caveats, remarks excluded")
    func topSecretMultiCaveat() {
        let note = "Source: Library of Congress, Manuscript Division, Kissinger Papers, Box CL 101, Geopolitical File, Algeria, April–May 1974. Secret; Sensitive; Exclusively Eyes Only. Kissinger met with Boumediene in Algiers en route to the Middle East."
        #expect(SourceNoteParser.classificationMarking(fromSourceNote: note)
                == "Secret; Sensitive; Exclusively Eyes Only")
    }

    @Test("real markings: 'No classification marking' statement is accepted")
    func noClassificationMarking() {
        let note = "Source: Johnson Library, National Security File, Country File, Vietnam, Memos and Miscellaneous. No classification marking."
        #expect(SourceNoteParser.classificationMarking(fromSourceNote: note)
                == "No classification marking")
    }

    @Test("non-marking second sentence returns nil (prose remark)")
    func proseRemarkReturnsNil() {
        let note = "Source: Library of Congress, Manuscript Division, Kissinger Papers, Box CL 168, Geopolitical File. Sent for information."
        #expect(SourceNoteParser.classificationMarking(fromSourceNote: note) == nil)
    }

    @Test("non-marking second sentence returns nil (long sentence, no vocabulary)")
    func longSentenceReturnsNil() {
        let note = "Source: National Archives, RG 59, Central Files 1967–69, POL 27 ARAB–ISR. A copy was sent to the White House for the President's evening reading and to the Embassy in Tel Aviv."
        #expect(SourceNoteParser.classificationMarking(fromSourceNote: note) == nil)
    }

    @Test("second sentence containing digits returns nil (received-time remark)")
    func digitsReturnNil() {
        let note = "Source: Department of State, Central Files, 611.3722/10–2062. Received at 7:31 p.m. on October 20."
        #expect(SourceNoteParser.classificationMarking(fromSourceNote: note) == nil)
    }

    @Test("single-sentence note returns nil (no sentence 2)")
    func singleSentenceReturnsNil() {
        #expect(SourceNoteParser.classificationMarking(
            fromSourceNote: "Source: Department of State, Central Files, 761.00/1-2069.") == nil)
        #expect(SourceNoteParser.classificationMarking(fromSourceNote: "711.00/11–552") == nil)
        #expect(SourceNoteParser.classificationMarking(fromSourceNote: "") == nil)
    }

    @Test("lowercase or run-on fragments after a valid level return nil")
    func lowercaseFragmentReturnsNil() {
        let note = "Source: Department of State, Central Files, 601.0093/5–1553. Secret; drafted by the Executive Secretariat after the meeting adjourned."
        #expect(SourceNoteParser.classificationMarking(fromSourceNote: note) == nil)
    }

    @Test("abbreviation split ('U.S. Government') truncating the marking sentence returns nil")
    func abbreviationSplitReturnsNil() {
        // The sentence-boundary regex has no abbreviation model, so it splits inside
        // "U.S. Government" and the candidate ends "…Dissemination to U.S" — the
        // interior '.' in the last fragment must reject the whole candidate rather
        // than store the truncated junk (adversarial-review finding 3).
        let note = "Source: Department of State, INR Files. Top Secret; SUEDE; Dissemination to U.S. Government agencies only."
        #expect(SourceNoteParser.classificationMarking(fromSourceNote: note) == nil)
    }

    @Test("missing space after the marking period (run-on remark) returns nil")
    func missingSpaceRunOnReturnsNil() {
        // TEI missing the space after "Priority." defeats the boundary regex, so the
        // remark rides along inside the fragment — the interior '.' gate rejects it.
        let note = "Source: Department of State, Central Files, 601.0093/5–1553. Confidential; Priority.Drafted by Dulles."
        #expect(SourceNoteParser.classificationMarking(fromSourceNote: note) == nil)
    }

    @Test("capitalized remark-verb fragment ('Drafted by …') returns nil")
    func remarkVerbFragmentReturnsNil() {
        // A short capitalized remark like "Drafted by Seward (FE/CA/RA)" passes the
        // 4-word shape gate; the remark-verb gate must reject it.
        let note = "Source: Department of State, Central Files, 601.0093/5–1553. Confidential; Priority; Drafted by Seward (FE/CA/RA)."
        #expect(SourceNoteParser.classificationMarking(fromSourceNote: note) == nil)
    }
}

// MARK: - ArchivalNeighborMatchingTests

/// Verifies `ParsedSourceNote.supportsArchivalNeighbors` / `archivalNeighborKey`, which the
/// Source Explorer uses to decide whether the "Documents from This Collection" section can
/// match neighbors and to explain an empty result.
@Suite("ArchivalNeighborMatchingTests")
struct ArchivalNeighborMatchingTests {

    @Test("matchable archival note types expose a key")
    func matchableTypes() {
        #expect(ParsedSourceNote.lotFile(recordGroup: "RG-59", lotNumber: "63 D 123", fileIdentifier: nil).supportsArchivalNeighbors)
        #expect(ParsedSourceNote.lotFile(recordGroup: nil, lotNumber: "63 D 123", fileIdentifier: nil).archivalNeighborKey == "Lot 63 D 123")

        #expect(ParsedSourceNote.presidentialLibrary(library: "Kennedy Library", collection: "National Security Files", fileIdentifier: nil).supportsArchivalNeighbors)

        // central files require a decimal identifier
        #expect(ParsedSourceNote.centralFiles(recordGroup: "59", fileIdentifier: "611.51/10-1646").supportsArchivalNeighbors)
        #expect(ParsedSourceNote.centralFiles(recordGroup: "59", fileIdentifier: "611.51/10-1646").archivalNeighborKey == "611.51")

        // nara collection requires a lot
        #expect(ParsedSourceNote.naraCollection(recordGroup: "59", series: "Decimal File", lotFile: "64 D 199", box: nil).supportsArchivalNeighbors)
    }

    @Test("unmatchable note types expose no key")
    func unmatchableTypes() {
        #expect(!ParsedSourceNote.centralFiles(recordGroup: "59", fileIdentifier: "3767/5").supportsArchivalNeighbors) // no decimal
        #expect(!ParsedSourceNote.naraCollection(recordGroup: "59", series: "Decimal File", lotFile: nil, box: nil).supportsArchivalNeighbors)
        #expect(!ParsedSourceNote.previouslyPublished(citation: "FRUS 1958-60, vol. X").supportsArchivalNeighbors)
        #expect(!ParsedSourceNote.unrecognized(rawText: "Source: see footnote 3").supportsArchivalNeighbors)
        #expect(ParsedSourceNote.cfpfFile(fileIdentifier: "P-reel 12").archivalNeighborKey == nil)
    }
}
