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
/// Five obstruction scenarios are exercised:
///   1. Tab bar (bottom) — does not cover the last row in a browser list
///   2. Breadcrumb bar (top safeAreaInset) — does not cover the first row of a pushed view
///   3. Software keyboard — does not cover the citation lookup field in CitationLookupView
///   4. iPad `.sidebarAdaptable` representations — Browse content stays reachable in BOTH
///      the leading-sidebar and floating-top-tab-bar representations, asserted before and
///      after a live toggle (#238)
///   5. The same for Research content, at the category-list root (#272). The pushed detail is
///      NOT covered — see the note in scenario 5.
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
///   1.3 — Session 1 review pass: scenario 4 made representation-agnostic — it asserts
///          content hittability in the launch representation AND after toggling, using a
///          content-specific subseries cell (sidebar tab rows are also `cells` and were
///          trivially hittable). A single blind toggle could otherwise assert only the
///          never-broken sidebar mode when a prior aborted run leaked the persisted
///          representation.
///   1.4 — #272: added scenario 5 (Research counterpart to scenario 4); `selectBrowseSection`
///          generalised to `selectSection(_:)`, which also fixes scenario 3 on iPad (it
///          hardcoded `app.tabBars`, matching only the iPhone bottom bar, so it failed on
///          every iPad destination).
///   1.5 — Adversarial review of scenario 5: it was green for the wrong reasons twice over.
///          (a) It re-selected the tab after the toggle; in the sidebar representation
///          `app.buttons["Research"]` does not exist, so `selectSection` fell through to the
///          sidebar's tab CELL, and tapping that collapsed the sidebar — both blocks then
///          asserted the floating-top-tab-bar representation and the sidebar was never tested.
///          Removed (the tab selection survives the switch, which is why scenario 4 never
///          re-selected). (b) Its drill-in oracle, `app.staticTexts["All Research Documents"]`,
///          also matches the stack root's own row, so it passed with no push having happened;
///          with a sound oracle the step proved unreliable in-suite, so the drill-in was
///          removed rather than left as a false-green. The root-content assertions now genuinely
///          run in BOTH representations.
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

    /// Selects a tab section by label, resolving the control across the iPhone bottom tab bar
    /// and the iPad `.sidebarAdaptable` sidebar / floating-top-tab-bar representations
    /// (where the tab items surface as buttons, sidebar cells, or plain labelled elements
    /// depending on the representation). Fails the test (rather than silently skipping, as
    /// the earlier `if browseTab.exists` guards did on iPad) when no control can be
    /// found — and dumps the element tree so the failure describes what it actually saw.
    ///
    /// - Parameter label: The tab's label, e.g. "Browse", "Search", "Research".
    @discardableResult
    private func selectSection(_ label: String) -> Bool {
        // Every candidate is resolved with .firstMatch: some representations expose more
        // than one element with the tab's label (e.g. the collapsed top bar plus the sidebar
        // row mid-transition), and tapping an ambiguous element fails with
        // "multiple matching elements found".
        let candidates = [
            app.tabBars.firstMatch.buttons[label].firstMatch,
            app.buttons[label].firstMatch,
            app.cells[label].firstMatch,
            app.cells.containing(NSPredicate(format: "label CONTAINS[c] %@", label)).firstMatch,
            app.descendants(matching: .any).matching(
                NSPredicate(format: "label == %@", label)).firstMatch,
        ]
        for control in candidates where control.waitForExistence(timeout: 3) {
            control.tap()
            return true
        }
        print("[UIObstructionTests] \(label) control not found; element tree:\n\(app.debugDescription)")
        XCTFail("Could not find a '\(label)' control in any tab-bar / sidebar representation "
                + "(element tree printed to the test log)")
        return false
    }

    /// Selects the Browse section. Thin wrapper over `selectSection(_:)`.
    @discardableResult
    private func selectBrowseSection() -> Bool { selectSection("Browse") }

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
        // Navigate to the Search tab. Resolved through selectSection so this works on iPad
        // too: `app.tabBars` only matches the iPhone bottom tab bar, so hardcoding it failed
        // on every iPad destination with "Search tab bar item not found" — the
        // .sidebarAdaptable representations surface tabs as sidebar cells / top-bar buttons.
        selectSection("Search")

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

    // MARK: - 4. iPad tab-bar representations do not obstruct Browse content

    /// A Browse content cell (corpus subseries row), excluding any sidebar tab rows the
    /// `.sidebarAdaptable` sidebar representation exposes as cells — those are trivially
    /// hittable and would let an obstruction assertion pass without testing content.
    private var corpusContentCell: XCUIElement {
        app.cells.containing(NSPredicate(format: "label BEGINSWITH 'Subseries'")).firstMatch
    }

    /// On iPad the tabs render via `.tabViewStyle(.sidebarAdaptable)`, which the user can
    /// toggle between a leading sidebar and a floating top tab bar. In the top-tab-bar
    /// representation a `NavigationSplitView` nested inside the TabView mis-computed the
    /// Browse detail column's top safe area and overlaid content that could not be scrolled
    /// into view (#238).
    ///
    /// The representation is system-persisted per install, the OS toggle is direction-blind
    /// (one control, no state readback), and a fresh install can launch in EITHER
    /// representation — so rather than assuming which mode a single tap lands in, this test
    /// asserts content hittability in the launch representation, toggles, and asserts again
    /// in the other representation. Both modes are always exercised regardless of persisted
    /// state, so a leaked representation from an aborted earlier run cannot green-light the
    /// buggy mode.
    ///
    /// The sidebar toggle is an OS-provided control (`ToggleSideBar` on iPadOS 26); the test
    /// **skips gracefully** (`XCTSkip`) when it cannot be located rather than failing on an
    /// iPadOS version where the affordance moved. It restores the representation in
    /// `tearDown`. iPhone destinations skip (no sidebar representation exists).
    func testBothTabBarRepresentationsDoNotObstructBrowseContent() throws {
        #if canImport(UIKit)
        try XCTSkipUnless(
            UIDevice.current.userInterfaceIdiom == .pad,
            "iPad-only: exercises the .sidebarAdaptable representations"
        )
        #else
        throw XCTSkip("iPad-only test")
        #endif

        guard let toggle = sidebarToggleButton(), toggle.waitForExistence(timeout: 5) else {
            throw XCTSkip("Could not locate the system sidebar/tab-bar toggle on this iPadOS version")
        }

        // Representation A — whatever the install launched in.
        selectBrowseSection()
        XCTAssertTrue(
            corpusContentCell.waitForExistence(timeout: 10),
            "Corpus subseries rows did not appear in the launch representation"
        )
        app.swipeDown(velocity: .fast) // ensure we are scrolled to the top
        XCTAssertTrue(
            corpusContentCell.isHittable,
            "First subseries row is not hittable in the launch tab-bar representation — "
                + "chrome may be overlaying content (#238)"
        )

        // Representation B — toggle (sidebar ⇄ floating top tab bar) and re-assert. The bug
        // is transition-sensitive — the size class stays .regular, so Browse never
        // re-evaluates its layout on the switch. Log the matched control for diagnosis.
        print("[UIObstructionTests] Tapping representation toggle: label='\(toggle.label)' id='\(toggle.identifier)'")
        toggle.tap()
        didToggleSidebar = true
        Thread.sleep(forTimeInterval: 0.7)

        XCTAssertTrue(
            corpusContentCell.waitForExistence(timeout: 10),
            "Corpus subseries rows did not appear after toggling the tab-bar representation"
        )
        app.swipeDown(velocity: .fast)
        XCTAssertTrue(
            corpusContentCell.isHittable,
            "First subseries row is not hittable after toggling the tab-bar representation — "
                + "chrome may be overlaying content (#238)"
        )

        // Drill one level in (still representation B); the pushed level's content must also
        // be reachable. The subseries row label is "Subseries <id>, N volumes"; the pushed
        // SubseriesView lists volume rows.
        corpusContentCell.tap()
        let pushedFirstCell = app.cells.firstMatch
        XCTAssertTrue(
            pushedFirstCell.waitForExistence(timeout: 5),
            "Pushed browser level cells did not appear after the representation toggle"
        )
        app.swipeDown(velocity: .fast)
        XCTAssertTrue(
            app.cells.firstMatch.isHittable,
            "First row of the pushed Browse level is not hittable after the representation toggle (#238)"
        )
    }

    // MARK: - 5. iPad tab-bar representations do not obstruct Research content

    /// A Research **content** row — the synthetic "All Research Documents" entry, which
    /// `ResearchView`'s sidebar always emits regardless of how much user data exists, so this
    /// asserts on real content on a fresh install.
    ///
    /// As with `corpusContentCell`, this deliberately does NOT use `app.cells.firstMatch`: the
    /// `.sidebarAdaptable` sidebar representation exposes the tab rows themselves as cells, and
    /// those are trivially hittable — an obstruction assertion against them would pass without
    /// testing content at all.
    private var researchContentCell: XCUIElement {
        app.cells.containing(
            NSPredicate(format: "label BEGINSWITH 'All Research Documents'")).firstMatch
    }

    /// Pops the Research tab's `NavigationStack` back to its category-list root if it is not
    /// already there.
    ///
    /// Needed because `selectedItem` defaults to `.allNotes` and #272's `researchNavigationPath`
    /// projects `selectedItem` into the stack path — so the tab launches with a non-empty path
    /// and auto-pushes into the "All Research Documents" list, leaving the category root behind a
    /// Back button. Tolerating both shapes keeps this test valid whichever way that lands.
    private func popToResearchRoot() {
        let back = app.buttons["BackButton"]
        if back.waitForExistence(timeout: 3) {
            back.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    /// Scenario 4's counterpart for the Research tab (#272 — the #238 class of bug).
    ///
    /// `ResearchView` nested a `NavigationSplitView` inside the `.sidebarAdaptable` TabView, so
    /// in the collapsed floating-top-tab-bar representation the detail column mis-computed its
    /// top safe area and overlaid content that could not be scrolled into view. iOS now
    /// flattens Research to a `NavigationStack` (category list as the stack root, document list
    /// pushed on selection), mirroring BrowserView's fix.
    ///
    /// Same rationale as scenario 4: the representation is system-persisted and the OS toggle is
    /// direction-blind, so this asserts in the launch representation, toggles, and asserts again
    /// — both modes are exercised whichever one the install launched in. iPad-only; restores the
    /// representation in `tearDown`.
    func testBothTabBarRepresentationsDoNotObstructResearchContent() throws {
        #if canImport(UIKit)
        try XCTSkipUnless(
            UIDevice.current.userInterfaceIdiom == .pad,
            "iPad-only: exercises the .sidebarAdaptable representations"
        )
        #else
        throw XCTSkip("iPad-only test")
        #endif

        guard let toggle = sidebarToggleButton(), toggle.waitForExistence(timeout: 5) else {
            throw XCTSkip("Could not locate the system sidebar/tab-bar toggle on this iPadOS version")
        }

        // Representation A — whatever the install launched in.
        selectSection("Research")
        popToResearchRoot()
        XCTAssertTrue(
            researchContentCell.waitForExistence(timeout: 10),
            "Research category rows did not appear in the launch representation"
        )
        app.swipeDown(velocity: .fast) // ensure we are scrolled to the top
        XCTAssertTrue(
            researchContentCell.isHittable,
            "'All Research Documents' row is not hittable in the launch tab-bar representation — "
                + "chrome may be overlaying content (#272)"
        )

        // Representation B — toggle and re-assert. The bug is transition-sensitive: the size
        // class stays .regular, so the tab's content never re-evaluates its layout on the switch.
        print("[UIObstructionTests] Tapping representation toggle: label='\(toggle.label)' id='\(toggle.identifier)'")
        toggle.tap()
        didToggleSidebar = true
        Thread.sleep(forTimeInterval: 0.7)

        // Do NOT re-select the tab here. The tab selection survives the representation switch
        // (Research stays `Selected`), and in the sidebar representation `app.buttons["Research"]`
        // does not exist — so selectSection would fall through to the sidebar's "Research" tab
        // CELL, and tapping that collapses the sidebar straight back to the floating top tab bar.
        // Both blocks would then assert the SAME representation and the sidebar would never be
        // tested. Scenario 4 does not re-select for exactly this reason.
        XCTAssertTrue(
            researchContentCell.waitForExistence(timeout: 10),
            "Research category rows did not appear after toggling the tab-bar representation"
        )
        app.swipeDown(velocity: .fast)
        XCTAssertTrue(
            researchContentCell.isHittable,
            "'All Research Documents' row is not hittable after toggling the tab-bar "
                + "representation — chrome may be overlaying content (#272)"
        )

        // NOTE — no drill-in step here, deliberately. The pushed detail is NOT covered, and a
        // check for it must not be added back naively:
        //   * The original oracle, `app.staticTexts["All Research Documents"]`, was VACUOUS: the
        //     stack root's own row renders that identical string, so the query matched before the
        //     tap — waitForExistence returned instantly and the step passed without any push.
        //   * With a sound oracle (`app.navigationBars["All Research Documents"]`, which exists
        //     only once the detail is pushed) the step proved unreliable in-suite: the tap does
        //     not consistently drive the push after the preceding swipe, in either a Cell tap or
        //     a row-button tap, with or without a settle delay.
        //   * The app itself is fine — an instrumented probe (tap row -> assert navigationBar,
        //     no preceding swipe) pushes reliably. This is a harness problem, not a #272 bug.
        // Covering the pushed detail needs its own investigation; a false-green is worse than a
        // documented gap, so the root-content assertions above stand alone for now.
    }
}
