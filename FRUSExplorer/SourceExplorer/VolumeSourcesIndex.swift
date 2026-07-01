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
            return lots[CentralFilesIndex.normalizeLot(lot)]
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

    /// The catalog record's URL, parsed once for `Link`/`openURL`.
    var url: URL? { URL(string: catalogURL) }
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
    /// The resolved NARA Catalog record, when one was found.
    let resolved: ArchivalResolution?
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
