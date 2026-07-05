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

// MARK: - ChartInspectorRow

/// One row of a chart's underlying data table.
///
/// `cells` holds the already-formatted, already-localised string value for each
/// column, in the same order as the owning `ChartInspectorData.columns`, so
/// `cells.count == columns.count`. Formatting (years without commas, shares as
/// percents, plain counts) is the adapter's responsibility — the row is a pure
/// presentation value.
///
/// Version history:
///   1.0 — Analytics SA (chart table inspector): initial implementation
struct ChartInspectorRow: Identifiable, Sendable, Hashable {
    /// The row's stable position (also its `Identifiable` id), 0-based in the
    /// order the adapter produced.
    let id: Int
    /// The formatted cell strings, one per column in `columns` order.
    let cells: [String]
}

// MARK: - ChartInspectorData

/// The full underlying-data table for a single Series-dashboard chart, ready to
/// be shown in a pop-up via `ChartDataInspectorView`.
///
/// Adapters build this from the *same* arrays their chart plots — for the
/// range-filtered time-series charts that means the in-domain arrays, so the
/// table matches the visible chart and updates with the year range. Column
/// headers arrive already-localised; cell values arrive already-formatted.
///
/// Version history:
///   1.0 — Analytics SA (chart table inspector): initial implementation
struct ChartInspectorData: Identifiable, Sendable, Hashable {
    /// A stable per-chart key (e.g. `"sa1.lag"`), also the `Identifiable` id used
    /// to drive the presenting `.sheet(item:)`.
    let id: String
    /// The chart's localised title, shown at the top of the pop-up.
    let title: String
    /// The localised column headers, in table order.
    let columns: [String]
    /// The data rows; each row's `cells.count` equals `columns.count`.
    let rows: [ChartInspectorRow]

    /// Builds an inspector table, wrapping each raw cell array into a
    /// positionally-identified `ChartInspectorRow`.
    ///
    /// - Parameters:
    ///   - id: The stable per-chart key.
    ///   - title: The localised chart title.
    ///   - columns: The localised column headers.
    ///   - rowCells: Each row's formatted cell strings (each the same length as
    ///     `columns`).
    init(id: String, title: String, columns: [String], rowCells: [[String]]) {
        self.id = id
        self.title = title
        self.columns = columns
        self.rows = rowCells.enumerated().map { ChartInspectorRow(id: $0.offset, cells: $0.element) }
    }

    /// A CSV serialisation of the table (header row + data rows), RFC-4180-style:
    /// a cell containing a comma, a double quote, or a newline is wrapped in
    /// double quotes with any embedded quotes doubled. Rows are joined with `\n`.
    var csv: String {
        var lines: [String] = []
        lines.append(columns.map(Self.escapeCSV).joined(separator: ","))
        for row in rows {
            lines.append(row.cells.map(Self.escapeCSV).joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    /// Escapes one CSV field, quoting it when it contains a comma, quote, or
    /// newline and doubling any embedded quotes.
    ///
    /// - Parameter field: The raw cell text.
    /// - Returns: The CSV-safe field.
    static func escapeCSV(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else {
            return field
        }
        let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}

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
