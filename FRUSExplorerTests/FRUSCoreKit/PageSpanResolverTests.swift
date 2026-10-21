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
        // indexed beside the chapters it holds, as frus1919Parisv13's were until index v63 left its
        // heading-only containers out (#1510). The rule must not depend on that.
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

// MARK: - Which of several documents a page reference means (#1509)

/// `PageSpanResolver.citedDocument(among:facts:citing:)` and what it reads: the one tie-break the
/// indexer stores a page reference's edge by and the reader's page link opens by. The end-to-end
/// cases, through the real pipeline and a real link's dispatch, are `CitationLookupIndexedTests`'s.
@Suite("PageSpanResolver — the document a page reference's footnote names among several on the page (#1509)")
struct CitedDocumentTieBreakTests {

    /// Three documents beginning on page 683, in source order.
    private let claimants = PageSpanResolver.PageClaimants(claim: .begins, documents: [
        .init(documentId: "d496", pages: 683...683),
        .init(documentId: "d497", pages: 683...684),
        .init(documentId: "d498", pages: 683...683),
    ])

    /// Their printed numbers and days, as `citedDocumentFactsSQL`'s rows give them.
    private let facts: [String: CitedDocumentFacts] = [
        "d496": CitedDocumentFacts(printedNumber: "496", dateISO: "1888-07-11", precision: "day"),
        "d497": CitedDocumentFacts(printedNumber: "497", dateISO: "1888-08-17", precision: "day"),
        "d498": CitedDocumentFacts(printedNumber: "498", dateISO: "1888-08-01", precision: "month"),
    ]

    /// The document a footnote reading `text` (none when `nil`) cites among the three.
    private func cited(_ text: String?) -> String {
        PageSpanResolver.citedDocument(among: claimants, facts: facts,
                                       citing: text.flatMap(PageCitationHint.init(citingText:)))
    }

    @Test("One document on the page is the answer, whatever the note says")
    func oneDocumentIsTheAnswer() {
        let one = PageSpanResolver.PageClaimants(claim: .printed, documents: [.init(documentId: "d1", pages: 1...2)])
        let hint = PageCitationHint(citingText: "Doc. No. 497, August 17")
        #expect(PageSpanResolver.citedDocument(among: one, facts: facts, citing: hint) == "d1")
    }

    @Test("No footnote: the first in source order")
    func noFootnoteIsTheFirst() {
        #expect(cited(nil) == "d496")
    }

    @Test("A number the note gives a document, carried by exactly one of them, decides")
    func aDocumentNumberDecides() {
        #expect(cited("printed as Doc. No. 497 post, page 683.") == "d497")
        #expect(cited("For inclosure see document No. 497, page 683.") == "d497")
        #expect(cited("See Document 497.") == "d497")
        // It outranks a day naming another of them.
        #expect(cited("Doc. No. 497, of July 11.") == "d497")
    }

    @Test("Two numbers on the page decide nothing; the day does, and without one the first")
    func twoNumbersFallToTheDay() {
        #expect(cited("Doc. No. 496 and Doc. No. 497 of August 17.") == "d497")
        #expect(cited("Doc. No. 496 and Doc. No. 497.") == "d496")
    }

    @Test("\"No. N\" alone is no document's number: a telegram's, in frus1934v01 d397's note")
    func aBareNumberIsNotADocuments() {
        #expect(cited("Telegram No. 497, July 11, 1 p.m., p. 683.") == "d496")
    }

    @Test("A day decides: spelled out or abbreviated, with a year that must agree")
    func aDayDecides() {
        #expect(cited("Count Arco Valley's note of August 17, 1888, p. 683.") == "d497")
        #expect(cited("note of Aug. 17, p. 683.") == "d497")
        #expect(cited("note of Aug 17, p. 683.") == "d497")
        #expect(cited("despatch of August 17, 1887, p. 683.") == "d496")
    }

