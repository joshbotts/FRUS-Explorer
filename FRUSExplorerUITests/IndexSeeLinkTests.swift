// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import XCTest

/// A back-of-volume index's "See" link scrolls within the index (Lane 2 of
/// `Planning/Editors-Annotations-Followups-2026-11-08.md`).
///
/// ## The defect
/// An index entry's cross-reference, `<ref target="#in2">`, names an `<item xml:id="in2">` of the
/// same index. Until Lane 2 the reader read the anchor as a document named `in2`, which no volume
/// has, and pushed a reader that said "Failed to Load: Document 'in2' was not found in the
/// volume." Measured at corpus `6170e4b32`: 49,799 such references in 397 volumes, every one inside
/// the index that holds its entry.
///
/// ## The fixture
/// `UITestVolumeSeeder.prepareIndexVolumeIfRequested(in:)` writes `frus1932v04`, a catalogue
/// volume, as one document and a back-matter Index of eighty-odd entries, so that the entry
/// "Aviation. *See under* China" names is far below the fold. A launch that does not ask for the
/// file removes it, so the four suites that count on exactly one downloaded volume never see it.
///
/// ## What it reads
/// After the tap, the reader is still the Index: no "Failed to Load" page, one web view, and the
/// entry "China (see also …" inside the web view's frame, which it was not before. On the code
/// before Lane 2 the "Failed to Load" page is what appears, and the test fails there.
///
/// Version history:
///   1.0 — 2026-11-08: Lane 2 of the follow-ups plan
@MainActor
final class IndexSeeLinkTests: XCTestCase {

    /// The subseries row's label, as the other seeded suites match theirs.
    private static let subseriesLabel = "Subseries 1932"

    /// Part of the manifest title of `frus1932v04`, "1932, The Far East, Volume IV".
    private static let volumeTitlePart = "Far East"

    /// The waits a query may take under another session's load (the runbook's rule).
    private static let patience: TimeInterval = 30

