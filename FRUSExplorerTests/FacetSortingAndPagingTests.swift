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

/// Facet sorting, paging, and filtering (#586).
///
/// ## The suite has a bug to guard, not only a feature to cover
/// The issue asked for sort and pagination controls. Underneath it was a defect: every section
/// was fetched at `LIMIT 50`, and the years section is ordered newest-first, so the cut kept
/// the 50 most recent years and dropped the rest. On the owner's index that started the
/// histogram at **1953** — 88,720 of 314,676 dated rows, 28% — and hid both World Wars behind
/// a caption reading "Showing the top 50 of 203".
///
/// ``yearsSectionIsNotCutAtFifty`` is the regression guard, and it drives the **real**
/// `IndexingPipeline.resultSetFacets` over a fixture with 60 distinct years rather than
/// asserting a constant. A test that only checked `FacetRequest.fetchCeiling > 50` would pass
/// against a pipeline that had gone back to hard-coding its own limit.
///
/// Version history:
///   1.0 — Session 2026-08-07: #586
@Suite("Facet sorting and paging")
struct FacetSortingAndPagingTests {

    // MARK: - Fixture

    /// One volume holding `years.count` documents, one per year, all matching `containment`.
    private func makeVolumeXML(years: [Int]) -> String {
        var xml = "<?xml version=\"1.0\"?>\n<TEI><text><body>\n"
        for (index, year) in years.enumerated() {
            xml += """
            <div type="document" xml:id="d\(index)">
              <head>\(index + 1). Item \(index)</head>
              <dateline>Washington, \(year)</dateline>
              <p>The doctrine of containment shaped policy.</p>
            </div>

            """
        }
        xml += "</body></text></TEI>"
        return xml
    }

