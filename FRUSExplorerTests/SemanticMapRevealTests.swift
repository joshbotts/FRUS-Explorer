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

        #expect(model.reveal(documentKey: key, isReadable: { _ in true }) == .revealed, """
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

    /// The half of the fix that a mutation caught surviving: the outcome was right and the caller
    /// discarded it.
    @Test("A continuation is settled by every outcome except notReady")
    func onlyNotReadyDefersTheContinuation() {
        #expect(SemanticMapSpikeView.continuationIsSettled(.revealed))
        #expect(SemanticMapSpikeView.continuationIsSettled(.notFound), """
            A document the map genuinely does not have must SETTLE the continuation, or the view \
            re-attempts the same missing document forever.
            """)
        #expect(SemanticMapSpikeView.continuationIsSettled(nil),
                "a continuation carrying no document has nothing to wait for")
        #expect(!SemanticMapSpikeView.continuationIsSettled(.notReady), """
            A reveal that could not run yet was recorded as applied. That is the bug a reader hit — \
            the map opens, the continuation is banked, the retry never happens, and the document is \
            never selected.
            """)
    }

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

    // MARK: - The deferral, which is what the console output measured

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
