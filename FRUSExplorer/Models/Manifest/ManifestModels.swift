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
/// embedded in each volume's published TEI (resolved via `VolumeLevelTag`). An empty
/// array is valid — some volumes predate the tagging system.
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

    /// Where this entry came from — the published catalogue, or the user's own file (#777).
    ///
    /// Defaulted and **not decoded**, so `manifest.json` is unchanged and every one of its 552
    /// entries is `.publishedCatalogue` without a byte moving. Only `LocalVolumeCatalog` mints
    /// the other case.
    public var provenance: VolumeOrigin = .publishedCatalogue

    public var id: String { volumeId }

    /// Constructs the GitHub raw download URL for this volume.
    ///
    /// Derived from `filename` at call time rather than stored in the manifest,
    /// since the URL scheme is stable and this avoids regenerating the manifest
    /// whenever GitHub changes the raw host (which it hasn't in a decade).
    ///
    /// Version history:
    ///   1.0 — New UI scaffolding: added so new macOS UI can enqueue downloads
    ///          without constructing the URL inline at every call site.
    ///   1.1 — Session 2026-08-09 (#777): **optional.** A side-loaded volume has no catalogue
    ///          URL, and this property is computed FROM THE FILENAME — so returning one anyway
    ///          would hand every repair path a plausible GitHub address that 404s, or, worse,
    ///          silently resolves to a *different* volume if that filename is later published.
    ///          The optionality is the mechanism, not a nicety: it makes every consumer confront
    ///          the missing URL at compile time.
    public var downloadUrl: String? {
        guard provenance == .publishedCatalogue else { return nil }
        return "https://raw.githubusercontent.com/HistoryAtState/frus/master/volumes/\(filename)"
    }
}

// MARK: - VolumeOrigin

// (Named `VolumeOrigin`, not `VolumeProvenance`: SA-3's `SourceProvenanceData` already owns
// that name for a per-volume archival-provenance row, an unrelated idea.)

/// Whether a volume entry describes something the app can fetch, or something the user supplied.
///
/// The distinction is not bookkeeping. It decides three things that would otherwise be wrong for a
/// side-loaded volume: whether a download URL exists at all (`downloadUrl`), whether Free Up Space
/// may offer to delete it (`StorageRemovalPlan`), and — the one that matters most — whether a
/// citation may claim the document is published (`FRUSVolumeMetadata`). A pre-release cited as
/// published, with a canonical `history.state.gov` URL that resolves to nothing, is worse than no
/// citation at all.
///
/// Version history:
///   1.0 — Session 2026-08-09: #777
public enum VolumeOrigin: String, Codable, Sendable, Equatable {
    /// From `manifest.json` — the published FRUS catalogue.
    case publishedCatalogue
    /// From a file the user side-loaded. Not necessarily unpublished, but the app cannot tell.
    case sideloaded
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
