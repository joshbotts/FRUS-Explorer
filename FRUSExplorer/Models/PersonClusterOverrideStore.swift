// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - PersonClusterOverrideStore

/// SwiftData mutations and snapshots for `PersonClusterOverride` records (Phase 3).
///
/// Mirrors the `ProjectAdminService` pattern: a `@MainActor` namespace of static helpers that
/// create, remove, and read the user's person-cluster corrections. The pipeline never touches
/// SwiftData directly — `snapshot(context:)` hands it `Sendable` `PersonClusterOverrideData` values
/// to apply as clustering constraints during consolidation.
///
/// Version history:
///   1.0 — Person rollup Phase 3: initial implementation
@MainActor
enum PersonClusterOverrideStore {

    /// Records that two members are the same person (a must-link merge), unless an equivalent
    /// override already exists. Returns the created override, or `nil` when it was a duplicate
    /// or a self-merge.
    @discardableResult
    static func merge(_ a: (volumeId: String, ref: String),
                      _ b: (volumeId: String, ref: String),
                      context: ModelContext) -> PersonClusterOverride? {
        guard a.volumeId != b.volumeId || a.ref != b.ref else { return nil }
        let existing = fetchAll(context: context)
        let duplicate = existing.contains { o in
            o.overrideKind == .merge && (
                (o.volumeIdA == a.volumeId && o.refA == a.ref && o.volumeIdB == b.volumeId && o.refB == b.ref) ||
                (o.volumeIdA == b.volumeId && o.refA == b.ref && o.volumeIdB == a.volumeId && o.refB == a.ref)
            )
        }
        guard !duplicate else { return nil }
        let override = PersonClusterOverride(kind: .merge,
                                             volumeIdA: a.volumeId, refA: a.ref,
                                             volumeIdB: b.volumeId, refB: b.ref)
        context.insert(override)
        return override
    }

    /// Records that a member is a different person (a detach split), unless one already exists for
    /// that member. Returns the created override, or `nil` when it was a duplicate.
    @discardableResult
    static func split(_ member: (volumeId: String, ref: String),
                      context: ModelContext) -> PersonClusterOverride? {
        let existing = fetchAll(context: context)
        let duplicate = existing.contains {
            $0.overrideKind == .split && $0.volumeIdA == member.volumeId && $0.refA == member.ref
        }
        guard !duplicate else { return nil }
        let override = PersonClusterOverride(kind: .split, volumeIdA: member.volumeId, refA: member.ref)
        context.insert(override)
        return override
    }

    /// Deletes an override (e.g. "unmerge" / "rejoin").
    static func remove(_ override: PersonClusterOverride, context: ModelContext) {
        context.delete(override)
    }

    /// All overrides, newest first.
    static func fetchAll(context: ModelContext) -> [PersonClusterOverride] {
        let descriptor = FetchDescriptor<PersonClusterOverride>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    /// `Sendable` snapshots of all overrides, for passing into the `IndexingPipeline` actor.
    static func snapshot(context: ModelContext) -> [PersonClusterOverrideData] {
        fetchAll(context: context).compactMap(\.snapshot)
    }
}
