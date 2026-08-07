// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - NamedFileSeriesRouting

/// Where a file series cited by name alone actually is (#354 item 1, surviving halves).
///
/// ## The citation shape, and why it is the hardest one
/// `Roosevelt Papers`. `J.C.S. Files`. `Moscow Embassy Files`. That is the whole source note —
/// no lot number, no record group, no repository. A reader of FRUS 1943 sees `Leahy Papers` and
/// has no way to learn it means the Manuscript Division of the Library of Congress.
///
/// Measured with the shipped parser over the corpus's 222,364 distinct notes: **5,745
/// documents** across **312 distinct series names**. Exactly **376** of them — the `CFM Files`
/// entry in `curated-lot-resolutions.json`, the only curated lot carrying `seriesNames` — get a
/// record group today. The other 5,369 get an explainer saying the repository is not stated.
///
/// ## What #354 asked for, and which parts of it are safe
/// The issue proposed an offline title match against the NARA harvest, a live keyword route, a
/// repository table, and a static series→record-group map. Its own comment then measured the
/// title match at **0 of 4,986** and told us why: a FRUS series name is an internal Department
/// designator (`NEA Files`, `CFM Files`) and a NARA series title is a descriptive phrase written
/// by a cataloguer. The two vocabularies do not intersect.
///
/// **That measurement also settles the live keyword route, which is not built here.** A live
/// query searches the same titles the offline match already failed against — over the same
/// records, since the harvest is NARA's own bulk export of them — so it inherits the same zero.
/// What it would return instead is unconstrained free-text hits, which is precisely the class of
/// answer #681 removed from the library route for being wrong by construction. Building it would
/// undo that lesson.
///
/// So what ships is the two halves that rest on evidence: a repository table and a
/// record-group map. **1,740 documents, 30.3% of the population**, every entry backed either by
/// the FRUS editors' own words or by a record group whose scope is the series named.
///
/// ## The evidence is the volumes' own front matter
/// FRUS volumes enumerate their sources. `frus1943`'s Sources section says, verbatim:
///
/// > 4. Hopkins Papers —The papers of Harry L. Hopkins, deposited in the Franklin D. Roosevelt
/// > Library at Hyde Park.
/// > 7. Leahy Papers —The diary of Fleet Admiral William D. Leahy, deposited in the Manuscripts
/// > Division of the Library of Congress…
/// > 8. Roosevelt Papers —The papers of President Franklin D. Roosevelt, deposited in the
/// > Franklin D. Roosevelt Library at Hyde Park.
///
/// That is better evidence than anything this project could assemble from outside: it is the
/// editors saying where they got the document. Each entry carries the sentence, and both views
/// show it, so a researcher can judge the claim instead of trusting it.
///
/// ## What is deliberately refused
/// The issue proposed `Defense→330` and `Army→319`. Both are **wrong**, and the volumes say so:
///
/// - `Defense Files` — `frus1941-43`: "The files of the Secretaries of War and Navy and other
///   relevant top-level files of the military departments for 1941–1943." The Department of
///   Defense did not exist until 1947; those are RG 107 and RG 80. And `frus1949v03` defines
///   `Department of Defense Files` as "the principal telegraphic and teletype exchanges between
///   the United States Military Governor for Germany and the **Department of the Army**".
///   One name, two different bodies of records, neither of them the Office of the Secretary of
///   Defense. 176 documents left unrouted rather than sent to RG 330.
/// - `Department of the Army Files` — `frus1943`: "Files for 1943 of the **War Department**, now
///   under the jurisdiction of the Department of the Army." Custody in 1943 is not provenance,
///   and War Department records are not simply RG 319. 86 documents left unrouted.
///
/// This is the whole reason the table is hand-built from the volumes rather than generated from
/// the issue's proposed mapping: two of its five entries would have sent 262 documents to record
/// groups that do not hold them.
///
/// `Marshall Mission Files` is excluded from the Foreign Service post pattern for the same
/// reason — the Marshall Mission to China was not a diplomatic post, so `Mission` is not one of
/// the pattern's nouns.
///
/// ## Provenance of the identifiers
/// The four record-group NAIDs were verified against the live NARA Catalog on 2026-08-07, and
/// RG 84 and RG 353 additionally agree with the committed bulk-export harvest manifest, which
/// was built from a different source. Repository URLs were fetched and answered `200` with a
/// title naming the institution; the Library of Congress and Yale destinations are not repeated
/// here but read from `ManuscriptRepositoryGuidance`, which already verified them for #354
/// item 4.
///
/// Version history:
///   1.0 — Session 2026-08-07: #354 item 1, repository table + record-group map
enum NamedFileSeriesRouting {

