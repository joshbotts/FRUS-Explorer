// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - POCOMIndex

/// Career records from the Office of the Historian's Principal Officers and Chiefs of Mission
/// register (#736).
///
/// The app-side mirror of `POCOMIndexGeneratorCore.POCOMIndex`; the JSON is the contract.
///
/// ## What it reaches, and what it does not
/// POCOM carries no FRUS anchor, so the only route in is
/// `PersonAuthorityIndex.pocomSlug(for:)` — meaning career data can appear **only** for people the
/// app already knows from a volume's editor-published person list. Measured on the shipped
/// artifacts: 1,245 of the app's 12,839 authority people carry a slug, **1,243 of them have at
/// least one appointment**, and those surface a Career section on roughly 12,500 of 62,818 live
/// person rows — high relative to the people count because chiefs of mission recur across many
/// volumes.
///
/// The careers add nobody to the 268 volumes whose editors published no person list. That gap is
/// #234's, and no amount of POCOM data closes it.
///
/// ## Chiefs of mission (version 2)
/// Version 2 adds three tables that do NOT go through the person authority: `chiefs`, every U.S.
/// chief of mission the register records as having served between 1861 and 1906, plus those whose
/// tenure ended in the 90 days before 1861 (the addressee rule's grace still reaches them), keyed by
/// POCOM territory id; `names`, the register's name parts for those people; and `roles`, the singular
/// role labels. They exist so Source Explorer can tell a Department letter to the U.S. minister (an
/// instruction) from a note to a foreign legation in Washington — `frus1863p2/d573`, "Mr. Seward to
/// Mr. Dayton", is the type case — and they are read only by `ChiefsOfMissionRoster`. `careers` is
/// unchanged by them: a person who is only in `chiefs` still has no Career section.
///
/// Version history:
///   1.0 — Session 2026-08-07: #736
///   1.1 — Session 2026-08-07: `POCOMCareer.lifespanText` (moved off the view, grouping off)
///   1.2 — 2026-09-13: version 2's `chiefs`, `names` and `roles` tables and `chiefs(territoryId:)`
///   1.3 — 2026-09-13: `displayName` keeps a generational suffix the altname omits; the chiefs
///         table's doc names its grace rows
///   1.4 — 2026-09-23 (#1370): `POCOMCareer.lifespanText` removed. The person sheet prints one
///         lifespan, `PersonLifespan` in `PersonIndexView.swift`, which takes the name authority's
///         years first and POCOM's only for a gap
///   1.5 — 2026-11-10 (FRUS Explorer Light, S22b): moved into FRUSCoreKit, public, and loaded from a URL
///         the host gives (`init(contentsOf:)`), since `ChiefsOfMissionRoster`, which reads its chiefs,
///         is the kit's; `POCOMIndexStore`, which reads the app's bundle, stays in the app
///         (`FRUSExplorer/Models/POCOMIndexStore.swift`)
///   1.6 — 2026-11-14 (FRUS Explorer Light, S21g's follow-up): `career(forSlug:)` public, with `POCOMCareer`'s
///         life years and posts and `POCOMAssignment`'s title, dates and note, for a host that draws the
///         person sheet's Career section; `PersonLifespan`, the sheet's lifespan line, moved here from
///         `PersonIndexView.swift`, public. Nothing they answer changes
public struct POCOMIndex: Codable, Sendable {

    /// Index schema version.
    let version: Int
    /// ISO date (`yyyy-MM-dd`) the index was generated.
    let generated: String
    /// Provenance string (upstream repo, license, checkout HEAD).
    let source: String
    /// `slug → career`, for slugs with at least one appointment.
    let careers: [String: POCOMCareer]
    /// `POCOM territory id → served chief-of-mission rows` (version 2), in the generator's order.
    /// Empty when decoding a version-1 file.
    let chiefs: [String: [POCOMChiefRow]]
    /// `slug → name parts` for every person in `chiefs` (version 2).
    let names: [String: POCOMPersonName]
    /// `POCOM role id → singular role label` for every role in `chiefs` (version 2).
    let roles: [String: String]

