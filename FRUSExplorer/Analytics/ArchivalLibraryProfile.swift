// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ArchivalLibraryCategoryCount

/// One provenance category's share of the user's own source notes.
struct ArchivalLibraryCategoryCount: Identifiable, Sendable, Equatable {
    /// The category.
    let category: SourceProvenanceCategory
    /// Documents in it.
    let documentCount: Int

    var id: String { category.rawValue }
}

// MARK: - ArchivalLibraryBandComposition

/// One era band's citation-form composition across the user's indexed volumes.
struct ArchivalLibraryBandComposition: Identifiable, Sendable, Equatable {
    /// The band.
    let band: ArchivalEraBand
    /// Indexed volumes in it.
    let volumeCount: Int
    /// Categories present, in ``SourceProvenanceCategory/ordered`` order, zeroes dropped.
    let categories: [ArchivalLibraryCategoryCount]

    var id: Int { band.index }

    /// Source notes in the band.
    var documentCount: Int { categories.reduce(0) { $0 + $1.documentCount } }
}

// MARK: - ArchivalLibraryCollection

/// One collection the user's own volumes draw on, with the record needed to open its
/// neighbours.
struct ArchivalLibraryCollection: Identifiable, Sendable, Equatable {
    /// The resolved authority record.
    let record: AuthorityCollectionRecord
    /// Documents in the user's index drawn from it.
    let documentCount: Int

    var id: String { record.id }
}

// MARK: - ArchivalLibraryProfile

/// The archival profile of the volumes **this user** has indexed — the Your Library mode.
///
/// Everything here is counted from the local `document_sources` table, never from the bundled
/// corpus-wide aggregates. That is the whole point of the mode: the other modes describe the
/// series, this one describes the library the reader actually has.
///
/// ## Two honest denominators
/// - ``noteCount`` counts *source notes*, one per document that carried one. It is smaller than
///   the indexed document count, because not every FRUS document has a source note, and the
///   copy must never call it a document total.
/// - ``volumeCount`` counts volumes that contributed at least one note — also smaller than the
///   number of volumes indexed, since 51 of the series' 552 volumes carry no source notes at
///   all.
///
/// ## What the collection ranking resolves, and what it cannot
/// Collections are resolved from the stored citation columns through the same authority the
/// Source Explorer uses, following its documented lookup order on the two keys the columns
/// carry: the canonical lot key, else repository plus leading segment. Two things follow.
/// First, central-file citations are absent by construction — their stored segment is a file
/// identifier, not a collection name — and ``centralFileNoteCount`` reports them separately
/// rather than letting them vanish. Second, a group that resolves to nothing is counted in
/// ``unresolvedCollectionNoteCount``, so the list never implies it covers everything.
///
/// Version history:
///   1.0 — Session 2026-08-09: #765 stage 1 (rider E)
struct ArchivalLibraryProfile: Sendable, Equatable {

    /// Collections listed in the ranking.
    static let collectionCap = 12

    /// Source notes across the user's index.
    let noteCount: Int
    /// Volumes contributing at least one source note.
    let volumeCount: Int
    /// Card 1: the whole library's composition, heaviest category first.
    let composition: [ArchivalLibraryCategoryCount]
    /// Card 2: composition per era band, earliest band first, empty bands dropped.
    let bands: [ArchivalLibraryBandComposition]
    /// Card 3: the most-cited resolvable collections, heaviest first.
    let collections: [ArchivalLibraryCollection]
    /// Notes citing the central files, which the collection ranking cannot resolve.
    let centralFileNoteCount: Int
    /// Notes in collection-shaped citations that resolved to no authority record.
    let unresolvedCollectionNoteCount: Int

    /// A profile with nothing in it — the honest state for an empty index.
    static let empty = ArchivalLibraryProfile(
        noteCount: 0, volumeCount: 0, composition: [], bands: [], collections: [],
        centralFileNoteCount: 0, unresolvedCollectionNoteCount: 0)

    /// Whether there is anything to draw.
    var isEmpty: Bool { noteCount == 0 }

    // MARK: - Building

