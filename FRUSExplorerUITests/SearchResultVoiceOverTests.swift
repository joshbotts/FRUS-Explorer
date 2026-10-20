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

// MARK: - SearchResultVoiceOverTests (#1684)

/// What VoiceOver says of a search result on iPhone and iPad, and the row's actions for its tags.
///
/// ## What it reads, and how
/// A result row is one button, and its accessibility label replaces everything the row draws. The
/// suite reads that label, and then **listens to VoiceOver itself**: iOS 27's VoiceOver service for UI
/// tests (`XCUIDevice.voiceOverService`) turns VoiceOver on in the simulator, moves its cursor, and
/// returns what it spoke. A flick up (`swipeUp()`) with VoiceOver on moves through the focused
/// element's actions, as a reader's does, and VoiceOver speaks each. On the code before #1684 each row
/// said its heading alone ("UI Test Spoken Document Button Actions available"), and its actions were
/// Add to Collection…, Add Tags… and VoiceOver's own Activate Default.
///
/// **Three things measured about the service** (iPhone 17, iOS 27.0, 2026-10-19):
/// - **It returns the first 64 characters of what VoiceOver speaks** ("Toggle filters Button Filter
///   results by volume, date range, docu"), so speech is compared up to that length, and the whole
///   label is read from the element (`label`).
/// - **The cursor stops on the last element** and says it again at each step.
/// - **A tap goes to the element under it, not to VoiceOver.** A double tap, which a reader uses to do
///   the action VoiceOver last spoke, opened the row under it: at the screen's centre, the editorial
///   note's row; on the row VoiceOver was on, its document; on the empty list under the rows, nothing.
///   Ctrl-Option-Space did nothing either. So the suite cannot make VoiceOver do a custom action. The
///   action's words are VoiceOver's own, read from it; what it does is the chip's tap, which the suite
///   drives (`tapTheTagChip(of:)`), and `SearchResultAccessibilityTests` holds the action to the
///   chip's function.
///
/// ## Fixture
/// `FRUS_UI_TEST_SEED_SPOKEN_VOLUME` writes the spoken-row volume (`UITestVolumeSeeder.spokenVolumeXML()`):
/// a document numbered 7 in `@n` and not in its head, dated and classified "Secret; Nodis"; an editorial
/// note numbered 8; and a preface, which is front matter. One keyword search lists the three. The tag
/// is made in the row's own menu (Add Tags…), so the test also drives the tagging a reader does.
///
/// ## Devices
/// iPhone 17 and iPad Pro 13-inch (M5), `OS=27.0`, with the iOS 27 timeout flags; three tests, none
/// skipped there. Under iOS 26 two tests skip and the third reads the labels without listening: the
/// service is iOS 27's.
///
/// Version history:
///   1.0 — #1684: initial implementation
@MainActor
final class SearchResultVoiceOverTests: XCTestCase {

    /// The word every section of the spoken-row volume holds (`UITestVolumeSeeder.spokenQueryWord`).
    private static let query = "xylograph"
    /// `d7`'s heading: numbered 7 in `@n`, dated, classified "Secret; Nodis".
    private static let document = "UI Test Spoken Document"
    /// `d8`'s heading: an editorial note, numbered 8.
    private static let editorialNote = "UI Test Spoken Editorial Note"
    /// The preface's heading: front matter.
    private static let preface = "UI Test Spoken Preface"
    /// The tag the tagging test makes. The UI-test store is in memory, so no earlier run's tag of
    /// this name is there.
    private static let tagName = "UI Test Spoken Tag"

    /// What each row's label must say: the heading, then the row as it is drawn (decision 73). The
    /// number is where the row draws it, the volume id as printed, the classification chip's own
    /// words, then the badge.
    private static let labels: [(heading: String, label: String)] = [
        (document, "7. UI Test Spoken Document, Washington, May 4, 1962, uitest-spoken-01, "
            + "Classification markings: Secret; Nodis"),
        (editorialNote, "8. UI Test Spoken Editorial Note, uitest-spoken-01, Editorial Note"),
        (preface, "UI Test Spoken Preface, uitest-spoken-01, Front Matter"),
    ]

