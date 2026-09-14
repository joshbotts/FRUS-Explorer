// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

// MARK: - FTS5Query

/// Builds a valid SQLite FTS5 MATCH expression from structured search parameters.
///
/// ## FTS5 Query Syntax Supported
///
/// | Feature | Example | Notes |
/// |---|---|---|
/// | Keyword | `cold war` | AND by default; OR with `.booleanMode = .or` |
/// | Phrase | `"cold war"` | Exact word-order match |
/// | Boolean OR | `cold OR war` | Use `.booleanMode = .or` |
/// | Boolean NOT | `cold NOT korea` | Use `.excludedTerms` |
/// | Prefix wildcard | `negoti*` | Use `.prefixWildcard`; prefix must be ≥ 1 char |
/// | Column filter | `header:cold` | Use `.columns` to restrict search scope |
/// | Proximity | `NEAR("military guarantee" europe, 30)` | Inline only, via `FTS5InlineQueryParser`; operands may be words, phrases or prefixes — never booleans |
///
/// ## Limitations (document in UI help text)
/// - **Suffix wildcard is not supported**: `*gotiate` is not valid FTS5 syntax.
/// - **Column filters and phrase search** are mutually exclusive in this builder;
///   phrase search always spans all indexed columns. The one exception is a phrase
///   inside a `NEAR`, which FTS5 gives no way to exempt from the operator's own
///   column prefix.
/// - **`NEAR` is an inline-syntax feature**, not a structured field: it is recognised
///   by `FTS5InlineQueryParser` from the search box, so it reaches this builder already
///   rendered in `keywordExpression` and is never passed through `sanitizeTerm`.
///
/// ## Combining parts
/// The keyword expression, the phrase and the prefix wildcard are each a *part*, and the
/// rendered expression means (keywords) AND phrase AND prefix AND NOT each excluded term.
/// A query with one part emits that part exactly as built. With several, the parts are
/// joined by an explicit `AND` and any part that is not a single operand is parenthesised
/// first; excluded terms are applied to the whole positive expression, parenthesised unless
/// it is a single operand. Both rules exist because FTS5's binding does not follow the order
/// the parts are written in. Juxtaposition binds tighter than `NOT`, so
/// `"cold" NOT "korea" "cold war"` means `cold NOT (korea "cold war")`; juxtaposition beside
/// a group is a syntax error; and `NOT` binds tighter than `OR`, so
/// `"cold" OR "war" NOT "korea"` excludes korea from the war documents only.
///
/// ## Injection Safety
/// All user-supplied term strings are sanitised via `sanitizeTerm(_:)` before
/// embedding in the query expression. The sanitizer strips FTS5 operator characters
/// and double-quotes from free text to prevent syntax errors and injection.
///
/// Version history:
///   1.0 — Session 03: initial implementation
///   1.1 — Session 129: fix stemming asymmetry — keywords and excluded-terms paths now
///          filter to `isLetter` characters before calling `PorterStemmer.stem`, matching
///          the behaviour of `stemForIndex` in `FTS5Store` and the phrase-search path.
///          Previously, terms containing punctuation (apostrophes, hyphens) were stemmed
///          from the full sanitized string, producing different stems than the indexed text.
///   1.2 — Session 2026-06-08: added `keywordExpression` — an optional pre-rendered
///          fragment that takes priority over `keywords`/`booleanMode`, populated by
///          `SearchService` from `FTS5InlineQueryParser` so the main search box can
///          parse real Google-style inline syntax (`OR`, `"phrases"`, `-exclusions`,
///          `term*`) instead of the previous naive whitespace split that mangled it.
///   2.1 — Q-1 (2026-07-29): `NEAR` documented as supported. It arrives pre-rendered in
///          `keywordExpression` from `FTS5InlineQueryParser`, so `sanitizeTerm` — which
///          strips `(`, `)`, `:`, `*` and would destroy a NEAR — never sees it. The
///          structured `keywords` path is unchanged and still fully sanitised.
///   2.0 — Session 2026-06-09: query-side stemming removed. The `porter unicode61`
///          tokenizer stems both index entries and query terms inside SQLite, so the
///          rendered MATCH expression now carries the user's original (sanitised,
///          lowercased) words instead of application-layer Porter stems.
///   2.2 — #1297 (2026-09-13): parts are combined with an explicit `AND`, each parenthesised
///          unless it is a single operand, and excluded terms apply to the whole positive
///          expression. The bare-space join let FTS5's precedence regroup them, and the
///          macOS Advanced popover and restored saved searches still set a phrase, a prefix
///          and excluded terms beside typed keywords: a keyword expression ending in `NOT x`
///          swallowed the phrase or prefix into its exclusion, one ending in a group beside
///          a phrase or prefix was a syntax error (`"cold" AND ("korea" OR "vietnam")
///          "cold war"`), and excluded terms bound only to the last `OR` alternative.
///          Measured over the #1297 sweep — 7,380 typed queries through the 5.0 inline parser,
///          each combined with a phrase, a prefix and excluded terms in 9 ways, with and
///          without a column scope — the bare-space join gave 624 syntax errors and 9,918
///          wrong match sets out of 66,420 combinations, identically in both scopes, and this
///          join gives none. A single part keeps the bytes it always had.
public struct FTS5Query: Sendable {

