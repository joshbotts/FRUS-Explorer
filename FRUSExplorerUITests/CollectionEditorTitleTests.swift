// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import XCTest

// MARK: - CollectionEditorTitleTests

/// The collection editor's navigation bar reads the collection's name (#1359): after a new collection is named, and
/// again when it is reopened from the Collections list.
///
/// Before #1359 the title came from a flag set once when the editor opened, so a new collection read **New
/// Collection** for as long as its editor stayed open, however it was named, and an existing one always read **Edit
/// Collection**.
///
/// **Run it on an iPhone AND an iPad.** The two layouts reach the name field through different screens — the iPad's
/// ⚙ Collection toolbar button opens a settings SHEET, the iPhone's Collection settings row PUSHES a screen — so one
/// destination proves one route. Neither branch skips: each idiom runs its own route to the same assertions.
///
/// **The name has spaces in it, but this suite does not guard the whitespace rule.** The editor saves the name
/// trimmed and follows the saved name back into its field. Measured on iPhone 17 (iOS 26.5), a mutant that compared
/// the two untrimmed PASSED this suite: typing sends one character at a time, a trailing space does not change the
/// trimmed name, so no save comes back while the field ends in one. The case the rule exists for — a pasted name, or an
/// edit earlier in a name that ends in a space — is pinned by `CollectionEditorNamingTests`, which fails on that
/// mutant.
///
/// Controls are found by accessibility identifier (`collection.editor.settings.button`, `…settings.row`,
/// `…name.field`), because iOS 27 reorders the XCUI tree and a label query can match a covered element.
///
/// Animations are off (`FRUS_UI_TEST_DISABLE_ANIMATIONS=1`): every assertion reads a navigation bar at rest, and no
/// assertion is about a transition — see CLAUDE.md on the iOS 27 idle stall. **The suite closes what it opens** in
/// `tearDown` (`UITestPresentation.dismissAnyPresentation`), because the iPad route opens a sheet and a presentation
/// left standing is what the next launch restores (#1279).
///
/// Version history:
///   1.0 — #1359: initial implementation
@MainActor
final class CollectionEditorTitleTests: XCTestCase {

    /// The name the test gives its collection.
    private static let name = "Cuban Missile Crisis"
    /// The editor's title before the collection has a name.
    private static let newTitle = "New Collection"
    /// The Collections tab's root navigation bar.
    private static let listTitle = "Collections"
    /// The settings screen's (iPhone) and sheet's (iPad) navigation title.
    private static let settingsTitle = "Collection settings"

    var app: XCUIApplication!

    /// Read through a closure: each test mints a fresh `XCUIApplication`, and a stored reference would leave the
    /// navigator driving a dead process.
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    override func tearDown() async throws {
        UITestPresentation.dismissAnyPresentation(in: app)
        app?.terminate()
        app = nil
        try await super.tearDown()
    }

    /// Create, name, return — the bar reads the name; back out, reopen from the list — it still does.
    func testTheEditorIsTitledWithTheCollectionsName() throws {
        launch()

        let create = app.buttons["Create new collection"].firstMatch
        XCTAssertTrue(create.waitForExistence(timeout: 10),
                      "The Collections tab offers no New Collection button. Buttons: \(visibleButtonLabels())")
        create.tap()
        XCTAssertTrue(app.navigationBars[Self.newTitle].waitForExistence(timeout: 10),
                      "The new collection's editor did not open titled \"\(Self.newTitle)\". Bars: \(barTitles())")

        if UIDevice.current.userInterfaceIdiom == .pad {
            nameThroughTheSettingsSheet()
        } else {
            nameThroughTheSettingsScreen()
        }
        XCTAssertTrue(app.navigationBars[Self.name].waitForExistence(timeout: 5),
                      "After naming it, the editor is not titled \"\(Self.name)\". Bars: \(barTitles())")

        backOut(from: Self.name)
        let row = app.collectionViews.staticTexts[Self.name].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5),
                      "The Collections list shows no row named \"\(Self.name)\" to reopen")
        row.tap()
        XCTAssertTrue(app.navigationBars[Self.name].waitForExistence(timeout: 10),
                      "The collection reopened from the list is not titled \"\(Self.name)\". Bars: \(barTitles())")
        backOut(from: Self.name)
    }

    // MARK: - Steps

    private func launch() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_DISABLE_ANIMATIONS"] = "1"
        app.launchArguments = UITestLaunch.arguments(startingOn: .collections)
        app.launch()
        // Asserted, not attempted (#1279): every step below starts on the Collections list.
        XCTAssertTrue(navigator.select(.collections, resolveTimeout: 15).tapped,
                      "Could not open the Collections tab, so this suite would read another screen")
        XCTAssertTrue(app.navigationBars[Self.listTitle].waitForExistence(timeout: 10),
                      "The Collections list is not showing. Bars: \(barTitles())")
    }

    /// iPad: ⚙ Collection opens the settings sheet, whose first field is the name; Done closes it.
    private func nameThroughTheSettingsSheet() {
        let settings = element("collection.editor.settings.button")
        XCTAssertTrue(settings.waitForExistence(timeout: 5),
                      "The iPad editor's toolbar has no ⚙ Collection button. Buttons: \(visibleButtonLabels())")
        settings.tap()
        XCTAssertTrue(app.navigationBars[Self.settingsTitle].waitForExistence(timeout: 5),
                      "⚙ Collection did not open the Collection settings sheet. Bars: \(barTitles())")
        typeName()
        let done = app.navigationBars[Self.settingsTitle].buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5), "The Collection settings sheet has no navigation-bar Done")
        done.tap()
        waitForAbsence(of: app.navigationBars[Self.settingsTitle], "The Collection settings sheet did not close")
    }

    /// iPhone: the Collection settings row pushes the settings screen, whose first field is the name; Back returns.
    private func nameThroughTheSettingsScreen() {
        let row = element("collection.editor.settings.row")
        XCTAssertTrue(row.waitForExistence(timeout: 5),
                      "The iPhone editor has no Collection settings row. Buttons: \(visibleButtonLabels())")
        row.tap()
        XCTAssertTrue(app.navigationBars[Self.settingsTitle].waitForExistence(timeout: 5),
                      "The Collection settings row did not push its screen. Bars: \(barTitles())")
        typeName()
        backOut(from: Self.settingsTitle)
    }

    private func typeName() {
        let field = element("collection.editor.name.field")
        XCTAssertTrue(field.waitForExistence(timeout: 5), "The settings show no collection-name field")
        field.tap()
        field.typeText(Self.name)
    }

    /// Taps the Back button in the bar titled `title`, and waits for that bar to go.
    private func backOut(from title: String) {
        let back = app.navigationBars[title].buttons["BackButton"]
        XCTAssertTrue(back.waitForExistence(timeout: 5),
                      "The bar titled \"\(title)\" has no Back button. Bars: \(barTitles())")
        back.tap()
        waitForAbsence(of: app.navigationBars[title], "Back did not leave the screen titled \"\(title)\"")
    }

    // MARK: - Queries

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func waitForAbsence(of element: XCUIElement, _ message: String) {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed, message)
    }

    /// Failure-message aid: the navigation bars on screen, by title.
    private func barTitles() -> String {
        app.navigationBars.allElementsBoundByIndex.map(\.identifier).joined(separator: " | ")
    }

    /// Failure-message aid: what a query could have matched instead.
    private func visibleButtonLabels() -> String {
        app.buttons.allElementsBoundByIndex
            .prefix(30)
            .map(\.label)
            .filter { !$0.isEmpty }
            .joined(separator: " | ")
    }
}
