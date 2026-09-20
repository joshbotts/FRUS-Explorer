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
///   1.1 — #1299 follow-up: the pre-search link at AX5 under the Local Only banner — the one entry point the first
///         round measured as unreachable and left unchecked
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

    override func tearDown() async throws {
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
    /// - The actions bar USED to overflow both edges — Filter's frame started at x = −34.7 and More ran
    ///   from x = 372.3 to 436.6, its centre off screen. #1307 capped the bar's glyphs, so both now sit
    ///   inside the window and this scenario asserts containment. `SearchActionsBarFitTests` below measures
    ///   the bar itself at five text sizes on two widths.
    /// - The More menu becomes a scrolling list of 186–246 pt rows, so Search Tips — the sixth — is not in the element
    ///   tree until the menu is scrolled. A query that does not scroll reports the item missing on a correct build.
    /// - The pre-search link is checked by its own scenario below, because the tab shell's Local Only banner covers it.
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
        // `contains`, not `intersects` (#1307): with the old uncapped glyphs this control ran
        // from x = 372.3 to 436.6 on a 402 pt screen — more than half of it off screen — and an
        // intersects test passed anyway, so it could not see the defect it sat beside.
        XCTAssertTrue(more.isHittable && window.contains(more.frame),
                      "More search actions is not wholly on screen at AX5: \(more.frame) in \(window)")
        more.tap()
        let item = app.buttons[Self.moreItem].firstMatch
        XCTAssertTrue(scrollMenu(until: item), "The More menu offers no Search Tips item at AX5, even scrolled")
        item.tap()
        assertSheetShowsTheRows()
        let last = element(Self.lastRow)
        XCTAssertTrue(scrollTips(until: last, maxSwipes: 30), "The sheet's last row never scrolled into view at AX5")
        closeWithDone()
    }

    /// At AX5 the pre-search Search tips link scrolls clear of the tab shell's Local Only banner, and opens the sheet.
    ///
    /// **Why this needs its own scenario, measured on iPhone 17 (402 pt) at #1299:** the banner is a bottom
    /// `safeAreaInset` the tab shell applies OUTSIDE `SearchView`'s navigation stack, which does not pass it on, so it is
    /// drawn OVER the Search content rather than beside it — from y = 551 at AX5, over a prompt area running to y = 791.
    /// The link sat at y 707–770, entirely under it, and the prompt's scroll view reported one page, so no scrolling
    /// moved it. Every UI-test launch runs without CloudKit, so the banner is always up here, which is what lets the
    /// scenario require it rather than hope for it.
    ///
    /// The drags start just above the banner and never on it, so a gesture the banner swallowed cannot pass for a view
    /// that would not scroll.
    func testPreSearchLinkScrollsClearOfTheLocalOnlyBannerAtTheLargestAccessibilitySize() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone,
                          "iPhone-only: the overlap was measured on iPhone 17 (402 pt); no iPad height was measured, so "
                          + "a green iPad run would not show the defect absent")
        launch(contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL")

        let banner = app.descendants(matching: .any).matching(identifier: "tabShell.syncBanner").firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 10),
                      "The Local Only banner is not up, so this run cannot judge whether the link clears it. UI-test "
                      + "launches skip CloudKit, which should always show it.")
        let link = element("search.tips.link.presearch")
        XCTAssertTrue(link.waitForExistence(timeout: 10),
                      "The pre-search screen offers no Search tips link at AX5. Buttons: \(visibleButtonLabels())")
        // The innermost scroll view holding the link — the prompt's own, not a screen-sized ancestor.
        let scrollers = app.scrollViews.containing(.any, identifier: "search.tips.link.presearch").allElementsBoundByIndex
        let scroller = try XCTUnwrap(scrollers.min { $0.frame.height < $1.frame.height },
                                     "The pre-search link is not inside a scroll view")

        let origin = app.coordinate(withNormalizedOffset: .zero)
        var drags = 0
        while link.frame.maxY > banner.frame.minY, drags < 6 {
            // From just above the banner, up by at most 150 pt and never above the scroll view's top edge.
            let start = banner.frame.minY - 12
            let end = max(scroller.frame.minY + 8, start - 150)
            guard start - end > 40 else { break }
            origin.withOffset(CGVector(dx: scroller.frame.midX, dy: start))
                .press(forDuration: 0.1, thenDragTo: origin.withOffset(CGVector(dx: scroller.frame.midX, dy: end)))
            drags += 1
        }
        // The measurement the doc comments cite, printed so a run records it.
        print("[#1299] AX5 pre-search link after \(drags) drag(s): link \(link.frame), banner \(banner.frame), "
              + "scroll view \(scroller.frame)")
        XCTAssertLessThanOrEqual(link.frame.maxY, banner.frame.minY,
                                 "The pre-search Search tips link stays under the Local Only banner at AX5 after "
                                 + "\(drags) drag(s): link \(link.frame), banner \(banner.frame), scroll view "
                                 + "\(scroller.frame)")
        link.tap()
        assertSheetShowsTheRows()
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

