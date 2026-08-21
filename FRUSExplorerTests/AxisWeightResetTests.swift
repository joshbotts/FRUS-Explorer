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

    /// Pins the mechanism, not just the symptom: the fallback is keyed on ABSENCE, and `rawValue`
    /// never produces an absence.
    @Test("A stored tuning pins every axis, so the default-merge fallback cannot fire")
    func storedTuningDefeatsTheMerge() {
        let stored = AxisWeights.default.rawValue
        for axis in SimilarityAxis.allCases {
            #expect(stored.contains(axis.rawValue), """
                `rawValue` writes every axis. That is what makes `base.weights[axis] ?? \
                axis.defaultWeight` unreachable — the value is present, so `??` never fires.
                """)
        }
        let parsed = AxisWeights(rawValue: stored)
        #expect(parsed?.weights.count == SimilarityAxis.allCases.count)
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
