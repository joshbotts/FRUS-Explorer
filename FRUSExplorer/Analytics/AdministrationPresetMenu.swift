// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - AdministrationPresetMenu

/// A one-tap preset menu that sets an analytics year range to a presidential
/// administration's term years (#236 ride-along), sitting beside an
/// `AnalyticsYearRangeBar`.
///
/// The administration terms are read from the already-loaded
/// `AdministrationProfilesIndex` (each `AdministrationProfile` carries the same ISO
/// `start`/`end` dates the SA-2 dashboard uses), so no new resource is wired and the
/// date semantics match SA-2 exactly rather than being re-derived.
///
/// The range it writes is a **coverage / document-year** span (the years the president
/// was in office), so this control belongs only on coverage-year surfaces — corpus
/// term-frequency and cross-reference analytics, whose year filter is the document's
/// coverage year. It is deliberately NOT offered on any of the four Series dashboards:
/// SA-1's axis is the print/production year (unrelated to when the documented events
/// occurred), SA-2b is itself organised by administration (a term preset would be
/// circular), and SA-2's and SA-3's coverage axes are decade-granular — an exact
/// term-year span would imply a precision those charts cannot honour.
///
/// Presets are **bounded by the host's year range** (`floorYear...corpusMaxYear`):
/// administrations whose term falls entirely outside that span are not offered (the
/// post-corpus administrations, Clinton onward, carry zero attributed documents and
/// could only produce an empty chart), and a straddling term's years are clamped into
/// it. The clamp is load-bearing, not cosmetic — the host's `AnalyticsYearRangeBar`
/// eagerly builds its end field's bounds as `start...corpusMaxYear`, so writing a raw
/// start year past the corpus ceiling (e.g. 1993 against a 1992 ceiling) would form an
/// invalid `ClosedRange` and trap.
///
/// Version history:
///   1.0 — Session 3 / #236: administration year-range presets
///   1.1 — Session 3 review: presets filtered to terms intersecting
///         `floorYear...corpusMaxYear` and clamped on write (a raw post-corpus term
///         start made the year bar's eager `start...corpusMaxYear` bounds invalid and
///         trapped); sitting-term end year fixed to the Gregorian calendar
struct AdministrationPresetMenu: View {

    /// The administration profiles to offer, from the bundled index. Rendered
    /// chronologically by presidency `number`; entries without a parseable start year
    /// or whose term never intersects `Self.floorYear...corpusMaxYear` are skipped.
    let administrations: [AdministrationProfile]
    /// The host's most recent corpus year — the year range's hard upper bound (the
    /// same value the host passes to `AnalyticsYearRangeBar.corpusMaxYear`). Preset
    /// years are clamped into `Self.floorYear...corpusMaxYear` so a selection can
    /// never escape the bar's eagerly-built field bounds.
    let corpusMaxYear: Int
    /// The year range's start, set to the administration's (clamped) term start year
    /// on selection.
    @Binding var yearStart: Int
    /// The year range's end, set to the administration's (clamped) term end year (or
    /// the current year for the sitting administration) on selection.
    @Binding var yearEnd: Int
    /// Invoked after a preset is applied so the host can re-run its queries.
    var onChange: () -> Void = {}

    /// The corpus floor year (the first FRUS volume, 1861) — the hosts' shared lower
    /// bound and reset target for the year range's start.
    static let floorYear = 1861

    /// The offerable presets: administrations whose term intersects
    /// `floorYear...corpusMaxYear`, with term years clamped into that span,
    /// chronological by presidency number. Pure (`nonisolated`, injected clock) so
    /// the bounding/clamping contract is directly unit-testable off the main actor.
    ///
    /// - Parameters:
    ///   - administrations: The bundled index's administrations.
    ///   - corpusMaxYear: The host's corpus ceiling year (upper clamp bound).
    ///   - currentYear: The current calendar year — the end bound applied to the
    ///     sitting administration's open term before clamping.
    /// - Returns: The bounded, clamped presets in presidency-number order.
    nonisolated static func presets(
        from administrations: [AdministrationProfile],
        corpusMaxYear: Int,
        currentYear: Int
    ) -> [(profile: AdministrationProfile, start: Int, end: Int)] {
        administrations
            .compactMap { profile -> (AdministrationProfile, Int, Int)? in
                guard let start = Int(profile.start.prefix(4)) else { return nil }
                let end = max(start, profile.end.flatMap { Int($0.prefix(4)) } ?? currentYear)
                // Drop terms that never intersect the host's span (the zero-document
                // post-corpus administrations), then clamp straddlers into it.
                guard start <= corpusMaxYear && end >= floorYear else { return nil }
                let clampedStart = min(max(start, floorYear), corpusMaxYear)
                let clampedEnd = max(clampedStart, min(end, corpusMaxYear))
                return (profile, clampedStart, clampedEnd)
            }
            .sorted { $0.0.number < $1.0.number }
    }

    /// The current Gregorian calendar year — the end bound for the sitting
    /// administration. Pinned to `.gregorian` so a non-Gregorian device calendar
    /// (e.g. Buddhist, Japanese) cannot skew the year arithmetic.
    private var currentYear: Int {
        Calendar(identifier: .gregorian).component(.year, from: Date())
    }

    var body: some View {
        let items = Self.presets(from: administrations,
                                 corpusMaxYear: corpusMaxYear,
                                 currentYear: currentYear)
        if !items.isEmpty {
            Menu {
                ForEach(items, id: \.profile.id) { item in
                    Button {
                        yearStart = item.start
                        yearEnd = item.end
                        onChange()
                    } label: {
                        Text(String(format: String(localized: "analytics.adminPreset.item %@ %lld %lld",
                                                   defaultValue: "%@ (%lld–%lld)"),
                                    item.profile.president, Int64(item.start), Int64(item.end)))
                    }
                }
            } label: {
                Label(String(localized: "analytics.adminPreset.label", defaultValue: "Administration"),
                      systemImage: "building.columns")
                    .font(.caption)
            }
            .help(String(localized: "analytics.adminPreset.help",
                         defaultValue: "Set the year range to a presidential administration's years in office"))
            .accessibilityLabel(String(localized: "analytics.adminPreset.a11y",
                                       defaultValue: "Set year range to an administration's term"))
        }
    }
}
