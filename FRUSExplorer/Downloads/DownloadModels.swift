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
///   1.1 — #1516: `figureBytes`, the volume's figure images, and `totalBytes`, what the volume
///          takes on the device and what Volumes & Storage shows for it.
public struct VolumeStorageEntry: Sendable {
    /// The volume identifier, e.g. `"frus1969-76v01"`.
    public let volumeId: String

    /// Size in bytes of the downloaded XML file on disk. The search index's size is estimated
    /// from this figure alone (`StorageReport.indexOverheadFactor`): images are not indexed.
    public let volumeFileBytes: Int

    /// Size in bytes of the volume's figure images on disk (#1516): zero for the 454 volumes of
    /// the 553 whose text names no image outside its title page, and for a volume whose images
    /// have not been fetched.
    public let figureBytes: Int

    /// The XML and the figure images together: what removing the volume's files frees.
    public var totalBytes: Int { volumeFileBytes + figureBytes }

    /// Creates an entry. `figureBytes` defaults to none.
    public init(volumeId: String, volumeFileBytes: Int, figureBytes: Int = 0) {
        self.volumeId = volumeId
        self.volumeFileBytes = volumeFileBytes
        self.figureBytes = figureBytes
    }
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
///   1.1 — Session 130: `indexOverheadFactor` constant added; calibrated with full-corpus
///          measurements (552 volumes: macOS 10.09 GB index, iOS 8.77 GB index, ~3.4 GB XML)
///   1.2 — #1516: `totalFigureBytes`, the volumes' figure images — a figure of its own, drawn as
///          its own segment of the Volumes & Storage bar, and part of `grandTotalBytes`.
public struct StorageReport: Sendable {
    /// Sum of all downloaded volume XML file sizes.
    public let totalVolumesBytes: Int

    /// Size of the FTS5 search index database. Populated in Session 09.
    public let totalIndexBytes: Int

    /// Size of stored AI-generated summaries. Populated in Session 19.
    public let totalSummariesBytes: Int

    /// Size of the downloaded semantic-vector shards (#926 item 2). Zero when the
    /// feature has fetched nothing. Counted HERE and nowhere else: the index walk
    /// explicitly excludes the shard directory, because before this field existed the
    /// recursive walk silently folded shard bytes (and the volume XML) into "Index" and
    /// the hero figure double-counted.
    public let totalVectorBytes: Int

    /// Size of the downloaded volumes' figure images (#1516): the sum of each `perVolume`
    /// entry's `figureBytes`. They sit in folders inside the volumes directory, which the index
    /// walk excludes whole, so they are counted here and nowhere else.
    public let totalFigureBytes: Int

    /// Per-volume breakdown of XML file and figure-image sizes.
    public let perVolume: [VolumeStorageEntry]

    /// Creates a report. `totalFigureBytes` defaults to none.
    public init(totalVolumesBytes: Int, totalIndexBytes: Int, totalSummariesBytes: Int,
                totalVectorBytes: Int, totalFigureBytes: Int = 0, perVolume: [VolumeStorageEntry]) {
        self.totalVolumesBytes = totalVolumesBytes
        self.totalIndexBytes = totalIndexBytes
        self.totalSummariesBytes = totalSummariesBytes
        self.totalVectorBytes = totalVectorBytes
        self.totalFigureBytes = totalFigureBytes
        self.perVolume = perVolume
    }

    /// Combined total of all managed storage.
    public var grandTotalBytes: Int {
        totalVolumesBytes + totalIndexBytes + totalSummariesBytes + totalVectorBytes + totalFigureBytes
    }

    // MARK: - Index size estimation

    /// Empirical ratio of search index bytes to volume XML bytes, calibrated against
    /// a full 552-volume FRUS corpus download.
    ///
    /// Measurements (all 552 volumes, ~3.4 GB XML):
    /// - macOS: 10.09 GB index → factor ≈ 2.97
    /// - iOS:    8.77 GB index → factor ≈ 2.58
    /// - Cross-platform average used here: **2.8**
    ///
    /// ## Why the index is so large
    /// The index database stores document text in multiple forms to support fast
    /// full-text search and TEI-faithful snippet rendering:
    /// - **FTS5 posting lists** — token → document mapping (compressed but still large)
    /// - **`document_cache.body_text`** — full unstemmed body text per document,
    ///   used for snippet regeneration after FTS5 returns results
    /// - **`document_cache` other columns** — header, dateline, source note, summaries
    /// - **Auxiliary tables** — cross_references, page_ranges, person_mentions,
    ///   persons, terms, document_dates
    ///
    /// XML files contain substantial tag markup that takes space but isn't indexed,
    /// so the searchable text content per byte of XML is denser than the ratio suggests.
    /// The actual factor ranges from ~2.5× for short volumes to ~3.0× for long ones.
    ///
    /// Use `indexOverheadFactor` for pre-download estimates and removal size
    /// calculations. Always prefix displayed estimates with "~" and note the variance.
    public static let indexOverheadFactor: Double = 2.8
}
