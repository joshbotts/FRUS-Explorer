// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - AuthorityCollectionRecord

/// One archival collection in the bundled cross-volume authority
/// (`collection-authority.json`, Source Explorer Phase 4): its canonical identity, the
/// alias forms the corpus writes, the citing-volume list, the offline-resolved NARA
/// NAID, and its two-level sub-series.
///
/// Per owner decision **S5** the artifact ships identity only — document counts are
/// always recomputed from the user's own index
/// (`IndexingPipeline.localCollectionStats`). Per owner decision **S4** depth is two
/// levels: the collection and one sub-series level.
///
/// Version history:
///   1.0 — Session 2026-07-03 (Source Explorer Phase 4 step 2): initial implementation
struct AuthorityCollectionRecord: Decodable, Sendable, Equatable, Identifiable {
    /// Stable dedup key: `"lot:" + lotFileNorm` or `"txt:" + repoNorm + "|" + segmentNorm`.
    let id: String
    /// Canonical display name (the most frequent raw form across the corpus).
    let name: String
    /// Canonical repository keyword (`"Johnson Library"`), or `nil` when unattributed.
    let repository: String?
    /// Record-group number (`"59"`) when known.
    let recordGroup: String?
    /// Canonical compact lot key (`"64D199"`) for lot-keyed records; matches
    /// `document_sources.lot_file_norm` / `volume_sources.lot_file_norm`.
    let lotFileNorm: String?
    /// Resolved NARA Catalog NAID (offline resolution only), when available.
    let naId: String?
    /// NARA Catalog URL for `naId`.
    let catalogURL: String?
    /// Distinct raw variant forms merged into this record (sorted; capped).
    let aliases: [String]
    /// Volumes whose front matter or document source notes cite this collection (sorted).
    let volumeIds: [String]
    /// Sub-series (level 2) under this collection, sorted by class key / name.
    let children: [AuthoritySubSeriesRecord]

    /// Explicit keys (the generator omits empty arrays for size — see `init(from:)`).
    private enum CodingKeys: String, CodingKey {
        case id, name, repository, recordGroup, lotFileNorm, naId, catalogURL,
             aliases, volumeIds, children
    }

    /// Decodes, tolerating the omitted empty arrays the generator writes.
    init(from decoder: any Decoder) throws {
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
        children = try c.decodeIfPresent([AuthoritySubSeriesRecord].self, forKey: .children) ?? []
    }

    /// Memberwise initializer (tests and previews).
    init(id: String, name: String, repository: String? = nil, recordGroup: String? = nil,
         lotFileNorm: String? = nil, naId: String? = nil, catalogURL: String? = nil,
         aliases: [String] = [], volumeIds: [String] = [],
         children: [AuthoritySubSeriesRecord] = []) {
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

    /// The NARA Catalog record's URL, parsed once for `Link`/`openURL`.
    var url: URL? { catalogURL.flatMap(URL.init(string:)) }
}

// MARK: - AuthoritySubSeriesRecord

/// One level-2 sub-series under an authority collection — the next leading citation
/// segment (`"Country File"` under `"National Security File"`) or a decimal /
/// subject-numeric class leaf under a Central Files collection.
struct AuthoritySubSeriesRecord: Decodable, Sendable, Equatable, Hashable {
    /// Canonical display name (most frequent raw form).
    let name: String
    /// The canonical class key (`SourceNoteParser.decimalClassKey` form) when the
    /// sub-series is a class leaf; matches `document_sources.decimal_class`.
    let decimalClass: String?
    /// Distinct raw variant forms merged into this sub-series (sorted; capped).
    let aliases: [String]
    /// Volumes citing this sub-series (sorted). For class-keyed children the list
    /// covers front-matter citations only — citing *documents* are local
    /// `decimal_class` queries (S5).
    let volumeIds: [String]

    /// Explicit keys (the generator omits empty arrays for size — see `init(from:)`).
    private enum CodingKeys: String, CodingKey {
        case name, decimalClass, aliases, volumeIds
    }

    /// Decodes, tolerating the omitted empty arrays the generator writes.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        decimalClass = try c.decodeIfPresent(String.self, forKey: .decimalClass)
        aliases = try c.decodeIfPresent([String].self, forKey: .aliases) ?? []
        volumeIds = try c.decodeIfPresent([String].self, forKey: .volumeIds) ?? []
    }

    /// Memberwise initializer (tests and previews).
    init(name: String, decimalClass: String? = nil, aliases: [String] = [],
         volumeIds: [String] = []) {
        self.name = name
        self.decimalClass = decimalClass
        self.aliases = aliases
        self.volumeIds = volumeIds
    }
}

// MARK: - CollectionAuthorityIndex

