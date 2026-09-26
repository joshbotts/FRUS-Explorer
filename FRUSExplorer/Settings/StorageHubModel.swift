// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Observation
import SwiftData

// MARK: - HubCopy

/// Count-agreeing copy fragments for the Volumes & Storage hub (S-2).
///
/// The app ships no String Catalog, so the `^[…](inflect: true)` agreement markup that would
/// normally handle this does nothing. A two-form choice is the honest substitute: a single
/// `"\(n) volumes"` string is wrong for the commonest count there is.
///
/// Both now go through `CountCopy`, which this pattern was lifted into (#1374): the two forms
/// formatted the count through a `%lld`, harmless only while the hub's counts stayed below 1,000.
///
/// Version history:
///   1.0 — S-2b: initial implementation, private to the macOS hub
///   1.1 — S-2c: lifted here so the iOS hub says the same thing
///   1.2 — 2026-09-25: #1374 — through `CountCopy`, so a count of 1,000 or more is grouped
enum HubCopy {

    /// "1 volume" / "N volumes" — the app-wide phrase, since the hub's own two keys said the same.
    static func volumes(_ count: Int) -> String {
        CountCopy.volumes(count)
    }

    /// "1 subseries" / "N subseries" — the noun is invariant, the article is not.
    static func subseries(_ count: Int) -> String {
        CountCopy.phrase(count,
                         one: String(localized: "settings.hub.count.subseries.one",
                                     defaultValue: "%@ subseries"),
                         many: String(localized: "settings.hub.count.subseries.many",
                                      defaultValue: "%@ subseries"))
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
///   1.2 — #1356 review, round 2: ``volumeIds(in:)``, what Remove takes, and
///          ``keeping(_:over:)``, what a sheet lists while its own removal runs
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

    /// The candidates `selection` names, as ids in the plan's order: what Free Up Space's Remove
    /// counts and removes.
    ///
    /// An id the plan does not offer is dropped, for the reason ``estimatedRecovery(for:)`` does
    /// not count one: a selection outlives the plan it was made in. That includes a volume another
    /// removal took while the sheet was open — ``DownloadedVolumesListModel``'s plan withholds a
    /// volume whose removal is under way — and a sheet that went on removing its selection would
    /// start a second removal of that volume, racing the first (#1356 review, round 2).
    func volumeIds(in selection: Set<String>) -> [String] {
        candidates.map(\.volumeId).filter { selection.contains($0) }
    }

    /// What a Free Up Space sheet lists while its own removal runs: this plan — the one the sheet
    /// was listing when that removal started — less every candidate `live` no longer offers,
    /// except the volumes the sheet is removing (#1356 review, round 2).
    ///
    /// The live plan withholds every volume whose removal is under way, and the removal marks the
    /// sheet's own volumes before its first step. Drawn from the live plan alone, the sheet lost
    /// them the moment it began removing them: with every candidate chosen it said "No Removable
    /// Volumes" beside its own spinner until the re-measure, and with some chosen it lost those
    /// rows and estimated a recovery of zero. Frozen instead, it would go on listing a volume that
    /// another removal took meanwhile. So the sheet's own volumes stay where they were, and every
    /// other row follows the live plan. A candidate the live plan gained meanwhile is not added:
    /// the sheet is removing, and it closes when the removal ends.
    ///
    /// - Parameters:
    ///   - removing: The volumes the sheet's own removal was started with.
    ///   - live: The hub's plan now.
    func keeping(_ removing: Set<String>, over live: StorageRemovalPlan) -> StorageRemovalPlan {
        let offered = Set(live.candidates.map(\.volumeId))
        return StorageRemovalPlan(candidates: candidates.filter {
            removing.contains($0.volumeId) || offered.contains($0.volumeId)
        })
    }
}

// MARK: - DownloadedVolumesListModel

/// What Volumes & Storage last measured, what its full downloaded-volume list draws — *Volumes on
/// This Device* on iOS, *Volumes on This Mac* on macOS — and the removal in progress (#1356).
///
/// There is ONE, on ``AppState/downloadedVolumes``. Both hubs read it, every instance of each, and
/// the list each hub opens reads it from the hub.
///
/// ## Why the list reads this and not copies
/// Before #1356 each hub handed its list `let` snapshots of the storage report and the index,
/// protected and last-opened sets, taken when the hub last rendered. A pushed destination (iOS) or
/// a sheet (macOS) holding copies changes only when a hub re-render reaches it. #1356 asked whether
/// one does, and on the simulators it does: against unfixed `v2`, a removed row left the pushed
/// list 1.1 s after the confirmation with nothing touched, on iPad Pro 13-inch at iOS 26.4 and at
/// iOS 27.0 (`VolumeRemovalTests.testRemovedRowLeavesTheListWithoutATouch`). The capture's
/// six-second row was not reproduced. The snapshots live here anyway, so that the removal mark
/// below and the rows it marks live in ONE observed object.
///
/// ## Why `AppState` holds it, not the hub or the list
/// The plan for #1356 put the removing set in the list's own `@State`, which is forgotten whenever
/// the list is closed and reopened mid-removal — Back then Show all on iOS, Done then Show All on
/// the Mac. The first fix moved the whole model to the hub, which outlives the list but not
/// itself: the iOS hub is a navigation destination of the Settings root and the Mac hub one arm of
/// the Settings pane switch, so Back to Settings and in again — or another pane and back — builds
/// a new hub with a new `@State`. Measured with the removal held open
/// (`VolumeRemovalTests.testRemovalMarkSurvivesLeavingTheHub`), on iOS 26.4 and 27.0: with the
/// model on the hub, the re-entered list drew the row as `… · indexed · never opened` while the
/// removal ran. Nor would anything have taken the row out of it afterwards, because the running
/// removal re-measures into the model of the hub the reader left — the unit test's per-hub mutant
/// shows the re-entered model still listing the volume once the removal is over. `AppState` lives
/// as long as the app, so a re-entered hub reads the same mark, and the re-measure lands in what
/// it draws.
///
/// That is also why the hub's WHOLE measurement lives here, not only what the list draws: the
/// index-page split and free space behind the compaction offer, and the iOS hub's measurement
/// error, are written by the same re-measure. The app holds one `AppState` for every scene, so two
/// iPad windows open on Volumes & Storage share the model too, and a removal started in one is
/// marked in the other.
///
/// ## The removal routine lives here, not in either hub
/// The two hubs are hand-maintained twins and each carried its own copy of the removal routine.
/// ``removeVolumes(_:in:context:remeasure:)`` is the one both now call — it supplies the app's
/// steps to ``removeVolumes(_:unindex:deleteFile:remeasure:)``, which orders them — so the
/// in-progress state below cannot exist on one platform and be missing from the other.
/// `HubRemovalRoutingTests` pins that both hubs call it and both lists draw ``statusLine(for:)``.
///
/// ## A removal in progress
/// A removal deletes the volume's index rows, then its file, then re-measures storage: a walk of
/// the volumes directory, a page-statistics read on the pipeline actor, four SwiftData fetches and
/// one index query per remaining volume. Before #1356 the row went on reading `indexed` through all
/// of it, and nothing on screen said a removal had started. Now:
/// - the volume is in ``removingVolumeIds`` from the moment the routine starts until the
///   re-measure has run, and ``statusLine(for:)`` reads *removing…* in place of its index state
///   and last-opened date;
/// - it leaves ``indexedVolumeIds`` as soon as its index rows are deleted, not when the re-measure
///   recomputes the set, so nothing that reads the set — the hub's hero count included — claims
///   rows that no longer exist;
/// - Free Up Space does not offer it (``freeUpSpacePlan(redownloadableVolumeIds:)``), for the same
///   reason its row withdraws its own Remove: a second removal would race the first. A sheet that
///   is open when the removal starts loses the row, and its Remove no longer takes the volume
///   (``StorageRemovalPlan/volumeIds(in:)``). The one exception is the sheet that STARTED the
///   removal: its own volumes are marked from the confirmation on, so until it closes it keeps
///   them (``StorageRemovalPlan/keeping(_:over:)``).
///
/// The mark clears after the re-measure has run. When the re-measure assigned a new report — the
/// ordinary case — that report no longer lists the volume, so no render draws the row unmarked
/// from the stale one. When the measurement itself FAILED the mark clears all the same, and what
/// the row does next is the hub's: iOS keeps its previous report and shows the error, so the
/// deleted volume's row is drawn again, unmarked and `not indexed`, until a measurement succeeds;
/// the Mac drops its report on a failure, which empties the list.
///
/// The row is MARKED, not dropped. A removal the re-measure does not confirm (the file could not be
/// deleted) brings the row back as it now is, and a list that had already dropped the row would
/// have no reason to draw it again.
///
/// Version history:
///   1.0 — #1356: initial implementation
///   1.1 — #1356 review, round 1: owned by `AppState` rather than by each hub, so the mark and the
///          re-measure reach a hub the reader re-enters mid-removal; carries the index-page split,
///          free space and measurement error too; ``removeVolumes(_:in:context:remeasure:)`` (the
///          app's steps, lifted from the twins) and ``freeUpSpacePlan(redownloadableVolumeIds:)``
///   1.2 — #1356 review, round 2: docs only — what the plan's exclusion means for an open Free Up
///          Space sheet and for the one that started the removal; the DEBUG hold is on each
///          volume's first step
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
    /// The live-versus-reclaimable split of the index file, measured with the report.
    var indexPages: IndexPageStatistics?
    /// Free space on the volume holding the index, for the compaction precondition.
    var availableBytes: Int?
    /// The message from a failed storage measurement. The iOS hub shows it; the Mac hub's
    /// measurement has no error surface and never sets it.
    var loadError: String?
    /// Volumes whose removal has started and whose re-measure has not run.
    private(set) var removingVolumeIds: Set<String> = []

