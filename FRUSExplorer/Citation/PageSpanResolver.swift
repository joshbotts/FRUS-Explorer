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
/// 120,993 (`tools/page-citations/rules_f.py` reproduces these figures).
///
/// ## Single source of truth
/// The reader's page links and Citation Lookup (`PageRangeStore`) and the indexing-time
/// page-reference resolver (`IndexingPipeline.resolvePageBasedCrossReferences`) all call
/// ``documents(onPage:in:)``, over rows built by ``documentPages(fromRows:)`` from one query
/// (``arabicPageRowsSQL``), so none can diverge from the others. Which ONE of several documents a
/// page reference means is ``citedDocument(among:facts:citing:)``, which the resolver and the
/// reader's page link both call (#1509) over the facts ``citedDocumentFactsSQL`` reads.
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
///   2.2 — #1509: ``citedDocument(among:facts:citing:)``, the one tie-break among several documents
///          on a page, with ``PageCitationHint`` and ``CitedDocumentFacts``; the two queries both
///          readers run, ``arabicPageRowsSQL`` and ``citedDocumentFactsSQL``.
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
        /// document's before it, which puts it on the page it begins on either way: over the fifteen
        /// volumes at `550a8c5c5` (`tools/page-citations/rules_f.py`), 391 documents with no break
        /// of their own begin on a page 1 (377 on a break outside every document, 14 on one another
        /// holds) and 349 on a later page, placed nowhere, as before #1503.
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
    /// own breaks can run backwards without the volume restarting anything: counting every row with
    /// a page, a section by its breaks, 36 of `frus1919Parisv13`'s 149 paged documents and sections
    /// "restart" — a hair under the line — when its compilations are indexed beside the chapters they
    /// hold, as they were until index v63, and 31 of 148 since v63 leaves them out (#1510,
    /// `rules_f.py` over `replica.py` with `RULE=v62` and without). Over the rows the index holds
    /// for the 548 volumes that are not microfiche supplements at `550a8c5c5`, the rule finds
    /// exactly the fifteen that number their pages per document (`tools/page-citations/simulate.py`,
    /// `rules_f.py`) — fourteen E-volumes and `frus1981-88v16`, where 56% (`frus1969-76ve14p1`, 106
    /// of 189) to 93% (`frus1969-76ve04`, 306 of 330) of those documents restart — and none of the
    /// 533 printed volumes, where at most 1% do (`frus1902app1`, 2 of 196: breaks out of order).
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

    // MARK: - Which of several a page reference means (#1509)

    /// The document a page reference means among the documents its page names: the one tie-break
    /// both the indexing-time resolver (`IndexingPipeline.resolvePageBasedCrossReferences`) and the
    /// reader's page link (`PageRangeStore.document(forPage:inVolume:citing:)`) call, so the stored
    /// edge, the cited-by count and the document a tap opens are the same document (#1509).
    ///
    /// When the page names one document, it. When it names several, whatever the claim — several
    /// short documents begin on it, where none does several are printed on it, or, in a volume that
    /// numbers its pages per document, several print a page of that number — the note the reference
    /// sits in usually says which:
    /// 1. a document number it names as a document (`Doc. No. 497`, `document 131`) that exactly one
    ///    of them carries;
    /// 2. otherwise the documents whose day it names (`July 7`, `Oct. 9, 1909`; a printed year must
    ///    agree), the first of them in source order;
    /// 3. otherwise the first in source order (the one at the top of the page, when several begin on
    ///    it) — what every page link opened before #1509.
    ///
    /// Measured over the 55,007 same-volume arabic `pg_N` references inside documents in the 533
    /// printed volumes at corpus `550a8c5c5` (`tools/page-citations/v63.py`, which applies this rule
    /// to the pages of a SAX replica of the parser and the notes of a SAX scan of the corpus): see
    /// `IndexingPipeline`'s v63 note for the figures. A number counts only when the note calls it a
    /// document's: "No. N" alone is usually a telegram's number — `frus1934v01` d397's "Telegram No.
    /// 391, July 7, 1 p.m., p. 467" cites d390, dated July 7, while d391 begins on the same page. A
    /// day counts only for a document dated to the day (``CitedDocumentFacts``): a month-precision
    /// date is stored as the month's first day. A promoted section can carry facts too —
    /// `document_cache` holds a number its heading opens with ("1. …") and `document_dates` a day it
    /// prints — and is matched like a document; no reference in that population cites a page naming
    /// several claimants with a section among them (`v63.py` counts them: 0).
    ///
    /// - Parameters:
    ///   - claimants: What the page names (``documents(onPage:in:)``). Never empty.
    ///   - facts: Each claimant's printed number and day, by document id (``CitedDocumentFacts``,
    ///     read through ``citedDocumentFactsSQL``). A claimant with none is matched by neither cue.
    ///   - citing: What the reference's note names (``PageCitationHint``), or `nil` for a reference
    ///     outside every footnote.
    public static func citedDocument(among claimants: PageClaimants,
                                     facts: [String: CitedDocumentFacts],
                                     citing: PageCitationHint?) -> String {
        let ids = claimants.documents.map(\.documentId)
        guard ids.count > 1, let citing else { return ids[0] }
        let numbered = ids.filter { id in
            guard let number = facts[id]?.printedNumber?.lowercased() else { return false }
            return citing.documentNumbers.contains { $0.lowercased() == number }
        }
        if numbered.count == 1 { return numbered[0] }
        if let dated = ids.first(where: { id in
            guard let day = facts[id]?.day else { return false }
            return citing.days.contains { $0.names(day) }
        }) {
            return dated
        }
        return ids[0]
    }

    /// The query whose rows ``CitedDocumentFacts/init(printedNumber:dateISO:precision:)`` reads: each
    /// document's printed number (`document_cache`) and stored day (`document_dates`), for one volume
    /// (bind it as parameter 1). One string, so the indexer and the reader read the same columns.
    public static let citedDocumentFactsSQL = """
        SELECT c.document_id, c.document_number, d.date_iso, d.date_precision
        FROM document_cache c
        LEFT JOIN document_dates d ON d.volume_id = c.volume_id AND d.document_id = c.document_id
        WHERE c.volume_id = ?
        """

    /// The query whose rows ``documentPages(fromRows:)`` groups — every arabic `page_ranges` row of
    /// one volume in the order the index stored them (bind the volume as parameter 1). The indexer
    /// and the reader run this one string.
    public static let arabicPageRowsSQL = """
        SELECT document_id, is_start, page_number_int
        FROM page_ranges
        WHERE volume_id = ? AND page_number_type = 'arabic' AND page_number_int IS NOT NULL
        ORDER BY rowid
        """
}

