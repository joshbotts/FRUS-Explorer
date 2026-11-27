// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import XCTest

// MARK: - ChronologyRangeFixture

/// What both of this file's suites stand on: the browse fixture's volume, whose six documents are dated from 1 January
/// to 1 March 1962 (`UITestVolumeSeeder`), and Chronology opened on its first three months by the seam that names a
/// range (`UITestBrowseSeams.chronologyRange`), since the screen's date pickers are set a month at a time through their
/// calendars and the manifest's latest year is 64 years on.
///
/// Version history:
///   1.0 — #2012 (L56): initial implementation
@MainActor
enum ChronologyRangeFixture {

    /// The fixture volume, as `CompilationDocumentsTests` and `AuxWindowCloseTests` seed it.
    static let seededVolumeId = "frus1961-63v06"
    /// The first day of the range Chronology opens on.
    static let firstDay = "1962-01-01"
    /// The last day of it.
    static let lastDay = "1962-03-31"
    /// Long, because a wait that is met returns at once and this Mac is not always quiet.
    static let patience: TimeInterval = 30

    /// Launches the app on Browse with the fixture seeded and Chronology armed to open on the range.
    ///
    /// - Parameters:
    ///   - zone: The zone the app runs in (`TZ`), whatever the Mac's; `nil` leaves the Mac's.
    ///   - contentSizeCategory: A `UICTContentSizeCategory…` name to force, or `nil`.
    /// - Returns: The launched app.
    static func launch(zone: String?, contentSizeCategory: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_DISABLE_ANIMATIONS"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_VOLUME"] = seededVolumeId
        app.launchEnvironment["FRUS_UI_TEST_CHRONOLOGY_RANGE"] = "\(firstDay)/\(lastDay)"
        if let zone { app.launchEnvironment["TZ"] = zone }
        app.launchArguments = UITestLaunch.arguments(contentSizeCategory: contentSizeCategory)
        app.launch()
        return app
    }

    /// Opens Chronology from Browse's Analysis Tools and waits for the range to load: a sheet on an iPhone, a window on
    /// an iPad.
    ///
    /// The mark is the range bar's *Search in this range*, which the screen draws once a load holds a document dated
    /// inside the range, and which is in the tree at every text size. The list's rows are not: at the largest sizes the
    /// first is below the screen, where the list draws no cell.
    ///
    /// - Parameters:
    ///   - app: The app under test.
    ///   - navigator: The suite's navigator.
    static func openChronology(in app: XCUIApplication, through navigator: TabBarNavigator,
                               file: StaticString = #filePath, line: UInt = #line) throws {
        try AnalysisToolsMenu.open("Chronology", in: app, through: navigator, file: file, line: line)
        let loaded = app.buttons["Search in this range"].firstMatch
        XCTAssertTrue(loaded.waitForExistence(timeout: patience), """
            Chronology loaded no document dated from \(firstDay) to \(lastDay), where the fixture has six. Buttons on \
            screen: \(buttonLabels(in: app))
            """, file: file, line: line)
    }

    /// The labels of the first buttons on screen, for a failure's message.
    static func buttonLabels(in app: XCUIApplication) -> String {
        app.buttons.allElementsBoundByIndex.prefix(40).map(\.label).filter { !$0.isEmpty }.joined(separator: " | ")
    }
}

// MARK: - ChronologyRangeHandOffTests (#2012, L56)

/// Chronology's *Search in this range* hands Search the two days the screen shows: the range it loaded, in any zone.
///
/// ## The two defects
/// - **A day early east of UTC (#2012).** The hand-off wrote its two days through a formatter in UTC, over the local
///   midnights the screen's calendar gave it, so wherever the device's zone is east of UTC it handed Search the day
///   before each end. Read from the code and an emulation when the issue was filed; this suite runs the app in Tokyo's
///   zone to see it.
/// - **The pickers, not the screen.** Both hand-offs read the two date pickers, which a reader can move without pressing
///   Show; after that they named a range the screen was not showing. This suite moves From's day and runs the hand-off
///   in New York's zone, west of UTC, where the first defect cannot show.
///
/// Both read the *Narrowed by* chip Search draws for the hand-off's filter, whose accessibility label names its two days
/// as they were handed (`SearchView.narrowedByRow`).
///
/// ## Devices
/// iPhone 17 and iPad Pro 13-inch (M5), `OS=27.0`; nothing skips. On an iPhone Chronology is a sheet over Browse, and on
/// an iPad a window, which the hand-off closes to bring the main window forward (#1368). The runbook's entry has the
/// measurements.
///
/// Version history:
///   1.0 — #2012 (L56): initial implementation
@MainActor
final class ChronologyRangeHandOffTests: XCTestCase {

