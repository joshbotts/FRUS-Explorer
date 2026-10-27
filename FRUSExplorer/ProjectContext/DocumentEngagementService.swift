// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - DocumentEngagementService + the store

// `DocumentEngagement`, `EngagementCoverage` and `DocumentEngagementService`'s rules — what counts as
// opened, annotated and collected, over values, and the partition — moved to FRUSCoreKit for FRUS
// Explorer Light (S17b), with the method appendix whose coverage block they make:
// `FRUSCoreKit/Models/DocumentEngagement.swift`. The gatherers here read the store, map its rows to the
// kit's values and ask the kit's rules, so the app and the web edition count by one definition.
//
// Version history:
//   1.1 — Session 2026-10-25 (FRUS Explorer Light, S17b): the gatherers over models pass their rows to
//          the kit's rules as values (`openedKeys(among:forProject:)`, `annotatedKeys(among:highlights:forProject:)`,
//          `collectedKeys(among:forProject:)`); `gather` and `coverage(forCorpusKeys:project:container:isOpenedComplete:)`
//          are as they were
extension DocumentEngagementService {

    /// The documents opened in this scope (`ReadingHistoryEntry`).
    ///
    /// **Gated on research logging at the writer**, so an empty result may mean "read nothing" or
    /// "recorded nothing"; the caller pairs it with `AppState.isResearchLoggingEnabled`.
    ///
    /// - Parameters:
    ///   - projectId: The project to attribute to, or `nil` for every visit on the device.
    ///   - context: The context to fetch through.
    /// - Returns: `"volumeId/documentId"` keys.
    nonisolated static func openedKeys(forProject projectId: UUID?,
                                       in context: ModelContext) -> Set<String> {
        openedKeys(visits: (try? context.fetch(FetchDescriptor<ReadingHistoryEntry>())) ?? [],
                   forProject: projectId)
    }

    /// The same rule over visits a caller already holds.
    ///
    /// Project Home has every one of these tables live in a `@Query` already, and re-fetching them
    /// through a context to answer a question its own arrays can answer would be both wasteful and
    /// a second place for the rule to live. The context overloads delegate here, so there is one
    /// definition of what counts and the two callers cannot drift.
    ///
    /// - Parameters:
    ///   - visits: the visits to consider.
    ///   - projectId: The project to attribute to, or `nil` for every visit.
    /// - Returns: `"volumeId/documentId"` keys.
    nonisolated static func openedKeys(visits: [ReadingHistoryEntry],
                                       forProject projectId: UUID?) -> Set<String> {
        openedKeys(among: visits.map {
            Visit(volumeId: $0.volumeId, documentId: $0.documentId, projectId: $0.projectId)
        }, forProject: projectId)
    }

    /// The documents carrying a research note, or a highlight belonging to one.
    ///
    /// - Parameters:
    ///   - projectId: The project to attribute to, or `nil` for every annotation on the device.
    ///   - context: The context to fetch through.
    /// - Returns: `"volumeId/documentId"` keys.
    nonisolated static func annotatedKeys(forProject projectId: UUID?,
                                          in context: ModelContext) -> Set<String> {
        annotatedKeys(notes: (try? context.fetch(FetchDescriptor<ResearchNote>())) ?? [],
                      highlights: (try? context.fetch(FetchDescriptor<DocumentHighlight>())) ?? [],
                      forProject: projectId)
    }

    /// The same rule over notes and highlights a caller already holds. See
    /// ``openedKeys(visits:forProject:)`` for why the pure overload exists.
    ///
    /// - Parameters:
    ///   - notes: the notes to consider.
    ///   - highlights: the highlights to consider.
    ///   - projectId: The project to attribute to, or `nil` for every annotation.
    /// - Returns: `"volumeId/documentId"` keys.
    nonisolated static func annotatedKeys(notes: [ResearchNote],
                                          highlights: [DocumentHighlight],
                                          forProject projectId: UUID?) -> Set<String> {
        // The scope's notes alone are read beyond their projects, as before the rule moved.
        annotatedKeys(among: notes.compactMap { note in
            let projectIds = note.projectIds
            guard isInScope(projectIds, forProject: projectId) else { return nil }
            return Note(id: note.id, volumeId: note.volumeId, documentId: note.documentId,
                        projectIds: projectIds)
        }, highlights: highlights.map {
            Highlight(volumeId: $0.volumeId, documentId: $0.documentId, noteId: $0.noteId)
        }, forProject: projectId)
    }

