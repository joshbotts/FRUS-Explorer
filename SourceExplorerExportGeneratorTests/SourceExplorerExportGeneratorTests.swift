// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import SourceExplorerExportGeneratorCore
import CollectionAuthorityGeneratorCore
import CentralFilesIndexGeneratorCore
import SourceNoteKit
import VolumeSourcesIndexGeneratorCore

// MARK: - AuthorityLookupParityTests

/// Fixture table locking `AuthorityLookup` to the app's `CollectionAuthorityIndex` lookup
/// contract (`FRUSExplorer/SourceExplorer/CollectionAuthority.swift:137-157`, the documented
/// 4-step order, and `:230-252`, the lookup implementations). One case per branch — if either
/// copy drifts, a case here fails (the CrossRefKit parity pattern).
struct AuthorityLookupParityTests {

    /// Records covering every lookup branch.
    private func fixtureLookup() -> AuthorityLookup {
        AuthorityLookup(collections: [
            AuthorityCollection(id: "lot:64D199", name: "Conference Files",
                                lotFileNorm: "64D199", naId: "1000",
                                catalogURL: "https://catalog.archives.gov/id/1000"),
            AuthorityCollection(id: "txt:johnson library|national security file",
                                name: "National Security File",
                                repository: "Johnson Library", naId: "2000"),
            // The sole unattributed text record carrying its segment (step 3's bridge target).
            AuthorityCollection(id: "txt:|conference dossiers", name: "Conference Dossiers"),
            // A uniquely-aliased record (step 4).
            AuthorityCollection(id: "txt:truman library|psf",
                                name: "President's Secretary's Files",
                                aliases: ["PSF Chronological File"]),
            // Two records sharing an alias — ambiguous, must never resolve via step 4.
            AuthorityCollection(id: "txt:ford library|shared name", name: "Shared Name"),
            AuthorityCollection(id: "txt:reagan library|shared name two", name: "Shared Name Two",
                                aliases: ["Shared Name"]),
        ])
    }

    @Test("step 1: the lot key always wins")
    func lotKeyWins() {
        let lookup = fixtureLookup()
        #expect(lookup.record(forLotNorm: "64D199")?.name == "Conference Files")
        // Via the parsed-note entry point: a lot-carrying parse resolves through its lot.
        let parsed = SourceNoteParser().parse("Department of State, Conference Files: Lot 64 D 199, CF 100.")
        #expect(lookup.record(forParsed: parsed, note: "Department of State, Conference Files: Lot 64 D 199, CF 100.")?.id == "lot:64D199")
    }

    @Test("step 2: the repository-scoped text key resolves")
    func repoScopedKey() {
        let lookup = fixtureLookup()
        #expect(lookup.record(repository: "Johnson Library",
                              leadingSegment: "National Security File")?.naId == "2000")
    }

    @Test("step 3: the guarded unattributed bucket bridges a sole, non-generic segment")
    func unattributedBridge() {
        let lookup = fixtureLookup()
        // A repository the fixture doesn't key ("Kennedy Library") + a segment carried only
        // by the unattributed record → the guard bridges.
        #expect(lookup.record(repository: "Kennedy Library",
                              leadingSegment: "Conference Dossiers")?.id == "txt:|conference dossiers")
        // A GENERIC lead segment must never bridge, even for a keyed repository — the
        // guard's first condition (mirrors the app's isGenericLead gate; "Subject Files"
        // plural-folds to the listed "subject file" generic).
        #expect(CollectionKeying.isGenericLead(CollectionKeying.segmentNorm("Subject Files")))
        #expect(lookup.record(repository: "Kennedy Library",
                              leadingSegment: "Subject Files") == nil)
    }

    @Test("step 4: a unique alias resolves; a shared alias never does")
    func aliasResolution() {
        let lookup = fixtureLookup()
        #expect(lookup.record(repository: "Truman Library",
                              leadingSegment: "PSF Chronological File")?.id == "txt:truman library|psf")
        // "Shared Name" is carried by two records — ambiguous, resolves to neither.
        #expect(lookup.uniqueRecord(forAliasNorm: CollectionKeying.segmentNorm("Shared Name")) == nil)
    }

    @Test("no identity → no record (foreign archives, previously published, unrecognized)")
    func noIdentityCases() {
        let lookup = fixtureLookup()
        let parsed = SourceNoteParser().parse("Printed from a copy that was released by the British Foreign Office.")
        #expect(lookup.record(forParsed: parsed, note: "Printed from a copy…") == nil)
    }
}

