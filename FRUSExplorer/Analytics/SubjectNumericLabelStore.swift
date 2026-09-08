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
/// The subject-numeric system replaced the decimal file in 1963 and the app has never had a label
/// table for it, so every one of these keys renders bare. Measured on the shipped corpus, they are
/// not a fringe: they are 1,362 leaves folding to 323 groups over 6,882 documents, and they
/// dominate the class lens in the later era bands.
///
/// ## Two editions, and reading a key against the wrong one is not a near miss
/// The 1965 handbook renumbered subdivisions inside the categories FRUS cites hardest. `POL 24` is
/// **SUBVERSION. ESPIONAGE. SABOTAGE.** under the 1963 arrangement and **SANCTIONS** under the one
/// that took effect in January 1964, with subversion moved to `POL 23-7`. POL alone carries about
/// two thirds of the corpus's subject-numeric documents, so a single merged table would mislabel
/// the most-cited category in the vocabulary. This is the 1950 decimal renumbering again, and it is
/// handled the same way: a coverage span that straddles the two schedules is refused rather than
/// guessed at.
///
/// ## What this table names, and what it does not
/// It names the GROUP — the category and its number. Measured, 90.4% of the corpus's
/// subject-numeric keys also carry a trailing country or party string (`VIET S`, `ARAB-ISR`), which
/// comes from the handbooks' country-abbreviations appendix and is not read yet. A surface showing
/// `POL 27 VIET S` must therefore print the tail as the source wrote it; glossing the group and
/// dropping the rest would name half the key and look complete.
///
/// Version history:
///   1.0 — #1211: initial implementation
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

        /// Whether this schedule speaks for a coverage span.
        ///
        /// The same rule the decimal table applies, and the clamp matters for the same reason: a
        /// FRUS volume covering 1958–1965 opens before the subject-numeric file existed, and
        /// requiring literal containment at both ends would silence it although every
        /// subject-numeric key in it was filed under one arrangement.
        ///
        /// - Parameters:
        ///   - span: The coverage years being described.
        ///   - floor: The year the subject-numeric file opens.
        /// - Returns: Whether this schedule governs the span.
        func governs(_ span: ClosedRange<Int>, floor: Int) -> Bool {
            guard span.upperBound >= floor else { return false }
            return max(span.lowerBound, floor) >= startYear && span.upperBound <= endYear
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

    /// A key's subject in plain words, or `nil` when this table cannot say.
    ///
    /// Silence is the designed outcome, exactly as it is for the decimal table: a wrong subject on
    /// an archival citation is worse than a bare code, because the reader cannot tell it is wrong.
    ///
    /// - Parameters:
    ///   - key: A class key as a source note wrote it (`"POL 27"`, `"POL 27 VIET S"`).
    ///   - span: The coverage years the surface's figures describe.
    /// - Returns: `"MILITARY OPERATIONS"`, or `nil`.
    func gloss(for key: String, coveringYears span: ClosedRange<Int>) -> String? {
        guard let schedule = schedules.first(where: {
            $0.governs(span, floor: coverage.systemOpensIn)
        }) else { return nil }
        guard let (category, designator) = Self.split(key) else { return nil }
        return schedule.subjects[category]?[designator]
    }

    /// Splits a class key into its category and its designator.
    ///
    /// The split mirrors `CollectionKeying.subjectNumericGroup`'s anchored match and then divides
    /// the group. It deliberately tolerates the missing space that fold must preserve: `DEF1-1` is
    /// a key the corpus really carries, and #841 forbids the fold from rewriting it to `DEF 1-1`,
    /// so the LOOKUP is where the two spellings are allowed to meet.
    ///
    /// - Parameter key: A class key.
    /// - Returns: `("POL", "27")`, or `nil` when the key is not subject-numeric.
    static func split(_ key: String) -> (category: String, designator: String)? {
        guard CollectionKeying.isSubjectNumericClass(key),
              let splitRegex,
              let match = splitRegex.firstMatch(
                in: key, range: NSRange(key.startIndex..., in: key)),
              let category = Range(match.range(at: 1), in: key),
              let number = Range(match.range(at: 2), in: key)
        else { return nil }
        return (String(key[category]).uppercased(),
                String(key[number]).replacingOccurrences(
                    of: #"\s"#, with: "", options: .regularExpression))
    }

    /// Category letters, an optional parenthesised agency qualifier, then the number.
    private static let splitRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^([A-Z]{1,6})(?:\s*\([^)]*\))?\s*(\d+(?:-\d+)*)"#)
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
