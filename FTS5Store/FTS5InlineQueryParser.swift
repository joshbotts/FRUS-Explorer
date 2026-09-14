// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

// MARK: - FTS5InlineQueryParser

/// Translates Google-style inline query syntax typed into the main search box into a
/// ready-to-embed, stemmed FTS5 MATCH expression fragment.
///
/// ## Why this exists
/// `FTS5Query.toFTS5MatchExpression()` builds its keyword expression from an already
/// *split* `[String]` plus a single uniform `booleanMode` — it has no concept of mixed
/// operators within one query. Historically `SearchService.makeFTS5Query` fed it the
/// naive whitespace split of the user's typed text, so `"cold war" OR blockade -korea`
/// became four literal ANDed keywords (`cold`, `war`, `or`, `blockad`) with the quotes
/// and `-` stripped by `sanitizeTerm` — silently producing a far more restrictive query
/// than the user intended (this was the exact bug reported as "OR yields fewer results
/// than AND"). This parser recognises that syntax for real and renders it directly to a
/// valid FTS5 expression. `SearchService` renders every search through
/// `parseDetailed(_:columnPrefix:structured:)`, which parses the typed text and the structured
/// phrase, prefix and excluded terms as one query; `FTS5Query.keywordExpression` carries a parsed
/// expression only where nothing sits beside it, as in `CorpusAnalyticsService`.
///
/// ## Syntax recognised
///
/// | Syntax | Meaning | Example |
/// |---|---|---|
/// | bare words | AND (rendered as an explicit `AND` keyword) | `cold war` → both required |
/// | `"quoted phrase"` | exact word-order phrase match | `"cold war"` |
/// | `OR` (any case) | either side matches | `Rusk OR Bundy` |
/// | `AND` (any case) | both sides match | `cold and war` |
/// | leading `-` | exclude a term, phrase or wildcard — or, attached to `(`, a group — from its AND-run, wherever it sits in the run | `-quarantine blockade`, `-"naval blockade"`, `cold -(korea OR vietnam)` |
/// | `NOT` (any case) | the same exclusion as `-` before a term, phrase, wildcard or group, and the only way to exclude a `NEAR(...)`; repeated marks exclude once | `cold NOT korea`, `not (korea OR vietnam) cold`, `aid NOT NEAR(military europe, 5)` |
/// | trailing `*` | prefix wildcard | `negoti*` |
/// | `( ... )` | groups a sub-expression; combines with the rest of the query like any operand | `(aqaba OR tiran) AND (navigation OR passage OR transit)` |
///
/// Operator keywords are recognised **in any case** (`and`/`And`/`AND` all act as the
/// operator, matching history.state.gov) and **only where they can bind**: an `AND` or
/// `OR` needs an operand on its left and, on its right, an operand or a chain of `NOT`s
/// ending in one; a `NOT` needs a chain of `NOT`s ending in an operand. An operator that
/// cannot bind — a leading or trailing `AND`/`OR`, the first of two doubled ones, a
/// trailing `NOT` — is demoted back to a literal search word for that same term instead
/// of being mis-parsed. To search for the literal word "and"/"or"/"not", quote it:
/// `"war and peace"`.
///
/// The expression is rendered from a boolean tree, never by splicing tokens, and that is
/// what guarantees the renderer never emits a MATCH expression SQLite would reject.
/// FTS5's `NOT` is strictly binary — `NOT "korea" AND "cold"` and `"cold" AND NOT "korea"`
/// are both syntax errors — so the renderer emits `NOT` only with a left operand, `AND`
/// and `OR` only between two sub-expressions, and parentheses wherever FTS5's precedence
/// (`NOT` binds tighter than `AND`, `AND` tighter than `OR`) would otherwise regroup what
/// the researcher typed.
///
/// Adjacent operands (juxtaposition, an explicit `AND`, or a parenthesised group next to
/// another operand) are always joined with an **explicit `AND` keyword**, never bare
/// concatenation. FTS5 permits implicit-AND only between bare phrases — `(a OR b) (c OR
/// d)` is a hard syntax error — so emitting the keyword is what keeps grouped queries
/// valid (this was the "grouped boolean query returns zero results" bug).
///
/// Each bare word and phrase word is sanitised and Porter-stemmed exactly as
/// `FTS5Query` does today, so results match the stemmed index identically regardless
/// of which path produced the expression.
///
/// ## Exclusions
/// An exclusion belongs to its **AND-run** — the members between two surviving `OR`s at
/// one nesting level, a group counting as one member — wherever it sits in that run, and
/// it never reaches across an `OR`: `-korea cold OR war` renders
/// `"cold" NOT "korea" OR "war"`, the same as `cold -korea OR war`. A leading exclusion is
/// placed behind the run's first positive member, and an `AND` typed directly before an
/// exclusion adds nothing to it (`cold AND -korea` is `cold -korea`).
///
/// Negation marks count once. A negation applied to something with no positive term
/// changes nothing — `cold NOT -korea` and `cold NOT NOT korea` are `cold -korea`, and
/// `NOT NOT cold` has no positive term at all, so it renders `nil`. A negation applied to
/// something that does contain a positive term is a true complement: `NOT (cold OR
/// -korea)` requires korea and excludes cold.
///
/// FTS5 has no universal set, so a query can only exclude from something it searches for.
/// An `OR` alternative made only of exclusions (`cold OR -korea`) therefore cannot be
/// searched. At the top level, or inside a top-level group, it is left out together with
/// its `OR`, and its operands are reported in `ParsedQuery.droppedOperands` — the search
/// runs as the narrower `cold`, and the Query Inspector can say what was not applied. If
/// every alternative is left out the expression is `nil`. Inside an enclosing AND-run the
/// same alternative is rendered exactly, by De Morgan's law: `war (cold OR -korea)`
/// renders `"war" NOT ("korea" NOT "cold")`, and nothing is dropped.
///
/// A complement is never left out whole while it holds a positive term. Before anything is
/// left out, a negation is pushed inward by De Morgan's law and what that exposes is
/// anchored like any other query: `cold OR -(war -korea)` means cold OR NOT war OR korea, so
/// it renders `"cold" OR "korea"` and reports only `war` as dropped. Every dropped operand is
/// therefore negated, and no applied operand is ever reported as dropped.
///
/// An approximation that provably matches nothing is refused rather than run. Pushing a negation
/// inward can expose an anchor that an exclusion beside it then removes in full:
/// `-(war -korea) -korea` would search `"korea" NOT "korea"`, and so would `-(war -korea)` beside
/// the excluded term korea. Such a query is `nil` — the refusal it got before negation was pushed
/// inward, on which `SearchService` throws `FTS5Error.emptyQuery` — instead of a search whose empty
/// result would read as a finding. The same holds for an empty alternative kept on its own, as in
/// `korea -korea OR -korea`. The proof is over operands, never documents: an approximation is
/// refused only when an operand every match must match is one it excludes — the same core,
/// excluded in a scope that spans the anchor's. An excluded
/// term with no column prefix, as a structured one always is, spans every column, so
/// `{body_text}:"korea" NOT "korea"` is refused, while a scoped exclusion removes only an anchor in its
/// own scope. A phrase is not taken to contain its words, nor a prefix the words it begins, so an
/// approximation left empty by what its words mean still runs; so does one that matches something
/// beside its empty part, like `"cold" OR "korea" NOT "korea"`. An exact render is never refused:
/// `korea -korea` is what was typed, and searches `"korea" NOT "korea"`.
///
/// `ParsedQuery.isApproximate` is `true` whenever the expression matches less than the query
/// means. It is the only report when what was left out has no operand of its own:
/// `-( -korea NOT )` means korea OR NOT the demoted word "not", and renders `"korea"`.
///
/// ## Structured parts
/// `parse(_:columnPrefix:structured:)` and `parseDetailed(_:columnPrefix:structured:)` also
/// take the structured search fields — a phrase, a prefix wildcard and excluded terms
/// (`StructuredQueryParts`), as restored saved searches carry them — as further members of
/// the same tree, conjoined with the typed query and harvested after its operands, with
/// `ParsedOperand.source` `.structured`. One tree decides meaning, anchoring and reporting
/// for the query that actually runs, so a phrase or prefix anchors a typed complement beside
/// it: typed `-korea` beside the phrase "cold war" renders `"cold war" NOT "korea"`, and
/// `cold OR -korea` beside the prefix `viet` renders `"viet"* NOT ("korea" NOT "cold")`, with
/// nothing dropped. A structured excluded term is no anchor, so typed `-korea` beside the
/// excluded term `vietnam` is still `nil`.
///
/// The fields are sanitised exactly as `FTS5Query` always sanitised them, and combined by
/// the rule it always used — positive parts joined by `AND`, each parenthesised unless it is
/// one operand, then every exclusion applied to the whole — which `FTS5Query` now takes from
/// here (`combine(renderedKeywords:structured:columnPrefix:)`). The phrase spans every
/// column, the prefix carries the column prefix, and an excluded term carries none, so it
/// removes a document whichever column holds the term. With no structured field set, a
/// typed query renders exactly what it renders alone.
///
/// ## Grouping
/// `(...)` groups parse **recursively** into the same tree: `buildNode` calls itself on
/// each balanced group's contents and folds the result back into the surrounding level as
/// a single member, which then takes part in operator resolution exactly like a bare word
/// or phrase. Groups therefore compose with `AND`/`OR`/`NOT` — including negating a whole
/// group via `NOT (...)` or `-(...)` — and nest to arbitrary depth:
/// `((aqaba OR tiran) AND navig*) OR (suez NOT canal)` round-trips intact. FTS5
/// itself natively supports parenthesised grouping in MATCH expressions, so a group
/// renders with its parentheses as typed.
///
/// A group with no content — `()`, `(   )` — is dropped in its entirety rather than
/// rendering as an empty `()`. A group of only exclusions is not dropped: it excludes from
/// the AND-run around it exactly as its members would bare, so `cold (-korea)` renders
/// `"cold" NOT "korea"` and `cold (-korea -vietnam)` renders
/// `"cold" NOT ("korea" OR "vietnam")`. As an `OR` alternative it is left out and reported,
/// like any other alternative made only of exclusions.
///
/// Degradation is graceful by construction: an unmatched `(` or stray `)` never
/// finds a balanced partner, falls through to ordinary token handling, sanitises to
/// nothing (parens are structural punctuation to `sanitizeBareToken`, exactly like
/// `{`/`}`/`:`/`/`), and is silently dropped.
///
/// ## A dash before a group
/// A dash **attached** to an opening parenthesis negates the group exactly as `NOT` does:
/// `cold -(korea OR vietnam)` and `cold NOT (korea OR vietnam)` both render
/// `"cold" NOT ("korea" OR "vietnam")`, and `-(...)` parses identically to `NOT (...)` in
/// every position. A **detached** dash — whitespace between it and the parenthesis — is
/// punctuation, as a lone `-` is everywhere else, and is dropped:
/// `cold - (korea OR vietnam)` searches for the group, `"cold" AND ("korea" OR "vietnam")`.
///
/// An attached dash with no group to negate keeps the punctuation reading rather than
/// becoming a stranded negation. Before a parenthesis with no balanced partner
/// (`cold -(korea` renders `"cold" AND "korea"`) or a group with no content (`cold -()`
/// renders `"cold"`) it is dropped along with its parenthesis. Those are the only two
/// places the spellings differ, because there the keyword is text the researcher can see:
/// `cold NOT (korea` excludes korea, and a `NOT` stranded by `cold NOT ()` is demoted to
/// the word "not".
///
/// The rule reaches only a dash that begins a token, and only a group. A dash that is not
/// the first character of its token is not attached to the parenthesis after it, so
/// `cold --(korea)` still searches for the group. Nor does a dash reach `NEAR(...)`:
/// `aid -NEAR(military europe, 5)` is the excluded word "near" beside a positive group of
/// the words, as it always was, so a proximity is excluded only with `NOT NEAR(...)`.
///
/// ## What this does *not* attempt
/// - **Column filters** (`header:cold`) — handled separately via `columnPrefix`,
///   applied uniformly from `SearchParameters`'s content-scope toggles.
///
/// Version history:
///   1.0 — Session 2026-06-08: initial implementation
///   2.0 — Session 2026-06-08: added recursive parenthetical-grouping support —
///          `(...)` now parses and renders to nested FTS5 sub-expressions instead
///          of being stripped as punctuation; groups compose with AND/OR/NOT
///          (including `NOT (...)`) and nest to arbitrary depth; unmatched/empty
///          groups degrade gracefully (dropped/`nil`) rather than producing
///          malformed output
///   3.0 — Session 159: (1) fixed a latent bug where adjacent operands were joined by
///          bare juxtaposition, which FTS5 rejects between parenthesised groups
///          (`(a OR b) (c OR d)` → syntax error) — so every grouped boolean query
///          (e.g. `(aqaba OR tiran) AND (navigation OR passage OR transit)`) failed and
///          surfaced as zero results. Operands are now joined with an explicit `AND`.
///          (2) Operators are now case-insensitive (`and`/`or`/`not` work, not only
///          uppercase), matching history.state.gov. The parser tests now also *execute*
///          their rendered output against a real FTS5 table so invalid output can no
///          longer pass.
///   4.0 — Q-1 (2026-07-29): `NEAR(a b, N)` proximity search. Recognised before ordinary
///          grouping (the parens are the operator's argument list, not a boolean group),
///          rendered as one opaque operand so it composes with `AND`/`OR`/`NOT` and nests
///          in groups through the existing pipeline. Case-insensitive on input, always
///          emitted uppercase because FTS5 rejects `near(`. `NEAR/N(a b)` is accepted as
///          an alias and *translated* — it is not valid FTS5 in any spelling. The column
///          prefix wraps the whole operator, which FTS5 requires and which makes a phrase
///          inside a NEAR column-scoped where a bare phrase is not. Contents FTS5 forbids
///          inside a NEAR (booleans, negation, nested groups) and any distance it will not
///          parse (negative, decimal, signed, empty, non-numeric) degrade to an ordinary
///          boolean group over the same words rather than reaching SQLite.
///   5.0 — #1297: rendering rebuilt on a boolean tree, because splicing tokens rendered a
///          `NOT` with no left operand whenever an exclusion led its AND-run or followed a
///          typed `AND`/`OR`, and FTS5 rejects that. Over every token sequence of length
///          1–4 on `cold war -korea NOT korea AND OR ( )` (7,380 queries) the old renderer
///          produced 1,674 expressions SQLite rejects and this one produces none.
///          (1) An exclusion is placed within its AND-run wherever it was typed:
///          `-korea cold`, `NOT korea cold`, `-korea (cold OR war)` and `cold AND -korea`,
///          all previously syntax errors, render `"cold" NOT "korea"` or its equivalent.
///          (2) An `AND`/`OR` directly before a `NOT` is an operator, no longer a required
///          literal word. RESULTS MOVE for queries that ran before: `cold AND NOT korea`
///          was `"cold" AND "and" NOT "korea"`, which matched only documents containing
///          the word "and", and is now `"cold" NOT "korea"`; `cold OR NOT korea` was
///          `"cold" AND "or" NOT "korea"` and is now `"cold"`.
///          (3) Negation marks count once: `cold NOT NOT korea` (was
///          `"cold" AND "not" NOT "korea"`) and `cold NOT -korea` (was the invalid
///          `NOT NOT`) render `"cold" NOT "korea"`; a query whose negations reach no
///          positive term is `nil`, where `NOT NOT cold` used to search for the word "not".
///          (4) A group of only exclusions excludes from its run instead of being dropped.
///          RESULTS MOVE: `cold (-korea)` was `"cold"`, returning the korea documents it
///          asked to exclude, and is now `"cold" NOT "korea"`; `cold OR (-korea)` was
///          `"cold" AND "or"`.
///          (5) An `OR` alternative made only of exclusions is left out and reported in
///          `ParsedQuery.droppedOperands` at the top level, and rendered exactly by De
///          Morgan's law inside an enclosing AND-run.
///          (6) A dash attached to `(` negates the group. RESULTS MOVE:
///          `cold -(korea OR vietnam)` used to search FOR the group, and now excludes it;
///          a detached `cold - (korea OR vietnam)` still searches for it.
///          (7) `ParsedOperand.isNegated` is the operand's effective polarity, so keyword
///          `NOT` and `NOT (...)` report their operands excluded as `-` always did, and
///          exact terms come only from positive operands the expression applies:
///          `europe NOT =containment` no longer reports a post-filter requiring the word
///          its own MATCH excludes.
///   6.0 — #1297 join: the structured fields join the tree, and a complement is anchored
///          after its negation is pushed inward. RESULTS MOVE, in two places.
///          (1) `parse(_:columnPrefix:structured:)` and `parseDetailed(_:columnPrefix:structured:)`
///          take a phrase, a prefix and excluded terms (`StructuredQueryParts`) as members of
///          the typed query's root conjunction, and `SearchService` renders through them
///          instead of handing the typed render to `FTS5Query`, which could not see a typed
///          complement that render left out. Restored saved searches with a phrase or prefix
///          beside typed text move: typed `-korea` beside the phrase "cold war" was
///          `"cold war"` — rows 4, 8, 12 and 16 of the truth table, with nothing reported — and
///          is `"cold war" NOT "korea"` (4 and 12); `cold OR -korea` beside the prefix `viet` was
///          `"cold" AND "viet"*` (5 rows, korea not applied) and is
///          `"viet"* NOT ("korea" NOT "cold")` (8 rows, exact).
///          (2) A negated group holding a positive term is no longer left out whole with its
///          positive operands reported as dropped; the negation is pushed inward and anchored.
///          This moves wherever the typed parse is used — Search, Corpus Analytics, the
///          retrieval eval routes, `OccurrenceAvailability`: `cold OR -(war -korea)` was
///          `"cold"` (10 rows) with war and korea dropped, and is `"cold" OR "korea"` (14 rows)
///          with only war dropped; `-(war -korea)` was `nil` and is `"korea"`. Over the 11,110
///          token sequences of length 1–4 with `-(`, in both scopes, 22 of 22,220 typed-alone
///          renders change, every one previously `nil` or narrower.
///          (3) `ParsedQuery.isApproximate` and `ParsedOperand.source`. A typed `NEAR` beside
///          structured parts renders `NEAR(...) NOT "korea"` where `FTS5Query` 2.2 wrote
///          `(NEAR(...)) NOT "korea"`, with the same rows; the `FTS5Query` carrier keeps the
///          parentheses. The #1297 property suite's printed counts move with (2) and every
///          inequality guard still holds: validity with `-(` executed 10,176 → 10,187 per
///          scope; `-(X)` rendered 11,178 → 13,239, negating 7,852 → 7,892, differs from
///          detached 12,432 → 12,864; monotonicity 1,676 → 1,714; set oracle seed 1297
///          narrowed 2,018 → 2,088 and nil 633 → 563, seed 1299 narrowed 1,987 → 2,056 and nil
///          639 → 570. Checked against a set oracle that never reads a render (80,000
///          comparisons) and a 222,200-case sweep of every short sequence beside every
///          structured combination, with no failures.
///   6.1 — #1297 fixes: an approximation that provably matches nothing is refused. RESULTS MOVE, and only from
///          a MATCH no document can satisfy to `nil`, on which `SearchService` throws `FTS5Error.emptyQuery`. 6.0's
///          push-inward could anchor a complement on an operand that an exclusion beside it then removed in full,
///          so queries the app had refused ran a guaranteed-empty search: `-(war -korea) -korea`, and
///          `-(war -korea)` or `-( cold -korea )` beside the excluded term korea, all `"korea" NOT "korea"`. The
///          same held without pushing: `korea -korea OR -korea` kept an empty alternative, and
///          `cold korea OR -korea` beside the excluded korea was `("cold" AND "korea") NOT "korea"`. Each
///          rendered `Expr` now carries what its operands prove — the operands every match matches, those any
///          one of which suffices, and those no match can match — and `parseDetailed` returns `nil` when the
///          query is approximated and its expression requires an operand it forbids. Exact renders are
///          unchanged, and so is an
///          approximation that matches something beside an empty part. Measured over the 222,200 renders of the
///          length-1–4 sweep with `-(`, beside every structured combination in both scopes: 292 change, every
///          one from a MATCH that matches no row of a corpus holding every combination of the swept words to
///          `nil`; the 208 that match nothing only on the #1297 truth table (`"cold" AND "not"`, whose words that
///          table never puts together) still run. Correction to 6.0: its 222,200-case sweep compared every exact
///          term with the typed-alone parse's, but its alphabet has no `=`, so every list it compared was empty
///          and the comparison could not fail. The exact terms are now swept over `=cold` and `-=cold` (111,100
///          combinations per scope): in each scope 20,292 carry an exact term beside a structured phrase or
///          prefix and 13,480 without one, 452 of those approximated, and every one equals the typed-alone
///          parse's wherever both render. Where they do not both render the lists can differ, and only because of
///          this refusal: 48 per scope are refused alone but anchored by a structured phrase or prefix, and
///          report the exact terms they apply; 16 render alone but are refused beside the excluded korea.
///          The #1297 property suites' printed counts move with the refusal, and every inequality guard still
///          holds: validity executed 6,951 → 6,947 without `-(` and 10,187 → 10,183 with it, per scope; `-(X)`
///          rendered 13,239 → 13,233 and negating 7,892 → 7,886, differing from detached unchanged at 12,864;
///          monotonicity compared 1,714 → 1,571; set oracle seed 1297 narrowed 2,088 → 1,764 and nil 563 → 887,
///          seed 1299 narrowed 2,056 → 1,750 and nil 570 → 876. The `FTS5Query` join sweep executed
///          65,133 → 65,121 per scope and its carrier identity carried 20,374 → 20,366, because fewer typed
///          renders reach the carrier; the carrier itself is never approximate, so no byte of its output moves.
///   6.2 — #1297 fixes review: an operator word left as a word carries the column prefix, like any other bare word.
///          RESULTS MOVE only in a scoped parse — in the app, the Summaries-only or Notes-only half of a search — and
///          only where `AND`, `OR` or `NOT` is demoted: scoped `cold OR` was `{body_text}:"cold" AND "or"`, which
///          searched "or" outside the scope, and is `{body_text}:"cold" AND {body_text}:"or"`. With it, refusal no
///          longer depends on the scope wherever a word anchors: 6.1 refused `-korea OR -not NOT` unscoped
///          (`"not" NOT "not"`) but ran it scoped as `"not" NOT {body_text}:"not"`, since an exclusion is shown to
///          remove only an anchor in a scope it spans, and `SearchService` read that search's exact terms and Query
///          Inspector rows from the refused unscoped parse — `( =cold NOT OR -korea ) -not` ran summaries-only
///          without its `=cold` post-filter. Measured over the length-1–4 sequences of three alphabets (the judged one
///          with `-(`, the exact-term one, and one with `-not`, `-and` and `-or`) beside every structured combination:
///          no unscoped parse changes; of 383,240 scoped renders, 195,398 differ only by the prefix on a demoted word
///          and 128 become `nil` — exactly the 128, from 32 sequences, whose unscoped parse was refused — and no exact
///          term, approximation flag or operand count changes on a render. A typed phrase still spans every column,
///          so beside the phrase "korea" a scoped `-korea` removes nothing provably: 16 parses over an alphabet with
///          that phrase (8 sequences, such as `"korea" -korea OR -korea`) are refused only unscoped.
///          `refusalAcrossScopesSweep` pins that class, and `SearchService` 2.2 runs no scope for a query its unscoped
///          parse refuses. No printed count in the #1297 property suites moves.
public enum FTS5InlineQueryParser {

