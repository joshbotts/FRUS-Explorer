// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - SeriesFactsIndexStore

/// Loads the bundled series-creator index once, lazily.
///
/// `nil` means the feature degrades to what shipped before #405 — no creator line — never that a
/// series has no creator. The distinction matters here more than usual, because the honest answer
/// for most NAIDs *is* "not stated", and a silent load failure would be indistinguishable from it.
///
/// Version history:
///   1.0 — Session 2026-08-10: #405 (F-6)
///   1.1 — 2026-11-08 (FRUS Explorer Light, S22a): in a file of its own, since the index it
///          loads is FRUSCoreKit's (`SeriesFactsIndex.swift`) and the kit never reads the app's bundle
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
}
