// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - POCOMIndexBuilder

/// Parses a `HistoryAtState/pocom` checkout into the bundled ``POCOMIndex`` (#736).
///
/// ## Four sources, three of them appointments
/// | directory | what it holds | measured |
/// |---|---|---|
/// | `people/{a-z}/*.xml` | the person register — name, life dates, career type | 4,261 files |
/// | `missions-countries/*.xml` | chiefs of mission to countries | 5,743 appointments (5,350 served + 393 `<other-nominees>`) |
/// | `missions-orgs/*.xml` | chiefs of mission to organizations | 225 |
/// | `positions-principals/*.xml` | posts **inside the Department** — Secretary, Under Secretary… | 1,293 |
///
/// The plan for this work described POCOM as "chief-of-mission assignments". That would have
/// dropped `positions-principals` — 1,293 appointments across 951 people, and the people most
/// heavily represented in FRUS. All three are harvested; 7,261 appointments over 4,259 people.
///
/// `concurrent-appointments/` is deliberately **not** harvested: its records are cross-references
/// between chief appointments already counted (`<chief-id>` pointers), so reading them would
/// double-count a posting rather than add one.
///
/// ## Version 2: the chiefs-of-mission tables
/// `missions-countries` is read a second way, for the `chiefs`, `names` and `roles` tables. That
/// read differs from the careers harvest in four ways, each measured on the register at
/// `ccc1f033`:
/// - Only `<chief>` rows inside `<chiefs>` count: 5,350 served rows. The 393 `<other-nominees>`
///   rows stay in `careers` and never reach `chiefs`.
/// - Rows are keyed by the file's `<territory-id>`, never by a row's contemporary territory id.
///   Korea's rows, for example, carry `joseon-dynasty-1910`.
/// - A row starts on the earlier of its appointment and start dates; the 49 rows stating neither
///   are skipped. A row is kept when its widened tenure overlaps 1861-01-01…1906-12-31, a last day
///   from 1860-10-03 counting (the app's 90-day grace), and an open end is closed by `ex` before
///   that test.
/// - `keepSlug` does not apply.
///
/// Measured output: 641 rows over 427 people, 52 territories and 15 roles. Two rows carry `ex`:
/// Pacheco's 1890 commissions to Guatemala and Honduras, both closed at 1891-06-30. The whole file
/// is 530,712 bytes, and `careers` is byte-identical to version 1's.
///
/// Pure and file-system-light — the per-file parsers work on strings so tests need no checkout.
public enum POCOMIndexBuilder {

    // MARK: - Role and place labels

    /// Reads a role table (`roles-country-chiefs/`, `positions-principals/`) into `id → singular`.
    ///
    /// Principal-position files are large — they carry an administrative history and the whole
    /// list of officeholders — so only the header is of interest here.
    ///
    /// Whitespace is **collapsed**, not just trimmed. `positions-principals` hard-wraps long
    /// titles inside the element, so `<singular>` genuinely contains a newline and twelve spaces:
    /// "Assistant Secretary of State for International Narcotics and Law Enforcement\n
    /// Affairs". Trimming alone leaves that intact and the label reaches the UI broken across a
    /// line — measured, 6 of the 83 principal positions are wrapped this way.
    public static func parseRoleTable(xml: String) -> (id: String, name: String)? {
        guard let id = firstTag(xml, "id")?.trimmed, !id.isEmpty else { return nil }
        // `<names><singular>` — scoped to the names block so an officeholder's own `<singular>`
        // (there is none today, but the files are deeply nested) cannot be picked up instead.
        guard let names = firstBlock(xml, "names"),
              let raw = firstTag(names, "singular") else { return nil }
        let singular = raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return singular.isEmpty ? nil : (id, singular)
    }