    // MARK: - Public Interface

    /// Parses `raw` (the literal text typed into the search box) into a stemmed,
    /// sanitised FTS5 MATCH expression fragment.
    ///
    /// - Parameter raw: The user's typed query text, in Google-style inline syntax.
    /// - Parameter columnPrefix: An FTS5 column-filter prefix (e.g. `"{header body_text}:"`)
    ///   applied to every bare word, wildcard and operator word left as a word — never to
    ///   an operator keyword, nor to a phrase, which spans every column. Pass `""` to search
    ///   all indexed columns (the default).
    /// - Parameter structured: The structured phrase, prefix wildcard and excluded terms to
    ///   combine with `raw` as one query (see "Structured parts"). `.none` by default.
    /// - Returns: The MATCH expression, or `nil` if neither `raw` nor `structured` carries
    ///   positive search content (nothing typed, only excluded/negated terms, or terms that
    ///   sanitise to nothing). Without `structured`, an expression is also suitable for
    ///   `FTS5Query.keywordExpression`.
    public static func parse(_ raw: String, columnPrefix: String = "",
                             structured: StructuredQueryParts = .none) -> String? {
        parseDetailed(raw, columnPrefix: columnPrefix, structured: structured).expression
    }

    /// Parses `raw` and reports the MATCH expression, the terms the researcher marked
    /// exact with `=`, and which operands the expression applies and which it leaves out.
    ///
    /// The expression and the exact terms travel together because they are two halves of
    /// one query. FTS5 cannot express "this literal word" over a stemmed index, so an exact
    /// term is rendered into the expression as an ordinary stemmed operand — which narrows
    /// the candidate set to a strict superset — and is *also* reported here so the SQL
    /// layer can apply a word-boundary filter to what comes back. Dropping either half
    /// silently changes the answer: without the expression there is nothing to filter, and
    /// without the filter the `=` did nothing.
    ///
    /// `structured` joins the typed query in one tree (see "Structured parts"), so every field
    /// reported here describes the query that runs: its operands follow the typed ones with
    /// `source` `.structured`, a typed complement beside a structured phrase or prefix is
    /// applied rather than dropped, and `isApproximate` says whether the expression matches less
    /// than the whole query means. Only typed words carry `=`, so `exactTerms` never gains a
    /// structured term.
    public static func parseDetailed(_ raw: String, columnPrefix: String = "",
                                     structured: StructuredQueryParts = .none) -> ParsedQuery {
        var harvest = Harvest()
        var parts: [Node] = []
        if let typed = buildNode(tokenize(raw), columnPrefix: columnPrefix, into: &harvest) {
            parts.append(typed)
        }
        parts += structuredParts(structured, columnPrefix: columnPrefix, into: &harvest)
        guard !parts.isEmpty else { return ParsedQuery(expression: nil, exactTerms: []) }
        let root = Node.parts(parts)
        var dropped = Set<Int>()
        guard let expression = anchored(root, dropped: &dropped) else {
            return ParsedQuery(expression: nil, exactTerms: [])
        }
        // Anchoring left something out whenever the query's exact meaning is a complement — even
        // when all it left out is a demoted operator word, which has no operand to report.
        var isApproximate = true
        if case .matching? = exactMeaning(of: root) { isApproximate = false }
        // An approximation its own operands prove empty is refused, as though nothing had anchored: running it
        // could only return no documents, which would read as a finding about the corpus. An exact render is what
        // was typed and always runs.
        if isApproximate, expression.isEmpty { return ParsedQuery(expression: nil, exactTerms: []) }
        var negated: [Int: Bool] = [:]
        polarity(of: root, negated: false, into: &negated)

        var operands: [ParsedOperand] = []
        var droppedOperands: [ParsedOperand] = []
        var exactTerms: [String] = []
        // Order-preserving de-duplication: the same word marked exact twice is one filter.
        var seen = Set<String>()
        for (index, proto) in harvest.operands.enumerated() {
            let isNegated = negated[index] ?? false
            let operand = ParsedOperand(text: proto.text,
                                        rendered: isNegated ? "NOT \(proto.core)" : proto.core,
                                        kind: proto.kind, isNegated: isNegated,
                                        isExact: proto.isExact, source: proto.source)
            if dropped.contains(index) {
                droppedOperands.append(operand)
                continue
            }
            operands.append(operand)
            // Only a *positive* exact term becomes a filter, however the operand came to be
            // excluded — `-=word`, `NOT =word`, `NOT (=word OR x)`. An excluded one would need
            // an inverted post-filter, and getting that subtly wrong silently over-excludes;
            // a plain one would require the very word the MATCH excludes.
            if !isNegated, let term = proto.exactTerm, seen.insert(term).inserted {
                exactTerms.append(term)
            }
        }
        return ParsedQuery(expression: expression.text, exactTerms: exactTerms,
                           operands: operands, droppedOperands: droppedOperands,
                           isApproximate: isApproximate)
    }

