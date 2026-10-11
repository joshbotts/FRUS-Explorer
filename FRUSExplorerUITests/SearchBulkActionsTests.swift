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

// MARK: - BulkActionsScreen

/// What the two suites in this file share: the launch on the thirty-document volume, the search
/// that lists it, and the selection's controls by identifier (#1576 lane 3).
///
/// Controls are found by identifier, because iOS 27 reorders the XCUI tree and a label query can
/// match a covered element. Result rows are the exception: a row is a button labelled with its
/// document's title, and the titles are this fixture's alone.
@MainActor
struct BulkActionsScreen {

    let app: XCUIApplication

    /// The word every document of the bulk volume holds (`UITestVolumeSeeder.bulkQueryWord`).
    static let query = "quillwort"
    /// The start of every bulk document's title (`UITestVolumeSeeder.bulkDocumentTitle`).
    static let titlePrefix = "UI Test Bulk Document"
    /// The seeded collection's name (`UITestProjectSeeder.collectionName`).
    static let collectionName = "UI Test Unattached Collection"

    /// How long a wait waits. Long, because a wait that is met returns at once and this Mac is not
    /// always quiet: on 2026-10-10, with other sessions' builds holding the load average over
    /// 200, an 8 s wait for "2 selected" timed out on a count that read "2 selected" by the time
    /// the failure was written.
    static let patience: TimeInterval = 30

    /// A launch on the Search tab with the bulk volume and the seeded collection.
    static func launch(contentSizeCategory: String? = nil) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        // Every step waits on a menu, a sheet or a bar, and XCTest's idle counter drifts on
        // iOS 27 (CLAUDE.md, #1320).
        app.launchEnvironment["FRUS_UI_TEST_DISABLE_ANIMATIONS"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_BULK_VOLUME"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_PROJECT"] = "1"
        app.launchArguments = UITestLaunch.arguments(startingOn: .search,
                                                     contentSizeCategory: contentSizeCategory)
        app.launch()
        return app
    }

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// The result rows on screen: buttons whose label is a bulk document's title.
    var rows: XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", Self.titlePrefix))
    }

    /// Runs the keyword search and waits for its rows. The volume is indexed during launch, and a
    /// search that runs first lists nothing, so the query is submitted until the rows are there.
    func runTheSearch(file: StaticString = #filePath, line: UInt = #line) {
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: Self.patience), "The Search tab shows no search field",
                      file: file, line: line)
        for attempt in 1...5 {
            field.tap()
            if attempt > 1, let typed = field.value as? String, typed == Self.query {
                field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: typed.count))
            }
            field.typeText(Self.query + "\n")
            if rows.firstMatch.waitForExistence(timeout: 12) { return }
        }
        XCTFail("A search for \"\(Self.query)\" listed no bulk document in five attempts",
                file: file, line: line)
    }

    /// More ▸ Select Results.
    func enterSelectionFromTheMoreMenu(file: StaticString = #filePath, line: UInt = #line) {
        let more = element("search.actions.more")
        XCTAssertTrue(more.waitForExistence(timeout: Self.patience), "The actions bar has no More menu", file: file, line: line)
        more.tap()
        let item = app.buttons["Select Results"].firstMatch
        if !item.waitForExistence(timeout: Self.patience) {
            // What the tap on More did show, for the log: a menu with other items, or no menu.
            // Until the results column could give way, a bar pushed behind the search field
            // took the tap elsewhere and no menu opened (iPhone SE at AX5, 2026-10-10).
            print("[#1576] no Select Results; buttons on screen: "
                  + app.buttons.allElementsBoundByIndex.prefix(40).map { "\"\($0.label)\"" }.joined(separator: ", "))
        }
        XCTAssertTrue(item.exists, "The More menu has no Select Results", file: file, line: line)
        item.tap()
        XCTAssertTrue(element("search.selection.done").waitForExistence(timeout: Self.patience),
                      "Select Results did not show the selection bar", file: file, line: line)
    }

    /// Waits for the selection bar's count to read `text`.
    func waitForCount(_ text: String, _ when: String, file: StaticString = #filePath, line: UInt = #line) {
        let count = element("search.selection.count")
        let reads = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", text), object: count)
        XCTAssertEqual(XCTWaiter.wait(for: [reads], timeout: Self.patience), .completed,
                       "The count reads \"\(count.label)\" \(when), where it should read \"\(text)\"",
                       file: file, line: line)
    }

    /// Waits for an element with `identifier` whose label holds `text`.
    ///
    /// Any element with the identifier, and not the first: a `Label` gives its identifier to its
    /// glyph as well as its words, and which of the two a first match answers is not fixed. On
    /// 2026-10-10 the checklist strip's count answered with its glyph's name, "Checklist With
    /// Checkmarks", at XXXL on an iPhone 17, and with its words at the other sizes.
    func waitFor(_ identifier: String, toHold text: String, _ when: String,
                 file: StaticString = #filePath, line: UInt = #line) {
        let named = app.descendants(matching: .any).matching(identifier: identifier)
        let holding = named.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
        if !holding.waitForExistence(timeout: Self.patience) {
            let labels = named.allElementsBoundByIndex.map { "\"\($0.label)\"" }.joined(separator: ", ")
            XCTFail("\(identifier) reads \(labels.isEmpty ? "<absent>" : labels) \(when), where it should hold \"\(text)\"",
                    file: file, line: line)
        }
    }

    /// Chooses an item of the selection bar's Select menu.
    func chooseFromTheSelectMenu(_ item: String, file: StaticString = #filePath, line: UInt = #line) {
        element("search.selection.menu").tap()
        let button = app.buttons[item].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: Self.patience), "The Select menu has no \"\(item)\"", file: file, line: line)
        button.tap()
    }

    /// Chooses a command from the selection bar's Actions menu.
    func chooseAction(_ item: String, file: StaticString = #filePath, line: UInt = #line) {
        let actions = element("search.selection.actions")
        XCTAssertTrue(actions.waitForExistence(timeout: Self.patience), "The selection bar has no Actions menu", file: file, line: line)
        actions.tap()
        let button = app.buttons[item].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: Self.patience), "The Actions menu has no \"\(item)\"", file: file, line: line)
        button.tap()
    }

    /// Leaves selection and closes any sheet, so the next launch restores a plain list.
    func leave() {
        guard app.state == .runningForeground else { return }
        for title in ["Add 2 Documents to Collection", "Add to Collection"] {
            let cancel = app.navigationBars[title].buttons["Cancel"].firstMatch
            if cancel.exists { cancel.tap() }
        }
        let done = element("search.selection.done")
        if done.exists { done.tap() }
        UITestPresentation.dismissAnyPresentation(in: app)
    }
}

