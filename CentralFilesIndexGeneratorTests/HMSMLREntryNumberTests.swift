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

/// Tests the #315 HMS/MLR entry-number extraction — the discrimination NARA staff depend on.
///
/// The stakes are why these are exhaustive: the number this filter selects is what a
/// researcher quotes to an archivist to pull an original record. Selecting a *superseded*
/// (`Former …`) number, or NARA's *internal* record ID, sends them to the wrong place — and
/// the mistake would be invisible in the app, since every candidate is a plausible-looking
/// identifier string.
///
/// The fixture is not invented: it is the real `variantControlNumbers` array returned for
/// NAID 40967113 (RG 306, lot 64D171 — "Chronological Files") by the live catalog on
/// 2026-07-15, plus the `Former HMS/MLR Entry Number` case the issue names explicitly.
struct HMSMLREntryNumberTests {

    /// The real array from NAID 40967113, verbatim — including the two adversarial
    /// neighbours: `HMS Record Entry ID` (internal) and the lot numbers themselves.
    private let realVariants: [(number: String?, type: String?)] = [
        ("RC 942",           "Declassification Project Number"),
        ("NND 48569",        "Declassification Project Number"),
        ("69D299",           "State Department Lot File Number"),
        ("67D147",           "State Department Lot File Number"),
        ("66D102",           "State Department Lot File Number"),
        ("64D171",           "State Department Lot File Number"),
        ("RC 925",           "Declassification Project Number"),
        ("NND 51113",        "Declassification Project Number"),
        ("NND 48559",        "Declassification Project Number"),
        ("HS1-301519541",    "HMS Record Entry ID"),
        ("P 312",            "HMS/MLR Entry Number"),
    ]

    @Test("Extracts exactly the HMS/MLR entry number from a real catalog record")
    func extractsFromRealRecord() {
        #expect(CatalogRecord.hmsMlrEntries(from: realVariants) == ["P 312"])
    }

    /// The requirement this issue states outright: a *Former* entry number is superseded and
    /// must never be handed to a researcher.
    @Test("Never returns a Former HMS/MLR Entry Number")
    func excludesFormerEntryNumber() {
        let withFormer = realVariants + [("A1 1069", "Former HMS/MLR Entry Number")]
        #expect(CatalogRecord.hmsMlrEntries(from: withFormer) == ["P 312"])
    }

    /// A record whose *only* HMS/MLR-ish value is the superseded one yields nothing —
    /// showing no entry number is correct; showing a stale one is not.
    @Test("A record with only a Former entry number yields none")
    func onlyFormerYieldsEmpty() {
        let onlyFormer: [(number: String?, type: String?)] = [
            ("A1 1069",       "Former HMS/MLR Entry Number"),
            ("HS1-301519541", "HMS Record Entry ID"),
        ]
        #expect(CatalogRecord.hmsMlrEntries(from: onlyFormer).isEmpty)
    }

    /// `HMS Record Entry ID` is NARA's internal identifier and is not a citable entry number.
    /// It shares the `HMS` prefix with the field we want — which is exactly why the filter
    /// matches the type exactly rather than by prefix or substring.
    @Test("Never returns the internal HMS Record Entry ID")
    func excludesInternalRecordEntryID() {
        let onlyInternal: [(number: String?, type: String?)] = [
            ("HS1-301519541", "HMS Record Entry ID")
        ]
        #expect(CatalogRecord.hmsMlrEntries(from: onlyInternal).isEmpty)
    }

    /// Guards the substring hazard directly: were the predicate ever loosened to
    /// `contains("HMS/MLR")`, this fixture would return two values instead of one.
    @Test("Exact type match, not a substring test")
    func matchesTypeExactlyNotBySubstring() {
        let ambiguous: [(number: String?, type: String?)] = [
            ("P 312",   "HMS/MLR Entry Number"),
            ("A1 1069", "Former HMS/MLR Entry Number"),
        ]
        let result = CatalogRecord.hmsMlrEntries(from: ambiguous)
        #expect(result == ["P 312"])
        #expect(result.count == 1, "a substring match would have admitted the Former value too")
    }

