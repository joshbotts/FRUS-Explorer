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

// MARK: - ProjectLeadsAggregatorTests

/// Tests for the pure lead aggregation (#377 Phase 3).
struct ProjectLeadsAggregatorTests {

    @Test("aggregate sums relatedness across seeds, drops seeds, ranks + caps")
    func aggregatesLeads() {
        let perSeed: [(seed: String, related: [(key: String, score: Double)])] = [
            ("v/s1", [("v/a", 1.0), ("v/b", 0.5), ("v/s2", 9.0)]),  // s2 is a seed → excluded
            ("v/s2", [("v/a", 2.0), ("v/c", 0.3)]),
        ]
        let seeds: Set<String> = ["v/s1", "v/s2"]
        let leads = ProjectLeadsAggregator.aggregate(perSeedRelated: perSeed, seedKeys: seeds, limit: 10)

        // a: 1.0 + 2.0 = 3.0 (recurs across both seeds) leads; then b (0.5), c (0.3). s2 dropped.
        #expect(leads.map(\.key) == ["v/a", "v/b", "v/c"])
        #expect(leads[0].aggregateScore == 3.0)
        #expect(leads[0].contributingSeedKeys == ["v/s1", "v/s2"])
        #expect(!leads.contains { $0.key == "v/s2" })

        // limit caps the result.
        #expect(ProjectLeadsAggregator.aggregate(
            perSeedRelated: perSeed, seedKeys: seeds, limit: 1).count == 1)
    }

    @Test("aggregate: a dismissed lead frees its slot (backfill) yet stays retained + hidden")
    func aggregateBackfillsDismissed() {
        let perSeed: [(seed: String, related: [(key: String, score: Double)])] = [
            ("v/s", [("v/a", 4.0), ("v/b", 3.0), ("v/c", 2.0), ("v/d", 1.0)]),
        ]
        let seeds: Set<String> = ["v/s"]

        // No dismissals: the top-2 visible leads are a, b.
        #expect(ProjectLeadsAggregator.aggregate(
            perSeedRelated: perSeed, seedKeys: seeds, limit: 2).map(\.key) == ["v/a", "v/b"])

        // Dismiss 'a': its freed slot backfills with the next-best 'c' (b, c visible), and 'a' is
        // still returned (at the end) so `applyLeads` keeps it hidden — it must not resurface.
        let withDismiss = ProjectLeadsAggregator.aggregate(
            perSeedRelated: perSeed, seedKeys: seeds, dismissedKeys: ["v/a"], limit: 2)
        #expect(withDismiss.map(\.key) == ["v/b", "v/c", "v/a"])
    }
}

// MARK: - ProjectLeadsServiceTests

/// Tests for the seed-gathering and upsert persistence (#377 Phase 3). The `recompute` engine
/// path needs an indexed corpus + `AppState`, so it is exercised on-device rather than here.
@MainActor
struct ProjectLeadsServiceTests {

    @Test("collectionSeedKeys returns the project's collection document keys only")
    func collectionSeed() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        let project = UUID()

        let c = Collection(name: "C", projectIds: [project])
        context.insert(c)
        for (i, doc) in [("v1", "d1"), ("v1", "d2")].enumerated() {
            let e = CollectionEntry(collectionId: c.id, documentId: doc.1, volumeId: doc.0, sortOrder: i)
            e.collection = c
            context.insert(e)
        }
        let heading = CollectionEntry(collectionId: c.id, documentId: "", volumeId: "", sortOrder: 2)
        heading.entryKind = .heading
        heading.collection = c
        context.insert(heading)

        // A different project's collection must not leak in.
        let other = Collection(name: "O", projectIds: [UUID()])
        context.insert(other)
        let eo = CollectionEntry(collectionId: other.id, documentId: "d9", volumeId: "v9", sortOrder: 0)
        eo.collection = other
        context.insert(eo)
        try context.save()

