// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

#if os(macOS)

import Foundation
import Observation
import SwiftData

// `SearchSortOrder` now lives in FRUSCoreKit's SearchSortOrder.swift (shared with the iOS SearchView,
// #305, and with FRUS Explorer Light).

// MARK: - MacSearchViewModel

/// Owns all state for the macOS Search sheet.
///
/// ## Submit-Only Search
/// `queryText` is the live text-field buffer and never triggers a search on its own.
/// A search fires only when the user presses Return, which calls `submitSearch()` and
/// sets `submittedQuery = queryText`. `searchTrigger` derives from `submittedQuery` and
/// `parametersVersion`; a `.task(id: searchTrigger)` in `SearchSheet` calls
/// `performSearch` whenever the trigger changes.
///
/// Filter changes (scope toggles, advanced filter sheet apply) bump `parametersVersion`,
/// which changes `searchTrigger` and re-runs `performSearch` against the **already-
/// submitted** query. If no query has been submitted yet (`submittedQuery` is empty),
/// `performSearch` short-circuits harmlessly.
///
/// ## Filter State
/// Two-tier filter model:
/// - Basic scope toggles (`scopeDocuments`, `scopeNotes`, `scopeSummaries`) project
///   directly into `parameters`.
/// - Advanced filter state lives in `filterVM` (`SearchViewModel`), which is presented
///   via `SearchFilterView` in a live popover (UI audit C4). The presenter calls
///   `applyAdvancedFilters()` on each `filterVM.advancedFilterSignature` change to copy
///   `filterVM` values into `parameters` and trigger re-search immediately.
///
/// ## Sorting and Pagination
/// Sorting is applied client-side on all results. `pagedResults` slices `allSortedResults`
/// by `pageSize`/`currentPage`. `performSearch` fetches up to 7,500 results so that all
/// pages are available without a server round-trip. `totalMatchCount` is fetched in
/// parallel via `SearchService.searchCount` and represents the true uncapped match count
/// — when it exceeds `results.count`, the UI surfaces an over-cap advisory.
///
/// ## Search-in Scope Toggles
/// `scopeDocuments`, `scopeNotes`, and `scopeSummaries` mirror
/// `SearchParameters.includeDocumentText`/`includeSummaries`/`includeNotes`. Toggling a
/// scope chip is equivalent to toggling the corresponding scope checkbox in the advanced
/// filter sheet. If all three scopes are disabled `performSearch` short-circuits with a
/// friendly error rather than asking the FTS5 layer to throw `emptyQuery`.
///
/// ## Naming
/// Named `MacSearchViewModel` to distinguish from the existing iOS `SearchViewModel`
/// in `Search/SearchViewModel.swift`. The iOS revamp will reconcile these.
///
/// Version history:
///   1.0 — New UI scaffolding (macOS-only; iOS revamp will unify)
///   1.1 — Add pagination, parametersVersion, filterVM bridge, advanced filter sync
///   1.2 — Session 120: raise cap from 500 → 7,500; add `totalMatchCount`; wire
///          `scopeDocuments` to `includeDocumentText`; clamp `currentPage` when results
///          shrink; gate empty-scope searches with a friendly error
///   1.3 — Session 121: add `submitSearch()` so `.onSubmit` bypasses debounce instead of
///          spawning a parallel Task; fix `performSearch` catch to skip result-clearing on
///          `CancellationError` (prevents flash of empty results when task is superseded)
///   1.4 — Session 129: remove 300 ms auto-debounce from `queryText.didSet`; rename
///          `debouncedQuery` → `submittedQuery`; `performSearch` reads `submittedQuery`
///          so queries never fire before the user presses Return; filter/scope changes
///          re-run the previously submitted query (not the live text-field buffer)
///   1.5 — Session 163: `syncToFilterVM` now loads the volume/subseries picker options
///          and reconstructs the picker selection from `parameters.volumeIds`;
///          `applyAdvancedFilters` writes `filterVM.effectiveVolumeIds` back into
///          `parameters.volumeIds` so the new advanced-filter volume pickers apply.
///   1.6 — Session 2026-07-04 (macOS UI audit C4): `applyAdvancedFilters` is now
///          called live per filter edit (signature observation in the popover host)
///          instead of once in the removed sheet's `onDismiss` batch.
///   1.7 — #1298 follow-up: both checklist re-anchor gates (`performSearch`, `performMeaningSearch`)
///          decide "same query" through `SearchHistoryWriter.isSameQuery(_:_:)` rather than `!=`, so
///          re-submitting `“cold war”` as `"cold war"` no longer clears the reviewed marks while the
///          history writer refreshes one row. The comment claiming the gate mirrors `historyAnchor`
///          had stopped being true when #1298 folded the writer's comparison.
///   1.8 — #1299: `performSearch` stores `SearchQueryRefusal.readable(error, for: frozenParams)` rather than the raw
///          error, so a refused query carries the same readable message as iOS, and the Search window shows it:
///          `SearchSheet` 1.19 renders `searchError` through `searchErrorView` (before it, the window only gated the
///          zero-result state on the error, and every failure was an empty list). Because that view shows ANY standing
///          error while the results are empty, the empty-query guards in `performSearch` and `performMeaningSearch`
///          clear `searchError` too — a refused `-korea` followed by Return on a cleared field left the refusal
///          message under the empty field (#1299 follow-up).
///   1.9 — #1584, #1595, #1596, #1598: `resultSetScope` is composed here, from `lastFetchLimit` and the new
///          `resultsAreSemantic`, both now written with the rows; `isResultSetTruncated` asks it, so a full
///          Meaning list is no longer flagged as truncated; `applyHandoff(_:)` runs a hand-off that names a
///          search as a keyword search; the engine is held as `MeaningSearchRunning`
///   1.10 — #1577 lane 2: `executedRoute`, an `ExecutedSearchRoute`, is what is written with the rows, and
///          `resultsAreSemantic` reads it; `offersReadings` is the readings' door, asked of the field's engine and
///          of the rows' route
///   1.11 — FRUS Explorer Light: `allSortedResults` is `SearchSortOrder.sorted(_:)`, the kit's date order, which
///          the iOS view model and the web edition sort by too; this file's copy of the comparator is gone
///   1.12 — #1646: `applyParameters(_:)` runs a hand-off or a recalled search inside the applied working corpus
///          (`SearchParameters.runningInside(workingCorpus:)`), and brings the filter view model to the new parameters
///          (`mirrorParameters(into:)`, split out of `syncToFilterVM`); `leaveWorkingCorpus()` is the banner's ✕, and
///          derives the document gate alone. #1648: `performSearch(service:)` numbers its run (`SearchRunLedger`), asks
///          once after its last wait whether a later run has replaced it, writes nothing if one has, and returns `true`
///          when none has; the rebuilt index calls `replaceSearchesUnderWay()`
///   1.13 — #1680: a run whose task the window cancels writes nothing. The kit stops its search and throws
///          `CancellationError`, on which `performSearch(service:)` returns `false`, and a run whose count alone was
///          stopped, after its rows came back, returns at `guard !Task.isCancelled` after its last wait
///   1.14 — #1577 lane 5: Search Within These Results. `holdBase(meaningAvailable:)` holds the list on screen as a
///          `PinnedResultBase`, built from `displayedResults` by the rules iPhone and iPad hold one by; the field then
///          runs the other engine inside it, words through `performSearch`'s keyword path and a question through
///          `rankHeldList(run:base:backend:)`. The held list joins the gate where the value a search runs with is
///          built (`LayeredResultComposer.gating(_:inside:)`) and never `parameters`, so the filter summary and the
///          token caption do not name it. Holding clears the submitted words with the field, and an empty field
///          inside a held list shows its rows; `leaveBase()` puts the list back with no search
///          (`AnsweredSearchTrigger`) unless a filter changed since. Every hand-off leaves the held list, and a layer
///          keeps the checklist's anchor. #1683: the checklist's marks wait for the rows of the search they belong to
///          (`canMarkReviewed`)
///   1.15 — #1577 lane 6: a question over a list held at its 7,500-row ceiling ranks the list's whole match
///          (`rankWholeMatch(run:base:match:backend:)`), as on iPhone and iPad, and the trail signs the documents it
///          ranked inside
@Observable
@MainActor
final class MacSearchViewModel {

    // MARK: - Input State

    /// Live text-field buffer. Does **not** trigger a search on its own.
    /// Call `submitSearch()` (bound to `.onSubmit`) to commit this value to
    /// `submittedQuery` and fire a search.
    var queryText: String = ""

    /// The last query string committed by `submitSearch()` or `applyParameters(_:)`.
    /// `searchTrigger` derives from this value, so only committed queries drive searches.
    var submittedQuery: String = ""

    // MARK: - Scope toggles

    /// Whether full document text (header, dateline, source note, body) is searched.
    /// Mirrors `parameters.includeDocumentText`. Toggling this off is equivalent to
    /// unchecking "Document text" in the advanced filter sheet.
    var scopeDocuments: Bool = true {
        didSet {
            parameters.includeDocumentText = scopeDocuments
            filterVM?.includeDocumentText = scopeDocuments
            parametersVersion += 1
        }
    }

    var scopeNotes: Bool = true {
        didSet {
            parameters.includeNotes = scopeNotes
            filterVM?.includeNotes = scopeNotes
            parametersVersion += 1
        }
    }

    var scopeSummaries: Bool = true {
        didSet {
            parameters.includeSummaries = scopeSummaries
            filterVM?.includeSummaries = scopeSummaries
            parametersVersion += 1
        }
    }

    // `scopeCollections` was removed with its chip (UI review M-10). It was a stored property
    // nothing ever read: no `didSet`, no projection into `parameters`, no reader but the chip's
    // own binding.
    //
    // **COLLECTION SEARCH WAS DESIGNED AND DECLINED BY THE OWNER, 2026-09-10.** Nothing here is
    // waiting on a re-add, and the re-add instruction this comment used to carry was wrong twice —
    // recorded because both errors would have been believed:
    //
    //  1. `includeCollections` HAS NEVER EXISTED. `git log -S'includeCollections' --all` returns
    //     exactly one commit, `0e821faa` — the one that coined the word inside this comment and
    //     its twin in `SearchSheet`. Nothing was ever removed under that name.
    //  2. A collection scope is not a sibling of the three toggles above. Those are FTS5 COLUMN
    //     SELECTORS (`SearchModels.swift`: "they select which FTS5 columns are matched"), and
    //     NEITHER FTS5 table has a collection column — both are `content='document_cache'`, keyed
    //     `(volume_id, document_id)`. Collections live in SwiftData; the index has never heard of
    //     them. Scoping to one would be a document-ID set — resolved through
    //     `WorkingCorpusResolver`, composed by `DocumentScopeGate.combine`, landing in the
    //     existing `SearchParameters.documentIds` beside the working corpus and the project
    //     History gate. No new `Bool`, no new `didSet`, and no change to this file's shape.

    // MARK: - Initialisation

    /// Applies the user-configured search defaults (`SearchDefaults`, set in
    /// Settings → Search) to the scope toggles, the type filter, and the
    /// underlying `parameters`. Property observers do not fire during
    /// initialisation, so `parameters` is updated explicitly.
    init() {
        let documents = SearchDefaults.scopeDocuments
        let notes     = SearchDefaults.scopeNotes
        let summaries = SearchDefaults.scopeSummaries
        let typeFilter = SearchDefaults.documentTypeFilter
        scopeDocuments = documents
        scopeNotes     = notes
        scopeSummaries = summaries
        parameters.includeDocumentText = documents
        parameters.includeNotes        = notes
        parameters.includeSummaries    = summaries
        parameters.documentTypeFilter  = typeFilter
    }

    // MARK: - Filter Parameters

    var parameters: SearchParameters = SearchParameters()

    /// Triggers a re-search whenever any filter changes. Observed via `searchTrigger`.
    var parametersVersion: Int = 0

    /// Combined token for `.task(id:)` — changes when the submitted query, any filter, or the
    /// SEARCH MODE changes (a mode flip re-runs the standing query through the other engine).
    /// Does **not** change when the user is merely typing in the text field; only
    /// `submitSearch()` (Return key) updates `submittedQuery`.
    var searchTrigger: String { "\(searchMode.rawValue)|\(submittedQuery)|\(parametersVersion)" }

    // MARK: - Meaning mode (V-5 hybrid page) — the iOS twin's block, mirrored

    /// Which engine a submitted search runs through. Per-session; see `SearchMode`. A change ends
    /// a selection, whoever makes it: the rows are the other engine's (#1576 lane 4).
    var searchMode: SearchMode = .keywords {
        didSet { if searchMode != oldValue { endSelecting() } }
    }

    /// The Meaning mode's engine, injected by `SearchSheet` once the semantic stack has booted.
    /// Held as ``MeaningSearchRunning`` so a test can drive a Meaning run with a list of its own.
    var semanticBackend: (any MeaningSearchRunning)?

    /// Hits beyond the indexed library from the last Meaning search (#262 presentation).
    var beyondLibraryHits: [SemanticSearchBackend.BeyondLibraryHit] = []

    /// The Meaning mode's disclosure counts, or `nil` outside the mode.
    var semanticDisclosure: SemanticSearchBackend.Disclosure?

    /// Set when a Meaning search found no model on device — the offer cue, not an error.
    var semanticNeedsModel = false

    /// Whether the last completed run was a Meaning run — frozen for the history record.
    private(set) var lastRunWasSemantic = false

