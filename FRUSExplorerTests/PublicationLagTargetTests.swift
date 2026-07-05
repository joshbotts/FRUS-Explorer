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

// MARK: - PublicationLagTargetTests

/// Pure tests for the evolving publication-timeliness target step function
/// (Analytics SA, series chart refinements): the publication-year → target
/// mapping (none / 15 / 20 / 30) at every breakpoint, and the domain-clamped
/// step-line point generation (no point before 1961; the editable range is
/// respected). No SwiftUI is instantiated.
///
/// Version history:
///   1.0 — Analytics SA (series chart refinements): initial implementation
///   1.1 — Analytics SA (series chart refinements): step indexed by publication
///          year; `StepPoint.year` (was `coverageYear`)
struct PublicationLagTargetTests {

    // MARK: - Step values at each breakpoint

    @Test("targetYears steps none → 15 → 20 → 30 at the directive breakpoints")
    func targetValuesAtBreakpoints() {
        // Before 1961: no formal target.
        #expect(PublicationLagTarget.targetYears(forYear: 1960) == nil)
        // 1961 ≤ year < 1972: 15 years (1961 directive).
        #expect(PublicationLagTarget.targetYears(forYear: 1961) == 15)
        #expect(PublicationLagTarget.targetYears(forYear: 1971) == 15)
        // 1972 ≤ year < 1985: 20 years (1972 directive).
        #expect(PublicationLagTarget.targetYears(forYear: 1972) == 20)
        #expect(PublicationLagTarget.targetYears(forYear: 1984) == 20)
        // year ≥ 1985: 30 years (1985 directive, 1991 statute).
        #expect(PublicationLagTarget.targetYears(forYear: 1985) == 30)
        #expect(PublicationLagTarget.targetYears(forYear: 1993) == 30)
    }

    @Test("Breakpoint constants are the documented directive years and values")
    func breakpointConstants() {
        #expect(PublicationLagTarget.firstTargetYear == 1961)
        #expect(PublicationLagTarget.secondTargetYear == 1972)
        #expect(PublicationLagTarget.thirdTargetYear == 1985)
        #expect(PublicationLagTarget.firstTargetYears == 15)
        #expect(PublicationLagTarget.secondTargetYears == 20)
        #expect(PublicationLagTarget.thirdTargetYears == 30)
    }

    // MARK: - Step-line points over a domain

    @Test("stepPoints over the full coverage default is [(1961,15),(1972,20),(1985,30),(1993,30)]")
    func stepPointsFullDomain() {
        let points = PublicationLagTarget.stepPoints(in: 1861...1993)
        #expect(points.map { [$0.year, $0.targetYears] }
            == [[1961, 15], [1972, 20], [1985, 30], [1993, 30]])
    }

    @Test("stepPoints emits nothing when the domain lies wholly before 1961")
    func stepPointsPre1961Empty() {
        #expect(PublicationLagTarget.stepPoints(in: 1861...1960).isEmpty)
        #expect(PublicationLagTarget.stepPoints(in: 1900...1959).isEmpty)
    }

    @Test("stepPoints never emits a point before 1961 even when the domain starts earlier")
    func stepPointsNoPointBefore1961() {
        let points = PublicationLagTarget.stepPoints(in: 1861...1993)
        #expect(points.allSatisfy { $0.year >= 1961 })
        // The first point sits exactly at the first directive year.
        #expect(points.first?.year == 1961)
    }

    @Test("stepPoints respects a narrowed editable range")
    func stepPointsNarrowedRange() {
        // A window entirely inside the 15-year era: clamped start + end, both 15.
        let midCentury = PublicationLagTarget.stepPoints(in: 1965...1970)
        #expect(midCentury.map { [$0.year, $0.targetYears] }
            == [[1965, 15], [1970, 15]])

        // A window that starts after 1961 and crosses one breakpoint.
        let crossing = PublicationLagTarget.stepPoints(in: 1965...1980)
        #expect(crossing.map { [$0.year, $0.targetYears] }
            == [[1965, 15], [1972, 20], [1980, 20]])

        // A window whose start is below 1961 clamps the first point up to 1961.
        let clampedStart = PublicationLagTarget.stepPoints(in: 1900...1975)
        #expect(clampedStart.first?.year == 1961)
        #expect(clampedStart.map(\.targetYears) == [15, 20, 20])
    }

    @Test("stepPoints yields a single point when the domain is one target-bearing year")
    func stepPointsSingleYear() {
        let points = PublicationLagTarget.stepPoints(in: 1990...1990)
        #expect(points.map { [$0.year, $0.targetYears] } == [[1990, 30]])
    }
}
