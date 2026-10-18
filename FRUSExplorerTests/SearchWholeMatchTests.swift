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
import SwiftData
import Testing
@testable import FRUSExplorer

// MARK: - Fixtures

/// A row keyed `<volume>/<id>`, with a snippet that names it and the scores given.
private func wholeRow(_ id: String, bm25: Double = -1, semantic: Double? = nil,
                      volume: String = "vol") -> SearchResult {
    SearchResult(documentId: id, volumeId: volume, header: "Header \(id)", snippet: "snippet <b>\(id)</b>",
                 bm25Score: bm25, semanticScore: semantic)
}

/// `count` rows `d1`… in keyword order, as a keyword list's are.
private func listRows(_ count: Int) -> [SearchResult] {
    (1...count).map { wholeRow("d\($0)", bm25: -Double(count - $0)) }
}

/// A keyword list or a browse held for a question, its search known unless `ran` is `nil`, and found under that search's
/// filters.
private func heldList(kind: PinnedResultBase.Kind = .keywords, query: String = "negotiations",
                      rows: [SearchResult], members: [SearchResult]? = nil, fetchLimit: Int, total: Int?,
                      ran: SearchParameters? = SearchParameters(keywords: "negotiations")) -> PinnedResultBase {
    let shown = members ?? rows
    return PinnedResultBase(
        direction: .rankByMeaning, kind: kind, query: query, rows: rows, members: shown,
        hiddenByChecklist: rows.count - shown.count, notDownloaded: 0, route: .keywords,
        fetchLimit: fetchLimit, totalMatchCount: total, renderedExpression: nil, disclosure: nil,
        beyondLibraryHits: [], userTagCountScope: ran.map { .match($0) }, historyAnchor: nil,
        completedSearchAnchor: nil, filterSignature: ran.map { SearchScopeSignature.signature(for: $0) } ?? "")
}

// MARK: - WholeMatchRulesTests

/// The pure parts of a ranking of a whole match (#1577 lane 6): which held lists are ranked whole, what their row and
/// record say, the set and the rows the composer chooses, and the sentences `ResultSetScope` gives the result. None
/// needs a search service, a view or a device.
///
/// Version history:
///   1.0 — #1577 lane 6: initial implementation
@Suite("Search within results: a list cut at its ceiling is ranked whole, the rules (#1577 lane 6)")
@MainActor
struct WholeMatchRulesTests {

    // MARK: Which lists

