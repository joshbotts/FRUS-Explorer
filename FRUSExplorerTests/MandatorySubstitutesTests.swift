// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Testing
import Foundation
@testable import FRUSExplorer

// MARK: - Fixtures

/// Fixture indexes for chapter 4, decoded from JSON rather than constructed.
///
/// `DigitizedRangeIndex` and `RollScansIndex` both build a private lookup table inside
/// `init(from:)` and therefore have no memberwise initialiser — so decoding is not merely
/// convenient, it is the only way in, and it means these tests exercise the real decode path that
/// the bundled artifacts take.
private enum SubstituteFixtures {

    /// Decodes a range index over the supplied rows.
    static func ranges(_ rows: String) -> DigitizedRangeIndex {
        let json = """
        {"schemaVersion":1,"generated":"2026-08-22","seriesNaIds":["302021"],
         "note":"fixture","ranges":[\(rows)]}
        """
        return try! JSONDecoder().decode(DigitizedRangeIndex.self, from: Data(json.utf8))
    }

    /// One range row.
    static func range(_ decimalClass: String, _ low: Int, _ high: Int,
                      naId: String, objects: Int = 10, title: String) -> String {
        """
        {"decimalClass":"\(decimalClass)","low":\(low),"high":\(high),"naId":"\(naId)",
         "objectCount":\(objects),"title":"\(title)"}
        """
    }

    /// Decodes a roll-scan index over the supplied `(naId, objectCount)` pairs.
    static func rollScans(_ pairs: [(String, Int)]) -> RollScansIndex {
        let rows = pairs.map { #"{"naId":"\#($0.0)","objectCount":\#($0.1)}"# }
            .joined(separator: ",")
        let json = """
        {"schemaVersion":1,"generated":"2026-08-22","seriesNaId":"654171","scans":[\(rows)]}
        """
        return try! JSONDecoder().decode(RollScansIndex.self, from: Data(json.utf8))
    }

    /// A numerical-file index over the supplied rolls.
    static func numericalFile(_ rolls: [NumericalFileRoll]) -> NumericalFileIndex {
        NumericalFileIndex(seriesNaId: "654171", microfilm: "M862", rolls: rolls)
    }

    /// One roll.
    static func roll(_ naId: String, _ start: Int, _ end: Int, title: String) -> NumericalFileRoll {
        NumericalFileRoll(naId: naId, title: title, caseStart: start, caseEnd: end,
                          catalogURL: "https://catalog.archives.gov/id/\(naId)")
    }

    /// Builds with every index injected, so no test can silently fall through to the bundle.
    static func build(_ files: [MandatorySubstitutes.CitedFile],
                      ranges rangeIndex: DigitizedRangeIndex? = nil,
                      rolls rollIndex: RollScansIndex? = nil,
                      numericalFile numerical: NumericalFileIndex? = nil) -> MandatorySubstitutes {
        MandatorySubstitutes.build(citedFiles: files, ranges: rangeIndex,
                                   rolls: rollIndex, numericalFile: numerical)
    }
}

// MARK: - MandatorySubstitutesTests

/// Pins chapter 4, the A6 mandatory-substitutes aggregation (#830 T-3).
///
/// Version history:
///   1.0 — Session 2026-08-22: #830 T-3
@Suite("A6 mandatory substitutes (#830 T-3)")
struct MandatorySubstitutesTests {

    // MARK: - The year gate

