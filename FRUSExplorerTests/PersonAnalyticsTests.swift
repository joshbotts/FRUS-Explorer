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

// MARK: - PersonAnalyticsQueryTests

/// Query-layer tests for the CA-5 person-analytics read path in `PersonMentionStore`:
/// `mentionTrajectories`, `topPeopleByMentions`, `rollupsMatchingName`,
/// `datedDocumentTotalsByYear`, and `mentioningDocumentTrajectories`.
///
/// Each test builds a fresh SQLite database (schema seeded via `IndexingPipeline`) and
/// inserts `person_mentions`, `person_rollup(_member)`, and `document_dates` fixtures
/// directly, so the joins are exercised against a real database.
///
/// Version history:
///   1.0 — CA-5 (analytics CA-track): initial implementation
struct PersonAnalyticsQueryTests {

    private func makeFixture() throws -> (dir: URL, dbURL: URL, store: PersonMentionStore) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSPersonAnalytics-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("test.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)

        let fts5 = try FTS5Store(databaseURL: dbURL)
        _ = try IndexingPipeline(
            fts5Store: fts5,
            databaseURL: dbURL,
            volumesDirectory: volDir,
            concurrencyLimit: 1
        )
        let store = try PersonMentionStore(databaseURL: dbURL)
        return (dir, dbURL, store)
    }

    // MARK: - Raw insert helpers

