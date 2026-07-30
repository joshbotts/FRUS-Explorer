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
import WordCloudKit

/// Rolls per-volume term counts up to subseries and corpus, and packs them into the two
/// bundled artifacts.
///
/// ## Summing is exact
/// Because ``CloudVectorsFile`` stores raw counts rather than normalised weights, a
/// subseries is the term-wise sum of its volumes and the corpus is the sum of everything —
/// no re-derivation from percentages, no drift. This is the whole reason for the schema
/// decision; see ``CloudVectorsFile``.
///
/// **Aggregate before truncating.** Rolling up already-truncated top-50 lists would lose
/// every term that is 51st in each of forty volumes but would rank 10th across the
/// subseries. Truncation happens once, at pack time, per scope.
///
/// ## Known divergence from the live cloud
/// These vectors will not reproduce the app's Word Cloud for the same volume, for three
/// reasons that no amount of care removes:
/// 1. **Different input text.** The app tokenises FTS5 `body_text` from the parsed AST;
///    this tokenises a byte-scanned approximation of it (see ``TEIBodyTextExtractor``).
/// 2. **User settings are inputs.** Tuning, custom stop lists, and per-scope hidden words
///    are all live; a build-time artifact cannot follow them.
/// 3. **Coverage.** The app counts only *indexed* documents. Someone with 3 of a
///    subseries' 44 volumes sees a 3-volume cloud; this vector covers all 44.
///
/// What *is* guaranteed is tokenizer parity — same text and same sets in, same counts out —
/// pinned by `WordCloudKitTests`.
///
/// Version history:
///   1.0 — O-1: initial implementation
public struct CloudVectorsAggregator: Sendable {

    /// The scope key used for the whole-corpus vectors.
    public static let corpusScopeKey = "corpus"

    /// Terms kept per (scope, lens). The hand-off asks for ~50, of which ~25 are drawn.
    public static let topTermsPerList = 50

    /// Schema version written into every file.
    public static let schemaVersion = 1

    /// A volume's raw counts, before any roll-up.
    public struct VolumeCounts: Sendable {
        /// The manifest volume id (`"frus1969-76v32"`).
        public let volumeId: String
        /// The manifest subseries this volume belongs to (`"1969-76"`).
        public let subseries: String
        /// Number of document divs tokenised.
        public let documentCount: Int
        /// Lens → term → occurrences.
        public let counts: [WordCloudLens: [String: Int]]

        /// Creates a volume's counts.
        public init(volumeId: String, subseries: String, documentCount: Int,
                    counts: [WordCloudLens: [String: Int]]) {
            self.volumeId = volumeId
            self.subseries = subseries
            self.documentCount = documentCount
            self.counts = counts
        }
    }

    /// Nominal terms retained per lens in the keyness baseline.
    ///
    /// Far larger than ``topTermsPerList`` because the two answer different questions: a cloud draws
    /// fifty words, while a baseline must be able to price whatever terms a researcher's documents
    /// contain.
    ///
    /// It is a **size budget, not a claim of coverage**, and the shipped artifact is the honest
    /// account of what it buys: `allTerms` retains 20,000 of 254,027 distinct terms — 7.9% of the
    /// vocabulary, but **98.1% of the token mass** — with the cut landing at a corpus count of 110;
    /// `topics` cuts at 65; `actions` has only 28,062 distinct terms so its cut lands in the
    /// once-only band and takes the whole lens. Everything below those counts is *unpriced*, which
    /// is not the same as absent from the corpus — see ``KeynessBaselineFile/Lens/cutoffCount``.
    /// The trade-off is bundle size against how far down the distribution the reference reaches;
    /// there is no low-frequency floor in the tuning to lean on (`minimumCount` is 1).
    public static let baselineTermsPerLens = 20_000

    /// The artifacts.
    public struct Output: Sendable {
        /// Corpus + every subseries — loaded eagerly by the app.
        public let core: CloudVectorsFile
        /// Every volume — loaded lazily.
        public let volumes: CloudVectorsFile
        /// The corpus keyness baseline (S-1) — the reference side of a keyness comparison.
        public let keynessBaseline: KeynessBaselineFile
    }

    /// The lenses carried, in cycle order.
    public let lenses: [WordCloudLens]
    /// Supplies each sentiment term's polarity.
    public let lexicons: WordCloudLexiconSet

    /// Creates an aggregator.
    public init(lenses: [WordCloudLens] = WordCloudLens.bundledCloudLenses,
                lexicons: WordCloudLexiconSet) {
        self.lenses = lenses
        self.lexicons = lexicons
    }

    /// Rolls `volumes` up and packs both files.
    ///
    /// - Parameters:
    ///   - volumes: Per-volume counts, in any order — output is sorted, so input order
    ///     cannot affect the artifact.
    ///   - generated: Date stamp for the provenance block.
    ///   - tuning: The tuning the counts were produced under, recorded in provenance.
    ///   - configuration: The full tokenisation stamp the keyness baseline pins itself to. Defaults
    ///     to `tuning` with the diplomatic layer on and no payload digests, which is the right shape
    ///     for a unit test but **not** for a shipped artifact — the runner passes real digests.
    public func pack(volumes: [VolumeCounts], generated: String,
                     tuning: WordCloudTuning,
                     configuration: KeynessBaselineFile.Configuration? = nil) -> Output {
        // ── Roll up. Sum raw counts; never sum truncated lists. ──
        var bySubseries: [String: [WordCloudLens: [String: Int]]] = [:]
        var corpus: [WordCloudLens: [String: Int]] = [:]
        for volume in volumes {
            for (lens, terms) in volume.counts {
                for (term, count) in terms {
                    bySubseries[volume.subseries, default: [:]][lens, default: [:]][term, default: 0] += count
                    corpus[lens, default: [:]][term, default: 0] += count
                }
            }
        }

        let documentCount = volumes.reduce(0) { $0 + $1.documentCount }
        let provenance = CloudVectorsFile.Provenance(
            volumeCount: volumes.count,
            documentCount: documentCount,
            tuning: tuning,
            topTermsPerList: Self.topTermsPerList
        )

        var coreScopes: [String: [WordCloudLens: [String: Int]]] = bySubseries
        coreScopes[Self.corpusScopeKey] = corpus

        var volumeScopes: [String: [WordCloudLens: [String: Int]]] = [:]
        for volume in volumes { volumeScopes[volume.volumeId] = volume.counts }

        return Output(
            core: file(scopes: coreScopes, generated: generated, provenance: provenance),
            volumes: file(scopes: volumeScopes, generated: generated, provenance: provenance),
            keynessBaseline: baseline(
                corpus: corpus, generated: generated, provenance: provenance,
                configuration: configuration ?? .init(tuning: tuning, includeDiplomatic: true,
                                                      lexiconsDigest: "", stopwordsDigest: ""))
        )
    }

