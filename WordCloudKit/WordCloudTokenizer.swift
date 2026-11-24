// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

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
/// Every tagger comes from `NaturalLanguageReadiness.tagger(tagSchemes:)`, which waits for the
/// warm-up and its canary first (#1373). Whether the lemmatiser, the lexical classes and the
/// name recogniser actually work in this process is `NaturalLanguageReadiness.health`; this type
/// does not check, so a lens the tagger cannot serve counts nothing here and the caller decides
/// what to say. The gate leaves out of a tagger any scheme whose asset request is still in flight
/// (#1539), so the word walk goes by `NaturalLanguageReadiness.wordWalkScheme(of:)` and, without a
/// lemma scheme, counts each word as printed.
///
/// A caller that knows the lemmatiser is missing says so (``wordForm``, #1608): a tokenizer told
/// `.printed` asks for no lemma scheme, so its count is of printed forms throughout — the count the
/// printed-form keyness reference was made by — whatever the lemmatiser does while it runs.
///
/// ## A host's tagger (S29a)
/// What the count reads of a tagger is a protocol, `WordCloudTagger`: each word in order with its
/// range and, when asked, its lemma and its lexical class, and for the entity lenses each name with
/// its type. ``accumulate(from:into:tagger:)`` counts with any tagger, on every platform, by the
/// same rules; ``accumulate(from:into:)`` counts with NaturalLanguage's, through the gate
/// (`NaturalLanguageWordCloudTagger`), which is how the app has always counted. A `.printed`
/// tokenizer asks no tagger for lemmas and reads none, so a host's count of printed forms is one too.
///
/// Version history:
///   1.0 — Word Cloud feature: initial implementation
///   1.1 — #1373: taggers come from `NaturalLanguageReadiness`, after the warm-up
///   1.2 — #1539 review round 1: the word walk follows the tagger's schemes, so a tagger built
///          without `.lemma` still counts every word
///   1.3 — #1608: ``wordForm``; a `.printed` tokenizer never asks for the lemma scheme
///   1.4 — 2026-11-12 (FRUS Explorer Light, S24d): its counting behind `canImport(NaturalLanguage)`;
///          where the framework is missing (Linux) the type keeps its configuration and its filters
///          (``accepts(_:)``, ``singularize(_:)``), and its counting is unavailable and says why
///   1.5 — 2026-11-23 (FRUS Explorer Light, S29a): the walk reads a `WordCloudTagger`, so
///          ``accumulate(from:into:tagger:)`` counts with a host's tagger on every platform;
///          ``accumulate(from:into:)`` counts with NaturalLanguage's, through the gate, as before
public struct WordCloudTokenizer: Sendable {

    /// Shortest token length kept. Two characters and below are almost always
    /// noise (initials, abbreviations) once stopwords are removed.
    public let minimumLength: Int

    /// The set of terms to drop after normalisation.
    public let stopwords: Set<String>

    /// When `true`, a conservative plural→singular fold is applied to tokens the
    /// lemmatiser leaves unchanged, so e.g. "treaties" merges with "treaty".
    public let foldPlurals: Bool

    /// The semantic filter. `.allTerms` keeps all content words; the entity and
    /// part-of-speech lenses keep only matching tokens (via `NaturalLanguage`).
    public let lens: WordCloudLens

    /// For the lexicon-backed lenses (`.concepts`, `.sentiment`), the set of
    /// base-form words a token must belong to; `nil` for all other lenses.
    public let lexicon: Set<String>?

    /// Classification markings and other document-chrome terms (single words and
    /// multi-word phrases) to reject across every lens. Empty disables the filter.
    public let markings: Set<String>

    /// The form a word lens counts in (#1608). `.dictionary` reads the lemmatiser, as the tokenizer
    /// always has. `.printed` asks for a tagger with no lemma scheme, so every word is counted as
    /// printed. The entity lenses read no lemma and ignore it.
    public let wordForm: WordCloudWordForm

