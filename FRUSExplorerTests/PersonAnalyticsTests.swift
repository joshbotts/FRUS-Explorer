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

// MARK: - PersonCoMentionHoverSelectionTests (#1383, #1385)

/// The co-mention graph's hover and click rules, driven through the view model methods the view's
/// closures call (#1383), plus the cap footer (#1385).
///
/// On macOS each node's hit area wrote the pointer's hover into `selectedPartnerId`, the property
/// the click writes and the info dock reads, so crossing a node replaced the clicked partner and a
/// click on a node the pointer had just entered cleared it. Each rule the fix states has a fixture
/// of its own: the pinned partner survives a hover elsewhere, a hover followed by a click pins,
/// the dock previews the hovered node and returns to the pinned one, a late exit from an earlier
/// node leaves the later node's preview alone, hover alone pins nothing, a click on the pinned
/// node empties the dock at once, and a reload drops a hover whose node is gone.
///
/// A click drops the hover whatever it names and whichever way the click toggles, and that takes
/// two fixtures more, because each half has a plausible partial version that passes the rest: a
/// click on one node while a stale hover names ANOTHER (clearing only a hover on the clicked node
/// leaves the stale one masking the click — the Session 162 failure), and an unpin after the
/// pointer re-enters the pinned node (clearing only when the click pins leaves the dock on the
/// unpinned node's preview). The unpin fixture above cannot tell: its first click already clears.
///
/// Version history:
///   1.0 — 2026-09-23: #1383 hover separated from the clicked selection; #1385 the cap footer
///   1.1 — 2026-09-24: #1383 review — a click under another node's stale hover, and an unpin
///          after re-entry, one fixture each
@MainActor
struct PersonCoMentionHoverSelectionTests {

    private let a = 11, b = 12, c = 13

    @Test("A hover over another node and off it leaves the clicked partner pinned")
    func hoverElsewhereKeepsTheClickedPartner() {
        let vm = PersonCoMentionGraphViewModel(focusRollupId: 1, focusName: "Focus")
        vm.toggleSelection(a)
        vm.hoverChanged(b, hovering: true)
        vm.hoverChanged(b, hovering: false)
        #expect(vm.selectedPartnerId == a)
        #expect(vm.displayedPartnerId == a)
    }

    @Test("A click on the node the pointer has just entered pins it, not clears it")
    func clickAfterHoverPins() {
        let vm = PersonCoMentionGraphViewModel(focusRollupId: 1, focusName: "Focus")
        vm.hoverChanged(a, hovering: true)
        vm.toggleSelection(a)
        #expect(vm.selectedPartnerId == a)
        #expect(vm.displayedPartnerId == a)
    }

    @Test("The dock previews the hovered node, then returns to the clicked one")
    func dockPreviewsThenReturns() {
        let vm = PersonCoMentionGraphViewModel(focusRollupId: 1, focusName: "Focus")
        vm.toggleSelection(a)
        vm.hoverChanged(b, hovering: true)
        #expect(vm.displayedPartnerId == b)
        #expect(vm.selectedPartnerId == a)
        vm.hoverChanged(b, hovering: false)
        #expect(vm.displayedPartnerId == a)
    }

    @Test("An exit from an earlier node arriving after the next node's entry keeps that node's preview")
    func lateExitKeepsTheLaterPreview() {
        let vm = PersonCoMentionGraphViewModel(focusRollupId: 1, focusName: "Focus")
        vm.toggleSelection(c)
        vm.hoverChanged(a, hovering: true)
        vm.hoverChanged(b, hovering: true)
        vm.hoverChanged(a, hovering: false)
        #expect(vm.hoveredPartnerId == b)
        #expect(vm.displayedPartnerId == b)
        #expect(vm.selectedPartnerId == c)
    }

    @Test("A hover alone pins nothing: the dock is empty once the pointer leaves")
    func hoverAlonePinsNothing() {
        let vm = PersonCoMentionGraphViewModel(focusRollupId: 1, focusName: "Focus")
        vm.hoverChanged(a, hovering: true)
        vm.hoverChanged(a, hovering: false)
        #expect(vm.selectedPartnerId == nil)
        #expect(vm.displayedPartnerId == nil)
    }

    @Test("A click that unpins the node under the pointer empties the dock at once")
    func unpinUnderThePointerEmptiesTheDock() {
        let vm = PersonCoMentionGraphViewModel(focusRollupId: 1, focusName: "Focus")
        vm.hoverChanged(a, hovering: true)
        vm.toggleSelection(a)
        vm.toggleSelection(a)
        #expect(vm.selectedPartnerId == nil)
        #expect(vm.displayedPartnerId == nil)
    }

    @Test("A click on one node while another is hovered selects the clicked node and drops the hover")
    func clickUnderAnotherNodesHoverSelectsTheClickedNode() {
        let vm = PersonCoMentionGraphViewModel(focusRollupId: 1, focusName: "Focus")
        // A hover on b whose exit never arrived, then a click on a.
        vm.hoverChanged(b, hovering: true)
        vm.toggleSelection(a)
        #expect(vm.selectedPartnerId == a)
        #expect(vm.hoveredPartnerId == nil)
        #expect(vm.displayedPartnerId == a)
    }

