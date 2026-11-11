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
public enum CuratedLotOutcome: Sendable, Equatable {

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
public struct CuratedSeries: Codable, Sendable, Equatable, Identifiable {
    /// NARA unique identifier.
    public let naId: String
    /// The series title as NARA describes it.
    public let title: String
    /// Deep link to the catalogue record.
    public let catalogURL: String
    /// HMS/MLR entry number (e.g. `A1-1096`) — the identifier NARA staff use to pull records.
    public let entryNumber: String?
    /// Coverage span as NARA states it (e.g. `1946–1947`).
    public let dateRange: String?

    public var id: String { naId }

    /// `catalogURL` as a `URL`, or `nil` when the stored string is not one.
    public var url: URL? { URL(string: catalogURL) }
}

// MARK: - CuratedReferral

/// The archivist-referral outcome: what stands in the way, and what to ask NARA for.
public struct CuratedReferral: Codable, Sendable, Equatable {
    /// Why no mapping exists — the archival fact, stated plainly.
    public let rationale: String
    /// What the researcher should do instead, including what to bring to a reference request.
    public let guidance: String
    /// How many series the collection was arranged into, when known — the number is the
    /// argument: a list of 170 is not a candidate list, it is a reason to ask for help.
    public let seriesCount: Int?
    /// The span of HMS/MLR entry numbers the collection occupies (e.g. `A1 310 – A1 675`).
    public let entryNumberRange: String?
    /// A catalogue search that shows the collection's series, for orientation only.
    public let browseURL: String?

    /// `browseURL` as a `URL`, or `nil` when absent or malformed.
    public var url: URL? { browseURL.flatMap(URL.init(string:)) }
}

// MARK: - CuratedSeriesDefinition

/// A NARA series several curated lots share, defined once in `curated-lot-resolutions.json`'s
/// `series` map and referenced by `seriesRef`.
///
/// Eighteen of the curated lots resolve to the same Conference Files series. Repeating its
/// title, NAID, entry number, span and rationale on every row would mean editing eighteen
/// places to reword one sentence, and would leave the "these are the same answer" relationship
/// implied by copy-paste rather than stated in the data.
struct CuratedSeriesDefinition: Codable, Sendable, Equatable {
    /// NARA unique identifier.
    let naId: String
    /// The series title as NARA describes it.
    let title: String
    /// Deep link to the catalogue record.
    let catalogURL: String
    /// HMS/MLR entry numbers — the identifiers NARA staff use to pull records.
    let hmsMlrEntryNumbers: [String]?
    /// Coverage span as NARA states it.
    let dateRange: String?
    /// The record group NARA holds it in, in the parser's `RG-59` form.
    let recordGroup: String?
    /// Why a lot referencing this series is only a *possible* match. A row may override it.
    let rationale: String?

    /// The shared definition as a renderable series.
    var series: CuratedSeries {
        CuratedSeries(naId: naId, title: title, catalogURL: catalogURL,
                      entryNumber: hmsMlrEntryNumbers?.first, dateRange: dateRange)
    }
}

// MARK: - CuratedLotRecord

/// One curated lot as stored in `curated-lot-resolutions.json`.
///
/// `kind` discriminates the three outcomes; the fields each kind needs are optional at the
/// storage layer and validated when `outcome` is built, so a malformed row yields `nil`
/// rather than a half-rendered card.
public struct CuratedLotRecord: Codable, Sendable, Equatable {
    /// Compact upper-cased lot key in `CentralFilesIndex.normalizeLot` form (`54D270`).
    public let lotNumber: String
    /// `"possible"`, `"candidates"`, or `"referral"`.
    public let kind: String
    /// The collection's name as FRUS cites it (`Marshall Mission Files`), for display.
    public let displayName: String?
    /// The record group the curation established — **authoritative over the parser's guess**,
    /// which defaults every non-`F` lot to RG 59 and so labels `M88` as RG 59 when it is RG 43.
    public let recordGroup: String?
    /// Why this outcome, in one or two sentences. Rendered beneath the chip.
    public let rationale: String?

    /// Key into the index's `series` map, when this row shares a series with others.
    /// A row's own inline fields win over the referenced definition.
    public let seriesRef: String?
    /// Collection names that route to this row even when the citation carries no lot number
    /// (the `namedFileSeries` parse). Matched case- and punctuation-insensitively.
    public let seriesNames: [String]?

    // `possible`
    public let naId: String?
    public let title: String?
    public let catalogURL: String?
    public let hmsMlrEntryNumbers: [String]?
    public let dateRange: String?

    // `candidates`
    public let creatorName: String?
    public let creatorNaId: String?
    public let seeAllURL: String?
    public let candidates: [CuratedSeries]?

    // `referral`
    public let guidance: String?
    public let seriesCount: Int?
    public let entryNumberRange: String?
    public let browseURL: String?

