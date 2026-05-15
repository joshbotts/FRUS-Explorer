// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
@testable import ManifestGeneratorCore

/// Tests for `VolumeIDParser`.
///
/// Each test covers a distinct filename pattern observed in the HistoryAtState/frus repository.
struct VolumeIDParserTests {

    // MARK: - Recognised Patterns

    @Test("Standard year-range volume: frus1969-76v01.xml")
    func standardYearRangeVolume() {
        let result = VolumeIDParser.parse(filename: "frus1969-76v01.xml")
        #expect(result?.volumeId == "frus1969-76v01")
        #expect(result?.subseries == "1969-76")
    }

    @Test("Four-digit year-range: frus1993-2000v01.xml")
    func fourDigitYearRange() {
        let result = VolumeIDParser.parse(filename: "frus1993-2000v01.xml")
        #expect(result?.volumeId == "frus1993-2000v01")
        #expect(result?.subseries == "1993-2000")
    }

    @Test("Single-year early volume: frus1861.xml")
    func singleYearEarlyVolume() {
        let result = VolumeIDParser.parse(filename: "frus1861.xml")
        #expect(result?.volumeId == "frus1861")
        #expect(result?.subseries == "1861")
    }

    @Test("Sub-series letter suffix: frus1952-54Gv01.xml")
    func subSeriesLetterSuffix() {
        let result = VolumeIDParser.parse(filename: "frus1952-54Gv01.xml")
        #expect(result?.volumeId == "frus1952-54Gv01")
        #expect(result?.subseries == "1952-54G")
    }

    @Test("Part number: frus1952-54v06p2.xml")
    func partNumber() {
        let result = VolumeIDParser.parse(filename: "frus1952-54v06p2.xml")
        #expect(result?.volumeId == "frus1952-54v06p2")
        #expect(result?.subseries == "1952-54")
    }

    @Test("Supplement: frus1969-76v01sups.xml")
    func supplement() {
        let result = VolumeIDParser.parse(filename: "frus1969-76v01sups.xml")
        #expect(result?.volumeId == "frus1969-76v01sups")
        #expect(result?.subseries == "1969-76")
    }

    @Test("Appendix: frus1861app.xml")
    func appendix() {
        let result = VolumeIDParser.parse(filename: "frus1861app.xml")
        #expect(result?.volumeId == "frus1861app")
        #expect(result?.subseries == "1861")
    }

    @Test("Microfiche: frus1977-80v03mf.xml")
    func microfiche() {
        let result = VolumeIDParser.parse(filename: "frus1977-80v03mf.xml")
        #expect(result?.volumeId == "frus1977-80v03mf")
        #expect(result?.subseries == "1977-80")
    }

    @Test("Special topic suffix: frus1894China.xml")
    func specialTopicSuffix() {
        let result = VolumeIDParser.parse(filename: "frus1894China.xml")
        #expect(result?.volumeId == "frus1894China")
        #expect(result?.subseries == "1894China")
    }

    @Test("Recent volume: frus2011-12v02.xml")
    func recentVolume() {
        let result = VolumeIDParser.parse(filename: "frus2011-12v02.xml")
        #expect(result?.volumeId == "frus2011-12v02")
        #expect(result?.subseries == "2011-12")
    }

    // MARK: - Unrecognised / Invalid Inputs

    @Test("Non-frus file returns nil")
    func nonFrusFile() {
        #expect(VolumeIDParser.parse(filename: "readme.md") == nil)
        #expect(VolumeIDParser.parse(filename: "manifest.json") == nil)
    }

    @Test("Non-XML extension returns nil")
    func nonXMLExtension() {
        #expect(VolumeIDParser.parse(filename: "frus1969-76v01.txt") == nil)
    }

    @Test("Bare frus prefix with no content returns nil")
    func bareFrusPrefix() {
        #expect(VolumeIDParser.parse(filename: "frus.xml") == nil)
    }
}
