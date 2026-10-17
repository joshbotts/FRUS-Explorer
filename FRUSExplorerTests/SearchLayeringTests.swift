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

// MARK: - Fixtures

/// A row, keyed `vol/<id>`, with a snippet that names it and the scores given.
private func row(_ id: String, bm25: Double = -1, semantic: Double? = nil,
                 volume: String = "vol") -> SearchResult {
    SearchResult(documentId: id, volumeId: volume, header: "Header \(id)", snippet: "snippet <b>\(id)</b>",
                 bm25Score: bm25, semanticScore: semantic)
}

/// A held base, with whatever the test does not name left at a plain value.
private func base(direction: SearchLayerDirection = .wordsInMatches,
                  kind: PinnedResultBase.Kind = .meaning,
                  query: String = "how did the embassy report",
                  rows: [SearchResult],
                  members: [SearchResult]? = nil,
                  notDownloaded: Int = 0,
                  route: ExecutedSearchRoute = .meaning,
                  fetchLimit: Int = 100,
                  total: Int? = nil) -> PinnedResultBase {
    let shown = members ?? rows
    return PinnedResultBase(
        direction: direction, kind: kind, query: query, rows: rows, members: shown,
        hiddenByChecklist: rows.count - shown.count, notDownloaded: notDownloaded,
        route: route, fetchLimit: fetchLimit, totalMatchCount: total, renderedExpression: nil,
        disclosure: nil, beyondLibraryHits: [], userTagCountScope: nil, historyAnchor: nil,
        completedSearchAnchor: nil, filterSignature: "")
}

/// `count` rows `d1`… with no score, as a keyword list's are.
private func keywordRows(_ count: Int) -> [SearchResult] {
    (1...count).map { row("d\($0)", bm25: -Double(count - $0)) }
}

// MARK: - SearchLayeringTests

/// Search Within These Results' pure parts (#1577 lane 4): the held base's sentences and record, the
/// composer that orders a layer and gates a search, the three-way document gate, and the sentences
/// `ResultSetScope` and the facet panel owe a layer. None needs a search service, a view or a device.
///
/// Version history:
///   1.0 — #1577 lane 4: initial implementation
@Suite("Search within results: the held base, the composer and the gate")
struct SearchLayeringTests {

    // MARK: The direction

    @Test("A layer starts over a list from one engine, runs the other, and is never stacked")
    func directionFollowsTheRoute() {
        #expect(SearchLayerDirection.starting(over: .meaning) == .wordsInMatches)
        #expect(SearchLayerDirection.starting(over: .keywords) == .rankByMeaning)
        #expect(SearchLayerDirection.starting(over: .wordsInMatches(base: 100)) == nil)
        #expect(SearchLayerDirection.starting(over: .rankedByMeaning(unranked: 0)) == nil)
        #expect(SearchLayerDirection.wordsInMatches.fieldEngine == .keywords)
        #expect(SearchLayerDirection.wordsInMatches.baseEngine == .meaning)
        #expect(SearchLayerDirection.rankByMeaning.fieldEngine == .meaning)
        #expect(SearchLayerDirection.rankByMeaning.baseEngine == .keywords)
        #expect(ExecutedSearchRoute.wordsInMatches(base: 1).isLayer)
        #expect(ExecutedSearchRoute.rankedByMeaning(unranked: 3).isLayer)
        #expect(!ExecutedSearchRoute.keywords.isLayer)
        #expect(!ExecutedSearchRoute.meaning.isLayer)
    }

    @Test("Each way in is titled by what it will do, and the field says what to type")
    func titlesAndPrompts() {
        #expect(SearchLayerDirection.wordsInMatches.startTitle == "Find Words in These Matches")
        #expect(SearchLayerDirection.rankByMeaning.startTitle == "Rank These Results by a Question")
        #expect(SearchLayerDirection.wordsInMatches.fieldPrompt == "Words to find in these matches…")
        #expect(SearchLayerDirection.rankByMeaning.fieldPrompt == "A question to rank these results by…")
        #expect(SearchLayerCopy.closestToAQuestion == "Closest to a Question…")
    }

    // MARK: The row that names the base

