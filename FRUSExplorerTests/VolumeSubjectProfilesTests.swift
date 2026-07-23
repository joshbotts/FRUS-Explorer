// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

// MARK: - VolumeSubjectProfilesTests

/// Decode + query tests for the app-side `VolumeSubjectProfiles` (Session 9): the
/// int-indexed vocabulary resolution, category grouping order, the cross-volume pivot,
/// tolerant decoding, and an integration guard that the actual bundled
/// `volume-subject-profiles-index.json` decodes with a sane shape.
///
/// Version history:
///   1.0 — Session 9: initial implementation
struct VolumeSubjectProfilesTests {

    /// A small artifact-shaped fixture: two volumes over a 3-subject vocabulary.
    /// `warSpecific` (idx 2) is v1's top; `peaceSpecific` (idx 1) is v2's top; `shared`
    /// (idx 0) appears in both.
    private func fixtureJSON() -> Data {
        let json = """
        {
          "schemaVersion": 1,
          "generated": "2026-06-16",
          "provenance": "test",
          "vocab": [
            {"r": "shared", "n": "Diplomacy", "c": "Bilateral Relations", "s": "General"},
            {"r": "peaceSpecific", "n": "Armistice", "c": "Politico-Military Issues", "s": "Peace"},
            {"r": "warSpecific", "n": "Naval Blockade", "c": "Warfare", "s": "General"}
          ],
          "profiles": [
            {"v": "frus_v1", "e": [{"i": 2, "w": 0.83}, {"i": 0, "w": 0.37}]},
            {"v": "frus_v2", "e": [{"i": 1, "w": 0.94}, {"i": 0, "w": 0.56}]}
          ]
        }
        """
        return Data(json.utf8)
    }

    private func decode() throws -> VolumeSubjectProfiles {
        try JSONDecoder().decode(VolumeSubjectProfiles.self, from: fixtureJSON())
    }

    // MARK: Resolution

    @Test("vocab indices resolve to name/category and preserve rank order")
    func resolvesTopSubjects() throws {
        let p = try decode()
        let v1 = try #require(p.topSubjects(forVolumeId: "frus_v1"))
        #expect(v1.map(\.name) == ["Naval Blockade", "Diplomacy"])
        #expect(v1.first?.category == "Warfare")
        #expect(v1.first?.score == 0.83)
        #expect(p.topSubjects(forVolumeId: "does-not-exist") == nil)
    }

    // MARK: Grouping

    @Test("grouped subjects order categories by their most-characteristic subject")
    func groupsOrderedByBestScore() throws {
        let p = try decode()
        let groups = p.groupedTopSubjects(forVolumeId: "frus_v1")
        // v1: Warfare (0.83) must precede Bilateral Relations (0.37).
        #expect(groups.map(\.category) == ["Warfare", "Bilateral Relations"])
        #expect(groups.first?.subjects.map(\.name) == ["Naval Blockade"])
    }

    // MARK: Cross-volume pivot

    @Test("otherVolumes lists shared-subject volumes and excludes the current one")
    func otherVolumesExcludesCurrent() throws {
        let p = try decode()
        // 'shared' appears in both volumes; from v1 the pivot must list only v2.
        #expect(p.otherVolumes(forSubjectRef: "shared", excluding: "frus_v1") == ["frus_v2"])
        #expect(p.otherVolumes(forSubjectRef: "shared", excluding: "frus_v2") == ["frus_v1"])
        // 'warSpecific' is only in v1, so from v1 there are no others.
        #expect(p.otherVolumes(forSubjectRef: "warSpecific", excluding: "frus_v1").isEmpty)
    }

    // MARK: Discovery vocabulary + resolver (#377 Phase 2b)

    @Test("allSubjects lists every referenced subject once, category-ordered, with reach")
    func allSubjectsVocabulary() throws {
        let p = try decode()
        // Ordered by category → subcategory → name: Bilateral Relations, Politico-Military, Warfare.
        #expect(p.allSubjects.map(\.name) == ["Diplomacy", "Armistice", "Naval Blockade"])
        #expect(p.allSubjects.map(\.ref) == ["shared", "peaceSpecific", "warSpecific"])
        // 'shared' spans both volumes; the specifics span one each.
        let byRef = Dictionary(uniqueKeysWithValues: p.allSubjects.map { ($0.ref, $0.volumeCount) })
        #expect(byRef["shared"] == 2)
        #expect(byRef["peaceSpecific"] == 1)
        #expect(byRef["warSpecific"] == 1)
    }

    @Test("volumeIds(forSubjectRefs:) unions the covering volumes of every ref")
    func volumeIdsForSubjectRefs() throws {
        let p = try decode()
        #expect(p.volumeIds(forSubjectRefs: ["warSpecific"]) == ["frus_v1"])
        #expect(p.volumeIds(forSubjectRefs: ["peaceSpecific"]) == ["frus_v2"])
        // 'shared' alone spans both; a union of the two specifics also spans both.
        #expect(p.volumeIds(forSubjectRefs: ["shared"]) == ["frus_v1", "frus_v2"])
        #expect(p.volumeIds(forSubjectRefs: ["warSpecific", "peaceSpecific"]) == ["frus_v1", "frus_v2"])
        // Unknown refs contribute nothing.
        #expect(p.volumeIds(forSubjectRefs: ["nope"]).isEmpty)
        #expect(p.volumeIds(forSubjectRefs: [String]()).isEmpty)
    }

