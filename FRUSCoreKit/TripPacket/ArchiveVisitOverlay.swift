// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

// MARK: - ArchiveVisitOverlay

/// A plan's stored per-target state, joined onto a derived ``TripPacketModel`` at render time
/// (Archive-Visit-Plan-Design §2a): tier assignments, exclusions, notes, and the stored-row
/// accounting the coverage report owes.
///
/// A value type the exporter and the editor both read, so the artifact and the screen cannot
/// apply a plan's state differently. The model itself stays a pure derivation from the seeds —
/// state is an overlay HERE, never merged into the model, which is what lets an untouched
/// target keep deriving correctly as volumes index.
///
/// Version history:
///   1.0 — Archive Visits Phase 3: initial implementation
///   1.1 — #1421 review: ``storedKeys`` — a stored row whose key the re-index re-spelled answers
///          for the target it was minted for, and the editor writes through it
///   1.2 — decision 62 (A15): ``superseded`` — a stored row that answers for a target another
///          stored row is shown on, kept and listed with its own tier, note and exclusion
///   1.3 — 2026-11-23 (FRUS Explorer Light, S30a): moved into FRUSCoreKit, public, out of
///          `ArchiveVisitDerivation.swift`, with the exporter that reads it; unchanged
public struct ArchiveVisitOverlay: Equatable, Sendable {

    /// A stored row that answers for a derived target another stored row is shown on (decision
    /// 62): two targets the reader had set became one, or a row re-spelled beside one minted on the
    /// new spelling. Its tier and note are kept under its own key, in ``tierAssignments`` and
    /// ``notes``, and none of its state is applied to the target.
    public struct Superseded: Equatable, Sendable {
        /// The derived target it answers for.
        public let targetKey: String
        /// Whether the row excludes its target from the packet — not applied, since the target
        /// follows the row it shows.
        public let excluded: Bool
    }

    /// The plan's tiers, in order. Empty for a plan that never prioritized.
    public var tiers: [ArchiveVisitTier] = []
    /// `targetKey` → assigned tier id. A key absent here — or assigned a tier id no longer in
    /// ``tiers`` — is Unprioritized, which always sorts last.
    public var tierAssignments: [String: UUID] = [:]
    /// Target keys the user excluded from the rendered packet.
    public var excludedKeys: Set<String> = []
    /// `targetKey` → the researcher's note.
    public var notes: [String: String] = [:]
    /// How many state rows the plan stores in all.
    public var storedKeyCount: Int = 0
    /// Stored keys that no longer derive from the current seeds — kept with their tier and
    /// notes, disclosed by the coverage report, never deleted (the owner's orphan decision).
    public var orphanKeys: [String] = []
    /// Derived target key → the key its stored row was minted under, where the two differ
    /// (#1421 review). A row minted before a re-index that only removed spaces from the note it
    /// was keyed on answers for the target it was minted for (`ArchiveVisitTargetKeys`); its own
    /// key is left exactly as it was, so a device still on the older index keeps finding it.
    public var storedKeys: [String: String] = [:]
    /// The stored rows that answer for a target another stored row is shown on, by their own
    /// stored key (decision 62): kept, listed under Stored targets with the orphans, never deleted,
    /// and written there by their own key. Which row a target shows is
    /// `ArchiveVisitTargetKeys.shownRow(among:answeringFor:)`'s rule.
    public var superseded: [String: Superseded] = [:]

    /// The key the stored row for derived target `key` carries: its ``storedKeys`` entry, or
    /// `key` itself. What a write passes to `ArchiveVisitPlan.targetState(forKey:resolvedBy:mintIfMissing:in:)`.
    public func storedKey(for key: String) -> String {
        storedKeys[key] ?? key
    }

    /// The tier a target key resolves to, or `nil` for Unprioritized (including a dangling
    /// tier id, which reads as Unprioritized — degraded, never crashed).
    public func tier(for key: String) -> ArchiveVisitTier? {
        guard let tierId = tierAssignments[key] else { return nil }
        return tiers.first { $0.id == tierId }
    }

    /// The tier's sort position for a target key — its index in ``tiers``, or `Int.max` for
    /// Unprioritized, so the implicit group always sorts last.
    public func tierOrderIndex(for key: String) -> Int {
        guard let tier = tier(for: key),
              let index = tiers.firstIndex(of: tier) else { return Int.max }
        return index
    }

    /// The display name for a tier — its label, or the positional fallback the 1c artboard
    /// specifies ("An unlabeled tier reads 'Priority 1'").
    public func displayName(for tier: ArchiveVisitTier) -> String {
        if let label = tier.label, !label.isEmpty { return label }
        let position = (tiers.firstIndex(of: tier) ?? 0) + 1
        return String(format: String(localized: "archiveVisit.tier.unnamed %lld",
                                     defaultValue: "Priority %lld"), Int64(position))
    }
}