// MARK: - SearchActionsBarFitTests (#1307)

/// The Search actions bar stays on screen at every text size, and its glyphs stop growing.
///
/// The row — Filter · Examine · Checklist · Sort · More — cannot wrap, scroll or fold, so at
/// accessibility sizes its `.title3` glyphs pushed it off BOTH edges: an over-wide `HStack` is
/// centred, and at AX5 on an iPhone 17 (402 pt) Filter's frame started at **x = −34.7** while More
/// ran to 436.6, its centre off screen. #1307 caps the glyphs at `FRUSTheme.barGlyphMaxScale`
/// (31 pt, which is `title3` at AX1) and leaves the Large Content Viewer to carry the magnified
/// name on a long press.
///
/// **Frames are read by accessibility identifier**, because iOS 27 reorders the XCUI tree and a
/// label query can match a covered element (`search.actions.filter` … `.more`).
///
/// **The assertion is the bar's own padding, not an arbitrary inset.** When the row fits, the
/// leading control sits at exactly the 16 pt horizontal padding and the trailing one ends 16 pt
/// from the right edge. Asserting containment in a window inset by 8 pt would discriminate by
/// about 2.7 pt at AX3, where the pre-fix frame sits at ~5.3; asserting against the padding
/// discriminates by ten.
///
/// **iPhone-only**, like its neighbour above: at iPad widths the row fits either way, so a green
/// iPad run is not evidence. Animations are off (`FRUS_UI_TEST_DISABLE_ANIMATIONS=1`) because this
/// suite measures a screen at rest — see CLAUDE.md on the iOS 27 idle stall.
///
/// Version history:
///   1.0 — 2026-09-20: #1307
@MainActor
final class SearchActionsBarFitTests: XCTestCase {

    private var app: XCUIApplication!
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    /// Every control of the bar, in the order the row lays them out.
    private static let identifiers = ["search.actions.filter", "search.actions.examine",
                                      "search.actions.checklist", "search.actions.sort",
                                      "search.actions.more"]

    /// Filter's frame width at the device's default text size, measured once per run.
    ///
    /// **An invalid category name renders at the default size and says nothing.**
    /// `UICTContentSizeCategory…` spells its tiers `M`, `L`, `XL`, `XXL`, `XXXL` — measured
    /// here, `…AccessibilityMedium` and `…AccessibilityExtraLarge` are not names, and a launch
    /// carrying one came up pixel-identical to L while its test passed. A fit assertion over a
    /// default-size bar is no evidence about accessibility sizes, so every accessibility case
    /// proves its own category took effect against this.
    private static var defaultGlyphWidth: CGFloat = 0

