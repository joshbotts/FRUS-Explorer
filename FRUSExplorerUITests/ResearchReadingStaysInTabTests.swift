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
///          the chain fixed — a page-turned or cross-referenced position — has no runtime test; the
///          UI-test store holds no document to page through.
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
    /// guards the first document and the list beneath it — not the page-turned or cross-referenced
    /// position the host-owned chain exists to keep. That has no runtime test yet.
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