    @Test("A keyword list or a browse cut at its ceiling, whose search is known, is ranked whole, and nothing else is")
    func whichListsAreRankedWhole() {
        let cut = heldList(rows: listRows(1_000), fetchLimit: 1_000, total: 35_275)
        #expect(cut.wasCut && cut.ranksWholeMatch)
        #expect(!heldList(rows: listRows(212), fetchLimit: 1_000, total: 212).ranksWholeMatch,
                "a list that holds its whole match ranks its rows, as lane 4 does")
        #expect(heldList(rows: listRows(1_000), fetchLimit: 1_000, total: nil).ranksWholeMatch,
                "a list at its ceiling whose count failed is cut")
        #expect(heldList(kind: .browse(name: "War"), query: "", rows: listRows(7_500), fetchLimit: 7_500,
                         total: 58_480, ran: SearchParameters(subjectBucket: 94)).ranksWholeMatch)
        #expect(!heldList(rows: listRows(1_000), fetchLimit: 1_000, total: 35_275, ran: nil).ranksWholeMatch,
                "with no search to read the match from, the rows are ranked")
        let meaning = PinnedResultBase(
            direction: .wordsInMatches, kind: .meaning, query: "q",
            rows: (1...100).map { wholeRow("d\($0)", semantic: 0.5) },
            members: (1...100).map { wholeRow("d\($0)", semantic: 0.5) }, hiddenByChecklist: 0, notDownloaded: 0,
            route: .meaning, fetchLimit: 100, totalMatchCount: nil, renderedExpression: nil, disclosure: nil,
            beyondLibraryHits: [], userTagCountScope: nil, historyAnchor: nil, completedSearchAnchor: nil,
            filterSignature: "")
        #expect(!meaning.ranksWholeMatch, "words are found inside a Meaning list, never a whole match")
    }

    // MARK: The row and the record

    @Test("The row names the whole match a question ranks, by its count, or as every result while that is not known")
    func theRowNamesTheWholeMatch() {
        let cut = heldList(rows: listRows(1_000), fetchLimit: 1_000, total: 35_275)
        #expect(cut.rowDescription == "Within all 35,275 results for “negotiations”")
        #expect(cut.accessibilityLabel == "Searching within all 35,275 results for “negotiations”")
        #expect(cut.backTitle == "Back to the 1,000 Results", "leaving puts the list's own rows back")
        var unknown = heldList(rows: listRows(1_000), fetchLimit: 1_000, total: nil)
        #expect(unknown.rowDescription == "Within every result for “negotiations”")
        unknown.keepWholeMatch((1...35_275).map { "vol/k\($0)" })
        #expect(unknown.rowDescription == "Within all 35,275 results for “negotiations”",
                "the keys a ranking read count the match its search could not")
        let ran = SearchParameters(subjectBucket: 94)
        #expect(heldList(kind: .browse(name: "War"), query: "", rows: listRows(7_500), fetchLimit: 7_500,
                         total: 58_480, ran: ran).rowDescription == "Within all 58,480 results for War")
        #expect(heldList(kind: .browse(name: "War"), query: "", rows: listRows(7_500), fetchLimit: 7_500,
                         total: nil, ran: ran).rowDescription == "Within every result for War")
        #expect(heldList(kind: .browse(name: nil), query: "", rows: listRows(7_500), fetchLimit: 7_500,
                         total: 9_000, ran: ran).rowDescription == "Within all 9,000 results of your browse")
        #expect(heldList(kind: .browse(name: nil), query: "", rows: listRows(7_500), fetchLimit: 7_500,
                         total: nil, ran: ran).rowDescription == "Within every result of your browse")
        // A list whose search is not known is ranked by its rows, and says where its fetch stopped (lane 4).
        #expect(heldList(rows: listRows(1_000), fetchLimit: 1_000, total: 35_275, ran: nil).rowDescription
                == "Within the first 1,000 of 35,275 results for “negotiations”")
    }

    @Test("The record counts the whole match less the rows hidden as reviewed, and the expression what was ranked and listed")
    func theRecordCountsTheMatch() throws {
        let rows = listRows(1_000)
        let held = heldList(rows: rows, members: Array(rows.dropFirst(13)), fetchLimit: 1_000, total: 35_275)
        #expect(held.hiddenKeys == Set(rows.prefix(13).map(\.id)))
        #expect(held.leftOutDescription == "13 results hidden as reviewed are not included.")
        #expect(held.signaturePart == "base=keywords:35262:negotiations")
        #expect(heldList(rows: listRows(212), fetchLimit: 1_000, total: 212).signaturePart
                == "base=keywords:212:negotiations", "a list ranked by its rows counts its members, as before")
        #expect(SemanticSearchBackend.renderedExpression(rankingAll: 35_262, listing: 1_000)
                .hasSuffix("; ranked=35262; top=1000"))
        // The trail signs the set ranked inside as a search inside that set signs it.
        let keys = ["vol/d3", "vol/d1", "vol/d2"]
        let signed = SearchScopeSignature.semanticSignature(rankingInside: keys)
        #expect(signed == SearchScopeSignature.semanticSignature(for: SearchParameters(documentIds: keys)))
        #expect(signed.hasPrefix("route=semantic;engine=on-device;docs=3/"))
        let layered = try #require(SearchScopeSignature.layered(signed, parameters: SearchParameters(), base: held))
        #expect(layered.hasPrefix("route=semantic;"), "an earlier build still reads it as a Meaning row")
        let prose = try #require(SearchScopeSignature.describe(layered))
        #expect(prose.contains("ranked inside a set of 3 documents, not across the whole series"), "\(prose)")
        #expect(prose.contains("inside the results of a keyword search for “negotiations” (35,262 documents)"),
                "\(prose)")
    }

    @Test("The set a question would rank is the whole match less the hidden rows, where that is known without reading it")
    func theSetSizeAhead() {
        let rows = listRows(1_000)
        let held = heldList(rows: rows, members: Array(rows.dropFirst(13)), fetchLimit: 1_000, total: 35_275)
        let outside = SearchParameters(keywords: "how was the test ban argued")
        #expect(held.wholeMatchSetSize(for: outside) == 35_262)
        var gated = outside
        gated.documentIds = ["vol/x"]
        #expect(held.wholeMatchSetSize(for: gated) == nil, "under a gate applied since only the keys can say")
        var filtered = outside
        filtered.documentTypeFilter = .documentsOnly
        #expect(held.wholeMatchSetSize(for: filtered) == nil,
                "under a filter chosen since, which narrows the match before the ranking, only the keys can say")
        let corpus = (1...500).map { "vol/c\($0)" }
        let inside = heldList(rows: rows, fetchLimit: 1_000, total: 4_000,
                              ran: SearchParameters(keywords: "negotiations", documentIds: corpus))
        #expect(inside.wholeMatchSetSize(for: SearchParameters(documentIds: corpus)) == 4_000,
                "the gate it was found under narrowed its match already")
        #expect(heldList(rows: rows, fetchLimit: 1_000, total: nil).wholeMatchSetSize(for: SearchParameters()) == nil)
        #expect(heldList(rows: listRows(212), fetchLimit: 1_000, total: 212).wholeMatchSetSize(for: SearchParameters())
                == nil, "a list ranked by its rows has no whole match to rank")
    }

    @Test("Filters chosen since narrow the whole match where one is set beside the list's own, a corpus applied since aside")
    func filtersNarrowTheMatch() {
        let ran = SearchParameters(keywords: "negotiations",
                                   dateRange: DateRange(earliest: "1961-01-01", latest: "1963-12-31"))
        let held = PinnedResultBase(
            direction: .rankByMeaning, kind: .keywords, query: "negotiations", rows: listRows(1_000),
            members: listRows(1_000), hiddenByChecklist: 0, notDownloaded: 0, route: .keywords, fetchLimit: 1_000,
            totalMatchCount: 3_120, renderedExpression: nil, disclosure: nil, beyondLibraryHits: [],
            userTagCountScope: .match(ran), historyAnchor: nil, completedSearchAnchor: nil,
            filterSignature: SearchScopeSignature.signature(for: ran))
        var live = ran
        live.keywords = "how was the test ban argued"
        #expect(!held.filtersNarrowTheMatch(live), "the list's own filters remove none of its match")
        var typed = live
        typed.documentTypeFilter = .documentsOnly
        #expect(held.filtersNarrowTheMatch(typed), "a filter set since narrows the match")
        var cornered = live
        cornered.documentIds = ["vol/d1", "vol/d2"]
        #expect(!held.filtersNarrowTheMatch(cornered), "a corpus applied since is the gate's to narrow, not a filter's")
        var removed = live
        removed.dateRange = nil
        #expect(!held.filtersNarrowTheMatch(removed), "a filter taken away removes nothing")
    }

    // MARK: The composer

    @Test("The set ranked is the match less the hidden rows, inside a corpus applied since, in the match's order")
    func theSetRanked() {
        let keys = (1...10).map { "vol/d\($0)" }
        #expect(LayeredResultComposer.wholeMatchSet(keys, leavingOut: [], inside: nil) == keys)
        #expect(LayeredResultComposer.wholeMatchSet(keys, leavingOut: ["vol/d2", "vol/d9"], inside: nil)
                == keys.filter { $0 != "vol/d2" && $0 != "vol/d9" })
        #expect(LayeredResultComposer.wholeMatchSet(
            keys, leavingOut: ["vol/d2"], inside: ["vol/d5", "vol/d2", "other/d1", "vol/d1"]) == ["vol/d1", "vol/d5"],
                "inside the gate, less the hidden, in the match's order and not the gate's")
        #expect(LayeredResultComposer.wholeMatchSet(keys, leavingOut: [], inside: []).isEmpty,
                "an empty gate admits nothing, as everywhere")
        // The filters chosen since narrow the set before the ranking, in the set's order.
        #expect(LayeredResultComposer.wholeMatchSet(keys, passing: nil) == keys, "with nothing constraining, the set")
        #expect(LayeredResultComposer.wholeMatchSet(keys, passing: ["vol/d7", "other/d1", "vol/d3"])
                == ["vol/d3", "vol/d7"], "the members the filters admit, in the set's order and not the filters'")
        #expect(LayeredResultComposer.wholeMatchSet(keys, passing: []).isEmpty, "filters that admit nothing")
    }

    @Test("The closest are listed up to the ceiling, and the list's own unranked rows in the set follow only where there is room")
    func theRowsChosen() {
        let members = listRows(6)
        let all = Set(members.map(\.id))
        // The ranking named last, so that a fill taken from the ranking's order and not the list's would show.
        let ranked: [(key: String, score: Double)] = [("vol/d9", 0.9), ("vol/d4", 0.8), ("vol/d2", 0.7)]
        let below = LayeredResultComposer.wholeMatchSelection(ranked: ranked, members: members, admitted: all, limit: 2)
        #expect(below.ranked.map(\.key) == ["vol/d9", "vol/d4"] && below.fill.isEmpty)
        let exact = LayeredResultComposer.wholeMatchSelection(ranked: ranked, members: members, admitted: all, limit: 3)
        #expect(exact.ranked.count == 3 && exact.fill.isEmpty, "a ceiling the ranked fill leaves no room")
        let room = LayeredResultComposer.wholeMatchSelection(ranked: ranked, members: members, admitted: all, limit: 5)
        #expect(room.ranked.map(\.key) == ["vol/d9", "vol/d4", "vol/d2"])
        #expect(room.fill.map(\.id) == ["vol/d1", "vol/d3"], "the list's unranked rows, in its order, up to the room")
        let narrowed = LayeredResultComposer.wholeMatchSelection(
            ranked: ranked, members: members, admitted: ["vol/d3", "vol/d5", "vol/d4", "vol/d2"], limit: 6)
        #expect(narrowed.fill.map(\.id) == ["vol/d3", "vol/d5"], "a row outside the set ranked is not listed")
        let none = LayeredResultComposer.wholeMatchSelection(ranked: [], members: members, admitted: all, limit: 4)
        #expect(none.ranked.isEmpty && none.fill.map(\.id) == ["vol/d1", "vol/d2", "vol/d3", "vol/d4"],
                "with nothing ranked, the list's own rows, as a ranking of them would list them")
        // Which members are in the set: those it holds, whatever its order.
        #expect(LayeredResultComposer.admittedMembers(members, of: ["other/d1", "vol/d5", "vol/d2", "vol/d5"])
                == ["vol/d2", "vol/d5"])
        #expect(LayeredResultComposer.admittedMembers(members, of: []).isEmpty)
    }

    @Test("The rows carry the ranking's scores, the unranked none, and a ranked document with no row is counted")
    func theRowsScored() {
        let rows = ["vol/d9": wholeRow("d9"), "vol/d4": wholeRow("d4")]
        let (listed, missing) = LayeredResultComposer.wholeMatchRows(
            ranked: [("vol/d9", 0.9), ("vol/x", 0.85), ("vol/d4", 0.8)], fill: [wholeRow("d1", bm25: -3)], rows: rows)
        #expect(listed.map(\.id) == ["vol/d9", "vol/d4", "vol/d1"])
        #expect(listed[0].semanticScore == 0.9 && listed[0].bm25Score == -0.9)
        #expect(listed[1].semanticScore == 0.8 && listed[1].bm25Score == -0.8)
        #expect(listed[2].semanticScore == nil && listed[2].bm25Score == -3)
        #expect(listed.map(\.snippet) == ["snippet <b>d9</b>", "snippet <b>d4</b>", "snippet <b>d1</b>"])
        #expect(missing == 1)
    }

    // MARK: The sentences

    /// A ranking of a whole match of `size` documents, listing `loaded` rows, `unranked` of them unranked, `filteredOut`
    /// of the match left out by filters chosen since.
    private func ranking(loaded: Int, shown: Int? = nil, unranked: Int = 0, size: Int, filteredOut: Int = 0,
                         notRanked: Int = 0, isCut: Bool = true, total: Int? = 35_275) -> ResultSetScope {
        let shown = shown ?? loaded
        return ResultSetScope(
            loaded: loaded, shown: shown, fetchLimit: 1_000, totalMatchCount: total,
            documentsOnPage: min(25, shown), pageCount: max(1, (shown + 24) / 25),
            route: .rankedByMeaning(unranked: unranked, wholeMatch: WholeMatchRanking(
                size: size, filteredOut: filteredOut, notRanked: notRanked, closest: loaded - unranked,
                isCut: isCut)))
    }

    @Test("The header names the closest and the documents they were chosen from, those that pass the filters, and what was not ranked")
    func theHeader() {
        #expect(ranking(loaded: 1_000, size: 35_275).headerDescription == "Closest 1,000 of 35,275 results")
        #expect(ranking(loaded: 1_000, size: 35_275, notRanked: 1_204).headerDescription
                == "Closest 1,000 of 35,275 results · 1,204 not ranked")
        // Filters chosen since narrowed the match before the ranking, so the second figure is of those that pass them.
        #expect(ranking(loaded: 1_000, size: 4_012, filteredOut: 31_263).headerDescription
                == "Closest 1,000 of the 4,012 results that pass your filters")
        #expect(ranking(loaded: 1_000, size: 4_012, filteredOut: 31_263, notRanked: 12).headerDescription
                == "Closest 1,000 of the 4,012 results that pass your filters · 12 not ranked")
        // A filter chosen since that left nothing out is not named.
        #expect(ranking(loaded: 1_000, size: 35_275, filteredOut: 0).headerDescription == "Closest 1,000 of 35,275 results")
        // Nothing could be ranked: the rows are the list's own, under the line that counts them.
        #expect(ranking(loaded: 10, unranked: 10, size: 24, notRanked: 24).headerDescription
                == "None of the 24 results could be ranked")
        #expect(ranking(loaded: 10, unranked: 10, size: 24, filteredOut: 6, notRanked: 24).headerDescription
                == "None of the 24 results that pass your filters could be ranked")
        // A set claim, true in any order: a date sort keeps it, where it drops lane 4's "closest first".
        var byDate = ranking(loaded: 1_000, size: 35_275)
        byDate.listIsInRankOrder = false
        #expect(byDate.headerDescription == "Closest 1,000 of 35,275 results")
        // The list's own unranked rows follow the closest, and the match's not-ranked count says how many there are.
        #expect(ranking(loaded: 20, unranked: 2, size: 24, notRanked: 6).headerDescription
                == "Closest 18 of 24 results · 6 not ranked")
        #expect(ranking(loaded: 1_000, shown: 990, size: 35_275).headerDescription
                == "990 shown · Closest 1,000 of 35,275 results")
        // A ranking that listed the whole set, a corpus applied since having narrowed it below the ceiling, is lane 4's.
        #expect(ranking(loaded: 212, size: 212, isCut: false).headerDescription == "212 results, closest first")
        #expect(ranking(loaded: 212, unranked: 9, size: 212, notRanked: 9, isCut: false).headerDescription
                == "212 results · 203 ranked · 9 not ranked")
    }

    @Test("A cut ranking is partial evidence, and its capture says the closest it ranked, not the highest-scoring")
    func theCapture() {
        let cut = ranking(loaded: 1_000, size: 35_275)
        #expect(cut.didHitFetchLimit && cut.isPartialEvidence && cut.isCapturePartial)
        #expect(cut.overCapGuidance == nil, "the field holds a question, so keyword advice does not apply")
        #expect(cut.captureTruncationWarning == "These 1,000 documents are the closest to your question of 35,275 matching documents, not all of them. Counts taken inside this corpus are counts inside that subset.")
        #expect(ranking(loaded: 1, size: 2).captureTruncationWarning
                == "This document is the closest to your question of 2 matching documents, not all of them. Counts taken inside this corpus are counts inside that subset.")
        // The rows listed after the closest, which it could not rank, are not called the closest.
        #expect(ranking(loaded: 1_000, unranked: 700, size: 35_275, notRanked: 34_975).captureTruncationWarning
                == "These 1,000 documents are the 300 closest to your question of 35,275 matching documents, and 700 that it could not rank. Counts taken inside this corpus are counts inside that subset.")
        var labelled = cut
        labelled.layerBaseLabel = "“negotiations”"
        #expect(labelled.captureProvenanceDescription
                == "Search results for “negotiations”, ranked by a question — the closest 1,000 of 35,275 matches")
        var partly = ranking(loaded: 1_000, unranked: 700, size: 35_275, notRanked: 34_975)
        partly.layerBaseLabel = "“negotiations”"
        #expect(partly.captureProvenanceDescription
                == "Search results for “negotiations”, ranked by a question — the closest 300 of 35,275 matches, and 700 not ranked")
        // Nothing ranked: the rows are the list's own inside the set, its highest-scoring, as lane 4 recorded them.
        var none = ranking(loaded: 10, unranked: 10, size: 24, notRanked: 24, total: 24)
        none.layerBaseLabel = "“talks”"
        #expect(none.captureTruncationWarning
                == "These 10 documents are the highest-scoring of 24 matching documents. Counts taken inside this corpus are counts inside that subset.")
        #expect(none.captureProvenanceDescription
                == "Search results for “talks”, ranked by a question — the highest-scoring 10 of 24 matches")
        // Filters chosen since: the documents passing them are the match the closest were chosen from.
        let filtered = ranking(loaded: 1_000, size: 4_012, filteredOut: 31_263)
        #expect(filtered.captureTruncationWarning == "These 1,000 documents are the closest to your question of 4,012 matching documents, not all of them. Counts taken inside this corpus are counts inside that subset.")
        // Not cut: whole, as a ranking of a whole list is.
        let whole = ranking(loaded: 212, size: 212, isCut: false)
        #expect(!whole.didHitFetchLimit && !whole.isCapturePartial && whole.captureTruncationWarning == nil)
        // Whatever the held list's own cut said: the ranking's is the one read.
        var overridden = ranking(loaded: 212, size: 212, isCut: false)
        overridden.layerBaseWasCut = true
        #expect(!overridden.didHitFetchLimit)
    }

    @Test("An empty ranking of a whole match whose set held documents says why none was listed, and blames no filter")
    func theEmptyStatement() {
        let filters = "None of the results you are searching within passes your filters."
        #expect(SearchLayerEmptyState.rankedStatement == filters)
        #expect(SearchLayerEmptyState.rankedStatement(route: .rankedByMeaning(unranked: 0), disclosure: nil) == filters,
                "a ranking of a list's rows is empty only when the filters removed every member")
        func whole(size: Int, filteredOut: Int = 18, notRanked: Int) -> ExecutedSearchRoute {
            .rankedByMeaning(unranked: 0, wholeMatch: WholeMatchRanking(
                size: size, filteredOut: filteredOut, notRanked: notRanked, closest: 0, isCut: size > 0))
        }
        func disclosure(set: Int, unscored: Int = 0, volumes: Int = 0, downloading: Int = 0,
                        withoutVector: Int = 0) -> SemanticSearchBackend.Disclosure {
            SemanticSearchBackend.Disclosure(
                unscoredCandidates: unscored, unscoredVolumes: volumes, downloadingVolumes: downloading,
                filtersApplied: true, filteredOut: 0, beyondUncheckedByFilters: false, rankedWithin: set,
                withoutVector: withoutVector)
        }
        #expect(SearchLayerEmptyState.rankedStatement(route: whole(size: 0, filteredOut: 24, notRanked: 0),
                                                      disclosure: disclosure(set: 0)) == filters,
                "the filters left none of the match, which the sentence says")
        // Six pass the filters and none can be ranked, and the list held none of them to list unranked.
        #expect(SearchLayerEmptyState.rankedStatement(
            route: whole(size: 6, notRanked: 6), disclosure: disclosure(set: 6, unscored: 6, volumes: 1))
                == "The documents you are searching within could not be ranked: match files for 1 volume are not on this device. Download Missing Vectors in Settings fetches the files for volumes you have downloaded.")
        #expect(SearchLayerEmptyState.rankedStatement(
            route: whole(size: 6, notRanked: 6), disclosure: disclosure(set: 6, withoutVector: 6))
                == "None of the documents you are searching within can be ranked by meaning: the app has no match data for them. Front matter and chapter headings never have any.")
        #expect(SearchLayerEmptyState.rankedStatement(
            route: whole(size: 6, notRanked: 6), disclosure: disclosure(set: 6, unscored: 6, volumes: 2, downloading: 2))
                == SemanticUnscoredCopy.emptyInsideSet(setSize: 6, ranked: 0, filteredOut: 0, volumes: 2, downloading: 2))
        // Ranked, but none of the ranked is in this device's index.
        #expect(SearchLayerEmptyState.rankedStatement(route: whole(size: 6, notRanked: 0), disclosure: disclosure(set: 6))
                == "None of the closest matches inside the documents you are searching within is indexed on this device.")
    }

    // MARK: The Mac's help, the seam and the timing line

    @Test("The Mac's toolbar help says a question ranks every result of a list cut at its ceiling")
    func theMacsHelp() {
        #expect(SearchLayerCopy.searchWithinResultsHelp(.rankByMeaning, isHolding: false, cutAt: 7_500)
                == "Rank every result of this search by a question, not only those loaded. The closest 7,500 are listed.")
        #expect(SearchLayerCopy.searchWithinResultsHelp(.rankByMeaning, isHolding: false)
                == "Rank these results by a question. Every result stays listed, the closest first.")
        #expect(SearchLayerCopy.searchWithinResultsHelp(.wordsInMatches, isHolding: false, cutAt: 7_500)
                == SearchLayerCopy.searchWithinResultsHelp(.wordsInMatches, isHolding: false),
                "words are found in a Meaning list, which no ceiling cuts")
        #expect(SearchLayerCopy.searchWithinResultsHelp(nil, isHolding: true, cutAt: 7_500)
                == SearchLayerCopy.searchWithinResultsHelp(nil, isHolding: true))
    }

    @Test("A UI test lowers the keyword ceiling only in UI-test mode, and only to a whole number above zero")
    func theCeilingSeam() {
        let key = UITestSearchCeiling.environmentKey
        #expect(UITestSearchCeiling.requested(in: ["FRUS_UI_TEST_MODE": "1", key: "4"]) == 4)
        #expect(UITestSearchCeiling.requested(in: [key: "4"]) == nil, "outside a UI test, nothing")
        #expect(UITestSearchCeiling.requested(in: ["FRUS_UI_TEST_MODE": "1"]) == nil)
        #expect(UITestSearchCeiling.requested(in: ["FRUS_UI_TEST_MODE": "1", key: "0"]) == nil)
        #expect(UITestSearchCeiling.requested(in: ["FRUS_UI_TEST_MODE": "1", key: "four"]) == nil)
        // The unit tests' host asks for none, so the ceiling is the app's own.
        #expect(SearchViewModel.keywordFetchCeiling == SearchViewModel.searchHardLimit)
    }

    @Test("The timing line holds counts and durations and nothing else")
    func theTimingLine() {
        let line = SearchTimingLog.line(SearchTimingLog.WholeMatch(
            matchSize: 35_275, setSize: 35_262, keysKept: false, ranked: 1_000, refetched: 812, listed: 1_000,
            keys: .milliseconds(731), set: .milliseconds(48), rank: .milliseconds(213), refetch: .milliseconds(804)))
        #expect(line == "whole-match docs=35275 set=35262 kept=0 ranked=1000 refetched=812 listed=1000 keys_ms=731.0 set_ms=48.0 rank_ms=213.0 refetch_ms=804.0")
    }
}

