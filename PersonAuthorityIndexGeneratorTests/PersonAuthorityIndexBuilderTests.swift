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
}
