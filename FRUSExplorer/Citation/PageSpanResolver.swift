// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - PageSpanResolver

/// Which documents a printed arabic page number is, and which pages a document is printed on.
///
/// FRUS TEI marks every printed page with a `<pb n="427" xml:id="pg_427"/>` element and references
/// a specific page with `<ref target="#pg_427">`. A page has no `<div>` of its own, so which
/// document is on it has to be read from where the breaks fall relative to the documents (#1503):
///
/// - **The page a document begins on** is the page of the last `<pb>` before its first printed
///   text. That is a break between documents, just before the div, when it begins at the top of a
///   page; the previous document's last break, when it begins part-way down one; or a break inside
///   the div ahead of its heading. The index records it beside the document's own breaks
///   (`page_ranges.is_start`, `FRUSDocumentAST.startPage`).
/// - **A document is printed on** that page through its last break, `[start, max(start, last)]`.
///   One with no break of its own is printed on the page it begins on, alone.
/// - **Without a start that places it** — no break before its first text anywhere in the volume,
///   one that is not an arabic page, or one its own breaks run below (the numbering restarted) —
///   only its own breaks place it: it is certainly on `[first, last]`, and may also be on the page
///   before the first, where it begins when it begins part-way down.
/// - **In a volume that numbers its pages afresh in every document** (``numbersPagesPerDocument(_:)``:
///   fourteen of the E-volumes and `frus1981-88v16`), every document begins on its own page 1, so
///   a start other than page 1 is the page of the document before it, in that document's
///   numbering, and places nothing (#1503 review round 1).
///
/// ## Which documents a page is
/// The documents that BEGIN on it, when any does: a citation of a page names the document printed
/// there, and the page a document begins on is the one a citation names. When none begins on it,
/// the documents certainly printed on it. Either way in source order, and more than one is an
/// ambiguous answer, which Citation Lookup reports as such (`MatchStrategy.sharedPage`).
///
/// In a volume that numbers its pages per document, every document certainly printed on a page of
/// that number, and the answer is ambiguous however many there are: the number alone names none
/// of them (``Claim/numberedPerDocument``). Until #1503 review round 1 the documents that began on
/// the page hid the others there, and one that alone began on it — placed by the page in effect
/// before it, another document's — was the answer, a match by page.
///
/// Before #1503 the index recorded a break only inside the document containing it, and a page went
/// to the document owning the last break at or before it. Measured over the 306,463 documents of
/// the 533 printed volumes at corpus `550a8c5c5` whose recorded start places them — with a SAX
/// replica of the parser over the rows the index holds, promoted prose sections' own breaks
/// included (#1503 review round 1) — the page a document begins on went to the document before it
/// for 156,625, to an earlier document or a promoted section for 32,293, to none for 117,503 — the
/// break before them sat between documents, recorded against neither — to one of several,
/// whichever a Swift Dictionary reached first, for 40, and to the document itself for 2. Under the
/// rule here it names the document alone for 185,470 and among others that begin there for
/// 120,993.
///
/// ## Single source of truth
/// The reader's page links and Citation Lookup (`PageRangeStore`) and the indexing-time
/// page-reference resolver (`IndexingPipeline.resolvePageBasedCrossReferences`) all call
/// ``documents(onPage:in:)``, over rows built by ``documentPages(fromRows:)``, so none can
/// diverge from the others.
///
/// Version history:
///   1.0 — Session 2026-07-05: extracted from `PageRangeStore.span` (Session 162 fix
///          preserved: the final span closes at the section max page, not `Int.max`) so
///          the indexing-time page-reference resolver and the reader share one algorithm.
///   2.0 — #1503: reads the page each document begins on. `documentContaining(page:in:)`, which
///          gave a page to the document owning the last break at or before it, is replaced by
///          ``documents(onPage:in:)``, which returns every document the page is and says whether
///          they begin on it; ``DocumentPages`` states which pages a document is printed on, which
///          `PageRangeStore.printedPages` returns for Citation Lookup's page check.
///   2.1 — #1503 review round 1: ``numbersPagesPerDocument(_:)``. In such a volume a start other
///          than page 1 places no document, and a page is every document printed on it,
///          ``Claim/numberedPerDocument``, ambiguous even when one document carries it.
public enum PageSpanResolver {

    // MARK: - DocumentPages

