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

/// The "why related" evidence for a semantic row: the distinctive vocabulary two documents share.
///
/// ## Why this exists
///
/// A cosine explains nothing. Every other axis can name its evidence — *these two are cited
/// together*, *they come from the same lot file*, *they are eleven days apart* — and an unexplained
/// row reads as noise. The design (`Vector-Embeddings-Semantic-Design.md` §6.1) asks for the shared
/// *distinctive* terms instead, computed **at render time for the displayed rows only**, because
/// both documents' texts are on device by definition: each passed the `document_cache` fence to be
/// shown at all.
///
/// ## Distinctive, not merely shared
///
/// Two FRUS documents share "government" and "department" the way two English sentences share "the".
/// A term earns its place in the chip by being rare *corpus-wide* while present in both documents, so
/// the ranking is by the corpus frequency `BundledKeynessBaseline` already ships. Where that baseline
/// is unavailable — no artifact, or a tokenisation configuration it was not built under — this
/// returns nothing rather than a list ranked by an unpriced guess, and the caller falls back to
/// stating the percentage.
///
/// ## A launch with no lemmatiser compares printed forms (#1608)
///
/// From #1373 such a launch had no chip at all: printed forms ranked against lemma counts would
/// skip every inflected word as unpriced and name only the uninflected ones. Now both documents
/// are counted as printed and ranked by the reference counted as printed, so two documents share a
/// word where both print the same form — `negotiate` in one and `negotiated` in the other is no
/// longer a shared word — and ``Evidence/printedFormsNote`` is what the panel says about it. The
/// chip still wears the anchor's own spelling, so a form the plural fold clipped (`dulle`) is shown
/// as the page prints it (`Dulles`).
///
/// ## The display form is the anchor's own spelling
///
/// `WordCloudTokenizer` emits **lowercased lemmas**, which is right for counting and wrong for a
/// chip: the ship *Kearsarge* would be printed `kearsarge`, and a reader would reasonably conclude
/// the app had mangled it. Each surviving term is therefore looked back up in the anchor's own text
/// and shown in the casing it appears there. That is what the design means by "display forms from
/// the anchor's own text — never stems".
///
/// ## An observation the first sample turned up, left unfixed on purpose
///
/// Ranking by corpus rarity often surfaces **personal names** — a pair may share `Francis` and
/// `William` before it shares any topical vocabulary. That is not wrong (two documents about the
/// same people are related, and the chip says what it measured), but it does overlap the separate
/// `sharedPersons` axis, and a chip that mostly names people tells a reader less than one naming
/// subject matter. Filtering names out would need a second `NLTagger` entity pass per document, and
/// which behaviour a historian prefers is exactly the sort of question the tester feedback path
/// exists to answer. Recorded here rather than guessed at.
///
/// Version history:
///   1.0 — V-3 follow-up: initial implementation
///   1.1 — #1373: no chip when this process's tagger cannot lemmatise
///   1.2 — #1608: with no lemmatiser the chip compares printed forms against the reference counted
///          as printed, and ``sharedTerms(anchor:candidates:appState:)`` returns the form with the
///          terms (``Evidence``); ``reloadToken(for:)``, the part of Related Documents' reload
///          identity that follows the tagger
///   1.3 — 2026-11-24 (FRUS Explorer Light, S29b): moved into FRUSCoreKit, public: the pass counts with the
///          tagger and the stopwords its caller gives (``evidence(anchor:candidates:pipeline:reference:stopwords:tagger:isolation:)``),
///          and a host's entry reads its own references (``sharedTerms(anchor:candidates:pipeline:references:languageAnalysis:stopwords:tagger:isolation:)``);
///          the app's entry over `AppState`, its pass behind NaturalLanguage's gate and the reload identity
///          stay the app's
public enum SemanticSharedTerms {

    /// What one pass found: each candidate's shared terms, and the form the words were compared in
    /// (#1608).
    public struct Evidence: Equatable, Sendable {
        /// Display-form terms per candidate; a candidate with no distinctive overlap is absent.
        public let terms: [DocumentKey: [String]]
        /// The form both documents' words and the corpus reference were counted in.
        public let wordForm: WordCloudWordForm

        /// What one pass found, spelt out so a host can make one (FRUS Explorer Light, S29b).
        public init(terms: [DocumentKey: [String]], wordForm: WordCloudWordForm) {
            self.terms = terms
            self.wordForm = wordForm
        }

        /// A pass that could not run: no candidates, no index, no reference, or no text for the
        /// anchor. It compared nothing, so it says nothing of how.
        public static let none = Evidence(terms: [:], wordForm: .dictionary)

