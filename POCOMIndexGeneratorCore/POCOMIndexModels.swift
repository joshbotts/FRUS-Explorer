// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - POCOMIndex

/// The bundled career index produced by `POCOMIndexGenerator` (#736).
///
/// Built from the Office of the Historian's public-domain (CC0) `HistoryAtState/pocom` repository
/// — the Principal Officers and Chiefs of Mission register. It answers "what posts did this person
/// hold, and when", for people the app already knows through
/// `person-authority-index.json`'s POCOM slug.
///
/// ## Why the join runs backwards
/// POCOM carries **no FRUS anchor of any kind**: a person record is
/// `{id, persName, birth, death, career-type, residence}` and the appointments live in
/// `missions-*/` keyed by POCOM slug. The only path into this app therefore runs
/// app people-id → `HistoryAtState/people` record → its `departmenthistory/people/{slug}`
/// source-url → this index. That means POCOM can only enrich people the app already has from
/// volume front matter; it cannot add anyone to a volume whose editors published no person list.
///
/// JSON keys are terse for the same reason the authority index's are.
public struct POCOMIndex: Codable, Sendable, Equatable {
    /// Schema version of this index file.
    public let version: Int
    /// ISO date the index was generated (yyyy-MM-dd).
    public let generated: String
    /// Provenance string (upstream repo, license, and checkout HEAD).
    public let source: String
    /// `slug → career record`, for slugs that have at least one appointment.
    public let careers: [String: POCOMCareer]

    public init(version: Int, generated: String, source: String, careers: [String: POCOMCareer]) {
        self.version = version
        self.generated = generated
        self.source = source
        self.careers = careers
    }
}

// MARK: - POCOMCareer

/// One person's POCOM record: their register name, life dates, and every appointment.
public struct POCOMCareer: Codable, Sendable, Equatable {
    /// Display name as POCOM spells it ("Surname, Given").
    public let n: String
    /// Birth year, if the register records one.
    public let b: Int?
    /// Death year, if the register records one.
    public let d: Int?
    /// Appointments, **sorted chronologically** by their earliest known date so the app can render
    /// the list without re-sorting and without a stable-sort assumption.
    public let a: [POCOMAssignment]

    public init(n: String, b: Int?, d: Int?, a: [POCOMAssignment]) {
        self.n = n
        self.b = b
        self.d = d
        self.a = a
    }
}

// MARK: - POCOMAssignment

/// One post: what it was, where, and the dates the register knows.
///
/// Every date is kept as the register's own string (`1935-01-22`, or a bare `1935` where that is
/// all it recorded) rather than parsed into a `Date`. POCOM's dates are frequently partial, and a
/// parse would have to invent a month and day that the register is deliberately not asserting.
public struct POCOMAssignment: Codable, Sendable, Equatable {
    /// Human-readable role title ("Envoy Extraordinary and Minister Plenipotentiary").
    public let r: String
    /// Human-readable place or organization ("Afghanistan", "United Nations"), absent for
    /// principal positions, which are posts in the Department itself.
    public let p: String?
    /// Date of appointment.
    public let ap: String?
    /// Date the officer took up the post.
    public let st: String?
    /// Date they left it.
    public let en: String?
    /// A note the register attaches to the termination — "Left Tehran on", "Died at post" — which
    /// is often the only thing distinguishing an ordinary rotation from an incident.
    public let nt: String?

    public init(r: String, p: String?, ap: String?, st: String?, en: String?, nt: String?) {
        self.r = r
        self.p = p
        self.ap = ap
        self.st = st
        self.en = en
        self.nt = nt
    }

    /// The earliest date this assignment states, for chronological ordering. Appointments with no
    /// date at all sort last, which is where a reader expects "date unknown" to sit.
    public var sortKey: String { ap ?? st ?? en ?? "9999" }
}

// MARK: - POCOMBuildStats

/// Summary statistics for the console report.
public struct POCOMBuildStats: Sendable, Equatable {
    public var personFiles = 0
    public var countryChiefs = 0
    public var orgChiefs = 0
    public var principals = 0
    public var careersEmitted = 0
    public var assignmentsEmitted = 0
    public var appointmentsWithNoPerson = 0
    public var unknownRoleIds: Set<String> = []
    public init() {}
}
