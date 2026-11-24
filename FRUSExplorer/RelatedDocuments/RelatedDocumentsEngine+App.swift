// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - RelatedDocumentsEngine (the app's)

/// The app's half of ``RelatedDocumentsEngine``, whose ranking, generators and scorers are
/// FRUSCoreKit's (`FRUSCoreKit/RelatedDocuments/`): the call every app surface makes, with the
/// app's `AppState`.
///
/// Version history:
///   1.0 — 2026-11-08: FRUS Explorer Light's S23a — the engine moved into FRUSCoreKit, and this is
///          the entry point it had, unchanged for its three callers (`RelatedDocumentsContent`,
///          `RelatedDocumentsRequest.load` and `ProjectLeadsService`)
///   1.1 — 2026-11-10: FRUS Explorer Light's S23b — `CrossReferenceStore`'s conformance to
///          `RelatedCitationSource` is declared with the store, now FRUSCoreKit's
///   1.2 — 2026-11-22: FRUS Explorer Light (#1907) — the doc comment names the kit's `rank` as it now
///          reads, with a `userSource` the app leaves at the index; the call is unchanged
///   1.3 — 2026-11-23: FRUS Explorer Light's S26a — the semantic axis's passes and Project Home's
///          reach moved into FRUSCoreKit, over a ``SemanticSimilarityHost``; the app's host, the shard
///          store's conformance, and the generation's and the reach's calls with `AppState`, by the
///          names the app's callers use, are below
extension RelatedDocumentsEngine {

    /// Computes the ranked related documents for an anchor over the app's own index and stores: the
    /// kit's ``rank(anchor:anchorYear:weights:scopeVolumeIds:limit:includeSnippets:userSource:includeOffIndexLeads:dependencies:)``
    /// with ``RelatedDocumentsDependencies/init(appState:)``, its lines' summaries read from the index
    /// (the kit's default source), where the app keeps them.
    ///
    /// - Parameters:
    ///   - anchor: The seed document.
    ///   - anchorYear: The seed's coverage year, if known, threaded to date-sensitive generators.
    ///   - weights: The user's per-axis tuning. A scorer whose axis weight is 0 is skipped entirely.
    ///   - scopeVolumeIds: The volume set to restrict candidates to (`nil` = all indexed).
    ///   - limit: Maximum rows.
    ///   - includeSnippets: Whether to fetch a context snippet for the shown rows.
    ///   - includeOffIndexLeads: Whether to run the S-3 off-index scan.
    ///   - appState: Holds the live index, the stores and the semantic axis's shard store.
    /// - Returns: The ranked result, or `.empty` when the index isn't ready or nothing matched.
    @MainActor
    static func rank(
        anchor: DocumentKey,
        anchorYear: Int?,
        weights: AxisWeights,
        scopeVolumeIds: Set<String>?,
        limit: Int,
        includeSnippets: Bool = true,
        includeOffIndexLeads: Bool = true,
        appState: AppState
    ) async -> RelatedDocumentsResult {
        await rank(
            anchor: anchor, anchorYear: anchorYear, weights: weights,
            scopeVolumeIds: scopeVolumeIds, limit: limit,
            includeSnippets: includeSnippets, includeOffIndexLeads: includeOffIndexLeads,
            dependencies: RelatedDocumentsDependencies(appState: appState))
    }
}

// MARK: - RelatedDocumentsDependencies (the app's)

extension RelatedDocumentsDependencies {

    /// The app's dependencies: what `AppState` holds, each read where the engine reads it (see the
    /// type's note), with the subject index from `DocumentSubjectStore`, the lexical axis's stopwords
    /// from the word cloud's, and the semantic axis over SemanticVectorsKit and the shard store
    /// (``SemanticVectorsSimilaritySource`` over ``SemanticSimilarityHost/init(appState:)``).
    ///
    /// - Parameter appState: The app's state.
    @MainActor
    init(appState: AppState) {
        self.init(
            indexingPipeline: appState.indexingPipeline,
            crossReferenceStore: appState.crossReferenceStore,
            personMentionStore: appState.personMentionStore,
            documentSubjectIndex: DocumentSubjectStore.shared,
            manifestStore: appState.manifestStore,
            searchService: appState.searchService,
            indexedVolumeIds: appState.indexedVolumeIds,
            lexicalStopwords: WordCloudStopwords.active(includeDiplomatic: true),
            semantic: SemanticVectorsSimilaritySource(host: SemanticSimilarityHost(appState: appState)))
    }
}