    /// One searchable unit as harvested, before the tree around it settles its polarity.
    ///
    /// Polarity cannot be read off the token: `korea` in `NOT (war OR korea)` carries no
    /// mark of its own, and whether a mark applies at all depends on what it reaches. So
    /// the harvest records only what the operand *is*, and `parseDetailed` decides whether
    /// it is excluded — and whether the expression applies it at all — once the tree is
    /// complete.
    private struct ProtoOperand {
        /// The operand's own text, without marks — becomes `ParsedOperand.text`.
        var text: String
        /// The operand's positive FTS5 fragment, column prefix included, never `NOT`.
        var core: String
        /// The public shape of the operand.
        var kind: ParsedOperand.Kind
        /// Whether the researcher typed the `=` sigil on it.
        var isExact: Bool
        /// The literal word a positive, applied occurrence post-filters on, or `nil` when
        /// the sigil is absent or cannot apply.
        var exactTerm: String?
        /// Where the operand came from.
        var source: ParsedOperand.Source = .typed
    }

    /// Everything `buildNode` gathers on its way down, besides the tree itself.
    ///
    /// One value rather than several `inout` parameters because the recursion threads it
    /// through every group. A leaf refers to its operand by index into `operands`.
    private struct Harvest {
        /// Every operand the query rendered, in the order typed.
        var operands: [ProtoOperand] = []
    }

    // MARK: - Boolean Tree

    /// The token for a dash attached to an opening parenthesis, which negates the group it
    /// opens exactly as `NOT (` does.
    ///
    /// `tokenize` emits it only for a dash that begins a token, so neither `cold-(war)`
    /// (the word `cold-` then a group) nor a detached `- (` ever produces it.
    private static let attachedDashGroup = "-("

    /// The query as a boolean tree, before anything is rendered.
    ///
    /// `-korea` and `NOT korea` both become `.not(.leaf(korea))`, which is what makes the
    /// two spellings interchangeable in every position. Rendering from a tree rather than
    /// splicing tokens is what guarantees valid FTS5: its `NOT` is strictly binary, so the
    /// text has to be built knowing what sits on its left.
    private indirect enum Node {
        /// A positive rendered operand, or a demoted operator literal when `operand` is `nil`.
        case leaf(String, operand: Int?)
        /// A negation — from `-`, `NOT`, or a dash attached to a group.
        case not(Node)
        /// A parenthesised group, kept so the rendered text keeps the researcher's parentheses.
        case group(Node)
        /// An AND-run: the members between two surviving `OR`s at one nesting level.
        case and([Node])
        /// Two or more AND-runs joined by `OR`.
        case or([Node])
        /// The query that runs: the typed query and each structured field, conjoined. Always
        /// the root, and never inside anything else.
        case parts([Node])
        /// A positive expression rendered outside this parser — `FTS5Query`'s keyword
        /// fragment — carried as one opaque operand.
        case opaque(String)
    }

    /// The structured fields as parts of the query, harvested after the typed operands.
    ///
    /// Sanitised exactly as `FTS5Query` always sanitised them, so a restored saved search
    /// renders the bytes it rendered before: the phrase spans all columns, the prefix carries
    /// the column prefix, and an excluded term carries none.
    private static func structuredParts(
        _ structured: StructuredQueryParts, columnPrefix: String, into harvest: inout Harvest
    ) -> [Node] {
        var parts: [Node] = []
        func leaf(_ proto: ProtoOperand) -> Node {
            harvest.operands.append(proto)
            return .leaf(proto.core, operand: harvest.operands.count - 1)
        }
        if let raw = structured.phrase, let phrase = stemPhrase(raw) {
            parts.append(leaf(ProtoOperand(text: phrase, core: "\"\(phrase)\"", kind: .phrase,
                                           isExact: false, exactTerm: nil, source: .structured)))
        }
        if let raw = structured.prefixWildcard {
            let prefix = sanitizeBareToken(raw)
            if !prefix.isEmpty {
                parts.append(leaf(ProtoOperand(text: prefix + "*", core: columnPrefix + "\"\(prefix)\"*",
                                               kind: .prefix, isExact: false, exactTerm: nil,
                                               source: .structured)))
            }
        }
        for raw in structured.excludedTerms {
            let term = sanitizeBareToken(raw).lowercased()
            guard !term.isEmpty else { continue }
            parts.append(.not(leaf(ProtoOperand(text: term, core: "\"\(term)\"",
                                                kind: term.contains(" ") ? .phrase : .word,
                                                isExact: false, exactTerm: nil, source: .structured))))
        }
        return parts
    }

