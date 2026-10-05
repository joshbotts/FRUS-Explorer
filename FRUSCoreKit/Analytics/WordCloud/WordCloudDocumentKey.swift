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
