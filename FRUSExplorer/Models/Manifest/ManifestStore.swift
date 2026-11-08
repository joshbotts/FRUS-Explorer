// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Observation

/// Why GitHub's listing of the published volumes was not read: it answered, with a status that
/// is not a success (#1660).
///
/// Thrown by the live fetch, and held in `ManifestStore.liveFetchError`, so Keeping Current can
/// say which of the causes it was. A transport failure (no connection, a timeout) is the
/// `URLError` itself.
///
/// Version history:
///   1.0 — #1660: initial implementation
public struct LiveListingError: Error, Sendable, Equatable {
    /// The HTTP status GitHub answered with.
    public let statusCode: Int
    /// Whether the answer was GitHub's request limit: a 429, or a 403 that says no requests
    /// remain. The listing is read without signing in, which GitHub allows 60 times an hour from
    /// one network address.
    public let isRateLimited: Bool
    /// When GitHub says requests may be made again, if it said.
    public let retryAfter: Date?

    /// Reads a non-success answer.
    ///
    /// - Parameters:
    ///   - response: GitHub's answer.
    ///   - now: The time a `Retry-After` counts from. Default: the current time.
    public init(response: HTTPURLResponse, now: Date = Date()) {
        statusCode = response.statusCode
        let remaining = response.value(forHTTPHeaderField: "X-RateLimit-Remaining")
        isRateLimited = response.statusCode == 429
            || (response.statusCode == 403 && remaining == "0")
        if let reset = response.value(forHTTPHeaderField: "X-RateLimit-Reset").flatMap(TimeInterval.init) {
            retryAfter = Date(timeIntervalSince1970: reset)
        } else if let seconds = response.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init) {
            retryAfter = now.addingTimeInterval(seconds)
        } else {
            retryAfter = nil
        }
    }
}

/// Loads and manages the bundled volume manifest, and merges it with the live GitHub listing.
///
/// `ManifestStore` is the single source of truth for volume metadata in the app.
/// It is injected into the environment via `AppState` once initialised.
///
/// ## Bundled Manifest (Layer 1)
/// Loaded synchronously from the app bundle at init time. Always available, even offline.
/// Contains rich metadata for all volumes known at release time.
///
/// ## Live GitHub Manifest (Layer 2)
/// Fetched asynchronously at launch when the device is online. Provides the current
/// file listing to detect newly published volumes and confirm download URLs/SHAs.
/// The diff result populates `diffResult`, whose `known` bucket is the catalogue every browse,
/// download and analytics surface reads and whose `liveInfoByVolumeId` drives correction
/// detection. `newlyAvailable` and `noLongerPublished` are computed and unconsumed (D-1).
///
/// Version history:
///   1.0 — Session 02: initial implementation
///   1.1 — Session 49: corpusDateRange computed property added
///   1.2 — Session 68b: frusSubseries(from:) updated to match VolumeIDParser Session 54 logic
///          (strips Vietnam-extras, bare part numbers, known suffixes, and conference/topic
///          name suffixes) so newly-available volumes in the live diff get correct subseries
///   1.3 — Session 69: frusSubseries(from:) simplified to single-step year-range extraction
///          (^\d{4}(-\d{2,4})?); fixes conference-suffix-on-volume-marker, mixed alphanumeric
///          edition suffixes (IranEd2), and single-letter sub-series identifiers (G in 1952-54G)
///   1.4 — Session 154: live GitHub listing now includes each file's git blob `sha`;
///          `ManifestDiffResult.liveInfoByVolumeId` exposes it (with size) for
///          `VolumeUpdateChecker` to detect upstream corrections
///   1.5 — FRUSCoreKit, part 2: conforms to the kit's `CitableVolumeCatalogue`, through which
///          Citation Lookup's engine, now in the kit, reads `citableEntries`
///   1.6 — #1660: a fetch asked for while one is under way waits for that one instead of
///          returning at once, so its caller reads the result it asked for; a non-success answer
///          is a `LiveListingError`, which keeps the status and GitHub's request limit
///   1.7 — Session 2026-11-08 (FRUS Explorer Light, S21a): the live listing's entry, its decode
///          and filter (`GitHubLiveEntry.volumes(inListing:)`), the diff
///          (`ManifestDiffResult.diff(bundled:live:)`), the diff's three result types and
///          `frusSubseries(from:)` moved into FRUSCoreKit (`Models/Manifest/ManifestLiveDiff.swift`),
///          unchanged but for access; the fetch calls them
@Observable
@MainActor
public final class ManifestStore {

    // MARK: - Public State

    /// All entries from the bundled manifest. Available immediately at launch.
    public private(set) var bundledEntries: [VolumeManifestEntry] = []

