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

// MARK: - CuratedLibraryResolutionsTests

/// Pins the curated library resolutions (#355 / N-4) — the first archival destinations Source
/// Explorer has ever had for a presidential-library citation.
///
/// Every library cluster in `collection-authority.json` carries `naId: nil`, and that is
/// structural rather than an oversight: presidential libraries sit outside every NARA record
/// group, so the record-group-filtered catalogue harvest cannot reach them. The destination is
/// therefore the repository's own finding aid.
///
/// ## The sub-collection level, and why it is optional
/// Measured over the corpus, two rows are containers rather than collections:
/// - **Carter / National Security Affairs**, 3,591 documents: `Brzezinski Material` 2,065
///   (57.5%) and `Staff Material` 1,444 (40.2%) — 97.7% in two branches the library describes
///   separately. One link for the row is right for at most 57% of it.
/// - **Library of Congress / Manuscript Division**, 958 documents naming **12** personal-papers
///   collections (Kissinger 745, Harriman 54, Harold Brown 30 …). The row is the division that
///   holds them, not a collection.
///
/// Everywhere else level 1 *is* the collection, so the sub-collection stays optional.
///
/// Version history:
///   1.0 — Session 2026-08-06: #355 / N-4, Carter + Library of Congress
///   1.1 — Session 2026-08-06: #355 / N-4, Ford — the two citation truncations (middle initial,
///         comma inside a series name) and one series cited at four different levels
///   1.2 — Session 2026-08-06: #355 / N-4, Nixon — read sentence 1 rather than the
///         central-files-anchored sentence, and find the series on either side of the box
///   1.3 — Session 2026-08-06: #355 / N-4, Johnson — the first entries carrying a NARA
///         identifier, plus two generic integrity guards (own-domain, well-formed naId)
///   1.4 — Session 2026-08-06: #355 / N-4, Eisenhower — the Ann Whitman File name trap, and a
///         third generic guard against aliases that can never match
///   1.5 — Session 2026-08-06: #355 / N-4, Kennedy — one aid per collection, the Herter Papers
///         held at two libraries at once, and why the series anchors are not linked
@Suite("Curated library resolutions")
struct CuratedLibraryResolutionsTests {