    /// A display label for a territory or organization slug.
    ///
    /// POCOM ships **no** label table for these — a mission file states only
    /// `<territory-id>afghanistan</territory-id>` — so the slug is all there is. Measured across
    /// the checkout there are 204 of them and **every one** matches `[a-z0-9-]+`, so title-casing
    /// handles them, with two adjustments:
    ///
    /// - a trailing four-digit disambiguator is dropped (`albania-1946` → "Albania"), because it
    ///   distinguishes two mission *records*, not two places, and the assignment's own dates
    ///   already say which era it is;
    /// - conjunctions and prepositions stay lower-case (`antigua-and-barbuda` → "Antigua and
    ///   Barbuda", not "Antigua And Barbuda").
    public static func humanize(territoryId: String) -> String {
        var slug = territoryId.trimmed.lowercased()
        if let range = slug.range(of: #"-\d{4}$"#, options: .regularExpression) {
            slug.removeSubrange(range)
        }
        let words = slug.split(separator: "-").map(String.init)
        return words.enumerated().map { index, word in
            if Self.acronyms.contains(word) { return word.uppercased() }
            return (index > 0 && Self.smallWords.contains(word)) ? word : word.capitalizedFirstLetter
        }.joined(separator: " ")
    }

    /// Conjunctions and prepositions that stay lower-case inside a label.
    static let smallWords: Set<String> = ["and", "of", "the", "for", "in", "to", "at", "on",
                                          "da", "de"]

    /// Slug tokens that are organisation acronyms and must not be title-cased.
    ///
    /// POCOM ships no label table for `missions-orgs` roles, so those 13 role ids fall through to
    /// ``humanize(territoryId:)`` — and without this set they render "Representative to Nato" and
    /// "Representative to Un", which is worse than showing the raw slug. Measured: 93 assignments
    /// across 11 distinct org roles in the shipped index. The list is derived from the ids the
    /// generator actually reported as unresolved, not guessed.
    static let acronyms: Set<String> = ["eu", "un", "unesco", "unido", "uneo", "unvo", "unafa",
                                        "nato", "oas", "oecd", "iaea", "icao", "us", "ussr", "uk"]

    // MARK: - People

    /// Parses one `people/{letter}/{slug}.xml` record into `(slug, name, birth, death)`.
    ///
    /// The name is assembled from `<surname>`/`<forename>` into the "Surname, Given" form the rest
    /// of the app uses. A record with neither is skipped rather than emitted nameless — a career
    /// list headed by an empty string is worse than no career list.
    public static func parsePerson(xml: String) -> (slug: String, name: String, birth: Int?, death: Int?)? {
        guard let slug = firstTag(xml, "id")?.trimmed, !slug.isEmpty else { return nil }
        let surname = (firstTag(xml, "surname") ?? "").trimmed
        let forename = (firstTag(xml, "forename") ?? "").trimmed
        let name: String
        switch (surname.isEmpty, forename.isEmpty) {
        case (false, false): name = "\(surname), \(forename)"
        case (false, true):  name = surname
        case (true, false):  name = forename
        case (true, true):   return nil
        }
        return (slug, name, Int(firstTag(xml, "birth")?.trimmed ?? ""),
                Int(firstTag(xml, "death")?.trimmed ?? ""))
    }

    // MARK: - Appointments

    /// One appointment as it comes out of a mission or principal-position file, before labels are
    /// resolved.
    public struct RawAppointment: Sendable, Equatable {
        public let personId: String
        public let roleId: String?
        public let placeId: String?
        public let appointed: String?
        public let started: String?
        public let ended: String?
        public let endNote: String?
    }