// MARK: - SearchBulkActionsTests (#1576 lane 3)

/// Selecting search results and acting on the selection, on iPhone and iPad.
///
/// ## What this is the only test of
/// `ResultSelectionTests` and `SearchSelectionModelTests` run the rules, and
/// `ResultSelectionWiringTests` reads the wiring from source. This suite is where the bar is
/// entered from the More menu and from a row, rows are tapped, the count and the outcome are read
/// off the screen, and the commands are chosen from the bar's Actions menu. It is the first suite
/// to drive a selection.
///
/// ## Fixture
/// `FRUS_UI_TEST_SEED_BULK_VOLUME` writes thirty documents that all hold one word, so a search
/// for it lists a first page of twenty-five and a second of five. `FRUS_UI_TEST_SEED_PROJECT`
/// seeds the collection the picked rows are added to, which holds one document of another
/// volume. A launch without the first flag removes the volume, so no other suite lists it.
///
/// ## Devices
/// An iPhone and an iPad; nothing skips. Each test is its own launch and is kept to two sheets,
/// because a test is allowed 300 s under iOS 27 and this Mac is not always quiet.
///
/// Version history:
///   1.0 — #1576 lane 3: initial implementation
@MainActor
final class SearchBulkActionsTests: XCTestCase {

    private var app: XCUIApplication!
    private var screen: BulkActionsScreen { BulkActionsScreen(app: app) }
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    override func setUp() async throws {
        continueAfterFailure = false
        app = BulkActionsScreen.launch()
        XCTAssertTrue(navigator.select(.search, resolveTimeout: 15).tapped,
                      "Could not open the Search tab, so this suite would read another screen")
        screen.runTheSearch()
    }

    override func tearDown() async throws {
        if let app { BulkActionsScreen(app: app).leave() }
        app?.terminate()
        app = nil
    }

