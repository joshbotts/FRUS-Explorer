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
/// a step function over the publication year (the lag chart's x-axis).
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
/// The step is indexed by **publication year** — the directive in force when a
/// volume was actually published. Because the directives are calendar events, a
/// volume is judged by whatever target was in force on its print date, so
/// indexing the step by publication year (which is the lag chart's x-axis) is
/// exact, not a simplification.
///
/// The type is pure and deterministic (no SwiftUI, no I/O), so it is fully
/// unit-testable.
///
/// Version history:
///   1.0 — Analytics SA (series chart refinements): initial implementation
///   1.1 — Analytics SA (series chart refinements): step indexed by publication
///          year (exact) rather than coverage year; `StepPoint.coverageYear`
///          renamed to `year`
enum PublicationLagTarget {

    // MARK: Breakpoints

    /// The publication year at/after which the first (15-year) target applies —
    /// the 1961 presidential directive. No target line is drawn before this.
    static let firstTargetYear = 1961

    /// The publication year at/after which the target rises to 20 years — the
    /// 1972 presidential directive.
    static let secondTargetYear = 1972

    /// The publication year at/after which the target rises to 30 years — the
    /// 1985 presidential directive, later codified by the 1991 statute.
    static let thirdTargetYear = 1985

    /// The 1961 directive's target in years.
    static let firstTargetYears = 15
    /// The 1972 directive's target in years.
    static let secondTargetYears = 20
    /// The 1985 directive's / 1991 statute's target in years.
    static let thirdTargetYears = 30

    // MARK: Step evaluation

    /// The publication-timeliness target in force for a given publication year,
    /// or `nil` before the first (1961) directive, when no formal target existed.
    ///
    /// - Parameter year: A volume's publication (print) year.
    /// - Returns: The target lag in years, or `nil` if `year < 1961`.
    static func targetYears(forYear year: Int) -> Int? {
        switch year {
        case ..<firstTargetYear:                    return nil
        case firstTargetYear..<secondTargetYear:    return firstTargetYears
        case secondTargetYear..<thirdTargetYear:    return secondTargetYears
        default:                                    return thirdTargetYears
        }
    }

    // MARK: Step-line points

    /// One point on the step target line: a publication year and the target lag
    /// in force from that year onward.
    struct StepPoint: Identifiable, Sendable, Hashable {
        /// The publication year at which this target segment begins.
        let year: Int
        /// The target lag (in years) in force from `year` onward.
        let targetYears: Int

        /// Stable identity (also the x-value): the publication year.
        var id: Int { year }
    }

    /// The step-line points to plot over a given publication-year domain, drawn
    /// with `.interpolationMethod(.stepEnd)` so each value holds until the next
    /// breakpoint.
    ///
    /// The line only exists from 1961 onward: if the domain ends before 1961 the
    /// result is empty (no target line). Each breakpoint that falls inside the
    /// domain contributes a point; the domain's own bounds are added as anchor
    /// points (clamped to the ≥1961 target-bearing sub-range) so the step spans
    /// the full visible, target-bearing width and respects the editable year range.
    ///
    /// For the full default production domain (`1861…2026`) this yields
    /// `[(1961,15), (1972,20), (1985,30), (2026,30)]`.
    ///
    /// - Parameter domain: The chart's effective publication-year domain.
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
            targetYears(forYear: year).map {
                StepPoint(year: year, targetYears: $0)
            }
        }
    }
}
