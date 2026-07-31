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

// MARK: - CollocationWindow

/// The text lying within ±N words of a query's matches in one document.
///
/// The inverse of the concordance: where `KWICBuilder` shows *each* occurrence in context for
/// reading, this collects the neighbourhoods for *counting*.
///
/// ## Words, not characters
/// `KWICBuilder`'s radius is characters, snapped outward to a word boundary — right for a readable
/// line, wrong for a measure. "Within ten words" is what a researcher means and what a proximity
/// operator counts, so the window here is a count of words.
///
/// ## Overlapping windows are MERGED, not double-counted
/// Two matches within 2N words share neighbours. Counting a shared word once per match inflates it
/// exactly where the query term is dense — which is exactly where a researcher is most likely to be
/// looking. So the windows are unioned and every token is counted once.
///
/// The choice matters less than its consistency: the same merge decides both the counts and the
/// total they are divided by. Applying it to one and not the other is invisible on screen and wrong
/// everywhere.
///
/// Version history:
///   1.0 — S-2: initial implementation
enum CollocationWindow {

    /// One document's contribution.
    struct DocumentScan: Equatable {
        /// The merged window text, as runs of the document's own prose. Runs are kept separate
        /// rather than concatenated so a caller can join them with a break the lemmatiser will
        /// respect — splicing two distant passages into one sentence invents adjacency.
        let runs: [String]
        /// How many matches of the query were found.
        let anchorCount: Int
        /// Matches beyond ``maxAnchorsPerDocument`` that contributed no window.
        let omittedAnchorCount: Int
    }

    /// Matches counted per document before the rest are dropped.
    ///
    /// A single memo that uses the query term two hundred times would otherwise dominate a
    /// collocation over a thousand documents, and the result would describe that memo's habits
    /// rather than the corpus's. Bounded, and the omission is reported rather than absorbed.
    static let maxAnchorsPerDocument = 200

    /// Collects the merged ±`windowSize`-word neighbourhoods of every match in `body`.
    ///
    /// - Parameters:
    ///   - body: the document's indexed text.
    ///   - stems: Porter stems of the query's positive terms — the same set the concordance and the
    ///     highlighter match on, so the words treated as matches here are the words the reader sees
    ///     highlighted.
    ///   - windowSize: how many words either side of a match to collect.
    static func scan(body: String, stems: [String], windowSize: Int) -> DocumentScan {
        guard !body.isEmpty, !stems.isEmpty, windowSize > 0 else {
            return DocumentScan(runs: [], anchorCount: 0, omittedAnchorCount: 0)
        }
        let stemSet = Set(stems)
        // The same near-free rejection the highlighter and KWIC use: Porter only rewrites suffixes,
        // so a word whose first character is not among the stems' first characters cannot stem to
        // one. Worth far more here than in KWIC — this runs over a whole result set.
        let firstLetters = Set(stemSet.compactMap { $0.first })

        // One pass, recording each word's range. Deliberately NOT `Array(body)` the way KWIC does:
        // a `Character` is 16 bytes, so a 1.2 MB document — and the corpus has one — would
        // materialise ~20 MB before a single word was examined, on a path that runs over hundreds
        // of documents.
        var wordRanges: [Range<String.Index>] = []
        var anchorPositions: [Int] = []
        var index = body.startIndex
        while index < body.endIndex {
            guard body[index].isLetter || body[index].isNumber else {
                index = body.index(after: index)
                continue
            }
            let wordStart = index
            while index < body.endIndex, body[index].isLetter || body[index].isNumber {
                index = body.index(after: index)
            }
            let range = wordStart..<index
            if let first = body[range].first?.lowercased().first, firstLetters.contains(first),
               stemSet.contains(PorterStemmer.stem(body[range].lowercased())) {
                anchorPositions.append(wordRanges.count)
            }
            wordRanges.append(range)
        }

        guard !anchorPositions.isEmpty else {
            return DocumentScan(runs: [], anchorCount: 0, omittedAnchorCount: 0)
        }
        let used = anchorPositions.prefix(maxAnchorsPerDocument)
        let anchorSet = Set(anchorPositions)

        // Union the windows into covered word indices, then walk them once in order. The anchor's
        // own position is excluded: it is the centre, not a neighbour, and leaving it in makes every
        // query term the top collocate of itself.
        var covered = Set<Int>()
        for position in used {
            let lower = max(0, position - windowSize)
            let upper = min(wordRanges.count - 1, position + windowSize)
            for i in lower...upper where !anchorSet.contains(i) { covered.insert(i) }
        }
        guard !covered.isEmpty else {
            return DocumentScan(runs: [], anchorCount: anchorPositions.count,
                                omittedAnchorCount: max(0, anchorPositions.count - used.count))
        }

        // Contiguous runs become one span of the document's own text, punctuation and all, so the
        // lemmatiser sees prose rather than a word list. A gap starts a new run.
        var runs: [String] = []
        var runStart = -1
        var previous = -2
        for i in covered.sorted() {
            if i != previous + 1 {
                if runStart >= 0 {
                    runs.append(String(body[wordRanges[runStart].lowerBound..<wordRanges[previous].upperBound]))
                }
                runStart = i
            }
            previous = i
        }
        if runStart >= 0 {
            runs.append(String(body[wordRanges[runStart].lowerBound..<wordRanges[previous].upperBound]))
        }
        return DocumentScan(runs: runs, anchorCount: anchorPositions.count,
                            omittedAnchorCount: max(0, anchorPositions.count - used.count))
    }
}

