// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - DecimalClassLabelTable

/// The bundled label table for State Department central-file decimal classes (#828).
///
/// Mirrors the artifact `DecimalClassLabelGenerator` writes. The vocabularies are stored
/// separately and composed at read time, because a decimal file number is not an opaque
/// identifier: `761.62` is *class 7, political relations, between country 61 and country 62*.
struct DecimalClassLabelTable: Decodable, Sendable {

    /// Artifact schema version.
    let schemaVersion: Int
    /// The artifact's own build stamp.
    let generated: String
    /// What was parsed, from which publications, and what a reader must know about them.
    let provenance: String
    /// The era schedules, earliest first.
    let schedules: [Schedule]

    /// One era's classification schedule.
    struct Schedule: Decodable, Sendable {
        /// Stable id (`"1910-1949"`).
        let id: String
        /// First year governed.
        let startYear: Int
        /// Last year governed.
        let endYear: Int
        /// The publication the classes and subjects were read from.
        let source: String
        /// `"7"` → `"Political Relations of States"`.
        let classes: [String: String]
        /// The classes whose suffix is a second COUNTRY rather than a subject.
        let relationsClasses: [String]
        /// The classes a key decomposes in at all.
        let countryArrangedClasses: [String]
        /// `"62"` → `"Germany"`, for this era only.
        let countries: [String: String]
        /// `classDigit` → (`suffix` → gloss).
        ///
        /// Class 8's entries run the manual's whole tree, not just its ten stems: `.6363` is
        /// Petroleum, beneath `.636` Carbon. Graphite, beneath `.63` Mines. Mining. That depth is
        /// what lets `812.6363` read as Mexico's oil files rather than as "Mexico".
        ///
        /// **A gloss is not unique.** 99 of the 693 suffixes share wording with another — `.711`
        /// and `.731` are both "Laws and regulations", of postal and of cable service, and `.2225`
        /// and `.3225` are both "Discharge", from the army and from the navy. Qualifying them by
        /// their parent was measured and dropped: it does not separate the largest family (the
        /// military/naval pairs differ two levels up, so the qualifier would have to be the whole
        /// chain) and the key itself is always displayed beside the gloss, which is the
        /// discriminator a reader needs.
        let subjects: [String: [String: String]]

        /// Whether this schedule governs every year in `span`, given where the decimal file opens.
        ///
        /// Containment at **both** ends, on a span first clamped at `floor` — the earliest year
        /// any schedule covers.
        ///
        /// The renumbering in 1950 is the hazard at the top: a span reaching past this schedule's
        /// end also covers the era where the same digits mean something else, so a key drawn from
        /// it could be read either way and labelling it would be a confident guess.
        ///
        /// The clamp is what lets the bottom be tested at all. The central decimal file BEGINS in
        /// 1910, so a span opening earlier — the first era band runs from 1861, where the *series*
        /// opens — carries no decimal keys in those years to mislabel, and requiring literal
        /// containment there silenced the whole first band, the one era #828 exists to label.
        /// Clamping says that precisely, instead of dropping the lower bound and hoping.
        ///
        /// Dropping it was live while one schedule shipped and would have become a mislabel with
        /// the second: a key cited by volumes covering 1945–1955 has an upper bound inside
        /// 1951–59, and an upper-bound-only test would label it from a schedule that governs half
        /// its documents. It has to stay bare.
        ///
        /// - Parameters:
        ///   - span: The years the caller's figures cover.
        ///   - floor: The first year the classification exists at all.
        /// - Returns: `true` when this schedule can speak for every decimal key in the span.
        func governs(_ span: ClosedRange<Int>, floor: Int) -> Bool {
            // A span ending before the file opens holds no decimal keys, so no schedule speaks
            // for it. Without this the clamp would lift such a span INTO the first schedule.
            guard span.upperBound >= floor else { return false }
            return max(span.lowerBound, floor) >= startYear && span.upperBound <= endYear
        }
    }

