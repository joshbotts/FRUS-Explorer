// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import XCTest

/// What happens when a **document** lands in F-2's two-pane detail pane (UI review F-2 follow-up).
///
/// ## The interaction, and why it was left unverified
/// `#914` shipped the two-pane and its probe drilled three levels — subseries, volume,
/// compilation. It never opened a *document*, and the document level is the one that brings a
/// second pane of its own: `DocumentView` presents the Research rail as a trailing `.inspector`
/// on every non-phone idiom, defaulting **open** (`panelVisible = true`, and `.rememberLast`
/// leaves it alone). So a document in the detail pane asks for three columns in a container that
/// was gated for two.
///
/// The arithmetic is the finding, and it does not depend on which container the inspector
/// resolves against: a rail is a fixed-width column either way, so the reader gets
/// `container − listPane − rail`. At F-2's own 820 pt gate that is roughly **160 pt of document**.
/// The app already states the floor it violates — `MacDocumentView.railOverlayBreakpoint`
/// (`:349`) exists so the Mac's reading column "never reflows below its ~340 pt floor".
///
/// ## Why this suite seeds a volume instead of joining `UIObstructionTests`
/// Reaching a document needs one on disk. `CompilationDocumentsTests` established the seam for
/// that (`FRUS_UI_TEST_SEED_VOLUME` + `-frus.filterDownloadedOnly YES`), and this suite reuses its
/// navigation verbatim. It is a separate `XCTestCase` for the same reason that one is: the launch
/// configuration differs from `UIObstructionTests`', and the two cannot share a host.
///
/// ## The recorded hazard this suite walks into deliberately
/// `CompilationDocumentsTests`' coverage ledger records that a `testDocumentRowOpensReader` was
/// written, run, and **removed**: after the reader pushed, every XCUI query timed out with
/// "Failed to get matching snapshots" for ~200 s, on iPhone 17 Pro. Two causes were left
/// unseparated — a fixture the loader waits on, or the accessibility snapshot and the `WKWebView`
/// bring-up wedging each other.
///
/// This suite therefore measures **before** it asserts, prints every number it takes, and keeps
/// its post-open queries to the cheapest forms available. If the wedge reproduces here, that is
/// itself the result: it means the interaction is not reachable by this harness on iPad either,
/// and the geometry has to be settled another way.
///
/// Version history:
///   1.0 — F-2 follow-up: the document-into-the-detail-pane interaction
@MainActor
final class TwoPaneDocumentTests: XCTestCase {

    /// The manifest volume the fixture is written for — the same one `CompilationDocumentsTests`
    /// seeds, so a single `UITestVolumeSeeder` fixture serves both suites.
    private static let seededVolumeId = "frus1961-63v06"

    /// The compilation `<head>` in the seeded fixture. Must match `UITestVolumeSeeder`.
    private static let compilationTitle = "UI Test Compilation"

    /// The first document `<head>` in the seeded fixture. Must match `UITestVolumeSeeder`.
    private static let firstDocumentTitle = "UI Test Document One"

    /// The list pane's width in `BrowserView` (`twoPaneLayout`, `listPaneWidth`).
    private static let listPaneWidth: CGFloat = 340

    var app: XCUIApplication!

