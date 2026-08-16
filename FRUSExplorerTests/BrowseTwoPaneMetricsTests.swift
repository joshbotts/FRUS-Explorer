// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import CoreGraphics
import Testing
@testable import FRUSExplorer

/// Browse's list-pane rule at the document level (UI review F-2 follow-up).
///
/// ## What is worth testing here
/// Not the comparison — that is one `>=`. What matters is that the rule keeps producing the
/// answers the **measurements** produced, on the two devices they were taken on, and that F-2's
/// shipped gate is not moved by accident while adding a second one.
///
/// The measurements (`TwoPaneDocumentTests`, iPadOS 26.5): a 13-inch iPad in portrait is 1032 pt
/// and gave the reader 451.5 pt between a 340 pt list and the rail; an 11-inch is 834 pt and had
/// the rail overlay the document instead. Both must lose the list pane — with the rule they
/// measured 752 pt of reader. A 13-inch in **landscape** is 1366 pt, where three columns still
/// leave 746 pt, and must keep it.
///
/// Version history:
///   1.0 — F-2 follow-up
@Suite("Browse two-pane metrics")
struct BrowseTwoPaneMetricsTests {

    /// Widths of the devices the rule was measured on, so a failure names a device.
    private let iPad13Portrait: CGFloat = 1032
    private let iPad11Portrait: CGFloat = 834
    private let iPad13Landscape: CGFloat = 1366

    @Test("F-2's shipped gate is unchanged")
    func detailPaneGateIsUnmoved() {
        // 820 is the number #914 shipped and #911/#912/#913 measured against. It is now composed
        // from its two parts rather than written down, and this pins the composition: if the
        // parts drift, every earlier measurement stops describing the shipped layout.
        #expect(BrowseTwoPaneMetrics.minimumWidth == 820)
        #expect(BrowseTwoPaneMetrics.listPaneWidth + BrowseTwoPaneMetrics.detailFloor == 820)

        #expect(BrowseTwoPaneMetrics.showsDetailPane(containerWidth: 820))
        #expect(!BrowseTwoPaneMetrics.showsDetailPane(containerWidth: 819))
        // The sidebar representation of an 11-inch iPad, which #914 records as correctly single
        // column at ~712 pt.
        #expect(!BrowseTwoPaneMetrics.showsDetailPane(containerWidth: 712))
    }

    @Test("both measured iPads give the list pane up for a document")
    func measuredDevicesCollapse() {
        #expect(!BrowseTwoPaneMetrics.showsListPane(containerWidth: iPad13Portrait,
                                                    isDocumentLevel: true),
                "a 13-inch iPad in portrait measured 451.5pt of reader between the list and the rail — the list pane must go")
        #expect(!BrowseTwoPaneMetrics.showsListPane(containerWidth: iPad11Portrait,
                                                    isDocumentLevel: true),
                "an 11-inch iPad had the rail OVERLAY the document, leaving ~213pt of visible prose — the list pane must go")
    }

    @Test("the same iPads keep the list pane at every other level")
    func measuredDevicesKeepTheListPaneOtherwise() {
        // The fix is scoped to the level that brings the rail. If this ever fails, the two-pane
        // has been withdrawn from the devices #914 shipped it for.
        #expect(BrowseTwoPaneMetrics.showsListPane(containerWidth: iPad13Portrait,
                                                   isDocumentLevel: false))
        #expect(BrowseTwoPaneMetrics.showsListPane(containerWidth: iPad11Portrait,
                                                   isDocumentLevel: false))
    }

    @Test("a container with room for all three keeps all three")
    func wideContainerKeepsTheListPane() {
        // 13-inch landscape: 1366 − 340 list − 280 rail = 746pt of reader, within a few points of
        // the 752 the same device MEASURED as a single column in portrait. The rule is a width
        // budget, not "documents are always full width", and this is the case that distinguishes
        // the two.
        #expect(BrowseTwoPaneMetrics.showsListPane(containerWidth: iPad13Landscape,
                                                   isDocumentLevel: true))
        let readerWidth = iPad13Landscape
            - BrowseTwoPaneMetrics.listPaneWidth
            - BrowseTwoPaneMetrics.researchRailWidth
        #expect(readerWidth >= BrowseTwoPaneMetrics.detailFloor,
                "a container that keeps all three panes must still honour F-2's own detail floor")
    }

    @Test("the document gate is the ordinary gate plus the rail, exactly")
    func documentGateIsDerived() {
        // The whole argument in one assertion: the rail is a third column and costs its width.
        // A hand-written 1060 here would pass while the derivation rotted.
        #expect(BrowseTwoPaneMetrics.documentMinimumWidth
                == BrowseTwoPaneMetrics.minimumWidth + BrowseTwoPaneMetrics.researchRailWidth)
        #expect(BrowseTwoPaneMetrics.showsListPane(
            containerWidth: BrowseTwoPaneMetrics.documentMinimumWidth, isDocumentLevel: true))
        #expect(!BrowseTwoPaneMetrics.showsListPane(
            containerWidth: BrowseTwoPaneMetrics.documentMinimumWidth - 1, isDocumentLevel: true))
    }

    @Test("a document with no list pane beside it always has a Back")
    func backSurvivesTheMissingListPane() {
        // The dead end this rule exists to prevent: `consumePendingBrowseDocument` APPENDS, so a
        // hand-off from Research, Search or a citation onto a fresh Browse tab is a document at
        // depth 1 — and depth 1 was exactly where the two-pane suppressed Back, on the grounds
        // that the corpus list was beside it.
        #expect(BrowseTwoPaneMetrics.showsBackControl(pathDepth: 1, listPaneShown: false),
                "a depth-1 document with the list pane given up would have no way back at all")
        #expect(BrowseTwoPaneMetrics.showsBackControl(pathDepth: 4, listPaneShown: false))
    }

    @Test("Back stays suppressed where the list pane really is the parent")
    func backIsStillSuppressedBesideTheList() {
        // The original behaviour, unchanged: with the corpus list on screen, a depth-1 Back would
        // offer to return the reader somewhere they can already see.
        #expect(!BrowseTwoPaneMetrics.showsBackControl(pathDepth: 1, listPaneShown: true))
        #expect(BrowseTwoPaneMetrics.showsBackControl(pathDepth: 2, listPaneShown: true))
    }

    @Test("Back is never offered on an empty path")
    func backNeverPopsAnEmptyPath() {
        // `removeLast()` traps on an empty array. Today a hidden list pane implies a document on
        // the path — but that implication lives in two other functions, and this is the guard that
        // does not depend on it.
        #expect(!BrowseTwoPaneMetrics.showsBackControl(pathDepth: 0, listPaneShown: false))
        #expect(!BrowseTwoPaneMetrics.showsBackControl(pathDepth: 0, listPaneShown: true))
    }

    @Test("an unmeasured container shows neither pane")
    func degenerateContainer() {
        // First layout passes report 0. Showing a list pane there would build the two-pane before
        // any width is known and flip arrangement on the next frame.
        #expect(!BrowseTwoPaneMetrics.showsDetailPane(containerWidth: 0))
        #expect(!BrowseTwoPaneMetrics.showsListPane(containerWidth: 0, isDocumentLevel: false))
        #expect(!BrowseTwoPaneMetrics.showsListPane(containerWidth: 0, isDocumentLevel: true))
    }
}
