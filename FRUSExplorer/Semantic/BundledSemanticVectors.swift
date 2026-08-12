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

/// Loader for the bundled semantic tiers: the row index and the corpus-wide sign-bit block.
///
/// Follows `BundledCloudVectors`' shape — `@MainActor` enum, idempotent `async prepare()`, work done
/// in `Task.detached(.utility)`, never first-touched on a render path — because the reason that shape
/// exists applies here twice over. This artifact is 10.23 MB, and while the *mapping* is cheap, the
/// index JSON decode is not something to discover during a view body.
///
/// Two departures from the JSON loaders, both because this is the app's first binary bundle resource:
///
/// * **The binary is mapped, never read.** `Data(contentsOf:options:.mappedIfSafe)` costs a few pages
///   up front and faults the rest in as the scan touches it. Reading 10.23 MB into the heap to answer
///   a 1.43 ms scan would be the expensive part of the feature.
/// * **The two files are loaded as a pair or not at all.** The index states a provenance digest and
///   the binary header carries one; a mismatch means two generations met, and the loader reports that
///   rather than serving vectors keyed by the wrong table. That is the family version-skew rule
///   (`BundledKeynessBaseline.configurationMismatch`) applied at the byte level.
///
/// Version history:
///   1.0 — V-2: initial implementation
@MainActor
public enum BundledSemanticVectors {

    /// What a caller gets when it asks for the tiers.
    public enum Availability: Equatable, Sendable {
        /// Both tiers loaded and agree on their provenance.
        case available
        /// Not loaded yet, or loading.
        case unavailable(SemanticUnavailable)
    }

    /// The decoded row index, once loaded.
    private static var loadedIndex: SemanticVectorIndex?
    /// The mapped corpus tier, once loaded.
    private static var loadedVectors: SemanticCorpusVectors?
    /// Set before the first load so a failed load is not retried on every access.
    private static var loadStarted = false
    /// Why the load failed, when it did.
    private static var failure: SemanticUnavailable?

    /// Whether both tiers are ready. Synchronous, for a view's `.task(id:)` key.
    public static var isAvailable: Bool { loadedIndex != nil && loadedVectors != nil }

    /// The current availability, including the reason when unavailable.
    public static var availability: Availability {
        if isAvailable { return .available }
        return .unavailable(failure ?? .pending)
    }

    /// The row index, or `nil` when not loaded.
    public static var index: SemanticVectorIndex? { loadedIndex }

    /// The mapped corpus tier, or `nil` when not loaded.
    public static var corpusVectors: SemanticCorpusVectors? { loadedVectors }

    /// The provenance both tiers agree on, or `nil` when not loaded.
    public static var provenance: SemanticVectorsArtifacts.Provenance? { loadedIndex?.provenance }

    /// Loads both tiers once. Safe to call from every consumer's `.task`; later calls are no-ops.
    ///
    /// Idempotent on `loadStarted` rather than on `loadedIndex == nil`, so a device that genuinely
    /// lacks the artifacts does not re-attempt the decode on every Related Documents view.
    public static func prepare() async {
        guard !loadStarted else { return }
        loadStarted = true
        let loaded = await Task.detached(priority: .utility) {
            () -> Result<(SemanticVectorIndex, SemanticCorpusVectors), SemanticUnavailable> in
            guard let indexURL = Bundle.main.url(
                    forResource: "semantic-vectors-index", withExtension: "json"),
                  let binaryURL = Bundle.main.url(
                    forResource: "semantic-vectors-binary", withExtension: "bin")
            else {
                #if DEBUG
                print("[BundledSemanticVectors] artifacts not in bundle")
                #endif
                return .failure(.noArtifact)
            }
            do {
                let data = try Data(contentsOf: indexURL)
                let file = try JSONDecoder().decode(
                    SemanticVectorsArtifacts.Index.self, from: data)
                let index = SemanticVectorIndex(file: file)
                let vectors = try SemanticCorpusVectors(
                    contentsOf: binaryURL, expecting: index.provenance)
                return .success((index, vectors))
            } catch let error as SemanticUnavailable {
                #if DEBUG
                print("[BundledSemanticVectors] refused: \(error)")
                #endif
                return .failure(error)
            } catch {
                #if DEBUG
                print("[BundledSemanticVectors] index decode failed: \(error)")
                #endif
                return .failure(.malformedArtifact("index: \(error)"))
            }
        }.value

        switch loaded {
        case .success(let (index, vectors)):
            loadedIndex = index
            loadedVectors = vectors
            failure = nil
        case .failure(let reason):
            failure = reason
        }
    }

    #if DEBUG
    /// Injects tiers for tests, bypassing the bundle.
    ///
    /// - Parameters:
    ///   - index: The row index to serve.
    ///   - vectors: The corpus tier to serve.
    public static func injectForTesting(
        index: SemanticVectorIndex?, vectors: SemanticCorpusVectors?
    ) {
        loadedIndex = index
        loadedVectors = vectors
        loadStarted = index != nil || vectors != nil
        failure = index == nil ? .noArtifact : nil
    }

    /// Resets to the unloaded state so a test can exercise `prepare()` again.
    public static func resetForTesting() {
        loadedIndex = nil
        loadedVectors = nil
        loadStarted = false
        failure = nil
    }
    #endif
}
