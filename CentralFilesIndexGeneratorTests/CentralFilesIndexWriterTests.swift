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

/// Tests that the bundled index round-trips through JSON and writes deterministically.
struct CentralFilesIndexWriterTests {

    private func sampleIndex() -> CentralFilesIndex {
        CentralFilesIndex(
            generated: "2026-06-15",
            numericalFile: NumericalFileIndex(
                seriesNaId: "654171", microfilm: "M862",
                rolls: [
                    NumericalFileRoll(naId: "19779414", title: "Numerical File: 7179-7187",
                                      caseStart: 7179, caseEnd: 7187,
                                      catalogURL: "https://catalog.archives.gov/id/19779414"),
                ]))
    }

    @Test("CentralFilesIndex round-trips through JSON")
    func roundTrips() throws {
        let index = sampleIndex()
        let data = try JSONEncoder().encode(index)
        let decoded = try JSONDecoder().decode(CentralFilesIndex.self, from: data)
        #expect(decoded == index)
        #expect(decoded.schemaVersion == CentralFilesIndex.currentSchemaVersion)
        #expect(decoded.numericalFile.roll(forFileNumber: "7187")?.naId == "19779414")
    }

    @Test("Writer produces a file that decodes back to the same index")
    func writesAndReads() throws {
        let index = sampleIndex()
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("central-files-test-\(UUID().uuidString)", isDirectory: true)
        let path = dir.appendingPathComponent("central-files-index.json").path
        defer { try? FileManager.default.removeItem(at: dir) }

        try CentralFilesIndexWriter.write(index, to: path)
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let decoded = try JSONDecoder().decode(CentralFilesIndex.self, from: data)
        #expect(decoded == index)
    }

    @Test("Output is byte-for-byte stable across encodes (deterministic diffs)")
    func deterministicOutput() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let a = try encoder.encode(sampleIndex())
        let b = try encoder.encode(sampleIndex())
        #expect(a == b)
    }
}
