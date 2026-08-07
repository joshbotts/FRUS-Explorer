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

// MARK: - LibraryKeywordScopeTests

/// Where a presidential library may be named for the citation to be *about* it (#353 §3.2),
/// and what part of the note its name is taken from (#353 §3.3).
///
/// `tryPresidentialLibrary` matched a repository keyword **anywhere** in a note and built the
/// repository name from **everything before it**. Both halves misfire on the same two shapes:
/// a library named in a secondary-copy clause, and a citation that follows a prose abstract.
///
/// Measured against `v2`: **382 documents reclassified** — 364 to `centralFiles`, 8 to
/// `namedFileSeries`, 10 to `unrecognized` — and **457 repository names repaired**, from up to
/// 150 characters of abstract prose down to the name. That second number is not cosmetic: the
/// value is the archival-neighbour key and the string Source Explorer sends the catalogue, so
/// every long one keyed to itself and matched nothing.
///
/// Version history:
///   1.0 — Session 2026-08-06: #353 §3.2 / §3.3
@Suite("Library keyword scope and name extraction")
struct LibraryKeywordScopeTests {

    private let parser = SourceNoteParser()

    private func kind(_ note: String) -> String {
        switch parser.parse(note) {
        case .presidentialLibrary: return "presidentialLibrary"
        case .centralFiles: return "centralFiles"
        case .lotFile: return "lotFile"
        case .namedFileSeries: return "namedFileSeries"
        case .unrecognized: return "unrecognized"
        default: return "other"
        }
    }

    private func library(_ note: String) -> String? {
        if case .presidentialLibrary(let library, _, _) = parser.parse(note) { return library }
        return nil
    }

    // MARK: - §3.2 where the library may be named

    /// A library named in a parenthetical is a secondary copy — the principle
    /// `strippingParentheticals(_:)` states for FRC accessions and #712 applied to lot numbers.
    /// 339 documents whose own citation is a State Department decimal file were filed at a
    /// presidential library on this evidence.
    @Test("A library in a parenthetical does not capture a central-files citation")
    func parentheticalLibraryDoesNotCapture() {
        let note = """
            Source: Department of State, Central Files, 033.6141/4–556. Confidential; Priority. \
            On April 4, Dulles sent the text of this message to Eisenhower with the \
            recommendation that he approve its transmission. (Eisenhower Library, Whitman File)
            """
        #expect(kind(note) == "centralFiles")
    }

    /// The unparenthesised half of the same defect, and 139 documents more.
    @Test("A secondary-copy remark does not capture the citation")
    func secondaryCopyRemarkDoesNotCapture() {
        for note in [
            "Source: Department of State, Central Files, 611.41/3–553. Secret. Another copy is in the Johnson Library.",
            "Source: Department of State, Central Files, 611.41/3–553. Secret. A copy of the report is also at the Johnson Library.",
            "Source: Department of State, Central Files, 611.41/3–553. Secret. Copies of these documents are in Eisenhower Library.",
        ] {
            #expect(kind(note) == "centralFiles",
                    Comment(rawValue: "a duplicate's location captured the citation: \(note)"))
        }
    }

    /// The exception, and the reason the rule is keyed on content rather than position:
    /// `"Copy obtained from the … Library"` opens with the same word and means the opposite —
    /// the WWII-era idiom asserts the document's own provenance. #353 lists it as a recovery
    /// worth 296 documents, not a steal.
    ///
    /// **This branch has 0 corpus traffic today** — measured by removing it and re-running the
    /// whole corpus, which changed nothing — because the idiom appears as a *whole-note* form
    /// that reaches `tryLibraryLeadNote` and never enters `tryPresidentialLibrary`. So the test
    /// drives the branch directly, through a `Source:` note, rather than through a corpus shape
    /// that does not exist; asserting it on the whole-note form would have passed for a reason
    /// that has nothing to do with this rule.
    @Test("An \"obtained from\" clause is not stripped as a duplicate")
    func obtainedFromIsProvenanceNotADuplicate() {
        let body = "Roosevelt papers, Box 4. Copy obtained from the Franklin D. Roosevelt Library."
        #expect(SourceNoteParser.droppingSecondaryCopyClauses(body) == body,
                "\"obtained from\" asserts provenance; it must survive the strip")

        let duplicate = "Roosevelt papers, Box 4. Another copy is in the Johnson Library."
        #expect(SourceNoteParser.droppingSecondaryCopyClauses(duplicate) != duplicate,
                "a duplicate's location must be stripped")
    }

    /// Sentence 1 is never dropped, whatever it says — it carries the citation on every
    /// `Source:` form.
    @Test("A library citation that itself mentions a copy survives")
    func leadingSentenceIsNeverDropped() {
        let note = "Source: Kennedy Library, National Security Files, Countries Series, Cuba, copy 2."
        #expect(kind(note) == "presidentialLibrary")
    }

    // MARK: - §3.3 what the repository name is taken from

    /// The 1958–1963 abstract notes put the citation after a prose summary, and the old rule
    /// took everything before the keyword — so the summary became the repository name. These
    /// are correctly classified; only the field was wrong.
    @Test("An abstract prefix is not absorbed into the repository name")
    func abstractPrefixIsNotAbsorbed() {
        let note = """
            Activist exile groups. Secret. 2 pp. Kennedy Library, NSF, Countries Series, \
            Cuba—Subjects, Exile Activities.
            """
        #expect(kind(note) == "presidentialLibrary")
        #expect(library(note) == "Kennedy Library",
                "got: \(library(note) ?? "nil")")
    }

    /// The plain lead form must be unchanged by the same rule.
    @Test("A leading library citation still yields its own name")
    func leadingLibraryNameIsUnchanged() {
        #expect(library("Source: Johnson Library, National Security File, Country File, Vietnam.")
                == "Johnson Library")
    }

    /// The cut points are searched strictly **before** the keyword. Searching the whole span
    /// would cut inside `George H.W. Bush Library`, whose own name contains `". "`.
    @Test("A repository name containing a period is not cut in half")
    func nameContainingAPeriodSurvives() {
        let note = "Source: George H.W. Bush Library, Presidential Records, NSC, Box 1."
        #expect(library(note) == "George H.W. Bush Library", "got: \(library(note) ?? "nil")")
    }

    /// The direct unit on the extractor, so a caller cannot satisfy the suite by accident.
    @Test("The name segment starts after the last comma or sentence break")
    func nameSegmentCutsAtTheNearestBoundary() {
        let body = "Some abstract. Secret. 4 pp. Kennedy Library, NSF"
        let range = body.range(of: "Kennedy Library")!
        #expect(SourceNoteParser.libraryNameSegment(in: body, endingAt: range,
                                                    keyword: "Kennedy Library")
                == "Kennedy Library")

        let commaForm = "Department of State, Kennedy Library"
        let r2 = commaForm.range(of: "Kennedy Library")!
        #expect(SourceNoteParser.libraryNameSegment(in: commaForm, endingAt: r2,
                                                    keyword: "Kennedy Library")
                == "Kennedy Library")
    }
}
