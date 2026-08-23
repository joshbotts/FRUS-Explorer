// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
// For the `NavigationPath` overload of `DocumentJump.apply` below: one reader host
// (CitationLookupView) keeps a NavigationPath rather than an array, and leaving it as the single
// hand-written copy of the rule is what let the rule go untested in the first place.
import SwiftUI

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
///   1.1 — Session 2026-06-09: `Codable` conformance added so structures can be
///          persisted to the `volume_structures` table at index time and served to
///          the Browser without re-parsing the volume XML.
///   2.0 — Session 2026-06-10: `divType` now carries the *effective section kind*
///          derived from the real corpus encoding (`type="section"` + `subtype` +
///          `xml:id`), not the raw `type` attribute. Kind-classification helpers
///          (`isFrontMatterKind`, `canReadDirectly`, `isPersonsList`, …) centralise
///          the routing rules previously duplicated across `VolumeView`,
///          `CompilationView`, and the macOS corpus browser.
public struct VolumeSection: Sendable, Identifiable, Codable, Hashable {

    /// The `xml:id` attribute of the enclosing `<div>`, or a generated stable string
    /// if the element lacks one. e.g. `"c1"`, `"app1"`, `"front"`.
    public let sectionId: String

    /// The section's effective kind.
    ///
    /// For body structure this is the TEI `type` attribute (`"compilation"`,
    /// `"chapter"`, `"subchapter"`, `"appendix"`). For front/back matter — which the
    /// real corpus encodes as `<div type="section" subtype="…">` — this is the
    /// normalised kind derived from `subtype` and `xml:id` by
    /// `FRUSDocumentParser` (e.g. `"preface"`, `"sources"`, `"persons"`, `"terms"`,
    /// `"table-of-contents"`, `"press-release"`, `"volume-summary"`,
    /// `"about-frus-series"`, `"errata"`, `"index"`, `"historical-document"`).
    /// `"front"` / `"back"` mark the wrapper elements themselves.
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

    // MARK: - Kind Classification (single source of truth for browser routing)

    /// Kinds that belong to the browser's "Front Matter" group (including the
    /// `"front"` wrapper itself, which the UI expands inline).
    public static let frontMatterKinds: Set<String> = [
        "front", "preface", "intro", "introduction", "errata", "foreword",
        "prefatoryNote", "sources", "persons", "terms",
        "table-of-contents", "press-release", "volume-summary",
        "about-frus-series", "historical-document", "section",
    ]

    /// Kinds whose content is prose (or a rendered list) that `DocumentView` can
    /// display directly via the `xml:id`-matching quasi-document parse — no FTS
    /// indexing required.
    ///
    /// `"persons"` and `"sources"` are deliberately absent: they route to the
    /// structured `FrontMatterPersonsView` / `VolumeSourcesView` instead.
    public static let proseReadableKinds: Set<String> = [
        "preface", "intro", "introduction", "errata", "foreword",
        "prefatoryNote", "terms", "appendix",
        "table-of-contents", "press-release", "volume-summary",
        "about-frus-series", "historical-document", "index", "section",
    ]

    /// `true` when this section belongs in the browser's "Front Matter" group.
    public var isFrontMatterKind: Bool {
        Self.frontMatterKinds.contains(divType)
    }

    /// `true` when this section is the structured Persons glossary, which routes to
    /// `FrontMatterPersonsView` rather than a document list.
    public var isPersonsList: Bool { divType == "persons" }

    /// `true` when this section is the structured archival Sources list, which routes
    /// to `VolumeSourcesView` rather than a document list.
    public var isSourcesList: Bool { divType == "sources" }

    /// `true` when this is a prose-only leaf section that can be opened directly in
    /// `DocumentView` (the parser locates the `<div>` by `xml:id`, so a real ID from
    /// the TEI source is required — auto-generated fallback IDs are excluded).
    public var canReadDirectly: Bool {
        guard Self.proseReadableKinds.contains(divType),
              documentIds.isEmpty,
              subsections.isEmpty
        else { return false }
        return hasExplicitSectionId
    }

