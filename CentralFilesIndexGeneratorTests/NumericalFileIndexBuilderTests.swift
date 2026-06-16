// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import CentralFilesIndexGeneratorCore

/// Tests for building the Numerical File index from harvested records.
struct NumericalFileIndexBuilderTests {

    @Test("Builds rolls from matching records and derives catalog URLs")
    func buildsRolls() {
        let records = [
            CatalogRecord(naId: "19174810", title: "Numerical File: 682-699"),
            CatalogRecord(naId: "19779414", title: "Numerical File: 7179-7187"),
        ]
        let result = NumericalFileIndexBuilder.build(
            records: records, seriesNaId: "654171", microfilm: "M862")

        #expect(result.matchedRolls == 2)
        #expect(result.totalRecords == 2)
        #expect(result.unmatchedTitles.isEmpty)
        let first = result.index.rolls.first
        #expect(first?.naId == "19174810")
        #expect(first?.catalogURL == "https://catalog.archives.gov/id/19174810")
        // Golden lookups resolve through the built index.
        #expect(result.index.roll(forFileNumber: "7187")?.naId == "19779414")
    }

    @Test("Collects non-roll records as unmatched rather than dropping silently")
    func collectsUnmatched() {
        let records = [
            CatalogRecord(naId: "654171", title: "Numerical and Minor Files of the Department of State"),
            CatalogRecord(naId: "1", title: "M862 publication pamphlet"),
            CatalogRecord(naId: "19174810", title: "Numerical File: 682-699"),
        ]
        let result = NumericalFileIndexBuilder.build(
            records: records, seriesNaId: "654171", microfilm: "M862")

        #expect(result.matchedRolls == 1)
        #expect(result.unmatchedTitles.count == 2)
        #expect(result.unmatchedTitles.contains("M862 publication pamphlet"))
    }

    @Test("Detects coverage gaps between non-contiguous rolls")
    func detectsGaps() {
        let records = [
            CatalogRecord(naId: "a", title: "Numerical File: 1-99"),
            CatalogRecord(naId: "b", title: "Numerical File: 200-299"),  // gap 100–199
        ]
        let result = NumericalFileIndexBuilder.build(
            records: records, seriesNaId: "654171", microfilm: "M862")

        #expect(result.coverageGaps == [CaseCoverageGap(from: 100, to: 199)])
        #expect(result.overlaps.isEmpty)
    }

    @Test("Contiguous rolls produce no gaps")
    func contiguousNoGaps() {
        let records = [
            CatalogRecord(naId: "a", title: "Numerical File: 1-99"),
            CatalogRecord(naId: "b", title: "Numerical File: 100-199"),
        ]
        let result = NumericalFileIndexBuilder.build(
            records: records, seriesNaId: "654171", microfilm: "M862")
        #expect(result.coverageGaps.isEmpty)
        #expect(result.overlaps.isEmpty)
    }

    @Test("Detects overlapping case ranges")
    func detectsOverlaps() {
        let records = [
            CatalogRecord(naId: "a", title: "Numerical File: 1-150"),
            CatalogRecord(naId: "b", title: "Numerical File: 100-200"),  // overlaps 100–150
        ]
        let result = NumericalFileIndexBuilder.build(
            records: records, seriesNaId: "654171", microfilm: "M862")
        #expect(result.overlaps.count == 1)
        #expect(result.coverageGaps.isEmpty)
    }
}
