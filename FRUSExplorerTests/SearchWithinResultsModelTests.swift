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

// MARK: - Fixture

/// Ten documents in one volume, `d0` … `d9`. Every one holds "containment"; `d1`, `d4` and `d7` also hold
/// "quillon", the words a layer finds; each is dated in its own year, 1950 to 1959.
private enum LayerFixture {

    static let volume = "vol1"
    static let count = 10
    static let wordDocuments: Set<Int> = [1, 4, 7]

    static func key(_ index: Int) -> String { "\(volume)/d\(index)" }

    /// A view model over the indexed fixture, and its folder, which the test removes.
    @MainActor
    static func makeViewModel() async throws -> (dir: URL, vm: SearchViewModel) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSLayer-\(UUID().uuidString)", isDirectory: true)
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        var xml = "<?xml version=\"1.0\"?>\n<TEI><text><body>\n"
        for index in 0..<count {
            let words = wordDocuments.contains(index) ? " The quillon file was opened." : ""
            xml += "<div type=\"document\" xml:id=\"d\(index)\"><head>\(index + 1). Item</head>"
                + "<dateline><date when=\"\(1950 + index)-05-01\">\(1950 + index)</date></dateline>"
                + "<p>The doctrine of containment shaped policy.\(words)</p></div>\n"
        }
        xml += "</body></text></TEI>"
        try Data(xml.utf8).write(to: volDir.appendingPathComponent("\(volume).xml"))
        let dbURL = dir.appendingPathComponent("t.sqlite")
        let fts5 = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(fts5Store: fts5, databaseURL: dbURL,
                                            volumesDirectory: volDir, concurrencyLimit: 1)
        try await pipeline.indexVolume(volume)
        return (dir, SearchViewModel(searchService: SearchService(fts5Store: fts5, pipeline: pipeline)))
    }

    /// The Meaning list the stand-in returns: every document, `d9` closest and `d0` furthest, so that the list's order
    /// is neither the index's nor a keyword ranking's.
    static var meaningRows: [SearchResult] {
        (0..<count).reversed().map { index in
            SearchResult(documentId: "d\(index)", volumeId: volume, header: "\(index + 1). Item",
                         snippet: "prose of d\(index)", bm25Score: -(0.5 + Double(index) / 100),
                         semanticScore: 0.5 + Double(index) / 100)
        }
    }
}

/// A Meaning engine that returns ``LayerFixture/meaningRows`` and ranks a held list by a fixed table, leaving the
/// members it has no score for unranked; it counts its calls, so a test can show that leaving a base runs nothing.
@MainActor
private final class LayerMeaningSearch: MeaningSearchRunning {

    /// The scores a ranking gives, by key; a member with none is not ranked.
    var rankScores: [String: Double] = [:]
    private(set) var runs = 0
    private(set) var reranks = 0
    /// The base and the gate the last ranking was given.
    private(set) var lastRerank: (base: [String], gate: [String]?)?

    func run(query: String, parameters: SearchParameters) async throws -> SemanticSearchBackend.Outcome {
        runs += 1
        return SemanticSearchBackend.Outcome(
            results: LayerFixture.meaningRows, beyondLibrary: [],
            disclosure: SemanticSearchBackend.Disclosure(
                unscoredCandidates: 0, unscoredVolumes: 0, downloadingVolumes: 0,
                filtersApplied: false, filteredOut: 0, beyondUncheckedByFilters: false))
    }

    func rerank(query: String, base: [SearchResult],
                parameters: SearchParameters) async throws -> SemanticSearchBackend.Outcome {
        reranks += 1
        lastRerank = (base.map(\.id), parameters.documentIds)
        let ranked = base.compactMap { row in rankScores[row.id].map { (key: row.id, score: $0) } }
            .sorted { $0.score > $1.score }
        let (rows, _) = LayeredResultComposer.rankedWithTail(ranked: ranked, members: base)
        return SemanticSearchBackend.Outcome(
            results: rows, beyondLibrary: [],
            disclosure: SemanticSearchBackend.Disclosure(
                unscoredCandidates: 0, unscoredVolumes: 0, downloadingVolumes: 0,
                filtersApplied: false, filteredOut: 0, beyondUncheckedByFilters: false,
                rankedWithin: base.count, withoutVector: base.count - ranked.count))
    }
}

/// A Meaning engine with no ranking inside a list: the protocol's stand-in `rerank` throws.
@MainActor
private final class UnrankingMeaningSearch: MeaningSearchRunning {
    func run(query: String, parameters: SearchParameters) async throws -> SemanticSearchBackend.Outcome {
        SemanticSearchBackend.Outcome(
            results: LayerFixture.meaningRows, beyondLibrary: [],
            disclosure: SemanticSearchBackend.Disclosure(
                unscoredCandidates: 0, unscoredVolumes: 0, downloadingVolumes: 0,
                filtersApplied: false, filteredOut: 0, beyondUncheckedByFilters: false))
    }
}

