// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - QueryInspection

/// What the Query Inspector knows about a query: what it became, what each part of it
/// matches, and — when nothing matched — which part is responsible.
///
/// ## Why this is a value, not a view
/// Every claim the inspector makes is a factual one a researcher may put in a method
/// appendix, so the claims are computed and tested here rather than assembled in a view
/// body where nothing can check them.
///
/// Version history:
///   1.0 — Q-2a: initial implementation
///   1.1 — #1297: `notApplied`, the operands a query typed but its expression leaves out, and
///         `hasUncountedOperands` / `replacingOperands(_:)`, so neither the count offer nor the
///         scoped-count rebuild reads past `operands` or loses a field
///   1.2 — #1297 join: `isApproximate`, carried by `replacingOperands(_:)`; the operands now include
///         the structured phrase, prefix and excluded terms, from the same combined parse the search runs
///   1.3 — #1297 fixes: `showsApproximateCaption`, the strip's caption gate as a property a test can run
///   1.4 — #1297 round 1: `isFilterOnly` reads `SearchParameters.runsAsFilterOnly`, so a refused text query beside a
///         person or subject filter is no longer called filters only; `isRefused` says why such a query has no
///         expression, and `showsStrip` is the one gate both hosts read
///   1.5 — #1297 round 2: `isRefused` needs something searchable that was refused, so a lone `"`, `(` or `=` typed on the
///         way to a query no longer shows a line whose reasons are false for it
struct QueryInspection: Sendable, Equatable {

    /// The MATCH expression the query rendered to, or `nil` when there is none.
    let expression: RenderedExpression?

    /// The query's searchable units, in the order typed, each with what the index knows
    /// about it.
    let operands: [InspectedOperand]

    /// How many volumes this device has indexed — the denominator every count needs.
    ///
    /// Per-device and live. The corpus has 553 published volumes; what a count is "out
    /// of" is how many of them are indexed *here*, which is the number the researcher's
    /// claim actually rests on.
    let indexedVolumeCount: Int

    /// True when the query runs as a filter-only search — no text at all, and a standalone filter such as a
    /// person filter.
    ///
    /// `SearchService.makeMatchExpressions` returns `(nil, nil)` for these and the search
    /// runs as a filter-only query. There is no expression to show, and saying so is
    /// better than showing an empty strip.
    ///
    /// The same rule the service applies, `SearchParameters.runsAsFilterOnly`. A query with text and no expression
    /// is not one of these even beside a filter: the service throws `FTS5Error.emptyQuery` for it, and
    /// ``isRefused`` describes it.
    let isFilterOnly: Bool

    /// Operands the researcher typed that the search leaves out, in the order typed.
    ///
    /// FTS5 has no universal set, so a part of the query made only of exclusions has nothing to
    /// search for: the `-korea` in `cold OR -korea`, or the `war` in `-(war -korea)`, which pushing
    /// the negation inward leaves as a bare exclusion beside `korea`. The parser leaves it out of
    /// the expression and reports its operands in `ParsedQuery.droppedOperands`; they are
    /// carried here so the inspector can say they were **not applied**, rather than listing
    /// them among ``operands`` as if they had excluded something.
    ///
    /// Every one is an excluded term. The parser pushes a negation inward before deciding what to
    /// leave out, so `cold OR -(war -korea)` searches `korea` and leaves out only `war`; and beside a
    /// structured phrase or prefix nothing is left out at all, because that part gives every
    /// exclusion something to exclude from.
    ///
    /// Never counted and never blamed: ``QueryInspector/scopedCounts(for:parameters:)``,
    /// ``QueryInspector/emptyConjuncts(in:parameters:)`` and ``hasUncountedOperands`` read
    /// ``operands`` only, because a number for a term the query did not use describes
    /// nothing in the result set.
    ///
    /// A `var` with a default so every memberwise call site that predates it compiles
    /// unchanged — which is also why ``replacingOperands(_:)`` exists.
    var notApplied: [ParsedOperand] = []

