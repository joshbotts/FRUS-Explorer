// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import XCTest

/// Closing an iPad auxiliary window returns the reader to the window they opened it from, not to
/// the Home Screen and not to a window they never opened (#1368).
///
/// ## What was wrong
/// On iPad every Analysis Tools surface but the word cloud opens as its own `WindowGroup` scene,
/// filling the screen, and the launching window goes to the background — and so do the Research
/// rail's Source Explorer, cross-reference graph and word cloud. Each surface's Done still called
/// the `dismiss()` it was written with when it was a sheet, which at the root of a window scene
/// closes the scene — and with nothing asking iPadOS to show another of the app's windows, it
/// sometimes showed the Home Screen. The process kept running; tapping the icon brought the main
/// window back exactly as it was.
///
/// ## What each test asserts
/// Before it opens anything, each case puts the launching window into a state a NEW main window
/// cannot have: Browse's Subseries directory for the Analysis Tools cases, a document open in Browse
/// for the rail cases. After Done it requires, in order, that the app is **foreground**, that the
/// marked state is what is on screen (hittable — the element tree keeps a backgrounded window's
/// elements), and that the tree holds no more Browse tab items than before — a new main window
/// brings its own tab bar. So a close that opened a brand-new main window instead of bringing the
/// launcher forward fails, where a check for "some Browse screen with an Analysis Tools button"
/// would pass it: a new window opens on Browse, because `UITestLaunch` pins that tab. The
/// foreground check waits for the scene transition to finish first: read immediately after the
/// tap, the app still reports `.runningForeground` on the way to the Home Screen, which would pass
/// the defect. The hand-off case's mark after the close is the volume it handed to Browse, checked
/// before the foreground state (see the case).
///
/// **This suite needs an iPad destination, and it self-skips on an iPhone**, where every one of
/// these surfaces is a sheet and Done has always closed it. A run on an iPhone is therefore a
/// skip, never a pass. The Analysis Tools cases also need Browse's two-pane (820 pt of width, every
/// iPad Pro in portrait): their mark is drawn in its detail pane, and a narrower iPad skips them,
/// naming the width it measured.
///
/// **Which cases guard against the Home Screen depends on the runtime and the multitasking mode.**
/// On `v2`, on iPad Pro 13-inch (M5), iPadOS did not drop every surface to the Home Screen, and
/// which ones it dropped varied (`Planning/DEVELOPMENT-PLAN.md`, 2026-09-24):
/// - **iOS 27.0, Windowed Apps** (a fresh iOS 27.0 simulator's default) — Archival Analytics' Done,
///   Semantic Analytics' Done and the citing-volume hand-off dropped to the Home Screen, identically
///   in three runs and again in review round 1's; Chronology, Corpus, Person and Cross-Reference
///   Analytics came back to the main window even on `v2`, and so did round 1's three rail cases
///   and its document-window case (one run): iPadOS brought back the window the reader came from.
/// - **iPadOS 26.5, Windowed Apps** — the hand-off dropped in one run of two, and nothing else did.
/// - **iOS 27.0, Full Screen Apps** — nothing dropped to the Home Screen, but in the one run
///   Cross-Reference Analytics' window was still on screen after its Done, so that case failed on
///   `v2` there.
/// - **iOS 27.0, Stage Manager** — nothing failed.
///
/// Against the Home Screen drop, then, Chronology, Corpus and Person are controls everywhere
/// measured, Cross-Reference is a control except in Full Screen Apps, and round 1's four cases are
/// controls where they were measured (iOS 27.0, Windowed Apps). Since review round 1 every case is
/// also a guard against a close that opens a new main window — that is what the launcher's mark and
/// the tab-item count measure; all eleven failed under that mutant in iOS 27.0 Windowed Apps — and
/// the document-window case against round 0's code, which fronted the main window instead. The
/// mode is set in the simulator's Settings ▸ Multitasking & Gestures, persists per install, and no
/// launch argument can set it.
///
/// Version history:
///   1.0 — Session 2026-09-24: #1368
///   1.1 — #1368 review round 1: the launcher is marked before the aux window opens and the Browse
///         tab items are counted, so fronting the launcher is told apart from opening a new main
///         window; the hand-off case asserts the handed volume is on screen; the rail's Source
///         Explorer, graph and word cloud are driven from a seeded document; and a tool opened in
///         the standalone document window closes back to that window
@MainActor
final class AuxWindowCloseTests: XCTestCase {

    var app: XCUIApplication!

