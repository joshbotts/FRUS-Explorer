// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import XCTest

/// UI tests verifying that composed views do not obstruct interactive content.
///
/// Three obstruction scenarios are exercised:
///   1. Tab bar (bottom) — does not cover the last row in a browser list
///   2. Breadcrumb bar (top safeAreaInset) — does not cover the first row of a pushed view
///   3. Software keyboard — does not cover the citation lookup field in CitationLookupView
///
/// ## Launch configuration (inherited from `FRUSExplorerUITests` pattern)
/// Each test class configures `XCUIApplication` with:
///   - `FRUS_UI_TEST_MODE = "1"` — local SQLite store, no CloudKit
///   - `-hasCompletedOnboarding 1` — skips OnboardingView, lands in MainTabView
///
/// ## Accessibility identifiers relied upon
/// The tests use standard XCTest element queries (`cells`, `buttons`, `textFields`)
/// rather than hard-coded accessibility identifiers where possible, so no production
/// code changes are required. Where a stable identifier is needed it is noted below.
///
/// Version history:
///   1.0 — Session 52: initial implementation
///   1.1 — Session 156: scenario 1 retries scroll-to-bottom with a settle delay until
///          the last row becomes hittable (the floating tab bar's resting position
///          is reached over several swipes, not two); scenario 3 rewritten against
///          `CitationLookupView` (Search tab → "Find by citation") since the
///          "Activity tab → New Project" flow it previously exercised no longer
///          exists on iOS
final class UIObstructionTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchArguments = ["-hasCompletedOnboarding", "1"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - 1. Tab bar does not obstruct the last browser row

    /// Scrolls the corpus / subseries browser list to the bottom and verifies that
    /// the last visible cell eventually becomes hittable (i.e. not obscured by the
    /// floating tab bar).
    ///
    /// The iOS 18 floating `TabView` bar overlaps the bottom of the `List`'s scroll
    /// content; each `swipeUp` gesture's deceleration/rubber-band animation continues
    /// briefly after the gesture itself returns control to the test, so the list's
    /// final resting position is reached over several swipes rather than after a
    /// fixed count of two. This test repeatedly swipes (with a short settle delay)
    /// until the last row is hittable, guarding against a regression where the row
    /// remains permanently obscured no matter how far the user scrolls.
    func testTabBarNotObstructingLastBrowserRow() throws {
        // The Browse tab is selected by default; confirm we are in the browser.
        // On iOS the tab bar item is labelled "Browse".
        let browseTab = app.tabBars.firstMatch.buttons["Browse"]
        if browseTab.exists {
            browseTab.tap()
        }

        // The corpus list (CorpusView) shows subseries groups as rows.
        // Wait for at least one cell to appear before scrolling.
        let firstCell = app.cells.firstMatch
        let appeared = firstCell.waitForExistence(timeout: 10)
        XCTAssertTrue(appeared, "Expected browser list cells to appear within 10 s")
        XCTAssertGreaterThan(app.cells.count, 0, "Expected at least one cell in the browser list")

        // Scroll toward the bottom of the list, settling briefly after each swipe,
        // until the last cell becomes hittable. XCTest's `isHittable` returns false
        // when a view is clipped or covered.
        var becameHittable = false
        for _ in 1...15 {
            let lastCell = app.cells.element(boundBy: app.cells.count - 1)
            if lastCell.isHittable {
                becameHittable = true
                break
            }
            app.swipeUp(velocity: .fast)
            Thread.sleep(forTimeInterval: 0.5)
        }

        XCTAssertTrue(
            becameHittable,
            "Last browser row never became hittable after repeated scrolling — "
                + "it may be permanently obscured by the tab bar"
        )
    }

    // MARK: - 2. Breadcrumb bar does not obstruct the first row of a pushed view

    /// Navigates into a subseries (pushing a new browser level), causing the
    /// `BrowserBreadcrumbBar` to appear via `.safeAreaInset(edge: .top)`, then
    /// verifies that the first row of the pushed list is hittable.
    ///
    /// `BreadcrumbFlowLayout` sizes the bar dynamically; the `.safeAreaInset`
    /// modifier shifts the list content down by exactly the bar's natural height.
    /// This test guards against any regression where the bar's height is
    /// underreported and the first row slides beneath it.
    func testBreadcrumbBarNotObstructingFirstRow() throws {
        // Ensure we are on the Browse tab.
        let browseTab = app.tabBars.firstMatch.buttons["Browse"]
        if browseTab.exists {
            browseTab.tap()
        }

        // Wait for the corpus list to load then tap the first cell to navigate in.
        let firstCell = app.cells.firstMatch
        let appeared = firstCell.waitForExistence(timeout: 10)
        XCTAssertTrue(appeared, "Expected corpus list cells to appear within 10 s")
        firstCell.tap()

        // After navigating in, the breadcrumb bar appears and a new set of rows loads.
        // Wait briefly for the pushed view's cells to settle.
        let pushedFirstCell = app.cells.firstMatch
        let pushedAppeared = pushedFirstCell.waitForExistence(timeout: 5)
        XCTAssertTrue(pushedAppeared, "Expected cells in pushed browser level within 5 s")

        // Scroll back to the top in case the navigation defaulted to a non-zero offset.
        app.swipeDown(velocity: .fast)

        // The first cell must be hittable — not hidden under the breadcrumb bar.
        XCTAssertTrue(
            app.cells.firstMatch.isHittable,
            "First row in pushed browser level is not hittable — it may be obscured by the breadcrumb bar"
        )
    }

    // MARK: - 3. Software keyboard does not cover the citation lookup field

    /// Opens Citation Lookup from the Search tab, taps the paste-citation
    /// `TextField`, and verifies that the field remains visible (above the keyboard).
    ///
    /// `CitationLookupView` wraps its fields in a `Form`, which uses
    /// `UIScrollView`-backed keyboard avoidance on iOS — the form scrolls so the
    /// focused field stays above the keyboard. This test guards against any
    /// regression where the field is scrolled out of view or the keyboard fully
    /// covers it.
    ///
    /// Note: an earlier version of this test exercised "Activity" tab → "New
    /// Project" → name field. That flow no longer exists on iOS — the Activity tab
    /// was renamed to "Research" (Session 130) and project creation is macOS-only
    /// (`SettingsProjectsPane`). Citation Lookup exercises the same `Form`-based
    /// keyboard-avoidance mechanism and is reachable with no preconditions.
    func testKeyboardDoesNotCoverCitationLookupField() throws {
        // Navigate to the Search tab.
        let searchTab = app.tabBars.firstMatch.buttons["Search"]
        XCTAssertTrue(
            searchTab.waitForExistence(timeout: 5),
            "Search tab bar item not found"
        )
        searchTab.tap()

        // "Find by citation" lives in the "More search actions" overflow menu.
        let moreActions = app.buttons["More search actions"]
        XCTAssertTrue(
            moreActions.waitForExistence(timeout: 5),
            "More search actions toolbar button not found"
        )
        moreActions.tap()

        let citationLookupButton = app.buttons["Find by citation"]
        XCTAssertTrue(
            citationLookupButton.waitForExistence(timeout: 5),
            "Find by citation menu item not found"
        )
        citationLookupButton.tap()

        // The Citation Lookup sheet presents a Form whose first field is the
        // paste-citation text field.
        let pasteField = app.textFields.firstMatch
        let fieldAppeared = pasteField.waitForExistence(timeout: 5)
        XCTAssertTrue(fieldAppeared, "Citation paste text field did not appear in lookup sheet")

        // Tap the field to raise the software keyboard.
        pasteField.tap()

        // Allow the keyboard animation to complete.
        let keyboard = app.keyboards.firstMatch
        let keyboardAppeared = keyboard.waitForExistence(timeout: 3)
        XCTAssertTrue(keyboardAppeared, "Software keyboard did not appear after tapping citation field")

        // The field must still be hittable — Form's scroll-to-visible should have
        // moved it above the keyboard. `isHittable` fails if the element is fully
        // occluded by another view (including the keyboard).
        XCTAssertTrue(
            pasteField.isHittable,
            "Citation paste field is not hittable after keyboard appeared — keyboard may be covering it"
        )
    }
}
