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

/// A slice must refuse out loud, refuse for the right reason, and be introduced before it is made.
///
/// ## What went wrong here twice
/// First, `setPole` refused **silently**: two documents in the same volume have no direction between
/// them, so the method returned without drawing and without a word. Choosing "…to here" did nothing,
/// and a legitimate constraint was indistinguishable from a dead control.
///
/// Then the fix for that told the reader the **wrong reason**. One `guard` covered two unrelated
/// causes — a volume the artifact carries no centroid for, and two centroids whose difference
/// cancels — and reported both as the volumes being "too alike". The first is a property of the
/// build and has nothing to do with likeness. A confident wrong diagnosis is worse than the silence
/// it replaced, because a reader acts on it.
///
/// So these tests assert the *reason*, not merely that something was said.
///
/// Version history:
///   1.0 — build 42: after the silent refusal, and the conflated diagnosis that replaced it
///   1.1 — 2026-11-24: FRUS Explorer Light's S28a — moved into the kit's suites: the refusals are the kit's
///          (`SemanticMapPoles`), whose rule the package tests directly and whose copy is read from its
///          file; the model's handling of them and the selection card's introduction are the app's
@Suite("Semantic slices refuse out loud and for the right reason")
@MainActor
struct SemanticSliceGuidanceTests {

    #if !SWIFT_PACKAGE
    // The app's model, which applies the kit's refusals to its state.
    /// A model with no map artifact loaded — enough for every guard that fires before the centroid
    /// lookup, which is the same-volume rule.
    private func makeModel() -> SemanticMapModel { SemanticMapModel() }
    #endif

    private func noYears(_ volumeID: String) -> Int? { nil }

    // MARK: - Reading the real copy

