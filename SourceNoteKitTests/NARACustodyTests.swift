// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
@testable import SourceNoteKit

// MARK: - NARACustodyTests

/// Pins the allow-list that decides whether the NARA catalogue may be queried at all (#681).
///
/// Measured over the corpus: 28,456 presidential-library documents name a repository the
/// National Archives administers, and **1,961 do not** — the Library of Congress (1,060), the
/// National Defense University (242), the Center of Military History (69), the Naval Historical
/// Center (55), and a tail of universities, historical societies and mis-parses. For those the
/// catalogue has no record to find, so the free-text query it used to run returned noise
/// rendered as up to three confident results.
///
/// Version history:
///   1.0 — Session 2026-08-06: #681
@Suite("NARACustody — which repositories the catalogue may be asked about")
struct NARACustodyTests {

    @Test("Every NARA-administered presidential library may be queried")
    func naraLibrariesMayBeQueried() {
        for repository in ["Hoover Library", "Roosevelt Library", "Truman Library",
                           "Eisenhower Library", "Kennedy Library", "Johnson Library",
                           "Nixon Presidential Materials", "Ford Library", "Carter Library",
                           "Reagan Library", "Bush Library", "National Archives"] {
            #expect(NARACustody.custody(ofRepository: repository) == .nara,
                    Comment(rawValue: "\(repository) is NARA-administered"))
        }
        // FRUS's fuller spellings reach the same entries through the shared normalizer.
        for repository in ["Harry S. Truman Library", "John F. Kennedy Library",
                           "Dwight D. Eisenhower Library", "Lyndon B. Johnson Library"] {
            #expect(NARACustody.custody(ofRepository: repository) == .nara,
                    Comment(rawValue: "\(repository) did not canonicalise onto the allow-list"))
        }
    }

    /// The measured population, by document count. Each of these had catalogue rows rendered
    /// for it, and there was no right row to render.
    @Test("Repositories outside NARA are refused")
    func outsideRepositoriesAreRefused() {
        for repository in ["Library of Congress",           // 1,060 documents
                           "Department of State",           //   380
                           "National Defense University",   //   242
                           "Center of Military History",    //    69
                           "Naval Historical Center",       //    55
                           "Minnesota Historical Society",
                           "Princeton University", "Yale University", "Stanford University",
                           "University of Montana", "Massachusetts Historical Society",
                           "U.S. Army Military History Institute"] {
            #expect(NARACustody.custody(ofRepository: repository) == .outside,
                    Comment(rawValue: "\(repository) is not part of the National Archives"))
        }
    }

    /// The sharpest name collision in the list: the **Hoover Institution** at Stanford is not
    /// the **Herbert Hoover Presidential Library**. Matching the bare surname would admit it,
    /// and every catalogue row shown for a Hoover Institution citation would be wrong.
    @Test("The Hoover Institution is not the Hoover Library")
    func hooverInstitutionIsNotTheHooverLibrary() {
        #expect(NARACustody.custody(ofRepository: "Hoover Library") == .nara)
        #expect(NARACustody.custody(ofRepository: "Hoover Institution") == .outside)
        #expect(NARACustody.custody(ofRepository: "Hoover Institution on War, Revolution and Peace")
                == .outside)
    }

    /// Not every `.presidentialLibrary` parse names a repository. `NSC 5906` and
    /// `National Security Council Files` are mis-parses, and querying the catalogue on them
    /// returns whatever the free text happens to match.
    @Test("A mis-parse is not a repository")
    func misParsesAreRefused() {
        for junk in ["NSC 5906", "National Security Council Files", "National Security Council",
                     "", "   "] {
            #expect(NARACustody.custody(ofRepository: junk) == .outside,
                    Comment(rawValue: "\"\(junk)\" is not a repository"))
        }
        #expect(NARACustody.custody(ofRepository: nil) == .outside)
    }

    /// The allow-list must not be widened by accident: an unrecognised name defaults to
    /// refused, which is the safe direction. A NARA repository missing from the list loses a
    /// query that had no acceptance test anyway; a non-NARA repository admitted by mistake
    /// renders results that are wrong by construction.
    @Test("An unrecognised repository defaults to refused")
    func unrecognisedDefaultsToRefused() {
        #expect(NARACustody.custody(ofRepository: "Institute of Contemporary Papers") == .outside)
        #expect(NARACustody.mayQueryCatalog(forRepository: "Some Other Archive") == false)
        #expect(NARACustody.mayQueryCatalog(forRepository: "Truman Library"))
    }
}
