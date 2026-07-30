// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing

@testable import FRUSExplorer

// MARK: - CorpusDispersionTests

/// The dispersion measure behind the Corpus Analytics footnote, and its two display gates.
///
/// Every case here is a boundary. The gates decide whether a sentence appears, so a test that only
/// exercises the middle of each range would let either edge move without failing.
@Suite("Corpus dispersion")
struct CorpusDispersionTests {

    // MARK: Nothing to say

    @Test("No volumes with matches yields no summary, not a zero")
    func emptyYieldsNil() {
        #expect(CorpusDispersion.make(volumeCounts: [], indexedVolumeCount: 40) == nil)
        // All-zero counts must behave identically to an absent array: "spread across 0 volumes" is
        // not a sentence worth rendering, and a share would divide by zero.
        #expect(CorpusDispersion.make(volumeCounts: [0, 0, 0], indexedVolumeCount: 40) == nil)
    }

    @Test("Zero-count volumes never inflate the volume count")
    func zerosAreNotCountedAsVolumes() throws {
        let d = try #require(CorpusDispersion.make(volumeCounts: [5, 0, 3, 0], indexedVolumeCount: 40))
        #expect(d.volumes == 2,
                "`volumes` must mean volumes CONTAINING the term; counting the zeros would report a wider spread than exists")
    }

    // MARK: The share itself

    @Test("The share is the top three counts over the total of the same array")
    func shareIsTopThreeOverTotal() throws {
        // 54 + 8 + 8 = 70 of 92 — the real "Article 43" 1949 distribution, one document dominating.
        let counts = [54, 8, 8, 7, 4, 3, 3, 2, 1, 1, 1]
        let d = try #require(CorpusDispersion.make(volumeCounts: counts, indexedVolumeCount: 40))
        #expect(d.volumes == 11)
        #expect(abs(d.topThreeShare - 70.0 / 92.0) < 0.000_001)
        #expect(d.topThreePercent == 76)
        #expect(d.showsConcentration)
    }

    @Test("Order does not matter — the top three are the largest, not the first")
    func orderIndependent() throws {
        let ascending = try #require(CorpusDispersion.make(volumeCounts: [1, 2, 3, 40], indexedVolumeCount: 9))
        let descending = try #require(CorpusDispersion.make(volumeCounts: [40, 3, 2, 1], indexedVolumeCount: 9))
        #expect(ascending == descending,
                "Taking the first three rather than the largest three would make the finding depend on query result order")
        #expect(ascending.topThreeShare == 45.0 / 46.0)
    }

    @Test("Fewer than three volumes uses every volume there is, without over-counting")
    func fewerThanThreeVolumes() throws {
        let d = try #require(CorpusDispersion.make(volumeCounts: [7, 3], indexedVolumeCount: 40))
        #expect(d.topThreeShare == 1.0, "With two volumes the top three are both of them")
        #expect(d.volumes == 2)
    }

    // MARK: The concentration gate — 25%

    @Test("The 25% gate is closed just below and open at exactly 25%")
    func concentrationGateBoundary() throws {
        // Twelve volumes of equal size: the top three hold 3/12 = exactly 25%, the gate boundary.
        // (Equal counts are the only clean way to hit it exactly — with 12 volumes of 5, top three
        // is 15 of 60.)
        let atGate = try #require(
            CorpusDispersion.make(volumeCounts: Array(repeating: 5, count: 12), indexedVolumeCount: 40))
        #expect(atGate.topThreeShare == 0.25)
        #expect(atGate.showsConcentration, "The gate is >= 25%, so exactly 25% must show")

        // A common term spread evenly: 20 volumes of 5 each → top three hold 15%.
        let below = try #require(
            CorpusDispersion.make(volumeCounts: Array(repeating: 5, count: 20), indexedVolumeCount: 40))
        #expect(below.topThreePercent == 15)
        #expect(!below.showsConcentration,
                "Below the gate the sentence must stay silent — announcing 15% as a concentration is what trains readers to ignore the line")
    }

    // MARK: The concentration gate — more than three volumes

    @Test("With three volumes or fewer the concentration sentence is suppressed as tautology")
    func threeOrFewerVolumesSuppressesConcentration() throws {
        for counts in [[10], [10, 5], [10, 5, 1]] {
            let d = try #require(CorpusDispersion.make(volumeCounts: counts, indexedVolumeCount: 40))
            #expect(d.topThreeShare == 1.0)
            #expect(!d.showsConcentration,
                    "\(counts.count) volumes: \"the top 3 hold 100%\" is arithmetic, not a finding — the volume count already said it")
        }
        // Four volumes is the first case where the top three are a genuine subset.
        let four = try #require(CorpusDispersion.make(volumeCounts: [10, 5, 1, 1], indexedVolumeCount: 40))
        #expect(four.volumes == 4)
        #expect(four.showsConcentration, "At four volumes the top three exclude something, so the share is informative")
    }

    // MARK: The denominator

    @Test("The denominator is carried through unchanged — it is the device's index, not the series")
    func denominatorIsDeviceIndexed() throws {
        let d = try #require(CorpusDispersion.make(volumeCounts: [3, 2], indexedVolumeCount: 7))
        #expect(d.indexedVolumeCount == 7,
                "A share of the 552 published volumes would be a claim about data this device does not have")
        #expect(d.volumes <= d.indexedVolumeCount)
    }

    @Test("Rounding is nearest, not truncating")
    func percentRoundsToNearest() throws {
        // 6 of 9 = 66.67%, which rounds to 67 and truncates to 66. This is the only assertion in
        // the file that can tell those two apart — the earlier fixtures all land on exact
        // percentages and would pass under either rule.
        let d = try #require(CorpusDispersion.make(volumeCounts: [2, 2, 2, 1, 1, 1], indexedVolumeCount: 40))
        #expect(d.volumes == 6)
        #expect(abs(d.topThreeShare - 6.0 / 9.0) < 0.000_001)
        #expect(d.topThreePercent == 67, "Nearest, not truncated: 66.67% is 67%")

        // 1 of 3 = 33.33%, which rounds DOWN to 33 — so the rule is round-half-away, not ceiling.
        let third = try #require(
            CorpusDispersion.make(volumeCounts: [1, 1, 1, 1, 1, 1, 1, 1, 1], indexedVolumeCount: 40))
        #expect(third.topThreePercent == 33)
    }
}
