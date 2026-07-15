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
}
