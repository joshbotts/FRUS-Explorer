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

/// Unit tests for the shared page resolver used by the reader's page links and Citation Lookup
/// (`PageRangeStore`) and the indexing-time cross-reference resolver
/// (`IndexingPipeline.resolvePageBasedCrossReferences`). Since #1503 it reads the page each
/// document begins on; the end-to-end cases, over TEI indexed by the real pipeline, are in
/// `CitationLookupIndexedTests`.
@Suite("PageSpanResolver — which documents a page is, from the page each begins on")
struct PageSpanResolverTests {

    /// Shorthand for one document's recorded pages.
    private func doc(_ id: String, start: Int? = nil, _ breaks: [Int] = []) -> PageSpanResolver.DocumentPages {
        PageSpanResolver.DocumentPages(documentId: id, startPage: start, breaks: breaks)
    }

    /// What a page resolves to, as a test compares it.
    private struct Answer: Equatable {
        let ids: [String]
        let claim: PageSpanResolver.Claim?
        init(_ ids: [String], _ claim: PageSpanResolver.Claim?) { self.ids = ids; self.claim = claim }
    }

    /// The ids `page` resolves to, and whether they begin on it.
    private func lookUp(_ page: Int, _ documents: [PageSpanResolver.DocumentPages]) -> Answer {
        let claimants = PageSpanResolver.documents(onPage: page, in: documents)
        return Answer(claimants?.documents.map(\.documentId) ?? [], claimants?.claim)
    }

    @Test("A document is printed from the page it begins on through its last break — on that one page when it has no break of its own")
    func printedFromTheStartPage() {
        #expect(doc("d19", start: 49, [50]).certainPages == 49...50)
        #expect(doc("d17", start: 48).certainPages == 48...48)
        // A break at the top of the document, before its heading, is its start too.
        #expect(doc("d21", start: 55, [55, 56]).certainPages == 55...56)
        // With a start that places it, what it may be on is what it is certainly on.
        #expect(doc("d19", start: 49, [50]).possiblePages == 49...50)
    }

    @Test("Without a start that places it, a document is certainly on its own breaks and may begin on the page before the first — never page 0")
    func ownBreaksPlaceADocumentWithoutAStart() {
        // No start recorded: nothing before it in the volume.
        #expect(doc("d7", [49, 50]).placingStart == nil)
        #expect(doc("d7", [49, 50]).certainPages == 49...50)
        #expect(doc("d7", [49, 50]).possiblePages == 48...50)
        #expect(doc("d1", [1, 2]).possiblePages == 1...2)
        // A start its own breaks run below belongs to another numbering: the E-volumes' facsimile
        // pages, restarting inside a document after its heading.
        #expect(doc("e2", start: 7, [1, 2]).placingStart == nil)
        #expect(doc("e2", start: 7, [1, 2]).certainPages == 1...2)
        // The control: a start equal to the first break places it.
        #expect(doc("d21", start: 55, [55]).placingStart == 55)
        // Nothing places a document with neither.
        #expect(doc("d0").certainPages == nil)
        #expect(doc("d0").possiblePages == nil)
    }

    @Test("A page resolves to the documents that begin on it, before any document still running on it")
    func beginningWinsThePage() {
        let volume = [doc("d18", start: 48, [49]), doc("d19", start: 49, [50]), doc("d20", start: 51, [52, 53])]
        // d18 runs onto page 49; d19 begins there.
        #expect(lookUp(49, volume) == Answer(["d19"], .begins))
        // No document begins on 53: the one printed on it.
        #expect(lookUp(53, volume) == Answer(["d20"], .printed))
        // Several begin on one page: all of them, in source order.
        let shared = [doc("d17", start: 48), doc("d18", start: 48, [49])]
        #expect(lookUp(48, shared) == Answer(["d17", "d18"], .begins))
        #expect(PageSpanResolver.documents(onPage: 48, in: shared)?.isAmbiguous == true)
        #expect(PageSpanResolver.documents(onPage: 49, in: shared)?.isAmbiguous == false)
    }

    @Test("A document without a start never begins a page; several printed on one page are all returned; a page no document is on resolves to nil")
    func printedAndNothing() {
        // Breaks out of order in a printed volume (frus1948v04's d192 and d193): d2's own break,
        // 2, is below its start, 3, so no start places it and it begins on nothing.
        let outOfOrder = [doc("d1", start: 1, [2, 3]), doc("d2", start: 3, [2])]
        #expect(lookUp(2, outOfOrder) == Answer(["d1", "d2"], .printed))
        #expect(lookUp(3, outOfOrder) == Answer(["d1"], .printed))
        #expect(lookUp(9, outOfOrder) == Answer([], nil))
        #expect(lookUp(1, []) == Answer([], nil))
        // The claimant carries the pages it is certainly on.
        #expect(PageSpanResolver.documents(onPage: 2, in: outOfOrder)?.documents.map(\.pages) == [1...3, 2...2])
    }