// MARK: - WholeMatchRankingTests

/// Counts the encoder's calls, from whichever task the searcher makes them in.
private final class EmbedCalls: @unchecked Sendable {
    private let lock = NSLock()
    private var calls = 0
    /// Counts one call.
    func record() { lock.lock(); calls += 1; lock.unlock() }
    /// The calls counted so far.
    var count: Int { lock.lock(); defer { lock.unlock() }; return calls }
}

/// `SemanticSearchBackend.rankWholeMatch(query:base:match:parameters:limit:)` on lane 1's synthetic vectors and an
/// index of the same documents (#1577 lane 6), no part of it skipped: for a match larger than the held list's ceiling,
/// the rows are the closest by a brute-force cosine computed here, in that order, each with its keyword snippet, and
/// none is outside the match.
///
/// ## The fixture
/// Every planted document reports on "the talks" except the crowd volume's 120, which report on the weather. The crowd's
/// vectors are the closest of all to the question, so a ranking that let a document outside the match in would list
/// them first. The match of "talks" is the other 24: twelve with their match file, six whose match file is not on the
/// device, and the two editions' three each. The held list is the first 10 or 20 of them by the keyword engine.
///
/// Version history:
///   1.0 — #1577 lane 6: initial implementation
@Suite("Search within results: the Meaning backend ranks a list's whole match (#1577 lane 6)")
@MainActor
struct WholeMatchRankingTests {