    /// Folds the two grouped queries into the three cards.
    ///
    /// - Parameters:
    ///   - groups: `archivalLibraryGroups()` — volume × citation form × repository.
    ///   - collectionGroups: `archivalLibraryCollectionGroups()` — the collection-shaped rows.
    ///   - coverage: Coverage spans by volume id, for the band attribution. A volume absent
    ///     here still counts toward ``noteCount``; it simply reaches no band.
    ///   - authority: The bundled authority, or `nil` when it failed to load — in which case
    ///     the collection ranking is empty and every collection-shaped note is reported as
    ///     unresolved, which is exactly what happened.
    static func make(groups: [IndexingPipeline.ArchivalLibraryGroup],
                     collectionGroups: [IndexingPipeline.ArchivalLibraryCollectionGroup],
                     coverage: [String: ArchivalVolumeCoverage],
                     authority: CollectionAuthorityIndex?) -> ArchivalLibraryProfile {
        guard !groups.isEmpty else { return .empty }

        var totals: [SourceProvenanceCategory: Int] = [:]
        var perBand: [Int: [SourceProvenanceCategory: Int]] = [:]
        var bandVolumes: [Int: Set<String>] = [:]
        var volumes = Set<String>()
        var noteCount = 0
        for group in groups {
            let category = SourceProvenanceCategory.from(citationEra: group.citationEra,
                                                         repository: group.repository)
            totals[category, default: 0] += group.documentCount
            noteCount += group.documentCount
            volumes.insert(group.volumeId)
            guard let span = coverage[group.volumeId] else { continue }
            let band = ArchivalEraBand.band(forMidpointYear: span.midpointYear).index
            perBand[band, default: [:]][category, default: 0] += group.documentCount
            bandVolumes[band, default: []].insert(group.volumeId)
        }

        let composition = SourceProvenanceCategory.ordered
            .compactMap { category -> ArchivalLibraryCategoryCount? in
                guard let count = totals[category], count > 0 else { return nil }
                return ArchivalLibraryCategoryCount(category: category, documentCount: count)
            }
            .sorted { $0.documentCount > $1.documentCount }

        let bands = ArchivalEraBand.all.compactMap { band -> ArchivalLibraryBandComposition? in
            guard let counts = perBand[band.index], !counts.isEmpty else { return nil }
            // Ordered, not sorted by size: this card is read across the bands as one shape, and
            // a stack whose segments reorder band to band cannot be read that way.
            let categories = SourceProvenanceCategory.ordered
                .compactMap { category -> ArchivalLibraryCategoryCount? in
                    guard let count = counts[category], count > 0 else { return nil }
                    return ArchivalLibraryCategoryCount(category: category, documentCount: count)
                }
            return ArchivalLibraryBandComposition(
                band: band, volumeCount: bandVolumes[band.index]?.count ?? 0,
                categories: categories)
        }

        let ranked = rankCollections(collectionGroups, authority: authority)
        return ArchivalLibraryProfile(
            noteCount: noteCount,
            volumeCount: volumes.count,
            composition: composition,
            bands: bands,
            collections: ranked.collections,
            centralFileNoteCount: (totals[.centralDecimalFile] ?? 0)
                + (totals[.centralForeignPolicyFile] ?? 0),
            unresolvedCollectionNoteCount: ranked.unresolved)
    }

    /// Resolves each collection-shaped group against the authority and sums by record.
    ///
    /// The lookup mirrors `CollectionAuthorityIndex.record(forParsed:note:)` on the two keys the
    /// stored columns carry, including its cross-domain guard: a citation from a presidential
    /// library must never land on a State Department lot cluster. That guard is not defensive
    /// tidiness — it is the #351 defect, where a Carter Library "Presidential Files" note
    /// resolved to `lot:66D204` and offered the reader a confidently wrong archive.
    private static func rankCollections(
        _ groups: [IndexingPipeline.ArchivalLibraryCollectionGroup],
        authority: CollectionAuthorityIndex?
    ) -> (collections: [ArchivalLibraryCollection], unresolved: Int) {
        guard let authority else {
            return ([], groups.reduce(0) { $0 + $1.documentCount })
        }
        var counts: [String: Int] = [:]
        var records: [String: AuthorityCollectionRecord] = [:]
        var unresolved = 0
        for group in groups {
            guard let record = resolve(group, authority: authority) else {
                unresolved += group.documentCount
                continue
            }
            counts[record.id, default: 0] += group.documentCount
            records[record.id] = record
        }
        let collections = counts
            .sorted { a, b in
                if a.value != b.value { return a.value > b.value }
                return a.key < b.key
            }
            .prefix(collectionCap)
            .compactMap { id, count -> ArchivalLibraryCollection? in
                guard let record = records[id] else { return nil }
                return ArchivalLibraryCollection(record: record, documentCount: count)
            }
        return (collections, unresolved)
    }

    /// The authority record for one stored citation group.
    private static func resolve(_ group: IndexingPipeline.ArchivalLibraryCollectionGroup,
                                authority: CollectionAuthorityIndex)
        -> AuthorityCollectionRecord? {
        if let lot = group.lotFileNorm, !lot.isEmpty {
            return authority.record(forLotNorm: lot)
        }
        guard let series = group.seriesName,
              let segment = leadingSegment(of: series) else { return nil }
        let match = authority.record(repository: group.repository, leadingSegment: segment)
        if match?.id.hasPrefix("lot:") == true, let repository = group.repository,
           CollectionKeying.isLibraryRepositoryName(repository) {
            return nil
        }
        return match
    }

    /// The first comma-separated segment of a stored series name — the level-1 key the
    /// authority clusters on.
    private static func leadingSegment(of series: String) -> String? {
        let head = series.split(separator: ",", maxSplits: 1).first.map(String.init) ?? series
        let trimmed = head.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
