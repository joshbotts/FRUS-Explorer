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

// MARK: - CIAJobGrammarTests

/// The shared CIA Job grammar and its normal form (#733).
///
/// Until #733 the Job pattern was reachable only through `tryCIACollection`, which requires the
/// note to name the Agency. A front-matter outline row rarely does — its CIA identity lives in an
/// ancestor heading — so the front matter keyed no Job at all while the same collection cited in a
/// document note keyed one.
///
/// Version history:
///   1.0 — Session 2026-08-10: #733
@Suite("CIA Job grammar (#733)")
struct CIAJobGrammarTests {

    @Test("The real corpus spellings all parse")
    func realSpellings() {
        // Every shape the corpus actually uses, taken from the owner's index.
        let cases: [(String, String)] = [
            ("Job 78–05091A", "78–05091A"),                                  // en-dash
            ("Job 80-01795R", "80-01795R"),                                  // hyphen
            ("Job 79R01012A", "79R01012A"),                                  // no separator
            ("Job 84–B00389R", "84–B00389R"),                                // letter mid-number
            ("DCI (McCone) Files: Job 80-B01285A", "80-B01285A"),            // prefixed by a series
            ("Job 79-R01012A, ODDI Registry", "79-R01012A"),                 // trailing segment
            ("NIC Registry of NIE and SNIE Files, Job 79–R01012A", "79–R01012A"),
            ("Job 80B01676R (DCI Logs, Minutes of Deputies Meetings)", "80B01676R"),
            ("job 95–G00278R", "95–G00278R"),                                // case-insensitive
        ]
        for (text, expected) in cases {
            #expect(SourceNoteParser.firstJobNumber(in: text) == expected,
                    "\(text) → \(SourceNoteParser.firstJobNumber(in: text) ?? "nil")")
        }
    }

    @Test("Prose senses of the word do not mint an archival key")
    func prosesSensesRefused() {
        // The measured false-positive rate over all 33,764 front-matter rows is zero, but that is
        // a property of today's corpus. The leading-digits requirement makes it structural: these
        // are what a bare `\bJob\s+(\w+)` would have keyed.
        for text in ["Job Corps records, 1965", "his job at the Department",
                     "Job Descriptions, Box 4", "the Job of the Under Secretary",
                     "Job"] {
            #expect(SourceNoteParser.firstJobNumber(in: text) == nil,
                    "\(text) must not yield a job key, got \(SourceNoteParser.firstJobNumber(in: text) ?? "nil")")
        }
    }

    @Test("A job number needs two leading digits and a body")
    func shapeGuard() {
        #expect(SourceNoteParser.firstJobNumber(in: "Job 7") == nil, "too short")
        #expect(SourceNoteParser.firstJobNumber(in: "Job 79R") == "79R", "three chars is enough")
        #expect(SourceNoteParser.firstJobNumber(in: "Job R01012A") == nil, "must open with digits")
    }

    @Test("The four spellings of one job reduce to one key")
    func normFoldsDashVariants() {
        // Job 79R01012A — the Registry of National Intelligence Estimates — is cited 214 times
        // across four spellings. Without a normal form it is four collections of 119, 55, 33 and 7.
        let spellings = ["79R01012A", "79-R01012A", "79–R01012A", "79R–01012A"]
        let keys = Set(spellings.map { SourceNoteParser.jobNumberNorm($0) })
        #expect(keys == ["79R01012A"], "got \(keys.sorted())")
    }

    @Test("The job key space is not the lot key space")
    func jobKeysAreNotLotKeys() {
        // Measured over the whole corpus: 395 job norms against 1,734 lot norms, zero collisions.
        // The two normal forms are the same transformation, so nothing but the separate column
        // keeps a job number from being looked up in `central-files-index.json`'s lot table.
        #expect(SourceNoteParser.jobNumberNorm("79–R01012A") == "79R01012A")
        #expect(SourceNoteParser.lotFileNorm("64 D 199") == "64D199")
        // A job is not recognised as a lot, and a lot is not recognised as a job.
        #expect(SourceNoteParser.firstLotReference(in: "Job 79–R01012A") == nil,
                "the lot grammar requires the word Lot")
        #expect(SourceNoteParser.firstJobNumber(in: "Lot 64 D 199") == nil,
                "the job grammar requires the word Job")
    }
}

