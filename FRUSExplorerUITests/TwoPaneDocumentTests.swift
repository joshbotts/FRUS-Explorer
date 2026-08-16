// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import XCTest

/// What happens when a **document** lands in F-2's two-pane detail pane (UI review F-2 follow-up).
///
/// ## The interaction, and why it was left unverified
/// `#914` shipped the two-pane and its probe drilled three levels — subseries, volume,
/// compilation. It never opened a *document*, and the document level is the one that brings a
/// second pane of its own: `DocumentView` presents the Research rail as a trailing `.inspector`
/// on every non-phone idiom, defaulting **open** (`panelVisible = true`, and `.rememberLast`
/// leaves it alone). So a document in the detail pane asks for three columns in a container that
/// was gated for two.
///
/// The arithmetic is the finding, and it does not depend on which container the inspector
/// resolves against: a rail is a fixed-width column either way, so the reader gets
/// `container − listPane − rail`. At F-2's own 820 pt gate that is roughly **160 pt of document**.
/// The app already states the floor it violates — `MacDocumentView.railOverlayBreakpoint`
/// (`:349`) exists so the Mac's reading column "never reflows below its ~340 pt floor".
///
/// ## Why this suite seeds a volume instead of joining `UIObstructionTests`
/// Reaching a document needs one on disk. `CompilationDocumentsTests` established the seam for
/// that (`FRUS_UI_TEST_SEED_VOLUME` + `-frus.filterDownloadedOnly YES`), and this suite reuses its
/// navigation verbatim. It is a separate `XCTestCase` for the same reason that one is: the launch
/// configuration differs from `UIObstructionTests`', and the two cannot share a host.
///
/// ## The recorded hazard this suite walks into deliberately
/// `CompilationDocumentsTests`' coverage ledger records that a `testDocumentRowOpensReader` was
/// written, run, and **removed**: after the reader pushed, every XCUI query timed out with
/// "Failed to get matching snapshots" for ~200 s, on iPhone 17 Pro. Two causes were left
/// unseparated — a fixture the loader waits on, or the accessibility snapshot and the `WKWebView`
/// bring-up wedging each other.
///
/// This suite therefore measures **before** it asserts, prints every number it takes, and keeps
/// its post-open queries to the cheapest forms available. If the wedge reproduces here, that is
/// itself the result: it means the interaction is not reachable by this harness on iPad either,
/// and the geometry has to be settled another way.
///
/// Version history:
///   1.0 — F-2 follow-up: the document-into-the-detail-pane interaction
final class TwoPaneDocumentTests: XCTestCase {

    /// The manifest volume the fixture is written for — the same one `CompilationDocumentsTests`
    /// seeds, so a single `UITestVolumeSeeder` fixture serves both suites.
    private static let seededVolumeId = "frus1961-63v06"

    /// The compilation `<head>` in the seeded fixture. Must match `UITestVolumeSeeder`.
    private static let compilationTitle = "UI Test Compilation"

    /// The first document `<head>` in the seeded fixture. Must match `UITestVolumeSeeder`.
    private static let firstDocumentTitle = "UI Test Document One"