/// An in-memory trail, with research logging on, for the record tests.
@MainActor
private func makeTrail() throws -> (container: ModelContainer, context: ModelContext, defaults: UserDefaults) {
    let container = try ModelContainer(
        for: SearchHistoryEntry.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    let defaults = try #require(UserDefaults(suiteName: "search-layer-\(UUID().uuidString)"))
    defaults.set(true, forKey: AppState.researchLoggingPreferenceKey)
    return (container, ModelContext(container), defaults)
}

// MARK: - SearchWithinResultsModelTests

/// Search Within These Results through the iPhone and iPad view model (#1577 lane 4), on a real index with a stand-in
/// Meaning engine: holding a base and leaving it, a layer in each direction, the emptied field, the hand-offs, the
/// checklist's marks and the trail.
///
/// Version history:
///   1.0 — #1577 lane 4: initial implementation
///   1.1 — plan of record §6g, found in A8: words typed as one phrase name a held list quoted once
@Suite("Search within results: the iPhone and iPad view model")
@MainActor
struct SearchWithinResultsModelTests {

    /// The view model with a Meaning list on screen: the stand-in's ten rows, closest first.
    private func meaningListOnScreen() async throws -> (dir: URL, vm: SearchViewModel, engine: LayerMeaningSearch) {
        let (dir, vm) = try await LayerFixture.makeViewModel()
        let engine = LayerMeaningSearch()
        vm.semanticBackend = engine
        vm.searchMode = .meaning
        vm.keywords = "how did the embassy report"
        await vm.search()
        try #require(vm.results.count == LayerFixture.count, "precondition: the Meaning list is on screen")
        return (dir, vm, engine)
    }

    /// The view model with a keyword list on screen: "containment", every document.
    private func keywordListOnScreen() async throws -> (dir: URL, vm: SearchViewModel, engine: LayerMeaningSearch) {
        let (dir, vm) = try await LayerFixture.makeViewModel()
        let engine = LayerMeaningSearch()
        vm.semanticBackend = engine
        vm.keywords = "containment"
        await vm.search()
        try #require(vm.results.count == LayerFixture.count, "precondition: the keyword list is on screen")
        return (dir, vm, engine)
    }

    // MARK: Holding a base

    @Test("Holding a Meaning list keeps its rows, turns the field to Keywords and empties it, and runs nothing")
    func holdingAMeaningList() async throws {
        let (dir, vm, engine) = try await meaningListOnScreen()
        defer { try? FileManager.default.removeItem(at: dir) }
        let rowsBefore = vm.results.map(\.id)
        let version = vm.executedSearchVersion

        let base = try #require(vm.holdBase(meaningAvailable: false), "a words layer needs no Meaning engine")
        #expect(base.direction == .wordsInMatches)
        #expect(base.kind == .meaning)
        #expect(base.query == "how did the embassy report")
        #expect(vm.pinnedBase != nil && vm.isShowingBase)
        #expect(vm.searchMode == .keywords, "the field runs the other engine")
        #expect(vm.keywords.isEmpty, "the field empties for the words")
        #expect(vm.results.map(\.id) == rowsBefore, "the rows stay on screen")
        #expect(vm.executedSearchVersion == version, "nothing ran")
        #expect(engine.runs == 1)
        #expect(vm.layerDirection(meaningAvailable: true) == nil, "no layer is stacked on a held base")
        #expect(!vm.hasActiveFilters, "the base is a scope and not a filter: the glyph does not light")
        #expect(vm.searchParameters.documentIds?.count == LayerFixture.count, "but it joins the gate")
        #expect(vm.documentSetSize == LayerFixture.count)
    }

    @Test("No layer starts with no rows, under an error, over a layer, or as a ranking with no Meaning engine")
    func holdingRefuses() async throws {
        let (dir, vm) = try await LayerFixture.makeViewModel()
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(vm.holdBase(meaningAvailable: true) == nil, "nothing on screen")
        vm.keywords = "containment"
        await vm.search()
        #expect(vm.layerDirection(meaningAvailable: false) == nil, "a ranking needs the Meaning engine")
        #expect(vm.layerDirection(meaningAvailable: true) == .rankByMeaning)
        // A refusal that leaves the last rows in `results` (#1576 lane 3), with the error drawn in their
        // place: a check of the rows alone would let the list be held.
        vm.keywords = ""
        await vm.search()
        #expect(vm.searchError != nil && !vm.results.isEmpty, "precondition: an error over rows that are kept")
        #expect(vm.holdBase(meaningAvailable: true) == nil, "an error is drawn in the rows' place")
    }

    // MARK: Words found in a Meaning list

    @Test("Words found in a Meaning list are its rows that hold them, in its order, with its scores")
    func wordsInMatches() async throws {
        let (dir, vm, _) = try await meaningListOnScreen()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.holdBase(meaningAvailable: false)
        vm.keywords = "quillon"
        await vm.search()
        #expect(vm.results.map(\.documentId) == ["d7", "d4", "d1"],
                "the list's own order, d9 closest, and not a keyword ranking's or the index's")
        let listScores = Dictionary(uniqueKeysWithValues: LayerFixture.meaningRows.map { ($0.documentId, $0.semanticScore) })
        #expect(vm.results.map(\.semanticScore) == ["d7", "d4", "d1"].map { listScores[$0] ?? nil },
                "each row keeps the list's score")
        #expect(vm.results.allSatisfy { $0.snippet.contains("<b>") }, "each row keeps its keyword snippet")
        #expect(vm.executedRoute == .wordsInMatches(base: LayerFixture.count))
        #expect(vm.totalMatchCount == nil, "a capture would read the layer's count back as a total")
        #expect(vm.resultSetScope.headerDescription == "3 of your 10 closest matches contain these words")
        #expect(vm.offersReadings, "the rows are a keyword match's own")
        #expect(!vm.isShowingBase)
        #expect(vm.lastRenderedExpression?.hasSuffix("; base=meaning:10:how%20did%20the%20embassy%20report") == true)
    }

    @Test("A filter chosen since the list was held narrows the layer, and the header says so")
    func filtersChosenSinceAreSaid() async throws {
        let (dir, vm, _) = try await meaningListOnScreen()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.holdBase(meaningAvailable: false)
        vm.keywords = "quillon"
        await vm.search()
        #expect(!vm.resultSetScope.layerFiltersNarrowed)
        vm.dateRangeEnabled = true
        vm.dateRangeStart = try #require(ISO8601DateFormatter().date(from: "1953-01-01T00:00:00Z"))
        vm.dateRangeEnd = try #require(ISO8601DateFormatter().date(from: "1959-12-31T00:00:00Z"))
        await vm.search()
        #expect(vm.results.map(\.documentId) == ["d7", "d4"], "d1 is dated 1951")
        #expect(vm.resultSetScope.headerDescription
                == "2 of your 10 closest matches contain these words and pass your filters")
    }

    @Test("A filter taken away since the list was held is not said to narrow the words")
    func filtersTakenAwayAreNotSaid() async throws {
        let (dir, vm) = try await LayerFixture.makeViewModel()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.semanticBackend = LayerMeaningSearch()
        vm.searchMode = .meaning
        vm.dateRangeEnabled = true
        vm.dateRangeStart = try #require(ISO8601DateFormatter().date(from: "1953-01-01T00:00:00Z"))
        vm.dateRangeEnd = try #require(ISO8601DateFormatter().date(from: "1959-12-31T00:00:00Z"))
        vm.keywords = "how did the embassy report"
        await vm.search()
        vm.holdBase(meaningAvailable: false)
        vm.clearFilters()
        #expect(vm.pinnedBase != nil, "precondition: Clear Filters keeps the list")
        vm.keywords = "quillon"
        await vm.search()
        #expect(vm.results.count == 3, "precondition: no filter is left to remove a row")
        #expect(vm.resultSetScope.headerDescription == "3 of your 10 closest matches contain these words")
    }

    @Test("A filter set in the sheet and never run is not the list's, so what it removes is said")
    func aFilterNeverRunIsNotTheLists() async throws {
        let (dir, vm, _) = try await meaningListOnScreen()
        defer { try? FileManager.default.removeItem(at: dir) }
        // As the filter sheet's Done leaves it: set, and no search run.
        vm.dateRangeEnabled = true
        vm.dateRangeStart = try #require(ISO8601DateFormatter().date(from: "1953-01-01T00:00:00Z"))
        vm.dateRangeEnd = try #require(ISO8601DateFormatter().date(from: "1959-12-31T00:00:00Z"))
        vm.holdBase(meaningAvailable: false)
        vm.keywords = "quillon"
        await vm.search()
        #expect(vm.results.map(\.documentId) == ["d7", "d4"], "d1 is dated 1951")
        #expect(vm.resultSetScope.headerDescription
                == "2 of your 10 closest matches contain these words and pass your filters")
    }

    // MARK: A keyword list ranked by a question

    @Test("A ranking returns the whole list closest first, the unranked last, and keeps the list's ceiling and total")
    func rankByMeaning() async throws {
        let (dir, vm, engine) = try await keywordListOnScreen()
        defer { try? FileManager.default.removeItem(at: dir) }
        let ceiling = vm.resultSetScope.fetchLimit
        let total = vm.totalMatchCount
        vm.sortOrder = .dateDescending
        let base = try #require(vm.holdBase(meaningAvailable: true))
        #expect(base.direction == .rankByMeaning && base.kind == .keywords)
        #expect(vm.searchMode == .meaning)
        #expect(vm.sortOrder == .relevance, "a ranking is read closest first")
        engine.rankScores = [LayerFixture.key(3): 0.9, LayerFixture.key(8): 0.8, LayerFixture.key(0): 0.7,
                             LayerFixture.key(5): 0.6, LayerFixture.key(2): 0.5, LayerFixture.key(9): 0.4,
                             LayerFixture.key(6): 0.3]
        vm.keywords = "which talks failed"
        await vm.search()
        #expect(engine.reranks == 1 && engine.runs == 0, "a held list is ranked, not searched")
        #expect(Array(vm.results.map(\.documentId).prefix(7)) == ["d3", "d8", "d0", "d5", "d2", "d9", "d6"])
        #expect(vm.results.suffix(3).allSatisfy { $0.semanticScore == nil })
        #expect(vm.results.count == LayerFixture.count, "the whole list, as the owner's decision 3 asks")
        #expect(vm.executedRoute == .rankedByMeaning(unranked: 3))
        #expect(vm.resultSetScope.fetchLimit == ceiling, "the list stays cut where its keyword fetch was cut")
        #expect(vm.totalMatchCount == total)
        #expect(vm.resultSetScope.headerDescription == "10 results · 7 ranked · 3 not ranked")
        #expect(vm.unrankedTail?.count == 3)
        #expect(vm.unrankedTail?.firstId == vm.results[7].id)
        #expect(!vm.offersReadings, "a ranking's readings stay shut, as a Meaning list's")
        #expect(vm.lastRenderedExpression?.contains("ranked=10") == true)
        #expect(vm.lastRenderedExpression?.hasSuffix("; base=keywords:10:containment") == true)
        // Under a date order the unranked rows are not together, so no line counts them.
        vm.sortOrder = .dateDescending
        #expect(vm.unrankedTail == nil)
    }

    @Test("A ranking's header says closest first only while the list is in its own order")
    func aRankingSortedByDateIsNotClosestFirst() async throws {
        let (dir, vm, engine) = try await keywordListOnScreen()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.holdBase(meaningAvailable: true)
        engine.rankScores = Dictionary(uniqueKeysWithValues: (0..<LayerFixture.count).map {
            (LayerFixture.key($0), 0.5 + Double($0) / 100)
        })
        vm.keywords = "which talks failed"
        await vm.search()
        #expect(vm.executedRoute == .rankedByMeaning(unranked: 0), "precondition: every row is ranked")
        #expect(vm.resultSetScope.headerDescription == "10 results, closest first")
        // The reader can sort a ranking by date after it runs; its rows are then not closest first.
        vm.sortOrder = .dateAscending
        #expect(vm.resultSetScope.headerDescription == "10 results")
    }

    @Test("A ranking with fewer rows than its list, for the rows the checklist hid, is not read as cut")
    func aRankingShortOfItsListIsNotCut() async throws {
        let (dir, vm, engine) = try await keywordListOnScreen()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.setChecklistMode(true)
        vm.markReviewed(volumeId: LayerFixture.volume, documentId: "d4")
        #expect(!vm.resultSetScope.didHitFetchLimit, "precondition: the list is every match")
        vm.holdBase(meaningAvailable: true)
        engine.rankScores = [LayerFixture.key(3): 0.9]
        vm.keywords = "which talks failed"
        await vm.search()
        let scope = vm.resultSetScope
        #expect(scope.loaded == LayerFixture.count - 1 && vm.totalMatchCount == LayerFixture.count,
                "precondition: nine ranked, of a list of ten")
        #expect(!scope.didHitFetchLimit && !scope.isCapturePartial, "nothing was cut")
        #expect(scope.captureChecklistWarning
                == "Checklist mode is hiding 1 reviewed document. It will not be in this corpus.")
        #expect(scope.captureProvenanceDescription
                == "Search results for “containment”, ranked by a question; 1 reviewed document excluded")
    }

    @Test("A working corpus applied since narrows the list a ranking ranks")
    func aCorpusNarrowsTheRanking() async throws {
        let (dir, vm, engine) = try await keywordListOnScreen()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.holdBase(meaningAvailable: true)
        vm.appliedWorkingCorpusKeys = [LayerFixture.key(2), LayerFixture.key(5), "vol9/d1"]
        vm.keywords = "which talks failed"
        await vm.search()
        #expect(engine.lastRerank?.gate.map(Set.init) == [LayerFixture.key(2), LayerFixture.key(5)],
                "the gate is the base inside the corpus")
    }

    // MARK: Leaving

    @Test("Leaving puts the list and every figure back with no search, and bumps the version")
    func leavingRestoresTheMeaningList() async throws {
        let (dir, vm, engine) = try await meaningListOnScreen()
        defer { try? FileManager.default.removeItem(at: dir) }
        let rows = vm.results.map(\.id)
        let scope = vm.resultSetScope
        let expression = vm.lastRenderedExpression
        let disclosure = vm.semanticDisclosure
        vm.holdBase(meaningAvailable: false)
        vm.keywords = "quillon"
        await vm.search()
        let version = vm.executedSearchVersion

        vm.leaveBase()
        #expect(vm.pinnedBase == nil && !vm.isShowingBase)
        #expect(vm.results.map(\.id) == rows)
        #expect(vm.resultSetScope == scope, "the route, the ceiling, the total and the counts are the list's")
        #expect(vm.lastRenderedExpression == expression)
        #expect(vm.semanticDisclosure == disclosure)
        #expect(vm.searchMode == .meaning, "the control shows the list's engine again")
        #expect(vm.keywords == "how did the embassy report", "and the field its question")
        #expect(vm.executedSearchVersion > version, "facets and the tag counts are keyed on the version")
        #expect(engine.runs == 1, "nothing ran")
        #expect(vm.layerDirection(meaningAvailable: false) == .wordsInMatches, "the list can be held again")
    }

    @Test("Leaving a ranking puts the keyword list back, its total, ceiling, expression and sort included")
    func leavingRestoresTheKeywordList() async throws {
        let (dir, vm, engine) = try await keywordListOnScreen()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.sortOrder = .dateAscending
        let rows = vm.results.map(\.id)
        let total = vm.totalMatchCount
        let expression = vm.lastRenderedExpression
        vm.holdBase(meaningAvailable: true)
        engine.rankScores = [LayerFixture.key(3): 0.9]
        vm.keywords = "which talks failed"
        await vm.search()
        vm.leaveBase()
        #expect(vm.results.map(\.id) == rows)
        #expect(vm.executedRoute == .keywords)
        #expect(vm.totalMatchCount == total)
        #expect(vm.lastRenderedExpression == expression)
        #expect(vm.sortOrder == .dateAscending, "the reader's own sort comes back")
        #expect(vm.searchMode == .keywords)
        #expect(vm.keywords == "containment")
    }

    // MARK: The emptied field

    @Test("Emptying the field inside a base shows the base's rows again, and the base stays")
    func emptiedFieldShowsTheBase() async throws {
        let (dir, vm, _) = try await meaningListOnScreen()
        defer { try? FileManager.default.removeItem(at: dir) }
        let rows = vm.results.map(\.id)
        vm.holdBase(meaningAvailable: false)
        // The hold emptied the field itself: the handler finds the base on screen and leaves it.
        #expect(vm.fieldEmptiedInsideBase())
        #expect(vm.results.map(\.id) == rows)
        vm.keywords = "quillon"
        await vm.search()
        #expect(vm.results.count == 3)
        vm.keywords = ""
        #expect(vm.fieldEmptiedInsideBase(), "the view's handler clears nothing")
        #expect(vm.results.map(\.id) == rows, "the base's rows, not an empty list")
        #expect(vm.pinnedBase != nil && vm.isShowingBase)
        #expect(vm.executedRoute == .meaning)
        // And outside a base the handler goes on as before.
        vm.leaveBase()
        vm.keywords = ""
        #expect(!vm.fieldEmptiedInsideBase())
    }

    @Test("Emptying the field after a layer gives the list its own words back, which a capture records")
    func emptiedFieldGivesTheListItsWords() async throws {
        let (dir, vm, _) = try await meaningListOnScreen()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.holdBase(meaningAvailable: false)
        vm.keywords = "quillon"
        await vm.search()
        #expect(vm.submittedSearchParameters.keywords == "quillon", "precondition: the layer's words")
        vm.keywords = ""
        #expect(vm.fieldEmptiedInsideBase())
        // What Save as Working Corpus records as the corpus's query (`SearchView.saveWorkingCorpusSheet`).
        #expect(vm.submittedSearchParameters.keywords == "how did the embassy report")
    }

    @Test("Facets aggregate a held list's own rows under the match that found them, not the emptied field")
    func facetsOfTheListUseItsMatch() async throws {
        let (dir, vm, engine) = try await keywordListOnScreen()
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(vm.facetParameters.keywords == "containment")
        vm.holdBase(meaningAvailable: true)
        #expect(vm.searchParameters.keywords == nil && vm.searchParameters.documentIds != nil,
                "precondition: the live parameters are the emptied field's, inside the list")
        #expect(vm.facetParameters.keywords == "containment" && vm.facetParameters.documentIds == nil,
                "the list's own match")
        engine.rankScores = [LayerFixture.key(3): 0.9]
        vm.keywords = "which talks failed"
        await vm.search()
        vm.keywords = ""
        #expect(vm.fieldEmptiedInsideBase())
        #expect(vm.facetParameters.keywords == "containment" && vm.facetParameters.documentIds == nil,
                "and again once the field is emptied")
    }

    @Test("An empty field inside a base searches nothing: the base's rows are shown, and nothing is recorded")
    func emptyFieldSearchesNothing() async throws {
        let (dir, vm, engine) = try await keywordListOnScreen()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.holdBase(meaningAvailable: true)
        let recorded = await vm.search()
        #expect(!recorded, "runSearch records nothing")
        #expect(engine.reranks == 0)
        #expect(vm.results.count == LayerFixture.count && vm.isShowingBase)
    }

    @Test("A failed layer's empty list is not mistaken for the base when the field is emptied")
    func aFailedLayerGivesWayToTheBase() async throws {
        let (dir, vm, _) = try await keywordListOnScreen()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.holdBase(meaningAvailable: true)
        vm.semanticBackend = UnrankingMeaningSearch()
        vm.keywords = "which talks failed"
        await vm.search()
        #expect(vm.results.isEmpty && vm.searchError != nil, "precondition: the layer failed")
        vm.keywords = ""
        #expect(vm.fieldEmptiedInsideBase())
        #expect(vm.results.count == LayerFixture.count && vm.searchError == nil)
    }

    // MARK: What leaves the base

    @Test("Every hand-off leaves the base, and Clear Filters does not")
    func handOffsLeaveTheBase() async throws {
        let (dir, vm, _) = try await meaningListOnScreen()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.holdBase(meaningAvailable: false)
        vm.clearFilters()
        #expect(vm.pinnedBase != nil, "Clear Filters keeps a list a re-run might not reproduce")

        vm.applyParameters(SearchParameters(keywords: "containment"))
        #expect(vm.pinnedBase == nil, "a recalled search leaves the base")

        await vm.search()
        vm.holdBase(meaningAvailable: true)
        #expect(vm.pinnedBase != nil)
        #expect(vm.applyHandoff(SearchParameters(keywords: "policy")))
        #expect(vm.pinnedBase == nil, "a hand-off leaves the base")

        await vm.search()
        vm.holdBase(meaningAvailable: true)
        vm.clearAll()
        #expect(vm.pinnedBase == nil)
    }

    @Test("A hand-off that runs nothing puts the held list back, with its engine and the reader's sort")
    func aScopeOnlyHandOffPutsTheListBack() async throws {
        let (dir, vm, engine) = try await keywordListOnScreen()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.sortOrder = .dateAscending
        let rows = vm.results.map(\.id)
        vm.holdBase(meaningAvailable: true)
        engine.rankScores = [LayerFixture.key(3): 0.9]
        vm.keywords = "which talks failed"
        await vm.search()
        #expect(vm.executedRoute == .rankedByMeaning(unranked: LayerFixture.count - 1), "precondition: a ranking")
        var scopeOnly = SearchParameters()
        scopeOnly.volumeIds = [LayerFixture.volume]
        #expect(!vm.applyHandoff(scopeOnly), "Search this volume runs nothing")
        #expect(vm.pinnedBase == nil)
        #expect(vm.executedRoute == .keywords && vm.results.map(\.id) == rows, "the rows are the list's own")
        #expect(vm.searchMode == .keywords, "and the control names their engine")
        #expect(vm.sortOrder == .dateAscending, "and the reader's sort is back")
    }

    @Test("A list found by a restored phrase alone is held as a keyword list, named by its phrase")
    func aPhraseListIsAKeywordList() async throws {
        let (dir, vm) = try await LayerFixture.makeViewModel()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.semanticBackend = LayerMeaningSearch()
        var restored = SearchParameters()
        restored.phrase = "doctrine of containment"
        vm.applyParameters(restored)
        await vm.search()
        #expect(vm.results.count == LayerFixture.count, "precondition: every document holds the phrase")
        let base = try #require(vm.holdBase(meaningAvailable: true))
        #expect(base.kind == .keywords)
        #expect(base.rowDescription == "Within 10 results for “doctrine of containment”", "quoted once (§6g)")
        #expect(base.signaturePart == "base=keywords:10:%22doctrine%20of%20containment%22")
    }

    /// Plan of record §6g, found in A8 in the Mac check copy: a search typed `"offset agreement"`, with its quotation
    /// marks, as both manuals' example is, held a list whose row read “"offset agreement"”.
    @Test("Words typed as one phrase name a held list quoted once wherever it is named, and are recorded as typed")
    func aTypedPhraseIsQuotedOnce() async throws {
        let (dir, vm) = try await LayerFixture.makeViewModel()
        defer { try? FileManager.default.removeItem(at: dir) }
        let engine = LayerMeaningSearch()
        vm.semanticBackend = engine
        let (container, context, defaults) = try makeTrail()
        defer { _ = container }
        let phrase = "\"doctrine of containment\""
        vm.keywords = phrase
        await vm.search()
        try #require(vm.results.count == LayerFixture.count, "precondition: every document holds the phrase")
        let base = try #require(vm.holdBase(meaningAvailable: true))
        #expect(base.kind == .keywords && base.query == phrase)
        #expect(base.rowDescription == "Within 10 results for “doctrine of containment”")
        #expect(base.accessibilityLabel == "Searching within 10 results for “doctrine of containment”")

        engine.rankScores = [LayerFixture.key(3): 0.9]
        vm.keywords = "which talks failed"
        await vm.search()
        try #require(vm.executedRoute == .rankedByMeaning(unranked: LayerFixture.count - 1), "precondition: a ranking")
        let swap = try #require(vm.layerSwap)
        #expect(SearchLayerCopy.swapHelp(swap)
                == "Ask “which talks failed” first, then find “doctrine of containment” among its closest matches")
        #expect(vm.resultSetScope.captureProvenanceDescription
                == "Search results for “doctrine of containment”, ranked by a question")

        vm.recordSearchHistory(projectId: nil, indexedVolumeCount: 1, in: context, defaults: defaults)
        let row = try #require(try context.fetch(FetchDescriptor<SearchHistoryEntry>()).first)
        let signature = try #require(row.scopeSignature)
        #expect(signature.hasSuffix(";base=keywords:10:%22doctrine%20of%20containment%22"), "the marks are recorded")
        #expect(SearchScopeSignature.describe(signature)?.last
                == "inside the results of a keyword search for “doctrine of containment” (10 documents)")

        vm.leaveBase()
        #expect(vm.keywords == phrase && vm.searchMode == .keywords, "the field gets the words back as typed")
    }

    @Test("Words found nowhere in the list can be searched across the library, which leaves the base")
    func searchingTheWholeLibrary() async throws {
        let (dir, vm, _) = try await meaningListOnScreen()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.holdBase(meaningAvailable: false)
        vm.keywords = "zircaloy"
        await vm.search()
        #expect(vm.results.isEmpty)
        #expect(vm.resultSetScope.headerDescription == "None of your 10 closest matches contains these words")
        vm.leaveBaseKeepingTheWords()
        #expect(vm.pinnedBase == nil)
        #expect(vm.keywords == "zircaloy" && vm.searchMode == .keywords)
        vm.keywords = "containment"
        await vm.search()
        #expect(vm.executedRoute == .keywords && vm.results.count == LayerFixture.count)
    }

    // MARK: The checklist and the selection

    @Test("The checklist's marks survive holding, a layer and leaving")
    func marksSurvive() async throws {
        let (dir, vm, _) = try await meaningListOnScreen()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.setChecklistMode(true)
        vm.markReviewed(volumeId: LayerFixture.volume, documentId: "d4")
        let base = try #require(vm.holdBase(meaningAvailable: false))
        #expect(base.members.count == LayerFixture.count - 1 && base.hiddenByChecklist == 1,
                "the layer runs inside the list as shown")
        vm.keywords = "quillon"
        await vm.search()
        #expect(vm.results.map(\.documentId) == ["d7", "d1"], "the reviewed d4 was not a member")
        #expect(vm.markedReviewedKeys == ["vol1|d4"], "a layer does not start the checklist again")
        vm.leaveBase()
        #expect(vm.markedReviewedKeys == ["vol1|d4"])
        #expect(!vm.displayedResults.map(\.documentId).contains("d4"))
    }

    @Test("The checklist's marks survive a ranking of a held list, and leaving it")
    func marksSurviveARanking() async throws {
        let (dir, vm, engine) = try await keywordListOnScreen()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.setChecklistMode(true)
        vm.markReviewed(volumeId: LayerFixture.volume, documentId: "d4")
        let base = try #require(vm.holdBase(meaningAvailable: true))
        #expect(base.direction == .rankByMeaning && base.members.count == LayerFixture.count - 1)
        engine.rankScores = [LayerFixture.key(3): 0.9, LayerFixture.key(8): 0.8]
        vm.keywords = "which talks failed"
        await vm.search()
        #expect(vm.executedRoute == .rankedByMeaning(unranked: LayerFixture.count - 3),
                "precondition: the nine members are ranked, the reviewed d4 not among them")
        #expect(vm.markedReviewedKeys == ["vol1|d4"], "a ranking does not start the checklist again")
        vm.leaveBase()
        #expect(vm.markedReviewedKeys == ["vol1|d4"])
        #expect(!vm.displayedResults.map(\.documentId).contains("d4"))
    }

    @Test("Tags given to rows inside a held list last into a ranking of it and back to the list")
    func tagsLastThroughTheList() async throws {
        let (dir, vm, engine) = try await keywordListOnScreen()
        defer { try? FileManager.default.removeItem(at: dir) }
        let tag = UUID()
        vm.holdBase(meaningAvailable: true)
        // Given to the list's own rows while they are on screen: #1576 lane 5's refresh writes those alone.
        vm.refreshUserTags([LayerFixture.key(3): [tag]])
        engine.rankScores = [LayerFixture.key(3): 0.9]
        vm.keywords = "which talks failed"
        await vm.search()
        #expect(vm.results.first?.id == LayerFixture.key(3), "precondition: d3 is ranked first")
        #expect(vm.results.first?.userTagIds == [tag.uuidString], "a ranking is built from the list, and carries the tag")
        // And one given inside the ranking goes back with the list.
        let second = UUID()
        vm.refreshUserTags([LayerFixture.key(5): [second]])
        vm.leaveBase()
        #expect(vm.results.first { $0.id == LayerFixture.key(5) }?.userTagIds == [second.uuidString])
        #expect(vm.results.first { $0.id == LayerFixture.key(3) }?.userTagIds == [tag.uuidString])
    }

    // MARK: The trail

    @Test("A layer typed with the base's own words writes a row of its own, and the base's row is kept")
    func aLayerKeepsTheBasesTrailRow() async throws {
        let (dir, vm, engine) = try await keywordListOnScreen()
        defer { try? FileManager.default.removeItem(at: dir) }
        let (container, context, defaults) = try makeTrail()
        defer { _ = container }
        vm.recordSearchHistory(projectId: nil, indexedVolumeCount: 1, in: context, defaults: defaults)
        let first = try #require(try context.fetch(FetchDescriptor<SearchHistoryEntry>()).first)
        let baseSignature = first.scopeSignature

        vm.holdBase(meaningAvailable: true)
        engine.rankScores = [LayerFixture.key(3): 0.9, LayerFixture.key(8): 0.8]
        vm.keywords = "containment"  // the base's own words, as a question
        #expect(await vm.search())
        vm.recordSearchHistory(projectId: nil, indexedVolumeCount: 1, in: context, defaults: defaults)

        let rows = try context.fetch(FetchDescriptor<SearchHistoryEntry>())
        #expect(rows.count == 2, "the layer wrote a row of its own")
        #expect(first.scopeSignature == baseSignature, "and left the base's row as it was")
        let layer = try #require(rows.first { $0.id != first.id })
        let signature = try #require(layer.scopeSignature)
        #expect(signature.hasPrefix("route=semantic"))
        #expect(signature.hasSuffix(";base=keywords:10:containment"))
        #expect(layer.matchCount == LayerFixture.count, "a complete ranking is recorded whole, not as a floor")
        if case .exact(let match, _) = layer.recordedCount {
            #expect(match == LayerFixture.count)
        } else {
            Issue.record("the layer's count reads as \(layer.recordedCount), not exact")
        }

        // Leaving gives the base its anchor back: a re-run of its words refreshes its own row, and not the
        // layer's, which holds the same words.
        let layerWrittenAt = try #require(layer.executedAt)
        vm.leaveBase()
        await vm.search()
        vm.recordSearchHistory(projectId: nil, indexedVolumeCount: 1, in: context, defaults: defaults)
        #expect(try context.fetch(FetchDescriptor<SearchHistoryEntry>()).count == 2)
        #expect(layer.scopeSignature == signature, "the layer's row is as it was")
        #expect(try #require(first.executedAt) > layerWrittenAt, "the base's row is the one the re-run refreshed")
    }

    @Test("Words found in a list sign the keyword grammar with the list as their base")
    func wordsLayerSignature() async throws {
        let (dir, vm, _) = try await meaningListOnScreen()
        defer { try? FileManager.default.removeItem(at: dir) }
        let (container, context, defaults) = try makeTrail()
        defer { _ = container }
        vm.holdBase(meaningAvailable: false)
        vm.keywords = "quillon"
        await vm.search()
        vm.recordSearchHistory(projectId: nil, indexedVolumeCount: 1, in: context, defaults: defaults)
        let row = try #require(try context.fetch(FetchDescriptor<SearchHistoryEntry>()).first)
        let signature = try #require(row.scopeSignature)
        #expect(signature.hasPrefix("mode=and;"), "the keyword grammar, whose docs= part is the gate")
        #expect(signature.contains(";docs=10/"))
        #expect(signature.hasSuffix(";base=meaning:10:how%20did%20the%20embassy%20report"))
        #expect(row.matchCount == 3)
        #expect(SearchScopeSignature.describe(signature)?.last
                == "inside the closest matches of a Meaning search for “how did the embassy report” (10 documents)")
    }
}

