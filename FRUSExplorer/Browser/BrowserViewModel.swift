// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Observation

// MARK: - BrowserViewModel

/// Manages navigation state and data loading for the hierarchical Browser view.
///
/// ## Navigation Hierarchy
/// Corpus → Subseries → Volume → Compilation/Chapter → Document (Session 12)
///
/// `BrowserViewModel` holds the current navigation path as a `[BrowserLevel]`
/// stack. Each level type carries the data needed to render that level without
/// re-querying the manifest.
///
/// ## Tag Filtering
/// Subseries-level tag filtering is stored per-subseries in `tagFilters`. When the
/// user taps a tag chip at the Volume level, `activateTagFilter(slug:forSubseries:)`
/// updates the appropriate filter entry and pops navigation back to the Subseries
/// level.
///
/// ## Volume Structure
/// `VolumeStructure` values are loaded lazily when the user navigates to the Volume
/// level and cached in `volumeStructures`. Loading is gated on volume download state
/// (undownloaded volumes show a "Download required" state).
///
/// ## Document Cache
/// `DocumentBrowserEntry` lists are loaded lazily from `IndexingPipeline.documents(forVolume:)`
/// and cached in `compilationDocuments`, with each section's progress recorded in
/// `documentLoadStates` (#1301). An unindexed volume shows an "Index required" prompt with an
/// "Index Now" action.
///
/// Version history:
///   1.0 — Session 11: initial implementation
///   1.1 — Session 50: filterDownloadedOnly — gates allSubseriesGroups and filteredVolumes
///   1.2 — Session 68: `indexingProgress` published during `indexVolume` via a concurrent
///          `progressStream` observer; `isIndexing` false-transition signals CompilationView
///          to auto-reload the document list without requiring navigation away
///   1.3 — Session 87: `BrowserLevel.people` case for person index navigation
///   1.4 — Wave R / R-9: `indexingPipeline` is back-filled the same way `downloadManager`
///          has been since #324 (`private(set) var` + `attachIndexingPipelineIfNeeded`),
///          because capturing it once at `.onAppear` could capture `nil` and make every
///          compilation claim "Index Required" for the whole session; `indexVolume`'s
///          nil-pipeline guard now records `BrowserIndexingError.pipelineUnavailable`
///          instead of returning silently
///   1.5 — #1051 B-1: three new levels for the browse-axes program — `.subseriesIndex`
///          (the era directory the 2a root moves one tap deep), `.catalogue` (the 1e
///          All Volumes catalogue), and `.volumeList(VolumeListSpec)` (the R-1 shared
///          cross-subseries volume list every axis drills into). `corpusStats` removed
///          (display left in Session 130; its document sum read the dead manifest field).
///          `activateTagFilter` gains the Q-5 fallback: with no `.subseries` ancestor on
///          the path it PUSHES the subseries level with the filter applied, instead of
///          silently setting latent state (the axis-list route to `VolumeView`).
///   1.6 — #1301: `isLoadingDocuments`, one app-wide `Bool` read in exactly one place, is replaced
///          by `documentLoadStates` — notStarted / loading / loaded / failed(Error) PER SECTION
///          KEY. `loadDocuments` records every outcome, including the two it used to decline
///          silently, and short-circuits only on `.loaded`, so the error row's Retry and the
///          `.onChange` kicks both work by calling it again. The render rule moved out to
///          `CompilationDocumentsPresentation`, where it can be tested.
///   1.7 — #1301 round 2: `compilationKey` forwards to `BrowseLoadKey.compilation`, so the load
///          task's id and the cache it writes into have ONE definition; `retryAction(for:)` makes
///          the failure row's button a value carrying the key it will ask for (a retry pointed at
///          a neighbouring section passed every test); and the nil-pipeline comment no longer
///          implies a view can reach that branch — no caller can, and two comments in round 1
///          said otherwise
///   1.8 — #1301 round 4: that comment's reason is corrected for kick 1, which is gated on an
///          `isIndexing` edge rather than on `isIndexed(_:)`; `indexVolume(_:)` cannot produce the
///          edge without a pipeline, so the conclusion stands. Comment only
///   1.9 — #1365: `topicIndex` holds the Topic index's state for every index Browse mounts, and
///          `openTopicIndex()` is the Topics row's entry, which resets it to the whole index
///   1.10 — #1363: the per-level memory — `LevelMemory` by path position in `levelMemorySlots`,
///          read with `memory(for:)`, written only by the level on screen through
///          `updateMemory(for:_:)`, pruned by `navigationPath`'s observer and emptied by `select(_:)`
///          — holds the Archives lens, closed eras and groups and collection search, and the All
///          Volumes and Editors searches, so the iPad two-pane's Back and its gate crossing return
///          the reader to what they set
///   1.11 — #1363 review round 1: the memory also holds a collection's expanded lists
///          (`LevelMemory.collectionDetail`, keyed on `.archivalCollection`'s position), and the
///          root's search is `rootSearch`, which no path change or `select(_:)` empties
///   1.12 — #1363, on merging #1364: `LevelMemory`'s doc says why the browse-within filter is
///          `AppState`'s and not a level's memory. Comment only
@Observable
@MainActor
public final class BrowserViewModel {

    // MARK: - Navigation Level

