// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import VolumeSubjectProfilesGeneratorCore

// MARK: - VolumeSubjectProfilesGeneratorTests

/// Unit tests for the volume-subject-profiles aggregation: genericity exclusion, the
/// per-volume minimum-count floor, TF-IDF ranking, top-N truncation, vocabulary
/// factoring, and byte-stable determinism.
///
/// Version history:
///   1.0 — Session 9: initial implementation
struct VolumeSubjectProfilesGeneratorTests {

    // MARK: Fixtures

    /// A constructed input over three volumes and a handful of subjects, shaped so the
    /// scoring outcomes are predictable:
    /// - `generic` appears in (almost) every document of every volume → must be dropped
    ///   by the genericity threshold.
    /// - `single` appears in exactly one document of v1 → must be dropped by the
    ///   minimum-count floor.
    /// - `warSpecific` / `peaceSpecific` are volume-characteristic → must rank.
    private func fixture() -> DocumentSubjectsInput {
        // Tagged-doc unions: v1 = d1…d9 (9 docs), v2 = d1…d9 (9), v3 = d1…d9 (9) —
        // corpus total 27 tagged documents.
        let subjectsIndex: [String: DocumentSubjectsInput.SubjectMeta] = [
            "generic": .init(name: "Generic Topic", category: "Global Issues", subcategory: "General"),
            "single": .init(name: "Single Mention", category: "Warfare", subcategory: "General"),
            "warSpecific": .init(name: "Naval Blockade", category: "Warfare", subcategory: "General"),
            "peaceSpecific": .init(name: "Armistice", category: "Politico-Military Issues", subcategory: "Peace"),
            "shared": .init(name: "Diplomacy", category: "Bilateral Relations", subcategory: "General"),
        ]
        let subjects: [String: [String: String]] = [
            // generic: 9/10 docs in every volume → ~90% corpus doc-frequency → generic.
            "generic": [
                "frus_v1": "d1, d2, d3, d4, d5, d6, d7, d8, d9",
                "frus_v2": "d1, d2, d3, d4, d5, d6, d7, d8, d9",
                "frus_v3": "d1, d2, d3, d4, d5, d6, d7, d8, d9",
            ],
            // single: one doc in v1 → below the min-count floor of 2.
            "single": ["frus_v1": "d1"],
            // warSpecific: concentrated in v1 (5 docs), rare elsewhere → high score in v1.
            "warSpecific": ["frus_v1": "d1, d2, d3, d4, d5", "frus_v3": "d1"],
            // peaceSpecific: concentrated in v2 (5 docs) → high score in v2.
            "peaceSpecific": ["frus_v2": "d1, d2, d3, d4, d5"],
            // shared: moderate across v1 and v2.
            "shared": ["frus_v1": "d6, d7", "frus_v2": "d6, d7, d8"],
        ]
        return DocumentSubjectsInput(generated: "2026-06-16", subjectsIndex: subjectsIndex, subjects: subjects)
    }

    /// The 27-document fixture corpus is far smaller than the real ~266K-document
    /// corpus the default `0.10` threshold is tuned for, so a fixture-appropriate
    /// `0.5` threshold is used: it isolates the 100%-frequency `generic` subject while
    /// leaving the 18–22%-frequency characteristic subjects to rank. The genericity
    /// *mechanism* is what these tests exercise, not the production constant.
    private func build(_ params: ProfileAggregator.Parameters = .init(genericityThreshold: 0.5),
                       coverageEndYear: [String: Int] = [:])
        -> (index: VolumeSubjectProfilesIndex, stats: ProfileAggregator.Stats) {
        ProfileAggregator.aggregate(
            input: fixture(), parameters: params,
            volumeCoverageEndYear: coverageEndYear,
            schemaVersion: 1, generated: "2026-07-09", provenance: "test")
    }

    // MARK: Era-sanity (#308 F2)

