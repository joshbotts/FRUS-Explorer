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
///   5. The same for Research content (#272)
///
/// Scenario 4 covers the Browse tab's ROOT list only; its drill-in asserted nothing and was
/// removed (see 1.6). Scenario 5 now covers Research's root list AND the pushed detail level in
/// the launch representation (see 1.7) — the pushed level is where #272's bug actually lives, so
/// root-only coverage was gating the wrong column entirely. Its remaining gaps are enumerated in
/// the coverage ledger at the end of that scenario. A false-green is worse than a documented gap;
/// so is a documented gap that was never re-measured.
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
///   1.6 — The same audit applied to scenario 4's drill-in, which had the identical defect and
///          predates scenario 5: it asserted `app.cells.firstMatch` — the naked query
///          `corpusContentCell` exists to avoid — which matches the un-pushed list, so it passed
///          without navigating. Measured on iPad: after the tap `backButton=false` and the nav
///          bar stayed "FRUS Corpus" (no push), yet the assertion reported true; repeated taps
///          did not push either. Root cause (shared with scenario 5): an XCUITest tap on a
///          SwiftUI List row's Cell element does not activate the Button inside it. Removed;
///          the pushed level is now an explicit, documented gap in both scenarios.
///   1.7 — #272 follow-up, all of it measured on iPad Pro 13-inch (M5); two claims above do not
///          survive re-measurement. (a) 1.6's shared root cause does NOT hold for Research: a tap
///          on `researchContentCell` DOES push (nav bar becomes "All Research Documents",
///          `BackButton` appears). What actually defeated it was ORDER — a preceding `swipeDown`
///          stops the tap driving the push. Drilling in BEFORE the swipe works, so scenario 5's
///          drill-in is restored with 1.5's own suggested sound oracle (`app.navigationBars[...]`),
///          covering the DETAIL column that root-only assertions never reached. It stays scoped to
///          the launch representation, where it is reliable; a run with it after the toggle fails
///          on the same ordering quirk. (Whether 1.6's claim holds for scenario 4's Corpus row is
///          untested here.) (b) `popToResearchRoot()` is retired: it presumed an auto-push that an
///          A/B run shows does not happen, so it was a silent no-op that also navigated every
///          assertion away from the detail column. Replaced by `assertResearchLaunchedAtCategoryRoot`,
///          a sound-oracle guard on that hazard — explicitly NOT a reproduction of it.
///   1.8 — #311: scenarios 4 and 5 could report GREEN having asserted nothing. `sidebarToggleButton()`
///          returns an element only once it exists, so each scenario's
///          `toggle.waitForExistence(timeout: 5)` was dead code — the intended tolerance for a slow
///          launch never ran, and the `guard let` hit nil first and threw `XCTSkip` (a skip passes).
///          The wait moved inside the helper, which now polls to a `timeout:` (0 in `tearDown`,
///          where the control's absence is not a failure), and both guards `XCTFail` instead of
///          skipping — past the idiom check the destination IS an iPad, so a missing toggle is a
///          real fault. Mirrors the same correction 1.2 made to the Browse-tab guards.
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
        // timeout: 0 — restoring the representation is best-effort; if the control is already
        // gone there is nothing to restore and tearDown should not stall polling for it.
        if didToggleSidebar, let toggle = sidebarToggleButton(timeout: 0), toggle.exists {
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
    /// that rename the identifier.
    ///
    /// **Polls until `timeout`** (#311). It must: this returns an element only once it exists, so
    /// a caller's `toggle.waitForExistence(timeout:)` is dead code — it can only ever be true, and
    /// callers who wrote one got no wait at all. A slow launch therefore returned nil immediately
    /// and the caller's `guard` threw `XCTSkip`, so both iPad obstruction scenarios reported GREEN
    /// having asserted nothing. The wait has to live here, before the nil.
    ///
    /// - Parameter timeout: How long to keep polling before giving up. Pass `0` for a single
    ///   immediate probe (`tearDown` does, where the control's absence is not a failure).
    /// - Returns: The toggle, or `nil` if it never appeared. On an iPad destination `nil` means
    ///   something is genuinely wrong — prefer failing over skipping.
    private func sidebarToggleButton(timeout: TimeInterval = 5) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            let byIdentifier = app.buttons["ToggleSideBar"]
            if byIdentifier.exists { return byIdentifier }
            // Built fresh each iteration, deliberately: NSPredicate is not Sendable, and the iOS 26
            // SDK isolates XCUI APIs to the main actor, so `matching(_:)` sends it out of this
            // nonisolated context. A predicate hoisted above the loop would be sent on the first
            // pass and used again on the second — "sending 'predicate' risks causing data races",
            // a hard error under Swift 6. Re-creating it keeps each send a fresh transfer.
            let predicate = NSPredicate(format:
                "label CONTAINS[c] 'sidebar' OR label CONTAINS[c] 'tab bar'")
            let matches = app.buttons.matching(predicate)
            if matches.count > 0 { return matches.firstMatch }
            if timeout <= 0 { break }
            Thread.sleep(forTimeInterval: 0.25)
        } while Date() < deadline
        return nil
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

        // Fails rather than skips (#311). Execution only reaches here on an iPad destination, so
        // the toggle is required to exist — and this used to XCTSkip, which reports GREEN. The
        // wait now lives inside the helper; the `waitForExistence` that stood here was dead code
        // against an element the helper only returns once it exists.
        guard let toggle = sidebarToggleButton() else {
            XCTFail("Could not locate the system sidebar/tab-bar toggle on this iPad destination "
                    + "after polling 5s — this scenario cannot exercise both .sidebarAdaptable "
                    + "representations without it (#238/#272 regression net is not running)")
            return
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

        // NOTE — the drill-in that used to live here was REMOVED: it asserted nothing.
        // It did `corpusContentCell.tap()` and then asserted `app.cells.firstMatch` — the exact
        // naked query `corpusContentCell` above exists to avoid. That query matches the
        // *un-pushed* corpus list (and, in the sidebar representation, the tab rows themselves),
        // so it passed whether or not the tap navigated. Instrumented on iPad Pro 13-inch (M5):
        // after the tap, `backButton=false` and the nav bar stayed "FRUS Corpus" — i.e. NO push
        // ever happened — while the old assertion still reported true. Repeated taps (2nd, 3rd)
        // did not push either.
        //
        // Do not restore it naively. `corpusContentCell.tap()` does not activate the row: an
        // XCUITest tap on a SwiftUI List row's Cell element does not trigger the Button inside
        // it here (the same behaviour was measured independently for Research in scenario 5).
        // Covering the pushed level needs its own investigation into the right tap target and a
        // sound oracle (the pushed SubseriesView sets `.navigationTitle(group.subseries)`, so a
        // navigationBars title change or a BackButton is the signal — never `app.cells`).
        // The four assertions above are the real #238 regression gate and are unaffected.
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

    /// Asserts the Research tab launched at its category-list root rather than auto-pushed one
    /// level deep into a document list.
    ///
    /// The oracle is verified; the hazard it guards is latent. That distinction is deliberate.
    ///
    /// #272 flattened iOS Research to a `NavigationStack` whose path *projects* `selectedItem`,
    /// so a non-nil default asks the stack to launch already pushed, stranding the category list
    /// behind a Back button. `ResearchView` defaults to `nil` on iOS to foreclose that.
    ///
    /// What this does NOT do is fail when that default is re-unified: measured on iPad Pro
    /// 13-inch (M5) at dd16bd7, `.allNotes` on iOS still launches at the root, because SwiftUI
    /// discards the initial path element. So this gates a latent hazard activating — it does not
    /// reproduce a live bug. Do NOT upgrade this comment to "catches the regression" without
    /// re-measuring: a8b20ca recorded that stronger claim and it does not reproduce.
    ///
    /// The oracle itself IS sound, probed in both states: at the category root there is no
    /// back-ish button at all; pushed, one surfaces as `[BackButton|Research]`. If the hazard
    /// ever activates, this fails.
    ///
    /// Replaces the former `popToResearchRoot()`, which tapped Back to work around the auto-push
    /// it presumed — and in doing so navigated away from the detail column before every
    /// assertion, leaving scenario 5 asserting only on the stack root. Since there is no
    /// auto-push, that helper was also a silent no-op: its `waitForExistence` never matched.
    private func assertResearchLaunchedAtCategoryRoot(_ context: String) {
        XCTAssertFalse(
            app.buttons["BackButton"].waitForExistence(timeout: 2),
            "Research launched auto-pushed into a document list instead of at its category root "
                + "(\(context)) — ResearchView.selectedItem must default to nil on iOS, since "
                + "researchNavigationPath projects it into the NavigationStack path (#272)"
        )
    }

    /// Drills into "All Research Documents" and asserts the **pushed detail level** — the column
    /// #272 is actually about — appears and is not overlaid by the floating tab bar.
    ///
    /// Oracle: `app.navigationBars["All Research Documents"]`, which exists only once the detail
    /// is pushed. This is the sound oracle e403faf identified but did not adopt; the oracle it
    /// removed (`app.staticTexts["All Research Documents"]`) was vacuous because the stack root's
    /// own row renders that identical string, so it matched before any tap.
    ///
    /// Call this BEFORE any swipe on the root list. An immediately-preceding swipe stops the row
    /// tap from driving the push (a harness quirk e403faf measured; an instrumented probe without
    /// the swipe pushes reliably). Ordering is therefore load-bearing, not incidental.
    ///
    /// SCOPE — read before trusting this as full #272 coverage: it gates the push and the detail's
    /// top chrome, NOT the obstruction of detail *content*. On a fresh install the document list
    /// is legitimately empty and renders a *centered* `ContentUnavailableView`, so there is no
    /// top-anchored content for the mis-computed safe area to hide. Closing that gap needs seeded
    /// research data (tracked separately) — do not claim content-level coverage until it exists.
    private func assertResearchDetailPushesUnobstructed(_ context: String) {
        researchContentCell.tap()
        let detailBar = app.navigationBars["All Research Documents"]
        guard detailBar.waitForExistence(timeout: 10) else {
            XCTFail("Tapping 'All Research Documents' did not push the document list (\(context))")
            return
        }
        XCTAssertTrue(
            detailBar.isHittable,
            "The pushed document list's navigation bar is not hittable (\(context)) — the "
                + "floating top tab bar may be overlaying the detail column's top safe area (#272)"
        )
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

        // Fails rather than skips (#311). Execution only reaches here on an iPad destination, so
        // the toggle is required to exist — and this used to XCTSkip, which reports GREEN. The
        // wait now lives inside the helper; the `waitForExistence` that stood here was dead code
        // against an element the helper only returns once it exists.
        guard let toggle = sidebarToggleButton() else {
            XCTFail("Could not locate the system sidebar/tab-bar toggle on this iPad destination "
                    + "after polling 5s — this scenario cannot exercise both .sidebarAdaptable "
                    + "representations without it (#238/#272 regression net is not running)")
            return
        }

        // Representation A — whatever the install launched in.
        selectSection("Research")
        XCTAssertTrue(
            researchContentCell.waitForExistence(timeout: 10),
            "Research category rows did not appear in the launch representation"
        )
        assertResearchLaunchedAtCategoryRoot("launch representation")
        // Detail level BEFORE the swipe — the swipe would stop the tap driving the push.
        assertResearchDetailPushesUnobstructed("launch representation")
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
        // No drill-in here — MEASURED, not assumed. The row tap will not drive the push once a
        // swipe has preceded it (representation A's swipeDown, above), which is exactly the quirk
        // e403faf hit; a run with the drill-in here fails on "did not push the document list".
        // Ordering it first works in representation A only, so that is where it lives.
        app.swipeDown(velocity: .fast)
        XCTAssertTrue(
            researchContentCell.isHittable,
            "'All Research Documents' row is not hittable after toggling the tab-bar "
                + "representation — chrome may be overlaying content (#272)"
        )

        // COVERAGE LEDGER for #272 — what this scenario proves, and what it still does not.
        // Every line below was measured on iPad Pro 13-inch (M5), not reasoned about.
        //
        // GATED: the root list is unobstructed in BOTH representations; tapping a category
        // actually pushes the detail, and the pushed detail's top chrome is hittable — in the
        // LAUNCH representation. Plus the tab launches at its category root, which guards a
        // latent hazard (see assertResearchLaunchedAtCategoryRoot) rather than a live bug: an
        // A/B run proved `.allNotes` vs nil on iOS are indistinguishable at launch, so that
        // assertion does NOT discriminate the ResearchView default. Claim it as nothing more.
        //
        // NOT GATED, two distinct gaps, neither of which should be claimed as covered:
        //   1. The detail push in the TOGGLED representation — blocked by the harness quirk noted
        //      above (a preceding swipe defeats the tap), not by any app defect.
        //   2. Obstruction of detail *content*, in either representation. On a fresh install the
        //      document list is legitimately empty and renders a CENTERED ContentUnavailableView,
        //      so the detail column holds no top-anchored content for a mis-computed safe area to
        //      hide. No assertion over an empty list can tell the fix from the bug. Closing this
        //      needs seeded research data (a note/tag fixture) before drilling in.
        //
        // History worth keeping: e403faf removed the original drill-in because its oracle
        // (`app.staticTexts["All Research Documents"]`) was vacuous — the stack root's own row
        // renders that same string, so it matched before the tap. That removal was locally right,
        // but it left the scenario asserting only on the root: the pre-fix SIDEBAR column, while
        // #272's bug lives in the DETAIL column. The repair above adopts e403faf's own suggested
        // oracle (`app.navigationBars[...]`) and adds the ordering its notes implied — drill in
        // BEFORE the swipe — which is what makes the launch-representation push reliable.
    }
}
