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

// MARK: - ManuscriptRepositoryBridgeTests

/// Pins lookup-order step 4's repository guard end-to-end (N-4 step 1): the **real**
/// `SourceNoteParser`, the **real** `CollectionKeying` identity derivation, and the
/// **real** bundled `collection-authority.json`, driven by the **verbatim corpus notes**
/// that were bridging.
///
/// ## Why the fixtures are corpus notes rather than synthetic strings
/// The bridge is not a hypothetical. Measured over all 266,513 `document_sources` rows,
/// seven distinct citations resolved through the global alias map to a collection held
/// by a *different* manuscript repository — an Eisenhower Library citation landing on the
/// **Carter** Library's staff-secretary cluster, and both Reagan's and Johnson's
/// "President's Daily Diary" landing on the **Library of Congress**. Every one was wrong,
/// so the guard costs no correct resolution: corpus-wide resolution moves 74,692 → 74,682
/// documents and the ten that move all go from a wrong answer to no answer.
///
/// Several of the bridges arise the same way, which a synthetic fixture would not
/// reproduce: the note's *Source* names repository A, but a cross-reference parenthetical
/// later in the note names repository B's collection, and the parser attributes the
/// parenthetical's collection under A's repository. The guard catches those too.
///
/// The suite also holds the guard's two deliberate limits — federal custody names never
/// conflict, and an absent repository never conflicts — because a wider guard silently
/// deletes correct resolutions and nothing else in the suite would notice.
///
/// Version history:
///   1.0 — Session 2026-08-05: N-4 step 1
@Suite("Collection authority — cross-repository alias bridges")
struct ManuscriptRepositoryBridgeTests {

