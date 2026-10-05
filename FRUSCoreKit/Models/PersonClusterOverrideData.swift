// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - PersonClusterOverrideKind

/// The two kinds of user correction applied over the algorithmic person rollup.
public enum PersonClusterOverrideKind: String, Sendable {
    /// "These two records are the same person." A must-link constraint that unions the algorithmic
    /// clusters containing the two anchored members, even across surname/era blocks.
    case merge
    /// "This record is a different person." A detach constraint that pulls the anchored member out
    /// of whatever cluster it landed in, into its own identity.
    case split
}

// MARK: - PersonClusterOverrideData

/// A `Sendable` snapshot of a `PersonClusterOverride`, passed from the (MainActor) SwiftData layer
/// into the `IndexingPipeline` actor so consolidation can apply user corrections as clustering
/// constraints without touching the managed object.
public struct PersonClusterOverrideData: Sendable, Equatable {
    /// Whether this is a merge (must-link) or split (detach) correction.
    public let kind: PersonClusterOverrideKind
    /// Primary anchored member (the member acted on; for a split, the member to detach).
    public let volumeIdA: String
    public let refA: String
    /// Secondary anchored member — present for a merge, `nil` for a split.
    public let volumeIdB: String?
    public let refB: String?

    public init(kind: PersonClusterOverrideKind, volumeIdA: String, refA: String,
                volumeIdB: String? = nil, refB: String? = nil) {
        self.kind = kind
        self.volumeIdA = volumeIdA
        self.refA = refA
        self.volumeIdB = volumeIdB
        self.refB = refB
    }
}
