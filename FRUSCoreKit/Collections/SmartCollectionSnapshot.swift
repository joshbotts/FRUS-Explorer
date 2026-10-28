// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - SmartCollectionDocumentRef

/// One result of a smart collection's saved search: the document to resolve, and its place in the
/// result set. A value, so resolving a smart collection creates no model instance outside a store.
///
/// Version history:
///   1.0 — Session 2026-07-02 (Collections Authoring Phase 2a): `CollectionContentResolver.SmartDocumentRef`
///   1.1 — 2026-10-27 (FRUS Explorer Light, S18b): FRUSCoreKit's, public, as `SmartCollectionDocumentRef`, with
///          the search that makes it (`SmartCollectionSnapshot.documentRefs`); the app's resolver names it
///          `SmartDocumentRef` still
public struct SmartCollectionDocumentRef: Sendable {
    /// The FRUS document identifier (e.g. `"d12"`).
    public let documentId: String
    /// The containing volume identifier.
    public let volumeId: String
    /// Position within the result set (ascending).
    public let sortOrder: Int

    /// Creates a smart-collection document reference.
    public init(documentId: String, volumeId: String, sortOrder: Int) {
        self.documentId = documentId
        self.volumeId = volumeId
        self.sortOrder = sortOrder
    }
}

// MARK: - SmartCollectionSnapshot

/// A smart (saved-search) collection's results, and the static collection a snapshot of them makes
/// (Collections rework Phase 4, D8).
///
/// A smart collection's membership resolves dynamically from a `SavedSearch` at export time,
/// so its contents aren't inspectable or editable in the manager, and it can't be shared as a
/// native `.fruscollection` file (which serializes static entries). A **snapshot** captures the
/// search's current results as ordinary `.document` entries in a new, `savedSearchId`-free
/// collection the researcher can reorder, annotate, section, and export like any other.
///
/// The snapshot is **non-destructive**: the original smart collection is untouched and stays
/// dynamic. The search runs here, at most `resultLimit` results (`documentRefs`), and the snapshot
/// is made from values (`snapshot(of:results:)`); a host inserts the collection it returns into its
/// store — the app through `create(from:results:into:)`, in `SmartCollectionSnapshot+App.swift`.
///
/// Version history:
///   1.0 — Collections rework Phase 4 (D8): initial implementation
///   1.1 — 2026-10-27 (FRUS Explorer Light, S18b): moved into FRUSCoreKit, public, with the saved search's run
///          (`documentRefs`, at most `resultLimit` results, the content resolver's `smartRefs(for:)` and both
///          Snapshot actions' search) and the snapshot over values (`snapshot(of:results:)`); `create(from:
///          results:into:)`, which inserts SwiftData models, stays in the app
public enum SmartCollectionSnapshot {

    /// A resolved document reference from a saved-search result.
    public typealias DocumentRef = (documentId: String, volumeId: String)

    /// The most results a smart collection resolves to: 1,000, the fetch ceiling of a search with text
    /// in it (`SearchViewModel.searchHardLimit`), at which the app has always run a smart collection's
    /// saved search — for an export, the live preview, the trip packet's reading list and a snapshot.
    /// The default page (`SearchService.defaultPageSize`, 20) once silently truncated those exports.
    public static let resultLimit = 1_000

    /// Runs a smart collection's saved search and returns one reference per result, in relevance order,
    /// `sortOrder` ascending from 0.
    ///
    /// - Parameters:
    ///   - parameters: The saved search, as its host runs it (`SavedSearch.searchParameters` in the app).
    ///   - searchService: The search to run it with.
    ///   - limit: The most results to fetch; `resultLimit` unless a caller passes its own.
    /// - Throws: Any search execution error.
    public static func documentRefs(
        parameters: SearchParameters,
        searchService: SearchService,
        limit: Int = resultLimit
    ) async throws -> [SmartCollectionDocumentRef] {
        let results = try await searchService.search(parameters: parameters, limit: limit)
        return results.enumerated().map { i, r in
            SmartCollectionDocumentRef(documentId: r.documentId, volumeId: r.volumeId, sortOrder: i)
        }
    }

    /// The static collection a snapshot of `smart` makes from its resolved results, as values for a host
    /// to insert.
    ///
    /// The snapshot copies the source's display name (suffixed), note, project membership, and
    /// composition settings, but carries **no** `savedSearchId`, so it is a normal editable
    /// collection with one ordered `.document` entry per result. The composition copied is the default
    /// body depth, the footnote style and the footnote pair (a nil pair stays nil, keeping the legacy
    /// derivation), the contents' style, highlights, notes, the word cloud and the summary prompt; the
    /// headnote default, the front matter and the settings are left at their defaults, and the source's
    /// own entries are not copied.
    ///
    /// - Parameters:
    ///   - smart: The smart collection's values.
    ///   - results: Its resolved results, in order.
    ///   - id: The snapshot's id; a new one by default.
    ///   - entryIds: The id of each result's entry; a new one each by default.
    /// - Returns: The snapshot's values, its entries at `sortOrder` 0, 1, 2, … in result order.
    public static func snapshot(
        of smart: CollectionExport,
        results: [DocumentRef],
        id: UUID = UUID(),
        entryIds: (Int) -> UUID = { _ in UUID() }
    ) -> CollectionExport {
        CollectionExport(
            id: id,
            name: snapshotName(smart.name),
            note: smart.note,
            projectIds: smart.projectIds,
            entries: results.enumerated().map { index, ref in
                CollectionEntryExport(id: entryIds(index), documentId: ref.documentId, volumeId: ref.volumeId,
                                      sortOrder: index, selectedNoteIds: [],
                                      kind: CollectionEntryKind.document.rawValue)
            },
            // Preserve composition so the snapshot exports identically to the smart collection.
            defaultBodyDepth: smart.defaultBodyDepth,
            footnoteStyle: smart.footnoteStyle,
            // Phase 5 footnote pair — copied verbatim (a nil pair stays nil, preserving
            // the legacy-derivation semantics on the snapshot).
            includeFootnotes: smart.includeFootnotes,
            includeSourceNote: smart.includeSourceNote,
            tocStyle: smart.tocStyle,
            applyHighlights: smart.applyHighlights,
            includeNotes: smart.includeNotes,
            includeWordCloud: smart.includeWordCloud,
            summaryPromptId: smart.summaryPromptId
        )
    }

    /// The display name for a snapshot of a collection named `base`.
    public static func snapshotName(_ base: String) -> String {
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? String(localized: "collection.snapshot.untitled",
                                            defaultValue: "Smart Collection") : trimmed
        return String(localized: "collection.snapshot.name",
                      defaultValue: "\(name) (Snapshot)")
    }
}