    private func withDB(_ dbURL: URL, _ body: (OpaquePointer?) -> Void) {
        var db: OpaquePointer?
        sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil)
        defer { sqlite3_close_v2(db) }
        body(db)
    }

    private let TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private func insertMention(_ dbURL: URL, volumeId: String, documentId: String, ref: String) {
        withDB(dbURL) { db in
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, "INSERT INTO person_mentions (volume_id, document_id, person_ref) VALUES (?, ?, ?)", -1, &stmt, nil)
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, volumeId, -1, TRANSIENT)
            sqlite3_bind_text(stmt, 2, documentId, -1, TRANSIENT)
            sqlite3_bind_text(stmt, 3, ref, -1, TRANSIENT)
            sqlite3_step(stmt)
        }
    }

    private func insertDate(_ dbURL: URL, volumeId: String, documentId: String, dateISO: String?) {
        withDB(dbURL) { db in
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, "INSERT OR REPLACE INTO document_dates (volume_id, document_id, date_iso) VALUES (?, ?, ?)", -1, &stmt, nil)
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, volumeId, -1, TRANSIENT)
            sqlite3_bind_text(stmt, 2, documentId, -1, TRANSIENT)
            if let d = dateISO { sqlite3_bind_text(stmt, 3, d, -1, TRANSIENT) } else { sqlite3_bind_null(stmt, 3) }
            sqlite3_step(stmt)
        }
    }

    private func insertRollup(_ dbURL: URL, rollupId: Int, canonicalName: String,
                              mentionCount: Int, members: [(volumeId: String, ref: String)]) {
        withDB(dbURL) { db in
            var s1: OpaquePointer?
            sqlite3_prepare_v2(db, """
                INSERT INTO person_rollup (rollup_id, namekey, canonical_name, mention_count)
                VALUES (?, ?, ?, ?)
                """, -1, &s1, nil)
            sqlite3_bind_int64(s1, 1, Int64(rollupId))
            sqlite3_bind_text(s1, 2, canonicalName.lowercased(), -1, TRANSIENT)
            sqlite3_bind_text(s1, 3, canonicalName, -1, TRANSIENT)
            sqlite3_bind_int64(s1, 4, Int64(mentionCount))
            sqlite3_step(s1)
            sqlite3_finalize(s1)
            for m in members {
                var s2: OpaquePointer?
                sqlite3_prepare_v2(db, "INSERT INTO person_rollup_member (volume_id, ref, rollup_id) VALUES (?, ?, ?)", -1, &s2, nil)
                sqlite3_bind_text(s2, 1, m.volumeId, -1, TRANSIENT)
                sqlite3_bind_text(s2, 2, m.ref, -1, TRANSIENT)
                sqlite3_bind_int64(s2, 3, Int64(rollupId))
                sqlite3_step(s2)
                sqlite3_finalize(s2)
            }
        }
    }

    /// Standard fixture: Kissinger (rollup 1, refs across two volumes) and Nixon (rollup 2),
    /// with dated documents in 1969/1970/1971 plus one UNDATED document.
    private func seedStandard(_ dbURL: URL) {
        insertRollup(dbURL, rollupId: 1, canonicalName: "Kissinger, Henry A.", mentionCount: 5,
                     members: [("v1", "p_KHA"), ("v2", "p_HK")])
        insertRollup(dbURL, rollupId: 2, canonicalName: "Nixon, Richard M.", mentionCount: 2,
                     members: [("v1", "p_RN")])

        // Dated documents.
        insertDate(dbURL, volumeId: "v1", documentId: "d1", dateISO: "1969-02-15")
        insertDate(dbURL, volumeId: "v1", documentId: "d2", dateISO: "1969-06-01")
        insertDate(dbURL, volumeId: "v1", documentId: "d3", dateISO: "1970-03-10")
        insertDate(dbURL, volumeId: "v2", documentId: "d4", dateISO: "1971-01-20")
        // An undated document — its mentions must be excluded from the year axis.
        insertDate(dbURL, volumeId: "v1", documentId: "dU", dateISO: nil)

        // Kissinger mentions: 1969 (d1,d2), 1970 (d3), 1971 (d4 via v2 ref), and undated (dU).
        insertMention(dbURL, volumeId: "v1", documentId: "d1", ref: "p_KHA")
        insertMention(dbURL, volumeId: "v1", documentId: "d2", ref: "p_KHA")
        insertMention(dbURL, volumeId: "v1", documentId: "d3", ref: "p_KHA")
        insertMention(dbURL, volumeId: "v2", documentId: "d4", ref: "p_HK")
        insertMention(dbURL, volumeId: "v1", documentId: "dU", ref: "p_KHA")
        // Nixon mentions: 1969 (d1), 1970 (d3).
        insertMention(dbURL, volumeId: "v1", documentId: "d1", ref: "p_RN")
        insertMention(dbURL, volumeId: "v1", documentId: "d3", ref: "p_RN")
    }

    // MARK: - Tests

    @Test("mentionTrajectories buckets mentions by rollup and year, excluding undated documents")
    func mentionTrajectoriesBucketsByYear() async throws {
        let (dir, dbURL, store) = try makeFixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        seedStandard(dbURL)

        let traj = try await store.mentionTrajectories(rollupIds: [1, 2])

        // Kissinger: 1969 → 2 (d1,d2), 1970 → 1 (d3), 1971 → 1 (d4). Undated dU excluded.
        #expect(traj[1] == [1969: 2, 1970: 1, 1971: 1])
        // Nixon: 1969 → 1 (d1), 1970 → 1 (d3).
        #expect(traj[2] == [1969: 1, 1970: 1])
        // The undated Kissinger mention must not appear under any year.
        #expect(traj[1]?.values.reduce(0, +) == 4)  // not 5 — one mention was undated
    }

    @Test("topPeopleByMentions ranks by count and respects the year range")
    func topPeopleRanksAndRespectsRange() async throws {
        let (dir, dbURL, store) = try makeFixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        seedStandard(dbURL)

        // Full span 1969–1971: Kissinger 4 dated mentions, Nixon 2 → Kissinger first.
        let full = try await store.topPeopleByMentions(inYearRange: 1969...1971, limit: 10)
        #expect(full.map(\.rollupId) == [1, 2])
        #expect(full.first?.mentionCount == 4)
        #expect(full.last?.mentionCount == 2)

        // Narrow to 1971 only: only Kissinger's v2/d4 mention falls inside; Nixon absent.
        let narrow = try await store.topPeopleByMentions(inYearRange: 1971...1971, limit: 10)
        #expect(narrow.map(\.rollupId) == [1])
        #expect(narrow.first?.mentionCount == 1)

        // A range with no dated mentions → empty.
        let empty = try await store.topPeopleByMentions(inYearRange: 1980...1990, limit: 10)
        #expect(empty.isEmpty)
    }

    @Test("topPeopleByMentions honors the volume scope")
    func topPeopleHonorsVolumeScope() async throws {
        let (dir, dbURL, store) = try makeFixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        seedStandard(dbURL)

        // Whole corpus (nil): Kissinger 4 dated mentions, Nixon 2.
        let all = try await store.topPeopleByMentions(inYearRange: 1969...1971, limit: 10, volumeIds: nil)
        #expect(all.map(\.rollupId) == [1, 2])
        #expect(all.first(where: { $0.rollupId == 1 })?.mentionCount == 4)

        // Scoped to v1: Kissinger's v2/d4 (1971) mention drops → 3; Nixon is entirely in v1 → 2.
        let v1 = try await store.topPeopleByMentions(inYearRange: 1969...1971, limit: 10, volumeIds: ["v1"])
        #expect(v1.map(\.rollupId) == [1, 2])
        #expect(v1.first(where: { $0.rollupId == 1 })?.mentionCount == 3)
        #expect(v1.first(where: { $0.rollupId == 2 })?.mentionCount == 2)

        // Scoped to v2: only Kissinger's v2/d4 (1971) remains → 1; Nixon has no v2 mention.
        let v2 = try await store.topPeopleByMentions(inYearRange: 1969...1971, limit: 10, volumeIds: ["v2"])
        #expect(v2.map(\.rollupId) == [1])
        #expect(v2.first?.mentionCount == 1)

        // An empty scope means "no filter" — same as nil (whole corpus).
        let emptyScope = try await store.topPeopleByMentions(inYearRange: 1969...1971, limit: 10, volumeIds: [])
        #expect(emptyScope.map(\.rollupId) == [1, 2])
    }

    @Test("mentionTrajectories honors the volume scope")
    func mentionTrajectoriesHonorsVolumeScope() async throws {
        let (dir, dbURL, store) = try makeFixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        seedStandard(dbURL)

        // Scoped to v1: Kissinger keeps 1969 (d1,d2) and 1970 (d3); 1971 (v2/d4) drops out.
        let v1 = try await store.mentionTrajectories(rollupIds: [1], volumeIds: ["v1"])
        #expect(v1[1] == [1969: 2, 1970: 1])

        // Scoped to v2: only the 1971 mention (v2/d4) survives.
        let v2 = try await store.mentionTrajectories(rollupIds: [1], volumeIds: ["v2"])
        #expect(v2[1] == [1971: 1])
    }

    @Test("topPeopleByMentions honors the limit")
    func topPeopleHonorsLimit() async throws {
        let (dir, dbURL, store) = try makeFixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        seedStandard(dbURL)

        let limited = try await store.topPeopleByMentions(inYearRange: 1969...1971, limit: 1)
        #expect(limited.count == 1)
        #expect(limited.first?.rollupId == 1)  // the most-mentioned
    }

    @Test("rollupsMatchingName searches canonical names, ordered by mention count")
    func rollupSearchByName() async throws {
        let (dir, dbURL, store) = try makeFixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        seedStandard(dbURL)

        let hits = try await store.rollupsMatchingName("i")  // matches Kissinger + Nixon
        #expect(hits.count == 2)
        // Ordered by mention_count DESC: Kissinger (5) before Nixon (2).
        #expect(hits.first?.canonicalName == "Kissinger, Henry A.")

        let one = try await store.rollupsMatchingName("Nixon")
        #expect(one.map(\.canonicalName) == ["Nixon, Richard M."])

        #expect(try await store.rollupsMatchingName("   ").isEmpty)
    }

    @Test("datedDocumentTotalsByYear counts only dated documents")
    func datedTotalsCountsDatedOnly() async throws {
        let (dir, dbURL, store) = try makeFixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        seedStandard(dbURL)

        let totals = try await store.datedDocumentTotalsByYear()
        // 1969: d1,d2 → 2; 1970: d3 → 1; 1971: d4 → 1. The undated dU is not counted.
        #expect(totals == [1969: 2, 1970: 1, 1971: 1])
    }

    @Test("share numerator and denominator are both dated-only, so no share exceeds 100%")
    func shareNeverExceeds100Percent() async throws {
        let (dir, dbURL, store) = try makeFixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        seedStandard(dbURL)

        let numer = try await store.mentioningDocumentTrajectories(rollupIds: [1, 2])
        let denom = try await store.datedDocumentTotalsByYear()

        // For every (rollup, year), the distinct dated documents mentioning the person
        // cannot exceed the total dated documents that year — share is always in 0...1.
        for (_, byYear) in numer {
            for (year, docs) in byYear {
                let total = try #require(denom[year], "every mentioned year must have a dated total")
                #expect(docs <= total, "numerator (\(docs)) must not exceed denominator (\(total)) in \(year)")
            }
        }

        // Concretely: Kissinger in 1969 mentions 2 documents out of 2 dated → exactly 100%.
        #expect(numer[1]?[1969] == 2)
        #expect(denom[1969] == 2)
    }

    @Test("empty rollup list yields empty trajectories")
    func emptyRollupIds() async throws {
        let (dir, dbURL, store) = try makeFixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        seedStandard(dbURL)

        #expect(try await store.mentionTrajectories(rollupIds: []).isEmpty)
        #expect(try await store.mentioningDocumentTrajectories(rollupIds: []).isEmpty)
    }

    // MARK: - Co-Mention Queries (CA-8)

    /// Co-mention fixture: three people (Kissinger 1, Nixon 2, Rogers 3) sharing documents
    /// in various combinations, plus one undated shared document.
    /// - d1 (1969): Kissinger + Nixon + Rogers  → all three pairwise co-mention
    /// - d2 (1969): Kissinger + Nixon           → K-N again (2nd shared doc)
    /// - d3 (1970): Kissinger + Nixon           → K-N again (3rd shared doc)
    /// - d4 (1971): Kissinger + Rogers          → K-R again
    /// - dU (undated): Kissinger + Nixon        → excluded from the timeline, counted for ego
    private func seedCoMention(_ dbURL: URL) {
        insertRollup(dbURL, rollupId: 1, canonicalName: "Kissinger, Henry A.", mentionCount: 9,
                     members: [("v1", "p_KHA")])
        insertRollup(dbURL, rollupId: 2, canonicalName: "Nixon, Richard M.", mentionCount: 6,
                     members: [("v1", "p_RN")])
        insertRollup(dbURL, rollupId: 3, canonicalName: "Rogers, William P.", mentionCount: 4,
                     members: [("v1", "p_WPR")])

        insertDate(dbURL, volumeId: "v1", documentId: "d1", dateISO: "1969-01-01")
        insertDate(dbURL, volumeId: "v1", documentId: "d2", dateISO: "1969-06-01")
        insertDate(dbURL, volumeId: "v1", documentId: "d3", dateISO: "1970-02-01")
        insertDate(dbURL, volumeId: "v1", documentId: "d4", dateISO: "1971-03-01")
        insertDate(dbURL, volumeId: "v1", documentId: "dU", dateISO: nil)

        // d1: all three.
        insertMention(dbURL, volumeId: "v1", documentId: "d1", ref: "p_KHA")
        insertMention(dbURL, volumeId: "v1", documentId: "d1", ref: "p_RN")
        insertMention(dbURL, volumeId: "v1", documentId: "d1", ref: "p_WPR")
        // d2, d3: Kissinger + Nixon.
        insertMention(dbURL, volumeId: "v1", documentId: "d2", ref: "p_KHA")
        insertMention(dbURL, volumeId: "v1", documentId: "d2", ref: "p_RN")
        insertMention(dbURL, volumeId: "v1", documentId: "d3", ref: "p_KHA")
        insertMention(dbURL, volumeId: "v1", documentId: "d3", ref: "p_RN")
        // d4: Kissinger + Rogers.
        insertMention(dbURL, volumeId: "v1", documentId: "d4", ref: "p_KHA")
        insertMention(dbURL, volumeId: "v1", documentId: "d4", ref: "p_WPR")
        // dU (undated): Kissinger + Nixon.
        insertMention(dbURL, volumeId: "v1", documentId: "dU", ref: "p_KHA")
        insertMention(dbURL, volumeId: "v1", documentId: "dU", ref: "p_RN")
    }

    @Test("topCoMentionedPeople counts DISTINCT shared documents, excludes the focus itself, orders and caps")
    func topCoMentionedOrderingAndCap() async throws {
        let (dir, dbURL, store) = try makeFixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        seedCoMention(dbURL)

        // Focus = Kissinger (1). Nixon shares d1,d2,d3,dU = 4 docs; Rogers shares d1,d4 = 2.
        let partners = try await store.topCoMentionedPeople(forRollupId: 1, limit: 10)
        #expect(partners.map(\.rollupId) == [2, 3])            // Nixon (4) before Rogers (2)
        #expect(partners.first?.sharedDocuments == 4)          // distinct docs, incl. undated dU
        #expect(partners.last?.sharedDocuments == 2)
        // The focus person is never listed as their own partner.
        #expect(!partners.contains { $0.rollupId == 1 })

        // Cap: limit 1 returns only the top partner (no silent extra rows).
        let capped = try await store.topCoMentionedPeople(forRollupId: 1, limit: 1)
        #expect(capped.count == 1)
        #expect(capped.first?.rollupId == 2)
    }

    @Test("coMentionEdges returns unordered pairs a<b with distinct-document weights, bounded to the id set")
    func coMentionEdgesDedupAndBound() async throws {
        let (dir, dbURL, store) = try makeFixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        seedCoMention(dbURL)

        let edges = try await store.coMentionEdges(amongRollupIds: [1, 2, 3])
        // Every emitted pair has a < b (each unordered pair once).
        for e in edges { #expect(e.a < e.b) }
        let byPair = Dictionary(uniqueKeysWithValues: edges.map { ("\($0.a)-\($0.b)", $0.sharedDocuments) })
        #expect(byPair["1-2"] == 4)   // K-N: d1,d2,d3,dU
        #expect(byPair["1-3"] == 2)   // K-R: d1,d4
        #expect(byPair["2-3"] == 1)   // N-R: only d1
        #expect(edges.count == 3)

        // Bounding: restricting to {1,3} must NOT surface the 1-2 or 2-3 pairs.
        let subset = try await store.coMentionEdges(amongRollupIds: [1, 3])
        #expect(subset.map { "\($0.a)-\($0.b)" } == ["1-3"])

        // Fewer than two ids → empty (no cartesian).
        #expect(try await store.coMentionEdges(amongRollupIds: [1]).isEmpty)
        #expect(try await store.coMentionEdges(amongRollupIds: []).isEmpty)
    }

    @Test("coMentionTimeline buckets shared documents by dated year, excluding undated docs and self-pairs")
    func coMentionTimelineBucketing() async throws {
        let (dir, dbURL, store) = try makeFixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        seedCoMention(dbURL)

        // Kissinger (1) × Nixon (2): 1969 → d1,d2 = 2; 1970 → d3 = 1. dU (undated) excluded.
        let kn = try await store.coMentionTimeline(rollupA: 1, rollupB: 2)
        #expect(kn == [1969: 2, 1970: 1])
        // The undated shared document must not appear under any year.
        #expect(kn.values.reduce(0, +) == 3)   // not 4 — dU excluded

        // Kissinger (1) × Rogers (3): 1969 → d1 = 1; 1971 → d4 = 1.
        let kr = try await store.coMentionTimeline(rollupA: 1, rollupB: 3)
        #expect(kr == [1969: 1, 1971: 1])

        // A person is not in a relationship with themselves.
        #expect(try await store.coMentionTimeline(rollupA: 1, rollupB: 1).isEmpty)
    }
}

