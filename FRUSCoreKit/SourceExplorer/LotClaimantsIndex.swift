// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
#if canImport(SourceNoteKit)
import SourceNoteKit
#endif

// MARK: - LotClaimant

/// One NARA series that claims a FRUS lot number.
struct LotClaimant: Codable, Sendable, Equatable {
    /// NARA unique identifier.
    let naId: String
    /// The series title as NARA describes it.
    let title: String
    /// The record group NARA holds it in.
    let recordGroup: String?
    /// HMS/MLR entry numbers — what NARA staff use to pull the records.
    let hmsMlrEntryNumbers: [String]?
    /// Coverage span as NARA states it.
    let dateRange: String?
    /// `"controlNumber"` (the series lists the lot among its own control numbers) or
    /// `"consolidationNote"` (NARA names the lot in prose attached to another control number).
    let evidence: String

    /// Deep link to the catalogue record.
    var catalogURL: String { "https://catalog.archives.gov/id/\(naId)" }
}

// MARK: - LotClaimantsIndex

/// Which NARA series claim a FRUS lot number, for the lots where **more than one** does
/// (#675 / N-8b).
///
/// ## What it fixes
/// NARA divides a lot file across several series as readily as it consolidates several into one
/// — both are choices it makes after records leave the originating agency, and a
/// `variantControlNumber` on a series is its assertion that the series holds that lot. The
/// bundled `central-files-index.json` stores **one** `naId` per lot, so wherever NARA divided a
/// lot the app named one series and silently dropped the rest.
///
/// Measured on the shipped bundle: **123 lots, up to 13 claiming series on one lot** (`61D146`),
/// and six bundle rows collapse to the same naId — those citations were indistinguishable.
/// `64D563` alone rides 245 FRUS documents across 12 series.
///
/// The defect is an *undisclosed* pick, not a wrong one: every claimant is a correct answer. So
/// Source Explorer shows them all as candidates, in the grammar #669 already ships, rather than
/// choosing one and saying nothing.
///
/// ## Why a separate artifact
/// `central-files-index.json` is rebuilt wholesale by the keyed harvest, so a field added there
/// survives until the next run. This is built **offline** from the record-group harvest by
/// `LotClaimantsIndexGenerator` — no API key — and read alongside it, like
/// `curated-lot-resolutions.json`.
///
/// Version history:
///   1.0 — Session 2026-08-05: #675 / N-8b
///   1.1 — 2026-10-27 (FRUS Explorer Light, S18b): moved into FRUSCoreKit with `CentralFilesIndex` and
///          `VolumeSourcesIndex`, public, so a host outside the app decodes the bundled file and passes it in;
///          `LotClaimantsIndexStore` and Source Explorer's rendering of a divided lot stay in the app
///          (`LotClaimantsIndexStore.swift`)
///   1.2 — 2026-11-10 (FRUS Explorer Light, S22b): Source Explorer's rendering of a divided lot,
///          `candidatesOutcome(forRawLot:in:seriesFacts:)` and `unanimousCreator(_:)`, moved here from the app with
///          `SourceExplorerProvenance.lotCards`, which calls it; the series facts it names the creator from are a
///          parameter, and the app's overload without it passes its store
public struct LotClaimantsIndex: Codable, Sendable {
    /// Bumped when the row shape changes.
    let schemaVersion: Int
    /// Generation date (`YYYY-MM-DD`).
    let generated: String
    /// Why the file exists.
    let note: String?
    /// The `generated` stamp of the harvest it was derived from.
    let harvestGenerated: String?
    /// One entry per lot NARA divided.
    let lots: [Entry]

    /// A lot and every series claiming it.
    struct Entry: Codable, Sendable {
        let lotNumber: String
        let claimants: [LotClaimant]
    }

    /// The series claiming `raw`, or `nil` when NARA did not divide this lot.
    ///
    /// Matched on the same folded key the acceptance test uses, so a citation reading
    /// `64–D 563` finds the entry stored as `64D563`.
    func claimants(forRawLot raw: String) -> [LotClaimant]? {
        let key = LotResolutionAcceptance.foldControlNumber(raw)
        guard !key.isEmpty else { return nil }
        guard let found = lots.first(where: { $0.lotNumber == key })?.claimants,
              found.count > 1 else { return nil }
        return found
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
    ///
    /// - Parameter seriesFacts: The series facts the creator row reads, read only for a lot NARA divided;
    ///   the app passes its bundled index (`LotClaimantsIndexStore.swift`).
    static func candidatesOutcome(forRawLot raw: String,
                                  in index: LotClaimantsIndex?,
                                  seriesFacts: @autoclosure () -> SeriesFactsIndex?) -> CuratedLotOutcome? {
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
            series.map { seriesFacts()?.creator(forNaId: $0.naId) })
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
    /// inline in `candidatesOutcome`, which then needed the bundled store, so no test could reach it.
    static func unanimousCreator(_ creators: [String?]) -> String? {
        guard !creators.isEmpty, !creators.contains(where: { $0 == nil }) else { return nil }
        let distinct = Set(creators.compactMap { $0 })
        return distinct.count == 1 ? distinct.first : nil
    }
}