    /// Whether the expression matches only part of what the query means — `ParsedQuery.isApproximate`.
    ///
    /// Not the same as `!notApplied.isEmpty`. Pushing a negation inward can leave out nothing but an
    /// operator word demoted to a search word, which has no operand row: `-( -korea NOT )` searches
    /// `korea` alone. The strip's narrower-than-typed caption reads this, so that case is still reported.
    ///
    /// A `var` with a default for the same reason as ``notApplied``.
    var isApproximate: Bool = false

    /// Whether the query holds something to search for that the parser refused, so there is no expression and the
    /// search cannot run.
    ///
    /// The parse refuses such a query when nothing in it is positive once its negations apply (`-korea`), when an
    /// approximation of it could match nothing (`-(war -korea) -korea` runs `korea` and excludes it), or when its
    /// groups nest deeper than `FTS5InlineQueryParser.maximumGroupDepth`. `SearchService` then throws
    /// `FTS5Error.emptyQuery` in every scope, a standalone filter or not. The strip says so in place of the
    /// expression; before #1297 round 1 such a query showed nothing, or beside a filter the filters-only line (F8).
    ///
    /// Not every text query without an expression. One whose parse renders and whose content scopes are all off has
    /// none, and the line's reasons would be false for it. Nor does text with nothing searchable in it set this — a
    /// lone `"`, `(`, `=` or `NEAR()`, which the parser sanitises to nothing. The service throws for that text too, but
    /// the strip shows while the researcher pauses mid-typing, and neither reason is true of an opening quote
    /// (#1297 round 2, A2; ``QueryInspector/refusesSomethingSearchable(_:)``).
    ///
    /// A `var` with a default for the same reason as ``notApplied``.
    var isRefused: Bool = false

    /// Whether a host shows the strip at all: there is an expression, or a line saying why there is none.
    ///
    /// Both hosts read this rather than spelling the condition out, so a new reason for an empty expression is
    /// shown on both platforms or on neither.
    var showsStrip: Bool { expression != nil || isFilterOnly || isRefused }

    /// Whether the strip shows its narrower-than-typed caption under the MATCH line: exactly when the
    /// expression is an approximation.
    ///
    /// The gate lives here rather than as a condition in the view so a test can run it. A scan of the view's
    /// source cannot tell `if inspection.isApproximate` from its inversion, and the one fact the caption states
    /// — the search is narrower than what was typed — must never appear on an exact query or vanish from an
    /// approximate one.
    var showsApproximateCaption: Bool { isApproximate }

    /// Whether every operand is present and none of them is the problem.
    var hasOperands: Bool { !operands.isEmpty }

    /// Whether the strip shows term rows at all: applied operands, or operands the query typed
    /// but did not apply.
    ///
    /// Not `hasOperands` alone: `and OR -korea` applies no operand (the literal `and` is not
    /// one) yet leaves `korea` out, and that row is the only place the researcher learns it.
    var showsTermRows: Bool { hasOperands || !notApplied.isEmpty }

    /// Whether any applied operand that is not excluded still lacks its scoped count — the
    /// condition for offering "Count each term in scope…".
    ///
    /// An excluded operand has no hit count to fetch, and a ``notApplied`` one was never
    /// searched, so neither may keep the offer open.
    var hasUncountedOperands: Bool {
        operands.contains { $0.scopedCount == nil && !$0.operand.isNegated }
    }

    /// This inspection with its operands replaced and every other fact carried across.
    ///
    /// The scoped-count pass rebuilds the operand list. Rebuilding the whole value at that
    /// call site would repeat every field, and a field added later with a default — as
    /// ``notApplied`` was — would silently fall back to it there, so the not-applied rows
    /// would vanish the moment the researcher asked for counts.
    func replacingOperands(_ operands: [InspectedOperand]) -> QueryInspection {
        QueryInspection(expression: expression, operands: operands,
                        indexedVolumeCount: indexedVolumeCount, isFilterOnly: isFilterOnly,
                        notApplied: notApplied, isApproximate: isApproximate, isRefused: isRefused)
    }
}

// MARK: - RenderedExpression

/// The FTS5 expression(s) a query produced.
///
/// There are two because the app searches two tables — the corpus (`frus_documents`) and
/// user content (summaries and notes). Under the shipped defaults both scope flags are on
/// and the two strings are **byte-identical**; they diverge only when exactly one of
/// Notes/Summaries is enabled, at which point the user-content one carries a
/// `{summary_text}:` or `{note_text}:` column prefix.
///
/// Version history:
///   1.0 — Q-2a: initial implementation
struct RenderedExpression: Sendable, Equatable {

