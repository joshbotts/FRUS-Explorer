// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - SubjectNumericLabelTable

/// The Department's subject-numeric filing schedules, so `POL 27` reads as *Military
/// Operations* rather than as a code (#1211).
///
/// The subject-numeric system replaced the decimal file in 1963 and the app had no label table
/// for it until #1211, so every one of these keys rendered bare. Measured on the shipped corpus
/// they are not a fringe: 1,362 leaves folding to 323 groups over 6,883 documents, and they
/// dominate the class lens in the later era bands.
///
/// ## Two editions, and reading a key against the wrong one is not a near miss
/// The 1965 handbook renumbered subdivisions inside the categories FRUS cites hardest. `POL 24` is
/// **SUBVERSION. ESPIONAGE. SABOTAGE.** under the 1963 arrangement and **SANCTIONS** under the one
/// that took effect in January 1964, with subversion moved to `POL 23-7`. POL alone carries about
/// two thirds of the corpus's subject-numeric documents, so a single merged table would mislabel
/// the most-cited category in the vocabulary. This is the 1950 decimal renumbering again. Until A16
/// it was handled the same way, a coverage span that straddles the two schedules refused outright;
/// since A16 (#1691's third line, the owner's decision 68 of 2026-10-19) such a span reads what both
/// editions print alike and nothing else: the country always, since the two list all 433 areas
/// identically, and the subject where the words match, compared without spaces, case or full
/// stops — 1,095 of the 1,359 designators both print, measured 2026-10-19 — in the later edition's
/// spelling. The 264 that differ stay blank, `POL 24` among them. The decimal table's rule across
/// 1950 is unchanged. The volumes made the rule necessary: a family's citing volumes in the
/// 1961–1968 era span 1961–1969 for `POL 27`, so no subject-numeric file in that era had a label.
///
/// ## The file's own years clamp a span at both ends
/// A FRUS volume covering 1958–1965 opens before the subject-numeric file existed, and one covering
/// 1969–1977 closes after it: the Department replaced it with the Central Foreign Policy File in
/// 1973. Neither holds a subject-numeric key from the years outside the file to mislabel, so a span
/// is clamped to the file's years before an edition is asked (the owner's decision of 2026-10-20,
/// A16, extending the floor clamp of #1211 to a ceiling). In the 1969–1976 era 557 files over 1,789
/// documents were bare for the ceiling alone, `POL 27` among them (its volumes span 1968–1975).
///
/// ## What this table names, and what it does not
/// It names the GROUP — the category and its number. Most of the corpus's subject-numeric keys
/// also carry a trailing country or party string (`VIET S`, `ARAB-ISR`), and since #1254 it IS
/// read: `Schedule.areas` resolves it — 1,617 of 1,781 such keys and 93.9% of their documents
/// at index version 69 (#1644) — from the 1963 handbook's list of standard country codes, which
/// the 1965 edition leaves out of print and refers to, so both schedules read one list. `leafGloss`
/// then composes the reading in NARA's FILING order rather than the citation's: `POL 27 VIET S` is
/// *Vietnam, South — MILITARY OPERATIONS*. A key with no tail reads as its subject alone, which
/// is the general file and not an omission.
///
/// Version history:
///   1.0 — #1211: initial implementation
///   1.1 — index version 69: a file with no subject number. A category alone reads "Files with
///          no subject number" under either schedule, and such a file reads as its country and
///          nothing before or after it; a key is divided by
///          `CollectionKeying.subjectNumericParts(of:)`, where the fold cuts it
///   1.2 — 2026-10-20 (A16, #1691's third line, decision 68): a span reaching both editions reads
///          its country, and its subject where both print the same words; a span is clamped to
///          the file's own years at both ends (`editions(coveringYears:)`)
struct SubjectNumericLabelTable: Decodable, Sendable {

    /// One edition's schedule.
    struct Schedule: Decodable, Sendable {
        /// Schedule id, e.g. `"1963"`.
        let id: String
        /// First year this arrangement governs.
        let startYear: Int
        /// Last year it governs.
        let endYear: Int
        /// `POL` -> `POLITICAL AFFAIRS & RELATIONS`.
        let categories: [String: String]
        /// `POL` -> `27` -> `MILITARY OPERATIONS`.
        let subjects: [String: [String: String]]
        /// `6` -> `MEMBERSHIP. ASSOCIATION.` — the list an ORGANIZATION's file is arranged by.
        let organizationSubjects: [String: String]
        /// `NATO` -> `North Atlantic Treaty Organization`, from the handbook's own abbreviations
        /// appendix. Its presence is what identifies a prefix as an organization file.
        let abbreviations: [String: String]
        /// `VIET S` -> `Vietnam, South` — the country, region or organization the file is
        /// arranged under, resolved for every tail the corpus writes.
        let areas: [String: String]

