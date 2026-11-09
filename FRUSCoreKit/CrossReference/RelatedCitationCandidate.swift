// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

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
///   1.1 — 2026-11-08: FRUS Explorer Light's S23a — moved unchanged into FRUSCoreKit from the
///          app's `CrossReferenceModels.swift`, since the kit's `RelatedCitationSource` returns it
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
