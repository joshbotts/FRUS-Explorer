// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - HubCopy

/// Count-agreeing copy fragments for the Volumes & Storage hub (S-2).
///
/// The app ships no String Catalog, so the `^[…](inflect: true)` agreement markup that would
/// normally handle this does nothing. A two-form choice is the honest substitute: a single
/// `"\(n) volumes"` string is wrong for the commonest count there is.
///
/// Version history:
///   1.0 — S-2b: initial implementation, private to the macOS hub
///   1.1 — S-2c: lifted here so the iOS hub says the same thing
enum HubCopy {

    /// "1 volume" / "N volumes".
    static func volumes(_ count: Int) -> String {
        count == 1
            ? String(localized: "settings.hub.count.volume.one", defaultValue: "1 volume")
            : String(format: String(localized: "settings.hub.count.volume.many %lld",
                                    defaultValue: "%lld volumes"), Int64(count))
    }

    /// "1 subseries" / "N subseries" — the noun is invariant, the article is not.
    static func subseries(_ count: Int) -> String {
        count == 1
            ? String(localized: "settings.hub.count.subseries.one", defaultValue: "1 subseries")
            : String(format: String(localized: "settings.hub.count.subseries.many %lld",
                                    defaultValue: "%lld subseries"), Int64(count))
    }
}

// MARK: - StorageRemovalPlan

/// Which downloaded volumes Free Up Space may offer, in the order it offers them (S-2).
///
/// Pure value type with no SwiftUI in it, so the two things that decide whether this feature is
/// safe — *which* volumes are eligible and *how much* removing them recovers — are unit-testable
/// rather than buried in a sheet body. Both platforms' sheets render this.
///
/// ## The protection rule
/// A volume carrying user data (a research note, a collection entry, a generated summary) is not a
/// candidate at all — not merely sorted last. Removing it would strand that work against a volume
/// no longer on the device, so the sheet never offers it and the user must delete it deliberately
/// from the full volume list.
///
/// ## The ordering
/// Never-opened volumes first, then least-recently-opened, then by identifier. That puts the
/// volumes a reader has demonstrably never needed at the top of a list they are skimming to free
/// space.
///
/// Version history:
///   1.0 — S-2c: extracted from the macOS Manage Storage sheet so the iOS port shares the rules
///   1.1 — Session 2026-08-09 (#777): `redownloadableVolumeIds` — a volume the app cannot fetch
///          again is never offered for removal. Free Up Space exists to reclaim space that costs
///          only a download to restore; a side-loaded volume costs the user their only copy.
struct StorageRemovalPlan: Equatable, Sendable {

    /// One removable volume.
    struct Candidate: Equatable, Sendable, Identifiable {
        /// The volume identifier.
        let volumeId: String
        /// Size of the XML file on disk.
        let volumeFileBytes: Int
        /// When the volume was last opened, or `nil` if never.
        let lastOpened: Date?

        var id: String { volumeId }

        /// XML plus its estimated search-index contribution.
        ///
        /// The index factor is `StorageReport.indexOverheadFactor` (2.8×), the cross-platform mean
        /// measured against a full 552-volume download. Always present this prefixed with "~".
        var estimatedBytes: Int {
            volumeFileBytes + Int(Double(volumeFileBytes) * StorageReport.indexOverheadFactor)
        }
    }

    /// The removable volumes, in the order the sheet lists them.
    let candidates: [Candidate]

    /// Whether there is anything to offer.
    var isEmpty: Bool { candidates.isEmpty }

    /// Builds the plan from a storage report and the two user-data snapshots.
    ///
    /// - Parameters:
    ///   - entries: Every downloaded volume, from `StorageReport.perVolume`.
    ///   - protectedVolumeIds: Volumes carrying notes, collections, or summaries. Excluded outright.
    ///   - redownloadableVolumeIds: Volumes the app can fetch again — the catalogue ids. Anything
    ///     else is **side-loaded**: the app's copy is the user's only copy, and it is written with
    ///     `isExcludedFromBackupKey`, so it is in no iCloud Backup or Time Machine either. Removing
    ///     one is irreversible, so it is never a candidate. Passing an empty set therefore offers
    ///     nothing, which is the safe direction for a caller that has not loaded its catalogue yet.
    ///   - lastOpenedByVolumeId: Most recent reading-history timestamp per volume.
    ///
    /// The exclusion matters more than it looks: candidates are sorted **never-opened first**, and
    /// a freshly side-loaded volume is by definition never opened and carries no notes — so before
    /// this guard it was not merely offered, it was the top suggestion, under a confirmation
    /// promising it "can be downloaded again" (#777).
    static func make(entries: [VolumeStorageEntry],
                     protectedVolumeIds: Set<String>,
                     redownloadableVolumeIds: Set<String>,
                     lastOpenedByVolumeId: [String: Date]) -> StorageRemovalPlan {
        let candidates = entries
            .filter { !protectedVolumeIds.contains($0.volumeId) }
            .filter { redownloadableVolumeIds.contains($0.volumeId) }
            .map { entry in
                Candidate(volumeId: entry.volumeId,
                          volumeFileBytes: entry.volumeFileBytes,
                          lastOpened: lastOpenedByVolumeId[entry.volumeId])
            }
            .sorted { a, b in
                switch (a.lastOpened, b.lastOpened) {
                case (nil, nil):        return a.volumeId < b.volumeId
                case (nil, _):          return true    // never opened → most removable
                case (_, nil):          return false
                case (let la?, let lb?):
                    // Oldest first; identifier breaks an exact tie so the order is stable.
                    return la == lb ? a.volumeId < b.volumeId : la < lb
                }
            }
        return StorageRemovalPlan(candidates: candidates)
    }

    /// Estimated bytes recovered by removing `selection`.
    ///
    /// Identifiers that are not candidates contribute nothing — a stale selection left over from a
    /// refresh must not inflate the figure.
    func estimatedRecovery(for selection: Set<String>) -> Int {
        candidates
            .filter { selection.contains($0.volumeId) }
            .reduce(0) { $0 + $1.estimatedBytes }
    }
}