    /// The route that produced the rows in `results` (#1595, #1598; a route and not a flag since
    /// #1577 lane 2).
    ///
    /// Written in the statements that assign `results`, so it describes the rows on screen: while a run
    /// is under way after a mode switch, `searchMode` and `lastRunWasSemantic` already name the new
    /// engine and the rows are still the last one's. ``resultSetScope`` reads this one, and so does
    /// whatever else describes the rows: the facet panel's counts and ``offersReadings``.
    private(set) var executedRoute: ExecutedSearchRoute = .keywords

    /// Whether the rows in `results` were ranked by a Meaning run: a read of ``executedRoute``.
    var resultsAreSemantic: Bool { executedRoute == .meaning }

    /// Whether the Timeline, Concordance and Collocates readings are offered (#1577 lane 2).
    ///
    /// Two conditions, and the door needs both. The rows on screen are a keyword match's own
    /// (`ExecutedSearchRoute.offersReadings`): after a switch back from Meaning, until the keyword
    /// rows arrive, the picker says Keywords over a Meaning list, and a reading opened then read that
    /// list. And the field's engine is Keywords: after a switch to Meaning the keyword rows stay
    /// until the Meaning list arrives, and a reading opened over them would be left open over that
    /// list. The view asked the picker alone until this lane. It also closes an open reading when
    /// this turns false, so that a reading is never left behind a dimmed control.
    var offersReadings: Bool { searchMode == .keywords && executedRoute.offersReadings }

    /// The count the facet panel heads its preamble with (#1577 lane 2), or `nil` when it is not known.
    ///
    /// For a route whose facets describe the list, the list's own size, which is exact. For a keyword
    /// match, the whole match (``totalMatchCount``, `nil` when the count did not come back). The route
    /// is the rows' and not the picker's, so between a switch of the picker and the new rows the panel
    /// goes on describing the rows that are on screen.
    var facetMatchCount: Int? {
        executedRoute.facetsDescribeTheList ? results.count : totalMatchCount
    }

    /// The documents the facet panel counts over (#1577 lane 2), or `nil` for a keyword match, which
    /// the panel aggregates in the index. The route is the rows', as for ``facetMatchCount``.
    var facetDocumentKeys: [(volumeId: String, documentId: String)]? {
        executedRoute.facetsDescribeTheList
            ? results.map { (volumeId: $0.volumeId, documentId: $0.documentId) }
            : nil
    }

    /// How many documents the next search would run inside, or `nil` when no document set is
    /// applied: the size of the gate, an applied working corpus intersected with the project's
    /// History scope (#1577 lane 1) and, while a list is held, with the list (lane 5). The Meaning
    /// strip reads it to say where a Meaning search will rank. `SearchViewModel.documentSetSize` is
    /// its twin.
    ///
    /// A list cut at its ceiling is ranked inside its whole match, not its rows (#1577 lane 6), so while one is held
    /// this is the match's size (`PinnedResultBase.wholeMatchSetSize(inside:)`), and `nil` where only reading the
    /// match could say it; the window then holds the strip back (``holdsTheMeaningStripBack``).
    var documentSetSize: Int? {
        if let base = pinnedBase, base.ranksWholeMatch { return base.wholeMatchSetSize(inside: parameters.documentIds) }
        return LayeredResultComposer.gating(parameters, inside: pinnedBase).documentIds?.count
    }

    /// Whether the Meaning strip waits for a question (#1577 lane 6): over the own rows of a list cut at its ceiling,
    /// where the documents a question would rank inside are not known before the match is read
    /// (``documentSetSize`` is `nil`), so the strip's opening would name a set the ranking would not bear out. The
    /// ranking's own strip then names it.
    var holdsTheMeaningStripBack: Bool {
        isShowingBase && pinnedBase?.ranksWholeMatch == true && documentSetSize == nil
    }

    /// The parameters a search would run with *right now*, from the live text field.
    ///
    /// Distinct from what `performSearch` uses, which reads `submittedQuery`. The Query
    /// Inspector wants the live text so the expression updates as the researcher types —
    /// that is how someone learns `NEAR` from watching it — while the search itself stays
    /// on Return, as it must at this corpus size. Inside a held list it is gated to the list,
    /// so the inspector's counts "in your current scope" are counts inside it (#1577 lane 5).
    var liveSearchParameters: SearchParameters {
        var params = LayeredResultComposer.gating(parameters, inside: pinnedBase)
        let trimmed = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        params.keywords = trimmed.isEmpty ? nil : trimmed
        return params
    }

    /// The parameters of the search that actually ran — for the zero-result decomposition,
    /// which must decompose the executed query rather than whatever is in the field now. Inside a
    /// held list, the list's gate is among them, as it was in the run (#1577 lane 5).
    var submittedSearchParameters: SearchParameters {
        var params = LayeredResultComposer.gating(parameters, inside: pinnedBase)
        let trimmed = submittedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        params.keywords = trimmed.isEmpty ? nil : trimmed
        return params
    }

    /// The parameters the facet panel aggregates a keyword match under: the submitted ones, except while a held
    /// list's own rows are on screen, whose match is the one they were found by (#1577 lane 5, lane 4's finding).
    /// The submitted ones then hold the emptied field and the list as the gate, which would aggregate a keyword
    /// list as an empty query and a browse as its loaded rows alone. `SearchViewModel.facetParameters` is its twin.
    var facetParameters: SearchParameters {
        if isShowingBase, let ran = pinnedBase?.ranParameters { return ran }
        return submittedSearchParameters
    }

    /// The route the facet panel's preamble names, where the rows are a layer's: words found in a held Meaning list,
    /// or a held list ranked by a question (#1577 lane 5). `nil` for a search through one engine.
    var facetLayerRoute: ExecutedSearchRoute? { executedRoute.isLayer ? executedRoute : nil }

    /// The words a working corpus saved from the rows on screen records as its query (#1577 lane 5): the submitted
    /// words, or a held list's own while its rows are shown. The field is empty then, and on this window the
    /// submitted words cannot be put back without running a search, as iPhone and iPad put them back.
    var wordsOfTheRowsShown: String {
        if isShowingBase, let base = pinnedBase { return base.query }
        return submittedSearchParameters.keywords ?? ""
    }

    // MARK: - Advanced Filter ViewModel

    /// Backing view model for `SearchFilterView` presented as a sheet.
    /// Created lazily on the first call to `syncToFilterVM(searchService:)`.
    /// Nil until then (and nil if `searchService` is not yet available).
    var filterVM: SearchViewModel? = nil

    // MARK: - Sort

    var sortOrder: SearchSortOrder = .relevance {
        didSet { currentPage = 0 }
    }

    // MARK: - Pagination

    static let pageSizeOptions: [Int] = [10, 20, 50, 100]

    var pageSize: Int = 20 {
        didSet { currentPage = 0 }
    }

    var currentPage: Int = 0

    /// Bumped once per COMPLETED search, so a view can key work on "the results were replaced".
    ///
    /// The macOS twin of `SearchViewModel.executedSearchVersion`, added for the concordance (R-3b).
    /// Keying on `results.count` instead — which is what I reached for first — would miss a new
    /// search returning the same number of rows, leaving a concordance built from the previous
    /// query on screen. That is the worst kind of stale for a view whose output gets quoted.
    private(set) var executedSearchVersion: Int = 0

    /// Which set the My Tags counts describe, frozen when a search COMPLETES (#1310).
    ///
    /// The macOS twin of `SearchViewModel.userTagCountScope`, and set at the same points for the
    /// same reason: `lastRunWasSemantic` is written before the await, so deriving this when the popover
    /// opens would describe a run that has not produced results yet.
    private(set) var userTagCountScope: UserTagCountScope?

    var totalPages: Int {
        max(1, Int(ceil(Double(displayedResults.count) / Double(pageSize))))
    }

    // MARK: - Results

    /// The loaded results. A selection follows every replacement of them (#1576 lane 4): an
    /// emptied list ends it, and the picks a new list does not show are dropped.
    var results: [SearchResult] = [] {
        didSet {
            // No rows, no route (#1577 lane 2): an emptied list is a keyword list until rows arrive,
            // whoever emptied it. The window clears the rows itself when the index is rebuilt.
            if results.isEmpty { executedRoute = .keywords }
            selectionFollowsReplacedResults()
        }
    }
    var isSearching: Bool = false
    /// What the last search failed with. The window draws it in the rows' place, so setting one
    /// ends a selection (#1576 lane 4).
    var searchError: Error? = nil {
        didSet { if searchError != nil { endSelecting() } }
    }

    /// The searches this window has sent, numbered, so that a run a later one replaced writes
    /// nothing when it comes back (#1648). See ``SearchRunLedger``.
    @ObservationIgnored private var searchRuns = SearchRunLedger()

    /// True total number of matches for the current query, independent of
    /// `searchHardLimit` — or `nil` when the count could not be obtained.
    ///
    /// ## Why this is optional
    /// It used to fall back to `results.count` when the concurrent `COUNT(*)` threw. That
    /// silently made the total equal the fetch cap **and switched off both truncation
    /// signals**, because `isResultSetTruncated` compares the two: a truncated set rendered
    /// as "7,500 loaded · 7,500 total" with the orange triangle and the over-cap advisory
    /// both gone, and that number was what `recordSearchHistory` wrote to the research
    /// trail. Not a wrong number in a corner — a wrong number that erased its own warning.
    ///
    /// `nil` now means "unknown", the surfaces say so, and the truncation warning is driven
    /// by whether the fetch actually hit its cap rather than by a comparison against a
    /// number that may not exist.
    var totalMatchCount: Int?

    /// The FTS5 expression the last completed search executed. Mirrors the iOS field; see
    /// `SearchViewModel.lastRenderedExpression` for why it is captured at execution rather than
    /// re-derived by the recorder.
    var lastRenderedExpression: String?

    /// Whether the displayed `results` are a truncated subset of the real match set.
    ///
    /// Keyed on the fetch hitting its own cap, which is knowable without the count. When
    /// the count *is* available and exceeds the fetch, that also counts — a filter applied
    /// after the limit could otherwise hide the truncation.
    ///
    /// ``ResultSetScope/didHitFetchLimit`` is that rule, and this asks it, so the window's orange
    /// advisory and the shared sentences cannot disagree about one result set. They did for a Meaning
    /// search (#1595): this compared its 100 rows with the engine's own list length and answered
    /// "truncated", so a full Meaning list sat under "Showing the first 100 matches — the total is
    /// unavailable" and advice to narrow the search "to load every match", which a Meaning search
    /// cannot do. A ranking has no larger match to load.
    var isResultSetTruncated: Bool { resultSetScope.didHitFetchLimit }

    /// Which set this window is showing, composed from what was recorded with the rows.
    ///
    /// The Mac twin of `SearchViewModel.resultSetScope`, and on the view model for the same reasons
    /// (#1584, #1597): the ceiling is the one this fetch ran under and the engine is the one that
    /// produced the rows, where `SearchSheet` passed a constant and read the picker. A layer's
    /// sentences are said by the rule iPhone and iPad say them by (#1577 lane 5).
    var resultSetScope: ResultSetScope {
        ResultSetScope(loaded: results.count,
                       shown: displayedResults.count,
                       fetchLimit: lastFetchLimit,
                       totalMatchCount: totalMatchCount,
                       documentsOnPage: pagedResults.count,
                       pageCount: totalPages,
                       appliedCorpusTruncation: filterVM?.appliedWorkingCorpusTruncation,
                       route: executedRoute)
            .describingLayer(over: pinnedBase, filtersNarrowed: lastLayerFiltersNarrowed, sortOrder: sortOrder)
    }

    /// The count to display, and whether it is the real total.
    ///
    /// Callers must not print `resultCountForDisplay` without consulting
    /// ``isTotalCountAvailable`` — that pairing is the whole point of the type change.
    var resultCountForDisplay: Int { totalMatchCount ?? results.count }

    /// Whether the displayed count is the true total rather than just what was fetched.
    var isTotalCountAvailable: Bool { totalMatchCount != nil }

    /// Hard upper bound on the number of results materialised by `performSearch` for a query
    /// with text in it.
    /// Raised from 500 → 7,500 in Session 120 (PR #45). At ~5 KB body-text average
    /// the working set stays well under 50 MB on macOS; the count badge displays the
    /// true uncapped total via `totalMatchCount`.
    static let searchHardLimit: Int = 7_500

    /// Hard upper bound for a **filter-only browse** — a subject or person constraint with no
    /// keyword, phrase, or prefix.
    ///
    /// Same value as the keyword ceiling on this platform, and that is the point: a browse row
    /// carries no `body_text` (there are no terms to snippet against, so the fetch does not select
    /// it — measured, 7,694,772 bytes per thousand rows before that change and 0 after), so 7,500
    /// browse rows cost a fraction of 7,500 keyword rows. The constant exists so the two ceilings
    /// can move independently, and so `isResultsCapped` compares against the one actually used —
    /// the iOS twin genuinely differs (1,000 keyword, 7,500 browse).
    static let filterOnlyHardLimit: Int = 7_500

    /// The ceiling the CURRENT results were actually fetched at. Recorded with the rows it fetched
    /// rather than recomputed from `parameters`, which are live filter state and may have moved since.
    private(set) var lastFetchLimit: Int = searchHardLimit

    /// Returns `results` ordered according to `sortOrder`, by `SearchSortOrder.sorted(_:)`: date
    /// sorting reads the structured `dateISO`, never the `dateline`, puts undated documents last in
    /// both directions, and breaks a tie on the date by BM25 score (more relevant first).
    var allSortedResults: [SearchResult] {
        sortOrder.sorted(results)
    }

