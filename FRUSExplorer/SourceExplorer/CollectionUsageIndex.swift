// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CollectionUsageIndex

/// Document-grain usage counts for the archival units FRUS cites — the bundled
/// `collection-usage-index.json` (#763, archival analytics Phase 2).
///
/// `collection-authority.json` says *which volumes* cite a collection; this says *how many
/// documents* each of those volumes draws from it. The two answer different questions and the
/// difference is large: `lot:54D270` supplies 1,063 documents from 5 volumes, while
/// `lot:63D351` supplies 625 from 81. Ranking by volumes and ranking by documents produce
/// different lists, and both are correct.
///
/// ## What it does not carry
/// **No era rollups.** Every era view is a rollup of these per-volume counts against
/// `manifest.json`'s coverage dates, which ``CollectionRelations/coverageEras`` already computes
/// for the collection timeline (#762). One era axis, one answer.
///
/// ## Reading a count honestly
/// A collection absent from ``collectionIds`` has **no documents attributed to it**, which is not
/// the same as being unused: 2,595 of the authority's 4,423 records are named in a volume's front
/// matter and never resolved from a document source note. ``documentCount(forCollectionId:)``
/// returns zero for those, and a surface that shows the number should say which question it
/// answered.
///
/// Version history:
///   1.0 — Session 2026-08-08: #763
struct CollectionUsageIndex: Decodable, Sendable {

    /// One key's per-volume document counts. Wire names are one letter — the artifact carries
    /// 12,273 rows and the field names would otherwise be 38% of the file.
    struct UsageRow: Decodable, Sendable {
        /// Index into the owning vocabulary.
        let key: Int
        /// Volume indices, ascending.
        let volumes: [Int]
        /// Document counts, parallel to ``volumes``.
        let counts: [Int]

        enum CodingKeys: String, CodingKey {
            case key = "k"
            case volumes = "v"
            case counts = "n"
        }

