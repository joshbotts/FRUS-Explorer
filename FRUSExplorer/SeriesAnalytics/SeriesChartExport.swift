// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - SeriesExportBox

/// The share sheet and error state one About-the-Series dashboard needs to deliver an export
/// (#790).
///
/// A reference box rather than two `@State` properties per dashboard, so the four dashboards
/// declare one property each and hand the box to their `chartCard` helper. The alternative —
/// duplicating the state, the delivery functions, the sheet and the alert four times — is how the
/// four `chartCard` helpers themselves came to be four copies of the same eleven lines.
///
/// Version history:
///   1.0 — Session 2026-08-09: #790
@Observable
final class SeriesExportBox {
    /// The file waiting to be shared on iOS; `nil` when nothing is pending.
    var shareItem: AnalyticsExportFile?
    /// An export failure, surfaced rather than swallowed.
    var error: String?

    /// Creates an empty box.
    init() {}

    /// Writes one table with its methods statement above it.
    ///
    /// The preamble is the point. `ChartInspectorData.csv` is the bare table, and until #790 that
    /// was the only way a Series figure's numbers could leave the app — no scope, no year range,
    /// no app version, and none of the caveats the dashboard prints on screen.
    @MainActor
    func deliver(_ table: ChartInspectorData, _ provenance: AnalyticsProvenance) {
        let filename = AnalyticsExportDelivery.filenameStem(title: provenance.figureTitle) + ".csv"
        switch AnalyticsExportDelivery.deliver(text: table.provenancedCSV(provenance),
                                               filename: filename) {
        case .share(let item): shareItem = item
        case .saved, .cancelled: break
        case .failed(let reason): error = reason
        }
    }

    /// Renders one chart as a publication figure and shares or saves it.
    ///
    /// - Parameters:
    ///   - format: PNG or vector PDF.
    ///   - provenance: The methods statement printed on the plate.
    ///   - chartHeight: The plate's chart area.
    ///   - chart: The chart itself. `AnalyticsFigureCanvas` renders detached from the view
    ///     hierarchy and inherits no environment, so everything the closure reads must already be
    ///     resolved — which is true of these dashboards, whose charts are pure functions of an
    ///     already-derived value.
    @MainActor
    func deliverFigure<Content: View>(_ format: AnalyticsFigureFormat,
                                      provenance: AnalyticsProvenance,
                                      chartHeight: CGFloat,
                                      @ViewBuilder chart: @escaping () -> Content) {
        let canvas = AnalyticsFigureCanvas(provenance: provenance, chartHeight: chartHeight,
                                            content: chart)
        guard let data = AnalyticsFigureExporter.render(canvas, format: format) else {
            error = String(localized: "analytics.export.error.render",
                           defaultValue: "The figure could not be rendered.")
            return
        }
        let filename = AnalyticsExportDelivery.filenameStem(title: provenance.figureTitle)
            + "." + format.pathExtension
        switch AnalyticsExportDelivery.deliver(data: data, filename: filename,
                                               contentType: format.contentType) {
        case .share(let item): shareItem = item
        case .saved, .cancelled: break
        case .failed(let reason): error = reason
        }
    }
}

// MARK: - Presentation

extension View {
    /// Mounts the share sheet and the failure alert for a dashboard's exports.
    ///
    /// Applied to the dashboard's outermost view, never to a `Group` — a presentation modifier on
    /// a `Group` is applied once per child.
    func seriesExportPresentation(_ box: SeriesExportBox) -> some View {
        modifier(SeriesExportPresentation(box: box))
    }
}

/// The share sheet + alert pair, so no dashboard has to remember both.
private struct SeriesExportPresentation: ViewModifier {
    @Bindable var box: SeriesExportBox

    func body(content: Content) -> some View {
        content
            .sheet(item: $box.shareItem) { AnalyticsExportShareSheet(item: $0) }
            .alert(String(localized: "analytics.export.error.title", defaultValue: "Export Failed"),
                   isPresented: Binding(get: { box.error != nil },
                                        set: { if !$0 { box.error = nil } })) {
                Button(String(localized: "common.ok", defaultValue: "OK")) { box.error = nil }
            } message: {
                Text(box.error ?? "")
            }
    }
}

// MARK: - SeriesChartExportControl

/// The per-card export menu, mounted in ``SeriesChartCard``'s controls slot.
///
/// Per card rather than per dashboard: each of these surfaces shows two or three charts at once,
/// so a single control would be ambiguous about which it acts on — the same reason Person and
/// Cross-Reference Analytics put theirs per section.
struct SeriesChartExportControl: View {
    /// The table to write, or `nil` when the chart has nothing to export.
    let table: ChartInspectorData?
    /// The methods statement.
    let provenance: AnalyticsProvenance
    /// Where the file goes.
    let box: SeriesExportBox
    /// Renders the figure, or `nil` for a card that should not offer one.
    let figure: ((AnalyticsFigureFormat) -> Void)?

    var body: some View {
        HStack {
            Spacer()
            AnalyticsSectionExportControl(
                isEnabled: !(table?.rows.isEmpty ?? true),
                exportCSV: { if let table { box.deliver(table, provenance) } },
                exportFigure: figure)
        }
    }
}
