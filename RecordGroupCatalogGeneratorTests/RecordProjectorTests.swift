// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import RecordGroupCatalogGeneratorCore

// MARK: - Fixtures

/// Record fixtures drawn from NARA's real bulk export.
///
/// `series486` is a verbatim reduction of NAID 472806592 ("Director's Speech Files") as returned by
/// `descriptions/record-groups/rg_486/` on the 2026-04-09 snapshot, read 2026-07-29 — including its
/// two-creator succession, its two control numbers, its lowercase quoted `audiovisual`, and the
/// `dataControlGroup` block the projection deliberately does not map.
enum CatalogFixtures {

    static let series486 = """
    {"record":{
      "naId":472806592,
      "title":"Director's Speech Files",
      "levelOfDescription":"series",
      "recordType":"description",
      "audiovisual":"false",
      "inclusiveStartDate":{"day":6,"logicalDate":"1988-08-06","month":8,"year":1988},
      "inclusiveEndDate":{"day":20,"logicalDate":"1994-04-20","month":4,"year":1994},
      "creators":[
        {"naId":10514123,
         "heading":"U.S. International Development Cooperation Agency. Trade and Development Program. (07/01/1980 - 10/27/1992)",
         "authorityType":"organization","creatorType":"Predecessor",
         "establishDate":{"day":1,"logicalDate":"1980-07-01","month":7,"year":1980},
         "abolishDate":{"day":27,"logicalDate":"1992-10-27","month":10,"year":1992}},
        {"naId":475680186,
         "heading":"U.S. Trade and Development Agency. Office of the Director. (10/28/1992 - )",
         "authorityType":"organization","creatorType":"Most Recent",
         "establishDate":{"day":28,"logicalDate":"1992-10-28","month":10,"year":1992}}
      ],
      "variantControlNumbers":[
        {"number":"P 1","type":"HMS/MLR Entry Number"},
        {"number":"HS2-000002595","type":"HMS Record Entry ID"}
      ],
      "accessRestriction":{"status":"Restricted - Possibly",
        "note":"Some or all records must be reviewed prior to being served to researchers.",
        "specificAccessRestrictions":[{"restriction":"FOIA (b)(6) Personal Information"}]},
      "physicalOccurrences":[{"copyStatus":"Preservation-Reproduction-Reference",
        "extent":"4 linear inches",
        "holdingsMeasurements":[{"count":1.0,"type":"Letter Archives Box, Narrow 4 inch"}],
        "mediaOccurrences":[{"generalMediaTypes":["Loose Sheets"],"specificMediaType":"Paper"}],
        "referenceUnits":[{"name":"National Archives at College Park - Textual Reference",
          "city":"College Park","state":"MD"}]}],
      "dataControlGroup":{"groupCd":"RRAT","groupId":"RRAT",
        "groupName":"National Archives at College Park - Textual Reference"},
      "ancestors":[{"distance":1,"levelOfDescription":"recordGroup","naId":22345815,
        "recordGroupNumber":486,"title":"Records of the U.S. Trade and Development Agency"}]
    }}
    """

    /// The record group's own node — the carrier of NARA's authoritative `seriesCount`.
    static let recordGroupNode486 = """
    {"record":{"naId":22345815,"title":"Records of the U.S. Trade and Development Agency",
      "levelOfDescription":"recordGroup","recordGroupNumber":486,"seriesCount":11,
      "recordType":"description"}}
    """

    static func record(_ json: String) throws -> CatalogJSONValue {
        try CatalogJSONValue.decodeRecordLine(Data(json.utf8))!
    }
}

// MARK: - RecordProjectorTests

/// Tests the raw-record → ``HarvestedRecord`` projection.
struct RecordProjectorTests {

    private func project(
        _ json: String, recordGroup: Int = 486, depth: HarvestDepth = .series
    ) throws -> (RecordProjectionOutcome, FieldAliasLedger) {
        var ledger = FieldAliasLedger()
        let outcome = RecordProjector().project(
            try CatalogFixtures.record(json), recordGroup: recordGroup,
            depth: depth, ledger: &ledger)
        return (outcome, ledger)
    }

