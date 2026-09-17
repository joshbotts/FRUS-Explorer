// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import XCTest

// MARK: - SearchTipsSheetTests

/// Runtime coverage for the iOS and iPadOS Search Tips sheet (#1299): that each tap-reachable entry point opens it, that
/// it shows the shared rows, that its navigation-bar Done closes it, and that it stays usable at the largest
/// accessibility text size.
///
/// `SearchTipsWiringTests` reads where the entry points are declared; this suite is what shows a reader can actually
/// reach them. The Find-menu item is not driven here — no suite in this target sends a key chord or opens the iPadOS
/// menu bar — so it rests on the source pin.
///
/// **Rows are found by accessibility identifier, not by their text.** Each row is ONE accessibility element whose label
/// is its spoken example and detail (`SearchTip.accessibilityLabel`), so the chip's own `Text("=containment")` is
/// deliberately absent from the element tree and a `staticTexts["=containment"]` query would fail against a correct
/// sheet. The label is asserted instead, which is what VoiceOver reads.
///
/// **Every test closes what it opens**, through the navigation-bar Done and again in `tearDown`
/// (`UITestPresentation.dismissAnyPresentation`), because a sheet left standing is what the next launch restores (#1279).
///
/// Version history:
///   1.0 — #1299: initial implementation
@MainActor
final class SearchTipsSheetTests: XCTestCase {

    /// The sheet's navigation title.
    private static let title = "Search Tips"
    /// The More menu's item.
    private static let moreItem = "Search Tips"
    /// The identifier of the exact-word row, the row whose chip the issue names.
    private static let exactWordRow = "search.tips.row.exactWord"
    /// The identifier of the first row.
    private static let firstRow = "search.tips.row.allWords"
    /// The identifier of the LAST row in Keywords mode: the iOS scope note.
    private static let lastRow = "search.tips.note.scopeIOS"

    var app: XCUIApplication!

    /// Read through a closure: each test mints a fresh `XCUIApplication`, and a stored reference would leave the
    /// navigator driving a dead process.
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    override func tearDownWithError() throws {
        UITestPresentation.dismissAnyPresentation(in: app)
        app?.terminate()
        app = nil
    }

    // MARK: - Tests

    /// More ▸ Search Tips opens the sheet on its rows, and Done closes it.
    func testMoreMenuOpensAndClosesSearchTips() throws {
        launch()
        openFromMoreMenu()
        assertSheetShowsTheRows()

        let exactWord = element(Self.exactWordRow)
        XCTAssertTrue(scroll(until: exactWord), "The exact-word row never scrolled into view")
        XCTAssertTrue(exactWord.label.hasPrefix("equals sign, containment"),
                      "The exact-word row should read its example as \"equals sign, containment\"; it reads "
                      + "\"\(exactWord.label)\"")

        closeWithDone()
    }

    /// The pre-search screen's link opens the same sheet.
    func testPreSearchLinkOpensSearchTips() throws {
        launch()
        let link = element("search.tips.link.presearch")
        XCTAssertTrue(link.waitForExistence(timeout: 10),
                      "The pre-search screen offers no Search tips link. Buttons: \(visibleButtonLabels())")
        link.tap()
        assertSheetShowsTheRows()
        closeWithDone()
    }

    /// A query the parser refuses shows a link below the Query Inspector, and it opens the same sheet.
    func testRefusedQueryOffersSearchTipsBelowTheInspector() throws {
        launch()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "The Search field was not found")
        field.tap()
        field.typeText("-korea")

        let link = element("search.tips.link.inspector")
        XCTAssertTrue(link.waitForExistence(timeout: 10),
                      "A refused query (-korea) shows no Search tips link below the Query Inspector. "
                      + "Buttons: \(visibleButtonLabels())")
        XCTAssertTrue(link.isHittable, "The Query Inspector's Search tips link is on screen but not hittable")
        link.tap()
        assertSheetShowsTheRows()
        closeWithDone()
    }

    /// At the largest accessibility text size the More menu is still reachable, the sheet opens, and its last row
    /// scrolls into view.
    ///
    /// iPhone-only, as `UIObstructionTests.testChronologyRangeBarFitsAtAccessibilityTextSize` is: at iPad widths the
    /// actions bar fits either way, so a green iPad run would not be evidence.
    func testSearchTipsAreReachableAtTheLargestAccessibilitySize() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone,
                          "iPhone-only: at iPad width the actions bar fits at every text size, so this scenario "
                          + "passes with or without a defect there")
        launch(contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL")

        let more = app.buttons["More search actions"].firstMatch
        XCTAssertTrue(more.waitForExistence(timeout: 10), "More search actions was not found")
        XCTAssertTrue(more.isHittable,
                      "More search actions is not hittable at AX5: frame \(more.frame) in a window of "
                      + "\(app.windows.firstMatch.frame)")
        more.tap()
        let item = app.buttons[Self.moreItem].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5), "The More menu offers no Search Tips item at AX5")
        item.tap()
        assertSheetShowsTheRows()

        let last = element(Self.lastRow)
        XCTAssertTrue(scroll(until: last, maxDrags: 40),
                      "The sheet's last row never scrolled into view at AX5")
        closeWithDone()
    }

    // MARK: - Steps

    private func launch(contentSizeCategory: String? = nil) {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchArguments = UITestLaunch.arguments(startingOn: .search,
                                                     contentSizeCategory: contentSizeCategory)
        app.launch()
        // Asserted, not attempted (#1279): every step below reads the Search tab.
        XCTAssertTrue(navigator.select(.search, resolveTimeout: 15).tapped,
                      "Could not open the Search tab, so this suite would read another screen")
    }

    private func openFromMoreMenu() {
        let more = app.buttons["More search actions"].firstMatch
        XCTAssertTrue(more.waitForExistence(timeout: 10), "More search actions was not found")
        more.tap()
        let item = app.buttons[Self.moreItem].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5),
                      "The More menu offers no Search Tips item. Buttons: \(visibleButtonLabels())")
        item.tap()
    }

    private func assertSheetShowsTheRows() {
        XCTAssertTrue(app.navigationBars[Self.title].waitForExistence(timeout: 5),
                      "The Search Tips sheet did not open")
        let first = element(Self.firstRow)
        XCTAssertTrue(first.waitForExistence(timeout: 5), "The sheet shows no syntax rows")
        XCTAssertTrue(first.label.hasPrefix("berlin crisis."),
                      "The first row should read its example then its detail; it reads \"\(first.label)\"")
    }

    private func closeWithDone() {
        let done = app.navigationBars[Self.title].buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5), "The sheet has no navigation-bar Done")
        done.tap()
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: app.navigationBars[Self.title])
        waitForExpectations(timeout: 5)
    }

    // MARK: - Queries

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// Drags the sheet's list up until `target` is hittable, starting each drag on the lowest row still hittable, so
    /// the drag lands inside the sheet whichever detent or form-sheet size it has.
    private func scroll(until target: XCUIElement, maxDrags: Int = 15) -> Bool {
        for _ in 0..<maxDrags {
            if target.exists && target.isHittable { return true }
            let rows = app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier BEGINSWITH 'search.tips.'"))
                .allElementsBoundByIndex
                .filter { $0.exists && $0.isHittable }
            guard let anchor = rows.max(by: { $0.frame.midY < $1.frame.midY }) else { return false }
            let start = anchor.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -220)))
        }
        return target.exists && target.isHittable
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
