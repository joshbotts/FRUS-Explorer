// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ManuscriptRepositoryGuidance

/// Where to actually look for a citation naming a repository the National Archives does not
/// administer (#354 item 4).
///
/// ## What was already done, and what was left
/// #681 stopped the harm: `NARACustody` refuses to issue a catalogue query for these
/// repositories, because a free-text search on a collection the catalogue cannot hold returns
/// rows that are wrong by construction. #355/N-4 then curated finding aids for the collections
/// it could, keyed on `(repository, collection, subCollection)`.
///
/// Measured against the shipped `curated-library-resolutions.json` with the real parser over
/// the corpus's 222,364 distinct source notes: of **1,503** documents citing a non-NARA
/// repository, **938** already reach a curated finding aid — every one of them a Library of
/// Congress personal-papers collection — and **565 reach nothing at all**. They are told the
/// National Archives cannot help and given no idea who can.
///
/// This is the other half: guidance at the **repository** level, which is the right grain for
/// exactly the citations the collection-keyed artifact misses. `Center of Military History,
/// Abrams Papers, Messages` and `National Defense University, Taylor Papers, T-646-71` name a
/// different collection every time; what does not vary is the institution holding them.
///
/// ## Coverage
/// Fourteen entries, **564 of the 565** uncovered documents:
///
/// | repository | documents |
/// |---|---|
/// | National Defense University | 244 |
/// | Library of Congress (papers outside the curated eight) | 120 |
/// | U.S. Army Center of Military History | 70 |
/// | Naval Historical Center | 55 |
/// | Minnesota Historical Society | 13 |
/// | U.S. Army Military History Institute | 13 |
/// | Princeton University | 11 |
/// | Hoover Institution | 10 |
/// | University of Montana | 10 |
/// | Yale University | 8 |
/// | University of Arkansas | 5 |
/// | Columbia University · Massachusetts Historical Society | 2 each |
/// | Michigan State University | 1 |
///
/// The one document not covered is a Howard University citation to the Moorland-Spingarn
/// Research Center. It is omitted deliberately: `library.howard.edu/msrc` is a 404 and
/// `msrc.howard.edu` answers with a generic faculty-page title, so no stable destination could
/// be confirmed, and one document does not justify shipping an unconfirmed one.
///
/// ## Two renames the citations predate
/// Worth more to a researcher than any link. FRUS cites the **Naval Historical Center**, which
/// was redesignated the **Naval History and Heritage Command** on 1 December 2008, and the
/// **U.S. Army Military History Institute**, whose holdings are now the **U.S. Army Heritage
/// and Education Center**. Searching either citation under its printed name finds nothing.
///
/// ## How each URL was verified, and why the field is on the record
/// Every entry declares how its destination was checked, because two of them could not be
/// checked the usual way and that should be visible rather than buried.
///
/// `.fetched` means the URL was requested and answered `200` with a title naming the
/// institution. That check caught four wrong guesses: `history.navy.mil` is a 404 at its root,
/// `lib.umt.edu/archives` and `library.howard.edu/msrc` are 404s, and — the one that would have
/// shipped silently — `web.library.yale.edu/mssa` returns 200 but redirects to the **Beinecke**
/// library, a different division from the Manuscripts and Archives that holds the Bowles Papers.
///
/// `.searchIndex` means only the search engine's index corroborates it: NDU and the Center of
/// Military History sit behind a Department of Defense filter that answers **403 to every path,
/// including invented ones** — verified by requesting
/// `ndu.edu/Libraries/ThisPageDoesNotExistAtAll-zzz/`, which returns the same 403 as the real
/// page. So a fetch there proves nothing either way, and no amount of retrying changes that.
/// They ship anyway because the failure mode of a wrong *homepage* is a visible dead link, not
/// the silent wrong answer a wrong archival identifier gives — but the distinction is recorded
/// on the entry rather than assumed.
///
/// `.redirectTarget` was added 2026-08-23 after a full re-check of all 95 URLs in the app. Three
/// of these fourteen had **moved**: Library of Congress, Yale and Michigan State. Yale's new
/// destination reads correctly (`Manuscripts and Archives Reading Room`, the right division — the
/// Beinecke trap above did not recur) so it stays `.fetched`; the other two answer with a bot
/// shell rather than a page, and neither existing case describes that honestly. See the case's own
/// note. **Michigan State is the one to learn from**: `lib.msu.edu` returns `200` to every path
/// including an invented one, so the 200 that made an audit call it "moved, fine" proved nothing
/// at all. The invented-path control catches this — but only if it is run against a **2xx**, which
/// nobody thinks to do.
///
/// ## Matching
/// Spellings are folded through `CollectionKeying.canonicalRepository` + `normalized`, the same
/// pair `NARACustody` uses, so the corpus's variants reach one entry: `the Hoover Institution`,
/// `Princeton University Library`, `University of Arkansas Libraries` and
/// `National Defense university` all fold on their own. Only the Military History Institute
/// needs explicit aliases — the corpus writes it four ways across 13 documents, and
/// `canonicalRepository` folds none of them together. Note also that `Naval Historical Center`
/// canonicalises to `Naval Historical`, which is why the spelling list is run through the real
/// normalizer rather than written out by hand.
///
/// Version history:
///   1.0 — Session 2026-08-07: #354 item 4, repository-level finding-aid guidance
///   1.1 — Session 2026-08-23: three moved URLs re-pointed; `.redirectTarget` added
enum ManuscriptRepositoryGuidance {