    /// `FTS5Query`'s expression: an already-rendered keyword fragment, if any, and the
    /// structured fields, combined by the same rule and anchoring as a parsed query.
    ///
    /// The fragment is one opaque, always-positive part, so this reproduces `FTS5Query` 2.2's
    /// join byte for byte — and, for the same reason, cannot see a complement the fragment's own
    /// parse left out. `nil` when there is no positive part. Used only by `FTS5Query`.
    static func combine(renderedKeywords: String?, structured: StructuredQueryParts,
                        columnPrefix: String) -> String? {
        var harvest = Harvest()
        var parts: [Node] = []
        if let renderedKeywords, !renderedKeywords.isEmpty { parts.append(.opaque(renderedKeywords)) }
        parts += structuredParts(structured, columnPrefix: columnPrefix, into: &harvest)
        guard !parts.isEmpty else { return nil }
        var dropped = Set<Int>()
        return anchored(.parts(parts), dropped: &dropped)?.text
    }

    /// One position in a nesting level's item stream, before its operators are resolved.
    private enum Item {
        /// Something that can be an operand: a leaf, a negated leaf, or a group.
        case node(Node)
        /// An operator keyword not yet checked for something to bind.
        case op(Operator)
    }

    /// Builds the boolean tree for a flat token sequence — which may contain balanced
    /// `(...)` groups at any depth — or `nil` when it carries nothing to build.
    ///
    /// The scan is the historical left-to-right one: `NEAR(...)` first, then balanced
    /// groups (recursing into this same function), then ordinary tokens through
    /// `classify`. Every operand is harvested in typed order and its leaf points back at it
    /// by index.
    ///
    /// Degradation is graceful by construction: an unmatched `(` or stray `)` never finds a
    /// partner in `matchingGroup`, falls through to `classify`, sanitises to nothing
    /// (parens are structural punctuation to `sanitizeBareToken`), and is silently
    /// dropped — exactly like any other punctuation-only token. A group that yields no
    /// node at all — `()`, `(   )`, a group of punctuation — is likewise dropped in its
    /// entirety. A group of only exclusions is a node, and keeps its meaning.
    private static func buildNode(
        _ tokens: [String], columnPrefix: String, into harvest: inout Harvest
    ) -> Node? {
        var items: [Item] = []
        var index = 0
        while index < tokens.count {
            let rawToken = tokens[index]

            // `NEAR(...)` is recognised before ordinary grouping, because its parentheses
            // are the operator's own argument list rather than a boolean group — the two
            // are spelled identically and only the preceding keyword distinguishes them.
            if let near = nearOperator(rawToken),
               index + 1 < tokens.count, tokens[index + 1] == "(",
               let group = matchingGroup(in: tokens, openAt: index + 1) {
                if let rendered = renderNear(inner: group.inner,
                                             aliasDistance: near.aliasDistance,
                                             columnPrefix: columnPrefix) {
                    harvest.operands.append(ProtoOperand(
                        text: (["NEAR("] + group.inner + [")"]).joined(separator: " "),
                        core: rendered, kind: .proximity, isExact: false, exactTerm: nil))
                    items.append(.node(.leaf(rendered, operand: harvest.operands.count - 1)))
                    index = group.closeIndex + 1
                    continue
                }
                // Malformed NEAR — an operand FTS5 forbids inside one (a boolean, a
                // negation, a nested group), or a distance that is not a bare
                // non-negative integer. Drop *only* the `NEAR` keyword and let the very
                // next iteration render `(...)` as an ordinary boolean group, so the
                // words the user typed are still searched. This is the established
                // graceful-degradation contract: never emit invalid FTS5, never silently
                // return nothing.
                index += 1
                continue
            }

            // A group, opened by `(` or by an attached `-(`. The attached dash is a NOT
            // before the group, emitted only when the group builds: before `()` it stays the
            // punctuation it always was, rather than stranding a NOT that
            // `demoteOrphanedOperators` would turn into a search for the word "not".
            if rawToken == "(" || rawToken == attachedDashGroup,
               let group = matchingGroup(in: tokens, openAt: index) {
                if let inner = buildNode(group.inner, columnPrefix: columnPrefix, into: &harvest) {
                    if rawToken == attachedDashGroup { items.append(.op(.not)) }
                    items.append(.node(.group(inner)))
                }
                index = group.closeIndex + 1
                continue
            }

            if let classified = classify(rawToken) {
                switch classified {
                case .op(let kind):
                    items.append(.op(kind))
                case .operand(let operand):
                    // Negation is structure, not text: the leaf holds the positive core, and
                    // the tree decides where — and whether — a `NOT` is rendered.
                    var positive = operand
                    positive.negated = false
                    if let core = render(positive, columnPrefix: columnPrefix) {
                        var term: String?
                        if operand.isExact, case .word(let raw) = operand.kind {
                            term = exactTerm(from: raw)
                        }
                        harvest.operands.append(ProtoOperand(
                            text: operand.surfaceText, core: core,
                            kind: operand.kind.parsedKind, isExact: operand.isExact,
                            exactTerm: term))
                        let leaf = Node.leaf(core, operand: harvest.operands.count - 1)
                        items.append(.node(operand.negated ? .not(leaf) : leaf))
                    }
                }
            }
            index += 1
        }

        demoteOrphanedOperators(in: &items, columnPrefix: columnPrefix)
        return structure(items)
    }

    /// Walks one nesting level's items left to right, converting any `AND`/`OR`/`NOT` that
    /// has nothing to bind into a literal leaf for that same word — stemmed and scoped by
    /// `columnPrefix`, like any other bare term, so a scoped `-not` removes a demoted `NOT` in
    /// its own scope and a scoped query never searches the word outside it.
    ///
    /// An `AND` or `OR` binds when a node sits on its left and, on its right, a node or a
    /// chain of `NOT`s ending in one — so `cold AND NOT korea` keeps both keywords as
    /// operators. A `NOT` binds when the chain of `NOT`s starting at it ends in a node.
    /// Everything that survives can therefore be structured (orphans such as `"cold OR"`,
    /// `"OR cold"`, `"cold OR OR war"` or a bare `"NOT"` become words). Resolution is in
    /// place and left to right, so chains of misplaced operators (`"cold OR AND war"`)
    /// resolve consistently: each candidate sees the earlier ones already resolved.
    private static func demoteOrphanedOperators(in items: inout [Item], columnPrefix: String) {
        func isNode(_ index: Int) -> Bool {
            guard items.indices.contains(index), case .node = items[index] else { return false }
            return true
        }
        func isNot(_ index: Int) -> Bool {
            guard items.indices.contains(index), case .op(.not) = items[index] else { return false }
            return true
        }
        func startsUnary(_ index: Int) -> Bool {
            var cursor = index
            while isNot(cursor) { cursor += 1 }
            return isNode(cursor)
        }

        for index in items.indices {
            guard case .op(let kind) = items[index] else { continue }
            let isValidPlacement: Bool
            switch kind {
            case .and, .or:
                isValidPlacement = isNode(index - 1) && startsUnary(index + 1)
            case .not:
                isValidPlacement = startsUnary(index)
            }
            guard !isValidPlacement else { continue }

            let literal = kind.fts5Keyword.lowercased()
            guard let word = stemBareWord(literal) else { continue }
            items[index] = .node(.leaf(columnPrefix + "\"\(word)\"", operand: nil))
        }
    }

    /// Folds one nesting level's resolved items into a node: AND-runs split at each `OR`,
    /// with every run of `NOT`s applied to the member it reaches.
    ///
    /// `AND` needs no node of its own, because every member of a run is conjoined anyway.
    /// Negation marks count once, and a negation reaching a member with no positive term is
    /// not applied at all — `NOT -korea` is `-korea`, and `NOT (-korea)` is `(-korea)` —
    /// since complementing a pure exclusion would ask FTS5 for a universal set it lacks.
    private static func structure(_ items: [Item]) -> Node? {
        var disjuncts: [Node] = []
        var run: [Node] = []
        var pendingNots = 0
        for item in items {
            switch item {
            case .op(.or):
                if !run.isEmpty { disjuncts.append(run.count == 1 ? run[0] : .and(run)) }
                run = []
            case .op(.and):
                continue
            case .op(.not):
                pendingNots += 1
            case .node(let node):
                run.append(pendingNots > 0 && hasPositiveLeaf(node) ? .not(node) : node)
                pendingNots = 0
            }
        }
        if !run.isEmpty { disjuncts.append(run.count == 1 ? run[0] : .and(run)) }
        guard !disjuncts.isEmpty else { return nil }
        return disjuncts.count == 1 ? disjuncts[0] : .or(disjuncts)
    }

    // MARK: - Signed Rendering

    /// How loosely a rendered expression's top-level operator binds, which decides where
    /// parentheses are needed. FTS5 binds `NOT` tighter than `AND`, and `AND` tighter than
    /// `OR`.
    private enum Precedence {
        /// The top level is an `OR`.
        case or
        /// The top level is an `AND`.
        case and
        /// The top level is a binary `NOT`.
        case not
        /// A single operand or a parenthesised group.
        case atom
    }

    /// Rendered FTS5 text, the precedence of its top-level operator, and what its operands alone prove about
    /// the documents it matches.
    ///
    /// The proof is what lets `parseDetailed` refuse an approximation that can match nothing (6.1). It is built
    /// alongside the text by the same functions — `operand`, `parenthesized`, `conjoin`, `exclude`, `disjoin` and
    /// `combineParts` — and is sound but not complete: `isEmpty` is `true` only when the expression matches no
    /// document in any corpus, and `false` says nothing.
    private struct Expr {
        /// The FTS5 text.
        var text: String
        /// How loosely `text`'s top-level operator binds.
        var precedence: Precedence
        /// Operands every document the expression matches also matches.
        var required: Set<OperandIdentity> = []
        /// Operands any one of which a document need only match to match the expression.
        var sufficient: Set<OperandIdentity> = []
        /// Operands no document the expression matches can match.
        var forbidden: Set<OperandIdentity> = []
        /// Whether the expression provably matches no document.
        var isEmpty = false

