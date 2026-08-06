// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import VolumeSourcesIndexGeneratorCore

// MARK: - LotFoldTests

/// Pins `VolumeSourcesIndexRunner.lotsToWrite` — the fold that stops `volume-sources-index.json`
/// duplicating the 751 lots `central-files-index.json` already answers (#372 / N-5 PR 2).
///
/// Measured on the shipped artifacts: 758 lot entries → **7**, and the file 1,506,052 → 951,629
/// bytes (−36.8%, with the `majorCollections[].resolved` removal). No reader resolves anything
/// differently, because every one of them consults central-files first.
///
/// Version history:
///   1.0 — Session 2026-08-05: #372 / N-5 PR 2
@Suite("VolumeSourcesIndexRunner — the lot fold")
struct LotFoldTests {

    private func naid(_ id: String) -> ResolvedNAID {
        ResolvedNAID(naId: id, catalogURL: "https://catalog.archives.gov/id/\(id)",
                     title: "t\(id)", recordGroup: "59", matchType: "control")
    }
    /// Central-files answers everything except the two orphans.
    private func answered(_ key: String) -> Bool { !["74D267", "78D26"].contains(key) }

    @Test("Lots central-files can answer are dropped; orphans are kept")
    func duplicatesAreDropped() {
        let resolved = ["64D199": naid("1"), "53D413": naid("2"),
                        "74D267": naid("3"), "78D26": naid("4")]
        let out = VolumeSourcesIndexRunner.lotsToWrite(
            resolved: resolved, prior: [:], isAnsweredByCentralFiles: answered)
        #expect(Set(out.map.keys) == ["74D267", "78D26"])
        #expect(out.map["74D267"]?.naId == "3", "the kept entry must survive intact")
        #expect(out.note == nil)
    }

    /// After the fold every surviving entry is API-derived by construction, and Phase C resolves
    /// none of them without a key. Without the carry-forward, one offline run empties the map.
    @Test("A keyless run inherits the orphans instead of emptying the map")
    func keylessRunInheritsOrphans() {
        // A keyless run resolves ONLY what central-files answers — all of which is then pruned.
        let keylessResolved = ["64D199": naid("1"), "53D413": naid("2")]
        let out = VolumeSourcesIndexRunner.lotsToWrite(
            resolved: keylessResolved,
            prior: ["74D267": naid("3"), "78D26": naid("4")],
            isAnsweredByCentralFiles: answered)
        #expect(Set(out.map.keys) == ["74D267", "78D26"], "the orphans must survive a keyless run")
        #expect(out.note != nil, "an inherited map must say so in the log")
    }

    /// Inheritance is not a bypass: a lot central-files has since learned is dropped even when the
    /// previous artifact still carries it, or the fold would decay one stale entry at a time.
    @Test("Inherited entries are pruned too")
    func inheritedEntriesArePrunedAsWell() {
        let out = VolumeSourcesIndexRunner.lotsToWrite(
            resolved: [:],
            prior: ["74D267": naid("3"), "64D199": naid("1")],   // 64D199 is now central-files'
            isAnsweredByCentralFiles: answered)
        #expect(Set(out.map.keys) == ["74D267"])
    }

    /// A fresh run wins over the prior map — otherwise a real re-resolution could never land.
    @Test("A run that resolved orphans does not consult the prior map")
    func freshResultWins() {
        let out = VolumeSourcesIndexRunner.lotsToWrite(
            resolved: ["74D267": naid("NEW")],
            prior: ["74D267": naid("OLD"), "78D26": naid("OLD2")],
            isAnsweredByCentralFiles: answered)
        #expect(out.map["74D267"]?.naId == "NEW")
        #expect(out.map["78D26"] == nil, "a lot that stopped resolving is a real result, not a gap")
        #expect(out.note == nil)
    }

    /// Unlike `recordGroups`, an empty result is legitimate here — it means central-files answers
    /// everything the corpus cites — so this warns rather than throwing.
    @Test("An empty result is legitimate and does not throw")
    func emptyIsAllowed() {
        let out = VolumeSourcesIndexRunner.lotsToWrite(
            resolved: ["64D199": naid("1")], prior: [:],
            isAnsweredByCentralFiles: { _ in true })
        #expect(out.map.isEmpty)
        #expect(out.note == nil)
    }

    /// The predicate must ask *can central-files answer this?*, not *does it list it?* An entry the
    /// bundle carries but REFUSES (#321 `ancestryLacksRecordGroup`, #351 `fileUnit`) has to stay
    /// here, or the lot vanishes from both artifacts at once. Those guards refuse nothing on
    /// today's bundle, so the two readings coincide — today, and only today.
    @Test("A lot central-files carries but refuses is kept, not dropped")
    func refusedEntriesAreKept() {
        // "60D627" is listed by central-files but would be refused at fileUnit level.
        let out = VolumeSourcesIndexRunner.lotsToWrite(
            resolved: ["60D627": naid("9"), "64D199": naid("1")], prior: [:],
            isAnsweredByCentralFiles: { $0 != "60D627" })
        #expect(out.map.keys.contains("60D627"),
                "a refused entry is not an answered one — dropping it loses the lot everywhere")
        #expect(out.map["64D199"] == nil)
    }
}