    // MARK: - Destination

    /// Where a named series is held.
    enum Destination: Sendable, Equatable {
        /// A repository outside the record-group system — a presidential library or a
        /// manuscript repository.
        case repository(name: String, url: URL?)
        /// A NARA record group whose scope is the series the citation names.
        case recordGroup(number: String, naId: String, title: String)

        /// The NARA Catalog record for a record-group destination.
        var catalogURL: URL? {
            if case .recordGroup(_, let naId, _) = self {
                return URL(string: "https://catalog.archives.gov/id/\(naId)")
            }
            return nil
        }
    }

    // MARK: - Entry

    /// One routed series name.
    struct Entry: Sendable, Equatable {
        /// Where the records are.
        let destination: Destination
        /// The sentence a researcher can check the claim against — the FRUS editors' own
        /// description where one exists, otherwise what makes the record group the right one.
        let evidence: String
        /// The spellings the corpus uses, folded through `CuratedLotResolutions`'
        /// series-name normalizer at lookup.
        let spellings: [String]
    }

    // MARK: - The table

    /// The hand-verified series names, in descending order of corpus traffic.
    static let entries: [Entry] = [
        Entry(destination: .repository(name: "Franklin D. Roosevelt Presidential Library",
                                       url: URL(string: "https://www.fdrlibrary.org/archives")),
              evidence: "The volume's Sources section: “Roosevelt Papers — The papers of "
                      + "President Franklin D. Roosevelt, deposited in the Franklin D. "
                      + "Roosevelt Library at Hyde Park.”",
              spellings: ["Roosevelt Papers"]),

        Entry(destination: .recordGroup(number: "218", naId: "545",
                                        title: "Records of the U.S. Joint Chiefs of Staff"),
              evidence: "The volume's Sources section: “J.C.S. Files — The files of the Joint "
                      + "Chiefs of Staff.” Record Group 218 is the Joint Chiefs' own records.",
              spellings: ["J.C.S. Files", "J. C. S. Files", "JCS Files", "JCS Records"]),

        Entry(destination: .repository(name: "Franklin D. Roosevelt Presidential Library",
                                       url: URL(string: "https://www.fdrlibrary.org/archives")),
              evidence: "The volume's Sources section: “Hopkins Papers — The papers of Harry L. "
                      + "Hopkins, deposited in the Franklin D. Roosevelt Library at Hyde Park.”",
              spellings: ["Hopkins Papers"]),

        Entry(destination: .repository(name: "Library of Congress, Manuscript Division",
                                       url: URL(string: "https://www.loc.gov/rr/mss/")),
              evidence: "The volume's Sources section: “Leahy Papers — The diary of Fleet "
                      + "Admiral William D. Leahy, deposited in the Manuscripts Division of the "
                      + "Library of Congress.”",
              spellings: ["Leahy Papers"]),

        Entry(destination: .recordGroup(
                number: "353", naId: "661",
                title: "Records of Interdepartmental and Intradepartmental Committees "
                     + "(State Department)"),
              evidence: "SWNCC is the State-War-Navy Coordinating Committee, and Record Group "
                      + "353 is the State Department's interdepartmental committee records.",
              spellings: ["SWNCC Files", "S.W.N.C.C. Files"]),

        Entry(destination: .repository(name: "Library of Congress, Manuscript Division",
                                       url: URL(string: "https://www.loc.gov/rr/mss/")),
              evidence: "The volume's Sources section: “Hull Papers — The papers of Cordell "
                      + "Hull, deposited in the Manuscripts Division of the Library of "
                      + "Congress.”",
              spellings: ["Hull Papers"]),

        Entry(destination: .repository(
                name: "Manuscripts and Archives, Yale University Library",
                url: URL(string: "https://library.yale.edu/visit-and-study/visit-information/manuscripts-and-archives-reading-room")),
              evidence: "The volume's Sources section: “Stimson Papers — The diary of Secretary "
                      + "of War Henry L. Stimson, deposited in the Yale University Library.”",
              spellings: ["Stimson Papers"]),
    ]

