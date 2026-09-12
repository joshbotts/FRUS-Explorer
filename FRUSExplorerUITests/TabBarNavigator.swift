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

// MARK: - TabDestination

/// One of `MainTabView`'s five destinations, with every handle a UI test can reach it by.
///
/// Named `TabDestination` rather than `TabSection`: SwiftUI has a `TabSection` of its own, which
/// `SidebarShortcuts.swift` argues about at length, and a same-named test type would read as that.
///
/// Version history:
///   1.0 — 2026-09-12: extracted from six hand-copied ladders (see ``TabBarNavigator``)
enum TabDestination: String, CaseIterable {

    case browse = "Browse"
    case search = "Search"
    case research = "Research"
    case collections = "Collections"
    case settings = "Settings"

    /// The tab's English accessibility label — its `String(localized:defaultValue:)` title in
    /// `MainTabView`. English because the app ships one localization, not because this suite pins
    /// a locale: `CFBundleDevelopmentRegion` is `en` and the built bundle carries no `.lproj`.
    var label: String { rawValue }

    /// The SF Symbol name SwiftUI publishes as the tab item's accessibility identifier.
    ///
    /// Measured in a live iPad element dump for four of the five — `identifier: 'books.vertical',
    /// label: 'Browse'`, and the same shape for Search, Research and Collections. `gear` is read
    /// from `MainTabView`'s own `systemImage:` rather than observed, because Settings was off the
    /// first page in every dump taken. Nothing rests on that inference alone: the identifier is
    /// only ever used in an `AND` with the label, and a bare-label candidate stands behind it.
    var symbol: String {
        switch self {
        case .browse: "books.vertical"
        case .search: "magnifyingglass"
        case .research: "note.text"
        case .collections: "tray.2"
        case .settings: "gear"
        }
    }

    /// `AppTab`'s raw value, for the `-frus.activeTab` launch argument.
    var appTabRawValue: String {
        switch self {
        case .browse: "browse"
        case .search: "search"
        case .research: "research"
        case .collections: "collections"
        case .settings: "settings"
        }
    }

    /// The navigation bar at this tab's root, used as an ARRIVAL oracle.
    ///
    /// Deliberately a `navigationBars` query rather than a label match: three of these bars carry
    /// the tab's own word, so a bare label landmark can be satisfied by the tab ITEM and report a
    /// green arrival at a tab nobody opened.
    var rootNavigationBar: String {
        switch self {
        case .browse: "FRUS Corpus"   // CorpusView.navigationTitle
        case .search: "Search"
        case .research: "Research"
        case .collections: "Collections"
        case .settings: "Settings"
        }
    }
}

// MARK: - TabBarNavigator

/// Selects a `MainTabView` tab in whichever representation iPadOS has chosen — **including the
/// ones that hide part of the bar.**
///
/// ## The defect this exists for
/// Six copies of a five-candidate label ladder were spread across this target, and not one of them
/// could reach a tab the OS had paged off screen. On iPad the `.sidebarAdaptable` floating top bar
/// is capped at roughly 54.5% of the screen's width and **paginates**: measured on iPad mini
/// (A17 Pro, 744 pt portrait) it renders `[ToggleSideBar] Browse | Search | Research ›`, and
/// **no element labelled "Settings" exists anywhere in the accessibility tree**. Page 2 carries
/// Research | Collections | Settings. So every ladder concluded the tab was unreachable, and
/// `UIObstructionTests.testSidebarCarriesResearcherObjectsOniPad` failed in its own setup while
/// two other suites reported a green SKIP having asserted nothing.
///
/// **It is not a narrow-device curiosity.** iPad Pro 13-inch (M5) — the destination `CLAUDE.md`
/// names for `UIObstructionTests` — paginates at `accessibility-extra-large`, putting Settings on
/// page 2 on the documented device (measured by driving the installed build, then restoring
/// `content_size medium`). The tab labels scale with Dynamic Type; the pill's width budget does
/// not. Paging is therefore part of resolving the control, not a device condition to skip on: the
/// reader pages the bar or expands the sidebar, and so does this.
///
/// ## Routes, in order
/// 1. the candidate ladder against the bar's current page, requiring the control to be HITTABLE;
/// 2. **rewind to the first page, then sweep forward** — see ``sweepPages(for:)`` for why the
///    rewind is load-bearing rather than defensive;
/// 3. expand the sidebar, which lists all five rows unpaginated at any width, tap, and restore.
///
/// Paging is tried before the sidebar because it is layout-neutral: the pill floats above the
/// content, while expanding the sidebar takes real layout width — enough, on an iPad Pro in
/// portrait, to cross the 820 pt two-pane gate `BrowserView` and `ResearchView` measure and rebuild
/// everything already pushed. That is #1273's defect, reached by a test helper instead of a
/// rotation.
///
/// Version history:
///   1.0 — 2026-09-12: initial implementation
final class TabBarNavigator {

