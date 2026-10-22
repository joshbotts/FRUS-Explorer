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

/// The facet panel's state machine and its narrowing map (R-1b).
///
/// ## What is worth testing in a panel controller
/// Not the layout. Three things that are silently wrong if they break: a section computed for
/// one result set must never be shown beside another; a narrowing must write the same field
/// the filter sheet writes, or the two surfaces disagree; and "narrowed from N" must be the
/// count *before* the narrow, which is the one number the panel cannot recover after the fact.
///
/// Version history:
///   1.0 — R-1b: initial implementation
///   1.1 — FRUS Explorer Light: `load` takes no pipeline, since the search service computes the
///          section, so the fixture returns none; the narrowing map's tests moved to the kit's
///          `FacetNarrowingTests`, beside the narrowing
///   1.2 — #1758: `clearingDiscardsEverything`, the panel cleared when its search leaves the screen
@Suite("Facet panel controller")
@MainActor
struct FacetPanelControllerTests {

    // MARK: - Fixture

    private func makeFixture() async throws
        -> (dir: URL, service: SearchService) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSPanel-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("test.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        var xml = "<?xml version=\"1.0\"?>\n<TEI><text><body>\n"
        for index in 0..<10 {
            let kind = index.isMultiple(of: 2) ? "document" : "editorialNote"
            xml += """
            <div type="\(kind)" xml:id="d\(index)">
              <head>\(index + 1). Item</head>
              <dateline>Washington, \(1946 + index % 3)</dateline>
              <p>The doctrine of containment shaped policy toward europe.</p>
            </div>

            """
        }
        xml += "</body></text></TEI>"
        try xml.data(using: .utf8)!.write(to: volDir.appendingPathComponent("vol1.xml"))

        let fts5 = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: fts5, databaseURL: dbURL, volumesDirectory: volDir, concurrencyLimit: 1)
        try await pipeline.indexVolume("vol1")
        return (dir, SearchService(fts5Store: fts5, pipeline: pipeline))
    }

    private func cleanUp(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    // MARK: - Lazy loading

    @Test("Nothing is computed until a section is asked for")
    func nothingComputedUpFront() async throws {
        let controller = FacetPanelController()
        controller.invalidate(signature: "q1")
        #expect(controller.facets == nil)
        #expect(controller.loadedSections.isEmpty)
    }

    @Test("Loading a section computes only that section")
    func loadingOneSectionComputesOnlyIt() async throws {
        let (dir, service) = try await makeFixture()
        defer { cleanUp(dir) }

        let controller = FacetPanelController()
        controller.invalidate(signature: "q1")
        await controller.load(.volumes, parameters: SearchParameters(keywords: "containment"),
                              service: service)

        let facets = try #require(controller.facets)
        #expect(!facets.volumes.isEmpty)
        #expect(facets.years.isEmpty, "an unrequested section must not be computed")
        #expect(controller.loadedSections == [.volumes])
    }

    @Test("Loading a second section keeps the first")
    func sectionsAccumulate() async throws {
        let (dir, service) = try await makeFixture()
        defer { cleanUp(dir) }

        let controller = FacetPanelController()
        controller.invalidate(signature: "q1")
        let params = SearchParameters(keywords: "containment")
        await controller.load(.volumes, parameters: params, service: service)
        await controller.load(.years, parameters: params, service: service)

        let facets = try #require(controller.facets)
        #expect(!facets.volumes.isEmpty, "the first section must survive the second's merge")
        #expect(!facets.years.isEmpty)
        #expect(controller.loadedSections == [.volumes, .years])
    }

    @Test("Re-loading a computed section is a no-op")
    func reloadingIsANoOp() async throws {
        let (dir, service) = try await makeFixture()
        defer { cleanUp(dir) }

        let controller = FacetPanelController()
        controller.invalidate(signature: "q1")
        let params = SearchParameters(keywords: "containment")
        await controller.load(.volumes, parameters: params, service: service)
        let first = controller.facets
        await controller.load(.volumes, parameters: params, service: service)
        #expect(controller.facets == first)
    }

    @Test("No service is safe rather than a crash")
    func missingDependenciesAreSafe() async {
        let controller = FacetPanelController()
        controller.invalidate(signature: "q1")
        await controller.load(.volumes, parameters: SearchParameters(keywords: "x"),
                              service: nil)
        #expect(controller.facets == nil)
        #expect(controller.failure == nil, "an absent dependency is not an error to paint")
    }

    // MARK: - Invalidation

    /// The failure this guards against is the plausible-looking one: a facet from the
    /// previous result set shown beside the current one.
    @Test("A new search discards every computed section")
    func newSearchDiscardsEverything() async throws {
        let (dir, service) = try await makeFixture()
        defer { cleanUp(dir) }

        let controller = FacetPanelController()
        controller.invalidate(signature: "q1")
        await controller.load(.volumes, parameters: SearchParameters(keywords: "containment"),
                              service: service)
        #expect(controller.facets != nil)

        controller.invalidate(signature: "q2")
        #expect(controller.facets == nil)
        #expect(controller.loadedSections.isEmpty)
    }

    /// #1758: the field emptied, with no search in its place. Nothing narrowed, so a pre-count
    /// recorded for a narrowing that never landed does not survive either.
    @Test("A search taken off the screen discards every computed section and any pending pre-count")
    func clearingDiscardsEverything() async throws {
        let (dir, service) = try await makeFixture()
        defer { cleanUp(dir) }

        let controller = FacetPanelController()
        controller.invalidate(signature: "q1")
        await controller.load(.volumes, parameters: SearchParameters(keywords: "containment"),
                              service: service)
        controller.recordNarrowing(from: 5)
        #expect(controller.facets != nil)

        controller.clear()
        #expect(controller.facets == nil)
        #expect(controller.loadedSections.isEmpty)
        #expect(controller.narrowedFrom == nil, "nothing was narrowed")
        // The next search is a new one, whose signature takes the panel over as usual.
        controller.invalidate(signature: "q1")
        #expect(controller.narrowedFrom == nil, "the cleared pre-count does not come back with the next search")
    }

    // MARK: - #850 · an open section that lost its data

    @Test("After a new search, a section still open on screen is asked for again")
    func openSectionIsReRequestedAfterANewSearch() async throws {
        let (dir, service) = try await makeFixture()
        defer { cleanUp(dir) }

        let controller = FacetPanelController()
        controller.invalidate(signature: "q1")
        await controller.load(.volumes, parameters: SearchParameters(keywords: "containment"),
                              service: service)

        // The reader has Volumes open and it has rows: nothing to request.
        #expect(controller.sectionsNeedingLoad(expanded: [.volumes]).isEmpty)

        // A new search. The data is correctly discarded — but on macOS the panel is a long-lived
        // `.inspector`, so the section is STILL OPEN on screen with nothing in it.
        controller.invalidate(signature: "q2")
        #expect(controller.sectionsNeedingLoad(expanded: [.volumes]) == [.volumes], """
            An expanded section whose data was just discarded was not reported as needing a \
            reload. That is #850: header visible, body blank, indefinitely, recoverable only by \
            collapsing and re-opening the section.
            """)
    }

    @Test("A section the reader never opened is still never computed")
    func closedSectionsAreNeverRequested() async throws {
        let controller = FacetPanelController()
        controller.invalidate(signature: "q1")

        // Decision R-1-1, which the #850 fix must not trade away: laziness comes from the fact
        // that the answer is derived from what is OPEN, not from what exists.
        #expect(controller.sectionsNeedingLoad(expanded: []).isEmpty)
        #expect(controller.sectionsNeedingLoad(expanded: [.people]) == [.people])
    }

    @Test("An open Provenance section asks for the volume breakdown its door is built from")
    func provenancePullsVolumes() async throws {
        let controller = FacetPanelController()
        controller.invalidate(signature: "q1")

        // #833: Provenance's archival door is built from the volume breakdown, so Provenance being
        // open implies Volumes must be computed even though Volumes itself is shut. Deriving this
        // in ONE place is what keeps first-disclosure and post-search recovery from disagreeing —
        // before #850 the companion request lived only in the disclosure closure, so after a new
        // search the door came back only for a reader who had also opened Volumes by hand.
        let needed = controller.sectionsNeedingLoad(expanded: [.provenance])
        #expect(needed.contains(.volumes))
        #expect(needed.contains(.provenance))
        // …and opening Volumes is not implied in reverse.
        #expect(controller.sectionsNeedingLoad(expanded: [.volumes]) == [.volumes])
    }

    @Test("A section already in flight is not asked for twice")
    func inFlightSectionsAreNotRerequested() async throws {
        let (dir, service) = try await makeFixture()
        defer { cleanUp(dir) }

        let controller = FacetPanelController()
        controller.invalidate(signature: "q1")
        // Drive a real load and check the settled state: once loaded, the section stops being
        // requested. The in-flight half is covered by `load`'s own guard, which this mirrors.
        await controller.load(.people, parameters: SearchParameters(keywords: "containment"),
                              service: service)
        #expect(controller.loadedSections.contains(.people))
        #expect(controller.sectionsNeedingLoad(expanded: [.people]).isEmpty,
                "a loaded section was requested again, which would re-run a full aggregation on every body evaluation")
    }

    @Test("Re-invalidating with the same signature keeps the cache")
    func sameSignatureKeepsTheCache() async throws {
        let (dir, service) = try await makeFixture()
        defer { cleanUp(dir) }

        let controller = FacetPanelController()
        controller.invalidate(signature: "q1")
        await controller.load(.volumes, parameters: SearchParameters(keywords: "containment"),
                              service: service)
        controller.invalidate(signature: "q1")
        #expect(controller.facets != nil, "the same search must not discard its own sections")
    }

    // MARK: - "narrowed from"

    /// The figure only exists at the moment of the click, because the narrow re-runs the
    /// search and the recomputed panel describes the narrowed set. This is the test that
    /// catches reading it off `facets` after the fact.
    @Test("A narrow's pre-count survives exactly one invalidation")
    func narrowedFromSurvivesTheNarrow() {
        let controller = FacetPanelController()
        controller.invalidate(signature: "q1")
        #expect(controller.narrowedFrom == nil)

        controller.recordNarrowing(from: 412)
        // Still pending — it is promoted by the invalidation the narrow causes.
        #expect(controller.narrowedFrom == nil)

        controller.invalidate(signature: "q1-narrowed")
        #expect(controller.narrowedFrom == 412)
    }

    @Test("An unrelated new search clears the pre-count")
    func narrowedFromDoesNotOutliveItsQuery() {
        let controller = FacetPanelController()
        controller.invalidate(signature: "q1")
        controller.recordNarrowing(from: 412)
        controller.invalidate(signature: "q1-narrowed")
        #expect(controller.narrowedFrom == 412)

        // A different query: "narrowed from 412" would now be a claim about nothing.
        controller.invalidate(signature: "q2")
        #expect(controller.narrowedFrom == nil)
    }

    @Test("An unavailable pre-count is carried as unavailable, not as zero")
    func narrowedFromCopesWithAnUnknownTotal() {
        let controller = FacetPanelController()
        controller.invalidate(signature: "q1")
        controller.recordNarrowing(from: nil)
        controller.invalidate(signature: "q1-narrowed")
        #expect(controller.narrowedFrom == nil)
    }

    // MARK: - Merge

    @Test("Merging a section preserves the others and updates the bound")
    func mergePreservesOtherSections() {
        let first = ResultSetFacets(
            matchCount: 10,
            years: [FacetBucket(key: "1948", label: "1948", count: 4)], undatedCount: 1,
            volumes: [], people: [], documentTypes: [], provenance: [],
            provenanceCoverage: ProvenanceCoverage(parsed: 0, withRecordGroup: 0, matchCount: 10),
            subjects: [], subjectCoverage: 0, subjectsPrepared: true, bounds: [.years: FacetBound(shown: 1, total: 3)])
        let second = ResultSetFacets(
            matchCount: 10,
            years: [], undatedCount: 0,
            volumes: [FacetBucket(key: "v1", label: "v1", count: 10)], people: [],
            documentTypes: [], provenance: [],
            provenanceCoverage: ProvenanceCoverage(parsed: 0, withRecordGroup: 0, matchCount: 10),
            subjects: [], subjectCoverage: 0, subjectsPrepared: true, bounds: [.volumes: FacetBound(shown: 1, total: 1)])

        let merged = FacetPanelController.merge(second, into: first, section: .volumes)
        #expect(merged.years.count == 1, "the earlier section must survive")
        #expect(merged.undatedCount == 1, "and its undated count with it")
        #expect(merged.volumes.count == 1)
        #expect(merged.bounds[.years] == FacetBound(shown: 1, total: 3))
        #expect(merged.bounds[.volumes] == FacetBound(shown: 1, total: 1))
    }
}

/// The iOS half of the facet panel (R-1c).
///
/// iOS holds filter state as individual fields rather than macOS's single `SearchParameters`,
/// so its narrowing applier is a separate implementation of the same contract — which means
/// it needs its own tests rather than inheriting macOS's confidence.
///
/// Version history:
///   1.0 — R-1c: initial implementation
///   1.1 — #1686: a Volumes selection outlasts a change of project, as the Mac's facet choice now does
///   1.2 — #1758: a search taken off the screen takes the facet panel's narrowings with it, each while it is as the
///          panel made it, and a chip's ✕ with nothing left to search runs nothing
///   1.3 — #1758: the scope's narrowing, which a working corpus records, is the filters the rows were found under
@Suite("iOS facet narrowing")
@MainActor
struct IOSFacetNarrowingTests {

    private func makeViewModel() async throws -> (dir: URL, vm: SearchViewModel) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSiOSFacet-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("test.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        let fts5 = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: fts5, databaseURL: dbURL, volumesDirectory: volDir, concurrencyLimit: 1)
        return (dir, SearchViewModel(searchService: SearchService(fts5Store: fts5, pipeline: pipeline)))
    }

    private func cleanUp(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    // MARK: - The applier writes the same fields the filter sheet owns

    @Test("A year narrowing sets an enabled, correctly-bounded date range")
    func yearNarrowing() async throws {
        let (dir, vm) = try await makeViewModel()
        defer { cleanUp(dir) }

        vm.applyFacetNarrowing(.year("1948"))
        #expect(vm.dateRangeEnabled)
        // The bounds must reach the whole year, and must survive the round-trip into the
        // parameters the search actually uses.
        let range = try #require(vm.searchParameters.dateRange)
        #expect(range.earliest == "1948-01-01")
        #expect(range.latest == "1948-12-31")
    }

    @Test("A volume narrowing replaces rather than adds")
    func volumeNarrowingReplaces() async throws {
        let (dir, vm) = try await makeViewModel()
        defer { cleanUp(dir) }

        vm.selectedVolumeIds = ["frus1945v01", "frus1946v02"]
        vm.selectedSubseriesIds = ["1945"]
        vm.applyFacetNarrowing(.volume("frus1948v03"))
        // Unioning would return more documents than the facet row's own count promised.
        #expect(vm.selectedVolumeIds == ["frus1948v03"])
        #expect(vm.selectedSubseriesIds.isEmpty, "a stale subseries would widen the gate back out")
    }

    /// The Mac keeps a Volumes facet's choice across a change of project since #1686 (`FacetVolumeChoiceTests`), as
    /// iPhone and iPad did already: here a facet's volumes are the filter fields' own selection, which a change of
    /// project leaves. `SearchView.applyActiveProject()` sets the scope off and "only new" off, as below; the view is
    /// not driven here, its two assignments are.
    @Test("A Volumes selection outlasts a change of project, and stands over Focus (#1686's iPhone and iPad half)")
    func volumeSelectionOutlastsAProjectChange() async throws {
        let (dir, vm) = try await makeViewModel()
        defer { cleanUp(dir) }

        vm.projectFocusVolumeIds = ["frus1948v01", "frus1948v02", "frus1948v03", "frus1948v04"]
        vm.projectScope = .focus
        #expect(vm.searchParameters.volumeIds == ["frus1948v01", "frus1948v02", "frus1948v03", "frus1948v04"])
        vm.applyFacetSelection(.volumes, keys: ["frus1948v03", "frus1948v02"])
        #expect(vm.searchParameters.volumeIds == ["frus1948v02", "frus1948v03"],
                "a facet's volumes stand over the project's Focus volumes, as a selection in Filters does")

        vm.projectScope = .off
        vm.projectOnlyNew = false
        #expect(vm.searchParameters.volumeIds == ["frus1948v02", "frus1948v03"],
                "a change of project's reset of the scope dropped the facet's volumes")
    }

    @Test("A person narrowing clears the typed ref that would AND with it")
    func personNarrowingClearsTheRefText() async throws {
        let (dir, vm) = try await makeViewModel()
        defer { cleanUp(dir) }

        vm.personRefText = "acheson"
        vm.applyFacetNarrowing(.person(77, label: "Acheson, Dean"))
        #expect(vm.personRollupId == 77)
        #expect(vm.personRefText.isEmpty, "a stale ref would silently undercount")
    }

    /// #1092: the chip must say WHO is filtered, not which slot number holds them.
    @Test("The person chip shows the tapped bucket's name, never the rollup id")
    func personChipShowsName() async throws {
        let (dir, vm) = try await makeViewModel()
        defer { cleanUp(dir) }

        vm.applyFacetNarrowing(.person(77, label: "Acheson, Dean"))
        let chip = try #require(vm.activeNarrowings.first { $0.id == "person" })
        #expect(chip.label == "Acheson, Dean", """
            A chip reading "person #77" names a slot that is renumbered on every rollup \
            rebuild — it means nothing to the reader and stops being the same person after \
            one merge.
            """)
        #expect(!chip.label.contains("77"))
    }

    /// The mapping from a tapped bucket carries the display name into the narrowing.
    @Test("A people bucket's narrowing carries its label")
    func peopleBucketCarriesLabel() {
        let bucket = FacetBucket(key: "77", label: "Acheson, Dean", count: 3)
        #expect(FacetNarrowing.forBucket(bucket, in: .people)
                == .person(77, label: "Acheson, Dean"))
    }

    @Test("A document-type narrowing sets the shared filter field")
    func documentTypeNarrowing() async throws {
        let (dir, vm) = try await makeViewModel()
        defer { cleanUp(dir) }

        vm.applyFacetNarrowing(.documentType(.editorialNotesOnly))
        #expect(vm.documentTypeFilter == .editorialNotesOnly)
        #expect(vm.searchParameters.documentTypeFilter == .editorialNotesOnly)
    }

    // MARK: - The narrowed-by row

    @Test("Every narrowing becomes a visible, clearable chip")
    func narrowingsAreVisibleAndClearable() async throws {
        let (dir, vm) = try await makeViewModel()
        defer { cleanUp(dir) }

        #expect(vm.activeNarrowings.isEmpty)

        vm.applyFacetNarrowing(.year("1948"))
        vm.applyFacetNarrowing(.volume("frus1948v03"))
        vm.applyFacetNarrowing(.person(77, label: "Acheson, Dean"))
        vm.applyFacetNarrowing(.documentType(.documentsOnly))

        let ids = Set(vm.activeNarrowings.map(\.id))
        #expect(ids == ["date", "volume", "person", "type"],
                "a narrowing with no chip is a filter the user cannot see or undo")

        for id in ids { vm.clearNarrowing(id) }
        #expect(vm.activeNarrowings.isEmpty, "every chip must actually clear its filter")
    }

    @Test("Clearing one narrowing leaves the others alone")
    func clearingIsScoped() async throws {
        let (dir, vm) = try await makeViewModel()
        defer { cleanUp(dir) }

        vm.applyFacetNarrowing(.year("1948"))
        vm.applyFacetNarrowing(.volume("frus1948v03"))
        vm.clearNarrowing("date")
        #expect(!vm.dateRangeEnabled)
        #expect(vm.selectedVolumeIds == ["frus1948v03"])
    }

    @Test("The row also reflects filters set in the sheet, not only from facets")
    func rowReflectsSheetFilters() async throws {
        let (dir, vm) = try await makeViewModel()
        defer { cleanUp(dir) }

        // Set the fields directly, as the filter sheet does. The row is derived from live
        // state precisely so it cannot drift from what is actually filtering.
        vm.dateRangeEnabled = true
        vm.documentTypeFilter = .editorialNotesOnly
        #expect(Set(vm.activeNarrowings.map(\.id)) == ["date", "type"])
    }

    @Test("An unknown identifier is ignored rather than clearing something else")
    func unknownClearIsANoOp() async throws {
        let (dir, vm) = try await makeViewModel()
        defer { cleanUp(dir) }

        vm.applyFacetNarrowing(.year("1948"))
        vm.clearNarrowing("not-a-dimension")
        #expect(vm.dateRangeEnabled)
    }

    // MARK: - The search's end (#1758)

    /// S1's sitting on an iPad Pro: *"long telegram"* narrowed by the Years facet to 1945, then the
    /// field's ✕. The *Narrowed by 1945* chip stayed over the prompt, and taking it away ran a search
    /// with nothing to search.
    @Test("A search taken off the screen takes the facet panel's narrowings with it, and leaves the sheet's")
    func endingTheSearchTakesTheFacetsNarrowings() async throws {
        let (dir, vm) = try await makeViewModel()
        defer { cleanUp(dir) }

        vm.applyFacetSelection(.years, keys: ["1945"])
        vm.applyFacetNarrowing(.documentType(.documentsOnly))
        // Set as the filter sheet sets it.
        vm.selectedVolumeIds = ["frus1945v05"]
        #expect(Set(vm.activeNarrowings.map(\.id)) == ["years", "type", "volume"])

        vm.endSearchOnScreen()
        #expect(vm.facetYearKeys == nil, "the 1945 chip outlived the search it narrowed")
        #expect(vm.documentTypeFilter == .all)
        #expect(vm.selectedVolumeIds == ["frus1945v05"], "a filter set in the sheet stays between searches")
        #expect(vm.activeNarrowings.map(\.id) == ["volume"])
    }

    @Test("A field the reader changed in the sheet since the facet panel set it is the reader's, and stays")
    func aFieldChangedSinceStays() async throws {
        let (dir, vm) = try await makeViewModel()
        defer { cleanUp(dir) }

        vm.applyFacetNarrowing(.year("1948"))
        vm.applyFacetNarrowing(.volume("frus1948v03"))
        // The sheet moves the date range's end; the volume is left as the panel set it.
        vm.dateRangeEnd = try #require(Calendar(identifier: .gregorian)
            .date(from: DateComponents(timeZone: TimeZone(identifier: "UTC"), year: 1950, month: 6, day: 30)))
        vm.endSearchOnScreen()
        #expect(vm.dateRangeEnabled, "the reader's own range was taken away with the search")
        #expect(vm.selectedVolumeIds.isEmpty)
    }

    @Test("A chip taken away and then set again in the sheet is the reader's")
    func aChipSetAgainInTheSheetStays() async throws {
        let (dir, vm) = try await makeViewModel()
        defer { cleanUp(dir) }

        vm.applyFacetNarrowing(.volume("frus1948v03"))
        vm.clearNarrowing("volume")
        vm.selectedVolumeIds = ["frus1948v03"]
        vm.endSearchOnScreen()
        #expect(vm.selectedVolumeIds == ["frus1948v03"])
    }

    @Test("Clear Filters and a restored search forget the facet panel's narrowings")
    func clearAndRestoreForgetTheRecord() async throws {
        let (dir, vm) = try await makeViewModel()
        defer { cleanUp(dir) }

        vm.applyFacetNarrowing(.volume("frus1948v03"))
        vm.clearFilters()
        vm.selectedVolumeIds = ["frus1948v03"]
        vm.endSearchOnScreen()
        #expect(vm.selectedVolumeIds == ["frus1948v03"], "Clear Filters left the panel's record behind")

        vm.applyFacetSelection(.years, keys: ["1945"])
        vm.applyParameters(SearchParameters(keywords: "telegram", yearKeys: ["1945"]))
        vm.endSearchOnScreen()
        #expect(vm.facetYearKeys == ["1945"], "a restored search's years are its own")
    }

    @Test("A search taken off the screen empties it back to the prompt")
    func endingTheSearchEmptiesTheScreen() async throws {
        let (dir, vm) = try await makeViewModel()
        defer { cleanUp(dir) }

        vm.keywords = "containment"
        _ = await vm.search()
        #expect(vm.hasSearched)
        vm.searchError = "stale"
        vm.endSearchOnScreen()
        #expect(!vm.hasSearched)
        #expect(vm.results.isEmpty)
        #expect(vm.searchError == nil)
        #expect(vm.userTagCountScope == nil)
    }

    /// With the chip's narrowing gone and nothing else to search, `SearchView.removeNarrowing(_:)`
    /// runs no search: run, it failed with "Enter a keyword, phrase, or prefix to search."
    @Test("With no words and only a year left, there is nothing to run")
    func nothingToRunWithAYearAlone() async throws {
        let (dir, vm) = try await makeViewModel()
        defer { cleanUp(dir) }

        vm.applyFacetSelection(.years, keys: ["1945"])
        #expect(!vm.hasRunnableQuery(in: .keywords))
        vm.applyFacetNarrowing(.person(77, label: "Acheson, Dean"))
        #expect(vm.hasRunnableQuery(in: .keywords), "a person runs on its own")
        vm.clearNarrowing("person")
        #expect(!vm.hasRunnableQuery(in: .keywords))
    }

    // MARK: - What a capture records (#1758)

    /// A working corpus records what narrowed the rows it holds, read from the filters they were
    /// found under: a filter set in the sheet since, which waits for the next search, is not theirs.
    @Test("The scope's narrowing is the filters the rows were found under, not the sheet's since")
    func narrowingIsTheRowsOwn() async throws {
        let (dir, vm) = try await makeViewModel()
        defer { cleanUp(dir) }

        #expect(vm.resultSetScope.narrowing.isEmpty, "no rows, nothing narrowed")
        // Every field searched and every type, whatever the test host's search defaults say.
        vm.includeDocumentText = true
        vm.includeSummaries = true
        vm.includeNotes = true
        vm.includeFrontMatter = true
        vm.documentTypeFilter = .all
        vm.keywords = "long telegram"
        vm.applyFacetSelection(.years, keys: ["1945"])
        _ = await vm.search()
        #expect(vm.resultSetScope.narrowing == ["years 1945"])
        #expect(vm.resultSetScope.captureProvenanceDescription == "Search results (years 1945)")

        vm.documentTypeFilter = .editorialNotesOnly
        #expect(vm.resultSetScope.narrowing == ["years 1945"], "a filter not yet run is not the rows'")
        _ = await vm.search()
        #expect(vm.resultSetScope.narrowing == ["years 1945", "editorial notes only"])
    }

    // MARK: - The honest total

    /// iOS has never held a whole-query count. Reporting the fetched count as the total at
    /// the cap would be the same lie the Q-M2 work removed from macOS.
    @Test("At the fetch cap the facet total is unavailable, not the cap")
    func totalIsUnavailableAtTheCap() async throws {
        let (dir, vm) = try await makeViewModel()
        defer { cleanUp(dir) }

        #expect(vm.totalMatchCountForFacets == 0, "an empty result set is a known zero")

        // The rule itself, at the boundary. Asserting only the empty case — or only the cap
        // constant — cannot tell the rule from "just return the fetched count": a mutation
        // doing exactly that passed until this was added.
        #expect(SearchViewModel.facetTotal(fetched: 0, cap: 1_000) == 0)
        #expect(SearchViewModel.facetTotal(fetched: 999, cap: 1_000) == 999)
        #expect(SearchViewModel.facetTotal(fetched: 1_000, cap: 1_000) == nil,
                "at the cap the real total is unknown — reporting 1,000 as the total is the lie")
        #expect(SearchViewModel.facetTotal(fetched: 1_001, cap: 1_000) == nil)
    }
}

/// A Volumes facet's choice across a change of project on the Mac (#1686).
///
/// A facet writes the Mac window's parameters alone, and a change of project derived the volume gate from the filter
/// view model again, so the search ran over the volumes chosen in Filters, or every volume, and the facet's choice was
/// gone. `MacSearchViewModel.applyProjectScope()` now asks `FacetVolumeChoice.volumeGate(_:choice:derived:)`, driven
/// here. The view model is compiled for the Mac alone and this target runs on iOS, so its calls are read in
/// `SearchResultRouteTests.macProjectChangeKeepsAFacetsVolumes`, and the window was walked in the check copy.
///
/// Version history:
///   1.0 — #1686: initial implementation
@Suite("A Volumes facet's choice across a change of project (#1686)")
struct FacetVolumeChoiceTests {

    /// Two volumes a reader chose in the Volumes facet of a search in the 1961–63 volumes.
    private let chosen = ["frus1961-63v05", "frus1961-63v11"]

    /// A project's Focus volumes, of which the facet's two are a part.
    private let focus = ["frus1961-63v01", "frus1961-63v05", "frus1961-63v11", "frus1961-63v14"]

    @Test("A change of project keeps a facet's volumes while the gate still holds them")
    func aChangeOfProjectKeepsTheChoice() {
        let choice = FacetVolumeChoice(volumeIds: chosen)
        #expect(FacetVolumeChoice.volumeGate(chosen, choice: choice, derived: nil) == chosen,
                "every volume, the filter view model's scope, replaced the facet's choice")
        #expect(FacetVolumeChoice.volumeGate(chosen, choice: choice, derived: ["frus1961-63v07"]) == chosen,
                "the volume chosen in Filters before the facet replaced the facet's choice")
    }

    @Test("A facet's volumes stand over a project's Focus volumes, as a selection in Filters does")
    func theChoiceStandsOverFocus() {
        #expect(FacetVolumeChoice.volumeGate(chosen, choice: FacetVolumeChoice(volumeIds: chosen),
                                             derived: focus) == chosen)
    }

    @Test("A gate something else has written since is derived again")
    func anotherWriterEndsTheChoice() {
        // The facet chose two volumes; an edit in Filters then cleared them, under Focus, so the gate is the
        // Focus volumes. A change of project sets the scope off, and the Focus volumes go with it.
        #expect(FacetVolumeChoice.volumeGate(focus, choice: FacetVolumeChoice(volumeIds: chosen), derived: nil) == nil,
                "a facet's choice that is no longer the gate was put back")
    }

    @Test("With no choice remembered, the gate is the derived one")
    func noChoiceDerivesTheGate() {
        #expect(FacetVolumeChoice.volumeGate(focus, choice: nil, derived: nil) == nil,
                "leaving Focus kept its volumes")
        #expect(FacetVolumeChoice.volumeGate(nil, choice: nil, derived: focus) == focus)
    }

    @Test("A facet that cleared the volume gate keeps it clear")
    func aClearedGateStaysClear() {
        // A Volumes selection that excludes every volume listed clears the gate (`FacetSelectionApplier`).
        #expect(FacetVolumeChoice.volumeGate(nil, choice: FacetVolumeChoice(volumeIds: nil),
                                             derived: ["frus1961-63v07"]) == nil)
    }
}