// MARK: - CitedDocumentFacts

/// What ``PageSpanResolver/citedDocument(among:facts:citing:)`` compares a page reference's note
/// against for one document: its printed number and the day it is dated (#1509).
public struct CitedDocumentFacts: Sendable, Equatable {
    /// The document's printed number (`document_cache.document_number`).
    public let printedNumber: String?
    /// The day the document is dated, when its stored date is precise to the day.
    public let day: PageCitationHint.CitedDay?

    /// A document's facts as given.
    public init(printedNumber: String?, day: PageCitationHint.CitedDay?) {
        self.printedNumber = printedNumber
        self.day = day
    }

    /// A document's facts from the columns ``PageSpanResolver/citedDocumentFactsSQL`` reads. The day
    /// is taken from `date_iso` (`yyyy-MM-dd`, the day #1326 stores) only when `date_precision` is
    /// `day`: a month or a year is stored as its first day, which no note means by "June 1".
    public init(printedNumber: String?, dateISO: String?, precision: String?) {
        let trimmed = printedNumber?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.printedNumber = (trimmed?.isEmpty ?? true) ? nil : trimmed
        guard precision == "day", let dateISO else { self.day = nil; return }
        let parts = dateISO.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { self.day = nil; return }
        self.day = PageCitationHint.CitedDay(month: parts[1], day: parts[2], year: parts[0])
    }
}

// MARK: - PageCitationHint

/// What the note a page reference sits in names that can tell several documents on a page apart
/// (#1509): the document numbers it names as documents and the days it names.
///
/// Built from the printed text of the reference's innermost footnote — by the indexer
/// (`IndexingPipeline.collectDocumentRefs`) and by the reader (`ASTToRenderNodeConverter`, which
/// hands it to the link and back through `FRUSURLSchemeHandler`) from the same AST through
/// ``init(noteChildren:)`` — so both ask ``PageSpanResolver/citedDocument(among:facts:citing:)`` the
/// same question.
public struct PageCitationHint: Sendable, Equatable {

    /// A day a note names: its month and day, and the year when one is printed with them.
    public struct CitedDay: Sendable, Equatable, Hashable {
        /// 1–12.
        public let month: Int
        /// 1–31.
        public let day: Int
        /// The year printed after the day (`Oct. 9, 1909`), or `nil` when none is.
        public let year: Int?

        /// A day as given.
        public init(month: Int, day: Int, year: Int?) {
            self.month = month
            self.day = day
            self.year = year
        }

