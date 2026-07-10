// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - SeriesChartKind

/// Which kind of x-axis a Series-analytics time-series chart carries, and hence
/// which fixed default x-domain and upper clamp it should use.
///
/// The three "About the Series" dashboards plot two different x semantics:
///
///   - **`.coverage`** — the x value is a document *coverage* year or decade (the
///     year a volume documents, not the year it was printed). Coverage data stops
///     around 1990 because the series has not yet declassified past it, so a
///     coverage axis should never extend past 1993 no matter how wide the user's
///     range is: default domain `1861...1993`.
///   - **`.production`** — the x value is a *print/publication* year, which runs
///     right up to the present as new volumes ship: default domain `1861...2026`.
///
/// The shared `1861` floor is the series' start year; it deliberately excludes the
/// pre-1861 retrospective-compilation outliers (e.g. a stray 1740s coverage decade)
/// that would otherwise cram the real data into a sliver of the plot width.
///
/// Version history:
///   1.0 — Analytics SA (series x-axis bounds): initial implementation
///   1.1 — Session 3 / #236: shared `yearAxisFormat` (grouping-free integer years),
///          consolidated here from the four dashboards' per-file copies
enum SeriesChartKind: Sendable {
    /// The x value is a document coverage year/decade (clamps at 1993).
    case coverage
    /// The x value is a print/publication year (runs to 2026).
    case production

    /// The lower bound shared by both kinds — the FRUS series' start year.
    static let floorYear = 1861

    /// The upper bound a coverage axis is clamped to: there is no coverage data
    /// past roughly 1990, so the axis stops at 1993 even when the user range runs
    /// to the present.
    static let coverageCeilingYear = 1993

    /// The upper bound a production axis extends to — effectively "the present"
    /// for publication years.
    static let productionCeilingYear = 2026

    /// This kind's fixed default x-domain (before any user range is applied):
    /// `1861...1993` for coverage, `1861...2026` for production.
    var defaultDomain: ClosedRange<Int> {
        switch self {
        case .coverage:   return Self.floorYear...Self.coverageCeilingYear
        case .production: return Self.floorYear...Self.productionCeilingYear
        }
    }

    /// Format style for integer year/decade axis labels that suppresses comma
    /// grouping — years should display as `1950`, not `1,950`. Shared by all four
    /// "About the Series" dashboards (previously a `private static let` in each).
    static let yearAxisFormat = IntegerFormatStyle<Int>.number.grouping(.never)
}

// MARK: - Effective domain

/// The x-axis domain a chart should actually use, given the user's editable
/// start/end year range and the chart's kind.
///
/// - For `.production`, the user range passes through unchanged
///   (`userStart...userEnd`).
/// - For `.coverage`, the end is clamped to `SeriesChartKind.coverageCeilingYear`
///   (1993) so a coverage chart never wastes width on the empty 1994–2026 tail even
///   when the user's range (e.g. SA-1's default `1861...2026`) runs past it.
///
/// The bounds are guarded so a caller that somehow supplies `userStart > userEnd`
/// still gets a valid non-empty single-year range rather than a crash.
///
/// - Parameters:
///   - userStart: The user's chosen start year.
///   - userEnd: The user's chosen end year.
///   - kind: Whether the chart's x-axis is coverage- or production-valued.
/// - Returns: The `ClosedRange<Int>` to feed to `.chartXScale(domain:)` and to
///   filter the plotted data against.
func effectiveDomain(
    userStart: Int,
    userEnd: Int,
    kind: SeriesChartKind
) -> ClosedRange<Int> {
    // Guard against an inverted range: collapse to a single valid year.
    let lower = min(userStart, userEnd)
    var upper = max(userStart, userEnd)
    if kind == .coverage {
        upper = min(upper, SeriesChartKind.coverageCeilingYear)
    }
    // After clamping the coverage ceiling, `upper` could fall below `lower`
    // (e.g. userStart 2000, kind .coverage → upper 1993 < 2000). Keep it valid.
    return min(lower, upper)...max(lower, upper)
}
