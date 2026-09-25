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
#if canImport(UIKit)
import UIKit
#endif

/// Browse Within This Scope shows the reader that the filter took (#1364).
///
/// ## What #1364 found
/// In Browse ▸ My Scopes, a scope's long-press menu offered **Browse Within This Scope**, and
/// choosing it only wrote the scope's id: the menu closed and nothing on screen changed. The amber
/// "Browsing within: …" banner lives on the Subseries list, which the reader had not opened, and
/// the corpus root's Subseries tile went on counting every volume in the series. The filter is
/// stored in UserDefaults, so it also carried into later sessions with nothing at the root to say
/// it was on.
///
/// ## The three tests, and where each can fail
/// All run on **both idioms**, because the menu item is iOS-only and the iPhone stack and the
/// iPad two-pane reach My Scopes through different containers.
///
/// - `testBrowseWithinLandsUnderTheBanner` chooses the menu item and then takes NO further step:
///   the banner must be on screen. Unfixed, the menu closes over My Scopes and the banner never
///   appears, on the iPhone stack and in the iPad detail pane alike. In the iPad two-pane it also
///   checks the list pane's Subseries tile, which stands beside the banner and is where #1364 was
///   seen still reading "553 volumes by era". A stack layout (iPhone, or an iPad below the 820 pt
///   gate) has no tile on screen at that moment, so there that check is not made, and the test
///   prints which layout it measured. An iPad Pro 11-inch is two-pane even in portrait (834 pt).
/// - `testRootTileNamesTheScopeWhenLaunchedNarrowed` launches with the filter already on — the
///   state a reader returns to in a later session — and asserts the tile's whole caption: the
///   scope's name, its two volumes and THEIR span, not the series'. Then, in My Scopes, that the
///   narrowed scope's row says so and the other scope's row does not, and that the narrowed row's
///   long-press menu offers Stop Browsing Within, not Browse Within, and that Stop takes the mark
///   off.
/// - `testAnotherScopeOffersBrowseWithinWhileNarrowed` launches narrowed to one scope and
///   long-presses the OTHER: its menu must offer Browse Within This Scope and not Stop Browsing
///   Within, and choosing it lands under the other scope's banner.
///
/// As first written, the first two FAILED on the unfixed code on both idioms — measured on iPhone
/// 17 Pro and iPad Pro 11-inch (M5), iOS 26.4. That red tree was `v2` with this suite's seams (the
/// seeder, the launch pin, the banner's identifier and the tile's accessibility value) and the two
/// refactors that carried `v2`'s behaviour into the new functions (the caption ignoring the filter,
/// the action setting only the id) — so neither idiom is a control here. Review round 1 extended
/// the suite and measured it again, on the same two devices, against mutants of the fixed code,
/// each on both idioms: with #1364's own defect (the action only writes the id) the first and third
/// fail and the second passes; the second fails against each mutant of the round's three additions
/// to it — the row mark keyed on "any filter is on", a scoped caption spanning the series, and a
/// Stop that browses within instead — and the third against Stop offered on every row while any
/// filter is on, which was built together with the row-mark mutant while the first test passed.
/// The row mark was new with #1364; Stop and the other scope's item were `v2`'s and untested.
///
/// Each keeps screenshots in the result bundle (`keepScreenshot`), because the glyph, the amber
/// banner and the tile's wrapping are drawing no assertion here reads.
///
/// ## The seam
/// `FRUS_UI_TEST_SEED_SCOPE=1` seeds two scopes with fixed ids (`UITestScopeSeeder` in the app),
/// because the UI-test store is in memory and the second and third tests must name an id before
/// the scope exists. `UITestLaunch` pins the filter off for every other suite; see its doc for
/// why that pin is not optional once this suite has run.
///
/// Version history:
///   1.0 — #1364: initial implementation
///   1.1 — #1364 review round 1: a second seeded scope, the tile's whole caption, Stop Browsing
///          Within, and `testAnotherScopeOffersBrowseWithinWhileNarrowed`
@MainActor
final class BrowseWithinScopeTests: XCTestCase {