    /// Parses every `<chief>` in a mission file, or every `<principal>` in a principal-position
    /// file.
    ///
    /// - Parameters:
    ///   - tag: `"chief"` or `"principal"`.
    ///   - fallbackRoleId: principal-position files state the role once in the file header rather
    ///     than on each officeholder, so the caller passes it down.
    public static func parseAppointments(xml: String, tag: String,
                                         fallbackRoleId: String? = nil) -> [RawAppointment] {
        blocks(xml, tag).compactMap { block in
            guard let person = firstTag(block, "person-id")?.trimmed, !person.isEmpty else { return nil }
            return RawAppointment(
                personId: person,
                roleId: firstTag(block, "role-title-id")?.trimmed ?? fallbackRoleId,
                placeId: firstTag(block, "contemporary-territory-id")?.trimmed
                    ?? firstTag(block, "org-id")?.trimmed,
                appointed: dateIn(block, "appointed"),
                started: dateIn(block, "started"),
                ended: dateIn(block, "ended"),
                endNote: noteIn(block, "ended"))
        }
    }

    /// The `<date>` inside a named event block (`<appointed><date>1935-01-22</date></appointed>`).
    ///
    /// The nesting is why a naive `<appointed>(\d{4})` scan finds nothing: the year is one level
    /// down, and the event element also carries a `<note>`.
    static func dateIn(_ block: String, _ event: String) -> String? {
        guard let inner = firstBlock(block, event),
              let date = firstTag(inner, "date")?.trimmed, !date.isEmpty else { return nil }
        return date
    }

    /// The `<note>` inside a named event block, when it says something.
    static func noteIn(_ block: String, _ event: String) -> String? {
        guard let inner = firstBlock(block, event),
              let note = firstTag(inner, "note")?.trimmed, !note.isEmpty else { return nil }
        return note
    }

    // MARK: - Chiefs of mission (version 2)

    /// First day of the window the `chiefs` table covers. 1861 is FRUS's first year.
    public static let chiefsWindowFirstDay = "1861-01-01"

    /// Days before ``chiefsWindowFirstDay`` that a row's last day may fall and the row still ship.
    ///
    /// The app's addressee rule lets a letter reach a chief for 90 days after the register's last day
    /// (`ChiefsOfMissionRoster.graceDaysAfterLastDay`), and decides only when exactly ONE name-matching
    /// person covers the date. A letter of early 1861 can therefore reach a chief whose tenure ended in
    /// late 1860, and a table cut at ``chiefsWindowFirstDay`` would hide that person from the count the
    /// rule's uniqueness rests on. Keep this at least the app's grace; the app's bundled-table test pins
    /// the pair by the first row it admits (`ward-john-elliott`, China, ended 1860-12-15).
    public static let chiefsWindowGraceDays = 90

    /// The earliest last day a row may have and still ship: ``chiefsWindowFirstDay`` less
    /// ``chiefsWindowGraceDays``. A literal, so a reader sees the edge; a test recomputes it.
    public static let chiefsWindowEarliestLastDay = "1860-10-03"

    /// Last day of the window the `chiefs` table covers. 1906 is the last year of the Department's
    /// numbered diplomatic instruction and despatch series, which the table helps Source Explorer
    /// choose between.
    public static let chiefsWindowLastDay = "1906-12-31"

    /// One served `<chief>` row from a country-mission file, before the window and the derived end
    /// are applied.
    public struct RawChief: Sendable, Equatable {
        /// The register's chief id (`fr-1861-dayt-01`). It is not unique registry-wide, so it is
        /// only ever a sort tie-break, never a key.
        public let chiefId: String
        /// The person's POCOM slug.
        public let personId: String
        /// The POCOM role id.
        public let roleId: String
        /// Date of appointment, as the register writes it.
        public let appointed: String?
        /// Date the chief took up the post, as the register writes it.
        public let started: String?
        /// Date they left it, as the register writes it.
        public let ended: String?
    }

