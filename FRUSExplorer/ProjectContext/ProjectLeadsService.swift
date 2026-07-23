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
/// The seed is the project's **collection documents** — a curated set is higher-signal than
/// every visited document (owner decision; can widen later). For each seed the multi-axis
/// related-document engine (#308) is run, the rankings are aggregated across the seed
/// (`ProjectLeadsAggregator`), and the top leads are upserted as `ProjectLeadEntry` records —
/// preserving each lead's `firstSurfacedAt` (the "new since you last looked" anchor) and any
/// `dismissed` flag.
///
/// `@MainActor` because the engine reads `AppState`; its work is bounded and `async`, so it
/// yields between per-seed ranks rather than blocking the UI. Callers should debounce it and
/// re-run when the project's collections change.
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
        let stored = project?.leadAxisWeights
            ?? UserDefaults.standard.string(forKey: globalWeightsKey)
        let base = stored.flatMap { AxisWeights(rawValue: $0) } ?? .default
        var merged: [SimilarityAxis: Double] = [:]
        for axis in SimilarityAxis.allCases {
            merged[axis] = base.weights[axis] ?? axis.defaultWeight
        }
        return AxisWeights(weights: merged)
    }

    /// The project's seed: the `"volumeId/documentId"` keys of its collection documents,
    /// de-duplicated and sorted.
    static func collectionSeedKeys(forProject projectId: UUID, in context: ModelContext) -> [String] {
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

    /// Recomputes the project's leads end-to-end: gather the seed, rank each seed's related
    /// documents, aggregate, and upsert the top leads. Clears the leads when the seed is empty.
    static func recompute(forProject projectId: UUID, appState: AppState, in context: ModelContext) async {
        let pid = projectId
        let project = try? context.fetch(
            FetchDescriptor<Project>(predicate: #Predicate { $0.id == pid })).first
        let weights = effectiveWeights(for: project)
        let seedKeys = collectionSeedKeys(forProject: projectId, in: context)
        guard !seedKeys.isEmpty else {
            applyLeads([], forProject: projectId, in: context)
            return
        }
        let seedSet = Set(seedKeys)
        var perSeed: [(seed: String, related: [(key: String, score: Double)])] = []
        var recordByKey: [String: CandidateRecord] = [:]   // display fields for the shown leads
        for seedKey in seedKeys.prefix(seedCap) {
            guard let anchor = DocumentKey(compositeString: seedKey) else { continue }
            let result = await RelatedDocumentsEngine.rank(
                anchor: anchor, anchorYear: nil, weights: weights,
                scopeVolumeIds: nil, limit: perSeedRelatedLimit, appState: appState)
            perSeed.append((seed: seedKey,
                            related: result.rows.map { ($0.key.compositeString, $0.totalScore) }))
            for row in result.rows where recordByKey[row.key.compositeString] == nil {
                recordByKey[row.key.compositeString] = row.record
            }
        }
        let candidates = ProjectLeadsAggregator.aggregate(
            perSeedRelated: perSeed, seedKeys: seedSet, limit: leadLimit)
        applyLeads(candidates, records: recordByKey, forProject: projectId, in: context)
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
