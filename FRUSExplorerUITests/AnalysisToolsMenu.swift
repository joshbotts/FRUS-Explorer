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

// MARK: - AnalysisToolsMenu

/// Browse ▸ **Analysis Tools** ▸ an item, for the three suites that all need that route (#1279).
///
/// ## Why this exists
/// There were three copies, and they pointed at each other in a CHAIN.
/// `KeyboardDismissBarReachTests.openCorpusAnalytics` said *"Mirrors
/// `AnalyticsKeyboardTests.openCorpusAnalytics`"*, which said *"Mirrors
/// `AnalyticsRotationTests.openCorpusAnalytics`"*. The two bodies were byte-identical — `diff` on
/// them at `69dfac7d` reports one differing line, each one's doc naming the other — and the head of
/// the chain did not lead where it claimed: the original also expands an overflowed toolbar and
/// prints the buttons actually on screen in its skip, and the copies had neither. (Both properties
/// predate #1278 — the chain was stale in the sense that the copies were never equal to its head,
/// not that the head moved away from them.) So when the copies missed they said only *"Analysis
/// Tools menu not reachable on this destination"* — naming a cause that was not the cause, and
/// printing nothing that could contradict it.
///
/// That is not a hypothetical. Measured on **iPad mini (A17 Pro)** at `69dfac7d`, with the app
/// freshly installed, `AnalyticsKeyboardTests` ran 3 tests: the first passed, and the other two
/// skipped with that message. The real cause was the Corpus Analytics surface the first test left
/// open — on iPad a second WINDOW scene, see `UITestPresentation` below — which iPadOS restored on
/// the next launch. The bare Browse guard could not see a tab that was not in the tree at all,
/// waited ten seconds, and proceeded anyway. The skip was green and the suite reported success
/// having measured one third of what it claims.
///
/// So the three copies are one function, and a miss now reports what it can see.
///
/// Version history:
///   1.0 — #1279: extracted from three copies whose "mirrors" comments formed a chain
enum AnalysisToolsMenu {

    /// The analysis menu's accessibility label.
    ///
    /// Its LABEL is the short name from `.controlHelp(_:detail:)`; the long
    /// "Chronology, Corpus Analytics, …" string is the accessibility HINT, not the label.
    static let label = "Analysis Tools"

    /// The labels UIKit gives a collapsed toolbar's overflow control, in the order to try them.
    private static let overflowLabels = ["More", "Show More", "More Actions"]

    /// Opens Browse, then the analysis menu, then `item`.
    ///
    /// **The tab selection is asserted, not attempted.** That is the whole of #1279: the bare
    /// `if browse.waitForExistence(timeout: 10) { browse.tap() }` this replaces could not fail, so
    /// on a miss it proceeded from whatever was on screen and left the next line to invent a reason.
    /// `TabBarNavigator.select` fails loudly on its own for a tab it cannot find anywhere — but its
    /// last-resort branch returns `tapped: false` WITHOUT failing, and `select` is
    /// `@discardableResult`, so a conversion that ignored the result would reproduce the defect it
    /// was written to remove.
    ///
    /// - Parameters:
    ///   - item: The menu item's label, e.g. `"Corpus Analytics"`.
    ///   - app: The application under test.
    ///   - navigator: The caller's navigator, so a relaunching suite drives its live app.
    ///   - file: Forwarded so a failure reports the caller's line.
    ///   - line: Forwarded so a failure reports the caller's line.
    /// - Throws: `XCTSkip` when the menu is not on screen, naming what IS.
    static func open(_ item: String,
                     in app: XCUIApplication,
                     through navigator: TabBarNavigator,
                     file: StaticString = #filePath,
                     line: UInt = #line) throws {
        // `resolveTimeout: 15` for the reason the parameter's own doc gives: every caller reaches
        // this from a test body moments after `setUpWithError`'s `launch()`, and a cold start can
        // take longer than five seconds to draw a tab bar at all. Applying that rule at one call
        // site and not the others would be the drift this file exists to end.
        XCTAssertTrue(navigator.select(.browse, resolveTimeout: 15, file: file, line: line).tapped, """
            Could not open the Browse tab, so everything after this would measure another screen. \
            Before #1279 this was a bare `waitForExistence` whose miss was silent, and the skip on \
            the next line then blamed the analysis menu for a tab that was never reached.
            """, file: file, line: line)

        var menu = app.buttons[label]
        if !menu.waitForExistence(timeout: 10) {
            // iPad: when the Browse toolbar collapses its trailing items into an overflow control,
            // "Analysis Tools" is not a top-level button until that is expanded.
            for overflow in overflowLabels {
                let more = app.buttons[overflow].firstMatch
                if more.exists { more.tap(); break }
            }
            // R-8 fixed the raw-SF-Symbol fallback this used to need: the overflowed row now
            // announces "Analysis Tools" like the in-bar button, because the name lives in the
            // item's `Label` rather than only in `.controlHelp`. `ToolbarOverflowAccessibilityTests`
            // is the guard; do not reintroduce an `app.buttons["chart.bar.xaxis"]` fallback here —
            // it would silently re-accept the defect.
            menu = app.buttons[label]
            if !menu.waitForExistence(timeout: 5) {
                throw XCTSkip("""
                    The analysis toolbar menu is not on screen, with the Browse tab open and any \
                    toolbar overflow expanded. Buttons on screen: \(visibleButtonLabels(in: app))
                    """)
            }
        }
        menu.tap()

        // 10, not 5: both replaced copies used 10 here, and adopting the third's 5 would have cut
        // two suites' tolerance in a change that is not about timing.
        let entry = app.buttons[item].firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 10),
                      "The analysis menu opened but offers no '\(item)'. "
                      + "Buttons on screen: \(visibleButtonLabels(in: app))",
                      file: file, line: line)
        entry.tap()
    }

    /// What a query could have matched instead — the half of the original's skip message the two
    /// copies dropped, and the reason #1279's real cause was visible in one suite and not the other.
    private static func visibleButtonLabels(in app: XCUIApplication) -> String {
        app.buttons.allElementsBoundByIndex
            .prefix(30)
            .map { $0.label }
            .filter { !$0.isEmpty }
            .joined(separator: " | ")
    }
}

