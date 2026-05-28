// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - Collection

/// A user-curated ordered list of FRUS documents.
///
/// Collections are used for export (PDF/HTML, Session 22), citation management,
/// and sharing related documents across a research project. Like research notes,
/// collections can carry multiple project tags and follow the same cross-project
/// visibility rules.
///
/// `documentEntries` is a relationship to `CollectionEntry` records. Entries are
/// ordered by `CollectionEntry.sortOrder`. Deleting a `Collection` cascades to
/// delete all its entries.
///
/// ## `lastModified`
/// Updated automatically on mutations to `name`, `note`, `projectIds`, and the
/// `documentEntries` relationship. Individual entry mutations update the entry's
/// own `lastModified`; the collection is not touched in that case.
///
/// Version history:
///   1.0 — Session 04: initial implementation
///   1.1 — Session 89: deleteRule changed .cascade → .nullify for CloudKit compatibility;
///          callers now delete associated entries manually before deleting a Collection
///   1.2 — Session 97: `savedSearchId` added; when non-nil the collection is a "smart collection"
///          whose document list is resolved dynamically from the linked `SavedSearch` at export time
@Model final class Collection {

    // MARK: - Identity

    var id: UUID = UUID()

    // MARK: - Content

    var name: String = "" {
        didSet { lastModified = .now }
    }

    var note: String? {
        didSet { lastModified = .now }
    }

    // MARK: - Project Tags

    /// IDs of `Project` records this collection is visible in.
    var projectIds: [UUID] = [] {
        didSet { lastModified = .now }
    }

    // MARK: - Smart Collection

    /// When non-nil, this collection is a "smart collection" — its documents are resolved
    /// dynamically at export time by executing the `SavedSearch` with this ID.
    /// Static `documentEntries` are ignored during export when this is set.
    var savedSearchId: UUID? {
        didSet { lastModified = .now }
    }

    // MARK: - Entries

    /// Ordered document entries. Sorted by `CollectionEntry.sortOrder` at display time.
    ///
    /// Optional for CloudKit schema compatibility — always non-nil in practice.
    /// Use `documentEntries ?? []` when iterating.
    ///
    /// `deleteRule: .nullify` is required for CloudKit sync compatibility — cascade delete
    /// rules are not supported by CloudKit. Callers must delete associated `CollectionEntry`
    /// records explicitly before deleting the parent `Collection`.
    @Relationship(deleteRule: .nullify, inverse: \CollectionEntry.collection)
    var documentEntries: [CollectionEntry]? {
        didSet { lastModified = .now }
    }

    // MARK: - Timestamps

    /// Optional for CloudKit schema compatibility — always non-nil in practice.
    var createdAt: Date?
    /// Optional for CloudKit schema compatibility — always non-nil in practice.
    var lastModified: Date?

    // MARK: - Initializer

    init(
        name: String,
        note: String? = nil,
        projectIds: [UUID] = []
    ) {
        self.id = UUID()
        self.name = name
        self.note = note
        self.projectIds = projectIds
        let now = Date.now
        createdAt = now
        lastModified = now

        #if DEBUG
        print("[SwiftData] Collection created: \(id) '\(name)'")
        #endif
    }
}

// MARK: - CollectionEntry

/// A single document in a `Collection`, with an explicit sort order.
///
/// `collectionId` carries the parent collection's `id` for reference without
/// requiring the full `Collection` object to be in memory. The relationship
/// to the parent collection is managed by `Collection.documentEntries`.
///
/// `researchNoteId` optionally links a specific `ResearchNote` to this entry,
/// used in export to include the note alongside the document.
///
/// Version history:
///   1.0 — Session 04: initial implementation
///   1.1 — Session 128: added `includeDocumentBody` and `selectedNoteIds` for per-entry
///          content selection in exports; `researchNoteId` retained for backward compatibility
@Model final class CollectionEntry {

    // MARK: - Identity

    var id: UUID = UUID()

    // MARK: - Parent Relationship

    /// Back-reference to the owning `Collection`. Required by CloudKit sync (all relationships must have inverses).
    /// Managed by `Collection.documentEntries`; do not set directly.
    var collection: Collection?

    /// The parent `Collection.id`. Carried explicitly for fast lookups that don't need the full collection graph.
    var collectionId: UUID = UUID() {
        didSet { lastModified = .now }
    }

    // MARK: - Document Reference

    var documentId: String = "" {
        didSet { lastModified = .now }
    }

    var volumeId: String = "" {
        didSet { lastModified = .now }
    }

    // MARK: - Ordering

    /// Position within the parent collection. Lower values appear first.
    var sortOrder: Int = 0 {
        didSet { lastModified = .now }
    }

    // MARK: - Optional Note Link

    /// An optional `ResearchNote.id` included with this entry in exports.
    /// Retained for backward compatibility. When `selectedNoteIds` is non-empty,
    /// it takes precedence over this field during export resolution.
    var researchNoteId: UUID? {
        didSet { lastModified = .now }
    }

    // MARK: - Per-Entry Export Options

    /// When `false`, the exporter skips the full document body for this entry (notes only).
    /// Defaults to `true` (full document included).
    var includeDocumentBody: Bool = true {
        didSet { lastModified = .now }
    }

    /// IDs of `ResearchNote` records to include with this entry in exports.
    /// When non-empty, overrides `researchNoteId`. CloudKit-compatible (same pattern as `Collection.projectIds`).
    var selectedNoteIds: [UUID] = [] {
        didSet { lastModified = .now }
    }

    // MARK: - Timestamps

    /// Optional for CloudKit schema compatibility — always non-nil in practice.
    var createdAt: Date?
    /// Optional for CloudKit schema compatibility — always non-nil in practice.
    var lastModified: Date?

    // MARK: - Initializer

    init(
        collectionId: UUID,
        documentId: String,
        volumeId: String,
        sortOrder: Int,
        researchNoteId: UUID? = nil,
        includeDocumentBody: Bool = true,
        selectedNoteIds: [UUID] = []
    ) {
        self.id = UUID()
        self.collectionId = collectionId
        self.documentId = documentId
        self.volumeId = volumeId
        self.sortOrder = sortOrder
        self.researchNoteId = researchNoteId
        self.includeDocumentBody = includeDocumentBody
        self.selectedNoteIds = selectedNoteIds
        let now = Date.now
        createdAt = now
        lastModified = now

        #if DEBUG
        print("[SwiftData] CollectionEntry created: \(id) doc=\(volumeId)/\(documentId)")
        #endif
    }
}
