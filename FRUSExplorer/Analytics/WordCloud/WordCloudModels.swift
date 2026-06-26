// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - WordCloudDocumentKey

/// A composite document identity (`volumeId` + `documentId`) used to address a
/// single FRUS document when resolving a `WordCloudScope` into the set of
/// documents whose text feeds a word cloud.
///
/// Version history:
///   1.0 — Word Cloud feature: initial implementation
struct WordCloudDocumentKey: Hashable, Sendable {
    /// FRUS volume identifier (e.g. `"frus1969-76v01"`).
    let volumeId: String
    /// Document identifier within the volume (e.g. `"d42"`).
    let documentId: String

    /// Creates a document key.
    /// - Parameters:
    ///   - volumeId: The FRUS volume identifier.
    ///   - documentId: The document identifier within the volume.
    init(volumeId: String, documentId: String) {
        self.volumeId = volumeId
        self.documentId = documentId
    }
}

// MARK: - WordCloudScope

/// Identifies a body of FRUS material to compute a word cloud over.
///
/// Every case ultimately resolves to a set of `WordCloudDocumentKey` values (or,
/// for `.corpus`, the entire index), which `WordFrequencyService` turns into a
/// ranked list of the most frequent meaningful terms. Resolution of the
/// SwiftData-backed cases (`.collection`, `.userTag`, `.savedSearch`) happens on
/// the main actor in `WordCloudScopeResolver`, which has access to the model
/// context; the FTS-backed cases are resolved inside the service.
///
/// Version history:
///   1.0 — Word Cloud feature: initial implementation
enum WordCloudScope: Hashable, Sendable, Identifiable {
    /// A single document.
    case document(volumeId: String, documentId: String)
    /// Every document in a single volume.
    case volume(volumeId: String)
    /// Every document across the volumes of a FRUS subseries.
    case subseries(subseriesId: String)
    /// The entire indexed corpus.
    case corpus
    /// Every document in a user-created collection.
    case collection(id: UUID)
    /// Every document tagged with a user tag.
    case userTag(id: UUID)
    /// Every document matching a saved search.
    case savedSearch(id: UUID)

    /// Identity for SwiftUI presentation (`.sheet(item:)`); equals `signature`.
    var id: String { signature }

    /// Reconstructs a scope from its `signature` (the inverse of `signature`).
    ///
    /// Used to drain the background precompute queue, which persists scopes as
    /// their signature strings. Returns `nil` for an unrecognised or malformed
    /// signature.
    init?(signature: String) {
        if signature == "corpus" { self = .corpus; return }
        guard let colon = signature.firstIndex(of: ":") else { return nil }
        let prefix = String(signature[..<colon])
        let value = String(signature[signature.index(after: colon)...])
        switch prefix {
        case "doc":
            guard let slash = value.firstIndex(of: "/") else { return nil }
            let volumeId = String(value[..<slash])
            let documentId = String(value[value.index(after: slash)...])
            self = .document(volumeId: volumeId, documentId: documentId)
        case "vol":
            self = .volume(volumeId: value)
        case "sub":
            self = .subseries(subseriesId: value)
        case "col":
            guard let uuid = UUID(uuidString: value) else { return nil }
            self = .collection(id: uuid)
        case "tag":
            guard let uuid = UUID(uuidString: value) else { return nil }
            self = .userTag(id: uuid)
        case "search":
            guard let uuid = UUID(uuidString: value) else { return nil }
            self = .savedSearch(id: uuid)
        default:
            return nil
        }
    }

    /// A stable string key identifying this scope, used to cache computed results.
    ///
    /// Distinct scopes always produce distinct signatures; the same scope always
    /// produces the same signature, so a cache keyed on it is correct across view
    /// re-creations.
    var signature: String {
        switch self {
        case let .document(volumeId, documentId): return "doc:\(volumeId)/\(documentId)"
        case let .volume(volumeId):               return "vol:\(volumeId)"
        case let .subseries(subseriesId):         return "sub:\(subseriesId)"
        case .corpus:                             return "corpus"
        case let .collection(id):                 return "col:\(id.uuidString)"
        case let .userTag(id):                    return "tag:\(id.uuidString)"
        case let .savedSearch(id):                return "search:\(id.uuidString)"
        }
    }
}

// MARK: - WordCloudResult

/// The computed output of a word cloud: the top terms plus the provenance counts
/// that contextualise them (how many documents and tokens were scanned).
///
/// Version history:
///   1.0 — Word Cloud feature: initial implementation
struct WordCloudResult: Sendable, Codable {
    /// The most frequent terms, sorted by descending count (ties broken
    /// alphabetically). Length is bounded by the requested limit.
    let terms: [TermCount]
    /// Number of documents whose text contributed to the counts.
    let documentCount: Int
    /// Total number of non-stopword tokens scanned across all documents.
    let totalTokenCount: Int

    /// An empty result (no documents in scope, or no surviving tokens).
    static let empty = WordCloudResult(terms: [], documentCount: 0, totalTokenCount: 0)
}
