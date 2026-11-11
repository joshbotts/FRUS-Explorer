// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif

// MARK: - What the app gives a methods statement, for the package

// In Xcode the suites run inside the app, whose `AnalyticsProvenance+App.swift` renders a methods statement
// for the app's host under the names the suites call: `captionLines`, `csvPreambleLines`, `plateLines`,
// `provenancedCSV(_:)` and the rest. The package has no app, so it declares the same names here over the
// kit's renderings, for a host that reads its version from the bundle and writes in the reader's locale,
// calendar and time zone, as the app's does. The suites then render with the same calls in both builds.
//
// Version history:
//   1.0 — 2026-11-11 (FRUS Explorer Light, S24a): initial implementation, when the methods statement
//          moved into the kit

#if SWIFT_PACKAGE
extension AnalyticsProvenance.Host {

    /// The app's host, as `AnalyticsProvenance+App.swift` makes it.
    static var app: AnalyticsProvenance.Host {
        AnalyticsProvenance.Host(
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
    }
}

extension AnalyticsProvenance {
    static var appVersion: String { Host.app.appVersion ?? "—" }
    static var appCredit: String { appCredit(for: .app) }
    var corpusCaveat: String { corpusCaveat(for: .app) }
    var formattedDate: String { formattedDate(for: .app) }
    var captionLines: [String] { captionLines(for: .app) }
    var allCaveats: [String] { allCaveats(for: .app) }
    var plateCaveatLines: [String] { plateCaveatLines(for: .app) }
    var plateLines: [AnalyticsPlateLine] { plateLines(for: .app) }
    var csvPreambleLines: [String] { csvPreambleLines(for: .app) }
}

extension ChartInspectorData {
    func provenancedCSV(_ provenance: AnalyticsProvenance) -> String {
        provenancedCSV(provenance, for: .app)
    }
}
#endif
