// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - AXChartPoint

/// One plotted point, as VoiceOver's Audio Graph needs it (#268).
///
/// Numeric on purpose. `ChartInspectorData` — the table behind every "show the data" pop-up — holds
/// **already-formatted, already-localised** strings, and reading an axis range back out of them
/// means parsing "1,204" and "38%" in whatever locale rendered them. That silently yields a wrong
/// range rather than an error, which on an audio graph is inaudible: the tones simply describe the
/// wrong shape. So the builder takes numbers, and the bridge below refuses rather than guesses.
///
/// Version history:
///   1.0 — Session 2026-08-10: #268 (I-1)
///   1.1 — 2026-11-11 (FRUS Explorer Light, S24a): out of `AXChartDescriptorBuilder.swift`, a file that
///          imports SwiftUI and Accessibility, into FRUSCoreKit, public
public struct AXChartPoint: Sendable, Hashable {
    /// The x label as the chart shows it (a year, a decade, a category).
    public let label: String
    /// The x value when the axis is numeric; `nil` for a categorical axis.
    public let x: Double?
    /// The plotted value.
    public let y: Double
}

// MARK: - AXChartDescriptorBuilder

/// The Audio Graph descriptor builder's Foundation half: a formatted cell read back to a number
/// (``numeric(_:)``), which `AnalyticsChartTables` gives a point for its x. The descriptors need
/// Accessibility, and they stay the app's with the two readers of a table's cells, in an extension of
/// this type (`AXChartDescriptorBuilder.swift`).
///
/// Version history:
///   1.0 — 2026-11-11 (FRUS Explorer Light, S24a): the type is declared here, with `numeric(_:)` moved out
///          of the app's builder unchanged
enum AXChartDescriptorBuilder {

    /// Reads a formatted cell back to a number, or `nil`.
    ///
    /// Handles the three shapes the adapters emit — a plain count, a grouped count (`1,204`), and
    /// a percentage (`38%`, read as 38). Anything else is a refusal, not a zero: a zero would put
    /// a point on the graph that the chart does not plot.
    ///
    /// **It reads the comma as a thousands separator, so it must never be given a decimal written
    /// for the reader's region** (#1616): `12,4`, which is 12.4 where decimals take a comma, reads
    /// as 124. A table with such a cell states its numbers (`ChartInspectorData.audioGraph`), as
    /// the Corpus Analytics series and the mention trajectories do, and is not read by column.
    static func numeric(_ cell: String) -> Double? {
        let trimmed = cell.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let stripped = trimmed
            .replacingOccurrences(of: "%", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard !stripped.isEmpty else { return nil }
        // Reject anything with a letter — "n/a", "—", a volume id — rather than letting a lenient
        // parser pull a leading digit out of it.
        guard !stripped.contains(where: { $0.isLetter }) else { return nil }
        return Double(stripped)
    }
}
