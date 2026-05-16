// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - SearchService

/// Translates `SearchParameters` into FTS5 queries and returns typed `SearchResult` values.
///
/// ## Filtering
/// Filters are applied in this order:
/// 1. FTS5 full-text match (keyword, phrase, prefix wildcard, NOT terms).
/// 2. Volume ID filter (post-processing if `searchParameters.volumeIds` is non-nil).
/// 3. Date range filter (queries `document_dates` in `IndexingPipeline` before searching).
/// 4. Subject tag AND filter (post-processing for multiple tag IDs).
/// 5. User tag AND filter (post-processing for multiple tag IDs).
///
/// ## Date Range Filtering
/// Date filtering relies on `IndexingPipeline.documentKeysInDateRange(_:limitToVolumeIds:)`.
/// Documents whose dateline could not be parsed to ISO 8601 are excluded when a date range
/// is specified. This is documented in the Search UI help text.
///
/// ## Column Scoping
/// When `SearchParameters.includeSummaries` and/or `includeNotes` are `false`, the
/// corresponding FTS5 columns are excluded from the search scope via `FTS5Query.columns`.
///
/// Version history:
///   1.0 — Session 09: initial implementation
///   1.1 — Session 38: document type filter applied in `search(_:limit:offset:)`
public actor SearchService {

    // MARK: - Dependencies

    private let fts5Store: FTS5Store
    private let pipeline: IndexingPipeline

    // MARK: - Pagination defaults

    public static let defaultPageSize = 20
    public static let maxPageSize = 100

    // MARK: - Initialisation

    /// Creates a `SearchService`.
    ///
    /// - Parameters:
    ///   - fts5Store: The shared FTS5 store containing indexed documents.
    ///   - pipeline: The indexing pipeline that owns the `document_dates` auxiliary table.
    public init(fts5Store: FTS5Store, pipeline: IndexingPipeline) {
        self.fts5Store = fts5Store
        self.pipeline = pipeline
    }

    // MARK: - Public API

    /// Executes a search and returns ranked results.
    ///
    /// - Parameters:
    ///   - parameters: Search criteria.
    ///   - limit: Maximum results to return. Capped at `maxPageSize`.
    ///   - offset: Number of results to skip for pagination.
    /// - Returns: Matching documents ordered by BM25 relevance.
    /// - Throws: `FTS5Error.emptyQuery` if no searchable content can be constructed.
    public func search(
        parameters: SearchParameters,
        limit: Int = defaultPageSize,
        offset: Int = 0
    ) async throws -> [SearchResult] {
        let query = try makeFTS5Query(from: parameters)
        let effectiveLimit = min(limit, Self.maxPageSize)

        // Build date-range whitelist if requested.
        let dateKeys: Set<String>? = try await {
            guard let range = parameters.dateRange else { return nil }
            return try await pipeline.documentKeysInDateRange(range, limitToVolumeIds: parameters.volumeIds)
        }()

        let rawResults = try await fts5Store.search(
            query: query,
            limit: effectiveLimit + 200,   // overscan to account for post-processing
            offset: offset
        )

        var filtered: [SearchResult] = []
        for raw in rawResults {
            // Volume filter
            if let vids = parameters.volumeIds, !vids.contains(raw.volumeId) { continue }

            // Date filter
            if let keys = dateKeys, !keys.contains("\(raw.volumeId)/\(raw.documentId)") { continue }

            // Subject tag AND filter
            if !parameters.subjectTagIds.isEmpty {
                let has = parameters.subjectTagIds.allSatisfy { raw.subjectTagIds.contains($0) }
                if !has { continue }
            }

            // User tag AND filter
            if !parameters.userTagIds.isEmpty {
                let has = parameters.userTagIds.allSatisfy { raw.userTagIds.contains($0) }
                if !has { continue }
            }

            // Document type filter
            switch parameters.documentTypeFilter {
            case .documentsOnly:
                if raw.isEditorialNote { continue }
            case .editorialNotesOnly:
                if !raw.isEditorialNote { continue }
            case .all:
                break
            }

            filtered.append(SearchResult(
                documentId: raw.documentId,
                volumeId: raw.volumeId,
                documentNumber: nil,          // populated from document_cache in a future session
                header: raw.header,
                dateline: raw.dateline,
                sourceNote: raw.sourceNote,
                snippet: raw.snippet,
                bm25Score: raw.bm25Score,
                subjectTagIds: raw.subjectTagIds,
                userTagIds: raw.userTagIds,
                isEditorialNote: raw.isEditorialNote
            ))

            if filtered.count >= effectiveLimit { break }
        }

        return filtered
    }

    /// Returns the total number of results matching `parameters` (for pagination UI).
    ///
    /// Does not apply post-processing filters; the returned count is an upper bound.
    /// For accurate counts with complex filters, use `search` and count the results.
    public func searchCount(parameters: SearchParameters) async throws -> Int {
        let query = try makeFTS5Query(from: parameters)
        return try await fts5Store.searchCount(query: query)
    }

    // MARK: - Query Building

    /// Translates `SearchParameters` into an `FTS5Query`.
    ///
    /// Column scoping: when summaries or notes are excluded, searches only the
    /// content columns the user has opted into.
    public func makeFTS5Query(from parameters: SearchParameters) throws -> FTS5Query {
        let keywords = parameters.keywords?
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { !$0.isEmpty } ?? []

        // Build active column set
        var columns: [FTS5Column]? = nil
        if !parameters.includeSummaries || !parameters.includeNotes {
            var cols: [FTS5Column] = [.header, .dateline, .sourceNote, .bodyText]
            if parameters.includeSummaries { cols.append(.summaryText) }
            if parameters.includeNotes     { cols.append(.noteText) }
            columns = cols
        }

        // Single subject/user tag IDs passed to FTS5 for pre-filtering;
        // multiple tag IDs are handled by post-processing in search().
        let fts5SubjectTag = parameters.subjectTagIds.count == 1 ? parameters.subjectTagIds.first : nil
        let fts5UserTag    = parameters.userTagIds.count == 1    ? parameters.userTagIds.first    : nil

        let query = FTS5Query(
            keywords: keywords,
            phrase: parameters.phrase,
            booleanMode: parameters.booleanMode,
            excludedTerms: parameters.excludedTerms,
            prefixWildcard: parameters.prefixWildcard,
            subjectTagId: fts5SubjectTag,
            userTagId: fts5UserTag,
            columns: columns
        )

        // Validate that the query has at least one positive search term.
        guard query.toFTS5MatchExpression() != nil else {
            throw FTS5Error.emptyQuery
        }
        return query
    }
}
