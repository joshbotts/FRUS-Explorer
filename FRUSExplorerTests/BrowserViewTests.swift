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
///
/// Version history:
///   1.0 — Session 11: initial implementation
///   1.1 — Wave R / R-9: coverage for the `indexingPipeline` back-fill and for
///          `indexVolume`'s missing-pipeline guard, which used to return silently
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

    // MARK: - Indexing-Pipeline Back-Fill (R-9)

    /// Builds a real `IndexingPipeline` over a temp database. `BrowserViewModel` only stores and
    /// nil-checks the pipeline, so nothing here needs a volume on disk.
    private func makePipeline() throws -> (IndexingPipeline, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("BrowserViewTests-\(UUID().uuidString)", isDirectory: true)
        let volumes = dir.appendingPathComponent("volumes", isDirectory: true)
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("test.sqlite")
        let store = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: store, databaseURL: dbURL, volumesDirectory: volumes
        )
        return (pipeline, dir)
    }

    @Test("R-9: attachIndexingPipelineIfNeeded back-fills a nil pipeline")
    func attachIndexingPipelineBackFills() throws {
        let vm = makeViewModel()
        #expect(vm.indexingPipeline == nil,
                "Precondition: the view model boots with no pipeline, exactly as BrowserView's onAppear bootstrap does when AppState has not assigned one yet")
        let (pipeline, dir) = try makePipeline()
        defer { try? FileManager.default.removeItem(at: dir) }

        vm.attachIndexingPipelineIfNeeded(pipeline)
        #expect(vm.indexingPipeline != nil,
                "The pipeline must be back-filled — without it isIndexed() answers false for every volume for the rest of the session (R-9)")
    }

    @Test("R-9: attachIndexingPipelineIfNeeded never replaces a live pipeline")
    func attachIndexingPipelineIsIdempotent() throws {
        let (first, firstDir) = try makePipeline()
        let (second, secondDir) = try makePipeline()
        defer {
            try? FileManager.default.removeItem(at: firstDir)
            try? FileManager.default.removeItem(at: secondDir)
        }
        let store = ManifestStore(bundledEntries: [])
        let vm = BrowserViewModel(
            manifestStore: store,
            tagStore: VolumeLevelTagStore(),
            downloadManager: nil,
            indexingPipeline: first
        )

        vm.attachIndexingPipelineIfNeeded(second)
        #expect(vm.indexingPipeline === first,
                "Back-filling must be a no-op once a pipeline is attached — the onChange observer can fire more than once and must never swap a live pipeline out")
    }

    @Test("R-9: attachIndexingPipelineIfNeeded(nil) is a no-op")
    func attachIndexingPipelineIgnoresNil() {
        let vm = makeViewModel()
        vm.attachIndexingPipelineIfNeeded(nil)
        #expect(vm.indexingPipeline == nil)
    }

    @Test("R-9: indexVolume with no pipeline records an error instead of failing mutely")
    func indexVolumeWithoutPipelineSetsError() async {
        let entry = makeEntry(volumeId: "frus1969-76v01", subseries: "1969-76")
        let vm = makeViewModel(volumes: [entry])
        #expect(vm.indexingError == nil, "Precondition: no error before the call")

        await vm.indexVolume(entry)

        // The whole point: CompilationView renders `indexingError`, so a nil here is a button
        // that does nothing and explains nothing — the part of R-9 that cost the most to
        // diagnose.
        #expect(vm.indexingError as? BrowserIndexingError == .pipelineUnavailable,
                "indexVolume must publish BrowserIndexingError.pipelineUnavailable when it has no pipeline, so the UI can say why nothing happened")
        #expect(vm.isIndexing == false,
                "A refused index must not leave the view in its indexing state")
        let message = BrowserIndexingError.pipelineUnavailable.errorDescription ?? ""
        #expect(!message.isEmpty, "The error must carry a user-readable message")
        #expect(!message.lowercased().contains("try again"),
                "The message must not promise that retrying helps — when FTS5Store failed to open at boot the pipeline is nil for the whole session and no number of taps can change that")
    }

    @Test("R-9: isIndexed answers false with no pipeline, which is why the banner could lie")
    func isIndexedWithoutPipelineIsFalse() {
        let vm = makeViewModel()
        #expect(vm.isIndexed("frus1969-76v01") == false,
                "Pins the ambiguity the fix works around: a nil pipeline is indistinguishable from an unindexed volume at this call site, so CompilationView must ask about the pipeline separately rather than trusting this answer")
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
    //
    // `aboutCommandGroupPresentsAboutView` was deleted here, and it is worth recording why, because
    // its presence is the reason nobody noticed the About window had no environment. It asserted on
    // `appState.showAbout` — a property removed in Session 61 when About became a `Window` scene
    // (see the note at AppState.swift:71). It kept compiling only because it sat inside
    // `#if os(macOS)` while this bundle is `platform: iOS` (project.yml:362), so the block was never
    // compiled by anything. A test naming the exact menu item that crashed, asserting on a property
    // that no longer exists, in code no compiler had read for months.
    //
    // `SceneEnvironmentAuditTests` replaces it with something that can actually fail.
}
