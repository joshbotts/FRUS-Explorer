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

// MARK: - LayerScreen

/// The Search screen as Search Within These Results uses it (#1577 lane 4), over lane 3's Meaning seam: the seeded
/// fixture volume, a stand-in for the query encoder, and a match file of the seam's own (see `MeaningResultsSeamTests`).
@MainActor
struct LayerScreen {

    let app: XCUIApplication

    /// The start of the three fixture titles that have vectors: "UI Test Document One", "Two", "Three".
    static let titlePrefix = "UI Test Document"
    /// The near question, which the seam answers as the fixture's second document: Two, One, Three, at 100, 32 and 3
    /// percent.
    static let nearQuestion = "how did the exchange of letters begin"
    /// A phrase every fixture document holds, its three without vectors included, and no published document does.
    static let fixturePhrase = "\"\(fixturePhraseWords)\""
    /// The phrase's words, as the row that names a list held from it quotes them: once, without the phrase's own
    /// quotation marks (plan of record §6g).
    static let fixturePhraseWords = "Synthetic UI-test content"
    /// Words two fixture documents hold, and nothing published: Two, which has a vector, and Nested Document Two, which
    /// has none. Of the near question's three closest matches only Two holds them (#1577 lane 7).
    static let swapWords = "\(fixturePhrase) Two"
    /// Long, because a wait that is met returns at once and this Mac is not always quiet.
    static let patience: TimeInterval = 30

