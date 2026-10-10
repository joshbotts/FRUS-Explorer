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

// MARK: - SearchResultAddToCollectionTests (#1576 lane 2)

/// A search result's menu adds its document to a collection, and a document the collection
/// already holds is not added again.
///
/// ## What this is the only test of
/// The unit suites drive the write (`CollectionAttachmentTests`, on a real store) and read the
/// wiring from source (`CollectionPickerDocumentsModeTests`). Neither opens a menu. This is the
/// one place the row's **Add to Collection…** is pressed, the picker is presented from the request
/// it was handed, and the collection's count is read back off the screen.
///
/// ## Fixture
/// - `FRUS_UI_TEST_SEED_VOLUME` writes the six-document volume, whose paragraphs all hold the word
///   "Synthetic": one keyword search lists every document.
/// - `FRUS_UI_TEST_SEED_PROJECT` seeds a collection, "UI Test Unattached Collection", holding one
///   document: `d1` of that volume, "UI Test Document One" (`UITestProjectSeeder`). So the picker
///   opens on "1 document", **the count has a document to be skipped for**, and no part of this
///   test drives the collection editor. The seeded project is not made active.
///
/// The collection is seeded and saved, so this does not reach the state the picker's New
/// Collection button leaves, a collection never saved; `appendDocumentsLinksBothWaysAndSaves` does.
///
/// ## Two tests, each its own launch
/// One adds two documents the collection does not hold; the other adds the one it holds. They
/// were one test until its five sheets took 292 s on an iPhone 17 while the Mac was under load
/// from other work, against the 300 s a test is allowed under iOS 27. The UI-test store is in
/// memory, so each launch starts from the seeded count.
///
/// ## Oracle: the picker's own row, and what it does not prove
/// The row is a button whose label is the collection's name and its caption, "1 document",
/// "2 documents" or "3 documents". It is read from a picker presented again each time, and the
/// caption is the collection's count of document entries in the app's one context.
/// - **It proves an entry was linked to the collection, and how many.** Two different documents
///   are added, so a request that carried the wrong row, or always the same document, comes out
///   at the wrong count.
/// - **It does not prove the save.** The UI-test store is in memory and the picker reads the same
///   context the add wrote to. `appendDocumentsLinksBothWaysAndSaves` reads a second context.
/// - The row's green checkmark is not read; it is drawn for 0.6 s.
///
/// ## Devices
/// An iPhone and an iPad, and nothing here skips. **Only the iPad guards the row's tap.** The row
/// is tapped at its centre: on an iPhone that is over the collection's name, and on an iPad's
/// wider sheet it is the blank part of the row, which took no tap until this lane gave the row a
/// content shape (measured on iPad Pro 13-inch (M5), iOS 27.0; see the runbook).
/// Under iOS 27 pass `-test-timeouts-enabled YES -maximum-test-execution-time-allowance 300`.
///
/// Version history:
///   1.0 — #1576 lane 2: initial implementation
@MainActor
final class SearchResultAddToCollectionTests: XCTestCase {

    /// The volume `FRUS_UI_TEST_SEED_VOLUME` writes.
    private static let volumeId = "frus1961-63v06"
    /// A word every fixture document's paragraph holds (`UITestVolumeSeeder.fixtureXML`).
    private static let query = "Synthetic"
    /// The seeded collection's name: `UITestProjectSeeder.collectionName`, repeated because a
    /// UI-test target cannot import the app.
    private static let collectionName = "UI Test Unattached Collection"
    /// `d1`, which the seeded collection holds.
    private static let heldDocument = "UI Test Document One"
    /// `d2`, which it does not.
    private static let newDocument = "UI Test Document Two"
    /// `d3`, which it does not either: a second document, so that the count says which was added.
    private static let secondNewDocument = "UI Test Document Three"
    /// The row menu's item, and the picker's title for one document.
    private static let menuItem = "Add to Collection…"
    private static let pickerTitle = "Add to Collection"

    /// Resolves the Search tab across every tab-bar representation.
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    /// The application under test.
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        // Every step waits on a menu or a sheet, and XCTest's idle counter drifts on iOS 27
        // (CLAUDE.md, #1320). The picker closes itself on a timer, not an animation.
        app.launchEnvironment["FRUS_UI_TEST_DISABLE_ANIMATIONS"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_VOLUME"] = Self.volumeId
        app.launchEnvironment["FRUS_UI_TEST_SEED_PROJECT"] = "1"
        app.launchArguments = UITestLaunch.arguments(startingOn: .search)
        app.launch()
        XCTAssertTrue(navigator.select(.search, resolveTimeout: 15).tapped,
                      "Could not open the Search tab, so this suite would read another screen")
    }

    override func tearDown() async throws {
        // The picker is a sheet. Cancel is its only way out, and the shared helper does not choose
        // Cancel, so it is closed here, by name, before the helper looks for anything else.
        if let app, app.state == .runningForeground {
            let cancel = app.navigationBars[Self.pickerTitle].buttons["Cancel"].firstMatch
            if cancel.exists { cancel.tap() }
        }
        UITestPresentation.dismissAnyPresentation(in: app)
        app?.terminate()
        app = nil
    }