    /// One level in the browser navigation stack.
    public enum BrowserLevel: Hashable {
        case corpus
        case subseries(SubseriesGroup)
        case volume(VolumeManifestEntry)
        case compilation(volumeId: String, section: VolumeSection)
        case document(DocumentBrowserEntry)
        case people
        /// The detected-topic index (#1023) — the subject-grain sibling of `people`.
        case subjects
        /// The subseries directory (#1051 B-1) — the era hierarchy the 2a root moves
        /// behind its double-width tile. Payload-less, like `.people`/`.subjects`.
        case subseriesIndex
        /// The All Volumes catalogue (#1051 A-1/A-2) — all 553 volumes under one
        /// searchable level with Title / Published / Era / Length presentations.
        case catalogue
        /// An arbitrary ordered cross-subseries volume list (#1051 R-1) — the shared
        /// destination every browse axis drills into. Identity is the spec's `axisKey`,
        /// never the id array, so a recomputed set under the same axis compares equal.
        case volumeList(VolumeListSpec)
        /// The Administrations index (#1051 A-3) — presidencies drilling to the volumes
        /// whose documents cover each term.
        case administrations
        /// The Editors index (#1051 A-4) — volume editors (compilers, per Q-1) drilling
        /// to the volumes naming them.
        case editors
        /// The My Scopes level (#1051 A-5) — the user's custom volume scopes.
        case scopes
        /// The in-Browse scope editor (#1051 design 3a), keyed by the scope's id.
        case scopeEditor(UUID)
        /// The Working Corpora level (#1051 A-6) — the user's captured document sets.
        case corpora
        /// One corpus's document drill (#1051 R-3). Identity is the corpus id; the name
        /// rides along for the breadcrumb.
        case corpusDocuments(id: UUID, name: String)
        /// The Archives axis (#1051 A-9) — provenance types and archival collections,
        /// as SIBLING lenses.
        case archives
        /// One archival collection's pushed detail (#1051 B-5). Identity is the
        /// authority record's stable string id; the name rides along for the breadcrumb.
        case archivalCollection(id: String, name: String)
        /// The Semantic Clusters index (#1051 B-7, A-8).
        case clusters
        /// One cluster's document drill (#1051 B-7, R-3). Identity is the ARTIFACT's
        /// cluster id — in-memory navigation only, never persisted (ids re-mint per
        /// artifact generation); the label rides along for the breadcrumb.
        case clusterDocuments(id: Int, label: String)

        public func hash(into hasher: inout Hasher) {
            switch self {
            case .corpus:              hasher.combine(0)
            case .subseries(let g):    hasher.combine(1); hasher.combine(g.subseries)
            case .volume(let v):       hasher.combine(2); hasher.combine(v.volumeId)
            case .compilation(let vid, let s):
                hasher.combine(3); hasher.combine(vid); hasher.combine(s.sectionId)
            case .document(let e):     hasher.combine(4); hasher.combine(e.documentId)
            case .people:              hasher.combine(5)
            case .subjects:            hasher.combine(6)
            case .subseriesIndex:      hasher.combine(7)
            case .catalogue:           hasher.combine(8)
            case .volumeList(let s):   hasher.combine(9); hasher.combine(s.axisKey)
            case .administrations:     hasher.combine(10)
            case .editors:             hasher.combine(11)
            case .scopes:              hasher.combine(12)
            case .scopeEditor(let id): hasher.combine(13); hasher.combine(id)
            case .corpora:             hasher.combine(14)
            case .corpusDocuments(let id, _): hasher.combine(15); hasher.combine(id)
            case .archives:            hasher.combine(16)
            case .archivalCollection(let id, _): hasher.combine(17); hasher.combine(id)
            case .clusters:            hasher.combine(18)
            case .clusterDocuments(let id, _): hasher.combine(19); hasher.combine(id)
            }
        }

        public static func == (lhs: BrowserLevel, rhs: BrowserLevel) -> Bool {
            switch (lhs, rhs) {
            case (.corpus, .corpus): return true
            case (.subseries(let a), .subseries(let b)): return a.subseries == b.subseries
            case (.volume(let a), .volume(let b)): return a.volumeId == b.volumeId
            case (.compilation(let v1, let s1), .compilation(let v2, let s2)):
                return v1 == v2 && s1.sectionId == s2.sectionId
            case (.document(let a), .document(let b)): return a.documentId == b.documentId
            case (.people, .people): return true
            case (.subjects, .subjects): return true
            case (.subseriesIndex, .subseriesIndex): return true
            case (.catalogue, .catalogue): return true
            case (.volumeList(let a), .volumeList(let b)): return a.axisKey == b.axisKey
            case (.administrations, .administrations): return true
            case (.editors, .editors): return true
            case (.scopes, .scopes): return true
            case (.scopeEditor(let a), .scopeEditor(let b)): return a == b
            case (.corpora, .corpora): return true
            case (.corpusDocuments(let a, _), .corpusDocuments(let b, _)): return a == b
            case (.archives, .archives): return true
            case (.archivalCollection(let a, _), .archivalCollection(let b, _)): return a == b
            case (.clusters, .clusters): return true
            case (.clusterDocuments(let a, _), .clusterDocuments(let b, _)): return a == b
            default: return false
            }
        }
    }

    // MARK: - Navigation State

    /// Current navigation stack. The last element is the displayed level.
    ///
    /// **Every change drops the memory of the positions it did not leave in place** (#1363): a
    /// position keeps its ``levelMemorySlots`` entry only while every level up to and including it
    /// is unchanged. That is done here rather than at the call sites because the path is written
    /// from all over Browse — appends, `removeLast()`, the breadcrumb's truncation, a page turn's
    /// `.replace`, `activateTagFilter`'s pop, and `stackLayout`'s binding assigning the whole array
    /// on a pop — and a site that forgot would leave a memory behind for whatever level next took
    /// that position.
    public var navigationPath: [BrowserLevel] = [] {
        didSet {
            let unchanged = zip(oldValue, navigationPath).prefix(while: { $0 == $1 }).count
            levelMemorySlots = levelMemorySlots.filter { $0.key < unchanged }
        }
    }