    /// One document's recorded pages: the arabic page it begins on, and the arabic page breaks
    /// inside it, in source order.
    public struct DocumentPages: Sendable, Equatable {
        /// The document's `xml:id`.
        public let documentId: String
        /// The arabic page the document begins on, when the index recorded one (`nil` when no
        /// break precedes its first text, or the one that does is not an arabic page).
        public var startPage: Int?
        /// The arabic page breaks inside the document, in source order.
        public var breaks: [Int]
        /// Whether the document's volume numbers its pages afresh in every document
        /// (``PageSpanResolver/numbersPagesPerDocument(_:)``), which ``PageSpanResolver/documentPages(fromRows:)``
        /// sets on every document of such a volume (#1503 review round 1).
        public var numberedPerDocument: Bool

        /// A document's pages as recorded.
        public init(documentId: String, startPage: Int? = nil, breaks: [Int] = [],
                    numberedPerDocument: Bool = false) {
            self.documentId = documentId
            self.startPage = startPage
            self.breaks = breaks
            self.numberedPerDocument = numberedPerDocument
        }

        /// `startPage` when it places the document: `nil` when there is none, or when a break of
        /// the document's own lies below it — the numbering restarted between the two, so the page
        /// in effect before the document belongs to another numbering.
        ///
        /// In a volume that numbers its pages per document it places the document only when it is
        /// page 1 (#1503 review round 1). Every document there begins on its own page 1, so a start
        /// of 3 is the page the document before it ended on — as for `frus1969-76ve05p1`'s d239,
        /// which has no page break of its own and would otherwise be placed on d238's page 2. A
        /// start of 1 is the document's own page-1 break, written before its div, or a one-page
        /// document's before it, which puts it on the page it begins on either way: measured over
        /// the fifteen volumes at corpus `550a8c5c5`, 390 documents with no break of their own
        /// begin on a page 1, 338 of them on their own page-1 break, and 349 more begin on a later
        /// page and are placed nowhere, as they were before #1503.
        public var placingStart: Int? {
            guard let startPage, breaks.allSatisfy({ $0 >= startPage }) else { return nil }
            guard !numberedPerDocument || startPage == 1 else { return nil }
            return startPage
        }

        /// The pages the document is certainly printed on: from its start through its last break
        /// — or, with no start that places it, from its first break to its last — or `nil` when
        /// nothing places it.
        public var certainPages: ClosedRange<Int>? {
            if let start = placingStart { return start...max(start, breaks.max() ?? start) }
            guard let first = breaks.min(), let last = breaks.max() else { return nil }
            return first...last
        }

        /// The pages the document may be printed on — the pages Citation Lookup accepts for it.
        /// `certainPages`, and, when no start places it, the page before its first break too,
        /// where it begins when it begins part-way down a page (never page 0).
        public var possiblePages: ClosedRange<Int>? {
            guard let certain = certainPages else { return nil }
            guard placingStart == nil, certain.lowerBound > 1 else { return certain }
            return (certain.lowerBound - 1)...certain.upperBound
        }
    }

    /// Groups `page_ranges` rows — `(documentId, isStart, page)`, arabic pages only, in the order
    /// the index stored them — into one ``DocumentPages`` per document, in the order each document
    /// first appears, which is source order. Pass a whole volume's rows: whether the volume numbers
    /// its pages per document is read from all of them, and set on every document.
    public static func documentPages(
        fromRows rows: [(documentId: String, isStart: Bool, pageInt: Int)]
    ) -> [DocumentPages] {
        var order: [String] = []
        var byId: [String: DocumentPages] = [:]
        for row in rows {
            if byId[row.documentId] == nil {
                order.append(row.documentId)
                byId[row.documentId] = DocumentPages(documentId: row.documentId)
            }
            if row.isStart {
                // One start row per document; a second (a document id repeated in a volume) keeps
                // the first, as a reader would.
                if byId[row.documentId]?.startPage == nil { byId[row.documentId]?.startPage = row.pageInt }
            } else {
                byId[row.documentId]?.breaks.append(row.pageInt)
            }
        }
        var documents = order.compactMap { byId[$0] }
        if numbersPagesPerDocument(documents) {
            for index in documents.indices { documents[index].numberedPerDocument = true }
        }
        return documents
    }