    /// Read through a closure rather than stored: two suites relaunch `XCUIApplication` mid-test,
    /// and a stored reference would leave the navigator driving a dead process with no symptom
    /// except every query returning nothing.
    private let currentApp: () -> XCUIApplication
    private var app: XCUIApplication { currentApp() }

    /// Creates a navigator over whatever application the closure returns at call time.
    /// - Parameter app: Returns the live `XCUIApplication`.
    init(app: @escaping () -> XCUIApplication) { self.currentApp = app }

    /// What had to happen before the control was tappable.
    enum Reveal: Equatable {
        /// The tab was already on the bar's current page (or this is iPhone).
        case none
        /// The floating bar was paged, `back` turns backward and `forward` turns forward.
        case paged(back: Int, forward: Int)
        /// The sidebar was expanded, the row tapped, and the representation restored.
        case sidebar
    }

    /// The outcome of one selection.
    ///
    /// Returned rather than discarded because the two reveal routes are each other's fallback: a
    /// pin asserting only "the tab opened" stays green when either route is broken, so neither
    /// route could then be mutated to red.
    struct Outcome: Equatable {
        /// Whether a control was tapped at all.
        let tapped: Bool
        /// What had to happen first.
        let reveal: Reveal
        /// A control that existed but never became hittable was tapped as a last resort.
        let tappedAnUnhittableControl: Bool
    }

    /// Which routes a caller will allow.
    ///
    /// Narrowed ONLY by tests written to prove one route: on every device measured the pager wins
    /// first, so a sidebar pin left on the default path would never execute the code it names.
    struct Routes: OptionSet {
        let rawValue: Int
        /// The candidate ladder against the current page.
        static let directly = Routes(rawValue: 1 << 0)
        /// Paging the floating bar.
        static let paging = Routes(rawValue: 1 << 1)
        /// Expanding the sidebar.
        static let sidebar = Routes(rawValue: 1 << 2)
        /// Every route, the default.
        static let all: Routes = [.directly, .paging, .sidebar]
    }

    /// Five tabs, so at most five pages and four steps either way; the extra step covers a bar that
    /// starts mid-sweep. The sweep normally stops earlier — on a repeated page signature, which
    /// also terminates a bar that WRAPS rather than ending, since a wrapping bar never withdraws
    /// its forward chevron.
    private static let maxPagerSteps = TabDestination.allCases.count + 1

    // MARK: - Selection