    /// Creates an empty model; a hub fills it from its first storage measurement.
    init() {}

    /// Every downloaded volume, in the report's order (by volume id).
    var entries: [VolumeStorageEntry] { report?.perVolume ?? [] }

    /// What a row says about its volume's place in the search index.
    ///
    /// Version history:
    ///   1.0 — #1356: initial implementation
    enum IndexState: Equatable, Sendable {
        /// A removal has started and its re-measure has not run.
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

    /// What Free Up Space may offer: ``StorageRemovalPlan``'s rules over this measurement, less
    /// every volume whose removal is under way.
    ///
    /// A volume being removed cannot be removed again — its row withdraws its own Remove because a
    /// second removal would race the first — and Free Up Space is the other way to ask. Both hubs
    /// build their sheet's plan here, and the sheet reads it live, so a volume another removal holds
    /// is left out of a sheet already open as well as of one opened later. The sheet's OWN removal
    /// is the exception: its volumes are marked from the confirmation on, so from then until it
    /// closes the sheet keeps them (``StorageRemovalPlan/keeping(_:over:)``, #1356 review, round 2).
    ///
    /// - Parameter redownloadableVolumeIds: The catalogue ids (``redownloadableVolumeIds(in:)``).
    func freeUpSpacePlan(redownloadableVolumeIds: Set<String>) -> StorageRemovalPlan {
        StorageRemovalPlan.make(entries: entries.filter { !removingVolumeIds.contains($0.volumeId) },
                                protectedVolumeIds: protectedVolumeIds,
                                redownloadableVolumeIds: redownloadableVolumeIds,
                                lastOpenedByVolumeId: lastOpenedByVolumeId)
    }

