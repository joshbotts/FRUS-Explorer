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

// MARK: - CentralFilesIndexTests

/// Tests for the app-side Central Files index model: JSON decoding (matching the
/// generated contract), File No. → roll lookup, and the bundled index sanity.
struct CentralFilesIndexTests {

    /// A JSON sample shaped exactly like the generated `central-files-index.json`.
    private let sampleJSON = """
    {
      "schemaVersion" : 1,
      "generated" : "2026-06-16",
      "numericalFile" : {
        "microfilm" : "M862",
        "seriesNaId" : "654171",
        "rolls" : [
          { "caseStart" : 682, "caseEnd" : 699, "naId" : "19174810",
            "title" : "Numerical File: 682-699",
            "catalogURL" : "https://catalog.archives.gov/id/19174810" },
          { "caseStart" : 7179, "caseEnd" : 7187, "naId" : "19779414",
            "title" : "Numerical File: 7179-7187",
            "catalogURL" : "https://catalog.archives.gov/id/19779414" },
          { "caseStart" : 14319, "caseEnd" : 14319, "naId" : "r1",
            "title" : "Numerical File: 14319/51-14319/120", "catalogURL" : "u1" },
          { "caseStart" : 14319, "caseEnd" : 14330, "naId" : "r2",
            "title" : "Numerical File: 14319/121-14330", "catalogURL" : "u2" }
        ]
      }
    }
    """

    private func decodeSample() throws -> CentralFilesIndex {
        try JSONDecoder().decode(CentralFilesIndex.self, from: Data(sampleJSON.utf8))
    }

    @Test("Decodes the generated JSON contract")
    func decodesContract() throws {
        let index = try decodeSample()
        #expect(index.schemaVersion == 1)
        #expect(index.numericalFile.microfilm == "M862")
        #expect(index.numericalFile.seriesNaId == "654171")
        #expect(index.numericalFile.rolls.count == 4)
    }

    @Test("Resolves the golden File No. citations to the correct roll")
    func resolvesGoldenCitations() throws {
        let index = try decodeSample()
        // Doc 6: File No. 7187; Doc 7: File No. 697/43.
        #expect(index.numericalFile.rolls(forFileNumber: "7187").map(\.naId) == ["19779414"])
        #expect(index.numericalFile.rolls(forFileNumber: "697/43").map(\.naId) == ["19174810"])
    }

    @Test("Parses the case number from File No. strings, ignoring labels and sub-docs")
    func parsesCaseNumber() {
        #expect(CentralFilesIndex.caseNumber(fromFileNumber: "7187") == 7187)
        #expect(CentralFilesIndex.caseNumber(fromFileNumber: "697/43") == 697)
        #expect(CentralFilesIndex.caseNumber(fromFileNumber: "File No. 17529.") == 17529)
        #expect(CentralFilesIndex.caseNumber(fromFileNumber: "no digits") == nil)
    }

    @Test("Returns all rolls when a case is split across rolls")
    func returnsAllRollsForSplitCase() throws {
        let index = try decodeSample()
        // Case 14319 spans r1 (sub-docs 51–120) and r2 (121–14330).
        #expect(index.numericalFile.rolls(forFileNumber: "14319/77").map(\.naId) == ["r1", "r2"])
        // 14325 is only on r2.
        #expect(index.numericalFile.rolls(forFileNumber: "14325").map(\.naId) == ["r2"])
    }

    @Test("Returns no rolls for a case in a coverage gap")
    func gapReturnsEmpty() throws {
        let index = try decodeSample()
        #expect(index.numericalFile.rolls(forFileNumber: "5000").isEmpty)  // between 699 and 7179
    }

    @Test("Lot file decodes and resolves from a raw source-note lot number")
    func lotFileLookup() throws {
        let json = """
        {
          "schemaVersion": 3, "generated": "2026-06-16",
          "numericalFile": { "microfilm": "M862", "seriesNaId": "654171", "rolls": [] },
          "lotFiles": [
            { "lotNumber": "64D199", "recordGroup": "59", "naId": "602231",
              "title": "The Secretary's Memorandums of Conversation",
              "catalogURL": "https://catalog.archives.gov/id/602231", "matchType": "control" }
          ]
        }
        """
        let index = try JSONDecoder().decode(CentralFilesIndex.self, from: Data(json.utf8))
        // Raw spellings from source notes normalize to the bundle's compact key.
        #expect(index.lotFile(forRawLot: "64 D 199")?.naId == "602231")
        #expect(index.lotFile(forRawLot: "Lot 64-D 199")?.naId == "602231")
        #expect(index.lotFile(forRawLot: "64D199")?.matchType == "control")
        #expect(index.lotFile(forRawLot: "99Z9") == nil)
    }

    @Test("normalizeLot matches the generator's compact form")
    func normalizesLot() {
        #expect(CentralFilesIndex.normalizeLot("63 D 135") == "63D135")
        #expect(CentralFilesIndex.normalizeLot("61–D 146") == "61D146")
        #expect(CentralFilesIndex.normalizeLot("Lot 56 F 28") == "56F28")
    }

    @Test("The bundled index loads, parses, and resolves the golden citations")
    func bundledIndexResolvesGolden() throws {
        // Guards against the resource being dropped from the bundle or the schema drifting.
        let index = try #require(CentralFilesIndexStore.shared,
                                 "central-files-index.json should be bundled and decodable")
        #expect(index.numericalFile.microfilm == "M862")
        #expect(index.numericalFile.rolls.count > 1000)
        #expect(index.numericalFile.rolls(forFileNumber: "7187").contains { $0.naId == "19779414" })
        #expect(index.numericalFile.rolls(forFileNumber: "697/43").contains { $0.naId == "19174810" })
    }
}
