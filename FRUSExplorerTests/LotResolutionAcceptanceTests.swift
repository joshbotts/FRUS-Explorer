// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import FRUSExplorer

// MARK: - LotResolutionAcceptanceTests

/// The acceptance test the app's live lot lookup never had (#674 / N-8), and the filter
/// that applies it.
///
/// ## The bug these reproduce
/// Lot `90 D 234` — the Bureau of Oceans' Antarctic files — resolved to a **Census Bureau**
/// series. Every offline path correctly reported "unresolved" (no NARA series carries that
/// control number), so the app fell through to a free-text phrase query that took the single
/// top hit with no verification of any kind.
///
/// The scenarios below are named for the real records, so a future reader can tell what each
/// one is defending against rather than reading a table of synthetic booleans.
///
/// Version history:
///   1.0 — Session 2026-08-04: #674 live-path acceptance test
@Suite("Lot resolution acceptance")
struct LotResolutionAcceptanceTests {

    /// A catalog result with everything defaulted to *acceptable*, so each test varies one
    /// field and the failure is unambiguous.
    private func result(naId: String = "1",
                        title: String = "Conference Files",
                        rg: String? = "59",
                        level: String? = "series",
                        controlNumbers: [String] = ["66D110"]) -> NARACatalogResult {
        NARACatalogResult(
            naId: naId, title: title,
            catalogURL: URL(string: "https://catalog.archives.gov/id/\(naId)")!,
            scopeNote: nil, recordGroupNumber: rg, seriesTitle: nil, dateRange: nil,
            levelOfDescription: level, variantControlNumbers: controlNumbers)
    }

    // MARK: The rule

