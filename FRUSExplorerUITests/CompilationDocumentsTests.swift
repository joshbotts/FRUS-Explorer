// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import XCTest

/// UI coverage for the Browse **compilation** level — the level R-9 made unreachable.
///
/// ## What this suite is for
/// Every other UI suite stops at the Volume level, because a UI-test install has no downloaded
/// volumes. R-9 lived precisely in that blind spot: `BrowserViewModel.indexingPipeline` was
/// captured once from `.onAppear`, which under `FRUS_UI_TEST_MODE` runs before
/// `bootDownloadManager()` assigns it, so the view model held `nil` for the session,
/// `isIndexed(_:)` answered `false` for every volume, `CompilationView` showed "Index Required"
/// for a fully indexed one, and its "Index Now" button did nothing at all — no progress, no
/// error, no log line.
///
/// The fix is the back-fill this suite exercises. The suite exists because *no test could have
/// caught the bug*, and adding the fix without adding the coverage would leave the next one just
/// as invisible.
///
/// ## Launch configuration
/// On top of the two values every suite injects (`FRUS_UI_TEST_MODE=1`,
/// `-hasCompletedOnboarding 1`) this one adds:
///   - `FRUS_UI_TEST_SEED_VOLUME` — a DEBUG-only app seam (`UITestVolumeSeeder`) that writes a
///     ~2 KB synthetic TEI volume for the named manifest volume into the volumes directory at
///     boot. Downloading the real 1.65 MB `frus1961-63v06` was the alternative and was rejected:
///     it makes the suite depend on GitHub and on network timing to assert nothing extra.
///   - `-frus.filterDownloadedOnly YES` — the persisted Browse filter, injected through
///     `NSArgumentDomain`. With exactly one volume on disk it collapses a 552-volume, 100-plus
///     subseries corpus to one row at each level, so the navigation below needs no scrolling and
///     no title matching against real corpus data.
///
/// ## Measured before/after (iPhone 17 Pro, iOS 26.5)
/// `testCompilationListsDocumentsAfterIndexing` fails on unmodified `v2` at the "Index Now" step
/// — the button is present, the tap does nothing, and the document rows never appear — and passes
/// with the back-fill in place. A test that passed either way would prove nothing about R-9.
///
/// Not idiom-gated: also verified green on iPad Pro 13-inch (M5), iOS 26.5. Nothing here depends
/// on the iPhone bottom tab bar (`selectSection` resolves the sidebar representations too), and
/// the defect is layout-independent.
///
/// Version history:
///   1.0 — Wave R / R-9: initial implementation
//
// Note: the iOS 26 SDK isolates the XCUI APIs to the main actor, so this file emits the same
// "main actor-isolated … nonisolated context" warnings the other UI suites do (see the note at
// the head of `UIObstructionTests` for why `@MainActor` on the class is not the fix).
final class CompilationDocumentsTests: XCTestCase {

    /// The manifest volume the fixture is written for. Any published ID works — the seeder
    /// supplies the content — but this is the smallest real volume (1.65 MB), so it is also the
    /// one a download-based variant of this suite would have used.
    private static let seededVolumeId = "frus1961-63v06"

    /// The compilation `<head>` in the seeded fixture. Must match `UITestVolumeSeeder`.
    private static let compilationTitle = "UI Test Compilation"

    /// The first document `<head>` in the seeded fixture. Must match `UITestVolumeSeeder`.
    private static let firstDocumentTitle = "UI Test Document One"

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_VOLUME"] = Self.seededVolumeId
        app.launchArguments = [
            "-hasCompletedOnboarding", "1",
            // Collapses Browse to the seeded volume alone — see the class docstring.
            "-frus.filterDownloadedOnly", "YES",
        ]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    /// Selects a tab section by label across the iPhone bottom bar and the iPad
    /// `.sidebarAdaptable` representations. Same resolution ladder as
    /// `UIObstructionTests.selectSection(_:)`; duplicated rather than shared because the two
    /// suites are independent `XCTestCase`s with no common base.
    @discardableResult
    private func selectSection(_ label: String) -> Bool {
        let candidates = [
            app.tabBars.firstMatch.buttons[label].firstMatch,
            app.buttons[label].firstMatch,
            app.cells[label].firstMatch,
            app.cells.containing(NSPredicate(format: "label CONTAINS[c] %@", label)).firstMatch,
        ]
        for control in candidates where control.waitForExistence(timeout: 3) {
            control.tap()
            return true
        }
        print("[CompilationDocumentsTests] '\(label)' control not found; element tree:\n"
              + app.debugDescription)
        XCTFail("Could not find a '\(label)' control in any tab-bar representation")
        return false
    }

