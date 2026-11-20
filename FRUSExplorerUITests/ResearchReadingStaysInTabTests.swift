// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import XCTest
import notify

/// The owner's report, driven end to end: a document opened from a Research-tab list, then Back,
/// returns to that list — in the Research tab, not the Browse tab (2026-09-11).
///
/// Before the change the document opened in Browse, and Back unwound Browse's own history, landing on
/// the corpus root. Unit tests pin the wiring; only a UI test can see which tab Back lands in, and
/// whether a reading position survives the iPad layout changing underneath it.
///
/// ## Oracles, and why these
/// - `navigationBars["All Research Documents"]` exists only while the STACK layout shows that list on
///   top. It is the sound oracle `UIObstructionTests` settled on; `staticTexts` of the same string is
///   vacuous, since the category row renders it too. The iPad two-pane never shows it, which is what
///   tells the two layouts apart.
/// - "Reading" is Back present, that list bar absent, and the category row not hittable. Each half of
///   that fails in a state the other allows: the stack's list has Back but shows the bar; the two-pane's
///   list shows the category row; the stack's root has no Back. Only a pushed document satisfies all three.
/// - `navigationBars["FRUS Corpus"]` is the Browse root. It must never appear: if it does, the document
///   opened in Browse and Back unwound Browse — the bug.
/// - Nothing queries the document's content. Queries over the WKWebView reader time out on iPhone.
///
/// Version history:
///   1.0 — 2026-09-11: initial implementation (iPhone)
///   1.1 — 2026-09-11: iPad — reading in whichever layout the width gives, and the document opened from
///          the list surviving the window crossing the 820 pt two-pane width in both directions. That is
///          a guard, NOT the evidence for the reading chain: measured by A/B on one iPad mini, it passes on
///          the pre-chain reader too, whose first document already lived above the layout branch. What
///          the chain fixed — a page-turned or cross-referenced position — had no runtime test; the
///          UI-test store held no document to page through.
///   1.2 — #1273: `ResearchReadingDepthTests`, in this file, turns a page and requires it to survive
///          the crossing — the test 1.1 said was missing.
@MainActor
final class ResearchReadingStaysInTabTests: XCTestCase {
    /// Resolves tab destinations across every representation, including the floating iPad bar when
    /// it has paged a tab off screen.
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }


    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        // The seeded note gives the Research list one row to open (UITestResearchSeeder).
        app.launchEnvironment["FRUS_UI_TEST_SEED_NOTE"] = "1"
        app.launchArguments = UITestLaunch.arguments()
        app.launch()
    }

    override func tearDown() async throws {
        XCUIDevice.shared.orientation = .portrait
        app = nil
    }

    // MARK: - iPhone

    func testBackFromAResearchDocumentReturnsToTheResearchList() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom == .pad,
                      "iPhone only — the iPad tests below cover both iPad layouts")

        // Through the navigator, not `app.tabBars…` — that query can never match on iPad, where
        // the floating bar's container is a plain `Other` element, and this test's own skip is the
        // only thing that kept it off one.
        XCTAssertTrue(navigator.select(.research).tapped, "no Research tab")

        // Drill into the list BEFORE any swipe — a preceding swipe stops the tap driving the push
        // (UIObstructionTests' measured ordering quirk).
        let allDocuments = app.cells.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "All Research Documents")).firstMatch
        XCTAssertTrue(allDocuments.waitForExistence(timeout: 10), "no All Research Documents row")
        allDocuments.tap()
        let listBar = app.navigationBars["All Research Documents"]
        XCTAssertTrue(listBar.waitForExistence(timeout: 10), "the Research list did not open")

        let seeded = app.staticTexts["UI Test Research Note"].firstMatch
        XCTAssertTrue(seeded.waitForExistence(timeout: 10),
                      "the seeded note is not in the list — the seeder did not run or the list did not load")
        seeded.tap()

        // The document is on top: the list's bar is gone and something is pushed.
        let back = app.buttons["BackButton"]
        XCTAssertTrue(back.waitForExistence(timeout: 10), "opening the document pushed nothing")
        XCTAssertFalse(listBar.waitForExistence(timeout: 2), "the document did not cover the list")
        XCTAssertFalse(app.navigationBars["FRUS Corpus"].exists,
                       "the document opened in the Browse tab — the reader left Research")

        back.tap()

        // Back lands on the list the document came from, still in Research.
        XCTAssertTrue(listBar.waitForExistence(timeout: 10), """
            Back did not return to the Research list. Before 2026-09-11 the document opened in Browse \
            and Back unwound Browse's history instead.
            """)
        XCTAssertFalse(app.navigationBars["FRUS Corpus"].exists,
                       "Back landed in the Browse tab")
        XCTAssertTrue(navigator.isSelected(.research),
                      "the Research tab is no longer selected")
    }

    // MARK: - iPad

    /// On iPad the document reads in Research in whichever layout this width gives — in the two-pane,
    /// over the whole two-pane rather than inside its detail pane — and Back returns to the list.
    func testBackFromAResearchDocumentReturnsToTheResearchListOniPad() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad only")
        let seeded = try openResearchList()

        seeded.tap()
        XCTAssertTrue(waitUntil { isReading }, "opening the document did not cover the Research list")
        XCTAssertFalse(app.navigationBars["FRUS Corpus"].exists,
                       "the document opened in the Browse tab — the reader left Research")

        backButton.tap()
        XCTAssertTrue(waitUntil { seeded.isHittable }, "Back did not return to the Research list")
        XCTAssertFalse(app.navigationBars["FRUS Corpus"].exists, "Back landed in the Browse tab")
    }

    /// The document opened from the list survives the window crossing the two-pane width, in both
    /// directions, and Back still returns to the list it came from.
    ///
    /// Crossing the gate swaps Research's stack for its two-pane (or back), which rebuilds every view
    /// pushed on it. Driven by rotation on an iPad whose portrait is narrower than the gate and whose
    /// landscape is wider — iPad mini — and it CHECKS the gate was crossed instead of assuming it: a
    /// rotation that changes no layout would pass every other assertion here while testing nothing.
    ///
    /// **Scope, measured:** this passes on the pre-chain reader as well (same iPad mini, iOS 26.3), so it
    /// guards the first document and the list beneath it — not the position the host-owned chain exists
    /// to keep. `ResearchReadingDepthTests` below covers the PAGE-TURNED half of that (#1273). A followed
    /// cross-reference is still not exercised at RUNTIME: the fixture carries no reference, and a link
    /// lives inside the WKWebView these suites do not query. Its code shape is pinned, though:
    /// `HandoffVisibilityTests.inPlaceReaderUsesTheChain` reads the reader's own body for the single
    /// `InPlaceReading.apply` call both jump kinds go through, and for the destination that presents the
    /// level a cross-reference pushes.
    func testReadingSurvivesTheWindowCrossingTheTwoPaneWidth() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad only")
        let seeded = try openResearchList()
        try XCTSkipUnless(listBar.waitForExistence(timeout: 3), """
            This iPad already shows Research's two-pane in portrait, so rotating cannot cross the \
            820 pt gate. Run on iPad mini, whose portrait is 744 pt.
            """)

        // Stack → two-pane, while reading.
        seeded.tap()
        XCTAssertTrue(waitUntil { isReading }, "opening the document did not cover the Research list")
        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 1.5)
        XCTAssertTrue(waitUntil(5) { isReading }, """
            Rotating across the two-pane width dropped the document. The reading position must live \
            above the layout swap, or the views the swap rebuilds take it with them.
            """)
        backButton.tap()
        XCTAssertTrue(waitUntil { seeded.isHittable }, "Back after rotating did not return to the Research list")
        XCTAssertFalse(listBar.exists, """
            Landscape still shows the stack layout, so this run never crossed the two-pane gate and the \
            assertions above tested nothing. The tab sidebar may be taking the width.
            """)

        // Two-pane → stack, while reading.
        seeded.tap()
        XCTAssertTrue(waitUntil { isReading }, "opening the document in the two-pane did not cover it")
        XCUIDevice.shared.orientation = .portrait
        Thread.sleep(forTimeInterval: 1.5)
        XCTAssertTrue(waitUntil(5) { isReading }, "rotating back to portrait dropped the document")
        backButton.tap()
        XCTAssertTrue(waitUntil { seeded.isHittable }, """
            Back after rotating to portrait did not return to the Research list — the rebuilt stack \
            lost the category the document was opened from.
            """)
        XCTAssertFalse(app.navigationBars["FRUS Corpus"].exists, "the reader left Research")
    }

    // MARK: - Helpers

    /// The Research category row that opens every annotated document.
    private var categoryRow: XCUIElement {
        app.cells.containing(NSPredicate(format: "label BEGINSWITH 'All Research Documents'")).firstMatch
    }

    /// The stack layout's list bar; the two-pane never shows it.
    private var listBar: XCUIElement { app.navigationBars["All Research Documents"] }

    /// The navigation bar's Back button.
    private var backButton: XCUIElement { app.buttons["BackButton"].firstMatch }

    /// Whether a document is on top of Research, in either layout — see the suite's note on oracles.
    private var isReading: Bool {
        backButton.exists && !listBar.exists && !categoryRow.isHittable
    }

    /// Selects Research in whichever tab-bar representation is up, and opens All Research Documents.
    ///
    /// - Returns: The seeded note's row.
    private func openResearchList() throws -> XCUIElement {
        guard navigator.select(.research).tapped else { throw XCTestError(.failureWhileWaiting) }
        // Before any swipe — a preceding swipe stops the tap driving the push.
        XCTAssertTrue(categoryRow.waitForExistence(timeout: 10), "no All Research Documents row")
        categoryRow.tap()
        let seeded = app.staticTexts["UI Test Research Note"].firstMatch
        XCTAssertTrue(seeded.waitForExistence(timeout: 10),
                      "the seeded note is not in the list — the seeder did not run or the list did not load")
        return seeded
    }

    /// Polls `condition` until it holds or `timeout` passes.
    private func waitUntil(_ timeout: TimeInterval = 10, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return condition()
    }
}

// MARK: - ResearchReadingDepthTests