    /// The typed outcome, or `nil` when the row does not carry what its `kind` requires —
    /// resolving `seriesRef` against `series` and letting the row's own fields win.
    ///
    /// A dangling `seriesRef` yields `nil` rather than a half-built card, and
    /// `CuratedLotResolutionsTests` fails the build if the shipped file contains one.
    func outcome(resolving series: [String: CuratedSeriesDefinition]) -> CuratedLotOutcome? {
        let shared = seriesRef.flatMap { series[$0] }
        if seriesRef != nil && shared == nil { return nil }
        switch kind {
        case "possible":
            guard let resolved = resolvedSeries(shared),
                  let why = rationale ?? shared?.rationale else { return nil }
            return .possible(resolved, rationale: why)
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

    /// This row's series: its own inline fields when present, otherwise the shared definition.
    private func resolvedSeries(_ shared: CuratedSeriesDefinition?) -> CuratedSeries? {
        if let naId, let title, let catalogURL {
            return CuratedSeries(naId: naId, title: title, catalogURL: catalogURL,
                                 entryNumber: hmsMlrEntryNumbers?.first, dateRange: dateRange)
        }
        return shared?.series
    }

    /// The record group this row establishes — its own, or the shared series' — in the
    /// parser's `RG-59` form.
    func effectiveRecordGroup(resolving series: [String: CuratedSeriesDefinition]) -> String? {
        recordGroup ?? seriesRef.flatMap { series[$0] }?.recordGroup
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
///   1.1 — 2026-11-08 (FRUS Explorer Light, S22a): moved into FRUSCoreKit, public with its decoder, and
///          loaded from a URL the host gives (`init(contentsOf:)`); `CuratedLotResolutionsStore`, which
///          reads the app's bundle, stays in the app (`CuratedLotResolutionsStore.swift`)
///   1.2 — 2026-11-10 (FRUS Explorer Light, S22b): `CuratedLotOutcome`, `CuratedSeries` and `CuratedReferral` public, since
///          the lot cards hold them
///   1.3 — 2026-11-11 (FRUS Explorer Light, S22c): `CuratedLotRecord` public, and the record, outcome and
///          record-group lookups both Source Explorer views read while they draw, for a host that draws what
///          they draw
public struct CuratedLotResolutions: Codable, Sendable {
    /// Bumped when the row shape changes.
    let schemaVersion: Int
    /// Curation date (`YYYY-MM-DD`).
    let generated: String
    /// Why the file exists, for whoever opens it next.
    let note: String?
    /// NARA series shared by more than one row, keyed by `seriesRef`.
    let series: [String: CuratedSeriesDefinition]?
    /// One row per curated collection.
    let lots: [CuratedLotRecord]

    /// The shared series definitions, or an empty map when the file declares none.
    private var seriesMap: [String: CuratedSeriesDefinition] { series ?? [:] }

    /// The curated record for `raw`, matched on the same normalized key
    /// `CentralFilesIndex.lotFile(forRawLot:)` uses, or `nil` when the lot is not curated.
    public func record(forRawLot raw: String) -> CuratedLotRecord? {
        let key = CentralFilesIndex.normalizeLot(raw)
        return lots.first { $0.lotNumber == key }
    }

    /// The curated outcome for `raw`, or `nil` when the lot is not curated (or its row is
    /// malformed — a bad row is treated as absent, so the app falls back to today's honest
    /// "no matching record" rather than rendering half a card).
    public func outcome(forRawLot raw: String) -> CuratedLotOutcome? {
        record(forRawLot: raw)?.outcome(resolving: seriesMap)
    }

    /// The record group curation established for `raw`, in the parser's `RG-59` form.
    /// Callers must prefer this over `SourceNoteParser`'s guess, which defaults every
    /// non-`F` lot to RG 59 and is wrong for at least one curated collection.
    public func recordGroup(forRawLot raw: String) -> String? {
        record(forRawLot: raw)?.effectiveRecordGroup(resolving: seriesMap)
    }

    /// The curated record a `namedFileSeries` citation belongs to — one that names the
    /// collection but carries no lot number, so it never reaches the lot path at all.
    ///
    /// "CFM Files" is cited both ways: 697 documents carry lot M-88 and a further 376 name
    /// the collection alone. The archival answer is the same for both, and before this
    /// lookup existed the second group saw nothing.
    public func record(forSeriesName name: String) -> CuratedLotRecord? {
        let key = CuratedLotResolutions.normalizeSeriesName(name)
        guard !key.isEmpty else { return nil }
        return lots.first { record in
            (record.seriesNames ?? []).contains { CuratedLotResolutions.normalizeSeriesName($0) == key }
        }
    }

    /// The curated outcome for a named file series, or `nil` when it is not curated.
    public func outcome(forSeriesName name: String) -> CuratedLotOutcome? {
        record(forSeriesName: name)?.outcome(resolving: seriesMap)
    }

    /// The record group curation established for a named file series.
    public func recordGroup(forSeriesName name: String) -> String? {
        record(forSeriesName: name)?.effectiveRecordGroup(resolving: seriesMap)
    }

    /// Case- and punctuation-insensitive series key. FRUS spells the same collection many
    /// ways — `J. C. S. Files` has nine distinct spellings in the corpus — so an exact match
    /// would resolve one spelling and silently miss the rest.
    static func normalizeSeriesName(_ raw: String) -> String {
        raw.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}

// MARK: - Loading

extension CuratedLotResolutions {

    /// The curated outcomes in the `curated-lot-resolutions.json` at `url`, decoded as
    /// `CuratedLotResolutionsStore` decodes the copy bundled with the app, for a host that keeps the file
    /// elsewhere.
    public init(contentsOf url: URL) throws {
        self = try JSONDecoder().decode(CuratedLotResolutions.self, from: Data(contentsOf: url))
    }
}
