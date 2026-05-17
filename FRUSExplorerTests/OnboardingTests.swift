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
        let tagStore = VolumeLevelTagStore(taxonomyEntries: [], manifestEntries: entries)
        let vm = OnboardingViewModel(manifestStore: store, tagStore: tagStore, volumesDirectory: nil)

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
        let tagStore = VolumeLevelTagStore(taxonomyEntries: [], manifestEntries: entries)
        let vm = OnboardingViewModel(manifestStore: store, tagStore: tagStore, volumesDirectory: nil)

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
        let tagStore = VolumeLevelTagStore(taxonomyEntries: [], manifestEntries: [])
        let vm = OnboardingViewModel(manifestStore: store, tagStore: tagStore, volumesDirectory: nil)

        vm.projectName = ""
        #expect(vm.canProceedFromProjectSetup == false)

        vm.projectName = "   "
        #expect(vm.canProceedFromProjectSetup == false)

        vm.projectName = "Cold War Diplomacy"
        #expect(vm.canProceedFromProjectSetup == true)
    }
}
