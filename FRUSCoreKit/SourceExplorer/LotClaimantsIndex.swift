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