    /// The bar's horizontal padding, which is what a fitting row's outermost frames sit at.
    private static let barPadding: CGFloat = 16

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
    }

    override func tearDown() async throws {
        if let app { UITestPresentation.dismissAnyPresentation(in: app) }
        app = nil
        try await super.tearDown()
    }

    func testBarFitsAtStandardSize() throws {
        try assertBarFits(at: nil, named: "L")
    }

    func testBarFitsAtLargestStandardSize() throws {
        try assertBarFits(at: "UICTContentSizeCategoryXXXL", named: "XXXL")
    }

    func testBarFitsAtFirstAccessibilitySize() throws {
        try assertBarFits(at: "UICTContentSizeCategoryAccessibilityM", named: "AX1")
    }

    /// AX3 is the first size that clipped on a 402 pt iPhone before the cap.
    func testBarFitsAtMiddleAccessibilitySize() throws {
        try assertBarFits(at: "UICTContentSizeCategoryAccessibilityXL", named: "AX3")
    }

    func testBarFitsAtLargestAccessibilitySize() throws {
        try assertBarFits(at: "UICTContentSizeCategoryAccessibilityXXXL", named: "AX5")
    }

    /// The glyphs still grow with the reader's setting up to the cap, and hold there.
    ///
    /// Without this a later change could freeze them at their default size and every fit test
    /// above would still pass — the bar would fit because it had stopped responding to Dynamic
    /// Type at all, which is the opposite of what #1307 is for.
    func testGlyphsGrowUpToTheCapAndThenHold() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, Self.phoneOnlyReason)
        let atL = try width(of: "search.actions.more", at: nil)
        let atAX1 = try width(of: "search.actions.more", at: "UICTContentSizeCategoryAccessibilityM")
        let atAX5 = try width(of: "search.actions.more", at: "UICTContentSizeCategoryAccessibilityXXXL")
        XCTAssertGreaterThan(atAX1, atL * 1.3,
                             "the glyphs stopped tracking Dynamic Type: L \(atL), AX1 \(atAX1)")
        XCTAssertEqual(atAX5, atAX1, accuracy: 2,
                       "the cap is not holding: AX1 \(atAX1), AX5 \(atAX5)")
    }

    // MARK: - Helpers

    private static let phoneOnlyReason =
        "iPhone-only: at iPad width the row fits either way, so a pass there is not evidence"

    private func assertBarFits(at category: String?, named size: String) throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, Self.phoneOnlyReason)
        if Self.defaultGlyphWidth == 0 {
            Self.defaultGlyphWidth = try width(of: "search.actions.filter", at: nil)
        }
        launch(contentSizeCategory: category)

        let window = app.windows.firstMatch.frame
        var frames: [(id: String, frame: CGRect)] = []
        for identifier in Self.identifiers {
            let element = app.descendants(matching: .any)[identifier].firstMatch
            XCTAssertTrue(element.waitForExistence(timeout: 10),
                          "\(identifier) is not in the tree at \(size)")
            frames.append((identifier, element.frame))
        }
        // The measurement record, printed whether or not the assertions hold.
        print("[#1307] \(size) window \(window.width): "
              + frames.map { "\($0.id.replacingOccurrences(of: "search.actions.", with: "")) "
                  + "\(Int($0.frame.minX))–\(Int($0.frame.maxX))" }.joined(separator: ", "))

        for (identifier, frame) in frames {
            XCTAssertGreaterThanOrEqual(frame.minX, 0,
                                        "\(identifier) runs off the leading edge at \(size): \(frame)")
            XCTAssertLessThanOrEqual(frame.maxX, window.maxX,
                                     "\(identifier) runs off the trailing edge at \(size): \(frame)")
        }
        // The outermost controls sit at the bar's own padding when the row fits. A tolerance of 2
        // absorbs the glyph's side bearing without admitting the pre-fix overflow, which is tens
        // of points.
        let leading = try XCTUnwrap(frames.first)
        let trailing = try XCTUnwrap(frames.last)
        XCTAssertEqual(leading.frame.minX, Self.barPadding, accuracy: 2,
                       "the row is wider than the screen at \(size): \(leading.frame)")
        XCTAssertEqual(trailing.frame.maxX, window.maxX - Self.barPadding, accuracy: 2,
                       "the row is wider than the screen at \(size): \(trailing.frame)")

        // Order and separation: a squeeze that overlapped two controls, or a reorder, fails here.
        for (earlier, later) in zip(frames, frames.dropFirst()) {
            XCTAssertLessThan(earlier.frame.maxX, later.frame.minX,
                              "\(earlier.id) and \(later.id) overlap at \(size)")
        }

        // The category really applied. Without this an unrecognised name renders at the
        // default size and everything above passes while measuring nothing.
        if let category, category.contains("Accessibility") {
            let width = try XCTUnwrap(frames.first).frame.width
            XCTAssertGreaterThan(width, Self.defaultGlyphWidth + 1,
                                 "\(size) rendered at the default glyph width "
                                 + "(\(width) vs \(Self.defaultGlyphWidth)): the content-size "
                                 + "category did not take effect, so this run says nothing")
        }
    }

    private func width(of identifier: String, at category: String?) throws -> CGFloat {
        launch(contentSizeCategory: category)
        let element = app.descendants(matching: .any)[identifier].firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 10), "\(identifier) is not in the tree")
        return element.frame.width
    }

    private func launch(contentSizeCategory: String?) {
        XCUIDevice.shared.orientation = .portrait
        if let app { UITestPresentation.dismissAnyPresentation(in: app) }
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        // A screen at rest: XCTest's idle counter drifts on iOS 27 and each action then waits its
        // full 60 s (CLAUDE.md, #1320).
        app.launchEnvironment["FRUS_UI_TEST_DISABLE_ANIMATIONS"] = "1"
        app.launchArguments = UITestLaunch.arguments(startingOn: .search,
                                                     contentSizeCategory: contentSizeCategory)
        app.launch()
        XCTAssertTrue(navigator.select(.search, resolveTimeout: 15).tapped,
                      "Could not open the Search tab, so this suite would read another screen")
    }
}
