// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - SearchService

/// Translates `SearchParameters` into the combined FTS5 search and returns typed
/// `SearchResult` values.
///
/// ## Query Construction
/// Document text (header, dateline, source note, body) lives in the
/// `frus_documents` FTS5 table; user-generated text (summaries, research notes)
/// lives in `user_content`. `makeMatchExpressions(from:)` renders one FTS5 MATCH
/// expression per table from the same raw search input, honouring the
/// `includeDocumentText` / `includeSummaries` / `includeNotes` scope flags.
///
/// ## Filtering & Pagination
/// All structured filters — volume IDs, date range, person ref, front matter,
/// subject/user tags, document type — are applied **inside the SQL** by
/// `IndexingPipeline.searchDocuments`, before `LIMIT`/`OFFSET`. Pagination is
/// therefore exact; there is no overscan or Swift-side post-filtering, and
/// `searchCount` agrees with the paginated results.
///
/// ## Snippets
/// FTS5 stores original (unstemmed) text, and each result row carries its body
/// text, so snippets are built in-process from the same row — no second query.
///
/// Version history:
///   1.0 — Session 09: initial implementation
///   1.1 — Session 38: document type filter applied in `search(_:limit:offset:)`
///   1.2 — Session 39: `personMentionStore` added; `personRef` filter applied in `search`
///   1.3 — Session 120: TEI-derived snippet pass from unstemmed `document_cache` text
///   1.4 — Session 122: `dateISO` populated for chronological sorting
///   1.5 — Session 123: post-processing round-trips merged into one call
///   1.6 — Session 129: unstemmed header/dateline substituted for FTS5-stemmed values
///   1.7 — Session 2026-06-08: `isFrontMatter` populated on results
///   2.0 — Session 2026-06-09: external-content redesign. Search runs as a single
///          SQL statement via `IndexingPipeline.searchDocuments` (corpus +
///          user-content match merge, SQL-side filters, exact pagination). The
///          stemmed-display repair pass and key-set whitelists are gone — FTS5 now
///          stores original text and filters evaluate in the database.
public actor SearchService {

    // MARK: - Dependencies

    private let fts5Store: FTS5Store
    private let pipeline: IndexingPipeline

    /// Retained for initialiser compatibility. Person-ref filtering is applied in
    /// SQL by `IndexingPipeline.searchDocuments` (an `EXISTS` against
    /// `person_mentions`); this store is no longer consulted during search.
    private let personMentionStore: PersonMentionStore?

    // MARK: - Pagination defaults

    /// Default number of results per page.
    public static let defaultPageSize = 20

    // MARK: - Initialisation

    /// Creates a `SearchService`.
    ///
    /// - Parameters:
    ///   - fts5Store: The shared FTS5 store (used for schema ownership; queries run
    ///     through `pipeline`).
    ///   - pipeline: The indexing pipeline that owns the combined search query and
    ///     auxiliary tables.
    ///   - personMentionStore: Unused by search since the SQL-side filter redesign;
    ///     accepted for initialiser compatibility.
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
    ///   - offset: Number of results to skip for pagination (exact — filters are
    ///     applied before pagination in SQL).
    /// - Returns: Matching documents ordered by BM25 relevance.
    /// - Throws: `FTS5Error.emptyQuery` if no searchable content can be constructed.
    public func search(
        parameters: SearchParameters,
        limit: Int = defaultPageSize,
        offset: Int = 0
    ) async throws -> [SearchResult] {
        let (corpusMatch, userMatch) = try makeMatchExpressions(from: parameters)
        let rows = try await pipeline.searchDocuments(
            corpusMatch: corpusMatch,
            userContentMatch: userMatch,
            filters: makeFilters(from: parameters),
            limit: limit,
            offset: offset
        )

        // Stem each positive term once; reused across all rows for highlighting.
        let queryTerms = positiveTerms(from: parameters)
        let stemmedQueryTerms = queryTerms.map { PorterStemmer.stem($0.lowercased()) }

        return rows.map { row in
            let snippet: String
            if !row.bodyText.isEmpty, !stemmedQueryTerms.isEmpty,
               let contextSnippet = Self.makeContextSnippet(
                   body: row.bodyText,
                   stemmedTerms: stemmedQueryTerms,
                   // Generate a generous window so the UI's adjustable `.lineLimit` (1–10 lines,
                   // #189-C) always has enough text to fill the chosen line count; the rendered
                   // length is clamped per surface at display time, not here.
                   contextRadius: 1000
               ) {
                snippet = contextSnippet
            } else {
                snippet = headerFallbackSnippet(header: row.header, dateline: row.dateline)
            }

            return SearchResult(
                documentId: row.documentId,
                volumeId: row.volumeId,
                documentNumber: row.documentNumber,
                header: row.header,
                dateline: row.dateline,
                dateISO: row.dateISO,
                sourceNote: row.sourceNote,
                snippet: snippet,
                bm25Score: row.score,
                subjectTagIds: Self.splitTagIds(row.subjectTagIds),
                userTagIds: Self.splitTagIds(row.userTagIds),
                isEditorialNote: row.isEditorialNote,
                isFrontMatter: row.isFrontMatter
            )
        }
    }

    /// Returns the exact total number of results matching `parameters`.
    ///
    /// Runs the same match expressions and SQL filters as `search`, so the count
    /// always agrees with the paginated result set.
    public func searchCount(parameters: SearchParameters) async throws -> Int {
        let (corpusMatch, userMatch) = try makeMatchExpressions(from: parameters)
        return try await pipeline.searchDocumentsCount(
            corpusMatch: corpusMatch,
            userContentMatch: userMatch,
            filters: makeFilters(from: parameters)
        )
    }

    /// Deterministically resolves the document carrying the given canonical printed
    /// number in a volume — the lookup path citation matching uses.
    ///
    /// Unlike `search(parameters:)`, this is a direct `document_cache` query, not a
    /// ranked full-text search: a bare number as a keyword matches every document that
    /// merely mentions the digits, and the BM25 result cap can starve out the actual
    /// document row in a realistically-sized volume.
    ///
    /// - Parameters:
    ///   - documentNumber: The canonical printed number as stored (e.g. `"15"`).
    ///   - volumeId: The volume to query.
    /// - Returns: The matching entry, or `nil` when the volume is not indexed or has
    ///   no document with that number.
    public func document(
        byNumber documentNumber: String,
        inVolume volumeId: String
    ) async throws -> DocumentBrowserEntry? {
        try await pipeline.document(forDocumentNumber: documentNumber, inVolume: volumeId)
    }

    // MARK: - Query Building

    /// Renders the corpus and user-content FTS5 MATCH expressions from the raw
    /// search input, honouring the scope flags.
    ///
    /// - `includeDocumentText` controls the `frus_documents` expression. Its indexed
    ///   columns are exactly the document text fields, so no column prefix is needed.
    /// - `includeSummaries`/`includeNotes` control the `user_content` expression;
    ///   when only one is enabled the expression is column-scoped to `summary_text`
    ///   or `note_text`.
    ///
    /// - Returns: A tuple of optional MATCH expressions; an element is `nil` when
    ///   its scope is disabled or the input renders to no positive content.
    /// - Throws: `FTS5Error.emptyQuery` when both expressions are `nil`.
    func makeMatchExpressions(
        from parameters: SearchParameters
    ) throws -> (corpus: String?, userContent: String?) {
        var corpus: String? = nil
        if parameters.includeDocumentText {
            corpus = renderExpression(from: parameters, columns: nil)
        }

        var userContent: String? = nil
        if parameters.includeSummaries || parameters.includeNotes {
            var columns: [FTS5Column]? = nil
            if !(parameters.includeSummaries && parameters.includeNotes) {
                columns = parameters.includeSummaries ? [.summaryText] : [.noteText]
            }
            userContent = renderExpression(from: parameters, columns: columns)
        }

        guard corpus != nil || userContent != nil else {
            // A person filter (a single ref, or a cross-corpus rollup from the People browser's
            // "Find all mentions") is a valid standalone constraint: run a filter-only query (no FTS
            // MATCH) instead of erroring. The pipeline's filter-only path applies the person filter.
            if parameters.personRef != nil || parameters.personRollupId != nil {
                return (nil, nil)
            }
            throw FTS5Error.emptyQuery
        }
        return (corpus, userContent)
    }

    /// Renders one FTS5 MATCH expression for the given column scope.
    ///
    /// The raw search-box text is parsed as Google-style inline syntax — quotes,
    /// `OR`, leading `-`, `NOT`, trailing `*` — by `FTS5InlineQueryParser`, with the
    /// column prefix applied to each operand. Structured fields (phrase, excluded
    /// terms, prefix wildcard) are rendered by `FTS5Query`.
    private func renderExpression(
        from parameters: SearchParameters,
        columns: [FTS5Column]?
    ) -> String? {
        let columnPrefix: String
        if let cols = columns, !cols.isEmpty {
            columnPrefix = "{\(cols.map(\.rawValue).joined(separator: " "))}:"
        } else {
            columnPrefix = ""
        }

        let keywordExpression = parameters.keywords.flatMap {
            FTS5InlineQueryParser.parse($0, columnPrefix: columnPrefix)
        }

        let query = FTS5Query(
            keywordExpression: keywordExpression,
            phrase: parameters.phrase,
            booleanMode: parameters.booleanMode,
            excludedTerms: parameters.excludedTerms,
            prefixWildcard: parameters.prefixWildcard,
            columns: columns
        )
        return query.toFTS5MatchExpression()
    }

    /// Maps `SearchParameters` to the SQL-side filter set.
    private func makeFilters(from parameters: SearchParameters) -> SearchSQLFilters {
        SearchSQLFilters(
            volumeIds: parameters.volumeIds,
            documentIds: parameters.documentIds,
            excludeDocumentIds: parameters.excludeDocumentIds,
            dateRange: parameters.dateRange,
            includeFrontMatter: parameters.includeFrontMatter,
            personRef: parameters.personRef,
            personRollupId: parameters.personRollupId,
            subjectTagIds: parameters.subjectTagIds,
            userTagIds: parameters.userTagIds,
            documentTypeFilter: parameters.documentTypeFilter
        )
    }

    /// Splits a space-separated tag-ID string into an array. Empty/nil → `[]`.
    private static func splitTagIds(_ raw: String?) -> [String] {
        guard let raw, !raw.isEmpty else { return [] }
        return raw.split(separator: " ").map(String.init)
    }

    // MARK: - Snippet Generation

    /// Returns the set of positive search terms (keywords + phrase words + prefix)
    /// that should be highlighted in the result snippet. Excluded terms are not
    /// included.
    private func positiveTerms(from parameters: SearchParameters) -> [String] {
        var terms: [String] = []
        if let kw = parameters.keywords {
            // Lightweight cleanup of inline-syntax artifacts so the snippet highlighter
            // bolds the words the user is actually searching *for* — not the operator
            // syntax around them. This intentionally doesn't run the full
            // `FTS5InlineQueryParser` (whose job is producing a MATCH expression, not a
            // highlight-term list); it just strips the same surface syntax the parser
            // recognises so e.g. `"cold war" OR blockade -korea` highlights "cold",
            // "war", and "blockade" without also bolding the literal words "OR" or
            // "korea" (which can never appear in a result anyway, since it's excluded)
            // or rendering quote/dash/asterisk characters in the snippet.
            var skipNextAsExcluded = false
            for rawToken in kw.split(whereSeparator: \.isWhitespace).map(String.init) {
                guard !rawToken.isEmpty else { continue }
                if skipNextAsExcluded {
                    skipNextAsExcluded = false
                    continue
                }
                // Operators are case-insensitive (matching FTS5InlineQueryParser), so
                // skip them in any case rather than bolding a literal "and"/"or".
                let upperToken = rawToken.uppercased()
                if upperToken == "OR" || upperToken == "AND" { continue }
                if upperToken == "NOT" { skipNextAsExcluded = true; continue }
                if rawToken.hasPrefix("-"), rawToken.count > 1 { continue }

                var token = rawToken
                if token.hasPrefix("\"") { token = String(token.dropFirst()) }
                if token.hasSuffix("\"") { token = String(token.dropLast()) }
                if token.hasSuffix("*"), token.count > 1 { token = String(token.dropLast()) }
                guard !token.isEmpty else { continue }
                terms.append(token)
            }
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

    /// Builds a minimal fallback snippet from a header and dateline string.
    ///
    /// Used when no body word matches a stemmed query term (e.g. the match was in a
    /// summary or note rather than the document body, or the app-side Porter stem
    /// disagrees with SQLite's). Showing the header and dateline is preferable to an
    /// empty snippet row.
    private func headerFallbackSnippet(header: String, dateline: String?) -> String {
        [header, dateline]
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
    ///     each side of the match. The caller passes a generous value (~1000) so the
    ///     result string can fill up to the 10-line maximum the UI's adjustable
    ///     `.lineLimit` may request (#189-C); the visible length is clamped at render time.
    nonisolated static func makeContextSnippet(
        body: String,
        stemmedTerms: [String],
        contextRadius: Int
    ) -> String? {
        guard !body.isEmpty, !stemmedTerms.isEmpty else { return nil }
        let stems = Set(stemmedTerms)

        // A sound, near-free rejection test, applied before any allocation.
        //
        // The Porter stemmer only strips or rewrites SUFFIXES — no rule alters a word's
        // first character — so a word whose first letter is not among the query stems' first
        // letters cannot possibly stem to one. Testing that costs a lowercase and a set
        // probe; the alternative was three String allocations and a full stem, per word, for
        // every word in the body.
        //
        // This is what made a failed match expensive. On a corpus search the body scan runs
        // to completion — measured on the real 316,839-document index, macOS's 7,500-row
        // fetch spent 41 s stemming ~6 million words and then discarded every result to fall
        // back to the header. Roughly 24 words in 25 now stop at a character comparison.
        var firstLetters = Set<Character>()
        for term in stemmedTerms {
            if let first = term.first { firstLetters.insert(first) }
        }

        // Walk the body and find the first word whose Porter stem hits the query set.
        let scalars = Array(body)
        var i = 0
        let n = scalars.count
        while i < n {
            // Skip non-letters.
            while i < n, !scalars[i].isLetter { i += 1 }
            guard i < n else { break }
            let wordStart = i
            var sawPunctuation = false
            while i < n, scalars[i].isLetter || scalars[i] == "'" || scalars[i] == "-" {
                if !scalars[i].isLetter { sawPunctuation = true }
                i += 1
            }
            let wordEnd = i

            // The cheap gate. `lowercased()` on a single Character allocates nothing for the
            // ASCII case and the set probe is O(1).
            guard let head = scalars[wordStart].lowercased().first,
                  firstLetters.contains(head) else { continue }

            let word = String(scalars[wordStart..<wordEnd])
            // Only strip when the scan actually consumed an apostrophe or hyphen, which is
            // rare — `filter` allocates a second String every time it is called.
            let alpha = sawPunctuation ? word.filter { $0.isLetter } : word
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