    private static let talks = SearchParameters(keywords: "talks")

    private func makeBackend(in directory: URL, withShards: [String] = SemanticSetFixture.volumesWithShards,
                             embedCalls: EmbedCalls = EmbedCalls())
        async throws -> (backend: SemanticSearchBackend, service: SearchService) {
        let volumesDirectory = directory.appendingPathComponent("volumes", isDirectory: true)
        try SemanticSetFixture.writeTEIVolumes(to: volumesDirectory, withoutTalks: [SemanticSetFixture.crowd])
        let databaseURL = directory.appendingPathComponent("index.sqlite")
        let store = try FTS5Store(databaseURL: databaseURL)
        let pipeline = try IndexingPipeline(fts5Store: store, databaseURL: databaseURL,
                                            volumesDirectory: volumesDirectory, concurrencyLimit: 1)
        for volume in SemanticSetFixture.volumes { try await pipeline.indexVolume(volume.id) }
        let service = SearchService(fts5Store: store, pipeline: pipeline)
        let artifacts = try SemanticSetFixture.writeArtifacts(in: directory, withShards: withShards)
        let searcher = SemanticQuerySearcher(
            index: artifacts.index, corpus: artifacts.corpus, modelStore: artifacts.modelStore,
            shardStore: artifacts.shardStore, requestShardFetch: { _ in false },
            embedOverride: { _ in
                embedCalls.record()
                return SemanticSetFixture.queryEmbedding
            })
        let backend = SemanticSearchBackend(
            searcher: searcher, searchService: service, manifestStore: ManifestStore(bundledEntries: []),
            indexedVolumeIds: { Set(SemanticSetFixture.volumes.map(\.id)) })
        return (backend, service)
    }

