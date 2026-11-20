// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import XCTest

/// Creating a custom volume scope on iOS (#862), and the keyboard in its way (#861).
///
/// ## Why these two issues are driven by one scenario
/// #861's reproduction is *"creating a new volume scope and using the volume title search filter"*
/// — the same screen #862 says cannot save. The iOS scope editor is the app's one sheet that
/// carries `.searchable` **inside** a `NavigationStack`, with Save as a `.confirmationAction`
/// toolbar item, so a keyboard that will not go away and a Save that will not land are plausibly
/// the same defect seen from two sides. This scenario exists to find out rather than assume.
///
/// It reports what it observes at each step before asserting, so a failure says *where* the flow
/// broke — which of the two issues is being reproduced is the first thing to establish.
///
/// Version history:
///   1.0 — #861/#862 reproduction
@MainActor
final class CustomScopeSaveTests: XCTestCase {
    /// Resolves tab destinations across every representation, including the floating iPad bar when
    /// it has paged a tab off screen.
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }


    var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchArguments = UITestLaunch.arguments()
        app.launch()
    }

    override func tearDown() async throws {
        app = nil
    }

    /// Whether the software keyboard is on screen.
    ///
    /// `app.keyboards.count` is the standard probe. A hardware keyboard attached to the simulator
    /// suppresses the software one and would make every keyboard assertion here vacuously pass, so
    /// the scenario reports the count rather than only asserting on it.
    private var keyboardIsUp: Bool { app.keyboards.count > 0 }

    private func tapIfExists(_ element: XCUIElement, _ label: String, timeout: TimeInterval = 8) -> Bool {
        guard element.waitForExistence(timeout: timeout) else {
            print("[#862] \(label): not found")
            return false
        }
        element.tap()
        Thread.sleep(forTimeInterval: 1.0)
        return true
    }

    /// Swipes up until `element` is present and hittable.
    ///
    /// The Settings pane rows are `NavigationLink`s in a `Form`, which is a lazy collection view —
    /// a row below the fold is **absent from the accessibility tree**, not merely off screen, so
    /// no timeout alone can find it. (The first run of this scenario reported "Volume Scopes: not
    /// found" for exactly that reason.)
    private func scrollUntil(_ element: XCUIElement, attempts: Int = 8) {
        for _ in 0..<attempts {
            if element.exists && element.isHittable { return }
            app.swipeUp(velocity: .slow)
            Thread.sleep(forTimeInterval: 0.4)
        }
    }

    /// Walks Settings ▸ Volume Scopes ▸ New Scope, fills it in, and saves.
    func testCustomScopeSavesOniOS() throws {
        #if canImport(UIKit)
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone
                          || UIDevice.current.userInterfaceIdiom == .pad,
                          "iOS-only: this is about the software keyboard")
        #else
        throw XCTSkip("UIKit-only test")
        #endif

        // Settings tab. Through the navigator, because the three-candidate ladder that used to
        // live here could not reach a tab the floating iPad bar had paged off screen — and it
        // reported that as `XCTSkipUnless(opened, "Settings tab not reachable on this device")`,
        // a GREEN skip naming a device limit for a helper's gap. Settings is reachable on every
        // canvas measured, so failing to reach it is now a failure.
        XCTAssertTrue(navigator.select(.settings).tapped,
                      "Settings is reachable on every canvas measured — page 2 of the floating bar "
                          + "on a narrow iPad — so not reaching it is a defect, not a device limit")
        Thread.sleep(forTimeInterval: 1.0)

        // **Matched on the STATIC TEXT, not the cell.** A dump of this screen shows every settings
        // row as `Cell → Other → … → StaticText, label: 'iCloud Sync'` — the cell itself carries no
        // label at all, so a `cells.matching(label CONTAINS …)` query finds nothing and reads as
        // "the row is not on screen". That mistake cost this repo three investigations on the
        // Browse rows (#312); it is the same shape here.
        let scopesText = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'Volume Scopes'")).firstMatch

        // Reached through the Settings root's own pane search — the shortest route a reader would
        // take, and incidentally a second `.searchable` for #861 to observe.
        let paneSearch = app.searchFields.firstMatch
        if paneSearch.waitForExistence(timeout: 5) {
            paneSearch.tap()
            paneSearch.typeText("scope")
            Thread.sleep(forTimeInterval: 1.5)
            print("[#861] Settings pane search: keyboard up = \(keyboardIsUp)")
        }
        if !scopesText.exists { scrollUntil(scopesText) }
        guard tapIfExists(scopesText, "Volume Scopes") else {
            print("[#862] element tree:\n\(app.debugDescription)")
            XCTFail("Volume Scopes is not reachable from Settings (tree printed above)")
            return
        }

        let newScope = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'New Scope'")).firstMatch
        scrollUntil(newScope)
        guard tapIfExists(newScope, "New Scope…") else {
            XCTFail("The Volume Scopes screen offers no way to create one")
            return
        }

        // ── The name field ────────────────────────────────────────────────────────────────
        let nameField = app.textFields.matching(
            NSPredicate(format: "placeholderValue CONTAINS[c] 'Scope name'")).firstMatch
        guard nameField.waitForExistence(timeout: 8) else {
            XCTFail("The scope editor has no name field")
            return
        }
        nameField.tap()
        nameField.typeText("Keyboard Probe")
        print("[#861] after typing the NAME: keyboard up = \(keyboardIsUp)")
        // #862's decisive measurement: is the Save toolbar item present BEFORE the `.searchable`
        // filter is touched? If it exists here and vanishes later, the search chrome is eating it.
        print("[#862] Save present BEFORE the filter = \(app.buttons["Save"].firstMatch.exists)")

        // ── The filter field, which is `.searchable` INSIDE the sheet (#861's reproduction) ──
        //
        // Measure BEFORE touching it. On iOS 26 a `.searchable` field in this position renders at
        // the BOTTOM of the sheet, which is exactly where the keyboard raised by the name field
        // already is — so the question is not only "does the keyboard dismiss" but "is the filter
        // reachable at all while it is up".
        let filter = app.searchFields.firstMatch
        guard filter.waitForExistence(timeout: 5) else {
            XCTFail("The scope editor has no volume filter field")
            return
        }
        let window = app.windows.firstMatch.frame
        let filterFrame = filter.frame
        print("[#861] window=\(window)")
        print("[#861] filter field frame=\(filterFrame) hittable=\(filter.isHittable)")
        if keyboardIsUp {
            let kb = app.keyboards.firstMatch.frame
            print("[#861] keyboard frame=\(kb)")
            print("[#861] filter is UNDER the keyboard = \(filterFrame.intersects(kb))")
        }

        // The measured state is that the filter IS covered — that is the defect, and the fix does
        // not move the field. What the fix adds is a way out: a Done bar above the keyboard.
        if keyboardIsUp {
            let done = app.buttons["Done"].firstMatch
            XCTAssertTrue(done.waitForExistence(timeout: 3), """
                The keyboard is up, the volume filter is underneath it (measured above), and there \
                is no Done affordance to dismiss it. Nothing else on this screen dismisses the \
                keyboard, so the filter is unreachable and the scope cannot be completed — #861, \
                and the reason for #862.
                """)
            done.tap()
            Thread.sleep(forTimeInterval: 1.2)
            print("[#861] after tapping Done: keyboard up = \(keyboardIsUp), "
                  + "filter hittable = \(filter.isHittable)")
            print("[#862] Save present after Done = \(app.buttons["Save"].firstMatch.exists)")
            XCTAssertFalse(keyboardIsUp, "Done did not dismiss the keyboard")
            XCTAssertTrue(filter.isHittable,
                          "the keyboard went away and the filter is still not reachable")
        }

        filter.tap()
        filter.typeText("Kennedy")
        Thread.sleep(forTimeInterval: 1.5)
        print("[#861] after typing in the FILTER: keyboard up = \(keyboardIsUp)")

        // The documented complaint: submitting does not put the keyboard away.
        app.typeText("\n")
        Thread.sleep(forTimeInterval: 1.5)
        print("[#861] after SUBMITTING the filter: keyboard up = \(keyboardIsUp)")

        // ── Is the primary action reachable with the keyboard up? ────────────────────────
        let save = app.buttons["Save"].firstMatch
        print("[#862] every button on screen now: "
              + (0..<app.buttons.count).map { app.buttons.element(boundBy: $0).label }
                  .filter { !$0.isEmpty }.joined(separator: " | "))
        print("[#862] Save exists=\(save.exists) hittable=\(save.exists ? "\(save.isHittable)" : "n/a") "
              + "frame=\(save.exists ? "\(save.frame)" : "n/a")")
        if keyboardIsUp {
            print("[#862] keyboard frame=\(app.keyboards.firstMatch.frame) window=\(app.windows.firstMatch.frame)")
        }

        // A scope needs at least one volume before Save is enabled. Target a real volume row by
        // label — the filter above narrowed the list to Kennedy-Khrushchev, and picking "whatever
        // cell is at index 2" selects section chrome instead, which is how an earlier run reached
        // Save with an empty selection and blamed the app.
        let volumeRow = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Kennedy-Khrushchev'")).firstMatch
        if volumeRow.waitForExistence(timeout: 5) {
            volumeRow.tap()
            Thread.sleep(forTimeInterval: 0.8)
        } else {
            print("[#862] no volume row matched the filter — selection stays empty")
        }
        print("[#862] after selecting a volume: Save enabled=\(save.exists ? "\(save.isEnabled)" : "n/a")")

        guard save.exists else {
            XCTFail("The scope editor offers no Save control at all")
            return
        }
        XCTAssertTrue(save.isEnabled, """
            Save is disabled after naming the scope and selecting a volume. `canSave` requires a \
            non-blank name, a non-empty selection, and `pendingPersonUnions == 0` — so one of the \
            three is not what the screen appears to show (#862).
            """)
        save.tap()
        Thread.sleep(forTimeInterval: 2.0)

        // ── Did it save? ─────────────────────────────────────────────────────────────────
        // The list sorts by name and we scrolled down to reach "New Scope…", so scroll back up
        // before looking — a lazy List omits off-screen rows from the tree entirely, and reading
        // that as "the scope did not save" is the mistake this scenario has already made twice.
        // A scope row is `Button { … } label: { scopeRow(scope) }`, and SwiftUI folds a Button's
        // label into the BUTTON's own accessibility label — the inner Text is not published as a
        // separate staticText. Matching only `staticTexts` therefore reported "the write did not
        // persist" for a row that was on screen, which is the whole of #862's unexplained
        // residual. Check both classes; the print below records which one carried it.
        let savedButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Keyboard Probe'")).firstMatch
        let savedText = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'Keyboard Probe'")).firstMatch
        var rowPresent: Bool { savedButton.exists || savedText.exists }
        for _ in 0..<6 where !rowPresent {
            app.swipeDown(velocity: .slow)
            Thread.sleep(forTimeInterval: 0.4)
        }
        print("[#862] after Save: editor dismissed = \(!nameField.exists), "
              + "row as button = \(savedButton.exists), row as staticText = \(savedText.exists)")
        // THE DECIDING SIGNAL. `scopes.isEmpty` renders this sentence instead of the ForEach, so
        // its presence says the @Query returned nothing — which separates "the row is there and
        // the selector missed it" from "the write is not in the store". Measured 2026-08-17: the
        // empty state IS on screen after a Save that dismissed the editor, so #862's residual is a
        // real defect and not the harness artefact #928 suspected.
        let emptyState = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH[c] 'Create a named set of volumes'")).firstMatch
        print("[#862] empty state on screen = \(emptyState.exists)")
        print("[#862] buttons on the list screen: "
              + (0..<app.buttons.count).map { app.buttons.element(boundBy: $0).label }
                  .filter { !$0.isEmpty }.joined(separator: " | "))
        XCTAssertTrue(rowPresent, """
            The scope was named, given a volume, and saved — and it is in neither the button nor \
            the staticText tree (#862). Read the two lines above before theorising: if the empty \
            state is on screen the @Query returned nothing and the write never reached the store; \
            if it is absent the row exists and this selector is what is wrong. NOTE the app's own \
            print() does NOT reach this log — the app is a separate process — so nothing here can \
            tell you whether save() threw or whether isDraft was true.
            """)
    }
}