// MARK: - DocumentYearExtractorTests

/// Verifies the id-keyed year extraction from `frus:doc-dateTime-min` attributes.
struct DocumentYearExtractorTests {

    @Test("years keyed by xml:id; undated and id-less divs omitted; nesting safe")
    func extraction() {
        let xml = """
        <TEI xmlns:frus="http://history.state.gov/frus/ns/1.0">
          <div type="chapter">
            <div type="document" xml:id="d1" frus:doc-dateTime-min="1946-03-05T00:00:00">
              <div type="section"><p>nested non-document div</p></div>
            </div>
            <div type="document" xml:id="d2">undated</div>
            <div type="document" frus:doc-dateTime-min="1950-01-01T00:00:00">no id</div>
            <div type="document" xml:id="d3" frus:doc-dateTime-min="1907-11-20T00:00:00"/>
          </div>
        </TEI>
        """
        let years = DocumentYearExtractor.extract(fromXML: Data(xml.utf8))
        #expect(years == ["d1": 1946, "d3": 1907])
    }
}

// MARK: - ExportRecordTests

/// Verifies record construction per strategy against synthetic bundled artifacts.
struct ExportRecordTests {

    /// A minimal central-files index: one clean lot, one flagged lot, one numerical roll.
    private func fixtureCentralFiles() throws -> (CentralFilesIndexGeneratorCore.CentralFilesIndex, URL) {
        let json = """
        {
          "schemaVersion": 1, "generated": "2026-07-17",
          "numericalFile": {
            "seriesNaId": "654171", "microfilm": "M862",
            "rolls": [
              { "naId": "19779414", "title": "Numerical File: 600-720", "caseStart": 600,
                "caseEnd": 720, "catalogURL": "https://catalog.archives.gov/id/19779414" }
            ]
          },
          "countrySeries": [],
          "lotFiles": [
            { "lotNumber": "64D199", "recordGroup": "RG 59", "naId": "1000",
              "title": "Conference Files, 1949-1963", "catalogURL": "https://catalog.archives.gov/id/1000",
              "matchType": "control" },
            { "lotNumber": "32D66", "recordGroup": "RG 59", "naId": "9999",
              "title": "Ford Library staff file", "catalogURL": "https://catalog.archives.gov/id/9999",
              "matchType": "control", "ancestryLacksRecordGroup": true }
          ]
        }
        """
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cfi-\(UUID().uuidString).json")
        try Data(json.utf8).write(to: url)
        let index = try JSONDecoder().decode(
            CentralFilesIndexGeneratorCore.CentralFilesIndex.self, from: Data(json.utf8))
        return (index, url)
    }

    private func fixtureVolumeSources() throws -> VolumeSourcesIndex {
        let json = """
        {
          "schemaVersion": 2, "generated": "2026-07-17",
          "recordGroups": {
            "59": { "naId": "302021", "catalogURL": "https://catalog.archives.gov/id/302021",
                    "title": "General Records of the Department of State", "recordGroup": "59",
                    "matchType": "manual" }
          },
          "lots": {
            "70D48": { "naId": "3000", "catalogURL": "https://catalog.archives.gov/id/3000",
                       "title": "Subject Files of the Office of X", "recordGroup": "59",
                       "matchType": "api" }
          },
          "majorCollections": []
        }
        """
        return try JSONDecoder().decode(VolumeSourcesIndex.self, from: Data(json.utf8))
    }

