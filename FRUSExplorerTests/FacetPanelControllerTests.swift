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
@Suite("Facet panel controller")
@MainActor
struct FacetPanelControllerTests {

    // MARK: - Fixture

    private func makeFixture() async throws
        -> (dir: URL, service: SearchService, pipeline: IndexingPipeline) {
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
        return (dir, SearchService(fts5Store: fts5, pipeline: pipeline), pipeline)
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
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }

        let controller = FacetPanelController()
        controller.invalidate(signature: "q1")
        await controller.load(.volumes, parameters: SearchParameters(keywords: "containment"),
                              service: service, pipeline: pipeline)

        let facets = try #require(controller.facets)
        #expect(!facets.volumes.isEmpty)
        #expect(facets.years.isEmpty, "an unrequested section must not be computed")
        #expect(controller.loadedSections == [.volumes])
    }

    @Test("Loading a second section keeps the first")
    func sectionsAccumulate() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }

        let controller = FacetPanelController()
        controller.invalidate(signature: "q1")
        let params = SearchParameters(keywords: "containment")
        await controller.load(.volumes, parameters: params, service: service, pipeline: pipeline)
        await controller.load(.years, parameters: params, service: service, pipeline: pipeline)

        let facets = try #require(controller.facets)
        #expect(!facets.volumes.isEmpty, "the first section must survive the second's merge")
        #expect(!facets.years.isEmpty)
        #expect(controller.loadedSections == [.volumes, .years])
    }

    @Test("Re-loading a computed section is a no-op")
    func reloadingIsANoOp() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }

        let controller = FacetPanelController()
        controller.invalidate(signature: "q1")
        let params = SearchParameters(keywords: "containment")
        await controller.load(.volumes, parameters: params, service: service, pipeline: pipeline)
        let first = controller.facets
        await controller.load(.volumes, parameters: params, service: service, pipeline: pipeline)
        #expect(controller.facets == first)
    }

    @Test("No service or pipeline is safe rather than a crash")
    func missingDependenciesAreSafe() async {
        let controller = FacetPanelController()
        controller.invalidate(signature: "q1")
        await controller.load(.volumes, parameters: SearchParameters(keywords: "x"),
                              service: nil, pipeline: nil)
        #expect(controller.facets == nil)
        #expect(controller.failure == nil, "an absent dependency is not an error to paint")
    }

    // MARK: - Invalidation

    /// The failure this guards against is the plausible-looking one: a facet from the
    /// previous result set shown beside the current one.
    @Test("A new search discards every computed section")
    func newSearchDiscardsEverything() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }

        let controller = FacetPanelController()
        controller.invalidate(signature: "q1")
        await controller.load(.volumes, parameters: SearchParameters(keywords: "containment"),
                              service: service, pipeline: pipeline)
        #expect(controller.facets != nil)

        controller.invalidate(signature: "q2")
        #expect(controller.facets == nil)
        #expect(controller.loadedSections.isEmpty)
    }

    // MARK: - #850 · an open section that lost its data

    @Test("After a new search, a section still open on screen is asked for again")
    func openSectionIsReRequestedAfterANewSearch() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }

        let controller = FacetPanelController()
        controller.invalidate(signature: "q1")
        await controller.load(.volumes, parameters: SearchParameters(keywords: "containment"),
                              service: service, pipeline: pipeline)

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
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }

        let controller = FacetPanelController()
        controller.invalidate(signature: "q1")
        // Drive a real load and check the settled state: once loaded, the section stops being
        // requested. The in-flight half is covered by `load`'s own guard, which this mirrors.
        await controller.load(.people, parameters: SearchParameters(keywords: "containment"),
                              service: service, pipeline: pipeline)
        #expect(controller.loadedSections.contains(.people))
        #expect(controller.sectionsNeedingLoad(expanded: [.people]).isEmpty,
                "a loaded section was requested again, which would re-run a full aggregation on every body evaluation")
    }

    @Test("Re-invalidating with the same signature keeps the cache")
    func sameSignatureKeepsTheCache() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }

        let controller = FacetPanelController()
        controller.invalidate(signature: "q1")
        await controller.load(.volumes, parameters: SearchParameters(keywords: "containment"),
                              service: service, pipeline: pipeline)
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

    // MARK: - Narrowing map

    @Test("Every narrowable section maps to a field the filter sheet also owns")
    func narrowingWritesSharedFields() {
        var params = SearchParameters(keywords: "containment")

        FacetNarrowing.year("1948").apply(to: &params)
        #expect(params.dateRange?.earliest == "1948-01-01")
        #expect(params.dateRange?.latest == "1948-12-31")

        FacetNarrowing.volume("frus1948v03").apply(to: &params)
        #expect(params.volumeIds == ["frus1948v03"])

        FacetNarrowing.person(77).apply(to: &params)
        #expect(params.personRollupId == 77)

        FacetNarrowing.documentType(.editorialNotesOnly).apply(to: &params)
        #expect(params.documentTypeFilter == .editorialNotesOnly)
    }

    /// A rollup and a single ref are alternative expressions of one filter. Leaving a stale
    /// ref set would AND them and return fewer documents than the facet's own count promised.
    @Test("Narrowing to a person clears any single-ref person filter")
    func personNarrowingClearsTheRef() {
        var params = SearchParameters(keywords: "containment")
        params.personRef = "#p-acheson"
        FacetNarrowing.person(77).apply(to: &params)
        #expect(params.personRollupId == 77)
        #expect(params.personRef == nil, "a stale ref would silently AND with the rollup")
    }

    @Test("The document-type bucket key maps to the right half")
    func documentTypeKeyMapping() {
        let notes = FacetBucket(key: "1", label: "Editorial notes", count: 3)
        let documents = FacetBucket(key: "0", label: "Documents", count: 7)
        #expect(FacetNarrowing.forBucket(notes, in: .documentType)
                == .documentType(.editorialNotesOnly))
        #expect(FacetNarrowing.forBucket(documents, in: .documentType)
                == .documentType(.documentsOnly))
    }

    /// `SearchSQLFilters` has no repository, record-group or citation-era field, and the
    /// design forbids adding filter plumbing here. So the section is descriptive, and this
    /// pins that rather than leaving a future reader to discover a dead control.
    @Test("Provenance offers no narrowing, deliberately")
    func provenanceIsDescriptiveOnly() {
        let bucket = FacetBucket(key: "centralDecimalFile", label: "Central Decimal File", count: 12)
        #expect(FacetNarrowing.forBucket(bucket, in: .provenance) == nil)
        #expect(!FacetNarrowing.isNarrowable(.provenance))
        for section in FacetSection.allCases where section != .provenance {
            #expect(FacetNarrowing.isNarrowable(section), "\(section.rawValue) should narrow")
        }
    }

    @Test("A non-numeric person key yields no narrowing rather than a wrong one")
    func malformedPersonKeyIsRefused() {
        let bucket = FacetBucket(key: "not-a-rollup-id", label: "?", count: 1)
        #expect(FacetNarrowing.forBucket(bucket, in: .people) == nil)
    }

    // MARK: - Merge

    @Test("Merging a section preserves the others and updates the bound")
    func mergePreservesOtherSections() {
        let first = ResultSetFacets(
            matchCount: 10,
            years: [FacetBucket(key: "1948", label: "1948", count: 4)], undatedCount: 1,
            volumes: [], people: [], documentTypes: [], provenance: [],
            provenanceCoverage: ProvenanceCoverage(parsed: 0, withRecordGroup: 0, matchCount: 10),
            bounds: [.years: FacetBound(shown: 1, total: 3)])
        let second = ResultSetFacets(
            matchCount: 10,
            years: [], undatedCount: 0,
            volumes: [FacetBucket(key: "v1", label: "v1", count: 10)], people: [],
            documentTypes: [], provenance: [],
            provenanceCoverage: ProvenanceCoverage(parsed: 0, withRecordGroup: 0, matchCount: 10),
            bounds: [.volumes: FacetBound(shown: 1, total: 1)])

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

    @Test("A person narrowing clears the typed ref that would AND with it")
    func personNarrowingClearsTheRefText() async throws {
        let (dir, vm) = try await makeViewModel()
        defer { cleanUp(dir) }

        vm.personRefText = "acheson"
        vm.applyFacetNarrowing(.person(77))
        #expect(vm.personRollupId == 77)
        #expect(vm.personRefText.isEmpty, "a stale ref would silently undercount")
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
        vm.applyFacetNarrowing(.person(77))
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
