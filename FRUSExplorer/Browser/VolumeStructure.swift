// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - VolumeSection

/// A structural section of a FRUS volume — compilation, chapter, appendix, etc.
///
/// Produced by `FRUSDocumentParser.parseVolumeStructure(volumeURL:)` and used by the
/// Browser view's Volume and Compilation/Chapter levels.
///
/// ## Hierarchy
/// A typical volume body contains compilations, each of which may contain chapters.
/// Documents appear as direct children of either a compilation or a chapter. Front
/// and back matter sections also carry a `VolumeSection` with type `"front"` / `"back"`.
///
/// Version history:
///   1.0 — Session 11: initial implementation
public struct VolumeSection: Sendable, Identifiable {

    /// The `xml:id` attribute of the enclosing `<div>`, or a generated stable string
    /// if the element lacks one. e.g. `"c1"`, `"app1"`, `"front"`.
    public let sectionId: String

    /// The TEI `type` attribute value. e.g. `"compilation"`, `"chapter"`, `"appendix"`,
    /// `"preface"`, `"front"`, `"back"`.
    public let divType: String

    /// The section's `<head>` text, or a humanised fallback derived from `divType`.
    public let title: String

    /// `xml:id` values of `<div type="document">` elements that are *direct* children
    /// of this section (not nested inside a subsection).
    public let documentIds: [String]

    /// Nested sub-sections, e.g. chapters within a compilation.
    public let subsections: [VolumeSection]

    public var id: String { sectionId }

    /// All document IDs reachable from this section or any of its subsections.
    public var allDocumentIds: [String] {
        documentIds + subsections.flatMap(\.allDocumentIds)
    }
}

// MARK: - VolumeStructure

/// The top-level structural outline of a FRUS volume.
///
/// Produced by `FRUSDocumentParser.parseVolumeStructure(volumeURL:)`. Contains
/// enough information to populate the Browser view's Volume level (section list)
/// and Compilation/Chapter level (document ID list for a given section).
///
/// Version history:
///   1.0 — Session 11: initial implementation
public struct VolumeStructure: Sendable {
    /// The volume this structure belongs to.
    public let volumeId: String

    /// All top-level sections in document order: front matter, compilations,
    /// appendices, back matter, etc.
    public let sections: [VolumeSection]

    /// Whether the volume has any structural sections at all.
    public var isEmpty: Bool { sections.isEmpty }
}

// MARK: - DocumentBrowserEntry

/// Lightweight metadata for a single FRUS document, used by the Browser's
/// Compilation/Chapter level to populate its document list.
///
/// Sourced from the `document_cache` SQLite table populated by `IndexingPipeline`.
/// Does not include the full document content — that is loaded by `FRUSDocumentParser`
/// when the user taps through to the Document view (Session 12).
///
/// Version history:
///   1.0 — Session 11: initial implementation
public struct DocumentBrowserEntry: Sendable, Identifiable, Hashable {
    /// The document's `xml:id` value within its volume.
    public let documentId: String

    /// The volume this document belongs to.
    public let volumeId: String

    /// Printed document number extracted from the `<head>`, if present.
    public let documentNumber: String?

    /// Document heading / title line.
    public let header: String

    /// Dateline string, if present.
    public let dateline: String?

    /// Source note (archival provenance), if present.
    public let sourceNote: String?

    public var id: String { "\(volumeId)/\(documentId)" }
}

// MARK: - CorpusStats

/// Aggregate statistics computed from the volume manifest, displayed at the
/// Browser's Corpus level.
///
/// Version history:
///   1.0 — Session 11: initial implementation
public struct CorpusStats: Sendable {
    public let totalVolumes: Int
    public let totalDocuments: Int
    public let earliestDocumentDate: String?
    public let latestDocumentDate: String?
    public let earliestPublicationDate: String?
    public let latestPublicationDate: String?
}

// MARK: - SubseriesGroup

/// Metadata aggregated across all volumes in a single FRUS subseries.
///
/// Used by the Browser's Corpus level (subseries list) and Subseries level
/// (header statistics and volume list).
///
/// Version history:
///   1.0 — Session 11: initial implementation
public struct SubseriesGroup: Sendable, Identifiable {
    /// The subseries identifier, e.g. `"1969-76"`, `"1861"`.
    public let subseries: String

    /// All manifest entries in this subseries, in chronological order.
    public let volumes: [VolumeManifestEntry]

    public var id: String { subseries }

    // MARK: - Derived statistics

    public var totalVolumes: Int { volumes.count }
    public var totalDocuments: Int { volumes.reduce(0) { $0 + $1.documentCount } }

    public var publishedCount: Int      { volumes.filter { $0.status == .published }.count }
    public var partiallyPublishedCount: Int { volumes.filter { $0.status == .partiallyPublished }.count }
    public var plannedCount: Int        { volumes.filter { $0.status == .planned }.count }

    /// Earliest document date across all volumes in the subseries (ISO 8601 string).
    public var earliestDate: String? {
        volumes.compactMap(\.dateRange.earliest).min()
    }

    /// Latest document date across all volumes in the subseries (ISO 8601 string).
    public var latestDate: String? {
        volumes.compactMap(\.dateRange.latest).max()
    }

    /// Numeric start year for chronological sorting (first 4 digits of the subseries string).
    public var startYear: Int {
        Int(subseries.prefix(4)) ?? 0
    }
}