// MARK: - The semantic axis's host (the app's)

extension SemanticSimilarityHost {

    /// The app's host for the semantic axis and Project Home's reach: the bundled tiers
    /// `BundledSemanticVectors` holds, and the shard store, the indexed volumes and the pipeline
    /// `AppState` holds, each read where a pass reads it, as the passes read them when they were the
    /// app's. A pass that wants a shard the store lacks asks `AppState` to fetch it, for the reason the
    /// passes always gave, `.readerAskedForSemantics`, so the reader's Download With Volumes decides.
    ///
    /// - Parameter appState: The app's state.
    @MainActor
    init(appState: AppState) {
        self.init(
            index: BundledSemanticVectors.index,
            corpusVectors: BundledSemanticVectors.corpusVectors,
            shardStore: appState.semanticShardStore,
            indexedVolumeIds: appState.indexedVolumeIds,
            indexingPipeline: appState.indexingPipeline,
            requestShard: { volumeID in
                _ = appState.fetchSemanticShardIfNeeded(for: volumeID, reason: .readerAskedForSemantics)
            })
    }
}

extension SemanticSimilarityGenerator {

    /// The generation over the app's state: the kit's ``candidates(for:anchorYear:limit:scopeVolumeIds:host:)``
    /// over ``SemanticSimilarityHost/init(appState:)``, under the name the semantic map's Nearest in
    /// language calls, as it did before the generation moved into the kit.
    ///
    /// - Parameters:
    ///   - anchor: The document the neighbours are of.
    ///   - anchorYear: Unused by this axis, as before.
    ///   - limit: How many neighbours.
    ///   - scopeVolumeIds: The caller's volume restriction, if any.
    ///   - appState: Holds the shard store, the indexed volumes and the pipeline.
    /// - Returns: The axis's own candidates, best first.
    func candidates(
        for anchor: DocumentKey,
        anchorYear: Int?,
        limit: Int,
        scopeVolumeIds: Set<String>?,
        appState: AppState
    ) async throws -> GeneratedPool {
        try await candidates(for: anchor, anchorYear: anchorYear, limit: limit,
                             scopeVolumeIds: scopeVolumeIds, host: SemanticSimilarityHost(appState: appState))
    }
}

extension SemanticProjectReach {

    /// Project Home's reach over the app's state: the kit's ``reach(seedKeys:weights:host:)`` over
    /// ``SemanticSimilarityHost/init(appState:)``, once the bundled tiers have loaded. The gate is
    /// read first, as it was, so a reader who has zeroed the axis never loads them here.
    ///
    /// - Parameters:
    ///   - seedKeys: The project's seed document keys, `"volumeId/documentId"`.
    ///   - weights: The reader's tuning — the consent gate.
    ///   - appState: Holds the indexed-volume set.
    /// - Returns: The ranked finding, or ``ProjectReach/none``.
    static func reach(
        seedKeys: [String], weights: AxisWeights, appState: AppState
    ) async -> ProjectReach {
        guard runsScan(weights: weights) else { return .none }
        await BundledSemanticVectors.prepare()
        return await reach(seedKeys: seedKeys, weights: weights,
                           host: SemanticSimilarityHost(appState: appState))
    }
}

// MARK: - The app's stores, as the engine reads them

/// The corpus-proximity scorer reads a volume's subseries from the store's `entry(forVolumeId:)`.
extension ManifestStore: VolumeManifestLookup {}

/// The semantic axis reads a shard through the store's own `shard(for:)`, which maps a shard once and
/// remembers a refusal; the store's downloads, adoption and purges stay the app's.
extension SemanticShardStore: SemanticShardSource {}
