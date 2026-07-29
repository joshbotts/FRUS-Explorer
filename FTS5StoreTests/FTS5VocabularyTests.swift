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

// MARK: - FTS5VocabularyTests

/// The corpus vocabulary (`fts5vocab`) and the stem transparency it makes possible (Q-3a).
///
/// Every test here runs against a real on-disk `porter unicode61` FTS5 table, because the
/// whole point of this layer is that it reports what SQLite actually did — a mock would
/// only report what we assumed.
///
/// Version history:
///   1.0 — Q-3a: initial implementation
@Suite("Corpus vocabulary and stem transparency")
struct FTS5VocabularyTests {

    // MARK: - Fixture

    /// A corpus chosen so the reports' own stemming trap is reproducible in miniature:
    /// four surface forms of *industry* and three of *production*, plus a term that
    /// appears many times in few documents (the "one memo with a tic" shape).
    private static let corpus: [String] = [
        "The policy of containment was debated. Containment again, and containment once more.",
        "We must contain the threat; containing it is the priority.",
        "industrial production statistics and industry output",
        "industries, industrialization, industrialized economies",
        "production, productive capacity, productivity gains",
        "Europe and the European recovery programme",
        // Present so the two-stemmer test exercises a real disagreement rather than
        // skipping it: Swift's PorterStemmer says `alli`, SQLite's says `allianc`.
        "the atlantic alliance and its alliances in western europe",
    ]

    /// Opens a real store on a temp file, seeds `corpus` through the content table so the
    /// external-content triggers populate the index, and returns it.
    private func makeStore() async throws -> (FTS5Store, URL) {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("fts5vocab-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("test.db")

        // A minimal single-column schema keeps the fixture readable; the vocabulary code
        // under test is schema-agnostic and the app's real schema is exercised by the
        // app-side suites.
        let schema = FTS5Schema(
            tableName: "frus_documents",
            columns: [.bodyText],
            tokenizerName: "porter unicode61"
        )
        let store = try FTS5Store(databaseURL: url, schema: schema)
        for (index, body) in Self.corpus.enumerated() {
            try await store.insert(document: FTS5Document(
                id: "d\(index)", volumeId: "v1", header: "", bodyText: body
            ))
        }
        return (store, dir)
    }

    private func cleanUp(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    // MARK: - The table exists and is populated

    @Test("The vocab table is created alongside the schema and holds terms")
    func vocabTableIsWired() async throws {
        let (store, dir) = try await makeStore()
        defer { cleanUp(dir) }
        let size = try await store.vocabularySize()
        #expect(size > 0, "fts5vocab returned no terms — the table is not wired up")
    }

    @Test("The vocab table name is derived from the schema, not hardcoded")
    func vocabTableNaming() {
        #expect(FTS5Schema.frusDocuments.vocabTableName == "frus_documents_vocab")
        #expect(FTS5Schema.userContent.vocabTableName == "user_content_vocab")
    }

    // MARK: - The stemming trap, reproduced

    @Test("Four surface forms of 'industry' collapse to one index term")
    func industryFormsCollapse() async throws {
        let (store, dir) = try await makeStore()
        defer { cleanUp(dir) }
        var stems = Set<String>()
        for form in ["industrial", "industry", "industries", "industrialization"] {
            let stem = try await store.indexStem(of: form)
            #expect(stem != nil, "\(form) did not tokenize to a single term")
            if let stem { stems.insert(stem) }
        }
        #expect(stems.count == 1,
                "the reports' central stemming trap did not reproduce — got \(stems.sorted())")
    }

    @Test("Three surface forms of 'production' collapse to one index term")
    func productionFormsCollapse() async throws {
        let (store, dir) = try await makeStore()
        defer { cleanUp(dir) }
        var stems = Set<String>()
        for form in ["production", "productive", "productivity"] {
            if let stem = try await store.indexStem(of: form) { stems.insert(stem) }
        }
        #expect(stems.count == 1, "expected one stem, got \(stems.sorted())")
    }

    @Test("A profile reports the search that actually ran, not the word typed")
    func profileNamesTheRealSearch() async throws {
        let (store, dir) = try await makeStore()
        defer { cleanUp(dir) }
        let profile = try #require(try await store.termProfile(for: "containment"))
        #expect(profile.surfaceForm == "containment")
        #expect(profile.stem == "contain")
        #expect(profile.isStemmed, "containment → contain is exactly the case worth warning about")
        // Two documents carry the stem: the containment one and the "contain/containing" one.
        // That second document is the trap: it is not about containment policy at all.
        #expect(profile.documentFrequency == 2)
    }

    @Test("Case and surrounding whitespace do not change the answer")
    func profileNormalizesInput() async throws {
        let (store, dir) = try await makeStore()
        defer { cleanUp(dir) }
        let plain = try #require(try await store.termProfile(for: "containment"))
        for variant in ["  Containment ", "CONTAINMENT", "ContainMent"] {
            let profile = try #require(try await store.termProfile(for: variant))
            #expect(profile == plain, "variant \(variant) profiled differently")
        }
    }

    // MARK: - Documents vs occurrences

    @Test("Occurrences and document frequency are different numbers, and both are reported")
    func occurrencesDifferFromDocuments() async throws {
        let (store, dir) = try await makeStore()
        defer { cleanUp(dir) }
        let profile = try #require(try await store.termProfile(for: "containment"))
        // "containment" appears 3× in d0 alone, plus contain/containing in d1.
        #expect(profile.occurrences > profile.documentFrequency,
                "occurrences must exceed documents for a term repeated within a document")
        let perDoc = try #require(profile.occurrencesPerDocument)
        #expect(perDoc > 1.0, "the concentration signal is what distinguishes a tic from a pattern")
    }