    /// The held list: the first `limit` rows of the keyword search for "talks", cut at `limit`, less the first
    /// `hiding` rows, which Checklist Mode hid.
    private func heldTalks(_ service: SearchService, limit: Int, hiding: Int = 0) async throws -> PinnedResultBase {
        let rows = try await service.search(parameters: Self.talks, limit: limit)
        let total = try await service.searchCount(parameters: Self.talks)
        return PinnedResultBase(
            direction: .rankByMeaning, kind: .keywords, query: "talks", rows: rows,
            members: Array(rows.dropFirst(hiding)), hiddenByChecklist: hiding, notDownloaded: 0, route: .keywords,
            fetchLimit: limit, totalMatchCount: total, renderedExpression: nil, disclosure: nil,
            beyondLibraryHits: [], userTagCountScope: .match(Self.talks), historyAnchor: nil,
            completedSearchAnchor: nil, filterSignature: "")
    }

    /// A fresh directory for one test, which `body` is handed and which is removed after it.
    private func withDirectory<T>(_ body: (URL) async throws -> T) async throws -> T {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WholeMatch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        return try await body(directory)
    }

    @Test("For a match larger than the ceiling the rows are the closest by the cosine, in order, with their keyword snippets, and none is outside the match")
    func theClosestOfTheWholeMatch() async throws {
        try await withDirectory { directory in
            let (backend, service) = try await makeBackend(in: directory)
            let base = try await heldTalks(service, limit: 10)
            let match = try await service.matchKeys(parameters: Self.talks)
            try #require(match.count == 24 && base.rows.count == 10 && base.totalMatchCount == 24,
                         "precondition: a list of 10 cut from a match of 24")
            try #require(base.ranksWholeMatch)
            // Fixture guard: a document outside the match is closer to the question than any inside it.
            let everything = SemanticSetFixture.volumes.flatMap { volume in volume.documentIDs.map { "\(volume.id)/\($0)" } }
            try #require(SemanticSetFixture.bruteForceRanking(of: everything).first?.key
                            .hasPrefix(SemanticSetFixture.crowd + "/") == true)

            let whole = try await backend.rankWholeMatch(query: "q", base: base, match: Self.talks,
                                                         parameters: SearchParameters(), limit: 10)

