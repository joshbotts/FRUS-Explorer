// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Vision
import XCTest

// MARK: - CollectionEditorTitleTests

/// The collection editor's navigation bar reads the collection's name (#1359): after a new collection is named, and
/// again when it is reopened from the Collections list. And a new collection is discarded, or named "Untitled
/// Collection", only when its editor is dismissed — not when a screen is pushed over it (#1359 review). What the reader
/// types in Collection settings is kept however they leave it (#1415), and what a heading's Section defaults sheet
/// writes is shown by the editor and survives its next edit (#1413).
///
/// Before #1359 the title came from a flag set once when the editor opened, so a new collection read **New
/// Collection** for as long as its editor stayed open, however it was named, and an existing one always read **Edit
/// Collection**.
///
/// **Run it on an iPhone AND an iPad.** The two layouts reach the name field through different screens — the iPad's
/// ⚙ Collection toolbar button opens a settings SHEET, the iPhone's Collection settings row PUSHES a screen — so one
/// destination proves one route. Each test takes the route the editor actually drew (whichever of the two controls is
/// on screen), not the device idiom's, because the editor picks its layout by size class. The three tests that leave
/// Collection settings straight for the list SKIP on the sheet route: only the pushed screen covers the editor, and
/// that is the state they need. Expect 8 tests with 0 skipped on an iPhone, and 8 with 3 skipped on an iPad.
///
/// **Only the iPhone run guards the push-over and the Collections-tab exit.** On an iPad
/// `testContentAloneDoesNotNameANewCollection` runs rather than skipping, but by reading it cannot fail there on the
/// old rule: the settings SHEET covers nothing, and presenting a sheet fires no `onDisappear`, so nothing is mistaken
/// for the editor's dismissal. The iPad's own push-over is a document opened in place, and the iPhone's per-entry
/// inspector is another; no test here drives either. So an iPad pass says the title follows the name through the
/// sheet, and nothing about the push-over.
///
/// **A first visit to settings is not enough to see the push-over defect.** Measured on iPhone 17 (iOS 26.5) before
/// the review fix: the editor's `onDisappear` fired when Collection settings was pushed over it and wrote "Untitled
/// Collection" to a new collection with content — but a covered editor is not updated, so the name field followed
/// that write only once the editor was back on screen. The FIRST visit showed an empty field even on the defective
/// build; the bar on return and the SECOND visit showed the default name. For an untouched collection the same
/// `onDisappear` deleted it, and it survived only because the editor inserts its collection again when it reappears.
///
/// **An edit on the pushed settings screen reaches the collection as it is typed (#1415).** Before, the screen's
/// fields bound to the editor's own state and were saved from the editor's `onChange`, which does not run while the
/// editor is covered — measured at #1359, the typed name reached the model 14 ms before the editor's `onAppear`,
/// seconds after the typing. So a name typed there and left by tapping the Collections tab never reached the model,
/// and a new collection given only such edits was discarded as untouched.
/// `testANameTypedInSettingsSurvivesTheCollectionsTab` (the test #1359's review wrote and dropped, because it failed
/// before and after that change) and `testFieldsSetInSettingsSurviveTheCollectionsTab` now pin it; both failed on the
/// pre-#1415 editor on iPhone 17 (iOS 26.5). Neither can see an app kill — the UI-test store lives in memory — so the save made with each edit is
/// pinned by `CollectionEditorNamingTests` instead.
///
/// **A heading's Section defaults sheet writes the collection itself (#1413)** — its description, subtitle, author
/// line and front-matter toggles (`CollectionAttributesRows`). Before, the editor went on showing the values it opened
/// with, and its next save wrote every one of them back: a rename, or even the editor following a toggle flipped in
/// that same sheet. The three Section defaults tests run on both idioms, and all three failed on the pre-#1413 editor
/// on iPhone 17 and on iPad Pro 13-inch (M5).
///
/// **The name has spaces in it, but this suite does not guard the whitespace rule.** The editor saves the name
/// trimmed and follows the saved name back into its field. Measured on iPhone 17 (iOS 26.5), a mutant that compared
/// the two untrimmed PASSED this suite: typing sends one character at a time, a trailing space does not change the
/// trimmed name, so no save comes back while the field ends in one. The case the rule exists for — a pasted name, or an
/// edit earlier in a name that ends in a space — is pinned by `CollectionEditorNamingTests`, which fails on that
/// mutant.
///
/// Controls are found by accessibility identifier (`collection.editor.settings.button`, `…settings.row`,
/// `…name.field`, and the `collection.editor.…` and `collection.attributes.…` fields and toggles), because iOS 27
/// reorders the XCUI tree and a label query can match a covered element.
///
/// Animations are off (`FRUS_UI_TEST_DISABLE_ANIMATIONS=1`): every assertion reads a screen at rest, and no
/// assertion is about a transition — see CLAUDE.md on the iOS 27 idle stall. **The suite closes what it opens** in
/// `tearDown` (`UITestPresentation.dismissAnyPresentation`), because the iPad route opens a sheet and a presentation
/// left standing is what the next launch restores (#1279).
///
/// Version history:
///   1.0 — #1359: initial implementation
///   1.1 — #1359 review: the push-over tests; each test takes the route the layout on screen offers, not the idiom's
///   1.2 — #1359 review, round 2: says which destination guards the push-over (the iPhone's)
///   1.3 — #1415 / #1413: edits in Collection settings survive the Collections tab; Section defaults' description,
///         subtitle and toggle survive the editor and show in it
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
    /// The description the tests give a collection — its note, which Collection settings and a heading's Section
    /// defaults both edit.
    private static let note = "A working note"
    /// The title-page subtitle the tests give a collection.
    private static let subtitle = "Draft"

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

    // MARK: - What the settings keep (#1415)

    /// A name typed on the pushed Collection settings screen reaches the collection as it is typed, so leaving the
    /// screen by the Collections tab — which takes the stack back to the list without the editor ever reappearing —
    /// keeps the collection, under that name (#1415). This is the test #1359's review wrote and dropped because it
    /// failed before and after that change.
    func testANameTypedInSettingsSurvivesTheCollectionsTab() throws {
        launch()
        createCollection()
        try openPushedSettings()
        typeName()
        dismissKeyboard()
        returnToTheListByTab()
        let row = listRow(Self.name)
        XCTAssertTrue(row.waitForExistence(timeout: 5), """
            The name typed in Collection settings was lost when the Collections tab took the stack back to the list: \
            the list has no row named "\(Self.name)". Rows: \(listRowLabels()). The editor under the settings screen \
            saved the name only when it came back on screen, and it never did.
            """)
        row.tap()
        XCTAssertTrue(app.navigationBars[Self.name].waitForExistence(timeout: 10),
                      "The collection reopened from the list is not titled \"\(Self.name)\". Bars: \(barTitles())")
        backOut(from: Self.name)
    }

    /// The rest of the screen, the same way: a description, a subtitle and a front-matter toggle set on the pushed
    /// settings screen of a collection that has no name are on the collection after the Collections tab takes the
    /// stack back to the list — so the collection is kept, named "Untitled Collection" when its editor went, and the
    /// three read back when it is reopened (#1415).
    func testFieldsSetInSettingsSurviveTheCollectionsTab() throws {
        launch()
        createCollection()
        try openPushedSettings()
        let addNote = element("collection.editor.note.add")
        XCTAssertTrue(addNote.waitForExistence(timeout: 5), "Collection settings offers no Add a note")
        addNote.tap()
        type(Self.note, into: "collection.editor.note.field", what: "note")
        type(Self.subtitle, into: "collection.editor.subtitle.field", what: "subtitle")
        dismissKeyboard()
        turnOn("collection.editor.colophon.toggle", what: "Include colophon")
        returnToTheListByTab()

        let row = listRow(Self.untitled)
        XCTAssertTrue(row.waitForExistence(timeout: 5), """
            The collection given a note, a subtitle and a colophon in Collection settings was lost when the \
            Collections tab took the stack back to the list: the list has no "\(Self.untitled)" row. Rows: \
            \(listRowLabels()).
            """)
        row.tap()
        XCTAssertTrue(app.navigationBars[Self.untitled].waitForExistence(timeout: 10),
                      "The kept collection's editor is not titled \"\(Self.untitled)\". Bars: \(barTitles())")
        try openPushedSettings()
        XCTAssertEqual(value(of: "collection.editor.note.field"), Self.note,
                       "The reopened collection's note does not read what was typed in Collection settings")
        XCTAssertEqual(value(of: "collection.editor.subtitle.field"), Self.subtitle,
                       "The reopened collection's subtitle does not read what was typed in Collection settings")
        let colophon = reveal("collection.editor.colophon.toggle", what: "Include colophon")
        XCTAssertEqual(colophon.value as? String, "1",
                       "The reopened collection's colophon is off; it was turned on in Collection settings")
    }

    // MARK: - What a heading's Section defaults keep (#1413)

    /// A subtitle typed in a heading's Section defaults sheet — which writes the collection itself — is what the
    /// editor's own Subtitle field shows once the sheet closes, not the value the editor opened with (#1413).
    func testTheEditorShowsASubtitleSetInSectionDefaults() throws {
        launch()
        createCollection()
        addSectionHeading()
        openSectionDefaults()
        type(Self.subtitle, into: "collection.attributes.subtitle.field", what: "Section defaults subtitle")
        closeSectionDefaults()

        let route = openSettings()
        XCTAssertEqual(value(of: "collection.editor.subtitle.field"), Self.subtitle, """
            Collection settings' Subtitle does not read the subtitle set in the heading's Section defaults: the editor \
            still shows the copy it took when it opened, and its next edit would write that copy back.
            """)
        closeSettings(route)
    }

    /// The acceptance case: a subtitle set in Section defaults survives the editor's next edit — here, naming the
    /// collection in Collection settings (#1413). Before the fix, any edit in the editor wrote EVERY field it held,
    /// from the copies it took when it opened, so the name's save put the old, empty subtitle back.
    func testASubtitleSetInSectionDefaultsSurvivesTheEditorsNextEdit() throws {
        launch()
        createCollection()
        addSectionHeading()
        openSectionDefaults()
        type(Self.subtitle, into: "collection.attributes.subtitle.field", what: "Section defaults subtitle")
        closeSectionDefaults()

        let route = openSettings()
        typeName()
        closeSettings(route)
        XCTAssertTrue(app.navigationBars[Self.name].waitForExistence(timeout: 5),
                      "After naming it, the editor is not titled \"\(Self.name)\". Bars: \(barTitles())")

        openSectionDefaults()
        XCTAssertEqual(value(of: "collection.attributes.subtitle.field"), Self.subtitle, """
            The subtitle set in Section defaults did not survive naming the collection: the editor's save wrote the \
            subtitle it opened with back over it.
            """)
        closeSectionDefaults()
    }

    /// The same sheet, on its own: a description typed in Section defaults survives a front-matter toggle flipped in
    /// that sheet (#1413). The editor follows the toggle, and before the fix following it saved every field the
    /// editor held — the description it opened with among them.
    func testADescriptionSetInSectionDefaultsSurvivesAToggleInTheSameSheet() throws {
        launch()
        createCollection()
        addSectionHeading()
        openSectionDefaults()
        type(Self.note, into: "collection.attributes.note.field", what: "Section defaults description")
        dismissKeyboard()
        turnOn("collection.attributes.colophon.toggle", what: "Append colophon page on export")
        closeSectionDefaults()

        openSectionDefaults()
        XCTAssertEqual(value(of: "collection.attributes.note.field"), Self.note, """
            The description typed in Section defaults did not survive the colophon toggle in the same sheet: the \
            editor followed the toggle, saved, and wrote the description it opened with back over it.
            """)
        let colophon = reveal("collection.attributes.colophon.toggle", what: "Append colophon page on export")
        XCTAssertEqual(colophon.value as? String, "1", "The colophon toggled on in Section defaults reads off")
        closeSectionDefaults()
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

    /// Taps the field `identifier` names and types `text` into it.
    private func type(_ text: String, into identifier: String, what: String) {
        let field = element(identifier)
        XCTAssertTrue(field.waitForExistence(timeout: 5), "There is no \(what) field (\(identifier)) to type into")
        field.tap()
        field.typeText(text)
    }

    /// The text a field holds: its value, or "" when the value is only the field's placeholder.
    private func value(of identifier: String) -> String {
        let field = element(identifier)
        XCTAssertTrue(field.waitForExistence(timeout: 5), "There is no field \(identifier) to read")
        let value = (field.value as? String) ?? ""
        return value == field.placeholderValue ? "" : value
    }

    /// Puts the keyboard away with the Done bar the screen puts above it (#861), and waits for it to go — the tab bar
    /// and the lower rows are under it. The bar's Done is a TOOLBAR button: a navigation bar's Done closes a sheet.
    private func dismissKeyboard() {
        let done = app.toolbars.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 5), "The keyboard has no Done bar to put it away with")
        done.tap()
        XCTAssertTrue(waitUntil { app.keyboards.count == 0 }, "The keyboard's Done did not put it away")
    }

    /// The toggle `identifier` names, scrolled up into view if it is not hittable. The drag runs at the screen's left
    /// edge, over row labels, so it scrolls the list without landing on a control.
    private func reveal(_ identifier: String, what: String) -> XCUIElement {
        let target = element(identifier)
        let window = app.windows.firstMatch
        let origin = window.coordinate(withNormalizedOffset: .zero)
        var drags = 0
        while !(target.exists && target.isHittable) && drags < 4 {
            let start = origin.withOffset(CGVector(dx: 24, dy: window.frame.height * 0.7))
            let end = origin.withOffset(CGVector(dx: 24, dy: window.frame.height * 0.4))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.3)
            drags += 1
        }
        XCTAssertTrue(target.exists && target.isHittable,
                      "\"\(what)\" (\(identifier)) is not on screen to use, after \(drags) drag(s)")
        return target
    }

    /// Turns on the toggle `identifier` names, and waits for it to read on. The tap goes to the switch itself: a
    /// SwiftUI toggle's element spans its whole row, and a tap on its label does not flip it.
    private func turnOn(_ identifier: String, what: String) {
        let toggle = reveal(identifier, what: what)
        XCTAssertEqual(toggle.value as? String, "0", "\"\(what)\" is already on, so turning it on tests nothing")
        let knob = toggle.switches.firstMatch
        if knob.exists {
            knob.tap()
        } else {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        }
        XCTAssertTrue(waitUntil { (toggle.value as? String) == "1" }, "\"\(what)\" did not turn on")
    }

    /// Opens the heading row's Section defaults sheet, which edits the collection's description, subtitle, author
    /// line and front-matter toggles on the model itself (`CollectionAttributesRows`).
    private func openSectionDefaults() {
        let pill = app.buttons["Section defaults"].firstMatch
        XCTAssertTrue(pill.waitForExistence(timeout: 5),
                      "The outline has no heading with a Section defaults pill. Buttons: \(visibleButtonLabels())")
        pill.tap()
        XCTAssertTrue(element("collection.attributes.subtitle.field").waitForExistence(timeout: 5),
                      "Section defaults opened no sheet holding the collection's Subtitle. Bars: \(barTitles())")
    }

    /// Closes the Section defaults sheet with its navigation bar's Done — the only navigation-bar Done on screen, since
    /// the pushed editor's own bar has none — and waits for it to go.
    private func closeSectionDefaults() {
        let done = app.navigationBars.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 5), "The Section defaults sheet has no navigation-bar Done")
        done.tap()
        waitForAbsence(of: element("collection.attributes.subtitle.field"), "The Section defaults sheet did not close")
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

