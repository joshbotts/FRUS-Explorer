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
/// collection the researcher can reorder, annotate, section, and export like any other, with
/// every setting of the smart collection and its own apparatus blocks (the design's §4.5).
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
///   1.2 — L29 (#1996, the third review's J39): `snapshot(of:results:id:entryIds:)` carries every setting of the
///          smart collection but its link, its name and its dates, where it carried the composition alone, and
///          the smart collection's apparatus blocks, its front matter before the results and the rest after, where
///          it carried none; `entryIds` numbers every entry by its place, the blocks' included
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
    /// The snapshot carries every setting of the smart collection — its note, project membership, front
    /// matter, the title page's switches, its composition (a nil footnote pair stays nil, keeping the legacy
    /// derivation), its headnote default and its summary prompt — under the source's display name
    /// (suffixed) and with **no** `savedSearchId`, so it is a normal editable collection that exports as the
    /// smart collection did. Every field of the values but those four and the dates travels, so a setting
    /// added to the values later travels too (#1996).
    ///
    /// Its entries are the smart collection's front-matter blocks, one `.document` entry per result, then its
    /// other apparatus blocks, each group in its order: where a smart collection prints them
    /// (`CollectionContentAssembly.resolveSmartItems`), as the design's §4.5 asks (the third review's J39). A
    /// block type this build does not know goes after the results, as the resolver places it nowhere. A block
    /// keeps every field but its id and its place. The smart collection's other entries, which it held before
    /// its link and which nothing it produces prints, are not carried.
    ///
    /// - Parameters:
    ///   - smart: The smart collection's values, with its entries.
    ///   - results: Its resolved results, in order.
    ///   - id: The snapshot's id; a new one by default.
    ///   - entryIds: The id of each of the snapshot's entries, by its place; a new one each by default.
    /// - Returns: The snapshot's values, its entries at `sortOrder` 0, 1, 2, … and its dates `nil`, for the
    ///   host to stamp.
    public static func snapshot(
        of smart: CollectionExport,
        results: [DocumentRef],
        id: UUID = UUID(),
        entryIds: (Int) -> UUID = { _ in UUID() }
    ) -> CollectionExport {
        let blocks = smart.entries
            .filter { $0.entryKind == .generated }
            .sorted { ($0.sortOrder, $0.id.uuidString) < ($1.sortOrder, $1.id.uuidString) }
        func leads(_ block: CollectionEntryExport) -> Bool {
            CollectionGeneratedBlockType(rawValue: block.generatedBlockType ?? "")?.defaultPosition == .frontMatter
        }
        let documents = results.map { ref in
            CollectionEntryExport(id: UUID(), documentId: ref.documentId, volumeId: ref.volumeId, sortOrder: 0,
                                  selectedNoteIds: [], kind: CollectionEntryKind.document.rawValue)
        }
        var snapshot = smart
        snapshot.id = id
        snapshot.name = snapshotName(smart.name)
        snapshot.savedSearchId = nil
        snapshot.createdAt = nil
        snapshot.lastModified = nil
        snapshot.entries = (blocks.filter(leads) + documents + blocks.filter { !leads($0) })
            .enumerated().map { place, entry in
                var entry = entry
                entry.id = entryIds(place)
                entry.sortOrder = place
                entry.createdAt = nil
                entry.lastModified = nil
                return entry
            }
        return snapshot
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
