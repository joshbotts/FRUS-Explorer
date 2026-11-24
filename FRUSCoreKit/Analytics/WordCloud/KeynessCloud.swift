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

#if canImport(WordCloudKit)
import WordCloudKit
#endif

// MARK: - KeynessCloud

/// Turns a computed word cloud into a keyness ranking — which of its words are *distinctive* of the
/// scope rather than merely frequent in it.
///
/// ## A re-ranking, not a second computation
/// This runs entirely on terms the cloud has already counted. That is a deliberate architectural
/// choice, not an economy: the scope's term limit participates in **both** cache keys
/// (`WordFrequencyService.cacheKey` and `WordCloudDiskCache.key`), so asking the service for a
/// deeper term list would miss every cache *and* the background precompute, turning a mode toggle
/// into a full re-tokenisation of the scope — for the corpus, a very long one. Re-ranking terms
/// already in memory is instant, cannot fail, and needs no task, progress or cancellation.
///
/// The price is stated rather than hidden: see ``Ranking/rankedAmongTopFrequent``.
///
/// ## Only over-represented terms are shown
/// `Keyness` returns a **signed** score, and the negative half is a real finding — the vocabulary a
/// set of documents conspicuously *avoids*. It is not shown here, for two reasons. A cloud sizes
/// words by magnitude, so mixing "says this far more" with "says this far less" in one size ranking
/// is incoherent. And the list view is the cloud's `accessibilityRepresentation`, so the two must
/// contain the same terms or a VoiceOver reader gets a different answer from a sighted one.
///
/// Version history:
///   1.0 — S-1: initial implementation
///   1.1 — #1373: `rank` takes the tagger verdict the terms were counted under, and a scope counted
///          without the lemmatiser is `languageAnalysisUnavailable` rather than ranked
///   1.2 — #1608: a scope counted as printed is ranked against the reference counted as printed,
///          and the ranking says so (``Ranking/wordForm``)
///   1.3 — 2026-11-24 (FRUS Explorer Light, S29b): moved into FRUSCoreKit, public: the ranking takes the
///          references and the tokenizer from its caller (``rank(terms:scopeTotal:fetchedTermCount:termLimit:lens:tuning:includeDiplomatic:languageAnalysis:references:tokenizer:minimumScopeCount:)``),
///          or a lookup's answer (``rank(terms:scopeTotal:fetchedTermCount:termLimit:availability:minimumScopeCount:)``),
///          and holds no state, so it is not isolated; the measure's label stays the app's
///
/// Not isolated since it moved into the kit: it ranks over the references its caller passes, and holds
/// nothing. The app's ranking against `BundledKeynessBaseline`, which is `@MainActor` because the
/// reference is loaded once and read from views, is the app's own, on the main actor as before.
public enum KeynessCloud {

    // MARK: - Result

    /// A keyness reading of one scope.
    public struct Ranking: Equatable, Sendable {
        /// Over-represented terms, most distinctive first.
        public let scores: [KeynessScore]
        /// How many of the scope's terms were eligible to be scored.
        public let candidateCount: Int
        /// Whether the candidate set was bounded by the cloud's term limit rather than by the
        /// low-frequency floor.
        ///
        /// `true` means the ranking covers only the scope's most *frequent* terms, so a word that is
        /// rare in the scope but unique to it could not be reached. That is a real limitation of
        /// ranking an already-truncated list, and the view says so rather than implying completeness.
        public let rankedAmongTopFrequent: Bool
        /// The scope floor a term had to clear to be scored at all.
        public let minimumScopeCount: Int
        /// How much of the corpus vocabulary the reference prices, for the provenance line.
        public let referenceRetained: Int
        /// How many distinct terms the corpus had before the reference was truncated.
        public let referenceDistinct: Int
        /// The smallest corpus count the reference prices. A scope term rarer than this corpus-wide
        /// is *unpriced*, not absent — the distinction the view must not blur.
        public let referenceCutoffCount: Int
        /// The reference artifact's generation stamp.
        public let generated: String?
        /// The form the scope and the reference were both counted in (#1608). `.printed` is the
        /// fallback of a launch with no lemmatiser, and every surface that shows or exports such a
        /// ranking says so: `WordCloudDisplayState.comparedAsPrintedNote(_:)` and its export forms.
        public let wordForm: WordCloudWordForm

        /// A reading of `scores`, spelt out so a host can make one (FRUS Explorer Light, S29b).
        public init(scores: [KeynessScore], candidateCount: Int, rankedAmongTopFrequent: Bool,
                    minimumScopeCount: Int, referenceRetained: Int, referenceDistinct: Int,
                    referenceCutoffCount: Int, generated: String?, wordForm: WordCloudWordForm) {
            self.scores = scores
            self.candidateCount = candidateCount
            self.rankedAmongTopFrequent = rankedAmongTopFrequent
            self.minimumScopeCount = minimumScopeCount
            self.referenceRetained = referenceRetained
            self.referenceDistinct = referenceDistinct
            self.referenceCutoffCount = referenceCutoffCount
            self.generated = generated
            self.wordForm = wordForm
        }