// MARK: - PersonRelationshipMathTests (CA-8)

/// Tests for the pure `PersonRelationshipMath` transforms (year-range filter + decade sum).
///
/// Version history:
///   1.0 — CA-8 (analytics CA-track): initial implementation
struct PersonRelationshipMathTests {

    @Test("points filters to the year range and sorts by year")
    func pointsFilterAndSort() {
        let timeline = [1971: 1, 1969: 3, 1980: 9]
        let points = PersonRelationshipMath.points(timeline: timeline, range: 1969...1975)
        #expect(points.map(\.year) == [1969, 1971])   // sorted, 1980 filtered out
        #expect(points.first?.coMentions == 3)
    }

    @Test("bucketByDecade sums co-mention counts within a decade")
    func decadeSum() {
        let points = [
            PersonRelationshipPoint(year: 1969, coMentions: 2),
            PersonRelationshipPoint(year: 1961, coMentions: 3),
            PersonRelationshipPoint(year: 1972, coMentions: 4),
        ]
        let bucketed = PersonRelationshipMath.bucketByDecade(points)
        let byDecade = Dictionary(uniqueKeysWithValues: bucketed.map { ($0.year, $0.coMentions) })
        #expect(byDecade[1960] == 5)   // 2 + 3
        #expect(byDecade[1970] == 4)
        #expect(bucketed.map(\.year) == [1960, 1970])   // sorted
    }
}

