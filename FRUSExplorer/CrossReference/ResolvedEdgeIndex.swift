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
/// ## What it is for
/// `cross_references` holds only the edges harvested from volumes the reader has **indexed**, so
/// the inbound half of a document's citation graph has always been a function of what happens to
/// be downloaded. A reader with ten volumes was shown the citations from those ten and told
/// nothing about the rest — and the graph's `hasUndownloadedSources` flag could not help, because
/// the missing edge was never in the table to be flagged.
///
/// ## Cross-volume only, and why that is the whole answer
/// 69,164 of the corpus's 77,792 document-to-document citations are **same-volume**. If you can
/// see a document you have its volume, so the local table already holds every one of those. What
/// is left — 8,628 edges into 5,740 documents from 184 volumes — is exactly the set that is
/// structurally unreachable without this file, and it fits in 281 KB.
///
/// ## What it does not carry
/// No titles, dates, or document numbers for the citing documents. Those live in the volume's own
/// TEI and would multiply the artifact many times over to restate what a download provides. A
/// surface built on this can say *how many* documents cite this one and *which volumes* they are
/// in — which is what tells a reader what to download — and must not imply it knows more.
///
/// Version history:
///   1.0 — Session 2026-08-09: #262
struct ResolvedEdgeIndex: Decodable, Sendable {

    /// One cited document and everything outside its own volume that cites it.
    struct TargetEdges: Decodable, Sendable {
        /// Index into ``ResolvedEdgeIndex/volumes``.
        let volume: Int
        /// Index into that volume's ``ResolvedEdgeIndex/documents`` row.
        let document: Int
        /// Source endpoints, flattened: `[volume, document, volume, document, …]`.
        let sources: [Int]
        /// Of those sources, how many cite from a footnote rather than body text.
        let footnoteSources: Int

        enum CodingKeys: String, CodingKey {
            case volume = "v"
            case document = "d"
            case sources = "s"
            case footnoteSources = "f"
        }

        /// Decodes, refusing a row whose source array is not endpoint-aligned — a short read would
        /// pair one volume with another edge's document and invent a citation.
        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            volume = try c.decode(Int.self, forKey: .volume)
            document = try c.decode(Int.self, forKey: .document)
            sources = try c.decode([Int].self, forKey: .sources)
            footnoteSources = try c.decode(Int.self, forKey: .footnoteSources)
            guard sources.count.isMultiple(of: 2) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .sources, in: c,
                    debugDescription: "\(sources.count) values is not a whole number of endpoints")
            }
        }
    }

    /// What the generating scan saw.
    struct Coverage: Decodable, Sendable {
        /// Volumes scanned.
        let volumesScanned: Int
        /// Every `<ref target>` harvested.
        let referencesScanned: Int
        /// References inside a document div.
        let referencesInsideDocuments: Int
        /// References resolving to a document in a shippable volume.
        let documentEdges: Int
        /// Of those, same-volume edges — excluded, because the local table holds them.
        let sameVolumeEdges: Int
        /// Distinct cited documents.
        let targetCount: Int
        /// Volumes contributing a cross-volume citation.
        let citingVolumeCount: Int

        /// Cross-volume edges stored — what the artifact actually carries.
        var storedEdges: Int { documentEdges - sameVolumeEdges }
    }

    /// Artifact schema version.
    let schemaVersion: Int
    /// Generation date stamp.
    let generated: String
    /// Volume ids, sorted.
    let volumes: [String]
    /// Document xml:ids per volume, parallel to ``volumes``.
    let documents: [[String]]
    /// One row per cited document.
    let targets: [TargetEdges]
    /// The funnel.
    let coverage: Coverage

    /// Row lookup by `"volume/document"`, built once on decode — the query runs on every graph
    /// load and a linear scan of 5,740 rows per load is not free.
    private var rowByKey: [String: Int] = [:]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, generated, volumes, documents, targets, coverage
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        generated = try c.decode(String.self, forKey: .generated)
        volumes = try c.decode([String].self, forKey: .volumes)
        documents = try c.decode([[String]].self, forKey: .documents)
        targets = try c.decode([TargetEdges].self, forKey: .targets)
        coverage = try c.decode(Coverage.self, forKey: .coverage)

        for (position, target) in targets.enumerated() {
            guard let key = Self.key(volume: target.volume, document: target.document,
                                     volumes: volumes, documents: documents) else { continue }
            rowByKey[key] = position
        }
    }

    // MARK: - Lookups

    /// Every document outside `volumeId` that cites `(volumeId, documentId)`.
    ///
    /// Returns an empty array both when nothing cites it and when the document is not in the
    /// index at all. Those are the same answer here — the index covers every shippable volume, so
    /// absence means no cross-volume citation was found — but a caller phrasing it for a reader
    /// should say "none found", never "none exist".
    func inboundSources(volumeId: String,
                        documentId: String) -> [(volumeId: String, documentId: String)] {
        guard let position = rowByKey["\(volumeId)/\(documentId)"] else { return [] }
        let target = targets[position]
        var result: [(volumeId: String, documentId: String)] = []
        result.reserveCapacity(target.sources.count / 2)
        for offset in stride(from: 0, to: target.sources.count, by: 2) {
            let volume = target.sources[offset]
            let document = target.sources[offset + 1]
            guard volumes.indices.contains(volume),
                  documents[volume].indices.contains(document) else { continue }
            result.append((volumes[volume], documents[volume][document]))
        }
        return result
    }

    /// Of those citing documents, how many cite from an editor's footnote rather than body text.
    ///
    /// 95.3% of document-to-document references in the corpus are footnotes, so a surface that
    /// presents these as the documents' own citations misdescribes almost all of them.
    func footnoteSourceCount(volumeId: String, documentId: String) -> Int {
        guard let position = rowByKey["\(volumeId)/\(documentId)"] else { return 0 }
        return targets[position].footnoteSources
    }

    private static func key(volume: Int, document: Int, volumes: [String],
                            documents: [[String]]) -> String? {
        guard volumes.indices.contains(volume),
              documents.indices.contains(volume),
              documents[volume].indices.contains(document) else { return nil }
        return "\(volumes[volume])/\(documents[volume][document])"
    }
}

// MARK: - ResolvedEdgeIndexStore

/// Loads and caches the bundled `resolved-edge-index.json`.
///
/// `shared` is `nil` only when the resource is missing or cannot be decoded. Consumers must treat
/// that as "corpus-wide citations are unavailable" and fall back to the local table — never as
/// "nothing else cites this document".
///
/// Version history:
///   1.0 — Session 2026-08-09: #262
enum ResolvedEdgeIndexStore {

    /// The bundled index, or `nil` when unavailable.
    static let shared: ResolvedEdgeIndex? = load()

    private static func load() -> ResolvedEdgeIndex? {
        guard let url = Bundle.main.url(forResource: "resolved-edge-index",
                                        withExtension: "json") else {
            #if DEBUG
            print("[CrossReference] ResolvedEdgeIndexStore: resolved-edge-index.json not found.")
            #endif
            return nil
        }
        do {
            return try JSONDecoder().decode(ResolvedEdgeIndex.self, from: try Data(contentsOf: url))
        } catch {
            #if DEBUG
            print("[CrossReference] ResolvedEdgeIndexStore: decode failed — \(error)")
            #endif
            return nil
        }
    }
}
