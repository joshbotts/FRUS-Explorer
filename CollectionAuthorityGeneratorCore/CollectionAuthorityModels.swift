// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// The bundled `collection-authority.json` artifact (Source Explorer Phase 4): a
/// corpus-wide, two-level authority of the archival collections FRUS editors cite.
///
/// Each record carries **identity only** — canonical display name, the alias forms the
/// corpus actually writes (the grain-mismatch bridges), citing-volume lists, and the
/// offline-resolved NARA NAID. Per owner decision **S5**, the artifact never ships
/// document counts or per-document lists: the user's own index defines those, and the
/// app recomputes them locally. Per owner decision **S4**, depth is exactly two levels —
/// the collection and one sub-series level — not the full frus-sources segment tree.
public struct CollectionAuthorityIndex: Codable, Sendable, Equatable {
    /// Artifact schema version (bump on breaking shape changes).
    public var schemaVersion: Int
    /// Generation date stamp (`yyyy-MM-dd`).
    public var generated: String
    /// All authority records, sorted by `id` (deterministic output).
    public var collections: [AuthorityCollection]

    public init(schemaVersion: Int, generated: String, collections: [AuthorityCollection]) {
        self.schemaVersion = schemaVersion
        self.generated = generated
        self.collections = collections
    }
}

/// One level-1 authority record: an archival collection cited across the corpus.
///
/// Keyed by `lot_file_norm` when the collection is a lot file (`id = "lot:64D199"`),
/// else by normalized repository + leading citation segment
/// (`id = "txt:johnson library|national security file"`) — the same normal forms the
/// app writes at index time (`SourceNoteParser.lotFileNorm`, the Phase-3 delegate keys),
/// so runtime rows join the authority without variant fan-out.
public struct AuthorityCollection: Codable, Sendable, Equatable {
    /// Stable dedup key: `"lot:" + lotFileNorm` or `"txt:" + repositoryNorm + "|" + segmentNorm`.
    public var id: String
    /// Canonical display name (the most frequent raw form across the corpus).
    public var name: String
    /// Canonical repository keyword (`"Johnson Library"`, `"Department of State"`),
    /// or `nil` when the corpus never attributes the collection to a repository.
    public var repository: String?
    /// Record-group number (`"59"`) when one is known for the collection.
    public var recordGroup: String?
    /// Canonical compact lot key (`"64D199"`) for lot-keyed records; matches
    /// `document_sources.lot_file_norm` / `volume_sources.lot_file_norm`.
    public var lotFileNorm: String?
    /// Resolved NARA Catalog NAID (offline resolution only), when available.
    public var naId: String?
    /// NARA Catalog URL for `naId`.
    public var catalogURL: String?
    /// Distinct raw variant forms merged into this record (sorted; capped).
    public var aliases: [String]
    /// Volumes whose front matter or document source notes cite this collection (sorted).
    public var volumeIds: [String]
    /// Sub-series (level 2) under this collection, sorted by name.
    public var children: [AuthoritySubSeries]

    /// Explicit keys (required by the custom omit-empty Codable implementation).
    enum CodingKeys: String, CodingKey {
        case id, name, repository, recordGroup, lotFileNorm, naId, catalogURL,
             aliases, volumeIds, children
    }

    public init(id: String, name: String, repository: String? = nil, recordGroup: String? = nil,
                lotFileNorm: String? = nil, naId: String? = nil, catalogURL: String? = nil,
                aliases: [String] = [], volumeIds: [String] = [],
                children: [AuthoritySubSeries] = []) {
        self.id = id
        self.name = name
        self.repository = repository
        self.recordGroup = recordGroup
        self.lotFileNorm = lotFileNorm
        self.naId = naId
        self.catalogURL = catalogURL
        self.aliases = aliases
        self.volumeIds = volumeIds
        self.children = children
    }

    /// Decodes, tolerating omitted empty arrays (see `encode(to:)`).
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        repository = try c.decodeIfPresent(String.self, forKey: .repository)
        recordGroup = try c.decodeIfPresent(String.self, forKey: .recordGroup)
        lotFileNorm = try c.decodeIfPresent(String.self, forKey: .lotFileNorm)
        naId = try c.decodeIfPresent(String.self, forKey: .naId)
        catalogURL = try c.decodeIfPresent(String.self, forKey: .catalogURL)
        aliases = try c.decodeIfPresent([String].self, forKey: .aliases) ?? []
        volumeIds = try c.decodeIfPresent([String].self, forKey: .volumeIds) ?? []
        children = try c.decodeIfPresent([AuthoritySubSeries].self, forKey: .children) ?? []
    }

    /// Encodes, omitting empty arrays — thousands of records without aliases or
    /// children would otherwise ship `[]` keys (the schema-v2 size lesson).
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(repository, forKey: .repository)
        try c.encodeIfPresent(recordGroup, forKey: .recordGroup)
        try c.encodeIfPresent(lotFileNorm, forKey: .lotFileNorm)
        try c.encodeIfPresent(naId, forKey: .naId)
        try c.encodeIfPresent(catalogURL, forKey: .catalogURL)
        if !aliases.isEmpty { try c.encode(aliases, forKey: .aliases) }
        if !volumeIds.isEmpty { try c.encode(volumeIds, forKey: .volumeIds) }
        if !children.isEmpty { try c.encode(children, forKey: .children) }
    }
}

