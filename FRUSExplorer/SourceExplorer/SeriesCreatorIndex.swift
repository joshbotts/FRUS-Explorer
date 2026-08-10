// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - SeriesCreatorIndex

/// The bundled `naId → creating body` projection (#405).
///
/// FRUS source notes name the container a document came out of (`Lot 64 D 199`), never the office
/// that made it. NARA records the office on the series, and the app already stores the series
/// NAIDs, so this is a join with no resolution work behind it — 622 series, 364 distinct headings,
/// ~52 KB.
///
/// Built offline by `SeriesCreatorIndexGenerator` from the record-group harvest. See that runner
/// for why the *similarity axis* half of #405 was measured and refused (2.8% corpus reachability),
/// and do not read this artifact's existence as evidence the axis is now viable.
///
/// Version history:
///   1.0 — Session 2026-08-10: #405 (F-6)
struct SeriesCreatorIndex: Codable, Sendable, Equatable {

    /// One series' creating bodies, as indices into `headings`.
    struct Entry: Codable, Sendable, Equatable {
        /// The body NARA marks `Most Recent` — the one to name.
        let creator: Int
        /// Earlier bodies, when NARA records any. **Not rendered today**; carried because the
        /// harvest pass that produced them is the expensive part.
        let predecessors: [Int]?

        enum CodingKeys: String, CodingKey {
            case creator = "c"
            case predecessors = "p"
        }
    }

    let schemaVersion: Int
    let generated: String
    /// Distinct creator headings, sorted, with NARA's trailing lifespan removed.
    let headings: [String]
    /// Series NAID → its creators.
    let byNaId: [String: Entry]

    /// The creating body for `naId`, or `nil` when the series is not covered.
    ///
    /// Coverage is a fraction and always will be: `creators` exists only on NARA's **series**
    /// layer, so a file-unit NAID — every numerical-file roll, for instance — resolves to nothing
    /// here by construction. Callers must treat `nil` as "not stated", never as "no creator".
    func creator(forNaId naId: String) -> String? {
        guard let entry = byNaId[naId], headings.indices.contains(entry.creator) else { return nil }
        return headings[entry.creator]
    }

    /// The earlier bodies NARA records for `naId`, if any. Unused by any surface today.
    func predecessors(forNaId naId: String) -> [String] {
        guard let entry = byNaId[naId] else { return [] }
        return (entry.predecessors ?? []).compactMap {
            headings.indices.contains($0) ? headings[$0] : nil
        }
    }
}

// MARK: - SeriesCreatorIndexStore

/// Loads the bundled series-creator index once, lazily.
///
/// `nil` means the feature degrades to what shipped before #405 — no creator line — never that a
/// series has no creator. The distinction matters here more than usual, because the honest answer
/// for most NAIDs *is* "not stated", and a silent load failure would be indistinguishable from it.
///
/// Version history:
///   1.0 — Session 2026-08-10: #405 (F-6)
enum SeriesCreatorIndexStore {

    /// The bundled index, or `nil` when the resource is missing or malformed.
    static let shared: SeriesCreatorIndex? = load()

    private static func load() -> SeriesCreatorIndex? {
        guard let url = Bundle.main.url(forResource: "series-creator-index",
                                        withExtension: "json") else {
            #if DEBUG
            print("[SourceExplorer] SeriesCreatorIndexStore: series-creator-index.json not found.")
            #endif
            return nil
        }
        do {
            return try JSONDecoder().decode(SeriesCreatorIndex.self,
                                            from: try Data(contentsOf: url))
        } catch {
            #if DEBUG
            print("[SourceExplorer] SeriesCreatorIndexStore: decode failed — \(error)")
            #endif
            return nil
        }
    }
}

// MARK: - Lookup with the app's own guards

extension SeriesCreatorIndex {

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
    static func creatorName(for entry: LotFileEntry) -> String? {
        guard shouldShow(isSeriesLevel: entry.isSeriesLevel,
                         untrustworthyFlag: CentralFilesIndexStore.shared?
                             .isUntrustworthyNAID(entry.naId)) else { return nil }
        return SeriesCreatorIndexStore.shared?.creator(forNaId: entry.naId)
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
