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

/// Names the map's clusters, by c-TF-IDF over the documents in each.
///
/// ## Why this is Swift and not Python
///
/// The layout stage that produced the clusters is Python, and it would have been one more numpy
/// expression to label them there. It deliberately does not: the design asks for labels "through the
/// **WordCloudKit tokenizer and stopword stack**, so labels speak the same vocabulary as every cloud
/// surface", and a second tokenizer would mint a second vocabulary. This repository has paid for that
/// mistake before — `BundledKeynessBaseline` exists precisely because SQLite's Porter stems and
/// NLTagger's lemmas are different words for the same term, and a ratio across them fails
/// systematically while looking like a finding.
///
/// ## The measurement that made this file worth reading twice
///
/// The first implementation used `log(1 + N/df)` for the inverse-cluster-frequency, with a comment
/// claiming the `+1` made a term used by every cluster score zero. It does not — it floors that term
/// at `log(2) ≈ 0.69`, which was enough for a word occupying 98% of a cluster's tokens to outrank one
/// appearing nowhere else. **The labels it produced were checked by eye and pronounced good**:
/// `chinese, china, japanese, nanking` reads exactly like a correct label for the China cluster.
///
/// It was not. A unit fixture where `government` beat `kearsarge` exposed the defect, and fixing it
/// changed **168 of 179 labels** — a cluster labelled `british, united, war, american`, which says
/// nothing about anything, turned out to be `maize, cottonseed, oversea, lansing`; `israel, arab,
/// israeli, say` became `israel, israeli, arab, baath`. Plausibility is what made the bug invisible,
/// and plausibility is all an eye can check. The lesson is the general one this repository keeps
/// paying for: output that looks right is not evidence that it is.
///
/// ## What c-TF-IDF is here
///
/// Treat each cluster as one document. A term's weight is its frequency *within* the cluster times
/// the log-inverse of how many clusters use it at all, so a word every cluster shares — `government`,
/// `department` — scores near zero however often it appears, and a word concentrated in one cluster
/// rises. That is the whole difference between a label and a word count.
///
/// ## Sampling, and why it is disclosed
///
/// Labelling every document would mean an `NLTagger` pass over 1.33 billion characters — the same
/// ~50-minute cost `CloudVectorsGenerator` pays. The labels do not need it: a cluster's distinctive
/// vocabulary is stable well before its thousandth document. So this reads a **deterministic stride
/// sample** per cluster and records the sample size in the artifact, because a label built from part
/// of a cluster should say so rather than let a reader assume it saw everything.
///
/// Version history:
///   1.0 — V-4: initial implementation
public enum ClusterLabeller {

    /// How many terms a cluster's label carries.
    public static let termsPerCluster = 4

    /// Documents read per cluster. A stable top-4 needs far fewer than a cluster's full membership;
    /// 300 is generous against the corpus's median cluster size.
    public static let documentsPerCluster = 300

    /// A document's cluster assignment and where to find its text.
    public struct Member: Sendable {
        /// Volume the document belongs to.
        public let volumeID: String
        /// The document's id within that volume.
        public let documentID: String
        /// The cluster it was assigned.
        public let cluster: Int

        /// Creates a member.
        /// - Parameters:
        ///   - volumeID: Volume id.
        ///   - documentID: Document id.
        ///   - cluster: Cluster id.
        public init(volumeID: String, documentID: String, cluster: Int) {
            self.volumeID = volumeID
            self.documentID = documentID
            self.cluster = cluster
        }
    }

    /// Date chrome a *label* must not show, filtered here rather than in the shared stopword payload.
    ///
    /// The first real run named one cluster "british, apr, united, war". `apr` is April, and the
    /// shared word-cloud stopwords carry only one of the twelve month names and none of the
    /// abbreviations — which is defensible for a word cloud, where dates are a small part of a large
    /// distribution, and wrong for a four-word label.
    ///
    /// **It is filtered here because fixing it in the shared payload is not a small change.**
    /// `BundledKeynessBaseline` pins that payload's SHA-256 (verified: the baseline's recorded digest
    /// and the file's digest match today), so editing it makes every keyness read report
    /// `.configurationMismatch` until `CloudVectorsGenerator` re-runs — about an hour — and it would
    /// silently re-price every term in the corpus reference. That is a disproportionate blast radius
    /// for a cosmetic term in one label out of 179.
    static let labelChrome: Set<String> = [
        "jan", "feb", "mar", "apr", "jun", "jul", "aug", "sep", "sept", "oct", "nov", "dec",
        "january", "february", "march", "april", "june", "july", "august", "september",
        "october", "november", "december",
    ]