    /// The corpus expression, or `nil` when document text is out of scope.
    let corpus: String?

    /// The user-content expression, or `nil` when both summaries and notes are out of scope.
    let userContent: String?

    /// The expression to display: the corpus one when there is one, else user content.
    ///
    /// Never a synthesized string. The mock in the design bundle shows a
    /// `{header dateline source_note body_text}:` prefix on the corpus expression, which
    /// the app cannot emit — `renderExpression` passes `columns: nil` for the corpus, so
    /// the prefix is empty. Displaying a prefix the engine never saw would make the
    /// "rendered expression" column non-reproducible, which defeats the point.
    var displayed: String? { corpus ?? userContent }

    /// Whether the two expressions differ, which is worth saying out loud because it
    /// means the two halves of the search asked different questions.
    var expressionsDiffer: Bool {
        guard let corpus, let userContent else { return false }
        return corpus != userContent
    }
}

// MARK: - InspectedOperand

/// One operand, with what the index knows about it.
///
/// ## Two counts, and the gap between them is information
/// `scopedCount` is exact within the researcher's current filters; `corpusDocumentFrequency`
/// is the whole local index, unscoped. Decision Q-2-1 keeps both and labels which is
/// which, because a term that is common corpus-wide but rare in scope — or the reverse —
/// is telling you something about your scope, not just about the term.
///
/// Version history:
///   1.0 — Q-2a: initial implementation
///   1.1 — #1297 fixes: `showsStructuredTag`, the strip's ADVANCED tag gate as a property a test can run
///   1.2 — #1297 round 1: `operand` is the operand as the search applies it, its `=` mark cleared where parser 6.3
///         ignores it (`QueryInspector.asSearched(_:exactTerms:)`)
///   1.3 — #1297 round 2: `operand` is the parser's, unrewritten; the EXACT tag and the scoped count read its
///         `isExactApplied`, which parser 6.4 decides operand by operand, where round 1 cleared `isExact` by word
struct InspectedOperand: Sendable, Equatable {

    /// The parsed operand this describes, exactly as the parser reported it.
    ///
    /// Its `isExact` is the `=` as typed, and its `isExactApplied` whether the search filters on it. Parser 6.4 decides
    /// that operand by operand, so in `(=cold OR war) =cold` only the second `cold` applies. The strip's EXACT tag and
    /// ``QueryInspector/queryText(for:)``, which the scoped count runs, read `isExactApplied`, so both describe the query
    /// that ran. Round 1 cleared `isExact` wherever the operand's WORD was not among `ParsedQuery.exactTerms`, which kept
    /// both marks in that query.
    let operand: ParsedOperand

    /// Whether the strip tags this operand ADVANCED: it came from a structured field — a restored saved
    /// search's phrase, prefix or excluded term — not from the search box.
    ///
    /// A property rather than a condition in the view, for the reason ``QueryInspection/showsApproximateCaption``
    /// is: a test can run it, where a scan of the view cannot tell a gate from its inversion.
    var showsStructuredTag: Bool { operand.source == .structured }

    /// The index term this operand's word resolves to, from SQLite's own tokenizer.
    ///
    /// `nil` for phrases, prefixes and proximity operands, which have no single stem, and
    /// for words that tokenize to more than one term.
    let stem: String?

    /// Exact hit count within the current filters, or `nil` when it has not been computed.
    ///
    /// Populated only by the explicit, expensive pass — see
    /// ``QueryInspector/scopedCounts(for:parameters:)``.
    let scopedCount: Int?

    /// How many indexed documents contain this operand's stem, corpus-wide and unfiltered.
    ///
    /// One `fts5vocab` lookup, no search. `nil` when the operand has no single stem.
    let corpusDocumentFrequency: Int?

    /// How many times this operand's stem occurs in total, corpus-wide and unfiltered.
    ///
    /// The other half of the `fts5vocab` row that ``corpusDocumentFrequency`` reads — it was being
    /// fetched and discarded. Always `>= corpusDocumentFrequency` when both are present: a document
    /// containing the stem contains it at least once.
    ///
    /// `nil` on the same terms as ``corpusDocumentFrequency``.
    let corpusOccurrences: Int?