    /// The seeded collection holds one document. Adding "UI Test Document Two" from its result row
    /// makes the count two, and adding "UI Test Document Three" from its own makes it three: each
    /// request carries its own row's document.
    func testAResultAddedFromItsMenuRaisesTheCollectionsCount() throws {
        try runTheSearch()

        // The picker opens on the seeded count, and the tap adds the one new document.
        var row = try openThePicker(from: Self.newDocument)
        XCTAssertTrue(row.label.contains("1 document"), """
            fixture: the seeded collection should open on "1 document". Its row reads "\(row.label)"
            """)
        XCTAssertFalse(row.label.contains("1 documents"), "the count's singular: \(row.label)")
        row.tap()
        waitForThePickerToClose("after adding \(Self.newDocument)")

        // Read from a picker presented again, opened from the second document's row.
        row = try openThePicker(from: Self.secondNewDocument)
        XCTAssertTrue(row.label.contains("2 documents"), """
            Add to Collection… did not add the result's document: the collection's row reads \
            "\(row.label)" where it should read "2 documents"
            """)
        row.tap()
        waitForThePickerToClose("after adding \(Self.secondNewDocument)")

        // Were every request carrying one and the same document, the count would have stayed.
        row = try openThePicker(from: Self.secondNewDocument)
        XCTAssertTrue(row.label.contains("3 documents"), """
            Adding \(Self.secondNewDocument) did not add that document: the row reads "\(row.label)" \
            where it should read "3 documents"
            """)
        cancelThePicker()
    }

    /// "UI Test Document One" is the document the seeded collection holds. Adding it from its
    /// result row closes the sheet as an add does and leaves the count at one (decision 3).
    func testADocumentTheCollectionHoldsIsNotAddedAgain() throws {
        try runTheSearch()

        var row = try openThePicker(from: Self.heldDocument)
        XCTAssertTrue(row.label.contains("1 document") && !row.label.contains("1 documents"), """
            fixture: the seeded collection should open on "1 document". Its row reads "\(row.label)"
            """)
        row.tap()
        waitForThePickerToClose("after adding \(Self.heldDocument), which was held")

        row = try openThePicker(from: Self.heldDocument)
        XCTAssertTrue(row.label.contains("1 document") && !row.label.contains("1 documents"), """
            A document the collection already held was added again: the row reads "\(row.label)"
            """)
        cancelThePicker()
    }

    // MARK: - Steps

    /// Runs the keyword search and waits for its rows.
    ///
    /// The seeded volume is indexed during launch, and a search that runs before the index holds
    /// it lists nothing and does not run again on its own. So the query is submitted until the
    /// rows are there, a few times at most.
    private func runTheSearch() throws {
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 15), "The Search tab shows no search field")
        let row = resultRow(Self.newDocument)
        for attempt in 1...5 {
            field.tap()
            if attempt > 1, let typed = field.value as? String, typed == Self.query {
                field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: typed.count))
            }
            field.typeText(Self.query + "\n")
            if row.waitForExistence(timeout: 6) { return }
        }
        XCTFail("""
            A search for "\(Self.query)" listed no row for \(Self.newDocument) in five attempts, so the \
            seeded volume is not in the index. Buttons: \(visibleButtonLabels())
            """)
    }

    /// A result row, by its document's title. The row is a button labelled with the title alone.
    private func resultRow(_ title: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", title)).firstMatch
    }

    /// Long-presses a result row, chooses Add to Collection…, and answers the seeded collection's
    /// row in the picker that opens.
    private func openThePicker(from title: String) throws -> XCUIElement {
        let row = resultRow(title)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "The results show no row for \(title)")
        row.press(forDuration: 1.2)
        let item = app.buttons[Self.menuItem].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5), """
            The row's menu has no "\(Self.menuItem)". Buttons: \(visibleButtonLabels())
            """)
        item.tap()
        XCTAssertTrue(app.navigationBars[Self.pickerTitle].waitForExistence(timeout: 10), """
            "\(Self.menuItem)" did not present the picker. Bars: \
            \(app.navigationBars.allElementsBoundByIndex.map(\.identifier))
            """)
        let collection = app.buttons
            .matching(NSPredicate(format: "label CONTAINS %@", Self.collectionName)).firstMatch
        XCTAssertTrue(collection.waitForExistence(timeout: 10), """
            The picker does not list the seeded collection. Buttons: \(visibleButtonLabels())
            """)
        return collection
    }

    /// Closes the picker with its Cancel.
    private func cancelThePicker() {
        app.navigationBars[Self.pickerTitle].buttons["Cancel"].firstMatch.tap()
        waitForThePickerToClose("after Cancel")
    }

    /// The picker dismisses itself a moment after a tap on a row, and at once on Cancel.
    private func waitForThePickerToClose(_ when: String) {
        let bar = app.navigationBars[Self.pickerTitle]
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: bar)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 10), .completed,
                       "The picker did not close \(when)")
    }

    /// The labels of the buttons on screen, for a failure message.
    private func visibleButtonLabels() -> [String] {
        app.buttons.allElementsBoundByIndex.prefix(40).map(\.label).filter { !$0.isEmpty }
    }
}