    @Test("focus suggestions rank by recurrence across engaged volumes, then score")
    func focusSuggestions() throws {
        let p = try decode()
        // One engaged volume → its top subjects, ranked by score (count ties at 1).
        let fromV1 = ProjectFocusSuggestions.suggestions(
            engagedVolumeIds: ["frus_v1"], profiles: p, excluding: [])
        #expect(fromV1.map(\.name) == ["Naval Blockade", "Diplomacy"])  // 0.83 before 0.37

        // Both volumes → 'shared' recurs (count 2) so it leads; the specifics (count 1)
        // follow, ordered by score (peaceSpecific 0.94 before warSpecific 0.83).
        let fromBoth = ProjectFocusSuggestions.suggestions(
            engagedVolumeIds: ["frus_v1", "frus_v2"], profiles: p, excluding: [])
        #expect(fromBoth.map(\.ref) == ["shared", "peaceSpecific", "warSpecific"])

        // Already-chosen refs are excluded from suggestions.
        let excludingShared = ProjectFocusSuggestions.suggestions(
            engagedVolumeIds: ["frus_v1", "frus_v2"], profiles: p, excluding: ["shared"])
        #expect(!excludingShared.contains { $0.ref == "shared" })

        // A limit caps the count.
        #expect(ProjectFocusSuggestions.suggestions(
            engagedVolumeIds: ["frus_v1", "frus_v2"], profiles: p, excluding: [], limit: 1).count == 1)
    }

    // MARK: Tolerance

    @Test("out-of-range vocab indices are skipped, not fatal")
    func toleratesBadIndex() throws {
        let json = """
        {"schemaVersion":1,"generated":"x","provenance":"","vocab":[{"r":"a","n":"A","c":"C","s":"S"}],
         "profiles":[{"v":"vX","e":[{"i":9,"w":1.0},{"i":0,"w":0.5}]}]}
        """
        let p = try JSONDecoder().decode(VolumeSubjectProfiles.self, from: Data(json.utf8))
        // The i=9 row is dropped; only the valid i=0 row survives.
        #expect(p.topSubjects(forVolumeId: "vX")?.map(\.name) == ["A"])
    }

    @Test("a missing/empty payload decodes to empty, not a crash")
    func toleratesEmpty() throws {
        let p = try JSONDecoder().decode(VolumeSubjectProfiles.self, from: Data("{}".utf8))
        #expect(p.resolvedByVolume.isEmpty)
        #expect(p.topSubjects(forVolumeId: "anything") == nil)
    }

    // MARK: Bundled artifact integrity

    @Test("bundled volume-subject-profiles-index.json decodes with a sane shape")
    func bundledArtifactDecodes() throws {
        guard let profiles = VolumeSubjectProfilesStore.shared else {
            return // resource unavailable in this host — nothing to assert
        }
        // Every resolved subject has a non-empty name and category, and a positive score.
        var volumesChecked = 0
        for (_, subjects) in profiles.resolvedByVolume {
            volumesChecked += 1
            for subject in subjects {
                #expect(!subject.name.isEmpty)
                #expect(!subject.category.isEmpty)
                #expect(subject.score > 0)
            }
            // Scores are ranked descending within a volume.
            let scores = subjects.map(\.score)
            #expect(scores == scores.sorted(by: >))
        }
        #expect(volumesChecked > 0)
    }

    @Test("bundled artifact provenance pins the source drop (generated date + md5)")
    func bundledArtifactProvenancePinned() throws {
        guard let profiles = VolumeSubjectProfilesStore.shared else { return }
        // The plan requires the provenance to pin the exact frus-subjects drop: the
        // upstream re-mints ~95 synthetic subject refs per export, so only a content
        // hash distinguishes two drops. A regeneration that loses the pin must fail here.
        #expect(profiles.provenance.contains("frus-subjects"))
        #expect(profiles.provenance.contains("source generated"))
        let md5Token = profiles.provenance.range(of: #"md5 [0-9a-f]{32}"#, options: .regularExpression)
        #expect(md5Token != nil, "provenance must carry the source drop's 32-hex md5 pin")
    }

    @Test("bundled artifact content sanity: known volumes surface era-specific subjects, never stoplisted generics")
    func bundledArtifactContentSanity() throws {
        guard let profiles = VolumeSubjectProfilesStore.shared else { return }
        // Plan item 8's known-volume checks (empirically tuned during Session 9):
        // the Vietnam volume's most characteristic subject is Vietnamization…
        let v06 = try #require(profiles.topSubjects(forVolumeId: "frus1969-76v06"))
        #expect(v06.first?.name == "Vietnamization")
        // …the WWII/USSR volume surfaces Lend-lease, and 1898 surfaces Neutrality.
        let v1944 = try #require(profiles.topSubjects(forVolumeId: "frus1944v04"))
        #expect(v1944.contains { $0.name == "Lend-lease program" })
        let v1898 = try #require(profiles.topSubjects(forVolumeId: "frus1898"))
        #expect(v1898.contains { $0.name == "Neutrality" })
        // The genericity floor holds: the 7 corpus-wide mega-subjects must appear in
        // NO volume's profile (the whole feature fails if War/Peace top every list).
        let stoplisted: Set<String> = [
            "War", "Peace", "Science and technology",
            "Treaties and international agreements", "Trade relations",
            "Financial and monetary affairs", "International law",
        ]
        for (volumeId, subjects) in profiles.resolvedByVolume {
            for subject in subjects {
                #expect(!stoplisted.contains(subject.name),
                        "\(volumeId) carries stoplisted generic subject \(subject.name)")
            }
        }
    }
}

