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

// MARK: - SearchLayerDirection + the engines

/// The engines a layer's direction names, which are the app's `SearchMode`. ``SearchLayerDirection`` moved into
/// FRUSCoreKit for FRUS Explorer Light's S27a; these two stay here, unchanged.
extension SearchLayerDirection {

    /// The engine the field runs while the base is held: the other one from the base's.
    var fieldEngine: SearchMode {
        switch self {
        case .wordsInMatches: return .keywords
        case .rankByMeaning: return .meaning
        }
    }

    /// The engine the base came from, which the Keywords | Meaning control shows again when the
    /// reader leaves the base.
    var baseEngine: SearchMode {
        switch self {
        case .wordsInMatches: return .meaning
        case .rankByMeaning: return .keywords
        }
    }
}

// MARK: - PinnedResultBase + the app

/// What the app sets aside with a held list, and the browse's name, which reads the app's subject store.
/// ``PinnedResultBase`` moved into FRUSCoreKit for FRUS Explorer Light's S27a, where these are a host's: its
/// initialiser takes what the host sets aside as one value, and this one takes the app's two anchors by the labels
/// the memberwise initialiser had, so the view models and the tests build a held list as they did.
///
/// Version history:
///   1.0 — 2026-11-24: FRUS Explorer Light's S27a — the two anchors over the kit's ``PinnedResultBase/setAside``,
///          and `browseName(of:)` moved here unchanged
extension PinnedResultBase {

    /// The app's two anchors, which a held list sets aside and leaving it puts back (rule 5).
    struct AppAnchors: Sendable {
        /// The trail anchor the base's own search left.
        let history: SearchHistoryWriter.Anchor?
        /// The search the base's rows came from, for the checklist and the selection.
        let checklist: ChecklistAnchor?
    }

    /// Creates a held list with the app's two anchors set aside.
    init(direction: SearchLayerDirection, kind: Kind, query: String, rows: [SearchResult], members: [SearchResult],
         hiddenByChecklist: Int, notDownloaded: Int, route: ExecutedSearchRoute, fetchLimit: Int,
         totalMatchCount: Int?, renderedExpression: String?, disclosure: SemanticSearchBackend.Disclosure?,
         beyondLibraryHits: [SemanticSearchBackend.BeyondLibraryHit], userTagCountScope: UserTagCountScope?,
         historyAnchor: SearchHistoryWriter.Anchor?, completedSearchAnchor: ChecklistAnchor?,
         filterSignature: String, describedQuery: String? = nil) {
        self.init(direction: direction, kind: kind, query: query, rows: rows, members: members,
                  hiddenByChecklist: hiddenByChecklist, notDownloaded: notDownloaded, route: route,
                  fetchLimit: fetchLimit, totalMatchCount: totalMatchCount, renderedExpression: renderedExpression,
                  disclosure: disclosure, beyondLibraryHits: beyondLibraryHits, userTagCountScope: userTagCountScope,
                  setAside: AppAnchors(history: historyAnchor, checklist: completedSearchAnchor),
                  filterSignature: filterSignature, describedQuery: describedQuery)
    }

    /// The trail anchor the base's own search left, set aside while a layer runs (rule 5).
    var historyAnchor: SearchHistoryWriter.Anchor? { (setAside as? AppAnchors)?.history }

    /// The search the base's rows came from, for the checklist and the selection.
    var completedSearchAnchor: ChecklistAnchor? { (setAside as? AppAnchors)?.checklist }

    /// What a browse with no words is of, for the row that names it as a held base: the person, the topic or the
    /// subject area its filter names, in that order, or `nil` when none has a name.
    ///
    /// - Parameter parameters: The browse's parameters.
    /// - Returns: The name, or `nil`.
    static func browseName(of parameters: SearchParameters) -> String? {
        let personRef = parameters.personRef?.trimmingCharacters(in: .whitespaces) ?? ""
        if parameters.personRollupId != nil || !personRef.isEmpty,
           let label = parameters.personLabel, !label.isEmpty {
            return label
        }
        if parameters.subjectRef != nil, let name = parameters.subjectName, !name.isEmpty { return name }
        let vocabulary = DocumentSubjectStore.shared?.bucketVocabulary
        if let bucket = parameters.subjectBucketKey.flatMap({ vocabulary?.id(forKey: $0) }) ?? parameters.subjectBucket {
            return vocabulary?.label(at: bucket)
        }
        return nil
    }
}

// MARK: - SearchLayerSwap