    /// Picks are counted, a picked row says so to VoiceOver, a page turn keeps them, and the
    /// Select menu picks the page and everything shown.
    func testPickedRowsAreCountedAndOutliveAPageTurn() throws {
        screen.enterSelectionFromTheMoreMenu()
        screen.waitForCount("0 selected", "on entering from the More menu")

        let first = screen.rows.element(boundBy: 0)
        let second = screen.rows.element(boundBy: 1)
        first.tap()
        second.tap()
        screen.waitForCount("2 selected", "after tapping two rows")
        XCTAssertTrue(first.isSelected && second.isSelected,
                      "The two tapped rows do not carry the selected trait")
        XCTAssertFalse(screen.rows.element(boundBy: 2).isSelected, "A row that was not tapped reads as selected")

        // Page 2 of the thirty holds five rows, none of them picked.
        let next = app.buttons["Next page"].firstMatch
        XCTAssertTrue(next.waitForExistence(timeout: BulkActionsScreen.patience), "The results have no Next page control")
        next.tap()
        // The count reads the same before and after the turn, so it is no sign the page has
        // changed: wait for the rows themselves, five on the second page of thirty.
        let fiveRows = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count == 5"), object: screen.rows)
        XCTAssertEqual(XCTWaiter.wait(for: [fiveRows], timeout: BulkActionsScreen.patience), .completed,
                       "Page 2 of thirty results should hold five rows; it holds \(screen.rows.count)")
        screen.waitForCount("2 selected", "after turning to page 2")

        screen.chooseFromTheSelectMenu("This Page")
        screen.waitForCount("7 selected", "after This Page on page 2")
        screen.chooseFromTheSelectMenu("All 30 Shown")
        screen.waitForCount("30 selected", "after All 30 Shown")
        screen.chooseFromTheSelectMenu("None")
        screen.waitForCount("0 selected", "after None")

        // Done gives the bar back to the five controls.
        screen.element("search.selection.done").tap()
        XCTAssertTrue(screen.element("search.actions.more").waitForExistence(timeout: BulkActionsScreen.patience),
                      "Done did not bring the actions bar back")
        XCTAssertFalse(screen.element("search.selection.count").exists, "The selection bar is still up after Done")
    }

    /// Select on a row's menu enters selection with that row picked. The two picked documents go
    /// into the seeded collection; a line above the results says so; Undo takes them out again.
    func testASelectionIsAddedToACollectionAndUndoTakesItBack() throws {
        let first = screen.rows.element(boundBy: 0)
        first.press(forDuration: 1.2)
        let select = app.buttons["Select"].firstMatch
        XCTAssertTrue(select.waitForExistence(timeout: BulkActionsScreen.patience), "A row's menu has no Select")
        select.tap()
        screen.waitForCount("1 selected", "after Select on a row's menu")
        screen.rows.element(boundBy: 1).tap()
        screen.waitForCount("2 selected", "after tapping a second row")

        var collection = try openThePickerForTheSelection()
        XCTAssertTrue(collection.label.contains("1 document"),
                      "fixture: the seeded collection should open on \"1 document\": \"\(collection.label)\"")
        collection.tap()
        waitForThePickerToClose()
        screen.waitFor("search.selection.outcome", toHold: "Added 2 documents to “\(BulkActionsScreen.collectionName)”.",
                       "after adding the two picked rows")
        screen.waitForCount("2 selected", "after the add: the picks stay")

        let undo = screen.element("search.selection.undo")
        XCTAssertTrue(undo.waitForExistence(timeout: BulkActionsScreen.patience), "The outcome offers no Undo")
        undo.tap()
        screen.waitFor("search.selection.outcome", toHold: "Removed 2 documents from “\(BulkActionsScreen.collectionName)”.",
                       "after Undo")
        XCTAssertFalse(screen.element("search.selection.undo").exists, "Undo is still offered after it was used")

        // Read back from the picker: the collection is at its seeded count again.
        collection = try openThePickerForTheSelection()
        XCTAssertTrue(collection.label.contains("1 document") && !collection.label.contains("1 documents"),
                      "Undo did not remove the two documents: the collection's row reads \"\(collection.label)\"")
        app.navigationBars["Add 2 Documents to Collection"].buttons["Cancel"].firstMatch.tap()
        waitForThePickerToClose()
    }