    /// Average corpus-wide occurrences per document containing the stem, or `nil` when either half
    /// is missing.
    ///
    /// The dispersion signal in one number. Near 1.0 the term is mentioned once wherever it appears;
    /// well above it, discussion concentrates. Both inputs are corpus-wide, so this says nothing
    /// about the researcher's current scope — and the surface that shows it must say so.
    var corpusOccurrencesPerDocument: Double? {
        guard let corpusOccurrences, let corpusDocumentFrequency, corpusDocumentFrequency > 0
        else { return nil }
        return Double(corpusOccurrences) / Double(corpusDocumentFrequency)
    }

    /// Whether the tokenizer broadened this word — the stem differs from what was typed.
    ///
    /// This is the stemming trap in one boolean. It is deliberately *not* the same as
    /// "this is a problem": `europe → europ` differs and matches nothing extra, while
    /// `containment → contain` is the one that misleads. Telling those apart needs the
    /// stem→surface-forms map that decision Q-3-1 deferred to D-1, so the inspector
    /// reports the fact and the count and lets the researcher judge.
    var isStemBroadening: Bool {
        guard let stem, operand.kind == .word else { return false }
        return stem != operand.text.lowercased()
    }
}

// MARK: - QueryInspector

/// Builds a ``QueryInspection`` from a query.
///
/// ## Two passes, priced differently, on purpose
/// - ``inspect(parameters:indexedVolumeCount:)`` is **cheap**: it parses, asks SQLite for
///   each word's stem, and does one `fts5vocab` lookup per operand. No search runs. This
///   is the pass that can be driven live from typing.
/// - ``scopedCounts(for:parameters:)`` and ``emptyConjuncts(in:parameters:)`` are
///   **expensive**: one `searchCount` per operand, each a real query, run serially.
///
///   This doc previously put a common term at 6–12 s, which was measured but misattributed.
///   The Q-M2 prerequisite work found the cost was the unfiltered count's redundant join
///   against a 1.8 GB table; removing it took `"government"` (195,519 matches on the real
///   store) from **2.55 s to 0.011 s** cold for the same answer. A per-operand pass is now
///   sub-second per operand rather than ~9 s. It stays on demand anyway — serial, N
///   queries, and unbounded in N — but it is no longer the head-of-line blocker it was.
///
/// The split is the whole reason decision Q-2-1 lands where it does: the unscoped estimate
/// is what a type-ahead can afford, and the scoped exact count is what a published claim
/// needs.
///
/// Version history:
///   1.0 — Q-2a: initial implementation
///   1.1 — #1297: the parser's dropped operands become `QueryInspection.notApplied`, uncounted
///         and unblamed; `inspect(parsed:parameters:indexedVolumeCount:)` takes a caller's parse
///   1.2 — #1297 join: inspects `SearchService.parsedQuery(for:)`, the combined parse the search
///         renders, and carries its `isApproximate`; a structured operand is narrowed for counting
///         through its own field
///   1.3 — #1297 round 1: `isFilterOnly` is `runsAsFilterOnly` and a refused text query sets `isRefused` (F8); an
///         `=` mark parser 6.3 ignores is cleared before anything reads the operand, so it is neither tagged EXACT
///         nor counted as the literal word (`asSearched(_:exactTerms:)`)
///   1.4 — #1297 round 2: the operands are inspected as parsed, and an `=` is tagged and counted as the literal word
///         exactly where the operand's own `isExactApplied` is set (A1), replacing `asSearched(_:exactTerms:)`, which
///         decided by word; `isRefused` needs something searchable that was refused (`refusesSomethingSearchable(_:)`,
///         A2); `Inputs`, the parts of a parameter set the passes read, keys the iOS refresh (A3)
struct QueryInspector: Sendable {

    /// The service every lookup runs through — counts, stems and vocabulary alike.
    ///
    /// One dependency rather than two, so the stems the inspector displays and the counts
    /// it reports provably come from the same store the search itself queries.
    let searchService: SearchService

    /// Creates an inspector.
    init(searchService: SearchService) {
        self.searchService = searchService
    }

