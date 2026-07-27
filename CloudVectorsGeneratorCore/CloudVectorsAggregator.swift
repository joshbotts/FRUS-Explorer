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

    /// Both artifacts.
    public struct Output: Sendable {
        /// Corpus + every subseries — loaded eagerly by the app.
        public let core: CloudVectorsFile
        /// Every volume — loaded lazily.
        public let volumes: CloudVectorsFile
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
    public func pack(volumes: [VolumeCounts], generated: String,
                     tuning: WordCloudTuning) -> Output {
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
            volumes: file(scopes: volumeScopes, generated: generated, provenance: provenance)
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
