// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SQLite3

// MARK: - CorpusTermProfile

/// What the index actually knows about one word the researcher typed.
///
/// ## The trap this exists to close
/// Both source reports name stemming as their most dangerous failure mode, and the
/// reason is that it is invisible. A search for *containment* silently becomes a search
/// for `contain`, which also matches *contains*, *containing*, *contained* and
/// *container* — so a five-figure hit count looks like evidence of a preoccupation when
/// it is mostly ordinary English. Nothing in the app has ever said so.
///
/// ## Why both counts are here
/// `documentFrequency` and `occurrences` are different numbers and the gap between them
/// is itself a finding: 200 occurrences across 150 documents is a pattern; 200 across 3
/// is one memo with a tic. The app's analytics count documents — correctly — but have
/// never had anything to contrast that against.
///
/// ## Scope
/// Both counts are **corpus-wide over the whole local index**, across every indexed
/// column, and are *not* narrowed by the user's current filters. Any surface that shows
/// them must say so; "12,431 documents" without its denominator is exactly the kind of
/// unbaselined number this workstream exists to stop producing.
///
/// Version history:
///   1.0 — Q-3a: initial implementation
public struct CorpusTermProfile: Sendable, Equatable {

    /// The word as the researcher typed it, lowercased.
    public let surfaceForm: String

    /// The term SQLite's own tokenizer produced — the string actually stored in the
    /// inverted index, and therefore the thing the query really searched for.
    public let stem: String

    /// How many indexed documents contain this stem at least once, corpus-wide.
    public let documentFrequency: Int

    /// How many times this stem occurs in total, corpus-wide. Always `>= documentFrequency`.
    public let occurrences: Int

    /// Creates a profile.
    public init(surfaceForm: String, stem: String, documentFrequency: Int, occurrences: Int) {
        self.surfaceForm = surfaceForm
        self.stem = stem
        self.documentFrequency = documentFrequency
        self.occurrences = occurrences
    }

    /// Whether the tokenizer changed the word — i.e. whether the search that ran was
    /// broader than the word the researcher typed.
    ///
    /// This is the condition worth warning about. `europe → europ` is technically a
    /// change but matches nothing extra in practice; `containment → contain` is the one
    /// that misleads. Distinguishing those needs the surface-form map deferred to D-1,
    /// so callers should treat this as "worth mentioning", not "definitely a problem".
    public var isStemmed: Bool { stem != surfaceForm }

    /// Average occurrences per matching document — the "one memo with a tic" detector.
    ///
    /// Returns `nil` rather than dividing by zero for a term the index has never seen.
    public var occurrencesPerDocument: Double? {
        guard documentFrequency > 0 else { return nil }
        return Double(occurrences) / Double(documentFrequency)
    }
}

// MARK: - FTS5Store + Vocabulary

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

    /// The full profile for one word the researcher typed: what it became, and what that
    /// costs in breadth.
    ///
    /// Returns `nil` when the word is not a single token. Returns a profile with **zero**
    /// counts — not `nil` — when the word tokenizes cleanly but the index has never seen
    /// it, because "your term appears in 0 documents" is a genuine, useful answer and is
    /// not the same as "this question does not apply".
    public func termProfile(for surfaceForm: String) throws -> CorpusTermProfile? {
        let normalized = surfaceForm
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard let stem = try indexStem(of: normalized) else { return nil }
        let entry = try vocabularyEntry(stem: stem)
        return CorpusTermProfile(
            surfaceForm: normalized,
            stem: stem,
            documentFrequency: entry?.documentFrequency ?? 0,
            occurrences: entry?.occurrences ?? 0
        )
    }

    /// Profiles several words in one call, dropping those that are not single tokens.
    public func termProfiles(for surfaceForms: [String]) throws -> [CorpusTermProfile] {
        try surfaceForms.compactMap { try termProfile(for: $0) }
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
