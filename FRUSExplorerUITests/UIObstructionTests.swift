// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import XCTest
#if canImport(UIKit)
import UIKit
#endif

/// UI tests verifying that composed views do not obstruct interactive content.
///
/// Four obstruction scenarios are exercised:
///   1. Tab bar (bottom) — does not cover the last row in a browser list
///   2. Breadcrumb bar (top safeAreaInset) — does not cover the first row of a pushed view
///   3. Software keyboard — does not cover the citation lookup field in CitationLookupView
///   4. iPad `.sidebarAdaptable` floating top tab bar — does not cover Browse content when
///      the sidebar is toggled into its top-tab-bar representation (#238)
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
///   1.2 — Session 1 / #238: added scenario 4 (iPad sidebar → floating top tab bar);
///          the Browse-tab guards resolve the control across bottom-bar / sidebar /
///          top-bar representations and now fail loudly instead of silently skipping
///          on iPad.
//
// Note: the iOS 26 SDK isolates the XCUI APIs (`XCUIApplication`/`XCUIElement`) to the main
// actor, so building this suite under Swift 6 emits `main actor-isolated … nonisolated
// context` warnings on every UI call throughout the file. These are pre-existing and
// SDK-driven (they cover the original scenarios 1–3 too); `@MainActor` on the class would
// silence them but conflicts with the throwing `setUpWithError`/`tearDownWithError`
// overrides ("sending self"), so they are left as-is. The app-target zero-warning gate
// (`CodingStandardsAuditTests`) does not cover this UI-test target.
final class UIObstructionTests: XCTestCase {

    var app: XCUIApplication!

    /// Set when scenario 4 toggles the iPad sidebar representation, so `tearDown` can
    /// restore it (the representation is system-persisted per install and would otherwise
    /// leak into later tests / runs).
    private var didToggleSidebar = false

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchArguments = ["-hasCompletedOnboarding", "1"]
        app.launch()
    }

    override func tearDownWithError() throws {
        if didToggleSidebar, let toggle = sidebarToggleButton(), toggle.exists {
            toggle.tap()
            didToggleSidebar = false
        }
        app = nil
    }

    // MARK: - Helpers

    /// Selects the Browse section, resolving the control across the iPhone bottom tab bar
    /// and the iPad `.sidebarAdaptable` sidebar / floating-top-tab-bar representations
    /// (where the tab items surface as buttons, sidebar cells, or plain labelled elements
    /// depending on the representation). Fails the test (rather than silently skipping, as
    /// the earlier `if browseTab.exists` guards did on iPad) when no Browse control can be
    /// found — and dumps the element tree so the failure describes what it actually saw.
    @discardableResult
    private func selectBrowseSection() -> Bool {
        let candidates = [
            app.tabBars.firstMatch.buttons["Browse"],
            app.buttons["Browse"],
            app.cells["Browse"],
            app.cells.containing(NSPredicate(format: "label CONTAINS[c] 'Browse'")).firstMatch,
            app.descendants(matching: .any).matching(
                NSPredicate(format: "label == 'Browse'")).firstMatch,
        ]
        for control in candidates where control.waitForExistence(timeout: 3) {
            control.tap()
            return true
        }
        print("[UIObstructionTests] Browse control not found; element tree:\n\(app.debugDescription)")
        XCTFail("Could not find a 'Browse' control in any tab-bar / sidebar representation "
                + "(element tree printed to the test log)")
        return false
    }

    /// The OS-provided control that toggles the `.sidebarAdaptable` TabView between its
    /// leading-sidebar and floating-top-tab-bar representations. On iPadOS 26 it carries the
    /// stable accessibility identifier `ToggleSideBar` (label "Toggle sidebar" — confirmed by
    /// a live simulator run); the fuzzy label predicate remains as a fallback for OS versions
    /// that rename the identifier. Callers must treat a `nil` result as "skip".
    private func sidebarToggleButton() -> XCUIElement? {
        let byIdentifier = app.buttons["ToggleSideBar"]
        if byIdentifier.exists { return byIdentifier }
        let predicate = NSPredicate(format:
            "label CONTAINS[c] 'sidebar' OR label CONTAINS[c] 'tab bar'")
        let matches = app.buttons.matching(predicate)
        return matches.count > 0 ? matches.firstMatch : nil
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
        selectBrowseSection()

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
        selectBrowseSection()

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

    // MARK: - 4. iPad sidebar → floating top tab bar does not obstruct Browse content

    /// On iPad the tabs render via `.tabViewStyle(.sidebarAdaptable)`, which the user can
    /// toggle between a leading sidebar and a floating top tab bar. In the top-tab-bar
    /// representation a `NavigationSplitView` nested inside the TabView mis-computed the
    /// Browse detail column's top safe area and overlaid content that could not be scrolled
    /// into view (#238). This test toggles into that representation and asserts the Browse
    /// list's first row — at the corpus root and one level in — is hittable.
    ///
    /// The sidebar toggle is an OS-provided control with no stable identifier, so the test
    /// **skips gracefully** (`XCTSkip`) when it cannot be located rather than failing on an
    /// iPadOS version where the affordance moved. It restores the representation in
    /// `tearDown`. iPhone destinations skip (no sidebar representation exists).
    func testSidebarTopTabBarModeDoesNotObstructBrowseContent() throws {
        #if canImport(UIKit)
        try XCTSkipUnless(
            UIDevice.current.userInterfaceIdiom == .pad,
            "iPad-only: exercises the .sidebarAdaptable floating top tab bar"
        )
        #else
        throw XCTSkip("iPad-only test")
        #endif

        guard let toggle = sidebarToggleButton(), toggle.waitForExistence(timeout: 5) else {
            throw XCTSkip("Could not locate the system sidebar/tab-bar toggle on this iPadOS version")
        }

        // Switch representation (sidebar ⇄ floating top tab bar) and let it settle. The bug
        // is transition-sensitive — the size class stays .regular, so Browse never
        // re-evaluates its layout on the switch. Log which control the fuzzy predicate
        // matched so a mis-match is diagnosable from the test log.
        print("[UIObstructionTests] Tapping representation toggle: label='\(toggle.label)' id='\(toggle.identifier)'")
        toggle.tap()
        didToggleSidebar = true
        Thread.sleep(forTimeInterval: 0.7)

        selectBrowseSection()

        let firstCell = app.cells.firstMatch
        XCTAssertTrue(
            firstCell.waitForExistence(timeout: 10),
            "Corpus list cells did not appear after toggling the tab-bar representation"
        )
        app.swipeDown(velocity: .fast) // ensure we are scrolled to the top
        XCTAssertTrue(
            app.cells.firstMatch.isHittable,
            "First Browse row is not hittable in the floating-top-tab-bar representation — "
                + "chrome may be overlaying content (#238)"
        )

        // Drill one level in; the first row of the pushed level must also be reachable.
        app.cells.firstMatch.tap()
        let pushedFirstCell = app.cells.firstMatch
        XCTAssertTrue(
            pushedFirstCell.waitForExistence(timeout: 5),
            "Pushed browser level cells did not appear in top-tab-bar mode"
        )
        app.swipeDown(velocity: .fast)
        XCTAssertTrue(
            app.cells.firstMatch.isHittable,
            "First row of the pushed Browse level is not hittable in top-tab-bar mode (#238)"
        )
    }
}
