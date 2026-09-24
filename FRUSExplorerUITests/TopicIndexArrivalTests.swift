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
/// well as the first, and Browse ▸ Topics afterwards opens the whole index.
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
/// door did nothing — the defect again, one tap later. The index now observes its host's slot,
/// which it empties as it lands a delivery, and each hand-off is posted as a new
/// `SubjectIndexGrouping.Arrival`; round 2 is the check that the second one reaches the view.
/// (Emptying alone makes it a change here; the identity is for a slot that was NOT emptied, which
/// `SubjectIndexGroupingTests.postingIsANewDeliveryEveryTime` pins.)
///
/// ## Why the Topics row is tapped after a hand-off
/// The host kept its last hand-off for as long as it lived, and Browse mounts a new index each time
/// it selects Topics, so the corpus root's Topics row — which hands nothing off — re-landed the
/// last door taken: the index opened under that door's chip instead of whole. The index now empties
/// the slot as it lands a delivery; `testTopicsRowAfterAHandOffOpensTheWholeIndex` is the device
/// check that the emptying reaches the host.
///
/// ## What it needs
/// Nothing downloaded: the index and the door both read the bundled subject artifact, which is
/// ready on the first frame. The fixture is the shipped catalogue's own — Warfare · Cold War holds
/// six topics, "Berlin" matches one of them, and the index's first topic, Academic exchanges, is on
/// screen until a search hides it.
///
/// ## Both idioms, and what differs between them
/// iOS and iPadOS run the same `SubjectIndexView` and the same hand-off, so nothing here skips. Run
/// it on an iPhone and on the iPad Pro 13-inch on iOS 27, where #1365 was seen: there Browse is two
/// panes, the index's `.searchable` belongs to the outer bar, and that bar COLLAPSES it into a
/// magnifier button — the 1.0 suite looked for `app.searchFields.firstMatch`, found nothing, and
/// failed before it reached the door. So the field is revealed through that button when it is not
/// already on screen, and matched by its own prompt rather than as the first search field in the
/// tree (SwiftUI's `.searchable` has no way to give the field an identifier). Leaving the index
/// differs too: a phone goes Back to the root; the two-pane has the root beside the index and no
/// Back at depth one, so it chooses People. Animations are off because every assertion reads a
/// screen at rest.
///
/// Version history:
///   1.0 — 2026-09-23: #1365
///   1.1 — 2026-09-24: #1365 review — runs on the iPad two-pane (the collapsed search is revealed,
///          and the field is matched by its prompt); round 1's precondition can fail; the
///          Topics-row test for the emptied slot
@MainActor
final class TopicIndexArrivalTests: XCTestCase {

    /// The Browse root's Topics row, by its accessibility label.
    private static let topicsRow = "Browse detected topics across the whole series"
    /// The Browse root's People row, by its accessibility label — the two-pane's way out.
    private static let peopleRow = "Browse people mentioned across all indexed volumes"
    /// The Topic index's search prompt, which no other search field in the app carries.
    private static let searchPrompt = "Search topics"
    /// The subject whose sheet carries the door.
    private static let subject = "Berlin crisis"
    /// A Cold War topic the search "Berlin" hides, so its presence proves the search is gone.
    private static let hiddenBySearch = "Detente"
    /// The index's first topic, on screen when it opens whole. Its area is Information
    /// Programs · General, and the search "Berlin" hides it.
    private static let firstTopic = "Academic exchanges"
    /// The index's second topic, in ANOTHER area (Politico-Military Issues · General), so it is
    /// listed only when the index is whole.
    private static let secondTopic = "Aerial reconnaissance"
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
        XCTAssertTrue(subjectRow(Self.firstTopic).waitForNonExistence(timeout: 5), """
            Precondition: the search "Berlin" should hide \(Self.firstTopic), which was on screen \
            before it — so the search never reached the list, and the door below would be taken \
            from the whole index rather than from a search.
            """)
        XCTAssertTrue(subjectRow(Self.subject).waitForExistence(timeout: 5),
                      "Searching \"Berlin\" does not list \(Self.subject)")
        takeAreaDoor(from: Self.subject)
        assertWholeAreaListed(round: 1)

