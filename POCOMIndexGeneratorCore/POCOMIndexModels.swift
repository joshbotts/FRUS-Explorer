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
/// — the Principal Officers and Chiefs of Mission register. `careers` answers "what posts did this
/// person hold, and when", for people the app already knows through
/// `person-authority-index.json`'s POCOM slug.
///
/// ## Version 2: chiefs of mission by territory
/// Version 2 adds three tables beside `careers`, and leaves `careers` byte-identical:
/// - `chiefs` holds every U.S. chief of mission the register records as having **served** at a
///   country mission between 1861 and 1906, plus those whose tenure ended in the 90 days before 1861
///   (the app's grace still reaches them). It is keyed by the mission file's `<territory-id>`.
/// - `names` holds those people's name parts.
/// - `roles` holds the singular labels of the roles they held.
///
/// Unlike `careers`, these tables are NOT restricted to authority-reachable slugs. They exist so
/// Source Explorer can tell a Department letter to the U.S. minister at a post from a note to a
/// foreign legation in Washington. The type case is William L. Dayton, minister to France and the
/// addressee of `frus1863p2/d573`, and he is not authority-reachable at all. The app decoder is
/// `FRUSExplorer/Models/POCOMIndex.swift`, and the wire keys below are its contract.
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
    /// `POCOM territory id → served chief-of-mission rows` overlapping 1861–1906, a last day allowed
    /// 90 days' grace before the window (version 2).
    /// Each territory's rows are ordered by (first day, slug, chief id).
    public let chiefs: [String: [POCOMChiefRow]]
    /// `slug → name parts`, for exactly the slugs `chiefs` names (version 2).
    public let names: [String: POCOMPersonName]
    /// `POCOM role id → singular role label`, for exactly the role ids `chiefs` uses (version 2).
    public let roles: [String: String]

    /// Creates an index. The version-2 tables default to empty.
    public init(version: Int, generated: String, source: String, careers: [String: POCOMCareer],
                chiefs: [String: [POCOMChiefRow]] = [:], names: [String: POCOMPersonName] = [:],
                roles: [String: String] = [:]) {
        self.version = version
        self.generated = generated
        self.source = source
        self.careers = careers
        self.chiefs = chiefs
        self.names = names
        self.roles = roles
    }
}

// MARK: - POCOMChiefRow

/// One served chief-of-mission row in the version-2 `chiefs` table.
///
/// Dates are the register's own strings (`YYYY`, `YYYY-MM` or `YYYY-MM-DD`), as with
/// ``POCOMAssignment``; the app floors and ceils them. An absent value is omitted from the JSON,
/// never written as `null`.
public struct POCOMChiefRow: Codable, Sendable, Equatable {
    /// The person's POCOM slug (`dayton-william-lewis`).
    public let s: String
    /// The POCOM role id (`envoy-extraordinary-minister-plenipotentiary`); ``POCOMIndex/roles``
    /// labels it.
    public let r: String
    /// Date of appointment.
    public let ap: String?
    /// Date the chief took up the post. In practice this is when credentials were presented.
    public let st: String?
    /// Date they left it.
    public let en: String?
    /// Derived end, written ONLY when `en` is absent. It is the day before the earliest start
    /// strictly later than this row's, among every served row at the same territory in the whole
    /// register, and it is absent when no such row exists.
    public let ex: String?

    /// Creates a row.
    public init(s: String, r: String, ap: String?, st: String?, en: String?, ex: String?) {
        self.s = s
        self.r = r
        self.ap = ap
        self.st = st
        self.en = en
        self.ex = ex
    }
}

// MARK: - POCOMPersonName

/// A person's name parts, as the register's `persName` records them (version 2).
public struct POCOMPersonName: Codable, Sendable, Equatable {
    /// Surname (`Dayton`).
    public let sn: String
    /// Forename(s) (`William Lewis`).
    public let fn: String
    /// Generational suffix (`Jr.`). Absent when the register has none, or an empty one.
    public let g: String?
    /// The register's first non-empty `altname` (`William L. Dayton`). Absent when it has none.
    public let a: String?

    /// Creates a name.
    public init(sn: String, fn: String, g: String?, a: String?) {
        self.sn = sn
        self.fn = fn
        self.g = g
        self.a = a
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
    /// `<chief>` rows read from inside `<chiefs>`, across every country-mission file (version 2).
    public var servedChiefRows = 0
    /// `<chief>` rows inside `<other-nominees>`. The `chiefs` table never reads them, but they
    /// still reach `careers`, which harvests every `<chief>` in a file.
    public var otherNomineeChiefRows = 0
    /// Served rows stating neither an appointment nor a start date. They cannot be placed in time.
    public var chiefRowsWithoutStart = 0
    /// Served rows whose tenure does not overlap the window (1861–1906, last days from 1860-10-03).
    public var chiefRowsOutsideWindow = 0
    /// In-window served rows whose person has no register file with a surname.
    public var chiefRowsWithoutName = 0
    /// Emitted rows that carry a derived end (`ex`).
    public var derivedEndsWritten = 0
    public init() {}
}