    /// Whether a volume numbers its pages afresh in every document (#1503 review round 1): whether
    /// at least one in four of its documents with a recorded start restarts the numbering — its
    /// start, or one of its breaks, is below the page before it, reading those documents' pages in
    /// source order.
    ///
    /// Only documents with a start count. A prose section the parser promotes records none, and its
    /// own breaks can run backwards without the volume restarting anything: `frus1919Parisv13`'s
    /// compilations are indexed beside the chapters they hold, and counting them, 36 of its 149
    /// paged documents and sections "restart" — a hair under the line. Measured over the 548
    /// volumes that are not microfiche supplements at corpus `550a8c5c5`, over the rows the index
    /// holds, the rule finds exactly the fifteen that number their pages per document — fourteen
    /// E-volumes and `frus1981-88v16`, where between 56% (`frus1969-76ve14p1`, 106 of 189) and 93%
    /// (`frus1969-76ve04`, 306 of 330) of those documents restart — and none of the 533 printed
    /// volumes, where at most 1% do (`frus1902app1`, 2 of 196: breaks out of order).
    public static func numbersPagesPerDocument(_ documents: [DocumentPages]) -> Bool {
        var previous: Int?
        var started = 0
        var restarting = 0
        for document in documents {
            guard let start = document.startPage else { continue }
            started += 1
            var restarts = false
            for page in [start] + document.breaks {
                if let previous, page < previous { restarts = true }
                previous = page
            }
            if restarts { restarting += 1 }
        }
        return restarting > 0 && restarting * 4 >= started
    }

    // MARK: - Page lookup

    /// How the documents a page resolves to stand on it.
    public enum Claim: Sendable, Equatable {
        /// They begin on the page.
        case begins
        /// They are printed on it, having begun on an earlier page.
        case printed
        /// They are every document printed on a page of that number in a volume that numbers its
        /// pages afresh in every document, where the number alone names none of them — one
        /// document or many (#1503 review round 1).
        case numberedPerDocument
    }

    /// One document a page resolves to.
    public struct PageClaimant: Sendable, Equatable {
        /// The document's `xml:id`.
        public let documentId: String
        /// The pages it is certainly printed on (``DocumentPages/certainPages``), the page among them.
        public let pages: ClosedRange<Int>
    }

    /// The documents a page resolves to, in source order, and how they stand on it.
    public struct PageClaimants: Sendable, Equatable {
        /// Whether they begin on the page, run through it, or carry its number in a volume numbering
        /// its pages per document.
        public let claim: Claim
        /// The documents, in source order. Never empty.
        public let documents: [PageClaimant]

        /// Whether the page cannot name one document: it names several, or it is a page number in a
        /// volume that numbers its pages per document.
        public var isAmbiguous: Bool { claim == .numberedPerDocument || documents.count > 1 }
    }

    /// The documents `page` is: those that begin on it, or, when none does, those certainly
    /// printed on it; `nil` when no document is (a page before the first document, after the
    /// last, or in front matter the index holds no document for). In a volume that numbers its
    /// pages per document, every document certainly printed on a page of that number
    /// (``Claim/numberedPerDocument``) — which includes every document that begins on it.
    ///
    /// - Parameters:
    ///   - page: The arabic printed page number.
    ///   - documents: One volume's documents, in source order (``documentPages(fromRows:)``).
    public static func documents(onPage page: Int, in documents: [DocumentPages]) -> PageClaimants? {
        if documents.contains(where: \.numberedPerDocument) {
            let printed = documents.compactMap { document -> PageClaimant? in
                guard let pages = document.certainPages, pages.contains(page) else { return nil }
                return PageClaimant(documentId: document.documentId, pages: pages)
            }
            return printed.isEmpty ? nil : PageClaimants(claim: .numberedPerDocument, documents: printed)
        }
        let beginning = documents.compactMap { document -> PageClaimant? in
            guard document.placingStart == page, let pages = document.certainPages else { return nil }
            return PageClaimant(documentId: document.documentId, pages: pages)
        }
        if !beginning.isEmpty { return PageClaimants(claim: .begins, documents: beginning) }
        let printed = documents.compactMap { document -> PageClaimant? in
            guard let pages = document.certainPages, pages.contains(page) else { return nil }
            return PageClaimant(documentId: document.documentId, pages: pages)
        }
        if !printed.isEmpty { return PageClaimants(claim: .printed, documents: printed) }
        return nil
    }
}