    /// Selects `destination`, revealing it first if the bar has paged it off screen.
    ///
    /// - Parameters:
    ///   - destination: The tab to open.
    ///   - routes: Which reveal routes to allow. Narrow this only in a test that exists to prove
    ///     one route.
    ///   - file: Forwarded so a failure reports the caller's line.
    ///   - line: Forwarded so a failure reports the caller's line.
    /// - Returns: What was tapped and what had to happen first.
    @discardableResult
    func select(_ destination: TabDestination,
                using routes: Routes = .all,
                file: StaticString = #filePath,
                line: UInt = #line) -> Outcome {
        if routes.contains(.directly),
           let control = resolve(destination, requireHittable: true, timeout: 5),
           tapAndConfirm(control, destination) {
            return Outcome(tapped: true, reveal: .none, tappedAnUnhittableControl: false)
        }
        if routes.contains(.paging), let swept = sweepPages(for: destination),
           tapAndConfirm(swept.control, destination) {
            return Outcome(tapped: true,
                           reveal: .paged(back: swept.back, forward: swept.forward),
                           tappedAnUnhittableControl: false)
        }
        if routes.contains(.sidebar), selectViaSidebar(destination) {
            return Outcome(tapped: true, reveal: .sidebar, tappedAnUnhittableControl: false)
        }
        // Last resort: route 1 WITHOUT the hittability requirement — exactly what the six old
        // ladders did. Kept so a representation where `isHittable` under-reports degrades to the
        // previous behaviour rather than to a new failure, and announced, because the one measured
        // exists-but-unhittable case is the Collections tab clipped by the pill's right edge, whose
        // centre lies over the navigation bar's "Switch project context" button.
        if routes.contains(.directly),
           let stale = resolve(destination, requireHittable: false, timeout: 1) {
            print("[TabBarNavigator] WARNING: tapping a '\(destination.label)' control that exists "
                  + "but is not hittable (frame \(stale.frame)). The tap may land on an unrelated "
                  + "control; if what follows fails, look here first.")
            stale.tap()
            return Outcome(tapped: arrived(at: destination, timeout: 3),
                           reveal: .none, tappedAnUnhittableControl: true)
        }
        print("[TabBarNavigator] '\(destination.label)' not found in any representation; tree:\n"
              + app.debugDescription)
        XCTFail("Could not reach the '\(destination.label)' tab. Tried the current page, every page "
                + "of the floating tab bar in both directions, and the expanded sidebar (element "
                + "tree printed to the test log).", file: file, line: line)
        return Outcome(tapped: false, reveal: .none, tappedAnUnhittableControl: false)
    }

    // MARK: - Tapping

    /// Taps, then CONFIRMS the tab actually changed — and if it did not, cleans up and reports
    /// failure so the caller falls through to the next route.
    ///
    /// **A control the tree reports as hittable can still be clipped, and MEASURED here it is.**
    /// On page 1 of a 744 pt iPad the Collections tab item exists with a frame running roughly
    /// 85 pt past the floating pill's visible right edge; `isHittable` returns true, and the
    /// synthesized tap at its centre lands on the navigation bar's "Switch project context" button
    /// behind it — opening a menu, not the tab. Believing that tap is how
    /// `testEveryTabIsReachableInThisRepresentation` first failed, on Collections, with the arrival
    /// oracle doing exactly the job it was added for.
    ///
    /// So arrival is the contract, not the tap. A tap that does not take is undone (the menu it may
    /// have opened is dismissed) and the next route runs — which pages the bar and brings the same
    /// tab fully on screen.
    private func tapAndConfirm(_ control: XCUIElement, _ destination: TabDestination) -> Bool {
        control.tap()
        if arrived(at: destination, timeout: 3) { return true }
        dismissAnyTransientPresentation()
        return false
    }