    /// Selects a level from the **corpus root**, replacing the path rather than extending it
    /// (UI review F-2).
    ///
    /// ## Why this is an assignment and not an append
    /// `CorpusView` is the stack root on iPhone, where the path is always empty when its rows are
    /// tapped — so `= [level]` and `.append(level)` are the same operation there, and this change
    /// is provably a no-op on that platform. Three facts make that provable rather than likely:
    /// nothing anywhere appends `.corpus`, the breadcrumb only ever *truncates*
    /// (`prefix(index + 1)`), and `levelView`'s `case .corpus` is unreachable.
    ///
    /// At regular width on iPad, `CorpusView` is a **persistent list pane** beside a detail pane.
    /// There the difference is the whole behaviour: appending would stack a newly chosen subseries
    /// on top of whatever document is open in the detail, so Back would walk through an unrelated
    /// reading history. Replacing is what makes a list pane a list pane.
    ///
    /// The dead `SubseriesListView` — written for the split layout #238 reverted — already used
    /// the assignment form. It was right about this and is the reason the semantics were not
    /// guessed at.
    ///
    /// ## It forgets every level's memory (#1363)
    /// A choice from the root opens its level afresh, as the phone's stack opens it: there the path
    /// is empty when a root row is tapped, so every level starts new. The prune in
    /// `navigationPath`'s observer is not enough on its own, because it keeps a position whose level
    /// is unchanged — and the two-pane's list pane can be tapped beside the level it opens, which
    /// assigns an EQUAL path and keeps the same view on screen. Emptying ``levelMemorySlots`` here is
    /// what redraws that view as new.
    ///
    /// **It does not touch ``topicIndex``.** A hand-off posts into it and THEN selects `.subjects`
    /// (`BrowserView.consumePendingSubjectExplorer()`), so a reset here would drop what was posted;
    /// the Topics row resets it through ``openTopicIndex()``.
    ///
    /// **Nor ``rootSearch``,** which is the root's and not a level's: a volume chosen from the root's
    /// search comes through here, and the phone's stack keeps that search under the volume.
    ///
    /// - Parameter level: The level the reader chose from the root list.
    public func select(_ level: BrowserLevel) {
        navigationPath = [level]
        levelMemorySlots = [:]
    }

    // MARK: - Topic Index (#1365)

    /// The Topic index's state — the hand-off waiting to land, and the reader's search, topic-area
    /// chip and open sheet — held HERE rather than in `SubjectIndexView`, which is bound to it.
    ///
    /// The two-pane mounts a new index for a reader who never left theirs: Back from a covering
    /// volume opened out of a topic's sheet (`navigationPath.removeLast()` re-renders the detail
    /// pane), and a layout change across the two-pane gate. This model outlives both, so the new
    /// index shows the area and search the reader left — what the single-column stack, which keeps
    /// the index alive underneath, always did. `SubjectIndexGrouping.HostState` has the rule.
    var topicIndex = SubjectIndexGrouping.HostState()

    /// The corpus root's Topics row: the whole index, whatever the last visit or hand-off left.
    ///
    /// **It resets `topicIndex` because it is not a hand-off.** Nothing is posted, so without the
    /// reset the index would show whatever the host still holds — the area the last "All «area»
    /// topics" door landed, or a search typed an hour ago. It also resets when `.subjects` is
    /// ALREADY the level on screen, which only the iPad two-pane allows (its list pane stays beside
    /// the index): the path assignment below is then equal and the same index view stays, so the
    /// reset is the only thing that tells it to show the whole index.
    ///
    /// A hand-off goes through `BrowserView.consumePendingSubjectExplorer()` instead, which posts
    /// its request and calls `select(.subjects)` — never this, which would drop what it posted.
    func openTopicIndex() {
        topicIndex.openWhole()
        select(.subjects)
    }

    // MARK: - Per-Level Memory (#1363)

    /// What the reader set on one Browse level, held here so that it outlives the level's view for
    /// exactly as long as the level is on the path (#1363).
    ///
    /// ## Why here and not in the level's view
    /// The iPad two-pane draws only the path's last level (`BrowserView.detailPane`), so a level
    /// pushed above another takes the lower one's view out of the hierarchy, and Back builds a new
    /// one. Crossing the two-pane gate — a rotation, a Stage Manager resize — swaps `twoPaneLayout`
    /// for `stackLayout` or back, which mounts every level on the path again. `@State` died with each
    /// of those views: Back from a collection brought Archives back on Provenance Types with its
    /// search gone. A navigation stack keeps the levels beneath its top alive, and this keeps their
    /// state alive the same way: while the level is on the path, and no longer (see
    /// ``navigationPath`` and ``select(_:)`` for when it goes).
    ///
    /// ## Why not the two other ways
    /// - `.id(level)` on the detail pane rebuilds a level view on every change of level, which the
    ///   #1301 reuse contract at `BrowserView.levelView` rules out; it would also reload a document on
    ///   every page turn.
    /// - Keeping the lower levels mounted and hidden: a hidden level still adds its `.toolbar` items
    ///   and its title to the one bar both panes share.
    ///
    /// ## What is here, and what is not
    /// One field per level that has something to keep; every slot carries all of them and its level
    /// reads its own. Choices that hold for every visit — the catalogue's arrangement, the
    /// collection list's grouping and sort, the class sort — are `@AppStorage` in their views and do
    /// not belong here. The Topic index keeps its own host state, ``topicIndex``, because a hand-off
    /// posts into it BEFORE `.subjects` is on the path, and then puts it there with ``select(_:)``,
    /// which empties this memory. The root is not a level on the path, so its search is
    /// ``rootSearch``, beside this rather than in it. Nor is the browse-within filter here
    /// (`AppState.browseScopeFilterId`, #1364): it holds until the reader clears it, across launches,
    /// for the root's Subseries tile, the subseries list and a subseries alike, and Browse Within
    /// sets it and THEN calls ``select(_:)`` — so a filter kept in this memory would be emptied by the
    /// call that opens the list it narrows.
    ///
    /// **Not kept, and so still lost on the two-pane's Back:** where a level was scrolled to (a
    /// rebuilt `List` starts at the top), and which collection rows the reader opened to show their
    /// sub-series (`CollectionBrowserView`'s disclosure keeps its own state). A collection's detail
    /// also loads its figures again, which is not the reader's setting but its data.
    struct LevelMemory: Equatable {
        /// `.archives`: the lens, the closed eras and collection groups, and the collection search.
        var archives = ArchivesIndexView.ReaderState()
        /// `.catalogue`: the All Volumes search.
        var catalogueSearch = ""
        /// `.editors`: the Editors index's search.
        var editorsSearch = ""
        /// `.archivalCollection`: which of the detail's lists the reader expanded past their preview
        /// — the one they may have opened a citing volume from.
        var collectionDetail = CollectionDetailView.Expansions()
    }