    // MARK: - The cheap pass

    /// Describes `parameters` without running a search.
    ///
    /// - Parameter indexedVolumeCount: how many volumes this device has indexed. Supplied
    ///   by the caller because it is app state (`AppState.indexedVolumeIds`), and because
    ///   passing it in keeps this type testable without one.
    func inspect(parameters: SearchParameters, indexedVolumeCount: Int) async -> QueryInspection {
        // The corpus parse, unscoped: operands and their reporting do not depend on the column
        // prefix, and the corpus expression is the one the strip displays first.
        await inspect(parsed: SearchService.parsedQuery(for: parameters), parameters: parameters,
                      indexedVolumeCount: indexedVolumeCount)
    }

    /// Describes `parameters` from a parse the caller has already made, without running a
    /// search.
    ///
    /// ``inspect(parameters:indexedVolumeCount:)`` is this with the parse made by
    /// `SearchService.parsedQuery(for:)`, and is its only production caller. The split lets a
    /// test hand the inspector a `ParsedQuery` of a chosen shape — dropped operands included —
    /// and check what the inspector does with it against a real index, without depending on
    /// which queries the parser of the day happens to drop.
    ///
    /// - Parameters:
    ///   - parsed: the combined parse of `parameters.keywords` and its structured phrase, prefix
    ///     and excluded terms, or `nil` for none. Its `operands` are inspected as reported, `isExactApplied`
    ///     included; its `droppedOperands` become ``QueryInspection/notApplied``; its `isApproximate` becomes
    ///     ``QueryInspection/isApproximate``; and a `nil` expression beside something searchable becomes
    ///     ``QueryInspection/isRefused``.
    ///   - parameters: the query, which still supplies the rendered expression and the filters.
    ///   - indexedVolumeCount: how many volumes this device has indexed.
    func inspect(
        parsed: ParsedQuery?, parameters: SearchParameters, indexedVolumeCount: Int
    ) async -> QueryInspection {
        let expression = await renderedExpression(for: parameters)

        var inspected: [InspectedOperand] = []
        // As parsed: whether an `=` applies is the parser's per-operand `isExactApplied`, which the strip and the scoped
        // count read. Deciding it again here from the word is how round 1 kept both marks in `(=cold OR war) =cold`.
        for operand in parsed?.operands ?? [] {
            let stem = await stem(for: operand)
            // One `fts5vocab` row carries both halves; reading only `doc` fetched `cnt` and
            // discarded it. Same query, same cost.
            var profile: (documentFrequency: Int, occurrences: Int)?
            if let stem {
                profile = try? await searchService.corpusTermProfile(forStem: stem)
            }
            inspected.append(InspectedOperand(
                operand: operand, stem: stem,
                scopedCount: nil,
                corpusDocumentFrequency: profile?.documentFrequency,
                corpusOccurrences: profile?.occurrences))
        }

        return QueryInspection(
            expression: expression,
            operands: inspected,
            indexedVolumeCount: indexedVolumeCount,
            // `runsAsFilterOnly`, the rule `makeMatchExpressions` applies, not `supportsFilterOnlySearch`: beside a
            // filter a refused text query still throws, and calling it filters only contradicted the error (F8).
            isFilterOnly: expression == nil && parameters.runsAsFilterOnly,
            // No stem or vocabulary lookup for these: a count beside a term the search did not
            // use would read as evidence about the result set.
            notApplied: parsed?.droppedOperands ?? [],
            isApproximate: parsed?.isApproximate ?? false,
            // The parse, not only the missing expression: text whose parse renders has no expression when every
            // content scope is off, and "cannot run because of what was typed" would be false for it. And something
            // searchable in it: a lone `(` typed on the way to a query is refused too, and neither reason is true of it.
            isRefused: expression == nil && parameters.hasTextTerms && parsed?.expression == nil
                && Self.refusesSomethingSearchable(parameters)
        )
    }

    /// The stand-in structured phrase ``refusesSomethingSearchable(_:)`` sets beside a query: any word the parser renders.
    private static let refusalProbeAnchor = "anchor"

