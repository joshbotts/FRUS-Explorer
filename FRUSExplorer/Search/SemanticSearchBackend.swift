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
/// ## A document set is ranked inside, not intersected (#1577 lane 1)
///
/// `SearchParameters.documentIds` is the one constraint that is not a filter here. It is a set of
/// documents the reader asked to be inside — an applied working corpus, a project's History
/// scope, or both — and until this change it was intersected like the rest: the series' closest
/// hundred, less whatever fell outside the set, which for a small set is few rows or none. A
/// corpus's own footer says "Applying one searches only inside it", and in Meaning mode that was
/// untrue. Now the set goes to `SemanticQuerySearcher.search(_:within:limit:)`, which scores
/// every member, and it is taken out of the parameters before the filter key set is built, so it
/// is not scanned a second time. Every other filter still narrows after ranking, as the facet
/// panel's promise ("Narrowing to a row returns exactly its documents") requires.
///
/// ## A hit the index does not hold is counted, not blamed on a filter (#1577 lane 1)
///
/// The vectors are bundled with the build and a volume is whatever the device downloaded, so a
/// ranked hit can name a document the device's index has no row for. Such a hit is counted
/// (`Disclosure.notIndexedHere`) and the strip says so. Its rows are looked up before the filter
/// intersection for that reason: afterwards, it is indistinguishable from a hit a filter removed.
///
/// ## What it inherits from the searcher
///
/// Corpus-wide reach, the drop-and-queue shard rule with its disclosure counts, and the edition-
/// twin fold — all argued at `SemanticQuerySearcher`. Inside a set it inherits that search's
/// accounting instead: no fold, and every member ranked, without a vector, or without its file.
///
/// Version history:
///   1.0 — V-5 hybrid page
///   1.1 — Session 2026-09-30: #1527 — `Disclosure.downloadingVolumes`, so the caption says match
///         files are downloading only when they are
///   1.2 — Session 2026-09-30, review round 1: #1527 — the count is the searcher's own, from its
///         answered fetch requests, rather than an ask count gated on the switch at caption time
///   1.3 — #1595, #1597, #1598: conforms to ``MeaningSearchRunning``, which is how the view models hold it
///   1.4 — #1577 lane 1: a document set is ranked inside; `Disclosure.rankedWithin` and `withoutVector`;
///         a hit the index holds no row for is counted in `notIndexedHere` and no longer in `filteredOut`
@MainActor
struct SemanticSearchBackend: MeaningSearchRunning {

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
        /// Of those volumes, how many have a match-file download under way, as the searcher's
        /// fetch requests were answered (#1527; `SemanticQuerySearcher.Results.downloadingVolumes`).
        /// Zero with Download With Volumes off or offline, and short of ``unscoredVolumes``
        /// whenever a volume's candidates ranked below the searcher's fetch depth.
        var downloadingVolumes: Int
        /// Whether SQL filters were intersected against the indexed hits.
        var filtersApplied: Bool
        /// Indexed hits the filters removed.
        var filteredOut: Int
        /// Beyond-library hits present while filters were active — checked against volume
        /// scope only, which the caption must say.
        var beyondUncheckedByFilters: Bool
        /// The size of the document set the run ranked inside, or `nil` for a run across the
        /// whole series (#1577). While it is set, ``unscoredCandidates`` counts members of the set
        /// and not candidates, and the caption words them so.
        var rankedWithin: Int? = nil
        /// Members of that set the bundled vectors hold no row for
        /// (`SemanticQuerySearcher.Results.withoutVector`). Zero for a run across the series.
        var withoutVector: Int = 0

        /// Ranked hits in volumes this device has indexed whose documents its index does not
        /// hold, which cannot be listed (#1577). The vectors are the build's and the volume is the
        /// device's, so the two can disagree: a document upstream added to a volume since the
        /// reader downloaded it, or removed from it since the build's vectors were made. Counted
        /// before the filters are applied, so it is never part of ``filteredOut``.
        var notIndexedHere: Int = 0

