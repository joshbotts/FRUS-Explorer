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
@testable import FTS5Store

// MARK: - Test Helpers

/// SQLITE_TRANSIENT for test-side binds (copy the string immediately).
private let TEST_SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Test double exposing the production external-content stack through the same
/// method names the pre-redesign `FTS5Store` write API had, so the test bodies
/// below read identically while writes flow through the `document_cache` content
/// table and the sync triggers — exactly as `IndexingPipeline` writes in the app.
private final class TestStore {

    /// The store under test (search side).
    let store: FTS5Store

    /// Write-side connection holding the content table and triggers.
    private let connection: FTS5Connection

    init(databaseURL: URL) throws {
        // Content table first — the FTS tables and triggers reference it.
        connection = try FTS5Connection(databaseURL: databaseURL)
        try connection.exec("""
            CREATE TABLE IF NOT EXISTS document_cache (
                volume_id TEXT NOT NULL,
                document_id TEXT NOT NULL,
                document_number TEXT,
                header TEXT NOT NULL,
                dateline TEXT,
                source_note TEXT,
                body_text TEXT NOT NULL,
                subject_tag_ids TEXT,
                user_tag_ids TEXT,
                summary_text TEXT,
                note_text TEXT,
                is_editorial_note INTEGER NOT NULL DEFAULT 0,
                is_front_matter   INTEGER NOT NULL DEFAULT 0,
                PRIMARY KEY (volume_id, document_id)
            )
            """)
        store = try FTS5Store(databaseURL: databaseURL)
        try connection.exec(FTS5Schema.userContent.createTableSQL(ifNotExists: true))
        for sql in FTS5Schema.frusDocuments.externalContentTriggerSQL() {
            try connection.exec(sql)
        }
        for sql in FTS5Schema.userContent.externalContentTriggerSQL() {
            try connection.exec(sql)
        }
    }

    /// Inserts (or fully replaces) a document row in the content table; the sync
    /// triggers maintain both FTS5 tables.
    func insert(document doc: FTS5Document) async throws {
        try upsert(doc)
    }

    /// Full-replace update through the content table (fires the UPDATE triggers).
    func update(document doc: FTS5Document) async throws {
        try upsert(doc)
    }

