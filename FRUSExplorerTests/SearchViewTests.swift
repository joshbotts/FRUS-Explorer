// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
import SwiftData
@testable import FRUSExplorer

// MARK: - Search Fixture Helper

/// Writes a minimal FRUS volume XML fixture to `url`.
private func writeSearchFixture(
    to url: URL,
    volumeId: String,
    documents: [(id: String, xml: String)]
) throws {
    let docBlocks = documents.map { doc in
        "<div type=\"document\" xml:id=\"\(doc.id)\">\(doc.xml)</div>"
    }.joined(separator: "\n")

    let xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <TEI xmlns="http://www.tei-c.org/ns/1.0">
      <teiHeader><fileDesc><titleStmt><title>\(volumeId)</title></titleStmt>
      <publicationStmt><date>2003</date></publicationStmt>
      <sourceDesc><p>Test fixture</p></sourceDesc></fileDesc></teiHeader>
      <text><body>
        <div type="compilation" xml:id="comp1">
          \(docBlocks)
        </div>
      </body></text>
    </TEI>
    """
    try xml.data(using: .utf8)!.write(to: url)
}

// MARK: - SearchViewTests

struct SearchViewTests {

    // MARK: - TotalMatchCountTests

    /// The whole-query count iOS gained in Q-wave step 6, end to end.
    ///
    /// Worth an integration test rather than a unit one: the count is taken *concurrently* with
    /// the search, and the two must land together — an `async let` that was awaited in the wrong
    /// order, or not at all, would leave a total describing the previous query. That is the exact
    /// defect class the surrounding work exists to remove, so it is pinned against a real index.
    @Test("The whole-query total is taken with the search and cleared with it")
    @MainActor
    func totalMatchCountAccompaniesTheSearch() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSTotal-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let dbURL = dir.appendingPathComponent("total.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)

        let store = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: store, databaseURL: dbURL, volumesDirectory: volDir, concurrencyLimit: 1)
        let service = SearchService(fts5Store: store, pipeline: pipeline)

        try writeSearchFixture(
            to: volDir.appendingPathComponent("frus1969-76v01.xml"),
            volumeId: "frus1969-76v01",
            documents: [
                (id: "d1", xml: "<head>Memorandum</head><p>Discussed détente policy at length.</p>"),
                (id: "d2", xml: "<head>Telegram</head><p>A further note on détente.</p>"),
                (id: "d3", xml: "<head>Letter</head><p>Unrelated administrative matter.</p>")
            ]
        )
        try await pipeline.indexVolume("frus1969-76v01")

        let vm = SearchViewModel(searchService: service)
        vm.keywords = "détente"
        await vm.search()

        // Far below the 1,000 ceiling, so the total is exactly what was fetched — which is the
        // case that proves the count RAN, since a count that silently failed would be nil.
        #expect(vm.results.count == 2)
        #expect(vm.totalMatchCount == 2)

        // And it must not outlive the results. A total left behind is a denominator for a set
        // that no longer exists.
        vm.clearAll()
        #expect(vm.results.isEmpty)
        #expect(vm.totalMatchCount == nil)
    }

    // MARK: - KeywordSearchTest

    @Test("Searching for a known keyword returns matching documents")
    @MainActor
    func keywordSearchReturnsResults() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSSearchKW-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let dbURL = dir.appendingPathComponent("kw.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)

        let store = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: store,
            databaseURL: dbURL,
            volumesDirectory: volDir,
            concurrencyLimit: 1
        )
        let service = SearchService(fts5Store: store, pipeline: pipeline)

        try writeSearchFixture(
            to: volDir.appendingPathComponent("frus1969-76v01.xml"),
            volumeId: "frus1969-76v01",
            documents: [
                (id: "d1", xml: "<head>Memorandum of Conversation</head><dateline>Washington, January 20, 1969.</dateline><p>Discussed détente policy with the Soviet delegation.</p>"),
                (id: "d2", xml: "<head>Telegram</head><dateline>Moscow, February 5, 1969.</dateline><p>Routine administrative message about staff assignments.</p>")
            ]
        )
        try await pipeline.indexVolume("frus1969-76v01")

        let vm = SearchViewModel(searchService: service)
        vm.keywords = "détente"
        await vm.search()

        #expect(vm.hasSearched)
        #expect(!vm.results.isEmpty)
        #expect(vm.results.map(\.documentId).contains("d1"))
    }

    // MARK: - PhraseSearchTest

    @Test("Phrase search returns only documents containing the exact phrase")
    @MainActor
    func phraseSearchReturnsExactMatches() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSSearchPhrase-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let dbURL = dir.appendingPathComponent("phrase.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)

        let store = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: store,
            databaseURL: dbURL,
            volumesDirectory: volDir,
            concurrencyLimit: 1
        )
        let service = SearchService(fts5Store: store, pipeline: pipeline)

        try writeSearchFixture(
            to: volDir.appendingPathComponent("frus1969-76v01.xml"),
            volumeId: "frus1969-76v01",
            documents: [
                (id: "d1", xml: "<head>Memorandum</head><dateline>Washington, March 1, 1969.</dateline><p>The national security council met today.</p>"),
                (id: "d2", xml: "<head>Telegram</head><dateline>Paris, March 2, 1969.</dateline><p>Security briefing about national policy goals.</p>")
            ]
        )
        try await pipeline.indexVolume("frus1969-76v01")

        let vm = SearchViewModel(searchService: service)
        vm.phrase = "national security council"
        await vm.search()

        #expect(vm.hasSearched)
        #expect(!vm.results.isEmpty)
        let ids = vm.results.map(\.documentId)
        #expect(ids.contains("d1"))
        #expect(!ids.contains("d2"))
    }

    // MARK: - DateRangeFilterTest

    @Test("Date range filter is included in search parameters when enabled")
    @MainActor
    func dateRangeFilterIncludedInParameters() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSSearchDR-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let dbURL = dir.appendingPathComponent("dr.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        let store = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: store, databaseURL: dbURL, volumesDirectory: volDir,
            concurrencyLimit: 1
        )
        let service = SearchService(fts5Store: store, pipeline: pipeline)

        let vm = SearchViewModel(searchService: service)
        let start = Calendar.current.date(from: DateComponents(year: 1969, month: 1, day: 1))!
        let end   = Calendar.current.date(from: DateComponents(year: 1972, month: 12, day: 31))!
        vm.dateRangeEnabled = true
        vm.dateRangeStart = start
        vm.dateRangeEnd = end

        let params = vm.searchParameters
        let range = try #require(params.dateRange)
        #expect(range.earliest == "1969-01-01")
        #expect(range.latest   == "1972-12-31")
    }

    // MARK: - ProjectScopeTest (#377 Phase 2a)

    @Test("Project History scope emits documentIds, and applyParameters clears it")
    @MainActor
    func projectHistoryScopeAndReset() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSSearchPS-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let dbURL = dir.appendingPathComponent("ps.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        let store = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: store, databaseURL: dbURL, volumesDirectory: volDir,
            concurrencyLimit: 1
        )
        let service = SearchService(fts5Store: store, pipeline: pipeline)
        let vm = SearchViewModel(searchService: service)

        // Off by default → no documentIds gate.
        #expect(vm.searchParameters.documentIds == nil)

        // History scope emits the engaged set as documentIds.
        vm.projectEngagedDocumentKeys = ["v1/d1", "v1/d2"]
        vm.projectScope = .history
        #expect(vm.searchParameters.documentIds == ["v1/d1", "v1/d2"])

        // A pending-search / saved-search snapshot resets the live scope, so the gate
        // does not silently carry into an unrelated hand-off search.
        vm.applyParameters(SearchParameters(keywords: "detente"))
        #expect(vm.projectScope == .off)
        #expect(vm.searchParameters.documentIds == nil)
    }

    @Test("Project Focus scope emits the subject-derived volume scope + only-new exclusion")
    @MainActor
    func projectFocusScopeParameters() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSSearchPF-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let dbURL = dir.appendingPathComponent("pf.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        let store = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: store, databaseURL: dbURL, volumesDirectory: volDir,
            concurrencyLimit: 1
        )
        let vm = SearchViewModel(searchService: SearchService(fts5Store: store, pipeline: pipeline))

        vm.projectFocusVolumeIds = ["frus1969-76v01", "frus1969-76v02"]
        vm.projectEngagedDocumentKeys = ["frus1969-76v01/d5"]

        // Focus with "only new" off: volumeIds is the focus scope; no exclusion.
        vm.projectScope = .focus
        #expect(vm.searchParameters.volumeIds == ["frus1969-76v01", "frus1969-76v02"])
        #expect(vm.searchParameters.excludeDocumentIds == nil)
        #expect(vm.searchParameters.documentIds == nil)

        // "Only new" on: the engaged set becomes the exclusion.
        vm.projectOnlyNew = true
        #expect(vm.searchParameters.excludeDocumentIds == ["frus1969-76v01/d5"])

        // A manual volume selection overrides the subject-derived focus volumes (owner
        // refinement) — the manual pick wins, subjects are ignored.
        vm.selectedVolumeIds = ["frus1952-54v08"]
        #expect(vm.searchParameters.volumeIds == ["frus1952-54v08"])
        // …and clearing it falls back to the subject-derived scope.
        vm.selectedVolumeIds = []
        #expect(vm.searchParameters.volumeIds == ["frus1969-76v01", "frus1969-76v02"])

        // Focus with neither a manual selection nor resolvable subject volumes must match
        // nothing (empty documentIds → SQL 1=0), not silently search the whole corpus.
        vm.projectFocusVolumeIds = []
        #expect(vm.searchParameters.volumeIds == nil)
        #expect(vm.searchParameters.documentIds == [])
    }

    // MARK: - SubjectTagFilterTest

    @Test("Subject tag ids are inert: live parameters always emit an empty list (Session 09)")
    @MainActor
    func subjectTagIdsEmittedEmpty() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSSearchST-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let dbURL = dir.appendingPathComponent("st.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        let store = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: store, databaseURL: dbURL, volumesDirectory: volDir,
            concurrencyLimit: 1
        )
        let service = SearchService(fts5Store: store, pipeline: pipeline)

        let vm = SearchViewModel(searchService: service)
        // A restored snapshot carrying retired subject ids must neither resurrect the
        // (neutralized) filter nor fake an "active filters" state.
        vm.applyParameters(SearchParameters(
            keywords: "test",
            subjectTagIds: ["kissinger-henry-a", "soviet-union"]
        ))
        #expect(vm.searchParameters.subjectTagIds.isEmpty)
        #expect(!vm.hasActiveFilters)
    }

    // MARK: - ScopeTest

    @Test("includeSummaries and includeNotes flags flow through to search parameters")
    @MainActor
    func scopeFlagsFlowToParameters() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSSearchScope-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let dbURL = dir.appendingPathComponent("scope.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        let store = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: store, databaseURL: dbURL, volumesDirectory: volDir,
            concurrencyLimit: 1
        )
        let service = SearchService(fts5Store: store, pipeline: pipeline)

        let vm = SearchViewModel(searchService: service)

        // Default: both included
        #expect(vm.searchParameters.includeSummaries)
        #expect(vm.searchParameters.includeNotes)

        // Disable summaries only
        vm.includeSummaries = false
        #expect(!vm.searchParameters.includeSummaries)
        #expect(vm.searchParameters.includeNotes)

        // Disable notes only
        vm.includeSummaries = true
        vm.includeNotes = false
        #expect(vm.searchParameters.includeSummaries)
        #expect(!vm.searchParameters.includeNotes)
    }

    // MARK: - ProjectDefaultsTest

    @Test("applyProjectDefaults pre-populates date range and subject tags from the active project")
    @MainActor
    func projectDefaultsPrePopulateFilters() throws {
        let container = try ModelContainer.makeTestContainer()
        let ctx = container.mainContext

        let project = Project(
            name: "Nixon Doctrine",
            defaultDateRangeStart: Calendar.current.date(from: DateComponents(year: 1969, month: 1, day: 1)),
            defaultDateRangeEnd: Calendar.current.date(from: DateComponents(year: 1974, month: 8, day: 9)),
            defaultSubjectTagIds: ["nixon-richard-m", "foreign-policy"]
        )
        ctx.insert(project)

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSSearchPD-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let dbURL = dir.appendingPathComponent("pd.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        let store = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: store, databaseURL: dbURL, volumesDirectory: volDir,
            concurrencyLimit: 1
        )
        let service = SearchService(fts5Store: store, pipeline: pipeline)

        let vm = SearchViewModel(searchService: service)
        vm.applyProjectDefaults(project)

        #expect(vm.dateRangeEnabled)
        // Persisted defaultSubjectTagIds survive on the model but are inert since
        // Session 09: they must NOT surface as live filter state or emitted parameters.
        #expect(vm.searchParameters.subjectTagIds.isEmpty)
    }

    // MARK: - QueryInspectorRefreshKeyTest

    /// #1297 round 1 (F7): `SearchView` refreshes the Query Inspector when this key changes. It was `vm.keywords`, so
    /// Clear Filters could remove a restored phrase and leave the strip describing the search before it — and the
    /// two describe different searches: beside the phrase "cold war", `cold OR -korea` is searched exactly, and
    /// without it the query is narrower than typed. `QueryInspectionTests.iOSInspectorRefreshesOnEveryQueryPart`
    /// pins the view's use of the key; this pins what the key covers.
    @Test("The inspector refresh key moves with a restored phrase, prefix or excluded term, not only the typed text")
    @MainActor
    func inspectorRefreshKeyCoversEveryQueryPart() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSInspectorKey-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let dbURL = dir.appendingPathComponent("key.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        let store = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: store, databaseURL: dbURL, volumesDirectory: volDir, concurrencyLimit: 1)
        let service = SearchService(fts5Store: store, pipeline: pipeline)
        let inspector = QueryInspector(searchService: service)

        let vm = SearchViewModel(searchService: service)
        vm.applyParameters(SearchParameters(keywords: "cold OR -korea", phrase: "cold war"))
        let restored = vm.queryInspectorRefreshKey
        #expect(restored == QueryInspector.Inputs(vm.searchParameters), "the key is read from the parameters the refresh inspects")
        let beside = await inspector.inspect(parameters: vm.searchParameters, indexedVolumeCount: 0)
        #expect(!beside.isApproximate, "precondition: beside the phrase the query is searched exactly")

        vm.clearFilters()
        #expect(vm.keywords == "cold OR -korea", "precondition: Clear Filters leaves the typed text alone")
        #expect(vm.queryInspectorRefreshKey != restored, "so the key must move, or the strip keeps the phrase")
        let cleared = await inspector.inspect(parameters: vm.searchParameters, indexedVolumeCount: 0)
        #expect(cleared.isApproximate, "and what it refreshes to is the narrower query that now runs")

        // Each structured field moves the key on its own, with the typed text unchanged.
        var before = vm.queryInspectorRefreshKey
        vm.phrase = "détente"
        #expect(vm.queryInspectorRefreshKey != before, "a phrase")
        vm.clearFilters()
        before = vm.queryInspectorRefreshKey
        vm.prefixWildcard = "viet"
        #expect(vm.queryInspectorRefreshKey != before, "a prefix")
        vm.clearFilters()
        before = vm.queryInspectorRefreshKey
        vm.excludedTermsText = "korea"
        #expect(vm.queryInspectorRefreshKey != before, "an excluded term")
    }

    /// #1297 round 2 (A3): the key was the whole `searchParameters`, whose synthesized `==` also compares fields the
    /// inspection never reads. A rollup rebuild captures a person filter's anchor, or relabels it, without changing the
    /// filter and without running a search — and the key still moved, so the refresh replaced the inspection, dropping
    /// the scoped counts the researcher had asked for and the zero-result blame. macOS bumps its counter only when the
    /// filter itself changes.
    @Test("The inspector refresh key ignores a person filter's label and anchor and the boolean mode, and moves with what the inspection reads")
    @MainActor
    func inspectorRefreshKeyIgnoresDisplayOnlyFields() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSInspectorKeyDisplay-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let dbURL = dir.appendingPathComponent("key.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        let store = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: store, databaseURL: dbURL, volumesDirectory: volDir, concurrencyLimit: 1)
        let service = SearchService(fts5Store: store, pipeline: pipeline)
        let inspector = QueryInspector(searchService: service)

        let vm = SearchViewModel(searchService: service)
        vm.keywords = "cold OR -korea"
        vm.personRollupId = 7
        vm.personLabel = "Acheson"
        let before = vm.queryInspectorRefreshKey
        let inspected = await inspector.inspect(parameters: vm.searchParameters, indexedVolumeCount: 0)

        vm.personLabel = "Dean Acheson"
        #expect(vm.queryInspectorRefreshKey == before, "a relabel changes no filter")
        vm.personAnchor = PersonRollupAnchor(volumeId: "frus1947v01", ref: "p_ADG_1")
        #expect(vm.queryInspectorRefreshKey == before, "an anchor capture changes no filter")
        vm.booleanMode = .or
        #expect(vm.queryInspectorRefreshKey == before, "the boolean mode is not read: the inline parser combines the text")
        #expect(await inspector.inspect(parameters: vm.searchParameters, indexedVolumeCount: 0) == inspected,
                "and what a refresh would inspect is the same inspection")

        // The other direction: each field the inspection reads still moves the key on its own.
        let moves: [(label: String, change: () -> Void)] = [
            ("the typed text", { vm.keywords = "cold" }),
            ("the person filter", { vm.personRollupId = 8 }),
            ("a single person ref", { vm.personRefText = "p_ADG_1" }),
            ("the subject name, the fallback half of a subject filter", { vm.subjectName = "Containment" }),
            ("the subject ref", { vm.subjectRef = "rec00812a40defabcb" }),
            ("the subject bucket", { vm.subjectBucketKey = "A\u{1F}B" }),
            ("a content scope", { vm.includeSummaries.toggle() }),
            ("front matter", { vm.includeFrontMatter.toggle() }),
            ("the document type", { vm.documentTypeFilter = .editorialNotesOnly }),
            ("the year facet", { vm.facetYearKeys = ["1950"] }),
            ("the date range", { vm.dateRangeEnabled.toggle() }),
        ]
        for (label, change) in moves {
            let key = vm.queryInspectorRefreshKey
            change()
            #expect(vm.queryInspectorRefreshKey != key, "\(label) moves the key")
        }
    }
}

// MARK: - PersonFilterTests

@MainActor
struct PersonFilterTests {

    // MARK: - PersonRefFlowsToParameters

    @Test("personRefText flows into SearchParameters.personRef")
    func personRefFlowsToParameters() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSSearchPR-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let dbURL = dir.appendingPathComponent("pr.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        let store = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: store, databaseURL: dbURL, volumesDirectory: volDir,
            concurrencyLimit: 1
        )
        let service = SearchService(fts5Store: store, pipeline: pipeline)

        let vm = SearchViewModel(searchService: service)
        vm.personRefText = "kissinger-henry-a"
        vm.keywords = "détente"

        let params = vm.searchParameters
        #expect(params.personRef == "kissinger-henry-a")
    }

    // MARK: - ApplyParametersTest

    @Test("applyParameters populates all fields from a SearchParameters snapshot")
    func applyParametersPopulatesFields() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSSearchAP-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let dbURL = dir.appendingPathComponent("ap.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        let store = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: store, databaseURL: dbURL, volumesDirectory: volDir,
            concurrencyLimit: 1
        )
        let service = SearchService(fts5Store: store, pipeline: pipeline)

        let vm = SearchViewModel(searchService: service)
        let params = SearchParameters(
            keywords: "détente",
            volumeIds: ["frus1969-76v01"],
            personRef: "kissinger-henry-a"
        )
        vm.applyParameters(params)

        #expect(vm.keywords == "détente")
        #expect(vm.personRefText == "kissinger-henry-a")
        #expect(vm.selectedVolumeIds == ["frus1969-76v01"])
        #expect(vm.searchParameters.personRef == "kissinger-henry-a")
        #expect(vm.searchParameters.volumeIds == ["frus1969-76v01"])
    }


    // MARK: - VolumeScopeTest

    /// Verifies the "Search this volume" handoff round-trips through the view model:
    /// `applyParameters` stores the volume scope, `searchParameters` forwards it to
    /// `SearchService`, `hasActiveFilters` reflects it, and `clearFilters` resets it.
    ///
    /// Regression guard for the Session 162 gap where the iOS view model had no
    /// volume concept at all, so the volume-only handoff was silently dropped at
    /// `applyParameters` and never reached the search query.
    @Test("Volume scope round-trips through applyParameters / searchParameters and clears")
    func volumeScopeRoundTripsAndClears() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSVolScope-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let dbURL = dir.appendingPathComponent("vs.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        let store = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: store, databaseURL: dbURL, volumesDirectory: volDir,
            concurrencyLimit: 1
        )
        let service = SearchService(fts5Store: store, pipeline: pipeline)

        let vm = SearchViewModel(searchService: service)

        // A baseline keyword search carries no volume filter.
        vm.keywords = "détente"
        #expect(vm.searchParameters.volumeIds == nil)
        #expect(vm.hasActiveFilters == false)

        // The volume-only handoff applies the scope without an executable term.
        vm.applyParameters(SearchParameters(volumeIds: ["frus1969-76v01"]))
        #expect(vm.selectedVolumeIds == ["frus1969-76v01"])
        #expect(vm.hasActiveFilters == true)

        // A query typed afterward is forwarded to the service scoped to the volume.
        vm.keywords = "détente"
        #expect(vm.searchParameters.keywords == "détente")
        #expect(vm.searchParameters.volumeIds == ["frus1969-76v01"])

        // Clearing filters resets the scope back to the whole corpus.
        vm.clearFilters()
        #expect(vm.selectedVolumeIds.isEmpty)
        #expect(vm.searchParameters.volumeIds == nil)
    }

    // MARK: - UnstemmedHeaderDisplayTest

    /// Verifies that `SearchResult.header` and `SearchResult.dateline` contain the
    /// original document text.
    ///
    /// Historical context: before the external-content redesign, the FTS5 table
    /// stored application-stemmed text ("Memorandum of Conversation" became
    /// "memorandum of convers") and SearchService had to repair display values from
    /// `document_cache`. The combined search query now reads display fields straight
    /// from `document_cache`, so this guards against any regression that reintroduces
    /// stemmed tokens into result rows.
    @Test("Search results show unstemmed header and dateline from document_cache")
    @MainActor
    func searchResultsShowUnstemmedHeaderAndDateline() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSUnstemmedHeader-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let dbURL  = dir.appendingPathComponent("unstemmed.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)

        let store = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: store,
            databaseURL: dbURL,
            volumesDirectory: volDir,
            concurrencyLimit: 1
        )
        let service = SearchService(fts5Store: store, pipeline: pipeline)

        // The header contains words that Porter-stem differently:
        // "Memorandum" → "memorandum", "Conversation" → "convers", "Assistant" → "assist".
        // The dateline has a full proper name and ordinal date that would be mangled.
        let originalHeader   = "Memorandum of Conversation"
        let originalDateline = "Washington, January 20, 1969."

        try writeSearchFixture(
            to: volDir.appendingPathComponent("frus1969-76v01.xml"),
            volumeId: "frus1969-76v01",
            documents: [
                (id: "d1", xml: "<head>\(originalHeader)</head><dateline>\(originalDateline)</dateline><p>Discussed détente policy.</p>")
            ]
        )
        try await pipeline.indexVolume("frus1969-76v01")

        let vm = SearchViewModel(searchService: service)
        vm.keywords = "détente"
        await vm.search()

        let result = try #require(vm.results.first { $0.documentId == "d1" })
        #expect(result.header == originalHeader,
                "header should be the original text from document_cache, not a stemmed FTS5 token")
        #expect(result.dateline == originalDateline,
                "dateline should be the original text from document_cache, not a stemmed FTS5 token")
    }
}

// MARK: - SearchChecklistModeTests

/// Display-time checklist-mode filtering (#189-D) — pure `SearchViewModel` logic over
/// directly-assigned `results` (no indexing).
struct SearchChecklistModeTests {

    /// Builds a minimal `SearchViewModel` backed by an empty store (no indexing) for exercising
    /// the display-time checklist filter over directly-assigned `results`.
    @MainActor
    private func makeChecklistVM() throws -> (vm: SearchViewModel, dir: URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSChecklist-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("c.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        let store = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: store, databaseURL: dbURL, volumesDirectory: volDir,
            concurrencyLimit: 1
        )
        let service = SearchService(fts5Store: store, pipeline: pipeline)
        return (SearchViewModel(searchService: service), dir)
    }

    /// `n` throwaway results in volume `v1`, documents `d1…dn`.
    private func sampleResults(_ n: Int) -> [SearchResult] {
        (1...n).map { SearchResult(documentId: "d\($0)", volumeId: "v1", header: "Doc \($0)", snippet: "", bm25Score: 0) }
    }

    @Test("Checklist mode hides reviewed results and pages over the filtered set")
    @MainActor
    func checklistHidesAndPagesOverFiltered() throws {
        let (vm, dir) = try makeChecklistVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.results = sampleResults(30)

        // Off: 30 results, 2 pages, page 0 shows the first 25.
        #expect(vm.displayedResults.count == 30)
        #expect(vm.totalPages == 2)
        #expect(vm.pagedResults.count == 25)

        // On + mark 6 reviewed: 24 shown, one page, all fit; the reviewed docs are gone.
        vm.setChecklistMode(true)
        for i in 1...6 { vm.markReviewed(volumeId: "v1", documentId: "d\(i)") }
        #expect(vm.displayedResults.count == 24)
        #expect(vm.resultCount == 24)
        #expect(vm.totalPages == 1)
        #expect(vm.pagedResults.count == 24)
        #expect(!vm.pagedResults.contains { $0.documentId == "d1" })
        #expect(!vm.pagedResults.contains { $0.documentId == "d6" })
        // The raw fetch count (used by the cap indicator) is unchanged.
        #expect(vm.results.count == 30)
    }

    @Test("Marking the last page's results reviewed re-clamps the current page")
    @MainActor
    func checklistPaginationClampsWhenPageEmpties() throws {
        let (vm, dir) = try makeChecklistVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.results = sampleResults(30)
        vm.currentPage = 1            // second page: d26…d30
        #expect(vm.pagedResults.map(\.documentId) == ["d26", "d27", "d28", "d29", "d30"])

        vm.setChecklistMode(true)     // resets currentPage to 0 on enable
        #expect(vm.currentPage == 0)
        vm.currentPage = 1            // back to page 2 under checklist (still 2 pages: 30 shown)
        // Mark all of page 2 reviewed → 25 shown, 1 page → the stale page index clamps to 0.
        for i in 26...30 { vm.markReviewed(volumeId: "v1", documentId: "d\(i)") }
        #expect(vm.totalPages == 1)
        #expect(vm.currentPage == 0)
        #expect(vm.pagedResults.count == 25)
        #expect(!vm.pagedResults.contains { $0.documentId == "d26" })
    }

    @Test("Disabling checklist mode restores the full unfiltered result set")
    @MainActor
    func checklistDisableRestoresAll() throws {
        let (vm, dir) = try makeChecklistVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.results = sampleResults(10)
        vm.setChecklistMode(true)
        vm.markReviewed(volumeId: "v1", documentId: "d1")
        vm.readSinceEnabledKeys = [SearchViewModel.reviewedKey(volumeId: "v1", documentId: "d2")]
        #expect(vm.displayedResults.count == 8)

        vm.setChecklistMode(false)
        #expect(vm.displayedResults.count == 10)
        #expect(vm.markedReviewedKeys.isEmpty)
        #expect(vm.readSinceEnabledKeys.isEmpty)
        #expect(vm.checklistEnabledAt == nil)
    }

    @Test("readSinceEnabledKeys and markedReviewedKeys union without double-hiding")
    @MainActor
    func checklistUnionOfReadAndMarked() throws {
        let (vm, dir) = try makeChecklistVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.results = sampleResults(5)
        vm.setChecklistMode(true)
        // d1 is both opened AND marked; d2 only opened; d3 only marked.
        vm.readSinceEnabledKeys = [
            SearchViewModel.reviewedKey(volumeId: "v1", documentId: "d1"),
            SearchViewModel.reviewedKey(volumeId: "v1", documentId: "d2"),
        ]
        vm.markReviewed(volumeId: "v1", documentId: "d1")
        vm.markReviewed(volumeId: "v1", documentId: "d3")
        #expect(vm.displayedResults.map(\.documentId) == ["d4", "d5"])
        #expect(vm.results.count - vm.displayedResults.count == 3)   // d1, d2, d3 — no double count
    }

    @Test("A new search resets checklist reviewed state so a prior query's reviews don't leak")
    @MainActor
    func checklistResetsOnNewSearch() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSChecklistReset-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let dbURL = dir.appendingPathComponent("r.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        let store = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: store, databaseURL: dbURL, volumesDirectory: volDir,
            concurrencyLimit: 1
        )
        let service = SearchService(fts5Store: store, pipeline: pipeline)
        // Two documents, both containing "alpha" and "beta" so they match either query.
        try writeSearchFixture(
            to: volDir.appendingPathComponent("frus1969-76v01.xml"),
            volumeId: "frus1969-76v01",
            documents: [
                (id: "d1", xml: "<head>One</head><p>alpha beta discussion of policy.</p>"),
                (id: "d2", xml: "<head>Two</head><p>alpha and beta notes on strategy.</p>"),
            ]
        )
        try await pipeline.indexVolume("frus1969-76v01")

        let vm = SearchViewModel(searchService: service)
        vm.keywords = "alpha"
        await vm.search()
        #expect(vm.results.count == 2)

        vm.setChecklistMode(true)
        let anchorA = try #require(vm.checklistEnabledAt)
        let first = vm.results[0]
        vm.markReviewed(volumeId: first.volumeId, documentId: first.documentId)
        #expect(vm.displayedResults.count == 1)   // one hidden under query A

        // A different query whose results include the same documents.
        vm.keywords = "beta"
        await vm.search()
        #expect(vm.results.count == 2)
        #expect(vm.checklistMode)                                // mode persists across searches
        #expect(vm.markedReviewedKeys.isEmpty)                   // marks cleared for the new query
        #expect(vm.readSinceEnabledKeys.isEmpty)
        #expect(vm.checklistEnabledAt != anchorA)                // re-anchored to the new search
        #expect(vm.displayedResults.count == 2)                  // no cross-query hiding leaks in
    }

    // MARK: Mark Page Reviewed, and Undo (#1576 lane 1)

    /// Sixty results are three pages of 25, 25 and 10. Marking page 1 hides `d1`…`d25`; the page
    /// index stays 0, so the rows that follow move up into it.
    @Test("Mark Page Reviewed hides the page and leaves the next one in its place; Undo brings it back")
    @MainActor
    func markPageHidesThePageAndUndoRestoresIt() throws {
        let (vm, dir) = try makeChecklistVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.results = sampleResults(60)
        vm.setChecklistMode(true)
        #expect(!vm.canUndoBulkMark)

        let hidden = vm.markReviewed(vm.pagedResults)

        #expect(hidden == 25)
        #expect(vm.displayedResults.count == 35)
        #expect(vm.currentPage == 0)
        #expect(vm.pagedResults.first?.documentId == "d26")
        #expect(vm.pagedResults.count == 25)
        #expect(vm.canUndoBulkMark)
        #expect(vm.results.count == 60, "the loaded results are untouched; the mark only hides")

        let restored = vm.undoLastBulkMark()

        #expect(restored == 25)
        #expect(vm.displayedResults.count == 60)
        #expect(vm.pagedResults.first?.documentId == "d1")
        #expect(!vm.canUndoBulkMark)
        #expect(vm.markedReviewedKeys.isEmpty)
    }

    @Test("Undo takes back the page mark and leaves a mark made on one row")
    @MainActor
    func undoLeavesAHandMark() throws {
        let (vm, dir) = try makeChecklistVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.results = sampleResults(60)
        vm.setChecklistMode(true)
        vm.markReviewed(volumeId: "v1", documentId: "d3")
        #expect(vm.pagedResults.count == 25)
        #expect(!vm.pagedResults.contains { $0.documentId == "d3" })

        // The page is now d1, d2, d4…d26: twenty-five rows, none of them the hand-marked one.
        #expect(vm.markReviewed(vm.pagedResults) == 25)
        #expect(vm.displayedResults.count == 34)

        #expect(vm.undoLastBulkMark() == 25)
        #expect(vm.displayedResults.count == 59)
        #expect(vm.markedReviewedKeys == [SearchViewModel.reviewedKey(volumeId: "v1", documentId: "d3")])
    }

    /// Marking the last page empties it, and the index must come back inside the pages that are
    /// left, as it does for a hand mark.
    @Test("Marking the last page reviewed re-clamps the page, and Undo keeps the index valid")
    @MainActor
    func markingTheLastPageClamps() throws {
        let (vm, dir) = try makeChecklistVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.results = sampleResults(60)
        vm.setChecklistMode(true)
        vm.currentPage = 2
        #expect(vm.pagedResults.map(\.documentId).first == "d51")

        #expect(vm.markReviewed(vm.pagedResults) == 10)
        #expect(vm.totalPages == 2)
        #expect(vm.currentPage == 0)

        #expect(vm.undoLastBulkMark() == 10)
        #expect(vm.totalPages == 3)
        #expect(vm.displayedResults.count == 60)
    }

    @Test("Turning Checklist Mode off, or on again, leaves nothing to undo")
    @MainActor
    func modeChangeClearsTheUndo() throws {
        let (vm, dir) = try makeChecklistVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.results = sampleResults(30)
        vm.setChecklistMode(true)
        vm.markReviewed(vm.pagedResults)
        #expect(vm.canUndoBulkMark)

        vm.setChecklistMode(false)
        #expect(!vm.canUndoBulkMark)
        #expect(vm.checklistAnchor == nil)
        #expect(vm.undoLastBulkMark() == 0)
        #expect(vm.displayedResults.count == 30)

        vm.setChecklistMode(true)
        #expect(!vm.canUndoBulkMark)
        #expect(vm.checklistAnchor != nil)
    }

    /// A marked page outlives a re-run of its search, and the re-run may load fewer of its results.
    /// Sixty results, page 1 marked; then the list is the ten a narrower filter left, of which
    /// `d21`…`d25` were on the marked page. Undo brings back five rows, and says five.
    @Test("Undo reports the rows that came back, which a re-run can make fewer than the mark hid")
    @MainActor
    func undoCountsTheRowsThatComeBack() throws {
        let (vm, dir) = try makeChecklistVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.results = sampleResults(60)
        vm.setChecklistMode(true)
        #expect(vm.markReviewed(vm.pagedResults) == 25)

        vm.results = Array(sampleResults(30).suffix(10))        // d21…d30
        #expect(vm.displayedResults.map(\.documentId) == ["d26", "d27", "d28", "d29", "d30"])
        #expect(vm.canUndoBulkMark)

        #expect(vm.undoLastBulkMark() == 5, "five of the marked page are in this list; twenty are not")
        #expect(vm.displayedResults.count == 10)
        #expect(vm.markedReviewedKeys.isEmpty, "the whole mark is taken back, whatever the list holds of it")
    }

    /// The same, with none of the marked page in the list: pressing Undo would change nothing on
    /// screen, so it is not offered. The mark stands, and is offered again when its rows are back.
    @Test("Undo is not offered while none of the marked page is in the list")
    @MainActor
    func undoIsNotOfferedWithNothingToBringBack() throws {
        let (vm, dir) = try makeChecklistVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.results = sampleResults(60)
        vm.setChecklistMode(true)
        vm.markReviewed(vm.pagedResults)

        vm.results = Array(sampleResults(60).suffix(10))        // d51…d60: none of d1…d25
        #expect(!vm.canUndoBulkMark)
        #expect(vm.markedReviewedKeys.count == 25, "the mark is kept")

        vm.results = sampleResults(60)
        #expect(vm.canUndoBulkMark, "and can be undone once its rows are in the list again")
        #expect(vm.undoLastBulkMark() == 25)
    }

    /// `d2` and `d3` are opened after the page is marked, which hides them whatever their mark.
    @Test("A marked result opened since stays hidden after Undo, and is not counted as back")
    @MainActor
    func undoDoesNotCountWhatAnOpeningStillHides() throws {
        let (vm, dir) = try makeChecklistVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.results = sampleResults(60)
        vm.setChecklistMode(true)
        vm.markReviewed(vm.pagedResults)
        vm.readSinceEnabledKeys = [SearchViewModel.reviewedKey(volumeId: "v1", documentId: "d2"),
                                   SearchViewModel.reviewedKey(volumeId: "v1", documentId: "d3")]

        #expect(vm.undoLastBulkMark() == 23)
        #expect(vm.displayedResults.count == 58)
    }

    /// A page mark answers with the rows that left the list. A result of the page that an opening
    /// already hid cannot be on the page, so this is the page's rows; the test hands the function
    /// such a result directly to pin the count's meaning.
    @Test("Mark Page Reviewed reports the rows that left the list")
    @MainActor
    func markCountsTheRowsThatLeft() throws {
        let (vm, dir) = try makeChecklistVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        let all = sampleResults(4)
        vm.results = all
        vm.setChecklistMode(true)
        vm.readSinceEnabledKeys = [SearchViewModel.reviewedKey(volumeId: "v1", documentId: "d4")]
        #expect(vm.displayedResults.count == 3)

        #expect(vm.markReviewed(all) == 3, "d4 was hidden already, so three rows left the list")
        #expect(vm.displayedResults.isEmpty)
    }

    /// The result list is identified by this counter with the page index, so it stands at its top
    /// after a page is marked or brought back. A mark on one row must leave it where it is.
    @Test("A bulk mark and its undo count as a change of page; a mark on one row does not")
    @MainActor
    func bulkMarksMoveTheListGeneration() throws {
        let (vm, dir) = try makeChecklistVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.results = sampleResults(60)
        vm.setChecklistMode(true)
        let start = vm.bulkMarkGeneration

        vm.markReviewed(volumeId: "v1", documentId: "d1")
        #expect(vm.bulkMarkGeneration == start, "a hand mark leaves the reader in mid-list")

        vm.markReviewed(vm.pagedResults)
        #expect(vm.bulkMarkGeneration == start + 1)

        vm.markReviewed([SearchResult]())
        #expect(vm.bulkMarkGeneration == start + 1, "a bulk mark that hid nothing changed no row")

        vm.undoLastBulkMark()
        #expect(vm.bulkMarkGeneration == start + 2)

        vm.undoLastBulkMark()
        #expect(vm.bulkMarkGeneration == start + 2, "an undo with nothing to bring back changed no row")
    }

    /// A view model over an index of two documents that both hold "alpha" and "beta".
    @MainActor
    private func makeIndexedChecklistVM() async throws -> (vm: SearchViewModel, dir: URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSChecklistSame-\(UUID().uuidString)", isDirectory: true)
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("s.sqlite")
        let store = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: store, databaseURL: dbURL, volumesDirectory: volDir,
            concurrencyLimit: 1
        )
        try writeSearchFixture(
            to: volDir.appendingPathComponent("frus1969-76v01.xml"),
            volumeId: "frus1969-76v01",
            documents: [
                (id: "d1", xml: "<head>One</head><p>alpha beta discussion of policy.</p>"),
                (id: "d2", xml: "<head>Two</head><p>alpha and beta notes on strategy.</p>"),
            ]
        )
        try await pipeline.indexVolume("frus1969-76v01")
        return (SearchViewModel(searchService: SearchService(fts5Store: store, pipeline: pipeline)), dir)
    }

    /// The owner's decision 4: on iPhone and iPad a re-run of the same search keeps the marks, as
    /// on the Mac. Until #1576 every completed search cleared them, so a tap on a tag chip, which
    /// re-runs the search on screen, undid every mark.
    @Test("A re-run of the same search keeps the marks, the undo and the anchor time")
    @MainActor
    func sameSearchRerunKeepsTheMarks() async throws {
        let (vm, dir) = try await makeIndexedChecklistVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.keywords = "alpha"
        await vm.search()
        try #require(vm.results.count == 2)
        vm.setChecklistMode(true)
        let anchorTime = try #require(vm.checklistEnabledAt)
        let opened = SearchViewModel.reviewedKey(volumeId: "frus1969-76v01", documentId: "d2")
        vm.readSinceEnabledKeys = [opened]
        #expect(vm.markReviewed(vm.pagedResults) == 1)
        #expect(vm.displayedResults.isEmpty)

        // The same words again, as a tag-chip tap or a facet runs them.
        await vm.search()
        #expect(vm.results.count == 2)
        #expect(vm.displayedResults.isEmpty, "the marks must survive a re-run of the same search")
        #expect(vm.canUndoBulkMark, "and so must the undo")
        #expect(vm.readSinceEnabledKeys == [opened], "and the documents opened since the mode came on")
        #expect(vm.checklistEnabledAt == anchorTime, "the anchor time is not moved by a re-run")

        // The same words under a changed filter: still the same search.
        vm.includeFrontMatter = false
        await vm.search()
        #expect(vm.searchError == nil)
        #expect(vm.results.count == 2, "the re-run loaded both documents, so an empty list is the marks' doing")
        #expect(vm.displayedResults.isEmpty)
        #expect(vm.checklistEnabledAt == anchorTime)

        // Other words: a new checklist, with nothing to undo.
        vm.keywords = "beta"
        await vm.search()
        #expect(vm.markedReviewedKeys.isEmpty)
        #expect(vm.readSinceEnabledKeys.isEmpty)
        #expect(!vm.canUndoBulkMark)
        #expect(vm.checklistEnabledAt != anchorTime)
        #expect(vm.displayedResults.count == 2)
    }

    /// The other half of decision 4. A browse has no words, so "the same query" cannot tell one
    /// person's mentions from another's: marks made in the first hid documents in the second.
    @Test("A browse of another person is another search: its marks are cleared")
    @MainActor
    func anotherPersonsBrowseClearsTheMarks() async throws {
        let (vm, dir) = try await makeIndexedChecklistVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        let mark = SearchViewModel.reviewedKey(volumeId: "frus1969-76v01", documentId: "d1")

        vm.personRefText = "p_KHA1"
        await vm.search()
        #expect(vm.searchError == nil, "precondition: a browse with no words runs")
        vm.setChecklistMode(true)
        let anchorTime = try #require(vm.checklistEnabledAt)
        vm.markReviewed(volumeId: "frus1969-76v01", documentId: "d1")

        // The same person under a changed filter: the same browse.
        vm.includeFrontMatter = false
        await vm.search()
        #expect(vm.searchError == nil, "the re-run completed, so the marks were kept by a search that settled")
        #expect(vm.markedReviewedKeys == [mark])
        #expect(vm.checklistEnabledAt == anchorTime)

        // Another person: another browse.
        vm.personRefText = "p_RWP1"
        await vm.search()
        #expect(vm.searchError == nil)
        #expect(vm.markedReviewedKeys.isEmpty, "marks made in one person's mentions leaked into another's")
        #expect(vm.checklistEnabledAt != anchorTime)
    }

    /// On iPhone and iPad a Filters field can be edited without a run. The rows on screen are
    /// then still the first person's, and marks made in them belong to that browse: the mode
    /// must anchor to the search that ran, not to the field as it stands when it is turned on.
    @Test("Checklist Mode turned on after a filter was edited and not run anchors to the search that ran")
    @MainActor
    func modeAnchorsToTheSearchThatRanNotTheEditedFilter() async throws {
        let (vm, dir) = try await makeIndexedChecklistVM()
        defer { try? FileManager.default.removeItem(at: dir) }

        vm.personRefText = "p_KHA1"
        await vm.search()
        #expect(vm.searchError == nil, "precondition: a browse with no words runs")
        let ran = try #require(ChecklistAnchor(query: "", parameters: vm.searchParameters).browse)

        // The field is edited, and the search is not run.
        vm.personRefText = "p_RWP1"
        vm.setChecklistMode(true)
        #expect(vm.checklistAnchor?.browse == ran, "the anchor is the browse whose rows are on screen")
        vm.markReviewed(volumeId: "frus1969-76v01", documentId: "d1")

        // Now it runs: another person's mentions, and the mark was made in the first's list.
        await vm.search()
        #expect(vm.searchError == nil)
        #expect(vm.markedReviewedKeys.isEmpty, "a mark made in one person's list hid a document in another's")
    }

    /// The Meaning path settles the checklist by the same rule, with the question as its words.
    @Test("In Meaning mode the same question keeps the marks and another question clears them")
    @MainActor
    func meaningSearchSettlesTheChecklist() async throws {
        let (vm, dir) = try makeChecklistVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.semanticBackend = ChecklistMeaningStub()
        vm.searchMode = .meaning
        vm.keywords = "why did the talks fail"
        await vm.search()
        try #require(vm.results.count == 3)
        vm.setChecklistMode(true)
        let anchorTime = try #require(vm.checklistEnabledAt)
        #expect(vm.markReviewed(vm.pagedResults) == 3)

        await vm.search()
        #expect(vm.displayedResults.isEmpty, "the same question is the same search")
        #expect(vm.canUndoBulkMark)
        #expect(vm.checklistEnabledAt == anchorTime)

        vm.keywords = "who opposed the treaty"
        await vm.search()
        #expect(vm.displayedResults.count == 3, "another question is another search")
        #expect(!vm.canUndoBulkMark)
        #expect(vm.checklistEnabledAt != anchorTime)
    }
}

/// A Meaning engine that answers every question with the same three rows, so a view-model test
/// can run the Meaning path with no model and no vectors.
@MainActor
private struct ChecklistMeaningStub: MeaningSearchRunning {
    func run(query: String, parameters: SearchParameters) async throws -> SemanticSearchBackend.Outcome {
        SemanticSearchBackend.Outcome(
            results: (1...3).map {
                SearchResult(documentId: "d\($0)", volumeId: "v1", header: "Doc \($0)", snippet: "",
                             bm25Score: -0.5, semanticScore: 0.5)
            },
            beyondLibrary: [],
            disclosure: SemanticSearchBackend.Disclosure(
                unscoredCandidates: 0, unscoredVolumes: 0, downloadingVolumes: 0,
                filtersApplied: false, filteredOut: 0, beyondUncheckedByFilters: false))
    }
}

#if os(macOS)

// MARK: - MacSearchViewModelTests

/// Tests for the submit-only search contract introduced in Session 129.
///
/// `MacSearchViewModel` must never fire a search while the user is merely typing.
/// A search fires only when `submitSearch()` is called (bound to `.onSubmit` / Return),
/// which commits `queryText` to `submittedQuery`. `searchTrigger` derives exclusively
/// from `submittedQuery` and `parametersVersion`.
///
/// Version history:
///   1.0 — Session 129: initial tests for submit-only constraint
@MainActor
struct MacSearchViewModelTests {

    // MARK: - SubmitOnlyTest

    @Test("SubmitOnlyTest: typing in queryText does not change searchTrigger")
    func queryTextDoesNotChangeTrigger() {
        let vm = MacSearchViewModel()
        let triggerBefore = vm.searchTrigger
        vm.queryText = "détente"
        #expect(vm.searchTrigger == triggerBefore,
                "searchTrigger must not change when queryText is typed — only submitSearch() should trigger a search")
    }

    @Test("SubmitOnlyTest: submitSearch() commits queryText to submittedQuery and changes searchTrigger")
    func submitSearchUpdatesTrigger() {
        let vm = MacSearchViewModel()
        let triggerBefore = vm.searchTrigger
        vm.queryText = "détente"
        vm.submitSearch()
        #expect(vm.submittedQuery == "détente",
                "submitSearch must commit queryText to submittedQuery")
        #expect(vm.searchTrigger != triggerBefore,
                "searchTrigger must change after submitSearch() so .task(id:) fires a search")
    }

    /// The macOS half of #1306's follow-up. This view model applies the scope through its
    /// `scopeNotes`/`scopeSummaries` didSets rather than by direct assignment, so the two flags
    /// have to be checked here as well as on iOS — one receiver could apply them and the other not.
    @Test("applyParameters carries a narrowed search scope onto the Mac view model")
    func applyParametersCarriesScopeOnMac() {
        let vm = MacSearchViewModel()
        vm.scopeSummaries = true
        vm.scopeNotes = true
        vm.applyParameters(SearchParameters(keywords: "d\u{00E9}tente",
                                            includeSummaries: false, includeNotes: false))
        #expect(vm.scopeSummaries == false, """
            The hand-off's narrowed scope did not reach the Mac view model, so Search still reads \
            the reader's own summaries and the chart's count cannot match it.
            """)
        #expect(vm.scopeNotes == false)
    }

    @Test("SubmitOnlyTest: submittedQuery is still empty after typing but before submit")
    func submittedQueryRemainsEmptyBeforeSubmit() {
        let vm = MacSearchViewModel()
        vm.queryText = "kennedy"
        #expect(vm.submittedQuery.isEmpty,
                "submittedQuery must stay empty until submitSearch() is explicitly called")
    }

    @Test("SubmitOnlyTest: scope toggle after submit re-fires search against submitted query")
    func scopeToggleAfterSubmitRetriggersSearch() {
        let vm = MacSearchViewModel()
        vm.queryText = "détente"
        vm.submitSearch()
        let triggerAfterSubmit = vm.searchTrigger
        vm.scopeNotes = false
        #expect(vm.searchTrigger != triggerAfterSubmit,
                "Scope toggle should change searchTrigger when a query has already been submitted")
    }

    // MARK: - ApplyParametersTest

    @Test("ApplyParametersTest: applyParameters sets both queryText and submittedQuery")
    func applyParametersSetsSubmittedQuery() {
        let vm = MacSearchViewModel()
        let params = SearchParameters(keywords: "détente")
        vm.applyParameters(params)
        #expect(vm.queryText == "détente",
                "applyParameters must populate the text field")
        #expect(vm.submittedQuery == "détente",
                "applyParameters must set submittedQuery so the programmatic search fires immediately")
    }

    // MARK: - Checklist Mode parity (#189-D)

    /// Builds `n` throwaway results (d1…dn, volume "v1") for exercising the checklist
    /// filtering/pagination math without a live index.
    private func sampleResults(_ n: Int) -> [SearchResult] {
        (1...n).map { SearchResult(documentId: "d\($0)", volumeId: "v1", header: "Doc \($0)", snippet: "", bm25Score: 0) }
    }

    @Test("Checklist mode hides reviewed results from displayedResults without double-counting")
    func checklistFiltersDisplayedResults() {
        let vm = MacSearchViewModel()
        vm.results = sampleResults(5)
        vm.setChecklistMode(true)
        // d1 is both opened AND marked; d2 only opened; d3 only marked.
        vm.readSinceEnabledKeys = [
            MacSearchViewModel.reviewedKey(volumeId: "v1", documentId: "d1"),
            MacSearchViewModel.reviewedKey(volumeId: "v1", documentId: "d2"),
        ]
        vm.markReviewed(volumeId: "v1", documentId: "d1")
        vm.markReviewed(volumeId: "v1", documentId: "d3")
        #expect(vm.displayedResults.map(\.documentId) == ["d4", "d5"])
        #expect(vm.results.count - vm.displayedResults.count == 3)   // d1,d2,d3 — union, no double count
    }

    @Test("Disabling checklist mode restores the full unfiltered result set")
    func checklistDisableRestoresAll() {
        let vm = MacSearchViewModel()
        vm.results = sampleResults(10)
        vm.setChecklistMode(true)
        vm.markReviewed(volumeId: "v1", documentId: "d1")
        vm.readSinceEnabledKeys = [MacSearchViewModel.reviewedKey(volumeId: "v1", documentId: "d2")]
        #expect(vm.displayedResults.count == 8)

        vm.setChecklistMode(false)
        #expect(vm.displayedResults.count == 10)
        #expect(vm.markedReviewedKeys.isEmpty)
        #expect(vm.readSinceEnabledKeys.isEmpty)
        #expect(vm.checklistEnabledAt == nil)
    }

    @Test("Marking the last page's results reviewed re-clamps the current page")
    func checklistPaginationClampsWhenPageEmpties() {
        let vm = MacSearchViewModel()
        vm.results = sampleResults(30)          // pageSize 20 → 2 pages
        vm.currentPage = 1                       // page 2: d21…d30
        #expect(vm.pagedResults.map(\.documentId) == (21...30).map { "d\($0)" })

        vm.setChecklistMode(true)                // resets currentPage to 0 on enable
        #expect(vm.currentPage == 0)
        vm.currentPage = 1                       // back to page 2 (still 2 pages: 30 shown)
        // Mark all of page 2 reviewed → 20 shown, 1 page → the stale page index clamps to 0.
        for i in 21...30 { vm.markReviewed(volumeId: "v1", documentId: "d\(i)") }
        #expect(vm.totalPages == 1)
        #expect(vm.currentPage == 0)
        #expect(vm.pagedResults.count == 20)
        #expect(!vm.pagedResults.contains { $0.documentId == "d21" })
    }

    /// Builds a `SearchService` over a one-volume index (d1/d2, both matching "alpha" and
    /// "beta") for exercising the query-change vs filter-rerun re-anchor contract. Returns the
    /// temp dir so the caller can remove it.
    private func makeAlphaBetaService() async throws -> (service: SearchService, dir: URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSMacChecklist-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("r.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        let store = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: store, databaseURL: dbURL, volumesDirectory: volDir,
            concurrencyLimit: 1
        )
        let service = SearchService(fts5Store: store, pipeline: pipeline)
        try writeSearchFixture(
            to: volDir.appendingPathComponent("frus1969-76v01.xml"),
            volumeId: "frus1969-76v01",
            documents: [
                (id: "d1", xml: "<head>One</head><p>alpha beta discussion of policy.</p>"),
                (id: "d2", xml: "<head>Two</head><p>alpha and beta notes on strategy.</p>"),
            ]
        )
        try await pipeline.indexVolume("frus1969-76v01")
        return (service, dir)
    }

    @Test("A new *query* re-anchors checklist state so a prior query's reviews don't leak")
    func checklistReAnchorsOnNewSearch() async throws {
        let (service, dir) = try await makeAlphaBetaService()
        defer { try? FileManager.default.removeItem(at: dir) }

        let vm = MacSearchViewModel()
        vm.queryText = "alpha"
        vm.submitSearch()
        await vm.performSearch(service: service)
        #expect(vm.results.count == 2)

        vm.setChecklistMode(true)
        let anchorA = try #require(vm.checklistEnabledAt)
        let first = vm.results[0]
        vm.markReviewed(volumeId: first.volumeId, documentId: first.documentId)
        #expect(vm.displayedResults.count == 1)   // one hidden under query A

        // A genuinely new query re-runs performSearch past its guards, re-anchoring.
        vm.queryText = "beta"
        vm.submitSearch()
        await vm.performSearch(service: service)
        #expect(vm.results.count == 2)
        #expect(vm.checklistMode)                                // mode persists across searches
        #expect(vm.markedReviewedKeys.isEmpty)                   // marks cleared for the new query
        #expect(vm.readSinceEnabledKeys.isEmpty)
        #expect(vm.checklistEnabledAt != anchorA)                // re-anchored to the new search
        #expect(vm.displayedResults.count == 2)                  // no cross-query hiding leaks in
    }

    @Test("A filter re-run of the SAME query preserves checklist reviewed marks")
    func checklistSurvivesFilterRerun() async throws {
        // Regression guard for the parity-review finding: macOS `performSearch` re-runs on every
        // filter/scope change (parametersVersion → searchTrigger), so the re-anchor must be gated
        // on the query actually changing — a filter re-run of the same query must NOT wipe marks.
        let (service, dir) = try await makeAlphaBetaService()
        defer { try? FileManager.default.removeItem(at: dir) }

        let vm = MacSearchViewModel()
        vm.queryText = "alpha"
        vm.submitSearch()
        await vm.performSearch(service: service)
        #expect(vm.results.count == 2)

        vm.setChecklistMode(true)
        let anchor = try #require(vm.checklistEnabledAt)
        let first = vm.results[0]
        let key = MacSearchViewModel.reviewedKey(volumeId: first.volumeId, documentId: first.documentId)
        vm.markReviewed(volumeId: first.volumeId, documentId: first.documentId)
        #expect(vm.displayedResults.count == 1)

        // A filter re-run: same submitted query, but parametersVersion bumps and performSearch
        // re-fires. Reviewed marks and the anchor must survive.
        vm.scopeSummaries = false
        await vm.performSearch(service: service)
        #expect(vm.checklistMode)
        #expect(vm.checklistEnabledAt == anchor)                 // anchor NOT moved by a filter re-run
        #expect(vm.markedReviewedKeys.contains(key))             // mark preserved
        #expect(vm.displayedResults.count == 1)                  // still hidden
    }

    // MARK: - Live user-tag filter (188-D parity, #212)

    @Test("MacSearchViewModel round-trips user tags through the shared filter VM (#212)")
    func macUserTagFilterRoundTrip() async throws {
        let (service, dir) = try await makeAlphaBetaService()
        defer { try? FileManager.default.removeItem(at: dir) }

        let tagA = UserTag(name: "Backchannel")
        let tagB = UserTag(name: "Détente")

        let vm = MacSearchViewModel()
        // An incoming filter carrying tagA must open the popover with tagA pre-checked.
        vm.parameters.userTagIds = [tagA.id.uuidString]
        vm.syncToFilterVM(searchService: service, userTags: [tagA, tagB])

        // Feed step: both tags available so the shared userTagsSection renders on macOS.
        #expect(vm.filterVM?.availableUserTags.count == 2)
        // Round-trip in: the active selection is reconstructed from parameters.
        #expect(vm.filterVM?.selectedUserTagIds == [tagA.id])

        // Toggle tagB on and apply.
        let versionBefore = vm.parametersVersion
        vm.filterVM?.selectedUserTagIds.insert(tagB.id)
        vm.applyAdvancedFilters()

        // Round-trip out: the selection is written back to parameters and a re-search fires.
        #expect(Set(vm.parameters.userTagIds) == Set([tagA.id.uuidString, tagB.id.uuidString]))
        #expect(vm.parametersVersion > versionBefore)

        // Clearing the selection removes the filter on the next apply.
        vm.filterVM?.selectedUserTagIds.removeAll()
        vm.applyAdvancedFilters()
        #expect(vm.parameters.userTagIds.isEmpty)
    }
}

#endif // os(macOS)

// MARK: - SearchDefaultsWiringTests

/// Verifies the Settings "Search Defaults" pane is actually consumed — the
/// `frus.search.*` keys were written by the pane but never read until
/// Session 2026-06-10 wired them into the search view models.
@MainActor
struct SearchDefaultsWiringTests {

    /// Builds a minimal SearchService for view-model construction.
    private func makeService(dir: URL) throws -> SearchService {
        let dbURL = dir.appendingPathComponent("defaults-test.sqlite")
        let store = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: store,
            databaseURL: dbURL,
            volumesDirectory: dir,
            concurrencyLimit: 1
        )
        return SearchService(fts5Store: store, pipeline: pipeline)
    }

    /// #1306 follow-up: the Corpus Analytics hand-off is the one place the app invites a reader to
    /// compare a chart's count against Search's, so it sends the two scope flags OFF. This is the
    /// receiving half — that `applyParameters` APPLIES them rather than keeping the view model's
    /// own scope, which is what makes two added arguments at the emitting end sufficient.
    ///
    /// It lives here rather than beside `applyParametersPopulatesFields` because that one sits in
    /// `PersonFilterTests`, and a scope guard buried in a person-filter suite is a guard nobody
    /// runs when they change scope.
    @Test("applyParameters carries a narrowed search scope onto the view model")
    func applyParametersCarriesScope() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSSearchScope-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let vm = SearchViewModel(searchService: try makeService(dir: dir))
        vm.includeSummaries = true
        vm.includeNotes = true
        vm.applyParameters(SearchParameters(keywords: "d\u{00E9}tente",
                                            includeSummaries: false, includeNotes: false))

        #expect(vm.includeSummaries == false, """
            The hand-off's narrowed scope did not reach the view model, so Search still reads the \
            reader's own summaries and the chart's count cannot match it.
            """)
        #expect(vm.includeNotes == false)
        #expect(vm.searchParameters.includeSummaries == false)
        #expect(vm.searchParameters.includeNotes == false)
    }

    @Test("SearchViewModel seeds scope and type filter from SearchDefaults and resets to them")
    func viewModelSeedsFromDefaults() async throws {
        let defaults = UserDefaults.standard
        let savedScope = defaults.object(forKey: SearchDefaults.scopeSummariesKey)
        let savedType  = defaults.object(forKey: SearchDefaults.typeFilterKey)
        defer {
            defaults.set(savedScope, forKey: SearchDefaults.scopeSummariesKey)
            defaults.set(savedType, forKey: SearchDefaults.typeFilterKey)
        }
        defaults.set(false, forKey: SearchDefaults.scopeSummariesKey)
        defaults.set("documentsOnly", forKey: SearchDefaults.typeFilterKey)

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSSearchDefaults-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let vm = SearchViewModel(searchService: try makeService(dir: dir))
        #expect(vm.includeSummaries == false,
                "scope toggles must seed from the persisted Search Defaults")
        #expect(vm.includeDocumentText == true)
        #expect(vm.documentTypeFilter == .documentsOnly)

        // A per-session override followed by Clear Filters returns to the
        // configured defaults, not the hardcoded ones.
        vm.includeSummaries = true
        vm.documentTypeFilter = .all
        vm.clearFilters()
        #expect(vm.includeSummaries == false)
        #expect(vm.documentTypeFilter == .documentsOnly)
    }

    @Test("advancedFilterSignature changes on applied filter edits, ignores legacy fields")
    func advancedFilterSignatureTracksAppliedFields() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSSearchSig-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let vm = SearchViewModel(searchService: try makeService(dir: dir))

        // Stable across repeated reads with no edits.
        let base = vm.advancedFilterSignature
        #expect(vm.advancedFilterSignature == base)

        // Every field applyAdvancedFilters() copies must perturb the signature —
        // this is what makes the macOS live filter popover (UI audit C4) apply edits.
        vm.documentTypeFilter = .editorialNotesOnly
        let afterType = vm.advancedFilterSignature
        #expect(afterType != base)

        vm.selectedSubseriesIds.insert("1969-76")
        let afterScope = vm.advancedFilterSignature
        #expect(afterScope != afterType)

        vm.dateRangeEnabled = true
        let afterDate = vm.advancedFilterSignature
        #expect(afterDate != afterScope)

        vm.personRefText = "p_N1"
        let afterPerson = vm.advancedFilterSignature
        #expect(afterPerson != afterDate)

        // User-tag selection (188-D / #212) must perturb the signature so the macOS live
        // popover re-applies a tag toggle, and it must be order-independent (sorted) so set
        // iteration order can't cause a spurious re-search.
        let idA = UUID(), idB = UUID()
        vm.selectedUserTagIds = [idA]
        let afterTagA = vm.advancedFilterSignature
        #expect(afterTagA != afterPerson)
        vm.selectedUserTagIds = [idA, idB]
        let afterTagAB = vm.advancedFilterSignature
        #expect(afterTagAB != afterTagA)
        vm.selectedUserTagIds = [idB, idA]  // same set, different insertion order
        #expect(vm.advancedFilterSignature == afterTagAB)

        // Legacy non-editable fields are deliberately excluded (cannot change while
        // the popover is open; excluding them avoids spurious re-searches).
        vm.phrase = "détente"
        vm.excludedTermsText = "telegram"
        #expect(vm.advancedFilterSignature == afterTagAB)
    }
}
