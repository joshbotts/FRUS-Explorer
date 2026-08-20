// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
import SourceNoteKit
@testable import CentralFilesIndexGeneratorCore

// MARK: - SupplementFromHarvestTests

/// Pins `supplementDecision` — the admission rule of the `SUPPLEMENT_FROM_HARVEST` pass that
/// closed #372 item 1b by resolving cited lot files against the offline record-group harvest
/// (978 → 1,065 lots).
///
/// ## What is being defended
/// The pass reads 4.5 GB, decides, and writes a bundled artifact that three render surfaces treat
/// as certain — Source Explorer captions its answer "Resolved from the bundled index". Only the
/// deciding has judgement in it, so that is what is tested; the scan is `HarvestShardReader`, and
/// the acceptance is `LotResolutionAcceptance`, both pinned by their own suites.
///
/// Three of the refusals below exist because of a specific way this could go wrong, and none of
/// them is hypothetical:
///
///   - **already resolved** is deduped against `central-files-index.json`, *not* against
///     `collection-authority.json`'s own `naId` field. The authority's join is stale relative to
///     the bundle it was built from — `83D66` is listed there as unresolved while central-files
///     has answered it since the keyed harvest — so the naive dedupe re-admits an existing row
///     under a possibly different NAID.
///   - **curated** is by name, never by trusting the rule to miss the 20 curated lots. It does
///     miss all 20 against today's harvest, and that is a property of the snapshot: curation
///     exists precisely because NARA carries no matching control number, and a re-harvest can
///     produce one. `CuratedLotResolutionsTests` fails the suite if one reaches this artifact.
///   - **divided lots are admitted with a stated pick**, not with shard-scan order. `57D284` has
///     two claimants that are different GATT sessions a year apart; whichever is stored, the
///     disclosure lives in `lot-claimants-index.json`, which is why the run order in the doc
///     comment is not advice.
///
/// Version history:
///   1.0 — Session 2026-08-19: #372 item 1b
@Suite("SUPPLEMENT_FROM_HARVEST — the admission rule")
struct SupplementFromHarvestTests {

    private typealias Candidate = CentralFilesIndexGeneratorRunner.SupplementCandidate

    private func candidate(naId: String, title: String = "Subject Files", rg: String = "59",
                           entries: [String] = [], level: String? = "series",
                           evidence: String = "controlNumber",
                           crossRG: Bool = false) -> Candidate {
        Candidate(naId: naId, title: title, recordGroup: rg, hmsMlrEntryNumbers: entries,
                  levelOfDescription: level, evidence: evidence, crossRecordGroup: crossRG)
    }

    private func decide(wanted: Set<String>, known: Set<String> = [], curated: Set<String> = [],
                        candidates: [String: [Candidate]] = [:])
        -> (admitted: [LotFileEntry],
            divided: [(lot: String, claimants: [Candidate])],
            refused: [(lot: String, reason: String)]) {
        CentralFilesIndexGeneratorRunner.supplementDecision(
            wanted: wanted, known: known, curated: curated, candidates: candidates)
    }

    // MARK: - Admission

