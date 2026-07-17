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

/// Tests the #352 lot post-validation — the guard that closes the two mis-resolution classes the
/// #335 audit found in the old RG-only acceptance rule (`firstAccepted` used to accept the first
/// record whose record group matched, nothing more).
///
/// The headline the guard exists to reject: NARA's `variantControlNumber_is` filter returned NAID
/// 609235170 for lot `60D627`, but that record is a **file unit** ("Operation Mongoose") whose own
/// `variantControlNumbers` list is **empty** — so it carries neither the series grain a lot must
/// have nor the lot number itself. Both facts are independently disqualifying.
///
/// The positive fixtures are real: NAID 40967113 (the 2026-07-15 harvest spike) exposes its lot
/// numbers as `State Department Lot File Number` control numbers — which is exactly why a legit
/// lot passes `carriesLotControlNumber` and the guard does not over-reject.
struct LotPostValidationTests {

    // MARK: - foldControlNumber

    @Test("Folds a raw control number to the compact lot key, stripping a Lot/Lot File prefix")
    func foldsControlNumber() {
        #expect(CatalogRecord.foldControlNumber("60D627") == "60D627")
        #expect(CatalogRecord.foldControlNumber("60 D 627") == "60D627")
        #expect(CatalogRecord.foldControlNumber("60-D-627") == "60D627")
        #expect(CatalogRecord.foldControlNumber("60–D 627") == "60D627")   // en-dash
        #expect(CatalogRecord.foldControlNumber("Lot 60 D 627") == "60D627")
        #expect(CatalogRecord.foldControlNumber("Lot File 74D471") == "74D471")
        #expect(CatalogRecord.foldControlNumber("lot 60d627") == "60D627")
        // An F-designator lot (RG 84) folds the same way.
        #expect(CatalogRecord.foldControlNumber("F 96") == "F96")
    }

    @Test("Folding does not spuriously equate a superstring with the lot (equality, not substring)")
    func foldIsEqualityNotSubstring() {
        // "160D6270" contains the substring "60D627", but folds to itself — never equal to 60D627.
        #expect(CatalogRecord.foldControlNumber("160D6270") == "160D6270")
        #expect(CatalogRecord.foldControlNumber("160D6270") != "60D627")
    }

    // MARK: - carriesLotControlNumber

    /// The real control-number array for NAID 40967113 (see `HMSMLREntryNumberTests`) — its four
    /// `State Department Lot File Number` values are exactly the lots a legit resolution must match.
    private let realVariants = ["RC 942", "NND 48569", "69D299", "67D147", "66D102", "64D171",
                                "RC 925", "NND 51113", "NND 48559", "HS1-301519541", "P 312"]

    @Test("A legit record carries its lot as a control number (real NAID 40967113)")
    func realRecordCarriesItsLots() {
        let record = CatalogRecord(naId: "40967113", title: "Chronological Files",
                                   variantControlNumbers: realVariants)
        #expect(record.carriesLotControlNumber("64D171"))
        #expect(record.carriesLotControlNumber("66D102"))
        #expect(record.carriesLotControlNumber("69D299"))
        // A lot the record does NOT index is not spuriously matched.
        #expect(!record.carriesLotControlNumber("60D627"))
    }

    @Test("The empty-list case (NAID 609235170 for 60D627) carries nothing")
    func emptyListCarriesNothing() {
        let record = CatalogRecord(naId: "609235170", title: "Files Pertaining to Operation Mongoose",
                                   variantControlNumbers: [])
        #expect(!record.carriesLotControlNumber("60D627"))
    }

