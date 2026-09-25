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
@MainActor
final class AnalyticsRotationTests: XCTestCase {
    /// Resolves tab destinations across every representation, including the floating iPad bar when
    /// it has paged a tab off screen.
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }


    var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        // Start every test upright. XCUIDevice orientation is process-wide and survives
        // between tests, so a landscape leftover silently changes the layout under test.
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchArguments = UITestLaunch.arguments()
        app.launch()
    }

    override func tearDown() async throws {
        // Leave the device upright regardless of how the test ended, or the next test inherits
        // landscape and its own layout assertions become meaningless.
        XCUIDevice.shared.orientation = .portrait
        // And leave nothing OPEN, for the same reason one level up (#1279). Every test in this
        // suite ends on an analytics surface, which on iPad is a window scene iPadOS restores at
        // the next launch — the state in which a tab guard finds no tab bar in the tree at all.
        // This suite is the heaviest producer of it and had neither this nor the `terminate()`
        // #1214 gave its sibling.
        UITestPresentation.dismissAnyPresentation(in: app)
        app?.terminate()
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
        // does. It used to leave the keyboard up, which is what #559 fixed; `addTerm()` now resigns
        // focus on iOS, so this path exercises the dismissal as a side effect.
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
        // **iPhone only, and the gate is new.** `WorkingOnBanner.canRenderInTopInset` suppresses the
        // banner on a regular-width iPad (#461/#462), so the assertion below cannot pass there. Until
        // now the only thing keeping this test off an iPad screen was the `XCTSkip("Settings tab not
        // found")` inside the helper — an accident that became load-bearing the moment the helper
        // learned to reach Settings on a paginated bar. Stating the real condition instead.
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone,
                          "iPhone-only: the Working-on banner is suppressed on a regular-width iPad")

        try giveActiveProjectAResearchQuestion()

        // Confirm the banner is actually on screen before drawing any conclusion from this test.
        navigator.select(.browse)
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
    /// The one project this suite stages. Named so the idempotence check can find it again.
    private static let fixtureProjectName = "Supply Chain"

    private func giveActiveProjectAResearchQuestion() throws {
        // Through the navigator: the bare `app.buttons["Settings"]` this replaces could not see a
        // tab the floating iPad bar had paged off screen, and reported it as
        // `XCTSkip("Settings tab not found")` — a green skip for a helper's gap.
        //
        // ASSERTED rather than skipped (#1279). `select` already fails for a tab it cannot find in
        // any representation; the one path that returns `tapped: false` without failing is the
        // last-resort tap on a control that exists but never became hittable. A skip there is the
        // same green-for-a-helper's-gap this comment condemns, one level up.
        XCTAssertTrue(navigator.select(.settings).tapped,
                      "Could not open the Settings tab, so the project's research question "
                      + "cannot be staged.")

        let projects = app.buttons["Projects"].firstMatch
        guard projects.waitForExistence(timeout: 10) else { throw XCTSkip("Projects pane not found") }
        projects.tap()

        // Reuse the fixture project if this launch already created it.
        //
        // This helper once had no idempotence guard and created a new "Supply Chain" project on
        // EVERY run. Under FRUS_UI_TEST_MODE the SwiftData store was then the simulator's real
        // on-disk one, shared by every suite and never reset, so the projects accumulated —
        // seven of them in a single afternoon of repeated full-suite runs. It has been in memory
        // since #555 (2026-07-27), which ends that leak for every fixture; the guard stays.
        //
        // That is not merely untidy. Each row renders a three-line detail with no line limit,
        // so at seven rows "New Project…" is pushed below the fold of the Projects pane, and
        // SwiftUI's lazy List has not materialised it. `waitForExistence` does not scroll, so
        // it reports non-existence and `UIObstructionTests` fails on a completely unrelated
        // assertion — with a message about a missing row that is really a message about
        // fixture debris.
        let existing = app.buttons[Self.fixtureProjectName].firstMatch
        if existing.waitForExistence(timeout: 2) {
            return   // already staged in this launch; nothing to create
        }

        let newProject = app.buttons["New Project…"].firstMatch
        guard newProject.waitForExistence(timeout: 10) else {
            throw XCTSkip("New Project row not found in the Projects pane")
        }
        newProject.tap()

        let name = app.textFields["Project name"].firstMatch
        guard name.waitForExistence(timeout: 10) else { throw XCTSkip("Project name field not found") }
        name.tap()
        name.typeText(Self.fixtureProjectName)

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
        // Asserted, not skipped — see `giveActiveProjectAResearchQuestion` (#1279).
        XCTAssertTrue(navigator.select(.search).tapped,
                      "Could not open the Search tab, so its keywords field cannot be focused.")

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
    ///
    /// The shared implementation since #1279. This was a FOURTH copy of the same route, eight lines
    /// above the one #1279 named, carrying both defects the issue is about: it discarded
    /// `navigator.select(.browse)`'s result, and it skipped with `"Analysis Tools menu not found"`
    /// for a tab it may never have reached.
    private func openAnalysisItem(_ label: String) throws {
        try AnalysisToolsMenu.open(label, in: app, through: navigator)
    }

    /// Opens Browse ▸ the analysis menu ▸ Corpus Analytics.
    ///
    /// The shared implementation since #1279. Two other suites carried a copy of this that claimed
    /// to mirror it and never matched it — without the overflow expansion, and without a skip
    /// message that says what IS on screen.
    private func openCorpusAnalytics() throws {
        try AnalysisToolsMenu.open("Corpus Analytics", in: app, through: navigator)
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

// MARK: - CrossReferenceMatrixScrollTests

/// Cross-Reference Analytics' Volume Citation Heat Matrix lays out in the page, not in a scroll box
/// of its own (#1379).
///
/// ## What was wrong
/// The matrix sat in a `ScrollView([.horizontal, .vertical])` capped at 480 pt, inside the page's
/// own scroll view. A full matrix — fifteen volumes — is 565 pt tall, so rows 14 and 15 were always
/// below the box's edge, however tall the window; a drag that started on the matrix scrolled the box
/// and not the page, so a reader scrolling down stopped there; and scrolling the box down to reach
/// the last rows took the column codes, the grid's first row, off its top. Seen on iPad and on the
/// Mac (#1081's captures).
///
/// ## What each test asserts
/// Every test launches with `FRUS_UI_TEST_SEED_CROSSREF_MATRIX=1`, which writes citations among
/// fifteen real volumes into the index (`UITestVolumeSeeder`), so the matrix is full with nothing
/// downloaded. They find rows and column codes by accessibility IDENTIFIER — a row label and its
/// volume's column code carry the same accessibility label, the volume's full title — and read them
/// from one snapshot of the tree, so none depends on which volumes a simulator's own index adds to
/// the ranking.
/// - `testASwipeStartingOnTheMatrixScrollsThePage` drags upward from a cell in the middle of the grid
///   and requires the *Landmark Documents (Influence)* heading, below the matrix, to move up with
///   the page.
/// - `testTheLastRowShowsWithTheColumnCodes` scrolls the page from outside the grid until the last
///   row can be tapped, and then requires the first column code to be tappable too.
/// - `testTheLabelColumnTakesTheWidthTheCellsLeave` measures the window the matrix is drawn in and
///   requires every row label to end, and every column code to sit, where
///   `HeatMatrixRowAxis.labelWidth` puts them for that window. The function has unit tests of its
///   own; this guards its INPUT, the width the view measures, which no unit test reaches. A view
///   that never measured would draw a 150 pt column at every width, #1379's second complaint; one
///   that measured outside its side padding would give the labels 32 pt too many and push the cells
///   into a sideways scroll on every iPad.
/// - `testEachRowLabelLinesUpWithItsRowOfCells` requires every row label's centre to sit on the
///   centre of each of the fifteen cells whose accessibility label names its volume as the citing
///   one. A row label used to be its row's first cell. It is now one of a column of labels beside
///   the cells' grid, and the two line up only while the column's spacing and header spacer match
///   the grid's.
/// - `testTheCellsScrollSidewaysBesideLabelsThatStayPut` runs only where the cells are wider than
///   the window. It drags a row of cells sideways and requires the column codes to move while the row
///   label stays where it was, then drags upward from the scrolled cells and requires the page, and
///   the labels with it, to move up. That is the layout every other test here sees only where the
///   sideways scroll view has nothing to scroll.
///
/// ## Which tests run where
/// The first two need an iPad and self-skip on an iPhone. They are measured on iPad Pro 11-inch
/// (M5) in portrait, where the page shows the whole 565 pt grid at once, and a window too short to
/// show it would fail the second test however the matrix scrolled. The sideways test needs a window
/// narrower than 707 pt — the 525 pt of cells, the 150 pt narrowest label column and 32 pt of page
/// padding — which no full-screen iPad is, so it self-skips there and names the width it measured;
/// an iPhone in portrait runs it. The width and alignment tests run on both. Expect **5 tests, 1
/// skipped** on an iPad and **5 tests, 2 skipped** on an iPhone.
///
/// Version history:
///   1.0 — #1379: initial implementation
///   1.1 — #1379 review round 1: the label-column width, the row alignment and the sideways scroll
///          are measured on screen; the app launches from `openTheMatrix`, after a test's device
///          check, instead of from `setUp`
@MainActor
final class CrossReferenceMatrixScrollTests: XCTestCase {

    var app: XCUIApplication!

    /// Read through a closure: `setUp` mints a fresh `XCUIApplication` per test (#1278).
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    /// `HeatMatrixRowAxis.rowLabelIdentifierPrefix`, spelled here because this target cannot import
    /// the app; `HeatMatrixRowAxisTests.identifierPrefixesArePinned` reads this file and holds the
    /// app's copy to this one.
    private static let rowPrefix = "crossRefAnalytics.matrix.row."

    /// `HeatMatrixRowAxis.columnCodeIdentifierPrefix`, spelled and held for the same reason.
    private static let columnPrefix = "crossRefAnalytics.matrix.column."

    /// The section heading below the matrix — the mark that the PAGE moved.
    private static let landmarkHeading = "Landmark Documents (Influence)"

    /// The matrix's own section heading.
    private static let matrixHeading = "Volume Citation Heat Matrix"

    /// The page's side padding, SwiftUI's default `.padding(.horizontal)` on iOS, inside which the
    /// matrix lays out.
    private static let pagePadding: CGFloat = 16

    /// The on-screen cell's edge (`CrossReferenceAnalyticsView.matrixCellSize`). Cells are 1 pt apart.
    private static let cellSize: CGFloat = 34

    /// A full matrix's volumes: its rows, and its columns.
    private static let volumeCount = 15

    /// The label column's width in a window `width` points wide, as `HeatMatrixRowAxis.labelWidth`
    /// gives it — spelled here because this target cannot import the app: what the cells leave of
    /// the width inside the page's padding, from 150 pt up to the exported figure's 320 pt.
    private static func labelWidth(forWindowWidth width: CGFloat) -> CGFloat {
        let cells = CGFloat(volumeCount) * (cellSize + 1)
        return min(max(width - 2 * pagePadding - cells, 150), 320)
    }

    override func setUp() async throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_CROSSREF_MATRIX"] = "1"
        // A screen measured at rest (CLAUDE.md, the iOS 27 idle stall). Scrolling is a scroll
        // view's own deceleration, which this does not turn off.
        app.launchEnvironment["FRUS_UI_TEST_DISABLE_ANIMATIONS"] = "1"
        // The two charts above the matrix collapsed and the two sections the tests read open, so
        // where the matrix starts does not depend on what an earlier run left in UserDefaults.
        app.launchArguments = UITestLaunch.arguments() + [
            "-frus.crossRefAnalytics.rankingExpanded", "NO",
            "-frus.crossRefAnalytics.distributionExpanded", "NO",
            "-frus.crossRefAnalytics.matrixExpanded", "YES",
            "-frus.crossRefAnalytics.landmarkExpanded", "YES",
        ]
        // Launched by `openTheMatrix`, so a test that skips for its device launches nothing.
    }

    override func tearDown() async throws {
        // Close the analytics window before terminating (#1279): iPadOS restores an open window
        // scene on the next launch, and the next test would find no tab bar at all.
        UITestPresentation.dismissAnyPresentation(in: app)
        app?.terminate()
        app = nil
    }

    // MARK: - Tests

    /// A drag that starts on a cell scrolls the page: the heading below the matrix moves up.
    func testASwipeStartingOnTheMatrixScrollsThePage() throws {
        try requireAnIPad()
        try openTheMatrix()
        let rows = try buttons(prefix: Self.rowPrefix, orderedBy: { $0.minY })
        let columns = try buttons(prefix: Self.columnPrefix, orderedBy: { $0.minX })
        let row = app.buttons[rows[7]].firstMatch
        let column = app.buttons[columns[7]].firstMatch
        XCTAssertTrue(bringOnScreen(row, column), """
            The eighth row and the eighth column could not both be brought on screen to start the \
            drag from a cell between them.\n\(tree())
            """)
        let heading = app.buttons[Self.landmarkHeading].firstMatch
        XCTAssertTrue(heading.exists, "No '\(Self.landmarkHeading)' heading below the matrix.\n\(tree())")

        let before = heading.frame.minY
        let x = column.frame.midX, y = row.frame.midY
        drag(from: CGPoint(x: x, y: y), to: CGPoint(x: x, y: y - 260))
        let moved = before - heading.frame.minY

        print("[CrossReferenceMatrixScrollTests] a 260 pt drag from the cell at (\(x), \(y)) moved the heading \(moved) pt")
        XCTAssertGreaterThan(moved, 100, """
            A 260 pt upward drag that started on the matrix's cell at (\(x), \(y)) moved the \
            '\(Self.landmarkHeading)' heading \(moved) pt: the drag scrolled something inside the \
            matrix and not the page — #1379's scroll box, which stopped a reader scrolling down the \
            window at the matrix.
            """)
    }

    /// The last row and the column codes are on screen together.
    func testTheLastRowShowsWithTheColumnCodes() throws {
        try requireAnIPad()
        try openTheMatrix()
        let rows = try buttons(prefix: Self.rowPrefix, orderedBy: { $0.minY })
        let columns = try buttons(prefix: Self.columnPrefix, orderedBy: { $0.minX })
        let lastRow = app.buttons[try XCTUnwrap(rows.last)].firstMatch
        let firstColumn = app.buttons[try XCTUnwrap(columns.first)].firstMatch

        var drags = 0
        while !(lastRow.exists && lastRow.isHittable), drags < 6, let handle = pageHandle() {
            // From outside the grid, and short, so no drag carries the column codes past the top
            // before the last row comes up.
            let from = CGPoint(x: handle.frame.midX, y: handle.frame.midY)
            drag(from: from, to: CGPoint(x: from.x, y: from.y - 150))
            drags += 1
        }
        print("[CrossReferenceMatrixScrollTests] \(drags) page drag(s); last row '\(lastRow.label)' at \(lastRow.frame), "
              + "first column '\(firstColumn.label)' at \(firstColumn.frame)")
        // Kept on a pass as well as a failure: the labels' cut — the topic at its tail, the tag
        // whole — is checked by eye from this, since no XCUI property reports a truncation.
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Heat matrix with its last row on screen"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        XCTAssertTrue(lastRow.isHittable, """
            The matrix's last row ('\(lastRow.label)', \(rows.count) rows) never came on screen after \
            \(drags) drag(s) of the page — #1379's 480 pt box, below whose edge the 14th and 15th \
            rows always sat.\n\(tree())
            """)
        XCTAssertTrue(firstColumn.isHittable, """
            With the last row on screen, the first column code ('\(firstColumn.label)') is not — the \
            column codes scrolled away with the rows, as they did in #1379's scroll box.\n\(tree())
            """)
    }

    /// The label column is as wide as `HeatMatrixRowAxis.labelWidth` makes it for this window, so the
    /// labels end, and the column codes sit, where that width puts them.
    func testTheLabelColumnTakesTheWidthTheCellsLeave() throws {
        try openTheMatrix()
        let snapshot = try everything()
        let window = try matrixWindow(in: snapshot)
        let labelWidth = Self.labelWidth(forWindowWidth: window.width)
        // The label column's trailing edge, and the centre of the first column of cells, 1 pt past
        // it. Before any sideways drag the cells' scroll view is at its start.
        let edge = window.minX + Self.pagePadding + labelWidth
        let firstCentre = edge + 1 + Self.cellSize / 2
        let rows = matrixButtons(Self.rowPrefix, in: snapshot)
        let columns = matrixButtons(Self.columnPrefix, in: snapshot).sorted { $0.frame.midX < $1.frame.midX }
        XCTAssertEqual(rows.count, Self.volumeCount, "Expected \(Self.volumeCount) row labels.\n\(tree())")
        XCTAssertEqual(columns.count, Self.volumeCount, "Expected \(Self.volumeCount) column codes.\n\(tree())")

        let rowsOff = rows.filter { abs($0.frame.maxX - edge) > 1.5 }
        let columnsOff = columns.enumerated().filter { index, column in
            abs(column.frame.midX - (firstCentre + CGFloat(index) * (Self.cellSize + 1))) > 1.5
        }
        print("[CrossReferenceMatrixScrollTests] window \(window): a \(labelWidth) pt label column ends at x \(edge) "
              + "and puts the first cell's centre at x \(firstCentre); the row labels end at "
              + "\(Set(rows.map { $0.frame.maxX }).sorted()) and the first column code is at "
              + "\(columns.first.map { "\($0.frame)" } ?? "nowhere")")
        XCTAssertTrue(rowsOff.isEmpty, """
            In a window \(window.width) pt wide the label column should be \(labelWidth) pt and end at \
            x \(edge), but these row labels end elsewhere: \
            \(rowsOff.map { "\($0.identifier) at \($0.frame.maxX)" }). The view is not sizing the \
            column from the width inside its side padding — a 150 pt column at every width is \
            #1379's second complaint.
            """)
        XCTAssertTrue(columnsOff.isEmpty, """
            In a window \(window.width) pt wide the first column of cells should be centred at x \
            \(firstCentre), each next one 35 pt on, but these column codes sit elsewhere: \
            \(columnsOff.map { "\($0.element.identifier) at \($0.element.frame.midX)" }).
            """)
    }

    /// Each row label sits level with its own row of cells.
    func testEachRowLabelLinesUpWithItsRowOfCells() throws {
        try openTheMatrix()
        let snapshot = try everything()
        let rows = matrixButtons(Self.rowPrefix, in: snapshot)
        // A cell's accessibility label is "<citing title> cites <cited title>: …", and a row label's
        // is its volume's title, so a row's cells are the ones whose label begins with its title.
        let cells = snapshot.filter { $0.type == .other && $0.label.contains(" cites ") }
        XCTAssertEqual(rows.count, Self.volumeCount, "Expected \(Self.volumeCount) row labels.\n\(tree())")

        var drifts: [(identifier: String, drift: CGFloat)] = []
        for row in rows.sorted(by: { $0.frame.minY < $1.frame.minY }) {
            let own = cells.filter { $0.label.hasPrefix(row.label + " cites ") }
            XCTAssertEqual(own.count, Self.volumeCount, """
                The row '\(row.identifier)' has \(own.count) cells whose label names it as the citing \
                volume, not \(Self.volumeCount).\n\(tree())
                """)
            drifts.append((row.identifier, own.map { abs($0.frame.midY - row.frame.midY) }.max() ?? 0))
        }
        let report = drifts.map { String(format: "%@ %.1f", $0.identifier, $0.drift) }.joined(separator: ", ")
        print("[CrossReferenceMatrixScrollTests] each row label's largest vertical distance from its cells' centres: \(report)")
        XCTAssertTrue(drifts.allSatisfy { $0.drift <= 1 }, """
            A row label is not level with its row of cells: \(report). The labels are a column of \
            their own beside the cells' grid (#1379), and line up with it only while the column's \
            header spacer and spacing match the grid's header row and vertical spacing.
            """)
    }

    /// Where the cells are wider than the window, they scroll sideways beside labels that stay put,
    /// and a vertical drag that starts on them still scrolls the page.
    func testTheCellsScrollSidewaysBesideLabelsThatStayPut() throws {
        try openTheMatrix()
        let window = try matrixWindow(in: try everything())
        let rows = try buttons(prefix: Self.rowPrefix, orderedBy: { $0.minY })
        let columns = try buttons(prefix: Self.columnPrefix, orderedBy: { $0.minX })
        let lastColumn = app.buttons[try XCTUnwrap(columns.last)].firstMatch
        // The right edge of the cells' scroll view: the page's padding in from the window's edge.
        let viewportEdge = window.maxX - Self.pagePadding
        // The last column's cell, 34 pt wide, centred on its code.
        let gridEdge = lastColumn.frame.midX + Self.cellSize / 2
        guard gridEdge > viewportEdge + 1 else {
            throw XCTSkip("""
                In a window \(window.width) pt wide the grid fits (its last column ends at x \
                \(gridEdge), inside the page's edge at x \(viewportEdge)), so its cells have \
                nothing to scroll sideways. Run this on an iPhone in portrait.
                """)
        }
        // The first row, raised into the upper two-thirds of the window: both drags below start on
        // its cells, and one that started at the foot of an iPhone's screen would be the system's
        // home gesture instead (the first run of this test did exactly that).
        let row = app.buttons[rows[0]].firstMatch
        let firstColumn = app.buttons[try XCTUnwrap(columns.first)].firstMatch
        XCTAssertTrue(raise(row, in: window) && firstColumn.isHittable, """
            The first row could not be brought into the upper two-thirds of the window with the \
            first column code on screen: row at \(row.frame), code at \(firstColumn.frame).\n\(tree())
            """)
        let heading = app.buttons[Self.matrixHeading].firstMatch

        // Sideways, along the row, from near the right edge of the cells' scroll view.
        let x = viewportEdge - 30, y = row.frame.midY
        let labelBefore = row.frame, codeBefore = firstColumn.frame.midX, headingBefore = heading.frame.minY
        drag(from: CGPoint(x: x, y: y), to: CGPoint(x: x - 150, y: y))
        let codeMoved = codeBefore - firstColumn.frame.midX
        let labelAfter = row.frame, headingAfterSideways = heading.frame.minY

        // Then upward, from the same cell, with the sideways scroll view scrolled.
        let rise = min(200, y - window.minY - 150)
        XCTAssertGreaterThan(rise, 100, "The row at y \(y) is too near the top to drag the page up from it.")
        drag(from: CGPoint(x: x, y: y), to: CGPoint(x: x, y: y - rise))
        let pageMoved = headingAfterSideways - heading.frame.minY
        let labelMoved = labelAfter.minY - row.frame.minY

        print("[CrossReferenceMatrixScrollTests] in a \(window.width) pt window, a 150 pt sideways drag at "
              + "(\(x), \(y)) moved the first column code \(codeMoved) pt and the row label from \(labelBefore) "
              + "to \(labelAfter) (heading \(headingBefore) → \(headingAfterSideways)); then a \(rise) pt "
              + "upward drag from the same cell moved the heading \(pageMoved) pt and the row label \(labelMoved) pt")
        XCTAssertGreaterThan(codeMoved, 100, """
            A 150 pt sideways drag across the cells moved the first column code \(codeMoved) pt: the \
            cells did not scroll sideways, so the columns past the window's edge cannot be reached.
            """)
        XCTAssertEqual(labelAfter.minX, labelBefore.minX, accuracy: 0.5, """
            The row label moved sideways with the cells (\(labelBefore) → \(labelAfter)): the labels \
            are inside the sideways scroll, as they were in #1379's scroll box, and scroll out of \
            sight beside the cells they name.
            """)
        XCTAssertEqual(headingAfterSideways, headingBefore, accuracy: 0.5, """
            A sideways drag moved the page (the matrix heading \(headingBefore) → \(headingAfterSideways)).
            """)
        XCTAssertGreaterThan(pageMoved, rise / 2, """
            A \(rise) pt upward drag that started on the scrolled cells moved the matrix heading \
            \(pageMoved) pt: the drag scrolled something inside the matrix and not the page — \
            #1379's scroll box.
            """)
        XCTAssertEqual(labelMoved, pageMoved, accuracy: 1, """
            The page moved \(pageMoved) pt but the row label \(labelMoved) pt: the labels are not \
            standing in the page.
            """)
    }

    // MARK: - Helpers

    /// Skips unless this is an iPad — for the two tests measured against an iPad's window.
    private func requireAnIPad() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, """
            #1379 was seen on iPad and the Mac; this test measures an iPad's window, where the whole \
            grid fits on screen. Run it on iPad Pro 11-inch (M5) in portrait.
            """)
    }

    /// Launches the app, opens Cross-Reference Analytics and waits for a full matrix.
    private func openTheMatrix(file: StaticString = #filePath, line: UInt = #line) throws {
        app.launch()
        try AnalysisToolsMenu.open("Cross-Reference Analytics", in: app, through: navigator,
                                   file: file, line: line)
        XCTAssertTrue(app.buttons[Self.matrixHeading].firstMatch.waitForExistence(timeout: 20),
                      "Cross-Reference Analytics opened without its heat matrix section.\n\(tree())",
                      file: file, line: line)
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", Self.rowPrefix))
        let deadline = Date().addingTimeInterval(30)
        while rows.count < 15, Date() < deadline { Thread.sleep(forTimeInterval: 0.5) }
        XCTAssertEqual(rows.count, 15, """
            The heat matrix has \(rows.count) rows, not a full 15 — was the index seeded? \
            (FRUS_UI_TEST_SEED_CROSSREF_MATRIX)\n\(tree())
            """, file: file, line: line)
    }

    /// One element of a snapshot of the tree.
    private struct Seen {
        /// The element's type.
        let type: XCUIElement.ElementType
        /// Its accessibility identifier.
        let identifier: String
        /// Its accessibility label.
        let label: String
        /// Its frame, in screen points.
        let frame: CGRect
    }

    /// Every element of ONE snapshot of the tree, so a re-render between two reads cannot mix two
    /// layouts.
    private func everything() throws -> [Seen] {
        var found: [Seen] = []
        func walk(_ element: XCUIElementSnapshot) {
            found.append(Seen(type: element.elementType, identifier: element.identifier,
                              label: element.label, frame: element.frame))
            for child in element.children { walk(child) }
        }
        walk(try app.snapshot())
        return found
    }

    /// The buttons in `snapshot` whose identifier starts with `prefix`.
    private func matrixButtons(_ prefix: String, in snapshot: [Seen]) -> [Seen] {
        snapshot.filter { $0.type == .button && $0.identifier.hasPrefix(prefix) }
    }

    /// The frame of the window the matrix is drawn in: the smallest window holding its heading. On an
    /// iPad the analytics is a window of its own, and on an iPhone a sheet in the app's window.
    private func matrixWindow(in snapshot: [Seen]) throws -> CGRect {
        let heading = try XCTUnwrap(snapshot.first { $0.type == .button && $0.label == Self.matrixHeading },
                                    "No '\(Self.matrixHeading)' heading in the tree.\n\(tree())").frame
        let centre = CGPoint(x: heading.midX, y: heading.midY)
        return try XCTUnwrap(snapshot.filter { $0.type == .window && $0.frame.contains(centre) }
            .map(\.frame)
            .min { $0.width * $0.height < $1.width * $1.height },
            "No window holds the matrix heading at \(centre).\n\(tree())")
    }

    /// The identifiers of the buttons whose identifier starts with `prefix`, ordered by `key` of
    /// their frames — read from ONE snapshot of the tree, so a re-render between two reads cannot
    /// mix two layouts.
    private func buttons(prefix: String, orderedBy key: (CGRect) -> CGFloat) throws -> [String] {
        let found = matrixButtons(prefix, in: try everything())
        XCTAssertEqual(found.count, 15, "Expected 15 buttons identified '\(prefix)…', found \(found.count).")
        return found.sorted { key($0.frame) < key($1.frame) }.map(\.identifier)
    }

    /// The first element outside the grid that can start a drag of the page, top to bottom: the
    /// matrix's subtitle, its heading, and the heading of the section below it.
    private func pageHandle() -> XCUIElement? {
        let candidates = [
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Rows cite columns'")).firstMatch,
            app.buttons[Self.matrixHeading].firstMatch,
            app.buttons[Self.landmarkHeading].firstMatch,
        ]
        return candidates.first { $0.exists && $0.isHittable }
    }

    /// Scrolls the page from outside the grid until `element`'s centre is in the upper two-thirds of
    /// `window`, or gives up.
    ///
    /// - Returns: Whether it got there and can be tapped.
    private func raise(_ element: XCUIElement, in window: CGRect) -> Bool {
        let limit = window.minY + window.height * 2 / 3
        var drags = 0
        while element.frame.midY > limit, drags < 6, let handle = pageHandle() {
            let from = CGPoint(x: handle.frame.midX, y: handle.frame.midY)
            drag(from: from, to: CGPoint(x: from.x, y: from.y - min(150, element.frame.midY - limit + 40)))
            drags += 1
        }
        return element.frame.midY <= limit && element.isHittable
    }

    /// Scrolls the page from outside the grid until both elements can be tapped, or gives up.
    private func bringOnScreen(_ first: XCUIElement, _ second: XCUIElement) -> Bool {
        var drags = 0
        while !(first.isHittable && second.isHittable), drags < 6, let handle = pageHandle() {
            let from = CGPoint(x: handle.frame.midX, y: handle.frame.midY)
            drag(from: from, to: CGPoint(x: from.x, y: from.y - 150))
            drags += 1
        }
        return first.isHittable && second.isHittable
    }

    /// A slow drag between two screen points, held at the end so it leaves no momentum behind, and
    /// then a pause for the layout to settle.
    private func drag(from start: CGPoint, to end: CGPoint) {
        let origin = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        origin.withOffset(CGVector(dx: start.x, dy: start.y))
            .press(forDuration: 0.1,
                   thenDragTo: origin.withOffset(CGVector(dx: end.x, dy: end.y)),
                   withVelocity: .slow,
                   thenHoldForDuration: 0.3)
        Thread.sleep(forTimeInterval: 0.8)
    }

    /// The element tree, for a failure message that says what WAS on screen.
    private func tree() -> String {
        app.state == .runningForeground ? app.debugDescription : "(app not in the foreground)"
    }
}