    @Test("A wanted lot with one candidate is admitted with every field derived correctly")
    func singleCandidateIsAdmitted() {
        let out = decide(wanted: ["80D135"],
                         candidates: ["80D135": [candidate(
                            naId: "236748619",
                            title: "Subject and Country Files of Secretary of State Cyrus Vance",
                            entries: ["P 10"])]])
        #expect(out.refused.isEmpty)
        #expect(out.divided.isEmpty)
        #expect(out.admitted.count == 1)
        let row = out.admitted.first
        #expect(row?.lotNumber == "80D135")
        #expect(row?.naId == "236748619")
        #expect(row?.recordGroup == "59")
        #expect(row?.title == "Subject and Country Files of Secretary of State Cyrus Vance")
        #expect(row?.catalogURL == "https://catalog.archives.gov/id/236748619",
                "the deep link is derived from the NAID, never copied from a candidate field")
        #expect(row?.matchType == "control",
                "every admission rests on an exact control-number match; nothing else can be honest")
        #expect(row?.hmsMlrEntryNumbers == ["P 10"])
        #expect(row?.levelOfDescription == "series")
        #expect(row?.ancestryLacksRecordGroup == nil)
    }

    /// `nil`, not `[]`. The field means "NARA states none *or* the enrichment pass has not run",
    /// and an empty array serialises into the artifact as a positive claim of emptiness.
    @Test("A candidate with no entry numbers stores nil, not an empty array")
    func absentEntryNumbersAreNil() {
        let out = decide(wanted: ["85D308"], candidates: ["85D308": [candidate(naId: "470633955")]])
        #expect(out.admitted.first?.hmsMlrEntryNumbers == nil)
    }

    /// A cross-record-group admission stores the record's ACTUAL group, not the cited one. That
    /// is already precedent — the five RG 306 rows the item-1 fold added — and `lotFile(forRawLot:)`
    /// keys on the lot number alone, so the field is descriptive rather than part of the lookup.
    @Test("A cross-record-group admission stores the holding record group, not the cited one")
    func crossRecordGroupStoresTheHoldingGroup() {
        let out = decide(wanted: ["57D284"],
                         candidates: ["57D284": [candidate(
                            naId: "1422076", title: "Records of the Fifth Session at Torquay",
                            rg: "43", crossRG: true)]])
        #expect(out.admitted.first?.recordGroup == "43",
                "FRUS cites this as a D-lot (RG 59); NARA holds it in RG 43, and the row must say so")
    }

    // MARK: - The three refusals

    /// The `83D66` case, and the reason the dedupe reads central-files rather than the authority.
    @Test("A lot central-files already answers is refused, never re-admitted")
    func knownLotIsRefused() {
        let out = decide(wanted: ["83D66"], known: ["83D66"],
                         candidates: ["83D66": [candidate(naId: "9999999")]])
        #expect(out.admitted.isEmpty,
                "the harvested row stands; a supplement must not overwrite it with another NAID")
        #expect(out.refused.first?.reason == "already in central-files")
    }

    /// The guard that must not be left to luck. A curated lot is refused **even when the harvest
    /// offers an acceptable candidate**, which is exactly the case that would otherwise ship.
    @Test("A curated lot is refused by name even when a candidate exists")
    func curatedLotIsRefusedDespiteACandidate() {
        let out = decide(wanted: ["60D627"], curated: ["60D627"],
                         candidates: ["60D627": [candidate(naId: "602231",
                                                           title: "Conference Files")]])
        #expect(out.admitted.isEmpty, """
                curation is a decision that NARA's answer is not determinate; \
                a control-number match does not overturn it silently
                """)
        #expect(out.refused.first?.reason == "curated as non-deterministic")
    }

    @Test("A wanted lot the harvest cannot answer is refused, and that is the common case")
    func noCandidateIsRefused() {
        let out = decide(wanted: ["61D385", "59D95"])
        #expect(out.admitted.isEmpty)
        #expect(out.refused.count == 2)
        #expect(out.refused.allSatisfy { $0.reason == "no candidate in the harvest" })
    }

    @Test("Refusal precedence: known beats curated beats no-candidate")
    func refusalPrecedenceIsStable() {
        let out = decide(wanted: ["A"], known: ["A"], curated: ["A"],
                         candidates: ["A": [candidate(naId: "1")]])
        #expect(out.refused.map(\.reason) == ["already in central-files"])
    }

    // MARK: - Divided lots

    /// NARA divides a lot across series as readily as it consolidates several into one, so a
    /// divided lot has several correct answers and `LotFileEntry` has room for one.
    @Test("A divided lot is admitted at its lowest NAID and reported for disclosure")
    func dividedLotPicksLowestNaIdAndReports() {
        let out = decide(wanted: ["57D284"],
                         candidates: ["57D284": [
                            candidate(naId: "1422086", title: "Records of the Special Session", rg: "43"),
                            candidate(naId: "1422076", title: "Records of the Fifth Session at Torquay", rg: "43"),
                         ]])
        #expect(out.admitted.count == 1)
        #expect(out.admitted.first?.naId == "1422076", "the lowest NAID, numerically")
        #expect(out.divided.count == 1)
        #expect(out.divided.first?.lot == "57D284")
        #expect(out.divided.first?.claimants.map(\.naId) == ["1422076", "1422086"],
                "the full claimant list must reach the log, or the pick is undisclosed")
    }

    /// The pick has to be a property of the data, not of which shard happened to be read first.
    @Test("The pick does not depend on candidate order")
    func pickIsOrderIndependent() {
        let a = candidate(naId: "5051990"), b = candidate(naId: "588795"), c = candidate(naId: "4706948")
        let forward = decide(wanted: ["76F44"], candidates: ["76F44": [a, b, c]])
        let reverse = decide(wanted: ["76F44"], candidates: ["76F44": [c, b, a]])
        #expect(forward.admitted.first?.naId == "588795")
        #expect(forward.admitted.first?.naId == reverse.admitted.first?.naId)
        #expect(forward.divided.first?.claimants.map(\.naId)
                == reverse.divided.first?.claimants.map(\.naId))
    }

    /// Numerically, not lexicographically — `"588795" < "5051990"` as strings, and the opposite
    /// as numbers. Sorting NAIDs as text is the kind of wrong that produces a valid-looking row.
    @Test("NAIDs are ordered as numbers, not as strings")
    func naIdOrderIsNumeric() {
        let out = decide(wanted: ["X"],
                         candidates: ["X": [candidate(naId: "5051990"), candidate(naId: "588795")]])
        #expect(out.admitted.first?.naId == "588795")
    }

    @Test("A single-candidate lot is not reported as divided")
    func singleCandidateIsNotDivided() {
        let out = decide(wanted: ["80D135"], candidates: ["80D135": [candidate(naId: "1")]])
        #expect(out.divided.isEmpty)
    }

    // MARK: - Determinism

    @Test("Admissions come out sorted by lot number regardless of set iteration order")
    func outputIsSorted() {
        let wanted: Set<String> = ["93D188", "80D135", "85D308"]
        let candidates = Dictionary(uniqueKeysWithValues: wanted.map {
            ($0, [candidate(naId: "1\($0.count)")])
        })
        #expect(decide(wanted: wanted, candidates: candidates).admitted.map(\.lotNumber)
                == ["80D135", "85D308", "93D188"])
    }

    @Test("An empty wanted set decides nothing rather than failing")
    func emptyWantedIsANoOp() {
        let out = decide(wanted: [])
        #expect(out.admitted.isEmpty && out.divided.isEmpty && out.refused.isEmpty)
    }

    // MARK: - Reading the inputs

    @Test("Cited lot keys come from the authority's lot: collections, folded through the shared rule")
    func citedKeysAreFolded() throws {
        let json = """
        {"collections":[
          {"id":"lot:1980D0135","name":"S/S Files: Lot 80 D 135"},
          {"id":"lot:60 D 627","name":"Conference Files"},
          {"id":"rg:59","name":"General Records"},
          {"id":"library:HST","name":"Truman Library"}]}
        """
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("auth-\(UUID().uuidString).json")
        try Data(json.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let keys = try #require(CentralFilesIndexGeneratorRunner.citedLotKeys(authorityPath: url.path))
        #expect(keys == ["80D135", "60D627"],
                "only lot: ids, and each folded into the harvest's key space")
    }

    /// Two authority ids can fold to one key. A `Set` absorbs that; a dictionary keyed on the raw
    /// id would not, and the first probe written for this work died on exactly that collision.
    @Test("Two cited spellings that fold together collapse to one key")
    func foldCollisionsCollapse() throws {
        let json = #"{"collections":[{"id":"lot:89D56"},{"id":"lot:89 D 056"}]}"#
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("auth-\(UUID().uuidString).json")
        try Data(json.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(CentralFilesIndexGeneratorRunner.citedLotKeys(authorityPath: url.path) == ["89D56"])
    }

    @Test("A missing or malformed authority file yields nil, which the runner treats as fatal")
    func missingAuthorityYieldsNil() {
        #expect(CentralFilesIndexGeneratorRunner
            .citedLotKeys(authorityPath: "/nonexistent/collection-authority.json") == nil)
    }

    @Test("Curated keys are read and folded, so a spaced curated row still refuses")
    func curatedKeysAreFolded() throws {
        let json = #"{"lots":[{"lotNumber":"60D627"},{"lotNumber":"M–88"},{"lotNumber":"1959D0095"}]}"#
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("curated-\(UUID().uuidString).json")
        try Data(json.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(CentralFilesIndexGeneratorRunner.curatedLotKeys(curatedPath: url.path)
                == ["60D627", "M88", "59D95"])
    }

    @Test("A missing curated file yields an empty set, which the runner refuses to run on")
    func missingCuratedYieldsEmpty() {
        #expect(CentralFilesIndexGeneratorRunner
            .curatedLotKeys(curatedPath: "/nonexistent/curated.json").isEmpty)
    }
}
