// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
#if canImport(Accessibility)
import Accessibility
#endif

// MARK: - SeriesChartCard

/// A titled, captioned container for a single Series-analytics chart, keeping the
/// four "About the Series" dashboards visually consistent.
///
/// Extracted from the identical private `chartCard` helper that lived in all four
/// dashboards (#236). When `inspector` is non-nil the header gains a trailing "View
/// as table" button; tapping it calls `onInspect(inspector)`, letting each dashboard
/// keep ownership of its `inspectorData` sheet state. An optional `controls` slot sits
/// between the caption and the chart for any per-chart controls (empty by default —
/// this session's scope pickers live at the dashboard level, not per chart).
///
/// Version history:
///   1.0 — Session 3 / #236: extracted the shared chart card; title carries the
///          `.isHeader` accessibility trait
///   1.1 — Session 2026-08-10: #832(b) — the Audio Graph descriptor gains a
///          `View.axChartDescriptor` entry point for charts this card cannot host
struct SeriesChartCard<Controls: View, Content: View>: View {

    /// The chart's title, shown in the header and exposed as a VoiceOver heading.
    let title: String
    /// A one-line explanatory caption below the title.
    let caption: String
    /// The chart's tabular representation; when non-nil, a "View as table" button
    /// appears in the header and invokes `onInspect` with this value.
    let inspector: ChartInspectorData?
    /// Which inspector columns feed the Audio Graph descriptor — see
    /// `AXChartDescriptorModifier`. Defaults fit the Series tables; the archival ranking and
    /// bands tables carry their category NAME at column 1 and their count at column 2, so the
    /// default silently refused there for as long as the card has hosted them (#268: adopted
    /// in source, nothing delivered at runtime).
    var axLabelColumn: Int = 0
    var axValueColumn: Int = 1
    /// Invoked with `inspector` when the user taps "View as table" — the host opens
    /// its own `.sheet` from the value.
    let onInspect: (ChartInspectorData) -> Void
    /// Per-chart controls pinned between the caption and the chart (empty by default).
    @ViewBuilder let controls: () -> Controls
    /// The chart body.
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if let inspector {
                    Button {
                        onInspect(inspector)
                    } label: {
                        Label(
                            String(localized: "series.inspector.viewTable", defaultValue: "View as table"),
                            systemImage: "tablecells"
                        )
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text(String(
                        localized: "series.inspector.viewTable.a11y",
                        defaultValue: "View \(title) as a table"
                    )))
                }
            }
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            controls()
            // #268: the Audio Graph descriptor, derived from the same table the "View as table"
            // button shows — one adoption point for every Series chart rather than one per
            // dashboard. Charts whose inspector cells are not numeric get no descriptor rather
            // than a wrong one; see `AXChartDescriptorBuilder.points(from:)`.
            content()
                .modifier(AXChartDescriptorModifier(inspector: inspector, title: title,
                                                    labelColumn: axLabelColumn,
                                                    valueColumn: axValueColumn))
        }
    }
}

// MARK: - AXChartDescriptorModifier

/// Attaches an `AXChartDescriptor` when the chart's inspector table can supply one (#268).
///
/// A modifier rather than an inline `.accessibilityChartDescriptor` so the `canImport` guard and
/// the "no descriptor is better than a wrong one" refusal live in one place, and so charts with no
/// inspector — or with a non-numeric one — are simply untouched.
///
/// ``SeriesChartCard`` applies it for every chart it hosts. Charts that cannot be hosted by the
/// card — one inside a `List` section, where the section header is already the chart's heading and
/// the card's own title would render a second one — reach it through
/// ``SwiftUI/View/axChartDescriptor(inspector:title:)``.
struct AXChartDescriptorModifier: ViewModifier {
    let inspector: ChartInspectorData?
    let title: String
    /// Which table column holds the x label / plotted value. The defaults (0, 1) fit the
    /// Series tables this shipped with. THEY DO NOT FIT the corpus analytics tables — there
    /// column 0 is the term and column 1 the period, and "1969" PARSES, so the default would
    /// have sonified years as values without a sound of complaint. Every adoption states its
    /// columns; `AXChartDescriptorTests` pins each table's indices against the real builders.
    var labelColumn: Int = 0
    var valueColumn: Int = 1
    /// Set for an interleaved multi-series table (a compare table, the trajectory table):
    /// rows split into one audio series per distinct value of this column. Without it such a
    /// table would flatten into one zig-zag series crossing every term — which parses cleanly
    /// and is wrong.
    var splitBySeriesColumn: Int? = nil

