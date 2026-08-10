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
