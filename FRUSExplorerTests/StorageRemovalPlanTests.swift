// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData
import Testing
@testable import FRUSExplorer

// MARK: - StorageRemovalPlanTests

/// Tests the Free Up Space eligibility and ordering rules (S-2c).
///
/// This is the only destructive flow in Settings that acts on more than one volume at a time, and
/// it is now shared by both platforms — so the rules that decide *which* volumes it offers, and
/// how much space it claims removing them recovers, are worth pinning precisely. The protection
/// rule in particular is the one that keeps a researcher's notes from being stranded against a
/// volume that is no longer on the device.
struct StorageRemovalPlanTests {

    private func entry(_ volumeId: String, bytes: Int = 1_000_000) -> VolumeStorageEntry {
        VolumeStorageEntry(volumeId: volumeId, volumeFileBytes: bytes)
    }

    /// The pre-#777 world: every volume came from the catalogue, so every volume is recoverable.
    /// Tests about the *other* rules pass this so their meaning is unchanged.
    private let allRedownloadable: Set<String> = [
        "a",
        "alpha",
        "b",
        "c",
        "frus1861",
        "frus1952-54v01",
        "frus1969-76v12",
        "never",
        "old",
        "recent",
        "zebra",
    ]

    private func date(_ daysAgo: Int) -> Date {
        Date(timeIntervalSince1970: 1_700_000_000 - Double(daysAgo) * 86_400)
    }

    // MARK: - The protection rule

    /// A volume with attached research data is not offered at all — not merely sorted last.
    @Test("Volumes carrying user data are excluded outright")
    func protectedVolumesAreNotCandidates() {
        let plan = StorageRemovalPlan.make(
            entries: [entry("a"), entry("b"), entry("c")],
            protectedVolumeIds: ["b"],
            redownloadableVolumeIds: allRedownloadable,
            lastOpenedByVolumeId: [:]
        )
        #expect(plan.candidates.map(\.volumeId) == ["a", "c"])
        #expect(!plan.candidates.contains { $0.volumeId == "b" })
    }

    /// Every volume protected → nothing to offer, and the sheet shows its empty state instead of
    /// an empty list with a live Remove button.
    @Test("A fully protected library yields an empty plan")
    func fullyProtectedLibraryIsEmpty() {
        let plan = StorageRemovalPlan.make(
            entries: [entry("a"), entry("b")],
            protectedVolumeIds: ["a", "b"],
            redownloadableVolumeIds: allRedownloadable,
            lastOpenedByVolumeId: [:]
        )
        #expect(plan.isEmpty)
        #expect(plan.candidates.isEmpty)
    }

    /// A protected identifier that is not downloaded must not disturb anything.
    @Test("A protection entry for a volume that is not downloaded is harmless")
    func unknownProtectedIdIsIgnored() {
        let plan = StorageRemovalPlan.make(
            entries: [entry("a")],
            protectedVolumeIds: ["not-downloaded"],
            redownloadableVolumeIds: allRedownloadable,
            lastOpenedByVolumeId: [:]
        )
        #expect(plan.candidates.map(\.volumeId) == ["a"])
    }

    // MARK: - Ordering

    /// Never-opened first, then least-recently-opened. That is the whole point of the list: the
    /// volumes a reader has demonstrably never needed sit at the top.
    @Test("Never-opened volumes lead, then oldest-opened first")
    func orderingPutsUnusedFirst() {
        let plan = StorageRemovalPlan.make(
            entries: [entry("recent"), entry("never"), entry("old")],
            protectedVolumeIds: [],
            redownloadableVolumeIds: allRedownloadable,
            lastOpenedByVolumeId: ["recent": date(1), "old": date(400)]
        )
        #expect(plan.candidates.map(\.volumeId) == ["never", "old", "recent"])
    }

    /// Two never-opened volumes have nothing to sort by but their identifier — and the order has
    /// to be stable, or rows would shuffle under the user's finger on every refresh.
    @Test("Never-opened volumes are ordered stably by identifier")
    func neverOpenedTieBreaksOnIdentifier() {
        let plan = StorageRemovalPlan.make(
            entries: [entry("frus1969-76v12"), entry("frus1861"), entry("frus1952-54v01")],
            protectedVolumeIds: [],
            redownloadableVolumeIds: allRedownloadable,
            lastOpenedByVolumeId: [:]
        )
        #expect(plan.candidates.map(\.volumeId) == ["frus1861", "frus1952-54v01", "frus1969-76v12"])
    }