    @Test("Several days on the page: the first of the documents the note names, in source order")
    func severalDaysTakeTheFirstNamed() {
        let three = PageSpanResolver.PageClaimants(claim: .begins, documents: [
            .init(documentId: "e1", pages: 700...700), .init(documentId: "e2", pages: 700...700),
            .init(documentId: "e3", pages: 700...701)])
        let days: [String: CitedDocumentFacts] = [
            "e1": CitedDocumentFacts(printedNumber: "1", dateISO: "1889-01-01", precision: "day"),
            "e2": CitedDocumentFacts(printedNumber: "2", dateISO: "1889-01-02", precision: "day"),
            "e3": CitedDocumentFacts(printedNumber: "3", dateISO: "1889-01-03", precision: "day")]
        let hint = PageCitationHint(citingText: "Telegrams of January 3 and January 2, p. 700.")
        #expect(PageSpanResolver.citedDocument(among: three, facts: days, citing: hint) == "e2")
    }

    @Test("A month-precision date is no day: \"August 1\" does not name d498, stored as August 1")
    func aMonthIsNoDay() {
        #expect(cited("letter of August 1, p. 683.") == "d496")
        #expect(facts["d498"]?.day == nil)
    }

    /// A claimant missing from `facts` is matched by neither cue, whatever its id. That is not "a
    /// section has no facts": `citedDocumentFactsSQL` reads `document_cache`, which holds every
    /// promoted section, with a number its heading opens with and any day it prints. Over the
    /// corpus no reference cites a page naming several claimants with a section among them
    /// (`tools/page-citations/v63.py`: 0), so nothing yet depends on how a section's facts compare.
    @Test("A claimant the facts do not hold is named by neither cue")
    func aClaimantWithoutFactsIsNamedByNeither() {
        let mixed = PageSpanResolver.PageClaimants(claim: .begins, documents: [
            .init(documentId: "ch9", pages: 57...58), .init(documentId: "d497", pages: 683...684)])
        let hint = PageCitationHint(citingText: "Doc. No. 9, August 17")
        #expect(PageSpanResolver.citedDocument(among: mixed, facts: facts, citing: hint) == "d497")
    }

    @Test("The facts read the stored columns: a day only at day precision and from a whole date, a blank number as none")
    func factsFromColumns() {
        let full = CitedDocumentFacts(printedNumber: " 497 ", dateISO: "1888-08-17", precision: "day")
        #expect(full.printedNumber == "497")
        #expect(full.day == PageCitationHint.CitedDay(month: 8, day: 17, year: 1888))
        #expect(CitedDocumentFacts(printedNumber: "", dateISO: nil, precision: nil).printedNumber == nil)
        #expect(CitedDocumentFacts(printedNumber: nil, dateISO: nil, precision: "day").day == nil)
        #expect(CitedDocumentFacts(printedNumber: nil, dateISO: "1888-08", precision: "day").day == nil)
        #expect(CitedDocumentFacts(printedNumber: nil, dateISO: "1888-08-17", precision: "year").day == nil)
    }
}

// MARK: - PageCitationHint

/// What a footnote names (#1509), and the form a page link carries it in.
@Suite("PageCitationHint — the document numbers and days a footnote names (#1509)")
struct PageCitationHintTests {

    @Test("A note naming no document number and no day gives no hint")
    func nothingNamedIsNoHint() {
        #expect(PageCitationHint(citingText: "See p. 683.") == nil)
        #expect(PageCitationHint(citingText: "") == nil)
    }

    @Test("Document numbers are read only where the note calls them a document's")
    func documentNumbers() {
        #expect(PageCitationHint(citingText: "Doc. No. 497 post")?.documentNumbers == ["497"])
        #expect(PageCitationHint(citingText: "documents Nos. 547, 556")?.documentNumbers == ["547"])
        #expect(PageCitationHint(citingText: "Document 131a, ante")?.documentNumbers == ["131a"])
        #expect(PageCitationHint(citingText: "Docs. 4 and 5")?.documentNumbers == ["4"])
        #expect(PageCitationHint(citingText: "telegram No. 4, p. 3") == nil)
    }

