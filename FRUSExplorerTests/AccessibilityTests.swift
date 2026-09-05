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

// MARK: - AccessibilityTests

// MARK: VoiceOverLabelTest

struct VoiceOverLabelTests {

    @Test("VoiceOverLabelTest: DisplayNode accessibilityLabel is non-empty for all node kinds")
    func displayNodeLabelsNonEmpty() {
        let central  = DisplayNode(id: "vol1/d1", kind: .central, metadata: nil, isDownloaded: true)
        let inbound  = DisplayNode(id: "vol1/d2", kind: .inbound, metadata: nil, isDownloaded: true)
        let outbound = DisplayNode(id: "vol1/d3", kind: .outbound, metadata: nil, isDownloaded: false)
        let clIn     = DisplayNode(id: "cluster/in/vol2",  kind: .clusterInbound(volumeId: "vol2", count: 3),  metadata: nil, isDownloaded: true)
        let clOut    = DisplayNode(id: "cluster/out/vol3", kind: .clusterOutbound(volumeId: "vol3", count: 5), metadata: nil, isDownloaded: true)

        for node in [central, inbound, outbound, clIn, clOut] {
            #expect(!node.accessibilityLabel.isEmpty,
                    "Expected non-empty label for node kind \(node.kind)")
        }
    }

    @Test("VoiceOverLabelTest: DisplayNode label includes document header when metadata is present")
    func displayNodeLabelIncludesHeader() {
        let meta = CrossReferenceNodeMetadata(
            documentId: "d1", volumeId: "vol1",
            documentNumber: "1", header: "Meeting of the NSC",
            dateline: "Washington, January 15, 1963"
        )
        let node = DisplayNode(id: "vol1/d1", kind: .inbound, metadata: meta, isDownloaded: true)
        #expect(node.accessibilityLabel.contains("Meeting of the NSC"))
    }
}

// MARK: TapTargetTest

/// Tap targets, measured against the values the views actually use.
///
/// **Both tests here used to be tautologies.** One asserted `48 >= 44` and the other `24 > 18`,
/// from four literals the test typed for itself — neither read a line of the app, and both would
/// have stayed green while the graph shrank its nodes to a point. The constants now live in
/// `FRUSTheme` and the radii come from the view model's own rule, so the assertions have something
/// to fail against.
struct TapTargetTests {

    @Test("Every tap-target constant meets the 44pt minimum")
    func tapTargetConstantsMeetTheMinimum() {
        #expect(FRUSTheme.minimumTapTarget == 44, "the iOS floor is 44pt")

        var checked = 0
        for (name, size) in [("graphNodeHitAreaDiameter", FRUSTheme.graphNodeHitAreaDiameter),
                             ("documentEdgeTapZoneWidth", FRUSTheme.documentEdgeTapZoneWidth)] {
            #expect(size >= FRUSTheme.minimumTapTarget,
                    "FRUSTheme.\(name) is \(size)pt, below the \(FRUSTheme.minimumTapTarget)pt minimum")
            checked += 1
        }
        #expect(checked == 2, "the tap-target sweep ran over \(checked) constants")
    }

    /// The central document reads as the centre because it is drawn largest — so the rule that
    /// sizes nodes has to keep it that way as the others grow.
    ///
    /// **Driven through the pure rule, not through the view model, and that is the whole point.**
    /// A document node's radius climbs with its corpus-wide connection count, and those counts
    /// arrive asynchronously into a `private(set)` dictionary — so a test that asked the view model
    /// saw every document at 15pt and never reached the cap. Measured before the rule was hoisted:
    /// raising that cap from 22 to 30, above the central node's fixed 24, passed unnoticed.
    ///
    /// **The invariant is not "central is biggest", and asserting that would be wrong.** A date
    /// cluster's radius climbs to a cap of exactly 24, which is the central radius, so a cluster of
    /// sixteen or more documents **ties** it. The tie is asserted rather than avoided: if either
    /// number moves, this test names which.
    @Test("The central node is drawn larger than every document, at any connection count")
    func centralNodeIsLargest() {
        typealias Graph = CrossReferenceGraphViewModel
        let central = Graph.radius(for: .central, connectionCount: 1)

        // Document-shaped nodes, swept across the whole range the rule can produce — including
        // counts far past the point where the cap binds, which is where the centre is at risk.
        var checked = 0
        for kind in [DisplayNode.Kind.inbound, .outbound, .extended,
                     .unit(collectionId: "c1", name: "Lot 62 D 1"),
                     .centralFileClass(key: "763.72", gloss: nil)] {
            for count in [1, 2, 10, 100, 10_000, 1_000_000] {
                let r = Graph.radius(for: kind, connectionCount: count)
                #expect(r < central,
                        "a \(kind) node at \(count) connections is \(r)pt, not under the central \(central)pt")
                checked += 1
            }
        }
        #expect(checked == 30, "the document sweep ran over \(checked) (kind, count) pairs")

        // A count below the floor must not underflow the rule.
        #expect(Graph.radius(for: .inbound, connectionCount: 0) >= 12)

        // Volume clusters — strictly smaller, and unmoved by their membership.
        #expect(Graph.radius(for: .clusterInbound(volumeId: "v2", count: 3), connectionCount: 1) < central)
        #expect(Graph.radius(for: .clusterOutbound(volumeId: "v2", count: 300), connectionCount: 1) < central)

        // Date clusters — never larger, and equal once they hold sixteen documents.
        func dateCluster(_ count: Int) -> CGFloat {
            Graph.radius(for: .dateCluster(label: "Jun 1967", count: count, memberKeys: []),
                         connectionCount: 1)
        }
        #expect(dateCluster(2) < central)
        #expect(dateCluster(15) < central)
        #expect(dateCluster(16) == central, "the tie is reached at sixteen members")
        #expect(dateCluster(999) == central, "the date-cluster cap and the central radius diverged")
    }

}