        /// Whether this term's reference count of zero means *unpriced* rather than *unused*.
        ///
        /// The reference keeps a truncated head of the corpus vocabulary, so a word rarer than
        /// ``referenceCutoffCount`` is absent from it without being absent from the corpus.
        /// Printing a bare "0 corpus-wide" for such a word asserts something the artifact cannot
        /// support, and it is exactly the word a high keyness score will have floated to the top.
        public func isUnpriced(_ score: KeynessScore) -> Bool {
            score.referenceCount == 0 && referenceCutoffCount > 1
        }
    }

    /// Why a keyness reading could not be produced.
    public enum Unavailable: Equatable, Sendable {
        /// No verdict yet — the first recompute has not run, or the bundled reference is still
        /// decoding off the main actor. Distinct from ``noArtifact`` because "not yet" and "never"
        /// are different claims and only one of them is a failure.
        case pending
        /// The bundled reference is missing or would not decode.
        case noArtifact
        /// The generator does not price this lens. The three entity lenses, by construction.
        case lensNotPriced(WordCloudLens)
        /// The live tokenisation is not comparable to the reference's.
        case configurationMismatch([KeynessBaselineFile.Configuration.Mismatch])
        /// The scope has no reference it can be compared with, and no setting fixes it, so it has
        /// its own message rather than joining ``configurationMismatch`` (#1373). Since #1608 a
        /// scope counted without the lemmatiser is ranked against the reference counted as printed;
        /// this remains for a part-of-speech lens counted without lexical classes, and for a scope
        /// counted as printed on a launch whose printed-form reference did not load.
        case languageAnalysisUnavailable
        /// Nothing in the scope occurs often enough to be scored.
        case noTermsAboveFloor(minimum: Int)
        /// Every scored term is under-represented — the scope has no distinctive vocabulary of its
        /// own relative to the corpus. Rare, but not an error, and quite different from an empty
        /// scope.
        case nothingOverRepresented
    }

    /// The outcome of asking for a keyness reading.
    public enum Outcome: Equatable, Sendable {
        case ranked(Ranking)
        case unavailable(Unavailable)

        /// The outcome to show before any verdict exists.
        public static let pending = Outcome.unavailable(.pending)
    }

    // MARK: - Ranking

    /// Ranks a computed cloud's terms by keyness against the corpus reference `references` holds for the
    /// scope, or says why there is none: the lookup (`KeynessReferences.baseline(for:tuning:includeDiplomatic:languageAnalysis:tokenizer:)`)
    /// and then ``rank(terms:scopeTotal:fetchedTermCount:termLimit:availability:minimumScopeCount:)``.
    ///
    /// A host passes the references its own tokenizer counted and its tagger's identity, so a reference
    /// another tokenizer counted refuses the scope (`Mismatch.tokenizer`); the app ranks against its
    /// bundled references, for NaturalLanguage's counts, through its own `rank`.
    ///
    /// - Parameters:
    ///   - terms: The scope's terms, as the cloud computed them — already truncated to the cloud's
    ///     limit, and already minus any words hidden from this cloud.
    ///   - scopeTotal: The scope's **true** token total. `WordCloudResult.totalTokenCount` is
    ///     accumulated across every document before truncation, so it is the right value; the sum of
    ///     `terms` is not, and would inflate every relative frequency.
    ///   - fetchedTermCount: How many terms the cloud actually FETCHED, before any per-cloud
    ///     hides. `terms` is the post-hide set, and judging truncation from it is wrong: hiding a
    ///     single word takes a full 220-term fetch to 219 and would flip the disclosure from
    ///     "ranked among the top 220" to "ranked over everything", which is false.
    ///   - termLimit: The limit the cloud requested, so a ranking can tell whether the candidate set
    ///     was cut by that limit or by the floor.
    ///   - lens: The lens the terms were counted under.
    ///   - tuning: The **live** tuning the terms were counted under — not `.standard`. The reference
    ///     is fixed at build time while the app's tokenizer follows user settings, and this is the
    ///     value that decides whether the two are comparable.
    ///   - includeDiplomatic: Whether the diplomatic stopword layer was active. In this codebase
    ///     that is the `excludeBoilerplate` setting **verbatim, not inverted** — see
    ///     `WordCloudLoader.load`.
    ///   - languageAnalysis: What the tagger could do when `terms` were counted — the result's own
    ///     `WordCloudResult.languageAnalysis`, not this process's verdict, since a cloud read from
    ///     the disk cache was counted by another process (#1373). It also chooses the reference
    ///     (#1608): `WordFrequencyService` counts a scope in the verdict's own form, and the
    ///     reference counted in that form is the one read.
    ///   - references: The corpus references to rank against, by the form their words are counted in.
    ///   - tokenizer: The tokenizer `terms` were counted by (S29a).
    ///   - minimumScopeCount: The fewest occurrences in the scope a term needs to be scored.
    public static func rank(
        terms: [TermCount],
        scopeTotal: Int,
        fetchedTermCount: Int,
        termLimit: Int,
        lens: WordCloudLens,
        tuning: WordCloudTuning,
        includeDiplomatic: Bool,
        languageAnalysis: NaturalLanguageHealth,
        references: KeynessReferences,
        tokenizer: WordCloudTokenizerIdentity,
        minimumScopeCount: Int = Keyness.defaultMinimumScopeCount
    ) -> Outcome {
        rank(terms: terms, scopeTotal: scopeTotal, fetchedTermCount: fetchedTermCount, termLimit: termLimit,
             availability: references.baseline(for: lens, tuning: tuning, includeDiplomatic: includeDiplomatic,
                                               languageAnalysis: languageAnalysis, tokenizer: tokenizer),
             minimumScopeCount: minimumScopeCount)
    }

