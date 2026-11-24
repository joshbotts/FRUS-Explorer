// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

/// Counts several word lenses from **one** `NLTagger` pass instead of one pass each.
///
/// ## Why this exists (decision O-1-2)
/// `CloudVectorsGenerator` needs four lenses — concepts, topics, actions, sentiment —
/// over the whole 3.3 GB corpus. Running ``WordCloudTokenizer`` once per lens tags every
/// volume four times, and tagging dominates the run.
///
/// The saving is available because **the four lenses share their entire pipeline up to the
/// final filter**. Each runs the same `enumerateTags(unit: .word, scheme: .lemma)` walk and
/// derives the same candidate term; they differ only in what they then keep:
///
/// | Lens | Keeps |
/// |---|---|
/// | `.concepts`  | tokens in the concepts lexicon |
/// | `.sentiment` | tokens in the sentiment lexicon |
/// | `.topics`    | tokens tagged `.noun` |
/// | `.actions`   | tokens tagged `.verb` |
///
/// So this is a **refactor, not an approximation**: the candidate is computed once and
/// fanned out. `WordCloudMultiLensParityTests` pins that against four separate
/// ``WordCloudTokenizer`` runs, term for term and count for count, and that test is the
/// reason the merge is safe to take. If it ever fails, the cause is almost certainly the
/// one asymmetry below.
///
/// ## The one asymmetry, and why it is handled
/// A single-lens tokenizer requests `[.lemma]` alone for the lexicon lenses and
/// `[.lemma, .lexicalClass]` for the POS lenses. Requesting both schemes *ought* not to
/// change the lemma — they are independent schemes on the same tagger — but that is an
/// assumption about a closed-source framework, not a guarantee. `requestsLexicalClass`
/// therefore asks for `.lexicalClass` only when a POS lens is actually present, so a
/// lexicon-only request is byte-identical to the single-lens path by construction.
///
/// ## Not for entity lenses
/// People / places / organizations take a different walk entirely (`.nameType` with
/// `.joinNames`, which merges adjacent tokens), so they cannot share this enumeration.
/// They are excluded from the bundled vectors anyway, and ``init`` rejects them.
///
/// ## Both forms from one pass (#1608)
/// ``accumulate(from:into:printedInto:)`` also counts every word as printed, in the pass that
/// counts it in its dictionary form. That is what lets `CloudVectorsGenerator` write the reference
/// counted as printed without tagging the corpus a second time: the printed form of a token is its
/// surface, lowercased and plural-folded under the tuning, which is what a walk with no lemma scheme
/// makes of the same token. Two things have to hold for the one pass to equal such a walk, and
/// both are a closed framework's behaviour rather than a guarantee: a walk by `.lemma` and a walk by
/// `.tokenType` find the same words, and a word's lexical class is the same whether or not the
/// tagger also holds the lemma scheme. `WordCloudPrintedFormParityTests` pins both on fixtures, and
/// the generator's `VERIFY_PRINTED_WALK=1` run measures them over every document of the corpus.
///
/// ## A host's tagger (S29a)
/// The pass reads a `WordCloudTagger`'s word walk, as `WordCloudTokenizer` does: the tagger-taking
/// ``accumulate(from:into:tagger:)`` and ``accumulate(from:into:printedInto:tagger:)`` count with any
/// tagger, on every platform, by the rules above; the two without one count with NaturalLanguage's,
/// through the gate (`NaturalLanguageWordCloudTagger`), as the generator always has. Over another
/// tagger the two properties the one pass rests on are that tagger's: `VERIFY_PRINTED_WALK=1` measures
/// them for it as it does for NaturalLanguage's.
///
/// Version history:
///   1.0 — O-1: initial implementation (decision O-1-2, one pass with N accumulators)
///   1.1 — #1373: the tagger comes from `NaturalLanguageReadiness`, after the warm-up
///   1.2 — #1539 review round 1: the walk follows the tagger's schemes, as `WordCloudTokenizer`'s
///          does, so a tagger the gate built without `.lemma` still counts every word
///   1.3 — #1608: ``wordForm``, and ``accumulate(from:into:printedInto:)``, which counts the
///          dictionary and the printed form of every word in one pass; ``readsLexicalClass(_:)``
///   1.4 — 2026-11-12 (FRUS Explorer Light, S24d): behind `canImport(NaturalLanguage)`; where the
///          framework is missing the type is unavailable and says why, below
///   1.5 — 2026-11-23 (FRUS Explorer Light, S29a): the pass reads a `WordCloudTagger`, so the type is
///          on every platform and counts with a host's tagger there; the two `accumulate`s without a
///          tagger count with NaturalLanguage's, through the gate, as before, and only where it is
public struct WordCloudMultiLensTokenizer: Sendable {