/// A page turned inside Research survives the iPad window crossing the two-pane width (#1273).
///
/// ## Why this exists beside the rotation test above
/// Research's reading chain lives on `ResearchView`, above the branch that swaps its stack for its
/// two-pane at 820 pt, because that swap rebuilds every view pushed on either (#1272). The rotation
/// test above opens only the FIRST document, and an A/B showed it passing on a reader that kept its
/// position in its own state: the first document had lived above the branch all along. What the chain
/// exists to keep is a position the reader REACHED — here, a page turned. So this turns one, crosses the
/// gate both ways, and requires the turned-to page each time.
///
/// ## Fixture
/// `FRUS_UI_TEST_SEED_VOLUME` writes a volume whose first three documents are `d1…d3`, "UI Test Document
/// One/Two/Three" (#1301 appended a nested branch after them — `n1`, `n2` and then, in round 2, `t1` —
/// so the fixture now reads `d1, d2, d3, n1, n2, t1` and the `d1 → d2` adjacency this suite turns a page
/// across is untouched),
/// and `FRUS_UI_TEST_SEED_NOTE_DOCUMENT=d1` puts the seeded Research note on its first document, so the
/// row opens a real document with a next page. `UITestFixtureVolumeTests` pins that the fixture reads in
/// that order.
///
/// The page-turn zones need three things (`DocumentView.documentEdgeNavigationOverlay`): the research
/// rail closed, the edge-tap preference on, and a neighbour loaded from the index. The first two are
/// pinned as launch arguments rather than trusted: both are persisted user preferences, so a simulator
/// where either was changed would hide the zones and fail this test for a reason it is not about. The
/// argument domain is searched before the application domain, so those two pins hold for the whole launch
/// whatever the app writes. The reading MODE is pinned for the opposite reason — so this suite writes
/// nothing: under Read or Research, `DocumentView` stores `panelVisible` into the PERSISTENT domain on
/// every open (DocumentView.swift:514-520), which would outlive the run and reach other suites;
/// `rememberLast` writes nothing on iPad.
///
/// ## Oracles — native chrome only; nothing queries the WKWebView's content
/// - The navigation bar's identifier is the document's title, so `navigationBars["UI Test Document Two"]`
///   says which page is showing. `buttons["Previous document"]` exists only off the first page: a second,
///   title-independent witness.
/// - The Back button's label says which layout the reader is in: "All Research Documents" in the stack
///   (Back returns to the pushed category), "Research" over the two-pane (Back returns to the root). That
///   is how the test proves the gate was crossed BEFORE it asserts what survived the crossing — a rotation
///   that changed no layout would otherwise pass while testing nothing.
/// - The page-turn is the edge zone's own accessibility element, `buttons["Next document"]`.
///
/// All three were measured by a probe on iPad mini (A17 Pro), iOS 26.5, before this was written.
///
/// ## One side effect, and the half of it that is not established
/// This is the first UI suite to tap a page-turn zone, and `DocumentView` invalidates
/// `EdgeTapNavigationTip` with `.actionPerformed` inside that gesture, unconditionally. Whether that write
/// still reaches TipKit's datastore while `Tips.hideAllTipsForTesting()` is in force is NOT established
/// anywhere in this repo, so treat it as a possibility rather than a fact: if the owner's manual seam
/// (`FRUS_UI_TEST_SHOW_TIPS=1`) ever fails to show that one tip, a simulator this suite has run on is the
/// first thing to check, and Settings ▸ show tips again re-arms it.
///
/// Version history:
///   1.0 — #1273: initial implementation
@MainActor
final class ResearchReadingDepthTests: XCTestCase {
    /// Resolves tab destinations across every representation, including the floating iPad bar when
    /// it has paged a tab off screen.
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }


    private var app: XCUIApplication!

    /// Carried by every assertion about the surviving page, so an A/B can confirm a failure happened
    /// there and not at a precondition.
    private static let lostPage = "PAGE-TURN LOST ACROSS THE TWO-PANE SWAP"

    override func setUp() async throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_VOLUME"] = "frus1961-63v06"
        app.launchEnvironment["FRUS_UI_TEST_SEED_NOTE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_NOTE_DOCUMENT"] = "d1"
        app.launchArguments = UITestLaunch.arguments() + [
                               "-frus.document.researchPanel.visible", "NO",
                               "-frus.reading.edgeTapNavigation", "YES",
                               "-frus.reading.defaultMode", "rememberLast"]
        app.launch()
    }

    override func tearDown() async throws {
        XCUIDevice.shared.orientation = .portrait
        app = nil
    }

    func testATurnedPageSurvivesTheWindowCrossingTheTwoPaneWidth() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad only")
        let seeded = try openResearchList()
        try XCTSkipUnless(listBar.waitForExistence(timeout: 3), """
            This iPad already shows Research's two-pane in portrait, so rotating cannot cross the \
            820 pt gate. Run on iPad mini, whose portrait is 744 pt.
            """)

        // Stack → two-pane.
        try openTheFirstDocumentAndTurnThePage(from: seeded)
        XCTAssertEqual(backButton.label, "All Research Documents", "the page-turn left the stack layout")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(waitUntil { backButton.exists && backButton.label == "Research" }, """
            Landscape did not put the reader over Research's two-pane, so the gate was never crossed and \
            the assertions after this would test nothing. The tab sidebar may be taking the width.
            """)
        assertStillOnPageTwo(after: "rotating from the stack to the two-pane")
        backButton.tap()
        XCTAssertTrue(waitUntil { seeded.isHittable }, "one Back from the turned page did not return to the list")
        XCTAssertFalse(app.navigationBars["FRUS Corpus"].exists, "the reader left Research")

        // Two-pane → stack.
        try openTheFirstDocumentAndTurnThePage(from: seeded)
        XCTAssertEqual(backButton.label, "Research", "the page-turn left the two-pane")
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(waitUntil { backButton.exists && backButton.label == "All Research Documents" }, """
            Portrait did not put the reader back in Research's stack, so the gate was never crossed and \
            the assertions after this would test nothing.
            """)
        assertStillOnPageTwo(after: "rotating from the two-pane to the stack")
        backButton.tap()
        XCTAssertTrue(waitUntil { listBar.exists && seeded.isHittable },
                      "one Back from the turned page did not return to the list")
    }

    // MARK: - Steps

    /// Opens the seeded note's document — the fixture's first — and turns to its second page.
    private func openTheFirstDocumentAndTurnThePage(from seeded: XCUIElement) throws {
        seeded.tap()
        XCTAssertTrue(app.navigationBars["UI Test Document One"].waitForExistence(timeout: 15),
                      "the seeded row did not open the fixture's first document")

        // The zone appears once the index gives d1 a neighbour. A launch that indexes the fixture in
        // the background can open d1 before that, and the reader asks for its neighbours once per
        // open — so reopen rather than wait for something that will not change.
        var hasNext = nextDocument.waitForExistence(timeout: 10)
        var reopened = 0
        while !hasNext && reopened < 2 {
            reopened += 1
            backButton.tap()
            _ = seeded.waitForExistence(timeout: 10)
            Thread.sleep(forTimeInterval: 3)
            seeded.tap()
            hasNext = nextDocument.waitForExistence(timeout: 10)
        }
        guard hasNext else {
            XCTFail("""
                No "Next document" zone on the fixture's first document after two reopens. Either the \
                fixture never indexed — an interrupted index keeps a volume out of every later launch's \
                reconcile (`frus.indexingInProgress`); Browse ▸ the volume ▸ Index Now clears it — or the \
                research rail is open, which hides the zones.
                """)
            throw XCTestError(.failureWhileWaiting)
        }
        XCTAssertFalse(previousDocument.exists, "the fixture's first document should have no previous page")

        nextDocument.tap()
        XCTAssertTrue(app.navigationBars["UI Test Document Two"].waitForExistence(timeout: 15),
                      "the page-turn did not reach the fixture's second document")
        XCTAssertTrue(previousDocument.waitForExistence(timeout: 5), "page two should offer a previous page")
    }

    /// The discriminating assertion: after the layout swap the reader still shows the page it turned to.
    ///
    /// Checked twice, a moment apart, and with page one required ABSENT: the swap replaces the whole
    /// stack, and a single early query could still find the outgoing bar. Page one is a sound negative
    /// here because no reference was followed — Back names the list, never the previous page.
    ///
    /// The two oracles are NOT ready at the same moment, which is why only one of them is polled. The
    /// title comes from the chain entry before the document parses (`DocumentView.displayTitle`), while
    /// the Previous zone waits on the rebuilt reader's whole async load — `vm.load` and then
    /// `loadAdjacentEntries`. Asserting the zone's bare `exists` made a slow rebuild report the very
    /// failure this message names, which an A/B could not tell from the defect.
    private func assertStillOnPageTwo(after crossing: String) {
        let pageTwo = app.navigationBars["UI Test Document Two"]
        XCTAssertTrue(pageTwo.waitForExistence(timeout: 10), """
            \(Self.lostPage): after \(crossing), the reader no longer shows the page it turned to. A \
            position kept in the reader's own state is rebuilt away with the layout; it must live in the \
            host's reading chain (#1272, #1273).
            """)
        Thread.sleep(forTimeInterval: 1.5)
        XCTAssertTrue(pageTwo.exists && !app.navigationBars["UI Test Document One"].exists,
                      "\(Self.lostPage): after \(crossing), the reader went back to page one")
        XCTAssertTrue(previousDocument.waitForExistence(timeout: 15),
                      "\(Self.lostPage): after \(crossing), page two's Previous zone is gone")
    }

    // MARK: - Helpers

    /// The stack layout's list bar; the two-pane never shows it.
    private var listBar: XCUIElement { app.navigationBars["All Research Documents"] }

    /// The navigation bar's Back button.
    private var backButton: XCUIElement { app.buttons["BackButton"].firstMatch }

    /// The page-turn zones — each is its own accessibility element (`DocumentView.documentEdgeTapZone`).
    private var nextDocument: XCUIElement { app.buttons["Next document"].firstMatch }
    private var previousDocument: XCUIElement { app.buttons["Previous document"].firstMatch }

    /// Selects Research in whichever tab-bar representation is up, and opens All Research Documents.
    ///
    /// - Returns: The seeded note's row.
    private func openResearchList() throws -> XCUIElement {
        guard navigator.select(.research).tapped else { throw XCTestError(.failureWhileWaiting) }
        // Before any swipe — a preceding swipe stops the tap driving the push.
        let category = app.cells.containing(
            NSPredicate(format: "label BEGINSWITH 'All Research Documents'")).firstMatch
        XCTAssertTrue(category.waitForExistence(timeout: 10), "no All Research Documents row")
        category.tap()
        let seeded = app.staticTexts["UI Test Research Note"].firstMatch
        XCTAssertTrue(seeded.waitForExistence(timeout: 10),
                      "the seeded note is not in the list — the seeder did not run or the list did not load")
        return seeded
    }

    /// Polls `condition` until it holds or `timeout` passes.
    private func waitUntil(_ timeout: TimeInterval = 10, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return condition()
    }
}

// MARK: - HistoryVisitTitleTests

/// A document opened from a `frusexplorer://` link is listed in History under its OWN title, with its
/// volume and document ids beneath (#1361).
///
/// The link handler opens a document with its VOLUME's manifest title as the header — the only title
/// it has before the volume is downloaded — and the writer used to record that header, so every such
/// visit was listed under the volume's name, over the volume id alone. Unit tests pin the writer
/// (`DocumentViewTests`) and the row (`HistoryPaneSnapshotTests`); only this sees what History DRAWS
/// after the real link path, and it is the one place the caption's drawing is checked.
///
/// ## Oracles
/// - The History row is a `Button` whose accessibility label joins its texts. It is found by
///   EITHER the bare volume id OR the document's head — deliberately broader than the caption it must
///   now carry, `frus1961-63v06 · d1`, so the row is found before the fix as well as after, and a
///   missing caption fails as the caption assertion rather than as "no visit". Its label is then read
///   whole.
/// - With the fix the title line is the document's head, so the identifier pair can only have come
///   from the caption; before it, the label held the volume's title and the bare volume id.
///
/// Version history:
///   1.0 — #1361: initial implementation
///   1.1 — #1361 review fixes: the oracle says how the row is really found
@MainActor
final class HistoryVisitTitleTests: XCTestCase {
    /// Resolves tab destinations across every representation.
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    private var app: XCUIApplication!

    /// The seeded volume, and the manifest title the link handler hands the reader as its header.
    private static let volumeId = "frus1961-63v06"
    private static let volumeTitle =
        "Foreign Relations of the United States, 1961–1963, Volume VI, Kennedy-Khrushchev Exchanges"

    override func setUp() async throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_VOLUME"] = Self.volumeId
        app.launchArguments = UITestLaunch.arguments()
        app.launch()
    }

    override func tearDown() async throws {
        XCUIDevice.shared.orientation = .portrait
        app = nil
    }

    func testALinkedDocumentIsListedUnderItsOwnTitle() throws {
        // Measured on an iPhone only (iPhone 17e, iOS 26.4). The iPad Research tab reaches History
        // through a two-pane sidebar above 820 pt, which this test's row and bar queries have not
        // been run against; the row it reads is the same shared `HistoryView` either way.
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom == .pad,
                      "iPhone only — not yet measured against the iPad Research two-pane")
        let link = try XCTUnwrap(URL(string: "frusexplorer://document/\(Self.volumeId)/d1"))
        app.open(link)

        // The reader's bar shows the parsed head once the document has loaded — and the visit is
        // recorded only after a successful load, so wait for it before looking at History.
        let head = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "UI Test Document One")).firstMatch
        XCTAssertTrue(head.waitForExistence(timeout: 30), "the link did not open and load d1")

        XCTAssertTrue(navigator.select(.research).tapped, "no Research tab")
        let historyRow = app.cells.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "Documents opened and searches run")).firstMatch
        XCTAssertTrue(historyRow.waitForExistence(timeout: 10), "no History row in Research")
        historyRow.tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 10), "History did not open")

        let identifiers = "\(Self.volumeId) · d1"
        let visit = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@ OR label CONTAINS %@", Self.volumeId,
                        "UI Test Document One")).firstMatch
        XCTAssertTrue(visit.waitForExistence(timeout: 10),
                      "no History row naming \(Self.volumeId) or the document's head")

        // What History drew, kept for the reviewer: the row's two lines are the thing under test.
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "History after a frusexplorer:// link"
        shot.lifetime = .keepAlways
        add(shot)

        // Every check below is reported, not only the first: together they say which half regressed.
        continueAfterFailure = true
        let label = visit.label
        XCTAssertTrue(label.contains("UI Test Document One"),
                      "the visit is not listed under the document's own title: \(label)")
        XCTAssertTrue(label.contains(identifiers),
                      "the visit's caption does not name the document: \(label)")
        XCTAssertFalse(label.contains(Self.volumeTitle),
                       "the visit is listed under its volume's title: \(label)")
    }
}

// MARK: - ResearchSidebarSelectionTests

/// The category open in Research's iPad two-pane is marked in the category list beside it — and it is
/// the only row marked (#1362).
///
/// ## Why a UI test, and what it reads
/// The two-pane (F-2) draws each category row as a plain `Button`, because a `NavigationLink(value:)`
/// outside a stack is inert, and a plain button draws no selected state. The list keeps its rows on
/// screen beside the detail, so before #1362 nothing told the reader — or VoiceOver — which category was
/// open. The fix is two modifiers read from `selectedItem`: a row fill and the `.isSelected` trait.
/// **This suite reads the trait and only the trait.** XCUI's `isSelected` reports it, and a fill changes
/// no trait, so a row whose fill were deleted would pass every assertion here. That the two-pane row
/// carries both, on one condition, is pinned in the source by `ResearchSidebarOpenMarkSourceTests` in
/// the unit target; that the fill is visible is checked by eye, from the screenshots this suite keeps.
///
/// ## Where it can fail, and where it skips
/// It can fail only on an iPad whose Research content area — the width `ResearchView`'s 820 pt gate
/// measures, which the tab sidebar narrows — reaches the gate. On an iPhone both tests skip as iPad-only,
/// measuring no width: the stack pushes a chosen category and no list stays on screen to mark. On an
/// iPad whose content area is under the gate they skip, naming the content width they measured. Over
/// the gate they never skip: a two-pane that is not there fails, and so does a selection the
/// representation toggle loses. Run them on an iPad Pro 13-inch; in landscape both representations are
/// two-pane there.
///
/// ## Both tab-bar representations, and why landscape
/// `.sidebarAdaptable`'s representation persists per install and has no launch pin, and the sidebar takes
/// real layout width: iPad Pro 13-inch portrait (1,032 pt) with the sidebar open is under the gate. So
/// the suite launches in LANDSCAPE. The first test runs in whichever representation the install has; the
/// second toggles to the other one and asserts there, and `tearDown` puts the install's own back. Every
/// assertion message and screenshot names the representation it ran in.
///
/// ## Oracles
/// - Rows are found by identifier (`ResearchSidebarItem.rowAccessibilityIdentifier`), and ALL of them at
///   once by its prefix, read from one snapshot of the element tree per sweep, so no read can land on an
///   element a re-render has since removed. The sweep must find the four rows iOS always draws, or "no
///   other row is marked" would hold over an empty set; a sweep that does not find them fails under its
///   own tag, so a missing row cannot read as a missing mark.
/// - Arrival is checked apart from the mark, so a tap that did not take cannot read as a missing mark:
///   History's search field or the seeded note appears, and the detail placeholder leaves.
/// - Before any category is chosen NO row is marked — the control that `isSelected` is not simply on for
///   every row.
///
/// Version history:
///   1.0 — #1362: initial implementation
///   1.1 — #1362 review, round 1: the doc says the suite reads the trait and not the fill; both skips
///          key on the content width the gate measures, so a lost two-pane and a selection lost on the
///          toggle FAIL; the placeholder's leaving is asserted; each row sweep reads one snapshot, and one
///          that finds no rows fails under its own tag
///   1.2 — #1431: the content-width measure moved to `TabBarNavigator`, unchanged, so Browse's
///          `BrowseRootSelectionTests` reads the same one
@MainActor
final class ResearchSidebarSelectionTests: XCTestCase {
    /// Resolves tab destinations across every representation.
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    private var app: XCUIApplication!

    /// The `.sidebarAdaptable` representation this launch found, restored in `tearDown` — see
    /// `UIObstructionTests.baselineSidebarExpanded` for why a baseline and not a flag.
    private var baselineSidebarExpanded = false

