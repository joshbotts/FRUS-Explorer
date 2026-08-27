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

// MARK: - LexicalCandidateQueryTests

/// The W-17 lexical-similarity store entry point (`lexicalCandidates`), against a real
/// on-disk `porter unicode61` table — the same no-mocks rule as `FTS5VocabularyTests`,
/// because the two things under test are exactly the parts a mock would assume away:
/// FTS5's column-filter syntax and the vocabulary-priced term admission.
///
/// Version history:
///   1.0 — W-17 session 1: initial implementation
@Suite("Lexical candidate query")
struct LexicalCandidateQueryTests {

    /// d1 and d3 carry *containment* in `body_text` (d3 four times, so it must outrank
    /// d1); d2 carries it ONLY in `header` — the column-restriction sentinel, which also
    /// makes *containment*'s vocabulary df **3, not 2**: `fts5vocab` counts every
    /// indexed column, the documented table-wide-pricing asymmetry. *europe* appears in
    /// four bodies (df 4), so a ceiling of 3 separates the two terms.
    private static let corpus: [(id: String, header: String, body: String)] = [
        ("d1", "1. Memorandum", "the containment doctrine shaped policy in europe"),
        ("d2", "containment review", "economic recovery in europe"),
        ("d3", "3. Report", "containment, containment, containment — a strategy of containment"),
        ("d4", "4. Telegram", "recovery programme across europe"),
        ("d5", "5. Note", "the ministers met in europe"),
    ]

    private func makeStore() async throws -> (FTS5Store, URL) {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lexcand-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let schema = FTS5Schema(
            tableName: "frus_documents",
            columns: [.documentId, .volumeId, .header, .bodyText],
            tokenizerName: "porter unicode61"
        )
        let store = try FTS5Store(databaseURL: dir.appendingPathComponent("test.db"),
                                  schema: schema)
        for doc in Self.corpus {
            try await store.insert(document: FTS5Document(
                id: doc.id, volumeId: "v1", header: doc.header, bodyText: doc.body))
        }
        return (store, dir)
    }

    private func cleanUp(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    @Test("The MATCH is column-restricted: a header-only occurrence does not qualify")
    func columnRestriction() async throws {
        let (store, dir) = try await makeStore()
        defer { cleanUp(dir) }
        let (candidates, admitted) = try await store.lexicalCandidates(
            terms: ["containment"], dfCeiling: 100, limit: 10)
        #expect(admitted == ["containment"])
        let ids = candidates.map(\.documentId)
        #expect(ids.contains("d1") && ids.contains("d3"))
        #expect(!ids.contains("d2"),
                "d2 carries the term only in `header` — matching it means the column filter is off and the query is partly re-deriving the archival axis")
    }

    @Test("Repetition ranks: the heavier body outranks the lighter, and bm25 is negative")
    func repetitionRanks() async throws {
        let (store, dir) = try await makeStore()
        defer { cleanUp(dir) }
        let (candidates, _) = try await store.lexicalCandidates(
            terms: ["containment"], dfCeiling: 100, limit: 10)
        let first = try #require(candidates.first)
        #expect(first.documentId == "d3", "four occurrences must outrank one")
        #expect(candidates.allSatisfy { $0.bm25 < 0 },
                "SQLite bm25() is negative for matches; a sign flip would invert every ranking built on it")
    }

    @Test("A term over the df ceiling is dropped before the query runs")
    func ceilingDropsCommonTerm() async throws {
        let (store, dir) = try await makeStore()
        defer { cleanUp(dir) }
        // *europe* has document frequency 4, *containment* 3 (d2's header occurrence
        // counts — the table-wide pricing the entry point documents). Ceiling 3 admits
        // one and refuses the other.
        let (candidates, admitted) = try await store.lexicalCandidates(
            terms: ["containment", "europe"], dfCeiling: 3, limit: 10)
        #expect(admitted == ["containment"])
        let ids = candidates.map(\.documentId)
        #expect(!ids.contains("d5"), "d5 matches only the refused term")
    }

    @Test("All terms over the ceiling yields the empty answer, not a broad query")
    func allOverCeiling() async throws {
        let (store, dir) = try await makeStore()
        defer { cleanUp(dir) }
        let (candidates, admitted) = try await store.lexicalCandidates(
            terms: ["europe"], dfCeiling: 1, limit: 10)
        #expect(candidates.isEmpty && admitted.isEmpty)
    }

    @Test("An unseen term is dropped; the rest of the query still runs")
    func unseenTermDropped() async throws {
        let (store, dir) = try await makeStore()
        defer { cleanUp(dir) }
        let (candidates, admitted) = try await store.lexicalCandidates(
            terms: ["zzzunlikelyterm", "containment"], dfCeiling: 100, limit: 10)
        #expect(admitted == ["containment"])
        #expect(!candidates.isEmpty)
    }

    @Test("Two surface forms of one stem are queried once, first form kept")
    func stemDeduplication() async throws {
        let (store, dir) = try await makeStore()
        defer { cleanUp(dir) }
        let (_, admitted) = try await store.lexicalCandidates(
            terms: ["containment", "containing"], dfCeiling: 100, limit: 10)
        #expect(admitted == ["containment"],
                "both stem to `contain`; querying twice would double-weight the term")
    }

    @Test("OR semantics: a document matching either admitted term appears")
    func orSemantics() async throws {
        let (store, dir) = try await makeStore()
        defer { cleanUp(dir) }
        let (candidates, admitted) = try await store.lexicalCandidates(
            terms: ["containment", "recovery"], dfCeiling: 100, limit: 10)
        #expect(admitted == ["containment", "recovery"])
        let ids = Set(candidates.map(\.documentId))
        #expect(ids.isSuperset(of: ["d1", "d3", "d2", "d4"]),
                "d2/d4 match only recovery, d1/d3 only containment — OR must reach all four")
    }

    @Test("A quote in a surface form is data, not query syntax")
    func quotingIsSafe() async throws {
        let (store, dir) = try await makeStore()
        defer { cleanUp(dir) }
        // Must not throw; the term tokenizes to nothing quote-shaped and simply misses.
        _ = try await store.lexicalCandidates(
            terms: ["contain\"ment"], dfCeiling: 100, limit: 10)
    }

    @Test("A schema without the named columns is refused legibly")
    func schemaGuard() async throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lexcand-guard-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { cleanUp(dir) }
        let bodyOnly = FTS5Schema(tableName: "frus_documents", columns: [.bodyText],
                                  tokenizerName: "porter unicode61")
        let store = try FTS5Store(databaseURL: dir.appendingPathComponent("test.db"),
                                  schema: bodyOnly)
        await #expect(throws: FTS5Error.self) {
            _ = try await store.lexicalCandidates(terms: ["containment"], dfCeiling: 10, limit: 5)
        }
    }
}
