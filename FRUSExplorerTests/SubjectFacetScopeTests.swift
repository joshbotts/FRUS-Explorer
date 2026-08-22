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
        // "count beside each", not "the count beside each": #1040 rewrote this footer to say
        // "the VOLUME count beside each", and the assertion is about pointing at the reach column
        // rather than about one wording of it.
        #expect(source.contains("count beside each"), """
            The copy must point at the reach column. With categories no longer selectable it is \
            what distinguishes a sub-category selecting 162 volumes from one selecting 550.
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

// MARK: - SubjectRefShapeTests

/// Pins the ref-shape split the durable-key design rests on — because three shipped comments got
/// it wrong, and the obvious way to check it is also wrong.
///
/// ## The design, and the claim under it
/// A saved subject search stores `subjectRef` and resolves ref-first, with `subjectName` as a
/// fallback. That is only worth doing if some refs move when the display name moves.
///
/// ## What is actually in the vocabulary — THREE shapes, not two
/// - **470** opaque upstream record ids (`rec00812a40defabcb`), stable across drops;
/// - **2** name-derived slugs wearing a `rec_` prefix (`rec_korean_war`, `rec_world_war_ii`);
/// - **19** plain name-derived slugs (`collective-security`, `east-asia-and-pacific`).
///
/// The middle pair is the trap, and it is why this suite exists rather than a comment. A
/// `hasPrefix("rec")` test — the obvious discriminator, and the one my first draft of this test
/// used — counts them as stable ids and reports 472/19. They are not stable: they are the display
/// name, lower-cased with separators. The discriminator that holds is that an opaque id is
/// `rec` followed by alphanumerics ONLY, so a separator character is the tell.
///
/// The shipped comments had said "472 `rec`-style … roughly 95 synthetic". Both numbers were
/// wrong, and ~95 is the count of refs the upstream generator re-mints per export — a different
/// quantity, carried across from a note about that generator. The design was right and the
/// arithmetic was not, which is the easiest kind of error to propagate by quotation.
///
/// Version history:
///   1.0 — Session 2026-08-21: from the #1023 scoping pass
@Suite("Subject ref shapes")
struct SubjectRefShapeTests {

    /// An opaque upstream id: `rec` then alphanumerics only. A separator means name-derived.
    private static func isOpaqueRecordID(_ ref: String) -> Bool {
        ref.hasPrefix("rec") && ref.dropFirst(3).allSatisfy { $0.isLetter || $0.isNumber }
    }