            let expected = SemanticSetFixture.bruteForceRanking(of: match)
            #expect(expected.count == 18, "fixture guard: 18 of the 24 can be ranked")
            #expect(whole.outcome.results.map(\.id) == expected.prefix(10).map(\.key),
                    "the closest ten of the whole match, in the cosine's order")
            for (row, wanted) in zip(whole.outcome.results, expected) {
                let score = try #require(row.semanticScore)
                #expect(abs(score - wanted.score) < 1e-6)
                #expect(row.bm25Score == -score)
            }
            #expect(whole.outcome.results.allSatisfy { match.contains($0.id) }, "a document outside the match is listed")
            #expect(!whole.outcome.results.contains { $0.volumeId == SemanticSetFixture.crowd })
            // Each row keeps the keyword snippet the search gives it, those the list did not hold among them.
            let snippets = Dictionary(try await service.search(parameters: Self.talks, limit: 100).map { ($0.id, $0.snippet) },
                                      uniquingKeysWith: { first, _ in first })
            #expect(whole.outcome.results.allSatisfy { $0.snippet == snippets[$0.id] && $0.snippet.contains("<b>") },
                    "each row has its keyword snippet")
            #expect(whole.outcome.results.contains { !base.memberKeys.contains($0.id) },
                    "fixture guard: a closest document the list did not hold is listed, its row fetched again")
            #expect(whole.ranking == WholeMatchRanking(size: 24, notRanked: 6, closest: 10, isCut: true))
            #expect(Set(whole.matchKeys) == Set(match))
            #expect(whole.outcome.disclosure.rankedWithin == 24)
            #expect(whole.outcome.disclosure.unscoredCandidates == SemanticSetFixture.absentPositives.count)
            #expect(whole.outcome.disclosure.withoutVector == 0 && whole.outcome.disclosure.notIndexedHere == 0)
            #expect(whole.outcome.beyondLibrary.isEmpty)
            #expect(whole.setSignature == SearchScopeSignature.semanticSignature(rankingInside: match))
        }
    }

    @Test("Where fewer than the ceiling can be ranked, the list's own unranked rows follow the closest, in its order")
    func unrankedRowsFillTheCeiling() async throws {
        try await withDirectory { directory in
            let (backend, service) = try await makeBackend(in: directory)
            let base = try await heldTalks(service, limit: 20)
            let match = try await service.matchKeys(parameters: Self.talks)
            try #require(base.rows.count == 20 && base.ranksWholeMatch)
            let whole = try await backend.rankWholeMatch(query: "q", base: base, match: Self.talks,
                                                         parameters: SearchParameters(), limit: 20)
            let ranked = SemanticSetFixture.bruteForceRanking(of: match).map(\.key)
            let unrankedInTheList = base.members.map(\.id).filter { !ranked.contains($0) }
            try #require(unrankedInTheList.count >= 2, "fixture guard: the list holds unranked rows to fill with")
            #expect(whole.outcome.results.map(\.id) == ranked + unrankedInTheList.prefix(2),
                    "every ranked document, closest first, then the list's unranked rows in its order, up to 20")
            #expect(whole.outcome.results.suffix(2).allSatisfy { $0.semanticScore == nil })
            #expect(whole.ranking == WholeMatchRanking(size: 24, notRanked: 6, closest: 18, isCut: true))
            let scope = ResultSetScope(loaded: 20, shown: 20, fetchLimit: 20, totalMatchCount: 24,
                                       documentsOnPage: 20, pageCount: 1,
                                       route: .rankedByMeaning(unranked: 2, wholeMatch: whole.ranking))
            #expect(scope.headerDescription == "Closest 18 of 24 results · 6 not ranked")
        }
    }

    @Test("With no match file on the device the list's own rows come back, unranked, and the encoder is never loaded")
    func nothingToScore() async throws {
        try await withDirectory { directory in
            let embedCalls = EmbedCalls()
            let (backend, service) = try await makeBackend(in: directory, withShards: [], embedCalls: embedCalls)
            let base = try await heldTalks(service, limit: 10)
            let whole = try await backend.rankWholeMatch(query: "q", base: base, match: Self.talks,
                                                         parameters: SearchParameters(), limit: 10)
            #expect(whole.outcome.results.map(\.id) == base.memberKeys, "the list's own rows, in its order")
            #expect(whole.outcome.results.allSatisfy { $0.semanticScore == nil })
            #expect(whole.ranking == WholeMatchRanking(size: 24, notRanked: 24, closest: 0, isCut: true))
            #expect(embedCalls.count == 0, "nothing could be scored, so the question was not encoded")
            var scope = ResultSetScope(loaded: 10, shown: 10, fetchLimit: 10, totalMatchCount: 24, documentsOnPage: 10,
                                       pageCount: 1, route: .rankedByMeaning(unranked: 10, wholeMatch: whole.ranking))
            scope.layerBaseLabel = "“talks”"
            #expect(scope.headerDescription == "None of the 24 results could be ranked")
            #expect(scope.captureProvenanceDescription
                    == "Search results for “talks”, ranked by a question — the highest-scoring 10 of 24 matches",
                    "the list's own rows, recorded as lane 4 recorded them, not as the closest of anything")
        }
    }

    @Test("Keys kept with the list are ranked, not the index's; a corpus applied since and hidden rows narrow the set")
    func theSetIsNarrowed() async throws {
        try await withDirectory { directory in
            let (backend, service) = try await makeBackend(in: directory)
            let match = try await service.matchKeys(parameters: Self.talks)

            // Keys kept with the list: the twins' alone, so a ranking of the index's would show more.
            var kept = try await heldTalks(service, limit: 10)
            let twins = match.filter { $0.hasPrefix(SemanticSetFixture.twinFirst + "/") || $0.hasPrefix(SemanticSetFixture.twinSecond + "/") }
            kept.keepWholeMatch(twins)
            let fromKept = try await backend.rankWholeMatch(query: "q", base: kept, match: Self.talks,
                                                            parameters: SearchParameters(), limit: 10)
            #expect(Set(fromKept.outcome.results.map(\.id)).isSubset(of: Set(twins)) && fromKept.ranking.size == 6)
            #expect(fromKept.matchKeys == twins)

            // A corpus applied since: the set is the match inside it; a key outside the match never comes in.
            let base = try await heldTalks(service, limit: 10)
            let held = match.filter { $0.hasPrefix(SemanticSetFixture.held + "/") }
            let corpus = Array(held.prefix(5)) + twins.prefix(2) + ["\(SemanticSetFixture.crowd)/d1"]
            let gated = try await backend.rankWholeMatch(query: "q", base: base, match: Self.talks,
                                                         parameters: SearchParameters(documentIds: corpus), limit: 10)
            #expect(gated.ranking.size == 7 && !gated.ranking.isCut)
            #expect(Set(gated.outcome.results.map(\.id)) == Set(corpus).intersection(match))

            // Rows hidden as reviewed when the list was held are left out of the set.
            let hiding = try await heldTalks(service, limit: 10, hiding: 3)
            let hidden = hiding.hiddenKeys
            let unhidden = try await backend.rankWholeMatch(query: "q", base: hiding, match: Self.talks,
                                                            parameters: SearchParameters(), limit: 10)
            #expect(unhidden.ranking.size == 21)
            #expect(!unhidden.outcome.results.contains { hidden.contains($0.id) })
        }
    }

    @Test("Filters chosen since narrow the match before the ranking: the closest of those that pass are listed, those the unfiltered ceiling would cut among them")
    func filtersNarrowTheMatchBeforeTheRanking() async throws {
        try await withDirectory { directory in
            let (backend, service) = try await makeBackend(in: directory)
            let base = try await heldTalks(service, limit: 10)
            let match = try await service.matchKeys(parameters: Self.talks)
            let twins = [SemanticSetFixture.twinFirst, SemanticSetFixture.twinSecond]
            let passing = match.filter { key in twins.contains { key.hasPrefix($0 + "/") } }
            let expected = SemanticSetFixture.bruteForceRanking(of: passing).map(\.key)
            // Fixture guard: two of the whole match's closest four are the twins', so filters narrowing the closest
            // rows after the ranking would list two, where six pass and four fit.
            try #require(expected.count == 6 && SemanticSetFixture.bruteForceRanking(of: match).prefix(4)
                .filter { passing.contains($0.key) }.count == 2)

            let scoped = try await backend.rankWholeMatch(query: "q", base: base, match: Self.talks,
                                                          parameters: SearchParameters(volumeIds: twins), limit: 4)
            #expect(scoped.outcome.results.map(\.id) == Array(expected.prefix(4)),
                    "the closest four of the six that pass, in the cosine's order")
            #expect(scoped.ranking == WholeMatchRanking(size: 6, filteredOut: 18, notRanked: 0, closest: 4, isCut: true))
            #expect(scoped.outcome.disclosure.filtersApplied && scoped.outcome.disclosure.filteredOut == 0,
                    "no hit is removed after the ranking")
            #expect(scoped.outcome.disclosure.rankedWithin == 6)
            #expect(scoped.setSignature == SearchScopeSignature.semanticSignature(rankingInside: passing))
            let scope = ResultSetScope(loaded: 4, shown: 4, fetchLimit: 4, totalMatchCount: 24, documentsOnPage: 4,
                                       pageCount: 1, route: .rankedByMeaning(unranked: 0, wholeMatch: scoped.ranking))
            #expect(scope.headerDescription == "Closest 4 of the 6 results that pass your filters")

            // A filter that leaves out the whole match lists nothing, and the filters' sentence says so.
            let nothing = try await backend.rankWholeMatch(query: "q", base: base, match: Self.talks,
                                                           parameters: SearchParameters(volumeIds: ["frus2099v01"]),
                                                           limit: 4)
            #expect(nothing.outcome.results.isEmpty)
            #expect(nothing.ranking == WholeMatchRanking(size: 0, filteredOut: 24, notRanked: 0, closest: 0, isCut: false))
            #expect(SearchLayerEmptyState.rankedStatement(
                route: .rankedByMeaning(unranked: 0, wholeMatch: nothing.ranking), disclosure: nothing.outcome.disclosure)
                    == SearchLayerEmptyState.rankedStatement)
        }
    }

    @Test("A set whose members pass and cannot be ranked, none of them held, lists nothing, and says why rather than blaming the filters")
    func nothingRankedAndNothingHeld() async throws {
        try await withDirectory { directory in
            let (backend, service) = try await makeBackend(in: directory)
            let base = try await heldTalks(service, limit: 4)
            let match = try await service.matchKeys(parameters: Self.talks)
            // The absent volume's documents the list of four does not hold: six, less any it does.
            let unheld = match.filter { $0.hasPrefix(SemanticSetFixture.absent + "/") && !base.memberKeys.contains($0) }
            try #require(unheld.count >= 2, "fixture guard: documents of the absent volume lie outside the held list")
            let whole = try await backend.rankWholeMatch(query: "q", base: base, match: Self.talks,
                                                         parameters: SearchParameters(documentIds: unheld), limit: 4)
            #expect(whole.outcome.results.isEmpty)
            #expect(whole.ranking == WholeMatchRanking(size: unheld.count, notRanked: unheld.count, closest: 0, isCut: true))
            #expect(SearchLayerEmptyState.rankedStatement(
                route: .rankedByMeaning(unranked: 0, wholeMatch: whole.ranking), disclosure: whole.outcome.disclosure)
                    == "The documents you are searching within could not be ranked: match files for 1 volume are not on this device. Download Missing Vectors in Settings fetches the files for volumes you have downloaded.")
        }
    }

    @Test("A search inside a set whose task is cancelled stops: before it encodes the question, or after, asking for no match file")
    func aCancelledSearchStops() async throws {
        try await withDirectory { directory in
            let embedCalls = EmbedCalls()
            let fetches = FetchRequests()
            let cancelWhileEncoding = CancelSwitch()
            let artifacts = try SemanticSetFixture.writeArtifacts(in: directory,
                                                                  withShards: SemanticSetFixture.volumesWithShards)
            let searcher = SemanticQuerySearcher(
                index: artifacts.index, corpus: artifacts.corpus, modelStore: artifacts.modelStore,
                shardStore: artifacts.shardStore,
                requestShardFetch: { volume in
                    fetches.record(volume)
                    return false
                },
                embedOverride: { _ in
                    embedCalls.record()
                    // The override runs in the task of the search that awaits it.
                    if cancelWhileEncoding.isOn { withUnsafeCurrentTask { $0?.cancel() } }
                    return SemanticSetFixture.queryEmbedding
                })
            // Uncancelled, the search encodes the question once and asks for the absent volume's match file once.
            let control = try await searcher.search("q", within: SemanticSetFixture.documentSet, limit: 5)
            try #require(!control.hits.isEmpty && embedCalls.count == 1 && fetches.count == 1,
                         "fixture guard: the set's search encodes and asks for a file")

            let cancelledFirst = await Task { () -> Bool in
                withUnsafeCurrentTask { $0?.cancel() }
                do {
                    _ = try await searcher.search("q", within: SemanticSetFixture.documentSet, limit: 5)
                    return false
                } catch {
                    return error is CancellationError
                }
            }.value
            #expect(cancelledFirst, "a search cancelled before it started came back")
            #expect(embedCalls.count == 1 && fetches.count == 1, "it encoded the question or asked for a file")

            cancelWhileEncoding.isOn = true
            let cancelledEncoding = await Task { () -> Bool in
                do {
                    _ = try await searcher.search("q", within: SemanticSetFixture.documentSet, limit: 5)
                    return false
                } catch {
                    return error is CancellationError
                }
            }.value
            #expect(cancelledEncoding, "a search cancelled while it encoded the question came back")
            #expect(embedCalls.count == 2, "fixture guard: the search reached the encoder")
            #expect(fetches.count == 1, "a search cancelled while it encoded asked for a match file")
        }
    }
}

