// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SQLite3

// MARK: - FTS5Store + Vocabulary

// W-16 (2026-08-27): the `CorpusTermProfile` struct and its `termProfile(for:)` /
// `termProfiles(for:)` composition used to live here, carrying `occurrencesPerDocument`
// — the dispersion statistic — with zero app callers. The statistic shipped by a
// different route (#579): `InspectedOperand.corpusOccurrencesPerDocument` computes the
// same ratio from this file's `vocabularyEntry(stem:)` counts and the Query Inspector
// renders it, so the type here was a second definition waiting to drift. The primitives
// the live path composes — `indexStem(of:)`, `vocabularyEntry(stem:)` — remain below.

extension FTS5Store {

    /// Returns the term SQLite's tokenizer produces for `surfaceForm`, or `nil` when the
    /// input is not exactly one token.
    ///
    /// ## Why this does not use `PorterStemmer`
    /// The app ships two stemmers. `PorterStemmer` (Swift) is used for snippet
    /// highlighting; SQLite's `porter unicode61` is what actually built the index and
    /// answers every query. Nothing has ever asserted that the two agree, and where they
    /// disagree a Swift-computed stem would name a term the engine never wrote — so a
    /// stem line sourced from it could confidently display a lookup that must return
    /// zero. `FTS5VocabularyTests` measures the disagreement rather than assuming it away.
    ///
    /// This method sidesteps the question entirely by asking SQLite: it tokenizes the
    /// word through a scratch FTS5 table declared with **this store's own tokenizer** and
    /// reads back what landed in the index. The answer is the engine's, by construction.
    ///
    /// ## The single-token contract
    /// Multi-word input returns `nil`. `fts5vocab` in `'row'` mode is a set, not a
    /// sequence — it has no positional information — so several tokens come back sorted
    /// alphabetically with no way to map them to the words that produced them. A stem
    /// line is a per-word statement anyway; a phrase does not have "a" stem. Punctuation
    /// that tokenizes to several words (`U.S.S.R.` → `u`, `s`, `r`) is therefore `nil`
    /// too, which is the honest answer.
    public func indexStem(of surfaceForm: String) throws -> String? {
        let trimmed = surfaceForm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let stems = try tokenize(trimmed)
        return stems.count == 1 ? stems[0] : nil
    }

    /// Tokenizes `text` through this store's tokenizer and returns the resulting index
    /// terms, sorted (see ``indexStem(of:)`` for why order is not available).
    ///
    /// Exposed for tests and for callers that legitimately want the whole token set of a
    /// phrase — for instance to explain that `U.S.S.R.` indexes as four separate terms.
    public func tokenize(_ text: String) throws -> [String] {
        try connection.ensureStemProbe(tokenizer: schema.resolvedTokenizerName)
        return try connection.stems(of: text)
    }

