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

// MARK: - PersonClustererTests

/// Unit tests for the pure `PersonClusterer` (Phase 2): blocking, variant folding, and the
/// era/role guardrails that drive merge / split / candidate decisions under the under-merge bias.
struct PersonClustererTests {

    private func input(_ vol: String, _ ref: String, _ name: String,
                       role: String? = nil,
                       listStart: Int? = nil, listEnd: Int? = nil,
                       authorityId: Int? = nil) -> PersonClusterInput {
        PersonClusterInput(volumeId: vol, ref: ref, name: name, role: role,
                           listStartYear: listStart, listEndYear: listEnd,
                           authorityId: authorityId)
    }

    // MARK: Exact-name behaviour

    @Test("Exact name with no era data merges (preserves Phase 0 behaviour)")
    func exactNameNoEraMerges() {
        let out = PersonClusterer.cluster([
            input("v1", "p_k", "Kissinger, Henry A."),
            input("v2", "p_z", "Kissinger, Henry A.")
        ])
        #expect(out.clusters.count == 1)
        #expect(out.clusters.first?.count == 2)
        #expect(out.candidates.isEmpty)
    }

    @Test("Exact name but eras far apart splits into two clusters (de-conflation)")
    func exactNameDisjointEraSplits() {
        let out = PersonClusterer.cluster([
            input("v1", "p1", "Smith, John", listStart: 1850, listEnd: 1855),
            input("v2", "p2", "Smith, John", listStart: 1960, listEnd: 1965)
        ])
        #expect(out.clusters.count == 2)
        #expect(out.candidates.isEmpty, "confident they are different people — not a suggestion")
    }

    @Test("Exact name with overlapping eras merges")
    func exactNameOverlappingEraMerges() {
        let out = PersonClusterer.cluster([
            input("v1", "p1", "Smith, John", listStart: 1948, listEnd: 1952),
            input("v2", "p2", "Smith, John", listStart: 1950, listEnd: 1955)
        ])
        #expect(out.clusters.count == 1)
    }

    // MARK: Variant-name behaviour

    @Test("Name variant with unknown era stays split and is recorded as a candidate")
    func variantUnknownEraCandidate() {
        let out = PersonClusterer.cluster([
            input("v1", "p1", "Kissinger, Henry A."),
            input("v2", "p2", "Kissinger, Henry")
        ])
        #expect(out.clusters.count == 2, "under-merge bias: do not auto-merge an uncertain variant")
        #expect(out.candidates.count == 1)
        #expect(out.candidates.first?.reason.contains("variant") == true)
    }

    @Test("Name variant with overlapping era is auto-merged")
    func variantOverlappingEraMerges() {
        let out = PersonClusterer.cluster([
            input("v1", "p1", "Kissinger, Henry A.", listStart: 1969, listEnd: 1977),
            input("v2", "p2", "Kissinger, Henry", listStart: 1973, listEnd: 1975)
        ])
        #expect(out.clusters.count == 1)
        #expect(out.candidates.isEmpty)
    }

    @Test("Name variant with overlapping era but conflicting roles is held as a candidate")
    func variantOverlappingEraRoleConflictCandidate() {
        let out = PersonClusterer.cluster([
            input("v1", "p1", "Bohlen, Charles", role: "Ambassador to France", listStart: 1962, listEnd: 1968),
            input("v2", "p2", "Bohlen, C.", role: "Petroleum engineer", listStart: 1963, listEnd: 1965)
        ])
        #expect(out.clusters.count == 2)
        #expect(out.candidates.count == 1)
        #expect(out.candidates.first?.reason.contains("role differs") == true)
    }

    // MARK: Non-matches

    @Test("Different given names under the same surname do not merge and are not candidates")
    func incompatibleGivenNames() {
        let out = PersonClusterer.cluster([
            input("v1", "p1", "Smith, Henry"),
            input("v2", "p2", "Smith, Harold")
        ])
        #expect(out.clusters.count == 2)
        #expect(out.candidates.isEmpty)
    }

    @Test("Different surnames are never compared (separate blocks)")
    func differentSurnames() {
        let out = PersonClusterer.cluster([
            input("v1", "p1", "Kissinger, Henry"),
            input("v2", "p2", "Nixon, Richard")
        ])
        #expect(out.clusters.count == 2)
        #expect(out.candidates.isEmpty)
    }

