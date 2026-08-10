// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - Manifest Entry

/// Rich metadata for a single FRUS volume in the bundled `manifest.json`.
///
/// Generated at release time by `ManifestGenerator` from each volume's `<teiHeader>`.
/// Decoded at app launch by `ManifestStore` to power the Browser view, download management,
/// and volume-level tag filtering.
///
/// The `tags` field contains volume-level subject tag slugs extracted from:
/// ```
/// /TEI/teiHeader/profileDesc/textClass/keywords[@scheme="https://history.state.gov/tags"]/term
/// ```
/// These are authoritative OH-curated tags embedded in published TEI. An empty array is valid
/// for volumes predating the tagging system — it is not an error or missing data.
/// Slugs resolve against `volume-tag-taxonomy.json` for display names and hierarchy.
///
/// `documentCount` is set to 0 when not available from the `<teiHeader>` alone (full-body
/// parsing is required for an accurate count and is out of scope for the generator tool).
///
/// Version history:
///   1.0 — Session 02: initial implementation
public struct VolumeManifestEntry: Codable, Sendable, Equatable {
    public let volumeId: String
    public let filename: String
    public let subseries: String
    public let title: String
    public let dateRange: DateRange
    public let publicationDate: String?     // ISO 8601 or free-form year; nil if absent
    public let status: VolumeStatus         // .published | .partiallyPublished | .planned
    public let editors: [String]
    public let generalEditor: String?
    public let documentCount: Int           // 0 when not extractable from teiHeader alone
    public let sizeBytes: Int               // File size reported by GitHub API
    public let tags: [String]              // Volume-level tag slugs; [] is valid

    public init(
        volumeId: String, filename: String, subseries: String, title: String,
        dateRange: DateRange, publicationDate: String?, status: VolumeStatus,
        editors: [String], generalEditor: String?, documentCount: Int,
        sizeBytes: Int, tags: [String]
    ) {
        self.volumeId = volumeId
        self.filename = filename
        self.subseries = subseries
        self.title = title
        self.dateRange = dateRange
        self.publicationDate = publicationDate
        self.status = status
        self.editors = editors
        self.generalEditor = generalEditor
        self.documentCount = documentCount
        self.sizeBytes = sizeBytes
        self.tags = tags
    }
}

/// Publication status of a FRUS volume.
public enum VolumeStatus: String, Codable, Sendable {
    /// Volume is fully published and available.
    case published

    /// Volume is partially published; some content is available but the volume is not complete.
    case partiallyPublished

    /// Volume is planned but not yet published. May appear in manifests as a placeholder.
    case planned
}

/// The earliest and latest document dates within a FRUS volume.
///
/// Both values are ISO 8601 date strings (`yyyy-MM-dd`). Either or both may be nil
/// if the `<teiHeader>` does not contain date-range information.
public struct DateRange: Codable, Sendable, Equatable {
    public let earliest: String?    // ISO 8601
    public let latest: String?      // ISO 8601

    public init(earliest: String?, latest: String?) {
        self.earliest = earliest
        self.latest = latest
    }
}

// MARK: - GitHub API

/// File metadata returned by the GitHub Contents API for a single file in a repository directory.
///
/// Entries with `size < 20_000` bytes are excluded from all download functionality.
/// This threshold filters out index/placeholder XML files that are not real FRUS volumes.
///
/// Version history:
///   1.0 — Session 02: initial implementation
public struct GitHubVolumeEntry: Codable, Sendable {
    public let name: String
    public let size: Int
    public let sha: String
    public let downloadUrl: String

    enum CodingKeys: String, CodingKey {
        case name, size, sha
        case downloadUrl = "download_url"
    }
}

// MARK: - Parsed TEI Header

/// Intermediate representation of metadata extracted from a FRUS `<teiHeader>`.
///
/// Produced by `TEIHeaderParser` and consumed by `ManifestGeneratorRunner` to assemble
/// a `VolumeManifestEntry`. Not part of the persisted manifest format.
///
