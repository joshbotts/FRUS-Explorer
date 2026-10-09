// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import XCTest

// MARK: - AnalyticsCompareFromTableTests

/// A Corpus Analytics comparison begun from the table is a chart with a live Values control (#1583).
///
/// ## What the defect was
/// Chart one term, switch to the table, add a second term. Two or more terms are always drawn as
/// a chart, but the chart/table control's stored value was still Table, and every gate read that
/// value: the comparison was drawn in raw counts, the Values control (Raw count / % of documents)
/// was disabled while it read "% of documents", and the chart/table control was disabled with its
/// table segment selected. No control on the screen could turn the comparison into shares.
///
/// ## What this observes
/// The two controls, since they are what was locked. With two terms committed from the table:
/// the Display control's **Chart** segment is the selected one, and **Values** is enabled. On an
/// iPhone the Values control is inside the **Options** menu; on an iPad it is in the toolbar. No
/// index is needed: the controls answer for a comparison whether or not either term matches.
///
/// ## Devices
/// One shared view, so either idiom is the guard. It never skips: a control it cannot find is a
/// failure that prints the buttons on screen. Measured on iPhone 17 (iOS 27.0) at the commit that
/// fixed it: 1 test, 1 passed; and on the code before the fix, 1 failed, on the selected segment.
///
/// Version history:
///   1.0 — 2026-10-09: #1583 — initial implementation
@MainActor
final class AnalyticsCompareFromTableTests: XCTestCase {

    var app: XCUIApplication!

    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    override func setUp() async throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchArguments = UITestLaunch.arguments()
        app.launch()
    }

    override func tearDown() async throws {
        // Corpus Analytics is a window scene on iPad, and iPadOS restores it at the next launch
        // unless it is closed (#1279).
        UITestPresentation.dismissAnyPresentation(in: app)
        app?.terminate()
        app = nil
    }

    /// The term field, resolved fresh each time: its placeholder changes when a term commits.
    private var termField: XCUIElement { app.textFields["analytics.termField"].firstMatch }

    /// The labels of the buttons on screen, for a failure to print.
    private var buttonsOnScreen: [String] {
        app.buttons.allElementsBoundByIndex.prefix(40).map(\.label).filter { !$0.isEmpty }
    }

    /// Types `term` into the term field and commits it, then waits for its chip.
    private func commit(_ term: String) {
        let field = termField
        XCTAssertTrue(field.waitForExistence(timeout: 10), "the term field is not on screen")
        field.tap()
        field.typeText("\(term)\n")
        XCTAssertTrue(app.staticTexts[term].waitForExistence(timeout: 10), "\(term) did not commit")
    }

    func testComparisonStartedFromTheTableIsAChartWithLiveValues() throws {
        try AnalysisToolsMenu.open("Corpus Analytics", in: app, through: navigator)
        commit("Berlin")

        // One term: switch to the table.
        let table = app.segmentedControls.buttons["Table"].firstMatch
        XCTAssertTrue(table.waitForExistence(timeout: 5),
                      "the Display control has no Table segment. Buttons on screen: \(buttonsOnScreen)")
        table.tap()
        XCTAssertTrue(table.isSelected, "precondition: the table is the selected display")

        // A second term, from the table.
        commit("Vienna")

        // The comparison is a chart, and the Display control says so.
        let chart = app.segmentedControls.buttons["Chart"].firstMatch
        XCTAssertTrue(chart.waitForExistence(timeout: 5))
        XCTAssertTrue(chart.isSelected, """
            #1583: two terms are on screen and the Display control still has Table selected. A \
            comparison is drawn as a chart, and every control reads the display it is drawn in.
            """)

        // Values is live. In the toolbar on a regular width, in the Options menu on a compact one.
        var values = app.segmentedControls.buttons["% of documents"].firstMatch
        var openedMenu = false
        if !values.exists {
            let options = app.buttons["Options"].firstMatch
            XCTAssertTrue(options.waitForExistence(timeout: 5),
                          "neither a Values control nor an Options menu is on screen. Buttons: \(buttonsOnScreen)")
            options.tap()
            openedMenu = true
            values = app.buttons["Values"].firstMatch
            XCTAssertTrue(values.waitForExistence(timeout: 5),
                          "the Options menu lists no Values item. Buttons: \(buttonsOnScreen)")
        }
        let enabled = values.isEnabled
        // Close the menu before asserting, so a failure leaves the screen as teardown expects it.
        if openedMenu { app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.92)).tap() }
        XCTAssertTrue(enabled, """
            #1583: the Values control is disabled over a comparison, so nothing on the screen can \
            turn it between raw counts and % of documents.
            """)
    }
}
