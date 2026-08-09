// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ResolvedEdgeIndex

/// Which documents in the rest of the series cite a document — the bundled
/// `resolved-edge-index.json` (#262).
///
/// ## The gap this closes
/// `cross_references` holds edges harvested from the volumes the reader has **indexed**. So the
/// inbound half of a document's citation graph is a function of what happens to be downloaded: a
/// reader with ten volumes is shown the citations from those ten and told nothing about the rest.
/// The graph's `hasUndownloadedSources` flag cannot fix that, because the missing edge is not in
/// the table to be flagged — its own doc comment says the flag "is normally false".
///
/// ## Why this is small, and why the issue expected it not to be
/// #262 estimated the artifact from the validator's ~2.70M resolved references and called it "the
/// big artifact". Two filters cut it by three orders of magnitude, and both are properties of the
/// question rather than compression tricks:
///
/// 1. **Only document-to-document references count.** Of 2,713,592 references, 181,807 sit inside
///    a document div (so they have a source document at all) and 77,792 resolve to a document div
///    in a shippable volume. The rest are page anchors, index entries, and targets outside the
///    manifest.
/// 2. **Only cross-volume edges belong here.** 69,164 of those 77,792 are same-volume — and if
///    you are reading a document you have its volume, so `cross_references` already holds every
///    one of them. Shipping them again would duplicate the local table and add nothing a reader
///    could not already see.
///
/// What is left is the edges that are *structurally* unreachable locally: citations from a volume
/// the reader does not have.
///
/// ## Encoding
/// Grouped by **target**, because the question is always "what cites this document". Endpoints are
/// two-level `(volume index, document index)` pairs so a document id is stored once per volume
/// rather than once per edge, and each target's sources are a flat alternating array of the two.
///
/// Version history:
///   1.0 — Session 2026-08-09: #262
public struct ResolvedEdgeIndex: Codable, Sendable, Equatable {

    /// One cited document and everything outside its own volume that cites it.
    public struct TargetEdges: Codable, Sendable, Equatable {
        /// Index into ``ResolvedEdgeIndex/volumes`` of the cited document's volume.
        public let volume: Int
        /// Index into that volume's ``ResolvedEdgeIndex/documents`` row.
        public let document: Int
        /// Source endpoints, flattened: `[volume, document, volume, document, …]`, ascending.
        public let sources: [Int]
        /// Of those sources, how many cite it from a footnote rather than body text.
        ///
        /// Kept as a scalar rather than a flag per edge: 95.3% of document-to-document references
        /// in the corpus are an editor's annotation, so a citation list that does not say so
        /// misdescribes what the reader is looking at — but the per-edge bit would double the
        /// artifact to say something that is almost always the same.
        public let footnoteSources: Int

        enum CodingKeys: String, CodingKey {
            case volume = "v"
            case document = "d"
            case sources = "s"
            case footnoteSources = "f"
        }

        /// Creates a target row.
        public init(volume: Int, document: Int, sources: [Int], footnoteSources: Int) {
            self.volume = volume
            self.document = document
            self.sources = sources
            self.footnoteSources = footnoteSources
        }

        /// Decodes, refusing a row whose source array is not endpoint-aligned — a short read
        /// would pair one volume with another edge's document and invent a citation.
        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            volume = try c.decode(Int.self, forKey: .volume)
            document = try c.decode(Int.self, forKey: .document)
            sources = try c.decode([Int].self, forKey: .sources)
            footnoteSources = try c.decode(Int.self, forKey: .footnoteSources)
            guard sources.count.isMultiple(of: 2) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .sources, in: c,
                    debugDescription: "\(sources.count) source values is not a whole number of endpoints")
            }
        }

        /// Edges into this target.
        public var edgeCount: Int { sources.count / 2 }
    }

    /// What the generating scan saw — every number a disclosure is built from.
    public struct Coverage: Codable, Sendable, Equatable {
        /// Volumes scanned.
        public let volumesScanned: Int
        /// Every `<ref target>` harvested.
        public let referencesScanned: Int
        /// References sitting inside a document div, and so having a source document.
        public let referencesInsideDocuments: Int
        /// References resolving to a document div in a shippable volume.
        public let documentEdges: Int
        /// Of those, references whose ends share a volume — excluded, because the local table
        /// already holds them whenever the reader can see the document at all.
        public let sameVolumeEdges: Int
        /// Distinct cited documents in the index.
        public let targetCount: Int
        /// Volumes contributing at least one cross-volume citation.
        public let citingVolumeCount: Int

        /// Cross-volume edges stored.
        public var storedEdges: Int { documentEdges - sameVolumeEdges }

        /// Creates a coverage block.
        public init(volumesScanned: Int, referencesScanned: Int, referencesInsideDocuments: Int,
                    documentEdges: Int, sameVolumeEdges: Int, targetCount: Int,
                    citingVolumeCount: Int) {
            self.volumesScanned = volumesScanned
            self.referencesScanned = referencesScanned
            self.referencesInsideDocuments = referencesInsideDocuments
            self.documentEdges = documentEdges
            self.sameVolumeEdges = sameVolumeEdges
            self.targetCount = targetCount
            self.citingVolumeCount = citingVolumeCount
        }
    }

    /// Artifact schema version.
    public let schemaVersion: Int
    /// Generation date stamp (`yyyy-MM-dd`).
    public let generated: String
    /// Volume ids appearing at either end, sorted.
    public let volumes: [String]
    /// Document xml:ids per volume, parallel to ``volumes``, each sorted.
    public let documents: [[String]]
    /// One row per cited document, sorted by (volume, document).
    public let targets: [TargetEdges]
    /// The funnel.
    public let coverage: Coverage

    /// Creates an index.
    public init(schemaVersion: Int, generated: String, volumes: [String],
                documents: [[String]], targets: [TargetEdges], coverage: Coverage) {
        self.schemaVersion = schemaVersion
        self.generated = generated
        self.volumes = volumes
        self.documents = documents
        self.targets = targets
        self.coverage = coverage
    }
}
