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

    // MARK: - Corpus Date Range

    /// The date range spanning the earliest to latest FRUS volume.
    ///
    /// Derived by scanning the leading 4-digit year prefix of every known subseries
    /// identifier. Falls back to 1861-01-01…1992-12-31 when the manifest is empty.
    /// Recomputed whenever `diffResult` or `bundledEntries` changes (no manual caching
    /// needed because `@Observable` tracks property access automatically).
    ///
    /// Typical result for the full 552-volume corpus: `1861-01-01...1992-12-31`.
    public var corpusDateRange: ClosedRange<Date> {
        let source = diffResult?.known ?? bundledEntries
        let years = source.compactMap { Int($0.subseries.prefix(4)) }
        let minYear = years.min() ?? 1861
        let maxYear = years.max() ?? 1992
        return Self.corpusYearStart(minYear)...Self.corpusYearEnd(maxYear)
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
    }

    // MARK: - Initialization

    public init() {
        bundledEntries = Self.loadBundledManifest()
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
        (diffResult?.known ?? bundledEntries).first { $0.volumeId == id }
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
            diffResult = diff(bundled: bundledEntries, live: liveEntries)
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
            guard let liveEntry = liveByFilename[entry.filename] else { continue }
            liveInfoByVolumeId[entry.volumeId] = LiveVolumeInfo(sha: liveEntry.sha, sizeBytes: liveEntry.size)
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
    let sha: String

    enum CodingKeys: String, CodingKey {
        case name, size, sha
        case downloadUrl = "download_url"
    }
}