    /// Looks up one stem in the corpus vocabulary.
    ///
    /// - Parameter stem: An index term, as produced by ``indexStem(of:)``. Passing a
    ///   surface form that the tokenizer would have changed simply misses.
    /// - Returns: `nil` when the index has never seen the term.
    public func vocabularyEntry(stem: String) throws -> (documentFrequency: Int, occurrences: Int)? {
        guard !stem.isEmpty else { return nil }
        let sql = "SELECT doc, cnt FROM \(schema.vocabTableName) WHERE term = ? LIMIT 1"
        let stmt = try connection.prepare(sql)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, stem, -1, FTS5Store.transientDestructor)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return (Int(sqlite3_column_int64(stmt, 0)), Int(sqlite3_column_int64(stmt, 1)))
    }

    /// One candidate row from ``lexicalCandidates(terms:dfCeiling:limit:)``.
    ///
    /// `bm25` is SQLite's raw `bm25()` value: **more negative is a stronger match**, and
    /// the scale is query-relative — the number is only meaningful against other rows of
    /// the same call (the W-17 scorer uses the `bm25(candidate)/bm25(anchor)` ratio,
    /// which is why the anchor document is deliberately NOT excluded here: its own row
    /// is the ratio's denominator).
    public struct LexicalCandidate: Sendable, Equatable {
        /// The matched document's volume.
        public let volumeId: String
        /// The matched document's id within its volume.
        public let documentId: String
        /// SQLite's raw `bm25()` score for the row (negative; lower is stronger).
        public let bm25: Double
    }

    /// A **column-restricted** BM25 OR-query over `body_text` — the store entry point
    /// for the W-17 lexical-similarity axis.
    ///
    /// ## Why a new entry point rather than a parameter
    /// The shipped search path's MATCH expressions are never column-scoped
    /// (`renderExpression` has no column syntax), and an open MATCH over this table also
    /// searches `header`, `dateline` and `source_note` — so an unrestricted "more like
    /// this" query partly re-derives the archival axis from the source notes it indexes.
    /// The restriction is for **correctness, not speed** (measured 0.0506 s restricted
    /// vs 0.0490 s unrestricted).
    ///
    /// ## The df ceiling is a correctness requirement, not a knob
    /// A pathological anchor whose extracted terms are corpus-common costs 2.899 s
    /// without one (measured). Each surface term is stemmed through this store's own
    /// tokenizer and priced against `fts5vocab`; terms whose document frequency exceeds
    /// `dfCeiling` — and terms the index has never seen — are dropped before the query
    /// runs. The admitted survivors are returned so the caller's chip can state exactly
    /// what was asked (display forms, never stems). Two surface forms collapsing to one
    /// stem are queried once.
    ///
    /// One deliberate asymmetry: the pricing is **table-wide** (`fts5vocab` counts a
    /// term's occurrences in every indexed column) while the query is body-restricted,
    /// so a term common in headers or source notes is priced slightly high and may be
    /// refused a touch early. The ceiling is a cost guard, not a statistic — erring
    /// toward refusal is the safe direction, and a per-column vocabulary would cost a
    /// second companion table to fix a bias that only tightens the guard.
    ///
    /// - Parameters:
    ///   - terms: Candidate query terms as **surface forms** (the anchor's own words —
    ///     the tokenizer re-stems them at query time, so they hit the same index terms
    ///     their occurrences did).
    ///   - dfCeiling: Maximum corpus document frequency an admitted term may have.
    ///   - limit: Maximum candidate rows to return, best (most negative) first.
    /// - Returns: The scored candidates and the admitted surface terms, in the order
    ///   given. Empty when no term survives admission.
    public func lexicalCandidates(
        terms: [String],
        dfCeiling: Int,
        limit: Int
    ) throws -> (candidates: [LexicalCandidate], admittedTerms: [String]) {
        // The query names these three columns; a schema without them (a test fixture
        // trimmed to `body_text` alone) would fail at prepare with an opaque SQLite
        // message, so refuse it legibly here.
        guard schema.columns.contains(.bodyText),
              schema.columns.contains(.volumeId),
              schema.columns.contains(.documentId) else {
            throw FTS5Error.sqliteError(
                code: 0,
                message: "lexicalCandidates requires a schema with body_text, volume_id and document_id columns")
        }
        var admitted: [String] = []
        var seenStems: Set<String> = []
        for term in terms {
            guard let stem = try indexStem(of: term), !seenStems.contains(stem),
                  let entry = try vocabularyEntry(stem: stem),
                  entry.documentFrequency <= dfCeiling
            else { continue }
            seenStems.insert(stem)
            admitted.append(term)
        }
        guard !admitted.isEmpty else { return ([], []) }

        // FTS5 column filter: `body_text : (…)` scopes every term in the group. Each
        // term ships as a quoted string (embedded quotes doubled per FTS5 syntax), so
        // punctuation in a surface form cannot become query syntax.
        let quoted = admitted.map { "\"" + $0.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        let matchExpr = "body_text : (" + quoted.joined(separator: " OR ") + ")"

        let sql = """
            SELECT volume_id, document_id, bm25(\(schema.tableName)) AS score
            FROM \(schema.tableName)
            WHERE \(schema.tableName) MATCH ?
            ORDER BY score
            LIMIT ?
            """
        let stmt = try connection.prepare(sql)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, matchExpr, -1, FTS5Store.transientDestructor)
        sqlite3_bind_int64(stmt, 2, Int64(limit))

        var out: [LexicalCandidate] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let vid = stringColumn(stmt, 0), let did = stringColumn(stmt, 1) else { continue }
            out.append(LexicalCandidate(
                volumeId: vid, documentId: did,
                bm25: sqlite3_column_double(stmt, 2)))
        }
        return (out, admitted)
    }

    /// Reads a text column as a Swift string, or `nil` for NULL.
    private func stringColumn(_ stmt: OpaquePointer?, _ index: Int32) -> String? {
        guard let c = sqlite3_column_text(stmt, index) else { return nil }
        return String(cString: c)
    }

    /// The number of distinct terms in the corpus vocabulary.
    ///
    /// A useful denominator, and the cheapest possible check that the vocab table is
    /// wired up at all.
    public func vocabularySize() throws -> Int {
        let stmt = try connection.prepare("SELECT count(*) FROM \(schema.vocabTableName)")
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    /// The `SQLITE_TRANSIENT` destructor, which tells SQLite to copy a bound string
    /// rather than retain the caller's pointer.
    static let transientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
}

