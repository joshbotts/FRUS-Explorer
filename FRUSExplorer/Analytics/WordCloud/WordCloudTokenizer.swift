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

    /// The semantic filter. `.allTerms` keeps all content words; the entity and
    /// part-of-speech lenses keep only matching tokens (via `NaturalLanguage`).
    let lens: WordCloudLens

    /// For the lexicon-backed lenses (`.concepts`, `.sentiment`), the set of
    /// base-form words a token must belong to; `nil` for all other lenses.
    let lexicon: Set<String>?

    /// Classification markings and other document-chrome terms (single words and
    /// multi-word phrases) to reject across every lens. Empty disables the filter.
    let markings: Set<String>

    /// Creates a tokenizer.
    /// - Parameters:
    ///   - stopwords: Terms to exclude after lemmatisation/lowercasing.
    ///   - minimumLength: Shortest surviving token length. Default 3.
    ///   - foldPlurals: Whether to apply the plural-folding fallback. Default true.
    ///   - lens: Semantic filter to apply. Default `.allTerms`.
    ///   - lexicon: Membership set for lexicon-backed lenses. Default `nil`.
    ///   - markings: Classification/chrome terms to reject across all lenses.
    init(stopwords: Set<String>, minimumLength: Int = 3, foldPlurals: Bool = true,
         lens: WordCloudLens = .allTerms, lexicon: Set<String>? = nil,
         markings: Set<String> = []) {
        self.stopwords = stopwords
        self.minimumLength = minimumLength
        self.foldPlurals = foldPlurals
        self.lens = lens
        self.lexicon = lexicon
        self.markings = markings
    }

    /// The `NaturalLanguage` name-type tag this lens filters on, if it's an entity lens.
    private var nameTag: NLTag? {
        switch lens {
        case .people:        return .personalName
        case .places:        return .placeName
        case .organizations: return .organizationName
        default:             return nil
        }
    }

    /// The `NaturalLanguage` lexical-class tag this lens filters on, if it's a
    /// part-of-speech lens.
    private var lexicalTag: NLTag? {
        switch lens {
        case .topics:      return .noun
        case .actions:     return .verb
        case .descriptors: return .adjective
        default:           return nil
        }
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
        return lens.isEntity
            ? accumulateEntities(from: text, into: &counts)
            : accumulateWords(from: text, into: &counts)
    }

    /// Word path: lemmatised content words (`.allTerms`) optionally filtered to a
    /// part-of-speech (`.topics` / `.actions` / `.descriptors`).
    private func accumulateWords(from text: String, into counts: inout [String: Int]) -> Int {
        // Only request the lexical-class scheme when a POS lens needs it — the
        // default `.allTerms` path stays lemma-only and fast.
        let schemes: [NLTagScheme] = lexicalTag == nil ? [.lemma] : [.lemma, .lexicalClass]
        let tagger = NLTagger(tagSchemes: schemes)
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
            if let needed = lexicalTag {
                let cls = tagger.tag(at: tokenRange.lowerBound, unit: .word, scheme: .lexicalClass).0
                guard cls == needed else { return true }
            }
            let surface = text[tokenRange]
            let lemma = tag?.rawValue
            let hasLemma = (lemma?.isEmpty == false)
            // Prefer the lemma; fall back to the surface form when the lemmatiser
            // has no entry (proper nouns, archaic spellings). When falling back,
            // apply a conservative plural fold so "treaties"/"treaty" don't split.
            var candidate = (hasLemma ? lemma! : String(surface)).lowercased()
            if !hasLemma && foldPlurals { candidate = Self.singularize(candidate) }
            // Lexicon-backed lenses (concepts / sentiment) keep only base-form words
            // that belong to their curated set.
            if let lexicon, !lexicon.contains(candidate) { return true }
            // Classification markings / document chrome are noise in every lens.
            if markings.contains(candidate) { return true }
            if isAcceptable(candidate) {
                counts[candidate, default: 0] += 1
                added += 1
            }
            return true
        }
        return added
    }

    /// Entity path: named people / places / organizations via the name-type
    /// recogniser. `.joinNames` keeps multi-word names ("United States") whole.
    private func accumulateEntities(from text: String, into counts: inout [String: Int]) -> Int {
        guard let needed = nameTag else { return 0 }
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        tagger.setLanguage(.english, range: text.startIndex..<text.endIndex)

        var added = 0
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .nameType,
            options: [.omitPunctuation, .omitWhitespace, .omitOther, .joinNames]
        ) { tag, tokenRange in
            guard tag == needed else { return true }
            // Lowercase first to merge casing variants ("United States" /
            // "united states"), accept against the lowercased stopword set, then
            // present the entity in Title Case for display.
            let lowered = String(text[tokenRange])
                .lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if isAcceptableEntity(lowered) {
                counts[lowered.capitalized, default: 0] += 1
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

    /// Whether a named-entity term should be counted. More permissive than
    /// `isAcceptable` about internal spaces and periods (so multi-word names like
    /// "john f. kennedy" / "united states" survive), but stricter about what counts
    /// as a name: it rejects classification markings (the chief source of named-entity
    /// false positives, e.g. "top secret" tagged as a place), terms containing digits,
    /// stopwords, and phrases whose every component word is itself a stopword or marking.
    private func isAcceptableEntity(_ term: String) -> Bool {
        guard term.count >= minimumLength else { return false }
        guard term.contains(where: { $0.isLetter }) else { return false }
        guard !term.contains(where: { $0.isNumber }) else { return false }
        guard !stopwords.contains(term), !markings.contains(term) else { return false }
        // Drop phrases made up entirely of stopwords/markings ("top secret", where
        // the recogniser joined two non-name words).
        let components = term.split { $0 == " " || $0 == "." }.map(String.init)
        if !components.isEmpty,
           components.allSatisfy({ stopwords.contains($0) || markings.contains($0) }) {
            return false
        }
        return true
    }
}
