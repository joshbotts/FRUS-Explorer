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

// MARK: - CrossReferenceNodeMetadata

/// Display-ready metadata for a single node (document) in the cross-reference graph.
///
/// Loaded from `document_cache` when building a `CrossReferenceGraph`. Fields may be
/// nil for documents whose volumes have not been downloaded and indexed.
///
/// Version history:
///   1.0 — Session 17: initial implementation
public struct CrossReferenceNodeMetadata: Sendable {
    public let documentId: String
    public let volumeId: String
    public let documentNumber: String?
    public let header: String?
    public let dateline: String?

    /// Stable dictionary key: `"volumeId/documentId"`.
    public var nodeKey: String { "\(volumeId)/\(documentId)" }

    public init(
        documentId: String,
        volumeId: String,
        documentNumber: String?,
        header: String?,
        dateline: String?
    ) {
        self.documentId = documentId
        self.volumeId = volumeId
        self.documentNumber = documentNumber
        self.header = header
        self.dateline = dateline
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
/// Version history:
///   1.0 — Session 17: initial implementation
public struct CrossReferenceGraph: Sendable {
    public let centralDocumentId: String
    public let centralVolumeId: String
    /// References whose target is the central document.
    public let inboundEdges: [CrossReferenceEdge]
    /// References whose source is the central document.
    public let outboundEdges: [CrossReferenceEdge]
    /// `true` when at least one inbound edge has a source volume absent from the
    /// caller-supplied `downloadedVolumeIds` set — indicating potentially incomplete
    /// inbound data (e.g. the DB was seeded externally or a volume was de-indexed).
    public let hasUndownloadedSources: Bool
    /// Metadata for all nodes reachable from the central document, keyed by `nodeKey`.
    public let nodeMetadata: [String: CrossReferenceNodeMetadata]

    public init(
        centralDocumentId: String,
        centralVolumeId: String,
        inboundEdges: [CrossReferenceEdge],
        outboundEdges: [CrossReferenceEdge],
        hasUndownloadedSources: Bool,
        nodeMetadata: [String: CrossReferenceNodeMetadata]
    ) {
        self.centralDocumentId = centralDocumentId
        self.centralVolumeId = centralVolumeId
        self.inboundEdges = inboundEdges
        self.outboundEdges = outboundEdges
        self.hasUndownloadedSources = hasUndownloadedSources
        self.nodeMetadata = nodeMetadata
    }

    /// Total number of edges (inbound + outbound).
    public var edgeCount: Int { inboundEdges.count + outboundEdges.count }
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
