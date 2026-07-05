// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CollectionDateSortScope

/// The two scopes the "Sort by Date" control offers, surfaced identically on the macOS
/// manager ribbon and the iPad/iOS toolbar.
///
/// - ``wholeCollection`` — the original (and default) behavior: documents flow through the
///   fixed structural anchors in ONE global chronology, so a document can cross a heading
///   boundary into a neighboring section.
/// - ``withinSections`` — documents sort by date *within* their heading-delimited section
///   only, and never cross a heading. When the collection has no headings, this is
///   identical to ``wholeCollection``.
enum CollectionDateSortScope: CaseIterable, Sendable {
    /// Sort every document into one global chronology (documents may cross headings).
    case wholeCollection
    /// Sort documents chronologically within each heading-delimited section only.
    case withinSections

    /// The localized menu-item title for this scope.
    var displayLabel: String {
        switch self {
        case .wholeCollection:
            return String(localized: "collection.sort.date.scope.whole",
                          defaultValue: "Across the Whole Collection")
        case .withinSections:
            return String(localized: "collection.sort.date.scope.sections",
                          defaultValue: "Within Each Section")
        }
    }

    /// A one-line help/tooltip clarifying the scope's effect.
    var helpText: String {
        switch self {
        case .wholeCollection:
            return String(localized: "collection.sort.date.scope.whole.help",
                          defaultValue: "Order every document into one chronology — a document may move past a section heading")
        case .withinSections:
            return String(localized: "collection.sort.date.scope.sections.help",
                          defaultValue: "Order documents chronologically within each section — documents stay under their heading")
        }
    }

    /// The SF Symbol paired with this scope's menu item.
    var systemImage: String {
        switch self {
        case .wholeCollection: return "arrow.up.arrow.down"
        case .withinSections:  return "list.bullet.indent"
        }
    }
}

// MARK: - CollectionEntryData

/// Shared data plumbing for the two collection managers (iOS `CollectionEditorView` and
/// macOS `MacCollectionManagerView`): bulk-loads per-document display data (headers and
/// ISO dates) and provides the canonical date sort, so both platforms render identical
/// entry rows and sort identically.
///
/// Version history:
///   1.0 — Authoring Phase 1 (Session 2026-07-02): extracted from the macOS pane-level
///          loader and `sortByDate`; iOS previously showed bare ids and sorted by volume
///          dates only
///   1.1 — Sort modes (Collections): `sortedByDate` gains a `withinSections` scope. When
///          false (the default) the global path is byte-identical to 1.0; when true the
///          flat entry list is partitioned into heading-delimited runs and the global
///          sort is applied to each run independently, so documents never cross a heading.
///          A shared `CollectionDateSortScope` enum drives the two UI surfaces.
enum CollectionEntryData {

    /// Bulk-loads document headers (from `document_cache` via `CrossReferenceStore`) and
    /// per-document ISO dates (from `document_dates`) for the given entries, keyed by
    /// `"volumeId/documentId"`. Documents from unindexed volumes are simply absent from
    /// the returned maps; callers fall back to ids / volume dates.
    @MainActor
    static func load(
        for entries: [CollectionEntry],
        appState: AppState
    ) async -> (headers: [String: String], dates: [String: String]) {
        let keys = entries.map { (volumeId: $0.volumeId, documentId: $0.documentId) }
        var headers: [String: String] = [:]
        var dates: [String: String] = [:]
        if let store = appState.crossReferenceStore,
           let h = try? await store.documentHeaders(for: keys) {
            headers = h
        }
        if let pipeline = appState.indexingPipeline,
           let d = try? await pipeline.datesByDocumentKey(keys) {
            dates = d
        }
        return (headers, dates)
    }

    /// Returns `entries` with the DOCUMENT entries reordered by date while heading/prose
    /// entries keep their positions, so the authored structure survives the sort (dateless
    /// structural entries would otherwise all clump at the sentinel).
    ///
    /// Date precedence per document (the canonical three tiers):
    /// 1. Per-document `date_iso` from `documentDates` — individual-document precision
    ///    within a volume.
    /// 2. The volume's `dateRange.earliest` from the manifest — keeps documents from
    ///    unindexed volumes in the right volume-level neighborhood.
    /// 3. A `"9999"` sentinel — documents with no date information sort to the end.
    ///
    /// - Parameter withinSections: when `false` (the default) the sort is GLOBAL — every
    ///   document flows through the fixed non-document anchors in one chronology, so a
    ///   document can cross a heading into a neighboring section. When `true` the sort is
    ///   SECTION-AWARE — the flat list is partitioned into heading-delimited runs and the
    ///   global sort is applied to each run independently, so documents sort by date within
    ///   their section and never cross a heading. With no headings the two scopes are
    ///   identical (one run = the whole collection).
    static func sortedByDate(
        _ entries: [CollectionEntry],
        documentDates: [String: String],
        manifest: [VolumeManifestEntry],
        withinSections: Bool = false
    ) -> [CollectionEntry] {
        // Built with a loop (not `uniqueKeysWithValues`) so a duplicate manifest row can
        // never crash the sort.
        var volumeDateMap: [String: String] = [:]
        for entry in manifest {
            if let d = entry.dateRange.earliest {
                volumeDateMap[entry.volumeId] = d
            }
        }

        guard withinSections else {
            return globalSortedByDate(entries, documentDates: documentDates,
                                      volumeDateMap: volumeDateMap)
        }

        // Section-aware: split the flat list into consecutive runs, beginning a new run
        // BEFORE each heading (of ANY depth). The leading run is everything before the
        // first heading; each subsequent run is [heading, …up to the next heading]. Apply
        // the global sort to each run independently, then concatenate in original order.
        // A sub-heading therefore starts its own run, so documents sort within their
        // immediate (deepest) section. With no headings there is a single run — the whole
        // collection — so this reduces exactly to the global path.
        var result: [CollectionEntry] = []
        result.reserveCapacity(entries.count)
        var run: [CollectionEntry] = []
        for entry in entries {
            if entry.entryKind == .heading, !run.isEmpty {
                result.append(contentsOf: globalSortedByDate(
                    run, documentDates: documentDates, volumeDateMap: volumeDateMap))
                run = []
            }
            run.append(entry)
        }
        if !run.isEmpty {
            result.append(contentsOf: globalSortedByDate(
                run, documentDates: documentDates, volumeDateMap: volumeDateMap))
        }
        return result
    }

    /// The canonical global sort over one entry list: reorders DOCUMENT entries by date
    /// into the doc-slots they already occupy while every non-document entry stays put as a
    /// fixed anchor. Shared by the whole-collection scope and by each run of the
    /// section-aware scope so the two paths cannot diverge.
    private static func globalSortedByDate(
        _ entries: [CollectionEntry],
        documentDates: [String: String],
        volumeDateMap: [String: String]
    ) -> [CollectionEntry] {
        let sortedDocs = entries
            .filter { $0.entryKind == .document }
            .sorted { a, b in
                let aDate = documentDates["\(a.volumeId)/\(a.documentId)"] ?? volumeDateMap[a.volumeId] ?? "9999"
                let bDate = documentDates["\(b.volumeId)/\(b.documentId)"] ?? volumeDateMap[b.volumeId] ?? "9999"
                return aDate < bDate
            }
        var docs = sortedDocs.makeIterator()
        return entries.map { $0.entryKind == .document ? (docs.next() ?? $0) : $0 }
    }
}