    /// Chooses which documents to read, deterministically.
    ///
    /// A **stride** rather than a random sample, and the stride runs over the members in artifact row
    /// order — which is volume order — so a sample spans a cluster's whole membership instead of
    /// concentrating in whichever volumes happen to come first. Deterministic because the artifact is:
    /// two runs over the same layout must produce the same labels or the map's text changes for no
    /// reason a reader could see.
    ///
    /// - Parameters:
    ///   - members: Every clustered document, in row order.
    ///   - perCluster: How many to take from each cluster.
    /// - Returns: The chosen members, grouped by cluster.
    public static func sample(
        members: [Member], perCluster: Int = documentsPerCluster
    ) -> [Int: [Member]] {
        var byCluster: [Int: [Member]] = [:]
        for member in members { byCluster[member.cluster, default: []].append(member) }
        var sampled: [Int: [Member]] = [:]
        for (cluster, all) in byCluster {
            guard all.count > perCluster else { sampled[cluster] = all; continue }
            let stride = Double(all.count) / Double(perCluster)
            var picked: [Member] = []
            picked.reserveCapacity(perCluster)
            for index in 0..<perCluster {
                picked.append(all[min(all.count - 1, Int(Double(index) * stride))])
            }
            sampled[cluster] = picked
        }
        return sampled
    }

    /// Computes each cluster's label terms from its per-cluster term counts.
    ///
    /// - Parameters:
    ///   - counts: Term counts per cluster.
    ///   - limit: Terms per label.
    /// - Returns: Label terms per cluster, most distinctive first.
    public static func label(
        counts: [Int: [String: Int]], limit: Int = termsPerCluster
    ) -> [Int: [String]] {
        guard !counts.isEmpty else { return [:] }
        // How many clusters use each term at all — the "document frequency" of c-TF-IDF, where a
        // cluster is the document.
        var clustersUsing: [String: Int] = [:]
        for (_, terms) in counts {
            for term in terms.keys { clustersUsing[term, default: 0] += 1 }
        }
        let clusterCount = Double(counts.count)

        var labels: [Int: [String]] = [:]
        for (cluster, terms) in counts {
            let total = Double(terms.values.reduce(0, +))
            guard total > 0 else { continue }
            var scored: [(term: String, weight: Double)] = []
            scored.reserveCapacity(terms.count)
            for (term, count) in terms {
                guard !labelChrome.contains(term) else { continue }
                let used = Double(clustersUsing[term] ?? 1)
                // `log(N/df)`, the plain inverse-cluster-frequency. A term every cluster uses has
                // df == N and scores EXACTLY zero, which is the property the whole measure rests on.
                //
                // A first draft wrote `log(1 + N/df)` to "avoid negatives" — a worry with no basis,
                // since df never exceeds N — and that floor of log(2) ≈ 0.69 was enough for a term
                // appearing in 98% of a cluster's tokens to outrank one that appears nowhere else.
                // Caught by a fixture where `government` beat `kearsarge`; the real corpus hid it,
                // because a word like `chinese` happens to be both frequent and concentrated.
                let weight = (Double(count) / total) * log(clusterCount / used)
                guard weight > 0 else { continue }
                scored.append((term: term, weight: weight))
            }
            scored.sort { $0.weight == $1.weight ? $0.term < $1.term : $0.weight > $1.weight }
            labels[cluster] = scored.prefix(limit).map(\.term)
        }
        return labels
    }

    /// Builds a tokenizer configured exactly as the app's word-cloud surfaces are.
    ///
    /// - Parameters:
    ///   - lexiconsPath: Path to `word-cloud-lexicons.json`.
    ///   - stopwordsPath: Path to `word-cloud-stopwords.json`.
    /// - Returns: The tokenizer.
    /// - Throws: When either payload is missing or empty — a labeller running without stopwords
    ///   would name every cluster after the same function words, and nothing downstream would notice.
    public static func makeTokenizer(
        lexiconsPath: String, stopwordsPath: String
    ) throws -> WordCloudTokenizer {
        let stopwordSet = try WordCloudStopwordSet(contentsOf: URL(fileURLWithPath: stopwordsPath))
        guard !stopwordSet.english.isEmpty else {
            throw LabelError.emptyStopwords(stopwordsPath)
        }
        _ = try WordCloudLexiconSet(contentsOf: URL(fileURLWithPath: lexiconsPath))
        let tuning = WordCloudTuning.standard
        return WordCloudTokenizer(
            stopwords: stopwordSet.active(includeDiplomatic: true),
            minimumLength: tuning.minimumLength,
            foldPlurals: tuning.foldPlurals,
            // `.allTerms`, matching the shared-terms chip: a curated lens would discard the proper
            // nouns and technical vocabulary that make a cluster name mean something.
            lens: .allTerms,
            lexicon: nil,
            markings: tuning.filterMarkings ? stopwordSet.markings : [])
    }

    /// Why labelling refused to run.
    public enum LabelError: Error, CustomStringConvertible {
        /// The stopword payload was missing or empty.
        case emptyStopwords(String)

        public var description: String {
            switch self {
            case .emptyStopwords(let path):
                return "Stopword payload empty or unreadable at \(path) — every cluster would be "
                    + "named after the same function words"
            }
        }
    }
}
