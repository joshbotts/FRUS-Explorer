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
/// The bug is invisible while the item sits in the bar, and with no project active no
/// shipping iPad width collapses the three-item Browse toolbar — measured on iPad Pro 13-inch
/// (M5) and iPad mini (A17 Pro), portrait, both of which keep all three items visible. WITH a
/// project active the mini collapses it on its own, which is accepted; see
/// ``testAnalysisMenuIsReachableByNameWithAProjectActive()``. A test that only
/// asserted `app.buttons["Analysis Tools"].exists` would therefore have passed against the
/// defect. `BrowserView.uiTestOverflowFillerItems` (`#if DEBUG`, off unless
/// `FRUS_UI_TEST_TOOLBAR_OVERFLOW=1`) adds six inert items so the real controls overflow,
/// which is the state these assertions are about.
///
/// Version history:
///   1.0 — Wave R / R-8: initial implementation
///   1.1 — 2026-09-18: the active-project reachability guard; launches pin Global context
@MainActor
final class ToolbarOverflowAccessibilityTests: XCTestCase {

    /// The name the analysis menu must announce, in the bar and in the overflow alike.
    private static let analysisToolsLabel = "Analysis Tools"
    /// The raw SF Symbol the defect leaked in place of that name.
    private static let analysisToolsSymbol = "chart.bar.xaxis"
    /// A project the UI-test store does not hold. The app still treats it as active for its chrome,
    /// which is all the width question depends on: the picker is icon-only in the bar, and its glyph
    /// is `folder` for any active project, real or not.
    private static let absentProjectId = "11111111-2222-3333-4444-555555555555"

    var app: XCUIApplication!

    /// Read through a closure: `launch(forcingToolbarOverflow:)` mints a fresh `XCUIApplication`
    /// inside each test, and a stored reference would leave the navigator driving a dead process.
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    override func tearDown() async throws {
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
        // And it must have taken the ANALYSIS MENU, not only fillers: in the bar the menu is named
        // correctly with or without the defect, so a pass there would measure nothing.
        XCTAssertFalse(app.navigationBars.buttons[Self.analysisToolsLabel].exists,
                       "The analysis menu is still in the bar, so the seam did not re-host it. The "
                       + "fillers must come BEFORE the real items in BrowserView's toolbars.")
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

    /// **The active-project guard.** With a project active on iPad mini (744 pt) in portrait, the
    /// picker's `folder` glyph is a few points wider than `globe`, the three Browse items no longer fit
    /// beside the floating tab bar, and the analysis menu is re-hosted into the system "…" overflow —
    /// measured on iPadOS 26.3, 26.5 and 27.0 alike. That is ACCEPTED, not fixed (see
    /// `BrowserView.uiTestOverflowFillerItems`), so what this pins is the promise that makes it
    /// acceptable: the menu stays reachable, and by its name. Unlike the seam-forced test above, it
    /// reaches the overflow the way a reader does, with nothing but an active project.
    ///
    /// On a wider iPad the menu stays in the bar and the first branch passes; the suite is run on
    /// the mini for the second.
    func testAnalysisMenuIsReachableByNameWithAProjectActive() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad,
                          "The Browse toolbar only runs out of room beside the iPad floating tab bar.")

        launch(forcingToolbarOverflow: false, activeProjectId: Self.absentProjectId)
        gotoBrowse()
        _ = app.buttons["Switch project context"].firstMatch.waitForExistence(timeout: 10)

        if app.navigationBars.buttons[Self.analysisToolsLabel].firstMatch.exists { return }

        let overflow = overflowControl()
        XCTAssertTrue(overflow.waitForExistence(timeout: 5),
                      "The analysis menu is neither in the bar nor behind an overflow control. "
                      + "Buttons on screen: \(visibleButtonLabels())")
        overflow.tap()
        XCTAssertTrue(app.buttons[Self.analysisToolsLabel].firstMatch.waitForExistence(timeout: 5),
                      "The overflow does not offer the analysis menu by name. "
                      + "Buttons on screen: \(visibleButtonLabels())")
        XCTAssertFalse(app.buttons[Self.analysisToolsSymbol].exists,
                       "The overflowed analysis menu exposes its raw SF Symbol name (R-8).")
    }

    // MARK: - Helpers

    private func launch(forcingToolbarOverflow: Bool, activeProjectId: String = "") {
        continueAfterFailure = false
        // XCUIDevice orientation is process-wide and survives between suites, so a
        // landscape leftover from the rotation tests would silently change this layout.
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        if forcingToolbarOverflow {
            app.launchEnvironment["FRUS_UI_TEST_TOOLBAR_OVERFLOW"] = "1"
        }
        app.launchArguments = UITestLaunch.arguments(activeProjectId: activeProjectId)
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
