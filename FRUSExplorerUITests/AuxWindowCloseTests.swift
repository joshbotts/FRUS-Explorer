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

/// Closing an iPad auxiliary window returns the reader to FRUS Explorer, not to the Home Screen
/// (#1368).
///
/// ## What was wrong
/// On iPad every Analysis Tools surface but the word cloud opens as its own `WindowGroup` scene,
/// filling the screen, and the launching window goes to the background. Each surface's Done still
/// called the `dismiss()` it was written with when it was a sheet, which at the root of a window
/// scene closes the scene — and with nothing asking iPadOS to show another of the app's windows, it
/// sometimes showed the Home Screen. The process kept running; tapping the icon brought the main
/// window back exactly as it was.
///
/// ## What each test asserts
/// Open the surface's window, tap its Done, and require that the app is **foreground** and that the
/// main window's Browse screen — the one the menu was opened from — is what it shows. The check
/// waits for the scene transition to finish first: read immediately after the tap, the app still
/// reports `.runningForeground` on the way to the Home Screen, which would pass the defect.
///
/// **This suite needs an iPad destination, and it self-skips on an iPhone**, where every one of
/// these surfaces is a sheet and Done has always closed it. A run on an iPhone is therefore a
/// skip, never a pass.
///
/// **Run it on iOS 27.0 in Windowed Apps mode; nowhere else does it guard.** On `v2`, on iPad Pro
/// 13-inch (M5), iPadOS did not drop every surface to the Home Screen, and which ones it dropped
/// depended on the runtime and the multitasking mode (`Planning/DEVELOPMENT-PLAN.md`, 2026-09-24):
/// - **iOS 27.0, Windowed Apps** (a fresh simulator's default) — Archival Analytics' Done, Semantic
///   Analytics' Done and the citing-volume hand-off failed, identically in three runs; Chronology,
///   Corpus, Person and Cross-Reference Analytics came back to the main window even on `v2`.
/// - **iPadOS 26.5, Windowed Apps** — the hand-off failed in one run of two, and nothing else did.
/// - **iOS 27.0, Full Screen Apps and Stage Manager** — nothing dropped to the Home Screen.
///
/// So the four Done cases that pass on `v2` everywhere measured are controls today, not guards: they
/// pin that the fix leaves those surfaces returning where they already did. The mode is set in the
/// simulator's Settings ▸ Multitasking & Gestures, persists per install, and no launch argument can
/// set it.
///
/// Version history:
///   1.0 — Session 2026-09-24: #1368
@MainActor
final class AuxWindowCloseTests: XCTestCase {

    var app: XCUIApplication!

    /// Read through a closure: `setUp` mints a fresh `XCUIApplication` per test (#1278).
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

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
        app.launch()
    }

    override func tearDown() async throws {
        // Close what is open, then terminate (#1279): an aux window left open is restored by the
        // next launch, and the next test would find no tab bar at all.
        UITestPresentation.dismissAnyPresentation(in: app)
        app?.terminate()
        app = nil
    }

    // MARK: - Done, one surface at a time

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
    /// is drawn only over a range holding indexed, DATED documents, and the UI-test fixture's
    /// documents carry datelines but no `<date>` — so on a UI-test launch Chronology is empty and
    /// the link never appears. Archival Analytics reads bundled artifacts only and reaches a citing
    /// volume with nothing downloaded. The two exits share the close action, and the unit suite
    /// (`WindowTargetingTests.everyClosingExitFrontsItsTarget`) pins every one of them.
    func testArchivalCitingVolumeHandOffReturnsToTheMainWindow() throws {
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

        // The collection's record: its citing volumes are rows naming a volume id.
        let citingVolume = app.buttons.matching(NSPredicate(format: "label CONTAINS 'frus'")).firstMatch
        XCTAssertTrue(scrollTo(citingVolume), "The collection sheet lists no citing volume.\n\(tree())")
        citingVolume.tap()

        assertInTheForeground(after: "a citing volume's hand-off to Browse")
        // Not the Analysis Tools button: the volume is pushed onto Browse, so its root toolbar may
        // be one level down. The tab is what the hand-off promised.
        XCTAssertTrue(navigator.isSelected(.browse), """
            The volume was handed to the Browse tab, so a main window showing Browse is what must \
            be in front.\n\(tree())
            """)
    }

    // MARK: - Helpers

    /// Opens an Analysis Tools surface, taps its Done, and asserts the main window came back.
    private func openAndClose(_ item: String, submenuItem: String? = nil,
                              file: StaticString = #filePath, line: UInt = #line) throws {
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
        XCTAssertTrue(waitUntilHittable(app.buttons[AnalysisToolsMenu.label].firstMatch), """
            After \(item)'s Done the main window's Browse screen — where the menu was opened — is \
            not the one on screen.\n\(tree())
            """, file: file, line: line)
    }

    /// Waits for the surface's window to be the one on screen: its Done can be tapped, and the
    /// Browse tab's Analysis Tools menu cannot.
    ///
    /// **Hittable, not merely present, on both sides.** The element tree keeps a backgrounded
    /// window's elements: with the aux window in front, `exists` on the main window's Analysis
    /// Tools button was `true` in all seven cases of every run on both runtimes, measured.
    private func waitForAuxWindow(_ item: String,
                                  file: StaticString = #filePath, line: UInt = #line) throws {
        let done = app.navigationBars.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 20) && waitUntilHittable(done),
                      "\(item) did not open in front with a Done button.\n\(tree())",
                      file: file, line: line)
        // Measured in Windowed Apps, Full Screen Apps and Stage Manager, the new window covered the
        // main one every time. Were both visible, the test would still measure the same thing —
        // where Done leaves you — so this only says so in the log.
        let menu = app.buttons[AnalysisToolsMenu.label].firstMatch
        if menu.exists, menu.isHittable {
            print("[AuxWindowCloseTests] The main window is still hittable beside \(item)'s window; "
                  + "this multitasking mode shows both.")
        }
    }

    /// Polls until `element` can be tapped, for up to `timeout` seconds.
    private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if element.exists, element.isHittable { return true }
            Thread.sleep(forTimeInterval: 0.25)
        } while Date() < deadline
        return false
    }

    /// Asserts the app is still in front once the window has gone.
    ///
    /// Waits out the transition first. Read at once, `state` is still `.runningForeground` while
    /// the window animates away toward the Home Screen — a check made there passes the defect.
    private func assertInTheForeground(after action: String,
                                       file: StaticString = #filePath, line: UInt = #line) {
        Thread.sleep(forTimeInterval: 2.5)
        XCTAssertEqual(app.state, .runningForeground, """
            After \(action) the app is not in the foreground (state \(app.state.rawValue)) — iPadOS \
            is showing the Home Screen, the #1368 defect: closing the app's only foreground window \
            without bringing another forward.
            """, file: file, line: line)
    }

    /// Swipes the frontmost scroll view up until `element` is hittable, or gives up.
    private func scrollTo(_ element: XCUIElement) -> Bool {
        if element.waitForExistence(timeout: 15), element.isHittable { return true }
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
