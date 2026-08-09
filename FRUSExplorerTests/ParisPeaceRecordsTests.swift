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

// MARK: - ParisPeaceRecordsTests

/// The offline resolution for `Paris Peace Conf.` citations (#354 item 3).
///
/// ## What the suite is actually guarding
/// Two different failures, and they need different kinds of test.
///
/// **The panel disappearing.** Nothing in the type system connects
/// `SourceNoteParser.tryParisPeaceConference`'s literal `"RG-256"` to
/// `ParisPeaceRecords.applies`. Spell one of them differently and 1,547 documents lose
/// their resolution with no compile error and no other failing test. So the reachability
/// tests drive the **real parser** on **verbatim corpus notes** — all five spellings the
/// corpus actually uses, censused over the 1,547 — rather than constructing a
/// `ParsedSourceNote` by hand, which would pass no matter what the parser emits.
///
/// **The panel appearing where it must not.** These identifiers are true of RG 256 and
/// false of the 192,128 RG-59 central-file documents beside them. `frus1926v01/d360` cites
/// `723.2515/2749` and `frus1919Parisv01/d415` cites `Paris Peace Conf. 723.2515/4` — the
/// *same decimal class* in two different record groups. The discriminator is the prefix,
/// never the number, and the paired test pins that it stays so.
///
/// ## The identifiers
/// All five NAIDs were verified by hand against the live NARA Catalog on 2026-08-07 (see
/// `ParisPeaceRecords`'s provenance note for what each check returned). They are pinned
/// here as literals because a typo in an archival identifier is this project's worst
/// defect class: it does not fail, it sends a researcher somewhere real and wrong.
///
/// Version history:
///   1.0 — Session 2026-08-07: #354 item 3
@Suite("Paris Peace Conference records")
struct ParisPeaceRecordsTests {

    private let parser = SourceNoteParser()

    /// The record group the real parser assigns to a note, or `nil` if it did not classify
    /// the note as a central-file citation at all.
    private func recordGroup(_ note: String) -> String? {
        if case .centralFiles(let rg, _) = parser.parse(note) { return rg }
        return nil
    }

    /// Whether a note reaches the Paris Peace panel through the real parser.
    private func reachesPanel(_ note: String) -> Bool {
        guard let rg = recordGroup(note) else { return false }
        return ParisPeaceRecords.applies(recordGroup: rg)
    }

    // MARK: - Reachability through the real parser

