// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

/// Resolves a `WordCloudScope` and computes its result, picking the right service
/// path (corpus, persistent subseries, or bounded scope).
///
/// Shared by `WordCloudView` and the comparative columns so the resolve→compute
/// dispatch lives in exactly one place.
///
/// Version history:
///   1.0 — Word Cloud feature: Phase 4 (extracted for reuse by comparison view)
@MainActor
enum WordCloudLoader {

    /// The standard number of terms requested by the main view and the background
    /// precompute, kept in one place so their on-disk cache keys always match.
    static let standardTermLimit = 220

    /// AppStorage key for the diplomatic-boilerplate stopword toggle (mirrors the
    /// `@AppStorage` used by `WordCloudView`).
    static let excludeBoilerplateKey = "frus.wordcloud.excludeBoilerplate"

    /// Computes one queued scope and writes it to the disk cache, using exactly the
    /// parameters the UI will later request so the precomputed result is a cache hit.
    ///
    /// - Returns: `true` when the job is finished with (success or unrecoverable
    ///   failure) and should be dequeued; `false` when it was cancelled (e.g. the
    ///   background task expired) and should be retried later.
    static func precompute(
        signature: String,
        appState: AppState,
        modelContext: ModelContext
    ) async -> Bool {
        guard let scope = WordCloudScope(signature: signature) else { return true }
        let exclude = UserDefaults.standard.object(forKey: excludeBoilerplateKey) as? Bool ?? true
        let hidden = WordCloudOverrides.hidden(for: signature)
        do {
            _ = try await load(
                scope: scope, excludeBoilerplate: exclude, hiddenWords: hidden,
                limit: standardTermLimit, appState: appState, modelContext: modelContext
            )
            return true
        } catch is CancellationError {
            return false
        } catch {
            #if DEBUG
            print("[WordCloudLoader] Precompute failed for \(signature): \(error)")
            #endif
            return true
        }
    }

    /// Computes the word cloud for `scope`.
    ///
    /// - Parameters:
    ///   - scope: The body of material to analyse.
    ///   - excludeBoilerplate: Whether the diplomatic stopword layer is active.
    ///   - hiddenWords: Per-scope user-hidden terms to exclude.
    ///   - limit: Maximum number of terms to return.
    ///   - appState: Provides the services and manifest.
    ///   - modelContext: SwiftData context for collection/tag/saved-search resolution.
    ///   - progress: Optional per-chunk progress callback (heavy scopes only).
    /// - Returns: The computed result and a display title, or an empty result with
    ///   an empty title when the word-frequency service is unavailable.
    static func load(
        scope: WordCloudScope,
        excludeBoilerplate: Bool,
        hiddenWords: Set<String>,
        limit: Int,
        lens: WordCloudLens = .allTerms,
        appState: AppState,
        modelContext: ModelContext,
        progress: WordCloudProgress? = nil
    ) async throws -> (result: WordCloudResult, title: String) {
        guard let service = appState.wordFrequencyService else { return (.empty, "") }

        let resolver = WordCloudScopeResolver(
            manifestStore: appState.manifestStore,
            pipeline: appState.indexingPipeline,
            searchService: appState.searchService,
            modelContext: modelContext
        )
        let resolved = try await resolver.resolve(scope)

        let isSubseries: Bool = { if case .subseries = scope { return true } else { return false } }()
        let result: WordCloudResult
        if resolved.isCorpus {
            result = try await service.corpusTopTerms(
                limit: limit, includeDiplomaticStopwords: excludeBoilerplate,
                extraStopwords: hiddenWords, lens: lens, progress: progress
            )
        } else {
            result = try await service.topTerms(
                signature: scope.signature, keys: resolved.keys,
                limit: limit, includeDiplomaticStopwords: excludeBoilerplate,
                extraStopwords: hiddenWords, lens: lens,
                persistent: isSubseries, progress: isSubseries ? progress : nil
            )
        }
        return (result, resolved.title)
    }
}
