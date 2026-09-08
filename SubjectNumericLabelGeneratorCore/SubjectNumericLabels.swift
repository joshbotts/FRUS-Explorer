// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - Schedule

/// One edition's subject-numeric filing schedule (#1211).
struct Schedule: Encodable, Sendable {
    /// Schedule id, e.g. `"1963"`.
    let id: String
    /// First year this arrangement governs.
    let startYear: Int
    /// Last year it governs.
    let endYear: Int
    /// The handbook it was read from.
    let source: String
    /// `POL` -> `POLITICAL AFFAIRS & RELATIONS`.
    let categories: [String: String]
    /// `POL` -> `27` -> `MILITARY OPERATIONS`.
    let subjects: [String: [String: String]]
    /// `6` -> `MEMBERSHIP. ASSOCIATION.` — the schedule an ORGANIZATION's file is arranged by,
    /// which is where `UN 6` and `NATO 3` are read from.
    let organizationSubjects: [String: String]
    /// `NATO` -> `North Atlantic Treaty Organization` — the handbook's own abbreviations
    /// appendix, which is what identifies a prefix as an ORGANIZATION file rather than a
    /// primary subject.
    let abbreviations: [String: String]

    /// A key's subject, or `nil` when this schedule cannot say.
    ///
    /// ## Two filing shapes, and the order between them is the guard
    /// A PRIMARY SUBJECT file is arranged by its own outline, so `POL 27` is read from the POL
    /// outline. An ORGANIZATION file is arranged by the international-organizations instruction's
    /// list of administrative subjects, so `UN 6` is read from that list under the name `UN`.
    ///
    /// The category is tried first and the organization list only when it is not a primary
    /// subject AND the handbook's own abbreviations appendix names it. That second condition is
    /// what stops the list being applied to everything it would fit: `PSL 27 VIET S` is a
    /// one-character corruption of `POL 27` and `NSSD 05-82` is a National Security Study
    /// Directive, and both would take a plausible subject from the list without it.
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

    /// The organization's name, when the category is one.
    ///
    /// - Parameter category: The key's category letters.
    /// - Returns: `"United Nations"`, or `nil` for a primary subject.
    func organizationName(for category: String) -> String? {
        subjects[category] == nil ? abbreviations[category] : nil
    }
}

// MARK: - SubjectNumericLabels

/// The bundled subject-numeric label table (#1211).
struct SubjectNumericLabels: Encodable, Sendable {
    /// Wire schema version.
    let schemaVersion: Int
    /// Build stamp, `yyyy-MM-dd`.
    let generated: String
    /// What was read, and the caveat a consumer owes a reader.
    let provenance: String
    /// The editions, in force order.
    let schedules: [Schedule]
    /// What the table can and cannot answer.
    let coverage: Coverage

    /// The contract a consumer gates on.
    struct Coverage: Encodable, Sendable {
        /// First year the subject-numeric file was in use.
        let systemOpensIn: Int
        /// One span per shipped schedule.
        let glossableYears: [Span]
        /// The verdict for a key outside every span, stated in a word.
        let keyOutsideGlossableYears: String
        /// Categories the corpus cites that no schedule names, and why.
        let unnamedCategories: [String]
        /// The measured reach of each schedule over the shipped corpus.
        let measured: [Measurement]
        /// The caveats every surface owes.
        let note: String

        /// One schedule's span.
        struct Span: Encodable, Sendable {
            let scheduleId: String
            let startYear: Int
            let endYear: Int
        }

        /// What one schedule reads over the corpus it exists for.
        struct Measurement: Encodable, Sendable {
            let scheduleId: String
            /// Distinct subject-numeric class keys the corpus carries.
            let corpusKeys: Int
            /// How many of them this schedule names.
            let namedKeys: Int
            /// Documents behind those keys.
            let corpusDocuments: Int
            /// Documents this schedule gives a reading.
            let namedDocuments: Int
        }
    }
}
