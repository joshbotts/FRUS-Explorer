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

// MARK: - AuthorityFoldTests

/// The cross-volume authority fold, driven directly (#733).
///
/// Added because a mutation sweep found this layer unguarded: deleting the job clause from
/// `accumulateAuthority`'s admission gate, and folding job numbers into the `lot:` key space,
/// BOTH passed the extractor suites. Those suites test what a row extracts; nothing tested what
/// the runner does with it, which is the half that decides whether the key reaches the artifact.
///
/// Version history:
///   1.0 — Session 2026-08-10: #733
@Suite("Authority fold (#733)")
struct AuthorityFoldTests {

    private func node(text: String, isHeading: Bool = false, recordGroup: String? = nil,
                      lotFile: String? = nil, jobNumber: String? = nil,
                      children: [CollectionNode] = []) -> CollectionNode {
        CollectionNode(text: text, isHeading: isHeading, depth: 0, recordGroup: recordGroup,
                       lotFile: lotFile, repository: nil, jobNumber: jobNumber,
                       resolved: nil, children: children)
    }

    private func fold(_ nodes: [CollectionNode],
                      volumes: [String] = ["frus1961-63v10"]) -> [String: MajorCollection] {
        var authority: [String: MajorCollection] = [:]
        for v in volumes {
            VolumeSourcesIndexRunner.accumulateAuthority(nodes, volumeId: v, into: &authority)
        }
        return authority
    }

    @Test("A job-bearing node enters the authority even though it is no heading and has no RG")
    func jobNodeIsAdmitted() {
        // The shape of 618 of the 620 real job rows: not a heading, no record group, no lot.
        let a = fold([node(text: "Job 79–R01012A (Registry of NIEs)", jobNumber: "79–R01012A")])
        #expect(a["job:79R01012A"] != nil, """
            A job node must be admitted on the same footing as a lot node. Without it the key is \
            extracted and then discarded at the gate, so #733 changes nothing. Got \
            \(a.keys.sorted()).
            """)
        #expect(a["job:79R01012A"]?.jobNumber == "79–R01012A", "and the raw form is carried")
    }

    @Test("A job keys its own namespace, never the lot namespace")
    func jobDoesNotEnterTheLotKeySpace() {
        let a = fold([node(text: "Job 80–B01285A", jobNumber: "80–B01285A")])
        #expect(a.keys.allSatisfy { !$0.hasPrefix("lot:") }, """
            A `lot:` key here would be looked up in central-files-index.json's lot table, where a \
            job number can only miss or — worse — hit another collection. Got \(a.keys.sorted()).
            """)
        #expect(a.keys.contains("job:80B01285A"))
    }

    @Test("The four spellings of one job fold to one authority record")
    func dashVariantsFoldTogether() {
        let a = fold([node(text: "a", jobNumber: "79R01012A"),
                      node(text: "b", jobNumber: "79-R01012A"),
                      node(text: "c", jobNumber: "79–R01012A"),
                      node(text: "d", jobNumber: "79R–01012A")])
        #expect(a.count == 1, "expected one record, got \(a.keys.sorted())")
        #expect(a["job:79R01012A"]?.occurrences == 4)
    }

    @Test("The same job across volumes accumulates volumes, not duplicates")
    func recursAcrossVolumes() {
        let a = fold([node(text: "Job 79R01012A", jobNumber: "79R01012A")],
                     volumes: ["frus1961-63v10", "frus1969-76v13", "frus1969-76v34"])
        #expect(a["job:79R01012A"]?.volumeIds.count == 3)
        #expect(a["job:79R01012A"]?.occurrences == 3)
    }

    @Test("A lot node still keys the lot namespace, and a plain node still keys its text")
    func otherNodesUnaffected() {
        let a = fold([node(text: "Central Files, Lot 64 D 199", lotFile: "64 D 199"),
                      node(text: "A Heading", isHeading: true)])
        #expect(a["lot:64D199"] != nil, "got \(a.keys.sorted())")
        #expect(a["txt:a heading"] != nil, "got \(a.keys.sorted())")
    }

    @Test("A job on a nested child is reached")
    func nestedJobIsFolded() {
        // The real encoding: a CIA repository heading with job-bearing children beneath it.
        let a = fold([node(text: "Central Intelligence Agency", isHeading: true, children: [
            node(text: "Job 80–M01048A", jobNumber: "80–M01048A"),
        ])])
        #expect(a["job:80M01048A"] != nil, "recursion must reach children; got \(a.keys.sorted())")
    }
}