    private func makeRecord(note: String, year: Int?) throws -> SourceExplorerExportRecord {
        let (centralFiles, url) = try fixtureCentralFiles()
        defer { try? FileManager.default.removeItem(at: url) }
        let lotResolver = try BundledLotResolver(indexURL: url)
        return SourceExplorerExportRunner.exportRecord(
            volumeId: "frusTEST", documentId: "d1", rawNote: note, documentYear: year,
            parser: SourceNoteParser(), lotResolver: lotResolver, centralFiles: centralFiles,
            volumeSources: try fixtureVolumeSources(),
            authority: AuthorityLookup(collections: []))
    }

    @Test("a clean lot resolves through the bundle → resolvedLotBundle")
    func lotResolves() throws {
        let record = try makeRecord(
            note: "Department of State, Conference Files: Lot 64 D 199, CF 100.", year: 1961)
        #expect(record.strategy == "lotFile")
        #expect(record.resolution.lotBundle?.naId == "1000")
        #expect(record.resolution.lotBundleMiss == nil)
        #expect(record.offlineOutcome == "resolvedLotBundle")
        #expect(record.derived.lotFileNorm == "64D199")
    }

    @Test("a flagged lot is excluded by the #321 guard and says why")
    func flaggedLotExcluded() throws {
        let record = try makeRecord(
            note: "Department of State, Staff Files: Lot 32 D 66, Box 1.", year: 1975)
        #expect(record.resolution.lotBundle == nil)
        #expect(record.resolution.lotBundleMiss == "flaggedAncestryLacksRecordGroup")
        // Still live-queryable (lotFile has a catalog route), so the outcome is liveRouteOnly.
        #expect(record.offlineOutcome == "liveRouteOnly")
    }

    @Test("an unknown lot reports notInBundle")
    func unknownLot() throws {
        let record = try makeRecord(
            note: "Department of State, Files: Lot 99 D 999.", year: 1960)
        #expect(record.resolution.lotBundleMiss == "notInBundle")
    }

    @Test("a File No. citation in the 1906–1910 window resolves numerical rolls")
    func numericalFileResolves() throws {
        let record = try makeRecord(note: "File No. 697/43.", year: 1907)
        #expect(record.strategy == "centralDecimalFile")
        #expect(record.resolution.numericalFileRolls?.first?.naId == "19779414")
        #expect(record.offlineOutcome == "resolvedNumericalFile")
    }

    @Test("a File No. outside roll coverage reports the gap")
    func numericalCoverageGap() throws {
        let record = try makeRecord(note: "File No. 5000/1.", year: 1908)
        #expect(record.resolution.numericalFileRolls == nil)
        #expect(record.resolution.numericalFileCoverageGap == true)
    }

    @Test("a File No. outside the year window never consults the rolls")
    func numericalYearGate() throws {
        let record = try makeRecord(note: "File No. 697/43.", year: 1912)
        #expect(record.resolution.numericalFileRolls == nil)
        #expect(record.resolution.numericalFileCoverageGap == nil)
    }

    @Test("volume-sources resolves a lot the central-files bundle misses")
    func volumeSourcesLot() throws {
        let record = try makeRecord(
            note: "Department of State, Subject Files: Lot 70 D 48.", year: 1969)
        #expect(record.resolution.lotBundleMiss == "notInBundle")
        #expect(record.resolution.volumeSources?.naId == "3000")
        #expect(record.resolution.volumeSourcesKey == "lot:70D48")
        #expect(record.offlineOutcome == "resolvedVolumeSources")
    }

    @Test("a bare decimal citation resolves RG 59 through volume-sources")
    func centralFilesRG() throws {
        // The era-2 stored shape: the note STARTS with the citation (the decimal grammar is
        // ^-anchored). En-dash in "2–1548" per the FRUS convention.
        let record = try makeRecord(note: "611.61/2–1548.", year: 1948)
        #expect(record.strategy == "centralDecimalFile")
        #expect(record.parsed.kind == "centralFiles")
        #expect(record.resolution.volumeSourcesKey == "rg:59")
        #expect(record.derived.decimalClass == "611.61")
    }

