// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SQLite3

// MARK: - PersonIndexEntry

/// A person record bundled with a cross-volume mention count, used by `PersonIndexView`.
///
/// `rollupId` is set when the entry comes from the materialised cross-corpus rollup
/// (`person_rollup`); `mentionCount` is then the correct, `(volume_id, ref)`-scoped count and
/// `entry.ref` is empty. When the entry is built from a single volume's front matter,
/// `rollupId` is `nil`, `sourceVolumeId`/`entry.ref` identify the per-volume person, and the
/// detail sheet resolves the rollup to show the cross-corpus count.
public struct PersonIndexEntry: Sendable, Identifiable {
    public let entry: PersonEntry
    /// Count of distinct documents (across all indexed volumes) that mention this person.
    public let mentionCount: Int
    /// Rollup id when this entry came from the cross-corpus rollup; `nil` for a per-volume entry.
    public let rollupId: Int?
    /// Volume this entry was built from (per-volume front-matter case), used to resolve the rollup.
    public let sourceVolumeId: String?
    /// Number of distinct volumes this cluster spans (Phase 4), for the "N volumes" subtitle. 0 for
    /// a per-volume front-matter entry.
    public let volumeCount: Int

    public var id: String { rollupId.map { "r\($0)" } ?? entry.id }

    public init(entry: PersonEntry, mentionCount: Int, rollupId: Int? = nil,
                sourceVolumeId: String? = nil, volumeCount: Int = 0) {
        self.entry = entry
        self.mentionCount = mentionCount
        self.rollupId = rollupId
        self.sourceVolumeId = sourceVolumeId
        self.volumeCount = volumeCount
    }
}

// MARK: - PersonRollupMember

/// A single per-volume record (`(volumeId, ref)` + its `persons` row) belonging to a person rollup,
/// used by the Phase 4 detail-sheet member drill-in and its "Separate" action.
public struct PersonRollupMember: Sendable, Identifiable {
    /// The volume this record comes from.
    public let volumeId: String
    /// The per-volume person entry (carries `ref`, name, role, era).
    public let entry: PersonEntry

    public var id: String { "\(volumeId)|\(entry.ref)" }

    public init(volumeId: String, entry: PersonEntry) {
        self.volumeId = volumeId
        self.entry = entry
    }
}

// MARK: - PersonMentionStore

