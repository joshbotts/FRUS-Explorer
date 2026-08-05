// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - LotResolutionAcceptance

/// Whether a NARA Catalog record may be surfaced as the resolution of a State Department
/// lot file (#674 / N-8).
///
/// ## Why this exists
/// The bundle-building generator has applied a three-conjunct acceptance test since #352
/// (`CatalogRecord.isAcceptableLotResolution`). **The app never had one.** Its live path
/// tried three exact `variantControlNumber_is` forms and, when all three correctly returned
/// nothing, fell back to a free-text phrase query taking the single top hit — which is how
/// lot `90 D 234` (the Bureau of Oceans' Antarctic files) came to resolve to a **Census
/// Bureau** series.
///
/// The generator's own client had already written down why that happens
/// (`NARACatalogHarvestClient.swift:413-416`): NARA's record-group filter does not constrain
/// free-text results, and *"the top hit for a lot string is often a giant wrong-RG series
/// (census/military/court)"*. It was hardened; the app was not. This type is the rule, in a
/// module both sides can compile, so there is one definition rather than two that drift.
///
/// ## The three conjuncts
/// Each closes a mis-resolution class the #335 audit found:
/// 1. the record's own record group matches the one being asked about — never a coincidental
///    free-text hit in another RG;
/// 2. it is not a **file unit** — a State Department lot file is catalogued as a *series*;
/// 3. it actually carries the queried lot in its `variantControlNumbers`.
///
/// Conjunct 3 is what makes the free-text fallback safe to keep rather than delete. The
/// exact `variantControlNumber_is` query matches only the literal spellings the caller
/// generated (`74D476`, `74 D 476`, `74 D476`), so a record NARA indexed as
/// `"Lot File 74D476"` is invisible to it — but `foldControlNumber` strips that prefix, so
/// the free-text hit can still be *verified*. The fallback stops being a guess and becomes a
/// second lookup with the same standard of proof.
///
/// ## What it deliberately does not do
/// It cannot tell one bureau's `66 D 50` from another's. State assigned lot numbers per
/// accession, so two offices could each hold that number and NARA catalogued both; all three
/// conjuncts pass for either. That is #675, and it needs the citation's own office name —
/// which this type is not given. Do not read a `true` here as "this is the right collection",
/// only as "this record is not obviously the wrong one".
///
/// Version history:
///   1.0 — Session 2026-08-04: #674 / N-8, extracted so the app and the generator share one rule
public enum LotResolutionAcceptance {

    /// NARA's `levelOfDescription` value for a file unit — the level a lot file is never
    /// catalogued at, and the one #351 found behind the worst mis-resolutions.
    public static let fileUnitLevel = "fileUnit"

    /// Folds a raw control-number string to the compact lot key form: uppercase, drop spaces
    /// and every dash variant, then strip a single leading `LOT` or `LOTFILE` token.
    ///
    /// The dash list covers the typographic forms FRUS and NARA both use — hyphen, en dash,
    /// em dash — because a citation reading `61–D 146` and a catalogue entry reading
    /// `61-D-146` are the same lot.
    public static func foldControlNumber(_ raw: String) -> String {
        var s = raw.uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "–", with: "")
            .replacingOccurrences(of: "—", with: "")
        for prefix in ["LOTFILE", "LOT"] where s.hasPrefix(prefix) {
            s.removeFirst(prefix.count)
            break
        }
        return s
    }

    /// Whether `variantControlNumbers` contains `normalizedLot` as a **whole** control number.
    ///
    /// Equality, never `contains` — `"160D6270"` must not spuriously satisfy `"60D627"`.
    /// Both sides are folded so a raw or spaced key still matches.
    public static func carriesLotControlNumber(
        _ normalizedLot: String,
        variantControlNumbers: [String]
    ) -> Bool {
        let target = foldControlNumber(normalizedLot)
        guard !target.isEmpty else { return false }
        return variantControlNumbers.contains { foldControlNumber($0) == target }
    }

    /// Whether a candidate record may be surfaced as the resolution of `normalizedLot` in
    /// `recordGroup`.
    ///
    /// A `nil` `candidateRecordGroup` or a `nil` `levelOfDescription` **fails** the test:
    /// #321 removed a last-resort branch that accepted records with no exposed record group,
    /// and absence of evidence is not evidence here.
    public static func isAcceptable(
        recordGroup: String,
        normalizedLot: String,
        candidateRecordGroup: String?,
        levelOfDescription: String?,
        variantControlNumbers: [String]
    ) -> Bool {
        guard let candidateRecordGroup, candidateRecordGroup == recordGroup else { return false }
        guard let levelOfDescription, levelOfDescription != fileUnitLevel else { return false }
        return carriesLotControlNumber(normalizedLot, variantControlNumbers: variantControlNumbers)
    }
}
