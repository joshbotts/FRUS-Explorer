// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
import SQLite3
@testable import FRUSExplorer

// MARK: - Real-TEI corpus access

/// Locates the local Foreign Relations TEI corpus mirror for integration tests.
///
/// These tests index **real published volumes** (not synthetic fixtures) through the
/// full pipeline, so they need a checkout of the Office of the Historian TEI corpus
/// (https://github.com/HistoryAtState/frus) on the local machine. Set the
/// `FRUS_TEI_MIRROR` environment variable to the mirror's `volumes/` directory —
/// via `TEST_RUNNER_FRUS_TEI_MIRROR=…` when invoking `xcodebuild test`. When the
/// variable is unset or the directory is missing, the suite is skipped (CI-safe).
enum RealTEICorpus {
    /// The mirror's `volumes/` directory, or `nil` when unavailable on this machine.
    static var volumesDirectory: URL? {
        guard let path = ProcessInfo.processInfo.environment["FRUS_TEI_MIRROR"],
              !path.isEmpty,
              FileManager.default.fileExists(atPath: path) else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    /// True when the corpus mirror (and the specific volumes these tests index) exist.
    static func hasVolumes(_ volumeIds: [String]) -> Bool {
        guard let dir = volumesDirectory else { return false }
        return volumeIds.allSatisfy {
            FileManager.default.fileExists(atPath: dir.appendingPathComponent("\($0).xml").path)
        }
    }
}

// MARK: - Coverage measurement helpers

/// Source-note coverage metrics for one indexed volume, read straight from the
/// pipeline's SQLite tables.
struct VolumeCoverage {
    /// Total rows in `document_cache` for the volume.
    let totalDocuments: Int
    /// Rows whose `source_note` is non-null and non-empty.
    let withSourceNote: Int
    /// `document_sources` row counts keyed by `citation_era`.
    let eraCounts: [String: Int]
    /// `document_sources` rows with a non-null `classification`.
    let withClassification: Int

    /// Fraction of documents carrying a stored source note (0…1).
    var coverage: Double {
        totalDocuments == 0 ? 0 : Double(withSourceNote) / Double(totalDocuments)
    }
}

/// Reads `VolumeCoverage` for `volumeId` from the test database at `dbURL`.
func measureCoverage(dbURL: URL, volumeId: String) throws -> VolumeCoverage {
    var db: OpaquePointer?
    guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
          let handle = db else {
        sqlite3_close(db)
        throw NSError(domain: "RealTEICoverageTests", code: 1)
    }
    defer { sqlite3_close_v2(handle) }
    let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    /// Runs a single-int query bound to `volumeId`.
    func scalar(_ sql: String) throws -> Int {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw NSError(domain: "RealTEICoverageTests", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(handle))])
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, volumeId, -1, transient)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    let total = try scalar("SELECT COUNT(*) FROM document_cache WHERE volume_id = ?")
    let withNote = try scalar("""
        SELECT COUNT(*) FROM document_cache
        WHERE volume_id = ? AND source_note IS NOT NULL AND source_note != ''
        """)
    let withClassification = try scalar("""
        SELECT COUNT(*) FROM document_sources
        WHERE volume_id = ? AND classification IS NOT NULL
        """)

    var eras: [String: Int] = [:]
    var stmt: OpaquePointer?
    let eraSQL = "SELECT citation_era, COUNT(*) FROM document_sources WHERE volume_id = ? GROUP BY citation_era"
    guard sqlite3_prepare_v2(handle, eraSQL, -1, &stmt, nil) == SQLITE_OK else {
        throw NSError(domain: "RealTEICoverageTests", code: 3)
    }
    defer { sqlite3_finalize(stmt) }
    sqlite3_bind_text(stmt, 1, volumeId, -1, transient)
    while sqlite3_step(stmt) == SQLITE_ROW {
        let era = sqlite3_column_text(stmt, 0).map { String(cString: $0) } ?? "?"
        eras[era] = Int(sqlite3_column_int64(stmt, 1))
    }
    return VolumeCoverage(totalDocuments: total, withSourceNote: withNote,
                          eraCounts: eras, withClassification: withClassification)
}

// MARK: - Test scaffolding (mirrors IndexingPipelineTests helpers)