    /// `true` when `sectionId` came from an `xml:id` in the TEI source rather than
    /// the parser's auto-generated `"<kind>-<n>"` fallback for ID-less elements.
    public var hasExplicitSectionId: Bool {
        guard !sectionId.isEmpty else { return false }
        let autoPrefix = "\(divType)-"
        if sectionId.hasPrefix(autoPrefix) {
            let suffix = sectionId.dropFirst(autoPrefix.count)
            if !suffix.isEmpty, suffix.allSatisfy(\.isNumber) { return false }
        }
        return true
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
///   1.1 — Session 2026-06-09: `Codable` conformance added (see `VolumeSection`).
public struct VolumeStructure: Sendable, Codable {
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
///   1.1 — Session 38: `isEditorialNote` field added
/// How a document-to-document jump should affect the host's navigation stack (#751).
///
/// Lives here rather than in `DocumentView.swift` because that file is iOS-only, while the hosts
/// that act on a jump (`SearchView`, `BrowserView`, the reader sheets) are cross-platform — the
/// enum has no platform dependency of its own.
public enum DocumentJump: Sendable {
    /// Descend: the reader followed a link *out of* the current document, so Back should return to
    /// it. Cross-references and page references.
    case push
    /// Move sideways: the reader turned the page, so the new document **replaces** the current one.
    /// A page-turn is a change of reading position, not a descent into it.
    ///
    /// Appending instead is what made paging through twenty documents cost twenty Back taps, with
    /// no breadcrumb escape at document level and none at all on regular-width iPad (audit M-17a).
    case replace
}

// MARK: - Applying a jump to a host's path

extension DocumentJump {

    /// Applies this jump to a reader host's navigation path, appending `entry`.
    ///
    /// ## Why this is a function and not three lines in each host
    /// Ten reader hosts route document-to-document jumps, and every one of them carried the same
    /// copy-pasted `if jump == .replace { removeLast() }; append(...)`. That is ten places for the
    /// rule to drift, and — more to the point — ten places where it could NOT be tested: each copy
    /// sat in a `private func` inside a `View` struct, reachable only by a source scan.
    ///
    /// **The source scan was vacuous, and this was measured rather than suspected.** The guard
    /// asserted that the literal `jump == .replace` appeared in each host's file, over RAW source
    /// (`HandoffVisibilityTests.hostsImplementReplace`). Deleting `vm.navigationPath.removeLast()`
    /// from `BrowserView` leaves that literal untouched, so the mutant reinstated M-17a in full —
    /// twenty page-turns costing twenty Back taps — and the suite stayed GREEN. Verified by running
    /// it 2026-08-20. Extracting the rule is what lets a real test observe the depth.
    ///
    /// - Parameters:
    ///   - path: The host's stack. `.replace` pops its top entry first; `.push` leaves it.
    ///   - entry: The document level to append.
    public func apply<Entry>(to path: inout [Entry], appending entry: Entry) {
        // The empty check is not defensive noise: `.replace` fires on a page-turn, and a host
        // whose path is empty is showing the document as its own root (the macOS document window,
        // and a sheet opened directly onto a document). Popping there would empty the stack and
        // leave the host with nothing to show.
        if self == .replace, !path.isEmpty {
            path.removeLast()
        }
        path.append(entry)
    }

    /// The `NavigationPath` overload, for a host that keeps an opaque path rather than an array.
    ///
    /// `DocumentBrowserEntry` is `Hashable` and NOT `Codable`, so this resolves to the same
    /// `append` overload the hand-written call did — a path that was never codable stays
    /// non-codable, and no state-restoration behaviour changes.
    public func apply(to path: inout NavigationPath, appending entry: some Hashable) {
        if self == .replace, !path.isEmpty {
            path.removeLast()
        }
        path.append(entry)
    }
}

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

    /// Whether this entry is a FRUS editorial note rather than a primary-source document.
    /// Set to `true` for entries whose `document_cache.is_editorial_note` value is 1.
    public let isEditorialNote: Bool

    /// A footnote within this document to reveal on arrival — the note's TEI `xml:id`
    /// (`d748fn3`), or `nil` for an ordinary open (#988).
    ///
    /// It rides on the navigation value rather than on the web view's coordinator because
    /// **90.8% of the corpus's 16,921 footnote references point into a different document**, and
    /// crossing a document boundary mounts a fresh `DocumentView`/`MacDocumentView`, hence a fresh
    /// representable, coordinator and `WKWebView`. State parked on the coordinator would serve
    /// only the 8.5% that stay put.
    ///
    /// Deliberately **not** part of `id`, which stays `volumeId/documentId`: two references to
    /// different notes in one document are the same destination, and letting the anchor split the
    /// identity would push a duplicate level onto every navigation stack keyed by it.
    public let footnoteAnchor: String?

    public var id: String { "\(volumeId)/\(documentId)" }

    public init(
        documentId: String,
        volumeId: String,
        documentNumber: String? = nil,
        header: String,
        dateline: String? = nil,
        sourceNote: String? = nil,
        isEditorialNote: Bool = false,
        footnoteAnchor: String? = nil
    ) {
        self.documentId = documentId
        self.volumeId = volumeId
        self.documentNumber = documentNumber
        self.header = header
        self.dateline = dateline
        self.sourceNote = sourceNote
        self.isEditorialNote = isEditorialNote
        self.footnoteAnchor = footnoteAnchor
    }
}

// `CorpusStats` — removed #1051 B-1. Its display left in Session 130 (CorpusView 1.3), and its
// `totalDocuments` summed the manifest's structurally-dead `documentCount` field (0 in all 552
// entries — the header parser cannot compute it), so the value was a permanently-zero lie.
// Per-volume document counts now come from `AdministrationProfilesStore.documentCount(forVolumeId:)`
// (R-2), the one named seam over the bundled `volumeTotals` table.

// MARK: - SubseriesGroup

/// Metadata aggregated across all volumes in a single FRUS subseries.
///
/// Used by the Browser's Corpus level (subseries list) and Subseries level
/// (header statistics and volume list).
///
/// Version history:
///   1.0 — Session 11: initial implementation
///   1.1 — #1051 B-1: `totalDocuments` removed — it summed the manifest's dead `documentCount`
///          (0 in all 552 entries) and its one consumer's `> 0` gate had therefore never
///          rendered; subseries document counts now sum the R-2 accessor at the call site
public struct SubseriesGroup: Sendable, Identifiable {
    /// The subseries identifier, e.g. `"1969-76"`, `"1861"`.
    public let subseries: String

    /// All manifest entries in this subseries, in chronological order.
    public let volumes: [VolumeManifestEntry]

    public var id: String { subseries }

    // MARK: - Derived statistics

    public var totalVolumes: Int { volumes.count }

    /// Published BY THE CATALOGUE. A side-loaded entry mints `status: .published` (the TEI
    /// header carries no status), and counting it here read "553 of 552" against a series
    /// that has 552 published volumes (#777). Side-loaded files are counted separately.
    public var publishedCount: Int {
        volumes.filter { $0.status == .published && $0.provenance != .sideloaded }.count
    }
    /// Files the user added themselves — real, browsable, and not the catalogue's.
    public var sideloadedCount: Int { volumes.filter { $0.provenance == .sideloaded }.count }
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