        /// Whether this schedule governs any year of a coverage span, clamped to the file's own
        /// years.
        ///
        /// The clamp is the decimal table's at the floor and, since A16, its mirror at the
        /// ceiling: a FRUS volume covering 1958–1965 opens before the subject-numeric file
        /// existed and one covering 1969–1977 closes after it, and neither holds a key from those
        /// years to mislabel, so requiring literal containment at either end silenced volumes
        /// every one of whose subject-numeric keys was filed under one arrangement. A span wholly
        /// outside the file's years touches nothing.
        ///
        /// - Parameters:
        ///   - span: The coverage years being described.
        ///   - floor: The year the subject-numeric file opens.
        ///   - ceiling: The year it closes.
        /// - Returns: Whether this schedule governs any of the span's years inside the file's.
        func touches(_ span: ClosedRange<Int>, floor: Int, ceiling: Int) -> Bool {
            guard span.upperBound >= floor, span.lowerBound <= ceiling else { return false }
            return max(span.lowerBound, floor) <= endYear && min(span.upperBound, ceiling) >= startYear
        }

        /// A key's subject, from its own outline or from the organization list.
        ///
        /// The outline is tried FIRST and the shared list only when the category is not a primary
        /// subject, because designators collide across the two: `POL 6` is *People. Biographic
        /// Data.* and the list's `6` is *Membership. Association.*
        ///
        /// - Parameters:
        ///   - category: The key's category letters.
        ///   - designator: Its number.
        /// - Returns: The subject, or `nil`.
        func subject(category: String, designator: String) -> String? {
            if let outline = subjects[category] { return outline[designator] }
            guard abbreviations[category] != nil else { return nil }
            return organizationSubjects[designator]
        }
    }

    /// Wire schema version.
    let schemaVersion: Int
    /// Build stamp.
    let generated: String
    /// The editions, in force order.
    let schedules: [Schedule]
    /// What the table can and cannot answer.
    let coverage: Coverage

    /// The published contract.
    struct Coverage: Decodable, Sendable {
        /// First year the subject-numeric file was in use.
        let systemOpensIn: Int
        /// The verdict for a key outside every span.
        let keyOutsideGlossableYears: String
        /// Categories the corpus cites that no schedule names.
        let unnamedCategories: [String]
        /// The caveats a surface owes a reader.
        let note: String
    }

    /// The year the subject-numeric file closes: the last schedule's last year, 1973.
    var systemClosesIn: Int { schedules.map(\.endYear).max() ?? coverage.systemOpensIn }

    /// The editions a coverage span reaches, in force order, once the span is clamped to the
    /// file's own years: one for a span inside an edition, or opening before the file or closing
    /// after it; both for a span crossing 1963 and 1964; none for a span outside the file.
    ///
    /// - Parameter span: The coverage years the surface's figures describe.
    /// - Returns: The schedules whose years the clamped span touches.
    func editions(coveringYears span: ClosedRange<Int>) -> [Schedule] {
        schedules.filter { $0.touches(span, floor: coverage.systemOpensIn, ceiling: systemClosesIn) }
    }

    /// Whether two labels print the same words: compared without spaces, case or full stops
    /// (decision 68's rule), so a word the scan broke or a stop one edition drops is not a
    /// difference.
    ///
    /// - Parameters:
    ///   - one: A label.
    ///   - other: Another.
    /// - Returns: Whether they are the same words.
    static func sameWords(_ one: String, _ other: String) -> Bool {
        func words(_ label: String) -> String {
            label.lowercased().filter { !$0.isWhitespace && $0 != "." }
        }
        return words(one) == words(other)
    }

    /// A key's subject across the editions a span reaches: the one edition's own, or, where every
    /// edition prints the same words, the later edition's spelling; `nil` where they differ or an
    /// edition has none.
    ///
    /// The later spelling because a straddling span is mostly the later edition's years (1963 is
    /// one year), and because that edition's cited labels were the ones read on the scan last.
    ///
    /// - Parameters:
    ///   - category: The key's category letters.
    ///   - designator: Its number.
    ///   - editions: The editions the span reaches, in force order.
    /// - Returns: The subject, or `nil`.
    private static func subject(category: String, designator: String,
                                across editions: [Schedule]) -> String? {
        guard let last = editions.last,
              let reading = last.subject(category: category, designator: designator) else { return nil }
        for edition in editions.dropLast() {
            guard let other = edition.subject(category: category, designator: designator),
                  sameWords(other, reading) else { return nil }
        }
        return reading
    }

