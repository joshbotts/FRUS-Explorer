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
#if !SWIFT_PACKAGE
import Metal
#endif
import Testing
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif
// The package builds SemanticVectorsKit as a module of its own; Xcode compiles it into the app.
#if canImport(SemanticVectorsKit)
import SemanticVectorsKit
#endif

/// The map needs a Metal device to prepare. Declared here rather than shared because
/// `SemanticMapSurfaceTests`' copy is file-private, and a second one-line constant beats widening
/// another suite's surface to reach it.
#if !SWIFT_PACKAGE
// The app's renderer is Metal's.
private let revealTestsHaveMetal = MTLCreateSystemDefaultDevice() != nil
#endif

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
///   1.1 — 2026-11-24: FRUS Explorer Light's S28a — moved into the kit's suites: the reveal's rule is the
///          kit's (`SemanticMapReveal`), which the package tests over the bundled map; the model's deferral,
///          its renderer and the view's source are the app's
///   1.2 — 2026-11-27: row L32 of the plan of record from 2026-11-25 (#2010) — on a slice: the kit's
///          reveal over a slice's positions, the model's reveal and the regions list's row, each run first
///          on the unchanged code, where they failed; the list's row on the plane, as before
@Suite("Revealing a document on the map")
struct SemanticMapRevealTests {

    // MARK: - The kit's reveal, over the bundled map

    @Test("A key splits at its first separator, and a key without one names nothing")
    func keysSplitAtTheFirstSeparator() throws {
        let parts = try #require(SemanticMapReveal.documentKey("frus1861/d1"))
        #expect(parts.volumeID == "frus1861" && parts.documentID == "d1")
        #expect(SemanticMapReveal.documentKey("frus1861/d1/extra")?.documentID == "d1/extra")
        for key in ["frus1861", "", "/d1", "frus1861/"] {
            #expect(SemanticMapReveal.documentKey(key) == nil, "\(key) parsed")
        }
    }