// MARK: - The backend's ranking of a held list

/// `SemanticSearchBackend.rerank(query:base:parameters:)` on lane 1's synthetic vectors and a real index of the same
/// documents (#1577 lane 4): the whole list, closest first by a brute-force cosine, the rows it cannot rank last in
/// the list's order, each row the list's own.
@Suite("Search within results: the Meaning backend ranks a held list")
@MainActor
struct SearchLayerRerankTests {

    private func makeBackend(in directory: URL) async throws -> (backend: SemanticSearchBackend, service: SearchService) {
        let volumesDirectory = directory.appendingPathComponent("volumes", isDirectory: true)
        try SemanticSetFixture.writeTEIVolumes(to: volumesDirectory)
        let databaseURL = directory.appendingPathComponent("index.sqlite")
        let store = try FTS5Store(databaseURL: databaseURL)
        let pipeline = try IndexingPipeline(fts5Store: store, databaseURL: databaseURL,
                                            volumesDirectory: volumesDirectory, concurrencyLimit: 1)
        for volume in SemanticSetFixture.volumes { try await pipeline.indexVolume(volume.id) }
        let service = SearchService(fts5Store: store, pipeline: pipeline)
        let artifacts = try SemanticSetFixture.writeArtifacts(in: directory)
        let searcher = SemanticQuerySearcher(
            index: artifacts.index, corpus: artifacts.corpus, modelStore: artifacts.modelStore,
            shardStore: artifacts.shardStore, requestShardFetch: { _ in false },
            embedOverride: { _ in SemanticSetFixture.queryEmbedding })
        let backend = SemanticSearchBackend(
            searcher: searcher, searchService: service, manifestStore: ManifestStore(bundledEntries: []),
            indexedVolumeIds: { Set(SemanticSetFixture.volumes.map(\.id)) })
        return (backend, service)
    }

