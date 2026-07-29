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
public struct FTS5Query: Sendable {

    // MARK: - Nested Types

    /// Controls how multiple keyword terms are combined.
    public enum BooleanMode: Sendable, Equatable {
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

    /// Terms that must NOT appear in the document.
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

        guard !parts.isEmpty || !excludedTerms.isEmpty else { return nil }

        var expression = parts.joined(separator: " ")

        // NOT terms — appended to whatever positive expression exists.
        // FTS5 requires at least one positive term when using NOT.
        // Sanitised and lowercased only; the porter tokenizer stems at query time.
        let sanitizedExclusions = excludedTerms
            .map { sanitizeTerm($0).lowercased() }
            .filter { !$0.isEmpty }

        if !sanitizedExclusions.isEmpty {
            let notPart = sanitizedExclusions.map { "NOT \"\($0)\"" }.joined(separator: " ")
            if expression.isEmpty {
                // No positive term — NOT alone is invalid FTS5 syntax. Skip.
                // Callers should validate that at least one positive term exists.
                return nil
            }
            expression = expression + " " + notPart
        }

        return expression.isEmpty ? nil : expression
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
