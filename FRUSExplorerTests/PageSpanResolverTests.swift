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
        // A volume numbering its pages per document, its breaks after each heading.
        let perDocument = [doc("d1", start: 3, [1, 2, 3]), doc("d2", start: 3, [1, 2])]
        #expect(lookUp(1, perDocument) == Answer(["d1", "d2"], .printed))
        #expect(lookUp(3, perDocument) == Answer(["d1"], .printed))
        #expect(lookUp(9, perDocument) == Answer([], nil))
        #expect(lookUp(1, []) == Answer([], nil))
        // The claimant carries the pages it is certainly on.
        #expect(PageSpanResolver.documents(onPage: 2, in: perDocument)?.documents.map(\.pages) == [1...3, 1...2])
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
