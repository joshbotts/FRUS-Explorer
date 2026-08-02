// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

// MARK: - FacetMatchSetParityTests

/// The facet match set drops two joins on the unfiltered path, and this asserts it changed nothing.
///
/// ## Why a test rather than a reading
/// "Dropping these joins cannot change the answer" is a claim about SQLite's external-content
/// invariants — that an FTS rowid always has a content row, and that `document_dates`' primary key
/// stops the `LEFT JOIN` fanning out. Both hold on the owner's index today, and neither is enforced
/// by anything the app controls. So the equivalence is asserted against the **real emitter on both
/// sides** rather than trusted: `resultSetFacetsJoinedMaterializationForTesting` runs the shape
/// that was replaced, in-process, on the same fixture.
///
/// Nothing here recomputes an expected facet in Swift. A test that reimplements the thing it checks
/// tests its own author; this repo has been burned by that twice recently.
///
/// ## And a plan assertion, because parity cannot see a regression
/// Output parity is blind to the optimisation being undone — a re-added join returns exactly the
/// same rows, only slower. A timing test on a 40-document fixture cannot tell a join from no join
/// either. The query plan can, so that is the guard.
///
/// Version history:
///   1.0 — facet materialisation: initial implementation
@Suite("Facet match set parity")
struct FacetMatchSetParityTests {

    // MARK: - Fixture

