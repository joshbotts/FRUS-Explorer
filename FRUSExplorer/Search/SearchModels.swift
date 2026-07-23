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
///   Session 09: `SearchParameters.subjectTagIds` is retained-but-inert (the
///         document-level subject taxonomy was retired; the SQL filter is gone).
public enum DocumentTypeFilter: Sendable, Equatable {
    /// Return all documents regardless of type (default).
    case all
    /// Exclude editorial notes — return only primary-source documents.
    case documentsOnly
    /// Return only editorial notes.
    case editorialNotesOnly
}

// MARK: - SearchSortOrder

/// Ordering applied to search results, shared by the iOS `SearchView` and the macOS Search window
/// (#305). `relevance` keeps the FTS5 BM25 order as returned; the date orders use the structured
/// `dateISO` value (undated rows last, BM25 tie-break) — see `SearchViewModel.sortedResults` and
/// `MacSearchViewModel.allSortedResults`.
enum SearchSortOrder: CaseIterable {
    case relevance
    case dateAscending
    case dateDescending

    /// Short control label.
    var label: String {
        switch self {
        case .relevance:      return String(localized: "search.sort.relevance", defaultValue: "Relevance")
        case .dateAscending:  return String(localized: "search.sort.dateAscending", defaultValue: "Date ↑")
        case .dateDescending: return String(localized: "search.sort.dateDescending", defaultValue: "Date ↓")
        }
    }
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

    /// Formerly restricted results to documents carrying the given subject tag IDs.
    ///
    /// Retained for API/persistence stability (`SavedSearch`, `Project` defaults) but
    /// **inert since Session 09**: document-level subject-tag filtering was retired
    /// (the subject taxonomy was dropped for low signal-to-noise), so this value no
    /// longer contributes a WHERE condition — see `IndexingPipeline.searchDocuments`.
    public var subjectTagIds: [String]

    /// Restrict results to documents that carry ALL of the given user tag IDs.
    /// Empty array = no user-tag filter.
    public var userTagIds: [String]

    /// Restrict results to documents within these volumes.
    /// `nil` = search all indexed volumes.
    public var volumeIds: [String]?

    /// Restrict results to this explicit set of documents, each keyed `"volumeId/documentId"`.
    /// `nil` = no document-set restriction. Powers the **Project History** search scope (#377
    /// Phase 2): the caller supplies the project's engaged documents (collections + noted +
    /// visited + tagged). Applied as an SQL `IN (…)`, so keep the set to a sane size.
    public var documentIds: [String]?

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

    /// If non-nil, restrict results to documents that mention this single per-volume person ref.
    ///
    /// Applied inside the search SQL as an `EXISTS` sub-query over `person_mentions`
    /// (`IndexingPipeline.searchDocuments`), not as a post-processing filter. Because the TEI `ref`
    /// is only meaningful within one volume, this matches a single per-volume id; prefer
    /// `personRollupId` for cross-corpus person filtering.
    public var personRef: String?

    /// Restrict results to documents mentioning any member of a person rollup (the cross-corpus
    /// identity from `person_rollup`). Set by the People browser's "Find all mentions"; correctly
    /// spans all of a person's per-volume TEI refs, unlike `personRef` (a single per-volume id).
    public var personRollupId: Int?

    /// Optional display name for the active person filter (`personRollupId`/`personRef`), shown as a
    /// removable "Mentions: …" chip in the search filter UI. Carried for presentation only.
    public var personLabel: String?

    // MARK: - Front matter scope

    /// Whether front-matter prose sections (preface, introduction, prefatoryNote, terms, etc.)
    /// should be included in search results. Default `true`.
    ///
    /// When `false`, rows with `document_cache.is_front_matter = 1` are excluded
    /// inside the search SQL (`IndexingPipeline.searchDocuments`). For volumes
    /// indexed before this field was added (front matter rows have
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
        documentIds: [String]? = nil,
        includeDocumentText: Bool = true,
        includeSummaries: Bool = true,
        includeNotes: Bool = true,
        projectId: UUID? = nil,
        documentTypeFilter: DocumentTypeFilter = .all,
        personRef: String? = nil,
        personRollupId: Int? = nil,
        personLabel: String? = nil,
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
        self.documentIds = documentIds
        self.includeDocumentText = includeDocumentText
        self.includeSummaries = includeSummaries
        self.includeNotes = includeNotes
        self.projectId = projectId
        self.documentTypeFilter = documentTypeFilter
        self.personRef = personRef
        self.personRollupId = personRollupId
        self.personLabel = personLabel
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
///   1.3 — Session 2026-06-08: `isFrontMatter` field added. Populated from
///          `document_cache.is_front_matter`. Used by search result rows to show a
///          teal "Front Matter" badge distinct from the purple editorial-note badge.
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

