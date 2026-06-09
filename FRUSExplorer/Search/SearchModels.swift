// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - DocumentTypeFilter

/// Controls which document types are included in search results.
///
/// Applied as a post-processing filter in `SearchService.search`.
///
/// Version history:
///   1.0 — Session 38: initial implementation
public enum DocumentTypeFilter: Sendable, Equatable {
    /// Return all documents regardless of type (default).
    case all
    /// Exclude editorial notes — return only primary-source documents.
    case documentsOnly
    /// Return only editorial notes.
    case editorialNotesOnly
}

// MARK: - SearchParameters

/// Full set of parameters for a `SearchService` query.
///
/// Translated by `SearchService` into an `FTS5Query` for the FTS5 index, with
/// additional post-processing for date range, volume, and multi-tag filters.
///
/// `keywords`, `phrase`, and `prefixWildcard` are mutually exclusive in practice
/// but may be combined; each non-nil value adds to the FTS5 MATCH expression.
///
/// Version history:
///   1.0 — Session 09: initial implementation
///   1.1 — Session 38: `documentTypeFilter` added
///   1.2 — Session 39: `personRef` filter added
///   1.3 — Session 75: `includeDocumentText` added so document body columns can be excluded
///          to enable "summaries only" or "notes only" search scope
///   1.4 — Session 2026-06-08: `includeFrontMatter` added for Phase 4 front-matter scope toggle
public struct SearchParameters: Sendable, Equatable {

    // MARK: - Full-text fields

    /// Space-separated keywords combined via `booleanMode`.
    public var keywords: String?

    /// Exact phrase (order-sensitive, case-insensitive).
    public var phrase: String?

    /// How keyword terms are combined. Default `.and`.
    public var booleanMode: FTS5Query.BooleanMode

    /// Terms that must NOT appear in matching documents.
    public var excludedTerms: [String]

    /// Prefix for a wildcard search (e.g. `"negoti"` matches `"negotiate"`,
    /// `"negotiated"`, etc.). The `*` is appended automatically.
    public var prefixWildcard: String?

    // MARK: - Filters

    /// Restrict results to documents whose date falls within this range.
    /// Dates are compared as ISO 8601 strings (`yyyy-MM-dd`).
    /// Documents without a parseable date are excluded when this is non-nil.
    public var dateRange: DateRange?

    /// Restrict results to documents that carry ALL of the given subject tag IDs.
    /// Empty array = no subject-tag filter.
    public var subjectTagIds: [String]

    /// Restrict results to documents that carry ALL of the given user tag IDs.
    /// Empty array = no user-tag filter.
    public var userTagIds: [String]

    /// Restrict results to documents within these volumes.
    /// `nil` = search all indexed volumes.
    public var volumeIds: [String]?

    // MARK: - Content scope

    /// Whether document body text (header, dateline, source note, body) should be searched.
    ///
    /// Default `true`. When `false`, document content columns are excluded from the FTS5
    /// column set, allowing searches scoped exclusively to summaries and/or notes.
    /// At least one of `includeDocumentText`, `includeSummaries`, or `includeNotes` must
    /// be `true`; `SearchService` will throw `FTS5Error.emptyQuery` if the active column
    /// set is empty.
    public var includeDocumentText: Bool

    /// Whether summary text should be searched. Default `true`.
    public var includeSummaries: Bool

    /// Whether research note text should be searched. Default `true`.
    public var includeNotes: Bool

    // MARK: - Project scope

    /// Restrict user-tag filtering to tags belonging to this project.
    /// `nil` = global context (all user tags visible).
    public var projectId: UUID?

    // MARK: - Document type

    /// Restricts results to a specific document type. Default `.all`.
    public var documentTypeFilter: DocumentTypeFilter

    // MARK: - Person ref filter

    /// If non-nil, restrict results to documents that mention this person ref.
    ///
    /// Applied as a post-processing filter in `SearchService.search`: only
    /// document keys returned by `PersonMentionStore.documents(forPersonRef:)`
    /// are eligible. A document that matches the personRef but has no FTS5
    /// keyword match will not appear in results unless `keywords` is also nil.
    ///
    /// Note: a nil keywords field is not currently a valid search; this parameter
    /// only restricts an existing keyword search's result set.
    public var personRef: String?

