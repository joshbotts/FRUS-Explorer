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
        let inbound  = try inboundEdges(forDocumentId: documentId, volumeId: volumeId)
        let outbound = try outboundEdges(forDocumentId: documentId, volumeId: volumeId)

        // `hasUndownloadedSources`: true when any inbound edge originates from a volume
        // that is absent from the caller's downloaded set. In the common case every edge
        // comes from an indexed (and therefore downloaded) volume, so this is normally
        // false. It can be true when the DB was seeded externally or when a volume was
        // de-indexed after its edges were written.
        let hasUndownloaded = inbound.contains { !downloadedVolumeIds.contains($0.sourceVolumeId) }

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
            nodeMetadata: meta
        )
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
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, documentId, -1, SQLITE_TRANSIENT_CR)
        sqlite3_bind_text(stmt, 2, volumeId,   -1, SQLITE_TRANSIENT_CR)
        return try collectEdges(stmt)
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
    public func volumeLevelConnections(limitToVolumeIds: [String]? = nil) throws -> [VolumeConnectionEdge] {
        var sql = """
            SELECT source_volume_id, target_volume_id, COUNT(*) AS ref_count
            FROM cross_references
            WHERE target_volume_id IS NOT NULL
              AND target_volume_id != source_volume_id
            """
        if let vids = limitToVolumeIds, !vids.isEmpty {
            let placeholders = vids.map { _ in "?" }.joined(separator: ", ")
            sql += "\n  AND source_volume_id IN (\(placeholders))"
            sql += "\n  AND target_volume_id IN (\(placeholders))"
        }
        sql += "\nGROUP BY source_volume_id, target_volume_id ORDER BY ref_count DESC"

        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }

        if let vids = limitToVolumeIds, !vids.isEmpty {
            // Bind the volume IDs twice — once for source_volume_id, once for target_volume_id.
            for (i, vid) in vids.enumerated() {
                sqlite3_bind_text(stmt, Int32(i + 1), vid, -1, SQLITE_TRANSIENT_CR)
            }
            let offset = Int32(vids.count)
            for (i, vid) in vids.enumerated() {
                sqlite3_bind_text(stmt, offset + Int32(i + 1), vid, -1, SQLITE_TRANSIENT_CR)
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

    /// Returns the total number of inbound + outbound edges for the given document.
    public func edgeCount(
        forDocumentId documentId: String,
        volumeId: String
    ) throws -> Int {
        let sql = """
            SELECT COUNT(*) FROM cross_references
            WHERE (source_document_id = ? AND source_volume_id = ?)
               OR (target_document_id = ? AND COALESCE(target_volume_id, source_volume_id) = ?)
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

    // MARK: - Private helpers

    private func fetchMetadata(
        volumeId: String,
        documentId: String
    ) throws -> CrossReferenceNodeMetadata? {
        let sql = """
            SELECT document_number, header, dateline
            FROM document_cache
            WHERE volume_id = ? AND document_id = ?
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
            dateline:   columnString(stmt, 2)
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
