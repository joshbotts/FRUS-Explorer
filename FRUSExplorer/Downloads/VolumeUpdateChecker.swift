// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// On-disk facts about a downloaded volume, used by `VolumeUpdateChecker` to detect
/// upstream corrections.
///
/// Produced by `DownloadManager.localVolumeInfo(for:)`. `sha` is `nil` only if hashing
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
public struct UpdatableVolume: Sendable, Identifiable, Equatable {
    public let entry: VolumeManifestEntry

    public var id: String { entry.volumeId }

    public init(entry: VolumeManifestEntry) {
        self.entry = entry
    }
}

/// Detects FRUS volumes that have been silently corrected upstream since the user
/// downloaded them.
///
/// ## Comparison Strategy
/// 1. **Preferred**: compare the local git blob SHA-1 (`LocalVolumeInfo.sha`,
///    computed by `DownloadManager.gitBlobSHA1(for:)`) against the live `sha`
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
    /// Local file reads and SHA-1 hashing happen on `downloadManager`'s actor, off
    /// the calling context. Intended to be called from a `Task` in response to an
    /// explicit "Check for Updates" action — not from a SwiftUI `body` or
    /// automatically at launch (corpus-wide hashing is too costly to run silently).
    public static func updatableVolumes(
        known: [VolumeManifestEntry],
        liveInfoByVolumeId: [String: LiveVolumeInfo],
        downloadManager: DownloadManager
    ) async -> [UpdatableVolume] {
        var results: [UpdatableVolume] = []
        for entry in known {
            guard let live = liveInfoByVolumeId[entry.volumeId],
                  downloadManager.isVolumeDownloaded(entry.volumeId),
                  let local = await downloadManager.localVolumeInfo(for: entry.volumeId),
                  hasUpdate(local: local, live: live)
            else { continue }
            results.append(UpdatableVolume(entry: entry))
        }
        return results
    }
}