    @Test("era-sanity drops an anachronistic subject from a volume that predates it, keeps it otherwise")
    func eraSanityDropsAnachronism() {
        // "AIDS" (earliest-plausible 1981) tagged on two volumes: one ending 1969, one ending 1985.
        let subjectsIndex: [String: DocumentSubjectsInput.SubjectMeta] = [
            "aids": .init(name: "AIDS", category: "Human Rights", subcategory: "General"),
            "war":  .init(name: "War", category: "Warfare", subcategory: "General"),
        ]
        let subjects: [String: [String: String]] = [
            "aids": ["frus_old": "d1, d2, d3", "frus_new": "d1, d2, d3"],
            "war":  ["frus_old": "d4, d5, d6", "frus_new": "d4, d5, d6"],
        ]
        let input = DocumentSubjectsInput(generated: "2026-06-16",
                                          subjectsIndex: subjectsIndex, subjects: subjects)
        // High genericity threshold so the tiny fixture doesn't drop either subject as generic.
        let (index, stats) = ProfileAggregator.aggregate(
            input: input, parameters: .init(genericityThreshold: 0.9),
            volumeCoverageEndYear: ["frus_old": 1969, "frus_new": 1985],
            schemaVersion: 1, generated: "t", provenance: "t")
        let refByIndex = index.vocab.map(\.ref)
        func refs(_ volumeId: String) -> Set<String> {
            Set(index.profiles.first { $0.volumeId == volumeId }?
                .entries.map { refByIndex[$0.vocabIndex] } ?? [])
        }
        // **The gate is RETIRED** (owner decision 2026-08-20), so this test asserts the opposite
        // of what it used to: a subject whose heading postdates the volume is KEPT.
        //
        // It was retired because it tested the subject HEADING's year while tags come from match
        // VARIANTS that deliberately predate the heading — measured, all 92 of its corpus-wide
        // drops were wrong, including 74 legitimate `Refugees` entries in volumes like frus1875v02
        // (a US minister sheltering 80 political refugees in his legation).
        #expect(refs("frus_old").contains("aids"), """
            The era gate is retired; a heading-vs-volume mismatch must no longer drop a tag. If \
            this fails, the gate has been reinstated without the variant-level data that would \
            make it correct.
            """)
        #expect(refs("frus_new").contains("aids"))
        #expect(refs("frus_old").contains("war"))      // untabled subject unaffected, as before
        #expect(stats.eraSanityDropped == 0, "the retired gate must drop nothing")
        // The table is still resolved and still reports unmatched names, so the research survives
        // for whoever gets variant-level data upstream and can build the sound test.
        #expect(stats.eraSanityUnmatched.contains("World War I"))
        #expect(!stats.eraSanityUnmatched.contains("AIDS"))
    }

    // MARK: Genericity + floor

    @Test("generic subjects above the corpus-frequency threshold are dropped entirely")
    func genericDropped() {
        let (index, stats) = build()
        #expect(stats.genericSubjectCount >= 1)
        #expect(!index.vocab.contains { $0.ref == "generic" })
        // 'generic' must not appear in any volume profile.
        let refByIndex = index.vocab.map(\.ref)
        for profile in index.profiles {
            for entry in profile.entries {
                #expect(refByIndex[entry.vocabIndex] != "generic")
            }
        }
    }

    @Test("a subject below the per-volume minimum-count floor is excluded")
    func minCountFloorExcludesSingletons() {
        let (index, _) = build()
        // 'single' (1 doc in v1) is below minDocCount=2 and must not surface.
        #expect(!index.vocab.contains { $0.ref == "single" })
    }

    // MARK: Ranking

    @Test("each volume's characteristic subject ranks first")
    func characteristicSubjectRanksFirst() {
        let (index, _) = build()
        let refByIndex = index.vocab.map(\.ref)
        func topRef(_ volumeId: String) -> String? {
            index.profiles.first { $0.volumeId == volumeId }?.entries.first.map { refByIndex[$0.vocabIndex] }
        }
        #expect(topRef("frus_v1") == "warSpecific")
        #expect(topRef("frus_v2") == "peaceSpecific")
    }

    @Test("scores are positive, descending, and rounded to 4 decimals")
    func scoresWellFormed() {
        let (index, _) = build()
        for profile in index.profiles {
            var last = Double.greatestFiniteMagnitude
            for entry in profile.entries {
                #expect(entry.score > 0)
                #expect(entry.score <= last)
                last = entry.score
                // 4-decimal rounding: score*10000 is (within fp tolerance) an integer.
                let scaled = entry.score * 10000
                #expect(abs(scaled - scaled.rounded()) < 1e-6)
            }
        }
    }

    // MARK: Top-N + vocab integrity

    @Test("top-N truncation caps each volume's entry count")
    func topNTruncates() {
        let (index, _) = build(.init(genericityThreshold: 0.5, minDocCount: 2, topN: 1))
        #expect(!index.profiles.isEmpty)
        for profile in index.profiles {
            #expect(profile.entries.count <= 1)
        }
    }

    @Test("every profile entry references a valid vocab index; vocab is sorted by ref")
    func vocabIntegrity() {
        let (index, _) = build()
        for profile in index.profiles {
            for entry in profile.entries {
                #expect(entry.vocabIndex >= 0 && entry.vocabIndex < index.vocab.count)
            }
        }
        #expect(index.vocab.map(\.ref) == index.vocab.map(\.ref).sorted())
        // Only used subjects are in the vocab (generic/single excluded).
        let vocabRefs = Set(index.vocab.map(\.ref))
        #expect(vocabRefs == ["warSpecific", "peaceSpecific", "shared"])
    }

    @Test("profiles are sorted by volumeId")
    func profilesSorted() {
        let (index, _) = build()
        #expect(index.profiles.map(\.volumeId) == index.profiles.map(\.volumeId).sorted())
    }

    // MARK: Vocab metadata

    @Test("vocab carries the source name/category/subcategory for each used ref")
    func vocabMetadata() {
        let (index, _) = build()
        let war = index.vocab.first { $0.ref == "warSpecific" }
        #expect(war?.name == "Naval Blockade")
        #expect(war?.category == "Warfare")
    }

    // MARK: Determinism (the wave byte-stability rule)

    @Test("aggregation is byte-stable across identical runs")
    func deterministic() throws {
        let a = build().index
        let b = build().index
        #expect(a == b)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let da = try encoder.encode(a)
        let db = try encoder.encode(b)
        #expect(da == db)
    }
}
