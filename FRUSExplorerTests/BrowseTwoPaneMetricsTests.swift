// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import CoreGraphics
import Foundation
import SwiftUI
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

// MARK: - BrowseOpenDoorTests

/// The open door's mark on Browse's corpus root (#1431), as values: the fill it paints, the rule that
/// decides whether the "Continue reading" row's document is the one open beside it, and the rule that
/// decides which document the row offers.
///
/// The mark is drawn only in the iPad two-pane, where `CorpusView` stays on screen as the list pane
/// beside the level a door opened. `BrowseRootSelectionTests` (UI, iPad only) reads its trait on a
/// device; `BrowseRootOpenMarkSourceTests` below pins where it is applied. This suite pins what it IS.
///
/// Version history:
///   1.0 — #1431: initial implementation
///   1.1 — #1431 review, round 1: `resumeEntryHoldsTheOpenRootsDocument`
@Suite("Browse root — the open door's mark")
struct BrowseOpenDoorTests {

    @Test("The open fill is Research's selected-row fill, so an open door reads alike in both two-panes")
    func openFillIsResearchs() {
        // `ResearchView.sidebarRow` (#1362) and `ReferenceListPanel.nodeRow` paint exactly this;
        // `ResearchSidebarOpenMarkSourceTests` pins their literals.
        #expect(BrowseOpenDoor.fill == Color.accentColor.opacity(0.12))
    }

