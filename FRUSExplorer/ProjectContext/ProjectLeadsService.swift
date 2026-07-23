// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - ProjectLeadsService

/// Computes and persists a project's discovery **leads** (#377 Phase 3): documents related to
/// the project's seed that it hasn't engaged yet.
///
/// The seed is the project's **deliberately engaged documents** — its collection documents plus
/// the documents it has research notes on (both are intentional, in-scope engagement). Visited
/// documents are **excluded**: an opened-but-never-tagged/noted/collected document is as likely to
/// have been found irrelevant as relevant, so it would add noise, not signal (owner decision — the
/// engaged set still tracks visits for the "already seen" search filter and the recent-activity
/// log). For each seed the multi-axis related-document engine (#308) is run, the rankings are
/// aggregated across the seed (`ProjectLeadsAggregator`), and the top leads are upserted as
/// `ProjectLeadEntry` records — preserving each lead's `firstSurfacedAt` (the "new since you last
/// looked" anchor) and any `dismissed` flag.
///
/// `@MainActor` because the engine reads `AppState`; its work is bounded and `async`, so it
/// yields between per-seed ranks rather than blocking the UI. Callers should debounce it and
/// re-run when the project's collections or noted documents change.
@MainActor
enum ProjectLeadsService {

    /// Maximum seed documents ranked per recompute (bounds cost on a large collection).
    static let seedCap = 40
    /// Related documents fetched per seed before aggregation.
    static let perSeedRelatedLimit = 30
    /// Maximum leads persisted per project.
    static let leadLimit = 24

    /// The `@AppStorage` key of the global related-documents weight preference (shared with
    /// the document-view Related panel).
    static let globalWeightsKey = "frus.related.weights"

    /// The effective lead axis weights for a project (#377 Phase 3): its own per-project
    /// tuning if set, else the researcher's global related-documents preference, else the app
    /// default — always overlaid onto the current defaults so a newly-added axis (e.g. a future
    /// semantic-proximity axis) inherits its default weight rather than an implicit 0.
    static func effectiveWeights(for project: Project?) -> AxisWeights {
        effectiveWeights(projectRaw: project?.leadAxisWeights)
    }

    /// The effective weights from a project's already-read raw weight string (the off-main path:
    /// `gatherSeed` reads `Project.leadAxisWeights` on a background context, then `recompute`
    /// resolves the weights on the main actor without re-touching the model). Same precedence and
    /// forward-compatible default merge as `effectiveWeights(for:)`.
    static func effectiveWeights(projectRaw: String?) -> AxisWeights {
        let stored = projectRaw ?? UserDefaults.standard.string(forKey: globalWeightsKey)
        let base = stored.flatMap { AxisWeights(rawValue: $0) } ?? .default
        var merged: [SimilarityAxis: Double] = [:]
        for axis in SimilarityAxis.allCases {
            merged[axis] = base.weights[axis] ?? axis.defaultWeight
        }
        return AxisWeights(weights: merged)
    }

    /// The project's seed: the `"volumeId/documentId"` keys of its collection documents,
    /// de-duplicated and sorted. `nonisolated` so `gatherSeed` can run it on a background context
    /// off the main actor (the fetch pulls every collection and faults each one's `documentEntries`
    /// relationship — the Phase-2a lesson is to never do that synchronously in a UI path).
    nonisolated static func collectionSeedKeys(forProject projectId: UUID, in context: ModelContext) -> [String] {
        let collections = ((try? context.fetch(FetchDescriptor<Collection>())) ?? [])
            .filter { $0.projectIds.contains(projectId) }
        var keys = Set<String>()
        for collection in collections {
            for entry in collection.documentEntries ?? []
            where entry.kind == CollectionEntryKind.document.rawValue
                && !entry.volumeId.isEmpty && !entry.documentId.isEmpty {
                keys.insert("\(entry.volumeId)/\(entry.documentId)")
            }
        }
        return keys.sorted()
    }