    @Test("Keeps every entry number when a record carries several")
    func keepsMultipleEntries() {
        let multi: [(number: String?, type: String?)] = [
            ("P 312",  "HMS/MLR Entry Number"),
            ("P 313",  "HMS/MLR Entry Number"),
        ]
        #expect(CatalogRecord.hmsMlrEntries(from: multi) == ["P 312", "P 313"])
    }

    // MARK: - Ordering
    //
    // NARA returns entry numbers in an arbitrary order — measured over the real corpus,
    // 50 of the 61 multi-entry records come back unsorted. Sorting is therefore what makes
    // the bundled artifact deterministic instead of a snapshot of one response's order.
    // The fixtures below are real values from the 2026-07-15 harvest.

    @Test("Sorts arbitrary response order deterministically")
    func sortsResponseOrder() {
        // Lot 56D679, exactly as the catalog returned it.
        let asReturned: [(number: String?, type: String?)] = [
            ("UD 28", "HMS/MLR Entry Number"),
            ("UD 32", "HMS/MLR Entry Number"),
            ("UD 30", "HMS/MLR Entry Number"),
            ("UD 29", "HMS/MLR Entry Number"),
            ("UD 31", "HMS/MLR Entry Number"),
        ]
        #expect(CatalogRecord.hmsMlrEntries(from: asReturned)
                == ["UD 28", "UD 29", "UD 30", "UD 31", "UD 32"])
    }

    /// The case that makes lexicographic sorting unacceptable rather than merely untidy:
    /// lot 78D237 carries 30 entry numbers, and plain sorting puts `UD-WX 1152` first while
    /// burying `UD-WX 54-A` at position 27.
    @Test("Natural order: a 2-digit number precedes 3- and 4-digit ones")
    func sortsNumericallyNotLexicographically() {
        #expect(CatalogRecord.sortedNaturally(
            ["UD-WX 1152", "UD-WX 253", "UD-WX 54-A", "UD-WX 1502", "UD-WX 491"])
                == ["UD-WX 54-A", "UD-WX 253", "UD-WX 491", "UD-WX 1152", "UD-WX 1502"])
    }

    /// Real values from lot 83D276 — lexicographic order would list the 6-digit numbers
    /// before the 4-digit one.
    @Test("Natural order across widely different magnitudes")
    func sortsAcrossMagnitudes() {
        #expect(CatalogRecord.sortedNaturally(
            ["UD-WX 100021", "UD-WX 100022-C", "UD-WX 1510-D"])
                == ["UD-WX 1510-D", "UD-WX 100021", "UD-WX 100022-C"])
    }

    /// Real values from lot 83D135 — mixed prefixes must still group by prefix first.
    @Test("Natural order sorts within a prefix, then across prefixes")
    func sortsWithinAndAcrossPrefixes() {
        #expect(CatalogRecord.sortedNaturally(
            ["UD-09D 1", "UD-09D 10", "UD-09D 7", "UD-13W 37", "UD-15D 31"])
                == ["UD-09D 1", "UD-09D 7", "UD-09D 10", "UD-13W 37", "UD-15D 31"])
    }

    /// A suffixed number sorts adjacent to its base rather than being scattered
    /// (real: lot 57F139).
    @Test("A lettered suffix sorts beside its base number")
    func sortsSuffixedBesideBase() {
        #expect(CatalogRecord.sortedNaturally(["UD 3269A", "UD 3269", "UD 3269B"])
                == ["UD 3269", "UD 3269A", "UD 3269B"])
    }

    /// The sort must be a *total* order: values the numeric comparison calls equal still
    /// need a stable tiebreak, or the artifact could differ between runs.
    @Test("Numerically-equal but textually-different values order deterministically")
    func totalOrderOnNumericTies() {
        let once  = CatalogRecord.sortedNaturally(["UD 007", "UD 7"])
        let twice = CatalogRecord.sortedNaturally(["UD 7", "UD 007"])
        #expect(once == twice, "the same set must sort identically regardless of input order")
    }

    /// Sorting the output of a sort changes nothing — the property the artifact's stability
    /// actually rests on.
    @Test("Sorting is idempotent")
    func sortIsIdempotent() {
        let input = ["UD-WX 1152", "UD-WX 253", "UD-WX 54-A"]
        let once = CatalogRecord.sortedNaturally(input)
        #expect(CatalogRecord.sortedNaturally(once) == once)
    }

    @Test("A record with no variant control numbers yields none")
    func emptyInputYieldsEmpty() {
        #expect(CatalogRecord.hmsMlrEntries(from: []).isEmpty)
    }

    @Test("Trims surrounding whitespace and drops blank numbers")
    func trimsAndDropsBlanks() {
        let messy: [(number: String?, type: String?)] = [
            ("  P 312  ", "HMS/MLR Entry Number"),
            ("",          "HMS/MLR Entry Number"),
            ("   ",       "HMS/MLR Entry Number"),
            (nil,         "HMS/MLR Entry Number"),
        ]
        #expect(CatalogRecord.hmsMlrEntries(from: messy) == ["P 312"])
    }

    /// The type string is a literal from NARA's data, so a differently-cased variant is a
    /// *different* value — this pins current behaviour rather than asserting it is desirable.
    /// If the live data ever proves case-inconsistent, this test is the place that says so.
    @Test("Type matching is case-sensitive (pins current behaviour)")
    func typeMatchIsCaseSensitive() {
        let cased: [(number: String?, type: String?)] = [
            ("P 312", "hms/mlr entry number")
        ]
        #expect(CatalogRecord.hmsMlrEntries(from: cased).isEmpty)
    }

    /// End-to-end through the decoder: the field must survive `decodePage`, not just the
    /// filter. Before #315 this array was dropped at decode time — which is precisely why the
    /// numbers could not be recovered from the cache and a re-query was needed.
    @Test("Survives the full page decode, not just the filter")
    func decodesThroughPage() throws {
        let json = """
        {
          "body": { "hits": { "hits": [
            { "_source": { "record": {
                "naId": 40967113,
                "title": "Chronological Files",
                "levelOfDescription": "series",
                "variantControlNumbers": [
                  { "number": "64D171",        "type": "State Department Lot File Number" },
                  { "number": "HS1-301519541", "type": "HMS Record Entry ID" },
                  { "number": "A1 1069",       "type": "Former HMS/MLR Entry Number" },
                  { "number": "P 312",         "type": "HMS/MLR Entry Number" }
                ]
            } }, "sort": [40967113] }
          ] } }
        }
        """.data(using: .utf8)!

        let page = try NARACatalogHarvestClient.decodePage(json)
        let record = try #require(page.records.first)
        #expect(record.naId == "40967113")
        #expect(record.levelOfDescription == "series")
        #expect(record.hmsMlrEntryNumbers == ["P 312"])
    }

    /// A record with the field absent decodes to an empty list, not a failure — most records
    /// in the corpus predate or lack it.
    @Test("A record without variantControlNumbers decodes with no entries")
    func decodesRecordLackingTheField() throws {
        let json = """
        {
          "body": { "hits": { "hits": [
            { "_source": { "record": { "naId": 12345, "title": "Something" } }, "sort": [12345] }
          ] } }
        }
        """.data(using: .utf8)!

        let page = try NARACatalogHarvestClient.decodePage(json)
        let record = try #require(page.records.first)
        #expect(record.hmsMlrEntryNumbers.isEmpty)
    }

    // MARK: - Enclosing series (#315)
    //
    // Fixtures are the real ancestor chains observed on 2026-07-15 for three of the 27
    // file-unit lot records. The premise these pin: a file unit's enclosing series — the
    // "file series name" #315 asks to display — already rides in the response we fetch, so
    // the title costs nothing extra.

    @Test("A file unit's enclosing series is extracted from its ancestors")
    func extractsSeriesAncestorFromFileUnit() throws {
        // Real: naId 19129101, lot 57M44.
        let json = """
        {
          "body": { "hits": { "hits": [
            { "_source": { "record": {
                "naId": 19129101,
                "title": "Numerical File: 295/271-295/341",
                "levelOfDescription": "fileUnit",
                "ancestors": [
                  { "distance": 2, "levelOfDescription": "recordGroup", "naId": 388,
                    "recordGroupNumber": 59, "title": "General Records of the Department of State" },
                  { "distance": 1, "levelOfDescription": "series", "naId": 654171,
                    "title": "Numerical Files" }
                ]
            } }, "sort": [19129101] }
          ] } }
        }
        """.data(using: .utf8)!

        let record = try #require(try NARACatalogHarvestClient.decodePage(json).records.first)
        #expect(record.levelOfDescription == "fileUnit")
        #expect(record.seriesAncestorNaId == "654171")
        #expect(record.seriesAncestorTitle == "Numerical Files")
        #expect(record.recordGroupNumber == "59")
        #expect(record.ancestorLevels == ["recordGroup", "series"])
        // The file unit carries no entry number of its own — the observed rule.
        #expect(record.hmsMlrEntryNumbers.isEmpty)
    }

    /// A series record's own ancestors stop at the record group, so it has no series ancestor
    /// — the guard against attributing a series to itself.
    @Test("A series record has no series ancestor")
    func seriesRecordHasNoSeriesAncestor() throws {
        // Real: naId 40967113, the verifying spike's record.
        let json = """
        {
          "body": { "hits": { "hits": [
            { "_source": { "record": {
                "naId": 40967113,
                "title": "Chronological Files",
                "levelOfDescription": "series",
                "ancestors": [
                  { "distance": 1, "levelOfDescription": "recordGroup", "naId": 622,
                    "recordGroupNumber": 306, "title": "Records of the U.S. Information Agency" }
                ],
                "variantControlNumbers": [
                  { "number": "P 312", "type": "HMS/MLR Entry Number" }
                ]
            } }, "sort": [40967113] }
          ] } }
        }
        """.data(using: .utf8)!

        let record = try #require(try NARACatalogHarvestClient.decodePage(json).records.first)
        #expect(record.seriesAncestorNaId == nil)
        #expect(record.seriesAncestorTitle == nil)
        #expect(record.hmsMlrEntryNumbers == ["P 312"])
        #expect(record.ancestorLevels == ["recordGroup"])
    }

    /// The mis-resolution candidate the ancestor spike surfaced: lot `61F30` is an
    /// F-designator (RG 84 post records), yet resolves to a record whose ancestry is
    /// `collection > series` — FDR Library's President's Secretary's File — with **no**
    /// record group. `ancestorLevels` is what lets the enrichment pass flag it.
    @Test("A collection-parented record exposes an ancestry with no record group")
    func flagsAncestryWithoutRecordGroup() throws {
        // Real: naId 16619095, lot 61F30.
        let json = """
        {
          "body": { "hits": { "hits": [
            { "_source": { "record": {
                "naId": 16619095,
                "title": "Navy - Estimates of Potential Military Strength",
                "levelOfDescription": "fileUnit",
                "ancestors": [
                  { "distance": 2, "levelOfDescription": "collection", "naId": 567623,
                    "title": "President's Secretary's File (Franklin D. Roosevelt)" },
                  { "distance": 1, "levelOfDescription": "series", "naId": 579094,
                    "title": "Departmental Correspondence" }
                ]
            } }, "sort": [16619095] }
          ] } }
        }
        """.data(using: .utf8)!

        let record = try #require(try NARACatalogHarvestClient.decodePage(json).records.first)
        #expect(record.seriesAncestorTitle == "Departmental Correspondence")
        #expect(record.recordGroupNumber == nil, "no recordGroup ancestor exists to read")
        #expect(!record.ancestorLevels.contains("recordGroup"),
                "this is the signal the enrichment pass flags as a candidate mis-resolution")
        #expect(record.ancestorLevels == ["collection", "series"])
    }
}