    /// The same two documents twice: the second add finds them there and says so, with nothing
    /// to undo.
    func testAddingASelectionTwiceSaysTheDocumentsWereAlreadyThere() throws {
        screen.enterSelectionFromTheMoreMenu()
        screen.rows.element(boundBy: 0).tap()
        screen.rows.element(boundBy: 1).tap()
        screen.waitForCount("2 selected", "after tapping two rows")

        try openThePickerForTheSelection().tap()
        waitForThePickerToClose()
        screen.waitFor("search.selection.outcome", toHold: "Added 2 documents", "after the first add")

        let collection = try openThePickerForTheSelection()
        XCTAssertTrue(collection.label.contains("3 documents"),
                      "The first add did not reach the collection: its row reads \"\(collection.label)\"")
        collection.tap()
        waitForThePickerToClose()
        screen.waitFor("search.selection.outcome",
                       toHold: "Nothing added: 2 were already in “\(BulkActionsScreen.collectionName)”.",
                       "after adding the same two again")
        XCTAssertFalse(screen.element("search.selection.undo").exists, "An add that added nothing offers an Undo")
    }

    /// Checklist Mode on, the page picked, Mark Reviewed: the page is hidden, the picks go with
    /// it, and Undo brings the rows back unpicked.
    func testASelectedPageIsMarkedReviewedAndUndoBringsItBack() throws {
        let checklist = screen.element("search.actions.checklist")
        XCTAssertTrue(checklist.waitForExistence(timeout: BulkActionsScreen.patience), "The actions bar has no Checklist control")
        checklist.tap()
        screen.waitFor("search.checklist.hidden", toHold: "Nothing hidden", "after turning Checklist Mode on")

        screen.enterSelectionFromTheMoreMenu()
        screen.chooseFromTheSelectMenu("This Page")
        screen.waitForCount("25 selected", "after This Page")

        screen.chooseAction("Mark Reviewed")
        screen.waitFor("search.checklist.hidden", toHold: "25 reviewed hidden", "after Mark Reviewed")
        screen.waitForCount("0 selected", "after Mark Reviewed: what was hidden is no longer picked")
        screen.waitFor("search.selection.outcome", toHold: "25 results marked reviewed", "after Mark Reviewed")
        XCTAssertEqual(screen.rows.count, 5, "The five results of the second page should have moved up")

        screen.element("search.selection.undo").tap()
        screen.waitFor("search.checklist.hidden", toHold: "Nothing hidden", "after Undo")
        screen.waitFor("search.selection.outcome", toHold: "25 results are back in the list", "after Undo")
        screen.waitForCount("0 selected", "after Undo: the rows come back unpicked")
    }

    // MARK: - Steps

    /// Chooses Add to Collection in the Actions menu and answers the seeded collection's row.
    private func openThePickerForTheSelection() throws -> XCUIElement {
        screen.chooseAction("Add to Collection…")
        XCTAssertTrue(app.navigationBars["Add 2 Documents to Collection"].waitForExistence(timeout: BulkActionsScreen.patience), """
            Add to Collection did not present the picker titled for two documents. Bars: \
            \(app.navigationBars.allElementsBoundByIndex.map(\.identifier))
            """)
        let collection = app.buttons
            .matching(NSPredicate(format: "label CONTAINS %@", BulkActionsScreen.collectionName)).firstMatch
        XCTAssertTrue(collection.waitForExistence(timeout: BulkActionsScreen.patience), "The picker does not list the seeded collection")
        return collection
    }

    private func waitForThePickerToClose() {
        let bar = app.navigationBars["Add 2 Documents to Collection"]
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: bar)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: BulkActionsScreen.patience), .completed, "The picker did not close")
    }
}

// MARK: - ResultSelectionBarFitTests (#1576 lane 3)

