// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import XCTest

// MARK: - ToolbarOverflowAccessibilityTests

/// Regression coverage for R-8: a toolbar control's name must survive the iPadOS
/// navigation-bar overflow.
///
/// ## The defect
/// The Browse analysis menu announced the raw SF Symbol string `chart.bar.xaxis` instead
/// of "Analysis Tools". `.controlHelp` does apply `.accessibilityLabel` on iOS, and the
/// in-bar button carried it correctly — but when iPadOS collapses a toolbar item into the
/// `OverflowBarButtonItem` popover it re-hosts it as a UIKit menu row and **re-derives**
/// the row's name from the content of the item's `label:` closure. A `Label`'s text wins;
/// with a bare `Image(systemName:)` the fallback is the image's own accessibility name,
/// which for an SF Symbol is the symbol string. Modifiers applied outside the label
/// closure never reach the overflow row.
///
/// Measured on iPad Pro 13-inch (M5), iPadOS 26.5, with the seam below active:
///
/// | Toolbar item shape | overflow row label |
/// |---|---|
/// | `Menu … label: { Image(systemName:) }` + `.accessibilityLabel` | ❌ the symbol string |
/// | `Menu … label: { Label(name, systemImage:) }` | ✅ `name` |
/// | `Button … label: { Label(name, systemImage:) }` | ✅ `name` |
///
/// ## Why this suite needs a seam
/// The bug is invisible while the item sits in the bar, and no shipping iPad width
/// collapses the three-item Browse toolbar — measured on iPad Pro 13-inch (M5) and iPad
/// mini (A17 Pro), portrait, both of which keep all three items visible. A test that only
/// asserted `app.buttons["Analysis Tools"].exists` would therefore have passed against the
/// defect. `BrowserView.uiTestOverflowFillerItems` (`#if DEBUG`, off unless
/// `FRUS_UI_TEST_TOOLBAR_OVERFLOW=1`) adds six inert items so the real controls overflow,
/// which is the state these assertions are about.
///
/// Version history:
///   1.0 — Wave R / R-8: initial implementation
@MainActor
final class ToolbarOverflowAccessibilityTests: XCTestCase {

    /// The name the analysis menu must announce, in the bar and in the overflow alike.
    private static let analysisToolsLabel = "Analysis Tools"
    /// The raw SF Symbol the defect leaked in place of that name.
    private static let analysisToolsSymbol = "chart.bar.xaxis"

    var app: XCUIApplication!

    /// Read through a closure: `launch(forcingToolbarOverflow:)` mints a fresh `XCUIApplication`
    /// inside each test, and a stored reference would leave the navigator driving a dead process.
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    override func tearDownWithError() throws {
        // This suite had no teardown at all, and it opens the analysis menu in all three tests
        // (#1279). A menu is not a window, so it is the mildest of the three producers — but the
        // rule is the rule, and this suite is also the one that was VICTIM of it, measuring another
        // suite's leftover window and reporting on it as the Browse toolbar.
        UITestPresentation.dismissAnyPresentation(in: app)
        app?.terminate()
        app = nil
    }

    // MARK: - Tests