    var pagedResults: [SearchResult] {
        let all = displayedResults
        // Clamp the page index at read time (side-effect-free) so a reviewed-set change that
        // shrinks the list can never leave `pagedResults` returning a blank page for a
        // now-out-of-range `currentPage` (mirrors `SearchViewModel.pagedResults`).
        let page = min(max(0, currentPage), totalPages - 1)
        let start = page * pageSize
        guard start < all.count else { return [] }
        return Array(all[start..<min(start + pageSize, all.count)])
    }

    // MARK: - Checklist Mode (#189-D)

    /// True when checklist review mode is active. Session-scoped; not persisted (resets on
    /// relaunch). While on, results the user has reviewed this session are hidden from the list,
    /// the timeline, and the page math. Mirrors `SearchViewModel`'s iOS implementation so the
    /// macOS Search window behaves identically.
    var checklistMode: Bool = false {
        didSet { clampCurrentPage(); pruneSelection() }
    }

    /// The instant checklist mode was last enabled (or a new search re-anchored it). Documents
    /// opened at or after this instant (per `ReadingHistoryEntry.accessedAt`) are hidden. `nil`
    /// while mode is off.
    var checklistEnabledAt: Date?

    /// `(volumeId|documentId)` keys opened since `checklistEnabledAt`, fed by a live
    /// `ReadingHistoryEntry` `@Query` in `MacSearchWindowView` (mirrors `readSinceEnabledKeys`
    /// on iOS).
    var readSinceEnabledKeys: Set<String> = [] {
        didSet { clampCurrentPage(); pruneSelection() }
    }

    /// The results the reader marked reviewed this session, from a row's menu or with Mark Page
    /// Reviewed, and the last bulk mark apart so that it can be undone (#1576 lane 1). An in-memory
    /// value, never a fabricated `ReadingHistoryEntry`.
    private(set) var reviewedMarks = ReviewedMarks() {
        didSet { clampCurrentPage(); pruneSelection() }
    }

    /// `(volumeId|documentId)` keys the reader marked reviewed this session: ``reviewedMarks``' keys.
    /// A read, since #1576: the marks are written through ``markReviewed(volumeId:documentId:)``,
    /// ``markReviewed(_:)`` and ``undoLastBulkMark()``.
    var markedReviewedKeys: Set<String> { reviewedMarks.keys }

    /// The search the checklist is anchored to, or `nil` while the mode is off. `performSearch`
    /// re-runs on every filter/scope change (not only on a new query), so the re-anchor is gated on
    /// the search itself changing — otherwise a filter edit mid-session would wipe the reader's
    /// reviewed marks. ``ChecklistAnchor`` decides "the same search": for a search with words, the
    /// writer's own ``SearchHistoryWriter/isSameQuery(_:_:)``, so a query re-run in other quotation
    /// marks (`“cold war”` as `"cold war"`, #1298) keeps its marks exactly as it keeps its history
    /// row; and for a browse with no words, the same person and subject (#1576 lane 1). Until then
    /// this was the typed text alone, which is empty for every browse, so marks made in one person's
    /// Find all mentions hid documents in the next person's.
    private(set) var checklistAnchor: ChecklistAnchor?

    /// A stable reviewed-set key for a `(volume, document)` pair.
    nonisolated static func reviewedKey(volumeId: String, documentId: String) -> String {
        "\(volumeId)|\(documentId)"
    }

    /// The reviewed set while checklist mode is on: docs opened since enable ∪ docs marked.
    var hiddenReviewedKeys: Set<String> {
        checklistMode ? readSinceEnabledKeys.union(markedReviewedKeys) : []
    }

    /// `allSortedResults` minus reviewed docs when checklist mode is on. All display-time page
    /// math (`totalPages`, `pagedResults`) and the timeline page over this, so the slice, count,
    /// and page index stay in sync.
    var displayedResults: [SearchResult] {
        let hidden = hiddenReviewedKeys
        guard !hidden.isEmpty else { return allSortedResults }
        return allSortedResults.filter {
            !hidden.contains(Self.reviewedKey(volumeId: $0.volumeId, documentId: $0.documentId))
        }
    }

    /// Enables/disables checklist mode. Enabling stamps the anchor and clears prior marks;
    /// disabling clears all reviewed state so the full list returns.
    ///
    /// Turned on inside a held list, the checklist is anchored to the list's own search, which every
    /// search inside it keeps (#1577 lane 5): the submitted words are a layer's then, or none.
    func setChecklistMode(_ on: Bool) {
        checklistMode = on
        if on {
            checklistEnabledAt = .now
            checklistAnchor = pinnedBase?.completedSearchAnchor
                ?? ChecklistAnchor(query: submittedQuery, parameters: submittedSearchParameters)
            forgetReviewedMarks()
        } else {
            checklistEnabledAt = nil
            checklistAnchor = nil
            readSinceEnabledKeys.removeAll()
            forgetReviewedMarks()
        }
        currentPage = 0
    }

    /// Forgets every mark, and with them a line in the selection's strip that offers to undo one
    /// (#1576 lane 4): after this there is nothing for that Undo to bring back. The one place the
    /// marks are reset, so that no reset leaves the line behind. `SearchViewModel`'s is its twin.
    private func forgetReviewedMarks() {
        reviewedMarks.reset()
        selectionSession.withdrawOutcomeOfferingToUndoMarks()
    }

    /// Whether a mark can be made on the rows on screen: Checklist Mode is on, and on the search
    /// whose rows are on screen (``ChecklistAnchor/isOnTheSearch(shown:)``).
    ///
    /// `performSearch` anchors the checklist to a search before it runs, and the last search's rows
    /// stay on screen until the new ones arrive. A mark made in that gap would be kept under the new
    /// search and hide those documents in its list: by the selection's Mark Reviewed, which All Shown
    /// can make of every loaded row (#1576 lane 4), and by a row's own Mark Reviewed and the strip's
    /// Mark Page Reviewed (#1683). So all three wait until the rows arrive. The iPhone's checklist is
    /// settled with the rows, so `SearchViewModel` has no twin of this.
    var canMarkReviewed: Bool {
        checklistMode && (checklistAnchor?.isOnTheSearch(shown: lastCompletedSearchAnchor) ?? true)
    }

    /// Marks a document reviewed for this checklist session (hides it without opening it), and
    /// nothing while the rows on screen are another search's (``canMarkReviewed``, #1683).
    func markReviewed(volumeId: String, documentId: String) {
        guard canMarkReviewed else { return }
        reviewedMarks.mark(Self.reviewedKey(volumeId: volumeId, documentId: documentId))
    }

    /// Marks several results reviewed at one stroke — Mark Page Reviewed hands this the page — and
    /// remembers the ones it newly hid, so that ``undoLastBulkMark()`` can bring them back
    /// (#1576 lane 1). `SearchViewModel.markReviewed(_:)` is its twin, and ``ReviewedMarks`` holds
    /// the rule for both. Nothing is marked while the rows on screen are another search's
    /// (``canMarkReviewed``, #1683).
    ///
    /// - Parameter results: The results to mark, in any order.
    /// - Returns: How many rows left the list: the results newly marked, less any a document
    ///   opened since the mode came on was hiding already.
    @discardableResult
    func markReviewed(_ results: [SearchResult]) -> Int {
        guard canMarkReviewed else { return 0 }
        let hidden = reviewedMarks.markBulk(results.map {
            Self.reviewedKey(volumeId: $0.volumeId, documentId: $0.documentId)
        }).subtracting(readSinceEnabledKeys).count
        // A new bulk mark is what Undo takes back now, so a line offering to undo an earlier
        // one would name the wrong rows (#1576 lane 4).
        selectionSession.withdrawOutcomeOfferingToUndoMarks()
        return hidden
    }

    /// How many rows of the loaded results Undo would bring back
    /// (``ReviewedMarks/undoableCount(among:otherwiseHidden:)``).
    private var undoableRowCount: Int {
        reviewedMarks.undoableCount(
            among: results.lazy.map { Self.reviewedKey(volumeId: $0.volumeId, documentId: $0.documentId) },
            otherwiseHidden: readSinceEnabledKeys)
    }

    /// Whether Undo would bring a row back: there is a bulk mark, and at least one result it hid
    /// is among the loaded results and hidden by nothing else. `SearchViewModel.canUndoBulkMark`
    /// is its twin.
    var canUndoBulkMark: Bool { undoableRowCount > 0 }

    /// Takes back the last bulk mark, and only that: marks made a row at a time stay.
    ///
    /// - Returns: How many rows came back to the list, which is not always the size of the mark:
    ///   see ``ReviewedMarks/undoableCount(among:otherwiseHidden:)``.
    @discardableResult
    func undoLastBulkMark() -> Int {
        let restored = undoableRowCount
        reviewedMarks.undoLastBulk()
        selectionSession.withdrawOutcomeOfferingToUndoMarks()
        return restored
    }

    /// Settles the checklist against a search that is about to run (#1576 lane 1): the same search
    /// keeps its marks and its anchor time, and another search starts the checklist again.
    /// `SearchViewModel.settleChecklist(for:)` is its twin.
    ///
    /// - Parameter anchor: The anchor of the search being run.
    private func settleChecklist(for anchor: ChecklistAnchor) {
        guard checklistMode, checklistAnchor?.isSameSearch(as: anchor) != true else { return }
        checklistAnchor = anchor
        checklistEnabledAt = .now
        readSinceEnabledKeys.removeAll()
        forgetReviewedMarks()
    }

    /// Resets `currentPage` to 0 when a reviewed-set change shrank the list below the current page.
    private func clampCurrentPage() {
        if currentPage >= totalPages { currentPage = 0 }
    }

    // MARK: - Selection (#1576 lane 4)

    /// The selection and what follows it: the picks, the search they were made in, and what the
    /// last command did. The rules are ``ResultSelectionSession``'s, which `SearchViewModel` holds
    /// too and whose tests drive them; this view model tells it what only it knows. Nothing runs
    /// this file's half, so each function below is its twin's, line for line, and
    /// `MacResultSelectionWiringTests` reads the two against each other. Two are not, each for a
    /// reason of this window: ``markSelectionReviewed()`` and ``settleSelection(for:)``, with
    /// ``canMarkSelectionReviewed``, which the iPhone has no need of.
    private var selectionSession = ResultSelectionSession()

    /// The results the reader has picked to act on at once, and whether the list is in selection.
    var resultSelection: ResultSelection { selectionSession.selection }

    /// What the last command on the selection did, shown above the results until the next
    /// command, the next completed search or Done.
    var bulkOutcome: BulkOutcome? { selectionSession.outcome }

    /// Counts the outcomes set, so that the strip can announce each one.
    var bulkOutcomeSerial: Int { selectionSession.outcomeSerial }

    /// The picked results, in the order the list shows them: what a command acts on.
    var selectedResults: [SearchResult] { resultSelection.resolved(in: displayedResults) }

    /// Whether more results are picked than one Add to Collection takes (the owner's decision 5).
    /// Mark Reviewed has no limit. This window loads up to 7,500 results, so All Shown is often
    /// over it.
    var selectionExceedsAddLimit: Bool { selectionSession.exceedsAddLimit }

    /// Whether Add to Collection can run: something is picked, and no more than one add takes.
    var canAddSelectionToCollection: Bool { selectionSession.canAdd }

    /// The search that last completed, which is the one any rows on screen came from; `nil`
    /// before the first. A selection is anchored to it, so that a re-run of the same search keeps
    /// its picks and another search ends it.
    private var lastCompletedSearchAnchor: ChecklistAnchor?

    /// Enters selection, with one row picked when the reader chose Select on it.
    ///
    /// - Parameter result: The row whose menu was used, or `nil` from the toolbar.
    func beginSelecting(with result: SearchResult? = nil) {
        // An error is drawn in the rows' place, whatever `results` still holds.
        guard searchError == nil, !displayedResults.isEmpty else { return }
        selectionSession.begin(
            picking: result?.id,
            anchor: lastCompletedSearchAnchor
                ?? ChecklistAnchor(query: submittedQuery, parameters: submittedSearchParameters))
    }

    /// Leaves selection: Done, a new search, a Keywords/Meaning flip, an emptied list.
    func endSelecting() {
        selectionSession.end()
    }

    /// Picks a row, or un-picks it.
    func toggleSelection(of result: SearchResult) {
        selectionSession.toggle(result.id)
    }

    /// Picks every row on the page on screen.
    func selectPage() {
        selectionSession.pick(pagedResults.map(\.id))
    }

    /// Picks every result the list shows: the loaded results less those Checklist Mode hides.
    /// Never a match that was not loaded.
    func selectAllShown() {
        selectionSession.pick(displayedResults.map(\.id))
    }

    /// Un-picks everything and stays in selection.
    func selectNone() {
        selectionSession.clear()
    }

    /// Whether Mark Reviewed can run on the selection: ``canMarkReviewed``, the rule a row's own
    /// Mark Reviewed and the strip's Mark Page Reviewed wait by too (#1683).
    ///
    /// A selection marked while another search's rows are coming, which All Shown can make of every
    /// loaded row, would be kept under the new search and hide those documents in its list. So the
    /// strip's Mark Reviewed is dimmed until the rows arrive, by which time another search has ended
    /// the selection. The iPhone's checklist is settled with the rows, so `SearchViewModel` has no
    /// twin of this.
    var canMarkSelectionReviewed: Bool { canMarkReviewed }

    /// Mark Reviewed for the selection: hides the picked rows, which takes them out of the
    /// selection, and keeps the line and its Undo.
    func markSelectionReviewed() {
        guard canMarkSelectionReviewed else { return }
        // Marked first and recorded after: marking prunes the session, and the two writes to it
        // must not overlap.
        let hidden = markReviewed(selectedResults)
        selectionSession.recordMark(hidden: hidden)
    }