        #expect(ProjectLeadsService.collectionSeedKeys(forProject: project, in: context) == ["v1/d1", "v1/d2"])
    }

    @Test("effectiveWeights: project override beats global preference beats default; missing axes default")
    func effectiveWeightsResolution() {
        let defaults = UserDefaults.standard
        let key = ProjectLeadsService.globalWeightsKey
        let saved = defaults.string(forKey: key)
        defer { if let saved { defaults.set(saved, forKey: key) } else { defaults.removeObject(forKey: key) } }

        // No project + no global preference → app defaults.
        defaults.removeObject(forKey: key)
        let appDefault = ProjectLeadsService.effectiveWeights(for: nil)
        #expect(appDefault[.archivalProvenance] == 1.0)
        #expect(appDefault[.sharedPersons] == 0.7)

        // Global preference (a partial string) → its explicit axes win; axes absent from the
        // string fall back to their default (the forward-compat merge for future axes).
        defaults.set("archivalProvenance:0.2", forKey: key)
        let global = ProjectLeadsService.effectiveWeights(for: nil)
        #expect(global[.archivalProvenance] == 0.2)
        #expect(global[.sharedPersons] == 0.7)

        // A project's own weights beat the global preference.
        let project = Project(name: "P")
        project.leadAxisWeights = "crossReference:0.9"
        let projectW = ProjectLeadsService.effectiveWeights(for: project)
        #expect(projectW[.crossReference] == 0.9)
        #expect(projectW[.archivalProvenance] == 1.0)   // not set by the project → default, not global 0.2
    }

    @Test("tuning panel round-trip: drafted weights → rawValue → effectiveWeights (unset axes default)")
    func perProjectWeightRoundTrip() {
        // Mirror the Project Home tuning panel's commit path: start from the effective defaults,
        // tweak two axes, persist as the raw string, and resolve back.
        var draft = AxisWeights.default
        draft[.crossReference] = 0.2
        draft[.dateProximity] = 0.9
        let project = Project(name: "P")
        project.leadAxisWeights = draft.rawValue

        let resolved = ProjectLeadsService.effectiveWeights(for: project)
        #expect(resolved[.crossReference] == 0.2)
        #expect(resolved[.dateProximity] == 0.9)
        // The panel serializes every axis (`rawValue` iterates allCases), so the axes the researcher
        // left alone are persisted at — and resolve back to — their default value.
        // (The partial-string forward-compat merge, where an axis is *absent* from the raw string, is
        // covered separately by `effectiveWeightsResolution`.)
        #expect(resolved[.archivalProvenance] == 1.0)
        #expect(resolved[.sharedPersons] == 0.7)
    }

    @Test("gatherSeed returns the project's seed keys + weight string off a background context")
    func gatherSeedOffMain() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        let project = Project(name: "P")
        project.leadAxisWeights = "crossReference:0.9"
        context.insert(project)

        let c = Collection(name: "C", projectIds: [project.id])
        context.insert(c)
        for (i, doc) in [("v1", "d1"), ("v1", "d2")].enumerated() {
            let e = CollectionEntry(collectionId: c.id, documentId: doc.1, volumeId: doc.0, sortOrder: i)
            e.collection = c
            context.insert(e)
        }
        try context.save()

        // The seed + raw weight string are read on a fresh background context (freeze lesson).
        let (seedKeys, raw) = await ProjectLeadsService.gatherSeed(
            forProject: project.id, container: container)
        #expect(seedKeys == ["v1/d1", "v1/d2"])
        #expect(raw == "crossReference:0.9")
    }

    @Test("applyLeads captures the document's display fields from the record map")
    func applyLeadsDisplayFields() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        let project = UUID()

        let records = ["v/a": CandidateRecord(
            header: "The Memo", dateline: "Washington, 1964", documentNumber: "42", isEditorialNote: true)]
        ProjectLeadsService.applyLeads(
            [ProjectLeadCandidate(key: "v/a", aggregateScore: 1.0, contributingSeedKeys: ["v/s"])],
            records: records, forProject: project, in: context)
        try context.save()

        let entry = try #require(try context.fetch(FetchDescriptor<ProjectLeadEntry>()).first)
        #expect(entry.header == "The Memo")
        #expect(entry.documentNumber == "42")
        #expect(entry.isEditorialNote == true)
    }

    @Test("applyLeads upserts: preserves firstSurfacedAt + dismissed, deletes stale")
    func applyLeadsUpsert() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        let project = UUID()

        let t0 = Date(timeIntervalSince1970: 1000)
        ProjectLeadsService.applyLeads([
            ProjectLeadCandidate(key: "v/a", aggregateScore: 3.0, contributingSeedKeys: ["v/s1"]),
            ProjectLeadCandidate(key: "v/b", aggregateScore: 2.0, contributingSeedKeys: ["v/s1"]),
        ], forProject: project, in: context, now: t0)
        try context.save()

        var entries = try context.fetch(FetchDescriptor<ProjectLeadEntry>())
        #expect(entries.count == 2)

        // Dismiss 'a'.
        try #require(entries.first { $0.documentKey == "v/a" }).dismissed = true
        try context.save()

        // Re-apply: 'a' still a candidate (with a new score), 'b' dropped, 'c' new.
        let t1 = Date(timeIntervalSince1970: 2000)
        ProjectLeadsService.applyLeads([
            ProjectLeadCandidate(key: "v/a", aggregateScore: 99.0, contributingSeedKeys: ["v/s2"]),
            ProjectLeadCandidate(key: "v/c", aggregateScore: 1.0, contributingSeedKeys: ["v/s1"]),
        ], forProject: project, in: context, now: t1)
        try context.save()

        entries = try context.fetch(FetchDescriptor<ProjectLeadEntry>())
        let byKey = Dictionary(uniqueKeysWithValues: entries.map { ($0.documentKey, $0) })

        // 'b' dropped (no longer a candidate).
        #expect(byKey["v/b"] == nil)
        // 'a' dismissed → score NOT re-ranked (stays 3.0), firstSurfacedAt preserved, still dismissed.
        #expect(byKey["v/a"]?.aggregateScore == 3.0)
        #expect(byKey["v/a"]?.dismissed == true)
        #expect(byKey["v/a"]?.firstSurfacedAt == t0)
        // 'c' new → stamped at t1.
        #expect(byKey["v/c"]?.aggregateScore == 1.0)
        #expect(byKey["v/c"]?.firstSurfacedAt == t1)
    }
}