    /// The seeded scope's id — `UITestScopeSeeder.scopeIdString` in the app target.
    private static let scopeId = "13640000-B4B4-4B4B-8B4B-000000001364"
    /// The seeded scope's name — `UITestScopeSeeder.scopeName`.
    private static let scopeName = "UI Test Scope"
    /// The other seeded scope's name — `UITestScopeSeeder.otherScopeName`.
    private static let otherScopeName = "Other UI Test Scope"
    /// The banner's text for the seeded scope — `browser.scopes.banner.active`.
    private static let bannerText = "Browsing within: UI Test Scope"
    /// The root tile's whole caption while narrowed to the seeded scope —
    /// `browser.corpus.tile.subseries.caption.scoped`. Its two volumes sit in the 1961-63 and
    /// 1969-76 eras, and a span names each era's first year.
    private static let narrowedTileCaption = "Browsing within: UI Test Scope · 2 volumes by era, 1961–1969"
    /// The scope row's accessibility value while the subseries hierarchy is narrowed to it —
    /// `browser.scopes.row.filterActive`.
    private static let rowFilterValue = "The subseries list is narrowed to this scope"
    /// The long-press menu's two filter items — `browser.scopes.menu.browseWithin` and
    /// `browser.scopes.menu.stopBrowsing`.
    private static let browseWithinItem = "Browse Within This Scope"
    private static let stopBrowsingItem = "Stop Browsing Within"

    var app: XCUIApplication!