    @Test("A real document reveals at its own point, in its region, at the reveal's extent")
    func kitRevealsARealDocument() throws {
        let loaded = try SemanticMapFixture.load()
        let clusters = loaded.mapIndex.clusters
        var clustered: Int?
        for row in 0..<min(loaded.index.documentCount, 5_000)
        where loaded.map.placement(at: row)?.cluster != SemanticMapArtifacts.unclustered {
            clustered = row; break
        }
        let row = try #require(clustered, "no clustered row in the first 5,000")
        let document = try #require(loaded.index.document(at: row))
        let revealed = try #require(SemanticMapReveal.reveal(
            volumeID: document.volumeID, documentID: document.documentID, index: loaded.index,
            map: loaded.map, clusters: clusters, isReadable: { $0 == document.volumeID }))
        let placement = try #require(loaded.map.placement(at: row))
        #expect(revealed.selection.row == row)
        #expect(revealed.selection.position == SIMD2(Float(placement.x), Float(placement.y)))
        #expect(revealed.selection.regionName
                == SemanticMapPicking.regionName(ofRow: row, map: loaded.map, clusters: clusters))
        #expect(revealed.selection.regionName != nil, "a tap and a reveal would show different cards")
        #expect(revealed.selection.isDownloaded)
        #expect(revealed.camera == SemanticMapCamera(centre: revealed.selection.position,
                                                     halfExtent: SemanticMapReveal.documentHalfExtent))
        #expect(SemanticMapReveal.reveal(volumeID: "frus9999", documentID: "d99999", index: loaded.index,
                                         map: loaded.map, clusters: clusters, isReadable: { _ in true }) == nil,
                "a document the map has no point for must say so")
    }

    @Test("A region focus lands on its centre only under the layout that minted its id")
    func kitFocusesARegion() throws {
        let mapIndex = try SemanticMapFixture.load().mapIndex
        let region = try #require(mapIndex.clusters.first)
        let focused = try #require(SemanticMapReveal.focus(
            regionID: region.id, digest: mapIndex.layoutIdentity, artifactDigest: mapIndex.layoutIdentity,
            clusters: mapIndex.clusters))
        #expect(focused.region.id == region.id)
        #expect(focused.camera == SemanticMapCamera(
            centre: SIMD2(Float(region.centreX), Float(region.centreY)),
            halfExtent: SemanticMapReveal.regionHalfExtent))
        #expect(SemanticMapReveal.focus(regionID: region.id, digest: "another layout",
                                        artifactDigest: mapIndex.layoutIdentity, clusters: mapIndex.clusters) == nil)
        #expect(SemanticMapReveal.focus(regionID: -1, digest: mapIndex.layoutIdentity,
                                        artifactDigest: mapIndex.layoutIdentity, clusters: mapIndex.clusters) == nil)
        #expect(SemanticMapReveal.regionHalfExtent > SemanticMapReveal.documentHalfExtent,
                "a region's focus leaves more of the map in view than a document's")
    }

    @Test("On a slice, a document reveals where the slice draws it, in the region its row is in")
    func kitRevealsWhereASliceDrawsIt() throws {
        let loaded = try SemanticMapFixture.load()
        let clusters = loaded.mapIndex.clusters
        let catalogue = Dictionary(try testManifestEntries().map { ($0.volumeId, $0) },
                                   uniquingKeysWith: { first, _ in first })
        let positions = try SemanticMapFixture.slice(
            loaded, yearForVolume: { SemanticMapVolumes.coverageYear(of: catalogue[$0]) }).positions
        // A clustered row the slice moves, so its places on the plane and on the slice differ.
        let row = try #require((0..<min(loaded.index.documentCount, 5_000)).first { row in
            guard let placement = loaded.map.placement(at: row) else { return false }
            return placement.cluster != SemanticMapArtifacts.unclustered
                && positions[row] != SIMD2(placement.x, placement.y)
        }, "no clustered row in the first 5,000 that the slice moves")
        let document = try #require(loaded.index.document(at: row))
        let revealed = try #require(SemanticMapReveal.reveal(
            volumeID: document.volumeID, documentID: document.documentID, index: loaded.index,
            map: loaded.map, clusters: clusters, positions: positions, isReadable: { _ in true }))
        let drawn = SIMD2(Float(positions[row].x), Float(positions[row].y))
        #expect(revealed.selection.row == row)
        #expect(revealed.selection.position == drawn, """
            The reveal rang the map plane's place for the row while the host drew a slice. On a slice \
            that place holds another document, and the camera went there with it (#2010).
            """)
        #expect(revealed.camera == SemanticMapCamera(centre: drawn,
                                                     halfExtent: SemanticMapReveal.documentHalfExtent))
        let region = try #require(
            SemanticMapPicking.regionName(ofRow: row, map: loaded.map, clusters: clusters))
        #expect(revealed.selection.regionName == region,
                "a slice lays the rows out again; a row's region is still the one the artifact names")
        // Positions that hold no place for the row are no answer, not the plane's place.
        #expect(SemanticMapReveal.reveal(
            volumeID: document.volumeID, documentID: document.documentID, index: loaded.index,
            map: loaded.map, clusters: clusters, positions: Array(positions.prefix(row)),
            isReadable: { _ in true }) == nil)
        // And with none, the map's own plane, as before.
        let placement = try #require(loaded.map.placement(at: row))
        #expect(SemanticMapReveal.reveal(
            volumeID: document.volumeID, documentID: document.documentID, index: loaded.index,
            map: loaded.map, clusters: clusters, isReadable: { _ in true })?.selection.position
                == SIMD2(Float(placement.x), Float(placement.y)))
    }

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

    #if !SWIFT_PACKAGE
    // The app's model, prepared over its bundle, and its renderer.
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

        #expect(model.reveal(documentKey: key, isReadable: { _ in true }) == .revealed, """
            The first document in the artifact did not reveal. Every row the artifact places has a             point by construction, so this is a lookup failure rather than an unembedded document.
            """)
        let selection = try #require(model.selection)
        #expect(selection.volumeID == document.volumeID)
        #expect(selection.documentID == document.documentID)
        #expect(selection.row == 0)
        #expect(model.camera != before, "the camera did not move to the revealed document")
        #expect(model.camera.halfExtent == SemanticMapReveal.documentHalfExtent)
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
                             isReadable: { _ in true }) == .revealed)
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
        #expect(model.reveal(documentKey: "frus1861", isReadable: { _ in true }) == .notFound)
        #expect(model.selection == nil)
    }

    /// An unknown document is an ordinary outcome — 2,356 display rows were never embedded — and
    /// must be reported rather than silently leaving the map where it was.
    @MainActor
    @Test("An unknown document reveals nothing and leaves no selection",
          .enabled(if: revealTestsHaveMetal))
    func unknownDocumentIsReported() async throws {
        let (model, _) = try await loadedModel()
        #expect(model.reveal(documentKey: "frus9999/d99999", isReadable: { _ in true }) == .notFound)
        #expect(model.selection == nil, "a failed reveal must not leave a selection behind")
    }

    /// **The defect a reader hit: the map opened and the document was not selected.**
    ///
    /// On macOS the continuation can arrive while `prepare()` is still uploading 314,483 points, so
    /// the model has no index yet. A reveal then must say `.notReady` — NOT `.notFound` — because
    /// the caller banks the continuation on any definite answer and never asks again. Collapsing the
    /// two is what made "On the Map" open a map with nothing selected.
    @MainActor
    @Test("A reveal before the map has loaded reports notReady, not notFound")
    func revealBeforeLoadIsNotReady() {
        let model = SemanticMapModel()   // never prepared: no index
        #expect(model.reveal(documentKey: "frus1861/d1", isReadable: { _ in true }) == .notReady, """
            An un-prepared map answered something other than .notReady. The caller treats every \
            answer except .notReady as final, so the retry that would have selected the document \
            never runs and the map opens with nothing selected.
            """)
        #expect(model.selection == nil)
    }

    /// A malformed key is a real answer even before the map loads — it can never become valid.
    @MainActor
    @Test("A malformed key is notFound even before the map loads")
    func malformedKeyIsFinal() {
        let model = SemanticMapModel()
        #expect(model.reveal(documentKey: "no-separator", isReadable: { _ in true }) == .notFound,
                "a key that can never parse should not make the caller retry forever")
    }
    #endif

    /// The half of the fix that a mutation caught surviving: the outcome was right and the caller
    /// discarded it.
    @Test("A continuation is settled by every outcome except notReady")
    func onlyNotReadyDefersTheContinuation() {
        #expect(SemanticMapReveal.continuationIsSettled(.revealed))
        #expect(SemanticMapReveal.continuationIsSettled(.notFound), """
            A document the map genuinely does not have must SETTLE the continuation, or the view \
            re-attempts the same missing document forever.
            """)
        #expect(SemanticMapReveal.continuationIsSettled(nil),
                "a continuation carrying no document has nothing to wait for")
        #expect(!SemanticMapReveal.continuationIsSettled(.notReady), """
            A reveal that could not run yet was recorded as applied. That is the bug a reader hit — \
            the map opens, the continuation is banked, the retry never happens, and the document is \
            never selected.
            """)
    }

    #if !SWIFT_PACKAGE
    // Reads the app's view.
    /// The continuation must be recorded **after** the reveal is consulted, not before.
    ///
    /// **This is the shape of the original defect and the extracted predicate does not catch it.**
    /// `continuationIsSettled` can be perfectly correct while the caller assigns
    /// `appliedContinuation` on its first line — which is exactly what shipped, and what a mutation
    /// moving the assignment back to the top proved was untested. The method is `private` to a
    /// SwiftUI view and takes no arguments, so its ordering cannot be driven from a test; reading
    /// the source is the honest instrument, and the assertion is positional rather than textual.
    @Test("The applied continuation is recorded after the reveal, not before it")
    func continuationIsRecordedLast() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent()
                .appending(path: "FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift"),
            encoding: .utf8)
        let start = try #require(source.range(of: "private func applyContinuedRequestIfNeeded()"))
        // The method ends at the first line that is exactly four-space-indented `}`.
        let rest = source[start.upperBound...]
        let end = try #require(rest.range(of: "\n    }"))
        let body = String(rest[..<end.lowerBound])

        let assign = try #require(body.range(of: "appliedContinuation = continued"), """
            The method no longer records the applied continuation at all, so every re-render \
            re-applies the continuation and fights the reader's own scope changes.
            """)
        let consult = try #require(body.range(of: "continuationIsSettled"), """
            The method no longer consults continuationIsSettled, so a reveal that could not run yet \
            is banked as an answer and never retried — the map opens with nothing selected.
            """)
        #expect(consult.lowerBound < assign.lowerBound, """
            `appliedContinuation` is assigned BEFORE the reveal outcome is consulted. Recording the \
            continuation is what prevents the retry, so assigning first discards a reveal that \
            arrived while prepare() was still loading — the original defect, verbatim.
            """)
    }
    #endif

    // MARK: - The deferral, which is what the console output measured

    #if !SWIFT_PACKAGE
    // The app's model's deferral, and the view's retry of it, read from its source.
    /// **The failure a reader hit, reproduced.** Console output from the shipped build:
    ///
    /// ```
    /// apply() continued=frus1946v06/d475  ->  reveal -> notReady
    /// apply() continued=nil
    /// ```
    ///
    /// The reveal correctly deferred, and by the time `prepare()` finished the caller's `continued`
    /// was nil again — so a retry driven from the caller had nothing to apply. The model must
    /// therefore remember the key itself, exactly as it already does for `requestedScope`.
    @MainActor
    @Test("A deferred reveal is remembered by the model, not by its caller")
    func deferredRevealIsRemembered() {
        let model = SemanticMapModel()   // unprepared: no index
        #expect(model.pendingRevealKey == nil, "nothing asked for yet")
        #expect(model.reveal(documentKey: "frus1946v06/d475", isReadable: { _ in true }) == .notReady)
        #expect(model.pendingRevealKey == "frus1946v06/d475", """
            A reveal the map could not honour was forgotten. The caller's copy of the request does \
            not survive until prepare() finishes — measured — so if the model does not hold the key \
            the document is never selected.
            """)
    }

    /// And once the map is ready, that remembered key selects the document and then clears.
    @MainActor
    @Test("The remembered reveal is honoured after prepare, then forgotten",
          .enabled(if: revealTestsHaveMetal))
    func rememberedRevealIsHonouredAfterPrepare() async throws {
        await BundledSemanticMap.prepare()
        try #require(BundledSemanticMap.isAvailable)
        let index = try #require(BundledSemanticVectors.index)
        let document = try #require(index.document(at: 0))
        let key = "\(document.volumeID)/\(document.documentID)"

        let model = SemanticMapModel()
        #expect(model.reveal(documentKey: key, isReadable: { _ in true }) == .notReady)
        #expect(model.pendingRevealKey == key)

        await model.prepare(eraForVolume: { _ in nil }, isDownloaded: { _ in false })
        try #require(model.unavailable == nil, "prepare reported: \(model.unavailable ?? "")")

        // What the view's `.task` does after prepare.
        let pending = try #require(model.pendingRevealKey,
                                   "the key was dropped between the deferral and prepare finishing")
        #expect(model.reveal(documentKey: pending, isReadable: { _ in true }) == .revealed)
        #expect(model.selection?.documentID == document.documentID)
        #expect(model.pendingRevealKey == nil, """
            The pending key survived a successful reveal, so every later prepare would re-select \
            this document and fight the reader.
            """)
    }

    /// A key that can never resolve must not be remembered forever.
    @MainActor
    @Test("A malformed key is not remembered")
    func malformedKeyIsNotRemembered() {
        let model = SemanticMapModel()
        #expect(model.reveal(documentKey: "no-separator", isReadable: { _ in true }) == .notFound)
        #expect(model.pendingRevealKey == nil,
                "an unresolvable key was queued for retry, which would retry on every prepare")
    }

    /// The model can remember a deferred reveal perfectly and still never be asked.
    ///
    /// **A mutation deleting the view's retry survived a suite that tested the memory itself** —
    /// the third time in this feature that a correct mechanism was left with no caller. The
    /// `.task` body is a SwiftUI closure that cannot be driven from a test, so the source is the
    /// instrument, and the assertion is positional: the retry must come after `model.prepare`, or
    /// `prepare`'s closing `frameAll` overrules the camera move and the document is selected
    /// off-screen.
    @Test("The view retries a deferred reveal, after prepare")
    func viewRetriesAfterPrepare() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent()
                .appending(path: "FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift"),
            encoding: .utf8)
        // Comments are stripped so prose naming the call cannot stand in for it.
        let code = source.components(separatedBy: .newlines)
            .map { line -> String in
                guard let slashes = line.range(of: "//") else { return line }
                return String(line[..<slashes.lowerBound])
            }
            .joined(separator: "\n")

        // **The CALL, not the declaration.** A first version searched for the bare name, which the
        // `private func` line satisfies — so deleting the only call site left the test green, and a
        // mutation proved it. A call site is a line that is exactly the invocation.
        let lines = code.components(separatedBy: .newlines)
        let callLine = lines.firstIndex { $0.trimmingCharacters(in: .whitespaces)
            == "applyPendingRevealIfNeeded()" }
        try #require(callLine != nil, """
            Nothing CALLS applyPendingRevealIfNeeded() (its declaration does not count). The model \
            remembers a deferred reveal and is never asked for it, so a document revealed while the \
            map was still loading is never selected — the defect a reader reported, restored.
            """)
        let retry = try #require(code.range(of: lines[callLine!]))
        let prepare = try #require(code.range(of: "await model.prepare("))
        #expect(prepare.lowerBound < retry.lowerBound, """
            The deferred reveal is retried BEFORE model.prepare(). prepare() ends by framing the \
            whole map, so the camera move would be immediately overruled and the reader would be \
            looking at the whole corpus with a selection somewhere off screen.
            """)
    }
    #endif

    // MARK: - The camera the labels project through

    #if !SWIFT_PACKAGE
    // The app's model and renderer, the view's source and the card's count.
    /// **The renderer owns the camera; the model keeps a mirror. They must agree.**
    ///
    /// Region labels and the selection marker are SwiftUI layers that project through
    /// `model.camera`, while the points are drawn by Metal through `renderer.camera`. A reveal that
    /// assigned the mirror directly moved the names and left the cloud where it was — a reader saw
    /// "soviet gorin" floating in empty space off the right edge of the map. Every other camera move
    /// (`pan`, `zoom`, `frameAll`) changes the renderer and then re-reads the mirror; this pins that
    /// a reveal does the same.
    @MainActor
    @Test("A reveal leaves the model's camera equal to the renderer's",
          .enabled(if: revealTestsHaveMetal))
    func revealKeepsCamerasInStep() async throws {
        await BundledSemanticMap.prepare()
        try #require(BundledSemanticMap.isAvailable)
        let index = try #require(BundledSemanticVectors.index)
        let model = SemanticMapModel()
        await model.prepare(eraForVolume: { _ in nil }, isDownloaded: { _ in false })
        try #require(model.unavailable == nil, "prepare reported: \(model.unavailable ?? "")")
        let renderer = try #require(model.renderer)
        #expect(model.camera == renderer.camera, "the mirror is already out of step before any move")

        let document = try #require(index.document(at: 0))
        #expect(model.reveal(documentKey: "\(document.volumeID)/\(document.documentID)",
                             isReadable: { _ in true }) == .revealed)

        #expect(model.camera == renderer.camera, """
            After a reveal the model's camera and the renderer's disagree. The points are drawn \
            through the renderer's and the region labels through the model's, so they would be \
            drawn against different views of the map — names detached from the cloud they name.
            """)
        #expect(model.camera.halfExtent == SemanticMapReveal.documentHalfExtent,
                "the reveal did not actually zoom in")
    }

    // MARK: - On a slice (#2010)

    /// A volume's coverage year from the bundled manifest, the year a slice lays a volume's rows at.
    private static func coverageYears() throws -> (String) -> Int? {
        let catalogue = Dictionary(try testManifestEntries().map { ($0.volumeId, $0) },
                                   uniquingKeysWith: { first, _ in first })
        return { SemanticMapVolumes.coverageYear(of: catalogue[$0]) }
    }

    /// A prepared model with a slice drawn between the series' first and last volumes, as two poles
    /// draw one, and the plane's positions the slice re-laid.
    @MainActor
    private func slicedModel() async throws
        -> (model: SemanticMapModel, index: SemanticVectorIndex, plane: [SIMD2<Int16>]) {
        let (model, index) = try await loadedModel()
        let plane = model.positions
        let years = try Self.coverageYears()
        let negative = try #require(index.volumes.first?.volumeID)
        let positive = try #require(index.volumes.last?.volumeID)
        model.setPole(volumeID: negative, isPositive: false, yearForVolume: years)
        model.setPole(volumeID: positive, isPositive: true, yearForVolume: years)
        try #require(model.slice != nil, "no slice was drawn: \(model.axisNotice ?? "no notice")")
        try #require(model.positions != plane, "the slice left every row where the plane had it")
        return (model, index, plane)
    }

    /// **The defect a slice's reader met** (#2010): *Nearest in language* on the selection card
    /// reveals a neighbour, and on a slice the ring went to the neighbour's place on the map's plane.
    @MainActor
    @Test("On a slice, a reveal rings the document where the slice draws it, and the camera goes there",
          .enabled(if: revealTestsHaveMetal))
    func revealOnASliceLandsOnTheSlice() async throws {
        let (model, index, plane) = try await slicedModel()
        let row = try #require((0..<min(index.documentCount, 5_000)).first { model.positions[$0] != plane[$0] })
        let document = try #require(index.document(at: row))
        #expect(model.reveal(documentKey: "\(document.volumeID)/\(document.documentID)",
                             isReadable: { _ in true }) == .revealed)
        let selection = try #require(model.selection)
        let drawn = SIMD2(Float(model.positions[row].x), Float(model.positions[row].y))
        #expect(selection.row == row)
        #expect(selection.position == drawn, """
            On a slice the reveal rang the document's place on the map's plane. The slice puts \
            another document there, so the ring named one document and circled another.
            """)
        #expect(model.camera.centre == drawn, "the camera went to the plane's coordinates, off the document")
        #expect(model.camera.halfExtent == SemanticMapReveal.documentHalfExtent)
        #expect(model.camera == model.renderer?.camera)
        #expect(model.slice != nil, "a reveal took the reader off their slice")
    }

    /// The regions list is VoiceOver's way into the map, and on a slice a region's centre has no
    /// place: it is a coordinate of the map's plane, which the slice gives to other documents.
    @MainActor
    @Test("On a slice, the regions list opens a region's card and selects no document",
          .enabled(if: revealTestsHaveMetal))
    func regionsListOnASliceOpensTheRegion() async throws {
        let (model, index, _) = try await slicedModel()
        let size = CGSize(width: 600, height: 600)
        // Under a scope the list counts a region's documents in scope, and its card counts the whole
        // corpus, as a tap on its name gives it (`select(at:)`'s note says why): a region whose two
        // counts differ tells the two records apart.
        model.setScope(volumeIDs: Set(index.volumes.prefix(200).map(\.volumeID)))
        let region = try #require(model.labelledClusters.first { listed in
            model.clusters.first { $0.id == listed.id }?.documentCount != listed.documentCount
        }, "no listed region's count differs from its whole-corpus count under the scope")
        let whole = try #require(model.clusters.first { $0.id == region.id })
        model.zoom(by: 4)
        let camera = model.camera
        model.selectRegionFromList(region, size: size, isReadable: { _ in true })
        #expect(model.selection == nil, """
            The list's row selected a document of the slice: the region's centre on the map's plane, \
            projected onto the slice, hit-tests whatever document sits there.
            """)
        #expect(model.selectedRegion?.id == region.id, "the row did not open its region's card")
        #expect(model.selectedRegion?.documentCount == whole.documentCount,
                "the card is the region's whole-corpus record, as a tap on its name gives")
        #expect(model.camera == camera, "a region has no place on a slice, so the camera stays")
    }

    /// The plane's half of the list's rule is the view's old one, moved: a test that a slice's rule
    /// did not change what a row does on the map's own plane.
    @MainActor
    @Test("On the map's plane, the regions list resolves a region as a tap at its framed centre does",
          .enabled(if: revealTestsHaveMetal))
    func regionsListOnThePlaneIsAsBefore() async throws {
        let (model, _) = try await loadedModel()
        let size = CGSize(width: 600, height: 600)
        let regions = Array(model.labelledClusters.prefix(8))
        try #require(regions.count == 8)
        var resolved = 0
        for region in regions {
            // A tap at the region's centre on the framed map, from a camera zoomed in first, as the
            // reader's would be.
            model.zoom(by: 4)
            model.frameAll()
            let framed = model.camera
            let point = SemanticMapLabelLayout.project(
                SIMD2(Float(region.centreX), Float(region.centreY)), camera: model.camera, size: size)
            model.select(at: point, size: size, isReadable: { _ in true })
            let tapped = (selection: model.selection, region: model.selectedRegion?.id)
            model.clearSelection()
            model.clearRegion()
            model.zoom(by: 4)
            model.selectRegionFromList(region, size: size, isReadable: { _ in true })
            #expect(model.selection == tapped.selection && model.selectedRegion?.id == tapped.region,
                    "region \(region.id)")
            #expect(model.camera == framed, "region \(region.id): the row did not frame the map first")
            if tapped.selection != nil || tapped.region != nil { resolved += 1 }
            model.clearSelection()
            model.clearRegion()
        }
        #expect(resolved > 0, "no row of the list resolved a region on the plane")
    }

    // MARK: - A reveal that finds nothing says so

    /// **The state existed and nothing drew it.** #941's commit claimed a failed reveal "is
    /// reported, rather than leaving the reader looking at an unmoved map". `revealFailed` was
    /// assigned and never read: its only two mentions in the file were its declaration and that
    /// assignment. The reader got precisely the unmoved, silent map the commit said they would not.
    ///
    /// A rendered state cannot be observed from a unit test, so this reads source — but it asserts
    /// the thing that was missing (a *use*), not merely that the property exists, because the
    /// property existing is exactly what was true while the feature was broken.
    @Test("The reveal-failure state is rendered, not merely stored")
    func revealFailureIsRendered() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent()
                .appending(path: "FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift"),
            encoding: .utf8)
        let code = source.components(separatedBy: .newlines)
            .map { line -> String in
                guard let slashes = line.range(of: "//") else { return line }
                return String(line[..<slashes.lowerBound])
            }
            .joined(separator: "\n")

        // **The key must be SET from a `.notFound` reveal.** A first version of this test counted
        // reads against writes, which a mutation walked straight through: replacing the assignment
        // with `revealFailedKey = nil` keeps the counts healthy while making the notice unreachable.
        // What matters is that a failing reveal stores the document, so assert that shape.
        let storesOnFailure = code.contains("== .notFound ? key : nil")
        #expect(storesOnFailure, """
            Nothing stores the document when a reveal answers .notFound, so `revealFailureNotice` \
            can never appear however well it is written. That is the defect restored: the reader \
            gets an unmoved map and no explanation.
            """)
        // And it must be read where the notice is built.
        #expect(code.contains("if let key = revealFailedKey"),
                "the notice does not read the stored key, so it cannot name the document")
        // And the view that draws it must be mounted, not merely declared — the mistake made twice
        // already in this feature.
        let lines = code.components(separatedBy: .newlines)
        #expect(lines.contains { $0.trimmingCharacters(in: .whitespaces) == "revealFailureNotice" }, """
            `revealFailureNotice` is declared but never mounted in the view hierarchy. A view that \
            nothing places renders nothing, which is indistinguishable from the defect it fixes.
            """)
        #expect(code.contains("semanticMap.reveal.notOnMap"),
                "the notice carries no localized explanation")
    }

    // MARK: - The neighbour list's contract

    /// The map's neighbour list must ask for exactly ten.
    @Test("The card asks for ten neighbours")
    @MainActor
    func neighbourCountIsTen() {
        #expect(SemanticMapSpikeView.nearestCount == 10)
    }
    #endif

    /// The reveal camera must actually change what is on screen.
    ///
    /// A half-extent equal to or larger than the default would "reveal" a document by leaving the
    /// map exactly as it was, which is indistinguishable from doing nothing.
    @Test("Revealing zooms in rather than leaving the camera alone")
    func revealZoomsIn() {
        #expect(SemanticMapReveal.documentHalfExtent < SemanticMapCamera().halfExtent, """
            The reveal half-extent (\(SemanticMapReveal.documentHalfExtent)) is not closer than the \
            default camera (\(SemanticMapCamera().halfExtent)), so revealing a document would not \
            visibly move the map.
            """)
        #expect(SemanticMapReveal.documentHalfExtent > 0)
    }
}
