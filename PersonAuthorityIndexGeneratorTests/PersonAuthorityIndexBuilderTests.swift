// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import PersonAuthorityIndexGeneratorCore

// MARK: - PersonAuthorityIndexBuilderTests

struct PersonAuthorityIndexBuilderTests {

    @Test("parseAnchor decodes a FRUS persons-page source URL into (volume, ref)")
    func parseAnchorDecodes() {
        let a = PersonAuthorityIndexBuilder.parseAnchor(
            "https://history.state.gov/historicaldocuments/frus1961-63v14/persons#p_KHA1")
        #expect(a?.volumeId == "frus1961-63v14")
        #expect(a?.ref == "p_KHA1")
    }

    @Test("parseAnchor ignores non-FRUS and non-persons source URLs")
    func parseAnchorIgnoresOthers() {
        #expect(PersonAuthorityIndexBuilder.parseAnchor(
            "https://history.state.gov/departmenthistory/people/aaron-david-laurence") == nil)
        #expect(PersonAuthorityIndexBuilder.parseAnchor(
            "https://history.state.gov/departmenthistory/visits") == nil)
    }

    @Test("parseRecord extracts canonical id, name, years, VIAF, and all FRUS anchors")
    func parseRecordExtractsEverything() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <person>
            <id>107252</id>
            <authorities><authority service="viaf">12345678</authority></authorities>
            <names>
                <preferred><name>Kissinger, Henry A.</name></preferred>
                <originals variants="2">
                    <original>
                        <name>Kissinger, Henry A.</name>
                        <source-url>https://history.state.gov/historicaldocuments/frus1961-63v14/persons#p_KHA1</source-url>
                    </original>
                    <original>
                        <name>Kissinger, Henry</name>
                        <source-url>https://history.state.gov/historicaldocuments/frus1969-76v40/persons#p_HK_1</source-url>
                        <source-url>https://history.state.gov/departmenthistory/people/kissinger-henry-alfred</source-url>
                    </original>
                </originals>
            </names>
            <birth-year>1923</birth-year>
            <death-year/>
        </person>
        """
        let record = try #require(try PersonAuthorityIndexBuilder.parseRecord(xml: xml))
        #expect(record.canonicalId == 107252)
        #expect(record.name == "Kissinger, Henry A.")
        #expect(record.birthYear == 1923)
        #expect(record.deathYear == nil)
        #expect(record.viaf == "12345678")
        // Only the two FRUS anchors are kept (the departmenthistory URL is dropped).
        #expect(record.frusAnchors.count == 2)
        #expect(record.frusAnchors.contains(FRUSAnchor(volumeId: "frus1961-63v14", ref: "p_KHA1")))
        #expect(record.frusAnchors.contains(FRUSAnchor(volumeId: "frus1969-76v40", ref: "p_HK_1")))
    }

    @Test("parseRecord returns nil for records with no FRUS anchors")
    func parseRecordSkipsNonFRUS() throws {
        let xml = """
        <person><id>200000</id>
            <names><preferred><name>Visitor, Only</name></preferred></names>
            <birth-year/><death-year/>
            <remarks><remark><source-url>https://history.state.gov/departmenthistory/visits</source-url></remark></remarks>
        </person>
        """
        #expect(try PersonAuthorityIndexBuilder.parseRecord(xml: xml) == nil)
    }

    @Test("build aggregates records under a directory into a crosswalk + authority index")
    func buildAggregates() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("paig-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        try """
        <person><id>107252</id>
          <names><preferred><name>Kissinger, Henry A.</name></preferred></names>
          <birth-year>1923</birth-year><death-year/>
          <names><originals><original>
            <source-url>https://history.state.gov/historicaldocuments/frus1961-63v14/persons#p_KHA1</source-url>
            <source-url>https://history.state.gov/historicaldocuments/frus1969-76v40/persons#p_HK_1</source-url>
          </original></originals></names>
        </person>
        """.write(to: dir.appendingPathComponent("107252.xml"), atomically: true, encoding: .utf8)

        try """
        <person><id>100001</id>
          <names><preferred><name>Aaron, David Laurence</name></preferred></names>
          <birth-year>1938</birth-year><death-year/>
          <names><originals><original>
            <source-url>https://history.state.gov/historicaldocuments/frus1969-76v22/persons#p_AD_1</source-url>
          </original></originals></names>
        </person>
        """.write(to: dir.appendingPathComponent("100001.xml"), atomically: true, encoding: .utf8)

        let (index, stats) = try PersonAuthorityIndexBuilder.build(
            dataDirectory: dir, version: 1, generated: "2026-06-18", source: "test")

        #expect(stats.recordsWithFRUSAnchors == 2)
        #expect(stats.crosswalkEntries == 3)
        #expect(stats.distinctVolumes == 3)
        #expect(index.crosswalk["frus1961-63v14"]?["p_KHA1"] == 107252)
        #expect(index.crosswalk["frus1969-76v40"]?["p_HK_1"] == 107252)
        #expect(index.crosswalk["frus1969-76v22"]?["p_AD_1"] == 100001)
        #expect(index.authority["107252"]?.n == "Kissinger, Henry A.")
        #expect(index.authority["107252"]?.b == 1923)
    }

    @Test("build honours keepVolume to restrict the crosswalk")
    func buildRestrictsByVolume() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("paig-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try """
        <person><id>1</id><names><preferred><name>X</name></preferred></names>
          <names><originals><original>
            <source-url>https://history.state.gov/historicaldocuments/frusKEEP/persons#p_1</source-url>
            <source-url>https://history.state.gov/historicaldocuments/frusDROP/persons#p_2</source-url>
          </original></originals></names>
        </person>
        """.write(to: dir.appendingPathComponent("1.xml"), atomically: true, encoding: .utf8)

        let (index, _) = try PersonAuthorityIndexBuilder.build(
            dataDirectory: dir, version: 1, generated: "2026-06-18", source: "test",
            keepVolume: { $0 == "frusKEEP" })
        #expect(index.crosswalk["frusKEEP"]?["p_1"] == 1)
        #expect(index.crosswalk["frusDROP"] == nil)
    }

    // MARK: - Schema v2: POCOM slug (#736)

    @Test("A departmenthistory source-url yields the POCOM slug the old builder discarded")
    func capturesPOCOMSlug() {
        #expect(PersonAuthorityIndexBuilder.parsePOCOMSlug(
            "https://history.state.gov/departmenthistory/people/acheson-dean-gooderham")
                == "acheson-dean-gooderham")
        #expect(PersonAuthorityIndexBuilder.parsePOCOMSlug(
            "https://history.state.gov/historicaldocuments/frus1952-54v01/persons#p_AD1") == nil,
                "a FRUS anchor is not a POCOM slug")
        #expect(PersonAuthorityIndexBuilder.parsePOCOMSlug("") == nil)
    }

    // MARK: - Schema v2: the overlay (#736 / #260)

    /// A registry index with two people and one anchor each.
    private func baseIndex() -> (crosswalk: [String: [String: Int]],
                                 authority: [String: AuthorityEntry]) {
        (["frus1952-54v01": ["p_A1": 100001]],
         ["100001": AuthorityEntry(n: "Acheson, Dean", b: 1893, d: 1971, v: nil),
          "100002": AuthorityEntry(n: "Bohlen, Charles", b: 1904, d: 1974, v: "12345")])
    }

    @Test("The overlay fills empty identifier fields and adds new anchors")
    func overlayEnrichesAndExpands() throws {
        var (crosswalk, authority) = baseIndex()
        var stats = BuildStats()
        let entry = PersonsCompleteOverlay.parseEntry("""
            <person xml:id="FRUS-1"><idno type="people-id">100001</idno>
            <idno type="wikidata">Q193236</idno><idno type="viaf">99887</idno>
            <occupation>Secretary of State</occupation>
            <idno type="frus-ref">frus1955-57v02/persons#p_AD2</idno></person>
            """)
        PersonAuthorityIndexBuilder.applyOverlay(
            .init(entries: [entry], flaggedPeopleIds: ["999"]),
            crosswalk: &crosswalk, authority: &authority, keepVolume: nil, stats: &stats)

        let enriched = try #require(authority["100001"])
        #expect(enriched.q == "Q193236")
        #expect(enriched.v == "99887")
        #expect(enriched.r == "Secretary of State")
        #expect(crosswalk["frus1955-57v02"]?["p_AD2"] == 100001)
        #expect(stats.crosswalkPairsAdded == 1)
        #expect(stats.crosswalkVolumesAdded == 1)
    }

    @Test("The registry keeps a value it already has — the overlay only fills gaps")
    func registryWinsOnEnrichment() throws {
        // The overlay is a different pipeline carrying 1,662 unreviewed auto-merges. It must not
        // overwrite an id the reconciled registry asserted.
        var (crosswalk, authority) = baseIndex()
        var stats = BuildStats()
        let entry = PersonsCompleteOverlay.parseEntry("""
            <person xml:id="FRUS-2"><idno type="people-id">100002</idno>
            <idno type="viaf">SHOULD-NOT-WIN</idno></person>
            """)
        PersonAuthorityIndexBuilder.applyOverlay(
            .init(entries: [entry], flaggedPeopleIds: []),
            crosswalk: &crosswalk, authority: &authority, keepVolume: nil, stats: &stats)
        #expect(try #require(authority["100002"]).v == "12345")
    }

    @Test("A conflicting anchor is recorded and the registry's id is kept")
    func conflictingAnchorRecorded() {
        var (crosswalk, authority) = baseIndex()
        var stats = BuildStats()
        let entry = PersonsCompleteOverlay.parseEntry("""
            <person xml:id="FRUS-3"><idno type="people-id">100002</idno>
            <idno type="frus-ref">frus1952-54v01/persons#p_A1</idno></person>
            """)
        PersonAuthorityIndexBuilder.applyOverlay(
            .init(entries: [entry], flaggedPeopleIds: []),
            crosswalk: &crosswalk, authority: &authority, keepVolume: nil, stats: &stats)
        #expect(crosswalk["frus1952-54v01"]?["p_A1"] == 100001, "registry wins")
        #expect(stats.crosswalkConflicts.count == 1)
        #expect(stats.crosswalkConflicts.first?.overlay == "100002")
        #expect(stats.crosswalkPairsAdded == 0)
    }

    @Test("An audit-flagged entry contributes neither identifiers nor anchors")
    func flaggedEntryContributesNothing() throws {
        // Both halves matter: its identifiers would land on the wrong person, and its anchors
        // would key a FRUS person to a merged identity a human review rejected.
        var (crosswalk, authority) = baseIndex()
        var stats = BuildStats()
        let entry = PersonsCompleteOverlay.parseEntry("""
            <person xml:id="FRUS-4"><idno type="people-id">100001</idno>
            <idno type="wikidata">Q-WRONG</idno>
            <idno type="frus-ref">frus1958-60v03/persons#p_XX1</idno></person>
            """)
        PersonAuthorityIndexBuilder.applyOverlay(
            .init(entries: [entry], flaggedPeopleIds: ["100001"]),
            crosswalk: &crosswalk, authority: &authority, keepVolume: nil, stats: &stats)
        #expect(try #require(authority["100001"]).q == nil)
        #expect(crosswalk["frus1958-60v03"] == nil)
        #expect(stats.overlayEntriesSkippedByAudit == 1)
    }

    @Test("A flagged SECONDARY people-id still disqualifies the whole entry")
    func flaggedSecondaryIdDisqualifies() throws {
        var (crosswalk, authority) = baseIndex()
        var stats = BuildStats()
        let entry = PersonsCompleteOverlay.parseEntry("""
            <person xml:id="FRUS-5"><idno type="people-id">100001</idno>
            <idno type="people-id">100002</idno><idno type="wikidata">Q-WRONG</idno></person>
            """)
        PersonAuthorityIndexBuilder.applyOverlay(
            .init(entries: [entry], flaggedPeopleIds: ["100002"]),
            crosswalk: &crosswalk, authority: &authority, keepVolume: nil, stats: &stats)
        #expect(try #require(authority["100001"]).q == nil,
                "the flag is on the merge, so no id in it may be trusted")
    }

    @Test("An anchor whose people-id the registry does not know is dropped and counted")
    func unknownIdAnchorDropped() {
        var (crosswalk, authority) = baseIndex()
        var stats = BuildStats()
        let entry = PersonsCompleteOverlay.parseEntry("""
            <person xml:id="FRUS-6"><idno type="people-id">777777</idno>
            <idno type="frus-ref">frus1961-63v01/persons#p_ZZ1</idno></person>
            """)
        PersonAuthorityIndexBuilder.applyOverlay(
            .init(entries: [entry], flaggedPeopleIds: []),
            crosswalk: &crosswalk, authority: &authority, keepVolume: nil, stats: &stats)
        #expect(crosswalk["frus1961-63v01"] == nil,
                "an anchor resolving to a person the app cannot name is worse than no anchor")
        #expect(stats.unknownOverlayIds.contains("777777"))
    }

    @Test("keepVolume applies to overlay anchors too")
    func overlayHonoursKeepVolume() {
        var (crosswalk, authority) = baseIndex()
        var stats = BuildStats()
        let entry = PersonsCompleteOverlay.parseEntry("""
            <person xml:id="FRUS-7"><idno type="people-id">100001</idno>
            <idno type="frus-ref">frus1899/persons#p_Q1</idno></person>
            """)
        PersonAuthorityIndexBuilder.applyOverlay(
            .init(entries: [entry], flaggedPeopleIds: []),
            crosswalk: &crosswalk, authority: &authority,
            keepVolume: { $0 == "frus1952-54v01" }, stats: &stats)
        #expect(crosswalk["frus1899"] == nil, "a volume the app does not ship gains no anchor")
    }

    @Test("Role text is truncated to the bundle-size budget")
    func roleTextTruncated() throws {
        var (crosswalk, authority) = baseIndex()
        var stats = BuildStats()
        let long = String(repeating: "x", count: 400)
        let entry = PersonsCompleteOverlay.parseEntry("""
            <person xml:id="FRUS-8"><idno type="people-id">100001</idno>
            <occupation>\(long)</occupation></person>
            """)
        PersonAuthorityIndexBuilder.applyOverlay(
            .init(entries: [entry], flaggedPeopleIds: [], roleCharacterLimit: 40),
            crosswalk: &crosswalk, authority: &authority, keepVolume: nil, stats: &stats)
        #expect(try #require(authority["100001"]).r?.count == 40)
    }
}
