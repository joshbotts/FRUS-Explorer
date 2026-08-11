// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - DecimalClassLabels

/// The bundled label table for State Department central-file decimal classes (#828, design
/// decision D-2).
///
/// ## The shape is compositional, and that is the whole design
/// A decimal file number is not an opaque identifier: in the country-arranged classes it is
/// `[class digit][country number].[subject suffix]` — `761.62` is *class 7, political relations,
/// between country 61 (the Soviet Union) and country 62 (Germany)*. So the table stores the three
/// vocabularies separately and composes a label at render time. Measured in the #764 feasibility
/// study: ~200 compositional rows cover **87.7%** of classed documents against 79.4% for a
/// thousand flat leaf rows — 3–5× the coverage per row of curation, which is why the schedule was
/// worth waiting for rather than routing around.
///
/// ## Era-scoped, because the same key means different things
/// The classification was **renumbered in 1950**: class 7 is "Political Relations of States" in
/// the 1910–49 schedule and "Internal Political and National Defense Affairs" in the 1950–59 one.
/// Country numbers moved too — Iran is 91 before 1950 and 88 after; Turkey 67 then 82. A table
/// that resolved a key without knowing which schedule it belongs to would be confidently wrong
/// rather than silent, so every lookup takes an era and a key that matches no schedule resolves to
/// nothing.
///
/// ## Every row carries its source
/// D-2's rule. The provenance is not decoration: the country table and the subject schedules come
/// from different NARA publications, the 1950s manual's scan is materially worse than the
/// 1910–49 one, and a reader who wants to check a label needs to know which document to open.
public struct DecimalClassLabels: Codable, Sendable, Equatable {

    /// Artifact schema version.
    public let schemaVersion: Int
    /// `yyyy-MM-dd` build stamp.
    public let generated: String
    /// What was parsed, from which documents, and what the caller must know about them.
    public let provenance: String
    /// The schedules, earliest first and non-overlapping.
    public let schedules: [Schedule]

    /// One era's classification schedule.
    public struct Schedule: Codable, Sendable, Equatable {
        /// Stable id (`"1910-1949"`).
        public let id: String
        /// First year the schedule governs.
        public let startYear: Int
        /// Last year the schedule governs.
        public let endYear: Int
        /// The publication this schedule's classes and subjects were read from.
        public let source: String
        /// `"7"` → `"Political Relations of States"`.
        public let classes: [String: String]
        /// The class digits arranged by country — the only ones a key decomposes in.
        ///
        /// Stored rather than inferred: it is a property of the schedule, and it changed at the
        /// 1950 renumbering (6/7/8 before, 3–9 after, with a different split).
        public let countryArrangedClasses: [String]
        /// `"62"` → `"Germany"`, for this era only.
        public let countries: [String: String]
        /// `classDigit` → (`suffix` → gloss), e.g. `"8"` → `"72"` → `"Telegraph"`.
        public let subjects: [String: [String: String]]
        /// Where each vocabulary came from, for the per-row stamp D-2 requires.
        public let sources: Sources

        /// The per-vocabulary provenance stamps.
        public struct Sources: Codable, Sendable, Equatable {
            /// Source of `classes` and `subjects`.
            public let schedule: String
            /// Source of `countries`.
            public let countries: String

            /// Creates the stamps.
            public init(schedule: String, countries: String) {
                self.schedule = schedule
                self.countries = countries
            }
        }

        /// Creates a schedule.
        public init(id: String, startYear: Int, endYear: Int, source: String,
                    classes: [String: String], countryArrangedClasses: [String],
                    countries: [String: String], subjects: [String: [String: String]],
                    sources: Sources) {
            self.id = id
            self.startYear = startYear
            self.endYear = endYear
            self.source = source
            self.classes = classes
            self.countryArrangedClasses = countryArrangedClasses
            self.countries = countries
            self.subjects = subjects
            self.sources = sources
        }

        /// Whether this schedule governs `year`.
        ///
        /// - Parameter year: A coverage year.
        /// - Returns: `true` when the year falls inside the schedule's span.
        public func governs(year: Int) -> Bool { year >= startYear && year <= endYear }
    }

    /// Creates the table.
    public init(schemaVersion: Int, generated: String, provenance: String,
                schedules: [Schedule]) {
        self.schemaVersion = schemaVersion
        self.generated = generated
        self.provenance = provenance
        self.schedules = schedules
    }
}

// MARK: - DecimalClassKey

/// One decimal class key, decomposed against a schedule (#828).
///
/// Decomposition is deliberately conservative: a key resolves only in a class the schedule says is
/// country-arranged, and only when the country slot is a code that schedule actually carries. A
/// key that does not decompose yields `nil` rather than a guess, because a wrong gloss on an
/// archival citation is worse than a bare number — the reader cannot tell it is wrong.
public struct DecimalClassKey: Sendable, Equatable {

    /// The leading class digit.
    public let classDigit: String
    /// The country number as written (`"51r"`, `"62"`).
    public let countryNumber: String
    /// The part after the dot, or `nil` when the key has none.
    public let subject: String?
    /// The second country, for the relations classes where the suffix is itself a country.
    public let secondCountry: String?

    /// Decomposes `key` against `schedule`.
    ///
    /// The relations reading is attempted only when the schedule says the class is
    /// country-arranged **and** the suffix is a country code in that same schedule; otherwise the
    /// suffix is read as a subject. That is what keeps `763.72` (two countries) apart from
    /// `811.114` (a country and a subject) without a hand-maintained exception list — the
    /// manual's own rule, "use smaller number of country for **", is what makes the two shapes
    /// distinguishable at all.
    ///
    /// - Parameters:
    ///   - key: A decimal class key as a source note wrote it.
    ///   - schedule: The era's schedule.
    /// - Returns: The decomposition, or `nil` when the key is not a decimal class of this era.
    public static func decompose(_ key: String,
                                 in schedule: DecimalClassLabels.Schedule) -> DecimalClassKey? {
        // `[digit][country][.suffix]`, the country slot being 1–2 digits plus an optional letter.
        let pattern = #"^(\d)(\d{1,2}[A-Za-z]?)(?:\.(.+))?$"#
        guard let match = key.range(of: pattern, options: .regularExpression),
              match.lowerBound == key.startIndex, match.upperBound == key.endIndex
        else { return nil }

        guard let regex = try? NSRegularExpression(pattern: pattern),
              let result = regex.firstMatch(in: key, range: NSRange(key.startIndex..., in: key))
        else { return nil }

        func group(_ index: Int) -> String? {
            guard let range = Range(result.range(at: index), in: key) else { return nil }
            return String(key[range])
        }
        guard let digit = group(1), let country = group(2) else { return nil }
        guard schedule.countryArrangedClasses.contains(digit) else { return nil }
        guard schedule.countries[country.lowercased()] != nil else { return nil }

        let suffix = group(3)
        // A suffix that is itself a country of this schedule reads as the other party.
        let second = suffix.flatMap { schedule.countries[$0.lowercased()] != nil ? $0 : nil }
        return DecimalClassKey(classDigit: digit, countryNumber: country,
                               subject: second == nil ? suffix : nil, secondCountry: second)
    }
}