/// Counts the match files a searcher asks for, from whichever task it asks in.
private final class FetchRequests: @unchecked Sendable {
    private let lock = NSLock()
    private var volumes: [String] = []
    /// Counts one request.
    func record(_ volume: String) { lock.lock(); volumes.append(volume); lock.unlock() }
    /// The requests counted so far.
    var count: Int { lock.lock(); defer { lock.unlock() }; return volumes.count }
}

/// A switch a test sets and a searcher's encoder reads, from whichever task it runs in.
private final class CancelSwitch: @unchecked Sendable {
    private let lock = NSLock()
    private var on = false
    /// Whether the encoder cancels the task it runs in.
    var isOn: Bool {
        get { lock.lock(); defer { lock.unlock() }; return on }
        set { lock.lock(); on = newValue; lock.unlock() }
    }
}

// MARK: - WholeMatchViewModelTests

/// A Meaning engine whose ranking of a whole match lists the held list's members in reverse, scored, and records each
/// call; it can hold its next ranking at its start until a test lets it go.
@MainActor
private final class WholeMatchEngine: MeaningSearchRunning {

    /// One call of ``rankWholeMatch(query:base:match:parameters:limit:)``.
    struct Call {
        let query: String
        let hadKeys: Bool
        let ran: SearchParameters
        let gate: [String]?
        /// The parameters outside the held list it was handed, the filters chosen since among them.
        let parameters: SearchParameters
        let limit: Int
    }

    private(set) var calls: [Call] = []
    private(set) var reranks = 0
    /// The match's keys the ranking returns.
    var matchKeys: [String] = []
    /// What the ranking says the filters chosen since left out of the match.
    var filteredOut = 0
    /// Set to hold the next ranking at its start.
    var holdNext = false
    /// The held ranking's continuation, once it is held.
    private(set) var held: CheckedContinuation<Void, Never>?
    /// Whether a held ranking found its task cancelled when it was let go.
    private(set) var sawCancellation = false

    func run(query: String, parameters: SearchParameters) async throws -> SemanticSearchBackend.Outcome {
        throw SemanticQuerySearcher.SearchUnavailable.vectorsUnavailable
    }

    func rerank(query: String, base: [SearchResult],
                parameters: SearchParameters) async throws -> SemanticSearchBackend.Outcome {
        reranks += 1
        throw SemanticQuerySearcher.SearchUnavailable.vectorsUnavailable
    }

    func rankWholeMatch(query: String, base: PinnedResultBase, match ran: SearchParameters,
                        parameters: SearchParameters, limit: Int) async throws -> SemanticSearchBackend.WholeMatchOutcome {
        calls.append(Call(query: query, hadKeys: base.wholeMatch != nil, ran: ran, gate: parameters.documentIds,
                          parameters: parameters, limit: limit))
        if holdNext {
            holdNext = false
            await withCheckedContinuation { held = $0 }
            if Task.isCancelled {
                sawCancellation = true
                throw CancellationError()
            }
        }
        let rows = Array(base.members.reversed().prefix(limit)).enumerated().map { index, row in
            row.replacingScores(bm25: -(0.9 - Double(index) / 10_000), semantic: 0.9 - Double(index) / 10_000)
        }
        return SemanticSearchBackend.WholeMatchOutcome(
            outcome: SemanticSearchBackend.Outcome(
                results: rows, beyondLibrary: [],
                disclosure: SemanticSearchBackend.Disclosure(
                    unscoredCandidates: 0, unscoredVolumes: 0, downloadingVolumes: 0, filtersApplied: false,
                    filteredOut: 0, beyondUncheckedByFilters: false, rankedWithin: matchKeys.count, withoutVector: 0)),
            matchKeys: matchKeys,
            ranking: WholeMatchRanking(size: matchKeys.count, filteredOut: filteredOut, notRanked: 0,
                                       closest: rows.count, isCut: rows.count < matchKeys.count),
            setSignature: "route=semantic;engine=on-device;docs=\(matchKeys.count)/test")
    }

    /// Lets the held ranking go on.
    func letGo() {
        held?.resume()
        held = nil
    }
}

/// A list cut at its ceiling ranked whole through the iPhone and iPad view model (#1577 lane 6), on a real index of
/// one document more than the 1,000-row keyword ceiling, with a stand-in engine: the call it makes, what it writes with
/// the rows, the keys it keeps, the record, leaving, and a replaced ranking.
///
/// Version history:
///   1.0 — #1577 lane 6: initial implementation
@Suite("Search within results: the iPhone and iPad view model ranks a list's whole match (#1577 lane 6)")
@MainActor
struct WholeMatchViewModelTests {

