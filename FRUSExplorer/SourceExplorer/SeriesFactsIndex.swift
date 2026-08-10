// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - SeriesFactsIndex

/// The bundled `naId → creating body` projection (#405).
///
/// FRUS source notes name the container a document came out of (`Lot 64 D 199`), never the office
/// that made it. NARA records the office on the series, and the app already stores the series
/// NAIDs, so this is a join with no resolution work behind it — 622 series, 364 distinct headings,
/// ~52 KB.
///
/// Built offline by `SeriesFactsIndexGenerator` from the record-group harvest. See that runner
/// for why the *similarity axis* half of #405 was measured and refused (2.8% corpus reachability),
/// and do not read this artifact's existence as evidence the axis is now viable.
///
/// Version history:
///   1.0 — Session 2026-08-10: #405 (F-6)
struct SeriesFactsIndex: Codable, Sendable, Equatable {

    /// One series' creating bodies, as indices into `headings`.
    struct Entry: Codable, Sendable, Equatable {
        /// The body NARA marks `Most Recent` — the one to name.
        let creator: Int
        /// Earlier bodies, when NARA records any. **Not rendered today**; carried because the
        /// harvest pass that produced them is the expensive part.
        let predecessors: [Int]?

        /// NARA's access status, as an index into `statuses`.
        let accessStatus: Int?
        /// The FOIA exemptions behind an access restriction, as indices into `restrictions`.
        let accessRestrictions: [Int]?
        /// Whether you may *publish* what you find — a different question from whether you may
        /// read it, and the one a researcher discovers too late.
        let useStatus: Int?
        let useRestrictions: [Int]?
        /// NARA's own extent statement, verbatim.
        let extent: String?
        /// The holding facility, as an index into `referenceUnits`.
        let referenceUnit: Int?
        let findingAids: [Int]?
        let startYear: Int?
        let endYear: Int?

        enum CodingKeys: String, CodingKey {
            case creator = "c"
            case predecessors = "p"
            case accessStatus = "as"
            case accessRestrictions = "ar"
            case useStatus = "us"
            case useRestrictions = "ur"
            case extent = "x"
            case referenceUnit = "ru"
            case findingAids = "fa"
            case startYear = "y0"
            case endYear = "y1"
        }
    }

    /// NARA's catalogue facts about one series, resolved to display strings (#663 / F-7).
    ///
    /// Everything here is trip-planning information: whether the records can be read at all, why
    /// not, whether what you find can be published, how much of it there is, where it physically
    /// is, and whether NARA has a folder list. FRUS's own citation says none of it.
    struct Facts: Sendable, Equatable {
        /// e.g. `Restricted - Partly`. Measured: 414 of 622 app-reachable series are restricted
        /// in some degree, so this is usually present and usually consequential.
        var accessStatus: String?
        /// e.g. `FOIA (b)(1) National Security` — 338 of 622.
        var accessRestrictions: [String]
        var useStatus: String?
        /// Chiefly `Copyright` — 205 of 622.
        var useRestrictions: [String]
        var extent: String?
        var referenceUnit: String?
        var findingAids: [String]
        var years: String?

        /// Whether NARA states any limit on reading the records.
        var isAccessRestricted: Bool { (accessStatus ?? "").hasPrefix("Restricted") }
        /// Whether NARA states any limit on publishing them.
        var isUseRestricted: Bool { (useStatus ?? "").hasPrefix("Restricted") }
        /// Nothing worth rendering.
        var isEmpty: Bool {
            accessStatus == nil && useStatus == nil && extent == nil
                && referenceUnit == nil && findingAids.isEmpty && years == nil
        }
    }

    let schemaVersion: Int
    let generated: String
    /// Distinct creator headings, sorted, with NARA's trailing lifespan removed.
    let headings: [String]
    /// Series NAID → its creators and facts.
    let byNaId: [String: Entry]
    /// Access/use status vocabulary.
    let statuses: [String]
    /// Access-restriction (FOIA exemption) vocabulary.
    let restrictions: [String]
    /// Use-restriction vocabulary.
    let useRestrictions: [String]
    /// Holding-facility vocabulary.
    let referenceUnits: [String]
    /// Finding-aid type vocabulary.
    let findingAidTypes: [String]

    /// The creating body for `naId`, or `nil` when the series is not covered.
    ///
    /// Coverage is a fraction and always will be: `creators` exists only on NARA's **series**
    /// layer, so a file-unit NAID — every numerical-file roll, for instance — resolves to nothing
    /// here by construction. Callers must treat `nil` as "not stated", never as "no creator".
    func creator(forNaId naId: String) -> String? {
        guard let entry = byNaId[naId], headings.indices.contains(entry.creator) else { return nil }
        return headings[entry.creator]
    }