    /// Creates a tokenizer.
    /// - Parameters:
    ///   - stopwords: Terms to exclude after lemmatisation/lowercasing.
    ///   - minimumLength: Shortest surviving token length. Default 3.
    ///   - foldPlurals: Whether to apply the plural-folding fallback. Default true.
    ///   - lens: Semantic filter to apply. Default `.allTerms`.
    ///   - lexicon: Membership set for lexicon-backed lenses. Default `nil`.
    ///   - markings: Classification/chrome terms to reject across all lenses.
    ///   - wordForm: The form to count words in. Default `.dictionary`; pass the form of the verdict
    ///     the count is made under (`NaturalLanguageHealth.wordForm`) wherever the count will be
    ///     compared with a keyness reference.
    public init(stopwords: Set<String>, minimumLength: Int = 3, foldPlurals: Bool = true,
         lens: WordCloudLens = .allTerms, lexicon: Set<String>? = nil,
         markings: Set<String> = [], wordForm: WordCloudWordForm = .dictionary) {
        self.stopwords = stopwords
        self.minimumLength = minimumLength
        self.foldPlurals = foldPlurals
        self.lens = lens
        self.lexicon = lexicon
        self.markings = markings
        self.wordForm = wordForm
    }

    /// The name type this lens keeps, if it's an entity lens.
    private var nameType: WordCloudNameType? {
        switch lens {
        case .people:        return .person
        case .places:        return .place
        case .organizations: return .organization
        default:             return nil
        }
    }

    /// The lexical class this lens keeps, if it's a part-of-speech lens.
    private var keptClass: WordCloudLexicalClass? {
        switch lens {
        case .topics:      return .noun
        case .actions:     return .verb
        case .descriptors: return .adjective
        default:           return nil
        }
    }

    /// What the word walk reads of each word (S29a).
    ///
    /// Lemmas for a `.dictionary` tokenizer and none for a `.printed` one (#1608), and the lexical class
    /// only when a part-of-speech lens needs it, so the default `.allTerms` path stays lemma-only and
    /// fast. Internal so a test reads what each form asks for.
    var wordReading: WordCloudTagReading {
        var reading: WordCloudTagReading = wordForm == .printed ? [] : [.lemmas]
        if keptClass != nil { reading.insert(.lexicalClasses) }
        return reading
    }

    #if canImport(NaturalLanguage)
    /// Accumulates lemmatised, filtered term counts from `text` into `counts`, with NaturalLanguage's
    /// tagger through the readiness gate (`NaturalLanguageWordCloudTagger`), as the app counts.
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
    public func accumulate(from text: String, into counts: inout [String: Int]) -> Int {
        // Through the readiness gate, never `NLTagger(tagSchemes:)` directly: a scheme whose first
        // use in a process fails stays failed for the rest of it (#1373), so the warm-up must come
        // first even when a tokenizer is the first thing to run. The gate's tagger builds a tagger
        // for each walk, with the schemes the walk reads (``wordSchemes``).
        accumulate(from: text, into: &counts, tagger: NaturalLanguageWordCloudTagger())
    }

    /// The schemes the word walk asks the gate for.
    ///
    /// The lexical-class scheme only when a part-of-speech lens needs it, so the default `.allTerms`
    /// path stays lemma-only and fast. A `.printed` tokenizer asks for `.tokenType` where a
    /// `.dictionary` one asks for `.lemma` (#1608): the tagger then has no lemma scheme, the walk
    /// goes by `.tokenType` (`NaturalLanguageReadiness.wordWalkScheme(of:)`), and every word is
    /// counted as printed. They are ``wordReading`` in NaturalLanguage's terms
    /// (`NaturalLanguageWordCloudTagger.wordSchemes(for:)`, S29a). Internal so a test reads what each
    /// form asks for.
    var wordSchemes: [NLTagScheme] {
        NaturalLanguageWordCloudTagger.wordSchemes(for: wordReading)
    }
    #else
    /// Where `NaturalLanguage` is missing (Linux), the tokenizer has no tagger of its own, so it counts
    /// only with a host's (``accumulate(from:into:tagger:)``, S29a) and, without one, counts nothing and
    /// says why (FRUS Explorer Light, S24d). It never counts another way: the count is the kit's rules
    /// over a tagger's walks, and the tagger's identity says whose count it is, so a reference counted
    /// by NaturalLanguage refuses a host's (`KeynessBaselineFile.Configuration.mismatches`). The
    /// configuration and the filters, ``accepts(_:)`` and ``singularize(_:)``, read no tagger and are
    /// here on every platform.
    @available(*, unavailable, message: "WordCloudTokenizer counts with NaturalLanguage unless it is given a tagger, and this platform has no NaturalLanguage: count with a WordCloudTagger of your own, accumulate(from:into:tagger:), or read the bundled clouds")
    @discardableResult
    public func accumulate(from text: String, into counts: inout [String: Int]) -> Int {
        fatalError("WordCloudTokenizer counts with NaturalLanguage unless it is given a tagger")
    }
    #endif