    /// Volume-scoped delete through the content table (fires the DELETE trigger).
    func delete(documentId: String, volumeId: String) async throws {
        let stmt = try connection.prepare(
            "DELETE FROM document_cache WHERE document_id = ? AND volume_id = ?")
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, documentId, -1, TEST_SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, volumeId, -1, TEST_SQLITE_TRANSIENT)
        try connection.step(stmt)
    }

    /// Transactional batch insert through the content table.
    func insertBatch(_ docs: [FTS5Document]) async throws {
        try connection.beginTransaction()
        do {
            for doc in docs { try upsert(doc) }
            try connection.commitTransaction()
        } catch {
            connection.rollbackTransaction()
            throw error
        }
    }

    /// Passthrough to `FTS5Store.search`.
    func search(query: FTS5Query, limit: Int, offset: Int) async throws -> [FTS5Result] {
        try await store.search(query: query, limit: limit, offset: offset)
    }

    /// Passthrough to `FTS5Store.storageSize`.
    func storageSize() async throws -> Int {
        try await store.storageSize()
    }

    /// Returns (volumeId, documentId) pairs whose summary/note text matches
    /// `matchExpr` in the `user_content` FTS5 table.
    func userContentMatches(_ matchExpr: String) throws -> [(volumeId: String, documentId: String)] {
        let stmt = try connection.prepare(
            "SELECT volume_id, document_id FROM user_content WHERE user_content MATCH ?")
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, matchExpr, -1, TEST_SQLITE_TRANSIENT)
        var rows: [(String, String)] = []
        while try connection.step(stmt) {
            let v = sqlite3_column_text(stmt, 0).map { String(cString: $0) } ?? ""
            let d = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
            rows.append((v, d))
        }
        return rows
    }

    /// Updates only the note text of an existing row (fires the user-content
    /// UPDATE trigger but not the corpus one).
    func setNoteText(_ note: String?, documentId: String, volumeId: String) throws {
        let stmt = try connection.prepare(
            "UPDATE document_cache SET note_text = ? WHERE document_id = ? AND volume_id = ?")
        defer { sqlite3_finalize(stmt) }
        if let note { sqlite3_bind_text(stmt, 1, note, -1, TEST_SQLITE_TRANSIENT) }
        else        { sqlite3_bind_null(stmt, 1) }
        sqlite3_bind_text(stmt, 2, documentId, -1, TEST_SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, volumeId, -1, TEST_SQLITE_TRANSIENT)
        try connection.step(stmt)
    }

    private func upsert(_ doc: FTS5Document) throws {
        let sql = """
            INSERT INTO document_cache
            (volume_id, document_id, document_number, header, dateline, source_note, body_text,
             subject_tag_ids, user_tag_ids, summary_text, note_text, is_editorial_note, is_front_matter)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
            ON CONFLICT(volume_id, document_id) DO UPDATE SET
              document_number = excluded.document_number,
              header          = excluded.header,
              dateline        = excluded.dateline,
              source_note     = excluded.source_note,
              body_text       = excluded.body_text,
              subject_tag_ids = excluded.subject_tag_ids,
              user_tag_ids    = excluded.user_tag_ids,
              summary_text    = excluded.summary_text,
              note_text       = excluded.note_text,
              is_editorial_note = excluded.is_editorial_note
            """
        let stmt = try connection.prepare(sql)
        defer { sqlite3_finalize(stmt) }
        func bindOpt(_ col: Int32, _ value: String?) {
            if let value { sqlite3_bind_text(stmt, col, value, -1, TEST_SQLITE_TRANSIENT) }
            else         { sqlite3_bind_null(stmt, col) }
        }
        sqlite3_bind_text(stmt, 1, doc.volumeId, -1, TEST_SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, doc.id, -1, TEST_SQLITE_TRANSIENT)
        bindOpt(3, doc.documentNumber)
        sqlite3_bind_text(stmt, 4, doc.header, -1, TEST_SQLITE_TRANSIENT)
        bindOpt(5, doc.dateline)
        bindOpt(6, doc.sourceNote)
        sqlite3_bind_text(stmt, 7, doc.bodyText, -1, TEST_SQLITE_TRANSIENT)
        bindOpt(8, doc.subjectTagIds)
        bindOpt(9, doc.userTagIds)
        bindOpt(10, doc.summaryText)
        bindOpt(11, doc.noteText)
        sqlite3_bind_int(stmt, 12, doc.isEditorialNote ? 1 : 0)
        try connection.step(stmt)
    }
}

private func makeStore() throws -> (TestStore, URL) {
    let dir = FileManager.default.temporaryDirectory
    let url = dir.appendingPathComponent("fts5test-\(UUID().uuidString).sqlite")
    let store = try TestStore(databaseURL: url)
    return (store, url)
}

private func sampleDoc(
    id: String = "d1",
    volumeId: String = "frus1969-76v01",
    header: String = "Memorandum of Conversation",
    body: String = "The president discussed cold war negotiations with the ambassador.",
    subjectTagIds: String? = nil,
    userTagIds: String? = nil
) -> FTS5Document {
    FTS5Document(
        id: id,
        volumeId: volumeId,
        documentNumber: nil,
        header: header,
        dateline: nil,
        sourceNote: nil,
        bodyText: body,
        subjectTagIds: subjectTagIds,
        userTagIds: userTagIds
    )
}

// MARK: - FTS5StoreTests

/// Integration tests for `FTS5Store`. Each test creates a fresh in-memory
/// (temp-file) database so tests are independent.
struct FTS5StoreTests {

    // MARK: - Insert and Search