    @Test("Empty input yields empty output")
    func emptyInput() {
        let out = PersonClusterer.cluster([])
        #expect(out.clusters.isEmpty)
        #expect(out.candidates.isEmpty)
    }

    // MARK: Normalisation

    @Test("Diacritics, suffixes, and honorifics fold so variants share a block and merge")
    func normalisationFolding() {
        // "Kissinger, Henry A., Jr." vs "Kissinger, Gen. Henry Alfred" → same surname/initial block;
        // given tokens [henry, a(lfred)] are compatible → variant; overlapping era → merge.
        let out = PersonClusterer.cluster([
            input("v1", "p1", "Kissinger, Henry A., Jr.", listStart: 1970, listEnd: 1974),
            input("v2", "p2", "Kissinger, Gen. Henry Alfred", listStart: 1971, listEnd: 1975)
        ])
        #expect(out.clusters.count == 1, "suffix/title folding + initial-vs-name compatibility merge")
    }

    @Test("normalize splits surname/given and folds diacritics + case")
    func normalizeSplitsName() {
        let n = PersonClusterer.normalize("Müller, José A.")
        #expect(n.surname == "muller")
        #expect(n.given == ["jose", "a"])
        #expect(n.blockingKey == "muller|j")
    }

    @Test("nameRelation classifies exact, variant, and incompatible given names")
    func nameRelationClassification() {
        #expect(PersonClusterer.nameRelation(["henry", "a"], ["henry", "a"]) == .exact)
        #expect(PersonClusterer.nameRelation(["henry", "a"], ["henry"]) == .variant)
        #expect(PersonClusterer.nameRelation(["henry"], ["harold"]) == .incompatible)
    }

    // MARK: User corrections (Phase 3)

    private func key(_ vol: String, _ ref: String) -> PersonClusterer.MemberKey {
        PersonClusterer.MemberKey(volumeId: vol, ref: ref)
    }

    @Test("must-link merges two records the era guardrail would otherwise split")
    func mustLinkOverridesEraSplit() {
        let out = PersonClusterer.cluster(
            [input("v1", "p1", "Smith, John", listStart: 1850, listEnd: 1855),
             input("v2", "p2", "Smith, John", listStart: 1960, listEnd: 1965)],
            mustLink: [(key("v1", "p1"), key("v2", "p2"))])
        #expect(out.clusters.count == 1, "the user's merge overrides the era guardrail")
    }

    @Test("must-link merges across different surname blocks")
    func mustLinkAcrossBlocks() {
        let out = PersonClusterer.cluster(
            [input("v1", "p1", "Clay, Lucius"),
             input("v2", "p2", "Clayton, William")],   // different surname → different block
            mustLink: [(key("v1", "p1"), key("v2", "p2"))])
        #expect(out.clusters.count == 1)
    }

    @Test("detach pulls a member out of its algorithmic cluster into its own identity")
    func detachSplitsCluster() {
        let people = [input("v1", "p1", "Kissinger, Henry A."),
                      input("v2", "p2", "Kissinger, Henry A."),
                      input("v3", "p3", "Kissinger, Henry A.")]
        #expect(PersonClusterer.cluster(people).clusters.count == 1)
        let out = PersonClusterer.cluster(people, detach: [key("v3", "p3")])
        #expect(out.clusters.count == 2)
        #expect(out.clusters.contains { $0.count == 2 })
        #expect(out.clusters.contains { $0.count == 1 })
    }

    // MARK: Authority crosswalk (Phase 5)

    @Test("authority crosswalk merges members sharing a canonical id, across surname/era blocks")
    func authoritySameIdMerges() {
        // Different name strings and a disjoint listed era — the heuristic would never auto-merge —
        // but the shared canonical id unites them.
        let out = PersonClusterer.cluster([
            input("v1", "p1", "Aaron, David L.", listStart: 1977, listEnd: 1981, authorityId: 100001),
            input("v2", "p2", "Aaron, David", authorityId: 100001),
            input("v3", "p3", "Aaron, David Laurence", listStart: 1969, listEnd: 1972, authorityId: 100001)
        ])
        #expect(out.clusters.count == 1)
        #expect(out.clusters.first?.count == 3)
    }

