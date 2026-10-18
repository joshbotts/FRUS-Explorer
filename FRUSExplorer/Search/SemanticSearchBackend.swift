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
///   1.5 — B4 (#1659): ``renderedExpression`` names the bundled generation's model
///   1.6 — #1577 lane 4: ``rerank(query:base:parameters:)`` ranks a held keyword list or browse by a
///         question, its own rows reordered with their keyword snippets, the rows it cannot rank last
///   1.7 — #1577 lane 6: ``rankWholeMatch(query:base:match:parameters:limit:)`` ranks the whole match of a list
///         held at its ceiling, inside the filters chosen since, and lists the closest rows up to the ceiling with
///         their keyword snippets
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

    /// What a Meaning search records as its rendered expression, which the method appendix's CSV
    /// prints verbatim — the honest record of what ran, so it names the bundled generation's
    /// model rather than a literal. Both view models read it, so the twins cannot drift; through
    /// build 50 each spelled `text-embedding-embeddinggemma-300m-qat` itself, which would have
    /// named the 300m beside EmbeddingGemma 2's results (B4).
    static var renderedExpression: String {
        let model = BundledSemanticVectors.provenance?.model ?? "unavailable"
        return "route=semantic; model=\(model); top=\(hitLimit)"
    }

    /// What a ranking of a held list records as its rendered expression (#1577 lane 4): the same
    /// route and model, and the size of the list it ranked whole, where a search of the series records
    /// the hundred it returns. "top=100" over a ranking of 212 documents would misstate what ran.
    ///
    /// - Parameter count: The held list's members, every one of which the ranking returns.
    /// - Returns: The expression.
    static func renderedExpression(rankingAll count: Int) -> String {
        let model = BundledSemanticVectors.provenance?.model ?? "unavailable"
        return "route=semantic; model=\(model); ranked=\(count)"
    }

    /// What a ranking of a held list's whole match records as its rendered expression (#1577 lane 6): the
    /// documents it ranked, and the ceiling it listed the closest of them up to. "ranked=35275; top=1000".
    ///
    /// - Parameters:
    ///   - count: The documents ranked inside (`WholeMatchRanking.size`).
    ///   - limit: The ceiling the closest were listed up to.
    /// - Returns: The expression.
    static func renderedExpression(rankingAll count: Int, listing limit: Int) -> String {
        renderedExpression(rankingAll: count) + "; top=\(limit)"
    }

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

    /// What a ranking of a held list's whole match produced (#1577 lane 6).
    struct WholeMatchOutcome {
        /// The rows, the closest first and then those listed unranked, and the disclosure. No hit is beyond the
        /// library: every document a keyword match holds is in the index.
        var outcome: Outcome
        /// The keys of the list's whole match, as the index gave them, which the view model keeps with the list so
        /// that a second question asks the index nothing.
        var matchKeys: [String]
        /// What the header and a capture say of the ranking.
        var ranking: WholeMatchRanking
        /// The trail's signature of the documents the ranking ranked inside
        /// (`SearchScopeSignature.semanticSignature(rankingInside:)`), made with the set.
        var setSignature: String
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

    /// Ranks a held list by a question (#1577 lane 4): every member closest first, then the members
    /// that could not be ranked, in the list's own order.
    ///
    /// The same path as ``run(query:parameters:)`` inside a document set, with the list's members as
    /// the set and its whole size as the limit (the owner's decision 3: a ranking returns the whole
    /// list, since the reader found those documents and a cut to 100 would lose some without saying
    /// which). Two things differ:
    ///
    /// - **The rows are the list's own**, so each keeps its keyword snippet with the words in bold,
    ///   and gains the chip. A Meaning search's rows carry a prose snippet, which here would throw
    ///   the keyword search's evidence away.
    /// - **A member that cannot be ranked is kept**, last and with no score (rule 4): it has no vector,
    ///   or its volume's match file is not on this device. The disclosure counts each kind, as a
    ///   search inside a set does, and the strip says why.
    ///
    /// The members are the list's rows that the document gate admits: the view model joins the held
    /// list to it (`DocumentScopeGate.combine(corpus:projectGate:pin:)`), so a working corpus applied
    /// since narrows them. Every other filter narrows the ranked list afterwards, as for any Meaning
    /// search, ranked rows and unranked alike.
    ///
    /// - Parameters:
    ///   - query: The reader's question, verbatim.
    ///   - base: The held list's members, in its order.
    ///   - parameters: The parameters the layer runs with, the held list's gate among them.
    /// - Returns: The rows, no beyond-library hits, and the disclosure.
    /// - Throws: `SemanticQuerySearcher.SearchUnavailable`, as ``run(query:parameters:)`` does.
    func rerank(query: String, base: [SearchResult], parameters: SearchParameters) async throws -> Outcome {
        let admitted = parameters.documentIds.map(Set.init)
        let members = admitted.map { gate in base.filter { gate.contains($0.id) } } ?? base
        let searched = try await searcher.search(query, within: members.map(\.id), limit: members.count)
        var (rows, _) = LayeredResultComposer.rankedWithTail(
            ranked: searched.hits.map { (key: "\($0.volumeID)/\($0.documentID)", score: $0.score) },
            members: members)

        var filterParameters = parameters
        filterParameters.documentIds = nil
        let filterKeys = try await searchService.filterKeySet(parameters: filterParameters)
        var filteredOut = 0
        if let filterKeys {
            let before = rows.count
            rows = rows.filter { filterKeys.contains($0.id) }
            filteredOut = before - rows.count
        }

        return Outcome(
            results: rows,
            beyondLibrary: [],
            disclosure: Disclosure(
                unscoredCandidates: searched.unscoredCandidates,
                unscoredVolumes: searched.unscoredVolumes,
                downloadingVolumes: searched.downloadingVolumes,
                filtersApplied: filterKeys != nil,
                filteredOut: filteredOut,
                beyondUncheckedByFilters: false,
                rankedWithin: searched.rankedWithin,
                withoutVector: searched.withoutVector))
    }

    /// Ranks the whole match of a held list cut at its ceiling by a question (#1577 lane 6), and lists the closest
    /// documents up to the ceiling: "Closest 1,000 of 35,275 results".
    ///
    /// ## Why the whole match
    ///
    /// A keyword list held at its ceiling (1,000 rows on iPhone and iPad, 7,500 on the Mac) is the highest-scoring
    /// slice of its match by the keyword engine's measure, a different slice on each platform, and
    /// ``rerank(query:base:parameters:)`` ranked the slice. Here every document of the match is scored, by the one
    /// path a search inside a set takes (`SemanticQuerySearcher.search(_:within:limit:)`, exact scoring of each
    /// member, with no threshold), and the best `limit` are listed. A document the keyword engine ranked below the
    /// ceiling can now be the closest to the question.
    ///
    /// ## Steps
    ///
    /// 1. **The match's keys**: the list's own once a ranking has read them, otherwise `SearchService.matchKeys` over
    ///    the search that found the list. Less the rows Checklist Mode hid when it was held, inside a working corpus
    ///    applied since (`LayeredResultComposer.wholeMatchSet(_:leavingOut:inside:)`), and passing the other filters
    ///    chosen since (`LayeredResultComposer.wholeMatchSet(_:passing:)`), off the main actor.
    /// 2. **The ranking**, which counts the members it cannot rank, as any search inside a set does.
    /// 3. **The rows**: the closest, and where fewer than `limit` could be ranked, the list's own unranked rows after
    ///    them (`LayeredResultComposer.wholeMatchSelection(ranked:members:admitted:limit:)`), those in the set ranked.
    ///    A row the list holds is its
    ///    own; the rest come from the list's keyword search run again with them as its gate, so every row keeps its
    ///    keyword snippet, where `SearchService.semanticResultRows(forKeys:)` would give none. That gate holds at
    ///    most `limit` keys, so no statement binds more than the 7,500 the Mac's ceiling allows (rule 8).
    ///
    /// ## The filters narrow the match, not the closest rows
    ///
    /// Every other Meaning list is ranked first and narrowed by the filters after. Here that would leave out of reach
    /// every document that passes them and ranks below the ceiling: a volume none of whose documents is among the
    /// closest 1,000 of the whole match would list nothing, under a row naming all of it. So the filters narrow the set
    /// before it is ranked, and the closest listed are the closest of the documents that pass them. The set is scored
    /// whole either way, so the filters cost the ranking nothing and save it the documents they leave out.
    ///
    /// - Parameters:
    ///   - query: The reader's question, verbatim.
    ///   - base: The held list (`PinnedResultBase.ranksWholeMatch`).
    ///   - ran: The search that found the list (`PinnedResultBase.ranParameters`): its match is the one ranked.
    ///   - parameters: The parameters in force outside the held list: their document gate and their other filters
    ///     narrow the match before the ranking.
    ///   - limit: The ceiling: the list's own fetch limit.
    /// - Returns: The rows, the match's keys, what the ranking ranked, and the set's signature for the trail.
    /// - Throws: `SemanticQuerySearcher.SearchUnavailable`, as ``run(query:parameters:)`` does, and
    ///   `CancellationError` when the task is cancelled: the kit's statements stop (#1680), the set is not finished,
    ///   and the searcher stops between its steps.
    func rankWholeMatch(query: String, base: PinnedResultBase, match ran: SearchParameters,
                        parameters: SearchParameters, limit: Int) async throws -> WholeMatchOutcome {
        let clock = ContinuousClock()
        let keysStart = clock.now
        let kept = base.wholeMatch
        let matchKeys: [String]
        if let kept {
            matchKeys = kept
        } else {
            matchKeys = try await searchService.matchKeys(parameters: ran)
        }
        let keysTime = clock.now - keysStart

        // The other filters, which narrow the match before the ranking. `filterKeySet` is nil exactly when nothing
        // constrains; built without the document gate, which the set honours below.
        let setStart = clock.now
        var filterParameters = parameters
        filterParameters.documentIds = nil
        let filterKeys = try await searchService.filterKeySet(parameters: filterParameters)

        // The set and its trail signature, off the main actor: a common word's match is some 200,000 keys, and the
        // signature's digest sorts them. A detached task is not cancelled with this one, so it is told.
        let hidden = base.hiddenKeys
        let gate = parameters.documentIds
        let members = base.members
        let setWork = Task.detached(priority: .userInitiated) { () throws -> WholeMatchSet in
            let inside = LayeredResultComposer.wholeMatchSet(matchKeys, leavingOut: hidden, inside: gate)
            try Task.checkCancellation()
            let set = LayeredResultComposer.wholeMatchSet(inside, passing: filterKeys)
            try Task.checkCancellation()
            return WholeMatchSet(keys: set, filteredOut: inside.count - set.count,
                                 admitted: LayeredResultComposer.admittedMembers(members, of: set),
                                 signature: SearchScopeSignature.semanticSignature(rankingInside: set))
        }
        let prepared = try await withTaskCancellationHandler {
            try await setWork.value
        } onCancel: {
            setWork.cancel()
        }
        let set = prepared.keys
        let admitted = prepared.admitted
        let setTime = clock.now - setStart
        try Task.checkCancellation()

        let rankStart = clock.now
        let searched = try await searcher.search(query, within: set, limit: limit)
        let rankTime = clock.now - rankStart
        try Task.checkCancellation()

        let (chosen, fill) = LayeredResultComposer.wholeMatchSelection(
            ranked: searched.hits.map { (key: "\($0.volumeID)/\($0.documentID)", score: $0.score) },
            members: members, admitted: admitted, limit: limit)

        // A row for each chosen document: the list's own, or its keyword search's, run again for the rest.
        var rows = Dictionary(base.members.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let unheld = chosen.map(\.key).filter { rows[$0] == nil }
        let fetchStart = clock.now
        if !unheld.isEmpty {
            var again = ran
            again.documentIds = DocumentScopeGate.combine(corpus: ran.documentIds, projectGate: nil, pin: unheld)
            for row in try await searchService.search(parameters: again, limit: unheld.count) {
                rows[row.id] = row
            }
        }
        let fetchTime = clock.now - fetchStart
        let (listed, missing) = LayeredResultComposer.wholeMatchRows(ranked: chosen, fill: fill, rows: rows)
        let closest = listed.count - fill.count

        let size = searched.rankedWithin ?? set.count
        SearchTimingLog.record(SearchTimingLog.WholeMatch(
            matchSize: matchKeys.count, setSize: size, keysKept: kept != nil,
            ranked: chosen.count, refetched: unheld.count, listed: listed.count,
            keys: keysTime, set: setTime, rank: rankTime, refetch: fetchTime))
        return WholeMatchOutcome(
            outcome: Outcome(
                results: listed,
                beyondLibrary: [],
                // The filters narrowed the set before the ranking, so no hit was removed after it: the ranking's own
                // record says what they left out (`WholeMatchRanking.filteredOut`).
                disclosure: Disclosure(
                    unscoredCandidates: searched.unscoredCandidates,
                    unscoredVolumes: searched.unscoredVolumes,
                    downloadingVolumes: searched.downloadingVolumes,
                    filtersApplied: filterKeys != nil,
                    filteredOut: 0,
                    beyondUncheckedByFilters: false,
                    rankedWithin: searched.rankedWithin,
                    withoutVector: searched.withoutVector,
                    notIndexedHere: missing)),
            matchKeys: matchKeys,
            ranking: WholeMatchRanking(
                size: size,
                filteredOut: prepared.filteredOut,
                notRanked: searched.withoutVector + searched.unscoredCandidates,
                closest: closest,
                isCut: closest + fill.count < size),
            setSignature: prepared.signature)
    }

    /// The set a ranking of a whole match ranks inside, made off the main actor
    /// (``rankWholeMatch(query:base:match:parameters:limit:)``): its keys, what the filters left out of it, the held
    /// list's members it holds, and its signature for the trail.
    private struct WholeMatchSet: Sendable {
        /// The set, in the match's order.
        let keys: [String]
        /// The documents of the match inside the gate, less the hidden rows, that the other filters left out.
        let filteredOut: Int
        /// The held list's members in the set.
        let admitted: Set<String>
        /// `SearchScopeSignature.semanticSignature(rankingInside:)` of the set.
        let signature: String
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

    /// Ranks a held list by a question (#1577 lane 4): its members closest first, then those that
    /// could not be ranked. See `SemanticSearchBackend.rerank(query:base:parameters:)`.
    ///
    /// - Parameters:
    ///   - query: The reader's question, verbatim.
    ///   - base: The held list's members, in its order.
    ///   - parameters: The parameters the layer runs with, the held list's gate among them.
    /// - Returns: The rows, and what the caption owes the reader.
    /// - Throws: `SemanticQuerySearcher.SearchUnavailable`.
    func rerank(query: String, base: [SearchResult],
                parameters: SearchParameters) async throws -> SemanticSearchBackend.Outcome

    /// Ranks the whole match of a held list cut at its ceiling (#1577 lane 6), and lists the closest documents up to
    /// the ceiling. See `SemanticSearchBackend.rankWholeMatch(query:base:match:parameters:limit:)`.
    ///
    /// - Parameters:
    ///   - query: The reader's question, verbatim.
    ///   - base: The held list.
    ///   - ran: The search that found the list.
    ///   - parameters: The parameters in force outside the held list.
    ///   - limit: The ceiling.
    /// - Returns: The rows, the match's keys, what the ranking ranked, and the set's signature.
    /// - Throws: `SemanticQuerySearcher.SearchUnavailable`.
    func rankWholeMatch(query: String, base: PinnedResultBase, match ran: SearchParameters,
                        parameters: SearchParameters, limit: Int) async throws -> SemanticSearchBackend.WholeMatchOutcome
}

extension MeaningSearchRunning {

    /// A stand-in that ranks nothing: the engine a test builds for a plain Meaning run need not rank a
    /// held list, and one that is asked to says it cannot run, as an engine with no vectors does.
    func rerank(query: String, base: [SearchResult],
                parameters: SearchParameters) async throws -> SemanticSearchBackend.Outcome {
        throw SemanticQuerySearcher.SearchUnavailable.vectorsUnavailable
    }

    /// A stand-in that ranks no whole match, as ``rerank(query:base:parameters:)``'s ranks no list.
    func rankWholeMatch(query: String, base: PinnedResultBase, match ran: SearchParameters,
                        parameters: SearchParameters, limit: Int) async throws -> SemanticSearchBackend.WholeMatchOutcome {
        throw SemanticQuerySearcher.SearchUnavailable.vectorsUnavailable
    }
}