    /// Carried by every assertion about the mark, so an A/B can confirm a failure happened there and not
    /// at a precondition.
    private static let unmarked = "OPEN CATEGORY NOT MARKED ALONE"

    /// Carried by the sweep's precondition — the four always-drawn rows found — so a sweep that finds no
    /// rows (an identifier renamed, a tree not yet drawn) fails under this tag and never under `unmarked`.
    private static let rowsMissing = "CATEGORY ROWS NOT FOUND"

    /// `ResearchView.twoPaneMinimumWidth`, which this target cannot import.
    private static let twoPaneGate: CGFloat = 820

    /// `ResearchSidebarItem.rowAccessibilityIdentifierPrefix`, and the identifiers of the four rows iOS
    /// always draws. `ResearchSidebarRowIdentityTests` pins the app's side of these strings.
    private static let rowPrefix = "research.sidebar.row."
    private static let allAnnotated = rowPrefix + "allAnnotated"
    private static let hasNotes = rowPrefix + "hasNotes"
    private static let notes = rowPrefix + "notes"
    private static let history = rowPrefix + "history"
    private static let alwaysDrawn: Set<String> = [allAnnotated, hasNotes, notes, history]

    override func setUp() async throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        // The seeded note gives All Research Documents a row to open, for the Back re-entry.
        app.launchEnvironment["FRUS_UI_TEST_SEED_NOTE"] = "1"
        // Every assertion reads a screen at rest (CLAUDE.md: the iOS 27 idle-counter stall).
        app.launchEnvironment["FRUS_UI_TEST_DISABLE_ANIMATIONS"] = "1"
        app.launchArguments = UITestLaunch.arguments()
        app.launch()
        baselineSidebarExpanded = navigator.sidebarIsExpanded
    }

    override func tearDown() async throws {
        // Restore the install's representation whoever displaced it — the toggle test, or the
        // navigator's sidebar route — and after an `XCTFail` unwind too.
        if app != nil, navigator.sidebarIsExpanded != baselineSidebarExpanded,
           let toggle = navigator.sidebarToggleButton(timeout: 2) {
            toggle.tap()
        }
        XCUIDevice.shared.orientation = .portrait
        app = nil
    }

    // MARK: - Tests

    /// In the launch representation: nothing marked before a choice; History alone once chosen; the mark
    /// moves with the choice; and it is still there after the two ways back to the list — Back from a
    /// document read over the two-pane, and leaving the tab and returning.
    func testTheOpenCategoryAloneIsMarked() throws {
        try openResearchTwoPane()
        let representation = representationName

        assertMarked(nil, "before any category is chosen", representation)

        row(Self.history).tap()
        assertArrived(historySearchField, "choosing History", representation)
        assertMarked(Self.history, "after choosing History", representation)
        attachScreenshot("#1362 History chosen — \(representation)")

        row(Self.allAnnotated).tap()
        assertArrived(seededNote, "choosing All Research Documents", representation)
        assertMarked(Self.allAnnotated, "after moving to All Research Documents", representation)

        // Back from a document read over the whole two-pane: the list is drawn again beneath it.
        seededNote.tap()
        XCTAssertTrue(waitUntil { backButton.exists && !row(Self.allAnnotated).isHittable },
                      "opening the seeded note did not cover the two-pane [\(representation)]")
        backButton.tap()
        XCTAssertTrue(waitUntil { seededNote.isHittable },
                      "Back did not return to All Research Documents [\(representation)]")
        assertMarked(Self.allAnnotated, "after Back from a document", representation)

        // Leaving the tab and coming back.
        XCTAssertTrue(navigator.select(.browse).tapped, "no Browse tab [\(representation)]")
        XCTAssertTrue(navigator.select(.research).tapped, "no Research tab on return [\(representation)]")
        XCTAssertTrue(seededNote.waitForExistence(timeout: 10),
                      "returning to Research did not show All Research Documents [\(representation)]")
        assertMarked(Self.allAnnotated, "after leaving the tab and returning", representation)
    }

    /// In the OTHER representation: the choice and its mark survive the toggle, and a choice made there is
    /// marked alone.
    func testTheMarkHoldsInTheOtherTabBarRepresentation() throws {
        try openResearchTwoPane()
        let launched = representationName

        row(Self.history).tap()
        assertArrived(historySearchField, "choosing History", launched)
        assertMarked(Self.history, "after choosing History", launched)

        let toggle = try XCTUnwrap(navigator.sidebarToggleButton(timeout: 5),
                                   "no sidebar toggle — the other representation cannot be reached [\(launched)]")
        toggle.tap()
        XCTAssertTrue(waitUntil { navigator.sidebarIsExpanded != baselineSidebarExpanded },
                      "the toggle did not change the tab-bar representation from \(launched)")
        let toggled = representationName

        // The skip keys on the width the gate measures and on nothing else. History leaving the detail
        // while the content area is still over the gate is a lost selection, and fails below.
        let width = try settledContentWidth(toggled)
        try XCTSkipIf(width < Self.twoPaneGate, """
            In the \(toggled) representation Research's content area is \(Int(width)) pt, under the \
            820 pt two-pane gate, so no list stays beside the detail to mark. Run on iPad Pro 13-inch in \
            landscape.
            """)
        XCTAssertTrue(waitUntil(5) { row(Self.history).isHittable }, """
            TWO-PANE LOST ON THE TOGGLE: Research's content area is \(Int(width)) pt, over the 820 pt gate, \
            but the category list is not on screen beside the detail [\(toggled)]
            """)
        XCTAssertTrue(historySearchField.waitForExistence(timeout: 10), """
            SELECTION LOST ON THE TOGGLE: History left the detail pane when the representation changed, \
            though Research's content area is \(Int(width)) pt and still two-pane [\(toggled)]
            """)
        XCTAssertTrue(waitUntil(5) { !detailPlaceholder.exists },
                      "the detail placeholder is drawn again after the toggle [\(toggled)]")
        assertMarked(Self.history, "after toggling to the other representation", toggled)
        attachScreenshot("#1362 History chosen — \(toggled)")

        row(Self.allAnnotated).tap()
        assertArrived(seededNote, "choosing All Research Documents", toggled)
        assertMarked(Self.allAnnotated, "after moving to All Research Documents", toggled)
        attachScreenshot("#1362 All Research Documents chosen — \(toggled)")
    }

    // MARK: - Steps and oracles

    /// Selects Research and requires its two-pane wherever the gate admits one. On an iPhone it skips as
    /// iPad-only, measuring nothing; on an iPad whose Research content area is under the gate it skips,
    /// naming that width; on an iPad over the gate a missing two-pane FAILS.
    private func openResearchTwoPane() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, """
            iPad only: on iPhone Research is a stack, a chosen category is pushed, and no list stays on \
            screen to mark.
            """)
        XCTAssertTrue(navigator.select(.research, resolveTimeout: 10).tapped,
                      "no Research tab [\(representationName)]")
        let representation = representationName
        let width = try settledContentWidth(representation)
        try XCTSkipIf(width < Self.twoPaneGate, """
            Research's content area is \(Int(width)) pt in the \(representation) representation — under \
            the 820 pt two-pane gate, where a chosen category is pushed and no list stays beside it to \
            mark. Run on iPad Pro 13-inch in landscape.
            """)
        XCTAssertTrue(detailPlaceholder.waitForExistence(timeout: 10), """
            TWO-PANE LOST: Research's content area is \(Int(width)) pt in the \(representation) \
            representation, over the 820 pt gate, but the two-pane's detail placeholder never appeared.
            """)
        print("[#1362] representation=\(representation) window=\(app.windows.firstMatch.frame.width)pt "
              + "content=\(width)pt")
    }

    /// Requires the tap that chose a category to have taken: `landmark`, which only that category's
    /// detail draws, appears, and the detail placeholder leaves.
    private func assertArrived(_ landmark: XCUIElement, _ choice: String, _ representation: String,
                               file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(landmark.waitForExistence(timeout: 10),
                      "\(choice) did not show its detail [\(representation)]", file: file, line: line)
        XCTAssertTrue(waitUntil(5) { !detailPlaceholder.exists },
                      "\(choice) left the detail placeholder drawn [\(representation)]", file: file, line: line)
    }

    /// Requires `expected` to be the only category row reporting `isSelected` (`nil`: none), polled
    /// briefly because the mark is drawn on the render after the tap. The four always-drawn rows are
    /// asserted first, under their own tag.
    private func assertMarked(_ expected: String?, _ moment: String, _ representation: String,
                              file: StaticString = #filePath, line: UInt = #line) {
        let want: Set<String> = expected.map { [$0] } ?? []
        var rows: [RowState] = []
        _ = waitUntil(5) {
            rows = rowStates()
            return Self.alwaysDrawn.isSubset(of: Set(rows.map(\.identifier)))
                && Set(rows.filter(\.isSelected).map(\.identifier)) == want
        }
        let table = rows.map { "\($0.identifier)[type \($0.type.rawValue)]=\($0.isSelected ? "SELECTED" : "-")" }
            .joined(separator: ", ")
        print("[#1362] \(moment) [\(representation)]: \(table)")
        XCTAssertTrue(Self.alwaysDrawn.isSubset(of: Set(rows.map(\.identifier))), """
            \(Self.rowsMissing): \(moment), in the \(representation) representation, the sweep did not find \
            the four rows iOS always draws (\(Self.alwaysDrawn.sorted())), so no mark could be read. \
            Read: \(table.isEmpty ? "nothing" : table)
            """, file: file, line: line)
        XCTAssertTrue(Set(rows.filter(\.isSelected).map(\.identifier)) == want, """
            \(Self.unmarked): \(moment), in the \(representation) representation, expected \
            \(expected ?? "no row") alone to report isSelected among the category rows. Read: \(table)
            """, file: file, line: line)
    }

    /// One element carrying a category-row identifier, as XCUI reports it.
    private struct RowState {
        /// The row's accessibility identifier.
        let identifier: String
        /// The element's type — printed so a failure shows whether a cell or a button carried it.
        let type: XCUIElement.ElementType
        /// Whether the element reports the selected trait.
        let isSelected: Bool
    }

    /// Every element carrying a category-row identifier, with its selected state, from ONE snapshot.
    private func rowStates() -> [RowState] {
        snapshotElements()
            .filter { $0.identifier.hasPrefix(Self.rowPrefix) }
            .map { RowState(identifier: $0.identifier, type: $0.elementType, isSelected: $0.isSelected) }
    }

    /// Every element of one snapshot of the app's tree, or none when the snapshot cannot be taken.
    ///
    /// One snapshot, rather than a query's `allElementsBoundByIndex`: each property read from an element
    /// bound by index resolves it again, and when a re-render has dropped that index the read is a hard
    /// XCTest failure, not a `false`. A snapshot is read once, so a sweep either sees a whole tree or,
    /// when it throws, nothing — which the polling callers treat as "not yet".
    private func snapshotElements() -> [any XCUIElementSnapshot] {
        guard let root = try? app.snapshot() else { return [] }
        var found: [any XCUIElementSnapshot] = []
        var pending: [any XCUIElementSnapshot] = [root]
        while let next = pending.popLast() {
            found.append(next)
            pending.append(contentsOf: next.children)
        }
        return found
    }

    /// The width `ResearchView`'s 820 pt gate measures: the window, less the tab sidebar when the sidebar
    /// is the representation, settled — `TabBarNavigator.settledContentAreaWidth(timeout:logTag:)`,
    /// which carries the measurement that chose it and which Browse's suite (#1431) reads too.
    private func settledContentWidth(_ representation: String,
                                     file: StaticString = #filePath, line: UInt = #line) throws -> CGFloat {
        try XCTUnwrap(navigator.settledContentAreaWidth(logTag: "[#1362] [\(representation)]"),
                      "Research's content width never settled [\(representation)]", file: file, line: line)
    }

    /// The category row with `identifier`.
    private func row(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Which `.sidebarAdaptable` representation is up.
    private var representationName: String {
        navigator.sidebarIsExpanded ? "sidebar" : "floating tab bar"
    }

    /// The detail pane's placeholder, drawn only by the two-pane with nothing chosen.
    private var detailPlaceholder: XCUIElement { app.staticTexts["Select a category"].firstMatch }

    /// History's search field — present whatever History holds, so it says History is in the detail.
    private var historySearchField: XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Search history")).firstMatch
    }

    /// The seeded note's row in All Research Documents.
    private var seededNote: XCUIElement { app.staticTexts["UI Test Research Note"].firstMatch }

    /// The navigation bar's Back button.
    private var backButton: XCUIElement { app.buttons["BackButton"].firstMatch }

    /// Attaches a screenshot the reviewer keeps — the only check on the fill's colour, which no
    /// assertion here can read.
    private func attachScreenshot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Polls `condition` until it holds or `timeout` passes.
    private func waitUntil(_ timeout: TimeInterval = 10, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return condition()
    }
}

// MARK: - SelectionEditMenuTests