    @Test("Projects the two priority payloads from a real series record")
    func projectsPriorityPayloads() throws {
        let (outcome, ledger) = try project(CatalogFixtures.series486)
        guard case .projected(let record) = outcome else {
            Issue.record("expected a projection, got \(outcome)")
            return
        }

        // Creators: both members, sorted, with dates on both sides of the succession.
        #expect(record.creators.count == 2)
        #expect(record.creators.map(\.creatorType) == ["Predecessor", "Most Recent"])
        #expect(record.creators[0].naId == "10514123")
        #expect(record.creators[0].abolishDate?.logicalDate == "1992-10-27")
        #expect(record.creators[1].establishDate?.year == 1992)
        #expect(record.creators.allSatisfy { $0.authorityType == "organization" })

        // Control numbers: verbatim, unfiltered — both types survive, including the internal
        // "HMS Record Entry ID" that CentralFilesIndexGenerator deliberately discards.
        #expect(record.variantControlNumbers.count == 2)
        #expect(Set(record.variantControlNumbers.compactMap(\.type))
                == ["HMS/MLR Entry Number", "HMS Record Entry ID"])
        #expect(record.variantControlNumbers.first { $0.type == "HMS/MLR Entry Number" }?.number == "P 1")

        #expect(ledger.observations["creators"]?.matchedAlias["creators"] == 1)
        #expect(ledger.neverMatched(among: RecordProjector.requiredFields).isEmpty)
    }

    @Test("Projects dates, restrictions, holdings and the audiovisual string")
    func projectsRemainingFields() throws {
        let (outcome, _) = try project(CatalogFixtures.series486)
        guard case .projected(let record) = outcome else { Issue.record("no projection"); return }

        #expect(record.inclusiveStartDate?.logicalDate == "1988-08-06")
        #expect(record.inclusiveStartDate?.isYearOnly == false)
        #expect(record.accessRestriction?.status == "Restricted - Possibly")
        #expect(record.accessRestriction?.specificRestrictions == ["FOIA (b)(6) Personal Information"])
        #expect(record.accessRestriction?.securityClassifications.isEmpty == true)
        #expect(record.physicalOccurrences.count == 1)
        #expect(record.physicalOccurrences[0].extent == "4 linear inches")
        #expect(record.physicalOccurrences[0].holdingsMeasurements[0].count == 1.0)
        #expect(record.physicalOccurrences[0].mediaTypes == ["Loose Sheets", "Paper"])
        #expect(record.physicalOccurrences[0].referenceUnitNames
                == ["National Archives at College Park - Textual Reference"])
        #expect(record.audiovisual == false)
        #expect(record.catalogURL == "https://catalog.archives.gov/id/472806592")
    }

    @Test("An unmapped raw key is reported rather than discarded")
    func reportsUnprojectedKeys() throws {
        // dataControlGroup is present on every RG 486 series and is not projected. The point of the
        // field is that a NEW key NARA adds shows up the same way, instead of vanishing at the
        // decode boundary the way the repo's existing catalog mirror loses everything it was not
        // told about.
        let (outcome, _) = try project(CatalogFixtures.series486)
        guard case .projected(let record) = outcome else { Issue.record("no projection"); return }
        #expect(record.unprojectedKeys == ["dataControlGroup"])
    }

    @Test("numberingNote is projected — it is the ordering instruction, not a note about numbering")
    func projectsNumberingNote() throws {
        let (outcome, _) = try project("""
        {"record":{"naId":1,"title":"Photographs","levelOfDescription":"series",
          "numberingNote":"Requests must include the record group number, series designator, box number, and item number. (Example=229-IIA-1-1).",
          "ancestors":[{"distance":1,"levelOfDescription":"recordGroup","naId":9,
            "recordGroupNumber":486,"title":"RG"}]}}
        """)
        guard case .projected(let record) = outcome else { Issue.record("no projection"); return }
        #expect(record.numberingNote?.hasPrefix("Requests must include") == true)
        // And it no longer shows up as an unmapped key.
        #expect(!record.unprojectedKeys.contains("numberingNote"))
    }

    @Test("specificRecordsTypes is DERIVED from subjects, not read from a key that does not exist")
    func derivesSpecificRecordsTypes() throws {
        // Measured across the 22-group harvest: an alias lookup for `specificRecordsTypes` matched
        // nothing in 20,188 records, because NARA folds every authority kind into `subjects` keyed by
        // authorityType — where there are 9,312 specificRecordsType entries across 16 groups.
        let (outcome, ledger) = try project("""
        {"record":{"naId":1,"title":"T","levelOfDescription":"series",
          "subjects":[
            {"naId":10,"heading":"Photographic prints","authorityType":"specificRecordsType"},
            {"naId":11,"heading":"Aerial views","authorityType":"specificRecordsType"},
            {"naId":12,"heading":"Peru","authorityType":"geographicPlaceName"},
            {"naId":13,"heading":"Propaganda","authorityType":"topicalSubject"}],
          "ancestors":[{"distance":1,"levelOfDescription":"recordGroup","naId":9,
            "recordGroupNumber":486,"title":"RG"}]}}
        """)
        guard case .projected(let record) = outcome else { Issue.record("no projection"); return }
        #expect(record.specificRecordsTypes == ["Aerial views", "Photographic prints"])
        // Every subject is still kept in full, discriminated by authorityType.
        #expect(record.subjects.count == 4)
        // The dead lookup is gone, so it is no longer examined at all.
        #expect(ledger.observations["specificRecordsTypes"] == nil)
    }

    @Test("A real specificRecordsTypes key would now trip the unprojected-key tripwire")
    func aRealSpecificRecordsTypesKeyIsReported() throws {
        // Dropped from consumedKeys deliberately: if NARA ever starts emitting the key for real, that
        // should be visible rather than masked by a stale entry.
        let (outcome, _) = try project("""
        {"record":{"naId":1,"title":"T","levelOfDescription":"series",
          "specificRecordsTypes":[{"heading":"Something new"}],
          "ancestors":[{"distance":1,"levelOfDescription":"recordGroup","naId":9,
            "recordGroupNumber":486,"title":"RG"}]}}
        """)
        guard case .projected(let record) = outcome else { Issue.record("no projection"); return }
        #expect(record.unprojectedKeys.contains("specificRecordsTypes"))
    }

    @Test("A year-only date is distinguishable from a precise one")
    func detectsYearOnlyDates() throws {
        // NARA renders a year-only date with a January-1st logicalDate, so logicalDate alone cannot
        // tell an imputed date from a real one.
        let date = CatalogDate(try CatalogFixtures.record(
            "{\"record\":{\"d\":{\"logicalDate\":\"1980-01-01\",\"year\":1980}}}")["d"])
        #expect(date?.isYearOnly == true)
        #expect(date?.logicalDate == "1980-01-01")
    }

    // MARK: Depth filtering

    @Test("The depth filter admits exactly the requested levels")
    func filtersByDepth() throws {
        func level(_ level: String, at depth: HarvestDepth) throws -> RecordProjectionOutcome {
            try project("""
            {"record":{"naId":1,"title":"T","levelOfDescription":"\(level)",
              "ancestors":[{"distance":1,"levelOfDescription":"recordGroup","naId":9,
                "recordGroupNumber":486,"title":"RG"}]}}
            """, depth: depth).0
        }
        if case .projected = try level("series", at: .series) {} else { Issue.record("series") }
        if case .levelNotAdmitted = try level("fileUnit", at: .series) {} else { Issue.record("fu") }
        if case .projected = try level("fileUnit", at: .seriesAndFileUnits) {} else { Issue.record("fu2") }
        if case .levelNotAdmitted = try level("item", at: .seriesAndFileUnits) {} else { Issue.record("item") }
        if case .projected = try level("item", at: .all) {} else { Issue.record("item2") }
    }

    @Test("The record group's own node is never a harvested record, at any depth")
    func excludesRecordGroupNode() throws {
        // It is kept through the harvest filter because it carries seriesCount, but it is metadata
        // about the group, not a record in it — counting it would inflate every total by one.
        for depth in HarvestDepth.allCases {
            let (outcome, _) = try project(CatalogFixtures.recordGroupNode486, depth: depth)
            if case .levelNotAdmitted = outcome {} else {
                Issue.record("recordGroup node admitted at depth \(depth.rawValue)")
            }
        }
    }

    // MARK: Invariants

    @Test("A record with no recordGroup ancestor is refused, not attributed by shard location")
    func refusesUnattributableRecord() throws {
        // The #321 lesson generalised: a record parented by a `collection` exposes no record group,
        // and this repo measured 0/16 precision for accepting such records as if they belonged to
        // the group being queried. Unattributable is not the same as attributable to us.
        let (outcome, _) = try project("""
        {"record":{"naId":5,"title":"Presidential library staff file","levelOfDescription":"series",
          "ancestors":[{"distance":1,"levelOfDescription":"collection","naId":77,
            "title":"Franklin D. Roosevelt Library Collection"}]}}
        """)
        guard case .rejected(let violation) = outcome else {
            Issue.record("expected refusal, got \(outcome)")
            return
        }
        #expect(violation == .noRecordGroupAncestor(naId: "5", ancestorLevels: ["collection"]))
        #expect(violation.auditLine.contains("no recordGroup in ancestry"))
    }

    @Test("A record belonging to another record group is refused")
    func refusesRecordGroupMismatch() throws {
        let (outcome, _) = try project("""
        {"record":{"naId":6,"title":"T","levelOfDescription":"series",
          "ancestors":[{"distance":1,"levelOfDescription":"recordGroup","naId":8,
            "recordGroupNumber":59,"title":"State"}]}}
        """, recordGroup: 486)
        #expect(outcome == .rejected(.recordGroupMismatch(naId: "6", expected: 486, found: 59)))
    }

    @Test("A record with no naId or no title is refused")
    func refusesIncompleteIdentity() throws {
        let ancestors = """
        "ancestors":[{"distance":1,"levelOfDescription":"recordGroup","naId":9,
          "recordGroupNumber":486,"title":"RG"}]
        """
        let (noId, _) = try project(
            "{\"record\":{\"title\":\"T\",\"levelOfDescription\":\"series\",\(ancestors)}}")
        #expect(noId == .rejected(.missingNaId))

        let (noTitle, _) = try project(
            "{\"record\":{\"naId\":7,\"levelOfDescription\":\"series\",\(ancestors)}}")
        #expect(noTitle == .rejected(.missingTitle(naId: "7")))
    }

    @Test("A file unit's enclosing series is captured; a series does not point at itself")
    func capturesSeriesAncestry() throws {
        let (outcome, _) = try project("""
        {"record":{"naId":10,"title":"Yugoslavia","levelOfDescription":"fileUnit",
          "ancestors":[
            {"distance":1,"levelOfDescription":"series","naId":11,"title":"Central Decimal File"},
            {"distance":2,"levelOfDescription":"recordGroup","naId":9,"recordGroupNumber":486,
             "title":"RG"}]}}
        """, depth: .seriesAndFileUnits)
        guard case .projected(let record) = outcome else { Issue.record("no projection"); return }
        #expect(record.seriesNaId == "11")
        #expect(record.seriesTitle == "Central Decimal File")

        let (seriesOutcome, _) = try project(CatalogFixtures.series486)
        guard case .projected(let series) = seriesOutcome else { Issue.record("no series"); return }
        #expect(series.seriesNaId == nil)
    }

    // MARK: stringList shapes

    @Test("stringList accepts scalar arrays, keyed objects, and an unanticipated key name")
    func flattensListShapes() throws {
        func list(_ json: String, keys: [String]) throws -> [String] {
            RecordProjector.stringList(try CatalogFixtures.record(json)["v"], preferredKeys: keys)
        }
        // NARA is inconsistent about whether a short-label list is strings or single-key objects,
        // and the key name varies by field — so a wrong guess must widen, not empty the field.
        let scalars = try list("{\"record\":{\"v\":[\"en\",\"fr\"]}}", keys: ["language"])
        #expect(scalars == ["en", "fr"])
        let keyed = try list("{\"record\":{\"v\":[{\"language\":\"en\"}]}}", keys: ["language"])
        #expect(keyed == ["en"])
        // No preferred key matches: fall back to any string member rather than dropping the value.
        let unanticipated = try list("{\"record\":{\"v\":[{\"surprise\":\"kept\"}]}}", keys: ["language"])
        #expect(unanticipated == ["kept"])
        // Duplicates collapse and the result is sorted, for a stable artifact.
        let deduped = try list("{\"record\":{\"v\":[\"b\",\"a\",\"b\"]}}", keys: [])
        #expect(deduped == ["a", "b"])
    }

    // MARK: Alias behaviour

    @Test("The projector tolerates NARA's own documented misspelling and reports the fallback")
    func toleratesDocumentedMisspelling() throws {
        // NARA's published OpenAPI spells this `pyhsicalOccurrences`; the shipped data spells it
        // correctly. Tolerating both costs nothing, but a match on the non-canonical spelling must
        // be visible rather than quietly used.
        let (_, ledger) = try project("""
        {"record":{"naId":1,"title":"T","levelOfDescription":"series",
          "pyhsicalOccurrences":[{"extent":"1 box"}],
          "ancestors":[{"distance":1,"levelOfDescription":"recordGroup","naId":9,
            "recordGroupNumber":486,"title":"RG"}]}}
        """)
        #expect(ledger.observations["physicalOccurrences"]?
            .matchedAlias["pyhsicalOccurrences"] == 1)
        let nonCanonical = ledger.nonCanonicalMatches()
        #expect(nonCanonical.contains { $0.field == "physicalOccurrences" && $0.count == 1 })
    }
}

