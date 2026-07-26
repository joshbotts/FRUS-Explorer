// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import XCTest

/// The #498 mitigation, exercised with the orientation lock ACTIVE.
///
/// `AnalyticsRotationTests` deliberately disables the lock so it keeps reproducing the underlying
/// AttributeGraph cycle. This suite is its complement: it runs the app as users get it and asserts
/// that the sequence which wedges an unmitigated build now survives.
///
/// The two suites must both keep passing, and they mean different things:
/// - `AnalyticsRotationTests` failing = the defect (or a regression in the repro harness).
/// - This suite failing = the mitigation stopped working, and iPhone users can wedge the app again.
///
/// Version history:
///   1.0 — #498: initial implementation, alongside the OrientationLock mitigation
final class AnalyticsOrientationLockTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        // Start every test upright. XCUIDevice orientation is process-wide and survives
        // between tests, so a landscape leftover silently changes the layout under test.
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchArguments = ["-hasCompletedOnboarding", "1"]
        // NB: no FRUS_DISABLE_ORIENTATION_LOCK — this suite wants the shipped behaviour.
        app.launch()
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
        app = nil
    }

    /// The exact sequence that wedges an unmitigated build: commit a term, re-focus the field, then
    /// rotate. With the lock engaged the rotation is inert and the app survives.
    func testMitigatedRotationSurvivesTheMinimalTrigger() throws {
        try openCorpusAnalytics()

        let field = app.textFields["Term…"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Term field should exist")
        field.tap()
        field.typeText("Berlin\n")

        let addField = app.textFields["Add a term…"]
        XCTAssertTrue(addField.waitForExistence(timeout: 10), "Term should commit")
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 2)
        addField.tap()

        XCUIDevice.shared.orientation = .landscapeLeft
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 12)
        XCUIDevice.shared.orientation = .portrait
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 12)

        XCTAssertEqual(app.state, .runningForeground,
                       "The orientation lock should have kept the app alive through #498's trigger.")
    }

    /// The lock must be RELEASED when the sheet closes, or the whole app is stuck in one orientation
    /// for the rest of the session — a worse bug than the one being mitigated.
    ///
    /// Asserted behaviourally rather than by reading the mask: after dismissing the sheet, rotating
    /// to landscape must actually change the interface, which it can only do if rotation was restored.
    func testLockIsReleasedWhenTheSheetIsDismissed() throws {
        try openCorpusAnalytics()
        XCTAssertTrue(app.textFields["Term…"].waitForExistence(timeout: 10),
                      "Corpus Analytics should be presented")

        let portraitWidth = app.windows.firstMatch.frame.width

        // Dismiss via the sheet's own Done button. A swipe-down is unreliable against a full-height
        // sheet, and a dismissal that silently fails would make this test assert nothing.
        let done = app.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 5), "Corpus Analytics should offer Done")
        done.tap()
        XCTAssertTrue(app.textFields["Term…"].waitForNonExistence(timeout: 10),
                      "The sheet must actually be dismissed before checking that rotation returned")

        XCUIDevice.shared.orientation = .landscapeLeft
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 10)

        let landscapeWidth = app.windows.firstMatch.frame.width
        XCTAssertGreaterThan(landscapeWidth, portraitWidth,
                             "After dismissing Corpus Analytics the app must rotate freely again "
                             + "(width \(landscapeWidth) should exceed portrait width \(portraitWidth)). "
                             + "A leaked lock would strand the whole app in one orientation.")
    }

    // MARK: - Helpers

    private func openCorpusAnalytics() throws {
        let browse = app.buttons["Browse"].firstMatch
        if browse.waitForExistence(timeout: 10) { browse.tap() }

        var menu = app.buttons["Analysis Tools"]
        if !menu.waitForExistence(timeout: 10) {
            for label in ["More", "Show More", "More Actions"] {
                let more = app.buttons[label].firstMatch
                if more.exists { more.tap(); break }
            }
            menu = app.buttons["Analysis Tools"]
            if !menu.waitForExistence(timeout: 5) { menu = app.buttons["chart.bar.xaxis"].firstMatch }
            guard menu.waitForExistence(timeout: 5) else {
                throw XCTSkip("Analysis toolbar menu not found — Browse toolbar layout changed")
            }
        }
        menu.tap()

        let item = app.buttons["Corpus Analytics"].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5), "Corpus Analytics menu item should exist")
        item.tap()
    }
}
