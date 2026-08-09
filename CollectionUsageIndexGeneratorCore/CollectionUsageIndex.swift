// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CollectionUsageIndex

/// Document-grain usage counts for the archival units FRUS cites (#763, archival analytics
/// Phase 2): how many *documents* each authority collection, each central-file class, and each
/// provenance category supplies to each volume.
///
/// ## Why this exists as its own artifact
/// `collection-authority.json` is identity — canonical name, aliases, citing volumes — and a
/// recorded decision keeps document counts out of it (owner decision S5). This is usage, and it
/// is regenerated from a different scan, so it ships beside the authority the way
/// `lot-claimants-index.json` ships beside `central-files-index.json`.
///
/// ## What it deliberately does not carry
/// **No era or decade rollups.** Every era view the design asks for is a rollup of these
/// per-volume counts against `manifest.json`'s coverage dates, and the app already computes that
/// join (`CollectionRelations.coverageEras`, #762). Shipping a second era axis here would cost
/// ~157 KB and create a surface that can silently disagree with the first one.
///
/// ## Encoding
/// Vocabularies are interned to `Int` indices and the payload is a parallel-array
/// ``UsageRow`` per key, which measured 424 KB against 530 KB for an object-per-pair encoding
/// and needs no hand-written decoder. `volumes` and `counts` are the same length by construction;
/// a decoded row that violates that is refused rather than read (see ``UsageRow/init(from:)``).
///
/// Version history:
///   1.0 — Session 2026-08-08: #763
public struct CollectionUsageIndex: Codable, Sendable, Equatable {

    /// One key's per-volume document counts.
    ///
    /// `volumes` holds indices into ``CollectionUsageIndex/volumes``, ascending; `counts` holds
    /// the document count at the same position. Both are non-empty — a key with no documents is
    /// omitted from the artifact rather than stored as an empty row.
    public struct UsageRow: Codable, Sendable, Equatable {
        /// Index into the owning vocabulary (`collectionIds`, `classKeys`, or `categories`).
        public let key: Int
        /// Volume indices, ascending.
        public let volumes: [Int]
        /// Document counts, parallel to ``volumes``.
        public let counts: [Int]

        /// One-letter wire names. The artifact carries 12,273 rows, and spelling the three field
        /// names out costs 307 KB — 38% of the file — for a machine-read index nobody opens by
        /// eye. The Swift properties stay spelled out; only the bytes are short.
        enum CodingKeys: String, CodingKey {
            case key = "k"
            case volumes = "v"
            case counts = "n"
        }

        /// The row's total documents across every volume.
        public var total: Int { counts.reduce(0, +) }

        /// Creates a usage row.
        public init(key: Int, volumes: [Int], counts: [Int]) {
            self.key = key
            self.volumes = volumes
            self.counts = counts
        }

        /// Decodes, refusing a row whose parallel arrays have drifted apart.
        ///
        /// The invariant is the whole basis of this encoding, and a silently-truncated read would
        /// attribute one collection's counts to another collection's volumes — a wrong number
        /// rendered as confidently as a right one.
        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            key = try c.decode(Int.self, forKey: .key)
            volumes = try c.decode([Int].self, forKey: .volumes)
            counts = try c.decode([Int].self, forKey: .counts)
            guard volumes.count == counts.count else {
                throw DecodingError.dataCorruptedError(
                    forKey: .counts, in: c,
                    debugDescription: "row \(key) has \(volumes.count) volumes and \(counts.count) counts")
            }
        }
    }

    /// What the scan saw — the numbers every coverage disclosure in the UI is built from.
    public struct Coverage: Codable, Sendable, Equatable {
        /// Volumes scanned (the manifest's shippable set, intersected with the local corpus).
        public let volumesScanned: Int
        /// Volumes with at least one document source note.
        public let volumesWithNotes: Int
        /// Document source notes scanned.
        public let noteCount: Int
        /// Notes that resolved to an authority collection.
        public let notesInACollection: Int
        /// Notes that yielded a central-file class key.
        public let notesWithAClassKey: Int
        /// Records in the authority the scan was joined against.
        public let authorityCollectionCount: Int
        /// Authority records that at least one document note resolved to. The gap is the point:
        /// a collection can be named in a volume's front matter and never carry a document.
        public let authorityCollectionsReached: Int

        /// Creates a coverage summary.
        public init(volumesScanned: Int, volumesWithNotes: Int, noteCount: Int,
                    notesInACollection: Int, notesWithAClassKey: Int,
                    authorityCollectionCount: Int, authorityCollectionsReached: Int) {
            self.volumesScanned = volumesScanned
            self.volumesWithNotes = volumesWithNotes
            self.noteCount = noteCount
            self.notesInACollection = notesInACollection
            self.notesWithAClassKey = notesWithAClassKey
            self.authorityCollectionCount = authorityCollectionCount
            self.authorityCollectionsReached = authorityCollectionsReached
        }
    }

    /// Artifact schema version.
    public let schemaVersion: Int
    /// Generation date stamp (`yyyy-MM-dd`).
    public let generated: String
    /// Every scanned volume id, sorted. The index space for every ``UsageRow``.
    public let volumes: [String]
    /// Document source notes per volume, parallel to ``volumes`` — the denominator a share needs.
    /// Zero is a real value: 51 shippable volumes carry no document source note at all.
    public let volumeNoteCounts: [Int]
    /// Authority collection ids reached by at least one document, sorted.
    public let collectionIds: [String]
    /// Central-file class keys reached by at least one document, sorted. **Two filing systems
    /// share this vocabulary** — the 1910–1949 decimal classes (`763.72`) and the 1963–1973
    /// subject-numeric designators (`POL 27 VIET S`) — because the corpus cites both through the
    /// same grammar. A consumer that labels or groups them must branch on the shape.
    public let classKeys: [String]
    /// Provenance categories, in `ProvenanceCategory.orderedCases` order.
    public let categories: [String]
    /// Per-collection usage, sorted by `key`.
    public let collections: [UsageRow]
    /// Per-class usage, sorted by `key`.
    public let classes: [UsageRow]
    /// Per-category usage, sorted by `key`.
    public let volumeCategories: [UsageRow]
    /// What the scan saw.
    public let coverage: Coverage

    /// Creates a usage index.
    public init(schemaVersion: Int, generated: String, volumes: [String],
                volumeNoteCounts: [Int], collectionIds: [String], classKeys: [String],
                categories: [String], collections: [UsageRow], classes: [UsageRow],
                volumeCategories: [UsageRow], coverage: Coverage) {
        self.schemaVersion = schemaVersion
        self.generated = generated
        self.volumes = volumes
        self.volumeNoteCounts = volumeNoteCounts
        self.collectionIds = collectionIds
        self.classKeys = classKeys
        self.categories = categories
        self.collections = collections
        self.classes = classes
        self.volumeCategories = volumeCategories
        self.coverage = coverage
    }
}
