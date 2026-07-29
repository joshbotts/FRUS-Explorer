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

/// Exact-word mode end to end: real pipeline, real FTS5 index, real search (Q-3b).
///
/// ## The one that matters
/// `countAgreesWithResults` is the reason this suite exists. The post-filter lives in the
/// SQL `WHERE` clause specifically so `searchDocumentsCount` sees it; if it were applied
/// in Swift over fetched rows instead, the count would keep reporting the stemmed
/// superset — a number strictly larger than the result list, shown to a researcher who is
/// about to publish it. Every other test here could pass with that bug present.
///
/// Version history:
///   1.0 — Q-3b: initial implementation
@Suite("Exact-word search")
struct ExactWordSearchTests {

    // MARK: - Fixture

    /// Four documents that separate the literal word from its stem-mates:
    /// - d1 carries the literal *containment*, twice.
    /// - d2 carries only *contain* / *containing* — the trap. Stemmed search finds it;
    ///   exact search must not.
    /// - d3 carries *container*, which stems to the same root and is about shipping.
    /// - d4 carries *containment* in its **header** only, which is a searched column.
    private func makeVolumeXML() -> String {
        """
        <?xml version="1.0"?>
        <TEI><text><body>
        <div type="document" xml:id="d1">
          <head>1. Memorandum on Policy</head>
          <p>The doctrine of containment shaped the response. Containment endured.</p>
        </div>
        <div type="document" xml:id="d2">
          <head>2. Telegram</head>
          <p>We must contain the threat; containing it is the immediate priority.</p>
        </div>
        <div type="document" xml:id="d3">
          <head>3. Shipping Report</head>
          <p>The container arrived at the port without incident.</p>
        </div>
        <div type="document" xml:id="d4">
          <head>4. Containment and the Alliance</head>
          <p>A discussion of policy in western europe.</p>
        </div>
        </body></text></TEI>
        """
    }

