// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - DocumentClassificationOverrideData

/// The `Sendable` value form of an override, for the SwiftData → pipeline-actor crossing.
/// `public` because `IndexingPipeline`'s (public) apply entry point takes it.
public struct DocumentClassificationOverrideData: Equatable, Sendable {
    /// The document's volume — half of the stable anchor.
    public let volumeId: String
    /// The document's id within it — the other half.
    public let documentId: String
    /// The user's classification assertion.
    public let isEditorialNote: Bool
    /// The TEI's own value at override time — the restore value.
    public let parsedIsEditorialNote: Bool

    /// Memberwise, spelled out because `public` suppresses the synthesized one.
    public init(volumeId: String, documentId: String,
                isEditorialNote: Bool, parsedIsEditorialNote: Bool) {
        self.volumeId = volumeId
        self.documentId = documentId
        self.isEditorialNote = isEditorialNote
        self.parsedIsEditorialNote = parsedIsEditorialNote
    }
}
