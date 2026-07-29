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

/// Facet aggregation over a result set (R-1a).
///
/// ## Two kinds of test here, and the second kind is the unusual one
/// The correctness tests assert counts against a fixture. The **plan** tests assert which
/// query plan SQLite chose, because that is the only thing a small fixture can prove about
/// cost: driven from the match set an aggregate is a rowid seek, and written the natural way
/// the same query becomes a 1.8 GB table scan — measured at 0.001 s versus 11.07 s over the
/// *same* 350 matches. On forty documents both are instant. Only the plan distinguishes them,
/// so `SCAN dc` in a plan is the bug.
///
/// Version history:
///   1.0 — R-1a: initial implementation
@Suite("Result-set facets")
struct ResultSetFacetsTests {

    // MARK: - Fixture

    /// Twelve documents with deliberately uneven distributions, so a facet that silently
    /// returned the whole corpus, or lost its ordering, or counted rows instead of
    /// documents, would show up as a wrong number rather than a plausible one.
    ///
    /// - `containment` appears in 8; `europe` in 6; both in 4.
    /// - Dates span 1946–1949, weighted to 1948, with two documents undated.
    /// - Half are editorial notes.
    private func makeVolumeXML(volume: String, ids: Range<Int>) -> String {
        var xml = "<?xml version=\"1.0\"?>\n<TEI><text><body>\n"
        for index in ids {
            let kind = index.isMultiple(of: 2) ? "document" : "editorialNote"
            // Two documents (index 10, 11) get no <dateline>, so they are undated.
            let dated = index < 10
            let year = [1946, 1947, 1948, 1948, 1948, 1949][index % 6]
            let terms = index < 8 ? "containment" : "rollback"
            let extra = index % 2 == 0 && index < 6 ? " and europe" : (index < 8 ? " and europe" : "")
            xml += """
            <div type="\(kind)" xml:id="d\(index)">
              <head>\(index + 1). Item \(index)</head>
            \(dated ? "  <dateline>Washington, \(year)</dateline>\n" : "")  <p>The doctrine of \(terms)\(extra) shaped policy.</p>
            </div>

            """
        }
        xml += "</body></text></TEI>"
        return xml
    }