// MARK: - VolumeScopeSwipeDeleteTests

/// A swipe that deletes a volume scope keeps the scope listed while its question is up, and after the question is
/// closed unanswered: the measurement behind leaving three swipes as they are (R6a, F10's sweep).
///
/// F10's trap is a destructive swipe button whose row carries the question it raises: the role animates the row out as
/// if deleted, and the row's dialog goes with it (`CollectionListSwipeDeleteTests`). Volume Scopes' swipe keeps
/// `role: .destructive`, but its question hangs on the list, not the row, and so do the Archives Visits list's and the
/// priority tiers'. Measured on the code as it was (iPhone 17, iOS 27.2): the question was up two seconds after the
/// swipe's Delete, the scope listed throughout, and still listed once the question was closed unanswered. So this
/// passes on the code before R6a too; it fails if the question moves onto the row while the swipe keeps its role.
///
/// **Run it on iPhone 17 and iPad Pro 13-inch (M5)**, `OS=27.2`, allowing 600 s.
///
/// Version history:
///   1.0 — R6a (F10's sweep): initial implementation
@MainActor
final class VolumeScopeSwipeDeleteTests: XCTestCase {

    /// `UITestScopeSeeder.scopeName`.
    private static let scope = "UI Test Scope"
    private static let title = "Delete Scope?"
    private static let patience: TimeInterval = 30

