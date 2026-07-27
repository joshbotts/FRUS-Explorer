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

import Testing
import Foundation
@testable import FRUSExplorer

/// Reading the bundled cloud vectors, and the honesty rule attached to it.
///
/// The load-bearing behaviour here is not "does it return terms" — it is **whether the
/// caller is told when the terms are not the scope's own**. A volume cloud that silently
/// shows its era's vocabulary would mislead a user at the exact moment they are deciding
/// whether to download that volume (decision O-4-2).
///
/// Version history:
///   1.0 — O-2: initial implementation
@Suite("Bundled cloud vectors — resolution and provenance")
@MainActor
struct BundledCloudVectorsTests {

    // MARK: - Fixtures

    private func file(_ scopes: [String: [WordCloudLens: [(String, Int, Int?)]]],
                      belowSignal: Set<String> = []) -> CloudVectorsFile {
        var vocabulary: [String] = []
        var index: [String: Int] = [:]
        func intern(_ t: String) -> Int {
            if let i = index[t] { return i }
            index[t] = vocabulary.count; vocabulary.append(t); return vocabulary.count - 1
        }
        var packed: [String: CloudVectorsFile.ScopeVectors] = [:]
        for (scope, byLens) in scopes {
            var lists: [String: CloudVectorsFile.TermList] = [:]
            for (lens, entries) in byLens {
                lists[lens.rawValue] = .init(
                    total: entries.reduce(0) { $0 + $1.1 },
                    entries: entries.map { .init(term: intern($0.0), count: $0.1, polarity: $0.2) },
                    belowSignalThreshold: belowSignal.contains("\(scope).\(lens.rawValue)")
                )
            }
            packed[scope] = .init(lists: lists)
        }
        return CloudVectorsFile(
            version: 1, generated: "2026-07-27",
            provenance: .init(volumeCount: 1, documentCount: 1, tuning: .standard, topTermsPerList: 50),
            lenses: WordCloudLens.bundledCloudLenses.map(\.rawValue),
            vocabulary: vocabulary, scopes: packed
        )
    }

    private var core: CloudVectorsFile {
        file([
            "corpus": [.topics: [("treaty", 900, nil), ("policy", 700, nil)],
                       .sentiment: [("peace", 400, 1), ("crisis", 300, -1)]],
            "1969-76": [.topics: [("salt", 500, nil), ("detente", 300, nil)]],
        ])
    }

    private var volumesFile: CloudVectorsFile {
        file([
            "frus1969-76v32": [.topics: [("abm", 200, nil), ("kissinger", 150, nil)]],
            "frus1969-76v99": [.topics: [("thin", 2, nil)]],
        ], belowSignal: ["frus1969-76v99.topics"])
    }

    // MARK: - Resolution

    @Test("Corpus and subseries resolve to their own terms, marked exact")
    func resolvesCoreScopes() {
        BundledCloudVectors.injectForTesting(core: core, volumes: nil)
        defer { BundledCloudVectors.injectForTesting(core: nil, volumes: nil) }

        let corpus = BundledCloudVectors.terms(forScope: .corpus, lens: .topics)
        #expect(corpus?.terms.map(\.term) == ["treaty", "policy"])
        #expect(corpus?.provenance == .exact)

        let era = BundledCloudVectors.terms(forScope: .subseries("1969-76"), lens: .topics)
        #expect(era?.terms.map(\.term) == ["salt", "detente"])
        #expect(era?.provenance == .exact)
    }

    @Test("Raw counts survive, so the layout sizes words on the generator's scale")
    func rawCountsSurvive() {
        BundledCloudVectors.injectForTesting(core: core, volumes: nil)
        defer { BundledCloudVectors.injectForTesting(core: nil, volumes: nil) }
        #expect(BundledCloudVectors.terms(forScope: .corpus, lens: .topics)?.terms.map(\.count) == [900, 700])
    }

    @Test("A volume with its own vectors resolves exactly")
    func volumeResolvesExactly() {
        BundledCloudVectors.injectForTesting(core: core, volumes: volumesFile)
        defer { BundledCloudVectors.injectForTesting(core: nil, volumes: nil) }

        let result = BundledCloudVectors.terms(
            forScope: .volume(volumeId: "frus1969-76v32", subseries: "1969-76"), lens: .topics)
        #expect(result?.terms.map(\.term) == ["abm", "kissinger"])
        #expect(result?.provenance == .exact)
    }

    // MARK: - The honesty rule (O-4-2)