        /// What the panel says above its rows when their shared words were compared as printed, or
        /// `nil` when they were compared in dictionary forms (#1608).
        ///
        /// The owner's condition for the fallback: that it happened, why, and that the result can
        /// differ from a device whose language analysis reduces words to their dictionary forms.
        ///
        /// It does not ask whether any row got a chip. A pass that compared printed forms and found
        /// no shared word leaves every row with a percentage where a device that reduces words can
        /// name the words, and this line is then the only thing that says why. A pass that could
        /// not run is ``none``, whose form is `.dictionary`, and says nothing.
        public var printedFormsNote: String? {
            guard wordForm == .printed else { return nil }
            return String(localized: "related.sharedTerms.printedForms.note",
                          defaultValue: "Shared words compared as printed: this device’s language analysis isn’t reducing words to their dictionary forms right now, so two documents share a word only where both print the same form (“negotiate” in one and “negotiated” in the other is not a match). A device that does reduce them (a Mac, or another iPhone or iPad) can name different shared words.")
        }
    }

    /// How many terms a chip shows. Three is what fits beside the other axes' chips on an iPhone.
    public static let chipTermLimit = 3

    /// The lens the chip counts under.
    ///
    /// `.allTerms` rather than a curated lens: the point is distinctive vocabulary, and the concept
    /// and sentiment lexicons would throw away exactly the proper nouns and rare technical terms that
    /// make a chip informative. It is also the lens `BundledKeynessBaseline` prices most fully
    /// (98.1% of corpus token mass).
    public static let lens: WordCloudLens = .allTerms

    /// Computes the shared distinctive terms between an anchor and each candidate, for a host: the
    /// reference its own references hold for its verdict and its tagger's identity, then the pass
    /// (FRUS Explorer Light, S29b).
    ///
    /// The app's entry, `sharedTerms(anchor:candidates:appState:)`, does the same over its bundled
    /// references, NaturalLanguage's verdict and its gate. Unavailable means unpriced, not "every term is
    /// rare": with no reference the host can be compared with, the pass names nothing and the caller falls
    /// back to stating the percentage.
    ///
    /// - Parameters:
    ///   - anchor: The document the rows are related to.
    ///   - candidates: The displayed candidates to explain.
    ///   - pipeline: The index the texts are read from.
    ///   - references: The corpus references the host's tokenizer counted.
    ///   - languageAnalysis: The verdict the terms are counted under: the host tagger's health.
    ///   - stopwords: The stopword lists the tokenizer reads.
    ///   - tagger: The tagger whose walks the tokenizer reads; its identity chooses the reference.
    ///   - isolation: Where the pass runs: its caller's actor, by default.
    /// - Returns: Display-form terms per candidate, and the form they were compared in.
    public static func sharedTerms<Tagger: WordCloudTagger>(
        anchor: DocumentKey,
        candidates: [DocumentKey],
        pipeline: IndexingPipeline,
        references: KeynessReferences,
        languageAnalysis: NaturalLanguageHealth,
        stopwords: WordCloudStopwordSet,
        tagger: Tagger,
        isolation: isolated (any Actor)? = #isolation
    ) async -> Evidence {
        guard !candidates.isEmpty else { return .none }
        // The chip's reference, as the app reads it: All terms at the standard tuning with the
        // diplomatic layer, in the verdict's form, counted by this tagger.
        guard case .available(let reference) = references.baseline(
            for: lens, tuning: .standard, includeDiplomatic: true,
            languageAnalysis: languageAnalysis, tokenizer: tagger.identity)
        else { return .none }
        return await evidence(anchor: anchor, candidates: candidates, pipeline: pipeline,
                              reference: reference, stopwords: stopwords, tagger: tagger)
    }

