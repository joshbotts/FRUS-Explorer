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

    // MARK: Consular Despatches (geo = post city from parent file-unit title)

    @Test("Consular: extracts the post city from the parent file-unit title")
    func consularPostCity() {
        let f = CountrySeriesParser.consularPostKeys(fromParent:)
        // Real survey file-unit titles.
        #expect(f("Despatches from U.S. Consuls in San Jose, Costa Rica, 1852-1906") == ["san jose"])
        #expect(f("Despatches From U.S. Consuls in Clifton, Canada, 1864-1906") == ["clifton"])  // "From" variant
        #expect(f("Despatches from U.S. Consuls in Windsor, Nova Scotia, Canada, 1872-1906") == ["windsor"])
        #expect(f("Despatches from U.S. Consuls in Three Rivers, Canada, 1881-1906") == ["three rivers"])
        #expect(f("Despatches from U.S. Consuls in Havana, Cuba, 1783-1906") == ["havana"])
        // Agency-form variants: spelled-out "United States" and spaced "U. S." (real data).
        #expect(f("Despatches from United States Consuls in Havana, Cuba, 1783-1906") == ["havana"])
        #expect(f("Despatches from U. S. Consuls in Alicante, Spain, 1797-1899") == ["alicante"])
        // Parenthetical alternate spelling → both keys.
        #expect(f("Despatches from U.S. Consuls in Brusa (Brousa), Turkey, 1837-1840") == ["brusa", "brousa"])
        // Other real lead forms (the 9 edge cases found in the cache).
        #expect(f("Despatches from the U.S. Consuls in Antigua, 1794-1906") == ["antigua"])
        #expect(f("Despatches from Consular Officers, Canton, China") == ["canton"])
        #expect(f("Despatches from Consular Offices - Port au Prince") == ["port au prince"])
        #expect(f("Despatches from U.S. Consular Representatives in Puerto Rico, 1821-1899") == ["puerto rico"])
        #expect(f("Despatches from U.S. Consuls to Cape Gracias a Dios, Nicaragua, 1903-1906") == ["cape gracias a dios"])
        #expect(f("Despatches from U.S. Ministers to Cap Haitien, Haiti, 1797-1906") == ["cap haitien"])
        #expect(f("Despatches from Grenville, Canada, 1904-1906") == ["grenville"])
        #expect(f("Antwerp, June 30, 1805-December 31, 1863") == ["antwerp"])
    }

    @Test("Consular: parses geo + date for a roll under a post file unit")
    func consularRoll() throws {
        let record = CatalogRecord(
            naId: "211373468", title: "Despatches: April 1 - August 31, 1895",
            levelOfDescription: "item",
            parentFileUnitNaId: "196006797",
            parentFileUnitTitle: "Despatches from U.S. Consuls in Havana, Cuba, 1783-1906")
        let parsed = try #require(CountrySeriesParser.parse(record, category: .consularDespatches))
        #expect(parsed.geoKeys == ["havana"])
        #expect(parsed.dateRange?.startISO == "1895-04-01")
        #expect(parsed.dateRange?.endISO == "1895-08-31")
    }

    @Test("Consular: tolerates Volume-prefixed and annotated roll titles")
    func consularRollTitleVariants() throws {
        #expect(HistoricalDateParser.parse("Despatches: Volume 1: August 24, 1897 - August 14, 1906")?.startISO == "1897-08-24")
        #expect(HistoricalDateParser.parse("Despatches: Volume 1: June 22, 1872 - June 11, 1886 CHECK DATE")?.endISO == "1886-06-11")
    }

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

    /// The build-time OCR-mangled-date guard (NARA review 2026-07-17): a bound whose year is
    /// outside the plausible pre-1906 window (1780–1911) is dropped, so a stray case number
    /// parsed as a year cannot produce an inverted range that silently excludes the roll.
    @Test("plausibleDate drops out-of-window years, keeps valid pre-1906 dates")
    func plausibleDateFiltersMangledYears() {
        #expect(CountrySeriesIndexBuilder.plausibleDate("1596-08-31") == nil)  // "…August 31, 139"
        #expect(CountrySeriesIndexBuilder.plausibleDate("1318-11-01") == nil)  // "Nov. 1, 11186 -"
        #expect(CountrySeriesIndexBuilder.plausibleDate("1202-07-31") == nil)
        #expect(CountrySeriesIndexBuilder.plausibleDate("1783-01-01") == "1783-01-01")  // earliest real
        #expect(CountrySeriesIndexBuilder.plausibleDate("1906-05-31") == "1906-05-31")
        #expect(CountrySeriesIndexBuilder.plausibleDate(nil) == nil)
    }
}

// MARK: - Chronological runs (W-8 tail)

