// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import CollectionAuthorityGeneratorCore
import SourceNoteKit

// MARK: - AuthorityLookup

/// SPM-side twin of the app's `CollectionAuthorityIndex` lookup surface — the documented
/// 4-step alias-resolution contract over the bundled `collection-authority.json`, so the
/// export reports exactly the authority matches the app UI shows.
///
/// **Parity:** `record(forParsed:note:)` ≡ `CollectionAuthorityIndex.record(forParsed:note:)`
/// (`FRUSExplorer/SourceExplorer/CollectionAuthority.swift:251`), and
/// `record(repository:leadingSegment:)` ≡ the app's same-named lookup
/// (`CollectionAuthority.swift:230`), reproduced branch-for-branch over the same shared
/// `SourceNoteKit.CollectionKeying` normalizers, with the `byId`/`byAlias`/`bySegment` map
/// construction mirroring the app's decoder init (`CollectionAuthority.swift:182-212`).
/// The lookup order (doc contract at `CollectionAuthority.swift:137-157`):
///   1. the lot key (`"lot:" + lotFileNorm`) always wins;
///   2. the repository-scoped text key (`"txt:" + repoNorm + "|" + segmentNorm`);
///   3. the guarded unattributed bucket (`"txt:|" + segmentNorm`) — only for a non-generic
///      segment that exactly one text record carries;
///   4. an unambiguous alias (plural-folded `segmentNorm` matching exactly one record).
/// If either copy drifts, the fixture table in `AuthorityLookupParityTests` fails.
///
/// Version history:
///   1.0 — #335: initial implementation (CrossRefKit parity-mirror pattern)
public struct AuthorityLookup: Sendable {

    /// All authority records, as decoded from the bundled artifact.
    public let collections: [AuthorityCollection]
    /// Record index by dedup key (`"lot:64D199"`, `"txt:johnson library|…"`).
    private let byId: [String: Int]
    /// Record indices by normalized alias/name form (multi-valued: shared forms are ambiguous).
    private let byAlias: [String: [Int]]
    /// Text-record indices by key segment (the part after `"|"` in a `"txt:"` id).
    private let bySegment: [String: [Int]]

    /// Builds the lookup maps from decoded records — the app decoder-init's twin.
    public init(collections: [AuthorityCollection]) {
        self.collections = collections
        var ids: [String: Int] = [:]
        ids.reserveCapacity(collections.count)
        var aliasMap: [String: [Int]] = [:]
        var segmentMap: [String: [Int]] = [:]
        for (i, record) in collections.enumerated() {
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

    /// Loads and decodes the bundled `collection-authority.json`.
    public init(indexURL: URL) throws {
        let data = try Data(contentsOf: indexURL)
        let index = try JSONDecoder().decode(CollectionAuthorityIndex.self, from: data)
        self.init(collections: index.collections)
    }

    /// The record with the given dedup key, or `nil`.
    public func record(id: String) -> AuthorityCollection? {
        byId[id].map { collections[$0] }
    }

    /// Lookup-order step 1: the record for a canonical compact lot key (`"64D199"`).
    public func record(forLotNorm lotNorm: String) -> AuthorityCollection? {
        record(id: "lot:" + lotNorm)
    }

    /// Lookup-order steps 2–4 for a repository + leading citation segment.
    public func record(repository: String?, leadingSegment: String) -> AuthorityCollection? {
        let segNorm = CollectionKeying.segmentNorm(leadingSegment)
        guard !segNorm.isEmpty else { return nil }
        let repoNorm = CollectionKeying
            .normalized(CollectionKeying.canonicalRepository(repository) ?? "")
        if let hit = record(id: "txt:" + repoNorm + "|" + segNorm) { return hit }
        // Step 3, guarded: never bridge a generic segment, and only when the unattributed
        // record is the sole text record carrying the segment.
        if !repoNorm.isEmpty, !CollectionKeying.isGenericLead(segNorm),
           let hits = bySegment[segNorm], hits.count == 1,
           collections[hits[0]].id == "txt:|" + segNorm {
            return collections[hits[0]]
        }
        return uniqueRecord(forAliasNorm: segNorm)
    }

    /// The document-source-note entry point: the shared `CollectionKeying.identity` produces
    /// the level-1 key, then the documented lookup order applies. A `.presidentialLibrary` note
    /// is domain-guarded off `lot:` clusters (#351) — the app's `domainFiltered` twin.
    public func record(forParsed parsed: ParsedSourceNote, note: String) -> AuthorityCollection? {
        guard let identity = CollectionKeying.identity(of: parsed, note: note) else { return nil }
        let match: AuthorityCollection?
        if let lotNorm = identity.lotFileNorm, !lotNorm.isEmpty {
            match = record(forLotNorm: lotNorm)
        } else if let segment = identity.leadingSegment {
            match = record(repository: identity.repository, leadingSegment: segment)
        } else {
            match = nil
        }
        return Self.domainFiltered(match, for: parsed)
    }

    /// Cross-domain rejection (#351): a presidential-library note must never resolve to a State
    /// lot-file cluster (`id` `"lot:…"`). Mirrors `CollectionAuthorityIndex.domainFiltered`.
    public static func domainFiltered(_ match: AuthorityCollection?,
                                      for parsed: ParsedSourceNote) -> AuthorityCollection? {
        if case .presidentialLibrary = parsed, match?.id.hasPrefix("lot:") == true { return nil }
        return match
    }

    /// Lookup-order step 4: the single record whose merged alias forms contain `norm`, or
    /// `nil` when no — or more than one — record carries it.
    public func uniqueRecord(forAliasNorm norm: String) -> AuthorityCollection? {
        guard let hits = byAlias[norm], hits.count == 1 else { return nil }
        return collections[hits[0]]
    }
}
