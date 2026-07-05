// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - PublicationLagTarget

/// The evolving historical target for FRUS publication timeliness, expressed as
/// a step function over the coverage-end year (the lag chart's x-axis).
///
/// FRUS had no formal timeliness target for most of its history. A sequence of
/// presidential directives progressively tightened the expectation before the
/// 1991 statute codified it:
///
///   - **Before 1961** — no formal target (no line drawn).
///   - **1961 ≤ year < 1972** — 15 years (1961 presidential directive).
///   - **1972 ≤ year < 1985** — 20 years (1972 presidential directive).
///   - **year ≥ 1985** — 30 years (1985 presidential directive, later codified
///     by the 1991 FRUS statute).
///
/// - Important: MODELING NOTE — the breakpoints here are indexed by **coverage
///   year** (the lag chart's x-axis: a volume's latest document year), which is a
///   deliberate *simplification*. The directives are calendar events dated by the
///   year they were issued; strictly, a volume covering year *X* was judged by
///   whatever directive was in force at the time it was *published*, not by the
///   directive whose issue year matches *X*. Indexing the step by coverage year is
///   the literal reading of "a 1961 directive called for a 15-year line" and keeps
///   the target line on the same axis as the plotted lag points. If publication-year
///   indexing is preferred, this helper is the single place to change.
///
/// The type is pure and deterministic (no SwiftUI, no I/O), so it is fully
/// unit-testable.
///
/// Version history:
///   1.0 — Analytics SA (series chart refinements): initial implementation
enum PublicationLagTarget {

    // MARK: Breakpoints

    /// The coverage year at/after which the first (15-year) target applies —
    /// the 1961 presidential directive. No target line is drawn before this.
    static let firstTargetYear = 1961

    /// The coverage year at/after which the target rises to 20 years — the
    /// 1972 presidential directive.
    static let secondTargetYear = 1972

    /// The coverage year at/after which the target rises to 30 years — the
    /// 1985 presidential directive, later codified by the 1991 statute.
    static let thirdTargetYear = 1985

    /// The 1961 directive's target in years.
    static let firstTargetYears = 15
    /// The 1972 directive's target in years.
    static let secondTargetYears = 20
    /// The 1985 directive's / 1991 statute's target in years.
    static let thirdTargetYears = 30

    // MARK: Step evaluation

    /// The publication-timeliness target in force for a given coverage year, or
    /// `nil` before the first (1961) directive, when no formal target existed.
    ///
    /// - Parameter coverageYear: A volume's coverage-end (latest-document) year.
    /// - Returns: The target lag in years, or `nil` if `coverageYear < 1961`.
    static func targetYears(forCoverageYear coverageYear: Int) -> Int? {
        switch coverageYear {
        case ..<firstTargetYear:                    return nil
        case firstTargetYear..<secondTargetYear:    return firstTargetYears
        case secondTargetYear..<thirdTargetYear:    return secondTargetYears
        default:                                    return thirdTargetYears
        }
    }

    // MARK: Step-line points

    /// One point on the step target line: a coverage year and the target lag in
    /// force from that year onward.
    struct StepPoint: Identifiable, Sendable, Hashable {
        /// The coverage-end year at which this target segment begins.
        let coverageYear: Int
        /// The target lag (in years) in force from `coverageYear` onward.
        let targetYears: Int

        /// Stable identity (also the x-value): the coverage year.
        var id: Int { coverageYear }
    }

    /// The step-line points to plot over a given coverage-year domain, drawn with
    /// `.interpolationMethod(.stepEnd)` so each value holds until the next
    /// breakpoint.
    ///
    /// The line only exists from 1961 onward: if the domain ends before 1961 the
    /// result is empty (no target line). Each breakpoint that falls inside the
    /// domain contributes a point; the domain's own bounds are added as anchor
    /// points (clamped to the ≥1961 target-bearing sub-range) so the step spans
    /// the full visible, target-bearing width and respects the editable year range.
    ///
    /// For the full default coverage domain (`1861…1993`) this yields
    /// `[(1961,15), (1972,20), (1985,30), (1993,30)]`.
    ///
    /// - Parameter domain: The chart's effective coverage-year domain.
    /// - Returns: Ascending, de-duplicated step points; empty when the domain lies
    ///   wholly before 1961.
    static func stepPoints(in domain: ClosedRange<Int>) -> [StepPoint] {
        // The target line only exists from the first directive year onward.
        let start = max(domain.lowerBound, firstTargetYear)
        let end = domain.upperBound
        guard start <= end else { return [] }

        // Candidate x-positions: the domain's clamped start, each interior
        // breakpoint, and the domain's end. De-duplicate + sort, then attach the
        // target in force at each.
        var years: Set<Int> = [start, end]
        for breakpoint in [firstTargetYear, secondTargetYear, thirdTargetYear]
        where breakpoint > start && breakpoint < end {
            years.insert(breakpoint)
        }
        return years.sorted().compactMap { year in
            targetYears(forCoverageYear: year).map {
                StepPoint(coverageYear: year, targetYears: $0)
            }
        }
    }
}
