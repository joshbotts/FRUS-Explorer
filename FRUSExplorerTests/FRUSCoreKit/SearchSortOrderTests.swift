// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif

// MARK: - SearchSortOrderTests

/// The result list's orders (#305), which both view models and the web edition sort by.
///
/// Version history:
///   1.0 — FRUS Explorer Light: initial implementation, with the order moved into the kit
@Suite("Search sort order")
struct SearchSortOrderTests {

    private func result(_ id: String, _ date: String?, _ score: Double) -> SearchResult {
        SearchResult(documentId: id, volumeId: "v1", header: id, dateISO: date, snippet: "", bm25Score: score)
    }

    /// Two documents on one day, one earlier, and two undated, in the order a search returned them.
    private var rows: [SearchResult] {
        [result("d1", "1951-03-01", -2), result("d2", nil, -9), result("d3", "1949-01-01", -1),
         result("d4", "1951-03-01", -5), result("d5", nil, -3)]
    }

    @Test("Relevance keeps the order the search returned")
    func relevanceKeepsTheOrder() {
        #expect(SearchSortOrder.relevance.sorted(rows).map(\.documentId) == ["d1", "d2", "d3", "d4", "d5"])
    }

    @Test("Oldest first puts the undated last and breaks a tie on the date by BM25")
    func oldestFirst() {
        // d4 scores lower than d1, so it is the more relevant of the two on 1 March 1951.
        #expect(SearchSortOrder.dateAscending.sorted(rows).map(\.documentId) == ["d3", "d4", "d1", "d2", "d5"])
    }

    @Test("Newest first still puts the undated last and breaks a tie on the date by BM25")
    func newestFirst() {
        #expect(SearchSortOrder.dateDescending.sorted(rows).map(\.documentId) == ["d4", "d1", "d3", "d2", "d5"], """
            Undated documents go last in both directions, so the dated stream stays contiguous, and the \
            more relevant of two documents on one day comes first in both.
            """)
    }
}