    @Test("Days: spelled out or abbreviated, a day out of range refused, a year kept when printed")
    func days() {
        typealias Day = PageCitationHint.CitedDay
        #expect(PageCitationHint(citingText: "June 5")?.days == [Day(month: 6, day: 5, year: nil)])
        #expect(PageCitationHint(citingText: "Oct. 9, 1909, from Russia")?.days == [Day(month: 10, day: 9, year: 1909)])
        #expect(PageCitationHint(citingText: "Sept. 9, 1915")?.days == [Day(month: 9, day: 9, year: 1915)])
        #expect(PageCitationHint(citingText: "May 3d")?.days == [Day(month: 5, day: 3, year: nil)])
        #expect(PageCitationHint(citingText: "July 7, 1 p.m.")?.days == [Day(month: 7, day: 7, year: nil)])
        #expect(PageCitationHint(citingText: "June 1945") == nil)
        #expect(PageCitationHint(citingText: "March 45") == nil)
        #expect(PageCitationHint(citingText: "March 0") == nil)
    }

    @Test("A day printed with a year names only that year's day; without one, the day in any year")
    func aDayNamesItsYear() {
        let candidate = PageCitationHint.CitedDay(month: 8, day: 17, year: 1888)
        #expect(PageCitationHint.CitedDay(month: 8, day: 17, year: nil).names(candidate))
        #expect(PageCitationHint.CitedDay(month: 8, day: 17, year: 1888).names(candidate))
        #expect(!PageCitationHint.CitedDay(month: 8, day: 17, year: 1887).names(candidate))
        #expect(!PageCitationHint.CitedDay(month: 8, day: 18, year: nil).names(candidate))
        #expect(!PageCitationHint.CitedDay(month: 9, day: 17, year: nil).names(candidate))
        #expect(PageCitationHint.CitedDay(month: 8, day: 17, year: 1888)
                    .names(PageCitationHint.CitedDay(month: 8, day: 17, year: nil)))
    }

    @Test("A month name or abbreviation is its month; any other word is none")
    func monthNames() {
        #expect(PageCitationHint.month("September") == 9)
        #expect(PageCitationHint.month("Sept") == 9)
        #expect(PageCitationHint.month("May") == 5)
        #expect(PageCitationHint.month("Smarch") == nil)
    }

    @Test("A hint survives a page link's query, and a query carrying none gives none")
    func queryRoundTrip() {
        let hint = PageCitationHint(documentNumbers: ["497", "131a"],
                                    days: [.init(month: 8, day: 17, year: 1888), .init(month: 7, day: 11, year: nil)])
        #expect(PageCitationHint(queryItems: hint.queryItems) == hint)
        #expect(PageCitationHint(queryItems: []) == nil)
        #expect(PageCitationHint(queryItems: [URLQueryItem(name: "no", value: "")]) == nil)
        #expect(PageCitationHint(queryItems: [URLQueryItem(name: "no", value: nil)]) == nil)
        #expect(PageCitationHint(queryItems: [URLQueryItem(name: "other", value: "497")]) == nil)
        #expect(PageCitationHint(queryItems: [URLQueryItem(name: "day", value: "8")]) == nil)
        #expect(PageCitationHint(queryItems: [URLQueryItem(name: "day", value: "8-17-1888-1")]) == nil)
        #expect(PageCitationHint(queryItems: [URLQueryItem(name: "day", value: "x-17")]) == nil)
    }
}

// MARK: - PageReferenceFormTests (A18b)

/// The printed form of a page reference, classified from its siblings (`PageReferenceForm`), which
/// decides whether a page of another volume cites the document on it (rule C, A18b). Each shape is
/// one the corpus prints: measured over the 173,933 cross-volume page `<ref>`s of the catalogue
/// volumes at corpus `6170e4b32`, 36,044 are an end of a range (`pp. 131</ref>–<ref>149`),
/// 10,641 carry "ff." (23 inside the reference, the rest after it) and the others are single pages.
@Suite("PageReferenceForm — a page's printed form, from its siblings (A18b)")
struct PageReferenceFormTests {