    /// Same for an exact timestamp collision, which CloudKit import can produce.
    @Test("An exact last-opened tie also breaks on identifier")
    func openedTieBreaksOnIdentifier() {
        let shared = date(10)
        let plan = StorageRemovalPlan.make(
            entries: [entry("zebra"), entry("alpha")],
            protectedVolumeIds: [],
            redownloadableVolumeIds: allRedownloadable,
            lastOpenedByVolumeId: ["zebra": shared, "alpha": shared]
        )
        #expect(plan.candidates.map(\.volumeId) == ["alpha", "zebra"])
    }

    // MARK: - Size estimates

    /// XML plus the 2.8× index estimate — the figure the sheet shows, prefixed with "~".
    @Test("A candidate's estimate is its XML plus the index overhead factor")
    func candidateEstimateIncludesIndexOverhead() {
        let plan = StorageRemovalPlan.make(
            entries: [entry("a", bytes: 1_000_000)],
            protectedVolumeIds: [],
            redownloadableVolumeIds: allRedownloadable,
            lastOpenedByVolumeId: [:]
        )
        let expected = 1_000_000 + Int(1_000_000 * StorageReport.indexOverheadFactor)
        #expect(plan.candidates[0].estimatedBytes == expected)
    }

    @Test("Recovery sums only the selected candidates")
    func recoverySumsSelection() {
        let plan = StorageRemovalPlan.make(
            entries: [entry("a", bytes: 1_000), entry("b", bytes: 2_000), entry("c", bytes: 4_000)],
            protectedVolumeIds: [],
            redownloadableVolumeIds: allRedownloadable,
            lastOpenedByVolumeId: [:]
        )
        let expected = plan.candidates
            .filter { ["a", "c"].contains($0.volumeId) }
            .reduce(0) { $0 + $1.estimatedBytes }
        #expect(plan.estimatedRecovery(for: ["a", "c"]) == expected)
        #expect(plan.estimatedRecovery(for: []) == 0)
    }

    /// A selection made before a refresh can name volumes that are no longer candidates (they were
    /// removed, or gained a note). Those must contribute nothing rather than inflate the claim.
    @Test("Identifiers that are not candidates contribute nothing to the estimate")
    func staleSelectionDoesNotInflateEstimate() {
        let plan = StorageRemovalPlan.make(
            entries: [entry("a", bytes: 1_000)],
            protectedVolumeIds: [],
            redownloadableVolumeIds: allRedownloadable,
            lastOpenedByVolumeId: [:]
        )
        #expect(plan.estimatedRecovery(for: ["a", "gone", "protected-now"])
                == plan.estimatedRecovery(for: ["a"]))
    }

    /// Nothing downloaded at all.
    @Test("An empty library yields an empty plan")
    func emptyLibrary() {
        let plan = StorageRemovalPlan.make(entries: [],
                                           protectedVolumeIds: [],
                                           redownloadableVolumeIds: allRedownloadable,
                                           lastOpenedByVolumeId: [:])
        #expect(plan.isEmpty)
        #expect(plan.estimatedRecovery(for: ["anything"]) == 0)
    }
}

// MARK: - HubCopyTests

/// Tests the hub's count-agreeing copy (S-2c).
///
/// The app ships no String Catalog, so grammatical agreement is hand-rolled; a single plural form
/// would render "1 volumes" in the commonest case there is (one interrupted volume, one selected
/// volume, one imported file).
struct HubCopyTests {

    @Test("Volume counts agree in number")
    func volumeAgreement() {
        #expect(HubCopy.volumes(1) == "1 volume")
        #expect(HubCopy.volumes(0) == "0 volumes")
        #expect(HubCopy.volumes(2) == "2 volumes")
        #expect(HubCopy.volumes(552) == "552 volumes")
    }

    @Test("Subseries counts agree in number without pluralizing the noun")
    func subseriesAgreement() {
        #expect(HubCopy.subseries(1) == "1 subseries")
        #expect(HubCopy.subseries(3) == "3 subseries")
    }
}

// MARK: - The recoverability rule (#777)

extension StorageRemovalPlanTests {