// MARK: - PersonCoMentionPhysicsTests (CA-8)

/// Determinism + termination checks for the co-mention ego-graph physics.
///
/// Version history:
///   1.0 — CA-8 (analytics CA-track): initial implementation
@MainActor
struct PersonCoMentionPhysicsTests {

    @Test("runPhysics pins the focus at centre and is deterministic for fixed inputs")
    func physicsPinsAndDeterministic() {
        let size = CGSize(width: 400, height: 400)
        let ids = [1, 2, 3]
        let edges = [
            PersonCoMentionEdge(a: 1, b: 2, sharedDocuments: 3),
            PersonCoMentionEdge(a: 1, b: 3, sharedDocuments: 1),
        ]
        let initial: [Int: CGPoint] = [
            1: CGPoint(x: 200, y: 200),
            2: CGPoint(x: 300, y: 200),
            3: CGPoint(x: 100, y: 200),
        ]
        let out1 = PersonCoMentionGraphViewModel.runPhysics(
            ids: ids, centralId: 1, edges: edges, positions: initial, size: size, iterations: 100)
        let out2 = PersonCoMentionGraphViewModel.runPhysics(
            ids: ids, centralId: 1, edges: edges, positions: initial, size: size, iterations: 100)

        // Focus pinned exactly at centre.
        #expect(out1[1] == CGPoint(x: 200, y: 200))
        // Deterministic: same inputs → identical positions.
        #expect(out1 == out2)
        // Partners stay inside the padded canvas bounds (48pt pad).
        for id in [2, 3] {
            let p = try! #require(out1[id])
            #expect(p.x >= 48 && p.x <= size.width - 48)
            #expect(p.y >= 48 && p.y <= size.height - 48)
        }
    }
}