/// The selection bar stays on screen at five text sizes on an iPhone, under the search field and
/// above the tab shell's banner, with a result starting between it and the banner.
///
/// The bar's row cannot wrap, so it stops its text growing at the first accessibility size
/// (`.dynamicTypeSize(...accessibility1)`). This measures what that leaves: its four controls
/// inside the window's width, in order and apart, under the search field's foot and above the
/// banner's head; and room for the widest count the bar can show. A line of text never draws
/// wider than it is offered, so the frames alone cannot show a count cut short: the room
/// between Done and Select is worked out from them and held to "8,888 selected" at the smallest
/// scale the count draws at.
///
/// Checklist Mode is on, and the test waits for its strip, so the strip is among the rows above
/// the results: the first result must still start above the banner, which it does only because
/// those rows scroll where they do not fit (`SearchView.resultsColumn`). A start is all that is
/// required: on the iPhone SE at AX5 the list has 10 pt.
///
/// **The sixth test is the Collocates reading at the largest size.** The list gives way to the
/// rows above it, so nothing in the five tests above is taller than its room. The Collocates
/// reading has controls of its own that cannot give way, which at AX5 with the banner showing
/// are more than the column has, and `TopAnchoredOverflow` is what keeps the mode picker from
/// being carried behind the search field. That test is the one that fails with the layout taken
/// out. The Timeline reading was tried first and is no test of it: with the layout out, at AX5
/// on an iPhone 17, the picker stayed where it was.
///
/// **What it measured with the commands in a bar at the foot**, the plan's first design, on
/// 2026-10-10: on the iPhone SE at AX5 Mark Reviewed drew at y 334 to 382 under a banner whose
/// top was at y 344, and at AX3 the first result started at y 283 under a bar whose top edge was
/// at y 280. That is why the commands are a menu in this bar.
///
/// **Each accessibility size proves it took effect**, as `SearchActionsBarFitTests` does: an
/// unrecognised category name renders at the default size and a fit assertion over that says
/// nothing. The search field's height at the default size is measured once and each accessibility
/// run must find it taller.
///
/// **iPhone only**: at iPad width the bar fits either way. Run it on an iPhone 17 (402 pt) and
/// an iPhone SE (3rd generation) (375 pt).
///
/// Version history:
///   1.0 — #1576 lane 3: initial implementation
@MainActor
final class ResultSelectionBarFitTests: XCTestCase {

    private var app: XCUIApplication!
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    /// The search field's height at the device's default text size, measured once per run.
    private static var defaultFieldHeight: CGFloat = 0

    private static let phoneOnlyReason =
        "iPhone-only: at iPad width the bar fits either way, so a pass there is not evidence"

    override func tearDown() async throws {
        if let app { BulkActionsScreen(app: app).leave() }
        app?.terminate()
        app = nil
    }

    func testBarsFitAtStandardSize() throws {
        try assertBarsFit(at: nil, named: "L")
    }

    func testBarsFitAtLargestStandardSize() throws {
        try assertBarsFit(at: "UICTContentSizeCategoryXXXL", named: "XXXL")
    }

    func testBarsFitAtFirstAccessibilitySize() throws {
        try assertBarsFit(at: "UICTContentSizeCategoryAccessibilityM", named: "AX1")
    }

    func testBarsFitAtMiddleAccessibilitySize() throws {
        try assertBarsFit(at: "UICTContentSizeCategoryAccessibilityXL", named: "AX3")
    }

    func testBarsFitAtLargestAccessibilitySize() throws {
        try assertBarsFit(at: "UICTContentSizeCategoryAccessibilityXXXL", named: "AX5")
    }

    // MARK: - Helpers