    /// Accumulates lemmatised, filtered term counts from `text` into `counts`, with `tagger`'s words,
    /// lemmas, lexical classes and names (S29a).
    ///
    /// The rules are the same whatever the tagger: the lemma where it gives one, and otherwise the
    /// word lowercased and plural-folded; the lexicon, the markings, the length and the stopwords; a
    /// part-of-speech lens's class; an entity lens's name type. So a host's tagger counts by the app's
    /// rules, and NaturalLanguage's (``accumulate(from:into:)``) counts as it always has.
    ///
    /// - Parameters:
    ///   - text: The document body text to tokenise.
    ///   - counts: A running `term → count` tally, mutated in place.
    ///   - tagger: The tagger whose walks the count reads.
    /// - Returns: The number of surviving tokens contributed by `text`.
    @discardableResult
    public func accumulate<Tagger: WordCloudTagger>(from text: String, into counts: inout [String: Int],
                                                    tagger: Tagger) -> Int {
        guard !text.isEmpty else { return 0 }
        return lens.isEntity
            ? accumulateEntities(from: text, into: &counts, tagger: tagger)
            : accumulateWords(from: text, into: &counts, tagger: tagger)
    }

    /// Word path: lemmatised content words (`.allTerms`) optionally filtered to a part-of-speech
    /// (`.topics` / `.actions` / `.descriptors`), over `tagger`'s word walk.
    ///
    /// Reads a lemma only where the walk gives one: a `.printed` tokenizer asks for none, and reads none
    /// from a tagger that gives one anyway, and a tagger the gate built without `.lemma`, because its
    /// asset request is in flight (#1539), walks by `.tokenType`, whose tags are token kinds, not
    /// dictionary forms, and gives none. Internal so a test can hand it such a tagger.
    /// - Parameters:
    ///   - text: The document body text to tokenise.
    ///   - counts: A running `term → count` tally, mutated in place.
    ///   - tagger: The tagger to walk: NaturalLanguage's through the gate, an `NLTagger` from the gate,
    ///     or a host's.
    /// - Returns: The number of surviving tokens contributed by `text`.
    func accumulateWords<Tagger: WordCloudTagger>(from text: String, into counts: inout [String: Int],
                                                  tagger: Tagger) -> Int {
        var added = 0
        let reading = wordReading
        let readsLemmas = reading.contains(.lemmas)
        tagger.enumerateWords(in: text, reading: reading) { tokenRange, givenLemma, classOfWord in
            if let needed = keptClass {
                guard classOfWord() == needed else { return true }
            }
            let surface = text[tokenRange]
            // A count of printed forms reads no lemma, whatever the tagger gives (#1608, S29a).
            let lemma = readsLemmas ? givenLemma : nil
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

    /// Entity path: named people / places / organizations via `tagger`'s name walk, in which a name of
    /// several words ("United States") is one.
    private func accumulateEntities<Tagger: WordCloudTagger>(from text: String, into counts: inout [String: Int],
                                                             tagger: Tagger) -> Int {
        guard let needed = nameType else { return 0 }
        var added = 0
        tagger.enumerateNames(in: text) { tokenRange, type in
            guard type == needed else { return true }
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
    public static func singularize(_ word: String) -> String {
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

    /// Whether an already-normalised term survives every criterion this tokenizer applies.
    ///
    /// The same three tests `accumulateWords` runs inline (lexicon membership, markings
    /// rejection, then the per-lens acceptability check), exposed so a caller holding a term
    /// list rather than raw text can ask the question — the Word Cloud settings bench computes
    /// "Keeps N of M terms" with it. Factored rather than reimplemented, so the number the
    /// settings pane shows cannot drift from what the cloud actually does.
    ///
    /// Note what it does **not** cover: `WordCloudTuning.minimumCount`, which is applied later
    /// (`WordFrequencyService.finalize`) against accumulated counts rather than per term, and
    /// plural folding, which happens during tokenisation and cannot be undone from a term.
    ///
    /// - Parameter term: A lowercased, already-lemmatised candidate.
    /// - Returns: `true` when the term would be counted.
    public func accepts(_ term: String) -> Bool {
        if let lexicon, !lexicon.contains(term) { return false }
        if markings.contains(term) { return false }
        return lens.isEntity ? isAcceptableEntity(term) : isAcceptable(term)
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