        /// Whether this day, as a note names it, is `other`: the same month and day, and the same
        /// year when this one prints a year and `other` has one.
        public func names(_ other: CitedDay) -> Bool {
            guard month == other.month, day == other.day else { return false }
            guard let year, let otherYear = other.year else { return true }
            return year == otherYear
        }
    }

    /// The numbers the note gives documents, as printed (`497`, `131a`).
    public let documentNumbers: [String]
    /// The days the note names, in the order it names them.
    public let days: [CitedDay]

    /// A hint as given.
    public init(documentNumbers: [String], days: [CitedDay]) {
        self.documentNumbers = documentNumbers
        self.days = days
    }

    /// What `citingText` names, or `nil` when it names no document number and no day — a hint that
    /// could only ever say "the first", which is what no hint says.
    public init?(citingText: String) {
        let ns = citingText as NSString
        let full = NSRange(location: 0, length: ns.length)
        var numbers: [String] = []
        Self.documentNumberRegex?.enumerateMatches(in: citingText, range: full) { match, _, _ in
            guard let match else { return }
            numbers.append(ns.substring(with: match.range(at: 1)))
        }
        var days: [CitedDay] = []
        Self.dayRegex?.enumerateMatches(in: citingText, range: full) { match, _, _ in
            guard let match,
                  let month = Self.month(ns.substring(with: match.range(at: 1))),
                  let day = Int(ns.substring(with: match.range(at: 2))), (1...31).contains(day) else { return }
            let yearRange = match.range(at: 3)
            let year = yearRange.location == NSNotFound ? nil : Int(ns.substring(with: yearRange))
            days.append(CitedDay(month: month, day: day, year: year))
        }
        guard !numbers.isEmpty || !days.isEmpty else { return nil }
        self.init(documentNumbers: numbers, days: days)
    }

    /// What a footnote whose children are `noteChildren` names: its printed text, whitespace
    /// collapsed, through ``init(citingText:)``. The one way the indexer and the reader build a hint.
    public init?(noteChildren: [FRUSASTNode]) {
        let text = FRUSASTNode.printedText(of: noteChildren)
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        self.init(citingText: text)
    }

    /// "Doc. No. 497", "document No. 210", "Document 131", "Docs. 4": a number the note gives a
    /// document. A bare "No. 4" is not one — in a footnote it is usually a telegram's or a despatch's.
    private static let documentNumberRegex = try? NSRegularExpression(
        pattern: #"\b(?:Docs?\.|[Dd]ocuments?)\s*(?:[Nn]os?\.\s*)?(\d+[A-Za-z]?)\b"#)

    /// A month, spelled out or abbreviated as the volumes abbreviate one ("Oct. 9", "Sept. 9"),
    /// then its day, then optionally its year.
    private static let dayRegex = try? NSRegularExpression(
        pattern: #"\b(January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sept|Sep|Oct|Nov|Dec)\.?\s*(\d{1,2})(?:st|nd|rd|th)?(?!\d)(?:,?\s*(\d{4})(?!\d))?"#)

    /// The month a name or abbreviation is, 1–12, or `nil` for a word that names none.
    static func month(_ name: String) -> Int? {
        let prefix = String(name.prefix(3))
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return months.firstIndex(of: prefix).map { $0 + 1 }
    }

    // MARK: URL form

    /// The hint as a page link's query items (`no=497`, `day=6-5` or `day=10-9-1909`), so the reader's
    /// link carries it to `FRUSURLSchemeHandler` and back.
    public var queryItems: [URLQueryItem] {
        documentNumbers.map { URLQueryItem(name: "no", value: $0) }
            + days.map { day in
                URLQueryItem(name: "day", value: day.year.map { "\(day.month)-\(day.day)-\($0)" }
                    ?? "\(day.month)-\(day.day)")
            }
    }

    /// The hint ``queryItems`` wrote, or `nil` when the items carry none.
    public init?(queryItems: [URLQueryItem]) {
        var numbers: [String] = []
        var days: [CitedDay] = []
        for item in queryItems {
            guard let value = item.value, !value.isEmpty else { continue }
            switch item.name {
            case "no":
                numbers.append(value)
            case "day":
                let parts = value.split(separator: "-").compactMap { Int($0) }
                guard parts.count == 2 || parts.count == 3 else { continue }
                days.append(CitedDay(month: parts[0], day: parts[1], year: parts.count == 3 ? parts[2] : nil))
            default:
                continue
            }
        }
        guard !numbers.isEmpty || !days.isEmpty else { return nil }
        self.init(documentNumbers: numbers, days: days)
    }
}
