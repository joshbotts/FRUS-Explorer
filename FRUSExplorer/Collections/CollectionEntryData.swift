// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

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
    static func sortedByDate(
        _ entries: [CollectionEntry],
        documentDates: [String: String],
        manifest: [VolumeManifestEntry]
    ) -> [CollectionEntry] {
        // Built with a loop (not `uniqueKeysWithValues`) so a duplicate manifest row can
        // never crash the sort.
        var volumeDateMap: [String: String] = [:]
        for entry in manifest {
            if let d = entry.dateRange.earliest {
                volumeDateMap[entry.volumeId] = d
            }
        }
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
