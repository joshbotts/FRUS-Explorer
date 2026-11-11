// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - DocumentNodeKey

/// Stable identity of a document node in the citation graph: `(volumeId, documentId)`.
///
/// A FRUS document is uniquely identified by its volume plus its `xml:id`; the same
/// document number recurs across volumes, so the volume component is load-bearing.
/// Used by `CrossReferenceStore.resolvedCitationEdges()` and `PageRank`.
///
/// Version history:
///   1.0 — CA-6 (analytics CA-track): initial implementation
///   1.1 — 2026-11-10 (FRUS Explorer Light, S23b): moved into FRUSCoreKit, unchanged, in a file of
///          its own beside `CrossReferenceStore`; it was declared in `CrossReferenceStats.swift`
public struct DocumentNodeKey: Hashable, Sendable {
    /// The volume containing the document.
    public let volumeId: String
    /// The document's `xml:id` within its volume.
    public let documentId: String

    /// Creates a node key from its volume and document identifiers.
    public init(volumeId: String, documentId: String) {
        self.volumeId = volumeId
        self.documentId = documentId
    }
}