    /// A reference to `page` of `volume` (`nil` for the volume being read), printing `text`.
    private func ref(_ volume: String?, _ page: Int, _ text: String) -> FRUSASTNode {
        .crossReference(target: volume.map { "\($0)#pg_\(page)" } ?? "#pg_\(page)",
                        targetVolumeId: volume, children: [.text(text)])
    }

    /// The forms of the references among `nodes`, in order, `nil` for a node that is no reference.
    private func forms(_ nodes: [FRUSASTNode]) -> [PageReferenceForm?] {
        nodes.indices.map { index in
            if case .crossReference = nodes[index] {
                return PageReferenceForm.form(ofPageReferenceAt: index, in: nodes)
            }
            return nil
        }
    }

    @Test("A range is two page references of one volume with one dash between them, whichever dash")
    func ranges() {
        for dash in ["–", "—", "−", "-", " – ", "\n–\n"] {
            let nodes: [FRUSASTNode] = [.text("See "), ref("frus1931-41v02", 131, "pp. 131"), .text(dash),
                                        ref("frus1931-41v02", 149, "149"), .text(".")]
            #expect(forms(nodes) == [nil, .rangeStart(end: 149), nil, .rangeEnd(start: 131), nil],
                    "with the dash \(dash.debugDescription)")
        }
    }

    @Test("A dash to a page of another volume, to a page of the volume being read, or to a document is no range")
    func notARange() {
        // Two volumes: the second reference is a single page of its own volume.
        #expect(forms([ref("volB", 131, "pp. 131"), .text("–"), ref("volC", 149, "149")])
                == [.single, nil, .single])
        // A page of the volume being read, written bare, after a page of another volume.
        #expect(forms([ref("volB", 131, "p. 131"), .text("–"), ref(nil, 149, "149")])
                == [.single, nil, .single])
        // A document after the dash.
        #expect(forms([ref("volB", 131, "p. 131"), .text("–"),
                       .crossReference(target: "volB#d5", targetVolumeId: "volB", children: [.text("Document 5")])])
                == [.single, nil, .single])
        // Text other than a dash between two pages: two single pages.
        #expect(forms([ref("volB", 131, "p. 131"), .text(" and "), ref("volB", 149, "p. 149")])
                == [.single, nil, .single])
        // A dash and more than a dash.
        #expect(forms([ref("volB", 131, "p. 131"), .text("– see also "), ref("volB", 149, "p. 149")])
                == [.single, nil, .single])
    }

    @Test("\"ff.\" inside the reference, after it, after a comma, or in an emphasis sibling")
    func andFollowing() {
        #expect(forms([ref("volB", 865, "pp. 865 ff."), .text(" for the request.")]) == [.andFollowing, nil])
        #expect(forms([ref("volB", 865, "pp. 865"), .text(" ff.")]) == [.andFollowing, nil])
        #expect(forms([ref("volB", 865, "p. 865"), .text(", ff.")]) == [.andFollowing, nil])
        #expect(forms([ref("volB", 865, "pp. 865"), .text(" "),
                       .emphasis(style: .italic, children: [.text("ff")]), .text(".")])
                == [.andFollowing, nil, nil, nil])
        // A word that only begins with the letters, or holds them, is not "ff".
        #expect(forms([ref("volB", 865, "p. 865"), .text(" offers nothing.")]) == [.single, nil])
        #expect(forms([ref("volB", 865, "Jaffa, p. 865"), .text(".")]) == [.single, nil])
        // "ff." later in the sentence does not reach back to the reference.
        #expect(forms([ref("volB", 865, "p. 865"), .text(", and later pages ff.")]) == [.single, nil])
    }

    @Test("A range's form is read before \"ff.\", and a node that is no page reference is a single page")
    func precedenceAndNonPages() {
        #expect(forms([ref("volB", 1, "pp. 1"), .text("–"), ref("volB", 5, "5"), .text(" ff.")])
                == [.rangeStart(end: 5), nil, .rangeEnd(start: 1), nil])
        #expect(PageReferenceForm.form(ofPageReferenceAt: 0, in: [.text("no reference")]) == .single)
        #expect(PageReferenceForm.form(ofPageReferenceAt: 3, in: [.text("out of range")]) == .single)
        let document: FRUSASTNode = .crossReference(target: "volB#d5", targetVolumeId: "volB", children: [])
        #expect(PageReferenceForm.form(ofPageReferenceAt: 0, in: [document, .text("–"), ref("volB", 5, "5")]) == .single)
    }

    @Test("The index's walk carries the form of a page of another volume, and none for a page of its own")
    func theIndexWalkCarriesIt() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSPageForms-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("volA.xml")
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0"><text><body>
        <div type="compilation" xml:id="comp1">
        <div type="document" xml:id="d1" n="1"><pb n="2" xml:id="pg_2"/><head>1. Report</head><p>See \
        <ref target="volB#pg_5">p. 5</ref>, \
        <ref target="volB#pg_7"><hi rend="italic">ibid.</hi>, pp. 7</ref>–<ref target="volB#pg_8">8</ref>, \
        <ref target="volB#pg_5">pp. 5 ff.</ref>, <ref target="#pg_2">p. 2</ref>, \
        <ref target="volA#pg_2">p. 2</ref> and <ref target="volC#pg_4">p. 4</ref>.\
        <note n="1" xml:id="d1fn1">For the letter of July 2, see <ref target="volB#pg_10">p. 10</ref>.</note></p></div>
        </div></body></text></TEI>
        """.write(to: url, atomically: true, encoding: .utf8)
        let rows = try await FRUSDocumentParser().parse(volumeURL: url)
        let document = try #require(rows.first { $0.documentId == "d1" })

        var crossRefs: [CrossReferenceRow] = []
        var personRefs: Set<String> = []
        var listVolumes: Set<String> = []
        var pageRanges: [PageRangeRow] = []
        IndexingPipeline.collectDocumentRefs(from: document.nodes, volumeId: "volA", documentId: "d1",
                                             crossRefs: &crossRefs, personRefs: &personRefs,
                                             personListVolumes: &listVolumes, pageRanges: &pageRanges)
        let collected = crossRefs.map { "\($0.targetVolumeId ?? "-")/\($0.targetDocumentId) \($0.pageForm.map { "\($0)" } ?? "none")" }
        #expect(collected == [
            "volB/pg_5 single",
            "volB/pg_7 rangeStart(end: 8)",
            "volB/pg_8 rangeEnd(start: 7)",
            "volB/pg_5 andFollowing",
            // The volume's own page, bare or with the volume's own prefix: no form.
            "-/pg_2 none",
            "volA/pg_2 none",
            "volC/pg_4 single",
            "volB/pg_10 single",
        ])
        // The note's reference carries the note's hint, as before; the body's carry none.
        #expect(crossRefs.last?.citing?.days == [.init(month: 7, day: 2, year: nil)])
        #expect(crossRefs.dropLast().allSatisfy { $0.citing == nil })
    }
}

// MARK: - CitedPageMapTests (A18b)

/// The bundled page map's decode and lookups (`CitedPageMap`), and rule C over it
/// (`PageSpanResolver.citedDocument(inVolume:page:form:citing:map:)`), the one function the indexer's
/// store pass and `ResolvedEdgeIndexGenerator` call.
@Suite("CitedPageMap — the bundled page map and rule C over it (A18b)")
struct CitedPageMapTests {

    /// volB: Document 1 begins on p. 5; Document 2 begins on p. 7 and is printed on p. 8;
    /// Documents 3 and 4 both begin on p. 10, dated July 1 and July 2 and numbered 3 and 4;
    /// Document 3 begins on p. 12 too (a second copy) and Document 4 on p. 13; volE numbers its
    /// pages per document, and its p. 1 is Documents 1 and 2.
    static let json = """
        {"schemaVersion":1,"generated":"2026-10-21","indexVersion":71,
         "volumes":["volB","volE"],
         "documents":[["d1","d2","d3","d4"],["d1","d2"]],
         "pages":[[[5,0,0],[7,0,1],[8,1,1],[10,0,2,3],[12,0,2],[13,0,3]],[[1,2,0,1]]],
         "facts":[[[2,"3","1945-07-01"],[3,"4","1945-07-02"]],[[0,"1",""],[1,"",""]]]}
        """

    private func map() throws -> CitedPageMap {
        try JSONDecoder().decode(CitedPageMap.self, from: Data(Self.json.utf8))
    }

    @Test("The map decodes to its entries and facts, and encodes back to the same file")
    func decodeAndEncode() throws {
        let map = try map()
        #expect(map.entry(volumeId: "volB", page: 5) == .init(claim: .begins, documentIds: ["d1"]))
        #expect(map.entry(volumeId: "volB", page: 8) == .init(claim: .printed, documentIds: ["d2"]))
        #expect(map.entry(volumeId: "volB", page: 10) == .init(claim: .begins, documentIds: ["d3", "d4"]))
        #expect(map.entry(volumeId: "volE", page: 1) == .init(claim: .numberedPerDocument, documentIds: ["d1", "d2"]))
        #expect(map.entry(volumeId: "volB", page: 9) == nil)
        #expect(map.entry(volumeId: "volZ", page: 5) == nil)
        #expect(map.pageCount == 7)
        #expect(map.entries.map { "\($0.volumeId)/\($0.page)" }
                == ["volB/5", "volB/7", "volB/8", "volB/10", "volB/12", "volB/13", "volE/1"])

        let facts = map.facts(volumeId: "volB", documentIds: ["d3", "d4", "d1"])
        #expect(facts["d3"] == CitedDocumentFacts(printedNumber: "3", day: .init(month: 7, day: 1, year: 1945)))
        #expect(facts["d4"]?.day == .init(month: 7, day: 2, year: 1945))
        #expect(facts["d1"] == nil, "a document on no page that names several carries no facts")
        #expect(map.facts(volumeId: "volE", documentIds: ["d1", "d2"])["d2"]
                == CitedDocumentFacts(printedNumber: nil, day: nil))

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let again = try JSONDecoder().decode(CitedPageMap.self, from: try encoder.encode(map))
        #expect(again == map)
        #expect(CitedPageMap.claim(ofCode: CitedPageMap.claimCode(.printed)) == .printed)
        #expect(CitedPageMap.claim(ofCode: 3) == nil)
    }

    @Test("A map that names an index outside its vocabulary, an unknown claim or ragged rows refuses to decode")
    func malformedMapsRefuse() {
        func decode(_ text: String) throws -> CitedPageMap {
            try JSONDecoder().decode(CitedPageMap.self, from: Data(text.utf8))
        }
        let head = #"{"schemaVersion":1,"generated":"2026-10-21","indexVersion":71,"volumes":["volB"],"documents":[["d1"]],"#
        #expect(throws: CitedPageMapError.malformedPage(volumeId: "volB", row: [5, 0, 1])) {
            _ = try decode(head + #""pages":[[[5,0,1]]],"facts":[[]]}"#)
        }
        #expect(throws: CitedPageMapError.malformedPage(volumeId: "volB", row: [5, 7, 0])) {
            _ = try decode(head + #""pages":[[[5,7,0]]],"facts":[[]]}"#)
        }
        #expect(throws: CitedPageMapError.malformedPage(volumeId: "volB", row: [5, 0])) {
            _ = try decode(head + #""pages":[[[5,0]]],"facts":[[]]}"#)
        }
        #expect(throws: CitedPageMapError.malformedFact(volumeId: "volB", document: 4)) {
            _ = try decode(head + #""pages":[[[5,0,0]]],"facts":[[[4,"1",""]]]}"#)
        }
        #expect(throws: CitedPageMapError.raggedVolumes(volumes: 1, documents: 1, pages: 0, facts: 1)) {
            _ = try decode(head + #""pages":[],"facts":[[]]}"#)
        }
    }

    @Test("Rule C: a single page cites the document on it, and the note settles a page naming several")
    func singlePages() throws {
        let map = try map()
        func cited(_ page: Int, _ form: PageReferenceForm, citing: PageCitationHint? = nil) -> String? {
            PageSpanResolver.citedDocument(inVolume: "volB", page: page, form: form, citing: citing, map: map)
        }
        #expect(cited(5, .single) == "d1")
        #expect(cited(8, .single) == "d2", "a page a document is printed on, having begun earlier")
        // Several: the number, then the day, else the first, as #1509's tie-break decides.
        #expect(cited(10, .single) == "d3")
        #expect(cited(10, .single, citing: .init(documentNumbers: ["4"], days: [])) == "d4")
        #expect(cited(10, .single, citing: .init(documentNumbers: [], days: [.init(month: 7, day: 2, year: nil)])) == "d4")
        #expect(cited(10, .single, citing: .init(documentNumbers: [], days: [.init(month: 7, day: 9, year: nil)])) == "d3",
                "a hint naming neither takes the first")
        // Nothing on the page, or a volume the map does not know.
        #expect(cited(9, .single) == nil)
        #expect(cited(99, .single) == nil)
        #expect(PageSpanResolver.citedDocument(inVolume: "volZ", page: 5, form: .single, citing: nil, map: map) == nil)
        // A volume numbering its pages per document: the number alone names none, so the first.
        #expect(PageSpanResolver.citedDocument(inVolume: "volE", page: 1, form: .single, citing: nil, map: map) == "d1")
        #expect(PageSpanResolver.citedDocument(inVolume: "volE", page: 1, form: .single,
                                               citing: .init(documentNumbers: ["1"], days: []), map: map) == "d1")
    }

    @Test("Rule C: a range cites when both end pages name the same one document; \"ff.\" never does")
    func rangesAndFollowing() throws {
        let map = try map()
        func cited(_ page: Int, _ form: PageReferenceForm) -> String? {
            PageSpanResolver.citedDocument(inVolume: "volB", page: page, form: form, citing: nil, map: map)
        }
        // pp. 7–8 lie within Document 2: both rows resolve.
        #expect(cited(7, .rangeStart(end: 8)) == "d2")
        #expect(cited(8, .rangeEnd(start: 7)) == "d2")
        // pp. 5–7: two documents.
        #expect(cited(5, .rangeStart(end: 7)) == nil)
        #expect(cited(7, .rangeEnd(start: 5)) == nil)
        // pp. 10–12: p. 10 names two documents, though p. 12 names one of them alone.
        #expect(cited(10, .rangeStart(end: 12)) == nil)
        #expect(cited(12, .rangeEnd(start: 10)) == nil)
        // pp. 5–9: an end with no entry.
        #expect(cited(5, .rangeStart(end: 9)) == nil)
        #expect(cited(9, .rangeEnd(start: 5)) == nil)
        // "ff." stays on the volume, whatever the page names.
        #expect(cited(5, .andFollowing) == nil)
        #expect(cited(10, .andFollowing) == nil)
    }

    /// The shipped `cited-page-map.json`: from the repository in the package, from the app's bundle
    /// in Xcode, through the store the indexer reads it from.
    private func shippedMap() throws -> CitedPageMap {
        #if SWIFT_PACKAGE
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/Resources/cited-page-map.json")
        return try JSONDecoder().decode(CitedPageMap.self, from: Data(contentsOf: url))
        #else
        return try #require(CitedPageMapStore.shared, """
            cited-page-map.json must decode from the app bundle. If it was just regenerated it needs \
            `xcodegen generate` to be enrolled — followed by \
            `git checkout -- FRUSExplorer.xcodeproj/xcshareddata/xcschemes/`.
            """)
        #endif
    }

    @Test("The shipped map is the current version's, covers the pages the corpus cites, and names the Atlantic Charter")
    func theShippedMap() throws {
        let map = try shippedMap()
        // Regenerated with the parse it was read from: a map from an older parse could name a
        // document the device's own page rows no longer begin a page with.
        #expect(map.indexVersion == IndexingPipeline.currentDateIndexVersion)
        #expect(map.schemaVersion == 1)
        // Generated 2026-10-21 at corpus `6170e4b32` from a full index of the 553 catalogue volumes:
        // an entry for every page a single-page reference cites and for both ends of each range
        // within one document — 16,364 pages in 380 volumes, naming 18,832 documents, 3,938 of the
        // pages naming several, with 8,543 documents' facts.
        #expect(map.volumes.count == 380)
        #expect(map.pageCount == 16_364)
        #expect(map.documents.reduce(0) { $0 + $1.count } == 18_832)
        #expect(map.facts.reduce(0) { $0 + $1.count } == 8_543)
        #expect(map.volumes == map.volumes.sorted())
        for row in map.documents { #expect(row == row.sorted()) }
        for rows in map.pages { #expect(rows.map { $0[0] } == rows.map { $0[0] }.sorted()) }

        // The Atlantic Charter: p. 367 of 1941 vol. I is where d372 begins, and it names it alone.
        #expect(map.entry(volumeId: "frus1941v01", page: 367) == .init(claim: .begins, documentIds: ["d372"]))
        #expect(PageSpanResolver.citedDocument(inVolume: "frus1941v01", page: 367, form: .single,
                                               citing: nil, map: map) == "d372")
        // The Potsdam protocol runs from p. 1478 and the communiqué from p. 1499 of 1945 Berlin
        // vol. II: a range within the communiqué cites it, one spanning both cites neither.
        #expect(map.entry(volumeId: "frus1945Berlinv02", page: 1478)?.documentIds == ["d1383"])
        #expect(map.entry(volumeId: "frus1945Berlinv02", page: 1499) == .init(claim: .begins, documentIds: ["d1384"]))
        #expect(map.entry(volumeId: "frus1945Berlinv02", page: 1500) == .init(claim: .printed, documentIds: ["d1384"]))
        #expect(PageSpanResolver.citedDocument(inVolume: "frus1945Berlinv02", page: 1499,
                                               form: .rangeStart(end: 1514), citing: nil, map: map) == "d1384")
        #expect(PageSpanResolver.citedDocument(inVolume: "frus1945Berlinv02", page: 1478,
                                               form: .rangeStart(end: 1499), citing: nil, map: map) == nil)
        // A page naming two documents carries both documents' facts: p. 716, Documents 816 and
        // 817, both of July 25, 1945, so a note naming the number decides and the day does not.
        #expect(map.entry(volumeId: "frus1945Berlinv02", page: 716)?.documentIds == ["d816", "d817"])
        let facts = map.facts(volumeId: "frus1945Berlinv02", documentIds: ["d816", "d817"])
        #expect(facts["816"] == nil)
        #expect(facts["d816"] == CitedDocumentFacts(printedNumber: "816", day: .init(month: 7, day: 25, year: 1945)))
        #expect(facts["d817"]?.printedNumber == "817")
        #expect(PageSpanResolver.citedDocument(inVolume: "frus1945Berlinv02", page: 716, form: .single,
                                               citing: .init(documentNumbers: ["817"], days: []), map: map) == "d817")
        #expect(PageSpanResolver.citedDocument(inVolume: "frus1945Berlinv02", page: 716, form: .single,
                                               citing: .init(documentNumbers: [], days: [.init(month: 7, day: 25, year: nil)]),
                                               map: map) == "d816")
        // No volume that numbers its pages per document is cited by page from another volume.
        #expect(map.entries.allSatisfy { $0.entry.claim != .numberedPerDocument })
    }
}
