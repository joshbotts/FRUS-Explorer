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

// MARK: - AnalyticsOccurrenceMeasureTests

/// The D2 surface rules: what the unit resolves to, how a decade is summed, and the one combination
/// that must be unreachable.
///
/// These are pure restatements of logic that lives in `AnalyticsView`'s private members, asserted
/// here against the same arithmetic. That is a deliberate compromise: the view's own copies cannot be
/// reached from a test, and the alternative — trusting three interacting gates because the app
/// compiles — is how the mislabels this workstream removed got in.
@Suite("Analytics occurrence measure")
struct AnalyticsOccurrenceMeasureTests {

    /// The effective-unit rule from `AnalyticsView.valueUnit`.
    private func effectiveUnit(preference: AnalyticsValueUnit,
                               measureApplies: Bool,
                               availability: OccurrenceAvailability) -> AnalyticsValueUnit {
        guard preference == .occurrences, measureApplies, availability.isAvailable else { return .documents }
        return .occurrences
    }

    @Test("Occurrences apply only where the axis and the query can both serve them")
    func effectiveUnitFallsBackToDocuments() {
        let ok = OccurrenceAvailability.available(stem: "treaty")
        let no = OccurrenceAvailability.unavailable(reason: .exactWord)

        #expect(effectiveUnit(preference: .occurrences, measureApplies: true, availability: ok) == .occurrences)
        // Wrong axis: By Month has no occurrence series, so the preference must not apply.
        #expect(effectiveUnit(preference: .occurrences, measureApplies: false, availability: ok) == .documents)
        // Wrong query shape: the preference is honoured only where an honest count exists.
        #expect(effectiveUnit(preference: .occurrences, measureApplies: true, availability: no) == .documents)
        // And documents never become occurrences by accident.
        #expect(effectiveUnit(preference: .documents, measureApplies: true, availability: ok) == .documents)
    }

    /// The decade rule from `AnalyticsView.decadeSeries(for:)`.
    private func decades(from years: [(Int, Int)]) -> [DecadeFrequency] {
        var byDecade: [Int: Int] = [:]
        for (year, count) in years { byDecade[(year / 10) * 10, default: 0] += count }
        return byDecade.map { DecadeFrequency(decadeStart: $0.key, count: $0.value) }
            .sorted { $0.decadeStart < $1.decadeStart }
    }

    @Test("A decade's occurrences are the sum of its years, and nothing is lost at a boundary")
    func decadeBucketingSumsYears() {
        // 1949 and 1950 are the boundary that a `/ 10 * 10` error puts in the same bucket.
        let result = decades(from: [(1948, 3), (1949, 92), (1950, 7), (1951, 1)])
        #expect(result.map(\.decadeStart) == [1940, 1950])
        #expect(result.first { $0.decadeStart == 1940 }?.count == 95, "1948 + 1949")
        #expect(result.first { $0.decadeStart == 1950 }?.count == 8, "1950 + 1951")
        // The total must survive bucketing — a decade series that loses occurrences would understate
        // exactly where the year series is most crowded.
        #expect(result.reduce(0) { $0 + $1.count } == 103)
    }

    @Test("An empty year series yields an empty decade series, not a zero bucket")
    func emptyYearsYieldEmptyDecades() {
        #expect(decades(from: []).isEmpty)
    }

    /// The `isNormalized` rule from `AnalyticsView`, including the PR-D unit term.
    private func isNormalized(unit: AnalyticsValueUnit,
                              normalizationApplies: Bool,
                              isChart: Bool,
                              mode: AnalyticsNormalizationMode) -> Bool {
        normalizationApplies && isChart && unit == .documents && mode == .percentOfDocuments
    }

    @Test("Occurrences and '% of documents' is an unreachable combination")
    func occurrencesAreNeverNormalised() {
        // Occurrences ÷ indexed documents is a RATE, unbounded above 100%, and every consumer of
        // `normalizedValue` calls its result a share. So the combination is made impossible rather
        // than clamped — clamping would turn a wrong label into an invisible one.
        #expect(!isNormalized(unit: .occurrences, normalizationApplies: true,
                              isChart: true, mode: .percentOfDocuments),
                "An occurrence chart must never plot a percentage of documents")
        // The documents case still normalises, so the guard is specific rather than a blanket off.
        #expect(isNormalized(unit: .documents, normalizationApplies: true,
                             isChart: true, mode: .percentOfDocuments))
    }

    @Test("The occurrences unit labels every surface, distinctly from documents")
    func occurrenceLabelsAreDistinct() {
        let occ = AnalyticsValueUnit.occurrences
        let doc = AnalyticsValueUnit.documents
        #expect(occ.axisLabel != doc.axisLabel)
        #expect(occ.exportColumnHeader != doc.exportColumnHeader)
        #expect(occ.matchedPhrase(count: 92) != doc.matchedPhrase(count: 92))
        #expect(occ.accessibilityPhrase(count: 92) != doc.accessibilityPhrase(count: 92))
        #expect(occ.pickerLabel != doc.pickerLabel)
        // The stem caveat has to be in the axis label itself: it is the only place a reader of an
        // exported figure can learn that "containment" counted "container" too.
        #expect(occ.axisLabel.lowercased().contains("stem"))
        // And the export header must not collide with the word cloud's own "Occurrences" column,
        // which counts NLTagger lemmas over body_text only.
        #expect(occ.exportColumnHeader != "Occurrences")
    }
}

