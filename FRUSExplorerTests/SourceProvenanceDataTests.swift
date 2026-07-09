// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

// MARK: - SourceProvenanceDataTests

/// Pure derivation tests for the "Archival Sourcing Over Time" dashboard (Series
/// Analytics SA-3b): the `SourceProvenanceIndex` decode contract, the
/// `SourceProvenanceData` derivations from a constructed fixture (pre-1900 floor,
/// per-decade shares, overall composition, missing-key = 0, unknown-category
/// tolerance, empty safety), and one integration guard that the *actual* bundled
/// `source-provenance-index.json` decodes with the expected headline figures.
///
/// These assert the model only — no SwiftUI view is instantiated.
///
/// Version history:
///   1.0 — Analytics SA-3b: initial implementation
struct SourceProvenanceDataTests {

    // MARK: Fixtures

    /// A small constructed index spanning one pre-1900 floor decade and three
    /// shown decades, exercising a missing category key and an unknown category.
    private func fixture() -> SourceProvenanceIndex {
        SourceProvenanceIndex(
            schemaVersion: 1,
            generated: "2026-07-04",
            totalSourceNotes: 100 + 200 + 80 + 40,
            volumesCovered: 12,
            categories: SourceProvenanceCategory.ordered.map(\.rawValue),
            byDecade: [
                // Pre-1900 floor: excluded from every derivation.
                DecadeProvenance(decade: 1860, totalNotes: 100, volumeCount: 3,
                                 counts: ["unrecognized": 100]),
                // 1910: 100% central decimal file (single category).
                DecadeProvenance(decade: 1910, totalNotes: 200, volumeCount: 4,
                                 counts: ["centralDecimalFile": 200]),
                // 1950: split; note "lotFile" present but "naraCollection" OMITTED
                // (must read as 0). Includes an UNKNOWN future category key.
                DecadeProvenance(decade: 1950, totalNotes: 80, volumeCount: 3,
                                 counts: [
                                    "centralDecimalFile": 40,
                                    "lotFile": 20,
                                    "presidentialLibrary": 20,
                                    "quantumArchive": 999,  // unknown → ignored
                                 ]),
                // 1970: presidential-library dominant.
                DecadeProvenance(decade: 1970, totalNotes: 40, volumeCount: 2,
                                 counts: [
                                    "presidentialLibrary": 30,
                                    "centralForeignPolicyFile": 10,
                                 ]),
            ]
        )
    }

    // MARK: Category enum

