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

/// A tab's content ends above the tab shell's banner (#1565).
///
/// ## What #1565 found
/// The shell drew its indexing and iCloud banner over the bottom of each tab's content. Every UI-test launch runs
/// without CloudKit, so the Local Only banner is always up here. Measured on iPhone 17 (iOS 26.5) on the unfixed
/// code, with the banner's top edge at y = 721.7:
/// - the Browse root, Browse ▸ Archives and the Settings root each came to rest, scrolled to their end, with their
///   last row's text at y 732–755;
/// - Settings ▸ Volumes & Storage ▸ Download from GitHub drew its Download button at y 741–775.
///
/// ## The scenarios, and which of them guard
/// Four FAILED on the unfixed code on that device, and pass with `TabShellBannerModifier`:
/// - `testBrowseRootRestsAboveTheBanner`, `testPushedListRestsAboveTheBanner` and
///   `testSettingsRootRestsAboveTheBanner` drag the screen's list to its end and require the lowest text or control
///   in it to end at or above the banner's top edge.
/// - `testPushedScreenBottomBarSitsAboveTheBanner` requires the Download button to sit above the banner. It is the
///   scenario a reservation of scroll room alone does not pass: `contentMargins` applied at the shell cleared the
///   three lists and left this button where it was.
///
/// `testEveryTabDrawsTheBannerAboveTheTabBar` passed on the unfixed code too. It guards what the fix changed in the
/// drawing: the banner is now hung in room the tab's view controller sets aside, and if that room were not there the
/// banner would sit behind the tab bar (or below the screen's edge on an iPad). It visits all five tabs, because each
/// tab draws its own banner, and taps Details, which has to open Settings.
///
/// `testBannerKeepsItsPlaceWhenTheTabsBecomeASidebar` is iPad-only and skips on an iPhone, which shows its tabs one
/// way. It switches the tabs to their other arrangement (a sidebar if they were a bar, a bar if they were a sidebar),
/// requires the banner to be on screen still, and then the Settings list to end above it.
///
/// ## An iPad is measured in landscape
/// `setUp` turns an iPad to landscape and an iPhone to portrait, and `tearDown` turns either back to portrait,
/// because a simulator keeps the orientation the last suite left it in. Measured on an iPad Pro 11-inch (M5),
/// iOS 27.0: in landscape all six scenarios run, and on the unfixed drawing five of them fail (every one but the
/// five-tab scenario); in portrait the Browse root and Archives fit above the banner, and their two scenarios skip.
///
/// ## Two ways a list scenario could lie, and what stops each
/// **A list too short to reach the banner** rests above it on any code. Each list scenario first requires that the
/// list's content ran below the banner's top edge before it was scrolled, and SKIPS when it did not, saying so. On
/// iPhone 17 none skips.
///
/// **A drag the banner swallowed** would leave the list where it was and read as "at rest". Every drag starts 12
/// points above the banner and never on it, and the list is read again after each until two readings agree.
///
/// The lowest edge is taken from ONE accessibility snapshot per reading (`XCUIElement.snapshot()`), not from a
/// query per row: a `List` is lazy, so the rows in the tree change as it scrolls, and a per-row frame query costs a
/// round trip each.
///
/// Version history:
///   1.0 — #1565: initial implementation
@MainActor
final class TabShellBannerClearanceTests: XCTestCase {

    var app: XCUIApplication!