    /// The Browse root's volume search (#1363 review round 1): what `CorpusView` shows in its
    /// field, held here for as long as this view model lives.
    ///
    /// **Not a slot of ``levelMemorySlots``, because the root is not on the path.** It is under
    /// every path, and the phone's stack never takes it down: a search there survives a result
    /// chosen from it — `select(_:)` — and every level pushed above it. The iPad two-pane does take
    /// the root down: its list pane gives way to a document on a window under
    /// `BrowseTwoPaneMetrics.documentMinimumWidth`, and crossing the two-pane gate mounts the other
    /// layout's root. So nothing here empties it — not a path change, not ``select(_:)`` — and only
    /// the reader does, from the field.
    var rootSearch = ""

    /// The memory of the levels on the path, by POSITION — `navigationPath`'s index.
    ///
    /// Written only through ``updateMemory(for:_:)``; pruned by ``navigationPath``'s observer to the
    /// positions a change left in place, and emptied by ``select(_:)``. So a position's entry always
    /// belongs to the level that sits there.
    private(set) var levelMemorySlots: [Int: LevelMemory] = [:]

    /// The memory of `level` where it sits on the path, or an empty memory when it has none.
    ///
    /// **The position is the LAST one `level` holds**, because a level view is given its level and
    /// not its index — `stackLayout`'s `navigationDestination` passes the value alone. For the level
    /// on screen that is exact, since it is the path's last element. A level lower in a stack that
    /// also sat above itself would read the upper one's memory while covered, and its own again once
    /// the upper one was popped. No level that keeps a memory can be on a path twice today:
    /// `.archives`, `.catalogue` and `.editors` are reached only through ``select(_:)``, and
    /// `.archivalCollection` is appended only by Archives' collection rows, directly above
    /// `.archives` — a related collection inside a collection's detail is a `NavigationLink`, which
    /// does not touch the path.
    ///
    /// - Parameter level: The level whose memory to read.
    /// - Returns: Its memory.
    func memory(for level: BrowserLevel) -> LevelMemory {
        guard let position = navigationPath.lastIndex(of: level) else { return LevelMemory() }
        return levelMemorySlots[position] ?? LevelMemory()
    }

    /// Changes the memory of `level` — only while `level` is the one on screen, the path's last.
    ///
    /// **A level under a push, or off the path, writes nothing.** In the two-pane a level under a
    /// push is out of the hierarchy, so anything its view writes as it is torn down would replace the
    /// memory Back reads; a stack keeps such a level alive but covered, where the reader cannot
    /// change it. The empty path has no level on screen and takes nothing either.
    ///
    /// A write that leaves the memory as it was stores nothing, so a binding that sets the value it
    /// already holds does not tell observers the memory changed.
    ///
    /// - Parameters:
    ///   - level: The level whose memory to change.
    ///   - change: The change.
    func updateMemory(for level: BrowserLevel, _ change: (inout LevelMemory) -> Void) {
        guard navigationPath.last == level else { return }
        let position = navigationPath.count - 1
        let current = levelMemorySlots[position] ?? LevelMemory()
        var memory = current
        change(&memory)
        guard memory != current else { return }
        levelMemorySlots[position] = memory
    }

    // MARK: - Download Filter

    /// When `true`, `allSubseriesGroups` and `filteredVolumes` exclude volumes (and
    /// subseries) that have not been downloaded to the device.
    ///
    /// Synced from `AppState.filterDownloadedOnly` via a `BrowserView.onChange` observer
    /// so it stays in step with the persisted user preference.
    public var filterDownloadedOnly: Bool = false

    // MARK: - Tag Filters (keyed by subseries string)

    /// Active tag-slug filters per subseries. Empty set = no filter.
    public var tagFilters: [String: Set<String>] = [:]

    /// Tag search text for the picker inside a subseries view.
    public var tagSearchText: String = ""

    // MARK: - Volume Loading State

    /// Parsed volume structures, keyed by volumeId. Populated lazily.
    public var volumeStructures: [String: VolumeStructure] = [:]

    /// `true` while a `parseVolumeStructure` call is in flight.
    public var isLoadingStructure: Bool = false

    /// Non-nil if the most recent `parseVolumeStructure` call failed.
    public var structureError: Error? = nil

    // MARK: - Compilation Documents

    /// Documents in a compiled section, keyed by `"volumeId/sectionId"`.
    public var compilationDocuments: [String: [DocumentBrowserEntry]] = [:]