    @Test("Matching is spelling-insensitive: spaced/prefixed control numbers still match")
    func matchesAcrossSpellings() {
        #expect(CatalogRecord(naId: "1", title: "x", variantControlNumbers: ["60 D 627"])
            .carriesLotControlNumber("60D627"))
        #expect(CatalogRecord(naId: "1", title: "x", variantControlNumbers: ["Lot 60 D 627"])
            .carriesLotControlNumber("60D627"))
        // A superstring control number must NOT match (equality after fold).
        #expect(!CatalogRecord(naId: "1", title: "x", variantControlNumbers: ["160D6270"])
            .carriesLotControlNumber("60D627"))
    }

    @Test("Letter-first and trailing-suffix lots match their control numbers (#352)")
    func matchesLetterFirstAndSuffix() {
        // CFM Files Lot M-88 (the run-book's #2 priority), stored spaced or dashed.
        #expect(CatalogRecord(naId: "1", title: "CFM Files", variantControlNumbers: ["M 88"])
            .carriesLotControlNumber("M88"))
        #expect(CatalogRecord(naId: "1", title: "CFM Files", variantControlNumbers: ["M-88"])
            .carriesLotControlNumber("M88"))
        // A trailing-letter suffix is significant: 61D282A must not match plain 61D282.
        #expect(CatalogRecord(naId: "1", title: "x", variantControlNumbers: ["61 D 282A"])
            .carriesLotControlNumber("61D282A"))
        #expect(!CatalogRecord(naId: "1", title: "x", variantControlNumbers: ["61D282"])
            .carriesLotControlNumber("61D282A"))
        // The queried key is also folded, so a non-normalized caller still matches (#352 hardening).
        #expect(CatalogRecord(naId: "1", title: "x", variantControlNumbers: ["M88"])
            .carriesLotControlNumber("M-88"))
    }

    // MARK: - isAcceptableLotResolution (the full acceptance decision)

    @Test("Accepts a series-level, RG-matching record that carries the lot")
    func acceptsCleanSeriesMatch() {
        let record = CatalogRecord(naId: "602231", title: "Conference Files",
                                   levelOfDescription: "series", recordGroupNumber: "59",
                                   variantControlNumbers: ["64D199", "CF 100"])
        #expect(record.isAcceptableLotResolution(recordGroup: "59", normalizedLot: "64D199"))
    }

    @Test("Rejects a file unit even when it carries the lot (a lot is a series)")
    func rejectsFileUnitLevel() {
        let record = CatalogRecord(naId: "1", title: "Some File Unit",
                                   levelOfDescription: "fileUnit", recordGroupNumber: "59",
                                   variantControlNumbers: ["64D199"])
        #expect(!record.isAcceptableLotResolution(recordGroup: "59", normalizedLot: "64D199"))
    }

    @Test("Rejects the 60D627 → Operation Mongoose match (fileUnit AND empty control list)")
    func rejectsTheHeadlineMisResolution() {
        let record = CatalogRecord(naId: "609235170", title: "Files Pertaining to Operation Mongoose",
                                   levelOfDescription: "fileUnit", recordGroupNumber: "59",
                                   variantControlNumbers: [])
        #expect(!record.isAcceptableLotResolution(recordGroup: "59", normalizedLot: "60D627"))
    }

    @Test("Rejects a series-level RG match whose control numbers lack the lot (post-validation core)")
    func rejectsSeriesWithoutTheLot() {
        // A plausible series in the right record group, but its control numbers do not include the
        // queried lot — the pure post-validation case (a coincidental variantControlNumber_is hit).
        let record = CatalogRecord(naId: "999", title: "Some Other Series",
                                   levelOfDescription: "series", recordGroupNumber: "59",
                                   variantControlNumbers: ["70D999"])
        #expect(!record.isAcceptableLotResolution(recordGroup: "59", normalizedLot: "60D627"))
    }

    @Test("Rejects a record from the wrong record group")
    func rejectsWrongRecordGroup() {
        let record = CatalogRecord(naId: "1", title: "RG-84 series",
                                   levelOfDescription: "series", recordGroupNumber: "84",
                                   variantControlNumbers: ["60D627"])
        #expect(!record.isAcceptableLotResolution(recordGroup: "59", normalizedLot: "60D627"))
    }

    // MARK: - decodePage carries variantControlNumbers end-to-end

    @Test("decodePage populates the raw variantControlNumbers, enabling post-validation")
    func decodeCarriesVariantControlNumbers() throws {
        // NAID 40967113 with its real lot-file-number control numbers.
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
                  { "number": "64D171", "type": "State Department Lot File Number" },
                  { "number": "66D102", "type": "State Department Lot File Number" },
                  { "number": "P 312",  "type": "HMS/MLR Entry Number" }
                ]
            } }, "sort": [40967113] }
          ] } }
        }
        """.data(using: .utf8)!
        let record = try #require(try NARACatalogHarvestClient.decodePage(json).records.first)
        #expect(record.variantControlNumbers == ["64D171", "66D102", "P 312"])
        #expect(record.carriesLotControlNumber("64D171"))
        #expect(record.isAcceptableLotResolution(recordGroup: "306", normalizedLot: "64D171"))
    }

    @Test("decodePage on the empty-list fileUnit case yields an unacceptable resolution")
    func decodeEmptyListFileUnitRejected() throws {
        // The shape of NAID 609235170: a file unit with no variantControlNumbers of its own.
        let json = """
        {
          "body": { "hits": { "hits": [
            { "_source": { "record": {
                "naId": 609235170,
                "title": "Files Pertaining to Operation Mongoose",
                "levelOfDescription": "fileUnit",
                "ancestors": [
                  { "distance": 2, "levelOfDescription": "recordGroup", "naId": 388,
                    "recordGroupNumber": 59, "title": "General Records of the Department of State" },
                  { "distance": 1, "levelOfDescription": "series", "naId": 1, "title": "A Series" }
                ]
            } }, "sort": [609235170] }
          ] } }
        }
        """.data(using: .utf8)!
        let record = try #require(try NARACatalogHarvestClient.decodePage(json).records.first)
        #expect(record.variantControlNumbers.isEmpty)
        #expect(record.recordGroupNumber == "59")
        #expect(!record.carriesLotControlNumber("60D627"))
        #expect(!record.isAcceptableLotResolution(recordGroup: "59", normalizedLot: "60D627"))
    }
}