    /// A key's country, region or organization element across the editions a span reaches: the
    /// name every edition gives the tail, or `nil` where one has none or they differ. The two
    /// schedules ship one list, so a tail either edition names is read for any span.
    ///
    /// - Parameters:
    ///   - tail: The tail as `normalizedTail` keys it.
    ///   - editions: The editions the span reaches.
    /// - Returns: The name, or `nil`.
    private static func area(_ tail: String, across editions: [Schedule]) -> String? {
        guard let name = editions.last?.areas[tail] else { return nil }
        return editions.allSatisfy { $0.areas[tail] == name } ? name : nil
    }

    /// A key's subject in plain words, or `nil` when this table cannot say.
    ///
    /// Silence is the designed outcome, exactly as it is for the decimal table: a wrong subject on
    /// an archival citation is worse than a bare code, because the reader cannot tell it is wrong.
    /// A span reaching both editions is read where they agree (decision 68), so `POL 27` over
    /// 1961–1969 reads *MILITARY OPERATIONS* and `POL 24` over the same years reads nothing.
    ///
    /// - Parameters:
    ///   - key: A class key as a source note wrote it (`"POL 27"`, `"POL 27 VIET S"`).
    ///   - span: The coverage years the surface's figures describe.
    /// - Returns: `"MILITARY OPERATIONS"`, or `nil`.
    func gloss(for key: String, coveringYears span: ClosedRange<Int>) -> String? {
        // A FILE UNDER THE PRIMARY SUBJECT ALONE has no subject number, so no schedule has a
        // subject to give it, and what it is does not depend on the edition (index version 69).
        // Only a head is said to be one: `gloss` is asked about a family, and such a file's
        // family is its head (`CollectionKeying.subjectNumericParts(of:)`). The handbooks' own
        // names for the categories are in the table and are not read here: the scan broke some
        // of them (`RAOIO`, `FOREI GN TRADE`), and `AID` has none in either edition.
        if let parts = CollectionKeying.subjectNumericParts(of: key), parts.number == nil {
            guard parts.group == key else { return nil }
            return String(localized: "archival.classLabel.noSubjectNumber",
                          defaultValue: "Files with no subject number")
        }
        let reached = editions(coveringYears: span)
        guard let last = reached.last, let (category, designator) = Self.split(key) else { return nil }

        // A PRIMARY SUBJECT file is arranged by its own outline; an ORGANIZATION file is arranged
        // by the international-organizations instruction's list of administrative subjects. The
        // category is tried first, and the list only when the handbook's abbreviations appendix
        // names the prefix — which is what stops the list being applied to `PSL 27` (a
        // one-character corruption of POL) and `NSSD 05-82` (a National Security Study Directive),
        // both of which would take a plausible subject from it otherwise. `Schedule.subject` keeps
        // that order in each edition.
        guard let subject = Self.subject(category: category, designator: designator,
                                         across: reached) else { return nil }
        guard last.subjects[category] == nil, let organization = last.abbreviations[category]
        else { return subject }
        // The organization's name is worth saying: a reader knows UN, and CENTO and SEATO are
        // another matter, and the key itself only ever shows the abbreviation.
        return String(format: String(localized: "archival.classLabel.organization %@ %@",
                                     defaultValue: "%1$@ — %2$@"),
                      organization, subject)
    }

