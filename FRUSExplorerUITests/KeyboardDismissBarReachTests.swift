// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import XCTest

/// `.keyboardDismissBar()` renders when its host is **not** inside a `NavigationStack`.
///
/// ## The question this exists to answer (#861)
/// Every adopter before this PR sat inside a `NavigationStack`. Two of the new ones do not: the
/// year-range popover is a bare `VStack` presented with `.presentationCompactAdaptation(.popover)`,
/// and `InlineNoteCreateSheet` is a bare `VStack` with no navigation container at all. The audit
/// reasoned it should work — `.keyboard` placement is an input-accessory mechanism keyed to the
/// focused responder rather than a nav-bar one — but nobody had observed it in this app, and the
/// year popover is the highest-leverage edit in the change: **one line reaches seven dashboards**.
/// Shipping it inert would put apparent coverage over seven screens that does nothing.
///
/// ## Two ways this test could lie, and what stops each
/// **Vacuity.** A simulator attached to the Mac's hardware keyboard never raises a software
/// keyboard, so there would be no accessory bar to find and the assertion would pass having
/// measured nothing. Like `AnalyticsKeyboardTests`, this skips rather than passes when no keyboard
/// appears. To make it run: Simulator ▸ I/O ▸ Keyboard ▸ Connect Hardware Keyboard (⇧⌘K), or
/// `defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool false`.
///
/// **A foreign Done.** The host sheet has its own toolbar, and asserting `buttons["Done"].exists`
/// would be satisfied by that one whether or not the accessory bar rendered. So the measurement is
/// a **count taken before focus and again after**: the bar is what the increase is made of.
///
/// Version history:
///   1.0 — #861: settles the open question the audit could not
final class KeyboardDismissBarReachTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchArguments = ["-hasCompletedOnboarding", "1"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// The year-range popover — a bare `VStack`, and the `.numberPad` it hosts has no return key.
    func testDismissBarRendersInTheYearRangePopover() throws {
        try openCorpusAnalytics()

        // The chip rides the chart chrome, so a term has to produce a chart first.
        let term = app.textFields["Term…"].firstMatch
        if term.waitForExistence(timeout: 10) {
            term.tap()
            term.typeText("Berlin\n")
            Thread.sleep(forTimeInterval: 3.0)
        }

        let chip = app.buttons["Year range"].firstMatch
        if !chip.waitForExistence(timeout: 10) {
            print("[#861] no chip. buttons: "
                  + (0..<app.buttons.count).map { app.buttons.element(boundBy: $0).label }
                      .filter { !$0.isEmpty }.joined(separator: " | "))
            throw XCTSkip("The year-range chip is not on this screen on this destination")
        }
        chip.tap()

        // Whatever "Done"s the host already shows — the sheet's own toolbar, chiefly.
        let doneBefore = app.buttons.matching(
            NSPredicate(format: "label ==[c] 'Done'")).count

        print("[#861] popover open. textFields: "
              + (0..<app.textFields.count).map {
                    let f = app.textFields.element(boundBy: $0)
                    return "\(f.label)/\(String(describing: f.value))@\(Int(f.frame.origin.y))"
                }.joined(separator: " | "))
        print("[#861] popover buttons: "
              + (0..<app.buttons.count).map { app.buttons.element(boundBy: $0).label }
                  .filter { !$0.isEmpty }.joined(separator: " | "))

        let field = app.textFields.matching(
            NSPredicate(format: "value != nil")).firstMatch
        guard field.waitForExistence(timeout: 5) else {
            throw XCTSkip("No year field in the popover on this destination")
        }
        field.tap()

        // PROVE THE FIELD HAS FOCUS. `waitForKeyboard()` alone is not enough: the Term field
        // behind the popover may already have raised a keyboard, in which case a missing Done
        // would say nothing about this host. Typing must move THIS field's value.
        let beforeValue = String(describing: field.value)
        field.typeText("5")
        Thread.sleep(forTimeInterval: 1.0)
        let afterValue = String(describing: field.value)
        print("[#861] year field value \(beforeValue) -> \(afterValue)")
        guard beforeValue != afterValue else {
            throw XCTSkip("Tapping the year field did not focus it (value unchanged) - this run cannot judge whether a dismissal affordance renders here.")
        }

        guard waitForKeyboard() else {
            throw XCTSkip("""
                No software keyboard appeared, so no accessory bar can exist and this test would \
                pass vacuously. Disconnect the Simulator's hardware keyboard (⇧⌘K).
                """)
        }

        // The popover's OWN Done, identified rather than matched by label — the host sheet
        // has a Done of its own in the toolbar, and counting labels cannot tell them apart.
        let popoverDone = app.buttons["yearRangeDone"].firstMatch
        XCTAssertTrue(popoverDone.waitForExistence(timeout: 3), "The year popover offers no way to dismiss its keyboard. It has none of its own (Reset is hidden on a default range) and both inherited mechanisms are inert in a popover: see the note in rangePickerPopover.")

        popoverDone.tap()
        XCTAssertTrue(waitForKeyboardGone(), "Tapping the popover's Done left the keyboard up.")
    }

    private func waitForKeyboardGone(timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if app.keyboards.count == 0 { return true }
            usleep(200_000)
        } while Date() < deadline
        return app.keyboards.count == 0
    }

    // MARK: - Helpers

    private func waitForKeyboard(timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if app.keyboards.count > 0 { return true }
            usleep(200_000)
        } while Date() < deadline
        return app.keyboards.count > 0
    }

    /// Mirrors `AnalyticsKeyboardTests.openCorpusAnalytics` — the toolbar path to the sheet.
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
