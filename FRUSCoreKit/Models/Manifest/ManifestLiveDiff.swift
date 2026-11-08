// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// The live GitHub listing and its diff against the bundled manifest, moved here from the app's
// `Models/Manifest/ManifestStore.swift` (FRUS Explorer Light, S21a, 2026-11-08) so that a host
// outside the app reads the listing and finds a corrected volume as the app does. Each declaration
// is unchanged but for access: the entry is public, with the `Sendable` Swift inferred while it was
// private; the diff, a private method of the store, is `ManifestDiffResult.diff(bundled:live:)`, with
// its helper `subseries(from:)` a private static beside it; and the fetch's decode and filter are the
// entry's `volumes(inListing:)`.
// The store, its fetch and `LiveListingError`, which reads an HTTP response, stay in the app.

// MARK: - The Live Listing's Diff

/// The result of diffing the bundled manifest against the live GitHub listing.
///
/// Version history:
///   1.0 — Session 02: initial implementation
///   1.1 — Session 154: added `liveInfoByVolumeId`, capturing the live git blob SHA
///          and byte size for every `known` volume so `VolumeUpdateChecker` can
///          detect upstream corrections to already-downloaded volumes.
///   1.2 — Session 2026-11-08 (FRUS Explorer Light, S21a): moved into FRUSCoreKit with the diff
///          that makes it, `diff(bundled:live:)`, unchanged
public struct ManifestDiffResult: Sendable {
    /// Volumes present in both manifests (use bundled rich metadata).
    public let known: [VolumeManifestEntry]

    /// Volumes present in the live listing only (newly released; no rich metadata yet).
    ///
    /// **Computed and rendered NOWHERE**, by decision D-1 in `New-Volume-Release-Plan.md`, which
    /// left the publication-to-release gap silent. This comment used to claim a "newly available"
    /// badge in the Browser and download views; there is no such badge, and neither surface reads
    /// this property. Nor could a badge alone fix it: every consumer of a `ManifestDiffResult`
    /// reads ``known``, which is a filter OVER the bundled manifest and so can only shrink — a
    /// volume published since this build shipped is not in `bundled`, has no rich metadata and no
    /// download URL these surfaces read. Surfacing this bucket means growing a consumer.
    public let newlyAvailable: [NewlyAvailableVolume]

    /// Volumes in the bundled manifest but absent from the live listing.
    ///
    /// No longer published; downloaded copies are unaffected. They are indeed absent from the
    /// download UI — but by the construction of ``known``, which filters the bundled manifest
    /// against the live listing, NOT by anything reading this property. Like ``newlyAvailable``
    /// it is computed and unconsumed.
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

// MARK: - Live Entry Type

/// Minimal GitHub API response entry used only for the live diff.
///
/// Version history:
///   1.0 — Session 02: with `ManifestStore`'s live diff
///   1.1 — Session 154: `sha`
///   1.2 — Session 2026-11-08 (FRUS Explorer Light, S21a): moved into FRUSCoreKit from the app's
///          `ManifestStore.swift`, public and `Sendable`, with `volumes(inListing:)`, the decode and
///          filter of `ManifestStore`'s fetch, unchanged
public struct GitHubLiveEntry: Codable, Sendable {
    public let name: String
    public let size: Int
    public let downloadUrl: String
    /// Git blob SHA-1 of the file's current contents, used by `VolumeUpdateChecker`
    /// to detect upstream corrections to already-downloaded volumes (Session 154).
    /// Optional so a listing entry that ever omits it degrades to "no update
    /// detection for that volume" instead of failing the whole manifest decode.
    public let sha: String?

    enum CodingKeys: String, CodingKey {
        case name, size, sha
        case downloadUrl = "download_url"
    }

    /// The volumes in GitHub's listing of the corpus's `volumes` folder
    /// (`GET https://api.github.com/repos/HistoryAtState/frus/contents/volumes`): its `.xml`
    /// entries of 20,000 bytes or more.
    ///
    /// - Parameter data: The listing's body, as the contents API answers.
    /// - Throws: The decoder's error when the body is not a list of entries.
    public static func volumes(inListing data: Data) throws -> [GitHubLiveEntry] {
        let all = try JSONDecoder().decode([GitHubLiveEntry].self, from: data)
        return all.filter { $0.name.hasSuffix(".xml") && $0.size >= 20_000 }
    }
}

// MARK: - The Diff

extension ManifestDiffResult {

    /// Diffs the bundled manifest against the live GitHub listing.
    public static func diff(bundled: [VolumeManifestEntry], live: [GitHubLiveEntry]) -> ManifestDiffResult {
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
    private static func subseries(from filename: String) -> String? {
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