    // MARK: - Front matter scope

    /// Whether front-matter prose sections (preface, introduction, prefatoryNote, terms, etc.)
    /// should be included in search results. Default `true`.
    ///
    /// When `false`, any result whose `"volumeId/documentId"` key appears in
    /// `IndexingPipeline.frontMatterDocumentKeys(limitToVolumeIds:)` is excluded.
    /// For volumes indexed before this field was added (front matter rows have
    /// `is_front_matter = 0` by default), this filter is a no-op until the user reindexes.
    public var includeFrontMatter: Bool

    // MARK: - Initialiser

    public init(
        keywords: String? = nil,
        phrase: String? = nil,
        booleanMode: FTS5Query.BooleanMode = .and,
        excludedTerms: [String] = [],
        prefixWildcard: String? = nil,
        dateRange: DateRange? = nil,
        subjectTagIds: [String] = [],
        userTagIds: [String] = [],
        volumeIds: [String]? = nil,
        includeDocumentText: Bool = true,
        includeSummaries: Bool = true,
        includeNotes: Bool = true,
        projectId: UUID? = nil,
        documentTypeFilter: DocumentTypeFilter = .all,
        personRef: String? = nil,
        includeFrontMatter: Bool = true
    ) {
        self.keywords = keywords
        self.phrase = phrase
        self.booleanMode = booleanMode
        self.excludedTerms = excludedTerms
        self.prefixWildcard = prefixWildcard
        self.dateRange = dateRange
        self.subjectTagIds = subjectTagIds
        self.userTagIds = userTagIds
        self.volumeIds = volumeIds
        self.includeDocumentText = includeDocumentText
        self.includeSummaries = includeSummaries
        self.includeNotes = includeNotes
        self.projectId = projectId
        self.documentTypeFilter = documentTypeFilter
        self.personRef = personRef
        self.includeFrontMatter = includeFrontMatter
    }
}

// MARK: - SearchResult

/// A single full-text search result from `SearchService.search`.
///
/// Results are ordered by BM25 relevance score. Lower (more negative) = more relevant.
/// The `snippet` field contains the output of SQLite's `snippet()` function with
/// `<b>` / `</b>` delimiters around the first matching run.
///
/// Version history:
///   1.0 — Session 09: initial implementation
///   1.1 — Session 38: `isEditorialNote` field added
///   1.2 — Session 122: `dateISO` field added. Populated from
///          `document_dates.date_iso` (e.g. `"1969-02-15"`). Used by the macOS
///          search window's date-asc / date-desc sort so results are ordered
///          chronologically rather than by the free-text `dateline` string,
///          which begins with the place of authorship and a textual month name
///          and therefore cannot be sorted as a date.
public struct SearchResult: Sendable, Identifiable {

    /// Document identifier (e.g. `"d1"`), unique within its volume.
    public let documentId: String

    /// Volume this document belongs to (e.g. `"frus1969-76v01"`).
    public let volumeId: String

    /// Printed document number, if present.
    public let documentNumber: String?

    /// Document header / title line.
    public let header: String

    /// Dateline string (place and date of authorship), if present.
    /// This is a free-text TEI value like `"Washington, March 5, 1969"` and is
    /// intended for **display only**. Do not sort on it — use `dateISO` instead.
    public let dateline: String?

    /// Canonical ISO 8601 date string from `document_dates.date_iso`, e.g.
    /// `"1969-02-15"` or (for partial-precision dates) `"1969"`. Sorts correctly
    /// as a string. `nil` for genuinely undated documents.
    public let dateISO: String?

    /// Source note describing archival provenance, if present.
    public let sourceNote: String?

    /// Context snippet with matching terms wrapped in `<b>…</b>`.
    public let snippet: String

    /// BM25 relevance score. Lower (more negative) = more relevant.
    public let bm25Score: Double