// MARK: - UITestPresentation

/// Returning the app to a screen the next test can navigate from (#1279).
///
/// ## The measurement this exists for
/// A UI test that ends with a presentation open does not only affect its own process. Measured on
/// **iPad mini (A17 Pro)** at `69dfac7d`, the pattern was exact: every test that ran immediately
/// after one ending with Corpus Analytics open could not reach the Browse tab, and the tab bar was
/// absent from the element tree entirely. It crossed a suite boundary too:
/// `ToolbarOverflowAccessibilityTests` measured that surface's buttons and reported on them as the
/// Browse toolbar's.
///
/// **On iPad it is a WINDOW, not a sheet, and that is why it survives.**
/// `BrowserView.presentAnalytics` branches on `\.supportsMultipleWindows`: where the environment
/// grants them — every iPad — it calls `appState.openAuxWindow` and the analytics surface is a
/// second window scene — `corpusAnalyticsScene`, a value-based `WindowGroup` the app's own scene
/// table describes as *"Value-based — restores correctly"*. Only where the environment withholds
/// multiple windows (iPhone) is it the `.sheet(isPresented:)` bound to `showAnalytics`. Restoring
/// correctly is exactly the property a test inherits here. **Nothing in the app restores
/// it**: `showAnalytics` is plain `@State`, which no relaunch brings back, so an explanation
/// reaching for the app's own persistence is looking in the wrong place — an earlier draft of this
/// file did exactly that and blamed `@SceneStorage`.
///
/// **Terminating is not enough, and that was the first attempt — measured, two failures remained.**
/// `XCUIApplication.launch()` already terminates a running app, and `KeyboardDismissBarReachTests`
/// has terminated in `tearDown` since #1214 — *"Make the keyboard-dismiss-bar reach test
/// order-independent, and able to fail"*, a week before this — which fixed this class for one suite
/// and left its siblings carrying it. What the next launch comes back to is what the last one had
/// OPEN, so the fix has to run before the app goes away, not after.
///
/// Version history:
///   1.0 — #1279: initial implementation
enum UITestPresentation {

    /// The labels that close a presented surface, in the order to try them.
    ///
    /// Deliberately not "Cancel": on a sheet that edits something, Cancel and Done are different
    /// decisions, and a cleanup helper has no business choosing the destructive one. Everything
    /// this is used on closes with Done.
    private static let dismissLabels = ["Done", "Close"]

    /// Closes a presented surface, if one is open, so the next launch restores a navigable screen.
    ///
    /// **Scoped to the navigation bar, and that is the whole of it.** A bare `app.buttons["Done"]`
    /// is the wrong query twice over here: the keyboard accessory bar this repo added at #861 puts
    /// a Done of its own on screen, and the year popover the sibling scenario opens leaves a dying
    /// Done in the tree after its own dismissal. Measured, the bare query cost two runs — one where
    /// it closed the keyboard instead of the sheet and left the next test facing the same sheet, and
    /// one where `isHittable` on the stale element failed the test outright with *"Activation point
    /// invalid and no suggested hit points based on element frame"*.
    ///
    /// No `isHittable`, for that second reason: it is a query that can FAIL a test, and this runs in
    /// `tearDown`, where a throw would replace a real failure with a cleanup one. `exists` on a
    /// navigation-bar button is the weaker check and the safe one.
    ///
    /// Best-effort by design. A presentation it cannot close is left for the navigator to report,
    /// which it does by name rather than by letting the next test proceed from it.
    ///
    /// - Parameter app: The application under test, or `nil` if the suite has already released it.
    static func dismissAnyPresentation(in app: XCUIApplication?) {
        guard let app, app.state == .runningForeground else { return }
        for label in dismissLabels {
            let button = app.navigationBars.buttons[label].firstMatch
            if button.exists {
                button.tap()
                Thread.sleep(forTimeInterval: 0.75)
                return
            }
        }
    }
}
