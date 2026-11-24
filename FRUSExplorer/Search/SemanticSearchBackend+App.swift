// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

// MARK: - SemanticSearchBackend + the app

/// The Meaning engine as the app makes and records it. `SemanticSearchBackend` moved into FRUSCoreKit for FRUS
/// Explorer Light's S27a, over values: this keeps the app's calls as they were, passing what the kit takes as
/// parameters, the manifest store's entries and the bundled generation's model.
///
/// Version history:
///   1.0 — 2026-11-24: FRUS Explorer Light's S27a — the engine's initialiser and its three rendered expressions as
///          they were, over the kit's
extension SemanticSearchBackend {

    /// Creates the engine over the app's manifest store.
    ///
    /// - Parameters:
    ///   - searcher: The Meaning engine.
    ///   - searchService: The index's search service.
    ///   - manifestStore: The manifest, which titles a hit beyond the library.
    ///   - indexedVolumeIds: The volumes the index holds, read at each run.
    init(searcher: SemanticQuerySearcher, searchService: SearchService, manifestStore: ManifestStore,
         indexedVolumeIds: @escaping () -> Set<String>) {
        self.init(searcher: searcher, searchService: searchService,
                  manifestEntry: { manifestStore.entry(forVolumeId: $0) },
                  indexedVolumeIds: indexedVolumeIds)
    }

    /// What a Meaning search records as its rendered expression, naming the bundled generation's model
    /// (``renderedExpression(model:)``).
    static var renderedExpression: String {
        renderedExpression(model: BundledSemanticVectors.provenance?.model)
    }

    /// What a ranking of a held list records as its rendered expression (``renderedExpression(rankingAll:model:)``).
    ///
    /// - Parameter count: The held list's members, every one of which the ranking returns.
    /// - Returns: The expression.
    static func renderedExpression(rankingAll count: Int) -> String {
        renderedExpression(rankingAll: count, model: BundledSemanticVectors.provenance?.model)
    }

    /// What a ranking of a held list's whole match records as its rendered expression
    /// (``renderedExpression(rankingAll:listing:model:)``).
    ///
    /// - Parameters:
    ///   - count: The documents ranked inside (`WholeMatchRanking.size`).
    ///   - limit: The ceiling the closest were listed up to.
    /// - Returns: The expression.
    static func renderedExpression(rankingAll count: Int, listing limit: Int) -> String {
        renderedExpression(rankingAll: count, listing: limit, model: BundledSemanticVectors.provenance?.model)
    }
}

extension SemanticSearchBackend: MeaningSearchRunning {}

// MARK: - MeaningSearchRunning

/// What a search view model needs of the Meaning engine: one run.
///
/// `SearchViewModel` and `MacSearchViewModel` hold the engine through this protocol, so a test can drive a Meaning
/// run through the view model with a list of its own. ``SemanticSearchBackend`` needs an index, the vectors and an
/// encoder: the kit's suites build one over synthetic vectors (`SemanticSetFixture`), and a view model's test passes a
/// list of its own instead.
///
/// Version history:
///   1.0 — #1595, #1597, #1598: initial implementation
///   1.1 — 2026-11-24: FRUS Explorer Light's S27a — moved here unchanged from `SemanticSearchBackend.swift`, which
///          moved into FRUSCoreKit
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
