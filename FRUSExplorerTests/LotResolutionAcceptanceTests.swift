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

    /// The **generator** side of the same rule, added by #372 item 1b.
    ///
    /// This test existed above for the app's client only, and the omission was not academic:
    /// `NARACatalogHarvestClient` carried its own three-conjunct rule and its own
    /// `foldControlNumber` for months, and the copy fell behind. The shared fold gained #679's
    /// spelling expansions; the private one did not; **53 lot files NARA holds were unreachable
    /// from the harvester** as a direct result, including `80D135`, which NARA indexes only as
    /// `1980D0135`.
    ///
    /// A source scan proves the call is in the file rather than that it runs — the same
    /// limitation the suite header states — but it is what stops the copy coming back, and
    /// coming back is precisely what happened once.
    @Test("The generator's harvest client uses the shared rule, with no private fold")
    func generatorUsesTheSharedRule() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(
            contentsOf: root.appending(path: "CentralFilesIndexGeneratorCore/NARACatalogHarvestClient.swift"),
            encoding: .utf8)
        #expect(text.count > 5_000, "NARACatalogHarvestClient.swift is implausibly small")
        let src = Self.code(text)
        #expect(src.contains("LotResolutionAcceptance.evidence"),
                "the harvest client does not call the shared acceptance rule")
        #expect(src.contains("LotResolutionAcceptance.carriesLotControlNumber"),
                "the harvest client does not use the shared control-number test")
        // The two declarations the swap deleted. Either one reappearing means a second copy of a
        // rule the app applies at render time.
        #expect(!src.contains("static func foldControlNumber"),
                "the harvest client has re-declared a private fold — this is the drift that cost 53 lots")
        #expect(!src.contains("recordGroupNumber == recordGroup\n"),
                "the harvest client has re-inlined the record-group conjunct instead of delegating")
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

// MARK: - LotFoldAndNoteChannelTests

/// The two spelling expansions and the consolidation-note channel added by #679.
///
/// All three defects here caused **false refusals** — the failure mode the bureau conjunct was
/// dropped to avoid, arriving through the conjunct that was kept.
///
/// Version history:
///   1.0 — Session 2026-08-05: #679
@Suite("Lot fold and note channel")
struct LotFoldAndNoteChannelTests {

    // MARK: Four-digit year