    @Test("A click that unpins the node after the pointer re-enters it empties the dock at once")
    func unpinAfterReenteringThePinnedNodeEmptiesTheDock() {
        let vm = PersonCoMentionGraphViewModel(focusRollupId: 1, focusName: "Focus")
        vm.toggleSelection(a)
        // Off the node and back on: the hover is live again when the unpinning click lands.
        vm.hoverChanged(a, hovering: false)
        vm.hoverChanged(a, hovering: true)
        vm.toggleSelection(a)
        #expect(vm.selectedPartnerId == nil)
        #expect(vm.hoveredPartnerId == nil)
        #expect(vm.displayedPartnerId == nil)
    }

    @Test("A reload drops the hover, whose node may be gone")
    func loadDropsTheHover() async throws {
        let (dir, _, store) = try makeCoMentionStore(partners: 2)
        defer { try? FileManager.default.removeItem(at: dir) }
        let vm = PersonCoMentionGraphViewModel(focusRollupId: 1, focusName: "Focus")
        vm.hoverChanged(a, hovering: true)
        await vm.load(from: store)
        #expect(vm.error == nil)
        #expect(vm.partners.count == 2)
        #expect(vm.hoveredPartnerId == nil)
        #expect(vm.displayedPartnerId == nil)
    }

    @Test("The cap footer reads the probe's lower bound as \"(of 25+)\", with no space before the parenthesis")
    func capFooterReadsTheLowerBound() async throws {
        // Thirty partners: more than the probe can see, so the footer must say "25+", not 30.
        let (dir, _, store) = try makeCoMentionStore(partners: 30)
        defer { try? FileManager.default.removeItem(at: dir) }
        let vm = PersonCoMentionGraphViewModel(focusRollupId: 1, focusName: "Focus")
        await vm.load(from: store)
        #expect(vm.error == nil)
        #expect(vm.partners.count == PersonCoMentionGraphViewModel.partnerLimit)
        #expect(vm.totalPartnerCount == PersonCoMentionGraphViewModel.partnerLimit + 1)
        #expect(vm.capApplied)
        #expect(vm.capDisclosure
                == "Showing the top 24 co-mentioned people (of 25+) by shared-document count.")
    }

    // MARK: - Fixture

    /// A fixture that could not be built — the database would not open or an insert failed.
    private struct FixtureError: Error {
        /// What failed, with SQLite's own message where there is one.
        let message: String
    }

    /// A store holding one document that mentions the focus person (rollup 1) and `partners`
    /// others (rollups 2…), so every partner shares exactly one document with the focus.
    private func makeCoMentionStore(partners: Int) throws -> (dir: URL, dbURL: URL, store: PersonMentionStore) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSCoMentionHover-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("test.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        let fts5 = try FTS5Store(databaseURL: dbURL)
        _ = try IndexingPipeline(fts5Store: fts5, databaseURL: dbURL,
                                 volumesDirectory: volDir, concurrencyLimit: 1)

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
              let db else {
            throw FixtureError(message: "co-mention fixture: cannot open")
        }
        defer { sqlite3_close_v2(db) }
        var statements: [String] = []
        for rollup in 1...(partners + 1) {
            let name = String(format: "Person %02d", rollup)
            statements.append("INSERT INTO person_rollup (rollup_id, namekey, canonical_name, mention_count) VALUES (\(rollup), '\(name.lowercased())', '\(name)', 1)")
            statements.append("INSERT INTO person_rollup_member (volume_id, ref, rollup_id) VALUES ('v1', 'p_\(rollup)', \(rollup))")
            statements.append("INSERT INTO person_mentions (volume_id, document_id, person_ref) VALUES ('v1', 'd1', 'p_\(rollup)')")
        }
        for sql in statements {
            guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
                throw FixtureError(message: "co-mention fixture: \(String(cString: sqlite3_errmsg(db)))")
            }
        }
        return (dir, dbURL, try PersonMentionStore(databaseURL: dbURL))
    }
}

// MARK: - GraphNodeLabelTests (#1384)

/// The shared node-label rules (`GraphNodeLabels`) the co-mention, volume connection and archival
/// network graphs draw through (#1384), one fixture per rule.
///
/// The Mac capture that filed #1384 showed both failures at once: every name was its first 14
/// characters with nothing marking the cut ("Bohlen, Charle"), and nothing kept labels apart, so
/// "Bruce, David K" and "Truman, Harry" were drawn end to end as one string and "Kennan, George"
/// over "Bohlen, Charle". So the cut has three fixtures (a name that fits, a cut at a word
/// boundary, and the hard cut when no boundary falls within the limit), and the placement has one
/// per rule: two labels that overlap place one, and it is the higher-ranked; two that merely touch
/// count as overlapping, while two a few points apart do not; a label that would cover another
/// node's disc yields even to a lower-ranked node; the first label — the centre's — is placed over
/// a disc, on the one plate, which no partner label overlaps; a square node is kept clear of its
/// corners, which a disc of its radius leaves out; and a label is never blocked by its own node,
/// even where the arithmetic that measures the gap rounds it inside the clearance.
///
/// The fixtures here are hand-made so each isolates one rule. The claim over a real layout is in
/// `PersonCoMentionLabelTests`, `VolumeConnectionLabelTests` and `ArchivalNetworkLabelTests`, which
/// lay the graphs out through their own code and check every placed label with
/// `clearanceViolations(placed:requests:)` and `plateOverlaps(placed:requests:)`.
///
/// Version history:
///   1.0 — 2026-09-24: #1384
///   1.1 — 2026-09-24: #1384 review — the first label is held to the disc rule (the fixture that
///          placed it across a disc now drops it), `.square` nodes, and the helper checks both
///   1.2 — 2026-09-24: #1384 review round 2 — by the owner's decision the first label is placed
///          over a disc again, on a plate: its fixture, `discsUnder(_:of:requests:)`,
///          `plateOverlaps(placed:requests:)`, and a helper that exempts the first label from
///          the disc rule only
struct GraphNodeLabelTests {

