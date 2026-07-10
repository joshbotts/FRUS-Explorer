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
}
