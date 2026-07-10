// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

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
struct SeriesChartCard<Controls: View, Content: View>: View {

    /// The chart's title, shown in the header and exposed as a VoiceOver heading.
    let title: String
    /// A one-line explanatory caption below the title.
    let caption: String
    /// The chart's tabular representation; when non-nil, a "View as table" button
    /// appears in the header and invokes `onInspect` with this value.
    let inspector: ChartInspectorData?
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
            content()
        }
    }
}

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