    /// Subject tag IDs associated with this document.
    public let subjectTagIds: [String]

    /// User tag IDs associated with this document.
    public let userTagIds: [String]

    /// Whether this document is a FRUS editorial note rather than a primary-source document.
    public let isEditorialNote: Bool

    public var id: String { "\(volumeId)/\(documentId)" }

    public init(
        documentId: String,
        volumeId: String,
        documentNumber: String? = nil,
        header: String,
        dateline: String? = nil,
        dateISO: String? = nil,
        sourceNote: String? = nil,
        snippet: String,
        bm25Score: Double,
        subjectTagIds: [String] = [],
        userTagIds: [String] = [],
        isEditorialNote: Bool = false
    ) {
        self.documentId = documentId
        self.volumeId = volumeId
        self.documentNumber = documentNumber
        self.header = header
        self.dateline = dateline
        self.dateISO = dateISO
        self.sourceNote = sourceNote
        self.snippet = snippet
        self.bm25Score = bm25Score
        self.subjectTagIds = subjectTagIds
        self.userTagIds = userTagIds
        self.isEditorialNote = isEditorialNote
    }
}

// MARK: - IndexingStage

/// The current phase of a single-volume indexing pass.
///
/// Emitted as part of `IndexingProgressUpdate` on the `IndexingPipeline.progressStream`.
///
/// ## Design note
/// The previous four-case sequence (parsing / extractingDates / indexingPersons /
/// buildingFTS5) implied four sequential passes. In practice the pipeline performs
/// a single XML parse that extracts documents, dates, persons, and cross-references
/// simultaneously, followed by batched SQLite writes. The two-phase model here
/// reflects the actual work: one parse pass, then N storage batches.
///
/// Version history:
///   1.0 — Session 51: initial implementation
///   2.0 — Session 112: replace four-stage sequence with .reading / .storingBatch / .complete
///   2.1 — Session 123: `.optimizing` case added so the UI can show progress during
///          the post-batch FTS5 `optimize()` phase (30–60 s on a full corpus rebuild).
///          Without this case the bulk-reindex UI appeared to stall on the last
///          volume's final `.storingBatch` until `optimize()` returned.
public enum IndexingStage: Sendable, Equatable {
    /// Single-pass XML parse: document text, dates, persons, and cross-references
    /// are all extracted simultaneously. `totalDocuments` is 0 until the parse
    /// completes and the count is known.
    case reading
    /// Batched SQLite writes: FTS5 rows, document cache, and auxiliary tables.
    /// `current` is the 1-based batch number; `total` is the total batch count.
    case storingBatch(current: Int, total: Int)
    /// FTS5 `optimize()` is merging b-tree segments. Emitted once by
    /// `indexAllVolumes` after every volume has finished storing and before the
    /// final `.complete`. No sub-progress is available — the UI should show an
    /// indeterminate spinner. Carries `volumeId == ""` because it is a
    /// batch-wide phase, not per-volume.
    case optimizing
    /// All stages are complete for this volume (single-volume path) or for the
    /// whole batch (bulk path). `volumeId == ""` in the bulk-completion case.
    case complete
}

// MARK: - IndexingProgressUpdate

/// A fine-grained per-document progress event emitted by `IndexingPipeline.progressStream`.
///
/// Unlike `IndexingProgress` (which tracks volume-level state for `ReindexView`), this
/// type carries per-document detail and throughput metrics for the inline `IndexingCapsule`
/// shown in `VolumeRowLabel` on iOS.
///
/// Version history:
///   1.0 — Session 51: initial implementation
public struct IndexingProgressUpdate: Sendable, Equatable {
    /// The volume currently being indexed.
    public let volumeId: String
    /// The current pipeline stage.
    public let stage: IndexingStage
    /// Number of documents fully processed so far in this volume.
    public let completedDocuments: Int
    /// Total documents in the volume (0 if not yet known).
    public let totalDocuments: Int
    /// Rolling throughput estimate in documents per second (≥ 0).
    public let docsPerSecond: Double

