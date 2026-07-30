// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing

@testable import FRUSExplorer

// MARK: - AnalyticsValueUnitTests

/// The consolidated unit label, and the source audit that keeps it consolidated.
///
/// PR-B moved the word "Documents" out of thirteen call sites in `AnalyticsView` into one type. That
/// is only worth doing if it stays that way, and nothing about a hardcoded string fails a build. The
/// audit at the bottom of this file is the part that makes the refactor durable; the rest pins the
/// "no behaviour change" claim it shipped under.
@Suite("Analytics value unit")
struct AnalyticsValueUnitTests {

    // MARK: The no-behaviour-change claim

    @Test("The documents unit resolves to the exact strings the call sites hardcoded")
    func documentsUnitMatchesThePreviousLiterals() {
        // These are the literals as they stood in AnalyticsView before the consolidation. If any of
        // them changed, the PR that claimed "no behaviour change" was wrong.
        #expect(AnalyticsValueUnit.documents.axisLabel == "Documents")
        #expect(AnalyticsValueUnit.documents.exportColumnHeader == "Matching documents")
        #expect(AnalyticsValueUnit.documents.matchedPhrase(count: 182) == "182 documents matched")
        #expect(AnalyticsValueUnit.documents.accessibilityPhrase(count: 182) == "182 documents")
    }

    @Test("A non-normalised axis reads as the unit; a normalised one reads as a share")
    func axisLabelSwitchesOnNormalisationOnly() {
        #expect(AnalyticsValueUnit.axisLabel(unit: .documents, isNormalized: false) == "Documents")
        #expect(AnalyticsValueUnit.axisLabel(unit: .documents, isNormalized: true) == "% of documents")
    }

    @Test("The normalised label does not vary by unit, because the denominator never does")
    func normalisedLabelIsUnitIndependent() {
        // DORMANT TODAY, DELIBERATELY. With `documents` the only case this cannot fail, and a
        // mutation making the normalised label unit-dependent survives it — I checked, rather than
        // assuming the test was doing work.
        //
        // What I then verified is that it is dormant and not broken: adding a second case together
        // with that mutation fails it, naming `["% of documents", "Occurrences"]`. So it activates
        // exactly when PR-D adds `occurrences`, which is the moment the invariant can first be
        // violated. Its value is being here before the case, not after.
        //
        // The invariant: a share's denominator is indexed documents whatever the numerator counts,
        // so "% of occurrences" would name a quantity the app never computes.
        let normalised = Set(AnalyticsValueUnit.allCases.map {
            AnalyticsValueUnit.axisLabel(unit: $0, isNormalized: true)
        })
        #expect(normalised == ["% of documents"],
                "Every unit must produce the same normalised label: \(normalised.sorted())")
    }

    @Test("Every unit supplies every label, with no empty strings")
    func everyUnitIsFullyLabelled() {
        for unit in AnalyticsValueUnit.allCases {
            #expect(!unit.axisLabel.isEmpty, "\(unit) has no axis label")
            #expect(!unit.exportColumnHeader.isEmpty, "\(unit) has no export column header")
            #expect(!unit.matchedPhrase(count: 1).isEmpty, "\(unit) has no matched phrase")
            #expect(!unit.accessibilityPhrase(count: 1).isEmpty, "\(unit) has no a11y phrase")
            // The count has to reach the string. A phrase that drops it reads as a label, and on the
            // totals footnote that would silently remove the number the footnote exists to show.
            #expect(unit.matchedPhrase(count: 4242).contains("4242")
                        || unit.matchedPhrase(count: 4242).contains("4,242"),
                    "\(unit) matchedPhrase drops the count")
            #expect(unit.accessibilityPhrase(count: 4242).contains("4242")
                        || unit.accessibilityPhrase(count: 4242).contains("4,242"),
                    "\(unit) accessibilityPhrase drops the count")
        }
    }

    // MARK: The audit that keeps it consolidated

    /// `FRUSExplorer/Analytics/` from this test file's location.
    private static let analyticsDirectory: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("FRUSExplorer/Analytics")

    @Test("The unit noun is written out in exactly one file")
    func unitNounIsNotHardcodedElsewhere() throws {
        // Both the localization key and the English default are checked: someone could reintroduce
        // either half alone, and either half alone is a site that will not track a new unit.
        let needles = ["analytics.axis.documents", "%lld documents matched",
                       "analytics.export.column.matching"]
        let fileManager = FileManager.default
        let paths = try fileManager
            .subpathsOfDirectory(atPath: Self.analyticsDirectory.path)
            .filter { $0.hasSuffix(".swift") }

        // Anti-vacuity: if the scan path breaks, every needle is trivially absent and this passes
        // while auditing nothing.
        #expect(paths.count > 10, "Only \(paths.count) Swift files under Analytics/; the scan path is wrong")
        #expect(paths.contains { $0.hasSuffix("AnalyticsValueUnit.swift") },
                "The file that is supposed to own these strings is not in the scan")

        var offenders: [String] = []
        for path in paths {
            let url = Self.analyticsDirectory.appendingPathComponent(path)
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let owns = path.hasSuffix("AnalyticsValueUnit.swift")
            for needle in needles where text.contains(needle) {
                // Comments in other files may DISCUSS the strings; only code should carry them.
                let inCodeOnly = text
                    .components(separatedBy: "\n")
                    .filter { $0.contains(needle) }
                    .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
                              && !$0.trimmingCharacters(in: .whitespaces).hasPrefix("///") }
                guard !inCodeOnly.isEmpty, !owns else { continue }
                offenders.append("\(path): \(needle)")
            }
        }

        #expect(offenders.isEmpty, """
            The Corpus Analytics unit noun is hardcoded outside AnalyticsValueUnit:

            \(offenders.joined(separator: "\n"))

            Route it through `AnalyticsValueUnit` (via `valueAxisLabel`, `matchedPhrase`,
            `accessibilityPhrase` or `exportColumnHeader`). It was spread across thirteen sites
            before PR-B, which is thirteen chances to leave one reading "Documents" over a column of
            something else — with no compile error and no test failure.
            """)
    }

    @Test("AnalyticsValueUnit owns each string exactly once")
    func ownerFileHasNoDuplicates() throws {
        let url = Self.analyticsDirectory.appendingPathComponent("AnalyticsValueUnit.swift")
        let text = try String(contentsOf: url, encoding: .utf8)
        for needle in ["analytics.axis.documents", "analytics.export.column.matching"] {
            let occurrences = text.components(separatedBy: needle).count - 1
            #expect(occurrences == 1,
                    "\(needle) appears \(occurrences)× in AnalyticsValueUnit.swift — one place means one place")
        }
    }
}