    /// The keyword list the ranking is given: the set's indexed members, by a keyword search for a word every document
    /// holds, so each row has a keyword snippet.
    private func keywordBase(_ service: SearchService) async throws -> [SearchResult] {
        try await service.search(parameters: SearchParameters(keywords: "talks",
                                                              documentIds: SemanticSetFixture.documentSet),
                                 limit: 1_000)
    }

    @Test("A held list is ranked whole, closest first by the cosine, its unranked rows last in its order")
    func rankingIsBruteForceWithATail() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SemanticLayer-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let (backend, service) = try await makeBackend(in: directory)
        let base = try await keywordBase(service)
        try #require(base.count == 14, "precondition: the set's 14 indexed members, 12 rankable and 2 with no file")

        let outcome = try await backend.rerank(
            query: "q", base: base, parameters: SearchParameters(documentIds: base.map(\.id)))

        let ranked = SemanticSetFixture.bruteForceRanking(of: base.map(\.id))
        let tail = base.map(\.id).filter { key in !ranked.contains { $0.key == key } }
        #expect(outcome.results.map(\.id) == ranked.map(\.key) + tail,
                "ranked by the cosine in the kernel's order, then the members it could not rank, in the list's order")
        #expect(tail.count == SemanticSetFixture.plantedWithoutShard)
        for (row, wanted) in zip(outcome.results, ranked) {
            let score = try #require(row.semanticScore)
            #expect(abs(score - wanted.score) < 1e-6)
            #expect(row.bm25Score == -score)
        }
        #expect(outcome.results.suffix(tail.count).allSatisfy { $0.semanticScore == nil })
        let snippets = Dictionary(base.map { ($0.id, $0.snippet) }, uniquingKeysWith: { first, _ in first })
        #expect(outcome.results.allSatisfy { snippets[$0.id] == $0.snippet && $0.snippet.contains("<b>") },
                "each row keeps the keyword search's snippet")
        #expect(outcome.disclosure.rankedWithin == base.count)
        #expect(outcome.disclosure.unscoredCandidates == SemanticSetFixture.plantedWithoutShard)
        #expect(outcome.beyondLibrary.isEmpty)
    }

    @Test("The gate narrows the members before ranking, and the other filters narrow the ranked list after")
    func gateBeforeAndFiltersAfter() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SemanticLayer-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let (backend, service) = try await makeBackend(in: directory)
        let base = try await keywordBase(service)
        let admitted = Array(base.map(\.id).prefix(5))

        let gated = try await backend.rerank(query: "q", base: base,
                                             parameters: SearchParameters(documentIds: admitted))
        #expect(Set(gated.results.map(\.id)) == Set(admitted), "only the members the gate admits")
        #expect(gated.disclosure.rankedWithin == admitted.count)

        let scoped = try await backend.rerank(
            query: "q", base: base,
            parameters: SearchParameters(volumeIds: [SemanticSetFixture.held], documentIds: base.map(\.id)))
        #expect(scoped.results.allSatisfy { $0.volumeId == SemanticSetFixture.held })
        #expect(scoped.disclosure.filtersApplied)
        #expect(scoped.disclosure.filteredOut == base.count - scoped.results.count)
    }
}