    /// Records what an Add to Collection did while selecting: the selection's, or one row's from
    /// its own menu. Outside selection nothing shows an outcome, and the picker's checkmark is the
    /// feedback.
    ///
    /// - Parameters:
    ///   - outcome: What `CollectionDocumentDiscovery.appendDocuments` answered.
    ///   - collectionName: The collection's name as its row shows it.
    func recordCollectionAdd(_ outcome: CollectionDocumentAppend, collectionName: String) {
        selectionSession.recordAdd(outcome, collectionName: collectionName)
    }

    /// Records what an Add Tags did, and shows the documents' tags on their rows at once
    /// (#1576 lane 5). The rows are refreshed in selection and out of it; the line and its Undo
    /// are kept in selection only, where there is a place for them.
    ///
    /// - Parameters:
    ///   - outcome: What `UserTagAdmin.assign` answered.
    ///   - tagNames: The names of the tags given.
    func recordTagAssign(_ outcome: UserTagAssign, tagNames: [String]) {
        refreshUserTags(outcome.tagIdsByDocument)
        selectionSession.recordTagging(outcome, tagNames: tagNames)
    }

    /// Gives the rows of the named documents the tags the store says they carry now, in memory
    /// (#1576 lane 5). A row's tags are a snapshot from when its search ran; without this a
    /// tagged row would show its new tag only after the next search. No other row changes, and
    /// neither do the picks, the page or the checklist's marks: the rows are the same rows.
    ///
    /// - Parameter tagIdsByDocument: Each document's whole tag set, keyed by `SearchResult.id`.
    func refreshUserTags(_ tagIdsByDocument: [String: Set<UUID>]) {
        guard results.contains(where: { tagIdsByDocument[$0.id] != nil }) else { return }
        results = results.map { row in
            tagIdsByDocument[row.id].map { row.replacingUserTagIds($0) } ?? row
        }
    }

    /// Takes the last command back and says what that did.
    ///
    /// The marks are this view model's to restore. Collection entries and tag assignments are
    /// the store's, so the caller, which holds the model context, removes them.
    ///
    /// - Parameters:
    ///   - removingEntries: Removes the collection entries with these ids and answers how many
    ///     it removed (`CollectionDocumentDiscovery.removeEntries`).
    ///   - removingTagAssignments: Removes the tag assignments with these ids and answers which
    ///     documents lost one and what each still carries
    ///     (`UserTagAdmin.removeAssignmentsAndIndex`).
    func undoBulkOutcome(removingEntries: ([UUID]) throws -> Int,
                         removingTagAssignments: ([UUID]) throws -> UserTagRemoval) {
        // A copy, so that restoring the marks, which writes this view model's own state, is not
        // a second write to the session while the session is being changed.
        var session = selectionSession
        var removal: UserTagRemoval?
        session.undo(
            removingEntries: removingEntries,
            removingTagAssignments: { ids in
                let removed = try removingTagAssignments(ids)
                removal = removed
                return removed.documents.count
            },
            restoringMarks: { undoLastBulkMark() })
        selectionSession = session
        // The rows lose the tags the Undo took back, as they gained them: in memory, at once.
        if let removal { refreshUserTags(removal.tagIdsByDocument) }
    }

    /// Follows a replaced result list. An emptied list ends selection; otherwise the picks the
    /// new list does not show are dropped and counted, for the completed search to settle.
    private func selectionFollowsReplacedResults() {
        selectionSession.resultsWereReplaced(nowEmpty: results.isEmpty,
                                             shown: Set(displayedResults.map(\.id)))
    }

    /// Drops the picks the list no longer shows: a row Checklist Mode has just hidden, because
    /// its document was opened or it was marked reviewed.
    private func pruneSelection() {
        selectionSession.prune(toShown: Set(displayedResults.map(\.id)))
    }

    /// Settles the selection against a search whose rows have just arrived. The same search
    /// keeps the picks it still shows and says how many it does not; another search ends
    /// selection.
    ///
    /// - Parameter anchor: The anchor of the search that ran.
    private func settleSelection(for anchor: ChecklistAnchor) {
        lastCompletedSearchAnchor = anchor
        selectionSession.settle(for: anchor)
    }

    // MARK: - Search within these results (#1577 lane 5)

    /// The list a layer runs inside, or `nil` while none is held. See ``PinnedResultBase``, and
    /// `SearchViewModel.pinnedBase`, this one's twin.
    ///
    /// Held in memory for the window's session and never saved (the owner's decision 4). It is a
    /// scope and not a filter, so it never enters ``parameters``: it joins the gate where the value
    /// a search runs with is built (``liveSearchParameters``, ``submittedSearchParameters``,
    /// `performSearch`'s and `rankHeldList(run:base:backend:)`'s), and the filter summary and the
    /// token caption, which read ``parameters``, do not name it (rule 3).
    private(set) var pinnedBase: PinnedResultBase?

    /// Whether the rows on screen are the held list's own: from the moment it is held, after an empty
    /// field is submitted during a layer, until a layer completes, its failure included. Read from the
    /// search version, as on iPhone and iPad.
    var isShowingBase: Bool { pinnedBase != nil && baseRowsVersion == executedSearchVersion }

    /// The search version at which the held list's own rows were last put on screen, or `nil`.
    private var baseRowsVersion: Int?

    /// Whether the filters the last layer ran under were other than its list's
    /// (`PinnedResultBase.filtersNarrow(_:)`), recorded with the layer's rows.
    private var lastLayerFiltersNarrowed = false

    /// The sort the reader had chosen when a ranking was started, which the list gets back on
    /// leaving: a ranking is read closest first.
    private var sortOrderBeforeBase: SearchSortOrder?

    /// The scope signature of the filters the rows on screen were found under, written with them by
    /// the two runs a list can be held from: what a held list's `PinnedResultBase.filterSignature` is.
    @ObservationIgnored private var filterSignatureOfTheRows: String?

    /// The trigger that rows put back on leaving a held list answer, so that the window's search task
    /// does not fetch them again (``AnsweredSearchTrigger``).
    @ObservationIgnored private var answeredTrigger = AnsweredSearchTrigger()

    /// The trail's signature of the documents the last ranking of a whole match ranked inside, written with its rows
    /// (#1577 lane 6) and read only while ``executedRoute`` is that ranking's (``meaningSignature``).
    /// `SearchViewModel`'s is its twin.
    @ObservationIgnored private var rankedSetSignature: String?

    /// The way a layer over the rows on screen would run, or `nil` when none can start now: no rows
    /// shown, a search under way or failed, a list already held (no deeper stacks), rows that are a
    /// layer's own, or a ranking asked for with no Meaning engine. `SearchViewModel`'s is its twin.
    ///
    /// - Parameter meaningAvailable: Whether the Meaning engine has booted, which a ranking needs.
    /// - Returns: The direction, or `nil`.
    func layerDirection(meaningAvailable: Bool) -> SearchLayerDirection? {
        guard pinnedBase == nil, !isSearching, searchError == nil, !displayedResults.isEmpty,
              let direction = SearchLayerDirection.starting(over: executedRoute) else { return nil }
        if direction == .rankByMeaning, !meaningAvailable { return nil }
        return direction
    }

    /// Holds the list on screen as the base a layer runs inside, and turns the field to the other
    /// engine: the toolbar's Search Within Results.
    ///
    /// The rows stay on screen. The list is built from ``displayedResults``, by the rules iPhone and
    /// iPad hold one by (`PinnedResultBase.members(of:shown:)`, `kind(route:query:ran:browseName:)`).
    /// The field empties and so do the submitted words: the engine is part of this window's search
    /// trigger, so with the words left in place the switch would run the list's own words through
    /// the other engine at once. The trigger's search then finds an empty field inside a held list,
    /// and searches nothing. The trail's anchor is set aside with the list (rule 5), and the
    /// checklist is left as it is: its marks belong to the list's search, which no search inside it
    /// re-anchors.
    ///
    /// - Parameter meaningAvailable: Whether the Meaning engine has booted, which a ranking needs.
    /// - Returns: The held list, or `nil` when no layer can start (``layerDirection(meaningAvailable:)``).
    @discardableResult
    func holdBase(meaningAvailable: Bool) -> PinnedResultBase? {
        guard let direction = layerDirection(meaningAvailable: meaningAvailable) else { return nil }
        let query = submittedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let ran = userTagCountScope?.ranParameters
        let members = PinnedResultBase.members(of: results, shown: displayedResults)
        let (kind, describedQuery) = PinnedResultBase.kind(route: executedRoute, query: query, ran: ran,
                                                           browseName: PinnedResultBase.browseName(of: ran ?? parameters))
        let base = PinnedResultBase(
            direction: direction,
            kind: kind,
            query: query,
            rows: results,
            members: members,
            hiddenByChecklist: results.count - members.count,
            notDownloaded: executedRoute == .meaning ? beyondLibraryHits.count : 0,
            route: executedRoute,
            fetchLimit: lastFetchLimit,
            totalMatchCount: totalMatchCount,
            renderedExpression: lastRenderedExpression,
            disclosure: semanticDisclosure,
            beyondLibraryHits: beyondLibraryHits,
            userTagCountScope: userTagCountScope,
            historyAnchor: historyAnchor,
            completedSearchAnchor: lastCompletedSearchAnchor,
            filterSignature: filterSignatureOfTheRows ?? SearchScopeSignature.signature(for: parameters),
            describedQuery: describedQuery)
        searchRuns.replaceRunsUnderWay()
        endSelecting()
        pinnedBase = base
        baseRowsVersion = executedSearchVersion
        lastLayerFiltersNarrowed = false
        // Set aside, and given back by `leaveBase()` (rule 5).
        historyAnchor = nil
        if direction == .rankByMeaning {
            sortOrderBeforeBase = sortOrder
            sortOrder = .relevance
        }
        searchMode = direction.fieldEngine
        queryText = ""
        submittedQuery = ""
        return base
    }

    /// Leaves the held list: its rows and every figure come back from memory, the field holds its
    /// words again and the Keywords | Meaning control its engine. `SearchViewModel.leaveBase()` is its
    /// twin.
    ///
    /// The engine and the words are this window's search trigger, so putting them back changes it.
    /// The list's rows answer that search already, and the window's task searches nothing for it
    /// (``AnsweredSearchTrigger``), unless a filter has changed since the list was found: this window
    /// applies a filter as it is set, so the list's search then runs again under the filters in force,
    /// and the rows on screen are never another set of filters' (`PinnedResultBase.wasFound(under:)`).
    /// The version is bumped, for whatever is keyed on it, and the list's trail anchor comes back.
    ///
    /// - Returns: Whether the rows put back stand with no search; `false` when the list's search runs
    ///   again, and when no list was held.
    @discardableResult
    func leaveBase() -> Bool {
        foldShownTagsIntoBase()
        guard let base = pinnedBase else { return false }
        dropBase()
        restoreRows(of: base)
        searchMode = base.direction.baseEngine
        queryText = base.query
        submittedQuery = base.query
        if let sort = sortOrderBeforeBase { sortOrder = sort }
        sortOrderBeforeBase = nil
        guard base.wasFound(under: parameters) else { return false }
        answeredTrigger.answer(searchTrigger)
        return true
    }

    /// Leaves a held list for a hand-off or a recalled search (rule 3) as ✕ does, its rows, figures and
    /// the reader's sort coming back. The hand-off's own search replaces them. The field, the words and
    /// the engine are the caller's. `SearchViewModel`'s is its twin.
    private func leaveBaseForHandoff() {
        foldShownTagsIntoBase()
        guard let base = pinnedBase else { return }
        dropBase()
        restoreRows(of: base)
        if let sort = sortOrderBeforeBase { sortOrder = sort }
        sortOrderBeforeBase = nil
    }

    /// Leaves a held Meaning list and runs the layer's words across the whole library: the command a
    /// layer that found nothing offers ("Search the Whole Library for These Words"). The words and the
    /// engine are the trigger's already, so a version bump runs them.
    func leaveBaseKeepingTheWords() {
        guard pinnedBase != nil else { return }
        dropBase()
        sortOrderBeforeBase = nil
        parametersVersion += 1
    }

    /// Lets go of a held list when the window empties its rows for a rebuilt index: they were the old
    /// index's. The engine and the submitted words are left as they are, so that no search runs, and the
    /// reader's sort comes back.
    func letGoOfBaseForRebuiltIndex() {
        guard pinnedBase != nil else { return }
        dropBase()
        if let sort = sortOrderBeforeBase { sortOrder = sort }
        sortOrderBeforeBase = nil
    }

    /// Carries the tags the rows on screen were given since the list was held into the held list
    /// (`PinnedResultBase.takeUserTags(from:)`), before those rows are replaced: by a layer, by the
    /// list's own rows, or on leaving. ``refreshUserTags(_:)`` writes the rows on screen alone.
    private func foldShownTagsIntoBase() {
        guard var base = pinnedBase else { return }
        base.takeUserTags(from: results)
        pinnedBase = base
    }

    /// Lets go of the held list without putting its rows back, which its callers do or not. The list's
    /// trail anchor comes back, as on leaving it.
    private func dropBase() {
        guard let base = pinnedBase else { return }
        searchRuns.replaceRunsUnderWay()
        isSearching = false
        pinnedBase = nil
        baseRowsVersion = nil
        lastLayerFiltersNarrowed = false
        historyAnchor = base.historyAnchor
    }

