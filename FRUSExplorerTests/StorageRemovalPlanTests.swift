// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
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
/// - a re-measure that still lists the volume (the delete failed): the row comes back as it is;
/// - a multi-volume removal (Free Up Space): every volume is marked from the start.
///
/// Version history:
///   1.0 — #1356: initial implementation
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
        // The file could not be deleted: the re-measure lists the volume again.
        await model.removeVolumes(["b"],
                                  unindex: { _ in },
                                  deleteFile: { _ in },
                                  remeasure: { model.report = Self.report(["a", "b", "c"]) })

        #expect(drawn(model) == ["a", "b", "c"], "a volume still on disk is still listed")
        #expect(!model.isRemoving("b"), "the mark ends with the routine, confirmed or not")
        #expect(model.indexState(of: "b") == .notIndexed, """
            Its index rows WERE deleted, so the row reads not indexed — not indexed, and not \
            removing.
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