    /// The project's noted-document seed: the `"volumeId/documentId"` keys of the documents that
    /// have a research note tagged to this project, de-duplicated and sorted. A note is a deliberate,
    /// in-scope engagement (unlike a mere visit), so noted documents anchor suggestions alongside
    /// collection documents. `nonisolated` so `gatherSeed` can run it off the main actor (an
    /// unscoped fetch filtered in memory — `[UUID].contains` predicates are unreliable in SwiftData).
    nonisolated static func noteSeedKeys(forProject projectId: UUID, in context: ModelContext) -> [String] {
        let notes = ((try? context.fetch(FetchDescriptor<ResearchNote>())) ?? [])
            .filter { $0.projectIds.contains(projectId) && !$0.volumeId.isEmpty && !$0.documentId.isEmpty }
        var keys = Set<String>()
        for note in notes {
            keys.insert("\(note.volumeId)/\(note.documentId)")
        }
        return keys.sorted()
    }

    /// Gathers the project's seed keys (its collection documents unioned with its noted documents)
    /// and its raw per-project weight string on a **background** context, off the main actor. The
    /// seed fetches pull every collection/note and filter in memory (the `projectIds`-contains
    /// predicate is unreliable in SwiftData); doing that — plus faulting each collection's
    /// `documentEntries` relationship — synchronously on the main thread froze the UI on a large
    /// library in Phase 2a, so it runs here on a detached task and returns only Sendable values.
    nonisolated static func gatherSeed(
        forProject projectId: UUID, container: ModelContainer
    ) async -> (seedKeys: [String], projectWeightsRaw: String?) {
        await Task.detached {
            let context = ModelContext(container)
            let pid = projectId
            let raw = (try? context.fetch(
                FetchDescriptor<Project>(predicate: #Predicate { $0.id == pid })).first)?.leadAxisWeights
            let seed = Set(collectionSeedKeys(forProject: projectId, in: context))
                .union(noteSeedKeys(forProject: projectId, in: context))
            return (seed.sorted(), raw)
        }.value
    }

    /// Recomputes the project's leads end-to-end: gather the seed, rank each seed's related
    /// documents, aggregate, and upsert the top leads. Clears the leads when the seed is empty.
    ///
    /// The seed gathering runs off-main (`gatherSeed`); the per-seed ranking must stay on the main
    /// actor (the engine reads `AppState`) but its heavy SQLite work happens inside the awaited
    /// actor calls, so the loop yields. Honors `Task` cancellation between seeds and before the
    /// upsert, so a superseding recompute (the debounce fired again) doesn't run to completion and
    /// race the fresher pass's writes.
    static func recompute(forProject projectId: UUID, appState: AppState, in context: ModelContext) async {
        // Flush pending main-context edits before reading the seed on a *separate* background
        // context: a document just added to (or removed from) a collection is only in the main
        // context's memory until the app autosaves, and `gatherSeed`'s fresh `ModelContext` sees
        // only the persisted store. Without this, a just-added seed document wouldn't be excluded
        // from the leads — the discovery feedback loop would appear broken (it wouldn't recover
        // until some later save *and* another recompute trigger). Cheap for a small changeset,
        // a no-op when clean.
        try? context.save()
        let (seedKeys, projectWeightsRaw) = await gatherSeed(
            forProject: projectId, container: context.container)
        if Task.isCancelled { return }
        let weights = effectiveWeights(projectRaw: projectWeightsRaw)
        guard !seedKeys.isEmpty else {
            // No seed → no basis to rank, so there are no visible suggestions. Clear the visible
            // (non-dismissed) leads but KEEP the researcher's dismissed markers: an empty seed is a
            // degenerate/transient state (a reorg, or a remove-then-re-add of the last collection
            // document), and wiping every ProjectLeadEntry here — as a blunt `applyLeads([])` would,
            // since its cleanup deletes any entry absent from an empty candidate set — would lose the
            // dismissals and resurface those leads as NEW once the seed repopulates.
            clearVisibleLeads(forProject: projectId, in: context)
            return
        }
        let seedSet = Set(seedKeys)
        var perSeed: [(seed: String, related: [(key: String, score: Double)])] = []
        var recordByKey: [String: CandidateRecord] = [:]   // display fields for the shown leads
        for seedKey in seedKeys.prefix(seedCap) {
            if Task.isCancelled { return }
            guard let anchor = DocumentKey(compositeString: seedKey) else { continue }
            // Leads never render the snippet, so skip the batched snippet extraction (× up to seedCap).
            let result = await RelatedDocumentsEngine.rank(
                anchor: anchor, anchorYear: nil, weights: weights,
                scopeVolumeIds: nil, limit: perSeedRelatedLimit,
                includeSnippets: false, appState: appState)
            perSeed.append((seed: seedKey,
                            related: result.rows.map { ($0.key.compositeString, $0.totalScore) }))
            for row in result.rows where recordByKey[row.key.compositeString] == nil {
                recordByKey[row.key.compositeString] = row.record
            }
        }
        if Task.isCancelled { return }
        // The keys the researcher has dismissed from Suggested Next — so the aggregator can backfill
        // their display slots with the next-best leads while keeping the dismissed ones hidden. A
        // small scoped fetch on the main context (it sees the just-dismissed state, saved above).
        let pid = projectId
        let dismissedKeys = Set(
            ((try? context.fetch(FetchDescriptor<ProjectLeadEntry>(
                predicate: #Predicate { $0.projectId == pid && $0.dismissed == true }))) ?? [])
                .map(\.documentKey))
        let candidates = ProjectLeadsAggregator.aggregate(
            perSeedRelated: perSeed, seedKeys: seedSet, dismissedKeys: dismissedKeys, limit: leadLimit)
        applyLeads(candidates, records: recordByKey, forProject: projectId, in: context)
    }

    /// Deletes a project's **visible** (non-dismissed) `ProjectLeadEntry` records, leaving its
    /// dismissed markers intact. Used for the empty-seed case, so a transiently-empty collection
    /// clears the suggestions on screen without discarding the researcher's dismissals (which would
    /// otherwise resurface as new leads once the seed repopulated).
    static func clearVisibleLeads(forProject projectId: UUID, in context: ModelContext) {
        let pid = projectId
        let visible = ((try? context.fetch(FetchDescriptor<ProjectLeadEntry>(
            predicate: #Predicate { $0.projectId == pid && $0.dismissed == false }))) ?? [])
        for entry in visible { context.delete(entry) }
    }

    /// Upserts the computed `candidates` into `ProjectLeadEntry` records for the project:
    /// updates the score/seeds of existing (non-dismissed) leads, inserts new ones (stamping
    /// `firstSurfacedAt`), and deletes leads that are no longer candidates. A dismissed lead's
    /// ranking is left untouched (so it stays hidden), and it is deleted only when it drops out
    /// of the candidate set entirely.
    static func applyLeads(_ candidates: [ProjectLeadCandidate],
                           records: [String: CandidateRecord] = [:],
                           forProject projectId: UUID,
                           in context: ModelContext,
                           now: Date = .now) {
        let pid = projectId
        let existing = ((try? context.fetch(FetchDescriptor<ProjectLeadEntry>(
            predicate: #Predicate { $0.projectId == pid }))) ?? [])
        let existingByKey = Dictionary(existing.map { ($0.documentKey, $0) },
                                       uniquingKeysWith: { first, _ in first })
        let candidateKeys = Set(candidates.map(\.key))

        for candidate in candidates {
            let record = records[candidate.key]
            if let entry = existingByKey[candidate.key] {
                if !entry.dismissed {
                    entry.aggregateScore = candidate.aggregateScore
                    entry.contributingSeedKeys = candidate.contributingSeedKeys
                    if let record {
                        entry.header = record.header
                        entry.documentNumber = record.documentNumber
                        entry.isEditorialNote = record.isEditorialNote
                    }
                }
                entry.lastComputedAt = now
            } else if let key = DocumentKey(compositeString: candidate.key) {
                context.insert(ProjectLeadEntry(
                    projectId: pid, volumeId: key.volumeId, documentId: key.documentId,
                    aggregateScore: candidate.aggregateScore,
                    contributingSeedKeys: candidate.contributingSeedKeys,
                    header: record?.header ?? "",
                    documentNumber: record?.documentNumber,
                    isEditorialNote: record?.isEditorialNote ?? false,
                    firstSurfacedAt: now, lastComputedAt: now))
            }
        }

        for entry in existing where !candidateKeys.contains(entry.documentKey) {
            context.delete(entry)
        }
    }
}
