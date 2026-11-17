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

// MARK: - Enqueue Outcome

/// What `DownloadManager.enqueueDownload` did with a request (#1660).
///
/// Every decline used to be silent, so a caller that removed its row on return told the reader a
/// download had started when none had. Keeping Current reads this to say which happened.
///
/// Version history:
///   1.0 — #1660: initial implementation
public enum DownloadEnqueueOutcome: Sendable, Equatable {
    /// Added to the queue; a transfer starts when the queue reaches it.
    case queued
    /// A transfer of this volume is already under way or waiting, and it fetches the same file.
    case alreadyQueued
    /// On disk already, and the request did not ask to replace it.
    case alreadyDownloaded
    /// A side-loaded volume: it has no catalogue address to download from (#777).
    case noCatalogueURL
}

// MARK: - Transfer Outcome

/// How a volume's transfer ended, reported once per transfer to `onTransferFinished` (#1660).
///
/// Version history:
///   1.0 — #1660: initial implementation
public enum DownloadTransferOutcome: Sendable, Equatable {
    /// The file is on disk; `onVolumeDownloaded` indexes it.
    case succeeded
    /// The transfer failed and its automatic retries are spent.
    case failed(DownloadFailure)
    /// The reader cancelled it.
    case cancelled
}

/// Why a transfer failed, kept as the error's `URLError` code so a screen can word the common
/// causes itself, with the system's description for the rest (#1660).
///
/// Version history:
///   1.0 — #1660: initial implementation
public struct DownloadFailure: Sendable, Equatable {
    /// The failure's `URLError` code, or `nil` when the error was not a `URLError` (a file that
    /// could not be moved into place, for one).
    public let urlErrorCode: URLError.Code?
    /// The error's own description, for a cause no screen words itself.
    public let description: String

    /// Reads `error`'s code and description.
    public init(_ error: any Error) {
        self.urlErrorCode = (error as? URLError)?.code
        self.description = error.localizedDescription
    }

    /// A failure with the given parts, for tests.
    public init(urlErrorCode: URLError.Code?, description: String) {
        self.urlErrorCode = urlErrorCode
        self.description = description
    }
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
///   1.3 — L20 (#1920, HCD-1): `indexOverheadFactor` measured again, 0.86 where it was 2.8
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

    /// Empirical ratio of search index bytes to volume XML bytes, measured against a full
    /// 553-volume library.
    ///
    /// Measured 2026-11-16 (L20, #1920, HCD-1) on two full libraries at index version 74, kept from
    /// the retake sittings: an iPad Pro 13-inch simulator's and the Mac check copy's. Each held
    /// 3,339,186,418 bytes of volume XML. Of each index file, about 3.57 GB, 2.88 GB was in use and
    /// the rest free pages a re-index leaves until Compact Database; an index as first built (index
    /// version 71, kept from 2026-10-21) was 2.88 GB with almost none free. So:
    /// - the index in use, against the XML: **0.86**, the factor used here;
    /// - a file a re-index has left at full size: 1.07.
    ///
    /// Per volume, the index in use apportioned by each volume's share of the stored text runs from
    /// 0.71 to 1.01 times its XML (the 5th to the 95th percentile; 0.56 to 1.12 at the extremes,
    /// median 0.87), as markup is denser in some volumes than in others.
    ///
    /// **Until L20 this was 2.8**, from a measurement of 2026-05-31 (552 volumes, ~3.4 GB XML: a
    /// 10.09 GB index on macOS, 8.77 GB on iOS), which overstated the index by about three times
    /// once the index had shrunk; no figure had been taken again.
    ///
    /// ## What the index holds
    /// - **`document_cache`** — each document's header, dateline, source note and full unstemmed
    ///   body text, for snippets: 1.63 GB of the 2.88 GB as first built;
    /// - **FTS5's posting lists** (`frus_documents_data`): 0.68 GB;
    /// - **Auxiliary tables** — sources, revisions, cross-references, page ranges, person mentions,
    ///   subjects and their indexes: the rest.
    ///
    /// Use `indexOverheadFactor` for pre-download estimates and removal size
    /// calculations. Always prefix displayed estimates with "~" and note the variance.
    public static let indexOverheadFactor: Double = 0.86
}