    /// Reads a country-mission file's `<territory-id>`, its served chiefs, and its nominee count.
    ///
    /// Only a `<chief>` inside `<chiefs>` is a served row. `<other-nominees>` uses the same element
    /// for people nominated or commissioned who did not serve as listed (France's Pinckney, "not
    /// received by the Directory"). A whole-file scan would admit them, and that whole-file scan is
    /// exactly what ``parseAppointments(xml:tag:fallbackRoleId:)`` does for `careers`.
    ///
    /// A row naming no person or no role is skipped, because it cannot be matched to a letter.
    ///
    /// - Returns: `nil` when the file states no `<territory-id>`.
    public static func parseCountryMission(xml: String)
    -> (territoryId: String, served: [RawChief], otherNominees: Int)? {
        guard let territory = firstTag(xml, "territory-id")?.trimmed, !territory.isEmpty else {
            return nil
        }
        let served = blocks(firstBlock(xml, "chiefs") ?? "", "chief").compactMap { block -> RawChief? in
            guard let person = firstTag(block, "person-id")?.trimmed, !person.isEmpty,
                  let role = firstTag(block, "role-title-id")?.trimmed, !role.isEmpty else { return nil }
            return RawChief(chiefId: firstTag(block, "id")?.trimmed ?? "", personId: person,
                            roleId: role, appointed: dateIn(block, "appointed"),
                            started: dateIn(block, "started"), ended: dateIn(block, "ended"))
        }
        let nominees = blocks(firstBlock(xml, "other-nominees") ?? "", "chief").count
        return (territory, served, nominees)
    }

    /// Parses one person record's name parts for the `names` table.
    ///
    /// Reads the `<persName>` block only, and collapses whitespace in every value: two register
    /// altnames carry a trailing space. An empty `<genName>` reads as absent, and the first
    /// NON-EMPTY `<altname>` is kept. A record with no surname yields `nil`, because the surname
    /// is what the app matches a letter's addressee against.
    ///
    /// ``parsePerson(xml:)`` is deliberately left alone: `careers` must stay byte-identical, and it
    /// only trims.
    public static func parsePersonName(xml: String) -> (slug: String, name: POCOMPersonName)? {
        guard let slug = firstTag(xml, "id")?.trimmed, !slug.isEmpty,
              let persName = firstBlock(xml, "persName") else { return nil }
        let surname = (firstTag(persName, "surname") ?? "").collapsedWhitespace
        guard !surname.isEmpty else { return nil }
        let forename = (firstTag(persName, "forename") ?? "").collapsedWhitespace
        let genName = (firstTag(persName, "genName") ?? "").collapsedWhitespace
        let altname = blocks(persName, "altname").map(\.collapsedWhitespace).first { !$0.isEmpty }
        return (slug, POCOMPersonName(sn: surname, fn: forename,
                                      g: genName.isEmpty ? nil : genName, a: altname))
    }

    /// A row's first day: the EARLIER of its floored appointment and start dates.
    ///
    /// It is not `appointed ?? started`. The register has an in-window row whose appointment
    /// FOLLOWS its start (`do-1885-thom-01`), and taking the appointment first would open that
    /// tenure late.
    static func firstDay(of chief: RawChief) -> String? {
        [chief.appointed, chief.started].compactMap { $0.flatMap(floorDay) }.min()
    }

    /// The first day a register date can mean. `1864` → `1864-01-01`, `1866-04` → `1866-04-01`,
    /// and a full date is unchanged.
    ///
    /// Accepts the same shapes as the app's `POCOMPartialDate.floorISO` and refuses the same ones:
    /// anything that is not `YYYY`, `YYYY-MM` or a real `YYYY-MM-DD` is `nil`. Measured, every
    /// dated event in `missions-countries` has one of the three shapes.
    static func floorDay(_ raw: String) -> String? {
        guard let parts = dateParts(raw) else { return nil }
        return isoDay(parts.year, parts.month ?? 1, parts.day ?? 1)
    }

    /// The last day a register date can mean. `1864` → `1864-12-31`, `1866-04` → `1866-04-30`, and
    /// a full date is unchanged. Refuses the same shapes as ``floorDay(_:)``.
    static func ceilDay(_ raw: String) -> String? {
        guard let parts = dateParts(raw) else { return nil }
        let month = parts.month ?? 12
        return isoDay(parts.year, month, parts.day ?? daysIn(month: month, year: parts.year))
    }