    // MARK: - Nested Types

    /// Controls how multiple keyword terms are combined.
    /// `Codable` so a whole `SearchParameters` can be archived (#756) — see `SavedSearch`.
    public enum BooleanMode: String, Codable, Sendable, Equatable {
        /// All keyword terms must appear in the document (default).
        case and
        /// Any keyword term suffices.
        case or
    }

    // MARK: - Properties

    /// Free-text keyword terms. Combined with `AND` (default) or `OR`.
    /// Each term is individually stemmed by the registered tokenizer at query time.
    ///
    /// Ignored when `keywordExpression` is non-nil (see below) — the two are
    /// alternative ways of specifying the keyword portion of the query, not additive.
    public var keywords: [String]

    /// A pre-rendered, ready-to-embed FTS5 expression fragment for the keyword portion
    /// of the query — produced by `FTS5InlineQueryParser.parse(_:columnPrefix:)` from
    /// the raw text typed into the main search box.
    ///
    /// When non-nil, `toFTS5MatchExpression()` embeds this fragment directly in place of
    /// building one from `keywords`/`booleanMode` — it already carries its own stemming,
    /// sanitisation, operator structure (`OR`/`NOT`/implicit `AND`), and column scoping.
    /// `keywords` and `booleanMode` are ignored in that case.
    ///
    /// `nil` (the default) preserves the original structured-`keywords` rendering path
    /// used by `CorpusAnalyticsService` and the test suite, where callers construct
    /// `FTS5Query` directly from an already-tokenised `[String]` rather than raw text.
    public var keywordExpression: String?

    /// Exact phrase to match. If non-nil, the phrase is added as a quoted FTS5 term.
    /// Phrase search is case-insensitive but order-sensitive.
    public var phrase: String?

    /// How keyword terms are combined. Does not affect phrase or excluded terms.
    public var booleanMode: BooleanMode

    /// Terms that must NOT appear in the document. Each is excluded from the whole positive
    /// expression — keywords, phrase and prefix together — never from only part of it.
    public var excludedTerms: [String]

    /// Prefix for a wildcard match (e.g. `"negoti"` matches `"negotiate"`,
    /// `"negotiated"`, `"negotiations"`, etc.). The `*` suffix is appended automatically.
    /// Suffix wildcards are not supported.
    public var prefixWildcard: String?

    /// If non-nil, results are filtered to documents whose `subject_tag_ids` field
    /// contains this tag ID. Post-processing applied in `FTS5Store` after the FTS5 query.
    public var subjectTagId: String?

    /// If non-nil, results are filtered to documents whose `user_tag_ids` field
    /// contains this tag ID. Post-processing applied in `FTS5Store` after the FTS5 query.
    public var userTagId: String?

    /// Restrict full-text search to these columns only. Nil = search all indexed columns.
    /// Has no effect on `phrase` (phrase search always spans all indexed columns).
    public var columns: [FTS5Column]?

    // MARK: - Initialiser

