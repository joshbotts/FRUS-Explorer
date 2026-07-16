// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ReferenceType

/// Whether a cross-reference was extracted from a footnote or an editorial note.
public enum ReferenceType: String, Sendable, Codable {
    case footnote
    case editorialNote
}

// MARK: - CrossReferenceEdge

/// A directed reference between two FRUS documents.
///
/// Edges are extracted from `<ref>` elements inside footnote and editorial-note blocks
/// during the indexing pass and stored in the `cross_references` SQLite table.
///
/// `targetVolumeId` always carries the resolved volume ID — `CrossReferenceStore`
/// normalises NULL (same-volume) rows using the source volume before returning edges.
///
/// Version history:
///   1.0 — Session 17: initial implementation
public struct CrossReferenceEdge: Sendable {
    public let sourceDocumentId: String
    public let sourceVolumeId: String
    public let targetDocumentId: String
    public let targetVolumeId: String
    /// Surrounding footnote or editorial-note text captured at index time; may be nil
    /// for edges indexed before Session 17 added the `context` column.
    public let context: String?
    public let referenceType: ReferenceType

    public init(
        sourceDocumentId: String,
        sourceVolumeId: String,
        targetDocumentId: String,
        targetVolumeId: String,
        context: String?,
        referenceType: ReferenceType
    ) {
        self.sourceDocumentId = sourceDocumentId
        self.sourceVolumeId = sourceVolumeId
        self.targetDocumentId = targetDocumentId
        self.targetVolumeId = targetVolumeId
        self.context = context
        self.referenceType = referenceType
    }
}

// MARK: - RelatedCitationCandidate

/// A document directly cited by, or citing, an anchor document — the cross-reference generator's
/// candidate row for the #308 find-related feature.
///
/// Carries the display fields (from `document_cache`, so only indexed/navigable candidates surface)
/// plus `citationCount`, the number of citation edges between the anchor and this candidate (the raw
/// strength the find-related engine normalises per axis).
///
/// Version history:
///   1.0 — #308 Phase 2b: initial implementation
public struct RelatedCitationCandidate: Sendable {
    /// The candidate document's volume.
    public let volumeId: String
    /// The candidate document's id.
    public let documentId: String
    /// The candidate's header (title); may be empty.
    public let header: String
    /// The candidate's dateline display string, if any.
    public let dateline: String?
    /// The candidate's document number within its volume, if any.
    public let documentNumber: String?
    /// Whether the candidate is an editorial note.
    public let isEditorialNote: Bool
    /// The number of citation edges between the anchor and this candidate (both directions).
    public let citationCount: Int

    public init(volumeId: String, documentId: String, header: String, dateline: String?,
                documentNumber: String?, isEditorialNote: Bool, citationCount: Int) {
        self.volumeId = volumeId
        self.documentId = documentId
        self.header = header
        self.dateline = dateline
        self.documentNumber = documentNumber
        self.isEditorialNote = isEditorialNote
        self.citationCount = citationCount
    }
}

// MARK: - CrossReferenceNodeMetadata

/// Display-ready metadata for a single node (document) in the cross-reference graph.
///
/// Loaded from `document_cache` (joined with `document_dates`) when building a
/// `CrossReferenceGraph`. Fields may be nil for documents whose volumes have not
/// been downloaded and indexed.
///
/// Version history:
///   1.0 — Session 17: initial implementation
///   1.1 — Session 161: `dateISO` (timeline layout, node date labels) and `summary`
///          (on-device summary surfaced in the node info panel)
public struct CrossReferenceNodeMetadata: Sendable {
    public let documentId: String
    public let volumeId: String
    public let documentNumber: String?
    public let header: String?
    public let dateline: String?
    /// ISO-8601 document date from `document_dates.date_iso` (`yyyy-MM-dd`, possibly
    /// truncated to `yyyy-MM` or `yyyy`). `nil` for unindexed or undated documents.
    public let dateISO: String?
    /// On-device generated summary from `document_cache.summary_text`, if the user
    /// has summarized this document. `nil` otherwise.
    public let summary: String?

    /// Stable dictionary key: `"volumeId/documentId"`.
    public var nodeKey: String { "\(volumeId)/\(documentId)" }

    public init(
        documentId: String,
        volumeId: String,
        documentNumber: String?,
        header: String?,
        dateline: String?,
        dateISO: String? = nil,
        summary: String? = nil
    ) {
        self.documentId = documentId
        self.volumeId = volumeId
        self.documentNumber = documentNumber
        self.header = header
        self.dateline = dateline
        self.dateISO = dateISO
        self.summary = summary
    }
}

// MARK: - CrossReferenceGraph