        /// This expression with `isEmpty` set when an operand it requires is covered by one it forbids.
        func settled() -> Expr {
            var result = self
            result.isEmpty = isEmpty || required.contains { anchor in forbidden.contains { $0.covers(anchor) } }
            return result
        }
    }

    /// A rendered operand as the emptiness proof compares it: its core, and the column prefix in front of it.
    ///
    /// Two operands with the same core and prefix match the same documents, and a core with no prefix spans
    /// every column, so it matches every document the same core matches under any prefix. Nothing else is
    /// compared: a phrase is not taken to contain its words, nor a prefix the words it begins, because stemming
    /// happens inside SQLite and makes neither claim provable here.
    private struct OperandIdentity: Hashable {
        /// The `{columns}:` prefix, or empty when the operand spans every column.
        let scope: String
        /// The operand's text after the prefix.
        let core: String

        /// The identity of an operand rendered as `text`.
        init(rendered text: String) {
            if text.hasPrefix("{"), let close = text.range(of: "}:") {
                scope = String(text[..<close.upperBound])
                core = String(text[close.upperBound...])
            } else {
                scope = ""
                core = text
            }
        }

        /// Whether every document matching `anchor` matches this operand: the same core, in a scope spanning
        /// the anchor's.
        func covers(_ anchor: OperandIdentity) -> Bool {
            core == anchor.core && (scope.isEmpty || scope == anchor.scope)
        }
    }

    /// One rendered operand, which requires and suffices for itself.
    private static func operand(_ text: String) -> Expr {
        let identity = OperandIdentity(rendered: text)
        return Expr(text: text, precedence: .atom, required: [identity], sufficient: [identity])
    }

    /// `expression` in parentheses, which change its precedence and nothing it matches.
    private static func parenthesized(_ expression: Expr) -> Expr {
        var grouped = expression
        grouped.text = "(\(expression.text))"
        grouped.precedence = .atom
        return grouped
    }

    /// An exact rendering of a node's meaning: the documents an expression matches, or
    /// their complement.
    ///
    /// FTS5 cannot search a complement on its own, so a `.lacking` value is only useful
    /// once something positive sits beside it to be excluded from.
    private enum Signed {
        /// The documents the expression matches.
        case matching(Expr)
        /// The documents the expression does not match.
        case lacking(Expr)
    }

    /// `expression` as the operand of a `NOT`: parenthesised unless it is already atomic.
    private static func atomText(_ expression: Expr) -> String {
        expression.precedence == .atom ? expression.text : "(\(expression.text))"
    }

    /// `expression` as an operand of `AND`, or the left operand of `NOT`: parenthesised
    /// only when it is an `OR`, the one operator binding more loosely than both.
    private static func conjunctText(_ expression: Expr) -> String {
        expression.precedence == .or ? "(\(expression.text))" : expression.text
    }

    /// The documents both `left` and `right` match.
    private static func conjoin(_ left: Expr, _ right: Expr) -> Expr {
        Expr(text: "\(conjunctText(left)) AND \(conjunctText(right))", precedence: .and,
             required: left.required.union(right.required),
             sufficient: left.sufficient.intersection(right.sufficient),
             forbidden: left.forbidden.union(right.forbidden),
             isEmpty: left.isEmpty || right.isEmpty).settled()
    }

    /// The documents `kept` matches less those `excluded` matches.
    ///
    /// When `kept` is an `AND`, FTS5 reads `a AND b NOT x` as `a AND (b NOT x)`, which
    /// selects the same documents as `(a AND b) NOT x`; the result keeps `AND` precedence
    /// because that is its top-level operator.
    ///
    /// Every operand sufficient for `excluded` is forbidden to the result, which is how an exclusion that removes
    /// an operand the kept side requires is proved to leave nothing.
    private static func exclude(_ kept: Expr, _ excluded: Expr) -> Expr {
        Expr(text: "\(conjunctText(kept)) NOT \(atomText(excluded))",
             precedence: kept.precedence == .and ? .and : .not,
             required: kept.required, forbidden: kept.forbidden.union(excluded.sufficient),
             isEmpty: kept.isEmpty).settled()
    }

    /// The documents any of `parts` matches. `OR` binds loosest, so no part needs
    /// parentheses.
    ///
    /// Empty only when every part is: an empty alternative beside one that matches leaves the whole searchable.
    private static func disjoin(_ parts: [Expr]) -> Expr {
        guard parts.count > 1 else { return parts[0] }
        var joined = parts[0]
        joined.text = parts.map(\.text).joined(separator: " OR ")
        joined.precedence = .or
        for part in parts.dropFirst() {
            joined.required.formIntersection(part.required)
            joined.sufficient.formUnion(part.sufficient)
            joined.forbidden.formIntersection(part.forbidden)
            joined.isEmpty = joined.isEmpty && part.isEmpty
        }
        return joined
    }

    /// The exact meaning of `node`, or `nil` when it contains nothing to render.
    ///
    /// An AND-run with a positive member renders exactly: the first positive member leads
    /// and every other member follows in typed order — conjoined when positive, excluded
    /// when negative. That is the hoist that moves `-korea cold` to `"cold" NOT "korea"`,
    /// and it never crosses an `OR` because runs are split at every `OR` first. A run with
    /// no positive member is the complement of the union of what it excludes. An `OR` with
    /// complement alternatives is, by De Morgan's law, the complement of their conjunction
    /// less the positive alternatives — exact, but searchable only once something positive
    /// anchors it.
    private static func exactMeaning(of node: Node) -> Signed? {
        switch node {
        case .leaf(let text, _):
            return .matching(operand(text))
        case .opaque(let text):
            // Precedence unknown, so it is parenthesised wherever anything binds to it unless it
            // is one operand — the rule `FTS5Query` has always used for its parts.
            return .matching(Expr(text: text, precedence: FTS5Query.isSingleOperand(text) ? .atom : .or))
        case .parts(let members):
            var positives: [Expr] = []
            var negatives: [Expr] = []
            for signed in members.compactMap(exactMeaning(of:)) {
                switch signed {
                case .matching(let expression): positives.append(expression)
                case .lacking(let expression): negatives.append(expression)
                }
            }
            guard !positives.isEmpty else {
                return negatives.isEmpty ? nil : .lacking(disjoin(negatives))
            }
            return .matching(combineParts(positives, negatives))
        case .not(let inner):
            switch exactMeaning(of: inner) {
            case .matching(let expression)?: return .lacking(expression)
            case .lacking(let expression)?: return .matching(expression)
            case nil: return nil
            }
        case .group(let inner):
            switch exactMeaning(of: inner) {
            case .matching(let expression)?:
                return .matching(parenthesized(expression))
            case .lacking(let expression)?: return .lacking(expression)
            case nil: return nil
            }
        case .and(let members):
            let signed = members.compactMap(exactMeaning(of:))
            guard !signed.isEmpty else { return nil }
            guard let first = signed.firstIndex(where: {
                if case .matching = $0 { return true }
                return false
            }), case .matching(var accumulated) = signed[first] else {
                return .lacking(disjoin(signed.compactMap {
                    if case .lacking(let expression) = $0 { return expression }
                    return nil
                }))
            }
            for member in signed[..<first] + signed[(first + 1)...] {
                switch member {
                case .matching(let expression): accumulated = conjoin(accumulated, expression)
                case .lacking(let expression): accumulated = exclude(accumulated, expression)
                }
            }
            return .matching(accumulated)
        case .or(let disjuncts):
            var matching: [Expr] = []
            var lacking: [Expr] = []
            for signed in disjuncts.compactMap(exactMeaning(of:)) {
                switch signed {
                case .matching(let expression): matching.append(expression)
                case .lacking(let expression): lacking.append(expression)
                }
            }
            guard var excluded = lacking.first else {
                return matching.isEmpty ? nil : .matching(disjoin(matching))
            }
            for expression in lacking.dropFirst() { excluded = conjoin(excluded, expression) }
            guard !matching.isEmpty else { return .lacking(excluded) }
            return .lacking(exclude(excluded, disjoin(matching)))
        }
    }

    /// The largest part of `node`'s meaning FTS5 can search, or `nil` when there is none.
    ///
    /// When `node` renders exactly as `.matching`, that is the answer. Otherwise — which
    /// can only happen at the root, beneath root-level groups, or inside a complement whose
    /// negation is being pushed inward, since an enclosing positive member anchors anything
    /// exactly — a negation of anything but a lone leaf is pushed inward by
    /// `complement(of:)` and anchored again, so the positive terms inside it are kept; an
    /// `OR` alternative that still cannot be anchored is left out together with its `OR`,
    /// and its operands are added to `dropped` so the inspector can report them as not
    /// applied; and a root AND-run of complements, or the root conjunction of typed and
    /// structured parts, keeps the members it can anchor and excludes the rest exactly. The
    /// result selects a subset of what the query means, never a superset.
    ///
    /// By induction the result is `nil` exactly when `node` has no leaf that is positive after
    /// the negations above it. So every operand added to `dropped` is negated, nothing is
    /// dropped beside a structured phrase or prefix, and no applied operand is ever dropped.
    ///
    /// A result can still match nothing: an anchor pushing inward exposes can be removed in full
    /// by an exclusion beside it. Its proof says so (`Expr.isEmpty`), and `parseDetailed` refuses it
    /// at the root rather than here, so the invariant above holds and an empty alternative beside
    /// one that matches changes nothing about the render.
    private static func anchored(_ node: Node, dropped: inout Set<Int>) -> Expr? {
        guard let signed = exactMeaning(of: node) else { return nil }
        if case .matching(let expression) = signed { return expression }
        switch node {
        case .leaf, .opaque:
            return nil
        case .not(let inner):
            // A complement of something containing a positive term can still hold an anchor:
            // push the negation inward and anchor what that exposes, so only the alternatives
            // that really are made only of exclusions are left out.
            if case .leaf = inner { return nil }
            return anchored(complement(of: inner), dropped: &dropped)
        case .parts(let members):
            var positives: [Expr] = []
            var negatives: [Expr] = []
            var local = Set<Int>()
            for member in members {
                var memberDropped = Set<Int>()
                if let expression = anchored(member, dropped: &memberDropped) {
                    positives.append(expression)
                    local.formUnion(memberDropped)
                } else if case .lacking(let expression)? = exactMeaning(of: member) {
                    negatives.append(expression)
                }
            }
            guard !positives.isEmpty else { return nil }
            dropped.formUnion(local)
            return combineParts(positives, negatives)
        case .group(let inner):
            return anchored(inner, dropped: &dropped).map(parenthesized)
        case .or(let disjuncts):
            var kept: [Expr] = []
            for disjunct in disjuncts {
                var local = Set<Int>()
                if let expression = anchored(disjunct, dropped: &local) {
                    kept.append(expression)
                    dropped.formUnion(local)
                } else {
                    dropped.formUnion(leaves(of: disjunct))
                }
            }
            return kept.isEmpty ? nil : disjoin(kept)
        case .and(let members):
            var approximations: [Expr] = []
            var exclusions: [Expr] = []
            var local = Set<Int>()
            for member in members {
                var memberDropped = Set<Int>()
                if let expression = anchored(member, dropped: &memberDropped) {
                    approximations.append(expression)
                    local.formUnion(memberDropped)
                } else if case .lacking(let expression)? = exactMeaning(of: member) {
                    exclusions.append(expression)
                }
            }
            guard var accumulated = approximations.first else { return nil }
            for expression in approximations.dropFirst() {
                accumulated = conjoin(accumulated, expression)
            }
            for expression in exclusions { accumulated = exclude(accumulated, expression) }
            dropped.formUnion(local)
            return accumulated
        }
    }