    /// The day before a full `YYYY-MM-DD` date, across month and year ends and leap days. `nil`
    /// for anything else.
    static func dayBefore(_ iso: String) -> String? {
        guard let parts = dateParts(iso), let month = parts.month, let day = parts.day else {
            return nil
        }
        if day > 1 { return isoDay(parts.year, month, day - 1) }
        if month > 1 { return isoDay(parts.year, month - 1, daysIn(month: month - 1, year: parts.year)) }
        return isoDay(parts.year - 1, 12, 31)
    }

    private static func dateParts(_ raw: String) -> (year: Int, month: Int?, day: Int?)? {
        let pieces = raw.trimmingCharacters(in: .whitespaces)
            .split(separator: "-", omittingEmptySubsequences: false)
        guard (1...3).contains(pieces.count), pieces[0].count == 4, let year = Int(pieces[0]) else {
            return nil
        }
        var month: Int?
        var day: Int?
        if pieces.count >= 2 {
            guard pieces[1].count == 2, let m = Int(pieces[1]), (1...12).contains(m) else { return nil }
            month = m
        }
        if pieces.count == 3, let m = month {
            guard pieces[2].count == 2, let d = Int(pieces[2]),
                  (1...daysIn(month: m, year: year)).contains(d) else { return nil }
            day = d
        }
        return (year, month, day)
    }

