// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CuratedLotOutcome

/// What hand curation established about a lot file that NARA's catalogue does not resolve
/// by control number (#375, workstream N-3).
///
/// The bundled `central-files-index.json` is binary: `lotFile(forRawLot:)` returns one
/// series or nothing. That shape cannot state the three answers curation actually produced,
/// and every one of them is a claim about *uncertainty*, so widening the existing entry with
/// an optional flag would have been the wrong mechanism — an optional decodes as `nil` in
/// every reader that does not know it, and `nil` reads as "confident" everywhere in this
/// codebase (`LotFileEntry.matchType` literally defaults to `"control"` on a missing key).
/// A separate type makes the uncertainty impossible to drop by omission.
enum CuratedLotOutcome: Sendable, Equatable {

    /// One NARA series, reached by collection name rather than by control number.
    /// Shown with a "Possible" confidence chip and the rationale that produced it.
    ///
    /// The same NAID can be **certain** for a different lot: NAID 602875 (Conference Files)
    /// is a control-number resolution for nine lots in `central-files-index.json` and a
    /// possible match for four here. Confidence therefore belongs to the *(lot → NAID)*
    /// edge, never to the NAID — which is why this is keyed by lot and why the #351
    /// `untrustworthyNAIDs` denylist (keyed by NAID) could not have carried it.
    case possible(CuratedSeries, rationale: String)

    /// Several plausible series under one NARA creator, none individually confirmable.
    /// Every candidate is shown, each with a "Possible" chip.
    case candidates([CuratedSeries], rationale: String, creatorName: String?, seeAllURL: URL?)

    /// No mechanical lot → series mapping exists, because NARA re-arranged the collection
    /// on a different principle than the one FRUS cites. The honest answer is to name the
    /// obstacle and hand the researcher to NARA reference staff.
    case referral(CuratedReferral)
}

// MARK: - CuratedSeries

/// One NARA series a curated lot may correspond to.
struct CuratedSeries: Codable, Sendable, Equatable, Identifiable {
    /// NARA unique identifier.
    let naId: String
    /// The series title as NARA describes it.
    let title: String
    /// Deep link to the catalogue record.
    let catalogURL: String
    /// HMS/MLR entry number (e.g. `A1-1096`) — the identifier NARA staff use to pull records.
    let entryNumber: String?
    /// Coverage span as NARA states it (e.g. `1946–1947`).
    let dateRange: String?

    var id: String { naId }

    /// `catalogURL` as a `URL`, or `nil` when the stored string is not one.
    var url: URL? { URL(string: catalogURL) }
}

// MARK: - CuratedReferral

/// The archivist-referral outcome: what stands in the way, and what to ask NARA for.
struct CuratedReferral: Codable, Sendable, Equatable {
    /// Why no mapping exists — the archival fact, stated plainly.
    let rationale: String
    /// What the researcher should do instead, including what to bring to a reference request.
    let guidance: String
    /// How many series the collection was arranged into, when known — the number is the
    /// argument: a list of 170 is not a candidate list, it is a reason to ask for help.
    let seriesCount: Int?
    /// The span of HMS/MLR entry numbers the collection occupies (e.g. `A1 310 – A1 675`).
    let entryNumberRange: String?
    /// A catalogue search that shows the collection's series, for orientation only.
    let browseURL: String?

    /// `browseURL` as a `URL`, or `nil` when absent or malformed.
    var url: URL? { browseURL.flatMap(URL.init(string:)) }
}

// MARK: - CuratedLotRecord

/// One curated lot as stored in `curated-lot-resolutions.json`.
///
/// `kind` discriminates the three outcomes; the fields each kind needs are optional at the
/// storage layer and validated when `outcome` is built, so a malformed row yields `nil`
/// rather than a half-rendered card.
struct CuratedLotRecord: Codable, Sendable, Equatable {
    /// Compact upper-cased lot key in `CentralFilesIndex.normalizeLot` form (`54D270`).
    let lotNumber: String
    /// `"possible"`, `"candidates"`, or `"referral"`.
    let kind: String
    /// The collection's name as FRUS cites it (`Marshall Mission Files`), for display.
    let displayName: String?
    /// The record group the curation established — **authoritative over the parser's guess**,
    /// which defaults every non-`F` lot to RG 59 and so labels `M88` as RG 59 when it is RG 43.
    let recordGroup: String?
    /// Why this outcome, in one or two sentences. Rendered beneath the chip.
    let rationale: String?

    // `possible`
    let naId: String?
    let title: String?
    let catalogURL: String?
    let hmsMlrEntryNumbers: [String]?
    let dateRange: String?

    // `candidates`
    let creatorName: String?
    let creatorNaId: String?
    let seeAllURL: String?
    let candidates: [CuratedSeries]?

    // `referral`
    let guidance: String?
    let seriesCount: Int?
    let entryNumberRange: String?
    let browseURL: String?