    /// How far each section's document load has got, keyed the same way as
    /// ``compilationDocuments`` (#1301).
    ///
    /// **Per section, and that is the whole point.** The flag this replaced,
    /// `isLoadingDocuments`, was one `Bool` for the whole app, read in exactly one place, and it
    /// could not say anything about the section on screen. `CompilationView` therefore drew its
    /// spinner on `isLoadingDocuments || compilationDocuments[key] == nil` — a disjunction whose
    /// second operand is the ABSENCE of a result, which no amount of waiting turns into anything
    /// else. Nothing in the tree ever cleared `compilationDocuments`, so a section whose load
    /// never ran spun for the life of the process.
    ///
    /// Read it through ``documentLoadState(forKey:)``, which supplies `.notStarted` for an absent
    /// key so no caller has to decide what a missing entry means — deciding that wrongly is what
    /// #1301 was.
    public var documentLoadStates: [String: BrowserDocumentLoadState] = [:]

    // MARK: - Indexing

    /// `true` while a triggered `indexVolume` call is running.
    public var isIndexing: Bool = false
    public var indexingError: Error? = nil

    /// Live per-document progress for the volume currently being indexed.
    /// `nil` when no indexing is in progress or before the first update arrives.
    /// Populated by a concurrent `progressStream` observer inside `indexVolume(_:)`.
    public var indexingProgress: IndexingProgressUpdate? = nil

    // MARK: - Dependencies

    public let manifestStore: ManifestStore
    public let tagStore: VolumeLevelTagStore
    /// The download manager. Settable only through ``attachDownloadManagerIfNeeded(_:)``
    /// because it can legitimately be `nil` when the view model boots (#324) and must be
    /// back-filled once `AppState` finishes booting it.
    public private(set) var downloadManager: DownloadManager?
    /// The search-index pipeline. Settable only through ``attachIndexingPipelineIfNeeded(_:)``
    /// for the same reason as `downloadManager` above: it can legitimately be `nil` when the
    /// view model boots and must be back-filled once `AppState` finishes booting it (R-9).
    ///
    /// This is deliberately a `var` and not a `let`, which also makes it observable: a view
    /// body that reads it (via ``isIndexed(_:)``, say) re-evaluates when the pipeline attaches,
    /// so `CompilationView` leaves its "Index Required" state on its own.
    public private(set) var indexingPipeline: IndexingPipeline?
    let parser: FRUSDocumentParser

    // MARK: - Initialisation

    public init(
        manifestStore: ManifestStore,
        tagStore: VolumeLevelTagStore,
        downloadManager: DownloadManager?,
        indexingPipeline: IndexingPipeline?
    ) {
        self.manifestStore = manifestStore
        self.tagStore = tagStore
        self.downloadManager = downloadManager
        self.indexingPipeline = indexingPipeline
        self.parser = FRUSDocumentParser()
    }

    /// Back-fills the download manager when it wasn't ready at boot (#324).
    ///
    /// Under `FRUS_UI_TEST_MODE` the browse stack can render before `AppState`
    /// finishes booting the download manager, so the view model would otherwise
    /// capture `nil` for the whole session and report every volume as
    /// not-downloaded. `BrowserView` calls this when the manager appears. It is a
    /// no-op once a manager is attached, so it can never clobber a live one — and a
    /// no-op in production, where the manager already exists at boot.
    public func attachDownloadManagerIfNeeded(_ manager: DownloadManager?) {
        guard downloadManager == nil, let manager else { return }
        downloadManager = manager
    }

    /// Back-fills the indexing pipeline when it wasn't ready at boot (R-9).
    ///
    /// The exact counterpart of ``attachDownloadManagerIfNeeded(_:)``, and it exists because
    /// #324 fixed only the download-manager half of the same defect. `BrowserView` copies both
    /// dependencies out of `AppState` from `.onAppear`, which under `FRUS_UI_TEST_MODE` (and on
    /// any launch where `ContentView`'s gate opens before `bootDownloadManager()` finishes) runs
    /// *before* `appState.indexingPipeline` is assigned. Without this the view model held `nil`
    /// for the session and `isIndexed(_:)` answered `false` for every volume, so a fully indexed
    /// volume showed "Index Required" and "Index Now" did nothing.
    ///
    /// A no-op once a pipeline is attached, so it can never clobber a live one — and a no-op in
    /// the normal launch path, where the pipeline already exists by the time Browse appears.
    public func attachIndexingPipelineIfNeeded(_ pipeline: IndexingPipeline?) {
        guard indexingPipeline == nil, let pipeline else { return }
        indexingPipeline = pipeline
    }

    // MARK: - Subseries Groups

    /// Every volume the app can show — the catalogue plus anything side-loaded (#777).
    ///
    /// Was `diffResult?.known ?? bundledEntries`, which is the catalogue and only the catalogue;
    /// a side-loaded volume produced no subseries group and no row, however thoroughly it was
    /// indexed. `browsableEntries` is that expression with the local entries folded in.
    /// Internal since #1051 B-1: the corpus root's search field and the All Volumes
    /// catalogue read the same universe this view model navigates.
    var allVolumes: [VolumeManifestEntry] {
        manifestStore.browsableEntries
    }

    /// All subseries groups, sorted chronologically by start year (most recent first).
    ///
    /// When `filterDownloadedOnly` is `true`, subseries where no volume has been
    /// downloaded are omitted entirely.
    public var allSubseriesGroups: [SubseriesGroup] {
        var dict: [String: [VolumeManifestEntry]] = [:]
        for v in allVolumes { dict[v.subseries, default: []].append(v) }
        var groups = dict
            .map { SubseriesGroup(subseries: $0.key, volumes: $0.value) }
            .sorted { $0.startYear > $1.startYear }
        if filterDownloadedOnly {
            groups = groups.filter { group in
                group.volumes.contains { isDownloaded($0.volumeId) }
            }
        }
        return groups
    }

