// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - FTS5Column

/// Names a column in the FTS5 virtual table.
///
/// Columns marked `UNINDEXED` store values in the FTS5 content shadow table but do
/// not contribute to the full-text index. Use them for identifiers and metadata that
/// must be returned with results but are never searched.
public enum FTS5Column: String, Sendable, CaseIterable {
    case documentId   = "document_id"
    case volumeId     = "volume_id"
    case documentNumber = "document_number"
    case header       = "header"
    case dateline     = "dateline"
    case sourceNote   = "source_note"
    case bodyText     = "body_text"
    case subjectTagIds = "subject_tag_ids"
    case userTagIds   = "user_tag_ids"
    case summaryText  = "summary_text"
    case noteText     = "note_text"
    case isEditorialNote = "is_editorial_note"
}

// MARK: - FTS5Schema

/// Defines the SQLite FTS5 virtual table structure and associated auxiliary tables.
///
/// `FTS5Schema` is intentionally decoupled from `FTS5Store` so the store can be
/// reused in projects with different document schemas. Pass a configured schema to
/// `FTS5Store.init` to control the table name and tokenizer.
///
/// ## FRUS Explorer Default Schema
/// Use `FTS5Schema.fruDocuments` for the standard FRUS document index. It creates:
/// - `frus_documents` FTS5 virtual table with `frus_english` stemming tokenizer
/// - `cross_references` directed edge table (populated by Session 09 indexing pipeline)
///
/// Version history:
///   1.0 — Session 03: initial implementation
public struct FTS5Schema: Sendable {

    /// Name of the FTS5 virtual table.
    public let tableName: String

    /// Ordered list of columns in the virtual table.
    public let columns: [FTS5Column]

    /// Name of the registered FTS5 tokenizer. Must be registered before schema creation.
    /// Default: `"frus_english"` (the Porter-stemming tokenizer from `FTS5Tokenizer`).
    public let tokenizerName: String

    /// If non-nil, the FTS5 table is created as an external-content FTS5 table
    /// (`content=<tableName>`). Nil means a standard FTS5 table.
    public let contentTable: String?

    public init(
        tableName: String,
        columns: [FTS5Column],
        tokenizerName: String = "frus_english",
        contentTable: String? = nil
    ) {
        self.tableName = tableName
        self.columns = columns
        self.tokenizerName = tokenizerName
        self.contentTable = contentTable
    }

    /// Standard FRUS document search schema.
    ///
    /// Columns `document_id`, `volume_id`, `document_number`, `subject_tag_ids`,
    /// and `user_tag_ids` are `UNINDEXED` — they are stored for result retrieval
    /// and tag-filter post-processing but not tokenized.
    public static let frusDocuments = FTS5Schema(
        tableName: "frus_documents",
        columns: FTS5Column.allCases,
        tokenizerName: "frus_english",
        contentTable: nil
    )

    // Columns that should be marked UNINDEXED in the CREATE VIRTUAL TABLE statement.
    static let unindexedColumns: Set<FTS5Column> = [
        .documentId, .volumeId, .documentNumber, .subjectTagIds, .userTagIds, .isEditorialNote,
    ]
}

// MARK: - FTS5Document

/// A document to be indexed in the FTS5 store.
///
/// All fields correspond directly to FTS5 virtual table columns. Nil optional fields
/// are stored as SQL NULL and are excluded from index tokenization.
///
/// The `id` field is the stable identifier used for update and delete operations.
/// It must be unique within the store.
///
/// Version history:
///   1.0 — Session 03: initial implementation
///   1.1 — Session 38: `isEditorialNote` field added
public struct FTS5Document: Sendable {
    /// Unique document identifier (e.g. `"d1"` within a volume).
    public let id: String
    /// Volume this document belongs to (e.g. `"frus1969-76v01"`).
    public let volumeId: String
    /// Printed document number from the FRUS volume, if present.
    public let documentNumber: String?
    /// Document header / title line.
    public let header: String
    /// Dateline string (place and date of authorship), if present.
    public let dateline: String?
    /// Source note describing the archival provenance, if present.
    public let sourceNote: String?
    /// Full plain-text body of the FRUS document (stripped of XML markup).
    public let bodyText: String
    /// Space-separated subject tag IDs for tag-filtered search. Nil if none.
    public let subjectTagIds: String?
    /// Space-separated user tag IDs for tag-filtered search. Nil if none.
    public let userTagIds: String?
    /// Latest generated summary text, if any summarization has been performed.
    public let summaryText: String?
    /// Research note body text, if the user has attached a note.
    public let noteText: String?
    /// Whether this document is a FRUS editorial note rather than a primary-source document.
    /// Stored as UNINDEXED in the FTS5 virtual table; not tokenized.
    public let isEditorialNote: Bool

    public init(
        id: String,
        volumeId: String,
        documentNumber: String? = nil,
        header: String,
        dateline: String? = nil,
        sourceNote: String? = nil,
        bodyText: String,
        subjectTagIds: String? = nil,
        userTagIds: String? = nil,
        summaryText: String? = nil,
        noteText: String? = nil,
        isEditorialNote: Bool = false
    ) {
        self.id = id
        self.volumeId = volumeId
        self.documentNumber = documentNumber
        self.header = header
        self.dateline = dateline
        self.sourceNote = sourceNote
        self.bodyText = bodyText
        self.subjectTagIds = subjectTagIds
        self.userTagIds = userTagIds
        self.summaryText = summaryText
        self.noteText = noteText
        self.isEditorialNote = isEditorialNote
    }
}

// MARK: - FTS5Result

/// A single full-text search result from `FTS5Store.search`.
///
/// Results are ordered by BM25 relevance score (lower = more relevant; SQLite's
/// `bm25()` function returns negative values, so sort ascending for best-first).
///
/// The `snippet` field contains the output of SQLite's `snippet()` function with
/// `<b>` / `</b>` delimiters around matching terms. The surrounding context window
/// is three tokens on each side of the first match.
///
/// Version history:
///   1.0 — Session 03: initial implementation
///   1.1 — Session 38: `isEditorialNote` field added
public struct FTS5Result: Sendable {
    /// Document identifier (matches `FTS5Document.id`).
    public let documentId: String
    /// Volume this document belongs to.
    public let volumeId: String
    /// Document header / title line.
    public let header: String
    /// Dateline, if present in the document.
    public let dateline: String?
    /// Source note, if present in the document.
    public let sourceNote: String?
    /// Context snippet with matching terms wrapped in `<b>…</b>`.
    public let snippet: String
    /// BM25 relevance score. Lower (more negative) = more relevant.
    public let bm25Score: Double
    /// Subject tag IDs associated with this document.
    public let subjectTagIds: [String]
    /// User tag IDs associated with this document.
    public let userTagIds: [String]
    /// Whether this document is an editorial note rather than a primary-source document.
    public let isEditorialNote: Bool

    /// Convenience: subject tag IDs split from the space-separated storage string.
    static func splitTagIds(_ raw: String?) -> [String] {
        guard let raw, !raw.isEmpty else { return [] }
        return raw.split(separator: " ").map(String.init)
    }
}