// MARK: - PersonSubjectAffinityTests (#264)

/// Tests the pure person↔subject affinity ranking extracted from `PersonIndexDetailSheet`
/// (`loadSubjectAffinities`) so the join is covered without a live `PersonMentionStore`.
struct PersonSubjectAffinityTests {

    private func subject(_ ref: String, _ name: String, score: Double,
                         category: String = "Category") -> VolumeSubjectProfiles.ResolvedSubject {
        VolumeSubjectProfiles.ResolvedSubject(
            ref: ref, name: name, category: category, subcategory: "Sub", score: score)
    }

    /// Builds a `topSubjectsByVolume` lookup from a plain dictionary (nil ⇒ no bundled profile).
    private func lookup(_ map: [String: [VolumeSubjectProfiles.ResolvedSubject]])
        -> (String) -> [VolumeSubjectProfiles.ResolvedSubject]? {
        { map[$0] }
    }

    @Test("Weight sums docCount × score across the person's volumes; volumeCount counts volumes")
    func weightingAndAggregation() {
        let a1 = subject("A", "Alpha", score: 0.8)
        let a2 = subject("A", "Alpha", score: 0.9)   // same ref, other volume
        let b  = subject("B", "Bravo", score: 0.5)
        let c  = subject("C", "Charlie", score: 0.3)
        let ranked = PersonSubjectAffinity.rank(
            mentionCounts: [("v1", 10), ("v2", 2)],
            topSubjectsByVolume: lookup(["v1": [a1, b], "v2": [a2, c]]),
            limit: 8)

        // A: in both volumes → weight 10*0.8 + 2*0.9 = 9.8, volumeCount 2.
        // B: only v1 → 10*0.5 = 5.0. C: only v2 → 2*0.3 = 0.6.
        #expect(ranked.map(\.subject.ref) == ["A", "B", "C"])
        #expect(ranked[0].volumeCount == 2)
        #expect(abs(ranked[0].weight - 9.8) < 1e-9)
        #expect(ranked[1].volumeCount == 1)
        #expect(abs(ranked[1].weight - 5.0) < 1e-9)
        #expect(abs(ranked[2].weight - 0.6) < 1e-9)
    }

    @Test("Volumes with no bundled profile are skipped")
    func skipsProfilelessVolumes() {
        let a = subject("A", "Alpha", score: 0.5)
        let ranked = PersonSubjectAffinity.rank(
            mentionCounts: [("v1", 4), ("vNoProfile", 100)],
            topSubjectsByVolume: lookup(["v1": [a]]),   // vNoProfile absent ⇒ nil
            limit: 8)
        #expect(ranked.map(\.subject.ref) == ["A"])
        #expect(abs(ranked[0].weight - 2.0) < 1e-9)   // 4*0.5 only; the 100-doc volume contributed nothing
    }

    @Test("Equal weights break ties by subject name for determinism")
    func tieBreakByName() {
        // Same docCount × score for both ⇒ equal weight; expect name-ascending order.
        let zebra = subject("Z", "Zebra", score: 0.5)
        let apple = subject("A", "Apple", score: 0.5)
        let ranked = PersonSubjectAffinity.rank(
            mentionCounts: [("v1", 3)],
            topSubjectsByVolume: lookup(["v1": [zebra, apple]]),
            limit: 8)
        #expect(ranked.map(\.subject.name) == ["Apple", "Zebra"])
    }

    @Test("The result is capped to the limit, keeping the highest-weight subjects")
    func respectsLimit() {
        let subjects = (1...5).map { subject("S\($0)", "S\($0)", score: Double($0) / 10.0) }
        let ranked = PersonSubjectAffinity.rank(
            mentionCounts: [("v1", 1)],
            topSubjectsByVolume: lookup(["v1": subjects]),
            limit: 2)
        // Highest scores are S5 (0.5) then S4 (0.4).
        #expect(ranked.map(\.subject.ref) == ["S5", "S4"])
    }

    @Test("No mention volumes yields no affinities")
    func emptyCounts() {
        let ranked = PersonSubjectAffinity.rank(
            mentionCounts: [],
            topSubjectsByVolume: lookup(["v1": [subject("A", "Alpha", score: 1)]]),
            limit: 8)
        #expect(ranked.isEmpty)
    }
}
