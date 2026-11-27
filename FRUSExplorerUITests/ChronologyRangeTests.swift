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
        closeTheIndexingGuideIfItOpens(in: app)
        return app
    }

    /// Closes the while-indexing guide when it opens: a queue of volumes indexing opens it over the screen, which a
    /// fresh install's first launch is (measured on a simulator made for this row, iPhone 17, iOS 27.0: it came up over
    /// Browse as Analysis Tools opened, and the menu went with it). It pages with Next and closes with Start exploring.
    /// It opens within moments of the launch or not at all, so the wait for it is short.
    static func closeTheIndexingGuideIfItOpens(in app: XCUIApplication) {
        let next = app.buttons["Next"].firstMatch
        guard next.waitForExistence(timeout: 8) else { return }
        let start = app.buttons["Start exploring"].firstMatch
        var pages = 0
        while !start.exists, next.exists, pages < 40 {
            next.tap()
            pages += 1
        }
        if start.waitForExistence(timeout: 5) { start.tap() }
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: start)
        _ = XCTWaiter.wait(for: [gone], timeout: patience)
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

// MARK: - ChronologyRangeSaveTests (L56)

/// Chronology's **Save as Working Corpus…** asks what it holds, saves the range the screen shows, says what it did, and
/// writes the record Browse ▸ Working Corpora lists (decisions 184 and 185, L56).
///
/// ## What it reads
/// The question's message (the corpus's description, the coverage line every corpus shows, and the save's count of each
/// kind), the toast the save shows after it, matched and never read since it goes by itself, and the corpus's row in
/// Browse ▸ Working Corpora, a button named for the range and the count of documents the question said. The counts are read from the screen and checked against each other rather than pinned,
/// since a simulator may hold real volumes of 1962 beside the fixture; on a simulator that holds the fixture alone they
/// are six, all dated inside the range.
///
/// ## The bar's fit
/// The save is an item of the toolbar's This Range menu, with the two hand-offs. Measured on an iPhone 17 under iOS 27.0
/// at the default text size, a sixth item of its own moved Done and About Chronology into the bar's overflow menu, so the
/// save's test requires Done in the bar, where a reader looks for it. Another test opens the screen at the largest
/// accessibility size, where the bar folds even its five items into the overflow, keeps a screenshot, and reaches the
/// save where the bar puts the menu.
///
/// ## Devices
/// iPhone 17 and iPad Pro 13-inch (M5), `OS=27.0`; nothing skips. The runbook's entry has the measurements.
///
/// Version history:
///   1.0 — L56: initial implementation
@MainActor
final class ChronologyRangeSaveTests: XCTestCase {

    private var app: XCUIApplication!
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    /// The toolbar's menu of the range's actions.
    private static let rangeMenuLabel = "This Range"
    /// The save's item in that menu.
    private static let saveLabel = "Save as Working Corpus…"
    /// The question's title (`workingCorpus.capture.confirm.title`).
    private static let questionTitle = "Save as Working Corpus?"
    /// The toast's words before the corpus's name (`workingCorpus.capture.saved %@`).
    private static let savedPrefix = "Saved as the working corpus “"

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

    /// The question says what the save holds, Save writes it, the toast names it, and Working Corpora lists it with its
    /// documents.
    func testTheRangeTheScreenShowsIsSavedAsAWorkingCorpus() throws {
        app = ChronologyRangeFixture.launch(zone: nil)
        try ChronologyRangeFixture.openChronology(in: app, through: navigator)
        XCTAssertTrue(app.navigationBars.buttons["Done"].firstMatch.isHittable, """
            Chronology's Done is not in its bar at the default text size, where the toolbar folded it into its overflow \
            menu. Buttons on screen: \(ChronologyRangeFixture.buttonLabels(in: app))
            """)
        try tapSave()

        let question = app.alerts[Self.questionTitle]
        XCTAssertTrue(question.waitForExistence(timeout: ChronologyRangeFixture.patience), """
            Save as Working Corpus… asked nothing. Buttons on screen: \(ChronologyRangeFixture.buttonLabels(in: app))
            """)
        let message = question.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: "\n")
        XCTAssertTrue(message.contains("Chronology, Jan 1"), "The question names no range: \(message)")
        XCTAssertTrue(message.contains("31, 1962: every document whose dates overlap the range."),
                      "The question does not say what the save takes: \(message)")
        let coverage = try XCTUnwrap(Self.coverage(in: message), "The question has no coverage line: \(message)")
        XCTAssertEqual(coverage.indexed, coverage.total, "Chronology reads indexed documents alone: \(message)")
        XCTAssertGreaterThanOrEqual(coverage.total, 6, "The range holds the fixture's six documents: \(message)")
        XCTAssertEqual(Self.kindsCounted(in: message), coverage.total,
                       "The save's kinds do not add up to what it holds: \(message)")
        question.buttons["Save"].tap()

