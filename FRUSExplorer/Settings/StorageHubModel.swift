// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Observation

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

// MARK: - DownloadedVolumesListModel

/// What the full downloaded-volume list draws — *Volumes on This Device* on iOS, *Volumes on This
/// Mac* on macOS — held by the hub and read by the list it opens (#1356).
///
/// ## Why the list reads this and not copies
/// Before #1356 each hub handed its list `let` snapshots of the storage report and the index,
/// protected and last-opened sets, taken when the hub last rendered. A pushed destination (iOS) or
/// a sheet (macOS) holding copies changes only when a hub re-render reaches it. #1356 asked whether
/// one does, and on the simulators it does: against unfixed `v2`, a removed row left the pushed
/// list 1.1 s after the confirmation with nothing touched, on iPad Pro 13-inch at iOS 26.4 and at
/// iOS 27.0 (`VolumeRemovalTests.testRemovedRowLeavesTheListWithoutATouch`). The capture's
/// six-second row was not reproduced. The hub keeps the snapshots here anyway, one instance per
/// hub, so that the removal mark below and the rows it marks live in ONE observed object. The mark
/// clears only after the re-measured report has been assigned here, so no render can draw the row
/// unmarked from the stale report — which a mark in the list's own state, clearing while the rows
/// still waited on a hub re-render to reach the list, could not promise.
///
/// ## The removal routine lives here, not in either hub
/// The two hubs are hand-maintained twins and each carried its own copy of the removal routine.
/// ``removeVolumes(_:unindex:deleteFile:remeasure:)`` is the one both now call, so the in-progress
/// state below cannot exist on one platform and be missing from the other.
///
/// ## A removal in progress
/// A removal deletes the volume's index rows, then its file, then re-measures storage: a walk of
/// the volumes directory, a page-statistics read on the pipeline actor, four SwiftData fetches and
/// one index query per remaining volume. Before #1356 the row went on reading `indexed` through all
/// of it, and nothing on screen said a removal had started. Now:
/// - the volume is in ``removingVolumeIds`` from the moment the routine starts until the
///   re-measure has landed, and ``statusLine(for:)`` reads *removing…* in place of its index state
///   and last-opened date;
/// - it leaves ``indexedVolumeIds`` as soon as its index rows are deleted, not when the re-measure
///   recomputes the set, so nothing that reads the set — the hub's hero count included — claims
///   rows that no longer exist.
///
/// The row is MARKED, not dropped. A removal the re-measure does not confirm (the file could not be
/// deleted) brings the row back as it now is, and a list that had already dropped the row would
/// have no reason to draw it again.
///
/// ## Why the hub holds the removing set, not the list
/// The plan for #1356 put the set in the list's own `@State`. Held there, it is forgotten whenever
/// the list is closed and reopened mid-removal — Back then Show all on iOS, Done then Show All on
/// the Mac — and the reopened list draws the row as an ordinary one while its file is being
/// deleted. The hub outlives both.
///
/// Version history:
///   1.0 — #1356: initial implementation
@MainActor
@Observable
final class DownloadedVolumesListModel {

    /// The latest storage measurement, or `nil` until the first one completes.
    var report: StorageReport?
    /// Volumes present in the search index.
    var indexedVolumeIds: Set<String> = []
    /// Volumes carrying notes, collections, or summaries — marked, never auto-removed.
    var protectedVolumeIds: Set<String> = []
    /// Most recent reading-history timestamp per volume.
    var lastOpenedByVolumeId: [String: Date] = [:]
    /// The volume the hub is re-indexing from the list, if any.
    var reindexingVolumeId: String?
    /// Volumes whose removal has started and whose re-measure has not landed.
    private(set) var removingVolumeIds: Set<String> = []

    /// Creates an empty model; the hub fills it from its first storage measurement.
    init() {}

    /// Every downloaded volume, in the report's order (by volume id).
    var entries: [VolumeStorageEntry] { report?.perVolume ?? [] }

    /// What a row says about its volume's place in the search index.
    ///
    /// Version history:
    ///   1.0 — #1356: initial implementation
    enum IndexState: Equatable, Sendable {
        /// A removal has started and its re-measure has not landed.
        case removing
        /// The volume has rows in the search index.
        case indexed
        /// It has none.
        case notIndexed
    }