    /// Resolves tab destinations across every representation. Shared with every other suite.
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_SCOPE"] = "1"
        // Every test here asserts screens at rest, so the iOS 27 idle-counter stall has nothing to
        // test here and every reason to be avoided (see `FRUSExplorerApp.configureUITestAnimations`).
        app.launchEnvironment["FRUS_UI_TEST_DISABLE_ANIMATIONS"] = "1"
    }

    override func tearDown() async throws {
        app = nil
    }

    // MARK: - Element queries

    /// The corpus root's Subseries tile, in the list pane or at the stack root.
    private var subseriesTile: XCUIElement { app.buttons["browse.root.subseriesTile"] }

    /// The corpus root's My Scopes row.
    private var scopesRow: XCUIElement { app.buttons["browse.root.scopesRow"] }

    /// The seeded scope's row in My Scopes — its accessibility label is "<name>, <n> volumes".
    private var seededScopeRow: XCUIElement { scopeRow(named: Self.scopeName) }

    /// The other seeded scope's row in My Scopes.
    private var otherScopeRow: XCUIElement { scopeRow(named: Self.otherScopeName) }

    /// A scope's row in My Scopes, by the start of its accessibility label. Neither seeded name
    /// begins with the other, so each prefix matches one row.
    private func scopeRow(named name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name + ",")).firstMatch
    }

    /// The "Browsing within" banner's text.
    private var banner: XCUIElement { app.staticTexts["browse.scopeFilter.banner"] }

    // MARK: - Helpers

    /// Selects Browse and reports whether it is the iPad two-pane.
    ///
    /// The two-pane's empty-detail placeholder is the layout probe (`BrowseNestedSectionTests` and
    /// `TwoPaneDocumentTests` use it): it exists only at the empty path of the two-pane, so its
    /// absence on a pad idiom means Browse fell through to the stack below the 820 pt gate.
    private func openBrowse() -> Bool {
        XCTAssertTrue(navigator.select(.browse, resolveTimeout: 15).tapped,
                      "Browse is the launch tab and reachable on every canvas measured")
        #if canImport(UIKit)
        guard UIDevice.current.userInterfaceIdiom == .pad else { return false }
        #endif
        return app.staticTexts["Choose a Subseries"].waitForExistence(timeout: 10)
    }

    /// Swipes the corpus root list up until `element` is hittable. The root is a lazy `List`, so a
    /// row below the fold is absent from the tree rather than merely off screen.
    private func scrollRootUntilHittable(_ element: XCUIElement) {
        let rootList = app.collectionViews
            .containing(.textField, identifier: "browse.root.searchField").firstMatch
        for _ in 0..<6 {
            if element.exists && element.isHittable { return }
            rootList.swipeUp(velocity: .slow)
            Thread.sleep(forTimeInterval: 0.4)
        }
    }

    /// Opens My Scopes from the corpus root and waits for the seeded scope's row.
    private func openMyScopes() {
        XCTAssertTrue(app.textFields["browse.root.searchField"].waitForExistence(timeout: 10),
                      "the corpus root did not appear")
        scrollRootUntilHittable(scopesRow)
        XCTAssertTrue(scopesRow.isHittable, "the corpus root's My Scopes row cannot be reached")
        scopesRow.tap()
        XCTAssertTrue(seededScopeRow.waitForExistence(timeout: 10), """
            My Scopes shows no row for the seeded scope "\(Self.scopeName)" — is \
            FRUS_UI_TEST_SEED_SCOPE reaching UITestScopeSeeder? Tree:
            \(app.debugDescription)
            """)
    }

    /// Waits until `element` satisfies `predicate`, returning whether it did.
    private func wait(for element: XCUIElement, toSatisfy predicate: NSPredicate,
                      timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// A predicate on an element's accessibility value containing `text`.
    private func valueContains(_ text: String) -> NSPredicate {
        NSPredicate(format: "value CONTAINS %@", text)
    }

    /// An element's accessibility value, with no value read as "".
    private func valueText(of element: XCUIElement) -> String {
        (element.value as? String) ?? ""
    }

    /// Polls `element`'s accessibility value until it reads `expected`, and returns what it last
    /// read — `nil` if the element was not on screen, as a row is not once the reader has been
    /// taken somewhere else.
    private func settledValue(of element: XCUIElement, expecting expected: String,
                              timeout: TimeInterval = 5) -> String? {
        let deadline = Date().addingTimeInterval(timeout)
        var last: String?
        repeat {
            last = element.exists ? valueText(of: element) : nil
            if last == expected { return last }
            Thread.sleep(forTimeInterval: 0.25)
        } while Date() < deadline
        return last
    }

    /// Long-presses `row` and waits for its menu to offer `offered`, asserting it does not also
    /// offer `withheld` — the two filter items are one branch, never both. Returns the offered item.
    private func openMenu(of row: XCUIElement, offering offered: String,
                          notOffering withheld: String) -> XCUIElement {
        row.press(forDuration: 1.5)
        let item = app.buttons[offered]
        XCTAssertTrue(item.waitForExistence(timeout: 5), """
            the long-press menu of "\(row.label)" does not offer \(offered). Tree:
            \(app.debugDescription)
            """)
        XCTAssertFalse(app.buttons[withheld].exists,
                       "the long-press menu of \"\(row.label)\" offers \(withheld) as well as \(offered)")
        return item
    }

    /// Keeps a screenshot in the result bundle whatever the outcome — the by-eye record of the
    /// banner, the tile and the row glyph, none of whose drawing an assertion here reads.
    private func keepScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Tests

    /// Long-press → Browse Within This Scope → the banner is on screen, with no further step.
    func testBrowseWithinLandsUnderTheBanner() throws {
        app.launchArguments = UITestLaunch.arguments()
        app.launch()
        let isTwoPane = openBrowse()
        print("[#1364] layout: \(isTwoPane ? "iPad two-pane" : "stack")")

        openMyScopes()
        // Before the choice the row carries no filter mark: the glyph's other branch.
        XCTAssertEqual(valueText(of: seededScopeRow), "",
                       "the scope's row says the list is narrowed before anything narrowed it")
        openMenu(of: seededScopeRow, offering: Self.browseWithinItem,
                 notOffering: Self.stopBrowsingItem).tap()

        // No further navigation: the reader chose the filter, and this is where they must be.
        XCTAssertTrue(wait(for: banner,
                           toSatisfy: NSPredicate(format: "exists == true AND hittable == true"),
                           timeout: 10), """
            Browse Within This Scope left no "Browsing within" banner on screen — the menu closed \
            and the reader is still where they were (#1364). Tree:
            \(app.debugDescription)
            """)
        XCTAssertEqual(banner.label, Self.bannerText)
        let window = app.windows.firstMatch.frame
        XCTAssertTrue(window.contains(banner.frame),
                      "the banner is in the tree but outside the window: \(banner.frame) in \(window)")

        if isTwoPane {
            // The list pane stands beside the banner; its tile is where #1364 was seen still
            // counting the whole series.
            XCTAssertTrue(wait(for: subseriesTile, toSatisfy: valueContains(Self.scopeName),
                               timeout: 5),
                          "the list pane's Subseries tile does not name the scope the list is "
                              + "narrowed to: \(String(describing: subseriesTile.value))")
        }
        keepScreenshot(named: "#1364 after Browse Within This Scope")

        // Leave the device un-narrowed (UITestLaunch pins it anyway), through the banner's own ✕.
        let clear = app.buttons["Stop browsing within this scope"]
        XCTAssertTrue(clear.waitForExistence(timeout: 5), "the banner has no clear button")
        clear.tap()
        XCTAssertTrue(wait(for: banner, toSatisfy: NSPredicate(format: "exists == false"),
                           timeout: 5),
                      "clearing the filter left the banner on screen")
    }

    /// Launched with the filter on → the root's tile names the scope, My Scopes marks its row and
    /// no other, and the row's Stop Browsing Within takes the mark off.
    func testRootTileNamesTheScopeWhenLaunchedNarrowed() throws {
        app.launchArguments = UITestLaunch.arguments(browseScopeFilterId: Self.scopeId)
        app.launch()
        let isTwoPane = openBrowse()
        print("[#1364] layout: \(isTwoPane ? "iPad two-pane" : "stack")")

        XCTAssertTrue(subseriesTile.waitForExistence(timeout: 10), "the corpus root has no Subseries tile")
        // The scope may be seeded after the first frame, so the caption may first read
        // `.unavailable`; wait for the named form rather than reading once.
        XCTAssertTrue(wait(for: subseriesTile, toSatisfy: valueContains(Self.scopeName),
                           timeout: 10), """
            The subseries list is narrowed to "\(Self.scopeName)" and the corpus root does not say \
            so: the Subseries tile reads "\(String(describing: subseriesTile.value))" (#1364)
            """)
        // The whole caption, because "2 volumes" alone would pass a tile that counted the scope
        // and spanned the series.
        XCTAssertEqual(valueText(of: subseriesTile), Self.narrowedTileCaption,
                       "the tile must count and span the scope's two volumes, not the series")
        keepScreenshot(named: "#1364 root, launched narrowed")

        openMyScopes()
        XCTAssertEqual(seededScopeRow.value as? String, Self.rowFilterValue, """
            My Scopes does not mark the scope the list is narrowed to — its row reads \
            "\(String(describing: seededScopeRow.value))"
            """)
        // The mark is the narrowed scope's, not every row's while some filter is on.
        XCTAssertTrue(otherScopeRow.waitForExistence(timeout: 5),
                      "My Scopes shows no row for the other seeded scope \"\(Self.otherScopeName)\"")
        XCTAssertEqual(valueText(of: otherScopeRow), "",
                       "the row of a scope the list is NOT narrowed to says it is")
        keepScreenshot(named: "#1364 My Scopes, launched narrowed")

        // The narrowed row's menu offers the way out, and it works where the reader is.
        openMenu(of: seededScopeRow, offering: Self.stopBrowsingItem,
                 notOffering: Self.browseWithinItem).tap()
        XCTAssertEqual(settledValue(of: seededScopeRow, expecting: ""), "", """
            Stop Browsing Within did not take the mark off the scope's row — or took the reader \
            away from My Scopes (a nil here). Tree:
            \(app.debugDescription)
            """)
        XCTAssertEqual(valueText(of: otherScopeRow), "")
        if isTwoPane {
            // The list pane's tile stands beside My Scopes and must stop naming the scope.
            XCTAssertTrue(wait(for: subseriesTile,
                               toSatisfy: NSPredicate(format: "NOT (value CONTAINS %@)", "Browsing within"),
                               timeout: 5),
                          "Stop Browsing Within left the tile reading \(String(describing: subseriesTile.value))")
        }
    }

    /// Launched narrowed to one scope → the OTHER scope's menu offers Browse Within, not Stop, and
    /// choosing it moves the filter to that scope, under its banner.
    func testAnotherScopeOffersBrowseWithinWhileNarrowed() throws {
        app.launchArguments = UITestLaunch.arguments(browseScopeFilterId: Self.scopeId)
        app.launch()
        let isTwoPane = openBrowse()
        print("[#1364] layout: \(isTwoPane ? "iPad two-pane" : "stack")")

        openMyScopes()
        XCTAssertTrue(otherScopeRow.waitForExistence(timeout: 5),
                      "My Scopes shows no row for the other seeded scope \"\(Self.otherScopeName)\"")
        // Stop belongs to the scope the list is narrowed to; every other scope offers the filter.
        openMenu(of: otherScopeRow, offering: Self.browseWithinItem,
                 notOffering: Self.stopBrowsingItem).tap()

        XCTAssertTrue(wait(for: banner,
                           toSatisfy: NSPredicate(format: "exists == true AND hittable == true"),
                           timeout: 10), """
            Browse Within This Scope on a second scope left no "Browsing within" banner on screen. \
            Tree:
            \(app.debugDescription)
            """)
        XCTAssertEqual(banner.label, "Browsing within: \(Self.otherScopeName)",
                       "choosing another scope did not move the filter to it")
        keepScreenshot(named: "#1364 after Browse Within another scope")

        // Leave the device un-narrowed (UITestLaunch pins it anyway), through the banner's own ✕.
        let clear = app.buttons["Stop browsing within this scope"]
        XCTAssertTrue(clear.waitForExistence(timeout: 5), "the banner has no clear button")
        clear.tap()
        XCTAssertTrue(wait(for: banner, toSatisfy: NSPredicate(format: "exists == false"),
                           timeout: 5),
                      "clearing the filter left the banner on screen")
    }
}