// MARK: ColorIndependenceTest

/// Where a hue carries meaning, something that is not a hue carries it too.
///
/// **This suite is a replacement, and the thing it replaced is the argument for it.** Its single
/// test was titled "all TagCategory cases have distinct background color mapping" and its body
/// asserted that `[.people, .places, .topics]` has three distinct raw values — true of any
/// three-case enum, and unable to fail for any reason to do with colour. It named
/// `DocumentTagChip.tagBackground`, which mapped people→blue, places→green, topics→orange.
///
/// **That function was deleted on 2026-06-04 (`844680fb`, "Remove subject tag UI"), and the test
/// stayed green for three months.** A test that had actually called `tagBackground` would have
/// been a compile error the day the subject-tag UI came out. That is the cost of the vacuous form,
/// and it is why every assertion below drives a value the app itself renders.
///
/// The app has **no category-to-colour mapping at all** any more, so what is checked here is the
/// channel that replaced it: the words.
///
/// **This suite is not the app's only colour-independence guard, and should not grow into it.**
/// `ProvenanceChip`'s three channels are pinned by ``ProvenanceChipTests``, and the semantic map's
/// era ramp by `SemanticMapRegionTests` — `noTwoErasCollide` measures all-pairs OKLab separation
/// against a 0.18 floor, and `eraLightnessIsMonotonic` pins the ramp's lightness order, which is
/// what lets that lens read early-to-late in greyscale. Each guarantee is tested where it lives;
/// a second copy here would be a second thing to drift.
///
/// Version history:
///   1.0 — replaces the vacuous `tagCategoryColorsAreDistinct`
struct ColorIndependenceTests {

    /// Subject categories are told apart by their names, which is the whole of how they are told
    /// apart — the Subjects browser heads a `Section` with each one.
    @Test("Tag categories are distinguished by name, and every name differs")
    func tagCategoriesAreDistinguishedByName() {
        var names: [String] = []
        for category in TagCategory.allCases {
            let name = category.displayName
            #expect(!name.isEmpty, "TagCategory.\(category) has no display name")
            names.append(name)
        }
        #expect(names.count == 3, "the category sweep ran over \(names.count) categories")
        #expect(Set(names).count == names.count,
                "two categories share a display name, so nothing tells them apart: \(names)")
    }

    /// `ConfidenceChip` tints itself green or orange, and the tint is decoration: the chip's own
    /// doc comment says "the **word** is the signal". These are those words.
    @Test("Archival confidence is spoken as a word, and the words differ")
    func confidenceIsSpokenAsAWord() {
        var labels: [String] = []
        for confidence in CentralFilesConfidence.allCases {
            let label = confidence.label
            #expect(!label.isEmpty, "CentralFilesConfidence.\(confidence) has no label")
            labels.append(label)
        }
        #expect(labels.count == 2, "the confidence sweep ran over \(labels.count) cases")
        #expect(Set(labels).count == labels.count,
                "both confidence levels read the same, leaving only the tint: \(labels)")
    }
}

// MARK: ReduceMotionTest

struct ReduceMotionTests {