    @Test("A Meaning base is named by its size and its question")
    func meaningBaseSentences() {
        let held = base(rows: (1...100).map { row("d\($0)", semantic: 0.5) })
        #expect(held.rowDescription == "Within 100 closest matches to “how did the embassy report”")
        #expect(held.accessibilityLabel == "Searching within 100 closest matches to “how did the embassy report”")
        #expect(held.backTitle == "Back to the 100 Matches")
        #expect(held.leftOutDescription == nil)
        #expect(!held.wasCut, "a Meaning list is never cut at a ceiling, however many rows it has")
        let one = base(rows: [row("d1", semantic: 0.5)])
        #expect(one.rowDescription == "Within the closest match to “how did the embassy report”")
        #expect(one.backTitle == "Back to the Closest Match")
    }

    @Test("A keyword base says where its fetch stopped, with and without a total")
    func keywordBaseSentences() {
        let whole = base(direction: .rankByMeaning, kind: .keywords, query: "offset agreement",
                         rows: keywordRows(212), route: .keywords, fetchLimit: 1_000, total: 212)
        #expect(whole.rowDescription == "Within 212 results for “offset agreement”")
        #expect(whole.backTitle == "Back to the 212 Results")
        #expect(!whole.wasCut)
        let cut = base(direction: .rankByMeaning, kind: .keywords, query: "negotiations",
                       rows: keywordRows(1_000), route: .keywords, fetchLimit: 1_000, total: 35_275)
        #expect(cut.wasCut)
        #expect(cut.rowDescription == "Within the first 1,000 of 35,275 results for “negotiations”")
        let cutUnknown = base(direction: .rankByMeaning, kind: .keywords, query: "negotiations",
                              rows: keywordRows(1_000), route: .keywords, fetchLimit: 1_000, total: nil)
        #expect(cutUnknown.rowDescription == "Within the first 1,000 results for “negotiations”")
        // A total above what loaded is a cut too, below the ceiling (a filter applied after the fetch).
        let short = base(direction: .rankByMeaning, kind: .keywords, query: "x",
                         rows: keywordRows(30), route: .keywords, fetchLimit: 1_000, total: 40)
        #expect(short.wasCut)
        let one = base(direction: .rankByMeaning, kind: .keywords, query: "x",
                       rows: keywordRows(1), route: .keywords, fetchLimit: 1_000, total: 1)
        #expect(one.rowDescription == "Within 1 result for “x”")
        #expect(one.backTitle == "Back to the Result")
    }

    @Test("A browse is named by its filter, or as a browse when the filter has no name")
    func browseBaseSentences() {
        let named = base(direction: .rankByMeaning, kind: .browse(name: "Aerial reconnaissance"), query: "",
                         rows: keywordRows(1_976), route: .keywords, fetchLimit: 7_500, total: 1_976)
        #expect(named.rowDescription == "Within 1,976 results for Aerial reconnaissance")
        let unnamed = base(direction: .rankByMeaning, kind: .browse(name: nil), query: "",
                           rows: keywordRows(12), route: .keywords, fetchLimit: 7_500, total: 12)
        #expect(unnamed.rowDescription == "Within 12 results of your browse")
        let cut = base(direction: .rankByMeaning, kind: .browse(name: "War"), query: "",
                       rows: keywordRows(7_500), route: .keywords, fetchLimit: 7_500, total: 58_480)
        #expect(cut.rowDescription == "Within the first 7,500 of 58,480 results for War")
    }

