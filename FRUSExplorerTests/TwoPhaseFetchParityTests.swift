// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing

@testable import FRUSExplorer

/// A private temp directory, named so it cannot collide with the several `withTempDir` helpers
/// other suites already declare privately.
private func withParityTempDir<T>(_ body: (URL) async throws -> T) async throws -> T {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("two-phase-parity-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    return try await body(dir)
}


/// A volume of `count` documents whose bodies are **byte-identical**, so bm25 scores every one of
/// them the same.
///
/// Ties are the only thing that can distinguish "phase two ordered by score" from "phase two ordered
/// by the ordinal phase one chose", and they do not occur in the shared fixture — a mutation dropping
/// the ordinal survived the first version of this suite. Identical bodies force the case.
private func writeTiedScoreVolume(to url: URL, volumeId: String, count: Int) throws {
    let body = "Identical quartzline text for tie scoring."
    let docs = (1...count).map { index in
        """
              <div type="document" n="\(index)" xml:id="d\(index)">
                <head>\(index). Memo</head>
                <dateline><date when="1971-03-01">March 1, 1971</date></dateline>
                <p>\(body)</p>
              </div>
        """
    }.joined(separator: "\n")
    let xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <TEI xmlns="http://www.tei-c.org/ns/1.0">
      <teiHeader><fileDesc><titleStmt><title>\(volumeId)</title></titleStmt>
      <publicationStmt><date when="2010">2010</date></publicationStmt>
      <sourceDesc><p>Tie fixture</p></sourceDesc></fileDesc></teiHeader>
      <text><body>
        <div type="compilation">
    \(docs)
        </div>
      </body></text>
    </TEI>
    """
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                            withIntermediateDirectories: true)
    try xml.write(to: url, atomically: true, encoding: .utf8)
}

// MARK: - TwoPhaseFetchParityTests

/// R-3a's acceptance criterion: the two-phase fetch returns byte-identical rows, in identical order,
/// to the single-phase shape it replaces.
///
/// ## Why parity is asserted in-process rather than eyeballed
/// The rewrite ranks the match narrow and hydrates only the window that survives, so it changes
/// *when and for which rows* `document_cache` is read. Whether that is observable in the output is a
/// claim about SQLite's join and ordering behaviour, not about the Swift around it — the kind of
/// claim that deserves an equivalence test. `searchDocumentsSinglePhaseForTesting` keeps the old
/// statement reachable so both can run against the same fixture in the same process.
///
/// ## The two things most likely to break, and why each is here
/// **Filters must narrow before the window is drawn.** Phase one keeps the `dc.`/`dd.` joins and the
/// whole `WHERE` clause. Move a filter to phase two and it would apply *after* `LIMIT`, returning
/// fewer rows than asked for from a window drawn over the wrong set — a quiet under-count, not an
/// error. Every filter shape the app can produce is exercised below.
///
/// **Ties.** Phase two re-reads the window and must reproduce phase one's order. The rewrite carries
/// an explicit `ordinal` for that, and the fixture below is 40 byte-identical documents that provably
/// share one bm25 score.
///
/// Stated plainly: **this suite cannot falsify the ordinal.** A mutation replacing
/// `ORDER BY r.ordinal` with `ORDER BY r.score` passes even against the tied fixture, because SQLite
/// currently returns equal-keyed rows in the same order for both shapes. The tie test still earns
/// its place — it pins that the two shapes agree on a tied set, which is the property the app
/// depends on — but the ordinal itself is insurance against a behaviour SQLite does not guarantee
/// and does not presently exhibit, not a guard this suite proves necessary.
@Suite("Two-phase fetch parity")
struct TwoPhaseFetchParityTests {

    /// Compares both fetch shapes for one query, and fails naming the first row that differs.
    private func assertParity(
        _ pipeline: IndexingPipeline,
        label: String,
        corpusMatch: String?,
        userContentMatch: String? = nil,
        filters: SearchSQLFilters,
        limit: Int = 50,
        offset: Int = 0
    ) async throws {
        let twoPhase = try await pipeline.searchDocuments(
            corpusMatch: corpusMatch, userContentMatch: userContentMatch,
            filters: filters, limit: limit, offset: offset)
        let singlePhase = try await pipeline.searchDocumentsSinglePhaseForTesting(
            corpusMatch: corpusMatch, userContentMatch: userContentMatch,
            filters: filters, limit: limit, offset: offset)

        #expect(twoPhase.count == singlePhase.count,
                "\(label): row COUNT differs — \(twoPhase.count) vs \(singlePhase.count). A filter that moved out of the ranking phase applies after LIMIT and silently under-counts.")
        for (index, pair) in zip(twoPhase, singlePhase).enumerated() {
            let (new, old) = pair
            #expect(new.documentId == old.documentId && new.volumeId == old.volumeId,
                    "\(label): row \(index) is a different document — \(new.volumeId)/\(new.documentId) vs \(old.volumeId)/\(old.documentId). Order is not preserved.")
            // Body text is the column the rewrite exists to stop over-fetching; if hydration drifted,
            // this is where it shows.
            #expect(new.bodyText == old.bodyText, "\(label): row \(index) body text differs")
            #expect(new.header == old.header && new.dateline == old.dateline
                        && new.sourceNote == old.sourceNote,
                    "\(label): row \(index) display columns differ")
            #expect(new.dateISO == old.dateISO, "\(label): row \(index) date differs")
            #expect(new.isEditorialNote == old.isEditorialNote
                        && new.isFrontMatter == old.isFrontMatter,
                    "\(label): row \(index) flags differ")
            #expect(new.userTagIds == old.userTagIds && new.subjectTagIds == old.subjectTagIds,
                    "\(label): row \(index) tag ids differ")
        }
    }

    @Test("Every query shape returns identical rows in identical order")
    func everyQueryShapeMatches() async throws {
        try await withParityTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            try writeRealEncodingVolume(to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                                        volumeId: "frus1969-76v01")
            try await pipeline.indexVolume("frus1969-76v01")

            // Control: the corpus really does answer these, so a green run is not eight empty
            // comparisons agreeing with each other. This caught a first draft that searched `the`,
            // which the fixture does not contain — every assertion would have passed on nothing.
            let control = try await pipeline.searchDocuments(
                corpusMatch: "policy", userContentMatch: nil,
                filters: SearchSQLFilters(includeFrontMatter: true), limit: 50, offset: 0)
            #expect(!control.isEmpty, "Precondition: the fixture must produce rows to compare")

            try await assertParity(pipeline, label: "common term",
                                   corpusMatch: "policy",
                                   filters: SearchSQLFilters(includeFrontMatter: true))
            try await assertParity(pipeline, label: "rare term",
                                   corpusMatch: "\"silvermine\"",
                                   filters: SearchSQLFilters(includeFrontMatter: true))
            try await assertParity(pipeline, label: "phrase",
                                   corpusMatch: "\"policy planning\"",
                                   filters: SearchSQLFilters(includeFrontMatter: true))
            try await assertParity(pipeline, label: "NEAR",
                                   corpusMatch: "NEAR(policy documentation, 10)",
                                   filters: SearchSQLFilters(includeFrontMatter: true))
            try await assertParity(pipeline, label: "prefix",
                                   corpusMatch: "polic*",
                                   filters: SearchSQLFilters(includeFrontMatter: true))
            // The filter shapes — each must narrow in phase one.
            try await assertParity(pipeline, label: "front matter excluded",
                                   corpusMatch: "policy",
                                   filters: SearchSQLFilters(includeFrontMatter: false))
            try await assertParity(pipeline, label: "volume scoped",
                                   corpusMatch: "policy",
                                   filters: SearchSQLFilters(volumeIds: ["frus1969-76v01"],
                                                             includeFrontMatter: true))
            try await assertParity(pipeline, label: "volume scope matching nothing",
                                   corpusMatch: "policy",
                                   filters: SearchSQLFilters(volumeIds: ["frus1861v01"],
                                                             includeFrontMatter: true))
        }
    }

    @Test("Paging draws the same windows, including past the end")
    func pagingMatches() async throws {
        try await withParityTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            try writeRealEncodingVolume(to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                                        volumeId: "frus1969-76v01")
            try await pipeline.indexVolume("frus1969-76v01")

            // OFFSET is where a window drawn from the wrong set would show up first: the two shapes
            // can agree on page one and diverge on page two.
            for (limit, offset) in [(1, 0), (1, 1), (2, 1), (50, 0), (2, 999)] {
                try await assertParity(pipeline, label: "limit \(limit) offset \(offset)",
                                       corpusMatch: "policy",
                                       filters: SearchSQLFilters(includeFrontMatter: true),
                                       limit: limit, offset: offset)
            }
        }
    }

    @Test("Rows with equal scores come back in the same order from both shapes")
    func tiedScoresKeepTheirOrder() async throws {
        try await withParityTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            // 40 documents with byte-identical bodies: bm25 cannot distinguish them, so the order
            // among them is whatever the ranking pass chose and nothing else.
            try writeTiedScoreVolume(to: volDir.appendingPathComponent("frus1969-76v02.xml"),
                                     volumeId: "frus1969-76v02", count: 40)
            try await pipeline.indexVolume("frus1969-76v02")

            let control = try await pipeline.searchDocuments(
                corpusMatch: "quartzline", userContentMatch: nil,
                filters: SearchSQLFilters(includeFrontMatter: true), limit: 40, offset: 0)
            #expect(control.count == 40, "Precondition: all 40 tied documents must match")
            // And they really are tied — otherwise this suite would be testing ordinary ranking.
            #expect(Set(control.map(\.score)).count == 1,
                    "Precondition: identical bodies must produce ONE distinct bm25 score, got \(Set(control.map(\.score)).count)")

            // Repeated because an unordered tie is free to come back either way: a single agreement
            // could be luck.
            for attempt in 1...8 {
                try await assertParity(pipeline, label: "tie attempt \(attempt)",
                                       corpusMatch: "quartzline",
                                       filters: SearchSQLFilters(includeFrontMatter: true),
                                       limit: 40, offset: 0)
                try await assertParity(pipeline, label: "tie page 2 attempt \(attempt)",
                                       corpusMatch: "quartzline",
                                       filters: SearchSQLFilters(includeFrontMatter: true),
                                       limit: 10, offset: 10)
            }
        }
    }
}