    /// A launch on the Search tab with the fixture volume and the Meaning seam, offline, and with a search with text in
    /// it fetched at `searchCeiling` rows where one is given (`UITestSearchCeiling`, #1577 lane 6).
    static func launch(contentSizeCategory: String? = nil, searchCeiling: Int? = nil) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_DISABLE_ANIMATIONS"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_VOLUME"] = "frus1961-63v06"
        app.launchEnvironment["FRUS_UI_TEST_SEED_MEANING"] = "1"
        if let searchCeiling { app.launchEnvironment["FRUS_UI_TEST_SEARCH_CEILING"] = String(searchCeiling) }
        app.launchArguments = UITestLaunch.arguments(startingOn: .search, contentSizeCategory: contentSizeCategory)
        // The reader's own automatic match-file download, off; see `MeaningResultsSeamTests.setUp`.
        app.launchArguments += ["-frus.semantic.autoDownloadShards", "<false/>"]
        app.launch()
        return app
    }

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// The fixture's three rows with vectors, as listed.
    var fixtureRows: XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", Self.titlePrefix))
    }

    /// The Keywords | Meaning control, by what it holds.
    var modePicker: XCUIElement {
        app.segmentedControls.containing(.button, identifier: "Keywords").firstMatch
    }

    /// The fixture rows listed, top to bottom, each with its heading and its score.
    ///
    /// The heading is the label up to its first comma: a result's label is its heading and then the
    /// rest of what the row draws, joined by commas (#1684), and no fixture heading holds a comma.
    func listed() -> [(title: String, score: String)] {
        fixtureRows.allElementsBoundByIndex.sorted { $0.frame.minY < $1.frame.minY }
            .map { (title: String($0.label.prefix { $0 != "," }), score: ($0.value as? String) ?? "") }
    }

    /// Chooses Meaning. The control is drawn once the launch has built the searcher, which on a busy Mac can take a
    /// while, so this wait is the longest.
    func chooseMeaning(file: StaticString = #filePath, line: UInt = #line) {
        let meaning = app.segmentedControls.buttons["Meaning"].firstMatch
        XCTAssertTrue(meaning.waitForExistence(timeout: 3 * Self.patience),
                      "Search shows no Keywords | Meaning control: the semantic stack did not start", file: file, line: line)
        meaning.tap()
    }

    /// Waits for the Meaning engine, which a ranking needs: the More menu's ranking command is dimmed until the launch
    /// has built it, and a menu whose contents change while it is open is rebuilt under the tap (measured at AX3, where
    /// the command was found and then gone). The Keywords | Meaning control is drawn once it is built. The More menu
    /// waits for it itself (`chooseFromTheMoreMenu`); the Sort menu's caller waits.
    func waitForTheMeaningEngine(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.segmentedControls.buttons["Meaning"].firstMatch.waitForExistence(timeout: 3 * Self.patience),
                      "Search shows no Keywords | Meaning control: the semantic stack did not start", file: file, line: line)
    }

    /// Puts the keyboard away with the search field's dismiss button, which the field shows while it has the keyboard,
    /// and waits for it to go. Holding a list hands the field the keyboard (`SearchView.holdBase()`), and the tab shell's
    /// banner gives way to a keyboard (#1070); the field stays empty and the list held.
    func putTheKeyboardAway(file: StaticString = #filePath, line: UInt = #line) {
        guard app.keyboards.count > 0 else { return }
        let labels = NSPredicate(format: "label IN %@", ["Close", "Cancel"])
        var dismiss = app.navigationBars.buttons.matching(labels).firstMatch
        if !dismiss.waitForExistence(timeout: Self.patience) { dismiss = app.buttons.matching(labels).firstMatch }
        XCTAssertTrue(dismiss.exists, "The search field shows no button that puts the keyboard away", file: file, line: line)
        dismiss.tap()
        let deadline = Date().addingTimeInterval(Self.patience)
        while app.keyboards.count > 0, Date() < deadline { Thread.sleep(forTimeInterval: 0.25) }
        XCTAssertEqual(app.keyboards.count, 0, "The keyboard is still up", file: file, line: line)
    }

    /// Replaces the field's text with `text` and submits it, emptying the field with its Clear text button (see
    /// `MeaningResultsSeamTests.submit`), and waiting for the list to empty first when `waitForEmptying`.
    func submit(_ text: String, waitForEmptying: Bool = true, file: StaticString = #filePath, line: UInt = #line) {
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: Self.patience), "The Search tab shows no search field",
                      file: file, line: line)
        field.tap()
        if let typed = field.value as? String, !typed.isEmpty, typed != field.placeholderValue {
            let clear = field.buttons["Clear text"].firstMatch
            XCTAssertTrue(clear.waitForExistence(timeout: Self.patience),
                          "The search field holds \"\(typed)\" and shows no Clear text button", file: file, line: line)
            clear.tap()
            if waitForEmptying {
                let emptied = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"),
                                                        object: fixtureRows.firstMatch)
                XCTAssertEqual(XCTWaiter.wait(for: [emptied], timeout: Self.patience), .completed,
                               "The field was emptied and the last search's rows are still listed", file: file, line: line)
            }
            field.tap()
        }
        field.typeText(text + "\n")
    }

    /// Submits `text` until `count` fixture rows are listed. The fixture is indexed during launch, and a search that
    /// runs first finds nothing.
    func searchUntilListed(_ text: String, count: Int, file: StaticString = #filePath, line: UInt = #line) {
        for _ in 1...5 {
            submit(text, file: file, line: line)
            if fixtureRows.element(boundBy: count - 1).waitForExistence(timeout: 12) { return }
        }
        XCTFail("\"\(text)\" never listed \(count) fixture documents; buttons on screen: "
                + app.buttons.allElementsBoundByIndex.prefix(40).map { "\"\($0.label)\"" }.joined(separator: ", "),
                file: file, line: line)
    }

    /// Submits `text` until the results header reads `header`: a list whose rows the fixture's titles do not tell apart,
    /// such as one cut at a lowered ceiling. The fixture is indexed during launch, and a search that runs first finds
    /// nothing.
    func searchUntilHeader(_ text: String, reads header: String, file: StaticString = #filePath, line: UInt = #line) {
        let found = app.staticTexts.matching(NSPredicate(format: "label == %@", header)).firstMatch
        for _ in 1...5 {
            submit(text, file: file, line: line)
            if found.waitForExistence(timeout: 12) { return }
        }
        XCTFail("\"\(text)\" never read \"\(header)\"; texts on screen: "
                + app.staticTexts.allElementsBoundByIndex.prefix(40).map { "\"\($0.label)\"" }.joined(separator: ", "),
                file: file, line: line)
    }

    /// Opens the More menu and taps `item`, once the Meaning engine is up: until then the menu's ranking command
    /// changes as the engine arrives, and a tap on any item of the menu rebuilt under it can come to nothing (measured:
    /// Save this search opened no sheet).
    func chooseFromTheMoreMenu(_ item: String, file: StaticString = #filePath, line: UInt = #line) {
        waitForTheMeaningEngine(file: file, line: line)
        let more = element("search.actions.more")
        XCTAssertTrue(more.waitForExistence(timeout: Self.patience), "The actions bar has no More menu", file: file, line: line)
        more.tap()
        let button = app.buttons[item].firstMatch
        // At AX5 an iPhone SE's menu shows three of its items, and draws the rest only once it is scrolled to them:
        // the menu is swiped up by its second item, which is always drawn, until the item is.
        var swipes = 0
        while !button.waitForExistence(timeout: swipes == 0 ? Self.patience : 5), swipes < 3 {
            let shown = app.buttons["Save as Working Corpus…"].firstMatch
            guard shown.exists else { break }
            shown.swipeUp()
            swipes += 1
        }
        if !button.exists {
            print("[#1577] no \(item) after \(swipes) swipe(s); buttons on screen: "
                  + app.buttons.allElementsBoundByIndex.prefix(40).map { "\"\($0.label)\"" }.joined(separator: ", "))
        }
        XCTAssertTrue(button.exists, "The More menu has no \"\(item)\"", file: file, line: line)
        button.tap()
    }

    /// Types into the field, which a held base hands the keyboard, and submits.
    func type(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: Self.patience), "The Search tab shows no search field",
                      file: file, line: line)
        field.tap()
        field.typeText(text + "\n")
    }

    /// Waits for a text on screen that reads exactly `text`.
    func waitForText(_ text: String, _ when: String, file: StaticString = #filePath, line: UInt = #line) {
        let found = app.staticTexts.matching(NSPredicate(format: "label == %@", text)).firstMatch
        if !found.waitForExistence(timeout: Self.patience) {
            XCTFail("\"\(text)\" is not on screen \(when). Texts: "
                    + app.staticTexts.allElementsBoundByIndex.prefix(40).map { "\"\($0.label)\"" }.joined(separator: ", "),
                    file: file, line: line)
        }
    }

    /// Waits for the row that names the base to read `label`.
    func waitForBaseRow(_ label: String, file: StaticString = #filePath, line: UInt = #line) {
        let row = element("search.layer.base")
        XCTAssertTrue(row.waitForExistence(timeout: Self.patience), "No row names the held base", file: file, line: line)
        XCTAssertEqual(row.label, label, "The row that names the base", file: file, line: line)
    }

    /// Closes what is open, so that the next launch restores a plain list.
    func leave() {
        guard app.state == .runningForeground else { return }
        let cancel = app.navigationBars["Save Search"].buttons["Cancel"].firstMatch
        if cancel.exists { cancel.tap() }
        UITestPresentation.dismissAnyPresentation(in: app)
    }
}

// MARK: - SearchWithinResultsTests (#1577 lane 4)