    /// A key's reading in plain words, or `nil` when this table cannot say.
    ///
    /// Silence is the designed outcome for anything uncertain: a wrong gloss on an archival
    /// citation is worse than a bare number, because the reader cannot tell that it is wrong. A
    /// key renders exactly as it does today whenever the schedule, the class, or the country is
    /// not one this table carries.
    ///
    /// - Parameters:
    ///   - key: A decimal class key as a source note wrote it (`"793.94"`).
    ///   - span: The coverage years the surface's figures describe.
    /// - Returns: `"China and Japan"`, `"Mexico — Petroleum"`, or `nil`.
    /// Whether `key` composes under the 1910-1949 schedule — the **indexing** test, not the
    /// display one (#834).
    ///
    /// ## This is deliberately NOT `gloss(for:coveringYears:) != nil`
    /// `gloss` additionally requires the class to be country-ARRANGED (6, 7, 8) because it is
    /// producing words for a reader. Indexing must admit every well-formed key, so reusing `gloss`
    /// here would silently refuse classes 0-5 and 9 — and the bundled artifact, which uses the
    /// shared rule, would then count citations the indexed table refused. The two surfaces would
    /// disagree about the same footnote with nothing on screen to explain it.
    ///
    /// Delegates to `SourceNoteKit.DecimalScheduleComposition` so the app and the generator apply
    /// one rule; the schedule is injected rather than re-read.
    func composes(_ key: String) -> Bool {
        guard let schedule = schedules.first(where: { $0.id == "1910-1949" }) ?? schedules.first
        else { return false }
        return DecimalScheduleComposition.composes(
            key,
            classes: Set(schedule.classes.keys),
            countries: Set(schedule.countries.keys.map { $0.lowercased() }))
    }

    func gloss(for key: String, coveringYears span: ClosedRange<Int>) -> String? {
        guard let floor = schedules.map(\.startYear).min(),
              let schedule = schedules.first(where: { $0.governs(span, floor: floor) })
        else { return nil }
        let parts = key.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        guard let head = parts.first, let first = head.first, first.isNumber else { return nil }
        let digit = String(first)
        let country = String(head.dropFirst()).lowercased()
        guard schedule.countryArrangedClasses.contains(digit),
              let nation = schedule.countries[country]
        else { return nil }

        let suffix = parts.count > 1 ? String(parts[1]) : nil
        if schedule.relationsClasses.contains(digit), let suffix,
           let other = schedule.countries[suffix.lowercased()] {
            return String(format: String(localized: "archival.classLabel.relations %@ %@",
                                         defaultValue: "%1$@ and %2$@"),
                          Self.readable(nation), Self.readable(other))
        }
        if let suffix, let subject = schedule.subjects[digit]?[suffix] {
            // The subject keeps the manual's own capitalisation. It was lower-cased while the
            // table held 61 subject headings, all of them common nouns ("Political affairs"); the
            // nested subdivisions are full of proper nouns, and any rule that lower-cases a first
            // word turns `.00N` into "Haiti — nazi. nazi activities" and `.142` into "United
            // States — red cross". These are headings in a filing manual, and reading them as the
            // manual prints them is both correct and the only rule with no wrong cases.
            return String(format: String(localized: "archival.classLabel.subject %@ %@",
                                         defaultValue: "%1$@ — %2$@"),
                          Self.readable(nation), subject)
        }
        return Self.readable(nation)
    }

    /// Un-inverts the table's index forms — `"World, The"` reads as `"The World"`.
    ///
    /// NARA's table alphabetises, so it stores the article at the end. Left alone, `795.00` came
    /// out as "Korea and World, The".
    static func readable(_ name: String) -> String {
        for article in [", The", ", the", ", A", ", An"] where name.hasSuffix(article) {
            let stem = String(name.dropLast(article.count))
            let word = article.dropFirst(2)
            return "\(word) \(stem)"
        }
        return name
    }
}

// MARK: - DecimalClassLabelStore

/// The bundled label table, decoded once on first use (#828).
///
/// A lazy `static let`, like its sibling stores — but every caller reaches it from a background
/// context, because the first touch pays the decode on whichever thread arrives first.
enum DecimalClassLabelStore {

    /// The table, or `nil` when the resource is absent or unreadable.
    ///
    /// Absence degrades to unlabelled keys, never to a crash: the app rendered bare numbers for
    /// its whole life before this artifact existed, and that remains a working state.
    static let shared: DecimalClassLabelTable? = load()

    private static func load() -> DecimalClassLabelTable? {
        guard let url = Bundle.main.url(forResource: "decimal-class-labels", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            #if DEBUG
            print("[DecimalClassLabelStore] decimal-class-labels.json is not in the bundle; "
                + "class keys will render unlabelled, as they did before #828.")
            #endif
            return nil
        }
        return try? JSONDecoder().decode(DecimalClassLabelTable.self, from: data)
    }
}
