// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CatalogQueryEvidence

/// What a live NARA catalogue result set is actually evidence of (#681).
///
/// ## Why this exists
/// Source Explorer issues three different catalogue queries and, until now, rendered all three
/// identically: the same "NARA Catalog" heading, the same rows, the same "View in NARA Catalog"
/// button. They are not the same kind of answer.
///
/// - A **lot-file** query asks for a specific control number and every result is put through
///   `LotResolutionAcceptance` — right record group, not a file unit, and *carries this control
///   number*. A row that survives that is evidence about the lot cited.
/// - A **record-group** query is constrained to the right record group and nothing else. The
///   result is in the right collection of collections; nothing ties it to the series cited.
/// - A **presidential-library** query is free text over the repository and collection names,
///   with no filter at all. Measured, that is 28,456 documents, and a result is evidence only
///   that some catalogue record shares vocabulary with the citation.
///
/// #669 already built the grammar for saying this — `CuratedLotOutcome.candidates`, a
/// `ConfidenceChip` beside each row and a caveat beneath. That grammar was applied to *curated*
/// results and not to live ones, which is the inversion this fixes: the curated matches were
/// hand-checked and hedged, while the unchecked live ones were presented flat.
///
/// ## Why a type rather than a branch in each view
/// There are two Source Explorer views, hand-written per platform, and this codebase has
/// shipped an affordance to one and not the other before. Both the classification and the
/// wording live here so the two cannot word the same hedge differently — or hedge on one
/// platform and not the other.
///
/// Version history:
///   1.0 — Session 2026-08-06: #681, live results adopt #669's candidate grammar
enum CatalogQueryEvidence: Sendable, Equatable {

    /// Every result carries the control number that was asked for, checked by
    /// `LotResolutionAcceptance`. The only branch that may be presented as a resolution.
    case controlNumberVerified

    /// Constrained to this record group, and to nothing narrower.
    case recordGroupOnly(recordGroup: String)

    /// Free text over the repository and collection names, with no filter.
    case collectionNameOnly

    /// How the citation `note` will be looked up, or `nil` when it takes no catalogue query.
    ///
    /// Mirrors the dispatch in both views' `loadCatalogResults`. A `.naraCollection` that names
    /// a lot is verified because #704 routes it to the guarded lot path — the classification
    /// has to track that reroute or it would describe a query the app no longer issues.
    static func forNote(_ note: ParsedSourceNote) -> CatalogQueryEvidence? {
        switch note {
        case .lotFile:
            return .controlNumberVerified
        case .naraCollection(let rg, _, let lot, _):
            return lot == nil ? .recordGroupOnly(recordGroup: rg) : .controlNumberVerified
        case .presidentialLibrary:
            return .collectionNameOnly
        default:
            return nil
        }
    }

    /// Whether results may be headed and worded as the answer rather than as candidates.
    var isVerified: Bool { self == .controlNumberVerified }

    /// The caveat a **durable copy** of a result must carry, or `nil` when the result was
    /// verified and needs none.
    ///
    /// ## Why this is separate from ``caveat``
    /// The chip and the caveat on screen qualify the rows a researcher is looking at. A Copy or
    /// an Export leaves the app: it lands in a research note, months from the moment the reader
    /// saw the chip, headed "NARA Catalog Record". So the hedge has to travel with it.
    ///
    /// macOS shipped exactly half of that. #680 added the manual-search caveat, gated on "did
    /// this come from the manual field?" — then #681 added a second way for an *automatic*
    /// result to be unverified (a record-group-only or collection-name-only query), and the
    /// export gate never learned about it. On screen those rows are chipped; copied, they were
    /// indistinguishable from a control-number-verified resolution. Measured, that is **26,667
    /// documents** — 9,580 record-group-only citations and the 17,087 presidential-library
    /// citations the bundled catalogue cannot answer.
    ///
    /// Both reasons are answered here, in the type both views already share, so a third reason
    /// cannot be added to one gate and not the other.
    ///
    /// - Parameters:
    ///   - evidence: what the automatic query constrained, or `nil` when none ran.
    ///   - isManualSearch: whether these rows came from the free-text field rather than the
    ///     automatic lookup. Takes precedence — the manual query is the actual producer, and
    ///     naming the automatic query's constraint would describe a query these rows did not
    ///     come from.
    static func exportCaveat(evidence: CatalogQueryEvidence?,
                             isManualSearch: Bool) -> String? {
        if isManualSearch {
            return String(localized: "source.explorer.manualSearch.exportCaveat",
                          defaultValue: """
                          NOTE: Result of a manual free-text search. It has not been checked \
                          against the cited lot number or record group.
                          """)
        }
        guard let caveat = evidence?.caveat else { return nil }
        return String(localized: "source.explorer.export.unverifiedCaveat",
                      defaultValue: "NOTE: \(caveat)")
    }

    /// The section heading. Unverified results say "Candidate" in the heading itself, because
    /// a caveat below the rows is read after the rows and often not at all.
    var sectionTitle: String {
        isVerified
            ? String(localized: "source.explorer.nara.header", defaultValue: "NARA Catalog")
            : String(localized: "source.explorer.nara.candidates.header",
                     defaultValue: "Candidate NARA Records")
    }

    /// What the query actually constrained, in the researcher's terms — stated so they can
    /// judge the rows rather than trust them. `nil` for the verified branch, which needs none.
    var caveat: String? {
        switch self {
        case .controlNumberVerified:
            return nil
        case .recordGroupOnly(let recordGroup):
            return String(localized: "source.explorer.nara.candidates.recordGroupOnly",
                          defaultValue: """
                          Matched by keyword within record group \(recordGroup). The record \
                          group is the one cited; nothing here ties these records to the \
                          series cited. Check the series title and dates before citing.
                          """)
        case .collectionNameOnly:
            return String(localized: "source.explorer.nara.candidates.collectionNameOnly",
                          defaultValue: """
                          Searched on the repository and collection names only — no catalog \
                          identifier constrains these results to the collection cited. Treat \
                          them as leads, and prefer the finding aid above.
                          """)
        }
    }
}
