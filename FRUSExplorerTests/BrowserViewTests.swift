// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

/// Tests for BrowserViewModel navigation, grouping, filtering, and tag display helpers.
@MainActor
struct BrowserViewTests {

    // MARK: - Helpers

    private func makeEntry(
        volumeId: String,
        subseries: String,
        title: String = "Test Volume",
        tags: [String] = [],
        documentCount: Int = 0,
        status: VolumeStatus = .published
    ) -> VolumeManifestEntry {
        VolumeManifestEntry(
            volumeId: volumeId,
            filename: "\(volumeId).xml",
            subseries: subseries,
            title: title,
            dateRange: DateRange(earliest: "1969-01-01", latest: "1972-12-31"),
            publicationDate: "2003",
            status: status,
            editors: [],
            generalEditor: nil,
            documentCount: documentCount,
            sizeBytes: 1_000_000,
            tags: tags
        )
    }

    private func makeViewModel(volumes: [VolumeManifestEntry] = []) -> BrowserViewModel {
        let store = ManifestStore(bundledEntries: volumes)
        let tagStore = VolumeLevelTagStore()
        return BrowserViewModel(
            manifestStore: store,
            tagStore: tagStore,
            downloadManager: nil,
            indexingPipeline: nil
        )
    }

    // MARK: - Initialisation

    @Test("BrowserViewModel initialises with empty navigation path")
    func initEmptyNavigationPath() {
        let vm = makeViewModel()
        #expect(vm.navigationPath.isEmpty)
    }

    @Test("BrowserViewModel initialises with no tag filters")
    func initNoTagFilters() {
        let vm = makeViewModel()
        #expect(vm.tagFilters.isEmpty)
    }

    // MARK: - Subseries Grouping

    @Test("allSubseriesGroups groups volumes by subseries identifier")
    func groupsBySubseries() {
        let entries = [
            makeEntry(volumeId: "frus1969-76v01", subseries: "1969-76"),
            makeEntry(volumeId: "frus1969-76v02", subseries: "1969-76"),
            makeEntry(volumeId: "frus1977-80v01", subseries: "1977-80"),
        ]
        let vm = makeViewModel(volumes: entries)
        #expect(vm.allSubseriesGroups.count == 2)
        let group6976 = vm.allSubseriesGroups.first { $0.subseries == "1969-76" }
        #expect(group6976?.volumes.count == 2)
        let group7780 = vm.allSubseriesGroups.first { $0.subseries == "1977-80" }
        #expect(group7780?.volumes.count == 1)
    }

    @Test("allSubseriesGroups sorts groups chronologically by start year")
    func groupsSortedByStartYear() {
        let entries = [
            makeEntry(volumeId: "frus1977-80v01", subseries: "1977-80"),
            makeEntry(volumeId: "frus1961-63v01", subseries: "1961-63"),
            makeEntry(volumeId: "frus1969-76v01", subseries: "1969-76"),
        ]
        let vm = makeViewModel(volumes: entries)
        let years = vm.allSubseriesGroups.map(\.startYear)
        #expect(years == years.sorted())
    }

    // MARK: - Filtered Volumes

    @Test("filteredVolumes with no active filter returns all volumes in subseries")
    func filteredVolumesNoFilter() {
        let entries = [
            makeEntry(volumeId: "frus1969-76v01", subseries: "1969-76"),
            makeEntry(volumeId: "frus1969-76v02", subseries: "1969-76"),
        ]
        let vm = makeViewModel(volumes: entries)
        let result = vm.filteredVolumes(for: "1969-76")
        #expect(result.count == 2)
    }

    @Test("filteredVolumes with unknown subseries returns empty array")
    func filteredVolumesUnknownSubseries() {
        let vm = makeViewModel()
        let result = vm.filteredVolumes(for: "nonexistent")
        #expect(result.isEmpty)
    }

    // MARK: - Tag Filter Actions

    @Test("activateTagFilter inserts slug into tagFilters for subseries")
    func activateTagFilterInsertsSlug() {
        let vm = makeViewModel()
        vm.activateTagFilter(slug: "iran", forSubseries: "1969-76")
        #expect(vm.tagFilters["1969-76"]?.contains("iran") == true)
    }

    @Test("activateTagFilter with navigation deeper than subseries pops to subseries level")
    func activateTagFilterPopsNavigation() {
        let entry = makeEntry(volumeId: "frus1969-76v01", subseries: "1969-76")
        let vm = makeViewModel(volumes: [entry])
        let group = vm.allSubseriesGroups.first { $0.subseries == "1969-76" }!
        vm.navigationPath = [.subseries(group), .volume(entry)]
        vm.activateTagFilter(slug: "iran", forSubseries: "1969-76")
        #expect(vm.navigationPath.count == 1)
        if case .subseries(let g) = vm.navigationPath[0] {
            #expect(g.subseries == "1969-76")
        } else {
            Issue.record("Expected .subseries at index 0")
        }
    }

    @Test("removeTagFilter removes a single slug from the active set")
    func removeTagFilterRemovesSlug() {
        let vm = makeViewModel()
        vm.tagFilters["1969-76"] = ["iran", "kissinger-henry-a"]
        vm.removeTagFilter(slug: "iran", forSubseries: "1969-76")
        #expect(vm.tagFilters["1969-76"]?.contains("iran") == false)
        #expect(vm.tagFilters["1969-76"]?.contains("kissinger-henry-a") == true)
    }

    @Test("clearTagFilters removes all filters for a subseries")
    func clearTagFiltersRemovesAll() {
        let vm = makeViewModel()
        vm.tagFilters["1969-76"] = ["iran", "kissinger-henry-a"]
        vm.clearTagFilters(forSubseries: "1969-76")
        #expect(vm.tagFilters["1969-76"] == nil)
    }

    // MARK: - SubseriesGroup Derived Statistics

    @Test("SubseriesGroup.publishedCount counts only published volumes")
    func subseriesGroupPublishedCount() {
        let entries = [
            makeEntry(volumeId: "v1", subseries: "1969-76", status: .published),
            makeEntry(volumeId: "v2", subseries: "1969-76", status: .partiallyPublished),
            makeEntry(volumeId: "v3", subseries: "1969-76", status: .planned),
        ]
        let vm = makeViewModel(volumes: entries)
        let group = vm.allSubseriesGroups.first { $0.subseries == "1969-76" }!
        #expect(group.publishedCount == 1)
        #expect(group.partiallyPublishedCount == 1)
        #expect(group.plannedCount == 1)
    }

    @Test("SubseriesGroup.startYear parses first four characters of subseries identifier")
    func subseriesGroupStartYear() {
        let entries = [makeEntry(volumeId: "v1", subseries: "1969-76")]
        let vm = makeViewModel(volumes: entries)
        let group = vm.allSubseriesGroups.first!
        #expect(group.startYear == 1969)
    }
}