    public init(
        keywords: [String] = [],
        keywordExpression: String? = nil,
        phrase: String? = nil,
        booleanMode: BooleanMode = .and,
        excludedTerms: [String] = [],
        prefixWildcard: String? = nil,
        subjectTagId: String? = nil,
        userTagId: String? = nil,
        columns: [FTS5Column]? = nil
    ) {
        self.keywords = keywords
        self.keywordExpression = keywordExpression
        self.phrase = phrase
        self.booleanMode = booleanMode
        self.excludedTerms = excludedTerms
        self.prefixWildcard = prefixWildcard
        self.subjectTagId = subjectTagId
        self.userTagId = userTagId
        self.columns = columns
    }

    // MARK: - FTS5 Expression Rendering

    /// Renders the structured query into an FTS5 MATCH expression string.
    ///
    /// The returned string is suitable for use as the right-hand side of a SQLite
    /// `MATCH` operator: `frus_documents MATCH <expression>`.
    ///
    /// Returns `nil` if the query contains no searchable content (all fields empty).
    public func toFTS5MatchExpression() -> String? {
        var parts: [String] = []

        // Column scope prefix, e.g. "{header body_text}:"
        let columnPrefix: String
        if let cols = columns, !cols.isEmpty {
            let names = cols.map(\.rawValue).joined(separator: " ")
            columnPrefix = "{\(names)}:"
        } else {
            columnPrefix = ""
        }

        // Keyword portion — `keywordExpression` (pre-rendered by `FTS5InlineQueryParser`
        // from raw inline-syntax search-box text) takes priority when present; it already
        // carries its own stemming, sanitisation, operator structure, and column scoping.
        // Otherwise fall back to the original structured `keywords`/`booleanMode` path
        // (used by `CorpusAnalyticsService` and the test suite, which construct `FTS5Query`
        // directly from an already-tokenised `[String]`).
        if let keywordExpression, !keywordExpression.isEmpty {
            parts.append(keywordExpression)
        } else {
            // Sanitize and lowercase only. The porter tokenizer stems query terms
            // inside SQLite exactly as it stems indexed text, so no application-layer
            // transform is needed (or wanted — a mismatched app-side stem would
            // *prevent* the tokenizer from matching). Terms are emitted as quoted
            // FTS5 strings: characters like apostrophes are invalid in barewords but
            // fine inside a quoted string, where SQLite tokenizes them exactly as it
            // tokenized the indexed text.
            let sanitizedKeywords = keywords
                .map { sanitizeTerm($0).lowercased() }
                .filter { !$0.isEmpty }

            if !sanitizedKeywords.isEmpty {
                let operator_ = booleanMode == .or ? " OR " : " "
                let keywordExpr = sanitizedKeywords
                    .map { columnPrefix + "\"\($0)\"" }
                    .joined(separator: operator_)
                parts.append(keywordExpr)
            }
        }

        // Phrase search (always full-table, ignores column prefix).
        // Words are embedded as-is; the porter tokenizer stems each phrase token at
        // query time, so morphological variants still match in word order.
        if let phrase, !phrase.isEmpty {
            let sanitized = sanitizePhrase(phrase)
            if !sanitized.isEmpty {
                let phraseWords = sanitized
                    .split(whereSeparator: \.isWhitespace)
                    .map { String($0).lowercased() }
                    .joined(separator: " ")
                if !phraseWords.isEmpty {
                    parts.append("\"\(phraseWords)\"")
                }
            }
        }

        // Prefix wildcard — quoted-string-plus-star is FTS5's prefix-query form
        // for non-bareword text.
        if let prefix = prefixWildcard, !prefix.isEmpty {
            let sanitized = sanitizeTerm(prefix)
            if !sanitized.isEmpty {
                parts.append(columnPrefix + "\"\(sanitized)\"*")
            }
        }

        // No positive term — FTS5 has no unary NOT, so exclusions alone are invalid syntax
        // and there is nothing to exclude from. Callers should validate that at least one
        // positive term exists.
        guard !parts.isEmpty else { return nil }

        // A lone part is emitted exactly as built. Several are joined with an explicit AND,
        // each parenthesised unless it is a single operand (see "Combining parts").
        var expression = parts.count == 1
            ? parts[0]
            : parts.map(Self.operandText).joined(separator: " AND ")

        // NOT terms — sanitised and lowercased only; the porter tokenizer stems at query time.
        // They apply to the whole positive expression, parenthesised unless it is a single
        // operand, so they can neither bind to its last OR alternative nor be swallowed by a
        // juxtaposition.
        let sanitizedExclusions = excludedTerms
            .map { sanitizeTerm($0).lowercased() }
            .filter { !$0.isEmpty }

        if !sanitizedExclusions.isEmpty {
            let positive = parts.count == 1 ? Self.operandText(parts[0]) : "(\(expression))"
            expression = positive + sanitizedExclusions.map { " NOT \"\($0)\"" }.joined()
        }

        return expression
    }

