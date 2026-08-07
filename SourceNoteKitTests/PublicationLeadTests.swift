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

// MARK: - PublicationLeadTests

/// Notes whose text FRUS set from a **print** rather than from an archival file (#353).
///
/// ## The two paths, which had two different answers
/// A `Source:`-prefixed note reached `matchesPreviouslyPublished` and its six leads. A bare
/// note reached a one-off `hasPrefix("Treaty Series")` in `parse()`'s tail and nothing else —
/// so the bare path recognised exactly one publication while the other recognised six, and
/// **most publication notes are bare** (measured: 331 of the 527 already classified). Both now
/// read one `previouslyPublishedLeads` list.
///
/// ## Measured
/// **356 documents**, none lost: 351 from `unrecognized`, plus 5 corrected off `centralFiles`
/// — those had matched on `"Department of State"` appearing *inside* `Department of State
/// Bulletin`, which is the publication's own name.
///
/// | lead | documents |
/// |---|---|
/// | `Reprinted from` | 196 |
/// | `Executive Agreement Series` | 102 |
/// | `Documents on Disarmament` | 19 |
/// | `The Official Bulletin` | 17 |
/// | `Issued by the White House as a press release` | 12 |
///
/// Version history:
///   1.0 — Session 2026-08-06: #353, publication leads on both note paths
@Suite("Publication leads")
struct PublicationLeadTests {

    private let parser = SourceNoteParser()

    private func isPublished(_ note: String) -> Bool {
        if case .previouslyPublished = parser.parse(note) { return true }
        return false
    }

    // MARK: - The five leads

    @Test("Each publication lead is recognized")
    func everyLeadIsRecognized() {
        for note in [
            "Reprinted from Conference on the Limitation of Armament , p. 1640.",
            "Executive Agreement Series No. 145",
            "Source: Documents on Disarmament , 1971, pp. 190–194. No classification marking.",
            "The Official Bulletin , Washington, Aug. 4, 1917 (Vol. 1, No. 73), p. 1.",
            "Issued by the White House as a press release, April 22, 1933; reprinted from Department of State, Press Releases , April 22, 1933, p. 259.",
        ] {
            #expect(isPublished(note),
                    Comment(rawValue: "publication lead not recognized: \(note.prefix(60))"))
        }
    }

    /// The bare and `Source:`-prefixed forms of the same citation must agree. They did not:
    /// the bare path knew one publication and the other knew six.
    @Test("A bare note and a Source: note reach the same answer")
    func bothPathsAgree() {
        for lead in ["Reprinted from Department of State Bulletin , July 21, 1952, pp. 92–93.",
                     "Executive Agreement Series No. 160",
                     "Treaty Series No. 762"] {
            #expect(isPublished(lead), Comment(rawValue: "bare form failed: \(lead)"))
            #expect(isPublished("Source: " + lead), Comment(rawValue: "Source: form failed: \(lead)"))
        }
    }

    /// These five were classified `centralFiles` because `matchesCentralFiles` matched
    /// `"Department of State"` **inside the publication's own title**. The note leads with
    /// `Reprinted from`; the text was set from the Bulletin.
    @Test("A Bulletin reprint is not a central-files citation")
    func bulletinReprintIsNotCentralFiles() {
        let note = """
            Source: Reprinted from the Department of State Bulletin , Sept. 13, 1954, pp. \
            363–364. The source text was issued as Department of State press release 486 on \
            Aug. 31.
            """
        #expect(isPublished(note))
        if case .centralFiles = parser.parse(note) {
            Issue.record("matched the Department's name inside the publication's title")
        }
    }

    // MARK: - What must NOT be claimed

    /// #353 lists `Unperfected Treaty No. A–10` as a publication lead. It is not one, and this
    /// is the test that keeps it from becoming one: unperfected treaties are **archival** —
    /// NARA holds them in RG 11, and `A–10` is its file designation, not a print number.
    /// Classifying those 8 documents as previously-published would send a researcher looking
    /// for a print that does not exist.
    @Test("An unperfected treaty is archival, not published")
    func unperfectedTreatyIsNotAPublication() {
        #expect(!isPublished("Unperfected Treaty No. A–10"))
        #expect(!isPublished("Unperfected Treaty No. J–10"))
    }

    /// Every lead is anchored to the head of the note. A publication *mentioned* in a remark
    /// does not make an archival citation a reprint — the head is what says where the printed
    /// text came from.
    @Test("A publication named in a remark does not claim the citation")
    func publicationInARemarkDoesNotClaim() {
        let note = """
            Source: Department of State, Central Files, 611.41/3–553. Secret. The text was \
            later reprinted from Department of State Bulletin , July 21, 1952, pp. 92–93.
            """
        #expect(!isPublished(note), "a reprint mentioned in a remark captured the citation")
    }

    /// The archival leads that share a first word with a publication must stay archival.
    @Test("Archival citations are untouched")
    func archivalCitationsAreUntouched() {
        for note in [
            "Source: Department of State, Central Files, 611.41/3–553. Secret.",
            "Source: Department of State, S/S Files: Lot 63 D 351, NSC Meetings.",
            "Source: Kennedy Library, National Security Files, Countries Series, Cuba.",
        ] {
            #expect(!isPublished(note), Comment(rawValue: "archival citation claimed: \(note)"))
        }
    }
}
