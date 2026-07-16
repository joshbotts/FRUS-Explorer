// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

/// Resolves a `WordCloudScope` into the concrete set of document keys (and a
/// human-readable title) that `WordFrequencyService` needs.
///
/// Resolution runs on the main actor because four of the scopes
/// (`.collection`, `.userTag`, `.savedSearch`, `.customScope`) read SwiftData
/// and/or re-run a search. The FTS-backed scopes (`.document`, `.volume`,
/// `.subseries`) read the index; `.corpus` is left for the service to enumerate so
/// its (potentially enormous) key list is never materialised on the main actor.
///
/// Version history:
///   1.0 — Word Cloud feature: initial implementation
///   1.1 — #258 Phase 5: `.customScope` — per-member-volume key enumeration (the
///          indexed grain by construction: un-indexed members contribute no rows,
///          so the cloud's existing "no indexed text in this scope yet" empty state
///          is the honest `.noIndexedMembers` rendering, never an inversion);
///          a dangling id keeps the generic-title + empty-keys pattern
@MainActor
struct WordCloudScopeResolver {

    /// The resolved scope: its title and either an explicit key set or the corpus flag.
    struct Resolved: Sendable {
        /// The originating scope.
        let scope: WordCloudScope
        /// Human-readable title for the cloud (volume/collection/tag/search name, etc.).
        let title: String
        /// The documents whose text feeds the cloud. Empty when `isCorpus` is true.
        let keys: [WordCloudDocumentKey]
        /// When true, the caller should use `WordFrequencyService.corpusTopTerms`.
        let isCorpus: Bool
    }

    /// Manifest store for volume/subseries titles and membership.
    let manifestStore: ManifestStore
    /// Indexing pipeline for FTS-backed document enumeration.
    let pipeline: IndexingPipeline?
    /// Search service used to re-run saved searches.
    let searchService: SearchService?
    /// SwiftData context for collections, tags, and saved searches.
    let modelContext: ModelContext

    /// Resolves `scope` to its title and document keys.
    /// - Parameter scope: The scope to resolve.
    /// - Returns: The resolved title + keys (or corpus flag).
    func resolve(_ scope: WordCloudScope) async throws -> Resolved {
        switch scope {
        case let .document(volumeId, documentId):
            let title = manifestStore.entry(forVolumeId: volumeId)?.title ?? volumeId
            return Resolved(
                scope: scope, title: title,
                keys: [WordCloudDocumentKey(volumeId: volumeId, documentId: documentId)],
                isCorpus: false
            )

        case let .volume(volumeId):
            let title = manifestStore.entry(forVolumeId: volumeId)?.title ?? volumeId
            return Resolved(scope: scope, title: title,
                            keys: try await keys(forVolume: volumeId), isCorpus: false)

        case let .subseries(subseriesId):
            let volumeIds = manifestStore.bundledEntries
                .filter { $0.subseries == subseriesId }
                .map(\.volumeId)
            var keys: [WordCloudDocumentKey] = []
            for volumeId in volumeIds {
                keys.append(contentsOf: try await self.keys(forVolume: volumeId))
            }
            return Resolved(scope: scope, title: subseriesId, keys: keys, isCorpus: false)

        case .corpus:
            return Resolved(
                scope: scope,
                title: String(localized: "wordcloud.scope.corpus", defaultValue: "Entire corpus"),
                keys: [], isCorpus: true
            )

        case let .collection(id):
            var descriptor = FetchDescriptor<Collection>(predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 1
            let collection = try modelContext.fetch(descriptor).first
            let title = collection?.name ?? String(localized: "wordcloud.scope.collection",
                                                   defaultValue: "Collection")
            let keys = (collection?.documentEntries ?? []).map {
                WordCloudDocumentKey(volumeId: $0.volumeId, documentId: $0.documentId)
            }
            return Resolved(scope: scope, title: title, keys: keys, isCorpus: false)

        case let .userTag(id):
            var descriptor = FetchDescriptor<UserTag>(predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 1
            let tag = try modelContext.fetch(descriptor).first
            let title = tag?.name ?? String(localized: "wordcloud.scope.tag", defaultValue: "Tag")
            let keys = (try await pipeline?.documentKeys(forUserTagId: id.uuidString)) ?? []
            return Resolved(scope: scope, title: title, keys: keys, isCorpus: false)

        case let .savedSearch(id):
            var descriptor = FetchDescriptor<SavedSearch>(predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 1
            let saved = try modelContext.fetch(descriptor).first
            let title = saved?.name ?? String(localized: "wordcloud.scope.search",
                                              defaultValue: "Saved search")
            var keys: [WordCloudDocumentKey] = []
            if let saved, let searchService {
                let results = try await searchService.search(
                    parameters: saved.searchParameters,
                    limit: SearchViewModel.searchHardLimit
                )
                keys = results.map { WordCloudDocumentKey(volumeId: $0.volumeId, documentId: $0.documentId) }
            }
            return Resolved(scope: scope, title: title, keys: keys, isCorpus: false)

        case let .customScope(id):
            // #258 Phase 5. Dereference the record (never copy the member list into the
            // scope value — sketch §8-Q3); a dangling id (deleted on another device)
            // yields the generic title + empty keys, matching `.collection`'s pattern —
            // an explicitly empty cloud, never a fallback to `.corpus`. Members are raw
            // manifest ids, so key enumeration per volume IS the indexed-grain
            // intersection: `keys(forVolume:)` returns nothing for un-indexed volumes.
            var descriptor = FetchDescriptor<CustomVolumeScope>(
                predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 1
            let record = try modelContext.fetch(descriptor).first
            let title = record?.name ?? String(localized: "wordcloud.scope.customScope",
                                               defaultValue: "Volume Scope")
            var keys: [WordCloudDocumentKey] = []
            for volumeId in record?.volumeIds ?? [] {
                keys.append(contentsOf: try await self.keys(forVolume: volumeId))
            }
            return Resolved(scope: scope, title: title, keys: keys, isCorpus: false)

        case let .dateRange(startISO, endISO):
            let range = DateRange(earliest: startISO, latest: endISO)
            let rows = (try await pipeline?.documentsInDateRange(
                range, scopeVolumeIds: nil, ascending: true, limit: Self.dateRangeKeyLimit)) ?? []
            let keys = rows.map { WordCloudDocumentKey(volumeId: $0.volumeId, documentId: $0.documentId) }
            return Resolved(
                scope: scope,
                title: WordCloudScope.dateRangeTitle(startISO: startISO, endISO: endISO),
                keys: keys, isCorpus: false
            )
        }
    }

    /// Hard cap on documents pulled for a date-range cloud, mirroring the Chronology
    /// browser's load limit so a very wide range stays responsive.
    private static let dateRangeKeyLimit = 5000

    /// Document keys for one volume, or an empty array when the volume isn't indexed.
    private func keys(forVolume volumeId: String) async throws -> [WordCloudDocumentKey] {
        let entries = (try await pipeline?.documents(forVolume: volumeId)) ?? []
        return entries.map { WordCloudDocumentKey(volumeId: $0.volumeId, documentId: $0.documentId) }
    }
}
