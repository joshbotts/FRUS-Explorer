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

/// Tests the streaming CSV reader against the quoting the real export contains: a header
/// row, quoted fields with embedded commas, and a `tei_xml` field with an embedded newline
/// and `""`-escaped quotes (which must not break row boundaries).
struct CitationCSVReaderTests {

    private func withTempCSV(_ contents: String, _ body: (String) throws -> Void) throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("citations-\(UUID().uuidString).csv")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        try body(url.path)
    }

    @Test("Reads the plain_text column across quoted commas, newlines, and escaped quotes")
    func readsPlainText() throws {
        let csv = """
        volume_id,citation_type,ancestor_id,xpath,plain_text,tei_xml
        v1,source-note,d1,xp1,"File No. 1271.","<note>File No. 1271.</note>"
        v2,source-note,d2,xp2,"Source: NARA, RG 59, Lot 64 D 199, Box 5","<note rend=""inline"">a, b
        spanning a newline</note>"
        v3,source-note,d3,xp3,Plain no quotes,xml3
        """
        try withTempCSV(csv) { path in
            var values: [String] = []
            try CitationCSVReader.forEachPlainText(path: path) { values.append($0) }
            #expect(values == [
                "File No. 1271.",
                "Source: NARA, RG 59, Lot 64 D 199, Box 5",
                "Plain no quotes",
            ])
        }
    }

    /// Offline integration check against the real ~200 MB export when present locally
    /// (skipped in CI / on machines without the fixture). Validates that the streaming
    /// reader survives the full file and that distinct-lot extraction matches expectations.
    @Test("Real citations export parses and yields the expected distinct-lot order of magnitude")
    func realExportDistinctLots() throws {
        let path = "/Users/jbotts/Development/citations2.csv"
        guard FileManager.default.fileExists(atPath: path) else { return }  // skip when absent
        var lots: Set<String> = []
        var rows = 0
        try CitationCSVReader.forEachPlainText(path: path) { text in
            rows += 1
            for c in LotFileCitationExtractor.citations(in: text) { lots.insert(c.normalizedLot) }
        }
        #expect(rows > 250_000)        // ~322k citation rows
        #expect(lots.count > 1_500)    // ~1,743 distinct lots
        #expect(lots.count < 3_000)    // sanity ceiling — guards against runaway false matches
    }

    @Test("Feeding reader output to the lot extractor finds the embedded lot")
    func endToEndLotExtraction() throws {
        let csv = """
        volume_id,citation_type,ancestor_id,xpath,plain_text,tei_xml
        v1,source-note,d1,xp1,"CU Files: Lot 63D135 (Entry A1-5072)","<note/>"
        v2,source-note,d2,xp2,"No lot here, just prose","<note/>"
        """
        try withTempCSV(csv) { path in
            var lots: Set<String> = []
            try CitationCSVReader.forEachPlainText(path: path) { text in
                for c in LotFileCitationExtractor.citations(in: text) { lots.insert(c.normalizedLot) }
            }
            #expect(lots == ["63D135"])
        }
    }
}