    /// The bundled index.
    private func index() throws -> CollectionAuthorityIndex {
        try #require(CollectionAuthorityStore.shared,
                     "collection-authority.json must decode from the app bundle")
    }

    /// Resolves a raw note exactly as Source Explorer does: parse, derive identity,
    /// apply the documented lookup order.
    private func resolve(_ note: String) throws -> AuthorityCollectionRecord? {
        try index().record(forParsed: SourceNoteParser().parse(note), note: note)
    }

    // MARK: - The bridges that must close

    @Test("An Eisenhower citation never lands on the Carter Library")
    func eisenhowerDoesNotReachCarter() throws {
        let note = "Source: Eisenhower Library, Records of the Office of the Staff "
            + "Secretary, International Series. Personal and Confidential. Drafted in SEA "
            + "by Mendenhall on May 19 and cleared by Robertson ."
        // The cluster it used to reach is real and still there — only the route is gone.
        #expect(try index().record(id: "txt:carter library|records of the office of the staff secretary") != nil,
                "fixture guard: the Carter cluster must still exist, or this test proves nothing")
        #expect(try resolve(note) == nil,
                "an Eisenhower citation resolving to a Carter Library collection is a confidently-wrong archive attribution")
    }

    @Test("A President's Daily Diary citation never crosses into another library")
    func dailyDiaryDoesNotCrossRepository() throws {
        // Derived, not hardcoded: the id is a `CollectionKeying` merge key, and pinning its
        // literal spelling made this guard fail the moment the normalizer gained a fold.
        //
        // **The counterexample repository changed, and the guard is why that was noticed.** This
        // test used to name the Library of Congress. The re-clustered authority holds no
        // `library of congress|…daily diary` cluster at all — the diary clusters are the Carter,
        // Ford, Johnson and Kennedy libraries and the National Archives — so the guard correctly
        // reported that the test could no longer prove its claim: there was nothing left to cross
        // INTO. Carter is used instead, exactly as the sibling Eisenhower test does, because the
        // risk being tested is unchanged: one library's citation must never land on another
        // library's collection of the same name (#353 §3.2).
        // **No trailing paren.** The note text below ends in one (it is a cross-reference
        // parenthetical) and the original derivation copied it in — but `segmentNorm` does not
        // strip punctuation, so it yielded `presidential daily diary)` and matched no cluster at
        // all. The guard then read as "the cluster vanished" when the real answer was "the id was
        // never spelled that way". Probed, not guessed: segmentNorm("President's Daily Diary)")
        // == "presidential daily diary)".
        let otherLibraryDiary = "txt:carter library|"
            + CollectionKeying.segmentNorm("President\u{2019}s Daily Diary")
        #expect(try index().record(id: otherLibraryDiary) != nil, """
            fixture guard: a DIFFERENT library's President's Daily Diary cluster must exist, or \
            this test proves nothing — there would be no wrong answer available to resolve to.
            """)
        #expect(try resolve("Johnson Library, President’s Daily Diary)") == nil)
        #expect(try resolve("Reagan Library, President’s Daily Diary)") == nil)
    }

    @Test("A cross-reference parenthetical never attributes another library's collection")
    func parentheticalDoesNotBridge() throws {
        // Source is the Library of Congress; "Recordings and Transcripts" belongs to the
        // Johnson Library and appears only in the trailing cross-reference.
        let harriman = "Source: Library of Congress, Manuscript Division, Harriman Papers, "
            + "Special Files, Public Service, Kennedy - Johnson , Vietnam, General, "
            + "April–Dec. 1968. Top Secret; Nodis ; Personal. In a telephone conversation "
            + "2 days later, the President and Wheeler discussed the impact of the bombing "
            + "halt on the military situation in Vietnam. ( Johnson Library, Recordings and "
            + "Transcripts, Recording of Telephone Conversation Between Johnson and Wheeler , "
            + "April 28, 1968, 11:10 a.m., Tape F6804.03, PNO 3)"
        // #353 §3.2: this used to parse as `Library of Congress` + **`Recordings and
        // Transcripts`** — the right repository welded to the Johnson Library's collection out
        // of the parenthetical — and the pair resolved to nothing, which is what the original
        // `== nil` here was really observing. The parenthetical is now stripped, so the note
        // keeps its own collection and may legitimately resolve. The invariant this test is
        // named for is asserted directly on the parse, where it cannot be satisfied by an
        // unrelated lookup miss.
        if case .presidentialLibrary(let library, let collection, _) =
            SourceNoteParser().parse(harriman) {
            #expect(library == "Library of Congress")
            #expect(collection == "Manuscript Division",
                    "got \(collection) — a cross-reference collection has been attributed")
        } else {
            Issue.record("expected a manuscript-repository parse for the Harriman note")
        }

        // Source is the National Defense University; the Hilsman Papers are at Kennedy.
        let taylor = "Source: National Defense University, Taylor Papers, Vietnam, chap. "
            + "XXIII. Top Secret; Sensitive. Drafted by Krulak . The meeting was held at "
            + "the White House. A memorandum of conversation of this meeting by Hilsman is "
            + "in the Kennedy Library, Hilsman Papers, Countries, Vietnam, White House "
            + "Meetings, State Memcons."
        // Same shape, and it exposed a second defect underneath: `libraryKeywords` is a match
        // list, not a priority list, and the old loop iterated it in list order — so
        // `Kennedy Library`, listed first, was taken out of the closing remark over the
        // `National Defense University` this citation opens with. The old repository rule hid
        // it by taking the first comma segment of everything before the keyword, which is NDU,
        // so the wrong keyword produced the right repository and the wrong collection.
        if case .presidentialLibrary(let library, let collection, _) =
            SourceNoteParser().parse(taylor) {
            #expect(library == "National Defense University")
            #expect(collection == "Taylor Papers",
                    "got \(collection) — the Hilsman Papers are at the Kennedy Library")
        } else {
            Issue.record("expected a repository parse for the Taylor note")
        }
    }

    // MARK: - What the guard must NOT touch

    /// The same institution under two spellings. `canonicalRepository` falls through to
    /// the raw string outside its keyword list, so requiring equality here would refuse
    /// a correct resolution the corpus actually makes.
    @Test("One repository under two spellings still resolves")
    func princetonStillResolves() throws {
        let note = "Source: Princeton University Library, Stevenson Papers, Embassy Files, "
            + "Tunisia. No classification marking."
        #expect(try resolve(note)?.id == "txt:princeton university|stevenson paper")
    }

    /// Custody, creator and accession names for the same federal records. Treating these
    /// as conflicts refuses 179 correct resolutions — the single largest way to get this
    /// guard wrong.
    @Test("Federal custody and creator names still resolve across each other")
    func federalNamesStillResolve() throws {
        let wnrc = "Source: Washington National Records Center, RG 286, AID Administrator "
            + "Files: FRC 69 A 1866, PRM 7–1, Development Assistance Committee, FY 1966. "
            + "Confidential."
        #expect(try resolve(wnrc)?.id
                == "txt:washington national records center|aid administrator files: frc 69 a 1866")

        // A library citation reaching a Department-of-State cluster is deliberately left
        // alone: the record's repository is the creating agency, not a rival building.
        let bandow = "Source: Reagan Library, Bandow Files, Bandow Paper for the Tenth "
            + "Session of the Conference on the Law of the Sea, Feb 13, 1981. Secret. "
            + "Drafted by Wulf . Sent through Busby ."
        #expect(try resolve(bandow)?.id == "txt:department of state|bandow file")
    }

    /// The alias step's whole purpose: a citation that names no repository at all still
    /// reaches the collection the corpus attributes it to.
    @Test("A citation naming no repository still resolves through the alias step")
    func unattributedCitationStillResolves() throws {
        #expect(try resolve("Clifford Papers")?.id == "txt:johnson library|clifford paper")
    }

    /// The repository-scoped key (step 2) carries 28,537 of the 28,772 resolved
    /// library documents and is the route N-4's curated NAIDs will ride. A guard that
    /// reached it would be catastrophic rather than conservative.
    @Test("The repository-scoped key is untouched")
    func repositoryScopedKeyUnaffected() throws {
        let note = "Source: Johnson Library, National Security File, Country File, "
            + "Vietnam, Box 1. Secret."
        #expect(try resolve(note)?.id == "txt:johnson library|national security file")
        let kennedy = "Source: Kennedy Library, National Security Files, Countries Series, "
            + "China. Secret."
        #expect(try resolve(kennedy)?.id == "txt:kennedy library|national security file")
    }
}
