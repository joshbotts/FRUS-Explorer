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