// MARK: - Swap (#1577 lane 7)

/// A trail row's every field, so that a row read before a swap can be compared with the row after it.
private struct TrailRow: Equatable {
    let id: UUID
    let queryText: String
    let resultCount: Int
    let loadedCount: Int?
    let matchCount: Int?
    let fetchLimit: Int?
    let scopeSignature: String?
    let renderedExpression: String?
    let executedAt: Date?

    init(_ entry: SearchHistoryEntry) {
        id = entry.id
        queryText = entry.queryText
        resultCount = entry.resultCount
        loadedCount = entry.loadedCount
        matchCount = entry.matchCount
        fetchLimit = entry.fetchLimit
        scopeSignature = entry.scopeSignature
        renderedExpression = entry.renderedExpression
        executedAt = entry.executedAt
    }

    /// Every row of the trail, oldest first.
    @MainActor
    static func all(in context: ModelContext) throws -> [TrailRow] {
        try context.fetch(FetchDescriptor<SearchHistoryEntry>()).map(TrailRow.init)
            .sorted { ($0.executedAt ?? .distantPast) < ($1.executedAt ?? .distantPast) }
    }
}

/// ``LayerMeaningSearch`` with a Meaning run that waits, while ``holding``, until the test lets it go: a swap's first
/// search, when it is the Meaning list's, is then under way while the test acts.
@MainActor
private final class HeldMeaningSearch: MeaningSearchRunning {