    /// `node`'s complement with the negation pushed onto its leaves by De Morgan's law.
    ///
    /// Group parentheses are not kept: they preserved the typed grouping of text this rewrite
    /// replaces, and `Expr` precedence parenthesises wherever FTS5 needs it.
    private static func complement(of node: Node) -> Node {
        switch node {
        case .leaf, .opaque: return .not(node)
        case .not(let inner): return inner
        case .group(let inner): return complement(of: inner)
        case .and(let members), .parts(let members): return .or(members.map(complement(of:)))
        case .or(let disjuncts): return .and(disjuncts.map(complement(of:)))
        }
    }

    /// The root conjunction's text: the positive parts joined by `AND`, each parenthesised
    /// unless atomic, then every excluded part as a `NOT` applied to the whole positive.
    ///
    /// A lone positive part with nothing to exclude is emitted exactly as built, which is
    /// what keeps a typed query with no structured fields byte-identical. The proof is `conjoin`'s over the
    /// positive parts, then `exclude`'s for each excluded part.
    private static func combineParts(_ positives: [Expr], _ negatives: [Expr]) -> Expr {
        func partText(_ expression: Expr) -> String {
            expression.precedence == .atom ? expression.text : "(\(expression.text))"
        }
        var positive = positives[0]
        if positives.count > 1 {
            positive.text = positives.map(partText).joined(separator: " AND ")
            positive.precedence = .and
            for part in positives.dropFirst() {
                positive.required.formUnion(part.required)
                positive.sufficient.formIntersection(part.sufficient)
                positive.forbidden.formUnion(part.forbidden)
                positive.isEmpty = positive.isEmpty || part.isEmpty
            }
            positive = positive.settled()
        }
        guard !negatives.isEmpty else { return positive }
        let kept = positives.count == 1 ? partText(positive) : "(\(positive.text))"
        return Expr(text: kept + negatives.map { " NOT \(atomText($0))" }.joined(), precedence: .not,
                    required: positive.required,
                    forbidden: negatives.reduce(positive.forbidden) { $0.union($1.sufficient) },
                    isEmpty: positive.isEmpty).settled()
    }

    /// Whether `node` contains a leaf that is positive after the negations above it —
    /// what decides whether a negation reaching `node` is applied. A demoted operator
    /// literal counts: it is a word the expression searches for.
    private static func hasPositiveLeaf(_ node: Node, negated: Bool = false) -> Bool {
        switch node {
        case .leaf, .opaque: return !negated
        case .not(let inner): return hasPositiveLeaf(inner, negated: !negated)
        case .group(let inner): return hasPositiveLeaf(inner, negated: negated)
        case .and(let members), .or(let members), .parts(let members):
            return members.contains { hasPositiveLeaf($0, negated: negated) }
        }
    }

    /// The harvested operand indices beneath `node`, in tree order.
    private static func leaves(of node: Node) -> [Int] {
        switch node {
        case .leaf(_, let operand): return operand.map { [$0] } ?? []
        case .opaque: return []
        case .not(let inner), .group(let inner): return leaves(of: inner)
        case .and(let members), .or(let members), .parts(let members): return members.flatMap(leaves(of:))
        }
    }

    /// Records, for each harvested operand beneath `node`, whether an odd number of the
    /// negations in the tree sit above it — its effective polarity.
    private static func polarity(of node: Node, negated: Bool, into map: inout [Int: Bool]) {
        switch node {
        case .leaf(_, let operand):
            if let operand { map[operand] = negated }
        case .opaque:
            break
        case .not(let inner):
            polarity(of: inner, negated: !negated, into: &map)
        case .group(let inner):
            polarity(of: inner, negated: negated, into: &map)
        case .and(let members), .or(let members), .parts(let members):
            for member in members { polarity(of: member, negated: negated, into: &map) }
        }
    }

    /// Scans forward from `tokens[openAt]` (which must open a group: `"("`, or the
    /// attached dash `"-("`) for its balanced closing `")"`, tracking nested-paren depth
    /// so inner groups don't terminate the search early — e.g. for `(a (b) c) d`, the
    /// outer group's contents are correctly identified as `a (b) c`, not just `a (b`.
    /// A `-(` opens a level exactly as `(` does, because it carries the same parenthesis.
    ///
    /// Returns the inner token slice (enclosing parens excluded) and the index of the
    /// matching close, or `nil` if `tokens` never returns to depth zero — i.e. an
    /// unmatched `(` that the caller should treat as an ordinary literal token.
    private static func matchingGroup(
        in tokens: [String], openAt: Int
    ) -> (inner: [String], closeIndex: Int)? {
        var depth = 0
        var i = openAt
        while i < tokens.count {
            if tokens[i] == "(" || tokens[i] == attachedDashGroup {
                depth += 1
            } else if tokens[i] == ")" {
                depth -= 1
                if depth == 0 {
                    return (Array(tokens[(openAt + 1)..<i]), i)
                }
            }
            i += 1
        }
        return nil
    }

    // MARK: - NEAR

    /// FTS5's own default proximity when `NEAR(a b)` omits the distance.
    ///
    /// Rendered explicitly rather than left implicit: the Query Inspector shows the
    /// expression that went to SQLite, and a researcher copying it into a method
    /// appendix should see the distance that actually applied.
    private static let defaultNearDistance = 10

    /// A recognised `NEAR` operator keyword, with the distance if it was spelled in the
    /// FTS3/4 `NEAR/N` alias form.
    private struct NearOperator {
        /// The digits after `NEAR/`, or `nil` for the canonical `NEAR(a b, N)` spelling.
        var aliasDistance: String?
    }

    /// Recognises the `NEAR` keyword, in any case, in either accepted spelling.
    ///
    /// Two spellings are accepted on input and **one** is emitted. The canonical
    /// `NEAR(a b, N)` is FTS5's own form and the one published method appendices use, so
    /// it is what a researcher pastes. `NEAR/N(a b)` is SQLite's older FTS3/4 spelling,
    /// accepted as a convenience alias — but note it is **not valid FTS5 at all**
    /// (`NEAR/5(a b)` and `a NEAR/5 b` are both hard syntax errors against a real FTS5
    /// table), so this is a genuine translation, not a pass-through. The infix
    /// `a NEAR/5 b` form is deliberately *not* accepted: it would change operator arity
    /// in the token stream for a spelling the engine never supported.
    ///
    /// Case-insensitive on input, matching this parser's `AND`/`OR`/`NOT` handling —
    /// but FTS5 requires the keyword uppercase, so `renderNear` always emits `NEAR`.
    private static func nearOperator(_ token: String) -> NearOperator? {
        let upper = token.uppercased()
        if upper == "NEAR" { return NearOperator(aliasDistance: nil) }
        guard upper.hasPrefix("NEAR/") else { return nil }
        let digits = String(upper.dropFirst("NEAR/".count))
        guard isNearDistance(digits) else { return nil }
        return NearOperator(aliasDistance: digits)
    }

    /// Whether `text` is a distance FTS5 will accept: a non-empty run of ASCII digits.
    ///
    /// Deliberately strict, and verified against a real FTS5 table — SQLite rejects a
    /// negative (`, -1`), a decimal (`, 3.5`), a signed (`, +5`), an empty (`, )`) and a
    /// non-numeric (`, x`) distance outright. `isNumber` alone would also admit
    /// non-ASCII digit scalars, which FTS5 does not parse, so the ASCII check is load-
    /// bearing rather than decorative.
    private static func isNearDistance(_ text: String) -> Bool {
        !text.isEmpty && text.allSatisfy { $0.isASCII && $0.isNumber }
    }

    /// Renders `NEAR(...)`'s inner tokens into a complete FTS5 `NEAR` expression, or
    /// `nil` when the contents are something FTS5 forbids inside one.
    ///
    /// ## What FTS5 permits inside `NEAR`, verified against a real table
    /// Operands may be bare words, phrases, or prefix terms — including this parser's
    /// own quoted-prefix render form (`"milit"*`), which executes cleanly. One operand
    /// is accepted (degenerate but valid); three or more are fine. Everything else is a
    /// syntax error and must therefore be rejected here rather than handed to SQLite:
    /// booleans (`NEAR(a OR b, 5)`), negation, nested groups (`NEAR((a b), 5)`), and
    /// column filters on the inner operands (`NEAR({body_text}: a b, 5)`).
    ///
    /// ## Column scoping wraps the whole operator
    /// The prefix goes in front of `NEAR(`, never on the inner operands — `{body_text}:
    /// NEAR(a b, 5)` is valid and `NEAR({body_text}: a b, 5)` is not. This is the one
    /// place the parser's usual per-operand prefixing cannot apply, and it has a visible
    /// consequence: a phrase inside a `NEAR` **is** column-scoped, whereas a bare phrase
    /// elsewhere deliberately spans all columns (see `render`). FTS5 offers no way to
    /// express the latter inside a `NEAR`, so the scoping is the honest reading of what
    /// the user asked for.
    private static func renderNear(
        inner: [String], aliasDistance: String?, columnPrefix: String
    ) -> String? {
        let operandTokens: [String]
        let distance: String

        if let aliasDistance {
            // `NEAR/N(...)` — a comma inside would then be a second, conflicting
            // distance. Reject rather than silently preferring one.
            guard !inner.contains(where: { $0.contains(",") }) else { return nil }
            operandTokens = inner
            distance = aliasDistance
        } else {
            guard let split = splitTrailingDistance(inner) else { return nil }
            operandTokens = split.operands
            distance = split.distance ?? String(defaultNearDistance)
        }

        var rendered: [String] = []
        for token in operandTokens {
            // A paren surviving into the operand list means a nested group, which FTS5
            // rejects inside NEAR.
            guard token != "(", token != ")" else { return nil }
            guard let classified = classify(token) else { continue }
            // An operator keyword inside NEAR is a syntax error, not a search word:
            // rejecting sends the whole thing down the degradation path, where the
            // user's words are still searched as an ordinary boolean group.
            guard case .operand(let operand) = classified else { return nil }
            guard !operand.negated else { return nil }
            // Column prefix is applied to the whole NEAR below, never per operand.
            guard let piece = render(operand, columnPrefix: "") else { continue }
            rendered.append(piece)
        }
        guard !rendered.isEmpty else { return nil }

        return "\(columnPrefix)NEAR(\(rendered.joined(separator: " ")), \(distance))"
    }

