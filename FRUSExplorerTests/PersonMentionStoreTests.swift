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

// MARK: - PersonMentionStoreTests

/// Tests for `PersonMentionStore`.
///
/// Uses a fresh SQLite database for each test, seeded via
/// `IndexingPipeline` so the schema is guaranteed up-to-date.
///
/// Version history:
///   1.0 — Session 39: initial implementation
struct PersonMentionStoreTests {

    // Build a fixture: temp dir + fresh pipeline + PersonMentionStore
    private func makeFixture() throws -> (dir: URL, store: PersonMentionStore) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSPMStore-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("test.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)

        let fts5 = try FTS5Store(databaseURL: dbURL)
        _ = try IndexingPipeline(
            fts5Store: fts5,
            databaseURL: dbURL,
            volumesDirectory: volDir,
            subjectTagStore: SubjectTagStore(entries: [], appearances: []),
            concurrencyLimit: 1
        )
        let store = try PersonMentionStore(databaseURL: dbURL)
        return (dir, store)
    }

    // Insert person_mentions rows directly via raw SQLite
    private func insertMention(dbURL: URL, volumeId: String, documentId: String, personRef: String) throws {
        var db: OpaquePointer?
        sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil)
        defer { sqlite3_close_v2(db) }
        let TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, "INSERT INTO person_mentions (volume_id, document_id, person_ref) VALUES (?, ?, ?)", -1, &stmt, nil)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, volumeId, -1, TRANSIENT)
        sqlite3_bind_text(stmt, 2, documentId, -1, TRANSIENT)
        sqlite3_bind_text(stmt, 3, personRef, -1, TRANSIENT)
        sqlite3_step(stmt)
    }

    @Test("documents(volumeId:ref:) — scoped to one volume, never conflates a shared ref")
    func documentsScopedByVolume() async throws {
        let (dir, store) = try makeFixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let dbURL = dir.appendingPathComponent("test.sqlite")

        try insertMention(dbURL: dbURL, volumeId: "vol1", documentId: "d1", personRef: "p_kissinger")
        try insertMention(dbURL: dbURL, volumeId: "vol1", documentId: "d3", personRef: "p_kissinger")
        // vol2 reuses the same TEI ref string for an unrelated person — must be excluded.
        try insertMention(dbURL: dbURL, volumeId: "vol2", documentId: "d5", personRef: "p_kissinger")
        try insertMention(dbURL: dbURL, volumeId: "vol1", documentId: "d2", personRef: "p_nixon")

        let results = try await store.documents(volumeId: "vol1", ref: "p_kissinger")
        #expect(results.count == 2)
        let keys = results.map { "\($0.volumeId)/\($0.documentId)" }.sorted()
        #expect(keys == ["vol1/d1", "vol1/d3"])
    }

    @Test("personRefsForDocument — returns refs for a given document")
    func personRefsForDocument() async throws {
        let (dir, store) = try makeFixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let dbURL = dir.appendingPathComponent("test.sqlite")

        try insertMention(dbURL: dbURL, volumeId: "vol1", documentId: "d1", personRef: "p_kissinger")
        try insertMention(dbURL: dbURL, volumeId: "vol1", documentId: "d1", personRef: "p_nixon")
        try insertMention(dbURL: dbURL, volumeId: "vol1", documentId: "d2", personRef: "p_kissinger")

        let refs = try await store.personRefs(forDocumentId: "d1", volumeId: "vol1")
        #expect(refs.sorted() == ["p_kissinger", "p_nixon"])
    }

    @Test("documentCount(volumeId:ref:) — counts only the scoped volume's mentions")
    func documentCountScopedByVolume() async throws {
        let (dir, store) = try makeFixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let dbURL = dir.appendingPathComponent("test.sqlite")

        try insertMention(dbURL: dbURL, volumeId: "vol1", documentId: "d1", personRef: "p1")
        try insertMention(dbURL: dbURL, volumeId: "vol1", documentId: "d2", personRef: "p1")
        // vol2's "p1" is an unrelated person sharing the ref string — counted separately.
        try insertMention(dbURL: dbURL, volumeId: "vol2", documentId: "d1", personRef: "p1")

        #expect(try await store.documentCount(volumeId: "vol1", ref: "p1") == 2)
        #expect(try await store.documentCount(volumeId: "vol2", ref: "p1") == 1)
    }

    // MARK: - Rollup read API (Phase 0)

    // Insert a person_rollup row plus its members directly via raw SQLite.
    private func insertRollup(
        dbURL: URL, rollupId: Int, namekey: String, canonicalName: String,
        description: String?, mentionCount: Int, members: [(volumeId: String, ref: String)]
    ) throws {
        var db: OpaquePointer?
        sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil)
        defer { sqlite3_close_v2(db) }
        let TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        var s1: OpaquePointer?
        sqlite3_prepare_v2(db, """
            INSERT INTO person_rollup (rollup_id, namekey, canonical_name, description, mention_count)
            VALUES (?, ?, ?, ?, ?)
            """, -1, &s1, nil)
        sqlite3_bind_int64(s1, 1, Int64(rollupId))
        sqlite3_bind_text(s1, 2, namekey, -1, TRANSIENT)
        sqlite3_bind_text(s1, 3, canonicalName, -1, TRANSIENT)
        if let d = description { sqlite3_bind_text(s1, 4, d, -1, TRANSIENT) } else { sqlite3_bind_null(s1, 4) }
        sqlite3_bind_int64(s1, 5, Int64(mentionCount))
        sqlite3_step(s1)
        sqlite3_finalize(s1)
        for m in members {
            var s2: OpaquePointer?
            sqlite3_prepare_v2(db,
                "INSERT INTO person_rollup_member (volume_id, ref, rollup_id) VALUES (?, ?, ?)",
                -1, &s2, nil)
            sqlite3_bind_text(s2, 1, m.volumeId, -1, TRANSIENT)
            sqlite3_bind_text(s2, 2, m.ref, -1, TRANSIENT)
            sqlite3_bind_int64(s2, 3, Int64(rollupId))
            sqlite3_step(s2)
            sqlite3_finalize(s2)
        }
    }

    @Test("rollupEntry(forVolumeId:ref:) — resolves the cross-corpus rollup for a per-volume person")
    func rollupEntryResolution() async throws {
        let (dir, store) = try makeFixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let dbURL = dir.appendingPathComponent("test.sqlite")

        // Kissinger appears under different per-volume refs in two volumes → one rollup.
        try insertRollup(dbURL: dbURL, rollupId: 1, namekey: "kissinger, henry a.",
                         canonicalName: "Kissinger, Henry A.", description: "Secretary of State",
                         mentionCount: 42, members: [("vol1", "p_KHA1"), ("vol2", "p_HK3")])

        let viaVol1 = try await store.rollupEntry(forVolumeId: "vol1", ref: "p_KHA1")
        #expect(viaVol1?.rollupId == 1)
        #expect(viaVol1?.mentionCount == 42)
        #expect(viaVol1?.entry.name == "Kissinger, Henry A.")
        // A different per-volume ref in another volume resolves to the same rollup.
        #expect(try await store.rollupEntry(forVolumeId: "vol2", ref: "p_HK3")?.rollupId == 1)
        // Unknown (volume, ref) → nil.
        #expect(try await store.rollupEntry(forVolumeId: "vol9", ref: "p_KHA1") == nil)
    }

    @Test("documentKeys(forRollupId:) — DISTINCT cross-corpus mentions across all members")
    func documentKeysForRollup() async throws {
        let (dir, store) = try makeFixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let dbURL = dir.appendingPathComponent("test.sqlite")

        try insertMention(dbURL: dbURL, volumeId: "vol1", documentId: "d1", personRef: "p_KHA1")
        try insertMention(dbURL: dbURL, volumeId: "vol1", documentId: "d2", personRef: "p_KHA1")
        try insertMention(dbURL: dbURL, volumeId: "vol2", documentId: "d9", personRef: "p_HK3")
        try insertRollup(dbURL: dbURL, rollupId: 1, namekey: "kissinger, henry a.",
                         canonicalName: "Kissinger, Henry A.", description: nil, mentionCount: 3,
                         members: [("vol1", "p_KHA1"), ("vol2", "p_HK3")])

        let keys = try await store.documentKeys(forRollupId: 1)
            .map { "\($0.volumeId)/\($0.documentId)" }.sorted()
        #expect(keys == ["vol1/d1", "vol1/d2", "vol2/d9"])
    }

    @Test("allPersonsSortedByName — reads the materialised rollup, ordered by canonical name")
    func allPersonsReadsRollup() async throws {
        let (dir, store) = try makeFixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let dbURL = dir.appendingPathComponent("test.sqlite")

        try insertRollup(dbURL: dbURL, rollupId: 2, namekey: "nixon, richard m.",
                         canonicalName: "Nixon, Richard M.", description: nil, mentionCount: 10,
                         members: [("vol1", "p_RN1")])
        try insertRollup(dbURL: dbURL, rollupId: 1, namekey: "kissinger, henry a.",
                         canonicalName: "Kissinger, Henry A.", description: nil, mentionCount: 42,
                         members: [("vol1", "p_KHA1")])

        let all = try await store.allPersonsSortedByName()
        #expect(all.map(\.entry.name) == ["Kissinger, Henry A.", "Nixon, Richard M."])
        #expect(all.first?.rollupId == 1)
        #expect(all.first?.mentionCount == 42)
    }

    @Test("searchFilterByPersonRef — only documents mentioning the ref are returned")
    func searchFilterByPersonRef() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSPMSearch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let dbURL = dir.appendingPathComponent("test.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)

        // Write a volume XML with two docs; both contain keyword "negotiate"
        let xml = """
        <?xml version="1.0"?>
        <TEI><text><body>
        <div type="document" xml:id="d1">
          <head>1. Memorandum</head>
          <p>Kissinger met to <persName ref="p_kissinger">negotiate</persName> terms.</p>
        </div>
        <div type="document" xml:id="d2">
          <head>2. Cable</head>
          <p>Delegation agreed to negotiate the settlement.</p>
        </div>
        </body></text></TEI>
        """
        try xml.data(using: .utf8)!.write(to: volDir.appendingPathComponent("vol1.xml"))

        let fts5 = try FTS5Store(databaseURL: dbURL)
        let pms = try PersonMentionStore(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: fts5,
            databaseURL: dbURL,
            volumesDirectory: volDir,
            subjectTagStore: SubjectTagStore(entries: [], appearances: []),
            concurrencyLimit: 1
        )
        try await pipeline.indexVolume("vol1")

        let searchService = SearchService(fts5Store: fts5, pipeline: pipeline, personMentionStore: pms)

        // Both documents contain "negotiate" but only d1 mentions p_kissinger
        var params = SearchParameters(keywords: "negotiate")
        params.personRef = "p_kissinger"
        let results = try await searchService.search(parameters: params)
        let ids = results.map(\.documentId)
        #expect(ids.contains("d1"), "d1 mentions p_kissinger and must appear")
        #expect(!ids.contains("d2"), "d2 does not mention p_kissinger and must be filtered out")
    }
}