/// Search Within These Results on iPhone and iPad, end to end, through lane 3's Meaning seam.
///
/// ## What each test drives
/// - **Words found in a Meaning list**: the near question lists the fixture's three documents with vectors, Two, One
///   and Three; More ▸ Find Words in These Matches holds them, and "Two OR Three" keeps two of them, in the list's
///   order and with its scores.
/// - **A keyword list ranked by a question**: the fixture's phrase lists all six documents; Sort ▸ Closest to a
///   Question… holds them, and the near question ranks the three with vectors first and counts the three without.
/// - **Closing the row** puts the list, its count and the Keywords | Meaning control back, with no search.
/// - **Words found nowhere** show what was looked in, and the two ways on: back to the list, or the words across the
///   whole library, which leaves the base.
/// - **A recalled saved search**, a hand-off, leaves the base; and Save this search is off while a base is held.
/// - **Swap** (#1577 lane 7): the words found in one of the Meaning list's three, swapped, list every document that
///   holds them, closest to the question first, a row with no vector that the Meaning list never held among them; and
///   swapped back, the words are found in the three again.
///
/// ## Devices
/// An iPhone 17 and an iPad Pro 13-inch (M5); nothing skips. The view is shared, but the iPad adds the regular-width
/// layout and the facet inspector. Run against the tree before lane 4 first, to show each test can fail: there is no
/// More ▸ Find Words in These Matches there, and no base row.
///
/// Version history:
///   1.0 — #1577 lane 4: initial implementation
///   1.1 — the recalled-search test saves the name the Save Search sheet offers, with no edit to it: the sheet's Save
///         is on as it opens since its fix (`SaveSearchSheetTests`)
///   1.2 — #1577 lane 7: Swap, each way
///   1.3 — plan of record §6g: a list held from the fixture's phrase is named with its words quoted once
@MainActor
final class SearchWithinResultsTests: XCTestCase {

    private var app: XCUIApplication!
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    override func setUp() async throws {
        continueAfterFailure = false
        app = LayerScreen.launch()
        XCTAssertTrue(navigator.select(.search, resolveTimeout: 15).tapped,
                      "Could not open the Search tab, so this suite would read another screen")
    }

    override func tearDown() async throws {
        if let app {
            LayerScreen(app: app).leave()
            app.terminate()
        }
        app = nil
    }

    /// The near question's Meaning list, held, and two of its three found by their words.
    func testWordsFoundInAMeaningListKeepItsOrderAndScores() throws {
        let screen = LayerScreen(app: app)
        screen.chooseMeaning()
        screen.searchUntilListed(LayerScreen.nearQuestion, count: 3)
        XCTAssertEqual(screen.listed().map(\.title),
                       ["UI Test Document Two", "UI Test Document One", "UI Test Document Three"],
                       "precondition: the seam's Meaning list")

        screen.chooseFromTheMoreMenu("Find Words in These Matches")
        screen.waitForBaseRow("Searching within 3 closest matches to “\(LayerScreen.nearQuestion)”")
        XCTAssertFalse(screen.modePicker.exists, "The row that names the base takes the Keywords | Meaning control's place")
        let field = app.searchFields.firstMatch
        XCTAssertEqual(field.placeholderValue, "Words to find in these matches…")
        XCTAssertEqual(screen.fixtureRows.count, 3, "The list stays on screen until words are typed")

        screen.type("Two OR Three")
        screen.waitForText("2 of your 3 closest matches contain these words", "after the words were searched for")
        let rows = screen.listed()
        XCTAssertEqual(rows.map(\.title), ["UI Test Document Two", "UI Test Document Three"],
                       "The rows that hold the words, in the Meaning list's order")
        XCTAssertEqual(rows.map(\.score), ["Semantic match 100 percent", "Semantic match 3 percent"],
                       "Each row keeps the Meaning list's score")
    }

    /// The fixture's six documents, found by their phrase, held from the Sort menu and ranked by the near question.
    func testAKeywordListRankedByAQuestionListsItsUnrankedRowsLast() throws {
        let screen = LayerScreen(app: app)
        screen.searchUntilListed(LayerScreen.fixturePhrase, count: 3)
        screen.waitForTheMeaningEngine()
        let sort = screen.element("search.actions.sort")
        XCTAssertTrue(sort.waitForExistence(timeout: LayerScreen.patience), "The actions bar has no Sort menu")
        sort.tap()
        let closest = app.buttons["Closest to a Question…"].firstMatch
        XCTAssertTrue(closest.waitForExistence(timeout: LayerScreen.patience), "The Sort menu has no Closest to a Question…")
        closest.tap()

        screen.waitForBaseRow("Searching within 6 results for “\(LayerScreen.fixturePhraseWords)”")
        XCTAssertEqual(app.searchFields.firstMatch.placeholderValue, "A question to rank these results by…")

        screen.type(LayerScreen.nearQuestion)
        screen.waitForText("6 results · 3 ranked · 3 not ranked", "after the question was asked")
        let rows = screen.listed()
        XCTAssertEqual(rows.map(\.title), ["UI Test Document Two", "UI Test Document One", "UI Test Document Three"],
                       "The three with vectors are ranked first, closest first")
        XCTAssertEqual(rows.map(\.score),
                       ["Semantic match 100 percent", "Semantic match 32 percent", "Semantic match 3 percent"])
        let unranked = screen.element("search.layer.unranked")
        XCTAssertTrue(unranked.waitForExistence(timeout: LayerScreen.patience), "No line counts the unranked rows")
        XCTAssertEqual(unranked.label, "3 results not ranked by meaning")
        let lastRanked = try XCTUnwrap(screen.fixtureRows.allElementsBoundByIndex.max { $0.frame.minY < $1.frame.minY })
        XCTAssertGreaterThanOrEqual(unranked.frame.minY, lastRanked.frame.maxY - 0.5,
                                    "The line is after the ranked rows")
        // A row with no vector is under the line. The list draws only the rows near the screen, so where the
        // first of them is not drawn yet (a phone), the list is dragged up a third of the window first.
        let nested = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'UI Test Nested'")).firstMatch
        if !nested.exists {
            let window = app.windows.firstMatch.frame
            let origin = app.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(CGVector(dx: window.midX, dy: window.height * 0.7))
                .press(forDuration: 0.1,
                       thenDragTo: origin.withOffset(CGVector(dx: window.midX, dy: window.height * 0.4)))
        }
        XCTAssertTrue(nested.waitForExistence(timeout: LayerScreen.patience), "No row with no vector is listed")
        XCTAssertTrue(unranked.exists, "The line that counts the unranked rows is no longer drawn")
        XCTAssertGreaterThanOrEqual(nested.frame.minY, unranked.frame.maxY - 0.5,
                                    "A row with no vector is under the line, not among the ranked")
    }

