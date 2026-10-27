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

    /// The claimants for `raw` as the `.candidates` outcome Source Explorer already renders
    /// (#669), or `nil` when NARA did not divide this lot.
    ///
    /// Mapping onto the existing grammar rather than adding a second one is deliberate: a
    /// divided lot and a creator-keyed curated lot are the same claim — *several series may
    /// hold this, none of them exclusively* — and the app should not have two ways of saying it.
    static func candidatesOutcome(forRawLot raw: String,
                                  in index: LotClaimantsIndex?) -> CuratedLotOutcome? {
        guard let claimants = index?.claimants(forRawLot: raw) else { return nil }
        let series = claimants.map {
            CuratedSeries(naId: $0.naId, title: $0.title, catalogURL: $0.catalogURL,
                          entryNumber: $0.hmsMlrEntryNumbers?.first, dateRange: $0.dateRange)
        }
        let rationale = String(
            format: String(localized: "source.explorer.dividedLot.rationale %lld",
                           defaultValue: "NARA divided this lot file across %lld series. Each series lists the lot among its own control numbers, so each holds part of the records this citation names. The citation alone does not say which one. Consult with NARA archivist staff for further assistance."),
            claimants.count)
        // #405: the `.candidates` grammar has always had a creator row; nothing ever filled it.
        let creatorName = unanimousCreator(
            series.map { SeriesFactsIndexStore.shared?.creator(forNaId: $0.naId) })
        return .candidates(series, rationale: rationale, creatorName: creatorName, seeAllURL: nil)
    }

    /// The one creator to name for a divided lot, or `nil`.
    ///
    /// Named **only when every claimant is covered and they all agree**. A lot NARA split across
    /// 13 series may have several creating offices, and naming one would be false for the rest;
    /// naming the creator of the subset that happens to be covered would be worse, because the
    /// reader cannot see which claimants it came from. Disagreement — and partial coverage — stay
    /// silent rather than resolved arbitrarily.
    ///
    /// A mutation sweep replaced this with `creators.first` and nothing caught it: the rule lived
    /// inline in `candidatesOutcome`, which needs the bundled store, so no test could reach it.
    static func unanimousCreator(_ creators: [String?]) -> String? {
        guard !creators.isEmpty, !creators.contains(where: { $0 == nil }) else { return nil }
        let distinct = Set(creators.compactMap { $0 })
        return distinct.count == 1 ? distinct.first : nil
    }
}
