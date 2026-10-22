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

// MARK: - WorkingCorpusResolution

/// What a working corpus amounts to **on this device**.
///
/// The corpus names a fixed set of documents; a device holds whichever of them it has indexed. Both
/// numbers are facts and a researcher needs both: the denominator of any claim is the corpus, while
/// what a query can actually reach is the indexed part.
///
/// This is the pay-off of syncing the key list rather than the query (decision M-1-1). Re-resolving
/// per device would have produced the *indexed* number alone, with nothing to compare it to and no
/// way to know the two devices disagreed.
///
/// Version history:
///   1.0 — M-1: initial implementation
///   1.1 — #1761: the coverage sentence groups both counts, and says "document" when the corpus
///          holds one
struct WorkingCorpusResolution: Equatable, Sendable {

    /// Keys this device can actually query — the ones present in the index.
    let indexedKeys: [String]
    /// Documents the corpus names, indexed or not.
    let totalCount: Int
    /// Volumes the corpus spans that this device has not indexed.
    let missingVolumeIds: [String]

    /// Documents reachable here.
    var indexedCount: Int { indexedKeys.count }
    /// Whether the whole corpus is reachable on this device.
    var isComplete: Bool { indexedCount == totalCount }

    /// The coverage sentence a scope control shows.
    ///
    /// Always states both numbers, even when complete: "267 of 267" tells a reader the corpus is
    /// whole, where a bare "267 documents" leaves them to wonder whether it was clipped.
    ///
    /// Both counts are grouped, as the corpus's own row prints its size: the `%lld` form read
    /// "10914 of 10914" under a cluster whose row read 10,914 (#1761). The noun follows the
    /// corpus's size, so a corpus of one reads "1 of 1 document".
    var coverageDescription: String {
        CountCopy.phrase(
            totalCount,
            one: String(localized: "workingCorpus.coverage.one %@ %@",
                        defaultValue: "%2$@ of %1$@ document indexed on this device"),
            many: String(localized: "workingCorpus.coverage.many %@ %@",
                         defaultValue: "%2$@ of %1$@ documents indexed on this device"),
            then: [indexedCount.formatted()])
    }
}

// MARK: - WorkingCorpusResolver

/// Resolves a working corpus against the local index.
///
/// Version history:
///   1.0 — M-1: initial implementation
struct WorkingCorpusResolver {

    /// The indexed-volume set, used to explain which parts of a corpus are out of reach.
    let indexedVolumeIds: Set<String>

    /// Resolves `corpus` against the index.
    ///
    /// Membership is decided **by volume**, not by a per-document index probe. A document key whose
    /// volume is indexed is reachable; one whose volume is not, is not. That is exact rather than
    /// approximate — `IndexingPipeline` indexes a volume's documents as a unit — and it costs a set
    /// lookup per key instead of a query per key, which matters at the several-thousand-key scale a
    /// corpus can reach.
    func resolve(_ corpus: WorkingCorpus) -> WorkingCorpusResolution {
        var indexed: [String] = []
        var missing: Set<String> = []
        for key in corpus.documentKeys {
            guard let volumeId = key.split(separator: "/").first.map(String.init) else { continue }
            if indexedVolumeIds.contains(volumeId) {
                indexed.append(key)
            } else {
                missing.insert(volumeId)
            }
        }
        return WorkingCorpusResolution(
            indexedKeys: indexed,
            totalCount: corpus.documentKeys.count,
            missingVolumeIds: missing.sorted()
        )
    }
}

// MARK: - DocumentScopeGate

/// Composes the document-grain constraints a search may carry at once.
///
/// A working corpus and a project History scope are both sets of documents the user asked to be
/// inside. Living here rather than in the view model because it is a rule about what a scope
/// *means*, not about how a screen holds state — and because a rule this consequential should be
/// testable without standing up a search service.
///
/// Version history:
///   1.0 — M-1: initial implementation
///   1.1 — #1577 lane 4: `combine(corpus:projectGate:pin:)`, a held base's members as a third set
enum DocumentScopeGate {

    /// Intersects the constraints, preserving the empty-set contract.
    ///
    /// **Intersection, not replacement.** Both constraints were asked for, so a History scope inside
    /// a working corpus means the documents in both.
    ///
    /// An empty result stays an empty **array**, never `nil`: `IndexingPipeline` reads an empty
    /// `documentIds` as "match nothing" and `nil` as "no constraint". Collapsing a disjoint
    /// intersection to `nil` would search the entire corpus while two scope labels sit on screen —
    /// the worst available answer, because it looks like a result rather than an error.
    static func combine(corpus: [String]?, projectGate: [String]?) -> [String]? {
        guard let corpus else { return projectGate }
        guard let projectGate else { return corpus }
        return Set(corpus).intersection(projectGate).sorted()
    }

    /// Intersects the constraints with a held base's members as a third set (#1577 lane 4): a search
    /// inside a held list is also inside the corpus and the History scope the list was found in.
    ///
    /// The same contract as ``combine(corpus:projectGate:)``: `nil` is no constraint, and an empty
    /// result stays an empty array, which matches nothing. A base whose members fall wholly outside a
    /// corpus applied since gives a layer that finds nothing, never one that searches the series.
    ///
    /// - Parameters:
    ///   - corpus: The applied working corpus's keys, or `nil`.
    ///   - projectGate: The project's History scope, or `nil`.
    ///   - pin: The held base's member keys, or `nil` when no base is held.
    /// - Returns: The intersection, or `nil` when no constraint is set.
    static func combine(corpus: [String]?, projectGate: [String]?, pin: [String]?) -> [String]? {
        let scoped = combine(corpus: corpus, projectGate: projectGate)
        guard let pin else { return scoped }
        guard let scoped else { return pin }
        return Set(scoped).intersection(pin).sorted()
    }
}
