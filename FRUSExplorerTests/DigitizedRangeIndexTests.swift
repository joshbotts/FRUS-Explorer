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

// MARK: - DigitizedRangeIndexTests

/// Linking NARA's scans for the file range a decimal citation names (#663).
///
/// ## What is being guarded
/// A wrong roll is worse than no roll — the same constraint as every other archival link in
/// this app. The index answers about a **file range**, never about a document, and the four
/// match states are what keeps that distinction visible.
///
/// The reach is deliberately measured rather than assumed: over the shipped artifact and the
/// owner's index, **5,323 of 185,694** classed decimal citations land in a digitised range, and
/// over 5,000 of those are the `763.72` European War file. This is *the WWI supplements get
/// their microfilm*, not a corpus-wide capability, and the tests below pin the honest states
/// rather than the headline.
///
/// Version history:
///   1.0 — Session 2026-08-07: #663
@Suite("Digitised scan ranges")
struct DigitizedRangeIndexTests {

    private func index() throws -> DigitizedRangeIndex {
        try #require(DigitizedRangeIndexStore.shared,
                     "digitized-ranges-index.json must be bundled")
    }

    // MARK: - Reading a citation

    /// The citation form the corpus actually stores.
    @Test("A decimal identifier yields its class and serial")
    func classAndSerialAreRead() {
        let p = DigitizedRangeIndex.classAndSerial(fromFileIdentifier: "763.72/1476")
        #expect(p?.0 == "763.72")
        #expect(p?.1 == 1476)
    }

    /// A citation with no serial cannot be placed in a range. Matching it on the class alone
    /// would answer "there is a scan of this file" to a question about a document.
    @Test("A class with no serial is not placed")
    func classWithoutSerialIsNotPlaced() {
        #expect(DigitizedRangeIndex.classAndSerial(fromFileIdentifier: "763.72") == nil)
        #expect(DigitizedRangeIndex.classAndSerial(fromFileIdentifier: "") == nil)
    }

    /// The harvest writes `131.` and `131` interchangeably; both must key alike or half a
    /// class's ranges become unreachable.
    @Test("The class key ignores a trailing dot and case")
    func classKeyIsCanonical() {
        #expect(DigitizedRangeIndex.canonicalClass("131.") == "131")
        #expect(DigitizedRangeIndex.canonicalClass(" 763.72119 ") == "763.72119")
        #expect(DigitizedRangeIndex.canonicalClass("763.72112A") == "763.72112a")
    }

    // MARK: - The four states, against the real bundled index

    /// A citation that lands in exactly one range.
    @Test("A serial inside one range resolves to it")
    func singleRangeResolves() throws {
        let index = try index()
        // 763.72111/5551-6950 is the only range in its class covering 6000.
        guard case .resolved(let range) = index.match(decimalClass: "763.72111", serial: 6000)
        else {
            Issue.record("expected a single range: \(index.match(decimalClass: "763.72111", serial: 6000))")
            return
        }
        #expect(range.contains(serial: 6000))
        #expect(range.decimalClass == "763.72111")
    }

    /// **The layered-digitisation case, which is the majority of hits.** `763.72/354-13348A` is
    /// one file unit spanning 12,994 serials and overlaps every narrow roll in the class, so a
    /// citation legitimately sits inside several. They come back narrowest first; nothing
    /// claims which is *the* one.
    @Test("Overlapping ranges come back narrowest first")
    func multipleRangesAreOrderedBySpan() throws {
        let index = try index()
        guard case .multipleRanges(let ranges) = index.match(decimalClass: "763.72", serial: 600)
        else {
            Issue.record("expected several ranges: \(index.match(decimalClass: "763.72", serial: 600))")
            return
        }
        #expect(ranges.count > 1)
        let spans = ranges.map { $0.high - $0.low }
        #expect(spans == spans.sorted(), Comment(rawValue: "spans out of order: \(spans)"))
        #expect(ranges.allSatisfy { $0.contains(serial: 600) })
    }

    /// "Scans exist for this file, just not this part of it" is a useful answer and is not
    /// "no scans".
    @Test("A class with scans but no covering range says so")
    func classScannedButSerialUncovered() throws {
        let index = try index()
        guard case .classDigitizedButSerialNotCovered(let count) =
                index.match(decimalClass: "763.72", serial: 9_999_999)
        else {
            Issue.record("expected the partial state")
            return
        }
        #expect(count > 0)
    }

    /// The classes FRUS cites most are not digitised at all, and the panel must stay silent
    /// for them rather than inventing a near miss.
    @Test("An undigitised class yields nothing")
    func undigitizedClassYieldsNothing() throws {
        let index = try index()
        // 893 (China, internal) is the corpus's most-cited class and has zero digitised units.
        #expect(index.match(decimalClass: "893.00", serial: 1) == .none)
        #expect(index.match(decimalClass: "611.41", serial: 12) == .none)
    }

    // MARK: - The artifact's own contract

    /// The direct scan link is offered **only** for a whole-roll PDF. 184 of the 624 ranges
    /// publish a `.tif` or `.jpg` first image, and sending a researcher to one frame of 802 is
    /// worse than sending them to the viewer holding all of them.
    @Test("Only whole-roll PDFs get a direct link")
    func onlyPDFsLinkDirectly() throws {
        let index = try index()
        for range in index.ranges {
            let isPDF = (range.objectFilename ?? "").lowercased().hasSuffix(".pdf")
            #expect((range.rollPDFURL != nil) == isPDF,
                    Comment(rawValue: "\(range.naId) \(range.objectFilename ?? "-")"))
            // Every range keeps a catalog record, whatever its object type.
            #expect(range.catalogURL?.absoluteString
                    == "https://catalog.archives.gov/id/\(range.naId)")
        }
    }

    /// Every range is a well-formed interval keyed to a class. An inverted or classless row
    /// would make containment answer false forever and hide itself.
    @Test("Every bundled range is a well-formed interval")
    func rangesAreWellFormed() throws {
        let index = try index()
        #expect(index.ranges.count > 500,
                Comment(rawValue: "only \(index.ranges.count) ranges — did the harvest change?"))
        for range in index.ranges {
            #expect(range.low <= range.high, Comment(rawValue: "inverted: \(range.title)"))
            #expect(!range.decimalClass.isEmpty)
            #expect(range.objectCount > 0, Comment(rawValue: "\(range.naId) has no images"))
        }
    }

    /// The Numerical File series is deliberately absent: the app already routes 1906–1910
    /// citations to their roll through `central-files-index.json`, and two indexes answering
    /// one question is how two surfaces come to disagree.
    @Test("The index covers the two decimal series and not the Numerical File")
    func seriesProvenanceIsPinned() throws {
        let index = try index()
        #expect(Set(index.seriesNaIds) == ["302021", "2555709"])
        #expect(!index.seriesNaIds.contains("654171"))
    }

    // MARK: - Wiring

    private static let views = [
        "FRUSExplorer/SourceExplorer/SourceExplorerView.swift",
        "FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift",
    ]

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appending(path: path), encoding: .utf8)
        #expect(text.count > 1_000, Comment(rawValue: "\(path) is implausibly small — did it move?"))
        return text
    }

    /// Both views must reach the index, and both must carry the caveat. A source audit: it
    /// detects removal, not a wrong surrounding condition.
    @Test("Both views render the scans, with the caveat")
    func bothViewsRenderTheScans() throws {
        for path in Self.views {
            let text = try Self.source(path)
            #expect(text.contains("DigitizedRangeIndex"),
                    Comment(rawValue: "\(path) never consults the digitised-range index"))
            #expect(text.contains("multipleRanges"),
                    Comment(rawValue: """
                            \(path) does not handle the overlapping-range case, which is the \
                            majority of hits — 2,773 of 5,323 documents.
                            """))
            #expect(text.contains("scanCaveat") || text.contains("scans.caveat"),
                    Comment(rawValue: """
                            \(path) shows a scan without the line saying it is the file range \
                            and not this document.
                            """))
        }
    }

    /// The caveat's job is to refuse the claim the link invites. If it stops saying so, the
    /// panel starts implying the scan is of the document.
    @Test("The caveat declines to claim the document")
    func caveatDeclinesTheDocument() {
        let caveat = SourceExplorerView.scanCaveat
        #expect(caveat.localizedCaseInsensitiveContains("not of this document"),
                Comment(rawValue: "caveat no longer refuses the document claim: \(caveat)"))
    }
}