/// A text selection in the iPhone and iPad reader offers the app's own actions at the START of the
/// system edit menu, and no floating selection bar is drawn beside it (#1540).
///
/// ## The defect
/// Until #1540 the reader drew its own dark pill — four colour dots, Excerpt, Look Up, Note — anchored
/// below the selection, on the assumption that UIKit always puts its edit menu above. UIKit puts it below
/// too, and the bar flipped above a selection near the bottom edge, so the system menu sometimes covered
/// the bar. The owner chose (2026-09-29) to put the app's actions into the system menu itself and retire
/// the iOS bar; the Mac keeps its bar.
///
/// ## Oracles
/// - `app.menuItems` is the edit menu's own accessibility tree — the names VoiceOver reads. Its row
///   shows what fits (on iOS 26.5 and 27.0, the four dots and Excerpt on an iPhone 17; those and Look
///   Up in NARA on an iPad Pro 13-inch) and ends in › (`Forward` under iOS 26.5, `Next Page` under
///   27.0), which opens the whole menu as a list of buttons. The row must open with the app's items in
///   the decision's order, and the list must hold all seven first, under their spoken names, with Copy
///   after them.
/// - The retired bar drew its dots and verbs as BUTTONS named "Highlight Yellow", "Look Up" and so on. A
///   button of one of those names on screen while the menu is up is the bar, and fails.
/// - A highlight is observed where a reader would find it: back on the Research root, whose "By
///   Highlight" section lists a colour only while the store holds a highlight of it (the UI-test store is
///   in memory, so every launch starts with none).
/// - Look Up in NARA is observed in the sheet it opens: "Look Up in NARA Catalog", with the selected
///   word in its query field. Excerpt and Note are observed the same way, in the sheets they open:
///   "Add Excerpt to Collection" and "New Research Note".
/// - That the selection is CLEARED after an item is chosen is not observable here: UIKit dismisses an
///   edit menu whenever one of its items is chosen, whether or not the page's selection survives, so
///   a menu that goes away proves nothing about the selection. `SelectionEditMenuItemTests` pins the
///   clear in the unit target, through the real selection bridge.
///
/// ## Fixture
/// The same as `ResearchReadingDepthTests`: the seeded note sits on `d1` of the seeded volume, whose
/// body reads "Synthetic UI-test content for frus1961-63v06, document 1.", so the row opens a real
/// document with text to select. The suite long-presses the first word, "Synthetic", which lies inside
/// one text node and so has document offsets: a press at the middle of the two-line paragraph on an
/// iPhone 17 selected something with none, and the menu offered only Look Up in NARA and Note. The
/// press is held 3 s, and a tap follows it when it raises no menu, for the reasons below.
///
/// ## Under iOS 27.0
/// Measured 2026-11-16 on iPhone 17 and iPad Pro 13-inch (M5), iOS 27.0. XCTest's long press selects
/// the word, and the edit menu comes only when the selection has landed before the press lifts: one
/// that lands after it leaves the word selected, its handles drawn, with no menu, and a long press
/// over that selection raises none either. The 1.2 s press this suite made until then lifted too soon
/// on the iPhone 17 in all six runs, 12 s after the page rendered as at 1 s, so every test failed on
/// "On screen: []", on `v2`'s code too; held 2 s or 3 s it raised the menu in 3 of 3 runs each, the
/// lookup opening on "Synthetic". A 3 s press still lifted too soon in 1 of 14 tries on the iPhone and
/// 2 of 19 on the iPad, each on a slow page (the three lookups of the paragraph XCTest makes as it
/// presses took 3.2 to 6.7 s each, against 1.4 to 3.1 s where it raised the menu), and pressing again
/// did not help. A tap on the selected word did: after a 1.2 s press had left the word selected with
/// no menu, a 3 s press raised none and the tap raised the whole menu, the lookup opening on
/// "Synthetic" (3 of 3 runs, on both devices). A long press of 1.2 s by hand (L19, the simulator
/// control tool, #1919) raises the menu, so the app's menu stands. The menu's › is `Next Page` under
/// 27.0, which the suite's `Forward` did not find.
///
/// ## Where it fails
/// Measured on iPhone 17 and iPad Pro 13-inch (M5), both iOS 26.5: before #1540 the first three tests
/// fail on each (the menu read Copy, Find Selection, Look Up — and Translate on the iPad — beside the
/// bar's buttons). The fourth, `testExcerptAndNoteFromTheEditMenuOpenTheirSheets`, was added in review
/// round 1 and measured against the reader's Excerpt and Note branches swapped instead; it failed on
/// iPhone 17, naming the sheet Excerpt opened. The first test's check that the menu's first page
/// OPENS with "Highlight Yellow" was measured against an extra item put ahead of the app's, on the
/// same device: the row read ["Probe", "Highlight Yellow", …], and the check before it, which reads
/// only the app's items, passed.
///
/// ## Running it
/// The suite lives in this file but is not `ResearchReadingStaysInTabTests`, so
/// `-only-testing FRUSExplorerUITests/ResearchReadingStaysInTabTests` runs none of it: name
/// `FRUSExplorerUITests/SelectionEditMenuTests`. Run it on an iPhone AND an iPad — the menu pages
/// differently on each, so Look Up in NARA is in the row on one and behind › on the other (see
/// `CLAUDE.md`).
///
/// Version history:
///   1.0 — #1540: initial implementation
///   1.1 — #1540 review round 1: Excerpt and Note are driven to their sheets; the first page must open
///          with the app's first item; the colour test no longer claims to see the selection cleared
///   1.2 — 2026-11-16: the press is held 3 s and followed by a tap on the word when it raises no
///          menu, and the menu's › is found as `Next Page` too, so the suite runs under iOS 27.0
@MainActor
final class SelectionEditMenuTests: XCTestCase {
    /// Resolves tab destinations across every representation, including the floating iPad bar when
    /// it has paged a tab off screen.
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    private var app: XCUIApplication!

    /// The app's items, under their spoken names, in the order #1540's decision puts them.
    private static let appItems = ["Highlight Yellow", "Highlight Green", "Highlight Blue",
                                   "Highlight Pink", "Excerpt", "Look Up in NARA", "Note"]

    /// The word the suite selects: the first of the fixture's body.
    private static let selectedWord = "Synthetic"

    /// How long the suite holds its press on the word, in seconds. Under iOS 27.0 a press of 1.2 s
    /// (this suite's until 2026-11-16) selects the word and raises no edit menu; 2 s raised it on an
    /// iPhone 17 in 3 of 3 runs, and 3 s leaves a second to spare (see the suite's notes).
    private static let pressDuration: TimeInterval = 3

    /// How many presses ``selectTheFirstWord()`` makes, each followed by a tap when it raises no menu,
    /// before it leaves the tests to report no menu (see the suite's notes).
    private static let pressAttempts = 3

    /// The names UIKit gives the edit menu's page-turn button (›): `Forward` under iOS 26.5, `Next
    /// Page` under iOS 27.0. Matched exactly, since the app's own results pager is "Next page".
    private static let pageTurnNames = ["Forward", "Next Page"]

    override func setUp() async throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_VOLUME"] = "frus1961-63v06"
        app.launchEnvironment["FRUS_UI_TEST_SEED_NOTE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_NOTE_DOCUMENT"] = "d1"
        // The rail closed and the mode pinned to `rememberLast`, so this suite writes no reading
        // preference (see ResearchReadingDepthTests' note on it).
        app.launchArguments = UITestLaunch.arguments() + [
            "-frus.document.researchPanel.visible", "NO",
            "-frus.reading.defaultMode", "rememberLast"]
        app.launch()
    }

    override func tearDown() async throws {
        // The sheet tests close their own sheets; this catches a lookup a failure left open. It does
        // not press the excerpt picker's Cancel or the composer's Discard, but those sheets are the
        // reader's `activeSheet`, plain view state that no launch restores.
        UITestPresentation.dismissAnyPresentation(in: app)
        XCUIDevice.shared.orientation = .portrait
        app = nil
    }

    /// The app's actions open the edit menu under their spoken names, Copy follows them, and the bar
    /// is gone.
    func testTheEditMenuLeadsWithTheReadersActions() throws {
        try openTheSeededDocument()
        selectTheFirstWord()

        XCTAssertTrue(app.menuItems["Highlight Yellow"].waitForExistence(timeout: 8), """
            #1540: the edit menu does not open with "Highlight Yellow". On screen: \(pageLabels()). \
            Buttons named like the retired bar's: \(barButtonLabels()).
            """)
        attachScreenshot("Edit menu, first page")
        XCTAssertTrue(barButtonLabels().isEmpty, """
            #1540: the retired floating selection bar is still drawn beside the edit menu: \
            \(barButtonLabels())
            """)

        let firstPage = pageLabels()
        let leading = Array(firstPage.prefix { Self.appItems.contains($0) })
        XCTAssertEqual(leading, Array(Self.appItems.prefix(leading.count)),
                       "#1540: the app's actions on the menu's first page are out of order: \(firstPage)")
        // The check above compares an empty prefix with an empty prefix when the row opens with
        // anything else, so the row's first item is asked for by name.
        XCTAssertEqual(firstPage.first, Self.appItems.first,
                       "#1540: the menu's first page does not open with the app's actions: \(firstPage)")

        let items = wholeMenu()
        print("[#1540] edit menu: first page \(firstPage); whole menu \(items)")
        XCTAssertEqual(Array(items.prefix(Self.appItems.count)), Self.appItems,
                       "#1540: the app's actions do not open the menu, in order. Whole menu: \(items)")
        let copy = try XCTUnwrap(items.firstIndex(of: "Copy"),
                                 "the system menu's Copy is missing. Whole menu: \(items)")
        XCTAssertGreaterThanOrEqual(copy, Self.appItems.count,
                                    "#1540: Copy comes before one of the app's actions. Whole menu: \(items)")
        attachScreenshot("Edit menu, whole")
    }

    /// Choosing a colour from the menu makes a highlight.
    ///
    /// The menu going away after the tap is UIKit's doing, not the app's: it does not show that the
    /// selection was cleared (see the suite's oracles).
    func testAColourFromTheEditMenuMakesAHighlight() throws {
        try openTheSeededDocument()
        selectTheFirstWord()

        let yellow = app.menuItems["Highlight Yellow"]
        XCTAssertTrue(yellow.waitForExistence(timeout: 8),
                      "#1540: the edit menu has no \"Highlight Yellow\" item. On screen: \(pageLabels())")
        yellow.tap()
        XCTAssertTrue(waitUntil(5) { app.menuItems.count == 0 },
                      "The menu stayed up after a colour was chosen: \(pageLabels())")
        attachScreenshot("After Highlight Yellow")

        // Back to the Research root, where a highlight adds a row under "By Highlight".
        var backs = 0
        while backButton.exists && backs < 3 {
            backButton.tap()
            backs += 1
            Thread.sleep(forTimeInterval: 1)
        }
        let yellowRow = app.cells.containing(NSPredicate(format: "label CONTAINS 'Yellow'")).firstMatch
        XCTAssertTrue(yellowRow.waitForExistence(timeout: 10), """
            #1540: no Yellow row under By Highlight on the Research root, so the menu's colour made no \
            highlight.
            """)
    }

    /// Look Up in NARA opens the NARA lookup with the selected word as its query.
    func testLookUpInNARAOpensTheLookupWithTheSelection() throws {
        try openTheSeededDocument()
        selectTheFirstWord()

        XCTAssertTrue(app.menuItems["Highlight Yellow"].waitForExistence(timeout: 8),
                      "#1540: the edit menu does not open with the app's actions. On screen: \(pageLabels())")
        var lookUp = app.menuItems["Look Up in NARA"]
        if !(lookUp.exists && lookUp.isHittable), forward.exists {
            // Behind the menu's ›, which opens the whole menu as a list of buttons.
            forward.tap()
            Thread.sleep(forTimeInterval: 0.5)
            lookUp = app.cells.buttons["Look Up in NARA"].firstMatch
        }
        XCTAssertTrue(lookUp.exists && lookUp.isHittable,
                      "#1540: no \"Look Up in NARA\" in the edit menu. Whole menu: \(listLabels())")
        lookUp.tap()

        let sheet = app.navigationBars["Look Up in NARA Catalog"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 10),
                      "Look Up in NARA did not open the NARA Catalog lookup")
        let query = app.textFields.matching(
            NSPredicate(format: "value == %@", Self.selectedWord)).firstMatch
        XCTAssertTrue(query.waitForExistence(timeout: 5), """
            The lookup did not open on the selected word "\(Self.selectedWord)". Text fields: \
            \(app.textFields.allElementsBoundByIndex.map { $0.value as? String ?? "" })
            """)
        attachScreenshot("Look Up in NARA")
        app.navigationBars["Look Up in NARA Catalog"].buttons["Close"].tap()
        XCTAssertTrue(waitUntil(5) { !sheet.exists }, "the lookup's Close did not close it")
    }

    /// Excerpt opens the collection picker for an excerpt of the selection, and Note opens the note
    /// composer: the reader's other two branches for a chosen item (`DocumentView.performSelectionVerb`).
    func testExcerptAndNoteFromTheEditMenuOpenTheirSheets() throws {
        try openTheSeededDocument()

        selectTheFirstWord()
        chooseFromTheMenu("Excerpt")
        let picker = app.navigationBars["Add Excerpt to Collection"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10), """
            #1540: Excerpt did not open the collection picker for an excerpt. Navigation bars: \
            \(navigationBarNames())
            """)
        attachScreenshot("Excerpt")
        picker.buttons["Cancel"].tap()
        XCTAssertTrue(waitUntil(5) { !picker.exists }, "the picker's Cancel did not close it")

        selectTheFirstWord()
        chooseFromTheMenu("Note")
        let composer = app.navigationBars["New Research Note"]
        XCTAssertTrue(composer.waitForExistence(timeout: 10), """
            #1540: Note did not open the note composer. Navigation bars: \(navigationBarNames())
            """)
        attachScreenshot("Note")
        composer.buttons["Discard"].tap()
        XCTAssertTrue(waitUntil(5) { !composer.exists }, "the composer's Discard did not close it")
    }

    // MARK: - Steps

    /// Chooses the item named `name` from the edit menu: from its row when the row shows it, else
    /// from the list the menu's › opens.
    private func chooseFromTheMenu(_ name: String) {
        XCTAssertTrue(app.menuItems["Highlight Yellow"].waitForExistence(timeout: 8),
                      "#1540: the edit menu does not open with the app's actions. On screen: \(pageLabels())")
        var item = app.menuItems[name]
        if !(item.exists && item.isHittable), forward.exists {
            forward.tap()
            Thread.sleep(forTimeInterval: 0.5)
            item = app.cells.buttons[name].firstMatch
        }
        XCTAssertTrue(item.exists && item.isHittable,
                      "#1540: no \"\(name)\" in the edit menu. Whole menu: \(listLabels())")
        item.tap()
    }

    /// Opens Research ▸ All Research Documents ▸ the seeded note, which reads the fixture's first document.
    private func openTheSeededDocument() throws {
        guard navigator.select(.research).tapped else { throw XCTestError(.failureWhileWaiting) }
        let category = app.cells.containing(
            NSPredicate(format: "label BEGINSWITH 'All Research Documents'")).firstMatch
        XCTAssertTrue(category.waitForExistence(timeout: 10), "no All Research Documents row")
        category.tap()
        let seeded = app.staticTexts["UI Test Research Note"].firstMatch
        XCTAssertTrue(seeded.waitForExistence(timeout: 10),
                      "the seeded note is not in the list — the seeder did not run or the list did not load")
        seeded.tap()
        XCTAssertTrue(app.navigationBars["UI Test Document One"].waitForExistence(timeout: 15),
                      "the seeded row did not open the fixture's first document")
    }

    /// Long-presses the body's first word, which selects it and raises the edit menu.
    ///
    /// The press lands 30 pt into the paragraph's first line rather than at the element's centre: on
    /// an iPhone the paragraph wraps to two lines, and its centre falls between them. It is held for
    /// ``pressDuration``, since under iOS 27.0 a press of 1.2 s selects the word and raises no menu.
    /// When no menu comes even so, the selection landed after the lift (see the suite's notes), and a
    /// tap on the selected word raises it, as a reader's would; a press that selected nothing is made
    /// again, up to ``pressAttempts`` presses in all. Any menu ends the steps, one without the app's
    /// items included, so the tests' checks still see it.
    private func selectTheFirstWord() {
        let body = app.webViews.firstMatch.staticTexts
            .matching(NSPredicate(format: "label CONTAINS %@", Self.selectedWord)).firstMatch
        XCTAssertTrue(body.waitForExistence(timeout: 20), "the fixture's body text never rendered")
        Thread.sleep(forTimeInterval: 1)
        let word = body.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 30, dy: 10))
        let menu = app.menuItems.firstMatch
        for press in 1...Self.pressAttempts {
            word.press(forDuration: Self.pressDuration)
            if menu.waitForExistence(timeout: 5) { return }
            print("[SelectionEditMenuTests] press \(press) of \(Self.pressAttempts) raised no edit menu; "
                  + "tapping the word")
            word.tap()
            if menu.waitForExistence(timeout: 5) { return }
            print("[SelectionEditMenuTests] the tap after press \(press) raised no edit menu")
        }
    }

    /// Every item of the menu, in its order.
    ///
    /// A menu with more items than its row holds ends the row with › (``forward``), which opens the
    /// WHOLE menu as a vertical list, each item a button in a cell, from the first item on (measured
    /// on iPhone 17 and iPad Pro 13-inch (M5), under iOS 26.5 and 27.0). With no › the row is the
    /// whole menu.
    private func wholeMenu() -> [String] {
        guard forward.exists && forward.isHittable else { return pageLabels() }
        forward.tap()
        Thread.sleep(forTimeInterval: 0.5)
        return listLabels()
    }

    /// The items of the menu's list, top to bottom: each cell's button.
    private func listLabels() -> [String] {
        app.cells.allElementsBoundByIndex
            .filter { $0.exists && $0.isHittable }
            .sorted { $0.frame.minY < $1.frame.minY }
            .compactMap { cell in
                let button = cell.buttons.firstMatch
                return button.exists ? button.label : nil
            }
    }

    // MARK: - Helpers

    /// The edit-menu items on screen, read in the menu's own order (top to bottom, then leading to
    /// trailing).
    private func pageLabels() -> [String] {
        app.menuItems.allElementsBoundByIndex
            .filter { $0.exists && $0.isHittable }
            .sorted { lhs, rhs in
                abs(lhs.frame.midY - rhs.frame.midY) > 4
                    ? lhs.frame.midY < rhs.frame.midY : lhs.frame.minX < rhs.frame.minX
            }
            .map(\.label)
    }

    /// The menu's page-turn button (›), under either of ``pageTurnNames``.
    ///
    /// The floating tab bar's pager is `Next Page` too (`TabBarNavigator`), so of the buttons so
    /// named the one taken is the one level with the menu's items.
    private var forward: XCUIElement {
        let named = app.buttons.matching(NSPredicate(format: "label IN %@ OR identifier IN %@",
                                                     Self.pageTurnNames, Self.pageTurnNames))
        guard let row = app.menuItems.allElementsBoundByIndex.first(where: { $0.exists })?.frame else {
            return named.firstMatch
        }
        return named.allElementsBoundByIndex
            .first { $0.exists && abs($0.frame.midY - row.midY) < row.height } ?? named.firstMatch
    }

    /// Buttons carrying the retired bar's names. The bar drew each dot and verb as a button; the menu
    /// draws them as menu items.
    private func barButtonLabels() -> [String] {
        (Self.appItems + ["Look Up"]).filter { app.buttons[$0].exists }
    }

    /// The navigation bar's Back button.
    private var backButton: XCUIElement { app.buttons["BackButton"].firstMatch }

    /// The identifiers of the navigation bars on screen, which name the screens and sheets showing.
    private func navigationBarNames() -> [String] {
        app.navigationBars.allElementsBoundByIndex.map(\.identifier)
    }

    /// Attaches a screenshot the reviewer keeps.
    private func attachScreenshot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Polls `condition` until it holds or `timeout` passes.
    private func waitUntil(_ timeout: TimeInterval = 10, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return condition()
    }
}