    /// Builds the keyness baseline from the **untruncated** corpus roll-up.
    ///
    /// Deliberately fed `corpus` before the top-50 truncation the cloud files apply — the whole
    /// point of this artifact is the terms a fifty-word cloud leaves out.
    ///
    /// ## The cut is a frequency, not a rank
    /// A plain `prefix(20_000)` cuts inside a tie, and the tiebreak is alphabetical. In the shipped
    /// corpus that is not academic: `actions` cuts at a count of 1, where 12,364 verbs are tied, so
    /// a rank cut would have priced the 4,302 spelled up to `fenoaltea` and left the 8,062 after it
    /// with no reference at all. Two verbs with identical corpus evidence would then get different
    /// keyness scores because of their first letter. So the prefix is **extended through the whole
    /// tied band**: membership depends only on how often a term occurs. The cost is small (the cap
    /// is a budget, and the band beyond it is short) and the resulting `cutoffCount` is a fact a
    /// caller can state.
    private func baseline(corpus: [WordCloudLens: [String: Int]], generated: String,
                          provenance: CloudVectorsFile.Provenance,
                          configuration: KeynessBaselineFile.Configuration) -> KeynessBaselineFile {
        var lenses: [String: KeynessBaselineFile.Lens] = [:]
        for (lens, terms) in corpus {
            // The true total, summed over EVERY term, before anything is dropped. Computing it from
            // the retained terms instead would inflate every relative frequency, and inflate it by a
            // different factor than the scope side — the precise error keyness exists to avoid.
            let totalTokens = terms.values.reduce(0, +)
            // Count first, then term: the term tiebreak keeps the ordering deterministic, and the
            // band extension below keeps it from deciding membership.
            let ranked = terms.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            var cut = min(Self.baselineTermsPerLens, ranked.count)
            if cut > 0, cut < ranked.count {
                let boundary = ranked[cut - 1].value
                while cut < ranked.count, ranked[cut].value == boundary { cut += 1 }
            }
            let retained = ranked.prefix(cut)
            lenses[lens.rawValue] = KeynessBaselineFile.Lens(
                totalTokens: totalTokens,
                distinctTerms: terms.count,
                terms: Dictionary(uniqueKeysWithValues: retained.map { ($0.key, $0.value) }),
                cutoffCount: retained.last?.value ?? 0
            )
        }
        return KeynessBaselineFile(
            version: 1, generated: generated, provenance: provenance,
            termsPerLens: Self.baselineTermsPerLens, configuration: configuration, lenses: lenses
        )
    }

    // MARK: - Packing

    /// Builds one file: truncates each list, interns its terms, and emits sorted output.
    private func file(scopes: [String: [WordCloudLens: [String: Int]]],
                      generated: String,
                      provenance: CloudVectorsFile.Provenance) -> CloudVectorsFile {
        // Intern in a deterministic order — first appearance while walking scopes and
        // lenses in sorted order — so two runs over the same input produce byte-identical
        // vocabularies, not merely equivalent ones.
        var vocabulary: [String] = []
        var index: [String: Int] = [:]
        func intern(_ term: String) -> Int {
            if let i = index[term] { return i }
            index[term] = vocabulary.count
            vocabulary.append(term)
            return vocabulary.count - 1
        }

        var packed: [String: CloudVectorsFile.ScopeVectors] = [:]
        for scopeKey in scopes.keys.sorted() {
            guard let byLens = scopes[scopeKey] else { continue }
            var lists: [String: CloudVectorsFile.TermList] = [:]
            for lens in lenses {
                guard let terms = byLens[lens] else { continue }
                let total = terms.values.reduce(0, +)
                // Rank by count descending, then term ascending. The tiebreak is not
                // cosmetic: dictionary order is unspecified, so without it two runs could
                // emit different top-50s whenever counts tie at the cut line.
                let ranked = terms.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
                    .prefix(Self.topTermsPerList)
                let entries = ranked.map { term, count in
                    CloudVectorsFile.TermList.Entry(
                        term: intern(term),
                        count: count,
                        polarity: lens == .sentiment ? lexicons.polarity(of: term) : nil
                    )
                }
                lists[lens.rawValue] = CloudVectorsFile.TermList(
                    total: total,
                    entries: entries,
                    belowSignalThreshold: entries.count < lens.minimumSignalTerms
                )
            }
            packed[scopeKey] = CloudVectorsFile.ScopeVectors(lists: lists)
        }

        return CloudVectorsFile(
            version: Self.schemaVersion,
            generated: generated,
            provenance: provenance,
            lenses: lenses.map(\.rawValue),
            vocabulary: vocabulary,
            scopes: packed
        )
    }
}