    /// The result of diffing bundled against live. `nil` until the live fetch completes.
    public private(set) var diffResult: ManifestDiffResult? = nil

    /// `true` while the live manifest fetch is in progress.
    public private(set) var isFetchingLive: Bool = false

    /// Non-nil if the last live manifest fetch failed: a `LiveListingError` when GitHub answered
    /// with a status that is not a success, otherwise the transport's error.
    public private(set) var liveFetchError: Error? = nil

    /// The fetch under way, which a second call waits for (#1660).
    private var liveFetch: Task<Void, Never>? = nil

    /// Entries for volumes on disk that the catalogue does not list — side-loaded files (#777).
    ///
    /// Kept separate from `bundledEntries` so nothing that means "the published FRUS series" can
    /// pick them up by accident: the corpus date range, the storage hero's denominator, and the
    /// download-update check all read the catalogue and must keep meaning what they mean. What
    /// *does* see them is ``browsableEntries`` — the volume universe the two browse surfaces
    /// enumerate — and ``entry(forVolumeId:)``, so a side-loaded volume has a title everywhere
    /// instead of a raw id.
    public private(set) var localEntries: [VolumeManifestEntry] = []

    /// Every volume the app can show: the catalogue, plus anything side-loaded.
    ///
    /// The catalogue wins a collision. A file named after a catalogue volume is that volume — the
    /// side-load duplicate check is a disk test, so this is reachable — and the catalogue's entry
    /// carries a download URL and a real publication status where the local one would not.
    public var browsableEntries: [VolumeManifestEntry] {
        let catalogue = diffResult?.known ?? bundledEntries
        guard !localEntries.isEmpty else { return catalogue }
        let known = Set(catalogue.map(\.volumeId))
        return catalogue + localEntries.filter { !known.contains($0.volumeId) }
    }

    /// The volumes citation resolution answers for: the bundled catalogue, and never a volume
    /// side-loaded from the reader's own file (#1523, owner decision D7).
    ///
    /// Citation Lookup and Add Documents' citations and links read this, through
    /// `CitationMatchingEngine`, because a citation is resolved by what the catalogue knows of a
    /// published volume — its subseries, its numbering, its title — and a side-loaded file's own
    /// header is not that record. Unlike ``browsableEntries`` it is not filtered by the live
    /// listing, so a volume no longer published is still found for a citation of it. The import
    /// tells the reader a side-loaded volume is left out (`SideloadCatalogueNotice`), deciding
    /// which volumes are by this same list.
    public var citableEntries: [VolumeManifestEntry] { bundledEntries }

    /// Re-reads the side-loaded volumes' sidecars, parsing headers for any that have none.
    ///
    /// Called through `AppState.reconcileSideloadedVolumes()`, from the corpus-change refresh that
    /// side-loading already triggers and once at boot, so a side-loaded volume has its title from
    /// launch and a volume side-loaded before #777 shipped gains its metadata on the next launch
    /// rather than needing to be re-imported. (Until 2026-10-01 no boot path called it, though
    /// this comment said one did.)
    public func refreshLocalEntries(volumesDirectory: URL) {
        let known = Set((diffResult?.known ?? bundledEntries).map(\.volumeId))
        localEntries = LocalVolumeCatalog.reconcile(in: volumesDirectory, known: known)
        rebuildEntryIndex()
    }

    // MARK: - Corpus Date Range

    /// The date range spanning the earliest to latest FRUS volume.
    ///
    /// The lower bound is the earliest subseries **start** year; the upper bound is the
    /// latest subseries **end** year (via `subseriesEndYear(_:)`), so a span like
    /// `"1989-92"` contributes 1992, not 1989 — the documents themselves run to the end
    /// of the span. Falls back to 1861-01-01…1992-12-31 when the manifest is empty.
    /// Recomputed whenever `diffResult` or `bundledEntries` changes (no manual caching
    /// needed because `@Observable` tracks property access automatically).
    ///
    /// Typical result for the full 553-volume corpus: `1861-01-01...1992-12-31`.
    public var corpusDateRange: ClosedRange<Date> {
        let source = diffResult?.known ?? bundledEntries
        let minYear = source.compactMap { Int($0.subseries.prefix(4)) }.min() ?? 1861
        let maxYear = source.compactMap { Self.subseriesEndYear($0.subseries) }.max() ?? 1992
        return Self.corpusYearStart(minYear)...Self.corpusYearEnd(maxYear)
    }

