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
public struct ManifestDiffResult: Sendable {
    /// Volumes present in both manifests (use bundled rich metadata).
    public let known: [VolumeManifestEntry]

    /// Volumes present in the live listing only (newly released; no rich metadata yet).
    /// Displayed with a "newly available" badge in the Browser and download views.
    public let newlyAvailable: [NewlyAvailableVolume]

    /// Volumes in the bundled manifest but absent from the live listing.
    /// No longer published; hidden from download UI but downloaded copies are unaffected.
    public let noLongerPublished: [VolumeManifestEntry]
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
///   1.2 — Session 68: frusSubseries(from:) updated to match VolumeIDParser Session 54 logic
///          (strips Vietnam-extras, bare part numbers, known suffixes, and conference/topic
///          name suffixes) so newly-available volumes in the live diff get correct subseries
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

        return ManifestDiffResult(
            known: known,
            newlyAvailable: newlyAvailable,
            noLongerPublished: noLongerPublished
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
/// Mirrors the algorithm in `VolumeIDParser.subseries(from:)` (Session 54) so that
/// newly-available volumes in the live GitHub diff receive the same correct subseries
/// grouping as volumes in the bundled manifest.
///
/// Four passes strip non-subseries suffixes from the right:
///
/// 1. **`v[a-z]?\d+` volume marker** — strips standard volume numbers (`v01`) and
///    Vietnam-extras (`ve01`, `ve05p1`). E.g. `1969-76ve01` → `1969-76`.
/// 2. **Trailing `p\d+`** — bare part numbers with no volume marker. E.g. `1863p2` → `1863`.
/// 3. **Known string suffixes** (`sups`, `app`, `mf`). E.g. `1877app` → `1877`.
/// 4. **Trailing `[A-Z][a-z]+` conference/topic names**, applied iteratively.
///    E.g. `1943CairoTehran` → `1943Cairo` → `1943`.
///    A single trailing uppercase letter (subseries letter, e.g. `G` in `1952-54G`)
///    is NOT stripped because it does not match `[A-Z][a-z]+`.
///
/// | Filename                    | Result    |
/// |-----------------------------|-----------|
/// | `frus1969-76v01.xml`        | `1969-76` |
/// | `frus1969-76ve01.xml`       | `1969-76` |
/// | `frus1969-76ve05p1.xml`     | `1969-76` |
/// | `frus1863p2.xml`            | `1863`    |
/// | `frus1877app.xml`           | `1877`    |
/// | `frus1943CairoTehran.xml`   | `1943`    |
/// | `frus1952-54Gv01.xml`       | `1952-54G`|
/// | `frus1861.xml`              | `1861`    |
///
/// Returns `nil` for filenames that are not `frus*.xml`.
///
/// Declared at module scope (not inside `ManifestStore`) so that `ManifestStoreTests`
/// can exercise it directly via `@testable import` without access-level friction.
func frusSubseries(from filename: String) -> String? {
    guard filename.hasSuffix(".xml") else { return nil }
    let base = String(filename.dropLast(4))           // strip ".xml"
    guard base.hasPrefix("frus"), base.count > 4 else { return nil }
    var s = String(base.dropFirst(4))                 // strip "frus"

    // Pass 1: v[a-z]?\d+ covers standard volumes (v01) and Vietnam-extras (ve01, ve05p2…).
    // Match from the marker to end-of-string and discard everything from there.
    if let range = s.range(of: #"v[a-z]?\d+.*$"#, options: .regularExpression) {
        let result = String(s[..<range.lowerBound])
        return result.isEmpty ? nil : result
    }

    // Pass 2: trailing bare part number (no volume marker), e.g. "1863p2".
    if let range = s.range(of: #"p\d+$"#, options: .regularExpression) {
        s = String(s[..<range.lowerBound])
    }

    // Pass 3: known non-subseries string suffixes (longest first to avoid partial matches).
    for suffix in ["sups", "app", "mf"] where s.hasSuffix(suffix) {
        s = String(s.dropLast(suffix.count)); break
    }

    // Pass 4: trailing conference/topic names of the form [A-Z][a-z]+, iteratively stripped.
    // Single trailing uppercase letters (e.g. "G" in "1952-54G") are preserved.
    var changed = true
    while changed {
        changed = false
        if let r = s.range(of: #"[A-Z][a-z]+$"#, options: .regularExpression) {
            s = String(s[..<r.lowerBound])
            changed = true
        }
    }

    return s.isEmpty ? nil : s
}

// MARK: - Internal Live Entry Type

/// Minimal GitHub API response entry used only for the live diff.
private struct GitHubLiveEntry: Codable {
    let name: String
    let size: Int
    let downloadUrl: String

    enum CodingKeys: String, CodingKey {
        case name, size
        case downloadUrl = "download_url"
    }
}
