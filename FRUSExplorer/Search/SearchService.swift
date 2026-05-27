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
///   1.2 — Session 39: `personMentionStore` added; `personRef` filter applied in `search`
///   1.3 — Session 120: TEI-derived snippet pass. After the FTS5 row set is filtered,
///          each result's `snippet` is regenerated from the unstemmed
///          `document_cache.body_text` so users see the actual word forms in the
///          document rather than stemmed tokens. The match window is sized for two
///          full lines of surrounding context.
///   1.4 — Session 122: `dateISO` populated on every `SearchResult` from
///          `document_dates.date_iso` via a batched lookup. Enables chronologically
///          correct date-asc / date-desc sorting in the macOS search window.
///   1.5 — Session 123: performance pass — `rebuildSnippetsFromTEI` + `attachDates`
///          replaced by `rebuildSnippetsAndAttachDates`, which fetches body text and
///          dates together via `IndexingPipeline.documentBodyTextsAndDates(for:)`.
///          Halves actor round-trips and SQL statements for the post-processing phase.
public actor SearchService {

    // MARK: - Dependencies

    private let fts5Store: FTS5Store
    private let pipeline: IndexingPipeline
    private let personMentionStore: PersonMentionStore?

    // MARK: - Pagination defaults

    public static let defaultPageSize = 20

    // MARK: - Initialisation

    /// Creates a `SearchService`.
    ///
    /// - Parameters:
    ///   - fts5Store: The shared FTS5 store containing indexed documents.
    ///   - pipeline: The indexing pipeline that owns the `document_dates` auxiliary table.
    ///   - personMentionStore: Optional store for person ref filtering. When `nil`,
    ///     `SearchParameters.personRef` is silently ignored.
    public init(
        fts5Store: FTS5Store,
        pipeline: IndexingPipeline,
        personMentionStore: PersonMentionStore? = nil
    ) {
        self.fts5Store = fts5Store
        self.pipeline = pipeline
        self.personMentionStore = personMentionStore
    }

    // MARK: - Public API

    /// Executes a search and returns ranked results.
    ///
    /// - Parameters:
    ///   - parameters: Search criteria.
    ///   - limit: Maximum results to return.
    ///   - offset: Number of results to skip for pagination.
    /// - Returns: Matching documents ordered by BM25 relevance.
    /// - Throws: `FTS5Error.emptyQuery` if no searchable content can be constructed.
    public func search(
        parameters: SearchParameters,
        limit: Int = defaultPageSize,
        offset: Int = 0
    ) async throws -> [SearchResult] {
        let query = try makeFTS5Query(from: parameters)
        let effectiveLimit = limit

        // Build date-range whitelist if requested.
        let dateKeys: Set<String>? = try await {
            guard let range = parameters.dateRange else { return nil }
            return try await pipeline.documentKeysInDateRange(range, limitToVolumeIds: parameters.volumeIds)
        }()

        // Build person-ref whitelist if requested.
        let personKeys: Set<String>? = try await {
            guard let ref = parameters.personRef,
                  let store = personMentionStore else { return nil }
            let pairs = try await store.documents(forPersonRef: ref)
            return Set(pairs.map { "\($0.volumeId)/\($0.documentId)" })
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

            // Person ref filter
            if let keys = personKeys, !keys.contains("\(raw.volumeId)/\(raw.documentId)") { continue }

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
                dateISO: nil,                 // populated by rebuildSnippetsAndAttachDates below
                sourceNote: raw.sourceNote,
                snippet: raw.snippet,         // empty string (FTS5 snippet() removed); replaced below
                bm25Score: raw.bm25Score,
                subjectTagIds: raw.subjectTagIds,
                userTagIds: raw.userTagIds,
                isEditorialNote: raw.isEditorialNote
            ))

            if filtered.count >= effectiveLimit { break }
        }

        // Build TEI-derived snippets and attach ISO dates in a single actor round-trip.
        // `documentBodyTextsAndDates` fetches body_text + date_iso with one CTE join,
        // replacing what was previously two sequential calls (rebuildSnippetsFromTEI
        // + attachDates) with two separate SQL queries and two actor hops.
        return await rebuildSnippetsAndAttachDates(
            results: filtered,
            queryTerms: positiveTerms(from: parameters)
        )
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
    /// Column scoping: when any scope flag is `false`, only the opted-in columns
    /// are searched. When all flags are `true`, `columns` is `nil` and FTS5
    /// searches all columns (the default, fastest path).
    public func makeFTS5Query(from parameters: SearchParameters) throws -> FTS5Query {
        let keywords = parameters.keywords?
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { !$0.isEmpty } ?? []

        // Build active column set.
        // Document text columns (header, dateline, sourceNote, bodyText) are included
        // only when `includeDocumentText` is true. Summary and note columns are additive.
        // When all flags are true the full FTS5 default search (columns: nil) is used.
        var columns: [FTS5Column]? = nil
        let needsColumnFilter = !parameters.includeDocumentText
                             || !parameters.includeSummaries
                             || !parameters.includeNotes
        if needsColumnFilter {
            var cols: [FTS5Column] = []
            if parameters.includeDocumentText {
                cols.append(contentsOf: [.header, .dateline, .sourceNote, .bodyText])
            }
            if parameters.includeSummaries { cols.append(.summaryText) }
            if parameters.includeNotes     { cols.append(.noteText) }
            columns = cols.isEmpty ? nil : cols
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

    // MARK: - TEI Snippet Generation

    /// Returns the set of positive search terms (keywords + phrase words + prefix)
    /// that should be highlighted in the result snippet. Excluded terms are not
    /// included.
    private func positiveTerms(from parameters: SearchParameters) -> [String] {
        var terms: [String] = []
        if let kw = parameters.keywords {
            terms.append(contentsOf: kw
                .split(whereSeparator: \.isWhitespace)
                .map(String.init)
                .filter { !$0.isEmpty })
        }
        if let phrase = parameters.phrase, !phrase.isEmpty {
            terms.append(contentsOf: phrase
                .split(whereSeparator: \.isWhitespace)
                .map(String.init)
                .filter { !$0.isEmpty })
        }
        if let prefix = parameters.prefixWildcard, !prefix.isEmpty {
            terms.append(prefix)
        }
        // De-duplicate case-insensitively while preserving order.
        var seen = Set<String>()
        return terms.filter { seen.insert($0.lowercased()).inserted }
    }

    /// Builds TEI-derived snippets and attaches ISO dates to every result in a
    /// single `IndexingPipeline` round-trip.
    ///
    /// Calls `pipeline.documentBodyTextsAndDates(for:)`, which issues one CTE-join
    /// query per chunk of 400 keys to fetch both `body_text` (unstemmed, from
    /// `document_cache`) and `date_iso` (from `document_dates`) simultaneously.
    /// This replaces the previous two-step pattern (`rebuildSnippetsFromTEI` +
    /// `attachDates`) which required two separate actor hops and SQL statements.
    ///
    /// **Snippet building**: the body text is scanned word-by-word; the first word
    /// whose Porter stem matches any positive query term is wrapped in `<b>…</b>`
    /// with ~400 characters of surrounding context (approximately two lines at the
    /// macOS list font).
    ///
    /// **Date attachment**: `dateISO` is populated from `date_iso`; results without
    /// a stored date keep `dateISO == nil` and are placed at the end of sorted lists.
    ///
    /// **Cache miss fallback**: documents absent from `document_cache` receive a
    /// snippet of `header · dateline` so the result row is never blank.
    private func rebuildSnippetsAndAttachDates(
        results: [SearchResult],
        queryTerms: [String]
    ) async -> [SearchResult] {
        guard !results.isEmpty else { return results }

        // Stem each positive term once; the same set is reused across all rows.
        let stemmedQueryTerms = queryTerms.isEmpty ? [] : queryTerms.map { PorterStemmer.stem($0.lowercased()) }

        let keys = results.map { (volumeId: $0.volumeId, documentId: $0.documentId) }
        let bodies: [String: String]
        let dates:  [String: String]
        do {
            (bodies, dates) = try await pipeline.documentBodyTextsAndDates(for: keys)
        } catch {
            #if DEBUG
            print("[SearchService] documentBodyTextsAndDates failed: \(error) — snippets and date sort will degrade")
            #endif
            return results
        }

        return results.map { result in
            let key = "\(result.volumeId)/\(result.documentId)"
            let dateISO = dates[key]

            let snippet: String
            if let body = bodies[key], !body.isEmpty, !stemmedQueryTerms.isEmpty {
                // Build TEI-derived context snippet; falls back to header·dateline on miss.
                snippet = Self.makeContextSnippet(
                    body: body,
                    stemmedTerms: stemmedQueryTerms,
                    contextRadius: 200
                ) ?? headerFallbackSnippet(result)
            } else {
                // Cache miss or no query terms: show header + dateline as minimal context.
                snippet = headerFallbackSnippet(result)
            }

            return SearchResult(
                documentId: result.documentId,
                volumeId: result.volumeId,
                documentNumber: result.documentNumber,
                header: result.header,
                dateline: result.dateline,
                dateISO: dateISO,
                sourceNote: result.sourceNote,
                snippet: snippet,
                bm25Score: result.bm25Score,
                subjectTagIds: result.subjectTagIds,
                userTagIds: result.userTagIds,
                isEditorialNote: result.isEditorialNote
            )
        }
    }

    /// Builds a minimal fallback snippet from a result's header and dateline fields.
    ///
    /// Used when the `document_cache` body text is unavailable for a result (e.g. a
    /// volume that was just indexed and whose cache row hasn't landed yet). Showing
    /// the header and dateline is preferable to an empty snippet row.
    private func headerFallbackSnippet(_ result: SearchResult) -> String {
        [result.header, result.dateline]
            .compactMap { s in (s?.isEmpty == false) ? s : nil }
            .joined(separator: " · ")
    }

    /// Builds a `<b>…</b>`-marked context snippet from a document body string.
    ///
    /// The body is scanned word-by-word; the first word whose Porter stem matches
    /// any entry in `stemmedTerms` is wrapped in `<b>…</b>` and ~`contextRadius`
    /// characters of text on either side are included. The window is snapped to
    /// word boundaries so the snippet does not begin or end mid-word, and ellipses
    /// are added when the body extends beyond the window.
    ///
    /// Returns `nil` if no word in `body` matches any stemmed term — callers should
    /// fall back to the header/dateline fallback so the result row is never blank.
    ///
    /// - Parameters:
    ///   - body: The unstemmed, plain-text document body to search.
    ///   - stemmedTerms: Query terms already reduced to their Porter stems.
    ///   - contextRadius: Approximate number of characters of context to include on
    ///     each side of the match. 200 chars ≈ two lines at the 12-point macOS list
    ///     font with a typical column width.
    nonisolated static func makeContextSnippet(
        body: String,
        stemmedTerms: [String],
        contextRadius: Int
    ) -> String? {
        guard !body.isEmpty, !stemmedTerms.isEmpty else { return nil }
        let stems = Set(stemmedTerms)

        // Walk the body and find the first word whose Porter stem hits the query set.
        let scalars = Array(body)
        var i = 0
        let n = scalars.count
        while i < n {
            // Skip non-letters.
            while i < n, !scalars[i].isLetter { i += 1 }
            guard i < n else { break }
            let wordStart = i
            while i < n, scalars[i].isLetter || scalars[i] == "'" || scalars[i] == "-" {
                i += 1
            }
            let wordEnd = i
            let word = String(scalars[wordStart..<wordEnd])
            let alpha = word.filter { $0.isLetter }
            let stem = alpha.isEmpty ? word.lowercased() : PorterStemmer.stem(alpha.lowercased())
            if stems.contains(stem) {
                // Found a match. Build the surrounding window.
                let lowerBound = max(0, wordStart - contextRadius)
                let upperBound = min(n, wordEnd + contextRadius)
                // Snap to word boundaries so we don't begin/end mid-word.
                var snapLow = lowerBound
                while snapLow > 0, scalars[snapLow - 1].isLetter { snapLow -= 1 }
                var snapHigh = upperBound
                while snapHigh < n, scalars[snapHigh].isLetter { snapHigh += 1 }
                let prefix = String(scalars[snapLow..<wordStart])
                let highlight = String(scalars[wordStart..<wordEnd])
                let suffix = String(scalars[wordEnd..<snapHigh])
                var out = ""
                if snapLow > 0 { out += "… " }
                out += prefix
                out += "<b>" + highlight + "</b>"
                out += suffix
                if snapHigh < n { out += " …" }
                return out
            }
        }
        return nil
    }
}
