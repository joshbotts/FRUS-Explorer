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
///   1.3 — Collections rework Phase 1a: persisted composition settings (`defaultBodyDepth`,
///          `footnoteStyle`, `tocStyle`, `applyHighlights`, `includeNotes`, `includeWordCloud`,
///          `summaryPromptId`) — the export-content decisions moved out of the ephemeral export sheet
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

    // MARK: - Composition (persisted export-content settings)

    /// These describe *what the exported product contains* — the editorial decisions that
    /// used to be re-chosen ephemerally in the export sheet (before Session-… Phase 1a).
    /// They are edited in the collection manager and read by `buildExportOptions` at export
    /// time, so a collection's composition is stable and re-exportable to any format.
    /// Enum-backed fields store the `rawValue` for CloudKit compatibility.

    /// Default document-body depth for exports — a `CollectionBodyDepth` raw value
    /// (`"full"`, `"summaryOnly"`, `"index"`). Per-entry overrides may refine it (Phase 1b).
    var defaultBodyDepth: String = "full" {
        didSet { lastModified = .now }
    }

    /// Footnote inclusion style for exports — a `CollectionFootnoteStyle` raw value
    /// (`"none"`, `"sourceNoteOnly"`, `"all"`).
    var footnoteStyle: String = "all" {
        didSet { lastModified = .now }
    }

    /// Table-of-contents label style for exports — a `CollectionToCStyle` raw value
    /// (`"citation"`, `"headerAndDateline"`).
    var tocStyle: String = "citation" {
        didSet { lastModified = .now }
    }

    /// When `true`, user highlights are annotated inline in exported document bodies.
    var applyHighlights: Bool = false {
        didSet { lastModified = .now }
    }

    /// When `true`, attached research notes appear below each document in exports.
    var includeNotes: Bool = true {
        didSet { lastModified = .now }
    }

    /// When `true`, a word-cloud overview is prepended to PDF/HTML exports.
    var includeWordCloud: Bool = false {
        didSet { lastModified = .now }
    }

    /// The `SummarizationPrompt.id` used when the body depth is `"summaryOnly"`.
    var summaryPromptId: UUID? {
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

// MARK: - CollectionEntryKind

/// What a `CollectionEntry` contributes to the composed collection (Phase 3a).
///
/// A collection is an ordered sequence of these: `document` entries are the FRUS documents;
/// `heading` entries start a section; `prose` entries are the researcher's own editorial note
/// blocks. This turns a flat document list into an authored, sectioned reader.
enum CollectionEntryKind: String, CaseIterable, Sendable {
    /// A FRUS document (uses `documentId`/`volumeId`).
    case document
    /// A section heading (uses `text` as the title).
    case heading
    /// An editorial prose block (uses `text` as the body).
    case prose
    /// A `kind` raw value written by a newer app version that this build does not
    /// understand (synced via CloudKit). Never persisted by this build; surfaced as an
    /// inert row and skipped by resolve/export so future entry kinds degrade gracefully
    /// instead of being misread as junk document entries (Authoring Phase 1 sync guard).
    case unrecognized

    /// Excludes `.unrecognized`: it is a decode fallback, not an authorable kind, so any
    /// menu or picker iterating the cases never offers it.
    static var allCases: [CollectionEntryKind] { [.document, .heading, .prose] }
}

// MARK: - CollectionEntry

/// A single item in a `Collection` — a document, a section heading, or a prose block — with
/// an explicit sort order.
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
///   1.1 — Session 128: added `selectedNoteIds` for multi-note per-entry selection;
///          `researchNoteId` retained for backward compatibility
///   1.2 — Session 153: removed `includeDocumentBody` (moved to export-level `CollectionBodyDepth`)
///   1.3 — Collections rework Phase 1b: added `bodyDepthOverride` (per-entry body depth)
///   1.4 — Collections rework Phase 3a: added `kind` + `text` (heterogeneous entries:
///          document / section heading / editorial prose block)
///   1.5 — Collections rework Phase 3b: added `richText` (rich-text prose body, an encoded
///          `AttributedString`; `text` retained as the plain-text projection)
///   1.6 — Authoring Phase 1: unknown `kind` raw values read as `.unrecognized` instead of
///          `.document` (mixed-build CloudKit sync guard); the setter never persists it
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

    /// IDs of `ResearchNote` records to include with this entry in exports.
    /// When non-empty, overrides `researchNoteId`. CloudKit-compatible (same pattern as `Collection.projectIds`).
    var selectedNoteIds: [UUID] = [] {
        didSet { lastModified = .now }
    }

    // MARK: - Composition Override

    /// Per-entry document-body depth — a `CollectionBodyDepth` raw value that overrides the
    /// collection's `defaultBodyDepth` for this one document. `nil` means "use the collection
    /// default", letting a single collection mix full documents, summaries, and citation-only
    /// entries into one product (Collections rework Phase 1b).
    var bodyDepthOverride: String? {
        didSet { lastModified = .now }
    }

    // MARK: - Entry Kind (Phase 3a)

    /// What this entry contributes to the composed collection — a `CollectionEntryKind` raw
    /// value. Defaults to `"document"` so every existing entry stays a document. A `"heading"`
    /// starts a section; a `"prose"` is an editorial note block. Heading/prose entries use
    /// `text` and ignore `documentId`/`volumeId`. Stored raw for CloudKit compatibility.
    var kind: String = "document" {
        didSet { lastModified = .now }
    }

    /// The section title (for a `heading` entry) or the editorial body (for a `prose` entry).
    /// `nil` for document entries. Always the plain-text form — a fallback for plain contexts
    /// and the source for a `prose` entry with no rich formatting.
    var text: String? {
        didSet { lastModified = .now }
    }

    /// Rich-text form of a `prose` entry's body, stored as **RTF** `Data`. `nil` for
    /// headings/documents and for plain prose; `text` is kept in sync as the plain-text
    /// projection so search and plain renderers keep working. Entries written by a Phase 3b
    /// build (or synced from one) instead hold that era's JSON-encoded `AttributedString` —
    /// readers go through `ProseRichText`/`CollectionProse`, which decode both formats and
    /// migrate legacy blobs to RTF (`ProseRichText.migrateLegacyJSONIfNeeded`).
    var richText: Data? {
        didSet { lastModified = .now }
    }

    /// Typed accessor for `kind` (not persisted; `kind` is the stored raw value).
    /// An unknown raw value — written by a newer app version — reads as `.unrecognized`
    /// rather than silently becoming a junk `.document`.
    var entryKind: CollectionEntryKind {
        get { CollectionEntryKind(rawValue: kind) ?? .unrecognized }
        set {
            // `.unrecognized` is a decode fallback; persisting its raw value would
            // round-trip as an unknown kind on every other device. Never write it.
            guard newValue != .unrecognized else { return }
            kind = newValue.rawValue
        }
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
        selectedNoteIds: [UUID] = []
    ) {
        self.id = UUID()
        self.collectionId = collectionId
        self.documentId = documentId
        self.volumeId = volumeId
        self.sortOrder = sortOrder
        self.researchNoteId = researchNoteId
        self.selectedNoteIds = selectedNoteIds
        let now = Date.now
        createdAt = now
        lastModified = now

        #if DEBUG
        print("[SwiftData] CollectionEntry created: \(id) doc=\(volumeId)/\(documentId)")
        #endif
    }
}
