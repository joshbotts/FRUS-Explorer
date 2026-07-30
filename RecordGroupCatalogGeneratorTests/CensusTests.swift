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

// MARK: - FieldCensusTests

/// Tests the key-path census — the artifact that makes an empty typed field distinguishable from an
/// absent upstream one.
struct FieldCensusTests {

    @Test("Collapses array nesting to [] so a census describes a corpus, not one record")
    func collapsesArrayPaths() throws {
        var census = FieldCensus()
        census.ingest(try CatalogFixtures.record(CatalogFixtures.series486))

        #expect(census.paths["creators[].heading"] != nil)
        #expect(census.paths["creators[].authorityType"] != nil)
        #expect(census.paths["variantControlNumbers[].type"] != nil)
        #expect(census.paths["physicalOccurrences[].holdingsMeasurements[].type"] != nil)
        #expect(census.paths["accessRestriction.specificAccessRestrictions[].restriction"] != nil)
        // Without collapsing, a 30-element array would emit 30 indexed paths.
        #expect(!census.sortedPaths.contains { $0.contains("[0]") })
    }

    @Test("occurrences counts leaves while recordsWithPath counts records")
    func separatesOccurrencesFromRecords() throws {
        var census = FieldCensus()
        census.ingest(try CatalogFixtures.record(CatalogFixtures.series486))

        // The fixture has two creators, so the two counters must diverge — reporting only one of
        // them would misstate coverage exactly where the interesting fields are.
        #expect(census.paths["creators[].heading"]?.occurrences == 2)
        #expect(census.paths["creators[].heading"]?.recordsWithPath == 1)
        #expect(census.presencePercent("creators[].heading") == 100.0)
        #expect(census.recordCount == 1)
    }

    @Test("Records observed JSON types, including the quoted-boolean quirk")
    func recordsTypes() throws {
        var census = FieldCensus()
        census.ingest(try CatalogFixtures.record(CatalogFixtures.series486))
        #expect(census.paths["audiovisual"]?.types == ["string"])
        #expect(census.paths["naId"]?.types == ["int"])
        // NARA writes this as `1.0`, but CatalogJSONValue probes Int before Double (so `naId` cannot
        // become `1933760.0`), which normalises a whole float to an integer. The census therefore
        // reports `int` here — a fact about the decoder, not about the export. See the decoding note
        // on CatalogJSONValue.init(from:); `doubleValue` reads either form, so nothing downstream
        // depends on the distinction.
        #expect(census.paths["physicalOccurrences[].holdingsMeasurements[].count"]?.types
                == ["int"])
    }

    @Test("Presence percentage reflects records that lack the path")
    func computesPresence() throws {
        var census = FieldCensus()
        census.ingest(try CatalogFixtures.record(CatalogFixtures.series486))
        census.ingest(try CatalogFixtures.record("""
        {"record":{"naId":2,"title":"No creators here","levelOfDescription":"series"}}
        """))
        #expect(census.recordCount == 2)
        #expect(census.presencePercent("creators[].heading") == 50.0)
        #expect(census.presencePercent("title") == 100.0)
    }

    @Test("Truncates and flattens long example values so a scope note cannot blow a CSV cell")
    func truncatesExamples() {
        let long = String(repeating: "x", count: 500)
        #expect(FieldCensus.truncate(long).count == FieldCensus.exampleLength + 1)  // + ellipsis
        #expect(FieldCensus.truncate("a\nb\tc") == "a b c")
    }

    @Test("Merging per-group censuses sums counts and unions types")
    func merges() throws {
        var a = FieldCensus()
        a.ingest(try CatalogFixtures.record(CatalogFixtures.series486))
        var b = FieldCensus()
        b.ingest(try CatalogFixtures.record(CatalogFixtures.series486))
        a.merge(b)
        #expect(a.recordCount == 2)
        #expect(a.paths["creators[].heading"]?.occurrences == 4)
        #expect(a.paths["creators[].heading"]?.recordsWithPath == 2)
    }

    @Test("CSV rows are sorted by key path, for a stable diff")
    func emitsSortedRows() throws {
        var census = FieldCensus()
        census.ingest(try CatalogFixtures.record(CatalogFixtures.series486))
        let paths = census.csvRows().map { $0[0] }
        #expect(paths == paths.sorted())
        #expect(FieldCensus.csvHeader.count == census.csvRows()[0].count)
    }
}

// MARK: - ValueCensusTests

/// Tests the value vocabulary census.
struct ValueCensusTests {