    var app: XCUIApplication!

    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_DISABLE_ANIMATIONS"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_INDEX_VOLUME"] = "1"
        app.launchArguments = UITestLaunch.arguments() + ["-frus.filterDownloadedOnly", "YES"]
        app.launch()
    }

    override func tearDown() async throws {
        if let app {
            UITestPresentation.dismissAnyPresentation(in: app)
            // Leave Browse at its root: the next launch on this simulator restores the page the
            // last one ended on, and a run that ended in the reader left the root's tile off screen.
            returnToTheRoot()
        }
        app = nil
    }

    /// Taps back until the Browse root's Subseries tile is hittable, six taps at most: the launch
    /// after a run that ended in the reader restores that page (the iPhone 17 run of 2026-11-08,
    /// which followed the control run and never saw the tile on screen).
    private func returnToTheRoot() {
        let tile = app.buttons["browse.root.subseriesTile"].firstMatch
        let back = app.buttons["BackButton"].firstMatch
        for _ in 0..<6 where !(tile.exists && tile.isHittable) && back.exists {
            back.tap()
            Thread.sleep(forTimeInterval: 0.6)
        }
    }

    // MARK: - The walk

    private func row(labelBeginningWith prefix: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    private func row(labelContaining part: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", part)).firstMatch
    }

    /// Swipes up until `element` is present and hittable: a `List` is lazy, so a row below the fold
    /// is absent from the tree, not merely off screen.
    private func scrollDownUntil(_ element: XCUIElement, attempts: Int = 8) {
        for _ in 0..<attempts {
            if element.exists && element.isHittable { return }
            app.swipeUp(velocity: .slow)
            Thread.sleep(forTimeInterval: 0.4)
        }
    }

    /// Browse ▸ Subseries ▸ 1932 ▸ the volume ▸ Back Matter ▸ Index, into the reader.
    ///
    /// The tab shell's "Local Only" banner covers the lower part of an iPhone's screen, and the
    /// Subseries tile can sit under it or lose a first tap (`VolumeAnnotationsSectionTests`, whose
    /// three-try loop this is): the first run here tapped a tile whose hit point was off screen and
    /// never saw the subseries row.
    private func openTheIndex() {
        XCTAssertTrue(navigator.select(.browse).tapped, "Could not reach the Browse tab")
        let tile = app.buttons["browse.root.subseriesTile"].firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: Self.patience),
                      "The Browse root's Subseries tile did not appear")
        returnToTheRoot()
        let subseries = row(labelBeginningWith: Self.subseriesLabel)
        for _ in 0..<3 {
            scrollDownUntil(tile, attempts: 4)
            if tile.exists && tile.isHittable { tile.tap() }
            if subseries.waitForExistence(timeout: 5) { break }
            scrollDownUntil(subseries, attempts: 4)
            if subseries.exists { break }
        }
        XCTAssertTrue(subseries.exists,
                      "No \"\(Self.subseriesLabel)\" row with filterDownloadedOnly=YES after three taps on the Subseries tile: the index fixture was not seeded, or the taps never reached the tile")
        scrollDownUntil(subseries, attempts: 6)
        subseries.tap()
        let volume = row(labelContaining: Self.volumeTitlePart)
        if !volume.waitForExistence(timeout: 10) { scrollDownUntil(volume, attempts: 6) }
        XCTAssertTrue(volume.exists, "The fixture volume's row is absent")
        scrollDownUntil(volume, attempts: 6)
        volume.tap()
        // The Back Matter row, "Index", and not the volume page's "Index Now" control.
        let index = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Index' AND NOT (label BEGINSWITH 'Index Now')")).firstMatch
        scrollDownUntil(index)
        XCTAssertTrue(index.waitForExistence(timeout: Self.patience),
                      "The volume page lists no Index under Back Matter")
        index.tap()
        // A section with no documents opens its compilation page, whose one control is "Read Index"
        // (`browser.compilation.readSection`, "Read %@"); the first run looked for a bare "Read".
        let read = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Read '")).firstMatch
        if read.waitForExistence(timeout: 10) { read.tap() }
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: Self.patience),
                      "The Index did not open in the reader")
    }

    // MARK: - The test

    func testASeeLinkScrollsToItsEntryWithinTheIndex() throws {
        openTheIndex()
        let webView = app.webViews.firstMatch
        let link = webView.links["China"].firstMatch
        XCTAssertTrue(link.waitForExistence(timeout: Self.patience),
                      "The entry \"Aviation. See under China\" has no China link")
        // WebKit reads a list item's text with its bullet, "• China (see also Sino-Japanese dispute), ",
        // and the entry is off the tree until it is on screen, so it is found by containment, and
        // only after the tap (measured on both devices, 2026-11-08).
        let target = webView.staticTexts
            .matching(NSPredicate(format: "label CONTAINS 'China (see also'")).firstMatch
        let readerFrame = webView.frame
        // An iPad's reader page holds more than one web view element (three on the 13-inch), so
        // the count is compared with itself, not with one.
        let webViewsBefore = app.webViews.count
        let frameBefore = target.exists ? target.frame : CGRect.null
        print("[IndexSeeLink] before: target exists=\(target.exists) frame=\(frameBefore) reader=\(readerFrame)")
        XCTAssertFalse(!frameBefore.isNull && readerFrame.contains(frameBefore),
                       "The entry is already on screen, so the test cannot see the scroll; make the fixture's index longer")

        link.tap()
        Thread.sleep(forTimeInterval: 3)
        let chinaTexts = webView.staticTexts.matching(NSPredicate(format: "label CONTAINS 'China'"))
        print("[IndexSeeLink] after the tap, texts naming China: "
              + (0..<min(chinaTexts.count, 8)).map { "\(chinaTexts.element(boundBy: $0).label) \(chinaTexts.element(boundBy: $0).frame)" }.joined(separator: " | "))

        // The defect: a pushed reader for a document named in2.
        XCTAssertFalse(app.staticTexts["Failed to Load"].waitForExistence(timeout: 3),
                       "A reader opened for a document named in2: the reference was read as a document, not as an index entry")
        XCTAssertEqual(app.webViews.count, webViewsBefore, "The tap opened another page")
        XCTAssertTrue(target.waitForExistence(timeout: Self.patience), "The entry China is not on the page")
        let frameAfter = target.frame
        print("[IndexSeeLink] after: frame=\(frameAfter) reader=\(webView.frame)")
        XCTAssertTrue(webView.frame.contains(frameAfter),
                      "The entry was not scrolled into the reader: \(frameAfter) outside \(webView.frame)")
    }
}