/// The decoded `collection-authority.json` with O(1) lookup maps.
///
/// ## Lookup order (documented contract)
///
/// Every surface resolves a citation to an authority record in the same order,
/// most-specific key first:
///
/// 1. **Lot key** — `"lot:" + lotFileNorm` (corpus-unique; always wins when present).
/// 2. **Repository-scoped text key** — `"txt:" + repoNorm + "|" + segmentNorm`
///    (the canonical repository keyword in `CollectionKeying.normalized` form and the
///    gated leading citation segment in the plural-folded
///    `CollectionKeying.segmentNorm` form).
/// 3. **Unattributed text key** — `"txt:|" + segmentNorm` (doc-note named series the
///    corpus never attributes to a repository). Guarded like step 4: the segment must
///    not be a generic lead (`CollectionKeying.isGenericLead` — a bare `"Subject
///    File"` never bridges to the unattributed grab-bag), and the unattributed record
///    must be the **sole** text record carrying the segment (an attributed citation
///    never silently resolves to the unattributed bucket while attributed records for
///    the same segment exist elsewhere).
/// 4. **Alias** — the plural-folded segment against every record's merged alias forms;
///    only an **unambiguous** hit (exactly one record) resolves, so a shared alias
///    can never route to the wrong collection.
///
/// All keys are produced by `SourceNoteKit.CollectionKeying` — the same functions the
/// generator clustered with, so lookups agree with the artifact by construction.
struct CollectionAuthorityIndex: Decodable, Sendable {

    /// Artifact schema version.
    let schemaVersion: Int
    /// Generation date stamp (`yyyy-MM-dd`).
    let generated: String
    /// All authority records, sorted by `id`.
    let collections: [AuthorityCollectionRecord]

    /// Record index by dedup key (`"lot:64D199"`, `"txt:johnson library|…"`).
    private let byId: [String: Int]
    /// Record indices by normalized alias / name form. Multi-valued: a form shared by
    /// several records is ambiguous and never resolves through the alias path.
    private let byAlias: [String: [Int]]
    /// Text-record indices by key segment (the part after `"|"` in a `"txt:"` id).
    /// Multi-valued: lookup step 3 bridges to the unattributed record only when it is
    /// the sole record carrying the segment.
    private let bySegment: [String: [Int]]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, generated, collections
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        generated = try c.decode(String.self, forKey: .generated)
        let records = try c.decode([AuthorityCollectionRecord].self, forKey: .collections)
        collections = records

