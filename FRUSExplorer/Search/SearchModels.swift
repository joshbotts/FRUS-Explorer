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
        includeSummaries: Bool = true,
        includeNotes: Bool = true,
        projectId: UUID? = nil,
        documentTypeFilter: DocumentTypeFilter = .all,
        personRef: String? = nil
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
        self.includeSummaries = includeSummaries
        self.includeNotes = includeNotes
        self.projectId = projectId
        self.documentTypeFilter = documentTypeFilter
        self.personRef = personRef
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
    public let dateline: String?

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
/// Version history:
///   1.0 — Session 51: initial implementation
public enum IndexingStage: String, Sendable {
    /// XML is being parsed and document text extracted.
    case parsing
    /// Date fields are being extracted from document headers.
    case extractingDates
    /// Person mentions are being resolved and stored.
    case indexingPersons
    /// Documents are being written to the FTS5 full-text index.
    case buildingFTS5
    /// All stages are complete for this volume.
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
public struct IndexingProgressUpdate: Sendable {
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
