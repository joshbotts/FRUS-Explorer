// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ExternalCitationIndex

/// Where FRUS's editorial footnotes point **outside** the printed record — the bundled
/// `external-citation-index.json` (#784).
///
/// ## What one number here means
/// A *reference* is one archival unit named in one editorial footnote: the editor writing
/// *"Telegram 1345 from Moscow, March 5, is in … Lot 66–D95"* — a document the volume did not
/// print, and where to find it. Three claims that look alike and are not:
///
/// | index | claim |
/// |---|---|
/// | `collection-usage-index.json` | documents **drawn from** this archival unit |
/// | `provenance-flow-index.json` | references between two **printed** documents |
/// | this one | material the editors said exists **and did not print** |
///
/// ## The era claim #784 makes does not survive its own scope
/// The issue's headline is that footnote citations are "the only archival-flow signal that reaches
/// 1910–1945", citing 640 / 523 / 1,183 references for the 1910s / 1920s / 1930s. Measured on the
/// shipped artifact, at the scope the same issue mandates (lot files and library collections only),
/// those decades yield **0 / 0 / 2**.
///
/// The two figures are not in conflict; they count different things. #784's own verbatim examples
/// of pre-war reach — `(file No. 711.684/11)` and `(811.114 Guatemala/90)` — are **decimal file
/// numbers**, the unit the same issue defers as "later, guarded". Measured over the 159 volumes
/// whose coverage midpoint falls in 1910–1945: 4,877 footnotes name a decimal file, 67 name a lot,
/// and 120 name a library — of which the great majority are the head-nested *"Photostatic copy
/// obtained from the Franklin D. Roosevelt Library"* provenance statements the harvest excludes by
/// design. Lot files and presidential libraries are a post-1945 filing practice. **A surface built
/// on this index must not claim pre-war reach**; ``eraSpan`` reports what the data actually covers.
///
/// Version history:
///   1.0 — Session 2026-08-10: #784
struct ExternalCitationIndex: Decodable, Sendable {

    /// One archival unit's references, broken down by the volume whose footnotes made them.
    struct UnitRow: Decodable, Sendable {
        /// Index into ``targetIds``.
        let key: Int
        /// Volume indices, ascending.
        let volumes: [Int]
        /// Reference counts, parallel to ``volumes``.
        let counts: [Int]

        enum CodingKeys: String, CodingKey {
            case key = "k"
            case volumes = "v"
            case counts = "n"
        }

        /// References across every volume.
        var total: Int { counts.reduce(0, +) }
    }

    /// One (citing unit → cited unit) edge.
    struct Pair: Decodable, Sendable {
        /// Index into ``sourceIds`` — the citing document's *own* archival unit.
        let source: Int
        /// Index into ``targetIds`` — the unit its footnote points at.
        let target: Int
        /// References along this edge.
        let count: Int

        enum CodingKeys: String, CodingKey {
            case source = "f"
            case target = "t"
            case count = "n"
        }
    }

    /// What the scan saw. Every disclosure is computed from this, never written into a sentence a
    /// regenerated artifact would leave quietly wrong.
    struct Coverage: Decodable, Sendable {
        let volumesScanned: Int
        let volumesWithReferences: Int
        let documentsScanned: Int
        let footnotesScanned: Int
        let footnotesExcluded: Int
        let headNestedExcluded: Int
        let headNestedExcludedWithAnchor: Int
        let referencesFound: Int
        let referencesInherited: Int
        let absenceClaimsRefused: Int
        let lotReferences: Int
        let libraryReferences: Int
        let referencesJoined: Int
        let referencesWithBothEnds: Int
        let sameUnitReferences: Int
        let authorityCollectionCount: Int

        /// References a flow diagram can actually draw.
        var betweenUnitReferences: Int { referencesWithBothEnds - sameUnitReferences }

        /// Share of references whose unit came from an `Ibid.` rather than a phrase of its own,
        /// `0...1`. The caveat quotes this rather than a written-down number.
        var inheritedShare: Double {
            guard referencesFound > 0 else { return 0 }
            return Double(referencesInherited) / Double(referencesFound)
        }
    }

    /// Artifact schema version.
    let schemaVersion: Int
    /// Generation date stamp.
    let generated: String
    /// Volumes contributing at least one reference, sorted — the index space for ``targets``.
    let volumes: [String]
    /// Authority collection ids reached as a citation target, sorted.
    let targetIds: [String]
    /// Authority collection ids reached as a citing document's own unit, sorted.
    let sourceIds: [String]
    /// Per-target references by volume.
    let targets: [UnitRow]
    /// (source → target) edges, including same-unit ones.
    let pairs: [Pair]
    /// What the scan saw.
    let coverage: Coverage

    // MARK: - Lookups

    /// References **out of** a collection — where the editors, annotating material drawn from it,
    /// pointed the reader. Heaviest first, same-unit edges excluded.
    func outgoingReferences(fromCollectionId id: String) -> [(collectionId: String, count: Int)] {
        guard let index = sourceIds.firstIndex(of: id) else { return [] }
        return pairs
            .filter { $0.source == index && targetIds[$0.target] != id }
            .sorted { $0.count > $1.count }
            .map { (targetIds[$0.target], $0.count) }
    }