        /// Members of the set that were scored, or `nil` for a run across the series: the set less
        /// its members without a vector and those without their match file. It is the number
        /// ranked, not the number listed, which the list's length and the other filters cut.
        var rankedCount: Int? {
            rankedWithin.map { max(0, $0 - withoutVector - unscoredCandidates) }
        }
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
    ///   - parameters: The current search parameters; only their FILTERS are read, and of those
    ///     `documentIds` is ranked inside where the others narrow afterwards.
    /// - Throws: `SemanticQuerySearcher.SearchUnavailable` untouched — the view models map the
    ///   `.modelNotDownloaded` case to the offer state.
    func run(query: String, parameters: SearchParameters) async throws -> Outcome {
        // `nil` is no set and `[]` is a set that holds nothing: the gate's own contract, which an
        // empty History scope and a disjoint corpus both rely on to match nothing.
        let searched: SemanticQuerySearcher.Results
        var filterParameters = parameters
        if let documentSet = parameters.documentIds {
            searched = try await searcher.search(query, within: documentSet, limit: Self.hitLimit)
            filterParameters.documentIds = nil
        } else {
            searched = try await searcher.search(query, limit: Self.hitLimit)
        }
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

        // Display rows first, for every hit in an indexed volume. A hit the index holds no row
        // for cannot be listed, and it is counted as that. Looked up after the filters, as these
        // were until #1577, such a hit was missing from the filter key set too, so it was
        // reported as a match "your filters removed" to a reader who might have set none.
        let rows = try await searchService.semanticResultRows(
            forKeys: indexedHits.map { (volumeId: $0.volumeID, documentId: $0.documentID) })
        let hitsInIndexedVolumes = indexedHits.count
        indexedHits = indexedHits.filter { rows["\($0.volumeID)/\($0.documentID)"] != nil }
        let notIndexedHere = hitsInIndexedVolumes - indexedHits.count

        // The filter intersection. `filterKeySet` is nil exactly when nothing constrains. Built
        // without the document set, which the ranking above has already honoured.
        let filterKeys = try await searchService.filterKeySet(parameters: filterParameters)
        var filteredOut = 0
        if let filterKeys {
            let before = indexedHits.count
            indexedHits = indexedHits.filter {
                filterKeys.contains("\($0.volumeID)/\($0.documentID)")
            }
            filteredOut = before - indexedHits.count
            // Volume scope is the one filter a beyond-library hit CAN honour.
            if let volumeIds = filterParameters.volumeIds, !volumeIds.isEmpty {
                let scope = Set(volumeIds)
                beyondHits = beyondHits.filter { scope.contains($0.volumeID) }
            }
        }

        // Synthesis in HIT ORDER — the ranked order IS relevance.
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
                downloadingVolumes: searched.downloadingVolumes,
                filtersApplied: filterKeys != nil,
                filteredOut: filteredOut,
                beyondUncheckedByFilters: filterKeys != nil && !beyond.isEmpty,
                rankedWithin: searched.rankedWithin,
                withoutVector: searched.withoutVector,
                notIndexedHere: notIndexedHere))
    }
}

// MARK: - MeaningSearchRunning

/// What a search view model needs of the Meaning engine: one run.
///
/// `SearchViewModel` and `MacSearchViewModel` hold the engine through this protocol, so a test can drive a Meaning
/// run through the view model with a list of its own. ``SemanticSearchBackend`` cannot be built in a unit test's
/// host: it needs the query encoder's model and the vector files, and neither is there.
///
/// Version history:
///   1.0 — #1595, #1597, #1598: initial implementation
@MainActor
protocol MeaningSearchRunning {

    /// Runs one Meaning search.
    ///
    /// - Parameters:
    ///   - query: The reader's text, verbatim.
    ///   - parameters: The current search parameters; only their filters are read. A document set among them
    ///     (`documentIds`) is ranked inside, and the other filters narrow the ranked list.
    /// - Returns: The ranked rows, the hits beyond the indexed library, and what the caption owes the reader.
    /// - Throws: `SemanticQuerySearcher.SearchUnavailable`, which the view models map to their own states.
    func run(query: String, parameters: SearchParameters) async throws -> SemanticSearchBackend.Outcome
}