// MARK: - NoteEditorUnsavedChangesTests

/// The note editor loses nothing the reader typed without asking, and deletes a note only once asked
/// (L19, #1919, IPA-2).
///
/// Before L19 the editor was an ordinary sheet: nothing is saved before Save, so a swipe down or
/// Discard closed it and the typed text was gone, and its Delete erased the note at once, where All
/// Notes asks "Delete Note?" first; on an iPad the app then trapped as All Notes' sheet closed.
///
/// ## What each test drives
/// - `testASwipeAsksBeforeLosingTypedText` types into the seeded note, swipes the sheet down, and
///   requires "Discard Changes?" with the editor still open; closes the dialog without discarding and
///   requires the typed words still in the body; on an iPad taps beside the sheet and requires the
///   editor still open with them, since UIKit ignores a touch outside a sheet it holds modal and
///   reports no attempt, so that tap asks nothing and loses nothing; then Discard, which asks too,
///   and Discard Changes, after which the list still shows the note as it was.
/// - `testAnUntouchedNoteClosesOnASwipeAndSaveAsksNothing` swipes an untouched note away (nothing to
///   lose, so no dialog), then types and saves: the editor closes with no dialog and the row reads the
///   saved words. Save is the case the guard must stand aside for.
/// - `testDeleteAsksAsAllNotesDoes` requires All Notes' dialog, its title and message, before the
///   note is deleted, and the note still there after the dialog is closed without deleting; then
///   deletes it through the dialog and requires All Notes empty. On an iPad that last step is where
///   the code before L19 trapped, building the editor again around the deleted note as the sheet
///   closed (iPad Pro 13-inch (M5), iOS 27.0; `ResearchNoteEditorViewModel.readable`).
///
/// ## Fixture and oracles
/// `FRUS_UI_TEST_SEED_NOTE` puts one note, "UI Test Research Note", on a document no fixture holds;
/// All Notes lists it and its row opens the editor, titled "Edit Note". A dialog is read by its title.
/// Under iOS 27.0 each hangs from its button as a popover, on the iPhone as on the iPad, and draws no
/// cancel button, so a tap outside it closes it; where an action sheet draws a cancel button, that
/// button is tapped.
///
/// ## Running it
/// The suite lives in this file but is not `ResearchReadingStaysInTabTests`: name
/// `FRUSExplorerUITests/NoteEditorUnsavedChangesTests`. Run it on an iPhone and an iPad, under iOS 27
/// with the allowance `CLAUDE.md` gives.
///
/// Version history:
///   1.0 — L19 (#1919, IPA-2): initial implementation
@MainActor
final class NoteEditorUnsavedChangesTests: XCTestCase {
    /// Resolves tab destinations across every representation.
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    private var app: XCUIApplication!

    /// `UITestResearchSeeder.noteBody`, repeated because a UI-test target cannot import the app.
    private static let seededBody = "UI Test Research Note"
    /// What the tests type: words the keyboard leaves as they are.
    private static let typed = "Typed in the test"
    /// The editor's navigation title for an existing note.
    private static let editorTitle = "Edit Note"
    /// The dialog that asks before typed text is lost.
    private static let discardTitle = "Discard Changes?"
    /// How long a wait waits: long, for the slow queries `CollectionEditorTitleTests.patience` records.
    private static let patience: TimeInterval = 30

    override func setUp() async throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_NOTE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_DISABLE_ANIMATIONS"] = "1"
        app.launchArguments = UITestLaunch.arguments(startingOn: .research)
        app.launch()
    }

    override func tearDown() async throws {
        // An editor a failure left open: Discard, and Discard Changes if it asks. The editor is view
        // state no launch restores, but a dialog left up would hold this launch's screen.
        if let app, app.state == .runningForeground, editorBar.exists {
            editorButton("Discard").tap()
            findDialogButton("Discard Changes", within: 3)?.tap()
        }
        XCUIDevice.shared.orientation = .portrait
        app = nil
    }

    /// A swipe asks before the typed words are lost, and on an iPad a tap beside the sheet leaves the
    /// editor open with them; Discard asks too, and Discard Changes leaves the note as it was.
    func testASwipeAsksBeforeLosingTypedText() throws {
        openTheSeededNote()
        typeIntoTheBody()

        swipeTheEditorDown()
        requireTheDiscardDialog("after a swipe down")
        XCTAssertTrue(editorBar.exists, "The swipe closed the editor, and the typed words with it")
        attachScreenshot("Discard Changes? after a swipe")
        try closeTheDialogWithoutChoosing(Self.discardTitle)
        XCTAssertTrue(editorBar.exists, "Closing the dialog closed the editor")
        XCTAssertTrue(bodyHoldsTheTypedWords(), "Closing the dialog lost the typed words: \(bodyText())")

        if UIDevice.current.userInterfaceIdiom == .pad {
            // Beside the form sheet: the window's left edge, which the centred sheet does not reach. UIKit ignores a
            // touch outside a sheet it holds modal and reports no attempt, so the tap asks nothing and the editor stays
            // with the typed words (measured on the iPad Pro 13-inch (M5), iOS 27.0). A dialog, should a later iOS
            // report the tap, is closed without choosing.
            app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5)).tap()
            Thread.sleep(forTimeInterval: 2)
            attachScreenshot("The editor after a tap beside the sheet")
            if app.staticTexts[Self.discardTitle].exists { try closeTheDialogWithoutChoosing(Self.discardTitle) }
            XCTAssertTrue(editorBar.exists, "A tap beside the sheet closed the editor")
            XCTAssertTrue(bodyHoldsTheTypedWords(), "The tap beside the sheet lost the typed words: \(bodyText())")
        }

        editorButton("Discard").tap()
        requireTheDiscardDialog("after Discard")
        XCTAssertTrue(editorBar.exists, "Discard closed the editor before its dialog was answered")
        try dialogButton("Discard Changes").tap()
        XCTAssertTrue(editorBar.waitForNonExistence(timeout: Self.patience), "Discard Changes left the editor open")
        XCTAssertTrue(app.staticTexts[Self.seededBody].waitForExistence(timeout: Self.patience),
                      "All Notes no longer lists the note as it was. Texts: \(visibleTexts())")
        XCTAssertFalse(listShowsTheTypedWords(), "Discard Changes saved the typed words")
    }

    /// Nothing to lose closes on a swipe; Save closes without asking and keeps the words.
    func testAnUntouchedNoteClosesOnASwipeAndSaveAsksNothing() throws {
        openTheSeededNote()
        swipeTheEditorDown()
        XCTAssertTrue(editorBar.waitForNonExistence(timeout: Self.patience),
                      "A swipe did not close an untouched note's editor")
        XCTAssertFalse(app.staticTexts[Self.discardTitle].exists, "An untouched note asked before closing")

        openTheSeededNote()
        typeIntoTheBody()
        editorButton("Save").tap()
        XCTAssertTrue(editorBar.waitForNonExistence(timeout: Self.patience), "Save left the editor open")
        XCTAssertFalse(app.staticTexts[Self.discardTitle].exists, "Save asked \"\(Self.discardTitle)\"")
        XCTAssertTrue(waitUntil { self.listShowsTheTypedWords() },
                      "After Save, All Notes does not show the typed words. Texts: \(visibleTexts())")
    }

    /// Delete asks All Notes' question, and closing the dialog without deleting keeps the note.
    func testDeleteAsksAsAllNotesDoes() throws {
        openTheSeededNote()
        editorButton("Delete").tap()
        XCTAssertTrue(app.staticTexts["Delete Note?"].waitForExistence(timeout: Self.patience), """
            Delete did not ask "Delete Note?". Texts: \(visibleTexts())
            """)
        XCTAssertTrue(app.staticTexts["This note will be permanently deleted."].exists,
                      "The dialog does not say what All Notes' says. Texts: \(visibleTexts())")
        XCTAssertTrue(editorBar.exists, "Delete closed the editor before its dialog was answered")
        attachScreenshot("Delete Note?")
        try closeTheDialogWithoutChoosing("Delete Note?", cancel: "Cancel")
        XCTAssertTrue(editorBar.exists, "Closing the dialog closed the editor")

        editorButton("Delete").tap()
        try dialogButton("Delete").tap()
        XCTAssertTrue(editorBar.waitForNonExistence(timeout: Self.patience), "Delete left the editor open")
        XCTAssertTrue(app.staticTexts["No Notes"].waitForExistence(timeout: Self.patience),
                      "All Notes still lists the deleted note. Texts: \(visibleTexts())")
    }

    // MARK: - Steps

    /// Research ▸ All Notes ▸ the seeded note, which opens the editor.
    private func openTheSeededNote() {
        if !app.staticTexts[Self.seededBody].exists {
            XCTAssertTrue(navigator.select(.research, resolveTimeout: 15).tapped, "no Research tab")
            let allNotes = app.cells.containing(NSPredicate(format: "label BEGINSWITH 'All Notes'")).firstMatch
            let row = allNotes.exists ? allNotes
                : app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'All Notes'")).firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: Self.patience), "Research has no All Notes row")
            row.tap()
        }
        let seeded = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", Self.seededBody)).firstMatch
        XCTAssertTrue(seeded.waitForExistence(timeout: Self.patience),
                      "All Notes does not list the seeded note. Texts: \(visibleTexts())")
        seeded.tap()
        XCTAssertTrue(editorBar.waitForExistence(timeout: Self.patience), "The note's row did not open its editor")
    }

    /// Types into the note's body, then puts the keyboard away with the formatting bar's Done.
    private func typeIntoTheBody() {
        XCTAssertTrue(noteBody.waitForExistence(timeout: Self.patience), "The editor has no note body")
        noteBody.tap()
        noteBody.typeText(" " + Self.typed)
        let done = app.toolbars.buttons["Done"].firstMatch
        if done.waitForExistence(timeout: 5) { done.tap() }
        XCTAssertTrue(waitUntil { self.bodyHoldsTheTypedWords() }, "The body does not hold the typed words: \(bodyText())")
        Thread.sleep(forTimeInterval: 1)
    }

    /// Drags the sheet down by its navigation bar, far and fast, as a reader closes a sheet.
    private func swipeTheEditorDown() {
        let start = editorBar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 600)),
                    withVelocity: .fast, thenHoldForDuration: 0)
        Thread.sleep(forTimeInterval: 1.5)
    }

    /// Requires "Discard Changes?" to be up.
    private func requireTheDiscardDialog(_ when: String) {
        XCTAssertTrue(app.staticTexts[Self.discardTitle].waitForExistence(timeout: Self.patience), """
            No "\(Self.discardTitle)" \(when). Navigation bars: \
            \(app.navigationBars.allElementsBoundByIndex.map(\.identifier)); texts: \(visibleTexts())
            """)
    }

    /// Closes the dialog titled `titled` choosing nothing: its cancel button where an action sheet
    /// draws one, else a tap outside the popover, which is how iOS 27.0 shows it on iPhone and iPad.
    private func closeTheDialogWithoutChoosing(_ titled: String, cancel: String = "Keep Editing") throws {
        let title = app.staticTexts[titled].firstMatch
        let cancelButton = app.sheets.buttons[cancel].firstMatch
        if cancelButton.waitForExistence(timeout: 3) {
            cancelButton.tap()
        } else {
            let regions = app.otherElements.matching(identifier: "PopoverDismissRegion")
            XCTAssertGreaterThan(regions.count, 0, "The dialog has no \(cancel) and no popover to tap outside")
            // The region spans the window. At its left edge and 45% down, the tap falls below a popover
            // hanging from a bar button and above a keyboard the swipe left up: at the foot of the
            // window it met the iPhone 17's keyboard in one run of three (iOS 27.0) and closed nothing.
            regions.element(boundBy: regions.count - 1)
                .coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.45)).tap()
        }
        XCTAssertTrue(title.waitForNonExistence(timeout: Self.patience), "The dialog did not close")
        Thread.sleep(forTimeInterval: 1)
    }

    // MARK: - Queries

    /// The editor's navigation bar.
    private var editorBar: XCUIElement { app.navigationBars[Self.editorTitle] }

    /// The note's body: a rich-text view named for VoiceOver, and the editor's one text view.
    private var noteBody: XCUIElement {
        let named = app.textViews["Research note body"].firstMatch
        return named.exists ? named : app.textViews.firstMatch
    }

    /// The editor's toolbar button `label`, wherever its placement drew it: the navigation bar, or a
    /// toolbar.
    private func editorButton(_ label: String) -> XCUIElement {
        let inBar = editorBar.buttons[label].firstMatch
        if inBar.exists { return inBar }
        let inToolbar = app.toolbars.buttons[label].firstMatch
        return inToolbar.exists ? inToolbar : app.buttons[label].firstMatch
    }

    /// The body's text.
    private func bodyText() -> String { (noteBody.value as? String) ?? "" }

    /// Whether the body holds the typed words.
    private func bodyHoldsTheTypedWords() -> Bool { bodyText().contains(Self.typed) }

    /// Whether a row of All Notes shows the typed words.
    private func listShowsTheTypedWords() -> Bool {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", Self.typed)).count > 0
    }

    /// The open dialog's button `label`, in a popover, an action sheet or an alert, as the system drew it.
    private func dialogButton(_ label: String) throws -> XCUIElement {
        try XCTUnwrap(findDialogButton(label, within: Self.patience),
                      "The dialog offered no \"\(label)\" in a popover, sheet or alert")
    }

    /// The open dialog's button `label`, or `nil` when none appears within `timeout`. Asserts nothing,
    /// so `tearDown` can ask.
    private func findDialogButton(_ label: String, within timeout: TimeInterval) -> XCUIElement? {
        let candidates = [app.popovers.buttons[label], app.sheets.buttons[label], app.alerts.buttons[label]]
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let found = candidates.first(where: { $0.exists }) { return found }
            Thread.sleep(forTimeInterval: 0.25)
        } while Date() < deadline
        return nil
    }

    /// The labels of the texts on screen, for a failure's message.
    private func visibleTexts() -> [String] {
        app.staticTexts.allElementsBoundByIndex.prefix(30).map(\.label).filter { !$0.isEmpty }
    }

    /// Attaches a screenshot the reviewer keeps.
    private func attachScreenshot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Polls `condition` until it holds or `timeout` passes.
    private func waitUntil(_ timeout: TimeInterval = NoteEditorUnsavedChangesTests.patience,
                           _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return condition()
    }
}