    @Test("Insert a document and search for a term in its body")
    func insertAndSearch() async throws {
        let (store, _) = try makeStore()
        let doc = sampleDoc(body: "The ambassador reviewed diplomatic communications.")
        try await store.insert(document: doc)

        let results = try await store.search(
            query: FTS5Query(keywords: ["diplomatic"]),
            limit: 10,
            offset: 0
        )
        #expect(results.count == 1)
        #expect(results[0].documentId == "d1")
    }

    // MARK: - Stemming

    @Test("Search for stem 'negotiate' matches indexed word 'negotiations'")
    func stemmingNegotiate() async throws {
        let (store, _) = try makeStore()
        try await store.insert(document: sampleDoc(
            body: "The parties entered into negotiations over the treaty."
        ))

        // "negoti" is the Porter stem of both "negotiate" and "negotiations"
        let results = try await store.search(
            query: FTS5Query(keywords: ["negotiate"]),
            limit: 10,
            offset: 0
        )
        #expect(!results.isEmpty, "Stemmed query 'negotiate' should match 'negotiations'")
    }

    @Test("Search for 'administer' matches document containing 'administered'")
    func stemmingAdminister() async throws {
        let (store, _) = try makeStore()
        // "administered" and "administer" both stem to "administ" via Porter step 1b + step 4.
        try await store.insert(document: sampleDoc(
            body: "The secretary administered the department budget carefully."
        ))

        let results = try await store.search(
            query: FTS5Query(keywords: ["administer"]),
            limit: 10,
            offset: 0
        )
        #expect(!results.isEmpty, "Stemmed query 'administer' should match indexed 'administered'")
    }

    @Test("Search for 'diplomat' matches document containing 'diplomatic'")
    func stemmingDiplomacy() async throws {
        let (store, _) = try makeStore()
        // "diplomatic" and "diplomat" both stem to "diplomat" via Porter step 4 ("ic" suffix removal).
        try await store.insert(document: sampleDoc(
            body: "The Secretary engaged in high-level diplomatic discussions with Soviet officials."
        ))

        let results = try await store.search(
            query: FTS5Query(keywords: ["diplomat"]),
            limit: 10,
            offset: 0
        )
        #expect(!results.isEmpty, "Stemmed query 'diplomat' should match indexed 'diplomatic'")
    }

    // MARK: - Phrase Search

    @Test("Phrase search returns only documents with exact phrase")
    func phraseSearch() async throws {
        let (store, _) = try makeStore()
        try await store.insert(document: sampleDoc(id: "d1",
            body: "The cold war dominated international relations for decades."))
        try await store.insert(document: sampleDoc(id: "d2",
            body: "The war was cold in temperature and hot in rhetoric."))
        try await store.insert(document: sampleDoc(id: "d3",
            body: "Kissinger discussed arms reduction."))

        let results = try await store.search(
            query: FTS5Query(phrase: "cold war"),
            limit: 10,
            offset: 0
        )
        let ids = results.map(\.documentId)
        #expect(ids.contains("d1"), "d1 contains 'cold war' phrase")
        // d2 has "war" and "cold" but not as adjacent phrase "cold war"
        #expect(!ids.contains("d3"))
    }

    // MARK: - Boolean OR

    @Test("Boolean OR returns documents matching either term")
    func booleanOR() async throws {
        let (store, _) = try makeStore()
        try await store.insert(document: sampleDoc(id: "d1", body: "Cold war tensions."))
        try await store.insert(document: sampleDoc(id: "d2", body: "Korea policy review."))
        try await store.insert(document: sampleDoc(id: "d3", body: "Unrelated mineral deposits."))

        let results = try await store.search(
            query: FTS5Query(keywords: ["cold", "korea"], booleanMode: .or),
            limit: 10,
            offset: 0
        )
        let ids = Set(results.map(\.documentId))
        #expect(ids.contains("d1"))
        #expect(ids.contains("d2"))
        #expect(!ids.contains("d3"))
    }