    @Test("occurrencesPerDocument is nil rather than a divide-by-zero for an unseen term")
    func perDocumentIsNilWhenUnseen() async throws {
        let (store, dir) = try await makeStore()
        defer { cleanUp(dir) }
        let profile = try #require(try await store.termProfile(for: "zzzunlikelyterm"))
        #expect(profile.documentFrequency == 0)
        #expect(profile.occurrencesPerDocument == nil)
    }

    // MARK: - Honest edges

    @Test("A word the index has never seen profiles as zero, not nil")
    func unseenTermIsZeroNotNil() async throws {
        let (store, dir) = try await makeStore()
        defer { cleanUp(dir) }
        // "0 documents" is a real answer and must be distinguishable from "this question
        // does not apply", which is what nil means here.
        let profile = try #require(try await store.termProfile(for: "zzzunlikelyterm"))
        #expect(profile.documentFrequency == 0)
        #expect(profile.occurrences == 0)
    }

    @Test("Multi-token input has no single stem and says so")
    func multiTokenInputReturnsNil() async throws {
        let (store, dir) = try await makeStore()
        defer { cleanUp(dir) }
        #expect(try await store.indexStem(of: "military guarantee") == nil)
        #expect(try await store.termProfile(for: "military guarantee") == nil)
        // Punctuation that explodes into several terms is the same situation.
        #expect(try await store.indexStem(of: "U.S.S.R.") == nil)
    }

    @Test("Empty and whitespace-only input yield nil rather than a bogus profile")
    func emptyInput() async throws {
        let (store, dir) = try await makeStore()
        defer { cleanUp(dir) }
        #expect(try await store.indexStem(of: "") == nil)
        #expect(try await store.indexStem(of: "   ") == nil)
        #expect(try await store.termProfile(for: "  ") == nil)
    }

    @Test("tokenize reports every term a phrase indexes as")
    func tokenizeExposesTheWholeSet() async throws {
        let (store, dir) = try await makeStore()
        defer { cleanUp(dir) }
        let terms = try await store.tokenize("U.S.S.R.")
        #expect(terms.count > 1, "the acronym indexes as several terms, which is the point")
    }

    /// The probe is reused across calls, so a leaked row from a previous lookup would
    /// silently add its terms to the next answer — and the failure would look like a
    /// tokenizer quirk rather than a bug.
    @Test("Consecutive lookups do not contaminate each other")
    func probeDoesNotLeakBetweenLookups() async throws {
        let (store, dir) = try await makeStore()
        defer { cleanUp(dir) }
        #expect(try await store.indexStem(of: "containment") == "contain")
        #expect(try await store.indexStem(of: "industrialization") == "industri")
        #expect(try await store.indexStem(of: "containment") == "contain")
        // A multi-token call in the middle is the sharpest version of the same risk.
        _ = try await store.tokenize("military guarantee europe")
        #expect(try await store.indexStem(of: "containment") == "contain")
    }

    // MARK: - The two-stemmer disagreement, measured

    /// The hazard Q-3 exists to close, stated as a measurement rather than a belief.
    ///
    /// The app ships two Porter implementations: Swift `PorterStemmer` (snippet
    /// highlighting) and SQLite's `porter unicode61` (which built the index). If they
    /// agreed everywhere, sourcing a stem line from either would be fine and this whole
    /// layer would be unnecessary. This test records the truth either way, so a future
    /// session reads a number instead of re-litigating the question.
    @Test("Where the two stemmers disagree, only SQLite's answer can be looked up")
    func twoStemmersDisagreeAndSQLiteWins() async throws {
        let (store, dir) = try await makeStore()
        defer { cleanUp(dir) }

        let words = ["containment", "industrialization", "productivity", "guarantees",
                     "europe", "policies", "negotiating", "alliance", "agreed",
                     "commitments", "sovereignty", "recovery"]

        var disagreements: [(String, swift: String, sqlite: String)] = []
        for word in words {
            let sqliteStem = try #require(try await store.indexStem(of: word),
                                          "\(word) should be a single token")
            let swiftStem = PorterStemmer.stem(word)
            if swiftStem != sqliteStem {
                disagreements.append((word, swift: swiftStem, sqlite: sqliteStem))
            }
        }