    /// References **into** a collection — which collections' documents were annotated by pointing
    /// at this one. Heaviest first, same-unit edges excluded.
    func incomingReferences(toCollectionId id: String) -> [(collectionId: String, count: Int)] {
        guard let index = targetIds.firstIndex(of: id) else { return [] }
        return pairs
            .filter { $0.target == index && sourceIds[$0.source] != id }
            .sorted { $0.count > $1.count }
            .map { (sourceIds[$0.source], $0.count) }
    }

    /// References from a collection to itself — the number the "between units only" disclosure has
    /// to quote.
    func sameUnitReferences(forCollectionId id: String) -> Int {
        guard let source = sourceIds.firstIndex(of: id),
              let target = targetIds.firstIndex(of: id) else { return 0 }
        return pairs.first { $0.source == source && $0.target == target }?.count ?? 0
    }

    /// Total references pointing at one collection, across every volume.
    func referenceCount(forCollectionId id: String) -> Int {
        guard let index = targetIds.firstIndex(of: id) else { return 0 }
        return targets.first { $0.key == index }?.total ?? 0
    }

    /// The volumes whose footnotes point at one collection, and how often.
    func volumeCounts(forCollectionId id: String) -> [(volumeId: String, count: Int)] {
        guard let index = targetIds.firstIndex(of: id),
              let row = targets.first(where: { $0.key == index }) else { return [] }
        return pairs(in: row)
    }

    /// Walks every (target, volume, count) the index carries, once.
    ///
    /// **For a caller that needs all of them**, which `volumeCounts(forCollectionId:)` cannot serve
    /// without a linear row scan per target — 995 targets against 995 rows. The era-banded pointer
    /// weight (#829c) needs exactly one pass, and this is it.
    ///
    /// - Parameter body: Called per reference group with the target id, the citing volume, and the
    ///   count.
    func forEachReference(_ body: (_ targetId: String, _ volumeId: String, _ count: Int) -> Void) {
        for row in targets {
            guard targetIds.indices.contains(row.key) else { continue }
            let id = targetIds[row.key]
            for pair in pairs(in: row) { body(id, pair.volumeId, pair.count) }
        }
    }

    /// One row's volumes zipped to its counts.
    ///
    /// **The single place the parallel arrays are zipped.** They arrive under one-letter wire names
    /// (`v`/`n`) and nothing in the format enforces that they are the same length, so a second
    /// implementation of this join is a second thing that can silently drift from the first —
    /// producing plausible counts against the wrong volumes. `ExternalCitationTests` pins it.
    ///
    /// - Parameter row: The stored row.
    /// - Returns: The volume ids and their counts, dropping any index the volume table lacks.
    private func pairs(in row: UnitRow) -> [(volumeId: String, count: Int)] {
        zip(row.volumes, row.counts).compactMap { volumeIndex, count in
            guard volumes.indices.contains(volumeIndex) else { return nil }
            return (volumes[volumeIndex], count)
        }
    }

    /// The corpus-wide heaviest (source → target) pairs, excluding same-unit edges.
    func heaviestPairs(limit: Int) -> [(sourceId: String, targetId: String, count: Int)] {
        pairs
            .filter { sourceIds[$0.source] != targetIds[$0.target] }
            .sorted { $0.count > $1.count }
            .prefix(limit)
            .map { (sourceIds[$0.source], targetIds[$0.target], $0.count) }
    }

    /// The earliest and latest coverage years the referencing volumes span, from the manifest.
    ///
    /// Exists so a surface can state the era reach it *has* instead of the one #784 predicted —
    /// see the type's note. Returns `nil` when no referencing volume carries a coverage range.
    func eraSpan(entriesById: [String: VolumeManifestEntry]) -> ClosedRange<Int>? {
        var earliest: Int?
        var latest: Int?
        for volumeId in volumes {
            guard let entry = entriesById[volumeId] else { continue }
            if let year = entry.dateRange.earliest.flatMap({ Int($0.prefix(4)) }) {
                earliest = min(earliest ?? year, year)
            }
            if let year = entry.dateRange.latest.flatMap({ Int($0.prefix(4)) }) {
                latest = max(latest ?? year, year)
            }
        }
        guard let earliest, let latest, earliest <= latest else { return nil }
        return earliest...latest
    }
}

// MARK: - ExternalCitationIndexStore

/// Loads and caches the bundled `external-citation-index.json`.
///
/// `shared` is `nil` only when the resource is missing or cannot be decoded; consumers must treat
/// that as "footnote citations are unavailable", never as "this collection is never cited".
///
/// Version history:
///   1.0 — Session 2026-08-10: #784
enum ExternalCitationIndexStore {

    /// The bundled index, or `nil` when unavailable.
    static let shared: ExternalCitationIndex? = load()

    private static func load() -> ExternalCitationIndex? {
        guard let url = Bundle.main.url(forResource: "external-citation-index",
                                        withExtension: "json") else {
            #if DEBUG
            print("[SourceExplorer] ExternalCitationIndexStore: external-citation-index.json not found.")
            #endif
            return nil
        }
        do {
            return try JSONDecoder().decode(ExternalCitationIndex.self,
                                            from: try Data(contentsOf: url))
        } catch {
            #if DEBUG
            print("[SourceExplorer] ExternalCitationIndexStore: decode failed — \(error)")
            #endif
            return nil
        }
    }
}