    /// Whether the tab item reports itself selected, polled.
    private func arrived(at destination: TabDestination, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if isSelected(destination) { return true }
            Thread.sleep(forTimeInterval: 0.25)
        } while Date() < deadline
        return false
    }

    /// Closes a menu or popover a mis-landed tap may have opened, so the next route is not blocked.
    ///
    /// The dismiss region first — UIKit publishes one for a popover — then a tap in the status-bar
    /// corner, which is outside both the pill and any content row, so it cannot navigate anywhere.
    private func dismissAnyTransientPresentation() {
        let region = app.otherElements["PopoverDismissRegion"]
        if region.exists {
            region.tap()
        } else if app.popovers.firstMatch.exists || app.sheets.firstMatch.exists {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.02)).tap()
        }
        Thread.sleep(forTimeInterval: 0.4)
    }

    // MARK: - Route 1 · the ladder

    /// The first candidate that exists — and, when asked, is hittable.
    ///
    /// ONE deadline for the whole ladder, not a `waitForExistence` per candidate. The old shape
    /// spent three seconds on each of five candidates before reporting a miss, so a page sweep
    /// built on it would have cost a minute per turn; it also made candidate 1 authoritative for
    /// three seconds when candidate 3 already matched.
    ///
    /// The whole-tree scan runs ONCE, after the poll: `descendants(matching: .any)` snapshots the
    /// entire tree, and re-running it every quarter second would spend the budget on the one
    /// candidate that has never resolved anything.
    private func resolve(_ destination: TabDestination,
                         requireHittable: Bool,
                         timeout: TimeInterval) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let hit = firstAcceptable(fastCandidates(for: destination), requireHittable) {
                return hit
            }
            if timeout <= 0 { break }
            Thread.sleep(forTimeInterval: 0.25)
        } while Date() < deadline
        return firstAcceptable([wholeTreeCandidate(for: destination)], requireHittable)
    }

    private func firstAcceptable(_ candidates: [XCUIElement],
                                 _ requireHittable: Bool) -> XCUIElement? {
        for candidate in candidates where candidate.exists {
            if !requireHittable || candidate.isHittable { return candidate }
        }
        return nil
    }

    /// The historical ladder with ONE insertion: a strict identifier-and-label pair at position 2.
    ///
    /// **`AND`, never `OR`.** The dump shows tab items carry both handles, so the pair is strictly
    /// narrower than either alone; an identifier-only arm would match any button carrying the
    /// symbol, and `magnifyingglass`, `note.text` and `books.vertical` each occur dozens of times
    /// in the app — several of them inside the very tab being selected.
    ///
    /// Every candidate is `.firstMatch`: some representations expose more than one element with the
    /// label, and tapping an ambiguous element fails with "multiple matching elements found".
    /// Predicates are built at their point of use — `NSPredicate` is not `Sendable` and the iOS 26
    /// SDK isolates the XCUI APIs to the main actor, so one value handed to two `matching(_:)`
    /// calls is a second send.
    private func fastCandidates(for destination: TabDestination) -> [XCUIElement] {
        [
            // iPhone's bottom bar. Cannot match on iPad, where the floating pill's container is a
            // plain `Other` element and no `tabBar` exists at all.
            app.tabBars.firstMatch.buttons[destination.label].firstMatch,
            tabItem(for: destination),
            app.buttons[destination.label].firstMatch,
            // The sidebar exposes tabs as ROWS, where a `buttons` query finds nothing.
            app.cells[destination.label].firstMatch,
            app.cells.containing(
                NSPredicate(format: "label CONTAINS[c] %@", destination.label)).firstMatch,
        ]
    }

    private func wholeTreeCandidate(for destination: TabDestination) -> XCUIElement {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", destination.label)).firstMatch
    }

    /// A tab item, matched on BOTH handles.
    private func tabItem(for destination: TabDestination) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier == %@ AND label == %@",
                                         destination.symbol, destination.label)).firstMatch
    }

    /// Whether this destination has a tab control on the bar's current page.
    ///
    /// Strict pair OR bare label, so an unverified `gear` inference degrades to the old behaviour
    /// rather than under-counting the page.
    private func isOnCurrentPage(_ destination: TabDestination) -> Bool {
        tabItem(for: destination).exists || app.buttons[destination.label].firstMatch.exists
    }

    // MARK: - Route 2 · paging

    /// UIKit's forward pagination control.
    ///
    /// **Exact and case-SENSITIVE, and it must stay that way.** The app ships its own results pager
    /// labelled "Previous page" / "Next page" (`SearchView`, `SearchSheet`, `FacetPanelView`),
    /// differing from UIKit's only in one capital letter — so the defensive-looking `CONTAINS[c]`
    /// spelling that is right for the sidebar toggle would page a search result list here, and a
    /// Search selection is made from exactly that screen. These strings come from UIKit's own
    /// accessibility bundle and carry NO identifier to lead with, which is why route 3 stands
    /// behind this one.
    private var nextPageButton: XCUIElement { app.buttons["Next Page"].firstMatch }

    /// UIKit's backward pagination control. See ``nextPageButton`` for the case-sensitivity rule.
    private var previousPageButton: XCUIElement { app.buttons["Previous Page"].firstMatch }

    /// Which destinations the bar's current page exposes — the progress and wrap detector.
    private var pageSignature: String {
        TabDestination.allCases.filter(isOnCurrentPage).map(\.rawValue).joined(separator: ",")
    }

    /// Rewinds to the first page, then steps forward over every page, re-probing after each.
    ///
    /// **THE REWIND IS NOT OPTIONAL AND IS NOT DEFENSIVE.** The bar pages itself to show the
    /// SELECTED tab, and the app persists that tab across launches: `MainTabView` calls
    /// `AppState.persistTabSeed` on every selection change, which writes `frus.activeTab` to
    /// `UserDefaults`, and a fresh scene is seeded from it. So the first run in which this helper
    /// successfully reaches Settings makes every LATER launch on that simulator open on Settings —
    /// the bar's last page, where Browse is absent and there is no forward chevron to turn. A
    /// forward-only sweep reports the tab unreachable on its own second run. Suites pin
    /// `-frus.activeTab browse` at launch so the seed cannot decide this; the rewind is the backstop
    /// for the launch paths that do not, and for state restoration, which the argument domain does
    /// not reach.
    ///
    /// - Parameter destination: The tab to find.
    /// - Returns: The control and how far the bar was turned, or `nil` if no page holds it.
    private func sweepPages(for destination: TabDestination)
        -> (control: XCUIElement, back: Int, forward: Int)? {
        guard isPad else { return nil }          // iPhone's bottom bar never paginates
        guard nextPageButton.exists || previousPageButton.exists else { return nil }

        var back = 0
        while previousPageButton.exists, back < Self.maxPagerSteps {
            let before = pageSignature
            previousPageButton.tap()
            back += 1
            if pageSignature == before { break }  // a control that does not move the bar
        }

        var seen = Set<String>()
        var forward = 0
        while true {
            if let control = resolve(destination, requireHittable: true, timeout: 1) {
                return (control, back, forward)
            }
            let signature = pageSignature
            guard !seen.contains(signature) else { return nil }   // also the wrap guard
            seen.insert(signature)
            guard forward < Self.maxPagerSteps, nextPageButton.exists else { return nil }
            nextPageButton.tap()
            forward += 1
        }
    }

    // MARK: - Route 3 · the sidebar

    /// Expands the sidebar, taps the row, and puts the representation back.
    private func selectViaSidebar(_ destination: TabDestination) -> Bool {
        guard isPad else { return false }
        // Already expanded: route 1 has already run the ladder against the sidebar's own rows, so
        // toggling here would COLLAPSE it and search the representation that just failed.
        guard !sidebarIsExpanded else { return false }
        guard let toggle = sidebarToggleButton(timeout: 3) else { return false }

        print("[TabBarNavigator] paging did not reveal '\(destination.label)'; expanding the "
              + "sidebar. It takes real layout width, so on an iPad whose content then falls under "
              + "the 820pt two-pane gate this rebuilds anything already pushed — if a caller loses "
              + "navigation state after this line, that is the cause.")
        toggle.tap()

        var selected = false
        if let control = resolve(destination, requireHittable: true, timeout: 5) {
            selected = tapAndConfirm(control, destination)
        }

        // READ THE REPRESENTATION BACK; assume neither outcome. A row tap was measured to dismiss
        // the sidebar on both devices anyone has run this on — the 744 pt overlay and the 13-inch
        // column — but assuming that and being wrong leaves it open, while assuming the opposite
        // toggles it twice. Polled, because a dismissing overlay's rows still exist mid-animation.
        let settle = Date().addingTimeInterval(1.5)
        while sidebarIsExpanded, Date() < settle { Thread.sleep(forTimeInterval: 0.25) }
        for _ in 0..<3 where sidebarIsExpanded {
            guard let toggle = sidebarToggleButton(timeout: 1) else { break }
            toggle.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }
        // No flag is published and none is needed: a suite restores the representation to the
        // baseline it captured in `setUp`, which is correct whoever displaced it and survives an
        // `XCTFail` unwind that no flag set around a tap can.
        return selected
    }

    // MARK: - Representation

    /// Whether the `.sidebarAdaptable` TabView is showing its SIDEBAR.
    ///
    /// **A COUNT, not one label.** In the sidebar the tabs are cells, and the floating pill contains
    /// no cells at all. Requiring three of the five at once means a content list that happens to
    /// hold a cell labelled "Browse" cannot produce a false positive — and a false positive here is
    /// the dangerous direction: the sidebar route would read "still expanded" after a successful
    /// selection and tap the toggle again, EXPANDING the sidebar and causing the very leak it
    /// exists to prevent.
    var sidebarIsExpanded: Bool {
        TabDestination.allCases.filter { app.cells[$0.label].firstMatch.exists }.count >= 3
    }

    /// Whether the floating bar is showing fewer than all five tabs.
    ///
    /// Gated on the representation: the sidebar's rows are not buttons, so without the gate an
    /// expanded sidebar reports itself paginated and a pagination pin would run against the wrong
    /// representation — silently, since the representation is system-persisted per install.
    var tabBarIsPaginated: Bool {
        guard isPad, !sidebarIsExpanded else { return false }
        return TabDestination.allCases.filter(isOnCurrentPage).count < TabDestination.allCases.count
    }

    /// Whether the tab item reports itself selected.
    func isSelected(_ destination: TabDestination) -> Bool {
        tabItem(for: destination).exists
            ? tabItem(for: destination).isSelected
            : app.buttons[destination.label].firstMatch.isSelected
    }

    /// The OS control that switches the `.sidebarAdaptable` TabView between representations.
    ///
    /// Identifier first (`ToggleSideBar` is Apple's own — the string appears nowhere in the app),
    /// fuzzy label as the fallback. **Polls** (#311): returning an element that does not yet exist
    /// made a caller's own `waitForExistence` dead code and turned two iPad scenarios green having
    /// asserted nothing.
    func sidebarToggleButton(timeout: TimeInterval = 5) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            let byIdentifier = app.buttons["ToggleSideBar"]
            if byIdentifier.exists { return byIdentifier }
            // Built fresh each iteration, deliberately: see `fastCandidates` on `NSPredicate`
            // sendability under Swift 6.
            let matches = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] 'sidebar' OR label CONTAINS[c] 'tab bar'"))
            if matches.count > 0 { return matches.firstMatch }
            if timeout <= 0 { break }
            Thread.sleep(forTimeInterval: 0.25)
        } while Date() < deadline
        return nil
    }

    private var isPad: Bool {
        #if canImport(UIKit)
        UIDevice.current.userInterfaceIdiom == .pad
        #else
        false
        #endif
    }
}

