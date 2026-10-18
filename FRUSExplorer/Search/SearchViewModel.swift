// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData
import Observation

// MARK: - SearchViewModel

/// Manages state and business logic for the Search view.
///
/// Holds the full set of search parameters and drives the results list.
/// Binds directly to `SearchService` for FTS5 queries.
///
/// ## Project Defaults
/// Call `applyProjectDefaults(_:)` after init to pre-populate filters from
/// the active project's default date range and subject tag IDs.
///
/// ## Lifecycle
/// 1. Init with `searchService`.
/// 2. `SearchView` feeds `availableUserTags` from a live `@Query`, so a tag created
///    elsewhere (e.g. the research-note editor) appears as a filter chip without a restart.
/// 3. Optionally call `applyProjectDefaults(_:)` if a project is active.
/// 4. Call `search()` when the user submits.
///
/// ## Suffix Wildcard Limitation
/// Only prefix wildcards are supported by FTS5 (e.g. `negoti*`). The `*`
/// is appended automatically to `prefixWildcard`. Suffix wildcards (`*ate`)
/// are not valid FTS5 syntax and are not exposed in the UI.
///
/// Version history:
///   1.0 — Session 16: initial implementation
///   1.1 — Session 38: `documentTypeFilter` property added
///   1.2 — Session 40: `personRefText` property and `applyParameters(_:)` added
///   1.3 — Session 62: `showFilterPanel` semantics changed from inline panel to sheet flag
///   1.4 — Session 100: `appState` property for logEvent(.searchSubmit) after search()
///          (both removed in Wave R-2a — see the last entry)
///   1.5 — Session 130: `searchHardLimit = 500` passed to `searchService.search()`; iOS
///          was silently capped at `defaultPageSize = 20` (the macOS VM already used 7 500)
///   1.6 — Session 2026-06-08: `phrase`, `prefixWildcard`, `booleanMode`, and
///          `excludedTermsText` are no longer user-editable — `SearchFilterView`'s
///          "Advanced Text" controls were removed in favour of `FTS5InlineQueryParser`
///          inline syntax in the main search box. The properties remain solely so
///          `applyParameters(_:)` can restore older `SavedSearch`/`pendingSearch`
///          snapshots without data loss.
///   1.7 — Session 163: add `selectedSubseriesIds` + `availableVolumes` for the
///          advanced-filter volume/subseries pickers; `effectiveVolumeIds` unions the
///          two selections; `applyParameters`/`reconstructScope` round-trip a flat
///          `volumeIds` scope back into the two pickers.
///   1.8 — Session 2026-07-04 (macOS UI audit C4): `advancedFilterSignature` added —
///          Equatable fingerprint of the applied advanced-filter fields, observed by
///          the macOS Search window's live filter popover to apply edits immediately.
///   Session 09: `selectedSubjectTagIds` live state removed — persisted subject ids
///         no longer echo into `hasActiveFilters`, emitted parameters, or new
///         `SavedSearch` records (the filter is inert).
///   1.9 — Wave R-4 (2026-07-26): `recordSearchHistory(projectId:in:defaults:)` added —
///          the iOS producer for `SearchHistoryEntry`, which until now had exactly one
///          writer and it was `MacSearchViewModel` (`#if os(macOS)`). An iOS-only
///          researcher's Project Home "Searches Run" tile was therefore structurally
///          always 0 and its Recent Searches card permanently empty. Mirrors the macOS
///          writer's semantics exactly, including the `submittedQuery` de-duplication
///          that keeps a filter/scope-only re-run from minting a second row.
///   2.0 — Wave R-2a: the `.searchSubmit` session event and the `appState` back reference it
///          needed are gone. `SearchHistoryEntry` is the only record of a search now, on both
///          platforms; `ResearchTrailMigration` brings the events earlier builds wrote across,
///          de-duplicated against the entries R-4's producer already wrote.
///   2.1 — #1297 round 1: `queryInspectorRefreshKey`, the iOS Query Inspector's refresh key — the whole
///          parameter set, where `SearchView` had keyed the refresh on `keywords` alone.
///   2.2 — #1297 round 2: `queryInspectorRefreshKey` is `QueryInspector.Inputs`, the fields the inspection reads, so a
///          person filter's relabel or anchor capture, or the boolean mode, no longer restarts the refresh and wipes
///          the scoped counts and zero-result blame (A3).
///   2.3 — #1299: `search()` passes a failure through `SearchQueryRefusal.readable(_:for:)`, so a query the parse refuses
///          (`-korea`, groups nested past 32) shows a message pointing at Search Tips, and — since the #1299 follow-up —
///          a query that parses with document text, summaries and research notes all off shows one naming Filters ▸
///          Search Scope. Both showed "The operation couldn’t be completed. (FRUSExplorer.FTS5Error error 5.)";
///          `SearchRefusalMessageTests` measured that on four refused queries and on those three toggles off first.
///   2.4 — #1584, #1597, #1598: `resultSetScope` is composed here, from `lastFetchLimit` and the new
///          `resultsAreSemantic`, both now written with the rows; `switchSearchMode(to:)` clears a search the new
///          engine cannot run and restores it on the way back; `applyHandoff(_:)` runs a hand-off that names a
///          search as a keyword search; the engine is held as `MeaningSearchRunning`
///   2.5 — #1577 lane 2: `executedRoute`, an `ExecutedSearchRoute`, is what is written with the rows, and
///          `resultsAreSemantic` reads it; `offersReadings` is the readings' door, asked of the field's engine and
///          of the rows' route
///   2.6 — FRUS Explorer Light: `sortedResults` is `SearchSortOrder.sorted(_:)`, the kit's date order, which the
///          macOS view model and the web edition sort by too; this file's copy of the comparator is gone
///   2.7 — #1648: `search()` numbers its run (`SearchRunLedger`), asks once after its last wait whether a later search
///          has replaced it, writes nothing if one has, and returns `true` when none has; a switch of engine and
///          `replaceSearchesUnderWay()` replace the runs under way, so a run sent before them cannot land after, and
///          `isSearchingWithNoWords` tells the emptied field a hand-off's own search from one to replace
///   2.8 — #1680: a keyword run's fetch is a task of its own (`keywordFetchUnderWay`), and whatever replaces the
///          run cancels it (`startRun()`, `replaceRunsUnderWay()`), so the kit stops its statements and the search
///          that replaced it no longer waits for them
///   2.9 — #1577 lane 4: Search Within These Results. `holdBase(meaningAvailable:)` holds the list on screen as a
///          `PinnedResultBase`, the field then runs the other engine inside it (`search()`'s layer), and
///          `leaveBase()` puts the list and its figures back with no search. Every hand-off leaves the base; Clear
///          Filters does not. A layer never overwrites the base's trail row, and keeps the checklist's marks
@Observable
@MainActor
final class SearchViewModel {

    // MARK: - Text Search Parameters

    /// Raw text typed into the main search box, in Google-style inline syntax
    /// (`"phrase"`, `term1 OR term2`, `-excluded`, `term*`) — parsed by
    /// `FTS5InlineQueryParser` in `SearchService`.
    var keywords: String = ""

    /// Legacy/backward-compatibility only — **no longer user-editable**.
    ///
    /// Exact phrase — order-sensitive, case-insensitive. Session 2026-06-08 removed
    /// the dedicated "Exact phrase" field from `SearchFilterView`; users now type
    /// `"quoted phrases"` directly into the main search box, where
    /// `FTS5InlineQueryParser` handles them natively. This property is retained only
    /// so `applyParameters(_:)` can faithfully restore older `SavedSearch`/
    /// `pendingSearch` snapshots that still carry a populated `phrase` value.
    var phrase: String = ""

    /// Legacy/backward-compatibility only — **no longer user-editable**.
    ///
    /// Prefix for a wildcard search. `*` is appended automatically. Session
    /// 2026-06-08 removed the dedicated "Prefix wildcard" field from
    /// `SearchFilterView`; users now type `term*` directly into the main search box.
    /// Retained only for `applyParameters(_:)` restoration of older snapshots.
    var prefixWildcard: String = ""

    /// Legacy/backward-compatibility only — **no longer user-editable**.
    ///
    /// How keyword terms are combined. Default `.and`. Session 2026-06-08 removed
    /// the "Keyword mode" (AND/OR) picker from `SearchFilterView`; users now type
    /// `term1 OR term2` directly into the main search box, where mixed AND/OR/NOT
    /// expressions are supported per-query (something this single global mode never
    /// could express). Retained only for `applyParameters(_:)` restoration.
    var booleanMode: FTS5Query.BooleanMode = .and

    /// Legacy/backward-compatibility only — **no longer user-editable**.
    ///
    /// Comma-separated terms that must NOT appear in matching documents. Session
    /// 2026-06-08 removed the "Excluded terms" field from `SearchFilterView`; users
    /// now type `-word` or `NOT word` directly into the main search box. Retained
    /// only for `applyParameters(_:)` restoration of older snapshots.
    var excludedTermsText: String = ""

    // MARK: - Date Range Parameters

    var dateRangeEnabled: Bool = false

    /// The Years facet's applied selection: documents whose **start year** is one of these (#775).
    ///
    /// `nil` = no year-set filter; an empty array matches nothing (see
    /// `SearchParameters.yearKeys`). Separate from `dateRangeEnabled`/`dateRangeStart`/`End`
    /// because a set of years is not an interval — `{1951, 1953}` cannot be written as a range —
    /// and because the two ask different questions: this one is start-year containment, matching
    /// the facet's own bucket rule, while the date range is interval overlap. They AND.
    var facetYearKeys: [String]? = nil
    var dateRangeStart: Date = Calendar.current.date(byAdding: .year, value: -80, to: .now) ?? .distantPast
    var dateRangeEnd: Date = .now

    // MARK: - Tag Filter Parameters

    // (The former `selectedSubjectTagIds` live state was removed in Session 09 with the
    // document-level subject taxonomy: the SQL filter is inert, so echoing persisted
    // subject ids here would only fake an "active filter" and write retired ids into
    // new SavedSearch records. `SearchParameters.subjectTagIds` itself survives for
    // persistence stability and is always emitted empty from live state.)
    var selectedUserTagIds: Set<UUID> = []

    // MARK: - Content Scope Parameters

    /// Whether document body content (header, dateline, source note, body text)
    /// is included in the search scope. Seeded from the Settings "Search Defaults"
    /// pane (`SearchDefaults`); per-session changes here do not write back.
    var includeDocumentText: Bool = SearchDefaults.scopeDocuments
    var includeSummaries: Bool = SearchDefaults.scopeSummaries
    var includeNotes: Bool = SearchDefaults.scopeNotes

    // MARK: - Document Type Filter

    /// Which document types to include in results. Seeded from the Settings
    /// "Search Defaults" pane (`SearchDefaults`).
    var documentTypeFilter: DocumentTypeFilter = SearchDefaults.documentTypeFilter

    // MARK: - Front Matter Scope

    /// Whether front-matter prose sections (preface, introduction, prefatoryNote, terms, etc.)
    /// are included in search results. Default `true`.
    var includeFrontMatter: Bool = true

    // MARK: - Person Reference Filter

    /// `@ref` attribute value from `<persName>` to restrict results to documents
    /// that mention a specific person. Empty string means no filter.
    var personRefText: String = ""

    /// Cross-corpus person rollup id (the People browser's "Find all mentions" handoff). Restricts
    /// results to documents mentioning any member of the clustered identity. `nil` means no filter.
    var personRollupId: Int?

    /// Active subject bucket from the results facet (#308) — a position in
    /// ``SubjectBucketVocabulary``. `nil` means no subject filter.
    var subjectBucket: Int?

    /// The durable `category`/`subcategory` identity of ``subjectBucket``. See
    /// `SearchParameters.subjectBucketKey`.
    var subjectBucketKey: String?

    /// Active SUBJECT filter from the Subject Explorer (#1023) — the durable ref. `nil` means no
    /// subject filter. Finer than ``subjectBucket``: a bucket is a `(category, subcategory)` pair
    /// and a subject is one of the ~4.6 subjects inside it.
    var subjectRef: String?

    /// Display name of ``subjectRef`` — the fallback half of the durable key AND what the filter
    /// chip says. Both uses need it: a ref alone cannot be shown to a reader, and after an upstream
    /// re-mint it is the only thing that still resolves.
    var subjectName: String?

    /// Display name for the active `personRollupId`/`personRef` filter, shown in the filter chip.
    var personLabel: String?

    /// Durable `(volumeId, ref)` identity behind `personRollupId` (#747).
    ///
    /// `personRollupId` is a **slot number**: the rollup table is rebuilt wholesale and renumbered
    /// from 1 on every correction and every corpus change, so a chip that holds only the integer
    /// starts filtering to a different person the moment anyone merges two identities. The anchor
    /// is a TEI key and does not move, so it survives the rebuild and re-resolves to the current
    /// slot. Captured lazily by ``refreshPersonRollupBinding(using:)`` — the sites that *set* a
    /// rollup id do not have it, because rollup-sourced `PersonIndexEntry`s carry an empty `ref`.
    var personAnchor: PersonRollupAnchor?

    /// Set when the last rebind dropped the person filter because its anchor no longer resolves,
    /// so the view can say so instead of silently widening the result set.
    var droppedPersonFilterNotice: String?

    // MARK: - Volume & Subseries Filter

    /// **Individually** selected volume IDs (the Volumes picker), distinct from the
    /// subseries selection below.
    ///
    /// Empty = no individual-volume constraint. Populated by the post-indexing
    /// "Search this volume" handoff (`IndexingSummaryCard.onSearchVolume` →
    /// `AppState.pendingSearch` → `applyParameters(_:)`), by the Volumes picker in
    /// `SearchFilterView`, and by analytics drill-in handoffs. The *effective* scope
    /// forwarded to `SearchService` is `effectiveVolumeIds` (the union with the
    /// subseries selection), which `IndexingPipeline.searchDocuments` applies SQL-side.
    var selectedVolumeIds: [String] = []

    /// Selected subseries identifiers (the Subseries picker), e.g. `"1969-76"`.
    ///
    /// Each selected subseries expands to all of its **indexed** volumes (from
    /// `availableVolumes`) when computing `effectiveVolumeIds`. Kept separate from
    /// `selectedVolumeIds` so the two pickers round-trip independently.
    var selectedSubseriesIds: Set<String> = []

