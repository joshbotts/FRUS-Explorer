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

// MARK: - FoldVolumeSourceLotsTests

/// Pins `CentralFilesIndexGeneratorRunner.foldDecision` — the admission rule of the
/// `FOLD_VOLUME_SOURCES` pass that closed #372 item 1 by absorbing `volume-sources-index.json`'s
/// orphan lots into `central-files-index.json` (971 → 978, and the orphan map to `{}`).
///
/// ## Why the rule is tested and not the pass
/// The pass reads a file, decides, and writes a file; only the middle step has judgement in it.
/// `foldDecision` is that step, factored out for the same reason `lotsToWrite` is factored out on
/// the volume-sources side — which is also what lets both sides of one fold be driven by tests
/// that never touch the 1 MB artifacts.
///
/// ## What each refusal is protecting
/// The two guards #321 and #351 installed live in `pruneFlaggedLots`, and a fold is exactly the
/// shape of change that reintroduces what a prune removed: it admits rows from a *different*
/// resolver, built under a different acceptance policy. Neither guard refuses anything on today's
/// input — the seven real orphans are all unflagged and unlevelled — so without these tests both
/// would be dead code that looks live, and the day a re-harvest produced a flagged orphan the fold
/// would quietly undo the prune.
///
/// Version history:
///   1.0 — Session 2026-08-19: #372 item 1
@Suite("FOLD_VOLUME_SOURCES — the admission rule")
struct FoldVolumeSourceLotsTests {

    private typealias Row = CentralFilesIndexGeneratorRunner.VolumeSourceLotRow

    /// A complete row, in the shape the seven real orphans have.
    private func row(naId: String = "40967113", rg: String = "306",
                     title: String = "Chronological Files", matchType: String? = "control",
                     level: String? = nil, flagged: Bool? = nil,
                     entries: [String]? = nil) -> Row {
        Row(naId: naId, catalogURL: "https://catalog.archives.gov/id/\(naId)", title: title,
            recordGroup: rg, matchType: matchType, hmsMlrEntryNumbers: entries,
            levelOfDescription: level, ancestryLacksRecordGroup: flagged)
    }

    private func decide(_ rows: [String: Row], known: Set<String> = [])
        -> (admitted: [LotFileEntry], refused: [(lot: String, reason: String)]) {
        CentralFilesIndexGeneratorRunner.foldDecision(rows: rows, known: known)
    }

    // MARK: - Admission