/// Queries the `person_mentions` table to support person-filtered search
/// and cross-volume person navigation.
///
/// Opens a read-only SQLite connection to the shared database file.
/// All query methods are synchronous (non-async) because they run on the
/// actor's executor and use a dedicated read-only connection — they never
/// block a writer.
///
/// Version history:
///   1.0 — Session 39: initial implementation
///   1.1 — Session 41: persons/terms table queries; name autocomplete support
///   1.2 — Session 87: allPersonsSortedByName() with cross-volume mention counts
public actor PersonMentionStore {

    // nonisolated(unsafe): deinit is nonisolated and must close the handle.
    // Safe because the actor serialises all access and the handle is never
    // read from outside the actor while it is live.
    nonisolated(unsafe) private var db: OpaquePointer?
    private let databaseURL: URL

    // MARK: - Initialisation

    /// Opens a read-only SQLite connection to the shared database file.
    ///
    /// - Parameter databaseURL: The shared database used by `IndexingPipeline`.
    /// - Throws: `PersonMentionError.databaseOpenFailed` if the file cannot be opened.
    public init(databaseURL: URL) throws {
        self.databaseURL = databaseURL
        var handle: OpaquePointer?
        let rc = sqlite3_open_v2(
            databaseURL.path, &handle,
            SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX,
            nil
        )
        guard rc == SQLITE_OK, let h = handle else {
            let msg = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            sqlite3_close(handle)
            throw PersonMentionError.databaseOpenFailed(message: msg)
        }
        db = h

        // Wait up to 5 s instead of failing instantly with SQLITE_BUSY when a WAL
        // checkpoint or recovery briefly locks the file.
        sqlite3_busy_timeout(h, 5000)

        #if DEBUG
        print("[PersonMentionStore] Opened read-only connection to \(databaseURL.lastPathComponent)")
        #endif
    }

    deinit {
        if let db { sqlite3_close_v2(db) }
    }

    // MARK: - Public API

    /// Returns the (volumeId, documentId) pairs in one volume that mention the given per-volume ref.
    ///
    /// The TEI `ref` (xml:id) is only meaningful within its own volume — the same string is reused
    /// for unrelated people across volumes — so this is always scoped by `(volume_id, ref)`. Use
    /// `documentKeys(forRollupId:)` for cross-corpus identity. Results are ordered by document_id.
    public func documents(volumeId: String, ref: String) throws -> [(volumeId: String, documentId: String)] {
        let sql = """
            SELECT volume_id, document_id FROM person_mentions
            WHERE volume_id = ? AND person_ref = ?
            ORDER BY document_id
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        bind(stmt, 1, volumeId)
        bind(stmt, 2, ref)
        var results: [(volumeId: String, documentId: String)] = []
        while step(stmt) {
            let vid = columnString(stmt, 0) ?? ""
            let did = columnString(stmt, 1) ?? ""
            results.append((volumeId: vid, documentId: did))
        }
        return results
    }

    /// Returns all unique person refs mentioned in the given document.
    ///
    /// Results are returned in alphabetical order.
    public func personRefs(forDocumentId documentId: String, volumeId: String) throws -> [String] {
        let sql = """
            SELECT person_ref FROM person_mentions
            WHERE volume_id = ? AND document_id = ?
            ORDER BY person_ref
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        bind(stmt, 1, volumeId)
        bind(stmt, 2, documentId)
        var refs: [String] = []
        while step(stmt) {
            if let ref = columnString(stmt, 0) { refs.append(ref) }
        }
        return refs
    }

    /// Returns the count of documents in one volume that mention the given per-volume ref.
    ///
    /// Scoped by `(volume_id, ref)` — the TEI `ref` collides across volumes, so an unscoped count
    /// conflates unrelated people. For a cross-corpus count, resolve the rollup with
    /// `rollupEntry(forVolumeId:ref:)` (its `mentionCount` is the materialised cross-corpus count).
    public func documentCount(volumeId: String, ref: String) throws -> Int {
        let sql = "SELECT COUNT(*) FROM person_mentions WHERE volume_id = ? AND person_ref = ?"
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        bind(stmt, 1, volumeId)
        bind(stmt, 2, ref)
        guard step(stmt) else { return 0 }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    // MARK: - Person Rollup Queries (Phase 0)

    /// Resolves the materialised cross-corpus rollup for a single per-volume person, or `nil` if the
    /// rollup hasn't been built or has no row for `(volumeId, ref)`. The returned entry's
    /// `mentionCount` is the correct cross-corpus count and `rollupId` drives drill-in/search.
    public func rollupEntry(forVolumeId volumeId: String, ref: String) throws -> PersonIndexEntry? {
        let sql = """
            SELECT r.rollup_id, r.canonical_name, r.description, r.mention_count,
                   r.role, r.start_year, r.end_year, r.volume_count
            FROM person_rollup_member m
            JOIN person_rollup r ON r.rollup_id = m.rollup_id
            WHERE m.volume_id = ? AND m.ref = ?
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        bind(stmt, 1, volumeId)
        bind(stmt, 2, ref)
        guard step(stmt) else { return nil }
        let rid  = Int(sqlite3_column_int64(stmt, 0))
        let name = columnString(stmt, 1) ?? ""
        let desc = columnString(stmt, 2)
        let cnt  = Int(sqlite3_column_int64(stmt, 3))
        let entry = PersonEntry(ref: "", name: name, description: desc,
                                role: columnString(stmt, 4),
                                startYear: columnIntOptional(stmt, 5),
                                endYear: columnIntOptional(stmt, 6))
        return PersonIndexEntry(entry: entry, mentionCount: cnt, rollupId: rid,
                                volumeCount: Int(sqlite3_column_int64(stmt, 7)))
    }

    /// The (volumeId, documentId) pairs across the whole corpus that mention any member of a rollup.
    public func documentKeys(forRollupId rollupId: Int) throws -> [(volumeId: String, documentId: String)] {
        let sql = """
            SELECT DISTINCT pm.volume_id, pm.document_id
            FROM person_rollup_member m
            JOIN person_mentions pm ON pm.volume_id = m.volume_id AND pm.person_ref = m.ref
            WHERE m.rollup_id = ?
            ORDER BY pm.volume_id, pm.document_id
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, Int64(rollupId))
        var results: [(volumeId: String, documentId: String)] = []
        while step(stmt) {
            results.append((volumeId: columnString(stmt, 0) ?? "", documentId: columnString(stmt, 1) ?? ""))
        }
        return results
    }

    /// Sub-threshold "possibly the same person" suggestions for a rollup (Phase 2).
    ///
    /// Returns the *other* rollup's id, canonical name, and the reason the clusterer declined to
    /// auto-merge the pair, looking at both orientations of the unordered `person_cluster_candidate`
    /// pair. Drives the "possibly same — Merge?" affordance (Phase 3/4). Ordered by the other name.
    public func candidates(forRollupId rollupId: Int) throws -> [(rollupId: Int, name: String, reason: String?)] {
        let sql = """
            SELECT c.rollup_id_b, r.canonical_name, c.reason
            FROM person_cluster_candidate c JOIN person_rollup r ON r.rollup_id = c.rollup_id_b
            WHERE c.rollup_id_a = ?
            UNION ALL
            SELECT c.rollup_id_a, r.canonical_name, c.reason
            FROM person_cluster_candidate c JOIN person_rollup r ON r.rollup_id = c.rollup_id_a
            WHERE c.rollup_id_b = ?
            ORDER BY 2
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, Int64(rollupId))
        sqlite3_bind_int64(stmt, 2, Int64(rollupId))
        var results: [(rollupId: Int, name: String, reason: String?)] = []
        while step(stmt) {
            results.append((Int(sqlite3_column_int64(stmt, 0)),
                            columnString(stmt, 1) ?? "",
                            columnString(stmt, 2)))
        }
        return results
    }

    /// The per-volume member records of a rollup (Phase 4 drill-in), joined to their `persons` rows
    /// for the per-volume name/role/era. Ordered by name then volume.
    public func members(forRollupId rollupId: Int) throws -> [PersonRollupMember] {
        let sql = """
            SELECT m.volume_id, p.ref, p.name, p.description, p.role, p.start_year, p.end_year
            FROM person_rollup_member m
            JOIN persons p ON p.volume_id = m.volume_id AND p.ref = m.ref
            WHERE m.rollup_id = ?
            ORDER BY p.name, m.volume_id
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, Int64(rollupId))
        var results: [PersonRollupMember] = []
        while step(stmt) {
            let entry = PersonEntry(ref: columnString(stmt, 1) ?? "",
                                    name: columnString(stmt, 2) ?? "",
                                    description: columnString(stmt, 3),
                                    role: columnString(stmt, 4),
                                    startYear: columnIntOptional(stmt, 5),
                                    endYear: columnIntOptional(stmt, 6))
            results.append(PersonRollupMember(volumeId: columnString(stmt, 0) ?? "", entry: entry))
        }
        return results
    }

    /// The set of rollup ids that have at least one pending "possibly the same" candidate (Phase 4
    /// row hint). Loaded once for the whole People list rather than per row.
    public func rollupIdsWithCandidates() throws -> Set<Int> {
        let sql = """
            SELECT rollup_id_a FROM person_cluster_candidate
            UNION SELECT rollup_id_b FROM person_cluster_candidate
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        var ids = Set<Int>()
        while step(stmt) { ids.insert(Int(sqlite3_column_int64(stmt, 0))) }
        return ids
    }

    /// A representative `(volumeId, ref)` member of a rollup, used to anchor a user correction
    /// (`PersonClusterOverride`) to stable TEI keys. Returns the member with the smallest
    /// `(volume_id, ref)` for determinism, or `nil` when the rollup has no members.
    public func representativeMember(forRollupId rollupId: Int) throws -> (volumeId: String, ref: String)? {
        let sql = """
            SELECT volume_id, ref FROM person_rollup_member
            WHERE rollup_id = ? ORDER BY volume_id, ref LIMIT 1
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, Int64(rollupId))
        guard step(stmt) else { return nil }
        return (columnString(stmt, 0) ?? "", columnString(stmt, 1) ?? "")
    }

    // MARK: - Persons Table Queries (Session 41)

    /// Looks up a single person entry by volume and ref.
    ///
    /// Returns `nil` if the persons table has no row for this volume/ref pair
    /// (e.g. the volume has not been indexed yet).
    public func person(forRef ref: String, volumeId: String) throws -> PersonEntry? {
        let sql = """
            SELECT ref, name, description, role, start_year, end_year FROM persons
            WHERE volume_id = ? AND ref = ?
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        bind(stmt, 1, volumeId)
        bind(stmt, 2, ref)
        guard step(stmt) else { return nil }
        let r    = columnString(stmt, 0) ?? ref
        let name = columnString(stmt, 1) ?? ""
        let desc = columnString(stmt, 2)
        return PersonEntry(ref: r, name: name, description: desc,
                           role: columnString(stmt, 3),
                           startYear: columnIntOptional(stmt, 4),
                           endYear: columnIntOptional(stmt, 5))
    }

    /// All person entries for a volume, sorted by name.
    ///
    /// Returns an empty array if the volume has not been indexed or has no persons list.
    public func allPersons(forVolumeId volumeId: String) throws -> [PersonEntry] {
        let sql = """
            SELECT ref, name, description, role, start_year, end_year FROM persons
            WHERE volume_id = ?
            ORDER BY name
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        bind(stmt, 1, volumeId)
        var results: [PersonEntry] = []
        while step(stmt) {
            let ref  = columnString(stmt, 0) ?? ""
            let name = columnString(stmt, 1) ?? ""
            let desc = columnString(stmt, 2)
            results.append(PersonEntry(ref: ref, name: name, description: desc,
                                       role: columnString(stmt, 3),
                                       startYear: columnIntOptional(stmt, 4),
                                       endYear: columnIntOptional(stmt, 5)))
        }
        return results
    }

    /// All cross-corpus persons sorted by name, from the materialised `person_rollup` table.
    ///
    /// Reads the precomputed rollup (built by `IndexingPipeline.consolidatePersonRollup`) rather than
    /// grouping live — a cross-corpus rollup over `person_mentions` is too slow for an interactive
    /// load. Phase 0 keys rollups by normalised name with `(volume_id, ref)`-scoped counts (so the
    /// per-volume TEI `ref` can no longer conflate unrelated people); Phase 2 upgrades the builder to
    /// true clustering without changing this read path. Returns an empty array when the rollup hasn't
    /// been built (no indexed volumes, or consolidation hasn't run yet).
    public func allPersonsSortedByName() throws -> [PersonIndexEntry] {
        let sql = """
            SELECT rollup_id, canonical_name, description, mention_count, role, start_year, end_year,
                   volume_count
            FROM person_rollup
            ORDER BY canonical_name ASC
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        var results: [PersonIndexEntry] = []
        while step(stmt) {
            let rid   = Int(sqlite3_column_int64(stmt, 0))
            let name  = columnString(stmt, 1) ?? ""
            let desc  = columnString(stmt, 2)
            let count = Int(sqlite3_column_int64(stmt, 3))
            let entry = PersonEntry(ref: "", name: name, description: desc,
                                    role: columnString(stmt, 4),
                                    startYear: columnIntOptional(stmt, 5),
                                    endYear: columnIntOptional(stmt, 6))
            results.append(PersonIndexEntry(entry: entry, mentionCount: count, rollupId: rid,
                                            volumeCount: Int(sqlite3_column_int64(stmt, 7))))
        }
        return results
    }

    /// Persons across all indexed volumes whose name contains `query` (case-insensitive LIKE).
    ///
    /// Returns at most `limit` results (default 20), ordered by name.
    /// Used by the Search view autocomplete picker.
    public func personsMatchingName(_ query: String, limit: Int = 20) throws -> [PersonEntry] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        let sql = """
            SELECT ref, name, description, volume_id FROM persons
            WHERE name LIKE ?
            ORDER BY name
            LIMIT ?
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        bind(stmt, 1, "%\(query)%")
        sqlite3_bind_int64(stmt, 2, Int64(limit))
        var results: [PersonEntry] = []
        while step(stmt) {
            let ref  = columnString(stmt, 0) ?? ""
            let name = columnString(stmt, 1) ?? ""
            let desc = columnString(stmt, 2)
            results.append(PersonEntry(ref: ref, name: name, description: desc))
        }
        return results
    }

    // MARK: - Terms Table Queries (Session 41)

    /// All glossary term entries for a volume, sorted by term.
    ///
    /// Returns an empty array if the volume has not been indexed or has no terms list.
    public func allTerms(forVolumeId volumeId: String) throws -> [GlossEntry] {
        let sql = """
            SELECT ref, term, definition FROM terms
            WHERE volume_id = ?
            ORDER BY term
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        bind(stmt, 1, volumeId)
        var results: [GlossEntry] = []
        while step(stmt) {
            let ref  = columnString(stmt, 0) ?? ""
            let term = columnString(stmt, 1) ?? ""
            let def  = columnString(stmt, 2)
            results.append(GlossEntry(ref: ref, term: term, definition: def))
        }
        return results
    }

    /// Looks up a single glossary term by volume and ref.
    ///
    /// Returns `nil` if not found.
    public func term(forRef ref: String, volumeId: String) throws -> GlossEntry? {
        let sql = """
            SELECT ref, term, definition FROM terms
            WHERE volume_id = ? AND ref = ?
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        bind(stmt, 1, volumeId)
        bind(stmt, 2, ref)
        guard step(stmt) else { return nil }
        let r    = columnString(stmt, 0) ?? ref
        let term = columnString(stmt, 1) ?? ""
        let def  = columnString(stmt, 2)
        return GlossEntry(ref: r, term: term, definition: def)
    }

    // MARK: - SQLite Helpers

    private let TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private func prepare(_ sql: String) throws -> OpaquePointer {
        var stmt: OpaquePointer?
        let rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        guard rc == SQLITE_OK, let s = stmt else {
            let msg = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            throw PersonMentionError.sqliteError(code: rc, message: msg)
        }
        return s
    }

    @discardableResult
    private func step(_ stmt: OpaquePointer) -> Bool {
        sqlite3_step(stmt) == SQLITE_ROW
    }

    private func bind(_ stmt: OpaquePointer, _ col: Int32, _ value: String) {
        sqlite3_bind_text(stmt, col, value, -1, TRANSIENT)
    }

    private func columnString(_ stmt: OpaquePointer, _ col: Int32) -> String? {
        guard let ptr = sqlite3_column_text(stmt, col) else { return nil }
        return String(cString: ptr)
    }

    private func columnIntOptional(_ stmt: OpaquePointer, _ col: Int32) -> Int? {
        guard sqlite3_column_type(stmt, col) != SQLITE_NULL else { return nil }
        return Int(sqlite3_column_int64(stmt, col))
    }
}

// MARK: - PersonMentionError

/// Errors thrown by `PersonMentionStore`.
public enum PersonMentionError: Error, Sendable {
    case databaseOpenFailed(message: String)
    case sqliteError(code: Int32, message: String)
}
