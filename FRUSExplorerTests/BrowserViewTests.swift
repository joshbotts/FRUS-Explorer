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

    @Test("allSubseriesGroups sorts groups chronologically by start year (most recent first)")
    func groupsSortedByStartYear() {
        let entries = [
            makeEntry(volumeId: "frus1977-80v01", subseries: "1977-80"),
            makeEntry(volumeId: "frus1961-63v01", subseries: "1961-63"),
            makeEntry(volumeId: "frus1969-76v01", subseries: "1969-76"),
        ]
        let vm = makeViewModel(volumes: entries)
        let years = vm.allSubseriesGroups.map(\.startYear)
        #expect(years == years.sorted(by: >))
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

    // MARK: - BrowserFilterTests

    @Test("BrowserFilterTest: filterDownloadedOnly=true hides non-downloaded volumes")
    func filterToggleHidesNonDownloadedVolumes() {
        // makeViewModel passes downloadManager: nil, so isDownloaded always returns false.
        let entries = [
            makeEntry(volumeId: "frus1969-76v01", subseries: "1969-76"),
            makeEntry(volumeId: "frus1969-76v02", subseries: "1969-76"),
        ]
        let vm = makeViewModel(volumes: entries)
        vm.filterDownloadedOnly = true
        let result = vm.filteredVolumes(for: "1969-76")
        #expect(result.isEmpty,
                "With no downloads and filterDownloadedOnly=true, filteredVolumes must be empty")
    }

    @Test("BrowserFilterTest: filterDownloadedOnly=false shows all volumes")
    func filterOffShowsAllVolumes() {
        let entries = [
            makeEntry(volumeId: "frus1969-76v01", subseries: "1969-76"),
            makeEntry(volumeId: "frus1969-76v02", subseries: "1969-76"),
        ]
        let vm = makeViewModel(volumes: entries)
        vm.filterDownloadedOnly = false
        let result = vm.filteredVolumes(for: "1969-76")
        #expect(result.count == 2,
                "With filterDownloadedOnly=false, all volumes must be returned")
    }

    @Test("BrowserFilterTest: filterDownloadedOnly=true hides subseries with no downloads")
    func filterToggleHidesSubseriesWithNoDownloads() {
        let entries = [
            makeEntry(volumeId: "frus1969-76v01", subseries: "1969-76"),
            makeEntry(volumeId: "frus1977-80v01", subseries: "1977-80"),
        ]
        let vm = makeViewModel(volumes: entries)
        vm.filterDownloadedOnly = true
        // downloadManager is nil → no volumes downloaded → all subseries filtered out
        #expect(vm.allSubseriesGroups.isEmpty,
                "With no downloads, allSubseriesGroups must be empty when filterDownloadedOnly=true")
    }

    @Test("BrowserFilterTest: filterDownloadedOnly is persisted via AppState to UserDefaults")
    func filterTogglePersistedToUserDefaults() {
        let key = "frus.filterDownloadedOnly"
        let appState = AppState()
        appState.filterDownloadedOnly = true
        #expect(UserDefaults.standard.bool(forKey: key) == true)
        // Restore
        appState.filterDownloadedOnly = false
        #expect(UserDefaults.standard.bool(forKey: key) == false)
    }

    // MARK: - BreadcrumbLayoutTests

    @Test("BreadcrumbLayoutTest: single item is assigned to row 0")
    func singleCrumbFitsOnOneLine() {
        let assignments = BreadcrumbFlowLayout.computeRowAssignments(
            itemWidths: [80],
            containerWidth: 300,
            horizontalSpacing: 4
        )
        #expect(assignments == [0], "A single item must be on row 0")
    }

    @Test("BreadcrumbLayoutTest: items that overflow container width wrap to new rows")
    func longPathWrapsToMultipleLines() {
        // Five items each 120pt wide, 4pt spacing, 300pt container.
        // Row 0: item 0 (120) + 4 + item 1 (120) = 244 ≤ 300 ✓
        //         244 + 4 + 120 = 368 > 300 → item 2 wraps
        // Row 1: item 2 (120) + 4 + item 3 (120) = 244 ≤ 300 ✓
        //         244 + 4 + 120 = 368 > 300 → item 4 wraps
        // Row 2: item 4 (120)
        let assignments = BreadcrumbFlowLayout.computeRowAssignments(
            itemWidths: [120, 120, 120, 120, 120],
            containerWidth: 300,
            horizontalSpacing: 4
        )
        #expect(assignments == [0, 0, 1, 1, 2],
                "Expected row assignments [0,0,1,1,2], got \(assignments)")
    }

    // MARK: - MacAboutMenuTests

    #if os(macOS)
    @Test("MacAboutMenuTest: AppState.showAbout starts false and can be set to true")
    func aboutCommandGroupPresentsAboutView() {
        let appState = AppState()
        #expect(!appState.showAbout,
                "showAbout must start false so the About sheet is not shown on launch")
        // Simulates what CommandGroup(replacing: .appInfo) does when the menu item is tapped
        appState.showAbout = true
        #expect(appState.showAbout,
                "showAbout must be settable to true to trigger the About sheet")
    }
    #endif
}