    /// The four-digit **end** year of a FRUS subseries identifier.
    ///
    /// Subseries identifiers encode a coverage span: `"1969-76"`, `"1989-92"`,
    /// `"1993-2000"`, or a bare single year like `"1861"`. This returns the span's end
    /// year, expanding a two-digit end to four digits relative to the start century
    /// (`"1989-92"` → 1992) and handling century rollover (`"1899-01"` → 1901). A bare
    /// year returns itself. Returns `nil` when the leading year cannot be parsed.
    public static func subseriesEndYear(_ subseries: String) -> Int? {
        let parts = subseries.split(separator: "-", maxSplits: 1)
        guard let startPart = parts.first, startPart.count == 4, let start = Int(startPart) else {
            return nil
        }
        guard parts.count == 2 else { return start }   // bare single-year subseries
        let endPart = parts[1]
        if endPart.count == 4, let end = Int(endPart) { return end }
        if endPart.count == 2, let twoDigit = Int(endPart) {
            var end = (start / 100) * 100 + twoDigit
            if end < start { end += 100 }              // century rollover (e.g. 1899-01 → 1901)
            return end
        }
        return start
    }

    /// Returns `Jan 1` of the given year in the Gregorian calendar.
    public static func corpusYearStart(_ year: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = 1; c.day = 1
        return Calendar(identifier: .gregorian).date(from: c) ?? .distantPast
    }

    /// Returns `Dec 31` of the given year in the Gregorian calendar.
    public static func corpusYearEnd(_ year: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = 12; c.day = 31
        return Calendar(identifier: .gregorian).date(from: c) ?? .distantFuture
    }

    // MARK: - Testing

    /// Testing initializer — bypasses bundle I/O and uses provided entries directly.
    init(bundledEntries: [VolumeManifestEntry]) {
        self.bundledEntries = bundledEntries
        rebuildEntryIndex()
    }

    // MARK: - Initialization

    public init() {
        setBundledEntries(Self.loadBundledManifest())
        #if DEBUG
        print("[FRUSExplorer] ManifestStore initialised with \(bundledEntries.count) bundled entries.")
        #endif
    }

    // MARK: - Convenience Lookups

    /// Returns the manifest entry for a given volume ID, or `nil` if not found.
    ///
    /// Searches `diffResult.known` when a live diff is available, otherwise falls
    /// back to `bundledEntries`. Used by the new macOS UI to resolve volume metadata
    /// from a `DocumentBrowserEntry` without requiring callers to search manually.
    ///
    /// Version history:
    ///   1.0 — New UI scaffolding
    /// The coverage era a volume falls into, from its manifest date range.
    ///
    /// Uses the app's own `CoverageEra` banding rather than a scheme invented at the call site, so
    /// an era-coloured map, an era-split analytics chart and an era-banded feedback log all mean the
    /// same thing by "before 1900".
    ///
    /// - Parameter volumeId: The volume to band.
    /// - Returns: The era, or `nil` when the volume has no usable date range.
    func eraForVolume(_ volumeId: String) -> CoverageEra? {
        guard let entry = entry(forVolumeId: volumeId),
              let earliest = entry.dateRange.earliest.flatMap({ Int($0.prefix(4)) }),
              let latest = entry.dateRange.latest.flatMap({ Int($0.prefix(4)) })
        else { return nil }
        // The midpoint, matching every other era-banding in the app: a volume belongs to exactly one
        // era, and its span is what decides which.
        return CoverageEra.bucket(year: (earliest + latest) / 2)
    }

    public func entry(forVolumeId id: String) -> VolumeManifestEntry? {
        entryIndex[id]
    }

    /// `volumeId` → entry, over whichever list ``entry(forVolumeId:)`` is answering from.
    ///
    /// This was a `.first { $0.volumeId == id }` scan over all 553 manifest entries, and it
    /// is the O(n) primitive under a surprising amount of the render loop. During a
    /// subseries index the indexing banner alone resolved it once per queued volume for the
    /// word-cloud scope and once per download-queue entry for the pending list — five times
    /// over, because `MainTabView` attaches the banner to each of its five tabs — at roughly
    /// ten body evaluations a second. For a 66-volume subseries that is on the order of
    /// 10⁵ string comparisons per pass, on the main thread, while the indexer is writing
    /// FTS5 segments. Nobody wrote a slow lookup on purpose; it was written when the only
    /// caller was a detail view resolving one title.
    ///
    /// Rebuilt on the two writes that can change the answer, which is why they funnel
    /// through ``setBundledEntries(_:)`` and ``setDiffResult(_:)`` rather than assigning
    /// the stored properties directly.
    private var entryIndex: [String: VolumeManifestEntry] = [:]

    /// Replaces the bundled entries and rebuilds ``entryIndex``.
    private func setBundledEntries(_ entries: [VolumeManifestEntry]) {
        bundledEntries = entries
        rebuildEntryIndex()
    }

