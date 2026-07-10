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
    /// so nothing touches the process environment.
    @Test("End-to-end: scans a corpus and writes report + CSV + bundled index")
    func endToEnd() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("crossref-e2e-\(UUID().uuidString)")
        let volumes = root.appendingPathComponent("volumes")
        let out = root.appendingPathComponent("out")
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let v1 = """
        <TEI xml:id="frus1901"><text><body>
        <div type="document" xml:id="d1"><p>\
        <ref target="#d1">self</ref> \
        <ref target="#dX">missing</ref> \
        <ref target="frus1902#d1">cross</ref> \
        <ref target="frusZ#d1">badvol</ref> \
        <ref target="http://x.com">ext</ref>\
        </p></div>
        </body></text></TEI>
        """
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
        #expect(report.totalRefsScanned == 5)
        #expect(report.totalBroken == 2)                       // #dX + frusZ#d1
        #expect(report.totalsByReason["unknownAnchor"] == 1)
        #expect(report.totalsByReason["unknownVolume"] == 1)
        #expect(report.informationalCounts["resolved"] == 2)   // #d1 + frus1902#d1
        #expect(report.informationalCounts["external"] == 1)
        #expect(report.unknownVolumeIds == ["frusZ"])
        #expect(report.generated == "2026-07-10")

        // Records carry precise location + enclosing document.
        let record = try #require(report.records.first { $0.rawTarget == "#dX" })
        #expect(record.sourceVolume == "frus1901")
        #expect(record.sourceDocument == "d1")
        #expect(record.sourceFilename == "frus1901.xml")
        #expect(record.line == 2)
        #expect(record.charOffset > 0)

        // CSV: header + 2 data rows.
        let csv = try String(contentsOf: out.appendingPathComponent("broken-refs-report.csv"), encoding: .utf8)
        let lines = csv.split(separator: "\r\n", omittingEmptySubsequences: true)
        #expect(lines.count == 3)
        #expect(lines[0].hasPrefix("source_volume,source_document,line"))

        // Bundled index: full detail at this size, composite-keyed.
        let indexData = try Data(contentsOf: out.appendingPathComponent("broken-refs-index.json"))
        let index = try JSONDecoder().decode(BrokenRefsIndex.self, from: indexData)
        #expect(index.totalBroken == 2)
        #expect(index.fullDetail == true)
        #expect(index.records.contains { $0.sv == "frus1901" && $0.sd == "d1" && $0.t == "#dX" && $0.r == "unknownAnchor" })
    }
}