    /// Read through a closure: `setUp` mints a fresh `XCUIApplication` per test (#1278).
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    /// The fixture volume the rail cases open — the one `TwoPaneDocumentTests` and
    /// `CompilationDocumentsTests` seed, so one `UITestVolumeSeeder` fixture serves all three.
    private static let seededVolumeId = "frus1961-63v06"

    /// The compilation `<head>` in the seeded fixture. Must match `UITestVolumeSeeder`.
    private static let compilationTitle = "UI Test Compilation"

    /// The first document `<head>` in the seeded fixture. Must match `UITestVolumeSeeder`.
    private static let firstDocumentTitle = "UI Test Document One"

    /// The Research rail header's "open in a new window" button — present only while a document is
    /// open, which makes it the rail cases' mark.
    private static let openInNewWindowLabel = "Open document in a new window"

    override func setUp() async throws {
        continueAfterFailure = false
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, """
            #1368 is an iPad defect: these surfaces open as window scenes only where the app may \
            open more than one window. On an iPhone each is a sheet, and this suite would measure \
            nothing — run it on an iPad Pro 13-inch (M5).
            """)
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchArguments = UITestLaunch.arguments()
    }

    override func tearDown() async throws {
        // Close what is open, then terminate (#1279): an aux window left open is restored by the
        // next launch, and the next test would find no tab bar at all.
        UITestPresentation.dismissAnyPresentation(in: app)
        app?.terminate()
        app = nil
    }

    // MARK: - Done, one Analysis Tools surface at a time

    /// Chronology's window (`chronologyScene`).
    func testChronologyDoneReturnsToTheMainWindow() throws {
        try openAndClose("Chronology")
    }

    /// Corpus Analytics' window (`corpusAnalyticsScene`).
    func testCorpusAnalyticsDoneReturnsToTheMainWindow() throws {
        try openAndClose("Corpus Analytics")
    }

    /// Person Analytics' Trends window (`personAnalyticsScene`) — the menu offers each mode as its
    /// own window where windows exist, so the item is a submenu.
    func testPersonAnalyticsDoneReturnsToTheMainWindow() throws {
        try openAndClose("Person Analytics", submenuItem: "Trends")
    }

    /// Cross-Reference Analytics' window (`crossReferenceAnalyticsScene`).
    func testCrossReferenceAnalyticsDoneReturnsToTheMainWindow() throws {
        try openAndClose("Cross-Reference Analytics")
    }

    /// Archival Analytics' window (`archivalAnalyticsScene`), reached through the tab shell's
    /// hand-off rather than `BrowserView`, unlike the other five.
    func testArchivalAnalyticsDoneReturnsToTheMainWindow() throws {
        try openAndClose("Archival Analytics")
    }

    /// The semantic map's window (`semanticMapScene`) — one of the four surfaces #1368 observed.
    func testSemanticAnalyticsDoneReturnsToTheMainWindow() throws {
        try openAndClose("Semantic Analytics")
    }

    // MARK: - A hand-off that closes the window

    /// Archival Analytics ▸ a collection ▸ one of its citing volumes: the row hands the volume to
    /// Browse and closes the collection sheet AND the window (#825d). In a window that closed the
    /// app's only foreground scene, and the Browse tab the volume went to was in the backgrounded
    /// launcher.
    ///
    /// **Why this exit and not Chronology ▸ Search in this range**, which the plan named: that link
    /// is drawn only over a range holding indexed documents that Chronology can date, and reaching
    /// one from here costs more than it measures. This suite seeds no volume for the Analysis Tools
    /// cases, so what Chronology would show depends on whatever that simulator's index already
    /// holds; seeding the fixture would give it dated documents (their datelines parse to January
    /// 1962), but Chronology opens on the manifest's latest year and loads nothing until its range is
    /// driven back to 1962 and Show is tapped. Archival Analytics reads bundled artifacts only and
    /// reaches a citing volume with nothing downloaded. The two exits share the close action, and
    /// the unit suite pins every one of them (`WindowTargetingTests.everyClosingExitFrontsItsTarget`
    /// and `everyClosingExitAddressesTheWindowItFronts`).
    func testArchivalCitingVolumeHandOffReturnsToTheMainWindow() throws {
        launch()
        try markTheLauncher()
        let tabItemsBefore = browseTabItemCount
        try AnalysisToolsMenu.open("Archival Analytics", in: app, through: navigator)
        try waitForAuxWindow("Archival Analytics")

        // The chart draws twelve bars; the full list is one tap away and its rows are buttons.
        let showAll = app.buttons.matching(NSPredicate(
            format: "label BEGINSWITH 'Show all' AND label CONTAINS 'units in this era'")).firstMatch
        XCTAssertTrue(scrollTo(showAll), "No 'Show all … units in this era' button.\n\(tree())")
        showAll.tap()

        let firstUnit = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '1.'")).firstMatch
        XCTAssertTrue(firstUnit.waitForExistence(timeout: 15), "The all-units list has no first row.\n\(tree())")
        firstUnit.tap()

        // The collection's record: its citing volumes are rows reading "<title>, <volume id>".
        let citingVolume = app.buttons.matching(NSPredicate(format: "label CONTAINS ', frus'")).firstMatch
        XCTAssertTrue(scrollTo(citingVolume), "The collection sheet lists no citing volume.\n\(tree())")
        let volumeTitle = try XCTUnwrap(
            citingVolume.label.range(of: ", frus", options: .backwards).map { String(citingVolume.label[..<$0.lowerBound]) },
            "The citing-volume row '\(citingVolume.label)' does not read '<title>, <volume id>'")
        print("[AuxWindowCloseTests] citing volume: \(citingVolume.label)")
        citingVolume.tap()

        // FIRST the volume, THEN the foreground state (review round 1). Browse was selected before
        // the hand-off as well as after it, and the tree keeps a backgrounded window's elements, so
        // `isSelected(.browse)` — what this case asserted before — held on `v2` and with the Archival
        // window still open. The handed volume's title, HITTABLE, holds only when the launcher is in
        // front showing it: a new main window opens on Browse's root, and the Archival window, left
        // open, covers the launcher.
        waitForTheTransition()
        XCTAssertTrue(waitUntilAnyHittable(app.staticTexts.matching(NSPredicate(format: "label == %@", volumeTitle))), """
            After the citing volume's hand-off the volume it was handed — '\(volumeTitle)' — is not \
            on screen (app state \(app.state.rawValue); 4 is foreground). #1368: the app went to \
            the Home Screen, the Archival window did not close, or another window came forward \
            instead of the one the volume went to.\n\(tree())
            """)
        XCTAssertEqual(app.state, .runningForeground)
        assertNoNewMainWindow(since: tabItemsBefore, after: "the citing volume's hand-off")
    }

    // MARK: - The Research rail's windows (review round 1)

    /// Source Explorer's window (`SourceExplorerRequest`), from the rail's Sources tile — one of the
    /// four surfaces #1368 observed, and the only Done that reads `\.isPresented` at the root of a
    /// `NavigationStack` (`SourceExplorerWindowContent`) rather than outside its own stack.
    func testSourceExplorerDoneReturnsToTheDocument() throws {
        try openRailToolAndClose("Sources")
    }

    /// The cross-reference graph's window (`GraphWindowRequest`), from the rail's Graph tile.
    func testCrossReferenceGraphDoneReturnsToTheDocument() throws {
        try openRailToolAndClose("Graph")
    }

    /// The rail word cloud's window (`WordCloudScope`), from the rail's Word Cloud tile.
    func testRailWordCloudDoneReturnsToTheDocument() throws {
        try openRailToolAndClose("Word Cloud")
    }

    /// A rail tool opened in the STANDALONE document window closes back to that window — not to the
    /// main window it borrowed its identity from (review round 1, correctness#0). Round 0 fronted
    /// the main window: the document window republishes the main window's `\.sceneID`, so Source
    /// Explorer recorded the main window as its launcher.
    ///
    /// The two windows are told apart by the tab bar: the main window has one, the document window
    /// does not. Both show the fixture document and its rail, so the rail being hittable says a
    /// document is in front, and the Browse tab item NOT being hittable says it is not the main
    /// window's.
    func testARailToolOpenedInTheDocumentWindowReturnsToIt() throws {
        launch(withFixture: true)
        try openTheFixtureDocument()
        let tabItemsBefore = browseTabItemCount

        let openInNewWindow = try XCTUnwrap(firstHittable(app.buttons.matching(
            NSPredicate(format: "label == %@", Self.openInNewWindowLabel))),
            "The Research rail offers no 'Open document in a new window'.\n\(tree())")
        openInNewWindow.tap()
        XCTAssertTrue(waitUntil { self.documentWindowIsInFront }, """
            The standalone document window did not come to the front with its rail.\n\(tree())
            """)

        let sources = try XCTUnwrap(firstHittable(app.buttons.matching(NSPredicate(format: "label == 'Sources'"))),
                                    "The document window's rail has no Sources tile.\n\(tree())")
        sources.tap()
        try waitForAuxWindow("Source Explorer (from the document window)")
        app.navigationBars.buttons["Done"].firstMatch.tap()

        assertInTheForeground(after: "Source Explorer's Done in a window opened from the document window")
        XCTAssertTrue(waitUntil { self.documentWindowIsInFront }, """
            After Source Explorer's Done the document window it was opened from is not the one in \
            front — \(anyHittable(browseTabItems) ? "the main window is" : "nothing of the app's is"). \
            A tool opened in the standalone document window must close back to it.\n\(tree())
            """)
        assertNoNewMainWindow(since: tabItemsBefore, after: "Source Explorer's Done")

        // The document window stays open: it has no Done, the simulator does not close it on ⌘W,
        // and XCUI reaches no window control (measured: after ⌘W it was still in front, and
        // SpringBoard's tree exposed no buttons). The next launch is unaffected — in every full run
        // of this suite the test after this one found its main window in front.
    }

    // MARK: - Helpers

    /// Launches the app — with the fixture volume seeded, and Browse narrowed to it, for the cases
    /// that need a document.
    private func launch(withFixture: Bool = false) {
        if withFixture {
            app.launchEnvironment["FRUS_UI_TEST_SEED_VOLUME"] = Self.seededVolumeId
            app.launchArguments += ["-frus.filterDownloadedOnly", "YES"]
        }
        app.launch()
    }

    /// The Browse tab items in the tree, a backgrounded main window's included — which is what makes
    /// their count grow when a close opens a new main window. Measured on iOS 27.0, each main
    /// window's tab bar shows its Browse item as TWO nested buttons of the same identifier and label,
    /// so the count is twice the main windows; the tests compare it with itself, never with a window
    /// count. Not the Analysis Tools menu: with a document open, Browse's toolbar folds it into its
    /// `More` overflow control, where it is no button at all (measured: the document-window case's
    /// failure tree held no Analysis Tools button). Aux windows and the standalone document window
    /// have no tab bar, so a hittable Browse item says a MAIN window is in front.
    private var browseTabItems: XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier == %@ AND label == %@",
                                         TabDestination.browse.symbol, TabDestination.browse.label))
    }

    /// How many Browse tab items the tree holds — a fixed number per main window (see
    /// ``browseTabItems``), so it rises exactly when a main window is added.
    private var browseTabItemCount: Int { browseTabItems.count }

    /// A row of Browse's Subseries directory — the launcher's mark for the Analysis Tools cases. The
    /// root's Subseries TILE is excluded by identifier: a new window has one, and its label also
    /// begins with the word.
    private var launcherMark: XCUIElement {
        app.buttons.matching(NSPredicate(
            format: "label BEGINSWITH 'Subseries ' AND identifier != 'browse.root.subseriesTile'")).firstMatch
    }

    /// Opens Browse's Subseries directory in the detail pane — a state a new main window, which
    /// opens on Browse's root with "Choose a Subseries", cannot have.
    private func markTheLauncher(file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertTrue(navigator.select(.browse, resolveTimeout: 15, file: file, line: line).tapped,
                      "Could not open the Browse tab to mark the launcher.", file: file, line: line)
        let width = app.windows.firstMatch.frame.width
        try XCTSkipUnless(app.staticTexts["Choose a Subseries"].waitForExistence(timeout: 10), """
            Browse is a single column at \(width) pt, below the two-pane gate, so the launcher's \
            mark has no detail pane to be drawn in — run on an iPad Pro in portrait.
            """)
        let tile = app.buttons["browse.root.subseriesTile"].firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 15), "No Subseries tile at Browse's root.\n\(tree())",
                      file: file, line: line)
        tile.tap()
        XCTAssertTrue(waitUntilHittable(launcherMark), "The Subseries directory did not open.\n\(tree())",
                      file: file, line: line)
    }

    /// Opens an Analysis Tools surface from a marked launcher, taps its Done, and asserts the
    /// launcher — not a new main window — is what came back.
    private func openAndClose(_ item: String, submenuItem: String? = nil,
                              file: StaticString = #filePath, line: UInt = #line) throws {
        launch()
        try markTheLauncher(file: file, line: line)
        let tabItemsBefore = browseTabItemCount
        try AnalysisToolsMenu.open(item, in: app, through: navigator, file: file, line: line)
        if let submenuItem {
            let entry = app.buttons[submenuItem].firstMatch
            XCTAssertTrue(entry.waitForExistence(timeout: 10),
                          "'\(item)' offers no '\(submenuItem)'.\n\(tree())", file: file, line: line)
            entry.tap()
        }
        try waitForAuxWindow(item, file: file, line: line)
        app.navigationBars.buttons["Done"].firstMatch.tap()
        assertInTheForeground(after: "\(item)'s Done", file: file, line: line)
        let newWindowNote = browseTabItemCount > tabItemsBefore ? "A new main window opened instead." : ""
        XCTAssertTrue(waitUntilHittable(launcherMark), """
            After \(item)'s Done the window the menu was opened from — marked by its open Subseries \
            directory — is not the one on screen. \(newWindowNote)\n\(tree())
            """, file: file, line: line)
        assertNoNewMainWindow(since: tabItemsBefore, after: "\(item)'s Done", file: file, line: line)
    }

    /// Opens a Research rail tool on the fixture document, taps its Done, and asserts the document's
    /// main window is what came back.
    private func openRailToolAndClose(_ tile: String,
                                      file: StaticString = #filePath, line: UInt = #line) throws {
        launch(withFixture: true)
        try openTheFixtureDocument(file: file, line: line)
        let tabItemsBefore = browseTabItemCount
        let button = try XCTUnwrap(firstHittable(app.buttons.matching(NSPredicate(format: "label == %@", tile))),
                                   "The Research rail has no '\(tile)' tile.\n\(tree())", file: file, line: line)
        button.tap()
        try waitForAuxWindow(tile, file: file, line: line)
        app.navigationBars.buttons["Done"].firstMatch.tap()
        assertInTheForeground(after: "the \(tile) window's Done", file: file, line: line)
        XCTAssertTrue(waitUntil { self.anyHittable(self.railMark) && self.anyHittable(self.browseTabItems) }, """
            After the \(tile) window's Done the main window showing the document it was opened \
            from is not the one on screen.\n\(tree())
            """, file: file, line: line)
        assertNoNewMainWindow(since: tabItemsBefore, after: "the \(tile) window's Done", file: file, line: line)
    }

    /// The rail header's "open in a new window" button — present only beside an open document.
    private var railMark: XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "label == %@", Self.openInNewWindowLabel))
    }

    /// True while the standalone document window is in front: a rail is hittable and no main
    /// window's tab bar is.
    private var documentWindowIsInFront: Bool {
        anyHittable(railMark) && !anyHittable(browseTabItems)
    }

    /// Browse ▸ Subseries ▸ the fixture's subseries ▸ its volume ▸ its compilation ▸ its first
    /// document, indexing on the way if this is a cold run — `TwoPaneDocumentTests`' walk.
    private func openTheFixtureDocument(file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertTrue(navigator.select(.browse, resolveTimeout: 15, file: file, line: line).tapped,
                      "Could not open the Browse tab.", file: file, line: line)
        let tile = app.buttons["browse.root.subseriesTile"].firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 15), "No Subseries tile at Browse's root.",
                      file: file, line: line)
        tile.tap()
        let steps: [(what: String, query: XCUIElementQuery, timeout: TimeInterval)] = [
            ("the fixture's subseries", app.buttons.matching(NSPredicate(
                format: "label BEGINSWITH 'Subseries ' AND identifier != 'browse.root.subseriesTile'")), 15),
            ("the fixture volume", app.buttons.matching(NSPredicate(
                format: "label CONTAINS[c] 'Kennedy-Khrushchev'")), 15),
            ("the fixture compilation", app.buttons.matching(NSPredicate(
                format: "label CONTAINS[c] %@", Self.compilationTitle)), 15),
        ]
        for step in steps {
            let element = step.query.firstMatch
            XCTAssertTrue(scrollTo(element, timeout: step.timeout),
                          "No row for \(step.what) — was the fixture seeded?\n\(tree())", file: file, line: line)
            element.tap()
            Thread.sleep(forTimeInterval: 0.8)
        }
        let indexNow = app.buttons["Index Now"]
        if indexNow.waitForExistence(timeout: 5), indexNow.isEnabled { indexNow.tap() }
        let document = app.buttons.matching(NSPredicate(
            format: "label CONTAINS[c] %@", Self.firstDocumentTitle)).firstMatch
        XCTAssertTrue(document.waitForExistence(timeout: 60), "No document rows at the compilation.\n\(tree())",
                      file: file, line: line)
        document.tap()
        XCTAssertTrue(waitUntil(timeout: 30) { self.anyHittable(self.railMark) }, """
            The document opened without its Research rail, so there are no rail tools to open.\n\(tree())
            """, file: file, line: line)
    }

    /// Waits for the surface's window to be the one on screen: its Done can be tapped.
    ///
    /// **Hittable, not merely present.** The element tree keeps a backgrounded window's elements:
    /// with the aux window in front, `exists` on the main window's Analysis Tools button was `true`
    /// in all seven cases of the first runs on both runtimes, measured. Whether a main window's tab
    /// bar is ALSO hittable beside the aux window is logged, not asserted — see below.
    private func waitForAuxWindow(_ item: String,
                                  file: StaticString = #filePath, line: UInt = #line) throws {
        let done = app.navigationBars.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 20) && waitUntilHittable(done),
                      "\(item) did not open in front with a Done button.\n\(tree())",
                      file: file, line: line)
        // Measured in Windowed Apps, Full Screen Apps and Stage Manager, the new window covered the
        // main one every time. Were both visible, the test would still measure the same thing —
        // where Done leaves you — so this only says so in the log.
        if anyHittable(browseTabItems) {
            print("[AuxWindowCloseTests] The main window is still hittable beside \(item)'s window; "
                  + "this multitasking mode shows both.")
        }
    }

    /// Fails when the tree holds more Browse tab items than it did before the aux window opened —
    /// another main window's tab bar, because the close asked iPadOS for a new main window instead of
    /// bringing an open one forward.
    private func assertNoNewMainWindow(since before: Int, after action: String,
                                       file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(browseTabItemCount, before, """
            After \(action) the tree holds \(browseTabItemCount) Browse tab items where it held \
            \(before) before the aux window opened: another main window's tab bar, so the close \
            opened a new main window rather than bringing the launcher forward.
            """, file: file, line: line)
    }

    /// Polls until `element` can be tapped, for up to `timeout` seconds.
    private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        waitUntil(timeout: timeout) { element.exists && element.isHittable }
    }

    /// Polls until some element of `query` can be tapped, for up to `timeout` seconds.
    private func waitUntilAnyHittable(_ query: XCUIElementQuery, timeout: TimeInterval = 10) -> Bool {
        waitUntil(timeout: timeout) { self.anyHittable(query) }
    }

    /// Polls `condition` every quarter second for up to `timeout` seconds.
    private func waitUntil(timeout: TimeInterval = 10, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.25)
        } while Date() < deadline
        return false
    }

    /// The first element of `query` that can be tapped. `firstMatch` alone may be a backgrounded
    /// window's copy: with two windows showing the same document, the tree holds both rails.
    private func firstHittable(_ query: XCUIElementQuery) -> XCUIElement? {
        query.allElementsBoundByIndex.first { $0.exists && $0.isHittable }
    }

    /// Whether any element of `query` can be tapped.
    private func anyHittable(_ query: XCUIElementQuery) -> Bool { firstHittable(query) != nil }

    /// Waits out the scene transition after a window closes. Read at once, `state` is still
    /// `.runningForeground` while the window animates away toward the Home Screen.
    private func waitForTheTransition() {
        Thread.sleep(forTimeInterval: 2.5)
    }

    /// Asserts the app is still in front once the window has gone, after waiting out the transition.
    private func assertInTheForeground(after action: String,
                                       file: StaticString = #filePath, line: UInt = #line) {
        waitForTheTransition()
        XCTAssertEqual(app.state, .runningForeground, """
            After \(action) the app is not in the foreground (state \(app.state.rawValue)) — iPadOS \
            is showing the Home Screen, the #1368 defect: closing the app's only foreground window \
            without bringing another forward.
            """, file: file, line: line)
    }

    /// Swipes the frontmost scroll view up until `element` is hittable, or gives up.
    private func scrollTo(_ element: XCUIElement, timeout: TimeInterval = 15) -> Bool {
        if element.waitForExistence(timeout: timeout), element.isHittable { return true }
        for _ in 0..<8 {
            app.swipeUp()
            if element.exists, element.isHittable { return true }
        }
        return element.exists && element.isHittable
    }

    /// The element tree, for a failure message that says what WAS on screen.
    private func tree() -> String {
        app.state == .runningForeground ? app.debugDescription : "(app not in the foreground)"
    }
}
