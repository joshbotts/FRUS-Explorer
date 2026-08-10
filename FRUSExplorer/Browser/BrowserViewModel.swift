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
/// and cached in `compilationDocuments`. An unindexed volume shows an "Index required"
/// prompt with an "Index Now" action.
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

        public func hash(into hasher: inout Hasher) {
            switch self {
            case .corpus:              hasher.combine(0)
            case .subseries(let g):    hasher.combine(1); hasher.combine(g.subseries)
            case .volume(let v):       hasher.combine(2); hasher.combine(v.volumeId)
            case .compilation(let vid, let s):
                hasher.combine(3); hasher.combine(vid); hasher.combine(s.sectionId)
            case .document(let e):     hasher.combine(4); hasher.combine(e.documentId)
            case .people:              hasher.combine(5)
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
            default: return false
            }
        }
    }

    // MARK: - Navigation State

    /// Current navigation stack. The last element is the displayed level.
    public var navigationPath: [BrowserLevel] = []

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

    /// `true` while `documents(forVolume:)` is being loaded.
    public var isLoadingDocuments: Bool = false

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

    // MARK: - Corpus Statistics

    /// Aggregate statistics computed from all manifest entries.
    public var corpusStats: CorpusStats {
        let all = allVolumes
        let docs = all.reduce(0) { $0 + $1.documentCount }
        let docDates  = all.compactMap { $0.dateRange.earliest } + all.compactMap { $0.dateRange.latest }
        let pubDates  = all.compactMap(\.publicationDate)
        return CorpusStats(
            totalVolumes: all.count,
            totalDocuments: docs,
            earliestDocumentDate: docDates.min(),
            latestDocumentDate: docDates.max(),
            earliestPublicationDate: pubDates.min(),
            latestPublicationDate: pubDates.max()
        )
    }

    // MARK: - Subseries Groups

    /// Every volume the app can show — the catalogue plus anything side-loaded (#777).
    ///
    /// Was `diffResult?.known ?? bundledEntries`, which is the catalogue and only the catalogue;
    /// a side-loaded volume produced no subseries group and no row, however thoroughly it was
    /// indexed. `browsableEntries` is that expression with the local entries folded in.
    private var allVolumes: [VolumeManifestEntry] {
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

    /// Activates a tag slug as a filter for the given subseries and (if needed)
    /// pops the navigation stack back to the Subseries level.
    public func activateTagFilter(slug: String, forSubseries subseries: String) {
        tagFilters[subseries, default: []].insert(slug)
        // Pop back to subseries level if we are deeper.
        if let idx = navigationPath.firstIndex(where: {
            if case .subseries(let g) = $0 { return g.subseries == subseries }
            return false
        }) {
            navigationPath = Array(navigationPath.prefix(through: idx))
        }
        #if DEBUG
        print("[BrowserView] Tag filter activated: \(slug) for subseries \(subseries)")
        #endif
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

    /// Cache key for `compilationDocuments`.
    public func compilationKey(volumeId: String, sectionId: String) -> String {
        "\(volumeId)/\(sectionId)"
    }

    /// Loads and caches `DocumentBrowserEntry` values for the given section.
    ///
    /// Filters the volume's documents down to the section's *direct* documents
    /// (`section.documentIds`), not every descendant (`allDocumentIds`). A section that has
    /// subsections lists those as their own drill-down rows, and each subsection loads its
    /// own direct documents — so a compilation with chapters no longer also lists every
    /// descendant document here (which double-counted them). For a leaf section the two are
    /// identical, so its full document list is unaffected. Mirrors history.state.gov, where
    /// an interior grouping node shows only its child groups (and any direct documents).
    public func loadDocuments(for section: VolumeSection, volumeId: String) async {
        let key = compilationKey(volumeId: volumeId, sectionId: section.sectionId)
        guard compilationDocuments[key] == nil else { return }
        guard let pipeline = indexingPipeline else { return }
        isLoadingDocuments = true
        do {
            let all = try await pipeline.documents(forVolume: volumeId)
            let sectionIds = Set(section.documentIds)
            compilationDocuments[key] = all.filter { sectionIds.contains($0.documentId) }
        } catch {
            #if DEBUG
            print("[BrowserView] Failed to load documents for \(key): \(error)")
            #endif
        }
        isLoadingDocuments = false
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