    /// The pass itself, against a reference the caller read: fetch the texts, count each in the
    /// reference's form, and name the rarest words the anchor shares with each candidate.
    ///
    /// ``sharedTerms(anchor:candidates:pipeline:references:languageAnalysis:stopwords:tagger:isolation:)``
    /// reads the reference for a host's verdict and calls it, and so does the app's entry, through its own
    /// `evidence(anchor:candidates:pipeline:reference:)`, which awaits NaturalLanguage's readiness gate
    /// first (#1373) and passes NaturalLanguage's tagger and the bundled stopwords. It is a function of its
    /// own so a test can run the pass in a form its host's verdict would not choose (#1608).
    ///
    /// - Parameters:
    ///   - anchor: The document the rows are related to.
    ///   - candidates: The displayed candidates to explain.
    ///   - pipeline: The index the texts are read from.
    ///   - reference: The corpus reference, which also fixes the form the texts are counted in.
    ///   - stopwords: The stopword lists the tokenizer reads (the app's bundled `word-cloud-stopwords.json`).
    ///   - tagger: The tagger whose walks the tokenizer reads (S29a). A tagger that warms up before its
    ///     first walk is awaited by its host first; the app's form awaits NaturalLanguage's gate.
    ///   - isolation: Where the pass runs: its caller's actor, by default, as it ran on the main actor
    ///     for the app before it moved (FRUS Explorer Light, S29b).
    /// - Returns: Display-form terms per candidate, and the reference's form.
    public static func evidence<Tagger: WordCloudTagger>(
        anchor: DocumentKey,
        candidates: [DocumentKey],
        pipeline: IndexingPipeline,
        reference: KeynessReference,
        stopwords: WordCloudStopwordSet,
        tagger: Tagger,
        isolation: isolated (any Actor)? = #isolation
    ) async -> Evidence {
        let tuning = WordCloudTuning.standard
        let keys = ([anchor] + candidates).map {
            WordCloudDocumentKey(volumeId: $0.volumeId, documentId: $0.documentId)
        }
        guard let texts = try? await pipeline.documentBodyTextsByKey(forKeys: keys),
              let anchorText = texts["\(anchor.volumeId)/\(anchor.documentId)"],
              !anchorText.isEmpty
        else { return .none }

        let tokenizer = WordCloudTokenizer(
            stopwords: stopwords.active(includeDiplomatic: true),
            minimumLength: tuning.minimumLength,
            foldPlurals: tuning.foldPlurals,
            lens: lens,
            // .allTerms is not a lexicon-backed lens, so no membership set applies.
            lexicon: nil,
            markings: tuning.filterMarkings ? stopwords.markings : [],
            // The reference's own form, so the two documents are counted the way it was (#1608).
            wordForm: reference.wordForm)

        var anchorCounts: [String: Int] = [:]
        tokenizer.accumulate(from: anchorText, into: &anchorCounts, tagger: tagger)
        guard !anchorCounts.isEmpty else { return .none }

        var result: [DocumentKey: [String]] = [:]
        for candidate in candidates {
            guard let text = texts["\(candidate.volumeId)/\(candidate.documentId)"],
                  !text.isEmpty else { continue }
            var candidateCounts: [String: Int] = [:]
            tokenizer.accumulate(from: text, into: &candidateCounts, tagger: tagger)

            let terms = rank(
                shared: Set(anchorCounts.keys).intersection(candidateCounts.keys),
                corpusCounts: reference.terms, limit: chipTermLimit)
            guard !terms.isEmpty else { continue }
            result[candidate] = terms.map { displayForm(for: $0, in: anchorText) }
        }
        return Evidence(terms: result, wordForm: reference.wordForm)
    }

    /// Ranks shared terms by corpus rarity and returns the most distinctive.
    ///
    /// A term the baseline does not price is **skipped, not treated as maximally rare**. The
    /// artifact retains a 20,000-term head, so an unpriced term means "rarer than the cutoff *or*
    /// absent from the corpus entirely" — and the second reading includes tokenisation debris, which
    /// would otherwise dominate every chip precisely because it is meaningless.
    ///
    /// - Parameters:
    ///   - shared: Terms present in both documents.
    ///   - corpusCounts: The baseline's corpus frequencies.
    ///   - limit: How many terms to return.
    /// - Returns: The rarest shared terms, rarest first, tie-broken alphabetically for determinism.
    public static func rank(shared: Set<String>, corpusCounts: [String: Int], limit: Int) -> [String] {
        var priced: [(term: String, count: Int)] = []
        priced.reserveCapacity(shared.count)
        for term in shared {
            guard let count = corpusCounts[term], count > 0 else { continue }
            priced.append((term: term, count: count))
        }
        priced.sort { $0.count == $1.count ? $0.term < $1.term : $0.count < $1.count }
        return priced.prefix(limit).map(\.term)
    }

    /// The casing a term wears in the anchor's own text.
    ///
    /// The tokenizer lowercases and lemmatises, so this searches the source for the first
    /// word-boundary occurrence and returns that substring. A lemma with no surface match — "be" for
    /// "was" — falls back to the lemma, which is why the ranking above prefers rare terms: a lemma
    /// that far from its surface form is almost always a common word that never reaches the chip.
    /// A term counted as printed (#1608) is the surface form already, or that form with its plural
    /// folded, and the same search finds it: `dulle` is shown as `Dulles`.
    ///
    /// - Parameters:
    ///   - term: A lowercased lemma, or a lowercased printed form.
    ///   - text: The anchor's body text.
    /// - Returns: The display form.
    public static func displayForm(for term: String, in text: String) -> String {
        guard let range = text.range(of: term, options: [.caseInsensitive, .diacriticInsensitive])
        else { return term }
        // Extend to the whole word so a lemma matched inside a longer surface form ("alliance"
        // inside "alliances") is shown as the reader will find it on the page.
        var start = range.lowerBound
        while start > text.startIndex {
            let previous = text.index(before: start)
            guard text[previous].isLetter else { break }
            start = previous
        }
        var end = range.upperBound
        while end < text.endIndex, text[end].isLetter { end = text.index(after: end) }
        let surface = String(text[start..<end])
        // A surface far longer than the lemma is a different word that merely contains it
        // ("ration" inside "corporations"); prefer the lemma over a misleading display form.
        guard surface.count <= term.count + 3 else { return term }
        return surface
    }
}
