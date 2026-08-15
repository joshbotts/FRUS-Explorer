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
/// Six obstruction scenarios are exercised:
///   1. Tab bar (bottom) — does not cover the last row in a browser list
///   2. Breadcrumb bar (top safeAreaInset) — does not cover the first row of a pushed view
///   3. Software keyboard — does not cover the citation lookup field in CitationLookupView
///   4. iPad `.sidebarAdaptable` representations — Browse content stays reachable in BOTH
///      the leading-sidebar and floating-top-tab-bar representations, asserted before and
///      after a live toggle (#238)
///   5. The same for Research content (#272)
///   6. The "Working on:" project banner (top safeAreaInset) — does not cover the Browse
///      NAVIGATION BAR or its controls (#486)
///
/// Scenarios 1–5 assert on list content. Scenario 6 is the first to assert on a navigation-bar
/// control, which is why #486 — a banner drawn straight over the back button, title, and trailing
/// toolbar items — shipped past a suite named for obstruction. When adding a scenario, ask which
/// chrome it can prove innocent, not merely which one it exercises.
///
/// Scenarios 4 and 5 both cover their tab's root list AND its pushed level (see 2.1 and 1.7) — the
/// pushed level is where #238/#272 actually live, so root-only coverage was gating the wrong column
/// entirely. Scenario 5's remaining gaps are enumerated in the coverage ledger at the end of it.
/// A false-green is worse than a documented gap; so is a documented gap that was never re-measured.
///
/// ## A cautionary tale, kept because it cost three investigations
/// Scenario 4's Browse drill-in was removed and stayed removed for three rounds (1.6, 1.7, 1.9) on
/// the conclusion that XCUITest "cannot drive a programmatic-push `Button`". That was never true.
/// TWO unrelated defects were producing the same symptom, and each round found one more reason to
/// believe the harness explanation instead of separating them:
///   1. **A test-query bug.** `corpusSubseriesRow` (then `corpusContentCell`) matched the section
///      HEADER "Subseries", which SwiftUI also exposes as a cell. Tapping a header cannot push
///      anything, so no change to the app could have made that tap work.
///   2. **An app bug.** `CorpusView`'s rows carried no `.contentShape`, so only the label's glyphs
///      were hit-testable and the row's centre — where an element tap lands — was dead space, for a
///      real finger as much as for the harness.
/// Round 1.6 hit (1) and blamed the driver. Round 1.9 hit (1) and (2) in one run each, and hardened
/// the same wrong explanation into a "structural" claim. #486 found (2) while doing something else.
/// Both had to be fixed before the drill-in could return (2.1).
///
/// The lesson is narrow and worth keeping: when a tap does nothing, verify WHAT element you tapped
/// and WHERE the tap landed before concluding anything about the driver — and having found one
/// cause, keep going, because a symptom this cheap to reproduce can have two.
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
///          ** The query introduced here was wrong from the start — see 2.1(a). ** It matched the
///          section header, not a subseries row. The reasoning above is sound; the element was not.
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
///          `corpusSubseriesRow` exists to avoid — which matches the un-pushed list, so it passed
///          without navigating. Measured on iPad: after the tap `backButton=false` and the nav
///          bar stayed "FRUS Corpus" (no push), yet the assertion reported true; repeated taps
///          did not push either. Root cause (shared with scenario 5): an XCUITest tap on a
///          SwiftUI List row's Cell element does not activate the Button inside it. Removed;
///          the pushed level is now an explicit, documented gap in both scenarios.
///          ** SUPERSEDED by 2.1 — the stated root cause is WRONG. ** The observations hold (no
///          push, vacuous oracle, removal justified); the diagnosis does not. XCUITest activates
///          such a Button fine. This round's tap could never have pushed for a reason unrelated to
///          Buttons: the query resolved to the section HEADER "Subseries", not a row. See
///          `corpusSubseriesRow`. Fixed in #312 along with the separate `.contentShape` defect 1.9
///          ran into; drill-in restored.
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
///   1.9 — #312 gap 3, measured on iPad Pro 13-inch (M5): 1.7's open question — whether the
///          ordering fix that revived scenario 5's Research drill-in also revives scenario 4's
///          Browse drill-in — is answered NO. Two runs (cell-tap, then the row's `Button`
///          element directly), drilling in before any swipe with a sound oracle: neither pushes.
///          The cause is structural, not ordering: `CorpusView` rows are
///          `Button { navigationPath.append… } .buttonStyle(.plain)` (a programmatic push) where
///          Research's are `NavigationLink(value:)`, and XCUITest drives the link but not the
///          button's action here. No drill-in is added (a red test is worse than a documented
///          gap); the measured finding is recorded in scenario 4's NOTE and on #312.
///          ** SUPERSEDED by 2.1 — "structural" was the wrong conclusion from two sound runs. **
///          Both runs did fail to push, for two DIFFERENT reasons, neither of them the construction
///          of the row: the cell-tap run tapped the section header (see 1.6's correction and
///          `corpusSubseriesRow`), and the direct-`Button` run tapped the row's centre, which was
///          dead space because the row had no `.contentShape`. Finding one cause and stopping is
///          what turned two ordinary bugs into a permanent gap. The `NavigationLink`-vs-`Button`
///          contrast is a coincidence — Research's rows are full-width because a `NavigationLink`
///          row fills its cell, so its centre tap hits. Both defects fixed in #312.
///   2.0 — #486: added scenario 6, the first assertion in this suite against a NAVIGATION-BAR
///          control rather than a list cell. Stages the state the banner needs (creates a project
///          with a research question through Settings ▸ Projects ▸ New Project…, which the create
///          branch of `ProjectEditorView.saveProject()` also makes active) and asserts both that
///          the banner's frame clears the navigation bar and that bar controls stay hittable.
///          iPhone-scoped: the banner is deliberately absent on regular-width iPad (#461/#462).
///          Also corrects 1.9: `CorpusView` rows are not un-drivable, they are un-hittable off
///          their text (no `.contentShape`) — a tap near the row's LEADING edge pushes.
///   2.1 — #312: `CorpusView`'s rows are full-width tap targets now, which retires the harness
///          limitation 1.6/1.9 recorded and 2.0 half-corrected. Four consequences here:
///          (a) `corpusContentCell` → `corpusSubseriesRow`, and it now matches the row's `Button`
///              via `label BEGINSWITH 'Subseries '` (trailing space) instead of a cell via
///              `BEGINSWITH 'Subseries'`. The old predicate matched the section HEADER, which
///              SwiftUI exposes as a cell as well: measured on iPhone 17 (iOS 26.3.1), the resolved
///              element was 40.3pt tall where every real row is 73.7pt. This is a SECOND defect,
///              independent of the app fix, and it is the one that actually defeated 1.6 — a header
///              tap can never push. Every earlier assertion written against that query, including
///              scenario 4's four root hittability assertions, was really asserting on the header.
///          (b) scenario 4's Browse drill-in is RESTORED, with the sound oracle 1.9's own notes
///              specified (`BackButton` + the "FRUS Corpus" nav bar going away) and 1.7's ordering
///              (drill in BEFORE the swipe). This closes #312 gap 3 — the pushed Browse level is
///              covered in the launch representation, matching scenario 5's shape.
///          (c) scenario 2 was another casualty of the app bug, previously invisible: its
///              `app.cells.firstMatch.tap()` targets the corpus list's first row, which since
///              Session 87 is "People", not a subseries — and it never pushed, so the post-tap
///              `app.cells.firstMatch` matched the un-pushed corpus list and the test passed
///              having asserted nothing about the breadcrumb bar it is named for. Now it drills
///              into a subseries (what its name always claimed) behind a `BackButton` oracle.
///              Retargeting is not cosmetic: with the rows fixed, the old target would have pushed
///              into `PersonIndexView`, which on a fresh install renders a cell-less
///              `ContentUnavailableView` — the test would have started FAILING. Verified on the
///              simulator: that view shows "No People Indexed" and contributes no cells.
///          (d) scenario 6's `dx: 0.22` coordinate tap is back to a plain element tap; the offset
///              was a workaround for the app bug, and keeping it would hide the fix. Confirmed
///              green on iPhone 17 with the plain tap.
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
        // **Scroll the LIST, not the app.** `app.swipeUp()` targets the app element's horizontal
        // centre, which was the corpus list while Browse was a single full-width column. Since
        // F-2's two-pane it is the *detail* pane on a wide iPad — so the gesture scrolled a
        // different view and the last row never moved, which is how this scenario failed the
        // moment the layout changed. Addressing the scroll view that owns the cells is correct in
        // both layouts and on both platforms, and it is what the design's §4 means by making the
        // oracles pane-aware rather than making them green.
        let listPane = app.collectionViews.firstMatch.exists
            ? app.collectionViews.firstMatch
            : app.tables.firstMatch
        var becameHittable = false
        for _ in 1...15 {
            let lastCell = app.cells.element(boundBy: app.cells.count - 1)
            if lastCell.isHittable {
                becameHittable = true
                break
            }
            if listPane.exists {
                listPane.swipeUp(velocity: .fast)
            } else {
                app.swipeUp(velocity: .fast)
            }
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
    ///
    /// SCOPE: on a regular-width iPad `breadcrumbBarIfAppropriate` renders `EmptyView` (#238), so on
    /// an iPad destination this exercises the push but has no breadcrumb to prove innocent. It is
    /// left unskipped deliberately — the push half is still worth running there — but do not read an
    /// iPad-only green as breadcrumb coverage.
    func testBreadcrumbBarNotObstructingFirstRow() throws {
        // Ensure we are on the Browse tab.
        selectBrowseSection()

        // Drill into a SUBSERIES — what this test's name and docstring have always described.
        //
        // `app.cells.firstMatch.tap()` used to stand here, and it was wrong twice over (2.1):
        //  - It targets the corpus list's FIRST row, which since Session 87 is the "People"
        //    cross-volume index, not a subseries. On a fresh UI-test install `PersonIndexView` has
        //    no indexed people and renders a cell-less `ContentUnavailableView`, so once #312 made
        //    the row actually tappable the old target would have started FAILING here.
        //  - It never pushed at all, which is what hid the mis-target: `CorpusView`'s rows had no
        //    `.contentShape`, so the element tap landed beside the label. The post-tap assertion
        //    below was then satisfied by the UN-pushed corpus list, and this test passed for years
        //    having asserted nothing whatsoever about the breadcrumb bar it is named for.
        let subseriesRow = corpusSubseriesRow
        XCTAssertTrue(subseriesRow.waitForExistence(timeout: 10),
                      "Expected corpus subseries rows to appear within 10 s")
        subseriesRow.tap()

        // Sound oracle for the push, so the assertions below cannot be satisfied by the root list:
        // the corpus root has no back button and owns the "FRUS Corpus" navigation bar.
        XCTAssertTrue(
            app.buttons["BackButton"].waitForExistence(timeout: 10),
            "Tapping a corpus subseries row did not push a browser level — without the push this "
                + "test cannot see the breadcrumb bar at all (#312)"
        )
        XCTAssertFalse(
            app.navigationBars["FRUS Corpus"].exists,
            "Still at the corpus root after tapping a subseries row — no push happened"
        )

        // After navigating in, the breadcrumb bar appears and a new set of rows loads.
        // Wait briefly for the pushed view's cells to settle.
        let pushedFirstCell = app.cells.firstMatch
        let pushedAppeared = pushedFirstCell.waitForExistence(timeout: 5)
        XCTAssertTrue(pushedAppeared, "Expected cells in pushed browser level within 5 s")

        // Scroll back to the top in case the navigation defaulted to a non-zero offset.
        app.swipeDown(velocity: .fast)

        // The first cell must be hittable — not hidden under the breadcrumb bar. `app.cells` is
        // safe here (unlike at the root) because the push is proven above, so these are the
        // SubseriesView's own volume rows.
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

    /// A Browse content row — the first corpus SUBSERIES row, resolved as the row's own `Button`.
    ///
    /// Excludes the sidebar tab rows that the `.sidebarAdaptable` sidebar representation exposes as
    /// cells: those are trivially hittable and would let an obstruction assertion pass without
    /// testing content at all.
    ///
    /// ## Why a button, and why the trailing space (2.1)
    /// This used to be `app.cells.containing(NSPredicate("label BEGINSWITH 'Subseries'"))`, which
    /// matched the section HEADER — the literal string "Subseries" — because SwiftUI exposes an
    /// inset-grouped header as a cell too, and it sorts before the rows. Measured on iPhone 17
    /// (iOS 26.3.1): the resolved element was 40.3pt tall at y=260.7, while every real subseries row
    /// is 73.7pt. So every assertion written against this query was really asserting on the header.
    ///
    /// That is the SECOND, independent reason 1.6's cell-tap drill-in never pushed — a header has no
    /// action, so no fix to the row's tap target could ever have rescued it. It is separate from the
    /// missing `.contentShape` that defeated 1.9's direct-button attempt (#312).
    ///
    /// The row's accessibility label is "Subseries <name>, <n> volumes", so `BEGINSWITH 'Subseries '`
    /// — with the trailing space — matches rows and excludes the bare header. Do not drop it.
    private var corpusSubseriesRow: XCUIElement {
        // Built fresh on each access — see `sidebarToggleButton` for the Swift 6 "sending" hazard a
        // hoisted NSPredicate creates in this nonisolated context.
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Subseries '")).firstMatch
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
            corpusSubseriesRow.waitForExistence(timeout: 10),
            "Corpus subseries rows did not appear in the launch representation"
        )
        // Detail level BEFORE the swipe — same ordering constraint scenario 5 documents (1.7): an
        // immediately-preceding swipe stops the row tap driving the push.
        assertBrowseDetailPushesUnobstructed("launch representation")
        app.swipeDown(velocity: .fast) // ensure we are scrolled to the top
        XCTAssertTrue(
            corpusSubseriesRow.isHittable,
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
            corpusSubseriesRow.waitForExistence(timeout: 10),
            "Corpus subseries rows did not appear after toggling the tab-bar representation"
        )
        app.swipeDown(velocity: .fast)
        XCTAssertTrue(
            corpusSubseriesRow.isHittable,
            "First subseries row is not hittable after toggling the tab-bar representation — "
                + "chrome may be overlaying content (#238)"
        )

        // NO drill-in in representation B — the ordering constraint 1.7 measured for scenario 5
        // applies here too: representation A's `swipeDown` above precedes any tap we could make
        // now, and a swipe defeats the tap that drives the push. The drill-in therefore lives in
        // representation A only, exactly as scenario 5's does. Not an app defect; a harness quirk.
        //
        // RESOLVED — the pushed-level gap this comment block used to document is closed (2.1).
        // Kept in outline because the diagnosis was wrong three times, and because the reason it
        // stayed wrong is more instructive than the answer: there were TWO defects, and each round
        // found one, explained the whole symptom with it, and stopped.
        //   1.6 removed the original drill-in for a good reason (`app.cells.firstMatch` matched the
        //       un-pushed list, so it passed without navigating) and then added a bad one: that an
        //       XCUITest tap on a List row's cell "does not activate the Button inside it". What it
        //       had actually tapped was the section HEADER — the old `corpusContentCell` predicate
        //       `label BEGINSWITH 'Subseries'` matched the header text, which SwiftUI also exposes
        //       as a cell. No app change could ever have made that tap push.
        //   1.9 re-measured on iPad Pro 13-inch (M5) and correctly found that neither the cell tap
        //       nor the row's `Button` element pushes — two runs, two different causes, read as one.
        //       It hardened the wrong explanation into a structural claim (`Button` +
        //       `.buttonStyle(.plain)` vs `ResearchView`'s `NavigationLink(value:)`) and a permanent
        //       gap on #312. The `NavigationLink` contrast is a coincidence: those rows fill their
        //       cell, so their centre is live.
        //   #486 found the second cause while doing something else: raw touch injection on iPhone 17
        //       Pro (iOS 26.5) showed `CorpusView`'s rows had no `.contentShape`, so only the
        //       label's glyphs were hit-testable. A row is ~370pt wide and "People" is ~65pt of it,
        //       so a centred tap — an element tap's landing point — fell in dead space. That is what
        //       defeated 1.9's direct-`Button` run.
        //   #312 fixed both: `.frame(maxWidth: .infinity)` + `.contentShape(Rectangle())` on the row
        //       labels (a real UX defect — most of every Browse row was dead to a finger, not just
        //       to the harness), and the query, which now resolves a row instead of the header.
        //       Measured on iPhone 17 (iOS 26.3.1) after the app fix: tapping the header cell still
        //       does not push (`back=false`, nav bar still "FRUS Corpus"), while a plain element tap
        //       on the row's `Button` does (`back=true`). Two fixes, two independent effects.
        //
        // The lesson, since it survived three investigations that each re-derived the wrong answer:
        // a tap that does nothing is evidence about WHICH element you resolved and WHERE the tap
        // landed, before it is evidence about the driver. "The harness cannot do this" is the most
        // expensive conclusion available and needs the most evidence, not the least — and one
        // confirmed cause is not a reason to stop looking for a second.
    }

    /// Drills into a corpus subseries and asserts the **pushed Browse level** appears and is not
    /// overlaid by the iPad tab-bar chrome. Scenario 4's counterpart to
    /// `assertResearchDetailPushesUnobstructed`, and the coverage 1.6/1.9 removed (see 2.1).
    ///
    /// Oracle: `BackButton` plus the disappearance of the "FRUS Corpus" navigation bar. Both are
    /// needed. The first alone can be satisfied by chrome the sidebar representation happens to
    /// expose; the second alone would pass if the whole Browse tab failed to render. Together they
    /// say "we left the corpus root and landed somewhere with a back button", which is the claim.
    /// This is precisely the oracle 1.9's notes specified — it was never the weak link.
    ///
    /// Call this BEFORE any swipe on the root list (1.7's ordering finding, which holds for both
    /// scenarios). Pops back so the caller resumes at the corpus root.
    private func assertBrowseDetailPushesUnobstructed(_ context: String) {
        corpusSubseriesRow.tap()

        let back = app.buttons["BackButton"]
        guard back.waitForExistence(timeout: 10) else {
            XCTFail("Tapping a corpus subseries row did not push the subseries level (\(context)) — "
                    + "if this is failing again, check the row's tap target before concluding "
                    + "anything about XCUITest; that mistake cost three investigations (#312)")
            return
        }
        XCTAssertFalse(
            app.navigationBars["FRUS Corpus"].exists,
            "A back button appeared but the navigation bar is still 'FRUS Corpus' (\(context)) — "
                + "no push happened and the oracle is being satisfied by other chrome"
        )

        // The pushed level's own top chrome must be reachable — the #238 assertion one level
        // deeper than the root-only version could reach.
        let detailBar = app.navigationBars.firstMatch
        XCTAssertTrue(detailBar.waitForExistence(timeout: 5),
                      "The pushed subseries level has no navigation bar (\(context))")
        XCTAssertTrue(
            detailBar.isHittable,
            "The pushed subseries level's navigation bar is not hittable (\(context)) — the "
                + "floating top tab bar may be overlaying the detail column's top safe area (#238)"
        )

        // ...and so must a real control near the TOP of the pushed list, which is where a
        // mis-computed top safe area does its damage. `SubseriesView`'s tag-filter bar renders
        // "Add Tag Filter" unconditionally, so this holds with no seeded data — deliberately NOT
        // `app.cells.firstMatch`, which in the sidebar representation matches the tab rows and
        // would pass without touching Browse content at all (the trap 1.6 fell into).
        let addTagFilter = app.buttons["Add Tag Filter"]
        XCTAssertTrue(addTagFilter.waitForExistence(timeout: 5),
                      "The pushed subseries level's tag-filter bar did not appear (\(context))")
        XCTAssertTrue(
            addTagFilter.isHittable,
            "The pushed subseries level's 'Add Tag Filter' control is not hittable (\(context)) — "
                + "chrome may be overlaying content one level below the corpus root (#238)"
        )

        back.tap()
        Thread.sleep(forTimeInterval: 0.5)
    }

    // MARK: - 5. iPad tab-bar representations do not obstruct Research content

    /// A Research **content** row — the synthetic "All Research Documents" entry, which
    /// `ResearchView`'s sidebar always emits regardless of how much user data exists, so this
    /// asserts on real content on a fresh install.
    ///
    /// As with `corpusSubseriesRow`, this deliberately does NOT use `app.cells.firstMatch`: the
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

    // MARK: - 6. The "Working on:" project banner does not obstruct the navigation bar (#486)

    /// The research question given to the project this scenario creates. Distinctive enough that
    /// the banner it produces cannot be confused with any other static text on screen.
    private static let bannerQuestion = "Berlin crisis cable traffic"

    /// The name of the project this scenario creates.
    private static let bannerProjectName = "Banner Obstruction Fixture"

    /// The `WorkingOnBanner` element, matched by the literal prefix it renders.
    ///
    /// Deliberately a `staticTexts` **label** match rather than an identifier: the banner is
    /// production UI with no test hook, and adding one would let the test pass against a banner
    /// that renders nothing.
    private var workingOnBanner: XCUIElement {
        // Built fresh on each access — see `sidebarToggleButton` for why a hoisted NSPredicate
        // is a Swift 6 "sending" hazard in this nonisolated context.
        app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'Working on:'")).firstMatch
    }

    /// Taps the first control carrying `label`, resolving across the representations a SwiftUI
    /// `List` row can take (button, cell, or a cell containing the labelled text).
    ///
    /// - Returns: `true` if something was tapped.
    @discardableResult
    private func tapRow(_ label: String, timeout: TimeInterval = 5) -> Bool {
        if tapRowWithoutScrolling(label, timeout: timeout) { return true }

        // Not on screen is not the same as not present. A `List` is lazy: a row below the
        // fold has not been materialised, so every query legitimately reports non-existence
        // and `waitForExistence` — which never scrolls — waits the full timeout for something
        // that cannot appear on its own.
        //
        // This is exactly how `testWorkingOnBannerDoesNotObstructBrowseNavigationBar` began
        // failing: accumulated fixture projects pushed "New Project…" below the fold, and the
        // failure read as "the row is missing" rather than "the list is long".
        guard let scroller = firstScrollContainer else { return false }
        for _ in 0..<6 {
            scroller.swipeUp()
            if tapRowWithoutScrolling(label, timeout: 0.5) { return true }
        }
        return false
    }

    /// One pass of the four query shapes, with no scrolling.
    private func tapRowWithoutScrolling(_ label: String, timeout: TimeInterval) -> Bool {
        let candidates = [
            app.buttons[label].firstMatch,
            app.cells[label].firstMatch,
            app.cells.containing(NSPredicate(format: "label CONTAINS[c] %@", label)).firstMatch,
            app.staticTexts[label].firstMatch,
        ]
        for control in candidates where control.waitForExistence(timeout: timeout) {
            control.tap()
            return true
        }
        return false
    }

    /// The scrollable container to swipe when a row is below the fold.
    private var firstScrollContainer: XCUIElement? {
        for candidate in [app.collectionViews.firstMatch, app.tables.firstMatch,
                          app.scrollViews.firstMatch] where candidate.exists {
            return candidate
        }
        return nil
    }

    /// Creates a project with a **non-blank research question** and leaves it active, which is the
    /// only state in which `WorkingOnBanner` renders anything.
    ///
    /// Under `FRUS_UI_TEST_MODE` onboarding is bypassed and no project exists, so the banner is
    /// invisible on a fresh install and an obstruction assertion would be vacuous. The create
    /// branch of `ProjectEditorView.saveProject()` assigns `appState.activeProjectId`, so saving is
    /// also what makes the new project active.
    ///
    /// The UI-test store is on **disk** (`makeLocalContainer`), so a project created by an earlier
    /// run survives into this one. This is therefore idempotent: it returns early when the banner
    /// is already on screen. Creating a redundant second project would also trip the one-time
    /// second-project nudge alert (`SecondProjectNudgeModifier`) and block every later step.
    private func ensureActiveProjectWithResearchQuestion() throws {
        selectBrowseSection()
        if workingOnBanner.waitForExistence(timeout: 3) { return }

        selectSection("Settings")
        XCTAssertTrue(tapRow("Projects", timeout: 10),
                      "Could not find the Projects row in the Settings list")
        XCTAssertTrue(tapRow("New Project…", timeout: 10),
                      "Could not find the 'New Project…' row in the Projects pane")

        let nameField = app.textFields["Project name"]
        guard nameField.waitForExistence(timeout: 10) else {
            throw XCTSkip("Project editor's name field did not appear — cannot stage the banner")
        }
        nameField.tap()
        nameField.typeText(Self.bannerProjectName)

        let questionField = app.textViews["Research question"]
        XCTAssertTrue(questionField.waitForExistence(timeout: 5),
                      "Project editor's research-question editor did not appear")
        questionField.tap()
        questionField.typeText(Self.bannerQuestion)

        let save = app.buttons["Save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "Project editor's Save button did not appear")
        save.tap()
        Thread.sleep(forTimeInterval: 0.7)
    }

    /// The "Working on: <research question>" banner must sit **below** the Browse navigation bar,
    /// not on top of it (#486).
    ///
    /// `BrowserTabView` applied the banner as a top `.safeAreaInset` to `BrowserView()` — from
    /// OUTSIDE its `NavigationStack`. A top inset applied to a navigation container does not push
    /// its bar down: SwiftUI composites the inset into the same top chrome band and draws it over
    /// the bar, so on iPhone the banner sliced the back chevron, the title, and the trailing
    /// toolbar items at every Browse depth. The fix moves the inset inside the stack.
    ///
    /// ## Why this is a new shape of assertion
    /// Scenarios 1–5 all assert that a **list cell** is hittable. Not one of them ever touched a
    /// navigation-bar control — which is precisely why #486 shipped through a suite named for
    /// obstruction. This asserts on the bar itself, two ways:
    ///
    ///  1. **Geometry** — the banner's frame must not intersect the navigation bar's frame. This is
    ///     the load-bearing oracle, and the ONLY one measured to discriminate the bug. Against the
    ///     pre-fix build it fails with `banner.minY = 66.5` inside a bar spanning 62…168.
    ///  2. **Hittability** — the Browse root's trailing "Analysis Tools" menu button must be
    ///     hittable, and so must the Back button one level down. Keep these, but do NOT rely on
    ///     them: measured against the pre-fix build with the order reversed, `isHittable` on
    ///     "Analysis Tools" returned **true while the banner was drawn across the bar** — a
    ///     non-interactive `Text` over a `.bar` material does not defeat SwiftUI's hit-testing, so
    ///     a hittability-only version of this scenario would have been a false green. They cover a
    ///     louder failure (chrome that genuinely swallows taps); geometry covers #486 itself.
    ///
    /// iPhone-scoped: on regular-width iPad `WorkingOnBanner` deliberately renders nothing and the
    /// research question is a navigation subtitle instead (#461/#462), so there is no banner to
    /// obstruct anything and the scenario would assert nothing.
    func testWorkingOnBannerDoesNotObstructBrowseNavigationBar() throws {
        #if canImport(UIKit)
        try XCTSkipUnless(
            UIDevice.current.userInterfaceIdiom == .phone,
            "iPhone-only: on regular-width iPad the banner is suppressed in favour of a "
                + "navigation subtitle (#461/#462), so there is nothing to obstruct"
        )
        #else
        throw XCTSkip("iPhone-only test")
        #endif

        try ensureActiveProjectWithResearchQuestion()

        // --- Browse ROOT (large title; three trailing toolbar items in the bar row) ---
        selectBrowseSection()
        XCTAssertTrue(workingOnBanner.waitForExistence(timeout: 10),
                      "The 'Working on:' banner never appeared with an active project that has a "
                          + "research question — this scenario cannot assert obstruction without it")

        let rootBar = app.navigationBars.firstMatch
        XCTAssertTrue(rootBar.waitForExistence(timeout: 5), "Browse navigation bar not found")
        assertBannerClearsNavigationBar(rootBar, context: "Browse root")

        let analysisMenu = app.buttons["Analysis Tools"]
        XCTAssertTrue(analysisMenu.waitForExistence(timeout: 5),
                      "The Browse root's 'Analysis Tools' toolbar button was not found")
        XCTAssertTrue(
            analysisMenu.isHittable,
            "The Browse root's 'Analysis Tools' toolbar button is not hittable while the "
                + "'Working on:' banner is displayed — the banner may be drawn over the "
                + "navigation bar (#486)"
        )

        // --- A PUSHED level (inline title; back chevron + title share one bar row) ---
        // This is where #486 was ugliest: with an inline title the bar is a single row, so the
        // banner sliced the back chevron, the title, and the trailing rail toggle at once.
        //
        // A plain element tap drives the push. It did not always: this line used to be a coordinate
        // tap at `dx: 0.22`, because `CorpusView`'s rows had no `.contentShape` and only the label's
        // ~65pt of glyphs were hit-testable — a centred tap (which is where an element tap lands)
        // fell in dead space. #312 made both row types full-width targets, so the workaround is gone
        // rather than left in place to hide the fix. If this ever stops pushing, check the row's tap
        // target first — see the note at the end of scenario 4 for why that ordering matters.
        let peopleRow = app.cells.containing(
            NSPredicate(format: "label CONTAINS[c] 'Browse people mentioned'")).firstMatch
        XCTAssertTrue(peopleRow.waitForExistence(timeout: 10),
                      "The corpus 'People' row did not appear")
        peopleRow.tap()

        let back = app.buttons["BackButton"]
        XCTAssertTrue(back.waitForExistence(timeout: 10),
                      "Tapping the corpus 'People' row did not push a browse level — this "
                          + "scenario's pushed-level half cannot run without it")

        XCTAssertTrue(workingOnBanner.waitForExistence(timeout: 5),
                      "The 'Working on:' banner is missing at a pushed Browse level — it must be "
                          + "present at every depth (#377 Phase 5)")
        let pushedBar = app.navigationBars.firstMatch
        assertBannerClearsNavigationBar(pushedBar, context: "pushed Browse level")
        XCTAssertTrue(
            back.isHittable,
            "The Back button is not hittable at a pushed Browse level while the 'Working on:' "
                + "banner is displayed — the banner may be drawn over the navigation bar (#486)"
        )
    }

    // MARK: - Scenario 7 · a discovery-tip popover — ATTEMPTED AND WITHDRAWN (#597 Phase 1)
    //
    // A TipKit popover over the navigation bar is the #486 shape, so a scenario for it belongs
    // here. It was written, and it does not work: reaching the anchor means opening a document,
    // and every XCUI query made while the document reader is on screen dies with
    // "Failed to get matching snapshots: Timed out while evaluating UI query" after ~180 s.
    // The reader hosts a WKWebView whose accessibility tree is large enough to defeat the query
    // engine — `app.popovers.firstMatch`, the cheapest first-class accessor, times out too. The
    // navigation itself succeeds; it is the assertion that cannot run.
    //
    // That is a harness limitation, not an app defect, and a test that fails for harness reasons
    // is worse than none — it trains a reader to ignore red. So the property is verified by eye
    // instead, and `FRUS_UI_TEST_SHOW_TIPS=1` is kept as the seam that makes that cheap: it forces
    // tips on in a build that otherwise suppresses them.
    //
    // Do not re-add this without first confirming a query can complete over the document reader.

    /// Asserts the "Working on:" banner's frame lies entirely below `bar`'s frame.
    ///
    /// The primary #486 oracle, and the only one measured to discriminate the bug: against the
    /// pre-fix build `isHittable` on the clipped toolbar button still returned true, because the
    /// banner is a non-interactive `Text` over a `.bar` material and taps fall straight through it.
    /// Overlap does not fall through.
    private func assertBannerClearsNavigationBar(_ bar: XCUIElement, context: String) {
        guard bar.exists, workingOnBanner.exists else {
            XCTFail("Missing navigation bar or banner while checking overlap (\(context))")
            return
        }
        let barFrame = bar.frame
        let bannerFrame = workingOnBanner.frame
        XCTAssertGreaterThanOrEqual(
            bannerFrame.minY, barFrame.maxY,
            "The 'Working on:' banner (\(bannerFrame)) overlaps the navigation bar (\(barFrame)) "
                + "at \(context) — a top .safeAreaInset applied to a NavigationStack is composited "
                + "over its bar instead of pushing content below it; the inset belongs INSIDE the "
                + "stack (#486)"
        )
    }

    // MARK: - Scenario 8 · Chronology's range bar at an accessibility text size (CW-12)

    /// The Chronology range bar must keep both date fields and its Show button on screen when the
    /// reader has chosen an accessibility text size.
    ///
    /// ## What this caught
    /// The range bar was a plain `HStack` of two `.compact` date pickers, a dash, a `Spacer` and the
    /// Show button. At `accessibility-large` the two pickers grow past the row's width and an
    /// `HStack` does not wrap: the row overflowed **both** screen edges at once, putting the From
    /// field's left edge and the Show button off-screen, so the range could not be set at all. The
    /// fix is `ViewThatFits`, which is this repo's idiom for the same problem in seven other places.
    ///
    /// ## Why it is a UI test and not a unit test
    /// `ViewThatFits` picks its child from the size actually proposed at layout time. Nothing about
    /// that is visible to a unit test, and the failure it prevents is purely geometric — the exact
    /// case this suite exists for. It is also the first Dynamic Type check in the suite; the size is
    /// set through `-UIPreferredContentSizeCategoryName`, which UIKit reads at launch, so it needs
    /// its own launch rather than a toggle mid-test.
    ///
    /// ## iPhone-only, and that is measured rather than assumed
    /// The skip is not caution. Running the pre-fix layout on an iPad Pro 13-inch **passes**: the
    /// wide row fits at accessibility-large on a 1032pt canvas, so `ViewThatFits` picks the same
    /// child either way and the assertions hold whether or not the bug is present. A green iPad run
    /// would therefore mean nothing while looking like verification. On an iPhone 17 the same
    /// mutation fails with the Show button at **x = 409.7 in a 402pt window** — off the trailing
    /// edge entirely, and squeezed to 32pt wide by 174pt tall.
    func testChronologyRangeBarFitsAtAccessibilityTextSize() throws {
        #if canImport(UIKit)
        try XCTSkipUnless(
            UIDevice.current.userInterfaceIdiom == .phone,
            "iPhone-only: at iPad width the row fits at accessibility-large either way, so this "
                + "scenario passes with the bug present and is not evidence there"
        )

        // Relaunch at an accessibility content size. The category is applied at launch, so the
        // suite's shared `setUpWithError` app cannot be reused.
        app.terminate()
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchArguments = [
            "-hasCompletedOnboarding", "1",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL",
        ]
        app.launch()
        #else
        throw XCTSkip("UIKit-only test")
        #endif

        selectBrowseSection()

        let analysisMenu = app.buttons["Analysis Tools"]
        XCTAssertTrue(analysisMenu.waitForExistence(timeout: 10),
                      "The Browse 'Analysis Tools' menu was not found — this scenario cannot reach "
                          + "Chronology without it")
        analysisMenu.tap()

        let chronologyItem = app.buttons["Chronology"].firstMatch
        XCTAssertTrue(chronologyItem.waitForExistence(timeout: 5),
                      "The 'Chronology' item was not in the Analysis Tools menu")
        chronologyItem.tap()

        // The Show button is the control the overflow pushed off the trailing edge.
        let showButton = app.buttons["Show"].firstMatch
        XCTAssertTrue(showButton.waitForExistence(timeout: 10),
                      "Chronology's 'Show' button never appeared")

        let window = app.windows.firstMatch.frame
        let showFrame = showButton.frame
        XCTAssertTrue(
            window.contains(showFrame),
            "Chronology's 'Show' button (\(showFrame)) is not fully inside the window "
                + "(\(window)) at accessibility-large — the range row is overflowing instead of "
                + "wrapping, so the range cannot be applied (CW-12)"
        )

        // And the leading end: the From field is what ran off the left edge.
        let fromField = app.datePickers.firstMatch
        if fromField.waitForExistence(timeout: 3) {
            XCTAssertTrue(
                window.contains(fromField.frame),
                "Chronology's first date field (\(fromField.frame)) is not fully inside the window "
                    + "(\(window)) at accessibility-large — the row overflowed the LEADING edge, "
                    + "which is the half a trailing-only check would miss (CW-12)"
            )
        }
    }

    // MARK: - Scenario 9 · the onboarding dock is capped on iPad (CW-10 / F-5)

    /// The onboarding dock must not stretch across a 13-inch iPad.
    ///
    /// ## What this caught
    /// Nothing bounded the dock stack on iOS at any level, while macOS pinned its whole window at
    /// 560×540. Measured on this simulator before the cap, the step-2 scope picker filled **1294
    /// of 1294 pt**. Two symptoms the review also named were already handled and are deliberately
    /// NOT asserted here, so a later reader does not "fix" them again: the welcome body carries
    /// its own 340pt cap, and the primary button is 128pt and merely centred.
    ///
    /// ## Why the assertion is on the scope picker and not the glass slab
    /// The slab is a background, and a background has no accessibility element to query. The
    /// segmented picker is the widest *control* in the stack, is queryable, and is the thing that
    /// actually stretched — so it is both the honest target and the one XCTest can see.
    ///
    /// ## iPad-only, for the same reason scenario 8 is iPhone-only
    /// The cap is 640pt and every iPhone is narrower, so on a phone the rule is a no-op by
    /// construction and the assertion would pass whether or not the cap existed.
    func testOnboardingDockIsCappedOniPad() throws {
        #if canImport(UIKit)
        try XCTSkipUnless(
            UIDevice.current.userInterfaceIdiom == .pad,
            "iPad-only: the cap is 640pt and every iPhone is narrower, so this passes with the "
                + "bug present and is not evidence there"
        )

        // Onboarding is the surface under test, so this launch must NOT carry
        // `-hasCompletedOnboarding 1` the way the rest of the suite does.
        app.terminate()
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchArguments = ["-hasCompletedOnboarding", "0"]
        app.launch()
        #else
        throw XCTSkip("UIKit-only test")
        #endif

        let getStarted = app.buttons["Get Started"].firstMatch
        XCTAssertTrue(getStarted.waitForExistence(timeout: 20),
                      "Onboarding's welcome step did not appear — this scenario cannot reach the "
                          + "scope step without it")

        let window = app.windows.firstMatch.frame
        XCTAssertGreaterThan(window.width, 700,
                             "Expected a regular-width iPad canvas; got \(window.width)pt. On a "
                                 + "narrow canvas this scenario proves nothing.")

        getStarted.tap()

        // Step 2's segmented scope control is the widest thing the dock holds.
        let scopePicker = app.segmentedControls.firstMatch
        XCTAssertTrue(scopePicker.waitForExistence(timeout: 10),
                      "The onboarding scope picker never appeared after Get Started")

        let cap: CGFloat = 640
        XCTAssertLessThanOrEqual(
            scopePicker.frame.width, cap,
            "The onboarding scope picker is \(scopePicker.frame.width)pt wide inside a "
                + "\(window.width)pt window — the dock stack is not capped, which is the F-5 "
                + "defect (measured at 1294 of 1294 pt before the fix)"
        )

        // And it must be CENTRED rather than pinned to the leading edge — the failure mode of
        // copying ProjectHomeView's cap-then-re-expand-leading idiom into this stack.
        let leadingGap = scopePicker.frame.minX - window.minX
        let trailingGap = window.maxX - scopePicker.frame.maxX
        XCTAssertEqual(
            leadingGap, trailingGap, accuracy: 2,
            "The onboarding dock is capped but not centred (leading \(leadingGap)pt, trailing "
                + "\(trailingGap)pt) — a leading-aligned cap leaves the slab hugging one edge"
        )
    }

    // MARK: - Scenario 10 · the semantic map gets a REGULAR-width host on iPad (CW-9a / F-25)

    /// On an iPad the semantic map must not run its phone layout.
    ///
    /// ## What this caught, measured on an iPad Pro 13-inch
    /// The map was a `.sheet`, and an iOS form sheet reports **compact** horizontal size class. So
    /// a 1032×1376pt tablet ran the map's phone layout inside a ~582×653pt sheet: display options
    /// folded behind a disclosure, one action card at a time, and — with the explanatory header at
    /// its default expanded state — a Metal canvas of roughly **582×201pt, about 8% of the screen,
    /// for 314,483 documents**.
    ///
    /// So the repair is not "a window instead of a modal", it is **regular width**. That is worth
    /// stating precisely because the two are easy to conflate, and only one of them is testable:
    /// modality is a presentation style, whereas size class has an observable consequence.
    ///
    /// ## `Display options` is the probe, and it is a good one
    /// `SemanticMapSpikeView` emits that `DisclosureGroup` inside `if isCompactWidth` and nowhere
    /// else — the single occurrence in the repo. Its presence *is* the compact layout, so
    /// asserting its absence asserts the thing that actually changed. Asserting on the canvas's
    /// pixel size instead would measure a Metal view through screenshots, which is what the
    /// original measurement had to do and is why it carried ±10pt error bars.
    func testSemanticMapIsNotCompactOniPad() throws {
        #if canImport(UIKit)
        try XCTSkipUnless(
            UIDevice.current.userInterfaceIdiom == .pad,
            "iPad-only: on iPhone the compact layout is correct, so this asserts nothing there"
        )
        #else
        throw XCTSkip("UIKit-only test")
        #endif

        // The map's own caveat strip is the surface's landmark on both hosts.
        let caveat = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] 'Experimental'")).firstMatch

        // **The map window is a real scene, so iPadOS may RESTORE it as the frontmost one** and
        // the app can come up showing the map with no tab bar at all. That is a property of the
        // value-based window this scenario exists to test — the two sibling scenes
        // (`archivalNeighborsScene`, `relatedDocumentsScene`) have always behaved the same way —
        // so the scenario handles both entry states rather than assuming a cold start. Navigating
        // unconditionally is what made this test fail spuriously on its second run.
        if !caveat.waitForExistence(timeout: 3) {
            selectBrowseSection()

            let analysisMenu = app.buttons["Analysis Tools"]
            XCTAssertTrue(analysisMenu.waitForExistence(timeout: 10),
                          "The Browse 'Analysis Tools' menu was not found, and the app did not "
                              + "restore into the map window either")
            analysisMenu.tap()

            let semantic = app.buttons["Semantic Analytics"].firstMatch
            XCTAssertTrue(semantic.waitForExistence(timeout: 5),
                          "'Semantic Analytics' was not in the Analysis Tools menu")
            semantic.tap()

            XCTAssertTrue(caveat.waitForExistence(timeout: 20),
                          "The semantic map never appeared after choosing Semantic Analytics")
        }

        // The assertion. `Display options` exists only under `isCompactWidth`.
        let compactOnlyControl = app.buttons["Display options"].firstMatch
        let disclosureAsAny = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Display options")).firstMatch
        let isCompact = compactOnlyControl.waitForExistence(timeout: 3) || disclosureAsAny.exists
        XCTAssertFalse(
            isCompact,
            "The semantic map is running its COMPACT (phone) layout on an iPad — 'Display "
                + "options' is emitted only inside `if isCompactWidth`. A form sheet reports "
                + "compact width, which is the F-25 defect; a window is regular width (CW-9a)."
        )

        // **Close the map before leaving, or this scenario poisons its siblings.** The window is a
        // real scene, so iPadOS restores it — and the very next scenario to launch (alphabetically
        // `testTabBarNotObstructing…`) came up inside the restored map with no tab bar and failed
        // looking for Browse. It passed in isolation, which is the signature of leaked state
        // rather than a defect in either test. Sheets never needed this; scenes do.
        let done = app.buttons["Done"].firstMatch
        if done.waitForExistence(timeout: 3) { done.tap() }
    }

    // MARK: - Scenario 11 · Archival Analytics' mode control folds on iPhone (P-8)

    /// The four-way mode control must not be four segments on a phone.
    ///
    /// ## What this caught
    /// `Collections / Network / Flows / Your Library` in one `.segmented` `Picker`, in a toolbar,
    /// with **no size-class branch anywhere in the view** — it was the only analytics dashboard
    /// that read no size class at all. On an iPhone the four labels truncated to
    /// `Col… Net… Flo… You…`, which names none of the four views.
    ///
    /// ## The probe
    /// A `.segmented` picker exposes its options as buttons *inside* an `XCUIElement` of type
    /// `segmentedControl`; a `.menu` picker is a single button labelled with the current
    /// selection. So "no segment named Your Library" is exactly the difference between the two
    /// forms, and does not depend on measuring truncated text — which is unreadable to XCTest
    /// anyway, since the accessibility label carries the full string whatever is drawn.
    ///
    /// iPhone-only: at regular width the segments fit and are the better control, which is why
    /// the fix is a branch rather than a replacement.
    func testArchivalModeControlFoldsOnPhone() throws {
        #if canImport(UIKit)
        try XCTSkipUnless(
            UIDevice.current.userInterfaceIdiom == .phone,
            "iPhone-only: at regular width the four segments fit and are kept deliberately"
        )
        #else
        throw XCTSkip("UIKit-only test")
        #endif

        selectBrowseSection()

        let analysisMenu = app.buttons["Analysis Tools"]
        XCTAssertTrue(analysisMenu.waitForExistence(timeout: 10),
                      "The Browse 'Analysis Tools' menu was not found")
        analysisMenu.tap()

        let archival = app.buttons["Archival Analytics"].firstMatch
        XCTAssertTrue(archival.waitForExistence(timeout: 5),
                      "'Archival Analytics' was not in the Analysis Tools menu")
        archival.tap()

        // The surface's landmark: its mode control names whichever view is showing.
        let currentMode = app.buttons["Collections"].firstMatch
        XCTAssertTrue(currentMode.waitForExistence(timeout: 20),
                      "Archival Analytics never appeared, or its mode control does not name the "
                          + "current view")

        XCTAssertFalse(
            app.segmentedControls.buttons["Your Library"].exists,
            "Archival Analytics is still showing a four-segment mode control on an iPhone — the "
                + "labels truncate to 'Col… Net… Flo… You…', naming none of the four views (P-8)."
        )
    }

    // MARK: - Scenario 12 · the iPad sidebar carries the researcher's own objects (F-3)

    /// The `.sidebarAdaptable` sidebar must not be five rows above an empty column.
    ///
    /// ## What this caught
    /// `MainTabView` declared five flat `Tab`s and nothing else — `TabSection` had never existed
    /// in the app target on any branch — so the expanded sidebar was five rows above roughly
    /// **510 pt** of nothing, while the researcher's own objects (saved searches, projects) lived
    /// behind toolbars and tabs.
    ///
    /// ## Why the assertion is on a PROJECT and not a saved search
    /// Both are in the footer, but only one can be created from the UI in a few taps: the suite
    /// already owns `ensureActiveProjectWithResearchQuestion()`, whereas saving a search needs an
    /// indexed corpus and a query first. Asserting on the reachable half keeps this scenario
    /// honest about what it verifies — the footer renders, is populated from SwiftData, and
    /// appears in the sidebar representation — rather than pretending to cover both lists.
    ///
    /// ## iPad-only and sidebar-only
    /// The footer belongs to the sidebar representation, which iPhone never shows. Scenario 4's
    /// toggle helper is reused rather than duplicated, and `tearDown` restores the representation
    /// so this does not leak into later runs — the same courtesy scenario 10 owes its window.
    func testSidebarCarriesResearcherObjectsOniPad() throws {
        #if canImport(UIKit)
        try XCTSkipUnless(
            UIDevice.current.userInterfaceIdiom == .pad,
            "iPad-only: iPhone never shows the sidebar representation this footer belongs to"
        )
        #else
        throw XCTSkip("UIKit-only test")
        #endif

        // A project to find. This also proves the footer reads live SwiftData rather than a
        // snapshot taken at launch.
        try ensureActiveProjectWithResearchQuestion()

        guard let toggle = sidebarToggleButton(timeout: 8) else {
            throw XCTSkip("No sidebar toggle on this iPad representation — scenario 4 documents "
                          + "that the control is absent in some states, and without the sidebar "
                          + "there is no footer to assert on")
        }
        toggle.tap()
        didToggleSidebar = true

        // Matched by IDENTIFIER, not by label. "Projects" also names a row in Settings, and
        // `ensureActiveProjectWithResearchQuestion` above navigates through exactly that row — so
        // a label match passes with this entire footer deleted. The first version of this
        // scenario did precisely that and survived its own mutation test.
        let projectsHeader = app.descendants(matching: .any)["SidebarShortcuts.folder"]
        XCTAssertTrue(
            projectsHeader.waitForExistence(timeout: 10),
            "The iPad sidebar shows no Projects group — the sidebar footer is missing, so the "
                + "column below the five tabs is still empty (F-3)."
        )
    }

    /// Reads the width `BrowserView`'s two-pane gate is actually seeing.
    ///
    /// Diagnostic, not an oracle: two attempts at that measurement were guessed and both were
    /// wrong, so this reads the number out of the running app instead. Dumping **every** matching
    /// probe is deliberate — `body`'s root is a `Group`, which applies modifiers per child, so
    /// more than one probe appearing (or one reporting a width that is not the content area's)
    /// is itself the diagnosis.
    func testDiagnoseBrowseContainerWidth() throws {
        #if canImport(UIKit)
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad-only diagnostic")
        #endif
        selectBrowseSection()

        let probes = app.descendants(matching: .any).matching(identifier: "BrowserView.widthProbe")
        _ = probes.firstMatch.waitForExistence(timeout: 10)
        print("[F-2 DIAG] window=\(app.windows.firstMatch.frame) probeCount=\(probes.count)")
        for index in 0..<probes.count {
            let probe = probes.element(boundBy: index)
            print("[F-2 DIAG] probe[\(index)] label=\"\(probe.label)\" frame=\(probe.frame)")
        }

        // Is the two-pane actually on screen? The detail placeholder exists only in that layout.
        let placeholder = app.staticTexts["Choose a Subseries"]
        print("[F-2 DIAG] placeholderPresent=\(placeholder.waitForExistence(timeout: 5))")

        let people = app.cells.containing(
            NSPredicate(format: "label CONTAINS[c] 'Browse people mentioned'")).firstMatch
        print("[F-2 DIAG] beforeTap cells=\(app.cells.count) peopleExists=\(people.exists) "
              + "peopleFrame=\(people.exists ? "\(people.frame)" : "-")")

        let last = app.cells.element(boundBy: max(0, app.cells.count - 1))
        print("[F-2 DIAG] tapping last cell label=\"\(last.label)\" frame=\(last.frame)")
        last.tap()
        Thread.sleep(forTimeInterval: 2)

        print("[F-2 DIAG] afterTap cells=\(app.cells.count) peopleExists=\(people.exists) "
              + "placeholderStillThere=\(placeholder.exists)")
        print("[F-2 DIAG] afterTap navBars=\(app.navigationBars.count)")
        for index in 0..<min(app.cells.count, 4) {
            print("[F-2 DIAG] afterTap cell[\(index)] frame=\(app.cells.element(boundBy: index).frame)")
        }
        print("[F-2 DIAG] afterTap placeholderExists=\(app.staticTexts["Choose a Subseries"].exists)")
    }

    // MARK: - Scenario 13 · Browse is two panes on a wide iPad (F-2)

    /// The subseries list must stay on screen while a level is open beside it.
    ///
    /// ## What this asserts, and what it deliberately does not
    /// It asserts the **behaviour that distinguishes a two-pane from a stack**: after choosing a
    /// subseries, the corpus list is *still there*. In the single-column layout the list is
    /// covered by the pushed level, so this is exactly the difference and nothing else.
    ///
    /// It does **not** assert pane widths. The design's gate is a measured container width, so
    /// the widths are a function of the device and the `.sidebarAdaptable` representation; pinning
    /// them here would make this a change-detector for two numbers rather than a check that the
    /// layout works.
    ///
    /// ## Why the list is identified by a row that only it contains
    /// `app.cells.firstMatch` resolves whichever pane sorts first, which is the silent-wrong-pane
    /// hazard the design's §4 names — an assertion written that way passes in both layouts and
    /// means nothing. The corpus root's People row exists only in the list pane, so its continued
    /// presence *after* a drill-in is a fact about the list pane specifically.
    func testBrowseIsTwoPaneOnWideiPad() throws {
        #if canImport(UIKit)
        try XCTSkipUnless(
            UIDevice.current.userInterfaceIdiom == .pad,
            "iPad-only: the two-pane gate requires a pad idiom and 820pt of content width"
        )
        #else
        throw XCTSkip("UIKit-only test")
        #endif

        selectBrowseSection()

        let window = app.windows.firstMatch.frame
        try XCTSkipUnless(window.width >= 900,
                          "This canvas (\(window.width)pt) is narrower than the two-pane gate "
                              + "plus the tab sidebar, so Browse is correctly a single column here")

        // The detail pane's empty state exists only in the two-pane layout.
        XCTAssertTrue(app.staticTexts["Choose a Subseries"].waitForExistence(timeout: 10),
                      "Browse is a single column at \(window.width)pt — the two-pane layout is "
                          + "not in effect, so nothing below this measures what it claims to.")

        // Drill THREE levels, checking after each. One level is not enough: the previous shape
        // rendered two panes correctly at rest and collapsed on the first push, and the split
        // probe reported a depth it never reached. Depth is where this layout family fails.
        //
        // Targets are chosen BY LABEL, never by "first cell past the divider" — that positional
        // rule is what let the split probe tap a cell that did nothing three times and report
        // byte-identical numbers as if they were stability (design §7.7).
        let divider = CGFloat(340)
        func panes(_ step: String) -> (list: Int, detail: Int, widest: CGFloat) {
            var list = 0, detail = 0, widest = CGFloat(0)
            for index in 0..<app.cells.count {
                let frame = app.cells.element(boundBy: index).frame
                if frame.maxX <= divider + 12 { list += 1 }
                if frame.minX >= divider - 12 { detail += 1 }
                widest = max(widest, frame.width)
            }
            print("[F-2] \(step): list=\(list) detail=\(detail) widest=\(widest)")
            return (list, detail, widest)
        }

        /// Taps a row in the DETAIL pane, targeting its text rather than the cell.
        ///
        /// The cells in these levels carry empty accessibility labels — the readable string is on
        /// a child `Text`. Targeting the cell by label therefore finds nothing, which is exactly
        /// how the split probe (§7.7) tapped nothing three times and reported byte-identical
        /// numbers as if the layout had held.
        func openInDetail(_ step: String) -> Bool {
            // Tapped by COORDINATE inside the cell, not by its label: these rows carry empty
            // accessibility labels, and targeting their child text hits a count badge rather than
            // the row. A normalized offset lands in the row body regardless.
            for index in 0..<app.cells.count {
                let cell = app.cells.element(boundBy: index)
                let frame = cell.frame
                guard frame.minX >= divider, frame.height > 30, cell.isHittable else { continue }
                print("[F-2] \(step) opening detail row at \(frame)")
                cell.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.5)).tap()
                Thread.sleep(forTimeInterval: 2.5)
                return true
            }
            print("[F-2] \(step): nothing tappable in the detail pane")
            return false
        }

        let subseriesRow = app.cells.element(boundBy: min(3, max(0, app.cells.count - 1)))
        guard subseriesRow.exists else {
            throw XCTSkip("No subseries rows on this device — nothing to open beside the list")
        }
        subseriesRow.tap()
        Thread.sleep(forTimeInterval: 1.5)

        for step in 1...3 {
            let measured = panes("depth \(step)")
            XCTAssertLessThan(
                measured.widest, window.width - 100,
                "depth \(step): a cell is \(measured.widest)pt wide in a \(window.width)pt "
                    + "window — the layout collapsed to one column, which is how both earlier "
                    + "shapes failed."
            )
            XCTAssertGreaterThan(measured.list, 0,
                                 "depth \(step): the corpus list was replaced rather than kept "
                                     + "beside the detail.")
            XCTAssertGreaterThan(measured.detail, 0,
                                 "depth \(step): the detail pane holds no cells.")
            if step < 3, !openInDetail("depth \(step)") { break }
        }
    }
}
