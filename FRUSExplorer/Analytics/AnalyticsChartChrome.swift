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

// MARK: - AnalyticsScopeBar

/// A reusable analysis-scope selector for the analytics screens (#189-B).
///
/// Names the active scope — the whole corpus, a subseries, or a single volume — and lets the
/// user change it from a menu, invoking `onChange` so the host can re-run its queries with the
/// updated `scopeVolumeIds`. Uses the same `CorpusAnalyticsService.subseries(fromVolumeId:)`
/// bucketing the charts use, so scope labels line up with the By-Subseries bars.
struct AnalyticsScopeBar: View {

    /// The indexed volume IDs available to scope over (typically `AppState.indexedVolumeIds`).
    let indexedVolumeIds: Set<String>
    /// Resolves a volume ID to its display title (from the manifest).
    let volumeTitle: (String) -> String
    /// The active volume scope; `nil` means the whole corpus.
    @Binding var scopeVolumeIds: [String]?
    /// Human-readable label for the active scope; `nil` when whole-corpus.
    @Binding var scopeLabel: String?
    /// Invoked after the scope changes so the host can re-run its queries.
    let onChange: () -> Void

    /// The distinct subseries spanned by the indexed corpus, sorted.
    private var indexedSubseries: [String] {
        Set(indexedVolumeIds.compactMap { CorpusAnalyticsService.subseries(fromVolumeId: $0) })
            .sorted()
    }

    /// The indexed volume IDs in a subseries, sorted.
    private func volumes(inSubseries subseries: String) -> [String] {
        indexedVolumeIds
            .filter { CorpusAnalyticsService.subseries(fromVolumeId: $0) == subseries }
            .sorted()
    }

    /// Name of the active scope for the menu label.
    private var currentLabel: String {
        scopeVolumeIds == nil
            ? String(localized: "analytics.scope.wholeCorpus", defaultValue: "Whole corpus")
            : (scopeLabel ?? String(localized: "analytics.scope.custom", defaultValue: "Selected volumes"))
    }

    /// Applies a new scope (or clears it when nil/empty) and notifies the host to re-run.
    private func setScope(_ ids: [String]?, label: String?) {
        let cleaned = (ids?.isEmpty == true) ? nil : ids
        scopeVolumeIds = cleaned
        scopeLabel = cleaned == nil ? nil : label
        onChange()
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "scope")
                .foregroundStyle(.secondary)
                .font(.caption)
            Menu {
                Button {
                    setScope(nil, label: nil)
                } label: {
                    Label(String(localized: "analytics.scope.wholeCorpus", defaultValue: "Whole corpus"),
                          systemImage: scopeVolumeIds == nil ? "checkmark" : "globe")
                }
                let subseries = indexedSubseries
                if !subseries.isEmpty {
                    Divider()
                    Menu(String(localized: "analytics.scope.bySubseries", defaultValue: "By Subseries")) {
                        ForEach(subseries, id: \.self) { sub in
                            Button(sub) { setScope(volumes(inSubseries: sub), label: sub) }
                        }
                    }
                    Menu(String(localized: "analytics.scope.byVolume", defaultValue: "By Volume")) {
                        ForEach(subseries, id: \.self) { sub in
                            Menu(sub) {
                                ForEach(volumes(inSubseries: sub), id: \.self) { volumeId in
                                    Button(volumeTitle(volumeId)) {
                                        setScope([volumeId], label: volumeTitle(volumeId))
                                    }
                                }
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(String(format: String(localized: "analytics.scope.label %@",
                                                defaultValue: "Scope: %@"), currentLabel))
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                }
            }
            Spacer()
            if scopeVolumeIds != nil {
                Button {
                    setScope(nil, label: nil)
                } label: {
                    Text(String(localized: "analytics.scope.clear", defaultValue: "Whole corpus"))
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }
}

// MARK: - AnalyticsCollapsibleSection

/// A collapsible chart section for the analytics dashboards (#207/#209): a tappable header
/// (title + chevron) that expands/collapses a chart body, with an optional strip of
/// chart-specific controls pinned at the top of the disclosed body.
///
/// Wrapping each chart lets users focus on one at a time, and hosting a chart's own controls
/// inside its section (instead of a shared toolbar) makes it unambiguous which chart a control
/// like "By decade" or "Out-degree" affects. The parent owns the expansion `@Binding` (typically
/// `@AppStorage`, so the choice persists), and each screen uses distinct keys so the sections
/// don't share state.
///
/// Modeled on `DocumentView.iOSPanelSectionHeader` (same chevron/animation language). Children
/// stay individually accessible; the header carries expanded/collapsed value + a header trait.
///
/// Version history:
///   1.0 — #207 (analytics UI): shared collapsible chart section.
struct AnalyticsCollapsibleSection<Controls: View, Content: View>: View {

    /// Localized section title, shown in the header and used as its accessibility label.
    let title: String
    /// Whether the section is expanded. Owned (and typically persisted) by the parent.
    @Binding var isExpanded: Bool
    /// Chart-specific controls pinned at the top of the disclosed body (empty for chartless
    /// sections). Rendered only when expanded.
    @ViewBuilder var controls: () -> Controls
    /// The chart/table body. Rendered only when expanded.
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
            } label: {
                HStack {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .padding(.horizontal)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityAddTraits(.isHeader)
            .accessibilityValue(isExpanded
                                ? String(localized: "analytics.section.expanded", defaultValue: "Expanded")
                                : String(localized: "analytics.section.collapsed", defaultValue: "Collapsed"))

            if isExpanded {
                controls()
                content()
            }
        }
    }
}

extension AnalyticsCollapsibleSection where Controls == EmptyView {
    /// Convenience for a section with no chart-specific controls.
    init(title: String, isExpanded: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) {
        self.init(title: title, isExpanded: isExpanded, controls: { EmptyView() }, content: content)
    }
}