    // MARK: - Verification

    /// How an entry's destination was confirmed. Recorded per entry so the two that could not
    /// be fetched are visible rather than indistinguishable from the twelve that were.
    enum Verification: String, Sendable, Equatable {
        /// Requested on 2026-08-07; answered `200` with a title naming the institution.
        case fetched
        /// Corroborated only by the search engine's index — the host answers `403` to every
        /// path, real or invented, so fetching cannot discriminate.
        case searchIndex
        /// **The institution's own server redirected us here, and the destination could not be
        /// read.** Added 2026-08-23, when a re-check found two entries that fit neither case above.
        ///
        /// Calling these `fetched` would assert a check nobody performed; calling them
        /// `searchIndex` would claim the host refuses robots, which is false — it answers, just
        /// not with anything readable. The redirect itself is the evidence, and it is good
        /// evidence: it is the repository asserting where its own archives now live.
        ///
        /// Two shapes produced it, and the second is the more dangerous:
        /// - **Library of Congress** — Cloudflare returns a `Just a moment...` interstitial, so the
        ///   status code describes the bot check rather than the page. With redirects suppressed
        ///   the old path resolves to a *specific* Manuscript Division successor while an invented
        ///   sibling resolves to a *generic* catch-all; that asymmetry is what makes the successor
        ///   credible.
        /// - **Michigan State** — the destination answers `200`, but so does **every** path on that
        ///   host, including an invented one, and the body is an Incapsula bot-defence shell. A
        ///   `200` there is worth nothing. This is the mirror of the `searchIndex` case and it is
        ///   easier to be fooled by, because a 200 reads as success to any checker.
        case redirectTarget
    }

    // MARK: - Entry

    /// One repository the National Archives does not administer, and where its records are.
    struct Entry: Sendable, Equatable, Identifiable {
        /// The repository's own name today.
        let name: String
        /// What FRUS calls it, when that is no longer the institution's name. `nil` when the
        /// citation's spelling and the current name agree.
        let formerName: String?
        /// One line on what the repository holds and where — enough to decide whether to go.
        let holdings: String
        /// The repository's finding-aid or archives page.
        let url: URL?
        /// How `url` was confirmed.
        let verification: Verification
        /// The spellings the corpus uses, folded through the shared normalizers at lookup.
        let spellings: [String]

        var id: String { name }
    }

    // MARK: - The table