    /// Free Up Space exists to reclaim space that costs only a download to get back. A side-loaded
    /// volume costs the user their only copy: the app's is written with `isExcludedFromBackupKey`,
    /// so it is in no iCloud Backup and no Time Machine either.
    @Test("A volume the app cannot download again is never offered")
    func sideloadedVolumesAreNotCandidates() {
        let plan = StorageRemovalPlan.make(
            entries: [entry("a"), entry("sideloaded"), entry("b")],
            protectedVolumeIds: [],
            redownloadableVolumeIds: ["a", "b"],
            lastOpenedByVolumeId: [:]
        )
        #expect(plan.candidates.map(\.volumeId) == ["a", "b"], """
            A side-loaded volume was offered for removal. Nothing can restore it — this is the \
            irreversible half of #777, and the confirmation promised a re-download.
            """)
    }

    /// The reason this is not merely a sorting nicety: candidates are ordered never-opened first,
    /// and a volume the user side-loaded a minute ago has by definition never been opened and
    /// carries no notes. Before the guard it was not just eligible, it led the list.
    @Test("It would otherwise have been the FIRST suggestion")
    func sideloadedVolumeWouldHaveLedTheList() {
        let entries = [entry("recent"), entry("sideloaded"), entry("old")]
        let opened = ["recent": date(1), "old": date(400)]

        let unguarded = StorageRemovalPlan.make(
            entries: entries, protectedVolumeIds: [],
            redownloadableVolumeIds: ["recent", "sideloaded", "old"],
            lastOpenedByVolumeId: opened)
        #expect(unguarded.candidates.first?.volumeId == "sideloaded", """
            The premise of the guard: never-opened sorts first, so a fresh side-load leads. If this \
            assertion fails the ordering changed and the #777 rationale needs re-checking.
            """)

        let guarded = StorageRemovalPlan.make(
            entries: entries, protectedVolumeIds: [],
            redownloadableVolumeIds: ["recent", "old"],
            lastOpenedByVolumeId: opened)
        #expect(guarded.candidates.map(\.volumeId) == ["old", "recent"])
    }

    /// A caller that has not resolved its catalogue yet offers nothing, rather than everything.
    @Test("An empty catalogue offers no candidates, not all of them")
    func emptyCatalogueIsSafe() {
        let plan = StorageRemovalPlan.make(
            entries: [entry("a"), entry("b")],
            protectedVolumeIds: [],
            redownloadableVolumeIds: [],
            lastOpenedByVolumeId: [:]
        )
        #expect(plan.isEmpty, """
            With no catalogue the plan must refuse rather than assume. The failure direction \
            matters: guessing "recoverable" deletes files, guessing "not" shows an empty sheet.
            """)
    }

    /// Both rules apply, and neither shadows the other.
    @Test("Protection and recoverability are independent")
    func bothRulesApply() {
        let plan = StorageRemovalPlan.make(
            entries: [entry("a"), entry("b"), entry("c"), entry("sideloaded")],
            protectedVolumeIds: ["b"],
            redownloadableVolumeIds: ["a", "b", "c"],
            lastOpenedByVolumeId: [:]
        )
        #expect(plan.candidates.map(\.volumeId) == ["a", "c"])
    }
}

// MARK: - DownloadedVolumesListModelTests

/// What *Volumes on This Device* / *Volumes on This Mac* draws while a volume is being removed
/// (#1356), driven through the one removal routine both hubs call.
///
/// ## How the tests hold a removal still
/// Each step the hub passes in — delete the index rows, delete the file, re-measure — can be made
/// to suspend on a continuation (``StepGate``). The test waits until the routine is parked at the
/// step it cares about, reads what a row would draw, and only then lets it go. That is the shape
/// #1356 asked for, and the reason a UI test cannot do this job: a timing-based assertion about a
/// removal in flight passes on a fast removal and flakes under load.
///
/// ## What each test guards
/// - the index rows being deleted: the row reads *removing…*, never `indexed`, and is marked rather
///   than dropped;
/// - the file being deleted: the volume has already left the index set;
/// - the re-measure running: the mark is still on, because the report the row would otherwise be
///   drawn from is the stale one;
/// - a re-measure that still lists the volume (the delete failed): the row comes back as it is,
///   reading what the re-measure found in the index;
/// - a multi-volume removal (Free Up Space): every volume is marked from the start;
/// - a hub opened while another hub's removal runs: it reads the same mark, and that removal's
///   re-measure reaches it — the model is `AppState`'s, not a hub's;
/// - Free Up Space: it does not offer a volume whose removal is under way;
/// - the app's own steps, through the routing both hubs call, against a real index and a real
///   volumes directory.
///
/// None of these reaches a hub. That both hubs call the routing, and both lists draw
/// ``DownloadedVolumesListModel/statusLine(for:)``, is `HubRemovalRoutingTests`', and the iOS hub
/// is driven end to end by `VolumeRemovalTests`.
///
/// Version history:
///   1.0 — #1356: initial implementation
///   1.1 — #1356 review, round 1: the unconfirmed removal reads its index state from the
///          re-measure; a hub opened mid-removal; Free Up Space withholding a removal under way;
///          the app's steps against a real pipeline
@MainActor
struct DownloadedVolumesListModelTests {

    /// A removal step that stops until the test releases it.
    ///
    /// Version history:
    ///   1.0 — #1356: initial implementation
    @MainActor
    final class StepGate {
        /// The steps that have reached the gate, in order.
        private(set) var arrivals: [String] = []
        /// The parked step's continuation, or `nil` when nothing is parked.
        private var parked: CheckedContinuation<Void, Never>?

        /// Called BY a step: records its arrival and suspends until ``release()``.
        func hold(_ step: String) async {
            arrivals.append(step)
            await withCheckedContinuation { parked = $0 }
        }

        /// Resumes the parked step.
        func release() {
            parked?.resume()
            parked = nil
        }

        /// Yields until `step` is parked at the gate. `false` if it never arrives.
        func waitUntilParked(at step: String) async -> Bool {
            for _ in 0..<10_000 {
                if parked != nil, arrivals.last == step { return true }
                await Task.yield()
            }
            return false
        }
    }

    /// The label the row reads while its removal is under way. The app ships no localization, so
    /// the default value is what renders.
    private static let removingLabel = "removing…"

    private static func entry(_ volumeId: String) -> VolumeStorageEntry {
        VolumeStorageEntry(volumeId: volumeId, volumeFileBytes: 2_048)
    }

    private static func report(_ volumeIds: [String]) -> StorageReport {
        StorageReport(totalVolumesBytes: 2_048 * volumeIds.count, totalIndexBytes: 0,
                      totalSummariesBytes: 0, totalVectorBytes: 0,
                      perVolume: volumeIds.map(entry))
    }

    /// Three volumes, all indexed — the state the hub has just measured.
    private func makeModel(_ volumeIds: [String] = ["a", "b", "c"]) -> DownloadedVolumesListModel {
        let model = DownloadedVolumesListModel()
        model.report = Self.report(volumeIds)
        model.indexedVolumeIds = Set(volumeIds)
        return model
    }

    /// The ids a list would draw with no filter.
    private func drawn(_ model: DownloadedVolumesListModel) -> [String] {
        model.entries(matching: "", title: { _ in nil }).map(\.volumeId)
    }

    /// The status line's `·`-separated parts, for `volumeId`.
    private func statusParts(_ model: DownloadedVolumesListModel, _ volumeId: String) -> [String] {
        model.statusLine(for: Self.entry(volumeId)).components(separatedBy: " · ")
    }

    @Test("While its index rows are deleted, the row reads removing…, never indexed, and stays drawn")
    func rowReadsRemovingWhileIndexRowsAreDeleted() async throws {
        let model = makeModel()
        let gate = StepGate()
        let removal = Task {
            await model.removeVolumes(["b"],
                                      unindex: { _ in await gate.hold("unindex") },
                                      deleteFile: { _ in },
                                      remeasure: { model.report = Self.report(["a", "c"]) })
        }
        try #require(await gate.waitUntilParked(at: "unindex"), "the removal never reached its first step")

        #expect(model.indexState(of: "b") == .removing)
        let parts = statusParts(model, "b")
        #expect(parts.last == Self.removingLabel, "the row reads \(parts)")
        #expect(!parts.contains("indexed"), """
            The row claims index rows while they are being deleted — #1356's defect: \(parts)
            """)
        #expect(drawn(model) == ["a", "b", "c"], "a removing row is marked, not dropped")
        #expect(model.indexState(of: "a") == .indexed && model.indexState(of: "c") == .indexed,
                "the rows beside it are untouched")

        gate.release()
        await removal.value
        #expect(drawn(model) == ["a", "c"], "once the re-measure lands the row is gone")
        #expect(model.removingVolumeIds.isEmpty)
    }

    @Test("Once its index rows are gone, the volume leaves the index set while its file is deleted")
    func indexSetDropsTheVolumeBeforeTheFileGoes() async throws {
        let model = makeModel()
        let gate = StepGate()
        let removal = Task {
            await model.removeVolumes(["b"],
                                      unindex: { _ in },
                                      deleteFile: { _ in await gate.hold("deleteFile") },
                                      remeasure: { model.report = Self.report(["a", "c"]) })
        }
        try #require(await gate.waitUntilParked(at: "deleteFile"), "the removal never reached the file")

        #expect(model.indexedVolumeIds == ["a", "c"], """
            The index rows are deleted but the index set still names the volume, so every reader of \
            the set — the hub's hero count included — claims rows that no longer exist until the \
            re-measure: \(model.indexedVolumeIds.sorted())
            """)
        #expect(model.indexState(of: "b") == .removing)

        gate.release()
        await removal.value
    }

    @Test("The mark stays on through the re-measure, while the only report is the stale one")
    func markOutlastsTheFileUntilTheRemeasureLands() async throws {
        let model = makeModel()
        let gate = StepGate()
        let removal = Task {
            await model.removeVolumes(["b"],
                                      unindex: { _ in },
                                      deleteFile: { _ in },
                                      remeasure: {
                                          await gate.hold("remeasure")
                                          model.report = Self.report(["a", "c"])
                                      })
        }
        try #require(await gate.waitUntilParked(at: "remeasure"), "the removal never reached the re-measure")

        #expect(drawn(model).contains("b"), "the stale report still lists the removed volume")
        #expect(model.indexState(of: "b") == .removing, """
            The file is gone and the report has not caught up. A row drawn from that report without \
            the mark is exactly what #1356 captured — a removed volume sitting in the list.
            """)

        gate.release()
        await removal.value
        #expect(drawn(model) == ["a", "c"])
        #expect(!model.isRemoving("b"))
    }

    @Test("A removal the re-measure does not confirm brings the row back as it is")
    func unconfirmedRemovalBringsTheRowBack() async {
        let model = makeModel()
        // What the index holds. The re-measure recomputes the index set from it, as the hubs'
        // `refreshSnapshots()` recomputes it from the pipeline, so the index state asserted below
        // is the re-measure's reading and not what the routine's early drop left behind.
        var index: Set<String> = ["a", "b", "c"]
        // The file could not be deleted: the re-measure lists the volume again.
        await model.removeVolumes(["b"],
                                  unindex: { volumeId in _ = index.remove(volumeId) },
                                  deleteFile: { _ in },
                                  remeasure: {
                                      model.report = Self.report(["a", "b", "c"])
                                      model.indexedVolumeIds = index
                                  })

        #expect(drawn(model) == ["a", "b", "c"], "a volume still on disk is still listed")
        #expect(!model.isRemoving("b"), "the mark ends with the routine, confirmed or not")
        #expect(model.indexState(of: "b") == .notIndexed, """
            Its index rows WERE deleted — the re-measure found none — so the row reads not \
            indexed, and not removing.
            """)
    }

    @Test("Free Up Space's several volumes are all marked from the moment the removal starts")
    func everyVolumeOfAMultiRemovalIsMarkedAtOnce() async throws {
        let model = makeModel()
        let gate = StepGate()
        let removal = Task {
            await model.removeVolumes(["a", "c"],
                                      unindex: { volumeId in await gate.hold("unindex \(volumeId)") },
                                      deleteFile: { _ in },
                                      remeasure: { model.report = Self.report(["b"]) })
        }
        try #require(await gate.waitUntilParked(at: "unindex a"), "the removal never reached its first volume")

        #expect(model.indexState(of: "a") == .removing)
        #expect(model.indexState(of: "c") == .removing, "the volume not yet reached is marked too")
        #expect(model.indexState(of: "b") == .indexed, "a volume not being removed is untouched")

        gate.release()
        try #require(await gate.waitUntilParked(at: "unindex c"), "the removal never reached its second volume")
        gate.release()
        await removal.value
        #expect(drawn(model) == ["b"])
        #expect(model.removingVolumeIds.isEmpty)
    }

    @Test("A hub opened while another hub's removal runs shows the mark, and that removal's re-measure reaches it")
    func removalReachesAHubOpenedWhileItRuns() async throws {
        let appState = AppState()
        // The hub the reader confirmed the removal in. Both hubs resolve their model through
        // `AppState` (`volumeList`), and a removal keeps the one its hub resolved after the reader
        // has left that hub.
        let leftHub = appState.downloadedVolumes
        leftHub.report = Self.report(["a", "b", "c"])
        leftHub.indexedVolumeIds = ["a", "b", "c"]
        let gate = StepGate()
        let removal = Task {
            await leftHub.removeVolumes(["b"],
                                        unindex: { _ in await gate.hold("unindex") },
                                        deleteFile: { _ in },
                                        remeasure: {
                                            leftHub.report = Self.report(["a", "c"])
                                            leftHub.indexedVolumeIds = ["a", "c"]
                                        })
        }
        try #require(await gate.waitUntilParked(at: "unindex"), "the removal never reached its first step")

        // Back to Settings and in again builds a NEW hub, whose first measurement runs while the
        // file is still on disk and its index rows are still there.
        let reenteredHub = appState.downloadedVolumes
        reenteredHub.report = Self.report(["a", "b", "c"])
        reenteredHub.indexedVolumeIds = ["a", "b", "c"]
        #expect(reenteredHub.indexState(of: "b") == .removing, """
            The re-entered hub draws the row as an ordinary one while its removal runs: the mark \
            belongs to the hub the reader left.
            """)

        gate.release()
        await removal.value
        #expect(reenteredHub.entries.map(\.volumeId) == ["a", "c"], """
            The removal's re-measure did not reach the hub on screen, which goes on listing the \
            removed volume until something else measures — #1356's row, one Back away.
            """)
        #expect(!reenteredHub.isRemoving("b"))
    }

    @Test("Free Up Space does not offer a volume whose removal is under way")
    func freeUpSpaceWithholdsAVolumeBeingRemoved() async throws {
        let model = makeModel()
        let catalogue: Set<String> = ["a", "b", "c"]
        #expect(model.freeUpSpacePlan(redownloadableVolumeIds: catalogue).candidates.map(\.volumeId)
                    == ["a", "b", "c"], "at rest, every catalogue volume is offered")
        let gate = StepGate()
        let removal = Task {
            await model.removeVolumes(["b"],
                                      unindex: { _ in await gate.hold("unindex") },
                                      deleteFile: { _ in },
                                      remeasure: { model.report = Self.report(["a", "c"]) })
        }
        try #require(await gate.waitUntilParked(at: "unindex"), "the removal never reached its first step")

        #expect(model.freeUpSpacePlan(redownloadableVolumeIds: catalogue).candidates.map(\.volumeId)
                    == ["a", "c"], """
            Free Up Space offers a volume that is already being removed. Its row withdrew its own \
            Remove because a second removal would race the first; the sheet is the other way in.
            """)

        gate.release()
        await removal.value
    }

    /// The context `AppState.refreshAfterCorpusChange(context:)` requires. Static because that call
    /// starts a person-rollup task it does not await, which reads this context after the test has
    /// returned, and a container dropped under a live context traps.
    private static let rollupContainer = Result {
        try ModelContainer(for: PersonClusterOverride.self,
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true,
                                                              cloudKitDatabase: .none))
    }

    @Test("The hubs' routing deletes the index rows, the index-set entry and the file, then re-measures once, marked throughout")
    func appStepsRemoveAVolumeThroughTheSharedRouting() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("frus-hub-removal-\(UUID().uuidString)", isDirectory: true)
        let volumes = dir.appendingPathComponent("volumes", isDirectory: true)
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        // Five real one-document volumes, indexed — the UI suite's rows.
        let rows = UITestVolumeSeeder.storageRowVolumeIds
        UITestVolumeSeeder.prepareStorageRows(requested: true, in: volumes)
        let dbURL = dir.appendingPathComponent("frus.db")
        let pipeline = try IndexingPipeline(fts5Store: try FTS5Store(databaseURL: dbURL),
                                            databaseURL: dbURL, volumesDirectory: volumes,
                                            concurrencyLimit: 1)
        await UITestVolumeSeeder.prepareStorageRowIndex(pipeline: pipeline, requested: true)
        let dm = DownloadManager(volumesDirectory: volumes, concurrencyLimit: 1,
                                 downloadTask: { _ in throw CancellationError() },
                                 onStateChanged: { _ in })

        let appState = AppState()
        appState.indexingPipeline = pipeline
        appState.downloadManager = dm
        appState.indexedVolumeIds = Set(rows)
        let model = appState.downloadedVolumes
        model.report = try await dm.storageReport()
        model.indexedVolumeIds = Set(rows)
        try #require(model.entries.map(\.volumeId) == rows, "the five rows were not measured")

        let target = "uitest-storage-02"
        let file = volumes.appendingPathComponent("\(target).xml")
        var remeasures = 0
        await model.removeVolumes([target], in: appState,
                                  context: try Self.rollupContainer.get().mainContext,
                                  remeasure: {
            remeasures += 1
            // What the hub's `loadReport()` finds when the routing hands over to it.
            #expect(model.isRemoving(target), "the mark is off before the re-measure has run")
            #expect((try? pipeline.isVolumeIndexed(target)) == false, "its index rows are still there")
            #expect(!appState.indexedVolumeIds.contains(target), """
                AppState's index set still names the volume, so every surface that reads it — \
                Browse's index badges among them — claims rows that are gone.
                """)
            #expect(!model.indexedVolumeIds.contains(target), "the list's index set still names it")
            #expect(!FileManager.default.fileExists(atPath: file.path), "its file is still on disk")
            model.report = try? await dm.storageReport()
        })

        #expect(remeasures == 1, "the routing re-measured \(remeasures) times")
        #expect(!model.isRemoving(target), "the mark outlived the re-measure")
        #expect(model.entries.map(\.volumeId) == rows.filter { $0 != target })
        for other in rows where other != target {
            #expect((try? pipeline.isVolumeIndexed(other)) == true, "\(other) lost its index rows")
        }
    }

    @Test("The status line of a row at rest: id · size · index state · last opened")
    func statusLineAtRest() {
        let model = makeModel()
        model.indexedVolumeIds = ["a"]
        model.lastOpenedByVolumeId = ["b": Date(timeIntervalSinceNow: -86_400)]

        let indexed = statusParts(model, "a")
        #expect(indexed.count == 4 && indexed[0] == "a" && indexed[2] == "indexed" && indexed[3] == "never opened",
                "\(indexed)")
        let opened = statusParts(model, "b")
        #expect(opened.count == 4 && opened[2] == "not indexed" && opened[3].hasPrefix("opened "),
                "\(opened)")
    }

    @Test("The filter matches an id or a title, ignoring case, diacritics and surrounding space")
    func filterMatchesIdOrTitle() {
        let model = makeModel(["frus1961-63v06", "frus1969-76v01"])
        let titles = ["frus1961-63v06": "Kennedy-Khrushchev Exchanges",
                      "frus1969-76v01": "Foundations of Foreign Policy, 1969–1972"]
        func matches(_ filter: String) -> [String] {
            model.entries(matching: filter, title: { titles[$0] }).map(\.volumeId)
        }
        #expect(matches("") == ["frus1961-63v06", "frus1969-76v01"], "a blank filter keeps every row")
        #expect(matches("   ") == ["frus1961-63v06", "frus1969-76v01"], "so does one of spaces")
        #expect(matches("  KHRUSHCHEV ") == ["frus1961-63v06"], "a title, trimmed and case-folded")
        #expect(matches("Fóundations") == ["frus1969-76v01"], "diacritics are ignored")
        #expect(matches("1969-76") == ["frus1969-76v01"], "an id")
        #expect(matches("Berlin").isEmpty)
    }
}

// MARK: - HubRemovalRoutingTests

/// Both hubs reach the removal through the one routing, read the one model on `AppState`, and both
/// full lists draw that model's status line (#1356 review).
///
/// These are the connections the unit tests above cannot reach: `DownloadedVolumesListModelTests`
/// drives the model with steps it supplies, so a hub gone back to its own inline removal loop, a
/// hub holding its own model again, or a list row drawing its own status text would leave every
/// one of them green while the row lost its *removing…* mark. The iOS hub is also driven end to
/// end by `VolumeRemovalTests.testRemovalMarkSurvivesLeavingTheHub`; the Mac has no UI-test target,
/// so for `MacVolumesStorageHub` these scans are the only automated guard.
///
/// Each assertion is scoped to ONE declaration's body — the hub's `removeVolumes`, its
/// `removalPlan`, the list's `row(_:)` — so a matching call elsewhere in a 2,000-line file cannot
/// satisfy it.
///
/// Version history:
///   1.0 — #1356 review, round 1: initial implementation
@Suite("Hub removal routing")
struct HubRemovalRoutingTests {

    /// The two hubs, the full-list view each presents, and how that list withdraws a removing
    /// row's actions — iOS offers no swipe actions, the Mac disables its Remove.
    private static let hubs: [(path: String, list: String, withdrawal: String)] = [
        ("FRUSExplorer/Settings/VolumesStorageHubView.swift", "private struct DownloadedVolumesListView",
         "if !removing {"),
        ("FRUSExplorer/Settings/MacVolumesStorageHub.swift", "private struct MacAllVolumesSheet",
         ".disabled(model.reindexingVolumeId != nil || removing)"),
    ]

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appending(path: path), encoding: .utf8)
        #expect(text.count > 1_000, "\(path) is implausibly small — did it move?")
        return text
    }

    /// The body of the first declaration introduced by `signature` — at or after `anchor`, when one
    /// is given — from its opening brace to the brace that balances it.
    private static func body(of signature: String, in text: String,
                             after anchor: String? = nil) throws -> String {
        var searchStart = text.startIndex
        if let anchor {
            searchStart = try #require(text.range(of: anchor), "no `\(anchor)`").upperBound
        }
        let declaration = try #require(text.range(of: signature, range: searchStart..<text.endIndex),
                                       "no `\(signature)`")
        let open = try #require(text[declaration.upperBound...].firstIndex(of: "{"),
                                "`\(signature)` has no body")
        var depth = 0
        var index = open
        while index < text.endIndex {
            if text[index] == "{" { depth += 1 }
            if text[index] == "}" {
                depth -= 1
                if depth == 0 { return String(text[open...index]) }
            }
            index = text.index(after: index)
        }
        Issue.record("`\(signature)`'s braces never balance")
        return ""
    }

    @Test("Both hubs read the one model on AppState, and neither builds its own")
    func bothHubsReadAppStatesModel() throws {
        for hub in Self.hubs {
            let text = try Self.source(hub.path)
            #expect(text.contains("private var volumeList: DownloadedVolumesListModel { appState.downloadedVolumes }"),
                    "\(hub.path) does not read its model from AppState")
            #expect(!text.contains("DownloadedVolumesListModel()"), """
                \(hub.path) builds a model of its own. A hub the reader leaves and re-enters is a \
                new hub: a model it holds is forgotten with it, and a removal still running from \
                the old one marks and re-measures into a model nobody draws.
                """)
            #expect(text.contains("model: volumeList,"), "\(hub.path) does not hand the model to its list")
        }
    }

    @Test("Both hubs remove through the shared routing, not an inline loop")
    func bothHubsRemoveThroughTheRouting() throws {
        for hub in Self.hubs {
            let removal = try Self.body(of: "private func removeVolumes(_ volumeIds: [String]) async",
                                        in: try Self.source(hub.path))
            #expect(removal.contains("volumeList.removeVolumes(volumeIds, in: appState, context: modelContext"),
                    "\(hub.path)'s removeVolumes does not call the shared routing:\n\(removal)")
            #expect(!removal.contains("pipeline.removeVolume(") && !removal.contains("deleteVolume("), """
                \(hub.path)'s removeVolumes runs removal steps of its own. They mark nothing: the row \
                reads `indexed` until the re-measure, which is #1356.
                \(removal)
                """)
        }
    }

    @Test("Both hubs build Free Up Space's plan through the model, which withholds a removal under way")
    func bothHubsPlanThroughTheModel() throws {
        for hub in Self.hubs {
            let plan = try Self.body(of: "private var removalPlan: StorageRemovalPlan",
                                     in: try Self.source(hub.path))
            #expect(plan.contains("volumeList.freeUpSpacePlan(redownloadableVolumeIds:"),
                    "\(hub.path)'s removalPlan bypasses the model:\n\(plan)")
        }
    }

    @Test("Both full lists draw the model's status line and withdraw a removing row's actions")
    func bothListsDrawTheModelsStatusLine() throws {
        for hub in Self.hubs {
            let row = try Self.body(of: "private func row(_ entry: VolumeStorageEntry) -> some View",
                                    in: try Self.source(hub.path), after: hub.list)
            #expect(row.contains("Text(model.statusLine(for: entry))"), """
                \(hub.list)'s row does not draw the model's status line, so it cannot read \
                *removing…*:
                \(row)
                """)
            #expect(row.contains("let removing = model.isRemoving(entry.volumeId)"),
                    "\(hub.list)'s row does not ask whether its volume is being removed")
            #expect(row.contains(hub.withdrawal), """
                \(hub.list)'s row still offers Remove while its volume is being removed; a second \
                removal would race the first.
                """)
        }
    }
}
