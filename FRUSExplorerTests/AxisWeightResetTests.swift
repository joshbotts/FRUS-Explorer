// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

// MARK: - AxisWeightResetTests

/// The global weight tuning's reset, and the storage contract it depends on (#1029, #1021).
///
/// Version history:
///   1.0 — Session 2026-08-21: #1029
@Suite("Axis weight reset (#1029)")
struct AxisWeightResetTests {

    /// A private suite-local defaults domain, so these never touch the real preference.
    private func scratchDefaults() -> UserDefaults {
        let suite = "frus.test.weights.\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    // MARK: - What "reset" has to mean

    /// **Removing beats writing, and this is the whole design.** Writing `AxisWeights.default` into
    /// the key pins today's numbers as an explicit tuning; because `rawValue` spells out every axis
    /// and `effectiveWeights` only falls back when an axis is ABSENT, that written-out value is
    /// indistinguishable from a deliberate one — which is exactly how #1021 happened.
    @Test("Reset removes the key rather than writing defaults into it")
    func resetRemovesRatherThanWrites() {
        let defaults = scratchDefaults()
        let key = SettingsKeys.relatedAxisWeights
        var tuned = AxisWeights.default
        tuned[.sharedSubjects] = 0
        defaults.set(tuned.rawValue, forKey: key)
        #expect(defaults.object(forKey: key) != nil)

        defaults.removeObject(forKey: key)   // what the Reset button does

        #expect(defaults.object(forKey: key) == nil, """
            Reset must leave the key ABSENT. Writing `AxisWeights.default` would look identical to \
            the user today and strand them again the next time an axis is added or a default moves.
            """)
    }

    /// The payoff of removing: an unconfigured reader picks up whatever the defaults are *now*.
    @Test("With the key absent, every axis resolves to its current default")
    func absentKeyInheritsCurrentDefaults() {
        for axis in SimilarityAxis.allCases {
            #expect(AxisWeights.default[axis] == axis.defaultWeight)
        }
        #expect(AxisWeights.default[.sharedSubjects] == 0.5)
    }

    /// The owner's ruling on the wrinkle: one meaning of "default". Semantic similarity ships as a
    /// deliberate experimental opt-in at 0, so a reset switches it back off.
    @Test("Reset returns semantic similarity to its opt-in zero, like every other axis")
    func resetIncludesTheExperimentalAxis() {
        #expect(SimilarityAxis.semanticSimilarity.defaultWeight == 0.0, """
            If this default ever moves off 0, the Reset button's copy and the caption that calls the \
            axis opt-in both need re-reading — the button silently changes meaning.
            """)
        #expect(AxisWeights.default[.semanticSimilarity] == 0.0)
    }

    // MARK: - The bug the reset exists to escape (#1021)

    /// The inverse of what this test used to pin. Before #1021 it asserted `rawValue` writes every
    /// axis — the mechanism of the bug. It now asserts the opposite, which is the fix.
    @Test("A stored tuning records only its departures, so an untouched axis follows its default")
    func storedTuningOmitsDefaultedAxes() {
        #expect(AxisWeights.default.rawValue.isEmpty, """
            The default tuning must serialize to the empty string: it departs from the defaults in \
            no axis. If this ever spells axes out again, every reader who touches a slider is \
            re-pinned to today's numbers forever — the whole of #1021.
            """)

        var tuned = AxisWeights.default
        tuned[.crossReference] = 0.2
        let stored = tuned.rawValue
        #expect(stored == "crossReference:0.2", """
            One moved slider must produce one pair, not seven. Stored: \(stored)
            """)
        for axis in SimilarityAxis.allCases where axis != .crossReference {
            #expect(!stored.contains(axis.rawValue),
                    "\(axis.rawValue) was never moved and must not be pinned")
        }
    }

    /// The repair, measured against the two vectors earlier versions actually wrote.
    ///
    /// A forward-only fix reaches nobody who already has a tuning — and the old serializer gave a
    /// tuning to everyone who ever released a slider, which is exactly the stranded cohort.
    @Test("A stored legacy default vector is treated as unconfigured and inherits today's defaults")
    func legacyDefaultVectorsGetTodaysDefaults() {
        // Era 1: six axes, before the semantic axis shipped (#868).
        let eraOne = "archivalProvenance:1.0,crossReference:1.0,dateProximity:0.5,"
            + "sharedPersons:0.7,sharedSubjects:0.0,subseries:0.3"
        // Era 2: seven axes, both new ones off — #868 through #308 Phase 3.
        let eraTwo = eraOne + ",semanticSimilarity:0.0"

        for (label, stored) in [("era 1 (six axes)", eraOne), ("era 2 (seven axes)", eraTwo)] {
            let parsed = AxisWeights(rawValue: stored)
            #expect(parsed?[.sharedSubjects] == 0.5, """
                \(label): a tuning identical to that era's defaults must inherit today's 0.5. \
                Read \(parsed?[.sharedSubjects] ?? -1). Through both eras the axis had no bundled \
                index behind it, so such a vector is not evidence of a preference about it.
                """)
            #expect(parsed?[.semanticSimilarity] == 0.0,
                    "\(label): the experimental axis must stay opt-in")
            #expect(parsed?[.sharedPersons] == 0.7, "\(label): untouched axes are unchanged")
        }
    }

    /// The amnesty must be exact. A reader who deliberately tuned an axis keeps their value, and
    /// an amnesty that fired on "close enough" would silently overwrite a real preference.
    @Test("A deliberate tuning that merely resembles a legacy default is preserved")
    func nearMissIsNotAmnestied() {
        let deliberate = "archivalProvenance:1.0,crossReference:1.0,dateProximity:0.5,"
            + "sharedPersons:0.7,sharedSubjects:0.3,subseries:0.3,semanticSimilarity:0.0"
        let parsed = AxisWeights(rawValue: deliberate)
        #expect(parsed?[.sharedSubjects] == 0.3, """
            0.3 differs from every legacy default, so it is a real choice and must survive. If this \
            reads 0.5 the amnesty is matching loosely and is overwriting preferences.
            """)

        // And a reader who zeroed ONE axis away from the era defaults keeps that too.
        let zeroedElsewhere = "archivalProvenance:0.0,crossReference:1.0,dateProximity:0.5,"
            + "sharedPersons:0.7,sharedSubjects:0.0,subseries:0.3,semanticSimilarity:0.0"
        #expect(AxisWeights(rawValue: zeroedElsewhere)?[.archivalProvenance] == 0.0)
        #expect(AxisWeights(rawValue: zeroedElsewhere)?[.sharedSubjects] == 0.0, """
            This vector is not a legacy default (archivalProvenance is zeroed), so nothing about it \
            is amnestied — including its sharedSubjects:0.0.
            """)
    }

    /// The hazard the sparse encoding creates, and the reason the backfill lives in `init`.
    ///
    /// Three surfaces read this preference straight out of `@AppStorage` and feed it to the engine
    /// through `subscript`, which reads a missing axis as 0. Sparse output WITHOUT this backfill
    /// would zero every unmentioned axis on those paths — a far worse bug than the one being fixed.
    @Test("A sparse stored string refills every unmentioned axis, not zeroes them")
    func sparseStringBackfillsRatherThanZeroes() throws {
        let parsed = try #require(AxisWeights(rawValue: "crossReference:0.2"))
        #expect(parsed[.crossReference] == 0.2)
        #expect(parsed[.archivalProvenance] == 1.0, """
            An axis absent from the STORED string must read its default, not 0. This is read \
            through `subscript` directly — the path RelatedDocumentsContent, DocumentView and \
            ResearchRailView take — not through ProjectLeadsService's merge.
            """)
        #expect(parsed[.sharedSubjects] == 0.5)
        #expect(parsed[.sharedPersons] == 0.7)
    }

    /// `AxisWeights.default.rawValue` is `""`, and `RelatedDocumentsRequest` is Codable THROUGH
    /// `rawValue` — so a nil `init?` for `""` would make a restored macOS Related window saved at
    /// default weights fail to decode and never reappear.
    @Test("A window payload at default weights survives a Codable round-trip")
    func defaultWeightsSurviveThePayloadRoundTrip() throws {
        let request = RelatedDocumentsRequest(
            anchor: DocumentKey(volumeId: "frus1969-76v01", documentId: "d1"),
            weights: .default)
        #expect(request.weights.rawValue.isEmpty, "the premise: default weights encode to \"\"")

        let data = try JSONEncoder().encode(request)
        let restored = try JSONDecoder().decode(RelatedDocumentsRequest.self, from: data)
        #expect(restored.weights == .default, """
            A request at default weights did not survive encoding. Before #1021's empty-string rule \
            this THREW .dataCorrupted, and the window it restores would simply not come back.
            """)
        #expect(restored.anchor == request.anchor)
    }

    /// Genuine garbage must still fall back, or the "a malformed stored value falls back at the
    /// read site" contract quietly becomes "any string is a tuning".
    @Test("Only the empty string is the default; real garbage is still nil")
    func garbageIsStillNil() {
        #expect(AxisWeights(rawValue: "") == .default)
        #expect(AxisWeights(rawValue: "not valid json") == nil)
        #expect(AxisWeights(rawValue: "noSuchAxis:1.0") == nil)
    }

    /// Round-tripping must preserve EFFECTIVE weights for every shape, including the two the new
    /// encoding treats specially.
    @Test("Every vector shape round-trips through the sparse encoding")
    func everyShapeRoundTrips() throws {
        var tuned = AxisWeights.default
        tuned[.dateProximity] = 0.91
        tuned[.semanticSimilarity] = 0.4
        let allZero = AxisWeights(weights: Dictionary(
            uniqueKeysWithValues: SimilarityAxis.allCases.map { ($0, 0.0) }))

        for (label, weights) in [("default", AxisWeights.default), ("tuned", tuned),
                                 ("all zero", allZero)] {
            let restored = try #require(AxisWeights(rawValue: weights.rawValue),
                                        "\(label) failed to decode from \"\(weights.rawValue)\"")
            for axis in SimilarityAxis.allCases {
                #expect(restored[axis] == weights[axis],
                        "\(label): \(axis.rawValue) round-tripped \(weights[axis]) → \(restored[axis])")
            }
        }
    }

    /// A zero is not a down-weight. `RelatedDocumentsEngine` skips zero-weighted axes outright, so a
    /// stale tuning silently DISABLES a feature rather than quieting it.
    @Test("A zeroed axis is absent from the tuning's active set")
    func zeroMeansOffNotQuiet() {
        var weights = AxisWeights.default
        weights[.sharedSubjects] = 0
        #expect(weights[.sharedSubjects] == 0)
        let active = SimilarityAxis.allCases.filter { weights[$0] > 0 }
        #expect(!active.contains(.sharedSubjects), """
            The engine gates on `weights[axis] > 0` at three sites, so this axis's query never runs. \
            The reset is the only route back for a tuning already written with it at 0.
            """)
    }

    /// An unset axis reads 0, NOT its default — the second half of #1021, and the reason reset has
    /// to clear the whole key rather than delete one token.
    @Test("A missing axis reads zero, not its default")
    func missingAxisReadsZeroNotDefault() {
        let partial = AxisWeights(weights: [.crossReference: 1.0])
        #expect(partial[.sharedSubjects] == 0)
        #expect(partial[.sharedSubjects] != SimilarityAxis.sharedSubjects.defaultWeight)
    }
}
