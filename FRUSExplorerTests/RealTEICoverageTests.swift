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
/// `FRUS_TEI_MIRROR` environment variable to the mirror's `volumes/` directory.
/// With `xcodebuild test`, `TEST_RUNNER_FRUS_TEI_MIRROR` must be an **environment
/// variable on the xcodebuild process** (env-var prefix form):
///
///     TEST_RUNNER_FRUS_TEI_MIRROR=/path/to/frus/volumes xcodebuild test …
///
/// Passing it as a trailing `KEY=VALUE` build-setting argument does NOT propagate to
/// the test runner — the suite silently skips and the run still reports TEST
/// SUCCEEDED. When the variable is unset or the directory is missing, the suite is
/// skipped (CI-safe).
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
/// (run `TEST_RUNNER_FRUS_TEI_MIRROR=/path/to/frus/volumes xcodebuild test …` —
/// env-var prefix, NOT a trailing xcodebuild argument, which silently skips).
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

// MARK: - Phase 3: front-matter keying & match-path resolution

/// End-to-end verification for Source Explorer Phase 3 against **real published TEI**:
/// front-matter source items must carry usable match keys, and every new match path
/// (normalized lot, decimal / subject-numeric class, presidential library) must
/// resolve archival neighbors through the app's own
/// `makeNeighborsTarget` → `archivalNeighbors` route.
///
/// Volumes: frus1961-63v17 (lot outline + colon/semicolon class-leaf lists) and
/// frus1964-68v20 (subject-numeric `structured` document notes, Johnson Library
/// children, and the audit §2.3 `POL 27 ARAB–ISR` class leaf — its Central Files
/// 1967–69 outline cites it and 100+ of its documents carry it). The audit measured
/// 14.5% of front-matter items keyed corpus-wide before Phase 3; these two volumes
/// key ~59% after it, asserted with margin at ≥50%.
@Suite("Volume sources — real-TEI keying & match paths (Phase 3)",
       .enabled(if: RealTEICorpus.hasVolumes(["frus1961-63v17", "frus1964-68v20"]),
                "requires FRUS_TEI_MIRROR pointing at a local frus TEI volumes mirror"))
struct RealTEIVolumeSourcesTests {

    /// Indexes both volumes, walks every front-matter item through the app's own
    /// target factory + matcher, and asserts the keyed rate and one resolution per
    /// new match path.
    @Test("keyed rate ≥50% and the lot / class / library paths each resolve neighbors")
    func frontMatterKeyingAndResolution() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeMirrorPipeline(dir: dir)
            let volumes = ["frus1961-63v17", "frus1964-68v20"]
            for v in volumes { try await pipeline.indexVolume(v) }

            var items = 0
            var keyedByPath: [String: Int] = [:]
            var firstResolution: [String: Int] = [:]
            for v in volumes {
                for entry in try await pipeline.volumeSources(forVolumeId: v)
                where entry.kind == .item {
                    items += 1
                    guard let t = VolumeSourcesView.makeNeighborsTarget(for: entry) else { continue }
                    let path: String
                    if t.lotFile != nil { path = "lot" }
                    else if t.decimalClass != nil { path = "class" }
                    else if t.repository != nil { path = "library" }
                    else { path = "rg+series" }
                    keyedByPath[path, default: 0] += 1
                    // Query each path's items until one resolves (indexed lookups).
                    if firstResolution[path] == nil {
                        let r = try await pipeline.archivalNeighbors(
                            forLotFile: t.lotFile, recordGroup: t.recordGroup,
                            series: t.series, repository: t.repository,
                            decimalClass: t.decimalClass, limit: 1)
                        if r.totalCount > 0 { firstResolution[path] = r.totalCount }
                    }
                }
            }

            let keyed = keyedByPath.values.reduce(0, +)
            // 439 raw items, minus the 16 published-works rows the bibliography
            // detection now correctly excludes from the archival outline.
            #expect(items > 380, "sanity: the two volumes list ~423 archival source items")
            #expect(Double(keyed) >= 0.5 * Double(items),
                    "keyed rate must stay ≥50% (audit baseline 14.5%); got \(keyed)/\(items)")
            for path in ["lot", "class", "library"] {
                #expect((keyedByPath[path] ?? 0) > 0, "the \(path) path must key items")
                #expect(firstResolution[path] != nil,
                        "at least one \(path)-keyed item must resolve neighbors")
            }

            // The audit §2.3 known class leaf, queried in its TEI en-dash form, must
            // bridge to the hyphen form document notes store and resolve.
            let pol = try await pipeline.archivalNeighbors(
                forLotFile: nil, recordGroup: nil, series: nil,
                repository: nil, decimalClass: "POL 27 ARAB–ISR", limit: 5)
            #expect(pol.totalCount > 0,
                    "POL 27 ARAB–ISR (en-dash) must resolve against hyphen doc rows")
        }
    }
}

