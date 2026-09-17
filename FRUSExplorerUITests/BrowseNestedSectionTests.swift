// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import XCTest

/// #1301 — a **nested** Browse section loads its documents without leaving the tab.
///
/// ## The defect
/// Reported against `frus1945Malta` ▸ *III. The Yalta Conference* ▸ *8. Minutes and related
/// documents* ▸ *11. Post-conference documents*: the document list showed "Loading documents…"
/// with a spinner indefinitely, and switching tabs and returning made it appear.
///
/// The mechanism is view reuse, and it is only reachable on iPad. At 820 pt or more of Browse
/// content width `BrowserView.twoPaneLayout` runs, and its `detailPane` **renders** the deepest
/// path element in place — "The detail pane RENDERS the path; it does not push it. No second
/// navigation container" (`BrowserView.swift`). The router it calls, `levelView`, is a
/// `Group { switch level }` chosen deliberately so SwiftUI can see the concrete view type and
/// preserve `@State` identity. So a `.compilation → .compilation` step takes the **same** switch
/// branch at the same structural position: SwiftUI updates the existing `CompilationView` with
/// the new `section` instead of creating one. `CompilationView`'s only unconditional load trigger
/// was a **bare** `.task`, which is scoped to appear/disappear and does not re-run on an update,
/// so the new section's cache entry was never written — and the spinner branch tested
/// `compilationDocuments[cacheKey] == nil`, the *absence of a result*, not a loading fact. There
/// was no error row, no retry and no `.refreshable`, so a missing entry had no terminal state at
/// all. Switching tabs away and back re-runs the bare `.task`, which is the reported workaround.
///
/// iPhone is immune for a structural reason, not an accidental one: `stackLayout` pushes each
/// level through `.navigationDestination`, which builds a new view per push, so the bare `.task`
/// ran every time. ``testNestedSectionsLoadOnPushPath`` is that control.
///
/// ## What this suite asserts, and why each assertion is load-bearing
/// The fixture (`UITestVolumeSeeder`) mirrors Malta's measured shape — compilation → chapter →
/// subchapter, where the middle rung holds **no documents of its own**:
///
///  1. **The first compilation level still loads.** `.volume → .compilation` crosses switch
///     branches and has always worked. It is the control that isolates the *nesting* step from
///     the fixture, the seeding, and the indexing — all three of which would fail this first.
///  2. **The chapter reaches "No documents in this section."** That string is reachable *only*
///     through a completed load (`documentRows(docs:)` renders it for an empty array), so it is
///     the fingerprint that separates "loaded and empty" from "never loaded". At `75e0fff2` this
///     is where the run fails: the chapter sits on the spinner forever.
///  3. **The subchapter's own document rows appear.** A second reuse step, one level deeper,
///     proving the fix is not a one-off for the first nested level.
///
/// Nothing here switches tabs between the taps and the assertions. That is the whole point: the
/// tab round-trip is the *workaround*, and a test that used it would pass on the broken build.
///
/// ## Measured
/// A/B on one pinned device, `-only-testing` held identical on both sides, iPad Pro 13-inch (M5),
/// iOS 26.3:
///  - **RED at `75e0fff28c131de69bde38e726872a91a18002c3`**: `testNestedSectionsLoadInTwoPane`
///    fails at assertion 2 — the chapter never leaves "Loading documents…" (60 s), while
///    assertion 1 passed in the same run.
///  - **GREEN with the fix** (`.task(id: cacheKey)` plus the per-section load state).
/// `testNestedSectionsLoadOnPushPath` passes on iPhone 17 (iOS 26.5) **before and after**, which
/// is the non-regression half.
///
/// Version history:
///   1.0 — #1301: initial implementation
///   1.1 — #1301 round 2: assertion 1 also requires the empty-state label to be ABSENT where the
///          section has documents. Measured: a composite mutant that drew the pre-load state as
///          the row list, with #1301's bare `.task` reinstated in full, PASSED assertion 2 — so
///          the oracle "that string is reachable only through a completed load" was a property of
///          one line in `CompilationView`, not of the app
//
// Note: the iOS 26 SDK isolates the XCUI APIs to the main actor, so this file emits the same
// "main actor-isolated … nonisolated context" warnings the other UI suites do (see the note at
// the head of `UIObstructionTests` for why `@MainActor` on the class is not the fix).
final class BrowseNestedSectionTests: XCTestCase {

