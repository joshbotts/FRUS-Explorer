// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Observation

/// The result of diffing the bundled manifest against the live GitHub listing.
///
/// Version history:
///   1.0 — Session 02: initial implementation
///   1.1 — Session 154: added `liveInfoByVolumeId`, capturing the live git blob SHA
///          and byte size for every `known` volume so `VolumeUpdateChecker` can
///          detect upstream corrections to already-downloaded volumes.
public struct ManifestDiffResult: Sendable {
    /// Volumes present in both manifests (use bundled rich metadata).
    public let known: [VolumeManifestEntry]

    /// Volumes present in the live listing only (newly released; no rich metadata yet).
    /// Displayed with a "newly available" badge in the Browser and download views.
    public let newlyAvailable: [NewlyAvailableVolume]

    /// Volumes in the bundled manifest but absent from the live listing.
    /// No longer published; hidden from download UI but downloaded copies are unaffected.
    public let noLongerPublished: [VolumeManifestEntry]

    /// Live git blob SHA and byte size for every `known` volume, keyed by `volumeId`.
    /// Used by `VolumeUpdateChecker` to detect upstream corrections to volumes the
    /// user has already downloaded.
    public let liveInfoByVolumeId: [String: LiveVolumeInfo]
}

/// Live git blob SHA and byte size for a volume, as reported by GitHub's contents
/// API at the time of the last `fetchLiveManifest()`.
///
/// Compared against `LocalVolumeInfo` by `VolumeUpdateChecker.hasUpdate(local:live:)`
/// to detect volumes that have received upstream corrections since download.
public struct LiveVolumeInfo: Sendable, Equatable {
    /// Git blob SHA-1 of the file's current contents on GitHub.
    public let sha: String

    /// Current file size in bytes on GitHub.
    public let sizeBytes: Int

    public init(sha: String, sizeBytes: Int) {
        self.sha = sha
        self.sizeBytes = sizeBytes
    }
}

/// Minimal metadata for a volume that appears in the live GitHub listing but not the
/// bundled manifest. No title, tags, or other rich metadata is available yet.
public struct NewlyAvailableVolume: Sendable, Identifiable {
    public let filename: String
    public let sizeBytes: Int
    public let downloadUrl: String
    /// Best-effort subseries parsed from the filename alone.
    public let subseries: String?

    public var id: String { filename }
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
/// The diff result populates `diffResult` and drives the "newly available" badge.
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

    /// Non-nil if the live manifest fetch failed.
    public private(set) var liveFetchError: Error? = nil

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

    /// Re-reads the side-loaded volumes' sidecars, parsing headers for any that have none.
    ///
    /// Called from the corpus-change refresh that side-loading already triggers, and once at boot,
    /// so a volume side-loaded before #777 shipped gains its metadata on the next launch rather
    /// than needing to be re-imported.
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
    /// Typical result for the full 552-volume corpus: `1861-01-01...1992-12-31`.
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
    public func entry(forVolumeId id: String) -> VolumeManifestEntry? {
        entryIndex[id]
    }