    @MainActor
    @Test("The vocabulary splits 470 opaque ids to 21 name-derived refs")
    func refShapeSplitIsAsDocumented() throws {
        let index = try #require(DocumentSubjectStore.shared)
        let refs = index.subjectVocabulary.map(\.ref)
        let opaque = refs.filter(Self.isOpaqueRecordID)
        let derived = refs.filter { !Self.isOpaqueRecordID($0) }

        #expect(refs.count == 491, "the shipped vocabulary is 491 subjects; got \(refs.count)")
        #expect(opaque.count == 470, """
            \(opaque.count) opaque record ids, not 470. The durable-key comments quote this number.
            """)
        #expect(derived.count == 21, """
            \(derived.count) name-derived refs, not 21. These are what the name fallback exists for.
            """)
        #expect(opaque.count + derived.count == refs.count, "every ref is one shape or the other")
    }

    /// The specific trap: refs that LOOK like stable ids by prefix and are not. If a future drop
    /// removes these two, the fallback is protecting less than the docs claim and the docs should
    /// shrink to match.
    @MainActor
    @Test("Two name-derived refs wear a rec_ prefix, which prefix-matching would miss")
    func recPrefixedSlugsAreNotOpaqueIDs() throws {
        let index = try #require(DocumentSubjectStore.shared)
        let refs = index.subjectVocabulary.map(\.ref)
        let prefixed = refs.filter { $0.hasPrefix("rec") && !Self.isOpaqueRecordID($0) }
        #expect(Set(prefixed) == ["rec_korean_war", "rec_world_war_ii"], """
            Expected exactly the two known rec_-prefixed slugs; found \(prefixed.sorted()). A \
            `hasPrefix("rec")` discriminator counts these as stable ids and reports 472/19 — which \
            is how the shipped comments came to say 472.
            """)
    }

    /// The property the fallback depends on, and it is exact rather than approximate: strip
    /// non-alphanumerics from a name-derived ref and from its display name and the two are
    /// **identical**, for all 21. So the ref is a pure function of the name, and a renamed subject
    /// is a re-minted ref — which is precisely the case `subjectName` exists to catch.
    ///
    /// Verified for every one of them, not sampled: if this ever became approximate, the fallback
    /// would be resting on a coincidence rather than on a rule.
    @MainActor
    @Test("A name-derived ref is its display name, alphanumerics only")
    func derivedRefsAreTheirNames() throws {
        let index = try #require(DocumentSubjectStore.shared)
        func alphanumerics(_ s: String) -> String {
            String(s.lowercased().filter { $0.isLetter || $0.isNumber })
        }
        var checked = 0
        for entry in index.subjectVocabulary where !Self.isOpaqueRecordID(entry.ref) {
            let slug = entry.ref.hasPrefix("rec_") ? String(entry.ref.dropFirst(4)) : entry.ref
            #expect(alphanumerics(slug) == alphanumerics(entry.name), """
                Ref \(entry.ref) is not its name "\(entry.name)" reduced to alphanumerics \
                (\(alphanumerics(slug)) vs \(alphanumerics(entry.name))). The name fallback assumes \
                the ref is derived from the name; if that is now only approximately true, say so \
                rather than loosening this test.
                """)
            checked += 1
        }
        #expect(checked == 21, "all 21 name-derived refs must be checked, not a sample")
    }
}

// MARK: - SubjectCatalogueTests

/// Pins the Subject Explorer's catalogue (#1023 data layer).
///
/// Version history:
///   1.0 — Session 2026-08-21: #1023
@Suite("Subject catalogue (#1023)")
struct SubjectCatalogueTests {

    /// The catalogue must carry the WHOLE vocabulary, including the subjects no volume's top-15
    /// ranks — those are exactly what an index is for, and any profile-derived list omits them.
    @MainActor
    @Test("Every subject in the vocabulary appears, including the unranked ones")
    func catalogueIsComplete() throws {
        let index = try #require(DocumentSubjectStore.shared)
        let catalogue = index.subjectCatalogue
        #expect(catalogue.count == index.subjectVocabulary.count)
        #expect(catalogue.count > 450, "the shipped vocabulary is 491 subjects; got \(catalogue.count)")

        let profiles = try #require(VolumeSubjectProfilesStore.shared)
        let ranked = Set(profiles.volumesBySubjectRef.keys)
        let unranked = catalogue.filter { !ranked.contains($0.ref) }
        #expect(!unranked.isEmpty, """
            Every catalogue subject also reaches some volume's top-15, so the explorer would show \
            nothing a profile-derived list could not. The 111 unranked subjects are the reason this \
            surface reads the vocabulary rather than the profiles.
            """)
    }

    /// Reach must agree with the artifact it came from, on both axes.
    @MainActor
    @Test("Document and volume counts agree with the index")
    func reachAgreesWithTheIndex() throws {
        let index = try #require(DocumentSubjectStore.shared)
        var checked = 0
        for row in index.subjectCatalogue.prefix(60) {
            #expect(row.documentCount == index.documentFrequency(forSubjectRef: row.ref),
                    "\(row.ref): catalogue and documentFrequency disagree")
            #expect(row.volumeCount == index.volumeIds(forSubjectRef: row.ref).count,
                    "\(row.ref): catalogue and volumeIds disagree")
            checked += 1
        }
        #expect(checked == 60)
    }

    /// The corpus/device split this surface inherits: the artifact counts all 552 volumes, so a
    /// reach figure can exceed anything a search on this device returns. Pinned because the copy
    /// that discloses it is only honest while this is true.
    @MainActor
    @Test("Reach is corpus-wide, so it can exceed one device's library")
    func reachIsCorpusWide() throws {
        let index = try #require(DocumentSubjectStore.shared)
        let widest = try #require(index.subjectCatalogue.max { $0.volumeCount < $1.volumeCount })
        #expect(widest.volumeCount > 400, """
            The widest subject reaches \(widest.volumeCount) volumes. The explorer's copy says these \
            counts describe the whole series rather than the reader's library; if reach ever became \
            device-scoped, that sentence would be the thing to rewrite.
            """)
        #expect(widest.documentCount > 1_000)
    }

    /// Alphabetical, not by reach — an index is read, not chosen from.
    @MainActor
    @Test("The catalogue is ordered by name")
    func catalogueIsAlphabetical() throws {
        let index = try #require(DocumentSubjectStore.shared)
        let names = index.subjectCatalogue.map(\.name)
        #expect(names == names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending },
                "a 491-row index sorted by a number the reader did not ask about is unnavigable")
    }
}

// MARK: - SubjectIndexGroupingTests

/// Pins the Subject Explorer's grouping and filtering (#1023).
///
/// Drives `SubjectIndexGrouping.sections` — the real rule the view calls — rather than re-deriving
/// it, which is why that rule is a pure static function on a type of its own.
///
/// Version history:
///   1.0 — Session 2026-08-22: #1023
@Suite("Subject index grouping (#1023)")
struct SubjectIndexGroupingTests {

    private func row(_ name: String, category: String = "Warfare",
                     subcategory: String = "General") -> SubjectIndexGrouping.SubjectIndexRow {
        .init(ref: "ref-\(name)", name: name, category: category, subcategory: subcategory,
              documentCount: 1, volumeCount: 1)
    }

    @Test("Rows group under their initial letter")
    func groupsByInitial() {
        let sections = SubjectIndexGrouping.sections(
            from: [row("Agriculture"), row("Arms control"), row("Berlin")], query: "")
        #expect(sections.map(\.letter) == ["A", "B"])
        #expect(sections[0].subjects.count == 2)
    }

    /// The non-letter bucket sorts LAST, not by code point. A heading whose position a reader
    /// cannot predict belongs at the end.
    @Test("A non-letter initial files under # and sorts last")
    func nonLetterSortsLast() {
        let sections = SubjectIndexGrouping.sections(
            from: [row("1956 crisis"), row("Berlin"), row("Agriculture")], query: "")
        #expect(sections.map(\.letter) == ["A", "B", "#"], """
            Got \(sections.map(\.letter)). "#" sorts before "A" by code point, which would put an \
            unpredictable heading at the top of a 491-row index.
            """)
        #expect(sections.last?.subjects.map(\.name) == ["1956 crisis"])
    }

    /// Search matches the sub-category too, because the sub-category is ON SCREEN in every row: a
    /// row visibly containing the typed word must not be filtered out.
    @Test("Search matches name, category and sub-category")
    func searchMatchesWhatIsVisible() {
        let rows = [row("Berlin blockade", category: "Warfare", subcategory: "Cold War"),
                    row("Agriculture", category: "Global Issues", subcategory: "Food")]
        #expect(SubjectIndexGrouping.sections(from: rows, query: "berlin")
            .flatMap(\.subjects).map(\.name) == ["Berlin blockade"])
        #expect(SubjectIndexGrouping.sections(from: rows, query: "cold war")
            .flatMap(\.subjects).map(\.name) == ["Berlin blockade"], """
            A row showing "Warfare · Cold War" must be findable by typing "cold war" — the \
            sub-category is visible in the row, so filtering it out reads as a broken search.
            """)
        #expect(SubjectIndexGrouping.sections(from: rows, query: "food")
            .flatMap(\.subjects).map(\.name) == ["Agriculture"])
    }

    @Test("Whitespace-only search does not filter")
    func whitespaceIsNotAQuery() {
        let rows = [row("Agriculture"), row("Berlin")]
        #expect(SubjectIndexGrouping.sections(from: rows, query: "   ").flatMap(\.subjects).count == 2)
    }

    @Test("A search matching nothing yields no sections, not empty ones")
    func noMatchesYieldsNoSections() {
        #expect(SubjectIndexGrouping.sections(from: [row("Agriculture")], query: "zzz").isEmpty, """
            Empty sections would render as headings with nothing under them; the view's \
            ContentUnavailableView overlay keys on this being empty.
            """)
    }

    /// The real vocabulary, so the grouping is exercised at production scale and shape.
    @MainActor
    @Test("The shipped catalogue groups without loss")
    func shippedCatalogueGroupsCompletely() throws {
        let index = try #require(DocumentSubjectStore.shared)
        let rows = index.subjectCatalogue.map {
            SubjectIndexGrouping.SubjectIndexRow(
                ref: $0.ref, name: $0.name, category: $0.category, subcategory: $0.subcategory,
                documentCount: $0.documentCount, volumeCount: $0.volumeCount)
        }
        let grouped = SubjectIndexGrouping.sections(from: rows, query: "")
        #expect(grouped.flatMap(\.subjects).count == rows.count, "grouping must not drop a subject")
        #expect(grouped.count > 10, "491 subjects should span many initials")
        #expect(Set(grouped.flatMap(\.subjects).map(\.ref)).count == rows.count, "no duplication")
    }
}

// MARK: - SubjectExplorerRequestTests

/// Pins the payload shape (#1023) — specifically that the facet door cannot express a subject.
///
/// Version history:
///   1.0 — Session 2026-08-22: #1023
@Suite("Subject explorer request (#1023)")
struct SubjectExplorerRequestTests {

    /// It rides a macOS window's restoration payload, so it must survive a Codable round-trip.
    @Test("Every case round-trips through Codable")
    func casesRoundTrip() throws {
        for value: SubjectExplorerRequest in [.all, .group(categoryKey: "Warfare\u{1F}General"),
                                              .subject(ref: "rec1", name: "Berlin blockade")] {
            let data = try JSONEncoder().encode(value)
            #expect(try JSONDecoder().decode(SubjectExplorerRequest.self, from: data) == value)
        }
    }

    /// The distinction the sum type exists for: three doors, three amounts of knowledge. If this
    /// ever collapses to `(ref, name)`, the facet door has to invent a ref it does not possess.
    @Test("The cases carry different amounts of knowledge")
    func casesAreDistinct() {
        #expect(SubjectExplorerRequest.all != .group(categoryKey: "Warfare\u{1F}General"))
        #expect(SubjectExplorerRequest.group(categoryKey: "a") != .group(categoryKey: "b"))
        #expect(SubjectExplorerRequest.subject(ref: "r", name: "A")
                != .subject(ref: "r", name: "B"), """
            The name is part of identity, not decoration: it is the fallback half of the durable \
            key and what the filter chip shows.
            """)
    }
}


// MARK: - NarrowingCategoryTests

/// Pins #1040: a category is a heading, not a scope.
///
/// ## The measurements this rests on
/// - 7 of 13 categories select **all 552** volumes; the narrowest selects 438.
/// - No document-count threshold rescues them: at 20 documents per volume, seven still select
///   476–548. The taxonomy's top level describes the series rather than partitioning it.
/// - `General` sub-categories reach a **median 542 of 552** — so unfolding them, the obvious way to
///   keep every category non-empty, would move a control that cannot narrow one level down.
/// - Non-`General` sub-categories reach a median **162**. That is the grain that narrows, and it is
///   what the menus now offer.
///
/// Version history:
///   1.0 — Session 2026-08-22: #1040
@Suite("Categories are headings, not scopes (#1040)")
struct NarrowingCategoryTests {

    @MainActor
    private func resolved() throws -> [String: [VolumeSubjectProfiles.ResolvedSubject]] {
        let index = try #require(DocumentSubjectStore.shared)
        return index.subjectsByVolume
    }

    /// The premise. If categories ever stopped saturating, this whole change would want revisiting
    /// rather than preserving.
    @MainActor
    @Test("Categories saturate, which is why they are not offered as scopes")
    func categoriesSaturate() throws {
        let map = try resolved()
        let all = ScopeFacets.categoryCatalog(resolvedByVolume: map)
        let corpus = map.count
        let saturating = all.filter { $0.volumeCount == corpus }.count
        #expect(saturating >= 5, """
            Only \(saturating) of \(all.count) categories select the whole corpus. Measured at 7 of \
            13 when this shipped; if categories have become discriminating, re-read #1040 before \
            keeping them out of the menus.
            """)
    }

    /// The rule itself: only categories with something under them that narrows.
    @MainActor
    @Test("Only categories with a non-General sub-category are offered")
    func onlyNarrowingCategoriesAreOffered() throws {
        let map = try resolved()
        let offered = ScopeFacets.narrowingCategories(resolvedByVolume: map)
        let all = ScopeFacets.categoryCatalog(resolvedByVolume: map)
        #expect(offered.count < all.count, """
            Every category is still offered (\(offered.count) of \(all.count)). Two of them — \
            Information Programs and Uncategorized — have only a folded `General` bucket, so with \
            no "All of X" row they would open onto an empty menu.
            """)
        for category in offered {
            #expect(!ScopeFacets.subCategoryCatalog(forCategory: category.label,
                                                    resolvedByVolume: map).isEmpty,
                    "\(category.label) is offered but has nothing under it")
        }
        let withheld = Set(all.map(\.label)).subtracting(offered.map(\.label))
        for label in withheld {
            #expect(ScopeFacets.subCategoryCatalog(forCategory: label,
                                                   resolvedByVolume: map).isEmpty,
                    "\(label) was withheld but has sub-categories a reader could have used")
        }
    }

    /// Why `General` was not unfolded instead — the alternative that would have kept every category
    /// non-empty. It fails on the same measurement the categories fail on.
    @MainActor
    @Test("General sub-categories are as saturating as the categories, so unfolding would not help")
    func generalWouldNotHelp() throws {
        let index = try #require(DocumentSubjectStore.shared)
        var generalReach: [Int] = []
        var specificReach: [Int] = []
        var byBucket: [String: Set<String>] = [:]
        for (volumeId, subjects) in index.subjectsByVolume {
            for subject in subjects {
                byBucket["\(subject.category)\u{1F}\(subject.subcategory)", default: []].insert(volumeId)
            }
        }
        for (key, volumes) in byBucket {
            if key.hasSuffix("\u{1F}\(ScopeFacets.generalSubcategory)") {
                generalReach.append(volumes.count)
            } else {
                specificReach.append(volumes.count)
            }
        }
        let generalMedian = generalReach.sorted()[generalReach.count / 2]
        let specificMedian = specificReach.sorted()[specificReach.count / 2]
        #expect(generalMedian > specificMedian * 2, """
            General rows reach a median \(generalMedian) against the specific rows' \
            \(specificMedian). Unfolding General was rejected because it moves a control that \
            cannot narrow one level down and renames it; if that gap has closed, the decision is \
            worth re-opening.
            """)
    }

    /// The menus must not offer a whole-category scope. A source scan, because the control is a
    /// SwiftUI Button inside a Menu and its absence is the deliverable.
    @Test("No scope surface offers an All-of-category row")
    func noSurfaceOffersWholeCategory() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        for path in ["FRUSExplorer/SeriesAnalytics/SeriesScopeBar.swift",
                     "FRUSExplorer/Analytics/AnalyticsChartChrome.swift",
                     "FRUSExplorer/Analytics/WordCloud/WordCloudView.swift",
                     "FRUSExplorer/Search/SearchFilterView.swift"] {
            let source = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            #expect(!source.contains("wholeCategory"), """
                \(path) still offers an "All of <category>" row. Measured, that selects 438–552 of \
                552 volumes — a control that cannot narrow, under copy promising a filter.
                """)
            #expect(source.contains("narrowingCategories"), """
                \(path) builds its category list from something other than the shared rule. That \
                rule is one function precisely because the last per-site enumeration in this area \
                was written five times and three disagreed (#1022).
                """)
        }
    }
}
