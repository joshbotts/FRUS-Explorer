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
///   one that is not an arabic page, or one its own breaks run below (the numbering restarted, as
///   it does in the E-volumes that number their pages per document) — only its own breaks place
///   it: it is certainly on `[first, last]`, and may also be on the page before the first, where
///   it begins when it begins part-way down.
///
/// ## Which documents a page is
/// The documents that BEGIN on it, when any does: a citation of a page names the document printed
/// there, and the page a document begins on is the one a citation names. When none begins on it,
/// the documents certainly printed on it. Either way in source order, and more than one is an
/// ambiguous answer, which Citation Lookup reports as such (`MatchStrategy.sharedPage`).
///
/// Before #1503 the index recorded a break only inside the document containing it, and a page went
/// to the document owning the last break at or before it: over the 306,469 documents of the 533
/// printed volumes at corpus `550a8c5c5` whose start page is now recorded, the page a document
/// begins on went to the document before it for 156,646, to an earlier one for 32,276, and to none
/// for 117,525 — the break before them sat between documents, recorded against neither — and to
/// the document itself for 2.
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

        /// A document's pages as recorded.
        public init(documentId: String, startPage: Int? = nil, breaks: [Int] = []) {
            self.documentId = documentId
            self.startPage = startPage
            self.breaks = breaks
        }

        /// `startPage` when it places the document: `nil` when there is none, or when a break of
        /// the document's own lies below it — the numbering restarted between the two, so the page
        /// in effect before the document belongs to another numbering.
        public var placingStart: Int? {
            guard let startPage, breaks.allSatisfy({ $0 >= startPage }) else { return nil }
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
    /// first appears, which is source order.
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
        return order.compactMap { byId[$0] }
    }

    // MARK: - Page lookup

    /// How the documents a page resolves to stand on it.
    public enum Claim: Sendable, Equatable {
        /// They begin on the page.
        case begins
        /// They are printed on it, having begun on an earlier page.
        case printed
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
        /// Whether they begin on the page or run through it.
        public let claim: Claim
        /// The documents, in source order. Never empty.
        public let documents: [PageClaimant]

        /// Whether the page names more than one document.
        public var isAmbiguous: Bool { documents.count > 1 }
    }

    /// The documents `page` is: those that begin on it, or, when none does, those certainly
    /// printed on it; `nil` when no document is (a page before the first document, after the
    /// last, or in front matter the index holds no document for).
    ///
    /// - Parameters:
    ///   - page: The arabic printed page number.
    ///   - documents: One volume's documents, in source order (``documentPages(fromRows:)``).
    public static func documents(onPage page: Int, in documents: [DocumentPages]) -> PageClaimants? {
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