    /// One lens and the filter it applies, resolved once at init.
    private struct Channel: Sendable {
        let lens: WordCloudLens
        /// Membership set for a lexicon lens; `nil` for a POS lens.
        let lexicon: Set<String>?
        /// Required lexical class for a POS lens; `nil` for a lexicon lens.
        let lexicalClass: WordCloudLexicalClass?
    }

    private let channels: [Channel]
    private let stopwords: Set<String>
    private let minimumLength: Int
    private let foldPlurals: Bool
    private let markings: Set<String>

    /// `true` when at least one channel is a part-of-speech lens.
    ///
    /// Drives whether `.lexicalClass` is requested at all — see the asymmetry note above.
    private let requestsLexicalClass: Bool

    /// The lenses this tokenizer counts, in the order given at init.
    public var lenses: [WordCloudLens] { channels.map(\.lens) }

    /// The form ``accumulate(from:into:)`` counts in (#1608). `.printed` asks for a tagger with no
    /// lemma scheme, as `WordCloudTokenizer` does, so the pass is the walk a launch with no
    /// lemmatiser makes.
    public let wordForm: WordCloudWordForm

    /// Creates a multi-lens tokenizer.
    ///
    /// - Parameters:
    ///   - lenses: The word lenses to count. Entity lenses are rejected (see above);
    ///     duplicates are collapsed, keeping first occurrence order.
    ///   - tuning: Length and plural-folding criteria, shared by every lens.
    ///   - stopwords: Terms to drop after normalisation, shared by every lens.
    ///   - lexicons: Supplies the membership set for `.concepts` / `.sentiment`.
    ///   - markings: Classification/chrome terms rejected across all lenses. Pass empty
    ///     to disable, matching `WordCloudTuning.filterMarkings == false`.
    ///   - wordForm: The form ``accumulate(from:into:)`` counts in. Default `.dictionary`.
    /// - Returns: `nil` if `lenses` is empty or contains an entity lens — a caller that
    ///   asked for entity counts here would otherwise silently receive none.
    public init?(
        lenses: [WordCloudLens],
        tuning: WordCloudTuning,
        stopwords: Set<String>,
        lexicons: WordCloudLexiconSet,
        markings: Set<String>,
        wordForm: WordCloudWordForm = .dictionary
    ) {
        guard !lenses.isEmpty, !lenses.contains(where: \.isEntity) else { return nil }

        var seen = Set<WordCloudLens>()
        self.channels = lenses.compactMap { lens in
            guard seen.insert(lens).inserted else { return nil }
            return Channel(
                lens: lens,
                lexicon: lexicons.filter(for: lens),
                lexicalClass: Self.lexicalClass(for: lens)
            )
        }
        self.stopwords = stopwords
        self.minimumLength = tuning.minimumLength
        self.foldPlurals = tuning.foldPlurals
        self.markings = markings
        self.requestsLexicalClass = self.channels.contains { $0.lexicalClass != nil }
        self.wordForm = wordForm
    }

    /// Whether `lens` keeps words by their part of speech, so a tokenizer that counts it asks the
    /// tagger for the lexical-class scheme (#1608).
    ///
    /// Public for `CloudVectorsGenerator`'s verification walk, which has to build both taggers a
    /// device builds when it counts as printed: one that holds the lexical classes, for Topics,
    /// Actions and Descriptors, and one that does not, for All terms, Concepts and Sentiment. The
    /// list is not repeated there, because a lens added here would be missing from it silently.
    /// - Parameter lens: A word lens. An entity lens reads no lexical class and answers `false`.
    public static func readsLexicalClass(_ lens: WordCloudLens) -> Bool {
        lexicalClass(for: lens) != nil
    }

    /// The lexical class a part-of-speech lens filters on.
    ///
    /// Mirrors `WordCloudTokenizer.keptClass`; kept in step by the parity test.
    private static func lexicalClass(for lens: WordCloudLens) -> WordCloudLexicalClass? {
        switch lens {
        case .topics:      return .noun
        case .actions:     return .verb
        case .descriptors: return .adjective
        default:           return nil
        }
    }

    /// What a pass reads of each word (S29a): lemmas for a `.dictionary` tokenizer and none for a
    /// `.printed` one (#1608), and the lexical class only when a part-of-speech lens is present (the
    /// asymmetry note above). Internal so a test reads what each form asks for.
    var reading: WordCloudTagReading {
        var reading: WordCloudTagReading = wordForm == .printed ? [] : [.lemmas]
        if requestsLexicalClass { reading.insert(.lexicalClasses) }
        return reading
    }

