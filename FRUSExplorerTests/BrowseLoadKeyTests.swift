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
/// bug in full).
///
/// ## The other half, and where each level's gate actually is (round 3)
/// Round 2's attack measured the limit above rather than inferring it: reverting `VolumeView`'s,
/// `ClustersBrowseView`'s and `CollectionDetailView`'s keyed tasks to bare `.task`s left every
/// suite green while the three key assertions below went on passing. So every keyed level now
/// loads through a modifier in `BrowseLoadKey.swift` that derives its own key — no call site holds
/// one — and the gates are:
///  - `.compilation` and `.volume`: **walks**, in `BrowseNestedSectionTests`. Both self-to-self
///    steps are reachable, and a walk fails when the key is gone.
///  - `.clusterDocuments` and `.archivalCollection`: no row appends either step, so no walk can
///    exist. The modifier is the structural gate, and the state those two views hold carries its
///    own identity — the second section here pins that a value loaded for one payload is never
///    reported for another, which is what makes a missing key a spinner rather than another
///    collection's figures under this one's name; the third, that a superseded load's late write
///    is dropped rather than erasing the payload on screen (round 4).
///
/// Version history:
///   1.0 — #1301 round 2: initial implementation
///   1.1 — #1301 round 3: `CollectionDetailLoad` and `ClusterDrillState` — the identity-carrying
///          state that replaces two resets a mutation could delete with every suite green
///   1.2 — #1301 round 4: a superseded load's late write must be DROPPED. Round 3's values adopted
///          a write naming another payload, so a late write for A, landing after B's task had
///          recorded, erased B's data — the Cited Over Time chart for good, and a cluster drill
///          back to its spinner. Every fixture now starts where its view starts (`""`,
///          `.noCluster`) and writes with the ticket `open(for:)` issues, because round 3's cluster
///          fixtures all started at a real id and so never took the line every real drill runs
///          through; and re-opening the value for the payload it holds is pinned to keep it
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

    // MARK: - The level state that carries its own identity (#1301 round 3)

    @Test("A collection's loaded values are reported for that collection and no other")
    func collectionDetailLoadAnswersOnlyItsOwnRecord() {
        // Starts where `CollectionDetailView` starts, so the opening below is the one the view's
        // first load runs through.
        var detail = CollectionDetailLoad(for: "")
        let ticket = detail.open(for: "presidential-libraries/truman")
        detail.record(localStats: IndexingPipeline.CollectionLocalStats(documentCount: 412,
                                                                        volumeCount: 9),
                      with: ticket)
        detail.record(related: [], with: ticket)
        detail.record(timeline: [CollectionEraCount(
            era: CollectionCoverageEra(index: 0, startYear: 1945, endYear: 1952),
            volumeCount: 9)], with: ticket)

        #expect(detail.localStats(for: "presidential-libraries/truman")?.documentCount == 412, """
            The record the value was opened for gets its own figures. `CollectionDetailView` \
            starts at `CollectionDetailLoad(for: "")`, so its first load always runs through \
            `open(for:)`'s replacement — a value left at "" refuses every write, and the page \
            says "still loading" for ever.
            """)
        #expect(detail.timeline(for: "presidential-libraries/truman").count == 1,
                "and its timeline, from the same first load")

        #expect(detail.localStats(for: "presidential-libraries/eisenhower") == nil, """
            412 documents belong to Truman, and under Eisenhower's name they are a lie with \
            nothing to say so. This is the screen `CollectionDetailView`'s keyed task used to \
            prevent with three `@State` resets nobody could hold it to — deleting them left 46 \
            tests in three suites green. Here the reset is not a statement: a value is reported \
            only for the record it was loaded for.
            """)
        #expect(detail.related(for: "presidential-libraries/eisenhower") == nil, """
            …and `nil` rather than `[]`, because this view draws `nil` as "still loading" and `[]` \
            as "nothing related" — a reuse must say the first, never the second.
            """)
        #expect(detail.timeline(for: "presidential-libraries/eisenhower").isEmpty, """
            …and an empty timeline draws no chart at all, which is the right thing to show for a \
            collection whose buckets are not known yet.
            """)
    }

    @Test("Opening the value for another record starts it empty, so two records never mix")
    func collectionDetailLoadRefusesToMixTwoRecords() {
        var detail = CollectionDetailLoad(for: "")
        let a = detail.open(for: "a")
        detail.record(localStats: IndexingPipeline.CollectionLocalStats(documentCount: 7,
                                                                        volumeCount: 2),
                      with: a)
        // The keyed task moves on to B, and B's ranking lands.
        let b = detail.open(for: "b")
        detail.record(related: [], with: b)

        #expect(detail.localStats(for: "b") == nil, """
            Opening the value for a different record must REPLACE it, not join it: a value that \
            merged the two would show A's document count beside B's related list.
            """)
        #expect(detail.related(for: "b") != nil, "and B's own write is kept")
        #expect(detail.localStats(for: "a") == nil, "…with A's figures gone rather than lingering")
    }

    @Test("Re-opening the value for the record it holds keeps what it holds")
    func collectionDetailLoadKeepsItsRecordWhenReopened() {
        var detail = CollectionDetailLoad(for: "")
        let first = detail.open(for: "a")
        detail.record(related: [], with: first)
        _ = detail.open(for: "a")

        #expect(detail.related(for: "a") != nil, """
            The keyed task re-runs every time the view re-appears — back from a pushed volume, \
            say — and opens the value again for the same record. Emptying it there would blank \
            a collection the reader is returning to and show "loading" over figures that are \
            about to be written back unchanged.
            """)
    }

    @Test("A cluster's first load, from where the view starts, is reported for that cluster")
    func clusterDrillStateReportsItsFirstMembershipLoad() {
        // `ClusterDocumentsView` starts at `ClusterDrillState(for: .noCluster)` and never builds
        // another, so EVERY real drill runs through `open(for:)`'s replacement. Round 3's version of
        // that line lived in the write and no fixture took it: every one started at a real id.
        var drill = ClusterDrillState(for: ClusterDrillState.noCluster)
        let ticket = drill.open(for: 17)
        drill.record(cluster: SemanticMapArtifacts.Cluster(id: 17, terms: [], documentCount: 2,
                                                           centreX: 0, centreY: 0, eraCounts: [:]),
                     keys: ["v/d1", "v/d2"],
                     shownCount: 2,
                     with: ticket)

        #expect(drill.cluster(for: 17)?.id == 17, """
            The drill's first membership load is not reported. With both `cluster(for:)` and \
            `unavailable(for:)` answering nil `ClusterDocumentsView` draws its spinner, and the \
            membership task will not run again — its key has not changed — so every cluster drill \
            in the app sits on ProgressView for good: #1301's screen on the Clusters axis.
            """)
        #expect(drill.keys(for: 17).count == 2, "and its members with it")
    }

    @Test("A cluster's first unavailable reason, from where the view starts, is reported")
    func clusterDrillStateReportsItsFirstUnavailableReason() {
        var drill = ClusterDrillState(for: ClusterDrillState.noCluster)
        let ticket = drill.open(for: 17)
        drill.record(unavailable: .noArtifact, with: ticket)

        #expect(drill.unavailable(for: 17) == .noArtifact, """
            The drill's first "unavailable" is not reported, so a cluster missing from the \
            artifact — or an artifact that failed to load — shows a spinner that never ends \
            instead of "This cluster's data could not be loaded."
            """)
    }

    @Test("A cluster's loaded membership is reported for that cluster and no other")
    func clusterDrillStateAnswersOnlyItsOwnCluster() {
        var drill = ClusterDrillState(for: ClusterDrillState.noCluster)
        let cluster = SemanticMapArtifacts.Cluster(id: 17,
                                                   terms: ["shah", "iran", "iranian", "mosadeq"],
                                                   documentCount: 2,
                                                   centreX: 0, centreY: 0,
                                                   eraCounts: [:])
        drill.record(cluster: cluster,
                     keys: ["frus1952-54v10/d1", "frus1952-54v10/d2"],
                     shownCount: 2,
                     with: drill.open(for: 17))

        #expect(drill.cluster(for: 17)?.id == 17, "precondition")
        #expect(drill.keys(for: 17).count == 2, "precondition")

        #expect(drill.cluster(for: 18) == nil, """
            `ClusterDocumentsView`'s body prefers `if let cluster`, so a cluster reported for \
            another cluster's id renders the PREVIOUS cluster's document list under this one's \
            title — and keeps rendering it when the new cluster is missing from the artifact, \
            because that path sets `unavailable` and returns without touching `cluster`.
            """)
        #expect(drill.keys(for: 18).isEmpty, "and none of its members either")
        #expect(drill.shownCount(for: 18) == 0, "nor its paging cursor")
    }

    @Test("Re-opening the drill for the cluster it holds keeps the list")
    func clusterDrillStateKeepsItsClusterWhenReopened() {
        var drill = ClusterDrillState(for: ClusterDrillState.noCluster)
        drill.record(cluster: SemanticMapArtifacts.Cluster(id: 17, terms: [], documentCount: 1,
                                                           centreX: 0, centreY: 0, eraCounts: [:]),
                     keys: ["v/d1"],
                     shownCount: 1,
                     with: drill.open(for: 17))
        _ = drill.open(for: 17)

        #expect(drill.cluster(for: 17) != nil, """
            The membership task re-runs every time the view re-appears — back from an opened \
            document, say — and opens the value again for the same cluster. Emptying it there \
            would swap the list the reader is returning to for a spinner and lose their place, \
            which round 3's view did not do.
            """)
    }

    @Test("Show more moves the cluster on screen, and nothing else")
    func clusterDrillStateShowMoreOnlyMovesItsOwnCluster() {
        var drill = ClusterDrillState(for: ClusterDrillState.noCluster)
        drill.record(cluster: SemanticMapArtifacts.Cluster(id: 17, terms: [], documentCount: 3,
                                                           centreX: 0, centreY: 0, eraCounts: [:]),
                     keys: ["v/d1", "v/d2", "v/d3"],
                     shownCount: 1,
                     with: drill.open(for: 17))

        drill.showMore(1, for: 18)
        #expect(drill.shownCount(for: 17) == 1, """
            "Show more" is an action on what is displayed, and nothing is displayed for a cluster \
            whose load has not landed — so a tap attributed to another cluster must move nothing.
            """)

        drill.showMore(1, for: 17)
        #expect(drill.shownCount(for: 17) == 2, "and its own tap advances one page")

        drill.showMore(50, for: 17)
        #expect(drill.shownCount(for: 17) == 3, "…never past the membership it has")
    }

    @Test("An unavailable reason belongs to the cluster it was resolved for")
    func clusterDrillStateUnavailableIsPerCluster() {
        var drill = ClusterDrillState(for: ClusterDrillState.noCluster)
        drill.record(unavailable: .noArtifact, with: drill.open(for: 17))

        #expect(drill.unavailable(for: 17) == .noArtifact, "precondition")
        #expect(drill.unavailable(for: 18) == nil, """
            The empty state is per cluster too: "This cluster's data could not be loaded." under \
            a cluster whose load is merely still running is a terminal claim about a live one.
            """)
    }

    // MARK: - A superseded load's late write (#1301 round 4)

    @Test("A superseded collection load that lands late cannot erase the record on screen")
    func aStaleCollectionWriteCannotEraseTheCurrentRecord() {
        // The order the keyed task really writes in across a reuse from A to B, measured by the
        // round-3 review's probe: B's task records its timeline synchronously before its first
        // await, then A's superseded task — whose awaits no cancellation interrupts — lands its
        // related list and its counts, then B's own two arrive.
        let era = CollectionEraCount(
            era: CollectionCoverageEra(index: 0, startYear: 1945, endYear: 1952), volumeCount: 9)
        var detail = CollectionDetailLoad(for: "")
        let a = detail.open(for: "a")
        let b = detail.open(for: "b")
        detail.record(timeline: [era], with: b)
        detail.record(related: [], with: a)
        #expect(detail.related(for: "b") == nil, """
            A's related list landed as B's while B's own ranking was still running — a write \
            whose ticket names another record must be dropped, not joined.
            """)
        detail.record(localStats: IndexingPipeline.CollectionLocalStats(documentCount: 7,
                                                                        volumeCount: 2),
                      with: a)
        #expect(detail.localStats(for: "b") == nil, """
            A's 7 documents landed as B's count while B's own query was still running.
            """)
        detail.record(related: [], with: b)
        detail.record(localStats: IndexingPipeline.CollectionLocalStats(documentCount: 3,
                                                                        volumeCount: 1),
                      with: b)

        #expect(detail.timeline(for: "b").count == 1, """
            A's late write erased B's timeline. B's task wrote it before its first await and never \
            writes it again, and the Cited Over Time section is drawn only when the timeline is \
            non-empty — so the chart is gone for as long as the reader stays on B, with nothing to \
            say it ever existed. A write from a load the level has moved on from must be DROPPED, \
            not adopted.
            """)
        #expect(detail.localStats(for: "b")?.documentCount == 3, "and B's own counts landed")
        #expect(detail.related(for: "b") != nil, "and B's own related list")

        // …and the order the review's second probe found worse: A landing LAST, after every one of
        // B's writes, which under adoption took all three of B's values with it.
        detail.record(localStats: IndexingPipeline.CollectionLocalStats(documentCount: 7,
                                                                        volumeCount: 2),
                      with: a)
        #expect(detail.localStats(for: "b")?.documentCount == 3, """
            A's counts, landing after all of B's writes, replaced B's — the page would have shown \
            "still loading" under every section for as long as the reader stayed.
            """)
        #expect(detail.timeline(for: "b").count == 1, "and B's timeline survives that too")
        detail.record(timeline: [era, era], with: a)
        #expect(detail.timeline(for: "b").count == 1, """
            and a timeline written with A's ticket is dropped like the other two — the task writes \
            it synchronously, so no late one arrives today, but the rule is the value's, not the \
            caller's.
            """)
    }

    @Test("A superseded cluster load that lands late cannot erase the cluster on screen")
    func aStaleClusterWriteCannotEraseTheCurrentDrill() {
        var drill = ClusterDrillState(for: ClusterDrillState.noCluster)
        let four = drill.open(for: 4)
        let seventeen = drill.open(for: 17)
        drill.record(cluster: SemanticMapArtifacts.Cluster(id: 17, terms: [], documentCount: 2,
                                                           centreX: 0, centreY: 0, eraCounts: [:]),
                     keys: ["v/d1", "v/d2"],
                     shownCount: 2,
                     with: seventeen)
        // Cluster 4's superseded membership scan lands after 17's.
        drill.record(cluster: SemanticMapArtifacts.Cluster(id: 4, terms: [], documentCount: 1,
                                                           centreX: 0, centreY: 0, eraCounts: [:]),
                     keys: ["w/d9"],
                     shownCount: 1,
                     with: four)

        #expect(drill.cluster(for: 17)?.id == 17, """
            Cluster 4's late write erased cluster 17's drill. With both `cluster(for:)` and \
            `unavailable(for:)` answering nil the view draws its spinner, and nothing re-runs the \
            membership task — its key has not changed — so that spinner is #1301's screen on the \
            Clusters axis, reached by a write that should have been dropped.
            """)
        #expect(drill.keys(for: 17).count == 2, "and 17's members survive it")

        // The same for the other write a superseded scan can make.
        drill.record(unavailable: .noArtifact, with: four)
        #expect(drill.cluster(for: 17)?.id == 17, """
            A superseded load's "unavailable" erased the cluster on screen the same way.
            """)
        #expect(drill.unavailable(for: 17) == nil, "and it must not be reported for 17 either")
    }

    // MARK: - The gate the compilation load runs behind

    @Test("The load gate reads the index and nothing else")
    func loadGateAdmitsOnlyTheIndexQuestion() {
        #expect(CompilationDocumentsPresentation.shouldLoad(isIndexed: true), """
            An indexed volume loads. This is the whole of the gate: the `guard volume != nil` \
            #1301 deleted asked the MANIFEST a question the load never needed — one more \
            condition, on a lookup no code path below it reads. Round 2's messages here and in \
            three comments credited it with stranding a SIDE-LOADED volume; that is not \
            reachable, and saying so in the message a maintainer reads at 2 a.m. when this fires \
            would send them looking for a test that does not exist. Since #777 \
            `ManifestStore.browsableEntries` is `catalogue + localEntries`, so a volume on disk is \
            in `allSubseriesGroups` — and `isIndexed` is a `document_cache` test, so anything \
            passing this gate is on disk.
            """)
        #expect(CompilationDocumentsPresentation.shouldLoad(isIndexed: false) == false, """
            An unindexed volume does NOT load, and this is the gate's reason for existing: \
            `document_cache` answers an unindexed volume with an empty set, which records \
            `.loaded` — the one state that short-circuits — so every later kick would return \
            early. `unindexedVolumeCachesAsLoadedAndEmpty` measures that trap from the other end.
            """)
    }
}