    /// A leaf key's full reading, composed in the order NARA FILES the records.
    ///
    /// ## The filing order is not the citation order, and the label follows the filing
    /// A citation writes class, number, country — `POL 27 VIET S`. NARA files the records class,
    /// then country, then number: the country is the second level the drawers are organised on and
    /// the third element of the designation. So the label reads *Vietnam, South — Military
    /// Operations*, which is also the shape the decimal table's own glosses take (*Mexico —
    /// Petroleum*), because for the decimal file the written order and the filing order coincide.
    /// One reading for both filing systems is worth having: they share a lens.
    ///
    /// A key with no country element is not an omission — the handbooks provide general files for
    /// each primary subject, kept at the beginning or the end of its run — so such a key reads as
    /// its subject alone.
    ///
    /// A span reaching both editions reads the country always and the subject where the two
    /// print the same words (decision 68): `POL 27 VIET S` over 1961–1969 is *Vietnam, South —
    /// MILITARY OPERATIONS*, and `POL 24 VIET S` over the same years *Vietnam, South*.
    ///
    /// - Parameters:
    ///   - key: A full leaf key as a source note wrote it (`"POL 27 VIET S"`).
    ///   - span: The coverage years the surface's figures describe.
    /// - Returns: The composed reading, or `nil` when the table can say nothing at all.
    func leafGloss(for key: String, coveringYears span: ClosedRange<Int>) -> String? {
        let reached = editions(coveringYears: span)
        guard let last = reached.last,
              let divided = CollectionKeying.subjectNumericParts(of: key) else { return nil }
        let category = divided.category.uppercased()

        var parts: [String] = []
        // A file with no subject number reads as its area alone (index version 69): no subject
        // follows it, and no organization's name goes before it. The one category that reached
        // the organization branch with such a file was `AID` under 1964–1973, which had no outline
        // in that schedule and whose appendix entry was a piece of another line: 22 keys over 52
        // documents would have read "programs in Spanish speaking countries). Aeronautics —
        // India". Since #1644 the table has `AID`'s outline for that schedule and ships no
        // abbreviation for a category that has one, so no `AID` key reaches the branch at all.
        if divided.number != nil,
           let organization = last.subjects[category] == nil ? last.abbreviations[category] : nil {
            parts.append(organization)
        }
        if !divided.area.isEmpty,
           let area = Self.area(Self.normalizedTail(divided.area), across: reached) {
            parts.append(area)
        }
        if let designator = divided.number,
           let subject = Self.subject(category: category, designator: designator, across: reached) {
            parts.append(subject)
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " — ")
    }

    /// Whatever follows a key's group — the country, region or organization element — without a
    /// post (`USSR` of `DEF 18-3 USSR (MO)`).
    ///
    /// The division is the kit's, `CollectionKeying.subjectNumericParts(of:)`, so the key is cut
    /// here where the fold cuts it. The post is left off because it names a city inside the
    /// country the file is arranged under, and the area table would read the two as two parties:
    /// `SWITZ (GE)` is Switzerland's file at Geneva, not Switzerland and Germany.
    ///
    /// - Parameter key: A class key.
    /// - Returns: The tail, or `nil` when the key is not subject-numeric.
    static func tail(of key: String) -> String? {
        CollectionKeying.subjectNumericParts(of: key)?.area
    }

    /// A tail keyed the way the artifact stores it.
    ///
    /// - Parameter raw: The tail as a source note wrote it.
    /// - Returns: Upper case, punctuation dropped, spacing collapsed.
    static func normalizedTail(_ raw: String) -> String {
        raw.uppercased()
            .replacingOccurrences(of: #"[^A-Z0-9 -]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    /// Splits a class key into its category and its designator.
    ///
    /// The split is `CollectionKeying.subjectNumericParts(of:)`, the division the fold makes. It
    /// tolerates the missing space that fold must preserve: `DEF1-1` is a key the corpus really
    /// carries, and #841 forbids the fold from rewriting it to `DEF 1-1`, so the LOOKUP is where
    /// the two spellings are allowed to meet.
    ///
    /// - Parameter key: A class key.
    /// - Returns: `("POL", "27")`, or `nil` when the key is not subject-numeric or is a
    ///   primary-subject file, which has no designator.
    static func split(_ key: String) -> (category: String, designator: String)? {
        guard let parts = CollectionKeying.subjectNumericParts(of: key),
              let number = parts.number else { return nil }
        return (parts.category.uppercased(), number)
    }
}

// MARK: - SubjectNumericLabelStore

/// The bundled subject-numeric table, decoded once on first use (#1211).
enum SubjectNumericLabelStore {

    /// The table, or `nil` when the resource is absent or unreadable.
    ///
    /// Absence degrades to unlabelled keys, never to a crash — the state every build before this
    /// one shipped in.
    static let shared: SubjectNumericLabelTable? = load()

    private static func load() -> SubjectNumericLabelTable? {
        guard let url = Bundle.main.url(forResource: "subject-numeric-labels",
                                        withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            #if DEBUG
            print("[SubjectNumericLabelStore] subject-numeric-labels.json is not in the bundle; "
                + "subject-numeric keys will render unlabelled, as they did before #1211.")
            #endif
            return nil
        }
        return try? JSONDecoder().decode(SubjectNumericLabelTable.self, from: data)
    }
}
