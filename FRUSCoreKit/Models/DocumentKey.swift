// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - DocumentKey

/// A corpus-unique identity for one FRUS document: its `volumeId` plus volume-local
/// `documentId` (the TEI `xml:id`, e.g. `"d42"`).
///
/// The corpus historically speaks three incompatible document-key idioms — a bare
/// `(volumeId, documentId)` tuple (`PersonMentionStore`, `documentKeys(forRollupId:)`),
/// a slash-joined `"volumeId/documentId"` string (`RelatedDocument.compositeKey`,
/// `documentKeysInDateRange`, every `CrossReferenceStore` node key), and the
/// Analytics-confined `WordCloudDocumentKey`. None is `Hashable + Codable` in a neutral
/// location, which the #308 find-related model needs: its scorers return
/// `[DocumentKey: Double]` (a tuple can't be a dictionary key) and its request rides a
/// `Codable` window payload. This is that one shared value type; helpers convert to the
/// legacy string / tuple idioms only at the API boundary.
///
/// `documentId` is volume-local — `"d12"` recurs in nearly every volume — so a bare
/// document id is never a safe identity across volumes; always carry the pair.
///
/// Version history:
///   1.0 — #308 Phase 2: introduced for the multi-axis find-related model
struct DocumentKey: Hashable, Sendable, Codable {

    /// The volume identifier (e.g. `"frus1969-76v01"`).
    let volumeId: String
    /// The volume-local document identifier — the TEI `xml:id` (e.g. `"d42"`).
    let documentId: String

    /// Creates a key from its two components.
    init(volumeId: String, documentId: String) {
        self.volumeId = volumeId
        self.documentId = documentId
    }

    /// Positional convenience initializer for call sites mapping row tuples.
    init(_ volumeId: String, _ documentId: String) {
        self.init(volumeId: volumeId, documentId: documentId)
    }

    /// The slash-joined `"volumeId/documentId"` form used by `RelatedDocument.compositeKey`,
    /// `documentKeysInDateRange`, and the cross-reference node keys — the boundary idiom for
    /// the app's string-keyed batch APIs.
    var compositeString: String { "\(volumeId)/\(documentId)" }

    /// Parses a slash-joined `"volumeId/documentId"` string back into a key. Splits on the
    /// **first** `/` (neither volume ids nor document ids contain `/`); returns `nil` for a
    /// missing separator or an empty component.
    init?(compositeString: String) {
        guard let slash = compositeString.firstIndex(of: "/") else { return nil }
        let volume = String(compositeString[..<slash])
        let document = String(compositeString[compositeString.index(after: slash)...])
        guard !volume.isEmpty, !document.isEmpty else { return nil }
        self.init(volumeId: volume, documentId: document)
    }

    /// The labelled `(volumeId:documentId:)` tuple form the `PersonMentionStore` /
    /// `IndexingPipeline` batch APIs accept.
    var tuple: (volumeId: String, documentId: String) { (volumeId, documentId) }
}
