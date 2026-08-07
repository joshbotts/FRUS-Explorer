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

// MARK: - ManuscriptRepositoryGuidanceTests

/// Repository-level guidance for citations the National Archives cannot answer (#354 item 4).
///
/// ## Why the fixtures are verbatim corpus notes
/// The table is keyed on what `CollectionKeying.canonicalRepository` and `normalized` make of
/// the repository the **parser** extracts — three pieces of shipped code between a source note
/// and an entry, none of them connected by the type system. A synthetic `"Naval Historical
/// Center"` string tests none of that chain. So every reachability fixture below is a real
/// note, taken verbatim from the corpus, and driven through the real parser.
///
/// That chain is not hypothetical. `canonicalRepository("Naval Historical Center")` returns
/// **`Naval Historical`** — it drops the last word — so a key written out by hand would have
/// missed all 55 of that repository's documents, silently. `NavalHistoricalCenterKeyIsFolded`
/// exists to pin exactly that.
///
/// ## Why the negative test matters as much
/// This table must never answer for a repository NARA *does* administer. A Truman Library
/// citation that got "here is where these records are, outside the National Archives" would be
/// a confident, wrong redirection away from the catalogue that really holds them.
///
/// Version history:
///   1.0 — Session 2026-08-07: #354 item 4
@Suite("Manuscript repository guidance")
struct ManuscriptRepositoryGuidanceTests {

    private let parser = SourceNoteParser()

    /// The guidance a real source note reaches through the real parser, or `nil`.
    private func guidance(_ note: String) -> ManuscriptRepositoryGuidance.Entry? {
        guard case .presidentialLibrary(let library, _, _) = parser.parse(note) else { return nil }
        return ManuscriptRepositoryGuidance.guidance(forRepository: library)
    }

    /// The repository the parser extracts, for failure messages.
    private func repository(_ note: String) -> String? {
        if case .presidentialLibrary(let library, _, _) = parser.parse(note) { return library }
        return nil
    }

    // MARK: - Reachability through the real parser

    /// One verbatim corpus note per curated repository. Between them these cover **564 of the
    /// 565** documents that reached no guidance at all before this change.
    static let corpusNotes: [(note: String, expectedName: String)] = [
        ("Read-out of disarmament meeting with the President. Confidential. 1 p. National Defense University, Taylor Papers, T–37–71.",
         "National Defense University Library"),
        ("Source: National Defense university, Taylor Papers, T-646-71. Top secret.",
         "National Defense University Library"),
        ("Source: Library of Congress Manuscript Division, Harriman Papers, Kennedy and Johnson Administrations, Far East General. Secret.",
         "Library of Congress, Manuscript Division"),
        ("Source: Center of Military History, Abrams Papers, Messages, No. 2058. Top Secret; Eyes Only.",
         "U.S. Army Center of Military History"),
        ("Source: Naval Historical Center, Anderson Papers, Diary. Top Secret.",
         "Naval History and Heritage Command"),
        ("Source: Minnesota Historical Society, Mondale Papers, Vice Presidential Papers, Foreign Policy Material.",
         "Minnesota Historical Society"),
        ("Source: Princeton University, H. Alexander Smith papers",
         "Princeton University Library"),
        ("Princeton University Library, Herman Phleger papers",
         "Princeton University Library"),
        ("Hoover Institution, Williams Papers",
         "Hoover Institution Library & Archives"),
        ("the Hoover Institution, Stanford University",
         "Hoover Institution Library & Archives"),
        ("Source: University of Montana, Mansfield Library, Mansfield Papers, Series 13, Box 69, Vietnam. No classification marking.",
         "Maureen and Mike Mansfield Library, University of Montana"),
        ("Source: University of Montana Library, Mansfield Papers, Box 105, Folder 19. Unclassified.",
         "Maureen and Mike Mansfield Library, University of Montana"),
        ("Source: Yale University, Bowles Papers, Box 300, Mansfield, Folder 536. No classification marking.",
         "Manuscripts and Archives, Yale University Library"),
        ("Improvement needed in administration of foreign policy. No classification marking. 7 pp. Yale University Library, Bowles Papers, Box 300, Folder 536.",
         "Manuscripts and Archives, Yale University Library"),
        ("Source: University of Arkansas Libraries, Special Collections Division, Bureau of Educational and Cultural Affairs Historical Collection ( CU ), MC 468.",
         "University of Arkansas Libraries"),
        ("Source: Columbia University, Harriman Papers, Bowles , Chester . Confidential; Personal—No Distribution.",
         "Columbia University Libraries"),
        ("Source: Massachusetts Historical Society, Henry Cabot Lodge II Papers, Reel 9. No classification marking.",
         "Massachusetts Historical Society"),
        ("Source: Michigan State University, Hannah Papers, H, Viet. fr., 1962.",
         "Michigan State University Archives"),
    ]