// MARK: - AllNotesFollowsOtherDevicesTests

/// All Notes, left open, follows a note another device adds and a note another device deletes, with no
/// relaunch (R6a, F4).
///
/// In R6's pass the iPad's All Notes kept listing a note deleted on the Mac until the app was force-quit,
/// and the Mac showed a note the iPad's import brought back only after a restart (X2, X3). The screen
/// fetched a snapshot of its own when it appeared, and drew it in place of the one Research keeps fresh
/// from its live query, so nothing another device did reached it while it was open.
///
/// The test opens Research ▸ All Notes with the seeded note, then has the app add a note and delete the
/// seeded one through a second context on its container, as an iCloud import writes
/// (`FRUS_UI_TEST_NOTES_ON_SIGNAL`, each change on a Darwin signal), and requires the open list to follow
/// each. On the code before R6a it fails at the added note, which the open list never shows.
///
/// **Run it on iPhone 17 and iPad Pro 13-inch (M5)**, `OS=27.0`, allowing 600 s.
///
/// Version history:
///   1.0 — R6a (F4): initial implementation
@MainActor
final class AllNotesFollowsOtherDevicesTests: XCTestCase {
    /// Resolves tab destinations across every representation.
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    private var app: XCUIApplication!

    /// `UITestResearchSeeder.noteBody`, repeated because a UI-test target cannot import the app.
    private static let seededBody = "UI Test Research Note"
    /// `UITestResearchSeeder.otherDeviceNoteBody`.
    private static let otherDeviceBody = "A note from another device"
    /// `UITestBrowseSeams.Signal.addNote`'s name.
    private static let addSignal = "bottsywattsy.FRUS-Explorer.uitest.add-note"
    /// `UITestBrowseSeams.Signal.deleteNote`'s name.
    private static let deleteSignal = "bottsywattsy.FRUS-Explorer.uitest.delete-note"
    /// How long a wait for a launch's screens waits.
    private static let patience: TimeInterval = 30
    /// How long the open list has to follow a change: a CloudKit import reaches Research's query in
    /// well under this on a device, and the seam's save is immediate.
    private static let follow: TimeInterval = 10

