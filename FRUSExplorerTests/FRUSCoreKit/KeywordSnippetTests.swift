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
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif
// The package builds FTS5Store as a module of its own; Xcode compiles it into the app.
#if canImport(FTS5Store)
import FTS5Store
#endif

/// A keyword result's snippet (A10b, plan of record decision 74): the window starts about 30
/// characters before the first match in the document's prose, after its own heading, source note
/// and dateline, and keeps 2,000 after it.
///
/// Until A10b the window was cut around the body's first match, 1,000 characters on each side, so a
/// row's two default lines mostly drew its own heading and source note again: measured over twelve
/// searches of a full index (`Planning/Keyword-Snippet-Assessment-2026-10-20.md`), the bold word was
/// drawn in 28.7% of the top 100 rows on an iPhone 17. The strip itself is `ProseSnippetTests`'.
///
/// Version history:
///   1.0 — A10b: initial implementation
///   1.1 — #1760: the window starts at the prose's first word of the rarest term it holds, ranked by the index
///          (`SearchService.keywordAnchorTiers(_:)`), and a question's terms are read as the tokenizer reads them
@Suite("A keyword result's snippet")
struct KeywordSnippetTests {

    /// The query words' Porter stems, as `SearchService` makes them.
    private static func stems(_ words: String...) -> [String] {
        words.map { PorterStemmer.stem($0.lowercased()) }
    }

    /// Stored: `frus1952-54v07p2` d567, cut short after the opening. "Berlin" is in its heading,
    /// its dateline and its prose.
    private enum Numbered {
        static let header = "No. 567 The Director of the Berlin Element, HICOG (Lyon) to the Office of the United "
            + "States High Commissioner for Germany, at Bonn"
        static let dateline = "Berlin, February 9, 1953—5 p.m."
        static let sourceNote = "762B.00/2–953: Telegram"
        static let body = "762B.00/2–953: Telegram " + header + " Repeated to London, Paris, Moscow, and Washington; "
            + "the source text is the copy in Department of State files. secret Berlin, February 9, 1953—5 p.m. "
            + "1269. Re Bonn’s 3463 to Department repeated Berlin 428, London 690, Paris 942, Moscow 190."
    }

    /// Stored: `frus1951v06p2` d94, cut short. Its classification marking sits before its dateline.
    private enum Classified {
        static let header = "The Chargé in Thailand (Turner) to the Secretary of State"
        static let dateline = "Bangkok, November 30, 1951—3 p. m."
        static let sourceNote = "792.00/11–3051: Telegram"
        static let prose = "Insufficient info yet offer firm analysis Nov 29 coup. Fol based solely on "
            + "preliminary observations."
        static let body = "792.00/11–3051: Telegram " + header + " confidential " + dateline + " 1233. " + prose
    }

    private static func numbered(_ word: String) -> String? {
        SearchService.keywordSnippet(body: Numbered.body, header: Numbered.header, dateline: Numbered.dateline,
                                     sourceNote: Numbered.sourceNote, stemmedTerms: stems(word))
    }

    private static func classified(_ word: String) -> String? {
        SearchService.keywordSnippet(body: Classified.body, header: Classified.header, dateline: Classified.dateline,
                                     sourceNote: Classified.sourceNote, stemmedTerms: stems(word))
    }

    // MARK: - The window

