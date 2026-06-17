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

/// Tests for per-series geo + date extraction, using real catalog titles from the survey.
struct CountrySeriesParserTests {

    // MARK: Despatches (geo from parent file-unit title)

    @Test("Despatches: extracts country from the parent file-unit title")
    func despatchesCountry() {
        let f = CountrySeriesParser.despatchesCountryKeys(fromParent:)
        #expect(f("Despatches from U.S. Ministers to Switzerland, 1853-1906") == ["switzerland"])
        #expect(f("Despatches from U.S. Ministers to the Dominican Republic, 1883-1906") == ["dominican republic"])
        #expect(f("Despatches from U.S. Ministers to the Italian States, 1832-1906") == ["italian states"])
        #expect(f("Despatches from U.S Ministers to China, 1843-1906") == ["china"])  // missing period
        #expect(f("Despatches from Diplomatic Officers, Haiti") == ["haiti"])
        #expect(f("Despatches from U.S. Ministers to Argentina") == ["argentina"])   // no date suffix
        #expect(f("Despatches from U.S. Ministers to Paraguay and Uruguay, 1853-1906") == ["paraguay", "uruguay"])
    }

    @Test("Despatches: parses geo + date for an item under a country file unit")
    func despatchesItem() throws {
        let record = CatalogRecord(
            naId: "188401761", title: "Mar. 4, 1905-Aug. 31, 1905",
            levelOfDescription: "item",
            parentFileUnitNaId: "5716479",
            parentFileUnitTitle: "Despatches from U.S. Ministers to Japan, 1855-1906")
        let parsed = try #require(CountrySeriesParser.parse(record, category: .despatches))
        #expect(parsed.geoKeys == ["japan"])
        #expect(parsed.dateRange?.startISO == "1905-03-04")
        #expect(parsed.dateRange?.endISO == "1905-08-31")
    }

    // MARK: Instructions (geo + dates from own fileUnit title)

    @Test("Instructions: parses Volume/Country/dates from the file-unit title")
    func instructionsFileUnit() throws {
        let record = CatalogRecord(
            naId: "149311973",
            title: "Volume 18: Great Britain: Aug. 17, 1861 - Sept. 2, 1863",
            levelOfDescription: "fileUnit")
        let parsed = try #require(CountrySeriesParser.parse(record, category: .instructions))
        #expect(parsed.geoKeys == ["great britain"])
        #expect(parsed.dateRange?.startISO == "1861-08-17")
        #expect(parsed.dateRange?.endISO == "1863-09-02")
    }

    @Test("Instructions: country-less early volume yields dates but no geo")
    func instructionsEarlyVolume() throws {
        let record = CatalogRecord(
            naId: "x", title: "Volume 4: February 1, 1797 - November 30, 1798",
            levelOfDescription: "fileUnit")
        let parsed = try #require(CountrySeriesParser.parse(record, category: .instructions))
        #expect(parsed.geoKeys.isEmpty)
        #expect(parsed.dateRange?.startISO == "1797-02-01")
    }

    // MARK: Notes from (geo from parent demonym)

    @Test("Notes from: extracts the country from the parent demonym/legation forms")
    func notesFromCountry() {
        let f = CountrySeriesParser.notesFromCountryKeys(fromParent:)
        #expect(f("T93 - Notes from the Venezuelan Legation in the United States to the Department of State, 1835-1906") == ["venezuela"])
        #expect(f("Notes from the Turkish Legation in the United States to the Department of State, 1867-1906") == ["turkey"])
        #expect(f("Notes from the Legation of the Dominican Republic in the United States to the Department of State, 1844-1906") == ["dominican republic"])
        #expect(f("Notes from the Legation of El Salvador in the United States to the Department of State, 1879-1906") == ["el salvador"])
        #expect(f("Notes from Central American Legations in the United States to the Department of State, 1823-1906") == ["central america"])
        #expect(f("Notes from Foreign Missions, China") == ["china"])
        #expect(f("Notes from Miscellaneous Foreign States to the Department of State, 1817-1906") == [])
    }

    // MARK: Notes to (geo + dates from own fileUnit title)

    @Test("Notes to: parses country and dates, splitting combined rolls")
    func notesToFileUnit() throws {
        let combined = CatalogRecord(
            naId: "216926854", title: "Uruguay and Paraguay: July 7, 1834 - June 26, 1906",
            levelOfDescription: "fileUnit")
        let parsed = try #require(CountrySeriesParser.parse(combined, category: .notesTo))
        #expect(parsed.geoKeys == ["uruguay", "paraguay"])
        #expect(parsed.dateRange?.startISO == "1834-07-07")
        #expect(parsed.dateRange?.endISO == "1906-06-26")
    }

    // MARK: Resolution level filtering

    @Test("Parse returns nil for a record at the wrong level for the series")
    func wrongLevelReturnsNil() {
        // Despatches resolve at item level; a fileUnit is not a target.
        let fu = CatalogRecord(naId: "x", title: "Despatches…", levelOfDescription: "fileUnit")
        #expect(CountrySeriesParser.parse(fu, category: .despatches) == nil)
        // Notes-to resolve at fileUnit level; an item is not a target.
        let item = CatalogRecord(naId: "y", title: "Venezuela: 1835", levelOfDescription: "item")
        #expect(CountrySeriesParser.parse(item, category: .notesTo) == nil)
    }
}