/// One level-2 authority record: a sub-series under a collection (the next leading
/// citation segment — `"Country File"` under `"National Security File"`, or a decimal /
/// subject-numeric class leaf under a Central Files collection).
public struct AuthoritySubSeries: Codable, Sendable, Equatable {
    /// Canonical display name (most frequent raw form).
    public var name: String
    /// The shared canonical class key (`SourceNoteParser.decimalClassKey` form) when the
    /// sub-series is a decimal / subject-numeric class leaf; matches
    /// `document_sources.decimal_class`.
    public var decimalClass: String?
    /// Distinct raw variant forms merged into this sub-series (sorted; capped).
    public var aliases: [String]
    /// Volumes citing this sub-series (sorted). For class-keyed children the list covers
    /// front-matter citations only — the citing *documents* are recomputed locally from
    /// the user's `decimal_class` index (S5).
    public var volumeIds: [String]

    /// Explicit keys (required by the custom omit-empty Codable implementation).
    enum CodingKeys: String, CodingKey {
        case name, decimalClass, aliases, volumeIds
    }

    public init(name: String, decimalClass: String? = nil,
                aliases: [String] = [], volumeIds: [String] = []) {
        self.name = name
        self.decimalClass = decimalClass
        self.aliases = aliases
        self.volumeIds = volumeIds
    }

    /// Decodes, tolerating omitted empty arrays (see `encode(to:)`).
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        decimalClass = try c.decodeIfPresent(String.self, forKey: .decimalClass)
        aliases = try c.decodeIfPresent([String].self, forKey: .aliases) ?? []
        volumeIds = try c.decodeIfPresent([String].self, forKey: .volumeIds) ?? []
    }

    /// Encodes, omitting empty arrays (size discipline — see `AuthorityCollection`).
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(decimalClass, forKey: .decimalClass)
        if !aliases.isEmpty { try c.encode(aliases, forKey: .aliases) }
        if !volumeIds.isEmpty { try c.encode(volumeIds, forKey: .volumeIds) }
    }
}

// MARK: - Intermediate reference model (not serialized)

/// One observed citation of an archival collection, extracted from a volume's front
/// matter or a document source note. The clustering input: `AuthorityBuilder` merges
/// references into `AuthorityCollection` records under the conservative-merge rules.
public struct CollectionReference: Sendable, Equatable {
    /// Where the reference was observed.
    public enum Origin: Sendable, Equatable {
        /// A volume front-matter Sources item (the Phase-3 `volume_sources` grain).
        case frontMatter
        /// A parsed document source note (the `document_sources` grain).
        case documentNote
    }

    /// The citing volume.
    public let volumeId: String
    /// Observation source.
    public let origin: Origin
    /// Canonical repository keyword, or `nil` when unattributed.
    public let repository: String?
    /// Record-group number when known.
    public let recordGroup: String?
    /// Canonical compact lot key when the collection is a lot file.
    public let lotFileNorm: String?
    /// Raw lot form as written (`"64 D 199"`, `"71–D 440"`) — an alias.
    public let rawLot: String?
    /// Raw level-1 leading segment (`"National Security File"`), or `nil` for
    /// lot-keyed references whose identity is the lot alone.
    public let leadingSegment: String?
    /// Raw level-2 segment (`"Country File"`), when one was observed.
    public let subSegment: String?
    /// Canonical class key when the level-2 entry is a decimal / subject-numeric class leaf.
    public let subDecimalClass: String?
    /// A named-series alias for a lot-keyed reference (`"PPS Files"` preceding
    /// `Lot 64 D 199` in the citation) — the grain-mismatch bridge.
    public let seriesAlias: String?
    /// Preferred display-name candidate for the level-1 record (front-matter rows carry
    /// the full descriptive item text here).
    public let displayName: String?

    public init(volumeId: String, origin: Origin, repository: String? = nil,
                recordGroup: String? = nil, lotFileNorm: String? = nil, rawLot: String? = nil,
                leadingSegment: String? = nil, subSegment: String? = nil,
                subDecimalClass: String? = nil, seriesAlias: String? = nil,
                displayName: String? = nil) {
        self.volumeId = volumeId
        self.origin = origin
        self.repository = repository
        self.recordGroup = recordGroup
        self.lotFileNorm = lotFileNorm
        self.rawLot = rawLot
        self.leadingSegment = leadingSegment
        self.subSegment = subSegment
        self.subDecimalClass = subDecimalClass
        self.seriesAlias = seriesAlias
        self.displayName = displayName
    }
}