        // Not an assertion about the *count* — that would break on any tokenizer update
        // for no good reason. The assertion is the one that matters: whatever SQLite
        // produced is what the index contains, so it is always the lookupable one.
        for word in words {
            let profile = try #require(try await store.termProfile(for: word))
            let byStem = try await store.vocabularyEntry(stem: profile.stem)
            let bySwift = try await store.vocabularyEntry(stem: PorterStemmer.stem(word))
            if profile.documentFrequency > 0 {
                #expect(byStem != nil,
                        "SQLite's own stem for \(word) must be present in its own vocabulary")
                if PorterStemmer.stem(word) != profile.stem {
                    #expect(bySwift == nil || bySwift?.documentFrequency != profile.documentFrequency,
                            "the Swift stem for \(word) resolved identically, so this test is not measuring what it claims")
                }
            }
        }

        // The disagreement must be REAL for at least one word this corpus contains,
        // otherwise the whole premise of sourcing stems from SQLite is unevidenced and
        // this test is decoration. `alliance` is the case, and it is not incidental —
        // it is the central noun of the report this workstream is built to reproduce.
        let alliance = try #require(try await store.termProfile(for: "alliance"))
        #expect(alliance.stem == "allianc", "SQLite's stem for alliance changed")
        #expect(PorterStemmer.stem("alliance") == "alli", "the Swift stem for alliance changed")
        #expect(alliance.documentFrequency > 0, "the corpus must actually contain alliance")
        #expect(try await store.vocabularyEntry(stem: "alli") == nil,
                "the Swift stem `alli` must be absent from the index — that absence is the entire reason a stem line cannot be sourced from PorterStemmer")

        // Recorded, not asserted — visible in the test log when it matters.
        if !disagreements.isEmpty {
            let summary = disagreements
                .map { "\($0.0): swift=\($0.swift) sqlite=\($0.sqlite)" }
                .joined(separator: "; ")
            print("[FTS5VocabularyTests] stemmer disagreement (informational): \(summary)")
        }
    }

    // MARK: - Schema lifecycle

    /// A schema rebuild drops and recreates the FTS5 table. The vocabulary must come
    /// back with it, empty, and must track the new index rather than lingering as an
    /// inert leftover.
    ///
    /// This does **not** prove the drop *ordering* in `createSchema` is required — it is
    /// not, since the source is recreated under the same name immediately after. See the
    /// comment there. What this covers is that a rebuilt database has a working, correct
    /// vocabulary at all.
    @Test("A schema rebuild leaves a working, empty vocabulary that then repopulates")
    func rebuildDoesNotOrphanTheVocabTable() async throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("fts5vocab-rebuild-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { cleanUp(dir) }
        let url = dir.appendingPathComponent("test.db")
        let schema = FTS5Schema(tableName: "frus_documents", columns: [.bodyText],
                                tokenizerName: "porter unicode61")

        // First open creates everything, then force the migration path by resetting the
        // stamped generation so the next open drops and recreates.
        do {
            let store = try FTS5Store(databaseURL: url, schema: schema)
            try await store.insert(document: FTS5Document(
                id: "d0", volumeId: "v1", header: "", bodyText: "containment policy"))
            #expect(try await store.vocabularySize() > 0)
        }
        var db: OpaquePointer?
        #expect(sqlite3_open(url.path, &db) == SQLITE_OK)
        #expect(sqlite3_exec(db, "PRAGMA user_version = 0", nil, nil, nil) == SQLITE_OK)
        sqlite3_close(db)

        let reopened = try FTS5Store(databaseURL: url, schema: schema)

        // Two real assertions. First: the call must not throw — a missing or dangling
        // vocab table surfaces here and nowhere earlier.
        let afterRebuild = try await reopened.vocabularySize()
        // Second, and this is the one an `>= 0` check silently skipped: the rebuild path
        // drops the index, so the vocabulary must be genuinely EMPTY rather than serving
        // stale terms from the dropped table's shadow rows.
        #expect(afterRebuild == 0,
                "the rebuilt index has no rows yet, so its vocabulary must be empty — got \(afterRebuild)")

        // And it must repopulate, proving the recreated vocab table tracks the recreated
        // index rather than being an inert leftover.
        try await reopened.insert(document: FTS5Document(
            id: "d1", volumeId: "v1", header: "", bodyText: "containment policy"))
        #expect(try await reopened.vocabularySize() > 0)
        let profile = try #require(try await reopened.termProfile(for: "containment"))
        #expect(profile.documentFrequency == 1)
    }
}