    #if canImport(NaturalLanguage)
    /// The schemes a pass asks the gate for: the walk's own — `.lemma`, or `.tokenType` for a
    /// `.printed` tokenizer (#1608) — and `.lexicalClass` only when a part-of-speech lens is
    /// present (the asymmetry note above). They are ``reading`` in NaturalLanguage's terms
    /// (`NaturalLanguageWordCloudTagger.wordSchemes(for:)`, S29a). Internal so a test reads what each
    /// form asks for.
    var schemes: [NLTagScheme] {
        NaturalLanguageWordCloudTagger.wordSchemes(for: reading)
    }

    /// Accumulates counts for every configured lens from a single pass over `text`, with
    /// NaturalLanguage's tagger through the readiness gate (`NaturalLanguageWordCloudTagger`).
    ///
    /// Counts are accumulated into the caller's dictionary-of-dictionaries so a whole
    /// volume can be folded in document by document without an allocation per document.
    /// Lenses absent from `counts` are inserted on first hit.
    ///
    /// - Parameters:
    ///   - text: The document body text to tokenise.
    ///   - counts: A running `lens → term → count` tally, mutated in place.
    public func accumulate(from text: String, into counts: inout [WordCloudLens: [String: Int]]) {
        // Through the readiness gate, like `WordCloudTokenizer` — see there (#1373).
        accumulate(from: text, into: &counts, tagger: NaturalLanguageWordCloudTagger())
    }

    /// Accumulates counts for every configured lens in **both** forms from a single pass over
    /// `text` (#1608), with NaturalLanguage's tagger through the readiness gate: the dictionary form
    /// into `counts`, exactly as ``accumulate(from:into:)`` counts it, and the printed form into
    /// `printed`.
    ///
    /// The printed tally is what a `.printed` tokenizer counts over the same text — see "Both forms
    /// from one pass" above for what that rests on. Call it on a `.dictionary` tokenizer: over a
    /// tagger with no lemma scheme the two tallies are the same count.
    ///
    /// - Parameters:
    ///   - text: The document body text to tokenise.
    ///   - counts: A running `lens → term → count` tally in dictionary forms, mutated in place.
    ///   - printed: A running `lens → term → count` tally in printed forms, mutated in place.
    public func accumulate(from text: String,
                           into counts: inout [WordCloudLens: [String: Int]],
                           printedInto printed: inout [WordCloudLens: [String: Int]]) {
        accumulate(from: text, into: &counts, printedInto: &printed, tagger: NaturalLanguageWordCloudTagger())
    }
    #else
    /// Where `NaturalLanguage` is missing (Linux), the pass has no tagger of its own: it counts with a
    /// host's (``accumulate(from:into:tagger:)``, S29a), and without one says why.
    @available(*, unavailable, message: "WordCloudMultiLensTokenizer counts with NaturalLanguage unless it is given a tagger, and this platform has no NaturalLanguage: count with a WordCloudTagger of your own, accumulate(from:into:tagger:)")
    public func accumulate(from text: String, into counts: inout [WordCloudLens: [String: Int]]) {
        fatalError("WordCloudMultiLensTokenizer counts with NaturalLanguage unless it is given a tagger")
    }

    /// Where `NaturalLanguage` is missing (Linux), the both-forms pass counts with a host's tagger
    /// (``accumulate(from:into:printedInto:tagger:)``, S29a), and without one says why.
    @available(*, unavailable, message: "WordCloudMultiLensTokenizer counts with NaturalLanguage unless it is given a tagger, and this platform has no NaturalLanguage: count with a WordCloudTagger of your own, accumulate(from:into:printedInto:tagger:)")
    public func accumulate(from text: String,
                           into counts: inout [WordCloudLens: [String: Int]],
                           printedInto printed: inout [WordCloudLens: [String: Int]]) {
        fatalError("WordCloudMultiLensTokenizer counts with NaturalLanguage unless it is given a tagger")
    }
    #endif

    /// Accumulates counts for every configured lens from a single pass over `text`, with `tagger`'s
    /// word walk (S29a): the rules of ``accumulate(from:into:)``, over any tagger.
    ///
    /// Reads a lemma only where the walk gives one, exactly as `WordCloudTokenizer`'s word walk does:
    /// a `.printed` tokenizer asks for none and reads none, and a tagger the gate built without
    /// `.lemma` gives none (#1539), so a test can hand it such a tagger.
    /// - Parameters:
    ///   - text: The document body text to tokenise.
    ///   - counts: A running `lens → term → count` tally, mutated in place.
    ///   - tagger: The tagger to walk: NaturalLanguage's through the gate, an `NLTagger` from the gate,
    ///     or a host's.
    public func accumulate<Tagger: WordCloudTagger>(from text: String,
                                                    into counts: inout [WordCloudLens: [String: Int]],
                                                    tagger: Tagger) {
        guard !text.isEmpty else { return }
        var unused: [WordCloudLens: [String: Int]] = [:]
        walk(text, tagger: tagger, into: &counts, printedInto: &unused, countsPrinted: false)
    }