// MARK: - FieldAliasLedgerTests

/// Tests the three states an `Optional` would have conflated.
struct FieldAliasLedgerTests {

    @Test("Distinguishes matched, present-but-empty, and absent")
    func distinguishesThreeStates() throws {
        var ledger = FieldAliasLedger()
        let projector = RecordProjector()

        func project(_ creators: String) throws {
            _ = projector.project(try CatalogFixtures.record("""
            {"record":{"naId":1,"title":"T","levelOfDescription":"series",\(creators)
              "ancestors":[{"distance":1,"levelOfDescription":"recordGroup","naId":9,
                "recordGroupNumber":486,"title":"RG"}]}}
            """), recordGroup: 486, depth: .series, ledger: &ledger)
        }

        try project("\"creators\":[{\"naId\":1,\"heading\":\"H\"}],")   // matched
        try project("\"creators\":[],")                                  // present but empty
        try project("\"creators\":null,")                                // present but empty
        try project("")                                                  // absent

        let observation = ledger.observations["creators"]
        #expect(observation?.matchedCount == 1)
        #expect(observation?.presentButEmpty == 2)
        #expect(observation?.absent == 1)
        #expect(observation?.examined == 4)
        // A field that matched at least once is not "never matched", even if mostly empty.
        #expect(ledger.neverMatched(among: ["creators"]).isEmpty)
    }