    /// Indexed volumes available to the volume/subseries pickers, loaded via
    /// `loadAvailableVolumes(allEntries:indexedIds:)`. Only indexed volumes appear so
    /// users cannot scope to a volume that can never return results.
    var availableVolumes: [VolumeManifestEntry] = []

    // MARK: - Project Scope (#377 Phase 2)

    /// How the active project constrains this search. `.off` (the default) ignores the
    /// project; `.history` gates results to `projectEngagedDocumentKeys`.
    ///
    /// The filter panel exposes the picker only when `projectEngagedDocumentKeys` is
    /// non-empty (i.e. a project is active and has engaged documents), so this stays
    /// `.off` and inert in Global Context.
    var projectScope: ProjectSearchScope = .off

    /// The active project's engaged `"volumeId/documentId"` keys, loaded by the view
    /// from live project activity (`ProjectEngagedDocuments`). Empty when no project is
    /// active or the project has engaged no documents.
    ///
    /// When `projectScope == .history`, this becomes `SearchParameters.documentIds`: a
    /// non-empty set gates the FTS query to exactly these documents, and an empty set
    /// (History chosen for a project with no history yet) matches nothing.
    var projectEngagedDocumentKeys: [String] = []

    /// The active project's display name, for the scope picker's label. `nil` in Global
    /// Context.
    var projectScopeName: String?

    /// The volumes the active project's focus subjects are characteristic of (#377 Phase 2b),
    /// resolved by the view from `Project.defaultSubjectTagIds` via `VolumeSubjectProfiles`.
    /// When `projectScope == .focus`, this becomes `SearchParameters.volumeIds` — a discovery
    /// scope over the corpus. Empty when the project has no focus subjects (then `.focus` is
    /// not offered).
    var projectFocusVolumeIds: [String] = []

    /// The Focus-mode "only new to this project" toggle (#377 Phase 2b, default off): when on,
    /// `projectEngagedDocumentKeys` becomes `SearchParameters.excludeDocumentIds`, dropping
    /// documents already collected/annotated/visited so discovery emphasizes fresh material.
    var projectOnlyNew: Bool = false

    /// The volumes a project's focus subjects are characteristic of, resolved via the bundled
    /// volume-subject profiles (#377 Phase 2b). Empty when the project has no focus subjects
    /// or the profiles are unavailable. An in-memory lookup — safe to call synchronously.
    /// Shared by the iOS `SearchView` and the macOS `SearchSheet` so Focus resolves the same
    /// way on both.
    static func focusVolumeIds(for project: Project?) -> [String] {
        guard let project, !project.defaultSubjectTagIds.isEmpty,
              let profiles = VolumeSubjectProfilesStore.shared else { return [] }
        return profiles.volumeIds(forSubjectRefs: project.defaultSubjectTagIds).sorted()
    }

    /// Equatable fingerprint of every advanced-filter field that
    /// `MacSearchViewModel.applyAdvancedFilters()` copies back into its parameters.
    ///
    /// Observed by the macOS Search window (`.onChange` inside the live filter
    /// popover, UI audit C4) so edits apply to the result list immediately instead
    /// of batching on dismiss. Reading it inside a view body registers Observation
    /// tracking on all constituent fields. The legacy non-editable fields (`phrase`,
    /// `prefixWildcard`, `booleanMode`, `excludedTermsText`) are excluded — they
    /// cannot change while the popover is open.
    var advancedFilterSignature: String {
        var parts: [String] = []
        parts.append(dateRangeEnabled
            ? "d1|\(dateRangeStart.timeIntervalSinceReferenceDate)|\(dateRangeEnd.timeIntervalSinceReferenceDate)"
            : "d0")
        // #775: the Years facet's set. Without it macOS's `applyAdvancedFilters` never fires on a
        // year selection — the signature is what tells it the filter state changed — so the set
        // would be applied, shown, and silently ignored by the search. Exactly M-1 again.
        parts.append(facetYearKeys.map { $0.sorted().joined(separator: ",") } ?? "y-")
        parts.append(personRefText)
        parts.append(personRollupId.map(String.init) ?? "")
        parts.append(personLabel ?? "")
        parts.append(String(describing: documentTypeFilter))
        parts.append(includeDocumentText ? "1" : "0")
        parts.append(includeSummaries ? "1" : "0")
        parts.append(includeNotes ? "1" : "0")
        // The fourth scope, missing until now: the Mac's live "Include front matter" toggle moved
        // and nothing re-applied. See `AdvancedFilterSignatureTests`, which pins the whole class.
        parts.append(includeFrontMatter ? "1" : "0")
        parts.append(selectedSubseriesIds.sorted().joined(separator: ","))
        // M-1: without this the Mac's `applyAdvancedFilters` never fires on an apply or a clear —
        // the signature is what tells it the filter VM changed — so the corpus was set, shown as
        // applied, and silently ignored by the search. The count is enough to distinguish; the keys
        // themselves can be thousands of strings and this runs on every filter edit.
        parts.append(appliedWorkingCorpusName ?? "")
        parts.append(String(appliedWorkingCorpusKeys?.count ?? -1))
        parts.append(selectedVolumeIds.joined(separator: ","))
        // User-tag filter (188-D): sorted for order-independence so toggling a tag perturbs the
        // signature deterministically, which drives the macOS live-apply observer (#212). iOS
        // does not observe this signature, so its behavior is unchanged.
        parts.append(selectedUserTagIds.map(\.uuidString).sorted().joined(separator: ","))
        // Project scope (#377 Phase 2): a scope change must perturb the signature so the
        // macOS live-apply observer copies the resulting gates into `parameters`. Focus mode's
        // "only new" toggle is part of the scope, so it joins the fingerprint too.
        parts.append("ps|\(projectScope.rawValue)|\(projectOnlyNew ? 1 : 0)")
        return parts.joined(separator: "§")
    }

    // MARK: - Results

    var results: [SearchResult] = [] {
        didSet {
            if currentPage >= totalPages { currentPage = 0 }
            // No rows, no route (#1577 lane 2): an emptied list is a keyword list until rows arrive,
            // whoever emptied it. The view clears the rows itself when the field is emptied.
            if results.isEmpty { executedRoute = .keywords }
            selectionFollowsReplacedResults()
        }
    }
    /// Every document matching the query, uncapped — or `nil` when the count could not be taken.
    ///
    /// ## Why this now exists, having been argued against
    /// The doc comment on `recordSearchHistory` recorded the decision not to have one: "adding
    /// [a count] would put a second FTS5 `COUNT(*)` on every iPhone search to improve a number
    /// nothing yet displays". Both halves have changed. ``ResultSetScope`` displays it — in the
    /// capture warning, in the corpus's own stored provenance, and in the results header — and the
    /// cost turns out not to be a second query's worth of work.
    ///
    /// Measured against the real 6.3 GB store, a filtered count over a date range, as the marginal
    /// cost of running it directly after the search that shares its joins:
    ///
    ///     term            filtered match   search    count     marginal
    ///     petroleum            1,506       0.099 s   0.021 s      21%
    ///     negotiations        35,275       0.974 s   0.104 s      11%
    ///     ambassador          53,388       1.189 s   0.156 s      13%
    ///
    /// Taken cold and alone the same count is 10.96 s — but that is the first touch of the join
    /// pages, and `searchDocuments` pays it already: it emits the identical CTE, joins and WHERE,
    /// differing only by `ORDER BY m.score LIMIT n`, and ordering on a computed score means the
    /// join is evaluated for **every** matched row however small the limit. The expensive part is
    /// not added by counting; it is already the search's.
    ///
    /// `nil` rather than a fallback when the count fails: a wrong total is worse than none here,
    /// since it becomes the denominator stored on a working corpus.
    var totalMatchCount: Int?

    /// The FTS5 expression the last completed search executed, captured during `search()`.
    ///
    /// Recorded there rather than re-derived in `recordSearchHistory` for two reasons: the
    /// renderer lives on the `SearchService` actor and cannot be reached from the synchronous
    /// recorder, and a later re-derivation would describe whatever the parameters are THEN. An
    /// appendix entry has to carry the expression that produced its count.
    var lastRenderedExpression: String?

    var isSearching: Bool = false
    var searchError: String? = nil {
        // #1576 lane 3: an error takes the rows off the screen, and some refusals leave `results`
        // as it was. A selection of rows that are not drawn is one a command must not act on.
        didSet { if searchError != nil { endSelecting() } }
    }
    var hasSearched: Bool = false

    /// The searches this screen has sent, numbered, so that a run a later one replaced writes
    /// nothing when it comes back (#1648). See ``SearchRunLedger``.
    @ObservationIgnored private var searchRuns = SearchRunLedger()

    /// The keyword fetch of the run under way, its rows and its total, held so that whatever replaces
    /// the run can cancel it and the kit stops its statements (#1680). `nil` while no keyword run is
    /// under way. A Meaning run has none: its engine does not stop when cancelled.
    @ObservationIgnored private var keywordFetchUnderWay: Task<KeywordFetch, any Error>?

    /// What a keyword run's fetch brings back: its rows, its total, and how long each took.
    struct KeywordFetch: Sendable {
        /// The rows, at most the run's fetch limit.
        let rows: [SearchResult]
        /// The whole-query count, or `nil` when it could not be taken.
        let total: Int?
        /// The time from sending the search to the rows' return.
        let rowsTime: Duration
        /// The time from sending the search to the total's return.
        let totalTime: Duration
    }

    /// Increments once per executed search — a stable `.task(id:)` key for views that
    /// must recompute when a search *runs*, not when its text changes.
    var executedSearchVersion: Int = 0

    /// Which set the Filters ▸ My Tags counts describe, frozen when a search COMPLETES (#1310).
    ///
    /// Set beside every `executedSearchVersion` bump and cleared wherever results are cleared,
    /// rather than derived when the panel opens. `lastRunWasSemantic` and `hasSearched` are both
    /// written BEFORE the await, so a panel opened mid-search would combine the new run's route
    /// with the old run's results and count a set that was never on screen.
    var userTagCountScope: UserTagCountScope?

    // MARK: - Sorting (#305)

    /// Result ordering. `relevance` = FTS5 BM25 (as returned); the date orders use `dateISO`.
    /// Changing it resets to the first page so the user sees the top of the re-sorted list.
    var sortOrder: SearchSortOrder = .relevance {
        didSet { if sortOrder != oldValue { currentPage = 0 } }
    }

    /// `results` ordered by `sortOrder`. Date sorting uses the structured `dateISO` value
    /// (`yyyy-MM-dd`); undated rows go last in both directions and ISO-date ties break by BM25
    /// (more relevant first). The order `MacSearchViewModel.allSortedResults` and the web edition
    /// return too: `SearchSortOrder.sorted(_:)`.
    var sortedResults: [SearchResult] {
        sortOrder.sorted(results)
    }

    // MARK: - Checklist Mode (#189-D)

    /// True when checklist mode is active. Session-scoped; not persisted (resets on relaunch).
    /// While on, results the user has reviewed this session are hidden.
    var checklistMode: Bool = false {
        didSet { clampCurrentPage(); pruneSelection() }
    }

    /// The instant checklist mode was last enabled. Documents opened at or after this instant
    /// (per `ReadingHistoryEntry.accessedAt`) are hidden. `nil` while mode is off.
    var checklistEnabledAt: Date?

    /// `(volumeId|documentId)` keys the user opened since `checklistEnabledAt`, fetched from
    /// `ReadingHistoryEntry` by `SearchView` and pushed in (mirrors `availableUserTags`).
    var readSinceEnabledKeys: Set<String> = [] {
        didSet { clampCurrentPage(); pruneSelection() }
    }

    /// The results the reader marked reviewed this session, by hand or with Mark Page Reviewed,
    /// and the last bulk mark apart so that it can be undone (#1576 lane 1). A lightweight
    /// in-memory value, NOT a fabricated `ReadingHistoryEntry`.
    private(set) var reviewedMarks = ReviewedMarks() {
        didSet { clampCurrentPage(); pruneSelection() }
    }

    /// `(volumeId|documentId)` keys the reader marked reviewed this session: ``reviewedMarks``' keys.
    /// A read, since #1576: the marks are written through ``markReviewed(volumeId:documentId:)``,
    /// ``markReviewed(_:)`` and ``undoLastBulkMark()``.
    var markedReviewedKeys: Set<String> { reviewedMarks.keys }

    /// The search the checklist's marks belong to, or `nil` while the mode is off (#1576 lane 1).
    ///
    /// A completed search keeps the marks when it is the same search (``ChecklistAnchor``) and
    /// clears them, re-anchoring, when it is another. Until #1576 every completed search cleared
    /// them here, so one tap on a tag chip, which re-runs the search on screen, undid every mark;
    /// the Mac kept them across a re-run of the same query, and this is now the Mac's rule, with
    /// both platforms telling one wordless browse from another.
    private(set) var checklistAnchor: ChecklistAnchor?

    /// A stable reviewed-set key for a `(volume, document)` pair.
    nonisolated static func reviewedKey(volumeId: String, documentId: String) -> String {
        "\(volumeId)|\(documentId)"
    }

    /// The reviewed set while checklist mode is on: docs opened since enable ∪ docs marked.
    var hiddenReviewedKeys: Set<String> {
        checklistMode ? readSinceEnabledKeys.union(markedReviewedKeys) : []
    }

    /// `sortedResults` minus reviewed docs when checklist mode is on. All display-time page math
    /// pages over this array, so the slice, count, and page index stay in sync.
    var displayedResults: [SearchResult] {
        let hidden = hiddenReviewedKeys
        guard !hidden.isEmpty else { return sortedResults }
        return sortedResults.filter { !hidden.contains(Self.reviewedKey(volumeId: $0.volumeId, documentId: $0.documentId)) }
    }