    // MARK: - Boolean NOT

    @Test("Boolean NOT excludes documents containing the excluded term")
    func booleanNOT() async throws {
        let (store, _) = try makeStore()
        try await store.insert(document: sampleDoc(id: "d1", body: "Cold war negotiations in Berlin."))
        try await store.insert(document: sampleDoc(id: "d2", body: "Cold war tensions in Korea."))
        try await store.insert(document: sampleDoc(id: "d3", body: "Cold weather forecasts."))

        var query = FTS5Query(keywords: ["cold"])
        query.excludedTerms = ["korea"]
        let results = try await store.search(query: query, limit: 10, offset: 0)
        let ids = Set(results.map(\.documentId))
        #expect(ids.contains("d1"))
        #expect(!ids.contains("d2"), "d2 contains 'korea' and should be excluded")
    }

    // MARK: - Prefix Wildcard

    @Test("Prefix wildcard matches all terms starting with the prefix")
    func prefixWildcard() async throws {
        let (store, _) = try makeStore()
        try await store.insert(document: sampleDoc(id: "d1", body: "Diplomatic negotiations proceeded."))
        try await store.insert(document: sampleDoc(id: "d2", body: "The diplomat arrived in Moscow."))
        try await store.insert(document: sampleDoc(id: "d3", body: "Unrelated content about minerals."))

        // "diplom" stems to "diplom"; prefix search should find both d1 and d2
        let results = try await store.search(
            query: FTS5Query(prefixWildcard: "diplom"),
            limit: 10,
            offset: 0
        )
        let ids = Set(results.map(\.documentId))
        #expect(ids.contains("d1"))
        #expect(ids.contains("d2"))
        #expect(!ids.contains("d3"))
    }

    // MARK: - Subject Tag Filter

    @Test("Subject tag filter returns only documents with matching tag")
    func subjectTagFilter() async throws {
        let (store, _) = try makeStore()
        try await store.insert(document: sampleDoc(
            id: "d1", body: "Arms control discussions.",
            subjectTagIds: "arms-control-and-disarmament nuclear-weapons"))
        try await store.insert(document: sampleDoc(
            id: "d2", body: "Soviet arms control position.",
            subjectTagIds: "russia arms-control-and-disarmament"))
        try await store.insert(document: sampleDoc(
            id: "d3", body: "Bilateral arms review.",
            subjectTagIds: "russia"))

        var query = FTS5Query(keywords: ["arms"])
        query.subjectTagId = "nuclear-weapons"
        let results = try await store.search(query: query, limit: 10, offset: 0)
        let ids = results.map(\.documentId)
        #expect(ids == ["d1"])
    }

    // MARK: - Incremental Update

    @Test("New documents added after initial inserts are immediately searchable")
    func incrementalUpdate() async throws {
        let (store, _) = try makeStore()
        try await store.insert(document: sampleDoc(id: "d1", body: "Initial document content."))

        // Verify initial state
        var results = try await store.search(
            query: FTS5Query(keywords: ["initial"]),
            limit: 10, offset: 0)
        #expect(results.count == 1)

        // Add a new document
        try await store.insert(document: sampleDoc(
            id: "d2",
            volumeId: "frus1969-76v02",
            body: "Subsequent document about Kissinger."))

        results = try await store.search(
            query: FTS5Query(keywords: ["kissinger"]),
            limit: 10, offset: 0)
        #expect(results.count == 1)
        #expect(results[0].documentId == "d2")
    }

    // MARK: - Delete

