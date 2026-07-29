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
/// valid FTS5 expression, which `SearchService` now feeds into `FTS5Query.keywordExpression`.
///
/// ## Syntax recognised
///
/// | Syntax | Meaning | Example |
/// |---|---|---|
/// | bare words | AND (rendered as an explicit `AND` keyword) | `cold war` → both required |
/// | `"quoted phrase"` | exact word-order phrase match | `"cold war"` |
/// | `OR` (any case) | either side matches | `Rusk OR Bundy` |
/// | `AND` (any case) | both sides match | `cold and war` |
/// | leading `-` | exclude a term or phrase | `-quarantine`, `-"naval blockade"` |
/// | `NOT` (any case) | exclude the following term/phrase, group, or wildcard | `cold NOT korea`, `not (korea OR vietnam)` |
/// | trailing `*` | prefix wildcard | `negoti*` |
/// | `( ... )` | groups a sub-expression; combines with the rest of the query like any operand | `(aqaba OR tiran) AND (navigation OR passage OR transit)` |
///
/// Operator keywords are recognised **in any case** (`and`/`And`/`AND` all act as the
/// operator, matching history.state.gov) and **only when they sit between valid
/// operands** — a leading/trailing/doubled `OR`/`AND`/`NOT`, or an operator with no
/// operand to bind, is demoted back to a literal search word for that same term instead
/// of being mis-parsed into invalid syntax. This guarantees the renderer never emits a
/// MATCH expression SQLite would reject (no orphaned operators). To search for the
/// literal word "and"/"or"/"not", quote it: `"war and peace"`.
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
/// ## Grouping
/// `(...)` groups parse and render **recursively**: `renderTokens` calls itself on
/// each balanced group's contents, wraps the rendered result in literal parentheses,
/// and folds it back into the surrounding token stream as a single opaque operand.
/// That operand then flows through the very same `classify` /
/// `demoteOrphanedOperators` / `assemble` pipeline as any bare word — so groups
/// compose with `AND`/`OR`/`NOT` (including negating a whole group via
/// `NOT (...)`) and nest to arbitrary depth:
/// `((aqaba OR tiran) AND navig*) OR (suez NOT canal)` round-trips intact. FTS5
/// itself natively supports parenthesised grouping in MATCH expressions, so the
/// rendered fragment needs no further translation — it's valid FTS5 as written.
///
/// Degradation is graceful by construction: an unmatched `(` or stray `)` never
/// finds a balanced partner, falls through to ordinary token handling, sanitises to
/// nothing (parens are structural punctuation to `sanitizeBareToken`, exactly like
/// `{`/`}`/`:`/`/`), and is silently dropped. A group whose contents carry no
/// positive search content — `()`, `(   )`, `(-korea)` — is dropped in its entirety
/// rather than rendering as an empty `()` or a content-free `(NOT korea)`.
///
/// One asymmetry worth calling out: leading-`-` negation does **not** compose with
/// groups — `-(korea OR vietnam)` is *not* recognised as "exclude this group" (the
/// `-` tokenises on its own, sanitises to nothing, and is dropped, leaving the group
/// itself positive). Use the keyword form `NOT (korea OR vietnam)` instead, which
/// *is* recognised — consistent with the existing rule that `NOT`, unlike `-`, must
/// be spelled out and appear in uppercase.
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
public enum FTS5InlineQueryParser {

    // MARK: - Public Interface

    /// Parses `raw` (the literal text typed into the search box) into a stemmed,
    /// sanitised FTS5 MATCH expression fragment.
    ///
    /// - Parameter raw: The user's typed query text, in Google-style inline syntax.
    /// - Parameter columnPrefix: An FTS5 column-filter prefix (e.g. `"{header body_text}:"`)
    ///   applied to every bare word, phrase, and wildcard operand — never to operator
    ///   keywords. Pass `""` to search all indexed columns (the default).
    /// - Returns: A MATCH expression fragment suitable for embedding alongside the rest
    ///   of `FTS5Query`'s parts, or `nil` if `raw` contains no positive search content
    ///   (empty string, only excluded/negated terms, or terms that sanitise to nothing).
    public static func parse(_ raw: String, columnPrefix: String = "") -> String? {
        parseDetailed(raw, columnPrefix: columnPrefix).expression
    }