    /// Whether `parameters` holds something to search for — an operand, or groups nested past the parser's limit — that
    /// its combined parse refuses. Meaningful only once that parse is `nil`.
    ///
    /// A `nil` parse does not say so on its own. The parser also refuses text whose terms sanitise to nothing, such as a
    /// lone `"`, `(`, `=`, `-(`, `NEAR()` or `?`, and for that text the strip's refused line would give two reasons,
    /// exclusions and nesting, neither of them true (#1297 round 2, A2). A refused parse reports no operands, so this
    /// asks the parser again with a stand-in structured phrase beside the query, keeping its restored excluded terms.
    /// Beside a phrase every complement has an anchor, so the parse renders and reports every searchable operand the
    /// query holds; the query holds one exactly when an operand other than the stand-in comes back.
    ///
    /// The one refusal a stand-in cannot lift is the nesting limit, which is why a `nil` probe counts as something
    /// refused. `FTS5InlineQueryParser.parseDetailed` compares `groupDepth(of:)` over the typed tokens with
    /// `maximumGroupDepth` before it builds anything, and refuses whatever sits beside them. The app cannot run that
    /// scan itself — it reads the parser's private tokenization, and a copy of that would be a second tokenizer to
    /// drift — so the limit is reached through the parse. Measured with parser 6.4 over every sequence of one to four
    /// tokens from `cold`, `-korea`, `=cold`, `-=cold`, `OR`, `NOT`, `AND`, `(`, `)`, `-(`, `"`, `"cold"`, `?`, `=`, `-`,
    /// `NEAR(`, `NEAR()`, `*`, `cold*`, `-"x y"`, `NEAR(cold war, 3)` and `“` — 245,410 queries, each alone, inside 32
    /// and 33 groups, and inside 33 groups 32 of them excluded, and each of those with and without the restored excluded
    /// terms `korea` and `?`, 1,963,280 probes — the probe was `nil` exactly when the groups nested past the limit, and
    /// never approximate. Of the same queries alone, 35,621 are refused: 26,581 hold something searchable, every one of
    /// them holding a typed exclusion, and 9,040 hold nothing.
    static func refusesSomethingSearchable(_ parameters: SearchParameters) -> Bool {
        let beside = StructuredQueryParts(phrase: refusalProbeAnchor, prefixWildcard: nil,
                                          excludedTerms: parameters.excludedTerms)
        let probe = FTS5InlineQueryParser.parseDetailed(parameters.keywords ?? "", structured: beside)
        guard probe.expression != nil else { return true }
        return probe.operands.contains { !($0.source == .structured && $0.kind == .phrase) }
            || !probe.droppedOperands.isEmpty
    }

    // MARK: - What the passes read

    /// The parts of a `SearchParameters` value the inspector's passes read, and nothing else, so a host can refresh
    /// exactly when an inspection could change — the iOS strip's refresh key, `SearchViewModel.queryInspectorRefreshKey`.
    ///
    /// `SearchParameters`' own `==` also compares four fields no pass reads: a person filter's `personLabel` and
    /// `personAnchor`, which name the rollup `personRollupId` filters on and re-find it after a renumber; `booleanMode`,
    /// which the inline parser never consults; and `projectId`, which no search path reads. A rollup rebuild captures an
    /// anchor or relabels a filter without changing it and without running a search, and a key that moved with them
    /// replaced the inspection, dropping the scoped counts the researcher had asked for and the zero-result blame
    /// (#1297 round 2, A3). Everything held here is read: the text and structured fields by the combined parse; the
    /// scope flags by `SearchService.matchExpressions` and the exact-word columns; the standalone filters by
    /// `runsAsFilterOnly`; and every filter by `SearchService.searchCount`, which the scoped counts and the zero-result
    /// decomposition run — `subjectName`, the fallback half of a subject filter, and the inert `subjectTagIds`, which
    /// `makeFilters` still passes on, included.
    ///
    /// `QueryInspectionTests` enumerates `SearchParameters`' stored properties, so a field added there fails that test
    /// until it is placed on one side of this line.
    struct Inputs: Equatable, Sendable {
        /// `SearchParameters.keywords`.
        let keywords: String?
        /// `SearchParameters.phrase`.
        let phrase: String?
        /// `SearchParameters.excludedTerms`.
        let excludedTerms: [String]
        /// `SearchParameters.prefixWildcard`.
        let prefixWildcard: String?
        /// `SearchParameters.dateRange`.
        let dateRange: DateRange?
        /// `SearchParameters.yearKeys`.
        let yearKeys: [String]?
        /// `SearchParameters.subjectTagIds`.
        let subjectTagIds: [String]
        /// `SearchParameters.userTagIds`.
        let userTagIds: [String]
        /// `SearchParameters.volumeIds`.
        let volumeIds: [String]?
        /// `SearchParameters.documentIds`.
        let documentIds: [String]?
        /// `SearchParameters.subjectBucket`.
        let subjectBucket: Int?
        /// `SearchParameters.subjectBucketKey`.
        let subjectBucketKey: String?
        /// `SearchParameters.subjectRef`.
        let subjectRef: String?
        /// `SearchParameters.subjectName`.
        let subjectName: String?
        /// `SearchParameters.excludeDocumentIds`.
        let excludeDocumentIds: [String]?
        /// `SearchParameters.includeDocumentText`.
        let includeDocumentText: Bool
        /// `SearchParameters.includeSummaries`.
        let includeSummaries: Bool
        /// `SearchParameters.includeNotes`.
        let includeNotes: Bool
        /// `SearchParameters.documentTypeFilter`.
        let documentTypeFilter: DocumentTypeFilter
        /// `SearchParameters.personRef`.
        let personRef: String?
        /// `SearchParameters.personRollupId`.
        let personRollupId: Int?
        /// `SearchParameters.includeFrontMatter`.
        let includeFrontMatter: Bool