    @Test("Deleted document no longer appears in search results")
    func deleteDocument() async throws {
        let (store, _) = try makeStore()
        try await store.insert(document: sampleDoc(id: "d1", body: "Soviet strategic interests."))
        try await store.insert(document: sampleDoc(id: "d2", body: "Soviet tactical doctrine."))

        var results = try await store.search(
            query: FTS5Query(keywords: ["soviet"]),
            limit: 10, offset: 0)
        #expect(results.count == 2)

        try await store.delete(documentId: "d1", volumeId: "frus1969-76v01")

        results = try await store.search(
            query: FTS5Query(keywords: ["soviet"]),
            limit: 10, offset: 0)
        let ids = results.map(\.documentId)
        #expect(!ids.contains("d1"), "Deleted document should not appear")
        #expect(ids.contains("d2"))
    }

    @Test("Delete is scoped by volume: same document_id in another volume survives")
    func deleteScopedByVolume() async throws {
        let (store, _) = try makeStore()
        // FRUS document IDs repeat in every volume — "d1" exists in both volumes here.
        try await store.insert(document: sampleDoc(
            id: "d1", volumeId: "frus1969-76v01", body: "Soviet strategic interests."))
        try await store.insert(document: sampleDoc(
            id: "d1", volumeId: "frus1969-76v02", body: "Soviet tactical doctrine."))

        try await store.delete(documentId: "d1", volumeId: "frus1969-76v01")

        let results = try await store.search(
            query: FTS5Query(keywords: ["soviet"]),
            limit: 10, offset: 0)
        #expect(results.count == 1, "Only the targeted volume's d1 should be deleted")
        #expect(results.first?.volumeId == "frus1969-76v02",
                "The other volume's d1 must survive a volume-scoped delete")
    }

    @Test("Update is scoped by volume: same document_id in another volume survives")
    func updateScopedByVolume() async throws {
        let (store, _) = try makeStore()
        try await store.insert(document: sampleDoc(
            id: "d1", volumeId: "frus1969-76v01", body: "Original text about detente."))
        try await store.insert(document: sampleDoc(
            id: "d1", volumeId: "frus1969-76v02", body: "Unrelated text about Berlin."))

        // Simulates a summary/note update: replace volume 1's d1 row.
        try await store.update(document: sampleDoc(
            id: "d1", volumeId: "frus1969-76v01", body: "Updated text about detente."))

        let berlin = try await store.search(
            query: FTS5Query(keywords: ["berlin"]),
            limit: 10, offset: 0)
        #expect(berlin.count == 1,
                "Updating v01/d1 must not delete v02/d1 (regression: unscoped delete)")

        let updated = try await store.search(
            query: FTS5Query(keywords: ["updated"]),
            limit: 10, offset: 0)
        #expect(updated.count == 1)
        #expect(updated.first?.volumeId == "frus1969-76v01")

        // The replaced row must not be duplicated.
        let detente = try await store.search(
            query: FTS5Query(keywords: ["detente"]),
            limit: 10, offset: 0)
        #expect(detente.count == 1, "Update must replace, not duplicate, the row")
    }

    // MARK: - Batch Insert Performance

    @Test("Batch insert of 1,000 documents completes and all documents are searchable")
    func batchInsertPerformance() async throws {
        let (store, _) = try makeStore()
        let marker = "uniquebatchmarker"
        let docs = (0..<1000).map { i in
            FTS5Document(
                id: "batch-\(i)",
                volumeId: "frus1969-76v01",
                header: "Document \(i)",
                bodyText: "\(marker) document number \(i) content here"
            )
        }

        let start = Date()
        try await store.insertBatch(docs)
        let elapsed = Date().timeIntervalSince(start)

        // Batch insert of 1,000 documents should complete in under 10 seconds
        // even on a slow CI machine.
        #expect(elapsed < 10.0, "Batch insert took \(elapsed)s, expected < 10s")

        // Spot-check: at least one result for the marker term
        let results = try await store.search(
            query: FTS5Query(keywords: [marker]),
            limit: 5, offset: 0)
        #expect(!results.isEmpty)
    }

    // MARK: - Storage Size

    @Test("storageSize returns non-zero after insertion")
    func storageSizeNonZero() async throws {
        let (store, _) = try makeStore()
        try await store.insert(document: sampleDoc())
        let size = try await store.storageSize()
        #expect(size > 0)
    }

    // MARK: - Backup Exclusion

    @Test("Database file has isExcludedFromBackupKey set after creation")
    func backupExclusion() async throws {
        let (_, url) = try makeStore()
        var value: AnyObject?
        try (url as NSURL).getResourceValue(&value, forKey: .isExcludedFromBackupKey)
        #expect((value as? Bool) == true)
    }

    // MARK: - External-Content Behaviour

    @Test("Direct writes to an external-content store are rejected")
    func externalContentWritesRejected() async throws {
        let (testStore, _) = try makeStore()
        await #expect(throws: FTS5Error.self) {
            try await testStore.store.insert(document: sampleDoc())
        }
    }

    @Test("Summary text matches in user_content, not in the corpus table")
    func summaryTextSearchedSeparately() async throws {
        let (store, _) = try makeStore()
        try await store.insert(document: sampleDoc(
            id: "d1",
            body: "Telegram about grain exports."
        ))
        try await store.update(document: FTS5Document(
            id: "d1", volumeId: "frus1969-76v01",
            header: "Memorandum of Conversation",
            bodyText: "Telegram about grain exports.",
            summaryText: "Discusses wheat shipment quotas."
        ))

        // The corpus table must not match summary-only words…
        let corpus = try await store.search(
            query: FTS5Query(keywords: ["wheat"]), limit: 10, offset: 0)
        #expect(corpus.isEmpty, "summary text must not be indexed in frus_documents")

        // …but user_content must.
        let userRows = try store.userContentMatches("wheat")
        #expect(userRows.count == 1)
        #expect(userRows.first?.documentId == "d1")
    }

    @Test("Note-only update syncs user_content and leaves the corpus index intact")
    func noteUpdateDoesNotTouchCorpus() async throws {
        let (store, _) = try makeStore()
        try await store.insert(document: sampleDoc(
            id: "d1", body: "Negotiations over the blockade."))

        try store.setNoteText("remember the armistice angle",
                              documentId: "d1", volumeId: "frus1969-76v01")

        // Corpus search unaffected by the note write.
        let corpus = try await store.search(
            query: FTS5Query(keywords: ["blockade"]), limit: 10, offset: 0)
        #expect(corpus.count == 1)

        // The note is searchable in user_content (porter stems "armistice").
        let noteRows = try store.userContentMatches("armistice")
        #expect(noteRows.count == 1)

        // Clearing the note removes it from user_content.
        try store.setNoteText(nil, documentId: "d1", volumeId: "frus1969-76v01")
        let cleared = try store.userContentMatches("armistice")
        #expect(cleared.isEmpty)
    }
}

