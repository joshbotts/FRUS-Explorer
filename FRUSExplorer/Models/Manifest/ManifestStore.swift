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

    /// Best-effort subseries extraction from a filename, for newly-available volumes.
    private func subseries(from filename: String) -> String? {
        guard filename.hasSuffix(".xml") else { return nil }
        let base = String(filename.dropLast(4))
        guard base.hasPrefix("frus"), base.count > 4 else { return nil }
        let afterFrus = String(base.dropFirst(4))
        if let range = afterFrus.range(of: #"v\d+"#, options: .regularExpression) {
            return String(afterFrus[..<range.lowerBound])
        }
        return afterFrus
    }
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
