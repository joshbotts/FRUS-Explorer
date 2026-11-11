// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - ChartDataInspectorView

/// A modal pop-up presenting a chart's underlying data as a table, with a Copy
/// (CSV to pasteboard) action and a Done button.
///
/// Rendering adapts to width: on regular width (macOS + iPad) a SwiftUI `Table`
/// with dynamic columns; on compact width (iPhone) a `List` where each row lists
/// its cells as labelled "column: value" lines — robust for narrow screens.
/// Designed to be presented via `.sheet(item:)`.
///
/// Version history:
///   1.0 — Analytics SA (chart table inspector): initial implementation
///   1.1 — 2026-11-11 (FRUS Explorer Light, S24a): its table, `ChartInspectorData`, with its rows and its
///          Audio Graph, moved into FRUSCoreKit (`ChartInspectorData.swift`); the view stays here
struct ChartDataInspectorView: View {

    /// The table to display.
    let data: ChartInspectorData

    /// Compact-width detection: drives the `List` fallback on iPhone.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Dismisses the pop-up (the Done button's action).
    @Environment(\.dismiss) private var dismiss

    /// `true` on compact-width (iPhone); `false` on macOS / regular-width iPad.
    private var isCompactWidth: Bool { horizontalSizeClass == .compact }

    var body: some View {
        NavigationStack {
            Group {
                if isCompactWidth {
                    compactList
                } else {
                    regularTable
                }
            }
            .navigationTitle(data.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        copyCSV()
                    } label: {
                        Label(
                            String(localized: "series.inspector.copy", defaultValue: "Copy"),
                            systemImage: "doc.on.doc"
                        )
                    }
                    .help(String(localized: "series.inspector.copy.help",
                                 defaultValue: "Copy the table as CSV"))
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "series.inspector.done", defaultValue: "Done")) {
                        dismiss()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 520, idealWidth: 640, minHeight: 380, idealHeight: 520)
        #endif
    }

    // MARK: - Regular-width table

    /// The regular-width (macOS + iPad) rendering: a SwiftUI `Table` with a
    /// dynamic column per header. Numeric-looking columns are right-friendly via
    /// a monospaced-digit font.
    private var regularTable: some View {
        Table(data.rows) {
            TableColumnForEach(Array(data.columns.indices), id: \.self) { columnIndex in
                TableColumn(data.columns[columnIndex]) { row in
                    let cell = columnIndex < row.cells.count ? row.cells[columnIndex] : ""
                    Text(cell)
                        .monospacedDigit()
                }
            }
        }
    }

    // MARK: - Compact-width list

    /// The compact-width (iPhone) fallback: a `List` where each row renders its
    /// cells as labelled "column: value" lines.
    private var compactList: some View {
        List {
            ForEach(data.rows) { row in
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(data.columns.indices), id: \.self) { columnIndex in
                        let value = columnIndex < row.cells.count ? row.cells[columnIndex] : ""
                        HStack(alignment: .firstTextBaseline) {
                            Text(data.columns[columnIndex])
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 8)
                            Text(value)
                                .font(.callout)
                                .monospacedDigit()
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
                .padding(.vertical, 2)
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: - Copy

    /// Copies the table's CSV to the platform pasteboard.
    private func copyCSV() {
        let csv = data.csv
        #if canImport(UIKit)
        UIPasteboard.general.string = csv
        #elseif canImport(AppKit)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(csv, forType: .string)
        #endif
    }
}