/// The three consular-tail series are single chronological runs resolved at FILE-UNIT
/// grain by date alone — every title form below is a REAL record from the offline
/// record-group harvest (rg_59.json, read 2026-08-27).
struct ChronologicalRunParserTests {

    private func parse(_ title: String,
                       category: CountrySeriesCategory) -> ParsedCountryRoll? {
        CountrySeriesParser.parse(
            CatalogRecord(naId: "1", title: title, levelOfDescription: "fileUnit"),
            category: category)
    }

    @Test("Notes from Foreign Consuls: bare Month D, YYYY ranges")
    func notesFromConsulsRange() throws {
        let parsed = try #require(parse("December 18, 1789 - December 31, 1826",
                                        category: .notesFromForeignConsuls))
        #expect(parsed.geoKeys.isEmpty)
        #expect(parsed.dateRange?.startISO == "1789-12-18")
        #expect(parsed.dateRange?.endISO == "1826-12-31")
    }

    @Test("Notes to Foreign Consuls: numeric M/D/YYYY ranges parse at full precision")
    func notesToConsulsNumericRange() throws {
        let parsed = try #require(parse("6/17/1853 - 1/31/1865",
                                        category: .notesToForeignConsuls))
        #expect(parsed.dateRange?.startISO == "1853-06-17")
        // The regression this form exists for: yearOnly used to flatten this to 1865-01-01,
        // silently excluding any date after January 1 from the volume's range.
        #expect(parsed.dateRange?.endISO == "1865-01-31")
    }

    @Test("Consular Instructions: a label before the colon is stripped")
    func consularInstructionsLabeled() throws {
        let parsed = try #require(parse("Instructions: October 12, 1801 - February 26, 1817",
                                        category: .consularInstructions))
        #expect(parsed.dateRange?.startISO == "1801-10-12")
        #expect(parsed.dateRange?.endISO == "1817-02-26")
    }

    @Test("Consular Instructions: the Volume-1 through-form yields an end-only bound")
    func consularInstructionsThroughForm() throws {
        let parsed = try #require(parse(
            #"Volume 1: "Despatches to Consuls," Pages 1-109: [through Sept. 1801]"#,
            category: .consularInstructions))
        // The date lives in the LAST colon segment; "through Sept. 1801" is an END bound
        // with an open start — everything up to September 1801 matches, nothing after.
        let range = try #require(parsed.dateRange)
        #expect(range.startISO == nil)
        #expect(range.endISO == "1801-09-01")
    }

    @Test("Chronological categories resolve only at fileUnit level")
    func wrongLevelRefused() {
        let item = CatalogRecord(naId: "1", title: "January 2, 1864 - December 31, 1864",
                                 levelOfDescription: "item")
        #expect(CountrySeriesParser.parse(item, category: .notesFromForeignConsuls) == nil)
    }

    @Test("matchesDate: date-only membership, geo never consulted")
    func dateOnlyMatch() {
        let roll = CountryRoll(naId: "40038222", title: "1/31/1865 - 9/29/1868",
                               geoKeys: [], startISO: "1865-01-31", endISO: "1868-09-29",
                               catalogURL: "https://catalog.archives.gov/id/40038222")
        #expect(roll.matchesDate("1866-01-15"))
        #expect(!roll.matchesDate("1864-12-31"))
        #expect(!roll.matchesDate("1868-09-30"))
        // The geo-keyed path REFUSES a geo-less roll — the reason matchesDate exists.
        #expect(!roll.matches(geoKey: "havana", dateISO: "1866-01-15"))
        // A roll with no bound at all never matches a dated query.
        let undated = CountryRoll(naId: "x", title: "?", geoKeys: [],
                                  startISO: nil, endISO: nil, catalogURL: "u")
        #expect(!undated.matchesDate("1866-01-15"))
    }

    @Test("rolls(containingDate:) filters a chronological series by date alone")
    func seriesDateOnlyLookup() {
        let series = CountrySeriesIndex(
            category: CountrySeriesCategory.notesFromForeignConsuls.rawValue,
            seriesNaId: "1076629", displayName: "Notes from Foreign Consuls",
            rolls: [
                CountryRoll(naId: "a", title: "1789-1826", geoKeys: [],
                            startISO: "1789-12-18", endISO: "1826-12-31", catalogURL: "u"),
                CountryRoll(naId: "b", title: "1864", geoKeys: [],
                            startISO: "1864-01-02", endISO: "1864-12-31", catalogURL: "u"),
            ])
        #expect(series.rolls(containingDate: "1864-06-01").map(\.naId) == ["b"])
        #expect(series.rolls(containingDate: "1850-01-01").isEmpty)
    }

    @Test("isChronologicalRun marks exactly the seven tail series")
    func chronologicalFlag() {
        let chronological = CountrySeriesCategory.allCases.filter(\.isChronologicalRun)
        #expect(Set(chronological) == [.consularInstructions, .notesToForeignConsuls,
                                       .notesFromForeignConsuls, .domesticLetters,
                                       .lettersReceived, .specialAgentsDespatches,
                                       .specialAgentsInstructions])
    }
}

