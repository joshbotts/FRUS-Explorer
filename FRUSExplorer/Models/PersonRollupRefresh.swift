// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - PersonRollupRefresh

/// The one place the materialised person rollup is rebuilt, and the one place that says so (#747).
///
/// ## Why a choke point
/// `person_rollup` is regenerated wholesale — `DELETE FROM person_rollup` then one row per cluster
/// at `rollup_id = clusterIndex + 1` — so **every rebuild renumbers essentially every cluster
/// after the first membership change**. Anything holding a bare rollup id across a rebuild is
/// pointing at a slot, not a person.
///
/// Before this type the rebuild had three unrelated triggers and the "it changed" signal was
/// raised by *neither of them*: two view files incremented `AppState.personRollupGeneration`
/// by hand after calling the store, so a third correction site — or the volume-change and launch
/// paths, which never raised it at all — left every other surface holding stale ids with no way to
/// know. Routing every rebuild through here means the signal cannot be forgotten, because raising
/// it is not a separate step.
///
/// ## What still has to be true at the call sites
/// This publishes *that* the rollup changed. Re-resolving a held id is the holder's job, through
/// ``SearchParameters/reresolvedPerson(using:)`` or an equivalent anchor lookup — a generation
/// bump that nobody observes is the same defect one layer up.
///
/// Version history:
///   1.0 — Session 2026-08-08: #747
@MainActor
enum PersonRollupRefresh {

    /// Rebuilds the rollup from the current corrections and publishes the change.
    ///
    /// - Parameters:
    ///   - context: main-actor context holding the (already-mutated) overrides.
    ///   - pipeline: owner of the materialised rollup.
    ///   - appState: bumped once the rebuild has actually completed, never before — an early bump
    ///     would have observers re-resolve against the *old* table and cache the answer they were
    ///     refreshing to escape.
    static func afterCorrection(context: ModelContext,
                                pipeline: IndexingPipeline,
                                appState: AppState) async {
        // Delegates rather than reimplements: the store owns the save + snapshot + consolidate
        // sequence and its `forceReload: false` reasoning. This adds only the signal.
        await PersonClusterOverrideStore.saveAndReconsolidate(context: context, pipeline: pipeline)
        appState.personRollupGeneration += 1
    }

    /// Rebuilds the rollup after the indexed corpus changed, and publishes the change.
    ///
    /// Volume add/remove never rebuilt the rollup at all (#747 / audit M-14): `removeVolume`
    /// deletes `persons` and `person_mentions` rows but leaves `person_rollup` and
    /// `person_rollup_member` alone, and `refreshReadOnlyStores` only reopens connections — it
    /// does not recompute data. The People browser therefore kept listing people whose only
    /// mentions were in a removed volume, with their old counts, until the next launch's
    /// count-drift check finally noticed. Newly indexed volumes were the mirror image: their
    /// people were invisible until relaunch.
    ///
    /// Uses the same drift check the launch path relies on (`members != persons`), not an
    /// unconditional rebuild, so this is safe to call from *every* corpus-touching action —
    /// including the ones that only VACUUM — and cheap (two `COUNT(*)`s) when nothing moved. That
    /// matters more than the saved work: a rule that is cheap enough to apply everywhere cannot be
    /// forgotten at the one site that needed it, which is how the defect arose.
    ///
    /// The overrides must be the **real** ones. Passing `[]` would not merely skip the user's
    /// corrections — the fingerprint mismatch would trigger a rebuild that *discards* them.
    ///
    /// - Returns: `true` if the rollup was rebuilt, and the generation therefore published.
    @discardableResult
    static func afterCorpusChange(context: ModelContext?,
                                  pipeline: IndexingPipeline,
                                  appState: AppState) async -> Bool {
        let overrides = context.map { PersonClusterOverrideStore.snapshot(context: $0) } ?? []
        let rebuilt = (try? await pipeline.consolidatePersonRollupIfNeeded(overrides: overrides)) ?? false
        if rebuilt { appState.personRollupGeneration += 1 }
        return rebuilt
    }

    /// Publishes a rebuild that another path already performed (the launch branches, which
    /// consolidate before `AppState` has observers).
    static func published(appState: AppState) {
        appState.personRollupGeneration += 1
    }
}

// MARK: - The person filter's identity

/// The three fields that together say "this search is filtered to a person" (#747).
///
/// Kept as one value because they only make sense together and the two search view models hold
/// them as three loose properties each. Bundling them means the rebind rule below is written once
/// rather than four times, which is the shape the audit found missing: `personRollupId` alone is a
/// slot number, and a slot number without its anchor cannot survive a rollup rebuild.
struct PersonFilterBinding: Equatable, Sendable {

    /// The current `person_rollup.rollup_id`. `nil` means no person filter.
    var rollupId: Int?

    /// The name shown in the filter chip.
    var label: String?

    /// The durable `(volumeId, ref)` this filter really means. `nil` before first capture.
    var anchor: PersonRollupAnchor?

    /// Creates a binding.
    init(rollupId: Int? = nil, label: String? = nil, anchor: PersonRollupAnchor? = nil) {
        self.rollupId = rollupId
        self.label = label
        self.anchor = anchor
    }
}

// MARK: - Re-resolution