    /// Whether this document was promoted from a prose-only front-matter structural div
    /// (preface, introduction, prefatoryNote, terms, etc.).
    ///
    /// Populated from `document_cache.is_front_matter` by the combined search
    /// query. Defaults to `false` for volumes indexed before the
    /// `is_front_matter` column was added (those volumes must be re-indexed for this
    /// field to carry correct values).
    public let isFrontMatter: Bool

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
        isEditorialNote: Bool = false,
        isFrontMatter: Bool = false
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
        self.isFrontMatter = isFrontMatter
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

// MARK: - SearchDefaults

/// User-configurable default search scope, persisted by the Settings
/// "Search Defaults" pane (iOS) / "Search" pane (macOS) and applied when a
/// search view model is created.
///
/// Per-session changes in the search filter panel override these values without
/// writing them back — the footer text in both settings panes documents exactly
/// that contract. `SearchViewModel` (iOS) seeds its scope properties from here
/// and `clearFilters()` resets to these values; `MacSearchViewModel` applies
/// them in its initialiser.
public enum SearchDefaults {

    /// UserDefaults key for the "search document text by default" toggle.
    public static let scopeDocumentsKey = "frus.search.scopeDocuments"
    /// UserDefaults key for the "include research notes by default" toggle.
    public static let scopeNotesKey = "frus.search.scopeNotes"
    /// UserDefaults key for the "include AI summaries by default" toggle.
    public static let scopeSummariesKey = "frus.search.scopeSummaries"
    /// UserDefaults key for the default document-type filter
    /// (`"all"` / `"documentsOnly"` / `"editorialNotesOnly"`).
    public static let typeFilterKey = "frus.search.defaultTypeFilter"

    /// Whether document body text is searched by default. Default `true`.
    public static var scopeDocuments: Bool {
        UserDefaults.standard.object(forKey: scopeDocumentsKey) as? Bool ?? true
    }

    /// Whether research notes are included in search by default. Default `true`.
    public static var scopeNotes: Bool {
        UserDefaults.standard.object(forKey: scopeNotesKey) as? Bool ?? true
    }

    /// Whether AI summaries are included in search by default. Default `true`.
    public static var scopeSummaries: Bool {
        UserDefaults.standard.object(forKey: scopeSummariesKey) as? Bool ?? true
    }

    /// The default document-type filter. Default `.all`.
    public static var documentTypeFilter: DocumentTypeFilter {
        switch UserDefaults.standard.string(forKey: typeFilterKey) {
        case "documentsOnly":      return .documentsOnly
        case "editorialNotesOnly": return .editorialNotesOnly
        default:                   return .all
        }
    }

    // MARK: - Result-preview snippet length (#189-C)

    /// UserDefaults key for the global default result-preview snippet length (1–10 lines).
    public static let snippetLineCountKey = "frus.search.snippetLineCount"
    /// UserDefaults key for the main-search snippet-length override (`0` = follow the global default).
    public static let snippetLineCountMainOverrideKey = "frus.search.snippetLineCount.mainOverride"
    /// UserDefaults key for the add-document sheet snippet-length override (`0` = follow the global).
    public static let snippetLineCountAddDocOverrideKey = "frus.search.snippetLineCount.addDocOverride"

    /// The global default snippet length in rendered lines when unset. Used as the `@AppStorage`
    /// default for the global picker; overrides default to `0` ("follow global").
    public static let defaultSnippetLineCount = 2

    /// Resolves the effective snippet length for a surface: a `0` override follows the global
    /// default; any other value overrides it. Both inputs are clamped to 1…10 so a stray stored
    /// value can never yield `.lineLimit(0)` (which would hide the snippet entirely).
    public static func effectiveSnippetLineCount(global: Int, override: Int) -> Int {
        let clampedGlobal = min(max(global, 1), 10)
        return override == 0 ? clampedGlobal : min(max(override, 1), 10)
    }

    /// A localized "1 line" / "N lines" label for a snippet length, shared by the settings and
    /// per-surface override pickers.
    public static func snippetLinesLabel(_ n: Int) -> String {
        n == 1
            ? String(localized: "settings.search.snippet.oneLine", defaultValue: "1 line")
            : String(format: String(localized: "settings.search.snippet.nLines %lld", defaultValue: "%lld lines"), Int64(n))
    }
}
