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
import NaturalLanguage

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
/// Version history:
///   1.0 — O-1: initial implementation (decision O-1-2, one pass with N accumulators)
///   1.1 — #1373: the tagger comes from `NaturalLanguageReadiness`, after the warm-up
///   1.2 — #1539 review round 1: the walk follows the tagger's schemes, as `WordCloudTokenizer`'s
///          does, so a tagger the gate built without `.lemma` still counts every word
///   1.3 — #1608: ``wordForm``, and ``accumulate(from:into:printedInto:)``, which counts the
///          dictionary and the printed form of every word in one pass; ``readsLexicalClass(_:)``
public struct WordCloudMultiLensTokenizer: Sendable {

    /// One lens and the filter it applies, resolved once at init.
    private struct Channel: Sendable {
        let lens: WordCloudLens
        /// Membership set for a lexicon lens; `nil` for a POS lens.
        let lexicon: Set<String>?
        /// Required lexical class for a POS lens; `nil` for a lexicon lens.
        let lexicalTag: NLTag?
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
                lexicalTag: Self.lexicalTag(for: lens)
            )
        }
        self.stopwords = stopwords
        self.minimumLength = tuning.minimumLength
        self.foldPlurals = tuning.foldPlurals
        self.markings = markings
        self.requestsLexicalClass = self.channels.contains { $0.lexicalTag != nil }
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
        lexicalTag(for: lens) != nil
    }

    /// The `NaturalLanguage` lexical-class tag a part-of-speech lens filters on.
    ///
    /// Mirrors `WordCloudTokenizer.lexicalTag`; kept in step by the parity test.
    private static func lexicalTag(for lens: WordCloudLens) -> NLTag? {
        switch lens {
        case .topics:      return .noun
        case .actions:     return .verb
        case .descriptors: return .adjective
        default:           return nil
        }
    }

    /// The schemes a pass asks the gate for: the walk's own — `.lemma`, or `.tokenType` for a
    /// `.printed` tokenizer (#1608) — and `.lexicalClass` only when a part-of-speech lens is
    /// present (the asymmetry note above). Internal so a test reads what each form asks for.
    var schemes: [NLTagScheme] {
        let walk: NLTagScheme = wordForm == .printed ? .tokenType : .lemma
        return requestsLexicalClass ? [walk, .lexicalClass] : [walk]
    }

    /// Accumulates counts for every configured lens from a single pass over `text`.
    ///
    /// Counts are accumulated into the caller's dictionary-of-dictionaries so a whole
    /// volume can be folded in document by document without an allocation per document.
    /// Lenses absent from `counts` are inserted on first hit.
    ///
    /// - Parameters:
    ///   - text: The document body text to tokenise.
    ///   - counts: A running `lens → term → count` tally, mutated in place.
    public func accumulate(from text: String, into counts: inout [WordCloudLens: [String: Int]]) {
        guard !text.isEmpty else { return }
        // Through the readiness gate, like `WordCloudTokenizer` — see there (#1373).
        accumulate(from: text, into: &counts, tagger: NaturalLanguageReadiness.tagger(tagSchemes: schemes))
    }

    /// Accumulates counts for every configured lens in **both** forms from a single pass over
    /// `text` (#1608): the dictionary form into `counts`, exactly as ``accumulate(from:into:)``
    /// counts it, and the printed form into `printed`.
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
        guard !text.isEmpty else { return }
        accumulate(from: text, into: &counts, printedInto: &printed,
                   tagger: NaturalLanguageReadiness.tagger(tagSchemes: schemes))
    }

    /// The pass over `tagger`, which ``accumulate(from:into:)`` builds through the gate.
    ///
    /// Walks by `NaturalLanguageReadiness.wordWalkScheme(of:)` and reads a lemma only from a `.lemma`
    /// walk, exactly as `WordCloudTokenizer.accumulateWords(from:into:tagger:)` does (#1539). Internal
    /// so a test can hand it a tagger the gate built without `.lemma`.
    /// - Parameters:
    ///   - text: The document body text to tokenise.
    ///   - counts: A running `lens → term → count` tally, mutated in place.
    ///   - tagger: The tagger to walk, from `NaturalLanguageReadiness.tagger(tagSchemes:)`.
    func accumulate(from text: String, into counts: inout [WordCloudLens: [String: Int]], tagger: NLTagger) {
        var unused: [WordCloudLens: [String: Int]] = [:]
        walk(text, tagger: tagger, into: &counts, printedInto: &unused, countsPrinted: false)
    }

    /// The both-forms pass over `tagger`, which ``accumulate(from:into:printedInto:)`` builds
    /// through the gate. Internal so a test can hand it a tagger of its own.
    /// - Parameters:
    ///   - text: The document body text to tokenise.
    ///   - counts: A running tally in dictionary forms, mutated in place.
    ///   - printed: A running tally in printed forms, mutated in place.
    ///   - tagger: The tagger to walk, from `NaturalLanguageReadiness.tagger(tagSchemes:)`.
    func accumulate(from text: String, into counts: inout [WordCloudLens: [String: Int]],
                    printedInto printed: inout [WordCloudLens: [String: Int]], tagger: NLTagger) {
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
    private func walk(_ text: String, tagger: NLTagger,
                      into counts: inout [WordCloudLens: [String: Int]],
                      printedInto printed: inout [WordCloudLens: [String: Int]],
                      countsPrinted: Bool) {
        let walk = NaturalLanguageReadiness.wordWalkScheme(of: tagger)
        tagger.string = text
        // The FRUS corpus is English; pinning the language improves lemma quality and
        // avoids per-call language detection.
        tagger.setLanguage(.english, range: text.startIndex..<text.endIndex)

        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: walk,
            options: [.omitPunctuation, .omitWhitespace, .omitOther]
        ) { tag, tokenRange in
            // ── Shared work: exactly WordCloudTokenizer.accumulateWords, done once ──
            let surface = text[tokenRange]
            let lemma = walk == .lemma ? tag?.rawValue : nil
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
            var lexicalClass: NLTag??
            for channel in channels {
                var countsCandidate = keepsCandidate
                var countsPrintedForm = keepsPrinted
                if let lexicon = channel.lexicon {
                    countsCandidate = countsCandidate && lexicon.contains(candidate)
                    countsPrintedForm = countsPrintedForm && lexicon.contains(printedForm)
                    guard countsCandidate || countsPrintedForm else { continue }
                } else if let needed = channel.lexicalTag {
                    if lexicalClass == nil {
                        lexicalClass = tagger.tag(at: tokenRange.lowerBound,
                                                  unit: .word, scheme: .lexicalClass).0
                    }
                    guard lexicalClass! == needed else { continue }
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