    /// **The defect this suite exists for**, and BOTH halves are needed — measured against real
    /// corpus notes, each signal alone routes some real citation wrongly.
    ///
    /// Form alone: decimal classes are not all dotted (the shipped index's first row is class
    /// `131`), so `131/423` is rejected by `isDecimalFileForm` and parses as case 131 — handing a
    /// 1939 decimal citation a 1906–1910 roll. Year alone: 1910 is the transition year and carries
    /// both forms, so a pure year gate sends the real note `File No. 811.304M28/45` (1910) to the
    /// rolls, where a decimal number yields no case at all, and it reaches neither route.
    ///
    /// Both fixtures are armed so a wrong route is *visible* rather than merely absent.
    @Test("Routing takes the year and the form together")
    func routingTakesYearAndFormTogether() {
        let ranges = SubstituteFixtures.ranges([
            SubstituteFixtures.range("131", 1, 500, naId: "RANGE", title: "Scanned range"),
            SubstituteFixtures.range("811.304m28", 1, 100, naId: "TRANSITION", title: "1910 scans"),
        ].joined(separator: ","))
        let numerical = SubstituteFixtures.numericalFile([
            SubstituteFixtures.roll("ROLL", 100, 200, title: "Numerical File: 100-200"),
            SubstituteFixtures.roll("EARLY", 6700, 6800, title: "Numerical File: 6700-6800"),
        ])

        // Out of band, dotless decimal class: the range, never the roll that also covers case 131.
        let modern = SubstituteFixtures.build(
            [.init(identifier: "131/423", year: 1939)], ranges: ranges, numericalFile: numerical)
        #expect(modern.rows.map(\.naId) == ["RANGE"])

        // In band, non-decimal form: the roll. A real 1907 note.
        let early = SubstituteFixtures.build(
            [.init(identifier: "6775/57", year: 1907)], ranges: ranges, numericalFile: numerical)
        #expect(early.rows.map(\.naId) == ["EARLY"])
        #expect(early.rows.first?.route == .microfilmRoll)

        // In band but DECIMAL form — the transition year. A real 1910 note; a pure year gate loses
        // this one entirely.
        let transition = SubstituteFixtures.build(
            [.init(identifier: "811.304M28/45", year: 1910)], ranges: ranges, numericalFile: numerical)
        #expect(transition.rows.map(\.naId) == ["TRANSITION"])
        #expect(transition.rows.first?.route == .digitizedRange)
    }

    /// A document with no year takes the decimal route, matching the Source Explorer's own gate,
    /// which requires a known year in 1906–1910 before it offers a roll.
    @Test("An unknown year falls to the decimal route, never to the rolls")
    func unknownYearDoesNotReachTheRolls() {
        let numerical = SubstituteFixtures.numericalFile(
            [SubstituteFixtures.roll("ROLL", 100, 200, title: "Numerical File: 100-200")])
        let result = SubstituteFixtures.build(
            [.init(identifier: "131/423", year: nil)], numericalFile: numerical)
        #expect(result.rows.isEmpty)
        #expect(result.documentsTested == 1)
    }

    // MARK: - The digitised-range route

    @Test("A sole claimant becomes one row a reader can walk to")
    func resolvedRangeBecomesASoleClaimantRow() {
        let ranges = SubstituteFixtures.ranges(
            SubstituteFixtures.range("763.72", 1, 100, naId: "A", objects: 802, title: "WWI scans"))
        let result = SubstituteFixtures.build(
            [.init(identifier: "763.72/50", year: 1918)], ranges: ranges)

        #expect(result.rows.count == 1)
        #expect(result.rows.first?.naId == "A")
        #expect(result.rows.first?.isSoleClaimant == true)
        #expect(result.rows.first?.objectCount == 802)
        #expect(result.rows.first?.documentCount == 1)
        #expect(result.documentsTested == 1)
        #expect(result.documentsWithSubstitute == 1)
        #expect(result.rows.first?.catalogURL?.absoluteString == "https://catalog.archives.gov/id/A")
    }

    /// NARA's digitisation is layered, so one serial legitimately sits inside several ranges. Every
    /// claimant is listed and flagged; collapsing to the narrowest would send a reader into a scan
    /// that may not hold their document.
    ///
    /// The second assertion is the one that matters: **the document is counted once**, not once per
    /// claimant. A citation claimed by two ranges is one document that need not be pulled.
    @Test("Every claimant of an ambiguous match is listed, and the document counted once")
    func ambiguousMatchListsEveryClaimantButCountsOneDocument() {
        let ranges = SubstituteFixtures.ranges([
            SubstituteFixtures.range("763.72", 1, 1000, naId: "WIDE", title: "Wide"),
            SubstituteFixtures.range("763.72", 40, 60, naId: "NARROW", title: "Narrow"),
        ].joined(separator: ","))

        let result = SubstituteFixtures.build(
            [.init(identifier: "763.72/50", year: 1918)], ranges: ranges)

        #expect(Set(result.rows.map(\.naId)) == ["WIDE", "NARROW"])
        #expect(result.rows.allSatisfy { !$0.isSoleClaimant })
        #expect(result.documentsWithSubstitute == 1)
    }

