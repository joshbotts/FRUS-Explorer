// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import XCTest

/// Rotation stability for the analytics sheets (#498).
///
/// ## What this suite exists to catch
/// Three device crash reports from build 35 (iPhone18,1, iOS 26.5.2) share one main-thread stack:
/// a rotation drives `-[UIWindow _rotateWindowToOrientation:…]` → `_UIHostingView.layoutSubviews()`
/// → a SwiftUI graph transaction; UIKit re-enters synchronously through
/// `-[UIViewController _traitCollectionDidChange:]` and asks the hosting controller for its
/// status-bar child, which forces `GraphHost.preferenceValue` to resolve a preference **from inside
/// the transaction that is still building it**. AttributeGraph detects the cycle, calls
/// `AG::Graph::print_cycle`, and `fprintf`s it to stderr until the 10-second scene-update watchdog
/// kills the process (`FRONTBOARD 0x8BADF00D`).
///
/// The app is killed, so the observable symptom in a UI test is simply that the process is gone —
/// there is no Swift fatal error to catch and no exception to trap. `XCUIApplication.state`
/// therefore *is* the oracle here.
///
/// ## Why the term matters
/// The leading diagnosis holds that the cycle needs the Corpus Analytics body to be *structurally*
/// invalidated by the same trait change UIKit is propagating. Three things in `AnalyticsView` are
/// gated on a committed term: the filter chips (which make `ViewThatFits(in: .horizontal)` actually
/// flip branches between portrait and landscape), the landscape hint (`showsLandscapeHint &&
/// !committedTerm.isEmpty`), and the chart itself. With no committed term both `ViewThatFits`
/// candidates fit at either width and the hint never appears, so the structure is rotation-stable.
///
/// So `testRotateWithEmptyTerm` is the **control** and `testRotateWithCommittedTerm` is the
/// **experiment**. If both pass, the term-gated diagnosis is wrong. If only the second fails, it is
/// corroborated. Committing a term needs no downloaded corpus — the chart renders empty, but every
/// structural condition above is met, which is why this suite can run against `FRUS_UI_TEST_MODE`
/// with no volumes on disk.
///
/// Version history:
///   1.0 — #498: first rotation coverage in the suite (there was none), plus the empty/committed
///          term A/B that discriminates the leading diagnosis
///   1.1 — #498 fix: `FRUS498_RUN_REPRO` no longer gates anything — with the
///          `.statusBarHidden(false)` fix in `BrowserView` none of these cases hangs, so they all
///          run in the everyday suite (~20s each). Person Analytics coverage added: it is the
///          latent sibling that reproduced the same cycle, and its two fields are what showed the
///          fix belongs on the presentation rather than on each field.
///   1.2 — Wave R / R-8: `openCorpusAnalytics` no longer falls back to the raw SF Symbol name
///          when the toolbar overflows. That fallback existed because the overflowed item
///          announced `chart.bar.xaxis`; it now announces "Analysis Tools".
final class AnalyticsRotationTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        // Start every test upright. XCUIDevice orientation is process-wide and survives
        // between tests, so a landscape leftover silently changes the layout under test.
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchArguments = ["-hasCompletedOnboarding", "1"]
        app.launch()
    }

    override func tearDownWithError() throws {
        // Leave the device upright regardless of how the test ended, or the next test inherits
        // landscape and its own layout assertions become meaningless.
        XCUIDevice.shared.orientation = .portrait
        app = nil
    }


    // MARK: - Tests

    /// Control: rotating Corpus Analytics with no committed term must survive.
    func testRotateWithEmptyTerm() throws {
        try openCorpusAnalytics()
        XCTAssertTrue(app.textFields["Term…"].waitForExistence(timeout: 10),
                      "Corpus Analytics should present its empty term-entry state")

        rotateRoundTrip()

        XCTAssertEqual(app.state, .runningForeground,
                       "App was killed rotating Corpus Analytics with an EMPTY term — the crash is "
                       + "not gated on a committed term, so the ViewThatFits/landscape-hint "
                       + "diagnosis is wrong and the toolbar/presentation-sizing path carries it.")
    }

    /// Experiment: rotating Corpus Analytics with a committed term (chips + landscape hint present).
    func testRotateWithCommittedTerm() throws {
        try openCorpusAnalytics()

        let field = app.textFields["Term…"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Term field should exist")
        field.tap()
        // Return commits via the field's own `.onSubmit { addTerm() }`. Tapping the "Search" button
        // is ambiguous — the Search TAB carries the same label — and Return is also what the owner
        // does, which matters because it leaves the keyboard up (see testKeyboardPersistsAcrossTerms).
        field.typeText("Berlin\n")

        XCTAssertTrue(app.staticTexts["Berlin"].waitForExistence(timeout: 10),
                      "The committed term should appear as a chip")

        rotateRoundTrip()

        XCTAssertEqual(app.state, .runningForeground,
                       "App was killed rotating Corpus Analytics with a committed term (#498).")
    }

    /// The owner's actual sequence: several terms entered in a row, keyboard never dismissed, then
    /// rotate. Reported from device — the software keyboard stays up after each term is committed,
    /// so `termField` (a UIKit-backed `TextField` duplicated in BOTH `ViewThatFits(in: .horizontal)`
    /// candidates at AnalyticsView.swift:1299) still holds first responder when the rotation lands.
    /// The branch swap then tears down and rebuilds a first-responder platform view during the same
    /// trait change UIKit is propagating — which is the `PlatformViewChild.updateValue()` frame in
    /// the crash stack.
    func testRotateWithMultipleTermsAndKeyboardUp() throws {
        try openCorpusAnalytics()

        let field = app.textFields["Term…"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Term field should exist")
        field.tap()
        field.typeText("Berlin\n")
        // Confirm the commit WITHOUT depending on the chip row: the placeholder flips to
        // "Add a term…" as soon as `committedTerms` is non-empty. The bisect can elide the chip
        // row, and an oracle that needs it would turn every such run into a false result.
        XCTAssertTrue(app.textFields["Add a term…"].waitForExistence(timeout: 10),
                      "First term should commit (placeholder flips to the add-a-term form)")

        // After the first commit the placeholder becomes "Add a term…".
        //
        // Each term re-taps the field first. On DEVICE the owner reports focus and the software
        // keyboard persist across commits, so no re-tap would be needed; in the simulator focus is
        // dropped after `addTerm()`. That divergence is itself a finding — it means the simulator
        // does not reproduce the owner's precondition unless the software keyboard is forced on
        // (Simulator ▸ I/O ▸ Keyboard ▸ Connect Hardware Keyboard OFF).
        let addField = app.textFields["Add a term…"]
        XCTAssertTrue(addField.waitForExistence(timeout: 5),
                      "Placeholder should switch to the add-a-term form after the first commit")
        for term in ["Moscow", "Paris"] {
            addField.tap()
            addField.typeText("\(term)\n")
            XCTAssertTrue(app.staticTexts[term].waitForExistence(timeout: 10),
                          "\(term) should commit to a chip")
        }

        // Record — do not assert — whether the keyboard is still up. The owner reports it never
        // dismisses on device; if that reproduces here it is both a usability bug in its own right
        // and the precondition that makes the rotation fatal.
        let keyboardUp = app.keyboards.count > 0
        XCTContext.runActivity(named: "Keyboard still presented after 3 terms: \(keyboardUp)") { _ in }

        rotateRoundTrip()

        XCTAssertEqual(app.state, .runningForeground,
                       "App was killed rotating Corpus Analytics with multiple committed terms and "
                       + "the keyboard up (#498). Keyboard was up before rotating: \(keyboardUp).")
    }

    /// The owner's negative control, from device: starting the chart in LANDSCAPE and rotating to
    /// portrait does not crash. Only portrait → landscape does.
    ///
    /// That asymmetry is diagnostic. `showsLandscapeHint` (AnalyticsView.swift:819-821) is
    /// `horizontalSizeClass == .compact && verticalSizeClass == .regular` — true in portrait, false
    /// in landscape. So the fatal direction is the one that **removes** `landscapeHint` from the
    /// NavigationStack's root VStack while UIKit is propagating that very trait change; the safe
    /// direction only **adds** it. A symmetric cause (e.g. `ViewThatFits` swapping branches, which
    /// happens in both directions) cannot by itself explain this, so this test is what keeps the
    /// diagnosis honest: if it ever starts failing too, the landscape-hint story is wrong.
    func testRotateLandscapeToPortraitIsSafe() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        try openCorpusAnalytics()

        let field = app.textFields["Term…"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Term field should exist in landscape")
        field.tap()
        field.typeText("Berlin\n")
        XCTAssertTrue(app.staticTexts["Berlin"].waitForExistence(timeout: 10),
                      "Term should commit to a chip in landscape")

        XCUIDevice.shared.orientation = .portrait
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 12)

        XCTAssertEqual(app.state, .runningForeground,
                       "Landscape → portrait is the owner's reported SAFE direction; a failure here "
                       + "means the defect is not directional and the landscape-hint diagnosis is wrong.")
    }

    /// The same fatal sequence with the #377 "Working on:" project banner actually rendering.
    ///
    /// `WorkingOnBanner` reserves zero height unless the active project has a non-blank research
    /// question (`ProjectPickerMenu.resolvedQuestion`), and onboarding's default "My Research"
    /// project has none — so every other test in this file runs with the banner absent. That is
    /// already informative: #498 reproduces without it, so the banner is not a precondition and
    /// #486 is an independent defect. This test closes the remaining question — whether the banner,
    /// which is a `.safeAreaInset(edge: .top)` applied OUTSIDE BrowserView's NavigationStack
    /// (MainTabView.swift:313, the #486 defect), makes the rotation worse.
    func testRotateWithProjectBannerActive() throws {
        try giveActiveProjectAResearchQuestion()

        // Confirm the banner is actually on screen before drawing any conclusion from this test.
        let browse = app.buttons["Browse"].firstMatch
        if browse.waitForExistence(timeout: 10) { browse.tap() }
        let banner = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Working on:'")).firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 10),
                      "The Working-on banner should be visible before testing rotation with it")

        try openCorpusAnalytics()
        let field = app.textFields["Term…"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Term field should exist")
        field.tap()
        field.typeText("Berlin\n")
        XCTAssertTrue(app.staticTexts["Berlin"].waitForExistence(timeout: 10), "First term should commit")

        let addField = app.textFields["Add a term…"]
        XCTAssertTrue(addField.waitForExistence(timeout: 5), "Add-a-term placeholder should appear")
        for term in ["Moscow", "Paris"] {
            addField.tap()
            addField.typeText("\(term)\n")
            XCTAssertTrue(app.staticTexts[term].waitForExistence(timeout: 10), "\(term) should commit")
        }

        rotateRoundTrip()

        XCTAssertEqual(app.state, .runningForeground,
                       "App was killed rotating Corpus Analytics with the project banner active.")
    }

    /// Settings ▸ Projects ▸ New Project… ▸ name + research question ▸ Save.
    ///
    /// Creates rather than edits: `FRUS_UI_TEST_MODE` bypasses `OnboardingView`, which is the only
    /// thing that mints the default "My Research" project, so a test launch has no projects at all.
    /// The create branch of `ProjectEditorView.saveProject()` also assigns
    /// `appState.activeProjectId`, which is exactly what the banner needs — it renders only for the
    /// ACTIVE project's non-blank question.
    ///
    /// Skips rather than fails if the Settings project path has moved: this is scaffolding for the
    /// banner test, not the thing under test.
    private func giveActiveProjectAResearchQuestion() throws {
        let settings = app.buttons["Settings"].firstMatch
        guard settings.waitForExistence(timeout: 10) else { throw XCTSkip("Settings tab not found") }
        settings.tap()

        let projects = app.buttons["Projects"].firstMatch
        guard projects.waitForExistence(timeout: 10) else { throw XCTSkip("Projects pane not found") }
        projects.tap()

        let newProject = app.buttons["New Project…"].firstMatch
        guard newProject.waitForExistence(timeout: 10) else {
            throw XCTSkip("New Project row not found in the Projects pane")
        }
        newProject.tap()

        let name = app.textFields["Project name"].firstMatch
        guard name.waitForExistence(timeout: 10) else { throw XCTSkip("Project name field not found") }
        name.tap()
        name.typeText("Supply Chain")

        let question = app.textViews["Research question"].firstMatch
        guard question.waitForExistence(timeout: 10) else {
            throw XCTSkip("Research question editor not found")
        }
        question.tap()
        question.typeText("How did the United States secure its supply chain")

        let save = app.buttons["Save"].firstMatch
        guard save.waitForExistence(timeout: 5) else { throw XCTSkip("Save button not found") }
        save.tap()
    }

    /// Three terms committed with a SINGLE tap on the field (one `typeText` containing three
    /// Returns), versus `testRotateWithMultipleTermsAndKeyboardUp` which re-taps between each.
    ///
    /// Discriminates the two things that differ between the passing 1-term case and the hanging
    /// 3-term case: the number of committed terms, and the number of times the text field is
    /// tapped (each tap re-presents the keyboard). If this HANGS, term count is the variable. If it
    /// PASSES, the trigger is repeated focus/keyboard cycling on the platform-backed field.
    func testRotateThreeTermsSingleTap() throws {
        try openCorpusAnalytics()

        let field = app.textFields["Term…"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Term field should exist")
        field.tap()
        field.typeText("Berlin\nMoscow\nParis\n")

        XCTAssertTrue(app.textFields["Add a term…"].waitForExistence(timeout: 10),
                      "Terms should commit (placeholder flips to the add-a-term form)")

        rotateRoundTrip()

        XCTAssertEqual(app.state, .runningForeground,
                       "App was killed rotating with three terms committed via a single tap.")
    }

    /// Two terms — the `isComparing` threshold (`committedTerms.count >= 2`). Locates the boundary
    /// between the passing 1-term case and the hanging 3-term case.
    func testRotateWithTwoTerms() throws {
        try openCorpusAnalytics()

        let field = app.textFields["Term…"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Term field should exist")
        field.tap()
        field.typeText("Berlin\n")
        let addField = app.textFields["Add a term…"]
        XCTAssertTrue(addField.waitForExistence(timeout: 10), "Term field should be present after the first commit")
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 2)
        addField.tap()
        addField.typeText("Moscow\n")
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 3)

        rotateRoundTrip()

        XCTAssertEqual(app.state, .runningForeground,
                       "App was killed rotating with two committed terms.")
    }

    /// MINIMAL TRIGGER: one committed term, then tap the term field a SECOND time (typing nothing),
    /// then rotate. If this hangs, the defect needs neither a second term nor any text — only a
    /// re-focus of the platform-backed field before the rotation.
    func testRotateAfterSecondTapOnField() throws {
        try openCorpusAnalytics()

        let field = app.textFields["Term…"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Term field should exist")
        field.tap()
        field.typeText("Berlin\n")

        let addField = app.textFields["Add a term…"]
        XCTAssertTrue(addField.waitForExistence(timeout: 10), "Term should commit")
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 2)
        addField.tap()   // <- the only additional action

        rotateRoundTrip()

        XCTAssertEqual(app.state, .runningForeground,
                       "App was killed rotating after merely re-tapping the term field.")
    }

    /// CONTROL for `testRotateAfterSecondTapOnField`: one committed term, then a second tap
    /// somewhere that is NOT the term field, then rotate. If this passes while the sibling hangs,
    /// the trigger is specific to re-focusing the text field rather than to any extra interaction.
    func testRotateAfterSecondTapElsewhere() throws {
        try openCorpusAnalytics()

        let field = app.textFields["Term…"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Term field should exist")
        field.tap()
        field.typeText("Berlin\n")
        XCTAssertTrue(app.textFields["Add a term…"].waitForExistence(timeout: 10), "Term should commit")
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 2)

        // Tap dead space well below the filter row — not the field, not a control.
        let win = app.windows.firstMatch
        win.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75)).tap()

        rotateRoundTrip()

        XCTAssertEqual(app.state, .runningForeground,
                       "App was killed rotating after a second tap away from the term field.")
    }

    /// SCOPE PROBE: is the defect specific to the Corpus Analytics sheet, or does ANY focused text
    /// field wedge on rotation?
    ///
    /// This decides whether an orientation lock on one screen is a real mitigation or a band-aid.
    /// The Search tab's keywords field is a plain `TextField` in a `NavigationStack` — but NOT in a
    /// sheet, and its stack is not nested inside another presented controller. If this hangs, the
    /// defect is app-wide and must be fixed globally.
    func testRotateWithFocusedSearchFieldIsSafe() throws {
        let search = app.buttons["Search"].firstMatch
        guard search.waitForExistence(timeout: 10) else { throw XCTSkip("Search tab not found") }
        search.tap()

        // `.searchable` surfaces as a searchField, not a textField.
        var field = app.searchFields.firstMatch
        if !field.waitForExistence(timeout: 5) { field = app.textFields.firstMatch }
        guard field.waitForExistence(timeout: 10) else { throw XCTSkip("Search field not found") }
        field.tap()
        field.typeText("Berlin")
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 2)
        field.tap()   // the second focus — the Corpus Analytics minimal trigger

        rotateRoundTrip()

        XCTAssertEqual(app.state, .runningForeground,
                       "App was killed rotating with a focused Search field — the defect is NOT "
                       + "confined to Corpus Analytics and an orientation lock there would not fix it.")
    }

    // MARK: - Latent siblings (#498)

    /// Person Analytics ▸ Network ▸ "Set focus person…".
    ///
    /// The same sheet → own-`NavigationStack` → platform text field shape as Corpus Analytics,
    /// presented from the same `BrowserView`. Before the fix this rotation tripped the same
    /// AttributeGraph cycle ~30 times per round trip — bounded rather than a wedge, so it passed
    /// this assertion while still being the defect. It is included because it is the case that
    /// showed the fix has to be applied per PRESENTATION, not per field.
    func testRotatePersonAnalyticsNetworkFieldAfterSecondTap() throws {
        try openAnalysisItem("Person Analytics")

        let network = app.buttons["Network"].firstMatch
        XCTAssertTrue(network.waitForExistence(timeout: 10), "Network mode should be offered")
        network.tap()

        let field = app.textFields["Set focus person…"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Focus-person field should exist")
        field.tap()
        field.typeText("Berlin")
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 2)
        field.tap()   // the second focus — the Corpus Analytics minimal trigger

        rotateRoundTrip()

        XCTAssertEqual(app.state, .runningForeground,
                       "App was killed rotating Person Analytics after re-tapping its focus field.")
    }

    /// Person Analytics ▸ Trends ▸ "Add a person to compare…" — the OTHER focusable field on the
    /// same sheet. It is covered by the same single `.statusBarHidden(false)`, which is the
    /// property a per-field fix would not have.
    func testRotatePersonAnalyticsTrendsFieldAfterSecondTap() throws {
        try openAnalysisItem("Person Analytics")

        let field = app.textFields["Add a person to compare…"]
        var scrolls = 0
        while (!field.exists || !field.isHittable) && scrolls < 6 {
            app.swipeUp()
            scrolls += 1
        }
        guard field.waitForExistence(timeout: 5), field.isHittable else {
            throw XCTSkip("Add-a-person field not reachable by scrolling")
        }
        field.tap()
        field.typeText("Berlin")
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 2)
        field.tap()

        rotateRoundTrip()

        XCTAssertEqual(app.state, .runningForeground,
                       "App was killed rotating Person Analytics after re-tapping its compare field.")
    }

    /// CONTROL for the two probes above: same sheet, same mode, rotated with the field never
    /// touched. Measured at zero cycle detections even before the fix, which is what establishes
    /// that the count above is attributable to the focused field and not to opening the sheet.
    func testRotatePersonAnalyticsNetworkNoFocus() throws {
        try openAnalysisItem("Person Analytics")

        let network = app.buttons["Network"].firstMatch
        XCTAssertTrue(network.waitForExistence(timeout: 10), "Network mode should be offered")
        network.tap()
        XCTAssertTrue(app.textFields["Set focus person…"].waitForExistence(timeout: 10),
                      "Focus-person field should exist")

        rotateRoundTrip()

        XCTAssertEqual(app.state, .runningForeground, "App was killed rotating Person Analytics.")
    }

    // MARK: - Helpers

    /// Opens Browse ▸ Analysis Tools ▸ the named item.
    private func openAnalysisItem(_ label: String) throws {
        let browse = app.buttons["Browse"].firstMatch
        if browse.waitForExistence(timeout: 10) { browse.tap() }
        let menu = app.buttons["Analysis Tools"]
        guard menu.waitForExistence(timeout: 10) else { throw XCTSkip("Analysis Tools menu not found") }
        menu.tap()
        let item = app.buttons[label].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5), "\(label) menu item should exist")
        item.tap()
    }

    /// Opens Browse ▸ the analysis menu ▸ Corpus Analytics.
    private func openCorpusAnalytics() throws {
        let browse = app.buttons["Browse"].firstMatch
        if browse.waitForExistence(timeout: 10) { browse.tap() }

        // The grouped analysis menu — an explicit Menu rather than toolbar overflow (BrowserView).
        // Its accessibility LABEL is the short name from `.controlHelp(_:detail:)`; the long
        // "Chronology, Corpus Analytics, …" string is the accessibility HINT, not the label.
        var menu = app.buttons["Analysis Tools"]
        if !menu.waitForExistence(timeout: 10) {
            // iPad: if the Browse toolbar ever collapses its trailing items into an overflow
            // control, "Analysis Tools" is not a top-level button until that is expanded.
            for label in ["More", "Show More", "More Actions"] {
                let more = app.buttons[label].firstMatch
                if more.exists { more.tap(); break }
            }
            // R-8 fixed the raw-SF-Symbol fallback this used to need: the overflowed row now
            // announces "Analysis Tools" like the in-bar button, because the name lives in the
            // item's `Label` rather than only in `.controlHelp`. `ToolbarOverflowAccessibilityTests`
            // is the guard; do not reintroduce a `app.buttons["chart.bar.xaxis"]` fallback here —
            // it would silently re-accept the defect.
            menu = app.buttons["Analysis Tools"]
            if !menu.waitForExistence(timeout: 5) {
                let labels = app.buttons.allElementsBoundByIndex.prefix(30)
                    .map { $0.label }.filter { !$0.isEmpty }.joined(separator: " | ")
                throw XCTSkip("Analysis toolbar menu not found. Buttons on screen: \(labels)")
            }
        }
        menu.tap()

        let item = app.buttons["Corpus Analytics"].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5), "Corpus Analytics menu item should exist")
        item.tap()
    }

    /// Portrait → landscape → portrait, pausing long enough for the 10s watchdog to fire if the
    /// graph cycle is hit. A killed app shows up as `.notRunning` at the assertion.
    private func rotateRoundTrip() {
        XCUIDevice.shared.orientation = .landscapeLeft
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 12)

        XCUIDevice.shared.orientation = .portrait
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 12)
    }
}
