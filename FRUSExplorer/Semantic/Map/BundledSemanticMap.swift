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

/// Loader for the bundled Tier-0 map: where every document sits, and what the regions are called.
///
/// Follows `BundledSemanticVectors` — `@MainActor` enum, idempotent `async prepare()`, work off the
/// main actor, never first-touched on a render path — and loads **only when a map surface asks for
/// it**. The map is 1.89 MB of placements plus a 25 KB index that nothing on the launch path needs,
/// so unlike the vector tiers this is not prepared at start-up.
///
/// It refuses a map whose provenance digest disagrees with the loaded vectors. That is not
/// pedantry: coordinates are computed *from* vectors, so a map from one generation drawn against
/// another places documents where different vectors put them, and every region would be subtly wrong
/// in a way no reader could detect.
///
/// Version history:
///   1.0 — V-4: initial implementation
@MainActor
public enum BundledSemanticMap {

    /// The decoded cluster roster and layout provenance.
    private static var loadedIndex: SemanticMapArtifacts.MapIndex?
    /// The mapped placements.
    private static var loadedVectors: SemanticMapVectors?
    /// Set before the first load so a failed load is not retried on every appearance.
    private static var loadStarted = false
    /// Why the load failed, when it did.
    private static var failure: SemanticUnavailable?

    /// Whether the map is ready to draw.
    public static var isAvailable: Bool { loadedIndex != nil && loadedVectors != nil }

    /// Why the map is not available, when it is not.
    public static var unavailableReason: SemanticUnavailable? {
        isAvailable ? nil : (failure ?? .pending)
    }

    /// The cluster roster and layout metadata.
    public static var index: SemanticMapArtifacts.MapIndex? { loadedIndex }

    /// The mapped placements.
    public static var vectors: SemanticMapVectors? { loadedVectors }

    /// Loads the map once.
    ///
    /// Requires `BundledSemanticVectors` to have loaded first, because the vectors carry the
    /// provenance the map is checked against and the row keying every placement is indexed by.
    public static func prepare() async {
        guard !loadStarted else { return }
        await BundledSemanticVectors.prepare()
        guard let vectorIndex = BundledSemanticVectors.index else {
            failure = BundledSemanticVectors.availability == .available ? .noArtifact : .pending
            return
        }
        loadStarted = true

        let provenance = vectorIndex.provenance
        let documentCount = vectorIndex.documentCount
        let loaded = await Task.detached(priority: .utility) {
            () -> Result<(SemanticMapArtifacts.MapIndex, SemanticMapVectors), SemanticUnavailable> in
            guard let indexURL = Bundle.main.url(
                    forResource: "semantic-map-index", withExtension: "json"),
                  let binaryURL = Bundle.main.url(
                    forResource: "semantic-map", withExtension: "bin")
            else {
                #if DEBUG
                print("[BundledSemanticMap] map artifacts not in bundle")
                #endif
                return .failure(.noArtifact)
            }
            do {
                let data = try Data(contentsOf: indexURL)
                let mapIndex = try JSONDecoder().decode(
                    SemanticMapArtifacts.MapIndex.self, from: data)
                guard mapIndex.provenanceDigest == provenance.digestHex else {
                    return .failure(.provenanceMismatch(
                        expected: provenance.digestHex, found: mapIndex.provenanceDigest))
                }
                let vectors = try SemanticMapVectors(
                    contentsOf: binaryURL, provenance: provenance,
                    expectedDocumentCount: documentCount)
                return .success((mapIndex, vectors))
            } catch let error as SemanticUnavailable {
                #if DEBUG
                print("[BundledSemanticMap] refused: \(error)")
                #endif
                return .failure(error)
            } catch {
                return .failure(.malformedArtifact("map index: \(error)"))
            }
        }.value

        switch loaded {
        case .success(let (mapIndex, vectors)):
            loadedIndex = mapIndex
            loadedVectors = vectors
            failure = nil
        case .failure(let reason):
            failure = reason
        }
    }

    #if DEBUG
    /// Resets to the unloaded state so a test can exercise `prepare()` again.
    public static func resetForTesting() {
        loadedIndex = nil
        loadedVectors = nil
        loadStarted = false
        failure = nil
    }
    #endif
}
