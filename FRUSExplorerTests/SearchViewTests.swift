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

    // MARK: - SubjectTagFilterTest

    @Test("Selected subject tag IDs are included in search parameters")
    @MainActor
    func subjectTagFilterIncludedInParameters() throws {
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
        vm.selectedSubjectTagIds = ["kissinger-henry-a", "soviet-union"]

        let params = vm.searchParameters
        #expect(params.subjectTagIds.contains("kissinger-henry-a"))
        #expect(params.subjectTagIds.contains("soviet-union"))
        #expect(params.subjectTagIds.count == 2)
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
        #expect(vm.selectedSubjectTagIds.contains("nixon-richard-m"))
        #expect(vm.selectedSubjectTagIds.contains("foreign-policy"))
        #expect(vm.selectedSubjectTagIds.count == 2)
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
