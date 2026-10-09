// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import XCTest

// MARK: - SummarizationPromptCopyTests

/// The first Use as Template after Settings ▸ Summarization opens gives the copy (#1590).
///
/// ## What the defect was
/// Each standard prompt's **Use as Template** is meant to open the New Prompt editor already
/// filled in: the name "Copy of <name>", the prompt's text and its fields. The pane kept the copy
/// in one `@State` and the sheet's `isPresented` Bool in another, and read the copy only inside
/// the sheet's content closure. Its body had never read it, so setting it did not re-run the
/// body, and the sheet was built from the closure made before the tap. The first use of a visit
/// opened a blank editor with **Choose a Template** over it; the second worked, because the first
/// read had registered the state.
///
/// ## Why this is the pane's FIRST action, and must stay so
/// Anything that reads the state first hides the defect. Pressing **New Prompt…** before Use as
/// Template is enough, so this test touches nothing in the pane before the button under test, and
/// each test method is a fresh launch.
///
/// ## Devices
/// One shared pane for iPhone and iPad, so one device is the guard. It never skips. Measured on
/// iPhone 17 (iOS 27.0) at the commit that fixed it: 1 test, 1 passed; and on the code before the
/// fix, 1 failed, on the name field's value (empty) and on Choose a Template being up.
///
/// Version history:
///   1.0 — 2026-10-09: #1590 — initial implementation
@MainActor
final class SummarizationPromptCopyTests: XCTestCase {

    var app: XCUIApplication!

    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    override func setUp() async throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchArguments = UITestLaunch.arguments(startingOn: .settings)
        app.launch()
    }

    override func tearDown() async throws {
        // The editor closes with Cancel, which the shared helper leaves alone by design: Cancel
        // and Done are different decisions on a sheet that edits. Nothing was typed here.
        let cancel = app.navigationBars.buttons["Cancel"].firstMatch
        if cancel.exists, cancel.isHittable { cancel.tap() }
        UITestPresentation.dismissAnyPresentation(in: app)
        app?.terminate()
        app = nil
    }

    /// Swipes up until `element` is present and hittable. A row below the fold of a `Form` is
    /// absent from the accessibility tree, so no timeout alone finds it.
    private func scrollUntil(_ element: XCUIElement, attempts: Int = 8) {
        for _ in 0..<attempts {
            if element.exists && element.isHittable { return }
            app.swipeUp(velocity: .slow)
            Thread.sleep(forTimeInterval: 0.4)
        }
    }

    func testFirstUseAsTemplateOpensTheCopy() throws {
        XCTAssertTrue(navigator.select(.settings).tapped, "Settings is reachable on every canvas measured")

        // Settings ▸ Summarization. Matched on the row's static text: the cell carries no label.
        let row = app.staticTexts.matching(NSPredicate(format: "label == 'Summarization'")).firstMatch
        scrollUntil(row)
        XCTAssertTrue(row.waitForExistence(timeout: 5),
                      "Settings lists no Summarization row. On screen: \(app.staticTexts.allElementsBoundByIndex.prefix(30).map(\.label))")
        row.tap()

        // The pane's first action. The button's label names its prompt: "Use Standard Summary as
        // a template for a new prompt".
        let use = app.buttons.matching(NSPredicate(
            format: "label BEGINSWITH 'Use ' AND label ENDSWITH ' as a template for a new prompt'")).firstMatch
        XCTAssertTrue(use.waitForExistence(timeout: 10), """
            The Summarization pane shows no Use as Template button, so the standard prompts were \
            not seeded. Buttons on screen: \(app.buttons.allElementsBoundByIndex.prefix(30).map(\.label))
            """)
        let label = use.label
        let promptName = String(label.dropFirst("Use ".count).dropLast(" as a template for a new prompt".count))
        XCTAssertFalse(promptName.isEmpty, "the button names no prompt: \(label)")
        use.tap()

        // The editor is up.
        let name = app.textFields["Prompt name"].firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 10), "the New Prompt editor did not open")
        // Give a second sheet the time it took to appear when the defect was live.
        Thread.sleep(forTimeInterval: 1.5)

        XCTAssertFalse(app.staticTexts["Choose a Template"].exists, """
            #1590: Use as Template opened the template picker, as New Prompt… does. The editor was \
            given no copy.
            """)
        XCTAssertEqual(name.value as? String, "Copy of \(promptName)", """
            #1590: the editor's name field does not hold the copy's name. An empty field reads back \
            as its placeholder, "Prompt name".
            """)
    }
}