    /// Splits `NEAR`'s inner tokens at its trailing `, N`, returning the operand tokens
    /// and the distance digits (`nil` distance when none was given).
    ///
    /// Returns `nil` — meaning "malformed, degrade" — when a distance position exists
    /// but does not hold a valid distance, matching what FTS5 itself rejects.
    ///
    /// The scan is quote-aware for a reason that is easy to miss: `tokenize` does not
    /// split on commas, so a comma inside a phrase (`NEAR("cold, war" europe)`) is
    /// indistinguishable from the distance separator by position alone. Taking the last
    /// comma naively would read `war" europe` as the distance and reject a perfectly
    /// good query. Commas outside quotes that are *not* the separator (`NEAR(a, b, 5)`)
    /// are dropped from the operand text rather than surviving into a rendered operand
    /// as `"a,"`.
    private static func splitTrailingDistance(
        _ tokens: [String]
    ) -> (operands: [String], distance: String?)? {
        let joined = tokens.joined(separator: " ")
        var segments: [String] = []
        var current = ""
        var inQuotes = false
        for character in joined {
            if character == "\"" {
                inQuotes.toggle()
                current.append(character)
            } else if character == ",", !inQuotes {
                segments.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        segments.append(current)

        guard segments.count > 1 else { return (tokens, nil) }

        let tail = segments.removeLast().trimmingCharacters(in: .whitespacesAndNewlines)
        guard isNearDistance(tail) else { return nil }
        return (tokenize(segments.joined(separator: " ")), tail)
    }

    // MARK: - Tokenization

    /// Splits `raw` on whitespace, treating `"..."` spans (including unterminated ones,
    /// which run to end-of-string) as single tokens so embedded spaces survive intact.
    private static func tokenize(_ raw: String) -> [String] {
        var tokens: [String] = []
        let chars = Array(raw)
        var i = 0
        while i < chars.count {
            if chars[i].isWhitespace {
                i += 1
                continue
            }
            if chars[i] == "\"" {
                var j = i + 1
                while j < chars.count, chars[j] != "\"" { j += 1 }
                let end = min(j, chars.count - 1)
                tokens.append(String(chars[i...end]))
                i = end + 1
            } else if chars[i] == "-", i + 1 < chars.count, chars[i + 1] == "\"" {
                // A "-" immediately followed by an opening quote — e.g.
                // `-"naval quarantine"` — must be consumed as a *single* token so
                // negation composes with phrases the same way it does with bare
                // words and wildcards. Without this branch the generic word-scan
                // below would stop at the first space inside the quotes, splitting
                // `-"naval quarantine"` into the two tokens `-"naval` and
                // `quarantine"` and silently breaking the negation.
                var j = i + 2
                while j < chars.count, chars[j] != "\"" { j += 1 }
                let end = min(j, chars.count - 1)
                tokens.append(String(chars[i...end]))
                i = end + 1
            } else if chars[i] == "-", i + 1 < chars.count, chars[i + 1] == "(" {
                // A "-" immediately followed by "(" — `-(korea OR vietnam)` — negates the
                // group exactly as `NOT (korea OR vietnam)` does, so it is kept as the one
                // token `-(`: `matchingGroup` counts it as an opener and `buildNode` reads
                // it as a NOT before the group. Without this branch the paren branch below
                // would split it into a bare "-" (punctuation, dropped) and a positive
                // group — the reading a DETACHED `- (` still gets.
                tokens.append(attachedDashGroup)
                i += 2
            } else if chars[i] == "(" || chars[i] == ")" {
                // Grouping parens are always emitted as their own single-character
                // tokens — even when butted directly against a word, e.g. `(aqaba`
                // or `tiran)` — so the recursive grouping pass in `buildNode`
                // recognises them regardless of spacing. Any that turn out to be
                // unmatched or otherwise unusable are mapped to whitespace by
                // `sanitizeBareToken` and silently dropped, same as today.
                tokens.append(String(chars[i]))
                i += 1
            } else {
                var j = i
                while j < chars.count, !chars[j].isWhitespace,
                      chars[j] != "(", chars[j] != ")" {
                    j += 1
                }
                tokens.append(String(chars[i..<j]))
                i = j
            }
        }
        return tokens
    }

    // MARK: - Classification

    /// A binary or unary boolean operator recognised inline. Only `OR` and `NOT` are
    /// ever rendered as literal FTS5 keywords; `AND` resolves to implicit juxtaposition.
    private enum Operator: Equatable {
        case and, or, not

        var fts5Keyword: String {
            switch self {
            case .and: return "AND"
            case .or:  return "OR"
            case .not: return "NOT"
            }
        }
    }

    private enum OperandKind {
        case word(String)
        case phrase(String)
        case wildcard(prefix: String)

        /// The public shape of this operand, for the inspector.
        var parsedKind: ParsedOperand.Kind {
            switch self {
            case .word: return .word
            case .phrase: return .phrase
            case .wildcard: return .prefix
            }
        }
    }

    private struct Operand {
        var negated: Bool
        /// Whether the researcher prefixed the term with `=`, asking for the literal word
        /// rather than everything sharing its stem.
        var isExact: Bool = false
        var kind: OperandKind

        /// The operand's own text, without the negation or exactness marks — what the
        /// inspector labels the pill with, and what a per-operand count re-searches.
        var surfaceText: String {
            switch kind {
            case .word(let w): return w
            case .phrase(let p): return p
            case .wildcard(let prefix): return prefix + "*"
            }
        }
    }

    private enum ClassifiedToken {
        case op(Operator)
        case operand(Operand)
    }

    /// Classifies one whitespace-delimited (or quote-delimited) raw token.
    ///
    /// Recognition order matters: a leading `-` is consumed first (so `-"phrase"` and
    /// `-word*` both negate correctly), then phrase / wildcard / bare-word in that order.
    /// Returns `nil` for tokens that carry no usable content (e.g. a bare `-`, `*`, `""`).
    private static func classify(_ token: String) -> ClassifiedToken? {
        // Operator keywords — recognised in any case (`and`, `And`, `AND` all act as
        // the operator), matching history.state.gov and most users' expectations. To
        // search for the literal word "and"/"or"/"not", quote it (`"and"`). An
        // operator that lacks the operand(s) it needs is demoted back to a literal of
        // that word by `demoteOrphanedOperators`, so this never produces invalid syntax.
        switch token.uppercased() {
        case "AND": return .op(.and)
        case "OR":  return .op(.or)
        case "NOT": return .op(.not)
        default: break
        }

        var text = token
        var negated = false
        if text.hasPrefix("-"), text.count > 1 {
            negated = true
            text = String(text.dropFirst())
        }
        // The exact-word sigil, consumed after negation so `-="word"` parses (and then
        // has its sigil ignored — see the operand site). Accepted both bare and quoted:
        // `=containment` and `="containment"`.
        var isExact = false
        if text.hasPrefix("="), text.count > 1 {
            isExact = true
            text = String(text.dropFirst())
            // `="word"` — unwrap the quotes so it classifies as a word, not a phrase.
            // A phrase is already positional; `=` adds nothing FTS5 has not done.
            if text.hasPrefix("\""), text.hasSuffix("\""), text.count > 1 {
                text = String(text.dropFirst().dropLast())
            } else if text.hasPrefix("\"") {
                text = String(text.dropFirst())
            }
            guard !text.isEmpty else { return nil }
        }
        guard !text.isEmpty else { return nil }

        if text.hasPrefix("\"") {
            var inner = String(text.dropFirst())
            if inner.hasSuffix("\"") { inner = String(inner.dropLast()) }
            let trimmed = inner.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            // A phrase is already an exact word sequence as far as FTS5 is concerned,
            // modulo stemming of each word; `=` on it is not supported and is dropped.
            return .operand(Operand(negated: negated, kind: .phrase(trimmed)))
        }

        if text.hasSuffix("*"), text.count > 1 {
            let prefix = String(text.dropLast())
            guard !prefix.isEmpty else { return nil }
            // `=negoti*` is a contradiction — a prefix search asks for many words. The
            // sigil is dropped and the wildcard wins.
            return .operand(Operand(negated: negated, kind: .wildcard(prefix: prefix)))
        }

        return .operand(Operand(negated: negated, isExact: isExact, kind: .word(text)))
    }

    /// The literal word an exact operand filters on, or `nil` when the sigil cannot
    /// apply.
    ///
    /// Returns `nil` for anything that is not exactly one index token — `="co-operate"`,
    /// `="U.S.S.R."`. Those have no single-word answer, and filtering on one fragment of
    /// what the researcher typed would be worse than ignoring the sigil. The query still
    /// runs stemmed, which is what it would have done without the `=`.
    private static func exactTerm(from raw: String) -> String? {
        let sanitized = sanitizeBareToken(raw)
        guard !sanitized.isEmpty, ExactWordMatcher.isSingleToken(sanitized) else { return nil }
        return sanitized
    }

    // MARK: - Rendering

    /// Renders a single operand to its FTS5 fragment (sanitised, quoted, column-scoped,
    /// and `NOT`-prefixed when negated). Returns `nil` when the operand sanitises to
    /// nothing usable (e.g. a phrase consisting only of punctuation).
    ///
    /// Every term is emitted as a double-quoted FTS5 string. Quoting matters now that
    /// terms are no longer reduced to their alphabetic core: characters like
    /// apostrophes and hyphens are not valid in FTS5 *barewords* (`don't` unquoted is
    /// a syntax error) but are fine inside a quoted string, where SQLite tokenizes
    /// them exactly as it tokenized the indexed text.
    private static func render(_ operand: Operand, columnPrefix: String) -> String? {
        switch operand.kind {
        case .word(let raw):
            guard let word = stemBareWord(raw) else { return nil }
            let core = columnPrefix + "\"\(word)\""
            return operand.negated ? "NOT \(core)" : core

        case .phrase(let raw):
            guard let phrase = stemPhrase(raw) else { return nil }
            // Phrase search always spans all indexed columns — matches the documented
            // limitation in `FTS5Query` ("column filters and phrase search are mutually
            // exclusive in this builder") so the two query-construction paths agree.
            let core = "\"\(phrase)\""
            return operand.negated ? "NOT \(core)" : core

        case .wildcard(let prefix):
            let sanitized = sanitizeBareToken(prefix)
            guard !sanitized.isEmpty else { return nil }
            // Quoted-string-plus-star is FTS5's prefix-query form for non-bareword
            // text; matches `FTS5Query`'s prefix-wildcard handling.
            let core = columnPrefix + "\"\(sanitized)\"*"
            return operand.negated ? "NOT \(core)" : core
        }
    }

    // MARK: - Sanitization
    //
    // `sanitizeBareToken` mirrors `FTS5Query.sanitizeTerm` exactly, and the structured
    // phrase, prefix and excluded terms are sanitised here for both paths — `FTS5Query`
    // hands its fields to `combine(renderedKeywords:structured:columnPrefix:)` — which is
    // what guarantees a term typed through the inline parser or set in the structured
    // Advanced Filters fields renders to the identical MATCH fragment and therefore the
    // identical match set. No stemming happens here: the `porter unicode61` tokenizer
    // stems query terms inside SQLite, symmetrically with indexed text.

    /// Strips FTS5 structural/operator characters from a single token, collapsing
    /// runs of resulting whitespace. Equivalent to `FTS5Query.sanitizeTerm`.
    private static func sanitizeBareToken(_ token: String) -> String {
        let stripped = token
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "(", with: " ")
            .replacingOccurrences(of: ")", with: " ")
            .replacingOccurrences(of: "^", with: " ")
            .replacingOccurrences(of: "*", with: " ")
            .replacingOccurrences(of: "{", with: " ")
            .replacingOccurrences(of: "}", with: " ")
            .replacingOccurrences(of: ":", with: " ")
            .replacingOccurrences(of: "/", with: " ")
            .replacingOccurrences(of: "+", with: " ")
        let components = stripped.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return components.joined(separator: " ")
    }

    /// Sanitises and lowercases a bare word — identical to the per-keyword transform
    /// in `FTS5Query.toFTS5MatchExpression()`. The porter tokenizer stems the term
    /// at query time, so no application-layer stemming is applied.
    ///
    /// Differs from that transform in one respect: when the sanitised text would be
    /// risky FTS5 syntax (a lone `-`, `***`, …), this parser drops the token entirely
    /// rather than embedding it. Inline syntax invites far more punctuation-heavy
    /// edge-case input than the structured keyword path ever saw, so this extra
    /// guard is specific to the parser. Multi-word survivors (e.g. `"a(b"` sanitising
    /// to `"a b"`) and purely alphanumeric tokens are kept verbatim.
    private static func stemBareWord(_ raw: String) -> String? {
        let sanitized = sanitizeBareToken(raw)
        guard !sanitized.isEmpty else { return nil }
        let lower = sanitized.lowercased()
        let alpha = lower.filter { $0.isLetter }
        if !alpha.isEmpty {
            return lower
        }
        let alnum = lower.filter { $0.isLetter || $0.isNumber }
        return (!lower.isEmpty && alnum == lower) ? lower : nil
    }

    /// Sanitises and lowercases each word of a phrase — a typed one, or the structured phrase
    /// field, which `FTS5Query` has sanitised through here since 3.0 rather than with a copy of
    /// this transform of its own. The porter tokenizer stems each phrase token at query time.
    private static func stemPhrase(_ raw: String) -> String? {
        let sanitized = raw
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "<", with: "")
            .replacingOccurrences(of: ">", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitized.isEmpty else { return nil }

        let words = sanitized
            .split(whereSeparator: \.isWhitespace)
            .map { String($0).lowercased() }
        let joined = words.joined(separator: " ")
        return joined.isEmpty ? nil : joined
    }
}

// MARK: - StructuredQueryParts

/// The structured search fields ANDed with the typed query: a phrase, a prefix wildcard and
/// excluded terms, as set by restored saved searches and the legacy Advanced fields.
///
/// Passed to `FTS5InlineQueryParser.parseDetailed(_:columnPrefix:structured:)`, which parses
/// them into the same tree as the typed text — see the parser's "Structured parts". Each is
/// sanitised there exactly as `FTS5Query` sanitises the fields of the same names.
///
/// Version history:
///   1.0 — #1297 join: initial implementation
public struct StructuredQueryParts: Sendable, Equatable {
    /// An exact phrase, spanning all columns whatever the column prefix. Lowercased word by
    /// word; `nil` or text that sanitises to nothing adds no part.
    public var phrase: String?
    /// A prefix, searched as `"prefix"*` behind the column prefix, `*` appended. `nil` or text
    /// that sanitises to nothing adds no part.
    public var prefixWildcard: String?
    /// Terms excluded from the whole query, each spanning all columns whatever the column
    /// prefix. A term of several words excludes that phrase. Never an anchor on its own.
    public var excludedTerms: [String]