    /// The list pane's width in `BrowserView` (`twoPaneLayout`, `listPaneWidth`).
    private static let listPaneWidth: CGFloat = 340

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_VOLUME"] = Self.seededVolumeId
        app.launchArguments = [
            "-hasCompletedOnboarding", "1",
            "-frus.filterDownloadedOnly", "YES",
        ]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Navigation (borrowed from CompilationDocumentsTests)

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
        XCTFail("Could not find a '\(label)' control in any tab-bar representation")
        return false
    }

    private var subseriesRow: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Subseries '")).firstMatch
    }

    private var volumeRow: XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Kennedy-Khrushchev'")).firstMatch
    }

    private var compilationRow: XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", Self.compilationTitle)).firstMatch
    }

    private var documentRow: XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", Self.firstDocumentTitle)).firstMatch
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

    /// Counts the cells on each side of the pane divider and reports the widest.
    @discardableResult
    private func panes(_ step: String) -> (list: Int, detail: Int, widest: CGFloat) {
        var list = 0, detail = 0, widest = CGFloat(0)
        let divider = Self.listPaneWidth
        for index in 0..<app.cells.count {
            let frame = app.cells.element(boundBy: index).frame
            if frame.maxX <= divider + 12 { list += 1 }
            if frame.minX >= divider - 12 { detail += 1 }
            widest = max(widest, frame.width)
        }
        print("[F-2 doc] \(step): list=\(list) detail=\(detail) widest=\(widest)")
        return (list, detail, widest)
    }

    // MARK: - The probe

    /// Opens a document into the two-pane detail pane and measures what the reader is left with.
    func testDocumentInTwoPaneDetailPane() throws {
        #if canImport(UIKit)
        try XCTSkipUnless(
            UIDevice.current.userInterfaceIdiom == .pad,
            "iPad-only: the two-pane gate requires a pad idiom and 820pt of content width"
        )
        #else
        throw XCTSkip("UIKit-only test")
        #endif

        selectSection("Browse")

        let window = app.windows.firstMatch.frame
        print("[F-2 doc] window=\(window)")

        // The two-pane placeholder is the layout probe. Skipping on its absence rather than
        // asserting a width lets this run on ANY iPad and report honestly which side of the gate
        // that device falls on — which is the question for the 11-inch, whose 834pt sits 14pt
        // above the gate.
        try XCTSkipUnless(
            app.staticTexts["Choose a Subseries"].waitForExistence(timeout: 10),
            "Browse is a single column at \(window.width)pt — this device is below the two-pane "
                + "gate, so the interaction does not arise here"
        )

        XCTAssertTrue(subseriesRow.waitForExistence(timeout: 15),
                      "No subseries row with filterDownloadedOnly=YES — the fixture volume was "
                          + "probably not seeded")
        subseriesRow.tap()
        Thread.sleep(forTimeInterval: 1.0)
        panes("subseries")

        XCTAssertTrue(volumeRow.waitForExistence(timeout: 10), "The seeded volume's row is absent")
        volumeRow.tap()
        Thread.sleep(forTimeInterval: 1.0)
        panes("volume")

        scrollDownUntil(compilationRow, attempts: 8)
        XCTAssertTrue(compilationRow.waitForExistence(timeout: 15),
                      "The seeded volume's compilation row did not appear")
        compilationRow.tap()
        Thread.sleep(forTimeInterval: 1.0)

        let indexNow = app.buttons["Index Now"]
        if indexNow.waitForExistence(timeout: 5), indexNow.isEnabled { indexNow.tap() }

        XCTAssertTrue(documentRow.waitForExistence(timeout: 60),
                      "No document rows at the compilation level")
        let compilationPanes = panes("compilation")
        XCTAssertGreaterThan(compilationPanes.list, 0,
                             "the corpus list is gone before the document even opened")

        // ── The interaction this suite exists for ──────────────────────────────────────────
        print("[F-2 doc] opening the document…")
        documentRow.tap()
        Thread.sleep(forTimeInterval: 6.0)

        // Cheapest post-open query first. If the recorded wedge reproduces, it stalls here and
        // the ~200 s stall IS the result — see the class docstring.
        print("[F-2 doc] after open: navBars=\(app.navigationBars.count)")

        let webViews = app.webViews
        print("[F-2 doc] webViews=\(webViews.count)")
        guard webViews.count > 0 else {
            XCTFail("The document did not render a web view — nothing below measures the reader")
            return
        }
        let reader = webViews.firstMatch.frame
        print("[F-2 doc] webView frame=\(reader)")

        let addNote = app.buttons["Add Note"]
        print("[F-2 doc] Add Note (rail) exists=\(addNote.exists) "
              + "frame=\(addNote.exists ? "\(addNote.frame)" : "n/a")")
        XCTAssertTrue(addNote.exists,
                      "The Research rail is not present, so this run says nothing about the "
                          + "three-column arrangement it exists to measure")

        let after = panes("document")

        // The rule: below `documentMinimumWidth` (1100 = F-2's 820 gate + a 280pt rail) the list
        // pane is given up so the reader gets the width. Every iPad in portrait is below it.
        //
        // The oracle is the reader's LEFT EDGE, not the cell count. Before the fix the web view
        // began at x=340.5 on both devices measured — exactly the list pane's width — so a
        // leading edge near zero is the fix and nothing else produces it. Cell counts are a
        // corroborating check: `list` counts cells left of the divider, and the corpus list is
        // the only thing that puts any there.
        XCTAssertLessThan(
            reader.minX, 100,
            "The document begins at x=\(reader.minX) in a \(window.width)pt window — the corpus "
                + "list pane is still taking 340pt beside a reader that also has a 240pt Research "
                + "rail. Measured before the fix: 340.5 on both a 13-inch and an 11-inch iPad."
        )
        XCTAssertGreaterThan(
            reader.width, window.width * 0.6,
            "The reader is \(reader.width)pt of a \(window.width)pt window. Three columns left it "
                + "451.5pt on a 13-inch iPad — below the document's own 70ch measure, and below "
                + "the ~340pt floor MacDocumentView.railOverlayBreakpoint refuses to cross."
        )
        XCTAssertEqual(
            after.list, 0,
            "Cells are still present left of the divider at the document level — the corpus list "
                + "pane was not given up (F-2 follow-up)"
        )

        // Back must survive the list pane, or the reader is stranded — and at depth 1, which a
        // hand-off from Research or Search produces, it is the ONLY way out.
        let back = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Back'")).firstMatch
        XCTAssertTrue(back.exists,
                      "The detail pane offers no Back with the list pane gone — the document is a "
                          + "dead end")
        back.tap()
        Thread.sleep(forTimeInterval: 1.5)
        let restored = panes("after Back")
        XCTAssertGreaterThan(restored.list, 0,
                             "Going back from the document did not restore the corpus list pane")

        // ── The depth-1 case, driven rather than reasoned about ────────────────────────────
        //
        // Everything above is at depth 4, where Back renders from `pathDepth > 1` and would render
        // with the coupling removed. This is the case that discriminates: `ResumeReadingRow` calls
        // `vm.select(.document(entry))`, which REPLACES the path — a document at depth 1, the same
        // shape `consumePendingBrowseDocument` produces for a hand-off from Research, Search or a
        // citation. Depth 1 is exactly where the two-pane suppressed Back, on the grounds that the
        // corpus list was beside it, and it is the list this fix gives up.
        //
        // Reachable here only because the document above was actually read: the row renders
        // nothing without reading history. If it is absent the case is unexercised and this says
        // so, rather than passing quietly.
        vm_resumeReading()
    }

    /// Drills the corpus root's "Continue reading" row and asserts the depth-1 document is not a
    /// dead end. Split out for a legible failure, not because it stands alone — it needs the
    /// reading history the scenario above creates.
    private func vm_resumeReading() {
        // Scroll back to the top of the list pane: the compilation walk left it scrolled, and the
        // resume row is the FIRST row in `CorpusView`.
        app.swipeDown(velocity: .slow)
        Thread.sleep(forTimeInterval: 0.6)

        let resume = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Continue reading'")).firstMatch
        guard resume.waitForExistence(timeout: 5) else {
            XCTFail("No 'Continue reading' row after reading a document, so the depth-1 case — a "
                    + "document that REPLACES the path rather than extending it — went untested. "
                    + "That is the case where a missing Back is a dead end.")
            return
        }
        resume.tap()
        Thread.sleep(forTimeInterval: 5.0)

        let after = panes("resume (depth 1)")
        XCTAssertEqual(after.list, 0,
                       "The list pane survived a depth-1 document — the level gate reads the path's "
                           + "last element, and `select(_:)` replaces the path rather than appending")

        let back = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Back'")).firstMatch
        XCTAssertTrue(
            back.exists,
            "A depth-1 document has no Back and no list pane — a dead end. This is the coupling "
                + "`BrowseTwoPaneMetrics.showsBackControl` exists for: the old `depth > 1` rule was "
                + "correct only while the corpus list was guaranteed to be beside the document."
        )
    }
}
