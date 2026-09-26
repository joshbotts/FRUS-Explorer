// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - PersonAnalyticsCopy

/// Person Analytics sentences a test reads, kept off the view (#1382).
///
/// A `View`'s statics are main-actor-isolated, so a caption built inside `PersonAnalyticsView`
/// could only be checked by reading the source. Here it is an ordinary function a test calls,
/// the way `PersonLifespan.text` was moved for the Career footer's "1,893–1,971".
///
/// Version history:
///   1.0 — 2026-09-25: #1382 — the Most-Mentioned caption, whose years printed grouped
///   1.1 — 2026-09-25: #1380 — the caption says "Select a person", which reads on the Mac too
enum PersonAnalyticsCopy {

    /// "Top people by mentions in dated documents, 1940–1992. …" — the caption under
    /// **Most-Mentioned People**.
    ///
    /// Each year is wrapped in `String(_:)`. `String(localized:)` formats an interpolated `Int` for
    /// the locale, which groups it, so the bare bounds read "1,940–1,992" beside a year chip and
    /// two axes that printed 1940 (#1382). `CodingStandardsAuditTests`' year scan refuses the bare
    /// form in any `defaultValue:`.
    ///
    /// - Parameter years: The ranking's year range.
    /// - Returns: The caption.
    static func rankingSubtitle(_ years: ClosedRange<Int>) -> String {
        String(localized: "personAnalytics.ranking.subtitle",
               defaultValue: "Top people by mentions in dated documents, \(String(years.lowerBound))–\(String(years.upperBound)). Select a person to compare them below.")
    }
}
