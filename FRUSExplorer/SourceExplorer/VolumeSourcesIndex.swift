// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - VolumeSourcesIndex

/// The bundled `volume-sources-index.json` (schema v2): the archival-source *resolutions*
/// the app cannot derive locally — front-matter record-group headers and lot-file citations
/// mapped to their NARA Catalog records — plus a cross-volume authority of the major
/// collections and which volumes cite each.
///
/// The app already re-parses every volume's Sources section into the `volume_sources` SQLite
/// table at index time (`IndexingPipeline` → ``VolumeSourcesView``), so this artifact ships
/// only the resolution maps and the authority, **not** the per-volume trees. A parsed source
/// node is resolved by looking its record group / normalized lot number up in this index —
/// the keys are produced with the same `CentralFilesIndex.normalizeLot` the generator uses.
///
/// Produced offline by the `VolumeSourcesIndexGenerator` SPM tool.
///
/// Version history:
///   1.0 — Session 2026-07-01: initial implementation (corpus-browser rework, item 3b)
struct VolumeSourcesIndex: Decodable, Sendable {

    /// Record-group headers → their resolved record, keyed by record-group **number** (`"59"`).
    let recordGroups: [String: ArchivalResolution]
    /// Lot-file citations → their resolved record, keyed by **normalized** lot number
    /// (`CentralFilesIndex.normalizeLot`, e.g. `"80D212"`).
    ///
    /// **Only the lots `central-files-index.json` cannot answer** (#372 / N-5 PR 2, the fold).
    /// Both bundles used to carry a lot map; 751 keys were in both and agreed on every rendered
    /// field. Since every reader consults central-files first — `ArchivalResolver` in the app,
    /// `OfflineNAIDResolver` in the authority generator, `applyResolution` in the volume-sources
    /// generator itself — the duplicates were pure weight. This map is now the *difference*, and
    /// the two are disjoint by construction (pinned by `VolumeSourcesIndexTests`).
    ///
    /// **Empty on the shipped artifact** since #372 item 1: `FOLD_VOLUME_SOURCES` admitted the
    /// last seven orphans into central-files, so the difference is nothing. The map and its
    /// readers stay — a re-harvest can mint a new orphan, and `lotsToWrite`'s carry-forward is
    /// what keeps one alive through a keyless run — but no lot on screen resolves through here
    /// today.
    let lots: [String: ArchivalResolution]
    /// The cross-volume authority, keyed by each collection's dedup key for O(1) lookup.
    let authorityByKey: [String: MajorCollectionRecord]

    private enum CodingKeys: String, CodingKey {
        case recordGroups, lots, majorCollections
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        recordGroups = try c.decode([String: ArchivalResolution].self, forKey: .recordGroups)
        lots = try c.decode([String: ArchivalResolution].self, forKey: .lots)
        let collections = try c.decode([MajorCollectionRecord].self, forKey: .majorCollections)
        authorityByKey = Dictionary(collections.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// The resolved NARA Catalog record for a parsed source node.
    ///
    /// A node that carries a lot file resolves **only** through its lot (the most specific
    /// match) — an unresolved lot returns `nil` rather than falling back to the node's record
    /// group, which would stamp a generic record-group link on every unmatched lot. A node
    /// without a lot resolves through its record-group header. This mirrors the generator's
    /// `applyResolution` (`if lotFile … else if recordGroup …`).
    func resolution(recordGroup: String?, lotFile: String?) -> ArchivalResolution? {
        if let lot = lotFile?.trimmingCharacters(in: .whitespacesAndNewlines), !lot.isEmpty {
            // #351: a fileUnit-level lot resolution is a wrong-collection mis-resolution (the
            // 60 D 627 → "Operation Mongoose" class the #335 audit flagged, baked into this
            // bundle before the resolver guard). Treat it as unresolved at the source so **every**
            // consumer is covered — the browser Sources row, and the Collections "Sources &
            // Archives" block whose PDF/DOCX/HTML export would otherwise print a durable wrong
            // NARA link. Durable until #352 re-resolves the lot and regenerates the bundle.
            guard let hit = lots[CentralFilesIndex.normalizeLot(lot)], !hit.isFileUnitLevel else {
                return nil
            }
            return hit
        }
        if let rg = recordGroup?.trimmingCharacters(in: .whitespacesAndNewlines), !rg.isEmpty {
            return recordGroups[rg]
        }
        return nil
    }

    /// The cross-volume authority entry for a parsed source node — which volumes' Sources
    /// sections cite this same collection — or `nil` when it is not a tracked collection.
    ///
    /// The dedup key mirrors the generator's `accumulateAuthority`: `lot:<normalized>` when a
    /// lot file is present, otherwise `txt:<lowercased text>`.
    func authority(recordGroup: String?, lotFile: String?, text: String) -> MajorCollectionRecord? {
        let key: String
        if let lot = lotFile?.trimmingCharacters(in: .whitespacesAndNewlines), !lot.isEmpty {
            key = "lot:" + CentralFilesIndex.normalizeLot(lot)
        } else {
            key = "txt:" + text.lowercased()
        }
        return authorityByKey[key]
    }
}

// MARK: - ArchivalResolution

/// A resolved NARA Catalog record for an archival collection (a record group or a lot file).
struct ArchivalResolution: Decodable, Sendable, Equatable {
    /// NARA Catalog National Archives Identifier.
    let naId: String
    /// Canonical `catalog.archives.gov/id/<naId>` URL string.
    let catalogURL: String
    /// The record's authority title (e.g. "General Records of the Department of State").
    let title: String
    /// The owning record group's number, when known.
    let recordGroup: String?
    /// How the match was made: `lot` (bundled index), `api` (NARA Catalog query), or `manual`.
    let matchType: String
    /// The series' **HMS/MLR Entry Number(s)** — what NARA staff ask researchers to quote when
    /// requesting the records (#315/#322). Carried through from the enriched central-files index
    /// so this surface shows the same detail as Source Explorer. `nil` for record-group / API
    /// resolutions and un-enriched bundles (both render as nothing). Synthesized `Decodable`
    /// treats the missing key as `nil`, so older bundles still decode.
    let hmsMlrEntryNumbers: [String]?
    /// The resolved record's catalog level (`series`, `fileUnit`, …), when known (#315/#322).
    let levelOfDescription: String?
    /// NAID of the enclosing file series, when this record is a file unit rather than a series.
    let seriesNaId: String?
    /// Title of the enclosing file series, for records whose own `title` names a file unit.
    let seriesTitle: String?
    /// The **enclosing series'** HMS/MLR entry numbers — the parent's identifiers, not this
    /// record's; kept separate because a parent series may carry many (#315/#322).
    let seriesHmsMlrEntryNumbers: [String]?