    /// The `defaultValue` a key ships with, read from source.
    ///
    /// **Not `String(localized:defaultValue:"")`, which is what the first version of this file did
    /// and which quietly tested nothing.** With an empty default and no catalog entry, Foundation
    /// returns the KEY — so `reasonsAreDistinct` was comparing `semanticMap.axis.sameVolume` against
    /// `semanticMap.axis.tooAlike`, finding them distinct, and passing. Its "the degenerate case
    /// mentions likeness" assertion passed because the *key* contains "tooAlike". Every claim in it
    /// was about identifiers rather than about anything a reader sees. Passing the real copy into
    /// the test instead would just duplicate it here, where it could drift; reading source is what
    /// the other suites in this repo do for exactly this reason.
    private func copy(forKey key: String,
                      in file: String = "FRUSCoreKit/Semantic/SemanticMapSlice.swift") throws -> String {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent()
                .appending(path: file),
            encoding: .utf8)
        let pattern = try Regex(#"localized:\s*"# + "\"" + NSRegularExpression.escapedPattern(for: key)
                                + "\"" + #",\s*\n?\s*defaultValue:\s*"((?:[^"\\]|\\.)*)""#)
        let match = try #require(source.firstMatch(of: pattern),
                                 "no defaultValue found in source for \(key)")
        return String(match.output[1].substring ?? "")
    }

    // MARK: - The same-volume refusal

    #if !SWIFT_PACKAGE
    // Drives the app's model.
    @Test("Two poles in one volume are refused, with a reason naming the actual constraint")
    func sameVolumeIsExplained() throws {
        let model = makeModel()
        model.setPole(volumeID: "frus1861", isPositive: false, yearForVolume: noYears)
        #expect(model.axisNotice == nil, "one pole is a normal intermediate state, not a failure")

        model.setPole(volumeID: "frus1861", isPositive: true, yearForVolume: noYears)
        let notice = try #require(model.axisNotice)
        #expect(model.slice == nil, "a slice was drawn between a volume and itself")
        #expect(notice.contains("same one"), """
            The refusal does not tell the reader that both documents are in one volume, which is the \
            actual constraint — an axis runs between volume summaries, not between the two documents \
            tapped. Got: \(model.axisNotice ?? "nothing at all")
            """)
    }

    /// The refusal must discard the choice just made, not the earlier one.
    ///
    /// Getting this backwards throws away work the reader did not just do: they set an end, then
    /// picked a bad second end, and the *first* end vanished.
    @Test("A refused pole clears the end just set, whichever end that was")
    func refusalClearsTheNewestPole() {
        let toEnd = makeModel()
        toEnd.setPole(volumeID: "frus1861", isPositive: false, yearForVolume: noYears)
        toEnd.setPole(volumeID: "frus1861", isPositive: true, yearForVolume: noYears)
        #expect(toEnd.poles.negative == "frus1861", "the surviving end should be the one set first")
        #expect(toEnd.poles.positive == nil, "the refused end should be the one just set")

        // And the same in the other order, which the first fix got wrong.
        let fromEnd = makeModel()
        fromEnd.setPole(volumeID: "frus1861", isPositive: true, yearForVolume: noYears)
        fromEnd.setPole(volumeID: "frus1861", isPositive: false, yearForVolume: noYears)
        #expect(fromEnd.poles.positive == "frus1861", """
            Setting the low end onto an existing high end cleared the HIGH end. The reader's earlier \
            choice was discarded instead of the one that was just refused.
            """)
        #expect(fromEnd.poles.negative == nil)
    }

    @Test("Clearing the slice clears the notice with it")
    func clearingRemovesTheNotice() {
        let model = makeModel()
        model.setPole(volumeID: "frus1861", isPositive: false, yearForVolume: noYears)
        model.setPole(volumeID: "frus1861", isPositive: true, yearForVolume: noYears)
        #expect(model.axisNotice != nil)
        model.clearSlice(yearForVolume: noYears)
        #expect(model.axisNotice == nil, "a stale refusal survived a return to the map")
        #expect(model.poles.negative == nil && model.poles.positive == nil)
    }
    #endif

    // MARK: - The kit's rule, as a host meets it

    @Test("A pair in one volume is refused before the artifact is ready, for the actual constraint")
    func kitRefusesOneVolume() {
        let refused = SemanticMapPoles.resolve(negative: "frus1861", positive: "frus1861",
                                               isReady: false, centroid: { _ in nil })
        #expect(refused == .refused(.sameVolume), "got \(refused)")
        #expect(SemanticMapPoles.Refusal.sameVolume.notice.contains("same one"))
    }

    @Test("One end alone is an intermediate state, not a refusal")
    func kitWaitsForTheSecondEnd() {
        let ends: [(String?, String?)] = [("frus1861", nil), (nil, "frus1861"), (nil, nil)]
        for (negative, positive) in ends {
            #expect(SemanticMapPoles.resolve(negative: negative, positive: positive, isReady: true,
                                             centroid: { _ in [1, 0] }) == .incomplete)
        }
    }

    @Test("A pair completed before the artifact is ready is remembered, not diagnosed")
    func kitDefersBeforeTheLoad() {
        #expect(SemanticMapPoles.resolve(negative: "frus1861", positive: "frus1946v06", isReady: false,
                                         centroid: { _ in nil })
                == .deferred(negative: "frus1861", positive: "frus1946v06"))
    }

    @Test("A missing centroid and a cancelling difference are two refusals, and two volumes make an axis")
    func kitNamesEachCause() {
        let centroids: [String: [Float]] = ["a": [1, 0, 0], "b": [0, 1, 0], "twin": [1, 0, 0]]
        #expect(SemanticMapPoles.resolve(negative: "a", positive: "missing", isReady: true,
                                         centroid: { centroids[$0] }) == .refused(.noSummary))
        #expect(SemanticMapPoles.resolve(negative: "a", positive: "twin", isReady: true,
                                         centroid: { centroids[$0] }) == .refused(.tooAlike))
        guard case .axis(let axis) = SemanticMapPoles.resolve(
            negative: "a", positive: "b", isReady: true, centroid: { centroids[$0] }) else {
            Issue.record("two differing volumes made no axis"); return
        }
        #expect(axis == SemanticAxis.between(negative: [1, 0, 0], negativeLabel: "a",
                                             positive: [0, 1, 0], positiveLabel: "b"))
    }

    @Test("Each refusal's notice is its copy, and the three are distinct")
    func kitNoticesAreTheCopy() throws {
        for refusal in SemanticMapPoles.Refusal.allCases {
            #expect(refusal.notice == (try copy(forKey: "semanticMap.axis.\(refusal.rawValue)")))
        }
        #expect(Set(SemanticMapPoles.Refusal.allCases.map(\.notice)).count == 3)
    }

    // MARK: - The reasons stay distinct

    /// Three refusals, three causes. If any two share wording the reader cannot tell which happened,
    /// which is the defect this suite exists for — one message previously served two causes.
    @Test("The three refusal messages name three different causes")
    func reasonsAreDistinct() throws {
        let sameVolume = try copy(forKey: "semanticMap.axis.sameVolume")
        let noSummary = try copy(forKey: "semanticMap.axis.noSummary")
        let tooAlike = try copy(forKey: "semanticMap.axis.tooAlike")
        for text in [sameVolume, noSummary, tooAlike] {
            #expect(!text.isEmpty, "a refusal message is missing")
        }
        #expect(Set([sameVolume, noSummary, tooAlike]).count == 3,
                "two refusals share wording, so the reader cannot tell which one happened")
        // The build-state message must NOT blame the volumes for being alike — that was the bug.
        // Both words are refused: the degenerate case has said "similar" since the owner's
        // 2026-09-30 wording, and either one would send the reader to change the volumes.
        #expect(!noSummary.lowercased().contains("alike") && !noSummary.lowercased().contains("similar"), """
            The missing-summary message describes the volumes as alike. That is a property of the \
            artifact, not of the volumes, and saying so sends the reader to change the wrong thing.
            """)
        #expect(tooAlike.lowercased().contains("alike") || tooAlike.lowercased().contains("similar"),
                "the genuinely-degenerate case should be the one that mentions likeness")
    }

    // MARK: - The slice is introduced before it is made

    #if !SWIFT_PACKAGE
    // Reads the app's view.
    /// Slices are reachable only from the selection card, so the card is the only place that can
    /// explain what a slice adds — and the caution that makes it usable judiciously.
    @Test("The selection card says what a slice adds, and that any two volumes produce one")
    func selectionCardIntroducesTheSlice() throws {
        let text = try copy(forKey: "semanticMap.axis.whatItAdds",
                            in: "FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift")
        #expect(!text.isEmpty)
        // The distinction from the map: the map has no nameable direction, a slice does.
        #expect(text.lowercased().contains("direction"), """
            The introduction does not draw the distinction that justifies the feature — the map's \
            plane has no direction that means anything, and a slice's does.
            """)
        // The caution, which is the half that keeps a reader from over-reading a tidy picture.
        #expect(text.lowercased().contains("any two volumes"), """
            The introduction describes what a slice shows without saying it will show it REGARDLESS. \
            Any two differing volumes produce a spread and every document lands on it, so a smooth \
            picture is not evidence. Without that sentence this text sells the feature rather than \
            explaining it.
            """)

        // And it must actually be mounted on the selection card, not merely defined.
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent()
                .appending(path: "FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift"),
            encoding: .utf8)
        let card = try #require(source.range(of: "private var selectionCard: some View"))
        let poles = try #require(source.range(of: "semanticMap.axis.poleFrom"))
        let key = try #require(source.range(of: "\"semanticMap.axis.whatItAdds\""))
        #expect(key.lowerBound > card.lowerBound && key.lowerBound < poles.lowerBound, """
            The slice introduction is not inside selectionCard above the pole buttons. Slices can be \
            started only from that card, so an explanation anywhere else is one the reader making a \
            slice will not read.
            """)
    }
    #endif
}