    /// `part` as an operand of `AND` or the left operand of `NOT`: unchanged when it is a
    /// single operand, parenthesised otherwise.
    private static func operandText(_ part: String) -> String {
        isSingleOperand(part) ? part : "(\(part))"
    }

    /// Whether `part` is one FTS5 operand, safe beside `AND` or `NOT` without parentheses: a
    /// single quoted string — optionally a `*` prefix query, optionally behind a `{columns}:`
    /// filter — or a single parenthesised group spanning the whole text.
    ///
    /// Anything else is parenthesised, deliberately conservatively. A keyword expression the
    /// inline parser rendered can hold `OR`, a binary `NOT`, or several column-scoped operands,
    /// and the structured keyword path juxtaposes its terms; parenthesising a `NEAR(...)`
    /// merely costs two characters. Quote-aware, including FTS5's `""` escape, so a
    /// parenthesis inside a quoted string is never mistaken for structure.
    static func isSingleOperand(_ part: String) -> Bool {
        let characters = Array(part)
        var index = 0
        if characters.first == "{" {
            guard let close = characters.firstIndex(of: "}"),
                  close + 1 < characters.count, characters[close + 1] == ":" else { return false }
            index = close + 2
        }
        guard index < characters.count else { return false }

        if characters[index] == "\"" {
            var cursor = index + 1
            while cursor < characters.count {
                if characters[cursor] == "\"" {
                    // `""` inside a string is an escaped quote, not the end of the string.
                    if cursor + 1 < characters.count, characters[cursor + 1] == "\"" {
                        cursor += 2
                        continue
                    }
                    break
                }
                cursor += 1
            }
            guard cursor < characters.count else { return false }
            var end = cursor + 1
            if end < characters.count, characters[end] == "*" { end += 1 }
            return end == characters.count
        }

        guard index == 0, characters[index] == "(" else { return false }
        var depth = 0
        var inQuotes = false
        for cursor in characters.indices {
            let character = characters[cursor]
            if character == "\"" {
                // An escaped `""` toggles twice, leaving the state where it was.
                inQuotes.toggle()
                continue
            }
            guard !inQuotes else { continue }
            if character == "(" {
                depth += 1
            } else if character == ")" {
                depth -= 1
                if depth == 0 { return cursor == characters.count - 1 }
            }
        }
        return false
    }

    // MARK: - Sanitization

    /// Strips characters that have special meaning in FTS5 query syntax from a
    /// single term, preventing syntax errors and injection.
    ///
    /// Removed: `"` `(` `)` `^` `*` `-` `+` `{` `}` `:` `/`
    /// Preserved: letters, digits, spaces (for multi-word keywords), apostrophes,
    /// hyphens within words are collapsed to spaces.
    private func sanitizeTerm(_ term: String) -> String {
        // Replace FTS5 operators and structural characters with spaces, then
        // collapse runs of whitespace and trim.
        let stripped = term
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
        // Collapse whitespace
        let components = stripped.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return components.joined(separator: " ")
    }

    /// Strips double-quotes and angle-brackets from a phrase string so it can be
    /// safely embedded between FTS5 double-quote delimiters.
    private func sanitizePhrase(_ phrase: String) -> String {
        phrase
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "<", with: "")
            .replacingOccurrences(of: ">", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