    /// The fourteen repositories, in descending order of corpus traffic.
    static let entries: [Entry] = [
        Entry(name: "National Defense University Library",
              formerName: nil,
              holdings: "Special Collections at Fort McNair, Washington, D.C., holds the "
                      + "personal papers of senior military leaders, including the Maxwell "
                      + "Taylor Papers.",
              url: URL(string: "https://www.ndu.edu/Libraries/Manuscript-Collections/"),
              verification: .searchIndex,
              spellings: ["National Defense University"]),

        Entry(name: "Library of Congress, Manuscript Division",
              formerName: nil,
              holdings: "The Manuscript Reading Room in the Madison Building, Washington, "
                      + "D.C., holds the personal papers this citation names. Finding aids "
                      + "for individual collections are published separately.",
              url: URL(string: "https://www.loc.gov/research-centers/manuscript/about-this-research-center/"),
              verification: .redirectTarget,
              spellings: ["Library of Congress"]),

        Entry(name: "U.S. Army Center of Military History",
              formerName: nil,
              holdings: "The Center, at Fort McNair, Washington, D.C., holds the Army's "
                      + "historical records and the personal papers of senior Army officers.",
              url: URL(string: "https://history.army.mil/Research/Series-and-Collections/"),
              verification: .searchIndex,
              spellings: ["Center of Military History"]),

        Entry(name: "Naval History and Heritage Command",
              formerName: "Naval Historical Center",
              holdings: "The Navy Archives at the Washington Navy Yard holds these records. "
                      + "The Naval Historical Center was redesignated the Naval History and "
                      + "Heritage Command on 1 December 2008 — searching under the name in "
                      + "this citation will not find it.",
              url: URL(string: "https://www.history.navy.mil/research/archives.html"),
              verification: .fetched,
              spellings: ["Naval Historical Center"]),

        Entry(name: "Minnesota Historical Society",
              formerName: nil,
              holdings: "The Gale Family Library in Saint Paul holds the Hubert H. Humphrey "
                      + "Papers.",
              url: URL(string: "https://www.mnhs.org/library"),
              verification: .fetched,
              spellings: ["Minnesota Historical Society"]),

        Entry(name: "U.S. Army Heritage and Education Center",
              formerName: "U.S. Army Military History Institute",
              holdings: "Carlisle Barracks, Pennsylvania. The Military History Institute's "
                      + "holdings are now part of the Army Heritage and Education Center — "
                      + "searching under the name in this citation will not find them.",
              url: URL(string: "https://ahec.armywarcollege.edu/"),
              verification: .fetched,
              spellings: ["U.S. Army Military History Institute",
                          "U.S. Army Military Historical Institute",
                          "U.S. Military History Institute",
                          "USAMHI"]),

        Entry(name: "Princeton University Library",
              formerName: nil,
              holdings: "Special Collections at Firestone Library holds the Adlai E. "
                      + "Stevenson and Herman Phleger papers, described in the library's "
                      + "own finding aids.",
              url: URL(string: "https://findingaids.princeton.edu/"),
              verification: .fetched,
              spellings: ["Princeton University"]),

        Entry(name: "Hoover Institution Library & Archives",
              formerName: nil,
              holdings: "At Stanford University — a private institution unrelated to the "
                      + "NARA-administered Herbert Hoover Presidential Library. Holds the "
                      + "Lansdale, Williams and Stilwell papers.",
              url: URL(string: "https://www.hoover.org/library-archives"),
              verification: .fetched,
              spellings: ["Hoover Institution"]),

        Entry(name: "Maureen and Mike Mansfield Library, University of Montana",
              formerName: nil,
              holdings: "Archives and Special Collections in Missoula holds the Mike "
                      + "Mansfield Papers; most of the collection is not digitised.",
              url: URL(string: "https://www.umt.edu/library/asc/"),
              verification: .fetched,
              spellings: ["University of Montana"]),

        Entry(name: "Manuscripts and Archives, Yale University Library",
              formerName: nil,
              holdings: "Sterling Memorial Library, New Haven, holds the Chester Bowles "
                      + "Papers (MS 628).",
              url: URL(string: "https://library.yale.edu/sterling-memorial-library/manuscripts-and-archives-reading-room"),
              verification: .fetched,
              spellings: ["Yale University"]),

        Entry(name: "University of Arkansas Libraries",
              formerName: nil,
              holdings: "The Special Collections Division in Fayetteville holds the Bureau "
                      + "of Educational and Cultural Affairs Historical Collection.",
              url: URL(string: "https://libraries.uark.edu/specialcollections/"),
              verification: .fetched,
              spellings: ["University of Arkansas"]),

        Entry(name: "Columbia University Libraries",
              formerName: nil,
              holdings: "The Rare Book & Manuscript Library in New York holds the W. Averell "
                      + "Harriman Papers cited here.",
              url: URL(string: "https://library.columbia.edu/libraries/rbml.html"),
              verification: .fetched,
              spellings: ["Columbia University"]),

        Entry(name: "Massachusetts Historical Society",
              formerName: nil,
              holdings: "Boston. Holds the Henry Cabot Lodge II Papers.",
              url: URL(string: "https://www.masshist.org/"),
              verification: .fetched,
              spellings: ["Massachusetts Historical Society"]),

        Entry(name: "Michigan State University Archives",
              formerName: nil,
              holdings: "University Archives and Historical Collections, East Lansing, holds "
                      + "the Hannah and Fishel papers.",
              url: URL(string: "https://lib.msu.edu/branches/ua/"),
              verification: .redirectTarget,
              spellings: ["Michigan State University"]),
    ]

    // MARK: - Lookup

    /// Every spelling folded to its lookup key, built once.
    ///
    /// Folded through the **real** `CollectionKeying` pair rather than written out by hand:
    /// `Naval Historical Center` canonicalises to `Naval Historical`, and a hand-written key
    /// would have missed all 55 of its documents with nothing to signal it.
    private static let byKey: [String: Entry] = {
        var table: [String: Entry] = [:]
        for entry in entries {
            for spelling in entry.spellings {
                guard let canonical = CollectionKeying.canonicalRepository(spelling) else { continue }
                let key = CollectionKeying.normalized(canonical)
                guard !key.isEmpty else { continue }
                table[key] = entry
            }
        }
        return table
    }()

    /// The guidance for a cited repository, or `nil` where none is curated.
    ///
    /// Callers must have established that the repository is **outside** NARA custody first
    /// (`NARACustody.mayQueryCatalog(forRepository:)`); this table says nothing about whether
    /// the National Archives holds the records, only where these particular repositories are.
    static func guidance(forRepository repository: String?) -> Entry? {
        guard let repository, !repository.trimmingCharacters(in: .whitespaces).isEmpty,
              let canonical = CollectionKeying.canonicalRepository(repository)
        else { return nil }
        return byKey[CollectionKeying.normalized(canonical)]
    }

    // MARK: - Wording

    /// Section/box header.
    static var sectionTitle: String {
        String(localized: "source.explorer.repositoryGuidance.header",
               defaultValue: "Where These Records Are")
    }

    /// Row label for a repository that has been renamed since the citation was written.
    static var citedAsLabel: String {
        String(localized: "source.explorer.repositoryGuidance.citedAs",
               defaultValue: "Cited here as")
    }

    /// The link's title, naming the destination so it can be judged before it is opened.
    static func linkLabel(_ entry: Entry) -> String {
        String(localized: "source.explorer.repositoryGuidance.link",
               defaultValue: "Open \(entry.name)")
    }
}