    /// A label's size as the canvas would measure it, estimated at 0.55 em a character and 1.25 em
    /// a line, which is close to the system font at the graphs' 8–9 pt. The rules under test hold
    /// for any size; the estimate only has to be realistic enough that a laid-out graph collides.
    static func estimatedSize(_ label: String, fontSize: CGFloat = 8) -> CGSize {
        CGSize(width: CGFloat(label.count) * fontSize * 0.55, height: fontSize * 1.25)
    }

    /// A request for a node at `x`, `y` with a disc of `radius` and a label `width` wide.
    private func request(_ id: String, x: CGFloat, y: CGFloat, radius: CGFloat = 12,
                         width: CGFloat = 80) -> GraphLabelRequest<String> {
        GraphLabelRequest(id: id, center: CGPoint(x: x, y: y), radius: radius,
                          size: CGSize(width: width, height: 10))
    }

    /// Every way a set of placed labels breaks the placement's promise, described: two placed rects
    /// closer than `GraphNodeLabels.clearance` (overlapping included), the first request's among
    /// them; or a partner's placed rect closer than that to the outline of a node other than its
    /// own (`discsUnder(_:of:requests:)`). The first request's label — the centre's — is exempt
    /// from the disc rule only: by the owner's decision (2026-09-24) it is drawn on a plate over
    /// whatever lies under it. Empty when the placement is clean.
    static func clearanceViolations<ID: Hashable>(placed: [ID: CGRect],
                                                  requests: [GraphLabelRequest<ID>]) -> [String] {
        let c = GraphNodeLabels.clearance
        var violations: [String] = []
        let rects = Array(placed)
        for i in rects.indices {
            for j in rects.indices where j > i {
                let a = rects[i].value, b = rects[j].value
                if a.intersects(b) || (a.minX < b.maxX + c && b.minX < a.maxX + c
                                       && a.minY < b.maxY + c && b.minY < a.maxY + c) {
                    violations.append("labels \(rects[i].key) and \(rects[j].key) at \(a) and \(b)")
                }
            }
            if rects[i].key != requests.first?.id {
                violations += discsUnder(rects[i].value, of: rects[i].key, requests: requests)
            }
        }
        return violations
    }

    /// Each node other than `id` whose outline comes within `GraphNodeLabels.clearance` of `rect` —
    /// its disc, or a `.square` node's whole square — described. For a partner's label that is a
    /// violation; for the centre's it is what its plate is drawn over.
    static func discsUnder<ID: Hashable>(_ rect: CGRect, of id: ID,
                                         requests: [GraphLabelRequest<ID>]) -> [String] {
        let c = GraphNodeLabels.clearance
        return requests.filter { other in
            guard other.id != id else { return false }
            let dx = max(rect.minX - other.center.x, 0, other.center.x - rect.maxX)
            let dy = max(rect.minY - other.center.y, 0, other.center.y - rect.maxY)
            return other.shape == .square
                ? hypot(max(dx - other.radius, 0), max(dy - other.radius, 0)) < c
                : hypot(dx, dy) < other.radius + c
        }.map { "label \(id) at \(rect) and node \($0.id)" }
    }

    /// Every placed partner label that overlaps the plate the canvas draws
    /// (`GraphNodeLabels.plate(for:placed:)`), described; the owner's rule is that none does. Empty
    /// too when there is no plate, so a caller that needs one asserts it separately.
    static func plateOverlaps<ID: Hashable>(placed: [ID: CGRect],
                                            requests: [GraphLabelRequest<ID>]) -> [String] {
        guard let plate = GraphNodeLabels.plate(for: requests, placed: placed) else { return [] }
        return placed.filter { $0.key != requests.first?.id && $0.value.intersects(plate) }
            .map { "label \($0.key) at \($0.value) and the plate at \(plate)" }
    }

    // MARK: shortLabel

    @Test("A name that fits the limit is drawn whole, with no mark")
    func aNameThatFitsIsWhole() {
        #expect(GraphNodeLabels.shortLabel("Kennan, George", limit: 14) == "Kennan, George")
        #expect(GraphNodeLabels.shortLabel("Rusk, Dean", limit: 14) == "Rusk, Dean")
    }

