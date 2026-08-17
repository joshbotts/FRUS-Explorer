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
import Metal
import Testing
@testable import FRUSExplorer

/// The map needs a Metal device to prepare. Declared here rather than shared because
/// `SemanticMapSurfaceTests`' copy is file-private, and a second one-line constant beats widening
/// another suite's surface to reach it.
private let revealTestsHaveMetal = MTLCreateSystemDefaultDevice() != nil

/// Going from a document to its place on the map, and back out to its nearest neighbours.
///
/// ## The two claims that need holding
/// A reveal must survive the trip through `SemanticMapRequest`, which also **keys the map's window
/// scene** — so the focused document has to be part of the request's identity. If it were not,
/// `openWindow(value:)` would find the existing map equal to the new request, focus it, and leave it
/// showing the previous document: the control would look broken while behaving exactly as written.
///
/// And a reveal must produce the same selection a tap produces. Two code paths that resolve a
/// document's region differently would put a document in one region when tapped and another when
/// revealed, which is the kind of disagreement nobody notices until they are comparing screenshots.
///
/// Version history:
///   1.0 — build 42: document → map, and the map's nearest-document list
@Suite("Revealing a document on the map")
struct SemanticMapRevealTests {

    // MARK: - The request carries the document, and its identity

    @Test("The focused document is part of the request's identity")
    func focusIsPartOfIdentity() {
        let base = SemanticMapRequest(volumeIDs: nil, scopeLabel: nil,
                                      lensRawValue: SemanticMapLens.cluster.rawValue)
        let first = SemanticMapRequest(volumeIDs: nil, scopeLabel: nil,
                                       lensRawValue: SemanticMapLens.cluster.rawValue,
                                       focusDocumentKey: "frus1861/d1")
        let second = SemanticMapRequest(volumeIDs: nil, scopeLabel: nil,
                                        lensRawValue: SemanticMapLens.cluster.rawValue,
                                        focusDocumentKey: "frus1861/d2")
        #expect(first != second, """
            Two reveals of different documents produce equal requests. `SemanticMapRequest` keys the \
            map window, so `openWindow(value:)` would focus the window already showing the FIRST \
            document and never apply the second — the tile would appear to do nothing.
            """)
        #expect(first != base, "a focused request must differ from the plain whole-corpus one")
        #expect(first.hashValue != second.hashValue || first != second,
                "Hashable must agree with Equatable for the window scene to key correctly")
    }

    /// An older Handoff payload has no such key and must still decode.
    @Test("A payload written before this field decodes with no focus")
    func olderPayloadStillDecodes() throws {
        let json = #"{"lensRawValue":"cluster","volumeIDs":null,"scopeLabel":null}"#
        let decoded = try JSONDecoder().decode(
            SemanticMapRequest.self, from: Data(json.utf8))
        #expect(decoded.focusDocumentKey == nil)
        #expect(decoded.lensRawValue == "cluster")
    }

    @Test("A focused request round-trips through JSON, as Handoff requires")
    func focusRoundTrips() throws {
        let request = SemanticMapRequest(volumeIDs: ["frus1861"], scopeLabel: "One volume",
                                         lensRawValue: SemanticMapLens.era.rawValue,
                                         focusDocumentKey: "frus1861/d17")
        let data = try JSONEncoder().encode(request)
        let back = try JSONDecoder().decode(SemanticMapRequest.self, from: data)
        #expect(back == request)
        #expect(back.focusDocumentKey == "frus1861/d17")
    }

    // MARK: - Revealing, against the real artifact

    /// **These load the bundled map on purpose, and the first draft did not.**
    ///
    /// Without it `BundledSemanticMap.vectors` is nil, `reveal` returns at its first guard, and
    /// every assertion below passes without reaching the code it names. Mutation testing caught
    /// exactly that: relaxing the key-parsing guard and deleting the region-clearing line both
    /// SURVIVED, because neither line ever ran. A test that cannot fail is worse than no test,
    /// because it is counted.
    @MainActor
    private func loadedModel() async throws -> (SemanticMapModel, SemanticVectorIndex) {
        await BundledSemanticMap.prepare()
        try #require(BundledSemanticMap.isAvailable,
                     "map unavailable: \(String(describing: BundledSemanticMap.unavailableReason))")
        let index = try #require(BundledSemanticVectors.index)
        let model = SemanticMapModel()
        await model.prepare(eraForVolume: { _ in nil }, isDownloaded: { _ in false })
        try #require(model.unavailable == nil, "prepare reported: \(model.unavailable ?? "")")
        return (model, index)
    }

    /// A real document reveals, selects, and brings the camera to its point.
    @MainActor
    @Test("Revealing a real document selects it and moves the camera to it",
          .enabled(if: revealTestsHaveMetal))
    func revealSelectsAndCentres() async throws {
        let (model, index) = try await loadedModel()
        let document = try #require(index.document(at: 0))
        let key = "\(document.volumeID)/\(document.documentID)"
        let before = model.camera

        #expect(model.reveal(documentKey: key, isReadable: { _ in true }), """
            The first document in the artifact did not reveal. Every row the artifact places has a             point by construction, so this is a lookup failure rather than an unembedded document.
            """)
        let selection = try #require(model.selection)
        #expect(selection.volumeID == document.volumeID)
        #expect(selection.documentID == document.documentID)
        #expect(selection.row == 0)
        #expect(model.camera != before, "the camera did not move to the revealed document")
        #expect(model.camera.halfExtent == SemanticMapModel.revealHalfExtent)
    }

    /// The reveal must agree with a tap about which region a document is in.
    @MainActor
    @Test("A revealed document lands in the region the artifact puts it in",
          .enabled(if: revealTestsHaveMetal))
    func revealAgreesAboutRegion() async throws {
        let (model, index) = try await loadedModel()
        let map = try #require(BundledSemanticMap.vectors)
        // Find a row that IS in a region, so the assertion is about agreement rather than about nil.
        var clustered: Int?
        for row in 0..<min(index.documentCount, 5_000)
        where map.placement(at: row)?.cluster != SemanticMapArtifacts.unclustered {
            clustered = row; break
        }
        let row = try #require(clustered, "no clustered row in the first 5,000")
        let document = try #require(index.document(at: row))
        #expect(model.reveal(documentKey: "\(document.volumeID)/\(document.documentID)",
                             isReadable: { _ in true }))
        #expect(model.selection?.regionName != nil, """
            A document the artifact places inside a region was revealed with no region name, so the             reveal and a tap would show different cards for the same document.
            """)
    }

    /// A key with no separator is not a document and must reveal nothing.
    @MainActor
    @Test("A key with no separator reveals nothing",
          .enabled(if: revealTestsHaveMetal))
    func malformedKeyRevealsNothing() async throws {
        let (model, _) = try await loadedModel()
        #expect(model.reveal(documentKey: "frus1861", isReadable: { _ in true }) == false)
        #expect(model.selection == nil)
    }

    /// An unknown document is an ordinary outcome — 2,356 display rows were never embedded — and
    /// must be reported rather than silently leaving the map where it was.
    @MainActor
    @Test("An unknown document reveals nothing and leaves no selection",
          .enabled(if: revealTestsHaveMetal))
    func unknownDocumentIsReported() async throws {
        let (model, _) = try await loadedModel()
        #expect(model.reveal(documentKey: "frus9999/d99999", isReadable: { _ in true }) == false)
        #expect(model.selection == nil, "a failed reveal must not leave a selection behind")
    }

    // MARK: - The neighbour list's contract

    /// The map's neighbour list must ask for exactly ten.
    @Test("The card asks for ten neighbours")
    func neighbourCountIsTen() {
        #expect(SemanticMapSpikeView.nearestCount == 10)
    }

    /// The reveal camera must actually change what is on screen.
    ///
    /// A half-extent equal to or larger than the default would "reveal" a document by leaving the
    /// map exactly as it was, which is indistinguishable from doing nothing.
    @Test("Revealing zooms in rather than leaving the camera alone")
    func revealZoomsIn() {
        #expect(SemanticMapModel.revealHalfExtent < SemanticMapCamera().halfExtent, """
            The reveal half-extent (\(SemanticMapModel.revealHalfExtent)) is not closer than the \
            default camera (\(SemanticMapCamera().halfExtent)), so revealing a document would not \
            visibly move the map.
            """)
        #expect(SemanticMapModel.revealHalfExtent > 0)
    }
}