    /// Closing the row puts back the list, its count, the field's question and the Keywords | Meaning control.
    func testClosingTheBaseRowPutsTheListAndTheControlBack() throws {
        let screen = LayerScreen(app: app)
        screen.chooseMeaning()
        screen.searchUntilListed(LayerScreen.nearQuestion, count: 3)
        screen.chooseFromTheMoreMenu("Find Words in These Matches")
        screen.type("Two")
        screen.waitForText("1 of your 3 closest matches contains these words", "after the words were searched for")

        let leave = screen.element("search.layer.leave")
        XCTAssertTrue(leave.waitForExistence(timeout: LayerScreen.patience), "The base row has no close button")
        XCTAssertEqual(leave.label, "Stop searching within these results")
        leave.tap()

        screen.waitForText("3 closest matches", "after the base row was closed")
        XCTAssertFalse(screen.element("search.layer.base").exists, "The base row is still there")
        XCTAssertTrue(screen.modePicker.waitForExistence(timeout: LayerScreen.patience),
                      "The Keywords | Meaning control did not come back")
        XCTAssertTrue(app.segmentedControls.buttons["Meaning"].firstMatch.isSelected, "The control shows the list's engine")
        XCTAssertEqual(app.searchFields.firstMatch.value as? String, LayerScreen.nearQuestion,
                       "The field holds the list's question again")
        XCTAssertEqual(screen.listed().map(\.title),
                       ["UI Test Document Two", "UI Test Document One", "UI Test Document Three"])
    }

    /// Words found nowhere in the list: what was looked in, Back to the list, or the words across the whole library.
    func testWordsFoundNowhereOfferTheWayBackAndTheWholeLibrary() throws {
        let screen = LayerScreen(app: app)
        screen.chooseMeaning()
        screen.searchUntilListed(LayerScreen.nearQuestion, count: 3)
        screen.chooseFromTheMoreMenu("Find Words in These Matches")
        screen.type("zircaloy")

        let statement = screen.element("search.layer.empty.statement")
        XCTAssertTrue(statement.waitForExistence(timeout: LayerScreen.patience), "A layer that found nothing says nothing")
        XCTAssertEqual(statement.label, "None of your 3 closest matches contains these words")
        let back = app.buttons["Back to the 3 Matches"].firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: LayerScreen.patience), "There is no way back to the list")
        XCTAssertTrue(app.buttons["Search the Whole Library for These Words"].firstMatch.exists)
        XCTAssertFalse(app.staticTexts["No semantic matches yet"].exists,
                       "The corpus-wide fallback is not shown while a base is held")
        back.tap()
        screen.waitForText("3 closest matches", "after Back")
        XCTAssertTrue(screen.modePicker.waitForExistence(timeout: LayerScreen.patience))

        screen.chooseFromTheMoreMenu("Find Words in These Matches")
        screen.type("zircaloy")
        let library = app.buttons["Search the Whole Library for These Words"].firstMatch
        XCTAssertTrue(library.waitForExistence(timeout: LayerScreen.patience))
        library.tap()
        XCTAssertTrue(screen.modePicker.waitForExistence(timeout: LayerScreen.patience),
                      "Searching the whole library leaves the base")
        XCTAssertFalse(screen.element("search.layer.base").exists)
        XCTAssertTrue(app.segmentedControls.buttons["Keywords"].firstMatch.isSelected,
                      "The words are searched as keywords")
        XCTAssertEqual(app.searchFields.firstMatch.value as? String, "zircaloy")
    }

    /// Save this search is off while a base is held, and recalling a saved search, a hand-off, leaves the base.
    func testARecalledSavedSearchLeavesTheBase() throws {
        let screen = LayerScreen(app: app)
        screen.searchUntilListed(LayerScreen.fixturePhrase, count: 3)
        screen.chooseFromTheMoreMenu("Save this search")
        let sheet = app.navigationBars["Save Search"]
        XCTAssertTrue(sheet.waitForExistence(timeout: LayerScreen.patience), "Save this search opened no sheet")
        // The sheet names the search by its words, which is the row's name below, with its Save on as it opens
        // (`SaveSearchSheetTests`).
        let saveButton = sheet.buttons["Save"].firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: LayerScreen.patience) && saveButton.isEnabled,
                      "The sheet's Save is not there to tap, or is off")
        saveButton.tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: sheet)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: LayerScreen.patience), .completed, "The sheet did not close")

        screen.chooseFromTheMoreMenu("Rank These Results by a Question")
        screen.waitForBaseRow("Searching within 6 results for “\(LayerScreen.fixturePhraseWords)”")
        let more = screen.element("search.actions.more")
        more.tap()
        let save = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Save this search'")).firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: LayerScreen.patience))
        XCTAssertFalse(save.isEnabled, "A layered search is not saved")
        let saved = app.buttons["Saved searches"].firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: LayerScreen.patience))
        saved.tap()
        let recall = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", LayerScreen.fixturePhrase)).firstMatch
        XCTAssertTrue(recall.waitForExistence(timeout: LayerScreen.patience), "The saved search is not listed")
        recall.tap()

        XCTAssertTrue(screen.modePicker.waitForExistence(timeout: LayerScreen.patience),
                      "A recalled search leaves the base, and the control comes back")
        XCTAssertFalse(screen.element("search.layer.base").exists)
        XCTAssertEqual(screen.fixtureRows.count, 3)
    }

    /// Words found in one of the near question's three closest matches, swapped: both documents that hold the words,
    /// closest to the question first, and the one with no vector, which the Meaning list never held, after the line
    /// that counts it. Swapped back, the words are found in the three again.
    func testSwapRanksEveryResultForTheWordsAndSwapsBack() throws {
        let screen = LayerScreen(app: app)
        screen.chooseMeaning()
        screen.searchUntilListed(LayerScreen.nearQuestion, count: 3)
        screen.chooseFromTheMoreMenu("Find Words in These Matches")
        screen.waitForBaseRow("Searching within 3 closest matches to “\(LayerScreen.nearQuestion)”")
        let swap = screen.element("search.layer.swap")
        XCTAssertFalse(swap.exists, "Swap is offered before a search has run inside the list")
        screen.type(LayerScreen.swapWords)
        screen.waitForText("1 of your 3 closest matches contains these words", "after the words were searched for")
        XCTAssertTrue(swap.waitForExistence(timeout: LayerScreen.patience),
                      "The row offers no Swap once a search has run inside the list")
        XCTAssertEqual(swap.label, "Swap the two searches")
        swap.tap()

        // A phrase beside a word is not one phrase, so the row quotes the words as typed, the phrase's marks included
        // (plan of record §6g).
        screen.waitForBaseRow("Searching within 2 results for “\(LayerScreen.swapWords)”")
        screen.waitForText("2 results · 1 ranked · 1 not ranked", "after the swap")
        let rows = screen.listed()
        XCTAssertEqual(rows.map(\.title), ["UI Test Document Two"], "The document with a vector, ranked")
        XCTAssertEqual(rows.map(\.score), ["Semantic match 100 percent"])
        let unranked = screen.element("search.layer.unranked")
        XCTAssertTrue(unranked.waitForExistence(timeout: LayerScreen.patience), "No line counts the unranked row")
        XCTAssertEqual(unranked.label, "1 result not ranked by meaning")
        let nested = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'UI Test Nested Document Two'")).firstMatch
        XCTAssertTrue(nested.waitForExistence(timeout: LayerScreen.patience),
                      "The document the Meaning list never held, which the words find, is not listed")
        XCTAssertGreaterThanOrEqual(nested.frame.minY, unranked.frame.maxY - 0.5, "It is not under the line")
        XCTAssertEqual(app.searchFields.firstMatch.value as? String, LayerScreen.nearQuestion,
                       "The field holds the list's question, asked inside the words' results")
        XCTAssertFalse(screen.modePicker.exists, "The row still takes the Keywords | Meaning control's place")

        // And back: a swap is a list held with a search inside it, which can be swapped in turn.
        let on = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: swap)
        XCTAssertEqual(XCTWaiter.wait(for: [on], timeout: LayerScreen.patience), .completed, "Swap stays off")
        swap.tap()
        screen.waitForBaseRow("Searching within 3 closest matches to “\(LayerScreen.nearQuestion)”")
        screen.waitForText("1 of your 3 closest matches contains these words", "after swapping back")
        XCTAssertEqual(screen.listed().map(\.title), ["UI Test Document Two"])
        XCTAssertEqual(app.searchFields.firstMatch.value as? String, LayerScreen.swapWords,
                       "The field holds the words again")
    }
}

