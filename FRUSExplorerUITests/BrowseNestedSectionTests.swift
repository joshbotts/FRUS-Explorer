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
///  4. **A section whose `<head>` repeats its parent's shows its OWN row** (round 2). The fixture's
///     deepest rung is a twin of the section it sits in, which is the one shape that distinguishes
///     a load keyed on the section's cache key from one keyed on `section.title` — a mutation that
///     passed every assertion above. 0 of 744 local TEI volumes publish that shape, so this pins
///     the contract rather than reproducing a defect.
///
/// Nothing here switches tabs between the taps and the assertions. That is the whole point: the
/// tab round-trip is the *workaround*, and a test that used it would pass on the broken build.
///
/// ## The other reused level (round 3)
/// ``testASecondVolumeFromRootSearchLoadsItsOwnStructure`` is the same mechanism one level up, and
/// it is iPad-only for the same reason. `CorpusView`'s root search calls `select(_:)`, which
/// **assigns** the path, so on regular-width iPad — where that search sits in the list pane beside
/// the detail — choosing a second volume updates the `VolumeView` already on screen. It is the only
/// keyed level besides the compilation whose self-to-self step a reader can take today.
///
/// ## The states no ordinary run can reach (round 2, and one more in round 4)
/// Five further tests run on **either** idiom, because none of them is about two-pane reuse.
/// Each asks `UITestBrowseSeams` for a state the app cannot otherwise be put in, and each covers a
/// piece of #1301 that a mutation sweep found undefended:
///  - ``testFailedSectionShowsAReadableErrorRowAndRetryLoadsIt`` — nothing in the app can be made
///    to fail a document load, so the error row, its sentence and its **Retry** had never been
///    rendered by any test. A one-shot injected throw covers the row, the readability of its
///    message, and that Retry asks for *this* section.
///  - ``testIndexingFromTheCompilationFillsItsDocumentList`` — the `.onChange(of: vm.isIndexing)`
///    kick. Three suites carry an "Index Now" step that has never once been taken, because boot
///    indexes every downloaded volume it finds; the cold seam makes that state explicit and the
///    walk REQUIRES the button rather than tolerating its absence.
///  - ``testALoadInFlightShowsTheSpinnerAndNotAnEmptyList`` — a load held open, because a real one
///    finishes in milliseconds and the row it draws meanwhile had never been asserted at all.
///  - ``testAPipelineArrivingLateFillsTheOpenCompilation`` — R-9's back-fill kick, driven by
///    holding the pipeline back past the compilation's first render.
///  - ``testAnIndexStartedElsewhereFillsTheOpenCompilation`` (round 4) — the
///    `.onChange(of: appState.currentIndexingProgress)` kick, driven by finishing the cold
///    fixture's download while its compilation is open. Rounds 2 and 3 called this kick unreachable;
///    it is the only loader on the ordinary download → open → browse path.
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
///   1.1 — #1301 round 2: assertion 4 steps into a section whose head repeats its parent's, and
///          four new tests drive the failure row, the in-flight spinner and two of the three
///          indexing kicks through `UITestBrowseSeams` — the in-flight one being what catches the
///          composite mutant that drew the pre-load state as the row list, which PASSED assertion
///          2 on a build carrying #1301 in full. (Assertion 1 also gained an empty-label check;
///          round 3 corrected what that check is credited with — see the comment beside it.) The
///          launch moves out of `setUp`, because those four need different app states to exist
///   1.2 — #1301 round 3: ``testASecondVolumeFromRootSearchLoadsItsOwnStructure`` walks the other
///          reachable self-to-self step — `.volume → .volume`, taken from the corpus root's search
///          on regular-width iPad — so `VolumeView`'s key is pinned by a walk rather than by an
///          assertion about the key function nothing was checked to call
///   1.3 — #1301 round 4: ``testAnIndexStartedElsewhereFillsTheOpenCompilation`` drives the third
///          kick — the one every index not started from the compilation depends on, the automatic
///          index after a download included — and ``navigateToSeededCompilation(requireIndexNow:tapIndexNow:)``
///          can require "Index Now" without tapping it. The launch helper's count of tests needing
///          a seam, stale since round 2 ("three of the five"), now says five of eight
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

    /// The `<head>` of the document inside the fixture's twin section — the third rung, whose own
    /// `<head>` repeats its parent's. Must match `UITestVolumeSeeder.twinDocumentTitle`.
    private static let twinDocumentTitle = "UI Test Twin Document"

    /// The `sectionId` of the subchapter, named here because the failure seam takes a section id
    /// rather than a title. Must match the `xml:id` in `UITestVolumeSeeder.fixtureXML(volumeId:)`.
    private static let subchapterSectionId = "uitestsubchapter"

    /// A second manifest volume, deliberately **not** downloaded, for the `.volume → .volume` walk
    /// (#1301 round 3).
    ///
    /// It is the volume #1301 was reported against, which is incidental here — what matters is
    /// that it is in the bundled manifest (so the root search finds it), that nothing has seeded
    /// it (so `VolumeView` draws "Download Required" and `loadVolumeStructure` no-ops, leaving
    /// `volumeStructures` with no entry for it), and that both its id and a fragment of its title
    /// match exactly one of the 553 catalogue entries — measured against `manifest.json`.
    private static let undownloadedVolumeId = "frus1945Malta"

    /// The label `VolumeView` shows for a volume that is not on disk.
    private static let downloadRequiredLabel = "Download Required"

    /// `CompilationView`'s spinner label — asserted **absent**, never waited on. A spinner that
    /// is merely slow and a spinner that is permanent look identical to a `waitForExistence`.
    private static let loadingLabel = "Loading documents…"

    /// The failure row's headline, and a distinctive fragment of the sentence under it.
    private static let failureHeadline = "Could not load this section’s documents."
    private static let failureDetailFragment = "could not read this section"

    /// The banner a compilation shows while its volume has no usable index.
    private static let indexRequiredLabel = "Index Required"
    private static let indexUnavailableLabel = "Search Index Unavailable"

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
    }

    /// Launches, with any seam this test needs added to the common environment.
    ///
    /// The launch is per TEST rather than in `setUp` because five of the eight tests below need a
    /// different app state to exist at all — a document load that throws or is held open, a volume
    /// nothing has indexed, a pipeline that arrives late, a download that finishes while a
    /// compilation is open — and each is requested by its own launch key. See `UITestBrowseSeams`.
    ///
    /// - Parameter seams: Extra launch-environment entries.
    private func launch(seams: [String: String] = [:]) {
        for (key, value) in seams { app.launchEnvironment[key] = value }
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
    ///
    /// - Parameters:
    ///   - requireIndexNow: When `true`, the volume MUST arrive unindexed and the "Index Now" button
    ///     must be there and enabled — the cold-seam tests assert the post-indexing path and would
    ///     pass vacuously on a volume that was already indexed. `false` tolerates the button's
    ///     absence, which is what every other run finds.
    ///   - tapIndexNow: With `requireIndexNow`, whether to tap the button once it is found. `false`
    ///     leaves the volume to be indexed from somewhere else, which is the scenario the progress
    ///     kick exists for (round 4).
    private func navigateToSeededCompilation(requireIndexNow: Bool = false,
                                             tapIndexNow: Bool = true) {
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
        if requireIndexNow {
            XCTAssertTrue(indexNow.waitForExistence(timeout: 20),
                          "This test asked for a COLD volume (FRUS_UI_TEST_COLD_SEEDED_VOLUME) and "
                              + "the compilation is not offering 'Index Now' — so the volume is "
                              + "indexed, the seam did not take, and everything below would pass "
                              + "without exercising the post-indexing path at all.")
            XCTAssertTrue(indexNow.isEnabled,
                          "'Index Now' is disabled, which means the view model has no indexing "
                              + "pipeline — a different state from an unindexed volume.")
            if tapIndexNow { indexNow.tap() }
        } else if indexNow.waitForExistence(timeout: 5), indexNow.isEnabled {
            indexNow.tap()
        }
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
        // WHAT THIS HOLDS, stated as narrowly as it is true (corrected in round 3). A completed
        // load and the empty-state label must never be on screen together: this section has three
        // documents, and "No documents in this section." beside its rows would mean the list and
        // the label disagree about the same cache entry.
        //
        // It is NOT the guard on assertion 2's oracle, and round 2's comment here said it was.
        // This is an immediate `.exists` query sequenced AFTER a `waitForExistence` on the first
        // row has returned; under the mutant that drew the pre-load state as the row list, the
        // label is on screen exactly while the cache entry is nil and is replaced by the rows in
        // the same render pass that makes that wait return — so the window closes before this
        // line runs. The guard on the oracle is
        // `testALoadInFlightShowsTheSpinnerAndNotAnEmptyList`, which holds a load open for eight
        // seconds precisely so the string can be seen, and the unit test
        // `eachPresentationDrawsItsOwnRow`, which pins the mapping one case at a time. The
        // measured kill for that mutant is recorded against the in-flight test at its first
        // assertion, not against this one.
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

        // ── 4. A third reuse step, into a section with ITS PARENT'S TITLE ──────────────────
        // The fixture's deepest rung is a subchapter whose <head> is byte-identical to the
        // subchapter it sits inside. That is the one shape that tells a load keyed on the
        // section's cache key from one keyed on `section.title`: the title does not change across
        // this step, so a title key leaves the task un-re-run and this section shows the previous
        // one's state. Measured over the local corpus, 0 of 744 volumes publish that shape today —
        // so this pins the contract rather than reproducing a defect, and it is the only assertion
        // in either target that can.
        let twinRow = row(containing: Self.subchapterTitle)
        scrollDownUntil(twinRow, attempts: 8)
        XCTAssertTrue(twinRow.waitForExistence(timeout: 15),
                      "[\(idiom)] The twin section's row is absent from the subchapter's Sections "
                          + "list — the fixture's third rung was not parsed.")
        twinRow.tap()

        XCTAssertTrue(
            row(containing: Self.twinDocumentTitle).waitForExistence(timeout: 60),
            "[\(idiom)] #1301: the twin section never rendered its own document row. Its title is "
                + "identical to its parent's, so a load task keyed on the TITLE rather than on the "
                + "section's cache key does not re-run here and this section goes on showing the "
                + "previous one's rows. Spinner still on screen: "
                + "\(app.staticTexts[Self.loadingLabel].exists); the parent's rows still on "
                + "screen: \(row(containing: Self.firstNestedDocumentTitle).exists)."
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

        launch()

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

    // MARK: - iPad: the OTHER level that is reused in place

    /// A second volume chosen from the corpus root's search loads **its own** structure.
    ///
    /// ## Why this walk exists, and why it is the one that had to be a walk
    /// `VolumeView`'s structure task is keyed on `BrowseLoadKey.volume(_:)`, and until round 3 that
    /// key had no gate but an assertion that the *function* varies with its argument — which goes
    /// on passing while nothing calls it. Round 1 recorded `.volume → .volume` as unreachable and
    /// round 2 corrected that: `CorpusView`'s root search calls `BrowserViewModel.select(_:)`,
    /// which **assigns** `navigationPath` rather than appending to it, and on regular-width iPad
    /// that list pane stands beside a detail pane which may already be showing a volume. So this is
    /// the one keyed level besides the compilation whose self-to-self step a reader can take today,
    /// and a behavioural test is the only thing that can see the key being used.
    ///
    /// ## The oracle, and why the fixture's constant section titles do not spoil it
    /// The first volume is **not downloaded**, so `loadVolumeStructure` returns at its
    /// `isVolumeDownloaded` guard and `vm.volumeStructures` gains no entry for it: there is no
    /// stale structure on screen to be mistaken for the second volume's. The second volume is the
    /// seeded fixture, and `volumeStructureSection` reads `vm.volumeStructures[volume.volumeId]` —
    /// keyed by the CURRENT volume — so with a bare `.task` the step leaves that dictionary
    /// untouched and the pane holds "Loading structure…" for the life of the process. That is
    /// #1301's screen, one level up from where it was reported.
    func testASecondVolumeFromRootSearchLoadsItsOwnStructure() throws {
        #if canImport(UIKit)
        try XCTSkipUnless(
            UIDevice.current.userInterfaceIdiom == .pad,
            "iPad-only: on iPhone `select(_:)` assigns a path that `stackLayout` PUSHES, which "
                + "builds a fresh VolumeView, and the root search is no longer on screen to make "
                + "a second choice from"
        )
        #else
        throw XCTSkip("UIKit-only test")
        #endif

        launch()

        guard let destination = TabDestination(rawValue: "Browse") else {
            XCTFail("'Browse' is not one of MainTabView's five tabs")
            return
        }
        _ = navigator.select(destination).tapped

        // The same layout probe the reproduction uses: below the two-pane gate the list pane is
        // not on screen beside the detail, so the step this test is about cannot be taken.
        try XCTSkipUnless(
            app.staticTexts["Choose a Subseries"].waitForExistence(timeout: 10),
            "Browse is a single column at \(app.windows.firstMatch.frame.width)pt — below the "
                + "two-pane gate the root search is replaced by the pushed level"
        )

        let field = app.textFields["browse.root.searchField"]
        XCTAssertTrue(field.waitForExistence(timeout: 15),
                      "The Browse root's volume search field (browse.root.searchField) is absent, "
                          + "so this walk cannot reach a volume at all.")

        // ── 1. A volume that is NOT downloaded ─────────────────────────────────────────────
        field.tap()
        field.typeText(Self.undownloadedVolumeId)

        let undownloadedRow = row(containing: "Malta")
        XCTAssertTrue(undownloadedRow.waitForExistence(timeout: 15),
                      "No search result for '\(Self.undownloadedVolumeId)'. The field reads "
                          + "'\(field.value as? String ?? "")' — the root search matches on title "
                          + "or volume id, and exactly one of the 553 manifest entries matches "
                          + "this one.")
        undownloadedRow.tap()

        XCTAssertTrue(
            app.staticTexts[Self.downloadRequiredLabel].waitForExistence(timeout: 20),
            "The first volume did not open on its 'Download Required' placeholder, so this run is "
                + "not standing on a `.volume` level and the step below would prove nothing."
        )

        // ── 2. …and a second one, chosen WITHOUT leaving that level ────────────────────────
        // `select(_:)` assigns the path, so the detail pane takes the same `levelView` switch
        // branch at the same structural position: SwiftUI UPDATES the VolumeView it already has.
        let clear = app.buttons["Clear volume search"]
        XCTAssertTrue(clear.waitForExistence(timeout: 10),
                      "The root search field's clear control is absent, so the second query "
                          + "cannot be typed.")
        clear.tap()
        field.tap()
        field.typeText(Self.seededVolumeId)

        XCTAssertTrue(volumeRow.waitForExistence(timeout: 15),
                      "No search result for the seeded volume '\(Self.seededVolumeId)'. The field "
                          + "reads '\(field.value as? String ?? "")'.")
        volumeRow.tap()

        let compilationRow = row(containing: Self.compilationTitle)
        scrollDownUntil(compilationRow, attempts: 8)
        XCTAssertTrue(
            compilationRow.waitForExistence(timeout: 60),
            "#1301: the SECOND volume never rendered its own structure. Its section list comes "
                + "from `vm.volumeStructures[volume.volumeId]`, which only "
                + "`loadVolumeStructure(for:)` writes, and the only thing that calls it on this "
                + "path is `VolumeView`'s structure task. A bare `.task` — one with no `id:` — "
                + "does not re-run when the detail pane updates this view with a new volume, so "
                + "the dictionary keeps no entry for this one and the pane holds 'Loading "
                + "structure…' for ever. 'Download Required' still on screen: "
                + "\(app.staticTexts[Self.downloadRequiredLabel].exists) (which would mean the "
                + "second choice never landed at all)."
        )
    }

    // MARK: - The terminal state, on either idiom

    /// A load that fails draws the error row, its sentence reads as English, and **Retry** asks
    /// for *this* section.
    ///
    /// Runs on any device: the failure row is not a two-pane phenomenon. Nothing in the app can be
    /// made to fail a document load, which is why no suite has ever rendered this row and why a
    /// mutation that replaced it with the permanent spinner — #1301's own screen — passed every
    /// test the branch shipped. `FRUS_UI_TEST_FAIL_DOCUMENT_LOAD` throws ONCE, where the real
    /// query throws; the retry then runs against a healthy index, which is what lets one test
    /// assert both halves of a terminal state.
    func testFailedSectionShowsAReadableErrorRowAndRetryLoadsIt() throws {
        launch(seams: ["FRUS_UI_TEST_FAIL_DOCUMENT_LOAD": Self.subchapterSectionId])
        navigateToSeededCompilation()

        // Down to the subchapter, whose first load the seam fails.
        let chapterRow = row(containing: Self.chapterTitle)
        scrollDownUntil(chapterRow, attempts: 8)
        XCTAssertTrue(chapterRow.waitForExistence(timeout: 30), "the nested chapter row is absent")
        chapterRow.tap()
        let subchapterRow = row(containing: Self.subchapterTitle)
        scrollDownUntil(subchapterRow, attempts: 8)
        XCTAssertTrue(subchapterRow.waitForExistence(timeout: 30),
                      "the nested subchapter row is absent")
        subchapterRow.tap()

        // 1. The row exists at all.
        XCTAssertTrue(
            app.staticTexts[Self.failureHeadline].waitForExistence(timeout: 30),
            "A failed load must draw the error row. Spinner on screen: "
                + "\(app.staticTexts[Self.loadingLabel].exists); empty-state label: "
                + "\(app.staticTexts[Self.emptyLabel].exists). A failure drawn as the spinner is "
                + "#1301's screen exactly — a terminal state that looks like a slow load, with no "
                + "way to ask again."
        )
        XCTAssertFalse(app.staticTexts[Self.loadingLabel].exists,
                       "the error row is up and the spinner is still beside it")

        // 2. The sentence under it is a sentence.
        let systemFallback = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'be completed' OR label CONTAINS 'IndexingError'")
        )
        // `map(\.label)` cannot be written here: the XCUI APIs are main-actor-isolated under the
        // iOS 26 SDK and a key path to `label` is a hard error from this nonisolated context.
        var fallbackLabels: [String] = []
        for element in systemFallback.allElementsBoundByIndex { fallbackLabels.append(element.label) }
        XCTAssertEqual(systemFallback.count, 0,
                       "The failure row is showing Foundation's fallback, which names a Swift "
                           + "module and an enum ordinal: \(fallbackLabels)")
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] %@", Self.failureDetailFragment)
            ).firstMatch.exists,
            "The failure row has no readable explanation under its headline."
        )

        // 3. Retry asks for THIS section, and the seam is spent, so its rows arrive.
        let retry = app.buttons["Retry"]
        XCTAssertTrue(retry.exists, "The error row has no Retry control, and it is the only exit "
                          + "from a failed section — this view has no `.refreshable`.")
        retry.tap()

        XCTAssertTrue(
            row(containing: Self.firstNestedDocumentTitle).waitForExistence(timeout: 60),
            "Retry did not bring back THIS section's rows. Error row still on screen: "
                + "\(app.staticTexts[Self.failureHeadline].exists). A button whose action is "
                + "empty, and one wired to a neighbouring section, both look like this."
        )
        XCTAssertFalse(app.staticTexts[Self.failureHeadline].exists,
                       "the rows arrived but the error row is still above them")
    }

    /// A load in flight shows the spinner — and does **not** show an empty document list.
    ///
    /// Real loads finish in milliseconds, so the row a load in flight produces has never been
    /// asserted by anything: by the time a UI test can look, the documents are up. That is how the
    /// mutation which drew the pre-load and in-flight states as the *document list* survived every
    /// suite, and it is not cosmetic — "No documents in this section." is the oracle
    /// ``assertNestedSectionsLoad``'s second assertion rests on, and a section that merely has not
    /// loaded yet must never be able to say it. Held open for eight seconds, both halves are
    /// ordinary assertions.
    func testALoadInFlightShowsTheSpinnerAndNotAnEmptyList() throws {
        launch(seams: ["FRUS_UI_TEST_DELAY_DOCUMENT_LOAD": "\(Self.subchapterSectionId):8"])
        navigateToSeededCompilation()

        let chapterRow = row(containing: Self.chapterTitle)
        scrollDownUntil(chapterRow, attempts: 8)
        XCTAssertTrue(chapterRow.waitForExistence(timeout: 30), "the nested chapter row is absent")
        chapterRow.tap()
        let subchapterRow = row(containing: Self.subchapterTitle)
        scrollDownUntil(subchapterRow, attempts: 8)
        XCTAssertTrue(subchapterRow.waitForExistence(timeout: 30),
                      "the nested subchapter row is absent")
        subchapterRow.tap()

        XCTAssertTrue(
            app.staticTexts[Self.loadingLabel].waitForExistence(timeout: 6),
            "A load held open for 8 s is not showing '\(Self.loadingLabel)'. Empty-state label on "
                + "screen instead: \(app.staticTexts[Self.emptyLabel].exists) — which is a section "
                + "with two documents claiming it has none, and would make the empty label "
                + "reachable without any load at all."
        )
        XCTAssertFalse(
            app.staticTexts[Self.emptyLabel].exists,
            "The spinner and the empty-list label are on screen together while the load runs."
        )

        XCTAssertTrue(
            row(containing: Self.firstNestedDocumentTitle).waitForExistence(timeout: 60),
            "and the rows arrive once the load is let go"
        )
        XCTAssertFalse(app.staticTexts[Self.loadingLabel].exists,
                       "the rows arrived and the spinner is still beside them")
    }

    // MARK: - The three indexing kicks, each driven

    /// A cold volume, indexed from the compilation itself, fills its document list without
    /// leaving the screen.
    ///
    /// This is the `.onChange(of: vm.isIndexing)` kick. The keyed `.task` declined while the
    /// volume was unindexed and will not re-run — its key has not changed — so this kick is the
    /// only thing that asks for the rows once the run finishes.
    ///
    /// The cold state is requested rather than hoped for: boot indexes every downloaded volume it
    /// finds, twice over, so three suites carry an "Index Now" step that has never once been
    /// taken. `requireIndexNow` makes a run that is not cold a failure instead of a pass.
    func testIndexingFromTheCompilationFillsItsDocumentList() throws {
        launch(seams: ["FRUS_UI_TEST_COLD_SEEDED_VOLUME": "1"])
        navigateToSeededCompilation(requireIndexNow: true)

        XCTAssertTrue(
            row(containing: Self.firstDocumentTitle).waitForExistence(timeout: 120),
            "After indexing from this screen the document rows never arrived, and nothing was "
                + "navigated away from. 'Index Required' still on screen: "
                + "\(app.staticTexts[Self.indexRequiredLabel].exists); spinner: "
                + "\(app.staticTexts[Self.loadingLabel].exists)."
        )
        XCTAssertFalse(app.staticTexts[Self.indexRequiredLabel].exists,
                       "the rows are up and the Index Required banner is still above them")
    }

    /// A pipeline that arrives after the compilation is already on screen fills its document list.
    ///
    /// This is R-9's back-fill kick, `.onChange(of: vm.indexingPipeline == nil)`. Without a
    /// pipeline `isIndexed` answers `false`, so the keyed task declines and the banner reads
    /// "Search Index Unavailable"; the task will not re-run afterwards, because `cacheKey` has not
    /// changed. The assertion on the banner is what makes this test non-vacuous: it proves the
    /// pipeline really was missing when the level rendered.
    func testAPipelineArrivingLateFillsTheOpenCompilation() throws {
        launch(seams: ["FRUS_UI_TEST_DELAY_PIPELINE": "25"])
        navigateToSeededCompilation()

        XCTAssertTrue(
            app.staticTexts[Self.indexUnavailableLabel].waitForExistence(timeout: 20),
            "The compilation opened with a pipeline already attached, so this run never reached "
                + "the state the back-fill kick exists for and everything below it would pass "
                + "whatever that kick did. Raise FRUS_UI_TEST_DELAY_PIPELINE."
        )

        XCTAssertTrue(
            row(containing: Self.firstDocumentTitle).waitForExistence(timeout: 90),
            "The pipeline was back-filled while this compilation was on screen and its rows never "
                + "arrived. 'Search Index Unavailable' still on screen: "
                + "\(app.staticTexts[Self.indexUnavailableLabel].exists); spinner: "
                + "\(app.staticTexts[Self.loadingLabel].exists)."
        )
    }

    /// A cold compilation fills its document list when an index started ELSEWHERE finishes — the
    /// automatic index after a download above all — with nothing on screen touched (round 4).
    ///
    /// This is the `.onChange(of: appState.currentIndexingProgress)` kick. Rounds 2 and 3 accepted it
    /// as unreachable, calling it the kick for a bulk index started from Settings. It is the kick for
    /// every index not started from the compilation: `currentIndexingProgress` goes `nil` on each
    /// pipeline `.complete`, the automatic post-download index included, while `vm.isIndexing` —
    /// kick 1's trigger — is set only by "Index Now". So on the ordinary download → open → browse
    /// path it is the ONLY loader: the keyed task declined on the unindexed volume and its key will
    /// not change, and the pipeline already exists, so the back-fill kick cannot fire either.
    ///
    /// `FRUS_UI_TEST_FINISH_SEEDED_DOWNLOAD_AFTER` hands the cold fixture to `DownloadManager`'s
    /// completion router while this test stands on the compilation, which runs the app's own
    /// `onVolumeDownloaded` closure — nothing below that call is simulated. "Index Now" is required
    /// and then deliberately NOT tapped: tapping it is ``testIndexingFromTheCompilationFillsItsDocumentList``.
    func testAnIndexStartedElsewhereFillsTheOpenCompilation() throws {
        // The same closure also fetches the finished volume's semantic shard, which has nothing to
        // do with this screen; the reader's own "download vectors automatically" switch, off, keeps
        // the run offline. `<false/>` rather than `NO`: the app reads the key with `as? Bool`, and
        // the argument domain hands `NO` over as a string. The key must match
        // `SettingsKeys.autoDownloadSemanticShards` — a UI suite cannot reference app constants.
        app.launchArguments += ["-frus.semantic.autoDownloadShards", "<false/>"]
        launch(seams: ["FRUS_UI_TEST_COLD_SEEDED_VOLUME": "1",
                       "FRUS_UI_TEST_FINISH_SEEDED_DOWNLOAD_AFTER": "30"])
        navigateToSeededCompilation(requireIndexNow: true, tapIndexNow: false)

        XCTAssertTrue(
            app.staticTexts[Self.indexRequiredLabel].exists,
            "The cold compilation is not showing '\(Self.indexRequiredLabel)', so the download "
                + "finished before this test reached it and everything below would pass whatever "
                + "the progress kick did. Raise FRUS_UI_TEST_FINISH_SEEDED_DOWNLOAD_AFTER."
        )

        // Touch nothing. The seam finishes the download, the app's own post-download closure
        // indexes the volume, and the progress kick is the only thing left that asks for the rows.
        XCTAssertTrue(
            row(containing: Self.firstDocumentTitle).waitForExistence(timeout: 120),
            "An index started elsewhere — here, the automatic one after a download — finished "
                + "while this compilation was open, and its rows never arrived. That is #1301's "
                + "permanent spinner on the ordinary download → open → browse path: the keyed task "
                + "declined and will not re-run, Index Now was never tapped, and the pipeline was "
                + "already there, so `.onChange(of: appState.currentIndexingProgress)` is the only "
                + "loader. 'Index Required' still on screen: "
                + "\(app.staticTexts[Self.indexRequiredLabel].exists); spinner: "
                + "\(app.staticTexts[Self.loadingLabel].exists)."
        )
        XCTAssertFalse(app.staticTexts[Self.indexRequiredLabel].exists,
                       "the rows are up and the Index Required banner is still above them")
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

        launch()
        navigateToSeededCompilation()
        assertNestedSectionsLoad(idiom: "iPhone push")
    }
}