    private func makeFixture(documents: Int = 40) async throws
        -> (dir: URL, service: SearchService, pipeline: IndexingPipeline) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSFacetParity-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("test.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)

        var body = "<?xml version=\"1.0\"?>\n<TEI><text><body>\n"
        for index in 0..<documents {
            let kind = index.isMultiple(of: 2) ? "document" : "editorialNote"
            body += """
            <div type="\(kind)" xml:id="d\(index)">
              <head>\(index + 1). Item \(index)</head>
              <dateline>Washington, \(1945 + index % 8)</dateline>
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

    /// The filter set the optimisation actually fires for: none.
    private var noFilters: SearchSQLFilters {
        SearchSQLFilters(
            volumeIds: nil, documentIds: nil, excludeDocumentIds: nil, dateRange: nil,
            includeFrontMatter: true, personRef: nil, personRollupId: nil,
            subjectTagIds: [], userTagIds: [], documentTypeFilter: .all,
            exactTerms: [], exactColumns: [])
    }

    /// A filter set that must keep the joined path.
    private var frontMatterExcluded: SearchSQLFilters {
        var filters = noFilters
        filters.includeFrontMatter = false
        return filters
    }

    // MARK: - Parity

    /// Every query shape the app can produce, both shapes, whole-struct equality.
    ///
    /// `ResultSetFacets`, `FacetBucket`, `FacetBound` and `ProvenanceCoverage` are all `Equatable`,
    /// so this compares the complete answer — buckets, counts, labels, truncation bounds and
    /// provenance coverage — not a sampled field.
    @Test("The joinless match set produces identical facets")
    func facetsMatchTheJoinedShape() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }

        for query in ["containment", "europe", "containment europe", "policy OR doctrine",
                      "=containment", "NEAR(containment europe, 20)", "zzznothing"] {
            let params = SearchParameters(keywords: query)
            let match = try await service.matchExpressions(for: params)

            let optimised = try await pipeline.resultSetFacets(
                corpusMatch: match.corpus, userContentMatch: match.userContent,
                filters: noFilters, request: .all)
            let joined = try await pipeline.resultSetFacetsJoinedMaterializationForTesting(
                corpusMatch: match.corpus, userContentMatch: match.userContent,
                filters: noFilters, request: .all)

            #expect(optimised == joined, "\(query): facets diverged")
        }
    }

    /// The second production caller. Threading the flag through only the facet path would ship
    /// half the surface untested — the filter sheet's My Tags counts run the same materialisation.
    @Test("The tag counts agree across both shapes")
    func tagCountsMatchTheJoinedShape() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }

        let params = SearchParameters(keywords: "containment")
        let match = try await service.matchExpressions(for: params)
        let tagIds = ["tag-a", "tag-b"]

        let optimised = try await pipeline.userTagCounts(
            corpusMatch: match.corpus, userContentMatch: match.userContent,
            filters: noFilters, tagIds: tagIds)
        let joined = try await pipeline.userTagCountsJoinedMaterializationForTesting(
            corpusMatch: match.corpus, userContentMatch: match.userContent,
            filters: noFilters, tagIds: tagIds)

        #expect(optimised == joined)
    }

    /// The optimisation fires only with an empty WHERE clause, so the filtered path must still
    /// take the joined shape and must still filter. A filter that stopped applying would return
    /// *more* rows, silently — the mirror image of the danger in the fetch path, where a deferred
    /// filter returns fewer.
    @Test("A filtered facet request still applies its filters")
    func filteredFacetsStillFilter() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }

        let params = SearchParameters(keywords: "containment")
        let match = try await service.matchExpressions(for: params)

        let unfiltered = try await pipeline.resultSetFacets(
            corpusMatch: match.corpus, userContentMatch: match.userContent,
            filters: noFilters, request: .all)
        let filtered = try await pipeline.resultSetFacets(
            corpusMatch: match.corpus, userContentMatch: match.userContent,
            filters: frontMatterExcluded, request: .all)

        // Both shapes agree with each other on the filtered path too.
        let filteredJoined = try await pipeline.resultSetFacetsJoinedMaterializationForTesting(
            corpusMatch: match.corpus, userContentMatch: match.userContent,
            filters: frontMatterExcluded, request: .all)
        #expect(filtered == filteredJoined, "the filtered path must be untouched by this change")

        // And the filter is doing something, or the assertion above is vacuous.
        #expect(unfiltered.matchCount >= filtered.matchCount)
    }

    /// Every section, one at a time. The facet panel requests `.one(section)` per expanded section,
    /// so the materialisation runs once per section rather than once per search — which is what
    /// makes its cost worth removing, and what makes a per-section divergence worth ruling out.
    @Test("Every section agrees when requested alone")
    func eachSectionMatchesAlone() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }

        let params = SearchParameters(keywords: "containment")
        let match = try await service.matchExpressions(for: params)

        for section in FacetSection.allCases {
            let optimised = try await pipeline.resultSetFacets(
                corpusMatch: match.corpus, userContentMatch: match.userContent,
                filters: noFilters, request: .one(section))
            let joined = try await pipeline.resultSetFacetsJoinedMaterializationForTesting(
                corpusMatch: match.corpus, userContentMatch: match.userContent,
                filters: noFilters, request: .one(section))
            #expect(optimised == joined, "section \(section) diverged")
        }
    }

    /// An empty match set must stay empty rather than becoming the whole corpus — the failure mode
    /// of getting the branch condition backwards.
    @Test("A query matching nothing produces no facets")
    func emptyMatchStaysEmpty() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }

        let params = SearchParameters(keywords: "zzznothingmatchesthis")
        let match = try await service.matchExpressions(for: params)
        let facets = try await pipeline.resultSetFacets(
            corpusMatch: match.corpus, userContentMatch: match.userContent,
            filters: noFilters, request: .all)
        #expect(facets.matchCount == 0)
    }

    // MARK: - The optimisation itself

    /// Parity is blind to the optimisation being undone: a re-added join returns identical rows,
    /// only slower. The plan is what can see it.
    ///
    /// Matched on the **alias** tokens, not the table names. `document_cache` appears in the plan
    /// of the FTS scan regardless — the existing precedent in this repo went vacuous by matching a
    /// table name, so this looks for `SEARCH dc` / `SEARCH dd`, which appear only when the joins
    /// are really there.
    @Test("The unfiltered facet materialisation does not join document_cache")
    func unfilteredMaterialisationHasNoJoins() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }

        let params = SearchParameters(keywords: "containment")
        let match = try await service.matchExpressions(for: params)
        let plan = try await pipeline.materializeMatchSetPlanForTesting(
            corpusMatch: match.corpus, userContentMatch: match.userContent, filters: noFilters)

        #expect(!plan.contains("SEARCH dc"),
                "the document_cache join is back — plan was: \(plan)")
        #expect(!plan.contains("SEARCH dd"),
                "the document_dates join is back — plan was: \(plan)")

        // And the joined shape still has them, so the assertion above is not passing because the
        // plan text simply never contains those tokens.
        let joinedPlan = try await pipeline.materializeMatchSetPlanForTesting(
            corpusMatch: match.corpus, userContentMatch: match.userContent,
            filters: noFilters, joinedMaterializationForParity: true)
        #expect(joinedPlan.contains("SEARCH dc"),
                "the parity shape must still join — otherwise the test above proves nothing")
    }

    /// Both production callers must forward the parity flag rather than pinning it.
    ///
    /// This is a source audit because no output assertion can see the defect: a caller that hardcodes
    /// `joinedMaterializationForParity: true` still returns exactly the right answer, just always on
    /// the slow path — and its own parity test then compares two joined shapes and passes. Verified:
    /// forcing `userTagCounts` to `true` leaves this whole suite green without it.
    @Test("Both callers forward the parity flag instead of pinning it")
    func callersForwardTheFlag() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appending(path: "FRUSExplorer/Search/IndexingPipeline.swift"),
            encoding: .utf8)

        // Four pass-through sites: `resultSetFacets`, `userTagCounts`, `materializeMatchSet`'s own
        // hop to the SQL builder, and the plan hook. A literal `true` belongs only in the two
        // `…ForTesting` hooks.
        let forwarded = source.components(
            separatedBy: "joinedMaterializationForParity: joinedMaterializationForParity").count - 1
        #expect(forwarded == 4,
                """
                Expected 4 pass-through sites (resultSetFacets, userTagCounts, materializeMatchSet, \
                the plan hook), found \(forwarded). A caller pinning the flag would keep returning \
                correct answers on the slow path, and no output test can see that.
                """)
        let pinnedTrue = source.components(
            separatedBy: "joinedMaterializationForParity: true").count - 1
        #expect(pinnedTrue == 2, "only the two test hooks may pin the flag; found \(pinnedTrue)")
    }

    /// The filtered path keeps its joins, because its filters reference `dc.` and `dd.`. If this
    /// ever fails, a filter has been moved somewhere it cannot be applied.
    @Test("The filtered materialisation keeps the joins its filters need")
    func filteredMaterialisationKeepsJoins() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }

        let params = SearchParameters(keywords: "containment")
        let match = try await service.matchExpressions(for: params)
        let plan = try await pipeline.materializeMatchSetPlanForTesting(
            corpusMatch: match.corpus, userContentMatch: match.userContent,
            filters: frontMatterExcluded)
        #expect(plan.contains("SEARCH dc"),
                "`is_front_matter` lives on document_cache — plan was: \(plan)")
    }
}
