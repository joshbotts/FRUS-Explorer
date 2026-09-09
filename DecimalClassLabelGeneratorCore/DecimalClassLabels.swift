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
    /// What this file can and cannot gloss, stated as data (#1204).
    public let coverage: Coverage

    /// The era contract, machine-readable, so a consumer fails closed instead of composing.
    ///
    /// ## Why this exists beside `provenance`, which already says it in words
    /// `provenance` has carried the sentence *"a key resolves only against the schedule governing
    /// its own era"* since #828, and it did not stop the failure #1204 reports: the
    /// commercial-diplomacy run read `schedules[0]`, composed `411.48` for a 1958 document, and
    /// got *Claims — British Africa* where the editors gloss it **Poland**. A **plausible wrong
    /// answer, not a miss** — which is the whole hazard, because a reader cannot tell it is wrong.
    ///
    /// Prose in a long paragraph is not a contract a consumer can branch on. This is: one named
    /// object, three fields to test, and `keyOutsideGlossableYears` states the required verdict
    /// in a word rather than leaving it to be inferred.
    ///
    /// ## What it honestly cannot do
    /// **JSON cannot force a consumer to check anything.** A caller who ignores this block
    /// composes exactly the wrong gloss it composed before. What changed is that the correct
    /// behaviour is now cheap, testable and citable — `Docs/Agentic-Analysis-Guide.md` points at
    /// these fields — rather than buried in a paragraph about scanning. Treat the improvement as
    /// *discoverability*, not enforcement, and do not let a future reader mistake it for a guard.
    ///
    /// ## `notShipped` is the part that is more than a warning
    /// The generator parses all three manuals and skips two of them on measured floors. Recording
    /// the omission **with its numbers** turns an absence into a stated fact: a consumer asking
    /// "is there a 1958 schedule?" gets *no, and here is how short it fell*, where before it got
    /// silence indistinguishable from a schedule nobody attempted.
    public struct Coverage: Codable, Sendable, Equatable {

        /// The year the classification was renumbered, so a key's meaning changes across it.
        public let renumberedAt: Int
        /// The year the central decimal file opens — no decimal key predates it.
        ///
        /// Publishing this is what makes `glossableYears` reproducible against the app. The app
        /// gates on a VOLUME's coverage span, not a document date, and clamps that span's lower
        /// bound here before testing containment: a volume covering 1861–1947 carries no pre-1910
        /// decimal keys to mislabel, so refusing it outright would silence the very era this file
        /// exists to label. A consumer applying literal containment to a span instead drops those
        /// volumes; a consumer gating a DOCUMENT's own date needs no clamp, because a document
        /// dated before this year has no decimal key in the first place.
        public let decimalFileOpensIn: Int
        /// The spans this file can gloss — one per schedule actually shipped.
        public let glossableYears: [Span]
        /// The required verdict for a key dated outside every span above. Always `"no-gloss"`.
        public let keyOutsideGlossableYears: String
        /// The schedules that were parsed and refused, with the measurement that refused them.
        public let notShipped: [Omission]
        /// The rule in one sentence, for a reader who reaches this block before the guide.
        public let note: String

        /// One era's span.
        public struct Span: Codable, Sendable, Equatable {
            /// The schedule's stable id.
            public let scheduleId: String
            /// First year it governs.
            public let startYear: Int
            /// Last year it governs.
            public let endYear: Int
        }

        /// A schedule this build parsed and did not ship.
        public struct Omission: Codable, Sendable, Equatable {
            /// The schedule's stable id.
            public let scheduleId: String
            /// First year it would have governed.
            public let startYear: Int
            /// Last year it would have governed.
            public let endYear: Int
            /// The publication it was read from.
            public let source: String
            /// Why it was refused, in the generator's own words.
            public let reason: String
            /// What this build actually parsed out of it.
            public let parsed: Counts
            /// The floors it had to clear.
            public let floors: Counts
        }

        /// The three vocabularies a schedule needs, counted.
        public struct Counts: Codable, Sendable, Equatable {
            /// Class digits.
            public let classes: Int
            /// Subject suffixes, across every class.
            public let subjects: Int
            /// Country numbers.
            public let countries: Int
        }
    }

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
        /// The classes whose suffix is a SECOND COUNTRY rather than a subject.
        ///
        /// A strict subset of ``countryArrangedClasses``: in the 1910–49 schedule class 7 is
        /// "Political Relations of States" and reads country-to-country, while class 8 is
        /// "Internal Affairs of States" and reads country-plus-subject. Both are arranged by
        /// country and their keys are the same shape, so the distinction cannot be inferred —
        /// it is a property of the schedule and is stored as one.
        public let relationsClasses: [String]

        /// The class digits arranged by country — the only ones a key decomposes in.
        ///
        /// Stored rather than inferred: it is a property of the schedule, and it changed at the
        /// 1950 renumbering (6/7/8 before, 3–9 after, with a different split).
        public let countryArrangedClasses: [String]
        /// `"62"` → `"Germany"`, for this era only.
        public let countries: [String: String]
        /// `classDigit` → (`suffix` → gloss), e.g. `"8"` → `"72"` → `"Telegraph"`.
        public let subjects: [String: [String: String]]
        /// The OTHER names the table files under a code this schedule already answers (#1257).
        ///
        /// The table gives one number to several places — 44e is the Bahamas and twenty-one of
        /// its cays; 11f is the Panama Canal Zone and four islands in it — and `countries` can
        /// hold only one. Before this field the losers were logged by the generator and dropped,
        /// so the app vended a single name and could not say there were others. Measured, a
        /// quarter of the documents a schedule can gloss sit on a code with more than one
        /// claimant, which is far too many to leave undisclosed.
        ///
        /// Sorted, so a rebuild is byte-identical.
        public let countryAlternates: [String: [String]]
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
                    relationsClasses: [String], countries: [String: String],
                    countryAlternates: [String: [String]],
                    subjects: [String: [String: String]], sources: Sources) {
            self.relationsClasses = relationsClasses
            self.id = id
            self.startYear = startYear
            self.endYear = endYear
            self.source = source
            self.classes = classes
            self.countryArrangedClasses = countryArrangedClasses
            self.countries = countries
            self.countryAlternates = countryAlternates
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
                schedules: [Schedule], coverage: Coverage) {
        self.schemaVersion = schemaVersion
        self.generated = generated
        self.provenance = provenance
        self.schedules = schedules
        self.coverage = coverage
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
        // The second country is read ONLY in a relations class. Class 8 of the 1910–49 schedule is
        // *Internal Affairs of States* — one country and a subject — so reading its suffix as a
        // second country turned `893.51` into "China and France" when it means China's internal
        // affairs, subject .51. A suffix that merely LOOKS like a country code is not one.
        let second = schedule.relationsClasses.contains(digit)
            ? suffix.flatMap { schedule.countries[$0.lowercased()] != nil ? $0 : nil }
            : nil
        return DecimalClassKey(classDigit: digit, countryNumber: country,
                               subject: second == nil ? suffix : nil, secondCountry: second)
    }
}