// MARK: - SearchWithinTheWholeMatchTests (#1577 lane 6)

/// A keyword list cut at its ceiling, ranked whole by a question (#1577 lane 6), end to end through lane 3's Meaning
/// seam and a lowered ceiling (`UITestSearchCeiling`).
///
/// ## What it drives
/// The launch fetches a search with text in it at four rows, so the fixture's phrase, which all six of its documents
/// hold, lists four of them, "4 loaded · 6 total": a list cut at its ceiling, as 1,000 of 35,275 are. Sort ▸ Closest to
/// a Question… holds it, and the row names the whole match: "all 6 results". The near question then ranks all six, not
/// the four loaded: the three with vectors, Two, One and Three, at 100, 32 and 3 percent, which of them were loaded or
/// not, under "Closest 3 of 6 results · 3 not ranked", and one of the list's own unranked rows after them, the room the
/// ceiling leaves, under "1 result not ranked by meaning".
///
/// ## Devices
/// An iPhone 17 and an iPad Pro 13-inch (M5), `OS=27.0`; nothing skips. On the code before lane 6, with the seam and
/// this suite added, it fails at the row, which names "the first 4 of 6 results", and a ranking there ranks only the
/// four loaded.
///
/// Version history:
///   1.0 — #1577 lane 6: initial implementation
///   1.1 — plan of record §6g: the row quotes the fixture's phrase once
@MainActor
final class SearchWithinTheWholeMatchTests: XCTestCase {

    private var app: XCUIApplication!
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    override func setUp() async throws {
        continueAfterFailure = false
        app = LayerScreen.launch(searchCeiling: 4)
        XCTAssertTrue(navigator.select(.search, resolveTimeout: 15).tapped,
                      "Could not open the Search tab, so this suite would read another screen")
    }

    override func tearDown() async throws {
        if let app {
            LayerScreen(app: app).leave()
            app.terminate()
        }
        app = nil
    }

    /// The phrase's six documents, four loaded, held from the Sort menu and ranked whole by the near question.
    func testAQuestionRanksTheWholeMatchOfAListCutAtItsCeiling() throws {
        let screen = LayerScreen(app: app)
        screen.searchUntilHeader(LayerScreen.fixturePhrase, reads: "4 loaded · 6 total")
        screen.waitForTheMeaningEngine()
        let sort = screen.element("search.actions.sort")
        XCTAssertTrue(sort.waitForExistence(timeout: LayerScreen.patience), "The actions bar has no Sort menu")
        sort.tap()
        let closest = app.buttons["Closest to a Question…"].firstMatch
        XCTAssertTrue(closest.waitForExistence(timeout: LayerScreen.patience), "The Sort menu has no Closest to a Question…")
        closest.tap()

        screen.waitForBaseRow("Searching within all 6 results for “\(LayerScreen.fixturePhraseWords)”")

        screen.type(LayerScreen.nearQuestion)
        screen.waitForText("Closest 3 of 6 results · 3 not ranked", "after the question was asked")
        let rows = screen.listed()
        XCTAssertEqual(rows.map(\.title), ["UI Test Document Two", "UI Test Document One", "UI Test Document Three"],
                       "All three with vectors are ranked, closest first, those the list had not loaded among them")
        XCTAssertEqual(rows.map(\.score),
                       ["Semantic match 100 percent", "Semantic match 32 percent", "Semantic match 3 percent"])
        let unranked = screen.element("search.layer.unranked")
        XCTAssertTrue(unranked.waitForExistence(timeout: LayerScreen.patience), "No line counts the unranked rows")
        XCTAssertEqual(unranked.label, "1 result not ranked by meaning",
                       "One of the list's own unranked rows, the room the ceiling of four leaves")
    }
}