// MARK: - CollectionProseRowRestTests

/// A long note block in the collection editor's outline — and a long introduction in Collection settings — once the
/// keyboard is put away, shows its OPENING words and ends its last line in an ellipsis (#1360).
///
/// Before #1360 each was a scrolling text view inside a fixed frame (60–220 pt for the note block, 80–200 pt for the
/// introduction). Measured on iPad Air 11-inch and iPhone Air (iOS 26.5), the note block's text view rested at its
/// 60 pt floor, showing the last three lines of a block typed in place — the text view follows the caret, and
/// nothing scrolled it back — and at AX3 only its last word, under a line cut through the letters.
///
/// **The oracle is text recognition, because nothing else can see the defect.** A text view reports its WHOLE text to
/// accessibility whether or not any of it is on screen, so `value` reads the same on the broken row and the fixed one.
/// So the test screenshots the text view and asks Vision what it reads there, which is what the reader sees — the
/// precedent is `YearRangeFieldWidthTests`. Every expectation is taken from the text view's own `value`, not from the
/// typed string, so an autocorrection the keyboard makes cannot fail the test. The editor is scrolled clear of the
/// screen's chrome first, because a screenshot of an element is the screen inside its frame.
///
/// **Run it on an iPad AND on an iPhone.** Every test fails on the unfixed build on both idioms, but they reach
/// different screens: the outline's Add menu is a single nav-bar menu on iPhone and a toolbar ＋ Add on iPad — inside
/// the toolbar's overflow (⋯) where the toolbar is too narrow for it, which on iPad Air 11-inch in portrait it is at
/// the default text size but not at AX3, and on iPad Pro 13-inch it is not — and Collection settings is a sheet on
/// iPad and a pushed screen on iPhone. The accessibility-size tests put a narrow row at its hardest — a larger font
/// puts more of a block past any fixed height — and each proves its size took effect by measuring the recognized
/// line's height, because an unrecognised category name renders at the default size and every other assertion would
/// still pass; the default-size test checks the other side of the same threshold.
///
/// **Two tests read the editor while it is edited**, from review of #1360's first build. At AX3 the six resting lines
/// (292 pt) outgrew the 220 pt editing height, so a tap to edit SHRANK the block; and the formatting bar's colour
/// picker, once the reader typed into its own fields, took focus and so ended the edit, which collapsed the block to
/// its resting lines behind the picker. Both measure the text view's frame, which XCUI reports whatever the text view
/// draws.
///
/// Animations are off (`FRUS_UI_TEST_DISABLE_ANIMATIONS=1`): the assertions read an editor at rest, and a keyboard
/// coming up or going down is one of the iOS 27 idle-stall triggers CLAUDE.md records. **The suite closes what it
/// opens** in `tearDown`: the iPad's Collection settings is a sheet.
///
/// Version history:
///   1.0 — #1360: initial implementation
///   1.1 — #1360 review, round 1: `testEditingALongNoteBlockAtAnAccessibilitySizeDoesNotShrinkIt` and
///          `testTextColorKeepsALongNoteBlockOpenWhileItsPickerIsUp`; the Add-menu note corrected for AX3 and for
///          iPad Pro 13-inch
@MainActor
final class CollectionProseRowRestTests: XCTestCase {