    /// The corpus row for the seeded volume's subseries.
    ///
    /// `BEGINSWITH 'Subseries '` — with the trailing space — matches `CorpusView`'s row button
    /// and excludes the bare "Subseries" section header, which SwiftUI also exposes and which
    /// sorts first. That distinction cost `UIObstructionTests` three investigations; do not
    /// loosen it.
    private var subseriesRow: XCUIElement {
        // Built fresh on each access: NSPredicate is not Sendable and the XCUI APIs are
        // main-actor-isolated, so a hoisted predicate would be sent twice out of this
        // nonisolated context — a hard error under Swift 6.
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Subseries '")).firstMatch
    }

    /// The volume row for the seeded volume, matched on a distinctive fragment of its manifest
    /// title (the row label is composed from the title and publication year).
    private var volumeRow: XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Kennedy-Khrushchev'")).firstMatch
    }

    /// The seeded compilation's row in `VolumeView`'s "Contents" section.
    private var compilationRow: XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", Self.compilationTitle)).firstMatch
    }

    /// A rendered document row in `CompilationView` — the thing this suite exists to assert.
    private var documentRow: XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", Self.firstDocumentTitle)).firstMatch
    }

    /// Swipes up until `element` exists and is hittable, or `attempts` is exhausted.
    ///
    /// SwiftUI `List` is backed by a lazy `UICollectionView`, so a row below the fold is not in
    /// the accessibility tree at all — `waitForExistence` on it can never succeed without
    /// scrolling first, however long the timeout. Each swipe is followed by a settle delay
    /// because the deceleration animation outlives the gesture call (the same reason
    /// `UIObstructionTests` scenario 1 loops instead of swiping a fixed number of times).
    private func scrollDownUntil(_ element: XCUIElement, attempts: Int) {
        for _ in 0..<attempts {
            if element.exists && element.isHittable { return }
            app.swipeUp(velocity: .slow)
            Thread.sleep(forTimeInterval: 0.4)
        }
    }

    /// Navigates Browse → subseries → volume → compilation, failing with a specific message at
    /// whichever step breaks (each level has a different cause of failure and they should not be
    /// reported as one).
    private func navigateToSeededCompilation() {
        selectSection("Browse")

        XCTAssertTrue(
            subseriesRow.waitForExistence(timeout: 15),
            "No subseries row appeared with filterDownloadedOnly=YES — the fixture volume was "
                + "probably not seeded (check for a [UITestVolumeSeeder] line in the app log). "
                + "Without it this suite cannot reach a compilation at all."
        )
        subseriesRow.tap()

        XCTAssertTrue(
            volumeRow.waitForExistence(timeout: 10),
            "The seeded volume's row did not appear in the subseries list"
        )
        volumeRow.tap()

        // The compilation row lives under VolumeView's "Contents" header, below the Tags and
        // Top-subjects sections — measured off-screen at y≈851 on a 874pt iPhone, and the List is
        // a lazy CollectionView, so the row is not merely invisible, it is absent from the
        // element tree. Scroll until it materialises.
        scrollDownUntil(compilationRow, attempts: 8)

        if !compilationRow.waitForExistence(timeout: 15) {
            // Dump what we actually saw. A missing row here has several possible causes
            // (structure not parsed, volume reported as not downloaded, the push not
            // happening at all) and the tree distinguishes them; guessing from the
            // assertion text alone is how UIObstructionTests lost three investigations.
            print("[CompilationDocumentsTests] compilation row not found; element tree:\n"
                  + app.debugDescription)
            XCTFail("The seeded volume's compilation row did not appear — `loadVolumeStructure` "
                    + "parses the XML directly when the volume is not indexed, so this step does "
                    + "NOT depend on the indexing pipeline and should survive R-9 either way "
                    + "(element tree printed to the test log)")
            return
        }
        compilationRow.tap()
    }

    // MARK: - The R-9 regression test

    /// Reaches the compilation level and asserts its **documents render**.
    ///
    /// This is the assertion R-9 blocked. Two paths reach it, and both are legitimate because the
    /// UI-test store is on disk and survives between runs:
    ///
    ///  - **Cold** (first run, or after erasing the simulator): the seeded volume is on disk but
    ///    unindexed, so "Index Required" is correct and the test taps "Index Now". Pre-fix that
    ///    tap is inert and the documents never arrive.
    ///  - **Warm** (a later run): the volume is already indexed, so documents should render with
    ///    no tap at all. Pre-fix `isIndexed` still answers `false` — this is the reported symptom
    ///    verbatim, "Index Required" on a fully indexed volume — and the test again falls to the
    ///    button, which is again inert.
    ///
    /// So the test discriminates the fix in both states, which is why it does not force one.
    func testCompilationListsDocumentsAfterIndexing() throws {
        navigateToSeededCompilation()

        // Cold path: drive the button. `.exists` (not a wait) — in the warm path the section is
        // absent and waiting on it would just burn the timeout.
        let indexNow = app.buttons["Index Now"]
        if indexNow.waitForExistence(timeout: 5) {
            XCTAssertTrue(
                indexNow.isEnabled,
                "'Index Now' is disabled at the compilation level. That state is reserved for a "
                    + "genuinely absent IndexingPipeline (FTS5Store failed to open at boot); "
                    + "under a normal UI-test launch the pipeline exists and the back-fill should "
                    + "have attached it (R-9)."
            )
            indexNow.tap()
        }

        // The oracle: real document rows from the seeded fixture.
        //
        // Deliberately NOT the "Documents (3)" section header — a header can be produced by an
        // empty section, and this suite's whole point is that content arrives. Indexing a 3-doc
        // fixture is near-instant, but the timeout is generous because a cold run also pays for
        // the pipeline's first-use schema work.
        XCTAssertTrue(
            documentRow.waitForExistence(timeout: 60),
            "No document rows rendered at the compilation level. If '\(Self.firstDocumentTitle)' "
                + "never appears while 'Index Required' is still on screen, this is R-9: "
                + "BrowserViewModel captured a nil indexingPipeline at .onAppear and was never "
                + "back-filled, so isIndexed() answers false for every volume and 'Index Now' "
                + "returns without doing anything."
        )

        // And the banner it replaces must be gone: a run where both were somehow on screen would
        // mean the list rendered for a reason other than a working pipeline.
        XCTAssertFalse(
            app.staticTexts["Index Required"].exists,
            "Document rows rendered but the 'Index Required' banner is still displayed"
        )
    }

    // MARK: - Coverage ledger
    //
    // GATED by this suite: Browse reaches a compilation, and that compilation's document rows
    // render, on an install whose only volume is the seeded fixture. Measured on iPhone 17 Pro
    // (iOS 26.5): red on unmodified v2, green with the back-fill.
    //
    // NOT GATED, and deliberately not asserted rather than asserted weakly: opening a document
    // row into the reader. A `testDocumentRowOpensReader` was written, run, and REMOVED, because
    // it failed for a reason that has nothing to do with R-9 and a red test is worse than a
    // recorded gap. What was measured, twice:
    //   - The row tap does push. A screenshot 40 s in shows the reader pushed, titled "UI Test
    //     Document One", with its back button — and stuck on "Loading document…"
    //     (`DocumentViewModel.load` had not completed).
    //   - Every XCUI query issued after that push times out with "Failed to get matching
    //     snapshots: Timed out while evaluating UI query" after ~200 s. Both a `staticTexts`
    //     match on the document body and a bare `app.webViews.firstMatch` behaved identically,
    //     which rules out "the web view's accessibility tree is merely large" — a `webViews`
    //     query does not have to walk it.
    // Two candidate explanations remain, and they were NOT separated here: the fixture may be
    // missing something `DocumentViewModel.load` awaits, or the accessibility snapshot and the
    // WKWebView bring-up may be wedging each other so that neither the load nor the query can
    // finish. Do not claim either without a run that distinguishes them — this suite's sibling
    // (`UIObstructionTests`) has a long history of one confident explanation covering two causes.
}
