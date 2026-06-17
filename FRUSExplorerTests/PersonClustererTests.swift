// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
@testable import FRUSExplorer

// MARK: - PersonClustererTests

/// Unit tests for the pure `PersonClusterer` (Phase 2): blocking, variant folding, and the
/// era/role guardrails that drive merge / split / candidate decisions under the under-merge bias.
struct PersonClustererTests {

    private func input(_ vol: String, _ ref: String, _ name: String,
                       role: String? = nil,
                       listStart: Int? = nil, listEnd: Int? = nil) -> PersonClusterInput {
        PersonClusterInput(volumeId: vol, ref: ref, name: name, role: role,
                           listStartYear: listStart, listEndYear: listEnd)
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
}
