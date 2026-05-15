// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - Volume Manifest Entry

/// Rich metadata for a single FRUS volume, decoded from the bundled `manifest.json`.
///
/// The manifest is generated at release time by the `ManifestGenerator` SPM tool and
/// committed to the repository. At app launch, `ManifestStore` decodes this from the
/// app bundle and merges it with the live GitHub API response.
///
/// The `tags` array contains volume-level subject tag slugs curated by OH staff and
/// embedded in each volume's published TEI. These are distinct from document-level
/// subject tags (see `SubjectTag`). An empty array is valid — some volumes predate
/// the tagging system.
///
/// Version history:
///   1.0 — Session 02: initial implementation
public struct VolumeManifestEntry: Codable, Sendable, Identifiable, Equatable {
    /// Unique identifier derived from the volume filename without extension.
    /// e.g. `"frus1969-76v01"`. Acts as the stable primary key across all data layers.
    public let volumeId: String

    /// Bare filename, e.g. `"frus1969-76v01.xml"`.
    public let filename: String

    /// Chronological subseries identifier extracted from the filename.
    /// e.g. `"1969-76"`, `"1977-80"`, `"1861"`. Used to group volumes in the Browser view.
    public let subseries: String

    /// Full volume title from the TEI `<titleStmt>`, with whitespace normalized.
    /// The raw TEI XML preserves indentation inside the title element, producing embedded
    /// newlines and runs of spaces. These are collapsed to single spaces on decode.
    public let title: String

    /// Earliest and latest document dates within the volume.
    public let dateRange: DateRange

    /// Publication date as a free-form string from the TEI `<publicationStmt>`.
    /// Typically a year (`"2003"`) or ISO date. `nil` if absent from the TEI header.
    public let publicationDate: String?

    /// Publication status.
    public let status: VolumeStatus

    /// Primary editors, excluding the general editor.
    public let editors: [String]

    /// The general editor of the subseries, if listed.
    public let generalEditor: String?

    /// Number of documents in the volume. `0` when not determinable from the TEI header alone.
    public let documentCount: Int

    /// File size in bytes as reported by the GitHub API. Used for download size estimates.
    public let sizeBytes: Int

    /// Volume-level subject tag slugs from the TEI `<teiHeader>`.
    /// Resolve against `VolumeLevelTagStore` for display names and hierarchy.
    public let tags: [String]

    public var id: String { volumeId }
}

// Custom Decodable conformance in an extension so the synthesized memberwise
// initializer is preserved for test construction.
extension VolumeManifestEntry {
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        volumeId        = try c.decode(String.self, forKey: .volumeId)
        filename        = try c.decode(String.self, forKey: .filename)
        subseries       = try c.decode(String.self, forKey: .subseries)
        let rawTitle    = try c.decode(String.self, forKey: .title)
        title           = rawTitle
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        dateRange       = try c.decode(DateRange.self, forKey: .dateRange)
        publicationDate = try c.decodeIfPresent(String.self, forKey: .publicationDate)
        status          = try c.decode(VolumeStatus.self, forKey: .status)
        editors         = try c.decode([String].self, forKey: .editors)
        generalEditor   = try c.decodeIfPresent(String.self, forKey: .generalEditor)
        documentCount   = try c.decode(Int.self, forKey: .documentCount)
        sizeBytes       = try c.decode(Int.self, forKey: .sizeBytes)
        let rawTags     = try c.decode([String].self, forKey: .tags)
        tags            = rawTags.reduce(into: [String]()) { seen, slug in
            if !seen.contains(slug) { seen.append(slug) }
        }
    }
}

/// Publication status of a FRUS volume.
public enum VolumeStatus: String, Codable, Sendable {
    case published
    case partiallyPublished
    case planned
}

/// The date range of documents within a FRUS volume.
///
/// Both values are ISO 8601 strings. Either may be `nil` for volumes where the TEI
/// header does not contain date-range information.
public struct DateRange: Codable, Sendable, Equatable {
    public let earliest: String?
    public let latest: String?
}