    override func setUp() async throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_NOTE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_NOTES_ON_SIGNAL"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_DISABLE_ANIMATIONS"] = "1"
        app.launchArguments = UITestLaunch.arguments(startingOn: .research)
        app.launch()
    }

    override func tearDown() async throws {
        UITestPresentation.dismissAnyPresentation(in: app)
        app = nil
    }

    func testAllNotesFollowsANoteAddedAndANoteDeletedElsewhere() throws {
        XCTAssertTrue(navigator.select(.research, resolveTimeout: 15).tapped, "no Research tab")
        let allNotes = app.cells.containing(NSPredicate(format: "label BEGINSWITH 'All Notes'")).firstMatch
        let door = allNotes.exists ? allNotes
            : app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'All Notes'")).firstMatch
        XCTAssertTrue(door.waitForExistence(timeout: Self.patience), "Research has no All Notes row")
        door.tap()
        XCTAssertTrue(row(Self.seededBody).waitForExistence(timeout: Self.patience),
                      "All Notes does not list the seeded note. Texts: \(texts())")
        XCTAssertFalse(row(Self.otherDeviceBody).exists, "The other device's note is listed before it was added")

        XCTAssertEqual(notify_post(Self.addSignal), UInt32(NOTIFY_STATUS_OK),
                       "The system refused to post \(Self.addSignal), so no note was added")
        XCTAssertTrue(row(Self.otherDeviceBody).waitForExistence(timeout: Self.follow), """
            All Notes, left open, does not list the note another device added: it draws a snapshot of its own \
            in place of the one Research refreshes (R6, X3). Texts: \(texts())
            """)
        attachScreenshot("All Notes after another device added a note")

        XCTAssertEqual(notify_post(Self.deleteSignal), UInt32(NOTIFY_STATUS_OK),
                       "The system refused to post \(Self.deleteSignal), so no note was deleted")
        XCTAssertTrue(row(Self.seededBody).waitForNonExistence(timeout: Self.follow), """
            All Notes, left open, still lists the note another device deleted (R6, X2). Texts: \(texts())
            """)
        XCTAssertTrue(row(Self.otherDeviceBody).exists, "Deleting one note took the other device's note too")
        attachScreenshot("All Notes after another device deleted a note")
    }

    // MARK: - Steps

    /// The list's row whose text begins with `body`.
    private func row(_ body: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", body)).firstMatch
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

// MARK: - RailAtCompactWidthTests

/// On an iPad at compact width the reader's rail is the iPhone's tap-to-open sheet, and closing it leaves the rail on
/// for the next document read at full width (L19, #1919, IPA-6).
///
/// A document opened from Project Home reads inside a form sheet, which reports a compact width. Before L19 the rail's
/// `.inspector` there showed nothing with its toggle on; toggled off and on it came up as a sheet of its own over the
/// document, and that sheet's closing wrote the stored rail setting off, so the next document opened at full width had
/// no rail (the check of 2026-11-16, iPad Pro 13-inch (M5), iOS 27.0).
///
/// ## What the test drives
/// It opens the seeded note's document from Research at full width and turns the rail on there if it is off, so that
/// the stored setting is on: the setting is read as stored, never pinned by a launch argument, since an argument-domain
/// default cannot be overwritten and would hide the very write this guards against. Then Project Home ▸ Recently Read
/// opens the same document in the form sheet, where no rail may show; a tap on the toggle must open the rail as a sheet,
/// with its tiles; a swipe closes it. Back at full width the document must show its rail column again. Whether the
/// toggle reads on is not asked: on the code before L19 XCUI reported it unselected while it was drawn on, in the run's
/// own screenshot (iPad Pro 13-inch (M5), iOS 27.0).
///
/// ## Narrowing a window (R6a, F8)
/// `testNarrowingTheWindowWithTheRailOpenCrashesNothing` resizes the window by its corner grip, which needs Windowed
/// Apps, and skips, naming the setting, where the window does not narrow. It relaunches with the rail's five sections
/// open, turns to landscape, widens the window and opens the document with its rail column, then narrows the window to
/// its least width (375 pt, which iPadOS centres) and widens it again twelve times, requiring after each that the app
/// runs, the column is back and no sheet is left over the reader. On the code before R6a it fails at narrowing 1 on the
/// iPad Pro 13-inch (M5) under iOS 27.2: an empty form sheet is left over the reader, the sheet SwiftUI made of the open
/// `.inspector` as the width turned compact, which is the host 1.0 (1823) crashed in on the owner's iPad (R6, PD21).
/// That code never crashed in the simulator, in 24 narrowings, so the sheet is what the test sees, not the crash.
///
/// ## Running it
/// iPad only (an iPhone skips): name `FRUSExplorerUITests/RailAtCompactWidthTests` and run it on iPad Pro 13-inch (M5),
/// `OS=27.0`, allowing 600 s, and the narrowing test on the same iPad under `OS=27.2` in Windowed Apps, allowing 900 s.
/// On the code before L19 the first test fails at that tap, which there turned the stored setting off and opened
/// nothing.
///
/// Version history:
///   1.0 — L19 (#1919, IPA-6): initial implementation
///   1.1 — R6a (F8): `testNarrowingTheWindowWithTheRailOpenCrashesNothing`
///   1.2 — R6a (the Facets check): the corner grip's steps forward to `WindowedAppsGrip`, which
///          `FacetsAtCompactWidthTests` shares
@MainActor
final class RailAtCompactWidthTests: XCTestCase {
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    private var app: XCUIApplication!

    /// `UITestProjectSeeder.projectIdString`.
    private static let projectId = "14570000-B4B4-4B4B-8B4B-000000001457"
    /// The fixture's first document.
    private static let documentTitle = "UI Test Document One"
    private static let patience: TimeInterval = 30

    override func setUp() async throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_VOLUME"] = "frus1961-63v06"
        app.launchEnvironment["FRUS_UI_TEST_SEED_NOTE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_NOTE_DOCUMENT"] = "d1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_PROJECT"] = "1"
        // The reading mode as the reader leaves it, so that a document's open writes no rail setting of its own.
        app.launchArguments = UITestLaunch.arguments(startingOn: .research, activeProjectId: Self.projectId)
            + ["-frus.reading.defaultMode", "rememberLast"]
        app.launch()
    }

    override func tearDown() async throws {
        UITestPresentation.dismissAnyPresentation(in: app)
        XCUIDevice.shared.orientation = .portrait
        app = nil
    }

    func testARailClosedInProjectHomesSheetLeavesTheColumnOn() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad only: an iPhone's rail is always a sheet")

        // Full width: the seeded note's document, with its rail column on.
        openTheSeededDocumentFromResearch()
        if !railTiles.waitForExistence(timeout: 5) { try toggleRail() }
        XCTAssertTrue(railTiles.waitForExistence(timeout: Self.patience),
                      "The rail column did not show at full width, so the stored setting is not on")
        attachScreenshot("Full width, rail on")
        goBackToTheResearchRoot()

        // Compact width: the same document in Project Home's form sheet.
        let home = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Project Home")).firstMatch
        XCTAssertTrue(home.waitForExistence(timeout: Self.patience), "Research shows no Project Home row")
        home.tap()
        let visit = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", Self.documentTitle)).firstMatch
        let found = scrollUntilHittable(visit)
        XCTAssertTrue(found, "Project Home's Recently Read does not list \(Self.documentTitle)")
        visit.tap()
        let toggle = app.buttons["researchRailToggle"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: Self.patience), "The document in Project Home has no rail toggle")
        Thread.sleep(forTimeInterval: 2)
        attachScreenshot("Project Home's sheet, as it opens")
        // The toggle's state is not read: XCUI's `isSelected` was false on the code before L19 while the toggle was drawn
        // on, so it cannot tell on from off here. The tap below is the guard; there it turned the setting off.
        XCTAssertFalse(railTiles.exists, "The rail opened by itself at compact width")

        toggle.tap()
        XCTAssertTrue(railTiles.waitForExistence(timeout: Self.patience), "The toggle opened no rail at compact width")
        attachScreenshot("Project Home's sheet, rail sheet up")
        // Closed by a swipe on the rail's own header.
        let header = app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "Research")).firstMatch
        let grip = header.exists ? header : railTiles
        let start = grip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 700)),
                    withVelocity: .fast, thenHoldForDuration: 0)
        XCTAssertTrue(railTiles.waitForNonExistence(timeout: Self.patience), "A swipe did not close the rail's sheet")

        // Back out of Project Home and read the document at full width again.
        let back = app.buttons["BackButton"].firstMatch
        if back.waitForExistence(timeout: 5) { back.tap() }
        UITestPresentation.dismissAnyPresentation(in: app)
        openTheSeededDocumentFromResearch()
        XCTAssertTrue(railTiles.waitForExistence(timeout: Self.patience), """
            At full width the document opened with no rail column: closing the rail at compact width turned the \
            stored setting off.
            """)
        attachScreenshot("Full width again")
    }

    /// Narrowing a window with a document and its rail column open, and widening it again, crashes nothing (R6a, F8).
    ///
    /// 1.0 (1823) crashed on the owner's iPad as its window narrowed with the rail open, intermittently (R6, PD21), at
    /// SwiftUI's trap for a view reading an `@Environment` value its hierarchy was never given, in the sheet SwiftUI made
    /// of the open inspector. The guard is that sheet: on the code before R6a it was left up, empty, after narrowing 1.
    /// The window is resized by its corner grip, which needs Windowed Apps: a window that does not narrow skips, naming
    /// the setting.
    func testNarrowingTheWindowWithTheRailOpenCrashesNothing() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad only: an iPhone's rail is always a sheet")
        // Every section of the rail open, so that each is built when SwiftUI hosts the rail anew, and landscape, as the
        // owner's iPad was.
        app.terminate()
        app.launchArguments += Self.everySectionOpen
        app.launch()
        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 1.5)
        // XCUI reports SpringBoard's frame in portrait while the window's frame and the drags are in landscape, so the
        // screen's width is the frame's longer side (measured on the iPad Pro 13-inch (M5) under iOS 27.2).
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard").frame
        let screen = CGRect(x: 0, y: 0, width: max(springboard.width, springboard.height),
                            height: min(springboard.width, springboard.height))
        widenTheWindow(to: screen)
        closeTheGuideIfPresent()
        openTheSeededDocumentFromResearch()
        closeTheGuideIfPresent()
        if !railTiles.waitForExistence(timeout: 5) { try toggleRail() }
        XCTAssertTrue(railTiles.waitForExistence(timeout: Self.patience), """
            The rail column did not show in the widened window, so it is not at regular width and nothing below would \
            narrow it across the rail's change of presentation.
            """)
        attachScreenshot("Widened, rail column on")

        // Three speeds, since the owner saw the crash on some narrowings and not on others. None is fast: a fast corner
        // drag has crashed the simulator's own `backboardd` (the runbook's entry for this suite).
        let speeds: [CGFloat] = [300, 900, 2_000]
        for attempt in 1...Self.narrowings {
            let speed = speeds[(attempt - 1) % speeds.count]
            closeTheGuideIfPresent()
            let wide = app.windows.firstMatch.frame
            dragTheCornerGrip(of: wide, to: CGPoint(x: wide.minX + 120, y: wide.maxY - Self.gripInset), speed: speed)
            Thread.sleep(forTimeInterval: 1)
            XCTAssertEqual(app.state, .runningForeground,
                           "Narrowing \(attempt) of \(Self.narrowings), at \(Int(speed)) pt/s, crashed the app (F8)")
            let narrow = app.windows.firstMatch.frame
            if attempt == 1 {
                attachScreenshot("Narrowed")
                try XCTSkipUnless(narrow.width < wide.width - 200, """
                    The window kept its width (\(Int(wide.width)) pt, then \(Int(narrow.width)) pt), so this simulator \
                    is not in Windowed Apps: set Settings ▸ Multitasking & Gestures ▸ Windowed Apps and run again.
                    """)
            }

            widenTheWindow(to: screen, speed: speed)
            XCTAssertEqual(app.state, .runningForeground,
                           "Widening \(attempt) of \(Self.narrowings), at \(Int(speed)) pt/s, crashed the app (F8)")
            XCTAssertTrue(railTiles.waitForExistence(timeout: Self.patience), """
                After narrowing \(attempt) the widened window shows no rail column: the app was relaunched by the \
                system after a crash, or the narrowing wrote the stored setting off (L19, IPA-6).
                """)
            // The sheet SwiftUI makes of the open inspector as the width turns compact is the host the crash came from.
            // On the code before R6a it was left up after the narrowing, empty, a 580 × 660 pt form sheet over the
            // reader with its dismiss region behind it (iPad Pro 13-inch (M5), iOS 27.2, landscape).
            XCTAssertFalse(app.otherElements["PopoverDismissRegion"].waitForExistence(timeout: 2), """
                After narrowing \(attempt) of \(Self.narrowings) a sheet is left over the widened reader: the \
                inspector was shown as a sheet as the window narrowed (F8).
                """)
        }
        attachScreenshot("Widened again after \(Self.narrowings) narrowings")
    }

    // MARK: - Steps

    /// How many times F8's test narrows and widens the window.
    private static let narrowings = 12
    /// The rail's five sections, each pinned open (`ResearchRailView`'s accordion keys).
    private static let everySectionOpen = ["subjects", "summary", "notes", "tags", "collections"]
        .flatMap { ["-frus.document.researchPanel.\($0)", "YES"] }
    /// How far inside the window's bottom-right corner its grip is taken.
    private static let gripInset = WindowedAppsGrip.inset

    /// Drags the bottom-right corner grip of a window whose frame is `frame` to `end`, both in screen points.
    private func dragTheCornerGrip(of frame: CGRect, to end: CGPoint, speed: CGFloat = 1_500) {
        WindowedAppsGrip.drag(from: frame, to: end, speed: speed)
    }

    /// Pages through the FRUS Research Guide and closes it, if a launch's indexing raised it.
    private func closeTheGuideIfPresent() {
        WindowedAppsGrip.closeTheGuideIfPresent(in: app)
    }

    /// Widens the window to all the width right of its origin, and waits for the layout to settle.
    private func widenTheWindow(to screen: CGRect, speed: CGFloat = 1_500) {
        WindowedAppsGrip.widen(app, to: screen, speed: speed)
    }

    /// The rail's Cite tile, which shows wherever the rail does.
    private var railTiles: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Cite")).firstMatch
    }

    /// Research ▸ All Research Documents ▸ the seeded note, which reads the fixture's first document.
    private func openTheSeededDocumentFromResearch() {
        XCTAssertTrue(navigator.select(.research, resolveTimeout: 15).tapped, "no Research tab")
        let category = app.cells.containing(
            NSPredicate(format: "label BEGINSWITH 'All Research Documents'")).firstMatch
        XCTAssertTrue(category.waitForExistence(timeout: Self.patience), "no All Research Documents row")
        category.tap()
        let seeded = app.staticTexts["UI Test Research Note"].firstMatch
        XCTAssertTrue(seeded.waitForExistence(timeout: Self.patience), "the seeded note is not listed")
        seeded.tap()
        XCTAssertTrue(app.navigationBars[Self.documentTitle].waitForExistence(timeout: Self.patience),
                      "the seeded row did not open the fixture's first document")
    }

    /// Back to Research's root, where Project Home is.
    private func goBackToTheResearchRoot() {
        var backs = 0
        let back = app.buttons["BackButton"].firstMatch
        while back.exists && backs < 4 {
            back.tap()
            backs += 1
            Thread.sleep(forTimeInterval: 1)
        }
    }

    /// Turns the rail on from its toggle, in the toolbar or in its overflow menu.
    private func toggleRail() throws {
        let toggle = app.buttons["researchRailToggle"].firstMatch
        if toggle.exists && toggle.isHittable {
            toggle.tap()
            return
        }
        let more = app.navigationBars.buttons["More"].firstMatch
        XCTAssertTrue(more.waitForExistence(timeout: Self.patience), "The reader's toolbar has no rail toggle or overflow")
        more.tap()
        let item = app.buttons["Research panel"].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: Self.patience), "The toolbar's overflow has no Research panel")
        item.tap()
    }

    /// Scrolls the frontmost scroll view up until `element` is hittable, eight times at most.
    private func scrollUntilHittable(_ element: XCUIElement) -> Bool {
        for _ in 0..<8 {
            if element.exists && element.isHittable { return true }
            let window = app.windows.firstMatch
            window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
                .press(forDuration: 0.05, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)))
            Thread.sleep(forTimeInterval: 0.75)
        }
        return element.exists && element.isHittable
    }

    private func attachScreenshot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}

// MARK: - WindowedAppsGrip

/// Resizes the app's window in Windowed Apps by its bottom-right corner grip, as a reader does, for
/// `RailAtCompactWidthTests` (R6a, F8) and `FacetsAtCompactWidthTests` (R6a, the Facets check).
///
/// Version history:
///   1.0 — R6a: lifted from `RailAtCompactWidthTests` for a second suite
@MainActor
enum WindowedAppsGrip {
    /// How far inside the window's bottom-right corner its grip is taken.
    static let inset: CGFloat = 6

    /// The screen in the drags' frame. XCUI reports SpringBoard's frame in portrait while the window's frame and the
    /// drags are in landscape, so its width is the frame's longer side (iPad Pro 13-inch (M5), iOS 27.2).
    static var landscapeScreen: CGRect {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard").frame
        return CGRect(x: 0, y: 0, width: max(springboard.width, springboard.height),
                      height: min(springboard.width, springboard.height))
    }

    /// Drags the bottom-right corner grip of a window whose frame is `frame` to `end`, both in screen points.
    static func drag(from frame: CGRect, to end: CGPoint, speed: CGFloat = 1_500) {
        let origin = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            .coordinate(withNormalizedOffset: .zero)
        let grip = origin.withOffset(CGVector(dx: frame.maxX - inset, dy: frame.maxY - inset))
        grip.press(forDuration: 0.3, thenDragTo: origin.withOffset(CGVector(dx: end.x, dy: end.y)),
                   withVelocity: XCUIGestureVelocity(speed), thenHoldForDuration: 0.3)
    }

    /// Narrows `app`'s window to its least width (375 pt, which iPadOS centres) by dragging its grip to 120 pt right of
    /// its left edge.
    static func narrow(_ app: XCUIApplication, speed: CGFloat) {
        let wide = app.windows.firstMatch.frame
        drag(from: wide, to: CGPoint(x: wide.minX + 120, y: wide.maxY - inset), speed: speed)
    }

    /// Drags the window's corner grip to the screen's right edge, which widens a window in Windowed Apps to all the
    /// width right of its origin, and waits for the layout to settle.
    static func widen(_ app: XCUIApplication, to screen: CGRect, speed: CGFloat = 1_500) {
        let frame = app.windows.firstMatch.frame
        drag(from: frame, to: CGPoint(x: screen.maxX - 2, y: frame.maxY - inset), speed: speed)
        Thread.sleep(forTimeInterval: 1)
    }

    /// Pages through the FRUS Research Guide and closes it, if a launch's indexing raised it (`IndexingGuideSheetModifier`
    /// opens it once a session, 0.6 s after a queue of two or more volumes begins), as `VolumeRemovalTests` does.
    static func closeTheGuideIfPresent(in app: XCUIApplication) {
        let start = app.buttons["Start exploring"]
        let next = app.buttons["Next"]
        let firstPage = app.staticTexts["The Official Record of American Foreign Policy"]
        guard start.exists || (next.exists && firstPage.exists) else { return }
        var pages = 0
        while !start.exists, pages < 20 {
            guard next.waitForExistence(timeout: 2), next.isHittable else { break }
            next.tap()
            pages += 1
            Thread.sleep(forTimeInterval: 0.8)
        }
        if start.waitForExistence(timeout: 2), start.isHittable { start.tap() }
        _ = start.waitForNonExistence(timeout: 3)
    }
}

// MARK: - FacetsAtCompactWidthTests

/// A Year staged in Search's Facets panel stays staged and unapplied as an iPad window narrows and widens with the
/// panel open (R6a, the Facets check; the owner's "Fix before R7").
///
/// On an iPad, Facets is a trailing `.inspector`. As the window narrows to compact width, SwiftUI closes it through its
/// binding's setter, and on the code before R6a that setter took every close for the reader's own and applied what
/// Years or Volumes held staged, IPH-3's rule for the sheet's Done, a swipe and the binoculars menu's Facets: in R6a's
/// check a staged *1962* was applied at the first narrowing, and the results then read *Narrowed by 1962*. A narrowing
/// is not the reader's close, so it applies nothing.
///
/// The first test stages a Year, narrows the window by its corner grip and widens it again three times, at three
/// speeds. After each it requires the app running, no *Narrowed by* row, the results still listed, and the Year still
/// staged (the panel's pinned bar), opening Facets from the binoculars menu if the widened window shows it closed. The
/// second narrows the window first, opens Facets as the sheet SwiftUI makes of the inspector at compact width, stages a
/// Year and closes the sheet with a swipe, which must apply it: the reader's own close, which the first test's rule must
/// not take away. Both need Windowed Apps and skip, naming the setting, where the window does not narrow.
///
/// **Run it on the iPad Pro 13-inch (M5) under `OS=27.2`, in Windowed Apps**, allowing 900 s.
///
/// Version history:
///   1.0 — R6a (the Facets check): initial implementation
@MainActor
final class FacetsAtCompactWidthTests: XCTestCase {
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    private var app: XCUIApplication!

    private static let patience: TimeInterval = 30

    override func tearDown() async throws {
        UITestPresentation.dismissAnyPresentation(in: app)
        // A window left narrow is restored narrow at the next launch, which then cannot be narrowed further.
        if let app, app.state == .runningForeground {
            WindowedAppsGrip.widen(app, to: WindowedAppsGrip.landscapeScreen)
        }
        XCUIDevice.shared.orientation = .portrait
        app?.terminate()
        app = nil
        try await super.tearDown()
    }