// MARK: - Phase 4: S5 local counts against ground truth

/// Rows fetched for the independent S5 ground truth: every `document_sources` row of
/// the temp index, with the columns the match shapes read.
private struct SourceRow {
    let volumeId: String
    let lotFileNorm: String?
    let recordGroup: String?
    let repository: String?
    let seriesName: String?
}

/// Fetches every `document_sources` row from the test database at `dbURL`.
private func fetchAllSourceRows(dbURL: URL) throws -> [SourceRow] {
    var db: OpaquePointer?
    guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
          let handle = db else {
        sqlite3_close(db)
        throw NSError(domain: "RealTEICoverageTests", code: 4)
    }
    defer { sqlite3_close_v2(handle) }
    var stmt: OpaquePointer?
    let sql = "SELECT volume_id, lot_file_norm, record_group, repository, series_name FROM document_sources"
    guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else {
        throw NSError(domain: "RealTEICoverageTests", code: 5)
    }
    defer { sqlite3_finalize(stmt) }
    var rows: [SourceRow] = []
    while sqlite3_step(stmt) == SQLITE_ROW {
        func col(_ i: Int32) -> String? { sqlite3_column_text(stmt, i).map { String(cString: $0) } }
        rows.append(SourceRow(volumeId: col(0) ?? "", lotFileNorm: col(1),
                              recordGroup: col(2), repository: col(3), seriesName: col(4)))
    }
    return rows
}

/// Evaluates `IndexingPipeline.localCollectionStats`' documented match semantics in
/// **Swift string operations** — an implementation independent of the production
/// single-round-trip SQL, so branch assembly, parameter order, and dedup bugs surface
/// as count mismatches.
private func groundTruthStats(rows: [SourceRow], lotFileNorm: String?, repository: String?,
                              recordGroup: String?, names: [String]) -> (docs: Int, volumes: Int) {
    let lot = lotFileNorm?.trimmingCharacters(in: .whitespaces)
    let repo = repository?.trimmingCharacters(in: .whitespaces)
    let isLibrary = repo.map { r in
        let l = r.lowercased()
        return l.contains("library") || l.contains("nixon") || l.contains("hoover institution")
    } ?? false
    let bareRG = recordGroup?.replacingOccurrences(of: #"^RG[\s\-]*"#, with: "",
                                                   options: [.regularExpression, .caseInsensitive])
        .trimmingCharacters(in: .whitespaces)
    // The same first-13-distinct-forms window the production query binds
    // (`IndexingPipeline.collectionMatchFormCap`: canonical name + the artifact's
    // 12-alias cap).
    var seen: Set<String> = []
    var forms: [String] = []
    for form in names {
        let name = form.trimmingCharacters(in: .whitespaces)
        guard name.count >= 4, seen.insert(name.lowercased()).inserted, seen.count <= 13
        else { continue }
        forms.append(name)
    }
    // The library keyword the production query derives ("Eisenhower Library" → "Eisenhower").
    let libraryKeyword = repo.map { r -> String in
        let skip: Set<String> = ["Library", "Presidential", "Institution", "The"]
        let parts = r.components(separatedBy: " ").filter { !skip.contains($0) && $0.count > 2 }
        return parts.first ?? (r.components(separatedBy: " ").first ?? "")
    } ?? ""

    var docs = 0
    var volumes: Set<String> = []
    for row in rows {
        var matched = false
        if let lot, !lot.isEmpty, row.lotFileNorm == lot { matched = true }
        if !matched {
            let series = (row.seriesName ?? "").lowercased()
            for name in forms {
                let n = name.lowercased()
                if isLibrary {
                    guard !libraryKeyword.isEmpty,
                          (row.repository ?? "").lowercased().contains(libraryKeyword.lowercased())
                    else { continue }
                    if series.hasPrefix(String(n.prefix(50))) { matched = true; break }
                } else if let bareRG, !bareRG.isEmpty {
                    guard row.recordGroup == bareRG || row.recordGroup == "RG-\(bareRG)"
                    else { continue }
                    if series == n || series.hasPrefix(n + ",") { matched = true; break }
                } else {
                    if series == n || series.hasPrefix(n + ",") { matched = true; break }
                }
            }
        }
        if matched {
            docs += 1
            volumes.insert(row.volumeId)
        }
    }
    return (docs, volumes.count)
}

