// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - Download Scope

/// Describes the set of volumes the user chose to download during onboarding or from
/// Settings → Download Manager. Used by `OnboardingViewModel` and `AppState` to pass
/// a pending download intent to `DownloadManager.enqueueScope(_:manifestStore:)`.
///
/// Version history:
///   1.0 — Session 49: initial implementation
public enum DownloadScope: Sendable, Equatable {
    /// Download the complete FRUS corpus (all known volumes).
    case corpus

    /// Download all volumes belonging to a specific subseries identifier (e.g. `"1969-76"`).
    case subseries(String)

    /// Download a single volume identified by its `volumeId` (e.g. `"frus1969-76v10"`).
    case volume(String)
}

// MARK: - Download Manager State

/// A point-in-time snapshot of DownloadManager's queue, delivered to the MainActor
/// callback whenever the queue changes. Used to update AppState.downloadQueue.
///
/// Version history:
///   1.0 — Session 05: initial implementation
public struct DownloadManagerState: Sendable {
    /// Volume IDs whose downloads are actively running.
    public let activeVolumeIds: [String]

    /// Volume IDs waiting to start (respecting the concurrency limit).
    public let pendingVolumeIds: [String]

    /// All queued volume IDs: active first, then pending. Suitable for UI display.
    public var allQueuedVolumeIds: [String] { activeVolumeIds + pendingVolumeIds }
}

// MARK: - Storage Report

/// Per-volume storage usage. One entry per downloaded volume XML file.
///
/// Version history:
///   1.0 — Session 05: initial implementation
public struct VolumeStorageEntry: Sendable {
    /// The volume identifier, e.g. `"frus1969-76v01"`.
    public let volumeId: String

    /// Size in bytes of the downloaded XML file on disk.
    public let volumeFileBytes: Int
}

/// Aggregate storage usage across all downloaded volumes, the search index, and
/// generated summaries. Reported in the Settings screen (Session 24).
///
/// `totalIndexBytes` and `totalSummariesBytes` are populated by Session 09
/// (Search Index Pipeline) and Session 19 (AI Summarization) respectively.
/// They are zero until those sessions wire their directories into `DownloadManager`.
///
/// Version history:
///   1.0 — Session 05: initial implementation
public struct StorageReport: Sendable {
    /// Sum of all downloaded volume XML file sizes.
    public let totalVolumesBytes: Int

    /// Size of the FTS5 search index database. Populated in Session 09.
    public let totalIndexBytes: Int

    /// Size of stored AI-generated summaries. Populated in Session 19.
    public let totalSummariesBytes: Int

    /// Per-volume breakdown of XML file sizes.
    public let perVolume: [VolumeStorageEntry]

    /// Combined total of all managed storage.
    public var grandTotalBytes: Int { totalVolumesBytes + totalIndexBytes + totalSummariesBytes }
}