    /// Puts a held list's rows and figures back, and counts a completed list, with no search.
    ///
    /// The submitted words are not put back here, as iPhone and iPad put them back: they are this
    /// window's search trigger. ``leaveBase()`` puts them back with the engine, and an empty field
    /// inside a held list keeps them empty (``wordsOfTheRowsShown`` gives a capture the list's own).
    private func restoreRows(of base: PinnedResultBase) {
        results = base.rows
        executedRoute = base.route
        filterSignatureOfTheRows = base.filterSignature
        totalMatchCount = base.totalMatchCount
        lastFetchLimit = base.fetchLimit
        lastRenderedExpression = base.renderedExpression
        semanticDisclosure = base.disclosure
        beyondLibraryHits = base.beyondLibraryHits
        semanticNeedsModel = false
        userTagCountScope = base.userTagCountScope
        lastCompletedSearchAnchor = base.completedSearchAnchor
        searchError = nil
        currentPage = 0
        executedSearchVersion &+= 1
    }

    /// Shows the held list's own rows again while it stays held: an empty field submitted after a
    /// layer, or over a search under way or failed.
    private func showBaseRows() {
        foldShownTagsIntoBase()
        guard let base = pinnedBase else { return }
        isSearching = false
        endSelecting()
        restoreRows(of: base)
        baseRowsVersion = executedSearchVersion
        lastLayerFiltersNarrowed = false
    }

    /// Where a ranking's unranked rows begin in the list as shown, and how many it shows: the line
    /// that counts them goes above the first (`LayeredResultComposer.unrankedTail(of:route:sortOrder:)`).
    var unrankedTail: (firstId: String, count: Int)? {
        LayeredResultComposer.unrankedTail(of: displayedResults, route: executedRoute, sortOrder: sortOrder)
    }

    // MARK: - UI State

    var showTips: Bool = false

    // MARK: - Computed Labels

    var dateRangeLabel: String? {
        guard let range = parameters.dateRange else { return nil }
        return [range.earliest, range.latest].compactMap { $0 }.joined(separator: " – ")
    }

    var volumeFilterLabel: String? {
        guard let ids = parameters.volumeIds, !ids.isEmpty else { return nil }
        return ids.count == 1 ? ids[0] : "\(ids.count) volumes"
    }

    var tagFilterLabel: String? {
        guard !parameters.userTagIds.isEmpty else { return nil }
        guard parameters.userTagIds.count == 1 else {
            return String(localized: "search.filter.tags.count",
                          defaultValue: "\(parameters.userTagIds.count) tags")
        }
        // Resolve to the tag's name. This used to return the raw id, so the chip read
        // "Tagged 37A4D180-4990-4C2A-A0F9-BB41B4116EC2" — already the case for the shipped
        // result-row chip tap, before any facet existed.
        let id = parameters.userTagIds[0]
        if let name = filterVM?.availableUserTags.first(where: { $0.id.uuidString == id })?.name {
            return name
        }
        // No tag list yet (the Advanced panel has never been opened) or the id no longer
        // resolves. A truncated id beats a full one, and beats claiming a name we do not have.
        return String(localized: "search.filter.tags.unresolved", defaultValue: "1 tag")
    }