    private enum CodingKeys: String, CodingKey { case version, generated, source, careers, chiefs, names, roles }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        generated = try c.decodeIfPresent(String.self, forKey: .generated) ?? ""
        source = try c.decodeIfPresent(String.self, forKey: .source) ?? ""
        careers = try c.decodeIfPresent([String: POCOMCareer].self, forKey: .careers) ?? [:]
        chiefs = try c.decodeIfPresent([String: [POCOMChiefRow]].self, forKey: .chiefs) ?? [:]
        names = try c.decodeIfPresent([String: POCOMPersonName].self, forKey: .names) ?? [:]
        roles = try c.decodeIfPresent([String: String].self, forKey: .roles) ?? [:]
    }

    /// The career for a POCOM slug, or `nil`.
    public func career(forSlug slug: String) -> POCOMCareer? { careers[slug] }

    /// Every territory id the `chiefs` table covers, sorted.
    var chiefTerritoryIds: [String] { chiefs.keys.sorted() }

    /// The chiefs of mission who served at a POCOM territory, as resolved values.
    ///
    /// A row is dropped when its person has no `names` entry or when it states neither an
    /// appointment nor a start date, because neither can be matched against a letter. The first day
    /// is the EARLIER of the appointment and start dates (the register has rows where the
    /// appointment follows the start); the last day is the ceiled end date, else the generator's
    /// derived end (`ex`), else `nil` — and a `nil` last day never matches a date.
    func chiefs(territoryId: String) -> [POCOMChiefOfMission] {
        (chiefs[territoryId] ?? []).compactMap { row in
            guard let name = names[row.s] else { return nil }
            let starts = [row.ap, row.st].compactMap { $0.flatMap(POCOMPartialDate.floorISO) }
            guard let first = starts.min() else { return nil }
            let last = row.en.flatMap(POCOMPartialDate.ceilISO) ?? row.ex.flatMap(POCOMPartialDate.ceilISO)
            return POCOMChiefOfMission(
                slug: row.s, surname: name.sn, forename: name.fn, displayName: name.displayName,
                roleLabel: roles[row.r] ?? row.r, territoryId: territoryId,
                firstDayISO: first, lastDayISO: last)
        }
    }
}

// MARK: - POCOMChiefRow

/// One served chief-of-mission row as the generator writes it (version 2).
///
/// Dates stay the register's own strings — `1861-03-18`, `1866-04` or a bare `1864` — for the same
/// reason `POCOMAssignment`'s do. `POCOMIndex.chiefs(territoryId:)` floors and ceils them.
struct POCOMChiefRow: Codable, Sendable, Equatable {
    /// The person's POCOM slug (`dayton-william-lewis`).
    let s: String
    /// The POCOM role id (`envoy-extraordinary-minister-plenipotentiary`).
    let r: String
    /// Date of appointment.
    let ap: String?
    /// Date the chief took up the post (in practice, presented credentials).
    let st: String?
    /// Date they left it.
    let en: String?
    /// Derived end, written only when `en` is absent: the day before the next strictly later start
    /// at the same territory in the full register.
    let ex: String?
}

// MARK: - POCOMPersonName

/// A person's name parts as the register records them (version 2).
struct POCOMPersonName: Codable, Sendable, Equatable {
    /// Surname (`Dayton`).
    let sn: String
    /// Forename(s) (`William Lewis`).
    let fn: String
    /// Generational suffix (`Jr.`), if any.
    let g: String?
    /// The register's first alternative name (`William L. Dayton`), if any.
    let a: String?

    /// The name to print: the register's alternative name when it has one, otherwise the forename,
    /// surname and suffix.
    ///
    /// The suffix is appended to the alternative name when the register's altname omits it, and not
    /// when it already ends with it. Without that, `dayton-william-lewis-jr` (a `William L. Dayton`,
    /// g `Jr.`, Netherlands 1882–1885) prints exactly as his father, the France type case — two people,
    /// one string. `thomas-william-widgery`'s altname already carries its `Jr.`.
    var displayName: String {
        let suffix = g?.trimmingCharacters(in: .whitespaces) ?? ""
        if let a, !a.trimmingCharacters(in: .whitespaces).isEmpty {
            guard !suffix.isEmpty else { return a }
            let bare = { (text: Substring) in text.trimmingCharacters(in: .punctuationCharacters).lowercased() }
            let lastToken = a.split(whereSeparator: { $0 == " " || $0 == "," }).last.map(bare) ?? ""
            return lastToken == bare(Substring(suffix)) ? a : a + " " + suffix
        }
        return [fn, sn, suffix].filter { !$0.isEmpty }.joined(separator: " ")
    }
}

// MARK: - POCOMChiefOfMission