/// The ego graph centred on a single FRUS document.
///
/// Contains all inbound edges (references TO the central document) and outbound edges
/// (references FROM it), plus display metadata for every node in the graph and a flag
/// indicating whether inbound sources from volumes that are not in the downloaded set
/// may be present.
///
/// `nodeMetadata` is keyed by `"volumeId/documentId"` and includes the central document.
/// Nodes from volumes not present in `document_cache` have `nil` header/dateline fields.
///
/// When `fetchedDegree > 1`, `extendedEdges` carries the degree-2+ edges loaded by
/// `CrossReferenceStore.expandedGraph(forDocumentId:volumeId:degree:downloadedVolumeIds:)`.
/// These connect 1st-degree nodes to their own neighbors and, for degree 3, those
/// neighbors to their neighbors. The `inboundEdges` and `outboundEdges` arrays always
/// contain the degree-1 (direct) edges only.
///
/// Version history:
///   1.0 — Session 17: initial implementation
///   1.1 — Current session: `extendedEdges` and `fetchedDegree` for multi-degree expansion
public struct CrossReferenceGraph: Sendable {
    public let centralDocumentId: String
    public let centralVolumeId: String
    /// References whose target is the central document (degree 1 only).
    public let inboundEdges: [CrossReferenceEdge]
    /// References whose source is the central document (degree 1 only).
    public let outboundEdges: [CrossReferenceEdge]
    /// `true` when at least one inbound edge has a source volume absent from the
    /// caller-supplied `downloadedVolumeIds` set — indicating potentially incomplete
    /// inbound data (e.g. the DB was seeded externally or a volume was de-indexed).
    public let hasUndownloadedSources: Bool
    /// Metadata for all nodes reachable from the central document, keyed by `nodeKey`.
    public let nodeMetadata: [String: CrossReferenceNodeMetadata]
    /// Degree-2+ edges loaded by `expandedGraph(degree:)`.
    /// Empty when `fetchedDegree == 1` (the default).
    public let extendedEdges: [CrossReferenceEdge]
    /// How many degrees were fetched when building this graph (1, 2, or 3).
    public let fetchedDegree: Int

    public init(
        centralDocumentId: String,
        centralVolumeId: String,
        inboundEdges: [CrossReferenceEdge],
        outboundEdges: [CrossReferenceEdge],
        hasUndownloadedSources: Bool,
        nodeMetadata: [String: CrossReferenceNodeMetadata],
        extendedEdges: [CrossReferenceEdge] = [],
        fetchedDegree: Int = 1
    ) {
        self.centralDocumentId = centralDocumentId
        self.centralVolumeId = centralVolumeId
        self.inboundEdges = inboundEdges
        self.outboundEdges = outboundEdges
        self.hasUndownloadedSources = hasUndownloadedSources
        self.nodeMetadata = nodeMetadata
        self.extendedEdges = extendedEdges
        self.fetchedDegree = fetchedDegree
    }

    /// Total number of degree-1 edges (inbound + outbound).
    public var edgeCount: Int { inboundEdges.count + outboundEdges.count }

    /// Total number of edges across all degrees.
    public var totalEdgeCount: Int { inboundEdges.count + outboundEdges.count + extendedEdges.count }
}

// MARK: - VolumeConnectionEdge

/// A directed summary of cross-references between two FRUS volumes.
///
/// Produced by `CrossReferenceStore.volumeLevelConnections()`, which aggregates
/// the document-level `cross_references` table by volume. Only cross-volume edges
/// are included (same-volume references are stored with NULL `target_volume_id`
/// and are excluded from the aggregation).
///
/// Version history:
///   1.0 — Added for volume-level graph in CorpusBrowserWindowView
public struct VolumeConnectionEdge: Sendable {
    /// The volume containing the source documents.
    public let sourceVolumeId: String
    /// The volume containing the target documents.
    public let targetVolumeId: String
    /// Number of individual document-level cross-references from source to target.
    public let count: Int

    public init(sourceVolumeId: String, targetVolumeId: String, count: Int) {
        self.sourceVolumeId = sourceVolumeId
        self.targetVolumeId = targetVolumeId
        self.count = count
    }
}

// MARK: - VolumeEgoGraph

/// The ego graph centred on a single FRUS volume.
///
/// Contains all inbound edges (references from other volumes TO the central volume)
/// and outbound edges (references FROM the central volume TO other volumes).
/// Produced by `CrossReferenceStore.volumeEgoGraph(forVolumeId:)`.
///
/// Version history:
///   1.0 — Added when the volume-level graph was redesigned as a per-volume ego graph
public struct VolumeEgoGraph: Sendable {
    /// The volume this graph is centred on.
    public let centralVolumeId: String
    /// Other volumes that contain references to documents in the central volume.
    /// Each edge's `sourceVolumeId` is the referencing volume; `targetVolumeId` is `centralVolumeId`.
    public let inboundEdges: [VolumeConnectionEdge]
    /// Volumes that the central volume's documents reference.
    /// Each edge's `sourceVolumeId` is `centralVolumeId`; `targetVolumeId` is the referenced volume.
    public let outboundEdges: [VolumeConnectionEdge]

    public init(
        centralVolumeId: String,
        inboundEdges: [VolumeConnectionEdge],
        outboundEdges: [VolumeConnectionEdge]
    ) {
        self.centralVolumeId = centralVolumeId
        self.inboundEdges = inboundEdges
        self.outboundEdges = outboundEdges
    }

    /// All unique partner volume IDs (sources of inbound + targets of outbound), sorted.
    public var partnerVolumeIds: [String] {
        var seen = Set<String>()
        var ids: [String] = []
        for edge in inboundEdges  { if seen.insert(edge.sourceVolumeId).inserted { ids.append(edge.sourceVolumeId) } }
        for edge in outboundEdges { if seen.insert(edge.targetVolumeId).inserted { ids.append(edge.targetVolumeId) } }
        return ids.sorted()
    }

    /// Volume IDs that appear in both inbound and outbound edges.
    public var bidirectionalVolumeIds: Set<String> {
        Set(inboundEdges.map(\.sourceVolumeId)).intersection(Set(outboundEdges.map(\.targetVolumeId)))
    }
}