// MARK: - FTS5Store + Per-document occurrences

extension FTS5Store {

    /// Occurrence counts for one index term, per document, corpus-wide and unfiltered.
    ///
    /// The only route to a **dated or scoped** occurrence count. The persistent `…_vocab` table is
    /// `row` mode — one row per term for the whole index, no document, no position — so it can say
    /// "this stem occurs 92 times" and can never say "…in 1949". This reads `instance` mode, which is
    /// one row per posting, and folds it to one row per document in SQLite.
    ///
    /// ## Deliberately returns rowids, and deliberately does not join
    /// Callers want `(volumeId, documentId)`, which lives in `document_cache`. Joining to get it here
    /// would be the obvious shape and is the wrong one. Measured on the real 6.3 GB index:
    ///
    /// | stem | postings | documents | this method | with the join |
    /// |---|---|---|---|---|
    /// | `contain` | 57,596 | 39,496 | 0.017 s | 2.00 s |
    /// | `govern` | 985,733 | 195,519 | 0.140 s | 8.99 s |
    /// | `state` | 1,688,186 | 299,557 | 0.233 s | 12.91 s |
    ///
    /// The cost tracks **document count, not postings** — `nuclear` (59,689 postings, 10,496 docs)
    /// joins in 0.39 s where `contain` (57,596 postings, 39,496 docs) takes 2.18 s. `document_cache`
    /// rows average 5.7 KB of `body_text`, so each rowid lookup is a page fault, and there is one per
    /// matched document however the query is arranged (pre-aggregating first only moved `state` from
    /// 14.29 s to 12.91 s). The caller resolves rowids against a cached map instead — see
    /// `IndexingPipeline.allDocumentRowidKeys()`, which the covering index answers in 0.114 s for the
    /// whole corpus.
    ///
    /// ## Cost
    /// ~7–8M postings/s: 0.001 s for a rare term, 0.233 s for `state`, 2.03 s for `the` (16.7M
    /// postings) — the ceiling a researcher can reach by accident. `WHERE term = ?` seeks rather than
    /// scanning, so cost is proportional to the term's posting list and not to the corpus's 234M.
    ///
    /// - Parameter stem: an index term, as produced by ``indexStem(of:)``. A surface form the
    ///   tokenizer would have changed simply misses.
    /// - Returns: `(documentRowid, occurrences)` per document containing the term, ascending by
    ///   rowid. Empty when the index has never seen the term.
    public func termOccurrencesByDocument(stem: String) throws -> [(documentRowid: Int64, occurrences: Int)] {
        guard !stem.isEmpty else { return [] }
        try connection.ensureInstanceVocab(tableName: schema.tableName)
        let sql = """
            SELECT doc, COUNT(*) FROM temp.\(FTS5Connection.instanceVocabTableName)
            WHERE term = ? GROUP BY doc ORDER BY doc
            """
        let stmt = try connection.prepare(sql)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, stem, -1, FTS5Store.transientDestructor)
        var result: [(documentRowid: Int64, occurrences: Int)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            result.append((documentRowid: sqlite3_column_int64(stmt, 0),
                           occurrences: Int(sqlite3_column_int64(stmt, 1))))
        }
        return result
    }
}
