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
/// again when it is reopened from the Collections list. And a new collection is discarded, or named "Untitled
/// Collection", only when its editor is dismissed — not when a screen is pushed over it (#1359 review).
///
/// Before #1359 the title came from a flag set once when the editor opened, so a new collection read **New
/// Collection** for as long as its editor stayed open, however it was named, and an existing one always read **Edit
/// Collection**.
///
/// **Run it on an iPhone AND an iPad.** The two layouts reach the name field through different screens — the iPad's
/// ⚙ Collection toolbar button opens a settings SHEET, the iPhone's Collection settings row PUSHES a screen — so one
/// destination proves one route. Each test takes the route the editor actually drew (whichever of the two controls is
/// on screen), not the device idiom's, because the editor picks its layout by size class. The test that leaves
/// Collection settings straight for the list SKIPS on the sheet route: only the pushed screen covers the editor, and
/// that is the state it needs. Expect 3 tests with 0 skipped on an iPhone, and 3 with 1 skipped on an iPad.
///
/// **A first visit to settings is not enough to see the push-over defect.** Measured on iPhone 17 (iOS 26.5) before
/// the review fix: the editor's `onDisappear` fired when Collection settings was pushed over it and wrote "Untitled
/// Collection" to a new collection with content — but a covered editor is not updated, so the name field followed
/// that write only once the editor was back on screen. The FIRST visit showed an empty field even on the defective
/// build; the bar on return and the SECOND visit showed the default name. For an untouched collection the same
/// `onDisappear` deleted it, and it survived only because the editor inserts its collection again when it reappears.
///
/// **What this suite cannot claim: an edit made on the pushed settings screen is saved only when the editor comes
/// back.** The screen's fields bind to the editor's own state, and the editor's `onChange` does not run while it is
/// covered — measured, the typed name reached the model 14 ms before the editor's `onAppear`, seconds after the
/// typing. So a name typed there and left by tapping the Collections tab never reaches the model, before the review
/// fix and after it; no test here asserts that it does.
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
/// Animations are off (`FRUS_UI_TEST_DISABLE_ANIMATIONS=1`): every assertion reads a screen at rest, and no
/// assertion is about a transition — see CLAUDE.md on the iOS 27 idle stall. **The suite closes what it opens** in
/// `tearDown` (`UITestPresentation.dismissAnyPresentation`), because the iPad route opens a sheet and a presentation
/// left standing is what the next launch restores (#1279).
///
/// Version history:
///   1.0 — #1359: initial implementation
///   1.1 — #1359 review: the push-over tests; each test takes the route the layout on screen offers, not the idiom's
@MainActor
final class CollectionEditorTitleTests: XCTestCase {

    /// The name the test gives its collection.
    private static let name = "Cuban Missile Crisis"
    /// The editor's title before the collection has a name.
    private static let newTitle = "New Collection"
    /// The default a kept, unnamed new collection is given when its editor is dismissed.
    private static let untitled = "Untitled Collection"
    /// The Collections tab's root navigation bar.
    private static let listTitle = "Collections"
    /// The Collections list's empty state. The UI-test store starts empty, so it shows until a test keeps a collection.
    private static let emptyListTitle = "No Collections"
    /// The settings screen's (iPhone) and sheet's (iPad) navigation title.
    private static let settingsTitle = "Collection settings"
    /// The compact editor's Add menu, by its accessibility label; the regular-width one reads "Add".
    private static let compactAddMenu =
        "Add documents, a section heading, a note block, highlighted passages, or an apparatus block"

    /// How the layout on screen reaches the name field.
    private enum SettingsRoute {
        /// The ⚙ Collection toolbar button opens a settings sheet (regular width).
        case sheet
        /// The Collection settings row pushes a screen over the editor (compact width).
        case pushed
    }

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
        createCollection()

        let route = openSettings()
        typeName()
        closeSettings(route)
        XCTAssertTrue(app.navigationBars[Self.name].waitForExistence(timeout: 5),
                      "After naming it, the editor is not titled \"\(Self.name)\". Bars: \(barTitles())")