/// Owner decision **S5** verification against real volumes: a bundled authority
/// record's local counts (`IndexingPipeline.localCollectionStats`, one SQL round
/// trip) must equal a ground truth computed independently in Swift over every
/// `document_sources` row of a temp index of six published volumes.
///
/// Volumes: six 64 D 199–citing volumes across two subseries (small ones, for test
/// runtime). Exercises both branch families — the lot + RG/series shapes
/// (Lot 64 D 199, Department of State) and the presidential-library shape
/// (Dulles Papers, Eisenhower Library).
/// Six real 64 D 199–citing volumes (1955–57 and 1958–60 subseries) for the S5 suite.
/// File-scope so the `@Suite` enablement condition can reference it without a macro
/// self-reference cycle.
private let s5TestVolumes = ["frus1955-57v04", "frus1955-57v08", "frus1955-57v09",
                             "frus1955-57v23p1", "frus1955-57v23p2", "frus1958-60v17"]

@Suite("Collection authority — S5 local counts vs ground truth (Phase 4)",
       .enabled(if: RealTEICorpus.hasVolumes(s5TestVolumes),
                "requires FRUS_TEI_MIRROR pointing at a local frus TEI volumes mirror"))
struct RealTEIS5LocalStatsTests {

    @Test("localCollectionStats equals the independent Swift ground truth")
    func localStatsMatchGroundTruth() async throws {
        try await withTempDir { dir in
            let (pipeline, dbURL) = try await makeMirrorPipeline(dir: dir)
            for v in s5TestVolumes { try await pipeline.indexVolume(v) }
            let rows = try fetchAllSourceRows(dbURL: dbURL)
            #expect(rows.count > 1000, "sanity: six volumes yield thousands of source rows")

            let index = try #require(CollectionAuthorityStore.shared)

            // (a) Lot + RG/series branches: Lot 64 D 199 (Department of State, RG 59).
            let lotRecord = try #require(index.record(forLotNorm: "64D199"))
            let lotStats = try await pipeline.localCollectionStats(
                lotFileNorm: lotRecord.lotFileNorm, repository: lotRecord.repository,
                recordGroup: lotRecord.recordGroup,
                names: [lotRecord.name] + lotRecord.aliases)
            let lotTruth = groundTruthStats(
                rows: rows, lotFileNorm: lotRecord.lotFileNorm,
                repository: lotRecord.repository, recordGroup: lotRecord.recordGroup,
                names: [lotRecord.name] + lotRecord.aliases)
            #expect(lotStats.documentCount > 0, "these six volumes cite Lot 64 D 199")
            #expect(lotStats.documentCount == lotTruth.docs,
                    "S5 doc count must equal ground truth; got \(lotStats.documentCount) vs \(lotTruth.docs)")
            #expect(lotStats.volumeCount == lotTruth.volumes,
                    "S5 volume count must equal ground truth; got \(lotStats.volumeCount) vs \(lotTruth.volumes)")

            // (b) Presidential-library branch: Dulles Papers (Eisenhower Library).
            let dulles = try #require(index.record(repository: "Eisenhower Library",
                                                   leadingSegment: "Dulles Papers"))
            let dullesStats = try await pipeline.localCollectionStats(
                lotFileNorm: dulles.lotFileNorm, repository: dulles.repository,
                recordGroup: dulles.recordGroup, names: [dulles.name] + dulles.aliases)
            let dullesTruth = groundTruthStats(
                rows: rows, lotFileNorm: dulles.lotFileNorm, repository: dulles.repository,
                recordGroup: dulles.recordGroup, names: [dulles.name] + dulles.aliases)
            #expect(dullesStats.documentCount == dullesTruth.docs,
                    "library-shape doc count must equal ground truth; got \(dullesStats.documentCount) vs \(dullesTruth.docs)")
            #expect(dullesStats.volumeCount == dullesTruth.volumes)

            // (c) One clause, one truth (adversarial review 2026-07-04 finding 3):
            // the record-level Archival Neighbors sheet total must equal the S5
            // count shown beside the button, for both branch families.
            for record in [lotRecord, dulles] {
                let stats = try await pipeline.localCollectionStats(
                    lotFileNorm: record.lotFileNorm, repository: record.repository,
                    recordGroup: record.recordGroup, names: [record.name] + record.aliases)
                let neighbors = try await pipeline.collectionNeighbors(
                    lotFileNorm: record.lotFileNorm, repository: record.repository,
                    recordGroup: record.recordGroup, names: [record.name] + record.aliases,
                    limit: 5)
                #expect(neighbors.totalCount == stats.documentCount,
                        "\(record.id): sheet total \(neighbors.totalCount) must equal S5 count \(stats.documentCount)")
            }
        }
    }
}