    @Test("A four-digit year folds to the two-digit form NARA also publishes")
    func fourDigitYearFolds() {
        // NARA's own data proves the equivalence: nine values literally read
        // "82D309 or 1982D0309" and "1978D0412 or 78D412".
        #expect(LotResolutionAcceptance.foldControlNumber("1984D241") == "84D241")
        #expect(LotResolutionAcceptance.foldControlNumber("1982D0129") == "82D129")
        #expect(LotResolutionAcceptance.foldControlNumber("1978D0412") == "78D412")
        #expect(LotResolutionAcceptance.carriesLotControlNumber(
            "84D241", variantControlNumbers: ["1984D241"]))
    }

    @Test("A 20xx accession number is NOT folded into an impossible lot")
    func twentyFirstCenturyIsLeftAlone() {
        // 2015D0755 is a 2015 accession. Folding it would produce 15D755 — a 1915 State
        // Department lot file, which cannot exist; lots run from the 1940s to the 1990s.
        #expect(LotResolutionAcceptance.foldControlNumber("2015D0755") != "15D755")
        #expect(!LotResolutionAcceptance.carriesLotControlNumber(
            "15D755", variantControlNumbers: ["2015D0755"]))
    }

    // MARK: Zero padding

    @Test("A zero-padded sequence folds to the unpadded form")
    func zeroPaddingFolds() {
        #expect(LotResolutionAcceptance.foldControlNumber("75D076") == "75D76")
        #expect(LotResolutionAcceptance.foldControlNumber("84D068") == "84D68")
        #expect(LotResolutionAcceptance.foldControlNumber("74F026") == "74F26")
        #expect(LotResolutionAcceptance.carriesLotControlNumber(
            "75D76", variantControlNumbers: ["75D076"]))
    }

    @Test("Non-lot identifiers pass through untouched")
    func nonLotIdentifiersSurvive() {
        // Entry numbers, declassification project numbers and agency disposition numbers share
        // the field. Rewriting them would manufacture matches out of unrelated identifiers.
        for id in ["A1 3051B", "NND 959367", "P 79", "DAL-0059-2012-0003-0001", "UD-16D 71"] {
            let folded = LotResolutionAcceptance.foldControlNumber(id)
            #expect(!folded.isEmpty)
            #expect(!LotResolutionAcceptance.carriesLotControlNumber(
                "84D241", variantControlNumbers: [id]))
        }
    }

    @Test("A trailing period is stripped")
    func trailingPeriodStripped() {
        #expect(LotResolutionAcceptance.carriesLotControlNumber(
            "64D199", variantControlNumbers: ["64D199."]))
    }

    // MARK: The consolidation note

    /// NARA's actual note on naId 596518, verbatim.
    private let consolidationNote = "This lot file is a consolidation of material found in lots "
        + "53D500, 58D159, 58D776, 60D644, 61D67, and 62D42 after screening."

    @Test("Lots named in a consolidation note are found")
    func noteNamesAreExtracted() {
        let found = LotResolutionAcceptance.lotsNamedInNote(consolidationNote)
        for lot in ["53D500", "58D159", "58D776", "60D644", "61D67", "62D42"] {
            #expect(found.contains(lot), "\(lot) not extracted from NARA's consolidation note")
        }
    }

    @Test("A record whose note names the lot is accepted, and labelled as such")
    func noteChannelAccepts() {
        // naId 596518 carries control numbers 58D776 and A1 1561 only, so 61D67 and 62D42 are
        // established by the note alone — 8 documents that were being refused.
        let e = LotResolutionAcceptance.evidence(
            recordGroup: "59", normalizedLot: "61D67",
            candidateRecordGroup: "59", levelOfDescription: "series",
            variantControlNumbers: ["58D776", "A1 1561"],
            controlNumberNotes: [consolidationNote])
        #expect(e == .consolidationNote)
    }

    @Test("A direct control number outranks the note")
    func controlNumberWins() {
        let e = LotResolutionAcceptance.evidence(
            recordGroup: "59", normalizedLot: "58D776",
            candidateRecordGroup: "59", levelOfDescription: "series",
            variantControlNumbers: ["58D776"],
            controlNumberNotes: [consolidationNote])
        #expect(e == .controlNumber)
    }

    @Test("Boilerplate notes name nothing — the measured false-positive rate is zero")
    func boilerplateNotesAreInert() {
        // These are the five most common note shapes in the harvest (1,706 + 981 + 753 + 665 +
        // 433 occurrences) plus the entry-provenance form. Exactly one note in all 8,897
        // contains lot-shaped tokens; if any of these did, prose scanning would be unsafe.
        for note in ["This is the Department of State Lot File Number.",
                     "This is a Department of State lot file number.",
                     "This is a Department of State LOT file number.",
                     "This is a State Department lot file number.",
                     "This is the Department of State Lot File number.",
                     "The portion of this series formerly identified as UD-11W 12 was formerly "
                     + "described under National Archives Identifier 6862111.",
                     "Entry UD-15D 37 was part of RG 59.",
                     "Transfer W286-68S3602, Boxes 89-93"] {
            #expect(LotResolutionAcceptance.lotsNamedInNote(note).isEmpty,
                    "boilerplate note yielded lot tokens: \(note)")
        }
    }

    @Test("The note channel still respects record group and level")
    func noteChannelIsNotAnEscapeHatch() {
        #expect(LotResolutionAcceptance.evidence(
            recordGroup: "59", normalizedLot: "61D67",
            candidateRecordGroup: "29", levelOfDescription: "series",
            variantControlNumbers: [], controlNumberNotes: [consolidationNote]) == nil)
        #expect(LotResolutionAcceptance.evidence(
            recordGroup: "59", normalizedLot: "61D67",
            candidateRecordGroup: "59", levelOfDescription: "fileUnit",
            variantControlNumbers: [], controlNumberNotes: [consolidationNote]) == nil)
    }

    @Test("Notes decode off the wire and reach the filter")
    func notesDecodeFromTheResponse() throws {
        let record: [String: Any] = [
            "naId": "596518", "title": "Subject Files",
            "recordGroupNumber": "59", "levelOfDescription": "series",
            "variantControlNumbers": [
                ["number": "58D776", "note": consolidationNote],
                ["number": "A1 1561"],
            ],
        ]
        let result = try #require(NARACatalogClient.buildResult(from: record))
        #expect(result.controlNumberNotes == [consolidationNote])
        #expect(NARACatalogClient.firstAcceptable([result], recordGroup: "59",
                                                 lotNumber: "61D67")?.naId == "596518")
    }

    // MARK: - O-7: the record-group guard, lowered on control-number evidence only

    /// The decision itself: NARA's own control number outranks the record group FRUS named.
    ///
    /// Verified against the offline harvest — naId 1422076 sits in **RG 43** and carries
    /// `57D284`, while every FRUS citation of that lot says RG 59. The two disagree because
    /// FRUS records provenance at the time of writing and NARA files by present custody; the
    /// control number is the assertion, and a record group is not a refutation of it.
    /// The counter-case, and the reason this is a table rather than a rule: an RG 29 (Census)
    /// series carries `90D234`, colliding with a State lot of the same shape. It is NOT in the
    /// table and must stay refused — see `LotResolutionAcceptanceTests` above.
    @Test("An unlisted cross-record-group hit is still refused")
    func unlistedCrossRecordGroupStillRefused() {
        #expect(LotResolutionAcceptance.evidence(
            recordGroup: "59", normalizedLot: "90D234",
            candidateRecordGroup: "29", levelOfDescription: "series",
            variantControlNumbers: ["90D234"]) == nil)
    }

    @Test("A control-number match is accepted across record groups")
    func controlNumberOutranksRecordGroup() {
        #expect(LotResolutionAcceptance.evidence(
            recordGroup: "59", normalizedLot: "57D284",
            candidateRecordGroup: "43", levelOfDescription: "series",
            variantControlNumbers: ["57D284", "NND 760090", "A1 713"]) == .controlNumber)
    }

    /// The USIA case, which is the one a reader is most likely to meet: FRUS says
    /// "Department of State, USIA/IOP Files: Lot 59 D 260" and NARA holds USIA in RG 306.
    @Test("The USIA lots resolve into RG 306")
    func usiaLotsCrossIntoRG306() {
        for lot in ["59D260", "61D445", "64D535"] {
            #expect(LotResolutionAcceptance.isAcceptable(
                recordGroup: "59", normalizedLot: lot,
                candidateRecordGroup: "306", levelOfDescription: "series",
                variantControlNumbers: [lot]),
                "\(lot) is cited under RG 59 and held by NARA in RG 306")
        }
    }

    /// The half that did NOT move. A consolidation note is prose that mentions the lot, not a
    /// catalogued control number, so it still requires the record groups to agree — otherwise a
    /// match could rest on a sentence naming a lot the series does not hold.
    @Test("A consolidation note is still refused across record groups")
    func consolidationNoteStillNeedsMatchingRecordGroup() {
        #expect(LotResolutionAcceptance.evidence(
            recordGroup: "59", normalizedLot: "61D67",
            candidateRecordGroup: "306", levelOfDescription: "series",
            variantControlNumbers: [], controlNumberNotes: [consolidationNote]) == nil)
        // …and is still accepted when they do agree, so the clause above is not a blanket ban.
        #expect(LotResolutionAcceptance.evidence(
            recordGroup: "59", normalizedLot: "61D67",
            candidateRecordGroup: "59", levelOfDescription: "series",
            variantControlNumbers: [], controlNumberNotes: [consolidationNote]) == .consolidationNote)
    }

    /// #321 is untouched: a record exposing no record group at all is still refused, even with
    /// a control-number hit. That branch is what put unrelated series behind lot citations.
    @Test("A record with no exposed record group is still refused")
    func nilRecordGroupStillRefused() {
        #expect(LotResolutionAcceptance.evidence(
            recordGroup: "59", normalizedLot: "57D284",
            candidateRecordGroup: nil, levelOfDescription: "series",
            variantControlNumbers: ["57D284"]) == nil)
    }

    /// And the file-unit exclusion survives the change.
    @Test("A file unit is still refused across record groups")
    func fileUnitStillRefused() {
        #expect(LotResolutionAcceptance.evidence(
            recordGroup: "59", normalizedLot: "57D284",
            candidateRecordGroup: "43", levelOfDescription: "fileUnit",
            variantControlNumbers: ["57D284"]) == nil)
    }
}