    @Test("ReduceMotionTest: layout animation does not start when reduceMotion is true")
    @MainActor
    func reduceMotionSuppressesAnimatedLayout() {
        let vm = CrossReferenceGraphViewModel(
            centralDocumentId: "d1",
            centralVolumeId:   "vol1"
        )
        // Inject enough nodes to trigger the force-directed path (>21 nodes)
        vm.displayNodes = (0..<25).map { i in
            DisplayNode(
                id: "vol1/d\(i)",
                kind: i == 0 ? .central : (i < 13 ? .inbound : .outbound),
                metadata: nil,
                isDownloaded: true
            )
        }
        vm.onCanvasSizeChanged(CGSize(width: 400, height: 400), reduceMotion: true)
        // With reduceMotion: true the layout runs synchronously — no animation task started
        #expect(!vm.isAnimatingLayout)
    }

    @Test("ReduceMotionTest: layout animation CAN start when reduceMotion is false")
    @MainActor
    func withoutReduceMotionAnimationMayStart() {
        let vm = CrossReferenceGraphViewModel(
            centralDocumentId: "d1",
            centralVolumeId:   "vol1"
        )
        vm.displayNodes = (0..<25).map { i in
            DisplayNode(
                id: "vol1/d\(i)",
                kind: i == 0 ? .central : (i < 13 ? .inbound : .outbound),
                metadata: nil,
                isDownloaded: true
            )
        }
        vm.onCanvasSizeChanged(CGSize(width: 400, height: 400), reduceMotion: false)
        // With reduceMotion: false an animated Task is launched
        #expect(vm.isAnimatingLayout)
    }

    @Test("ReduceMotionTest: standard layout (≤20 nodes) never sets isAnimatingLayout")
    @MainActor
    func standardLayoutNeverAnimates() {
        let vm = CrossReferenceGraphViewModel(
            centralDocumentId: "d1",
            centralVolumeId:   "vol1"
        )
        vm.displayNodes = (0..<10).map { i in
            DisplayNode(
                id: "vol1/d\(i)",
                kind: i == 0 ? .central : (i < 5 ? .inbound : .outbound),
                metadata: nil,
                isDownloaded: true
            )
        }
        // Both with and without reduceMotion, standard layout is synchronous
        vm.onCanvasSizeChanged(CGSize(width: 400, height: 400), reduceMotion: false)
        #expect(!vm.isAnimatingLayout)
    }
}

// MARK: - TabBarAccessibilityTests

/// Accessibility and badge behaviour tests for the iOS tab bar introduced in Sessions 43–45.
///
/// iOS-guarded where the `AppTab` type is unavailable on macOS.
///
/// Version history:
///   1.0 — Session 45: initial implementation
#if os(iOS)
@MainActor
struct TabBarAccessibilityTests {

    private let tabKey  = "frus.activeTab"
    private let visitKey = "frus.lastActivityTabVisit"

    private func cleanup() {
        UserDefaults.standard.removeObject(forKey: tabKey)
        UserDefaults.standard.removeObject(forKey: visitKey)
    }

    @Test("tabTitleRawValuesAreNonEmpty — all five AppTab cases have a non-empty rawValue")
    func tabTitleRawValuesAreNonEmpty() {
        for tab in AppTab.allCases {
            #expect(!tab.rawValue.isEmpty,
                    "AppTab.\(tab) has an empty rawValue")
        }
    }

    @Test("researchTabExists — AppTab has .research case replacing former .activity case")
    func researchTabExists() {
        // The Activity tab was replaced by Research in Session 130. Verify the case exists and
        // round-trips through the persisted seed (#316: the shared `activeTab` is gone; the seed
        // is `AppState.seedActiveTab` / `persistTabSeed`).
        AppState.persistTabSeed(.research)
        #expect(AppState.seedActiveTab == .research)
        // lastActivityTabVisit is retained in AppState for potential future badge use, but is no
        // longer stamped by any tab write.
        let state = AppState()
        let baseline = state.lastActivityTabVisit
        AppState.persistTabSeed(.browse)
        #expect(state.lastActivityTabVisit == baseline,
                "lastActivityTabVisit should not change when the tab seed is written")
    }

    @Test("settingsTabBadgeReturnsZeroWhenInfrastructureAbsent — no crash on nil pipeline or dm")
    func settingsTabBadgeReturnsZeroWhenInfrastructureAbsent() {
        // Fresh AppState has nil downloadManager and nil indexingPipeline.
        let state = AppState()
        // unindexedVolumeCount must return 0 rather than crash.
        #expect(state.unindexedVolumeCount == 0)
    }
}
#endif
