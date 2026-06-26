// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import NaturalLanguage

/// Turns document body text into a stream of normalised, filtered terms for
/// word-cloud frequency counting.
///
/// Normalisation applies Apple's on-device `NaturalLanguage` lemmatiser on a
/// best-effort basis: when it returns a lemma, inflected forms collapse to a
/// single readable form ("negotiations" → "negotiation"), giving a less
/// fragmented, more legible cloud than the FTS5 English stemmer's stems (e.g.
/// "diplomaci"). The lemmatiser is context-dependent — it yields better lemmas
/// over full sentences than isolated words — so when no lemma is available the
/// lowercased surface form is kept. A token survives only if it is alphabetic,
/// at least `minimumLength` characters, and not a stopword.
///
/// The type is a value type with no stored mutable state, so it is `Sendable` and
/// safe to use from any actor.
///
/// Version history:
///   1.0 — Word Cloud feature: initial implementation
struct WordCloudTokenizer: Sendable {

    /// Shortest token length kept. Two characters and below are almost always
    /// noise (initials, abbreviations) once stopwords are removed.
    let minimumLength: Int

    /// The set of terms to drop after normalisation.
    let stopwords: Set<String>

    /// When `true`, a conservative plural→singular fold is applied to tokens the
    /// lemmatiser leaves unchanged, so e.g. "treaties" merges with "treaty".
    let foldPlurals: Bool

    /// Creates a tokenizer.
    /// - Parameters:
    ///   - stopwords: Terms to exclude after lemmatisation/lowercasing.
    ///   - minimumLength: Shortest surviving token length. Default 3.
    ///   - foldPlurals: Whether to apply the plural-folding fallback. Default true.
    init(stopwords: Set<String>, minimumLength: Int = 3, foldPlurals: Bool = true) {
        self.stopwords = stopwords
        self.minimumLength = minimumLength
        self.foldPlurals = foldPlurals
    }

    /// Accumulates lemmatised, filtered term counts from `text` into `counts`.
    ///
    /// Counts are accumulated into the caller's dictionary rather than returned so
    /// many documents can be folded into a single running tally without allocating
    /// an intermediate array per document.
    ///
    /// - Parameters:
    ///   - text: The document body text to tokenise.
    ///   - counts: A running `term → count` tally, mutated in place.
    /// - Returns: The number of surviving tokens contributed by `text`.
    @discardableResult
    func accumulate(from text: String, into counts: inout [String: Int]) -> Int {
        guard !text.isEmpty else { return 0 }
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = text
        // The FRUS corpus is English; pinning the language improves lemma quality
        // and avoids per-call language detection.
        tagger.setLanguage(.english, range: text.startIndex..<text.endIndex)

        var added = 0
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .lemma,
            options: [.omitPunctuation, .omitWhitespace, .omitOther]
        ) { tag, tokenRange in
            let surface = text[tokenRange]
            let lemma = tag?.rawValue
            let hasLemma = (lemma?.isEmpty == false)
            // Prefer the lemma; fall back to the surface form when the lemmatiser
            // has no entry (proper nouns, archaic spellings). When falling back,
            // apply a conservative plural fold so "treaties"/"treaty" don't split.
            var candidate = (hasLemma ? lemma! : String(surface)).lowercased()
            if !hasLemma && foldPlurals { candidate = Self.singularize(candidate) }
            if isAcceptable(candidate) {
                counts[candidate, default: 0] += 1
                added += 1
            }
            return true
        }
        return added
    }

    /// Words that look plural (end in `s`) but are singular or uncountable, and so
    /// must never be folded.
    private static let pluralExceptions: Set<String> = [
        "series", "species", "news", "analysis", "basis", "crisis", "thesis",
        "diagnosis", "emphasis", "hypothesis", "politics", "economics", "physics",
        "ethics", "statistics", "status", "census", "consensus", "apparatus",
        "corps", "means", "headquarters", "gas", "bias", "canvas", "atlas",
        "alias", "virus", "focus", "bonus", "campus", "surplus", "versus",
        "across", "press", "congress", "progress", "process", "access", "address",
        "business", "witness", "wireless", "always", "perhaps", "whereas"
    ]

    /// Conservatively folds a likely English plural to its singular.
    ///
    /// Guards against common `-is`/`-us`/`-ss`/`-ous` endings and a fixed
    /// exception set, so only high-confidence plurals are reduced. Applied only as
    /// a fallback when the lemmatiser yields no lemma.
    static func singularize(_ word: String) -> String {
        guard word.count > 4, !pluralExceptions.contains(word) else { return word }
        if word.hasSuffix("ss") || word.hasSuffix("us")
            || word.hasSuffix("is") || word.hasSuffix("ous") { return word }
        if word.hasSuffix("ies") { return String(word.dropLast(3)) + "y" }   // treaties → treaty
        if word.hasSuffix("ches") || word.hasSuffix("shes")
            || word.hasSuffix("sses") || word.hasSuffix("xes")
            || word.hasSuffix("zes") { return String(word.dropLast(2)) }     // boxes → box
        if word.hasSuffix("s") { return String(word.dropLast(1)) }           // documents → document
        return word
    }

    /// Whether a normalised candidate term should be counted.
    ///
    /// Rejects short tokens, anything containing a digit or non-letter (so dates,
    /// reference numbers, and stray punctuation drop out), and stopwords.
    private func isAcceptable(_ term: String) -> Bool {
        guard term.count >= minimumLength else { return false }
        for ch in term where !(ch.isLetter || ch == "-" || ch == "'") { return false }
        guard term.contains(where: { $0.isLetter }) else { return false }
        return !stopwords.contains(term)
    }
}