    /// Whether the next run waits for ``release()``.
    var holding = false
    /// Whether the next ranking of a held list waits for ``release()``.
    var holdingRanking = false
    private var waiting: CheckedContinuation<Void, Never>?
    private(set) var runs = 0
    private(set) var reranks = 0
    private let ranking = LayerMeaningSearch()

    /// The scores a ranking gives, by key.
    var rankScores: [String: Double] {
        get { ranking.rankScores }
        set { ranking.rankScores = newValue }
    }

    func run(query: String, parameters: SearchParameters) async throws -> SemanticSearchBackend.Outcome {
        runs += 1
        if holding { await withCheckedContinuation { waiting = $0 } }
        return try await ranking.run(query: query, parameters: parameters)
    }

    func rerank(query: String, base: [SearchResult],
                parameters: SearchParameters) async throws -> SemanticSearchBackend.Outcome {
        reranks += 1
        if holdingRanking { await withCheckedContinuation { waiting = $0 } }
        return try await ranking.rerank(query: query, base: base, parameters: parameters)
    }

    /// Lets the run or the ranking that waits go on.
    func release() {
        holding = false
        holdingRanking = false
        waiting?.resume()
        waiting = nil
    }
}

/// Swap, through the iPhone and iPad view model (#1577 lane 7), on lane 4's fixture and stand-in engine: the two
/// queries change places, the list is the one built by hand in the other order, and the trail rows written before the
/// swap stay as they were, each of the swap's two searches writing one of its own.
///
/// Version history:
///   1.0 — #1577 lane 7: initial implementation
@Suite("Search within results: Swap, through the iPhone and iPad view model (#1577 lane 7)")
@MainActor
struct SearchLayerSwapModelTests {

    private static let question = "how did the embassy report"

    /// A view model, its stand-in engine scoring a ranking by `scores`, and the trail it records in.
    private func screen(scores: [String: Double] = [:]) async throws
        -> (dir: URL, vm: SearchViewModel, engine: HeldMeaningSearch, record: () -> Void, context: ModelContext,
            container: ModelContainer) {
        let (dir, vm) = try await LayerFixture.makeViewModel()
        let engine = HeldMeaningSearch()
        engine.rankScores = scores
        vm.semanticBackend = engine
        let (container, context, defaults) = try makeTrail()
        let record = { vm.recordSearchHistory(projectId: nil, indexedVolumeCount: 1, in: context, defaults: defaults) }
        return (dir, vm, engine, record, context, container)
    }

    /// `query` searched through `mode`, recorded as `SearchView.runSearch()` records it.
    private func run(_ query: String, as mode: SearchMode, in vm: SearchViewModel, recording record: () -> Void) async {
        vm.searchMode = mode
        vm.keywords = query
        if await vm.search() { record() }
    }

    /// The list a reader builds by hand: `listQuery` through `listEngine`, held, and `layerQuery` searched inside it.
    private func builtByHand(listQuery: String, through listEngine: SearchMode, layerQuery: String,
                             scores: [String: Double], sortOrder: SearchSortOrder = .relevance) async throws
        -> (dir: URL, vm: SearchViewModel) {
        let (dir, vm) = try await LayerFixture.makeViewModel()
        let engine = LayerMeaningSearch()
        engine.rankScores = scores
        vm.semanticBackend = engine
        vm.sortOrder = sortOrder
        vm.searchMode = listEngine
        vm.keywords = listQuery
        await vm.search()
        try #require(vm.holdBase(meaningAvailable: true) != nil, "precondition: the list built by hand can be held")
        vm.keywords = layerQuery
        await vm.search()
        return (dir, vm)
    }

    /// The swapped screen against the one built by hand: the rows, their order, scores and snippets, and every figure.
    private func expectTheSameList(_ swapped: SearchViewModel, as hand: SearchViewModel) {
        #expect(swapped.results.map(\.id) == hand.results.map(\.id), "the rows, in the order built by hand")
        #expect(swapped.results.map(\.semanticScore) == hand.results.map(\.semanticScore))
        #expect(swapped.results.map(\.snippet) == hand.results.map(\.snippet))
        #expect(swapped.executedRoute == hand.executedRoute)
        #expect(swapped.resultSetScope == hand.resultSetScope, "the header, the ceiling, the total and the counts")
        #expect(swapped.pinnedBase?.rowDescription == hand.pinnedBase?.rowDescription)
        #expect(swapped.pinnedBase?.memberKeys == hand.pinnedBase?.memberKeys)
        #expect(swapped.lastRenderedExpression == hand.lastRenderedExpression)
        #expect(swapped.searchMode == hand.searchMode && swapped.sortOrder == hand.sortOrder)
    }

    @Test("Swap turns words found in a Meaning list into every result for the words, closest to the question first")
    func wordsFoundInAListSwapIntoARanking() async throws {
        let scores = [LayerFixture.key(4): 0.9, LayerFixture.key(1): 0.8]
        let (dir, vm, engine, record, context, container) = try await screen(scores: scores)
        defer { try? FileManager.default.removeItem(at: dir); _ = container }
        await run(Self.question, as: .meaning, in: vm, recording: record)
        vm.holdBase(meaningAvailable: true)
        vm.keywords = "quillon"
        #expect(await vm.search())
        record()
        #expect(vm.resultSetScope.headerDescription == "3 of your 10 closest matches contain these words",
                "precondition: the words were found in the Meaning list")
        let before = try TrailRow.all(in: context)
        #expect(before.count == 2, "precondition: the list's row and the layer's")
        // Words typed since and not searched for: the swap runs the words that ran.
        vm.keywords = "quillon file"
        let swap = try #require(vm.layerSwap, "the row offers Swap once a search has run inside the list")
        #expect(swap.direction == .rankByMeaning && swap.listQuery == "quillon" && swap.layerQuery == Self.question)

