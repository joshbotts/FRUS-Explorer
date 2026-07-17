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

/// Tests for the #322 enrichment carry-through and the #321 flagged-lot guard in
/// ``BundledLotResolver``.
@Suite("BundledLotResolver")
struct BundledLotResolverTests {

    /// Writes a minimal `central-files-index` JSON (just the `lotFiles` array) to a temp file
    /// and returns a resolver over it.
    private func resolver(lotFilesJSON: String) throws -> BundledLotResolver {
        let json = "{\"lotFiles\":[\(lotFilesJSON)]}"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cfi-\(UUID().uuidString).json")
        try Data(json.utf8).write(to: url)
        return try BundledLotResolver(indexURL: url)
    }

    @Test("Carries the #315 enrichment fields through for an accepted lot (#322)")
    func carriesEnrichment() throws {
        let r = try resolver(lotFilesJSON: """
        {"lotNumber":"70D150","recordGroup":"59","naId":"111","title":"Central Files",
         "catalogURL":"https://catalog.archives.gov/id/111","matchType":"control",
         "hmsMlrEntryNumbers":["P 312"],"levelOfDescription":"series",
         "seriesNaId":null,"seriesTitle":null,"seriesHmsMlrEntryNumbers":null}
        """)
        let hit = r.resolve(rawLot: "70 D 150")
        #expect(hit != nil)
        #expect(hit?.hmsMlrEntryNumbers == ["P 312"])
        #expect(hit?.levelOfDescription == "series")
        #expect(hit?.naId == "111")
    }

    @Test("A file-unit lot resolves to nil — treated as unresolved (#351)")
    func fileUnitIsUnresolved() throws {
        // A State Department lot file is catalogued as a NARA *series*; a control-number query
        // that lands on a `fileUnit` is a false positive (the #335 audit measured this class as
        // almost entirely wrong-collection — 60 D 627 → an "Operation Mongoose" file unit). The
        // resolver treats it as unresolved, mirroring the app's `CentralFilesIndex` guard and the
        // `ancestryLacksRecordGroup` class, so a wrong NAID never enters volume-sources.
        let r = try resolver(lotFilesJSON: """
        {"lotNumber":"80D212","recordGroup":"59","naId":"333","title":"Yugoslavia File Unit",
         "catalogURL":"https://catalog.archives.gov/id/333","matchType":"control",
         "levelOfDescription":"fileUnit","seriesNaId":"302021","seriesTitle":"Central Decimal Files",
         "seriesHmsMlrEntryNumbers":["A1 205","A1 206"]}
        """)
        #expect(r.resolve(rawLot: "Lot 80 D 212") == nil)
    }

    @Test("A flagged (ancestryLacksRecordGroup) lot resolves to nil — treated as unresolved (#321)")
    func flaggedIsUnresolved() throws {
        let r = try resolver(lotFilesJSON: """
        {"lotNumber":"61F30","recordGroup":"84","naId":"579094","title":"Departmental Correspondence",
         "catalogURL":"https://catalog.archives.gov/id/579094","matchType":"control",
         "ancestryLacksRecordGroup":true}
        """)
        #expect(r.resolve(rawLot: "61 F 30") == nil)
    }

    @Test("An un-enriched lot (no #315 fields) still resolves, with nil enrichment")
    func unenrichedStillResolves() throws {
        let r = try resolver(lotFilesJSON: """
        {"lotNumber":"63D135","recordGroup":"59","naId":"222","title":"Conference Files",
         "catalogURL":"https://catalog.archives.gov/id/222","matchType":"control"}
        """)
        let hit = r.resolve(rawLot: "Lot 63 D 135")
        #expect(hit?.naId == "222")
        #expect(hit?.hmsMlrEntryNumbers == nil)
    }
}