    @Test("Every curated repository is reachable from a real corpus note")
    func corpusNotesReachGuidance() {
        for (note, expected) in Self.corpusNotes {
            let hit = guidance(note)
            #expect(hit?.name == expected,
                    Comment(rawValue: """
                            got \(hit?.name ?? "nil") (repository "\(repository(note) ?? "no library parse")") \
                            for: \(note.prefix(70))
                            """))
        }
    }

    /// The corpus writes the Military History Institute four ways across 13 documents, and
    /// `canonicalRepository` folds none of them together — the only entry that needs explicit
    /// aliases, and the only one where dropping them loses documents silently.
    @Test("All four Military History Institute spellings reach one entry")
    func militaryHistoryInstituteSpellingsFold() {
        for note in [
            "Source: U.S. Army Military History Institute, William C. Westmoreland Papers, History File 25. Top Secret.",
            "Source: U.S. Army Military Historical Institute, Kraemer Papers, Vietnam. Secret; Routine.",
            "Source: U.S. Military History Institute, Johnson Papers, Close Hold File No. 3. Top Secret.",
            "Source: USAMHI , Kraemer Papers, VN 61 63. Confidential, Noforn/Continued Control.",
        ] {
            #expect(guidance(note)?.name == "U.S. Army Heritage and Education Center",
                    Comment(rawValue: "got \(guidance(note)?.name ?? "nil") for: \(note.prefix(60))"))
        }
    }

    /// The key that a hand-written table would have got wrong.
    ///
    /// `canonicalRepository("Naval Historical Center")` drops the final word and returns
    /// `Naval Historical`. The table folds its spellings through the real normalizer for
    /// exactly this reason; this test fails the moment someone "simplifies" that to a literal.
    @Test("The Naval Historical Center folds through the real normalizer")
    func navalHistoricalCenterKeyIsFolded() {
        #expect(CollectionKeying.canonicalRepository("Naval Historical Center") == "Naval Historical",
                "fixture guard: the canonicaliser no longer drops the word, so this test is moot")
        #expect(ManuscriptRepositoryGuidance
            .guidance(forRepository: "Naval Historical Center")?.name
                == "Naval History and Heritage Command")
    }

    // MARK: - What must not reach guidance

    /// A repository the National Archives administers must get no answer from this table.
    /// Redirecting a Truman citation away from the catalogue that holds it would be worse
    /// than saying nothing.
    @Test("NARA-administered repositories get no outside guidance")
    func naraRepositoriesGetNoGuidance() {
        for repository in [
            "Truman Library", "Johnson Library", "Kennedy Library", "Carter Library",
            "Reagan Library", "Ford Library", "Eisenhower Library", "Nixon Presidential Materials",
            "National Archives", "Hoover Library",
        ] {
            #expect(ManuscriptRepositoryGuidance.guidance(forRepository: repository) == nil,
                    Comment(rawValue: "\(repository) was given outside-NARA guidance"))
            #expect(NARACustody.mayQueryCatalog(forRepository: repository),
                    Comment(rawValue: "fixture guard: \(repository) must be NARA-administered"))
        }
    }

    /// The Herbert Hoover Presidential Library and the Hoover Institution at Stanford are
    /// different bodies with confusingly similar names. `NARACustody` already draws that line;
    /// this table must draw it the same way or the two guards disagree.
    @Test("The Hoover Library and the Hoover Institution stay distinct")
    func hooverLibraryIsNotTheHooverInstitution() {
        #expect(ManuscriptRepositoryGuidance.guidance(forRepository: "Hoover Library") == nil)
        #expect(ManuscriptRepositoryGuidance.guidance(forRepository: "Hoover Institution") != nil)
    }

    /// An empty or absent repository is not a lookup.
    @Test("An absent repository yields no guidance")
    func absentRepositoryYieldsNothing() {
        #expect(ManuscriptRepositoryGuidance.guidance(forRepository: nil) == nil)
        #expect(ManuscriptRepositoryGuidance.guidance(forRepository: "") == nil)
        #expect(ManuscriptRepositoryGuidance.guidance(forRepository: "   ") == nil)
    }

    // MARK: - The table's own contract

    /// Every entry says how its destination was checked, and the two that could not be fetched
    /// are named here.
    ///
    /// The National Defense University and the Center of Military History sit behind a
    /// Department of Defense filter that returns `403` to **every** path, invented ones
    /// included — so a fetch cannot discriminate a real page from a wrong one there. Pinning
    /// the pair means adding a third unverified destination has to be a deliberate edit to
    /// this test rather than something that slips in.
    @Test("Exactly two destinations are unfetchable, and they are the known two")
    func unverifiedDestinationsAreTheKnownTwo() {
        let unfetched = ManuscriptRepositoryGuidance.entries
            .filter { $0.verification == .searchIndex }
            .map(\.name)
            .sorted()
        #expect(unfetched == ["National Defense University Library",
                              "U.S. Army Center of Military History"],
                Comment(rawValue: "unfetched destinations changed: \(unfetched)"))
    }

    /// Every destination is an absolute HTTPS URL. A relative or plain-HTTP one would be a
    /// broken or downgraded link on a screen whose whole job is pointing somewhere real.
    @Test("Every destination is an absolute HTTPS URL")
    func destinationsAreHTTPS() {
        for entry in ManuscriptRepositoryGuidance.entries {
            let url = try? #require(entry.url, Comment(rawValue: "\(entry.name) has no destination"))
            #expect(url?.scheme == "https", Comment(rawValue: "\(entry.name): \(url?.absoluteString ?? "nil")"))
            #expect(url?.host?.isEmpty == false, Comment(rawValue: "\(entry.name) has no host"))
        }
    }

    /// The two renames, which are the most useful thing this table carries: a researcher
    /// searching under the citation's own spelling finds nothing at either institution.
    @Test("The two renamed repositories carry their former names")
    func renamedRepositoriesNameTheOldForm() {
        let renamed = ManuscriptRepositoryGuidance.entries
            .filter { $0.formerName != nil }
            .map { "\($0.formerName!) → \($0.name)" }
            .sorted()
        #expect(renamed == [
            "Naval Historical Center → Naval History and Heritage Command",
            "U.S. Army Military History Institute → U.S. Army Heritage and Education Center",
        ], Comment(rawValue: "renames changed: \(renamed)"))
    }

    /// No two entries claim the same lookup key — a duplicate would silently shadow whichever
    /// entry the table happened to build second.
    @Test("No spelling is claimed by two entries")
    func spellingsAreUnambiguous() {
        var seen: [String: String] = [:]
        for entry in ManuscriptRepositoryGuidance.entries {
            for spelling in entry.spellings {
                guard let canonical = CollectionKeying.canonicalRepository(spelling) else {
                    Issue.record(Comment(rawValue: "\(entry.name): \"\(spelling)\" canonicalises to nil"))
                    continue
                }
                let key = CollectionKeying.normalized(canonical)
                #expect(seen[key] == nil,
                        Comment(rawValue: "key \"\(key)\" claimed by \(seen[key] ?? "") and \(entry.name)"))
                seen[key] = entry.name
            }
        }
    }

    /// Every entry is reachable from at least one of its own declared spellings. A spelling
    /// that canonicalises to nothing would make an entry dead weight.
    @Test("Every entry is reachable from its own spellings")
    func everyEntryIsReachable() {
        for entry in ManuscriptRepositoryGuidance.entries {
            for spelling in entry.spellings {
                #expect(ManuscriptRepositoryGuidance.guidance(forRepository: spelling)?.name == entry.name,
                        Comment(rawValue: "\(entry.name) unreachable from its own spelling \"\(spelling)\""))
            }
        }
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

    /// Both views must reach the table.
    ///
    /// A source audit, with the limits that implies: it detects the call being removed or
    /// renamed — the realistic regression, and one that everything above stays green through —
    /// and it does not detect the surrounding condition being changed to something wrong.
    @Test("Both views reach the repository guidance")
    func bothViewsReachTheGuidance() throws {
        for path in Self.views {
            let text = try Self.source(path)
            #expect(text.contains("ManuscriptRepositoryGuidance.guidance(forRepository:"),
                    Comment(rawValue: """
                            \(path) never looks up the repository guidance — the 564 documents \
                            citing a non-NARA repository are told only where their records are not.
                            """))
            #expect(text.contains("guidance.holdings"),
                    Comment(rawValue: "\(path) never renders what the repository holds"))
            #expect(text.contains("guidance.formerName"),
                    Comment(rawValue: """
                            \(path) drops the former name — a researcher searching the Naval \
                            Historical Center or the Army Military History Institute under the \
                            name in the citation finds nothing at the institution that now holds \
                            the records.
                            """))
        }
    }
}