    @Test("PINNED QUIRK: a prefixed, unlabeled central-files note classifies as namedFileSeries")
    func prefixedCentralFilesQuirk() throws {
        // "Department of State, Central Files, 611.61/2–1548." — no "Source:" prefix (so the
        // narrative path never runs) and the ^-anchored decimal grammar cannot match past the
        // prefix, so the parser lands on .namedFileSeries. This pins the app's CURRENT
        // behavior for the #335 export/audit; if a grammar improvement reclassifies these,
        // this test should be updated alongside the audit baseline.
        let record = try makeRecord(
            note: "Department of State, Central Files, 611.61/2–1548.", year: 1948)
        #expect(record.strategy == "namedFileSeries")
    }

    @Test("an unrecognized note has no route and no resolution")
    func unrecognizedNote() throws {
        let record = try makeRecord(note: "A note the grammar has never met.", year: nil)
        #expect(record.strategy == "unrecognized")
        #expect(record.resolution.liveLookupRoute == "noCatalogRoute")
        #expect(record.offlineOutcome == "noResolution")
    }
}

// MARK: - RunnerEndToEndTests

/// End-to-end run over a synthetic two-volume corpus: record content, summary counts,
/// sample stride, and byte-stable determinism.
struct RunnerEndToEndTests {

    /// Builds a corpus dir + bundled artifacts + manifest in a temp sandbox.
    private func makeSandbox() throws -> (volumes: URL, manifest: String, cfi: String,
                                          vsi: String, authority: String, out: URL, root: URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("se-export-\(UUID().uuidString)", isDirectory: true)
        let volumes = root.appendingPathComponent("volumes", isDirectory: true)
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)

        let vol1 = """
        <TEI xmlns:frus="http://history.state.gov/frus/ns/1.0">
          <div type="document" xml:id="d1" frus:doc-dateTime-min="1961-06-03T00:00:00">
            <note type="source">Department of State, Conference Files: Lot 64 D 199, CF 100. Secret.</note>
            <p>Body.</p>
          </div>
          <div type="document" xml:id="d2" frus:doc-dateTime-min="1961-07-01T00:00:00">
            <note type="source">A note the grammar has never met.</note>
          </div>
        </TEI>
        """
        let vol2 = """
        <TEI xmlns:frus="http://history.state.gov/frus/ns/1.0">
          <div type="document" xml:id="d1" frus:doc-dateTime-min="1907-11-20T00:00:00">
            <note type="source">File No. 697/43.</note>
          </div>
        </TEI>
        """
        try Data(vol1.utf8).write(to: volumes.appendingPathComponent("frusTESTa.xml"))
        try Data(vol2.utf8).write(to: volumes.appendingPathComponent("frusTESTb.xml"))
        // A corpus volume OUTSIDE the manifest, which must be skipped.
        try Data(vol2.utf8).write(to: volumes.appendingPathComponent("frusOUTSIDE.xml"))

        let manifest = root.appendingPathComponent("manifest.json")
        try Data("""
        [{"volumeId":"frusTESTa"},{"volumeId":"frusTESTb"}]
        """.utf8).write(to: manifest)

        let cfi = root.appendingPathComponent("central-files-index.json")
        try Data("""
        {
          "schemaVersion": 1, "generated": "2026-07-17",
          "numericalFile": { "seriesNaId": "654171", "microfilm": "M862", "rolls": [
            { "naId": "19779414", "title": "Numerical File: 600-720", "caseStart": 600,
              "caseEnd": 720, "catalogURL": "https://catalog.archives.gov/id/19779414" } ] },
          "countrySeries": [],
          "lotFiles": [
            { "lotNumber": "64D199", "recordGroup": "RG 59", "naId": "1000",
              "title": "Conference Files, 1949-1963",
              "catalogURL": "https://catalog.archives.gov/id/1000", "matchType": "control" } ]
        }
        """.utf8).write(to: cfi)

