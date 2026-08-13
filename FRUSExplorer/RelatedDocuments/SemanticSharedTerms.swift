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
enum SemanticSharedTerms {

    /// How many terms a chip shows. Three is what fits beside the other axes' chips on an iPhone.
    static let chipTermLimit = 3

    /// The lens the chip counts under.
    ///
    /// `.allTerms` rather than a curated lens: the point is distinctive vocabulary, and the concept
    /// and sentiment lexicons would throw away exactly the proper nouns and rare technical terms that
    /// make a chip informative. It is also the lens `BundledKeynessBaseline` prices most fully
    /// (98.1% of corpus token mass).
    static let lens: WordCloudLens = .allTerms

    /// Computes the shared distinctive terms between an anchor and each candidate.
    ///
    /// Reads every text in one keyed query and tokenises each document once, so the cost is linear in
    /// the displayed rows rather than quadratic. The lexical assessment measured this class of query
    /// at ~50 ms for a comparable row count.
    ///
    /// - Parameters:
    ///   - anchor: The document the rows are related to.
    ///   - candidates: The displayed candidates to explain.
    ///   - appState: Supplies the index and the tokenisation payloads.
    /// - Returns: Display-form terms per candidate; a candidate with no distinctive overlap is
    ///   absent from the result rather than present with an empty list.
    @MainActor
    static func sharedTerms(
        anchor: DocumentKey,
        candidates: [DocumentKey],
        appState: AppState
    ) async -> [DocumentKey: [String]] {
        guard !candidates.isEmpty, let pipeline = appState.indexingPipeline else { return [:] }

        // The corpus reference. Unavailable means unpriced, not "every term is rare" — ranking
        // without it would put the anchor's most ordinary words first.
        let tuning = WordCloudTuning.standard
        guard case .available(let corpusCounts, _, _) = BundledKeynessBaseline.baseline(
            for: lens, tuning: tuning, includeDiplomatic: true)
        else { return [:] }

        let keys = ([anchor] + candidates).map {
            WordCloudDocumentKey(volumeId: $0.volumeId, documentId: $0.documentId)
        }
        guard let texts = try? await pipeline.documentBodyTextsByKey(forKeys: keys),
              let anchorText = texts["\(anchor.volumeId)/\(anchor.documentId)"],
              !anchorText.isEmpty
        else { return [:] }

        let tokenizer = WordCloudTokenizer(
            stopwords: WordCloudStopwords.active(includeDiplomatic: true),
            minimumLength: tuning.minimumLength,
            foldPlurals: tuning.foldPlurals,
            lens: lens,
            // .allTerms is not a lexicon-backed lens, so no membership set applies.
            lexicon: nil,
            markings: tuning.filterMarkings ? WordCloudStopwords.markings : [])

        var anchorCounts: [String: Int] = [:]
        tokenizer.accumulate(from: anchorText, into: &anchorCounts)
        guard !anchorCounts.isEmpty else { return [:] }

        var result: [DocumentKey: [String]] = [:]
        for candidate in candidates {
            guard let text = texts["\(candidate.volumeId)/\(candidate.documentId)"],
                  !text.isEmpty else { continue }
            var candidateCounts: [String: Int] = [:]
            tokenizer.accumulate(from: text, into: &candidateCounts)

            let terms = rank(
                shared: Set(anchorCounts.keys).intersection(candidateCounts.keys),
                corpusCounts: corpusCounts, limit: chipTermLimit)
            guard !terms.isEmpty else { continue }
            result[candidate] = terms.map { displayForm(for: $0, in: anchorText) }
        }
        return result
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
    static func rank(shared: Set<String>, corpusCounts: [String: Int], limit: Int) -> [String] {
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
    ///
    /// - Parameters:
    ///   - term: A lowercased lemma.
    ///   - text: The anchor's body text.
    /// - Returns: The display form.
    static func displayForm(for term: String, in text: String) -> String {
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
