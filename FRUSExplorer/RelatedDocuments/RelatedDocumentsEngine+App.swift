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
extension RelatedDocumentsEngine {

    /// Computes the ranked related documents for an anchor over the app's own index and stores: the
    /// kit's ``rank(anchor:anchorYear:weights:scopeVolumeIds:limit:includeSnippets:includeOffIndexLeads:dependencies:)``
    /// with ``RelatedDocumentsDependencies/init(appState:)``.
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
    /// (``AppSemanticSimilaritySource``).
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
            semantic: AppSemanticSimilaritySource(appState: appState))
    }
}

// MARK: - The app's stores, as the engine reads them

/// The corpus-proximity scorer reads a volume's subseries from the store's `entry(forVolumeId:)`.
extension ManifestStore: VolumeManifestLookup {}