    @Test("authority crosswalk never merges different canonical ids, even with identical names")
    func authorityDifferentIdNeverMerges() {
        let out = PersonClusterer.cluster([
            input("v1", "p1", "Smith, John", authorityId: 1),
            input("v2", "p2", "Smith, John", authorityId: 2)
        ])
        #expect(out.clusters.count == 2, "authority splits a same-name conflation the heuristic would merge")
        #expect(out.candidates.isEmpty)
    }

    @Test("a user detach overrides an authority grouping")
    func userDetachOverridesAuthority() {
        let out = PersonClusterer.cluster([
            input("v1", "p1", "Aaron, David", authorityId: 100001),
            input("v2", "p2", "Aaron, David", authorityId: 100001)
        ], detach: [key("v2", "p2")])
        #expect(out.clusters.count == 2, "the user's split wins over the authority crosswalk")
    }

    @Test("detach then must-link can move a member to a different identity")
    func detachThenMustLink() {
        // a,b merge; c,d merge. Detach b from {a,b}, then must-link b with c → {a}, {b,c,d}.
        let people = [input("v1", "p1", "Adams, John"),
                      input("v2", "p2", "Adams, John"),
                      input("v3", "p3", "Baker, Howard"),
                      input("v4", "p4", "Baker, Howard")]
        let out = PersonClusterer.cluster(people,
                                          mustLink: [(key("v2", "p2"), key("v3", "p3"))],
                                          detach: [key("v2", "p2")])
        // {a} alone, and {b,c,d} merged.
        #expect(out.clusters.count == 2)
        #expect(out.clusters.contains { $0.count == 1 })
        #expect(out.clusters.contains { $0.count == 3 })
    }
}

// MARK: - PersonClusterOverrideStoreTests

/// Tests the SwiftData store for person-cluster corrections (Phase 3), backed by an in-memory
/// container so no CloudKit/disk is touched.
@MainActor
struct PersonClusterOverrideStoreTests {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: PersonClusterOverride.self, configurations: config)
        return ModelContext(container)
    }

    @Test("merge dedups unordered pairs and rejects a self-merge")
    func mergeDedup() throws {
        let ctx = try makeContext()
        #expect(PersonClusterOverrideStore.merge(("v1", "p1"), ("v2", "p2"), context: ctx) != nil)
        #expect(PersonClusterOverrideStore.merge(("v1", "p1"), ("v2", "p2"), context: ctx) == nil)
        #expect(PersonClusterOverrideStore.merge(("v2", "p2"), ("v1", "p1"), context: ctx) == nil,
                "reversed orientation is the same unordered pair")
        #expect(PersonClusterOverrideStore.merge(("v1", "p1"), ("v1", "p1"), context: ctx) == nil,
                "a self-merge is rejected")
        #expect(PersonClusterOverrideStore.fetchAll(context: ctx).count == 1)
    }

    @Test("split dedups per member; snapshot maps both kinds")
    func splitAndSnapshot() throws {
        let ctx = try makeContext()
        #expect(PersonClusterOverrideStore.split(("v1", "p1"), context: ctx) != nil)
        #expect(PersonClusterOverrideStore.split(("v1", "p1"), context: ctx) == nil)
        PersonClusterOverrideStore.merge(("v1", "p1"), ("v2", "p2"), context: ctx)

        let snap = PersonClusterOverrideStore.snapshot(context: ctx)
        #expect(snap.count == 2)
        #expect(snap.contains { $0.kind == .split && $0.volumeIdA == "v1" && $0.refA == "p1" })
        #expect(snap.contains { $0.kind == .merge && $0.volumeIdB == "v2" && $0.refB == "p2" })
    }

    @Test("remove deletes an override")
    func removeOverride() throws {
        let ctx = try makeContext()
        let override = try #require(PersonClusterOverrideStore.split(("v1", "p1"), context: ctx))
        PersonClusterOverrideStore.remove(override, context: ctx)
        #expect(PersonClusterOverrideStore.fetchAll(context: ctx).isEmpty)
    }
}