// MARK: - PorterStemmerTests

/// Unit tests for the Porter stemmer, independent of the SQLite layer.
struct PorterStemmerTests {

    @Test("Plural → singular: 'negotiations' stems to 'negoti'")
    func negotiations() {
        #expect(PorterStemmer.stem("negotiations") == PorterStemmer.stem("negotiate"))
    }

    @Test("Past tense: 'negotiated' stems same as 'negotiate'")
    func negotiated() {
        let stemBase = PorterStemmer.stem("negotiate")
        let stemPast = PorterStemmer.stem("negotiated")
        #expect(stemBase == stemPast)
    }

    @Test("Present participle: 'negotiating' stems same as 'negotiate'")
    func negotiating() {
        let stemBase = PorterStemmer.stem("negotiate")
        let stemProg = PorterStemmer.stem("negotiating")
        #expect(stemBase == stemProg)
    }

    @Test("Short words (≤ 2 chars) returned unchanged")
    func shortWords() {
        #expect(PorterStemmer.stem("a") == "a")
        #expect(PorterStemmer.stem("is") == "is")
    }

    @Test("'caresses' → 'caress' (Step 1a sses)")
    func caresses() {
        #expect(PorterStemmer.stem("caresses") == PorterStemmer.stem("caress"))
    }

    @Test("'running' → stem via Step 1b ing removal")
    func running() {
        #expect(PorterStemmer.stem("running") == PorterStemmer.stem("run"))
    }
}

