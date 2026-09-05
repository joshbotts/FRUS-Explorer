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
/// ## Why the Browse scenario waits, and why it no longer trusts `isHittable` alone
/// `isHittable` is a hit test against a single accessibility snapshot. The check used to be taken
/// in the instant after `waitForKeyboard()` returns — which is when the keyboard element merely
/// *exists*, not when it and its accessory row have finished coming up — with no wait of any kind,
/// alone among the waits in this file.
///
/// **Reported** (2026-09-05, `v2` at f9e702ce): green run alone, `XCTAssertNotNil failed - A Done
/// was counted but none is hittable` when the class runs this second, and the same in a full
/// `xcodebuild test`. **Not reproduced here**: twelve class runs in both orders, a full 37-test
/// UI-target run, a run under deliberate CPU load, and a run on each of the two iOS builds a
/// `name:iPhone 17` destination can resolve to (26.3.1 and 26.5) were all green. So the unwaited
/// snapshot is named as the thing that ADMITS the reported failure, not as a measured cause — an
/// honest reading of a symptom this machine cannot produce. `.last { $0.isHittable }` also returns
/// nil on an empty match set, so the one message stood for two different defects; both are now
/// waited for and reported apart.
///
/// **And `isHittable` cannot see the thing this test was thought to guard.** Measured 2026-09-05 on
/// iOS 26.3.1 and 26.5, iPhone 17: with #1070's gate deliberately removed the banner renders at
/// y 455–525 *over* the Done bar at y 497–533 — and the Done still reports `isHittable == true`, is
/// tapped, and dismisses the keyboard. The whole scenario passes with the fix taken out. So the
/// occlusion is asserted where it can actually be observed: the inset must be **gone** while the
/// keyboard is up, which is `IndexingInsetState.resolve`'s first rule seen end-to-end.
///
/// Version history:
///   1.0 — #861: settles the open question the audit could not
///   1.1 — #1070: the Browse root search field — the B-1 field that shipped without any
///         dismissal affordance and trapped a reader under the raised keyboard
///   1.2 — order-independence: the Browse scenario's hittability check waits instead of
///         sampling once, the two ways it can fail are told apart, and the #1070 gate is
///         asserted directly rather than inferred from a hit test that cannot see it
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
        // Terminate rather than only dropping the reference. The popover scenario ends with the
        // Corpus Analytics sheet AND the year popover still presented; leaving that standing made
        // the next scenario's `launch()` a terminate-and-relaunch of an app frozen mid-presentation
        // instead of a cold start. Nothing in the class may depend on what came before it.
        app?.terminate()
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

    /// The Browse root's inline volume search (#1070): the field that trapped a reader.
    ///
    /// A plain `TextField` in the root List — no Cancel, a root often too short to
    /// scroll-dismiss, and the raised keyboard covers the tab bar, so before the fix there
    /// was no route off the screen at all. The fix is the #861 bar; this measures it the
    /// suite's own way — a Done count taken before focus and again after, so the toolbar's
    /// unrelated buttons cannot satisfy the assertion.
    func testDismissBarRendersOnTheBrowseRootSearchField() throws {
        let browse = app.buttons["Browse"].firstMatch
        if browse.waitForExistence(timeout: 10) { browse.tap() }

        let field = app.textFields["browse.root.searchField"].firstMatch
        guard field.waitForExistence(timeout: 10) else {
            throw XCTSkip("The Browse root search field is not on this destination")
        }

        let doneBefore = app.buttons.matching(
            NSPredicate(format: "label ==[c] 'Done'")).count

        // #1070's occluder as it stands BEFORE focus. The gate can only be measured on a run
        // where the inset has something in it to yield — on a simulator signed in to iCloud it
        // is empty and there is nothing to hide, which is a skipped check, not a passed one.
        let inset = tabShellInset
        let insetWasUpBeforeFocus = inset.exists

        field.tap()
        guard waitForKeyboard() else {
            throw XCTSkip("""
                No software keyboard appeared, so no accessory bar can exist and this test would \
                pass vacuously. Disconnect the Simulator's hardware keyboard (⇧⌘K).
                """)
        }

        // Wait for the bar rather than sampling the instant the keyboard element appears — see
        // the note on the class about the two things a single unwaited hit test conflates.
        let bar = waitForDismissBar(beyond: doneBefore)

        XCTAssertGreaterThan(bar.count, doneBefore, """
            Focusing the Browse root search field raised the keyboard without the #861 Done \
            bar — the keyboard covers the tab bar and nothing else on the root dismisses it \
            (#1070's trapped-reader shape).
            """)
        XCTAssertNotNil(bar.done, """
            The #861 Done bar rendered but never became hittable. Something is drawn over the \
            keyboard's accessory row: \(describeOverlaps(of: bar.lastFrame)).
            """)

        // #1070 itself, asserted where it is visible: while the keyboard is up the tab shell's
        // bottom inset floats onto the accessory row, so it must not be rendering at all.
        if insetWasUpBeforeFocus {
            XCTAssertTrue(waitForDisappearance(of: inset), """
                #1070: the tab shell's bottom inset is still on screen with the keyboard up. It \
                rides the accessory row the #861 Done bar renders in — see \
                IndexingInsetState.resolve, whose first rule is that the keyboard wins outright.
                """)
        } else {
            print("[#1070] the bottom inset was already empty before focus, so this run cannot "
                  + "judge whether the keyboard gate works. Sign the simulator out of iCloud to "
                  + "put the Local Only banner there.")
        }

        bar.done?.tap()
        XCTAssertTrue(waitForKeyboardGone(), "Tapping Done left the keyboard up.")
    }

    // MARK: - The dismiss bar, waited for

    /// The tab shell's bottom inset — the overlay #1070 is about.
    ///
    /// Matched on `SyncStatusBanner`'s identifier rather than its label, which is localized and
    /// composed from two further localized strings.
    private var tabShellInset: XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: "tabShell.syncBanner").firstMatch
    }

    /// Polls until a **Done** beyond `baseline` is on screen *and* hittable.
    ///
    /// Returns the largest count seen and the last hittable element, so the caller can say which
    /// of the two failed: no bar at all, or a bar nothing could reach.
    private func waitForDismissBar(beyond baseline: Int,
                                   timeout: TimeInterval = 8) -> (count: Int, done: XCUIElement?, lastFrame: CGRect) {
        let deadline = Date().addingTimeInterval(timeout)
        var bestCount = 0
        var lastFrame = CGRect.zero
        repeat {
            let dones = app.buttons.matching(
                NSPredicate(format: "label ==[c] 'Done'")).allElementsBoundByIndex
            bestCount = max(bestCount, dones.count)
            if let last = dones.last { lastFrame = last.frame }
            if dones.count > baseline, let hittable = dones.last(where: { $0.isHittable }) {
                return (bestCount, hittable, hittable.frame)
            }
            usleep(200_000)
        } while Date() < deadline
        return (bestCount, nil, lastFrame)
    }

    /// Names whatever is drawn across `rect`, so an occlusion failure says what did it.
    private func describeOverlaps(of rect: CGRect) -> String {
        guard !rect.isEmpty else { return "no Done bar was ever on screen to be covered" }
        let all = app.descendants(matching: .any)
        let names = (0..<all.count).compactMap { index -> String? in
            let element = all.element(boundBy: index)
            let frame = element.frame
            guard frame.intersects(rect), frame.height > 0, frame.height < rect.height * 12 else {
                return nil
            }
            let name = element.identifier.isEmpty ? element.label : element.identifier
            return name.isEmpty ? nil : "\(name)@\(Int(frame.minY))-\(Int(frame.maxY))"
        }
        return names.isEmpty ? "nothing intersects \(rect)" : names.joined(separator: ", ")
    }

    /// Polls until `element` is gone.
    private func waitForDisappearance(of element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if !element.exists { return true }
            usleep(200_000)
        } while Date() < deadline
        return !element.exists
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
