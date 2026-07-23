// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - ProjectSearchScope

/// How an active project constrains a search (#377 Phase 2).
///
/// The search filter panel exposes this as a picker, shown only when a project is
/// active *and* has engaged at least one document. It grows in Phase 2b with a
/// `.focus` (discovery) mode; for now it is a two-way choice.
///
/// Version history:
///   1.0 — #377 Phase 2a: `.off` / `.history`
enum ProjectSearchScope: String, CaseIterable, Identifiable, Sendable {
    /// Search the whole indexed corpus; the active project does not constrain results.
    case off
    /// Restrict results to the documents the active project has engaged — its
    /// collected, annotated, and visited documents (the "History / recall" mode).
    case history

    /// Stable identity for `Picker` selection.
    var id: String { rawValue }
}

// MARK: - ProjectEngagedDocuments

/// Assembles the set of documents a project has **engaged** — the union of every
/// document in its collections, every document it has an anchored note on, and every
/// document visited while it was the active project (#377 Phase 2).
///
/// This engaged set is the recall corpus for the search **History** scope
/// (`ProjectSearchScope.history`) and, later, the exclusion set for discovery's
/// "only new" toggle (Phase 2b). Keys are `"volumeId/documentId"` — the same identity
/// the FTS5 `documentIds` filter matches on (see `IndexingPipeline.filterConditions`).
enum ProjectEngagedDocuments {

    /// A stable `"volumeId/documentId"` key.
    static func key(_ volumeId: String, _ documentId: String) -> String {
        "\(volumeId)/\(documentId)"
    }

    /// Pure extraction: the union of `"volumeId/documentId"` keys across a project's
    /// already-filtered collections, notes, and visits.
    ///
    /// Records that are not anchored to a specific document — project-level notes, and
    /// `heading`/`prose` collection entries — carry blank ids and are skipped, so the
    /// set contains only real documents.
    ///
    /// `nonisolated` and reads SwiftData `@Model` relationships
    /// (`Collection.documentEntries`), so it must run on the actor/thread that owns the
    /// passed model objects — either the main context (via `keys(forProject:in:)`) or a
    /// private background context (via the async `keys(forProject:container:)`). Never
    /// pass it objects fetched on a different context.
    nonisolated static func keys(collections: [Collection],
                                 notes: [ResearchNote],
                                 visits: [ReadingHistoryEntry]) -> Set<String> {
        var result = Set<String>()
        for note in notes where !note.volumeId.isEmpty && !note.documentId.isEmpty {
            result.insert(key(note.volumeId, note.documentId))
        }
        for visit in visits where !visit.volumeId.isEmpty && !visit.documentId.isEmpty {
            result.insert(key(visit.volumeId, visit.documentId))
        }
        for collection in collections {
            for entry in collection.documentEntries ?? []
            where entry.kind == CollectionEntryKind.document.rawValue
                && !entry.volumeId.isEmpty && !entry.documentId.isEmpty {
                result.insert(key(entry.volumeId, entry.documentId))
            }
        }
        return result
    }

    /// Fetches the project's collections/notes/visits from `context` and extracts their
    /// engaged document keys. `nonisolated` so it can run on either the main context or a
    /// background context; callers must invoke it on the context's own actor/thread.
    ///
    /// Collections and notes are filtered on their `projectIds` **array** in memory —
    /// SwiftData array-membership (`.contains`) predicates are unreliable, so the
    /// dashboard and this helper both fetch-then-filter. Visits carry a **scalar**
    /// `projectId`, which filters reliably in the fetch predicate.
    nonisolated static func computeKeys(forProject projectId: UUID,
                                        in context: ModelContext) -> Set<String> {
        let pid = projectId
        let notes = ((try? context.fetch(FetchDescriptor<ResearchNote>())) ?? [])
            .filter { $0.projectIds.contains(pid) }
        let collections = ((try? context.fetch(FetchDescriptor<Collection>())) ?? [])
            .filter { $0.projectIds.contains(pid) }
        let visits = (try? context.fetch(FetchDescriptor<ReadingHistoryEntry>(
            predicate: #Predicate { $0.projectId == pid }
        ))) ?? []
        return keys(collections: collections, notes: notes, visits: visits)
    }

    /// Main-context fetch convenience (synchronous). Prefer the async
    /// `keys(forProject:container:)` on UI paths that must not block the main thread on a
    /// large library.
    @MainActor
    static func keys(forProject projectId: UUID, in context: ModelContext) -> Set<String> {
        computeKeys(forProject: projectId, in: context)
    }

    /// Off-main-thread fetch (#377 Phase 2a follow-up): computes the engaged key set on a
    /// **private background `ModelContext`** so a large library can't freeze the UI. Only
    /// the `Sendable` `Set<String>` crosses back to the caller — no `@Model` objects
    /// escape the background context.
    static func keys(forProject projectId: UUID, container: ModelContainer) async -> Set<String> {
        await Task.detached(priority: .userInitiated) {
            let context = ModelContext(container)
            return computeKeys(forProject: projectId, in: context)
        }.value
    }

    /// The distinct volumes the project engages, computed off the main thread (#377 Phase 2b,
    /// the focus-subject suggestion seed). Derived from the engaged doc keys — a
    /// `"volumeId/documentId"` key's volume is the segment before the first `/`.
    static func engagedVolumeIds(forProject projectId: UUID, container: ModelContainer) async -> Set<String> {
        let keys = await keys(forProject: projectId, container: container)
        return Set(keys.compactMap { $0.split(separator: "/", maxSplits: 1).first.map(String.init) })
    }
}
