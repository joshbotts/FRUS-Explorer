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

/// Tests the #352 `RESOLVE_LOTS_ONLY` merge — re-harvesting lots must not lose valid NAIDs to
/// NARA control-number index drift (a lot that resolved in an earlier harvest but whose
/// `variantControlNumber_is` search now returns nothing still holds a valid, stable NAID).
struct MergeLotsTests {

    private func lot(_ n: String, naId: String, level: String? = nil,
                     flagged: Bool? = nil) -> LotFileEntry {
        LotFileEntry(lotNumber: n, recordGroup: "59", naId: naId,
                     title: "Lot \(n)", catalogURL: "https://catalog.archives.gov/id/\(naId)",
                     levelOfDescription: level, ancestryLacksRecordGroup: flagged)
    }

    @Test("A good existing lot the harvest missed (drift) is preserved with its old NAID")
    func preservesDriftLostLot() {
        let existing = [lot("64D171", naId: "40967113", level: "series")]
        let harvested: [LotFileEntry] = []   // NARA's control-number search now returns nothing
        let merged = CentralFilesIndexGeneratorRunner.mergeLots(existing: existing, harvested: harvested)
        #expect(merged.map(\.lotNumber) == ["64D171"])
        #expect(merged.first?.naId == "40967113")
    }

    @Test("A fileUnit existing lot the harvest missed is dropped (never preserved)")
    func dropsFileUnitLot() {
        let existing = [lot("60D627", naId: "609235170", level: "fileUnit")]
        let merged = CentralFilesIndexGeneratorRunner.mergeLots(existing: existing, harvested: [])
        #expect(merged.isEmpty, "the 60 D 627 → Operation Mongoose fileUnit must not survive the merge")
    }

    @Test("A flagged (ancestryLacksRecordGroup) existing lot the harvest missed is dropped")
    func dropsFlaggedLot() {
        let existing = [lot("32D66", naId: "1", flagged: true)]
        let merged = CentralFilesIndexGeneratorRunner.mergeLots(existing: existing, harvested: [])
        #expect(merged.isEmpty)
    }

    @Test("The fresh harvest wins for a lot present in both (updated NAID)")
    func harvestOverlaysExisting() {
        let existing = [lot("64D199", naId: "OLD", level: "series")]
        let harvested = [lot("64D199", naId: "NEW", level: "series")]
        let merged = CentralFilesIndexGeneratorRunner.mergeLots(existing: existing, harvested: harvested)
        #expect(merged.count == 1)
        #expect(merged.first?.naId == "NEW")
    }

    @Test("A fileUnit that the harvest re-resolves cleanly is added (harvest overlays)")
    func harvestRescuesFileUnit() {
        let existing = [lot("60D627", naId: "609235170", level: "fileUnit")]
        let harvested = [lot("60D627", naId: "602875", level: "series")]
        let merged = CentralFilesIndexGeneratorRunner.mergeLots(existing: existing, harvested: harvested)
        #expect(merged.first?.naId == "602875")
        #expect(merged.first?.levelOfDescription == "series")
    }

    @Test("A harvest-only lot is added; output is sorted and deduplicated")
    func addsAndSorts() {
        let existing = [lot("64D199", naId: "1", level: "series")]
        let harvested = [lot("54D270", naId: "2", level: "series"),
                         lot("M88", naId: "3", level: "series")]
        let merged = CentralFilesIndexGeneratorRunner.mergeLots(existing: existing, harvested: harvested)
        #expect(merged.map(\.lotNumber) == ["54D270", "64D199", "M88"])
    }
}