// MARK: - RollScansIndexTests

/// Scan data for the M862 Numerical File rolls (#663 follow-up).
///
/// ## Why this is a NAID join and not a second range parser
/// `central-files-index.json` already names every M862 roll. What it could not do was open one:
/// its roll records carry `caseStart`, `caseEnd`, `naId`, `catalogURL`, `title` and nothing
/// else. The harvest has the image count and the roll PDF, and they join by identifier —
/// **1,218 of the 1,261 bundled rolls, 96.6%**, with no parsing at all. The decimal half of
/// #663 had to parse titles and reached 14.7% of its candidate units.
///
/// Worth **2,449 documents**: every 1906–1910 citation that already resolves to a roll, of which
/// 2,425 have every one of their rolls digitised.
///
/// ## Why the two sections stayed separate
/// Multiple rolls mean *opposite* things in the two routes. A Numerical File case split across
/// consecutive rolls is the **complete** answer — the researcher needs all of them. Several
/// decimal ranges mean NARA digitised in overlapping layers, and that section says "narrowest
/// first, the widest is not wrong". One wording cannot serve both, so only the row is shared.
///
/// Version history:
///   1.0 — Session 2026-08-07: #663 follow-up
@Suite("Numerical File roll scans")
struct RollScansIndexTests {

    private func index() throws -> RollScansIndex {
        try #require(RollScansIndexStore.shared, "roll-scans-index.json must be bundled")
    }