        // The swap's second search, the ranking, held, to read the row while it runs.
        engine.holdingRanking = true
        let swapping = Task { await vm.swapLayer(meaningAvailable: true, recording: record) }
        for _ in 0..<400 where engine.reranks == 0 { await Task.yield() }
        try #require(engine.reranks == 1, "precondition: the swap's ranking is under way")
        #expect(vm.pinnedBase?.query == "quillon" && vm.swapUnderWay == nil,
                "once the new list is held the row names it, and its close button acts")
        #expect(vm.layerSwap == nil, "Swap waits for the ranking: nothing has run inside the new list yet")
        engine.release()
        #expect(await swapping.value)

        // The two queries have changed places.
        let held = try #require(vm.pinnedBase, "the swap holds the words' own results")
        #expect(held.kind == .keywords && held.query == "quillon" && held.direction == .rankByMeaning)
        #expect(held.rowDescription == "Within 3 results for “quillon”", "the words that ran, not those typed since")
        #expect(vm.searchMode == .meaning && vm.keywords == Self.question, "the field asks the list's question")
        #expect(vm.executedRoute == .rankedByMeaning(unranked: 1))
        #expect(vm.resultSetScope.headerDescription == "3 results · 2 ranked · 1 not ranked")
        #expect(vm.results.map(\.documentId) == ["d4", "d1", "d7"], "closest first, the one not ranked last")
        #expect(vm.swapUnderWay == nil)

        // The list built by hand in the other order.
        let (handDir, hand) = try await builtByHand(listQuery: "quillon", through: .keywords,
                                                    layerQuery: Self.question, scores: scores)
        defer { try? FileManager.default.removeItem(at: handDir) }
        expectTheSameList(vm, as: hand)

        // The rows written before the swap are as they were, and each of the swap's two searches wrote its own.
        let after = try TrailRow.all(in: context)
        for row in before { #expect(after.contains(row), "the row for “\(row.queryText)” changed") }
        let added = after.filter { row in !before.contains { $0.id == row.id } }
        #expect(added.map(\.queryText) == ["quillon", Self.question])
        let list = try #require(added.first?.scopeSignature)
        #expect(list.hasPrefix("mode=") && !list.contains("base="), "the words' own search, across the library")
        #expect(added.first?.matchCount == 3)
        let layer = try #require(added.last?.scopeSignature)
        #expect(layer.hasPrefix("route=semantic") && layer.hasSuffix(";base=keywords:3:quillon"))
        #expect(added.last?.matchCount == 3, "the ranking recorded whole")
    }

    @Test("Swap turns a ranking into the list's words found in the question's closest matches")
    func aRankingSwapsIntoWordsFound() async throws {
        let scores = [LayerFixture.key(7): 0.9, LayerFixture.key(1): 0.8]
        let (dir, vm, engine, record, context, container) = try await screen(scores: scores)
        defer { try? FileManager.default.removeItem(at: dir); _ = container }
        vm.sortOrder = .dateAscending
        await run("quillon", as: .keywords, in: vm, recording: record)
        vm.holdBase(meaningAvailable: true)
        #expect(vm.sortOrder == .relevance, "precondition: a ranking is read closest first")
        vm.keywords = "which talks failed"
        #expect(await vm.search())
        record()
        #expect(vm.resultSetScope.headerDescription == "3 results · 2 ranked · 1 not ranked", "precondition: a ranking")
        let before = try TrailRow.all(in: context)

        #expect(await vm.swapLayer(meaningAvailable: true, recording: record))

        let held = try #require(vm.pinnedBase)
        #expect(held.kind == .meaning && held.query == "which talks failed" && held.direction == .wordsInMatches)
        #expect(vm.searchMode == .keywords && vm.keywords == "quillon", "the field holds the list's words")
        #expect(engine.runs == 1, "the question was asked of the library once, for the new list")
        #expect(vm.executedRoute == .wordsInMatches(base: LayerFixture.count))
        #expect(vm.resultSetScope.headerDescription == "3 of your 10 closest matches contain these words")
        #expect(vm.sortOrder == .dateAscending, "the reader's sort, which the ranking had set aside, is back")

        let (handDir, hand) = try await builtByHand(listQuery: "which talks failed", through: .meaning,
                                                    layerQuery: "quillon", scores: scores, sortOrder: .dateAscending)
        defer { try? FileManager.default.removeItem(at: handDir) }
        expectTheSameList(vm, as: hand)

        let after = try TrailRow.all(in: context)
        for row in before { #expect(after.contains(row), "the row for “\(row.queryText)” changed") }
        let added = after.filter { row in !before.contains { $0.id == row.id } }
        #expect(added.map(\.queryText) == ["which talks failed", "quillon"])
        let list = try #require(added.first?.scopeSignature)
        #expect(list.hasPrefix("route=semantic") && !list.contains("base="), "the question's own search")
        let layer = try #require(added.last?.scopeSignature)
        #expect(layer.hasPrefix("mode=") && layer.hasSuffix(";base=meaning:10:which%20talks%20failed"))
    }

    /// The trap a swap sets the anchor aside for: the layer's words equal the list's question, so whichever row is left
    /// anchored, the layer's or, given back, the list's, the swap's first search would rewrite it.
    @Test("A swap whose two searches share their words keeps both earlier rows as they were")
    func aSwapOfOneWordKeepsBothRows() async throws {
        let (dir, vm, _, record, context, container) = try await screen(scores: [LayerFixture.key(2): 0.9])
        defer { try? FileManager.default.removeItem(at: dir); _ = container }
        await run("containment", as: .meaning, in: vm, recording: record)
        vm.holdBase(meaningAvailable: true)
        vm.keywords = "containment"
        #expect(await vm.search())
        record()
        let before = try TrailRow.all(in: context)
        #expect(before.count == 2 && before.allSatisfy { $0.queryText == "containment" },
                "precondition: the list's row and the layer's, of one word")

        #expect(await vm.swapLayer(meaningAvailable: true, recording: record))

        let after = try TrailRow.all(in: context)
        #expect(after.count == 4, "each of the swap's searches wrote a row of its own")
        for row in before { #expect(after.contains(row), "a row written before the swap changed") }
        #expect(vm.pinnedBase?.kind == .keywords && vm.executedRoute == .rankedByMeaning(unranked: LayerFixture.count - 1))
    }

    @Test("No swap before a search has run inside the list, after the field is emptied, or over a failed search")
    func whenTheRowOffersNoSwap() async throws {
        let (dir, vm, _, record, _, container) = try await screen()
        defer { try? FileManager.default.removeItem(at: dir); _ = container }
        await run(Self.question, as: .meaning, in: vm, recording: record)
        #expect(vm.layerSwap == nil, "no list held")
        vm.holdBase(meaningAvailable: true)
        #expect(vm.layerSwap == nil, "the list's own rows: nothing has run inside it")
        let ranNothing = await vm.swapLayer(meaningAvailable: true, recording: record)
        #expect(!ranNothing && vm.pinnedBase?.kind == .meaning, "a swap with nothing to swap leaves the list held")
        vm.keywords = "quillon"
        await vm.search()
        #expect(vm.layerSwap != nil)
        vm.keywords = "NOT korea"  // a query the parse refuses (`SearchQueryRefusalTests`)
        await vm.search()
        #expect(vm.searchError != nil && vm.layerSwap == nil, "a refused search has nothing to swap")
        vm.keywords = ""
        #expect(vm.fieldEmptiedInsideBase())
        #expect(vm.layerSwap == nil, "the field emptied: the list's own rows again")
    }

    /// A search under way inside the list has its words submitted before its rows arrive, so the rows on screen are still
    /// the last layer's: a swap then would pair the one's words with the other's rows.
    @Test("No swap while a search runs inside the list, whose words have listed nothing yet")
    func noSwapWhileASearchRuns() async throws {
        let (dir, vm, engine, record, context, container) = try await screen(scores: [LayerFixture.key(7): 0.9])
        defer { try? FileManager.default.removeItem(at: dir); _ = container }
        await run("quillon", as: .keywords, in: vm, recording: record)
        vm.holdBase(meaningAvailable: true)
        vm.keywords = "which talks failed"
        await vm.search()
        #expect(vm.layerSwap != nil, "precondition: a ranking is on screen")
        engine.holdingRanking = true
        vm.keywords = "which talks succeeded"
        let asking = Task { await vm.search() }
        for _ in 0..<400 where engine.reranks < 2 { await Task.yield() }
        try #require(engine.reranks == 2 && vm.isSearching, "precondition: the second question is under way")
        let rowsBefore = try TrailRow.all(in: context).count
        let swapped = await vm.swapLayer(meaningAvailable: true, recording: record)
        #expect(!swapped, "a swap while a search runs")
        #expect(vm.pinnedBase?.query == "quillon", "the list stays held")
        #expect(try TrailRow.all(in: context).count == rowsBefore, "and nothing ran")
        engine.release()
        #expect(await asking.value)
    }

    /// The new list's search is a search of its own, of other words, so Checklist Mode starts over for it, as it would
    /// by hand: the marks were made on the held list's search (`ChecklistAnchor` is the words a search ran with).
    @Test("A swap's new list is a search of other words: Checklist Mode starts over for it, as by hand")
    func aSwapStartsTheChecklistOver() async throws {
        let scores = [LayerFixture.key(4): 0.9]
        let (dir, vm, _, record, _, container) = try await screen(scores: scores)
        defer { try? FileManager.default.removeItem(at: dir); _ = container }
        await run(Self.question, as: .meaning, in: vm, recording: record)
        vm.setChecklistMode(true)
        vm.markReviewed(volumeId: LayerFixture.volume, documentId: "d4")
        vm.holdBase(meaningAvailable: true)
        vm.keywords = "quillon"
        await vm.search()
        #expect(vm.results.map(\.documentId) == ["d7", "d1"], "precondition: the reviewed d4 is not a member")

        #expect(await vm.swapLayer(meaningAvailable: true, recording: record))
        #expect(vm.markedReviewedKeys.isEmpty, "the new list's search starts the checklist over")
        #expect(vm.results.map(\.documentId) == ["d4", "d1", "d7"], "d4 is ranked with the rest")
    }

    @Test("A swap ends with nothing held where a hand-off comes while its first search runs")
    func aHandOffEndsASwap() async throws {
        let (dir, vm, engine, record, _, container) = try await screen(scores: [LayerFixture.key(7): 0.9])
        defer { try? FileManager.default.removeItem(at: dir); _ = container }
        await run("quillon", as: .keywords, in: vm, recording: record)
        vm.holdBase(meaningAvailable: true)
        vm.keywords = "which talks failed"
        await vm.search()
        engine.holding = true
        let swapping = Task { await vm.swapLayer(meaningAvailable: true, recording: record) }
        for _ in 0..<200 where engine.runs == 0 { await Task.yield() }
        try #require(engine.runs == 1, "precondition: the swap's first search, the question's, is under way")
        #expect(vm.pinnedBase == nil && vm.swapUnderWay?.heldList.query == "quillon",
                "the row goes on naming the list the swap let go of")
        var scopeOnly = SearchParameters()
        scopeOnly.volumeIds = [LayerFixture.volume]
        #expect(!vm.applyHandoff(scopeOnly), "Search this volume runs nothing of its own")
        #expect(vm.swapUnderWay == nil, "a hand-off ends the swap")
        engine.release()
        let swapped = await swapping.value
        #expect(!swapped)
        #expect(vm.pinnedBase == nil, "nothing is held once a hand-off has come")
    }

    @Test("A swap ends with nothing held where the reader's own search replaces its first")
    func aSearchReplacesASwap() async throws {
        let (dir, vm, engine, record, context, container) = try await screen(scores: [LayerFixture.key(7): 0.9])
        defer { try? FileManager.default.removeItem(at: dir); _ = container }
        await run("quillon", as: .keywords, in: vm, recording: record)
        vm.holdBase(meaningAvailable: true)
        vm.keywords = "which talks failed"
        await vm.search()
        record()
        let rowsBefore = try TrailRow.all(in: context).count
        engine.holding = true
        let swapping = Task { await vm.swapLayer(meaningAvailable: true, recording: record) }
        for _ in 0..<200 where engine.runs == 0 { await Task.yield() }
        try #require(engine.runs == 1, "precondition: the swap's first search is under way")
        vm.searchMode = .keywords
        vm.keywords = "containment"
        let mine = Task { await vm.search() }
        engine.release()
        let swapped = await swapping.value
        #expect(await mine.value)
        #expect(!swapped)
        #expect(vm.pinnedBase == nil && vm.swapUnderWay == nil)
        #expect(vm.executedRoute == .keywords && vm.results.count == LayerFixture.count, "the reader's search's rows")
        #expect(try TrailRow.all(in: context).count == rowsBefore, "the replaced search recorded nothing")
    }

    @Test("A swap whose new list finds nothing holds nothing, and shows that search")
    func aSwapThatFindsNothing() async throws {
        let (dir, vm, _, record, context, container) = try await screen()
        defer { try? FileManager.default.removeItem(at: dir); _ = container }
        await run(Self.question, as: .meaning, in: vm, recording: record)
        vm.holdBase(meaningAvailable: true)
        vm.keywords = "zircaloy"
        await vm.search()
        record()
        #expect(vm.results.isEmpty && vm.layerSwap != nil, "precondition: words found nowhere in the list")

        #expect(!(await vm.swapLayer(meaningAvailable: true, recording: record)))
        #expect(vm.pinnedBase == nil && vm.swapUnderWay == nil)
        #expect(vm.executedRoute == .keywords && vm.results.isEmpty && vm.hasSearched,
                "the words' own search, which found nothing either")
        #expect(try TrailRow.all(in: context).map(\.queryText) == [Self.question, "zircaloy", "zircaloy"],
                "the search that ran is recorded")
    }
}