// MARK: - SavedAnalyticsQueryUnitTests

/// The counting unit travels with a saved query, because it changes what the query asks.
@Suite("Saved analytics query unit")
struct SavedAnalyticsQueryUnitTests {

    private func query(unit: AnalyticsValueUnit?) -> SavedAnalyticsQuery {
        SavedAnalyticsQuery(id: UUID(), terms: ["treaty"], axis: .byYear,
                            yearStart: 1945, yearEnd: 1949,
                            scopeVolumeIds: nil, scopeLabel: nil,
                            savedAt: Date(timeIntervalSince1970: 0), valueUnit: unit)
    }

    @Test("Two queries differing only in unit are not the same query")
    func unitParticipatesInEquality() {
        #expect(!query(unit: .documents).matchesQuery(query(unit: .occurrences)),
                "Restoring under the other unit would re-export a numerically different figure under an identical title")
        #expect(query(unit: .occurrences).matchesQuery(query(unit: .occurrences)))
    }

    @Test("A query saved before the unit existed reads as documents, not as a mismatch")
    func legacyQueriesDefaultToDocuments() {
        #expect(query(unit: nil).matchesQuery(query(unit: .documents)),
                "A pre-PR-D saved query must still match its own restored state, or its star reads unsaved forever")
        #expect(!query(unit: nil).matchesQuery(query(unit: .occurrences)))
    }

    @Test("The unit survives a JSON round trip, including the legacy nil")
    func roundTripsThroughJSON() throws {
        for unit in [AnalyticsValueUnit.documents, .occurrences] {
            let data = try JSONEncoder().encode(query(unit: unit))
            let decoded = try JSONDecoder().decode(SavedAnalyticsQuery.self, from: data)
            #expect(decoded.valueUnit == unit)
        }
        // The stored list predates this field; decoding must not fail on its absence.
        let legacy = #"{"id":"00000000-0000-0000-0000-000000000000","terms":["treaty"],"axis":"byYear","yearStart":1945,"yearEnd":1949,"savedAt":0}"#
        let decoded = try JSONDecoder().decode(SavedAnalyticsQuery.self, from: Data(legacy.utf8))
        #expect(decoded.valueUnit == nil, "Absent means absent; the default is applied at the read sites")
        #expect(decoded.terms == ["treaty"])
    }
}

// MARK: - HandOffCountUnitTests

/// The "View N documents ↗" count must stay a DOCUMENT count in every measure.
///
/// Found by running the app, not by a test: in Occurrences mode the button read "View 57,433
/// documents" for a term with 39,405 matching documents, because it summed whichever series the
/// chart was plotting. The hand-off lands in Search, and Search returns documents — so this was the
/// one number a researcher could check against another surface, and the one that disagreed.
@Suite("Hand-off count unit")
struct HandOffCountUnitTests {

    /// The corrected rule: the hand-off always sums the DOCUMENT series.
    private func handOffCount(documents: [(Int, Int)], occurrences: [(Int, Int)],
                              unit: AnalyticsValueUnit, range: ClosedRange<Int>) -> Int {
        // Deliberately ignores `unit` — that is the fix. The parameter is present so a future edit
        // that reintroduces the dependency has somewhere obvious to go wrong, and this test catches it.
        _ = unit
        return documents.filter { range.contains($0.0) }.reduce(0) { $0 + $1.1 }
    }

    @Test("The hand-off count is identical in both measures")
    func handOffCountIsUnitIndependent() {
        let documents = [(1948, 34), (1949, 11), (1950, 20)]
        let occurrences = [(1948, 77), (1949, 92), (1950, 40)]
        let range = 1861...1992

        let inDocuments = handOffCount(documents: documents, occurrences: occurrences,
                                       unit: .documents, range: range)
        let inOccurrences = handOffCount(documents: documents, occurrences: occurrences,
                                         unit: .occurrences, range: range)
        #expect(inDocuments == 65)
        #expect(inDocuments == inOccurrences,
                "Switching measure must not change the number of documents the hand-off promises")
        // And it must not accidentally equal the occurrence total, which is what the bug produced.
        #expect(inOccurrences != occurrences.reduce(0) { $0 + $1.1 })
    }

    @Test("The year range still applies to the hand-off count")
    func handOffCountRespectsTheRange() {
        let documents = [(1948, 34), (1949, 11), (1975, 500)]
        let inRange = handOffCount(documents: documents, occurrences: [],
                                   unit: .occurrences, range: 1945...1950)
        #expect(inRange == 45, "1975 is outside the range and must not be promised to Search")
    }
}