    /// Resolves tab destinations across every representation, including the floating iPad bar when
    /// it has paged a tab off screen. Shared with every other suite — this was one of six
    /// hand-copied ladders, none of which could page.
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_VOLUME"] = Self.seededVolumeId
        app.launchArguments = UITestLaunch.arguments() + [
            "-frus.filterDownloadedOnly", "YES",
        ]
        app.launch()
    }

    override func tearDown() async throws {
        app = nil
    }

    // MARK: - Navigation (borrowed from CompilationDocumentsTests)

    @discardableResult
    private func selectSection(_ label: String,
                               file: StaticString = #filePath, line: UInt = #line) -> Bool {
        guard let destination = TabDestination(rawValue: label) else {
            XCTFail("'\(label)' is not one of MainTabView's five tabs", file: file, line: line)
            return false
        }
        return navigator.select(destination, file: file, line: line).tapped
    }

    private var subseriesRow: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Subseries '")).firstMatch
    }

    private var volumeRow: XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Kennedy-Khrushchev'")).firstMatch
    }

    private var compilationRow: XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", Self.compilationTitle)).firstMatch
    }

    private var documentRow: XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", Self.firstDocumentTitle)).firstMatch
    }

    /// Swipes up until `element` is present and hittable. SwiftUI `List` is lazy, so a row below
    /// the fold is absent from the accessibility tree, not merely invisible.
    private func scrollDownUntil(_ element: XCUIElement, attempts: Int) {
        for _ in 0..<attempts {
            if element.exists && element.isHittable { return }
            app.swipeUp(velocity: .slow)
            Thread.sleep(forTimeInterval: 0.4)
        }
    }

    /// Counts the cells on each side of the pane divider and reports the widest.
    @discardableResult
    private func panes(_ step: String) -> (list: Int, detail: Int, widest: CGFloat) {
        var list = 0, detail = 0, widest = CGFloat(0)
        let divider = Self.listPaneWidth
        for index in 0..<app.cells.count {
            let frame = app.cells.element(boundBy: index).frame
            if frame.maxX <= divider + 12 { list += 1 }
            if frame.minX >= divider - 12 { detail += 1 }
            widest = max(widest, frame.width)
        }
        print("[F-2 doc] \(step): list=\(list) detail=\(detail) widest=\(widest)")
        return (list, detail, widest)
    }

    // MARK: - The probe

    /// Opens a document into the two-pane detail pane and measures what the reader is left with.
    func testDocumentInTwoPaneDetailPane() throws {
        #if canImport(UIKit)
        try XCTSkipUnless(
            UIDevice.current.userInterfaceIdiom == .pad,
            "iPad-only: the two-pane gate requires a pad idiom and 820pt of content width"
        )
        #else
        throw XCTSkip("UIKit-only test")
        #endif

        selectSection("Browse")

        let window = app.windows.firstMatch.frame
        print("[F-2 doc] window=\(window)")

        // The two-pane placeholder is the layout probe. Skipping on its absence rather than
        // asserting a width lets this run on ANY iPad and report honestly which side of the gate
        // that device falls on — which is the question for the 11-inch, whose 834pt sits 14pt
        // above the gate.
        try XCTSkipUnless(
            app.staticTexts["Choose a Subseries"].waitForExistence(timeout: 10),
            "Browse is a single column at \(window.width)pt — this device is below the two-pane "
                + "gate, so the interaction does not arise here"
        )

        // #1051 B-1 (root 2a): the subseries list moved one tap deep behind the root's
        // "Subseries" tile (in the persistent list pane); the directory renders in the
        // detail pane and the rows keep their labels.
        let subseriesTile = app.buttons["browse.root.subseriesTile"].firstMatch
        XCTAssertTrue(subseriesTile.waitForExistence(timeout: 15),
                      "The Browse root's Subseries tile did not appear in the list pane")
        subseriesTile.tap()
        Thread.sleep(forTimeInterval: 1.0)

        XCTAssertTrue(subseriesRow.waitForExistence(timeout: 15),
                      "No subseries row with filterDownloadedOnly=YES — the fixture volume was "
                          + "probably not seeded")
        subseriesRow.tap()
        Thread.sleep(forTimeInterval: 1.0)
        panes("subseries")

        XCTAssertTrue(volumeRow.waitForExistence(timeout: 10), "The seeded volume's row is absent")
        volumeRow.tap()
        Thread.sleep(forTimeInterval: 1.0)
        panes("volume")

        scrollDownUntil(compilationRow, attempts: 8)
        XCTAssertTrue(compilationRow.waitForExistence(timeout: 15),
                      "The seeded volume's compilation row did not appear")
        compilationRow.tap()
        Thread.sleep(forTimeInterval: 1.0)

        let indexNow = app.buttons["Index Now"]
        if indexNow.waitForExistence(timeout: 5), indexNow.isEnabled { indexNow.tap() }

        XCTAssertTrue(documentRow.waitForExistence(timeout: 60),
                      "No document rows at the compilation level")
        let compilationPanes = panes("compilation")
        XCTAssertGreaterThan(compilationPanes.list, 0,
                             "the corpus list is gone before the document even opened")

        // ── The interaction this suite exists for ──────────────────────────────────────────
        print("[F-2 doc] opening the document…")
        documentRow.tap()
        Thread.sleep(forTimeInterval: 6.0)

        // Cheapest post-open query first. If the recorded wedge reproduces, it stalls here and
        // the ~200 s stall IS the result — see the class docstring.
        print("[F-2 doc] after open: navBars=\(app.navigationBars.count)")

        let webViews = app.webViews
        print("[F-2 doc] webViews=\(webViews.count)")
        guard webViews.count > 0 else {
            XCTFail("The document did not render a web view — nothing below measures the reader")
            return
        }
        let reader = webViews.firstMatch.frame
        print("[F-2 doc] webView frame=\(reader)")

        let addNote = app.buttons["Add Note"]
        print("[F-2 doc] Add Note (rail) exists=\(addNote.exists) "
              + "frame=\(addNote.exists ? "\(addNote.frame)" : "n/a")")
        XCTAssertTrue(addNote.exists,
                      "The Research rail is not present, so this run says nothing about the "
                          + "three-column arrangement it exists to measure")

        let after = panes("document")

        // The rule: below `documentMinimumWidth` (1100 = F-2's 820 gate + a 280pt rail) the list
        // pane is given up so the reader gets the width. Every iPad in portrait is below it.
        //
        // The oracle is the reader's LEFT EDGE, not the cell count. Before the fix the web view
        // began at x=340.5 on both devices measured — exactly the list pane's width — so a
        // leading edge near zero is the fix and nothing else produces it. Cell counts are a
        // corroborating check: `list` counts cells left of the divider, and the corpus list is
        // the only thing that puts any there.
        XCTAssertLessThan(
            reader.minX, 100,
            "The document begins at x=\(reader.minX) in a \(window.width)pt window — the corpus "
                + "list pane is still taking 340pt beside a reader that also has a 240pt Research "
                + "rail. Measured before the fix: 340.5 on both a 13-inch and an 11-inch iPad."
        )
        XCTAssertGreaterThan(
            reader.width, window.width * 0.6,
            "The reader is \(reader.width)pt of a \(window.width)pt window. Three columns left it "
                + "451.5pt on a 13-inch iPad — below the document's own 70ch measure, and below "
                + "the ~340pt floor MacDocumentView.railOverlayBreakpoint refuses to cross."
        )
        XCTAssertEqual(
            after.list, 0,
            "Cells are still present left of the divider at the document level — the corpus list "
                + "pane was not given up (F-2 follow-up)"
        )

        // Back must survive the list pane, or the reader is stranded — and at depth 1, which a
        // hand-off from Research or Search produces, it is the ONLY way out.
        let back = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Back'")).firstMatch
        XCTAssertTrue(back.exists,
                      "The detail pane offers no Back with the list pane gone — the document is a "
                          + "dead end")
        back.tap()
        Thread.sleep(forTimeInterval: 1.5)
        let restored = panes("after Back")
        XCTAssertGreaterThan(restored.list, 0,
                             "Going back from the document did not restore the corpus list pane")

        // ── The depth-1 case, driven rather than reasoned about ────────────────────────────
        //
        // Everything above is at depth 4, where Back renders from `pathDepth > 1` and would render
        // with the coupling removed. This is the case that discriminates: `ResumeReadingRow` calls
        // `vm.select(.document(entry))`, which REPLACES the path — a document at depth 1, the same
        // shape `consumePendingBrowseDocument` produces for a hand-off from Research, Search or a
        // citation. Depth 1 is exactly where the two-pane suppressed Back, on the grounds that the
        // corpus list was beside it, and it is the list this fix gives up.
        //
        // Reachable here only because the document above was actually read: the row renders
        // nothing without reading history. If it is absent the case is unexercised and this says
        // so, rather than passing quietly.
        vm_resumeReading()
    }

    /// Drills the corpus root's "Continue reading" row and asserts the depth-1 document is not a
    /// dead end. Split out for a legible failure, not because it stands alone — it needs the
    /// reading history the scenario above creates.
    private func vm_resumeReading() {
        // Scroll back to the top of the list pane: the compilation walk left it scrolled, and the
        // resume row is the FIRST row in `CorpusView`.
        app.swipeDown(velocity: .slow)
        Thread.sleep(forTimeInterval: 0.6)

        let resume = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Continue reading'")).firstMatch
        guard resume.waitForExistence(timeout: 5) else {
            XCTFail("No 'Continue reading' row after reading a document, so the depth-1 case — a "
                    + "document that REPLACES the path rather than extending it — went untested. "
                    + "That is the case where a missing Back is a dead end.")
            return
        }
        resume.tap()
        Thread.sleep(forTimeInterval: 5.0)

        let after = panes("resume (depth 1)")
        XCTAssertEqual(after.list, 0,
                       "The list pane survived a depth-1 document — the level gate reads the path's "
                           + "last element, and `select(_:)` replaces the path rather than appending")

        let back = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Back'")).firstMatch
        XCTAssertTrue(
            back.exists,
            "A depth-1 document has no Back and no list pane — a dead end. This is the coupling "
                + "`BrowseTwoPaneMetrics.showsBackControl` exists for: the old `depth > 1` rule was "
                + "correct only while the corpus list was guaranteed to be beside the document."
        )
    }
}

