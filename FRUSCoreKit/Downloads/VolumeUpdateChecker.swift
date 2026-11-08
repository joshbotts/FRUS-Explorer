// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

/// On-disk facts about a downloaded volume, used by `VolumeUpdateChecker` to detect
/// upstream corrections.
///
/// Produced by a `DownloadedVolumeFiles`, the app's `DownloadManager` or a host's library
/// (`localVolumeInfo(for:)`). `sha` is `nil` only if hashing
/// the file failed; `sizeBytes` is `nil` only if the volume is not downloaded.
public struct LocalVolumeInfo: Sendable, Equatable {
    /// Git blob SHA-1 of the on-disk file's contents, in the same form as
    /// `LiveVolumeInfo.sha`. `nil` if hashing failed.
    public let sha: String?

    /// On-disk file size in bytes.
    public let sizeBytes: Int?

    public init(sha: String?, sizeBytes: Int?) {
        self.sha = sha
        self.sizeBytes = sizeBytes
    }
}

/// A downloaded volume whose live copy on GitHub differs from the local copy,
/// paired with its bundled metadata for display.
///
/// Version history:
///   1.0 — Session 154: initial implementation
///   1.1 — #1660: `isSideloaded`
public struct UpdatableVolume: Sendable, Identifiable, Equatable {
    /// The volume's catalogue entry.
    public let entry: VolumeManifestEntry

    /// Whether the file on this device is one the reader side-loaded under the catalogue
    /// volume's name (`DownloadManager.isSideloaded(_:)`), which Update replaces (#1660).
    public let isSideloaded: Bool

    /// The volume's id.
    public var id: String { entry.volumeId }

    /// A volume listed by a check.
    public init(entry: VolumeManifestEntry, isSideloaded: Bool = false) {
        self.entry = entry
        self.isSideloaded = isSideloaded
    }
}

/// The downloaded volumes a corrections check reads: whether each is on disk, its
/// `LocalVolumeInfo`, and whether the reader side-loaded it.
///
/// The app's `DownloadManager` conforms, keeping its hashes in its preferences and reading them on
/// its actor; a host outside the app conforms its own library of volume files.
///
/// Version history:
///   1.0 — Session 2026-11-08 (FRUS Explorer Light, S21a): what
///          `VolumeUpdateChecker.updatableVolumes` reads in place of `DownloadManager`, which it
///          took until it moved into FRUSCoreKit
public protocol DownloadedVolumeFiles: Sendable {
    /// Whether the volume's file is on disk.
    func isVolumeDownloaded(_ volumeId: String) -> Bool

    /// On-disk facts about a downloaded volume, or `nil` if it is not downloaded.
    func localVolumeInfo(for volumeId: String) async -> LocalVolumeInfo?

    /// Whether the file on disk is one the reader side-loaded under the catalogue volume's name,
    /// which Update replaces.
    func isSideloaded(_ volumeId: String) async -> Bool
}

/// Detects FRUS volumes that have been silently corrected upstream since the user
/// downloaded them.
///
/// ## Comparison Strategy
/// 1. **Preferred**: compare the local git blob SHA-1 (`LocalVolumeInfo.sha`,
///    computed by `gitBlobSHA1(for:)`) against the live `sha`
///    GitHub's contents API reports for the same file. An exact, content-based
///    comparison that is insensitive to incidental metadata changes.
/// 2. **Fallback**: if no local SHA is available, compare on-disk byte count
///    against the live `size`. Corrections virtually always change file size, so
///    this still catches the common case.
///
/// `hasUpdate(local:live:)` is a pure function over fixture-friendly value types so
/// it can be unit tested without file I/O or network access. `updatableVolumes(...)`
/// is the orchestration entry point used by the Downloads settings views.
///
/// Version history:
///   1.0 — Session 154: initial implementation
///   1.1 — Session 2026-11-08 (FRUS Explorer Light, S21a): moved into FRUSCoreKit from the app's
///          `Downloads/`, with `gitBlobSHA1(for:)`, which was `DownloadManager`'s and which
///          `DownloadManager.gitBlobSHA1(for:)` forwards to; `updatableVolumes` reads a
///          `DownloadedVolumeFiles` in place of `DownloadManager`, which conforms. Otherwise
///          unchanged
public enum VolumeUpdateChecker {

    /// Returns `true` if `live` differs from the locally downloaded copy described
    /// by `local`.
    public static func hasUpdate(local: LocalVolumeInfo, live: LiveVolumeInfo) -> Bool {
        if let localSha = local.sha {
            return localSha != live.sha
        }
        if let localSize = local.sizeBytes {
            return localSize != live.sizeBytes
        }
        return false
    }

    /// Scans every downloaded volume in `known` and returns those whose live copy
    /// differs from the local copy, per `hasUpdate(local:live:)`.
    ///
    /// Local file reads and SHA-1 hashing happen in `downloadManager`, on its actor when it
    /// is one (the app's `DownloadManager` is), off the calling context. Intended to be called
    /// from a `Task` in response to an
    /// explicit "Check for Updates" action — not from a SwiftUI `body` or
    /// automatically at launch (corpus-wide hashing is too costly to run silently).
    public static func updatableVolumes(
        known: [VolumeManifestEntry],
        liveInfoByVolumeId: [String: LiveVolumeInfo],
        downloadManager: some DownloadedVolumeFiles
    ) async -> [UpdatableVolume] {
        var results: [UpdatableVolume] = []
        for entry in known {
            guard let live = liveInfoByVolumeId[entry.volumeId],
                  downloadManager.isVolumeDownloaded(entry.volumeId),
                  let local = await downloadManager.localVolumeInfo(for: entry.volumeId),
                  hasUpdate(local: local, live: live)
            else { continue }
            results.append(UpdatableVolume(entry: entry,
                                           isSideloaded: await downloadManager.isSideloaded(entry.volumeId)))
        }
        return results
    }

    /// Computes the git blob SHA-1 of `data`, in the same form GitHub's contents API
    /// reports for repository files: `sha1("blob <byte length>\0" + data)`.
    public static func gitBlobSHA1(for data: Data) -> String {
        var hasher = Insecure.SHA1()
        hasher.update(data: Data("blob \(data.count)\0".utf8))
        hasher.update(data: data)
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