/// The W-8 remainder's title grammars — every form below is a REAL record from the
/// offline harvest (rg_59.json, read 2026-08-27).
struct DomesticAndSpecialAgentParserTests {

    private func parse(_ title: String,
                       category: CountrySeriesCategory) -> ParsedCountryRoll? {
        CountrySeriesParser.parse(
            CatalogRecord(naId: "1", title: title, levelOfDescription: "fileUnit"),
            category: category)
    }

    @Test("Domestic Letters: the Volume/Dates label form")
    func domesticLettersLabelForm() throws {
        let parsed = try #require(parse("Volume: 1 - Dates: Dec 11, 1784-Nov 28, 1785",
                                        category: .domesticLetters))
        #expect(parsed.dateRange?.startISO == "1784-12-11")
        #expect(parsed.dateRange?.endISO == "1785-11-28")
        // The year-sharing variant: "Jan 2-Jun 26, 1794" gives the year on one side only.
        let shared = try #require(parse("Volume: 6 - Dates: Jan 2-Jun 26, 1794",
                                        category: .domesticLetters))
        #expect(shared.dateRange?.startISO == "1794-01-02")
        #expect(shared.dateRange?.endISO == "1794-06-26")
    }

    @Test("Letters Received: THRU and dash month spans close both bounds")
    func lettersReceivedMonthSpans() throws {
        let thru = try #require(parse("July THRU September 1814", category: .lettersReceived))
        #expect(thru.dateRange?.startISO == "1814-07-01")
        #expect(thru.dateRange?.endISO == "1814-09-30")
        // The dash variant shipped once as an OPEN-ENDED roll matching every later date —
        // the generic split needs digits on both sides and a bare month name has none.
        let dash = try #require(parse("January - February, 1793", category: .lettersReceived))
        #expect(dash.dateRange?.startISO == "1793-01-01")
        #expect(dash.dateRange?.endISO == "1793-02-29")
    }

    @Test("Letters Received: single-month volumes close to the month's end")
    func lettersReceivedSingleMonth() throws {
        let plain = try #require(parse("December 1817", category: .lettersReceived))
        #expect(plain.dateRange?.startISO == "1817-12-01")
        // An open start-only bound would match every later year.
        #expect(plain.dateRange?.endISO == "1817-12-31")
        let part = try #require(parse("August Part I, 1873", category: .lettersReceived))
        #expect(part.dateRange?.startISO == "1873-08-01")
        #expect(part.dateRange?.endISO == "1873-08-31")
    }

    @Test("Special Agents despatches: the volume's coverage is the span of every year named")
    func specialAgentYearSpan() throws {
        let parsed = try #require(parse(
            "Volume 12: Richard Rush: 1836-1838, Nathaniel Niles: 1841, Aaron Vail: 1838, Benjamin Tappan: 1840-1841, Albert Fitz: 1842; Volume 13: Duff Green: 1843-1845 and 1859-1860",
            category: .specialAgentsDespatches))
        // The generic last-colon rule would keep only the FINAL agent's years and lose the
        // rest — the span parse reads them all.
        #expect(parsed.dateRange?.startISO == "1836-01-01")
        #expect(parsed.dateRange?.endISO == "1860-12-31")
        // An agent row with no years at all yields no range (and the real one, "Edmund
        // Roberts", is undigitized and filtered before parsing anyway).
        let none = try #require(parse("Edmund Roberts", category: .specialAgentsDespatches))
        #expect(none.dateRange == nil)
    }

    @Test("Instructions to Special Agents ride the existing label-colon grammar")
    func specialAgentInstructions() throws {
        let parsed = try #require(parse(
            "Volume 3: Special Missions: Sept. 11, 1852 - Aug.  31,  1886",
            category: .specialAgentsInstructions))
        #expect(parsed.dateRange?.startISO == "1852-09-11")
        #expect(parsed.dateRange?.endISO == "1886-08-31")
    }

    @Test("All four new categories are chronological runs at fileUnit grain")
    func newCategoriesShape() {
        for c in [CountrySeriesCategory.domesticLetters, .lettersReceived,
                  .specialAgentsDespatches, .specialAgentsInstructions] {
            #expect(c.isChronologicalRun)
            #expect(c.resolutionLevel == "fileUnit")
        }
    }
}
