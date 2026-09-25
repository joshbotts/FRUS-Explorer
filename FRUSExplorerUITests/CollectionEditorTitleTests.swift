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
/// **Only the iPhone run guards the push-over.** On an iPad `testContentAloneDoesNotNameANewCollection` runs rather
/// than skipping, but by reading it cannot fail there on the old rule: the settings SHEET covers nothing, and
/// presenting a sheet fires no `onDisappear`, so nothing is mistaken for the editor's dismissal. The iPad's own
/// push-over is a document opened in place, and the iPhone's per-entry inspector is another; no test here drives
/// either. So an iPad pass says the title follows the name through the sheet, and nothing about the push-over.
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
///   1.2 — #1359 review, round 2: says which destination guards the push-over (the iPhone's)
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
/// different screens: the outline's Add menu is in the iPad toolbar's overflow (⋯) in portrait and a single nav-bar
/// menu on iPhone, and Collection settings is a sheet on iPad and a pushed screen on iPhone. The accessibility-size
/// test puts a narrow row at its hardest — a larger font puts more of a block past any fixed height — and it proves its
/// size took effect by measuring the recognized line's height, because an unrecognised category name renders at the
/// default size and every other assertion would still pass; the default-size test checks the other side of the same
/// threshold.
///
/// Animations are off (`FRUS_UI_TEST_DISABLE_ANIMATIONS=1`): the assertions read an editor at rest, and a keyboard
/// coming up or going down is one of the iOS 27 idle-stall triggers CLAUDE.md records. **The suite closes what it
/// opens** in `tearDown`: the iPad's Collection settings is a sheet.
///
/// Version history:
///   1.0 — #1360: initial implementation
@MainActor
final class CollectionProseRowRestTests: XCTestCase {

    /// A paragraph of common words — nothing the keyboard should correct — that runs past the old 220 pt row at the
    /// default size on the narrowest outline this suite runs in, and far past it at an accessibility size.
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
    /// toolbar's ＋ Add, or — measured on iPad Air 11-inch in portrait, where the toolbar is too narrow for it — inside
    /// the toolbar's overflow (⋯) menu.
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
