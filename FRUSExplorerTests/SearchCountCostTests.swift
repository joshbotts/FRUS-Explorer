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

/// The Q-M2 prerequisite: the count is cheap, and an unavailable count cannot pretend to be
/// a complete one.
///
/// ## Why these two things are one suite
/// Both were found by measuring the count against the real 6.3 GB store before R-1. The
/// unfiltered count joined a 1.8 GB table it did not need (2.55 s vs 0.011 s for the same
/// answer), and when that join's query failed the fallback made a truncated result set
/// render as complete. R-1's facet panel prints a denominator, so both had to be settled
/// before it was built on top.
///
/// Version history:
///   1.0 — Q-M2 prerequisite: initial implementation
@Suite("Search count: cost and honesty")
struct SearchCountCostTests {

    // MARK: - Fixture

    private func makeFixture(documents: Int = 40) async throws
        -> (dir: URL, service: SearchService, pipeline: IndexingPipeline) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSCount-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("test.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)

        // Half the documents are editorial notes, so the document-type filter — the one the
        // new index serves — actually partitions the set.
        var body = "<?xml version=\"1.0\"?>\n<TEI><text><body>\n"
        for index in 0..<documents {
            let kind = index.isMultiple(of: 2) ? "document" : "editorialNote"
            body += """
            <div type="\(kind)" xml:id="d\(index)">
              <head>\(index + 1). Item \(index)</head>
              <p>The doctrine of containment shaped policy toward europe in \(1945 + index % 8).</p>
            </div>

            """
        }
        body += "</body></text></TEI>"
        try body.data(using: .utf8)!.write(to: volDir.appendingPathComponent("vol1.xml"))

        let fts5 = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: fts5, databaseURL: dbURL, volumesDirectory: volDir, concurrencyLimit: 1)
        try await pipeline.indexVolume("vol1")
        return (dir, SearchService(fts5Store: fts5, pipeline: pipeline), pipeline)
    }

    private func cleanUp(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    // MARK: - The unfiltered count drops its joins without changing the answer

    /// The correctness guarantee behind the optimisation.
    ///
    /// The unfiltered count no longer joins `document_cache`, which is only safe because an
    /// FTS rowid with no content row cannot exist (both FTS tables are external-content over
    /// `document_cache` with the full trigger set). This asserts the equivalence rather than
    /// trusting it: the joined shape and the bare shape must agree, on every query shape the
    /// app can produce.
    @Test("The unfiltered count equals the joined count it replaced")
    func countMatchesTheJoinedShape() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }

        for query in ["containment", "europe", "containment europe", "policy OR doctrine",
                      "=containment", "NEAR(containment europe, 20)", "zzznothing"] {
            let params = SearchParameters(keywords: query)
            let optimised = try await service.searchCount(parameters: params)
            let joined = try await pipeline.searchDocumentsCountJoinedForTesting(
                corpusMatch: try await service.matchExpressions(for: params).corpus,
                userContentMatch: try await service.matchExpressions(for: params).userContent)
            #expect(optimised == joined,
                    "\(query): optimised=\(optimised) joined=\(joined)")
        }
    }

    /// The optimisation only fires when there is no WHERE clause, so the filtered path must
    /// keep working — and must still agree with the fetched results.
    @Test("A filtered count still applies its filters")
    func filteredCountStillFilters() async throws {
        let (dir, service, _) = try await makeFixture()
        defer { cleanUp(dir) }

        var params = SearchParameters(keywords: "containment")
        let unfiltered = try await service.searchCount(parameters: params)

        params.documentTypeFilter = .documentsOnly
        let documentsOnly = try await service.searchCount(parameters: params)
        #expect(documentsOnly < unfiltered, "the filter must narrow the count")
        let fetchedDocumentsOnly = try await service.search(parameters: params, limit: 1000).count
        #expect(documentsOnly == fetchedDocumentsOnly)

        params.documentTypeFilter = .editorialNotesOnly
        let notesOnly = try await service.searchCount(parameters: params)
        #expect(notesOnly + documentsOnly == unfiltered,
                "the two halves must partition the unfiltered set exactly")
    }

    /// `includeFrontMatter` defaults true and emits no condition, which is why the
    /// unfiltered path is the *default* path rather than an edge case.
    @Test("The default parameters really do take the no-WHERE path")
    func defaultParametersAreUnfiltered() async throws {
        let (dir, service, _) = try await makeFixture()
        defer { cleanUp(dir) }

        let params = SearchParameters(keywords: "containment")
        #expect(params.includeFrontMatter, "if this default changed, the optimisation stops firing")
        #expect(params.documentTypeFilter == .all)
        // And the count still agrees with the result set, which is the user-visible contract.
        let counted = try await service.searchCount(parameters: params)
        let fetched = try await service.search(parameters: params, limit: 1000).count
        #expect(counted == fetched)
    }

    // MARK: - The facet index exists

    @Test("The facet covering index is created, and the planner uses it")
    func facetIndexIsPresentAndUsed() async throws {
        let (dir, _, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }

        #expect(try await pipeline.indexNamesForTesting(onTable: "document_cache")
                    .contains("idx_document_cache_facet"),
                "the facet index must exist — without it the document-type aggregate scans the whole table")

        // The acceptance criterion the brief settled on is the query PLAN, not a stopwatch:
        // a timing test on a 40-document fixture cannot distinguish a covering index from a
        // full scan, but the plan can.
        let plan = try await pipeline.queryPlanForTesting("""
            SELECT is_editorial_note, COUNT(*) FROM document_cache
            WHERE is_front_matter = 0 GROUP BY is_editorial_note
            """)
        #expect(plan.contains("idx_document_cache_facet"),
                "the document-type aggregate must use the covering index — plan was: \(plan)")
    }
}