    @Test("A series in the right record group carrying the lot is accepted")
    func acceptsAGenuineResolution() {
        #expect(LotResolutionAcceptance.isAcceptable(
            recordGroup: "59", normalizedLot: "66D110",
            candidateRecordGroup: "59", levelOfDescription: "series",
            variantControlNumbers: ["66D110", "A1 3051B"]))
    }

    @Test("A wrong-record-group hit is refused — the 90 D 234 / Census class")
    func refusesWrongRecordGroup() {
        #expect(!LotResolutionAcceptance.isAcceptable(
            recordGroup: "59", normalizedLot: "90D234",
            candidateRecordGroup: "29", levelOfDescription: "series",
            variantControlNumbers: ["90D234"]))
    }

    @Test("A file unit is refused even when everything else matches — the #351 class")
    func refusesFileUnit() {
        #expect(!LotResolutionAcceptance.isAcceptable(
            recordGroup: "59", normalizedLot: "60D627",
            candidateRecordGroup: "59", levelOfDescription: "fileUnit",
            variantControlNumbers: ["60D627"]))
    }

    @Test("A record that does not carry the lot is refused — the free-text phrase hit")
    func refusesRecordWithoutTheLot() {
        #expect(!LotResolutionAcceptance.isAcceptable(
            recordGroup: "59", normalizedLot: "90D234",
            candidateRecordGroup: "59", levelOfDescription: "series",
            variantControlNumbers: ["61D146", "A1 1561"]))
    }

    @Test("Absent record group or level is refused, not waved through")
    func refusesUnknownMetadata() {
        // #321 removed a last-resort branch that accepted records with no exposed record
        // group. Absence of evidence must not read as evidence.
        #expect(!LotResolutionAcceptance.isAcceptable(
            recordGroup: "59", normalizedLot: "66D110",
            candidateRecordGroup: nil, levelOfDescription: "series",
            variantControlNumbers: ["66D110"]))
        #expect(!LotResolutionAcceptance.isAcceptable(
            recordGroup: "59", normalizedLot: "66D110",
            candidateRecordGroup: "59", levelOfDescription: nil,
            variantControlNumbers: ["66D110"]))
    }

    // MARK: Control-number folding

    @Test("Folding matches the spellings FRUS and NARA actually use")
    func foldingMatchesRealSpellings() {
        // This is what makes the free-text fallback worth keeping: `variantControlNumber_is`
        // matches only the literal variants the caller generated, so NARA's own
        // "Lot File 74D476" spelling is invisible to it — but verifiable here.
        for spelling in ["74D476", "74 D 476", "74 D476", "74-D-476", "74–D 476",
                         "Lot 74 D 476", "Lot File 74D476", "lot file 74d476"] {
            #expect(LotResolutionAcceptance.carriesLotControlNumber(
                "74D476", variantControlNumbers: [spelling]),
                    "\(spelling) should fold to 74D476")
        }
    }

    @Test("Folding is equality, never substring — 160D6270 is not 60D627")
    func foldingIsNotSubstring() {
        #expect(!LotResolutionAcceptance.carriesLotControlNumber(
            "60D627", variantControlNumbers: ["160D6270"]))
        #expect(!LotResolutionAcceptance.carriesLotControlNumber(
            "", variantControlNumbers: ["60D627"]))
    }

    // MARK: The filter — that the rule is actually applied

    @Test("firstAcceptable skips the wrong-RG top hit and takes the acceptable one")
    func filterSkipsToTheAcceptableRecord() {
        // Exactly the shape the generator's own comment describes: "the top hit for a lot
        // string is often a giant wrong-RG series … so we scan the page".
        let page = [
            result(naId: "census", title: "Inventory Controls", rg: "29",
                   controlNumbers: ["90D234"]),
            result(naId: "fileunit", level: "fileUnit", controlNumbers: ["66D110"]),
            result(naId: "right", controlNumbers: ["66D110"]),
        ]
        let picked = NARACatalogClient.firstAcceptable(page, recordGroup: "59", lotNumber: "66D110")
        #expect(picked?.naId == "right")
    }

    @Test("firstAcceptable returns nil rather than the least-bad option")
    func filterRefusesRatherThanDegrade() {
        // The honest outcome is "No matching record found" plus the manual search link —
        // not a confident row for whatever happened to come back first.
        let page = [
            result(naId: "census", title: "Inventory Controls", rg: "29",
                   controlNumbers: ["90D234"]),
            result(naId: "other", controlNumbers: ["61D146"]),
        ]
        #expect(NARACatalogClient.firstAcceptable(page, recordGroup: "59",
                                                 lotNumber: "90D234") == nil)
        #expect(NARACatalogClient.firstAcceptable([], recordGroup: "59", lotNumber: "66D110") == nil)
    }

    // MARK: Response parsing — the fields the rule needs must survive decoding

    @Test("Control numbers decode from every nesting NARA uses")
    func controlNumbersDecodeFromAllShapes() {
        // If this regressed to [] the acceptance test would refuse everything, so the
        // failure would be loud — but it would also make the app resolve nothing at all.
        #expect(NARACatalogClient.variantControlNumbers(
            in: ["variantControlNumbers": ["66D110", "A1 3051B"]]) == ["66D110", "A1 3051B"])
        #expect(NARACatalogClient.variantControlNumbers(
            in: ["variantControlNumbers": [["number": "66D110"], ["number": "A1 3051B"]]])
                == ["66D110", "A1 3051B"])
        #expect(NARACatalogClient.variantControlNumbers(
            in: ["description": ["variantControlNumbers": [["number": "66D110"]]]]) == ["66D110"])
        #expect(NARACatalogClient.variantControlNumbers(in: [:]).isEmpty)
    }
}

// MARK: - LotAcceptanceWiringAuditTests

/// That the acceptance test is *applied* on every live lot route, not merely defined.
///
/// The suite above proves the rule and the filter in isolation. It cannot prove either is
/// reached: both lot routes are network calls behind an API key, so a unit test exercises
/// none of them, and the whole defect in #674 was a correct-looking codebase where nothing
/// called a check that did not exist. A source scan is the available guard — it proves the
/// call is in the file, not that the file runs, which is why the PR also carries a
/// visual-review step against a real lot.
///
/// Version history:
///   1.0 — Session 2026-08-04: #674 live-path acceptance test
@Suite("Lot acceptance wiring")
struct LotAcceptanceWiringAuditTests {

    private static var clientSource: String {
        get throws {
            let root = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
            let text = try String(
                contentsOf: root.appending(path: "FRUSExplorer/SourceExplorer/NARACatalogClient.swift"),
                encoding: .utf8)
            #expect(text.count > 5_000, "NARACatalogClient.swift is implausibly small")
            return text
        }
    }