    var activeFilterSummary: String? {
        var parts: [String] = []
        if parameters.dateRange != nil           { parts.append("date") }
        if parameters.yearKeys != nil            { parts.append("years") }
        if parameters.volumeIds != nil           { parts.append("volume") }
        // `documentIds` has TWO producers — an applied working corpus and a project History
        // gate — and `DocumentScopeGate.combine` intersects them, so it can carry either or both.
        // Labelling it unconditionally "project" named the wrong scope whenever a corpus was the
        // source, which is the common case: the corpus is applied from the filter sheet two
        // controls away, while a History gate needs an active project in History mode.
        if parameters.documentIds != nil {
            let corpus = filterVM?.appliedWorkingCorpusKeys != nil
            let project = filterVM?.projectScope != .off
            switch (corpus, project) {
            case (true, true):  parts.append("corpus + project")
            case (true, false): parts.append("corpus")
            default:            parts.append("project")
            }
        }
        if !parameters.userTagIds.isEmpty        { parts.append("tags") }
        if parameters.phrase != nil              { parts.append("phrase") }
        if parameters.personRef != nil || parameters.personRollupId != nil { parts.append("person") }
        if !parameters.excludedTerms.isEmpty     { parts.append("excluded") }
        if parameters.prefixWildcard != nil      { parts.append("prefix") }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    // MARK: - Filter Mutations (each bumps parametersVersion to trigger re-search)

    func setDocumentTypeFilter(_ filter: DocumentTypeFilter) {
        parameters.documentTypeFilter = filter
        filterVM?.documentTypeFilter = filter
        parametersVersion += 1
    }

    /// Includes or excludes front matter in the executed query (M-4).
    ///
    /// ## This field was reachable and inert on macOS before this existed
    /// `SearchFilterView`'s "Include front matter" toggle binds `filterVM.includeFrontMatter`, and
    /// #916 put that property into `advancedFilterSignature` so the popover re-applies when it
    /// changes. But ``applyAdvancedFilters()`` copied its three siblings — `includeDocumentText`,
    /// `includeSummaries`, `includeNotes` — and **not this one**, and ``syncToFilterVM(…)`` never
    /// seeded it either. So on macOS the toggle moved, the search re-ran, and the results were
    /// identical: the third instance of this review's no-silent-no-ops defect, and the second for
    /// this very field. Both halves are fixed alongside this setter, because a token that writes
    /// `parameters` while the popover writes `filterVM` would otherwise let each silently undo the
    /// other.
    ///
    /// Writing **both** stores is the same shape ``setDocumentTypeFilter(_:)`` uses, and it is what
    /// keeps a subsequent `applyAdvancedFilters()` from reverting a token's edit.
    ///
    /// - Parameter include: `true` to search front matter (the default), `false` to exclude it.
    func setIncludeFrontMatter(_ include: Bool) {
        guard parameters.includeFrontMatter != include else { return }
        parameters.includeFrontMatter = include
        filterVM?.includeFrontMatter = include
        parametersVersion += 1
    }

    /// A short label for the active person filter, or `nil` when there is none.
    ///
    /// Exists so a People facet click reads back in the filter row the way a Volume or Date
    /// click already does — the design's requirement that facets and the filter sheet cannot
    /// disagree only holds if every narrowable dimension is visible in one place.
    var personFilterLabel: String? {
        if let rollupId = parameters.personRollupId {
            // Prefer the stored name. `rollup_id` is a slot number that is renumbered on every
            // rollup rebuild (#747), so "person #12" both means nothing to the reader and stops
            // being the same person between one correction and the next.
            if let label = parameters.personLabel, !label.isEmpty { return label }
            return String(localized: "search.filter.person.rollup",
                          defaultValue: "person #\(rollupId)")
        }
        if let ref = parameters.personRef {
            return ref.hasPrefix("#") ? String(ref.dropFirst()) : ref
        }
        return nil
    }

    /// Clears the person filter in both of its forms.
    func clearPersonFilter() {
        guard parameters.personRef != nil || parameters.personRollupId != nil else { return }
        parameters.personRef = nil
        parameters.personRollupId = nil
        parameters.personAnchor = nil
        filterVM?.personRollupId = nil
        filterVM?.personAnchor = nil
        // **Both halves of the mirror, or the clear undoes itself.** `applyAdvancedFilters` rebuilds
        // `personRef` from `filterVM.personRefText` (:712) and `personLabel` from `filterVM`
        // (:714). Clearing only the rollup fields left the typed ref alive in the filter VM, so the
        // person filter came back the next time anything in the Advanced popover changed — a ×
        // that held until the reader touched an unrelated control. Found while wiring M-4's token
        // row, which routes its remove button here.
        filterVM?.personRefText = ""
        filterVM?.personLabel = nil
        parametersVersion += 1
    }

    /// Captures or re-resolves the person filter's durable anchor against the live rollup (#747).
    ///
    /// The macOS twin of `SearchViewModel.refreshPersonRollupBinding(using:)`. Both exist because
    /// the two search surfaces keep separate state (`project_macos_search_separate`); fixing only
    /// one would leave the Mac search window filtering by a stale slot number after every merge.
    ///
    /// - Returns: `true` if the caller should re-run the search.
    @discardableResult
    func refreshPersonRollupBinding(using store: PersonMentionStore?) async -> Bool {
        let before = PersonFilterBinding(rollupId: parameters.personRollupId,
                                         label: parameters.personLabel,
                                         anchor: parameters.personAnchor)
        let (after, dropped) = await PersonRollupRefresh.rebind(before, using: store)
        guard after != before else { return false }
        parameters.personRollupId = after.rollupId
        parameters.personLabel = after.label
        parameters.personAnchor = after.anchor
        filterVM?.personRollupId = after.rollupId
        filterVM?.personLabel = after.label
        filterVM?.personAnchor = after.anchor
        if dropped {
            droppedPersonFilterNotice = String(
                localized: "search.person.filterDropped",
                defaultValue: "The person filter was cleared — \(before.label ?? "that person") is no longer in the indexed corpus.")
        }
        // Only an id change (or a drop) alters the result set; a first-time anchor capture does not.
        let changed = dropped || after.rollupId != before.rollupId
        if changed { parametersVersion += 1 }
        return changed
    }

    /// Set when the last rebind dropped the person filter because its anchor no longer resolves.
    var droppedPersonFilterNotice: String?

    func clearDateFilter() {
        parameters.dateRange = nil
        filterVM?.dateRangeEnabled = false
        parametersVersion += 1
    }

    /// The Years-facet chip's label, or `nil` when no year set is in force (#775).
    ///
    /// Names the years up to three, then counts. Which years were kept is the finding a reader
    /// needs; beyond three the list outgrows the chip.
    var yearFilterLabel: String? {
        guard let years = parameters.yearKeys else { return nil }
        if years.isEmpty {
            return String(localized: "search.filter.years.none", defaultValue: "none")
        }
        if years.count <= 3 { return years.sorted().joined(separator: ", ") }
        return String(format: String(localized: "search.filter.years.count %lld",
                                     defaultValue: "%lld years"), Int64(years.count))
    }

    func clearYearFilter() {
        parameters.yearKeys = nil
        filterVM?.facetYearKeys = nil
        parametersVersion += 1
    }

    /// Clears the #308 subject-bucket narrowing. No `filterVM` counterpart: the Advanced popover
    /// has no subject control, because the bucket is chosen from a breakdown of the current result
    /// set rather than from a standing list.
    func clearSubjectFilter() {
        parameters.subjectBucket = nil
        parameters.subjectBucketKey = nil
        parametersVersion += 1
    }

    /// Clears the SUBJECT filter (#1023) — both halves of the durable key, or the fallback would
    /// resurrect it on the next resolution.
    ///
    /// Separate from `clearSubjectFilter` because the two are different grains and coexist: a
    /// reader can hold an area from the results facet and a topic from the explorer, and clearing
    /// one must not silently clear the other.
    func clearTopicFilter() {
        parameters.subjectRef = nil
        parameters.subjectName = nil
        parametersVersion += 1
    }

    func clearVolumeFilter() {
        // Clear the manual volume/subseries selection, then re-derive the scope so the
        // executed gate matches: in Focus this falls back to the subject-derived volumes
        // (the manual selection was overriding them, #377 Phase 2b); off/History simply
        // drop the volume constraint. `applyProjectScope` bumps only if the gate changed.
        if let fvm = filterVM {
            fvm.selectedVolumeIds = []
            fvm.selectedSubseriesIds = []
            applyProjectScope()
        } else {
            parameters.volumeIds = nil
            parametersVersion += 1
        }
    }

    func clearTagFilter() {
        parameters.userTagIds = []
        // The same stale-mirror defect as `clearPersonFilter`: `applyAdvancedFilters` rebuilds
        // `parameters.userTagIds` from `filterVM.selectedUserTagIds` (:727), so clearing only the
        // parameters left the selection checked in the popover and the filter returned on the next
        // edit there.
        filterVM?.selectedUserTagIds = []
        parametersVersion += 1
    }

    // MARK: - Advanced Filter Bridge

    /// Copies current `parameters` state into `filterVM` so the filter sheet
    /// shows the currently active values when presented. Creates `filterVM` on
    /// first call if `searchService` is available.
    func syncToFilterVM(
        searchService: SearchService?,
        volumeEntries: [VolumeManifestEntry] = [],
        indexedVolumeIds: Set<String> = [],
        userTags: [UserTag] = []
    ) {
        if filterVM == nil, let svc = searchService {
            filterVM = SearchViewModel(searchService: svc)
        }
        guard let filterVM else { return }

        // Populate the volume/subseries picker options; `mirrorParameters(into:)` then
        // reconstructs the picker selection from the currently active flat `volumeIds` scope
        // so the sheet shows what is actually applied.
        filterVM.loadAvailableVolumes(allEntries: volumeEntries, indexedIds: indexedVolumeIds)
        // User-tag filter (188-D parity, #212): feed the live tag list so the shared
        // `SearchFilterView.userTagsSection` appears on macOS. Because this runs on every
        // "Advanced…" open with a live @Query source, the section always reflects current tags
        // with no relaunch.
        filterVM.availableUserTags  = userTags
        mirrorParameters(into: filterVM)
    }

    /// Copies the window's `parameters` into the filter view model's fields, so that the popover
    /// shows what is applied, and what derives from the filter view model derives the search that ran.
    ///
    /// The second half of ``syncToFilterVM(searchService:volumeEntries:indexedVolumeIds:userTags:)``,
    /// split out for ``applyParameters(_:)`` (#1646): a hand-off or a recalled search replaces the
    /// parameters, and until this ran there too the filter view model kept the search before it.
    /// Whatever derived from it outside the popover then re-applied that search: the banner's ✕ (now
    /// ``leaveWorkingCorpus()``) dropped a person's Find all mentions and emptied the list, and a
    /// change of project (``applyProjectScope()``) put back the volumes it held.
    ///
    /// - Parameter filterVM: The filter view model, which the caller has made.
    private func mirrorParameters(into filterVM: SearchViewModel) {
        let scope = SearchViewModel.reconstructScope(
            from: parameters.volumeIds ?? [],
            available: filterVM.availableVolumes
        )
        filterVM.selectedSubseriesIds = scope.subseries
        filterVM.selectedVolumeIds    = scope.volumes

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")

        filterVM.facetYearKeys = parameters.yearKeys
        if let range = parameters.dateRange {
            filterVM.dateRangeEnabled = true
            if let earliest = range.earliest, let d = fmt.date(from: earliest) {
                filterVM.dateRangeStart = d
            }
            if let latest = range.latest, let d = fmt.date(from: latest) {
                filterVM.dateRangeEnd = d
            }
        } else {
            filterVM.dateRangeEnabled = false
        }

        filterVM.phrase             = parameters.phrase ?? ""
        filterVM.prefixWildcard     = parameters.prefixWildcard ?? ""
        filterVM.booleanMode        = parameters.booleanMode
        filterVM.excludedTermsText  = parameters.excludedTerms.joined(separator: ", ")
        filterVM.personRefText      = parameters.personRef ?? ""
        filterVM.personRollupId     = parameters.personRollupId
        filterVM.personLabel        = parameters.personLabel
        filterVM.personAnchor       = parameters.personAnchor
        filterVM.documentTypeFilter = parameters.documentTypeFilter
        filterVM.includeDocumentText = parameters.includeDocumentText
        filterVM.includeSummaries   = parameters.includeSummaries
        filterVM.includeNotes       = parameters.includeNotes
        // Seeded, not merely applied. A saved search archives the whole `SearchParameters` (#756),
        // so a recalled search really can arrive with front matter excluded; without this line the
        // popover would show it included and the next edit would silently re-include it.
        filterVM.includeFrontMatter = parameters.includeFrontMatter

        // User-tag filter (188-D parity, #212): reconstruct the active selection from
        // `parameters` so an applied tag filter shows its tags checked.
        filterVM.selectedUserTagIds = Set(parameters.userTagIds.compactMap { UUID(uuidString: $0) })
    }

    /// Copies `filterVM` state back into `parameters` and triggers a re-search.
    /// Called live by the Search window on each `filterVM.advancedFilterSignature`
    /// change while the filter popover is open (UI audit C4) — there is no
    /// dismiss-time batch anymore.
    func applyAdvancedFilters() {
        guard let filterVM else { return }

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")

        parameters.yearKeys = filterVM.facetYearKeys
        if filterVM.dateRangeEnabled {
            parameters.dateRange = DateRange(
                earliest: fmt.string(from: filterVM.dateRangeStart),
                latest:   fmt.string(from: filterVM.dateRangeEnd)
            )
        } else {
            parameters.dateRange = nil
        }

        parameters.phrase           = filterVM.phrase.isEmpty ? nil : filterVM.phrase
        parameters.prefixWildcard   = filterVM.prefixWildcard.isEmpty ? nil : filterVM.prefixWildcard
        parameters.booleanMode      = filterVM.booleanMode
        parameters.excludedTerms    = filterVM.excludedTermsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        parameters.personRef        = filterVM.personRefText.isEmpty ? nil : filterVM.personRefText
        parameters.personRollupId   = filterVM.personRollupId
        parameters.personLabel      = filterVM.personLabel
        parameters.personAnchor     = filterVM.personAnchor
        parameters.documentTypeFilter = filterVM.documentTypeFilter
        parameters.includeDocumentText = filterVM.includeDocumentText
        parameters.includeSummaries = filterVM.includeSummaries
        parameters.includeNotes     = filterVM.includeNotes
        // The fourth scope toggle, missing here until M-4. Its absence made the popover's
        // "Include front matter" checkbox a live control that changed nothing on macOS: #916 had
        // already put the property into `advancedFilterSignature`, so flipping it re-ran the search
        // — with this field unchanged. See `setIncludeFrontMatter(_:)`.
        parameters.includeFrontMatter = filterVM.includeFrontMatter
        // User-tag filter (188-D parity, #212): write the selection back so a chosen tag
        // actually narrows the FTS query and drives the "Tagged" summary chip.
        parameters.userTagIds       = filterVM.selectedUserTagIds.map(\.uuidString)
        // Volume scope + project History/Focus gates (#377 Phase 2): a single derivation
        // from the filter VM's scope (see `scopeDerivedParams`) so `applyAdvancedFilters` and
        // `applyProjectScope` never diverge.
        let scoped = scopeDerivedParams()
        parameters.volumeIds          = scoped.volumeIds
        parameters.documentIds        = scoped.documentIds
        parameters.excludeDocumentIds = scoped.excludeDocumentIds

        // Keep scope toggles in sync. Direct assignment to the backing storage
        // would skip the `didSet` observers (which bump `parametersVersion`), but
        // since we already bump `parametersVersion` below this is intentional —
        // the chips just visually reflect what advanced filters already applied.
        scopeDocuments  = filterVM.includeDocumentText
        scopeNotes      = filterVM.includeNotes
        scopeSummaries  = filterVM.includeSummaries

        parametersVersion += 1
    }

    // MARK: - Pending Search Application

    /// Applies a `SearchParameters` snapshot received from `AppState.pendingSearch`, or recalled
    /// from Saved Searches.
    ///
    /// Sets both `parameters` and the reflected UI state (scope toggles, query text, the filter
    /// view model), then bumps `parametersVersion` so `.task(id: searchTrigger)` fires a new search.
    /// The search runs inside the applied working corpus, if there is one, and under none of the
    /// snapshot's own document gates (`SearchParameters.runningInside(workingCorpus:)`, #1646).
    ///
    /// A keyword-less person handoff (the People browser's "Find all mentions") runs on its
    /// `personRef`/`personRollupId` filter alone — `performSearch` now treats a person filter as a
    /// valid standalone term, and the `parametersVersion` bump fires the search. We no longer
    /// fabricate a `"person:<ref>"` query string (which used to leak into the FTS keywords).
    ///
    /// Every hand-off and saved-search recall leaves a held list (#1577 lane 5, rule 3): the list it
    /// would otherwise run inside is no part of what it hands over.
    func applyParameters(_ params: SearchParameters) {
        leaveBaseForHandoff()
        let kw = params.keywords ?? ""
        queryText = kw
        submittedQuery = kw
        // Project History/Focus scope is a live, manual choice — never inherited from a
        // restored snapshot or a pending-search hand-off (#377 Phase 2). Clear the filter VM's
        // selection so the picker matches, and so a later unrelated filter edit (which re-runs
        // `applyAdvancedFilters`) can't silently reintroduce a gate.
        filterVM?.projectScope = .off
        filterVM?.projectOnlyNew = false
        // The snapshot's own document gates go with it. The applied working corpus does not: it
        // is this window's state, its banner goes on naming it, and the search runs inside it, as
        // iPhone and iPad's does (#1646). Until #1646 the corpus was dropped here with the
        // project's gates and nothing composed it back, so a hand-off or a recalled search ran
        // over the whole scope under "Inside …".
        parameters = params.runningInside(workingCorpus: filterVM?.appliedWorkingCorpusKeys)
        // And the filter VM takes the new parameters, so that an edit made outside the popover
        // re-applies this search and not the one before it (`mirrorParameters(into:)`).
        if let filterVM { mirrorParameters(into: filterVM) }
        scopeDocuments = params.includeDocumentText
        scopeNotes     = params.includeNotes
        scopeSummaries = params.includeSummaries
        parametersVersion += 1
    }

    /// Applies a search hand-off (`AppState.pendingSearch`).
    ///
    /// A hand-off that names something to find runs as a keyword search whatever the picker showed, as
    /// a saved search does (``SearchParameters/namesASearchToRun``). The window used to keep the picker's
    /// mode, so Corpus Analytics' "View N documents", followed while the window was on Meaning, ranked
    /// the term by meaning and did not show those N documents, and a person's Find all mentions, which
    /// carries no question, showed an empty list.
    ///
    /// A hand-off that names nothing to find leaves a held list's engine in the control, the engine of
    /// the rows put back (#1577 lane 5), as on iPhone and iPad.
    func applyHandoff(_ params: SearchParameters) {
        let namesASearch = params.namesASearchToRun
        let heldListEngine = pinnedBase?.direction.baseEngine
        if namesASearch { searchMode = .keywords }
        applyParameters(params)
        if !namesASearch, let heldListEngine { searchMode = heldListEngine }
    }

    /// Re-derives `parameters.documentIds` from the filter VM's current project scope +
    /// engaged-key set and re-runs the search **only if the effective gate changed**
    /// (#377 Phase 2a). Called by `SearchSheet` after it (re)loads the engaged set — on
    /// opening Advanced filters and on an active-project change — so the executed query
    /// always reflects the live project scope without re-searching when nothing changed
    /// (e.g. merely opening the panel with no scope active; the engaged set is stored sorted
    /// so an unchanged set compares equal). Note: if the active project changes *while* the
    /// Advanced popover is open with History active, this bump plus the popover's own
    /// `advancedFilterSignature` observer (which sees the scope flip to `.off`) can both fire
    /// — two re-searches for one switch, both correctly yielding the ungated result.
    func applyProjectScope() {
        guard filterVM != nil else { return }
        let scoped = scopeDerivedParams()
        if scoped.volumeIds != parameters.volumeIds
            || scoped.documentIds != parameters.documentIds
            || scoped.excludeDocumentIds != parameters.excludeDocumentIds {
            parameters.volumeIds          = scoped.volumeIds
            parameters.documentIds        = scoped.documentIds
            parameters.excludeDocumentIds = scoped.excludeDocumentIds
            parametersVersion += 1
        }
    }

    /// Leaves the applied working corpus, and runs the same search again over the full scope: the
    /// banner's ✕ (#1646).
    ///
    /// Only the document gate is derived again, from the project's scope with no corpus in it. The ✕
    /// called `applyAdvancedFilters()`, which copies back every field the popover edits from the
    /// filter view model, and a facet's narrowing writes `parameters` alone: so the ✕ undid a person
    /// or a year chosen in Facets, and, until `applyParameters(_:)` mirrored its parameters, a
    /// hand-off's own filters, which after a person's Find all mentions emptied the list.
    func leaveWorkingCorpus() {
        filterVM?.clearWorkingCorpus()
        let scoped = scopeDerivedParams()
        parameters.documentIds        = scoped.documentIds
        parameters.excludeDocumentIds = scoped.excludeDocumentIds
        parametersVersion += 1
    }

    /// The volume scope + project History/Focus gates derived from the filter VM's current
    /// scope (#377 Phase 2). The single source both `applyAdvancedFilters` and
    /// `applyProjectScope` use, so the executed `parameters` never disagree about the scope.
    /// - Focus overrides the volume scope with the subject-derived focus volumes and,
    ///   with "only new" on, excludes the engaged set; History gates to the engaged set;
    ///   off uses the manual volume/subseries selection.
    private func scopeDerivedParams() -> (volumeIds: [String]?, documentIds: [String]?, excludeDocumentIds: [String]?) {
        guard let fvm = filterVM else { return (nil, nil, nil) }
        let manualVolumes = fvm.effectiveVolumeIds.isEmpty ? nil : fvm.effectiveVolumeIds
        let volumeIds: [String]?
        let documentIds: [String]?
        switch fvm.projectScope {
        case .off:
            volumeIds = manualVolumes
            documentIds = nil
        case .history:
            volumeIds = manualVolumes
            documentIds = fvm.projectEngagedDocumentKeys
        case .focus:
            // A manual volume selection (or applied custom scope) overrides the subject-
            // derived focus volumes; with neither, Focus matches nothing (empty
            // `documentIds`, per the History contract) rather than the whole corpus.
            if let manual = manualVolumes {
                volumeIds = manual
                documentIds = nil
            } else if fvm.projectFocusVolumeIds.isEmpty {
                volumeIds = nil
                documentIds = []
            } else {
                volumeIds = fvm.projectFocusVolumeIds
                documentIds = nil
            }
        }
        let exclude = (fvm.projectScope == .focus && fvm.projectOnlyNew)
            ? fvm.projectEngagedDocumentKeys : nil
        // M-1: the working corpus composes with whatever the project scope already gated, by
        // INTERSECTION — both are document-grain constraints the user applied. Missing here, an
        // applied corpus was written to `filterVM` and never reached `parameters`, so the Mac
        // search ignored it entirely while the filter sheet showed it as applied.
        let gated = DocumentScopeGate.combine(corpus: fvm.appliedWorkingCorpusKeys,
                                              projectGate: documentIds)
        return (volumeIds, gated, exclude)
    }

    // MARK: - Search

    /// Commits the current `queryText` as the submitted query and fires a search.
    ///
    /// Sets `submittedQuery = queryText`, which changes `searchTrigger` and causes
    /// the `.task(id: searchTrigger)` observer in `SearchSheet` to call `performSearch`.
    /// This is the only path the field updates `submittedQuery` by; it is bound to
    /// `.onSubmit` (Return key) so searches fire only when the user explicitly submits.
    /// A hand-off sets it as well (`applyParameters(_:)`), and holding or leaving a list
    /// (#1577 lane 5) empties it and puts it back.
    func submitSearch() {
        submittedQuery = queryText
    }

    /// Executes a search against `SearchService` using `submittedQuery` and the current `parameters`.
    ///
    /// Fetches up to `searchHardLimit` (7,500) results so all pagination pages are available
    /// client-side. In parallel, fetches the true total match count via
    /// `SearchService.searchCount` and stores it in `totalMatchCount`. When all three scope
    /// flags are disabled (`includeDocumentText`, `includeSummaries`, `includeNotes` all
    /// false), a friendly error is set before any FTS5 call is attempted.
    ///
    /// `currentPage` is reset to 0 on every successful fetch; if the result set shrank below
    /// the previous page index it is clamped to a valid page.
    ///
    /// ## A run a later one replaced (#1648, #1680)
    /// Called only from `.task(id: searchTrigger)` in `SearchSheet`. When `searchTrigger` changes,
    /// SwiftUI cancels the running task and starts a new one. Since #1680 the kit stops a cancelled
    /// task's search, the pipeline's statement at its progress handler's next call (usually within a
    /// millisecond) and the snippet pass at its next row, and `search` and `searchCount` throw
    /// `CancellationError`, on which the catch below returns; a run whose count alone was stopped,
    /// after its rows came back, returns at the check after its last wait. Either way a cancelled run
    /// writes nothing, and the search that replaced it no longer waits for it. The run is still
    /// numbered as it starts (``SearchRunLedger``), because a Meaning run, whose engine does not stop,
    /// comes back all the same; once its last wait is over a run that is no longer the latest returns
    /// without writing anything, leaving the rows on screen to the run that replaced it. `isSearching`
    /// is reset by the latest run alone.
    ///
    /// ## Inside a held list (#1577 lane 5)
    /// Words typed over a held Meaning list are searched inside it, and the rows found are put in its
    /// order with its scores (`LayeredResultComposer.wordsInMatches(keywordRows:base:)`); a question
    /// typed over a held keyword list goes to `performMeaningSearch`, which ranks the list. Neither
    /// re-anchors the checklist: a layer runs inside the list's search. An empty field inside a held
    /// list searches nothing: the list's own rows are shown, and filters set meanwhile wait for the
    /// words or the question they will narrow, as on iPhone and iPad. And the search the trigger asks
    /// for as a held list is left, which its restored rows answer, runs nothing (``AnsweredSearchTrigger``).
    ///
    /// - Returns: `true` when this run was not replaced, so that what it wrote is what the window
    ///   shows. The window records the search, and starts over its facets, only then. A held list's
    ///   own rows put back by an empty field are what the window shows, so the facets start over for
    ///   them, and the trail records nothing, since it records no search without words.
    @discardableResult
    func performSearch(service: SearchService?) async -> Bool {
        let run = searchRuns.startRun()
        // The rows a held list put back on leaving answer this search already (#1577 lane 5).
        if answeredTrigger.consume(searchTrigger) { return false }
        // Tags given to the rows on screen go with a held list before a layer replaces them, so that
        // a ranking of it, built from its members, carries them.
        foldShownTagsIntoBase()
        if pinnedBase != nil, submittedQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Inside a held list an empty field searches nothing: its own rows are shown again.
            guard isSearching || !isShowingBase || searchError != nil else { return false }
            showBaseRows()
            return true
        }
        if searchMode == .meaning {
            return await performMeaningSearch(run: run)
        }
        lastRunWasSemantic = false
        let query = submittedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        // A person filter (single ref or a cross-corpus rollup) or a subject filter is a valid
        // standalone term, so a keyword-less "Find all mentions" handoff runs on it alone.
        let hasStandaloneFilter = parameters.supportsFilterOnlySearch
        guard (!query.isEmpty || hasStandaloneFilter), let service else {
            // This replaced any run under way, which will clear nothing now (#1648).
            isSearching = false
            results = []
            executedRoute = .keywords
            totalMatchCount = nil
            lastRenderedExpression = nil
            // `SearchSheet` shows any standing error beside empty results, so the last search's must go with them.
            searchError = nil
            return true
        }

        // Inside a held Meaning list this run is the words found in it (#1577 lane 5), gated to the list
        // here and nowhere else in what a keyword search sends. Read before the await, with the run.
        let base = pinnedBase
        // A filter narrows the words only where one is set and it is not one the list ran under.
        let filtersNarrowed = base?.filtersNarrow(parameters) ?? false
        var params = LayeredResultComposer.gating(parameters, inside: base)
        params.keywords = query.isEmpty ? nil : query

        // Empty scope guard: at least one of the three scope flags must be enabled.
        // Without this, SearchService throws `emptyQuery`, which surfaces as an unhelpful
        // technical error string.
        //
        // Skipped for a filter-only query, which has no MATCH and therefore nothing to scope.
        // Applying it there rejected a perfectly runnable subject- or person-only search on macOS
        // while iOS ran it — the twin divergence #1022 set out to remove (#1022 review).
        guard params.includeDocumentText || params.includeSummaries || params.includeNotes
                || (params.supportsFilterOnlySearch && !params.hasTextTerms) else {
            isSearching = false
            results = []
            executedRoute = .keywords
            totalMatchCount = nil
            lastRenderedExpression = nil
            searchError = MacSearchError.emptyScope
            return true
        }

        isSearching = true
        searchError = nil
        currentPage = 0
        // The latest run ends the search; a run a later one replaced leaves that to it (#1648).
        defer { if searchRuns.isLatest(run) { isSearching = false } }

        // Re-anchor the checklist ONLY when the search itself changed (#189-D). `performSearch`
        // also re-runs on every filter/scope change (those bump `parametersVersion`, part of
        // `searchTrigger`), so an unconditional re-anchor would silently wipe the user's reviewed
        // marks whenever they touched a filter mid-session. `ChecklistAnchor` keeps marks across
        // re-runs of the same search while still clearing them for a new one: the same words by
        // the history writer's own rule (`SearchHistoryWriter.isSameQuery`, #1298), and for a
        // browse with no words the same person and subject (#1576 lane 1). Reviewed identity is
        // document identity, which recurs across searches, so a stale mark must not leak into an
        // unrelated search. Built from the parameters this run is about to send. Not for words found
        // in a held list, which run inside its search and keep its checklist (#1577 lane 5): their
        // words would re-anchor it, and the marks made on the list would be lost on leaving it.
        if base == nil {
            settleChecklist(for: ChecklistAnchor(query: query, parameters: params))
        }

        // Capture an immutable copy so Swift 6 region-based isolation is happy
        // when the same parameters value is sent to two actor-isolated calls below.
        let frozenParams = params

        // A browse fetches under its own ceiling because its rows are far smaller — no `body_text`,
        // since there are no terms to snippet against. Recorded below, with the rows, so
        // `isResultSetTruncated` compares against the ceiling actually used.
        let fetchLimit = frozenParams.runsAsFilterOnly
            ? Self.filterOnlyHardLimit : Self.searchHardLimit

        // #1577 lane 1: a search inside a document set is timed, for `SearchTimingLog`.
        let clock = ContinuousClock()
        let sent = clock.now

        // Fetch results and total count in parallel. searchCount runs an FTS5 COUNT(*)
        // without snippet/bm25 work so it returns substantially faster than search().
        async let resultsTask  = service.search(parameters: frozenParams, limit: fetchLimit)
        async let countTask    = service.searchCount(parameters: frozenParams)
        async let expressionTask = try? service.matchExpressions(for: frozenParams).corpus
        do {
            let fetched = try await resultsTask
            let rowsTime = clock.now - sent
            let expression = await expressionTask
            let counted = try? await countTask
            let totalTime = clock.now - sent
            // A run a later one replaced writes nothing (#1648). Asked once, after the last wait, so
            // that the window shows one run's rows with their own total and expression. Written as each
            // came back, the rows stood under the last search's total until the count arrived, and for
            // good when the run was replaced in between. So the rows now wait for the count, which
            // follows the fetch on the pipeline: 11 to 21% of the search's time, measured on the full
            // store (`SearchViewModel.totalMatchCount`).
            // Nor does a run whose task the window cancelled (#1680). One a later trigger replaced is the
            // ledger's to drop as well, but one cancelled by the window closing is still the latest, and
            // its count, stopped by the kit after the rows came back, reads as nil through `try?`.
            guard !Task.isCancelled else { return false }
            guard searchRuns.isLatest(run) else { return false }
            if let base {
                // Words found in a held Meaning list (#1577 lane 5): the rows of it that hold them, in its
                // order with its scores.
                results = LayeredResultComposer.wordsInMatches(keywordRows: fetched, base: base)
                executedRoute = .wordsInMatches(base: base.members.count)
                // A layer runs inside the list's search, whose checklist it keeps. Its rows are another
                // list, so picks end.
                endSelecting()
                lastLayerFiltersNarrowed = filtersNarrowed
            } else {
                results = fetched
                // With the rows and before the next suspension, so that no pass draws another
                // search's rows under this one's selection (#1576 lane 4). The anchor is the one the
                // checklist was settled by above: `params` has not changed since.
                settleSelection(for: ChecklistAnchor(query: query, parameters: params))
                executedRoute = .keywords
                // The filters a list held from these rows was found under (#1577 lane 5).
                filterSignatureOfTheRows = SearchScopeSignature.signature(for: params)
            }
            // With the rows, not before the await: a run that is replaced keeps the previous rows,
            // and they keep the ceiling and the engine they came from.
            lastFetchLimit = fetchLimit
            beyondLibraryHits = []
            semanticDisclosure = nil
            semanticNeedsModel = false
            // A layer's expression names its list as well, for the method appendix's CSV (#1577 lane 5).
            lastRenderedExpression = base.map { inside in expression.map { $0 + inside.renderedExpressionSuffix } }
                ?? expression
            executedSearchVersion &+= 1
            // #1310: the parameters that RAN. Filter edits re-run the search here, so these are
            // the executed ones by the time the popover reads them.
            userTagCountScope = .match(submittedSearchParameters)
            // Deliberately NOT `?? fetched.count`. An unavailable count is unknown, not
            // equal to what happened to be fetched — see `totalMatchCount`. A layer's stays `nil`, as
            // on iPhone and iPad: a capture stores the total beside its partial flag, and the layer's
            // own count there would read back as "captured from 7 matches" (#1577 lane 5).
            if base != nil {
                totalMatchCount = nil
            } else if let total = counted {
                // `max` guards the reverse inconsistency: a count that somehow came back
                // below the fetch would understate the result set.
                totalMatchCount = max(total, fetched.count)
            } else {
                totalMatchCount = nil
            }
            if let documentSet = frozenParams.documentIds {
                SearchTimingLog.record(SearchTimingLog.GatedKeyword(
                    setSize: documentSet.count, rowCount: fetched.count,
                    rows: rowsTime, total: totalTime))
            }
            // Clamp page index to the new result set.
            if currentPage >= totalPages { currentPage = max(0, totalPages - 1) }
            #if DEBUG
            // `totalMatchCount` is Optional — nil when the whole-query count was not fetched
            // (see the branch above). Interpolating it directly printed "Optional(1234)", or
            // the bare word "nil", which is why the compiler flags the debug-description
            // interpolation: the log line was less readable than it looked.
            print("[MacSearchViewModel] Search returned \(fetched.count)/"
                  + "\(totalMatchCount.map(String.init) ?? "not counted") results")
            #endif
        } catch {
            // A cancelled run writes nothing and keeps the rows on screen. Since #1680 the kit throws
            // `CancellationError` for a search whose task the window cancelled: one a later trigger
            // replaced, or the window closing.
            guard !(error is CancellationError) else { return false }
            // A run a later one replaced says nothing of its failure either.
            guard searchRuns.isLatest(run) else { return false }
            // The same mapping as iOS: a query the parse refused becomes a readable message pointing at Search
            // Tips, and every other failure is stored unchanged (#1299).
            searchError = SearchQueryRefusal.readable(error, for: frozenParams)
            results = []
            executedRoute = .keywords
            totalMatchCount = nil
            lastRenderedExpression = nil
            #if DEBUG
            print("[MacSearchViewModel] Search failed: \(error)")
            #endif
        }
        return true
    }