    /// A paragraph of common words — nothing the keyboard should correct — that runs well past six lines at the default
    /// size in every outline this suite has measured, iPad Pro 13-inch's included, and far past them at an
    /// accessibility size. While it is edited the block stands more than the 20 pt the Text Color test needs above its
    /// 142 pt resting lines: 220 pt, the editing height, on iPad Air 11-inch, and 203.3 pt on iPhone Air, under it.
    private static let paragraph = """
        This section gathers the papers that show how the plan took shape over the first weeks of the crisis. \
        The early memoranda set out the choices as the staff saw them, and the later ones record how those choices \
        narrowed once the meetings began. Read the first three documents together, since each answers a question the \
        one before it left open. The fourth and fifth documents come from the field and give a different view of the \
        same days. Note the dates with care, because several of these papers crossed in transit and their authors did \
        not see each other before writing. The last group returns to the capital and closes the section with the \
        decision itself, the order that followed it, and the first reports of how it was received abroad. Taken \
        together they show a government working quickly with partial information and changing its mind more than once \
        before it settled on a course it would defend for years afterward.
        """
    /// The compact editor's Add menu, by its accessibility label; the regular-width one reads "Add".
    private static let compactAddMenu =
        "Add documents, a section heading, a note block, highlighted passages, or an apparatus block"
    /// A new, unnamed collection's editor title (#1359).
    private static let newCollectionTitle = "New Collection"
    /// Collection settings' navigation title — the iPad sheet's and the iPhone screen's.
    private static let settingsTitle = "Collection settings"
    /// The label above the introduction's editor in Collection settings.
    private static let introductionLabel = "Introduction"
    /// How many of the block's opening words the row must show first.
    private static let openingWordCount = 4
    /// How many of the block's closing words the row must NOT show.
    private static let closingWordCount = 3
    /// The recognized line height, in points, that divides the default text size from AX3 — midway between the two.
    /// Vision's box hugs the glyphs rather than the line: measured on iPad Air 11-inch and iPhone Air (iOS 26.5), the
    /// typed callout text's first line read 16.6 pt and 16.0 pt at the default size and 29.0 pt and 28.7 pt at AX3,
    /// where the six resting lines filled 142 pt and 292 pt. Both tests check their side of it, so a threshold that
    /// drifted past either size fails a test rather than passing both.
    private static let accessibilityLineHeight: CGFloat = 23
    /// The note block's editing height at the default text size — ``RichTextRestingCap/proseBlock``'s 220 pt.
    private static let noteBlockEditingHeight: CGFloat = 220
    /// The note block's six resting lines at the default text size: measured 142 pt on iPad Air 11-inch and iPhone Air.
    private static let defaultRestingHeight: CGFloat = 142