    @Test("SourceProvenanceCategory: ten ordered categories with the expected raw values")
    func categoryOrder() {
        #expect(SourceProvenanceCategory.ordered.count == 10)
        #expect(SourceProvenanceCategory.ordered.map(\.rawValue) == [
            "centralDecimalFile", "centralForeignPolicyFile", "lotFile",
            "presidentialLibrary", "naraCollection", "intelligence",
            "namedFileSeries", "foreignArchive", "previouslyPublished",
            "unrecognized",
        ])
        #expect(SourceProvenanceCategory.allCases.count == 10)
    }

    @Test("SourceProvenanceCategory: an unknown raw value is nil, not a crash")
    func unknownRawValueTolerated() {
        #expect(SourceProvenanceCategory(rawValue: "quantumArchive") == nil)
        #expect(SourceProvenanceCategory(rawValue: "centralDecimalFile") == .centralDecimalFile)
    }

    // MARK: DecadeProvenance.count(for:)

    @Test("DecadeProvenance: a missing category key reads as zero")
    func missingKeyIsZero() {
        let decade = fixture().byDecade.first { $0.decade == 1950 }!
        // naraCollection omitted from the 1950 counts.
        #expect(decade.count(for: .naraCollection) == 0)
        #expect(decade.count(for: .lotFile) == 20)
        #expect(decade.count(for: .centralDecimalFile) == 40)
    }

    // MARK: Pre-1900 floor + shares

    @Test("SourceProvenanceData: shareByDecade excludes decades below 1900")
    func floorExcludesPre1900() {
        let data = SourceProvenanceData(index: fixture())
        let decades = Set(data.shareByDecade.map(\.decade))
        #expect(!decades.contains(1860))
        #expect(decades == [1910, 1950, 1970])
        #expect(data.decadeRangeShown == 1910...1970)
        // The floored-out 1860 bucket's notes are disclosed.
        #expect(data.prewarExcludedNoteCount == 100)
    }

    @Test("SourceProvenanceData: shares sum to ~1.0 within each shown decade")
    func sharesSumToOne() {
        let data = SourceProvenanceData(index: fixture())
        for decade in [1910, 1950, 1970] {
            let sum = data.shareByDecade
                .filter { $0.decade == decade }
                .reduce(0.0) { $0 + $1.share }
            #expect(abs(sum - 1.0) < 1e-9, "decade \(decade) shares summed to \(sum)")
        }
    }

    @Test("SourceProvenanceData: an omitted-then-present category yields the right share")
    func perCategoryShare() {
        let data = SourceProvenanceData(index: fixture())
        // 1950: centralDecimalFile 40/80 = 0.5 (naraCollection absent → no row).
        let cdf = data.shareByDecade.first { $0.decade == 1950 && $0.category == .centralDecimalFile }
        #expect(cdf != nil)
        #expect(abs((cdf?.share ?? 0) - 0.5) < 1e-9)
        // naraCollection has no row in 1950 (share would be 0).
        let nara = data.shareByDecade.first { $0.decade == 1950 && $0.category == .naraCollection }
        #expect(nara == nil)
    }

    @Test("SourceProvenanceData: an unknown category key is ignored, not counted")
    func unknownCategoryIgnored() {
        let data = SourceProvenanceData(index: fixture())
        // The "quantumArchive" 999-count in 1950 must NOT inflate the decade's
        // shares: only the four known categories contribute, and they sum to 1.0
        // on the real total (80), so the unknown key is fully excluded.
        let sum1950 = data.shareByDecade
            .filter { $0.decade == 1950 }
            .reduce(0.0) { $0 + $1.share }
        // Known counts: 40+20+20 = 80 = totalNotes → shares sum to 1.0.
        #expect(abs(sum1950 - 1.0) < 1e-9)
        // No composition entry exceeds its known contribution.
        let comp = data.overallComposition
        let totalCounted = comp.reduce(0) { $0 + $1.noteCount }
        // 1910: 200, 1950: 80 (known only), 1970: 40 = 320 (excludes the 999 unknown + 100 floor).
        #expect(totalCounted == 320)
    }

    // MARK: Overall composition

    @Test("SourceProvenanceData: overallComposition sums counts across shown decades")
    func compositionSums() {
        let data = SourceProvenanceData(index: fixture())
        func count(_ c: SourceProvenanceCategory) -> Int {
            data.overallComposition.first { $0.category == c }?.noteCount ?? -1
        }
        #expect(count(.centralDecimalFile) == 200 + 40)      // 1910 + 1950
        #expect(count(.lotFile) == 20)                       // 1950
        #expect(count(.presidentialLibrary) == 20 + 30)      // 1950 + 1970
        #expect(count(.centralForeignPolicyFile) == 10)      // 1970
        #expect(count(.naraCollection) == 0)                 // never present
        // Composition covers all ten categories (stable legend), zeros included.
        #expect(data.overallComposition.count == 10)
        // Shares over the shown total (320).
        #expect(data.shownNoteCount == 320)
        let cdfShare = data.overallComposition.first { $0.category == .centralDecimalFile }?.share ?? 0
        #expect(abs(cdfShare - 240.0 / 320.0) < 1e-9)
    }

    @Test("SourceProvenanceData: notesByDecade carries shown decades only")
    func notesByDecade() {
        let data = SourceProvenanceData(index: fixture())
        #expect(data.notesByDecade.map(\.decade) == [1910, 1950, 1970])
        let d1910 = data.notesByDecade.first { $0.decade == 1910 }
        #expect(d1910?.totalNotes == 200)
        #expect(d1910?.volumeCount == 4)
    }

    // MARK: Stats + empty safety

    @Test("SourceProvenanceData: headline stats echo the index")
    func headlineStats() {
        let data = SourceProvenanceData(index: fixture())
        #expect(data.totalSourceNotes == 420)
        #expect(data.volumesCovered == 12)
    }

    @Test("SourceProvenanceData: a nil index yields empty collections, no crash")
    func nilIndexIsSafe() {
        let data = SourceProvenanceData(index: nil)
        #expect(data.shareByDecade.isEmpty)
        #expect(data.overallComposition.isEmpty)
        #expect(data.notesByDecade.isEmpty)
        #expect(data.totalSourceNotes == 0)
        #expect(data.volumesCovered == 0)
        #expect(data.decadeRangeShown == nil)
        #expect(data.prewarExcludedNoteCount == 0)
        #expect(data.shownNoteCount == 0)
    }

    @Test("SourceProvenanceData: an all-pre-1900 index shows nothing but still safe")
    func allPre1900Safe() {
        let index = SourceProvenanceIndex(
            schemaVersion: 1, generated: "2026-07-04",
            totalSourceNotes: 10, volumesCovered: 1,
            categories: SourceProvenanceCategory.ordered.map(\.rawValue),
            byDecade: [DecadeProvenance(decade: 1840, totalNotes: 10, volumeCount: 1,
                                        counts: ["unrecognized": 10])]
        )
        let data = SourceProvenanceData(index: index)
        #expect(data.shareByDecade.isEmpty)
        #expect(data.decadeRangeShown == nil)
        #expect(data.prewarExcludedNoteCount == 10)
    }

    // MARK: Integration — the bundled artifact

    /// Guards that the real `source-provenance-index.json` is bundled and matches
    /// the schema, with the SA-3a headline figures. This proves the resource is in
    /// the built product and decodes via `SourceProvenanceIndex`.
    @Test("Bundled source-provenance-index.json decodes with the expected headline figures")
    func bundledArtifactDecodes() throws {
        let url = try #require(
            Bundle.main.url(forResource: "source-provenance-index", withExtension: "json"),
            "source-provenance-index.json must be bundled as an app resource"
        )
        let data = try Data(contentsOf: url)
        let index = try JSONDecoder().decode(SourceProvenanceIndex.self, from: data)
        #expect(index.schemaVersion == 1)
        #expect(index.totalSourceNotes == 268757)
        #expect(index.volumesCovered == 522)
        #expect(index.byDecade.count == 16, "SA-3a ships 16 coverage decades; got \(index.byDecade.count)")
        #expect(index.categories.count == 10)

        // The derivation over the real data floors to >= 1900 and stays sound.
        let derived = SourceProvenanceData(index: index)
        #expect(derived.decadeRangeShown?.lowerBound == 1900)
        #expect(!derived.shareByDecade.isEmpty)
        for decade in Set(derived.shareByDecade.map(\.decade)) {
            let sum = derived.shareByDecade.filter { $0.decade == decade }.reduce(0.0) { $0 + $1.share }
            #expect(abs(sum - 1.0) < 1e-6, "real decade \(decade) shares summed to \(sum)")
        }
    }

    // MARK: Category filter (#236)

    /// The full coverage-year domain (well past the shown decades) so decade filtering
    /// never confounds the category-exclusion assertions.
    private var allDecades: ClosedRange<Int> { 1900...2000 }

    @Test("category filter: empty exclusion set is identity")
    func categoryFilterEmptyIsIdentity() {
        let data = SourceProvenanceData(index: fixture())
        let filtered = data.shareByDecade(in: allDecades, excluding: [])
        let plain = data.shareByDecade(in: allDecades)
        #expect(filtered.map(\.id) == plain.map(\.id))
        #expect(filtered.map(\.share) == plain.map(\.share))
        #expect(data.overallComposition(excluding: []).map(\.category)
                == data.overallComposition.map(\.category))
    }

    @Test("category filter: hidden category is removed and remaining shares renormalize to 1.0")
    func categoryFilterRenormalizes() {
        let data = SourceProvenanceData(index: fixture())
        // 1950 raw (known) counts: centralDecimalFile 40, lotFile 20, presidentialLibrary 20.
        // Hide presidentialLibrary → shown total 60 → cdf 40/60, lot 20/60.
        let filtered = data.shareByDecade(in: allDecades, excluding: [.presidentialLibrary])
        let d1950 = filtered.filter { $0.decade == 1950 }
        #expect(!d1950.contains { $0.category == .presidentialLibrary })
        let cdf = d1950.first { $0.category == .centralDecimalFile }?.share ?? 0
        let lot = d1950.first { $0.category == .lotFile }?.share ?? 0
        #expect(abs(cdf - 40.0 / 60.0) < 1e-9)
        #expect(abs(lot - 20.0 / 60.0) < 1e-9)
        // Every shown decade still sums to 1.0 across the shown categories.
        for decade in Set(filtered.map(\.decade)) {
            let sum = filtered.filter { $0.decade == decade }.reduce(0.0) { $0 + $1.share }
            #expect(abs(sum - 1.0) < 1e-9, "decade \(decade) filtered shares summed to \(sum)")
        }
    }

    @Test("category filter: an all-zero decade for the shown categories is dropped, not divided by zero")
    func categoryFilterDropsEmptyDecade() {
        let data = SourceProvenanceData(index: fixture())
        // 1910 is 100% centralDecimalFile; hiding it leaves that decade with no shown notes.
        let filtered = data.shareByDecade(in: allDecades, excluding: [.centralDecimalFile])
        #expect(!filtered.contains { $0.decade == 1910 })
        // 1970 (presidentialLibrary + CFPF) is unaffected and still sums to 1.0.
        let d1970 = filtered.filter { $0.decade == 1970 }
        #expect(abs(d1970.reduce(0.0) { $0 + $1.share } - 1.0) < 1e-9)
    }

    @Test("category filter: overallComposition renormalizes over shown categories, hidden dropped")
    func overallCompositionFilter() {
        let data = SourceProvenanceData(index: fixture())
        let filtered = data.overallComposition(excluding: [.unrecognized])
        #expect(!filtered.contains { $0.category == .unrecognized })
        // Shown categories' shares sum to 1.0 (categories with zero notes contribute 0).
        let sum = filtered.reduce(0.0) { $0 + $1.share }
        #expect(abs(sum - 1.0) < 1e-9)
        // Stable order preserved (subsequence of the canonical order).
        let order = SourceProvenanceCategory.ordered
        let idx = filtered.map { order.firstIndex(of: $0.category)! }
        #expect(idx == idx.sorted())
    }
}