    private var app: XCUIApplication!
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    override func setUp() async throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDown() async throws {
        UITestPresentation.dismissAnyPresentation(in: app)
        app?.terminate()
        app = nil
    }

    // MARK: Tests

    /// In Tokyo's zone, nine hours east of UTC, *Search in this range* hands Search the range's own two days.
    func testSearchInThisRangeHandsSearchTheDaysTheScreenShows() throws {
        app = ChronologyRangeFixture.launch(zone: "Asia/Tokyo")
        try ChronologyRangeFixture.openChronology(in: app, through: navigator)
        searchInThisRange()
        assertSearchIsNarrowed(from: ChronologyRangeFixture.firstDay, to: ChronologyRangeFixture.lastDay, """
            In Tokyo's zone Chronology showed \(ChronologyRangeFixture.firstDay) to \(ChronologyRangeFixture.lastDay), \
            and Search in this range handed Search other days (#2012: a UTC formatter over a local midnight writes the \
            day before, east of UTC)
            """)
    }

    /// After From is moved to the 5th without Show, *Search in this range* still hands the range the screen shows.
    func testSearchInThisRangeNamesTheLoadedRangeAfterThePickersMove() throws {
        app = ChronologyRangeFixture.launch(zone: "America/New_York")
        try ChronologyRangeFixture.openChronology(in: app, through: navigator)
        pickTheFifthInFrom()
        searchInThisRange()
        assertSearchIsNarrowed(from: ChronologyRangeFixture.firstDay, to: ChronologyRangeFixture.lastDay, """
            From was moved to the 5th and Show was not pressed, so Chronology still showed \
            \(ChronologyRangeFixture.firstDay) to \(ChronologyRangeFixture.lastDay); Search in this range handed Search \
            the pickers' days instead
            """)
    }

    // MARK: Steps

    /// Taps *Search in this range*, in the range bar's summary row.
    private func searchInThisRange(file: StaticString = #filePath, line: UInt = #line) {
        let button = app.buttons["Search in this range"].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: ChronologyRangeFixture.patience), """
            Chronology shows no Search in this range. Buttons on screen: \(ChronologyRangeFixture.buttonLabels(in: app))
            """, file: file, line: line)
        button.tap()
    }

    /// Requires Search's *Narrowed by* row to show the hand-off's chip for `first` to `last`, naming the chip it shows
    /// instead in the failure.
    private func assertSearchIsNarrowed(from first: String, to last: String, _ message: String,
                                        file: StaticString = #filePath, line: UInt = #line) {
        let expected = app.buttons["Remove the \(first) to \(last) filter"]
        if expected.waitForExistence(timeout: ChronologyRangeFixture.patience) { return }
        let shown = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Remove the 19")).firstMatch
        let reads = shown.exists ? "Search's date chip reads \"\(shown.label)\"" : "Search shows no date chip"
        XCTFail("\(message). \(reads). Buttons on screen: \(ChronologyRangeFixture.buttonLabels(in: app))",
                file: file, line: line)
    }

    /// Opens From's calendar, taps the 5th of the month it opens on, and closes it with a tap where the picker is, as
    /// `FilterDateRangeHandOffTests` picks a day (L57 measured the route on an iPhone 17 under iOS 27.0). The point is
    /// fixed before the calendar opens, since the calendar is a date picker too and takes the first place among them.
    private func pickTheFifthInFrom(file: StaticString = #filePath, line: UInt = #line) {
        let compact = app.datePickers.allElementsBoundByIndex
            .filter { $0.exists && !$0.frame.isEmpty && $0.frame.height < 80 }
            .sorted { ($0.frame.minY, $0.frame.minX) < ($1.frame.minY, $1.frame.minX) }
        guard let from = compact.first else {
            XCTFail("Chronology's range bar has no date picker", file: file, line: line)
            return
        }
        let frame = from.frame
        let window = app.frame
        let control = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: frame.midX - window.minX, dy: frame.midY - window.minY))
        control.tap()
        let month = app.buttons["DatePicker.NextMonth"].firstMatch
        XCTAssertTrue(month.waitForExistence(timeout: ChronologyRangeFixture.patience), "From's calendar did not open",
                      file: file, line: line)
        // A day's button reads "Friday, January 5": the 5th of the month the picker opened on, January 1962.
        let fifth = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", " 5")).allElementsBoundByIndex
            .first { $0.isHittable && $0.label.contains("January") }
        guard let fifth else {
            XCTFail("From's calendar has no January 5 to tap", file: file, line: line)
            return
        }
        fifth.tap()
        control.tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: month)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: ChronologyRangeFixture.patience), .completed,
                       "From's calendar did not close", file: file, line: line)
    }
}