    /// Parses `raw` and reports both the MATCH expression and the terms the researcher
    /// marked exact with `=`.
    ///
    /// The two travel together because they are two halves of one query. FTS5 cannot
    /// express "this literal word" over a stemmed index, so an exact term is rendered
    /// into the expression as an ordinary stemmed operand — which narrows the candidate
    /// set to a strict superset — and is *also* reported here so the SQL layer can apply
    /// a word-boundary filter to what comes back. Dropping either half silently changes
    /// the answer: without the expression there is nothing to filter, and without the
    /// filter the `=` did nothing.
    public static func parseDetailed(_ raw: String, columnPrefix: String = "") -> ParsedQuery {
        var harvest = Harvest()
        let expression = renderTokens(tokenize(raw), columnPrefix: columnPrefix, into: &harvest)
        // Order-preserving de-duplication: the same word marked exact twice is one filter.
        var seen = Set<String>()
        let unique = harvest.exactTerms.filter { seen.insert($0).inserted }
        return ParsedQuery(expression: expression,
                           exactTerms: expression == nil ? [] : unique,
                           operands: expression == nil ? [] : harvest.operands)
    }

    /// Everything `renderTokens` gathers on its way down, besides the expression itself.
    ///
    /// One value rather than several `inout` parameters because the recursion threads it
    /// through every group; each new thing the parser reports would otherwise widen four
    /// call sites.
    private struct Harvest {
        var exactTerms: [String] = []
        var operands: [ParsedOperand] = []
    }

    // MARK: - Recursive Group-Aware Rendering

    /// Renders a flat sequence of raw tokens — which may contain balanced `(...)`
    /// groups at any depth — into a stemmed, sanitised FTS5 MATCH expression
    /// fragment, or `nil` if it carries no positive search content.
    ///
    /// Each balanced `(...)` group is located via `matchingGroup(in:openAt:)`,
    /// rendered by **recursing into this same function**, and — provided it produced
    /// any content — wrapped in literal parentheses and folded back into the token
    /// stream as a single opaque `.operand`. That operand then flows through the
    /// exact same `classify` / `demoteOrphanedOperators` / `assemble` pipeline as any
    /// bare word or phrase, so a group composes with `AND`/`OR`/`NOT` — including
    /// `NOT (a OR b)` — with no special-casing beyond "this operand happens to render
    /// as a parenthesised sub-expression". FTS5 natively supports parenthesised
    /// grouping in MATCH expressions, so the rendered fragment is valid as-is.
    ///
    /// Degradation is graceful by construction: an unmatched `(` or stray `)` never
    /// finds a partner in `matchingGroup`, falls through to ordinary `classify`
    /// handling, sanitises to nothing (parens are structural punctuation to
    /// `sanitizeBareToken`), and is silently dropped — exactly like any other
    /// punctuation-only token. A group whose contents render to `nil` (e.g. `()`,
    /// `(   )`, or `(-korea)` — only excluded terms, no positive content) is
    /// likewise dropped in its entirety rather than emitted as an empty `()`.
    private static func renderTokens(
        _ tokens: [String], columnPrefix: String, into harvest: inout Harvest
    ) -> String? {
        var resolved: [ResolvedToken] = []
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
                    resolved.append(.operand(rendered: rendered, isPositive: true))
                    harvest.operands.append(ParsedOperand(
                        text: (["NEAR("] + group.inner + [")"]).joined(separator: " "),
                        rendered: rendered, kind: .proximity, isNegated: false, isExact: false))
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

            if rawToken == "(", let group = matchingGroup(in: tokens, openAt: index) {
                if let rendered = renderTokens(group.inner, columnPrefix: columnPrefix,
                                               into: &harvest) {
                    resolved.append(.operand(rendered: "(\(rendered))", isPositive: true))
                }
                index = group.closeIndex + 1
                continue
            }

            if let classified = classify(rawToken) {
                switch classified {
                case .op(let kind):
                    resolved.append(.opCandidate(kind))
                case .operand(let operand):
                    if let rendered = render(operand, columnPrefix: columnPrefix) {
                        resolved.append(.operand(rendered: rendered, isPositive: !operand.negated))
                        harvest.operands.append(ParsedOperand(
                            text: operand.surfaceText, rendered: rendered,
                            kind: operand.kind.parsedKind, isNegated: operand.negated,
                            isExact: operand.isExact))
                        // Only *positive* exact terms become filters. `-="word"` would
                        // otherwise need an inverted post-filter, and getting that subtly
                        // wrong silently over-excludes; the sigil is ignored on a negated
                        // operand, which leaves ordinary negation — today's behaviour.
                        if operand.isExact, !operand.negated,
                           case .word(let raw) = operand.kind,
                           let term = exactTerm(from: raw) {
                            harvest.exactTerms.append(term)
                        }
                    }
                }
            }
            index += 1
        }

