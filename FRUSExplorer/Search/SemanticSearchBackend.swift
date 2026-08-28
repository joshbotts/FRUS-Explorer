// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - SemanticSearchBackend

/// The Meaning search mode's engine face (V-5 hybrid page): one definition, called by BOTH
/// platforms' view models, of how semantic hits become the rows the existing search machinery
/// renders — so the two hand-maintained search surfaces cannot drift on synthesis rules.
///
/// ## What rides the existing machinery, and on what terms
///
/// Indexed hits become full `SearchResult`s: `bm25Score` carries the NEGATED cosine so every
/// lower-is-better consumer (the date sorts' tie-break, the undated tail) works unchanged, and
/// `semanticScore` carries the cosine itself for display. The snippet is `ProseSnippet` — the
/// evaluation report's prose-first rule, now shared — because with no keywords there is nothing
/// to bold, and the assessment's snippet break is answered with prose rather than a bare header.
///
/// ## Filters intersect; they do not pretend
///
/// When the parameters carry SQL-expressible filters, the UNCAPPED filter key set is fetched and
/// indexed hits are intersected — the assessment's `materializeMatchSet` wiring. Beyond-library
/// hits have no rows to filter: volume scope IS applied (the volume id is known), everything
/// else cannot be, and the disclosure says so rather than quietly showing unfiltered rows under
/// a filtered search.
///
/// ## What it inherits from the searcher
///
/// Corpus-wide reach, the drop-and-queue shard rule with its disclosure counts, and the edition-
/// twin fold — all argued at `SemanticQuerySearcher`.
@MainActor
struct SemanticSearchBackend {

    let searcher: SemanticQuerySearcher
    let searchService: SearchService
    let manifestStore: ManifestStore
    /// Read live at run time — the indexed set grows as volumes index.
    let indexedVolumeIds: () -> Set<String>

    /// Ranked hits requested from the funnel. 100, not the pool's 800: a ten-page semantic
    /// list is already past what a reader triages, and every row costs a keyed lookup.
    static let hitLimit = 100

    /// A hit in a volume this device has not indexed — rendered by the #262 rule (manifest
    /// title, no invented metadata, a download affordance where the manifest has a URL).
    struct BeyondLibraryHit: Identifiable, Equatable {
        let volumeID: String
        let documentID: String
        /// Exact int8 cosine, the same scale the rows' chips show.
        let score: Double
        /// The volume's manifest title.
        let volumeTitle: String
        /// Whether the manifest carries a download URL (side-loaded volumes do not).
        let isDownloadable: Bool
        var id: String { "\(volumeID)/\(documentID)" }
    }

    /// What the caption must say — every count the mode owes the reader.
    struct Disclosure: Equatable {
        /// Candidates dropped because their volume's shard is not on this device (warming up).
        var unscoredCandidates: Int
        /// Distinct volumes those came from.
        var unscoredVolumes: Int
        /// Whether SQL filters were intersected against the indexed hits.
        var filtersApplied: Bool
        /// Indexed hits the filters removed.
        var filteredOut: Int
        /// Beyond-library hits present while filters were active — checked against volume
        /// scope only, which the caption must say.
        var beyondUncheckedByFilters: Bool
    }

    /// What a run produced.
    struct Outcome {
        var results: [SearchResult]
        var beyondLibrary: [BeyondLibraryHit]
        var disclosure: Disclosure
    }

    /// Runs one Meaning search.
    ///
    /// - Parameters:
    ///   - query: The reader's text, verbatim.
    ///   - parameters: The current search parameters; only their FILTERS are read.
    /// - Throws: `SemanticQuerySearcher.SearchUnavailable` untouched — the view models map the
    ///   `.modelNotDownloaded` case to the offer state.
    func run(query: String, parameters: SearchParameters) async throws -> Outcome {
        let searched = try await searcher.search(query, limit: Self.hitLimit)
        let indexed = indexedVolumeIds()

        var indexedHits: [SemanticQuerySearcher.Hit] = []
        var beyondHits: [SemanticQuerySearcher.Hit] = []
        for hit in searched.hits {
            if indexed.contains(hit.volumeID) {
                indexedHits.append(hit)
            } else {
                beyondHits.append(hit)
            }
        }

        // The filter intersection. `filterKeySet` is nil exactly when nothing constrains.
        let filterKeys = try await searchService.filterKeySet(parameters: parameters)
        var filteredOut = 0
        if let filterKeys {
            let before = indexedHits.count
            indexedHits = indexedHits.filter {
                filterKeys.contains("\($0.volumeID)/\($0.documentID)")
            }
            filteredOut = before - indexedHits.count
            // Volume scope is the one filter a beyond-library hit CAN honour.
            if let volumeIds = parameters.volumeIds, !volumeIds.isEmpty {
                let scope = Set(volumeIds)
                beyondHits = beyondHits.filter { scope.contains($0.volumeID) }
            }
        }

        // Keyed display rows, then synthesis in HIT ORDER — the ranked order IS relevance.
        let rows = try await searchService.semanticResultRows(
            forKeys: indexedHits.map { (volumeId: $0.volumeID, documentId: $0.documentID) })
        let results: [SearchResult] = indexedHits.compactMap { hit in
            guard let row = rows["\(hit.volumeID)/\(hit.documentID)"] else { return nil }
            return SearchResult(
                documentId: row.documentId,
                volumeId: row.volumeId,
                documentNumber: row.documentNumber,
                header: row.header,
                dateline: row.dateline,
                dateISO: row.dateISO,
                sourceNote: row.sourceNote,
                snippet: ProseSnippet.prose(
                    header: row.header,
                    dateline: row.dateline,
                    sourceNote: row.sourceNote,
                    body: row.bodyText),
                bm25Score: -hit.score,
                semanticScore: hit.score,
                subjectTagIds: SearchService.tagIds(from: row.subjectTagIds),
                userTagIds: SearchService.tagIds(from: row.userTagIds),
                isEditorialNote: row.isEditorialNote,
                isFrontMatter: row.isFrontMatter)
        }

        let beyond: [BeyondLibraryHit] = beyondHits.map { hit in
            let entry = manifestStore.entry(forVolumeId: hit.volumeID)
            return BeyondLibraryHit(
                volumeID: hit.volumeID,
                documentID: hit.documentID,
                score: hit.score,
                volumeTitle: entry?.title ?? hit.volumeID,
                isDownloadable: entry?.downloadUrl != nil)
        }

        return Outcome(
            results: results,
            beyondLibrary: beyond,
            disclosure: Disclosure(
                unscoredCandidates: searched.unscoredCandidates,
                unscoredVolumes: searched.unscoredVolumes,
                filtersApplied: filterKeys != nil,
                filteredOut: filteredOut,
                beyondUncheckedByFilters: filterKeys != nil && !beyond.isEmpty))
    }
}
