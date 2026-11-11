// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - LotClaimantsIndexStore

/// Loads the bundled claimants index once, mirroring `CentralFilesIndexStore`.
///
/// Version history:
///   1.0 — Session 2026-08-05: #675 / N-8b
///   1.1 — 2026-10-27 (FRUS Explorer Light, S18b): in a file of its own, `LotClaimantsIndexStore.swift`, since the
///          index it loads is FRUSCoreKit's and the kit never reads the app's bundle
///   1.2 — 2026-11-10 (FRUS Explorer Light, S22b): the rendering of a divided lot is FRUSCoreKit's
///          (`LotClaimantsIndex.swift`), given the series facts; the overload here passes the app's
enum LotClaimantsIndexStore {

    /// The bundled index, or `nil` when the resource is missing or malformed — in which case
    /// the app degrades to the pre-N-8b behaviour of naming one series, which is wrong but not
    /// broken.
    static let shared: LotClaimantsIndex? = load()

    private static func load() -> LotClaimantsIndex? {
        guard let url = Bundle.main.url(forResource: "lot-claimants-index",
                                        withExtension: "json") else {
            #if DEBUG
            print("[SourceExplorer] LotClaimantsIndexStore: lot-claimants-index.json not found.")
            #endif
            return nil
        }
        do {
            return try JSONDecoder().decode(LotClaimantsIndex.self,
                                            from: try Data(contentsOf: url))
        } catch {
            #if DEBUG
            print("[SourceExplorer] LotClaimantsIndexStore: decode failed — \(error)")
            #endif
            return nil
        }
    }
}

// MARK: - Rendering

extension LotClaimantsIndex {

    /// ``candidatesOutcome(forRawLot:in:seriesFacts:)`` with the app's bundled series facts
    /// (`SeriesFactsIndexStore`), read only for a lot NARA divided.
    static func candidatesOutcome(forRawLot raw: String,
                                  in index: LotClaimantsIndex?) -> CuratedLotOutcome? {
        candidatesOutcome(forRawLot: raw, in: index, seriesFacts: SeriesFactsIndexStore.shared)
    }
}
