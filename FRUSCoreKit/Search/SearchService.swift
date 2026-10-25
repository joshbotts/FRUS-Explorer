// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
#if canImport(FTS5Store)
import FTS5Store
#endif

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
/// A keyword row's window is cut from the document's prose, after its own heading, source
/// note and dateline (``keywordSnippet(body:header:dateline:sourceNote:stemmedTerms:)``).
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
///   2.1 — #1297 join: `parsedQuery(for:columnPrefix:)` parses the typed keywords and the
///          structured phrase, prefix and excluded terms as one query, and both the MATCH
///          expression and the exact-word terms come from it. The typed text used to be
///          rendered alone and handed to `FTS5Query` as a string, which discarded a typed
///          exclusion beside a restored phrase or prefix. RESULTS MOVE for those searches.
///   2.2 — #1297 fixes review: `makeMatchExpressions` runs no scope for a query the unscoped
///          parse refuses. `exactTerms(from:)` and the Query Inspector read that parse, so a
///          summaries-only or notes-only search could run a single-column render beside the
///          refusal with its `=` post-filter silently empty — `=cold "korea" -korea OR -korea`
///          ran as `{summary_text}:"cold" AND "korea" NOT {summary_text}:"korea"`, because a
///          typed phrase spans every column. It now throws `FTS5Error.emptyQuery` in every scope.
///   2.3 — #1297 round 1 (docs only): `exactTerms(from:)` says it returns the marked words every match must
///          contain, which is what parser 6.3 reports, and `matchExpressions(for:)` names the refusals among the
///          reasons it throws.
///   2.4 — #1297 round 2 (docs only): `exactTerms(from:)` describes the `=` rule by requirement and per operand, as parser
///          6.4 applies it, rather than by the places a mark sits.
///   2.5 — #1297 round 3 (docs only): `exactTerms(from:)` states parser 6.5's D4 — requirement is proved over marked
///          operands, so a word marked in every alternative is reported, and every positive mark on it applies.
///   2.6 — #1297 round 4 (docs only): `exactTerms(from:)` says parser 6.6 compares marks as the filter reads words, so a
///          word is reported once, in the spelling of its first applied mark, and `=Cold war OR =cold. peace` filters;
///          the paragraph is reflowed.
///   2.7 — #1298: the highlighter reads typographic double quotation marks as U+0022, through the parser's shared fold
///          rather than a copy of its set. `positiveTerms(from:)` folds the typed keywords before anything reads them,
///          and that fold is what makes the snippet, the concordance and the collocates anchor on the words a straight
///          spelling does: the one scan it runs, `strippingNearScaffolding(_:)`, receives text that is already folded.
///          `strippingNearScaffolding(_:)` and `lastUnquotedComma(in:)` also test
///          `FTS5InlineQueryParser.isDoubleQuotationMark(_:)` themselves, for consistency with the parser when a caller
///          hands them unfolded text directly — which no production caller does, and their own tests do. At 55464a46
///          `“cold war”` bolded nothing and concorded nothing (its terms were `“cold` and `war”`, whose stems keep the
///          marks), `«war and peace»` concorded neither word, and `blockade -„naval quarantine“` returned no document on a
///          three-document index where its straight spelling returns one; called directly, a `)` or `,` inside curly
///          marks ended a `NEAR` span or its distance. Each now reads as its straight spelling, and a double prime or a
///          single mark still does not.
///   2.8 — #1299 round 2: `filterKeySet(parameters:)` builds the Meaning mode's filters with `keywords` removed, as its
///          documentation always said it did. It passed the parameters whole to `makeFilters(from:)`, which reads the
///          typed text for the exact-word post-filter, so on iOS and iPadOS — whose Meaning run hands the backend the
///          live parameters, typed text included — a `=word` in a Meaning search dropped every semantic hit whose
///          document lacks the literal word, and the strip blamed the reader's filters. On the Mac the keywords of a
///          search restored or handed to the window did the same, even under a query typed since. RESULTS MOVE for
///          those Meaning searches: measured over a two-volume index, `=containment` alone went from the two documents
///          holding the literal word to `nil` (nothing constrains), and beside a volume filter from one document to both
///          of the volume's.
///   2.9 — #1373 review round 1: `collocation(...)` awaits the language tagger's verdict itself before it tokenizes,
///          rather than trusting both callers to have done so.
///   2.10 — #1522: `hasFinishedIndexing(_:)`, which the citation lookup asks before it reports a document absent
///          from a downloaded volume.
///   2.11 — FRUSCoreKit, part 2: moved into the kit. It reads the subject index through
///          `pipeline.resources`; its collocation measure, which tags with NaturalLanguage, moved
///          to the app's `SearchService+Collocation.swift`, so `pipeline` and
///          `positiveTerms(from:)` are internal for it
///   2.12 — FRUS Explorer Light: `concordance(for:parameters:radius:)` is public, and
///          `resultSetFacets(parameters:request:documentKeys:)` computes a search's facets by the
///          route the facet panel took, for the panel and the web edition alike
///   2.13 — #1680: `search` and `searchCount` throw `CancellationError` when the calling task is
///          cancelled before they return: the pipeline's statement stops at its progress handler's
///          next call, usually within a millisecond, and the snippet pass, now
///          `results(from:parameters:)`, at its next row
///   2.14 — #1577 lane 6: `matchKeys(parameters:)`, the key of every document a search matches,
///          which Search Within These Results ranks by a question when the list was cut at its ceiling
///   2.15 — A10b (plan of record decision 74): a keyword row's snippet starts at its match, after the
///          document's own heading, source note and dateline (`ProseSnippet`'s strip, which Meaning rows
///          share): 30 characters before the prose's first match, back to a space, and 2,000 after it,
///          where it kept 1,000 on each side of the body's first match. A row whose only match is in
///          those fields shows its opening prose. SNIPPETS MOVE for every keyword search
///   2.16 — A18 (index version 70): a result carries `dateISOMax` and `datePrecision` from its row, so a
///          row with no dateline — a section's, dated by the documents it holds — can draw its day or span
///   2.17 — #1760: a keyword row's window starts at the prose's first word of the rarest of the query's words
///          that the prose holds, rarest across the index, with the function words set aside while the query has
///          another word (`keywordAnchorTiers(_:)`, `functionWordStems`), where it started at the first word of any,
///          which for a question typed as keywords was *the*; and the highlighter reads each term as the tokenizer
///          does, so `happen?` is `happen`. `results(from:parameters:)` is `async`. SNIPPETS MOVE for a search of more
///          than one word, and only for those
///   2.18 — The keyword scan's ASCII fast path (plan of record §5, found in L2): the word loop reads one ASCII
///          character from a table built by asking `Character` what the scan asked of every character
///          (`WordCharacter`), the first gate reads it from a table of the stems' first letters, and the second
///          compares its byte; any other character is read as before. The scan had been most of the snippet pass,
///          and since #1760 it runs on to the rarest word. NO SNIPPET MOVES
///   2.19 — FRUS Explorer Light S17a: `userSource`, where every search, count, key set, facet match and tag
///          count of this service reads its user half (`SearchUserSource`), which `makeFilters(from:)` puts in
///          the filters it builds, and `semanticResultRows(forKeys:)` passes on; `.index`, the app's, unless the
///          host passes another. `userTagCounts(parameters:tagIds:documentKeys:)`, the filter sheet's two
///          routes to the tag counts, public. NO RESULT MOVES on the index
public actor SearchService {

    // MARK: - Dependencies

    private let fts5Store: FTS5Store
    /// Internal rather than private so the app's collocation extension
    /// (`SearchService+Collocation.swift`) can read the documents' body text through it.
    let pipeline: IndexingPipeline

    /// Retained for initialiser compatibility. Person-ref filtering is applied in
    /// SQL by `IndexingPipeline.searchDocuments` (an `EXISTS` against
    /// `person_mentions`); this store is no longer consulted during search.
    private let personMentionStore: PersonMentionStore?

    /// Where this service's searches read their user half: the notes and summaries the words match, the
    /// tags a filter, a row and a tag count read, and the user's texts the exact-word filter reads (S17a).
    /// `.index` in the app. A host that keeps each user's half in a store attached to `pipeline` makes a
    /// service for a user with `.attachedStore(userId:)`; the pipeline is shared, the service is cheap.
    public nonisolated let userSource: SearchUserSource

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
    ///   - userSource: Where the user half is read (`SearchUserSource`): the index's own, as the app
    ///     reads it, by default.
    public init(
        fts5Store: FTS5Store,
        pipeline: IndexingPipeline,
        personMentionStore: PersonMentionStore? = nil,
        userSource: SearchUserSource = .index
    ) {
        self.fts5Store = fts5Store
        self.pipeline = pipeline
        self.personMentionStore = personMentionStore
        self.userSource = userSource
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
    /// - Throws: `FTS5Error.emptyQuery` if no searchable content can be constructed, and
    ///   `CancellationError` when the calling task is cancelled before this returns (#1680): the
    ///   pipeline's statement stops at its progress handler's next call, usually within a
    ///   millisecond, and the snippet pass at its next row.
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
        return try await results(from: rows, parameters: parameters)
    }

    /// Test hook: called by `results(from:parameters:)` before each row's snippet, after the row's
    /// cancellation check, with the row's index (#1680). `nil` in the app. It lets a test cancel the
    /// pass at a row and count how many rows the pass went on to, which its error alone cannot say.
    private var snippetRowTestHook: (@Sendable (Int) -> Void)?

    /// Test hook: installs `snippetRowTestHook`.
    func setSnippetRowTestHook(_ hook: (@Sendable (Int) -> Void)?) {
        snippetRowTestHook = hook
    }

    /// The pipeline's rows as results, each with its snippet, in their order.
    ///
    /// Stops at the next row when the calling task is cancelled, and after the last one, and throws
    /// `CancellationError` (#1680). The snippet pass is most of a search's time at the Mac's 7,500 rows (0.76 s of a
    /// common word's 1.15 s, measured over a full index) and runs on this actor, so a search a later
    /// one replaced would otherwise hold up every call into the service, the replacing search's
    /// included, until its last snippet.
    func results(from rows: [IndexedSearchRow], parameters: SearchParameters) async throws -> [SearchResult] {
        // Stem each positive term once, and rank the stems once, rarest first; reused across all
        // rows for highlighting (#1760).
        let queryTerms = positiveTerms(from: parameters)
        let stemmedQueryTerms = queryTerms.map { PorterStemmer.stem($0.lowercased()) }
        var anchorTiers: [[String]] = []
        if !rows.isEmpty { anchorTiers = await keywordAnchorTiers(stemmedQueryTerms) }

        var results: [SearchResult] = []
        results.reserveCapacity(rows.count)
        for (index, row) in rows.enumerated() {
            try Task.checkCancellation()
            snippetRowTestHook?(index)
            // The window keeps 2,000 characters after the match, so the UI's adjustable `.lineLimit`
            // (1–10 lines, #189-C) always has text to fill the chosen line count; the rendered length
            // is clamped per surface at display time, not here.
            let snippet = Self.keywordSnippet(
                body: row.bodyText,
                header: row.header,
                dateline: row.dateline,
                sourceNote: row.sourceNote,
                stemTiers: anchorTiers
            ) ?? headerFallbackSnippet(header: row.header, dateline: row.dateline)

            results.append(SearchResult(
                documentId: row.documentId,
                volumeId: row.volumeId,
                documentNumber: row.documentNumber,
                header: row.header,
                dateline: row.dateline,
                dateISO: row.dateISO,
                dateISOMax: row.dateISOMax,
                datePrecision: row.datePrecision.flatMap(DatePrecision.init(rawValue:)),
                sourceNote: row.sourceNote,
                snippet: snippet,
                bm25Score: row.score,
                subjectTagIds: Self.splitTagIds(row.subjectTagIds),
                userTagIds: Self.splitTagIds(row.userTagIds),
                isEditorialNote: row.isEditorialNote,
                isFrontMatter: row.isFrontMatter
            ))
        }
        // And after the last row, so that a task cancelled at any point gets no answer.
        try Task.checkCancellation()
        return results
    }

    /// Returns the exact total number of results matching `parameters`.
    ///
    /// Runs the same match expressions and SQL filters as `search`, so the count
    /// always agrees with the paginated result set. Throws `CancellationError` when the calling
    /// task is cancelled before this returns, as `search` does (#1680).
    public func searchCount(parameters: SearchParameters) async throws -> Int {
        let (corpusMatch, userMatch) = try makeMatchExpressions(from: parameters)
        return try await pipeline.searchDocumentsCount(
            corpusMatch: corpusMatch,
            userContentMatch: userMatch,
            filters: makeFilters(from: parameters)
        )
    }

    /// Display rows for the Meaning mode's hits (V-5 hybrid page) — the pipeline's keyed batch,
    /// through this actor so the two search routes share one entry surface. A row's tags are read
    /// from `userSource`.
    ///
    /// - Parameter keys: The semantic hits to resolve.
    /// - Returns: `"volumeId/documentId"` → row; unindexed keys are absent.
    public func semanticResultRows(
        forKeys keys: [(volumeId: String, documentId: String)]
    ) async throws -> [String: IndexedSearchRow] {
        try await pipeline.semanticResultRows(forKeys: keys, userSource: userSource)
    }

    /// The full key set the current FILTERS admit, for the Meaning mode's intersection.
    ///
    /// `nil` means the parameters carry no SQL-expressible filter and nothing constrains.
    /// Uncapped — see the pipeline method's reasoning.
    ///
    /// **The typed text is removed before the filters are built** (#1299 round 2). `makeFilters(from:)` also renders the
    /// exact-word post-filter, which it reads from the parse of `keywords` — right for a keyword search, whose MATCH
    /// that filter refines, and wrong here, where the typed text is the semantic query and there is no MATCH to refine.
    /// Built from the parameters as they came, a Meaning search for `=containment policy` removed every hit whose
    /// document lacks the literal word and reported them as "Your filters removed N matches" to a reader who had set no
    /// filter. Exact-word mode (#567) predates Meaning mode (#1127), so nothing had ever asked this for filters alone. The
    /// structured phrase, prefix and excluded terms stay, because the parse never takes an exact term from them.
    ///
    /// - Parameter parameters: The current search parameters; only their filters are read.
    /// - Returns: Matching keys, or `nil` when unfiltered.
    public func filterKeySet(parameters: SearchParameters) async throws -> Set<String>? {
        var filtersOnly = parameters
        filtersOnly.keywords = nil
        return try await pipeline.documentKeysMatchingFilters(makeFilters(from: filtersOnly))
    }

    /// Every document `parameters` match, keyed `"volumeId/documentId"`: the whole match, where
    /// ``search(parameters:limit:offset:)`` returns a window of it (#1577 lane 6).
    ///
    /// The same match expressions and the same filters as `search` and ``searchCount(parameters:)``,
    /// so there are as many keys as the count says, and they are the documents a search with no limit
    /// would list. A search ranks the match and fills each row's snippet; this does neither, and so
    /// stays cheap for a match of any size: what Search Within These Results ranks by a question when
    /// the list on screen was cut at its ceiling. A key appears once. The order is none in particular,
    /// so a caller that needs the search's order runs the search.
    ///
    /// - Parameter parameters: The search: its words, its scopes and its filters, a document gate among
    ///   them.
    /// - Returns: The keys; none for a search with no words and no filter.
    /// - Throws: `FTS5Error.emptyQuery` where `search` throws it, and `CancellationError` when the
    ///   calling task is cancelled before this returns, as `search` does (#1680).
    public func matchKeys(parameters: SearchParameters) async throws -> [String] {
        let (corpusMatch, userMatch) = try makeMatchExpressions(from: parameters)
        return try await pipeline.documentKeysMatching(
            corpusMatch: corpusMatch,
            userContentMatch: userMatch,
            filters: makeFilters(from: parameters)
        )
    }

    /// Splits a stored space-separated tag-id column for a semantic display row — the same rule
    /// `search` applies to its own rows.
    public static func tagIds(from raw: String?) -> [String] {
        splitTagIds(raw)
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

    /// Returns the indexed document with a given TEI id in a volume — the lookup a
    /// history.state.gov link resolves through, since its path names the document by id (#1474).
    /// The id is matched as written, then ignoring case.
    ///
    /// - Parameters:
    ///   - documentId: The document's `xml:id`, e.g. `"d84"` or `"d373a"`.
    ///   - volumeId: The volume to query.
    /// - Returns: The matching entry, or `nil` when the volume is not indexed or has no such id.
    public func document(
        withId documentId: String,
        inVolume volumeId: String
    ) async throws -> DocumentBrowserEntry? {
        try await pipeline.document(forDocumentId: documentId, inVolume: volumeId)
    }

    /// Whether the index can say what `volumeId` holds: it holds rows for the volume, and the
    /// volume's indexing is not running or cut short (`IndexingPipeline.isIndexingUnfinished(_:)`)
    /// — the question the citation lookup asks before it reports a document absent (#1522).
    ///
    /// `false` for a volume downloaded and never indexed, which is every volume after Settings'
    /// Rebuild Index empties the index and before its pass reaches them, and every one waiting in
    /// the queue after a download; and for a volume whose pass is running or stopped part-way,
    /// whose rows may be some of its documents and not others.
    ///
    /// - Parameter volumeId: The volume to ask about.
    /// - Returns: `true` when a lookup that finds nothing in the volume may say so.
    public func hasFinishedIndexing(_ volumeId: String) async throws -> Bool {
        guard try pipeline.isVolumeIndexed(volumeId) else { return false }
        let unfinished = await pipeline.isIndexingUnfinished(volumeId)
        return !unfinished
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

    /// The W-17 lexical-similarity candidate query — a thin public face on
    /// `FTS5Store.lexicalCandidates` so the axis queries exactly the store the search
    /// executes against, not a second connection that could drift.
    public func lexicalCandidates(
        terms: [String], dfCeiling: Int, limit: Int
    ) async throws -> (candidates: [FTS5Store.LexicalCandidate], admittedTerms: [String]) {
        try await fts5Store.lexicalCandidates(terms: terms, dfCeiling: dfCeiling, limit: limit)
    }

    /// The rendered MATCH expression(s) for `parameters`, for the Query Inspector.
    ///
    /// A thin public face on `makeMatchExpressions` so the inspector displays exactly the
    /// strings the search executed — not a second rendering that could drift from it.
    /// Rethrows `FTS5Error.emptyQuery` whenever neither expression renders and the query does not run
    /// filter-only: the parser refused the text (nothing positive once its negations apply, an
    /// approximation proved to match nothing, or groups nested past
    /// `FTS5InlineQueryParser.maximumGroupDepth`), every content scope is off, or there is neither text
    /// nor a standalone filter. "No searchable content at all", as this said before #1297 round 1, missed
    /// the refusals, which have content.
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

        // The unscoped parse is the one the exact-word post-filter and the Query Inspector read, so a query it
        // refuses runs in no scope. A single-column parse can still render one: a typed phrase spans every column,
        // so a scoped exclusion of the same word cannot be shown to remove it, and the search would run without the
        // exact terms it marked (#1297).
        let unscopedRenders = Self.parsedQuery(for: parameters).expression != nil
        var userContent: String? = nil
        if unscopedRenders, parameters.includeSummaries || parameters.includeNotes {
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

    /// The combined parse of `parameters`: the typed `keywords` and the structured phrase, prefix
    /// wildcard and excluded terms, as one query (#1297).
    ///
    /// The one place the app turns a query's text into a parse. The MATCH expression
    /// (`renderExpression(from:columns:)`), the exact-word post-filter (`exactTerms(from:)`) and the
    /// Query Inspector's operand rows all read it, so none of them can describe a different query
    /// from the one that runs. `columnPrefix` scopes the typed operands and the prefix wildcard; the
    /// phrase and the excluded terms span every column, as they always have.
    ///
    /// Nonisolated and pure: it parses and touches no store.
    static func parsedQuery(for parameters: SearchParameters, columnPrefix: String = "") -> ParsedQuery {
        FTS5InlineQueryParser.parseDetailed(parameters.keywords ?? "", columnPrefix: columnPrefix,
                                            structured: parameters.structuredQueryParts)
    }

    /// Renders one FTS5 MATCH expression for the given column scope.
    ///
    /// The raw search-box text — Google-style inline syntax: quotes, `OR`, leading `-`, `NOT`,
    /// trailing `*` — and the structured phrase, prefix wildcard and excluded terms are parsed
    /// together by `parsedQuery(for:columnPrefix:)`, with the column prefix applied to each typed
    /// operand and to the prefix. This no longer goes through `FTS5Query`: that builder receives the
    /// typed text already rendered, so it could not see a typed exclusion the typed text left out on
    /// its own, and a restored search for the phrase "cold war" with `-korea` typed beside it ran as
    /// `"cold war"` alone.
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
        return Self.parsedQuery(for: parameters, columnPrefix: columnPrefix).expression
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
            resolvedBucket = pipeline.resources.documentSubjects()?.bucketVocabulary.id(forKey: key) ?? -1
        } else {
            resolvedBucket = parameters.subjectBucket
        }
        // #1022, subject grain. REF FIRST, THEN NAME. The ref is exact and stable for the 472
        // 470 opaque upstream record ids; the name catches the 21 name-derived refs, which ARE the
        // display name reduced to alphanumerics and are re-minted when it changes — including two
        // that wear a `rec_` prefix and so look stable. Same `-1`
        // sentinel and for the same reason: a subject that has left the vocabulary must match
        // NOTHING, because falling back to `nil` reads as "no subject filter" and would widen a
        // saved search to the whole corpus under a name promising one subject.
        let resolvedSubject: Int?
        if let ref = parameters.subjectRef {
            let index = pipeline.resources.documentSubjects()
            resolvedSubject = index?.subjectPosition(forRef: ref)
                ?? parameters.subjectName.flatMap { index?.subjectPosition(forName: $0) }
                ?? -1
        } else {
            resolvedSubject = nil
        }
        return SearchSQLFilters(
            volumeIds: parameters.volumeIds,
            documentIds: parameters.documentIds,
            subjectBucket: resolvedBucket,
            subjectRef: resolvedSubject,
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
            exactColumns: Self.exactColumns(for: parameters),
            userSource: userSource
        )
    }

    /// The words the exact-word post-filter requires: those marked `=` that every match must contain.
    ///
    /// Read from the same combined parse that builds the MATCH expression,
    /// `parsedQuery(for:columnPrefix:)`, so the two can never disagree about which terms were
    /// marked. This reads the unscoped parse, and `makeMatchExpressions` runs no scope that parse
    /// refuses, so no search runs whose marked terms this cannot read. Only typed words carry the
    /// mark; the structured fields never add one.
    ///
    /// Not every marked word. The SQL layer ANDs one filter per term over every result, so the parser
    /// reports a word only where every match must contain it through a marked operand — a required mark,
    /// or a mark in every `OR` alternative (`=cold war OR =cold fevers`) — and then every positive mark on
    /// it applies (`ParsedOperand.isExactApplied`, parser 6.5, D4). It ignores a mark wherever a match need
    /// not contain the word through one: when only one `OR` alternative marks it (`=cold OR war` keeps war
    /// documents without cold), on a word an excluded group leaves optional (`cold -(war -=korea)`), and
    /// beside the same word unmarked (`(=cold OR fevers) cold` keeps a document holding only colds and
    /// fevers, since the unmarked cold admits the stem). The rule is requirement, not position: excluding a
    /// group can make a mark apply, as in `NOT (war OR -=cold)`, which searches the literal cold without
    /// war. A mark on a prefix, or on a word the index splits into several terms (`=U.S.S.R.`), is always
    /// ignored. The structured parts can therefore take a term away — `=cold OR -korea` reports `cold` alone
    /// and nothing beside the restored prefix `viet`, which anchors the complement — and never add one.
    ///
    /// One term per word, and a word is what the filter reads (parser 6.6): capitalisation, the accents the
    /// filter folds (`café` and `cafe`, never letters such as `ø` or `ł`) and punctuation at either end of a mark do
    /// not make another word, so `=Cold war OR =cold. peace` marks
    /// cold in every alternative and reports `["Cold"]`, the spelling of the word's first applied mark, and
    /// `=Soviet =soviet` reports `["Soviet"]`. The filter folds the spelling itself, so each word is one
    /// filter whichever spelling is reported.
    static func exactTerms(from parameters: SearchParameters) -> [String] {
        parsedQuery(for: parameters).exactTerms
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
    ///
    /// A quotation mark is any mark the parser reads as one (`FTS5InlineQueryParser.isDoubleQuotationMark(_:)`),
    /// so a paren inside `“…”` is text exactly as it is inside `"…"` (#1298). The text is returned unfolded. Its one
    /// production caller, `positiveTerms(from:)`, folds the text before handing it over, so the predicate keeps a
    /// direct caller consistent with the parser rather than changing what the highlighter anchors on.
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
                if FTS5InlineQueryParser.isDoubleQuotationMark(character) {
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
    ///
    /// A phrase may be quoted with any mark the parser reads as a quote — `"`, `“ ”`, `„ “`, `« »`, `＂` — and a
    /// double prime (`12″`) or a single mark opens nothing (`FTS5InlineQueryParser.isDoubleQuotationMark(_:)`, #1298).
    static func lastUnquotedComma(in text: String) -> String.Index? {
        var inQuotes = false
        var found: String.Index? = nil
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            if FTS5InlineQueryParser.isDoubleQuotationMark(character) {
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
    public func concordance(
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

    // MARK: - Facets (R-1)

    /// A search's results broken down by `request`'s sections, as the facet panel shows them.
    ///
    /// A keyword search's facets describe its whole match (decision R-1-2), through the MATCH
    /// expressions and filters the search itself runs, so the panel and the list count one set. A
    /// meaning search has no MATCH, so its facets describe `documentKeys`, the results it ranked,
    /// and no expression is built: asking for one from the typed text is how the keyword reading of
    /// a meaning search leaked into these counts (#1193). Both routes run the same aggregation,
    /// `IndexingPipeline.resultSetFacets`.
    ///
    /// - Parameters:
    ///   - parameters: the search that ran.
    ///   - request: the sections to compute, and their row ceiling.
    ///   - documentKeys: the results to describe when no keyword match produced them, such as a
    ///     meaning search's; `nil` for a keyword search.
    /// - Throws: `FTS5Error.emptyQuery` when a keyword search has neither text to match nor a
    ///   filter to run alone, as ``matchExpressions(for:)`` does.
    public func resultSetFacets(
        parameters: SearchParameters,
        request: FacetRequest,
        documentKeys: [(volumeId: String, documentId: String)]? = nil
    ) async throws -> ResultSetFacets {
        let expressions = documentKeys == nil
            ? try makeMatchExpressions(from: parameters)
            : (corpus: nil, userContent: nil)
        let filters = documentKeys == nil ? makeFilters(from: parameters) : SearchSQLFilters()
        return try await pipeline.resultSetFacets(
            corpusMatch: expressions.corpus, userContentMatch: expressions.userContent,
            filters: filters, request: request, documentKeys: documentKeys)
    }

    /// How many documents of a search's results carry each of `tagIds`, as the filter sheet's My Tags
    /// toggles count them (`IndexingPipeline.userTagCounts`), with the tags read from `userSource` (S17a).
    ///
    /// The filter sheet's two routes, as `SearchViewModel.loadUserTagCounts` takes them: a keyword search
    /// counts over its whole match, through the expressions and filters the search runs; a meaning
    /// search over `documentKeys`, the results it ranked, already filtered, with no expression built.
    ///
    /// - Parameters:
    ///   - parameters: The search that ran.
    ///   - tagIds: The tags to count, each a `UserTag.id.uuidString`; a tag no document of the results
    ///     carries is absent from the answer.
    ///   - documentKeys: The results to count over when no keyword match produced them; `nil` for a
    ///     keyword search.
    /// - Returns: Counts keyed by the tag ids as given.
    /// - Throws: `FTS5Error.emptyQuery` when a keyword search has neither text to match nor a filter to
    ///   run alone, as ``matchExpressions(for:)`` does.
    public func userTagCounts(
        parameters: SearchParameters,
        tagIds: [String],
        documentKeys: [(volumeId: String, documentId: String)]? = nil
    ) async throws -> [String: Int] {
        guard let documentKeys else {
            let expressions = try makeMatchExpressions(from: parameters)
            return try await pipeline.userTagCounts(
                corpusMatch: expressions.corpus, userContentMatch: expressions.userContent,
                filters: makeFilters(from: parameters), tagIds: tagIds)
        }
        return try await pipeline.userTagCounts(
            corpusMatch: nil, userContentMatch: nil, filters: SearchSQLFilters(userSource: userSource),
            tagIds: tagIds, documentKeys: documentKeys)
    }

    /// The query's positive terms, for highlighting and the concordance. Internal rather than
    /// private so the app's collocation extension can anchor on the same terms.
    func positiveTerms(from parameters: SearchParameters) -> [String] {
        var terms: [String] = []
        // Folded first, as the parser folds the text it renders (#1298): without it `“cold war”` leaves `“cold` and
        // `war”`, whose stems keep the marks and anchor on nothing.
        if let kw = parameters.keywords.map(FTS5InlineQueryParser.normalizingQuotationMarks) {
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
                // As the tokenizer reads it (#1760): a question typed as keywords ends `happen?`,
                // which the search reads as `happen`, and whose stem kept the mark and anchored on
                // nothing. An `=` word keeps its mark, which anchors on nothing as before: its match
                // is the literal word, which a stem cannot say.
                if !token.hasPrefix("=") { token = FTS5InlineQueryParser.trimmingTokenizerSeparators(token) }
                guard !token.isEmpty else { continue }
                terms.append(token)
            }
        }
        if let phrase = parameters.phrase, !phrase.isEmpty {
            terms.append(contentsOf: phrase
                .split(whereSeparator: \.isWhitespace)
                .map { FTS5InlineQueryParser.trimmingTokenizerSeparators(String($0)) }
                .filter { !$0.isEmpty })
        }
        if let prefix = parameters.prefixWildcard, !prefix.isEmpty {
            terms.append(FTS5InlineQueryParser.trimmingTokenizerSeparators(prefix))
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
    /// empty snippet row. A match in the body's own heading, source note or dateline is a
    /// body match, and gets the opening prose instead (``keywordSnippet(body:header:dateline:sourceNote:stemmedTerms:)``).
    private func headerFallbackSnippet(header: String, dateline: String?) -> String {
        [header, dateline]
            .compactMap { s in (s?.isEmpty == false) ? s : nil }
            .joined(separator: " · ")
    }

    // MARK: - The keyword window (A10b)

    /// How many characters a keyword row's window keeps before the match: about five words
    /// (plan of record decision 74), taken back to the start of the word they reach.
    nonisolated static let keywordLead = 30

    /// How many characters a keyword row's window keeps after the match: enough that the UI's
    /// adjustable `.lineLimit` fills ten lines on the widest row (#189-C), about 1,800 characters on
    /// an iPad Pro in landscape; the visible length is clamped at render time.
    nonisolated static let keywordTrail = 2_000

    /// Words that say nothing about a document on their own: articles, auxiliaries, pronouns,
    /// prepositions and conjunctions, and the question words a question typed as keywords opens with
    /// (#1760). As Porter stems, as a query's words are compared.
    ///
    /// A keyword row's window does not start at one of them while the query has another word
    /// (``keywordAnchorTiers(_:)``). *May* is not among them, since it is a month in this corpus as
    /// often as a verb.
    nonisolated static let functionWordStems: Set<String> = Set("""
        a about above after again against all also am an and any are as at be because been before being below \
        between both but by can could did do does doing done down during each either few for from further had has \
        have having he her here hers herself him himself his how i if in into is it its itself me more most my \
        myself neither no nor not of off on once only or other our ours out over own same she should so some such \
        than that the their theirs them themselves then there these they this those through to too under until up \
        upon us very was we were what when where whether which while who whom whose why will with within without \
        would yet you your yours
        """.split(whereSeparator: \.isWhitespace).map { PorterStemmer.stem(String($0)) })

    /// The query's stems in the order a keyword row's window prefers them (#1760): the rarest across
    /// the index first, by how many of its documents hold each (`IndexingPipeline.documentFrequencies
    /// (ofIndexTerms:)`), stems held by as many documents together, in the order typed; and none of
    /// ``functionWordStems`` while the query has another word.
    ///
    /// A question typed as keywords, *Why did the Marshall Plan happen?*, matches documents holding
    /// every one of its words, and A10b's window started at the first of them in the prose, which was
    /// *the* in nearly every row, so *the* was the word each row drew in bold. Ranked, the window
    /// starts at *Marshall*: on build 1861's full index, 13,067 documents hold it, and 318,650 hold *the*.
    /// Rarity alone ranks *why* (21,021) above *plan* (67,090), so a row whose prose lacks *Marshall*
    /// and *happen* would start at *why*; the function words are therefore set aside, and a row whose
    /// prose holds none of the other words starts as a row whose words are only in its own fields does.
    ///
    /// A stem the vocabulary does not hold is held as rare as any: a word no document holds cannot
    /// anchor a window, and the few Swift stems SQLite's stemmer spells otherwise are words, not marks.
    /// Where the vocabulary cannot be read, every stem is one tier, A10b's rule.
    ///
    /// - Parameter stems: The query's positive terms, reduced to their Porter stems.
    /// - Returns: The tiers, most telling first; one tier for a query of one stem.
    func keywordAnchorTiers(_ stems: [String]) async -> [[String]] {
        var unique: [String] = []
        for stem in stems where !stem.isEmpty && !unique.contains(stem) { unique.append(stem) }
        let telling = unique.filter { !Self.functionWordStems.contains($0) }
        let anchoring = telling.isEmpty ? unique : telling
        guard anchoring.count > 1 else { return anchoring.isEmpty ? [] : [anchoring] }
        guard let frequencies = try? await pipeline.documentFrequencies(ofIndexTerms: anchoring)
        else { return [anchoring] }
        var tiers: [[String]] = []
        var tierFrequency: Int?
        // `sorted` is not stable, so the order typed is compared too.
        let ranked = anchoring.enumerated().sorted { a, b in
            let (fa, fb) = (frequencies[a.element] ?? 0, frequencies[b.element] ?? 0)
            return fa != fb ? fa < fb : a.offset < b.offset
        }
        for (_, stem) in ranked {
            let frequency = frequencies[stem] ?? 0
            if frequency == tierFrequency, !tiers.isEmpty {
                tiers[tiers.count - 1].append(stem)
            } else {
                tiers.append([stem])
                tierFrequency = frequency
            }
        }
        return tiers
    }

    /// A keyword row's snippet (A10b, plan of record decision 74): the window around the first word
    /// of the document's own prose that the query matches, after its own heading, source note and
    /// dateline. A search row draws the heading and the dateline, and the source note's classification
    /// as a chip; the Add Documents sheet prints the source note whole.
    ///
    /// - **The prose** starts where `ProseSnippet.proseStart(in:header:dateline:sourceNote:)` puts
    ///   it, the strip a Meaning row's snippet is cut by. A body that is only its boilerplate is read
    ///   whole, as the Meaning snippet's fallback reads it.
    /// - **The word** is the prose's first word of the most telling tier it holds (#1760): the rarest
    ///   of the query's words across the index, leaving aside *the*, *of*, *why* and their kind while
    ///   the query has another word (``keywordAnchorTiers(_:)``), where A10b took the first word of any,
    ///   so that a question typed as keywords no longer marks *the*.
    /// - **The window** is ``makeContextSnippet(body:stemTiers:from:before:after:)``'s:
    ///   ``keywordLead`` characters before that word, back to a space, and ``keywordTrail`` after it.
    /// - **A row whose only match is in those fields** gets the opening prose, ``keywordTrail``
    ///   characters of it with no word marked, as a Meaning row does. A word in the heading or the
    ///   dateline is drawn there; one only in the source note, or in the line the strip takes with the
    ///   dateline, is drawn nowhere on a search row. Over the twelve topical searches of
    ///   `Planning/Keyword-Snippet-Assessment-2026-10-20.md`, 1.1% of the top 1,000 rows and none of
    ///   the top 100; over archival ones, many more ("Whitman File": 52 of its top 100, 50 of them by
    ///   the source note; plan of record §6g).
    /// - **A row with no match in its body**, an empty body, or a query with no positive term gets
    ///   `nil`: the caller shows the heading and dateline again (`headerFallbackSnippet`).
    ///
    /// - Parameters:
    ///   - body: The unstemmed, plain-text document body.
    ///   - header: The document's header, as the row shows it.
    ///   - dateline: The row's dateline, when present.
    ///   - sourceNote: The document's stored source note, when present.
    ///   - stemTiers: Query terms already reduced to their Porter stems, in tiers, the most telling first.
    /// - Returns: The snippet, with the match between `<b>` and `</b>` when it is in the prose.
    nonisolated static func keywordSnippet(
        body: String,
        header: String,
        dateline: String?,
        sourceNote: String?,
        stemTiers: [[String]]
    ) -> String? {
        guard !body.isEmpty, stemTiers.contains(where: { !$0.isEmpty }) else { return nil }
        let characters = Array(body)
        let terms = KeywordStems(tiers: stemTiers)
        let proseStart = ProseSnippet.proseStart(
            in: characters, header: header, dateline: dateline, sourceNote: sourceNote) ?? 0
        if let match = terms.firstMatch(in: characters, from: proseStart, to: characters.count) {
            return window(in: characters, around: match, from: proseStart, before: keywordLead, after: keywordTrail)
        }
        // A match only before the prose, in the fields the row draws: the prose's opening, unmarked.
        guard proseStart > 0, terms.firstMatch(in: characters, from: 0, to: proseStart) != nil else { return nil }
        var end = min(characters.count, proseStart + keywordTrail)
        while end < characters.count, characters[end].isLetter { end += 1 }
        return String(characters[proseStart..<end]) + (end < characters.count ? " …" : "")
    }

    /// ``keywordSnippet(body:header:dateline:sourceNote:stemTiers:)`` with every stem in one tier: the
    /// window at the prose's first word that any of them matches, A10b's rule.
    nonisolated static func keywordSnippet(
        body: String,
        header: String,
        dateline: String?,
        sourceNote: String?,
        stemmedTerms: [String]
    ) -> String? {
        keywordSnippet(body: body, header: header, dateline: dateline, sourceNote: sourceNote,
                       stemTiers: [stemmedTerms])
    }

    /// Builds a `<b>…</b>`-marked context snippet from a document body string.
    ///
    /// The body is scanned word-by-word from `start`; the first word whose Porter stem matches
    /// an entry of the best tier of `stemTiers` the body holds is wrapped in `<b>…</b>`, with about
    /// `before` characters ahead of it and `after` behind it (#1760: with one tier, the first word of
    /// any stem). Ahead, the window goes back to a space, so that it opens on a whole word ("Bonn’s",
    /// not its "s"), and never before `start`; behind, it goes on to the end of the word it reaches.
    /// "… " opens a window that starts after `start`, and " …" ends one that stops before the body does.
    ///
    /// Returns `nil` if no word in `body` from `start` on matches any stemmed term.
    ///
    /// - Parameters:
    ///   - body: The unstemmed, plain-text document body to search.
    ///   - stemTiers: Query terms already reduced to their Porter stems, in tiers, the most telling first.
    ///   - start: Where the scan and the window may begin, in characters: a keyword row passes where
    ///     its prose starts (``keywordSnippet(body:header:dateline:sourceNote:stemTiers:)``).
    ///   - before: About how many characters to keep ahead of the match.
    ///   - after: About how many characters to keep behind it. A keyword row keeps ``keywordTrail``,
    ///     so the result string can fill up to the 10-line maximum the UI's adjustable `.lineLimit`
    ///     may request (#189-C); the visible length is clamped at render time.
    nonisolated static func makeContextSnippet(
        body: String,
        stemTiers: [[String]],
        from start: Int = 0,
        before: Int = keywordLead,
        after: Int = keywordTrail
    ) -> String? {
        guard !body.isEmpty, stemTiers.contains(where: { !$0.isEmpty }) else { return nil }
        let characters = Array(body)
        guard let match = KeywordStems(tiers: stemTiers).firstMatch(in: characters, from: start, to: characters.count)
        else { return nil }
        return window(in: characters, around: match, from: start, before: before, after: after)
    }

    /// ``makeContextSnippet(body:stemTiers:from:before:after:)`` with every stem in one tier: the window
    /// at the first word that any of `stemmedTerms` matches.
    nonisolated static func makeContextSnippet(
        body: String,
        stemmedTerms: [String],
        from start: Int = 0,
        before: Int = keywordLead,
        after: Int = keywordTrail
    ) -> String? {
        makeContextSnippet(body: body, stemTiers: [stemmedTerms], from: start, before: before, after: after)
    }

    /// The window ``makeContextSnippet(body:stemTiers:from:before:after:)`` describes, around a
    /// match already found.
    nonisolated private static func window(
        in characters: [Character],
        around match: Range<Int>,
        from start: Int,
        before: Int,
        after: Int
    ) -> String {
        let n = characters.count
        // Back to a space, not only across letters: a 30-character lead otherwise opens "… s 3463"
        // on "Bonn’s 3463", whose apostrophe is not a letter.
        var low = max(start, match.lowerBound - before)
        while low > start, !characters[low - 1].isWhitespace { low -= 1 }
        var high = min(n, match.upperBound + after)
        while high < n, characters[high].isLetter { high += 1 }
        var out = low > start ? "… " : ""
        out += String(characters[low..<match.lowerBound])
        out += "<b>" + String(characters[match]) + "</b>"
        out += String(characters[match.upperBound..<high])
        if high < n { out += " …" }
        return out
    }

    /// A query's stems, and the scan that finds the first body word stemming to one of them.
    private struct KeywordStems {

        /// Each stem's tier, 0 the most telling (#1760): the scan takes the first word of the best tier a
        /// range holds. With one tier, as `init(_:)` makes, that is the range's first word of any stem.
        let tiers: [String: Int]

        /// The scan's gates over every stem.
        let gates: Gates

        /// Reads `stemmedTerms`, query terms already reduced to their Porter stems, as one tier.
        init(_ stemmedTerms: [String]) {
            self.init(tiers: [stemmedTerms])
        }

        /// Reads `ordered`, the query's stems in tiers, the most telling first. A stem listed in two
        /// tiers is in the first.
        init(tiers ordered: [[String]]) {
            var tiers: [String: Int] = [:]
            for (tier, stems) in ordered.enumerated() {
                for stem in stems where tiers[stem] == nil { tiers[stem] = tier }
            }
            self.tiers = tiers
            gates = Gates(tiers.keys)
        }

        /// The first word in `characters[start..<end]` whose Porter stem is in the best tier the range
        /// holds: its range, or `nil` when no word's stem is the query's.
        ///
        /// One pass. At the first word of the first tier it stops; at a word of a later tier it goes on,
        /// for the rarer tiers alone, whose gates turn away the rest of the words, the common ones first.
        /// A word is a letter and the letters, apostrophes and hyphens after it (``WordCharacter``).
        func firstMatch(in characters: [Character], from start: Int, to end: Int) -> Range<Int>? {
            var best: (tier: Int, range: Range<Int>)?
            var gates = self.gates
            var i = start
            while i < end {
                // Skip non-letters.
                while i < end, WordCharacter(characters[i]) != .letter { i += 1 }
                guard i < end else { break }
                let wordStart = i
                var sawPunctuation = false
                while i < end {
                    let kind = WordCharacter(characters[i])
                    if kind == .other { break }
                    if kind == .joiner { sawPunctuation = true }
                    i += 1
                }
                let wordEnd = i
                guard gates.admit(characters, from: wordStart, to: wordEnd, sawPunctuation: sawPunctuation)
                else { continue }

                let word = String(characters[wordStart..<wordEnd])
                // Only strip when the scan actually consumed an apostrophe or hyphen, which is
                // rare — `filter` allocates a second String every time it is called.
                let alpha = sawPunctuation ? word.filter { $0.isLetter } : word
                let stem = alpha.isEmpty ? word.lowercased() : PorterStemmer.stem(alpha.lowercased())
                guard let tier = tiers[stem], tier < (best?.tier ?? .max) else { continue }
                if tier == 0 { return wordStart..<wordEnd }
                best = (tier, wordStart..<wordEnd)
                gates = Gates(tiers.filter { $0.value < tier }.keys)
            }
            return best?.range
        }
    }

    /// The scan's two gates over a set of stems, which turn a word away before it is stemmed when it
    /// cannot stem to any of them.
    private struct Gates {

        /// The stems' first characters, for the scan's first gate.
        let firstLetters: Set<Character>

        /// The first gate for a word that opens with one ASCII character, indexed by that character
        /// lowercased: whether it is one of ``firstLetters``.
        let asciiFirstLetters: [Bool]

        /// Each stem's opening, for the scan's second gate: the stem less its last two characters, and
        /// never less than its first, as each character's `asciiValue`.
        let openings: [[UInt8?]]

        /// The gates over `stems`, query terms already reduced to their Porter stems.
        init<Stems: Sequence>(_ stems: Stems) where Stems.Element == String {
            let stems = Set(stems)
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
            firstLetters = Set(stems.compactMap(\.first))
            // The same gate for a word that opens with one ASCII character, read from a table without
            // lowercasing or hashing a `Character`. One ASCII character equals only itself, but a first
            // letter of several bytes can equal one too (the Kelvin sign is K), so such a letter is asked.
            var asciiFirstLetters = [Bool](repeating: false, count: 128)
            for letter in firstLetters {
                if let byte = WordCharacter.asciiByte(letter) {
                    asciiFirstLetters[Int(byte)] = true
                } else {
                    for byte in 0..<128 where letter == Character(Unicode.Scalar(UInt8(byte))) {
                        asciiFirstLetters[byte] = true
                    }
                }
            }
            self.asciiFirstLetters = asciiFirstLetters
            // The second gate, which A10b needs (decision 74): a row whose word is only in its heading or
            // source note now scans its whole prose before it falls back, where the scan used to stop at
            // the heading's match. The stemmer rewrites a word's end only, and no further back than a
            // stem's last two characters (every replacement keeps all but the last one or two characters
            // of what it replaces), so a word can stem to a stem only if it opens with all of the stem but
            // those two. Measured over a full index, at the Mac's 7,500 rows: "Presidential Materials"
            // went from 8.4 s to 3.6 s in a debug build, with not one snippet changed in nine searches.
            // `SearchSnippetCostTests.stemmingKeepsTheWordsOpening` holds the stemmer to it.
            openings = stems.filter { !$0.isEmpty }.map { $0.prefix(max(1, $0.count - 2)).map(\.asciiValue) }
        }

        /// Whether the word in `characters[start..<end]` passes both gates, and so is stemmed.
        func admit(_ characters: [Character], from start: Int, to end: Int, sawPunctuation: Bool) -> Bool {
            // The cheap gate: a table for one ASCII character, which `lowercased()` would change from A–Z
            // to a–z and leave otherwise; for any other, the character lowercased and a set probe.
            if let byte = WordCharacter.asciiByte(characters[start]) {
                let lower = (65...90).contains(byte) ? byte + 32 : byte
                guard asciiFirstLetters[Int(lower)] else { return false }
            } else {
                guard let head = characters[start].lowercased().first, firstLetters.contains(head) else { return false }
            }
            // The second gate, for a word the stemmer reads as it is written (an apostrophe or a hyphen
            // is taken out first, which moves its letters).
            return sawPunctuation || opensLikeAStem(characters, from: start, to: end)
        }

        /// Whether the word in `characters[start..<end]` opens as one of the stems' ``openings`` does,
        /// compared in ASCII. A character outside ASCII is not compared, and lets the word through to
        /// the stemmer, which decides. A word's character has an `asciiValue` only when it is one ASCII
        /// character (``WordCharacter/asciiByte(_:)``): CR LF, the one other character that has one, is
        /// in no word.
        private func opensLikeAStem(_ characters: [Character], from start: Int, to end: Int) -> Bool {
            let length = end - start
            return openings.contains { opening in
                guard opening.count <= length else { return false }
                for j in 0..<opening.count {
                    guard let letter = WordCharacter.asciiByte(characters[start + j]), let expected = opening[j]
                    else { return true }
                    // ASCII upper case to lower; a stem is lower case already.
                    let lower = (65...90).contains(letter) ? letter + 32 : letter
                    if lower != expected { return false }
                }
                return true
            }
        }
    }

    /// How the scan reads one character of a body: a letter, which opens a word or goes on with one; an
    /// apostrophe or a hyphen, which goes on with one; or anything else, which ends it.
    private enum WordCharacter {
        case letter, joiner, other

        /// What the scan reads `character` as: from ``ascii`` for one ASCII character, as nearly every
        /// character of a FRUS body is, and otherwise from `Character` itself (``init(asking:)``).
        ///
        /// `Character.isLetter` reads its first scalar's Unicode property from the runtime's tables, a
        /// call no build inlines. The scan asked it of every character, and twice of most, which was 85%
        /// of the scan and 57% of the snippet pass: sampled in a release build over a full index, "What
        /// was the Long Telegram?" at the Mac's 7,500 rows.
        @inline(__always)
        init(_ character: Character) {
            if let byte = Self.asciiByte(character) {
                self = Self.ascii[Int(byte)]
            } else {
                self.init(asking: character)
            }
        }

        /// What `Character` says `character` is: the scan's test of every character before the table,
        /// and still its test of one outside it.
        init(asking character: Character) {
            if character.isLetter {
                self = .letter
            } else if character == "'" || character == "-" {
                self = .joiner
            } else {
                self = .other
            }
        }

        /// What the scan reads each ASCII character as, by its value: asked of `Character` once
        /// (``init(asking:)``), so that the table and the test cannot disagree.
        static let ascii: [WordCharacter] = (0..<128).map { byte in
            WordCharacter(asking: Character(Unicode.Scalar(UInt8(byte))))
        }

        /// The one byte of `character` when it is one ASCII character, and `nil` for any other: one outside
        /// ASCII, or one of several scalars, as an *e* with a combining accent is.
        @inline(__always)
        static func asciiByte(_ character: Character) -> UInt8? {
            let utf8 = character.utf8
            return utf8.count == 1 ? utf8.first : nil
        }
    }
}