    /// Accumulates counts for every configured lens in **both** forms from a single pass over `text`,
    /// with `tagger`'s word walk (S29a): the rules of ``accumulate(from:into:printedInto:)``, over any
    /// tagger. Call it on a `.dictionary` tokenizer.
    /// - Parameters:
    ///   - text: The document body text to tokenise.
    ///   - counts: A running tally in dictionary forms, mutated in place.
    ///   - printed: A running tally in printed forms, mutated in place.
    ///   - tagger: The tagger to walk.
    public func accumulate<Tagger: WordCloudTagger>(from text: String,
                                                    into counts: inout [WordCloudLens: [String: Int]],
                                                    printedInto printed: inout [WordCloudLens: [String: Int]],
                                                    tagger: Tagger) {
        guard !text.isEmpty else { return }
        walk(text, tagger: tagger, into: &counts, printedInto: &printed, countsPrinted: true)
    }

    /// One walk over `tagger`, counting each word's candidate into `counts` and, when
    /// `countsPrinted`, its printed form into `printed`.
    ///
    /// The candidate is `WordCloudTokenizer.accumulateWords`' own: the lemma where the walk gives
    /// one, and otherwise the printed form — the surface, lowercased, and plural-folded when the
    /// tuning folds. So the printed form is the candidate of a word with no lemma, and a walk with
    /// no lemma scheme counts nothing else. Each form passes the markings, the length and stopword
    /// test and the lens's own filter by itself: a word whose lemma is a stopword and whose printed
    /// form is not ("says", under "say") is counted in one tally and not the other.
    private func walk<Tagger: WordCloudTagger>(_ text: String, tagger: Tagger,
                                               into counts: inout [WordCloudLens: [String: Int]],
                                               printedInto printed: inout [WordCloudLens: [String: Int]],
                                               countsPrinted: Bool) {
        let reading = self.reading
        let readsLemmas = reading.contains(.lemmas)
        tagger.enumerateWords(in: text, reading: reading) { tokenRange, givenLemma, classOfWord in
            // ── Shared work: exactly WordCloudTokenizer.accumulateWords, done once ──
            let surface = text[tokenRange]
            // A `.printed` pass reads no lemma, whatever the tagger gives (#1608, S29a).
            let lemma = readsLemmas ? givenLemma : nil
            let hasLemma = (lemma?.isEmpty == false)
            // The printed form is worked out only where something reads it: for a word with no
            // lemma, whose candidate it is, and for every word of a both-forms pass.
            var printedForm = ""
            if countsPrinted || !hasLemma {
                printedForm = String(surface).lowercased()
                if foldPlurals { printedForm = WordCloudTokenizer.singularize(printedForm) }
            }
            let candidate = hasLemma ? lemma!.lowercased() : printedForm

            // Rejected for every lens alike — test these before paying for the POS tag.
            let keepsCandidate = !markings.contains(candidate) && isAcceptable(candidate)
            let keepsPrinted = countsPrinted
                && (hasLemma ? !markings.contains(printedForm) && isAcceptable(printedForm)
                             : keepsCandidate)
            guard keepsCandidate || keepsPrinted else { return true }

            // The lexical class is read at most once per surviving token, and only when
            // some channel needs it.
            var wordClass: WordCloudLexicalClass??
            for channel in channels {
                var countsCandidate = keepsCandidate
                var countsPrintedForm = keepsPrinted
                if let lexicon = channel.lexicon {
                    countsCandidate = countsCandidate && lexicon.contains(candidate)
                    countsPrintedForm = countsPrintedForm && lexicon.contains(printedForm)
                    guard countsCandidate || countsPrintedForm else { continue }
                } else if let needed = channel.lexicalClass {
                    if wordClass == nil {
                        wordClass = classOfWord()
                    }
                    guard wordClass! == needed else { continue }
                }
                if countsCandidate { counts[channel.lens, default: [:]][candidate, default: 0] += 1 }
                if countsPrintedForm { printed[channel.lens, default: [:]][printedForm, default: 0] += 1 }
            }
            return true
        }
    }

    /// Whether a normalised candidate term should be counted.
    ///
    /// Identical to `WordCloudTokenizer.isAcceptable` — rejects short tokens, anything
    /// containing a digit or non-letter, and stopwords.
    private func isAcceptable(_ term: String) -> Bool {
        guard term.count >= minimumLength else { return false }
        for ch in term where !(ch.isLetter || ch == "-" || ch == "'") { return false }
        guard term.contains(where: { $0.isLetter }) else { return false }
        return !stopwords.contains(term)
    }
}
