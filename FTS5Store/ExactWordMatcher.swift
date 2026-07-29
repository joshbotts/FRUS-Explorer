// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ExactWordMatcher

/// Decides whether a piece of stored text contains a word *literally*, on the same
/// boundaries SQLite's `unicode61` tokenizer uses.
///
/// ## Why this exists
/// The index is stemmed, so a search for `containment` is really a search for `contain`
/// and cannot distinguish the researcher's term from *contains*, *containing* or
/// *container*. Exact-word mode narrows that back down. The stemmed result set is a
/// strict **superset** of the exact matches — every document containing the literal word
/// also contains its stem — so exact mode is the stemmed query plus this post-filter. No
/// second index, no reindex.
///
/// ## Agreeing with the tokenizer is the whole job
/// This must split text exactly where `unicode61` splits it, or the filter removes
/// documents FTS5 legitimately matched. Verified against a real `unicode61` table:
///
/// - Runs of **alphanumeric** characters are tokens; everything else separates.
///   `containment.`, `(containment)` and `containment,` all yield `containment`;
///   `co-operate` yields two tokens; `containment42` stays one.
/// - **Diacritics are folded.** `naïve` indexes as `naive` and `Führer` as `fuhrer`.
///   This is the trap: a matcher that compared raw scalars would reject a document FTS5
///   had already matched, and the result would look like a mysterious missing hit rather
///   than a bug. `ExactWordMatcherTests` pins this against SQLite's own output.
/// - Case is folded.
///
/// Stemming is deliberately **not** applied here — that is the entire point.
///
/// Version history:
///   1.0 — Q-3b: initial implementation
public enum ExactWordMatcher {

    /// Normalises text the way `unicode61` does before comparison: diacritics folded,
    /// lowercased.
    ///
    /// Folding uses the POSIX locale rather than the user's. With a Turkish locale,
    /// `I` lowercases to a dotless `ı`, which would silently change which documents
    /// match based on a device setting the corpus knows nothing about.
    static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    /// Splits `text` into index tokens on `unicode61`'s boundaries.
    public static func tokens(in text: String) -> [String] {
        normalize(text)
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
    }

    /// Whether `word` is a usable exact term — that is, whether it is exactly one token.
    ///
    /// Multi-token input (`co-operate`, `U.S.S.R.`) has no single-word answer, so the
    /// sigil degrades to an ordinary stemmed search rather than silently filtering on
    /// one fragment of what the researcher typed.
    public static func isSingleToken(_ word: String) -> Bool {
        tokens(in: word).count == 1
    }

    /// Whether `text` contains `word` as a whole token.
    ///
    /// Returns `false` for a `word` that is not exactly one token — callers should have
    /// rejected those earlier via ``isSingleToken(_:)``; returning `false` here rather
    /// than `true` keeps a mistake visible as missing results instead of a filter that
    /// silently does nothing.
    public static func contains(word: String, in text: String) -> Bool {
        guard !text.isEmpty else { return false }
        let target = tokens(in: word)
        guard target.count == 1, let needle = target.first else { return false }
        return tokens(in: text).contains(needle)
    }

    /// Whether any of `texts` contains `word` as a whole token.
    ///
    /// The searched columns are ORed: a term appearing exactly in a header but only in
    /// stemmed form in the body still satisfies an exact search, because the header is
    /// one of the columns the query actually searched.
    public static func contains(word: String, inAnyOf texts: [String?]) -> Bool {
        texts.contains { text in
            guard let text else { return false }
            return contains(word: word, in: text)
        }
    }
}