// MARK: - SearchLayerBaseRowFitTests (#1577 lane 4)

/// The row that names a held base, and the actions bar under it, at five text sizes on the two iPhone widths.
///
/// The row takes the Keywords | Meaning control's place in the top inset, which already ran off both edges once
/// (#1307), so its frames are measured as the actions bar's are (`SearchActionsBarFitTests`): inside the window, under
/// the search field, above the actions bar, its close button 44 points or more, and a result still starting between
/// the bars and the tab shell's banner, which it requires, as `ResultSelectionBarFitTests` does. Holding the list hands
/// the field the keyboard, and the banner gives way to a keyboard (#1070), so the layout is measured as a reader reads
/// the list, with the keyboard put away. Each accessibility size proves it took effect by the search field's height.
///
/// Each size is measured once with a held keyword list, before a search has run inside it. Since #1577 lane 7 each is
/// measured a second time, with Swap on the row, which it offers once a search has run inside the list: the near
/// question's Meaning list, whose sentence is the longest the fixture gives the row, held, with words found in it. Swap
/// narrows the sentence's column, so the row is measured where it is narrowest too: Swap after the sentence and before
/// the ✕, inside the window, 44 points tall, and a result still above the banner.
///
/// The way to that row passes through a plain Meaning list. Lane 7 measured it at L, XXXL and AX1 only: at AX3 and AX5
/// the Meaning strip made the top inset taller than an iPhone 17's screen, SwiftUI centred it, and the More menu sat at
/// y −394 with the list below the screen. Since the strip's fix (2026-10-18, `MeaningStripFitTests`) the strip is one
/// row at the accessibility sizes, and all five sizes measure the row with Swap.
///
/// ## Devices
/// An iPhone 17 (402 pt) and an iPhone SE (3rd generation, 375 pt, iOS 27). It skips at iPad width, where the row fits
/// either way.
///
/// Version history:
///   1.0 — #1577 lane 4: initial implementation
///   1.1 — #1577 lane 7: L, XXXL and AX1 measured again with Swap on the row
///   1.2 — 2026-10-18: AX3 and AX5 measured with Swap too, since the Meaning strip's fix
@MainActor
final class SearchLayerBaseRowFitTests: XCTestCase {

    private var app: XCUIApplication!
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    /// The search field's height at the default text size, measured once per run.
    private static var defaultFieldHeight: CGFloat = 0
    private static let phoneOnlyReason =
        "iPhone-only: at iPad width the row fits either way, so a pass there is not evidence"

    override func tearDown() async throws {
        if let app {
            LayerScreen(app: app).leave()
            app.terminate()
        }
        app = nil
    }

    func testBaseRowFitsAtStandardSize() throws { try assertBaseRowFits(at: nil, named: "L") }
    func testBaseRowFitsAtLargestStandardSize() throws {
        try assertBaseRowFits(at: "UICTContentSizeCategoryXXXL", named: "XXXL")
    }
    func testBaseRowFitsAtFirstAccessibilitySize() throws {
        try assertBaseRowFits(at: "UICTContentSizeCategoryAccessibilityM", named: "AX1")
    }
    func testBaseRowFitsAtMiddleAccessibilitySize() throws {
        try assertBaseRowFits(at: "UICTContentSizeCategoryAccessibilityXL", named: "AX3")
    }
    func testBaseRowFitsAtLargestAccessibilitySize() throws {
        try assertBaseRowFits(at: "UICTContentSizeCategoryAccessibilityXXXL", named: "AX5")
    }