// MARK: - BrowseRootSelectionTests

/// The door open in Browse's iPad two-pane is marked in the corpus list beside it — and it is the only
/// door marked (#1431).
///
/// ## Why a UI test, and what it reads
/// The two-pane (F-2) keeps `CorpusView` on screen as a list pane beside the level a door opened, and
/// every door there is a plain `Button` row or a tile that paints its own card; neither draws a selected
/// state. Before #1431 nothing told the reader — or VoiceOver — which door the detail pane had come from.
/// The fix is two halves on one condition, keyed on `vm.navigationPath.first`: the selected fill and the
/// `.isSelected` trait. **This suite reads the trait and only the trait.** XCUI's `isSelected` reports it
/// and a fill changes no trait, so a door whose fill were deleted would pass every assertion here.
/// `BrowseRootOpenMarkSourceTests`, in the unit target, pins both halves on every door in the source;
/// whether the fill is visible is checked by eye, from the screenshots this suite keeps.
///
/// ## Where it can fail, and where it skips
/// It can fail only on an iPad whose Browse content area — the width `BrowserView`'s 820 pt gate
/// measures, which the tab sidebar narrows — reaches the gate. On an iPhone every test skips as iPad-only
/// before launching, measuring no width: the stack pushes a door's level over the root and no list stays
/// on screen to mark, so an iPhone run is a skip, not a guard. On an iPad under the gate the tests skip,
/// naming the width they measured; over it they never skip, and a two-pane that is not there fails, as
/// does a door the representation toggle loses. The resume-row test needs the DOCUMENT gate instead —
/// 1,100 pt, since the list pane survives a document only with room for the Research rail as well — which
/// in landscape an iPad Pro 13-inch reaches in the floating representation and not in the sidebar, so it
/// switches to the floating bar itself and skips below 1,100 pt naming the width. Run on iPad Pro 13-inch
/// or iPad Air 13-inch; the suite turns the device to landscape itself.
///
/// ## Both tab-bar representations
/// The first test runs in whichever representation the install has; the second toggles to the other and
/// asserts the open door survived and is still marked there. `tearDown` restores the install's own
/// representation while the device is still in landscape, then the orientation the test found — the
/// order #1367's review measured to matter.
///
/// ## Oracles
/// - Doors are found by identifier, and ALL of them at once by the `browse.root.` prefix, read from one
///   snapshot of the tree per sweep. A sweep must find every door it expects, or "no other door is
///   marked" would hold over an empty set; one that does not fails under its own tag.
/// - Arrival is checked apart from the mark, so a tap that did not take cannot read as a missing mark:
///   the navigation bar names the level (#1367 gave the two-pane's one bar the detail level's title) and
///   the empty-path placeholder has gone.
/// - Two controls that `isSelected` is neither on for every door nor stuck on the last one tapped: before
///   any door is opened NO door is marked, and with a volume open from the root search, clearing the
///   search brings the doors back with none marked, since none of them opened it.
///
/// Version history:
///   1.0 — #1431: initial implementation
@MainActor
final class BrowseRootSelectionTests: XCTestCase {
    /// Resolves tab destinations across every representation.
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    private var app: XCUIApplication!