    /// The manifest volume the fixture is written for — the same one `CompilationDocumentsTests`
    /// and `TwoPaneDocumentTests` seed, so one `UITestVolumeSeeder` fixture serves all three.
    private static let seededVolumeId = "frus1961-63v06"

    /// The compilation `<head>` in the seeded fixture. Must match `UITestVolumeSeeder`.
    private static let compilationTitle = "UI Test Compilation"

    /// The first document `<head>` directly inside the compilation. Must match
    /// `UITestVolumeSeeder`.
    private static let firstDocumentTitle = "UI Test Document One"

    /// The nested chapter's `<head>` — the middle rung, which holds no documents of its own.
    /// Must match `UITestVolumeSeeder.chapterTitle`.
    private static let chapterTitle = "UI Test Chapter"

    /// The nested subchapter's `<head>` — the leaf that holds the nested documents. Must match
    /// `UITestVolumeSeeder.subchapterTitle`.
    private static let subchapterTitle = "UI Test Subchapter"

    /// The first nested document's `<head>`. Must match
    /// `UITestVolumeSeeder.nestedDocumentTitles`.
    ///
    /// Deliberately not a superstring of ``firstDocumentTitle``: every row query here is
    /// `CONTAINS[c]`, so "Nested UI Test Document One" would have matched both.
    private static let firstNestedDocumentTitle = "UI Test Nested Document One"

    /// `CompilationView`'s spinner label — asserted **absent**, never waited on. A spinner that
    /// is merely slow and a spinner that is permanent look identical to a `waitForExistence`.
    private static let loadingLabel = "Loading documents…"

    /// `CompilationView`'s empty-list label. Reachable only through a completed load.
    private static let emptyLabel = "No documents in this section."

    var app: XCUIApplication!

    /// Resolves tab destinations across every representation, including the floating iPad bar when
    /// it has paged a tab off screen. Shared with every other suite.
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_VOLUME"] = Self.seededVolumeId
        app.launchArguments = UITestLaunch.arguments() + [
            // Collapses Browse to the seeded volume alone, so the walk below needs no title
            // matching against real corpus data.
            "-frus.filterDownloadedOnly", "YES",
        ]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Element queries

    private var subseriesRow: XCUIElement {
        // Built fresh on each access: NSPredicate is not Sendable and the XCUI APIs are
        // main-actor-isolated, so a hoisted predicate would be sent twice out of this
        // nonisolated context — a hard error under Swift 6.
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Subseries '")).firstMatch
    }

