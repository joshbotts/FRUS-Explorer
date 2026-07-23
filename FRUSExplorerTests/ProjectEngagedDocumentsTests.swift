// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
import SwiftData
@testable import FRUSExplorer

/// Tests for `ProjectEngagedDocuments` — the engaged-document assembly behind the
/// Project **History** search scope (#377 Phase 2).
@MainActor
struct ProjectEngagedDocumentsTests {

    /// Collects a project's engaged documents from its collections, doc-anchored notes,
    /// and visits; de-duplicates across sources; skips non-document records; and never
    /// leaks another project's activity.
    @Test("keys(forProject:) unions collections + notes + visits, dedups, scopes to project")
    func engagedKeysUnionAndScope() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)

        let projectA = UUID()
        let projectB = UUID()

        // Project A collection: two document entries + one heading (blank ids, skipped).
        let cA = Collection(name: "A Collection", projectIds: [projectA])
        context.insert(cA)
        for (i, doc) in [("v1", "d1"), ("v1", "d2")].enumerated() {
            let e = CollectionEntry(collectionId: cA.id, documentId: doc.1, volumeId: doc.0, sortOrder: i)
            e.collection = cA
            context.insert(e)
        }
        let heading = CollectionEntry(collectionId: cA.id, documentId: "", volumeId: "", sortOrder: 2)
        heading.entryKind = .heading
        heading.collection = cA
        context.insert(heading)

        // Project B collection (must not leak into A's set).
        let cB = Collection(name: "B Collection", projectIds: [projectB])
        context.insert(cB)
        let eB = CollectionEntry(collectionId: cB.id, documentId: "d9", volumeId: "v2", sortOrder: 0)
        eB.collection = cB
        context.insert(eB)

        // Notes: one doc-anchored in A (contributes), one project-level in A (skipped),
        // one in B (excluded).
        context.insert(ResearchNote(documentId: "d3", volumeId: "v1", projectIds: [projectA]))
        context.insert(ResearchNote(documentId: "", volumeId: "", projectIds: [projectA]))
        context.insert(ResearchNote(documentId: "d99", volumeId: "v9", projectIds: [projectB]))

        // Visits: one duplicates a collected doc (dedup), one is new, one is in B.
        context.insert(ReadingHistoryEntry(documentId: "d1", volumeId: "v1", projectId: projectA))
        context.insert(ReadingHistoryEntry(documentId: "d4", volumeId: "v1", projectId: projectA))
        context.insert(ReadingHistoryEntry(documentId: "d88", volumeId: "v8", projectId: projectB))

        try context.save()

        let keysA = ProjectEngagedDocuments.keys(forProject: projectA, in: context)
        #expect(keysA == ["v1/d1", "v1/d2", "v1/d3", "v1/d4"])
        // d1 appears in both a collection and a visit but only once (dedup).
        #expect(keysA.count == 4)
        // No project-B activity leaks in.
        #expect(!keysA.contains("v2/d9"))
        #expect(!keysA.contains("v9/d99"))
        #expect(!keysA.contains("v8/d88"))

        let keysB = ProjectEngagedDocuments.keys(forProject: projectB, in: context)
        #expect(keysB == ["v2/d9", "v9/d99", "v8/d88"])
    }

    /// A project with no tagged activity has an empty engaged set (History scope then
    /// gates to nothing, per the `documentIds` contract).
    @Test("keys(forProject:) is empty for a project with no activity")
    func engagedKeysEmptyForIdleProject() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)

        // Activity exists, but for a *different* project.
        let other = UUID()
        context.insert(ReadingHistoryEntry(documentId: "d1", volumeId: "v1", projectId: other))
        try context.save()

        let keys = ProjectEngagedDocuments.keys(forProject: UUID(), in: context)
        #expect(keys.isEmpty)
    }

    /// The off-main-thread variant (used by the search UIs so a large library can't freeze
    /// the panel) returns the same engaged set as the synchronous main-context path.
    @Test("keys(forProject:container:) computes the same set off the main thread")
    func engagedKeysBackgroundVariantMatches() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)

        let project = UUID()
        let c = Collection(name: "C", projectIds: [project])
        context.insert(c)
        let e = CollectionEntry(collectionId: c.id, documentId: "d1", volumeId: "v1", sortOrder: 0)
        e.collection = c
        context.insert(e)
        context.insert(ResearchNote(documentId: "d2", volumeId: "v1", projectIds: [project]))
        context.insert(ReadingHistoryEntry(documentId: "d3", volumeId: "v1", projectId: project))
        try context.save()

        let sync = ProjectEngagedDocuments.keys(forProject: project, in: context)
        let async = await ProjectEngagedDocuments.keys(forProject: project, container: container)
        #expect(sync == ["v1/d1", "v1/d2", "v1/d3"])
        #expect(async == sync)

        // engagedVolumeIds derives the distinct volumes from those keys.
        let volumes = await ProjectEngagedDocuments.engagedVolumeIds(forProject: project, container: container)
        #expect(volumes == ["v1"])
    }
}