    private func assertBarsFit(at category: String?, named size: String) throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, Self.phoneOnlyReason)
        if Self.defaultFieldHeight == 0 {
            Self.defaultFieldHeight = try fieldHeight(at: nil)
        }
        launch(at: category)
        let screen = BulkActionsScreen(app: app)
        screen.runTheSearch()

        let checklist = screen.element("search.actions.checklist")
        XCTAssertTrue(checklist.waitForExistence(timeout: BulkActionsScreen.patience), "The actions bar has no Checklist control")
        checklist.tap()
        // The strip is what makes the rows above the results tall: without it this measures less.
        screen.waitFor("search.checklist.hidden", toHold: "Nothing hidden", "after turning Checklist Mode on at \(size)")
        screen.enterSelectionFromTheMoreMenu()

        let window = app.windows.firstMatch.frame
        let banner = screen.element("tabShell.syncBanner")
        XCTAssertTrue(banner.waitForExistence(timeout: BulkActionsScreen.patience),
                      "The tab shell's banner is not showing, so nothing here is measured against it")
        let bannerTop = banner.frame.minY

        let identifiers = ["search.selection.done", "search.selection.count", "search.selection.menu",
                           "search.selection.actions"]
        var frames: [(id: String, frame: CGRect)] = []
        for identifier in identifiers {
            let element = screen.element(identifier)
            XCTAssertTrue(element.waitForExistence(timeout: BulkActionsScreen.patience), "\(identifier) is not in the tree at \(size)")
            frames.append((identifier, element.frame))
        }
        let field = app.searchFields.firstMatch.frame
        let firstRow = screen.rows.firstMatch
        let firstRowTop: CGFloat? = firstRow.exists ? firstRow.frame.minY : nil
        // The measurement record, printed whether or not the assertions hold.
        print("[#1576] \(size) window \(Int(window.width))x\(Int(window.height)) field foot \(Int(field.maxY)) "
              + "banner top \(Int(bannerTop)) first row top \(firstRowTop.map { String(Int($0)) } ?? "none"): "
              + frames.map { "\($0.id.replacingOccurrences(of: "search.selection.", with: "")) "
                  + "x \(Int($0.frame.minX))–\(Int($0.frame.maxX)) y \(Int($0.frame.minY))–\(Int($0.frame.maxY))" }
                  .joined(separator: ", "))

        for (identifier, frame) in frames {
            XCTAssertGreaterThanOrEqual(frame.minX, 0, "\(identifier) runs off the leading edge at \(size): \(frame)")
            XCTAssertLessThanOrEqual(frame.maxX, window.maxX, "\(identifier) runs off the trailing edge at \(size): \(frame)")
            XCTAssertGreaterThan(frame.width, 0, "\(identifier) has no width at \(size)")
            XCTAssertLessThanOrEqual(frame.maxY, bannerTop + 0.5,
                                     "\(identifier) is under the tab shell's banner at \(size): \(frame), banner top \(bannerTop)")
        }
        // In order and apart.
        for (earlier, later) in zip(frames, frames.dropFirst()) {
            XCTAssertLessThanOrEqual(earlier.frame.maxX, later.frame.minX,
                                     "\(earlier.id) and \(later.id) overlap at \(size)")
        }
        // Under the search field, not behind it. The mode picker is the first thing above the
        // results, so it is the first to go behind the field when they are too tall for their
        // room; a build without the Meaning engine draws no picker, and the bar is first.
        let picker = Self.modePicker(in: app)
        let barTop = frames.map(\.frame.minY).min() ?? 0
        let stackTop = picker.exists ? picker.frame.minY : barTop
        XCTAssertGreaterThanOrEqual(stackTop, field.maxY - 0.5,
                                    "what is above the results is behind the search field at \(size): top \(stackTop), field foot \(field.maxY)")
        // Room for the widest count. Done, the count and Select are four gaps apart in the row.
        let room = frames[2].frame.minX - frames[0].frame.maxX - 4 * Self.rowSpacing
        let needed = Self.widestCountWidth(at: category) * Self.countMinimumScale
        print("[#1576] \(size) count room \(Int(room)) widest count at its smallest \(Int(needed.rounded(.up)))")
        XCTAssertLessThanOrEqual(needed, room + 0.5,
                                 "the count's room at \(size) (\(room) pt) cuts \"8,888 selected\" short: it needs \(needed) pt at its smallest")
        // And a result still starts between the bar and the banner: the rows fixed above the
        // list give way to it (`SearchView.resultsColumn`).
        let barFoot = frames.map(\.frame.maxY).max() ?? 0
        let rowTop = try XCTUnwrap(firstRowTop, "no result row is in the tree at \(size)")
        XCTAssertGreaterThanOrEqual(rowTop, barFoot, "the first result is drawn over the selection bar at \(size)")
        XCTAssertLessThan(rowTop, bannerTop,
                          "no result starts above the banner at \(size): first row top \(rowTop), banner top \(bannerTop)")

        // The category really applied.
        if let category, category.contains("Accessibility") {
            let height = app.searchFields.firstMatch.frame.height
            XCTAssertGreaterThan(height, Self.defaultFieldHeight + 1, """
                \(size) rendered the search field at its default height (\(height) vs \
                \(Self.defaultFieldHeight)): the content-size category did not take effect, so this run says nothing
                """)
        }
    }

    /// The space between the bar's controls: `ResultSelectionBar.spacing`, which this target
    /// cannot read. `ResultSelectionWiringTests` holds the two to the same figure.
    private static let rowSpacing: CGFloat = 8
    /// The smallest the count draws: `ResultSelectionBar.countMinimumScale`, likewise.
    private static let countMinimumScale: CGFloat = 0.6

    /// The width of the widest count the bar can show, at full size, in the font the row draws
    /// it in at a text size: body, with digits of one width, growing no further than the first
    /// accessibility size.
    private static func widestCountWidth(at category: String?) -> CGFloat {
        let asked = category.map { UIContentSizeCategory(rawValue: $0) } ?? .large
        let drawn = asked.isAccessibilityCategory ? UIContentSizeCategory.accessibilityMedium : asked
        let body = UIFont.preferredFont(forTextStyle: .body,
                                        compatibleWith: UITraitCollection(preferredContentSizeCategory: drawn))
        let font = UIFont.monospacedDigitSystemFont(ofSize: body.pointSize, weight: .regular)
        return ("8,888 selected" as NSString).size(withAttributes: [.font: font]).width
    }

    /// The Collocates reading's own controls cannot give way, and at the largest text size with
    /// the banner showing they are taller than the column has. Nothing above the results may move
    /// for them.
    func testCollocatesTallerThanTheirRoomLeaveTheModePickerInPlace() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, Self.phoneOnlyReason)
        launch(at: "UICTContentSizeCategoryAccessibilityXXXL")
        let screen = BulkActionsScreen(app: app)
        screen.runTheSearch()
        XCTAssertTrue(screen.element("tabShell.syncBanner").waitForExistence(timeout: BulkActionsScreen.patience),
                      "The tab shell's banner is not showing, so the column has more room than this test is about")

        let examine = screen.element("search.actions.examine")
        XCTAssertTrue(examine.waitForExistence(timeout: BulkActionsScreen.patience), "The actions bar has no Examine menu")
        examine.tap()
        let collocates = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Collocates")).firstMatch
        XCTAssertTrue(collocates.waitForExistence(timeout: BulkActionsScreen.patience), "The Examine menu has no Collocates")
        collocates.tap()
        // The reading has taken the list's place when its Rank by control is there.
        let rankBy = app.segmentedControls.containing(.button, identifier: "Evidence").firstMatch
        XCTAssertTrue(rankBy.waitForExistence(timeout: BulkActionsScreen.patience),
                      "Collocates did not replace the list: its Rank by control is not in the tree")

        let field = app.searchFields.firstMatch.frame
        let picker = Self.modePicker(in: app)
        XCTAssertTrue(picker.waitForExistence(timeout: BulkActionsScreen.patience),
                      "The Search tab draws no mode picker, so this test has nothing to measure")
        let more = screen.element("search.actions.more")
        XCTAssertTrue(more.waitForExistence(timeout: BulkActionsScreen.patience), "The actions bar has no More menu")
        print("[#1576] collocates AX5 field foot \(Int(field.maxY)) picker y \(Int(picker.frame.minY))–\(Int(picker.frame.maxY)) "
              + "more y \(Int(more.frame.minY))–\(Int(more.frame.maxY)) rank by y \(Int(rankBy.frame.minY))–\(Int(rankBy.frame.maxY))")
        XCTAssertGreaterThanOrEqual(picker.frame.minY, field.maxY - 0.5, """
            the mode picker is behind the search field: its top is at \(picker.frame.minY) and the field's foot at \
            \(field.maxY). A reading taller than its room has moved what is above the results.
            """)
        XCTAssertGreaterThanOrEqual(more.frame.minY, picker.frame.maxY - 0.5, "the actions bar is drawn over the mode picker")
    }

    /// The Keywords and Meaning picker. By what it holds: the Collocates reading has a segmented
    /// control of its own, and which of the two a first match answers is not fixed.
    private static func modePicker(in app: XCUIApplication) -> XCUIElement {
        app.segmentedControls.containing(.button, identifier: "Keywords").firstMatch
    }

    private func fieldHeight(at category: String?) throws -> CGFloat {
        launch(at: category)
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: BulkActionsScreen.patience), "The Search tab shows no search field")
        return field.frame.height
    }

    private func launch(at category: String?) {
        if let app {
            BulkActionsScreen(app: app).leave()
            app.terminate()
        }
        app = BulkActionsScreen.launch(contentSizeCategory: category)
        XCTAssertTrue(navigator.select(.search, resolveTimeout: 15).tapped,
                      "Could not open the Search tab, so this suite would read another screen")
    }
}