    /// Every spelling the corpus uses, verbatim. Censused over all 1,547 RG-256 notes:
    /// `Paris Peace Conf.` 1,455 · `Paris Peace Conference` 89 · `Paris peace Conf.` 1 ·
    /// `Paris Peace Conf` 1 · `paris Peace Conf.` 1.
    @Test("Every corpus spelling reaches the panel")
    func corpusSpellingsReachThePanel() {
        for note in [
            "Paris Peace Conf. 182/1",
            "Paris Peace Conference 184.01202/44½",
            "Paris peace Conf. 184.44/1",
            "Paris Peace Conf 180.03401/134",
            "paris Peace Conf. 180.03401/88",
        ] {
            #expect(reachesPanel(note),
                    Comment(rawValue: "got \(recordGroup(note) ?? "no central-file parse") for: \(note)"))
        }
    }

    /// A trailing document-type clause is the corpus's commonest variation (74 of the
    /// 1,547 notes run past 40 characters, nearly all of them `: Telegram`).
    @Test("A note with a trailing clause still reaches the panel")
    func trailingClauseStillReaches() {
        #expect(reachesPanel("Paris Peace Conf. 183.9 Brazil/2: Telegram"))
    }

    // MARK: - What must not reach the panel

    /// The pair that shows the discriminator is the prefix and not the number: one decimal
    /// class, two record groups, two different bodies of records.
    @Test("The same decimal class in RG 59 does not reach the panel")
    func sameDecimalClassInRG59IsRefused() {
        #expect(reachesPanel("Paris Peace Conf. 723.2515/4: Telegram"),
                "fixture guard: the RG-256 half of the pair must reach the panel")
        #expect(!reachesPanel("723.2515/2749"),
                "an RG-59 citation was offered the American Commission's records")
    }

    /// Real RG-59 central-file notes spanning the corpus's filing eras. These are the
    /// 192,128 documents the panel must stay away from.
    @Test("RG-59 central-file citations do not reach the panel")
    func rg59CitationsAreRefused() {
        for note in [
            "57013/1.",
            "851.5151/1730: Telegram",
            "851.20/1–2745",
            "601.6411/2–551: Telegram",
        ] {
            #expect(!reachesPanel(note),
                    Comment(rawValue: "RG-59 note reached the Paris Peace panel: \(note)"))
        }
    }

    // MARK: - The gate itself

    /// `applies` is called with whatever the caller holds, and the two views normalise
    /// record groups for display, so the spaced and bare forms are accepted too.
    @Test("applies accepts the parser's form and both display forms")
    func appliesAcceptsDisplaySpellings() {
        #expect(ParisPeaceRecords.applies(recordGroup: "RG-256"))
        #expect(ParisPeaceRecords.applies(recordGroup: "RG 256"))
        #expect(ParisPeaceRecords.applies(recordGroup: "256"))
        #expect(ParisPeaceRecords.applies(recordGroup: " RG-256 "))
    }

    /// The match is on the whole number, not a prefix or a substring of one. `25` and
    /// `2560` are the two ways a loosened comparison goes wrong, and neither is a record
    /// group these citations belong to.
    @Test("applies refuses every other record group")
    func appliesRefusesOthers() {
        for rg in ["RG-59", "RG 59", "59", "", "25", "2560", "RG-256A", "RG-84", "RG-218"] {
            #expect(!ParisPeaceRecords.applies(recordGroup: rg),
                    Comment(rawValue: "\(rg) was accepted as the American Commission's record group"))
        }
    }

    // MARK: - The identifiers

    /// Hand-verified against the live catalog. A wrong digit here is a working link to the
    /// wrong records, which is worse than no link.
    @Test("The catalog identifiers are the verified ones")
    func identifiersAreVerified() {
        #expect(ParisPeaceRecords.recordGroup.naId == "583")
        #expect(ParisPeaceRecords.recordGroup.title
                == "Records of the American Commission to Negotiate Peace")

        #expect(ParisPeaceRecords.series.naId == "638859")
        #expect(ParisPeaceRecords.series.title == "General Records")

        #expect(ParisPeaceRecords.indexSeries.naId == "638858")
        #expect(ParisPeaceRecords.classificationManual.naId == "638805")
        #expect(ParisPeaceRecords.keyToRecords.naId == "638831")
    }

    /// RG 256 holds **two** series titled `General Records`; the other (`2922342`) is the
    /// Greene Mission to Finland, Estonia, Latvia and Lithuania, which these citations
    /// never refer to. Resolving this series by title would be ambiguous, so it is pinned
    /// by identifier — and this test says out loud which one is wrong.
    @Test("The series is the decimal file, not the other General Records")
    func seriesIsNotTheGreeneMission() {
        #expect(ParisPeaceRecords.series.naId != "2922342")
    }

    /// Every link the panel offers is a canonical catalog record URL.
    @Test("Every record builds a canonical catalog URL")
    func catalogURLsAreCanonical() {
        let all = [ParisPeaceRecords.recordGroup, ParisPeaceRecords.series]
            + ParisPeaceRecords.findingAids
        for record in all {
            #expect(record.catalogURL?.absoluteString
                    == "https://catalog.archives.gov/id/\(record.naId)",
                    Comment(rawValue: "bad URL for \(record.title)"))
            // Computed outside `#expect`: the macro cannot prove `allSatisfy`'s `rethrows`
            // is non-throwing here and rejects the call as unhandled.
            let isNumeric = record.naId.allSatisfy { $0.isNumber }
            #expect(isNumeric,
                    Comment(rawValue: "non-numeric NAID for \(record.title): \(record.naId)"))
        }
    }

    /// The three aids the series' own `findingAids` field names, in the order a researcher
    /// needs them, with no duplicate of the series itself.
    @Test("The finding aids are the series' own three, deduplicated")
    func findingAidsAreTheSeriesOwn() {
        #expect(ParisPeaceRecords.findingAids.map(\.naId) == ["638805", "638858", "638831"])
        let ids = Set(ParisPeaceRecords.findingAids.map(\.naId))
        #expect(ids.count == 3, "a finding aid is listed twice")
        #expect(!ids.contains(ParisPeaceRecords.series.naId), "the series is listed as its own finding aid")
        #expect(!ids.contains(ParisPeaceRecords.recordGroup.naId), "the record group is listed as a finding aid")
    }

    // MARK: - Wording

    /// The roll caveat is the panel's whole reason for existing in this shape: the file
    /// units overlap and cannot be adjudicated from the harvest, so the panel must say it
    /// does not know which one holds the document. A caveat that stops saying so turns an
    /// honest section into an implied claim.
    @Test("The roll note declines to name a roll")
    func rollNoteDeclinesToNameARoll() {
        let note = ParisPeaceRecords.rollNote
        #expect(note.localizedCaseInsensitiveContains("does not say which one holds this document"),
                "the roll caveat no longer says the roll is unidentified: \(note)")
        #expect(note.contains("M820"), "the microfilm publication is no longer named")
    }

    /// The provenance note is what tells the researcher the RG-59 finding aids they may
    /// have seen elsewhere in this app do not describe these records.
    @Test("The provenance note distinguishes RG 256 from the State Department file")
    func provenanceNoteNamesTheDistinction() {
        let note = ParisPeaceRecords.provenanceNote
        #expect(note.contains("256"))
        #expect(note.contains("RG 59"))
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

    /// Both views must actually reach the panel.
    ///
    /// **What this test can and cannot do.** Everything above pins the data and the gate,
    /// and every one of those assertions still passed when the iOS call site was deleted
    /// outright — measured, not assumed. So without this test the PR's entire subject
    /// (1,547 documents getting a panel) has no guard at all.
    ///
    /// It is a source audit, and a source audit is a *presence* check: it detects the call
    /// being removed or renamed, which is the realistic regression, and it does **not**
    /// detect the surrounding condition being changed to something wrong. The same
    /// limitation was measured on this file's neighbour — flipping `||` to `&&` in
    /// `MacSourceExplorerView`'s manual-search escape hatch leaves
    /// `PresidentialLibraryOutcomeTests` entirely green. Proving behaviour would take a UI
    /// test; this proves the wiring exists.
    @Test("Both views reach the Paris Peace panel")
    func bothViewsReachThePanel() throws {
        for path in Self.views {
            let text = try Self.source(path)
            #expect(text.contains("ParisPeaceRecords.applies(recordGroup:"),
                    Comment(rawValue: """
                            \(path) never gates on the Paris Peace record group — the 1,547 \
                            `Paris Peace Conf.` citations get no offline resolution.
                            """))
            #expect(text.contains("ParisPeaceRecords.series"),
                    Comment(rawValue: "\(path) never renders the series that holds the records"))
            #expect(text.contains("ParisPeaceRecords.rollNote"),
                    Comment(rawValue: """
                            \(path) renders the Paris Peace records without the roll caveat — \
                            naming the series without saying the roll is unidentified reads as \
                            a claim the panel cannot support.
                            """))
        }
    }

    /// The macOS `.centralFiles` branch must not send RG 256 to the RG-59 period box.
    ///
    /// This is the correctness half of the change: before #354 that branch bound `_` for the
    /// record group and routed every central-file note through `centralFilesPeriodBox`, so a
    /// Paris Peace citation was offered the State Department's finding aids and filing
    /// manual — a different record group with a different filing system.
    @Test("macOS routes RG 256 away from the RG-59 period box")
    func macDoesNotSendRG256ToThePeriodBox() throws {
        let text = try Self.source("FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift")
        let branch = try #require(
            text.range(of: "case .centralFiles("),
            Comment(rawValue: "the macOS central-files dispatch branch moved — update this test"))
        let periodBox = try #require(
            text.range(of: "centralFilesPeriodBox(", range: branch.upperBound..<text.endIndex),
            Comment(rawValue: "the macOS period box is gone — update this test"))
        #expect(text[branch.upperBound..<periodBox.lowerBound].contains("ParisPeaceRecords.applies"),
                """
                MacSourceExplorerView reaches centralFilesPeriodBox from the .centralFiles \
                branch without excluding RG 256, so Paris Peace citations are offered the \
                RG 59 decimal-file finding aids and filing manual.
                """)
    }
}