    /// `volumeId` → entry, over whichever list ``entry(forVolumeId:)`` is answering from.
    ///
    /// This was a `.first { $0.volumeId == id }` scan over all 552 manifest entries, and it
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
    /// Safe to call multiple times (e.g., when the user taps "Check for new volumes").
    /// Skips if a fetch is already in progress.
    ///
    /// - Parameter session: URLSession to use. Defaults to `.shared`.
    public func fetchLiveManifest(session: URLSession = .shared) async {
        guard !isFetchingLive else { return }
        isFetchingLive = true
        liveFetchError = nil

        defer { isFetchingLive = false }

        #if DEBUG
        print("[FRUSExplorer] ManifestStore: fetching live GitHub listing…")
        #endif

        do {
            let liveEntries = try await fetchGitHubListing(session: session)
            setDiffResult(diff(bundled: bundledEntries, live: liveEntries))
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
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let all = try JSONDecoder().decode([GitHubLiveEntry].self, from: data)
        return all.filter { $0.name.hasSuffix(".xml") && $0.size >= 20_000 }
    }

    /// Diffs the bundled manifest against the live GitHub listing.
    private func diff(bundled: [VolumeManifestEntry], live: [GitHubLiveEntry]) -> ManifestDiffResult {
        let bundledByFilename = Dictionary(uniqueKeysWithValues: bundled.map { ($0.filename, $0) })
        let liveByFilename = Dictionary(uniqueKeysWithValues: live.map { ($0.name, $0) })

        let known = bundled.filter { liveByFilename[$0.filename] != nil }
        let noLongerPublished = bundled.filter { liveByFilename[$0.filename] == nil }

        let newlyAvailable: [NewlyAvailableVolume] = live
            .filter { bundledByFilename[$0.name] == nil }
            .map { liveEntry in
                let subseries = subseries(from: liveEntry.name)
                return NewlyAvailableVolume(
                    filename: liveEntry.name,
                    sizeBytes: liveEntry.size,
                    downloadUrl: liveEntry.downloadUrl,
                    subseries: subseries
                )
            }

        var liveInfoByVolumeId: [String: LiveVolumeInfo] = [:]
        for entry in known {
            // `sha` is optional in the decode so one anomalous listing entry can't
            // fail the whole live manifest; a volume without it simply has no
            // update detection until the listing carries the field again.
            guard let liveEntry = liveByFilename[entry.filename],
                  let sha = liveEntry.sha else { continue }
            liveInfoByVolumeId[entry.volumeId] = LiveVolumeInfo(sha: sha, sizeBytes: liveEntry.size)
        }

        return ManifestDiffResult(
            known: known,
            newlyAvailable: newlyAvailable,
            noLongerPublished: noLongerPublished,
            liveInfoByVolumeId: liveInfoByVolumeId
        )
    }

    /// Best-effort subseries extraction from a FRUS filename, for newly-available volumes.
    ///
    /// Delegates to the module-level `frusSubseries(from:)` free function so that
    /// the parsing logic is independently testable via `@testable import`.
    private func subseries(from filename: String) -> String? {
        frusSubseries(from: filename)
    }
}

// MARK: - Subseries Parsing

/// Extracts the subseries identifier from a FRUS XML filename.
///
/// Mirrors the algorithm in `VolumeIDParser.subseries(from:)` (Session 69) so that
/// newly-available volumes in the live GitHub diff receive the same correct subseries
/// grouping as volumes in the bundled manifest.
///
/// A FRUS subseries is strictly a year or year-range — digits and hyphens only.
/// The subseries is extracted by matching only the leading `^\d{4}(-\d{2,4})?`
/// portion of the after-`frus` segment. Everything else is discarded: volume markers,
/// part numbers, string suffixes, single-letter sub-series identifiers, conference/topic
/// names, and mixed alphanumeric edition markers. No multi-pass stripping is needed.
///
/// | Filename                       | Result     |
/// |--------------------------------|------------|
/// | `frus1969-76v01.xml`           | `1969-76`  |
/// | `frus1969-76ve01.xml`          | `1969-76`  |
/// | `frus1969-76ve05p1.xml`        | `1969-76`  |
/// | `frus1863p2.xml`               | `1863`     |
/// | `frus1877app.xml`              | `1877`     |
/// | `frus1894app1.xml`             | `1894`     |
/// | `frus1943CairoTehran.xml`      | `1943`     |
/// | `frus1945Berlin.xml`           | `1945`     |
/// | `frus1919Paris.xml`            | `1919`     |
/// | `frus1951-54IranEd2.xml`       | `1951-54`  |
/// | `frus1952-54Gv01.xml`          | `1952-54`  |
/// | `frus1861.xml`                 | `1861`     |
/// | `frus1993-2000v01.xml`         | `1993-2000`|
///
/// Returns `nil` for filenames that are not `frus*.xml`.
///
/// Declared at module scope (not inside `ManifestStore`) so that `ManifestStoreTests`
/// can exercise it directly via `@testable import` without access-level friction.
func frusSubseries(from filename: String) -> String? {
    guard filename.hasSuffix(".xml") else { return nil }
    let base = String(filename.dropLast(4))           // strip ".xml"
    guard base.hasPrefix("frus"), base.count > 4 else { return nil }
    let afterFrus = String(base.dropFirst(4))         // strip "frus"

    // Extract the year or year-range prefix only. Anything after — volume markers,
    // letters, conference names, edition markers, etc. — is not part of the subseries.
    guard let range = afterFrus.range(of: #"^\d{4}(-\d{2,4})?"#,
                                      options: .regularExpression) else {
        return nil
    }
    let result = String(afterFrus[range])
    return result.isEmpty ? nil : result
}

// MARK: - Internal Live Entry Type

/// Minimal GitHub API response entry used only for the live diff.
private struct GitHubLiveEntry: Codable {
    let name: String
    let size: Int
    let downloadUrl: String
    /// Git blob SHA-1 of the file's current contents, used by `VolumeUpdateChecker`
    /// to detect upstream corrections to already-downloaded volumes (Session 154).
    /// Optional so a listing entry that ever omits it degrades to "no update
    /// detection for that volume" instead of failing the whole manifest decode.
    let sha: String?

    enum CodingKeys: String, CodingKey {
        case name, size, sha
        case downloadUrl = "download_url"
    }
}