    /// The typed outcome, or `nil` when the row does not carry what its `kind` requires.
    var outcome: CuratedLotOutcome? {
        switch kind {
        case "possible":
            guard let naId, let title, let catalogURL, let rationale else { return nil }
            return .possible(
                CuratedSeries(naId: naId, title: title, catalogURL: catalogURL,
                              entryNumber: hmsMlrEntryNumbers?.first, dateRange: dateRange),
                rationale: rationale)
        case "candidates":
            guard let candidates, !candidates.isEmpty, let rationale else { return nil }
            return .candidates(candidates, rationale: rationale, creatorName: creatorName,
                               seeAllURL: seeAllURL.flatMap(URL.init(string:)))
        case "referral":
            guard let rationale, let guidance else { return nil }
            return .referral(CuratedReferral(rationale: rationale, guidance: guidance,
                                             seriesCount: seriesCount,
                                             entryNumberRange: entryNumberRange,
                                             browseURL: browseURL))
        default:
            return nil
        }
    }
}

// MARK: - CuratedLotResolutions

/// The bundled hand-curated lot outcomes (#375).
///
/// ## Why this is its own artifact
/// Nothing generates it. Every row is human archival judgement, and three separate generator
/// paths rewrite `central-files-index.json` wholesale — a full `CITATIONS_CSV` harvest replaces
/// the whole `lotFiles` array, `ENRICH_LOTS` overwrites level and flag fields in place, and the
/// writer re-encodes from a five-property model that silently drops any key it does not declare.
/// Curated rows kept in that file would survive exactly until the next run.
///
/// ## Containment
/// These rows are deliberately **not** written into `central-files-index.json`,
/// `volume-sources-index.json`, or `collection-authority.json`. Those bundles feed surfaces
/// with nowhere to put a caveat: `VolumeSourcesView` renders a resolution as a bare
/// `building.columns` icon link, `CollectionGeneratedBlocks` flattens one into a two-field
/// export row that becomes a durable line in a PDF, and `CollectionDetailView` captions a NAID
/// with "resolved offline from the bundled index". Printing a possible match through any of
/// those states a certainty the curation does not have. Confining curated outcomes to the two
/// Source Explorer views — the only surfaces that can show a chip and a rationale — means every
/// other surface keeps showing "unresolved", which is true. `CuratedLotContainmentTests` pins it.
///
/// Version history:
///   1.0 — Session 2026-08-03: #375 curated lot outcomes (N-3)
struct CuratedLotResolutions: Codable, Sendable {
    /// Bumped when the row shape changes.
    let schemaVersion: Int
    /// Curation date (`YYYY-MM-DD`).
    let generated: String
    /// Why the file exists, for whoever opens it next.
    let note: String?
    /// One row per curated lot.
    let lots: [CuratedLotRecord]

    /// The curated record for `raw`, matched on the same normalized key
    /// `CentralFilesIndex.lotFile(forRawLot:)` uses, or `nil` when the lot is not curated.
    func record(forRawLot raw: String) -> CuratedLotRecord? {
        let key = CentralFilesIndex.normalizeLot(raw)
        return lots.first { $0.lotNumber == key }
    }

    /// The curated outcome for `raw`, or `nil` when the lot is not curated (or its row is
    /// malformed — a bad row is treated as absent, so the app falls back to today's honest
    /// "no matching record" rather than rendering half a card).
    func outcome(forRawLot raw: String) -> CuratedLotOutcome? {
        record(forRawLot: raw)?.outcome
    }

    /// The record group curation established for `raw`, in the parser's `RG-59` form.
    /// Callers must prefer this over `SourceNoteParser`'s guess, which defaults every
    /// non-`F` lot to RG 59 and is wrong for at least one curated collection.
    func recordGroup(forRawLot raw: String) -> String? {
        record(forRawLot: raw)?.recordGroup
    }
}

// MARK: - CuratedLotResolutionsStore

/// Loads the bundled curated lot outcomes once, mirroring `CentralFilesIndexStore`.
///
/// Version history:
///   1.0 — Session 2026-08-03: #375 curated lot outcomes (N-3)
enum CuratedLotResolutionsStore {

    /// The bundled curated outcomes, or `nil` when the resource is missing or malformed.
    /// A `nil` store degrades to the pre-curation behaviour, which is honest rather than wrong.
    static let shared: CuratedLotResolutions? = load()

    private static func load() -> CuratedLotResolutions? {
        guard let url = Bundle.main.url(forResource: "curated-lot-resolutions",
                                        withExtension: "json") else {
            #if DEBUG
            print("[SourceExplorer] CuratedLotResolutionsStore: curated-lot-resolutions.json not found in bundle.")
            #endif
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(CuratedLotResolutions.self, from: data)
        } catch {
            #if DEBUG
            print("[SourceExplorer] CuratedLotResolutionsStore: failed to decode curated-lot-resolutions.json — \(error)")
            #endif
            return nil
        }
    }
}
