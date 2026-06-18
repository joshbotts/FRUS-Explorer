// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

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

// MARK: - PersonClusterOverride

/// A user correction to the algorithmic person rollup (Phase 3), synced via CloudKit.
///
/// The People browser's clusters are computed by `PersonClusterer` and materialised in the
/// rebuildable aux SQLite (`person_rollup`). Those clusters are keyed by ephemeral ids that change
/// on every rebuild, so user corrections cannot reference them — they anchor on the **stable**
/// `(volumeId, ref)` member keys from the TEI data. Consolidation reads the current overrides and
/// applies them as constraints (`merge` = must-link, `split` = detach) when building the rollup, so
/// the entire read path (counts, search, drill-in) keeps working unchanged.
///
/// ## CloudKit compatibility
/// - All stored properties have default values.
/// - No `@Relationship` declarations.
/// - Anchors are plain strings, mirroring `DocumentTagAssignment`.
///
/// > Whenever a model type is added to `ModelContainer.frusModelTypes`, the CloudKit schema must be
/// > deployed to Production before shipping (see the schema note in `ModelContainer+FRUS`).
///
/// Version history:
///   1.0 — Person rollup Phase 3: initial implementation
@Model final class PersonClusterOverride {

    // MARK: - Identity

    var id: UUID = UUID()

    /// The correction kind, persisted as the raw value of `PersonClusterOverrideKind`.
    var kind: String = ""

    // MARK: - Anchors

    /// Volume of the primary anchored member (the member acted on; for a split, the one to detach).
    var volumeIdA: String = ""
    /// Per-volume TEI `ref` of the primary anchored member.
    var refA: String = ""
    /// Volume of the secondary anchored member — set for a merge, `nil` for a split.
    var volumeIdB: String? = nil
    /// Per-volume TEI `ref` of the secondary anchored member — set for a merge, `nil` for a split.
    var refB: String? = nil

    // MARK: - Timestamps

    /// Optional for CloudKit schema compatibility — always non-nil in practice.
    var createdAt: Date? = nil

    // MARK: - Initialiser

    init(kind: PersonClusterOverrideKind, volumeIdA: String, refA: String,
         volumeIdB: String? = nil, refB: String? = nil) {
        self.id = UUID()
        self.kind = kind.rawValue
        self.volumeIdA = volumeIdA
        self.refA = refA
        self.volumeIdB = volumeIdB
        self.refB = refB
        self.createdAt = .now

        #if DEBUG
        print("[SwiftData] PersonClusterOverride created: \(kind.rawValue) \(volumeIdA)/\(refA)"
            + (volumeIdB.map { " ↔︎ \($0)/\(refB ?? "?")" } ?? ""))
        #endif
    }

    // MARK: - Derived

    /// The typed correction kind, or `nil` if the stored raw value is unrecognised.
    var overrideKind: PersonClusterOverrideKind? { PersonClusterOverrideKind(rawValue: kind) }

    /// A `Sendable` snapshot for passing into the `IndexingPipeline` actor.
    var snapshot: PersonClusterOverrideData? {
        guard let k = overrideKind else { return nil }
        return PersonClusterOverrideData(kind: k, volumeIdA: volumeIdA, refA: refA,
                                         volumeIdB: volumeIdB, refB: refB)
    }
}