    /// The catalog record's URL, parsed once for `Link`/`openURL`.
    var url: URL? { URL(string: catalogURL) }

    /// Whether the resolved record is described at the series level — i.e. whether `title` is
    /// itself the file series name. `nil` level (an un-enriched bundle) reads as `false`.
    var isSeriesLevel: Bool { levelOfDescription == "series" }

    /// Whether this resolution landed on a **file unit** rather than a series (#351). A State
    /// lot file is catalogued as a series; a `fileUnit` match is the wrong-collection class the
    /// #335 audit flagged (60 D 627 → "Operation Mongoose"), baked into this bundle before the
    /// resolver guard. The catalog affordance is withheld for these until #352 re-resolves them.
    var isFileUnitLevel: Bool { levelOfDescription == "fileUnit" }

    /// The **file series name** to display — the single accessor the UI should use, so the
    /// series/file-unit distinction cannot be got wrong at a call site (#315/#322). Mirrors
    /// `CentralFilesIndex.LotFileEntry.displaySeriesTitle`.
    var displaySeriesTitle: String? { isSeriesLevel ? title : seriesTitle }
}

// MARK: - MajorCollectionRecord

/// One collection in the cross-volume authority: which volumes' Sources sections cite it.
struct MajorCollectionRecord: Decodable, Sendable, Equatable {
    /// Stable dedup key (`lot:<normalized>` or `txt:<lowercased text>`).
    let key: String
    /// The collection's display text.
    let text: String
    /// Whether the collection was a `<hi rend="strong">` heading (a major named collection).
    let isHeading: Bool
    /// The owning record group's number, when parsed.
    let recordGroup: String?
    /// The lot-file citation, when present.
    let lotFile: String?
    /// The holding repository, when named.
    let repository: String?
    // `resolved` was here. It is no longer serialized (#372 / N-5 PR 2): nothing ever read it
    // — this record is consulted only for `volumeIds`, to caption "Cited in N volumes" — and 758
    // of its 932 populated objects duplicated a `lots` entry verbatim. 307,810 bytes, 20.4% of
    // the artifact, decoded on every launch and discarded. An older bundle that still carries the
    // key simply decodes without it.
    /// Volumes whose Sources section cites this collection, sorted.
    let volumeIds: [String]
    /// Total citing nodes across all volumes.
    let occurrences: Int
}

// MARK: - VolumeSourcesIndexStore

/// Loads and caches the bundled `volume-sources-index.json`.
///
/// The index is decoded once, lazily, on first access. `shared` is `nil` only when the
/// resource is missing or cannot be decoded (logged in DEBUG). Mirrors
/// ``CentralFilesIndexStore``.
///
/// Version history:
///   1.0 — Session 2026-07-01: initial implementation
enum VolumeSourcesIndexStore {

    /// The bundled volume-sources resolution index, or `nil` if unavailable. Loaded once.
    static let shared: VolumeSourcesIndex? = load()

    private static func load() -> VolumeSourcesIndex? {
        guard let url = Bundle.main.url(forResource: "volume-sources-index", withExtension: "json") else {
            #if DEBUG
            print("[Browser] VolumeSourcesIndexStore: volume-sources-index.json not found in bundle.")
            #endif
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(VolumeSourcesIndex.self, from: data)
        } catch {
            #if DEBUG
            print("[Browser] VolumeSourcesIndexStore: failed to decode volume-sources-index.json — \(error)")
            #endif
            return nil
        }
    }
}
