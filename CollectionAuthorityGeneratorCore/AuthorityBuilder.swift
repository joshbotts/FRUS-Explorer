// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SourceNoteKit
import VolumeSourcesIndexGeneratorCore

/// Merges `CollectionReference`s corpus-wide into two-level authority records under the
/// conservative-merge rules:
///
/// - the **same normalized lot key always merges** (`lot_file_norm` is a corpus-unique
///   identifier, so formatting variants and grain mismatches collapse safely);
/// - **textual merges require normalized equality of the leading segment *within the
///   same repository bucket*** — never across repositories, and an unattributed
///   reference (no repository) merges only with other unattributed references;
/// - a leading segment whose normalized form appears in two or more repository buckets
///   is reported as an **ambiguous cluster left unmerged** (the records stay separate).
///
/// Output is deterministic: records sort by `id`, children by class/name, aliases and
/// volume lists lexicographically; every vote tie breaks lexicographically.
public enum AuthorityBuilder {

    /// A leading segment that recurs under multiple repository buckets — deliberately
    /// left unmerged, and reported for the regeneration log.
    public struct AmbiguousCluster: Sendable, Equatable {
        /// The normalized leading segment.
        public let segment: String
        /// The distinct repository buckets it appears under (sorted; `"(unattributed)"`
        /// for the no-repository bucket).
        public let repositories: [String]
    }

    /// The clustering output: the artifact records plus the ambiguity report.
    public struct BuildResult: Sendable {
        /// Final records, sorted by `id`.
        public let collections: [AuthorityCollection]
        /// Ambiguous leading segments left unmerged.
        public let ambiguous: [AmbiguousCluster]
        /// References that carried no clusterable key (for the report).
        public let unclusterableCount: Int
    }

    /// Inclusion thresholds (documented size discipline — the schema-v2 trim lesson):
    /// a record or sub-series cited by front matter always ships; a doc-note-only
    /// textual record ships when it recurs across at least this many volumes.
    static let docNoteOnlyVolumeThreshold = 2

    /// Alias-list cap per record / sub-series.
    static let aliasCap = 12

    // MARK: - Aggregation state

    private struct ChildAgg {
        var decimalClass: String?
        /// Front-matter name votes (the curated outline names — preferred).
        var fmNameVotes: [String: Int] = [:]
        /// Doc-note name votes (fallback).
        var docNameVotes: [String: Int] = [:]
        var aliases: Set<String> = []
        var fmVolumes: Set<String> = []
        var docVolumes: Set<String> = []
    }

    private struct Agg {
        var lotFileNorm: String?
        var repoVotes: [String: Int] = [:]
        var rgVotes: [String: Int] = [:]
        /// Front-matter display-name votes (preferred canonical names).
        var fmNameVotes: [String: Int] = [:]
        /// Doc-note name votes (fallback canonical names).
        var docNameVotes: [String: Int] = [:]
        var aliases: Set<String> = []
        var fmVolumes: Set<String> = []
        var docVolumes: Set<String> = []
        var children: [String: ChildAgg] = [:]
    }

    /// The level-1 merge key for a reference, or `nil` when it carries no clusterable
    /// identity (`"lot:64D199"` / `"txt:<repoNorm>|<segmentNorm>"`).
    public static func level1Key(for ref: CollectionReference) -> String? {
        CollectionKeying.level1Key(lotFileNorm: ref.lotFileNorm,
                                   repository: ref.repository,
                                   leadingSegment: ref.leadingSegment)
    }

    // MARK: - Build