extension PersonRollupRefresh {

    /// Re-points a person filter at whoever it *actually* names, after any rollup rebuild (#747).
    ///
    /// This is the pure core, taking its two lookups as closures so it can be exercised without a
    /// database — the store adapter below is the only thing that touches SQLite.
    ///
    /// Three outcomes:
    ///
    /// - **no filter** → returned unchanged, and any stale anchor is cleared so it cannot be
    ///   mistaken for a live one later;
    /// - **filter with no anchor yet** → the anchor is *captured* from the rollup's representative
    ///   member. Capture happens here rather than at the six sites that set a rollup id because
    ///   `PersonIndexEntry.entry.ref` is empty for rollup-sourced entries: the producers genuinely
    ///   do not have the anchor, only the store does;
    /// - **filter with an anchor** → the anchor is re-resolved. If it still names a cluster the id
    ///   (and label) are updated, so a filter set before a merge follows the person into the merged
    ///   identity. If it no longer resolves — its volume was removed — the filter is **dropped**,
    ///   because the alternative is quietly searching an integer that now selects a different human.
    ///
    /// - Returns: the updated binding and whether the filter was dropped, so the caller can tell the
    ///   user rather than silently changing their result set.
    /// Deliberately `nonisolated`: the pure core touches no shared state, and
    /// ``SearchParameters/reresolvedPerson(using:)`` — which `SearchParameters` exposes to
    /// non-main-actor callers — has to be able to reach it.
    nonisolated static func rebind(
        _ binding: PersonFilterBinding,
        anchorFor: (Int) -> PersonRollupAnchor?,
        entryFor: (PersonRollupAnchor) -> PersonIndexEntry?
    ) -> (binding: PersonFilterBinding, droppedPersonFilter: Bool) {
        var updated = binding
        guard let rollupId = binding.rollupId else {
            updated.anchor = nil
            return (updated, false)
        }
        guard let anchor = binding.anchor else {
            updated.anchor = anchorFor(rollupId)
            return (updated, false)
        }
        guard let entry = entryFor(anchor), let current = entry.rollupId else {
            updated.rollupId = nil
            updated.label = nil
            updated.anchor = nil
            return (updated, true)
        }
        updated.rollupId = current
        // The canonical name can change too — a merge adopts the authority's preferred spelling —
        // and a chip that keeps the pre-merge label misdescribes what it is now filtering to.
        updated.label = entry.entry.name
        return (updated, false)
    }

    /// ``rebind(_:anchorFor:entryFor:)`` against the live read-only person store.
    ///
    /// A `nil` store (the read-only connections are closed during a reindex) is a no-op rather than
    /// a drop: "I cannot look this up right now" is not "this person is gone", and dropping the
    /// user's filter on a transient outage would be worse than the defect being fixed.
    static func rebind(_ binding: PersonFilterBinding,
                       using store: PersonMentionStore?) async
        -> (binding: PersonFilterBinding, droppedPersonFilter: Bool) {
        guard let store, let rollupId = binding.rollupId else {
            // No store, or no filter: `rebind` still runs for the no-filter case so a stale anchor
            // is cleared, but it must not be handed lookups it would then be asked to trust.
            return store == nil ? (binding, false)
                                : rebind(binding, anchorFor: { _ in nil }, entryFor: { _ in nil })
        }

        // Exactly one of the two lookups is needed, and which one is what `rebind` decides. Both
        // are resolved up front (each `nil` unless its branch applies) so the pure core stays
        // synchronous — an `async` closure parameter would make it untestable without a database.
        var capturedAnchor: PersonRollupAnchor?
        var resolvedEntry: PersonIndexEntry?
        if let existing = binding.anchor {
            resolvedEntry = try? await store.rollupEntry(forVolumeId: existing.volumeId,
                                                         ref: existing.ref)
        } else if let member = try? await store.representativeMember(forRollupId: rollupId) {
            capturedAnchor = PersonRollupAnchor(volumeId: member.volumeId, ref: member.ref)
        }
        return rebind(binding,
                      anchorFor: { _ in capturedAnchor },
                      entryFor: { _ in resolvedEntry })
    }
}

// MARK: - SearchParameters

extension SearchParameters {

    /// The person filter, re-pointed at whoever the anchor names *now* (#747).
    ///
    /// The stored-query path — a `SavedSearch` or a trail entry restored long after the rollup it
    /// was captured against was renumbered. Delegates to
    /// ``PersonRollupRefresh/rebind(_:anchorFor:entryFor:)`` so a restored query and a live filter
    /// chip cannot disagree about what re-resolution means.
    func reresolvedPerson(
        using resolve: (PersonRollupAnchor) -> PersonIndexEntry?
    ) -> (parameters: SearchParameters, droppedPersonFilter: Bool) {
        let (rebound, dropped) = PersonRollupRefresh.rebind(
            PersonFilterBinding(rollupId: personRollupId, label: personLabel, anchor: personAnchor),
            anchorFor: { _ in nil },   // a stored query cannot capture; it can only re-resolve
            entryFor: resolve)
        var updated = self
        updated.personRollupId = rebound.rollupId
        updated.personLabel = rebound.label
        updated.personAnchor = rebound.anchor
        return (updated, dropped)
    }
}