    private func makeFixture() async throws
        -> (dir: URL, service: SearchService, pipeline: IndexingPipeline) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSFacet-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("test.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        // Two volumes, so the volume facet has something to rank.
        try makeVolumeXML(volume: "vol1", ids: 0..<8).data(using: .utf8)!
            .write(to: volDir.appendingPathComponent("vol1.xml"))
        try makeVolumeXML(volume: "vol2", ids: 8..<12).data(using: .utf8)!
            .write(to: volDir.appendingPathComponent("vol2.xml"))

        let fts5 = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: fts5, databaseURL: dbURL, volumesDirectory: volDir, concurrencyLimit: 1)
        try await pipeline.indexVolume("vol1")
        try await pipeline.indexVolume("vol2")
        return (dir, SearchService(fts5Store: fts5, pipeline: pipeline), pipeline)
    }

    private func cleanUp(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func facets(
        _ pipeline: IndexingPipeline, _ service: SearchService,
        query: String, request: FacetRequest = .all,
        configure: (inout SearchParameters) -> Void = { _ in }
    ) async throws -> ResultSetFacets {
        var params = SearchParameters(keywords: query)
        configure(&params)
        let expressions = try await service.matchExpressions(for: params)
        return try await pipeline.resultSetFacets(
            corpusMatch: expressions.corpus, userContentMatch: expressions.userContent,
            filters: await service.filtersForTesting(params), request: request)
    }

    // MARK: - The match count is the denominator

    @Test("The facet match count equals the search's own count")
    func matchCountAgreesWithSearch() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }

        for query in ["containment", "europe", "containment europe", "rollback"] {
            let expected = try await service.searchCount(parameters: SearchParameters(keywords: query))
            let computed = try await facets(pipeline, service, query: query).matchCount
            #expect(computed == expected, "\(query): facets=\(computed) search=\(expected)")
        }
    }

    @Test("A query with no matches yields an empty breakdown, not a crash")
    func emptyMatchIsEmpty() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }

        let result = try await facets(pipeline, service, query: "zzznothingatall")
        #expect(result.matchCount == 0)
        #expect(result.years.isEmpty && result.volumes.isEmpty && result.people.isEmpty)
    }

    // MARK: - Sections

    @Test("Volume buckets sum to the match and are ordered by count")
    func volumeBucketsSumAndOrder() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }

        let result = try await facets(pipeline, service, query: "containment")
        #expect(!result.volumes.isEmpty)
        // Every matched document lives in exactly one volume, so the buckets must partition
        // the match exactly. A facet that counted join rows instead of documents would
        // overshoot here.
        #expect(result.volumes.reduce(0) { $0 + $1.count } == result.matchCount)
        let counts = result.volumes.map(\.count)
        #expect(counts == counts.sorted(by: >), "volumes must be ordered by count descending")
    }

    @Test("Document-type buckets partition the match exactly")
    func documentTypePartitions() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }

        let result = try await facets(pipeline, service, query: "containment")
        #expect(result.documentTypes.reduce(0) { $0 + $1.count } == result.matchCount)
        #expect(result.documentTypes.count <= 2)
    }

    @Test("Year buckets plus undated documents account for the whole match")
    func yearsPlusUndatedAccountForTheMatch() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }

        let result = try await facets(pipeline, service, query: "containment")
        let dated = result.years.reduce(0) { $0 + $1.count }
        // The reason `undatedCount` exists: without it the bars would sum to less than the
        // match and nothing would explain the difference.
        #expect(dated + result.undatedCount == result.matchCount,
                "years=\(dated) undated=\(result.undatedCount) match=\(result.matchCount)")
    }

    @Test("Year buckets are ordered newest first and look like years")
    func yearsAreOrderedAndWellFormed() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }

        let result = try await facets(pipeline, service, query: "containment")
        let keys = result.years.map(\.key)
        #expect(keys == keys.sorted(by: >))
        #expect(keys.allSatisfy { $0.count == 4 && Int($0) != nil }, "got \(keys)")
    }

    /// A document may mention several refs that roll up to one person; the facet counts
    /// **documents**, so it must not double-count.
    @Test("People counts never exceed the match size")
    func peopleCountDocumentsNotMentions() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }

        let result = try await facets(pipeline, service, query: "containment")
        for bucket in result.people {
            #expect(bucket.count <= result.matchCount,
                    "\(bucket.label) counted \(bucket.count) of \(result.matchCount) — mentions, not documents")
        }
    }

    // MARK: - Filters

    /// Facets describe the set the researcher is looking at, so the filters belong in the
    /// match-set phase. A facet computed over the unfiltered match would silently disagree
    /// with the result list.
    @Test("Facets respect the active filters")
    func facetsRespectFilters() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }

        let unfiltered = try await facets(pipeline, service, query: "containment")
        let notesOnly = try await facets(pipeline, service, query: "containment") {
            $0.documentTypeFilter = .editorialNotesOnly
        }
        #expect(notesOnly.matchCount < unfiltered.matchCount)
        #expect(notesOnly.documentTypes.count == 1, "only one type can survive that filter")
        // And the filtered count must agree with what a filtered search would return.
        var params = SearchParameters(keywords: "containment")
        params.documentTypeFilter = .editorialNotesOnly
        let filteredCount = try await service.searchCount(parameters: params)
        #expect(notesOnly.matchCount == filteredCount)
    }

    @Test("A volume filter narrows the volume facet to that volume")
    func volumeFilterNarrowsTheFacet() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }

        let all = try await facets(pipeline, service, query: "containment")
        let target = try #require(all.volumes.first?.key)
        let scoped = try await facets(pipeline, service, query: "containment") {
            $0.volumeIds = [target]
        }
        #expect(scoped.volumes.map(\.key) == [target])
        #expect(scoped.matchCount < all.matchCount || all.volumes.count == 1)
    }

    // MARK: - Bounds

    @Test("A truncated section reports how much it is hiding")
    func boundsReportTruncation() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }

        // Force truncation with a limit of one.
        let result = try await facets(pipeline, service, query: "containment",
                                     request: FacetRequest(sections: [.volumes], limitPerSection: 1))
        let bound = try #require(result.bounds[.volumes])
        #expect(bound.shown == 1)
        #expect(bound.total >= 1)
        if bound.total > 1 {
            #expect(bound.isTruncated, "the house rule is no silent truncation")
        }
    }

    /// The bound's `total` must be the real distinct cardinality, not the number of rows
    /// returned — that is the difference between "top 4 of 47" and the truth, which on the
    /// real store is 552 volumes and 14,615 person rollups.
    @Test("The bound total is the real cardinality, not the row count")
    func boundTotalIsRealCardinality() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }

        let full = try await facets(pipeline, service, query: "containment",
                                   request: FacetRequest(sections: [.volumes], limitPerSection: 50))
        let clipped = try await facets(pipeline, service, query: "containment",
                                      request: FacetRequest(sections: [.volumes], limitPerSection: 1))
        #expect(clipped.bounds[.volumes]?.total == full.volumes.count,
                "the total must not shrink just because fewer rows were returned")
    }

    @Test("An untruncated section still reports a bound, with shown == total")
    func untruncatedSectionStillReportsABound() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }

        let result = try await facets(pipeline, service, query: "containment")
        let bound = try #require(result.bounds[.documentType])
        #expect(!bound.isTruncated)
        #expect(bound.shown == bound.total)
    }

    // MARK: - Laziness

    @Test("Only the requested sections are computed")
    func onlyRequestedSectionsAreComputed() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }

        let result = try await facets(pipeline, service, query: "containment",
                                     request: .one(.volumes))
        #expect(!result.volumes.isEmpty)
        #expect(result.years.isEmpty && result.people.isEmpty && result.provenance.isEmpty)
        #expect(result.bounds[.years] == nil, "an uncomputed section has no bound")
        #expect(result.matchCount > 0, "but the denominator is always available")
    }

    @Test("Undated documents are only counted when years are requested")
    func undatedIsScopedToTheYearsSection() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }

        let volumesOnly = try await facets(pipeline, service, query: "containment",
                                           request: .one(.volumes))
        let yearsOnly = try await facets(pipeline, service, query: "containment",
                                        request: .one(.years))
        #expect(volumesOnly.undatedCount == 0)
        #expect(yearsOnly.undatedCount > 0)
    }

    // MARK: - Coverage

    @Test("Provenance coverage reports two denominators, not one")
    func provenanceCoverageHasTwoDenominators() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }

        let result = try await facets(pipeline, service, query: "containment",
                                     request: .one(.provenance))
        let coverage = result.provenanceCoverage
        #expect(coverage.matchCount == result.matchCount)
        // Parsed is a superset of record-group-bearing, and both are bounded by the match.
        #expect(coverage.withRecordGroup <= coverage.parsed)
        #expect(coverage.parsed <= coverage.matchCount)
    }

    // MARK: - The insight line

    @Test("The top-volume share is computed, and is nil when there is nothing to divide")
    func topVolumeShareIsComputed() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }

        let result = try await facets(pipeline, service, query: "containment")
        let share = try #require(result.topVolumeShare(3))
        #expect(share > 0 && share <= 1.0)
        // With two volumes in the fixture, the top three hold everything.
        #expect(abs(share - 1.0) < 0.0001)
        #expect(ResultSetFacets.empty().topVolumeShare() == nil)
    }

    // MARK: - Query plans (the cost acceptance criterion)

    /// The test that actually protects the performance work.
    ///
    /// Each aggregate must drive `FROM temp.facet_mset` and seek into `document_cache` by
    /// rowid. If a plan ever says `SCAN document_cache`, the aggregate has been rewritten
    /// into the shape that costs 11 s instead of 0.001 s on the real store — and no timing
    /// test on a twelve-document fixture would notice.
    @Test("Every facet aggregate drives from the match set, never scanning document_cache")
    func facetPlansNeverScanDocumentCache() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }

        let params = SearchParameters(keywords: "containment")
        let expressions = try await service.matchExpressions(for: params)
        let plans = try await pipeline.facetQueryPlansForTesting(
            corpusMatch: expressions.corpus, userContentMatch: expressions.userContent,
            filters: await service.filtersForTesting(params))

        #expect(plans.count == FacetSection.allCases.count)
        for (section, plan) in plans {
            // SQLite writes the *alias*, so these assertions are against `ms` and `dc`, not
            // the table names. An earlier version of this test looked for
            // "SCAN document_cache" and could therefore never have fired — the plan says
            // "SCAN dc". Worth stating: that vacuity is what let the wrong join order
            // through in the first place.
            #expect(plan.hasPrefix("SCAN ms") || plan.contains("SCAN ms "),
                    "\(section.rawValue) must DRIVE from the match set, not seek into it. Plan: \(plan)")
            #expect(plan.contains("SEARCH dc USING INTEGER PRIMARY KEY"),
                    "\(section.rawValue) must reach document_cache by rowid seek. Plan: \(plan)")
            // A bare `SCAN dc` reads the 1.8 GB table. A covering-index scan is cheap, but
            // driving from `ms` means neither should appear at all.
            #expect(!plan.contains("SCAN dc\n") && !plan.contains("SCAN dc |") && !plan.hasSuffix("SCAN dc"),
                    "\(section.rawValue) scans document_cache. Plan: \(plan)")
        }
    }

    @Test("The match set is a rowid table, so joins back are integer-primary-key seeks")
    func matchSetIsARowidTable() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }

        let params = SearchParameters(keywords: "containment")
        let expressions = try await service.matchExpressions(for: params)
        let plans = try await pipeline.facetQueryPlansForTesting(
            corpusMatch: expressions.corpus, userContentMatch: expressions.userContent,
            filters: await service.filtersForTesting(params))
        let volumes = try #require(plans[.volumes])
        #expect(volumes.contains("SCAN ms"), "plan: \(volumes)")
        #expect(volumes.contains("SEARCH dc USING INTEGER PRIMARY KEY"),
                "the volume aggregate must seek document_cache by rowid. Plan: \(volumes)")
    }

    // MARK: - The temp table does not leak

    /// The match set is dropped on every exit path. A leaked one would make the *next*
    /// search's facets describe the previous search's results — a wrong answer that looks
    /// entirely plausible.
    @Test("Consecutive facet computations do not contaminate each other")
    func matchSetDoesNotLeak() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }

        let first = try await facets(pipeline, service, query: "containment")
        let second = try await facets(pipeline, service, query: "rollback")
        let third = try await facets(pipeline, service, query: "containment")

        #expect(first.matchCount == third.matchCount, "the same query must give the same answer")
        #expect(second.matchCount != first.matchCount, "and a different query a different one")
        let rollbackCount = try await service.searchCount(
            parameters: SearchParameters(keywords: "rollback"))
        #expect(second.matchCount == rollbackCount)
    }
}
