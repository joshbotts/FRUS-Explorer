// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif
#if canImport(SourceNoteKit)
import SourceNoteKit
#endif

// MARK: - SourceExplorerPanelsHostTests

/// The rules Source Explorer's panels read while they draw, as a host calls them (FRUS Explorer Light's
/// S22c): `SourceExplorerPanels`, which moved out of `SourceExplorerView.swift`. The app's own suites drive
/// them through the view's names, in Xcode alone; these run in the package too, so Linux's Foundation
/// computes the same lines, its `String(localized:)` stand-in among them.
///
/// Version history:
///   1.0 — 2026-11-11: FRUS Explorer Light's S22c, with the rules' move into FRUSCoreKit
@Suite("Source Explorer's panel rules — as a host calls them")
struct SourceExplorerPanelsHostTests {

    /// frus1961-63v15/d177, a telegram of 21 February 1963, as `SubjectNumericExplorerTests` reads it.
    private static let note1963 = "Source: Department of State, Central Files, POL US–USSR. Secret; Priority. Drafted and initialed by Hillenbrand on February 19; cleared by Thompson, Tyler, Guthrie, and Bundy; and approved and initialed by Rusk."

    @Test("A Subject-Numeric note of 1963 reads its designation, the 1963 block, the 1963 handbook and NARA's page")
    func subjectNumericReading() throws {
        let day = DecimalFileSegment.DocumentDay(year: 1963, month: 2, day: 21)
        let reading = try #require(SourceExplorerPanels.subjectNumericCitation(
            parsed: SourceNoteParser().parse(Self.note1963), note: Self.note1963, documentDay: day))
        #expect(reading.designation == "POL US–USSR")
        #expect(reading.block == "1963")
        #expect(reading.handbooks.map(\.label) == ["Classification Handbook 1963 (PDF)"])
        #expect(reading.pageURL.absoluteString
                == "https://www.archives.gov/research/foreign-policy/state-dept/rg-59-central-files/1963-1973")
        #expect(SourceExplorerPanels.subjectNumericBlock(for: day) == "1963")
        #expect(SourceExplorerPanels.subjectNumericBlock(for: .init(year: 1965, month: 6, day: 1)) == "1964–66")
        #expect(SourceExplorerPanels.subjectNumericCitation(parsed: nil, note: "", documentDay: nil) == nil)
    }

    @Test("The filing periods are NARA's five eras in eleven rows, the Subject-Numeric File's with both handbooks")
    func filingPeriods() {
        let periods = SourceExplorerPanels.allFilingPeriods
        #expect(periods.map(\.id) == ["1789-1906", "1906-1910", "1910-1929", "1930-1939", "1940-1944", "1945-1949",
                                      "1950-1954", "1955-1959", "1960-1963", "1963-1973", "1973-1979"])
        #expect(periods.first { $0.id == "1963-1973" }?.filingManuals.map(\.label)
                == ["Classification Handbook 1963 (PDF)", "Classification Handbook 1965–73 (PDF)"])
        #expect(periods.allSatisfy { $0.url.host == "www.archives.gov" })
        #expect(periods.flatMap(\.filingManuals).allSatisfy { $0.url.host == "www.archives.gov" })
    }

    @Test("Archival Neighbors: a lot's basis names the lot, and a note with no parse matches nothing")
    func archivalNeighbors() throws {
        let note = "Department of State, Conference Files: Lot 60 D 224, CF 1626."
        let basis = try #require(SourceExplorerPanels.archivalNeighborBasis(
            for: SourceNoteParser().parse(note), note: note, documentYear: nil, documentDay: nil))
        #expect(basis.hasPrefix("Same lot file — "), "\(basis)")
        #expect(basis.contains("60"), "\(basis)")
        #expect(SourceExplorerPanels.relatedEmptyState(for: nil, note: "") == .unmatched)
        #expect(SourceExplorerPanels.relatedMatchKey(for: nil, note: "") == nil)
        #expect(SourceExplorerPanels.archivalNeighborBasis(for: nil, note: "", documentYear: nil, documentDay: nil) == nil)
    }

    @Test("The scans' caveat says the scan is the file range's, not the document's")
    func scanCaveat() {
        #expect(SourceExplorerPanels.scanCaveat.contains("not of this document"))
    }

    #if !SWIFT_PACKAGE // the view's names are the app's
    @Test("The view's names give the kit's values")
    @MainActor
    func viewForwards() {
        #expect(SourceExplorerView.scanCaveat == SourceExplorerPanels.scanCaveat)
        #expect(SourceExplorerView.allFilingPeriods.map(\.id) == SourceExplorerPanels.allFilingPeriods.map(\.id))
        let parsed = SourceNoteParser().parse(Self.note1963)
        let day = DecimalFileSegment.DocumentDay(year: 1963, month: 2, day: 21)
        #expect(SourceExplorerView.subjectNumericCitation(parsed: parsed, note: Self.note1963, documentDay: day)
                == SourceExplorerPanels.subjectNumericCitation(parsed: parsed, note: Self.note1963, documentDay: day))
        #expect(SourceExplorerView.relatedEmptyState(for: nil, note: "") == .unmatched)
    }
    #endif
}