    @Test("A below-signal volume falls back to its era AND SAYS SO")
    func belowSignalVolumeIsMarked() {
        BundledCloudVectors.injectForTesting(core: core, volumes: volumesFile)
        defer { BundledCloudVectors.injectForTesting(core: nil, volumes: nil) }

        let result = BundledCloudVectors.terms(
            forScope: .volume(volumeId: "frus1969-76v99", subseries: "1969-76"), lens: .topics)
        #expect(result?.terms.map(\.term) == ["salt", "detente"], "should show the era's words")
        #expect(result?.provenance == .subseriesFallback("1969-76"),
                "a silent fallback would let the user attribute the era's vocabulary to the volume")
    }

    @Test("Before the volumes file loads, a volume falls back to its era AND SAYS SO")
    func fallsBackWhileVolumesFileIsUnloaded() {
        // The volumes file is lazy, so this is the ordinary state on first selection —
        // not an edge case. It must be marked for exactly the same reason.
        BundledCloudVectors.injectForTesting(core: core, volumes: nil)
        defer { BundledCloudVectors.injectForTesting(core: nil, volumes: nil) }

        let result = BundledCloudVectors.terms(
            forScope: .volume(volumeId: "frus1969-76v32", subseries: "1969-76"), lens: .topics)
        #expect(result?.terms.map(\.term) == ["salt", "detente"])
        #expect(result?.provenance == .subseriesFallback("1969-76"))
    }

    // MARK: - Absence

    @Test("Nothing loaded means nothing rendered — never a placeholder")
    func returnsNilBeforeLoad() {
        BundledCloudVectors.injectForTesting(core: nil, volumes: nil)
        #expect(!BundledCloudVectors.isCoreReady)
        #expect(BundledCloudVectors.terms(forScope: .corpus, lens: .topics) == nil)
        #expect(BundledCloudVectors.terms(
            forScope: .volume(volumeId: "v", subseries: "e"), lens: .topics) == nil)
    }

    @Test("An unknown scope or a lens with no list resolves to nil, not to something else's words")
    func unknownScopeIsNil() {
        BundledCloudVectors.injectForTesting(core: core, volumes: volumesFile)
        defer { BundledCloudVectors.injectForTesting(core: nil, volumes: nil) }

        #expect(BundledCloudVectors.terms(forScope: .subseries("1800-05"), lens: .topics) == nil)
        // "1969-76" carries no sentiment list; it must not borrow the corpus's.
        #expect(BundledCloudVectors.terms(forScope: .subseries("1969-76"), lens: .sentiment) == nil)
    }

    // MARK: - Sentiment

    @Test("Sentiment polarity comes from the artifact, so the splash can colour offline")
    func polarityResolves() {
        BundledCloudVectors.injectForTesting(core: core, volumes: nil)
        defer { BundledCloudVectors.injectForTesting(core: nil, volumes: nil) }

        #expect(BundledCloudVectors.polarity(of: "peace", inScope: .corpus, lens: .sentiment) == 1)
        #expect(BundledCloudVectors.polarity(of: "crisis", inScope: .corpus, lens: .sentiment) == -1)
        // Only the sentiment lens carries polarity at all.
        #expect(BundledCloudVectors.polarity(of: "treaty", inScope: .corpus, lens: .topics) == nil)
    }

    // MARK: - The shipped artifacts

    @Test("The bundled core file decodes, and carries the corpus plus every subseries")
    func shippedCoreFileIsUsable() throws {
        // Against the REAL bundled artifact, not a fixture: a schema drift between the
        // generator and this reader would otherwise surface as a blank backdrop at runtime
        // with no error anywhere.
        let url = try #require(Bundle.main.url(forResource: "cloud-vectors-core", withExtension: "json"))
        let file = try JSONDecoder().decode(CloudVectorsFile.self, from: Data(contentsOf: url))

        #expect(file.version == 1)
        #expect(file.scopes["corpus"] != nil)
        #expect(file.scopes.count > 100, "expected the corpus plus ~107 subseries")
        #expect(!file.vocabulary.isEmpty)

        let topics = try #require(file.scopes["corpus"]?.lists[WordCloudLens.topics.rawValue])
        #expect(topics.entries.count > 10)
        #expect(topics.entries.allSatisfy { $0.term >= 0 && $0.term < file.vocabulary.count })
        // Ranked descending — the renderer normalises against the first entry.
        #expect(topics.entries.map(\.count) == topics.entries.map(\.count).sorted(by: >))
    }
}
