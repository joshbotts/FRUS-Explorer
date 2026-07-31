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
    var coverageDescription: String {
        String(format: String(localized: "workingCorpus.coverage %lld %lld",
                              defaultValue: "%lld of %lld documents indexed on this device"),
               Int64(indexedCount), Int64(totalCount))
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