    func testNarrowingKeepsAStagedYearUnapplied() throws {
        let screen = try launchWidenedOnSearch()
        searchUntilTheFixtureIsListed()
        openFacets()
        let year = stageTheFirstYear()
        attachScreenshot("Widened, \(year) staged")

        for (index, speed) in [CGFloat(300), 900, 2_000].enumerated() {
            let attempt = index + 1
            WindowedAppsGrip.closeTheGuideIfPresent(in: app)
            let wide = app.windows.firstMatch.frame
            WindowedAppsGrip.narrow(app, speed: speed)
            Thread.sleep(forTimeInterval: 1.5)
            XCTAssertEqual(app.state, .runningForeground, "Narrowing \(attempt), at \(Int(speed)) pt/s, crashed the app")
            if attempt == 1 {
                let narrow = app.windows.firstMatch.frame
                attachScreenshot("Narrowed")
                try XCTSkipUnless(narrow.width < wide.width - 200, """
                    The window kept its width (\(Int(wide.width)) pt, then \(Int(narrow.width)) pt), so this simulator \
                    is not in Windowed Apps: set Settings ▸ Multitasking & Gestures ▸ Windowed Apps and run again.
                    """)
            }
            WindowedAppsGrip.widen(app, to: screen, speed: speed)
            Thread.sleep(forTimeInterval: 1.5)
            attachScreenshot("Widened after narrowing \(attempt)")
            XCTAssertFalse(app.staticTexts["Narrowed by"].exists, """
                After narrowing \(attempt) the staged \(year) was applied: the results read Narrowed by. SwiftUI's close \
                of the inspector as the window narrowed was taken for the reader's own (IPH-3).
                """)
            XCTAssertTrue(fixtureRows.firstMatch.exists, "After narrowing \(attempt) the results are no longer listed")
            if !yearsHeader.exists { openFacets() }
            XCTAssertTrue(stagedBar.waitForExistence(timeout: 10),
                          "After narrowing \(attempt) \(year) is no longer staged in Facets")
        }
    }

    /// At compact width Facets is the sheet SwiftUI makes of the inspector, and a swipe that closes it is the reader's
    /// own close, which applies what is staged (IPH-3). The narrowing's close above must not take that away.
    func testASwipeClosingTheCompactSheetAppliesTheStagedYear() throws {
        _ = try launchWidenedOnSearch()
        let wide = app.windows.firstMatch.frame
        WindowedAppsGrip.narrow(app, speed: 900)
        Thread.sleep(forTimeInterval: 1.5)
        let narrow = app.windows.firstMatch.frame
        try XCTSkipUnless(narrow.width < wide.width - 200, """
            The window kept its width (\(Int(wide.width)) pt, then \(Int(narrow.width)) pt), so this simulator is not \
            in Windowed Apps: set Settings ▸ Multitasking & Gestures ▸ Windowed Apps and run again.
            """)
        searchUntilTheFixtureIsListed()
        openFacets()
        let year = stageTheFirstYear()
        attachScreenshot("Compact, \(year) staged in Facets' sheet")
        yearsHeader.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)))
        XCTAssertTrue(yearsHeader.waitForNonExistence(timeout: Self.patience), "A downward drag did not close Facets")
        attachScreenshot("Compact, Facets closed by a swipe")
        XCTAssertTrue(app.staticTexts["Narrowed by"].waitForExistence(timeout: Self.patience), """
            A swipe closing Facets' sheet at compact width did not apply the staged \(year): a reader's own close \
            applies what is staged (IPH-3).
            """)
    }

    // MARK: - Steps

    /// Launches on Search with the fixture volume and the Meaning seam, in landscape, the window widened to all the
    /// screen right of its origin; returns the screen in the drags' frame.
    private func launchWidenedOnSearch() throws -> CGRect {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad only: an iPhone's Facets is always a sheet")
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_VOLUME"] = "frus1961-63v06"
        app.launchEnvironment["FRUS_UI_TEST_SEED_MEANING"] = "1"
        app.launchArguments = UITestLaunch.arguments(startingOn: .search)
            + ["-frus.semantic.autoDownloadShards", "<false/>"]
        app.launch()
        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 1.5)
        let screen = WindowedAppsGrip.landscapeScreen
        // A window the last launch left narrow comes back narrow and centred, and once the first widening after the
        // relaunch left it so (375 pt, measured): widen until the window spans most of the screen.
        for _ in 1...3 where app.windows.firstMatch.frame.width < screen.width * 0.6 {
            WindowedAppsGrip.closeTheGuideIfPresent(in: app)
            WindowedAppsGrip.widen(app, to: screen)
        }
        WindowedAppsGrip.closeTheGuideIfPresent(in: app)
        // The iPad's tab sidebar restores the tab it last showed, whatever the launch asked for.
        XCTAssertTrue(navigator.select(.search, resolveTimeout: 15).tapped, "No Search tab")
        return screen
    }

    /// The fixture's documents, as listed.
    private var fixtureRows: XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "UI Test Document"))
    }

    /// Facets' Years section header, which shows wherever the panel does.
    private var yearsHeader: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Years")).firstMatch
    }

    /// The bar pinned to the panel's foot while Years or Volumes holds a staged choice (IPH-3).
    private var stagedBar: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "facets.selection.bar").firstMatch
    }

    /// Searches the fixture's phrase until its documents are listed: the fixture is indexed during launch, and a
    /// search that runs first finds nothing.
    private func searchUntilTheFixtureIsListed() {
        let field = app.searchFields.firstMatch
        for _ in 1...5 where !fixtureRows.firstMatch.exists {
            WindowedAppsGrip.closeTheGuideIfPresent(in: app)
            XCTAssertTrue(field.waitForExistence(timeout: Self.patience), "The Search tab shows no search field")
            field.tap()
            if let typed = field.value as? String, !typed.isEmpty, typed != field.placeholderValue {
                field.buttons["Clear text"].firstMatch.tap()
                field.tap()
            }
            field.typeText("\"Synthetic UI-test content\"\n")
            _ = fixtureRows.firstMatch.waitForExistence(timeout: 12)
        }
        XCTAssertTrue(fixtureRows.firstMatch.exists, "The fixture's documents are not listed")
    }

    /// Opens Facets from the binoculars menu.
    private func openFacets() {
        let examine = app.descendants(matching: .any).matching(identifier: "search.actions.examine").firstMatch
        XCTAssertTrue(examine.waitForExistence(timeout: Self.patience), "The actions bar has no Examine menu")
        examine.tap()
        let facets = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Facets")).firstMatch
        XCTAssertTrue(facets.waitForExistence(timeout: Self.patience), "The Examine menu has no Facets")
        facets.tap()
        XCTAssertTrue(yearsHeader.waitForExistence(timeout: Self.patience), "Facets did not open")
    }

    /// Discloses Years and chooses its first bucket, which stages it; returns the bucket's label.
    private func stageTheFirstYear() -> String {
        yearsHeader.tap()
        let bucket = app.buttons.matching(NSPredicate(format: "label MATCHES %@", "^(1[89]|20)[0-9]{2}.*")).firstMatch
        XCTAssertTrue(bucket.waitForExistence(timeout: Self.patience), "Years lists no year")
        let label = bucket.label
        bucket.tap()
        XCTAssertTrue(stagedBar.waitForExistence(timeout: 10), "Choosing \(label) staged nothing")
        return label
    }

    private func attachScreenshot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}

// MARK: - AddToCollectionAnnouncementTests

/// Add to Collection says what it did to VoiceOver: "Added to “UI Test Unattached Collection”" (L19, #1919, A11Y-3).
///
/// Until L19 the picker drew a green check that the sheet's own closing took away 0.6 s later, and said nothing, so a
/// VoiceOver reader heard no outcome at all. The test opens the seeded note's document, `d2`, which the seeded
/// collection does not hold, and the rail's Collections ▸ Add to Collection. With VoiceOver on it moves VoiceOver's
/// cursor to the collection's row and double-taps, as a VoiceOver reader activates a row: with VoiceOver on a single
/// tap only moves its cursor (`SearchResultVoiceOverTests`). It then reads VoiceOver's speech four times a second for
/// eight seconds and requires the announcement among it, which the sheet's closing and VoiceOver's move to the screen
/// beneath must not cut off.
///
/// **Run it alone, on a simulator shut down before it**, on iPhone 17 and iPad Pro 13-inch (M5), both `OS=27.0`, with
/// 600 s a test: under Xcode 27.2, once the VoiceOver service's speech has been read, `disable()` leaves VoiceOver on,
/// and any later test of the run meets its cursor (`SearchResultVoiceOverTests`' entry in the runbook). It needs
/// iOS 27's VoiceOver service and skips below it. The fixture is `FRUS_UI_TEST_SEED_VOLUME`'s volume, the seeded note
/// on its `d2` (`FRUS_UI_TEST_SEED_NOTE_DOCUMENT`) and `FRUS_UI_TEST_SEED_PROJECT`'s collection, which holds `d1`.
///
/// Version history:
///   1.0 — L19 (#1919, A11Y-3): initial implementation
@MainActor
final class AddToCollectionAnnouncementTests: XCTestCase {
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    private var app: XCUIApplication!

    /// `UITestProjectSeeder.collectionName`.
    private static let collectionName = "UI Test Unattached Collection"
    /// The fixture's second document, which the seeded collection does not hold.
    private static let documentTitle = "UI Test Document Two"
    /// What the picker says once the document is in the collection.
    private static let announcement = "Added to “\(collectionName)”"
    private static let patience: TimeInterval = 30

    override func setUp() async throws {
        continueAfterFailure = false
        // A run that ended inside a test could have left VoiceOver on.
        turnVoiceOverOff()
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_DISABLE_ANIMATIONS"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_VOLUME"] = "frus1961-63v06"
        app.launchEnvironment["FRUS_UI_TEST_SEED_NOTE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_NOTE_DOCUMENT"] = "d2"
        app.launchEnvironment["FRUS_UI_TEST_SEED_PROJECT"] = "1"
        app.launchArguments = UITestLaunch.arguments(startingOn: .research)
        app.launch()
    }

    override func tearDown() async throws {
        turnVoiceOverOff()
        UITestPresentation.dismissAnyPresentation(in: app)
        app?.terminate()
        app = nil
    }

    func testAnAddIsSaidToVoiceOver() throws {
        guard #available(iOS 27.0, *) else { throw XCTSkip("Listens through iOS 27's VoiceOver service") }
        openTheSeededDocument()
        openAddToCollection()
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", Self.collectionName)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: Self.patience), """
            Add to Collection does not list \(Self.collectionName). Buttons: \(labels(of: .button))
            """)

        let voiceOver = XCUIDevice.shared.voiceOverService
        try voiceOver.enable()
        RunLoop.current.run(until: Date().addingTimeInterval(2))
        var passed: [String] = []
        var onTheRow = false
        // The cursor stops on the last element and says it again, so a row not met in thirty steps is not on screen.
        for _ in 1...30 {
            let spoken = try voiceOver.moveForward().utterance
            if spoken.hasPrefix(Self.collectionName) { onTheRow = true; break }
            passed.append(spoken)
        }
        guard onTheRow else {
            try voiceOver.disable()
            XCTFail("VoiceOver never reached the \(Self.collectionName) row. It spoke: \(passed)")
            return
        }
        // A VoiceOver reader's double tap activates the element under VoiceOver's cursor.
        row.doubleTap()
        var heard: [String] = []
        for _ in 1...32 where !heard.contains(where: { $0.contains(Self.announcement) }) {
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
            let spoken = try voiceOver.currentSpeech().utterance
            if heard.last != spoken { heard.append(spoken) }
        }
        try voiceOver.disable()
        XCTAssertTrue(heard.contains { $0.contains(Self.announcement) }, """
            VoiceOver did not say "\(Self.announcement)" within eight seconds of the row's activation. It said: \(heard)
            """)
    }

    // MARK: - Steps

    /// Research ▸ All Research Documents ▸ the seeded note, which reads the fixture's second document.
    private func openTheSeededDocument() {
        XCTAssertTrue(navigator.select(.research, resolveTimeout: 15).tapped, "no Research tab")
        let category = app.cells.containing(
            NSPredicate(format: "label BEGINSWITH 'All Research Documents'")).firstMatch
        let row = category.exists ? category
            : app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'All Research Documents'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: Self.patience), "no All Research Documents row")
        row.tap()
        let seeded = app.staticTexts["UI Test Research Note"].firstMatch
        XCTAssertTrue(seeded.waitForExistence(timeout: Self.patience), "the seeded note is not listed")
        seeded.tap()
        XCTAssertTrue(app.navigationBars[Self.documentTitle].waitForExistence(timeout: Self.patience),
                      "the seeded row did not open the fixture's second document")
    }

    /// The rail's Collections ▸ Add to Collection, the rail opened first where it is not showing.
    private func openAddToCollection() {
        let add = app.buttons["Add to Collection"].firstMatch
        if !railHeader.waitForExistence(timeout: 5) {
            let toggle = app.buttons["researchRailToggle"].firstMatch
            XCTAssertTrue(toggle.waitForExistence(timeout: Self.patience), "The reader has no rail toggle")
            toggle.tap()
            XCTAssertTrue(railHeader.waitForExistence(timeout: Self.patience), "The toggle opened no rail")
        }
        if !add.waitForExistence(timeout: 3) {
            let collections = app.scrollViews.buttons.matching(
                NSPredicate(format: "label BEGINSWITH 'Collections'")).firstMatch
            XCTAssertTrue(collections.waitForExistence(timeout: Self.patience), """
                The rail has no Collections accordion. Buttons: \(labels(of: .button))
                """)
            collections.tap()
        }
        XCTAssertTrue(add.waitForExistence(timeout: Self.patience), "The Collections accordion has no Add to Collection")
        add.tap()
    }

    /// The rail's Cite tile, which shows wherever the rail does (`RailAtCompactWidthTests`' sign of the rail).
    private var railHeader: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Cite")).firstMatch
    }

    /// Turns VoiceOver off if a test left it on.
    private func turnVoiceOverOff() {
        guard #available(iOS 27.0, *) else { return }
        let voiceOver = XCUIDevice.shared.voiceOverService
        if voiceOver.isEnabled { try? voiceOver.disable() }
    }

    /// The labels of the elements of `type` on screen, for a failure message.
    private func labels(of type: XCUIElement.ElementType) -> [String] {
        app.descendants(matching: type).allElementsBoundByIndex.prefix(40).map(\.label).filter { !$0.isEmpty }
    }
}
