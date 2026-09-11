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
final class ResearchReadingStaysInTabTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        // The seeded note gives the Research list one row to open (UITestResearchSeeder).
        app.launchEnvironment["FRUS_UI_TEST_SEED_NOTE"] = "1"
        app.launchArguments = ["-hasCompletedOnboarding", "1"]
        app.launch()
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
        app = nil
    }

    // MARK: - iPhone

    func testBackFromAResearchDocumentReturnsToTheResearchList() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom == .pad,
                      "iPhone only — the iPad tests below cover both iPad layouts")

        let researchTab = app.tabBars.firstMatch.buttons["Research"].firstMatch
        XCTAssertTrue(researchTab.waitForExistence(timeout: 15), "no Research tab")
        researchTab.tap()

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
        XCTAssertTrue(researchTab.isSelected, "the Research tab is no longer selected")
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
        let candidates = [app.tabBars.firstMatch.buttons["Research"].firstMatch,
                          app.buttons["Research"].firstMatch,
                          app.cells["Research"].firstMatch]
        guard let tab = candidates.first(where: { $0.waitForExistence(timeout: 5) }) else {
            XCTFail("no Research control in any tab-bar representation")
            throw XCTestError(.failureWhileWaiting)
        }
        tab.tap()
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
/// `FRUS_UI_TEST_SEED_VOLUME` writes a three-document volume (`d1…d3`, "UI Test Document One/Two/Three"),
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
final class ResearchReadingDepthTests: XCTestCase {

    private var app: XCUIApplication!

    /// Carried by every assertion about the surviving page, so an A/B can confirm a failure happened
    /// there and not at a precondition.
    private static let lostPage = "PAGE-TURN LOST ACROSS THE TWO-PANE SWAP"

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_VOLUME"] = "frus1961-63v06"
        app.launchEnvironment["FRUS_UI_TEST_SEED_NOTE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_NOTE_DOCUMENT"] = "d1"
        app.launchArguments = ["-hasCompletedOnboarding", "1",
                               "-frus.document.researchPanel.visible", "NO",
                               "-frus.reading.edgeTapNavigation", "YES",
                               "-frus.reading.defaultMode", "rememberLast"]
        app.launch()
    }

    override func tearDownWithError() throws {
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
        let candidates = [app.tabBars.firstMatch.buttons["Research"].firstMatch,
                          app.buttons["Research"].firstMatch,
                          app.cells["Research"].firstMatch]
        guard let tab = candidates.first(where: { $0.waitForExistence(timeout: 5) }) else {
            XCTFail("no Research control in any tab-bar representation")
            throw XCTestError(.failureWhileWaiting)
        }
        tab.tap()
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