    /// Clusters `references` into the final authority records.
    ///
    /// - Parameters:
    ///   - references: All corpus references (any order — output is order-independent).
    ///   - resolver: Offline NAID resolution for lot-keyed records.
    public static func build(references: [CollectionReference],
                             resolver: OfflineNAIDResolver?) -> BuildResult {
        var aggs: [String: Agg] = [:]
        var unclusterable = 0

        for ref in references {
            guard let key = level1Key(for: ref) else {
                unclusterable += 1
                continue
            }
            var agg = aggs[key] ?? Agg()
            agg.lotFileNorm = agg.lotFileNorm ?? ref.lotFileNorm
            if let repo = ref.repository { agg.repoVotes[repo, default: 0] += 1 }
            if let rg = ref.recordGroup { agg.rgVotes[rg, default: 0] += 1 }
            switch ref.origin {
            case .frontMatter:
                agg.fmVolumes.insert(ref.volumeId)
                if let name = ref.displayName { agg.fmNameVotes[name, default: 0] += 1 }
            case .documentNote:
                agg.docVolumes.insert(ref.volumeId)
                if let name = ref.displayName ?? ref.leadingSegment
                    ?? ref.rawLot.map({ "Lot \($0)" }) {
                    agg.docNameVotes[name, default: 0] += 1
                }
            }
            if let raw = ref.rawLot { agg.aliases.insert(raw) }
            if let alias = ref.seriesAlias { agg.aliases.insert(alias) }
            if let segment = ref.leadingSegment { agg.aliases.insert(segment) }
            if let name = ref.displayName { agg.aliases.insert(name) }

            // Level 2.
            if let childKey = ref.subDecimalClass
                ?? ref.subSegment.map({ ReferenceBuilder.normalized($0) }) {
                var child = agg.children[childKey] ?? ChildAgg()
                child.decimalClass = child.decimalClass ?? ref.subDecimalClass
                let childName = ref.subDecimalClass ?? ref.subSegment ?? childKey
                if let sub = ref.subSegment { child.aliases.insert(sub) }
                switch ref.origin {
                case .frontMatter:
                    child.fmVolumes.insert(ref.volumeId)
                    child.fmNameVotes[childName, default: 0] += 1
                case .documentNote:
                    child.docVolumes.insert(ref.volumeId)
                    child.docNameVotes[childName, default: 0] += 1
                }
                agg.children[childKey] = child
            }
            aggs[key] = agg
        }

        // Ambiguity report: normalized leading segments recurring across repository
        // buckets (textual keys only) — kept unmerged by construction, logged here.
        var segmentBuckets: [String: Set<String>] = [:]
        for key in aggs.keys where key.hasPrefix("txt:") {
            let body = String(key.dropFirst("txt:".count))
            guard let bar = body.firstIndex(of: "|") else { continue }
            let repo = String(body[..<bar])
            let segment = String(body[body.index(after: bar)...])
            segmentBuckets[segment, default: []]
                .insert(repo.isEmpty ? "(unattributed)" : repo)
        }
        let ambiguous = segmentBuckets
            .filter { $0.value.count >= 2 }
            .map { AmbiguousCluster(segment: $0.key, repositories: $0.value.sorted()) }
            .sorted { $0.segment < $1.segment }

        // Materialize records under the inclusion thresholds.
        var collections: [AuthorityCollection] = []
        for (key, agg) in aggs {
            let isLot = agg.lotFileNorm != nil
            guard isLot || !agg.fmVolumes.isEmpty
                    || agg.docVolumes.count >= docNoteOnlyVolumeThreshold else { continue }

            let name = topVote(agg.fmNameVotes) ?? topVote(agg.docNameVotes)
                ?? agg.lotFileNorm.map { "Lot \($0)" } ?? key
            let repository = topVote(agg.repoVotes)
            let recordGroup = topVote(agg.rgVotes)
            let resolved = agg.lotFileNorm.flatMap { resolver?.resolve(lotNorm: $0) }

            var children: [AuthoritySubSeries] = []
            for (childKey, child) in agg.children {
                let isClass = child.decimalClass != nil
                // Class children ship only when front matter cites them (their citing
                // documents are recomputed locally from `decimal_class` — S5); textual
                // children ship when front-matter-cited or recurring across volumes.
                if isClass {
                    guard !child.fmVolumes.isEmpty else { continue }
                } else {
                    guard !child.fmVolumes.isEmpty
                            || child.docVolumes.count >= docNoteOnlyVolumeThreshold
                    else { continue }
                }
                let childName = topVote(child.fmNameVotes) ?? topVote(child.docNameVotes)
                    ?? childKey
                let volumes = isClass ? child.fmVolumes
                    : child.fmVolumes.union(child.docVolumes)
                children.append(AuthoritySubSeries(
                    name: childName,
                    decimalClass: child.decimalClass,
                    aliases: cappedAliases(child.aliases, excludingName: childName),
                    volumeIds: volumes.sorted()))
            }
            children.sort {
                ($0.decimalClass ?? $0.name, $0.name) < ($1.decimalClass ?? $1.name, $1.name)
            }

            collections.append(AuthorityCollection(
                id: key, name: name, repository: repository, recordGroup: recordGroup,
                lotFileNorm: agg.lotFileNorm,
                naId: resolved?.naId, catalogURL: resolved?.catalogURL,
                aliases: cappedAliases(agg.aliases, excludingName: name),
                volumeIds: agg.fmVolumes.union(agg.docVolumes).sorted(),
                children: children))
        }
        collections.sort { $0.id < $1.id }

        return BuildResult(collections: collections, ambiguous: ambiguous,
                           unclusterableCount: unclusterable)
    }

    /// The most-voted value, ties broken lexicographically (deterministic).
    static func topVote(_ votes: [String: Int]) -> String? {
        votes.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .first?.key
    }

    /// Sorted alias list with the canonical name (and its normal-form duplicates)
    /// removed, capped at `aliasCap` (kept deterministically: shortest-then-lexicographic,
    /// so compact citation forms survive the cap ahead of long descriptive texts).
    static func cappedAliases(_ aliases: Set<String>, excludingName name: String) -> [String] {
        let nameNorm = ReferenceBuilder.normalized(name)
        var seen: Set<String> = [nameNorm]
        var distinct: [String] = []
        for alias in aliases.sorted(by: { ($0.count, $0) < ($1.count, $1) }) {
            let norm = ReferenceBuilder.normalized(alias)
            guard !norm.isEmpty, !seen.contains(norm) else { continue }
            seen.insert(norm)
            distinct.append(alias)
        }
        return Array(distinct.prefix(aliasCap)).sorted()
    }
}