    private func makeFixture() async throws -> (dir: URL, service: SearchService) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSExact-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("test.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        try makeVolumeXML().data(using: .utf8)!.write(to: volDir.appendingPathComponent("vol1.xml"))

        let fts5 = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: fts5, databaseURL: dbURL, volumesDirectory: volDir, concurrencyLimit: 1)
        try await pipeline.indexVolume("vol1")
        return (dir, SearchService(fts5Store: fts5, pipeline: pipeline))
    }

    /// Same fixture, also handing back the pipeline for tests that need to write user text.
    private func makeFixtureWithPipeline() async throws
        -> (dir: URL, service: SearchService, pipeline: IndexingPipeline) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSExact-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("test.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        try makeVolumeXML().data(using: .utf8)!.write(to: volDir.appendingPathComponent("vol1.xml"))

        let fts5 = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: fts5, databaseURL: dbURL, volumesDirectory: volDir, concurrencyLimit: 1)
        try await pipeline.indexVolume("vol1")
        return (dir, SearchService(fts5Store: fts5, pipeline: pipeline), pipeline)
    }

    // MARK: - The stemmed baseline

    @Test("Without the sigil, the search is stemmed and catches the whole family")
    func stemmedBaselineIsBroad() async throws {
        let (dir, service) = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: dir) }

        let results = try await service.search(parameters: SearchParameters(keywords: "containment"))
        let ids = Set(results.map(\.documentId))
        // This breadth is exactly the trap the reports name: a search for "containment"
        // silently returns a telegram about containing a threat and a shipping report.
        #expect(ids.contains("d1"))
        #expect(ids.contains("d2"), "stemmed search must reach contain/containing")
        #expect(ids.contains("d3"), "stemmed search must reach container")
        #expect(ids.contains("d4"))
    }

    // MARK: - Exact mode

    @Test("With the sigil, only the literal word matches")
    func exactNarrowsToTheLiteralWord() async throws {
        let (dir, service) = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: dir) }

        let results = try await service.search(parameters: SearchParameters(keywords: "=containment"))
        let ids = Set(results.map(\.documentId))
        #expect(ids.contains("d1"), "d1 carries the literal word")
        #expect(!ids.contains("d2"), "contain/containing is not containment")
        #expect(!ids.contains("d3"), "container is not containment")
    }

    /// Header text is reachable — but note *why*, because the obvious reading is wrong.
    ///
    /// `IndexingPipeline.extractBodyText` maps **every** node's `plainText`, `<head>`
    /// included, so `body_text` is a superset of `header`, `dateline` and `source_note`.
    /// The OR across corpus columns is therefore redundant on the corpus path, and a
    /// mutation restricting the filter to `body_text` alone passes this test — correctly.
    /// The OR earns its keep on `summary_text` / `note_text`, which are genuinely separate
    /// columns; `exactMatchesInASummaryOnly` is the test that proves it.
    @Test("A header-only occurrence matches, because body_text subsumes the header")
    func exactMatchesInTheHeader() async throws {
        let (dir, service) = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: dir) }

        let results = try await service.search(parameters: SearchParameters(keywords: "=containment"))
        #expect(Set(results.map(\.documentId)).contains("d4"),
                "d4 carries Containment in its header, which body_text subsumes")
    }

    /// The test that actually requires the column OR. `summary_text` is a separate column
    /// that `body_text` does not contain, so a filter checking only `body_text` fails here.
    @Test("An exact term is satisfied by a summary the query searched")
    func exactMatchesInASummaryOnly() async throws {
        let (dir, service, pipeline) = try await makeFixtureWithPipeline()
        defer { try? FileManager.default.removeItem(at: dir) }

        // d3 is the shipping report: its body has "container" but never "containment".
        try await pipeline.updateSummaryText(
            volumeId: "vol1", documentId: "d3",
            responseText: "This memorandum concerns containment of the shipping dispute.")

        var params = SearchParameters(keywords: "=containment")
        params.includeSummaries = true
        let ids = Set(try await service.search(parameters: params, limit: 100).map(\.documentId))
        #expect(ids.contains("d3"),
                "the literal word is in d3's summary, which is a searched column")

        // And with summaries out of scope it must disappear again — the filter may never
        // be satisfied by a column the query did not look at.
        var narrowed = SearchParameters(keywords: "=containment")
        narrowed.includeSummaries = false
        narrowed.includeNotes = false
        let narrowedIds = Set(try await service.search(parameters: narrowed, limit: 100).map(\.documentId))
        #expect(!narrowedIds.contains("d3"))
    }

    /// Kills the substring reading of "exact". A substring matcher would say
    /// "containment" contains "contain" and return d1 and d4, which is the opposite of
    /// what exact mode is for.
    @Test("An exact term does not match a longer word that contains it")
    func exactIsNotASubstringMatch() async throws {
        let (dir, service) = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: dir) }

        let ids = Set(try await service.search(parameters: SearchParameters(keywords: "=contain"),
                                               limit: 100).map(\.documentId))
        #expect(ids.contains("d2"), "d2 has the literal word 'contain'")
        #expect(!ids.contains("d1"), "'containment' is not 'contain'")
        #expect(!ids.contains("d4"), "'Containment' is not 'contain'")
        #expect(!ids.contains("d3"), "'container' is not 'contain'")
    }

    // MARK: - The count cannot lie

    @Test("The count agrees with the results — exactly, not approximately")
    func countAgreesWithResults() async throws {
        let (dir, service) = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: dir) }

        for query in ["=containment", "containment", "=containment europe", "=alliance"] {
            let params = SearchParameters(keywords: query)
            let results = try await service.search(parameters: params, limit: 1000)
            let count = try await service.searchCount(parameters: params)
            #expect(count == results.count,
                    "count/result mismatch for \(query): count=\(count) results=\(results.count)")
        }
    }

    /// The sharpest version of the same point: exact must be strictly narrower than
    /// stemmed *in the count*, not merely in the rows.
    @Test("The exact count is strictly smaller than the stemmed count")
    func exactCountIsStrictlySmaller() async throws {
        let (dir, service) = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: dir) }

        let stemmed = try await service.searchCount(parameters: SearchParameters(keywords: "containment"))
        let exact = try await service.searchCount(parameters: SearchParameters(keywords: "=containment"))
        #expect(exact < stemmed,
                "exact=\(exact) stemmed=\(stemmed) — the post-filter is not reaching the count")
        #expect(exact > 0, "the literal word is present, so exact must not be empty")
    }

    /// Pagination is computed from the count, so a count that ignored the filter would
    /// also produce phantom pages.
    @Test("Pagination stays exact under an exact filter")
    func paginationStaysExact() async throws {
        let (dir, service) = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: dir) }

        let params = SearchParameters(keywords: "=containment")
        let count = try await service.searchCount(parameters: params)
        let firstPage = try await service.search(parameters: params, limit: 1, offset: 0)
        #expect(firstPage.count == 1)
        // One past the end must be empty, not a row the filter should have removed.
        let past = try await service.search(parameters: params, limit: 10, offset: count)
        #expect(past.isEmpty, "offset \(count) returned \(past.count) rows past the end")
    }

    // MARK: - Scope honesty

    @Test("An exact term cannot be satisfied by a column the query did not search")
    func scopeLimitsWhichColumnsCount() async throws {
        let (dir, service) = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: dir) }

        // With document text off and only user content in scope, the corpus columns are
        // out of scope — so nothing should match, rather than the body rescuing it.
        var params = SearchParameters(keywords: "=containment")
        params.includeDocumentText = false
        params.includeSummaries = true
        params.includeNotes = true

        let columns = SearchService.exactColumns(for: params)
        #expect(!columns.contains("body_text"), "body_text is out of scope here")
        #expect(columns.contains("summary_text"))

        let results = try await service.search(parameters: params)
        #expect(results.isEmpty, "no summary carries the word, so nothing may match")
    }

    @Test("exactColumns tracks the scope flags")
    func exactColumnsTrackScope() {
        var params = SearchParameters(keywords: "=x")
        params.includeDocumentText = true
        params.includeSummaries = false
        params.includeNotes = false
        #expect(SearchService.exactColumns(for: params)
                == ["header", "dateline", "source_note", "body_text"])

        params.includeSummaries = true
        params.includeNotes = true
        #expect(SearchService.exactColumns(for: params).contains("summary_text"))
        #expect(SearchService.exactColumns(for: params).contains("note_text"))

        params.includeDocumentText = false
        #expect(SearchService.exactColumns(for: params) == ["summary_text", "note_text"])
    }

    // MARK: - Mixed queries

    @Test("Exact and stemmed terms coexist in one query")
    func mixedQueryAppliesOnlyToTheMarkedTerm() async throws {
        let (dir, service) = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: dir) }

        // `=containment` exact, `polic*` stemmed. d1 has containment + policy; d4 has
        // Containment (header) + policy. d2/d3 have neither literal containment.
        let results = try await service.search(parameters: SearchParameters(keywords: "=containment polic*"))
        let ids = Set(results.map(\.documentId))
        #expect(ids.contains("d1"))
        #expect(!ids.contains("d2"))
        #expect(!ids.contains("d3"))
    }

    @Test("A query with no sigil is completely unaffected by this feature")
    func noSigilNoBehaviourChange() async throws {
        let (dir, service) = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: dir) }

        let params = SearchParameters(keywords: "policy")
        #expect(SearchService.exactTerms(from: params).isEmpty)
        let count = try await service.searchCount(parameters: params)
        let results = try await service.search(parameters: params, limit: 1000)
        #expect(count == results.count)
        #expect(count > 0)
    }
}