        /// The parts of `parameters` the passes read.
        init(_ parameters: SearchParameters) {
            keywords = parameters.keywords
            phrase = parameters.phrase
            excludedTerms = parameters.excludedTerms
            prefixWildcard = parameters.prefixWildcard
            dateRange = parameters.dateRange
            yearKeys = parameters.yearKeys
            subjectTagIds = parameters.subjectTagIds
            userTagIds = parameters.userTagIds
            volumeIds = parameters.volumeIds
            documentIds = parameters.documentIds
            subjectBucket = parameters.subjectBucket
            subjectBucketKey = parameters.subjectBucketKey
            subjectRef = parameters.subjectRef
            subjectName = parameters.subjectName
            excludeDocumentIds = parameters.excludeDocumentIds
            includeDocumentText = parameters.includeDocumentText
            includeSummaries = parameters.includeSummaries
            includeNotes = parameters.includeNotes
            documentTypeFilter = parameters.documentTypeFilter
            personRef = parameters.personRef
            personRollupId = parameters.personRollupId
            includeFrontMatter = parameters.includeFrontMatter
        }
    }

    /// The index term an operand's word resolves to, or `nil` when it has no single one.
    ///
    /// Only a bare word has a stem worth showing. A phrase is several words, a prefix is
    /// deliberately many, and a `NEAR(...)` is a whole expression — labelling any of them
    /// with one stem would be a lie of convenience.
    private func stem(for operand: ParsedOperand) async -> String? {
        guard operand.kind == .word else { return nil }
        return try? await searchService.indexStem(of: operand.text)
    }

    /// Renders the query's MATCH expression(s), or `nil` when it has none.
    private func renderedExpression(for parameters: SearchParameters) async -> RenderedExpression? {
        guard let pair = try? await searchService.matchExpressions(for: parameters) else { return nil }
        guard pair.corpus != nil || pair.userContent != nil else { return nil }
        return RenderedExpression(corpus: pair.corpus, userContent: pair.userContent)
    }

    // MARK: - The expensive passes

    /// Runs one exact `searchCount` per operand, within the current filters.
    ///
    /// Returns the operands with `scopedCount` filled in. Operand order is preserved so a
    /// view can diff against the cheap pass without re-keying.
    ///
    /// A **negated** operand is skipped rather than counted: "how many documents contain
    /// the thing you excluded" is not a number the result set contains, and showing it
    /// beside the others would read as a hit count. Operands in
    /// ``QueryInspection/notApplied`` are not visited at all — the search never used them.
    func scopedCounts(
        for inspection: QueryInspection, parameters: SearchParameters
    ) async -> [InspectedOperand] {
        var out: [InspectedOperand] = []
        for item in inspection.operands {
            guard !item.operand.isNegated else { out.append(item); continue }
            let count = try? await searchService.searchCount(
                parameters: Self.parameters(parameters, narrowedTo: item.operand))
            out.append(InspectedOperand(
                operand: item.operand, stem: item.stem,
                scopedCount: count,
                corpusDocumentFrequency: item.corpusDocumentFrequency,
                corpusOccurrences: item.corpusOccurrences))
        }
        return out
    }

