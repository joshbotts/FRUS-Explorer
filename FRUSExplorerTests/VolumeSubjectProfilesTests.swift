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
        // The genericity floor holds. What that means is "no subject is so corpus-wide that it
        // crowds out what a volume is actually about" — the whole feature fails if War and Peace
        // top every list. It is asserted two ways, because a fixed list of names cannot express it.
        //
        // These five are corpus-wide in any drop, and stay out:
        let alwaysGeneric: Set<String> = [
            "War", "Peace", "Science and technology",
            "Treaties and international agreements", "Trade relations",
        ]
        for (volumeId, subjects) in profiles.resolvedByVolume {
            for subject in subjects {
                #expect(!alwaysGeneric.contains(subject.name),
                        "\(volumeId) carries stoplisted generic subject \(subject.name)")
            }
        }

        // The list used to also name "International law" and "Financial and monetary affairs".
        // They were removed on 2026-08-19 when the source drop was refreshed, because the floor is
        // a MEASURED threshold — a share of tagged corpus documents — and the cleaner export put
        // both below it. That is the floor working, not failing: measured over the refreshed
        // artifact, "International law" is listed by 102 of 552 volumes and tops exactly one, which
        // makes it less common than eight subjects this test never stoplisted (Intelligence
        // collection 178, Propaganda 166, Armed forces 162). Pinning the *output* of a data-driven
        // rule re-fails on every legitimate refresh, so the invariant is asserted directly instead.
        let volumeCount = profiles.resolvedByVolume.count
        var listedIn: [String: Int] = [:]
        var topsCount: [String: Int] = [:]
        for (_, subjects) in profiles.resolvedByVolume {
            for subject in subjects { listedIn[subject.name, default: 0] += 1 }
            if let first = subjects.first { topsCount[first.name, default: 0] += 1 }
        }
        // Measured headroom: the most-listed subject is 32.2% of volumes in this drop and was
        // 36.6% in the previous one, so 40% flags a real regression rather than ordinary drift.
        if let (name, count) = listedIn.max(by: { $0.value < $1.value }) {
            #expect(Double(count) / Double(volumeCount) < 0.40, """
                \(name) is listed by \(count) of \(volumeCount) volumes — the genericity floor is \
                no longer holding it back
                """)
        }
        // And nothing should be the single most characteristic subject of a large slice of the
        // corpus: 3.4% here, 3.8% before.
        if let (name, count) = topsCount.max(by: { $0.value < $1.value }) {
            #expect(Double(count) / Double(volumeCount) < 0.10,
                    "\(name) tops \(count) of \(volumeCount) volumes' profiles")
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


// MARK: - SubjectMeaningTests

/// Pins #1024: `ResolvedSubject.score` carries two different quantities depending on which producer
/// built the value, and the difference is arithmetic, not cosmetic.
///
/// The field was documented as "the TF-IDF-style distinctiveness weight; ranks within a volume
/// only" — written when the volume profiles were the only producer. The document-subject index
/// now fills the same field with corpus IDF. Every *ordering* use stays correct under either, which
/// is why this went unnoticed; the two consumers that do arithmetic on it
/// (`PersonSubjectAffinity.rank`, whose producer is injected, and `ProjectFocusSuggestions`, whose
/// is type-pinned) would silently change question if handed the other producer.
///
/// These tests pin the two properties the field's warning rests on. If they ever fail, the warning
/// is what needs rewriting — not the tests.
///
/// Version history:
///   1.0 — Session 2026-08-21: #1024
@Suite("Subject score means two things (#1024)")
struct SubjectMeaningTests {

    /// The document producer's score is a corpus constant: identical for a ref in every volume.
    /// This is the property that makes it factor out of `Σ documentCount × score`.
    @MainActor
    @Test("The document-grain score is constant per subject across volumes")
    func documentScoreIsCorpusConstant() throws {
        let index = try #require(DocumentSubjectStore.shared)
        var seen: [String: Double] = [:]
        var varying: [String] = []
        for (_, subjects) in index.subjectsByVolume {
            for subject in subjects {
                if let previous = seen[subject.ref] {
                    if previous != subject.score { varying.append(subject.ref) }
                } else {
                    seen[subject.ref] = subject.score
                }
            }
        }
        #expect(varying.isEmpty, """
            \(varying.count) subjects vary in score across volumes at the document grain. That \
            score is documented as corpus IDF — a constant — and PersonIndexView's affinity \
            warning depends on it being one.
            """)
    }

    /// The profile producer's score is NOT constant — it is per-volume, which is what makes an
    /// affinity sum meaningful there. Two producers, two quantities, one field.
    @MainActor
    @Test("The profile-grain score varies per volume for the same subject")
    func profileScoreVariesByVolume() throws {
        let profiles = try #require(VolumeSubjectProfilesStore.shared)
        var seen: [String: Double] = [:]
        var varying = 0
        for (volumeId, _) in profiles.resolvedByVolume {
            for subject in profiles.topSubjects(forVolumeId: volumeId) ?? [] {
                if let previous = seen[subject.ref], previous != subject.score { varying += 1 }
                seen[subject.ref] = subject.score
            }
        }
        #expect(varying > 0, """
            No subject's profile score varies across volumes. If the profiles have become a corpus \
            constant too, the two producers now agree and #1024's warning — and the affinity \
            ranking that depends on the variation — should be revisited.
            """)
    }

    /// And the two disagree in fact, for subjects both carry. Without this the warning would be
    /// theoretical: two producers that happened to agree could be swapped freely.
    @MainActor
    @Test("The two producers disagree on the same subject in the same volume")
    func producersDisagree() throws {
        let index = try #require(DocumentSubjectStore.shared)
        let profiles = try #require(VolumeSubjectProfilesStore.shared)
        let documentScores = index.subjectsByVolume
        var compared = 0
        var disagreed = 0
        for (volumeId, _) in profiles.resolvedByVolume {
            guard let profileSubjects = profiles.topSubjects(forVolumeId: volumeId),
                  let documentSubjects = documentScores[volumeId] else { continue }
            let byRef = Dictionary(documentSubjects.map { ($0.ref, $0.score) },
                                   uniquingKeysWith: { a, _ in a })
            for subject in profileSubjects {
                guard let documentScore = byRef[subject.ref] else { continue }
                compared += 1
                if abs(documentScore - subject.score) > 1e-9 { disagreed += 1 }
            }
        }
        #expect(compared > 0, "no (subject, volume) pair is carried by both producers")
        #expect(disagreed > compared / 2, """
            Only \(disagreed) of \(compared) shared (subject, volume) pairs disagree. The field's \
            warning claims the two producers store different quantities; near-agreement would mean \
            they do not.
            """)
    }

    /// The enumeration itself, pinned. A count in prose goes stale silently; this fails when a
    /// third site starts doing arithmetic on the field.
    ///
    /// Scans for accumulation (`+=`) against a `ResolvedSubject`'s `score` across the app. The two
    /// known sites are allowed by name; anything else is a new arithmetic consumer the field's
    /// warning does not cover, which is precisely how "exactly one" became wrong.
    ///
    /// **What this scan can and cannot see.** It matches the binding both real sites use
    /// (`subject.score`) on a non-comment line. It deliberately does NOT match bare `.score`,
    /// because the first draft did and produced two false positives: this suite's own doc comment
    /// quoting the code, and `ProjectLeadsAggregator`'s `candidate.score`, which is a lead's score
    /// and an unrelated type. A false positive is worse than a narrow scan here — a source test
    /// that cries wolf gets its `known` list padded until it means nothing. The cost is that a
    /// consumer binding the value under another name escapes it, so this supplements the field's
    /// documentation rather than replacing it.
    @MainActor
    @Test("Only the two documented sites do arithmetic on ResolvedSubject.score")
    func arithmeticConsumersAreEnumerated() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer")
        let known: Set<String> = ["PersonIndexView.swift", "ProjectFocusSuggestions.swift"]

        var found: [String] = []
        let files = try #require(FileManager.default.enumerator(at: root,
                                                                includingPropertiesForKeys: nil))
        for case let url as URL in files {
            guard url.pathExtension == "swift" else { continue }
            guard let source = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for line in source.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("//") else { continue }   // prose, not code
                guard trimmed.contains("+="), trimmed.contains("subject.score") else { continue }
                found.append(url.lastPathComponent)
                break
            }
        }
        let unexpected = Set(found).subtracting(known)
        #expect(unexpected.isEmpty, """
            New arithmetic on ResolvedSubject.score in: \(unexpected.sorted().joined(separator: ", ")). \
            The field's doc enumerates its arithmetic consumers and explains why a producer swap \
            changes the question each answers — add the new site to that note and to `known` here, \
            or the next author will trust a count that is wrong again.
            """)
        #expect(Set(found).isSuperset(of: known), """
            One of the documented sites no longer accumulates .score — found \(found.sorted()). If \
            it was removed, shrink the doc's enumeration in the same commit.
            """)
    }
}