    // MARK: - Foreign Service posts

    /// `<City> Embassy | Legation | Consulate | Post Files` — a Foreign Service post's own
    /// records, which is what Record Group 84 is.
    ///
    /// A pattern rather than a table because the corpus writes **33 of these** across 149
    /// documents (`Moscow Embassy Files` 36, `Tokyo Post Files` 20, `Vienna Legation Files` 12,
    /// down a long tail to `Wellington Legation Files` 1), the name states the post outright,
    /// and a table would have to be extended every time a volume cites another city.
    ///
    /// `Mission` is **not** one of the nouns. It would match `Marshall Mission Files` — the
    /// Marshall Mission to China, which was not a diplomatic post and whose records are not in
    /// RG 84. One word, two documents, and a wrong record group.
    private static let foreignServicePostRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\b(?:Embassy|Legation|Consulate|Post)\s+Files$"#,
        options: .caseInsensitive
    )

    /// The Foreign Service post destination, shared by every name the pattern matches.
    static let foreignServicePosts = Entry(
        destination: .recordGroup(
            number: "84", naId: "413",
            title: "Records of the Foreign Service Posts of the Department of State"),
        evidence: "The series name states a Foreign Service post, and Record Group 84 is the "
                + "posts' own records. The individual post's files are a series within it.",
        spellings: [])

    // MARK: - Lookup

    /// Every listed spelling folded to its lookup key, built once.
    ///
    /// Uses `CuratedLotResolutions.normalizeSeriesName`, the normalizer the app already applies
    /// to this exact field — its own doc comment notes `J. C. S. Files` has nine spellings in
    /// the corpus. Sharing it means a spelling this table matches is a spelling the rest of
    /// Source Explorer matches.
    private static let byKey: [String: Entry] = {
        var table: [String: Entry] = [:]
        for entry in entries {
            for spelling in entry.spellings {
                let key = CuratedLotResolutions.normalizeSeriesName(spelling)
                guard !key.isEmpty else { continue }
                table[key] = entry
            }
        }
        return table
    }()

    /// Where the named series is held, or `nil` where this table cannot say.
    ///
    /// Exact spellings are tried first; the Foreign Service post pattern is the fallback, so a
    /// listed name always beats the pattern.
    static func routing(forSeriesName name: String) -> Entry? {
        let key = CuratedLotResolutions.normalizeSeriesName(name)
        guard !key.isEmpty else { return nil }
        if let hit = byKey[key] { return hit }
        guard let regex = foreignServicePostRegex else { return nil }
        let range = NSRange(name.startIndex..., in: name)
        return regex.firstMatch(in: name, range: range) != nil ? foreignServicePosts : nil
    }

    // MARK: - Wording

    /// Section/box header.
    static var sectionTitle: String {
        String(localized: "source.explorer.namedSeriesRouting.header",
               defaultValue: "Where This Series Is Held")
    }

    /// Row label for a record-group destination.
    static var recordGroupLabel: String {
        String(localized: "source.explorer.namedSeriesRouting.recordGroup",
               defaultValue: "Record Group")
    }

    /// Row label for a repository destination.
    static var repositoryLabel: String {
        String(localized: "source.explorer.namedSeriesRouting.repository",
               defaultValue: "Repository")
    }

    /// The destination's display name.
    static func title(_ entry: Entry) -> String {
        switch entry.destination {
        case .repository(let name, _):
            return name
        case .recordGroup(let number, _, let title):
            return "RG \(number) — \(title)"
        }
    }

    /// The row label appropriate to the destination.
    static func label(_ entry: Entry) -> String {
        switch entry.destination {
        case .repository: return repositoryLabel
        case .recordGroup: return recordGroupLabel
        }
    }

    /// The destination's link, whichever kind it is.
    static func url(_ entry: Entry) -> URL? {
        switch entry.destination {
        case .repository(_, let url): return url
        case .recordGroup: return entry.destination.catalogURL
        }
    }

    /// The link's title, naming the destination so it can be judged before it is opened.
    static func linkLabel(_ entry: Entry) -> String {
        if case .recordGroup = entry.destination {
            return String(localized: "source.explorer.nara.viewRecord",
                          defaultValue: "View in NARA Catalog")
        }
        return String(localized: "source.explorer.repositoryGuidance.link",
                      defaultValue: "Open \(title(entry))")
    }
}
