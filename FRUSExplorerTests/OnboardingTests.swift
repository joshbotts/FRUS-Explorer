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

// MARK: - Volume Picker Tests

@Suite("Onboarding — volume picker")
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

    private func makeTaxonomyEntry(slug: String, category: String = "topics") -> TagTaxonomyEntry {
        TagTaxonomyEntry(
            slug: slug,
            displayName: slug.capitalized,
            category: category,
            subcategory: "general",
            parentSlug: nil,
            description: nil
        )
    }

    // MARK: - Tests

    @Test("volumesBySubseries groups and sorts by start year")
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

        let groups = vm.volumesBySubseries
        #expect(groups.count == 3)
        #expect(groups[0].subseries == "1861")
        #expect(groups[1].subseries == "1969-76")
        #expect(groups[1].volumes.count == 2)
        #expect(groups[2].subseries == "1977-80")
    }

    @Test("tag filter returns only volumes with selected tag")
    func singleTagFilter() {
        let entries = [
            makeEntry(volumeId: "frus1969v01", subseries: "1969-76", tags: ["iran"]),
            makeEntry(volumeId: "frus1969v02", subseries: "1969-76", tags: ["vietnam"]),
            makeEntry(volumeId: "frus1977v01", subseries: "1977-80", tags: ["iran"]),
        ]
        let taxonomyEntries = [
            makeTaxonomyEntry(slug: "iran"),
            makeTaxonomyEntry(slug: "vietnam"),
        ]
        let store = ManifestStore(bundledEntries: entries)
        let tagStore = VolumeLevelTagStore(taxonomyEntries: taxonomyEntries, manifestEntries: entries)
        let vm = OnboardingViewModel(manifestStore: store, tagStore: tagStore, volumesDirectory: nil)

        vm.sortMode = .byTag
        vm.selectedTagSlugs = ["iran"]

        let displayed = vm.displayVolumes
        #expect(displayed.count == 2)
        #expect(displayed.contains { $0.volumeId == "frus1969v01" })
        #expect(displayed.contains { $0.volumeId == "frus1977v01" })
        #expect(!displayed.contains { $0.volumeId == "frus1969v02" })
    }

    @Test("multi-tag filter uses AND logic")
    func multiTagAndLogic() {
        let entries = [
            makeEntry(volumeId: "frus1969v01", subseries: "1969-76", tags: ["iran", "vietnam"]),
            makeEntry(volumeId: "frus1969v02", subseries: "1969-76", tags: ["iran"]),
            makeEntry(volumeId: "frus1977v01", subseries: "1977-80", tags: ["vietnam"]),
        ]
        let taxonomyEntries = [
            makeTaxonomyEntry(slug: "iran"),
            makeTaxonomyEntry(slug: "vietnam"),
        ]
        let store = ManifestStore(bundledEntries: entries)
        let tagStore = VolumeLevelTagStore(taxonomyEntries: taxonomyEntries, manifestEntries: entries)
        let vm = OnboardingViewModel(manifestStore: store, tagStore: tagStore, volumesDirectory: nil)

        vm.sortMode = .byTag
        vm.selectedTagSlugs = ["iran", "vietnam"]

        let displayed = vm.displayVolumes
        #expect(displayed.count == 1)
        #expect(displayed[0].volumeId == "frus1969v01")
    }

    @Test("activateTagFilter sets mode and adds slug")
    func activateTagFilter() {
        let store = ManifestStore(bundledEntries: [])
        let tagStore = VolumeLevelTagStore(taxonomyEntries: [], manifestEntries: [])
        let vm = OnboardingViewModel(manifestStore: store, tagStore: tagStore, volumesDirectory: nil)

        #expect(vm.sortMode == .bySubseries)
        #expect(vm.selectedTagSlugs.isEmpty)

        vm.activateTagFilter(slug: "iran")

        #expect(vm.sortMode == .byTag)
        #expect(vm.selectedTagSlugs.contains("iran"))
    }

    @Test("volumes under 20kb excluded from display")
    func smallVolumesExcluded() {
        let entries = [
            makeEntry(volumeId: "frus1969v01", subseries: "1969-76", sizeBytes: 50_000),
            makeEntry(volumeId: "frus1969v02", subseries: "1969-76", sizeBytes: 19_999),
            makeEntry(volumeId: "frus1977v01", subseries: "1977-80", sizeBytes: 20_000),
        ]
        let store = ManifestStore(bundledEntries: entries)
        let tagStore = VolumeLevelTagStore(taxonomyEntries: [], manifestEntries: entries)
        let vm = OnboardingViewModel(manifestStore: store, tagStore: tagStore, volumesDirectory: nil)

        let displayed = vm.displayVolumes
        #expect(displayed.count == 2)
        #expect(!displayed.contains { $0.volumeId == "frus1969v02" })
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