// MARK: - PersonsByNameTests

struct PersonsByNameTests {

    private func makeStore() throws -> (dir: URL, dbURL: URL, store: PersonMentionStore) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSByName-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("test.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)

        let fts5 = try FTS5Store(databaseURL: dbURL)
        _ = try IndexingPipeline(
            fts5Store: fts5, databaseURL: dbURL, volumesDirectory: volDir,
            subjectTagStore: SubjectTagStore(entries: [], appearances: []),
            concurrencyLimit: 1
        )
        let store = try PersonMentionStore(databaseURL: dbURL)
        return (dir, dbURL, store)
    }

    private func insertPerson(dbURL: URL, volumeId: String, ref: String,
                               name: String, description: String? = nil) throws {
        var db: OpaquePointer?
        sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil)
        defer { sqlite3_close_v2(db) }
        let TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db,
            "INSERT OR REPLACE INTO persons (volume_id, ref, name, description) VALUES (?, ?, ?, ?)",
            -1, &stmt, nil)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, volumeId,    -1, TRANSIENT)
        sqlite3_bind_text(stmt, 2, ref,         -1, TRANSIENT)
        sqlite3_bind_text(stmt, 3, name,        -1, TRANSIENT)
        if let d = description { sqlite3_bind_text(stmt, 4, d, -1, TRANSIENT) }
        else { sqlite3_bind_null(stmt, 4) }
        sqlite3_step(stmt)
    }

    @Test("personsMatchingNameCaseInsensitive — LIKE search is case-insensitive")
    func personsMatchingNameCaseInsensitive() async throws {
        let (dir, dbURL, store) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        try insertPerson(dbURL: dbURL, volumeId: "vol1", ref: "p_kiss",
                         name: "Kissinger, Henry A.", description: "NSA")

        let results = try await store.personsMatchingName("kissinger")
        #expect(results.count == 1)
        #expect(results.first?.name == "Kissinger, Henry A.")
    }

    @Test("personsMatchingNamePartial — partial substring match is supported")
    func personsMatchingNamePartial() async throws {
        let (dir, dbURL, store) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        try insertPerson(dbURL: dbURL, volumeId: "vol1", ref: "p_kiss",
                         name: "Kissinger, Henry A.")
        try insertPerson(dbURL: dbURL, volumeId: "vol1", ref: "p_nixon",
                         name: "Nixon, Richard M.")

        let results = try await store.personsMatchingName("Kiss")
        #expect(results.count == 1)
        #expect(results.first?.ref == "p_kiss")
    }

    @Test("personsMatchingNameLimit — result count is capped at the specified limit")
    func personsMatchingNameLimit() async throws {
        let (dir, dbURL, store) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        for i in 1...25 {
            try insertPerson(dbURL: dbURL, volumeId: "vol1", ref: "p_smith\(i)",
                             name: "Smith, Person \(i)")
        }

        let results = try await store.personsMatchingName("Smith", limit: 20)
        #expect(results.count == 20)
    }

    @Test("personLookupByRefAndVolume — single person retrieved by ref and volumeId")
    func personLookupByRefAndVolume() async throws {
        let (dir, dbURL, store) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        try insertPerson(dbURL: dbURL, volumeId: "frus1969-76v01", ref: "p1",
                         name: "Kissinger, Henry A.", description: "National Security Advisor")

        let entry = try await store.person(forRef: "p1", volumeId: "frus1969-76v01")
        let found = try #require(entry)
        #expect(found.name == "Kissinger, Henry A.")
        #expect(found.description == "National Security Advisor")

        // Wrong volume → nil
        let missing = try await store.person(forRef: "p1", volumeId: "other-vol")
        #expect(missing == nil)
    }
}