    /// **The regression guard.** With the Browse toolbar forced into overflow on iPad, the
    /// analysis menu must be reachable by its intended label and must NOT be reachable by
    /// its SF Symbol name.
    func testAnalysisMenuKeepsItsNameInTheIPadToolbarOverflow() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad,
                          "The navigation-bar overflow control is an iPad layout; run this on an iPad destination.")

        launch(forcingToolbarOverflow: true)
        gotoBrowse()

        // The seam must actually have produced an overflow, or the assertions below are vacuous.
        let overflow = overflowControl()
        XCTAssertTrue(overflow.waitForExistence(timeout: 10),
                      "FRUS_UI_TEST_TOOLBAR_OVERFLOW did not push the Browse toolbar into an overflow "
                      + "control, so this test cannot observe what it exists to check. Add filler items "
                      + "to BrowserView.uiTestOverflowFillerItems until it does.")
        overflow.tap()

        let named = app.buttons[Self.analysisToolsLabel].firstMatch
        XCTAssertTrue(named.waitForExistence(timeout: 5),
                      "The overflowed analysis menu should announce \"\(Self.analysisToolsLabel)\". "
                      + "Buttons on screen: \(visibleButtonLabels())")

        // The precise before/after oracle: pre-fix this query matched and the one above did not.
        XCTAssertFalse(app.buttons[Self.analysisToolsSymbol].exists,
                       "The overflowed analysis menu is exposing its raw SF Symbol name "
                       + "(\"\(Self.analysisToolsSymbol)\") — put the name back in its `label:` closure "
                       + "as a `Label`, not an `Image`.")
    }

    /// Control: with no overflow forced, the same button is a plain bar item and already
    /// carried the right label before the fix. This is what pins that the fix did not
    /// regress the non-overflowed representation — and, run alongside the test above, it
    /// is what shows the seam (not the platform) is what changes the outcome.
    func testAnalysisMenuKeepsItsNameWithoutOverflow() throws {
        launch(forcingToolbarOverflow: false)
        gotoBrowse()

        let named = app.buttons[Self.analysisToolsLabel].firstMatch
        XCTAssertTrue(named.waitForExistence(timeout: 10),
                      "The in-bar analysis menu should announce \"\(Self.analysisToolsLabel)\". "
                      + "Buttons on screen: \(visibleButtonLabels())")
        XCTAssertFalse(app.buttons[Self.analysisToolsSymbol].exists,
                       "The in-bar analysis menu should never expose its SF Symbol name.")
    }

    /// The menu must still open and offer its items — a `Label` in place of the `Image`
    /// changes what VoiceOver reads, and this pins that it changed nothing else.
    func testAnalysisMenuStillOpensItsItems() throws {
        launch(forcingToolbarOverflow: false)
        gotoBrowse()

        let menu = app.buttons[Self.analysisToolsLabel].firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: 10), "Analysis menu should exist")
        menu.tap()

        XCTAssertTrue(app.buttons["Corpus Analytics"].firstMatch.waitForExistence(timeout: 5),
                      "Corpus Analytics should be offered by the analysis menu")
    }

    // MARK: - Helpers

    private func launch(forcingToolbarOverflow: Bool) {
        continueAfterFailure = false
        // XCUIDevice orientation is process-wide and survives between suites, so a
        // landscape leftover from the rotation tests would silently change this layout.
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        if forcingToolbarOverflow {
            app.launchEnvironment["FRUS_UI_TEST_TOOLBAR_OVERFLOW"] = "1"
        }
        app.launchArguments = UITestLaunch.arguments()
        app.launch()
    }

    private func gotoBrowse() {
        // Asserted, not attempted (#1279). This suite measures the BROWSE toolbar; the bare guard
        // it replaces could not fail, so on a miss every assertion below read whatever toolbar was
        // on screen and reported on it as Browse's. Measured at `69dfac7d` on iPad mini (A17 Pro),
        // that is not hypothetical: after `AnalyticsKeyboardTests` left a sheet standing, all three
        // tests here failed against the Corpus Analytics sheet's own buttons.
        //
        // `resolveTimeout: 15` keeps the tolerance the bare wait had: this runs immediately after
        // `launch()`, and a cold start can take that long to draw a tab bar at all.
        XCTAssertTrue(navigator.select(.browse, resolveTimeout: 15).tapped,
                      "Could not open the Browse tab, so this suite would measure another screen.")
        _ = app.navigationBars.firstMatch.waitForExistence(timeout: 10)
    }

    /// The navigation bar's overflow control. UIKit gives it the accessibility identifier
    /// `OverflowBarButtonItem`; the label fallbacks cover a future rename.
    private func overflowControl() -> XCUIElement {
        let byIdentifier = app.buttons["OverflowBarButtonItem"].firstMatch
        if byIdentifier.exists { return byIdentifier }
        for label in ["More", "Show More", "More Actions"] {
            let candidate = app.buttons[label].firstMatch
            if candidate.exists { return candidate }
        }
        return byIdentifier
    }

    /// Failure-message aid: what a query could have matched instead.
    private func visibleButtonLabels() -> String {
        app.buttons.allElementsBoundByIndex
            .prefix(30)
            .map(\.label)
            .filter { !$0.isEmpty }
            .joined(separator: " | ")
    }
}
