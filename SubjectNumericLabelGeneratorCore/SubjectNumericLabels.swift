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
