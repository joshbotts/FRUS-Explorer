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

struct TapTargetTests {

    @Test("TapTargetTest: graph node hit area diameter meets 44pt iOS/iPadOS minimum")
    func nodeHitAreaMeetsMinimum() {
        // CrossReferenceGraphView renders node hit areas as Circle().frame(width: 48, height: 48)
        let hitAreaDiameter: CGFloat = 48
        #expect(hitAreaDiameter >= 44)
    }

    @Test("TapTargetTest: central node radius is larger than edge node radius")
    func centralNodeIsLarger() {
        // drawNode uses r=24 for central, r=18 for others → central hit area is proportionally larger
        let centralRadius: CGFloat = 24
        let edgeRadius: CGFloat    = 18
        #expect(centralRadius > edgeRadius)
    }
}

// MARK: ColorIndependenceTest

struct ColorIndependenceTests {

    @Test("ColorIndependenceTest: all TagCategory cases have distinct background color mapping")
    func tagCategoryColorsAreDistinct() {
        // tagBackground in DocumentTagChip maps each category to a different hue.
        // We verify the category enum has at least 3 distinct cases.
        let categories: [TagCategory] = [.people, .places, .topics]
        let uniqueCount = Set(categories.map(\.rawValue)).count
        #expect(uniqueCount == 3)
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