    private static func daysIn(month: Int, year: Int) -> Int {
        switch month {
        case 2: return (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)) ? 29 : 28
        case 4, 6, 9, 11: return 30
        default: return 31
        }
    }

    private static func isoDay(_ year: Int, _ month: Int, _ day: Int) -> String {
        String(format: "%04ld-%02ld-%02ld", year, month, day)
    }

    // MARK: - Full build

    /// Builds the index from a POCOM checkout.
    ///
    /// - Parameter keepSlug: when non-nil, only these slugs are emitted into `careers`. The runner
    ///   passes the set the app can actually reach through the authority index, which keeps the
    ///   bundled careers to the people who will ever be looked up. The version-2 `chiefs`, `names`
    ///   and `roles` tables IGNORE it: the chief of mission a letter is addressed to need not be
    ///   anyone the authority index reaches.
    public static func build(checkout: URL, version: Int, generated: String, source: String,
                             keepSlug: Set<String>? = nil)
    throws -> (index: POCOMIndex, stats: POCOMBuildStats) {
        var stats = POCOMBuildStats()
        let fm = FileManager.default

        func read(_ url: URL) -> String? {
            guard let data = try? Data(contentsOf: url) else { return nil }
            return String(data: data, encoding: .utf8)
        }
        func xmlFiles(_ subpath: String) -> [URL] {
            let dir = checkout.appendingPathComponent(subpath, isDirectory: true)
            guard let all = try? fm.subpathsOfDirectory(atPath: dir.path) else { return [] }
            // Filename-sorted so a rebuild is byte-identical.
            return all.filter { $0.hasSuffix(".xml") }.sorted()
                .map { dir.appendingPathComponent($0) }
        }

        // 1. Role labels, from both tables.
        var roleNames: [String: String] = [:]
        for url in xmlFiles("roles-country-chiefs") + xmlFiles("positions-principals") {
            guard let xml = read(url), let role = parseRoleTable(xml: xml) else { continue }
            roleNames[role.id] = role.name
        }

        // 2. People.
        var people: [String: (name: String, birth: Int?, death: Int?)] = [:]
        var nameParts: [String: POCOMPersonName] = [:]
        for url in xmlFiles("people") {
            guard let xml = read(url) else { continue }
            stats.personFiles += 1
            if let parsed = parsePersonName(xml: xml) { nameParts[parsed.slug] = parsed.name }
            guard let p = parsePerson(xml: xml) else { continue }
            people[p.slug] = (p.name, p.birth, p.death)
        }

        // 3. Appointments from all three sources. A country-mission file is also read for its
        //    served chiefs here, rather than a second time below.
        var raw: [RawAppointment] = []
        var servedByTerritory: [String: [RawChief]] = [:]
        for url in xmlFiles("missions-countries") {
            guard let xml = read(url) else { continue }
            let found = parseAppointments(xml: xml, tag: "chief")
            stats.countryChiefs += found.count
            raw += found
            if let mission = parseCountryMission(xml: xml) {
                servedByTerritory[mission.territoryId, default: []] += mission.served
                stats.servedChiefRows += mission.served.count
                stats.otherNomineeChiefRows += mission.otherNominees
            }
        }
        for url in xmlFiles("missions-orgs") {
            guard let xml = read(url) else { continue }
            let found = parseAppointments(xml: xml, tag: "chief")
            stats.orgChiefs += found.count
            raw += found
        }
        for url in xmlFiles("positions-principals") {
            guard let xml = read(url) else { continue }
            // The role is stated once in the file header; officeholders do not repeat it.
            let roleId = firstTag(xml, "id")?.trimmed
            let found = parseAppointments(xml: xml, tag: "principal", fallbackRoleId: roleId)
            stats.principals += found.count
            raw += found
        }

        // 4. Fold into per-person careers.
        var byPerson: [String: [POCOMAssignment]] = [:]
        for appointment in raw {
            if let keepSlug, !keepSlug.contains(appointment.personId) { continue }
            guard people[appointment.personId] != nil else {
                stats.appointmentsWithNoPerson += 1
                continue
            }
            let roleLabel: String
            if let id = appointment.roleId {
                if let name = roleNames[id] {
                    roleLabel = name
                } else {
                    // Reported, never silently dropped: an unresolved role id means the register
                    // gained a title the tables do not carry, and the assignment is still real.
                    stats.unknownRoleIds.insert(id)
                    roleLabel = humanize(territoryId: id)
                }
            } else {
                roleLabel = ""
            }
            byPerson[appointment.personId, default: []].append(POCOMAssignment(
                r: roleLabel,
                p: appointment.placeId.map(humanize(territoryId:)),
                ap: appointment.appointed, st: appointment.started,
                en: appointment.ended, nt: appointment.endNote))
        }

        var careers: [String: POCOMCareer] = [:]
        for (slug, assignments) in byPerson {
            guard let person = people[slug] else { continue }
            // Total order: date, then role, then place, so a rebuild is byte-identical even when
            // two posts share a start date (a chargé and an ambassador on the same day).
            let sorted = assignments.sorted {
                ($0.sortKey, $0.r, $0.p ?? "") < ($1.sortKey, $1.r, $1.p ?? "")
            }
            careers[slug] = POCOMCareer(n: person.name, b: person.birth, d: person.death, a: sorted)
            stats.assignmentsEmitted += sorted.count
        }
        stats.careersEmitted = careers.count

        // 5. Chiefs of mission (version 2), independent of keepSlug.
        var chiefs: [String: [POCOMChiefRow]] = [:]
        var chiefNames: [String: POCOMPersonName] = [:]
        var chiefRoles: [String: String] = [:]
        for (territory, rows) in servedByTerritory {
            let firstDays = rows.map(firstDay(of:))
            // Every placeable start at this territory across the WHOLE register, not just the
            // window. A 1905 open row is capped by a 1910 successor the table never emits.
            let allStarts = firstDays.compactMap { $0 }
            var kept: [(first: String, chiefId: String, position: Int, row: POCOMChiefRow)] = []
            for (position, chief) in rows.enumerated() {
                guard let first = firstDays[position] else {
                    stats.chiefRowsWithoutStart += 1
                    continue
                }
                // `ex` only when the register states no end. A stated end that will not parse
                // (measured: none) leaves the tenure open for the window test and writes no `ex`,
                // so the app reads no last day and the row never matches a date.
                let derivedEnd = chief.ended == nil
                    ? allStarts.filter { $0 > first }.min().flatMap(dayBefore) : nil
                let lastDay = chief.ended == nil ? derivedEnd : chief.ended.flatMap(ceilDay)
                guard first <= chiefsWindowLastDay,
                      lastDay.map({ $0 >= chiefsWindowEarliestLastDay }) ?? true else {
                    stats.chiefRowsOutsideWindow += 1
                    continue
                }
                guard let name = nameParts[chief.personId] else {
                    stats.chiefRowsWithoutName += 1
                    continue
                }
                chiefNames[chief.personId] = name
                if chiefRoles[chief.roleId] == nil {
                    if let label = roleNames[chief.roleId] {
                        chiefRoles[chief.roleId] = label
                    } else {
                        stats.unknownRoleIds.insert(chief.roleId)
                        chiefRoles[chief.roleId] = humanize(territoryId: chief.roleId)
                    }
                }
                kept.append((first, chief.chiefId, position, POCOMChiefRow(
                    s: chief.personId, r: chief.roleId, ap: chief.appointed, st: chief.started,
                    en: chief.ended, ex: derivedEnd)))
            }
            guard !kept.isEmpty else { continue }
            // Total order: first day, slug, chief id, then file position. The last key only
            // separates rows that repeat all three, which the register's non-unique chief ids
            // make possible, so a rebuild never depends on sort stability.
            kept.sort {
                ($0.first, $0.row.s, $0.chiefId, $0.position) < ($1.first, $1.row.s, $1.chiefId, $1.position)
            }
            chiefs[territory] = kept.map(\.row)
            stats.derivedEndsWritten += kept.filter { $0.row.ex != nil }.count
        }

        return (POCOMIndex(version: version, generated: generated, source: source,
                           careers: careers, chiefs: chiefs, names: chiefNames, roles: chiefRoles),
                stats)
    }
}

