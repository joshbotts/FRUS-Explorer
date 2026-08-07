// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import SourceNoteKit

// MARK: - AgencyFileSeriesTests

/// File series held by an agency rather than by the National Archives (#353).
///
/// FRUS cites these as `Agency, Series, Box N, Folder`. `tryNarrativeNamedSeries` could not
/// reach them: its patterns are anchored to the start of the note and require the leading
/// segment to **end** in `Files`/`Papers`/`Records`/`Collection`, which an agency name does
/// not — so the rule never saw the series in segment 2. The tell is that the same corpus
/// classifies `National Security Council **Files**, …` correctly and
/// `National Security Council, …` not at all.
///
/// Measured: **592 documents** recovered, 504 of them NSC, every one previously
/// `unrecognized`, and **0 lost**. That second number is guaranteed by the dispatch rather
/// than merely observed — `tryAgencyFileSeries` runs last, so it can only claim notes every
/// other strategy has already declined.
///
/// Version history:
///   1.0 — Session 2026-08-06: #353, agency-held file series
@Suite("Agency-held file series")
struct AgencyFileSeriesTests {

    private let parser = SourceNoteParser()

    private func series(_ note: String) -> (name: String, fileID: String?)? {
        if case .namedFileSeries(let name, let fileID) = parser.parse(note) {
            return (name, fileID)
        }
        return nil
    }

    // MARK: - What is recovered

    /// The dominant shape, and 504 of the 592.
    @Test("An NSC citation resolves to its named series")
    func nscCitationResolves() throws {
        let hit = try #require(
            series("Source: National Security Council, Carter Intelligence Files, Box 20, SCC Meetings, 1977–1980 Minutes. Secret; Sensitive."),
            "expected a named file series")
        #expect(hit.name == "National Security Council, Carter Intelligence Files")
        #expect(hit.fileID == "Box 20")
    }

    /// The other agencies in the list, each measured in the corpus.
    @Test("Every listed agency's lead citation resolves")
    func everyAgencyResolves() {
        let notes = [
            "Source: Department of the Treasury, Office of the Secretary, Executive Secretariat, 1978 Files, 56–83–69. Confidential.",
            "Source: Defense Intelligence Agency, DIA Command Files 1970s, Box 3, DIA Command 1976. Secret; Codeword.",
            "Source: Department of Energy, Executive Secretariat Files, Job #8824, Box 3135, IA Memoranda of Conversation. Confidential.",
            "Source: Department of Commerce, Bureau of Foreign Commerce Files 321, Economic and Social Council. Administratively Restricted.",
            "Source: National Security Agency, Accession 23034, H02–0106–1, Folder 2, Correspondence–Memos concerning ELINT . Secret.",
            "Source: Department of Defense, Afghan War Collection, Box 1, Afghan Politics. Secret.",
        ]
        for note in notes {
            #expect(series(note) != nil,
                    Comment(rawValue: "unresolved agency citation: \(note.prefix(70))"))
        }
    }

    /// The agency stays at the head of the stored name. `National Security Council,
    /// Institutional Files` and another body's `Institutional Files` are different series and
    /// must not collapse onto one archival-neighbour key.
    @Test("The stored series name is qualified by its agency")
    func seriesNameKeepsItsAgency() throws {
        let hit = try #require(
            series("Source: National Security Council, Institutional Files, NSC Meetings, Box SR 105, NSC Meeting 121. Secret."))
        #expect(hit.name.hasPrefix("National Security Council, "))
        #expect(hit.name != "Institutional Files")
    }

    // MARK: - What must NOT be claimed

    /// The rule runs last precisely so it cannot outrank a real strategy. The Department of
    /// State is also absent from the agency list — a citation leading with it is a central
    /// files or lot citation, both of which have their own strategies far earlier.
    @Test("A State Department citation is untouched")
    func stateDepartmentIsNotAnAgencyLead() {
        for note in [
            "Source: Department of State, Central Files, 611.41/3–553. Secret.",
            "Source: Department of State, S/S Files: Lot 63 D 351, NSC Meetings.",
        ] {
            #expect(series(note) == nil,
                    Comment(rawValue: "a State citation was claimed as an agency series: \(note)"))
        }
    }

    /// A custodian with no series named is not a series. Inventing one from the following
    /// prose would key documents to a classification marking.
    ///
    /// An explicit marking guard was written for this and then **removed**: measured at 0
    /// documents, because cutting the segment at its first sentence break already empties it.
    /// This test is what the guard was protecting, kept after the guard went.
    @Test("An agency named with no series resolves to nothing")
    func bareAgencyIsNotASeries() {
        #expect(series("Source: Department of Defense. Secret. Drafted by Van Hollen and approved by Harris.") == nil)
        #expect(series("Source: National Security Council. Top Secret.") == nil)
    }

    /// A series name is a name, not a sentence. The length bound stops a run-on remark from
    /// becoming a key.
    @Test("An implausibly long segment is not a series name")
    func longSegmentIsRefused() {
        let runOn = "Source: National Security Council, "
            + String(repeating: "an extremely long descriptive clause ", count: 4) + "."
        #expect(series(runOn) == nil)
    }

    /// `Center For Cryptologic History. Top Secret.` names a series and then stops naming one.
    @Test("A series followed by a marking keeps only the series")
    func seriesIsCutAtTheSentenceBreak() throws {
        let hit = try #require(
            series("Source: National Security Agency, Center For Cryptologic History. Top Secret."))
        #expect(hit.name == "National Security Agency, Center For Cryptologic History")
    }
}