    /// The `.sidebarAdaptable` representation this launch found, restored in `tearDown`.
    private var baselineSidebarExpanded = false

    /// The orientation the test found, restored in `tearDown` after the representation.
    private var baselineOrientation: UIDeviceOrientation = .portrait

    /// Carried by every assertion about the mark, so an A/B can confirm a failure happened there and not
    /// at a precondition.
    private static let unmarked = "OPEN DOOR NOT MARKED ALONE"

    /// Carried by the sweep's precondition — every expected door found — so a sweep that finds none (an
    /// identifier renamed, a tree not yet drawn) fails under this tag and never under `unmarked`.
    private static let doorsMissing = "BROWSE DOORS NOT FOUND"

    /// `BrowseTwoPaneMetrics.minimumWidth`, which this target cannot import.
    private static let twoPaneGate: CGFloat = 820

    /// `BrowseTwoPaneMetrics.documentMinimumWidth`: the gate plus the 280 pt Research rail.
    private static let documentGate: CGFloat = 1100

    /// The volume `UITestVolumeSeeder` writes for the resume-row test — the one the other two-pane
    /// suites seed.
    private static let seededVolumeId = "frus1961-63v06"

    /// The corpus root's identifier prefix, and the identifiers of its doors (`CorpusView`).
    private static let prefix = "browse.root."
    private static let people = prefix + "peopleRow"
    private static let topics = prefix + "topicsRow"
    private static let subseriesTile = prefix + "subseriesTile"
    private static let archivesTile = prefix + "archivesTile"
    private static let resumeRow = prefix + "resumeRow"

    /// A root-search result row's identifier.
    private static func searchResult(_ volumeId: String) -> String { prefix + "searchResult." + volumeId }

    /// Every door the root always draws, with the title its level gives the navigation bar.
    private static let doors: [(identifier: String, title: String)] = [
        (people, "People"),
        (topics, "Topics"),
        (subseriesTile, "Subseries"),
        (prefix + "catalogueTile", "All Volumes"),
        (prefix + "administrationsTile", "Administrations"),
        (prefix + "editorsTile", "Editors"),
        (archivesTile, "Archives"),
        (prefix + "clustersTile", "Clusters"),
        (prefix + "scopesRow", "My Scopes"),
        (prefix + "corporaRow", "Working Corpora"),
    ]

    /// The identifiers of `doors`.
    private static var doorIdentifiers: Set<String> { Set(doors.map(\.identifier)) }

