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
        // Era 4 — State Dept. central files (full narrative)
        let centralNarrative = "Source: Department of State, Central Foreign Policy File, Electronic Telegrams, D891080-0768. Secret; Exdis. Sent Immediate."
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
                    .previouslyPublished, .unrecognized, .naraCollection, .ciaCollection:
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
    }

    // MARK: - Priority and edge cases

    @Test("Priority: top-level source note found before head-nested one")
    func topLevelTakesPriorityOverHeadNested() {
        // If both patterns are present, the top-level note (pass 1) is returned first.
        let nodes: [FRUSASTNode] = [
            .head(children: [
                .text("Document"),
                .footnote(id: "head-fn", type: .source, printedNumber: nil,
                          children: [.text("Source: Head-nested note.")])
            ]),
            .footnote(id: "div-fn", type: .source, printedNumber: "1",
                      children: [.text("Source: Top-level note.")])
        ]
        #expect(extractSourceNote(from: nodes) == "Source: Top-level note.")
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
