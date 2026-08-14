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

import Testing
import Foundation
@testable import FRUSExplorer

// MARK: - Onboarding Trigger Tests

@Suite("Onboarding — volume trigger")
struct OnboardingTriggerTests {

    @Test("hasDownloadedVolumes returns false for empty directory")
    func noXMLFilesReturnsFalse() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("onboarding-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        #expect(OnboardingViewModel.hasDownloadedVolumes(in: dir) == false)
    }

    @Test("hasDownloadedVolumes returns true when xml file exists")
    func xmlFileReturnsTrue() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("onboarding-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let xmlFile = dir.appendingPathComponent("frus1969-76v01.xml")
        try Data("<test/>".utf8).write(to: xmlFile)

        #expect(OnboardingViewModel.hasDownloadedVolumes(in: dir) == true)
    }
}

// MARK: - Volume / Subseries Tests

/// Tests for the Session 49 OnboardingViewModel.
///
/// The old volume-picker, tag-filter, and sortMode tests were removed in Session 49
/// because those features moved to `DownloadManagerSettingsView`. The tests below
/// cover the new `allSubseries`, `allVolumes`, and scope resolution APIs.
///
/// Version history:
///   1.0 — Session 10: initial implementation
///   2.0 — Session 49: updated for redesigned OnboardingViewModel API
@Suite("Onboarding — volume listing")
@MainActor
struct VolumePickerTests {

    // MARK: - Fixtures

    private func makeEntry(
        volumeId: String,
        subseries: String,
        title: String = "Test Volume",
        sizeBytes: Int = 50_000,
        tags: [String] = []
    ) -> VolumeManifestEntry {
        VolumeManifestEntry(
            volumeId: volumeId,
            filename: "\(volumeId).xml",
            subseries: subseries,
            title: title,
            dateRange: DateRange(earliest: "1969-01-01", latest: "1976-12-31"),
            publicationDate: nil,
            status: .published,
            editors: [],
            generalEditor: nil,
            documentCount: 100,
            sizeBytes: sizeBytes,
            tags: tags
        )
    }

    // MARK: - Tests

    @Test("allSubseries groups unique subseries sorted descending by start year")
    func subseriesGrouping() {
        let entries = [
            makeEntry(volumeId: "frus1977v01", subseries: "1977-80"),
            makeEntry(volumeId: "frus1861v01", subseries: "1861"),
            makeEntry(volumeId: "frus1969v01", subseries: "1969-76"),
            makeEntry(volumeId: "frus1969v02", subseries: "1969-76"),
        ]
        let store = ManifestStore(bundledEntries: entries)
        let vm = OnboardingViewModel(manifestStore: store, volumesDirectory: nil)

        let subseries = vm.allSubseries
        #expect(subseries.count == 3)
        // Descending order: 1977, 1969, 1861
        #expect(subseries[0] == "1977-80")
        #expect(subseries[1] == "1969-76")
        #expect(subseries[2] == "1861")
    }

    @Test("volumes under 20 KB excluded from allVolumes")
    func smallVolumesExcluded() {
        let entries = [
            makeEntry(volumeId: "frus1969v01", subseries: "1969-76", sizeBytes: 50_000),
            makeEntry(volumeId: "frus1969v02", subseries: "1969-76", sizeBytes: 19_999),
            makeEntry(volumeId: "frus1977v01", subseries: "1977-80", sizeBytes: 20_000),
        ]
        let store = ManifestStore(bundledEntries: entries)
        let vm = OnboardingViewModel(manifestStore: store, volumesDirectory: nil)

        let volumes = vm.allVolumes
        #expect(volumes.count == 2)
        #expect(!volumes.contains { $0.volumeId == "frus1969v02" })
    }
}

// MARK: - Project Setup Tests

@Suite("Onboarding — project setup")
@MainActor
struct ProjectSetupTests {

    @Test("canProceedFromProjectSetup requires non-empty name")
    func requiresName() {
        let store = ManifestStore(bundledEntries: [])
        let vm = OnboardingViewModel(manifestStore: store, volumesDirectory: nil)

        vm.projectName = ""
        #expect(vm.canProceedFromProjectSetup == false)

        vm.projectName = "   "
        #expect(vm.canProceedFromProjectSetup == false)

        vm.projectName = "Cold War Diplomacy"
        #expect(vm.canProceedFromProjectSetup == true)
    }
}

// MARK: - Root Routing Tests

/// Pins `AppRootRouter`'s decision, and above all the one it used to get wrong.
///
/// **The bug these exist for shipped past a green suite.** Onboarding's Skip button enqueues
/// nothing, so Skip → Finish wrote `hasCompletedOnboarding`, created the default project — every
/// side effect the existing tests assert, all succeeding — and then `ContentView` sent the reader
/// straight back to the Welcome page, permanently, because it required a volume on disk or in the
/// queue as well as the flag. The side effects were tested; the decision made *after* them was
/// not, because it lived in a view body. Hence `AppRootRouter`, and hence these.
@Suite("Onboarding — root routing")
struct AppRootRouterTests {