    /// Enables/disables checklist mode. Enabling stamps the anchor time, anchors the checklist to
    /// the search on screen and clears prior marks; disabling clears all reviewed state so the full
    /// list returns.
    func setChecklistMode(_ on: Bool) {
        checklistMode = on
        if on {
            checklistEnabledAt = .now
            // The search whose rows are on screen, not the Filters fields as they stand now: a
            // filter edited and not yet run is no part of the list the marks will be made in.
            checklistAnchor = lastCompletedSearchAnchor
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

    /// Forgets every mark, and with them a line in the selection's bar that offers to undo one
    /// (#1576 lane 4): after this there is nothing for that Undo to bring back. The one place the
    /// marks are reset, so that no reset leaves the line behind. Here the selection bar takes the
    /// Checklist toggle's place, so no control turns the mode off while a line stands; the Mac's
    /// window has one that does. `MacSearchViewModel`'s is this function's twin.
    private func forgetReviewedMarks() {
        reviewedMarks.reset()
        selectionSession.withdrawOutcomeOfferingToUndoMarks()
    }

    /// Marks a document reviewed for this checklist session (hides it without opening it).
    func markReviewed(volumeId: String, documentId: String) {
        reviewedMarks.mark(Self.reviewedKey(volumeId: volumeId, documentId: documentId))
    }

    /// Marks several results reviewed at one stroke — Mark Page Reviewed hands this the page — and
    /// remembers the ones it newly hid, so that ``undoLastBulkMark()`` can bring them back
    /// (#1576 lane 1).
    ///
    /// The page index is left where it is: with a page hidden, the rows that follow move up into
    /// it, which is what a reader working down a list wants next.
    ///
    /// - Parameter results: The results to mark, in any order.
    /// - Returns: How many rows left the list: the results newly marked, less any a document
    ///   opened since the mode came on was hiding already.
    @discardableResult
    func markReviewed(_ results: [SearchResult]) -> Int {
        markBulk(results, returnsListToTop: true)
    }

    /// The bulk mark itself.
    ///
    /// - Parameters:
    ///   - results: The results to mark.
    ///   - returnsListToTop: Whether the marked rows were the page, so that the rows that move
    ///     up should be shown from their top. A selection's rows are scattered down the list and
    ///     the reader is among them: marking those must leave the list where it is.
    /// - Returns: How many rows left the list.
    private func markBulk(_ results: [SearchResult], returnsListToTop: Bool) -> Int {
        let hidden = reviewedMarks.markBulk(results.map {
            Self.reviewedKey(volumeId: $0.volumeId, documentId: $0.documentId)
        }).subtracting(readSinceEnabledKeys).count
        if hidden > 0, returnsListToTop { bulkMarkGeneration &+= 1 }
        // A new bulk mark is what Undo takes back now, so a line offering to undo an earlier
        // one would name the wrong rows (#1576 lane 3).
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
    /// is among the loaded results and hidden by nothing else. After a re-run that loaded none of
    /// the marked page there is nothing here to bring back, and the control is dimmed.
    var canUndoBulkMark: Bool { undoableRowCount > 0 }

    /// Takes back the last bulk mark, and only that: marks made a row at a time stay.
    ///
    /// - Returns: How many rows came back to the list, which is not always the size of the mark:
    ///   see ``ReviewedMarks/undoableCount(among:otherwiseHidden:)``.
    @discardableResult
    func undoLastBulkMark() -> Int {
        let restored = undoableRowCount
        reviewedMarks.undoLastBulk()
        if restored > 0 { bulkMarkGeneration &+= 1 }
        selectionSession.withdrawOutcomeOfferingToUndoMarks()
        return restored
    }

    /// Counts the bulk marks and undos that changed the list. The result list is identified by
    /// it with the page index, so that after Mark Page Reviewed the list stands at the top of the
    /// rows that moved up, as it does after a page turn, and not at the offset the reader had
    /// scrolled the marked page to. A mark made on one row does not move it: the reader is in
    /// mid-list.
    private(set) var bulkMarkGeneration = 0

    /// Settles the checklist against a search that has just completed (#1576 lane 1).
    ///
    /// The same search keeps its marks, the documents opened since the mode came on, and its
    /// anchor time. Another search starts the checklist again: reviewed identity is document
    /// identity, which recurs across searches, so a mark kept past its search would hide a result
    /// the reader has not reviewed under this one.
    ///
    /// - Parameter anchor: The anchor of the search that ran.
    private func settleChecklist(for anchor: ChecklistAnchor) {
        lastCompletedSearchAnchor = anchor
        guard checklistMode, checklistAnchor?.isSameSearch(as: anchor) != true else { return }
        checklistAnchor = anchor
        checklistEnabledAt = .now
        readSinceEnabledKeys.removeAll()
        forgetReviewedMarks()
    }

    /// The search that last completed, which is the one any rows on screen came from; `nil`
    /// before the first. Recorded whether or not Checklist Mode is on, so that turning the mode on
    /// anchors it to those rows' search. `submittedSearchParameters` cannot serve: it freezes the
    /// words alone, and the Filters fields under it can be edited without a run.
    private var lastCompletedSearchAnchor: ChecklistAnchor?

    /// Resets `currentPage` to 0 when a reviewed-set change shrank the list below the current page.
    private func clampCurrentPage() {
        if currentPage >= totalPages { currentPage = 0 }
    }

    // MARK: - Selection (#1576 lane 3)

    /// The selection and what follows it: the picks, the search they were made in, and what the
    /// last command did. The rules are ``ResultSelectionSession``'s, which the Mac's view model
    /// holds too (#1576 lane 4); this view model tells it what only it knows. Written only
    /// through the functions below; pruned whenever the shown results change, and ended when an
    /// error takes the rows off the screen, so that no pick is ever of a row the list does not
    /// show.
    private var selectionSession = ResultSelectionSession()

    /// The results the reader has picked to act on at once, and whether the list is in selection.
    var resultSelection: ResultSelection { selectionSession.selection }

    /// What the last command on the selection did, shown above the results until the next
    /// command, the next completed search or Done.
    var bulkOutcome: BulkOutcome? { selectionSession.outcome }

    /// Counts the outcomes set, so that the bar can announce each one.
    var bulkOutcomeSerial: Int { selectionSession.outcomeSerial }

    /// The picked results, in the order the list shows them: what a command acts on.
    var selectedResults: [SearchResult] { resultSelection.resolved(in: displayedResults) }

    /// Whether more results are picked than one Add to Collection takes (the owner's decision 5).
    /// Mark Reviewed has no limit.
    var selectionExceedsAddLimit: Bool { selectionSession.exceedsAddLimit }

    /// Whether Add to Collection can run: something is picked, and no more than one add takes.
    var canAddSelectionToCollection: Bool { selectionSession.canAdd }

    /// Enters selection, with one row picked when the reader chose Select on it.
    ///
    /// - Parameter result: The row whose menu was used, or `nil` from the More menu.
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

    /// Mark Reviewed for the selection: hides the picked rows, which takes them out of the
    /// selection, and keeps the line and its Undo.
    func markSelectionReviewed() {
        // The picked rows are scattered and the reader is among them, so the list stays put.
        // Marked first and recorded after: marking prunes the session, and the two writes to it
        // must not overlap.
        let hidden = markBulk(selectedResults, returnsListToTop: false)
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

    /// Settles the selection against a search that has just completed. The same search keeps the
    /// picks it still shows and says how many it does not; another search ends selection.
    ///
    /// - Parameter anchor: The anchor of the search that ran.
    private func settleSelection(for anchor: ChecklistAnchor) {
        selectionSession.settle(for: anchor)
    }

    // MARK: - Available Filter Options

    /// The user's tags, used to render the filter panel's tag chips and to resolve
    /// tag UUIDs to names in result rows. Fed by `SearchView` from a live SwiftData
    /// `@Query`, so newly-created tags appear without an app restart.
    var availableUserTags: [UserTag] = []

    // MARK: - UI State

    /// Controls presentation of the `SearchFilterView` sheet.
    /// Set to `true` by the filter toolbar button; `false` when the sheet is dismissed.
    var showFilterPanel: Bool = false
    var navigationPath: [DocumentBrowserEntry] = []

    // MARK: - Pagination

    /// Maximum results fetched by `search()` for a query with text in it.
    ///
    /// iOS pages through results (`pageSize` per page) rather than rendering them in one
    /// continuous list, so the full set is materialised in memory but only a single page
    /// of rows is ever rendered. Raised from 500 → 1 000 once pagination bounded the
    /// render cost. The macOS search window uses a separate hard limit of 7 500.
    ///
    /// The binding cost is not the rows, it is `body_text`: a keyword query needs it to build each
    /// row's context snippet, and it measures a 7,416-character mean over the corpus — ~7.7 MB per
    /// thousand rows, off SQLite overflow pages. That is what this ceiling bounds.
    static let searchHardLimit: Int = 1_000

    /// Maximum results fetched for a **filter-only browse** — a subject or person constraint with
    /// no keyword, phrase, or prefix.
    ///
    /// Higher than `searchHardLimit` because the row is a different size. A browse has no query
    /// terms, so `SearchService` cannot build a context snippet and the fetch does not select
    /// `body_text` at all; measured, a 1,000-row browse window carried 7,694,772 bytes of body
    /// before that change and **0 after**, at half the wall time. What remains is header, dateline,
    /// source note and tag ids — a few hundred bytes a row, so 7,500 costs less than the old 1,000.
    ///
    /// 7,500 is chosen against the data rather than by symmetry with macOS: measured over the
    /// shipped subject index, a 1,000-row ceiling returns every document for 69% of subjects and
    /// 7,500 does so for **95%**. The remaining 5% are the corpus-wide subjects (*War* reaches
    /// 58,480 documents) where no ceiling a phone should hold would help, and where the
    /// "loaded · total" header is the honest answer.
    static let filterOnlyHardLimit: Int = 7_500

    /// The ceiling the CURRENT results were actually fetched at.
    ///
    /// **Recorded with the rows it fetched, not recomputed from `searchParameters`.** Those are the live
    /// filter state and may have moved since the search ran — the same reason `resultsSnapshot`
    /// passes `submittedSearchParameters` rather than the live value. Deriving the cap from them
    /// would make `isResultsCapped` and the facet total answer for a query the user is still
    /// typing, and both of those decide whether the app claims a count is complete.
    private(set) var lastFetchLimit: Int = searchHardLimit

    /// Number of results rendered per page on iOS.
    static let pageSize: Int = 25

    /// Zero-based index of the currently displayed results page.
    var currentPage: Int = 0

    /// Total number of result pages for the currently-displayed (checklist-filtered) set (≥ 1).
    var totalPages: Int {
        max(1, Int(ceil(Double(displayedResults.count) / Double(Self.pageSize))))
    }

    /// The slice of `displayedResults` shown on the current page. Only these rows are rendered,
    /// keeping the list bounded regardless of how many results were fetched. The page index is
    /// clamped here (side-effect-free) so a reviewed-set change that shrinks the list can never
    /// leave `pagedResults` returning a blank page for a now-out-of-range `currentPage`.
    var pagedResults: [SearchResult] {
        let base = displayedResults
        let page = min(max(0, currentPage), totalPages - 1)
        let start = page * Self.pageSize
        guard start < base.count else { return [] }
        return Array(base[start..<min(start + Self.pageSize, base.count)])
    }

    // MARK: - Dependencies

    private let searchService: SearchService

    // Wave R-2a: the `weak var appState` injected here since Session 100 existed solely so
    // `search()` could fire `AppState.logEvent(.searchSubmit(…))`. That writer is retired, and
    // `SearchView` passes the active project id to `recordSearchHistory` directly, so the back
    // reference is gone rather than left as an unread property.

    // MARK: - Initialisation

    init(searchService: SearchService) {
        self.searchService = searchService
    }

    // MARK: - Setup

    /// Populates `availableVolumes` with the indexed subset of `allEntries`, sorted by
    /// volume ID, for the volume/subseries pickers in `SearchFilterView`.
    ///
    /// - Parameters:
    ///   - allEntries: Every known volume (typically `manifestStore.diffResult?.known
    ///     ?? manifestStore.bundledEntries`).
    ///   - indexedIds: The set of volume IDs that have been indexed
    ///     (`AppState.indexedVolumeIds`).
    func loadAvailableVolumes(allEntries: [VolumeManifestEntry], indexedIds: Set<String>) {
        availableVolumes = allEntries
            .filter { indexedIds.contains($0.volumeId) }
            .sorted { $0.volumeId < $1.volumeId }
    }

    func applyProjectDefaults(_ project: Project?) {
        guard let project else { return }
        if let start = project.defaultDateRangeStart,
           let end = project.defaultDateRangeEnd {
            dateRangeEnabled = true
            dateRangeStart = start
            dateRangeEnd = end
        }
        // Project.defaultSubjectTagIds is deliberately NOT applied: subject-tag
        // filtering is inert since Session 09 (see SearchParameters.subjectTagIds).
    }

    // MARK: - Search

    /// The keyword text of the search most recently *executed*, trimmed.
    ///
    // MARK: - Meaning mode (V-5 hybrid page)

    /// Which engine a submitted search runs through. Per-session, defaulting to Keywords —
    /// see `SearchMode`'s reasoning for why this is deliberately not persisted.
    var searchMode: SearchMode = .keywords {
        // #1576 lane 3: picks made in one engine's list end with it, whoever changes the engine
        // (the picker, a hand-off, a restored search).
        didSet { if searchMode != oldValue { endSelecting() } }
    }

    /// The Meaning mode's engine, injected by the view once the semantic stack has booted.
    /// `nil` means the mode is unavailable (a build state) and the picker should not offer it.
    /// Held as ``MeaningSearchRunning`` so a test can drive a Meaning run with a list of its own.
    var semanticBackend: (any MeaningSearchRunning)?

    /// Hits beyond the indexed library from the last Meaning search — rendered under the
    /// results list by the #262 rule, never mixed into `results` (they have no metadata rows).
    var beyondLibraryHits: [SemanticSearchBackend.BeyondLibraryHit] = []

    /// The Meaning mode's disclosure counts, or `nil` outside the mode.
    var semanticDisclosure: SemanticSearchBackend.Disclosure?

    /// Set when a Meaning search found no model on device — the view's cue to show the
    /// download offer instead of an error.
    var semanticNeedsModel = false

    /// Whether the last completed run was a Meaning run — frozen with the results so the
    /// history record describes the search that ran, not the mode the picker shows now.
    private(set) var lastRunWasSemantic = false

    /// The route that produced the rows in `results` (#1597, #1598; a route and not a flag since
    /// #1577 lane 2).
    ///
    /// Written in the statements that assign `results`, so it describes the rows on screen.
    /// `lastRunWasSemantic` is written before the await, for the history record, and `searchMode` is the
    /// picker: during a run, and after a mode switch that had nothing to run, each can name an engine
    /// the rows did not come from. ``resultSetScope`` reads this one, and so does whatever else
    /// describes the rows: the facet panel's counts and ``offersReadings``.
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
    /// match, the whole match (``totalMatchCountForFacets``). The route is the rows' and not the
    /// picker's, so between a switch of the picker and the new rows the panel goes on describing the
    /// rows that are on screen.
    var facetMatchCount: Int? {
        guard hasSearched else { return nil }
        return executedRoute.facetsDescribeTheList ? results.count : totalMatchCountForFacets
    }

    /// The documents the facet panel counts over (#1577 lane 2), or `nil` for a keyword match, which
    /// the panel aggregates in the index. The route is the rows', as for ``facetMatchCount``.
    var facetDocumentKeys: [(volumeId: String, documentId: String)]? {
        executedRoute.facetsDescribeTheList
            ? results.map { (volumeId: $0.volumeId, documentId: $0.documentId) }
            : nil
    }

    /// The parameters the facet panel aggregates a keyword match under: the live ones, except while a
    /// held list's own rows are on screen (#1577 lane 4), whose match is the one they were found by.
    /// The live ones then hold the emptied field and the list as the document gate, which aggregated a
    /// keyword list as an empty query and a browse as its loaded rows alone (the review's finding).
    var facetParameters: SearchParameters {
        if isShowingBase, case .match(let ran)? = pinnedBase?.userTagCountScope { return ran }
        return searchParameters
    }

    /// Whether a mode switch cleared a search's rows because the new engine had nothing to run, so that
    /// the switch back runs it again (#1597). See ``switchSearchMode(to:)``.
    private var searchSetAsideByModeSwitch = false

    // MARK: - Search within these results (#1577 lane 4)

    /// The list a layer runs inside, or `nil` while none is held. See ``PinnedResultBase``.
    ///
    /// Held in memory for the session and never saved (the owner's decision 4): Save this search is
    /// off while one is held, and Save as Working Corpus is the durable form. It is a scope and not a
    /// filter, so ``hasActiveFilters`` does not count it and the filter glyph does not light for it
    /// (rule 3); it joins the document gate in ``searchParameters`` only.
    private(set) var pinnedBase: PinnedResultBase?

    /// Whether the rows on screen are the held list's own: from the moment it is held, after the
    /// field is emptied during a layer, until a layer completes, its failure included.
    ///
    /// Read from the search version rather than kept as a flag, since every completed run bumps the
    /// version, a failure and a refusal of the model included, and a flag left behind by any one of
    /// them would leave the field's handler showing an emptied list for the base.
    var isShowingBase: Bool { pinnedBase != nil && baseRowsVersion == executedSearchVersion }

    /// The search version at which the held base's own rows were last put on screen, or `nil`.
    private var baseRowsVersion: Int?

    /// Whether the filters the last layer ran under were other than its list's (`ResultSetScope.layerFiltersNarrowed`),
    /// recorded with the layer's rows.
    private var lastLayerFiltersNarrowed = false

    /// The sort the reader had chosen when a ranking was started, which the list gets back on leaving
    /// the base: a ranking is read closest first, and its own control turns the sort to relevance.
    private var sortOrderBeforeBase: SearchSortOrder?

    /// Set when leaving a browse's base empties the field, which the field's handler would otherwise
    /// take for the reader clearing it and empty the list just put back (``fieldEmptiedInsideBase()``).
    @ObservationIgnored private var fieldEmptiedByLeaving = false

    /// The scope signature of the filters the rows on screen ran under, written with them by the two
    /// runs a base can be held from: what a held list's ``PinnedResultBase/filterSignature`` is, so
    /// that a filter set in the sheet and never run is not taken for the list's own.
    @ObservationIgnored private var filterSignatureOfTheRows: String?

    /// The way a layer over the rows on screen would run, or `nil` when none can start now: no rows
    /// shown, a search under way or failed, a base already held (no deeper stacks), rows that are a
    /// layer's own, or a ranking asked for with no Meaning engine.
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
    /// engine (#1577 lane 4).
    ///
    /// The rows stay on screen. The field empties, and its prompt asks for words or a question; the
    /// row that names the base takes the Keywords | Meaning control's place. Nothing is searched until
    /// the reader types.
    ///
    /// The trail's anchor is set aside with the base, so that no layer refreshes the base's row
    /// (rule 5). The checklist is left as it is: its marks belong to the base's search, and they last
    /// through every layer and the return (``search()`` does not settle the checklist inside a base).
    ///
    /// - Parameter meaningAvailable: Whether the Meaning engine has booted, which a ranking needs.
    /// - Returns: The held base, or `nil` when no layer can start (``layerDirection(meaningAvailable:)``).
    @discardableResult
    func holdBase(meaningAvailable: Bool) -> PinnedResultBase? {
        guard let direction = layerDirection(meaningAvailable: meaningAvailable) else { return nil }
        let hidden = hiddenReviewedKeys
        let members = hidden.isEmpty ? results : results.filter {
            !hidden.contains(Self.reviewedKey(volumeId: $0.volumeId, documentId: $0.documentId))
        }
        let kind: PinnedResultBase.Kind
        // A list restored with a phrase or a prefix and no typed words (an older saved search's) is a
        // keyword list all the same, named by those words.
        var describedQuery: String?
        switch executedRoute {
        case .meaning: kind = .meaning
        default:
            if submittedQuery.isEmpty, case .match(let ran)? = userTagCountScope,
               let words = PinnedResultBase.describedWords(phrase: ran.phrase, prefix: ran.prefixWildcard) {
                kind = .keywords
                describedQuery = words
            } else {
                kind = submittedQuery.isEmpty ? .browse(name: browseName) : .keywords
            }
        }
        let base = PinnedResultBase(
            direction: direction,
            kind: kind,
            query: submittedQuery,
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
            filterSignature: filterSignatureOfTheRows
                ?? SearchScopeSignature.signature(for: parameters(insideBase: nil)),
            describedQuery: describedQuery)
        replaceRunsUnderWay()
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
        // The field turns to the other engine and empties. The field's handler finds the base on
        // screen and leaves it there.
        searchMode = direction.fieldEngine
        keywords = ""
        return base
    }

    /// What a browse with no words is of, for the row that names it as a held base: the person, the
    /// topic or the subject area its filter names, in that order, or `nil` when none has a name.
    var browseName: String? {
        if personRollupId != nil || !personRefText.trimmingCharacters(in: .whitespaces).isEmpty,
           let personLabel, !personLabel.isEmpty {
            return personLabel
        }
        if subjectRef != nil, let subjectName, !subjectName.isEmpty { return subjectName }
        if let bucket = subjectBucketKey
            .flatMap({ DocumentSubjectStore.shared?.bucketVocabulary.id(forKey: $0) }) ?? subjectBucket {
            return DocumentSubjectStore.shared?.bucketVocabulary.label(at: bucket)
        }
        return nil
    }

    /// Leaves the held base: its rows and every figure come back from memory with no search, the field
    /// holds the base's words again and the Keywords | Meaning control its engine (#1577 lane 4).
    ///
    /// The version is bumped, because facets, the concordance and the tag counts are keyed on it:
    /// rows put back without it would sit under the layer's figures. The base's trail anchor comes
    /// back, so a re-run of its words refreshes its own row as before it was held.
    func leaveBase() {
        foldShownTagsIntoBase()
        guard let base = pinnedBase else { return }
        dropBase()
        restoreRows(of: base)
        searchMode = base.direction.baseEngine
        if !keywords.isEmpty, base.query.isEmpty { fieldEmptiedByLeaving = true }
        keywords = base.query
        if let sort = sortOrderBeforeBase { sortOrder = sort }
        sortOrderBeforeBase = nil
    }

    /// Leaves a held base for a hand-off or a recalled search (rule 3) as ✕ does, the list, its
    /// figures and the reader's sort coming back, so that a hand-off that runs nothing (Search this
    /// volume) leaves the screen as it was before the list was held. One that runs a search replaces the
    /// rows itself. The field and the engine are the caller's.
    private func leaveBaseForHandoff() {
        foldShownTagsIntoBase()
        guard let base = pinnedBase else { return }
        dropBase()
        restoreRows(of: base)
        if let sort = sortOrderBeforeBase { sortOrder = sort }
        sortOrderBeforeBase = nil
    }

    /// Carries the tags the rows on screen were given since the list was held into the held list
    /// (`PinnedResultBase.takeUserTags(from:)`), before those rows are replaced: by a layer, by the
    /// list's own rows, or on leaving. `refreshUserTags(_:)` writes the rows on screen alone.
    private func foldShownTagsIntoBase() {
        guard var base = pinnedBase else { return }
        base.takeUserTags(from: results)
        pinnedBase = base
    }

    /// Leaves a held Meaning list and runs the layer's words across the whole library: the command
    /// a layer that found nothing offers ("Search the Whole Library for These Words"). The field and
    /// the engine stay as they are; the caller runs the search.
    func leaveBaseKeepingTheWords() {
        guard pinnedBase != nil else { return }
        dropBase()
        sortOrderBeforeBase = nil
    }

    /// Lets go of the held base without putting its rows back, which its callers do or not: leaving,
    /// a hand-off, and the words searched across the whole library, which run a search of their own
    /// (rule 3). The base's trail anchor comes back, as on leaving it.
    private func dropBase() {
        guard let base = pinnedBase else { return }
        replaceRunsUnderWay()
        isSearching = false
        pinnedBase = nil
        baseRowsVersion = nil
        lastLayerFiltersNarrowed = false
        historyAnchor = base.historyAnchor
    }

    /// Puts a base's rows and figures back, and counts a completed list, with no search.
    private func restoreRows(of base: PinnedResultBase) {
        results = base.rows
        executedRoute = base.route
        // The rows' own words, which a Save as Working Corpus records (the review's finding: a layer's
        // stayed after its rows had gone), and the filters they ran under.
        submittedQuery = base.query
        filterSignatureOfTheRows = base.filterSignature
        totalMatchCount = base.totalMatchCount
        lastFetchLimit = base.fetchLimit
        lastRenderedExpression = base.renderedExpression
        semanticDisclosure = base.disclosure
        beyondLibraryHits = base.beyondLibraryHits
        semanticNeedsModel = false
        userTagCountScope = base.userTagCountScope
        lastCompletedSearchAnchor = base.completedSearchAnchor
        hasSearched = true
        searchError = nil
        currentPage = 0
        executedSearchVersion &+= 1
    }

    /// Shows the held base's own rows again while it stays held: a layer's words or question erased.
    private func showBaseRows() {
        foldShownTagsIntoBase()
        guard let base = pinnedBase else { return }
        replaceRunsUnderWay()
        isSearching = false
        endSelecting()
        restoreRows(of: base)
        baseRowsVersion = executedSearchVersion
        lastLayerFiltersNarrowed = false
    }

    /// What an emptied field means while a base is held, asked by `SearchView`'s handler on the field
    /// before it clears anything (#1577 lane 4).
    ///
    /// With a base held, emptying the field shows the base's rows again, and the base stays: the
    /// reader has erased a layer's words, not left the list (the assessment's first state trap). And
    /// leaving a browse's base empties the field itself, which is not the reader clearing it.
    ///
    /// - Returns: `true` when this has dealt with the emptied field, so that the handler clears nothing.
    func fieldEmptiedInsideBase() -> Bool {
        if fieldEmptiedByLeaving {
            fieldEmptiedByLeaving = false
            return true
        }
        guard pinnedBase != nil else { return false }
        // A layer's rows, a run under way, or a refusal drawn in the rows' place.
        if isSearching || !isShowingBase || searchError != nil { showBaseRows() }
        return true
    }

    /// Where a ranking's unranked rows begin in the list as shown, and how many it shows (#1577 lane 4): the line
    /// that counts them goes above the first. `nil` outside a ranking of a held list, with every row ranked, and under
    /// a date order, where the unranked rows are no longer together at the end.
    var unrankedTail: (firstId: String, count: Int)? {
        guard case .rankedByMeaning = executedRoute, sortOrder == .relevance else { return nil }
        let unranked = displayedResults.filter { $0.semanticScore == nil }
        guard let first = unranked.first else { return nil }
        return (first.id, unranked.count)
    }

    /// The parameters with the held base joined to the document gate, or without it.
    ///
    /// - Parameter base: The held base, or `nil` for the parameters outside any base.
    private func parameters(insideBase base: PinnedResultBase?) -> SearchParameters {
        var params = parametersOutsideBase
        params.documentIds = DocumentScopeGate.combine(corpus: params.documentIds, projectGate: nil,
                                                       pin: base?.memberKeys)
        return params
    }

    /// Frozen at the top of `search()` rather than read from `keywords` at recording time:
    /// `keywords` is bound live to the `.searchable` field, so a user who keeps typing while
    /// the FTS5 query is in flight would otherwise have the *later* text recorded against the
    /// *earlier* search. Named for its macOS counterpart, `MacSearchViewModel.submittedQuery`.
    private var submittedQuery: String = ""

    /// Runs the search the field and the filters describe, through the engine the picker names.
    ///
    /// The run is numbered as it starts, which replaces every run still under way (#1648): a run that
    /// a later search or a cleared list has replaced by the time it comes back writes nothing. See
    /// ``SearchRunLedger``.
    ///
    /// - Returns: `true` when this run was not replaced, so that what it wrote, rows or a refusal, is
    ///   what the screen shows. `SearchView.runSearch()` records the search only then.
    @discardableResult
    func search() async -> Bool {
        let run = startRun()
        // #1577 lane 4: tags given to the rows on screen go with the held list before a layer replaces
        // them, so that a ranking of it, built from its members, carries them.
        foldShownTagsIntoBase()
        // Inside a held base an empty field searches nothing. The base's own rows are shown, and the
        // filters wait for the words or the question they will narrow. Nothing new is on screen, so
        // nothing is recorded.
        if pinnedBase != nil, keywords.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            showBaseRows()
            return false
        }
        if searchMode == .meaning {
            return await searchMeaning(run: run)
        }
        lastRunWasSemantic = false
        let params = searchParameters
        // Inside a held Meaning list this run is the words found in it (#1577 lane 4): its rows are put
        // in the list's order, with the list's scores. Read before the await, with the run.
        let base = pinnedBase
        // A filter narrows the words only where one is set and it is not one the list ran under: a
        // filter taken away since the list was held removes none of its rows (the review's finding).
        let filtersNarrowed = base.map {
            hasActiveFilters && SearchScopeSignature.signature(for: parametersOutsideBase) != $0.filterSignature
        } ?? false
        // A person or subject filter is a valid standalone constraint — `SearchService`
        // applies it SQL-side, so "Find all mentions" handoffs (which carry only
        // a `personRef`) can run without a keyword. Before Session 162 this guard
        // rejected them, so the person handoff surfaced an error instead of results.
        guard Self.hasPositiveKeywordTerm(params) else {
            // This refusal replaced any run under way, which will clear nothing now (#1648).
            isSearching = false
            searchError = String(
                localized: "search.error.empty",
                defaultValue: "Enter a keyword, phrase, or prefix to search."
            )
            return true
        }
        // Freeze the query text for `recordSearchHistory` before awaiting anything (see
        // `submittedQuery`).
        submittedQuery = keywords.trimmingCharacters(in: .whitespacesAndNewlines)
        isSearching = true
        searchError = nil
        hasSearched = true
        searchSetAsideByModeSwitch = false
        do {
            // Concurrently, not sequentially: the two statements share their joins, so the
            // second runs against pages the first has already faulted in. Mirrors
            // `MacSearchViewModel.performSearch`, which has always done it this way.
            // A browse fetches deeper than a keyword search because its rows are far smaller —
            // no `body_text`, since there are no terms to snippet against. See `filterOnlyHardLimit`.
            let fetchLimit = params.runsAsFilterOnly ? Self.filterOnlyHardLimit : Self.searchHardLimit
            // #1577 lane 1: a search inside a document set is timed, for `SearchTimingLog`.
            let clock = ContinuousClock()
            let sent = clock.now
            // A task of its own, so that whatever replaces this run stops it (#1680): the kit stops a
            // search's statements when the task running them is cancelled, and the search that replaced
            // this one then runs at once instead of after them. See `startRun()`.
            let fetch = Task { [searchService] () async throws -> KeywordFetch in
                async let fetched = searchService.search(parameters: params, limit: fetchLimit)
                async let counted: Int? = {
                    // A failed count must not fail the search. The header and the capture warning
                    // both degrade to "total unavailable", which is what macOS already shows.
                    do { return try await searchService.searchCount(parameters: params) }
                    catch { return nil }
                }()
                let rows = try await fetched
                let rowsTime = clock.now - sent
                let total = await counted
                let totalTime = clock.now - sent
                return KeywordFetch(rows: rows, total: total, rowsTime: rowsTime, totalTime: totalTime)
            }
            keywordFetchUnderWay = fetch
            defer { if keywordFetchUnderWay == fetch { keywordFetchUnderWay = nil } }
            let fetchedRun = try await fetch.value
            let rows = fetchedRun.rows
            let rowsTime = fetchedRun.rowsTime
            let total = fetchedRun.total
            let totalTime = fetchedRun.totalTime
            // Same actor hop as the fetch, no query: a thin face on the renderer the search used.
            let expression = try? await searchService.matchExpressions(for: params).corpus
            // A run a later one replaced writes nothing (#1648). Asked once, after the last wait, so
            // that what is written is one run's rows with their own total, expression and checklist:
            // written as each came back, a run replaced between two waits left its rows under the last
            // search's total. Waiting costs nothing seen, since the results are not drawn while a
            // search runs.
            guard searchRuns.isLatest(run) else { return false }
            if let base {
                // Words found in a held Meaning list (#1577 lane 4). Its total stays `nil`: a capture
                // stores the total beside its partial flag, and the layer's own count there would read
                // back as "captured from 7 matches" (`ExecutedSearchRoute.wordsInMatches`).
                results = LayeredResultComposer.wordsInMatches(keywordRows: rows, base: base)
                executedRoute = .wordsInMatches(base: base.members.count)
                totalMatchCount = nil
                lastLayerFiltersNarrowed = filtersNarrowed
            } else {
                results = rows
                executedRoute = .keywords
                totalMatchCount = total
                filterSignatureOfTheRows = SearchScopeSignature.signature(for: params)
            }
            // With the rows, not before the await: `resultSetScope` reads both, and until the rows are
            // replaced the ones on screen are the last search's, fetched under its ceiling (#1584).
            lastFetchLimit = fetchLimit
            beyondLibraryHits = []
            semanticDisclosure = nil
            semanticNeedsModel = false
            if let documentSet = params.documentIds {
                SearchTimingLog.record(SearchTimingLog.GatedKeyword(
                    setSize: documentSet.count, rowCount: rows.count,
                    rows: rowsTime, total: totalTime))
            }
            // A layer's expression names its base as well, for the method appendix's CSV (#1577 lane 4).
            lastRenderedExpression = base.map { inside in expression.map { $0 + inside.renderedExpressionSuffix } }
                ?? expression
            // Bumped AFTER `results` is replaced, so the "completed search" the doc comment
            // promises is what consumers actually observe. It used to be bumped in the
            // synchronous prefix, five lines and one actor hop earlier: SwiftUI re-evaluated the
            // body during the await — it must, or the `isSearching` spinner would never appear —
            // and every `.task(id:)` keyed on the version fired against the PREVIOUS query's
            // results. The concordance survived that by accident, because its key also carries the
            // page and `currentPage = 0` re-triggered it; a key without a page member had no such
            // rescue and settled on a confident ranking of the wrong documents. Matches
            // `MacSearchViewModel.performSearch`, which has always ordered these correctly.
            executedSearchVersion &+= 1
            // #1310: the parameters that RAN, frozen here. The live field may already have moved.
            userTagCountScope = .match(params)
            currentPage = 0
            if base == nil {
                // A new search is a fresh checklist (#189-D): re-anchor "reviewed since" to now and
                // clear prior marks, so results reviewed under a *previous* search aren't silently
                // hidden in this one. A re-run of the same search keeps them (#1576 lane 1). Built
                // from the parameters that ran, not the live ones.
                settleChecklist(for: ChecklistAnchor(query: submittedQuery, parameters: params))
                // #1576 lane 3: the picks last as long as the checklist's marks do, by the same rule.
                settleSelection(for: ChecklistAnchor(query: submittedQuery, parameters: params))
            } else {
                // A layer runs inside the base's search, whose checklist it keeps: marks made on the
                // base last through every layer and the return to it (#1577 lane 4). Its rows are
                // another list, so picks end.
                endSelecting()
            }
            #if DEBUG
            print("[SearchView] Search returned \(results.count) results")
            #endif
        } catch {
            // Nor does a replaced run's failure reach the screen (#1648).
            guard searchRuns.isLatest(run) else { return false }
            results = []
            executedRoute = .keywords
            beyondLibraryHits = []
            semanticDisclosure = nil
            // Cleared with the results, at every site that clears them: a total left over from
            // the previous query is a denominator for a set that no longer exists.
            totalMatchCount = nil
            lastRenderedExpression = nil
            // Bumped here too: a failed search is a completed one for every consumer keyed on the
            // version, and leaving it unchanged would strand them on the previous query's answer.
            executedSearchVersion &+= 1
            userTagCountScope = nil
            // A query the parse refused reads as a message pointing at Search Tips rather than as
            // "FTS5Error error 5"; every other failure keeps its own description (#1299).
            searchError = SearchQueryRefusal.readable(error, for: params).localizedDescription
            #if DEBUG
            print("[SearchView] Search error: \(error)")
            #endif
        }
        isSearching = false
        // Wave R-2a: the `appState?.logEvent(.searchSubmit(…))` that stood here is gone, as R-4
        // said it would be. `SearchView.runSearch()` calls `recordSearchHistory` immediately after
        // this method returns, and that `SearchHistoryEntry` is now the only record of a search —
        // read by the History surface, Project Home, and the derived session log alike.
        // `ResearchTrailMigration` carries the events already written by earlier builds across.
        return true
    }

    /// The Meaning run (V-5 hybrid page). Mirrors `search()`'s bookkeeping contract exactly —
    /// freeze, flags, version bump AFTER results land, checklist re-anchor — with the engine
    /// swapped and the FTS-only fields (`totalMatchCount`, the rendered expression) given their
    /// honest Meaning values: the total is `nil` (a top-K list has no uncapped match count, and
    /// recording one would poison the SavedSearch freshness watermark, which diffs against a
    /// later FTS count), and the expression records the route and model instead of an FTS string.
    ///
    /// - Parameter run: This run's number, from `search()` (#1648).
    /// - Returns: `true` when this run was not replaced, as `search()` returns.
    private func searchMeaning(run: Int) async -> Bool {
        submittedQuery = keywords.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !submittedQuery.isEmpty else {
            // A refusal replaced any run under way, which will clear nothing now (#1648).
            isSearching = false
            searchError = String(
                localized: "search.semantic.error.empty",
                defaultValue: "Type a question or phrase to search by meaning.")
            return true
        }
        guard let backend = semanticBackend else {
            isSearching = false
            searchError = String(
                localized: "search.semantic.error.unavailable",
                defaultValue: "Searching by meaning is not available in this build.")
            return true
        }
        isSearching = true
        searchError = nil
        hasSearched = true
        searchSetAsideByModeSwitch = false
        semanticNeedsModel = false
        lastRunWasSemantic = true
        // The checklist's anchor is of the search that ran: read here, before the await, as the
        // engine's parameters are on the next line.
        let checklistAnchorOfThisRun = ChecklistAnchor(query: submittedQuery, parameters: searchParameters)
        // And the filters it runs under, which a list held from it compares a layer's with (#1577 lane 4).
        let filterSignatureOfThisRun = SearchScopeSignature.signature(for: searchParameters)
        do {
            // Inside a held keyword list or browse this run ranks it by the question (#1577 lane 4). Its
            // failures are this function's, in the `catch`es below.
            if let base = pinnedBase {
                return try await rankHeldList(run: run, base: base, backend: backend)
            }
            let outcome = try await backend.run(query: submittedQuery, parameters: searchParameters)
            // A Meaning run a later search replaced writes nothing: the case #1648 was filed for, a
            // Meaning list landing over the keyword rows of the search that followed it. Nor does
            // such a run's failure, below.
            guard searchRuns.isLatest(run) else { return false }
            results = outcome.results
            executedRoute = .meaning
            filterSignatureOfTheRows = filterSignatureOfThisRun
            beyondLibraryHits = outcome.beyondLibrary
            semanticDisclosure = outcome.disclosure
            totalMatchCount = nil
            lastFetchLimit = SemanticSearchBackend.hitLimit
            // Printed in the method appendix's CSV verbatim — the honest record of what ran.
            lastRenderedExpression = SemanticSearchBackend.renderedExpression
            executedSearchVersion &+= 1
            // #1310: the meaning route counts over the results themselves — there is no FTS match
            // to rebuild, and rebuilding one from the typed question is what this fixes.
            userTagCountScope = .resultKeys(results.map {
                UserTagCountScope.DocumentKey(volumeId: $0.volumeId, documentId: $0.documentId)
            })
            currentPage = 0
            settleChecklist(for: checklistAnchorOfThisRun)
            settleSelection(for: checklistAnchorOfThisRun)
        } catch SemanticQuerySearcher.SearchUnavailable.modelNotDownloaded {
            guard searchRuns.isLatest(run) else { return false }
            results = []
            executedRoute = .keywords
            beyondLibraryHits = []
            semanticDisclosure = nil
            totalMatchCount = nil
            lastRenderedExpression = nil
            semanticNeedsModel = true
            executedSearchVersion &+= 1
            userTagCountScope = nil
        } catch SemanticQuerySearcher.SearchUnavailable.queryTooLong {
            guard searchRuns.isLatest(run) else { return false }
            results = []
            executedRoute = .keywords
            beyondLibraryHits = []
            semanticDisclosure = nil
            totalMatchCount = nil
            lastRenderedExpression = nil
            executedSearchVersion &+= 1
            userTagCountScope = nil
            searchError = String(
                localized: "search.semantic.error.tooLong",
                defaultValue: "This search is too long for the model. Try a shorter phrasing.")
        } catch {
            guard searchRuns.isLatest(run) else { return false }
            results = []
            executedRoute = .keywords
            beyondLibraryHits = []
            semanticDisclosure = nil
            totalMatchCount = nil
            lastRenderedExpression = nil
            executedSearchVersion &+= 1
            userTagCountScope = nil
            searchError = String(
                localized: "search.semantic.error.failed",
                defaultValue: "Semantic search could not run. Try again.")
            #if DEBUG
            print("[SearchView] Meaning search error: \(error)")
            #endif
        }
        isSearching = false
        return true
    }

    /// A held keyword list or browse ranked by the question in the field (#1577 lane 4): every row of the
    /// list, closest first, and the rows the engine cannot rank last, in the list's own order.
    ///
    /// ``searchMeaning(run:)``'s second path, with its bookkeeping; what fails here is thrown to that
    /// function's `catch`es. A ranking keeps the list's ceiling and total, so the list stays cut where its
    /// keyword fetch was cut (`ExecutedSearchRoute.rankedByMeaning`), and its expression says it ranked the
    /// whole list, not a top hundred. It runs inside the base's search, whose checklist it keeps, as words
    /// found in a list do; its rows are another list, so picks end.
    ///
    /// - Parameters:
    ///   - run: This run's number, from `search()` (#1648).
    ///   - base: The held list.
    ///   - backend: The Meaning engine.
    /// - Returns: `true` when this run was not replaced, as `search()` returns.
    private func rankHeldList(run: Int, base: PinnedResultBase, backend: any MeaningSearchRunning) async throws -> Bool {
        let ranking = try await backend.rerank(query: submittedQuery, base: base.members, parameters: searchParameters)
        guard searchRuns.isLatest(run) else { return false }
        results = ranking.results
        executedRoute = .rankedByMeaning(unranked: ranking.results.filter { $0.semanticScore == nil }.count)
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
        currentPage = 0
        endSelecting()
        isSearching = false
        return true
    }

    // MARK: - Switching the engine (#1597)

    /// Whether the keyword engine has anything to run in `params`: typed text, a restored phrase or
    /// prefix, or a person or subject filter alone, which `SearchService` applies in SQL.
    ///
    /// The rule `search()` refuses on. An exclusion is not on the list: alone it names nothing to find.
    private static func hasPositiveKeywordTerm(_ params: SearchParameters) -> Bool {
        params.keywords != nil
            || params.phrase != nil
            || params.prefixWildcard != nil
            || params.supportsFilterOnlySearch
    }

    /// Whether the engine `mode` names has anything to run in the live parameters.
    ///
    /// A Meaning search runs on a typed question and reads nothing else as one, so a browse (a person's
    /// Find all mentions, a topic, a subject area) gives it nothing to run.
    func hasRunnableQuery(in mode: SearchMode) -> Bool {
        switch mode {
        case .keywords:
            return Self.hasPositiveKeywordTerm(searchParameters)
        case .meaning:
            return !keywords.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    /// Moves the Keywords | Meaning picker to `newMode`, and settles what the rows on screen are (#1597).
    ///
    /// **The rows on screen should belong to the engine the picker names.** The strip under the picker
    /// assumes so. (The Examine menu's gate and the facet panel's counts did until #1577 lane 2; they ask
    /// the route recorded with the rows now.) A search that is on screen therefore runs again through
    /// the new engine. When that engine has nothing to run
    /// (Meaning over a browse, which has no question), the rows are cleared and the pre-search prompt
    /// shows, as the Mac's Search window does. Until #1597 the rows stayed where they were, under the
    /// count line "412 closest matches" and the Meaning strip, although no Meaning search had run.
    ///
    /// The cleared search is remembered, so switching back to an engine that can run it shows it again.
    /// Without that a browse would be lost to one tap: the keyboard's Search key is off while the field
    /// is empty, so the reader could not run it again from this screen.
    ///
    /// - Parameter newMode: The mode the reader chose.
    /// - Returns: `true` when the caller must run the search now. It is returned and not run here
    ///   because every search entry point goes through `SearchView.runSearch()`, which records it.
    func switchSearchMode(to newMode: SearchMode) -> Bool {
        guard newMode != searchMode else { return false }
        searchMode = newMode
        // A run under way is the other engine's, and its rows would land under this picker (#1648).
        // `isSearching` stays as it is until the run the caller starts now replaces it, or below.
        replaceRunsUnderWay()
        guard hasSearched || searchSetAsideByModeSwitch else { return false }
        if hasRunnableQuery(in: newMode) { return true }
        isSearching = false
        results = []
        executedRoute = .keywords
        beyondLibraryHits = []
        semanticDisclosure = nil
        semanticNeedsModel = false
        totalMatchCount = nil
        lastRenderedExpression = nil
        searchError = nil
        // As `clearAll()` and the cleared search field do: no search has completed, so the version is
        // not bumped, and a nil scope shows no tag counts for the rows that have gone (#1310).
        userTagCountScope = nil
        hasSearched = false
        currentPage = 0
        searchSetAsideByModeSwitch = true
        return false
    }

    /// Applies a search hand-off (`AppState.pendingSearch`) and says whether it names a search to run.
    ///
    /// A hand-off that names something to find runs as a keyword search whatever the picker showed, as
    /// a saved search does (``SearchParameters/namesASearchToRun``). The picker used to keep its mode,
    /// so with Search on Meaning a person's Find all mentions, which carries no question, arrived on a
    /// Search Error panel ("Type a question or phrase to search by meaning."), and Corpus Analytics'
    /// "View N documents" ranked the term by meaning and did not show those N documents.
    ///
    /// A hand-off that only sets a scope (Search this volume) runs nothing and leaves the picker alone:
    /// the scope applies to either engine.
    ///
    /// - Parameter params: The hand-off's parameters.
    /// - Returns: `true` when the caller must run the search now, through `SearchView.runSearch()`.
    func applyHandoff(_ params: SearchParameters) -> Bool {
        let namesASearch = params.namesASearchToRun
        // A held list's own engine, which comes back with its rows when the hand-off runs nothing (#1577
        // lane 4): the picker then names the engine of the rows it sits over.
        let heldListEngine = pinnedBase?.direction.baseEngine
        if namesASearch { searchMode = .keywords }
        applyParameters(params)
        if !namesASearch, let heldListEngine { searchMode = heldListEngine }
        return namesASearch
    }

    /// Which set this screen is showing, composed from what was recorded with the rows.
    ///
    /// The one place iPhone and iPad compose it. `totalMatchCount` is a whole-query count taken beside
    /// the search; it stays optional because the count can fail, and every sentence in
    /// ``ResultSetScope`` is true without one.
    ///
    /// On the view model, and not in `SearchView`, since #1584. The view passed the 1,000-row keyword
    /// ceiling for every search, so a complete browse of 3,000 documents, fetched under 7,500, read
    /// "3,000 loaded · 3,000 total", and a working corpus saved from it was stored as a partial capture.
    /// It also read the picker for the engine (#1597). Here both come from the run that produced the
    /// rows, and a test can read the result without a view.
    var resultSetScope: ResultSetScope {
        let layered = executedRoute.isLayer
        var ranking = false
        if case .rankedByMeaning = executedRoute { ranking = true }
        return ResultSetScope(loaded: results.count,
                              shown: displayedResults.count,
                              fetchLimit: lastFetchLimit,
                              totalMatchCount: totalMatchCount,
                              documentsOnPage: pagedResults.count,
                              pageCount: totalPages,
                              appliedCorpusTruncation: appliedWorkingCorpusTruncation,
                              route: executedRoute,
                              // #1577 lane 4: what a layer's sentences owe.
                              layerFiltersNarrowed: layered && lastLayerFiltersNarrowed,
                              listIsInRankOrder: sortOrder == .relevance,
                              layerBaseLabel: layered ? pinnedBase?.captureLabel : nil,
                              // A ranking's rows can be fewer than its list's with nothing cut: those the
                              // checklist hid when it was held, and those a filter chosen since removes.
                              layerBaseWasCut: ranking ? pinnedBase?.wasCut : nil,
                              layerBaseHiddenByChecklist: ranking ? pinnedBase?.hiddenByChecklist ?? 0 : 0)
    }

    // MARK: - Search History

    /// What this screen last wrote to the trail — see ``SearchHistoryWriter/Anchor``.
    ///
    /// Several of `SearchView`'s entry points re-run `search()` for the **same** query with a
    /// changed filter — clearing the volume scope, tapping a tag chip on a result row. Those are
    /// not separate searches the researcher ran, so they refresh the anchored row rather than
    /// minting a second one. Held here rather than derived from the table, which is shared across
    /// windows, devices and projects.
    private var historyAnchor: SearchHistoryWriter.Anchor?

    /// Records the most recently executed search — the iOS half of the trail's search producer.
    ///
    /// Call once after `search()` completes; `SearchView.runSearch()` is the single site that does
    /// so, which is why every search entry point in that view routes through it. All the rules —
    /// the research-logging gate, the empty-query and error skips, and the insert-or-refresh
    /// decision — live in ``SearchHistoryWriter``, shared with macOS, because two copies of them
    /// is how #612 shipped a trail whose two platforms disagreed about the same query's count.
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
        // A layer's row records the list it shows as its whole answer (#1577 lane 4): left with no
        // match count, a complete ranking of 212 rows under a 1,000-row ceiling would print as "at
        // least 212", and a ranking keeps its base's total, which is no count of the layer.
        let layer = executedRoute.isLayer ? pinnedBase : nil
        let outcome = SearchHistoryWriter.record(
            SearchHistoryWriter.Reading(
                queryText: submittedQuery,
                // The true total when there is one, the fetched count otherwise. `resultCount`
                // cannot express "unknown", so the honest fallback is what was actually seen.
                resultCount: layer != nil ? results.count : (totalMatchCount ?? results.count),
                loadedCount: results.count,
                matchCount: layer != nil ? results.count : totalMatchCount,
                fetchLimit: lastFetchLimit,
                indexedVolumeCount: indexedVolumeCount,
                // The executed parameters, not the live filter state — those may have moved.
                parameters: submittedSearchParameters,
                appliedCorpusId: appliedWorkingCorpusId,
                // Rendered in `search()` against these parameters. Deliberately NOT the Query
                // Inspector, which is debounced view state keyed on the live text.
                renderedExpression: lastRenderedExpression,
                // A Meaning run must not be stamped with an FTS-shaped scope signature — the
                // appendix would decode it into "searched document text" claims. The route
                // signature has no `mode=` key, so the fails-closed decoder prints it verbatim.
                // Inside a document set it names the set as well (#1577 lane 1), and a layer adds
                // its base (`base=`, #1577 lane 4), which an earlier build passes over.
                signatureOverride: SearchScopeSignature.layered(
                    lastRunWasSemantic
                        ? SearchScopeSignature.semanticSignature(for: submittedSearchParameters) : nil,
                    parameters: submittedSearchParameters, base: layer),
                projectId: projectId,
                hasError: searchError != nil),
            anchor: &historyAnchor,
            in: context,
            defaults: defaults)
        #if DEBUG
        print("[SearchViewModel] SearchHistoryEntry \(outcome): \"\(submittedQuery)\"")
        #else
        _ = outcome
        #endif
    }

    func clearFilters() {
        phrase = ""
        prefixWildcard = ""
        booleanMode = .and
        excludedTermsText = ""
        dateRangeEnabled = false
        facetYearKeys = nil
        selectedUserTagIds = []
        selectedVolumeIds = []
        selectedSubseriesIds = []
        includeDocumentText = SearchDefaults.scopeDocuments
        includeSummaries = SearchDefaults.scopeSummaries
        includeNotes = SearchDefaults.scopeNotes
        includeFrontMatter = true
        documentTypeFilter = SearchDefaults.documentTypeFilter
        personRefText = ""
        personRollupId = nil
        personLabel = nil
        personAnchor = nil
        // #308. Clear Filters must reach a facet-panel narrowing too — it is set by a single tap
        // and is exactly the kind a reader would expect this button to undo.
        subjectBucket = nil
        subjectBucketKey = nil
        // Reset the project scope selection + Focus "only new" toggle (keep the loaded
        // engaged-key/focus-volume sets — they are context, not user filters, and
        // re-populate only when the project changes).
        projectScope = .off
        projectOnlyNew = false
        // Cleared with the rest. Leaving it made Clear Filters a promise it did not keep for the
        // one filter the control could not display either.
        clearWorkingCorpus()
    }

    /// Replaces every search still under way without starting one, for a list emptied with no search
    /// (#1648): the field cleared on iPhone and iPad. A run that comes back after this writes nothing,
    /// so it cannot put rows back under the empty field, and nothing is searching any more.
    func replaceSearchesUnderWay() {
        replaceRunsUnderWay()
        isSearching = false
    }

    /// Starts a run, which replaces the runs under way and stops the keyword fetch of the one that has
    /// one (#1680), and returns its number. `search()` calls nothing else to start one.
    private func startRun() -> Int {
        stopKeywordFetchUnderWay()
        return searchRuns.startRun()
    }

    /// Replaces the runs under way without starting one, and stops the keyword fetch of the one that
    /// has one (#1680). Every replacement on this screen goes through here or ``startRun()``.
    private func replaceRunsUnderWay() {
        stopKeywordFetchUnderWay()
        searchRuns.replaceRunsUnderWay()
    }

    /// Cancels the keyword fetch under way, if any, so that the kit stops its statements (#1680). The
    /// run it belonged to writes nothing either way: the ledger says it was replaced.
    private func stopKeywordFetchUnderWay() {
        keywordFetchUnderWay?.cancel()
        keywordFetchUnderWay = nil
    }

    /// Whether the search under way has no words (#1648): a browse, such as a person's Find all
    /// mentions or a subject, or a restored phrase or prefix with nothing typed.
    ///
    /// `SearchView` asks it when the field is emptied. A hand-off or a recalled search with no words
    /// empties the field itself, through ``applyParameters(_:)``, and the search it starts can be under
    /// way before the field's handler runs. That search is the reader's latest request, so the handler
    /// leaves it, and its screen, alone; an emptied field replaces only a search for words.
    var isSearchingWithNoWords: Bool { isSearching && submittedQuery.isEmpty }

    func clearAll() {
        // Given the same clear as a hand-off, though only a test calls this (#1577 lane 4).
        leaveBaseForHandoff()
        replaceSearchesUnderWay()
        keywords = ""
        clearFilters()
        results = []
        totalMatchCount = nil
        lastRenderedExpression = nil
        hasSearched = false
        searchError = nil
        // #1310: the counts describe a result set that no longer exists.
        userTagCountScope = nil
        executedRoute = .keywords
        searchSetAsideByModeSwitch = false
        // #1577 lane 1: nor does the Meaning strip describe one.
        semanticDisclosure = nil
        beyondLibraryHits = []
    }

    // MARK: - Computed Properties

    /// The effective volume scope forwarded to `SearchService`: the de-duplicated
    /// union of the individually-selected volumes (`selectedVolumeIds`) and every
    /// indexed volume belonging to a selected subseries (`selectedSubseriesIds`).
    ///
    /// Empty when no volume or subseries filter is active, in which case
    /// `searchParameters` passes `nil` (search the whole indexed corpus).
    var effectiveVolumeIds: [String] {
        var ids = Set(selectedVolumeIds)
        if !selectedSubseriesIds.isEmpty {
            for entry in availableVolumes where selectedSubseriesIds.contains(entry.subseries) {
                ids.insert(entry.volumeId)
            }
        }
        return ids.sorted()
    }

    /// The applied working corpus, as its **indexed** document keys, or `nil` when none is applied.
    ///
    /// Document-grain scope (M-1). Held as resolved keys rather than as the corpus's identifier so
    /// the search parameters stay a self-contained value — the same reason `documentIds` exists at
    /// all — and so an applied corpus survives the corpus being renamed mid-session.
    var appliedWorkingCorpusKeys: [String]?

    /// The corpus's name, for the applied-scope chip. Cleared with the keys.
    var appliedWorkingCorpusName: String?

    /// The applied corpus's id, recorded so a trail entry can resolve its truncation later.
    /// Names are deliberately not unique, so an entry keyed on the name could resolve the wrong
    /// corpus's capture and mislabel its own count as partial or complete.
    var appliedWorkingCorpusId: UUID?

    /// What is known about the applied corpus's own truncation, captured at the moment it is
    /// applied because that is the only place the `WorkingCorpus` object is in hand.
    ///
    /// Carried alongside the keys rather than looked up by name later: names are deliberately not
    /// unique (`WorkingCorpus` says so — uniqueness cannot be guaranteed across CloudKit devices),
    /// so a by-name lookup could resolve the wrong corpus's truncation onto the applied one.
    var appliedWorkingCorpusTruncation: WorkingCorpus.CaptureTruncation?

    /// How many documents the next search would run inside, or `nil` when no document set is
    /// applied: the live gate's size, an applied working corpus intersected with the project's
    /// History scope (#1577 lane 1).
    ///
    /// The Meaning strip and the pre-search prompt read it to say where a Meaning search will
    /// rank. Zero is a set that holds nothing, which is not the same as no set.
    var documentSetSize: Int? { searchParameters.documentIds?.count }

    /// Clears any applied working corpus.
    func clearWorkingCorpus() {
        appliedWorkingCorpusKeys = nil
        appliedWorkingCorpusName = nil
        appliedWorkingCorpusId = nil
        appliedWorkingCorpusTruncation = nil
    }

    /// The volume scope + History/Focus document gate the active project scope produces
    /// (#377 Phase 2). History gates `documentIds` to the engaged set. Focus scopes to
    /// volumes: a **manual** volume selection (or applied custom scope) *overrides* the
    /// subject-derived focus volumes, otherwise the subject volumes apply; a Focus scope
    /// with neither matches nothing (an empty `documentIds`, mirroring History's empty-set
    /// contract) rather than silently searching the whole corpus.
    private var projectScopedGates: (volumeIds: [String]?, documentIds: [String]?) {
        let manualVolumes = effectiveVolumeIds.isEmpty ? nil : effectiveVolumeIds
        switch projectScope {
        case .off:
            return (manualVolumes, nil)
        case .history:
            return (manualVolumes, projectEngagedDocumentKeys)
        case .focus:
            if let manualVolumes { return (manualVolumes, nil) }        // manual overrides
            return projectFocusVolumeIds.isEmpty
                ? (nil, [])                                             // neither → match nothing
                : (projectFocusVolumeIds, nil)                         // subject-derived
        }
    }

    /// The parameters of the search that actually **ran**.
    ///
    /// `searchParameters` reads the live `keywords` field, which changes on every keystroke. Any
    /// consumer describing the results on screen — the concordance, the collocation — must anchor on
    /// what produced them, or it reports on a query the user has typed but not run. Mirrors
    /// `MacSearchViewModel.submittedSearchParameters`, which this side lacked.
    var submittedSearchParameters: SearchParameters {
        var params = searchParameters
        let trimmed = submittedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        params.keywords = trimmed.isEmpty ? nil : trimmed
        return params
    }

    /// What the iOS Query Inspector refreshes on: the parts of the live parameter set the inspection reads,
    /// `QueryInspector.Inputs` of `searchParameters`.
    ///
    /// The inspection reads more than the typed text. Its operands, not-applied rows and narrower-than-typed caption
    /// come from the combined parse of `keywords` with a restored search's `phrase`, `prefixWildcard` and excluded
    /// terms (`SearchService.parsedQuery(for:)`); the scope flags decide which expressions render; and the filters
    /// decide whether a query with no expression runs filter-only, and what the scoped counts count. Keyed on
    /// `keywords` alone, as `SearchView` was, Clear Filters removed a restored phrase and left the strip describing the
    /// search before it: `cold OR -korea` beside the phrase "cold war" is searched exactly, and without it is narrower
    /// than typed (#1297 round 1, F7).
    ///
    /// Not the whole parameter set, whose `==` also compares four fields no pass reads — `personLabel`, `personAnchor`,
    /// `booleanMode` and `projectId`. After a rollup rebuild `refreshPersonRollupBinding(using:)` captures an anchor, or
    /// relabels the filter, without running a search, and a key that moved with them restarted the refresh, which
    /// replaced the inspection's scoped counts and cleared the zero-result blame (#1297 round 2, A3).
    /// `QueryInspector.Inputs` says which fields are read and why, and `QueryInspectionTests` fails when
    /// `SearchParameters` gains a field neither side names. The macOS window keys the same refresh on `queryText` and
    /// `parametersVersion`, which its filter and scope edits bump and a person filter's anchor capture or relabel does
    /// not.
    ///
    /// Neither key holds the indexed-volume count or the live index, which the inspection also reads; see
    /// `QueryInspector.Inputs`.
    var queryInspectorRefreshKey: QueryInspector.Inputs { QueryInspector.Inputs(searchParameters) }

    /// The live parameter set: the typed text, the restored structured fields, the scope flags and every filter, as
    /// the next search would run them.
    ///
    /// While a base is held its members join the document gate (#1577 lane 4,
    /// `DocumentScopeGate.combine(corpus:projectGate:pin:)`), so a layer runs inside it, the Query Inspector's counts
    /// "in your current scope" are counts inside it, and the Meaning strip and prompt name its size. Nothing else
    /// reads the base from here: ``hasActiveFilters`` and ``activeNarrowings`` read the fields, so the filter glyph
    /// does not light for it.
    var searchParameters: SearchParameters { parameters(insideBase: pinnedBase) }

    /// The live parameter set with no held base: what ``searchParameters`` was before #1577 lane 4, and what a held
    /// base's own filters are compared with.
    private var parametersOutsideBase: SearchParameters {
        let kw = keywords.trimmingCharacters(in: .whitespaces)
        let ph = phrase.trimmingCharacters(in: .whitespaces)
        let pw = prefixWildcard.trimmingCharacters(in: .whitespaces)
        let excluded = excludedTermsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let range: DateRange? = dateRangeEnabled
            ? DateRange(
                earliest: SearchViewModel.isoDate(dateRangeStart),
                latest: SearchViewModel.isoDate(dateRangeEnd)
              )
            : nil
        let scoped = projectScopedGates
        return SearchParameters(
            keywords: kw.isEmpty ? nil : kw,
            phrase: ph.isEmpty ? nil : ph,
            booleanMode: booleanMode,
            excludedTerms: excluded,
            prefixWildcard: pw.isEmpty ? nil : pw,
            dateRange: range,
            yearKeys: facetYearKeys,
            subjectTagIds: [],
            userTagIds: selectedUserTagIds.map(\.uuidString),
            volumeIds: scoped.volumeIds,
            documentIds: DocumentScopeGate.combine(corpus: appliedWorkingCorpusKeys,
                                                   projectGate: scoped.documentIds),
            // Project Focus "only new" (#377 Phase 2b): excludes the engaged set so discovery
            // emphasizes fresh material. Only in `.focus` with the toggle on.
            excludeDocumentIds: (projectScope == .focus && projectOnlyNew)
                ? projectEngagedDocumentKeys : nil,
            includeDocumentText: includeDocumentText,
            includeSummaries: includeSummaries,
            includeNotes: includeNotes,
            documentTypeFilter: documentTypeFilter,
            personRef: personRefText.trimmingCharacters(in: .whitespaces).isEmpty
                ? nil
                : personRefText.trimmingCharacters(in: .whitespaces),
            personRollupId: personRollupId,
            personLabel: personLabel,
            personAnchor: personAnchor,
            includeFrontMatter: includeFrontMatter,
            subjectBucket: subjectBucket,
            subjectBucketKey: subjectBucketKey,
            subjectRef: subjectRef,
            subjectName: subjectName
        )
    }

    /// The number of results currently shown to the user — the checklist-filtered count, so the
    /// results-count header matches the visible rows.
    var resultCount: Int { displayedResults.count }

    /// `true` when the result set hit the ceiling it was fetched at, indicating the query matches
    /// more documents than are shown. Users should narrow their search terms. Keyed on the raw
    /// fetch count (not the checklist-filtered view), since the cap is about the FTS5 fetch.
    ///
    /// Compares against `lastFetchLimit`, which differs by query shape: a browse is fetched to
    /// `filterOnlyHardLimit`. Comparing against the keyword ceiling instead would call a
    /// 7,500-row browse "not capped" at exactly the point it is.
    var isResultsCapped: Bool { results.count == lastFetchLimit }

    // Note: this still checks the legacy `phrase`/`prefixWildcard`/`excludedTermsText`/
    // `booleanMode` fields even though `SearchFilterView` no longer exposes controls for
    // them — a restored `SavedSearch`/`pendingSearch` snapshot can still populate them via
    // `applyParameters(_:)`, and when it does, that state genuinely affects the query, so
    // the "Clear Filters" affordance must remain available to reset it.
    /// The search service, for tests that need to drive the count loader.
    var searchServiceForTesting: SearchService { searchService }

    /// How many documents in the current result set carry each user tag, keyed by
    /// `UUID.uuidString` (R-1 follow-up).
    ///
    /// Populated on demand when the filter sheet opens — never eagerly, and never for the
    /// facet panel. An absent key means the tag matched nothing, or counts have not been
    /// computed; the surface distinguishes those with ``hasUserTagCounts``.
    var userTagCounts: [String: Int] = [:]

    /// Whether the tag counts have been computed for the current match.
    ///
    /// Separate from `userTagCounts.isEmpty`, because "every tag matched nothing" and "not
    /// computed yet" must render differently — the first is an answer.
    var hasUserTagCounts: Bool = false

    /// Whether the count pass is running.
    var isCountingUserTags: Bool = false

    /// Counts each of `tags` against the result set `matchParameters` describes.
    ///
    /// - Parameter matchParameters: the query to count against. Passed in rather than read
    ///   from `self` because on macOS this view model is the *filter sheet's* — seeded by
    ///   `MacSearchViewModel.syncToFilterVM`, which copies `phrase` but **not** `keywords`.
    ///   Counting against `self.searchParameters` there would silently describe a different
    ///   result set than the one on screen.
    func loadUserTagCounts(
        scope: UserTagCountScope,
        tags: [UserTag],
        service: SearchService?,
        pipeline: IndexingPipeline?
    ) async {
        guard let pipeline, !tags.isEmpty else { return }
        isCountingUserTags = true
        defer { isCountingUserTags = false }
        do {
            let counts: [String: Int]
            switch scope {
            case .match(let matchParameters):
                // The keyword route, unchanged: rebuild the executed match and count over it.
                // `service` is needed only here — a key-set count consults no expression, which
                // is exactly how the Meaning leak happened (#1310).
                guard let service else { return }
                let expressions = try await service.matchExpressions(for: matchParameters)
                let filters = await service.filtersForTesting(matchParameters)
                counts = try await pipeline.userTagCounts(
                    corpusMatch: expressions.corpus, userContentMatch: expressions.userContent,
                    filters: filters, tagIds: tags.map(\.id.uuidString))
            case .resultKeys(let keys):
                // The keys are already filtered by the backend, so no filters are applied and no
                // expression is asked for.
                counts = try await pipeline.userTagCounts(
                    corpusMatch: nil, userContentMatch: nil, filters: SearchSQLFilters(),
                    tagIds: tags.map(\.id.uuidString),
                    documentKeys: keys.map { (volumeId: $0.volumeId, documentId: $0.documentId) })
            }
            guard !Task.isCancelled else { return }
            userTagCounts = counts
            hasUserTagCounts = true
        } catch {
            // A query with no searchable content throws `emptyQuery`; that is not a count
            // failure and must not leave `hasUserTagCounts` true with stale numbers.
            userTagCounts = [:]
            hasUserTagCounts = false
        }
    }

    /// The match total to show the facet panel, or `nil` when it is not known (R-1c).
    ///
    /// iOS has never held a whole-query count: `resultCount` is the *fetched* count, capped
    /// at `searchHardLimit` (1,000). So this returns the fetched count only when the fetch
    /// demonstrably did **not** hit its cap — at the cap the real total is unknown, and
    /// reporting 1,000 as "all 1,000 matches" would be exactly the lie the Q-M2 work removed
    /// from macOS. The panel renders "total unavailable" instead.
    ///
    /// The facet *sections* are unaffected either way: they aggregate over the whole match in
    /// SQL, independent of what was fetched.
    var totalMatchCountForFacets: Int? {
        // The real total when one was taken; otherwise the old rule, which refuses to report the
        // fetched count as a total once the fetch hit its ceiling. The fallback is not dead code —
        // `searchCount` can fail, and `nil` is what the panel already renders as "total
        // unavailable".
        totalMatchCount ?? Self.facetTotal(fetched: results.count, cap: lastFetchLimit)
    }

    /// The rule behind ``totalMatchCountForFacets``, extracted so it can be tested at the
    /// boundary.
    ///
    /// It has to be: a test that only exercises an empty result set cannot distinguish
    /// "return the fetched count" from "return nil at the cap" — both give 0 — and a
    /// mutation replacing the whole rule with `fetched` passed on exactly that basis.
    /// Reaching the real cap in a test would need a thousand-document fixture.
    static func facetTotal(fetched: Int, cap: Int) -> Int? {
        fetched >= cap ? nil : fetched
    }

    /// Applies a facet narrowing (R-1c).
    ///
    /// iOS holds filter state as individual fields rather than macOS's single
    /// `SearchParameters`, so `FacetNarrowing.apply(to:)` cannot be shared — the fields are
    /// this view model's own. What *is* shared is the destination: every case writes a field
    /// the filter sheet also owns, so a facet and the sheet can never disagree, which is the
    /// property the design asks for.
    func applyFacetNarrowing(_ narrowing: FacetNarrowing) {
        switch narrowing {
        case .year(let year):
            guard let start = Self.date(fromISO: "\(year)-01-01"),
                  let end = Self.date(fromISO: "\(year)-12-31") else { return }
            dateRangeEnabled = true
            dateRangeStart = start
            dateRangeEnd = end
        case .volume(let volumeId):
            // Replace rather than add: the facet's count is for that volume alone, so
            // unioning would return more documents than the row promised.
            selectedVolumeIds = [volumeId]
            selectedSubseriesIds = []
        case .person(let rollupId, let label):
            personRollupId = rollupId
            // #1092: carry the tapped bucket's display name, or the chip reads "person #N".
            personLabel = label
            // Drop any anchor from a previous person: it names someone else, and leaving it would
            // make the next rebind silently re-point this filter back at them.
            personAnchor = nil
            // A rollup and a typed ref are alternative spellings of one filter; leaving the
            // text set would AND them and silently undercount.
            personRefText = ""
        case .documentType(let filter):
            documentTypeFilter = filter
        case .subject(let bucket):
            // Replace rather than union, for the reason `.volume` gives: the row's count is for
            // that bucket alone.
            subjectBucket = bucket
            subjectBucketKey = DocumentSubjectStore.shared?.bucketVocabulary.key(at: bucket)
        }
        // No version bump: unlike macOS, this view model has no `parametersVersion` and iOS
        // re-runs the search explicitly. The caller owns that — see `SearchView`.
    }

    /// Applies a staged facet selection (#775), routed through the one shared applier.
    ///
    /// iOS holds its filters as individual fields rather than a `SearchParameters`, so this
    /// round-trips through a value: build the parameters, let `FacetSelectionApplier` write the
    /// change, read the result back. That is a little indirect and it is the point — the
    /// single-tap path has two appliers, one per platform, and they have already drifted.
    func applyFacetSelection(_ section: FacetSection, keys: [String]?) {
        var parameters = searchParameters
        FacetSelectionApplier.apply(section, keys: keys, to: &parameters)
        switch section {
        case .years:
            facetYearKeys = parameters.yearKeys
        case .volumes:
            // A subseries selection is a different way of naming volumes and would widen the gate
            // back out — the same reason the single-tap path clears it.
            selectedVolumeIds = parameters.volumeIds ?? []
            selectedSubseriesIds = []
        case .people, .documentType, .provenance, .subjects:
            break
        }
    }

    /// Captures or re-resolves the person filter's durable anchor against the live rollup (#747).
    ///
    /// Call after applying a person filter and again on every `AppState.personRollupGeneration`
    /// change: the rollup table is renumbered from 1 on every rebuild, so an id captured before a
    /// merge points at whoever now occupies that slot. Sets ``droppedPersonFilterNotice`` when the
    /// anchor no longer resolves, so the view can tell the user rather than quietly returning a
    /// wider result set.
    ///
    /// - Returns: `true` if the caller should re-run the search (the filter changed).
    @discardableResult
    func refreshPersonRollupBinding(using store: PersonMentionStore?) async -> Bool {
        let before = PersonFilterBinding(rollupId: personRollupId,
                                         label: personLabel,
                                         anchor: personAnchor)
        let (after, dropped) = await PersonRollupRefresh.rebind(before, using: store)
        guard after != before else { return false }
        personRollupId = after.rollupId
        personLabel = after.label
        personAnchor = after.anchor
        if dropped {
            droppedPersonFilterNotice = String(
                localized: "search.person.filterDropped",
                defaultValue: "The person filter was cleared — \(before.label ?? "that person") is no longer in the indexed corpus.")
        }
        // A pure anchor capture changes no filter, so it must not cost the user a re-run.
        return dropped || after.rollupId != before.rollupId
    }

    /// Parses a `yyyy-MM-dd` string into a `Date`, for the year-facet narrowing.
    private static func date(fromISO iso: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: iso)
    }

    /// The narrowings currently in force, as clearable summaries (R-1c).
    ///
    /// iOS has never had an active-filter row — only a filled filter glyph, which says
    /// *that* something is filtered but not what, and offers no way back. That gap is
    /// tolerable when every filter was set in a sheet the user just closed; it is not
    /// tolerable once a single tap in a facet list can narrow the result set, because then
    /// the narrowing is the interaction and it needs to be legible and reversible.
    ///
    /// Derived from the live fields rather than remembered from the tap, so it cannot drift
    /// from what is actually filtering, and so it also covers filters set in the sheet.
    var activeNarrowings: [ActiveNarrowing] {
        var out: [ActiveNarrowing] = []
        if dateRangeEnabled {
            out.append(ActiveNarrowing(
                id: "date",
                label: String(localized: "search.narrowing.date",
                              defaultValue: "\(Self.isoDate(dateRangeStart)) to \(Self.isoDate(dateRangeEnd))")))
        }
        if let years = facetYearKeys {
            out.append(ActiveNarrowing(
                id: "years",
                // Named, not counted, up to three: "1951, 1953" is the whole point of #775 and a
                // chip reading "2 years" would hide which two. Beyond three the list is longer
                // than the chip, so it degrades to a count.
                label: years.isEmpty
                    ? String(localized: "search.narrowing.years.none",
                             defaultValue: "No years")
                    : years.count <= 3
                    ? years.sorted().joined(separator: ", ")
                    : String(format: String(localized: "search.narrowing.years %lld",
                                            defaultValue: "%lld years"),
                             Int64(years.count))))
        }
        if !selectedVolumeIds.isEmpty {
            out.append(ActiveNarrowing(
                id: "volume",
                label: selectedVolumeIds.count == 1
                    ? selectedVolumeIds[0]
                    : String(localized: "search.narrowing.volumes",
                             defaultValue: "\(selectedVolumeIds.count) volumes")))
        }
        if !selectedSubseriesIds.isEmpty {
            out.append(ActiveNarrowing(
                id: "subseries",
                label: String(localized: "search.narrowing.subseries",
                              defaultValue: "\(selectedSubseriesIds.count) subseries")))
        }
        if let personRollupId {
            // #1092: prefer the stored display name — the slot number is meaningless to a
            // reader and is renumbered on every rollup rebuild (#747). The numeric fallback
            // survives only for a filter restored without its label.
            out.append(ActiveNarrowing(
                id: "person",
                label: personLabel
                    ?? String(localized: "search.narrowing.person",
                              defaultValue: "person #\(personRollupId)")))
        }
        if !selectedUserTagIds.isEmpty {
            // `Set<UUID>`, not an array — so no index subscript, and a stable label needs a
            // deterministic pick rather than whatever the set iterates first.
            let onlyName = selectedUserTagIds.count == 1
                ? selectedUserTagIds.first.flatMap { id in
                    availableUserTags.first { $0.id == id }?.name }
                : nil
            out.append(ActiveNarrowing(
                id: "tag",
                label: onlyName
                    ?? (selectedUserTagIds.count == 1
                        ? String(localized: "search.narrowing.tag.one", defaultValue: "1 tag")
                        : String(localized: "search.narrowing.tags",
                                 defaultValue: "\(selectedUserTagIds.count) tags"))))
        }
        if documentTypeFilter != .all {
            out.append(ActiveNarrowing(
                id: "type",
                label: documentTypeFilter == .editorialNotesOnly
                    ? String(localized: "search.narrowing.notes", defaultValue: "Editorial notes")
                    : String(localized: "search.narrowing.documents", defaultValue: "Documents")))
        }
        if let bucket = subjectBucketKey
            .flatMap({ DocumentSubjectStore.shared?.bucketVocabulary.id(forKey: $0) }) ?? subjectBucket {
            // Named from the vocabulary, not from the tap: this list is derived from live fields
            // precisely so it cannot describe a filter that is no longer the one applied. A bucket
            // the vocabulary cannot name still gets a chip — a filter with no way back is the one
            // failure this whole list exists to prevent.
            out.append(ActiveNarrowing(
                id: "subject",
                label: DocumentSubjectStore.shared?.bucketVocabulary.label(at: bucket)
                    ?? String(localized: "search.narrowing.subject.unknown",
                              defaultValue: "Subject filter")))
        }
        // The subject chip, separate from the bucket one above: they are different grains and a
        // reader can hold both at once (a bucket from the facet, a subject from the explorer).
        // Named from the STORED name rather than re-resolved, because after an upstream re-mint the
        // ref no longer resolves and a chip that vanished would be a filter with no way back — the
        // one failure this list exists to prevent.
        if subjectRef != nil {
            out.append(ActiveNarrowing(
                id: "subjectRef",
                label: subjectName ?? String(localized: "search.narrowing.subjectRef.unknown",
                                             defaultValue: "Topic filter")))
        }
        return out
    }

    /// Clears one active narrowing by its identifier.
    func clearNarrowing(_ id: String) {
        switch id {
        case "date": dateRangeEnabled = false
        case "years": facetYearKeys = nil
        case "volume": selectedVolumeIds = []
        case "subseries": selectedSubseriesIds = []
        case "person": personRollupId = nil; personRefText = ""; personAnchor = nil
        case "type": documentTypeFilter = .all
        case "tag": selectedUserTagIds = []
        case "subject": subjectBucket = nil; subjectBucketKey = nil
        case "subjectRef": subjectRef = nil; subjectName = nil
        default: return
        }
        // Caller re-runs the search, matching this view model's existing convention.
    }

    var hasActiveFilters: Bool {
        if documentTypeFilter != .all { return true }
        if personRollupId != nil { return true }
        if !personRefText.trimmingCharacters(in: .whitespaces).isEmpty { return true }
        if dateRangeEnabled { return true }
        // `nil` is no filter; an EMPTY array is a real filter that matches nothing, so this tests
        // for presence rather than for non-emptiness.
        if facetYearKeys != nil { return true }
        // #308's facet-panel narrowing. Like `facetYearKeys` it is set by a tap rather than in the
        // sheet, which is precisely why it has to be reported: nothing else on screen would.
        if subjectBucket != nil { return true }
        if subjectRef != nil { return true }
        if !selectedVolumeIds.isEmpty { return true }
        if !selectedSubseriesIds.isEmpty { return true }
        if !selectedUserTagIds.isEmpty { return true }
        if !excludedTermsText.isEmpty { return true }
        if !phrase.isEmpty { return true }
        if !prefixWildcard.isEmpty { return true }
        if !includeDocumentText || !includeSummaries || !includeNotes { return true }
        if !includeFrontMatter { return true }
        if projectScope != .off { return true }
        // An applied working corpus gates every row, so the filter glyph must say so. It was
        // missing here because a corpus is applied through its own field rather than through the
        // volume-checkbox field a custom volume scope writes — so it inherited none of the filter
        // vocabulary that field carries for free.
        if appliedWorkingCorpusKeys != nil { return true }
        switch booleanMode {
        case .or: return true
        case .and: return false
        }
    }

    func makeEntry(from result: SearchResult) -> DocumentBrowserEntry {
        DocumentBrowserEntry(
            documentId: result.documentId,
            volumeId: result.volumeId,
            documentNumber: result.documentNumber,
            header: result.header,
            dateline: result.dateline,
            sourceNote: result.sourceNote,
            isEditorialNote: result.isEditorialNote
        )
    }

    // MARK: - Parameter Application (used by pendingSearch)

    /// Applies a `SearchParameters` snapshot to all filter fields.
    /// Called by `SearchView` when presented with pre-filled parameters via
    /// `AppState.pendingSearch`.
    func applyParameters(_ params: SearchParameters) {
        // Every hand-off and saved-search recall leaves a held base (#1577 lane 4, rule 3): the base it
        // would otherwise run inside is no part of what it hands over.
        leaveBaseForHandoff()
        keywords          = params.keywords ?? ""
        phrase            = params.phrase ?? ""
        prefixWildcard    = params.prefixWildcard ?? ""
        booleanMode       = params.booleanMode
        excludedTermsText = params.excludedTerms.joined(separator: ", ")
        personRefText     = params.personRef ?? ""
        personRollupId    = params.personRollupId
        personLabel       = params.personLabel
        personAnchor      = params.personAnchor
        // #775: restore the year set. `nil` is a real value here (no year filter), so this
        // assigns unconditionally rather than guarding on non-nil — a guard would leave a
        // previous search's years in force under a restored search that has none.
        facetYearKeys = params.yearKeys
        if let range = params.dateRange {
            dateRangeEnabled = true
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withFullDate]
            if let earliest = range.earliest { dateRangeStart = fmt.date(from: earliest) ?? dateRangeStart }
            if let latest   = range.latest   { dateRangeEnd   = fmt.date(from: latest)   ?? dateRangeEnd }
        } else {
            dateRangeEnabled = false
        }
        // params.subjectTagIds is intentionally dropped (inert since Session 09) —
        // restoring it would fake an "active filter" for a constraint that does nothing.
        selectedUserTagIds    = Set(params.userTagIds.compactMap { UUID(uuidString: $0) })
        let scope = Self.reconstructScope(from: params.volumeIds ?? [], available: availableVolumes)
        selectedSubseriesIds  = scope.subseries
        selectedVolumeIds     = scope.volumes
        includeDocumentText   = params.includeDocumentText
        includeSummaries      = params.includeSummaries
        includeNotes          = params.includeNotes
        includeFrontMatter    = params.includeFrontMatter
        documentTypeFilter    = params.documentTypeFilter
        // ASSIGNED UNCONDITIONALLY, never `if let`. A recalled search that omits it must CLEAR any
        // bucket the previous search left in force — this view model's fields outlive one search,
        // so a conditional assignment would leak a stale subject filter into every hand-off.
        subjectBucket         = params.subjectBucket
        subjectBucketKey      = params.subjectBucketKey
        // Unconditional for the same reason, and this pair is why a hand-off used to die on iOS
        // and live on macOS: `MacSearchViewModel.applyParameters` assigns the whole
        // `SearchParameters`, while this one copies named fields — so a field added there and not
        // here is dropped between `consumePendingSearch` and `search()`, which re-derives from
        // these very fields. The reader got "Enter a keyword, phrase, or prefix to search" from a
        // door that had just handed over a perfectly good subject (#1023).
        subjectRef            = params.subjectRef
        subjectName           = params.subjectName
        // Project History scope is a live, manual choice — never inherited from a restored
        // snapshot or a pending-search hand-off (Analytics drill-in, "Find all mentions",
        // indexing banners). Without this reset a History scope selected earlier in the
        // session would silently keep gating unrelated hand-off searches (#377 Phase 2a).
        // `params.documentIds` is deliberately dropped: `searchParameters` re-derives
        // `documentIds` from `projectScope`, so clearing the scope fully clears the gate.
        projectScope          = .off
        projectOnlyNew        = false
    }

    // MARK: - Scope Reconstruction

    /// Splits a flat `volumeIds` scope back into a subseries selection plus a set of
    /// individually-selected volumes, so a scope round-tripped through
    /// `SearchParameters` (the analytics drill-in, a `SavedSearch`, or a pending
    /// handoff) repopulates the two pickers faithfully.
    ///
    /// A subseries is treated as "selected as a whole" only when *every* one of its
    /// indexed volumes appears in `volumeIds`; those volumes are then removed from the
    /// individual set. Volumes belonging to a partially-covered subseries remain
    /// individual selections. When `available` is empty (manifest not yet loaded) every
    /// id is returned as an individual selection — the effective scope is identical,
    /// only the picker labelling differs.
    ///
    /// Shared by `applyParameters(_:)` here and `MacSearchViewModel.syncToFilterVM`.
    static func reconstructScope(
        from volumeIds: [String],
        available: [VolumeManifestEntry]
    ) -> (subseries: Set<String>, volumes: [String]) {
        guard !volumeIds.isEmpty, !available.isEmpty else { return ([], volumeIds) }
        let idSet = Set(volumeIds)
        let bySubseries = Dictionary(grouping: available, by: { $0.subseries })
        var subseries: Set<String> = []
        var consumed: Set<String> = []
        for (sub, entries) in bySubseries {
            let subVolumeIds = Set(entries.map(\.volumeId))
            if !subVolumeIds.isEmpty, subVolumeIds.isSubset(of: idSet) {
                subseries.insert(sub)
                consumed.formUnion(subVolumeIds)
            }
        }
        let individual = volumeIds.filter { !consumed.contains($0) }
        return (subseries, individual)
    }

    // MARK: - Private Helpers

    private static func isoDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: date)
    }
}