        demoteOrphanedOperators(in: &resolved)
        return assemble(resolved)
    }

    /// Scans forward from `tokens[openAt]` (which must be `"("`) for its balanced
    /// closing `")"`, tracking nested-paren depth so inner groups don't terminate the
    /// search early — e.g. for `(a (b) c) d`, the outer group's contents are correctly
    /// identified as `a (b) c`, not just `a (b`.
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
            if tokens[i] == "(" {
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

    /// Resolves operator placement and joins the surviving pieces into the final
    /// MATCH expression fragment. Shared by the top-level call in `renderTokens` and
    /// every recursive group invocation, so a group's internal "is there any positive
    /// content?" check is identical to the top-level one. Returns `nil` when there is
    /// no positive search content.
    private static func assemble(_ resolved: [ResolvedToken]) -> String? {
        var pieces: [String] = []
        var hasPositiveOperand = false
        // Tracks whether the operand/group about to be emitted sits immediately after
        // a surviving `NOT` operator — e.g. in `cold NOT korea` or `cold NOT (korea OR
        // vietnam)`, the right-hand side is excluded even though its own rendering
        // carries no negation marker of its own (that's a property of `Operand`, which
        // groups don't have). Without this, `NOT korea` or `NOT (korea OR vietnam)`
        // alone would be miscounted as having positive content and incorrectly produce
        // a MATCH expression instead of `nil`.
        var precededByNot = false
        // Whether the previously appended piece rendered an operand (vs. an operator
        // keyword). Two operands with no operator between them are *juxtaposed*; FTS5
        // only permits implicit-AND between bare phrases (`"a" "b"`), NOT between
        // parenthesised groups — `(a OR b) (c OR d)` is a hard syntax error. Relying on
        // juxtaposition therefore silently produced invalid MATCH expressions for every
        // grouped query (e.g. `(aqaba OR tiran) AND (navigation OR passage)`), which
        // SQLite rejected and the search surfaced as zero results. So an explicit `AND`
        // is inserted between juxtaposed positive operands.
        var previousWasOperand = false
        for token in resolved {
            switch token {
            case .operand(let rendered, let isPositive):
                // Insert an explicit AND between two juxtaposed operands when this one is
                // positive. A negated operand renders as `NOT x`, which forms the valid
                // binary `X NOT x`, so it must NOT be prefixed with AND (`X AND NOT x` is
                // itself an FTS5 syntax error).
                if previousWasOperand && isPositive {
                    pieces.append(Operator.and.fts5Keyword)
                }
                pieces.append(rendered)
                if isPositive && !precededByNot { hasPositiveOperand = true }
                precededByNot = false
                previousWasOperand = true
            case .opCandidate(let kind):
                // Every surviving operator — including AND — is emitted as a real FTS5
                // keyword. AND used to be dropped in favour of juxtaposition, but that
                // is invalid between groups (see `previousWasOperand` above). `AND` is a
                // documented standard-syntax keyword and is accepted wherever the OR
                // this builder already emits is.
                pieces.append(kind.fts5Keyword)
                precededByNot = (kind == .not)
                previousWasOperand = false
            }
        }

        guard hasPositiveOperand, !pieces.isEmpty else { return nil }
        return pieces.joined(separator: " ")
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
            } else if chars[i] == "(" || chars[i] == ")" {
                // Grouping parens are always emitted as their own single-character
                // tokens — even when butted directly against a word, e.g. `(aqaba`
                // or `tiran)` — so the recursive grouping pass in `renderTokens`
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

    // MARK: - Operator Resolution

    private enum ResolvedToken {
        case operand(rendered: String, isPositive: Bool)
        case opCandidate(Operator)
    }

    /// Walks `tokens` left-to-right, converting any `OR`/`AND`/`NOT` candidate that
    /// lacks the operand neighbour(s) it needs into a literal rendered operand for that
    /// same word (stemmed, like any other bare term).
    ///
    /// This is what guarantees `parse` never hands SQLite an expression with an
    /// orphaned operator (`"cold OR"`, `"OR cold"`, `"cold OR OR war"`, a bare `"NOT"`,
    /// …) — every operator that survives this pass is provably sandwiched between real
    /// operands, which is always valid FTS5 syntax. Resolution is left-to-right and
    /// in-place so chains of misplaced operators (`"cold OR AND war"`) resolve
    /// consistently: each candidate sees prior candidates' already-resolved state.
    ///
    /// `isOperand` treats a rendered `(...)` group exactly like any bare word or
    /// phrase — both arrive here as `.operand` cases — so `cold OR (war AND korea)`
    /// and `(cold OR war) NOT korea` resolve with no group-specific logic at all.
    private static func demoteOrphanedOperators(in tokens: inout [ResolvedToken]) {
        func isOperand(_ index: Int) -> Bool {
            guard tokens.indices.contains(index) else { return false }
            if case .operand = tokens[index] { return true }
            return false
        }

        for index in tokens.indices {
            guard case .opCandidate(let kind) = tokens[index] else { continue }
            let isValidPlacement: Bool
            switch kind {
            case .and, .or:
                isValidPlacement = isOperand(index - 1) && isOperand(index + 1)
            case .not:
                isValidPlacement = isOperand(index + 1)
            }
            guard !isValidPlacement else { continue }

            let literal = kind.fts5Keyword.lowercased()
            guard let word = stemBareWord(literal) else { continue }
            tokens[index] = .operand(rendered: "\"\(word)\"", isPositive: true)
        }
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
    // Mirrors `FTS5Query.sanitizeTerm`/`sanitizePhrase` exactly — this is what
    // guarantees a term typed through either the inline parser or the structured
    // Advanced Filters fields renders to the identical MATCH fragment and therefore
    // the identical match set. No stemming happens here: the `porter unicode61`
    // tokenizer stems query terms inside SQLite, symmetrically with indexed text.

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

    /// Sanitises and lowercases each word of a phrase — identical to the per-word
    /// transform in `FTS5Query.toFTS5MatchExpression()`'s phrase-handling branch.
    /// The porter tokenizer stems each phrase token at query time.
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

// MARK: - ParsedQuery

/// A parsed search box: the FTS5 expression, plus the terms that need a literal-word
/// post-filter applied to whatever that expression returns.
///
/// Version history:
///   1.0 — Q-3b: initial implementation
public struct ParsedQuery: Sendable, Equatable {

    /// The MATCH expression, or `nil` when the input carries no positive search content.
    public let expression: String?

    /// Words the researcher marked with `=`, in the order typed, de-duplicated.
    ///
    /// Empty whenever `expression` is `nil` — there is nothing to post-filter.
    public let exactTerms: [String]

    /// The query's searchable units, in the order typed — what the Query Inspector
    /// renders as pills and counts individually (Q-2).
    ///
    /// Operators are not operands and do not appear. Nor do boolean groups: a group is
    /// reported as the operands inside it, because "(a OR b)" has no single hit count.
    /// Empty whenever `expression` is `nil`.
    public let operands: [ParsedOperand]

    /// Creates a parsed query.
    public init(expression: String?, exactTerms: [String], operands: [ParsedOperand] = []) {
        self.expression = expression
        self.exactTerms = exactTerms
        self.operands = operands
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

    /// The FTS5 fragment this operand rendered to — what actually went to SQLite.
    public let rendered: String

    /// What kind of unit it is.
    public let kind: Kind

    /// Whether it was excluded with `-` or `NOT`.
    ///
    /// A negated operand has no meaningful "hit count" of its own in the result set, so
    /// the inspector shows it differently rather than counting it.
    public let isNegated: Bool

    /// Whether it carried the `=` exact-word mark.
    public let isExact: Bool

    /// Creates an operand.
    public init(text: String, rendered: String, kind: Kind, isNegated: Bool, isExact: Bool) {
        self.text = text
        self.rendered = rendered
        self.kind = kind
        self.isNegated = isNegated
        self.isExact = isExact
    }
}