        /// Decodes, refusing a row whose parallel arrays have drifted apart — a short read would
        /// attribute one collection's counts to another collection's volumes.
        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            key = try c.decode(Int.self, forKey: .key)
            volumes = try c.decode([Int].self, forKey: .volumes)
            counts = try c.decode([Int].self, forKey: .counts)
            guard volumes.count == counts.count else {
                throw DecodingError.dataCorruptedError(
                    forKey: .counts, in: c,
                    debugDescription: "row \(key): \(volumes.count) volumes, \(counts.count) counts")
            }
        }
    }

    /// What the generating scan saw — the numbers a coverage disclosure is built from.
    struct Coverage: Decodable, Sendable {
        /// Volumes scanned.
        let volumesScanned: Int
        /// Volumes carrying at least one document source note.
        let volumesWithNotes: Int
        /// Document source notes scanned.
        let noteCount: Int
        /// Notes that resolved to an authority collection.
        let notesInACollection: Int
        /// Notes that yielded a central-file class key.
        let notesWithAClassKey: Int
        /// Records in the authority the scan was joined against.
        let authorityCollectionCount: Int
        /// Authority records at least one document resolved to.
        let authorityCollectionsReached: Int
    }

    /// Artifact schema version.
    let schemaVersion: Int
    /// Generation date stamp.
    let generated: String
    /// Scanned volume ids, sorted — the index space for every row.
    let volumes: [String]
    /// Source notes per volume, parallel to ``volumes``.
    let volumeNoteCounts: [Int]
    /// Authority collection ids reached by at least one document, sorted.
    let collectionIds: [String]
    /// Central-file class keys reached by at least one document, sorted. Holds **both** the
    /// 1910–1949 decimal classes and the 1963–1973 subject-numeric designators; branch with
    /// `CollectionKeying.isSubjectNumericClass`.
    let classKeys: [String]
    /// Provenance categories in display order.
    let categories: [String]
    /// Per-collection usage.
    let collections: [UsageRow]
    /// Per-class usage.
    let classes: [UsageRow]
    /// Per-category usage.
    let volumeCategories: [UsageRow]
    /// What the scan saw.
    let coverage: Coverage

    // MARK: - Lookups

    /// Row index by collection id, built once on decode.
    private var collectionRows: [String: Int] = [:]
    /// Row index by class key.
    private var classRows: [String: Int] = [:]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, generated, volumes, volumeNoteCounts, collectionIds, classKeys,
             categories, collections, classes, volumeCategories, coverage
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        generated = try c.decode(String.self, forKey: .generated)
        volumes = try c.decode([String].self, forKey: .volumes)
        volumeNoteCounts = try c.decode([Int].self, forKey: .volumeNoteCounts)
        collectionIds = try c.decode([String].self, forKey: .collectionIds)
        classKeys = try c.decode([String].self, forKey: .classKeys)
        categories = try c.decode([String].self, forKey: .categories)
        collections = try c.decode([UsageRow].self, forKey: .collections)
        classes = try c.decode([UsageRow].self, forKey: .classes)
        volumeCategories = try c.decode([UsageRow].self, forKey: .volumeCategories)
        coverage = try c.decode(Coverage.self, forKey: .coverage)

        for (position, row) in collections.enumerated() where collectionIds.indices.contains(row.key) {
            collectionRows[collectionIds[row.key]] = position
        }
        for (position, row) in classes.enumerated() where classKeys.indices.contains(row.key) {
            classRows[classKeys[row.key]] = position
        }
    }

    /// Documents attributed to a collection across the whole series. Zero when nothing resolved.
    func documentCount(forCollectionId id: String) -> Int {
        guard let position = collectionRows[id] else { return 0 }
        return collections[position].counts.reduce(0, +)
    }

    /// Documents a collection supplies to each volume, keyed by volume id. Empty when nothing
    /// resolved to it.
    func documentsByVolume(forCollectionId id: String) -> [String: Int] {
        guard let position = collectionRows[id] else { return [:] }
        return pairs(collections[position])
    }

    /// Documents attributed to a central-file class across the whole series.
    func documentCount(forClassKey key: String) -> Int {
        guard let position = classRows[key] else { return 0 }
        return classes[position].counts.reduce(0, +)
    }

    /// Documents a class supplies to each volume, keyed by volume id.
    func documentsByVolume(forClassKey key: String) -> [String: Int] {
        guard let position = classRows[key] else { return [:] }
        return pairs(classes[position])
    }

    /// Source notes scanned in a volume — the denominator for any per-volume share. `nil` when
    /// the volume was not scanned, which is different from a scanned volume holding none.
    func noteCount(forVolumeId id: String) -> Int? {
        guard let index = volumes.firstIndex(of: id) else { return nil }
        return volumeNoteCounts[index]
    }

    /// Volumes drawn from one provenance category, with per-volume document counts — the
    /// FORWARD companion of ``categoryCounts(forVolumeId:)``, added for the Browse
    /// Archives axis (#1051 B-5). Empty for an unknown slug.
    ///
    /// - Parameter slug: A category slug from ``categories``.
    /// - Returns: `volumeId → documents`, for every volume the category reaches.
    func documentsByVolume(forCategory slug: String) -> [String: Int] {
        guard let key = categories.firstIndex(of: slug),
              let row = volumeCategories.first(where: { $0.key == key }) else { return [:] }
        return pairs(row)
    }

    /// Documents in each provenance category for one volume, keyed by category slug.
    func categoryCounts(forVolumeId id: String) -> [String: Int] {
        guard let volumeIndex = volumes.firstIndex(of: id) else { return [:] }
        var result: [String: Int] = [:]
        for row in volumeCategories where categories.indices.contains(row.key) {
            if let position = row.volumes.firstIndex(of: volumeIndex) {
                result[categories[row.key]] = row.counts[position]
            }
        }
        return result
    }

    /// Resolves a row's parallel arrays into `volumeId: count`.
    private func pairs(_ row: UsageRow) -> [String: Int] {
        var result: [String: Int] = [:]
        result.reserveCapacity(row.volumes.count)
        for (position, volumeIndex) in row.volumes.enumerated()
        where volumes.indices.contains(volumeIndex) {
            result[volumes[volumeIndex]] = row.counts[position]
        }
        return result
    }
}

// MARK: - CollectionUsageIndexStore

/// Loads and caches the bundled `collection-usage-index.json`.
///
/// Lazy and load-once, like every sibling index store. `shared` is `nil` only when the resource
/// is missing or cannot be decoded — every consumer must treat that as "document weights are
/// unavailable" and fall back to the volume-grain counts the authority already carries, never as
/// "this collection supplies no documents".
///
/// Version history:
///   1.0 — Session 2026-08-08: #763
enum CollectionUsageIndexStore {

    /// The bundled usage index, or `nil` when unavailable.
    static let shared: CollectionUsageIndex? = load()

    private static func load() -> CollectionUsageIndex? {
        guard let url = Bundle.main.url(forResource: "collection-usage-index",
                                        withExtension: "json") else {
            #if DEBUG
            print("[SourceExplorer] CollectionUsageIndexStore: collection-usage-index.json not found.")
            #endif
            return nil
        }
        do {
            return try JSONDecoder().decode(CollectionUsageIndex.self,
                                            from: try Data(contentsOf: url))
        } catch {
            #if DEBUG
            print("[SourceExplorer] CollectionUsageIndexStore: decode failed — \(error)")
            #endif
            return nil
        }
    }
}