    /// Every case below is "onboarded and booted" unless it says otherwise, so each test varies
    /// exactly the fact it names.
    private func destination(hasCompletedOnboarding: Bool = true,
                             isBootComplete: Bool = true,
                             hasVolumes: Bool = false,
                             hasActiveDownloads: Bool = false,
                             hasFinishedOnboardingWithoutVolumes: Bool = false,
                             isUITestMode: Bool = false) -> AppRootDestination {
        AppRootRouter.destination(
            hasCompletedOnboarding: hasCompletedOnboarding,
            isBootComplete: isBootComplete,
            hasVolumes: hasVolumes,
            hasActiveDownloads: hasActiveDownloads,
            hasFinishedOnboardingWithoutVolumes: hasFinishedOnboardingWithoutVolumes,
            isUITestMode: isUITestMode)
    }

    @Test("THE SKIP DEAD END: finishing with an empty library reaches the app, not the wizard")
    func skipPathReachesTheApp() {
        // Exactly the state Skip → Finish leaves behind: onboarded, booted, nothing on disk,
        // nothing queued. Before the fix this returned `.onboarding` for ever.
        #expect(destination(hasFinishedOnboardingWithoutVolumes: true) == .main)
    }

    @Test("without that licence, an empty library still re-onboards — the deleted-everything case")
    func emptyLibraryWithoutLicenceReOnboards() {
        // The branch the AND was written for, and the only thing it should still mean: a reader
        // who HAD volumes and no longer does. Preserving this is why the fix needed a new fact
        // rather than a relaxed condition.
        #expect(destination(hasFinishedOnboardingWithoutVolumes: false) == .onboarding)
    }

    @Test("a reader who has never onboarded always gets the wizard")
    func neverOnboardedGetsWizard() {
        #expect(destination(hasCompletedOnboarding: false) == .onboarding)
        // Not even a live library or a mid-flight download lets a new reader past it…
        #expect(destination(hasCompletedOnboarding: false, hasVolumes: true) == .onboarding)
        #expect(destination(hasCompletedOnboarding: false, hasActiveDownloads: true) == .onboarding)
        // …and the empty-library licence must never be readable as "onboarding is done".
        #expect(destination(hasCompletedOnboarding: false,
                            hasFinishedOnboardingWithoutVolumes: true) == .onboarding)
    }

    @Test("#753: an onboarded reader waits on the placeholder, never on the first-run screen")
    func bootingNeverShowsTheWizard() {
        // `hasVolumes` reads the download manager, which is assigned at the END of boot, so a
        // researcher with hundreds of volumes is indistinguishable from one with none until boot
        // finishes. The placeholder is what stops the app telling them they have nothing.
        #expect(destination(isBootComplete: false) == .bootPlaceholder)
        #expect(destination(isBootComplete: false, hasVolumes: true) == .bootPlaceholder)
        // And the empty-library licence must not skip the wait either — it decides between app
        // and wizard, not between waiting and not.
        #expect(destination(isBootComplete: false,
                            hasFinishedOnboardingWithoutVolumes: true) == .bootPlaceholder)
    }

    @Test("volumes or an in-flight download reach the app on their own")
    func contentReachesTheApp() {
        #expect(destination(hasVolumes: true) == .main)
        #expect(destination(hasActiveDownloads: true) == .main)
    }

    @Test("UI-test mode reaches the app and does not wait for boot")
    func uiTestModeBypasses() {
        // #156: `-hasCompletedOnboarding 1` has to reach the main UI with no volumes at all.
        #expect(destination(isUITestMode: true) == .main)
        #expect(destination(isBootComplete: false, isUITestMode: true) == .main)
        // But it is not a skeleton key: a never-onboarded launch still starts at the wizard.
        #expect(destination(hasCompletedOnboarding: false, isUITestMode: true) == .onboarding)
    }
}

// MARK: - Empty-Finish Detection

@Suite("Onboarding — empty finish")
@MainActor
struct OnboardingEmptyFinishTests {

    @Test("only a finish with nothing on disk AND nothing queued counts as empty")
    func finishedEmptyRequiresBothToBeAbsent() {
        // All four combinations of a two-input predicate, so no term can be dropped unnoticed.
        #expect(OnboardingCompletion.finishedEmpty(hasVolumes: false, hasQueuedDownloads: false))
        #expect(!OnboardingCompletion.finishedEmpty(hasVolumes: true, hasQueuedDownloads: false))
        // The queue term is the one that is easy to think redundant and is not: Continue enqueues,
        // and at Finish time the volume has NOT landed yet, so a check that looked only at the
        // disk would mark a *downloading* reader as empty-handed and hand them the licence — and
        // the honest-copy branch — meant for someone who chose to download nothing.
        #expect(!OnboardingCompletion.finishedEmpty(hasVolumes: false, hasQueuedDownloads: true))
        #expect(!OnboardingCompletion.finishedEmpty(hasVolumes: true, hasQueuedDownloads: true))
    }
}