    private func bundled() throws -> CuratedLibraryResolutions {
        try #require(CuratedLibraryResolutionsStore.shared,
                     "curated-library-resolutions.json must decode from the app bundle")
    }

    // MARK: - Sub-collection extraction

    /// The level-2 segment has to come back out of the note: the per-document parse keeps only
    /// the level-1 collection, and the authority artifact's `children` are volume-grain
    /// vocabulary with no document linkage.
    @Test("The sub-collection is recovered from the citation")
    func subCollectionIsExtracted() {
        let carter = "Source: Carter Library, National Security Affairs, Brzezinski Material, "
            + "Subject File, Box 55, SALT , Chronology, 1/24/77–3/24/77. Secret."
        #expect(CuratedLibraryResolutions.subCollection(
            inNote: carter, afterCollection: "National Security Affairs") == "Brzezinski Material")

        let staff = "Source: Carter Library, National Security Affairs, Staff Material, Office, "
            + "Box 69, USSR : Brezhnev - Carter Correspondence, 1–2/77. No classification marking."
        #expect(CuratedLibraryResolutions.subCollection(
            inNote: staff, afterCollection: "National Security Affairs") == "Staff Material")

        let loc = "Source: Library of Congress, Manuscript Division, Kissinger Papers, "
            + "Box TS 82, NSC Meetings, Jan–Mar 1969. Top Secret."
        #expect(CuratedLibraryResolutions.subCollection(
            inNote: loc, afterCollection: "Manuscript Division") == "Kissinger Papers")
    }

    /// A box or folder is a locator, not a sub-collection. Returning `Box 17` as one would key
    /// every document separately and resolve none of them — so the locator itself is refused in
    /// **either** position, before and after the series.
    @Test("A locator is never returned as a sub-collection")
    func locatorsAreRefused() {
        for note in ["Source: Carter Library, Plains File, Box 17, Nodis.",
                     "Source: Carter Library, Plains File, Folder 3.",
                     "Source: Kennedy Library, National Security Files, Reel 12.",
                     "Source: Nixon Presidential Materials, NSC Files, Box 849, Boxes 1–4."] {
            let collection = ["Plains File", "National Security Files", "NSC Files"]
                .first { note.contains($0) } ?? ""
            let sub = CuratedLibraryResolutions.subCollection(inNote: note,
                                                              afterCollection: collection)
            #expect(sub?.range(of: #"^(Box|Boxes|Folder|Reel|Container|Lot)\b"#,
                               options: [.regularExpression, .caseInsensitive]) == nil,
                    "leaked the locator \(sub ?? "") from: \(note)")
        }
        // A citation that stops at the collection has no sub-collection at all.
        #expect(CuratedLibraryResolutions.subCollection(
            inNote: "Source: Carter Library, Plains File.", afterCollection: "Plains File") == nil)
        #expect(CuratedLibraryResolutions.subCollection(
            inNote: "Source: Carter Library, Plains File, Folder 3.",
            afterCollection: "Plains File") == nil, "nothing follows the folder")
    }

    /// The extraction must read **sentence 1**, not `SourceNoteParser.citationSentence(of:)`.
    ///
    /// This is a wiring test, and it exists because the obvious version of it is not one:
    /// `FirstSentenceTests` pins the two parser functions against each other and passes happily
    /// while `subCollection` calls the wrong one. Mutation-tested — swapping the call back to
    /// `citationSentence` leaves every other test in this suite green.
    ///
    /// The note below is a verbatim corpus shape. Its remarks cross-reference the White House
    /// Central Files, which is what `citationSentence` anchors on, so it returns the *remarks*
    /// and the sub-collection is read out of an editor's aside. Measured: 4,605 Nixon documents.
    @Test("The sub-collection is read from the citation, not from the remarks")
    func extractionReadsSentenceOne() {
        let note = "Source: National Archives, Nixon Presidential Materials, NSC Files, "
            + "Agency Files, Box 193, AID, Volume I 1969. Confidential. On May 23 Haig sent "
            + "Kissinger a memorandum in which this was the first item for Kissinger to discuss "
            + "with the President that day. (Ibid., Subject Files, Items to Discuss with the "
            + "President) Kissinger met with the President at 9:30 a.m. (Ibid., White House "
            + "Central Files, President\u{2019}s Daily Diary)"
        #expect(CuratedLibraryResolutions.subCollection(
            inNote: note, afterCollection: "NSC Files") == "Agency Files",
                "the remarks name a central file, which is what citationSentence anchors on")
    }

    /// FRUS puts the box on either side of the series, and the Nixon volumes overwhelmingly put
    /// it first. Stopping at the locator read 4,605 Nixon documents as having no series.
    @Test("The series is found on either side of the box")
    func seriesFoundEitherSideOfTheBox() {
        let seriesFirst = "Source: National Archives, Nixon Presidential Materials, NSC Files, "
            + "Kissinger Office Files, Box 1, HAK Administrative and Staff Files. Secret."
        let boxFirst = "Source: National Archives, Nixon Presidential Materials, NSC Files, "
            + "Box 849, Country Files, Latin America. Confidential."
        #expect(CuratedLibraryResolutions.subCollection(
            inNote: seriesFirst, afterCollection: "NSC Files") == "Kissinger Office Files")
        #expect(CuratedLibraryResolutions.subCollection(
            inNote: boxFirst, afterCollection: "NSC Files") == "Country Files")
    }

    // MARK: - Lookup

    @Test("A sub-collection resolves to its own finding aid")
    func subCollectionResolves() throws {
        let curated = try bundled()
        let brzezinski = curated.resolution(repository: "Carter Library",
                                            collection: "National Security Affairs",
                                            subCollection: "Brzezinski Material")
        let staff = curated.resolution(repository: "Carter Library",
                                       collection: "National Security Affairs",
                                       subCollection: "Staff Material")
        #expect(brzezinski != nil, "Brzezinski Material (2,065 documents) must resolve")
        #expect(staff != nil, "Staff Material (1,444 documents) must resolve")
        #expect(brzezinski?.findingAid != nil)
        #expect(staff?.findingAid != nil)
    }

    /// The corpus misspells the name three ways, and those are real documents.
    @Test("Sub-collection aliases and misspellings resolve to the same aid")
    func aliasesResolve() throws {
        let curated = try bundled()
        let canonical = curated.resolution(repository: "Carter Library",
                                           collection: "National Security Affairs",
                                           subCollection: "Brzezinski Material")
        // Compared on the whole resolution, not the URL. Carter's collection-wide entry shares
        // the container aid's URL, so a URL-only assertion passes even with alias matching
        // removed — the misspelling simply falls through to the collection-wide answer. The
        // rationale differs, so equality distinguishes "matched the alias" from "fell through".
        let collectionWide = curated.resolution(repository: "Carter Library",
                                                collection: "National Security Affairs",
                                                subCollection: nil)
        #expect(canonical?.url == collectionWide?.url, "fixture guard: the URLs really are shared")
        #expect(canonical != collectionWide, "fixture guard: …but the entries are distinguishable")
        for spelling in ["Brzezinski Materials", "Brzezinksi Material", "Brzezinsky Material"] {
            #expect(curated.resolution(repository: "Carter Library",
                                       collection: "National Security Affairs",
                                       subCollection: spelling) == canonical,
                    "\(spelling) must match the alias, not fall through to the collection-wide entry")
        }
    }

    /// The Reagan citations write one series both ways — `NSC Country File` and
    /// `NSC : Country File` — 76 documents turning on a punctuation mark. The fold is local to
    /// this artifact so it cannot leak into the authority keying, where a colon IS meaningful.
    @Test("A colon is a separator when matching a sub-collection")
    func colonIsASeparator() throws {
        let curated = try bundled()
        let plain = curated.resolution(repository: "Reagan Library",
                                       collection: "Executive Secretariat",
                                       subCollection: "NSC Country File")
        #expect(plain != nil, "the Reagan Country File must resolve")
        for variant in ["NSC : Country File", "NSC:Country File", "NSC Country Files"] {
            #expect(curated.resolution(repository: "Reagan Library",
                                       collection: "Executive Secretariat",
                                       subCollection: variant) == plain,
                    "\(variant) must reach the same aid")
        }
        // …and the fold must not merge genuinely different series.
        #expect(curated.resolution(repository: "Reagan Library",
                                   collection: "Executive Secretariat",
                                   subCollection: "NSC Head of State File") != plain)
    }

    /// Nixon writes the same level with `and` and with `&`.
    @Test("Ampersand and 'and' reach the same Nixon sub-series")
    func ampersandFolds() throws {
        let curated = try bundled()
        let spelled = curated.resolution(repository: "Nixon", collection: "White House Special Files",
                                         subCollection: "Staff Member and Office Files")
        let amp = curated.resolution(repository: "Nixon", collection: "White House Special Files",
                                     subCollection: "Staff Member & Office Files")
        #expect(spelled != nil || amp == nil,
                "if the spelled form is curated the ampersand must reach it too")
        if spelled != nil { #expect(amp == spelled) }
    }

    // MARK: - Ford: the two truncations

    /// `citationSentence` ends the sentence at a middle initial, so a series named after a
    /// person arrives cut off. Curating the stump would key every `Robert C.` in the corpus to
    /// one person's aid, so the remainder is recovered from the raw note instead.
    @Test("A series named after a person survives the middle-initial truncation")
    func middleInitialIsRepaired() {
        let cases = [
            ("Source: Ford Library, National Security Adviser, Robert C. McFarlane Files, Box 1, "
             + "Intelligence Investigations Subject Files. No classification marking.",
             "Robert C. McFarlane Files"),
            ("Source: Ford Library, National Security Adviser, John K. Matheny Files, Box 11, "
             + "Senate Select Committee on Intelligence, Final Report. No classification marking.",
             "John K. Matheny Files"),
            ("Source: Ford Library, National Security Adviser, Staff Assistants: Peter W. Rodman "
             + "Files, 1974–1977, Box 1, Subject File, Glomar Explorer. Secret.",
             "Staff Assistants: Peter W. Rodman Files"),
        ]
        for (note, expected) in cases {
            let sub = CuratedLibraryResolutions.subCollection(
                inNote: note, afterCollection: "National Security Adviser")
            #expect(sub == expected, "got \(sub ?? "nil") — the stump would mis-key every namesake")
        }
    }

    /// The repair must stay narrow: a candidate that does not end in an initial is returned as
    /// the citation sentence produced it, never extended into the commentary that follows.
    @Test("A candidate that is not truncated is left alone")
    func unruncatedCandidatesAreUntouched() {
        let note = "Source: Ford Library, National Security Adviser, Presidential Agency File, "
            + "Box 5, Central Intelligence Agency. Secret. Drafted by W. Colby, who forwarded it."
        #expect(CuratedLibraryResolutions.subCollection(
            inNote: note, afterCollection: "National Security Adviser") == "Presidential Agency File")
    }

    /// The other truncation is inherent: a series whose own name contains a comma splits on it,
    /// so only the head reaches the matcher. The curated segment is that head, which has to be
    /// unambiguous inside the collection for this to be safe.
    @Test("A series name containing a comma resolves from its head")
    func commaBearingSeriesResolveFromTheHead() throws {
        let curated = try bundled()
        let europe = "Source: Ford Library, National Security Adviser, NSC Europe, Canada, and "
            + "Ocean Affairs Staff, Box 58, General Subject File, Ocean Policy, 1976. Confidential."
        let sub = CuratedLibraryResolutions.subCollection(
            inNote: europe, afterCollection: "National Security Adviser")
        #expect(sub == "NSC Europe", "the citation splits at the series' own comma")
        let aid = curated.resolution(repository: "Ford Library",
                                     collection: "National Security Adviser", subCollection: sub)
        #expect(aid?.title.contains("Europe, Canada, and Ocean Affairs") == true)
        #expect(curated.resolution(repository: "Ford Library",
                                   collection: "National Security Adviser",
                                   subCollection: "NSC Staff for Europe") == aid,
                "the other FRUS spelling of the same staff must reach the same aid")
    }

    // MARK: - Ford: one series, cited at several levels

    /// The NSC institutional records are cited through the adviser's papers, as a collection in
    /// their own right, and under a bare `NSC Files` level. All of them are the same records, and
    /// the parenthesised spellings key differently, so each needs its own entry.
    @Test("Every spelling of the NSC Institutional Files reaches one aid")
    func institutionalFilesSpellingsAgree() throws {
        let curated = try bundled()
        let viaAdviser = curated.resolution(repository: "Ford Library",
                                            collection: "National Security Adviser",
                                            subCollection: "NSC Institutional Files")
        #expect(viaAdviser != nil)
        for collection in ["NSC Institutional Files (H-Files)", "NSC Institutional Files",
                           "NSC Institutional Files (H\u{2013}Files)"] {
            let hit = curated.resolution(repository: "Ford Library", collection: collection,
                                         subCollection: nil)
            #expect(hit?.url == viaAdviser?.url,
                    "\(collection) must reach the same finding aid as the adviser-level citation")
        }
        // …and the subseries the corpus splits off with an em dash.
        for sub in ["Institutional Files", "Institutional Files\u{2014} NSDMs",
                    "Institutional Files\u{2014}Meetings"] {
            #expect(curated.resolution(repository: "Ford Library",
                                       collection: "National Security Council",
                                       subCollection: sub)?.url == viaAdviser?.url,
                    "\(sub) is a subseries of the same Institutional Files")
        }
    }

    /// `NSC Institutional Files` is the single most dangerous name in this artifact: three
    /// repositories use it for three different series. Measured over the corpus, of the
    /// documents whose note names institutional files, **1,206 are Nixon's, 447 are Carter's and
    /// only 331 are Ford's** — so a match on the series name alone would send the majority of
    /// them to the wrong repository.
    ///
    /// Nixon and Ford are both curated now, which makes this sharper than a nil check: the two
    /// must resolve to **different repositories' aids**, and Carter — which has no entry — must
    /// still resolve to nothing rather than borrowing either.
    @Test("The institutional files resolve per repository, never across")
    func institutionalFilesDoNotCrossRepositories() throws {
        let curated = try bundled()
        let ford = curated.resolution(repository: "Ford Library",
                                      collection: "NSC Institutional Files (H-Files)",
                                      subCollection: nil)
        let nixon = curated.resolution(repository: "Nixon Presidential Materials",
                                       collection: "NSC Files",
                                       subCollection: "NSC Institutional Files (H-Files)")
        #expect(ford != nil)
        #expect(nixon != nil)
        #expect(ford?.url.contains("fordlibrarymuseum.gov") == true)
        #expect(nixon?.url.contains("nixonlibrary.gov") == true)
        #expect(ford?.url != nixon?.url, "the same name must not reach the same aid")

        // Nixon cited at its own level-1 reaches the Nixon aid, not Ford's.
        for collection in ["NSC Institutional Files (H-Files)", "NSC Institutional Files"] {
            let hit = curated.resolution(repository: "Nixon Presidential Materials",
                                         collection: collection, subCollection: nil)
            #expect(hit?.url == nixon?.url, "\(collection) must reach the Nixon H-Files aid")
        }
        // Repositories with no entry stay unresolved rather than borrowing a neighbour's.
        for repository in ["Carter Library", "Reagan Library", "Library of Congress"] {
            #expect(curated.resolution(repository: repository,
                                       collection: "NSC Institutional Files (H-Files)",
                                       subCollection: nil) == nil,
                    "\(repository) borrowed another repository's institutional-files aid")
            #expect(curated.resolution(repository: repository,
                                       collection: "National Security Council",
                                       subCollection: "Institutional Files") == nil,
                    "\(repository) reached Ford's institutional files through the NSC level")
        }
    }

    // MARK: - Nixon

    /// The Nixon Library itemises 28 NSC Files series but not all of them, so the collection
    /// page is the answer for the rest — and that is most of the mass, not a rounding error:
    /// `Country Files` (1,697 documents) is split by region in the archive but cited without
    /// one, and `Agency Files` (506, boxes 193–306) has no list of its own.
    @Test("An un-itemised Nixon series falls back to the collection page")
    func nixonCollectionPageAnswersForUnitemisedSeries() throws {
        let curated = try bundled()
        let hub = curated.resolution(repository: "Nixon", collection: "NSC Files",
                                     subCollection: nil)
        #expect(hub != nil)
        for series in ["Country Files", "Agency Files", "Backchannel Files"] {
            #expect(curated.resolution(repository: "Nixon", collection: "NSC Files",
                                       subCollection: series) == hub,
                    "\(series) has no list of its own and must reach the collection page")
        }
        // …while an itemised series reaches its own box list instead.
        let subjects = curated.resolution(repository: "Nixon", collection: "NSC Files",
                                          subCollection: "Subject Files")
        #expect(subjects != nil)
        #expect(subjects != hub, "Subject Files has its own box list")
        #expect(subjects?.url.hasSuffix(".pdf") == true)
    }

    /// Two Nixon series have confusable names — `For the President's Files (Winston Lord) –
    /// China Trip/Vietnam` (boxes 846–872) and `For the President's Files – China/Vietnam
    /// Negotiations` (1031–1041). The corpus also writes several short forms that name neither
    /// unambiguously, and those deliberately get the collection page rather than a guess.
    @Test("Confusable Nixon China series are not guessed at")
    func confusableChinaSeriesFallBack() throws {
        let curated = try bundled()
        let hub = curated.resolution(repository: "Nixon", collection: "NSC Files",
                                     subCollection: nil)
        let lord = curated.resolution(
            repository: "Nixon", collection: "NSC Files",
            subCollection: "For the President\u{2019}s Files ( Winston Lord )—China Trip/Vietnam")
        #expect(lord != nil)
        #expect(lord?.url.contains("winston_lord") == true)
        for ambiguous in ["President\u{2019}s File—China Trip", "Files for the President—China Material",
                         "Files for the President"] {
            #expect(curated.resolution(repository: "Nixon", collection: "NSC Files",
                                       subCollection: ambiguous) == hub,
                    "\(ambiguous) names neither series unambiguously and must not be guessed")
        }
    }

    /// `National Security Council` names a body, not a collection, so it is curated
    /// sub-collection-only: an unrecognized sub-collection must resolve to nothing rather than
    /// to the Institutional Files.
    @Test("The bare National Security Council level never answers on its own")
    func bodyLevelDoesNotAnswer() throws {
        let curated = try bundled()
        #expect(curated.resolution(repository: "Ford Library",
                                   collection: "National Security Council",
                                   subCollection: nil) == nil)
        #expect(curated.resolution(repository: "Ford Library",
                                   collection: "National Security Council",
                                   subCollection: "Some Other Series") == nil)
    }

    /// Ford publishes a collection-level page for the National Security Adviser Files, so an
    /// unqualified citation gets it — and so does a series the library has never published an
    /// aid for. Nixon publishes no equivalent for the White House Special Files, which is why
    /// that row deliberately has no collection-wide entry; the asymmetry is the point.
    @Test("An unqualified Ford citation gets the collection-level page")
    func fordCollectionLevelAnswers() throws {
        let curated = try bundled()
        let whole = curated.resolution(repository: "Ford Library",
                                       collection: "National Security Adviser", subCollection: nil)
        #expect(whole != nil, "Ford publishes a collection-level page; it must be reachable")
        // The Scowcroft Daily Work Files have no aid of their own — measured, 21 documents. They
        // fall back to the collection page rather than to nothing.
        #expect(curated.resolution(repository: "Ford Library",
                                   collection: "National Security Adviser",
                                   subCollection: "Scowcroft Daily Work Files") == whole)
        #expect(curated.resolution(repository: "Nixon", collection: "White House Special Files",
                                   subCollection: nil) == nil,
                "Nixon has no collection-level aid, so it must still answer nothing")
    }

    /// The Library of Congress row has no honest whole-row answer — it is a division, not a
    /// collection — so an unrecognized sub-collection must resolve to **nothing** rather than
    /// falling back to a repository-level link. That fallback is the defect this work removes.
    @Test("A container row never answers for an unrecognized sub-collection")
    func containerRowDoesNotFallBack() throws {
        let curated = try bundled()
        #expect(curated.resolution(repository: "Library of Congress",
                                   collection: "Manuscript Division",
                                   subCollection: "Some Unlisted Papers") == nil)
        #expect(curated.resolution(repository: "Library of Congress",
                                   collection: "Manuscript Division",
                                   subCollection: nil) == nil,
                "there is no collection-wide answer for a division")
    }

    @Test("The lookup normalizes repository and collection like the authority keying")
    func lookupUsesSharedNormalizers() throws {
        let curated = try bundled()
        let canonical = curated.resolution(repository: "Carter Library",
                                           collection: "National Security Affairs",
                                           subCollection: "Brzezinski Material")
        #expect(canonical != nil)
        // Full library name, and the plural-folded collection spelling.
        #expect(curated.resolution(repository: "Jimmy Carter Library",
                                   collection: "National Security Affair",
                                   subCollection: "Brzezinski Material")?.url == canonical?.url)
    }

    @Test("An uncurated repository resolves to nothing")
    func uncuratedResolvesToNil() throws {
        let curated = try bundled()
        #expect(curated.resolution(repository: "Reagan Library", collection: "Matlock Files",
                                   subCollection: nil) == nil)
    }

    // MARK: - Johnson

    /// One series is 41% of the Johnson corpus. The library titles it in the plural and FRUS
    /// cites it in the singular, which the shared plural fold handles — so this is really a test
    /// that the fold is load-bearing for 2,015 documents.
    @Test("The Johnson Country File resolves in either number")
    func johnsonCountryFileResolves() throws {
        let curated = try bundled()
        let singular = curated.resolution(repository: "Johnson Library",
                                          collection: "National Security File",
                                          subCollection: "Country File")
        #expect(singular != nil, "2,015 documents ride on this one")
        #expect(singular?.title.contains("Country Files") == true)
        #expect(curated.resolution(repository: "Johnson Library",
                                   collection: "National Security Files",
                                   subCollection: "Country Files") == singular,
                "the collection's plural spelling reaches the same list")
        // Vietnam is a separate series, not part of it.
        #expect(curated.resolution(repository: "Johnson Library",
                                   collection: "National Security File",
                                   subCollection: "Vietnam Country File") != singular)
    }

    /// The Johnson aliases carry real weight, and nothing else in this suite exercises them:
    /// dropping them all leaves every other test green (mutation-tested). Each spelling below is
    /// a verbatim corpus form, with the document count it accounts for.
    @Test("Johnson's alias spellings reach their series")
    func johnsonAliasesResolve() throws {
        let curated = try bundled()
        // canonical sub-collection -> other spellings the corpus writes
        let families: [String: [String]] = [
            "Files of Walt W. Rostow": ["Rostow Files",                      // 64
                                        "Files of Walt Rostow"],             // 44
            "Files of Robert W. Komer": ["Komer Files",                      // 28
                                         "Robert W. Komer Files",            // 6
                                         "Files of Robert Komer"],           // 5
            "NSAMs": ["National Security Action Memoranda",                  // 13
                      "National Security Action Memorandums"],               // 9
            "NSC Histories": ["NSC History",                                 // 7
                              "NSC History of the March 31st Speech"],       // 20
            "Saunders Files": ["Files of Harold H. Saunders",                // 12
                               "NSC Files of Harold Saunders"],              // 9
            "Memos to the President": ["Memos to the President— Walt W. Rostow",
                                       "Memos to the President- McGeorge Bundy"],
            "Head of State Correspondence": ["Head of State Correspondence File"],
            "NSC Meetings File": ["NSC Meetings"],
        ]
        for (canonical, spellings) in families {
            let expected = curated.resolution(repository: "Johnson Library",
                                              collection: "National Security File",
                                              subCollection: canonical)
            #expect(expected != nil, Comment(rawValue: "\(canonical) is not curated"))
            for spelling in spellings {
                #expect(curated.resolution(repository: "Johnson Library",
                                           collection: "National Security File",
                                           subCollection: spelling) == expected,
                        Comment(rawValue: "\(spelling) fell through instead of matching "
                                + "\(canonical) — compare on the whole resolution, since the "
                                + "collection page would share neither URL nor rationale"))
            }
        }
    }

    /// LBJ files some things the corpus cites under the NSF elsewhere — `Aides File` names the
    /// NSF's own per-person series rather than a series of its own — so the collection page is
    /// the honest answer rather than a guess at which aide.
    @Test("An un-itemised Johnson series gets the collection page")
    func johnsonCollectionPageAnswers() throws {
        let curated = try bundled()
        let whole = curated.resolution(repository: "Johnson Library",
                                       collection: "National Security File", subCollection: nil)
        #expect(whole != nil)
        #expect(curated.resolution(repository: "Johnson Library",
                                   collection: "National Security File",
                                   subCollection: "Aides File") == whole)
        // The abbreviation and the plural both name the same collection.
        for spelling in ["NSF", "National Security Files"] {
            #expect(curated.resolution(repository: "Johnson Library", collection: spelling,
                                       subCollection: nil)?.url == whole?.url)
        }
    }

    /// Johnson is the first repository whose entries carry a NARA identifier, so these rows show
    /// a catalogue link beside the finding aid. Both values were read off the library's own
    /// pages and then confirmed against the catalogue record itself.
    @Test("Published NARA identifiers produce a catalogue link")
    func johnsonCarriesNARAIdentifiers() throws {
        let curated = try bundled()
        let nsf = curated.resolution(repository: "Johnson Library",
                                     collection: "National Security File", subCollection: nil)
        #expect(nsf?.naId == "567979")
        #expect(nsf?.catalogURL?.absoluteString == "https://catalog.archives.gov/id/567979")
        let shosc = curated.resolution(repository: "Johnson Library",
                                       collection: "National Security File",
                                       subCollection: "Special Head of State Correspondence File")
        #expect(shosc?.naId == "7763260")
        #expect(shosc?.catalogURL != nil)
        // An entry with no published identifier must not invent one.
        #expect(curated.resolution(repository: "Johnson Library",
                                   collection: "National Security File",
                                   subCollection: "Country File")?.catalogURL == nil)
    }

    /// `Subject File` is the most-shared series name in the artifact — four repositories use it
    /// for four different series. Each must reach its own repository, and the four must be
    /// four distinct destinations.
    @Test("Subject Files resolve per repository, never across")
    func subjectFilesDoNotCrossRepositories() throws {
        let curated = try bundled()
        let hits = [
            curated.resolution(repository: "Johnson Library",
                               collection: "National Security File", subCollection: "Subject File"),
            curated.resolution(repository: "Nixon", collection: "NSC Files",
                               subCollection: "Subject Files"),
            curated.resolution(repository: "Ford Library", collection: "National Security Adviser",
                               subCollection: "Presidential Subject File"),
            curated.resolution(repository: "Reagan Library", collection: "Executive Secretariat",
                               subCollection: "NSC Subject File"),
        ].map { $0?.url }
        #expect(hits.allSatisfy { $0 != nil }, "fixture guard: all four must be curated")
        #expect(Set(hits).count == 4, "four repositories, four destinations")
    }

    // MARK: - Eisenhower

    /// The Eisenhower Library holds **two** collections whose names contain "Whitman", and the
    /// wrong one is the obvious-looking match: `WHITMAN, ANN C.: PAPERS, 1949-90` is Ann
    /// Whitman's own papers, **one foot**. The Ann Whitman File the corpus cites 1,900 times is
    /// `EISENHOWER, DWIGHT D.: Papers as President … (Ann Whitman File)`, 122 feet.
    ///
    /// This is the same shape as the Nixon Returned Materials Collection removed in #695: a
    /// plausible name match to a small unrelated collection.
    @Test("The Whitman File is the presidential papers, not Ann Whitman's own")
    func whitmanFileIsNotAnnWhitmansPapers() throws {
        let curated = try bundled()
        let whitman = try #require(curated.resolution(repository: "Eisenhower Library",
                                                      collection: "Whitman File",
                                                      subCollection: nil))
        #expect(whitman.title.contains("Papers as President"))
        #expect(whitman.title.contains("Ann Whitman File"))
        #expect(!whitman.url.contains("whitman-ann-papers"),
                "that URL is the one-foot personal papers, not the 122-foot presidential file")
        // Cited a level up, through the papers, it must reach the same place.
        #expect(curated.resolution(repository: "Eisenhower Library", collection: "Eisenhower papers",
                                   subCollection: "Whitman file")?.url == whitman.url)
    }

    /// The library titles one series two ways and FRUS uses both. Confirmed from the container
    /// list itself, whose scope note says "The Dwight D. Eisenhower Diaries series" while the
    /// series is titled DDE Diary.
    @Test("Eisenhower's series spellings reach one container list")
    func eisenhowerSeriesSpellingsAgree() throws {
        let curated = try bundled()
        func awf(_ sub: String) -> CuratedLibraryResolution? {
            curated.resolution(repository: "Eisenhower Library", collection: "Whitman File",
                               subCollection: sub)
        }
        #expect(awf("Eisenhower Diaries") == awf("DDE Diaries"))
        #expect(awf("Eisenhower Diaries")?.url.contains("dde-diary-series") == true)
        #expect(awf("International File") == awf("International Series"))
        #expect(awf("NSC Records") == awf("NSC Series"))
        // …and distinct series stay distinct.
        #expect(awf("NSC Records") != awf("Cabinet Series"))
        #expect(awf("Administration Series") != awf("Miscellaneous Series"))

        // Dulles: General and White House telephone conversations are subseries of one series.
        let general = curated.resolution(repository: "Eisenhower Library", collection: "Dulles Papers",
                                         subCollection: "General Telephone Conversations")
        #expect(general?.url.contains("telephone-conversations-series") == true)
        #expect(curated.resolution(repository: "Eisenhower Library", collection: "Dulles Papers",
                                   subCollection: "White House Telephone Conversations") == general)
        // But the memoranda series is a different destination.
        #expect(curated.resolution(repository: "Eisenhower Library", collection: "Dulles Papers",
                                   subCollection: "Meetings with the President") != general)
    }

    /// `White House Office Files` names a records group of some fifteen separate offices, each
    /// with its own finding aid and no aid for the whole. So it is curated sub-collection-only:
    /// an unqualified citation must resolve to nothing rather than to one office's records.
    @Test("The White House Office level never answers on its own")
    func whiteHouseOfficeIsSubKeyedOnly() throws {
        let curated = try bundled()
        #expect(curated.resolution(repository: "Eisenhower Library",
                                   collection: "White House Office Files",
                                   subCollection: nil) == nil)
        // Project Clean Up (40 documents) has no published aid anywhere in the library's 581,
        // so it must stay unresolved rather than borrow a neighbouring office's.
        #expect(curated.resolution(repository: "Eisenhower Library",
                                   collection: "White House Office Files",
                                   subCollection: "Project Clean Up") == nil)
        // A named office does resolve.
        #expect(curated.resolution(repository: "Eisenhower Library",
                                   collection: "White House Office Files",
                                   subCollection: "Records of the Office of the Staff Secretary") != nil)
    }

    // MARK: - Kennedy

    /// The JFK Library publishes **one** finding aid per subcollection — overview, series list
    /// and container list on a single page — so a series citation has no more specific
    /// published destination and the collection entry is the honest answer for all of them.
    ///
    /// It is deliberately not an anchor link. The aid's series anchors (`#id1`…) are injected
    /// client-side, so measured on the live page the fragment resolves before the target exists
    /// and the browser stays at scroll position 0; and the ids are per-page sequential — `#id5`
    /// is Subjects in the National Security Files but Press Conferences in the President's
    /// Office Files — so they would drift silently if a series were ever inserted.
    @Test("A Kennedy series citation reaches its subcollection's finding aid")
    func kennedySeriesReachTheCollectionAid() throws {
        let curated = try bundled()
        let nsf = try #require(curated.resolution(repository: "Kennedy Library",
                                                  collection: "National Security Files",
                                                  subCollection: nil))
        #expect(nsf.title.contains("National Security Files"))
        // Every series citation lands on the same aid — 2,108 documents, measured.
        for series in ["Countries Series", "Meetings and Memoranda Series", "Subjects Series",
                       "Vietnam Country Series", "Kaysen Series", "Germany"] {
            #expect(curated.resolution(repository: "Kennedy Library",
                                       collection: "National Security Files",
                                       subCollection: series) == nsf,
                    Comment(rawValue: "\(series) must reach the National Security Files aid"))
        }
        #expect(curated.resolution(repository: "Kennedy Library", collection: "NSF",
                                   subCollection: nil)?.url == nsf.url)
        // The President's Office Files are a different subcollection, in both spellings.
        let pof = curated.resolution(repository: "Kennedy Library",
                                     collection: "Presidential Office Files", subCollection: nil)
        #expect(pof != nil)
        #expect(pof?.url != nsf.url)
        #expect(curated.resolution(repository: "Kennedy Library",
                                   collection: "President\u{2019}s Office Files",
                                   subCollection: nil)?.url == pof?.url,
                Comment(rawValue: "the library's possessive spelling reaches the same entry "
                        + "through the President's/Presidential fold added in #696, so it "
                        + "needs no entry of its own"))
    }

    /// A personal-papers entry must name the **person the collection is named after**.
    ///
    /// The Kennedy entries were found by trying slugs and reading the page title back, and that
    /// is a method with a specific failure: `gwbpp` looks like George W. Ball and is **Gerald W.
    /// Bush**; `chpp` looks like Christian Herter and is **Chet Huntley**. Both were caught only
    /// by the title. The own-domain guard cannot see either one — same library, same host — so
    /// the surname is the only thing that distinguishes a right link from a plausible wrong one.
    ///
    /// Mutation-tested: pointing the Ball entry at `gwbpp` passes every other test in this suite.
    @Test("A personal-papers entry names the right person")
    func personalPapersNameTheRightPerson() throws {
        let curated = try bundled()
        // (repository, collection, surname that must appear in the finding aid's own title)
        let people: [(String, String, String)] = [
            ("Kennedy Library", "Ball Papers", "Ball"),
            ("Kennedy Library", "Papers of George W. Ball", "Ball"),
            ("Kennedy Library", "Hilsman Papers", "Hilsman"),
            ("Kennedy Library", "Sorensen Papers", "Sorensen"),
            ("Kennedy Library", "Papers of Arthur M. Schlesinger", "Schlesinger"),
            ("Kennedy Library", "Dillon Papers", "Dillon"),
            ("Kennedy Library", "Cleveland Papers", "Cleveland"),
            ("Eisenhower Library", "Herter Papers", "HERTER"),
            ("Eisenhower Library", "Hagerty papers", "HAGERTY"),
            ("Ford Library", "National Security Adviser", "National Security Adviser"),
        ]
        for (repository, collection, surname) in people {
            let hit = try #require(curated.resolution(repository: repository,
                                                      collection: collection, subCollection: nil),
                                   Comment(rawValue: "\(repository)/\(collection) is not curated"))
            #expect(hit.title.localizedCaseInsensitiveContains(surname),
                    Comment(rawValue: "\(collection) resolves to \"\(hit.title)\", which does not "
                            + "name \(surname) — a slug that lands on a different person's papers "
                            + "looks entirely plausible and is on the same domain"))
        }
    }

    /// Christian Herter's papers are held at **two** libraries, and the corpus cites both.
    /// Eisenhower's are curated; Kennedy's are not, and must stay unresolved rather than
    /// borrowing Eisenhower's aid — which is exactly what an unscoped name match would do.
    @Test("Herter Papers at two libraries do not borrow each other's aid")
    func herterPapersDoNotCrossLibraries() throws {
        let curated = try bundled()
        let ike = curated.resolution(repository: "Eisenhower Library", collection: "Herter Papers",
                                     subCollection: nil)
        #expect(ike?.url.contains("eisenhowerlibrary.gov") == true)
        #expect(curated.resolution(repository: "Kennedy Library", collection: "Herter Papers",
                                   subCollection: nil) == nil,
                Comment(rawValue: "the Kennedy Library's Herter papers have no curated aid yet "
                        + "— they must not resolve to the Eisenhower Library's"))
    }

    // MARK: - Artifact integrity

    /// `subCollectionAliases` alias the **sub-collection**, so on an entry with no
    /// sub-collection they match nothing and silently do nothing.
    ///
    /// This is not hypothetical: `James C. Hagerty papers` (19 documents) and
    /// `Staff Secretary's Records` were both written as aliases on collection-wide entries and
    /// resolved nothing until each was given its own entry. A collection-level spelling needs
    /// an entry; only a sub-collection spelling can be an alias.
    @Test("No entry carries aliases that can never match")
    func collectionWideEntriesHaveNoDeadAliases() throws {
        for entry in try bundled().entries where entry.subCollection == nil {
            #expect(entry.subCollectionAliases == nil,
                    Comment(rawValue: "\(entry.repository)/\(entry.collection) has "
                            + "subCollectionAliases but no subCollection — they match nothing. "
                            + "Give each spelling its own entry instead."))
        }
    }


    /// Every entry must point at **its own repository's** domain.
    ///
    /// This is the generic form of the defect this whole workstream exists to prevent, and the
    /// one a hand-written entry is most likely to introduce: a URL copied from the row above it.
    /// Series names repeat across repositories — `NSC Institutional Files`, `Subject Files`,
    /// `Country Files`, `Name Files` all name different records at different libraries — so the
    /// mistake produces a plausible-looking link to the wrong archive.
    @Test("No entry links to another repository's domain")
    func entriesStayWithinTheirRepository() throws {
        let expected = ["Carter Library": "jimmycarterlibrary.gov",
                        "Ford Library": "fordlibrarymuseum.gov",
                        "Eisenhower Library": "eisenhowerlibrary.gov",
                        "Johnson Library": "discoverlbj.org",
                        "Kennedy Library": "jfklibrary.org",
                        "Library of Congress": "loc.gov",
                        "Nixon": "nixonlibrary.gov",
                        "Reagan Library": "reaganlibrary.gov"]
        for entry in try bundled().entries {
            let host = try #require(URL(string: entry.resolution.url)?.host(),
                                    Comment(rawValue: "\(entry.resolution.url) has no host"))
            let domain = try #require(
                expected[entry.repository],
                Comment(rawValue: "\(entry.repository) is not in the expected-domain table — "
                        + "add it deliberately rather than widening the check"))
            #expect(host.hasSuffix(domain),
                    Comment(rawValue: "\(entry.repository)/\(entry.collection)/"
                            + "\(entry.subCollection ?? "—") links to \(host), not \(domain)"))
        }
    }

    /// A NARA identifier must be a bare number: anything else silently builds a broken
    /// catalogue URL, and the row would show a link that 404s.
    @Test("Every NARA identifier is a bare number")
    func naIdsAreWellFormed() throws {
        for entry in try bundled().entries {
            guard let naId = entry.resolution.naId else { continue }
            #expect(naId.allSatisfy(\.isNumber) && !naId.isEmpty,
                    "\(entry.collection) has a malformed naId: \(naId)")
            #expect(entry.resolution.catalogURL != nil)
        }
    }


    /// A curated entry whose URL does not parse is worse than no entry: the row would render a
    /// title with nothing behind it.
    @Test("Every curated entry carries a parseable finding aid")
    func everyEntryHasAUsableURL() throws {
        let curated = try bundled()
        #expect(!curated.entries.isEmpty)
        for entry in curated.entries {
            #expect(entry.resolution.findingAid != nil,
                    "\(entry.collection)/\(entry.subCollection ?? "—") has an unparseable URL")
            #expect(!entry.resolution.title.isEmpty)
            #expect(entry.resolution.url.hasPrefix("https://"),
                    "\(entry.resolution.url) is not https")
        }
    }

    /// Two entries answering the same key would make the resolution order-dependent.
    @Test("No two entries share a key")
    func keysAreUnique() throws {
        var seen = Set<String>()
        for entry in try bundled().entries {
            let key = CuratedLibraryResolutions.collectionKey(entry.repository, entry.collection)
                + "|" + (entry.subCollection.map { CuratedLibraryResolutions.subCollectionKey($0) } ?? "")
            #expect(seen.insert(key).inserted, "duplicate curated key: \(key)")
        }
    }

    /// Both platforms must consult the store. This is a **deletion** guard: a source scan
    /// cannot tell a live call from one behind `if false`, and does not try. The realistic
    /// regression it exists for is a call site that never gets written, not one disabled on
    /// purpose.
    ///
    /// Both platforms must consult the store. This codebase has shipped a Source Explorer
    /// affordance to iOS only before (#617 did it in Collections), and the macOS panel is a
    /// separate hand-written view rather than a shared one.
    @Test("Both Source Explorer views consult the curated store")
    func bothPlatformsWired() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        for path in ["FRUSExplorer/SourceExplorer/SourceExplorerView.swift",
                     "FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift"] {
            let text = try String(contentsOf: root.appending(path: path), encoding: .utf8)
            let code = text.split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")
            #expect(code.contains("CuratedLibraryResolutionsStore.shared?.resolution("),
                    "\(path) does not consult the curated library store")
            #expect(code.contains("CuratedLibraryResolutions.subCollection("),
                    "\(path) resolves without the sub-collection — the container rows would be wrong")
        }
    }
}