    /// Volumes within a subseries after applying the active tag filter and (optionally)
    /// the downloaded-only filter.
    public func filteredVolumes(for subseries: String) -> [VolumeManifestEntry] {
        let group = allSubseriesGroups.first { $0.subseries == subseries }
        guard let volumes = group?.volumes else { return [] }
        var result = volumes
        let filter = tagFilters[subseries] ?? []
        if !filter.isEmpty {
            let allowed = Set(tagStore.volumes(forTagSlugs: Array(filter)))
            result = result.filter { allowed.contains($0.volumeId) }
        }
        if filterDownloadedOnly {
            result = result.filter { isDownloaded($0.volumeId) }
        }
        return result
    }

    // MARK: - Tag Filter Actions

    /// Activates a tag slug as a filter for the given subseries, then lands the reader on
    /// that subseries level — popping back to it when it is an ancestor, or pushing it when
    /// it is not.
    ///
    /// ## The Q-5 fallback (#1051 B-1)
    /// A `VolumeView` can now be reached from paths with no `.subseries` ancestor (the All
    /// Volumes catalogue, root search, and every future axis list). Before this fix the
    /// no-ancestor case silently did nothing visible while setting LATENT filter state that
    /// pre-filtered the subseries the next time it was entered from the root. The ruled
    /// behaviour (owner decision Q-5) is to push the subseries level with the filter
    /// applied, so the chip's promise — "show other volumes with this tag" — lands
    /// somewhere visible and the breadcrumb stays truthful.
    public func activateTagFilter(slug: String, forSubseries subseries: String) {
        tagFilters[subseries, default: []].insert(slug)
        if let idx = Self.subseriesAncestorIndex(in: navigationPath, subseries: subseries) {
            navigationPath = Array(navigationPath.prefix(through: idx))
        } else {
            // Build the group from the UNFILTERED universe: `allSubseriesGroups` respects
            // `filterDownloadedOnly`, and a chip on an undownloaded volume must still land.
            let vols = allVolumes.filter { $0.subseries == subseries }
            guard !vols.isEmpty else { return }
            navigationPath.append(.subseries(SubseriesGroup(subseries: subseries, volumes: vols)))
        }
        #if DEBUG
        print("[BrowserView] Tag filter activated: \(slug) for subseries \(subseries)")
        #endif
    }

    /// The index of the `.subseries` level for `subseries` on `path`, or `nil` when the
    /// path has no such ancestor (the Q-5 push case). Static and pure so the pop-vs-push
    /// decision is unit-testable without a manifest store.
    ///
    /// - Parameters:
    ///   - path: The navigation path to search.
    ///   - subseries: The subseries identifier the tag filter belongs to.
    /// - Returns: The 0-based index to pop through, or `nil` to push instead.
    static func subseriesAncestorIndex(in path: [BrowserLevel], subseries: String) -> Int? {
        path.firstIndex(where: {
            if case .subseries(let g) = $0 { return g.subseries == subseries }
            return false
        })
    }

    /// Removes a tag slug filter for the given subseries.
    public func removeTagFilter(slug: String, forSubseries subseries: String) {
        tagFilters[subseries]?.remove(slug)
    }

    /// Clears all tag filters for the given subseries.
    public func clearTagFilters(forSubseries subseries: String) {
        tagFilters.removeValue(forKey: subseries)
    }

    // MARK: - Download State

    /// Whether a given volume XML file is present on disk.
    public func isDownloaded(_ volumeId: String) -> Bool {
        downloadManager?.isVolumeDownloaded(volumeId) ?? false
    }

    // MARK: - Volume Structure Loading

    /// Loads the `VolumeStructure` for a volume, caching the result.
    ///
    /// No-ops if the structure is already cached. The persisted structure from
    /// `volume_structures` (written at index time) is preferred; volumes that are
    /// downloaded but not yet indexed fall back to parsing the XML. Sets
    /// `isLoadingStructure` and `structureError` around the async operation.
    public func loadVolumeStructure(for volume: VolumeManifestEntry) async {
        guard volumeStructures[volume.volumeId] == nil else { return }
        guard let dm = downloadManager, dm.isVolumeDownloaded(volume.volumeId) else { return }

        // Fast path: structure persisted at index time — a single SQLite read
        // instead of a SAX pass over the whole volume XML.
        if let pipeline = indexingPipeline,
           let cached = try? await pipeline.cachedVolumeStructure(forVolumeId: volume.volumeId),
           !cached.isEmpty {
            volumeStructures[volume.volumeId] = cached
            return
        }

        let url = dm.volumeURL(for: volume.volumeId)  // nonisolated — safe to call without await
        isLoadingStructure = true
        structureError = nil
        do {
            let structure = try await parser.parseVolumeStructure(volumeURL: url)
            volumeStructures[volume.volumeId] = structure
        } catch {
            structureError = error
            #if DEBUG
            print("[BrowserView] Failed to parse structure for \(volume.volumeId): \(error)")
            #endif
        }
        isLoadingStructure = false
    }

    // MARK: - Compilation Document Loading

    /// Cache key for `compilationDocuments` and ``documentLoadStates``.
    ///
    /// Forwards to ``BrowseLoadKey/compilation(volumeId:sectionId:)``, which is also what
    /// `CompilationView`'s load task is keyed on — one definition, so the id the task re-runs for
    /// and the dictionary the load writes into cannot drift apart.
    public func compilationKey(volumeId: String, sectionId: String) -> String {
        BrowseLoadKey.compilation(volumeId: volumeId, sectionId: sectionId)
    }

