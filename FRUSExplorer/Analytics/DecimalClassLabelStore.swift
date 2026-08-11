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
        let subjects: [String: [String: String]]

        /// Whether this schedule governs every year in `span`.
        ///
        /// The test is on the span's **upper** bound, and the asymmetry is the point.
        ///
        /// The renumbering in 1950 is the hazard: a span reaching past this schedule's end also
        /// covers the era where the same digits mean something else, so a key drawn from it could
        /// be read either way and labelling it would be a confident guess. The 1948–1960 era band
        /// is exactly that case, and gets no labels.
        ///
        /// The lower bound carries no such risk. The central decimal file BEGINS in 1910, so a
        /// span opening earlier — the first era band runs from 1861, where the series itself opens
        /// — contains no decimal keys in those years to mislabel. Requiring containment at both
        /// ends silenced that band entirely, which is the one era #828 exists to label: before
        /// 1948 the class lens *is* the named archival record.
        ///
        /// - Parameter span: The years the caller's figures cover.
        /// - Returns: `true` when this schedule can speak for every decimal key in the span.
        func governs(_ span: ClosedRange<Int>) -> Bool {
            span.upperBound >= startYear && span.upperBound <= endYear
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
    /// - Returns: `"China and Japan"`, `"Mexico — internal affairs"`, or `nil`.
    func gloss(for key: String, coveringYears span: ClosedRange<Int>) -> String? {
        guard let schedule = schedules.first(where: { $0.governs(span) }) else { return nil }
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
            return String(format: String(localized: "archival.classLabel.subject %@ %@",
                                         defaultValue: "%1$@ — %2$@"),
                          Self.readable(nation), subject.lowercased())
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
