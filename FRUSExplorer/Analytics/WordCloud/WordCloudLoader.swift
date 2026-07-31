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
    ///
    /// ## Why 1,000 and not the 220 this shipped with
    /// The cloud itself never draws more than `WordCloudLayout.place`'s 180-word cap, so this
    /// number is not about the picture — it is the candidate pool the **keyness** measure re-ranks.
    /// Measured on real volumes: at 220 the pool bottoms out at words occurring ~140–240 times in a
    /// volume, and a keyness ranking of *The Conference of Berlin* reached 169 terms; at 1,000 it
    /// bottoms out around 30 and reaches 607. The top ~30 are identical either way — what the extra
    /// depth buys is the second tier (`attlee`, `ruhr`, `clayton`, `mikołajczyk`; `golan`, `assad`,
    /// `unef`), which is usually where the research is.
    ///
    /// It costs no extra CPU: `WordFrequencyService.finalize` sorts the whole tally and applies
    /// `.prefix(limit)` afterwards, so only the prefix changes. It does cost **one** recomputation
    /// of every disk-cached scope (corpus, subseries, subject categories), because `limit` is part
    /// of both cache keys — deliberate, and paid once. Scopes a researcher builds (collections,
    /// tags, saved searches, custom scopes) were never persisted, so for them it costs nothing.
    static let standardTermLimit = 1_000

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

        // Combine the per-scope hidden words with the user's global and per-lens
        // custom stop lists, and read the tunable criteria, all from settings.
        let extras = hiddenWords.union(WordCloudSettings.extraStopwords(for: lens))
        let tuning = WordCloudSettings.tuning

        // Subseries and subject-category clouds span many volumes and are drawn from a
        // small, shared, stable set of signatures — worth the persistent disk cache and a
        // progress readout. Custom scopes are user-specific and unbounded, so they stay
        // transient (Phase 5).
        let isPersistentScope: Bool = {
            if case .subseries = scope { return true }
            if case .subjectCategory = scope { return true }
            return false
        }()
        // The CACHE signature (never the scope's canonical signature — the precompute queue
        // persists that one). A subject cloud's key set derives from the BUNDLED profiles, not
        // just the index, so its cache entries must also rotate when an app update ships a
        // regenerated volume-subject-profiles-index.json (the era-sanity regen did exactly
        // that): decorate with the bundle's `generated` stamp. The index-count fingerprint the
        // disk cache already applies covers indexing changes; this covers bundle changes.
        let cacheSignature: String = {
            if case .subjectCategory = scope {
                return "\(scope.signature)|vsp=\(VolumeSubjectProfilesStore.shared?.generated ?? "none")"
            }
            return scope.signature
        }()
        let result: WordCloudResult
        if resolved.isCorpus {
            result = try await service.corpusTopTerms(
                limit: limit, includeDiplomaticStopwords: excludeBoilerplate,
                extraStopwords: extras, lens: lens, tuning: tuning, progress: progress
            )
        } else {
            result = try await service.topTerms(
                signature: cacheSignature, keys: resolved.keys,
                limit: limit, includeDiplomaticStopwords: excludeBoilerplate,
                extraStopwords: extras, lens: lens, tuning: tuning,
                persistent: isPersistentScope, progress: isPersistentScope ? progress : nil
            )
        }
        return (result, resolved.title)
    }
}