// MARK: - Minimal XML scanning

// POCOM's files are small, flat, and machine-generated, and the fields wanted here are unambiguous
// element names. Scanning for them directly avoids building an `XMLDocument` per file across
// 4,700+ files, and keeps the parsers usable on a string in tests.

private func firstTag(_ xml: String, _ name: String) -> String? {
    guard let open = xml.range(of: "<\(name)>"),
          let close = xml.range(of: "</\(name)>", range: open.upperBound..<xml.endIndex)
    else { return nil }
    return String(xml[open.upperBound..<close.lowerBound])
}

private func firstBlock(_ xml: String, _ name: String) -> String? {
    guard let open = xml.range(of: "<\(name)>"),
          let close = xml.range(of: "</\(name)>", range: open.upperBound..<xml.endIndex)
    else { return nil }
    return String(xml[open.upperBound..<close.lowerBound])
}

private func blocks(_ xml: String, _ name: String) -> [String] {
    var result: [String] = []
    var cursor = xml.startIndex
    while let open = xml.range(of: "<\(name)>", range: cursor..<xml.endIndex),
          let close = xml.range(of: "</\(name)>", range: open.upperBound..<xml.endIndex) {
        result.append(String(xml[open.upperBound..<close.lowerBound]))
        cursor = close.upperBound
    }
    return result
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    /// Trimmed, with every internal whitespace run collapsed to a single space.
    var collapsedWhitespace: String { split(whereSeparator: \.isWhitespace).joined(separator: " ") }
    /// Upper-cases the first character and leaves the rest alone.
    ///
    /// `capitalized` would additionally lower-case everything after the first letter of each
    /// word, which is wrong for any slug that is not already lower-case. Every POCOM slug is
    /// (measured: all 204), so today the two agree — this is the safer of two equivalent choices,
    /// not a fix for a live defect.
    var capitalizedFirstLetter: String {
        guard let first else { return self }
        return String(first).uppercased() + dropFirst()
    }
}