    /// The documents that are entries in a collection.
    ///
    /// Not shared with `ProjectLeadsService.collectionSeedKeys`, which answers the same question
    /// for a **mandatory** project and unions its answer into a seed. The shared thing between them
    /// is the key format, `ProjectEngagedDocuments.key(_:_:)`'s, which the kit's rule writes the same.
    ///
    /// - Parameters:
    ///   - projectId: The project to attribute to, or `nil` for every collection on the device.
    ///   - context: The context to fetch through.
    /// - Returns: `"volumeId/documentId"` keys.
    nonisolated static func collectedKeys(forProject projectId: UUID?,
                                          in context: ModelContext) -> Set<String> {
        collectedKeys(collections: (try? context.fetch(FetchDescriptor<Collection>())) ?? [],
                      forProject: projectId)
    }

    /// The same rule over collections a caller already holds. See
    /// ``openedKeys(visits:forProject:)`` for why the pure overload exists.
    ///
    /// - Parameters:
    ///   - collections: the collections to consider.
    ///   - projectId: The project to attribute to, or `nil` for every collection.
    /// - Returns: `"volumeId/documentId"` keys.
    nonisolated static func collectedKeys(collections allCollections: [Collection],
                                          forProject projectId: UUID?) -> Set<String> {
        // The scope's collections alone are read beyond their projects, as before the rule moved:
        // reading one's entries faults its `documentEntries` relationship.
        collectedKeys(among: allCollections.compactMap { collection in
            let projectIds = collection.projectIds
            guard isInScope(projectIds, forProject: projectId) else { return nil }
            return CollectionDocuments(projectIds: projectIds,
                                       entries: (collection.documentEntries ?? []).map {
                                           .init(kind: $0.kind, volumeId: $0.volumeId, documentId: $0.documentId)
                                       })
        }, forProject: projectId)
    }

    /// Runs all three gatherers against one context.
    ///
    /// The single definition of "every kind of engagement": `coverage(forCorpusKeys:…)` calls it
    /// too, so the one-corpus and many-corpus paths cannot come to disagree about what counts.
    ///
    /// - Parameters:
    ///   - projectId: The project to attribute to, or `nil` for the whole device.
    ///   - context: The context to fetch through.
    /// - Returns: The three key sets.
    nonisolated static func gather(forProject projectId: UUID?,
                                   in context: ModelContext) -> GatheredKeys {
        GatheredKeys(opened: openedKeys(forProject: projectId, in: context),
                     annotated: annotatedKeys(forProject: projectId, in: context),
                     collected: collectedKeys(forProject: projectId, in: context))
    }

    /// All three kinds over model arrays a caller already holds — the Project Home path.
    ///
    /// - Parameters:
    ///   - collections: the collections to consider.
    ///   - notes: the notes to consider.
    ///   - highlights: the highlights to consider.
    ///   - visits: the visits to consider.
    ///   - projectId: The project to attribute to, or `nil` for the whole device.
    /// - Returns: The three key sets.
    nonisolated static func gather(collections: [Collection],
                                   notes: [ResearchNote],
                                   highlights: [DocumentHighlight],
                                   visits: [ReadingHistoryEntry],
                                   forProject projectId: UUID?) -> GatheredKeys {
        GatheredKeys(opened: openedKeys(visits: visits, forProject: projectId),
                     annotated: annotatedKeys(notes: notes, highlights: highlights,
                                              forProject: projectId),
                     collected: collectedKeys(collections: collections, forProject: projectId))
    }

    /// Gathers all three kinds off the main actor and partitions `corpusKeys` by them.
    ///
    /// - Parameters:
    ///   - corpusKeys: The corpus's document keys.
    ///   - projectId: The project to attribute to, or `nil` for the whole device.
    ///   - container: The container a private background context is opened on.
    ///   - isOpenedComplete: Whether research logging is on. **Defaulted to the live gate**, so a
    ///     caller gets the caveat right by saying nothing; the suite passes it explicitly to drive
    ///     both branches without mutating `UserDefaults.standard`. A `UserDefaults` parameter would
    ///     be the more obvious shape and cannot be used: it is not `Sendable`, and this signature
    ///     crosses an actor boundary.
    /// - Returns: The partition.
    nonisolated static func coverage(forCorpusKeys corpusKeys: [String],
                                     project projectId: UUID?,
                                     container: ModelContainer,
                                     isOpenedComplete: Bool = AppState.isResearchLoggingEnabled)
    async -> EngagementCoverage {
        await Task.detached {
            let context = ModelContext(container)
            return partition(corpusKeys: corpusKeys,
                             keys: gather(forProject: projectId, in: context),
                             isOpenedComplete: isOpenedComplete)
        }.value
    }
}