/// A resolved U.S. chief of mission: who, in what role, where, and the days the register lets us
/// say they held the post.
public struct POCOMChiefOfMission: Sendable, Equatable {
    /// POCOM slug.
    public let slug: String
    /// Surname, for matching a letter's addressee.
    public let surname: String
    /// Forename(s), for matching a letter's addressee.
    public let forename: String
    /// The name to print.
    public let displayName: String
    /// Singular role label ("Envoy Extraordinary and Minister Plenipotentiary").
    public let roleLabel: String
    /// The POCOM territory id the row was keyed under.
    public let territoryId: String
    /// First day of the tenure, `yyyy-MM-dd`, floored from a partial date.
    public let firstDayISO: String
    /// Last day of the tenure, `yyyy-MM-dd`, ceiled from a partial date; `nil` when the register
    /// gives no end and the generator could derive none.
    public let lastDayISO: String?
}

// MARK: - POCOMPartialDate

/// Floors and ceils the register's partial dates (`YYYY`, `YYYY-MM`, `YYYY-MM-DD`) to whole days.
enum POCOMPartialDate {

    /// `1864` → `1864-01-01`; `1866-04` → `1866-04-01`; a full date unchanged; anything else `nil`.
    static func floorISO(_ raw: String) -> String? {
        guard let parts = parts(raw) else { return nil }
        return String(format: "%04d-%02d-%02d", parts.year, parts.month ?? 1, parts.day ?? 1)
    }

    /// `1864` → `1864-12-31`; `1866-04` → `1866-04-30`; a full date unchanged; anything else `nil`.
    static func ceilISO(_ raw: String) -> String? {
        guard let parts = parts(raw) else { return nil }
        let month = parts.month ?? 12
        let day = parts.day ?? daysIn(month: month, year: parts.year)
        return String(format: "%04d-%02d-%02d", parts.year, month, day)
    }

    private static func parts(_ raw: String) -> (year: Int, month: Int?, day: Int?)? {
        let pieces = raw.trimmingCharacters(in: .whitespaces).split(separator: "-", omittingEmptySubsequences: false)
        guard (1...3).contains(pieces.count), pieces[0].count == 4, let year = Int(pieces[0]) else { return nil }
        var month: Int?
        var day: Int?
        if pieces.count >= 2 {
            guard pieces[1].count == 2, let m = Int(pieces[1]), (1...12).contains(m) else { return nil }
            month = m
        }
        if pieces.count == 3, let m = month {
            guard pieces[2].count == 2, let d = Int(pieces[2]), (1...daysIn(month: m, year: year)).contains(d) else { return nil }
            day = d
        }
        return (year, month, day)
    }

    private static func daysIn(month: Int, year: Int) -> Int {
        switch month {
        case 2: return (year % 4 == 0 && year % 100 != 0) || year % 400 == 0 ? 29 : 28
        case 4, 6, 9, 11: return 30
        default: return 31
        }
    }
}

// MARK: - POCOMCareer

/// One person's register entry: name, life dates, and appointments in chronological order.
public struct POCOMCareer: Codable, Sendable, Equatable {
    /// Display name as POCOM spells it.
    let n: String
    /// Birth year, if recorded. The person sheet reads it only where the name authority has none
    /// (`PersonLifespan`, #1370).
    public let b: Int?
    /// Death year, if recorded. Read the same way as `b`.
    public let d: Int?
    /// Appointments, already sorted by the generator — the view renders them in order.
    public let a: [POCOMAssignment]
}

// MARK: - POCOMAssignment

/// One post held: what, where, and when.
public struct POCOMAssignment: Codable, Sendable, Equatable, Identifiable {
    /// Role title ("Under Secretary of State").
    let r: String
    /// Place or organization, absent for posts inside the Department.
    let p: String?
    /// Date of appointment, as the register writes it.
    let ap: String?
    /// Date the officer took up the post.
    let st: String?
    /// Date they left it.
    let en: String?
    /// The register's note on the termination ("Left Tehran on", "Resigned").
    public let nt: String?

    /// Stable within one career: no two appointments share all four of these.
    public var id: String { "\(r)|\(p ?? "")|\(ap ?? "")|\(st ?? "")" }