    /// The join the whole feature rests on, measured against both shipped bundles.
    @Test("Almost every bundled roll finds its scan by NAID")
    func rollsJoinToScans() throws {
        let scans = try index()
        let central = try #require(CentralFilesIndexStore.shared)
        let rolls = central.numericalFile.rolls
        #expect(rolls.count > 1_000, Comment(rawValue: "only \(rolls.count) rolls"))
        let joined = rolls.filter { scans.scan(forNaId: $0.naId) != nil }.count
        let rate = Double(joined) / Double(rolls.count)
        #expect(rate > 0.95,
                Comment(rawValue: "join rate fell to \(joined)/\(rolls.count) — did a harvest change?"))
    }

    /// The first roll, end to end: the bundle names it, the scan index opens it.
    @Test("A known roll resolves to its microfilm PDF")
    func knownRollHasItsPDF() throws {
        let scan = try #require(try index().scan(forNaId: "19086784"))
        #expect(scan.objectFilename == "M862_Roll1.pdf")
        #expect(scan.objectCount == 1172)
        #expect(scan.rollPDFURL != nil)
    }

    /// Same rule as the decimal ranges: a direct link only for a whole-roll PDF, because a
    /// `.tif` object URL is the first image of the unit and one frame of a thousand is worse
    /// than the viewer holding all of them.
    @Test("Only whole-roll PDFs get a direct link")
    func onlyPDFsLinkDirectly() throws {
        for scan in try index().scans {
            let isPDF = (scan.objectFilename ?? "").lowercased().hasSuffix(".pdf")
            #expect((scan.rollPDFURL != nil) == isPDF,
                    Comment(rawValue: "\(scan.naId) \(scan.objectFilename ?? "-")"))
            #expect(scan.objectCount > 0, Comment(rawValue: "\(scan.naId) has no images"))
        }
    }

    /// The 43 rolls the harvest has no record for are not an error to hide: the row keeps its
    /// catalog link and offers no PDF, which is the honest state rather than a missing one.
    @Test("A roll with no scan still presents its catalog link")
    func unjoinedRollStillPresents() throws {
        let central = try #require(CentralFilesIndexStore.shared)
        let scans = try index()
        let unjoined = central.numericalFile.rolls.first { scans.scan(forNaId: $0.naId) == nil }
        let roll = try #require(unjoined, "no unjoined roll — the fixture assumption changed")
        let presentation = DigitizedScanPresentation(roll: roll, scan: nil)
        #expect(presentation.catalogURL != nil)
        #expect(presentation.pdfURL == nil)
        #expect(presentation.pdfLabel == nil)
        #expect(presentation.objectCount == 0)
    }

    /// The presentation is what stops the two platforms drifting; both routes must build one.
    @Test("Both scan routes build the same presentation type")
    func bothRoutesUseThePresentation() throws {
        let central = try #require(CentralFilesIndexStore.shared)
        let roll = try #require(central.numericalFile.rolls.first)
        let fromRoll = DigitizedScanPresentation(
            roll: roll, scan: try index().scan(forNaId: roll.naId))
        #expect(fromRoll.title == roll.title)

        let range = try #require(DigitizedRangeIndexStore.shared?.ranges.first)
        let fromRange = DigitizedScanPresentation(range)
        #expect(fromRange.title == range.title)
        #expect(fromRange.objectCount == range.objectCount)
    }

    /// Both views must render rolls through the shared row, or the pre-1910 section quietly
    /// keeps its old catalog-link-only treatment on one platform.
    @Test("Both views give rolls the shared scan row")
    func bothViewsUseTheSharedRow() throws {
        for path in ["FRUSExplorer/SourceExplorer/SourceExplorerView.swift",
                     "FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift"] {
            let root = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
            let text = try String(contentsOf: root.appending(path: path), encoding: .utf8)
            #expect(text.contains("DigitizedScanPresentation("),
                    Comment(rawValue: "\(path) never builds the shared presentation"))
            #expect(text.contains("RollScansIndexStore.shared?.scan(forNaId:"),
                    Comment(rawValue: "\(path) never looks up a roll's scan"))
            #expect(text.contains("digitizedScanRow("),
                    Comment(rawValue: "\(path) does not render through the shared row"))
        }
    }
}
