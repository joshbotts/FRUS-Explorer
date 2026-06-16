// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CaseCoverageGap

/// A gap in case-number coverage between two consecutive rolls — a span of case numbers
/// no harvested roll claims. Surfaced by the survey so missing rolls are caught early.
public struct CaseCoverageGap: Sendable, Equatable {
    /// First uncovered case number (inclusive).
    public let from: Int
    /// Last uncovered case number (inclusive).
    public let to: Int
    public init(from: Int, to: Int) { self.from = from; self.to = to }
}

// MARK: - CaseRangeOverlap

/// Two rolls whose case ranges overlap. Expected to be empty; a non-empty list means a
/// title was misparsed or NARA's ranges genuinely overlap (handle in lookup if so).
public struct CaseRangeOverlap: Sendable, Equatable {
    public let lower: NumericalFileRoll
    public let higher: NumericalFileRoll
    public init(lower: NumericalFileRoll, higher: NumericalFileRoll) {
        self.lower = lower
        self.higher = higher
    }
}

// MARK: - NumericalFileHarvestResult

/// The built index plus survey diagnostics from the harvest pass.
///
/// The diagnostics let the (network-bound) harvest run validate itself without a human
/// inspecting raw JSON: how many records parsed as rolls, which titles did not, and
/// whether the case ranges tile the corpus contiguously.
public struct NumericalFileHarvestResult: Sendable, Equatable {
    /// The assembled, sorted index.
    public let index: NumericalFileIndex
    /// Total descendant records returned by the catalog.
    public let totalRecords: Int
    /// Titles that did not parse as a Numerical File case range (series/file-unit
    /// descriptions, finding aids, or unexpected formats). Capped for logging.
    public let unmatchedTitles: [String]
    /// Spans of case numbers no roll covers (possible missing rolls).
    public let coverageGaps: [CaseCoverageGap]
    /// Overlapping case ranges (expected empty).
    public let overlaps: [CaseRangeOverlap]

    /// Number of records that parsed into rolls.
    public var matchedRolls: Int { index.rolls.count }
}

// MARK: - NumericalFileIndexBuilder

/// Builds a `NumericalFileIndex` from harvested catalog records.
///
/// Pure (no I/O): all logic is testable without the network. The runner pairs it with
/// `NARACatalogHarvestClient` for the live harvest.
///
/// Version history:
///   1.0 — Session 2026-06-15: initial implementation
public enum NumericalFileIndexBuilder {

    /// Builds the index and survey diagnostics from raw catalog records.
    ///
    /// - Parameters:
    ///   - records: Descendant records of the Numerical File series.
    ///   - seriesNaId: The series NAID (`654171`).
    ///   - microfilm: Microfilm publication (`M862`).
    ///   - maxUnmatchedSamples: How many unmatched titles to retain for logging.
    public static func build(
        records: [CatalogRecord],
        seriesNaId: String,
        microfilm: String,
        maxUnmatchedSamples: Int = 25
    ) -> NumericalFileHarvestResult {
        var rolls: [NumericalFileRoll] = []
        var unmatched: [String] = []

        for record in records {
            if let range = RollTitleParser.numericalFileCaseRange(from: record.title) {
                rolls.append(NumericalFileRoll(
                    naId: record.naId,
                    title: record.title,
                    caseStart: range.start,
                    caseEnd: range.end,
                    catalogURL: NARACatalogHarvestClient.catalogIDBase + record.naId
                ))
            } else {
                unmatched.append(record.title)
            }
        }

        let index = NumericalFileIndex(seriesNaId: seriesNaId, microfilm: microfilm, rolls: rolls)
        let (gaps, overlaps) = coverageAnalysis(rolls: index.rolls)

        return NumericalFileHarvestResult(
            index: index,
            totalRecords: records.count,
            unmatchedTitles: Array(unmatched.prefix(maxUnmatchedSamples)),
            coverageGaps: gaps,
            overlaps: overlaps
        )
    }

    /// Detects gaps and overlaps across case ranges. `rolls` must be sorted by `caseStart`.
    static func coverageAnalysis(
        rolls: [NumericalFileRoll]
    ) -> (gaps: [CaseCoverageGap], overlaps: [CaseRangeOverlap]) {
        var gaps: [CaseCoverageGap] = []
        var overlaps: [CaseRangeOverlap] = []
        guard rolls.count > 1 else { return (gaps, overlaps) }

        for i in 1..<rolls.count {
            let prev = rolls[i - 1]
            let curr = rolls[i]
            if curr.caseStart > prev.caseEnd + 1 {
                gaps.append(CaseCoverageGap(from: prev.caseEnd + 1, to: curr.caseStart - 1))
            } else if curr.caseStart <= prev.caseEnd {
                overlaps.append(CaseRangeOverlap(lower: prev, higher: curr))
            }
        }
        return (gaps, overlaps)
    }
}
