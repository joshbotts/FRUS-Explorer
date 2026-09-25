// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
import Observation
import SwiftUI
@testable import FRUSExplorer

/// Tests for BrowserViewModel navigation, grouping, filtering, and tag display helpers.
///
/// Version history:
///   1.0 — Session 11: initial implementation
///   1.1 — Wave R / R-9: coverage for the `indexingPipeline` back-fill and for
///          `indexVolume`'s missing-pipeline guard, which used to return silently
///   1.2 — #1363: `BrowseLevelMemoryTests`, below, for the per-level memory
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

    // MARK: - #777: side-loaded volumes in the counts

    /// A side-loaded entry mints `status: .published` (its TEI header carries no status), and
    /// `publishedCount` counting it is the shipped "553 of 552": a subseries claiming one more
    /// published volume than the series has. Published means published BY THE CATALOGUE;
    /// side-loaded files are counted separately, and both numbers stay honest.
    @Test("A side-loaded volume is not counted as published")
    func sideloadedVolumeCountsSeparately() {
        var side = makeEntry(volumeId: "frusSIDE", subseries: "1969-1976",
                              title: "Side-loaded volume", status: .published)
        side.provenance = .sideloaded
        let group = SubseriesGroup(subseries: "1969-1976", volumes: [
            makeEntry(volumeId: "frus1969-76v01", subseries: "1969-1976",
                       title: "Published volume", status: .published),
            side,
        ])
        #expect(group.publishedCount == 1, """
            The side-loaded entry inflated the published count — the catalogue has one \
            published volume here, and the pill must say one.
            """)
        #expect(group.sideloadedCount == 1)
        #expect(group.totalVolumes == 2, "the volume is still real and still counted as itself")
    }
}

// MARK: - BrowseLevelMemoryTests (#1363)

/// #1363 — what a reader set on a Browse level lives exactly as long as that level is on the path:
/// through a push above it and the pop back, and no longer once the path shrinks past it or
/// `select(_:)` replaces it.
///
/// ## Why the model and not the view
/// The iPad two-pane draws only the path's last level, so Back from a level pushed above Archives
/// mounts a NEW `ArchivesIndexView`, and crossing the two-pane gate swaps the whole layout and
/// mounts every level on the path again. State the view held died with it: the issue's
/// reproduction came back on Provenance Types with its search gone. `BrowserViewModel` outlives
/// every one of those mounts, and these tests drive the calls the level mounts make —
/// `memoryBinding(for:_:)`, and the `memory(for:)` / `updateMemory(for:_:)` pair it reads and
/// writes through. The device checks are in `BrowseNestedSectionTests`:
/// `testLevelStateSurvivesBackInTwoPane`, which can fail only on an iPad at two-pane width, and
/// `testLevelStateSurvivesTheTwoPaneGate`, which rotates across the gate and needs an iPad mini.
///
/// Every test that reads the model first writes a memory and checks that it reads back, so none of
/// them can pass by finding the empty memory a store that kept nothing would also return. The last
/// but one is pure: `ArchivesIndexView.ReaderState.show(_:)`, the rule that keeps the collection
/// search's lifetime within a visit what it was.
///
/// Version history:
///   1.0 — #1363: initial implementation
@MainActor
struct BrowseLevelMemoryTests {

    /// A collection pushed above Archives, as a collection row does.
    private static let collection =
        BrowserViewModel.BrowserLevel.archivalCollection(id: "clifford", name: "Clark Clifford Papers")
    /// Another collection, for the replacement step.
    private static let otherCollection =
        BrowserViewModel.BrowserLevel.archivalCollection(id: "rusk", name: "Rusk Appointment Books")

    /// The Archives state the issue's reproduction leaves behind — the Collections lens and a
    /// search — plus one closed era and one closed group, so both collapse sets are pinned too.
    private static var narrowed: ArchivesIndexView.ReaderState {
        var state = ArchivesIndexView.ReaderState()
        state.lens = .collections
        state.collectionSearch = "Clark Clifford"
        state.collapsedEras = ["decimal-1910-1949"]
        state.collapsedCollectionGroups = ["repository:National Archives"]
        return state
    }

    private func makeViewModel() -> BrowserViewModel {
        BrowserViewModel(manifestStore: ManifestStore(bundledEntries: []),
                         tagStore: VolumeLevelTagStore(),
                         downloadManager: nil,
                         indexingPipeline: nil)
    }

    /// Opens Archives from the root and narrows it, checking that the write was kept.
    private func openNarrowedArchives(_ vm: BrowserViewModel) {
        vm.select(.archives)
        vm.updateMemory(for: .archives) { $0.archives = Self.narrowed }
        #expect(vm.memory(for: .archives).archives == Self.narrowed,
                "Precondition: a write from the level on screen must be kept")
    }

    /// Pushes the collection above Archives and gives it a memory of its own, checking the write.
    private func pushCollectionWithMemory(_ vm: BrowserViewModel) {
        vm.navigationPath.append(Self.collection)
        vm.updateMemory(for: Self.collection) { $0.catalogueSearch = "collection's own" }
        #expect(vm.memory(for: Self.collection).catalogueSearch == "collection's own",
                "Precondition: the pushed level's write must be kept")
    }

    @Test("A level's memory survives a push above it and the pop back — the two-pane's Back")
    func memorySurvivesAPushAndPopAboveIt() {
        let vm = makeViewModel()
        openNarrowedArchives(vm)

        vm.navigationPath.append(Self.collection)
        #expect(vm.memory(for: .archives).archives == Self.narrowed,
                "Pushing a collection above Archives dropped the Archives memory")

        // The two-pane's Back.
        vm.navigationPath.removeLast()
        #expect(vm.memory(for: .archives).archives == Self.narrowed, """
            Back from the collection returned to Archives without the lens and search the reader \
            left — the issue's reproduction (#1363)
            """)

        // The stack's pop, which assigns the shorter path whole through its binding.
        vm.navigationPath.append(Self.collection)
        vm.navigationPath = Array(vm.navigationPath.prefix(1))
        #expect(vm.memory(for: .archives).archives == Self.narrowed,
                "A pop that assigns the shorter path whole dropped the memory of the level it kept")
    }

    @Test("select(_:) replaces the path and every level's memory, and leaves the Topic index alone")
    func selectForgetsTheLevelsItReplaces() {
        let vm = makeViewModel()
        openNarrowedArchives(vm)
        pushCollectionWithMemory(vm)
        vm.topicIndex.post(.all)

        vm.select(.catalogue)
        #expect(vm.levelMemorySlots.isEmpty, "select(_:) kept \(vm.levelMemorySlots)")

        // Archives chosen again from the root opens anew, as a phone's stack opens it.
        vm.select(.archives)
        #expect(vm.memory(for: .archives) == BrowserViewModel.LevelMemory(), """
            Archives chosen again from the root came back narrowed: select(_:) must forget the \
            levels it replaces
            """)
        #expect(vm.topicIndex.pending != nil, """
            select(_:) emptied the Topic index's waiting hand-off, which a hand-off posts BEFORE it \
            selects the index (#1365) — the index would open whole instead of where it was sent
            """)
    }

    @Test("select(_:) of the level already on screen opens it anew — the two-pane's list pane")
    func selectingTheLevelOnScreenForgetsIt() {
        let vm = makeViewModel()
        openNarrowedArchives(vm)

        // The iPad two-pane keeps the root beside the level, so its Archives tile can be tapped
        // with Archives on screen: the path is assigned an EQUAL value, and the view stays.
        vm.select(.archives)
        #expect(vm.memory(for: .archives) == BrowserViewModel.LevelMemory(),
                "The Archives tile, tapped beside a narrowed Archives, left it narrowed")
    }

    @Test("A memory is gone once the path shrinks past its level")
    func shrinkingPastALevelForgetsIt() {
        let vm = makeViewModel()
        openNarrowedArchives(vm)
        pushCollectionWithMemory(vm)

        vm.navigationPath.removeLast()
        vm.navigationPath.append(Self.collection)
        #expect(vm.memory(for: Self.collection) == BrowserViewModel.LevelMemory(),
                "A collection popped and pushed again kept what its earlier visit set")
        #expect(vm.memory(for: .archives).archives == Self.narrowed,
                "Popping the collection took the memory of the level beneath it too")

        // Back to the empty path — the breadcrumb's root, or the two-pane's Back at depth one —
        // and Archives put back WITHOUT select(_:), so only the shrink can have cleared it.
        vm.navigationPath = []
        #expect(vm.levelMemorySlots.isEmpty, "The emptied path kept \(vm.levelMemorySlots)")
        vm.navigationPath = [.archives]
        #expect(vm.memory(for: .archives) == BrowserViewModel.LevelMemory(),
                "Archives came back narrowed after the path had shrunk past it")
    }

    @Test("A level replaced at its position does not inherit the memory of the one it replaced")
    func aReplacedLevelStartsFresh() {
        let vm = makeViewModel()
        openNarrowedArchives(vm)
        pushCollectionWithMemory(vm)

        // The same depth, another level — the shape of a page turn's `.replace`. The path's length
        // does not change, so a rule that compared lengths alone would keep the memory.
        vm.navigationPath[1] = Self.otherCollection
        #expect(vm.memory(for: Self.otherCollection) == BrowserViewModel.LevelMemory(),
                "The level put in the collection's place inherited its memory")
        vm.navigationPath[1] = Self.collection
        #expect(vm.memory(for: Self.collection) == BrowserViewModel.LevelMemory(),
                "The collection's memory outlived its replacement")
        #expect(vm.memory(for: .archives).archives == Self.narrowed,
                "Replacing the level above Archives took the Archives memory too")
    }

    @Test("Only the level on screen writes: not one under a push, not one off the path, not on an empty path")
    func onlyTheLevelOnScreenWrites() {
        let vm = makeViewModel()
        openNarrowedArchives(vm)

        // A level under a push. The two-pane REMOVES it, and whatever a torn-down view writes on
        // the way out — a search field emptied as it goes — must not reach the memory Back reads.
        vm.navigationPath.append(Self.collection)
        vm.updateMemory(for: .archives) { $0.archives = ArchivesIndexView.ReaderState() }
        vm.navigationPath.removeLast()
        #expect(vm.memory(for: .archives).archives == Self.narrowed,
                "A write from Archives while a collection sat above it replaced the memory Back reads")

        // A level not on the path at all.
        vm.updateMemory(for: .catalogue) { $0.catalogueSearch = "Malta" }
        #expect(vm.memory(for: .catalogue) == BrowserViewModel.LevelMemory())
        #expect(vm.levelMemorySlots.count == 1, "A level off the path wrote: \(vm.levelMemorySlots)")

        // The empty path, which has no level on screen.
        vm.navigationPath = []
        vm.updateMemory(for: .archives) { $0.archives = Self.narrowed }
        #expect(vm.levelMemorySlots.isEmpty, "The empty path took a write: \(vm.levelMemorySlots)")
    }

    @Test("A write that leaves a memory as it was tells no observer it changed")
    func anUnchangedWriteDoesNotNotify() {
        let vm = makeViewModel()
        openNarrowedArchives(vm)

        let unchanged = ObservationFlag()
        withObservationTracking { _ = vm.levelMemorySlots } onChange: { unchanged.fire() }
        vm.updateMemory(for: .archives) { $0.archives = Self.narrowed }
        #expect(!unchanged.fired, """
            Setting the Archives memory to the value it held notified its observers — a binding that \
            writes back what it read would redraw every view reading the memory, for nothing
            """)

        // The control: a real change notifies, so the silence above is not a tracker that never fires.
        let changed = ObservationFlag()
        withObservationTracking { _ = vm.levelMemorySlots } onChange: { changed.fire() }
        vm.updateMemory(for: .archives) { $0.archives.collectionSearch = "Clifford" }
        #expect(changed.fired, "Precondition: a changed memory must notify its observers")
    }

    @Test("Leaving the Collections lens empties its search, as tearing the list down always did")
    func aLensSwitchEmptiesTheCollectionSearch() {
        var state = Self.narrowed
        state.show(.types)
        #expect(state.lens == .types)
        #expect(state.collectionSearch.isEmpty, """
            The collection search outlived a switch to Provenance Types; before #1363 the list held \
            it and the switch tore it down, on every platform
            """)
        #expect(state.collapsedCollectionGroups == Self.narrowed.collapsedCollectionGroups,
                "The closed groups are held on the axis so that a lens switch keeps them")
        #expect(state.collapsedEras == Self.narrowed.collapsedEras)

        // Choosing the lens already on screen is not leaving it.
        var stays = Self.narrowed
        stays.show(.collections)
        #expect(stays == Self.narrowed, "Re-choosing Collections emptied its search")
    }

    @Test("The mounts' binding reads and writes each level's memory")
    func theMountBindingDrivesTheMemory() {
        let vm = makeViewModel()
        vm.select(.archives)
        vm.memoryBinding(for: .archives, \.archives.lens).wrappedValue = .collections
        vm.memoryBinding(for: .archives, \.archives.collectionSearch).wrappedValue = "Clark Clifford"
        #expect(vm.memory(for: .archives).archives.lens == .collections,
                "Precondition: the binding's write must reach the memory")

        vm.navigationPath.append(Self.collection)
        vm.navigationPath.removeLast()
        // New bindings, as a re-mounted view makes.
        #expect(vm.memoryBinding(for: .archives, \.archives.lens).wrappedValue == .collections)
        #expect(vm.memoryBinding(for: .archives, \.archives.collectionSearch).wrappedValue
                == "Clark Clifford")

        vm.select(.catalogue)
        vm.memoryBinding(for: .catalogue, \.catalogueSearch).wrappedValue = "Malta"
        vm.navigationPath.append(.volumeList(VolumeListSpec(
            axisKey: "archives:category:lotFile", title: "Lot Files", volumeIds: [])))
        vm.navigationPath.removeLast()
        #expect(vm.memoryBinding(for: .catalogue, \.catalogueSearch).wrappedValue == "Malta")

        vm.select(.editors)
        vm.memoryBinding(for: .editors, \.editorsSearch).wrappedValue = "Humphrey"
        vm.navigationPath.append(.volumeList(VolumeListSpec(
            axisKey: "editor:David C. Humphrey", title: "David C. Humphrey", volumeIds: [])))
        vm.navigationPath.removeLast()
        #expect(vm.memoryBinding(for: .editors, \.editorsSearch).wrappedValue == "Humphrey")
    }
}

/// Records that an observation's `onChange` fired. `withObservationTracking` hands `onChange` a
/// `@Sendable` closure, which cannot capture a `var`; the change it reports is delivered on the
/// thread that made it — here, the main actor that runs these tests.
private final class ObservationFlag: @unchecked Sendable {
    /// Whether `onChange` fired.
    private(set) var fired = false

    /// Records the firing.
    func fire() { fired = true }
}