    /// Ranks a computed cloud's terms by keyness against the reference a lookup found for the scope, or
    /// gives the lookup's refusal: the ranking itself, which every form of `rank` comes to.
    ///
    /// - Parameters:
    ///   - terms: The scope's terms, as the cloud computed them — already truncated to the cloud's
    ///     limit, and already minus any words hidden from this cloud.
    ///   - scopeTotal: The scope's **true** token total (`WordCloudResult.totalTokenCount`).
    ///   - fetchedTermCount: How many terms the cloud actually FETCHED, before any per-cloud hides.
    ///   - termLimit: The limit the cloud requested.
    ///   - availability: The lookup's answer for the scope's lens, settings, verdict and tokenizer: a
    ///     reference counted in the scope's form, or why there is none.
    ///   - minimumScopeCount: The fewest occurrences in the scope a term needs to be scored.
    public static func rank(
        terms: [TermCount],
        scopeTotal: Int,
        fetchedTermCount: Int,
        termLimit: Int,
        availability: KeynessReferences.Availability,
        minimumScopeCount: Int = Keyness.defaultMinimumScopeCount
    ) -> Outcome {
        let reference: KeynessReference
        switch availability {
        case .unavailable(.noArtifact):
            return .unavailable(.noArtifact)
        case .unavailable(.lensNotPriced(let lens)):
            return .unavailable(.lensNotPriced(lens))
        case .unavailable(.languageAnalysisUnavailable):
            return .unavailable(.languageAnalysisUnavailable)
        case .unavailable(.configurationMismatch(let mismatches)):
            return .unavailable(.configurationMismatch(mismatches))
        case .available(let found):
            reference = found
        }

        let eligible = terms.filter { $0.count >= minimumScopeCount }
        guard !eligible.isEmpty else {
            return .unavailable(.noTermsAboveFloor(minimum: minimumScopeCount))
        }

        let scopeCounts = Dictionary(terms.map { ($0.term, $0.count) },
                                     uniquingKeysWith: { a, _ in a })
        let scored = Keyness.score(
            scopeCounts: scopeCounts,
            referenceCounts: reference.terms,
            scopeTotal: scopeTotal,
            referenceTotal: reference.totalTokens,
            minimumScopeCount: minimumScopeCount
        )
        let overRepresented = scored.filter(\.isOverused)
        guard !overRepresented.isEmpty else { return .unavailable(.nothingOverRepresented) }

        return .ranked(Ranking(
            scores: overRepresented,
            candidateCount: eligible.count,
            // The cloud asked for `termLimit` terms and got exactly that many, so the frequency cut
            // is what bounded the candidates — some term below it would have been scored otherwise.
            // Got fewer, and the scope simply has no more terms: the ranking is complete under the
            // floor. Judged on the FETCHED count, never on `terms`, which the caller has already
            // filtered — one session hide would otherwise turn a truncated fetch into a claim of
            // completeness.
            rankedAmongTopFrequent: fetchedTermCount >= termLimit,
            minimumScopeCount: minimumScopeCount,
            // All four from the reference that was ranked against, never from a second lookup,
            // which could name the file of the other form (#1608).
            referenceRetained: reference.terms.count,
            referenceDistinct: reference.distinctTerms,
            referenceCutoffCount: reference.cutoffCount,
            generated: reference.generated,
            wordForm: reference.wordForm
        ))
    }

    // MARK: - Layout input

    /// The layout's view of a keyness ranking.
    ///
    /// `WordCloudLayout` sizes by `TermCount.count` — an **Int**, and it returns nothing at all when
    /// the largest is `<= 0` (`WordCloudLayout.place`). A signed `Double` G² cannot be handed to it
    /// directly. Scores are scaled by 100 and floored at 1 so ordering and relative magnitude
    /// survive the conversion; the layout's own `sqrt` curve then does the tail compression it does
    /// for frequency.
    ///
    /// These counts are **layout input only**. `PlacedWord` carries just a term, a size and a
    /// position, so no scaled score reaches the screen — which matters, because a list rendering
    /// them under the existing "%lld occurrences" label would state a falsehood.
    public static func layoutTerms(_ scores: [KeynessScore]) -> [TermCount] {
        scores.map { TermCount(term: $0.term, count: max(1, Int(($0.logLikelihood * 100).rounded()))) }
    }
}
