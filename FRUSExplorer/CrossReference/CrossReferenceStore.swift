// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SQLite3

// MARK: - CrossReferenceStore

/// Queries the `cross_references` and `document_cache` SQLite tables to build
/// `CrossReferenceGraph` values used by the graph renderer in Session 18.
///
/// Opens its own **read-only** SQLite connection to the shared database file.
/// SQLite WAL mode allows concurrent readers alongside `IndexingPipeline`'s
/// read-write connection without blocking.
///
/// All public methods are actor-isolated and therefore safe to call from any
/// concurrent context.
///
/// Version history:
///   1.0 — Session 17: initial implementation
///   1.1 — Session 129: `expandedGraph(forDocumentId:volumeId:degree:downloadedVolumeIds:)`
///          for multi-degree ego graph expansion
///   1.2 — Session 130: removed 20-node and 15-node caps; all reachable nodes now included
///   1.3 — Session 130: `documentHeaders(for:)` public method for batch header lookup
///   1.4 — Session 130: `documentsWithUserTags()` — returns all (vol, doc, tagIds) rows
///          from document_cache for use by ResearchView's direct-tag data source
///   1.5 — CA-6 (analytics CA-track): statistical queries for CrossReferenceAnalyticsView —
///          `topDocumentsByInDegree(limit:)`, `resolvedInDegrees()`, `resolvedOutDegrees()`,
///          and `resolvedCitationEdges()` (all resolved-target-only, for in-degree ranking,
///          the degree-distribution histogram, and the offline PageRank input)
///   1.6 — Session 7 / #240B: `is_broken = 0` exclusion across every edge/degree/count
///          query (validated-broken refs never reach graphs or analytics) +
///          `excludedBrokenCount(yearRange:volumeIds:)` for the disclosure caption
public actor CrossReferenceStore {

    // MARK: - SQLite handle

    // nonisolated(unsafe): deinit is nonisolated and must close the handle.
    // Safe because the actor serialises all access and the handle is never
    // read from outside the actor while it is live.
    nonisolated(unsafe) private var db: OpaquePointer?

    // MARK: - Init / deinit

    /// Opens a read-only connection to `databaseURL`.
    ///
    /// - Throws: `CrossReferenceError.databaseOpenFailed` if SQLite cannot open the file.
    public init(databaseURL: URL) throws {
        var handle: OpaquePointer?
        let rc = sqlite3_open_v2(
            databaseURL.path,
            &handle,
            SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX,
            nil
        )
        guard rc == SQLITE_OK, let h = handle else {
            let msg = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            sqlite3_close(handle)
            throw CrossReferenceError.databaseOpenFailed(message: msg)
        }
        db = h

        // Wait up to 5 s instead of failing instantly with SQLITE_BUSY when a WAL
        // checkpoint or recovery briefly locks the file (writers on other connections
        // include FTS5Store and IndexingPipeline's auxiliary connection).
        sqlite3_busy_timeout(h, 5000)

        #if DEBUG
        print("[CrossReferenceStore] Opened read-only connection to \(databaseURL.lastPathComponent)")
        #endif
    }

    deinit {
        if let h = db { sqlite3_close_v2(h) }
    }

    // MARK: - Public API

    /// Builds the full ego graph for the given document.
    ///
    /// - Parameters:
    ///   - documentId: The `xml:id` of the central document.
    ///   - volumeId: The volume the central document belongs to.
    ///   - downloadedVolumeIds: All volume IDs currently downloaded. Used to compute
    ///     `CrossReferenceGraph.hasUndownloadedSources`.
    /// - Returns: A `CrossReferenceGraph` with inbound and outbound edges, node metadata
    ///   for all endpoints, and the `hasUndownloadedSources` flag.
    public func graph(
        forDocumentId documentId: String,
        volumeId: String,
        downloadedVolumeIds: Set<String>
    ) throws -> CrossReferenceGraph {
        let local    = try inboundEdges(forDocumentId: documentId, volumeId: volumeId)
        let outbound = try outboundEdges(forDocumentId: documentId, volumeId: volumeId)

        // #262: complete the inbound half from the bundled corpus-wide index. Without it the
        // answer to "what cites this?" was a function of what the reader happened to have
        // downloaded, and the flag below could never fire for the case it was written for —
        // an edge from a volume you do not have was not in the table to be flagged.
        let inbound = Self.completingInboundEdges(
            local: local, documentId: documentId, volumeId: volumeId, index: resolvedEdgeIndex)
        let undownloadedCiting = inbound
            .filter { !downloadedVolumeIds.contains($0.sourceVolumeId) }
            .map(\.sourceVolumeId)
        let hasUndownloaded = !undownloadedCiting.isEmpty

        var meta: [String: CrossReferenceNodeMetadata] = [:]

        // Resolve metadata for all unique endpoints + the central document.
        var endpoints: Set<String> = ["\(volumeId)/\(documentId)"]
        for edge in inbound  { endpoints.insert("\(edge.sourceVolumeId)/\(edge.sourceDocumentId)") }
        for edge in outbound { endpoints.insert("\(edge.targetVolumeId)/\(edge.targetDocumentId)") }

        for key in endpoints {
            let parts = key.split(separator: "/", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            let vol = parts[0], doc = parts[1]
            if let m = try fetchMetadata(volumeId: vol, documentId: doc) {
                meta[key] = m
            } else {
                // Placeholder for unindexed/undownloaded nodes.
                meta[key] = CrossReferenceNodeMetadata(
                    documentId: doc, volumeId: vol,
                    documentNumber: nil, header: nil, dateline: nil
                )
            }
        }

        return CrossReferenceGraph(
            centralDocumentId: documentId,
            centralVolumeId: volumeId,
            inboundEdges: inbound,
            outboundEdges: outbound,
            hasUndownloadedSources: hasUndownloaded,
            nodeMetadata: meta,
            undownloadedCitingVolumeIds: Set(undownloadedCiting).sorted()
        )
    }

    /// The local inbound edges, plus every cross-volume citation the bundled index knows about
    /// that the local table does not already hold.
    ///
    /// A local edge always wins: it carries the context text and the real reference type, which
    /// the bundled index does not store. The completion only adds pairs, never replaces one.
    ///
    /// The synthesised edges are typed `.footnote`, and that is a deliberate approximation rather
    /// than a guess: 95.3% of document-to-document references in the corpus are an editor's
    /// annotation, and the index stores the footnote count per target instead of a flag per edge.
    /// Any surface that distinguishes the two must read `ResolvedEdgeIndex.footnoteSourceCount`
    /// rather than trusting an individual synthesised edge's type.
    ///
    /// `nonisolated` and `static` so it is a pure function of its inputs, testable without a
    /// database.
    nonisolated static func completingInboundEdges(
        local: [CrossReferenceEdge],
        documentId: String,
        volumeId: String,
        index: ResolvedEdgeIndex?
    ) -> [CrossReferenceEdge] {
        guard let index else { return local }
        var seen = Set(local.map { "\($0.sourceVolumeId)/\($0.sourceDocumentId)" })
        var result = local
        for source in index.inboundSources(volumeId: volumeId, documentId: documentId) {
            let key = "\(source.volumeId)/\(source.documentId)"
            guard seen.insert(key).inserted else { continue }
            result.append(CrossReferenceEdge(
                sourceDocumentId: source.documentId,
                sourceVolumeId: source.volumeId,
                targetDocumentId: documentId,
                targetVolumeId: volumeId,
                context: nil,
                referenceType: .footnote))
        }
        return result
    }

    /// Builds a multi-degree ego graph centred on a single document.
    ///
    /// - **Degree 1**: returns the same result as `graph(forDocumentId:volumeId:downloadedVolumeIds:)`.
    /// - **Degree 2**: additionally loads inbound + outbound edges for each 1st-degree node
    ///   (capped at the 20 most-connected first-degree nodes to keep graph size manageable)
    ///   and stores them in `CrossReferenceGraph.extendedEdges`.
    /// - **Degree 3**: extends further from 2nd-degree nodes (capped at 15).
    ///
    /// Edges already present at a lower degree are deduplicated. All node metadata
    /// encountered during expansion is included in the returned `nodeMetadata` dictionary.
    ///
    /// - Parameters:
    ///   - documentId: The `xml:id` of the central document.
    ///   - volumeId: The volume the central document belongs to.
    ///   - degree: 1, 2, or 3 — how many hops to expand from the central document.
    ///   - downloadedVolumeIds: All volume IDs currently downloaded.
    /// - Returns: A `CrossReferenceGraph` with `fetchedDegree` set to `degree` and
    ///   `extendedEdges` populated for degree > 1.
    public func expandedGraph(
        forDocumentId documentId: String,
        volumeId: String,
        degree: Int,
        downloadedVolumeIds: Set<String>
    ) throws -> CrossReferenceGraph {
        guard degree > 1 else {
            return try graph(forDocumentId: documentId, volumeId: volumeId,
                             downloadedVolumeIds: downloadedVolumeIds)
        }

        // Build the degree-1 base graph.
        let base = try graph(forDocumentId: documentId, volumeId: volumeId,
                             downloadedVolumeIds: downloadedVolumeIds)

        // Collect 1st-degree node keys.
        var firstDegreeKeys: Set<String> = []
        for edge in base.inboundEdges {
            firstDegreeKeys.insert("\(edge.sourceVolumeId)/\(edge.sourceDocumentId)")
        }
        for edge in base.outboundEdges {
            firstDegreeKeys.insert("\(edge.targetVolumeId)/\(edge.targetDocumentId)")
        }

        // Track all edges already present to avoid duplication.
        var seenEdgeKeys: Set<String> = []
        for edge in base.inboundEdges + base.outboundEdges {
            seenEdgeKeys.insert(Self.edgeKey(edge))
        }

        var extendedEdges: [CrossReferenceEdge] = []
        var extendedMeta: [String: CrossReferenceNodeMetadata] = base.nodeMetadata
        var allNodeKeys: Set<String> = Set(["\(volumeId)/\(documentId)"] + firstDegreeKeys)

        // Expand degree-2: load edges for every 1st-degree node.
        let deg2Nodes = Array(firstDegreeKeys).sorted()
        var secondDegreeKeys: Set<String> = []
        for nodeKey in deg2Nodes {
            let newEdges = try edgesFor(nodeKey: nodeKey,
                                        seenEdgeKeys: &seenEdgeKeys,
                                        allNodeKeys: &allNodeKeys,
                                        extendedMeta: &extendedMeta,
                                        downloadedVolumeIds: downloadedVolumeIds)
            for edge in newEdges {
                // A node is 2nd-degree if it's new (not in degree-1 set).
                let srcKey = "\(edge.sourceVolumeId)/\(edge.sourceDocumentId)"
                let tgtKey = "\(edge.targetVolumeId)/\(edge.targetDocumentId)"
                if !firstDegreeKeys.contains(srcKey) && srcKey != "\(volumeId)/\(documentId)" {
                    secondDegreeKeys.insert(srcKey)
                }
                if !firstDegreeKeys.contains(tgtKey) && tgtKey != "\(volumeId)/\(documentId)" {
                    secondDegreeKeys.insert(tgtKey)
                }
            }
            extendedEdges.append(contentsOf: newEdges)
        }

        // Expand degree-3: load edges for every 2nd-degree node.
        if degree >= 3 {
            for nodeKey in Array(secondDegreeKeys).sorted() {
                let newEdges = try edgesFor(nodeKey: nodeKey,
                                            seenEdgeKeys: &seenEdgeKeys,
                                            allNodeKeys: &allNodeKeys,
                                            extendedMeta: &extendedMeta,
                                            downloadedVolumeIds: downloadedVolumeIds)
                extendedEdges.append(contentsOf: newEdges)
            }
        }

        #if DEBUG
        print("[CrossReferenceStore] expandedGraph degree=\(degree): \(base.edgeCount) deg-1 + \(extendedEdges.count) extended edges")
        #endif

        return CrossReferenceGraph(
            centralDocumentId: documentId,
            centralVolumeId:   volumeId,
            inboundEdges:      base.inboundEdges,
            outboundEdges:     base.outboundEdges,
            hasUndownloadedSources: base.hasUndownloadedSources,
            nodeMetadata:      extendedMeta,
            extendedEdges:     extendedEdges,
            fetchedDegree:     degree
        )
    }

    /// Loads all inbound and outbound edges for `nodeKey`, returning only those not
    /// already in `seenEdgeKeys`. Updates `seenEdgeKeys`, `allNodeKeys`, and `extendedMeta`
    /// in-place.
    private func edgesFor(
        nodeKey: String,
        seenEdgeKeys: inout Set<String>,
        allNodeKeys:  inout Set<String>,
        extendedMeta: inout [String: CrossReferenceNodeMetadata],
        downloadedVolumeIds: Set<String>
    ) throws -> [CrossReferenceEdge] {
        let parts = nodeKey.split(separator: "/", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return [] }
        let vol = parts[0], doc = parts[1]

        let nodeIn  = try inboundEdges(forDocumentId: doc, volumeId: vol)
        let nodeOut = try outboundEdges(forDocumentId: doc, volumeId: vol)
        var newEdges: [CrossReferenceEdge] = []

        for edge in nodeIn + nodeOut {
            let ek = Self.edgeKey(edge)
            guard !seenEdgeKeys.contains(ek) else { continue }
            seenEdgeKeys.insert(ek)
            newEdges.append(edge)

            // Ensure metadata exists for all endpoints of the new edge.
            for nk in ["\(edge.sourceVolumeId)/\(edge.sourceDocumentId)",
                       "\(edge.targetVolumeId)/\(edge.targetDocumentId)"]
            where !allNodeKeys.contains(nk) {
                allNodeKeys.insert(nk)
                let np = nk.split(separator: "/", maxSplits: 1).map(String.init)
                guard np.count == 2 else { continue }
                if let m = try? fetchMetadata(volumeId: np[0], documentId: np[1]) {
                    extendedMeta[nk] = m
                } else {
                    extendedMeta[nk] = CrossReferenceNodeMetadata(
                        documentId: np[1], volumeId: np[0],
                        documentNumber: nil, header: nil, dateline: nil
                    )
                }
            }
        }
        return newEdges
    }

    /// Stable string key for deduplicating edges.
    private static func edgeKey(_ edge: CrossReferenceEdge) -> String {
        "\(edge.sourceVolumeId)/\(edge.sourceDocumentId)->\(edge.targetVolumeId)/\(edge.targetDocumentId)"
    }

    /// Returns the document header text for a batch of `(volumeId, documentId)` pairs,
    /// queried from the `document_cache` table.
    ///
    /// Keys with no matching row (volume not yet indexed) are omitted from the result.
    /// The return dictionary is keyed by `"volumeId/documentId"`.
    public func documentHeaders(
        for keys: [(volumeId: String, documentId: String)]
    ) throws -> [String: String] {
        var result: [String: String] = [:]
        for (vol, doc) in keys {
            if let meta = try fetchMetadata(volumeId: vol, documentId: doc),
               let header = meta.header {
                result["\(vol)/\(doc)"] = header
            }
        }
        return result
    }

    /// Returns the subset of `keys` present in `document_cache` — the documents actually indexed
    /// locally, regardless of whether they carry a `<head>`. Editorial notes are indexed but
    /// headerless, so their header is nil even when downloaded; membership here is the true
    /// "is this document indexed?" signal, distinct from a citation into an un-downloaded volume
    /// (#278). Keyed `"volumeId/documentId"`.
    public func indexedDocumentKeys(
        for keys: [(volumeId: String, documentId: String)]
    ) throws -> Set<String> {
        var result: Set<String> = []
        for (vol, doc) in keys {
            if try fetchMetadata(volumeId: vol, documentId: doc) != nil {
                result.insert("\(vol)/\(doc)")
            }
        }
        return result
    }

    /// Returns every `(volumeId, documentId, userTagIds)` tuple where `document_cache`
    /// has at least one user tag stored in the `user_tag_ids` column.
    ///
    /// Used by `ResearchView` to build the directly-tagged-documents data source,
    /// independently of whether those documents also have `ResearchNote` records in
    /// SwiftData. This keeps user tags and research notes as separate annotation types.
    public func documentsWithUserTags() throws -> [(volumeId: String, documentId: String, userTagIds: [UUID])] {
        let sql = """
            SELECT volume_id, document_id, user_tag_ids
            FROM document_cache
            WHERE user_tag_ids IS NOT NULL AND LENGTH(TRIM(user_tag_ids)) > 0
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        var result: [(volumeId: String, documentId: String, userTagIds: [UUID])] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let vol = columnString(stmt, 0) ?? ""
            let doc = columnString(stmt, 1) ?? ""
            let raw = columnString(stmt, 2) ?? ""
            let ids = raw.split(separator: " ").compactMap { UUID(uuidString: String($0)) }
            if !ids.isEmpty {
                result.append((volumeId: vol, documentId: doc, userTagIds: ids))
            }
        }
        return result
    }

    /// The bundled corpus-wide citation index, or `nil` when it failed to load — in which case
    /// the graph falls back to the local table alone, which is what shipped before #262.
    ///
    /// Read through a property rather than the store directly so a test can substitute a fixture.
    var resolvedEdgeIndex: ResolvedEdgeIndex? { ResolvedEdgeIndexStore.shared }

    /// Returns all edges whose target is `(documentId, volumeId)`.
    public func inboundEdges(
        forDocumentId documentId: String,
        volumeId: String
    ) throws -> [CrossReferenceEdge] {
        // NULL target_volume_id means "same volume as source", so normalise using COALESCE.
        let sql = """
            SELECT source_volume_id, source_document_id,
                   COALESCE(target_volume_id, source_volume_id) AS resolved_target_volume,
                   target_document_id,
                   reference_type, context
            FROM cross_references
            WHERE target_document_id = ?
              AND COALESCE(target_volume_id, source_volume_id) = ?
              AND is_broken = 0
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, documentId, -1, SQLITE_TRANSIENT_CR)
        sqlite3_bind_text(stmt, 2, volumeId,   -1, SQLITE_TRANSIENT_CR)
        return try collectEdges(stmt)
    }

    /// Returns all edges whose source is `(documentId, volumeId)`.
    public func outboundEdges(
        forDocumentId documentId: String,
        volumeId: String
    ) throws -> [CrossReferenceEdge] {
        let sql = """
            SELECT source_volume_id, source_document_id,
                   COALESCE(target_volume_id, source_volume_id) AS resolved_target_volume,
                   target_document_id,
                   reference_type, context
            FROM cross_references
            WHERE source_document_id = ?
              AND source_volume_id = ?
              AND is_broken = 0
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, documentId, -1, SQLITE_TRANSIENT_CR)
        sqlite3_bind_text(stmt, 2, volumeId,   -1, SQLITE_TRANSIENT_CR)
        return try collectEdges(stmt)
    }

    /// Returns the documents directly cited by, or citing, the anchor — the cross-reference
    /// generator's bounded candidate set for the #308 find-related feature.
    ///
    /// Unions both directions of the anchor's ego edges and groups by the *other* endpoint with its
    /// citation multiplicity. The outbound direction applies the shared `documentTargetPredicate`
    /// (drops page / footnote / index / chapter / appendix / bare-volume / URL anchors that also live
    /// in `target_document_id`); the inbound direction needs no such filter because a citation's
    /// *source* is always a real document. The `JOIN document_cache` is an INNER join — like the
    /// archival-neighbour paths — so only indexed (navigable) candidates surface. `is_broken = 0`
    /// throughout. Cost is `O(ego edges)`: two index-keyed ego scans (`source`/`target_document_id`),
    /// never a corpus scan.
    ///
    /// - Parameters:
    ///   - documentId: The anchor document id.
    ///   - volumeId: The anchor volume id.
    ///   - scopeVolumeIds: Restrict candidates to these volumes (`nil` / empty = all indexed).
    ///   - limit: Maximum candidates, ordered by citation multiplicity (descending) then key.
    /// - Returns: The candidate documents with their citation counts, the anchor itself excluded.
    public func relatedByCitation(
        forDocumentId documentId: String,
        volumeId: String,
        scopeVolumeIds: Set<String>? = nil,
        limit: Int
    ) throws -> [RelatedCitationCandidate] {
        // Sort the scope ids for a deterministic bind order.
        let scopeIds = scopeVolumeIds.map { Array($0).sorted() } ?? []
        let scopeClause = scopeIds.isEmpty
            ? ""
            : "AND i.cand_vol IN (\(scopeIds.map { _ in "?" }.joined(separator: ", ")))"
        let sql = """
            WITH incident(cand_vol, cand_doc) AS (
                SELECT COALESCE(cr.target_volume_id, cr.source_volume_id), cr.target_document_id
                FROM cross_references cr
                WHERE cr.source_document_id = ? AND cr.source_volume_id = ?
                  AND cr.is_broken = 0
                  AND \(Self.documentTargetPredicate)
                UNION ALL
                SELECT cr.source_volume_id, cr.source_document_id
                FROM cross_references cr
                WHERE cr.target_document_id = ?
                  AND COALESCE(cr.target_volume_id, cr.source_volume_id) = ?
                  AND cr.is_broken = 0
            )
            SELECT i.cand_vol, i.cand_doc, COUNT(*) AS citation_count,
                   dc.header, dc.dateline, dc.document_number, dc.is_editorial_note
            FROM incident i
            JOIN document_cache dc ON dc.volume_id = i.cand_vol AND dc.document_id = i.cand_doc
            WHERE NOT (i.cand_vol = ? AND i.cand_doc = ?)
              \(scopeClause)
            GROUP BY i.cand_vol, i.cand_doc
            ORDER BY citation_count DESC, i.cand_vol, i.cand_doc
            LIMIT ?
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        var col: Int32 = 1
        sqlite3_bind_text(stmt, col, documentId, -1, SQLITE_TRANSIENT_CR); col += 1 // outbound source_document_id
        sqlite3_bind_text(stmt, col, volumeId,   -1, SQLITE_TRANSIENT_CR); col += 1 // outbound source_volume_id
        sqlite3_bind_text(stmt, col, documentId, -1, SQLITE_TRANSIENT_CR); col += 1 // inbound target_document_id
        sqlite3_bind_text(stmt, col, volumeId,   -1, SQLITE_TRANSIENT_CR); col += 1 // inbound resolved target volume
        sqlite3_bind_text(stmt, col, volumeId,   -1, SQLITE_TRANSIENT_CR); col += 1 // exclude anchor volume
        sqlite3_bind_text(stmt, col, documentId, -1, SQLITE_TRANSIENT_CR); col += 1 // exclude anchor document
        for vid in scopeIds {
            sqlite3_bind_text(stmt, col, vid, -1, SQLITE_TRANSIENT_CR); col += 1
        }
        sqlite3_bind_int(stmt, col, Int32(max(0, limit)))

        var results: [RelatedCitationCandidate] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(RelatedCitationCandidate(
                volumeId:        columnString(stmt, 0) ?? "",
                documentId:      columnString(stmt, 1) ?? "",
                header:          columnString(stmt, 3) ?? "",
                dateline:        columnString(stmt, 4),
                documentNumber:  columnString(stmt, 5),
                isEditorialNote: sqlite3_column_int(stmt, 6) != 0,
                citationCount:   Int(sqlite3_column_int(stmt, 2))))
        }
        return results
    }

    // MARK: - Archival provenance queries

    /// Returns the lot file citation for a document, if one was recorded during indexing.
    ///
    /// Queries `document_sources` for the `lot_file` and `repository` fields stored by
    /// `IndexingPipeline.storeIndexData()`. Returns `nil` when the document has not been
    /// indexed, has no recognizable source note, or has a source note that doesn't include
    /// a lot file number (e.g. decimal-file era notes, "previously published" citations).
    public func lotFileCitation(
        forVolumeId volumeId: String,
        documentId: String
    ) throws -> (repository: String?, lotFile: String, recordGroup: String?)? {
        let sql = """
            SELECT repository, lot_file, record_group
            FROM document_sources
            WHERE volume_id = ? AND document_id = ? AND lot_file IS NOT NULL
            LIMIT 1
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, volumeId,   -1, SQLITE_TRANSIENT_CR)
        sqlite3_bind_text(stmt, 2, documentId, -1, SQLITE_TRANSIENT_CR)
        guard sqlite3_step(stmt) == SQLITE_ROW,
              let lot = columnString(stmt, 1), !lot.isEmpty else { return nil }
        return (
            repository:   columnString(stmt, 0),
            lotFile:      lot,
            recordGroup:  columnString(stmt, 2)
        )
    }

    /// Returns all distinct FRUS documents that share the same archival lot file as the
    /// given document. Documents are ordered by volume then document ID.
    ///
    /// This enables "archival discovery" — finding other FRUS documents drawn from the
    /// same box or series without following editorial cross-references. Results exclude
    /// the querying document itself.
    ///
    /// - Parameters:
    ///   - lotFile: The lot file number to search for (e.g. `"64 D 199"`).
    ///   - excludingVolumeId: Volume ID to exclude the querying document.
    ///   - excludingDocumentId: Document ID to exclude.
    /// - Returns: Array of `(volumeId, documentId, repository, header)` tuples.
    ///   `header` comes from `document_cache` and may be nil for unindexed docs.
    public func documentsFromSameLotFile(
        lotFile: String,
        excludingVolumeId: String,
        excludingDocumentId: String
    ) throws -> [(volumeId: String, documentId: String, repository: String?, header: String?)] {
        let sql = """
            SELECT ds.volume_id, ds.document_id, ds.repository, dc.header
            FROM document_sources ds
            LEFT JOIN document_cache dc
                   ON dc.volume_id = ds.volume_id AND dc.document_id = ds.document_id
            WHERE ds.lot_file = ?
              AND NOT (ds.volume_id = ? AND ds.document_id = ?)
            ORDER BY ds.volume_id, ds.document_id
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, lotFile,             -1, SQLITE_TRANSIENT_CR)
        sqlite3_bind_text(stmt, 2, excludingVolumeId,   -1, SQLITE_TRANSIENT_CR)
        sqlite3_bind_text(stmt, 3, excludingDocumentId, -1, SQLITE_TRANSIENT_CR)
        var results: [(volumeId: String, documentId: String, repository: String?, header: String?)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append((
                volumeId:   columnString(stmt, 0) ?? "",
                documentId: columnString(stmt, 1) ?? "",
                repository: columnString(stmt, 2),
                header:     columnString(stmt, 3)
            ))
        }
        return results
    }

    /// Returns cross-volume reference counts, aggregated by (sourceVolumeId, targetVolumeId).
    ///
    /// Only cross-volume edges are returned — same-volume references (stored with NULL
    /// `target_volume_id`) are excluded. Results are sorted by count descending.
    ///
    /// - Parameter limitToVolumeIds: When non-nil, only edges where BOTH the source and
    ///   target volume are in this set are returned. Pass the volume IDs of a single
    ///   subseries to scope the graph to that subseries rather than the entire corpus.
    ///   `nil` returns all cross-volume connections (corpus-wide).
    ///
    /// Used by `VolumeConnectionGraphView` in the Corpus Browser.
    public func volumeLevelConnections(limitToVolumeIds: [String]? = nil,
                                       yearRange: ClosedRange<Int>? = nil) throws -> [VolumeConnectionEdge] {
        // The heat matrix is a volume×volume adjacency, so `limitToVolumeIds` keeps its
        // both-endpoints contract (source AND target volume in the set). The year filter is
        // source-anchored like the other CA-6 queries (a single defensible edge date).
        var sql = """
            SELECT cr.source_volume_id, cr.target_volume_id, COUNT(*) AS ref_count
            FROM cross_references cr
            \(Self.sourceDateJoin(yearRange))
            WHERE cr.target_volume_id IS NOT NULL
              AND cr.target_volume_id != cr.source_volume_id
              AND cr.is_broken = 0
            """
        let datePredicate = Self.sourceDatePredicate(yearRange)
        if !datePredicate.isEmpty { sql += "\n  AND \(datePredicate)" }
        if let vids = limitToVolumeIds, !vids.isEmpty {
            let placeholders = vids.map { _ in "?" }.joined(separator: ", ")
            sql += "\n  AND cr.source_volume_id IN (\(placeholders))"
            sql += "\n  AND cr.target_volume_id IN (\(placeholders))"
        }
        sql += "\nGROUP BY cr.source_volume_id, cr.target_volume_id ORDER BY ref_count DESC"

        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }

        // The year params (if any) bind first; the volume-id double-bind follows, so its columns
        // shift right by 2 when a year range is active.
        var col = Self.bindDateRange(yearRange, to: stmt, from: 1)
        if let vids = limitToVolumeIds, !vids.isEmpty {
            // Bind the volume IDs twice — once for source_volume_id, once for target_volume_id.
            for vid in vids {
                sqlite3_bind_text(stmt, col, vid, -1, SQLITE_TRANSIENT_CR)
                col += 1
            }
            for vid in vids {
                sqlite3_bind_text(stmt, col, vid, -1, SQLITE_TRANSIENT_CR)
                col += 1
            }
        }

        var result: [VolumeConnectionEdge] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let src = columnString(stmt, 0) ?? ""
            let tgt = columnString(stmt, 1) ?? ""
            let cnt = Int(sqlite3_column_int64(stmt, 2))
            result.append(VolumeConnectionEdge(sourceVolumeId: src, targetVolumeId: tgt, count: cnt))
        }
        return result
    }

    /// Returns the ego graph for a single volume: all cross-volume inbound and outbound edges,
    /// aggregated by partner volume.
    ///
    /// - Inbound edges: other volumes whose documents contain `<ref target="volumeId#...">`.
    /// - Outbound edges: volumes that documents in `volumeId` reference.
    ///
    /// Same-volume references (NULL `target_volume_id`) and self-loop references are excluded.
    public func volumeEgoGraph(forVolumeId volumeId: String) throws -> VolumeEgoGraph {
        let inbound  = try volumeInboundConnectionEdges(forVolumeId: volumeId)
        let outbound = try volumeOutboundConnectionEdges(forVolumeId: volumeId)
        return VolumeEgoGraph(centralVolumeId: volumeId, inboundEdges: inbound, outboundEdges: outbound)
    }

    private func volumeInboundConnectionEdges(forVolumeId volumeId: String) throws -> [VolumeConnectionEdge] {
        let sql = """
            SELECT source_volume_id, target_volume_id, COUNT(*) AS ref_count
            FROM cross_references
            WHERE target_volume_id = ?
              AND source_volume_id != ?
              AND is_broken = 0
            GROUP BY source_volume_id
            ORDER BY ref_count DESC
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, volumeId, -1, SQLITE_TRANSIENT_CR)
        sqlite3_bind_text(stmt, 2, volumeId, -1, SQLITE_TRANSIENT_CR)
        return try collectVolumeEdges(stmt)
    }

    private func volumeOutboundConnectionEdges(forVolumeId volumeId: String) throws -> [VolumeConnectionEdge] {
        let sql = """
            SELECT source_volume_id, target_volume_id, COUNT(*) AS ref_count
            FROM cross_references
            WHERE source_volume_id = ?
              AND target_volume_id IS NOT NULL
              AND target_volume_id != ?
              AND is_broken = 0
            GROUP BY target_volume_id
            ORDER BY ref_count DESC
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, volumeId, -1, SQLITE_TRANSIENT_CR)
        sqlite3_bind_text(stmt, 2, volumeId, -1, SQLITE_TRANSIENT_CR)
        return try collectVolumeEdges(stmt)
    }

    private func collectVolumeEdges(_ stmt: OpaquePointer) throws -> [VolumeConnectionEdge] {
        var edges: [VolumeConnectionEdge] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let src = columnString(stmt, 0) ?? ""
            let tgt = columnString(stmt, 1) ?? ""
            let cnt = Int(sqlite3_column_int64(stmt, 2))
            edges.append(VolumeConnectionEdge(sourceVolumeId: src, targetVolumeId: tgt, count: cnt))
        }
        return edges
    }

    /// Returns the total reference count (inbound + outbound) for each of `keys`,
    /// keyed by `"volumeId/documentId"`.
    ///
    /// Used by the graph renderer to scale node size with connectivity. Each key
    /// costs one indexed `COUNT(*)` query; callers pass the (small) node set of a
    /// single ego graph.
    public func connectionCounts(
        forKeys keys: [(volumeId: String, documentId: String)]
    ) throws -> [String: Int] {
        var result: [String: Int] = [:]
        for (vol, doc) in keys {
            result["\(vol)/\(doc)"] = try edgeCount(forDocumentId: doc, volumeId: vol)
        }
        return result
    }

    /// Returns the total number of inbound + outbound edges for the given document.
    public func edgeCount(
        forDocumentId documentId: String,
        volumeId: String
    ) throws -> Int {
        let sql = """
            SELECT COUNT(*) FROM cross_references
            WHERE is_broken = 0
              AND ((source_document_id = ? AND source_volume_id = ?)
                OR (target_document_id = ? AND COALESCE(target_volume_id, source_volume_id) = ?))
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, documentId, -1, SQLITE_TRANSIENT_CR)
        sqlite3_bind_text(stmt, 2, volumeId,   -1, SQLITE_TRANSIENT_CR)
        sqlite3_bind_text(stmt, 3, documentId, -1, SQLITE_TRANSIENT_CR)
        sqlite3_bind_text(stmt, 4, volumeId,   -1, SQLITE_TRANSIENT_CR)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    // MARK: - CA-6 statistical queries

    // MARK: - CA-6 Filter Helpers (year-range + volume scope, #189-B)

    /// Normalises an optional volume scope: `nil`/empty → `nil` (no filter), else deduplicated.
    /// A `nil` scope emits no SQL, so whole-corpus output is byte-for-byte unchanged.
    private static func normalizedScope(_ volumeIds: [String]?) -> [String]? {
        guard let ids = volumeIds, !ids.isEmpty else { return nil }
        return Array(Set(ids))
    }

    /// The `JOIN document_dates` clause binding each edge to its **source** document's date, or
    /// `""` when no year range is active. CA-6 filters are **source-anchored** (#189-B): the year
    /// and volume scope gate the *citing* document, so a heavily-cited target outside the slice
    /// still surfaces (the foundational documents a project leans on). Undated sources are
    /// dropped by this INNER JOIN.
    private static func sourceDateJoin(_ yearRange: ClosedRange<Int>?) -> String {
        yearRange == nil ? "" :
            "JOIN document_dates dds ON dds.volume_id = cr.source_volume_id AND dds.document_id = cr.source_document_id"
    }

    /// The bare WHERE predicate restricting the source document's `date_iso` year to `yearRange`
    /// (point-year on the start date, matching the Person/Corpus dashboards), or `""` when nil.
    private static func sourceDatePredicate(_ yearRange: ClosedRange<Int>?) -> String {
        yearRange == nil ? "" :
            "dds.date_iso IS NOT NULL AND length(dds.date_iso) >= 4 AND CAST(substr(dds.date_iso, 1, 4) AS INTEGER) BETWEEN ? AND ?"
    }

    /// Excludes the non-document citation-target forms that also live in `target_document_id` and
    /// would otherwise be crowned as "documents" in the ranking / histogram / PageRank (#209). Real
    /// documents and editorial notes are `d`/`en`-prefixed numbered ids; the anchor forms actually
    /// present in the corpus are (verified against real indexes, e.g. frus1952-54v10, where a
    /// footnote `d197fn2` had the top in-degree and index items outranked real documents):
    ///   - page / front-matter anchors — `pg_*` (roman pages `pg_III`, front matter `pg_fm12`, and
    ///     cross-volume `pg_*` fragments `resolvePageBasedCrossReferences` leaves unresolved),
    ///   - footnote anchors — any id containing `fn` (e.g. `d197fn2`),
    ///   - back-of-book index items (`in5`), chapter / appendix anchors (`ch3`, `app*`),
    ///   - bare volume ids (`frus…`) and URLs (`*://*`).
    ///
    /// A denylist (rather than a `d[0-9]*` allow-list) because document ids in the wild aren't
    /// strictly `d`+digits, and the store's own fixtures use bare stand-in ids. Applied to **every**
    /// degree/edge query so the in-degree ranking, degree histogram, and PageRank landmark list stay
    /// lockstep and never crown a non-document anchor as a "landmark document".
    private static let documentTargetPredicate = """
        cr.target_document_id NOT GLOB 'pg_*' \
        AND cr.target_document_id NOT GLOB '*fn*' \
        AND cr.target_document_id NOT GLOB 'in[0-9]*' \
        AND cr.target_document_id NOT GLOB 'ch[0-9]*' \
        AND cr.target_document_id NOT GLOB 'app*' \
        AND cr.target_document_id NOT GLOB 'frus*' \
        AND cr.target_document_id NOT GLOB '*://*'
        """

    /// Excludes cross-references the corpus validation dataset flags as unresolvable (#240B), so the
    /// degree rankings / edge lists / analytics never count a dead reference. Uses the `cr` alias the
    /// analytics queries assign.
    private static let brokenExclusionPredicate = "cr.is_broken = 0"

    /// The bare `<columnExpr> IN (?, …)` predicate for a normalised volume scope, or `""` when nil.
    private static func volumeScopePredicate(_ scope: [String]?, columnExpr: String) -> String {
        guard let scope, !scope.isEmpty else { return "" }
        let ph = scope.map { _ in "?" }.joined(separator: ", ")
        return "\(columnExpr) IN (\(ph))"
    }

    /// Assembles a `WHERE` clause from bare predicates, dropping the empty ones; `""` when none.
    private static func whereClause(_ predicates: [String]) -> String {
        let kept = predicates.filter { !$0.isEmpty }
        return kept.isEmpty ? "" : "WHERE " + kept.joined(separator: " AND ")
    }

    /// Binds the year range's `[lower, upper]` at `col` when active; returns the next free column.
    private static func bindDateRange(_ yearRange: ClosedRange<Int>?, to stmt: OpaquePointer?, from col: Int32) -> Int32 {
        guard let yearRange else { return col }
        sqlite3_bind_int64(stmt, col, Int64(yearRange.lowerBound))
        sqlite3_bind_int64(stmt, col + 1, Int64(yearRange.upperBound))
        return col + 2
    }

    /// Binds a normalised volume scope's ids as text starting at `col`; returns the next column.
    private static func bindVolumeScope(_ scope: [String]?, to stmt: OpaquePointer?, from col: Int32) -> Int32 {
        guard let scope, !scope.isEmpty else { return col }
        var c = col
        for vid in scope {
            sqlite3_bind_text(stmt, c, vid, -1, SQLITE_TRANSIENT_CR)
            c += 1
        }
        return c
    }

    /// The top-N documents by inbound citation count (in-degree), joined to their header.
    ///
    /// A NULL `target_volume_id` denotes a **same-volume** reference (the TEI `<ref>` used a
    /// bare `#…` fragment, so the target lives in the source's own volume — this includes the
    /// page references resolved at index time). Such edges are attributed to the node
    /// `(source_volume_id, target_document_id)` via `COALESCE(target_volume_id, source_volume_id)`
    /// — the same normalisation the ego-graph queries (`inboundEdges`/`outboundEdges`) already
    /// use — so within-volume citations count toward a document's in-degree instead of being
    /// dropped. Ranking is over the resolved node `(resolved_target_volume, target_document_id)`.
    ///
    /// - Parameters:
    ///   - limit: Maximum rows to return, ordered by in-degree descending.
    ///   - yearRange: When non-nil, count only citations whose **source** document is dated in
    ///     this year span (source-anchored, #189-B). `nil` counts every year.
    ///   - volumeIds: When non-empty, count only citations whose **source** volume is in this set.
    ///     `nil`/empty counts the whole corpus (byte-for-byte unchanged).
    /// - Returns: `(volumeId, documentId, inDegree, header)` — `header` from `document_cache`,
    ///   `nil` when the target is not in the cache (a not-yet-indexed cross-volume target, or a
    ///   non-document anchor such as an unresolved roman-numeral page reference).
    public func topDocumentsByInDegree(
        limit: Int,
        yearRange: ClosedRange<Int>? = nil,
        volumeIds: [String]? = nil
    ) throws -> [(volumeId: String, documentId: String, inDegree: Int, header: String?)] {
        let scope = Self.normalizedScope(volumeIds)
        let sql = """
            SELECT COALESCE(cr.target_volume_id, cr.source_volume_id) AS resolved_target_volume,
                   cr.target_document_id, COUNT(*) AS in_degree, dc.header
            FROM cross_references cr
            \(Self.sourceDateJoin(yearRange))
            LEFT JOIN document_cache dc
                   ON dc.volume_id = COALESCE(cr.target_volume_id, cr.source_volume_id)
                  AND dc.document_id = cr.target_document_id
            \(Self.whereClause([Self.documentTargetPredicate, Self.brokenExclusionPredicate,
                                Self.sourceDatePredicate(yearRange),
                                Self.volumeScopePredicate(scope, columnExpr: "cr.source_volume_id")]))
            GROUP BY resolved_target_volume, cr.target_document_id
            ORDER BY in_degree DESC, resolved_target_volume, cr.target_document_id
            LIMIT ?
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        var col = Self.bindDateRange(yearRange, to: stmt, from: 1)
        col = Self.bindVolumeScope(scope, to: stmt, from: col)
        sqlite3_bind_int(stmt, col, Int32(max(0, limit)))
        var result: [(volumeId: String, documentId: String, inDegree: Int, header: String?)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            result.append((
                volumeId:   columnString(stmt, 0) ?? "",
                documentId: columnString(stmt, 1) ?? "",
                inDegree:   Int(sqlite3_column_int64(stmt, 2)),
                header:     columnString(stmt, 3)
            ))
        }
        return result
    }

    /// The in-degree of every target document — one row per distinct resolved node
    /// `(COALESCE(target_volume_id, source_volume_id), target_document_id)`, giving its inbound
    /// citation count. Same-volume references (NULL target volume) are attributed to their
    /// source volume, matching `topDocumentsByInDegree`.
    ///
    /// The view buckets these per-document counts into a histogram with
    /// `CrossReferenceStats.degreeDistribution(_:)` (a pure, testable function) rather than
    /// bucketing in SQL, so the bucketing rule is unit-testable without a database.
    ///
    /// - Parameters:
    ///   - yearRange: When non-nil, count only edges whose source document is dated in this span
    ///     (source-anchored, matching `topDocumentsByInDegree` so the histograms stay lockstep).
    ///   - volumeIds: When non-empty, count only edges whose source volume is in this set.
    /// - Returns: The in-degree value for each target document (unordered).
    public func resolvedInDegrees(yearRange: ClosedRange<Int>? = nil, volumeIds: [String]? = nil) throws -> [Int] {
        let scope = Self.normalizedScope(volumeIds)
        let sql = """
            SELECT COUNT(*) AS in_degree
            FROM cross_references cr
            \(Self.sourceDateJoin(yearRange))
            \(Self.whereClause([Self.documentTargetPredicate, Self.brokenExclusionPredicate,
                                Self.sourceDatePredicate(yearRange),
                                Self.volumeScopePredicate(scope, columnExpr: "cr.source_volume_id")]))
            GROUP BY COALESCE(cr.target_volume_id, cr.source_volume_id), cr.target_document_id
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        let col = Self.bindDateRange(yearRange, to: stmt, from: 1)
        _ = Self.bindVolumeScope(scope, to: stmt, from: col)
        var result: [Int] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            result.append(Int(sqlite3_column_int64(stmt, 0)))
        }
        return result
    }

    /// The number of unresolvable cross-references (`is_broken = 1`) emitted by source documents in
    /// the given scope — the count disclosed in the analytics footnote (#240B). Source-anchored like
    /// the degree queries so it moves in lockstep with the era/scope filters.
    ///
    /// - Parameters:
    ///   - yearRange: When non-nil, count only refs whose source document is dated in this span.
    ///   - volumeIds: When non-empty, count only refs whose source volume is in this set.
    /// - Returns: The count of excluded broken references.
    public func excludedBrokenCount(yearRange: ClosedRange<Int>? = nil, volumeIds: [String]? = nil) throws -> Int {
        let scope = Self.normalizedScope(volumeIds)
        let sql = """
            SELECT COUNT(*) AS broken_count
            FROM cross_references cr
            \(Self.sourceDateJoin(yearRange))
            \(Self.whereClause(["cr.is_broken = 1",
                                Self.sourceDatePredicate(yearRange),
                                Self.volumeScopePredicate(scope, columnExpr: "cr.source_volume_id")]))
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        let col = Self.bindDateRange(yearRange, to: stmt, from: 1)
        _ = Self.bindVolumeScope(scope, to: stmt, from: col)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    /// The out-degree of every source document that emits at least one cross-reference —
    /// one row per distinct `(source_volume_id, source_document_id)` counting its outbound
    /// edges. Same-volume edges are included (they are attributed to the source volume in the
    /// in-degree query), so the in- and out-degree distributions are drawn from the same
    /// edge population.
    ///
    /// - Parameters:
    ///   - yearRange: When non-nil, count only edges whose source document is dated in this span.
    ///   - volumeIds: When non-empty, count only edges whose source volume is in this set.
    /// - Returns: The out-degree value for each such source document (unordered).
    public func resolvedOutDegrees(yearRange: ClosedRange<Int>? = nil, volumeIds: [String]? = nil) throws -> [Int] {
        let scope = Self.normalizedScope(volumeIds)
        let sql = """
            SELECT COUNT(*) AS out_degree
            FROM cross_references cr
            \(Self.sourceDateJoin(yearRange))
            \(Self.whereClause([Self.documentTargetPredicate, Self.brokenExclusionPredicate,
                                Self.sourceDatePredicate(yearRange),
                                Self.volumeScopePredicate(scope, columnExpr: "cr.source_volume_id")]))
            GROUP BY cr.source_volume_id, cr.source_document_id
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        let col = Self.bindDateRange(yearRange, to: stmt, from: 1)
        _ = Self.bindVolumeScope(scope, to: stmt, from: col)
        var result: [Int] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            result.append(Int(sqlite3_column_int64(stmt, 0)))
        }
        return result
    }

    /// Every document-to-document citation edge, as `(source, target)` node keys.
    ///
    /// Same-volume references (NULL target volume) are attributed to the node
    /// `(source_volume_id, target_document_id)` via `COALESCE(target_volume_id, source_volume_id)`
    /// — the same node identity as `topDocumentsByInDegree` — so within-volume citations feed
    /// the offline `PageRank` power iteration rather than being dropped. The node set is the
    /// union of the sources and the resolved targets.
    ///
    /// Self-loops (`source == resolved target`) are excluded — a document citing itself carries
    /// no influence signal and would distort PageRank's dangling/mass handling.
    ///
    /// - Parameters:
    ///   - yearRange: When non-nil, keep only edges whose source document is dated in this span
    ///     (source-anchored). PageRank then runs over the sub-graph seen from the in-slice sources.
    ///   - volumeIds: When non-empty, keep only edges whose source volume is in this set.
    /// - Returns: One `(source, target)` pair per stored edge (with multiplicity — repeated
    ///   citations between the same pair appear repeatedly, so PageRank weights a heavily-cited
    ///   pair more, matching the heat matrix's `ref_count`).
    public func resolvedCitationEdges(yearRange: ClosedRange<Int>? = nil, volumeIds: [String]? = nil) throws -> [(source: DocumentNodeKey, target: DocumentNodeKey)] {
        let scope = Self.normalizedScope(volumeIds)
        // The self-loop exclusion is always present, so it leads the WHERE; the date/volume
        // predicates are AND-appended after it.
        let selfLoop = "NOT (COALESCE(cr.target_volume_id, cr.source_volume_id) = cr.source_volume_id AND cr.target_document_id = cr.source_document_id)"
        let sql = """
            SELECT cr.source_volume_id, cr.source_document_id,
                   COALESCE(cr.target_volume_id, cr.source_volume_id) AS resolved_target_volume,
                   cr.target_document_id
            FROM cross_references cr
            \(Self.sourceDateJoin(yearRange))
            \(Self.whereClause([selfLoop,
                                Self.documentTargetPredicate, Self.brokenExclusionPredicate,
                                Self.sourceDatePredicate(yearRange),
                                Self.volumeScopePredicate(scope, columnExpr: "cr.source_volume_id")]))
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        let col = Self.bindDateRange(yearRange, to: stmt, from: 1)
        _ = Self.bindVolumeScope(scope, to: stmt, from: col)
        var result: [(source: DocumentNodeKey, target: DocumentNodeKey)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let src = DocumentNodeKey(volumeId: columnString(stmt, 0) ?? "",
                                      documentId: columnString(stmt, 1) ?? "")
            let tgt = DocumentNodeKey(volumeId: columnString(stmt, 2) ?? "",
                                      documentId: columnString(stmt, 3) ?? "")
            result.append((source: src, target: tgt))
        }
        return result
    }

    // MARK: - Private helpers

    private func fetchMetadata(
        volumeId: String,
        documentId: String
    ) throws -> CrossReferenceNodeMetadata? {
        let sql = """
            SELECT dc.document_number, dc.header, dc.dateline, dd.date_iso, dc.summary_text
            FROM document_cache dc
            LEFT JOIN document_dates dd
                   ON dd.volume_id = dc.volume_id AND dd.document_id = dc.document_id
            WHERE dc.volume_id = ? AND dc.document_id = ?
            LIMIT 1
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, volumeId,   -1, SQLITE_TRANSIENT_CR)
        sqlite3_bind_text(stmt, 2, documentId, -1, SQLITE_TRANSIENT_CR)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return CrossReferenceNodeMetadata(
            documentId: documentId,
            volumeId:   volumeId,
            documentNumber: columnString(stmt, 0),
            header:     columnString(stmt, 1),
            dateline:   columnString(stmt, 2),
            dateISO:    columnString(stmt, 3),
            summary:    columnString(stmt, 4)
        )
    }

    private func collectEdges(_ stmt: OpaquePointer) throws -> [CrossReferenceEdge] {
        var edges: [CrossReferenceEdge] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let srcVol  = columnString(stmt, 0) ?? ""
            let srcDoc  = columnString(stmt, 1) ?? ""
            let tgtVol  = columnString(stmt, 2) ?? ""
            let tgtDoc  = columnString(stmt, 3) ?? ""
            let refType = ReferenceType(rawValue: columnString(stmt, 4) ?? "") ?? .footnote
            let context = columnString(stmt, 5)
            edges.append(CrossReferenceEdge(
                sourceDocumentId: srcDoc,
                sourceVolumeId:   srcVol,
                targetDocumentId: tgtDoc,
                targetVolumeId:   tgtVol,
                context:          context,
                referenceType:    refType
            ))
        }
        return edges
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        guard let db else { throw CrossReferenceError.databaseOpenFailed(message: "connection closed") }
        var stmt: OpaquePointer?
        let rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        guard rc == SQLITE_OK, let s = stmt else {
            let msg = String(cString: sqlite3_errmsg(db))
            throw CrossReferenceError.queryFailed(message: msg)
        }
        return s
    }

    private func columnString(_ stmt: OpaquePointer, _ col: Int32) -> String? {
        guard let ptr = sqlite3_column_text(stmt, col) else { return nil }
        return String(cString: ptr)
    }
}

// MARK: - SQLITE_TRANSIENT shim

private let SQLITE_TRANSIENT_CR = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

// MARK: - CrossReferenceError

public enum CrossReferenceError: Error, LocalizedError {
    case databaseOpenFailed(message: String)
    case queryFailed(message: String)

    public var errorDescription: String? {
        switch self {
        case .databaseOpenFailed(let msg): return "CrossReferenceStore: database open failed — \(msg)"
        case .queryFailed(let msg):        return "CrossReferenceStore: query failed — \(msg)"
        }
    }
}