    /// "Scans exist for this file, just not for the part you cite" is informative and is not "no
    /// scans" — but it is not a substitute either, because the reader still has to pull. So it is
    /// counted and stated, never tabled under a heading that says to use these instead.
    @Test("A partly digitised class is counted, never tabled")
    func partlyDigitizedClassIsCountedNotTabled() {
        let ranges = SubstituteFixtures.ranges(
            SubstituteFixtures.range("763.72", 1, 100, naId: "A", title: "Scans"))
        let result = SubstituteFixtures.build(
            [.init(identifier: "763.72/5000", year: 1918)], ranges: ranges)

        #expect(result.rows.isEmpty)
        #expect(result.partiallyDigitizedCount == 1)
        #expect(result.documentsWithSubstitute == 0)
        #expect(result.documentsTested == 1)
        #expect(result.coverageNote.contains("partly digitized"))
    }

    // MARK: - The microfilm route

    /// A case regularly spills across consecutive rolls, so every roll holding it is named — and
    /// each is flagged ambiguous, because the reader has to check which one has their document.
    @Test("A case split across rolls names every roll, image counts from the scan index")
    func caseSplitAcrossRollsNamesEveryRoll() {
        let numerical = SubstituteFixtures.numericalFile([
            SubstituteFixtures.roll("R1", 7000, 7200, title: "Numerical File: 7000-7200"),
            SubstituteFixtures.roll("R2", 7100, 7300, title: "Numerical File: 7100-7300"),
        ])
        let scans = SubstituteFixtures.rollScans([("R1", 1172), ("R2", 980)])

        let result = SubstituteFixtures.build(
            [.init(identifier: "7187/43", year: 1908)], rolls: scans, numericalFile: numerical)

        #expect(Set(result.rows.map(\.naId)) == ["R1", "R2"])
        #expect(result.rows.allSatisfy { !$0.isSoleClaimant })
        #expect(result.rows.allSatisfy { $0.route == .microfilmRoll })
        #expect(result.rows.first(where: { $0.naId == "R1" })?.objectCount == 1172)
        #expect(result.documentsWithSubstitute == 1)
    }

    /// The image count is a nicety; a missing scan row must not drop the roll, because the roll is
    /// still the thing the reader has to use.
    @Test("A roll with no scan row still prints, with no image count")
    func rollWithoutScanRowStillPrints() {
        let numerical = SubstituteFixtures.numericalFile(
            [SubstituteFixtures.roll("R1", 7000, 7200, title: "Numerical File: 7000-7200")])
        let result = SubstituteFixtures.build(
            [.init(identifier: "7187", year: 1908)], numericalFile: numerical)

        #expect(result.rows.map(\.naId) == ["R1"])
        #expect(result.rows.first?.objectCount == 0)
    }

    // MARK: - The denominator

    /// A note that named no file was never tested, and must not read as a tested miss — otherwise
    /// the chapter reports a worse hit rate than it earned over documents it never examined.
    @Test("Documents citing no file number stay out of the denominator")
    func untestableDocumentsStayOutOfTheDenominator() {
        let ranges = SubstituteFixtures.ranges(
            SubstituteFixtures.range("763.72", 1, 100, naId: "A", title: "Scans"))
        let result = SubstituteFixtures.build([
            .init(identifier: "763.72/50", year: 1918),
            .init(identifier: nil, year: 1918),
            .init(identifier: "   ", year: 1918),
        ], ranges: ranges)

        #expect(result.documentsTested == 1)
        #expect(result.documentsWithSubstitute == 1)
    }