    public init(
        volumeId: String,
        stage: IndexingStage,
        completedDocuments: Int,
        totalDocuments: Int,
        docsPerSecond: Double
    ) {
        self.volumeId = volumeId
        self.stage = stage
        self.completedDocuments = completedDocuments
        self.totalDocuments = totalDocuments
        self.docsPerSecond = docsPerSecond
    }
}

// MARK: - VolumeMetadataDiscovered

/// Aggregate metrics emitted by `IndexingPipeline.metadataStream` once per volume,
/// immediately after the XML parse phase completes and before storage begins.
///
/// All integer counts are zero-safe — callers can compare against 0 without
/// optional handling. `dateRangeMin`/`dateRangeMax` are `nil` when no document
/// in the volume carries a parseable date.
///
/// Version history:
///   1.0 — Session 113: initial implementation
///   1.1 — Session 116: glossaryPersonNames added for IndexingContextCard key-persons chips
public struct VolumeMetadataDiscovered: Sendable {
    /// The volume that was just parsed.
    public let volumeId: String
    /// Total number of documents in the volume.
    public let totalDocuments: Int
    /// Number of documents classified as editorial notes.
    public let editorialNoteCount: Int
    /// Number of unique person refs mentioned across all documents.
    public let uniquePersonCount: Int
    /// Number of cross-reference edges originating from this volume.
    public let crossReferenceCount: Int
    /// Number of documents that carry a parseable date.
    public let datedDocumentCount: Int
    /// ISO-8601 earliest document date found, or `nil` if no dates are present.
    public let dateRangeMin: String?
    /// ISO-8601 latest document date found, or `nil` if no dates are present.
    public let dateRangeMax: String?
    /// Number of persons listed in the volume's biographical glossary.
    public let glossaryPersonCount: Int
    /// Number of terms listed in the volume's subject glossary.
    public let glossaryTermCount: Int
    /// Up to 12 person names from the volume's biographical glossary, sorted alphabetically.
    ///
    /// Populated from the first 12 entries (by name) in the parsed glossary. Empty when the
    /// volume carries no biographical glossary. Used by `IndexingContextCard` to render
    /// key-person chips while the write phase is in progress.
    public let glossaryPersonNames: [String]

    public init(
        volumeId: String,
        totalDocuments: Int,
        editorialNoteCount: Int,
        uniquePersonCount: Int,
        crossReferenceCount: Int,
        datedDocumentCount: Int,
        dateRangeMin: String?,
        dateRangeMax: String?,
        glossaryPersonCount: Int,
        glossaryTermCount: Int,
        glossaryPersonNames: [String] = []
    ) {
        self.volumeId = volumeId
        self.totalDocuments = totalDocuments
        self.editorialNoteCount = editorialNoteCount
        self.uniquePersonCount = uniquePersonCount
        self.crossReferenceCount = crossReferenceCount
        self.datedDocumentCount = datedDocumentCount
        self.dateRangeMin = dateRangeMin
        self.dateRangeMax = dateRangeMax
        self.glossaryPersonCount = glossaryPersonCount
        self.glossaryTermCount = glossaryTermCount
        self.glossaryPersonNames = glossaryPersonNames
    }
}

// MARK: - IndexingProgress

/// A progress event emitted by `IndexingPipeline.progress`.
///
/// Consumed by the Search view to display indexing status and completion state.
///
/// Version history:
///   1.0 — Session 09: initial implementation
public struct IndexingProgress: Sendable {

    /// Current indexing state.
    public enum State: Sendable {
        /// No indexing is in progress.
        case idle
        /// A volume is actively being indexed.
        case indexing(volumeId: String, current: Int, total: Int)
        /// All queued volumes have been indexed successfully.
        case completed(volumeCount: Int, documentCount: Int)
        /// A volume failed to index (indexing of other volumes continues).
        case failed(volumeId: String, error: String)
    }

    public let state: State
    public let timestamp: Date

    public init(state: State, timestamp: Date = .now) {
        self.state = state
        self.timestamp = timestamp
    }
}