/// The held list and the search inside it, swapped (#1577 lane 7): the layer's words or question become a list of their
/// own, and the list's own words or question become the search inside it. The base row's Swap.
///
/// The two orders give different lists (the assessment's §9). Words found in a Meaning list are at most its hundred
/// closest, "7 of your 100 closest matches contain these words", where a question ranking the words' own results lists
/// every document that holds them, "212 results, closest first". Swap turns either into the other without retyping.
///
/// It runs what the reader would run by hand in the other order, and nothing besides: the layer's words or question
/// through its own engine, under the working corpus and the filters in force, as a search of its own; that list held,
/// as Search Within These Results holds one; and the held list's words or question inside it. So the list it shows is
/// the one built by hand in that order, a list cut at its ceiling ranked whole as lane 6 ranks one, and each of the two
/// searches writes a trail row of its own, as by hand. The checklist's marks are the held list's search's, and the new
/// list's search is a search of its own, which Checklist Mode treats as any search: other words start it over.
///
/// ## The trail's anchor is set aside
/// The layer's row is the one the trail writer last wrote, and the new list's search runs the layer's own words or
/// question, so the writer would take it for a re-run and rewrite the layer's row as a search across the library. The
/// held list's anchor, which leaving gives back, names the held list's words, which the swap then searches inside the
/// new list. So a view model sets the anchor aside before the swap's first search, as holding a list sets it aside
/// (rule 5), and every row written before the swap stays as it was.
///
/// ## What a swap needs
/// A layer's rows on screen, since there is nothing to swap before the field has run inside the list, and words or a
/// question on each side: a browse has none of its own (a person's mentions, a subject area), nor does a list found by a
/// restored phrase or prefix with nothing typed, whose words are a filter's and not the field's.
///
/// Version history:
///   1.0 — #1577 lane 7: initial implementation
struct SearchLayerSwap: Sendable {

    /// The list held when the swap began, which the row goes on naming until the new list is held, so that the row
    /// does not give way to the Keywords | Meaning control while the new list's search runs.
    let heldList: PinnedResultBase
    /// The way the search inside the new list runs: the other way from the held list's.
    let direction: SearchLayerDirection
    /// The words or question the new list is found by: the layer's, as it ran.
    let listQuery: String
    /// The words or question searched inside the new list: the held list's own.
    let layerQuery: String

    /// The engine the new list's own search runs through, which is the one the field ran inside the held list.
    var listEngine: SearchMode { direction.baseEngine }

    /// The swap of `heldList` and the layer on screen over it, or `nil` where none can be made.
    ///
    /// - Parameters:
    ///   - heldList: The held list.
    ///   - route: The route that produced the rows on screen: a layer's, or there is nothing to swap.
    ///   - layerQuery: The words or question the rows on screen ran with (the submitted query, not the live field).
    init?(heldList: PinnedResultBase, route: ExecutedSearchRoute, layerQuery: String) {
        let layer = layerQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let own = heldList.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard route.isLayer, !layer.isEmpty, !own.isEmpty else { return nil }
        self.heldList = heldList
        self.direction = heldList.direction.swapped
        self.listQuery = layer
        self.layerQuery = own
    }

    /// Whether the rows on screen are the new list's own search: a list its engine gives, found by its words or
    /// question. The swap holds that list and goes on; anything else on screen, a search the reader ran meanwhile or a
    /// hand-off's, ends it.
    ///
    /// - Parameters:
    ///   - route: The route that produced the rows on screen.
    ///   - query: The words or question those rows ran with.
    /// - Returns: Whether they are the new list.
    func isAnswered(by route: ExecutedSearchRoute, query: String) -> Bool {
        SearchLayerDirection.starting(over: route) == direction
            && query.trimmingCharacters(in: .whitespacesAndNewlines) == listQuery
    }
}

// MARK: - AnsweredSearchTrigger

/// A search the rows on screen already answer (#1577 lane 5), which the Mac's window then does not run.
///
/// The Mac's Search window runs a search whenever its trigger changes: the engine, the submitted words or the filters'
/// version. Leaving a held list puts back its engine and its words, which changes the trigger, though the list's own
/// rows are already back on screen from memory: run, the search would fetch them again, flash "Searching…" and, for a
/// Meaning list, encode the question again. So the view model records the trigger its restored rows answer, and the
/// search the window's task starts for it does nothing. Any other trigger, a filter edited before the task ran
/// included, is searched as always.
///
/// Version history:
///   1.0 — #1577 lane 5: initial implementation
struct AnsweredSearchTrigger: Equatable, Sendable {

