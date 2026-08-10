// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import VolumeSourcesIndexGeneratorCore
import SourceNoteKit

// MARK: - JobKeyingTests

/// The generator's half of #733, plus the lot-grammar divergence it uncovered.
///
/// The four existing extractor tests assert on `items.map(\.text)` only, so a key that is never
/// extracted, or extracted wrongly, leaves all of them green. These assert the keys.
///
/// Version history:
///   1.0 — Session 2026-08-10: #733
@Suite("Generator job keying (#733)")
struct JobKeyingTests {

    private func rows(_ sourcesXML: String) -> [SourceRow] {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <text><front>
            <div type="section" subtype="sources"><head>Sources</head>
        \(sourcesXML)
            </div>
          </front><body></body></text>
        </TEI>
        """
        return VolumeSourcesExtractor.extract(fromXML: Data(xml.utf8))
    }

    @Test("An outline item naming a Job keys it")
    func itemKeysAJob() {
        let extracted = rows("""
        <list>
          <item><hi rend="strong">Central Intelligence Agency</hi>
            <list>
              <item>Job 79–R01012A (Registry of National Intelligence Estimates)</item>
              <item>DDO/DDP Files: Job 64–00352R</item>
              <item>Some series naming no job at all</item>
            </list>
          </item>
        </list>
        """)
        let jobs = extracted.compactMap(\.jobNumber)
        #expect(jobs == ["79–R01012A", "64–00352R"], "got \(jobs)")
        // …and never into the lot column, which BundledLotResolver looks up as a lot number.
        #expect(extracted.allSatisfy { $0.lotFile == nil },
                "a job in lotFile is resolved against central-files-index.json's lot table")
    }

    @Test("The generator and the app agree about what a Job is")
    func sharesTheAppsGrammar() {
        // One grammar, not two: the extractor calls SourceNoteParser rather than declaring its
        // own pattern, so the bundled index and the app's `volume_sources` table cannot disagree.
        for text in ["Job 79–R01012A", "DCI (McCone) Files: Job 80-B01285A", "Job 84–B00389R"] {
            let row = rows("<list><item>\(text)</item></list>").first { $0.kind == .item }
            #expect(row?.jobNumber == SourceNoteParser.firstJobNumber(in: text),
                    "\(text): extractor said \(row?.jobNumber ?? "nil")")
        }
    }

    @Test("Prose senses do not mint a key here either")
    func noProseFalsePositives() {
        let extracted = rows("<list><item>Job Corps records, 1965–1968</item></list>")
        #expect(extracted.allSatisfy { $0.jobNumber == nil })
    }

    // MARK: - The lot-grammar divergence #733 uncovered

    @Test("F-designator lots are keyed, which the retired D-only pattern could not do")
    func fDesignatorLotsAreKeyed() {
        // The extractor used to declare `#"\bLot\s+([\w\s\-]+?D\s*\d+)\b"# — D only — which is the
        // regex the app replaced at index version 18. Measured against the app's own table, 249
        // rows across 75 volumes carry a lot it cannot see; 225 of them are F-designator posts.
        // Those collections were simply missing from the bundled index.
        let cases = [
            ("London Embassy Files, Lot 59 F 59", "59 F 59"),
            ("Berlin Mission Files, Lot 58 F 62", "58 F 62"),
            ("EDC Files, Lot 57 M 44", "57 M 44"),
            ("USIA Files, Lot 63 A 190", "63 A 190"),
        ]
        for (text, expected) in cases {
            let row = rows("<list><item>\(text)</item></list>").first { $0.kind == .item }
            #expect(row?.lotFile == expected, "\(text): got \(row?.lotFile ?? "nil")")
        }
    }

    @Test("D-designator lots still key exactly as before")
    func dDesignatorLotsUnchanged() {
        for (text, expected) in [("Central Files, Lot 64 D 199", "64 D 199"),
                                 ("Conference Files, Lot 60 D 627", "60 D 627")] {
            let row = rows("<list><item>\(text)</item></list>").first { $0.kind == .item }
            #expect(row?.lotFile == expected, "\(text): got \(row?.lotFile ?? "nil")")
        }
    }
}