// MARK: - The screen's Swap, read from source (#1577 lane 7)

/// The iPhone and iPad screen's half of Swap, read from source: `SearchWithinResultsTests` taps the row's Swap on both
/// devices, but no run sees the row while a swap's first search is under way, which is a fraction of a second. So the
/// shape is pinned: the row goes on naming the list a swap let go of, with Swap and the ✕ off meanwhile, and Swap is off
/// while any search runs. Each scan matches a call, read with comments set aside.
///
/// Version history:
///   1.0 — #1577 lane 7: initial implementation
@Suite("Search within results: the screen's Swap, read from source (#1577 lane 7)")
struct SearchLayerSwapScreenWiringTests {

    private static func squeezedCode(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined().filter { !$0.isWhitespace }
    }

    private static func squeezed(_ text: String) -> String { text.filter { !$0.isWhitespace } }

    @Test("The row names the list a swap let go of, with its buttons off, and Swap is off while a search runs")
    func theRowDuringASwap() throws {
        let view = try Self.squeezedCode("FRUSExplorer/Search/SearchView.swift")
        #expect(view.contains(Self.squeezed("""
            if let base = vm.pinnedBase ?? vm.swapUnderWay?.heldList {
                SearchLayerBaseRow(base: base,
                                   swap: vm.swapUnderWay ?? vm.layerSwap,
                                   canSwap: vm.swapUnderWay == nil && !vm.isSearching,
                                   canLeave: vm.swapUnderWay == nil,
                                   performSwap: { Task { await swapLayer() } },
                                   leave: { leaveBase() })
            """)), "the row gives way to the Keywords | Meaning control during a swap, or its buttons act")
        let row = try Self.squeezedCode("FRUSExplorer/Search/SearchLayerViews.swift")
        for call in ["if let swap { Button(action: performSwap) {",
                     "Label(SearchLayerCopy.swapTitle, systemImage: SearchLayerCopy.swapGlyph)",
                     ".disabled(!canSwap) .controlHelp(SearchLayerCopy.swapLabel, detail: SearchLayerCopy.swapHelp(swap),",
                     ".accessibilityIdentifier(\"search.layer.swap\") } Button(action: leave) {",
                     ".buttonStyle(.borderless) .disabled(!canLeave)"] {
            #expect(row.contains(Self.squeezed(call)), "the base row lost `\(call)`")
        }
        // VoiceOver hears what a swap will do as it starts; the layer's header follows, as for any layer.
        #expect(view.contains(Self.squeezed("AccessibilityNotification.Announcement(SearchLayerCopy.swapHelp(swap)).post()")))
    }
}