    /// The date range to show, or `nil` when the register has no date at all.
    ///
    /// Prefers the **service** dates (`started`–`ended`) over the appointment date, because the
    /// question a researcher is asking beside a document is who held the post *then*, not when the
    /// paperwork was signed. Falls back to the appointment date when service dates are missing.
    ///
    /// Dates are rendered as the register writes them rather than reformatted: many are partial
    /// (`1935` with no month), and a formatter would have to invent the missing precision.
    public var dateRangeText: String? {
        let start = st ?? ap
        switch (start, en) {
        case let (.some(from), .some(to)):
            return String(localized: "pocom.range", defaultValue: "\(from) – \(to)")
        case let (.some(from), .none):
            return String(localized: "pocom.from", defaultValue: "from \(from)")
        case let (.none, .some(to)):
            return String(localized: "pocom.until", defaultValue: "until \(to)")
        case (.none, .none):
            return nil
        }
    }

    /// "Under Secretary of State" or "Ambassador — France".
    public var titleText: String {
        guard let p, !p.isEmpty else { return r }
        return String(localized: "pocom.roleAtPlace", defaultValue: "\(r) — \(p)")
    }
}

// MARK: - PersonLifespan

/// A reconciled person's life years, as the detail sheet prints them (#1370).
///
/// **Life years are not active years, and until #1370 the app wrote one into the other.** The
/// rollup stored the name authority's birth and death years in `start_year`/`end_year` — the
/// columns the People list prints beside the role and the sheet labels **Active** — while the
/// Career footer printed POCOM's, so Kissinger's sheet read *Active 1923–2015* above *1923–2023*.
/// The rollup now carries only the volumes' years, and the life years are read here, at display
/// time, once.
///
/// **Two sources, in a fixed order.** The name authority's year comes first; POCOM's fills only a
/// year the authority lacks. Measured over the shipped artifacts: POCOM fills a gap for 76 people
/// (Kissinger's death year, 2023, is in POCOM alone); the two disagree for exactly two, Byrnes and
/// Deming, on a birth year each, and the authority wins; and 18 people have authority years and no
/// POCOM career at all — 13 of them presidents — so they had no lifespan line until now.
///
/// Display time rather than rollup columns, because the sheet already holds both entries (it
/// reads the authority for the register's role and POCOM for the Career section) and because
/// columns filled from the authority alone would have missed POCOM's 76 fills.
///
/// Version history:
///   1.0 — #1370: in `PersonIndexView.swift`, beside the sheet
///   1.1 — 2026-11-14 (FRUS Explorer Light, S21g's follow-up): moved into FRUSCoreKit, public, unchanged, for a
///         host whose person sheet prints the lifespan line as the app does
public enum PersonLifespan {

    /// Birth and death years: the authority's, each gap filled from the POCOM career.
    public static func years(authority: PersonAuthorityIndex.AuthorityEntry?,
                             career: POCOMCareer?) -> (born: Int?, died: Int?) {
        (authority?.b ?? career?.b, authority?.d ?? career?.d)
    }

    /// The sheet's lifespan line for this person, or `nil` when neither source has a year.
    public static func text(authority: PersonAuthorityIndex.AuthorityEntry?, career: POCOMCareer?) -> String? {
        let lived = years(authority: authority, career: career)
        return text(born: lived.born, died: lived.died)
    }

    /// "1893–1971", "Born 1893", "Died 1971", or `nil`.
    ///
    /// Grouping is switched **off** explicitly. `String(localized:)` interpolates an `Int` through a
    /// number formatter, which renders 1893 as "1,893" — a year wearing a thousands separator — and
    /// shipped once that way in the Career footer this line replaces.
    public static func text(born: Int?, died: Int?) -> String? {
        let plain = IntegerFormatStyle<Int>.number.grouping(.never)
        switch (born, died) {
        case let (.some(born), .some(died)):
            return String(localized: "people.detail.lifespan",
                          defaultValue: "\(born, format: plain)–\(died, format: plain)")
        case let (.some(born), .none):
            return String(localized: "people.detail.lifespan.born",
                          defaultValue: "Born \(born, format: plain)")
        case let (.none, .some(died)):
            return String(localized: "people.detail.lifespan.died",
                          defaultValue: "Died \(died, format: plain)")
        case (.none, .none):
            return nil
        }
    }
}

// MARK: - Loading

extension POCOMIndex {

    /// The index in the `pocom-index.json` at `url`, decoded as `POCOMIndexStore` decodes the copy bundled
    /// with the app, for a host that keeps the file elsewhere.
    public init(contentsOf url: URL) throws {
        self = try JSONDecoder().decode(POCOMIndex.self, from: Data(contentsOf: url))
    }
}
