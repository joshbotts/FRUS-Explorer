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

// MARK: - CompleteSubjectMembershipTests

/// Pins the #308 Phase 3 facet fix: subject scopes resolve through **complete** membership.
///
/// ## What was wrong
/// The facets resolved through `VolumeSubjectProfiles.volumesBySubjectRef`, documented as "the
/// volumes whose PROFILE carries the subject". That is accurate and easy to read past, because a
/// profile is the volume's TOP-15. Measured over the shipped artifacts: of 76,574 (subject, volume)
/// memberships only **8,268 were selectable — 10.8%**. Scoping to *Agriculture* offered 51 volumes
/// when 526 contain it; *Water* offered 79 of 545.
///
/// A ranking artifact was being used as a membership index. The top-15 cut is right for "what is
/// this volume about" and wrong for "which volumes touch this subject".
///
/// Version history:
///   1.0 — Session 2026-08-21: #308 Phase 3
@Suite("Complete subject membership (#308)")
struct CompleteSubjectMembershipTests {

    @MainActor
    private func index() throws -> DocumentSubjectIndex {
        try #require(DocumentSubjectStore.shared,
                     "document-subject-index.json must decode from the app bundle")
    }

    /// The headline property: the document index reaches strictly more than the profiles.
    @MainActor
    @Test("Complete membership strictly exceeds the profile-derived membership")
    func completeExceedsProfiles() throws {
        let index = try index()
        let profiles = try #require(VolumeSubjectProfilesStore.shared)
        var profilePairs = 0
        for (_, volumes) in profiles.volumesBySubjectRef { profilePairs += volumes.count }
        var completePairs = 0
        for (_, volumes) in index.volumesBySubjectRef { completePairs += volumes.count }
        #expect(completePairs > profilePairs * 5, """
            Complete membership is \(completePairs) against the profiles' \(profilePairs). If these \
            ever converge, either the facets have been pointed back at the top-15 profiles or the \
            profiles have stopped being a top-15 ranking.
            """)
    }

    /// Every volume the profiles claim must still be present — the fix must ADD reach, never move
    /// it. A complete map that dropped a volume the profiles had would be a regression wearing the
    /// costume of an improvement.
    @MainActor
    @Test("The complete map is a superset of the profile map")
    func completeIsASuperset() throws {
        let index = try index()
        let profiles = try #require(VolumeSubjectProfilesStore.shared)
        var missing: [String] = []
        for (ref, volumes) in profiles.volumesBySubjectRef {
            let complete = index.volumeIds(forSubjectRef: ref)
            guard !complete.isEmpty else { continue }   // subject absent from the newer drop
            for volume in volumes where !complete.contains(volume) {
                missing.append("\(ref)/\(volume)")
            }
        }
        #expect(missing.isEmpty, """
            \(missing.count) (subject, volume) pairs the profiles carry are absent from the \
            complete map. First few: \(missing.prefix(5).joined(separator: ", "))
            """)
    }

    /// The catalogue must offer subjects that never rank anywhere — those are exactly the ones a
    /// facet is for: spread thinly across many volumes, top-15 in none.
    @MainActor
    @Test("The catalogue includes subjects that reach no volume's top-15")
    func catalogueIncludesUnrankedSubjects() throws {
        let index = try index()
        let profiles = try #require(VolumeSubjectProfilesStore.shared)
        let ranked = Set(profiles.volumesBySubjectRef.keys)
        let complete = Set(index.subjectVocabulary.map(\.ref))
        let unranked = complete.subtracting(ranked)
        #expect(!unranked.isEmpty, """
            Every subject in the complete vocabulary also ranks in some volume's profile, which \
            means the catalogue gained nothing. 111 subjects were unranked when this shipped.
            """)
        // And they must be reachable, not merely listed.
        for ref in unranked.prefix(5) {
            #expect(!index.volumeIds(forSubjectRef: ref).isEmpty,
                    "\(ref) is in the catalogue but resolves to no volumes")
        }
    }

    /// The volume-grain view the category facets read must agree with the subject-grain one — they
    /// are two shapes of one fact, and a category scope built from a disagreeing view would differ from
    /// the subject scope beneath it.
    @MainActor
    @Test("The volume-grain view agrees with the subject-grain map")
    func viewsAgree() throws {
        let index = try index()
        let byVolume = index.subjectsByVolume
        var reconstructed: [String: Set<String>] = [:]
        for (volumeId, subjects) in byVolume {
            for subject in subjects { reconstructed[subject.ref, default: []].insert(volumeId) }
        }
        var disagreements = 0
        for (ref, volumes) in index.volumesBySubjectRef where Set(volumes) != (reconstructed[ref] ?? []) {
            disagreements += 1
        }
        #expect(disagreements == 0, """
            \(disagreements) subjects disagree between the subject-grain map and the volume-grain \
            view. A category facet built from one and a subject facet from the other would scope \
            differently for the same data.
            """)
    }
}


// MARK: - PivotSheetMembershipTests

/// Pins #1027: the subject pivot sheet's row list resolves through **complete membership**, the
/// same set its archival-profile button below already used.
///
/// ## What was wrong
/// One sheet, two resolvers. The rows came from `VolumeSubjectProfilesStore.otherVolumes`, whose
/// reach is each volume's top-15 subjects, while `coveringVolumeIds` — feeding the "Archival
/// profile of these volumes" button and its footer count — came from the complete document-subject
/// index. So the header said "8 other volumes cover this subject" directly above a button offering
/// the profile of 82, for one subject, in one sheet. The smaller number was the one wearing the
/// word *cover*.
///
/// These tests drive `VolumeSubjectVolumesSheet`'s own resolver rather than re-deriving membership,
/// because a test that re-derives it passes no matter what the sheet reads.
///
/// Version history:
///   1.0 — Session 2026-08-21: #1027
@Suite("Subject pivot sheet membership (#1027)")
struct PivotSheetMembershipTests {

    @MainActor
    private func index() throws -> DocumentSubjectIndex {
        try #require(DocumentSubjectStore.shared,
                     "document-subject-index.json must decode from the app bundle")
    }

    /// The subject where the two routes disagreed most, with a volume that carries it — the
    /// fixture is chosen from the data so it cannot go stale against a re-drop.
    @MainActor
    private func widestGapSubject() throws -> (ref: String, volumeId: String, complete: Int, profile: Int) {
        let index = try index()
        let profiles = try #require(VolumeSubjectProfilesStore.shared)
        var best: (ref: String, volumeId: String, complete: Int, profile: Int)?
        for (ref, profileVolumes) in profiles.volumesBySubjectRef {
            let complete = index.volumeIds(forSubjectRef: ref)
            guard let anchor = complete.sorted().first else { continue }
            let gap = complete.count - profileVolumes.count
            if gap > (best.map { $0.complete - $0.profile } ?? 0) {
                best = (ref, anchor, complete.count, profileVolumes.count)
            }
        }
        return try #require(best, "no subject is carried by both the profiles and the document index")
    }

    /// The headline: the rows are membership, not the top-15 ranking.
    @MainActor
    @Test("The row list resolves through complete membership, not the volume profiles")
    func rowsUseCompleteMembership() throws {
        let fixture = try widestGapSubject()
        let sheet = VolumeSubjectVolumesSheet(
            subject: .init(ref: fixture.ref, name: "fixture", category: "c", subcategory: "s", score: 1),
            currentVolumeId: fixture.volumeId)

        // Exactly membership minus the volume in hand.
        #expect(sheet.otherVolumeIds.count == fixture.complete - 1, """
            The sheet listed \(sheet.otherVolumeIds.count) volumes where complete membership for             \(fixture.ref) is \(fixture.complete) (minus the one being viewed). If this reads             \(max(0, fixture.profile - 1)) the rows have been pointed back at the top-15 profiles.
            """)
        #expect(!sheet.otherVolumeIds.contains(fixture.volumeId),
                "the volume being viewed must not appear among the OTHER volumes")

        // And strictly more than the pre-#1027 answer, so a silent regression to profiles fails
        // here even if the counts above were somehow satisfied.
        let profiles = try #require(VolumeSubjectProfilesStore.shared)
        let profileRoute = profiles.otherVolumes(forSubjectRef: fixture.ref,
                                                 excluding: fixture.volumeId)
        #expect(sheet.otherVolumeIds.count > profileRoute.count, """
            Membership (\(sheet.otherVolumeIds.count)) must exceed the profile route             (\(profileRoute.count)) for \(fixture.ref) — that gap is the whole of #1027.
            """)
    }

    /// The bug's actual shape: one sheet must not state two counts for one subject.
    @MainActor
    @Test("The row list and the archival-profile button describe the same set")
    func listAndButtonAgree() throws {
        let fixture = try widestGapSubject()
        let sheet = VolumeSubjectVolumesSheet(
            subject: .init(ref: fixture.ref, name: "fixture", category: "c", subcategory: "s", score: 1),
            currentVolumeId: fixture.volumeId)
        #expect(Set(sheet.coveringVolumeIds) == Set(sheet.otherVolumeIds).union([fixture.volumeId]), """
            The button's set (\(sheet.coveringVolumeIds.count)) is not the row list             (\(sheet.otherVolumeIds.count)) plus the volume being viewed. Two resolvers have grown             back, which is exactly what #1027 removed.
            """)
    }

    /// The person-affinity context (#264) excludes nothing, so both sets are identical there.
    @MainActor
    @Test("With no current volume, nothing is excluded")
    func personContextExcludesNothing() throws {
        let fixture = try widestGapSubject()
        let sheet = VolumeSubjectVolumesSheet(
            subject: .init(ref: fixture.ref, name: "fixture", category: "c", subcategory: "s", score: 1),
            currentVolumeId: "")
        #expect(sheet.otherVolumeIds == sheet.coveringVolumeIds)
        #expect(sheet.otherVolumeIds.count == fixture.complete)
    }
}

// MARK: - SubjectFacetCopyTests

/// Pins the detected-topic picker's PROSE against the reach its resolver actually delivers.
///
/// ## What was wrong
/// #1017 repointed every subject facet at complete document-grain membership. That is right for
/// the subject grain — *Agriculture* reaches 526 volumes, not the 51 whose top-15 ranked it — and
/// it **saturates** at the category grain, because a category is a union over ~40 subjects.
/// Measured over the shipped artifacts, seven of thirteen categories reach 552 of 552 volumes.
///
/// The two footers, written for the old route, still told the reader *"A volume appears when a
/// topic is among its most distinctive, not merely mentioned."* So the surface promised a
/// distinctiveness filter and delivered the whole corpus. The reach column beside each row was
/// honest the whole time; only the sentences were not.
///
/// These tests fail if either half moves: prose that re-asserts distinctiveness, or a resolver
/// whose reach stops being saturating (which would mean the prose needs rewriting the other way).
///
/// Version history:
///   1.0 — Session 2026-08-21: from the #1027/#1024 adversarial review
@Suite("Detected-topic facet copy matches its reach")
struct SubjectFacetCopyTests {

    /// The measurement the copy rests on. If categories ever stop saturating, the sentences
    /// this suite protects become the wrong ones and should be revisited deliberately.
    @MainActor
    @Test("Category reach is saturating, which is what the copy must describe")
    func categoryReachIsSaturating() throws {
        let index = try #require(DocumentSubjectStore.shared)
        let catalog = ScopeFacets.categoryCatalog(resolvedByVolume: index.subjectsByVolume)
        let corpusVolumes = index.taggedVolumeIds.count
        #expect(catalog.count >= 13, "the taxonomy's categories must all be present")

        let widest = try #require(catalog.map(\.volumeCount).max())
        #expect(widest == corpusVolumes, """
            The widest category reaches \(widest) of \(corpusVolumes) volumes. The picker's copy \
            says a broad category "reaches most of the series"; if the widest no longer reaches \
            ALL of it, re-read that sentence before changing this number.
            """)
        let saturating = catalog.filter { $0.volumeCount == corpusVolumes }.count
        #expect(saturating >= 5, """
            Only \(saturating) categories select the whole corpus. Measured at 7 of 13 when the \
            copy was written — a filter that selects everything is the thing the reader has to be \
            told about.
            """)
    }

    /// The prose itself. A source scan, because the strings are the deliverable.
    @MainActor
    @Test("Neither footer claims the picker selects on distinctiveness")
    func copyDoesNotPromiseDistinctiveness() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("FRUSExplorer/Search/SearchFilterView.swift"),
            encoding: .utf8)

        #expect(!source.contains("one of their most distinctive"), """
            The section footer promised volumes "where that topic is one of their most \
            distinctive". The resolver selects every volume containing the topic — measured, that \
            is all 552 for seven of thirteen categories.
            """)
        #expect(!source.contains("among its most distinctive, not merely mentioned"), """
            The picker footer promised the opposite of what it does: mentioned IS enough, and \
            saying otherwise is the difference between a filter and no filter.
            """)
        #expect(source.contains("mentioned is enough"), """
            The picker footer must say plainly that a mention is sufficient. Softening this puts \
            the reader back where the review found them.
            """)
        #expect(source.contains("the count beside each"), """
            The copy must point at the reach column. It is the only thing on screen that \
            distinguishes a category selecting 438 volumes from one selecting 552.
            """)
    }
}

// MARK: - SubjectsByVolumeCostTests

/// Pins that `DocumentSubjectIndex.subjectsByVolume` is a stored map, not a rebuild.
///
/// ## What was wrong
/// It was a computed property that rebuilt all 76,574 entries on every read — allocating a
/// `ResolvedSubject` per (subject, volume) pair, appending each through a dictionary lookup, then
/// sorting all 552 arrays. Measured on an iPhone 17 simulator: **278 ms per access, on the main
/// actor.**
///
/// Six scope surfaces read it, and one reads it in a loop. `SearchFilterView.categories` reads it
/// once and then calls `subCategoryCatalog(resolvedByVolume:)` once per category inside a `filter`
/// closure, so the measured cost of **typing one character** into the topic picker's search field
/// was **3,623 ms**, and expanding one category was **3,204 ms** — single main-actor blocks, on a
/// control the reader is expected to type into.
///
/// After: 193 ms and 121 ms. The remaining time is the catalogs themselves walking the map, which
/// is a separate and much smaller question.
///
/// Version history:
///   1.0 — Session 2026-08-21: from the #1027/#1024 review
@Suite("subjectsByVolume is stored, not rebuilt")
struct SubjectsByVolumeCostTests {

    /// The guard. Absolute rather than ratio because there is no longer a slow path to compare
    /// against, and the headroom is enormous: 200 reads of a stored map is microseconds, while 200
    /// rebuilds would be ~56 seconds. Nothing between those two numbers is a plausible regression.
    @MainActor
    @Test("Repeated reads are free")
    func repeatedReadsAreFree() throws {
        let index = try #require(DocumentSubjectStore.shared)
        _ = index.subjectsByVolume   // fault in whatever the first touch costs

        let started = ContinuousClock.now
        var total = 0
        for _ in 0..<200 { total += index.subjectsByVolume.count }
        let elapsed = ContinuousClock.now - started

        #expect(total == 200 * index.subjectsByVolume.count)
        #expect(elapsed < .milliseconds(500), """
            200 reads took \(elapsed). A stored map makes this microseconds; if `subjectsByVolume` \
            has gone back to rebuilding, this is ~56 seconds and the topic picker freezes for 3.6 s \
            per keystroke.
            """)
    }

    /// The cache must be RIGHT, not merely fast — a stored map that disagrees with the data would
    /// be a worse bug than the one it fixes, and would show as wrong volume counts on six surfaces.
    @MainActor
    @Test("The stored map matches the membership it is derived from")
    func storedMapMatchesMembership() throws {
        let index = try #require(DocumentSubjectStore.shared)
        let byVolume = index.subjectsByVolume

        // Rebuild independently from the subject-grain map and compare.
        var expected: [String: Set<String>] = [:]
        for (ref, volumeIds) in index.volumesBySubjectRef {
            for volumeId in volumeIds { expected[volumeId, default: []].insert(ref) }
        }
        #expect(byVolume.count == expected.count, "volume coverage differs")
        var mismatched: [String] = []
        for (volumeId, subjects) in byVolume where Set(subjects.map(\.ref)) != expected[volumeId] {
            mismatched.append(volumeId)
        }
        #expect(mismatched.isEmpty, """
            \(mismatched.count) volumes' subject sets disagree with the membership map they are \
            built from. First few: \(mismatched.prefix(3).joined(separator: ", "))
            """)

        // And the documented ordering survives: IDF-descending, ties by name.
        for (_, subjects) in byVolume.prefix(50) {
            let resorted = subjects.sorted { ($0.score, $1.name) > ($1.score, $0.name) }
            #expect(subjects.map(\.ref) == resorted.map(\.ref),
                    "a volume's subjects are not in the documented IDF-descending order")
        }
    }
}