    @Test("A field that never matched anywhere is reported — the run's go/no-go")
    func reportsNeverMatched() throws {
        var ledger = FieldAliasLedger()
        _ = RecordProjector().project(try CatalogFixtures.record("""
        {"record":{"naId":1,"title":"T","levelOfDescription":"series",
          "ancestors":[{"distance":1,"levelOfDescription":"recordGroup","naId":9,
            "recordGroupNumber":486,"title":"RG"}]}}
        """), recordGroup: 486, depth: .series, ledger: &ledger)

        // This is the failure the whole design guards against: the harvest completes, the artifact
        // looks plausible, and the data it existed to collect is simply not there.
        #expect(ledger.neverMatched(among: RecordProjector.requiredFields)
                == ["creators", "variantControlNumbers"])
    }

    @Test("Merging per-group ledgers sums each state")
    func merges() {
        var a = FieldAliasLedger()
        a.noteMatch(field: "creators", alias: "creators")
        a.noteAbsent(field: "creators")
        var b = FieldAliasLedger()
        b.noteMatch(field: "creators", alias: "creators")
        b.notePresentButEmpty(field: "creators")
        a.merge(b)
        #expect(a.observations["creators"]?.matchedCount == 2)
        #expect(a.observations["creators"]?.absent == 1)
        #expect(a.observations["creators"]?.presentButEmpty == 1)
    }
}
