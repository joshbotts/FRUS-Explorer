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

        public func hash(into hasher: inout Hasher) {
            switch self {
            case .corpus:              hasher.combine(0)
            case .subseries(let g):    hasher.combine(1); hasher.combine(g.subseries)
            case .volume(let v):       hasher.combine(2); hasher.combine(v.volumeId)
            case .compilation(let vid, let s):
                hasher.combine(3); hasher.combine(vid); hasher.combine(s.sectionId)
            case .document(let e):     hasher.combine(4); hasher.combine(e.documentId)
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
    public let downloadManager: DownloadManager?
    public let indexingPipeline: IndexingPipeline?
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

    /// All volumes from the manifest (live known + bundled).
    private var allVolumes: [VolumeManifestEntry] {
        manifestStore.diffResult?.known ?? manifestStore.bundledEntries
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
    /// No-ops if the structure is already cached. Sets `isLoadingStructure` and
    /// `structureError` around the async parse operation.
    public func loadVolumeStructure(for volume: VolumeManifestEntry) async {
        guard volumeStructures[volume.volumeId] == nil else { return }
        guard let dm = downloadManager, dm.isVolumeDownloaded(volume.volumeId) else { return }
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
    /// Filters the full volume document list down to IDs present in `section.allDocumentIds`.
    public func loadDocuments(for section: VolumeSection, volumeId: String) async {
        let key = compilationKey(volumeId: volumeId, sectionId: section.sectionId)
        guard compilationDocuments[key] == nil else { return }
        guard let pipeline = indexingPipeline else { return }
        isLoadingDocuments = true
        do {
            let all = try await pipeline.documents(forVolume: volumeId)
            let sectionIds = Set(section.allDocumentIds)
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
        guard let pipeline = indexingPipeline else { return }
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