    /// What the failure row's **Retry** control does, as a value (#1301 round 2).
    ///
    /// ## Why a value rather than a closure written at the call site
    /// The button's action was `Task { await vm.loadDocuments(for: section, volumeId: volumeId) }`,
    /// written inside the row's `@ViewBuilder`. Two mutations of that line survived every test:
    /// emptying the body (a button that renders and does nothing — and the error row is the only
    /// exit from a failed section, since the file has no `.refreshable`), and pointing it at a
    /// *neighbouring* section, which quietly fills another section's cache while this one goes on
    /// showing its error. `retryAction(for:volumeId:)` returns the key it will load for, so both
    /// are ordinary assertions.
    ///
    /// - Parameters:
    ///   - section: The section whose rows failed.
    ///   - volumeId: Its volume.
    /// - Returns: The action, carrying the key it targets.
    public func retryAction(for section: VolumeSection,
                            volumeId: String) -> CompilationRetryAction {
        CompilationRetryAction(
            targetKey: compilationKey(volumeId: volumeId, sectionId: section.sectionId),
            run: { [weak self] in await self?.loadDocuments(for: section, volumeId: volumeId) }
        )
    }

    /// How far the load for one section key has got, `.notStarted` when nothing has been
    /// attempted (#1301).
    ///
    /// - Parameter key: A key from ``compilationKey(volumeId:sectionId:)``.
    /// - Returns: The section's load state.
    public func documentLoadState(forKey key: String) -> BrowserDocumentLoadState {
        documentLoadStates[key] ?? .notStarted
    }

    /// Loads and caches `DocumentBrowserEntry` values for the given section, recording the
    /// outcome in ``documentLoadStates``.
    ///
    /// Filters the volume's documents down to the section's *direct* documents
    /// (`section.documentIds`), not every descendant (`allDocumentIds`). A section that has
    /// subsections lists those as their own drill-down rows, and each subsection loads its
    /// own direct documents — so a compilation with chapters no longer also lists every
    /// descendant document here (which double-counted them). For a leaf section the two are
    /// identical, so its full document list is unaffected. Mirrors history.state.gov, where
    /// an interior grouping node shows only its child groups (and any direct documents).
    ///
    /// ## What short-circuits, and what deliberately does not (#1301)
    /// Only `.loaded` returns early. `.failed` does not, which is what makes the error row's
    /// **Retry** button — and the pipeline back-fill's `.onChange` kick — work by simply calling
    /// this again. `.loading` does not either: re-entering is idempotent and self-healing, where
    /// returning on it would let a load cancelled mid-flight strand its section on the spinner
    /// forever. That is #1301 in a new costume, so it is refused by construction rather than
    /// avoided by argument.
    ///
    /// ## The caller's obligation
    /// **Do not call this for a volume that is not indexed.** `document_cache` answers an
    /// unindexed volume with an empty set, which would be recorded as `.loaded` and never
    /// reloaded once the volume *was* indexed. `CompilationView`'s `.task` holds that guard, and
    /// its silence there is observable because `CompilationDocumentsPresentation` resolves the
    /// same condition to `.indexRequired` — a real screen with a real button — before it ever
    /// consults the load state.
    ///
    /// The volume does **not** have to be in the manifest: nothing here reads it. The old caller
    /// gated on a `volume != nil` lookup through `allSubseriesGroups` that the load never needed.
    public func loadDocuments(for section: VolumeSection, volumeId: String) async {
        let key = compilationKey(volumeId: volumeId, sectionId: section.sectionId)
        guard !documentLoadState(forKey: key).isLoaded else { return }
        guard let pipeline = indexingPipeline else {
            // Recorded rather than returned silently — but the honest scope of that is narrow, and
            // two comments in this branch's first round overstated it. NO VIEW REACHES THIS. Every
            // caller in `CompilationView` is gated on `isIndexed(_:)`, which answers `false`
            // without a pipeline, or — kick 1 — on an `isIndexing` edge that `indexVolume(_:)`
            // cannot produce without one, because its pipeline guard returns before it sets the
            // flag; and Retry is drawn only from an already-recorded `.failed`; the
            // pipeline is also monotone nil → non-nil (`attachIndexingPipelineIfNeeded` guards on
            // nil), so no race strands a caller here. It is reached by a direct call — which is
            // what the two unit tests that pin it do — and it exists so the model is not the
            // place the information stops.
            documentLoadStates[key] = .failed(BrowserIndexingError.pipelineUnavailable)
            return
        }
        documentLoadStates[key] = .loading
        do {
            #if DEBUG
            // Inert unless FRUS_UI_TEST_FAIL_DOCUMENT_LOAD names this section. It throws where the
            // real query throws, so the recording, the row and the retry below are all production
            // code — see `UITestBrowseSeams`.
            try UITestBrowseSeams.throwInjectedFailureIfRequested(sectionId: section.sectionId)
            // And, separately, holds a load open so the in-flight row can be seen at all.
            await UITestBrowseSeams.delayLoadIfRequested(sectionId: section.sectionId)
            #endif
            let all = try await pipeline.documents(forVolume: volumeId)
            let sectionIds = Set(section.documentIds)
            // Rows first, THEN the state. The view reads both, and this order means a render
            // triggered by the state's write always finds the rows already there.
            compilationDocuments[key] = all.filter { sectionIds.contains($0.documentId) }
            documentLoadStates[key] = .loaded
        } catch {
            documentLoadStates[key] = .failed(error)
            #if DEBUG
            print("[BrowserView] Failed to load documents for \(key): \(error)")
            #endif
        }
    }

    // MARK: - Indexing

    /// Returns `true` if the volume has been indexed (has entries in `document_cache`).
    public func isIndexed(_ volumeId: String) -> Bool {
        guard let pipeline = indexingPipeline else { return false }
        return (try? pipeline.isVolumeIndexed(volumeId)) ?? false
    }