    /// Rows as the index stores them for a volume that numbers its pages per document (#1503
    /// review round 1), in the shapes frus1969-76ve04 and ve05p1 print: d1's page 1 before its
    /// div; d2's inside, after its heading, so its start is d1's last page; d3 with no break of
    /// its own, its start d2's last page (ve05p1's d239); d4 one page, inside; d5 after the
    /// one-page d4, so its start is d4's page 1.
    private var perDocumentRows: [(documentId: String, isStart: Bool, pageInt: Int)] {
        [("d1", true, 1), ("d1", false, 2), ("d1", false, 3),
         ("d2", true, 3), ("d2", false, 1), ("d2", false, 2),
         ("d3", true, 2),
         ("d4", true, 2), ("d4", false, 1),
         ("d5", true, 1), ("d5", false, 1), ("d5", false, 2), ("d5", false, 3), ("d5", false, 4)]
    }

    @Test("A volume that numbers its pages per document is told apart from a printed one by how often its documents restart the numbering (#1503 review round 1)")
    func perDocumentNumberingIsDetected() {
        let perDocument = PageSpanResolver.documentPages(fromRows: perDocumentRows)
        #expect(PageSpanResolver.numbersPagesPerDocument(perDocument))
        #expect(perDocument.allSatisfy { $0.numberedPerDocument })
        // A printed volume whose breaks run out of order once among five documents is not.
        let printed = [doc("d1", start: 268, [269, 270]), doc("d2", start: 270, [269]),
                       doc("d3", start: 271), doc("d4", start: 272), doc("d5", start: 273)]
        #expect(!PageSpanResolver.numbersPagesPerDocument(printed))
        // Nor one whose restarting rows are all a section's, which records no start: a compilation
        // indexed beside the chapters it holds, as frus1919Parisv13's are.
        let sections = [doc("ch1", [4, 5, 6]), doc("comp1", [2, 3, 7]), doc("ch2", [8, 9]), doc("comp2", [7, 10])]
        #expect(!PageSpanResolver.numbersPagesPerDocument(sections))
        // The control: the same one restart in a volume of two documents is one in two.
        #expect(PageSpanResolver.numbersPagesPerDocument(Array(printed.prefix(2))))
        #expect(!PageSpanResolver.numbersPagesPerDocument([]))
    }

    @Test("In a volume that numbers its pages per document, only a start of page 1 places a document, and a page is every document printed on a page of that number — ambiguous even when one is (#1503 review round 1)")
    func perDocumentPagesAreEveryDocumentPrintedThere() {
        let volume = PageSpanResolver.documentPages(fromRows: perDocumentRows)
        func pages(_ id: String) -> PageSpanResolver.DocumentPages? { volume.first { $0.documentId == id } }
        // d3's start, 2, is d2's page: it places nothing — outside such a volume it would.
        #expect(pages("d3")?.placingStart == nil)
        #expect(pages("d3")?.possiblePages == nil)
        #expect(doc("d3", start: 2).placingStart == 2)
        // A start of page 1 places the document; one its own breaks run below still does not.
        #expect(pages("d1")?.certainPages == 1...3)
        #expect(pages("d5")?.certainPages == 1...4)
        #expect(pages("d2")?.certainPages == 1...2)
        // Page 1: every document with a page 1 — not the ones that "begin" there, d1 and d5, alone.
        #expect(lookUp(1, volume) == Answer(["d1", "d2", "d4", "d5"], .numberedPerDocument))
        // Page 2: not d3, whose start the page was.
        #expect(lookUp(2, volume) == Answer(["d1", "d2", "d5"], .numberedPerDocument))
        // Page 4: one document has one, and the answer is still ambiguous.
        #expect(lookUp(4, volume) == Answer(["d5"], .numberedPerDocument))
        #expect(PageSpanResolver.documents(onPage: 4, in: volume)?.isAmbiguous == true)
        #expect(lookUp(9, volume) == Answer([], nil))
    }

    @Test("Rows group into documents in the order each first appears, the start row apart from the breaks")
    func rowsGroupIntoDocuments() {
        let rows: [(documentId: String, isStart: Bool, pageInt: Int)] = [
            ("d18", true, 48), ("d18", false, 49),
            ("d19", true, 49), ("d19", false, 50),
            ("d20", false, 52), ("d20", true, 51),   // a start stored after a break still counts
            ("d20", true, 60),                         // a second start: the first is kept
        ]
        let documents = PageSpanResolver.documentPages(fromRows: rows)
        #expect(documents.map(\.documentId) == ["d18", "d19", "d20"])
        #expect(documents.map(\.startPage) == [48, 49, 51])
        #expect(documents.map(\.breaks) == [[49], [50], [52]])
        #expect(PageSpanResolver.documentPages(fromRows: []).isEmpty)
    }
}
