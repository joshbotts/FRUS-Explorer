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
/// | bare words | implicit AND (juxtaposition) | `cold war` → both required |
/// | `"quoted phrase"` | exact word-order phrase match | `"cold war"` |
/// | `OR` (uppercase only) | either side matches | `Rusk OR Bundy` |
/// | `AND` (uppercase only) | both sides match (same as juxtaposition) | `cold AND war` |
/// | leading `-` | exclude a term or phrase | `-quarantine`, `-"naval blockade"` |
/// | `NOT` (uppercase only) | exclude the following term/phrase, group, or wildcard | `cold NOT korea`, `NOT (korea OR vietnam)` |
/// | trailing `*` | prefix wildcard | `negoti*` |
/// | `( ... )` | groups a sub-expression; combines with the rest of the query like any operand | `(aqaba OR tiran) AND (navigation OR passage OR transit)` |
///
/// Operator keywords are recognised **only in uppercase** and **only when they sit
/// between valid operands** (matching both Google's and FTS5's own convention) — e.g.
/// lowercase `or`, or a leading/trailing/doubled `OR`/`AND`/`NOT`, is searched for as a
/// literal word instead of mis-parsed into invalid syntax. This guarantees the renderer
/// never emits a MATCH expression SQLite would reject (no orphaned operators).
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
        renderTokens(tokenize(raw), columnPrefix: columnPrefix)
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
    private static func renderTokens(_ tokens: [String], columnPrefix: String) -> String? {
        var resolved: [ResolvedToken] = []
        var index = 0
        while index < tokens.count {
            let rawToken = tokens[index]

            if rawToken == "(", let group = matchingGroup(in: tokens, openAt: index) {
                if let rendered = renderTokens(group.inner, columnPrefix: columnPrefix) {
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
        for token in resolved {
            switch token {
            case .operand(let rendered, let isPositive):
                pieces.append(rendered)
                if isPositive && !precededByNot { hasPositiveOperand = true }
                precededByNot = false
            case .opCandidate(let kind):
                // Explicit "AND" is rendered as plain juxtaposition (implicit AND) —
                // not the literal keyword "AND". FTS5's documented standard syntax
                // guarantees implicit-AND-via-concatenation works; whether the bare
                // "AND" keyword is accepted as an operator (vs. a literal search term)
                // depends on the build's syntax mode, and `FTS5Query` itself never
                // emits it (see its `.and` `booleanMode` rendering). Omitting the
                // keyword here sidesteps that ambiguity entirely while producing the
                // exact same match set.
                if kind != .and {
                    pieces.append(kind.fts5Keyword)
                }
                precededByNot = (kind == .not)
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
    }

    private struct Operand {
        var negated: Bool
        var kind: OperandKind
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
        // Operator keywords — recognised only in exact uppercase, matching both
        // Google's and FTS5's own convention (lowercase "or" is a literal search word).
        switch token {
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
        guard !text.isEmpty else { return nil }

        if text.hasPrefix("\"") {
            var inner = String(text.dropFirst())
            if inner.hasSuffix("\"") { inner = String(inner.dropLast()) }
            let trimmed = inner.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return .operand(Operand(negated: negated, kind: .phrase(trimmed)))
        }

        if text.hasSuffix("*"), text.count > 1 {
            let prefix = String(text.dropLast())
            guard !prefix.isEmpty else { return nil }
            return .operand(Operand(negated: negated, kind: .wildcard(prefix: prefix)))
        }

        return .operand(Operand(negated: negated, kind: .word(text)))
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
            guard let stemmed = stemBareWord(literal) else { continue }
            tokens[index] = .operand(rendered: stemmed, isPositive: true)
        }
    }

    // MARK: - Rendering

    /// Renders a single operand to its FTS5 fragment (sanitised, stemmed, column-scoped,
    /// and `NOT`-prefixed when negated). Returns `nil` when the operand sanitises to
    /// nothing usable (e.g. a phrase consisting only of punctuation).
    private static func render(_ operand: Operand, columnPrefix: String) -> String? {
        switch operand.kind {
        case .word(let raw):
            guard let stemmed = stemBareWord(raw) else { return nil }
            let core = columnPrefix + stemmed
            return operand.negated ? "NOT \(core)" : core

        case .phrase(let raw):
            guard let stemmed = stemPhrase(raw) else { return nil }
            // Phrase search always spans all indexed columns — matches the documented
            // limitation in `FTS5Query` ("column filters and phrase search are mutually
            // exclusive in this builder") so the two query-construction paths agree.
            let core = "\"\(stemmed)\""
            return operand.negated ? "NOT \(core)" : core

        case .wildcard(let prefix):
            let sanitized = sanitizeBareToken(prefix)
            guard !sanitized.isEmpty else { return nil }
            // Matches `FTS5Query`'s prefix-wildcard handling: sanitised but not
            // lowercased or stemmed — FTS5 prefix matching is on raw indexed tokens.
            let core = columnPrefix + sanitized + "*"
            return operand.negated ? "NOT \(core)" : core
        }
    }

    // MARK: - Sanitization & Stemming
    //
    // Mirrors `FTS5Query.sanitizeTerm`/`sanitizePhrase` and its keyword/exclusion
    // stemming transforms exactly (filter to `isLetter` before `PorterStemmer.stem`,
    // matching `FTS5Store.stemForIndex`) — this is what guarantees a term typed
    // through either the inline parser or the structured Advanced Filters fields
    // resolves to the identical stemmed token and therefore the identical match set.

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

    /// Sanitises, lowercases, filters to letters, and Porter-stems a bare word —
    /// identical to the per-keyword transform in `FTS5Query.toFTS5MatchExpression()`.
    ///
    /// Differs from that transform in one respect: when the sanitised text contains
    /// *no* letters, `FTS5Query` falls back to embedding the lowercased sanitised text
    /// verbatim (e.g. a stray `"123"` keyword survives as `123`). This parser instead
    /// only keeps that fallback when the result is purely alphanumeric — anything else
    /// (a lone `-`, `***`, …) is dropped rather than risking invalid FTS5 syntax. Inline
    /// syntax invites far more punctuation-heavy edge-case input than the structured
    /// keyword path ever saw, so this extra guard is specific to the new parser.
    private static func stemBareWord(_ raw: String) -> String? {
        let sanitized = sanitizeBareToken(raw)
        guard !sanitized.isEmpty else { return nil }
        let lower = sanitized.lowercased()
        let alpha = lower.filter { $0.isLetter }
        if !alpha.isEmpty {
            return PorterStemmer.stem(alpha)
        }
        let alnum = lower.filter { $0.isLetter || $0.isNumber }
        return (!lower.isEmpty && alnum == lower) ? lower : nil
    }

    /// Sanitises and Porter-stems each word of a phrase — identical to the per-word
    /// transform in `FTS5Query.toFTS5MatchExpression()`'s phrase-handling branch.
    private static func stemPhrase(_ raw: String) -> String? {
        let sanitized = raw
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "<", with: "")
            .replacingOccurrences(of: ">", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitized.isEmpty else { return nil }

        let words = sanitized
            .split(whereSeparator: \.isWhitespace)
            .map { word -> String in
                let lower = String(word).lowercased()
                let alpha = lower.filter { $0.isLetter }
                return alpha.isEmpty ? lower : PorterStemmer.stem(alpha)
            }
        let joined = words.joined(separator: " ")
        return joined.isEmpty ? nil : joined
    }
}