    /// Phase 1's fold input: `matchesByDocument` records each matched document's units, and
    /// only for files that carried a document key — a key-less file still counts in the
    /// aggregate but cannot be marked.
    @Test("matchesByDocument records matched units per document key")
    func matchesByDocumentRecordsMatches() {
        let ranges = SubstituteFixtures.ranges(
            SubstituteFixtures.range("612", 1, 500, naId: "A", title: "Range A"))
        let result = SubstituteFixtures.build([
            .init(identifier: "612/23", year: 1950, documentKey: "v1/d1"),
            .init(identifier: "612/24", year: 1950),
            .init(identifier: "999.99/1", year: 1950, documentKey: "v1/d3"),
        ], ranges: ranges)
        #expect(result.matchesByDocument == ["v1/d1": ["A"]], """
            Only the keyed, matched document may appear: the key-less match is unmarkable and \
            the unmatched document has nothing to mark.
            """)
        #expect(result.documentsWithSubstitute == 2,
                "the key-less match still counts in the aggregate")
    }

    /// An empty chapter must say the app saw two routes only — silence would read as a clearance
    /// to pull everything, which is the error A6 exists to prevent.
    @Test("The coverage note refuses to imply nothing is digitised")
    func coverageNoteStatesItsOwnReach() {
        let none = SubstituteFixtures.build([.init(identifier: nil, year: 1950)])
        #expect(none.documentsTested == 0)
        #expect(none.coverageNote.contains("can say nothing either way"))

        let tested = SubstituteFixtures.build([.init(identifier: "999.99/1", year: 1950)])
        #expect(tested.coverageNote.contains("two routes"))
        #expect(tested.coverageNote.contains("Confirm with staff"))
    }

    // MARK: - Ordering

    /// The tie-break fixture is built **against** the expectation: the row with more documents is
    /// given the alphabetically LATER NAID, so sorting by NAID alone — or forgetting the count key
    /// entirely — produces the opposite order. A fixture whose final key alone yields the expected
    /// answer would leave every earlier key untested.
    @Test("Rows sort by affected documents before NAID")
    func rowsSortByAffectedDocumentsBeforeNaId() {
        let ranges = SubstituteFixtures.ranges([
            SubstituteFixtures.range("100", 1, 10, naId: "AAA", title: "One document"),
            SubstituteFixtures.range("200", 1, 10, naId: "ZZZ", title: "Two documents"),
        ].joined(separator: ","))

        let result = SubstituteFixtures.build([
            .init(identifier: "100/5", year: 1950),
            .init(identifier: "200/5", year: 1950),
            .init(identifier: "200/6", year: 1950),
        ], ranges: ranges)

        #expect(result.rows.map(\.naId) == ["ZZZ", "AAA"])
        #expect(result.rows.first?.documentCount == 2)
    }

    // MARK: - The extractor's scope

    /// Chapter 4's two lookups both live under `.centralFiles`. A lot file's identifier is a folder
    /// designation, so admitting it would add documents to the denominator that no route could
    /// match — a worse hit rate reported over documents never actually tested.
    @Test("Only central-file citations yield an identifier")
    @MainActor
    func extractorAdmitsOnlyCentralFiles() {
        // Real corpus spellings, taken from source-explorer-export-sample.json.
        #expect(TripPacketBuilder.centralFileIdentifier(in: "File No. 811.304M28/45.")
                == "811.304M28/45")
        #expect(TripPacketBuilder.centralFileIdentifier(in: "File No. 6775/57.") == "6775/57")
        #expect(TripPacketBuilder.centralFileIdentifier(
            in: "Source: Department of State, Central Files 1967-69, POL 7 VIET S. Confidential.")
                != nil)

        // A lot file's identifier is a folder designation, and a library's is a box — admitting
        // either would put documents in the denominator that no route could ever match.
        #expect(TripPacketBuilder.centralFileIdentifier(in: "Lot 60-D 224, Box 55: D.O./P.R./20")
                == nil)
        #expect(TripPacketBuilder.centralFileIdentifier(
            in: "Source: Kennedy Library, President's Office Files, Departments and Agencies "
                + "Series, Box 91, USIA 7/61-12/61. No classification marking.") == nil)
    }
}

// MARK: - MandatorySubstitutesFoldTests

/// Pins the chapter-4 fold (#830 T-3; Archive Visits Phase 1).
///
/// The standalone chapter is gone: the rows became per-seeding markers on the target list, and
/// the four facts with no row to sit on — the denominators, the partial-digitization count, the
/// layered warning, the citation rule — landed in the coverage report (§3a). This suite pins
/// that landing.
///
/// Version history:
///   1.0 — Session 2026-08-22: #830 T-3 (as `MandatorySubstitutesChapterTests`)
///   2.0 — Archive Visits Phase 1: re-pinned from the deleted chapter to the fold
@Suite("Substitutes fold (#830 T-3 / Phase 1)")
struct MandatorySubstitutesFoldTests {

    /// A model whose substitutes aggregate is injected, so the exporter is driven by a known
    /// value rather than by whatever the bundled indexes happen to hold.
    private func model(substitutes: MandatorySubstitutes) -> TripPacketModel {
        TripPacketModel.build(
            groups: [(key: "class|763.72", label: "Central Decimal File 763.72",
                      category: .centralDecimalFile, repository: nil, lotAsPrinted: nil,
                      resolution: nil, documents: TripPacketExporterTests.refs(4))],
            documentYears: [1918],
            unresolvedLotCount: 0,
            unresolvedDocumentCount: 0,
            researchQuestion: nil,
            facts: { _ in nil },
            substitutes: { _ in substitutes },
            claimants: { _ in nil })
    }

    private func rows(_ count: Int) -> [MandatorySubstitutes.Row] {
        (0..<count).map {
            MandatorySubstitutes.Row(naId: "N\($0)", title: "Range \($0)", route: .digitizedRange,
                                     objectCount: 10, documentCount: count - $0,
                                     isSoleClaimant: true)
        }
    }

    /// The rule is NARA's obligation, quoted — not the app's advice, paraphrased — and it
    /// prints whenever any document actually has a substitute.
    @Test("The A6 rule is quoted and attributed when substitutes exist")
    func ruleIsQuoted() {
        let substitutes = MandatorySubstitutes(rows: rows(1), documentsTested: 4,
                                               documentsWithSubstitute: 1,
                                               partiallyDigitizedCount: 0)
        let text = TripPacketExporter(model: model(substitutes: substitutes),
                                      projectName: "P").export()
        #expect(text.contains(
            "\"Researchers must use microfilm and online resources when those options are available.\""))
    }

    /// An empty result that said nothing would read as a clearance to pull everything — the
    /// coverage caveat prints unconditionally.
    @Test("An empty substitutes result still prints its coverage caveat")
    func emptyResultStillCaveats() {
        let substitutes = MandatorySubstitutes(rows: [], documentsTested: 6,
                                               documentsWithSubstitute: 0,
                                               partiallyDigitizedCount: 0)
        let text = TripPacketExporter(model: model(substitutes: substitutes),
                                      projectName: "P").export()
        #expect(text.contains("two routes"))
        #expect(text.contains("Confirm with staff"))
        #expect(!text.contains("Researchers must use microfilm"),
                "no substitute exists, so quoting the obligation would point at nothing")
    }

    /// The marker rides only the documents that matched — a target-level flag would assert
    /// coverage of documents that were never tested (§3a's grain argument).
    @Test("The seeding marker names the unit, at document grain")
    func markerIsPerDocument() {
        let substitutes = MandatorySubstitutes(
            rows: rows(1), documentsTested: 4, documentsWithSubstitute: 1,
            partiallyDigitizedCount: 0,
            matchesByDocument: ["frus1948v02/d2": ["N0"]])
        let text = TripPacketExporter(model: model(substitutes: substitutes),
                                      projectName: "P").export()
        let markers = text.components(separatedBy: "Digitized or filmed — use Range 0 (NAID N0)")
        #expect(markers.count == 2, "exactly one document matched, so exactly one marker")
        let markedLine = text.components(separatedBy: "FRUS 1948 II, Document 2")[1]
            .components(separatedBy: "FRUS 1948 II, Document 3")[0]
        #expect(markedLine.contains("instead of pulling"),
                "the marker must sit under the matched document's own seeding row")
    }
}