    /// Removes volumes: for each, its index rows and then its file; then one re-measure.
    ///
    /// The steps are passed in, because they reach the pipeline, the download manager and
    /// `AppState`; the ORDER, and what the list sees between the steps, is this function's. The
    /// hubs reach it through ``removeVolumes(_:in:context:remeasure:)``, which supplies the app's
    /// steps; the tests supply their own.
    ///
    /// - Parameters:
    ///   - volumeIds: The volumes to remove — one from a row's Remove, several from Free Up Space.
    ///   - unindex: Deletes one volume's index rows.
    ///   - deleteFile: Deletes one volume's XML file.
    ///   - remeasure: Runs once after the last file: reopens the read-only stores and re-measures
    ///     storage, which replaces ``report`` and ``indexedVolumeIds`` when it succeeds.
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

    /// Removes volumes with the app's own steps: the routing both hubs call (#1356 review).
    ///
    /// Each hub used to build these steps itself, around its own call to
    /// ``removeVolumes(_:unindex:deleteFile:remeasure:)`` — so a hub gone back to removing inline
    /// would have passed every unit test while its list lost the mark. The steps: delete the
    /// volume's index rows and drop it from `AppState.indexedVolumeIds`; delete its file; then,
    /// once, VACUUM after a multi-volume removal (a single one is not worth the pause for a few
    /// megabytes), reopen the read-only stores so analytics stop counting the removed rows (#275),
    /// and let the hub re-measure. A DEBUG launch can hold each volume's first step — its unindex —
    /// open (`UITestVolumeSeeder.holdStorageRemovalIfRequested()`), so every volume of a Free Up
    /// Space batch is held in turn. That is how a UI test reads the mark, leaves the hub, or reads
    /// Free Up Space while a removal is still running.
    ///
    /// - Parameters:
    ///   - volumeIds: The volumes to remove.
    ///   - appState: Supplies the pipeline and the download manager. Without either this removes
    ///     nothing, as each hub's own copy did.
    ///   - context: The main-actor context `AppState.refreshAfterCorpusChange(context:)` requires.
    ///   - remeasure: The calling hub's `loadReport()`, which writes its measurement here.
    func removeVolumes(_ volumeIds: [String],
                       in appState: AppState,
                       context: ModelContext,
                       remeasure: @MainActor () async -> Void) async {
        guard let dm = appState.downloadManager,
              let pipeline = appState.indexingPipeline else { return }
        await removeVolumes(
            volumeIds,
            unindex: { volumeId in
                #if DEBUG
                await UITestVolumeSeeder.holdStorageRemovalIfRequested()
                #endif
                try? await pipeline.removeVolume(volumeId)
                appState.indexedVolumeIds.remove(volumeId)
            },
            deleteFile: { volumeId in
                try? await dm.deleteVolume(volumeId: volumeId)
            },
            remeasure: {
                if volumeIds.count > 1 {
                    try? await pipeline.vacuumIndex()
                }
                appState.refreshAfterCorpusChange(context: context)
                await remeasure()
            }
        )
    }

    /// The ids the app can fetch again: the catalogue. A volume on disk and absent from this set
    /// was side-loaded, and removing it cannot be undone (#777). Both hubs and both lists read
    /// this one definition.
    static func redownloadableVolumeIds(in manifestStore: ManifestStore) -> Set<String> {
        Set((manifestStore.diffResult?.known ?? manifestStore.bundledEntries).map(\.volumeId))
    }
}
