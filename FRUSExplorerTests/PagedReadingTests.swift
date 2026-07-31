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

import Foundation
import Testing
@testable import FRUSExplorer

// MARK: - PagedReadingTests

/// Which readings paginate, and what makes a concordance rebuild.
///
/// Both fixes here address one confusion: **the surfaces disagree about what a page is.** The list
/// and the concordance show one page; the timeline and the collocates panel cover the whole
/// retained set. Pagination visibility and concordance rebuilds both have to follow that split,
/// and neither did.
///
/// Version history:
///   1.0 — Q wave: initial implementation
@Suite("Paged readings and concordance freshness")
struct PagedReadingTests {

    // MARK: - Which readings page

    @Test("The list and the concordance page; the timeline and collocates do not")
    func pagedReadings() {
        #expect(ResultReading.list.isPaged)
        #expect(ResultReading.concordance.isPaged)
        #expect(!ResultReading.timeline.isPaged)
        #expect(!ResultReading.collocates.isPaged)
    }

    /// The property has to split the cases, not answer the same way for all of them — a constant
    /// `true` reproduces the iOS bug and a constant `false` reproduces the macOS one.
    @Test("isPaged actually discriminates")
    func pagedIsNotConstant() {
        let paged = ResultReading.allCases.filter(\.isPaged)
        #expect(paged.count == 2, "expected exactly two paged readings, got \(paged.map(\.rawValue))")
    }

    // MARK: - What makes the concordance rebuild

    private func result(_ volume: String, _ document: String) -> SearchResult {
        SearchResult(documentId: document, volumeId: volume, header: "h", snippet: "", bm25Score: 0)
    }

    @Test("Reordering the same page rebuilds the concordance")
    func reorderRebuilds() {
        // Changing the sort order re-orders `results` in place. The page index does not move and
        // no search runs, so neither `page` nor `version` changed under the old key.
        let ascending = [result("v1", "d1"), result("v1", "d2")]
        let descending = [result("v1", "d2"), result("v1", "d1")]
        let before = ConcordanceRebuildKey(mode: true, rows: ascending, version: 1)
        let after = ConcordanceRebuildKey(mode: true, rows: descending, version: 1)
        #expect(before != after, "a reordered page must rebuild — the lines are shown in row order")
    }

    @Test("Marking a document reviewed rebuilds the concordance")
    func checklistShiftRebuilds() {
        // `displayedResults` drops the reviewed document and everything after it shifts up, so the
        // page now holds a document it did not before — again with no page or version change.
        let before = ConcordanceRebuildKey(
            mode: true, rows: [result("v1", "d1"), result("v1", "d2")], version: 1)
        let after = ConcordanceRebuildKey(
            mode: true, rows: [result("v1", "d2"), result("v1", "d3")], version: 1)
        #expect(before != after)
    }

    @Test("An unchanged page does not rebuild")
    func stablePageDoesNotRebuild() {
        // The other half of the contract: this key drives `.task(id:)`, so a key that changed on
        // every body pass would re-run a DB fetch and a scan continuously.
        let rows = [result("v1", "d1"), result("v1", "d2")]
        #expect(ConcordanceRebuildKey(mode: true, rows: rows, version: 3)
                == ConcordanceRebuildKey(mode: true, rows: rows, version: 3))
    }

    @Test("A new search over the same documents still rebuilds")
    func versionStillCounts() {
        // Why `version` survives alongside the keys: a different query can match the same
        // documents while centring on a different term, so the lines differ though the keys match.
        let rows = [result("v1", "d1")]
        #expect(ConcordanceRebuildKey(mode: true, rows: rows, version: 1)
                != ConcordanceRebuildKey(mode: true, rows: rows, version: 2))
    }

    @Test("Rows are not read while the concordance is closed")
    func closedModeIgnoresRows() {
        // `.task(id:)` is evaluated on every body pass. Building composite keys for a page that no
        // concordance is showing would put that work on every render of the search screen.
        let a = ConcordanceRebuildKey(mode: false, rows: [result("v1", "d1")], version: 1)
        let b = ConcordanceRebuildKey(mode: false, rows: [result("v9", "d9")], version: 1)
        #expect(a == b)
        #expect(a.documentKeys.isEmpty)
    }

    @Test("Opening the concordance rebuilds")
    func openingRebuilds() {
        let rows = [result("v1", "d1")]
        #expect(ConcordanceRebuildKey(mode: false, rows: rows, version: 1)
                != ConcordanceRebuildKey(mode: true, rows: rows, version: 1))
    }
}
