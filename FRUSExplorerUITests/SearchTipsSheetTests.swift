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
/// **Visibility is judged by frames, never by `isHittable`.** Measured on iPhone 17: a List row whose centre sat 49 pt
/// below the screen reported `isHittable == true`, and a helper that dragged from it moved nothing. A row counts as in
/// view when its centre lies inside the list's own frame, and the list is scrolled with `swipeUp()` on the list itself.
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
        XCTAssertTrue(scrollTips(until: exactWord), "The exact-word row never scrolled into view")
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
        let window = app.windows.firstMatch.frame
        XCTAssertTrue(centre(of: link, isInside: window),
                      "The Query Inspector's Search tips link is not on screen: \(link.frame) in \(window)")
        link.tap()
        assertSheetShowsTheRows()
        closeWithDone()
    }

    /// At the largest accessibility text size (AX5) More ▸ Search Tips still opens the sheet, and its last row scrolls
    /// into view.
    ///
    /// **What AX5 does to the route, measured on iPhone 17 (402 pt) at #1299**, so a later failure here can be read
    /// against it:
    /// - The actions bar overflows BOTH edges — Filter's frame starts at x = −34.7 and More search actions runs from
    ///   x = 372.3 to 436.6, its centre off screen. That overflow predates #1299 and is outside it (the owner's scope
    ///   decision); XCUITest still activates the control through its on-screen part, as a finger can, so it is asserted
    ///   reachable rather than wholly on screen.
    /// - The More menu becomes a scrolling list of 186–246 pt rows, so Search Tips — the sixth — is not in the element
    ///   tree until the menu is scrolled. A query that does not scroll reports the item missing on a correct build.
    /// - The pre-search link is NOT checked here. It lies inside the Search screen's content (y 377–791), but with iCloud
    ///   signed out the tab shell's Local Only banner is drawn OVER that content from y = 551 down, and it is an overlay
    ///   rather than an inset, so no scrolling of the prompt clears it. That banner is outside #1299.
    ///
    /// iPhone-only, as `UIObstructionTests.testChronologyRangeBarFitsAtAccessibilityTextSize` is: at iPad widths none of
    /// this crowding happens, so a green iPad run would not be evidence.
    func testSearchTipsAreReachableAtTheLargestAccessibilitySize() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone,
                          "iPhone-only: at iPad width nothing on this route crowds at AX5, so this scenario passes "
                          + "with or without a defect there")
        launch(contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL")

        let more = app.buttons["More search actions"].firstMatch
        XCTAssertTrue(more.waitForExistence(timeout: 10), "More search actions was not found")
        let window = app.windows.firstMatch.frame
        XCTAssertTrue(more.isHittable && window.intersects(more.frame),
                      "More search actions cannot be reached at AX5: frame \(more.frame) in \(window)")
        more.tap()
        let item = app.buttons[Self.moreItem].firstMatch
        XCTAssertTrue(scrollMenu(until: item), "The More menu offers no Search Tips item at AX5, even scrolled")
        item.tap()
        assertSheetShowsTheRows()
        let last = element(Self.lastRow)
        XCTAssertTrue(scrollTips(until: last, maxSwipes: 30), "The sheet's last row never scrolled into view at AX5")
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

    /// The sheet's list: the collection view holding a tip row or note. Re-resolved on every use, because a query tied
    /// to one row stops matching once that row scrolls out of the tree.
    private func tipsList() -> XCUIElement {
        app.collectionViews.containing(NSPredicate(
            format: "identifier BEGINSWITH 'search.tips.row.' OR identifier BEGINSWITH 'search.tips.note.'")).firstMatch
    }

    /// Whether `element`'s centre lies inside `container`'s frame.
    private func centre(of element: XCUIElement, isInside container: CGRect) -> Bool {
        element.exists && container.contains(CGPoint(x: element.frame.midX, y: element.frame.midY))
    }

    /// Swipes the sheet's list up until `target`'s centre is inside the list's frame. At the medium detent the first
    /// swipe raises the sheet to large.
    private func scrollTips(until target: XCUIElement, maxSwipes: Int = 15) -> Bool {
        for _ in 0..<maxSwipes {
            let list = tipsList()
            guard list.exists else { return false }
            if centre(of: target, isInside: list.frame) { return true }
            list.swipeUp()
        }
        let list = tipsList()
        return list.exists && centre(of: target, isInside: list.frame)
    }

    /// Swipes the open More menu up until `item`'s centre is on screen.
    private func scrollMenu(until item: XCUIElement, maxSwipes: Int = 8) -> Bool {
        let labels = ["Save this search", "Save as Working Corpus…", "Saved searches", "Find by citation",
                      "Look up an abbreviation", Self.moreItem]
        let window = app.windows.firstMatch.frame
        for _ in 0..<maxSwipes {
            if centre(of: item, isInside: window) { return true }
            let menu = app.collectionViews.containing(NSPredicate(format: "label IN %@", labels)).firstMatch
            guard menu.waitForExistence(timeout: 3) else { return false }
            menu.swipeUp()
        }
        return centre(of: item, isInside: window)
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