        var ids: [String: Int] = [:]
        ids.reserveCapacity(records.count)
        var aliasMap: [String: [Int]] = [:]
        var segmentMap: [String: [Int]] = [:]
        for (i, record) in records.enumerated() {
            if ids[record.id] == nil { ids[record.id] = i }
            if record.id.hasPrefix("txt:"), let bar = record.id.firstIndex(of: "|") {
                let segment = String(record.id[record.id.index(after: bar)...])
                if segmentMap[segment]?.contains(i) != true {
                    segmentMap[segment, default: []].append(i)
                }
            }
            for form in [record.name] + record.aliases {
                let norm = CollectionKeying.segmentNorm(form)
                guard !norm.isEmpty else { continue }
                if aliasMap[norm]?.contains(i) != true {
                    aliasMap[norm, default: []].append(i)
                }
            }
        }
        byId = ids
        byAlias = aliasMap
        bySegment = segmentMap
    }

    // MARK: - Lookups

    /// The record with the given dedup key, or `nil`.
    func record(id: String) -> AuthorityCollectionRecord? {
        byId[id].map { collections[$0] }
    }

    /// The record for a canonical compact lot key (`"64D199"`), or `nil`.
    /// Lookup-order step 1.
    func record(forLotNorm lotNorm: String) -> AuthorityCollectionRecord? {
        record(id: "lot:" + lotNorm)
    }

    /// The record for a repository + leading citation segment, following the
    /// documented lookup order (steps 2–4): the repository-scoped text key, then the
    /// guarded unattributed bucket, then an unambiguous alias.
    func record(repository: String?, leadingSegment: String) -> AuthorityCollectionRecord? {
        let segNorm = CollectionKeying.segmentNorm(leadingSegment)
        guard !segNorm.isEmpty else { return nil }
        let repoNorm = CollectionKeying
            .normalized(CollectionKeying.canonicalRepository(repository) ?? "")
        if let hit = record(id: "txt:" + repoNorm + "|" + segNorm) { return hit }
        // Step 3, guarded (see the lookup-order contract): never bridge a generic
        // segment, and only when the unattributed record is the sole text record
        // carrying the segment — mirroring step 4's uniqueness rule.
        if !repoNorm.isEmpty, !CollectionKeying.isGenericLead(segNorm),
           let hits = bySegment[segNorm], hits.count == 1,
           collections[hits[0]].id == "txt:|" + segNorm {
            return collections[hits[0]]
        }
        return uniqueRecord(forAliasNorm: segNorm)
    }

    /// The record for a parsed document source note (the document Source Explorer
    /// entry point): the shared `CollectionKeying.identity` produces the same level-1
    /// key the generator clustered the note's siblings under, then the documented
    /// lookup order applies.
    func record(forParsed parsed: ParsedSourceNote, note: String) -> AuthorityCollectionRecord? {
        guard let identity = CollectionKeying.identity(of: parsed, note: note) else { return nil }
        let match: AuthorityCollectionRecord?
        if let lotNorm = identity.lotFileNorm, !lotNorm.isEmpty {
            match = record(forLotNorm: lotNorm)
        } else if let segment = identity.leadingSegment {
            match = record(repository: identity.repository, leadingSegment: segment)
        } else {
            match = nil
        }
        return CollectionAuthorityIndex.domainFiltered(match, for: parsed)
    }

    /// Rejects a cross-domain resolution (#351): a note parsed as a **presidential-library**
    /// citation must never resolve to a State Department **lot-file** cluster (an `id` of
    /// `"lot:…"`). The alias grammar can otherwise bridge a segment two collections happen to
    /// share — a Carter Library "Presidential Files" note matched `lot:66D204` in the #335 audit —
    /// producing a confidently-wrong archive link. A library note legitimately resolving to a
    /// text-keyed (`"txt:…"`) library cluster is untouched; only the lot cross-domain is blocked.
    static func domainFiltered(_ match: AuthorityCollectionRecord?,
                               for parsed: ParsedSourceNote) -> AuthorityCollectionRecord? {
        if case .presidentialLibrary = parsed, match?.id.hasPrefix("lot:") == true { return nil }
        return match
    }

    /// The record for a volume front-matter Sources row (the `VolumeSourcesView`
    /// entry point): the shared `CollectionKeying.frontMatterIdentity` derivation,
    /// then the documented lookup order.
    func record(forFrontMatterText text: String, repository: String?,
                lotFileNorm: String?, decimalClass: String?) -> AuthorityCollectionRecord? {
        guard let identity = CollectionKeying.frontMatterIdentity(
            text: text, repository: repository, lotFileNorm: lotFileNorm,
            decimalClass: decimalClass) else { return nil }
        if let lotNorm = identity.lotFileNorm, !lotNorm.isEmpty {
            return record(forLotNorm: lotNorm)
        }
        guard let segment = identity.leadingSegment else { return nil }
        return record(repository: identity.repository, leadingSegment: segment)
    }

    /// The single record whose merged alias forms contain `norm` (a
    /// `CollectionKeying.segmentNorm` form), or `nil` when no — or more than one —
    /// record carries the form (lookup-order step 4: a shared alias is ambiguous and
    /// never resolves).
    func uniqueRecord(forAliasNorm norm: String) -> AuthorityCollectionRecord? {
        guard let hits = byAlias[norm], hits.count == 1 else { return nil }
        return collections[hits[0]]
    }
}

// MARK: - CollectionAliasFallback convenience

extension IndexingPipeline.CollectionAliasFallback {
    /// Builds the neighbors matcher's display-time alias fallback from a bundled
    /// authority record: the record's canonical lot key plus its name and merged
    /// alias forms (see `IndexingPipeline.archivalNeighbors(forLotFile:…)` for the
    /// documented fallback order).
    init(record: AuthorityCollectionRecord) {
        self.init(lotFileNorm: record.lotFileNorm, names: [record.name] + record.aliases)
    }
}

// MARK: - CollectionAuthorityStore

/// Loads and caches the bundled `collection-authority.json`.
///
/// The index is decoded once, lazily, on first access; views warm it off the main
/// thread before their first per-row lookup (`Task.detached { _ = shared }` — the
/// `VolumeSourcesIndexStore` pattern). `shared` is `nil` only when the resource is
/// missing or cannot be decoded (logged in DEBUG).
///
/// Version history:
///   1.0 — Session 2026-07-03 (Source Explorer Phase 4 step 2): initial implementation
///   1.1 — Session 2026-07-04 (Phase 4 verification): alias/segment lookups use the
///          plural-folded `CollectionKeying.segmentNorm`
///   1.2 — Session 2026-07-04 (Phase 4 adversarial review): lookup step 3 (the
///          unattributed bucket) is guarded — generic segments never bridge, and the
///          unattributed record must be the sole text record carrying the segment
enum CollectionAuthorityStore {

    /// The bundled collection authority, or `nil` if unavailable. Loaded once.
    static let shared: CollectionAuthorityIndex? = load()

    private static func load() -> CollectionAuthorityIndex? {
        guard let url = Bundle.main.url(forResource: "collection-authority", withExtension: "json") else {
            #if DEBUG
            print("[SourceExplorer] CollectionAuthorityStore: collection-authority.json not found in bundle.")
            #endif
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(CollectionAuthorityIndex.self, from: data)
        } catch {
            #if DEBUG
            print("[SourceExplorer] CollectionAuthorityStore: failed to decode collection-authority.json — \(error)")
            #endif
            return nil
        }
    }
}