    /// `d7`'s label once it carries the suite's tag.
    private static var taggedDocumentLabel: String { labels[0].label + ", Tags: " + tagName }

    /// The name of the row's action for the suite's tag.
    private static var filterAction: String { "Filter by " + tagName }

    /// How long a wait waits: long, because a wait that is met returns at once.
    private static let patience: TimeInterval = 30

    /// How much of what VoiceOver speaks the service returns: its first 64 characters (iOS 27.0).
    private static let utteranceLength = 64

    /// What VoiceOver speaks first of a row with `label`, as far as the service returns it: the label,
    /// then that the row is a button.
    private static func opening(of label: String) -> String {
        String((label + " Button").prefix(utteranceLength))
    }

    /// Resolves the Search tab across every tab-bar representation.
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    /// The application under test.
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        // A run that ended inside a test could have left VoiceOver on.
        turnVoiceOverOff()
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_DISABLE_ANIMATIONS"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_SPOKEN_VOLUME"] = "1"
        app.launchArguments = UITestLaunch.arguments(startingOn: .search)
        app.launch()
        XCTAssertTrue(navigator.select(.search, resolveTimeout: 15).tapped,
                      "Could not open the Search tab, so this suite would read another screen")
    }

    override func tearDown() async throws {
        turnVoiceOverOff()
        if let app, app.state == .runningForeground {
            let cancel = app.navigationBars["Tag 1 Document"].buttons["Cancel"].firstMatch
            if cancel.exists { cancel.tap() }
            let done = app.descendants(matching: .any).matching(identifier: "search.selection.done").firstMatch
            if done.exists { done.tap() }
        }
        UITestPresentation.dismissAnyPresentation(in: app)
        app?.terminate()
        app = nil
    }

    // MARK: - Tests

    /// Each row's label says what the row draws, heading first, and VoiceOver says it.
    func testEachRowSaysWhatItDraws() throws {
        runTheSearch()
        for (heading, label) in Self.labels {
            XCTAssertEqual(resultRow(heading).label, label, "The label VoiceOver is given for the row of \(heading)")
        }

        guard #available(iOS 27.0, *) else { return }
        let voiceOver = XCUIDevice.shared.voiceOverService
        try voiceOver.enable()
        var heard: [String: String] = [:]
        for _ in 1...40 where heard.count < Self.labels.count {
            let spoken = try voiceOver.moveForward().utterance
            if let row = Self.labels.first(where: { spoken.contains($0.heading) }) { heard[row.heading] = spoken }
        }
        for (heading, label) in Self.labels {
            let spoken = try XCTUnwrap(heard[heading], "VoiceOver never reached the row of \(heading). It heard: \(heard)")
            XCTAssertTrue(spoken.hasPrefix(Self.opening(of: label)),
                          "VoiceOver says \"\(spoken)\" of the row of \(heading), where it should begin \"\(Self.opening(of: label))\"")
        }
    }

    /// A tag the row carries is said last in its label, VoiceOver offers it as an action after the
    /// row's two, and the tag's chip, whose function the action calls, filters the search to the
    /// tagged document.
    func testATagIsSaidAndOfferedAsAnActionThatFilters() throws {
        guard #available(iOS 27.0, *) else { throw XCTSkip("Listens through iOS 27's VoiceOver service") }
        runTheSearch()
        tag(Self.document)
        let row = resultRow(Self.document)
        let said = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", Self.taggedDocumentLabel),
                                             object: row)
        XCTAssertEqual(XCTWaiter.wait(for: [said], timeout: Self.patience), .completed, """
            Once tagged, the row's label reads "\(row.label)", where it should end with its tag: \
            "\(Self.taggedDocumentLabel)"
            """)

        let voiceOver = XCUIDevice.shared.voiceOverService
        try voiceOver.enable()
        try moveVoiceOver(to: Self.taggedDocumentLabel)
        let actions = try flickThroughTheActions(until: Self.filterAction)
        XCTAssertEqual(actions, ["Add to Collection…", "Add Tags…", Self.filterAction],
                       "The row's actions, in the order VoiceOver reads them")
        try voiceOver.disable()

        // What the action does is what the chip does: the search keeps the tagged document and loses
        // the two the tag is not on.
        tapTheTagChip(of: row)
        let one = app.staticTexts["1 result"].firstMatch
        if !one.waitForExistence(timeout: Self.patience) { attachTheScreen(named: "After the tag chip") }
        XCTAssertTrue(one.exists, """
            The tag's chip did not narrow the search to the one document that carries the tag. \
            Texts: \(visibleTexts()). Buttons: \(visibleButtonLabels())
            """)
        XCTAssertTrue(row.waitForExistence(timeout: Self.patience),
                      "Filtering by \(Self.tagName) lost the row of the document that carries it")
        for heading in [Self.editorialNote, Self.preface] {
            XCTAssertFalse(resultRow(heading).exists,
                           "Filtering by \(Self.tagName) left the row of \(heading), which does not carry the tag")
        }
    }

    /// While results are being selected a tap on a tag chip picks its row and filters nothing, as
    /// the row's own activation does, so the row offers no action for its tag.
    func testSelectionOffersNoActionForATag() throws {
        guard #available(iOS 27.0, *) else { throw XCTSkip("Listens through iOS 27's VoiceOver service") }
        runTheSearch()
        tag(Self.document)
        let row = resultRow(Self.document)
        let said = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", Self.taggedDocumentLabel),
                                             object: row)
        XCTAssertEqual(XCTWaiter.wait(for: [said], timeout: Self.patience), .completed,
                       "Once tagged, the row's label reads \"\(row.label)\"")
        enterSelection()

        let voiceOver = XCUIDevice.shared.voiceOverService
        try voiceOver.enable()
        try moveVoiceOver(to: Self.taggedDocumentLabel)
        let actions = try flickThroughTheActions(until: Self.filterAction)
        XCTAssertFalse(actions.contains(Self.filterAction), "In selection the row offers \(Self.filterAction): \(actions)")
        XCTAssertTrue(actions.contains("Add Tags…"), "The row's actions in selection, as VoiceOver read them: \(actions)")
    }

    // MARK: - Steps

    /// A result row, by the heading it draws. Found by `CONTAINS`, since a row that draws its number
    /// says the number first.
    private func resultRow(_ heading: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", heading)).firstMatch
    }

    /// Runs the keyword search and waits for its three rows. The volume is indexed during launch,
    /// and a search that runs first lists nothing, so the query is submitted until the rows are there.
    private func runTheSearch(file: StaticString = #filePath, line: UInt = #line) {
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: Self.patience), "The Search tab shows no search field",
                      file: file, line: line)
        for attempt in 1...5 {
            field.tap()
            if attempt > 1, let typed = field.value as? String, typed == Self.query {
                field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: typed.count))
            }
            field.typeText(Self.query + "\n")
            if resultRow(Self.document).waitForExistence(timeout: 12),
               Self.labels.allSatisfy({ resultRow($0.heading).waitForExistence(timeout: 5) }) {
                return
            }
        }
        XCTFail("""
            A search for "\(Self.query)" did not list the spoken-row volume's three sections in five attempts. \
            Buttons: \(visibleButtonLabels())
            """, file: file, line: line)
    }

    /// Gives a row's document the suite's tag, from the row's menu: Add Tags…, a new tag, Done.
    private func tag(_ heading: String, file: StaticString = #filePath, line: UInt = #line) {
        let row = resultRow(heading)
        XCTAssertTrue(row.waitForExistence(timeout: Self.patience), "No row for \(heading)", file: file, line: line)
        row.press(forDuration: 1.2)
        let item = app.buttons["Add Tags…"].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: Self.patience),
                      "The row's menu has no Add Tags…. Buttons: \(visibleButtonLabels())", file: file, line: line)
        item.tap()
        let picker = app.navigationBars["Tag 1 Document"]
        XCTAssertTrue(picker.waitForExistence(timeout: Self.patience), "Add Tags… did not present the tag picker",
                      file: file, line: line)
        let field = app.textFields["New tag name"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: Self.patience), "The tag picker has no New Tag field",
                      file: file, line: line)
        field.tap()
        // Return makes the tag, which the picker lists switched on.
        field.typeText(Self.tagName + "\n")
        let made = app.switches.matching(NSPredicate(format: "label BEGINSWITH %@", Self.tagName)).firstMatch
        XCTAssertTrue(made.waitForExistence(timeout: Self.patience), "The tag made in the picker is not listed",
                      file: file, line: line)
        picker.buttons["Done"].firstMatch.tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: picker)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: Self.patience), .completed, "The tag picker did not close",
                       file: file, line: line)
    }

    /// More ▸ Select Results, and the selection bar's Done to wait for.
    private func enterSelection(file: StaticString = #filePath, line: UInt = #line) {
        let more = app.descendants(matching: .any).matching(identifier: "search.actions.more").firstMatch
        XCTAssertTrue(more.waitForExistence(timeout: Self.patience), "The actions bar has no More menu", file: file, line: line)
        more.tap()
        let item = app.buttons["Select Results"].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: Self.patience), "The More menu has no Select Results",
                      file: file, line: line)
        item.tap()
        let done = app.descendants(matching: .any).matching(identifier: "search.selection.done").firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: Self.patience), "Select Results did not show the selection bar",
                      file: file, line: line)
    }

    /// Moves VoiceOver's cursor forward until it speaks the row whose label is `label`.
    @available(iOS 27.0, *)
    private func moveVoiceOver(to label: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let voiceOver = XCUIDevice.shared.voiceOverService
        var heard: [String] = []
        // The cursor stops on the last element and says it again, so a row not met in the first forty
        // steps is not on the screen.
        for _ in 1...40 {
            let spoken = try voiceOver.moveForward().utterance
            if spoken.hasPrefix(Self.opening(of: label)) { return }
            heard.append(spoken)
        }
        XCTFail("VoiceOver never spoke a row beginning \"\(Self.opening(of: label))\". It spoke: \(heard)",
                file: file, line: line)
    }

    /// Flicks up through the focused element's actions, as a VoiceOver reader does, until VoiceOver
    /// speaks `wanted` or has gone round them once ("Activate Default" is VoiceOver's own last).
    ///
    /// - Returns: The actions spoken, in order, up to `wanted` or up to the round's end.
    @available(iOS 27.0, *)
    private func flickThroughTheActions(until wanted: String) throws -> [String] {
        let voiceOver = XCUIDevice.shared.voiceOverService
        var spoken: [String] = []
        for _ in 1...8 {
            app.swipeUp()
            let action = try voiceOver.currentSpeech().utterance
            if action == "Activate Default" { break }
            spoken.append(action)
            if action == wanted { break }
        }
        return spoken
    }

    /// Taps a row's first tag chip, as a sighted reader does. The chip is a button inside the row's
    /// button, which the accessibility tree does not show as one, so the tap lands on the start of the
    /// row's strip of chips, its scroll view.
    private func tapTheTagChip(of row: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let strip = row.scrollViews.firstMatch
        XCTAssertTrue(strip.waitForExistence(timeout: Self.patience), "The row draws no tag chips", file: file, line: line)
        strip.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5)).withOffset(CGVector(dx: 12, dy: 0)).tap()
    }

    /// Turns VoiceOver off if a test left it on.
    private func turnVoiceOverOff() {
        guard #available(iOS 27.0, *) else { return }
        let voiceOver = XCUIDevice.shared.voiceOverService
        if voiceOver.isEnabled { try? voiceOver.disable() }
    }

    /// The labels of the buttons on screen, for a failure message.
    private func visibleButtonLabels() -> [String] { labels(of: .button) }

    /// The texts on screen, for a failure message.
    private func visibleTexts() -> [String] { labels(of: .staticText) }

    /// The labels of the elements of one type on screen, from one snapshot: read one element at a
    /// time, a list that changes under the reads fails the read ("No matches found for Element at
    /// index 5").
    private func labels(of type: XCUIElement.ElementType) -> [String] {
        guard let root = try? app.snapshot() else { return [] }
        var found: [String] = []
        var stack = [root]
        while let node = stack.popLast(), found.count < 40 {
            if node.elementType == type, !node.label.isEmpty { found.append(node.label) }
            stack.append(contentsOf: node.children.reversed())
        }
        return found
    }

    /// Keeps a screenshot of the screen with the run's results, for a failure.
    private func attachTheScreen(named name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
