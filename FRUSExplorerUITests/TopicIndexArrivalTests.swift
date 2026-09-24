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
/// well as the first; Back from a volume opened out of the index returns to the area and search the
/// reader left; and Browse ▸ Topics afterwards opens the whole index.
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
/// door did nothing — the defect again, one tap later. The index now observes its host's waiting
/// delivery, which it empties as it lands one, and each hand-off is posted as a new
/// `SubjectIndexGrouping.Arrival`; round 2 is the check that the second one reaches the view.
/// (Emptying alone makes it a change here; the identity is defensive, for a slot that was NOT
/// emptied, which `SubjectIndexGroupingTests.postingIsANewDeliveryEveryTime` pins.)
///
/// ## Why Back from a volume
/// The iPad two-pane draws only the path's last level, so a covering volume opened from a topic's
/// sheet replaces the index, and Back mounts a NEW one. While the index held the reader's search and
/// chip itself, that new index started empty and the reader came back to all 491 topics instead of
/// the area they left — where a phone's navigation stack keeps the index alive under the volume and
/// always kept both. The host holds them now (`SubjectIndexGrouping.HostState`);
/// `testBackFromAVolumeKeepsTheAreaAndTheSearch` is the device check, and the phone run is its
/// control.
///
/// ## Why the Topics row is tapped after a hand-off
/// The corpus root's Topics row hands nothing off, so it must open the whole index — and with the
/// host holding the index's state, only an explicit reset (`BrowserViewModel.openTopicIndex()`)
/// does that. Before #1365 the host's slot kept its last hand-off and the row re-landed it; after
/// the state moved into the host, a row that only selected the level would show whatever the host
/// still held. `testTopicsRowAfterAHandOffOpensTheWholeIndex` taps it after a door. In the
/// two-pane it first taps it BESIDE the index, still on screen: the path assignment is then equal
/// and the same index view stays, so the reset is all that can bring the whole index back.
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
/// Back at depth one, so it chooses People. Going back from a volume is Back on both: the bar's on a
/// phone, the detail pane's own on the two-pane. Animations are off because every assertion reads a
/// screen at rest.
///
/// Version history:
///   1.0 — 2026-09-23: #1365
///   1.1 — 2026-09-24: #1365 review — runs on the iPad two-pane (the collapsed search is revealed,
///          and the field is matched by its prompt); round 1's precondition can fail; the
///          Topics-row test for the emptied slot
///   1.2 — 2026-09-24: #1365 review, round 2 — Back from a covering volume keeps the area and the
///          search; the Topics row is also tapped beside a narrowed index in the two-pane
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
    /// A covering-volume row's accessibility identifier, on a topic's sheet.
    private static let volumeRowID = "subjects.detail.volume"
    /// The chip after the door, with "Berlin" typed inside the area.
    private static let searchedChip = "Topic area: Cold War — 1 of 6 topics"

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
        XCTAssertEqual(chip.label, Self.searchedChip,
                       "With the search listing one of the area's six topics, the chip must say so")
        takeAreaDoor(from: Self.subject)
        assertWholeAreaListed(round: 2)
    }

    /// A covering volume opened from a topic's sheet, then Back: the index must come back narrowed
    /// to the area the reader took and filtered by the search they typed inside it (#1365 review).
    /// The two-pane mounts a new index here; the phone's stack keeps the old one, so the phone is
    /// this test's control.
    func testBackFromAVolumeKeepsTheAreaAndTheSearch() throws {
        launch()
        openTopicIndex()

        search("Berlin")
        XCTAssertTrue(subjectRow(Self.subject).waitForExistence(timeout: 5),
                      "Searching \"Berlin\" does not list \(Self.subject)")
        takeAreaDoor(from: Self.subject)
        assertWholeAreaListed(round: 1)
        search("Berlin")
        let chip = element(Self.chipID)
        XCTAssertTrue(chip.waitForExistence(timeout: 5), "The chip vanished when the reader searched")
        XCTAssertEqual(chip.label, Self.searchedChip,
                       "Precondition: the search inside the area should list one of its six topics")

        openCoveringVolume(from: Self.subject)
        goBackFromTheVolume()
        XCTAssertTrue(chip.waitForExistence(timeout: 10), """
            Back from the volume returned to an index with no topic-area chip: the area the reader \
            took is gone. Buttons: \(visibleButtonLabels())
            """)
        XCTAssertEqual(chip.label, Self.searchedChip, """
            Back from the volume kept the area but not the reader's search "Berlin" — the chip must \
            still count one of the area's six topics
            """)
        XCTAssertTrue(subjectRow(Self.subject).waitForExistence(timeout: 5),
                      "\(Self.subject), the one topic the search lists, is not listed after Back")
        XCTAssertFalse(app.navigationBars[Self.subject].exists,
                       "\(Self.subject)'s sheet, closed when the volume opened, came back with the index")
    }

    /// Browse ▸ Topics hands nothing off, so it must open the whole index even after a door has
    /// landed an area — neither re-land that door's area nor keep what the host holds (#1365
    /// review). The two-pane taps it twice: beside the narrowed index, and after leaving it.
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

        if isTwoPane {
            // The Browse root is the list pane beside the index, so its Topics row can be tapped
            // with the index still the level on screen. The same index view stays; only a reset of
            // what the host holds brings the whole index back.
            tapTopicsRow()
            assertWholeIndex(after: "Browse ▸ Topics, tapped beside the narrowed index,")
            takeAreaDoor(from: Self.firstTopic)
            XCTAssertTrue(chip.waitForExistence(timeout: 10),
                          "Precondition: the door landed no chip the second time")
        }

        leaveTheIndex()
        tapTopicsRow()
        assertWholeIndex(after: "Browse ▸ Topics")
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

    /// Whether Browse is two panes: the index sits beside the root with no Back in the bar. Read
    /// while the index is on screen at depth one.
    private var isTwoPane: Bool {
        !app.navigationBars.buttons["BackButton"].firstMatch.exists
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
        let sheet = openSheet(of: name)
        let door = element(Self.doorID)
        scrollIntoView(door)
        XCTAssertTrue(door.exists, "\(name)'s sheet offers no topic-area door")
        door.tap()
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 5), "\(name)'s sheet did not close")
    }

    /// Opens a subject's sheet and taps its first covering volume, which opens that volume in
    /// Browse — replacing the index in the two-pane, pushed over it on a phone.
    private func openCoveringVolume(from name: String) {
        let sheet = openSheet(of: name)
        let volume = element(Self.volumeRowID)
        scrollIntoView(volume)
        XCTAssertTrue(volume.exists, "\(name)'s sheet lists no covering volume")
        volume.tap()
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 5), "\(name)'s sheet did not close")
        XCTAssertTrue(element(Self.chipID).waitForNonExistence(timeout: 10), """
            The volume did not open: the Topic index is still on screen. \
            Buttons: \(visibleButtonLabels())
            """)
    }

    /// Goes back from a volume to the level under it: the bar's Back on a phone, the detail pane's
    /// own Back in the two-pane, which has no navigation container to put one in the bar.
    private func goBackFromTheVolume() {
        let barBack = app.navigationBars.buttons["BackButton"].firstMatch
        if barBack.waitForExistence(timeout: 3) {
            barBack.tap()
            return
        }
        let paneBack = app.buttons["Back"].firstMatch
        XCTAssertTrue(paneBack.waitForExistence(timeout: 5), """
            The volume offers no Back, in the bar or in the detail pane. \
            Buttons: \(visibleButtonLabels())
            """)
        paneBack.tap()
    }

    /// Opens a subject's sheet from the list, and returns its navigation bar.
    private func openSheet(of name: String) -> XCUIElement {
        let row = subjectRow(name)
        XCTAssertTrue(row.waitForExistence(timeout: 5), "\(name) is not listed")
        row.tap()
        let sheet = app.navigationBars[name]
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "\(name)'s sheet did not open")
        return sheet
    }

    /// Swipes the open sheet up until `element` is on screen, or gives up after eight swipes.
    private func scrollIntoView(_ element: XCUIElement) {
        let window = app.windows.firstMatch.frame
        var swipes = 0
        while !(element.exists && window.contains(CGPoint(x: element.frame.midX, y: element.frame.midY))),
              swipes < 8 {
            app.swipeUp()
            swipes += 1
        }
    }

    /// The whole index: the second topic, outside every area the tests land, is listed, and no
    /// chip is shown.
    private func assertWholeIndex(after step: String) {
        let chip = element(Self.chipID)
        let listed = subjectRow(Self.secondTopic).waitForExistence(timeout: 10)
        XCTAssertFalse(chip.exists, """
            \(step) reopened the index under "\(chip.label)" — a door taken before it, or what the \
            host still held, where the row asks for the whole index.
            """)
        XCTAssertTrue(listed, """
            \(step) must list the whole index, \(Self.secondTopic) included. \
            Buttons: \(visibleButtonLabels())
            """)
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