    var app: XCUIApplication!

    /// Read through a closure: each test mints a fresh `XCUIApplication`.
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    override func tearDown() async throws {
        UITestPresentation.dismissAnyPresentation(in: app)
        app?.terminate()
        app = nil
        try await super.tearDown()
    }

    func testALongNoteBlockRestsOnItsOpeningWords() throws {
        launch(contentSizeCategory: nil)
        let firstLineHeight = try typeTheParagraphAndReadItAtRest(in: addNoteBlock(), under: editorBar(),
                                                                  what: "note block", name: "default")
        XCTAssertLessThan(firstLineHeight, Self.accessibilityLineHeight, """
            At the default text size the row's first line is \(firstLineHeight) pt tall, over the \
            \(Self.accessibilityLineHeight) pt the accessibility-size test takes as proof that its size took effect.
            """)
    }

    func testALongNoteBlockRestsOnItsOpeningWordsAtAnAccessibilitySize() throws {
        launch(contentSizeCategory: "UICTContentSizeCategoryAccessibilityXL")
        let firstLineHeight = try typeTheParagraphAndReadItAtRest(in: addNoteBlock(), under: editorBar(),
                                                                  what: "note block", name: "AX3")
        XCTAssertGreaterThan(firstLineHeight, Self.accessibilityLineHeight, """
            The row's first line is \(firstLineHeight) pt tall, which is the default text size: the accessibility \
            size did not take effect, so this test measured nothing an accessibility reader sees.
            """)
    }