        // The toast names the corpus for its range. It goes by itself after 2.6 s, so it is matched, never read: on an
        // iPad it had gone by the time its label was asked for.
        let named = "Chronology, Jan 1"
        let toast = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", Self.savedPrefix + named))
            .firstMatch
        XCTAssertTrue(toast.waitForExistence(timeout: ChronologyRangeFixture.patience), """
            The save said nothing after it, or named the corpus for another range. Texts on screen: \(texts())
            """)
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: toast)
        _ = XCTWaiter.wait(for: [gone], timeout: ChronologyRangeFixture.patience)

        closeChronology()
        openWorkingCorpora()
        // A row of Browse's Working Corpora is a button named for the corpus and its count of documents.
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND label ENDSWITH %@",
                                                   named, ", \(coverage.total) documents")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: ChronologyRangeFixture.patience), """
            Working Corpora lists no corpus named for the range with \(coverage.total) documents. Buttons on screen: \
            \(ChronologyRangeFixture.buttonLabels(in: app))
            """)
    }

    /// At the largest accessibility text size the save is reached where the toolbar puts it, and asks its question.
    func testTheSaveIsReachableAtTheLargestTextSize() throws {
        app = ChronologyRangeFixture.launch(zone: nil,
                                            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL")
        try ChronologyRangeFixture.openChronology(in: app, through: navigator)
        keepScreenshot(named: "Chronology at AX5")
        try tapSave()
        XCTAssertTrue(app.alerts[Self.questionTitle].waitForExistence(timeout: ChronologyRangeFixture.patience), """
            At the largest text size Save as Working Corpus… asked nothing. Buttons on screen: \
            \(ChronologyRangeFixture.buttonLabels(in: app))
            """)
        keepScreenshot(named: "The question at AX5")
        app.alerts[Self.questionTitle].buttons["Cancel"].tap()
    }

    // MARK: Steps

    /// Opens the toolbar's This Range menu, in the bar or in its overflow menu, whose control UIKit labels More, and taps
    /// the save in it.
    private func tapSave(file: StaticString = #filePath, line: UInt = #line) throws {
        let inBar = app.buttons[Self.rangeMenuLabel].firstMatch
        if inBar.waitForExistence(timeout: 10), inBar.isHittable {
            inBar.tap()
        } else {
            let overflow = ["More", "Show More", "More Actions"].lazy
                .map { self.app.navigationBars.buttons[$0].firstMatch }
                .first { $0.exists }
            let more = try XCTUnwrap(overflow, """
                The toolbar shows no \(Self.rangeMenuLabel) and no overflow control. Buttons on screen: \
                \(ChronologyRangeFixture.buttonLabels(in: app))
                """, file: file, line: line)
            keepScreenshot(named: "The toolbar, folded")
            more.tap()
            let inOverflow = app.buttons[Self.rangeMenuLabel].firstMatch
            XCTAssertTrue(inOverflow.waitForExistence(timeout: 10), """
                The toolbar's overflow holds no \(Self.rangeMenuLabel). Buttons on screen: \
                \(ChronologyRangeFixture.buttonLabels(in: app))
                """, file: file, line: line)
            inOverflow.tap()
        }
        let item = app.buttons[Self.saveLabel].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 10), """
            \(Self.rangeMenuLabel) holds no \(Self.saveLabel). Buttons on screen: \
            \(ChronologyRangeFixture.buttonLabels(in: app))
            """, file: file, line: line)
        keepScreenshot(named: "The range's menu")
        item.tap()
    }

    /// Closes Chronology with its Done: the sheet on an iPhone, the window on an iPad, which brings the main window
    /// forward (#1368).
    private func closeChronology(file: StaticString = #filePath, line: UInt = #line) {
        let done = app.navigationBars.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: ChronologyRangeFixture.patience), "Chronology has no Done",
                      file: file, line: line)
        done.tap()
    }

    /// Opens Browse ▸ Working Corpora, the list Browse's root names *Your sets*.
    private func openWorkingCorpora(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(navigator.select(.browse, resolveTimeout: 15, file: file, line: line).tapped,
                      "Could not open the Browse tab", file: file, line: line)
        let corpora = app.buttons["browse.root.corporaRow"].firstMatch
        XCTAssertTrue(corpora.waitForExistence(timeout: ChronologyRangeFixture.patience), """
            Browse's root has no Working Corpora row. Buttons on screen: \(ChronologyRangeFixture.buttonLabels(in: app))
            """, file: file, line: line)
        corpora.tap()
    }

    /// The question's coverage line, "6 of 6 documents indexed on this device", as its two counts.
    private static func coverage(in message: String) -> (indexed: Int, total: Int)? {
        guard let match = message.firstMatch(of: /([\d,]+) of ([\d,]+) documents? indexed on this device/),
              let indexed = Int(match.1.replacing(",", with: "")),
              let total = Int(match.2.replacing(",", with: "")) else { return nil }
        return (indexed, total)
    }

    /// The sum of the counts in the question's sentence of kinds, "6 are dated inside the range, …".
    private static func kindsCounted(in message: String) -> Int? {
        guard let sentence = message.split(separator: "\n").first(where: {
            $0.contains("inside the range") || $0.contains("beyond the range") || $0.contains("more than a year")
        }) else { return nil }
        return sentence.matches(of: /([\d,]+) (?:is|are|extends?|spans?)\b/)
            .compactMap { Int($0.1.replacing(",", with: "")) }
            .reduce(0, +)
    }

    /// The labels of the first texts on screen, for a failure's message.
    private func texts() -> String {
        app.staticTexts.allElementsBoundByIndex.prefix(40).map(\.label).filter { !$0.isEmpty }.joined(separator: " | ")
    }

    /// Keeps a screenshot of the screen in the result bundle.
    private func keepScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