// MARK: - Phase 4: generator ↔ app document-note parity

/// Volumes for the note-parity suite: one head-nested-era volume (1955+ encodings,
/// patterns 1/2) and one pre-1955 volume (top-level notes, patterns 3/4) — the same
/// small volumes the Phase-1 coverage suite indexes.
private let noteParityVolumes = ["frus1961-63v06", "frus1952-54v01p1"]

/// Generator ↔ app note-extraction parity (adversarial review 2026-07-04 finding 6):
/// `DocumentNoteExtractor.extract(fromXML:)` (the collection-authority generator's
/// single-pass XML extractor, compiled into this test bundle from the SPM source)
/// must reproduce **exactly** the notes `IndexingPipeline` stores to
/// `document_cache.source_note` — same documents, same normalized text. This pins the
/// two asserted-but-untested divergences the review found (head-nesting depth and the
/// untyped/unclassified `type` semantics).
@Suite("Collection authority — generator/app note-extraction parity (Phase 4)",
       .enabled(if: RealTEICorpus.hasVolumes(noteParityVolumes),
                "requires FRUS_TEI_MIRROR pointing at a local frus TEI volumes mirror"))
struct RealTEINoteParityTests {

    @Test("DocumentNoteExtractor equals the pipeline's stored source notes")
    func extractorMatchesStoredNotes() async throws {
        let volDir = try #require(RealTEICorpus.volumesDirectory)
        try await withTempDir { dir in
            let (pipeline, dbURL) = try await makeMirrorPipeline(dir: dir)
            for v in noteParityVolumes { try await pipeline.indexVolume(v) }
            for volumeId in noteParityVolumes {
                let xml = try Data(contentsOf: volDir.appendingPathComponent("\(volumeId).xml"))
                var generatorNotes: [String: String] = [:]
                for note in DocumentNoteExtractor.extract(fromXML: xml)
                where !note.documentId.isEmpty {
                    generatorNotes[note.documentId] = note.note
                }
                let appNotes = try fetchStoredSourceNotes(dbURL: dbURL, volumeId: volumeId)
                #expect(appNotes.count > 100, "\(volumeId): sanity — the app stored notes")
                // Same documents, both directions…
                let missing = appNotes.keys.filter { generatorNotes[$0] == nil }.sorted()
                #expect(missing.isEmpty,
                        "\(volumeId): app stored notes the generator missed: \(missing.prefix(5))")
                let extra = generatorNotes.keys.filter { appNotes[$0] == nil }.sorted()
                #expect(extra.isEmpty,
                        "\(volumeId): generator extracted notes the app does not store: \(extra.prefix(5))")
                // …and the same text per document.
                var mismatches = 0
                for (docId, appNote) in appNotes where generatorNotes[docId] != appNote {
                    mismatches += 1
                    if mismatches <= 3 {
                        Issue.record("\(volumeId)/\(docId): app『\(appNote.prefix(80))』 vs generator『\((generatorNotes[docId] ?? "<nil>").prefix(80))』")
                    }
                }
                #expect(mismatches == 0, "\(volumeId): \(mismatches) note-text mismatches")
            }
        }
    }
}

/// Fetches every stored, non-empty `document_cache.source_note` for `volumeId`,
/// keyed by document id.
private func fetchStoredSourceNotes(dbURL: URL, volumeId: String) throws -> [String: String] {
    var db: OpaquePointer?
    guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
          let handle = db else {
        sqlite3_close(db)
        throw NSError(domain: "RealTEICoverageTests", code: 6)
    }
    defer { sqlite3_close_v2(handle) }
    var stmt: OpaquePointer?
    let sql = """
        SELECT document_id, source_note FROM document_cache
        WHERE volume_id = ? AND source_note IS NOT NULL AND source_note != ''
          AND is_front_matter = 0
        """
    guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else {
        throw NSError(domain: "RealTEICoverageTests", code: 7)
    }
    defer { sqlite3_finalize(stmt) }
    let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    sqlite3_bind_text(stmt, 1, volumeId, -1, transient)
    var notes: [String: String] = [:]
    while sqlite3_step(stmt) == SQLITE_ROW {
        guard let id = sqlite3_column_text(stmt, 0).map({ String(cString: $0) }),
              let note = sqlite3_column_text(stmt, 1).map({ String(cString: $0) })
        else { continue }
        notes[id] = note
    }
    return notes
}