// MARK: - PersonAnalyticsMathTests

/// Tests for the pure `PersonAnalyticsMath` transforms (flatten / normalize / decade bucket).
///
/// Version history:
///   1.0 — CA-5 (analytics CA-track): initial implementation
struct PersonAnalyticsMathTests {

    @Test("rawPoints flattens and filters to the year range")
    func rawPointsFilters() {
        let traj = [1: [1969: 3, 1970: 5, 1980: 9]]
        let names = [1: "Kissinger"]
        let points = PersonAnalyticsMath.rawPoints(trajectories: traj, names: names, range: 1969...1975)
        #expect(points.count == 2)  // 1980 filtered out
        #expect(points.contains(PersonTrajectoryPoint(rollupId: 1, name: "Kissinger", year: 1969, value: 3)))
        #expect(!points.contains { $0.year == 1980 })
    }

    @Test("sharePoints divides by the year's dated total and clamps to 0...1")
    func sharePointsClamps() {
        let numer = [1: [1969: 2, 1970: 1]]
        let totals = [1969: 4, 1970: 1]
        let points = PersonAnalyticsMath.sharePoints(mentioningDocs: numer, totals: totals,
                                                     names: [1: "K"], range: 1900...2000)
        let byYear = Dictionary(uniqueKeysWithValues: points.map { ($0.year, $0.value) })
        #expect(byYear[1969] == 0.5)   // 2 / 4
        #expect(byYear[1970] == 1.0)   // 1 / 1 → exactly 100%, not more
        for p in points { #expect(p.value <= 1.0) }
    }

    @Test("sharePoints skips years with no or zero denominator")
    func sharePointsSkipsMissingDenominator() {
        let numer = [1: [1969: 2, 1971: 3]]
        let totals = [1969: 4]  // 1971 missing; simulate a zero elsewhere
        let points = PersonAnalyticsMath.sharePoints(mentioningDocs: numer, totals: totals,
                                                     names: [1: "K"], range: 1900...2000)
        #expect(points.map(\.year) == [1969])  // 1971 dropped (no denominator)
    }

    @Test("bucketByDecade sums raw values but averages shares")
    func decadeBucketing() {
        let raw = [
            PersonTrajectoryPoint(rollupId: 1, name: "K", year: 1969, value: 2),
            PersonTrajectoryPoint(rollupId: 1, name: "K", year: 1961, value: 3),
        ]
        let summed = PersonAnalyticsMath.bucketByDecade(raw, isShare: false)
        #expect(summed.count == 1)
        #expect(summed.first?.year == 1960)
        #expect(summed.first?.value == 5)  // 2 + 3

        let shares = [
            PersonTrajectoryPoint(rollupId: 1, name: "K", year: 1969, value: 0.4),
            PersonTrajectoryPoint(rollupId: 1, name: "K", year: 1961, value: 0.2),
        ]
        let averaged = PersonAnalyticsMath.bucketByDecade(shares, isShare: true)
        #expect(averaged.first?.value == 0.30000000000000004)  // (0.4 + 0.2) / 2, floating point
    }
}