    /// The collection's introduction opts into the same resting cap, in Collection settings — a sheet on iPad, a
    /// pushed screen on iPhone — and before #1360 it had the same fixed-frame scrolling editor.
    func testALongIntroductionRestsOnItsOpeningWords() throws {
        launch(contentSizeCategory: nil)
        let bar = app.navigationBars[Self.settingsTitle]
        _ = try typeTheParagraphAndReadItAtRest(in: openIntroduction(), under: bar,
                                                what: "introduction", name: "introduction")
    }

    /// The resting cap counts LINES and the editing height POINTS, so at AX3 the note block's six resting lines
    /// (292 pt) outgrew its 220 pt editing height, and a tap to edit made the block SHORTER — the opposite of lifting
    /// its cap. Found in review of #1360's first build; beginning to edit must never shrink a block.
    func testEditingALongNoteBlockAtAnAccessibilitySizeDoesNotShrinkIt() throws {
        launch(contentSizeCategory: "UICTContentSizeCategoryAccessibilityXL")
        let editor = addNoteBlock()
        let firstLineHeight = try typeTheParagraphAndReadItAtRest(in: editor, under: editorBar(),
                                                                  what: "note block", name: "AX3, before editing")
        XCTAssertGreaterThan(firstLineHeight, Self.accessibilityLineHeight, """
            The row's first line is \(firstLineHeight) pt tall, which is the default text size: the accessibility \
            size did not take effect, so this test measured nothing an accessibility reader sees.
            """)
        let resting = editor.frame.height
        XCTAssertGreaterThan(resting, Self.noteBlockEditingHeight, """
            At AX3 the resting block is \(resting) pt, not past the \(Self.noteBlockEditingHeight) pt editing \
            height, so a shrink on editing could not happen here and this test measures nothing.
            """)

        editor.tap()
        XCTAssertTrue(app.toolbars.buttons["Done"].firstMatch.waitForExistence(timeout: 5),
                      "Tapping the resting note block did not begin editing: no formatting bar")
        Thread.sleep(forTimeInterval: 1)
        XCTAssertGreaterThanOrEqual(editor.frame.height, resting - 1, """
            Beginning to edit made the note block \(editor.frame.height) pt tall, from its resting \(resting) pt: \
            it shrank when its cap lifted.
            """)
    }