    @Test("The bold word is the prose's, and the window opens on a whole word about 30 characters before it")
    func theWindowStartsAtTheProsesMatch() {
        // "Berlin" in the heading and the dateline is passed over for the prose's. Thirty characters
        // before it fall on the "s" of "Bonn’s", whose apostrophe is not a letter: the window goes back
        // to the space, where a lead snapped across letters alone opened "… s 3463".
        #expect(Self.numbered("Berlin")
                == "… Bonn’s 3463 to Department repeated <b>Berlin</b> 428, London 690, Paris 942, Moscow 190.")
        #expect(Self.classified("coup")
                == "… yet offer firm analysis Nov 29 <b>coup</b>. Fol based solely on preliminary observations.")
    }

    @Test("A window that starts where the prose does opens with no ellipsis")
    func noEllipsisAtTheProsesStart() {
        // A10's fixture, d7 of the spoken-row volume, as the index stores it: fewer than 30 characters
        // of prose come before the word.
        let snippet = SearchService.keywordSnippet(
            body: "UI Test Spoken Document Source: UI test fixture, Spoken File. Secret; Nodis. Washington, May 4, "
                + "1962 Spoken-row fixture, xylograph document.",
            header: "UI Test Spoken Document", dateline: "Washington, May 4, 1962",
            sourceNote: "Source: UI test fixture, Spoken File. Secret; Nodis.", stemmedTerms: Self.stems("xylograph"))
        #expect(snippet == "Spoken-row fixture, <b>xylograph</b> document.")
        #expect(Self.classified("insufficient")
                == "<b>Insufficient</b> info yet offer firm analysis Nov 29 coup. Fol based solely on preliminary observations.")
    }

    @Test("The window keeps 2,000 characters after the match, to the end of a word, and marks the cut")
    func twoThousandAfter() throws {
        #expect(SearchService.keywordLead == 30 && SearchService.keywordTrail == 2_000)
        let body = "Header The negotiators met to discuss the treaty" + String(repeating: " word", count: 1_000)
        let snippet = try #require(SearchService.keywordSnippet(
            body: body, header: "Header", dateline: nil, sourceNote: nil, stemmedTerms: Self.stems("treaty")))
        #expect(snippet.hasPrefix("… negotiators met to discuss the <b>treaty</b> word word"))
        let after = try #require(snippet.components(separatedBy: "</b>").last)
        #expect(after.hasSuffix(" word …"), "cut at the end of a word, and marked")
        #expect((2_000...2_003).contains(after.count - 2), "\(after.count - 2) characters after the match")
    }

    @Test("A window never opens before where it may start, and finds no match before it")
    func theWindowsFloor() {
        #expect(SearchService.makeContextSnippet(body: "aaa bbb ccc target", stemmedTerms: ["target"], from: 4)
                == "bbb ccc <b>target</b>")
        #expect(SearchService.makeContextSnippet(body: "aaa bbb ccc target", stemmedTerms: ["target"])
                == "aaa bbb ccc <b>target</b>")
        #expect(SearchService.makeContextSnippet(body: "target aaa bbb", stemmedTerms: ["target"], from: 7) == nil)
        // A short lead and trail: back to a space ahead, on to the end of a word behind.
        #expect(SearchService.makeContextSnippet(body: "one two target three", stemmedTerms: ["target"],
                                                 before: 4, after: 3)
                == "… two <b>target</b> three")
    }

    // MARK: - Rows with no match in the prose

    @Test("A row whose only match is in its heading, source note or dateline shows its opening prose, unmarked")
    func aMatchOnlyInTheFieldsShowsTheOpeningProse() {
        // "Thailand" is in the heading, which the row draws above the snippet; "confidential" is in the
        // classification line the strip takes with the dateline, which no part of a search row draws.
        #expect(Self.classified("Thailand") == Classified.prose)
        #expect(Self.classified("confidential") == Classified.prose)
        // A long opening is cut as a window is, 2,000 characters on.
        let long = SearchService.keywordSnippet(
            body: "Telegram From Bonn" + String(repeating: " prose", count: 500), header: "Telegram From Bonn",
            dateline: nil, sourceNote: nil, stemmedTerms: Self.stems("Bonn"))
        #expect(long?.hasPrefix("prose prose") == true)
        #expect(long?.hasSuffix(" prose …") == true)
        #expect(long.map { (2_000...2_006).contains($0.count) } == true, "\(long?.count ?? 0) characters")
    }

    @Test("A row with no match in its body has no window, and a body that is only its fields is read whole")
    func noMatchAndAllBoilerplate() {
        #expect(Self.numbered("zanzibar") == nil, "the caller shows the heading and dateline again")
        #expect(SearchService.keywordSnippet(body: "", header: "H", dateline: nil, sourceNote: nil,
                                             stemmedTerms: Self.stems("treaty")) == nil)
        #expect(SearchService.keywordSnippet(body: Numbered.body, header: Numbered.header, dateline: nil,
                                             sourceNote: nil, stemmedTerms: []) == nil)
        // An editorial note that is only its heading has no prose to start from: the body is the text.
        #expect(SearchService.keywordSnippet(body: "1. Editorial Note", header: "1. Editorial Note", dateline: nil,
                                             sourceNote: nil, stemmedTerms: Self.stems("editorial"))
                == "1. <b>Editorial</b> Note")
    }

    // MARK: - Through the service

    /// The service's own loop over a page of rows, where each row's snippet is made: one of each kind.
    @Test("The search service gives each row its window, its opening prose or its heading and dateline again")
    func theServiceGivesEachKind() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSKeywordSnippet-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let dbURL = dir.appendingPathComponent("t.sqlite")
        let fts5 = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(fts5Store: fts5, databaseURL: dbURL, volumesDirectory: dir,
                                            concurrencyLimit: 1)
        let service = SearchService(fts5Store: fts5, pipeline: pipeline)
        func row(_ id: String, header: String, dateline: String?, sourceNote: String?, body: String) -> IndexedSearchRow {
            IndexedSearchRow(documentId: id, volumeId: "frus1952-54v07p2", documentNumber: nil, header: header,
                             dateline: dateline, sourceNote: sourceNote, bodyText: body, subjectTagIds: nil,
                             userTagIds: nil, isEditorialNote: false, isFrontMatter: false, dateISO: nil, score: -3)
        }
        let rows = [
            row("d567", header: Numbered.header, dateline: Numbered.dateline, sourceNote: Numbered.sourceNote,
                body: Numbered.body),
            row("d1", header: "Memorandum by the Berlin Element", dateline: "Washington, June 1, 1953", sourceNote: nil,
                body: "Memorandum by the Berlin Element Washington, June 1, 1953 The talks went on."),
            row("d2", header: "Minutes", dateline: "Washington, October 22, 1962", sourceNote: nil,
                body: "The President opened the meeting."),
        ]
        let results = try await service.results(from: rows, parameters: SearchParameters(keywords: "Berlin"))
        #expect(results.map(\.snippet) == [
            "… Bonn’s 3463 to Department repeated <b>Berlin</b> 428, London 690, Paris 942, Moscow 190.",
            "The talks went on.",
            "Minutes · Washington, October 22, 1962",
        ])
    }

    // MARK: - The word the window starts at (#1760)

    /// A question typed as keywords, *Why did the Marshall Plan happen?*: every word is the query's, and
    /// A10b's window started at the prose's first word of any, *the*, in nearly every row.
    private enum Question {
        static let header = "Memorandum by the Secretary of State"
        static let prose = "Under the program the Secretary explained why the plan was needed and what would happen "
            + "if Congress refused. Marshall said that the plan would succeed."
        /// The query's stems as `SearchService.keywordAnchorTiers(_:)` gives them over an index of FRUS:
        /// rarest first, and none of *why*, *did* and *the*, which say nothing on their own.
        static let tiers = [["marshal"], ["happen"], ["plan"]]
    }

    private static func question(_ tiers: [[String]], prose: String = Question.prose) -> String? {
        SearchService.keywordSnippet(body: Question.header + " " + prose, header: Question.header, dateline: nil,
                                     sourceNote: nil, stemTiers: tiers)
    }

    @Test("The window starts at the prose's first word of the rarest term it holds, not the first word of any")
    func theWindowStartsAtTheRarestTerm() throws {
        let ranked = try #require(Self.question(Question.tiers))
        #expect(ranked.hasPrefix("… would happen if Congress refused. <b>Marshall</b> said that the plan"), "\(ranked)")
        // A10b's rule, every stem of the question in one tier: the first word of any, which is "the".
        let unranked = try #require(Self.question([["why", "did", "the", "marshal", "plan", "happen"]]))
        #expect(unranked.hasPrefix("Under <b>the</b> program"), "\(unranked)")
    }

    @Test("A rarer term the prose does not hold gives way to the next, and a tier's words are taken in the prose's order")
    func aMissingTermGivesWay() throws {
        // "zanzibar" is held by no word here: the next tier's first word is the window's.
        #expect(try #require(Self.question([["zanzibar"], ["plan"], ["the"]]))
                    .hasPrefix("… the Secretary explained why the <b>plan</b>"))
        // Two words held by as many documents: the first in the prose.
        #expect(try #require(Self.question([["happen", "plan"], ["the"]]))
                    .hasPrefix("… the Secretary explained why the <b>plan</b>"))
        // A rarer word held only in the heading, which the row draws, gives way to the prose's next.
        let headingOnly = try #require(Self.question([["secretari"], ["plan"]], prose: "The plan was ready."))
        #expect(headingOnly == "The <b>plan</b> was ready.")
        // And a prose holding none of the query's telling words opens unmarked, as a row whose words are
        // only in its own fields does: the function words set aside are no anchor of their own.
        #expect(Self.question([["secretari"], ["plan"]], prose: "The program was ready.") == "The program was ready.")
    }

    @Test("The tiered scan matches the first word of the best tier wherever it lies")
    func theTieredScanReachesTheEnd() {
        let body = String(repeating: "the plan and the program ", count: 400) + "Marshall at last."
        let snippet = SearchService.makeContextSnippet(body: body, stemTiers: [["marshal"], ["plan"], ["the"]],
                                                       before: 8, after: 10)
        #expect(snippet == "… program <b>Marshall</b> at last.")
        // With no word of the best tier, the first word of the next.
        #expect(SearchService.makeContextSnippet(body: "the plan", stemTiers: [["marshal"], ["plan"], ["the"]])
                == "the <b>plan</b>")
        #expect(SearchService.makeContextSnippet(body: "the plan", stemTiers: [["marshal"], []]) == nil)
    }

    /// Ranked over a real index: three documents, each holding *the*, two *plan* and one *Marshall*.
    @Test("The search service ranks a query's stems by how many of the index's documents hold each")
    func theServiceRanksByDocumentFrequency() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSKeywordAnchor-\(UUID().uuidString)", isDirectory: true)
        let volumes = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let paragraphs = [
            "Under the program the Secretary explained the plan. Marshall said that it would succeed.",
            "The plan was debated in the Cabinet.",
            "The Embassy reported the conversation.",
        ]
        var xml = "<?xml version=\"1.0\"?>\n<TEI><text><body>\n"
        for (index, paragraph) in paragraphs.enumerated() {
            xml += "<div type=\"document\" xml:id=\"d\(index + 1)\"><head>\(index + 1). Item</head><p>\(paragraph)</p></div>\n"
        }
        xml += "</body></text></TEI>"
        try Data(xml.utf8).write(to: volumes.appendingPathComponent("vol1.xml"))
        let dbURL = dir.appendingPathComponent("t.sqlite")
        let fts5 = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(fts5Store: fts5, databaseURL: dbURL, volumesDirectory: volumes,
                                            concurrencyLimit: 1)
        try await pipeline.indexVolume("vol1")
        let service = SearchService(fts5Store: fts5, pipeline: pipeline)

        // Rarest first, and "the" set aside, which says nothing on its own.
        #expect(await service.keywordAnchorTiers(Self.stems("the", "Marshall", "plan")) == [["marshal"], ["plan"]])
        #expect(await service.keywordAnchorTiers(Self.stems("plan", "Marshall")) == [["marshal"], ["plan"]])
        // A word no document holds is held as rare as any.
        #expect(await service.keywordAnchorTiers(Self.stems("plan", "xylograph")) == [["xylograph"], ["plan"]])
        // A query of function words alone is ranked as they are: no document here holds "of".
        #expect(await service.keywordAnchorTiers(Self.stems("the", "of")) == [["of"], ["the"]])
        // One word, or one telling word beside function words, is one tier, and asks the index nothing.
        #expect(await service.keywordAnchorTiers(Self.stems("plan")) == [["plan"]])
        #expect(await service.keywordAnchorTiers(Self.stems("why", "did", "the", "Marshall")) == [["marshal"]])
        #expect(await service.keywordAnchorTiers([]).isEmpty)

        // The row's snippet, through the search the reader typed.
        let results = try await service.search(parameters: SearchParameters(keywords: "Why did the Marshall Plan happen?"),
                                               limit: 10)
        #expect(results.isEmpty, "no document holds every word of the question")
        let found = try await service.search(parameters: SearchParameters(keywords: "the Marshall plan?"), limit: 10)
        let snippet = try #require(found.first?.snippet)
        #expect(snippet.contains("<b>Marshall</b>"), "\(snippet)")
    }

    // MARK: - Terms as the tokenizer reads them (#1760)

    @Test("A question's terms are read as the tokenizer reads them, without the marks at either end")
    func termsAreReadAsTheTokenizerReadsThem() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSKeywordTerms-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let dbURL = dir.appendingPathComponent("t.sqlite")
        let fts5 = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(fts5Store: fts5, databaseURL: dbURL, volumesDirectory: dir,
                                            concurrencyLimit: 1)
        let service = SearchService(fts5Store: fts5, pipeline: pipeline)

        let question = SearchParameters(keywords: "Why did the Marshall Plan happen?")
        #expect(await service.positiveTerms(from: question) == ["Why", "did", "the", "Marshall", "Plan", "happen"])
        #expect(await service.positiveTerms(from: SearchParameters(keywords: "\"cold war,\" (Berlin) détente…"))
                == ["cold", "war", "Berlin", "détente"])
        // An `=` word keeps its mark, which its stem has never matched (its match is the literal word).
        #expect(await service.positiveTerms(from: SearchParameters(keywords: "=containment")) == ["=containment"])
        // The expression the Query Inspector shows quotes `happen`, which the search reads, not `happen?`.
        let expression = try #require(try await service.matchExpressions(for: question).corpus)
        #expect(expression == "\"why\" AND \"did\" AND \"the\" AND \"marshall\" AND \"plan\" AND \"happen\"")
    }
}
