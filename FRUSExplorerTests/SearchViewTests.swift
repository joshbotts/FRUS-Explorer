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

        let vm = SearchViewModel(searchService: service, subjectTagStore: subjectStore)
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

        let vm = SearchViewModel(searchService: service, subjectTagStore: subjectStore)
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

        let vm = SearchViewModel(searchService: service, subjectTagStore: subjectStore)
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

        let vm = SearchViewModel(searchService: service, subjectTagStore: subjectStore)
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

        let vm = SearchViewModel(searchService: service, subjectTagStore: subjectStore)

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

        let vm = SearchViewModel(searchService: service, subjectTagStore: subjectStore)
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

        let vm = SearchViewModel(searchService: service, subjectTagStore: subjectStore)
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

        let vm = SearchViewModel(searchService: service, subjectTagStore: subjectStore)
        let params = SearchParameters(
            keywords: "détente",
            personRef: "kissinger-henry-a"
        )
        vm.applyParameters(params)

        #expect(vm.keywords == "détente")
        #expect(vm.personRefText == "kissinger-henry-a")
        #expect(vm.searchParameters.personRef == "kissinger-henry-a")
    }
}
