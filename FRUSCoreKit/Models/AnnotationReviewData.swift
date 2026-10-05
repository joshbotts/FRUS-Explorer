// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - AnnotationReviewData

/// The `Sendable` value form of a review row — what crosses into the pipeline actor.
///
/// Carries only what the reconcile's SQL binds. `public` because the pipeline's entry point is.
public struct AnnotationReviewData: Equatable, Sendable, Hashable {
    /// The raw kind, so the actor can filter without knowing the enum.
    public let annotationType: String
    /// The volume half of the anchor.
    public let volumeId: String
    /// The document half.
    public let documentId: String
    /// The content hash the reader dispositioned.
    public let contentHash: String
    /// The change kind the reader dispositioned, or `nil`.
    public let changeKind: String?

    /// Memberwise, spelled out because `public` suppresses the synthesized one.
    public init(annotationType: String, volumeId: String, documentId: String,
                contentHash: String, changeKind: String?) {
        self.annotationType = annotationType
        self.volumeId = volumeId
        self.documentId = documentId
        self.contentHash = contentHash
        self.changeKind = changeKind
    }
}
