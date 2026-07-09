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
/// coverage year. It is deliberately NOT offered on the production-year SA-1 dashboard
/// (whose axis is the print year, unrelated to when the documented events occurred) nor
/// on SA-2b (which is itself organised by administration).
///
/// Version history:
///   1.0 — Session 3 / #236: administration year-range presets
struct AdministrationPresetMenu: View {

    /// The administration profiles to offer, from the bundled index. Rendered
    /// chronologically by presidency `number`; entries without a parseable start year
    /// are skipped.
    let administrations: [AdministrationProfile]
    /// The year range's start, set to the administration's term start year on selection.
    @Binding var yearStart: Int
    /// The year range's end, set to the administration's term end year (or the current
    /// year for the sitting administration) on selection.
    @Binding var yearEnd: Int
    /// Invoked after a preset is applied so the host can re-run its queries.
    var onChange: () -> Void = {}

    /// The current calendar year — the end bound for the sitting administration.
    private var currentYear: Int { Calendar.current.component(.year, from: Date()) }

    /// The four-digit year at the front of an ISO `yyyy-MM-dd` string, or `nil`.
    private func year(from iso: String) -> Int? { Int(iso.prefix(4)) }

    /// The offerable presets: administrations with a parseable start year, chronological.
    private var presets: [(profile: AdministrationProfile, start: Int, end: Int)] {
        administrations
            .compactMap { profile -> (AdministrationProfile, Int, Int)? in
                guard let start = year(from: profile.start) else { return nil }
                let end = profile.end.flatMap(year(from:)) ?? currentYear
                return (profile, start, max(start, end))
            }
            .sorted { $0.0.number < $1.0.number }
    }

    var body: some View {
        let items = presets
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
