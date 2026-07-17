// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import VolumeSourcesIndexGeneratorCore

/// Resolves lot files to NARA Catalog records **entirely offline**, chaining the three
/// existing resolution sources in trust order — the generator never calls the live
/// NARA API:
///
/// 1. `central-files-index.json` (`BundledLotResolver`) — control-number-verified lot
///    records harvested by `CentralFilesIndexGenerator` Phase 3;
/// 2. the bundled `volume-sources-index.json` `lots` map — the offline+cached
///    resolutions `VolumeSourcesIndexGenerator` shipped;
/// 3. the `.cache/volume-sources/lots` per-lot cache files written by that generator's
///    API pass (`<recordGroup>_<lotNorm>.json`; an empty `naId` marks a confirmed miss).
public struct OfflineNAIDResolver: Sendable {

    private let bundled: BundledLotResolver?
    private let indexLots: [String: ResolvedNAID]
    private let cacheLots: [String: ResolvedNAID]

    /// Loads whichever sources exist; missing files simply shrink the chain.
    ///
    /// - Parameters:
    ///   - centralFilesIndexURL: Path of `central-files-index.json` (optional).
    ///   - volumeSourcesIndexURL: Path of the bundled `volume-sources-index.json` (optional).
    ///   - cacheDirectory: The `VolumeSourcesIndexGenerator` cache directory
    ///     (`.cache/volume-sources`), read-only (optional).
    public init(centralFilesIndexURL: URL?, volumeSourcesIndexURL: URL?, cacheDirectory: URL?) {
        bundled = centralFilesIndexURL.flatMap { try? BundledLotResolver(indexURL: $0) }
        indexLots = Self.loadIndexLots(volumeSourcesIndexURL)
        cacheLots = Self.loadCacheLots(cacheDirectory)
    }

    /// The number of distinct offline lot resolutions available across all sources.
    public var lotCount: Int {
        Set(indexLots.keys).union(cacheLots.keys).count + (bundled?.lotFileCount ?? 0)
    }

    /// Resolves a normalized compact lot key (`"64D199"`) to its NARA record, or `nil`.
    ///
    /// The `central-files` source (`BundledLotResolver`) already rejects `fileUnit`-level and
    /// `ancestryLacksRecordGroup` mis-resolutions (#321/#351/#352). The `volume-sources` `lots`
    /// map is **not** otherwise guarded, so a `fileUnit`-level entry there — the same
    /// wrong-collection class (60 D 627 → "Operation Mongoose") — is skipped here too (#352), or
    /// it would re-poison the collection-authority clusters this resolver feeds. The per-lot cache
    /// (step 3) carries no level, but the audited fileUnit lots have no cache files, so the
    /// `fileUnit` class cannot reach that fallback.
    public func resolve(lotNorm: String) -> ResolvedNAID? {
        if let hit = bundled?.resolve(rawLot: lotNorm) { return hit }
        if let hit = indexLots[lotNorm], hit.levelOfDescription != "fileUnit" { return hit }
        return cacheLots[lotNorm]
    }

    /// Decodes the `lots` map of a bundled `volume-sources-index.json`.
    private static func loadIndexLots(_ url: URL?) -> [String: ResolvedNAID] {
        struct Slice: Decodable { let lots: [String: ResolvedNAID]? }
        guard let url, let data = try? Data(contentsOf: url),
              let slice = try? JSONDecoder().decode(Slice.self, from: data) else { return [:] }
        return slice.lots ?? [:]
    }

    /// Loads per-lot cache files (`lots/<rg>_<norm>.json`), skipping confirmed misses.
    /// Files are read in sorted order so a (theoretical) duplicate norm resolves
    /// deterministically to the lexicographically-first record group's record.
    private static func loadCacheLots(_ directory: URL?) -> [String: ResolvedNAID] {
        struct LotResolution: Decodable { let naId: String; let title: String; let matchType: String? }
        guard let directory else { return [:] }
        let lotsDir = directory.appendingPathComponent("lots", isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: lotsDir, includingPropertiesForKeys: nil) else { return [:] }
        var map: [String: ResolvedNAID] = [:]
        for url in files.filter({ $0.pathExtension == "json" })
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let name = url.deletingPathExtension().lastPathComponent
            let parts = name.split(separator: "_", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let rg = String(parts[0])
            let norm = String(parts[1])
            guard map[norm] == nil,
                  let data = try? Data(contentsOf: url),
                  let res = try? JSONDecoder().decode(LotResolution.self, from: data),
                  !res.naId.isEmpty else { continue }
            map[norm] = ResolvedNAID(
                naId: res.naId,
                catalogURL: "https://catalog.archives.gov/id/" + res.naId,
                title: res.title, recordGroup: rg, matchType: res.matchType ?? "control")
        }
        return map
    }
}
