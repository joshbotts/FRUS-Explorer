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
/// Version history:
///   1.0 — O-1: initial implementation (decision O-1-2, one pass with N accumulators)
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
    /// - Returns: `nil` if `lenses` is empty or contains an entity lens — a caller that
    ///   asked for entity counts here would otherwise silently receive none.
    public init?(
        lenses: [WordCloudLens],
        tuning: WordCloudTuning,
        stopwords: Set<String>,
        lexicons: WordCloudLexiconSet,
        markings: Set<String>
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

        let schemes: [NLTagScheme] = requestsLexicalClass ? [.lemma, .lexicalClass] : [.lemma]
        let tagger = NLTagger(tagSchemes: schemes)
        tagger.string = text
        // The FRUS corpus is English; pinning the language improves lemma quality and
        // avoids per-call language detection.
        tagger.setLanguage(.english, range: text.startIndex..<text.endIndex)

        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .lemma,
            options: [.omitPunctuation, .omitWhitespace, .omitOther]
        ) { tag, tokenRange in
            // ── Shared work: exactly WordCloudTokenizer.accumulateWords, done once ──
            let surface = text[tokenRange]
            let lemma = tag?.rawValue
            let hasLemma = (lemma?.isEmpty == false)
            var candidate = (hasLemma ? lemma! : String(surface)).lowercased()
            if !hasLemma && foldPlurals { candidate = WordCloudTokenizer.singularize(candidate) }

            // Rejected for every lens alike — test these before paying for the POS tag.
            if markings.contains(candidate) { return true }
            guard isAcceptable(candidate) else { return true }

            // The lexical class is read at most once per surviving token, and only when
            // some channel needs it.
            var lexicalClass: NLTag??
            for channel in channels {
                if let lexicon = channel.lexicon {
                    guard lexicon.contains(candidate) else { continue }
                } else if let needed = channel.lexicalTag {
                    if lexicalClass == nil {
                        lexicalClass = tagger.tag(at: tokenRange.lowerBound,
                                                  unit: .word, scheme: .lexicalClass).0
                    }
                    guard lexicalClass! == needed else { continue }
                }
                counts[channel.lens, default: [:]][candidate, default: 0] += 1
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