    @Test("A longer name is cut at the last word boundary within the limit and ends in an ellipsis")
    func aCutEndsAtAWordBoundaryWithAnEllipsis() {
        // Fourteen characters leave thirteen before the "…": "Bohlen, Charl" ends inside a word,
        // so the cut backs up to the boundary after "Bohlen," and drops the comma it leaves hanging.
        #expect(GraphNodeLabels.shortLabel("Bohlen, Charles E.", limit: 14) == "Bohlen…")
        // The boundary can fall exactly at the limit: "Truman, Harry" is thirteen whole characters.
        #expect(GraphNodeLabels.shortLabel("Truman, Harry S.", limit: 14) == "Truman, Harry…")
        // A period ends an initial rather than hanging, so it stays.
        #expect(GraphNodeLabels.shortLabel("Johnson, U. Alexis", limit: 14) == "Johnson, U.…")
    }

    @Test("A name with no word boundary within the limit is cut hard, and still marked")
    func aCutWithNoBoundaryIsHardAndMarked() {
        #expect(GraphNodeLabels.shortLabel("frus1961-63v07-09mSupp", limit: 12) == "frus1961-63…")
        // A space AFTER the limit is no boundary within it.
        #expect(GraphNodeLabels.shortLabel("Vissarionovich, Iosif", limit: 12) == "Vissarionov…")
        // A boundary that would leave nothing but a comma before it is no boundary either: the
        // label is never the mark alone.
        #expect(GraphNodeLabels.shortLabel(", Vissarionovich Iosif", limit: 12) == ", Vissarion…")
    }

    // MARK: place

    @Test("Two nodes at the same height closer than their labels are wide place one label, the higher-ranked")
    func sameHeightNeighboursPlaceTheHigherRankedLabel() {
        // Labels 80 pt wide under nodes 50 pt apart: 60…140 against 110…190.
        let a = request("a", x: 100, y: 100), b = request("b", x: 150, y: 100)
        #expect(Set(GraphNodeLabels.place([a, b]).keys) == ["a"])
        #expect(Set(GraphNodeLabels.place([b, a]).keys) == ["b"])
        // The same pair ranked behind a far first label: the order still decides between two
        // partners, not only between the first label and the rest.
        let first = request("first", x: 600, y: 600)
        #expect(Set(GraphNodeLabels.place([first, a, b]).keys) == ["first", "a"])
        #expect(Set(GraphNodeLabels.place([first, b, a]).keys) == ["first", "b"])
        // The control: the same two nodes 200 pt apart keep both labels.
        let far = request("b", x: 300, y: 100)
        #expect(Set(GraphNodeLabels.place([a, far]).keys) == ["a", "b"])
    }

    /// Two labels side by side, `gap` points apart, and how many the placement keeps.
    struct GapCase: CustomTestStringConvertible, Sendable {
        /// The space between the two labels' rects.
        let gap: CGFloat
        /// How many of the two labels are placed.
        let placed: Int
        /// The case name Swift Testing shows.
        var testDescription: String { "labels \(gap) pt apart place \(placed)" }
    }

    @Test("Labels that touch end to end count as overlapping; labels a few points apart do not",
          arguments: [GapCase(gap: 0, placed: 1), GapCase(gap: 2, placed: 1), GapCase(gap: 4, placed: 2)])
    func touchingLabelsCountAsOverlapping(_ gapCase: GapCase) {
        // "Bruce, David KTruman, Harry": two labels drawn end to end read as one string.
        let a = request("a", x: 100, y: 100)                         // label 60…140
        let b = request("b", x: 180 + gapCase.gap, y: 100)           // label 140+gap…
        #expect(GraphNodeLabels.place([a, b]).count == gapCase.placed)
    }

    /// A node under another's label, `gap` points below it, and whether the upper label is kept.
    struct DiscCase: CustomTestStringConvertible, Sendable {
        /// The space between the upper label's bottom edge and the lower node's disc.
        let gap: CGFloat
        /// Whether the upper node's label is placed.
        let upperPlaced: Bool
        /// The case name Swift Testing shows.
        var testDescription: String { "a disc \(gap) pt under a label \(upperPlaced ? "keeps" : "drops") it" }
    }

    @Test("A partner's label that would cover another node's disc is dropped, even when that node ranks lower",
          arguments: [DiscCase(gap: -5, upperPlaced: false), DiscCase(gap: 2, upperPlaced: false),
                      DiscCase(gap: 4, upperPlaced: true)])
    func aLabelYieldsToAnotherNodesDisc(_ discCase: DiscCase) {
        // The upper label spans y 115…125; the lower node's 12 pt disc sits `gap` below it. The two
        // labels are far apart vertically, so only the disc can decide. A first label far away
        // takes the focus's rank, so `upper` is a partner that outranks the node it yields to.
        let first = request("first", x: 600, y: 600)
        let upper = request("upper", x: 100, y: 100)
        let lower = request("lower", x: 100, y: 125 + 12 + discCase.gap)
        let placed = GraphNodeLabels.place([first, upper, lower])
        #expect((placed["upper"] != nil) == discCase.upperPlaced)
        #expect(placed["lower"] != nil)
        #expect(placed["first"] != nil)
    }