    private func assertBaseRowFits(at category: String?, named size: String) throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, Self.phoneOnlyReason)
        if Self.defaultFieldHeight == 0 {
            launch(at: nil)
            let field = app.searchFields.firstMatch
            XCTAssertTrue(field.waitForExistence(timeout: LayerScreen.patience), "The Search tab shows no search field")
            Self.defaultFieldHeight = field.frame.height
        }
        launch(at: category)
        let screen = LayerScreen(app: app)
        // The longest of the bases the suite can hold: a keyword list of six, named by its quoted phrase. One
        // listed row is enough, and all there is at AX5, where the list draws only the rows near the screen.
        screen.searchUntilListed(LayerScreen.fixturePhrase, count: 1)
        screen.chooseFromTheMoreMenu("Rank These Results by a Question")

        let base = screen.element("search.layer.base")
        let leave = screen.element("search.layer.leave")
        XCTAssertTrue(base.waitForExistence(timeout: LayerScreen.patience), "No row names the held base at \(size)")
        XCTAssertTrue(leave.waitForExistence(timeout: LayerScreen.patience), "The base row has no close button at \(size)")
        // The layout a reader reads the list in: the keyboard the hold raised put away, and the banner back.
        screen.putTheKeyboardAway()
        XCTAssertTrue(base.exists, "Putting the keyboard away let go of the held list at \(size)")
        // Each frame is read once: a read is a query, 4 to 13 s apiece under Xcode 27.1, and reading them as needed
        // took the AX1 test past 10 minutes on a loaded Mac (2026-10-17).
        let window = app.windows.firstMatch.frame
        let field = app.searchFields.firstMatch.frame
        let bar = ["search.actions.filter", "search.actions.examine", "search.actions.checklist",
                   "search.actions.sort", "search.actions.more"].map { ($0, screen.element($0)) }
        for (identifier, element) in bar {
            XCTAssertTrue(element.waitForExistence(timeout: LayerScreen.patience), "\(identifier) is not in the tree at \(size)")
        }
        let barFrames = bar.map { ($0.0, $0.1.frame) }
        let baseFrame = base.frame
        let leaveFrame = leave.frame
        // Up for as long as no iCloud account syncs, so always on a test simulator with the keyboard away:
        // `ResultSelectionBarFitTests` relies on it the same way.
        let banner = screen.element("tabShell.syncBanner")
        XCTAssertTrue(banner.waitForExistence(timeout: LayerScreen.patience),
                      "The tab shell's banner is not showing, so nothing here is measured against it")
        let bannerTop = banner.frame.minY
        let firstRow = screen.fixtureRows.allElementsBoundByIndex.map(\.frame.minY).min()
        let barTop = barFrames.map(\.1.minY).min() ?? 0
        let barFoot = barFrames.map(\.1.maxY).max() ?? 0
        print("[#1577] \(size) window \(Int(window.width))x\(Int(window.height)) field foot \(Int(field.maxY)) "
              + "base x \(Int(baseFrame.minX))–\(Int(baseFrame.maxX)) y \(Int(baseFrame.minY))–\(Int(baseFrame.maxY)) "
              + "leave x \(Int(leaveFrame.minX))–\(Int(leaveFrame.maxX)) \(Int(leaveFrame.width))x\(Int(leaveFrame.height)) "
              + "bar y \(Int(barTop))–\(Int(barFoot)) "
              + "banner top \(Int(bannerTop)) first row top \(firstRow.map { String(Int($0)) } ?? "none")")

        for (identifier, frame) in [("search.layer.base", baseFrame), ("search.layer.leave", leaveFrame)] + barFrames {
            XCTAssertGreaterThanOrEqual(frame.minX, 0, "\(identifier) runs off the leading edge at \(size): \(frame)")
            XCTAssertLessThanOrEqual(frame.maxX, window.maxX + 0.5, "\(identifier) runs off the trailing edge at \(size): \(frame)")
            XCTAssertGreaterThan(frame.width, 0, "\(identifier) has no width at \(size)")
        }
        XCTAssertLessThanOrEqual(baseFrame.maxX, leaveFrame.minX + 0.5, "The sentence runs under its close button at \(size)")
        XCTAssertGreaterThanOrEqual(leaveFrame.width, 44 - 0.5, "The close button is under 44 points wide at \(size)")
        XCTAssertGreaterThanOrEqual(leaveFrame.height, 44 - 0.5, "The close button is under 44 points tall at \(size)")
        // Under the search field, and above the actions bar.
        XCTAssertGreaterThanOrEqual(min(baseFrame.minY, leaveFrame.minY), field.maxY - 0.5,
                                    "The base row is behind the search field at \(size)")
        XCTAssertGreaterThanOrEqual(barTop, max(baseFrame.maxY, leaveFrame.maxY) - 0.5,
                                    "The actions bar is drawn over the base row at \(size)")
        // A result still starts between the bars and the banner, which the rows above the list give way to.
        let rowTop = try XCTUnwrap(firstRow, "no result row is in the tree at \(size)")
        XCTAssertGreaterThanOrEqual(rowTop, barFoot - 0.5, "the first result is drawn over the actions bar at \(size)")
        XCTAssertLessThan(rowTop, bannerTop, "no result starts above the banner at \(size)")
        XCTAssertLessThanOrEqual(barFoot, bannerTop + 0.5, "the actions bar is under the banner at \(size)")

        // The category really applied.
        if let category, category.contains("Accessibility") {
            let height = field.height
            XCTAssertGreaterThan(height, Self.defaultFieldHeight + 1, """
                \(size) rendered the search field at its default height (\(height) vs \(Self.defaultFieldHeight)): the \
                content-size category did not take effect, so this run says nothing
                """)
        }

        try assertTheRowWithSwapFits(at: size, screen: screen)
    }

    /// The row with Swap on it (#1577 lane 7): the near question's Meaning list held, whose sentence is the longest the
    /// fixture gives the row, with words found in it, the keyboard the search raised put away.
    private func assertTheRowWithSwapFits(at size: String, screen: LayerScreen) throws {
        let leave = screen.element("search.layer.leave")
        leave.tap()
        XCTAssertTrue(screen.modePicker.waitForExistence(timeout: LayerScreen.patience),
                      "Closing the row at \(size) did not bring the Keywords | Meaning control back")
        screen.chooseMeaning()
        screen.searchUntilListed(LayerScreen.nearQuestion, count: 1)
        screen.chooseFromTheMoreMenu("Find Words in These Matches")
        screen.type("Two")
        screen.waitForText("1 of your 3 closest matches contains these words", "at \(size), after the words")
        let swap = screen.element("search.layer.swap")
        XCTAssertTrue(swap.waitForExistence(timeout: LayerScreen.patience), "The row offers no Swap at \(size)")
        screen.putTheKeyboardAway()

        let window = app.windows.firstMatch.frame
        let field = app.searchFields.firstMatch.frame
        let base = screen.element("search.layer.base")
        XCTAssertTrue(base.exists, "Putting the keyboard away let go of the held list at \(size)")
        let baseFrame = base.frame
        let swapFrame = swap.frame
        let leaveFrame = leave.frame
        // The bar's two outermost controls: its height and its edges.
        let filter = screen.element("search.actions.filter").frame
        let more = screen.element("search.actions.more").frame
        let banner = screen.element("tabShell.syncBanner")
        XCTAssertTrue(banner.waitForExistence(timeout: LayerScreen.patience),
                      "The tab shell's banner is not showing, so nothing here is measured against it")
        let bannerTop = banner.frame.minY
        let firstRow = screen.fixtureRows.allElementsBoundByIndex.map(\.frame.minY).min()
        let barTop = min(filter.minY, more.minY)
        let barFoot = max(filter.maxY, more.maxY)
        print("[#1577 lane 7] \(size) window \(Int(window.width))x\(Int(window.height)) field foot \(Int(field.maxY)) "
              + "base x \(Int(baseFrame.minX))–\(Int(baseFrame.maxX)) y \(Int(baseFrame.minY))–\(Int(baseFrame.maxY)) "
              + "swap x \(Int(swapFrame.minX))–\(Int(swapFrame.maxX)) \(Int(swapFrame.width))x\(Int(swapFrame.height)) "
              + "leave x \(Int(leaveFrame.minX))–\(Int(leaveFrame.maxX)) "
              + "bar y \(Int(barTop))–\(Int(barFoot)) "
              + "banner top \(Int(bannerTop)) first row top \(firstRow.map { String(Int($0)) } ?? "none")")

        for (identifier, frame) in [("search.layer.base", baseFrame), ("search.layer.swap", swapFrame),
                                    ("search.layer.leave", leaveFrame), ("search.actions.filter", filter),
                                    ("search.actions.more", more)] {
            XCTAssertGreaterThanOrEqual(frame.minX, 0, "\(identifier) runs off the leading edge at \(size): \(frame)")
            XCTAssertLessThanOrEqual(frame.maxX, window.maxX + 0.5, "\(identifier) runs off the trailing edge at \(size): \(frame)")
            XCTAssertGreaterThan(frame.width, 0, "\(identifier) has no width at \(size)")
        }
        XCTAssertLessThanOrEqual(baseFrame.maxX, swapFrame.minX + 0.5, "The sentence runs under Swap at \(size)")
        XCTAssertLessThanOrEqual(swapFrame.maxX, leaveFrame.minX + 0.5, "Swap runs under the close button at \(size)")
        XCTAssertGreaterThanOrEqual(swapFrame.width, 44 - 0.5, "Swap is under 44 points wide at \(size)")
        XCTAssertGreaterThanOrEqual(swapFrame.height, 44 - 0.5, "Swap is under 44 points tall at \(size)")
        XCTAssertGreaterThanOrEqual(min(baseFrame.minY, swapFrame.minY, leaveFrame.minY), field.maxY - 0.5,
                                    "The base row is behind the search field at \(size)")
        XCTAssertGreaterThanOrEqual(barTop, max(baseFrame.maxY, swapFrame.maxY, leaveFrame.maxY) - 0.5,
                                    "The actions bar is drawn over the base row at \(size)")
        let rowTop = try XCTUnwrap(firstRow, "no result row is in the tree at \(size), with Swap on the row")
        XCTAssertGreaterThanOrEqual(rowTop, barFoot - 0.5, "the first result is drawn over the actions bar at \(size)")
        XCTAssertLessThan(rowTop, bannerTop, "no result starts above the banner at \(size), with Swap on the row")
    }

    private func launch(at category: String?) {
        if let app {
            LayerScreen(app: app).leave()
            app.terminate()
        }
        app = LayerScreen.launch(contentSizeCategory: category)
        XCTAssertTrue(navigator.select(.search, resolveTimeout: 15).tapped,
                      "Could not open the Search tab, so this suite would read another screen")
    }
}