    /// The Meaning run — `SearchViewModel.searchMeaning`'s macOS twin, with this window's own
    /// bookkeeping contract (typed `searchError`, a replaced run that writes nothing, the
    /// checklist's query-keyed re-anchor). Inside a held keyword list or browse the question ranks
    /// the list (`rankHeldList(run:base:backend:)`), which keeps the list's checklist (#1577 lane 5).
    ///
    /// - Parameter run: This run's number, from `performSearch(service:)` (#1648).
    /// - Returns: `true` when this run was not replaced, as `performSearch(service:)` returns.
    private func performMeaningSearch(run: Int) async -> Bool {
        let query = submittedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            // This replaced any run under way, which will clear nothing now (#1648).
            isSearching = false
            results = []
            executedRoute = .keywords
            beyondLibraryHits = []
            semanticDisclosure = nil
            totalMatchCount = nil
            lastRenderedExpression = nil
            // As in `performSearch`: the window shows a standing error beside empty results.
            searchError = nil
            return true
        }
        guard let backend = semanticBackend else {
            isSearching = false
            results = []
            executedRoute = .keywords
            searchError = SemanticModeError.unavailable
            return true
        }
        isSearching = true
        searchError = nil
        currentPage = 0
        semanticNeedsModel = false
        lastRunWasSemantic = true
        defer { if searchRuns.isLatest(run) { isSearching = false } }
        // The same-search rule `performSearch` settles by, and for a question the one the history
        // writer refreshes a Meaning run's row by, so a respelled Meaning query keeps its marks as
        // it keeps its row. Not for a question ranking a held list, which runs inside its search and
        // keeps its checklist (#1577 lane 5).
        if pinnedBase == nil {
            settleChecklist(for: ChecklistAnchor(query: query, parameters: parameters))
        }
        // Taken before the run: the filters can change while it is under way, and the selection
        // is settled by the search that was sent (#1576 lane 4). So are the filters the rows are
        // found under, which a list held from them compares a layer's with (#1577 lane 5).
        let sentAnchor = ChecklistAnchor(query: query, parameters: parameters)
        let sentFilterSignature = SearchScopeSignature.signature(for: parameters)
        do {
            // Inside a held keyword list or browse this run ranks it by the question (#1577 lane 5).
            // Its failures are this function's, in the `catch`es below.
            if let base = pinnedBase {
                return try await rankHeldList(run: run, base: base, backend: backend)
            }
            let outcome = try await backend.run(query: query, parameters: parameters)
            // A Meaning run a later search replaced writes nothing, nor does its failure below
            // (#1648): the Meaning engine does not stop when its task is cancelled, as the kit's
            // keyword search does since #1680.
            guard searchRuns.isLatest(run) else { return false }
            results = outcome.results
            settleSelection(for: sentAnchor)
            filterSignatureOfTheRows = sentFilterSignature
            lastFetchLimit = SemanticSearchBackend.hitLimit
            executedRoute = .meaning
            beyondLibraryHits = outcome.beyondLibrary
            semanticDisclosure = outcome.disclosure
            // nil, not the hit count: the SavedSearch freshness watermark diffs matchCount
            // against a later FTS count, and a semantic number there mints phantom deltas.
            totalMatchCount = nil
            // Printed in the method appendix's CSV verbatim — the honest record of what ran.
            lastRenderedExpression = SemanticSearchBackend.renderedExpression
            executedSearchVersion &+= 1
            // #1310: counted over the results themselves — the meaning route has no FTS match.
            userTagCountScope = .resultKeys(results.map {
                UserTagCountScope.DocumentKey(volumeId: $0.volumeId, documentId: $0.documentId)
            })
            if currentPage >= totalPages { currentPage = max(0, totalPages - 1) }
        } catch SemanticQuerySearcher.SearchUnavailable.modelNotDownloaded {
            guard searchRuns.isLatest(run) else { return false }
            results = []
            executedRoute = .keywords
            // No rows, so no reader of the scope sees it; recorded for the history row, which has
            // always carried the Meaning engine's list length for a Meaning run that found no model.
            lastFetchLimit = SemanticSearchBackend.hitLimit
            beyondLibraryHits = []
            semanticDisclosure = nil
            totalMatchCount = nil
            lastRenderedExpression = nil
            semanticNeedsModel = true
            executedSearchVersion &+= 1
            userTagCountScope = nil
        } catch {
            guard !(error is CancellationError) else { return false }
            guard searchRuns.isLatest(run) else { return false }
            results = []
            executedRoute = .keywords
            lastFetchLimit = SemanticSearchBackend.hitLimit
            beyondLibraryHits = []
            semanticDisclosure = nil
            totalMatchCount = nil
            lastRenderedExpression = nil
            executedSearchVersion &+= 1
            userTagCountScope = nil
            searchError = (error as? SemanticQuerySearcher.SearchUnavailable) == .queryTooLong
                ? SemanticModeError.tooLong : SemanticModeError.failed
        }
        return true
    }

    /// A held keyword list or browse ranked by the question submitted (#1577 lane 5): every row of the
    /// list, closest first, and the rows the engine cannot rank last, in the list's own order.
    /// `SearchViewModel.rankHeldList(run:base:backend:)` is its twin.
    ///
    /// ``performMeaningSearch(run:)``'s second path, apart from it so that the plain Meaning run's rows are
    /// the only ones that are a Meaning list; what fails here is thrown to that function's `catch`es. The
    /// ranking is handed the list gated by `LayeredResultComposer.gating(_:inside:)`, so that a working
    /// corpus applied since narrows it, and the other filters narrow the ranked rows after. It keeps the
    /// list's ceiling and total, so the list stays cut where its keyword fetch was cut, and its expression
    /// says it ranked the whole list, not a top hundred. It runs inside the list's search, whose checklist
    /// it keeps; its rows are another list, so picks end.
    ///
    /// - Parameters:
    ///   - run: This run's number, from `performSearch(service:)` (#1648).
    ///   - base: The held list.
    ///   - backend: The Meaning engine.
    /// - Returns: `true` when this run was not replaced, as `performSearch(service:)` returns.
    private func rankHeldList(run: Int, base: PinnedResultBase, backend: any MeaningSearchRunning) async throws -> Bool {
        // A list cut at its ceiling is ranked whole (#1577 lane 6).
        if base.ranksWholeMatch, let ran = base.ranParameters {
            return try await rankWholeMatch(run: run, base: base, match: ran, backend: backend)
        }
        let query = submittedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let ranking = try await backend.rerank(query: query, base: base.members,
                                               parameters: LayeredResultComposer.gating(parameters, inside: base))
        guard searchRuns.isLatest(run) else { return false }
        results = ranking.results
        executedRoute = .rankedByMeaning(unranked: ranking.results.filter { $0.semanticScore == nil }.count)
        endSelecting()
        beyondLibraryHits = ranking.beyondLibrary
        semanticDisclosure = ranking.disclosure
        totalMatchCount = base.totalMatchCount
        lastFetchLimit = base.fetchLimit
        lastRenderedExpression = SemanticSearchBackend.renderedExpression(rankingAll: base.members.count)
            + base.renderedExpressionSuffix
        executedSearchVersion &+= 1
        userTagCountScope = .resultKeys(results.map {
            UserTagCountScope.DocumentKey(volumeId: $0.volumeId, documentId: $0.documentId)
        })
        if currentPage >= totalPages { currentPage = max(0, totalPages - 1) }
        return true
    }

    /// A held list cut at its 7,500-row ceiling ranked whole by the question submitted (#1577 lane 6): the closest
    /// documents of its match, up to the ceiling, then the list's own rows the engine cannot rank, if there is room.
    /// `SearchViewModel.rankWholeMatch(run:base:match:backend:)` is its twin.
    ///
    /// ``rankHeldList(run:base:backend:)``'s path for such a list, with the same bookkeeping. The ranking is handed the
    /// parameters outside the held list, ``parameters``, whose gate is a working corpus applied since, never the
    /// list's rows. It runs in the window's search task, which the window cancels when its trigger changes, and the
    /// kit then stops its statements. The match's keys are kept with the held list, and the trail signs the documents
    /// ranked inside (``rankedSetSignature``).
    ///
    /// - Parameters:
    ///   - run: This run's number, from `performSearch(service:)` (#1648).
    ///   - base: The held list.
    ///   - ran: The search that found it, whose match is ranked.
    ///   - backend: The Meaning engine.
    /// - Returns: `true` when this run was not replaced, as `performSearch(service:)` returns.
    private func rankWholeMatch(run: Int, base: PinnedResultBase, match ran: SearchParameters,
                                backend: any MeaningSearchRunning) async throws -> Bool {
        let query = submittedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let whole = try await backend.rankWholeMatch(query: query, base: base, match: ran,
                                                     parameters: parameters, limit: base.fetchLimit)
        guard searchRuns.isLatest(run) else { return false }
        pinnedBase?.keepWholeMatch(whole.matchKeys)
        results = whole.outcome.results
        executedRoute = .rankedByMeaning(unranked: whole.outcome.results.filter { $0.semanticScore == nil }.count,
                                         wholeMatch: whole.ranking)
        endSelecting()
        beyondLibraryHits = whole.outcome.beyondLibrary
        semanticDisclosure = whole.outcome.disclosure
        rankedSetSignature = whole.setSignature
        totalMatchCount = base.totalMatchCount
        lastFetchLimit = base.fetchLimit
        // The held list as it is now, with its match's keys, so that its part counts the match (`signaturePart`).
        lastRenderedExpression = SemanticSearchBackend.renderedExpression(rankingAll: whole.ranking.size,
                                                                          listing: base.fetchLimit)
            + (pinnedBase ?? base).renderedExpressionSuffix
        executedSearchVersion &+= 1
        userTagCountScope = .resultKeys(results.map {
            UserTagCountScope.DocumentKey(volumeId: $0.volumeId, documentId: $0.documentId)
        })
        if currentPage >= totalPages { currentPage = max(0, totalPages - 1) }
        return true
    }

    /// Replaces every search still under way without starting one, for rows cleared with no search
    /// (#1648): the window empties them itself when the index is rebuilt. A run that comes back after
    /// this writes nothing, so it cannot put the old index's rows back, and nothing is searching any
    /// more.
    func replaceSearchesUnderWay() {
        searchRuns.replaceRunsUnderWay()
        isSearching = false
    }

    // MARK: - Search History

    /// What this window last wrote to the trail — see ``SearchHistoryWriter/Anchor``.
    ///
    /// Filter and scope changes bump `parametersVersion`, which re-runs `performSearch` for the
    /// **same** `submittedQuery`. Those are not separate searches the researcher ran, so they
    /// refresh the anchored row rather than minting a second one — but the row's scope and counts
    /// become the ones it finally ran under, which is the M-2 fix.
    private var historyAnchor: SearchHistoryWriter.Anchor?

    /// The Meaning signature the trail records for the rows on screen: the documents a ranking of a whole match
    /// ranked inside (#1577 lane 6), which ``submittedSearchParameters`` does not hold, or the set the parameters
    /// hold. `SearchViewModel`'s is its twin.
    private var meaningSignature: String {
        if case .rankedByMeaning(_, _?) = executedRoute, let rankedSetSignature { return rankedSetSignature }
        return SearchScopeSignature.semanticSignature(for: submittedSearchParameters)
    }

    /// Records the most recently executed search — the macOS half of the trail's search producer.
    ///
    /// Call once after `performSearch` completes. All the rules — the research-logging gate, the
    /// empty-query and error skips, and the insert-or-refresh decision — live in
    /// ``SearchHistoryWriter``, shared with iOS.
    ///
    /// - Parameters:
    ///   - projectId: the project active at execution, or `nil` in global context.
    ///   - indexedVolumeCount: how many volumes this device has indexed — the denominator.
    ///   - context: the context to write to.
    ///   - defaults: where the research-logging switch is read from.
    func recordSearchHistory(projectId: UUID?,
                             indexedVolumeCount: Int? = nil,
                             in context: ModelContext,
                             defaults: UserDefaults = .standard) {
        // A layer's row records the list it shows as its whole answer (#1577 lane 5, as on iPhone and
        // iPad): left with no match count, a complete ranking of 212 rows would print as "at least
        // 212", and a ranking keeps its list's total, which is no count of the layer.
        let layer = executedRoute.isLayer ? pinnedBase : nil
        let outcome = SearchHistoryWriter.record(
            SearchHistoryWriter.Reading(
                queryText: submittedQuery.trimmingCharacters(in: .whitespacesAndNewlines),
                // The true total when there is one, the fetched count otherwise. Before Q-M2 an
                // unavailable count was written as exactly the fetch cap, so a trail entry could
                // record "7,500" for a query matching 195,519 — a number a researcher may cite.
                resultCount: layer != nil ? results.count : resultCountForDisplay,
                loadedCount: results.count,
                matchCount: layer != nil ? results.count : totalMatchCount,
                fetchLimit: lastFetchLimit,
                indexedVolumeCount: indexedVolumeCount,
                parameters: submittedSearchParameters,
                appliedCorpusId: filterVM?.appliedWorkingCorpusId,
                renderedExpression: lastRenderedExpression,
                // See the iOS twin: a Meaning run records the route signature, never an
                // FTS-shaped scope the appendix would decode into keyword claims. Inside a
                // document set it names the set as well (#1577 lane 1), and a layer adds its list
                // (`base=`, lane 5), which an earlier build passes over.
                signatureOverride: SearchScopeSignature.layered(
                    lastRunWasSemantic ? meaningSignature : nil,
                    parameters: submittedSearchParameters, base: layer),
                projectId: projectId,
                hasError: searchError != nil),
            anchor: &historyAnchor,
            in: context,
            defaults: defaults)
        #if DEBUG
        print("[MacSearchViewModel] SearchHistoryEntry \(outcome): \"\(submittedQuery)\"")
        #else
        _ = outcome
        #endif
    }
}

// MARK: - MacSearchError

/// User-facing error states that originate in `MacSearchViewModel` rather than the
/// underlying `SearchService` / `FTS5Store` layer.
///
/// Version history:
///   1.0 — Session 120: added for the empty-scope guard in `performSearch`
/// The Meaning mode's typed errors, for the window's `Error?`-shaped `searchError`.
enum SemanticModeError: LocalizedError {
    case unavailable
    case tooLong
    case failed

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return String(localized: "search.semantic.error.unavailable.mac",
                          defaultValue: "Searching by meaning is not available in this build.")
        case .tooLong:
            return String(localized: "search.semantic.error.tooLong.mac",
                          defaultValue: "This search is too long for the model. Try a shorter phrasing.")
        case .failed:
            return String(localized: "search.semantic.error.failed.mac",
                          defaultValue: "Semantic search could not run. Try again.")
        }
    }
}

enum MacSearchError: LocalizedError {
    /// All three "Search in" scope flags are disabled — there is nothing to search.
    case emptyScope

    var errorDescription: String? {
        switch self {
        case .emptyScope:
            return String(
                localized: "search.error.emptyScope",
                defaultValue: "Enable at least one of Documents, Notes, or Summaries to search."
            )
        }
    }
}

#endif // os(macOS)