    private var volumeRow: XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Kennedy-Khrushchev'")).firstMatch
    }

    private func row(containing text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch
    }

    /// Swipes up until `element` is present and hittable. SwiftUI `List` is lazy, so a row below
    /// the fold is absent from the accessibility tree, not merely invisible.
    private func scrollDownUntil(_ element: XCUIElement, attempts: Int) {
        for _ in 0..<attempts {
            if element.exists && element.isHittable { return }
            app.swipeUp(velocity: .slow)
            Thread.sleep(forTimeInterval: 0.4)
        }
    }

    // MARK: - The shared walk

    /// Browse → subseries → volume → compilation, indexing on the way if this is a cold run.
    ///
    /// Fails with a distinct message at each step: the causes are different and reporting them
    /// as one is how `UIObstructionTests` lost three investigations.
    private func navigateToSeededCompilation() {
        guard let destination = TabDestination(rawValue: "Browse") else {
            XCTFail("'Browse' is not one of MainTabView's five tabs")
            return
        }
        _ = navigator.select(destination).tapped

        // #1051 B-1 (root 2a): the subseries list moved one tap deep behind the root's tile.
        let subseriesTile = app.buttons["browse.root.subseriesTile"].firstMatch
        XCTAssertTrue(subseriesTile.waitForExistence(timeout: 15),
                      "The Browse root's Subseries tile did not appear — this suite cannot reach "
                          + "a compilation at all.")
        subseriesTile.tap()
        Thread.sleep(forTimeInterval: 0.8)

        XCTAssertTrue(subseriesRow.waitForExistence(timeout: 15),
                      "No subseries row with filterDownloadedOnly=YES — the fixture volume was "
                          + "probably not seeded (look for a [UITestVolumeSeeder] line in the "
                          + "app log).")
        subseriesRow.tap()
        Thread.sleep(forTimeInterval: 0.8)

        XCTAssertTrue(volumeRow.waitForExistence(timeout: 10),
                      "The seeded volume's row did not appear in the subseries list")
        volumeRow.tap()
        Thread.sleep(forTimeInterval: 0.8)

        let compilationRow = row(containing: Self.compilationTitle)
        scrollDownUntil(compilationRow, attempts: 8)
        XCTAssertTrue(compilationRow.waitForExistence(timeout: 15),
                      "The seeded volume's compilation row did not appear — `loadVolumeStructure` "
                          + "parses the XML directly, so this step does not depend on indexing.")
        compilationRow.tap()
        Thread.sleep(forTimeInterval: 0.8)

        // Cold run: the seeded volume is on disk but not yet indexed.
        let indexNow = app.buttons["Index Now"]
        if indexNow.waitForExistence(timeout: 5), indexNow.isEnabled { indexNow.tap() }
    }

    /// The three assertions, shared by both idioms so the iPhone control exercises exactly the
    /// same oracle as the iPad reproduction — only the layout underneath differs.
    private func assertNestedSectionsLoad(idiom: String) {
        // ── 1. The control: the FIRST compilation level ────────────────────────────────────
        // `.volume → .compilation` crosses `levelView`'s switch branches, so this has always
        // built a fresh view and always loaded. If it fails, the fixture, the seeding or the
        // indexing is at fault and nothing below says anything about #1301.
        XCTAssertTrue(
            row(containing: Self.firstDocumentTitle).waitForExistence(timeout: 60),
            "[\(idiom)] No document rows at the FIRST compilation level. This step is the "
                + "control — it crosses a switch branch and builds a new view — so a failure here "
                + "is the fixture, the seeding or the indexing, not #1301."
        )
        // The empty-state label is the oracle assertion 2 rests on, and this is what keeps that
        // oracle honest. The first compilation level HOLDS three documents, so "No documents in
        // this section." must never appear here — a pre-load state drawn as the row list renders
        // that string for a section whose rows have simply not arrived yet, which would make
        // assertion 2 satisfiable with no load at all (measured: a composite mutant that drew the
        // pre-load state as the row list passed assertion 2 on a build carrying #1301 in full).
        XCTAssertFalse(
            app.staticTexts[Self.emptyLabel].exists,
            "[\(idiom)] '\(Self.emptyLabel)' is on screen at the FIRST compilation level, which "
                + "holds three documents. A section that has rows is claiming it has none — the "
                + "pre-load or in-flight state is being drawn as the document list."
        )

        // ── 2. The reuse step: compilation → compilation ───────────────────────────────────
        let chapterRow = row(containing: Self.chapterTitle)
        scrollDownUntil(chapterRow, attempts: 8)
        XCTAssertTrue(chapterRow.waitForExistence(timeout: 15),
                      "[\(idiom)] The nested chapter row is absent from the compilation's "
                          + "Sections list — the fixture's branch was not parsed.")
        chapterRow.tap()

        XCTAssertTrue(
            app.staticTexts[Self.emptyLabel].waitForExistence(timeout: 60),
            "[\(idiom)] #1301: the nested chapter never reached a terminal state. "
                + "'\(Self.emptyLabel)' is reachable ONLY through a completed load, so its "
                + "absence means the load never ran. On iPad the detail pane renders the deepest "
                + "level in place, so this `.compilation → .compilation` step REUSES the "
                + "CompilationView instance and a bare `.task` — one with no `id:` — never "
                + "re-runs for the new section. Spinner still on screen: "
                + "\(app.staticTexts[Self.loadingLabel].exists)."
        )
        XCTAssertFalse(
            app.staticTexts[Self.loadingLabel].exists,
            "[\(idiom)] The chapter reached its empty state but the spinner is still on screen "
                + "beside it — the load state and the rendered branch disagree."
        )

        // ── 3. One level deeper: a second reuse step ───────────────────────────────────────
        let subchapterRow = row(containing: Self.subchapterTitle)
        scrollDownUntil(subchapterRow, attempts: 8)
        XCTAssertTrue(subchapterRow.waitForExistence(timeout: 15),
                      "[\(idiom)] The nested subchapter row is absent from the chapter's "
                          + "Sections list")
        subchapterRow.tap()

        XCTAssertTrue(
            row(containing: Self.firstNestedDocumentTitle).waitForExistence(timeout: 60),
            "[\(idiom)] #1301: the nested subchapter never rendered its document rows — the "
                + "second `.compilation → .compilation` step. The subchapter holds two documents "
                + "in the fixture. Spinner still on screen: "
                + "\(app.staticTexts[Self.loadingLabel].exists); empty-state label on screen: "
                + "\(app.staticTexts[Self.emptyLabel].exists) (which would mean the rows were "
                + "loaded against the wrong section key rather than not loaded at all)."
        )
        XCTAssertFalse(
            app.staticTexts[Self.loadingLabel].exists,
            "[\(idiom)] The subchapter's rows rendered but the spinner is still beside them."
        )
    }

    // MARK: - iPad: the reproduction

    /// The two-pane reproduction. **Red at `75e0fff2`, green with the fix.**
    func testNestedSectionsLoadInTwoPane() throws {
        #if canImport(UIKit)
        try XCTSkipUnless(
            UIDevice.current.userInterfaceIdiom == .pad,
            "iPad-only: the in-place detail render needs a pad idiom and 820pt of content width"
        )
        #else
        throw XCTSkip("UIKit-only test")
        #endif

        guard let destination = TabDestination(rawValue: "Browse") else {
            XCTFail("'Browse' is not one of MainTabView's five tabs")
            return
        }
        _ = navigator.select(destination).tapped

        let window = app.windows.firstMatch.frame
        print("[#1301] window=\(window)")

        // The two-pane placeholder is the layout probe, borrowed from `TwoPaneDocumentTests`.
        // Skipping on its absence rather than asserting a width lets this run on ANY iPad and
        // report honestly which side of the 820 pt gate that device falls on — a narrow Split
        // View or Slide Over falls through to `stackLayout`, where the defect does not arise.
        try XCTSkipUnless(
            app.staticTexts["Choose a Subseries"].waitForExistence(timeout: 10),
            "Browse is a single column at \(window.width)pt — this device is below the two-pane "
                + "gate, so the in-place detail render does not run here"
        )

        navigateToSeededCompilation()
        assertNestedSectionsLoad(idiom: "iPad two-pane")
    }

    // MARK: - iPhone: the non-regression control

    /// The push path must keep working. `stackLayout` gives every pushed level its own view, so
    /// the bare `.task` already ran on each push and iPhone never showed the defect; keying the
    /// task must not change that.
    func testNestedSectionsLoadOnPushPath() throws {
        #if canImport(UIKit)
        try XCTSkipUnless(
            UIDevice.current.userInterfaceIdiom == .phone,
            "iPhone-only: this is the `.navigationDestination` push path, which iPad only takes "
                + "below the two-pane gate"
        )
        #else
        throw XCTSkip("UIKit-only test")
        #endif

        navigateToSeededCompilation()
        assertNestedSectionsLoad(idiom: "iPhone push")
    }
}
