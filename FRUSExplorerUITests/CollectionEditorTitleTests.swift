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
/// that is the state they need. Expect 9 tests with 0 skipped on an iPhone, and 9 with 3 skipped on an iPad.
///
/// **Since L44 the colophon and the other two export switches are step 2's** (decision 170), a screen pushed in the
/// settings' own stack, so the tests that turn one on open *Apparatus* first, and the three tests that typed into a
/// heading's Section defaults sheet, which wrote the collection itself (#1413), drive step 2's switches beside the
/// settings' fields: the sheet holds the section's own settings now, and nothing of the collection's.
///
/// **A narrow iPad is a third layout, and only it reaches the Add menu's overflow (#1450).** On iPad Air 11-inch in
/// portrait the regular-width toolbar folds ＋ Add into its ⋯ overflow, while ⚙ Collection stays in the bar and
/// Collection settings is still the sheet. Measured there (M4, iOS 26.5, 2026-10-01): 8 tests, 3 skipped, none failed,
/// the four heading tests each printing `[CollectionEditorAddMenu] opened from the toolbar's overflow menu`. With the
/// bar-only lookup put back, those four failed in `addSectionHeading()` ("The editor has no Add menu").
///
/// **Only the iPhone run guards the push-over and the Collections-tab exit.** On an iPad
/// `testContentAloneDoesNotNameANewCollection` runs rather than skipping, but by reading it cannot fail there on the
/// old rule: the settings SHEET covers nothing, and presenting a sheet fires no `onDisappear`, so nothing is mistaken
/// for the editor's dismissal. The iPad's own push-over is a document opened in place, and the iPhone's per-entry
/// inspector is another; no test here drives either. So an iPad pass says the title follows the name through the
/// sheet, and nothing about the push-over.
///
/// **Only the iPad runs guard Link to Saved Search… (#1704)**, the other way round: on the settings SHEET the picker
/// hung on the editor beneath it and opened nothing, and on the pushed screen it always opened. Measured on the code
/// before the fix (2026-10-17): `testLinkToSavedSearchOpensOverCollectionSettings` failed on iPad Pro 13-inch (M5),
/// iOS 27.0, and iPad Air 11-inch (M4), iOS 26.5, and passed on iPhone 17, iOS 27.0.
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
/// **Until L44 a heading's Section defaults sheet wrote the collection itself (#1413)** — its description, subtitle,
/// author line and front-matter toggles (`CollectionAttributesRows`). Before #1413 the editor went on showing the values
/// it opened with, and its next save wrote every one of them back: a rename, or even the editor following a toggle
/// flipped in that same sheet. The three tests run on both idioms, and all three failed on the pre-#1413 editor on
/// iPhone 17 and on iPad Pro 13-inch (M5); L44 moved them to step 2's switches, the second surface since.
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
/// **Every wait is ``patience``, 30 s, and the suite needs 600 s a test** (`-test-timeouts-enabled YES
/// -default-test-execution-time-allowance 600 -maximum-test-execution-time-allowance 600`), not the 300 s CLAUDE.md
/// gives an iOS 27 run. One query on these screens takes seconds, so a 5 s wait could run out before its first check
/// came back. With 30 s waits the slowest Section defaults test took 348 s on iPhone 17 and 342 s on iPad Pro 13-inch
/// (M5), iOS 27.0, on 2026-10-17, and the three took 326 to 430 s on iPad Air 11-inch (M4), iOS 26.5, in #1704's
/// control.
///
/// Version history:
///   1.0 — #1359: initial implementation
///   1.1 — #1359 review: the push-over tests; each test takes the route the layout on screen offers, not the idiom's
///   1.2 — #1359 review, round 2: says which destination guards the push-over (the iPhone's)
///   1.3 — #1415 / #1413: edits in Collection settings survive the Collections tab; Section defaults' description,
///         subtitle and toggle survive the editor and show in it
///   1.4 — #1450: `addSectionHeading()` opens the Add menu through `CollectionEditorAddMenu`, which also looks in
///         the toolbar's ⋯ overflow, where a narrow iPad puts it
///   1.5 — #1450 review, round 1: run on iPad Air 11-inch (M4) in portrait, iOS 26.5, the device #1450 names — the
///         four heading tests open the menu from the overflow and pass, and fail with the bar-only lookup put back
///   1.6 — #1704: `testLinkToSavedSearchOpensOverCollectionSettings`, which the iPads guard and the iPhone controls
///   1.7 — 2026-10-17 (plan of record §6g): every wait is ``patience``, 30 s, where most were 5 s, because one query
///         on these screens takes seconds under Xcode 27.1; the three Section defaults tests, which failed on `v2` in a
///         5 s wait, pass again, given 600 s a test
///   1.8 — L44: the three Section defaults tests drive step 2's switches, and the colophon is turned on in step 2
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
    /// The description the tests give a collection — its note, which Collection settings and a heading's Section
    /// defaults both edit.
    private static let note = "A working note"
    /// The title-page subtitle the tests give a collection.
    private static let subtitle = "Draft"
    /// The saved search `UITestSavedSearchSeeder` writes, as its `searchName` spells it.
    private static let savedSearch = "UI Test Saved Search"
    /// The Link to Saved Search picker's navigation title.
    private static let linkPickerTitle = "Link to Saved Search"
    /// How long a wait waits. Long, because a wait that is met returns at once, and on these screens one XCUI query
    /// takes seconds. Measured in #1704's runs on 2026-10-17, under Xcode 27.1 (installed the day before): a query for
    /// a control by its identifier took 4 to 13 s at a run's median and up to 28 s, on iPhone 17 and iPad Pro 13-inch
    /// (M5) (iOS 27.0) and iPad Air 11-inch (M4) (iOS 26.5), against about a second for a query by label. XCTest first
    /// checks a wait's condition a second after the wait begins, so a 5 s wait ran out while that first check was
    /// still running, whatever the screen showed: all three Section defaults tests failed "The Section defaults sheet
    /// did not close" on all three devices, on `v2` itself. `waitForExistence(timeout:)` checks once more after it
    /// runs out, which is all that kept the other 5 s waits passing: every wait for a control by identifier ran past
    /// its 5 s.
    private static let patience: TimeInterval = 30

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
        XCTAssertTrue(app.navigationBars[Self.name].waitForExistence(timeout: Self.patience),
                      "After naming it, the editor is not titled \"\(Self.name)\". Bars: \(barTitles())")

        backOut(from: Self.name)
        let row = listRow(Self.name)
        XCTAssertTrue(row.waitForExistence(timeout: Self.patience),
                      "The Collections list shows no row named \"\(Self.name)\" to reopen")
        row.tap()
        XCTAssertTrue(app.navigationBars[Self.name].waitForExistence(timeout: Self.patience),
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
        XCTAssertTrue(app.navigationBars[Self.newTitle].waitForExistence(timeout: Self.patience), """
            Back from Collection settings, the unnamed collection's editor is not titled "\(Self.newTitle)". Bars: \
            \(barTitles()). The editor took the settings screen pushed over it for its own dismissal and named the \
            collection "\(Self.untitled)".
            """)

        route = openSettings()
        assertNameFieldIsEmpty("on the second visit to Collection settings")
        typeName()
        closeSettings(route)
        XCTAssertTrue(app.navigationBars[Self.name].waitForExistence(timeout: Self.patience),
                      "After naming it, the editor is not titled \"\(Self.name)\". Bars: \(barTitles())")
        backOut(from: Self.name)
        XCTAssertTrue(listRow(Self.name).waitForExistence(timeout: Self.patience),
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
        XCTAssertTrue(app.staticTexts[Self.emptyListTitle].waitForExistence(timeout: Self.patience), """
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
        XCTAssertTrue(row.waitForExistence(timeout: Self.patience), """
            The name typed in Collection settings was lost when the Collections tab took the stack back to the list: \
            the list has no row named "\(Self.name)". Rows: \(listRowLabels()). The editor under the settings screen \
            saved the name only when it came back on screen, and it never did.
            """)
        row.tap()
        XCTAssertTrue(app.navigationBars[Self.name].waitForExistence(timeout: Self.patience),
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
        XCTAssertTrue(addNote.waitForExistence(timeout: Self.patience), "Collection settings offers no Add a note")
        addNote.tap()
        type(Self.note, into: "collection.editor.note.field", what: "note")
        type(Self.subtitle, into: "collection.editor.subtitle.field", what: "subtitle")
        dismissKeyboard()
        // L44 (decision 170): the colophon is step 2's, a screen pushed over the settings, which the tab takes away too.
        openApparatusStep()
        turnOn("collection.editor.colophon.toggle", what: "Include colophon")
        returnToTheListByTab()

        let row = listRow(Self.untitled)
        XCTAssertTrue(row.waitForExistence(timeout: Self.patience), """
            The collection given a note, a subtitle and a colophon in Collection settings was lost when the \
            Collections tab took the stack back to the list: the list has no "\(Self.untitled)" row. Rows: \
            \(listRowLabels()).
            """)
        row.tap()
        XCTAssertTrue(app.navigationBars[Self.untitled].waitForExistence(timeout: Self.patience),
                      "The kept collection's editor is not titled \"\(Self.untitled)\". Bars: \(barTitles())")
        try openPushedSettings()
        XCTAssertEqual(value(of: "collection.editor.note.field"), Self.note,
                       "The reopened collection's note does not read what was typed in Collection settings")
        XCTAssertEqual(value(of: "collection.editor.subtitle.field"), Self.subtitle,
                       "The reopened collection's subtitle does not read what was typed in Collection settings")
        openApparatusStep()
        let colophon = reveal("collection.editor.colophon.toggle", what: "Include colophon")
        XCTAssertEqual(colophon.value as? String, "1",
                       "The reopened collection's colophon is off; it was turned on in step 2")
    }

    // MARK: - What step 2's switches keep (#1413's tests, moved by L44)

    // Until L44 these three tests typed into a heading's Section defaults sheet, which wrote the collection's own
    // description, subtitle, author line and switches (#1413). L44 took the collection's settings out of that sheet (the
    // design's §5.2), and the three switches into step 2, a screen of their own beside the settings' fields: the second
    // surface #1413 guarded, now pushed in the settings' own stack. The hazard is the same, one surface's write lost to
    // another's, and so are the checks.

    /// A switch turned on in step 2 is what step 2 shows when it is opened again from the settings, after the settings
    /// have closed and the editor has come back (#1413's first test, moved).
    func testASwitchSetInTheApparatusStepIsShownWhenItOpensAgain() throws {
        launch()
        createCollection()
        addSectionHeading()
        var route = openSettings()
        openApparatusStep()
        turnOn("collection.editor.colophon.toggle", what: "Include colophon")
        leaveApparatusStep()
        closeSettings(route)

        route = openSettings()
        openApparatusStep()
        let colophon = reveal("collection.editor.colophon.toggle", what: "Include colophon")
        XCTAssertEqual(colophon.value as? String, "1", """
            Step 2's colophon reads off when it opens again: the switch turned on there did not reach the collection, \
            or the editor showed the copy it took when it opened.
            """)
        leaveApparatusStep()
        closeSettings(route)
    }

    /// The acceptance case: a switch turned on in step 2 survives the editor's next edit, here naming the collection in
    /// Collection settings (#1413's second test, moved). Before #1413 any edit in the editor wrote every field it held,
    /// from the copies it took when it opened.
    func testASwitchSetInTheApparatusStepSurvivesTheEditorsNextEdit() throws {
        launch()
        createCollection()
        addSectionHeading()
        let route = openSettings()
        openApparatusStep()
        turnOn("collection.editor.colophon.toggle", what: "Include colophon")
        leaveApparatusStep()
        typeName()
        dismissKeyboard()

        openApparatusStep()
        let colophon = reveal("collection.editor.colophon.toggle", what: "Include colophon")
        XCTAssertEqual(colophon.value as? String, "1", """
            The colophon turned on in step 2 did not survive naming the collection: the editor's save wrote the copy it \
            opened with back over it.
            """)
        leaveApparatusStep()
        closeSettings(route)
        XCTAssertTrue(app.navigationBars[Self.name].waitForExistence(timeout: Self.patience),
                      "After naming it, the editor is not titled \"\(Self.name)\". Bars: \(barTitles())")
    }

    /// A note typed in Collection settings survives a switch turned on in step 2 (#1413's third test, moved): the editor
    /// follows the switch, and before #1413 following it saved every field the editor held, the note it opened with
    /// among them.
    func testANoteSurvivesASwitchInTheApparatusStep() throws {
        launch()
        createCollection()
        addSectionHeading()
        let route = openSettings()
        let addNote = element("collection.editor.note.add")
        XCTAssertTrue(revealInSettings("collection.editor.note.add", what: "Add a note").exists)
        addNote.tap()
        type(Self.note, into: "collection.editor.note.field", what: "note")
        dismissKeyboard()
        openApparatusStep()
        turnOn("collection.editor.colophon.toggle", what: "Include colophon")
        leaveApparatusStep()

        XCTAssertEqual(value(of: "collection.editor.note.field"), Self.note, """
            The note typed in Collection settings did not survive the colophon turned on in step 2: the editor followed \
            the switch, saved, and wrote the note it opened with back over it.
            """)
        closeSettings(route)
    }

    // MARK: - Linking from Collection settings (#1704)

    /// Link to Saved Search… in Collection settings opens its picker over the settings, and the search picked there is
    /// the collection's link, shown in the settings still open beneath it (#1704).
    ///
    /// On a regular width Collection settings is a SHEET, and the picker's sheet hung on the editor beneath it. SwiftUI
    /// presents one sheet at a time from a view, so the tap opened nothing, and the picker came up only once Done had
    /// closed the settings. On a compact width the settings screen is PUSHED and the editor presents nothing else, so the
    /// picker always opened: there this test is the control.
    func testLinkToSavedSearchOpensOverCollectionSettings() throws {
        launch(seedingSavedSearch: true)
        createCollection()
        let route = openSettings()

        let link = revealInSettings("collection.editor.smart.link", what: "Link to Saved Search…")
        XCTAssertTrue(link.isEnabled,
                      "Link to Saved Search… is disabled, so the seeded saved search \"\(Self.savedSearch)\" is not saved")
        link.tap()
        let picker = app.navigationBars[Self.linkPickerTitle]
        XCTAssertTrue(picker.waitForExistence(timeout: Self.patience), """
            Link to Saved Search… in Collection settings (\(route)) opened no picker. Bars: \(barTitles()). On the \
            sheet route the picker hangs on the editor beneath the settings sheet, and waits for Done to close it.
            """)

        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", Self.savedSearch)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: Self.patience),
                      "The picker lists no \"\(Self.savedSearch)\". Buttons: \(visibleButtonLabels())")
        row.tap()
        waitForAbsence(of: picker, "Picking \"\(Self.savedSearch)\" did not close the picker")
        XCTAssertTrue(app.navigationBars[Self.settingsTitle].exists,
                      "Collection settings closed with the picker. Bars: \(barTitles())")
        XCTAssertTrue(app.staticTexts[Self.savedSearch].firstMatch.waitForExistence(timeout: Self.patience), """
            Collection settings do not show the link to "\(Self.savedSearch)" picked in the picker, so the pick did \
            not reach the collection
            """)
        closeSettings(route)
    }

    // MARK: - Steps

    /// Launches on the Collections list. `seedingSavedSearch` saves one search for Link to Saved Search… to offer
    /// (`UITestSavedSearchSeeder`).
    private func launch(seedingSavedSearch: Bool = false) {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_DISABLE_ANIMATIONS"] = "1"
        if seedingSavedSearch {
            app.launchEnvironment["FRUS_UI_TEST_SEED_SAVED_SEARCH"] = "1"
        }
        app.launchArguments = UITestLaunch.arguments(startingOn: .collections)
        app.launch()
        // Asserted, not attempted (#1279): every step below starts on the Collections list.
        XCTAssertTrue(navigator.select(.collections, resolveTimeout: 15).tapped,
                      "Could not open the Collections tab, so this suite would read another screen")
        XCTAssertTrue(app.navigationBars[Self.listTitle].waitForExistence(timeout: Self.patience),
                      "The Collections list is not showing. Bars: \(barTitles())")
    }

    /// Opens a new collection's editor from the Collections list.
    private func createCollection() {
        let create = app.buttons["Create new collection"].firstMatch
        XCTAssertTrue(create.waitForExistence(timeout: Self.patience),
                      "The Collections tab offers no New Collection button. Buttons: \(visibleButtonLabels())")
        create.tap()
        XCTAssertTrue(app.navigationBars[Self.newTitle].waitForExistence(timeout: Self.patience),
                      "The new collection's editor did not open titled \"\(Self.newTitle)\". Bars: \(barTitles())")
    }

    /// Adds a section heading, so the collection has content and is kept when its editor goes.
    ///
    /// The Add menu is opened wherever the layout put it (`CollectionEditorAddMenu.open`). Until #1450 this looked for
    /// it in the bar alone, so on an iPad narrow enough to fold ＋ Add into the toolbar's ⋯ overflow — iPad Air 11-inch
    /// (M4) in portrait, iOS 26.5 — it failed here with "The editor has no Add menu" before the test had tested
    /// anything: measured by lane K3 on the one test that then added a heading, and on all four that do now when that
    /// lookup was put back on 2026-10-01. iPhone 17 and iPad Pro 13-inch never fold it, which is why it had never failed.
    private func addSectionHeading() {
        CollectionEditorAddMenu.open(in: app)
        let heading = app.buttons["Add Section Heading"].firstMatch
        XCTAssertTrue(heading.waitForExistence(timeout: Self.patience),
                      "The Add menu has no Add Section Heading. Buttons: \(visibleButtonLabels())")
        heading.tap()
        XCTAssertTrue(app.buttons["Section defaults"].firstMatch.waitForExistence(timeout: Self.patience),
                      "Add Section Heading added no heading row. Buttons: \(visibleButtonLabels())")
    }

    /// Opens Collection settings through whichever control the layout on screen drew, and waits for it.
    private func openSettings() -> SettingsRoute {
        let (button, row) = settingsControls()
        let route: SettingsRoute = button.exists ? .sheet : .pushed
        (route == .sheet ? button : row).tap()
        XCTAssertTrue(app.navigationBars[Self.settingsTitle].waitForExistence(timeout: Self.patience),
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
        XCTAssertTrue(app.navigationBars[Self.settingsTitle].waitForExistence(timeout: Self.patience),
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
            XCTAssertTrue(done.waitForExistence(timeout: Self.patience),
                          "The Collection settings sheet has no navigation-bar Done")
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
        XCTAssertTrue(app.navigationBars[Self.listTitle].waitForExistence(timeout: Self.patience),
                      "Tapping the Collections tab did not return to the list. Bars: \(barTitles())")
    }

    private func typeName() {
        let field = element("collection.editor.name.field")
        XCTAssertTrue(field.waitForExistence(timeout: Self.patience), "The settings show no collection-name field")
        field.tap()
        field.typeText(Self.name)
    }

    /// Taps the field `identifier` names and types `text` into it.
    private func type(_ text: String, into identifier: String, what: String) {
        let field = element(identifier)
        XCTAssertTrue(field.waitForExistence(timeout: Self.patience),
                      "There is no \(what) field (\(identifier)) to type into")
        field.tap()
        field.typeText(text)
    }

    /// The text a field holds: its value, or "" when the value is only the field's placeholder.
    private func value(of identifier: String) -> String {
        let field = element(identifier)
        XCTAssertTrue(field.waitForExistence(timeout: Self.patience), "There is no field \(identifier) to read")
        let value = (field.value as? String) ?? ""
        return value == field.placeholderValue ? "" : value
    }

    /// Puts the keyboard away with the Done bar the screen puts above it (#861), and waits for it to go — the tab bar
    /// and the lower rows are under it. The bar's Done is a TOOLBAR button: a navigation bar's Done closes a sheet.
    private func dismissKeyboard() {
        let done = app.toolbars.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: Self.patience), "The keyboard has no Done bar to put it away with")
        done.tap()
        XCTAssertTrue(waitUntil { app.keyboards.count == 0 }, "The keyboard's Done did not put it away")
    }

    /// The toggle `identifier` names, scrolled up into view if it is not hittable. The drag runs at the leading edge of
    /// step 2's screen, under its own navigation bar (L44), over row labels, so it scrolls the list without landing on a
    /// control, and on the iPad's settings sheet never touches the dimmed window around it, where a touch closes it.
    private func reveal(_ identifier: String, what: String) -> XCUIElement {
        let target = element(identifier)
        let window = app.windows.firstMatch
        let origin = window.coordinate(withNormalizedOffset: .zero)
        let bar = app.navigationBars["Apparatus"]
        let x = bar.exists ? bar.frame.minX + 24 : 24
        var drags = 0
        while !(target.exists && target.isHittable) && drags < 6 {
            let start = origin.withOffset(CGVector(dx: x, dy: window.frame.height * 0.7))
            let end = origin.withOffset(CGVector(dx: x, dy: window.frame.height * 0.4))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.3)
            drags += 1
        }
        XCTAssertTrue(target.exists && target.isHittable,
                      "\"\(what)\" (\(identifier)) is not on screen to use, after \(drags) drag(s)")
        return target
    }

    /// The control `identifier` names in Collection settings, dragged up into view: Smart Collection is the settings'
    /// last section, below the fold on every device. Each drag runs down the settings' leading edge, under their own
    /// navigation bar, so on the sheet route it scrolls the sheet's list and never touches the dimmed window around the
    /// sheet, where a touch closes it.
    private func revealInSettings(_ identifier: String, what: String) -> XCUIElement {
        let target = element(identifier)
        let bar = app.navigationBars[Self.settingsTitle]
        let origin = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
        var drags = 0
        while !(target.exists && target.isHittable) && drags < 10 {
            let x = bar.frame.minX + 24
            let start = origin.withOffset(CGVector(dx: x, dy: bar.frame.maxY + 360))
            let end = origin.withOffset(CGVector(dx: x, dy: bar.frame.maxY + 40))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .fast, thenHoldForDuration: 0.3)
            drags += 1
        }
        XCTAssertTrue(target.exists && target.isHittable,
                      "\"\(what)\" (\(identifier)) is not on screen in Collection settings, after \(drags) drag(s)")
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

    /// Opens step 2, *Apparatus*, from its row in Collection settings (L44), where the three export switches are.
    private func openApparatusStep() {
        let row = revealInSettings("collection.settings.apparatus.row", what: "the Apparatus row")
        row.tap()
        XCTAssertTrue(app.navigationBars["Apparatus"].waitForExistence(timeout: Self.patience),
                      "The Apparatus row opened no step. Bars: \(barTitles())")
    }

    /// Goes back from step 2 to Collection settings.
    private func leaveApparatusStep() {
        backOut(from: "Apparatus")
        XCTAssertTrue(app.navigationBars[Self.settingsTitle].waitForExistence(timeout: Self.patience),
                      "Back from step 2 did not return to Collection settings. Bars: \(barTitles())")
    }

    /// The name field shows no text of its own: its value is empty, or is the field's placeholder.
    private func assertNameFieldIsEmpty(_ when: String) {
        let field = element("collection.editor.name.field")
        XCTAssertTrue(field.waitForExistence(timeout: Self.patience), "The settings show no collection-name field")
        let value = (field.value as? String) ?? ""
        XCTAssertTrue(value.isEmpty || value == field.placeholderValue, """
            The unnamed collection's name field reads "\(value)" \(when); it should be empty, showing its \
            placeholder "\(field.placeholderValue ?? "")".
            """)
    }

    /// Taps the Back button in the bar titled `title`, and waits for that bar to go.
    private func backOut(from title: String) {
        let back = app.navigationBars[title].buttons["BackButton"]
        XCTAssertTrue(back.waitForExistence(timeout: Self.patience),
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
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: Self.patience), .completed, message)
    }

    /// Polls `condition` until it holds or `timeout` passes, and reports whether it held.
    private func waitUntil(_ timeout: TimeInterval = CollectionEditorTitleTests.patience,
                           _ condition: () -> Bool) -> Bool {
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

// MARK: - CollectionEditorAddMenu

/// Opens the collection editor's Add menu wherever the layout on screen put it, for both suites in this file.
///
/// There are three places. The compact editor draws one navigation-bar menu, named by ``compactLabel``. The
/// regular-width editor draws a toolbar ＋ Add. And where that toolbar is too narrow for its items, iPadOS folds ＋ Add
/// into the toolbar's ⋯ overflow menu: measured by lane K3 (#1360) on iPad Air 11-inch (M4) in portrait at the default
/// text size, iOS 26.5 — and not at AX3 on the same device, nor on iPad Pro 13-inch.
///
/// `CollectionProseRowRestTests` had the three-way lookup from the start. `CollectionEditorTitleTests` looked in the
/// bar alone, so a test of its that adds a section heading failed on that iPad before reaching what it tests (#1450).
/// What was measured, and when: lane K3 saw the one such test the suite then had fail
/// (`testContentAloneDoesNotNameANewCollection`); #1413 added three more; and on 2026-10-01, with the bar-only lookup
/// put back, all four failed there with "The editor has no Add menu" (8 tests: 4 failed, 3 skipped, 1 passed). One
/// function now serves both suites, so the next place the layout puts the menu is learned once.
///
/// **Which devices can show the third place.** iPhone 17 and iPad Pro 13-inch never fold the menu, so on those two a
/// run takes the first or second branch and says nothing about the third. Each call prints the branch it took,
/// `[CollectionEditorAddMenu] opened from …`, so a log shows which. Showing the tab sidebar does not narrow the
/// editor enough to reach it: on iPad Pro 13-inch (M5), iOS 27.0, in portrait, the sidebar is an overlay (content
/// area 752 pt while it shows), and the first tap on the Collections list dismissed it, so the editor opened at full
/// width with ＋ Add in the toolbar. The third place wants iPad Air 11-inch in portrait: there, on iOS 26.5,
/// `CollectionEditorTitleTests` opened all four of its Add menus "from the toolbar's overflow menu" and passed
/// (2026-10-01). A change to this function is untested on the overflow until it has run on that device.
///
/// Version history:
///   1.0 — #1450 (lane HYG): lifted from `CollectionProseRowRestTests.openAddMenu()`, unchanged in what it does
///   1.1 — #1450 review, round 1: the overflow branch measured from `CollectionEditorTitleTests` on iPad Air 11-inch
///         (M4), iOS 26.5; the doc says what was measured failing, and when
///   1.2 — 2026-10-17 (plan of record §6g): waits ``patience``, as both suites do, for the slow queries
///         `CollectionEditorTitleTests.patience` records
@MainActor
enum CollectionEditorAddMenu {

    /// The compact editor's Add menu, by its accessibility label; the regular-width one reads "Add".
    static let compactLabel =
        "Add documents, a section heading, a note block, highlighted passages, or an apparatus block"

    /// How long `open` waits for the menu, and then for the overflow's Add: the suites' own wait
    /// (`CollectionEditorTitleTests.patience`). In #1704's runs the overflow's Add once took 12.6 s to be found, past
    /// the 5 s this waited before.
    private static let patience: TimeInterval = 30

    /// Where the layout put the Add menu.
    enum Place: String {
        /// The compact editor's navigation-bar menu.
        case compactBar = "the compact navigation-bar menu"
        /// The regular-width editor's toolbar ＋ Add.
        case toolbar = "the toolbar's Add"
        /// Inside the toolbar's ⋯ overflow menu.
        case overflow = "the toolbar's overflow menu"
    }

    /// Opens the Add menu and returns where it was. Fails the test when the editor offers none.
    @discardableResult
    static func open(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> Place? {
        let compact = app.buttons[compactLabel].firstMatch
        let regular = app.buttons["Add"].firstMatch
        let overflow = app.navigationBars.buttons["More"].firstMatch
        let deadline = Date().addingTimeInterval(patience)
        while !(compact.exists || regular.exists || overflow.exists), Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        let place: Place
        if compact.exists {
            compact.tap()
            place = .compactBar
        } else if regular.exists {
            regular.tap()
            place = .toolbar
        } else if overflow.exists {
            overflow.tap()
            let nested = app.buttons["Add"].firstMatch
            guard nested.waitForExistence(timeout: patience) else {
                XCTFail("The toolbar's overflow menu holds no Add menu", file: file, line: line)
                return nil
            }
            nested.tap()
            place = .overflow
        } else {
            let labels = app.buttons.allElementsBoundByIndex.prefix(30).map(\.label).filter { !$0.isEmpty }
            XCTFail("""
                The collection editor has neither an Add menu nor a toolbar overflow menu. Buttons: \
                \(labels.joined(separator: " | "))
                """, file: file, line: line)
            return nil
        }
        print("[CollectionEditorAddMenu] opened from \(place.rawValue)")
        return place
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
/// **Every wait is ``patience``, 30 s, and the suite needs 600 s a test** (`-test-timeouts-enabled YES
/// -default-test-execution-time-allowance 600 -maximum-test-execution-time-allowance 600`). On 2026-10-17 its slowest
/// test took 137 s on iPad Air 11-inch (M4) and 129 s on iPhone Air, but #1704's runs of the Text Color test on the
/// Air reached 214 and 228 s before failing in its last steps, and a busier Mac takes longer still.
///
/// Version history:
///   1.0 — #1360: initial implementation
///   1.1 — #1360 review, round 1: `testEditingALongNoteBlockAtAnAccessibilitySizeDoesNotShrinkIt` and
///          `testTextColorKeepsALongNoteBlockOpenWhileItsPickerIsUp`; the Add-menu note corrected for AX3 and for
///          iPad Pro 13-inch
///   1.2 — 2026-10-17 (plan of record §6g): every wait is ``patience``, 30 s, where most were 5 s; the introduction
///          and Text Color tests, which failed on `v2` in a 5 s wait on iPad Air 11-inch, pass again
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
    /// How long a wait waits: long, for the reason `CollectionEditorTitleTests.patience` records. Here the slow screens
    /// are the colour picker and the Collection settings sheet. In #1704's runs on iPad Air 11-inch (M4), iOS 26.5,
    /// `testALongIntroductionRestsOnItsOpeningWords` failed "Done did not put the keyboard away" while the first check
    /// for the sheet's Done took 4.3 s, and `testTextColorKeepsALongNoteBlockOpenWhileItsPickerIsUp` failed "The colour
    /// picker did not close", and once "Text Color opened no colour picker with a Sliders tab", neither of that 5 s
    /// wait's two checks having found the picker. Both failed so on `v2` itself.
    private static let patience: TimeInterval = 30

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
        XCTAssertTrue(app.toolbars.buttons["Done"].firstMatch.waitForExistence(timeout: Self.patience),
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
        XCTAssertTrue(done.waitForExistence(timeout: Self.patience), "The note block's formatting bar offers no Done")
        Thread.sleep(forTimeInterval: 1)
        let open = editor.frame.height
        XCTAssertGreaterThan(open, Self.defaultRestingHeight + 20, """
            While it is edited the long note block is \(open) pt, not clearly taller than its \
            \(Self.defaultRestingHeight) pt resting lines, so a collapse could not be seen.
            """)

        let color = app.toolbars.buttons["Text Color"].firstMatch
        XCTAssertTrue(color.waitForExistence(timeout: Self.patience),
                      "The note block's formatting bar offers no Text Color")
        color.tap()
        let sliders = app.buttons["Sliders"].firstMatch
        XCTAssertTrue(sliders.waitForExistence(timeout: Self.patience),
                      "Text Color opened no colour picker with a Sliders tab")
        XCTAssertGreaterThanOrEqual(editor.frame.height, open - 1, """
            With the colour picker just opened the note block is \(editor.frame.height) pt, from the \(open) pt it \
            was open at.
            """)
        sliders.tap()
        let red = app.textFields["sliderRed"].firstMatch
        XCTAssertTrue(red.waitForExistence(timeout: Self.patience), "The colour picker's Sliders tab has no Red field")
        red.tap()
        XCTAssertTrue(waitUntil { (red.value(forKey: "hasKeyboardFocus") as? Bool) == true },
                      "The picker's Red field did not take focus, so the note block's edit never ended")
        Thread.sleep(forTimeInterval: 1)
        XCTAssertTrue(editor.exists, "Behind the colour picker the note block is not in the element tree")
        XCTAssertGreaterThanOrEqual(editor.frame.height, open - 1, """
            With the picker's Red field focused the note block is \(editor.frame.height) pt, from the \(open) pt it \
            was open at: it collapsed to its resting lines while the reader was still choosing a colour.
            """)

        let close = app.buttons["close"].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: Self.patience), "The colour picker has no close button")
        if !close.isHittable {
            // On iPad Pro 13-inch (iOS 26.4) the Red field's number pad floats over the picker's close button, in a
            // popover whose dismissal region leaves nothing else hittable either. A tap at the picker's Grid tab —
            // outside the pad, by coordinate — puts the pad away.
            app.buttons["Grid"].firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            XCTAssertTrue(waitUntil { close.isHittable }, "The colour picker's close button stays covered")
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
        XCTAssertTrue(create.waitForExistence(timeout: Self.patience),
                      "The Collections tab offers no New Collection button")
        create.tap()
        XCTAssertTrue(editorBar().waitForExistence(timeout: Self.patience), "The new collection's editor did not open")
    }

    /// The new collection's editor's navigation bar.
    private func editorBar() -> XCUIElement {
        app.navigationBars[Self.newCollectionTitle]
    }

    /// Adds a note block to the outline and returns its text view.
    private func addNoteBlock() -> XCUIElement {
        openAddMenu()
        let addNote = app.buttons["Add Note Block"].firstMatch
        XCTAssertTrue(addNote.waitForExistence(timeout: Self.patience), "The Add menu has no Add Note Block")
        addNote.tap()

        // The outline holds no other text view: the introduction and the collection note live in Collection settings.
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: Self.patience), "Add Note Block added no editable row")
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
        XCTAssertTrue(waitUntil { button.exists || row.exists },
                      "The editor shows neither the ⚙ Collection button nor the Collection settings row")
        (button.exists ? button : row).tap()
        XCTAssertTrue(app.navigationBars[Self.settingsTitle].waitForExistence(timeout: Self.patience),
                      "Collection settings did not open")
        let label = app.staticTexts[Self.introductionLabel].firstMatch
        XCTAssertTrue(label.waitForExistence(timeout: Self.patience), "Collection settings shows no Introduction label")
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
        XCTAssertTrue(done.waitForExistence(timeout: Self.patience), "The \(what)'s formatting bar offers no Done")
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

    /// Opens the editor's Add menu wherever the layout on screen put it (`CollectionEditorAddMenu.open`).
    private func openAddMenu() {
        CollectionEditorAddMenu.open(in: app)
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
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: Self.patience), .completed, message)
    }

    /// Polls `condition` until it holds or `timeout` passes, and reports whether it held.
    private func waitUntil(_ timeout: TimeInterval = CollectionProseRowRestTests.patience,
                           _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return condition()
    }
}

// MARK: - CollectionListManagementTests

/// The iPhone and iPad Collections list renames and deletes a collection, and every delete asks first (#1823).
///
/// Before #1823 a full swipe deleted a collection at once, with its headings and note blocks, and the list renamed
/// nothing: a row's menu offered Duplicate, Word Cloud and Create Static Snapshot. Each test here names the route it
/// drives — the row's menu, its swipe, Edit — and requires the dialog before anything is deleted, and the collection gone
/// only after its Delete.
///
/// **Run it on iPhone 17 and iPad Pro 13-inch (M5), both `OS=27.0`.** On the iPhone the dialog is an action sheet with
/// a Cancel; on the iPad it is a popover hanging from the row or from Edit's Delete, with no Cancel, closed by a tap
/// outside it. Nothing skips. The two collections are the launch's own seeds: `FRUS_UI_TEST_SEED_PROJECT`'s unattached
/// collection and `FRUS_UI_TEST_SEED_SAVED_SEARCH=linked`'s smart one. The store is in memory, so each launch has both.
///
/// Version history:
///   1.0 — #1823: initial implementation
@MainActor
final class CollectionListManagementTests: XCTestCase {

    /// `UITestProjectSeeder.collectionName`, repeated because a UI-test target cannot import the app.
    private static let unattached = "UI Test Unattached Collection"
    /// `UITestSavedSearchSeeder.collectionName`.
    private static let smart = "UI Test Smart Collection"
    /// The name the rename test gives the unattached collection.
    private static let renamed = "Renamed From the List"
    private static let listTitle = "Collections"
    private static let emptyListTitle = "No Collections"
    /// XCTest's first check of a slow `.any` query waits a second; see `CollectionEditorTitleTests.patience`.
    private static let patience: TimeInterval = 30

    var app: XCUIApplication!

    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    override func tearDown() async throws {
        UITestPresentation.dismissAnyPresentation(in: app)
        app?.terminate()
        app = nil
        try await super.tearDown()
    }

    /// The row's menu Delete asks; closing the dialog keeps the collection; its Delete deletes that collection and no
    /// other.
    func testTheRowsMenuDeleteAsksFirst() throws {
        launch()
        openMenu(on: Self.unattached)
        tapMenuItem("Delete")
        requireDialog(titled: "Delete “\(Self.unattached)”?")
        closeDialogWithoutDeleting()
        XCTAssertTrue(listRow(Self.unattached).exists, "Closing the dialog deleted \"\(Self.unattached)\"")

        openMenu(on: Self.unattached)
        tapMenuItem("Delete")
        requireDialog(titled: "Delete “\(Self.unattached)”?")
        XCTAssertTrue(listRow(Self.unattached).exists, "The collection went before its dialog's Delete was tapped")
        try dialogButton("Delete").tap()
        waitForAbsence(of: listRow(Self.unattached), "\"\(Self.unattached)\" is still listed after its Delete")
        XCTAssertTrue(listRow(Self.smart).exists, "Deleting one collection took \"\(Self.smart)\" too")
    }

    /// A swipe offers Delete, which asks too: the swipe alone, however far, deletes nothing.
    func testASwipeAsksFirst() throws {
        launch()
        let row = listRow(Self.unattached)
        row.swipeLeft()
        let swipeDelete = app.buttons["Delete"].firstMatch
        XCTAssertTrue(swipeDelete.waitForExistence(timeout: Self.patience), "The swipe offered no Delete")
        XCTAssertTrue(row.exists, "The swipe deleted the collection without its Delete being tapped")
        swipeDelete.tap()
        requireDialog(titled: "Delete “\(Self.unattached)”?")
        XCTAssertTrue(row.exists, "The swipe's Delete deleted the collection without asking")
        try dialogButton("Delete").tap()
        waitForAbsence(of: row, "\"\(Self.unattached)\" is still listed after its Delete")
    }

    /// The row's menu Rename asks for the name, and the row reads it.
    func testTheRowsMenuRenames() throws {
        launch()
        openMenu(on: Self.unattached)
        tapMenuItem("Rename")
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: Self.patience), "Rename opened no alert with a name field")
        XCTAssertEqual(field.value as? String, Self.unattached, "The Rename field does not start from the name")
        // At the field's end, then one delete per character: the cursor lands where the tap does.
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: Self.unattached.count + 2)
                       + Self.renamed)
        app.alerts.buttons["Save"].firstMatch.tap()
        XCTAssertTrue(listRow(Self.renamed).waitForExistence(timeout: Self.patience),
                      "The list shows no row named \"\(Self.renamed)\". Rows: \(listRowLabels())")
        XCTAssertFalse(listRow(Self.unattached).exists, "The old name is still listed. Rows: \(listRowLabels())")
    }

    /// Edit chooses rows rather than opening them; its Delete asks, names how many, and deletes every one chosen.
    func testEditDeletesTheChosenCollections() throws {
        launch()
        let bar = app.navigationBars[Self.listTitle]
        let edit = bar.buttons["Edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: Self.patience), "The list offers no Edit")
        edit.tap()
        let delete = bar.buttons["Delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: Self.patience), "Edit put no Delete in the bar")
        XCTAssertFalse(delete.isEnabled, "Edit's Delete is enabled with nothing chosen")

        listRow(Self.unattached).tap()
        listRow(Self.smart).tap()
        XCTAssertTrue(bar.exists, "A tap in Edit opened a collection rather than choosing it. Bars: \(barTitles())")
        XCTAssertTrue(waitUntil { delete.isEnabled }, "Choosing two rows did not enable Edit's Delete")
        delete.tap()
        requireDialog(titled: "Delete 2 collections?")
        XCTAssertTrue(listRow(Self.unattached).exists && listRow(Self.smart).exists,
                      "Edit's Delete deleted before its dialog's Delete was tapped")
        try dialogButton("Delete").tap()
        XCTAssertTrue(app.staticTexts[Self.emptyListTitle].waitForExistence(timeout: Self.patience),
                      "The list does not read \"\(Self.emptyListTitle)\" after both were deleted. Rows: \(listRowLabels())")
        XCTAssertFalse(bar.buttons["Done"].exists, "The list stayed in Edit after its Delete")
    }

    // MARK: - Steps

    private func launch() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_DISABLE_ANIMATIONS"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_PROJECT"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_SAVED_SEARCH"] = "linked"
        app.launchArguments = UITestLaunch.arguments(startingOn: .collections)
        app.launch()
        XCTAssertTrue(navigator.select(.collections, resolveTimeout: 15).tapped,
                      "Could not open the Collections tab, so this suite would read another screen")
        XCTAssertTrue(app.navigationBars[Self.listTitle].waitForExistence(timeout: Self.patience),
                      "The Collections list is not showing. Bars: \(barTitles())")
        for name in [Self.unattached, Self.smart] {
            XCTAssertTrue(listRow(name).waitForExistence(timeout: Self.patience),
                          "The seeded \"\(name)\" is not listed. Rows: \(listRowLabels())")
        }
    }

    /// Touches and holds `name`'s row until its menu opens.
    private func openMenu(on name: String) {
        listRow(name).press(forDuration: 1.2)
    }

    private func tapMenuItem(_ label: String) {
        let item = app.buttons[label].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: Self.patience),
                      "The row's menu has no \"\(label)\". Buttons: \(visibleButtonLabels())")
        item.tap()
    }

    /// Requires the delete dialog, titled `title`, to be up, in whichever form the idiom presents it.
    private func requireDialog(titled title: String) {
        let heading = app.staticTexts[title].firstMatch
        XCTAssertTrue(heading.waitForExistence(timeout: Self.patience), """
            No dialog titled "\(title)" opened. Texts: \
            \(app.staticTexts.allElementsBoundByIndex.prefix(30).map(\.label))
            """)
    }

    /// The open dialog's button `label`: in a popover on an iPad, an action sheet on an iPhone.
    private func dialogButton(_ label: String) throws -> XCUIElement {
        let candidates = [app.popovers.buttons[label], app.sheets.buttons[label], app.alerts.buttons[label]]
        var found: XCUIElement?
        let deadline = Date().addingTimeInterval(Self.patience)
        repeat {
            found = candidates.first { $0.exists }
            if found == nil { Thread.sleep(forTimeInterval: 0.25) }
        } while found == nil && Date() < deadline
        return try XCTUnwrap(found, "The dialog offered no \"\(label)\" in a popover, sheet or alert. Tree:\n\(app.debugDescription)")
    }

    /// Closes the dialog without deleting: its Cancel on an iPhone, a tap outside the popover on an iPad, where a
    /// dialog's Cancel is not drawn.
    private func closeDialogWithoutDeleting() {
        let cancel = app.sheets.buttons["Cancel"].firstMatch
        if cancel.exists {
            cancel.tap()
        } else {
            let regions = app.otherElements.matching(identifier: "PopoverDismissRegion")
            XCTAssertGreaterThan(regions.count, 0, "The dialog has no Cancel and no popover to tap outside")
            regions.element(boundBy: regions.count - 1)
                .coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.97)).tap()
        }
        XCTAssertTrue(app.staticTexts["Delete “\(Self.unattached)”?"].firstMatch.waitForNonExistence(timeout: Self.patience),
                      "The dialog did not close")
    }

    // MARK: - Queries

    /// The list's row whose name is `name`.
    private func listRow(_ name: String) -> XCUIElement {
        app.collectionViews.staticTexts[name].firstMatch
    }

    private func listRowLabels() -> [String] {
        app.collectionViews.staticTexts.allElementsBoundByIndex.map(\.label).filter { !$0.isEmpty }
    }

    private func waitForAbsence(of element: XCUIElement, _ message: String) {
        XCTAssertTrue(element.waitForNonExistence(timeout: Self.patience), message)
    }

    /// Polls `condition` until it holds or `timeout` passes, and reports whether it held.
    private func waitUntil(_ timeout: TimeInterval = CollectionListManagementTests.patience,
                           _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return condition()
    }

    private func barTitles() -> String {
        app.navigationBars.allElementsBoundByIndex.map(\.identifier).joined(separator: " | ")
    }

    private func visibleButtonLabels() -> String {
        app.buttons.allElementsBoundByIndex.prefix(30).map(\.label).filter { !$0.isEmpty }.joined(separator: " | ")
    }
}

// MARK: - CollectionListSwipeDeleteTests

/// A swipe that deletes a collection from the Collections list keeps its confirmation until it is
/// answered (R6a, F10).
///
/// In R6's pass, on the iPhone under iOS 27.2, swiping *R6 scratch* and tapping Delete raised the
/// confirmation, which closed before it could be answered, and the collection stayed (X7). The row's
/// swipe button carried `role: .destructive`, which animates its row away as if already deleted and
/// takes the row's dialog with it: the trap L19 measured for a collection's entries and fixed there
/// with a red tint and no role (`CollectionRowDeleteTests`). `CollectionListManagementTests`'
/// `testASwipeAsksFirst` passed on that code: it launches with animations off and taps Delete the moment
/// the dialog shows.
///
/// So this suite launches with animations on, as a reader has them: the swipe's Delete must raise the
/// question, which must still be up two seconds later with the collection still listed; closing it
/// keeps the collection; a second swipe's Delete, answered, deletes it. On an iPad the dialog is a
/// popover pointing at the row (`CollectionListManagementTests`), and that holds too.
///
/// **Run it on iPhone 17 and iPad Pro 13-inch (M5)**, `OS=27.2` and `OS=27.0`, allowing 600 s.
///
/// Version history:
///   1.0 — R6a (F10): initial implementation
@MainActor
final class CollectionListSwipeDeleteTests: XCTestCase {

    /// `UITestProjectSeeder.collectionName`.
    private static let collection = "UI Test Unattached Collection"
    private static let title = "Delete “UI Test Unattached Collection”?"
    private static let patience: TimeInterval = 30

    var app: XCUIApplication!

    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    override func tearDown() async throws {
        UITestPresentation.dismissAnyPresentation(in: app)
        app?.terminate()
        app = nil
        try await super.tearDown()
    }

    func testASwipesDeleteWaitsForItsAnswer() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_PROJECT"] = "1"
        app.launchArguments = UITestLaunch.arguments(startingOn: .collections)
        app.launch()
        XCTAssertTrue(navigator.select(.collections, resolveTimeout: 15).tapped, "Could not open the Collections tab")
        let row = app.collectionViews.staticTexts[Self.collection].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: Self.patience), "The seeded collection is not listed")

        swipeDelete(row)
        let question = app.staticTexts[Self.title].firstMatch
        XCTAssertTrue(question.waitForExistence(timeout: Self.patience), "The swipe's Delete did not ask")
        Thread.sleep(forTimeInterval: 2)
        attachScreenshot("Two seconds after the swipe's Delete")
        XCTAssertTrue(question.exists, """
            The swipe's Delete raised its question, which closed by itself within two seconds, unanswered: the \
            destructive swipe button took the row, and the row's dialog with it (R6, X7).
            """)
        XCTAssertTrue(row.exists, "The collection left the list before its question was answered")
        closeTheQuestion()
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Closing the question deleted the collection")

        swipeDelete(row)
        XCTAssertTrue(question.waitForExistence(timeout: Self.patience), "The second swipe's Delete did not ask")
        Thread.sleep(forTimeInterval: 1)
        let delete = [app.popovers.buttons["Delete"], app.sheets.buttons["Delete"], app.alerts.buttons["Delete"]]
            .first { $0.exists }
        try XCTUnwrap(delete, "The question offers no Delete").tap()
        XCTAssertTrue(row.waitForNonExistence(timeout: Self.patience), "Delete left the collection listed")
    }

    // MARK: - Steps

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

// MARK: - CollectionRowDeleteTests

/// Deleting a collection row that holds the reader's text asks first, on a swipe, and a row that holds nothing goes at
/// once (L19, #1919, MAC-2).
///
/// Before L19 a full swipe deleted any row at once — a note block's text, a heading's section defaults, a document's
/// headnote — with no undo, on every synced device. `testASwipeOnANoteBlockAsksFirst` writes a note block, swipes it,
/// and requires "Delete Note Block?" with the block still there; closes the dialog and requires the text intact; then
/// deletes it through the dialog. `testASwipeOnAnUntouchedDocumentDeletesIt` requires the seeded document row, at its
/// defaults, to go on its swipe with no dialog: the rule asks only where there is something to lose.
///
/// **Run it on iPhone 17 and iPad Pro 13-inch (M5), both `OS=27.0`.** Under iOS 27.0 the dialog is a popover pointing
/// at the row on the iPhone as on the iPad, with no Cancel: a tap outside closes it (the helper takes an action sheet's
/// Cancel too). A swipe either completes on its own, as it did in every run of this row's code, or stops at a revealed
/// Delete, which the test taps when the cell holds it. On the code before L19 the note block's test fails at its
/// dialog; the untouched document's fails too, but not as a guard: the swipe stopped at `.onDelete`'s Delete, which the
/// cell does not hold, so nothing was tapped and the row stayed (iPhone 17, iOS 27.0, from the run's recording). The
/// fixture is `FRUS_UI_TEST_SEED_PROJECT`'s collection, which holds `d1` of `FRUS_UI_TEST_SEED_VOLUME`'s volume.
///
/// **What it caught.** Its first run, with the dialog but with the swipe still `.onDelete`'s, failed on the iPhone 17:
/// the swipe's Delete took the note block off the list at once and no dialog showed, and the block came back when the
/// collection was opened again. `.onDelete`'s Delete is a destructive swipe button, which animates its row away as if
/// deleted and takes the row's dialog with it; each row now has a swipe button of its own, red by tint.
///
/// Version history:
///   1.0 — L19 (#1919, MAC-2): initial implementation
@MainActor
final class CollectionRowDeleteTests: XCTestCase {

    /// `UITestProjectSeeder.collectionName`.
    private static let collectionName = "UI Test Unattached Collection"
    /// The seeded document's header, from the seeded volume.
    private static let documentHeader = "UI Test Document One"
    /// What the test writes into its note block.
    private static let blockText = "A note the test wrote"
    /// See `CollectionEditorTitleTests.patience`.
    private static let patience: TimeInterval = 30

    var app: XCUIApplication!

    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    override func tearDown() async throws {
        UITestPresentation.dismissAnyPresentation(in: app)
        app?.terminate()
        app = nil
        try await super.tearDown()
    }

    func testASwipeOnANoteBlockAsksFirst() throws {
        launchIntoTheCollection()
        CollectionEditorAddMenu.open(in: app)
        let addNote = app.buttons["Add Note Block"].firstMatch
        XCTAssertTrue(addNote.waitForExistence(timeout: Self.patience), "The Add menu has no Add Note Block")
        addNote.tap()
        let block = app.textViews.firstMatch
        XCTAssertTrue(block.waitForExistence(timeout: Self.patience), "Add Note Block added no row")
        block.tap()
        block.typeText(Self.blockText)
        let done = app.toolbars.buttons["Done"].firstMatch
        if done.waitForExistence(timeout: 5) { done.tap() }
        Thread.sleep(forTimeInterval: 1)

        try swipeToDelete(cell(holding: block))
        let title = app.staticTexts["Delete Note Block?"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: Self.patience), """
            The swipe did not ask "Delete Note Block?". Texts: \(texts())
            """)
        XCTAssertTrue(app.staticTexts["Its text goes with it, on your other devices too once they sync."].exists,
                      "The dialog does not say what goes. Texts: \(texts())")
        XCTAssertTrue(block.exists, "The note block went before its dialog was answered")
        attachScreenshot("Delete Note Block?")
        closeTheDialog(titled: title)
        XCTAssertTrue(block.exists, "Closing the dialog deleted the note block")
        XCTAssertTrue(((block.value as? String) ?? "").contains(Self.blockText), "Closing the dialog lost the text")

        try swipeToDelete(cell(holding: block))
        XCTAssertTrue(title.waitForExistence(timeout: Self.patience), "The second swipe did not ask")
        try dialogButton("Delete Note Block").tap()
        XCTAssertTrue(block.waitForNonExistence(timeout: Self.patience), "Delete Note Block left the row")
    }

    func testASwipeOnAnUntouchedDocumentDeletesIt() throws {
        launchIntoTheCollection()
        let header = documentRowText(in: app)
        XCTAssertTrue(header.waitForExistence(timeout: Self.patience),
                      "The seeded document's row is not in Contents. Texts: \(texts())")
        try swipeToDelete(cell(holding: header))
        XCTAssertTrue(header.waitForNonExistence(timeout: Self.patience),
                      "A document at its defaults did not go on its swipe. Texts: \(texts())")
        XCTAssertFalse(app.staticTexts["Remove Document?"].exists, "A document at its defaults asked before it went")
    }

    // MARK: - Steps

    private func launchIntoTheCollection() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_DISABLE_ANIMATIONS"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_PROJECT"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_VOLUME"] = "frus1961-63v06"
        app.launchArguments = UITestLaunch.arguments(startingOn: .collections)
        app.launch()
        XCTAssertTrue(navigator.select(.collections, resolveTimeout: 15).tapped,
                      "Could not open the Collections tab, so this suite would read another screen")
        let row = app.collectionViews.staticTexts[Self.collectionName].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: Self.patience), "The seeded collection is not listed")
        row.tap()
        XCTAssertTrue(app.navigationBars[Self.collectionName].waitForExistence(timeout: Self.patience),
                      "The seeded collection's editor did not open")
    }

    /// The list cell that holds `element`.
    private func cell(holding element: XCUIElement) throws -> XCUIElement {
        let middle = CGPoint(x: element.frame.midX, y: element.frame.midY)
        let found = app.cells.allElementsBoundByIndex.first { $0.frame.contains(middle) }
        return try XCTUnwrap(found, "No list cell holds the element at \(middle)")
    }

    /// Swipes `cell` left, fast, as a reader deletes a row. In this row's runs the swipe was a full one and acted at once:
    /// the row went, or its dialog showed (iPhone 17 and iPad Pro 13-inch (M5), iOS 27.0). A swipe that stops at a Delete
    /// the cell holds is followed by a tap on it; on the code before L19 the swipe stopped at `.onDelete`'s Delete, which
    /// the cell does not hold, so nothing was tapped. A swipe over a note block still being typed in may only end the
    /// typing, revealing nothing (seen by hand on the iPhone 17 under iOS 27.0), so a second swipe follows one that
    /// revealed nothing and left the row and no dialog.
    private func swipeToDelete(_ cell: XCUIElement) throws {
        for _ in 0..<2 {
            cell.swipeLeft(velocity: .fast)
            let reveal = cell.buttons["Delete"].firstMatch
            if reveal.waitForExistence(timeout: 2) {
                reveal.tap()
                return
            }
            // A full swipe acts without stopping at Delete: its dialog, or its row gone, is the swipe's answer.
            if !cell.exists || app.popovers.count > 0 || app.sheets.count > 0 { return }
        }
    }

    /// Closes the dialog choosing nothing: its Cancel where an action sheet draws one, else a tap outside
    /// the popover, which is how iOS 27.0 shows it on iPhone and iPad. A note block's swipe has ended
    /// its typing by the time the dialog shows, so the foot of the window is clear of a keyboard.
    private func closeTheDialog(titled title: XCUIElement) {
        let cancel = app.sheets.buttons["Cancel"].firstMatch
        if cancel.waitForExistence(timeout: 3) {
            cancel.tap()
        } else {
            let regions = app.otherElements.matching(identifier: "PopoverDismissRegion")
            XCTAssertGreaterThan(regions.count, 0, "The dialog has no Cancel and no popover to tap outside")
            regions.element(boundBy: regions.count - 1)
                .coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.97)).tap()
        }
        XCTAssertTrue(title.waitForNonExistence(timeout: Self.patience), "The dialog did not close")
        Thread.sleep(forTimeInterval: 1)
    }

    /// The open dialog's button `label`, in a popover, an action sheet or an alert, as the system drew it.
    private func dialogButton(_ label: String) throws -> XCUIElement {
        let candidates = [app.popovers.buttons[label], app.sheets.buttons[label], app.alerts.buttons[label]]
        var found: XCUIElement?
        let deadline = Date().addingTimeInterval(Self.patience)
        repeat {
            found = candidates.first { $0.exists }
            if found == nil { Thread.sleep(forTimeInterval: 0.25) }
        } while found == nil && Date() < deadline
        return try XCTUnwrap(found, "The dialog offered no \"\(label)\" in a popover, sheet or alert")
    }

    private func texts() -> [String] {
        app.staticTexts.allElementsBoundByIndex.prefix(30).map(\.label).filter { !$0.isEmpty }
    }

    private func attachScreenshot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}

// MARK: - CollectionInspectorOpenDocumentTests

/// A collection's document opens in the reader from the screen its row's tap opens (L19, #1919, IPA-4).
///
/// A row's tap, and its Configure pill, open the entry's settings — the iPhone's drill-in, the iPad's Configure sheet —
/// and until L19 the reader was reached from a collection only by a row's long press, a context-menu item the main
/// interface did not offer. `testOpenDocumentInTheEntrysSettingsOpensTheReader` taps the seeded document's row,
/// requires **Open Document** in its settings, opens the reader with it, and goes Back: on the iPhone to the settings it
/// came from, on the iPad to the editor, since the sheet closes before the document opens.
///
/// **Run it on iPhone 17 and iPad Pro 13-inch (M5), both `OS=27.0`**: the drill-in and the sheet are different code.
/// The reader's oracle is its navigation bar, titled with the document's header or, until the document has loaded, its
/// id. The fixture is `FRUS_UI_TEST_SEED_PROJECT`'s collection, which holds `d1` of `FRUS_UI_TEST_SEED_VOLUME`'s volume.
///
/// Version history:
///   1.0 — L19 (#1919, IPA-4): initial implementation
@MainActor
final class CollectionInspectorOpenDocumentTests: XCTestCase {

    /// `UITestProjectSeeder.collectionName`.
    private static let collectionName = "UI Test Unattached Collection"
    /// The seeded document's header, from the seeded volume.
    private static let documentHeader = "UI Test Document One"
    /// See `CollectionEditorTitleTests.patience`.
    private static let patience: TimeInterval = 30

    var app: XCUIApplication!

    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    override func tearDown() async throws {
        UITestPresentation.dismissAnyPresentation(in: app)
        app?.terminate()
        app = nil
        try await super.tearDown()
    }

    func testOpenDocumentInTheEntrysSettingsOpensTheReader() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_DISABLE_ANIMATIONS"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_PROJECT"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_VOLUME"] = "frus1961-63v06"
        app.launchArguments = UITestLaunch.arguments(startingOn: .collections)
        app.launch()
        XCTAssertTrue(navigator.select(.collections, resolveTimeout: 15).tapped, "Could not open the Collections tab")
        let collection = app.collectionViews.staticTexts[Self.collectionName].firstMatch
        XCTAssertTrue(collection.waitForExistence(timeout: Self.patience), "The seeded collection is not listed")
        collection.tap()
        XCTAssertTrue(app.navigationBars[Self.collectionName].waitForExistence(timeout: Self.patience),
                      "The seeded collection's editor did not open")

        let row = documentRowText(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: Self.patience), """
            The seeded document's row is not in Contents. Texts: \
            \(app.staticTexts.allElementsBoundByIndex.prefix(30).map(\.label).filter { !$0.isEmpty })
            """)
        row.tap()
        let open = app.buttons["collection.inspector.openDocument"].firstMatch
        XCTAssertTrue(open.waitForExistence(timeout: Self.patience), """
            The row's settings offer no Open Document. Buttons: \
            \(app.buttons.allElementsBoundByIndex.prefix(30).map(\.label).filter { !$0.isEmpty })
            """)
        attachScreenshot("The entry's settings")
        open.tap()

        let reader = app.navigationBars.matching(NSPredicate(format: "identifier IN %@",
                                                              [Self.documentHeader, "d1"])).firstMatch
        XCTAssertTrue(reader.waitForExistence(timeout: Self.patience), """
            Open Document did not open the reader. Bars: \(app.navigationBars.allElementsBoundByIndex.map(\.identifier))
            """)
        attachScreenshot("The reader")
        let back = app.buttons["BackButton"].firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: Self.patience), "The reader has no Back")
        back.tap()
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCTAssertTrue(app.navigationBars[Self.collectionName].waitForExistence(timeout: Self.patience),
                          "Back did not return to the collection")
            XCTAssertFalse(open.exists, "The Configure sheet is still up behind the reader")
        } else {
            XCTAssertTrue(open.waitForExistence(timeout: Self.patience),
                          "Back did not return to the entry's settings it was opened from")
        }
    }

    private func attachScreenshot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}

// MARK: - CollectionListExportTests (L35)

/// *Export…* from the Collections list (L35, the plan of record's lane 1), and a list row that opens anywhere along its
/// width (R4's finding).
///
/// ## What it holds
/// - `testTheRowsMenuExportOpensTheSheet`: a row's menu offers *Export…*, and it opens the export sheet for that
///   collection, whose sentence counts its one document. 1.0 (1861) exported only from inside a collection.
/// - `testARowOpensAnywhereAlongItsWidth`: a tap on the row's line, at 85% of the window's width and past its text,
///   opens the collection. R4 found, on an iPad, that a row opened only where its text was: its content shape had no
///   greedy frame to fill.
///
/// ## Devices
/// iPhone 17 and iPad Pro 13-inch (M5), `OS=27.0`; neither test skips. The seeded collection is
/// `UITestProjectSeeder`'s, one document, with the smart collection beside it (`FRUS_UI_TEST_SEED_SAVED_SEARCH`).
///
/// Version history:
///   1.0 — L35: initial implementation
@MainActor
final class CollectionListExportTests: XCTestCase {

    /// `UITestProjectSeeder.collectionName`, repeated because a UI-test target cannot import the app.
    private static let unattached = "UI Test Unattached Collection"
    private static let listTitle = "Collections"
    /// The export sheet's title, `export.nav.title`.
    private static let sheetTitle = "Export collection"
    private static let patience: TimeInterval = 30

    var app: XCUIApplication!

    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    override func tearDown() async throws {
        UITestPresentation.dismissAnyPresentation(in: app)
        app?.terminate()
        app = nil
        try await super.tearDown()
    }

    /// A row's menu offers *Export…*, which opens the export sheet for that collection.
    func testTheRowsMenuExportOpensTheSheet() throws {
        launch()
        listRow(Self.unattached).press(forDuration: 1.2)
        let export = app.buttons["Export…"].firstMatch
        XCTAssertTrue(export.waitForExistence(timeout: Self.patience),
                      "The row's menu has no Export…. Buttons: \(visibleButtonLabels())")
        export.tap()
        XCTAssertTrue(app.navigationBars[Self.sheetTitle].waitForExistence(timeout: Self.patience),
                      "Export… opened no export sheet. Bars: \(barTitles())")
        let sentence = app.descendants(matching: .any).matching(identifier: "collection.export.sentence").firstMatch
        XCTAssertTrue(sentence.waitForExistence(timeout: Self.patience), "The export sheet shows no sentence")
        XCTAssertTrue(waitUntil { sentence.label.contains("1 document") },
                      "The sheet's sentence does not count the collection's one document: \"\(sentence.label)\"")
    }

    /// A tap on the row's line past its text opens the collection, as a tap on its name does.
    func testARowOpensAnywhereAlongItsWidth() throws {
        launch()
        let name = listRow(Self.unattached)
        let window = app.windows.firstMatch.frame
        let text = name.frame
        // On the row's line, at 85% of the window's width: past the name on both idioms, and inside the row, whose
        // trailing edge is the list's inset from the window's.
        let x = window.minX + window.width * 0.85
        XCTAssertGreaterThan(x, text.maxX + 20, "The point is not past the row's text, so the test proves nothing: \(text)")
        name.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x - text.minX, dy: text.height / 2)).tap()
        let editor = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier IN %@", ["collection.editor.settings.row", "collection.editor.settings.button"]))
            .firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: Self.patience), """
            A tap at x \(Int(x)) on the row, past its text (x \(Int(text.minX))–\(Int(text.maxX))), did not open the \
            collection. Bars: \(barTitles())
            """)
    }

    // MARK: - Steps

    private func launch() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_DISABLE_ANIMATIONS"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_PROJECT"] = "1"
        app.launchArguments = UITestLaunch.arguments(startingOn: .collections)
        app.launch()
        XCTAssertTrue(navigator.select(.collections, resolveTimeout: 15).tapped,
                      "Could not open the Collections tab, so this suite would read another screen")
        XCTAssertTrue(app.navigationBars[Self.listTitle].waitForExistence(timeout: Self.patience),
                      "The Collections list is not showing. Bars: \(barTitles())")
        XCTAssertTrue(listRow(Self.unattached).waitForExistence(timeout: Self.patience),
                      "The seeded \"\(Self.unattached)\" is not listed")
    }

    /// The list's row whose name is `name`.
    private func listRow(_ name: String) -> XCUIElement {
        app.collectionViews.staticTexts[name].firstMatch
    }

    /// Polls `condition` until it holds or `timeout` passes, and reports whether it held.
    private func waitUntil(_ timeout: TimeInterval = CollectionListExportTests.patience,
                           _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return condition()
    }

    private func barTitles() -> String {
        app.navigationBars.allElementsBoundByIndex.map(\.identifier).joined(separator: " | ")
    }

    private func visibleButtonLabels() -> String {
        app.buttons.allElementsBoundByIndex.prefix(30).map(\.label).filter { !$0.isEmpty }.joined(separator: " | ")
    }
}

// MARK: - CollectionListRowActionsTests (L35, #2006)

/// What VoiceOver offers on a Collections list row: each of the row's menu items as an action (#2006's first item,
/// L35). 1.0 (1861) put Rename, Duplicate, Word Cloud, Create Static Snapshot and Delete in a context menu alone,
/// which VoiceOver does not offer.
///
/// ## How it reads them
/// iOS 27's VoiceOver service for UI tests turns VoiceOver on, moves its cursor and returns what it spoke; a flick up
/// with VoiceOver on moves through the focused element's actions, which VoiceOver speaks, its own *Activate Default*
/// last (`SearchResultVoiceOverTests` measured the service). It cannot make VoiceOver do an action, so the test reads
/// each action's name; `CollectionListRowActionWiringTests` holds each action to the menu item's own call.
///
/// ## Devices
/// iPhone 17 and iPad Pro 13-inch (M5), `OS=27.0`: one test, which skips below iOS 27. Under Xcode 27.2 VoiceOver
/// stays on once its speech has been read, so run it alone, on a simulator shut down before it (the
/// `SearchResultVoiceOverTests` entry of `Planning/UI-Test-Destinations-Runbook.md`).
///
/// Version history:
///   1.0 — L35 (#2006): initial implementation
@MainActor
final class CollectionListRowActionsTests: XCTestCase {

    /// `UITestProjectSeeder.collectionName` and `UITestSavedSearchSeeder.collectionName`.
    private static let unattached = "UI Test Unattached Collection"
    private static let smart = "UI Test Smart Collection"
    private static let listTitle = "Collections"
    private static let patience: TimeInterval = 30
    /// VoiceOver's own action, which it reads last.
    private static let activateDefault = "Activate Default"

    var app: XCUIApplication!

    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    override func setUp() async throws {
        continueAfterFailure = false
        turnVoiceOverOff()
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDown() async throws {
        turnVoiceOverOff()
        UITestPresentation.dismissAnyPresentation(in: app)
        app?.terminate()
        app = nil
        try await super.tearDown()
    }

    /// Each row offers its menu's items as VoiceOver actions, in the menu's order; a smart collection's adds Create
    /// Static Snapshot. Delete is the row's swipe, which VoiceOver offers of itself.
    func testEachRowOffersItsMenuAsActions() throws {
        guard #available(iOS 27.0, *) else { throw XCTSkip("Listens through iOS 27's VoiceOver service") }
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_DISABLE_ANIMATIONS"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_PROJECT"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_SAVED_SEARCH"] = "linked"
        app.launchArguments = UITestLaunch.arguments(startingOn: .collections)
        app.launch()
        XCTAssertTrue(navigator.select(.collections, resolveTimeout: 15).tapped,
                      "Could not open the Collections tab, so this suite would read another screen")
        XCTAssertTrue(app.navigationBars[Self.listTitle].waitForExistence(timeout: Self.patience),
                      "The Collections list is not showing")
        for name in [Self.unattached, Self.smart] {
            XCTAssertTrue(app.collectionViews.staticTexts[name].firstMatch.waitForExistence(timeout: Self.patience),
                          "The seeded \"\(name)\" is not listed")
        }

        // Every tap is done; from here on only VoiceOver moves.
        let voiceOver = XCUIDevice.shared.voiceOverService
        try voiceOver.enable()
        var heard: [String: [String]] = [:]
        var spokenOnTheWay: [String] = []
        for _ in 1...40 where heard.count < 2 {
            let spoken = try voiceOver.moveForward().utterance
            guard let name = [Self.unattached, Self.smart].first(where: { spoken.hasPrefix($0) }),
                  heard[name] == nil else {
                spokenOnTheWay.append(spoken)
                continue
            }
            heard[name] = try flickThroughTheActions(of: voiceOver)
        }
        try voiceOver.disable()

        print("[L35 VoiceOver] actions: \(heard)")
        let menu = ["Export…", "Rename", "Duplicate", "Word Cloud"]
        let unattached = try XCTUnwrap(heard[Self.unattached], "VoiceOver never reached \(Self.unattached): \(spokenOnTheWay)")
        let smart = try XCTUnwrap(heard[Self.smart], "VoiceOver never reached \(Self.smart): \(spokenOnTheWay)")
        // Delete is the row's swipe, which VoiceOver offers of itself: on 1.0's rows it read "Delete" twice and nothing
        // else. The menu's actions leave it out, so it is required and read apart from the menu's order.
        XCTAssertEqual(unattached.filter { $0 != "Delete" }, menu,
                       "The actions VoiceOver offers on \(Self.unattached)'s row, in order: \(unattached)")
        XCTAssertEqual(smart.filter { $0 != "Delete" }, menu + ["Create Static Snapshot"],
                       "The actions VoiceOver offers on \(Self.smart)'s row, in order: \(smart)")
        XCTAssertTrue(unattached.contains("Delete"), "VoiceOver offers no Delete on \(Self.unattached)'s row: \(unattached)")
        XCTAssertTrue(smart.contains("Delete"), "VoiceOver offers no Delete on \(Self.smart)'s row: \(smart)")
    }

    /// Flicks up through the focused element's actions until VoiceOver reads its own *Activate Default*, which it
    /// reads last, or has flicked ten times.
    ///
    /// - Returns: The actions spoken before *Activate Default*, in order.
    @available(iOS 27.0, *)
    private func flickThroughTheActions(of voiceOver: XCUIVoiceOverService) throws -> [String] {
        var spoken: [String] = []
        for _ in 1...10 {
            app.swipeUp()
            let action = try voiceOver.currentSpeech().utterance
            if action == Self.activateDefault { break }
            spoken.append(action)
        }
        return spoken
    }

    /// Turns VoiceOver off if a test left it on.
    private func turnVoiceOverOff() {
        guard #available(iOS 27.0, *) else { return }
        let voiceOver = XCUIDevice.shared.voiceOverService
        if voiceOver.isEnabled { try? voiceOver.disable() }
    }
}

// MARK: - CollectionExportSheetFitTests (L35)

/// The export sheet, opened from the Collections list, at the default text size, AX3 and AX5 on an iPhone 17 and an
/// iPhone SE (L35; the third review's J9): it opens on its sentence, with its format and Export in view.
///
/// ## What it measures
/// The sheet of `UITestProjectSeeder`'s export collection (`FRUS_UI_TEST_SEED_PROJECT=export`), whose sentence is the
/// longest a realistic collection's is (its doc says why), launched as a device whose Apple Intelligence is off
/// (`FRUS_UI_TEST_APPLE_INTELLIGENCE=notEnabled`), so that the sheet also says what it lacks. Once the sentence has been
/// counted, it reads from one snapshot the window, the navigation bar, the sentence, the line of what the device lacks,
/// the format, Export and the bar at the sheet's foot, and requires each inside the window's width; the sentence whole
/// between the navigation bar and the bar at every size, which it is since it is drawn no larger than AX1 (decision
/// 221); the line of what the device lacks under it, whole above the bar at the default size and at the
/// accessibility sizes begun at least a line above the bar; at the default size the chosen card above the bar; at the
/// accessibility sizes the format's menu inside the bar; and Export inside the bar and the window. Each run's
/// `[L35 fit]` line prints where each ends, and a screenshot is kept. The menu, which the sheet draws only at an
/// accessibility size, is the proof that the size took effect; the card, which it draws only at a standard size, at
/// the default.
///
/// ## On 1.0 (1861)
/// The row's menu has no Export…, so each test fails at its first step. 1.0's sheet itself, opened through the editor,
/// is measured in the suite's runbook entry (`Planning/UI-Test-Destinations-Runbook.md`). L35's sheet drew the sentence
/// at the reader's size until decision 221, and it ran under the bar at AX3 on the SE and at AX5 on both.
///
/// ## Devices
/// iPhone 17 and iPhone SE (3rd generation), `OS=27.0`; iPhone-only, it self-skips at iPad width, where the sheet is a
/// form sheet with room to spare.
///
/// Version history:
///   1.0 — L35 (J9, decision 221): initial implementation
@MainActor
final class CollectionExportSheetFitTests: XCTestCase {

    /// `UITestProjectSeeder.exportCollectionName`.
    private static let exportCollection = "UI Test Export Collection"
    private static let listTitle = "Collections"
    /// The export sheet's title, `export.nav.title`.
    private static let sheetTitle = "Export collection"
    /// The seeded collection's sentence begins so: it counts six documents.
    private static let sentenceOpening = "6 documents:"
    private static let patience: TimeInterval = 30
    private static let phoneOnlyReason =
        "iPhone-only: at iPad width the export sheet is a form sheet with room to spare, so a pass there is not evidence"
    /// A line of the sheet's text at AX1, the largest it is drawn at, rounded up: what must show above the bar for the
    /// line of what the device lacks to be begun.
    private static let oneLine: CGFloat = 40

    var app: XCUIApplication!

    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    override func tearDown() async throws {
        UITestPresentation.dismissAnyPresentation(in: app)
        app?.terminate()
        app = nil
        try await super.tearDown()
    }

    func testTheSheetFitsAtTheDefaultSize() throws {
        try assertSheetFits(at: nil, named: "L")
    }

    func testTheSheetFitsAtAX3() throws {
        try assertSheetFits(at: "UICTContentSizeCategoryAccessibilityXL", named: "AX3")
    }

    func testTheSheetFitsAtAX5() throws {
        try assertSheetFits(at: "UICTContentSizeCategoryAccessibilityXXXL", named: "AX5")
    }

    // MARK: - The measurement

    private func assertSheetFits(at category: String?, named size: String) throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, Self.phoneOnlyReason)
        launch(at: category)
        let row = app.collectionViews.staticTexts[Self.exportCollection].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: Self.patience), "The seeded \"\(Self.exportCollection)\" is not listed")
        row.press(forDuration: 1.2)
        let export = app.buttons["Export…"].firstMatch
        XCTAssertTrue(export.waitForExistence(timeout: Self.patience), "The row's menu has no Export… at \(size)")
        export.tap()
        let bar = app.navigationBars[Self.sheetTitle]
        XCTAssertTrue(bar.waitForExistence(timeout: Self.patience), "Export… opened no export sheet at \(size)")
        let sentence = element("collection.export.sentence")
        XCTAssertTrue(sentence.waitForExistence(timeout: Self.patience), "The sheet never counted what it will print")
        XCTAssertTrue(sentence.label.hasPrefix(Self.sentenceOpening),
                      "The sheet counts another collection: \"\(sentence.label)\"")
        // The sentence replaced the spinner: let the form settle before it is read.
        Thread.sleep(forTimeInterval: 1)

        let accessibility = category?.contains("Accessibility") == true
        let formatId = accessibility ? "collection.export.format.menu" : "collection.export.format.pdf"
        let frames = try snapshotFrames(["collection.export.sentence", "collection.export.lacks", formatId,
                                         "collection.export.run", "collection.export.bar"])
        let window = app.windows.firstMatch.frame
        let navFoot = bar.frame.maxY
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "L35 fit \(size)"
        shot.lifetime = .keepAlways
        add(shot)
        print("[L35 fit] \(size) window \(Int(window.width))x\(Int(window.height)) nav foot \(Int(navFoot)): "
              + frames.sorted { $0.key < $1.key }.map { id, f in
                  "\(id.replacingOccurrences(of: "collection.export.", with: "")) "
                  + "x \(Int(f.minX))–\(Int(f.maxX)) y \(Int(f.minY))–\(Int(f.maxY))" }
                  .joined(separator: ", "))

        let sentenceFrame = try XCTUnwrap(frames["collection.export.sentence"], "no sentence in the snapshot at \(size)")
        // The line of what the device lacks starts under the sentence, which is drawn no larger than AX1, so the form
        // has built its row at every size.
        let lacks = try XCTUnwrap(frames["collection.export.lacks"],
                                  "The sheet does not say what this device lacks at \(size), or the line is below the screen")
        let missingFormat = accessibility
            ? "the menu is drawn only at an accessibility size, so the size did not take effect"
            : "the cards are drawn only at a standard size"
        let format = try XCTUnwrap(frames[formatId], "No \(formatId) at \(size): \(missingFormat)")
        let run = try XCTUnwrap(frames["collection.export.run"], "no Export in the snapshot at \(size)")
        let foot = try XCTUnwrap(frames["collection.export.bar"], "no bar at the sheet's foot at \(size)")

        for (name, frame) in [("sentence", sentenceFrame), ("lacks", lacks), ("format", format), ("Export", run)] {
            XCTAssertGreaterThanOrEqual(frame.minX, window.minX - 0.5, "\(name) runs off the leading edge at \(size): \(frame)")
            XCTAssertLessThanOrEqual(frame.maxX, window.maxX + 0.5, "\(name) runs off the trailing edge at \(size): \(frame)")
            XCTAssertGreaterThan(frame.height, 0, "\(name) has no height at \(size)")
        }
        // The sheet opens on its sentence, whole between the navigation bar and the bar at every size (decision
        // 221), and the line of what the device lacks follows it.
        XCTAssertGreaterThanOrEqual(sentenceFrame.minY, navFoot - 0.5,
                                    "The sentence starts under the navigation bar at \(size): \(sentenceFrame), bar foot \(navFoot)")
        XCTAssertLessThanOrEqual(sentenceFrame.maxY, foot.minY + 0.5, """
            The sentence runs under the bar at \(size): it ends at \(sentenceFrame.maxY), the bar starts at \(foot.minY)
            """)
        XCTAssertLessThanOrEqual(sentenceFrame.maxY, lacks.minY + 0.5, "The sentence runs into what the device lacks at \(size)")
        if accessibility {
            // Under a long sentence at AX1 the line may continue under the bar, where the form scrolls: it is begun above it.
            XCTAssertLessThanOrEqual(lacks.minY, foot.minY - Self.oneLine, """
                What this device lacks starts too low to be read at \(size): it starts at \(lacks.minY), the bar at \(foot.minY)
                """)
            XCTAssertGreaterThanOrEqual(format.minY, foot.minY - 0.5, "The format menu is not in the bar at \(size)")
            XCTAssertLessThanOrEqual(format.maxY, run.minY + 0.5, "The format menu runs into Export at \(size)")
        } else {
            XCTAssertLessThanOrEqual(lacks.maxY, foot.minY + 0.5, """
                What this device lacks runs under the bar at \(size): it ends at \(lacks.maxY), the bar starts at \(foot.minY)
                """)
            XCTAssertGreaterThanOrEqual(format.minY, lacks.maxY - 0.5, "The chosen card is above what the device lacks at \(size)")
            XCTAssertLessThanOrEqual(format.maxY, foot.minY + 0.5, """
                The chosen card, PDF, runs under the bar at \(size): it ends at \(format.maxY), the bar starts at \(foot.minY)
                """)
        }
        XCTAssertGreaterThanOrEqual(run.minY, foot.minY - 0.5, "Export is not in the bar at \(size)")
        XCTAssertLessThanOrEqual(run.maxY, window.maxY + 0.5, "Export runs off the foot of the screen at \(size): \(run)")
        XCTAssertTrue(app.buttons["collection.export.run"].isHittable, "Export cannot be tapped at \(size)")
    }

    // MARK: - Steps and queries

    private func launch(at category: String?) {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_DISABLE_ANIMATIONS"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_PROJECT"] = "export"
        app.launchEnvironment["FRUS_UI_TEST_APPLE_INTELLIGENCE"] = "notEnabled"
        app.launchArguments = UITestLaunch.arguments(startingOn: .collections, contentSizeCategory: category)
        app.launch()
        XCTAssertTrue(navigator.select(.collections, resolveTimeout: 15).tapped,
                      "Could not open the Collections tab, so this suite would read another screen")
        XCTAssertTrue(app.navigationBars[Self.listTitle].waitForExistence(timeout: Self.patience),
                      "The Collections list is not showing")
    }

    /// The element whose identifier is `identifier`, of any type.
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// The frames of the elements whose identifiers are `identifiers`, read from one snapshot of the app: a read of
    /// each is a query of its own, which takes seconds under Xcode 27 (`SearchLayerBaseRowFitTests`).
    private func snapshotFrames(_ identifiers: [String]) throws -> [String: CGRect] {
        let wanted = Set(identifiers)
        var found: [String: CGRect] = [:]
        var stack = [try app.snapshot()]
        while let node = stack.popLast() {
            if wanted.contains(node.identifier), found[node.identifier] == nil { found[node.identifier] = node.frame }
            stack.append(contentsOf: node.children)
        }
        return found
    }
}

/// The seeded document's row text in a collection's Contents: the row speaks "Document UI Test Document One", the
/// document's header from the index after "Document", or "Document d1" while the volume is not yet indexed (L19).
@MainActor
func documentRowText(in app: XCUIApplication) -> XCUIElement {
    app.staticTexts.matching(NSPredicate(format: "label ENDSWITH %@ OR label ENDSWITH %@",
                                         "UI Test Document One", "Document d1")).firstMatch
}

// MARK: - CollectionFactsAccessibilityTests (L43)

/// Each control L43 adds speaks its name and its value (the design's §9 accessibility table, lane 3): what VoiceOver reads
/// for an element is its label and its value, which XCUI reads back.
///
/// - **A new collection's settings:** *Opening*, which a new collection sets to the volume's heading leading (decision
///   159), and *See also*, off, in step 1 since L44; *Citation style*, in the style Settings ▸ Display holds, History at
///   State in the UI-test store (decision 160); and *Wording*'s ten fields, each named "Contents, printed as" and valued
///   with the word it prints, on Wording's own screen since L44.
/// - **A section's sheet:** *Headnotes*, following the collection: *Follow the collection: Off* since L44.
/// - **A document's settings:** *Date line*, offered once the document has a title, and not before (decision 163).
///
/// **Run it on iPhone 17 and iPad Pro 13-inch (M5), both `OS=27.0`**: the iPhone pushes Collection settings and a
/// document's settings, the iPad presents both as sheets, and each is different code. The document's fixture is
/// `FRUS_UI_TEST_SEED_PROJECT`'s collection, which holds `d1` of `FRUS_UI_TEST_SEED_VOLUME`'s volume.
///
/// Version history:
///   1.0 — L43: initial implementation
///   1.1 — L44: Opening and See also in step 1, Wording a screen of its own, a section's Headnotes saying what it follows
@MainActor
final class CollectionFactsAccessibilityTests: XCTestCase {

    /// `UITestProjectSeeder.collectionName`.
    private static let collectionName = "UI Test Unattached Collection"
    /// The settings screen's (iPhone) and sheet's (iPad) navigation title.
    private static let settingsTitle = "Collection settings"
    /// The editor's title before a new collection has a name.
    private static let newTitle = "New Collection"
    /// See `CollectionEditorTitleTests.patience`.
    private static let patience: TimeInterval = 30
    /// The ten labels of the collection's Wording, by the name the stored map gives each, with the word the app prints.
    private static let wording: [(key: String, word: String)] = [
        ("contents", "Contents"), ("headnote", "Headnote"), ("summary", "Summary"), ("researchNote", "Research Note"),
        ("seeAlso", "See also:"), ("bibliography", "Bibliography"), ("chronology", "Chronology"),
        ("archivalSources", "Sources & Archives"), ("personsIndex", "Persons Index"), ("thematicIndex", "Thematic Index"),
    ]

    var app: XCUIApplication!

    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    override func tearDown() async throws {
        UITestPresentation.dismissAnyPresentation(in: app)
        app?.terminate()
        app = nil
        try await super.tearDown()
    }

    /// A new collection's Opening, Citation style, See also and Wording speak their names and values, and a section's
    /// Headnotes default does.
    func testTheCollectionsNewControlsSpeakTheirNameAndValue() throws {
        launch(seedingProject: false)
        let create = app.buttons["Create new collection"].firstMatch
        XCTAssertTrue(create.waitForExistence(timeout: Self.patience), "The Collections tab offers no New Collection")
        create.tap()
        XCTAssertTrue(app.navigationBars[Self.newTitle].waitForExistence(timeout: Self.patience),
                      "The new collection's editor did not open")

        // A section heading, whose sheet holds the section's Headnotes default.
        CollectionEditorAddMenu.open(in: app)
        let heading = app.buttons["Add Section Heading"].firstMatch
        XCTAssertTrue(heading.waitForExistence(timeout: Self.patience), "The Add menu has no Add Section Heading")
        heading.tap()
        let pill = app.buttons["Section defaults"].firstMatch
        XCTAssertTrue(pill.waitForExistence(timeout: Self.patience), "Add Section Heading added no heading row")
        pill.tap()
        let headnotes = reveal("collection.inspector.sectionHeadnote.picker", what: "Headnotes", under: nil)
        // L44 (the design's §4.2): the first choice says what it follows, where it read Default.
        assertSpeaks(headnotes, name: "Headnotes", value: "Follow the collection: Off",
                     what: "A section's Headnotes default")
        attachScreenshot("A section's sheet")
        let done = app.navigationBars.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: Self.patience), "The section's sheet has no Done")
        done.tap()

        // Collection settings: the ⚙ button's sheet on the iPad, the pushed screen on the iPhone.
        let button = element("collection.editor.settings.button")
        let row = element("collection.editor.settings.row")
        XCTAssertTrue(waitUntil { button.exists || row.exists }, "The editor offers no way into Collection settings")
        (button.exists ? button : row).tap()
        XCTAssertTrue(app.navigationBars[Self.settingsTitle].waitForExistence(timeout: Self.patience),
                      "Collection settings did not open")

        // L44: Opening and See also are step 1's, a screen of its own.
        let documents = reveal("collection.settings.documents.row", what: "Documents", under: Self.settingsTitle)
        documents.tap()
        XCTAssertTrue(app.navigationBars["Documents"].waitForExistence(timeout: Self.patience), "Documents did not open")
        let opening = reveal("composition.opening.picker", what: "Opening", under: "Documents")
        assertSpeaks(opening, name: "Opening", value: "The volume’s heading leads",
                     what: "A new collection's Opening (decision 159)")
        let seeAlso = reveal("composition.seeAlso.toggle", what: "See also", under: "Documents")
        XCTAssertTrue(seeAlso.label.hasPrefix("See also"), "See also is named \"\(seeAlso.label)\"")
        XCTAssertEqual(seeAlso.value as? String, "0", "See also does not speak Off for a new collection")
        attachScreenshot("Document content")
        let back = app.navigationBars["Documents"].buttons["BackButton"]
        XCTAssertTrue(back.waitForExistence(timeout: Self.patience), "Documents has no Back")
        back.tap()
        XCTAssertTrue(app.navigationBars[Self.settingsTitle].waitForExistence(timeout: Self.patience),
                      "Back did not return to Collection settings")

        let style = reveal("composition.citationStyle.picker", what: "Citation style", under: Self.settingsTitle)
        assertSpeaks(style, name: "Citation style", value: "History at State",
                     what: "A new collection's Citation style, Settings ▸ Display's (decision 160)")
        let wording = reveal("composition.wording.group", what: "Wording", under: Self.settingsTitle)
        XCTAssertTrue(wording.label.contains("Wording"), "Wording is named \"\(wording.label)\"")
        wording.tap()
        // L44: Wording is a row that opens a screen of the ten fields.
        XCTAssertTrue(app.navigationBars["Wording"].waitForExistence(timeout: Self.patience), "Wording did not open")
        for (key, word) in Self.wording {
            // By its identifier, or by the name VoiceOver reads, which is what this test is about.
            let field = reveal(app.textFields.matching(NSPredicate(format: "identifier == %@ OR label == %@",
                                                                   "composition.wording.field.\(key)",
                                                                   "\(word), printed as")).firstMatch,
                               what: "Wording's \(word)", under: "Wording")
            XCTAssertEqual(field.label, "\(word), printed as", "Wording's \(key) field is named \"\(field.label)\"")
            XCTAssertEqual(field.value as? String, word, "Wording's \(key) field does not speak the word it prints")
        }
        attachScreenshot("Citations & wording")
    }

    /// A document's Date line is offered once it has a title, and speaks its name and the line typed into it.
    func testTheDocumentsDateLineSpeaksItsNameAndValue() throws {
        launch(seedingProject: true)
        let collection = app.collectionViews.staticTexts[Self.collectionName].firstMatch
        XCTAssertTrue(collection.waitForExistence(timeout: Self.patience), "The seeded collection is not listed")
        collection.tap()
        XCTAssertTrue(app.navigationBars[Self.collectionName].waitForExistence(timeout: Self.patience),
                      "The seeded collection's editor did not open")
        let row = documentRowText(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: Self.patience), "The seeded document's row is not in Contents")
        row.tap()
        // By identifier: a form's text field shows no title, and iOS 27 names it by its placeholder alone.
        let title = element("collection.inspector.titleOverride.field")
        XCTAssertTrue(title.waitForExistence(timeout: Self.patience), "The document's settings have no Title override")
        let dateLine = element("collection.inspector.dateLine.field")
        XCTAssertFalse(dateLine.exists, "A date line is offered before the document has a title (decision 163)")

        title.tap()
        title.typeText("The first letter")
        XCTAssertTrue(dateLine.waitForExistence(timeout: Self.patience), "A title did not bring the Date line")
        XCTAssertEqual(dateLine.label, "Date line", "The date line is named \"\(dateLine.label)\"")
        dateLine.tap()
        dateLine.typeText("Washington, 26 January 1961")
        XCTAssertTrue(waitUntil { (dateLine.value as? String) == "Washington, 26 January 1961" },
                      "The date line does not speak what was typed: \(dateLine.value ?? "nil")")
        attachScreenshot("A document's date line")
    }

    // MARK: - Helpers

    private func launch(seedingProject: Bool) {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_DISABLE_ANIMATIONS"] = "1"
        if seedingProject {
            app.launchEnvironment["FRUS_UI_TEST_SEED_PROJECT"] = "1"
            app.launchEnvironment["FRUS_UI_TEST_SEED_VOLUME"] = "frus1961-63v06"
        }
        app.launchArguments = UITestLaunch.arguments(startingOn: .collections)
        app.launch()
        XCTAssertTrue(navigator.select(.collections, resolveTimeout: 15).tapped, "Could not open the Collections tab")
    }

    /// What VoiceOver reads for `element` — its label, then its value — holds `name` and `value`.
    private func assertSpeaks(_ element: XCUIElement, name: String, value: String, what: String) {
        let spoken = [element.label, (element.value as? String) ?? ""].filter { !$0.isEmpty }.joined(separator: ", ")
        XCTAssertTrue(spoken.contains(name) && spoken.contains(value), "\(what) speaks \"\(spoken)\"")
    }

    /// The element `identifier` names, dragged up into view, under the bar titled `bar` where one is given (so a drag
    /// on a sheet never lands on the window around it), else at the window's leading edge.
    private func reveal(_ identifier: String, what: String, under bar: String?) -> XCUIElement {
        reveal(element(identifier), what: "\(what) (\(identifier))", under: bar)
    }

    /// `target`, dragged up into view as `reveal(_:what:under:)` drags.
    private func reveal(_ target: XCUIElement, what: String, under bar: String?) -> XCUIElement {
        let origin = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
        let top = bar.map { app.navigationBars[$0].frame } ?? app.navigationBars.firstMatch.frame
        var drags = 0
        while !(target.exists && target.isHittable) && drags < 14 {
            let x = top.minX + 24
            let start = origin.withOffset(CGVector(dx: x, dy: top.maxY + 360))
            let end = origin.withOffset(CGVector(dx: x, dy: top.maxY + 60))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .fast, thenHoldForDuration: 0.3)
            drags += 1
        }
        XCTAssertTrue(target.exists, "\(what) is not on screen, after \(drags) drag(s)")
        return target
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func waitUntil(_ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(Self.patience)
        while Date() < deadline {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return condition()
    }

    private func attachScreenshot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}

// MARK: - CollectionSettingsDriver (L44)

/// Drives a collection's settings for L44's suites: a new collection, Collection settings by whichever route the layout
/// draws (the iPad's ⚙ sheet, the iPhone's pushed screen), a step's screen, and the rows on it. Every wait is 30 s, as
/// `CollectionEditorTitleTests.patience` explains, and frames are read from one snapshot where several are needed.
@MainActor
struct CollectionSettingsDriver {
    /// The app under test.
    let app: XCUIApplication

    static let patience: TimeInterval = 30
    static let settingsTitle = "Collection settings"
    static let documentsTitle = "Documents"
    static let apparatusTitle = "Apparatus"

    /// The element whose identifier is `identifier`, of any type.
    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Opens a new collection's editor from the Collections list.
    func createCollection() {
        let create = app.buttons["Create new collection"].firstMatch
        XCTAssertTrue(create.waitForExistence(timeout: Self.patience), "The Collections tab offers no New Collection")
        create.tap()
        XCTAssertTrue(app.navigationBars["New Collection"].waitForExistence(timeout: Self.patience),
                      "The new collection's editor did not open")
    }

    /// Opens Collection settings through whichever control the layout drew, and waits for it. Returns whether it is
    /// the iPad's sheet.
    @discardableResult
    func openSettings() -> Bool {
        let button = element("collection.editor.settings.button")
        let row = element("collection.editor.settings.row")
        XCTAssertTrue(waitUntil { button.exists || row.exists }, "The editor offers no way into Collection settings")
        let isSheet = button.exists
        (isSheet ? button : row).tap()
        XCTAssertTrue(app.navigationBars[Self.settingsTitle].waitForExistence(timeout: Self.patience),
                      "Collection settings did not open")
        return isSheet
    }

    /// Opens a step from its row in Collection settings, and waits for its screen.
    func openStep(_ rowIdentifier: String, title: String) {
        let row = reveal(element(rowIdentifier), what: "the \(title) row", under: Self.settingsTitle)
        row.tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: Self.patience), "The \(title) step did not open")
    }

    /// Taps the Back button in the bar titled `title`, and waits for that bar to go.
    func back(from title: String) {
        let back = app.navigationBars[title].buttons["BackButton"]
        XCTAssertTrue(back.waitForExistence(timeout: Self.patience), "The \(title) screen has no Back button")
        back.tap()
        XCTAssertTrue(waitUntil { !app.navigationBars[title].exists }, "Back did not leave \(title)")
    }

    /// `target`, dragged up into view under the bar titled `bar`, so a drag on a sheet never lands on the window
    /// around it.
    @discardableResult
    func reveal(_ target: XCUIElement, what: String, under bar: String) -> XCUIElement {
        let origin = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
        let top = app.navigationBars[bar].frame
        var drags = 0
        while !(target.exists && target.isHittable) && drags < 14 {
            let x = top.minX + 24
            let start = origin.withOffset(CGVector(dx: x, dy: top.maxY + 360))
            let end = origin.withOffset(CGVector(dx: x, dy: top.maxY + 60))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .fast, thenHoldForDuration: 0.3)
            drags += 1
        }
        XCTAssertTrue(target.exists && target.isHittable, "\(what) is not on screen, after \(drags) drag(s)")
        return target
    }

    /// The frames of the elements whose identifiers are `identifiers`, from one snapshot of the app.
    func frames(_ identifiers: [String]) throws -> [String: CGRect] {
        let wanted = Set(identifiers)
        var found: [String: CGRect] = [:]
        var stack = [try app.snapshot()]
        while let node = stack.popLast() {
            if wanted.contains(node.identifier), found[node.identifier] == nil { found[node.identifier] = node.frame }
            stack.append(contentsOf: node.children)
        }
        return found
    }

    /// Polls `condition` until it holds or 30 s pass, and reports whether it held.
    func waitUntil(_ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(Self.patience)
        while Date() < deadline {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return condition()
    }

    /// The text VoiceOver reads for `element`: its label, then its value.
    static func spoken(_ element: XCUIElement) -> String {
        [element.label, (element.value as? String) ?? ""].filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

// MARK: - CollectionTemplateStepsTests (L44)

/// The collection's settings in two steps (L44; the Collections design's §4.3 and §5.2): the rows that say what each
/// step holds, a template's card that writes step 1's seven and says what changed with *Undo*, step 2's shortcuts and
/// the one tap on its row, which only adds, and a section's sheet that holds the section's own settings, each saying
/// what it follows, with the count at the collection that clears them.
///
/// ## Devices
/// iPhone 17 and iPad Pro 13-inch (M5), both `OS=27.0`: the iPhone pushes Collection settings and each step in the
/// editor's stack, the iPad pushes each step in the settings sheet's own stack, and each is different code. It never
/// skips. Allow 600 s a test.
///
/// ## On the code before L44
/// The settings have no step rows, so each test fails at its first step row.
///
/// Version history:
///   1.0 — L44: initial implementation
@MainActor
final class CollectionTemplateStepsTests: XCTestCase {

    var app: XCUIApplication!
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }
    private var driver: CollectionSettingsDriver { CollectionSettingsDriver(app: app) }

    override func tearDown() async throws {
        UITestPresentation.dismissAnyPresentation(in: app)
        app?.terminate()
        app = nil
        try await super.tearDown()
    }

    /// A new collection's rows say what it is (J26), a card writes its seven with the line and *Undo* under it (J17),
    /// and *Undo* puts back what was there.
    func testATemplateSaysWhatChangedAndUndoPutsItBack() throws {
        launch()
        driver.createCollection()
        driver.openSettings()

        let documents = driver.element("collection.settings.documents.row")
        XCTAssertTrue(documents.waitForExistence(timeout: CollectionSettingsDriver.patience), "No Documents row")
        XCTAssertEqual(documents.value as? String, "Like Full text as printed · 2 differ",
                       "A new collection's Documents row does not say which template it is like (J26)")
        let apparatus = driver.element("collection.settings.apparatus.row")
        XCTAssertEqual(apparatus.value as? String, "Contents by citation", "A new collection's Apparatus row")

        driver.openStep("collection.settings.documents.row", title: CollectionSettingsDriver.documentsTitle)
        let differences = driver.element("collection.documents.differences")
        XCTAssertTrue(differences.waitForExistence(timeout: CollectionSettingsDriver.patience),
                      "Step 1 does not say how a new collection differs from the template it is like")
        let card = driver.element("collection.template.fullTextAsPrinted")
        XCTAssertNotEqual(card.value as? String, "Active", "Full text as printed is drawn in force on a new collection")
        card.tap()

        let line = driver.element("collection.documents.change")
        XCTAssertTrue(line.waitForExistence(timeout: CollectionSettingsDriver.patience), "A card's choice wrote no line")
        XCTAssertEqual(line.label, "Changed Archival source note from Off to On and Research notes from On to Off.")
        let undo = driver.element("collection.documents.change.undo")
        XCTAssertTrue(undo.isHittable, "The line's Undo is not in view where the choice was made (J17)")
        XCTAssertEqual(card.value as? String, "Active", "The chosen card is not drawn in force")
        attachScreenshot("Step 1 after a card")

        undo.tap()
        XCTAssertTrue(driver.waitUntil { !line.exists }, "Undo left the line")
        XCTAssertTrue(driver.waitUntil { (card.value as? String) != "Active" }, "Undo left the template in force")
        driver.back(from: CollectionSettingsDriver.documentsTitle)
        XCTAssertEqual(documents.value as? String, "Like Full text as printed · 2 differ",
                       "Undo did not put the collection's seven back")
    }

    /// The one tap on step 2's row adds the chosen template's suggested set, names every block it adds, and its Undo
    /// stands where it stood (J14); step 2's All and None add and remove, with the line and Undo where they were chosen.
    func testStepTwoAddsTheSuggestedSetAndItsShortcutsAddAndRemove() throws {
        launch()
        driver.createCollection()
        driver.openSettings()
        driver.openStep("collection.settings.documents.row", title: CollectionSettingsDriver.documentsTitle)
        driver.element("collection.template.fullTextAsPrinted").tap()
        XCTAssertTrue(driver.element("collection.documents.change").waitForExistence(timeout: CollectionSettingsDriver.patience))
        driver.back(from: CollectionSettingsDriver.documentsTitle)

        let offer = driver.element("collection.settings.offer")
        XCTAssertTrue(offer.waitForExistence(timeout: CollectionSettingsDriver.patience),
                      "Step 2's row offers no suggested set after a template")
        XCTAssertEqual(offer.label, "Add Bibliography, Sources & Archives and Note on the Text")
        offer.tap()
        let apparatus = driver.element("collection.settings.apparatus.row")
        XCTAssertTrue(driver.waitUntil {
            (apparatus.value as? String) == "Contents by citation · Bibliography · Sources & Archives · Note on the Text"
        }, "The one tap's blocks are not on the Apparatus row: \(apparatus.value ?? "nil")")
        let offerUndo = driver.element("collection.settings.offer.change.undo")
        XCTAssertTrue(offerUndo.waitForExistence(timeout: CollectionSettingsDriver.patience), "The one tap left no Undo")
        offerUndo.tap()
        XCTAssertTrue(driver.waitUntil { (apparatus.value as? String) == "Contents by citation" },
                      "Undo did not take the one tap's blocks back out: \(apparatus.value ?? "nil")")

        driver.openStep("collection.settings.apparatus.row", title: CollectionSettingsDriver.apparatusTitle)
        driver.element("collection.apparatus.all").tap()
        let line = driver.element("collection.apparatus.change")
        XCTAssertTrue(line.waitForExistence(timeout: CollectionSettingsDriver.patience), "All wrote no line")
        XCTAssertEqual(line.label, "Added Bibliography, Chronology, Sources & Archives, Persons Index, Thematic Index "
                       + "and Note on the Text. Word-cloud overview on.")
        XCTAssertTrue(driver.element("collection.apparatus.change.undo").isHittable, "All's Undo is not in view (J17)")
        let bibliography = driver.element("collection.apparatus.block.bibliography")
        XCTAssertEqual(bibliography.value as? String, "1", "Bibliography's tick does not say the collection has it")

        driver.element("collection.apparatus.none").tap()
        XCTAssertTrue(driver.waitUntil { line.label.hasPrefix("Removed Bibliography") },
                      "None's line does not say what it removed: \(line.label)")
        XCTAssertTrue(driver.waitUntil { (bibliography.value as? String) == "0" }, "None left Bibliography ticked")
        attachScreenshot("Step 2 after None")
        driver.element("collection.apparatus.change.undo").tap()
        XCTAssertTrue(driver.waitUntil { (bibliography.value as? String) == "1" }, "Undo did not put None's blocks back")
    }

    /// A section's sheet holds the section's own settings and nothing of the collection's, each choice saying what it
    /// follows; a setting the section sets for itself is counted at the collection, and *Clear* returns it to following.
    func testASectionsSheetHoldsItsOwnAndTheCollectionCountsAndClearsThem() throws {
        launch()
        driver.createCollection()
        CollectionEditorAddMenu.open(in: app)
        let heading = app.buttons["Add Section Heading"].firstMatch
        XCTAssertTrue(heading.waitForExistence(timeout: CollectionSettingsDriver.patience), "No Add Section Heading")
        heading.tap()
        let pill = app.buttons["Section defaults"].firstMatch
        XCTAssertTrue(pill.waitForExistence(timeout: CollectionSettingsDriver.patience), "No section heading row")
        pill.tap()

        let footnotes = driver.element("collection.inspector.footnotes.picker")
        XCTAssertTrue(footnotes.waitForExistence(timeout: CollectionSettingsDriver.patience), "The sheet has no Footnotes")
        XCTAssertFalse(driver.element("collection.attributes.subtitle.field").exists,
                       "The section's sheet still holds the collection's Subtitle")
        XCTAssertEqual(CollectionSettingsDriver.spoken(footnotes), "Footnotes, Follow the collection: On")
        XCTAssertEqual(CollectionSettingsDriver.spoken(driver.element("collection.inspector.highlights.picker")),
                       "Highlights in body, Follow the collection: Off")
        XCTAssertEqual(CollectionSettingsDriver.spoken(driver.element("collection.inspector.sectionHeadnote.picker")),
                       "Headnotes, Follow the collection: Off")
        attachScreenshot("A section's sheet")
        footnotes.tap()
        let off = app.buttons["Off"].firstMatch
        XCTAssertTrue(off.waitForExistence(timeout: CollectionSettingsDriver.patience), "Footnotes' menu has no Off")
        off.tap()
        XCTAssertTrue(driver.waitUntil { (footnotes.value as? String) == "Off" }, "Footnotes did not take Off")
        let done = app.navigationBars.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: CollectionSettingsDriver.patience), "The section's sheet has no Done")
        done.tap()

        driver.openSettings()
        driver.openStep("collection.settings.documents.row", title: CollectionSettingsDriver.documentsTitle)
        let count = driver.reveal(driver.element("collection.setting.footnotes.own"), what: "Footnotes' count",
                                  under: CollectionSettingsDriver.documentsTitle)
        XCTAssertEqual(count.label, "1 sets its own", "The count at the collection is not a button with its words")
        count.tap()
        XCTAssertTrue(app.navigationBars["Footnotes"].waitForExistence(timeout: CollectionSettingsDriver.patience),
                      "The count opened no list")
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Untitled section")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: CollectionSettingsDriver.patience), "The list does not name the section")
        row.tap()
        driver.element("collection.setting.own.clear").tap()
        XCTAssertTrue(driver.waitUntil { !row.exists }, "Clear left the section in the list")
        driver.back(from: "Footnotes")
        XCTAssertTrue(driver.waitUntil { !driver.element("collection.setting.footnotes.own").exists },
                      "The count stayed after Clear")
    }

    private func launch() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_DISABLE_ANIMATIONS"] = "1"
        app.launchArguments = UITestLaunch.arguments(startingOn: .collections)
        app.launch()
        XCTAssertTrue(navigator.select(.collections, resolveTimeout: 15).tapped, "Could not open the Collections tab")
    }

    private func attachScreenshot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}

// MARK: - CollectionInspectorSwitchNamesTests (L44, #2006)

/// Each research note's switch in a document's settings is named by the note's opening words, so two notes are two
/// switches VoiceOver can tell apart (#2006's second item): what VoiceOver reads for a switch is its label, which XCUI
/// reads back. The document is `UITestProjectSeeder`'s export collection's `d1`, which holds the seeder's note and,
/// with `FRUS_UI_TEST_SEED_NOTE_DOCUMENT=d1`, `UITestResearchSeeder`'s.
///
/// ## Devices
/// iPhone 17 and iPad Pro 13-inch (M5), both `OS=27.0`: the iPhone's drill-in and the iPad's Configure sheet. Never
/// skips. Allow 600 s.
///
/// ## On the code before L44
/// Both switches read "Include this research note when notes apply", so the test fails at its count of names.
///
/// Version history:
///   1.0 — L44: initial implementation
@MainActor
final class CollectionInspectorSwitchNamesTests: XCTestCase {

    var app: XCUIApplication!
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    override func tearDown() async throws {
        UITestPresentation.dismissAnyPresentation(in: app)
        app?.terminate()
        app = nil
        try await super.tearDown()
    }

    func testEachNotesSwitchIsNamedByItsOpeningWords() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_DISABLE_ANIMATIONS"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_PROJECT"] = "export"
        app.launchEnvironment["FRUS_UI_TEST_SEED_VOLUME"] = "frus1961-63v06"
        app.launchEnvironment["FRUS_UI_TEST_SEED_NOTE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_NOTE_DOCUMENT"] = "d1"
        app.launchArguments = UITestLaunch.arguments(startingOn: .collections)
        app.launch()
        XCTAssertTrue(navigator.select(.collections, resolveTimeout: 15).tapped, "Could not open the Collections tab")
        let driver = CollectionSettingsDriver(app: app)

        let collection = app.collectionViews.staticTexts["UI Test Export Collection"].firstMatch
        XCTAssertTrue(collection.waitForExistence(timeout: CollectionSettingsDriver.patience), "No export collection")
        collection.tap()
        let row = documentRowText(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: CollectionSettingsDriver.patience), "No d1 row in Contents")
        // On the iPad a row's Configure pill opens its settings; on the iPhone the row does.
        let configure = app.buttons["Configure"].firstMatch
        (configure.waitForExistence(timeout: 5) ? configure : row).tap()
        XCTAssertTrue(driver.element("collection.inspector.titleOverride.field")
            .waitForExistence(timeout: CollectionSettingsDriver.patience), "The document's settings did not open")

        let switches = app.switches.matching(NSPredicate(format: "label BEGINSWITH %@", "Include"))
        XCTAssertTrue(driver.waitUntil { switches.count >= 2 }, "The settings list fewer than two note switches")
        let names = switches.allElementsBoundByIndex.map(\.label)
        XCTAssertEqual(Set(names).count, names.count, "Two switches speak the same name: \(names)")
        XCTAssertTrue(names.contains("Include the note “A note that prints with d1.”"), "Names: \(names)")
        XCTAssertTrue(names.contains("Include the note “UI Test Research Note”"), "Names: \(names)")
    }
}

// MARK: - CollectionTemplateFitTests (L44, #2006, J17)

/// Step 1's template cards and the section pill at the default text size, AX3 and AX5 (#2006's fourth item; the third
/// review's J17): a card is drawn larger at an accessibility size, which proves the size took effect, the card
/// stays inside the window, and after a card is chosen, and after step 2's *None*, the line and its *Undo* are in view.
/// The section pill's label grows with the size too, where its type was fixed at 12 points.
///
/// ## Devices
/// iPhone 17 and iPad Pro 13-inch (M5), `OS=27.0`. Never skips. Allow 900 s a test.
///
/// ## On the code before L44
/// `testATemplateCardGrowsWithTheTextSize` finds the card among the settings' own templates and fails at its ratio: the
/// card is as tall at AX3 as at the default size. The other three find no step row and fail at it.
///
/// Version history:
///   1.0 — L44: initial implementation
@MainActor
final class CollectionTemplateFitTests: XCTestCase {

    var app: XCUIApplication!
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }
    private var driver: CollectionSettingsDriver { CollectionSettingsDriver(app: app) }

    override func tearDown() async throws {
        UITestPresentation.dismissAnyPresentation(in: app)
        app?.terminate()
        app = nil
        try await super.tearDown()
    }

    /// #2006's fourth item, on the card's own frame, which the code before L44 draws too: *Full text as printed*'s card
    /// at the default size and again at AX3, in one test. On the code before L44 its type was fixed in points, so the
    /// card was as tall at AX3 as at the default; a card whose type follows the reader's size is taller.
    func testATemplateCardGrowsWithTheTextSize() throws {
        let standard = try templateCardFrame(at: nil)
        app.terminate()
        let large = try templateCardFrame(at: "UICTContentSizeCategoryAccessibilityXL")
        print("[L44 fit] card at L \(standard), at AX3 \(large)")
        XCTAssertGreaterThan(large.height, standard.height * 1.4, """
            Full text as printed's card is \(Int(large.height)) points high at AX3 and \(Int(standard.height)) at the default \
            size: its type does not follow the reader's text size (#2006)
            """)
    }

    func testTheStepsFitAtTheDefaultSize() throws {
        try assertStepsFit(at: nil, named: "L")
    }

    func testTheStepsFitAtAX3() throws {
        try assertStepsFit(at: "UICTContentSizeCategoryAccessibilityXL", named: "AX3")
    }

    func testTheStepsFitAtAX5() throws {
        try assertStepsFit(at: "UICTContentSizeCategoryAccessibilityXXXL", named: "AX5")
    }

    /// *Full text as printed*'s card, by its label, in a new collection's settings: in step 1 where the settings have
    /// one (L44), else among the settings' own templates (the code before L44, where the iPhone drew chips).
    private func templateCardFrame(at category: String?) throws -> CGRect {
        launch(at: category)
        driver.createCollection()
        driver.openSettings()
        let step = driver.element("collection.settings.documents.row")
        let bar: String
        if step.waitForExistence(timeout: 10) {
            driver.openStep("collection.settings.documents.row", title: CollectionSettingsDriver.documentsTitle)
            bar = CollectionSettingsDriver.documentsTitle
        } else {
            bar = CollectionSettingsDriver.settingsTitle
        }
        let card = driver.reveal(app.buttons["Full text as printed"].firstMatch, what: "Full text as printed's card",
                                 under: bar)
        return card.frame
    }

    private func launch(at category: String?) {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_DISABLE_ANIMATIONS"] = "1"
        app.launchArguments = UITestLaunch.arguments(startingOn: .collections, contentSizeCategory: category)
        app.launch()
        XCTAssertTrue(navigator.select(.collections, resolveTimeout: 15).tapped, "Could not open the Collections tab")
    }

    private func assertStepsFit(at category: String?, named size: String) throws {
        launch(at: category)
        let accessibility = category != nil

        driver.createCollection()
        CollectionEditorAddMenu.open(in: app)
        let heading = app.buttons["Add Section Heading"].firstMatch
        XCTAssertTrue(heading.waitForExistence(timeout: CollectionSettingsDriver.patience), "No Add Section Heading")
        heading.tap()
        let pill = app.buttons["Section defaults"].firstMatch
        XCTAssertTrue(pill.waitForExistence(timeout: CollectionSettingsDriver.patience), "No section heading row")
        print("[L44 fit] \(size) pill \(pill.frame)")
        if accessibility {
            XCTAssertGreaterThan(pill.frame.height, 34, "The pill's type did not grow at \(size): \(pill.frame)")
        }

        driver.openSettings()
        driver.openStep("collection.settings.documents.row", title: CollectionSettingsDriver.documentsTitle)
        let window = app.windows.firstMatch.frame
        let frames = try driver.frames(["collection.template.fullTextAsPrinted"])
        let card = try XCTUnwrap(frames["collection.template.fullTextAsPrinted"], "No card at \(size)")
        print("[L44 fit] \(size) window \(Int(window.width))x\(Int(window.height)) card \(card)")
        XCTAssertGreaterThanOrEqual(card.minX, window.minX - 0.5, "The card runs off the leading edge at \(size)")
        XCTAssertLessThanOrEqual(card.maxX, window.maxX + 0.5, "The card runs off the trailing edge at \(size)")
        if accessibility {
            // The card is about 60 points high at the default size, its name a line of subheadline type and its line of
            // caption type; at AX3 those are about 36 and 35 points a line, so the card passes 85 only if the size took
            // effect. One column is measured against the step's own bar, since on the iPad the settings are a sheet
            // narrower than the window.
            let bar = app.navigationBars[CollectionSettingsDriver.documentsTitle].frame
            XCTAssertGreaterThan(card.height, 85,
                                 "The card was not drawn larger at \(size), so the size did not take effect: \(card)")
            XCTAssertGreaterThan(card.width, bar.width * 0.7, "The cards are not one column at \(size): \(card), bar \(bar)")
        }

        // J17: the line and its Undo in view where the choice was made, after a card.
        let cardElement = driver.element("collection.template.fullTextAsPrinted")
        cardElement.tap()
        let line = driver.element("collection.documents.change")
        XCTAssertTrue(line.waitForExistence(timeout: CollectionSettingsDriver.patience), "No line after a card at \(size)")
        let undo = driver.element("collection.documents.change.undo")
        XCTAssertTrue(driver.waitUntil { line.isHittable && undo.isHittable },
                      "The line and its Undo are not in view after a card at \(size)")
        attachScreenshot("L44 fit \(size): after a card")

        driver.back(from: CollectionSettingsDriver.documentsTitle)
        driver.openStep("collection.settings.apparatus.row", title: CollectionSettingsDriver.apparatusTitle)
        driver.element("collection.apparatus.none").tap()
        let apparatusLine = driver.element("collection.apparatus.change")
        XCTAssertTrue(apparatusLine.waitForExistence(timeout: CollectionSettingsDriver.patience),
                      "No line after None at \(size)")
        let apparatusUndo = driver.element("collection.apparatus.change.undo")
        XCTAssertTrue(driver.waitUntil { apparatusLine.isHittable && apparatusUndo.isHittable },
                      "The line and its Undo are not in view after None at \(size)")
        attachScreenshot("L44 fit \(size): after None")
    }

    private func attachScreenshot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}

// MARK: - CollectionSectionPillHitAreaTests (L44, #2006)

/// The section pill answers a tap inside 44 points of its centre, beyond its own 24 (#2006's third item): a tap above
/// the pill, outside its frame and inside the hit area `minimumHitTarget()` gives it, opens the section's sheet.
///
/// ## Devices
/// iPad Pro 13-inch (M5), `OS=27.0`, where the pill is one line, about 24 points high. On iPhone 17 it skips: its label
/// wraps in the narrow outline, and the pill is 38.7 points high, so its 44-point area adds too little to tap. Allow 600 s.
///
/// ## On the code before L44
/// Measured in the suite's runbook entry, on the iPad: whether the system takes a tap that close to the pill by itself, as
/// it took Search's Filter and pager taps before #1918 (`SearchHitAreaTests`).
///
/// Version history:
///   1.0 — L44: initial implementation
@MainActor
final class CollectionSectionPillHitAreaTests: XCTestCase {

    var app: XCUIApplication!
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    override func tearDown() async throws {
        UITestPresentation.dismissAnyPresentation(in: app)
        app?.terminate()
        app = nil
        try await super.tearDown()
    }

    func testATapAboveThePillOpensTheSectionsSheet() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_DISABLE_ANIMATIONS"] = "1"
        app.launchArguments = UITestLaunch.arguments(startingOn: .collections)
        app.launch()
        XCTAssertTrue(navigator.select(.collections, resolveTimeout: 15).tapped, "Could not open the Collections tab")
        let driver = CollectionSettingsDriver(app: app)
        driver.createCollection()
        CollectionEditorAddMenu.open(in: app)
        let heading = app.buttons["Add Section Heading"].firstMatch
        XCTAssertTrue(heading.waitForExistence(timeout: CollectionSettingsDriver.patience), "No Add Section Heading")
        heading.tap()
        let pill = app.buttons["Section defaults"].firstMatch
        XCTAssertTrue(pill.waitForExistence(timeout: CollectionSettingsDriver.patience), "No section heading row")
        let frame = pill.frame
        print("[L44 pill] \(frame)")
        // Measured on the code before L44 (iPhone 17, iOS 27.0): the pill's label wraps in the iPhone's narrow outline,
        // "Section" over "defaults", so the pill is 38.7 points high there, and its 44-point area adds under 3 points above
        // it, too few for a tap to tell from the system's own tolerance. One line, as on the iPad, it is about 24.
        try XCTSkipIf(frame.height > 34, """
            The pill is \(Int(frame.height)) points high here, its label wrapped, so its 44-point area adds \
            \(Int((44 - frame.height) / 2)) points above it: too few for a tap to tell. Run it on an iPad, where it is one line.
            """)
        // Above the pill, 8 points past its top edge: outside the pill and inside the 44-point square about its centre.
        // Above, not below: the row's Body depth menu is drawn under the pill and after it, so it takes a tap there.
        let above = frame.height / 2 + 8
        XCTAssertLessThan(above, 22, "A tap \(Int(above)) points above the centre is outside the 44-point square")
        let origin = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(CGVector(dx: frame.midX, dy: frame.midY - above)).tap()
        // By the sheet's section header, which the code before L44 draws too.
        let sheet = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Section Defaults")).firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: CollectionSettingsDriver.patience),
                      "A tap \(Int(above)) points above the pill's centre, 8 past its edge, opened no section sheet")
    }
}