    override func setUp() async throws {
        continueAfterFailure = false
        let found = XCUIDevice.shared.orientation
        baselineOrientation = found.isValidInterfaceOrientation ? found : .portrait
        XCUIDevice.shared.orientation = .landscapeLeft
    }

    override func tearDown() async throws {
        // Restore the install's representation whoever displaced it, while still in landscape, and
        // wait for it to read as found before rotating back (#1367's review measured the order).
        if app != nil, navigator.sidebarIsExpanded != baselineSidebarExpanded,
           let toggle = navigator.sidebarToggleButton(timeout: 2) {
            toggle.tap()
            _ = waitUntil(5) { navigator.sidebarIsExpanded == baselineSidebarExpanded }
        }
        XCUIDevice.shared.orientation = baselineOrientation
        app = nil
    }

    // MARK: - Tests

    /// In the launch representation: no door marked before one is opened; then each door the root
    /// always draws, opened in turn, is the only one marked; a level opened inside a door keeps that door
    /// marked, and so do Back and leaving the tab.
    func testEachOpenDoorAloneIsMarked() throws {
        try requirePad()
        launch()
        try openBrowseTwoPane()
        let representation = representationName

        assertMarked(nil, among: Self.doorIdentifiers, "before any door is opened", representation)

        for door in Self.doors {
            row(door.identifier).tap()
            assertArrived(at: door.title, "opening \(door.title)", representation)
            assertMarked(door.identifier, among: Self.doorIdentifiers, "after opening \(door.title)", representation)
            if door.identifier == Self.people || door.identifier == Self.archivesTile {
                attachScreenshot("#1431 \(door.title) open — \(representation)")
            }
        }

        // A level opened INSIDE a door keeps the door marked: the mark follows the path's root.
        row(Self.subseriesTile).tap()
        assertArrived(at: "Subseries", "opening Subseries again", representation)
        let subseries = app.buttons.matching(NSPredicate(
            format: "label BEGINSWITH 'Subseries ' AND identifier != %@", Self.subseriesTile)).firstMatch
        XCTAssertTrue(subseries.waitForExistence(timeout: 15),
                      "the subseries directory drew no subseries row [\(representation)]")
        subseries.tap()
        XCTAssertTrue(backControl.waitForExistence(timeout: 10),
                      "opening a subseries did not deepen the detail pane [\(representation)]")
        assertMarked(Self.subseriesTile, among: Self.doorIdentifiers, "after opening a subseries inside it",
                     representation)

        backControl.tap()
        assertArrived(at: "Subseries", "Back from the subseries", representation)
        assertMarked(Self.subseriesTile, among: Self.doorIdentifiers, "after Back", representation)

        XCTAssertTrue(navigator.select(.research).tapped, "no Research tab [\(representation)]")
        XCTAssertTrue(navigator.select(.browse).tapped, "no Browse tab on return [\(representation)]")
        assertArrived(at: "Subseries", "returning to Browse", representation)
        assertMarked(Self.subseriesTile, among: Self.doorIdentifiers, "after leaving the tab and returning",
                     representation)
    }

    /// In the OTHER representation: the open door and its mark survive the toggle, and a door opened
    /// there is marked alone.
    func testTheMarkHoldsInTheOtherTabBarRepresentation() throws {
        try requirePad()
        launch()
        try openBrowseTwoPane()
        let launched = representationName

        row(Self.archivesTile).tap()
        assertArrived(at: "Archives", "opening Archives", launched)
        assertMarked(Self.archivesTile, among: Self.doorIdentifiers, "after opening Archives", launched)

        let toggle = try XCTUnwrap(navigator.sidebarToggleButton(timeout: 5),
                                   "no sidebar toggle — the other representation cannot be reached [\(launched)]")
        toggle.tap()
        XCTAssertTrue(waitUntil { navigator.sidebarIsExpanded != baselineSidebarExpanded },
                      "the toggle did not change the tab-bar representation from \(launched)")
        let toggled = representationName

        // The skip keys on the width the gate measures and on nothing else. Archives leaving the
        // detail while the content area is still over the gate is a lost door, and fails below.
        let width = try contentWidth(toggled)
        try XCTSkipIf(width < Self.twoPaneGate, """
            In the \(toggled) representation Browse's content area is \(Int(width)) pt, under the 820 pt \
            two-pane gate, so no list stays beside the detail to mark. Run on iPad Pro 13-inch or iPad Air \
            13-inch.
            """)
        XCTAssertTrue(waitUntil(5) { row(Self.archivesTile).isHittable }, """
            TWO-PANE LOST ON THE TOGGLE: Browse's content area is \(Int(width)) pt, over the 820 pt gate, \
            but the corpus list is not on screen beside the detail [\(toggled)]
            """)
        XCTAssertTrue(app.navigationBars["Archives"].waitForExistence(timeout: 10), """
            DOOR LOST ON THE TOGGLE: Archives left the detail pane when the representation changed, though \
            Browse's content area is \(Int(width)) pt and still two-pane [\(toggled)]. Bars: \(barIdentifiers)
            """)
        assertMarked(Self.archivesTile, among: Self.doorIdentifiers, "after toggling to the other representation",
                     toggled)
        attachScreenshot("#1431 Archives open — \(toggled)")

        row(Self.people).tap()
        assertArrived(at: "People", "opening People", toggled)
        assertMarked(Self.people, among: Self.doorIdentifiers, "after opening People", toggled)
        attachScreenshot("#1431 People open — \(toggled)")
    }

