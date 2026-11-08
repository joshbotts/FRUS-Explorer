// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - RelatedDocumentsDependencies

/// What the find-related engine reads from its host, in place of the app's `AppState`: the index's
/// pipeline, the cross-reference query, the person store, the document-grain subject index, the
/// manifest, the search service, the indexed volumes, the lexical axis's stopwords, and the semantic
/// axis when the host has one.
///
/// Each generator and scorer reads the member it needs where it read `appState` before, under the same
/// name, so most of the moved code differs from the app's only in that word. Three reads were not
/// `appState`'s: ``documentSubjectIndex`` was `DocumentSubjectStore.shared`, ``lexicalStopwords`` was
/// `WordCloudStopwords.active(includeDiplomatic: true)`, and the semantic axis's re-score read
/// `appState.semanticShardStore` in the engine, where ``semantic`` now reads it.
///
/// ## Each member is read where it is used, not when the value is made
/// The initialiser takes every member but ``semantic`` as an autoclosure. So the app's
/// `RelatedDocumentsDependencies(appState:)` passes `appState.personMentionStore`, and the scorer
/// that reads ``personMentionStore`` gets the store `AppState` holds at that moment, as it did when it
/// read `appState.personMentionStore` itself — `AppState.refreshReadOnlyStores()` replaces that store
/// and the cross-reference store, and ``indexedVolumeIds`` grows while a volume indexes. And the
/// app's `DocumentSubjectStore.shared`, which decodes a 6 MB file on first use, is still decoded only
/// when the shared-subject scorer first reads it. A host whose stores never change passes them as
/// values.
///
/// ## The semantic axis is behind ``semantic``
/// The app passes `AppSemanticSimilaritySource`, its generator's three passes, which read
/// SemanticVectorsKit's bundled tiers and the app's shard store; a host without the semantic stack
/// passes none, as FRUS Explorer Light does until its phase
/// 4. With none, the axis contributes nothing: no candidates, no re-score of the other axes'
/// candidates and no off-index leads, whatever its weight.
///
/// Version history:
///   1.0 — 2026-11-08: FRUS Explorer Light's S23a, with the engine's move into FRUSCoreKit
public struct RelatedDocumentsDependencies: Sendable {

    private let indexingPipelineProvider: @MainActor @Sendable () -> IndexingPipeline?
    private let crossReferenceStoreProvider: @MainActor @Sendable () -> (any RelatedCitationSource)?
    private let personMentionStoreProvider: @MainActor @Sendable () -> PersonMentionStore?
    private let documentSubjectIndexProvider: @MainActor @Sendable () -> DocumentSubjectIndex?
    private let manifestStoreProvider: @MainActor @Sendable () -> any VolumeManifestLookup
    private let searchServiceProvider: @MainActor @Sendable () -> SearchService?
    private let indexedVolumeIdsProvider: @MainActor @Sendable () -> Set<String>
    private let lexicalStopwordsProvider: @MainActor @Sendable () -> Set<String>

    /// The live index's pipeline: archival neighbours, dates, volume structures, display records,
    /// body texts and snippets. `nil` while no index is open, when the engine returns
    /// `RelatedDocumentsResult.empty`.
    @MainActor public var indexingPipeline: IndexingPipeline? { indexingPipelineProvider() }

    /// The cross-reference query the citation generator runs; the app's `CrossReferenceStore`.
    @MainActor public var crossReferenceStore: (any RelatedCitationSource)? { crossReferenceStoreProvider() }

    /// The person store whose rollup the shared-people scorer reads.
    @MainActor public var personMentionStore: PersonMentionStore? { personMentionStoreProvider() }

    /// The document-grain subject index the shared-subjects scorer reads; `nil` when it is not
    /// available, and the axis then contributes nothing.
    @MainActor public var documentSubjectIndex: DocumentSubjectIndex? { documentSubjectIndexProvider() }

    /// The manifest the corpus-proximity scorer reads a volume's subseries from.
    @MainActor public var manifestStore: any VolumeManifestLookup { manifestStoreProvider() }

    /// The search service the lexical generator prices and runs its terms with.
    @MainActor public var searchService: SearchService? { searchServiceProvider() }