    /// Whether `volumeId`'s removal is under way.
    func isRemoving(_ volumeId: String) -> Bool {
        removingVolumeIds.contains(volumeId)
    }

    /// What `volumeId`'s row says about the index. A removal in progress outranks the index set.
    func indexState(of volumeId: String) -> IndexState {
        if removingVolumeIds.contains(volumeId) { return .removing }
        return indexedVolumeIds.contains(volumeId) ? .indexed : .notIndexed
    }

    /// The report's volumes whose id or title contains `filter`, ignoring case and diacritics.
    ///
    /// A blank filter keeps every volume. Both lists call this, so the two cannot disagree about
    /// what a filter matches.
    ///
    /// - Parameters:
    ///   - filter: The text typed into the list's filter field.
    ///   - title: The display title for a volume id, or `nil` when it has none.
    /// - Returns: The matching entries, in the report's order.
    func entries(matching filter: String, title: (String) -> String?) -> [VolumeStorageEntry] {
        let needle = filter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return entries }
        return entries.filter { entry in
            "\(entry.volumeId)\n\(title(entry.volumeId) ?? "")".range(
                of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    /// Size · index state · last opened, in one line — or size · *removing…* while the volume's
    /// removal is under way. Both lists draw this line, so the two cannot word a row differently.
    func statusLine(for entry: VolumeStorageEntry) -> String {
        let size = ByteCountFormatter.string(fromByteCount: Int64(entry.volumeFileBytes),
                                             countStyle: .file)
        let indexState: String
        switch self.indexState(of: entry.volumeId) {
        case .removing:
            let removing = String(localized: "settings.hub.allVolumes.removing",
                                  defaultValue: "removing…")
            return "\(entry.volumeId) · \(size) · \(removing)"
        case .indexed:
            indexState = String(localized: "settings.hub.allVolumes.indexed", defaultValue: "indexed")
        case .notIndexed:
            indexState = String(localized: "settings.hub.allVolumes.notIndexed",
                                defaultValue: "not indexed")
        }
        let opened: String
        if let date = lastOpenedByVolumeId[entry.volumeId] {
            opened = String(localized: "settings.hub.allVolumes.opened",
                            defaultValue: "opened \(date.formatted(.relative(presentation: .named)))")
        } else {
            opened = String(localized: "settings.hub.allVolumes.neverOpened",
                            defaultValue: "never opened")
        }
        return "\(entry.volumeId) · \(size) · \(indexState) · \(opened)"
    }

    /// Removes volumes: for each, its index rows and then its file; then one re-measure.
    ///
    /// The steps are the hub's, passed in, because they reach the pipeline, the download manager
    /// and `AppState`; the ORDER, and what the list sees between the steps, is this function's.
    ///
    /// - Parameters:
    ///   - volumeIds: The volumes to remove — one from a row's Remove, several from Free Up Space.
    ///   - unindex: Deletes one volume's index rows.
    ///   - deleteFile: Deletes one volume's XML file.
    ///   - remeasure: Runs once after the last file: reopens the read-only stores and re-measures
    ///     storage, which replaces ``report`` and ``indexedVolumeIds``.
    func removeVolumes(_ volumeIds: [String],
                       unindex: @MainActor (String) async -> Void,
                       deleteFile: @MainActor (String) async -> Void,
                       remeasure: @MainActor () async -> Void) async {
        // Every volume is marked before the first step, so a Free Up Space batch does not leave
        // its later volumes drawn as ordinary rows while the earlier ones are deleted.
        removingVolumeIds.formUnion(volumeIds)
        for volumeId in volumeIds {
            await unindex(volumeId)
            // The index rows are gone NOW; the re-measure would not say so until it lands.
            indexedVolumeIds.remove(volumeId)
            await deleteFile(volumeId)
        }
        await remeasure()
        // Only after the re-measure: until it lands, the report still lists the deleted file, and
        // a row drawn from it without the mark is #1356's removed volume sitting in the list.
        removingVolumeIds.subtract(volumeIds)
    }

    /// The ids the app can fetch again: the catalogue. A volume on disk and absent from this set
    /// was side-loaded, and removing it cannot be undone (#777). Both hubs and both lists read
    /// this one definition.
    static func redownloadableVolumeIds(in manifestStore: ManifestStore) -> Set<String> {
        Set((manifestStore.diffResult?.known ?? manifestStore.bundledEntries).map(\.volumeId))
    }
}
