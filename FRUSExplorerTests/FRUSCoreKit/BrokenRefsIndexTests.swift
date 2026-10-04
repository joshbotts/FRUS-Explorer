// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

// MARK: - BrokenRefsIndex decode

struct BrokenRefsIndexTests {

    /// A fixture bundle: an in-document broken ref, a front-matter (`sd:""`) broken ref, a
    /// malformedTarget (kept live), and the same `(sv,t)` under two `sd` values (must fold to one).
    private static let fixtureJSON = """
    {
      "schemaVersion": 1,
      "generated": "2026-07-10",
      "corpusVolumeCount": 694,
      "seriesVolumeCount": 552,
      "totalBroken": 6,
      "fullDetail": true,
      "records": [
        {"sv":"frus1901","sd":"d1","t":"#dX","r":"unknownAnchor","rv":"frus1901","ra":"dX"},
        {"sv":"frus1901","sd":"","t":"frus1877#pg_1077","r":"unknownPage","rv":"frus1877","ra":"pg_1077"},
        {"sv":"frus1909","sd":"","t":"frus1907p1#pg_840","r":"unknownPage","rv":"frus1907p1","ra":"pg_840"},
        {"sv":"frus1909","sd":"d614","t":"frus1907p1#pg_840","r":"unknownPage","rv":"frus1907p1","ra":"pg_840"},
        {"sv":"frus1951v03p2","sd":"","t":"pg_1602","r":"malformedTarget","rv":"frus1951v03p2","ra":"pg_1602"}
      ]
    }
    """

    private static func decodeFixture() throws -> BrokenRefsIndex {
        try JSONDecoder().decode(BrokenRefsIndex.self, from: Data(fixtureJSON.utf8))
    }

    @Test("Top-level metadata decodes; records preserved for export")
    func metadata() throws {
        let index = try Self.decodeFixture()
        #expect(index.schemaVersion == 1)
        #expect(index.generated == "2026-07-10")
        #expect(index.totalBroken == 6)          // the occurrence count from the bundle
        #expect(index.fullDetail == true)
        #expect(index.records.count == 5)        // every record kept for the export, incl. malformed
    }

    @Test("Degradable lookup is volume-scoped and finds front-matter refs regardless of document")
    func volumeScopedLookup() throws {
        let index = try Self.decodeFixture()
        // In-document ref.
        #expect(index.degradableInfo(sourceVolume: "frus1901", rawTarget: "#dX")?.reason == "unknownAnchor")
        // Front-matter ref (sd:"") resolves even though no document context is supplied.
        let fm = index.degradableInfo(sourceVolume: "frus1901", rawTarget: "frus1877#pg_1077")
        #expect(fm?.reason == "unknownPage")
        #expect(fm?.resolvedVolume == "frus1877")
        #expect(fm?.resolvedAnchor == "pg_1077")
        // A ref that resolves is not in the index.
        #expect(index.degradableInfo(sourceVolume: "frus1901", rawTarget: "#d1") == nil)
    }

    @Test("malformedTarget records stay live (excluded from degradation) but remain in records")
    func malformedStaysLive() throws {
        let index = try Self.decodeFixture()
        #expect(index.degradableInfo(sourceVolume: "frus1951v03p2", rawTarget: "pg_1602") == nil)
        #expect(index.records.contains { $0.r == "malformedTarget" })
    }

    @Test("A (sv,t) under two sd values folds to a single degradable entry")
    func collisionFolds() throws {
        let index = try Self.decodeFixture()
        #expect(index.degradableInfo(sourceVolume: "frus1909", rawTarget: "frus1907p1#pg_840") != nil)
        // 5 records → 4 non-malformed → the frus1909 pair folds → 3 distinct degradable keys.
        #expect(index.degradableCount == 3)
    }

    @Test("degradableTargets round-trips the source volume + raw target for the pipeline")
    func degradableTargets() throws {
        let index = try Self.decodeFixture()
        let keys = Set(index.degradableTargets.map { "\($0.sourceVolume)|\($0.rawTarget)" })
        #expect(keys == [
            "frus1901|#dX",
            "frus1901|frus1877#pg_1077",
            "frus1909|frus1907p1#pg_840",
        ])
    }

    @Test("A missing/garbage bundle degrades to an empty index rather than throwing")
    func tolerantDecode() throws {
        let index = try JSONDecoder().decode(BrokenRefsIndex.self, from: Data("{}".utf8))
        #expect(index.records.isEmpty)
        #expect(index.degradableCount == 0)
    }
}

// MARK: - BrokenRefsReportExporter

struct BrokenRefsReportExporterTests {

    private static func index(_ records: String) throws -> BrokenRefsIndex {
        let json = """
        {"schemaVersion":1,"generated":"2026-07-10","corpusVolumeCount":1,"seriesVolumeCount":1,\
        "totalBroken":\(records.isEmpty ? 0 : 1),"fullDetail":true,"records":[\(records)]}
        """
        return try JSONDecoder().decode(BrokenRefsIndex.self, from: Data(json.utf8))
    }

    @Test("CSV emits the reduced header and CRLF rows, sorted by (sv, sd, t)")
    func csvShape() throws {
        let index = try Self.index("""
        {"sv":"frus1910","sd":"","t":"#in3","r":"unknownAnchor","rv":"frus1910","ra":"in3"},
        {"sv":"frus1901","sd":"d1","t":"#dX","r":"unknownAnchor","rv":"frus1901","ra":"dX"}
        """)
        let csv = BrokenRefsReportExporter.csv(from: index)
        let lines = csv.components(separatedBy: "\r\n").filter { !$0.isEmpty }
        #expect(lines.count == 3)  // header + 2
        #expect(lines[0] == "source_volume,source_document,raw_target,reason,resolved_volume,resolved_anchor")
        // Sorted: frus1901 before frus1910.
        #expect(lines[1] == "frus1901,d1,#dX,unknownAnchor,frus1901,dX")
        #expect(lines[2].hasPrefix("frus1910,,#in3,"))   // empty source_document cell
    }

    @Test("A field containing a comma or quote is RFC-4180 quoted and doubled")
    func csvEscaping() throws {
        let index = try Self.index("""
        {"sv":"frus1901","sd":"d1","t":"#a,b","r":"unknownAnchor","rv":null,"ra":"say \\"hi\\""}
        """)
        let csv = BrokenRefsReportExporter.csv(from: index)
        #expect(csv.contains("\"#a,b\""))            // comma → quoted
        #expect(csv.contains("\"say \"\"hi\"\"\""))  // quote → doubled + wrapped
        // nil resolved_volume renders as an empty cell.
        #expect(csv.contains(",unknownAnchor,,"))
    }
}
