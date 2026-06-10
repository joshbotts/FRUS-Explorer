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
        let subjectStore = SubjectTagStore(entries: [], appearances: [])
        let pipeline = try IndexingPipeline(
            fts5Store: store,
            databaseURL: dbURL,
            volumesDirectory: volDir,
            subjectTagStore: subjectStore,
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
        let subjectStore = SubjectTagStore(entries: [], appearances: [])
        let pipeline = try IndexingPipeline(
            fts5Store: store,
            databaseURL: dbURL,
            volumesDirectory: volDir,
            subjectTagStore: subjectStore,
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
        let subjectStore = SubjectTagStore(entries: [], appearances: [])
        let pipeline = try IndexingPipeline(
            fts5Store: store, databaseURL: dbURL, volumesDirectory: volDir,
            subjectTagStore: subjectStore, concurrencyLimit: 1
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
        let subjectStore = SubjectTagStore(entries: [], appearances: [])
        let pipeline = try IndexingPipeline(
            fts5Store: store, databaseURL: dbURL, volumesDirectory: volDir,
            subjectTagStore: subjectStore, concurrencyLimit: 1
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
        let subjectStore = SubjectTagStore(entries: [], appearances: [])
        let pipeline = try IndexingPipeline(
            fts5Store: store, databaseURL: dbURL, volumesDirectory: volDir,
            subjectTagStore: subjectStore, concurrencyLimit: 1
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
        let subjectStore = SubjectTagStore(entries: [], appearances: [])
        let pipeline = try IndexingPipeline(
            fts5Store: store, databaseURL: dbURL, volumesDirectory: volDir,
            subjectTagStore: subjectStore, concurrencyLimit: 1
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
        let subjectStore = SubjectTagStore(entries: [], appearances: [])
        let pipeline = try IndexingPipeline(
            fts5Store: store, databaseURL: dbURL, volumesDirectory: volDir,
            subjectTagStore: subjectStore, concurrencyLimit: 1
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
        let subjectStore = SubjectTagStore(entries: [], appearances: [])
        let pipeline = try IndexingPipeline(
            fts5Store: store, databaseURL: dbURL, volumesDirectory: volDir,
            subjectTagStore: subjectStore, concurrencyLimit: 1
        )
        let service = SearchService(fts5Store: store, pipeline: pipeline)

        let vm = SearchViewModel(searchService: service)
        let params = SearchParameters(
            keywords: "détente",
            personRef: "kissinger-henry-a"
        )
        vm.applyParameters(params)

        #expect(vm.keywords == "détente")
        #expect(vm.personRefText == "kissinger-henry-a")
        #expect(vm.searchParameters.personRef == "kissinger-henry-a")
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
        let subjectStore = SubjectTagStore(entries: [], appearances: [])
        let pipeline = try IndexingPipeline(
            fts5Store: store,
            databaseURL: dbURL,
            volumesDirectory: volDir,
            subjectTagStore: subjectStore,
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
}

#endif // os(macOS)