    /// Replaces the diff result and rebuilds ``entryIndex``.
    ///
    /// `known` takes over from `bundledEntries` as the lookup source the moment it exists,
    /// exactly as the old expression's `??` did.
    private func setDiffResult(_ result: ManifestDiffResult?) {
        diffResult = result
        rebuildEntryIndex()
    }

    /// Rebuilds the id → entry map from the current lookup source.
    ///
    /// Last-write-wins on a duplicate id, which matches `first { }`'s behaviour only when
    /// ids are unique — they are, and a duplicate would be a manifest defect either way.
    private func rebuildEntryIndex() {
        // `browsableEntries`, not the catalogue: a side-loaded volume needs a title, a coverage
        // range and editors at all ~53 `entry(forVolumeId:)` call sites, or it renders as a raw
        // id among titled neighbours and can never be a citation, a search scope, or a chart row.
        // The catalogue is listed first and wins the `uniquingKeysWith` tie.
        entryIndex = Dictionary(browsableEntries.map { ($0.volumeId, $0) },
                                uniquingKeysWith: { first, _ in first })
    }

    /// Convenience alias for `fetchLiveManifest()` used by the new app entry point.
    ///
    /// Version history:
    ///   1.0 — New UI scaffolding
    public func refresh(session: URLSession = .shared) async {
        await fetchLiveManifest(session: session)
    }

    // MARK: - Live Manifest Fetch

    /// Fetches the live GitHub listing and computes the diff against the bundled manifest.
    ///
    /// Safe to call multiple times (e.g., when the user taps "Check for Corrections"). A call made
    /// while a fetch is under way waits for that fetch and starts none of its own (#1660): it
    /// used to return at once, so Check for Corrections, pressed while the fetch the pane starts
    /// on opening was still running, read no list and did nothing.
    ///
    /// - Parameter session: URLSession to use. Defaults to `.shared`. A call that waits for a
    ///   fetch under way gets that fetch's session.
    public func fetchLiveManifest(session: URLSession = .shared) async {
        if let liveFetch {
            await liveFetch.value
            return
        }
        let fetch = Task { await performLiveFetch(session: session) }
        liveFetch = fetch
        await fetch.value
        liveFetch = nil
    }

    /// One fetch of the live listing, run by `fetchLiveManifest(session:)`.
    private func performLiveFetch(session: URLSession) async {
        isFetchingLive = true
        liveFetchError = nil

        defer { isFetchingLive = false }

        #if DEBUG
        print("[FRUSExplorer] ManifestStore: fetching live GitHub listing…")
        #endif

        do {
            let liveEntries = try await fetchGitHubListing(session: session)
            setDiffResult(ManifestDiffResult.diff(bundled: bundledEntries, live: liveEntries))
            #if DEBUG
            let d = diffResult!
            print("[FRUSExplorer] ManifestStore: diff complete — \(d.known.count) known, \(d.newlyAvailable.count) new, \(d.noLongerPublished.count) removed.")
            #endif
        } catch {
            liveFetchError = error
            #if DEBUG
            print("[FRUSExplorer] ManifestStore: live fetch failed — \(error)")
            #endif
        }
    }

    // MARK: - Private

    /// Loads and decodes `manifest.json` from the main bundle.
    private static func loadBundledManifest() -> [VolumeManifestEntry] {
        guard let url = Bundle.main.url(forResource: "manifest", withExtension: "json") else {
            #if DEBUG
            print("[FRUSExplorer] ManifestStore: manifest.json not found in bundle.")
            #endif
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let entries = try JSONDecoder().decode([VolumeManifestEntry].self, from: data)
            return entries
        } catch {
            #if DEBUG
            print("[FRUSExplorer] ManifestStore: failed to decode manifest.json — \(error)")
            #endif
            return []
        }
    }

    /// Fetches the GitHub directory listing for FRUS volumes (filenames + sizes + URLs).
    private func fetchGitHubListing(session: URLSession) async throws -> [GitHubLiveEntry] {
        guard let url = URL(string: "https://api.github.com/repos/HistoryAtState/frus/contents/volumes") else {
            preconditionFailure("Invalid GitHub volumes endpoint URL")
        }
        var request = URLRequest(url: url)
        request.setValue("FRUSExplorer/2.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(http.statusCode) else { throw LiveListingError(response: http) }
        return try GitHubLiveEntry.volumes(inListing: data)
    }
}

// MARK: - CitableVolumeCatalogue

/// The app's catalogue for Citation Lookup and Add Documents' citations and links: `citableEntries`,
/// the bundled entries (#1523). A lookup reads them on the main actor, as it did when the engine held
/// the store by its own type.
extension ManifestStore: CitableVolumeCatalogue {}