    /// The volumes with rows in the index, which the lexical generator keeps its candidates to.
    @MainActor public var indexedVolumeIds: Set<String> { indexedVolumeIdsProvider() }

    /// The words the lexical generator never takes as query terms: the app's word-cloud stopwords with
    /// the diplomatic list (`WordCloudStopwords.active(includeDiplomatic: true)`).
    @MainActor public var lexicalStopwords: Set<String> { lexicalStopwordsProvider() }

    /// The semantic axis, or `nil` for a host without the semantic stack (see the type's note).
    public let semantic: (any SemanticSimilaritySource)?

    /// Creates the dependencies. Every member but `semantic` is an autoclosure, read where the
    /// engine uses it.
    ///
    /// - Parameters:
    ///   - indexingPipeline: The live index's pipeline.
    ///   - crossReferenceStore: The cross-reference query.
    ///   - personMentionStore: The person store.
    ///   - documentSubjectIndex: The document-grain subject index.
    ///   - manifestStore: The manifest.
    ///   - searchService: The search service.
    ///   - indexedVolumeIds: The volumes with rows in the index.
    ///   - lexicalStopwords: The lexical generator's stopwords.
    ///   - semantic: The semantic axis, or `nil` to leave it out.
    public init(
        indexingPipeline: @autoclosure @escaping @MainActor @Sendable () -> IndexingPipeline?,
        crossReferenceStore: @autoclosure @escaping @MainActor @Sendable () -> (any RelatedCitationSource)?,
        personMentionStore: @autoclosure @escaping @MainActor @Sendable () -> PersonMentionStore?,
        documentSubjectIndex: @autoclosure @escaping @MainActor @Sendable () -> DocumentSubjectIndex?,
        manifestStore: @autoclosure @escaping @MainActor @Sendable () -> any VolumeManifestLookup,
        searchService: @autoclosure @escaping @MainActor @Sendable () -> SearchService?,
        indexedVolumeIds: @autoclosure @escaping @MainActor @Sendable () -> Set<String>,
        lexicalStopwords: @autoclosure @escaping @MainActor @Sendable () -> Set<String>,
        semantic: (any SemanticSimilaritySource)? = nil
    ) {
        self.indexingPipelineProvider = indexingPipeline
        self.crossReferenceStoreProvider = crossReferenceStore
        self.personMentionStoreProvider = personMentionStore
        self.documentSubjectIndexProvider = documentSubjectIndex
        self.manifestStoreProvider = manifestStore
        self.searchServiceProvider = searchService
        self.indexedVolumeIdsProvider = indexedVolumeIds
        self.lexicalStopwordsProvider = lexicalStopwords
        self.semantic = semantic
    }
}

// MARK: - RelatedCitationSource

/// The cross-reference generator's query: the documents directly cited by, or citing, an anchor, with
/// their citation counts. The app's `CrossReferenceStore` answers it with `relatedByCitation`.
///
/// Version history:
///   1.0 — 2026-11-08: FRUS Explorer Light's S23a
public protocol RelatedCitationSource: Sendable {
    /// The documents directly cited by, or citing, the anchor, the anchor itself excluded.
    ///
    /// - Parameters:
    ///   - documentId: The anchor document id.
    ///   - volumeId: The anchor volume id.
    ///   - scopeVolumeIds: Restrict candidates to these volumes (`nil` or empty: all indexed).
    ///   - limit: Maximum candidates, ordered by citation multiplicity (descending) then key.
    /// - Returns: The candidate documents with their citation counts.
    func relatedByCitation(
        forDocumentId documentId: String,
        volumeId: String,
        scopeVolumeIds: Set<String>?,
        limit: Int
    ) async throws -> [RelatedCitationCandidate]
}

// MARK: - VolumeManifestLookup

/// One volume's manifest entry by its id: the corpus-proximity scorer's read of a volume's subseries.
/// The app's `ManifestStore` answers it from whichever list it is serving.
///
/// Version history:
///   1.0 — 2026-11-08: FRUS Explorer Light's S23a
@MainActor
public protocol VolumeManifestLookup: Sendable {
    /// The manifest entry for `id`, or `nil` when the manifest has none.
    func entry(forVolumeId id: String) -> VolumeManifestEntry?
}