    /// The formatting bar's Text Color presents the system colour picker. Opening it leaves the note block focused —
    /// measured on iPad Air 11-inch (a popover) and iPhone Air (a sheet), iOS 26.5 — but typing a value into the
    /// picker's own Sliders fields takes focus from the text view, which ENDS editing while the reader is still
    /// formatting. On #1360's first build that ending collapsed a long block to its six resting lines behind the
    /// picker, scrolled to the top, hiding what was being coloured.
    func testTextColorKeepsALongNoteBlockOpenWhileItsPickerIsUp() throws {
        launch(contentSizeCategory: nil)
        let editor = addNoteBlock()
        editor.tap()
        editor.typeText(Self.paragraph)
        let done = app.toolbars.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 5), "The note block's formatting bar offers no Done")
        Thread.sleep(forTimeInterval: 1)
        let open = editor.frame.height
        XCTAssertGreaterThan(open, Self.defaultRestingHeight + 20, """
            While it is edited the long note block is \(open) pt, not clearly taller than its \
            \(Self.defaultRestingHeight) pt resting lines, so a collapse could not be seen.
            """)

        let color = app.toolbars.buttons["Text Color"].firstMatch
        XCTAssertTrue(color.waitForExistence(timeout: 5), "The note block's formatting bar offers no Text Color")
        color.tap()
        let sliders = app.buttons["Sliders"].firstMatch
        XCTAssertTrue(sliders.waitForExistence(timeout: 5), "Text Color opened no colour picker with a Sliders tab")
        XCTAssertGreaterThanOrEqual(editor.frame.height, open - 1, """
            With the colour picker just opened the note block is \(editor.frame.height) pt, from the \(open) pt it \
            was open at.
            """)
        sliders.tap()
        let red = app.textFields["sliderRed"].firstMatch
        XCTAssertTrue(red.waitForExistence(timeout: 5), "The colour picker's Sliders tab has no Red field")
        red.tap()
        XCTAssertTrue(waitUntil(5) { (red.value(forKey: "hasKeyboardFocus") as? Bool) == true },
                      "The picker's Red field did not take focus, so the note block's edit never ended")
        Thread.sleep(forTimeInterval: 1)
        XCTAssertTrue(editor.exists, "Behind the colour picker the note block is not in the element tree")
        XCTAssertGreaterThanOrEqual(editor.frame.height, open - 1, """
            With the picker's Red field focused the note block is \(editor.frame.height) pt, from the \(open) pt it \
            was open at: it collapsed to its resting lines while the reader was still choosing a colour.
            """)

        let close = app.buttons["close"].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 5), "The colour picker has no close button")
        if !close.isHittable {
            // On iPad Pro 13-inch (iOS 26.4) the Red field's number pad floats over the picker's close button, in a
            // popover whose dismissal region leaves nothing else hittable either. A tap at the picker's Grid tab —
            // outside the pad, by coordinate — puts the pad away.
            app.buttons["Grid"].firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            XCTAssertTrue(waitUntil(5) { close.isHittable }, "The colour picker's close button stays covered")
        }
        close.tap()
        waitForAbsence(of: sliders, "The colour picker did not close")
        Thread.sleep(forTimeInterval: 1)
        // Focus stays in the picker's field until the picker goes, and UIKit does not hand it back to the note block —
        // measured on both idioms — so the edit ended with the picker, and the block rests.
        XCTAssertFalse(done.exists, "After the picker the note block has its formatting bar back: focus came back")
        XCTAssertLessThanOrEqual(editor.frame.height, Self.defaultRestingHeight + 1, """
            After the picker, with focus gone, the note block is \(editor.frame.height) pt, not its \
            \(Self.defaultRestingHeight) pt resting lines: the edit the picker ended left it open.
            """)
    }

    // MARK: - Steps

    /// Launches on the Collections tab at `contentSizeCategory` (`nil`: the device's own) and opens a new collection.
    private func launch(contentSizeCategory: String?) {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_DISABLE_ANIMATIONS"] = "1"
        app.launchArguments = UITestLaunch.arguments(startingOn: .collections,
                                                     contentSizeCategory: contentSizeCategory)
        app.launch()
        XCTAssertTrue(navigator.select(.collections, resolveTimeout: 15).tapped,
                      "Could not open the Collections tab, so this suite would read another screen")

        let create = app.buttons["Create new collection"].firstMatch
        XCTAssertTrue(create.waitForExistence(timeout: 10), "The Collections tab offers no New Collection button")
        create.tap()
        XCTAssertTrue(editorBar().waitForExistence(timeout: 10), "The new collection's editor did not open")
    }

    /// The new collection's editor's navigation bar.
    private func editorBar() -> XCUIElement {
        app.navigationBars[Self.newCollectionTitle]
    }

    /// Adds a note block to the outline and returns its text view.
    private func addNoteBlock() -> XCUIElement {
        openAddMenu()
        let addNote = app.buttons["Add Note Block"].firstMatch
        XCTAssertTrue(addNote.waitForExistence(timeout: 5), "The Add menu has no Add Note Block")
        addNote.tap()

        // The outline holds no other text view: the introduction and the collection note live in Collection settings.
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5), "Add Note Block added no editable row")
        XCTAssertEqual(app.textViews.count, 1, "The outline holds \(app.textViews.count) text views, not the one note")
        return editor
    }

    /// Opens Collection settings through whichever control the layout drew — the ⚙ Collection button's sheet on a
    /// regular-width layout, the Collection settings row's pushed screen on a compact one — and returns the
    /// introduction's text view: the one text view directly below the "Introduction" label. (The collection note
    /// above it is a text view too.)
    private func openIntroduction() throws -> XCUIElement {
        let button = app.descendants(matching: .any)["collection.editor.settings.button"].firstMatch
        let row = app.descendants(matching: .any)["collection.editor.settings.row"].firstMatch
        XCTAssertTrue(waitUntil(10) { button.exists || row.exists },
                      "The editor shows neither the ⚙ Collection button nor the Collection settings row")
        (button.exists ? button : row).tap()
        XCTAssertTrue(app.navigationBars[Self.settingsTitle].waitForExistence(timeout: 5),
                      "Collection settings did not open")
        let label = app.staticTexts[Self.introductionLabel].firstMatch
        XCTAssertTrue(label.waitForExistence(timeout: 5), "Collection settings shows no Introduction label")
        let below = app.textViews.allElementsBoundByIndex
            .filter { $0.frame.minY >= label.frame.maxY - 2 }
            .min { $0.frame.minY < $1.frame.minY }
        return try XCTUnwrap(below, "Collection settings shows no text view below the Introduction label")
    }

    /// Types the paragraph into `editor`, puts the keyboard away with the formatting bar's Done, brings the editor
    /// into view under `topBar`, and checks what it DRAWS. Returns the height in points of the first line Vision read.
    private func typeTheParagraphAndReadItAtRest(in editor: XCUIElement, under topBar: XCUIElement,
                                                 what: String, name: String) throws -> CGFloat {
        editor.tap()
        editor.typeText(Self.paragraph)

        // The formatting bar's own Done (#861/#928) — the keyboard's accessory, not a navigation-bar button.
        let done = app.toolbars.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 5), "The \(what)'s formatting bar offers no Done")
        done.tap()
        waitForAbsence(of: done, "Done did not put the keyboard away")
        Thread.sleep(forTimeInterval: 1)
        bringIntoView(editor, under: topBar)

        let value = try XCTUnwrap(editor.value as? String, "The \(what) reports no text")
        let words = Self.words(value)
        XCTAssertGreaterThan(words.count, 100, "The \(what) holds \(words.count) words, not the typed paragraph")

        let shot = editor.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = "\(what) at rest (\(name))"
        attachment.lifetime = .keepAlways
        add(attachment)
        let lines = try recognizedLines(in: shot.image, pointsTall: editor.frame.height)
        let shownWords = Self.words(lines.map(\.text).joined(separator: " "))
        let report = "The \(what) reads: \(lines.map(\.text)) in a \(editor.frame.height) pt text view"

        // Positive signal first: Vision read something, or nothing below means anything.
        XCTAssertFalse(lines.isEmpty, "Vision read nothing in the \(what). \(report)")

        let opening = Array(words.prefix(Self.openingWordCount))
        XCTAssertEqual(Array(shownWords.prefix(Self.openingWordCount)), opening, """
            At rest the \(what) does not begin with its opening words "\(opening.joined(separator: " "))". \(report)
            """)
        let closing = words.suffix(Self.closingWordCount).joined(separator: " ")
        XCTAssertFalse(shownWords.joined(separator: " ").contains(closing), """
            At rest the \(what) shows its closing words "\(closing)": it was left scrolled to its end. \(report)
            """)
        let last = lines.last?.text ?? ""
        XCTAssertTrue(last.hasSuffix("...") || last.hasSuffix("…"), """
            The \(what)'s last line "\(last)" does not end in an ellipsis, so it is cut rather than truncated. \
            \(report)
            """)
        let firstLineHeight = lines.first?.height ?? 0
        print("[CollectionProseRowRestTests] \(name): first line \(firstLineHeight) pt of \(lines.count) lines "
              + "in a \(editor.frame.height) pt text view")
        return firstLineHeight
    }

    /// Opens the editor's Add menu wherever the layout on screen put it: the compact nav-bar menu, the regular-width
    /// toolbar's ＋ Add, or — measured on iPad Air 11-inch in portrait at the default text size, where the toolbar is
    /// too narrow for it — inside the toolbar's overflow (⋯) menu.
    private func openAddMenu() {
        let compact = app.buttons[Self.compactAddMenu].firstMatch
        let regular = app.buttons["Add"].firstMatch
        let overflow = app.navigationBars.buttons["More"].firstMatch
        XCTAssertTrue(waitUntil(10) { compact.exists || regular.exists || overflow.exists },
                      "The collection editor has neither an Add menu nor a toolbar overflow menu")
        if compact.exists {
            compact.tap()
        } else if regular.exists {
            regular.tap()
        } else {
            overflow.tap()
            let nested = app.buttons["Add"].firstMatch
            XCTAssertTrue(nested.waitForExistence(timeout: 5), "The toolbar's overflow menu holds no Add menu")
            nested.tap()
        }
    }

    /// Scrolls the list holding `editor` until it sits just under `topBar` (and the compact editor's Outline | Preview
    /// control, when that is on screen), clear of the chrome along the bottom of the screen, and asserts it is. An
    /// element's screenshot is the SCREEN inside its frame: measured on iPhone Air at AX3, the resting row was 292 pt
    /// tall and its lower lines lay under the iCloud "Local Only" banner, which Vision read as the row's last line —
    /// and a first drag aimed at the navigation bar's edge put its top line under the Outline | Preview control, which
    /// sits below that bar. The drag starts just left of the text view, in its row, so it scrolls the list — inside a
    /// sheet, not the dimmed window behind it — and cannot put the editor into editing.
    private func bringIntoView(_ editor: XCUIElement, under topBar: XCUIElement) {
        let modePicker = app.segmentedControls.containing(.button, identifier: "Outline").firstMatch
        let topChrome = max(topBar.frame.maxY, modePicker.exists ? modePicker.frame.maxY : 0)
        if editor.frame.minY > topChrome + 32 {
            let origin = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
            let x = max(editor.frame.minX - 6, 1)
            let start = origin.withOffset(CGVector(dx: x, dy: editor.frame.minY + 4))
            let end = origin.withOffset(CGVector(dx: x, dy: topChrome + 24))
            // Slow, and held at the end: a plain drag flings, and measured it carried the row 160 pt past its mark
            // and under the navigation bar.
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.5)
            Thread.sleep(forTimeInterval: 1)
        }
        XCTAssertFalse(app.toolbars.buttons["Done"].firstMatch.exists,
                       "Scrolling put the editor into editing: its formatting bar is back")
        for (name, chrome) in [("the navigation bar", topBar),
                               ("the Outline | Preview control", modePicker),
                               ("the iCloud status banner", app.staticTexts["Local Only"].firstMatch),
                               ("the tab bar", app.tabBars.firstMatch)] where chrome.exists {
            XCTAssertFalse(chrome.frame.intersects(editor.frame), """
                The resting note block (\(editor.frame)) lies under \(name) (\(chrome.frame)), so its screenshot \
                would read the chrome instead of the row.
                """)
        }
    }

    // MARK: - Queries

    /// One line Vision recognized: its text, and its height in points.
    private struct RecognizedLine {
        /// The line's top candidate.
        let text: String
        /// The height of the line's box, in points.
        let height: CGFloat
    }

    /// The lines Vision reads in `image`, top to bottom. `pointsTall` is the screenshotted element's height in points,
    /// which converts a box Vision measures as a fraction of the image into points whatever the image's pixel scale.
    private func recognizedLines(in image: UIImage, pointsTall: CGFloat) throws -> [RecognizedLine] {
        let cgImage = try XCTUnwrap(image.cgImage, "The row's screenshot has no bitmap")
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: cgImage).perform([request])
        return (request.results ?? [])
            .sorted { $0.boundingBox.maxY > $1.boundingBox.maxY }
            .compactMap { observation in
                observation.topCandidates(1).first.map {
                    RecognizedLine(text: $0.string, height: observation.boundingBox.height * pointsTall)
                }
            }
    }

    /// `text` as lower-case words, punctuation and ellipses dropped, so what Vision reads compares with what was typed.
    private static func words(_ text: String) -> [String] {
        let kept: [Character] = text.lowercased().map { character -> Character in
            character.isLetter || character.isNumber ? character : " "
        }
        return String(kept).split(separator: " ").map(String.init)
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
}
