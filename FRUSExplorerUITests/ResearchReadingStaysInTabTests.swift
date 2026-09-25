// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import XCTest

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
