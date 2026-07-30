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

/// Per-tag counts over a result set, and the R-1 follow-up fixes.
///
/// ## Why the counts live here and not in the facet panel
/// Measured on the real store, 67 of 316,839 documents carry a tag — 0.021%. A permanent
/// sixth facet section would render "Nothing to break down here" for almost every query. The
/// counts go on the filter sheet's existing My Tags toggles instead, which appear only when
/// opened and already perform the narrowing.
///
/// Version history:
///   1.0 — R-1 follow-up: initial implementation
@Suite("User-tag counts")
struct UserTagCountTests {

    // MARK: - Fixture

    /// Six documents. Tag A is on three of them, tag B on one, tag C on none — and one
    /// document repeats tag A's id inside its own string, which is the case that makes
    /// `COUNT(*)` overcount.
    private let tagA = "AAAAAAAA-0000-0000-0000-000000000001"
    private let tagB = "BBBBBBBB-0000-0000-0000-000000000002"
    private let tagC = "CCCCCCCC-0000-0000-0000-000000000003"

    private func makeFixture() async throws
        -> (dir: URL, service: SearchService, pipeline: IndexingPipeline) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSTagCount-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("test.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)

        var xml = "<?xml version=\"1.0\"?>\n<TEI><text><body>\n"
        for index in 0..<6 {
            xml += """
            <div type="document" xml:id="d\(index)">
              <head>\(index + 1). Item</head>
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

        // d0, d1, d2 carry tag A. d2 ALSO repeats A — the real store has 14 such rows.
        // d1 carries B as well. Nothing carries C.
        try await pipeline.updateUserTagIds(volumeId: "vol1", documentId: "d0", userTagIds: tagA)
        try await pipeline.updateUserTagIds(volumeId: "vol1", documentId: "d1",
                                            userTagIds: "\(tagA) \(tagB)")
        try await pipeline.updateUserTagIds(volumeId: "vol1", documentId: "d2",
                                            userTagIds: "\(tagA) \(tagA) \(tagA)")
        return (dir, SearchService(fts5Store: fts5, pipeline: pipeline), pipeline)
    }

    private func cleanUp(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func counts(
        _ pipeline: IndexingPipeline, _ service: SearchService,
        query: String, tags: [String],
        configure: (inout SearchParameters) -> Void = { _ in }
    ) async throws -> [String: Int] {
        var params = SearchParameters(keywords: query)
        configure(&params)
        let expressions = try await service.matchExpressions(for: params)
        return try await pipeline.userTagCounts(
            corpusMatch: expressions.corpus, userContentMatch: expressions.userContent,
            filters: await service.filtersForTesting(params), tagIds: tags)
    }

    // MARK: - Counting documents, not tokens

    /// The defect this guards: 14 of the real store's 67 tagged rows repeat an id, so
    /// `COUNT(*)` reported 25 for a tag the shipped filter matches on 22 documents.
    @Test("A repeated id inside one row counts once, not three times")
    func repeatedIdCountsOnce() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }

        let result = try await counts(pipeline, service, query: "containment",
                                     tags: [tagA, tagB, tagC])
        #expect(result[tagA] == 3,
                "d2 repeats tag A three times; COUNT(*) would say 5. Got \(result[tagA] as Int?)")
        #expect(result[tagB] == 1)
    }

    /// The count must equal what toggling that tag actually returns, or the number is
    /// decoration.
    @Test("Each count equals what filtering on that tag returns")
    func countsAgreeWithTheFilter() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }

        let result = try await counts(pipeline, service, query: "containment",
                                     tags: [tagA, tagB])
        for (tagId, expected) in result {
            var filtered = SearchParameters(keywords: "containment")
            filtered.userTagIds = [tagId]
            let actual = try await service.searchCount(parameters: filtered)
            #expect(expected == actual, "\(tagId): counted \(expected), filter returns \(actual)")
        }
    }

    @Test("A tag matching nothing is omitted rather than reported as zero")
    func unmatchedTagIsOmitted() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }

        let result = try await counts(pipeline, service, query: "containment",
                                     tags: [tagA, tagC])
        #expect(result[tagC] == nil, "the surface renders a missing key as 0")
        #expect(result[tagA] != nil)
    }

    // MARK: - Scope

    @Test("Counts describe the filtered match, not the corpus")
    func countsRespectFilters() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }

        let all = try await counts(pipeline, service, query: "containment", tags: [tagA])
        #expect(all[tagA] == 3)

        // Narrow to a volume that holds none of the tagged documents' siblings — here, narrow
        // by document type to editorial notes, of which the fixture has none.
        let narrowed = try await counts(pipeline, service, query: "containment", tags: [tagA]) {
            $0.documentTypeFilter = .editorialNotesOnly
        }
        #expect(narrowed[tagA] == nil, "no editorial note carries the tag, so it must not appear")
    }

    @Test("A query matching nothing yields no counts")
    func emptyMatchYieldsNoCounts() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }

        #expect(try await counts(pipeline, service, query: "zzznothing",
                                 tags: [tagA, tagB]).isEmpty)
    }

    @Test("An empty tag list is a no-op, not a malformed query")
    func emptyTagListIsSafe() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }

        // A VALUES clause with no rows is a syntax error, so this must short-circuit.
        #expect(try await counts(pipeline, service, query: "containment", tags: []).isEmpty)
    }

    /// Keys come from the caller's live tag list, so an id left behind in the column cannot
    /// produce a row nobody can name.
    @Test("A stale id in the column produces no bucket")
    func staleColumnIdIsNotReported() async throws {
        let (dir, service, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }

        let orphan = "DEADBEEF-0000-0000-0000-00000000DEAD"
        try await pipeline.updateUserTagIds(volumeId: "vol1", documentId: "d3",
                                            userTagIds: orphan)
        // Asking only about the live tags must not surface the orphan.
        let result = try await counts(pipeline, service, query: "containment", tags: [tagA, tagB])
        #expect(result[orphan] == nil)
        #expect(result[tagA] == 3, "and the real counts are unaffected")
    }

    // MARK: - The query plan

    /// The same acceptance rule the facet sections are held to: drive from the match set,
    /// seek `document_cache` by rowid, never scan it. A fixture this small cannot tell the
    /// shapes apart by timing.
    @Test("The aggregate drives from the match set and seeks document_cache by rowid")
    func planDrivesFromTheMatchSet() async throws {
        let (dir, _, pipeline) = try await makeFixture()
        defer { cleanUp(dir) }

        let plan = try await pipeline.userTagCountPlanForTesting(tagIds: [tagA, tagB, tagC])
        #expect(plan.contains("SCAN ms"), "must drive from the match set. Plan: \(plan)")
        #expect(plan.contains("SEARCH dc USING INTEGER PRIMARY KEY"),
                "must reach document_cache by rowid. Plan: \(plan)")
        #expect(!plan.contains("SCAN dc |") && !plan.hasSuffix("SCAN dc"),
                "must not scan document_cache. Plan: \(plan)")
    }
}

/// The R-1 follow-up fixes that are not about counting.
///
/// Version history:
///   1.0 — R-1 follow-up: initial implementation
@Suite("R-1 follow-up fixes")
@MainActor
struct R1FollowUpFixTests {

    private func makeFixture() async throws
        -> (dir: URL, pipeline: IndexingPipeline, vm: SearchViewModel) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSFollowUp-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("test.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        try """
        <?xml version="1.0"?>
        <TEI><text><body>
        <div type="document" xml:id="d1">
          <head>1. Item</head><p>The doctrine of containment.</p>
        </div>
        </body></text></TEI>
        """.data(using: .utf8)!.write(to: volDir.appendingPathComponent("vol1.xml"))
        let fts5 = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: fts5, databaseURL: dbURL, volumesDirectory: volDir, concurrencyLimit: 1)
        try await pipeline.indexVolume("vol1")
        let service = SearchService(fts5Store: fts5, pipeline: pipeline)
        return (dir, pipeline, SearchViewModel(searchService: service))
    }

    private func cleanUp(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    /// Creating an untagged note used to pass `userTagIds: nil`, which set the column to
    /// NULL — and the column is per *document*, so it erased tags another note on the same
    /// document had contributed. Invisible, because the next launch's push restored them.
    @Test("Updating note text alone does not disturb the document's tags")
    func noteTextUpdateLeavesTagsAlone() async throws {
        let (dir, pipeline, _) = try await makeFixture()
        defer { cleanUp(dir) }

        let tag = "AAAAAAAA-0000-0000-0000-000000000001"
        try await pipeline.updateUserTagIds(volumeId: "vol1", documentId: "d1", userTagIds: tag)

        // The text-only overload — what the new-note path now calls.
        try await pipeline.updateNoteText(volumeId: "vol1", documentId: "d1",
                                          bodyText: "a note with no tags of its own")
        let after = try await pipeline.userTagIdsForTesting(volumeId: "vol1", documentId: "d1")
        #expect(after == tag, "the tag must survive a note-text update. Got \(after ?? "nil")")

        // And the overload that DOES take tags still owns the column, deliberately.
        try await pipeline.updateNoteText(volumeId: "vol1", documentId: "d1",
                                          bodyText: "still a note", userTagIds: nil)
        #expect(try await pipeline.userTagIdsForTesting(volumeId: "vol1", documentId: "d1") == nil,
                "the tag-bearing overload is still authoritative when a caller has the real value")
    }

    /// iOS held tag ids in a `Set<UUID>` and its narrowing summary had no tag case, so a tag
    /// filter was invisible in the chip row and could not be cleared from it.
    @Test("A tag filter appears in the narrowing summary and can be cleared")
    func tagFilterIsVisibleAndClearable() async throws {
        let (dir, _, vm) = try await makeFixture()
        defer { cleanUp(dir) }

        let id = UUID()
        vm.selectedUserTagIds = [id]
        let narrowing = try #require(vm.activeNarrowings.first { $0.id == "tag" })
        #expect(!narrowing.label.isEmpty)

        vm.clearNarrowing("tag")
        #expect(vm.selectedUserTagIds.isEmpty)
        #expect(!vm.activeNarrowings.contains { $0.id == "tag" })
    }

    @Test("A single tag is labelled by name when the name is known")
    func singleTagUsesItsName() async throws {
        let (dir, _, vm) = try await makeFixture()
        defer { cleanUp(dir) }

        let tag = UserTag(name: "stockpiling")
        vm.availableUserTags = [tag]
        vm.selectedUserTagIds = [tag.id]
        let narrowing = try #require(vm.activeNarrowings.first { $0.id == "tag" })
        #expect(narrowing.label == "stockpiling",
                "a raw UUID in a chip is what this fix exists to remove")
    }

    @Test("Several tags are summarised by count rather than by one arbitrary name")
    func severalTagsAreSummarised() async throws {
        let (dir, _, vm) = try await makeFixture()
        defer { cleanUp(dir) }

        // `Set<UUID>` has no stable first element, so naming one of several would be
        // nondeterministic across launches.
        vm.selectedUserTagIds = [UUID(), UUID(), UUID()]
        let narrowing = try #require(vm.activeNarrowings.first { $0.id == "tag" })
        #expect(narrowing.label.contains("3"))
    }

    @Test("Counts are cleared rather than left stale when a query has no searchable content")
    func failedCountClearsState() async throws {
        let (dir, pipeline, vm) = try await makeFixture()
        defer { cleanUp(dir) }

        let tag = UserTag(name: "stockpiling")
        vm.availableUserTags = [tag]
        // An all-scopes-off query throws `emptyQuery` inside the loader.
        var params = SearchParameters(keywords: "containment")
        params.includeDocumentText = false
        params.includeSummaries = false
        params.includeNotes = false

        await vm.loadUserTagCounts(matching: params, tags: [tag],
                                   service: vm.searchServiceForTesting, pipeline: pipeline)
        #expect(!vm.hasUserTagCounts, "stale numbers beside a failed count would be a lie")
        #expect(vm.userTagCounts.isEmpty)
        #expect(!vm.isCountingUserTags, "a stuck flag would spin forever")
    }
}
