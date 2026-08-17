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
@testable import FRUSExplorer

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
@Suite("Semantic slices refuse out loud and for the right reason")
@MainActor
struct SemanticSliceGuidanceTests {

    /// A model with no map artifact loaded — enough for every guard that fires before the centroid
    /// lookup, which is the same-volume rule.
    private func makeModel() -> SemanticMapModel { SemanticMapModel() }

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
    private func copy(forKey key: String) throws -> String {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .appending(path: "FRUSExplorer/Semantic/Map/SemanticMapSpikeView.swift"),
            encoding: .utf8)
        let pattern = try Regex(#"localized:\s*"# + "\"" + NSRegularExpression.escapedPattern(for: key)
                                + "\"" + #",\s*\n?\s*defaultValue:\s*"((?:[^"\\]|\\.)*)""#)
        let match = try #require(source.firstMatch(of: pattern),
                                 "no defaultValue found in source for \(key)")
        return String(match.output[1].substring ?? "")
    }

    // MARK: - The same-volume refusal

    @Test("Two poles in one volume are refused, with a reason naming the actual constraint")
    func sameVolumeIsExplained() {
        let model = makeModel()
        model.setPole(volumeID: "frus1861", isPositive: false, yearForVolume: noYears)
        #expect(model.axisNotice == nil, "one pole is a normal intermediate state, not a failure")

        model.setPole(volumeID: "frus1861", isPositive: true, yearForVolume: noYears)
        let notice = try? #require(model.axisNotice)
        #expect(model.slice == nil, "a slice was drawn between a volume and itself")
        #expect(notice?.contains("same one") == true, """
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
        #expect(!noSummary.lowercased().contains("alike"), """
            The missing-summary message describes the volumes as alike. That is a property of the \
            artifact, not of the volumes, and saying so sends the reader to change the wrong thing.
            """)
        #expect(tooAlike.lowercased().contains("alike"),
                "the genuinely-degenerate case should be the one that mentions likeness")
    }

    // MARK: - The slice is introduced before it is made

    /// Slices are reachable only from the selection card, so the card is the only place that can
    /// explain what a slice adds — and the caution that makes it usable judiciously.
    @Test("The selection card says what a slice adds, and that any two volumes produce one")
    func selectionCardIntroducesTheSlice() throws {
        let text = try copy(forKey: "semanticMap.axis.whatItAdds")
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
}