    @Test("An unknown, complete, series-level row crosses over with every field intact")
    func completeRowIsAdmitted() {
        let out = decide(["64D171": row(entries: ["A1 1069", "P 160"])])
        #expect(out.refused.isEmpty)
        #expect(out.admitted.count == 1)
        let entry = out.admitted.first
        // Field by field: the crossing is a nine-field copy between two types with several
        // same-typed adjacent fields, so a transposition compiles and `naId` alone misses it.
        #expect(entry?.lotNumber == "64D171", "the map KEY is the lot number; the row carries none")
        #expect(entry?.naId == "40967113")
        #expect(entry?.recordGroup == "306")
        #expect(entry?.title == "Chronological Files")
        #expect(entry?.catalogURL == "https://catalog.archives.gov/id/40967113")
        #expect(entry?.matchType == "control")
        #expect(entry?.hmsMlrEntryNumbers == ["A1 1069", "P 160"])
        #expect(entry?.levelOfDescription == nil)
        #expect(entry?.ancestryLacksRecordGroup == nil,
                "the flag is cleared on admission — a row that carried true never gets this far")
        // The values must also be mutually distinguishable, or a title/URL swap passes above.
        #expect(entry?.title != entry?.catalogURL)
        #expect(entry?.naId != entry?.recordGroup)
    }

    @Test("A series-level row is admitted; the level rides along rather than being erased")
    func seriesLevelIsCarried() {
        let out = decide(["70D449": row(level: "series")])
        #expect(out.admitted.first?.levelOfDescription == "series")
    }

    // MARK: - The four refusals

    @Test("A lot central-files already answers is refused, never overwritten")
    func knownLotIsRefused() {
        let out = decide(["64D171": row(naId: "99999999")], known: ["64D171"])
        #expect(out.admitted.isEmpty,
                "the harvested resolution wins; a front-matter row must not replace it")
        #expect(out.refused.map(\.lot) == ["64D171"])
        #expect(out.refused.first?.reason.contains("already") == true)
    }

    @Test("A fileUnit row is refused — #351, the rule the sibling prune enforces")
    func fileUnitIsRefused() {
        let out = decide(["60D627": row(level: "fileUnit")])
        #expect(out.admitted.isEmpty,
                "a file-unit title is not the series title #315 asks the UI to present")
        #expect(out.refused.first?.reason.contains("#351") == true)
    }

    @Test("An ancestryLacksRecordGroup row is refused — #321")
    func flaggedRowIsRefused() {
        let out = decide(["61D146": row(flagged: true)])
        #expect(out.admitted.isEmpty)
        #expect(out.refused.first?.reason.contains("#321") == true)
    }

    @Test("A row missing any required field is refused rather than defaulted")
    func incompleteRowsAreRefused() {
        let cases: [String: Row] = [
            "A1": Row(naId: nil, catalogURL: "u", title: "t", recordGroup: "59",
                      matchType: "control", hmsMlrEntryNumbers: nil,
                      levelOfDescription: nil, ancestryLacksRecordGroup: nil),
            "A2": Row(naId: "1", catalogURL: nil, title: "t", recordGroup: "59",
                      matchType: "control", hmsMlrEntryNumbers: nil,
                      levelOfDescription: nil, ancestryLacksRecordGroup: nil),
            "A3": Row(naId: "1", catalogURL: "u", title: nil, recordGroup: "59",
                      matchType: "control", hmsMlrEntryNumbers: nil,
                      levelOfDescription: nil, ancestryLacksRecordGroup: nil),
            "A4": Row(naId: "1", catalogURL: "u", title: "t", recordGroup: nil,
                      matchType: "control", hmsMlrEntryNumbers: nil,
                      levelOfDescription: nil, ancestryLacksRecordGroup: nil),
        ]
        let out = decide(cases)
        #expect(out.admitted.isEmpty)
        #expect(out.refused.count == 4)
        #expect(out.refused.allSatisfy { $0.reason == "incomplete row" })
    }

    /// `matchType` is `control` (exact control-number match) or `phrase` (free-text fallback) —
    /// a claim about *how* a lot resolved, which `LotFileEntry` requires and cannot express as
    /// unknown. Defaulting an absent one is the tempting fix and the wrong one: it would mint
    /// high confidence the source never asserted, on rows nobody looks at because nothing on
    /// screen renders `matchType` today.
    @Test("A row with no matchType is refused, not defaulted to control")
    func missingMatchTypeIsRefused() {
        let out = decide(["74D267": row(matchType: nil)])
        #expect(out.admitted.isEmpty, "an absent matchType must not become \"control\"")
        #expect(out.refused.first?.reason == "incomplete row")
    }

    @Test("phrase is carried through unchanged — the refusal is of absence, not of low confidence")
    func phraseMatchTypeIsAdmitted() {
        let out = decide(["78D26": row(matchType: "phrase")])
        #expect(out.admitted.first?.matchType == "phrase")
    }

    // MARK: - Determinism and idempotency

    @Test("Admissions come out in sorted key order regardless of insertion order")
    func outputIsOrderIndependent() {
        let rows = ["78D26": row(naId: "824653"), "64D171": row(naId: "40967113"),
                    "70D449": row(naId: "40967285")]
        #expect(decide(rows).admitted.map(\.lotNumber) == ["64D171", "70D449", "78D26"])
    }

    /// Idempotency is not a separate mechanism — it is the "already in central-files" refusal
    /// seen a second time. Feeding the first run's own admissions back as `known` is the same
    /// state the pass reaches on a re-run, and it must admit nothing.
    @Test("Re-running over an index that already absorbed the rows admits nothing")
    func secondRunIsANoOp() {
        let rows = ["64D171": row(), "70D449": row(naId: "40967285")]
        let first = decide(rows)
        #expect(first.admitted.count == 2)
        let second = decide(rows, known: Set(first.admitted.map(\.lotNumber)))
        #expect(second.admitted.isEmpty)
        #expect(second.refused.count == 2)
    }

    @Test("An empty map is a no-op, not an error — it is the post-fold steady state")
    func emptyMapIsANoOp() {
        let out = decide([:])
        #expect(out.admitted.isEmpty)
        #expect(out.refused.isEmpty)
    }

    // MARK: - The wire shape

    /// The rows are read straight from the shipped artifact, so the decoder has to match its
    /// spelling. All eight fields are optional by design; a required one would turn a single
    /// malformed row into a failure of the whole pass.
    @Test("The real volume-sources row shape decodes, and unknown keys are ignored")
    func decodesTheShippedShape() throws {
        let json = """
        {"schemaVersion":2,"generated":"2026-08-10","recordGroups":{},"majorCollections":[],
         "lots":{"64D171":{"catalogURL":"https://catalog.archives.gov/id/40967113",
                           "matchType":"control","naId":"40967113","recordGroup":"306",
                           "title":"Chronological Files"}}}
        """
        let decoded = try JSONDecoder().decode(
            CentralFilesIndexGeneratorRunner.VolumeSourceLots.self, from: Data(json.utf8))
        let lots = try #require(decoded.lots)
        #expect(lots.count == 1)
        #expect(lots["64D171"]?.naId == "40967113")
        #expect(lots["64D171"]?.levelOfDescription == nil)
        #expect(decide(lots).admitted.count == 1, "and it is admissible as decoded")
    }

    @Test("An artifact with no lots key decodes to nil rather than failing")
    func absentLotsKeyDecodes() throws {
        let decoded = try JSONDecoder().decode(
            CentralFilesIndexGeneratorRunner.VolumeSourceLots.self,
            from: Data(#"{"schemaVersion":2}"#.utf8))
        #expect(decoded.lots == nil)
    }
}