/// Creates a temporary directory, calls `body`, and cleans up after.
private func withTempDir<T>(_ body: (URL) async throws -> T) async throws -> T {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("FRUSRealTEITests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    return try await body(dir)
}

/// Builds a pipeline backed by a temp database whose volumes directory is the
/// **real TEI mirror** — no fixture copying; the pipeline reads published XML.
private func makeMirrorPipeline(dir: URL) async throws -> (pipeline: IndexingPipeline, dbURL: URL) {
    let dbURL = dir.appendingPathComponent("test.sqlite")
    let volDir = try #require(RealTEICorpus.volumesDirectory)
    let store = try FTS5Store(databaseURL: dbURL)
    let pipeline = try IndexingPipeline(
        fts5Store: store,
        databaseURL: dbURL,
        volumesDirectory: volDir,
        subjectTagStore: SubjectTagStore(entries: [], appearances: []),
        concurrencyLimit: 2
    )
    return (pipeline, dbURL)
}

// MARK: - Suite

/// End-to-end coverage check for Source Explorer Phase 1 (head-nested source-note
/// extraction) against **real published TEI volumes**, per the audit's verification
/// target (a): source-note coverage ≥90% for 1955+ volumes, no pre-1955 regression.
///
/// Skipped unless `FRUS_TEI_MIRROR` points at a local frus corpus `volumes/` mirror
/// (pass `TEST_RUNNER_FRUS_TEI_MIRROR=/path/to/frus/volumes` to `xcodebuild test`).
@Suite("IndexingPipeline — real-TEI source-note coverage (Phase 1)",
       .enabled(if: RealTEICorpus.hasVolumes(["frus1961-63v06", "frus1952-54v01p1"]),
                "requires FRUS_TEI_MIRROR pointing at a local frus TEI volumes mirror"))
struct RealTEICoverageTests {

    /// Head-nested era (1955+ encoding): frus1961-63v06 (Kennedy, foreign economic
    /// policy — the audit's known-good small volume). Before Phase 1 this era stored
    /// source notes for <1% of documents; the target is ≥90%. Also verifies the two
    /// audit-known lot files (66 D 204, 77 D 163) now resolve archival neighbors,
    /// and that `citation_era='structured'` rows exist (zero existed corpus-wide
    /// before the fix).
    @Test("frus1961-63v06: coverage ≥90%, structured rows, known lots resolve neighbors")
    func headNestedEraVolume() async throws {
        try await withTempDir { dir in
            let (pipeline, dbURL) = try await makeMirrorPipeline(dir: dir)
            try await pipeline.indexVolume("frus1961-63v06")

            let cov = try measureCoverage(dbURL: dbURL, volumeId: "frus1961-63v06")
            #expect(cov.totalDocuments > 100, "sanity: the volume has ~120 documents")
            #expect(cov.coverage >= 0.90,
                    "1955+ coverage target ≥90%; got \(cov.withSourceNote)/\(cov.totalDocuments)")

            // The audit found zero structured rows corpus-wide before the fix.
            let structured = cov.eraCounts["structured"] ?? 0
            #expect(structured > 0, "head-nested 'Source:' narratives must yield structured rows")

            // Classification split (S1) fills for real notes ("Secret", "Confidential", …).
            #expect(cov.withClassification > 0, "classification column must fill for real notes")

            // Audit bucket B3: these lots ARE cited in this volume's TEI source notes;
            // before Phase 1 archivalNeighbors returned zero for both.
            for lot in ["66 D 204", "77 D 163"] {
                let r = try await pipeline.archivalNeighbors(
                    forLotFile: lot, recordGroup: nil, series: nil)
                #expect(r.totalCount > 0, "lot \(lot) must resolve archival neighbors")
            }
        }
    }

    /// Pre-1955 control (top-level inline encoding): frus1952-54v01p1. The audit
    /// measured 90% coverage for the 1952–54 subseries before the fix; the head-nested
    /// extraction must not regress it.
    @Test("frus1952-54v01p1: pre-1955 coverage does not regress (≥85%)")
    func pre1955ControlVolume() async throws {
        try await withTempDir { dir in
            let (pipeline, dbURL) = try await makeMirrorPipeline(dir: dir)
            try await pipeline.indexVolume("frus1952-54v01p1")

            let cov = try measureCoverage(dbURL: dbURL, volumeId: "frus1952-54v01p1")
            #expect(cov.totalDocuments > 150, "sanity: the volume has ~227 documents")
            #expect(cov.coverage >= 0.85,
                    "pre-1955 control must hold; got \(cov.withSourceNote)/\(cov.totalDocuments)")
        }
    }
}