    @Test("Resolves []-collapsed paths back against a record")
    func resolvesPaths() throws {
        let record = try CatalogFixtures.record(CatalogFixtures.series486)
        #expect(ValueCensus.values(at: "levelOfDescription", in: record) == ["series"])
        #expect(Set(ValueCensus.values(at: "variantControlNumbers[].type", in: record))
                == ["HMS/MLR Entry Number", "HMS Record Entry ID"])
        #expect(ValueCensus.values(at: "creators[].creatorType", in: record)
                == ["Predecessor", "Most Recent"])
        #expect(ValueCensus.values(at: "accessRestriction.status", in: record)
                == ["Restricted - Possibly"])
        // Two array hops.
        #expect(ValueCensus.values(
            at: "physicalOccurrences[].mediaOccurrences[].specificMediaType", in: record)
                == ["Paper"])
        // A path that does not exist yields nothing rather than throwing.
        #expect(ValueCensus.values(at: "nope.nothing[]", in: record).isEmpty)
    }

    @Test("Tracks which record groups a value appears in — what makes 'agency-specific' answerable")
    func tracksRecordGroupSpread() throws {
        var census = ValueCensus()
        let record = try CatalogFixtures.record(CatalogFixtures.series486)
        census.ingest(record, recordGroup: 486)
        census.ingest(record, recordGroup: 59)

        let groups = census.recordGroups["variantControlNumbers[].type"]?["HMS/MLR Entry Number"]
        #expect(groups == [59, 486])
        #expect(census.counts["variantControlNumbers[].type"]?["HMS/MLR Entry Number"] == 2)

        // The CSV carries the spread, so a one-group value reads as agency-specific and a
        // twenty-group value reads as a NARA-wide vocabulary term.
        let row = census.csvRows().first { $0[0] == "variantControlNumbers[].type" && $0[1] == "HMS/MLR Entry Number" }
        #expect(row?[3] == "2")
        #expect(row?[4] == "59 486")
    }
}

// MARK: - ControlNumberCensusTests

/// Tests the control-number cross-tab — the headline answer to the "agency-specific variant control
/// numbers" question.
struct ControlNumberCensusTests {

    @Test("occurrences and recordsWithValue diverge for a record carrying several of one type")
    func separatesOccurrencesFromRecords() {
        var census = ControlNumberCensus()
        census.ingest([
            CatalogControlNumber(number: "UD-WX 54-A", type: "HMS/MLR Entry Number"),
            CatalogControlNumber(number: "UD-WX 253", type: "HMS/MLR Entry Number"),
            CatalogControlNumber(number: "UD-WX 1502", type: "HMS/MLR Entry Number"),
        ], recordGroup: 59)

        let key = ControlNumberCensus.Key(type: "HMS/MLR Entry Number", note: nil, recordGroup: 59)
        #expect(census.cells[key]?.occurrences == 3)
        #expect(census.cells[key]?.recordsWithValue == 1)
        #expect(census.recordsWithAnyControlNumber == 1)
        #expect(census.totalEntries == 3)
    }

    @Test("An entry with no type is kept, not dropped")
    func keepsUntypedEntries() {
        // Measured: a small number of entries in the export carry a number and no type at all.
        // Dropping them would lose real identifiers.
        var census = ControlNumberCensus()
        census.ingest([CatalogControlNumber(number: "A1 3066", type: nil)], recordGroup: 59)
        #expect(census.typeSummaries[""]?.occurrences == 1)
        #expect(census.crossTabRows().first?[0] == "(no type)")
        #expect(census.crossTabRows().first?[6] == "A1 3066")
    }

    @Test("A lot number under the generic type is not conflated with the specific one")
    func keepsTypesDistinct() {
        // The measured trap: State Department lot files are recorded under BOTH
        // "State Department Lot File Number" and the generic "Agency-Assigned Identifier",
        // distinguishable only by the free-text note. They must stay separate rows so the reader can
        // see both — a filter on either type alone loses a large share of the lots.
        var census = ControlNumberCensus()
        census.ingest([
            CatalogControlNumber(number: "63D135", type: "State Department Lot File Number"),
            CatalogControlNumber(number: "72D289", type: "Agency-Assigned Identifier",
                                 note: "Department of State Lot File Number"),
        ], recordGroup: 59)

        #expect(census.typeSummaries.count == 2)
        let rows = census.crossTabRows()
        #expect(rows.count == 2)
        #expect(rows.contains { $0[0] == "Agency-Assigned Identifier" && $0[1].contains("Lot File") })
    }