    @Test("The first label is placed over another node's disc, on the one plate, which no partner label overlaps")
    func theFirstLabelIsPlacedOverADiscOnItsPlate() {
        // The focus's label spans x 260…340, y 129…140 under its 26 pt disc; a partner's 20 pt disc
        // sits 50 pt below the centre, across it — the shape the iPad capture and both laid-out
        // co-mention graphs produce. #1384 and plan §3 A5 hold every label to the disc rule; by the
        // owner's decision of 2026-09-24 the centre's is placed anyway, on a plate.
        let focus = GraphLabelRequest(id: "focus", center: CGPoint(x: 300, y: 100), radius: 26,
                                      size: CGSize(width: 80, height: 11))
        let below = request("below", x: 300, y: 150, radius: 20)
        #expect(!Self.discsUnder(GraphNodeLabels.labelRect(for: focus), of: "focus",
                                 requests: [focus, below]).isEmpty)
        let placed = GraphNodeLabels.place([focus, below])
        #expect(placed["focus"] == CGRect(x: 260, y: 100 + 26 + GraphNodeLabels.spacing, width: 80, height: 11))
        // Its plate is 3 pt wider at each side and 1 pt taller above and below.
        #expect(GraphNodeLabels.plate(for: [focus, below], placed: placed)
                == CGRect(x: 257, y: 128, width: 86, height: 13))
        // There is one plate, the first request's — which every graph's priority order makes the
        // centre's — and none without a first label.
        #expect(GraphNodeLabels.plate(for: [below, focus], placed: GraphNodeLabels.place([below, focus]))
                == GraphNodeLabels.plateRect(behind: GraphNodeLabels.labelRect(for: below)))
        #expect(GraphNodeLabels.plate(for: [GraphLabelRequest<String>](), placed: [:]) == nil)
        // The partner's own label, under its own disc, keeps clear of the focus's and is placed.
        #expect(placed["below"] != nil)
        // A partner whose label would come within 1 pt of the focus's, over the plate, is dropped,
        // however high it ranks; 2 pt further right its label touches the plate's side without
        // overlapping it, and is placed.
        let beside = request("beside", x: 381, y: 114)          // label x 341…421, y 129…139
        #expect(GraphNodeLabels.place([focus, beside, below])["beside"] == nil)
        let touching = request("beside", x: 383, y: 114)        // label x 343…423
        let kept = GraphNodeLabels.place([focus, touching, below])
        #expect(kept["beside"] != nil)
        #expect(Self.plateOverlaps(placed: kept, requests: [focus, touching, below]).isEmpty)
        #expect(Self.clearanceViolations(placed: kept, requests: [focus, touching, below]).isEmpty)
    }

    @Test("A square node is kept clear of its corners, which a disc of its radius would leave out")
    func aSquareNodeIsClearedCornerToCorner() {
        // The archival network draws a class as a rounded square inside the square `radius` out
        // from its centre. A 20 pt square at (100, 100) has its corner at (120, 120); the label under
        // a 12 pt disc at (162, 107) spans x 122…202 and y 122…132, 2 pt right of and 2 pt below
        // that corner — 2.8 pt away, inside the clearance. A 20 pt disc at the same centre is
        // 31 pt from the label's corner, well clear, so only the square's corner decides.
        let first = request("first", x: 600, y: 600)
        let upper = request("upper", x: 162, y: 107)
        let square = GraphLabelRequest(id: "square", center: CGPoint(x: 100, y: 100), radius: 20,
                                       shape: .square, size: CGSize(width: 40, height: 10))
        #expect(GraphLabelRequest<String>.Shape.disc == request("x", x: 0, y: 0).shape,
                "a request is a disc unless it says otherwise")
        #expect(GraphNodeLabels.place([first, upper, square])["upper"] == nil)
        let disc = GraphLabelRequest(id: "disc", center: CGPoint(x: 100, y: 100), radius: 20,
                                     size: CGSize(width: 40, height: 10))
        #expect(GraphNodeLabels.place([first, upper, disc])["upper"] != nil)
    }

    @Test("A label is never blocked by its own node's disc, and sits spacing points under it")
    func aLabelIsNotBlockedByItsOwnDisc() {
        // Each is ranked behind a far first label, so the disc rule applies to it.
        let first = request("first", x: 700, y: 50)
        let partner = GraphLabelRequest(id: "partner", center: CGPoint(x: 100, y: 100), radius: 22,
                                        size: CGSize(width: 120, height: 30))
        #expect(GraphNodeLabels.place([first, partner])["partner"]
                == CGRect(x: 40, y: 100 + 22 + GraphNodeLabels.spacing, width: 120, height: 30))
        // The label starts exactly `radius + clearance` below its node, and measured back from a
        // centre at y = 483.3 that distance rounds to 28.999999999999943 for a 26 pt disc —
        // inside the clearance. Only the rule that a node's own disc is not "another" keeps it.
        let rounded = GraphLabelRequest(id: "rounded", center: CGPoint(x: 350, y: 483.3), radius: 26,
                                        size: CGSize(width: 60, height: 11))
        #expect(GraphNodeLabels.place([first, rounded])["rounded"] != nil)
    }

    @Test("The helpers that check a real layout report an overlap, a touch, a covered disc and a plate overlapped")
    func theClearanceCheckSeesEachViolation() {
        // The laid-out tests trust this helper to find what the placement must avoid, so each kind
        // of violation it looks for is shown to it once, over labels placed by hand.
        let a = request("a", x: 100, y: 100), b = request("b", x: 150, y: 100)
        let overlapping = [a, b].reduce(into: [String: CGRect]()) { $0[$1.id] = GraphNodeLabels.labelRect(for: $1) }
        #expect(Self.clearanceViolations(placed: overlapping, requests: [a, b]).count == 1)
        let touching = request("b", x: 180, y: 100)
        let touchingRects = [a, touching].reduce(into: [String: CGRect]()) { $0[$1.id] = GraphNodeLabels.labelRect(for: $1) }
        #expect(Self.clearanceViolations(placed: touchingRects, requests: [a, touching]).count == 1)
        // A disc under a partner's label is a violation. Under the first label, which is drawn on
        // its plate, it is not — `discsUnder` still reports it.
        let first = request("first", x: 600, y: 600)
        let disc = request("disc", x: 100, y: 130)
        let covered = ["a": GraphNodeLabels.labelRect(for: a)]
        #expect(Self.clearanceViolations(placed: covered, requests: [first, a, disc]).count == 1)
        #expect(Self.clearanceViolations(placed: covered, requests: [a, disc]).isEmpty)
        #expect(Self.discsUnder(GraphNodeLabels.labelRect(for: a), of: "a", requests: [a, disc]).count == 1)
        #expect(Self.clearanceViolations(placed: covered, requests: [first, a]).isEmpty)
        // A partner label over the first label's plate is reported; one clear of it is not.
        let over = ["a": GraphNodeLabels.labelRect(for: a), "c": CGRect(x: 141, y: 115, width: 40, height: 10)]
        let clear = ["a": GraphNodeLabels.labelRect(for: a), "c": CGRect(x: 144, y: 115, width: 40, height: 10)]
        let pair = [a, request("c", x: 161, y: 100)]
        #expect(Self.plateOverlaps(placed: over, requests: pair).count == 1)
        #expect(Self.plateOverlaps(placed: clear, requests: pair).isEmpty)
        // A square's corner is a violation where a disc of the same radius would not be.
        let corner = ["a": CGRect(x: 121, y: 121, width: 40, height: 10)]
        let square = GraphLabelRequest(id: "square", center: CGPoint(x: 100, y: 100), radius: 20,
                                       shape: .square, size: CGSize(width: 40, height: 10))
        let round = GraphLabelRequest(id: "round", center: CGPoint(x: 100, y: 100), radius: 20,
                                      size: CGSize(width: 40, height: 10))
        #expect(Self.clearanceViolations(placed: corner, requests: [square]).count == 1)
        #expect(Self.clearanceViolations(placed: corner, requests: [round]).isEmpty)
    }
}

