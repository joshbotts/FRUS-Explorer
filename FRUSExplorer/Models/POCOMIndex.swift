// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - POCOMIndex

/// Career records from the Office of the Historian's Principal Officers and Chiefs of Mission
/// register (#736).
///
/// The app-side mirror of `POCOMIndexGeneratorCore.POCOMIndex`; the JSON is the contract.
///
/// ## What it reaches, and what it does not
/// POCOM carries no FRUS anchor, so the only route in is
/// `PersonAuthorityIndex.pocomSlug(for:)` — meaning career data can appear **only** for people the
/// app already knows from a volume's editor-published person list. Measured on the shipped
/// artifacts: 1,242 of the app's 12,836 authority people carry a slug, **1,240 of them have at
/// least one appointment**, and those surface a Career section on roughly 12,500 of 62,818 live
/// person rows — high relative to the people count because chiefs of mission recur across many
/// volumes.
///
/// It adds nobody to the 268 volumes whose editors published no person list. That gap is #234's,
/// and no amount of POCOM data closes it.
///
/// Version history:
///   1.0 — Session 2026-08-07: #736
struct POCOMIndex: Codable, Sendable {

    /// Index schema version.
    let version: Int
    /// ISO date (`yyyy-MM-dd`) the index was generated.
    let generated: String
    /// Provenance string (upstream repo, license, checkout HEAD).
    let source: String
    /// `slug → career`, for slugs with at least one appointment.
    let careers: [String: POCOMCareer]

    private enum CodingKeys: String, CodingKey { case version, generated, source, careers }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        generated = try c.decodeIfPresent(String.self, forKey: .generated) ?? ""
        source = try c.decodeIfPresent(String.self, forKey: .source) ?? ""
        careers = try c.decodeIfPresent([String: POCOMCareer].self, forKey: .careers) ?? [:]
    }

    /// The career for a POCOM slug, or `nil`.
    func career(forSlug slug: String) -> POCOMCareer? { careers[slug] }
}

// MARK: - POCOMCareer

/// One person's register entry: name, life dates, and appointments in chronological order.
struct POCOMCareer: Codable, Sendable, Equatable {
    /// Display name as POCOM spells it.
    let n: String
    /// Birth year, if recorded.
    let b: Int?
    /// Death year, if recorded.
    let d: Int?
    /// Appointments, already sorted by the generator — the view renders them in order.
    let a: [POCOMAssignment]
}

// MARK: - POCOMAssignment

/// One post held: what, where, and when.
struct POCOMAssignment: Codable, Sendable, Equatable, Identifiable {
    /// Role title ("Under Secretary of State").
    let r: String
    /// Place or organization, absent for posts inside the Department.
    let p: String?
    /// Date of appointment, as the register writes it.
    let ap: String?
    /// Date the officer took up the post.
    let st: String?
    /// Date they left it.
    let en: String?
    /// The register's note on the termination ("Left Tehran on", "Resigned").
    let nt: String?

    /// Stable within one career: no two appointments share all four of these.
    var id: String { "\(r)|\(p ?? "")|\(ap ?? "")|\(st ?? "")" }

    /// The date range to show, or `nil` when the register has no date at all.
    ///
    /// Prefers the **service** dates (`started`–`ended`) over the appointment date, because the
    /// question a researcher is asking beside a document is who held the post *then*, not when the
    /// paperwork was signed. Falls back to the appointment date when service dates are missing.
    ///
    /// Dates are rendered as the register writes them rather than reformatted: many are partial
    /// (`1935` with no month), and a formatter would have to invent the missing precision.
    var dateRangeText: String? {
        let start = st ?? ap
        switch (start, en) {
        case let (.some(from), .some(to)):
            return String(localized: "pocom.range", defaultValue: "\(from) – \(to)")
        case let (.some(from), .none):
            return String(localized: "pocom.from", defaultValue: "from \(from)")
        case let (.none, .some(to)):
            return String(localized: "pocom.until", defaultValue: "until \(to)")
        case (.none, .none):
            return nil
        }
    }

    /// "Under Secretary of State" or "Ambassador — France".
    var titleText: String {
        guard let p, !p.isEmpty else { return r }
        return String(localized: "pocom.roleAtPlace", defaultValue: "\(r) — \(p)")
    }
}

// MARK: - POCOMIndexStore

/// Loads the bundled `pocom-index.json` once, lazily.
///
/// `nil` when the resource is absent (the unit-test bundle) or malformed — in which case the
/// Career section simply does not appear, exactly as it did before this shipped.
enum POCOMIndexStore {
    static let shared: POCOMIndex? = load()

    private static func load() -> POCOMIndex? {
        guard let url = Bundle.main.url(forResource: "pocom-index", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            #if DEBUG
            print("[POCOMIndex] pocom-index.json not found in bundle")
            #endif
            return nil
        }
        do {
            let index = try JSONDecoder().decode(POCOMIndex.self, from: data)
            #if DEBUG
            print("[POCOMIndex] loaded \(index.careers.count) careers (generated \(index.generated))")
            #endif
            return index
        } catch {
            #if DEBUG
            print("[POCOMIndex] decode failed: \(error)")
            #endif
            return nil
        }
    }
}
