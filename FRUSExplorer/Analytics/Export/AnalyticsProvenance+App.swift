// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - AnalyticsProvenance + the app

/// The methods statement as the app renders it: for its own host.
///
/// `AnalyticsProvenance` moved into FRUSCoreKit (`FRUSCoreKit/Analytics/Export/AnalyticsProvenance.swift`)
/// for FRUS Explorer Light, which stamps the same method block on its exports. What the renderings read
/// from the app is passed in there, and passed here: the bundle's short version string for the credit
/// line, and the reader's locale, calendar and time zone for the export date and the volume count. Every
/// call site keeps the names it used, as `QueryMethodAppendix+App.swift` keeps the appendix's.
///
/// Version history:
///   1.0 — 2026-11-11 (FRUS Explorer Light, S24a): initial implementation, when the methods statement
///          moved into the kit
extension AnalyticsProvenance.Host {

    /// The app's host: its bundle's short version string and the reader's locale, calendar and time
    /// zone, read each time a statement is rendered, as the renderings read them before they moved.
    static var app: AnalyticsProvenance.Host {
        AnalyticsProvenance.Host(
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
    }
}

extension AnalyticsProvenance {

    /// The app's marketing version, or `"—"` when unavailable.
    static var appVersion: String { Host.app.appVersion ?? "—" }

    /// `FRUS Explorer 1.2` — the wordmark + version used on the figure and in the preamble.
    static var appCredit: String { appCredit(for: .app) }

    /// The corpus statement, its volume count grouped for the reader's locale.
    var corpusCaveat: String { corpusCaveat(for: .app) }

    /// The export timestamp, in the reader's locale, calendar and time zone.
    var formattedDate: String { formattedDate(for: .app) }

    /// The two lines baked onto an exported figure, for the app's host.
    var captionLines: [String] { captionLines(for: .app) }

    /// Every caveat the CSV method block states, for the app's host.
    var allCaveats: [String] { allCaveats(for: .app) }

    /// The caveats printed on an exported figure, for the app's host.
    var plateCaveatLines: [String] { plateCaveatLines(for: .app) }

    /// Everything an exported plate prints beneath its chart, for the app's host.
    var plateLines: [AnalyticsPlateLine] { plateLines(for: .app) }

    /// The complete method block as `#`-prefixed CSV comment lines, for the app's host.
    var csvPreambleLines: [String] { csvPreambleLines(for: .app) }
}

extension ChartInspectorData {

    /// The table's CSV preceded by `provenance` as `#` comment lines (D3), for the app's host.
    ///
    /// - Parameter provenance: The methods statement to stamp above the header row.
    /// - Returns: The provenance-stamped CSV text, newline-terminated.
    func provenancedCSV(_ provenance: AnalyticsProvenance) -> String {
        provenancedCSV(provenance, for: .app)
    }
}