    private func makeFixture(years: [Int]) async throws
        -> (dir: URL, service: SearchService, pipeline: IndexingPipeline) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSFacetPage-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("test.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        try makeVolumeXML(years: years).data(using: .utf8)!
            .write(to: volDir.appendingPathComponent("vol1.xml"))

        let fts5 = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: fts5, databaseURL: dbURL, volumesDirectory: volDir, concurrencyLimit: 1)
        try await pipeline.indexVolume("vol1")
        return (dir, SearchService(fts5Store: fts5, pipeline: pipeline), pipeline)
    }

    private func cleanUp(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    /// Rows for building paging cases without a database.
    private func buckets(_ pairs: [(String, Int)]) -> [FacetBucket] {
        pairs.map { FacetBucket(key: $0.0, label: $0.0, count: $0.1) }
    }

    // MARK: - The years cut (the shipped defect)

    @Test("The years section is not cut at 50 — a 60-year match returns all 60")
    func yearsSectionIsNotCutAtFifty() async throws {
        let years = Array(1900...1959)
        #expect(years.count == 60, "the fixture must exceed the old 50-row cut to prove anything")
        let (dir, service, pipeline) = try await makeFixture(years: years)
        defer { cleanUp(dir) }

        let params = SearchParameters(keywords: "containment")
        let expressions = try await service.matchExpressions(for: params)
        let computed = try await pipeline.resultSetFacets(
            corpusMatch: expressions.corpus, userContentMatch: expressions.userContent,
            filters: await service.filtersForTesting(params), request: .one(.years))

        #expect(computed.years.count == 60,
                "got \(computed.years.count) year buckets; the old LIMIT 50 would return 50")
        // The specific harm: newest-first ordering meant the *oldest* years were the ones
        // dropped, so their presence is what proves the cut is gone.
        let keys = Set(computed.years.map(\.key))
        #expect(keys.contains("1900"), "the earliest year is exactly what the old cut discarded")
        #expect(keys.contains("1909"))
        #expect(computed.bounds[.years]?.isTruncated == false)
    }

    @Test("Years and the other bounded sections open showing everything")
    func boundedSectionsOpenWhole() {
        // The fetch is only half the fix. If years still opened at `.top25`, a reader would see
        // 25 of 203 years and the 1953 problem would have moved from SQL into the view.
        #expect(FacetPageSize.standard(for: .years) == .all)
        #expect(FacetPageSize.standard(for: .documentType) == .all)
        #expect(FacetPageSize.standard(for: .provenance) == .all)
        #expect(FacetPageSize.standard(for: .volumes) == .top25)
        #expect(FacetPageSize.standard(for: .people) == .top25)

        #expect(FacetSection.years.hasBoundedDomain)
        #expect(FacetSection.documentType.hasBoundedDomain)
        #expect(FacetSection.provenance.hasBoundedDomain)
        #expect(!FacetSection.volumes.hasBoundedDomain)
        #expect(!FacetSection.people.hasBoundedDomain)
    }

    @Test("The default fetch clears the largest real section")
    func fetchCeilingClearsRealData() {
        // 16,385 distinct person rollups on a whole-corpus match; 18,078 in the rollup table.
        #expect(FacetRequest.fetchCeiling > 18_078)
        #expect(FacetRequest.one(.people).limitPerSection == FacetRequest.fetchCeiling)
        #expect(FacetRequest.all.limitPerSection == FacetRequest.fetchCeiling)
    }

    // MARK: - Sorting

    @Test("Count order does not trust the SQL order it was handed")
    func countOrderSortsExplicitly() {
        // Years arrive year-descending and every other section count-descending, so a `.count`
        // case that returned its input unchanged would be right four times and wrong once.
        let yearOrdered = buckets([("1950", 3), ("1949", 40), ("1948", 12)])
        let sorted = FacetPaging.sorted(yearOrdered, by: .count)
        #expect(sorted.map(\.count) == [40, 12, 3])
        #expect(sorted.map(\.key) == ["1949", "1948", "1950"])
    }

    @Test("Equal counts break by label, not by input order")
    func countTiesBreakByLabel() {
        let rows = buckets([("Zulu", 7), ("Alpha", 7), ("Mike", 7)])
        #expect(FacetPaging.sorted(rows, by: .count).map(\.label) == ["Alpha", "Mike", "Zulu"])
    }

    @Test("Alphabetical puts a diacritic initial with its letter, not after Z")
    func alphabeticalHandlesDiacritics() {
        // This is the case SQLite's BINARY collation gets wrong: `ORDER BY canonical_name`
        // exiles all 22 non-ASCII initials past `Z`. `Ágústsson` belongs between `Adams` and
        // `Baker`, which is where a reader looks for it.
        let rows = buckets([("Baker, J.", 1), ("Ágústsson, Einar", 1), ("Adams, C.", 1),
                            ("Zimmermann, A.", 1)])
        let ascending = FacetPaging.sorted(rows, by: .labelAscending).map(\.label)
        #expect(ascending == ["Adams, C.", "Ágústsson, Einar", "Baker, J.", "Zimmermann, A."])
        #expect(ascending.last != "Ágústsson, Einar", "BINARY collation would put it here")
        #expect(FacetPaging.sorted(rows, by: .labelDescending).map(\.label) == ascending.reversed())
    }

    @Test("Alphabetical orders volume ids naturally, so v5 precedes v10")
    func alphabeticalIsNumericAware() {
        let rows = buckets([("frus1952-54v10", 1), ("frus1952-54v05", 1), ("frus1952-54v2", 1)])
        #expect(FacetPaging.sorted(rows, by: .labelAscending).map(\.key)
                == ["frus1952-54v2", "frus1952-54v05", "frus1952-54v10"])
    }

    @Test("Rows sharing a label order deterministically by key")
    func duplicateLabelsAreDeterministic() {
        // Two rollups with no canonical name both fall back to the same label. `sorted(by:)`
        // is not documented as stable, so without the key tiebreak these could swap between
        // renders of the same data.
        let rows = [FacetBucket(key: "77", label: "", count: 4),
                    FacetBucket(key: "12", label: "", count: 4),
                    FacetBucket(key: "45", label: "", count: 4)]
        for sort in FacetSort.allCases {
            let once = FacetPaging.sorted(rows, by: sort).map(\.key)
            let twice = FacetPaging.sorted(rows.reversed(), by: sort).map(\.key)
            #expect(once == twice, "\(sort) is order-dependent on tied labels")
        }
    }

    @Test("Years keeps its shipped default; everything else keeps count")
    func defaultSortsPreserveShippedBehaviour() {
        #expect(FacetSort.standard(for: .years) == .labelDescending)
        for section in FacetSection.allCases where section != .years {
            #expect(FacetSort.standard(for: section) == .count, "\(section)")
        }
    }

    @Test("Only the three sections with a real ordering choice get a picker")
    func sortChoicesAreOfferedWhereTheyMeanSomething() {
        #expect(FacetSort.choices(for: .years).count == 3)
        #expect(FacetSort.choices(for: .volumes).count == 3)
        #expect(FacetSort.choices(for: .people).count == 3)
        #expect(FacetSort.choices(for: .documentType).isEmpty)
        #expect(FacetSort.choices(for: .provenance).isEmpty)
    }

    @Test("A sort control reads as oldest/newest on years and A–Z elsewhere")
    func sortTitlesAreSectionSpecific() {
        #expect(FacetSort.labelAscending.title(for: .years) == "Oldest first")
        #expect(FacetSort.labelDescending.title(for: .years) == "Newest first")
        #expect(FacetSort.labelAscending.title(for: .people) == "A–Z")
        #expect(FacetSort.labelDescending.title(for: .people) == "Z–A")
    }

    // MARK: - Paging

    @Test("A short last page reports its true first row number")
    func lastPageOffsetIsCorrect() {
        // 53 rows at 25 a page: page 3 holds 3 rows starting at 51. Deriving the offset from
        // the page's own row count would say 3 × 3 + 1 = 10, which is wrong on exactly the
        // page a reader checks when they want to know how far the list goes.
        let rows = buckets((1...53).map { ("k\($0)", 100 - $0) })
        let page = FacetPaging.page(rows, with: FacetDisplayState(
            sort: .count, pageSize: .top25, pageIndex: 2))
        #expect(page.rows.count == 3)
        #expect(page.firstRowNumber == 51)
        #expect(page.pageCount == 3)
        #expect(page.matchingCount == 53)
    }

    @Test("An out-of-range page clamps to the last page rather than showing nothing")
    func pageIndexIsClamped() {
        let rows = buckets((1...10).map { ("k\($0)", $0) })
        let page = FacetPaging.page(rows, with: FacetDisplayState(
            sort: .count, pageSize: .top5, pageIndex: 99))
        #expect(page.pageIndex == 1)
        #expect(page.rows.count == 5)
        #expect(!page.rows.isEmpty, "an empty page would read as 'no results'")

        let negative = FacetPaging.page(rows, with: FacetDisplayState(
            sort: .count, pageSize: .top5, pageIndex: -4))
        #expect(negative.pageIndex == 0)
    }

    @Test("Show all returns every row as a single page")
    func showAllIsOnePage() {
        let rows = buckets((1...203).map { ("k\($0)", $0) })
        let page = FacetPaging.page(rows, with: FacetDisplayState(sort: .count, pageSize: .all))
        #expect(page.rows.count == 203)
        #expect(page.pageCount == 1)
        #expect(!page.hasMultiplePages)
        #expect(page.firstRowNumber == 1)
    }

    @Test("An exact multiple of the page size does not mint an empty trailing page")
    func exactMultipleHasNoEmptyPage() {
        let rows = buckets((1...25).map { ("k\($0)", $0) })
        let page = FacetPaging.page(rows, with: FacetDisplayState(sort: .count, pageSize: .top25))
        #expect(page.pageCount == 1)
        #expect(!page.hasMultiplePages)
    }

    @Test("An empty section is one page, not zero")
    func emptyIsOnePage() {
        let page = FacetPaging.page([], with: FacetDisplayState(sort: .count, pageSize: .top10))
        #expect(page.pageCount == 1)
        #expect(page.rows.isEmpty)
        #expect(page.firstRowNumber == 0)
        #expect(!page.isFiltered)
    }

    // MARK: - Filtering

    @Test("The filter ignores case and diacritics")
    func filterIsCaseAndDiacriticInsensitive() {
        // Requiring the accent would make the filter useless on the names hardest to type,
        // which are the ones a reader most needs it for.
        let rows = buckets([("Ágústsson, Einar", 3), ("Dulles, John Foster", 9),
                            ("Acheson, Dean", 5)])
        #expect(FacetPaging.filter(rows, matching: "agustsson").map(\.key) == ["Ágústsson, Einar"])
        #expect(FacetPaging.filter(rows, matching: "DULLES").map(\.key) == ["Dulles, John Foster"])
        // "son" starts no label but ends two of them, so matching both is only possible if the
        // filter is a substring test rather than a prefix one.
        #expect(Set(FacetPaging.filter(rows, matching: "son").map(\.key))
                == ["Ágústsson, Einar", "Acheson, Dean"])
    }

    @Test("A blank filter is a no-op, not a filter that matches nothing")
    func blankFilterIsNoOp() {
        let rows = buckets([("a", 1), ("b", 2)])
        #expect(FacetPaging.filter(rows, matching: "").count == 2)
        #expect(FacetPaging.filter(rows, matching: "   ").count == 2)
        #expect(FacetPaging.filter(rows, matching: "\n\t").count == 2)
    }

    @Test("A filtered page reports both denominators")
    func filteredPageKeepsBothTotals() {
        let rows = buckets((1...100).map { ("row\($0)", $0) })
        let page = FacetPaging.page(rows, with: FacetDisplayState(
            sort: .count, pageSize: .top10, filterText: "row1"))
        // row1, row10–row19, row100 — 12 rows.
        #expect(page.matchingCount == 12)
        #expect(page.totalCount == 100, "the unfiltered size is what 'clear the filter' returns to")
        #expect(page.isFiltered)
        #expect(page.pageCount == 2)
    }

    @Test("A filter matching nothing yields an empty page that still knows the total")
    func filterMatchingNothing() {
        let rows = buckets([("Acheson", 1), ("Dulles", 2)])
        let page = FacetPaging.page(rows, with: FacetDisplayState(
            sort: .count, pageSize: .top25, filterText: "zzznope"))
        #expect(page.rows.isEmpty)
        #expect(page.matchingCount == 0)
        #expect(page.totalCount == 2)
        #expect(page.isFiltered)
    }

    // MARK: - Controller state

    @MainActor
    @Test("Re-sorting and resizing return to the first page")
    func sortAndResizeResetThePage() {
        let controller = FacetPanelController()
        controller.setPage(7, for: .people)
        #expect(controller.displayState(for: .people).pageIndex == 7)

        controller.setSort(.labelAscending, for: .people)
        #expect(controller.displayState(for: .people).pageIndex == 0,
                "page 7 alphabetical holds different people from page 7 by count")

        controller.setPage(4, for: .people)
        controller.setPageSize(.top5, for: .people)
        #expect(controller.displayState(for: .people).pageIndex == 0)

        controller.setPage(3, for: .people)
        controller.setFilter("dulles", for: .people)
        #expect(controller.displayState(for: .people).pageIndex == 0)
    }

    @MainActor
    @Test("A new match keeps the chosen sort but drops the page and the filter")
    func invalidateKeepsPreferencesAndDropsPosition() {
        let controller = FacetPanelController()
        controller.invalidate(signature: "first")
        controller.setSort(.labelAscending, for: .people)
        controller.setPageSize(.top10, for: .people)
        controller.setPage(6, for: .people)
        controller.setFilter("dulles", for: .people)

        controller.invalidate(signature: "second")

        let state = controller.displayState(for: .people)
        #expect(state.sort == .labelAscending, "the sort is a stated preference")
        #expect(state.pageSize == .top10)
        #expect(state.pageIndex == 0, "page 6 of the previous result set does not exist here")
        #expect(state.filterText.isEmpty,
                "a leftover filter over new rows reads as a broken facet, not a filtered one")
    }

    @MainActor
    @Test("An untouched section reports its section-specific defaults")
    func untouchedSectionUsesDefaults() {
        let controller = FacetPanelController()
        #expect(controller.displayState(for: .years)
                == FacetDisplayState(sort: .labelDescending, pageSize: .all))
        #expect(controller.displayState(for: .people)
                == FacetDisplayState(sort: .count, pageSize: .top25))
    }

    @MainActor
    @Test("Re-invalidating with the same signature does not reset the page")
    func repeatedSignatureIsInert() {
        // `invalidate` is called on every render pass of the hosting view, so a same-signature
        // call resetting the page would make paging impossible rather than merely wrong.
        let controller = FacetPanelController()
        controller.invalidate(signature: "same")
        controller.setPage(3, for: .volumes)
        controller.invalidate(signature: "same")
        #expect(controller.displayState(for: .volumes).pageIndex == 3)
    }
}