    var app: XCUIApplication!

    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    override func tearDown() async throws {
        UITestPresentation.dismissAnyPresentation(in: app)
        app?.terminate()
        app = nil
        try await super.tearDown()
    }

    func testAScopesSwipeKeepsItsRowUntilAnswered() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_SCOPE"] = "1"
        app.launchArguments = UITestLaunch.arguments(startingOn: .settings)
        app.launch()
        openVolumeScopes()
        let row = app.staticTexts[Self.scope].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: Self.patience), "The seeded scope is not listed")

        // From here each state is read before any is asserted, so a failure reports all four.
        continueAfterFailure = true
        swipeDelete(row)
        let question = app.staticTexts[Self.title].firstMatch
        let asked = question.waitForExistence(timeout: Self.patience)
        Thread.sleep(forTimeInterval: 2)
        attachScreenshot("Two seconds after the swipe's Delete")
        let stillAsking = question.exists
        let listedWhileAsking = row.exists
        if stillAsking { closeTheQuestion() }
        let listedAfterClosing = row.waitForExistence(timeout: 5)
        attachScreenshot("After the question closed unanswered")
        print("[F10 sweep] asked=\(asked) stillAsking=\(stillAsking) listedWhileAsking=\(listedWhileAsking) "
              + "listedAfterClosing=\(listedAfterClosing)")
        XCTAssertTrue(asked, "The swipe's Delete did not ask")
        XCTAssertTrue(stillAsking, "The question closed by itself within two seconds, unanswered")
        XCTAssertTrue(listedWhileAsking, """
            The scope left the list while its question was still up: the destructive swipe button animated \
            the row out as if it were already deleted.
            """)
        XCTAssertTrue(listedAfterClosing, """
            The question closed unanswered and the scope is no longer listed, though nothing deleted it: \
            the destructive swipe button took the row.
            """)
    }

    // MARK: - Steps

    /// Settings ▸ Volume Scopes. The Settings root is a lazy list, so a row below the fold is absent from the tree
    /// until it is scrolled to (`CustomScopeSaveTests.scrollUntil`).
    private func openVolumeScopes() {
        XCTAssertTrue(navigator.select(.settings, resolveTimeout: 15).tapped, "Could not open the Settings tab")
        let link = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Volume Scopes'")).firstMatch
        _ = link.waitForExistence(timeout: 5)
        for _ in 0..<10 where !(link.exists && link.isHittable) {
            app.swipeUp(velocity: .slow)
            Thread.sleep(forTimeInterval: 0.4)
        }
        if !link.exists {
            attachScreenshot("Settings, with no Volume Scopes row found")
            print("[F10 sweep] tree:\n\(app.debugDescription)")
        }
        XCTAssertTrue(link.exists, "Volume Scopes is not reachable from Settings (screenshot and tree above)")
        link.tap()
    }

    /// Swipes the row left, as a reader does, and taps the Delete it reveals.
    private func swipeDelete(_ row: XCUIElement) {
        row.swipeLeft()
        let reveal = app.buttons["Delete"].firstMatch
        XCTAssertTrue(reveal.waitForExistence(timeout: Self.patience), "The swipe revealed no Delete")
        reveal.tap()
    }

    /// Closes the question without deleting: an action sheet's Cancel, or a tap outside a popover.
    private func closeTheQuestion() {
        let cancel = app.sheets.buttons["Cancel"].firstMatch
        if cancel.exists {
            cancel.tap()
        } else {
            let regions = app.otherElements.matching(identifier: "PopoverDismissRegion")
            XCTAssertGreaterThan(regions.count, 0, "The question has no Cancel and no popover to tap outside")
            regions.element(boundBy: regions.count - 1)
                .coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.97)).tap()
        }
        XCTAssertTrue(app.staticTexts[Self.title].firstMatch.waitForNonExistence(timeout: Self.patience),
                      "The question did not close")
    }

    private func attachScreenshot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