        // Round 2 — search inside the area, then take the same door again.
        search("Berlin")
        let chip = element(Self.chipID)
        XCTAssertTrue(chip.waitForExistence(timeout: 5), "The chip vanished when the reader searched")
        XCTAssertEqual(chip.label, "Topic area: Cold War — 1 of 6 topics",
                       "With the search listing one of the area's six topics, the chip must say so")
        takeAreaDoor(from: Self.subject)
        assertWholeAreaListed(round: 2)
    }

    /// Browse ▸ Topics hands nothing off, so it must open the whole index even after a door has
    /// landed an area — not re-land that door's area into the new index (#1365 review).
    func testTopicsRowAfterAHandOffOpensTheWholeIndex() throws {
        launch()
        openTopicIndex()

        // The first topic's sheet is reachable with no search, and its door hands off
        // Information Programs · General.
        takeAreaDoor(from: Self.firstTopic)
        let chip = element(Self.chipID)
        XCTAssertTrue(chip.waitForExistence(timeout: 10),
                      "Precondition: the door landed no chip, so reopening the index proves nothing")
        XCTAssertFalse(subjectRow(Self.secondTopic).exists,
                       "Precondition: \(Self.secondTopic) is outside the area and must be hidden by it")

        leaveTheIndex()
        tapTopicsRow()
        let whole = subjectRow(Self.secondTopic)
        XCTAssertTrue(waitForEither(whole, chip, timeout: 10),
                      "The Topic index did not open. Buttons: \(visibleButtonLabels())")
        XCTAssertFalse(chip.exists, """
            Browse ▸ Topics reopened the index under "\(chip.label)" — the door taken before it, \
            landed a second time into a new index that nothing had handed off to.
            """)
        XCTAssertTrue(whole.exists,
                      "Browse ▸ Topics must list the whole index, \(Self.secondTopic) included")
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

    /// Taps the Browse root's Topics row.
    private func tapTopicsRow() {
        let row = app.buttons[Self.topicsRow].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15),
                      "The Browse root offers no Topics row. Buttons: \(visibleButtonLabels())")
        row.tap()
    }

    /// Opens the index from the Browse root, and waits for it to list its first topic.
    private func openTopicIndex() {
        tapTopicsRow()
        XCTAssertTrue(subjectRow(Self.firstTopic).waitForExistence(timeout: 10),
                      "The Topic index did not open at \(Self.firstTopic), its first topic")
    }

    /// Leaves the index for the Browse root, the way the layout on screen offers.
    private func leaveTheIndex() {
        let back = app.navigationBars.buttons["BackButton"].firstMatch
        if back.exists {
            // A phone, or an iPad too narrow for two panes: the index is pushed over the root.
            back.tap()
        } else {
            // The two-pane: the root is the list pane beside the index, and at depth one the
            // detail offers no Back — the reader leaves by choosing another level.
            let people = app.buttons[Self.peopleRow].firstMatch
            XCTAssertTrue(people.exists, """
                The index offers no Back and the Browse root is not beside it. \
                Buttons: \(visibleButtonLabels())
                """)
            people.tap()
        }
        XCTAssertTrue(element(Self.chipID).waitForNonExistence(timeout: 5),
                      "The Topic index is still on screen after leaving it")
    }

    /// The index's search field, revealed first when the bar has collapsed it into a button.
    private func revealTopicSearch() -> XCUIElement {
        let field = topicSearchField
        if field.waitForExistence(timeout: 2) { return field }
        // The iPad two-pane on iOS 27: the outer bar shows the index's search as a magnifier
        // button. Scoped to the navigation bars, because the floating tab bar's Search tab is also
        // a button labelled "Search".
        let collapsed = app.navigationBars.buttons["Search"].firstMatch
        XCTAssertTrue(collapsed.exists, """
            The Topic index shows neither its search field nor the bar button that reveals it. \
            Search fields: \(searchFieldDescriptions()). Buttons: \(visibleButtonLabels())
            """)
        collapsed.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5), """
            The bar's Search button revealed no "\(Self.searchPrompt)" field. \
            Search fields: \(searchFieldDescriptions())
            """)
        return field
    }

    /// Types into the index's search field, replacing whatever it held.
    private func search(_ text: String) {
        let field = revealTopicSearch()
        field.tap()
        if let value = field.value as? String, !value.isEmpty, value != field.placeholderValue {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count))
        }
        field.typeText(text)
    }

    /// Opens a subject's sheet and taps its "All «area» topics" door.
    private func takeAreaDoor(from name: String) {
        let row = subjectRow(name)
        XCTAssertTrue(row.waitForExistence(timeout: 5), "\(name) is not listed")
        row.tap()
        let sheet = app.navigationBars[name]
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "\(name)'s sheet did not open")

        let door = element(Self.doorID)
        let window = app.windows.firstMatch.frame
        var swipes = 0
        while !(door.exists && window.contains(CGPoint(x: door.frame.midX, y: door.frame.midY))),
              swipes < 8 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(door.exists, "\(name)'s sheet offers no topic-area door")
        door.tap()
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 5), "\(name)'s sheet did not close")
    }

    /// The landing: the whole area listed under a chip counting it, and no search text left.
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
        // The field may have collapsed back into the bar's button, which holds no text; when it
        // is on screen it must be empty.
        let field = topicSearchField
        if field.exists {
            let value = field.value as? String ?? ""
            XCTAssertTrue(value.isEmpty || value == field.placeholderValue,
                          "Round \(round): the search field still reads \"\(value)\"")
        }
    }

    // MARK: - Queries

    /// The index's search field, by its prompt — never the first search field in the tree.
    private var topicSearchField: XCUIElement {
        app.searchFields.matching(NSPredicate(format: "placeholderValue == %@", Self.searchPrompt))
            .firstMatch
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// A subject row: a button whose label starts with the subject's name (the row reads its name,
    /// its category and its reach as one element).
    private func subjectRow(_ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
    }

    /// Waits until either element exists; `false` when neither does by the deadline.
    private func waitForEither(_ first: XCUIElement, _ second: XCUIElement,
                               timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if first.waitForExistence(timeout: 0.5) || second.exists { return true }
        } while Date() < deadline
        return false
    }

    /// Failure-message aid: what a query could have matched instead.
    private func visibleButtonLabels() -> String {
        app.buttons.allElementsBoundByIndex
            .prefix(30)
            .map(\.label)
            .filter { !$0.isEmpty }
            .joined(separator: " | ")
    }

    /// Failure-message aid: every search field's identifier, label and prompt.
    private func searchFieldDescriptions() -> String {
        let fields = app.searchFields.allElementsBoundByIndex.map {
            "[id: \($0.identifier), label: \($0.label), prompt: \($0.placeholderValue ?? "")]"
        }
        return fields.isEmpty ? "none" : fields.joined(separator: " ")
    }
}