    /// The root search's result rows are doors too: the one opened is marked alone, the mark moves with
    /// the next, and clearing the search brings the doors back with none marked.
    func testTheOpenSearchResultAloneIsMarked() throws {
        try requirePad()
        launch()
        try openBrowseTwoPane()
        let representation = representationName

        let field = app.textFields["browse.root.searchField"]
        XCTAssertTrue(field.waitForExistence(timeout: 15), "no root search field [\(representation)]")
        field.tap()
        // Thirteen manifest volumes carry "frus1945" in their id; these two are the fourth and fifth.
        field.typeText("frus1945")
        let malta = Self.searchResult("frus1945Malta")
        let unitedNations = Self.searchResult("frus1945v01")
        let results: Set<String> = [malta, unitedNations]
        assertMarked(nil, among: results, "before a result is opened", representation)

        row(malta).tap()
        assertArrivedAtVolume(titled: "Malta and Yalta", listRow: malta, "opening the Malta result", representation)
        assertMarked(malta, among: results, "after opening the Malta result", representation)

        row(unitedNations).tap()
        assertArrivedAtVolume(titled: "The United Nations", listRow: unitedNations,
                              "opening the United Nations result", representation)
        assertMarked(unitedNations, among: results, "after moving to the United Nations result", representation)
        attachScreenshot("#1431 search result open — \(representation)")

        // The volume stays open; the doors come back; none of them opened it. Tapping a result scrolled
        // the list pane to it, and the lazy list drops the search field's row from the tree once it is
        // off screen (measured), so scroll the list pane back to the top first — by dragging a result
        // row, which only the list pane holds.
        let clear = app.buttons["Clear volume search"]
        for _ in 0..<6 where !clear.exists {
            row(unitedNations).swipeDown(velocity: .fast)
        }
        XCTAssertTrue(clear.waitForExistence(timeout: 5), "no Clear volume search control [\(representation)]")
        clear.tap()
        assertMarked(nil, among: Self.doorIdentifiers, "after clearing the search with a volume open",
                     representation)
    }

    /// The "Continue reading" row is a door as well — it SELECTS its document — so it is marked while
    /// that document is the open root, and not while the same document is open under another door.
    func testTheResumeRowIsMarkedWhileItsDocumentIsOpen() throws {
        try requirePad()
        launch(seedingVolume: true)
        XCTAssertTrue(navigator.select(.browse, resolveTimeout: 10).tapped, "no Browse tab")
        // The list pane stays beside a document only where the Research rail fits as well; in landscape
        // the sidebar takes that width on a 13-inch iPad, so this test runs in the floating bar.
        if navigator.sidebarIsExpanded {
            let toggle = try XCTUnwrap(navigator.sidebarToggleButton(timeout: 5),
                                       "no sidebar toggle to reach the floating tab bar")
            toggle.tap()
            XCTAssertTrue(waitUntil { !navigator.sidebarIsExpanded }, "the toggle did not collapse the sidebar")
        }
        let representation = representationName
        let width = try contentWidth(representation)
        try XCTSkipIf(width < Self.documentGate, """
            Browse's content area is \(Int(width)) pt in the \(representation) representation — under the \
            1,100 pt document gate, where the list pane gives way to a document and nothing stays beside \
            it to mark. Run on iPad Pro 13-inch or iPad Air 13-inch.
            """)
        XCTAssertTrue(detailPlaceholder.waitForExistence(timeout: 10), """
            TWO-PANE LOST: Browse's content area is \(Int(width)) pt [\(representation)], over the gate, but \
            the two-pane's detail placeholder never appeared.
            """)

        // Read the fixture's first document through the Subseries door, so reading history offers it.
        row(Self.subseriesTile).tap()
        let subseries = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Subseries '")).firstMatch
        XCTAssertTrue(subseries.waitForExistence(timeout: 15), "no seeded subseries row — the fixture was not seeded")
        subseries.tap()
        let volume = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Kennedy-Khrushchev'")).firstMatch
        XCTAssertTrue(volume.waitForExistence(timeout: 10), "the seeded volume's row is absent")
        volume.tap()
        let compilation = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'UI Test Compilation'")).firstMatch
        XCTAssertTrue(compilation.waitForExistence(timeout: 15), "the seeded compilation's row is absent")
        compilation.tap()
        let indexNow = app.buttons["Index Now"]
        if indexNow.waitForExistence(timeout: 5), indexNow.isEnabled { indexNow.tap() }
        let document = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'UI Test Document One'")).firstMatch
        XCTAssertTrue(document.waitForExistence(timeout: 60), "no document rows at the seeded compilation")
        document.tap()
        XCTAssertTrue(waitUntil(20) { app.webViews.count > 0 }, "the document did not open a reader")

        let resume = row(Self.resumeRow)
        XCTAssertTrue(resume.waitForExistence(timeout: 15),
                      "no Continue reading row after reading a document [\(representation)]")
        let required = Self.doorIdentifiers.union([Self.resumeRow])
        // The document is open — but under the Subseries door, which is the door marked.
        assertMarked(Self.subseriesTile, among: required, "with the document open under Subseries", representation)

        resume.tap()
        // Depth 1 beside the list pane has no Back: the arrival, checked apart from the mark.
        XCTAssertTrue(waitUntil(10) { !backControl.exists && app.webViews.count > 0 },
                      "Continue reading did not reopen its document at the root [\(representation)]")
        assertMarked(Self.resumeRow, among: required, "after Continue reading", representation)
        attachScreenshot("#1431 Continue reading open — \(representation)")
    }