    @Test("A tile paints the open fill while open and its own card colour otherwise")
    func tileFillFollowsIsOpen() {
        #expect(BrowseOpenDoor.tileFill(isOpen: true) == BrowseOpenDoor.fill,
                "an open tile must paint the same fill an open row does")
        #expect(BrowseOpenDoor.tileFill(isOpen: false) == BrowseTileChrome.cardColor,
                "a closed tile must keep the grouped list's card colour")
        #expect(BrowseOpenDoor.tileFill(isOpen: true) != BrowseTileChrome.cardColor,
                "an open tile that paints the card colour draws no mark at all")
    }

    /// One fixture per conjunct of the rule — the document, the volume, and a root that is a
    /// document at all — so no conjunct can be deleted with the suite still green.
    ///
    /// **The volume conjunct is why the rule is not `root == .document(entry)`.** `BrowserLevel`'s
    /// equality compares a document by its `documentId` alone, and document ids repeat across
    /// volumes — 543 of the local corpus's 744 volume files carry an `xml:id="d5"` — so that
    /// comparison would mark the row for another volume's document of the same id.
    @MainActor
    @Test("The resume row is open only while the root is its own document, in its own volume")
    func resumeRowOpensOnlyItsOwnDocument() {
        let open = BrowserViewModel.BrowserLevel.document(
            DocumentBrowserEntry(documentId: "d5", volumeId: "frus1969-76v17", header: "Five"))
        #expect(BrowseOpenDoor.opensDocument(volumeId: "frus1969-76v17", documentId: "d5", root: open),
                "the row's own document, open beside it, is not marked")
        #expect(!BrowseOpenDoor.opensDocument(volumeId: "frus1961-63v06", documentId: "d5", root: open),
                "another volume's d5 is marked as this row's document")
        #expect(!BrowseOpenDoor.opensDocument(volumeId: "frus1969-76v17", documentId: "d6", root: open),
                "another document of this volume is marked as this row's document")
        #expect(!BrowseOpenDoor.opensDocument(volumeId: "frus1969-76v17", documentId: "d5", root: .people),
                "a root that is not a document is marked as one")
        #expect(!BrowseOpenDoor.opensDocument(volumeId: "frus1969-76v17", documentId: "d5", root: nil),
                "the row is marked with nothing open — which is also the single-column stack")
    }

    /// The row holds on to the document it opened (#1431's review, round 1). `DocumentView` writes a
    /// history entry on every load, so the newest read moves — a cross-reference followed from the
    /// resumed document, or a document read in another tab — while the root stays where it was. The
    /// row used to offer the newest read, lost its mark, and left no door marked.
    ///
    /// One fixture per conjunct of the hold, so none can be deleted with the suite still green: the
    /// root's document, its volume, and the index filter the offer already applies.
    @MainActor
    @Test("The resume row keeps offering the open root's document when a newer read moves the history")
    func resumeEntryHoldsTheOpenRootsDocument() {
        struct Read: Equatable {
            let volumeId: String
            let documentId: String
        }
        func document(_ read: Read) -> BrowserViewModel.BrowserLevel {
            .document(DocumentBrowserEntry(documentId: read.documentId, volumeId: read.volumeId,
                                           header: read.documentId))
        }
        let resumed = Read(volumeId: "frus1969-76v17", documentId: "d5")
        let followed = Read(volumeId: "frus1969-76v17", documentId: "d9")
        let elsewhere = Read(volumeId: "frus1961-63v06", documentId: "d5")
        let bothIndexed: Set<String> = ["frus1969-76v17", "frus1961-63v06"]
        func offered(_ history: [Read], root: BrowserViewModel.BrowserLevel?,
                     indexed: Set<String> = bothIndexed) -> Read? {
            BrowseOpenDoor.resumeEntry(in: history, root: root, ids: { ($0.volumeId, $0.documentId) },
                                       isIndexed: { indexed.contains($0) })
        }

        // Newest first: the reader resumed d5, then followed a reference to d9.
        let offer = offered([followed, resumed], root: document(resumed))
        #expect(offer == resumed, """
            a newer read moved the row off the document the detail pane was opened from: it offers \
            \(String(describing: offer))
            """)
        #expect(offer.map { BrowseOpenDoor.opensDocument(volumeId: $0.volumeId, documentId: $0.documentId,
                                                         root: document(resumed)) } == true,
                "the row holds its document but no longer marks itself on it")

        // No document root — the stack, the Mac, any other door: the newest read, as before #1431.
        #expect(offered([followed, resumed], root: nil) == followed, "with nothing open the row does not offer the newest read")
        #expect(offered([followed, resumed], root: .people) == followed, "a root that is not a document held the row")
        // The volume: another volume's d5 at the root is not this history's d5.
        #expect(offered([followed, resumed], root: document(elsewhere)) == followed,
                "another volume's d5 at the root held the row on this volume's d5")
        // The document: a document of this volume that the history does not hold is not d5.
        #expect(offered([elsewhere, resumed], root: document(Read(volumeId: "frus1969-76v17", documentId: "d6")))
                == elsewhere, "d6 at the root held the row on d5, its volume's other read")
        // The index: the row never offers a read whose volume has left the index, root or not.
        #expect(offered([elsewhere, resumed], root: document(resumed), indexed: ["frus1961-63v06"]) == elsewhere,
                "the row held a document whose volume is no longer indexed")
        #expect(offered([resumed], root: document(resumed), indexed: []) == nil,
                "the row offered a read with no volume in the index")
    }
}

// MARK: - BrowseRootOpenMarkSourceTests

/// Every door on Browse's corpus root wears the open mark, keyed on the level it opens (#1431) —
/// read from the source, because the fill has no runtime signature a UI test can read.
///
/// ## What a door is, and what its mark is
/// A door is any control on the root that calls `BrowserViewModel.select(_:)` — which ASSIGNS the
/// path — or `openTopicIndex()`, which resets the Topic index and then selects `.subjects`. In the
/// iPad two-pane the root stays on screen as the list pane, so `BrowserView.twoPaneLayout` hands it
/// `vm.navigationPath.first`, and the door whose level that is must say so: the selected fill for the
/// eye and the `.isSelected` trait for VoiceOver, on the one condition. Rows take both through
/// `.browseOpenDoorMark(_:)`; the "Browse by" tiles, which paint their own card in a row whose chrome
/// is cleared, take `isOpen:` and paint the fill on the card.
///
/// ## What it reads, and what it does not
/// Calls to those two methods, on any receiver (`rootSelection`). Not a root set any other way — a
/// direct `navigationPath = [...]`, or an `append` onto an empty path, which is how
/// `consumePendingBrowseDocument` and `consumePendingBrowseVolume` hand a document or volume to a fresh
/// Browse tab. Those land a level whose door `openRoot` marks all the same when the root draws one;
/// nothing here requires it.
///
/// ## Why a source sweep and not only the UI suite
/// `BrowseRootSelectionTests` reads the trait through XCUI's `isSelected`, and a fill changes no
/// trait, so a door whose fill were deleted — or keyed on another level — passes it: the gap #1362's
/// review found in Research. That holds for the Continue reading row too: the UI suite drives it, but
/// reads only its trait, so its fill and its `openRoot: openRoot` wiring are pinned here.
///
/// **It fails naming the site.** Each check matches a call by its balanced parentheses and braces,
/// over code whose comments and string contents are blanked, so neither a comment nor a label can
/// stand in for a modifier.
///
/// Version history:
///   1.0 — #1431: initial implementation
///   1.1 — #1431 review, round 1: a root selection on ANY receiver; a hand-off is recognised by the
///          level it lands rather than by name, so #1364's Browse Within passes; the model's own root
///          selectors are pinned; the resume row's hold on its document is pinned
@Suite("Browse root — every door's open mark, as written")
struct BrowseRootOpenMarkSourceTests {

    private static let corpusView = "FRUSExplorer/Browser/CorpusView.swift"
    private static let browserView = "FRUSExplorer/Browser/BrowserView.swift"
    private static let resumeRow = "FRUSExplorer/Browser/ResumeReadingRow.swift"
    private static let viewModel = "FRUSExplorer/Browser/BrowserViewModel.swift"

    /// The level each door #1431 lists opens, spelled as the source spells it — plus the "Continue
    /// reading" row's `.document(entry)`, a root door the issue's list left out.
    private static let expectedDoorLevels: Set<String> = [
        ".document(entry)", ".volume(entry)", ".people", ".subjects", ".subseriesIndex", ".catalogue",
        ".administrations", ".editors", ".archives", ".clusters", ".scopes", ".corpora",
    ]

    /// The levels of the doors the root ALWAYS draws: every door but the search results and Continue
    /// reading, whose levels carry an argument and whose rows exist only while the search shows that
    /// volume or the history holds that document.
    private static var alwaysDrawnDoorLevels: Set<String> { expectedDoorLevels.filter { !$0.contains("(") } }

    /// A root selection as the source spells it: `select(_:)` or `openTopicIndex()` called on ANY
    /// receiver — `vm`, `viewModel`, `browser.model`, `self` — because a scan cannot read a receiver's
    /// type, and a list of receiver names let a call through an unlisted one go unseen (#1431's review,
    /// round 1). `select` must take an UNLABELLED first argument, as `BrowserViewModel.select(_:)` does,
    /// which keeps out other types' `select` — the semantic map's `select(at:size:isReadable:)` today.
    /// `theModelsRootSelectorsAreKnown` pins the model's own selectors, so a new wrapper cannot hide
    /// behind a name this pattern lacks.
    private static let rootSelection =
        #"\.\s*(?:select\s*\((?!\s*[A-Za-z_][A-Za-z0-9_]*\s*:)|openTopicIndex\s*\()"#

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func scan(_ relativePath: String) throws -> SwiftSourceScan {
        SwiftSourceScan(try String(contentsOf: repoRoot.appending(path: relativePath), encoding: .utf8))
    }

    /// The level a door's action opens: the argument of `vm.select(…)`, or `.subjects` for
    /// `vm.openTopicIndex()` (whose body the first test pins to `select(.subjects)`).
    private static func level(ofActionAt range: Range<Int>, in scan: SwiftSourceScan) -> String? {
        if scan.text(range).contains("openTopicIndex") { return ".subjects" }
        guard let close = scan.balancedEnd(from: range.upperBound - 1) else { return nil }
        return SwiftSourceScan.normalized(scan.text(range.upperBound..<(close - 1)))
    }

    @Test("Every door on the corpus root carries the open mark, keyed on the level it opens")
    func everyDoorIsMarkedOnItsOwnLevel() throws {
        let scan = try Self.scan(Self.corpusView)
        let actions = scan.matches(Self.rootSelection)
        #expect(actions.count >= Self.expectedDoorLevels.count,
                "only \(actions.count) door actions in \(Self.corpusView) — the scan is reading the wrong text")
        let elements = scan.elements(named: ["Button", "BrowseAxisTile", "BrowseAxisGridTile", "ResumeReadingRow"])

        var reached: [String] = []
        for action in actions {
            let line = scan.line(of: action.lowerBound)
            guard let level = Self.level(ofActionAt: action, in: scan) else {
                Issue.record("\(Self.corpusView):\(line): cannot read the level this door opens")
                continue
            }
            guard let door = elements.filter({ $0.range.contains(action.lowerBound) })
                .min(by: { $0.range.count < $1.range.count }) else {
                Issue.record("\(Self.corpusView):\(line): the door opening \(level) is in no Button, tile or resume row the scan can read")
                continue
            }
            reached.append(level)
            let site = "\(Self.corpusView):\(line) \(door.name) opening \(level)"
            switch door.name {
            case "Button":
                let marks = door.chain.components(separatedBy: ".browseOpenDoorMark(").count - 1
                #expect(marks == 1, "\(site) carries \(marks) `.browseOpenDoorMark` calls, not one")
                #expect(door.chain.contains(".browseOpenDoorMark(isOpen(\(level)))"), """
                    \(site) is not marked on its own level: its chain must carry \
                    `.browseOpenDoorMark(isOpen(\(level)))`. Read: \(door.chain)
                    """)
            case "BrowseAxisTile", "BrowseAxisGridTile":
                #expect(door.arguments.contains("isOpen: isOpen(\(level))"), """
                    \(site) is not handed its own level's state: its arguments must carry \
                    `isOpen: isOpen(\(level))`. Read: \(door.arguments)
                    """)
            case "ResumeReadingRow":
                #expect(level == ".document(entry)", "\(site): the resume row opens something other than its document")
                #expect(door.arguments.contains("openRoot: openRoot"),
                        "\(site) is not handed the open root, so it can never be marked. Read: \(door.arguments)")
            default:
                Issue.record("\(site): unexpected element")
            }
        }
        #expect(Set(reached) == Self.expectedDoorLevels, """
            the sweep reached the doors opening \(Set(reached).sorted()), not the ones #1431 names \
            (\(Self.expectedDoorLevels.sorted())) — a door was added or removed, or no longer calls `select(_:)`
            """)

        // `isOpen(_:)` compares the door's level with the ROOT the two-pane was opened from.
        let isOpen = try #require(scan.functionBody(named: "isOpen"),
                                  "\(Self.corpusView): no `func isOpen` for the doors to key on")
        #expect(isOpen.contains("openRoot == level"),
                "\(Self.corpusView) isOpen(_:) no longer compares the door's level with `openRoot`: \(isOpen)")
        // The Topics door's `.subjects` above holds only while `openTopicIndex()` selects it.
        let model = try Self.scan(Self.viewModel)
        let openTopicIndex = try #require(model.functionBody(named: "openTopicIndex"),
                                          "\(Self.viewModel): no `openTopicIndex()`")
        #expect(openTopicIndex.contains("select(.subjects)"),
                "openTopicIndex() no longer selects `.subjects`, so the Topics row's mark names the wrong level")
    }

    /// A root selection outside `CorpusView` is a hand-off: it lands a level the reader chose ELSEWHERE,
    /// and `openRoot` marks the door whose level that is all the same — provided the root draws that
    /// door. So what this requires of each one is the level it lands: one an ALWAYS-drawn door opens.
    ///
    /// It used to require each site by name, which is a list of today's call sites rather than a rule.
    /// #1364's Browse Within (`BrowseScopesLevel.browseWithin`, lane B4 of the same plan) calls
    /// `vm.select(.subseriesIndex)` — a correct hand-off whose mark the Subseries tile carries — and the
    /// name list would have failed it as soon as both lanes merged, with no conflict to warn anyone.
    /// Measured: this sweep's first version, run with B4's `ScopeBrowseView.swift` on disk, failed
    /// naming `browseWithin`; this one passes it.
    @Test("Every root selection outside the corpus root lands a level one of its always-drawn doors marks")
    func noRootSelectionEscapesTheSweep() throws {
        let appRoot = Self.repoRoot.appending(path: "FRUSExplorer")
        let paths = try FileManager.default.subpathsOfDirectory(atPath: appRoot.path)
            .filter { $0.hasSuffix(".swift") }
            .sorted()
        #expect(paths.count > 100, "Only \(paths.count) Swift files under FRUSExplorer/ — the scan path is wrong.")
        var handOffs: [String: String] = [:]
        var inCorpusView = 0
        for path in paths {
            let relative = "FRUSExplorer/\(path)"
            // The model's own calls are its implementation; `theModelsRootSelectorsAreKnown` pins them.
            guard relative != Self.viewModel else { continue }
            let scan = try Self.scan(relative)
            for call in scan.matches(Self.rootSelection) {
                if relative == Self.corpusView {
                    inCorpusView += 1
                    continue
                }
                let location = "\(relative):\(scan.line(of: call.lowerBound))"
                let site = "\(relative) \(scan.enclosingDeclaration(of: call.lowerBound) ?? "<no declaration>")"
                guard let level = Self.level(ofActionAt: call, in: scan) else {
                    Issue.record("\(location) (\(site)): cannot read the level this root selection lands")
                    continue
                }
                handOffs[site] = level
                #expect(Self.alwaysDrawnDoorLevels.contains(level), """
                    \(location) (\(site)) selects \(level), which none of the doors the corpus root always \
                    draws opens — so in the iPad two-pane nothing beside the detail is marked while it is \
                    open. Land a level one of those doors opens, or give this one a door in CorpusView \
                    with its mark.
                    """)
            }
        }
        #expect(inCorpusView >= Self.expectedDoorLevels.count, "the sweep found only \(inCorpusView) doors in CorpusView")
        // It must reach the hand-off every build carries, or it has proved nothing outside CorpusView.
        #expect(handOffs["\(Self.browserView) consumePendingSubjectExplorer"] == ".subjects",
                "the sweep did not read BrowserView.consumePendingSubjectExplorer's `.subjects`: \(handOffs)")
    }

    /// `rootSelection` names `select` and `openTopicIndex` because the model offers a root level
    /// through `select(_:)` and through one wrapper of it, `openTopicIndex()`. A second wrapper — a
    /// `func openArchives() { select(.archives) }` — would make every call to it a root selection the
    /// pattern cannot see, so the model is read for its calls to `select`. (Measured: that very wrapper,
    /// added to the model, fails this test naming it.)
    @Test("The model sets a root level only in `select(_:)` and `openTopicIndex()`")
    func theModelsRootSelectorsAreKnown() throws {
        let scan = try Self.scan(Self.viewModel)
        // A bare or `self.` call to the model's own `select(_:)` — not its declaration, and not a
        // labelled `select` of some other type.
        let calls = scan.matches(
            #"(?<![A-Za-z0-9_.])(?<!func\s)(?:self\s*\.\s*)?select\s*\((?!\s*[A-Za-z_][A-Za-z0-9_]*\s*:)"#)
        let selectors = Set(calls.map { scan.enclosingDeclaration(of: $0.lowerBound) ?? "<no declaration>" })
        #expect(selectors == ["openTopicIndex"], """
            \(Self.viewModel) sets a root level in \(selectors.sorted()), not only in `openTopicIndex()`. \
            A call to any of these is a root selection `rootSelection` does not name: add the method to \
            that pattern and its level to `level(ofActionAt:in:)`.
            """)
    }

    @Test("The row mark paints the open fill and announces the selected trait, both on one condition")
    func rowMarkCarriesBothHalves() throws {
        let scan = try Self.scan(Self.corpusView)
        let body = try #require(scan.typeBody(named: "BrowseOpenDoorMark"),
                                "\(Self.corpusView): no `BrowseOpenDoorMark` modifier")
        #expect(body.components(separatedBy: ".accessibilityAddTraits(isOpen ? .isSelected : [])").count - 1 == 1,
                "BrowseOpenDoorMark must announce `.isSelected` on `isOpen`, once: \(body)")
        #expect(body.components(separatedBy: ".listRowBackground(isOpen ? BrowseOpenDoor.fill : nil)").count - 1 == 1,
                "BrowseOpenDoorMark must paint `BrowseOpenDoor.fill` on `isOpen`, once: \(body)")
        #expect(body.components(separatedBy: ".listRowBackground(").count - 1 == 1,
                "BrowseOpenDoorMark sets the row background more than once, and a second call can undo the fill")
        let apply = try #require(scan.functionBody(named: "browseOpenDoorMark"),
                                 "\(Self.corpusView): no `browseOpenDoorMark(_:)`")
        #expect(apply.contains(".modifier(BrowseOpenDoorMark(isOpen: isOpen))"),
                "browseOpenDoorMark(_:) no longer applies BrowseOpenDoorMark: \(apply)")
    }

    @Test("Both tile types paint the open fill on their card and announce the selected trait")
    func tilesCarryBothHalves() throws {
        let scan = try Self.scan(Self.corpusView)
        for tile in ["BrowseAxisTile", "BrowseAxisGridTile"] {
            let body = try #require(scan.typeBody(named: tile), "\(Self.corpusView): no `\(tile)`")
            let buttons = SwiftSourceScan(body).elements(named: ["Button"])
            #expect(buttons.count == 1, "\(tile) draws \(buttons.count) buttons, not one")
            let button = try #require(buttons.first, "\(tile) draws no button")
            #expect(button.chain.contains(".accessibilityAddTraits(isOpen ? .isSelected : [])"),
                    "\(tile) no longer announces `.isSelected` on `isOpen`. Chain: \(button.chain)")
            #expect(button.closures.contains(".background(BrowseOpenDoor.tileFill(isOpen: isOpen),"),
                    "\(tile) no longer paints `BrowseOpenDoor.tileFill(isOpen: isOpen)` on its card: \(button.closures)")
            let backgrounds = button.closures.components(separatedBy: ".background(").count - 1
            #expect(backgrounds == 1, "\(tile) paints \(backgrounds) backgrounds, not one — a second can hide the fill")
        }
    }

    @Test("Only the two-pane hands the corpus root an open level; the stack never does")
    func onlyTheTwoPaneHandsTheRootAnOpenLevel() throws {
        let scan = try Self.scan(Self.browserView)
        let twoPane = SwiftSourceScan(try #require(scan.functionBody(named: "twoPaneLayout"),
                                                   "\(Self.browserView): no `twoPaneLayout`"))
        let listPanes = twoPane.elements(named: ["CorpusView"])
        #expect(listPanes.count == 1, "twoPaneLayout builds \(listPanes.count) corpus lists, not one")
        #expect(listPanes.first?.arguments == "vm: vm, showsNavigationChrome: false, openRoot: vm.navigationPath.first",
                "the two-pane's list pane is not handed the path's first level: \(listPanes.first?.arguments ?? "none")")
        let stack = SwiftSourceScan(try #require(scan.functionBody(named: "stackLayout"),
                                                 "\(Self.browserView): no `stackLayout`"))
        let roots = stack.elements(named: ["CorpusView"])
        #expect(roots.count == 1, "stackLayout builds \(roots.count) corpus lists, not one")
        #expect(roots.first?.arguments == "vm: vm", """
            the stack's root is handed more than its view model (\(roots.first?.arguments ?? "none")) — \
            the stack pushes a level over the root, so nothing stays beside it to mark
            """)
        #expect(scan.matches(#"\bopenRoot:"#).count == 1,
                "\(Self.browserView) hands `openRoot` to more than the two-pane's list pane")
    }

    @Test("The resume row holds on to the open root's document and marks itself only while it is the root")
    func resumeRowIsMarkedOnItsDocument() throws {
        let scan = try Self.scan(Self.resumeRow)
        let buttons = scan.elements(named: ["Button"]).filter { $0.closures.contains("onResume(") }
        #expect(buttons.count == 1, "\(Self.resumeRow) has \(buttons.count) buttons that resume, not one")
        let button = try #require(buttons.first, "\(Self.resumeRow): no resuming button")
        #expect(button.chain.contains(
            ".browseOpenDoorMark(BrowseOpenDoor.opensDocument(volumeId: entry.volumeId, documentId: entry.documentId, root: openRoot))"),
                "the resume row is not marked on its own document: \(button.chain)")
        // The document it offers is chosen with the root in hand (#1431's review, round 1): offering
        // the newest read instead moves the row off the document it opened, and its mark with it.
        let resumable = SwiftSourceScan.normalized(try #require(scan.propertyBody(named: "resumable"),
                                                                "\(Self.resumeRow): no `resumable`"))
        #expect(resumable.contains("BrowseOpenDoor.resumeEntry(in: history, root: openRoot,"),
                "the resume row does not choose its document with the open root in hand: \(resumable)")
    }
}

// MARK: - SwiftSourceScan

/// Swift source with every comment and every string literal's contents blanked to spaces, so brackets
/// can be counted and neither a comment nor a label can stand in for code. Offsets and line breaks
/// are kept, so a site is reported by the line it is on. Built for `BrowseRootOpenMarkSourceTests`
/// (#1431), whose root-selection sweep feeds it every Swift file under `FRUSExplorer/`.
///
/// **Raw strings are read as raw strings** (`#"…"#`, `##"…"##`, `#"""…"""#`, closed only by their own
/// quotes and hashes), since #1431's review, round 1: 36 app files carry one, and read as an ordinary
/// literal a raw string holding an odd number of quotes flipped the blanking for the rest of its line,
/// hiding any call after it. Not parsed: regex literals (`/…/`), read as code — a quote inside one would
/// open a string. The app's eight (`wholeMatch(of:)`, `prefixMatch(of:)`) hold no quote.
private struct SwiftSourceScan {

    /// One call — a name, its parenthesised arguments, its trailing closures and its modifier chain.
    struct Element {
        /// The called name, such as `Button`.
        let name: String
        /// The whole call, from the name to the end of its modifier chain.
        let range: Range<Int>
        /// The parenthesised arguments, whitespace collapsed; empty when there are none.
        let arguments: String
        /// Every trailing closure, whitespace collapsed.
        let closures: String
        /// The modifier chain after the closures, whitespace collapsed.
        let chain: String
    }

    /// The blanked source, one element per `Character`.
    let chars: [Character]

    /// Blanks `source`.
    init(_ source: String) { chars = Self.blank(Array(source)) }

    /// The blanked text in `range`.
    func text(_ range: Range<Int>) -> String { String(chars[range]) }

    /// `text` with every run of whitespace collapsed to one space, trimmed.
    static func normalized(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    /// The 1-based line `index` is on.
    func line(of index: Int) -> Int { chars[..<index].filter { $0 == "\n" }.count + 1 }

    /// Every match of `pattern` over the blanked text, as `Character` offsets.
    func matches(_ pattern: String) -> [Range<Int>] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            Issue.record("SwiftSourceScan: the pattern \(pattern) does not compile")
            return []
        }
        let string = String(chars)
        return regex.matches(in: string, range: NSRange(string.startIndex..., in: string)).compactMap {
            guard let range = Range($0.range, in: string) else { return nil }
            return string.distance(from: string.startIndex, to: range.lowerBound)
                ..< string.distance(from: string.startIndex, to: range.upperBound)
        }
    }

    /// The index just past the bracket that closes the one at `open`, or `nil` when unbalanced.
    func balancedEnd(from open: Int) -> Int? {
        var depth = 0
        for index in open..<chars.count {
            switch chars[index] {
            case "(", "{", "[": depth += 1
            case ")", "}", "]":
                depth -= 1
                if depth == 0 { return index + 1 }
            default: break
            }
        }
        return nil
    }

    /// The body of the first `func name`, braces included, or `nil`.
    func functionBody(named name: String) -> String? {
        declarationBody(#"\bfunc\s+"# + name + #"\b[^{]*\{"#)
    }

    /// The body of the first `struct`, `enum` or `class` named `name`, braces included, or `nil`.
    func typeBody(named name: String) -> String? {
        declarationBody(#"\b(struct|enum|class)\s+"# + name + #"\b[^{]*\{"#)
    }

    /// The body of the first computed property `var name`, braces included, or `nil` — its head read
    /// on one line and without an `=`, as `enclosingDeclaration(of:)` reads one.
    func propertyBody(named name: String) -> String? {
        declarationBody(#"\bvar\s+"# + name + #"\b[^{=\n]*\{"#)
    }

    /// The name of the innermost `func`, or computed property (`var name: Type {`), whose body
    /// contains `index`, or `nil`. A computed property's head is read on ONE line and without an
    /// `=`: a `var` with an `=` is stored (its braces are an observer or an initialiser's closure),
    /// and one with no brace on its line is a stored declaration the next line's brace does not
    /// belong to. (A `func`'s head may hold an `=` — a default argument — and span lines.)
    func enclosingDeclaration(of index: Int) -> String? {
        let heads = matches(#"\bfunc\s+[A-Za-z_][A-Za-z0-9_]*[^{]*\{"#)
            + matches(#"\bvar\s+[A-Za-z_][A-Za-z0-9_]*[^{=\n]*\{"#)
        var best: (name: String, body: Range<Int>)?
        for head in heads {
            guard let end = balancedEnd(from: head.upperBound - 1) else { continue }
            let body = (head.upperBound - 1)..<end
            guard body.contains(index), best.map({ body.count < $0.body.count }) ?? true else { continue }
            let signature = text(head).drop { $0.isLetter }.drop { $0.isWhitespace }
            best = (String(signature.prefix { $0.isLetter || $0.isNumber || $0 == "_" }), body)
        }
        return best?.name
    }

    private func declarationBody(_ pattern: String) -> String? {
        guard let head = matches(pattern).first,
              let end = balancedEnd(from: head.upperBound - 1) else { return nil }
        return text((head.upperBound - 1)..<end)
    }

    /// Every call to one of `names` — `Name(…)`, `Name {…}`, `Name(…) {…} label: {…}` — with its
    /// modifier chain.
    func elements(named names: [String]) -> [Element] {
        matches(#"\b("# + names.joined(separator: "|") + #")\s*[({]"#).compactMap { head in
            let name = String(text(head).prefix { $0.isLetter || $0.isNumber || $0 == "_" })
            return element(named: name, at: head.lowerBound)
        }
    }

    private func element(named name: String, at start: Int) -> Element? {
        var index = skipWhitespace(from: start + name.count)
        var arguments = ""
        if index < chars.count, chars[index] == "(" {
            guard let end = balancedEnd(from: index) else { return nil }
            arguments = text((index + 1)..<(end - 1))
            index = end
        }
        guard let afterClosures = trailingClosures(from: index) else { return nil }
        let closures = text(index..<afterClosures)
        index = afterClosures
        let chainStart = index
        while true {
            let dot = skipWhitespace(from: index)
            guard dot + 1 < chars.count, chars[dot] == ".",
                  chars[dot + 1].isLetter || chars[dot + 1] == "_" else { break }
            var cursor = dot + 1
            while cursor < chars.count, chars[cursor].isLetter || chars[cursor].isNumber || chars[cursor] == "_" {
                cursor += 1
            }
            if cursor < chars.count, chars[cursor] == "(" {
                guard let end = balancedEnd(from: cursor) else { return nil }
                cursor = end
            }
            guard let end = trailingClosures(from: cursor) else { return nil }
            index = end
        }
        return Element(name: name, range: start..<index,
                       arguments: Self.normalized(arguments),
                       closures: Self.normalized(closures),
                       chain: Self.normalized(text(chainStart..<index)))
    }

    /// The index past every trailing closure starting at `start` — the first bare, later ones
    /// labelled (`label: {…}`) — or `start` itself when there are none.
    private func trailingClosures(from start: Int) -> Int? {
        var index = start
        while true {
            let brace = skipWhitespace(from: index)
            if brace < chars.count, chars[brace] == "{" {
                guard let end = balancedEnd(from: brace) else { return nil }
                index = end
                continue
            }
            var cursor = brace
            while cursor < chars.count, chars[cursor].isLetter || chars[cursor].isNumber || chars[cursor] == "_" {
                cursor += 1
            }
            guard cursor > brace, cursor < chars.count, chars[cursor] == ":" else { return index }
            let labelled = skipWhitespace(from: cursor + 1)
            guard labelled < chars.count, chars[labelled] == "{",
                  let end = balancedEnd(from: labelled) else { return index }
            index = end
        }
    }

    private func skipWhitespace(from start: Int) -> Int {
        var index = start
        while index < chars.count, chars[index].isWhitespace { index += 1 }
        return index
    }

    // MARK: Blanking

    private static func blank(_ source: [Character]) -> [Character] {
        var out = source
        func blankOut(_ range: Range<Int>) {
            for index in range where out[index] != "\n" { out[index] = " " }
        }
        var index = 0
        while index < source.count {
            let next: Character? = index + 1 < source.count ? source[index + 1] : nil
            if source[index] == "/", next == "/" {
                let start = index
                while index < source.count, source[index] != "\n" { index += 1 }
                blankOut(start..<index)
            } else if source[index] == "/", next == "*" {
                let start = index
                var depth = 0
                repeat {
                    if source[index] == "/", index + 1 < source.count, source[index + 1] == "*" {
                        depth += 1
                        index += 2
                    } else if source[index] == "*", index + 1 < source.count, source[index + 1] == "/" {
                        depth -= 1
                        index += 2
                    } else {
                        index += 1
                    }
                } while depth > 0 && index < source.count
                blankOut(start..<index)
            } else if source[index] == "\"" {
                let (end, delimiter) = skipString(source, from: index)
                let inner = (index + delimiter)..<max(index + delimiter, end - delimiter)
                blankOut(inner.clamped(to: 0..<source.count))
                index = end
            } else if source[index] == "#", let raw = rawOpening(source, at: index) {
                let (end, closed) = skipRawString(source, from: index, hashes: raw.hashes, quotes: raw.quotes)
                let open = index + raw.hashes + raw.quotes
                let inner = open..<max(open, closed ? end - raw.quotes - raw.hashes : end)
                blankOut(inner.clamped(to: 0..<source.count))
                index = end
            } else {
                index += 1
            }
        }
        return out
    }

    /// The index past the string literal opening at `start`, and its delimiter's length (1 or 3).
    private static func skipString(_ source: [Character], from start: Int) -> (end: Int, delimiter: Int) {
        let multiline = start + 2 < source.count && source[start + 1] == "\"" && source[start + 2] == "\""
        let delimiter = multiline ? 3 : 1
        var index = start + delimiter
        while index < source.count {
            if source[index] == "\\" {
                if index + 1 < source.count, source[index + 1] == "(" {
                    index = skipInterpolation(source, from: index + 1)
                } else {
                    index += 2
                }
                continue
            }
            if multiline {
                if source[index] == "\"", index + 2 < source.count,
                   source[index + 1] == "\"", source[index + 2] == "\"" {
                    return (index + 3, 3)
                }
            } else {
                if source[index] == "\"" { return (index + 1, 1) }
                if source[index] == "\n" { return (index, 1) }
            }
            index += 1
        }
        return (index, delimiter)
    }

    /// The raw string opening at `start` — its run of `#` and then one quote or three — or `nil` when
    /// the `#` there opens something else (`#if`, `#Predicate`, `#available`).
    private static func rawOpening(_ source: [Character], at start: Int) -> (hashes: Int, quotes: Int)? {
        var index = start
        while index < source.count, source[index] == "#" { index += 1 }
        guard index < source.count, source[index] == "\"" else { return nil }
        let multiline = index + 2 < source.count && source[index + 1] == "\"" && source[index + 2] == "\""
        return (index - start, multiline ? 3 : 1)
    }

    /// The index past the raw string opening at `start`: its own quotes followed by as many `#` as
    /// opened it, and whether that close was found. An interpolation (`\#(…)`) is blanked with the rest
    /// — nothing here needs code from inside a string. A one-line raw string that meets the end of its
    /// line unclosed ends there, as an ordinary literal does.
    private static func skipRawString(_ source: [Character], from start: Int,
                                      hashes: Int, quotes: Int) -> (end: Int, closed: Bool) {
        let close = Array(repeating: Character("\""), count: quotes) + Array(repeating: Character("#"), count: hashes)
        var index = start + hashes + quotes
        while index < source.count {
            if index + close.count <= source.count, Array(source[index..<(index + close.count)]) == close {
                return (index + close.count, true)
            }
            if quotes == 1, source[index] == "\n" { return (index, false) }
            index += 1
        }
        return (index, false)
    }

    /// The index past the `)` closing the interpolation whose `(` is at `open`, skipping the strings
    /// inside it.
    private static func skipInterpolation(_ source: [Character], from open: Int) -> Int {
        var depth = 0
        var index = open
        while index < source.count {
            if source[index] == "\"" {
                index = skipString(source, from: index).end
                continue
            }
            if source[index] == "(" { depth += 1 }
            if source[index] == ")" {
                depth -= 1
                if depth == 0 { return index + 1 }
            }
            index += 1
        }
        return index
    }
}