    @Test("noteClass groups spellings without rewriting the raw note")
    func classifiesNotesAdditively() {
        // The raw note always travels in its own column; noteClass is a second column beside it, so
        // a wrong classification is visible and correctable rather than baked into the data.
        #expect(ControlNumberCensus.noteClass("Department of State Lot File Number")
                == ControlNumberCensus.noteClass("DEPARTMENT OF STATE, LOT FILE NUMBER"))
        #expect(ControlNumberCensus.noteClass("Dept. of State - Lot File No.")
                != ControlNumberCensus.noteClass("Department of State Lot File Number"))
        #expect(ControlNumberCensus.noteClass(nil) == "")

        var census = ControlNumberCensus()
        census.ingest([CatalogControlNumber(number: "1", type: "T", note: "Raw, Note!")],
                      recordGroup: 1)
        let row = census.crossTabRows()[0]
        #expect(row[1] == "Raw, Note!")        // verbatim
        #expect(row[2] == "raw note")          // additive classification
    }

    @Test("HMS/MLR and Former HMS/MLR stay distinct rows — no substring folding")
    func doesNotFoldRelatedTypes() {
        // The superseded number is precisely the value a researcher must not be handed as current,
        // so it must never merge into the current one.
        var census = ControlNumberCensus()
        census.ingest([
            CatalogControlNumber(number: "P 1", type: "HMS/MLR Entry Number"),
            CatalogControlNumber(number: "P 0", type: "Former HMS/MLR Entry Number"),
        ], recordGroup: 486)
        #expect(census.typeSummaries.count == 2)
    }

    @Test("Type summaries rank by frequency and report record-group spread")
    func summarisesTypes() {
        var census = ControlNumberCensus()
        census.ingest([CatalogControlNumber(number: "1", type: "Common")], recordGroup: 59)
        census.ingest([CatalogControlNumber(number: "2", type: "Common")], recordGroup: 84)
        census.ingest([CatalogControlNumber(number: "3", type: "Rare")], recordGroup: 486)

        let rows = census.typeSummaryRows()
        #expect(rows[0][0] == "Common")
        #expect(rows[0][1] == "2")
        #expect(rows[0][3] == "59 84")
        #expect(rows[1][0] == "Rare")
        #expect(rows[1][3] == "486")
    }

    @Test("Merging preserves both counters and the group spread")
    func merges() {
        var a = ControlNumberCensus()
        a.ingest([CatalogControlNumber(number: "1", type: "T")], recordGroup: 59)
        var b = ControlNumberCensus()
        b.ingest([CatalogControlNumber(number: "2", type: "T")], recordGroup: 84)
        a.merge(b)
        #expect(a.typeSummaries["T"]?.occurrences == 2)
        #expect(a.typeSummaries["T"]?.recordGroups == [59, 84])
        #expect(a.recordsWithAnyControlNumber == 2)
    }
}

// MARK: - CreatorCensusTests

/// Tests the creator inventory.
struct CreatorCensusTests {

    @Test("Keeps creatorType counts apart, because one office is routinely both")
    func separatesCreatorTypes() {
        // Collapsing "Most Recent" and "Predecessor" would hide the succession structure that makes
        // the creator data worth having.
        var census = CreatorCensus()
        let creator = CatalogCreator(naId: "10514123", heading: "Trade and Development Program",
                                     authorityType: "organization", creatorType: "Predecessor")
        census.ingest([creator], recordGroup: 486)
        census.ingest([CatalogCreator(naId: "10514123", heading: "Trade and Development Program",
                                     authorityType: "organization", creatorType: "Most Recent")],
                      recordGroup: 486)

        let entry = census.entries["10514123"]
        #expect(entry?.recordCount == 2)
        #expect(entry?.creatorTypeCounts == ["Predecessor": 1, "Most Recent": 1])
        #expect(census.recordsWithAnyCreator == 2)
    }

    @Test("Exposes the NAID set the authority join needs")
    func exposesReferencedNaIds() {
        var census = CreatorCensus()
        census.ingest([CatalogCreator(naId: "1", heading: "A"),
                       CatalogCreator(naId: "2", heading: "B"),
                       CatalogCreator(heading: "no naId")], recordGroup: 59)
        #expect(census.referencedNaIds == ["1", "2"])
    }

    @Test("A creator active in several record groups is counted once, with its spread")
    func tracksSpread() {
        var census = CreatorCensus()
        for rg in [43, 59, 84] {
            census.ingest([CatalogCreator(naId: "9", heading: "Department of State")],
                          recordGroup: rg)
        }
        #expect(census.entries.count == 1)
        #expect(census.entries["9"]?.recordGroups == [43, 59, 84])
        #expect(census.csvRows()[0][5] == "43 59 84")
    }

    @Test("Merging does not double-count a creator seen in both halves")
    func merges() {
        var a = CreatorCensus()
        a.ingest([CatalogCreator(naId: "9", heading: "State")], recordGroup: 59)
        var b = CreatorCensus()
        b.ingest([CatalogCreator(naId: "9", heading: "State")], recordGroup: 84)
        a.merge(b)
        #expect(a.entries.count == 1)
        #expect(a.entries["9"]?.recordCount == 2)
        #expect(a.entries["9"]?.recordGroups == [59, 84])
    }
}
