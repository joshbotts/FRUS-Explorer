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
    /// The SQL filters `parameters` renders to — so a facet computation runs against the
    /// identical filter set the search itself applies.
    ///
    /// Exposed for R-1's facet aggregation and its tests: facets describe the set the
    /// researcher is looking at, which is only true if both sides derive their filters from
    /// one place.
    func filtersForTesting(_ parameters: SearchParameters) -> SearchSQLFilters {
        makeFilters(from: parameters)
    }

    /// The index term SQLite's tokenizer produces for `word`, or `nil` when the word is
    /// not exactly one token.
    ///
    /// A pass-through to the store, so the Query Inspector needs one dependency rather
    /// than two — and so the stem it displays is the one the search's own store computed.
    public func indexStem(of word: String) async throws -> String? {
        try await fts5Store.indexStem(of: word)
    }

    /// Corpus-wide document frequency for an index term, unscoped by any filter.
    public func corpusDocumentFrequency(forStem stem: String) async throws -> Int? {
        try await fts5Store.vocabularyEntry(stem: stem)?.documentFrequency
    }

    /// Corpus-wide document frequency **and occurrence count** for an index term, unscoped.
    ///
    /// Same single `fts5vocab` row as ``corpusDocumentFrequency(forStem:)``, which read `doc` and
    /// discarded `cnt` — the occurrence half was already being fetched and thrown away on every
    /// inspection.
    ///
    /// The pair is worth more than either number alone: `documentFrequency` counts documents
    /// containing the stem, `occurrences` counts how many times it appears, and their ratio is the
    /// "one memo with a tic" detector. On this corpus the two can point in opposite directions —
    /// "Article 43" appears in 34 documents in 1948 and 11 in 1949, while its occurrences *rise*
    /// 77 → 92, because one 1949 document carries 54 of them. A frequency count alone reads that
    /// as a topic disappearing.
    ///
    /// Both figures are **corpus-wide and unfiltered** — the whole local index, ignoring scope,
    /// date range and every other filter. Any surface showing them has to say so, or a researcher
    /// will read them as describing their current result set.
    public func corpusTermProfile(forStem stem: String) async throws -> (documentFrequency: Int, occurrences: Int)? {
        try await fts5Store.vocabularyEntry(stem: stem)
    }

    /// The rendered MATCH expression(s) for `parameters`, for the Query Inspector.
    ///
    /// A thin public face on `makeMatchExpressions` so the inspector displays exactly the
    /// strings the search executed — not a second rendering that could drift from it.
    /// Rethrows `FTS5Error.emptyQuery` for a query with no searchable content at all.
    public func matchExpressions(
        for parameters: SearchParameters
    ) throws -> (corpus: String?, userContent: String?) {
        try makeMatchExpressions(from: parameters)
    }

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
            // "Find all mentions") or a subject filter is a valid standalone constraint: run a
            // filter-only query (no FTS MATCH) instead of erroring. The pipeline's filter-only path
            // applies it SQL-side. `supportsFilterOnlySearch` is the single rule — see its
            // documentation for why this is not an enumeration repeated at four sites (#1022).
            // ...but only when there is genuinely no text to run. Reaching here WITH text means
            // every content scope is off, which is a scope error; running the bare filter would
            // silently discard what the reader typed (#1022 review).
            if parameters.runsAsFilterOnly {
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
    ///
    /// ## The subject bucket is re-resolved here, and only here
    /// `subjectBucketKey` is the durable `category`/`subcategory` pair; `subjectBucket` is a
    /// position in the vocabulary. Every path — a fresh facet tap, a recalled saved search, a
    /// hand-off — funnels through this one function on its way to SQL, so re-resolving here fixes
    /// all of them at once, where doing it at each recall site would be several places to forget.
    ///
    /// `-1` is the "matches nothing" sentinel: a key whose pair has been removed from the
    /// vocabulary must NOT fall back to `nil`, which reads as "no subject filter" and would widen
    /// a saved search to the whole corpus under a name promising the opposite.
    private func makeFilters(from parameters: SearchParameters) -> SearchSQLFilters {
        let resolvedBucket: Int?
        if let key = parameters.subjectBucketKey {
            resolvedBucket = DocumentSubjectStore.shared?.bucketVocabulary.id(forKey: key) ?? -1
        } else {
            resolvedBucket = parameters.subjectBucket
        }
        return SearchSQLFilters(
            volumeIds: parameters.volumeIds,
            documentIds: parameters.documentIds,
            subjectBucket: resolvedBucket,
            excludeDocumentIds: parameters.excludeDocumentIds,
            dateRange: parameters.dateRange,
            yearKeys: parameters.yearKeys,
            includeFrontMatter: parameters.includeFrontMatter,
            personRef: parameters.personRef,
            personRollupId: parameters.personRollupId,
            subjectTagIds: parameters.subjectTagIds,
            userTagIds: parameters.userTagIds,
            documentTypeFilter: parameters.documentTypeFilter,
            exactTerms: Self.exactTerms(from: parameters),
            exactColumns: Self.exactColumns(for: parameters)
        )
    }

    /// The words this query marked exact with `=`.
    ///
    /// Parsed from the same raw text and by the same parser that builds the MATCH
    /// expression, so the two can never disagree about which terms were marked.
    static func exactTerms(from parameters: SearchParameters) -> [String] {
        guard let keywords = parameters.keywords else { return [] }
        return FTS5InlineQueryParser.parseDetailed(keywords).exactTerms
    }

    /// The `document_cache` columns an exact term may be satisfied by — the columns this
    /// query actually searched.
    ///
    /// Scope-dependent on purpose. With summaries off, a literal match inside a summary
    /// must not rescue a document: the query never looked there, so counting it would
    /// make the exact filter *broader* than the search it refines. The corpus columns
    /// come as a set of four because `renderExpression` never scopes the corpus
    /// expression to a subset of them.
    static func exactColumns(for parameters: SearchParameters) -> [String] {
        var columns: [String] = []
        if parameters.includeDocumentText {
            columns += ["header", "dateline", "source_note", "body_text"]
        }
        if parameters.includeSummaries { columns.append("summary_text") }
        if parameters.includeNotes { columns.append("note_text") }
        return columns
    }

    /// Splits a space-separated tag-ID string into an array. Empty/nil → `[]`.
    private static func splitTagIds(_ raw: String?) -> [String] {
        guard let raw, !raw.isEmpty else { return [] }
        return raw.split(separator: " ").map(String.init)
    }

    // MARK: - Snippet Generation

    /// Rewrites `NEAR(...)` spans down to just their operand words, so the snippet
    /// highlighter bolds what the researcher searched for rather than the operator
    /// scaffolding around it.
    ///
    /// Without this, `NEAR("military guarantee" europe, 30)` splits on whitespace into
    /// `NEAR("military`, `guarantee"`, `europe,` and `30)` — none of which the existing
    /// operator/quote/dash cleanup recognises — so the snippet would bold the literal
    /// text `NEAR("military` and the distance `30`. Both are syntax, not content.
    ///
    /// Deliberately a surface rewrite in the same spirit as the cleanup it feeds, not a
    /// second parser: it removes the keyword (in either accepted spelling), the operator's
    /// parentheses, and a trailing `, N` distance, and leaves every operand — including
    /// quoted phrases — for the existing loop to handle exactly as it already handles a
    /// bare phrase.
    ///
    /// The distance is only dropped when it sits in the distance position. A bare `1948`
    /// typed as an operand is a real search term and survives.
    static func strippingNearScaffolding(_ raw: String) -> String {
        // Cheap bail-out: the overwhelming majority of queries contain no NEAR at all.
        guard raw.range(of: "near", options: .caseInsensitive) != nil else { return raw }

        var out = ""
        var rest = Substring(raw)
        while let keyword = rest.range(of: #"(?i)\bNEAR(/[0-9]+)?\s*\("#, options: .regularExpression) {
            out += rest[..<keyword.lowerBound]
            // Walk to the operator's matching close paren, tracking depth and quotes so a
            // paren inside a phrase cannot terminate the span early.
            var depth = 0
            var inQuotes = false
            var index = keyword.upperBound
            var closed = false
            // `keyword` ends just past the opening paren, so depth starts at one.
            depth = 1
            while index < rest.endIndex {
                let character = rest[index]
                if character == "\"" {
                    inQuotes.toggle()
                } else if !inQuotes, character == "(" {
                    depth += 1
                } else if !inQuotes, character == ")" {
                    depth -= 1
                    if depth == 0 { closed = true; break }
                }
                index = rest.index(after: index)
            }
            guard closed else {
                // Unbalanced — emit the remainder untouched rather than guessing.
                out += rest[keyword.lowerBound...]
                return out
            }
            var body = String(rest[keyword.upperBound..<index])
            // Drop a trailing `, N` distance, quote-aware so `NEAR("cold, war" x)` keeps
            // its phrase intact.
            if let separator = Self.lastUnquotedComma(in: body) {
                let tail = body[body.index(after: separator)...]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !tail.isEmpty, tail.allSatisfy({ $0.isASCII && $0.isNumber }) {
                    body = String(body[..<separator])
                }
            }
            out += " " + body + " "
            rest = rest[rest.index(after: index)...]
        }
        out += rest
        return out
    }

    /// The index of the last comma in `text` that is not inside a double-quoted phrase,
    /// or `nil` when there is none.
    static func lastUnquotedComma(in text: String) -> String.Index? {
        var inQuotes = false
        var found: String.Index? = nil
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            if character == "\"" {
                inQuotes.toggle()
            } else if character == ",", !inQuotes {
                found = index
            }
            index = text.index(after: index)
        }
        return found
    }

    /// Returns the set of positive search terms (keywords + phrase words + prefix)
    /// that should be highlighted in the result snippet. Excluded terms are not
    /// included.
    // MARK: - Concordance (R-3b)

    /// Builds a keyword-in-context concordance for the given results.
    ///
    /// ## Why this takes results rather than parameters
    /// It concordances **exactly the rows on screen**. Passing parameters and re-running the search
    /// would let the concordance and the list disagree about what they are showing, and passing the
    /// whole retained set would fetch body text for up to 7,500 documents — 37 MB on macOS, for a
    /// view showing twenty lines. The caller hands over its displayed page.
    ///
    /// ## Why body text is fetched here and not carried on `SearchResult`
    /// `SearchResult` deliberately has no `bodyText`. The view models retain 1,000 results on iOS and
    /// 7,500 on macOS, so a body per result would be a permanent memory cost paid by every search,
    /// for a mode most searches never open — the same mistake the occurrence measure made and had to
    /// undo. One keyed fetch for the visible page instead.
    ///
    /// - Parameters:
    ///   - results: the displayed page, in display order.
    ///   - parameters: the executed query, for its positive terms.
    ///   - radius: context characters either side of each match.
    /// - Returns: lines in the order the results were given, plus the number of occurrences the
    ///   per-document bound dropped. Documents with no aligned occurrence contribute no lines —
    ///   which is a real possibility, because matching here uses the Swift `PorterStemmer` while the
    ///   index used SQLite's; see ``KWICBuilder/build(body:stems:radius:volumeId:documentId:header:dateISO:)``.
    func concordance(
        for results: [SearchResult],
        parameters: SearchParameters,
        radius: Int = 60
    ) async throws -> ConcordanceResult {
        let stems = positiveTerms(from: parameters).map { PorterStemmer.stem($0.lowercased()) }
        guard !results.isEmpty, !stems.isEmpty else {
            return ConcordanceResult(lines: [], omittedCount: 0, documentsWithoutLines: 0)
        }
        let keys = results.map {
            WordCloudDocumentKey(volumeId: $0.volumeId, documentId: $0.documentId)
        }
        let bodies = try await pipeline.documentBodyTextsByKey(forKeys: keys)

        var lines: [KWICLine] = []
        var omitted = 0
        var documentsWithoutLines = 0
        for result in results {
            guard let body = bodies["\(result.volumeId)/\(result.documentId)"] else {
                documentsWithoutLines += 1
                continue
            }
            let scan = KWICBuilder.build(
                body: body, stems: stems, radius: radius,
                volumeId: result.volumeId, documentId: result.documentId,
                header: result.header, dateISO: result.dateISO)
            if scan.lines.isEmpty { documentsWithoutLines += 1 }
            lines.append(contentsOf: scan.lines)
            omitted += scan.omittedCount
        }
        return ConcordanceResult(lines: lines, omittedCount: omitted,
                                 documentsWithoutLines: documentsWithoutLines)
    }



    /// Words the query's matches keep company with, ranked by how distinctive that company is.
    ///
    /// ## Why this takes the whole retained set where the concordance takes a page
    /// The concordance shows *these lines*, so it must agree with the rows on screen. A collocation
    /// is a *measure*, and a measure over twenty-five documents cannot clear its own floor: a page
    /// yields ~400 window tokens across ~290 distinct lemmas, so almost nothing reaches three
    /// occurrences and the panel reads as broken rather than bounded. Measured on the real index:
    /// the whole retained iOS set is 4.3 MB and about 1.4 s; a page is 0.1 MB and empty.
    ///
    /// ## The bound is on MATCHES, not documents or bytes
    /// Cost has two drivers and they scale differently. Bytes drive the fetch and the scan; matches
    /// drive the `NLTagger` pass, which is the expensive one — measured at 80,124 surviving
    /// tokens/sec, a dense query over a full macOS set is 6.4 s of tagging against 4.2 s of
    /// everything else. A byte cap leaves that unbounded. `maxMatches` caps the term that actually
    /// costs, and ``CollocationResult/wasBounded`` reports when it bit.
    ///
    /// - Parameters:
    ///   - results: the retained result set — everything the user could page to, not the page.
    ///   - parameters: the executed query, for its positive terms.
    ///   - windowSize: words either side of each match.
    ///   - configuration: the resolved live tokenisation. The caller resolves it on the main actor.
    func collocation(
        for results: [SearchResult],
        parameters: SearchParameters,
        windowSize: Int,
        configuration: CollocationConfiguration,
        reference: (terms: [String: Int], totalTokens: Int, cutoffCount: Int),
        generated: String?,
        maxMatches: Int? = nil
    ) async throws -> CollocationAnalysis.Outcome {
        let maxMatches = maxMatches ?? Self.collocationMatchBudget(windowSize: windowSize)
        // The same set the concordance and the highlighter anchor on, so the words treated as
        // matches are the words the reader sees marked. For a `NEAR(a b, N)` query that set holds
        // BOTH operands, so the collocates are of the pair — the right reading of "what appears
        // near this query", and worth stating on screen.
        let terms = positiveTerms(from: parameters)
        let stems = terms.map { PorterStemmer.stem($0.lowercased()) }
        guard !results.isEmpty, !stems.isEmpty else { return .unavailable(.noMatches) }

        let keys = results.map {
            WordCloudDocumentKey(volumeId: $0.volumeId, documentId: $0.documentId)
        }
        var counts: [String: Int] = [:]
        var windowTokenCount = 0
        var documentsScanned = 0
        var anchorCount = 0
        var omittedAnchorCount = 0
        var budgetSpent = 0
        var documentsOffered = 0

        // Chunked the way every other bulk body-text reader in the app is: one keyed fetch per 400
        // documents, scanned, then dropped. The whole retained set is never resident at once, which
        // is what keeps a 7,500-result macOS search from holding 32 MB of prose.
        var offset = 0
        while offset < keys.count, budgetSpent < maxMatches {
            try Task.checkCancellation()
            let chunk = Array(keys[offset..<min(offset + Self.collocationChunkSize, keys.count)])
            offset += Self.collocationChunkSize
            let bodies = try await pipeline.documentBodyTextsByKey(forKeys: chunk)

            // The scan is per-document and independent, so it fans out. Measured single-threaded, a
            // dense macOS set is ~2.7 s of scanning alone; this is the difference between a panel
            // that appears and one that looks hung.
            let scans = await withTaskGroup(of: CollocationWindow.DocumentScan.self) { group in
                for key in chunk {
                    guard let body = bodies["\(key.volumeId)/\(key.documentId)"] else { continue }
                    group.addTask {
                        CollocationWindow.scan(body: body, stems: stems, windowSize: windowSize)
                    }
                }
                var collected: [CollocationWindow.DocumentScan] = []
                for await scan in group { collected.append(scan) }
                return collected
            }

            // Runs are joined with a newline, never a space: two passages from opposite ends of a
            // document are not a sentence, and the lemmatiser is context-dependent. A line break is
            // the cheapest boundary it respects.
            var windowText: [String] = []
            documentsOffered += chunk.count
            for scan in scans {
                documentsScanned += 1
                anchorCount += scan.anchorCount
                omittedAnchorCount += scan.omittedAnchorCount
                budgetSpent += scan.anchorCount
                windowText.append(contentsOf: scan.runs)
            }
            if !windowText.isEmpty {
                // One tokenizer pass per CHUNK rather than per window: `accumulate` builds a fresh
                // `NLTagger` on every call, and a window-at-a-time loop would construct thousands.
                windowTokenCount += configuration.tokenizer
                    .accumulate(from: windowText.joined(separator: "\n"), into: &counts)
            }
        }

        // The query's own terms, in the form the collocates are counted in, so the exclusion
        // compares like with like. Stems would not match — the counts are lemmas.
        var anchorLemmas: [String: Int] = [:]
        configuration.tokenizer.accumulate(from: terms.joined(separator: "\n"), into: &anchorLemmas)

        return CollocationAnalysis.rank(
            counts: counts,
            windowTokenCount: windowTokenCount,
            anchorLemmas: Set(anchorLemmas.keys),
            windowSize: windowSize,
            documentsScanned: documentsScanned,
            documentsInScope: results.count,
            // What the BUDGET stopped, distinct from what simply had no cached body text.
            // `documentsScanned < documentsInScope` conflates the two, and a scan that covered
            // everything it was offered must not report itself as truncated.
            documentsOffered: documentsOffered,
            anchorCount: anchorCount,
            omittedAnchorCount: omittedAnchorCount,
            reference: reference,
            generated: generated
        )
    }

    /// Window tokens collected before the scan stops — the budget on the term that actually costs.
    ///
    /// 200,000 surviving tokens is about 2.5 s of tagging at the measured 80,124 tokens/sec. That
    /// covers every iOS result set outright and every sparse macOS one; it clips only a dense query
    /// over a full macOS set, where the collocates drawn from a 200,000-token sample are
    /// statistically indistinguishable from those drawn from the whole.
    static let collocationTokenBudget = 200_000

    /// Matches affordable at a given window size.
    ///
    /// The budget is on TOKENS, not matches, because a match is not a fixed amount of work: at ±10 a
    /// match contributes ~10 surviving tokens, at ±50 about five times that. A fixed match budget
    /// calibrated at ±10 would let the ±50 the picker offers cost five times its measurement — 12 s
    /// where 2.5 s was intended, on a control the user is invited to move.
    static func collocationMatchBudget(windowSize: Int) -> Int {
        // ~48% of raw words survive stopwording and the length floor, measured corpus-wide:
        // 1,286 MB of body text yields 94.6M surviving tokens, ~13.6 bytes each against ~6.5
        // bytes per raw word.
        let tokensPerMatch = max(1, Int((Double(2 * windowSize) * 0.48).rounded()))
        return max(1, collocationTokenBudget / tokensPerMatch)
    }

    /// Documents per keyed body-text fetch, matching every other bulk reader in the app (400 pairs
    /// is 800 binds, under SQLite's 999-variable limit).
    static let collocationChunkSize = 400

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
            for rawToken in Self.strippingNearScaffolding(kw)
                .split(whereSeparator: \.isWhitespace).map(String.init) {
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