    /// Names the operands that return nothing on their own — the reason a conjunctive
    /// query came back empty.
    ///
    /// This is the whole point of the zero path. "No results" is indistinguishable from a
    /// typo, a stemming surprise and a genuine historical absence; "*guarantee* matches
    /// 41 documents here, *Formosa* matches 0" is a finding.
    ///
    /// Negated operands are excluded: an excluded term matching nothing is not why the
    /// query is empty. Neither is a ``QueryInspection/notApplied`` operand, which is not
    /// visited: the search never used it, whatever it would match on its own.
    func emptyConjuncts(
        in inspection: QueryInspection, parameters: SearchParameters
    ) async -> [ParsedOperand] {
        var empty: [ParsedOperand] = []
        for item in inspection.operands where !item.operand.isNegated {
            let count = try? await searchService.searchCount(
                parameters: Self.parameters(parameters, narrowedTo: item.operand))
            if count == 0 { empty.append(item.operand) }
        }
        return empty
    }

    /// Rebuilds `parameters` so its text is a single operand, keeping every filter and scope
    /// flag intact.
    ///
    /// Keeping the filters is what makes the answer useful: the question is "does this
    /// term match anything *here*", not "anywhere". The operand's own marks are restored
    /// so an exact term is counted exactly and a prefix as a prefix — counting
    /// `=containment` as plain `containment` would report a number the query never used.
    /// The reverse holds too, which is why ``queryText(for:)`` spells an `=` only where the operand's
    /// `isExactApplied` is set: in `=containment OR alliance` the mark is ignored, and counting it
    /// exactly would report a number that query never used either.
    ///
    /// A typed operand is re-spelled as search-box text. A structured one goes back into its own
    /// field instead, because the two spellings are not always the same query: the prefix field
    /// `neg:oti` renders `"neg oti"*`, while typed `neg oti*` renders `"neg" AND "oti"*`. A
    /// structured operand is only ever a phrase or a prefix here — an excluded term is negated,
    /// and negated operands are never narrowed to.
    static func parameters(
        _ base: SearchParameters, narrowedTo operand: ParsedOperand
    ) -> SearchParameters {
        var narrowed = base
        // Every text field is cleared first; leaving one set would AND it into a count that is
        // supposed to be about one operand.
        narrowed.keywords = nil
        narrowed.phrase = nil
        narrowed.prefixWildcard = nil
        narrowed.excludedTerms = []
        switch operand.source {
        case .typed:
            narrowed.keywords = queryText(for: operand)
        case .structured:
            switch operand.kind {
            case .phrase:
                narrowed.phrase = operand.text
            case .prefix:
                // `text` carries the `*` the field appends itself.
                narrowed.prefixWildcard = String(operand.text.dropLast())
            case .word, .proximity:
                narrowed.keywords = queryText(for: operand)
            }
        }
        return narrowed
    }

    /// The search-box text that reproduces one operand on its own, as the search applied it.
    ///
    /// A word is spelled `=word` exactly when its mark applied — `ParsedOperand.isExactApplied` — and plain otherwise,
    /// `=` typed or not: parser 6.4 ignores a mark on an operand a match need not contain, such as the first `cold` of
    /// `(=cold OR war) =cold`, and the search runs that word by its stem. Parsed alone, an applied `=word` is exact
    /// again, by the parser's own spelling rule (`=cold:` filters on `cold`).
    static func queryText(for operand: ParsedOperand) -> String {
        switch operand.kind {
        case .word:
            return operand.isExactApplied ? "=\(operand.text)" : operand.text
        case .phrase:
            return "\"\(operand.text)\""
        case .prefix, .proximity:
            // `text` already carries the `*` for a prefix and the whole `NEAR(...)` for a
            // proximity operand.
            return operand.text
        }
    }
}
