// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - AnalyticsYearRangeBar

/// Compact year-range filter bar for the Corpus analytics charts.
///
/// Two clamped year-entry fields (each a `Stepper` wrapping an editable `TextField`)
/// separated by an en-dash, with a "Reset" affordance shown only when the range has
/// been narrowed away from its defaults. Extracted verbatim from `AnalyticsView` in
/// Prep-B so the forthcoming Corpus dashboards (CA-5+) can reuse the exact control
/// without duplicating it; `AnalyticsView` composes it unchanged.
///
/// The parent owns the range as two `@Binding` integers and supplies the bounds
/// context (`corpusMaxYear`, `isCompactWidth`, `isCustom`) plus the reset action, so
/// this view stays free of any `AppState` / manifest dependency.
///
/// Version history:
///   1.0 — Prep-B (analytics CA-track): lifted from `AnalyticsView.yearRangeBar` /
///          `yearEntryField` with identical appearance and behavior.
struct AnalyticsYearRangeBar: View {

    /// Start year of the range. Clamped on write to `1776...end`.
    @Binding var start: Int
    /// End year of the range. Clamped on write to `start...corpusMaxYear`.
    @Binding var end: Int

    /// Most recent corpus year — the upper bound and the reset target for `end`.
    let corpusMaxYear: Int
    /// `true` on a compact-width layout (iPhone), where the "Year range:" label is
    /// dropped so the space goes to the fields.
    let isCompactWidth: Bool
    /// `true` when the range has been narrowed away from the `1861...corpusMaxYear`
    /// default; drives the "Reset" button's visibility.
    let isCustom: Bool
    /// Resets the range to its default span (`1861...corpusMaxYear`). Owned by the
    /// parent so the default constants live in one place.
    let onReset: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar")
                .foregroundStyle(.secondary)
                .font(.caption)

            // The "Year range:" label is dropped on compact width (iPhone): the
            // calendar icon carries the meaning and the space goes to the fields.
            if !isCompactWidth {
                Text(String(localized: "analytics.yearRange.label",
                            defaultValue: "Year range:"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            yearEntryField(
                value: $start,
                bounds: 1776...end,
                accessibilityLabel: String(localized: "analytics.yearRange.start.a11y",
                                           defaultValue: "Start year")
            )

            Text(verbatim: "–")
                .foregroundStyle(.tertiary)
                .font(.caption)

            yearEntryField(
                value: $end,
                bounds: start...corpusMaxYear,
                accessibilityLabel: String(localized: "analytics.yearRange.end.a11y",
                                           defaultValue: "End year")
            )

            if isCustom {
                Button {
                    onReset()
                } label: {
                    Text(String(localized: "analytics.yearRange.reset",
                                defaultValue: "Reset"))
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Color.accentColor)
                .help(String(
                    localized: "analytics.yearRange.reset.help",
                    defaultValue: "Reset the year range to 1861 – current year (the full FRUS corpus span)"
                ))
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    /// A year value rendered as an editable, clamped text field paired with an
    /// up/down stepper. Typing commits a value (clamped into `bounds`), letting
    /// the user jump directly to a year instead of stepping one at a time; the
    /// stepper remains for fine adjustment.
    private func yearEntryField(
        value: Binding<Int>,
        bounds: ClosedRange<Int>,
        accessibilityLabel: String
    ) -> some View {
        // Clamp on write so a typed (or stepped) value can never escape `bounds`.
        let clamped = Binding<Int>(
            get: { value.wrappedValue },
            set: { value.wrappedValue = min(max($0, bounds.lowerBound), bounds.upperBound) }
        )
        return Stepper(value: clamped, in: bounds) {
            TextField(
                String(localized: "analytics.yearRange.field.placeholder", defaultValue: "Year"),
                value: clamped,
                format: .number.grouping(.never)
            )
            .labelsHidden()
            .multilineTextAlignment(.trailing)
            .font(.caption.monospacedDigit())
            .frame(width: 44)
            .textFieldStyle(.roundedBorder)
            #if os(iOS)
            .keyboardType(.numberPad)
            #endif
        }
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - AnalyticsViewModePicker

/// The chart-vs-table segmented control for the Corpus analytics toolbar.
///
/// A two-segment `Picker` (bar-chart glyph / bulleted-list glyph) bound to an
/// `AnalyticsViewMode`. Extracted from `AnalyticsView`'s toolbar in Prep-B so the
/// same control can be reused by the forthcoming Corpus dashboards; the parent
/// supplies the binding and a `disabled` flag (the analytics view disables it until
/// a term is committed). Appearance and behavior are identical to the inline version.
///
/// Version history:
///   1.0 — Prep-B (analytics CA-track): lifted from `AnalyticsView.toolbarContent`
///          (the view-mode segment) with identical appearance and behavior.
struct AnalyticsViewModePicker: View {

    /// The active presentation mode.
    @Binding var viewMode: AnalyticsViewMode
    /// `true` to disable the control (e.g. before a term has been committed).
    var isDisabled: Bool

    var body: some View {
        Picker(
            String(localized: "analytics.viewMode.picker", defaultValue: "Display"),
            selection: $viewMode
        ) {
            Image(systemName: "chart.bar")
                .tag(AnalyticsViewMode.chart)
                .accessibilityLabel(
                    String(localized: "analytics.viewMode.chart.a11y", defaultValue: "Chart")
                )
            Image(systemName: "list.bullet")
                .tag(AnalyticsViewMode.table)
                .accessibilityLabel(
                    String(localized: "analytics.viewMode.table.a11y", defaultValue: "Table")
                )
        }
        .pickerStyle(.segmented)
        .disabled(isDisabled)
        .help(String(
            localized: "analytics.viewMode.picker.help",
            defaultValue: "Switch between chart visualisation and a tabular list of the same data"
        ))
    }
}
