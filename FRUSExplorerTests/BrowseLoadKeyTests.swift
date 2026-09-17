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

// MARK: - BrowseLoadKeyTests

/// The reuse contract's one mechanical gate (#1301 round 2).
///
/// ## What this suite can and cannot do, said plainly
/// `BrowserView.levelView` states that every payload-carrying Browse level keys its load task on
/// the payload it loads for. Until `BrowseLoadKey` existed, that sentence had **no gate of any
/// kind**: a mutation sweep keyed `CompilationView`'s task on the section's *title* instead of its
/// cache key and every unit test and both iPad browse suites stayed green, because the fixture's
/// two nested heads happen to differ. The same sweep gutted `VolumeView`'s and
/// `ClustersBrowseView`'s keys back to bare `.task`s with the same result.
///
/// These assertions close the half that is a value: a key must **vary with every component of its
/// payload**, which is what a title-key, a volume-only key, or a count-only key fails. They do not
/// and cannot show that a view still passes the key to `.task(id:)` — a source scan for that shape
/// is the thing this repo has already MEASURED to be vacuous (`VolumeStructure.swift:200` records
/// a guard that asserted a literal over raw source and stayed green while a mutant reinstated the
/// bug in full). For `CompilationView` that half is closed instead by construction: its load goes
/// through `View.compilationDocumentLoad(vm:volumeId:section:)`, which takes the section and
/// derives the key itself, so there is no key at the call site to mutate.
///
/// Version history:
///   1.0 — #1301 round 2: initial implementation
@Suite("Browse load keys vary with their payload")
@MainActor
struct BrowseLoadKeyTests {

    // MARK: - The compilation key

    @Test("The compilation key is the cache key — one definition, not two that agree today")
    func compilationKeyIsTheCacheKey() {
        let vm = BrowserViewModel(
            manifestStore: ManifestStore(bundledEntries: []),
            tagStore: VolumeLevelTagStore(),
            downloadManager: nil,
            indexingPipeline: nil
        )
        #expect(
            vm.compilationKey(volumeId: "frus1945Malta", sectionId: "ch8")
                == BrowseLoadKey.compilation(volumeId: "frus1945Malta", sectionId: "ch8"),
            """
            The task's id and the dictionary the load writes into must be the same string. Two \
            definitions that agree today are two things to keep in step; `compilationKey` \
            forwards to `BrowseLoadKey.compilation` so there is nothing to keep in step.
            """
        )
    }

    @Test("The compilation key changes with the section, which a title key does not")
    func compilationKeyVariesWithTheSection() {
        let parent = BrowseLoadKey.compilation(volumeId: "frus1945Malta", sectionId: "ch8")
        let child = BrowseLoadKey.compilation(volumeId: "frus1945Malta", sectionId: "ch11")
        #expect(parent != child, """
            #1301 is a `.compilation → .compilation` step that reuses one view, so a key that does \
            not move between two sections is the defect itself. A key on `section.title` moves \
            here only because these two ids have different titles in the corpus — measured, 0 of \
            744 local volumes hold a section whose <head> equals its own PARENT's, which is why \
            that mutation survived every behavioural test and needs an assertion about the key.
            """)
    }

    @Test("The compilation key changes with the volume, which a section-only key does not")
    func compilationKeyVariesWithTheVolume() {
        #expect(
            BrowseLoadKey.compilation(volumeId: "frus1945Malta", sectionId: "ch8")
                != BrowseLoadKey.compilation(volumeId: "frus1961-63v06", sectionId: "ch8"),
            """
            Section ids are unique within a volume and NOT across the corpus — `ch8` exists in \
            hundreds of volumes — so a key on the section alone would serve one volume's rows \
            under another volume's section.
            """
        )
    }

    // MARK: - The other payload-carrying levels

    @Test("The volume key changes with the volume")
    func volumeKeyVariesWithTheVolume() {
        // Not latent, and the comment this replaces said it was: `CorpusView`'s root search calls
        // `BrowserViewModel.select(_:)`, which ASSIGNS the path rather than appending, and on
        // regular-width iPad that list pane stands beside a detail pane that may already hold a
        // volume — a live `.volume → .volume` step.
        #expect(BrowseLoadKey.volume("frus1945Malta") != BrowseLoadKey.volume("frus1961-63v06"))
    }

    @Test("The cluster membership key changes with the cluster")
    func clusterMembershipKeyVariesWithTheCluster() {
        #expect(BrowseLoadKey.clusterMembership(clusterId: 17)
                != BrowseLoadKey.clusterMembership(clusterId: 18))
    }

    @Test("The cluster metadata key changes with the cluster AND with the indexed-volume count")
    func clusterMetadataKeyVariesWithBothComponents() {
        #expect(
            BrowseLoadKey.clusterMetadata(clusterId: 17, indexedVolumeCount: 3)
                != BrowseLoadKey.clusterMetadata(clusterId: 18, indexedVolumeCount: 3),
            """
            The count-only form is the dangerous one: it still re-keys on indexing, so it reads in \
            a diff as the working B-4 idiom while having dropped the cluster back out.
            """
        )
        #expect(
            BrowseLoadKey.clusterMetadata(clusterId: 17, indexedVolumeCount: 3)
                != BrowseLoadKey.clusterMetadata(clusterId: 17, indexedVolumeCount: 4),
            """
            And the cluster-only form loses what B-4 added: finishing an index pass must upgrade \
            the degraded rows without navigating away.
            """
        )
    }

    @Test("The archival collection key changes with the record")
    func archivalCollectionKeyVariesWithTheRecord() {
        #expect(BrowseLoadKey.archivalCollection(recordId: "presidential-libraries/truman")
                != BrowseLoadKey.archivalCollection(recordId: "presidential-libraries/eisenhower"))
    }

    // MARK: - The gate the compilation load runs behind

    @Test("The load gate reads the index and nothing else")
    func loadGateAdmitsOnlyTheIndexQuestion() {
        #expect(CompilationDocumentsPresentation.shouldLoad(isIndexed: true), """
            An indexed volume loads. This is the whole of the gate: the `guard volume != nil` \
            #1301 deleted asked the MANIFEST a question the load never needed, and a side-loaded \
            volume — indexed perfectly well, absent from `allSubseriesGroups` — answered `nil` and \
            never loaded a single row, with no error and no change of spinner.
            """)
        #expect(CompilationDocumentsPresentation.shouldLoad(isIndexed: false) == false, """
            An unindexed volume does NOT load, and this is the gate's reason for existing: \
            `document_cache` answers an unindexed volume with an empty set, which records \
            `.loaded` — the one state that short-circuits — so every later kick would return \
            early. `unindexedVolumeCachesAsLoadedAndEmpty` measures that trap from the other end.
            """)
    }
}
