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

// MARK: - TopicIndexArrivalTests

/// #1365 — the Topic index's "All «area» topics" door lands on the whole area, the second time as
/// well as the first.
///
/// ## The defect
/// Browse ▸ Topics, search "Berlin", open **Berlin crisis**, tap **All Cold War topics**: the index
/// came back under "Topic area: Cold War — 6 topics" listing one topic, because the arrival set the
/// chip and left the search. `SubjectIndexGroupingTests` pins the landing rule itself; this suite
/// drives the wiring that delivers it, which no unit test reaches.
///
/// ## Why the door is tapped twice
/// The second tap sends a request EQUAL to the first (`.group` with the same key) into the same live
/// view. The index used to observe the request's VALUE, so an equal one changed nothing and the
/// door did nothing — the defect again, one tap later. Each hand-off now carries its own identity
/// (`SubjectIndexGrouping.Arrival`); round 2 is the check that it reaches the view.
///
/// ## What it needs
/// Nothing downloaded: the index and the door both read the bundled subject artifact, which is
/// ready on the first frame. The fixture is the shipped catalogue's own — Warfare · Cold War holds
/// six topics, and "Berlin" matches one of them.
///
/// It carries no idiom skip, because iOS and iPadOS run the same `SubjectIndexView` and the same
/// hand-off — but it has been run on an iPhone (iPhone 17e, iOS 26.3) only; the iPad two-pane,
/// where the index renders in the detail pane under the outer bar, is unmeasured. Animations are
/// off because every assertion reads a screen at rest.
///
/// Version history:
///   1.0 — 2026-09-23: #1365
@MainActor
final class TopicIndexArrivalTests: XCTestCase {

    /// The Browse root's Topics row, by its accessibility label.
    private static let topicsRow = "Browse detected topics across the whole series"
    /// The subject whose sheet carries the door.
    private static let subject = "Berlin crisis"
    /// A Cold War topic the search "Berlin" hides, so its presence proves the search is gone.
    private static let hiddenBySearch = "Detente"
    /// The chip's accessibility identifier.
    private static let chipID = "subjects.index.groupFilter"
    /// The door's accessibility identifier.
    private static let doorID = "subjects.detail.browseArea"

    var app: XCUIApplication!

    /// Read through a closure: each test mints a fresh `XCUIApplication`.
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    override func tearDown() async throws {
        UITestPresentation.dismissAnyPresentation(in: app)
        app?.terminate()
        app = nil
    }

    // MARK: - Tests

    func testAreaDoorReplacesTheSearchEveryTime() throws {
        launch()
        openTopicIndex()

        // Round 1 — the issue's reproduction, arriving from the whole index.
        search("Berlin")
        XCTAssertTrue(subjectRow(Self.subject).waitForExistence(timeout: 5),
                      "Searching \"Berlin\" does not list \(Self.subject)")
        XCTAssertFalse(subjectRow(Self.hiddenBySearch).exists,
                       "Precondition: the search should hide \(Self.hiddenBySearch)")
        takeAreaDoor()
        assertWholeAreaListed(round: 1)

        // Round 2 — search inside the area, then take the same door again.
        search("Berlin")
        let chip = element(Self.chipID)
        XCTAssertTrue(chip.waitForExistence(timeout: 5), "The chip vanished when the reader searched")
        XCTAssertEqual(chip.label, "Topic area: Cold War — 1 of 6 topics",
                       "With the search listing one of the area's six topics, the chip must say so")
        takeAreaDoor()
        assertWholeAreaListed(round: 2)
    }

    // MARK: - Steps

    private func launch() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_DISABLE_ANIMATIONS"] = "1"
        app.launchArguments = UITestLaunch.arguments(startingOn: .browse)
        app.launch()
        XCTAssertTrue(navigator.select(.browse, resolveTimeout: 15).tapped,
                      "Could not open the Browse tab, so this suite would read another screen")
    }

    private func openTopicIndex() {
        let row = app.buttons[Self.topicsRow].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15),
                      "The Browse root offers no Topics row. Buttons: \(visibleButtonLabels())")
        row.tap()
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 10),
                      "The Topic index opened with no search field")
    }

    /// Types into the index's search field, replacing whatever it held.
    private func search(_ text: String) {
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "The Topic index's search field is gone")
        field.tap()
        if let value = field.value as? String, !value.isEmpty, value != field.placeholderValue {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count))
        }
        field.typeText(text)
    }

    /// Opens the subject's sheet and taps its "All «area» topics" door.
    private func takeAreaDoor() {
        let row = subjectRow(Self.subject)
        XCTAssertTrue(row.waitForExistence(timeout: 5), "\(Self.subject) is not listed")
        row.tap()
        let sheet = app.navigationBars[Self.subject]
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "\(Self.subject)'s sheet did not open")

        let door = element(Self.doorID)
        let window = app.windows.firstMatch.frame
        var swipes = 0
        while !(door.exists && window.contains(CGPoint(x: door.frame.midX, y: door.frame.midY))),
              swipes < 8 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(door.exists, "\(Self.subject)'s sheet offers no topic-area door")
        door.tap()
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: sheet)
        waitForExpectations(timeout: 5)
    }

    /// The landing: the whole area listed under a chip counting it, and an empty search field.
    private func assertWholeAreaListed(round: Int) {
        let chip = element(Self.chipID)
        XCTAssertTrue(chip.waitForExistence(timeout: 10),
                      "Round \(round): the door did not land a topic-area chip")
        XCTAssertTrue(subjectRow(Self.hiddenBySearch).waitForExistence(timeout: 5), """
            Round \(round): \(Self.hiddenBySearch) is not listed after the door, so the search \
            "Berlin" survived the arrival — the list shows one topic under a chip that reads \
            "\(chip.label)" (#1365).
            """)
        XCTAssertEqual(chip.label, "Topic area: Cold War — 6 topics",
                       "Round \(round): the chip must count the whole area once the search is gone")
        let field = app.searchFields.firstMatch
        let value = field.value as? String ?? ""
        XCTAssertTrue(value.isEmpty || value == field.placeholderValue,
                      "Round \(round): the search field still reads \"\(value)\"")
    }

    // MARK: - Queries

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// A subject row: a button whose label starts with the subject's name (the row reads its name,
    /// its category and its reach as one element).
    private func subjectRow(_ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
    }

    /// Failure-message aid: what a query could have matched instead.
    private func visibleButtonLabels() -> String {
        app.buttons.allElementsBoundByIndex
            .prefix(30)
            .map(\.label)
            .filter { !$0.isEmpty }
            .joined(separator: " | ")
    }
}