    func body(content: Content) -> some View {
        #if canImport(Accessibility)
        if let descriptor = builtDescriptor {
            content.accessibilityChartDescriptor(FixedChartDescriptor(descriptor))
        } else {
            content
        }
        #else
        content
        #endif
    }

    #if canImport(Accessibility)
    private var builtDescriptor: AXChartDescriptor? {
        guard let inspector else { return nil }
        let xLabel = inspector.columns.indices.contains(labelColumn)
            ? inspector.columns[labelColumn] : ""
        let yLabel = inspector.columns.indices.contains(valueColumn)
            ? inspector.columns[valueColumn] : ""
        if let seriesColumn = splitBySeriesColumn {
            guard let split = AXChartDescriptorBuilder.seriesSplit(
                from: inspector, seriesColumn: seriesColumn,
                labelColumn: labelColumn, valueColumn: valueColumn) else { return nil }
            return AXChartDescriptorBuilder.descriptor(
                title: title, xLabel: xLabel, yLabel: yLabel, namedSeries: split)
        }
        guard let points = AXChartDescriptorBuilder.points(
            from: inspector, labelColumn: labelColumn, valueColumn: valueColumn)
        else { return nil }
        return AXChartDescriptorBuilder.descriptor(
            title: title, xLabel: xLabel, yLabel: yLabel, points: points)
    }
    #endif
}

extension View {

    /// Attaches the Audio Graph descriptor to a chart that ``SeriesChartCard`` does not host (#268).
    ///
    /// Same refusal as the card's: a chart whose inspector table has no numeric value column gets
    /// **no** descriptor rather than a wrong one, because an audio graph missing points still
    /// sounds complete.
    ///
    /// - Parameters:
    ///   - inspector: The chart's tabular form — the same value its "View as table" button shows,
    ///     so the sonified series and the readable one cannot drift apart.
    ///   - title: The descriptor's title, normally the chart's own heading.
    func axChartDescriptor(
        inspector: ChartInspectorData?,
        title: String,
        labelColumn: Int = 0,
        valueColumn: Int = 1,
        splitBySeriesColumn: Int? = nil
    ) -> some View {
        modifier(AXChartDescriptorModifier(inspector: inspector, title: title,
                                           labelColumn: labelColumn, valueColumn: valueColumn,
                                           splitBySeriesColumn: splitBySeriesColumn))
    }
}

#if canImport(Accessibility)
/// Wraps a prebuilt descriptor in the representable SwiftUI wants.
private struct FixedChartDescriptor: AXChartDescriptorRepresentable {
    let descriptor: AXChartDescriptor
    init(_ descriptor: AXChartDescriptor) { self.descriptor = descriptor }
    func makeChartDescriptor() -> AXChartDescriptor { descriptor }
    func updateChartDescriptor(_ descriptor: AXChartDescriptor) {}
}
#endif

extension SeriesChartCard where Controls == EmptyView {
    /// Convenience for a card with no per-chart controls.
    ///
    /// - Parameters:
    ///   - title: The chart title.
    ///   - caption: The explanatory caption.
    ///   - inspector: The chart's tabular representation, or `nil`.
    ///   - onInspect: Invoked with `inspector` when "View as table" is tapped.
    ///   - content: The chart body.
    init(
        title: String,
        caption: String,
        inspector: ChartInspectorData?,
        onInspect: @escaping (ChartInspectorData) -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(title: title, caption: caption, inspector: inspector,
                  onInspect: onInspect, controls: { EmptyView() }, content: content)
    }
}