    /// The trigger the rows on screen answer, until a search asks about it.
    private var trigger: String?

    /// Records that the rows on screen answer `trigger`.
    ///
    /// - Parameter trigger: The window's trigger as the rows were put back.
    mutating func answer(_ trigger: String) {
        self.trigger = trigger
    }

    /// Whether the rows on screen answer the search `trigger` asks for. True once, for the trigger answered last;
    /// asking about any trigger forgets the answer, so a later search of the same words runs.
    ///
    /// - Parameter trigger: The trigger of the search about to run.
    /// - Returns: Whether that search has nothing to do.
    mutating func consume(_ trigger: String) -> Bool {
        defer { self.trigger = nil }
        return self.trigger == trigger
    }
}

// MARK: - ResultSetScope + layers

extension ResultSetScope {

    /// This scope with what a layer's sentences owe, from the held list and the layer's run (#1577 lanes 4 and 5).
    /// The one place either view model says them, so that the Mac's window, which no test runs, says what the iPhone's
    /// tested view model says.
    ///
    /// - Words found in a list, and a ranking: whether filters chosen since narrow them
    ///   (``layerFiltersNarrowed``), and the list a capture names beside the layer's text (``layerBaseLabel``).
    /// - A ranking: whether the list was cut at its fetch (``layerBaseWasCut``), and the rows the checklist hid when it
    ///   was held (``layerBaseHiddenByChecklist``). A ranking's rows can be fewer than its list's with nothing cut:
    ///   those the checklist hid, and those a filter chosen since removes (lane 4's review).
    /// - Every route: whether the list is in its own order (``listIsInRankOrder``), which only a ranking's header reads.
    ///
    /// - Parameters:
    ///   - base: The held list, or `nil`.
    ///   - filtersNarrowed: Whether filters narrowed the last layer, as its run recorded
    ///     (`PinnedResultBase.filtersNarrow(_:)`).
    ///   - sortOrder: The order the list is shown in.
    /// - Returns: The scope.
    func describingLayer(over base: PinnedResultBase?, filtersNarrowed: Bool,
                         sortOrder: SearchSortOrder) -> ResultSetScope {
        var scope = self
        var ranking = false
        if case .rankedByMeaning = route { ranking = true }
        scope.layerFiltersNarrowed = route.isLayer && filtersNarrowed
        scope.listIsInRankOrder = sortOrder == .relevance
        scope.layerBaseLabel = route.isLayer ? base?.captureLabel : nil
        scope.layerBaseWasCut = ranking ? base?.wasCut : nil
        scope.layerBaseHiddenByChecklist = ranking ? base?.hiddenByChecklist ?? 0 : 0
        return scope
    }
}

// MARK: - SearchScopeSignature + the app

// `SearchScopeSignature` moved to FRUSCoreKit for FRUS Explorer Light (S17b), where the method appendix
// that reads it went too: `FRUSCoreKit/Search/SearchScopeSignature.swift`. These two keep the app's
// calls as they were, passing what the kit takes as parameters.
extension SearchScopeSignature {

    /// The signature a search inside a held base records (#1577 lane 4), or `signature` itself outside
    /// one: the kit's ``SearchScopeSignature/layered(_:parameters:basePart:)``, with the base's `base=`
    /// part (``PinnedResultBase/signaturePart``).
    ///
    /// - Parameters:
    ///   - signature: The route's own signature (a Meaning run's), or `nil` for a keyword run.
    ///   - parameters: The executed parameters.
    ///   - base: The held base, or `nil` outside one.
    /// - Returns: The signature to record, or `nil` to let the writer derive the keyword one.
    static func layered(_ signature: String?, parameters: SearchParameters,
                        base: PinnedResultBase?) -> String? {
        layered(signature, parameters: parameters, basePart: base?.signaturePart)
    }

    /// A recorded signature as the method appendix's prose, the kit's
    /// ``SearchScopeSignature/describe(_:resources:locale:)`` over the app's bundled data files and the
    /// reader's locale.
    ///
    /// - Parameter signature: a string produced by ``SearchScopeSignature/signature(for:)``.
    /// - Returns: the phrases describing the scope, or `nil` if `signature` does not parse.
    static func describe(_ signature: String) -> [String]? {
        describe(signature, resources: .bundled, locale: .autoupdatingCurrent)
    }
}