// MARK: - UITestLaunch

/// The launch arguments every UI-test suite passes.
///
/// **`-frus.activeTab browse` is not cosmetic.** `NSArgumentDomain` outranks the persistent domain,
/// so this pins what `AppState.seedActiveTab` reads and makes the launch tab deterministic
/// regardless of what an earlier test wrote. Without it a suite's launch tab is whatever the last
/// test on that simulator selected — already true today, and harmless only because Browse, Search
/// and Research all sit on page 1 of even a narrow floating bar. It stops being harmless the moment
/// a test can reach Settings, because the bar then opens on its LAST page and Browse is behind it.
///
/// Version history:
///   1.0 — 2026-09-12: initial implementation
enum UITestLaunch {

    /// - Parameters:
    ///   - tab: The tab the app should open on.
    ///   - contentSizeCategory: A `UICTContentSizeCategory…` name to force, or `nil` for the
    ///     device's own setting.
    /// - Returns: The launch arguments.
    static func arguments(startingOn tab: TabDestination = .browse,
                          contentSizeCategory: String? = nil) -> [String] {
        var arguments = ["-hasCompletedOnboarding", "1",
                         "-frus.activeTab", tab.appTabRawValue]
        if let contentSizeCategory {
            arguments += ["-UIPreferredContentSizeCategoryName", contentSizeCategory]
        }
        return arguments
    }
}