    /// A view model over 1,001 documents that all hold "containment", and its folder, which the test removes.
    private func makeViewModel() async throws -> (dir: URL, vm: SearchViewModel) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSWholeMatch-\(UUID().uuidString)", isDirectory: true)
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        var xml = "<?xml version=\"1.0\"?>\n<TEI><text><body>\n"
        for index in 0...SearchViewModel.searchHardLimit {
            xml += "<div type=\"document\" xml:id=\"d\(index)\"><head>\(index + 1). Item</head>"
                + "<p>The doctrine of containment shaped policy.</p></div>\n"
        }
        xml += "</body></text></TEI>"
        try Data(xml.utf8).write(to: volDir.appendingPathComponent("vol1.xml"))
        let dbURL = dir.appendingPathComponent("t.sqlite")
        let fts5 = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(fts5Store: fts5, databaseURL: dbURL,
                                            volumesDirectory: volDir, concurrencyLimit: 1)
        try await pipeline.indexVolume("vol1")
        return (dir, SearchViewModel(searchService: SearchService(fts5Store: fts5, pipeline: pipeline)))
    }

    /// The view model with "containment" listed, cut at 1,000 of 1,001, held for a question, and the engine.
    private func holdTheCutList() async throws -> (dir: URL, vm: SearchViewModel, engine: WholeMatchEngine) {
        let (dir, vm) = try await makeViewModel()
        vm.keywords = "containment"
        await vm.search()
        try #require(vm.results.count == SearchViewModel.searchHardLimit && vm.totalMatchCount == 1_001,
                     "precondition: a list of 1,000 cut from a match of 1,001")
        let engine = WholeMatchEngine()
        engine.matchKeys = (0...SearchViewModel.searchHardLimit).map { "vol1/d\($0)" }
        vm.semanticBackend = engine
        let held = try #require(vm.holdBase(meaningAvailable: true))
        try #require(held.ranksWholeMatch)
        return (dir, vm, engine)
    }

    @Test("A question over a list cut at its ceiling ranks its whole match, and the screen says the closest of it")
    func aQuestionRanksTheWholeMatch() async throws {
        let (dir, vm, engine) = try await holdTheCutList()
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(vm.pinnedBase?.rowDescription == "Within all 1,001 results for “containment”")
        #expect(vm.documentSetSize == 1_001, "a question would rank the whole match, not the 1,000 rows held")

        vm.keywords = "how was containment argued"
        #expect(await vm.search())
        #expect(engine.calls.count == 1 && engine.reranks == 0, "the whole match is ranked, not the rows held")
        let call = try #require(engine.calls.first)
        #expect(call.query == "how was containment argued" && call.ran.keywords == "containment" && !call.hadKeys)
        #expect(call.limit == SearchViewModel.searchHardLimit)
        #expect(call.gate == nil, "handed the parameters outside the list, whose gate is not the list's rows")
        #expect(vm.executedRoute == .rankedByMeaning(unranked: 0, wholeMatch: WholeMatchRanking(
            size: 1_001, notRanked: 0, closest: 1_000, isCut: true)))
        #expect(vm.resultSetScope.headerDescription == "Closest 1,000 of 1,001 results")
        #expect(vm.results.count == 1_000 && vm.results.first?.semanticScore == 0.9)
        #expect(vm.pinnedBase?.wholeMatch == engine.matchKeys, "the match's keys are kept with the list")
        #expect(vm.totalMatchCount == 1_001 && vm.lastFetchLimit == SearchViewModel.searchHardLimit)
        #expect(vm.lastRenderedExpression?.hasSuffix("; ranked=1001; top=1000; base=keywords:1001:containment") == true,
                "\(vm.lastRenderedExpression ?? "nil")")

        // A second question reads the keys the list kept. A filter chosen since reaches the ranking, which narrows the
        // match by it and says what it left out, and the header says so (the stand-in reports a figure, whatever the
        // filter). Until then the strip cannot say what the question will rank.
        vm.documentTypeFilter = .documentsOnly
        #expect(vm.documentSetSize == nil, "under a filter chosen since only the match's keys can say what is ranked")
        engine.filteredOut = 7
        vm.keywords = "who argued for it"
        #expect(await vm.search())
        #expect(engine.calls.count == 2 && engine.calls[1].hadKeys)
        #expect(engine.calls[1].parameters.documentTypeFilter == .documentsOnly, "the filter chosen since is not handed on")
        #expect(engine.calls[1].gate == nil)
        #expect(vm.resultSetScope.headerDescription == "Closest 1,000 of the 1,001 results that pass your filters")
        vm.documentTypeFilter = .all
        engine.filteredOut = 0

        // Leaving puts the list and its figures back, with no search.
        vm.leaveBase()
        #expect(engine.calls.count == 2)
        #expect(vm.results.count == 1_000 && vm.executedRoute == .keywords)
        #expect(vm.resultSetScope.headerDescription == "1,000 loaded · 1,001 total")
    }

    @Test("The trail signs the documents a whole match's ranking ranked inside, and the list by its whole match")
    func theTrailSignsTheSetRanked() async throws {
        let (dir, vm, _) = try await holdTheCutList()
        defer { try? FileManager.default.removeItem(at: dir) }
        let container = try ModelContainer(
            for: SearchHistoryEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = ModelContext(container)
        let defaults = try #require(UserDefaults(suiteName: "whole-match-\(UUID().uuidString)"))
        defaults.set(true, forKey: AppState.researchLoggingPreferenceKey)

        vm.keywords = "how was containment argued"
        await vm.search()
        vm.recordSearchHistory(projectId: nil, in: context, defaults: defaults)
        let entries = try context.fetch(FetchDescriptor<SearchHistoryEntry>())
        let entry = try #require(entries.first { $0.queryText == "how was containment argued" })
        #expect(entry.scopeSignature == "route=semantic;engine=on-device;docs=1001/test;base=keywords:1001:containment")
        #expect(entry.matchCount == 1_000 && entry.resultCount == 1_000, "the list it shows, recorded whole")
    }

    @Test("A ranking a later search replaced is cancelled and writes nothing")
    func aReplacedRankingWritesNothing() async throws {
        let (dir, vm, engine) = try await holdTheCutList()
        defer { try? FileManager.default.removeItem(at: dir) }
        engine.holdNext = true
        vm.keywords = "the first question"
        let first = Task { await vm.search() }
        while engine.held == nil { await Task.yield() }

        vm.keywords = "the second question"
        #expect(await vm.search(), "the second search writes")
        engine.letGo()
        #expect(await first.value == false, "the first, replaced, writes nothing")
        #expect(engine.sawCancellation, "the replaced ranking's task was cancelled, so the kit stops its statements")
        #expect(engine.calls.map(\.query) == ["the first question", "the second question"])
        #expect(vm.executedRoute == .rankedByMeaning(unranked: 0, wholeMatch: WholeMatchRanking(
            size: 1_001, notRanked: 0, closest: 1_000, isCut: true)))
        #expect(vm.isSearching == false)
    }
}

// MARK: - WholeMatchScreenWiringTests

/// The iPhone and iPad screen's half of an empty ranking of a whole match (#1577 lane 6), which no test drives through
/// the view: the screen asks `SearchLayerEmptyState.rankedStatement(route:disclosure:)` with the rows' route and the
/// ranking's disclosure, which `WholeMatchRulesTests.theEmptyStatement` holds to its sentences, as the Mac's window
/// does (`MacSearchWithinResultsWiringTests`).
///
/// Version history:
///   1.0 — #1577 lane 6: initial implementation
@Suite("Search within results: the iPhone and iPad screen says why an empty ranking of a whole match is empty (#1577 lane 6)")
struct WholeMatchScreenWiringTests {

    @Test("The layer's empty state asks for the statement by the rows' route and the ranking's disclosure")
    func theEmptyStateAsksByRoute() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let screen = try String(contentsOf: root.appendingPathComponent("FRUSExplorer/Search/SearchView.swift"),
                                encoding: .utf8).filter { !$0.isWhitespace }
        let call = "SearchLayerEmptyState.rankedStatement(route: resultSetScope.route, disclosure: vm.semanticDisclosure)"
        #expect(screen.contains(call.filter { !$0.isWhitespace }), "an empty ranking of a whole match blames the filters")
        #expect(!screen.contains("SearchLayerEmptyState.rankedStatement,"),
                "the screen still says the filters' sentence over every empty ranking")
    }
}
