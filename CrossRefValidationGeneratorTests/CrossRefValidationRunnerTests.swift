// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import CrossRefValidationGeneratorCore

struct CrossRefValidationRunnerTests {

    /// Builds a two-volume corpus + manifest in a temp dir, runs the generator, and asserts on the
    /// three artifacts. Uses the parameterized `run(volumesDir:manifestPath:outputDir:generated:)`
    /// so nothing touches the process environment. The fixture exercises the review-confirmed
    /// classes: a front-matter broken ref (nil `sourceDocument` → `sd: ""` sentinel), a duplicated
    /// broken target (index dedup), and an xml:id that exists only inside a comment (must NOT
    /// mask the ref targeting it).
    @Test("End-to-end: scans a corpus and writes report + CSV + deduplicated bundled index")
    func endToEnd() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("crossref-e2e-\(UUID().uuidString)")
        let volumes = root.appendingPathComponent("volumes")
        let out = root.appendingPathComponent("out")
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let v1 = [
            "<TEI xml:id=\"frus1901\"><text>",                                                     // line 1
            "<front><div type=\"section\" xml:id=\"toc\"><p><ref target=\"#nope\">fm</ref></p></div></front>", // line 2
            "<body>",                                                                              // line 3
            "<!-- <div xml:id=\"ghost\"/> -->",                                                    // line 4
            "<div type=\"document\" xml:id=\"d1\"><p><ref target=\"#d1\">a</ref> "                 // line 5
                + "<ref target=\"#dX\">m1</ref> <ref target=\"#dX\">m2</ref> "
                + "<ref target=\"#ghost\">g</ref> <ref target=\"frus1902#d1\">c</ref> "
                + "<ref target=\"frusZ#d1\">bv</ref> <ref target=\"http://x.com\">e</ref></p></div>",
            "</body></text></TEI>",                                                                // line 6
        ].joined(separator: "\n")
        let v2 = """
        <TEI xml:id="frus1902"><text><body>
        <div type="document" xml:id="d1"><p>ok</p></div>
        </body></text></TEI>
        """
        try Data(v1.utf8).write(to: volumes.appendingPathComponent("frus1901.xml"))
        try Data(v2.utf8).write(to: volumes.appendingPathComponent("frus1902.xml"))

        let manifest = """
        [{"volumeId":"frus1901","filename":"frus1901.xml","status":"published"},\
        {"volumeId":"frus1902","filename":"frus1902.xml","status":"published"}]
        """
        let manifestURL = root.appendingPathComponent("manifest.json")
        try Data(manifest.utf8).write(to: manifestURL)

        try CrossRefValidationRunner.run(volumesDir: volumes,
                                         manifestPath: manifestURL.path,
                                         outputDir: out,
                                         generated: "2026-07-10")

        // Report JSON.
        let reportData = try Data(contentsOf: out.appendingPathComponent("broken-refs-report.json"))
        let report = try JSONDecoder().decode(CrossRefValidationReport.self, from: reportData)
        #expect(report.corpusVolumeCount == 2)
        #expect(report.seriesVolumeCount == 2)
        #expect(report.totalRefsScanned == 8)
        // Broken: #nope + #dX ×2 + #ghost (comment-only id must not resolve) + frusZ#d1.
        #expect(report.totalBroken == 5)
        #expect(report.totalsByReason["unknownAnchor"] == 4)
        #expect(report.totalsByReason["unknownVolume"] == 1)
        // Zero-count reasons are still present — the report schema is stable.
        #expect(report.totalsByReason["emptyTarget"] == 0)
        #expect(report.totalsByReason.count == BrokenRefReason.allCases.count)
        #expect(report.informationalCounts["resolved"] == 2)   // #d1 + frus1902#d1
        #expect(report.informationalCounts["external"] == 1)
        #expect(report.unknownVolumeIds == ["frusZ"])
        #expect(report.generated == "2026-07-10")

        // Front-matter record: nil sourceDocument, correct location.
        let frontMatter = try #require(report.records.first { $0.rawTarget == "#nope" })
        #expect(frontMatter.sourceDocument == nil)
        #expect(frontMatter.line == 2)

        // In-document record: precise location + enclosing document.
        let dupRecords = report.records.filter { $0.rawTarget == "#dX" }
        #expect(dupRecords.count == 2)   // the report keeps every occurrence
        #expect(dupRecords.allSatisfy { $0.sourceDocument == "d1" && $0.sourceFilename == "frus1901.xml" })
        #expect(dupRecords[0].line == 5)
        #expect(dupRecords[0].byteOffset > 0)

        // CSV: header + 5 data rows, byte-offset column named for its unit.
        let csv = try String(contentsOf: out.appendingPathComponent("broken-refs-report.csv"), encoding: .utf8)
        let lines = csv.split(separator: "\r\n", omittingEmptySubsequences: true)
        #expect(lines.count == 6)
        #expect(lines[0] == "source_volume,source_document,line,byte_offset,raw_target,reason,resolved_volume,resolved_anchor,source_filename")

        // Bundled index: full detail at this size; records DEDUPLICATED on (sv, sd, t) —
        // 5 occurrences collapse to 4 distinct keys; totalBroken stays the occurrence count.
        let indexData = try Data(contentsOf: out.appendingPathComponent("broken-refs-index.json"))
        let index = try JSONDecoder().decode(BrokenRefsIndex.self, from: indexData)
        #expect(index.totalBroken == 5)
        #expect(index.fullDetail == true)
        #expect(index.records.count == 4)
        #expect(index.records.filter { $0.t == "#dX" }.count == 1)
        // The front-matter record uses the empty-string sentinel for sd.
        #expect(index.records.contains { $0.sv == "frus1901" && $0.sd == "" && $0.t == "#nope" && $0.r == "unknownAnchor" })
        #expect(index.records.contains { $0.sv == "frus1901" && $0.sd == "d1" && $0.t == "#ghost" && $0.r == "unknownAnchor" })
    }

    /// The compact fallback branch: when the full-detail encoding exceeds the threshold, the index
    /// drops `rv`/`ra` and flags `fullDetail: false`.
    @Test("Bundled index falls back to the compact form above the size threshold")
    func compactFallback() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("crossref-compact-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("index.json")

        let broken = [
            BrokenRef(sourceVolume: "frus1901", sourceDocument: "d1", sourceFilename: "frus1901.xml",
                      rawTarget: "#dX", resolvedVolume: "frus1901", resolvedAnchor: "dX",
                      reason: .unknownAnchor, line: 5, byteOffset: 100),
            BrokenRef(sourceVolume: "frus1901", sourceDocument: "d1", sourceFilename: "frus1901.xml",
                      rawTarget: "#dX", resolvedVolume: "frus1901", resolvedAnchor: "dX",
                      reason: .unknownAnchor, line: 9, byteOffset: 200),   // duplicate key
        ]
        try CrossRefValidationRunner.writeBundledIndex(broken: broken, generated: "2026-07-10",
                                                       corpusVolumeCount: 1, seriesVolumeCount: 1,
                                                       to: url, threshold: 10)   // force the fallback

        let index = try JSONDecoder().decode(BrokenRefsIndex.self, from: Data(contentsOf: url))
        #expect(index.fullDetail == false)
        #expect(index.totalBroken == 2)
        #expect(index.records.count == 1)          // deduplicated in the compact form too
        #expect(index.records[0].rv == nil)        // detail dropped
        #expect(index.records[0].ra == nil)
        #expect(index.records[0].r == "unknownAnchor")
    }
}
