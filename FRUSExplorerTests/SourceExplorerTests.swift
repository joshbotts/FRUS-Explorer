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
        if case .lotFile(let lot, _) = parser.parse(lotFileInline) {
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
                    .previouslyPublished, .unrecognized:
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
