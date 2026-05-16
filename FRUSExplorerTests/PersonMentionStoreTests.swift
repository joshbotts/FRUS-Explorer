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

    @Test("documentsForPersonRef — returns correct (volumeId, documentId) pairs")
    func documentsForPersonRef() async throws {
        let (dir, store) = try makeFixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let dbURL = dir.appendingPathComponent("test.sqlite")

        try insertMention(dbURL: dbURL, volumeId: "vol1", documentId: "d1", personRef: "p_kissinger")
        try insertMention(dbURL: dbURL, volumeId: "vol1", documentId: "d3", personRef: "p_kissinger")
        try insertMention(dbURL: dbURL, volumeId: "vol2", documentId: "d5", personRef: "p_kissinger")
        try insertMention(dbURL: dbURL, volumeId: "vol1", documentId: "d2", personRef: "p_nixon")

        let results = try await store.documents(forPersonRef: "p_kissinger")
        #expect(results.count == 3)
        let keys = results.map { "\($0.volumeId)/\($0.documentId)" }.sorted()
        #expect(keys == ["vol1/d1", "vol1/d3", "vol2/d5"])
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

    @Test("documentCountForRef — returns correct count")
    func documentCountForRef() async throws {
        let (dir, store) = try makeFixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let dbURL = dir.appendingPathComponent("test.sqlite")

        try insertMention(dbURL: dbURL, volumeId: "vol1", documentId: "d1", personRef: "p1")
        try insertMention(dbURL: dbURL, volumeId: "vol1", documentId: "d2", personRef: "p1")
        try insertMention(dbURL: dbURL, volumeId: "vol2", documentId: "d1", personRef: "p1")

        let count = try await store.documentCount(forPersonRef: "p1")
        #expect(count == 3)
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