    /// Resolves tab destinations across every representation. Shared with every other suite.
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        // Every scenario measures a screen at rest, so the iOS 27 idle-counter stall has nothing to test here and
        // every reason to be avoided (see `FRUSExplorerApp.configureUITestAnimations`).
        app.launchEnvironment["FRUS_UI_TEST_DISABLE_ANIMATIONS"] = "1"
        // A simulator keeps the orientation the last suite left it in, and the measurements here depend on it. An
        // iPad is turned to landscape, where every list in this suite is long enough to reach the banner (in portrait
        // on an iPad Pro 11-inch the Browse root and Archives fit above it, and their scenarios skip).
        #if canImport(UIKit)
        XCUIDevice.shared.orientation = UIDevice.current.userInterfaceIdiom == .pad ? .landscapeLeft : .portrait
        #endif
    }

    override func tearDown() async throws {
        // The representation persists per install, and other suites' helpers assume the one they find.
        if let sidebarWasExpanded, let app, app.state == .runningForeground,
           navigator.sidebarIsExpanded != sidebarWasExpanded {
            navigator.sidebarToggleButton(timeout: 3)?.tap()
        }
        sidebarWasExpanded = nil
        UITestPresentation.dismissAnyPresentation(in: app)
        app = nil
        // Portrait is what the suites that pin no orientation were measured in.
        XCUIDevice.shared.orientation = .portrait
    }

    /// Whether the tabs were a sidebar before a scenario switched the representation, so `tearDown` can put it back
    /// even when the scenario fails. `nil` when no scenario has switched it.
    private var sidebarWasExpanded: Bool?

    // MARK: - Element queries

    /// The tab shell's banner, by the identifier `SyncStatusBanner` carries.
    private var banner: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "tabShell.syncBanner").firstMatch
    }

    // MARK: - Reading a screen

    /// One scroll container the banner reaches, as one accessibility snapshot read it.
    private struct Reading {
        /// The container's frame on screen.
        let container: CGRect
        /// The lowest edge of any text or control inside it.
        let lowestEdge: CGFloat
        /// What that lowest element is, for the log and the failure message.
        let lowestElement: String
    }

    /// The element types that count as content a reader must be able to see and tap. Containers and scroll bars are
    /// left out: a scroll bar runs the height of its scroll view, under the banner on any code.
    ///
    /// **Images are left out too, and that is measured.** While a list has rows under the tab bar, iOS 26 keeps an
    /// image named `AdditionalDimmingOverlay` inside it, 642 × 286 pt from y = 731 on iPhone 17, wider than the
    /// screen and reaching below it. Counted as content it was the lowest element of every list not yet at its end,
    /// and on the Settings root two readings in a row agreed on it, so the scenario stopped scrolling halfway and
    /// failed on a frame that is no row. `readScrollContainers` also leaves out anything that is not inside its
    /// list's width, which is the other thing that image is not.
    private static let contentTypes: Set<XCUIElement.ElementType> = [
        .button, .staticText, .textField, .secureTextField, .searchField, .switch, .toggle, .link, .slider,
        .stepper, .picker, .segmentedControl, .textView, .menuButton, .popUpButton, .cell, .disclosureTriangle,
    ]

    /// The element types that scroll.
    private static let scrollTypes: Set<XCUIElement.ElementType> = [.collectionView, .scrollView, .table]

    /// Reads every outermost scroll container whose frame runs from above the banner's top edge down to it.
    ///
    /// Outermost, because a container inside another moves with it; and at least 200 points tall, which leaves out a
    /// row of chips that happens to sit low on the screen.
    private func readScrollContainers(under bannerFrame: CGRect) throws -> [Reading] {
        var readings: [Reading] = []

        func lowestLeaf(in node: XCUIElementSnapshot) -> (edge: CGFloat, name: String)? {
            let bounds = node.frame
            var lowest: (edge: CGFloat, name: String)?
            func visit(_ element: XCUIElementSnapshot) {
                guard element.children.isEmpty else {
                    element.children.forEach(visit)
                    return
                }
                guard Self.contentTypes.contains(element.elementType),
                      element.frame.width > 0, element.frame.height > 0,
                      element.frame.minX >= bounds.minX - 1, element.frame.maxX <= bounds.maxX + 1,
                      element.frame.maxY > (lowest?.edge ?? -.infinity) else { return }
                let name = element.identifier.isEmpty ? element.label : element.identifier
                lowest = (element.frame.maxY, "\"\(name.prefix(48))\" at y \(Self.span(element.frame))")
            }
            visit(node)
            return lowest
        }

        func walk(_ element: XCUIElementSnapshot) {
            let frame = element.frame
            if Self.scrollTypes.contains(element.elementType), frame.height >= 200,
               frame.minX < bannerFrame.maxX, frame.maxX > bannerFrame.minX,
               frame.minY < bannerFrame.minY, frame.maxY > bannerFrame.minY - 1 {
                if let lowest = lowestLeaf(in: element) {
                    readings.append(Reading(container: frame, lowestEdge: lowest.edge, lowestElement: lowest.name))
                }
                return
            }
            element.children.forEach(walk)
        }
        walk(try app.snapshot())
        return readings
    }

    /// A frame's vertical extent, to one decimal place.
    private static func span(_ frame: CGRect) -> String {
        String(format: "%.1f–%.1f", frame.minY, frame.maxY)
    }

    /// Drags every list the banner reaches to its end and requires what rests there to end above the banner.
    ///
    /// - Parameter screen: The screen's name, for the log line a run records and for the failure message.
    private func assertListsRestAboveTheBanner(_ screen: String,
                                               file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertTrue(banner.waitForExistence(timeout: 15), """
            \(screen): the Local Only banner is not up, so this run cannot judge what it covers. UI-test launches \
            skip CloudKit, which should always show it.
            """, file: file, line: line)
        let bannerFrame = banner.frame
        let before = try readScrollContainers(under: bannerFrame)
        try XCTSkipUnless(before.contains { $0.lowestEdge > bannerFrame.minY }, """
            \(screen): nothing here runs below the banner's top edge (y \(bannerFrame.minY)) before scrolling, so \
            the list is too short on this device to show whether it would rest under the banner. Read: \
            \(before.map(\.lowestElement))
            """)

        let origin = app.coordinate(withNormalizedOffset: .zero)
        var readings = before
        var drags = 0
        var agreeing = 0
        while agreeing < 2, drags < 16 {
            for reading in readings {
                // From just above the banner, up by at most 320 pt and never above the list's own top edge.
                let start = bannerFrame.minY - 12
                let end = max(reading.container.minY + 8, start - 320)
                guard start - end > 40 else { continue }
                origin.withOffset(CGVector(dx: reading.container.midX, dy: start))
                    .press(forDuration: 0.1,
                           thenDragTo: origin.withOffset(CGVector(dx: reading.container.midX, dy: end)))
            }
            drags += 1
            Thread.sleep(forTimeInterval: 0.6)
            let next = try readScrollContainers(under: bannerFrame)
            let agrees = next.count == readings.count && zip(next, readings).allSatisfy {
                abs($0.lowestEdge - $1.lowestEdge) < 0.5 && $0.lowestElement == $1.lowestElement
            }
            agreeing = agrees ? agreeing + 1 : 0
            readings = next
        }
        keepScreenshot(named: "1565-\(screen)")
        XCTAssertFalse(readings.isEmpty, "\(screen): no list reaches the banner after scrolling", file: file, line: line)
        for reading in readings {
            // The measurement the doc comments cite, printed so a run records it.
            print("[#1565] \(screen): banner top \(bannerFrame.minY), list at y \(Self.span(reading.container)), "
                  + "lowest \(reading.lowestElement) after \(drags) drag(s)")
            XCTAssertLessThanOrEqual(reading.lowestEdge, bannerFrame.minY + 0.5, """
                \(screen): scrolled to its end, the list rests with \(reading.lowestElement) below the banner's \
                top edge at y \(bannerFrame.minY), where it cannot be tapped.
                """, file: file, line: line)
        }
    }

    /// Keeps a screenshot in the result bundle: what the banner sits over is drawing no assertion here reads.
    private func keepScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Launches on `tab` and selects it. The launch argument sets only the tab a new scene starts on, so the
    /// selection is made as well.
    private func launch(on tab: TabDestination) {
        app.launchArguments = UITestLaunch.arguments(startingOn: tab)
        app.launch()
        XCTAssertTrue(navigator.select(tab, resolveTimeout: 15).tapped, "\(tab.label) could not be selected")
    }

    // MARK: - Lists

    /// The Browse root's last rows, My Scopes and Working Corpora, rest above the banner.
    func testBrowseRootRestsAboveTheBanner() throws {
        launch(on: .browse)
        XCTAssertTrue(app.textFields["browse.root.searchField"].waitForExistence(timeout: 10),
                      "the corpus root did not appear")
        try assertListsRestAboveTheBanner("browse-root")
    }

    /// One push deep, Browse ▸ Archives rests with its last provenance-type door above the banner.
    func testPushedListRestsAboveTheBanner() throws {
        launch(on: .browse)
        let tile = app.buttons["browse.root.archivesTile"]
        XCTAssertTrue(tile.waitForExistence(timeout: 10), "the corpus root has no Archives tile")
        if !tile.isHittable { app.swipeUp(velocity: .slow) }
        tile.tap()
        XCTAssertTrue(app.buttons["Provenance Types"].waitForExistence(timeout: 10),
                      "Archives did not open on its lens picker")
        try assertListsRestAboveTheBanner("browse-archives")
    }

    /// The Settings root's last row, under Diagnostics, rests above the banner.
    func testSettingsRootRestsAboveTheBanner() throws {
        launch(on: .settings)
        XCTAssertTrue(app.buttons["Volumes & Storage"].firstMatch.waitForExistence(timeout: 10),
                      "Settings has no Volumes & Storage row")
        try assertListsRestAboveTheBanner("settings-root")
    }

    // MARK: - A pushed screen's own bottom bar

    /// Settings ▸ Volumes & Storage ▸ Download from GitHub draws its Download button above the banner.
    ///
    /// The button is in a bar the screen pins to the bottom of its safe area, so nothing scrolls it. On the unfixed
    /// code it sat wholly under the banner (y 741–775 under a banner from y = 721.7, iPhone 17, iOS 26.5).
    func testPushedScreenBottomBarSitsAboveTheBanner() throws {
        launch(on: .settings)
        let pane = app.buttons["Volumes & Storage"].firstMatch
        XCTAssertTrue(pane.waitForExistence(timeout: 10), "Settings has no Volumes & Storage row")
        pane.tap()
        let door = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Download from GitHub"))
            .firstMatch
        XCTAssertTrue(door.waitForExistence(timeout: 10), "Volumes & Storage has no Download from GitHub row")
        door.tap()
        let download = app.buttons["Download"].firstMatch
        XCTAssertTrue(download.waitForExistence(timeout: 10), "Download from GitHub shows no Download button")
        XCTAssertTrue(banner.waitForExistence(timeout: 15),
                      "The Local Only banner is not up, so this run cannot judge what it covers")
        keepScreenshot(named: "1565-download-bar")
        print("[#1565] download-bar: banner top \(banner.frame.minY), Download at y \(Self.span(download.frame))")
        XCTAssertLessThanOrEqual(download.frame.maxY, banner.frame.minY + 0.5, """
            The Download button (y \(Self.span(download.frame))) sits under the banner, whose top edge is at \
            y \(banner.frame.minY): a reader with a banner showing cannot start a download from this screen.
            """)
    }

    // MARK: - The banner's own place

    /// On each of the five tabs the banner is above the tab bar, and its Details button opens Settings.
    ///
    /// Each tab draws its own banner, in room its own view controller sets aside. Without that room the banner hangs
    /// from the bottom of the safe area: behind the tab bar on an iPhone, below the screen's edge on an iPad.
    func testEveryTabDrawsTheBannerAboveTheTabBar() throws {
        launch(on: .search)
        // The lowest the banner's top edge may be: 40 pt above the tab bar where the bar is at the bottom of the
        // screen (an iPhone), and 40 pt above the screen's own bottom edge where it is not (an iPad).
        let screen = app.windows.firstMatch.frame
        let tabBar = app.tabBars.firstMatch
        let floor = tabBar.exists && tabBar.frame.midY > screen.midY ? tabBar.frame.minY : screen.maxY
        var tops: [String] = []
        for tab in [TabDestination.search, .research, .collections, .settings, .browse] {
            XCTAssertTrue(navigator.select(tab, resolveTimeout: 15).tapped, "\(tab.label) could not be selected")
            XCTAssertTrue(banner.waitForExistence(timeout: 15), "\(tab.label) shows no banner")
            let top = banner.frame.minY
            tops.append("\(tab.label) \(top)")
            XCTAssertLessThanOrEqual(top, floor - 40, """
                On \(tab.label) the banner's top edge is at y \(top), not clear of y \(floor): it is not drawn above \
                the tab bar.
                """)
        }
        print("[#1565] banner top by tab: \(tops.joined(separator: ", ")); floor \(floor)")

        // Details is the banner's one control. The banner is ONE accessibility element (its children are combined),
        // so the button is tapped where it is drawn: at the trailing edge, level with the title.
        let frame = banner.frame
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: frame.maxX - 44, dy: frame.minY + 34))
            .tap()
        XCTAssertTrue(app.buttons["Volumes & Storage"].firstMatch.waitForExistence(timeout: 10), """
            Tapping Details on the Browse tab's banner did not open Settings. Banner \(frame).
            """)
    }

    /// On an iPad the banner keeps its place, and the Settings list still ends above it, when the tabs are shown the
    /// other way: as a sidebar if they were a bar, as a bar if they were a sidebar.
    ///
    /// The room the banner hangs in is set aside on the view controller that hosts the tab's content, and switching
    /// the representation is the one thing a reader can do that rearranges what hosts it. Were the room not there
    /// afterwards, the banner would hang below the screen's bottom edge, where nobody would see it.
    func testBannerKeepsItsPlaceWhenTheTabsBecomeASidebar() throws {
        #if canImport(UIKit)
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad,
                          "iPad-only: an iPhone shows its tabs one way, as a bar")
        #endif
        launch(on: .settings)
        XCTAssertTrue(banner.waitForExistence(timeout: 15),
                      "The Local Only banner is not up, so this run cannot judge where it is drawn")
        let wasExpanded = navigator.sidebarIsExpanded
        let toggle = try XCTUnwrap(navigator.sidebarToggleButton(timeout: 5),
                                   "This iPad shows no control that switches between the tab bar and the sidebar")
        sidebarWasExpanded = wasExpanded
        toggle.tap()
        let deadline = Date().addingTimeInterval(8)
        while navigator.sidebarIsExpanded == wasExpanded, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.3)
        }
        XCTAssertNotEqual(navigator.sidebarIsExpanded, wasExpanded,
                          "The control did not switch the representation, so nothing was measured")
        XCTAssertTrue(banner.waitForExistence(timeout: 10), "The banner is gone after the switch")
        Thread.sleep(forTimeInterval: 0.6)

        let screen = app.windows.firstMatch.frame
        let frame = banner.frame
        print("[#1565] sidebar \(wasExpanded ? "collapsed" : "expanded"): banner at y \(Self.span(frame)), "
              + "x \(frame.minX)–\(frame.maxX); screen bottom \(screen.maxY)")
        XCTAssertLessThanOrEqual(frame.minY, screen.maxY - 40, """
            With the sidebar \(wasExpanded ? "collapsed" : "expanded") the banner's top edge is at y \(frame.minY), \
            not clear of the screen's bottom edge at y \(screen.maxY).
            """)
        try assertListsRestAboveTheBanner("settings-root-other-representation")
    }
}