// MARK: - SaveSearchSheetTests

/// Search ▸ More ▸ Save this search on iPhone and iPad: the sheet offers the search's words as the name, and its Save is
/// on as it opens, so the name can be saved as offered.
///
/// ## The defect it guards
/// The sheet opened with the search's words in its name field and its Save off, and Save came on only once the name
/// was edited (found 2026-10-17 by `SearchWithinResultsTests`, which typed a space to get past it). The More menu's
/// command set the name and the sheet's Bool, two `@State`s of `SearchView` that its body never reads, so the body did
/// not run again, and the sheet was built from the closure made before the tap. A probe measured it on an iPhone 17,
/// iOS 27.0: no body ran between the tap and the sheet, whose content read the name as empty and its own Bool as false.
/// The field showed the words, since a binding reads the stored value; Save's `.disabled` was worked out from the old
/// one. The sheet now takes a `SaveSearchRequest` as its item and keeps the name as its own state, #1590's shape. Like
/// #1590's, the defect needs the launch's first Save this search, so the test opens the sheet before anything else.
///
/// ## Devices
/// An iPhone 17 and an iPad Pro 13-inch (M5), `OS=27.0`; nothing skips. The sheet is one view on both, a form sheet on
/// the iPad. On the code before the fix it fails on both at "Save is off".
///
/// Version history:
///   1.0 — the Save Search sheet's Save, on as it opens: initial implementation
@MainActor
final class SaveSearchSheetTests: XCTestCase {

    private var app: XCUIApplication!
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    override func setUp() async throws {
        continueAfterFailure = false
        app = LayerScreen.launch()
        XCTAssertTrue(navigator.select(.search, resolveTimeout: 15).tapped,
                      "Could not open the Search tab, so this suite would read another screen")
    }

    override func tearDown() async throws {
        if let app {
            LayerScreen(app: app).leave()
            app.terminate()
        }
        app = nil
    }

    /// The fixture's phrase, saved under the name the sheet offers, with no edit to it.
    func testTheOfferedNameSavesAsItIs() throws {
        let screen = LayerScreen(app: app)
        screen.searchUntilListed(LayerScreen.fixturePhrase, count: 3)
        screen.chooseFromTheMoreMenu("Save this search")
        let sheet = app.navigationBars["Save Search"]
        XCTAssertTrue(sheet.waitForExistence(timeout: LayerScreen.patience), "Save this search opened no sheet")
        let name = app.textFields["Name this search"].firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: LayerScreen.patience), "The sheet has no name field")
        XCTAssertEqual(name.value as? String, LayerScreen.fixturePhrase, "The sheet names the search by its words")

        // Nothing touches the field. A wait rather than one read, so a bar that catches up late still passes.
        let save = sheet.buttons["Save"].firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: LayerScreen.patience), "The sheet has no Save")
        let on = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: save)
        XCTAssertEqual(XCTWaiter.wait(for: [on], timeout: LayerScreen.patience), .completed,
                       "Save is off though the sheet offers the name \(LayerScreen.fixturePhrase)")
        save.tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: sheet)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: LayerScreen.patience), .completed, "The sheet did not close")

        // Under FRUS_UI_TEST_MODE the store is in memory, so a row of that name is this launch's save.
        screen.chooseFromTheMoreMenu("Saved searches")
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", LayerScreen.fixturePhrase)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: LayerScreen.patience),
                      "No saved search is listed under the name the sheet offered")
    }
}