    /// NARA's catalogue facts for `naId`, or `nil` when the series is not covered.
    ///
    /// Every index is bounds-checked rather than trusted: the artifact is generated, but it also
    /// ships in the bundle where a bad edit would otherwise trap mid-render.
    func facts(forNaId naId: String) -> Facts? {
        guard let entry = byNaId[naId] else { return nil }
        func lookup(_ i: Int?, _ table: [String]) -> String? {
            guard let i, table.indices.contains(i) else { return nil }
            return table[i]
        }
        func lookupAll(_ xs: [Int]?, _ table: [String]) -> [String] {
            (xs ?? []).compactMap { table.indices.contains($0) ? table[$0] : nil }
        }
        let years: String?
        switch (entry.startYear, entry.endYear) {
        case let (s?, e?): years = s == e ? "\(s)" : "\(s)–\(e)"
        case let (s?, nil): years = "\(s)–"
        case let (nil, e?): years = "–\(e)"
        default: years = nil
        }
        let facts = Facts(
            accessStatus: lookup(entry.accessStatus, statuses),
            accessRestrictions: lookupAll(entry.accessRestrictions, restrictions),
            useStatus: lookup(entry.useStatus, statuses),
            useRestrictions: lookupAll(entry.useRestrictions, useRestrictions),
            extent: entry.extent,
            referenceUnit: lookup(entry.referenceUnit, referenceUnits),
            findingAids: lookupAll(entry.findingAids, findingAidTypes),
            years: years)
        return facts.isEmpty ? nil : facts
    }

    /// The earlier bodies NARA records for `naId`, if any. Unused by any surface today.
    func predecessors(forNaId naId: String) -> [String] {
        guard let entry = byNaId[naId] else { return [] }
        return (entry.predecessors ?? []).compactMap {
            headings.indices.contains($0) ? headings[$0] : nil
        }
    }
}

// MARK: - SeriesFactsIndexStore

/// Loads the bundled series-creator index once, lazily.
///
/// `nil` means the feature degrades to what shipped before #405 — no creator line — never that a
/// series has no creator. The distinction matters here more than usual, because the honest answer
/// for most NAIDs *is* "not stated", and a silent load failure would be indistinguishable from it.
///
/// Version history:
///   1.0 — Session 2026-08-10: #405 (F-6)
enum SeriesFactsIndexStore {

    /// The bundled index, or `nil` when the resource is missing or malformed.
    static let shared: SeriesFactsIndex? = load()

    private static func load() -> SeriesFactsIndex? {
        guard let url = Bundle.main.url(forResource: "series-facts-index",
                                        withExtension: "json") else {
            #if DEBUG
            print("[SourceExplorer] SeriesFactsIndexStore: series-facts-index.json not found.")
            #endif
            return nil
        }
        do {
            return try JSONDecoder().decode(SeriesFactsIndex.self,
                                            from: try Data(contentsOf: url))
        } catch {
            #if DEBUG
            print("[SourceExplorer] SeriesFactsIndexStore: decode failed — \(error)")
            #endif
            return nil
        }
    }
}

// MARK: - Lookup with the app's own guards

extension SeriesFactsIndex {

    /// The creating body to show for a bundled lot entry, or `nil`.
    ///
    /// Three guards, each protecting against showing a true fact about the wrong record:
    ///
    /// 1. **Series level only.** `bundledLotSection` renders file-unit entries too, and a file
    ///    unit borrows its series title from its parent (`displaySeriesTitle`). NARA puts
    ///    `creators` on the series alone, so a creator found for a file-unit NAID would be either
    ///    absent or — worse — the parent's, presented as the cited record's.
    /// 2. **Not an untrustworthy NAID.** `#351` established that some bundled NAIDs point at the
    ///    wrong collection entirely; `CentralFilesIndex.isUntrustworthyNAID` is the standing list.
    ///    A creator attached to one of those would dress a known-bad resolution in new detail.
    /// 3. **Not the record group.** A record-group node's creator is "Department of State" for
    ///    three-quarters of the corpus — true, and useless. This index only holds series, so the
    ///    guard is structural rather than a filter, but it is why the line stays absent on the
    ///    decimal-file mass instead of repeating one label everywhere.
    /// NARA's catalogue facts for a bundled lot entry, under the same guards as the creator.
    static func facts(for entry: LotFileEntry) -> Facts? {
        guard shouldShow(isSeriesLevel: entry.isSeriesLevel,
                         untrustworthyFlag: CentralFilesIndexStore.shared?
                             .isUntrustworthyNAID(entry.naId)) else { return nil }
        return SeriesFactsIndexStore.shared?.facts(forNaId: entry.naId)
    }

    static func creatorName(for entry: LotFileEntry) -> String? {
        guard shouldShow(isSeriesLevel: entry.isSeriesLevel,
                         untrustworthyFlag: CentralFilesIndexStore.shared?
                             .isUntrustworthyNAID(entry.naId)) else { return nil }
        return SeriesFactsIndexStore.shared?.creator(forNaId: entry.naId)
    }

    /// Guards 1 and 2 as a pure decision, so both can be exercised — including the case no test
    /// can otherwise reach, where the central-files index failed to load.
    ///
    /// `untrustworthyFlag` is `nil` when that index is unavailable. It must be treated as
    /// **unknown, not clean**: `!= true` rather than `== false`. A mutation sweep flipped exactly
    /// that comparison and nothing caught it, because in a test process the singleton is always
    /// present and the two spellings agree.
    static func shouldShow(isSeriesLevel: Bool, untrustworthyFlag: Bool?) -> Bool {
        guard isSeriesLevel else { return false }
        return untrustworthyFlag != true
    }
}