        backOut(from: Self.name)
        let row = listRow(Self.name)
        XCTAssertTrue(row.waitForExistence(timeout: 5),
                      "The Collections list shows no row named \"\(Self.name)\" to reopen")
        row.tap()
        XCTAssertTrue(app.navigationBars[Self.name].waitForExistence(timeout: 10),
                      "The collection reopened from the list is not titled \"\(Self.name)\". Bars: \(barTitles())")
        backOut(from: Self.name)
    }

    /// A new collection with content, its settings opened before it has a name: a visit to the settings is not the
    /// editor going away, so nothing names the collection "Untitled Collection" — not the bar on return, not the
    /// name field on a second visit — and the name typed there is the name the collection keeps.
    func testContentAloneDoesNotNameANewCollection() throws {
        launch()
        createCollection()
        addSectionHeading()

        var route = openSettings()
        assertNameFieldIsEmpty("on the first visit to Collection settings")
        closeSettings(route)
        XCTAssertTrue(app.navigationBars[Self.newTitle].waitForExistence(timeout: 5), """
            Back from Collection settings, the unnamed collection's editor is not titled "\(Self.newTitle)". Bars: \
            \(barTitles()). The editor took the settings screen pushed over it for its own dismissal and named the \
            collection "\(Self.untitled)".
            """)

        route = openSettings()
        assertNameFieldIsEmpty("on the second visit to Collection settings")
        typeName()
        closeSettings(route)
        XCTAssertTrue(app.navigationBars[Self.name].waitForExistence(timeout: 5),
                      "After naming it, the editor is not titled \"\(Self.name)\". Bars: \(barTitles())")
        backOut(from: Self.name)
        XCTAssertTrue(listRow(Self.name).waitForExistence(timeout: 5),
                      "The Collections list shows no row named \"\(Self.name)\". Rows: \(listRowLabels())")
    }

    /// An untouched new collection whose pushed settings screen is left straight for the list is discarded: the
    /// editor IS dismissed here, though no view event says so. The guard for `NewCollectionSession`'s `deinit`, the
    /// only signal this route sends.
    func testAnUntouchedCollectionLeftFromItsSettingsIsDiscarded() throws {
        launch()
        createCollection()
        try openPushedSettings()
        returnToTheListByTab()
        // Positive, not merely "no rows found": the list's own empty state is showing.
        XCTAssertTrue(app.staticTexts[Self.emptyListTitle].waitForExistence(timeout: 5), """
            An untouched new collection outlived its editor: the list does not read "\(Self.emptyListTitle)". Rows: \
            \(listRowLabels()). Leaving Collection settings for the list dismissed the editor without ending its \
            new-collection session.
            """)
        XCTAssertTrue(listRowLabels().isEmpty, "The Collections list shows rows: \(listRowLabels())")
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

    /// Opens a new collection's editor from the Collections list.
    private func createCollection() {
        let create = app.buttons["Create new collection"].firstMatch
        XCTAssertTrue(create.waitForExistence(timeout: 10),
                      "The Collections tab offers no New Collection button. Buttons: \(visibleButtonLabels())")
        create.tap()
        XCTAssertTrue(app.navigationBars[Self.newTitle].waitForExistence(timeout: 10),
                      "The new collection's editor did not open titled \"\(Self.newTitle)\". Bars: \(barTitles())")
    }

    /// Adds a section heading, so the collection has content and is kept when its editor goes.
    private func addSectionHeading() {
        let compact = app.buttons[Self.compactAddMenu].firstMatch
        let regular = app.buttons["Add"].firstMatch
        XCTAssertTrue(waitUntil { compact.exists || regular.exists },
                      "The editor has no Add menu. Buttons: \(visibleButtonLabels())")
        (compact.exists ? compact : regular).tap()
        let heading = app.buttons["Add Section Heading"].firstMatch
        XCTAssertTrue(heading.waitForExistence(timeout: 5),
                      "The Add menu has no Add Section Heading. Buttons: \(visibleButtonLabels())")
        heading.tap()
        XCTAssertTrue(app.buttons["Section defaults"].firstMatch.waitForExistence(timeout: 5),
                      "Add Section Heading added no heading row. Buttons: \(visibleButtonLabels())")
    }

    /// Opens Collection settings through whichever control the layout on screen drew, and waits for it.
    private func openSettings() -> SettingsRoute {
        let (button, row) = settingsControls()
        let route: SettingsRoute = button.exists ? .sheet : .pushed
        (route == .sheet ? button : row).tap()
        XCTAssertTrue(app.navigationBars[Self.settingsTitle].waitForExistence(timeout: 5),
                      "Collection settings did not open (\(route)). Bars: \(barTitles())")
        return route
    }

    /// Opens Collection settings as a screen PUSHED over the editor, or skips: a settings sheet covers nothing.
    private func openPushedSettings() throws {
        let (button, row) = settingsControls()
        try XCTSkipIf(button.exists, """
            This layout opens Collection settings as a sheet, which does not cover the editor; the pushed settings \
            screen this test needs belongs to the compact-width layout. Run it on an iPhone.
            """)
        row.tap()
        XCTAssertTrue(app.navigationBars[Self.settingsTitle].waitForExistence(timeout: 5),
                      "The Collection settings row did not push its screen. Bars: \(barTitles())")
    }

    /// The ⚙ Collection toolbar button and the Collection settings row, once either is on screen.
    private func settingsControls() -> (button: XCUIElement, row: XCUIElement) {
        let button = element("collection.editor.settings.button")
        let row = element("collection.editor.settings.row")
        XCTAssertTrue(waitUntil { button.exists || row.exists }, """
            The editor shows neither the ⚙ Collection button nor the Collection settings row. Buttons: \
            \(visibleButtonLabels())
            """)
        return (button, row)
    }

    /// Closes Collection settings the way `route` opened it: the sheet's Done, or the pushed screen's Back.
    private func closeSettings(_ route: SettingsRoute) {
        switch route {
        case .sheet:
            let done = app.navigationBars[Self.settingsTitle].buttons["Done"]
            XCTAssertTrue(done.waitForExistence(timeout: 5), "The Collection settings sheet has no navigation-bar Done")
            done.tap()
            waitForAbsence(of: app.navigationBars[Self.settingsTitle], "The Collection settings sheet did not close")
        case .pushed:
            backOut(from: Self.settingsTitle)
        }
    }

    /// Taps the Collections tab from a screen pushed over the editor, which takes the whole stack back to the list.
    private func returnToTheListByTab() {
        XCTAssertTrue(navigator.select(.collections, resolveTimeout: 10).tapped,
                      "Could not tap the Collections tab from Collection settings")
        XCTAssertTrue(app.navigationBars[Self.listTitle].waitForExistence(timeout: 5),
                      "Tapping the Collections tab did not return to the list. Bars: \(barTitles())")
    }

    private func typeName() {
        let field = element("collection.editor.name.field")
        XCTAssertTrue(field.waitForExistence(timeout: 5), "The settings show no collection-name field")
        field.tap()
        field.typeText(Self.name)
    }

    /// The name field shows no text of its own: its value is empty, or is the field's placeholder.
    private func assertNameFieldIsEmpty(_ when: String) {
        let field = element("collection.editor.name.field")
        XCTAssertTrue(field.waitForExistence(timeout: 5), "The settings show no collection-name field")
        let value = (field.value as? String) ?? ""
        XCTAssertTrue(value.isEmpty || value == field.placeholderValue, """
            The unnamed collection's name field reads "\(value)" \(when); it should be empty, showing its \
            placeholder "\(field.placeholderValue ?? "")".
            """)
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

    /// The Collections list's row whose name is `name`.
    private func listRow(_ name: String) -> XCUIElement {
        app.collectionViews.staticTexts[name].firstMatch
    }

    /// The text of the Collections list's rows. The UI-test store starts empty, so every row is one a test made. (A
    /// row's CELL carries no label of its own — the text is its children's — so reading cells would find nothing.)
    private func listRowLabels() -> [String] {
        app.collectionViews.staticTexts.allElementsBoundByIndex.map(\.label).filter { !$0.isEmpty }
    }

    private func waitForAbsence(of element: XCUIElement, _ message: String) {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed, message)
    }

    /// Polls `condition` until it holds or `timeout` passes, and reports whether it held.
    private func waitUntil(_ timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return condition()
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