    /// No structured fields.
    public static let none = StructuredQueryParts()

    /// Creates structured parts.
    public init(phrase: String? = nil, prefixWildcard: String? = nil, excludedTerms: [String] = []) {
        self.phrase = phrase
        self.prefixWildcard = prefixWildcard
        self.excludedTerms = excludedTerms
    }
}

// MARK: - ParsedQuery

/// A parsed search box: the FTS5 expression, plus the terms that need a literal-word
/// post-filter applied to whatever that expression returns.
///
/// Version history:
///   1.0 — Q-3b: initial implementation
///   1.1 — #1297: `droppedOperands`, the operands a query typed but its expression leaves out
///   1.2 — #1297 join: `isApproximate`; operands and dropped operands include the structured
///          fields, and every dropped operand is negated
public struct ParsedQuery: Sendable, Equatable {

    /// The MATCH expression, or `nil` when the input carries no positive search content.
    public let expression: String?

    /// Words the researcher marked with `=`, in the order typed, de-duplicated.
    ///
    /// Empty whenever `expression` is `nil` — there is nothing to post-filter.
    public let exactTerms: [String]

    /// The query's searchable units that `expression` applies, in the order typed — what
    /// the Query Inspector renders as pills and counts individually (Q-2).
    ///
    /// Operators are not operands and do not appear. Nor do boolean groups: a group is
    /// reported as the operands inside it, because "(a OR b)" has no single hit count.
    /// An operand the expression leaves out is in `droppedOperands` instead.
    /// Empty whenever `expression` is `nil`.
    public let operands: [ParsedOperand]

    /// Operands the researcher typed that the expression leaves out, in the order typed.
    ///
    /// FTS5 has no universal set, so an `OR` alternative made only of exclusions
    /// (`cold OR -korea`) cannot be searched: the alternative is left out of `expression`
    /// and its operands are reported here instead of in `operands`, so the Query Inspector
    /// can say they were not applied rather than showing them as working exclusions.
    /// Empty whenever `expression` is `nil`.
    ///
    /// Every dropped operand is negated: a negation is pushed inward before anything is left
    /// out, so a positive term inside an excluded group is searched, never dropped. Nothing is
    /// dropped beside a structured phrase or prefix, which anchors every complement.
    public let droppedOperands: [ParsedOperand]

    /// Whether `expression` matches only part of what the query means, because the query as a
    /// whole had no positive term to anchor its complement. Always `false` when `expression`
    /// is `nil`.
    ///
    /// Not the same as a non-empty `droppedOperands`: what was left out can be a demoted
    /// operator word with no operand, as in `-( -korea NOT )`, which renders `"korea"` and
    /// drops nothing. This flag is the only report of that case.
    public let isApproximate: Bool

    /// Creates a parsed query.
    public init(expression: String?, exactTerms: [String], operands: [ParsedOperand] = [],
                droppedOperands: [ParsedOperand] = [], isApproximate: Bool = false) {
        self.expression = expression
        self.exactTerms = exactTerms
        self.operands = operands
        self.droppedOperands = droppedOperands
        self.isApproximate = isApproximate
    }
}

// MARK: - ParsedOperand

/// One searchable unit of a query, as the inspector needs to describe it.
///
/// "Operand" here means what a researcher would point at and call a term: a word, a
/// quoted phrase, a prefix, or a whole `NEAR(...)`. A boolean *group* is deliberately not
/// one — it is reported as the operands inside it, because "(a OR b)" has no single hit
/// count and naming it as one operand would invite exactly the wrong reading.
///
/// Version history:
///   1.0 — Q-2a: initial implementation
///   1.1 — #1297: `isNegated` is the operand's effective polarity in the expression, so
///          keyword `NOT` and `NOT (...)` report their operands excluded, as `-` always did
///   1.2 — #1297 join: `source`, which tells a typed operand from one a structured field added
public struct ParsedOperand: Sendable, Equatable {

    /// What kind of searchable unit this is.
    public enum Kind: Sendable, Equatable {
        /// A bare word, stemmed by the tokenizer.
        case word
        /// A quoted phrase — an exact word sequence, each word stemmed.
        case phrase
        /// A trailing-`*` prefix search.
        case prefix
        /// A whole `NEAR(...)` expression.
        case proximity
    }

    /// The operand's text as the researcher would recognise it, without the `-` or `=`
    /// marks. A prefix keeps its `*`, because that is part of what was asked for.
    public let text: String

    /// The FTS5 fragment this operand rendered to — what actually went to SQLite: its
    /// positive form, prefixed `NOT ` when the operand is excluded.
    public let rendered: String

    /// What kind of unit it is.
    public let kind: Kind

    /// Whether the operand is excluded in the rendered expression — its effective polarity
    /// after every `-`, `NOT` and negated group above it, not the mark on its own token.
    ///
    /// `NOT korea` reports exactly what `-korea` does, and both operands of
    /// `NOT (korea OR vietnam)` are excluded. Repeated marks count once: a negation that
    /// reaches no positive term is not applied, so `NOT -korea` is simply excluded, while
    /// in `NOT (cold OR -korea)` the two negations above `korea` cancel and it is required.
    ///
    /// A negated operand has no meaningful "hit count" of its own in the result set, so
    /// the inspector shows it differently rather than counting it.
    public let isNegated: Bool

    /// Whether it carried the `=` exact-word mark.
    public let isExact: Bool

    /// Where an operand came from.
    public enum Source: Sendable, Equatable {
        /// Typed into the search box.
        case typed
        /// A structured field: the phrase, the prefix wildcard, or an excluded term.
        case structured
    }

    /// Where this operand came from.
    ///
    /// A structured operand is reported after every typed one, and cannot always be re-spelled
    /// as typed text — the prefix field `neg:oti` renders `"neg oti"*`, typed `neg oti*` renders
    /// `"neg" AND "oti"*` — so anything that re-runs one operand on its own must use its field.
    /// Part of equality: a value built by hand for a structured operand must pass `.structured`.
    public let source: Source

    /// Creates an operand.
    public init(text: String, rendered: String, kind: Kind, isNegated: Bool, isExact: Bool,
                source: Source = .typed) {
        self.text = text
        self.rendered = rendered
        self.kind = kind
        self.isNegated = isNegated
        self.isExact = isExact
        self.source = source
    }
}