    /// `text` with full-line `//` comments removed, so a comment mentioning the call cannot
    /// satisfy an assertion looking for it.
    private static func code(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    @Test("Both live lot routes filter through firstAcceptable")
    func bothLotRoutesFilter() throws {
        let src = Self.code(try Self.clientSource)
        // Two routes reach a lot: resolveLotFile (the direct entry point) and
        // resolveLotFileVariants (the three-variant ladder plus its free-text fallback).
        let calls = src.components(separatedBy: "firstAcceptable(").count - 1
        #expect(calls >= 3,
                "expected firstAcceptable at the declaration plus both lot routes; found \(calls)")
    }

    @Test("The free-text fallback no longer takes the top hit blindly")
    func fallbackDoesNotTakeTheTopHit() throws {
        let src = Self.code(try Self.clientSource)
        // The exact shape of the bug: a single-result phrase query whose first element was
        // returned unverified. `maxResults: 1` must not reappear on the lot path.
        #expect(!src.contains("searchByRecordGroup(recordGroup, keywords: keywords, maxResults: 1)"),
                "searchByLotFile is back to a single unfilterable result — one result cannot be scanned")
        #expect(src.contains("fallbackScanRows"),
                "the fallback no longer scans a page")
    }

    @Test("The shared rule is used, not a second copy inside the client")
    func usesTheSharedRule() throws {
        let src = Self.code(try Self.clientSource)
        #expect(src.contains("LotResolutionAcceptance.isAcceptable"),
                "NARACatalogClient does not call the shared acceptance rule")
        // A local re-implementation is how the app and generator drifted apart in the first
        // place — the generator had the rule for months while the app had none.
        #expect(!src.contains("func isAcceptableLotResolution"),
                "NARACatalogClient declares its own copy of the acceptance rule")
    }
}

// MARK: - CatalogResultDecodingTests

/// That `buildResult` carries the acceptance fields off the wire.
///
/// The extractor is tested above; this tests the **caller**. A first round of mutation
/// testing showed why that distinction matters: replacing `buildResult`'s
/// `variantControlNumbers(in: record)` with `[]` left every test green while starving the
/// acceptance rule, which would have made the app resolve nothing at all.
///
/// Version history:
///   1.0 — Session 2026-08-04: #674 live-path acceptance test
@Suite("Catalog result decoding")
struct CatalogResultDecodingTests {

    @Test("A decoded v2 record carries level and control numbers into the result")
    func decodesAcceptanceFields() throws {
        let record: [String: Any] = [
            "naId": "602875",
            "title": "Conference Files",
            "recordGroupNumber": "59",
            "levelOfDescription": "series",
            "variantControlNumbers": [["number": "66D110"], ["number": "A1 3051B"]],
        ]
        let result = try #require(NARACatalogClient.buildResult(from: record))
        #expect(result.levelOfDescription == "series")
        #expect(result.variantControlNumbers == ["66D110", "A1 3051B"])
        // And the decoded result must actually satisfy the rule end to end.
        #expect(NARACatalogClient.firstAcceptable([result], recordGroup: "59",
                                                 lotNumber: "66D110")?.naId == "602875")
    }

    @Test("A decoded v1-nested record carries them too")
    func decodesNestedShape() throws {
        let record: [String: Any] = [
            "description": [
                "naId": "1039947",
                "title": "Records Relating to Jamaica",
                "recordGroupNumber": "59",
                "levelOfDescription": "series",
                "variantControlNumbers": [["number": "Lot File 74D476"]],
            ] as [String: Any],
        ]
        let result = try #require(NARACatalogClient.buildResult(from: record))
        #expect(result.levelOfDescription == "series")
        // NARA's own "Lot File" spelling — invisible to variantControlNumber_is, verifiable here.
        #expect(NARACatalogClient.firstAcceptable([result], recordGroup: "59",
                                                 lotNumber: "74D476")?.naId == "1039947")
    }

    @Test("A record missing the acceptance fields decodes but is refused")
    func missingFieldsAreRefused() throws {
        let record: [String: Any] = ["naId": "9", "title": "Inventory Controls",
                                     "recordGroupNumber": "29"]
        let result = try #require(NARACatalogClient.buildResult(from: record))
        #expect(result.levelOfDescription == nil)
        #expect(result.variantControlNumbers.isEmpty)
        #expect(NARACatalogClient.firstAcceptable([result], recordGroup: "59",
                                                 lotNumber: "90D234") == nil)
    }
}