// MARK: - CollocationResult

/// What appears near a query's matches, ranked by how distinctive it is of that neighbourhood.
///
/// Version history:
///   1.0 — S-2: initial implementation
struct CollocationResult: Equatable {

    /// Neighbours over-represented beside the query, most distinctive first.
    let scores: [KeynessScore]
    /// Words either side of each match that were collected.
    let windowSize: Int
    /// Documents whose text was actually scanned.
    let documentsScanned: Int
    /// Documents in the result set. Larger than ``documentsScanned`` when a bound stopped the scan.
    let documentsInScope: Int
    /// Matches found across the scanned documents.
    let anchorCount: Int
    /// Matches dropped by the per-document bound.
    let omittedAnchorCount: Int
    /// Surviving tokens inside the merged windows — the denominator the scores divide by.
    let windowTokenCount: Int
    /// The floor a neighbour had to clear to be ranked.
    let minimumCount: Int
    /// The smallest corpus count the reference prices; below it a neighbour is *unpriced*.
    let referenceCutoffCount: Int
    /// The reference artifact's generation stamp.
    let generated: String?

    /// Whether a bound stopped the scan short of the whole result set.
    var wasBounded: Bool { documentsScanned < documentsInScope }
}

// MARK: - CollocationAnalysis

/// Builds a ``CollocationResult`` from window text.
///
/// Kept separate from the scan so the statistical half is testable without a database: the scan
/// turns documents into window text, this turns window text into a ranking.
///
/// ## Why not `KeynessCloud.rank`
/// That entry point is documented as "a re-ranking, not a second computation" over the word cloud's
/// already-truncated top-N list, and three of its parameters exist to describe that truncation.
/// Collocation counts its own tokens from scratch and truncates nothing, so it scores through
/// `Keyness` directly and reports its own bounds.
///
/// Version history:
///   1.0 — S-2: initial implementation
enum CollocationAnalysis {

    /// Why a collocation could not be produced.
    enum Unavailable: Equatable {
        /// No verdict yet.
        case pending
        /// The bundled reference is missing or would not decode.
        case noArtifact
        /// The live tokenisation is not comparable to the reference's.
        case configurationMismatch([KeynessBaselineFile.Configuration.Mismatch])
        /// The query matched nothing whose neighbourhood could be collected.
        case noMatches
        /// Neighbours were collected, but none occurs often enough to be ranked.
        case noNeighboursAboveFloor(minimum: Int)
        /// Every neighbour is *under*-represented — the query sits in ordinary prose.
        case nothingDistinctive
    }

    /// The outcome of asking what appears near a query.
    enum Outcome: Equatable {
        case ranked(CollocationResult)
        case unavailable(Unavailable)

        /// The outcome to show before any verdict exists.
        static let pending = Outcome.unavailable(.pending)
    }

    /// Tokenises window text and ranks it against the corpus reference.
    ///
    /// - Parameters:
    ///   - counts: lemma → occurrences inside the merged windows, produced by the caller with
    ///     ``WordCloudTokenizer/accumulate(from:into:)`` so the terms are in the same form the
    ///     reference is keyed by. Counting them any other way — Porter stems, raw words — compares
    ///     two different vocabularies and fails systematically.
    ///   - windowTokenCount: surviving tokens across those same windows. `accumulate` returns it;
    ///     it is the denominator, and it must come from the same merge policy as `counts`.
    ///   - anchorLemmas: the query terms in lemma form, excluded from the ranking. A term is not a
    ///     collocate of itself, and with two matches within 2N words each would otherwise appear in
    ///     the other's window.
    ///   - reference: the corpus counts and true total, from ``BundledKeynessBaseline``.
    static func rank(
        counts: [String: Int],
        windowTokenCount: Int,
        anchorLemmas: Set<String>,
        windowSize: Int,
        documentsScanned: Int,
        documentsInScope: Int,
        anchorCount: Int,
        omittedAnchorCount: Int,
        reference: (terms: [String: Int], totalTokens: Int, cutoffCount: Int),
        generated: String?,
        minimumCount: Int = Keyness.defaultMinimumScopeCount
    ) -> Outcome {
        guard anchorCount > 0, windowTokenCount > 0, !counts.isEmpty else {
            return .unavailable(.noMatches)
        }
        let neighbours = counts.filter { !anchorLemmas.contains($0.key) }
        guard neighbours.values.contains(where: { $0 >= minimumCount }) else {
            return .unavailable(.noNeighboursAboveFloor(minimum: minimumCount))
        }
        let scored = Keyness.score(
            scopeCounts: neighbours,
            referenceCounts: reference.terms,
            scopeTotal: windowTokenCount,
            referenceTotal: reference.totalTokens,
            minimumScopeCount: minimumCount
        )
        let overRepresented = scored.filter(\.isOverused)
        guard !overRepresented.isEmpty else { return .unavailable(.nothingDistinctive) }

        return .ranked(CollocationResult(
            scores: overRepresented,
            windowSize: windowSize,
            documentsScanned: documentsScanned,
            documentsInScope: documentsInScope,
            anchorCount: anchorCount,
            omittedAnchorCount: omittedAnchorCount,
            windowTokenCount: windowTokenCount,
            minimumCount: minimumCount,
            referenceCutoffCount: reference.cutoffCount,
            generated: generated
        ))
    }
}