    /// The members are what the layer searches; rows Checklist Mode hid, and Meaning hits with no row, are not.
    @Test("What the base leaves out is said, in the singular for one")
    func leftOutIsSaid() {
        let rows = keywordRows(212)
        let hiddenOne = base(direction: .rankByMeaning, kind: .keywords, query: "x", rows: rows,
                             members: Array(rows.dropFirst()), route: .keywords, fetchLimit: 1_000, total: 212)
        #expect(hiddenOne.rowDescription == "Within 211 results for “x”", "the members are what the layer runs in")
        #expect(hiddenOne.leftOutDescription == "1 result hidden as reviewed is not included.")
        let both = base(rows: (1...100).map { row("d\($0)", semantic: 0.5) },
                        members: (3...100).map { row("d\($0)", semantic: 0.5) }, notDownloaded: 3)
        #expect(both.leftOutDescription == """
            2 results hidden as reviewed are not included. 3 matches in volumes you have not downloaded are not included.
            """)
        // A cut base counts its fetch in "the first", whatever Checklist Mode hid among it.
        let cut = base(direction: .rankByMeaning, kind: .keywords, query: "n", rows: keywordRows(1_000),
                       members: Array(keywordRows(1_000).dropFirst(10)), route: .keywords,
                       fetchLimit: 1_000, total: 35_275)
        #expect(cut.rowDescription == "Within the first 1,000 of 35,275 results for “n”")
        #expect(cut.leftOutDescription == "10 results hidden as reviewed are not included.")
    }

    // MARK: The record

    @Test("A list found by a phrase or a prefix alone is named by them")
    func describedWordsOfARestoredList() {
        #expect(PinnedResultBase.describedWords(phrase: "wheat shipments", prefix: nil) == "\"wheat shipments\"")
        #expect(PinnedResultBase.describedWords(phrase: nil, prefix: "embarg") == "embarg*")
        #expect(PinnedResultBase.describedWords(phrase: " wheat ", prefix: "embarg") == "\"wheat\" embarg*")
        #expect(PinnedResultBase.describedWords(phrase: "", prefix: " ") == nil)
        #expect(PinnedResultBase.describedWords(phrase: nil, prefix: nil) == nil)
        var described = base(kind: .keywords, query: "", rows: keywordRows(12), route: .keywords)
        described.describedQuery = "\"wheat shipments\""
        #expect(described.rowDescription == "Within 12 results for “\"wheat shipments\"”")
        #expect(described.captureLabel == "“\"wheat shipments\"”")
        #expect(described.signaturePart == "base=keywords:12:%22wheat%20shipments%22")
        #expect(described.query.isEmpty, "the field gets back what it held")
    }

    @Test("A held list takes the tags the rows on screen were given, and nothing else of them")
    func aHeldListTakesTheShownTags() throws {
        let tag = UUID()
        let rows = keywordRows(4)
        var held = base(kind: .keywords, query: "containment", rows: rows, members: Array(rows.prefix(3)),
                        route: .keywords)
        let shown = [rows[1].replacingUserTagIds([tag]), row("elsewhere")]
        held.takeUserTags(from: shown)
        #expect(held.rows.map(\.userTagIds) == [[], [tag.uuidString], [], []])
        #expect(held.members.map(\.userTagIds) == [[], [tag.uuidString], []])
        #expect(held.rows.map(\.id) == rows.map(\.id) && held.members.count == 3, "no row is added or lost")
        #expect(held.rows[1].snippet == rows[1].snippet, "the held row keeps its own snippet")
    }

    @Test("The base's record part is kind, size and percent-encoded words")
    func signaturePartEncodes() {
        let held = base(query: "a;b=c:d “é”", rows: [row("d1", semantic: 0.5), row("d2", semantic: 0.4)])
        #expect(held.signaturePart == "base=meaning:2:a%3Bb%3Dc%3Ad%20%E2%80%9C%C3%A9%E2%80%9D")
        #expect(held.renderedExpressionSuffix == "; " + held.signaturePart)
        let browse = base(direction: .rankByMeaning, kind: .browse(name: "Aerial reconnaissance"), query: "",
                          rows: keywordRows(3), route: .keywords, fetchLimit: 7_500)
        #expect(browse.signaturePart == "base=browse:3:Aerial%20reconnaissance")
        #expect(held.captureLabel == "“a;b=c:d “é””")
        #expect(browse.captureLabel == "Aerial reconnaissance")
    }

    @Test("A layer signs as its engine does, with its base last; describe names the base")
    func layeredSignatureRoundTrips() throws {
        let gated = SearchParameters(keywords: "SAVAK", documentIds: ["vol/d1", "vol/d2"])
        let held = base(query: "how did the embassy", rows: [row("d1", semantic: 0.5), row("d2", semantic: 0.4)])

        let words = try #require(SearchScopeSignature.layered(nil, parameters: gated, base: held))
        #expect(words == SearchScopeSignature.signature(for: gated) + ";base=meaning:2:how%20did%20the%20embassy")
        let wordsProse = try #require(SearchScopeSignature.describe(words))
        #expect(wordsProse.contains("2 documents"), "the gate's own part is still read")
        #expect(wordsProse.last == "inside the closest matches of a Meaning search for “how did the embassy” (2 documents)")

        let keywordBase = base(direction: .rankByMeaning, kind: .keywords, query: "offset agreement",
                               rows: keywordRows(212), route: .keywords, fetchLimit: 1_000)
        let ranked = try #require(SearchScopeSignature.layered(
            SearchScopeSignature.semanticSignature(for: gated), parameters: gated, base: keywordBase))
        #expect(ranked.hasPrefix("route=semantic"), "an earlier build must still read a Meaning row as one")
        let rankedProse = try #require(SearchScopeSignature.describe(ranked))
        #expect(rankedProse.contains("ranked inside a set of 2 documents, not across the whole series"))
        #expect(rankedProse.last == "inside the results of a keyword search for “offset agreement” (212 documents)")

        // Outside a base nothing changes, so every row written before the change still compares equal.
        #expect(SearchScopeSignature.layered(nil, parameters: gated, base: nil) == nil)
        #expect(SearchScopeSignature.layered("route=semantic;engine=on-device", parameters: gated, base: nil)
                == "route=semantic;engine=on-device")
        // A part this build cannot read is left out, not guessed at.
        let malformed = SearchScopeSignature.signature(for: gated) + ";base=meaning:many:x"
        #expect(SearchScopeSignature.describe(malformed)?.contains { $0.hasPrefix("inside the") } == false)
        let browse = SearchScopeSignature.signature(for: gated) + ";base=browse:3:Aerial%20reconnaissance"
        #expect(SearchScopeSignature.describe(browse)?.last
                == "inside the results of a browse of Aerial reconnaissance (3 documents)")
        let unnamed = SearchScopeSignature.signature(for: gated) + ";base=browse:1:"
        #expect(SearchScopeSignature.describe(unnamed)?.last == "inside the results of a browse (1 document)")
    }

    // MARK: The composer

    /// Tie fixtures are named so that id order alone does not pass: the base is d9 … d1, closest first, and the keyword
    /// search returns its rows in another order again.
    @Test("Words found in a Meaning list keep its order and its scores, and their own snippets")
    func wordsInMatchesKeepTheBaseOrder() {
        let members = [row("d9", semantic: 0.9), row("d5", semantic: 0.8), row("d7", semantic: 0.8),
                       row("d1", semantic: 0.7), row("d3", semantic: 0.6)]
        let held = base(rows: members)
        let found = [row("d1", bm25: -9), row("d7", bm25: -8), row("d9", bm25: -7),
                     row("d7", bm25: -8), row("d42", bm25: -6)]
        let rows = LayeredResultComposer.wordsInMatches(keywordRows: found, base: held)
        #expect(rows.map(\.documentId) == ["d9", "d7", "d1"],
                "the base's order, each found row once, and no row the base does not hold")
        #expect(rows.map(\.semanticScore) == [0.9, 0.8, 0.7])
        #expect(rows.map(\.bm25Score) == [-0.9, -0.8, -0.7], "ordered by closeness under a date sort's tie-break")
        #expect(rows.map(\.snippet) == ["snippet <b>d9</b>", "snippet <b>d7</b>", "snippet <b>d1</b>"])
        #expect(LayeredResultComposer.wordsInMatches(keywordRows: [], base: held).isEmpty)
    }

    @Test("A ranking puts its ranked rows first, then the rest in the base's order, none dropped or doubled")
    func rankingKeepsATail() {
        let members = keywordRows(6)  // d1 … d6, BM25 order
        let ranked: [(key: String, score: Double)] = [("vol/d4", 0.81), ("vol/d6", 0.62), ("vol/d2", 0.62),
                                                      ("vol/d99", 0.5), ("vol/d4", 0.4)]
        let (rows, unranked) = LayeredResultComposer.rankedWithTail(ranked: ranked, members: members)
        #expect(rows.map(\.documentId) == ["d4", "d6", "d2", "d1", "d3", "d5"],
                "ranked closest first, then the unranked in the base's own order, not by id or score")
        #expect(unranked == 3)
        #expect(rows.prefix(3).map(\.semanticScore) == [0.81, 0.62, 0.62])
        #expect(rows.prefix(3).map(\.bm25Score) == [-0.81, -0.62, -0.62])
        #expect(rows.suffix(3).allSatisfy { $0.semanticScore == nil }, "an unranked row is never scored as zero")
        #expect(rows.suffix(3).map(\.bm25Score) == [-5, -3, -1], "an unranked row keeps its keyword score")
        #expect(Set(rows.map(\.id)).count == rows.count)
        let none = LayeredResultComposer.rankedWithTail(ranked: [], members: members)
        #expect(none.rows.map(\.documentId) == members.map(\.documentId) && none.unranked == 6)
    }

    @Test("The gate composer leaves a value with no base as it was, and joins a base to the gate")
    func gatingJoinsTheBase() {
        let open = SearchParameters(keywords: "x")
        #expect(LayeredResultComposer.gating(open, inside: nil).documentIds == nil)
        let corpus = SearchParameters(keywords: "x", documentIds: ["vol/d1", "vol/d2", "vol/d3"])
        #expect(LayeredResultComposer.gating(corpus, inside: nil).documentIds == ["vol/d1", "vol/d2", "vol/d3"])
        let held = base(rows: [row("d2", semantic: 0.5), row("d4", semantic: 0.4)])
        #expect(LayeredResultComposer.gating(open, inside: held).documentIds == ["vol/d2", "vol/d4"])
        #expect(LayeredResultComposer.gating(corpus, inside: held).documentIds == ["vol/d2"])
        let disjoint = SearchParameters(keywords: "x", documentIds: ["vol/d9"])
        #expect(LayeredResultComposer.gating(disjoint, inside: held).documentIds == [],
                "an empty gate matches nothing, and never becomes no gate")
    }

    /// One fixture per `nil` and per empty conjunct, as the assessment's §7 asks.
    @Test("The three-way gate intersects what is set and keeps the empty-set contract")
    func threeWayGate() {
        let corpus = ["a", "b", "c"], project = ["b", "c", "d"], pin = ["c", "b", "e"]
        #expect(DocumentScopeGate.combine(corpus: nil, projectGate: nil, pin: nil) == nil)
        #expect(DocumentScopeGate.combine(corpus: nil, projectGate: nil, pin: pin) == pin)
        #expect(DocumentScopeGate.combine(corpus: corpus, projectGate: nil, pin: nil) == corpus)
        #expect(DocumentScopeGate.combine(corpus: nil, projectGate: project, pin: nil) == project)
        #expect(DocumentScopeGate.combine(corpus: corpus, projectGate: project, pin: pin) == ["b", "c"])
        #expect(DocumentScopeGate.combine(corpus: corpus, projectGate: nil, pin: pin) == ["b", "c"])
        #expect(DocumentScopeGate.combine(corpus: nil, projectGate: project, pin: pin) == ["b", "c"])
        #expect(DocumentScopeGate.combine(corpus: [], projectGate: nil, pin: pin) == [])
        #expect(DocumentScopeGate.combine(corpus: nil, projectGate: [], pin: pin) == [])
        #expect(DocumentScopeGate.combine(corpus: corpus, projectGate: project, pin: []) == [])
        #expect(DocumentScopeGate.combine(corpus: ["a"], projectGate: nil, pin: ["z"]) == [])
        // The two-way form is unchanged.
        #expect(DocumentScopeGate.combine(corpus: corpus, projectGate: project) == ["b", "c"])
    }

    // MARK: What the results header owes a layer

    private func scope(loaded: Int, shown: Int? = nil, route: ExecutedSearchRoute,
                       fetchLimit: Int = 1_000, total: Int? = nil, filtersNarrowed: Bool = false,
                       inRankOrder: Bool = true, label: String? = nil, baseWasCut: Bool? = nil,
                       baseHidden: Int = 0) -> ResultSetScope {
        ResultSetScope(loaded: loaded, shown: shown ?? loaded, fetchLimit: fetchLimit, totalMatchCount: total,
                       documentsOnPage: min(loaded, 25), pageCount: max(1, (loaded + 24) / 25),
                       route: route, layerFiltersNarrowed: filtersNarrowed, listIsInRankOrder: inRankOrder,
                       layerBaseLabel: label, layerBaseWasCut: baseWasCut, layerBaseHiddenByChecklist: baseHidden)
    }

    @Test("A ranking is cut where its list was, whatever its own count against the list's total")
    func aRankingIsCutWhereItsListWas() {
        let ranked = ExecutedSearchRoute.rankedByMeaning(unranked: 2)
        // Nine ranked of a list of ten: one hidden as reviewed when the list was held, or removed by a filter.
        let short = scope(loaded: 9, route: ranked, total: 10, label: "“containment”", baseWasCut: false, baseHidden: 1)
        #expect(!short.didHitFetchLimit && !short.isCapturePartial)
        #expect(short.captureChecklistWarning
                == "Checklist mode is hiding 1 reviewed document. It will not be in this corpus.")
        #expect(short.captureProvenanceDescription
                == "Search results for “containment”, ranked by a question; 1 reviewed document excluded")
        #expect(short.headerDescription == "9 results · 7 ranked · 2 not ranked",
                "the header counts the ranking's own rows, hidden ones none")
        // A list cut at its fetch is cut in its ranking, whatever the ranking's count.
        let cut = scope(loaded: 997, route: ranked, total: 35_275, label: "“negotiations”", baseWasCut: true, baseHidden: 3)
        #expect(cut.didHitFetchLimit && cut.isCapturePartial)
        #expect(cut.captureProvenanceDescription == "Search results for “negotiations”, ranked by a question"
                + " — the highest-scoring 997 of 35,275 matches; 3 reviewed documents excluded")
        // With no word from the list, lane 2's rule stands: the Mac's window until lane 5.
        #expect(scope(loaded: 9, route: ranked, total: 10).didHitFetchLimit)
        // And the list's figures are a ranking's alone.
        #expect(scope(loaded: 9, route: .keywords, total: 10, baseWasCut: false).didHitFetchLimit,
                "a keyword list is read by its own counts")
        #expect(scope(loaded: 9, route: .keywords, baseHidden: 4).captureChecklistWarning == nil)
    }

    @Test("Words found in a list say so, and say the filters too when filters chosen since narrow them")
    func wordsHeaderNamesTheFilters() {
        let route = ExecutedSearchRoute.wordsInMatches(base: 100)
        #expect(scope(loaded: 7, route: route).headerDescription
                == "7 of your 100 closest matches contain these words")
        #expect(scope(loaded: 7, route: route, filtersNarrowed: true).headerDescription
                == "7 of your 100 closest matches contain these words and pass your filters")
        #expect(scope(loaded: 1, route: route, filtersNarrowed: true).headerDescription
                == "1 of your 100 closest matches contains these words and passes your filters")
        #expect(scope(loaded: 0, route: route, filtersNarrowed: true).headerDescription
                == "None of your 100 closest matches both contains these words and passes your filters")
        let single = ExecutedSearchRoute.wordsInMatches(base: 1)
        #expect(scope(loaded: 1, route: single, filtersNarrowed: true).headerDescription
                == "Your closest match contains these words and passes your filters")
        #expect(scope(loaded: 0, route: single, filtersNarrowed: true).headerDescription
                == "Your closest match does not both contain these words and pass your filters")
        // Only a layer's sentences change: a keyword list ignores the flag.
        #expect(scope(loaded: 7, route: .keywords, filtersNarrowed: true).headerDescription == "7 results")
    }

    @Test("A ranking is closest first only in its own order")
    func rankedHeaderFollowsTheSort() {
        let route = ExecutedSearchRoute.rankedByMeaning(unranked: 0)
        #expect(scope(loaded: 212, route: route).headerDescription == "212 results, closest first")
        #expect(scope(loaded: 212, route: route, inRankOrder: false).headerDescription == "212 results",
                "under a date sort the list is not closest first")
        #expect(scope(loaded: 212, route: .rankedByMeaning(unranked: 9), inRankOrder: false).headerDescription
                == "212 results · 203 ranked · 9 not ranked")
    }

    @Test("A capture inside a layer names both layers")
    func captureNamesBothLayers() {
        let words = scope(loaded: 7, route: .wordsInMatches(base: 100), label: "“how did the embassy”")
        #expect(words.captureProvenanceDescription
                == "Words found in a Meaning search’s closest matches to “how did the embassy” — 7 of 100")
        #expect(scope(loaded: 7, route: .wordsInMatches(base: 100)).captureProvenanceDescription
                == "Words found in a Meaning search’s closest matches — 7 of 100")
        let ranked = scope(loaded: 212, route: .rankedByMeaning(unranked: 0), total: 212, label: "“offset agreement”")
        #expect(ranked.captureProvenanceDescription == "Search results for “offset agreement”, ranked by a question")
        let cut = scope(loaded: 1_000, route: .rankedByMeaning(unranked: 0), total: 35_275, label: "“negotiations”")
        #expect(cut.captureProvenanceDescription
                == "Search results for “negotiations”, ranked by a question — the highest-scoring 1,000 of 35,275 matches")
        #expect(scope(loaded: 3, route: .rankedByMeaning(unranked: 0), total: 3).captureProvenanceDescription
                == "Search results, ranked by a question")
    }

    // MARK: #1683, the counts with no form for one

    @Test("One hidden document, and a Meaning capture of one, read in the singular (#1683)")
    func singularsOfTheCaptureAndTheCaveats() {
        let meaningOne = scope(loaded: 1, route: .meaning, fetchLimit: 100)
        #expect(meaningOne.captureTruncationWarning?.hasPrefix("This document is the closest match") == true)
        #expect(scope(loaded: 2, route: .meaning, fetchLimit: 100).captureTruncationWarning?
                .hasPrefix("These documents are the closest matches") == true)
        let hidingOne = scope(loaded: 5, shown: 4, route: .keywords)
        #expect(hidingOne.captureChecklistWarning
                == "Checklist mode is hiding 1 reviewed document. It will not be in this corpus.")
        #expect(hidingOne.captureProvenanceDescription == "Search results; 1 reviewed document excluded")
        #expect(hidingOne.collocationScopeDescription.hasSuffix(" 1 reviewed document is excluded."))
        let hidingTwo = scope(loaded: 5, shown: 3, route: .keywords)
        #expect(hidingTwo.captureChecklistWarning
                == "Checklist mode is hiding 2 reviewed documents. They will not be in this corpus.")
        #expect(hidingTwo.collocationScopeDescription.hasSuffix(" 2 reviewed documents are excluded."))
    }

    @Test("The facet panel names a layer's list, and one match in the singular (#1683)")
    func facetPreambles() {
        typealias Panel = FacetPanelView
        #expect(Panel.preambleHeadline(matchCount: 7, isMeaningSearch: false, layerRoute: .wordsInMatches(base: 100))
                == "Describing the 7 closest matches that contain your words")
        #expect(Panel.preambleHeadline(matchCount: 1, isMeaningSearch: false, layerRoute: .wordsInMatches(base: 100))
                == "Describing the closest match that contains your words")
        #expect(Panel.preambleHeadline(matchCount: 212, isMeaningSearch: true,
                                       layerRoute: .rankedByMeaning(unranked: 0))
                == "Describing these 212 results, ranked by your question")
        #expect(Panel.preambleHeadline(matchCount: 1, isMeaningSearch: false, layerRoute: nil) == "Describing the 1 match")
        #expect(Panel.preambleHeadline(matchCount: 412, isMeaningSearch: false, layerRoute: nil)
                == "Describing all 412 matches")
        #expect(Panel.preambleHeadline(matchCount: 1, isMeaningSearch: true, layerRoute: nil)
                == "Describing the closest match")
        #expect(Panel.preambleHeadline(matchCount: 100, isMeaningSearch: true, layerRoute: nil)
                == "Describing the 100 closest matches")
        #expect(Panel.preambleHeadline(matchCount: nil, isMeaningSearch: false, layerRoute: nil)
                == "Describing this result set — total unavailable")
    }

    @Test("A ranking's unranked rows are counted, in the singular for one")
    func unrankedHeader() {
        #expect(SearchLayerCopy.unrankedHeader(1) == "1 result not ranked by meaning")
        #expect(SearchLayerCopy.unrankedHeader(1_204) == "1,204 results not ranked by meaning")
    }
}