// MARK: - FrontMatterJobKeyingTests

/// That the front-matter extractor actually emits the key (#733).
///
/// The generator's four existing promotion tests assert on `items.map(\.text)` only, so they stay
/// green whether a key is extracted correctly, incorrectly, or not at all. These drive the real
/// extractor and assert the key.
///
/// Version history:
///   1.0 — Session 2026-08-10: #733
@Suite("Front-matter CIA Job keying (#733)")
struct FrontMatterJobKeyingTests {

    /// Parses a Sources section through the **real** `parseVolumeFull` entry point, so section
    /// detection, the delegate and the promotion pass are all exercised together.
    private func parse(_ sourcesXML: String) async throws -> [VolumeSourceEntry] {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("frus733-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("frus1961-63v10.xml")
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <teiHeader><fileDesc><titleStmt><title>fixture</title></titleStmt>
          <publicationStmt><date when="1997">1997</date></publicationStmt>
          <sourceDesc><p>fixture</p></sourceDesc></fileDesc></teiHeader>
          <text><front>
            <div type="section" subtype="sources" xml:id="sources">
              <head>Sources</head>
        \(sourcesXML)
            </div>
          </front><body></body></text>
        </TEI>
        """.write(to: url, atomically: true, encoding: .utf8)
        return try await FRUSDocumentParser().parseVolumeFull(volumeURL: url).volumeSources
    }

    @Test("An outline item naming a Job keys it, normalised")
    func itemRowKeysAJob() async throws {
        let rows = try await parse("""
        <list>
          <item><hi rend="strong">Central Intelligence Agency</hi>
            <list>
              <item>Job 79–R01012A (Registry of National Intelligence Estimates)</item>
              <item>DDO/DDP Files: Job 64–00352R</item>
            </list>
          </item>
        </list>
        """)
        let keyed = rows.filter { $0.jobNumber != nil }
        #expect(keyed.count == 2, "expected both job rows keyed, got \(rows.map(\.jobNumber))")
        #expect(keyed.map(\.jobNumberNorm) == ["79R01012A", "6400352R"])
        // The job must NOT land in the lot column — that column is looked up as a lot number.
        #expect(keyed.allSatisfy { $0.lotFile == nil && $0.lotFileNorm == nil },
                "a job number in lot_file would be resolved against the lot table")
    }

    @Test("A row that names no Job keys none")
    func nonJobRowsUnaffected() async throws {
        let rows = try await parse("""
        <list>
          <item><hi rend="strong">Department of State</hi>
            <list><item>Central Files, Lot 64 D 199</item></list>
          </item>
        </list>
        """)
        #expect(rows.allSatisfy { $0.jobNumber == nil })
        #expect(rows.contains { $0.lotFileNorm == "64D199" }, "the lot key still works")
    }

    @Test("The job is read from the row's own text, never inherited")
    func jobIsNotInherited() async throws {
        // Unlike repository and record group, a job number identifies ONE container. Inheriting
        // it would key every sibling to the first child's collection.
        let rows = try await parse("""
        <list>
          <item><hi rend="strong">Job 79–R01012A, Central Intelligence Agency</hi>
            <list>
              <item>Some other series with no job number</item>
            </list>
          </item>
        </list>
        """)
        let children = rows.filter { $0.depth > 0 }
        #expect(!children.isEmpty, "fixture must produce a child row")
        #expect(children.allSatisfy { $0.jobNumber == nil },
                "a child inherited a job number: \(children.map(\.jobNumber))")
    }

    @Test("The promotion pass carries the job across")
    func promotedRowKeepsItsJob() async throws {
        // `withNote` rebuilds the entry field-by-field after extraction, so an omitted field is
        // dropped from exactly the #668 paragraph-encoded collections and nowhere else — the
        // silent-loss shape this test exists to pin.
        let rows = try await parse("""
        <p rend="flushleft">Job 80–B01285A (DCI McCone Files)</p>
        <p>Records of the Director of Central Intelligence, 1961–1965.</p>
        """)
        let keyed = rows.filter { $0.jobNumber != nil }
        #expect(keyed.count == 1, "expected the promoted row to keep its job, got \(rows.map(\.jobNumber))")
        #expect(keyed.first?.jobNumberNorm == "80B01285A")
        #expect(keyed.first?.note != nil, "and to keep the description the promotion pass absorbed")
    }
}