// MARK: - PersonCoMentionLabelTests (#1384)

/// The co-mention graph's side of #1384: which label is placed first, how long a name may run, how
/// big each disc is drawn, and that over a layout the graph really produces the focus is labelled,
/// on its plate, over the disc under it, while no partner label touches another label, overlaps the
/// plate or covers a disc.
///
/// Version history:
///   1.0 — 2026-09-24: #1384
///   1.1 — 2026-09-24: #1384 review — names as the authority index stores them, the disc radius
///          pinned, and the laid-out graphs' focus label held to the disc rule with their counts
///   1.2 — 2026-09-24: #1384 review round 2 — by the owner's decision the laid-out graphs' focus is
///          labelled over the disc under it, on the one plate, which no partner label overlaps
@MainActor
struct PersonCoMentionLabelTests {

    /// The focus's name as the bundled person authority stores it (`person-authority-index.json`'s
    /// `n`), which is what the rollup builder names a person by wherever it has an authority id.
    private static let focusName = "Acheson, Dean Gooderham"

    /// Twenty-four partners' names as the authority stores them — the names the graph draws for
    /// these people (13 to 32 characters) — so a laid-out graph cuts some and collides.
    private static let partnerNames = [
        "Truman, Harry S.", "Marshall, George Catlett", "Bohlen, Charles Eustis (“Chip”)",
        "Kennan, George Frost", "Bruce, David Kirkpatrick Este", "Harriman, William Averell",
        "Byrnes, James Francis", "Forrestal, James V.", "Lovett, Robert Abercrombie",
        "Vandenberg, Arthur H.", "Dulles, John Foster", "Nitze, Paul Henry", "Rusk, David Dean",
        "Eisenhower, Dwight D.", "Stalin, Joseph", "Molotov, Vyacheslav Mikhailovich",
        "Bevin, Ernest", "Attlee, Clement R.", "Bidault, Georges P.", "Clay, Lucius DuBignon",
        "MacArthur, Douglas", "Hickerson, John Dewey", "Jessup, Philip Caryl", "Webb, James Edwin",
    ]