        let vsi = root.appendingPathComponent("volume-sources-index.json")
        try Data("""
        { "schemaVersion": 2, "generated": "2026-07-17",
          "recordGroups": {}, "lots": {}, "majorCollections": [] }
        """.utf8).write(to: vsi)

        let authority = root.appendingPathComponent("collection-authority.json")
        try Data("""
        { "schemaVersion": 1, "generated": "2026-07-17", "collections": [] }
        """.utf8).write(to: authority)

        return (volumes, manifest.path, cfi.path, vsi.path, authority.path,
                root.appendingPathComponent("out", isDirectory: true), root)
    }

    private func runOnce(_ sandbox: (volumes: URL, manifest: String, cfi: String,
                                     vsi: String, authority: String, out: URL, root: URL)) throws {
        try SourceExplorerExportRunner.run(
            volumesDir: sandbox.volumes, manifestPath: sandbox.manifest,
            centralFilesIndexPath: sandbox.cfi, volumeSourcesIndexPath: sandbox.vsi,
            collectionAuthorityPath: sandbox.authority,
            outputDir: sandbox.out, generated: "2026-07-17")
    }

    @Test("end-to-end: records, summary counts, manifest filter, valid JSON")
    func endToEnd() throws {
        let sandbox = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: sandbox.root) }
        try runOnce(sandbox)

        let exportData = try Data(contentsOf: sandbox.out
            .appendingPathComponent("source-explorer-export.json"))
        struct Export: Decodable {
            let schemaVersion: Int
            let generated: String
            let records: [SourceExplorerExportRecord]
        }
        let export = try JSONDecoder().decode(Export.self, from: exportData)
        #expect(export.records.count == 3)
        #expect(export.records.map(\.id).sorted()
                == ["frusTESTa/d1", "frusTESTa/d2", "frusTESTb/d1"])
        let lot = export.records.first { $0.id == "frusTESTa/d1" }
        #expect(lot?.offlineOutcome == "resolvedLotBundle")
        #expect(lot?.documentYear == 1961)
        #expect(lot?.derived.classificationMarking == "Secret")
        let numerical = export.records.first { $0.id == "frusTESTb/d1" }
        #expect(numerical?.offlineOutcome == "resolvedNumericalFile")

        let summaryData = try Data(contentsOf: sandbox.out
            .appendingPathComponent("source-explorer-export-summary.json"))
        let summary = try JSONDecoder().decode(SourceExplorerExportSummary.self, from: summaryData)
        #expect(summary.recordCount == 3)
        #expect(summary.volumeCount == 2)
        #expect(summary.volumesOutsideManifest == 1)
        #expect(summary.byStrategy["lotFile"] == 1)
        #expect(summary.byStrategy["unrecognized"] == 1)
        #expect(summary.byOutcome["resolvedLotBundle"] == 1)
        #expect(summary.byDecade["1960"] == 2)
        #expect(summary.byDecade["1900"] == 1)

        // Sample: stride 200 over 3 records → exactly the first record.
        let sampleData = try Data(contentsOf: sandbox.out
            .appendingPathComponent("source-explorer-export-sample.json"))
        let sample = try JSONDecoder().decode([SourceExplorerExportRecord].self, from: sampleData)
        #expect(sample.count == 1)
    }

    @Test("byte-stable determinism across runs")
    func deterministic() throws {
        let sandbox = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: sandbox.root) }
        try runOnce(sandbox)
        let first = try Data(contentsOf: sandbox.out
            .appendingPathComponent("source-explorer-export.json"))
        let firstSummary = try Data(contentsOf: sandbox.out
            .appendingPathComponent("source-explorer-export-summary.json"))
        try runOnce(sandbox)
        #expect(try Data(contentsOf: sandbox.out
            .appendingPathComponent("source-explorer-export.json")) == first)
        #expect(try Data(contentsOf: sandbox.out
            .appendingPathComponent("source-explorer-export-summary.json")) == firstSummary)
    }
}