    // MARK: - Steps and oracles

    /// Skips on an iPhone before anything launches.
    private func requirePad() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, """
            iPad only: on iPhone Browse is a stack, a door's level is pushed over the root, and no list \
            stays on screen to mark.
            """)
    }

    /// Launches on Browse in Global context, the downloaded-only filter pinned — on and with the fixture
    /// volume seeded for the resume-row test, off otherwise — and records the representation found.
    private func launch(seedingVolume: Bool = false) {
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        // Every assertion reads a screen at rest (CLAUDE.md: the iOS 27 idle-counter stall).
        app.launchEnvironment["FRUS_UI_TEST_DISABLE_ANIMATIONS"] = "1"
        if seedingVolume { app.launchEnvironment["FRUS_UI_TEST_SEED_VOLUME"] = Self.seededVolumeId }
        app.launchArguments = UITestLaunch.arguments()
            + ["-frus.filterDownloadedOnly", seedingVolume ? "YES" : "NO"]
        app.launch()
        // Read the representation once the tab chrome is drawn, not before it.
        _ = navigator.sidebarToggleButton(timeout: 10)
        baselineSidebarExpanded = navigator.sidebarIsExpanded
    }

    /// Selects Browse and requires its two-pane wherever the gate admits one: under the gate it skips,
    /// naming the width; over it a missing two-pane FAILS.
    private func openBrowseTwoPane() throws {
        XCTAssertTrue(navigator.select(.browse, resolveTimeout: 10).tapped,
                      "no Browse tab [\(representationName)]")
        let representation = representationName
        let width = try contentWidth(representation)
        try XCTSkipIf(width < Self.twoPaneGate, """
            Browse's content area is \(Int(width)) pt in the \(representation) representation — under the \
            820 pt two-pane gate, where a door's level is pushed and no list stays beside it to mark. Run on \
            iPad Pro 13-inch or iPad Air 13-inch.
            """)
        XCTAssertTrue(detailPlaceholder.waitForExistence(timeout: 10), """
            TWO-PANE LOST: Browse's content area is \(Int(width)) pt in the \(representation) \
            representation, over the 820 pt gate, but the two-pane's detail placeholder never appeared.
            """)
        print("[#1431] representation=\(representation) window=\(app.windows.firstMatch.frame.width)pt "
              + "content=\(width)pt")
    }

    /// The width Browse's gates measure, settled — see `TabBarNavigator.settledContentAreaWidth`.
    private func contentWidth(_ representation: String,
                              file: StaticString = #filePath, line: UInt = #line) throws -> CGFloat {
        try XCTUnwrap(navigator.settledContentAreaWidth(logTag: "[#1431] [\(representation)]"),
                      "Browse's content width never settled [\(representation)]", file: file, line: line)
    }

    /// Requires the tap that opened a door to have taken: the bar names `title` and the empty-path
    /// placeholder has gone.
    private func assertArrived(at title: String, _ step: String, _ representation: String,
                               file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 10),
                      "\(step) did not show \(title) in the detail pane [\(representation)]. Bars: \(barIdentifiers)",
                      file: file, line: line)
        XCTAssertTrue(waitUntil(5) { !detailPlaceholder.exists },
                      "\(step) left the detail placeholder drawn [\(representation)]", file: file, line: line)
    }

    /// Requires a volume whose title contains `title` to be the one in the detail pane: its heading is
    /// drawn right of `listRow`, the result row just tapped, where no result row — each of which also
    /// carries a title — can be.
    ///
    /// The edge is read from the tapped row, not the search field: tapping a result scrolls the list
    /// pane to it, and the field above can leave the lazy list's tree (measured: the Malta result's
    /// tap scrolled the field away on iPad Pro 13-inch, iOS 26.3).
    private func assertArrivedAtVolume(titled title: String, listRow: String, _ step: String,
                                       _ representation: String,
                                       file: StaticString = #filePath, line: UInt = #line) {
        let arrived = waitUntil(10) {
            let elements = snapshotElements()
            guard let listEdge = elements.first(where: { $0.identifier == listRow })?.frame.maxX else { return false }
            return elements.contains {
                $0.elementType == .staticText && $0.label.contains(title) && $0.frame.minX >= listEdge
            }
        }
        XCTAssertTrue(arrived, "\(step) did not show that volume in the detail pane [\(representation)]",
                      file: file, line: line)
        XCTAssertTrue(waitUntil(5) { !detailPlaceholder.exists },
                      "\(step) left the detail placeholder drawn [\(representation)]", file: file, line: line)
    }

    /// Requires `expected` to be the only element under the `browse.root.` prefix reporting `isSelected`
    /// (`nil`: none), once every identifier in `required` has been found — polled briefly, because the
    /// mark is drawn on the render after the tap.
    private func assertMarked(_ expected: String?, among required: Set<String>, _ moment: String,
                              _ representation: String, file: StaticString = #filePath, line: UInt = #line) {
        let want: Set<String> = expected.map { [$0] } ?? []
        var doors: [DoorState] = []
        _ = waitUntil(5) {
            doors = doorStates()
            return required.isSubset(of: Set(doors.map(\.identifier)))
                && Set(doors.filter(\.isSelected).map(\.identifier)) == want
        }
        let table = doors.map { "\($0.identifier)[type \($0.type.rawValue)]=\($0.isSelected ? "SELECTED" : "-")" }
            .joined(separator: ", ")
        print("[#1431] \(moment) [\(representation)]: \(table)")
        XCTAssertTrue(required.isSubset(of: Set(doors.map(\.identifier))), """
            \(Self.doorsMissing): \(moment), in the \(representation) representation, the sweep did not find \
            \(required.subtracting(doors.map(\.identifier)).sorted()), so no mark could be read. \
            Read: \(table.isEmpty ? "nothing" : table)
            """, file: file, line: line)
        XCTAssertTrue(Set(doors.filter(\.isSelected).map(\.identifier)) == want, """
            \(Self.unmarked): \(moment), in the \(representation) representation, expected \
            \(expected ?? "no door") alone to report isSelected under the browse.root. prefix. Read: \(table)
            """, file: file, line: line)
    }

    /// One element carrying a `browse.root.` identifier, as XCUI reports it.
    private struct DoorState {
        /// The element's accessibility identifier.
        let identifier: String
        /// The element's type — printed so a failure shows whether a cell or a button carried it.
        let type: XCUIElement.ElementType
        /// Whether the element reports the selected trait.
        let isSelected: Bool
    }

    /// Every element carrying a `browse.root.` identifier, with its selected state, from ONE snapshot.
    private func doorStates() -> [DoorState] {
        snapshotElements()
            .filter { $0.identifier.hasPrefix(Self.prefix) }
            .map { DoorState(identifier: $0.identifier, type: $0.elementType, isSelected: $0.isSelected) }
    }

    /// Every element of one snapshot of the app's tree, or none when the snapshot cannot be taken — see
    /// `ResearchSidebarSelectionTests.snapshotElements` for why a snapshot and not bound elements.
    private func snapshotElements() -> [any XCUIElementSnapshot] {
        guard let root = try? app.snapshot() else { return [] }
        var found: [any XCUIElementSnapshot] = []
        var pending: [any XCUIElementSnapshot] = [root]
        while let next = pending.popLast() {
            found.append(next)
            pending.append(contentsOf: next.children)
        }
        return found
    }

    /// The navigation bars' identifiers, for a failure message.
    private var barIdentifiers: [String] {
        snapshotElements().filter { $0.elementType == .navigationBar }.map(\.identifier)
    }

    /// The element carrying `identifier`.
    private func row(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Which `.sidebarAdaptable` representation is up.
    private var representationName: String {
        navigator.sidebarIsExpanded ? "sidebar" : "floating tab bar"
    }

    /// The detail pane's placeholder, drawn only by the two-pane with nothing open.
    private var detailPlaceholder: XCUIElement { app.staticTexts["Choose a Subseries"].firstMatch }

    /// The detail pane's own Back row, drawn where there is a parent level beside the list pane.
    private var backControl: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == 'Back'")).firstMatch
    }

    /// Attaches a screenshot the reviewer keeps — the only check on the fill, which no assertion here
    /// can read.
    private func attachScreenshot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Polls `condition` until it holds or `timeout` passes.
    private func waitUntil(_ timeout: TimeInterval = 10, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return condition()
    }
}