    @Test("At the shipped limit the capture's four names keep surname and given name, and every cut is marked")
    func theShippedLimitKeepsTheCapturesGivenNames() {
        let limit = PersonCoMentionGraphViewModel.labelLimit
        // The four people #1384's capture cut or overlapped ("Bruce, David K", "Truman, Harry",
        // "Kennan, George", "Bohlen, Charle"), named as the authority stores them. A word-boundary
        // cut at fourteen would draw two of them as "Kennan…" and "Bohlen…", and Truman's as
        // "Truman, Harry…".
        let drawn = ["Bruce, David Kirkpatrick Este", "Truman, Harry S.", "Kennan, George Frost",
                     "Bohlen, Charles Eustis (“Chip”)"]
            .map { GraphNodeLabels.shortLabel($0, limit: limit) }
        #expect(drawn == ["Bruce, David…", "Truman, Harry S.", "Kennan, George…", "Bohlen, Charles…"])
        #expect(drawn.allSatisfy { $0.count <= limit })
    }

    @Test("A partner's disc is 12 pt plus up to 10 pt by shared documents, 3 pt more while the dock shows it")
    func aPartnersDiscScalesWithSharedDocumentsAndGrowsWhenShown() {
        // The placement keeps every label clear of these radii, and the canvas draws its discs at
        // them, so a change here moves both — the audit claims pin that the canvas reads
        // `nodeRadius(for:)`; this pins what it returns.
        let vm = PersonCoMentionGraphViewModel(focusRollupId: 1, focusName: "Focus")
        vm.nodes = [PersonCoMentionNode(rollupId: 1, name: "Focus", sharedWithFocus: 0),
                    PersonCoMentionNode(rollupId: 2, name: "Two", sharedWithFocus: 4),
                    PersonCoMentionNode(rollupId: 3, name: "Three", sharedWithFocus: 2),
                    PersonCoMentionNode(rollupId: 4, name: "Four", sharedWithFocus: 1)]
        let radii = { [1, 2, 3, 4].map { vm.nodeRadius(for: $0) } }
        // The focus is fixed; a partner is 12 + 10 × its share of the largest partner's documents.
        #expect(radii() == [PersonCoMentionGraphViewModel.focusRadius, 22, 17, 14.5])
        // A pinned partner is emphasised, 3 pt larger.
        vm.toggleSelection(3)
        #expect(radii() == [PersonCoMentionGraphViewModel.focusRadius, 22, 20, 14.5])
        // A hovered one is the displayed partner instead (#1383), and only it is emphasised.
        vm.hoverChanged(4, hovering: true)
        #expect(radii() == [PersonCoMentionGraphViewModel.focusRadius, 22, 17, 17.5])
    }

    @Test("Labels are ranked: the focus, the partner the dock shows, then partners by shared documents")
    func labelsAreRankedFocusDisplayedThenShared() async throws {
        let (dir, store) = try makeLayoutStore(names: Array(Self.partnerNames.prefix(4)))
        defer { try? FileManager.default.removeItem(at: dir) }
        let vm = PersonCoMentionGraphViewModel(focusRollupId: 1, focusName: Self.focusName)
        await vm.load(from: store)
        #expect(vm.error == nil)
        // Rollups 2…5 share 24, 23, 22, 21 documents with the focus.
        #expect(vm.labelPriority == [1, 2, 3, 4, 5])
        // A click pins the lowest-ranked partner: its label goes second, and only once.
        vm.toggleSelection(5)
        #expect(vm.labelPriority == [1, 5, 2, 3, 4])
        // A hover shows another partner in the dock (#1383), and its label outranks the pinned one's.
        vm.hoverChanged(4, hovering: true)
        #expect(vm.labelPriority == [1, 4, 2, 3, 5])
        vm.hoverChanged(4, hovering: false)
        #expect(vm.labelPriority == [1, 5, 2, 3, 4])
    }

