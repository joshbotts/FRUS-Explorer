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
    /// Canonical id from the OOH authority crosswalk (Phase 5) when this identity is authoritative;
    /// `nil` for a heuristically-clustered identity.
    public let authorityId: Int?
    /// VIAF id (Phase 5) when reconciled, for a "View on VIAF" link.
    public let viafId: String?

    public var id: String { rollupId.map { "r\($0)" } ?? entry.id }

    public init(entry: PersonEntry, mentionCount: Int, rollupId: Int? = nil,
                sourceVolumeId: String? = nil, volumeCount: Int = 0,
                authorityId: Int? = nil, viafId: String? = nil) {
        self.entry = entry
        self.mentionCount = mentionCount
        self.rollupId = rollupId
        self.sourceVolumeId = sourceVolumeId
        self.volumeCount = volumeCount
        self.authorityId = authorityId
        self.viafId = viafId
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

// MARK: - PersonRollupMention

/// One (rollup identity × mentioning document) pair, returned by
/// `PersonMentionStore.rollupMentions(forDocuments:)` for the collections Persons Index
/// block (Authoring Phase 6). Carries the rollup's display fields so callers never need
/// a second lookup per identity.
public struct PersonRollupMention: Sendable {
    /// The rollup id — pairs with the same id are the same person.
    public let rollupId: Int
    /// The rollup's canonical display name.
    public let canonicalName: String
    /// The rollup's description (front-matter role text), when available.
    public let description: String?
    /// The rollup's role classification, when available.
    public let role: String?
    /// The mentioning document's volume.
    public let volumeId: String
    /// The mentioning document's id.
    public let documentId: String

    /// Creates a rollup-mention pair.
    public init(rollupId: Int, canonicalName: String, description: String?, role: String?,
                volumeId: String, documentId: String) {
        self.rollupId = rollupId
        self.canonicalName = canonicalName
        self.description = description
        self.role = role
        self.volumeId = volumeId
        self.documentId = documentId
    }
}

// MARK: - PersonMentionRanking

/// One most-mentioned-person row for the Person Analytics "by era" ranking (CA-5).
///
/// `mentionCount` is the number of `(person-ref × document)` mentions of any member
/// of this rollup that fall inside the selected coverage year range **and** in a dated
/// document (a `document_dates` row) — mentions in undated documents cannot be placed
/// on the year axis and are excluded (and disclosed) rather than silently dropped.
///
/// Version history:
///   1.0 — CA-5 (analytics CA-track): initial implementation
public struct PersonMentionRanking: Sendable, Identifiable {
    /// The rollup identity (pairs with the People browser's `rollup_id`).
    public let rollupId: Int
    /// The rollup's canonical display name.
    public let canonicalName: String
    /// Mentions in dated documents within the selected year range.
    public let mentionCount: Int

    public var id: Int { rollupId }

    /// Creates a most-mentioned-person ranking row.
    public init(rollupId: Int, canonicalName: String, mentionCount: Int) {
        self.rollupId = rollupId
        self.canonicalName = canonicalName
        self.mentionCount = mentionCount
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
///   1.3 — Authoring Phase 6 (blocks): rollupMentions(forDocuments:) — mentions in a
///          document set resolved through the materialised rollup, for the collections
///          Persons Index block (reuses the People-browser identity path; clustering is
///          never reimplemented by callers)
///   1.4 — Authoring Phase 6 review fix: rollupMentions uses an index-usable row-value
///          IN predicate instead of the concatenated-key form, which forced a full
///          person_mentions scan per Persons-block resolve (on every debounced preview
///          refresh)
///   1.5 — CA-5 (analytics CA-track): person analytics read path —
///          `mentionTrajectories(rollupIds:)` (rollup → year → mention count over the
///          dated core join), `topPeopleByMentions(inYearRange:limit:)` (most-mentioned
///          rollups in a coverage window), `rollupsMatchingName(_:limit:)` (the picker
///          search), and `datedDocumentTotalsByYear()` (the dated-only `% of documents`
///          denominator). All read-only over the existing tables — no schema change.
///   1.6 — CA-8 (analytics CA-track): person co-mention read path —
///          `topCoMentionedPeople(forRollupId:limit:)` (the ego partners, bounded to the
///          focus person's document set + a disclosed top-N cap),
///          `coMentionEdges(amongRollupIds:)` (partner-partner edges within the bounded
///          ego, self-join constrained to the given ids, unordered pairs a<b), and
///          `coMentionTimeline(rollupA:rollupB:)` (two-person shared-document counts per
///          dated year, for relationship dynamics). All read-only, distinct-document
///          counted — no schema change.
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
                   r.role, r.start_year, r.end_year, r.volume_count, r.authority_id, r.viaf_id
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
                                volumeCount: Int(sqlite3_column_int64(stmt, 7)),
                                authorityId: columnIntOptional(stmt, 8),
                                viafId: columnString(stmt, 9))
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

    /// Person mentions within a document set, resolved through the materialised
    /// People-browser rollup (Authoring Phase 6 — the collections Persons Index block).
    ///
    /// Joins `person_mentions` in the given documents to `person_rollup_member` /
    /// `person_rollup`, so identities are exactly the People browser's — the clusterer's
    /// output is reused, never reimplemented. Returns one element per distinct
    /// (rollup × mentioning document) pair. Empty when the rollup hasn't been built
    /// (consolidation not yet run), matching the People browser's behavior.
    ///
    /// Queries are issued in chunks of 499 documents (998 bound variables — two per
    /// pair) to stay within SQLite's 999-variable cap. The predicate uses row-value
    /// syntax — `(pm.volume_id, pm.document_id) IN (VALUES (?, ?), …)` — which SQLite
    /// can satisfy from `idx_person_mentions_doc`; the concatenated-key form
    /// (`volume_id || '/' || document_id IN (…)`) defeats every index and full-scans
    /// `person_mentions`, the app's largest per-mention table, on every resolve.
    ///
    /// - Parameter docs: `(volumeId, documentId)` pairs restricting the mention scope.
    /// - Returns: Distinct rollup × document pairs, unordered (callers group and sort).
    public func rollupMentions(
        forDocuments docs: [(volumeId: String, documentId: String)]
    ) throws -> [PersonRollupMention] {
        guard !docs.isEmpty else { return [] }
        let chunkSize = 499
        var results: [PersonRollupMention] = []
        for start in stride(from: 0, to: docs.count, by: chunkSize) {
            let chunk = Array(docs[start..<min(start + chunkSize, docs.count)])
            let placeholders = chunk.map { _ in "(?, ?)" }.joined(separator: ", ")
            let sql = """
                SELECT DISTINCT r.rollup_id, r.canonical_name, r.description, r.role,
                                pm.volume_id, pm.document_id
                FROM person_mentions pm
                JOIN person_rollup_member m
                  ON m.volume_id = pm.volume_id AND m.ref = pm.person_ref
                JOIN person_rollup r ON r.rollup_id = m.rollup_id
                WHERE (pm.volume_id, pm.document_id) IN (VALUES \(placeholders))
                """
            let stmt = try prepare(sql)
            defer { sqlite3_finalize(stmt) }
            for (i, doc) in chunk.enumerated() {
                bind(stmt, Int32(i * 2 + 1), doc.volumeId)
                bind(stmt, Int32(i * 2 + 2), doc.documentId)
            }
            while step(stmt) {
                results.append(PersonRollupMention(
                    rollupId: Int(sqlite3_column_int64(stmt, 0)),
                    canonicalName: columnString(stmt, 1) ?? "",
                    description: columnString(stmt, 2),
                    role: columnString(stmt, 3),
                    volumeId: columnString(stmt, 4) ?? "",
                    documentId: columnString(stmt, 5) ?? ""))
            }
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

    // MARK: - Person Analytics Queries (CA-5)

    /// Mention counts per rollup per year, for the multi-person trajectory chart (CA-5).
    ///
    /// For each requested rollup, returns a `year → mention count` map. The count is the
    /// number of `person_mentions` rows (one per `(person-ref × document)`) that resolve
    /// to that rollup and land in a **dated** document — the year is the first four
    /// characters of `document_dates.date_iso`. Mentions in undated documents (no
    /// `document_dates` row) cannot be placed on the year axis and are excluded (the
    /// inner join drops them); the view discloses this as "mentions in dated documents".
    ///
    /// Core join: `person_mentions pm → person_rollup_member m (m.volume_id = pm.volume_id
    /// AND m.ref = pm.person_ref) → document_dates dd (dd.volume_id = pm.volume_id AND
    /// dd.document_id = pm.document_id)`, grouped by `rollup_id, year`.
    ///
    /// - Parameter rollupIds: The rollups to chart. Empty → empty result.
    /// - Returns: `rollupId → (year → mentionCount)`. Rollups with no dated mentions are absent.
    public func mentionTrajectories(rollupIds: [Int], volumeIds: [String]? = nil) throws -> [Int: [Int: Int]] {
        guard !rollupIds.isEmpty else { return [:] }
        // Deduplicate and bound the IN-list; parameterise every id (never interpolate).
        let ids = Array(Set(rollupIds))
        let placeholders = ids.map { _ in "?" }.joined(separator: ", ")
        let scope = Self.normalizedScope(volumeIds)
        let sql = """
            SELECT m.rollup_id,
                   CAST(substr(dd.date_iso, 1, 4) AS INTEGER) AS yr,
                   COUNT(*)
            FROM person_mentions pm
            JOIN person_rollup_member m
              ON m.volume_id = pm.volume_id AND m.ref = pm.person_ref
            JOIN document_dates dd
              ON dd.volume_id = pm.volume_id AND dd.document_id = pm.document_id
            WHERE m.rollup_id IN (\(placeholders))
              AND dd.date_iso IS NOT NULL AND length(dd.date_iso) >= 4
              \(Self.volumeScopeClause(scope))
            GROUP BY m.rollup_id, yr
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        var col: Int32 = 1
        for rid in ids { sqlite3_bind_int64(stmt, col, Int64(rid)); col += 1 }
        col = Self.bindVolumeScope(scope, to: stmt, from: col)
        var result: [Int: [Int: Int]] = [:]
        while step(stmt) {
            let rid = Int(sqlite3_column_int64(stmt, 0))
            let year = Int(sqlite3_column_int64(stmt, 1))
            let count = Int(sqlite3_column_int64(stmt, 2))
            guard year > 0 else { continue }
            result[rid, default: [:]][year] = count
        }
        return result
    }

    // MARK: - Volume-scope helpers (Person Analytics slicing, #189-B)

    /// Normalises an optional volume-scope list: `nil`/empty → `nil` (whole corpus), otherwise
    /// the deduplicated ids. A `nil` scope emits no SQL filter, so the analytics queries keep
    /// their original whole-corpus behaviour byte-for-byte.
    static func normalizedScope(_ volumeIds: [String]?) -> [String]? {
        guard let ids = volumeIds, !ids.isEmpty else { return nil }
        return Array(Set(ids))
    }

    /// An `AND <alias>.volume_id IN (?, …)` fragment for a normalised volume scope, or `""`
    /// when the scope is `nil`. Bind the same ids (in order) with `bindVolumeScope` at the
    /// placeholder run that lands where this fragment sits in the statement.
    static func volumeScopeClause(_ scope: [String]?, alias: String = "pm") -> String {
        guard let scope, !scope.isEmpty else { return "" }
        let ph = scope.map { _ in "?" }.joined(separator: ", ")
        return "AND \(alias).volume_id IN (\(ph))"
    }

    /// Binds a normalised volume scope's ids as text starting at column `from`, returning the
    /// next free column index. A `nil` scope binds nothing and returns `from` unchanged.
    static func bindVolumeScope(_ scope: [String]?, to stmt: OpaquePointer?, from: Int32) -> Int32 {
        guard let scope, !scope.isEmpty else { return from }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        var col = from
        for vid in scope {
            sqlite3_bind_text(stmt, col, vid, -1, transient)
            col += 1
        }
        return col
    }

    /// The most-mentioned rollups within a coverage year range (CA-5 "by era").
    ///
    /// Counts `person_mentions` rows resolving to each rollup whose mentioning document
    /// is **dated** (a `document_dates` row) with a `date_iso` year inside `range`, joins
    /// `person_rollup` for the canonical name, and ranks descending. Uses the same dated
    /// core join as `mentionTrajectories` — undated mentions are excluded consistently.
    /// When `volumeIds` is non-empty, only mentions in those volumes are counted (the scope
    /// picker); `nil` counts the whole corpus.
    ///
    /// - Parameters:
    ///   - range: Inclusive coverage-year window (from the year-range bar).
    ///   - limit: Maximum rows (top-N).
    /// - Returns: Ranked `PersonMentionRanking` rows, most-mentioned first.
    public func topPeopleByMentions(inYearRange range: ClosedRange<Int>,
                                    limit: Int,
                                    volumeIds: [String]? = nil) throws -> [PersonMentionRanking] {
        let scope = Self.normalizedScope(volumeIds)
        let sql = """
            SELECT m.rollup_id, r.canonical_name, COUNT(*) AS cnt
            FROM person_mentions pm
            JOIN person_rollup_member m
              ON m.volume_id = pm.volume_id AND m.ref = pm.person_ref
            JOIN document_dates dd
              ON dd.volume_id = pm.volume_id AND dd.document_id = pm.document_id
            JOIN person_rollup r ON r.rollup_id = m.rollup_id
            WHERE dd.date_iso IS NOT NULL AND length(dd.date_iso) >= 4
              AND CAST(substr(dd.date_iso, 1, 4) AS INTEGER) BETWEEN ? AND ?
              \(Self.volumeScopeClause(scope))
            GROUP BY m.rollup_id
            ORDER BY cnt DESC, r.canonical_name ASC
            LIMIT ?
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        var col: Int32 = 1
        sqlite3_bind_int64(stmt, col, Int64(range.lowerBound)); col += 1
        sqlite3_bind_int64(stmt, col, Int64(range.upperBound)); col += 1
        col = Self.bindVolumeScope(scope, to: stmt, from: col)
        sqlite3_bind_int64(stmt, col, Int64(limit))
        var results: [PersonMentionRanking] = []
        while step(stmt) {
            results.append(PersonMentionRanking(
                rollupId: Int(sqlite3_column_int64(stmt, 0)),
                canonicalName: columnString(stmt, 1) ?? "",
                mentionCount: Int(sqlite3_column_int64(stmt, 2))))
        }
        return results
    }

    /// Rollups whose canonical name contains `query` (case-insensitive), for the
    /// comparison picker's search-to-add field (CA-5). Ordered by mention count so the
    /// most-mentioned matches surface first.
    ///
    /// - Parameters:
    ///   - query: Free-text fragment; blank → empty result.
    ///   - limit: Maximum rows (default 20).
    /// - Returns: Matching rollups as `PersonMentionRanking` rows (`mentionCount` is the
    ///   materialised cross-corpus count, not year-scoped).
    public func rollupsMatchingName(_ query: String, limit: Int = 20) throws -> [PersonMentionRanking] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        let sql = """
            SELECT rollup_id, canonical_name, mention_count
            FROM person_rollup
            WHERE canonical_name LIKE ?
            ORDER BY mention_count DESC, canonical_name ASC
            LIMIT ?
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        bind(stmt, 1, "%\(query)%")
        sqlite3_bind_int64(stmt, 2, Int64(limit))
        var results: [PersonMentionRanking] = []
        while step(stmt) {
            results.append(PersonMentionRanking(
                rollupId: Int(sqlite3_column_int64(stmt, 0)),
                canonicalName: columnString(stmt, 1) ?? "",
                mentionCount: Int(sqlite3_column_int64(stmt, 2))))
        }
        return results
    }

    /// Count of **dated** documents per year — the `% of documents` denominator (CA-5).
    ///
    /// Counts `document_dates` rows (one per `(volume, document)`) whose `date_iso` has a
    /// four-digit year. CRITICAL (the CA-4 population lesson): this denominator and the
    /// normalized numerator (documents mentioning a person in year Y, drawn from the SAME
    /// dated core join) are BOTH dated-only, so a within-year share can never exceed 100%.
    /// Do **not** substitute `CorpusAnalyticsService.documentTotalsByYear`, which applies a
    /// volume-start-year fallback for undated documents — that inflated denominator would
    /// mismatch this dated-only numerator.
    ///
    /// - Returns: `year → dated-document count`.
    public func datedDocumentTotalsByYear(volumeIds: [String]? = nil) throws -> [Int: Int] {
        let scope = Self.normalizedScope(volumeIds)
        let sql = """
            SELECT CAST(substr(date_iso, 1, 4) AS INTEGER) AS yr, COUNT(*)
            FROM document_dates
            WHERE date_iso IS NOT NULL AND length(date_iso) >= 4
              \(Self.volumeScopeClause(scope, alias: "document_dates"))
            GROUP BY yr
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        _ = Self.bindVolumeScope(scope, to: stmt, from: 1)
        var totals: [Int: Int] = [:]
        while step(stmt) {
            let year = Int(sqlite3_column_int64(stmt, 0))
            guard year > 0 else { continue }
            totals[year] = Int(sqlite3_column_int64(stmt, 1))
        }
        return totals
    }

    /// Count of **dated** documents that mention any member of each rollup, per year — the
    /// `% of documents` numerator for the trajectory chart (CA-5).
    ///
    /// A person may be mentioned by several refs in one document; this counts each
    /// `(rollup × dated document × year)` at most once (`COUNT(DISTINCT document)`), so the
    /// numerator is a *document* share directly comparable to `datedDocumentTotalsByYear`.
    /// Same dated core join as `mentionTrajectories` — both dated-only, share ≤ 100%.
    ///
    /// - Parameter rollupIds: The rollups to chart. Empty → empty result.
    /// - Returns: `rollupId → (year → distinct-dated-document count)`.
    public func mentioningDocumentTrajectories(rollupIds: [Int], volumeIds: [String]? = nil) throws -> [Int: [Int: Int]] {
        guard !rollupIds.isEmpty else { return [:] }
        let ids = Array(Set(rollupIds))
        let placeholders = ids.map { _ in "?" }.joined(separator: ", ")
        let scope = Self.normalizedScope(volumeIds)
        let sql = """
            SELECT m.rollup_id,
                   CAST(substr(dd.date_iso, 1, 4) AS INTEGER) AS yr,
                   COUNT(DISTINCT pm.volume_id || '/' || pm.document_id)
            FROM person_mentions pm
            JOIN person_rollup_member m
              ON m.volume_id = pm.volume_id AND m.ref = pm.person_ref
            JOIN document_dates dd
              ON dd.volume_id = pm.volume_id AND dd.document_id = pm.document_id
            WHERE m.rollup_id IN (\(placeholders))
              AND dd.date_iso IS NOT NULL AND length(dd.date_iso) >= 4
              \(Self.volumeScopeClause(scope))
            GROUP BY m.rollup_id, yr
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        var col: Int32 = 1
        for rid in ids { sqlite3_bind_int64(stmt, col, Int64(rid)); col += 1 }
        col = Self.bindVolumeScope(scope, to: stmt, from: col)
        var result: [Int: [Int: Int]] = [:]
        while step(stmt) {
            let rid = Int(sqlite3_column_int64(stmt, 0))
            let year = Int(sqlite3_column_int64(stmt, 1))
            let count = Int(sqlite3_column_int64(stmt, 2))
            guard year > 0 else { continue }
            result[rid, default: [:]][year] = count
        }
        return result
    }

    // MARK: - Person Co-Mention Queries (CA-8)

    /// The focus person's top co-mentioned partners (CA-8 ego network).
    ///
    /// Two DIFFERENT rollups co-occur when a member ref of each is mentioned in the SAME
    /// `(volume_id, document_id)`. This first restricts to the documents that mention the
    /// focus rollup (via `documentKeys(forRollupId:)`'s join), then counts, for every OTHER
    /// rollup, the number of DISTINCT shared documents. The focus rollup itself is excluded
    /// (`m2.rollup_id <> ?`), so a person is never their own partner.
    ///
    /// The self-join is bounded to the focus person's own document set (the inner
    /// `focus_docs` CTE), so it never fans out over the whole corpus — the query cost scales
    /// with the focus person's mention count, not the corpus size. Results are ordered by
    /// shared-document count descending (ties broken by canonical name) and capped at
    /// `limit` — the DISCLOSED top-N bound (decision CA-8-1); there is no silent truncation,
    /// the caller shows the cap.
    ///
    /// - Parameters:
    ///   - rollupId: The focus person's rollup id.
    ///   - limit: Top-N partner cap (the disclosed bound).
    /// - Returns: `(rollupId, canonicalName, sharedDocuments)` partners, most-shared first.
    public func topCoMentionedPeople(forRollupId rollupId: Int,
                                     limit: Int,
                                     volumeIds: [String]? = nil) throws -> [(rollupId: Int, canonicalName: String, sharedDocuments: Int)] {
        // focus_docs: the DISTINCT documents mentioning any member of the focus rollup.
        // Then join every OTHER rollup mentioned in those same documents and count DISTINCT
        // shared documents. COUNT(DISTINCT …) collapses the case where a partner is mentioned
        // by several refs in one document. Scoping `focus_docs` to the volume selection is
        // sufficient — partners are counted only within those same documents (#189-B).
        let scope = Self.normalizedScope(volumeIds)
        let sql = """
            WITH focus_docs AS (
                SELECT DISTINCT pm.volume_id, pm.document_id
                FROM person_rollup_member m
                JOIN person_mentions pm
                  ON pm.volume_id = m.volume_id AND pm.person_ref = m.ref
                WHERE m.rollup_id = ?
                  \(Self.volumeScopeClause(scope))
            )
            SELECT m2.rollup_id, r2.canonical_name,
                   COUNT(DISTINCT pm2.volume_id || '/' || pm2.document_id) AS shared
            FROM focus_docs fd
            JOIN person_mentions pm2
              ON pm2.volume_id = fd.volume_id AND pm2.document_id = fd.document_id
            JOIN person_rollup_member m2
              ON m2.volume_id = pm2.volume_id AND m2.ref = pm2.person_ref
            JOIN person_rollup r2 ON r2.rollup_id = m2.rollup_id
            WHERE m2.rollup_id <> ?
            GROUP BY m2.rollup_id
            ORDER BY shared DESC, r2.canonical_name ASC
            LIMIT ?
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        var col: Int32 = 1
        sqlite3_bind_int64(stmt, col, Int64(rollupId)); col += 1
        col = Self.bindVolumeScope(scope, to: stmt, from: col)
        sqlite3_bind_int64(stmt, col, Int64(rollupId)); col += 1
        sqlite3_bind_int64(stmt, col, Int64(limit))
        var results: [(rollupId: Int, canonicalName: String, sharedDocuments: Int)] = []
        while step(stmt) {
            results.append((rollupId: Int(sqlite3_column_int64(stmt, 0)),
                            canonicalName: columnString(stmt, 1) ?? "",
                            sharedDocuments: Int(sqlite3_column_int64(stmt, 2))))
        }
        return results
    }

    /// Pairwise co-mention counts WITHIN a bounded rollup set (CA-8 partner-partner edges).
    ///
    /// For every unordered pair `(a, b)` with `a < b` drawn from `rollupIds`, counts the
    /// DISTINCT documents that mention BOTH — the partner-partner edges of the ego network.
    /// The self-join is constrained to the given ids on BOTH sides (`m1.rollup_id IN (…)
    /// AND m2.rollup_id IN (…) AND m1.rollup_id < m2.rollup_id`), so it never produces a
    /// full-corpus cartesian product; with the ego bounded to `focus + top-N` (≈ 30 rollups)
    /// this stays small and fast.
    ///
    /// The `m1.rollup_id < m2.rollup_id` predicate emits each unordered pair exactly once
    /// (a < b), so callers never de-duplicate. Pairs sharing no document are absent (no
    /// zero-weight edges).
    ///
    /// - Parameter rollupIds: The bounded rollup set (the ego: focus + partners). Fewer
    ///   than two ids → empty result.
    /// - Returns: `(a, b, sharedDocuments)` with `a < b`, one row per co-occurring pair.
    public func coMentionEdges(amongRollupIds rollupIds: [Int], volumeIds: [String]? = nil) throws -> [(a: Int, b: Int, sharedDocuments: Int)] {
        let ids = Array(Set(rollupIds))
        guard ids.count >= 2 else { return [] }
        let placeholders = ids.map { _ in "?" }.joined(separator: ", ")
        let scope = Self.normalizedScope(volumeIds)
        // Both members joined to person_mentions in the SAME document; the id-set filter on
        // both sides bounds the join to the ego, and rollup_id < rollup_id dedupes to a<b.
        // A shared document lives in one volume (pm2 joins pm1's volume), so filtering pm1 by
        // the volume scope restricts the edges to that scope (#189-B).
        let sql = """
            SELECT m1.rollup_id AS a, m2.rollup_id AS b,
                   COUNT(DISTINCT pm1.volume_id || '/' || pm1.document_id) AS shared
            FROM person_mentions pm1
            JOIN person_mentions pm2
              ON pm2.volume_id = pm1.volume_id AND pm2.document_id = pm1.document_id
            JOIN person_rollup_member m1
              ON m1.volume_id = pm1.volume_id AND m1.ref = pm1.person_ref
            JOIN person_rollup_member m2
              ON m2.volume_id = pm2.volume_id AND m2.ref = pm2.person_ref
            WHERE m1.rollup_id IN (\(placeholders))
              AND m2.rollup_id IN (\(placeholders))
              AND m1.rollup_id < m2.rollup_id
              \(Self.volumeScopeClause(scope, alias: "pm1"))
            GROUP BY m1.rollup_id, m2.rollup_id
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        var col: Int32 = 1
        for rid in ids { sqlite3_bind_int64(stmt, col, Int64(rid)); col += 1 }
        for rid in ids { sqlite3_bind_int64(stmt, col, Int64(rid)); col += 1 }
        col = Self.bindVolumeScope(scope, to: stmt, from: col)
        var results: [(a: Int, b: Int, sharedDocuments: Int)] = []
        while step(stmt) {
            results.append((a: Int(sqlite3_column_int64(stmt, 0)),
                            b: Int(sqlite3_column_int64(stmt, 1)),
                            sharedDocuments: Int(sqlite3_column_int64(stmt, 2))))
        }
        return results
    }

    /// The two-person co-mention timeline (CA-8 relationship dynamics): the number of
    /// DISTINCT DATED documents mentioning BOTH rollups, bucketed by document year.
    ///
    /// Joins each rollup's members to `person_mentions` in the SAME `(volume, document)`,
    /// then to `document_dates` for the year (first four chars of `date_iso`). Undated
    /// documents (no `document_dates` row, or a short/NULL `date_iso`) cannot be placed on
    /// the year axis and are excluded (disclosed as "co-occurrences in dated documents").
    /// `COUNT(DISTINCT document)` collapses multiple refs of either person in one document,
    /// so each shared document counts once per year.
    ///
    /// - Parameters:
    ///   - rollupA: First rollup id.
    ///   - rollupB: Second rollup id. Equal to `rollupA` → empty (a person is not their own
    ///     relationship).
    /// - Returns: `year → shared-dated-document count`.
    public func coMentionTimeline(rollupA: Int, rollupB: Int, volumeIds: [String]? = nil) throws -> [Int: Int] {
        guard rollupA != rollupB else { return [:] }
        let scope = Self.normalizedScope(volumeIds)
        let sql = """
            SELECT CAST(substr(dd.date_iso, 1, 4) AS INTEGER) AS yr,
                   COUNT(DISTINCT pm1.volume_id || '/' || pm1.document_id) AS shared
            FROM person_mentions pm1
            JOIN person_mentions pm2
              ON pm2.volume_id = pm1.volume_id AND pm2.document_id = pm1.document_id
            JOIN person_rollup_member m1
              ON m1.volume_id = pm1.volume_id AND m1.ref = pm1.person_ref
            JOIN person_rollup_member m2
              ON m2.volume_id = pm2.volume_id AND m2.ref = pm2.person_ref
            JOIN document_dates dd
              ON dd.volume_id = pm1.volume_id AND dd.document_id = pm1.document_id
            WHERE m1.rollup_id = ? AND m2.rollup_id = ?
              AND dd.date_iso IS NOT NULL AND length(dd.date_iso) >= 4
              \(Self.volumeScopeClause(scope, alias: "pm1"))
            GROUP BY yr
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        var col: Int32 = 1
        sqlite3_bind_int64(stmt, col, Int64(rollupA)); col += 1
        sqlite3_bind_int64(stmt, col, Int64(rollupB)); col += 1
        col = Self.bindVolumeScope(scope, to: stmt, from: col)
        var result: [Int: Int] = [:]
        while step(stmt) {
            let year = Int(sqlite3_column_int64(stmt, 0))
            guard year > 0 else { continue }
            result[year] = Int(sqlite3_column_int64(stmt, 1))
        }
        return result
    }

    // MARK: - Persons Table Queries (Session 41)

    /// Looks up a single person entry by volume and ref.
    ///
    /// Returns `nil` if the persons table has no row for this volume/ref pair
    /// (e.g. the volume has not been indexed yet).
    /// Human-readable name for a stored `(volumeId, ref)` correction anchor.
    ///
    /// The corrections manager renders each override by name; the anchor may no longer
    /// resolve (the volume was removed from the index, or a rebuild dropped that person),
    /// in which case this returns `nil` and the caller shows the raw `volumeId/ref`.
    ///
    /// - Parameters:
    ///   - volumeId: The anchor's volume.
    ///   - ref: The anchor's per-volume TEI `ref`.
    /// - Returns: The person's name, or `nil` when the anchor no longer resolves.
    public func personName(volumeId: String, ref: String) throws -> String? {
        let stmt = try prepare("SELECT name FROM persons WHERE volume_id = ? AND ref = ?")
        defer { sqlite3_finalize(stmt) }
        bind(stmt, 1, volumeId)
        bind(stmt, 2, ref)
        guard step(stmt) else { return nil }
        return columnString(stmt, 0)
    }

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
                   volume_count, authority_id, viaf_id
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
                                            volumeCount: Int(sqlite3_column_int64(stmt, 7)),
                                            authorityId: columnIntOptional(stmt, 8),
                                            viafId: columnString(stmt, 9)))
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
