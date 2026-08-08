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
/// | `missions-countries/*.xml` | chiefs of mission to countries | 5,743 appointments |
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

    // MARK: - Full build

    /// Builds the index from a POCOM checkout.
    ///
    /// - Parameter keepSlug: when non-nil, only these slugs are emitted. The runner passes the set
    ///   the app can actually reach through the authority index, which keeps the bundled artifact
    ///   to the people who will ever be looked up.
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
        for url in xmlFiles("people") {
            guard let xml = read(url) else { continue }
            stats.personFiles += 1
            guard let p = parsePerson(xml: xml) else { continue }
            people[p.slug] = (p.name, p.birth, p.death)
        }

        // 3. Appointments from all three sources.
        var raw: [RawAppointment] = []
        for url in xmlFiles("missions-countries") {
            guard let xml = read(url) else { continue }
            let found = parseAppointments(xml: xml, tag: "chief")
            stats.countryChiefs += found.count
            raw += found
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

        return (POCOMIndex(version: version, generated: generated, source: source,
                           careers: careers), stats)
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