    /// Triggers indexing for a single volume and streams live per-document progress
    /// into `indexingProgress` while the pipeline runs.
    ///
    /// A concurrent `Task` iterates `pipeline.progressStream`, filtering to
    /// `volume.volumeId` and breaking on `.complete`. The task is cancelled once
    /// `pipeline.indexVolume` returns (success or error) so it never outlives the
    /// indexing operation. `indexingProgress` is cleared and `isIndexing` is set to
    /// `false` at the end — CompilationView's `.onChange(of: vm.isIndexing)` uses
    /// this transition to load the document list without requiring navigation.
    public func indexVolume(_ volume: VolumeManifestEntry) async {
        // R-9: never return silently here. This guard used to be a bare `return`, so
        // "Index Now" produced no progress, no error, and no log line — the single most
        // expensive part of diagnosing the defect. Recording the error lets
        // `CompilationView`'s existing error row explain itself; the button is also
        // disabled in that state, mirroring `MacCorpusBrowserWindow`.
        guard let pipeline = indexingPipeline else {
            indexingError = BrowserIndexingError.pipelineUnavailable
            #if DEBUG
            print("[BrowserView] indexVolume(\(volume.volumeId)) refused: no indexing pipeline.")
            #endif
            return
        }
        isIndexing = true
        indexingError = nil
        indexingProgress = nil

        // Stream per-document progress for this volume into indexingProgress.
        // Runs on the main actor so @Observable property mutations are safe.
        // Breaks on .complete or when cancelled (i.e. when indexVolume returns).
        let progressTask = Task { @MainActor [weak self] in
            for await update in pipeline.progressStream {
                guard let self else { break }
                guard update.volumeId == volume.volumeId else { continue }
                self.indexingProgress = update
                if update.stage == .complete { break }
            }
        }

        do {
            try await pipeline.indexVolume(volume.volumeId)
            #if DEBUG
            print("[BrowserView] Indexed \(volume.volumeId)")
            #endif
        } catch {
            indexingError = error
            #if DEBUG
            print("[BrowserView] Indexing failed for \(volume.volumeId): \(error)")
            #endif
        }

        progressTask.cancel()
        indexingProgress = nil
        isIndexing = false
    }

    // MARK: - Tag Display Helpers

    /// Tag chips for a volume, sorted by category priority (People → Places → Topics),
    /// then alphabetically within category. Used by the Volume level.
    public func tagChips(for volume: VolumeManifestEntry) -> [VolumeLevelTag] {
        tagStore.resolve(slugs: volume.tags)
            .sorted { lhs, rhs in
                let lp = categoryPriority(lhs.category)
                let rp = categoryPriority(rhs.category)
                if lp != rp { return lp < rp }
                return lhs.displayName < rhs.displayName
            }
    }

    private func categoryPriority(_ cat: TagCategory) -> Int {
        switch cat {
        case .people: return 0
        case .places: return 1
        case .topics: return 2
        }
    }
}

// MARK: - CompilationRetryAction

/// One press of the failure row's **Retry** control (#1301 round 2).
///
/// Carries ``targetKey`` so a test can assert *which* section the button asks for, not merely that
/// it asks for something: a retry wired to a neighbouring section is indistinguishable from a
/// correct one by any count of calls, and worse on screen than a dead button — it fills another
/// section's cache while the failed one keeps its error row.
///
/// Built by ``BrowserViewModel/retryAction(for:volumeId:)``. Not `Sendable`: it closes over a
/// `@MainActor` view model and is created and run there.
///
/// Version history:
///   1.0 — #1301 round 2: initial implementation
public struct CompilationRetryAction {

    /// The `compilationDocuments` / `documentLoadStates` key this retry will load for.
    public let targetKey: String

    /// The load itself.
    private let body: @MainActor () async -> Void

    /// Creates an action.
    ///
    /// - Parameters:
    ///   - targetKey: The section key it loads for.
    ///   - run: The load.
    init(targetKey: String, run: @escaping @MainActor () async -> Void) {
        self.targetKey = targetKey
        self.body = run
    }

    /// Asks for the section's documents again.
    @MainActor
    public func run() async { await body() }
}

// MARK: - BrowserIndexingError

/// Failures the Browser can hit before it ever reaches `IndexingPipeline`.
///
/// Exists so that ``BrowserViewModel/indexVolume(_:)``'s missing-pipeline path has something
/// user-readable to publish into `indexingError`. `CompilationView` renders that value, so the
/// "Index Now" button can no longer fail mutely (R-9).
///
/// Version history:
///   1.0 — Wave R / R-9: initial implementation
public enum BrowserIndexingError: LocalizedError, Equatable {

    /// `AppState` has no `IndexingPipeline`, so nothing can be indexed or index-checked.
    ///
    /// Two ways to get here, and the message has to hold for both:
    /// 1. The transient boot race this fix removes — the view model captured `nil` before
    ///    `bootDownloadManager()` assigned the pipeline. Relaunching clears it (so does the
    ///    back-fill, which is why the UI should no longer reach this state).
    /// 2. `FTS5Store` / `IndexingPipeline` construction genuinely threw at boot
    ///    (`FRUSExplorerApp` builds both with `try?`). Then the pipeline is `nil` for the whole
    ///    session no matter what the user taps, and only a relaunch — or, if the database file
    ///    itself is damaged, a reinstall — can restore it.
    case pipelineUnavailable

    /// A user-facing explanation, deliberately free of "try again": in case 2 retrying the
    /// button cannot help, and promising otherwise is what made the original defect so opaque.
    public var errorDescription: String? {
        switch self {
        case .pipelineUnavailable:
            // One literal, not a `+` chain: `defaultValue` is a `String.LocalizationValue`,
            // which is expressible by a literal but has no `+`.
            return String(
                localized: "browser.indexing.pipelineUnavailable",
                defaultValue: "FRUS Explorer could not open its search index. This volume cannot be indexed or checked until you restart. Relaunch the app. If the message comes back, the index database is damaged and only reinstalling will rebuild it."
            )
        }
    }
}
