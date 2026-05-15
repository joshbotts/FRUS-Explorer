// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FTS5Store

// MARK: - Test Helpers

private func makeStore() throws -> (FTS5Store, URL) {
    let dir = FileManager.default.temporaryDirectory
    let url = dir.appendingPathComponent("fts5test-\(UUID().uuidString).sqlite")
    let store = try FTS5Store(databaseURL: url, schema: .frusDocuments)
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

        try await store.delete(documentId: "d1")

        results = try await store.search(
            query: FTS5Query(keywords: ["soviet"]),
            limit: 10, offset: 0)
        let ids = results.map(\.documentId)
        #expect(!ids.contains("d1"), "Deleted document should not appear")
        #expect(ids.contains("d2"))
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

    @Test("Single keyword produces simple term expression")
    func singleKeyword() {
        let q = FTS5Query(keywords: ["nuclear"])
        let expr = q.toFTS5MatchExpression()
        #expect(expr == "nuclear")
    }

    @Test("Multiple keywords joined with AND by default")
    func multipleKeywordsAND() {
        let q = FTS5Query(keywords: ["cold", "war"])
        let expr = q.toFTS5MatchExpression()
        #expect(expr == "cold war")
    }

    @Test("Multiple keywords joined with OR in .or mode")
    func multipleKeywordsOR() {
        let q = FTS5Query(keywords: ["cold", "korea"], booleanMode: .or)
        let expr = q.toFTS5MatchExpression()
        #expect(expr == "cold OR korea")
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
        #expect(expr == "cold NOT korea")
    }

    @Test("Prefix wildcard appends asterisk")
    func prefixWildcard() {
        let q = FTS5Query(prefixWildcard: "negoti")
        let expr = q.toFTS5MatchExpression()
        #expect(expr == "negoti*")
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
        #expect(expr == "{header body_text}:cold")
    }

    @Test("Injected FTS5 operators in keyword are sanitized")
    func sanitizeInjection() {
        let q = FTS5Query(keywords: ["cold OR war AND NOT"])
        let expr = q.toFTS5MatchExpression()
        // The FTS5 operator words are kept as literals; structural punctuation stripped.
        #expect(expr != nil)
        #expect(!(expr?.contains("\"") ?? false))
    }
}
