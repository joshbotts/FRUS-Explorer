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
///   3. Software keyboard — does not cover the project name field in ProjectEditorView
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
    /// the last visible cell is hittable (i.e. not obscured by the tab bar).
    ///
    /// The SwiftUI `TabView` automatically adds safe-area insets for its tab bar, and
    /// `List` respects those insets — so the last row should always scroll clear of
    /// the bar. This test acts as a regression guard.
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

        // Scroll to the very bottom of the list.
        app.swipeUp(velocity: .fast)
        app.swipeUp(velocity: .fast)

        // After scrolling, the last cell in the list should be fully visible and hittable.
        // XCTest's `isHittable` returns false when a view is clipped or covered.
        let lastCell = app.cells.element(boundBy: app.cells.count - 1)
        XCTAssertTrue(lastCell.exists, "Expected at least one cell to remain after scrolling")
        XCTAssertTrue(
            lastCell.isHittable,
            "Last browser row is not hittable — it may be obscured by the tab bar"
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

    // MARK: - 3. Software keyboard does not cover the project name field

    /// Navigates to the Activity tab, creates a new project, taps the name
    /// `TextField`, and verifies that the field remains visible (above the keyboard).
    ///
    /// `ProjectEditorView` wraps its fields in a `Form`, which uses
    /// `UIScrollView`-backed keyboard avoidance on iOS — the form scrolls so the
    /// focused field stays above the keyboard. This test guards against any
    /// regression where the field is scrolled out of view or the keyboard fully
    /// covers it.
    func testKeyboardDoesNotCoverProjectNameField() throws {
        // Navigate to the Activity tab.
        let activityTab = app.tabBars.firstMatch.buttons["Activity"]
        XCTAssertTrue(
            activityTab.waitForExistence(timeout: 5),
            "Activity tab bar item not found"
        )
        activityTab.tap()

        // Tap the "+" button to open the new-project editor.
        let addButton = app.navigationBars.buttons["Add"]
            .firstMatch
        // Fall back to any "+" or "New Project" button if "Add" label not used.
        let addFallback = app.buttons["New Project"].firstMatch
        let addBtnExists = addButton.waitForExistence(timeout: 5)
            || addFallback.waitForExistence(timeout: 2)
        XCTAssertTrue(addBtnExists, "No new-project button found in Activity tab navigation bar")

        if addButton.exists && addButton.isHittable {
            addButton.tap()
        } else {
            addFallback.tap()
        }

        // The project editor presents. Wait for a text field (project name).
        let nameField = app.textFields.firstMatch
        let fieldAppeared = nameField.waitForExistence(timeout: 5)
        XCTAssertTrue(fieldAppeared, "Project name text field did not appear in editor")

        // Tap the field to raise the software keyboard.
        nameField.tap()

        // Allow the keyboard animation to complete.
        let keyboard = app.keyboards.firstMatch
        let keyboardAppeared = keyboard.waitForExistence(timeout: 3)
        XCTAssertTrue(keyboardAppeared, "Software keyboard did not appear after tapping name field")

        // The field must still be hittable — Form's scroll-to-visible should have
        // moved it above the keyboard. `isHittable` fails if the element is fully
        // occluded by another view (including the keyboard).
        XCTAssertTrue(
            nameField.isHittable,
            "Project name field is not hittable after keyboard appeared — keyboard may be covering it"
        )
    }
}