    @Test("A node with no position or no measured size asks for no label")
    func aNodeWithNoPositionOrSizeAsksForNoLabel() {
        let vm = PersonCoMentionGraphViewModel(focusRollupId: 1, focusName: "Focus")
        vm.nodes = [PersonCoMentionNode(rollupId: 1, name: "Focus", sharedWithFocus: 0),
                    PersonCoMentionNode(rollupId: 2, name: "Two", sharedWithFocus: 2),
                    PersonCoMentionNode(rollupId: 3, name: "Three", sharedWithFocus: 1)]
        vm.nodePositions = [1: CGPoint(x: 200, y: 200), 2: CGPoint(x: 300, y: 200)]
        let size = CGSize(width: 40, height: 10)
        // Rollup 3 has a size and no position.
        #expect(vm.labelRequests(sizes: [1: size, 2: size, 3: size]).map(\.id) == [1, 2])
        // Rollup 2 has a position and no size.
        #expect(vm.labelRequests(sizes: [1: size, 3: size]).map(\.id) == [1])
        // Each request carries the radius the canvas draws the disc at.
        #expect(vm.labelRequests(sizes: [1: size, 2: size]).map(\.radius)
                == [PersonCoMentionGraphViewModel.focusRadius, 22])
    }

    /// One laid-out case: a canvas and how many of the 25 labels fit on it.
    struct LayoutCase: CustomTestStringConvertible, Sendable {
        /// The canvas.
        let canvas: CGSize
        /// Labels placed there, the focus's counted.
        let placed: Int
        /// The case name Swift Testing shows.
        var testDescription: String { "\(Int(canvas.width)) × \(Int(canvas.height)) places \(placed)" }
    }

    @Test("Over a layout the graph produces, the focus is labelled over the disc under it, and no partner label touches a label, the plate or a disc",
          arguments: [LayoutCase(canvas: CGSize(width: 700, height: 520), placed: 18),
                      LayoutCase(canvas: CGSize(width: 360, height: 420), placed: 17)])
    func aLaidOutGraphPlacesClearLabels(_ layoutCase: LayoutCase) async throws {
        let (dir, store) = try makeLayoutStore(names: Self.partnerNames)
        defer { try? FileManager.default.removeItem(at: dir) }
        let vm = PersonCoMentionGraphViewModel(focusRollupId: 1, focusName: Self.focusName)
        await vm.load(from: store)
        #expect(vm.error == nil)
        #expect(vm.partners.count == 24)
        // Reduce Motion settles the layout synchronously through the same `runPhysics` the view runs.
        vm.onCanvasSizeChanged(layoutCase.canvas, reduceMotion: true)
        #expect(vm.nodePositions.count == 25)

        var sizes: [Int: CGSize] = [:]
        for id in vm.allRollupIds {
            sizes[id] = GraphNodeLabelTests.estimatedSize(vm.label(for: id),
                                                          fontSize: id == 1 ? 9 : 8)
        }
        let requests = vm.labelRequests(sizes: sizes)
        let placed = GraphNodeLabels.place(requests)

        #expect(requests.count == 25)
        // Measured: in both layouts rollup 5's disc sits under the focus's label, which #1384's
        // rule would drop. By the owner's decision the focus is labelled anyway, on its plate.
        let focusRect = GraphNodeLabels.labelRect(for: requests[0])
        let under = GraphNodeLabelTests.discsUnder(focusRect, of: 1, requests: requests)
        #expect(!under.isEmpty, "no disc lies under the focus's label in this layout any more")
        #expect(placed[1] == focusRect, "the focus is labelled under its node whatever lies there")
        // One plate, the focus's, and no partner label overlaps it.
        #expect(GraphNodeLabels.plate(for: requests, placed: placed)
                == GraphNodeLabels.plateRect(behind: focusRect))
        let overlaps = GraphNodeLabelTests.plateOverlaps(placed: placed, requests: requests)
        #expect(overlaps.isEmpty, "\(overlaps)")
        // Pinned, so the counts `labelLimit`'s comment states cannot drift unnoticed; the sizes are
        // `estimatedSize`'s, not a font's.
        #expect(placed.count == layoutCase.placed, "placed \(placed.count) of \(requests.count)")
        let violations = GraphNodeLabelTests.clearanceViolations(placed: placed, requests: requests)
        #expect(violations.isEmpty, "\(violations.count) violation(s): \(violations.prefix(5))")
    }

    // MARK: - Fixture

    /// A fixture that could not be built.
    private struct FixtureError: Error {
        /// What failed, with SQLite's own message where there is one.
        let message: String
    }

    /// A store whose focus (rollup 1) shares 24, 23, 22 … documents with the partners named, in
    /// order (rollups 2…): document `dJ` mentions the focus and every partner `k` with `k + J ≤ 25`,
    /// so partners also co-occur with one another, as they do in a real ego graph.
    private func makeLayoutStore(names: [String]) throws -> (dir: URL, store: PersonMentionStore) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSCoMentionLabels-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("test.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        let fts5 = try FTS5Store(databaseURL: dbURL)
        _ = try IndexingPipeline(fts5Store: fts5, databaseURL: dbURL,
                                 volumesDirectory: volDir, concurrencyLimit: 1)

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
              let db else {
            throw FixtureError(message: "label fixture: cannot open")
        }
        defer { sqlite3_close_v2(db) }
        let everyone = [Self.focusName] + names
        var statements: [String] = []
        for (index, name) in everyone.enumerated() {
            let rollup = index + 1
            let quoted = name.replacingOccurrences(of: "'", with: "''")
            statements.append("INSERT INTO person_rollup (rollup_id, namekey, canonical_name, mention_count) VALUES (\(rollup), '\(quoted.lowercased())', '\(quoted)', 1)")
            statements.append("INSERT INTO person_rollup_member (volume_id, ref, rollup_id) VALUES ('v1', 'p_\(rollup)', \(rollup))")
        }
        for document in 1...24 {
            statements.append("INSERT INTO person_mentions (volume_id, document_id, person_ref) VALUES ('v1', 'd\(document)', 'p_1')")
            for partner in 1...names.count where partner + document <= 25 {
                statements.append("INSERT INTO person_mentions (volume_id, document_id, person_ref) VALUES ('v1', 'd\(document)', 'p_\(partner + 1)')")
            }
        }
        for sql in statements {
            guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
                throw FixtureError(message: "label fixture: \(String(cString: sqlite3_errmsg(db)))")
            }
        }
        return (dir, try PersonMentionStore(databaseURL: dbURL))
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
