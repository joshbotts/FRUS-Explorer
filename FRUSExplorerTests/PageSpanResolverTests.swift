// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
@testable import FRUSExplorer

// MARK: - PageSpanResolverTests

/// Unit tests for the shared span-containing page resolver used by both the reader
/// (`PageRangeStore`) and the indexing-time cross-reference resolver
/// (`IndexingPipeline.resolvePageBasedCrossReferences`).
@Suite("PageSpanResolver — shared span-containing page resolution")
struct PageSpanResolverTests {

    /// Two documents, each spanning ten pages; a page inside a span resolves to its owner.
    @Test("Page inside a document's range resolves to that document")
    func pageInsideRange() {
        let rows: [(documentId: String, pageInt: Int)] =
            (1...10).map { ("d1", $0) } + (11...20).map { ("d2", $0) }
        #expect(PageSpanResolver.documentContaining(page: 7, in: rows) == "d1")
        #expect(PageSpanResolver.documentContaining(page: 15, in: rows) == "d2")
    }

    /// The boundary pages — a document's first page and the page just before the next
    /// document — resolve on the correct side of the boundary.
    @Test("Boundary pages resolve to the correct side of the span")
    func boundaryPages() {
        let rows: [(documentId: String, pageInt: Int)] =
            (1...10).map { ("d1", $0) } + (11...20).map { ("d2", $0) }
        #expect(PageSpanResolver.documentContaining(page: 10, in: rows) == "d1")
        #expect(PageSpanResolver.documentContaining(page: 11, in: rows) == "d2")
    }

    /// A page that owns no <pb> but lies between two documents' opening pages resolves to
    /// the earlier document — the case the old exact-match `page_number_int = N` missed.
    @Test("A page with no <pb> inside a span resolves to the containing document")
    func interiorPageWithoutOwnPageBreak() {
        // d1 opens at 10 (pb 10, 12 only), d2 opens at 13.
        let rows: [(documentId: String, pageInt: Int)] = [
            ("d1", 10), ("d1", 12), ("d2", 13), ("d2", 14),
        ]
        // Page 11 has no row of its own, yet belongs to d1's span [10, 12].
        #expect(PageSpanResolver.documentContaining(page: 11, in: rows) == "d1")
    }

    /// The last document's span closes at the section's maximum page, not `Int.max`.
    @Test("Last document closes at the section max page, not Int.max")
    func lastDocumentClosesAtMaxPage() {
        let rows: [(documentId: String, pageInt: Int)] = [
            ("d1", 1), ("d1", 9), ("d2", 10), ("d2", 15),
        ]
        // Within the last document's recorded span.
        #expect(PageSpanResolver.documentContaining(page: 15, in: rows) == "d2")
        // Beyond the section's highest recorded page: no document claims it.
        #expect(PageSpanResolver.documentContaining(page: 16, in: rows) == nil)
        #expect(PageSpanResolver.documentContaining(page: 500, in: rows) == nil)
    }

    /// A page below the first document's opening page resolves to nil.
    @Test("A page below the first document's opening page resolves to nil")
    func pageBelowFirstDocument() {
        let rows: [(documentId: String, pageInt: Int)] = [
            ("d1", 42), ("d1", 43), ("d2", 44),
        ]
        #expect(PageSpanResolver.documentContaining(page: 5, in: rows) == nil)
    }

    /// Empty input (e.g. a volume with only roman / non-arabic pages) resolves to nil.
    @Test("Empty input resolves to nil")
    func emptyInput() {
        #expect(PageSpanResolver.documentContaining(page: 1, in: []) == nil)
    }

    /// The resolver is order-independent: shuffled input yields the same boundaries as
    /// sorted input, since it sorts internally (first occurrence of each doc wins).
    @Test("Unsorted input produces the same result as sorted input")
    func orderIndependence() {
        let sorted: [(documentId: String, pageInt: Int)] = [
            ("d1", 1), ("d1", 2), ("d2", 3), ("d2", 4), ("d3", 5),
        ]
        let shuffled: [(documentId: String, pageInt: Int)] = [
            ("d3", 5), ("d2", 4), ("d1", 2), ("d2", 3), ("d1", 1),
        ]
        for page in 1...5 {
            #expect(
                PageSpanResolver.documentContaining(page: page, in: sorted)
                    == PageSpanResolver.documentContaining(page: page, in: shuffled)
            )
        }
    }
}