// MARK: - FTS5QueryTests

/// Unit tests for `FTS5Query.toFTS5MatchExpression()`.
struct FTS5QueryTests {

    @Test("Single keyword produces a quoted term expression")
    func singleKeyword() {
        let q = FTS5Query(keywords: ["nuclear"])
        let expr = q.toFTS5MatchExpression()
        #expect(expr == "\"nuclear\"")
    }

    @Test("Multiple keywords joined with AND by default")
    func multipleKeywordsAND() {
        let q = FTS5Query(keywords: ["cold", "war"])
        let expr = q.toFTS5MatchExpression()
        #expect(expr == "\"cold\" \"war\"")
    }

    @Test("Multiple keywords joined with OR in .or mode")
    func multipleKeywordsOR() {
        let q = FTS5Query(keywords: ["cold", "korea"], booleanMode: .or)
        let expr = q.toFTS5MatchExpression()
        #expect(expr == "\"cold\" OR \"korea\"")
    }

    @Test("Phrase search wraps term in double quotes")
    func phraseExpression() {
        let q = FTS5Query(phrase: "cold war")
        let expr = q.toFTS5MatchExpression()
        #expect(expr == "\"cold war\"")
    }

    @Test("NOT terms appended correctly")
    func notTerms() {
        var q = FTS5Query(keywords: ["cold"])
        q.excludedTerms = ["korea"]
        let expr = q.toFTS5MatchExpression()
        #expect(expr == "\"cold\" NOT \"korea\"")
    }

    @Test("Prefix wildcard appends asterisk after the quoted prefix")
    func prefixWildcard() {
        let q = FTS5Query(prefixWildcard: "negoti")
        let expr = q.toFTS5MatchExpression()
        #expect(expr == "\"negoti\"*")
    }

    @Test("Empty query returns nil")
    func emptyQuery() {
        let q = FTS5Query()
        #expect(q.toFTS5MatchExpression() == nil)
    }

    @Test("Column scope prefix applied to keywords")
    func columnScope() {
        let q = FTS5Query(keywords: ["cold"], columns: [.header, .bodyText])
        let expr = q.toFTS5MatchExpression()
        #expect(expr == "{header body_text}:\"cold\"")
    }

    @Test("Injected FTS5 operators in keyword are neutralised inside a quoted string")
    func sanitizeInjection() {
        let q = FTS5Query(keywords: ["cold OR war AND NOT"])
        let expr = q.toFTS5MatchExpression()
        // Structural punctuation is stripped by the sanitizer and the whole term is
        // embedded as one quoted string, so the operator words become literal
        // (lowercased) search words rather than FTS5 syntax.
        #expect(expr == "\"cold or war and not\"")
    }

    @Test("Keywords keep their original word form — the tokenizer stems, not the app")
    func keywordsNotStemmedInExpression() {
        // Pre-redesign, "negotiations" rendered as the Porter stem "negoti". The
        // porter tokenizer now stems inside SQLite, so the expression must carry the
        // user's original word for the tokenizer to transform symmetrically.
        let q = FTS5Query(keywords: ["negotiations"])
        #expect(q.toFTS5MatchExpression() == "\"negotiations\"")
    }

    @Test("Apostrophes survive sanitisation safely inside the quoted term")
    func apostropheKeywordQuoted() {
        // "don't" is not a valid FTS5 bareword (apostrophes are syntax errors
        // unquoted) but is safe inside a quoted string, where unicode61 tokenizes
        // it exactly as it tokenized the indexed text.
        let q = FTS5Query(keywords: ["don't"])
        #expect(q.toFTS5MatchExpression() == "\"don't\"")
    }
}
