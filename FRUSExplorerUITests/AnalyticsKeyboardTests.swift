// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import XCTest

/// The Corpus Analytics term field gives the screen back after it commits a term (#559).
///
/// ## Why this needs a UI test rather than a unit test
/// The thing being asserted is whether a software keyboard is on screen, which only exists in a
/// running app. `AnalyticsView` has no view model to interrogate — the focus lives in
/// `@FocusState`, which is not readable from outside the view.
///
/// ## The vacuity problem, and how this handles it
/// A simulator attached to the Mac's hardware keyboard **never shows the software keyboard**, so a
/// naive "assert no keyboard after submit" passes without testing anything — the keyboard was
/// never there to dismiss. Every test below therefore asserts the keyboard IS up first, and calls
/// `XCTSkip` if it is not. A skip is honest; a green run that measured nothing is not.
///
/// To make it run rather than skip, disable the hardware keyboard in the Simulator
/// (I/O ▸ Keyboard ▸ Connect Hardware Keyboard, ⇧⌘K) — or run on a device, which is what the
/// issue describes.
///
/// Version history:
///   1.0 — #559: initial implementation
final class AnalyticsKeyboardTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        // Without this the app launches into onboarding, "Analysis Tools" is never reachable,
        // and every test in this suite SKIPS — reporting success having measured nothing.
        app.launchArguments = ["-hasCompletedOnboarding", "1"]
        app.launch()
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
        app = nil
    }

    /// The reported bug: Return commits the term and the keyboard stays up forever.
    func testKeyboardDismissesAfterCommittingTerm() throws {
        let field = try focusedTermField()

        field.typeText("Berlin\n")

        XCTAssertTrue(app.staticTexts["Berlin"].waitForExistence(timeout: 10),
                      "The term should commit — otherwise this is not testing the dismissal path")
        XCTAssertTrue(waitForKeyboard(toBePresent: false),
                      """
                      #559: the keyboard is still up after committing a term. In portrait it covers \
                      the chart the term was typed to produce; in landscape it covers essentially \
                      all of it, and this view offers no way down.
                      """)
    }

    /// The keyboard must come back when the user asks for it — the fix resigns focus, it does not
    /// make the field unusable.
    func testFieldIsRefocusableAfterDismissal() throws {
        let field = try focusedTermField()
        field.typeText("Berlin\n")
        XCTAssertTrue(waitForKeyboard(toBePresent: false), "precondition: the keyboard dismissed")

        field.tap()
        XCTAssertTrue(waitForKeyboard(toBePresent: true),
                      "tapping the field again must bring the keyboard back")
    }

    /// A second term must be enterable, which is the regression a too-eager resign would cause.
    func testSecondTermStillCommits() throws {
        let field = try focusedTermField()
        field.typeText("Berlin\n")
        XCTAssertTrue(app.staticTexts["Berlin"].waitForExistence(timeout: 10))

        field.tap()
        field.typeText("Vienna\n")
        XCTAssertTrue(app.staticTexts["Vienna"].waitForExistence(timeout: 10),
                      "resigning focus must not block entering a comparison term")
    }

    // MARK: - Helpers

    /// Opens Corpus Analytics, focuses the term field, and skips if no software keyboard appears.
    private func focusedTermField() throws -> XCUIElement {
        try openCorpusAnalytics()
        let field = app.textFields["Term…"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Term field should exist")
        field.tap()

        guard waitForKeyboard(toBePresent: true) else {
            throw XCTSkip("""
                No software keyboard appeared, so there is nothing to dismiss and this test would \
                pass vacuously. Disable the Simulator's hardware keyboard (⇧⌘K) or run on a device.
                """)
        }
        return field
    }

    /// Polls for the software keyboard reaching `present`, because dismissal is animated and
    /// `app.keyboards.count` is sampled, not awaited.
    private func waitForKeyboard(toBePresent present: Bool, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if (app.keyboards.count > 0) == present { return true }
            usleep(200_000)
        } while Date() < deadline
        return (app.keyboards.count > 0) == present
    }

    /// Mirrors `AnalyticsRotationTests.openCorpusAnalytics` — the toolbar path to the sheet.
    private func openCorpusAnalytics() throws {
        let browse = app.buttons["Browse"].firstMatch
        if browse.waitForExistence(timeout: 10) { browse.tap() }

        let menu = app.buttons["Analysis Tools"]
        guard menu.waitForExistence(timeout: 10) else {
            throw XCTSkip("Analysis Tools menu not reachable on this destination")
        }
        menu.tap()

        let item = app.buttons["Corpus Analytics"].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 10), "Corpus Analytics item should exist")
        item.tap()
    }
}
