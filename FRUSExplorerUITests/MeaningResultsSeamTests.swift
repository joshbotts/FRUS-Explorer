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
import notify

// MARK: - MeaningResultsSeamTests (#1577 lane 3)

/// Meaning results, on screen, through `UITestMeaningSeeder`.
///
/// ## What this is the first test of
/// Until this suite no UI test reached a Meaning result: a Meaning search needs the 310 MB query
/// encoder, which no simulator has and no test may download. `FRUS_UI_TEST_SEED_MEANING` stands in
/// for the encoder and gives the searcher a match-file store of the seam's own, holding one file,
/// made for the seeded fixture volume. The searcher's code, the backend, the bundled index and the
/// bundled sign bits are the app's own. So these rows are what a reader's would be, for a question
/// whose answer the test knows.
///
/// The store is the seam's own so that the simulator's state cannot reach these rows: a match file
/// the simulator's app had fetched for another volume would score that volume's candidates, and a
/// far question's 800 candidates lie in 124 volumes. The launch also turns the reader's automatic
/// match-file download off, which keeps the run offline.
///
/// ## The two questions, and why there are two
/// Every question is answered as if it were the fixture's second document, so a plain Meaning
/// search lists the fixture's three documents that have vectors, that one first: 100, 32 and 3
/// percent. They are three of 80 hits. The real volume has 120 documents, 80 of whose rows are
/// among the question's 800 candidates, and the seam's match file scores them all; the fixture
/// holds three, so the strip above the list says that 77 close matches are not listed and that 720
/// possible matches could not be scored. (Through build 50, with EmbeddingGemma 300m's bits and
/// no score calibration, the three read 100, 65 and 61 percent; `UITestMeaningSeeder`'s header
/// says why the calibrated figures of the seam's sign vectors sit lower.)
///
/// A question that holds the word "afield" is answered as a document of another volume, far from
/// all three: a plain search then lists none of them, and a search **inside a working corpus** of
/// them lists all three, Three, Two and One, each at 0 percent (24, 24 and 16 through build 50). That last is what #1577 lane 1 changed. Before
/// it, a Meaning search inside a set took the whole series' closest hundred and kept the members
/// among them, which for the far question is none
/// (`testAFarQuestionInsideAWorkingCorpusRanksEveryMemberWithAVector` lists no row on that tree:
/// the pull request quotes the run).
///
/// The figures are the bundled artifacts' own, and `UITestMeaningSeederTests` holds them there, so
/// a regenerated bundle that moves them fails a unit test that says which figure moved.
///
/// ## Fixture
/// `FRUS_UI_TEST_SEED_VOLUME` writes six documents: three whose ids the real volume has, and so
/// have bundled vectors, and three of the fixture's own, which have none. The working corpus is
/// saved and applied by the test itself, in the UI-test store, which is in memory.
///
/// ## Devices
/// An iPhone and an iPad; nothing skips. A row's score is read from its accessibility value, which
/// this lane gave it: the row's label was its heading alone (since #1684, the row as drawn).
///
/// Version history:
///   1.0 — #1577 lane 3: initial implementation
///   1.1 — B4 (#1659): the rows' order and percentages for EmbeddingGemma 2's bits and calibration
///   1.2 — 2026-10-15: `submit` empties the field with its Clear text button and waits for the list to
///          empty, so `ask` reads the new question's rows and not the last search's. The third test's
///          Filters step failed on iPhone 17 (iOS 27.0) from a defect in Search, not here:
///          `FilterVolumeListTests`, below, is its guard.
@MainActor
final class MeaningResultsSeamTests: XCTestCase {

    private var app: XCUIApplication!
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    /// The volume `UITestVolumeSeeder` writes and `UITestMeaningSeeder` plants a match file for.
    private static let seededVolumeId = "frus1961-63v06"
    /// The start of the three titles that have vectors. The fixture's other three begin "UI Test
    /// Nested" and "UI Test Twin".
    private static let titlePrefix = "UI Test Document"
    /// A phrase every fixture document holds and no published document does.
    private static let fixturePhrase = "\"Synthetic UI-test content\""
    private static let nearQuestion = "how did the exchange of letters begin"
    private static let farQuestion = "a question from far afield"
    private static let corpusName = "Seam Corpus"
    /// Long, because a wait that is met returns at once and this Mac is not always quiet.
    private static let patience: TimeInterval = 30

    override func setUp() async throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        // Every step waits on a menu, a sheet or a list, and XCTest's idle counter drifts on
        // iOS 27 (CLAUDE.md, #1320).
        app.launchEnvironment["FRUS_UI_TEST_DISABLE_ANIMATIONS"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_VOLUME"] = Self.seededVolumeId
        app.launchEnvironment["FRUS_UI_TEST_SEED_MEANING"] = "1"
        app.launchArguments = UITestLaunch.arguments(startingOn: .search)
        // The reader's own "download vectors automatically" switch, off: the app then asks the
        // network for no match file on the seeded volume's account. The seam's searcher asks for
        // none in any case. `<false/>` and not `NO`, since the app reads the key with `as? Bool`;
        // the key is `SettingsKeys.autoDownloadSemanticShards`, which a UI suite cannot name.
        app.launchArguments += ["-frus.semantic.autoDownloadShards", "<false/>"]
        app.launch()
        XCTAssertTrue(navigator.select(.search, resolveTimeout: 15).tapped,
                      "Could not open the Search tab, so this suite would read another screen")
    }

    override func tearDown() async throws {
        if let app {
            if app.state == .runningForeground {
                let cancel = app.navigationBars["Save Working Corpus"].buttons["Cancel"].firstMatch
                if cancel.exists { cancel.tap() }
                UITestPresentation.dismissAnyPresentation(in: app)
            }
            app.terminate()
        }
        app = nil
    }

    // MARK: Tests

    /// The plain search: every question is the fixture's second document, so that document is
    /// first at 100 percent and the other two with vectors follow it.
    func testAMeaningSearchListsTheFixtureDocumentsWithTheirScores() throws {
        chooseMeaning()
        let rows = ask(Self.nearQuestion, expecting: 3)
        XCTAssertEqual(rows.map(\.title),
                       ["UI Test Document Two", "UI Test Document One", "UI Test Document Three"],
                       "A Meaning list is in order of score, and the question's own document is first")
        XCTAssertEqual(rows.map(\.score),
                       ["Semantic match 100 percent", "Semantic match 32 percent", "Semantic match 3 percent"])
    }

    /// The control for the next test, on this tree: outside any set the far question reaches none
    /// of the fixture's documents, so nothing is listed.
    ///
    /// The near question is asked first. An empty list alone would not show that the far question
    /// was what emptied it: a Meaning search that runs before the launch has indexed the fixture
    /// lists nothing either. Three rows first show that the seam is answering and the index holds
    /// the fixture, and then the far question takes them away.
    func testAFarQuestionOutsideAnySetListsNoFixtureDocument() throws {
        chooseMeaning()
        _ = ask(Self.nearQuestion, expecting: 3)

        submit(Self.farQuestion)
        // A Meaning search that ran and listed nothing says so in the Meaning empty state
        // (`search.semantic.empty.title`). The wait is on that, so "no rows" is read after the
        // search and not before it.
        let empty = app.staticTexts["No semantic matches yet"].firstMatch
        XCTAssertTrue(empty.waitForExistence(timeout: Self.patience), """
            The far question showed neither rows nor the Meaning empty state. Texts on screen: \
            \(app.staticTexts.allElementsBoundByIndex.prefix(30).map { "\"\($0.label)\"" }.joined(separator: ", "))
            """)
        XCTAssertEqual(fixtureRows.count, 0, "A far question outside any set listed fixture documents")
        // Why it is empty: every one of the 800 candidates is in a volume the seam's store has no
        // file for. The near question leaves 720 unscored, so this figure is the far question's own.
        let unscored = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '800 possible matches'")).firstMatch
        XCTAssertTrue(unscored.waitForExistence(timeout: Self.patience), """
            The strip does not say that the far question's 800 candidates went unscored. Texts on screen: \
            \(app.staticTexts.allElementsBoundByIndex.prefix(30).map { "\"\($0.label)\"" }.joined(separator: ", "))
            """)
    }

    /// Inside a working corpus every member that has a vector is ranked, however far the question
    /// is from it (#1577 lane 1). The corpus is the fixture's six documents; three have vectors.
    func testAFarQuestionInsideAWorkingCorpusRanksEveryMemberWithAVector() throws {
        // A keyword search that lists the fixture's documents, saved as a working corpus.
        submit(Self.fixturePhrase)
        XCTAssertTrue(fixtureRows.firstMatch.waitForExistence(timeout: Self.patience),
                      "The keyword search for the fixture's phrase listed none of its documents")
        saveTheResultsAsAWorkingCorpus()
        applyTheWorkingCorpus()

        chooseMeaning()
        let rows = ask(Self.farQuestion, expecting: 3)
        XCTAssertEqual(rows.map(\.title),
                       ["UI Test Document Three", "UI Test Document Two", "UI Test Document One"],
                       "Inside the corpus the three members with vectors are ranked, closest first")
        // Each is below the score calibration's offset, so each reads 0 percent; the order above is
        // the cosine's (186, 187 and 201 bits from the question).
        XCTAssertEqual(rows.map(\.score),
                       ["Semantic match 0 percent", "Semantic match 0 percent", "Semantic match 0 percent"])
    }

    // MARK: Steps

    /// The result rows that are the fixture's documents with vectors.
    private var fixtureRows: XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", Self.titlePrefix))
    }

    /// Chooses Meaning in the Keywords | Meaning picker. The picker is drawn once the launch has
    /// loaded the bundled vectors and built the searcher, which is after the first frame and after
    /// the launch's other work: on a simulator just booted, with this Mac busy, it was not there
    /// in thirty seconds (iPad Pro 13-inch, 2026-10-11). So this wait is longer than the others.
    private func chooseMeaning(file: StaticString = #filePath, line: UInt = #line) {
        let meaning = app.segmentedControls.buttons["Meaning"].firstMatch
        XCTAssertTrue(meaning.waitForExistence(timeout: 3 * Self.patience),
                      "Search shows no Keywords | Meaning picker: the semantic stack did not start", file: file, line: line)
        meaning.tap()
    }

    /// Replaces the field's text with `text` and submits it.
    ///
    /// The field is emptied with its own Clear text button, not with delete keys. A tap on a field
    /// that already has the keyboard puts the cursor where it lands, and the keys then delete only
    /// what is before it: on an iPhone 17 (iOS 26.5) the far question went out as `a question from
    /// far afield content"`. Emptying the field empties the list too (Search clears its results
    /// when the text goes), and the wait for that is what lets ``ask(_:expecting:file:line:)`` wait
    /// for the new question's rows. Without it the third test asked while the list still held
    /// three fixture rows, from the Meaning search that choosing Meaning runs on the field's text,
    /// and read them while they were being replaced. On the same iPhone, with build 50's model, it
    /// read Three, Two, One: neither the order it replaced (Two, One, Three) nor the one the list
    /// settled on two seconds later (Two, Three, One).
    private func submit(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: Self.patience), "The Search tab shows no search field",
                      file: file, line: line)
        field.tap()
        if let typed = field.value as? String, !typed.isEmpty, typed != field.placeholderValue {
            let clear = field.buttons["Clear text"].firstMatch
            XCTAssertTrue(clear.waitForExistence(timeout: Self.patience),
                          "The search field holds \"\(typed)\" and shows no Clear text button", file: file, line: line)
            clear.tap()
            let emptied = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"),
                                                    object: fixtureRows.firstMatch)
            XCTAssertEqual(XCTWaiter.wait(for: [emptied], timeout: Self.patience), .completed,
                           "The field was emptied and the last search's rows are still listed", file: file, line: line)
            field.tap()
        }
        field.typeText(text + "\n")
    }

    /// Submits `question` until `count` fixture rows are listed, and reads them top to bottom.
    ///
    /// The fixture volume is indexed during launch, and a Meaning search that runs first finds its
    /// documents in the bundled index and no row for them in the search index, so it lists nothing.
    private func ask(_ question: String, expecting count: Int,
                     file: StaticString = #filePath, line: UInt = #line) -> [(title: String, score: String)] {
        for _ in 1...5 {
            submit(question, file: file, line: line)
            // The last of the rows expected: it exists once at least `count` are listed.
            if fixtureRows.element(boundBy: count - 1).waitForExistence(timeout: 12) { break }
        }
        let rows = fixtureRows.allElementsBoundByIndex
        if rows.count != count {
            print("[#1577] \"\(question)\" listed \(rows.count) fixture rows; buttons on screen: "
                  + app.buttons.allElementsBoundByIndex.prefix(40).map { "\"\($0.label)\"" }.joined(separator: ", "))
        }
        XCTAssertEqual(rows.count, count, "\"\(question)\" should list \(count) fixture documents", file: file, line: line)
        return rows.sorted { $0.frame.minY < $1.frame.minY }
            .map { (title: Self.heading(of: $0.label), score: ($0.value as? String) ?? "") }
    }

    /// A row's heading: its label up to the first comma. A result's label is its heading and then the
    /// rest of what the row draws, joined by commas (#1684), and no fixture heading holds a comma.
    private static func heading(of label: String) -> String {
        String(label.prefix { $0 != "," })
    }

    /// More ▸ Save as Working Corpus…, with a name, saved.
    private func saveTheResultsAsAWorkingCorpus(file: StaticString = #filePath, line: UInt = #line) {
        let more = app.descendants(matching: .any).matching(identifier: "search.actions.more").firstMatch
        XCTAssertTrue(more.waitForExistence(timeout: Self.patience), "The actions bar has no More menu", file: file, line: line)
        more.tap()
        let save = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Save as Working Corpus'")).firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: Self.patience), "The More menu has no Save as Working Corpus…",
                      file: file, line: line)
        save.tap()
        let sheet = app.navigationBars["Save Working Corpus"]
        XCTAssertTrue(sheet.waitForExistence(timeout: Self.patience), "Save as Working Corpus… opened no sheet",
                      file: file, line: line)
        let name = app.textFields["Corpus name"].firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: Self.patience), "The sheet has no name field", file: file, line: line)
        name.tap()
        name.typeText(Self.corpusName)
        let confirm = sheet.buttons["Save"].firstMatch
        XCTAssertTrue(confirm.isEnabled, "Save is dimmed with a name typed and results to keep", file: file, line: line)
        confirm.tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: sheet)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: Self.patience), .completed,
                       "The Save Working Corpus sheet did not close", file: file, line: line)
    }

    /// Filters ▸ My Working Corpora ▸ the corpus, then Done.
    private func applyTheWorkingCorpus(file: StaticString = #filePath, line: UInt = #line) {
        let filters = app.descendants(matching: .any).matching(identifier: "search.actions.filter").firstMatch
        XCTAssertTrue(filters.waitForExistence(timeout: Self.patience), "The actions bar has no Filters control",
                      file: file, line: line)
        filters.tap()
        let panel = app.navigationBars["Filters"]
        XCTAssertTrue(panel.waitForExistence(timeout: Self.patience), "Filters did not open", file: file, line: line)

        // The group is below the fold on an iPhone: bring it up, then open it.
        let group = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'My Working Corpora'")).firstMatch
        let corpus = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", Self.corpusName)).firstMatch
        var swipes = 0
        while !group.exists && !corpus.exists && swipes < 8 {
            app.swipeUp()
            swipes += 1
        }
        if !corpus.exists {
            XCTAssertTrue(group.waitForExistence(timeout: Self.patience), """
                Filters has no My Working Corpora group after \(swipes) swipes. Elements: \
                \(app.staticTexts.allElementsBoundByIndex.prefix(40).map { "\"\($0.label)\"" }.joined(separator: ", "))
                """, file: file, line: line)
            group.tap()
        }
        if !corpus.waitForExistence(timeout: 8) {
            // The group may have opened below the fold.
            app.swipeUp()
        }
        XCTAssertTrue(corpus.waitForExistence(timeout: Self.patience), """
            My Working Corpora does not list "\(Self.corpusName)". Buttons: \
            \(app.buttons.allElementsBoundByIndex.prefix(40).map { "\"\($0.label)\"" }.joined(separator: ", "))
            """, file: file, line: line)
        corpus.tap()
        let done = panel.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: Self.patience), "Filters has no Done", file: file, line: line)
        done.tap()
        let applied = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", Self.corpusName)).firstMatch
        XCTAssertTrue(applied.waitForExistence(timeout: Self.patience),
                      "No line says the search is inside \"\(Self.corpusName)\"", file: file, line: line)
    }
}

// MARK: - FilterVolumeListTests

/// Filters offers a volume that was indexed while the Search tab was on screen.
///
/// ## The defect
/// Search read the filter panel's volume list once, when the tab appeared, from the indexed set as it
/// stood then. The list gates four of the panel's groups: My Working Corpora, My Volume Scopes, By
/// Subject and Limit to Volumes. `MeaningResultsSeamTests`' third test met it on an iPhone 17 (iOS
/// 27.0) whose restored window opens on Search: the tab read the set a second before boot's own read
/// of the index began, and Filters had no My Working Corpora group to apply the corpus from. That
/// test sees the defect only where the app opens on Search, which the simulator's saved scene
/// decides, and only while boot's read loses the race; on an iPad Pro 13-inch whose saved scene opens
/// on Collections it passed. `SearchView.reloadAvailableVolumes` says what Search does now.
///
/// ## How this test makes it certain
/// The fixture is cold at launch (`FRUS_UI_TEST_COLD_SEEDED_VOLUME`), so the tab reads a set without
/// it whatever the timing. It is indexed only when the test, on Search, sends the signal that
/// finishes its download (`FRUS_UI_TEST_FINISH_SEEDED_DOWNLOAD_ON_SIGNAL`), and then by the app's own
/// post-download closure, as after any download. Nothing in between leaves the tab, so its `.task`
/// does not run again. A keyword search for the fixture's phrase says when the index holds it, so a
/// failure below is Filters' and not a slow index.
///
/// ## Devices
/// Any iPhone or iPad; nothing skips. A simulator that holds other indexed volumes draws Limit to
/// Volumes from the start, so the test looks for the fixture's own row in it, by its title.
///
/// Version history:
///   1.0 — 2026-10-15: initial implementation
@MainActor
final class FilterVolumeListTests: XCTestCase {

    private var app: XCUIApplication!
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    /// The seeded volume, `frus1961-63v06`, by words of its title that no other volume's title holds.
    private static let volumeTitle = "Kennedy-Khrushchev"
    /// The start of the fixture's document titles that a keyword search lists.
    private static let documentTitlePrefix = "UI Test Document"
    /// A phrase every fixture document holds and no published document does.
    private static let fixturePhrase = "\"Synthetic UI-test content\""
    /// Long, because a wait that is met returns at once and this Mac is not always quiet.
    private static let patience: TimeInterval = 30

    /// What this suite can tell the running app: `UITestBrowseSeams.Signal`'s raw value, repeated
    /// here because a UI suite cannot reference the app's constants.
    private enum SeamSignal: String {
        /// Finish the seeded volume's download (`FRUS_UI_TEST_FINISH_SEEDED_DOWNLOAD_ON_SIGNAL`).
        case finishSeededDownload = "bottsywattsy.FRUS-Explorer.uitest.finish-seeded-download"
    }

    override func setUp() async throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FRUS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_DISABLE_ANIMATIONS"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_SEED_VOLUME"] = "frus1961-63v06"
        app.launchEnvironment["FRUS_UI_TEST_COLD_SEEDED_VOLUME"] = "1"
        app.launchEnvironment["FRUS_UI_TEST_FINISH_SEEDED_DOWNLOAD_ON_SIGNAL"] = "1"
        app.launchArguments = UITestLaunch.arguments(startingOn: .search)
        // The post-download closure also fetches the volume's match file. The reader's own switch,
        // off, keeps the run offline; see `MeaningResultsSeamTests.setUp` for the spelling.
        app.launchArguments += ["-frus.semantic.autoDownloadShards", "<false/>"]
        app.launch()
        XCTAssertTrue(navigator.select(.search, resolveTimeout: 15).tapped,
                      "Could not open the Search tab, so this suite would read another screen")
    }

    override func tearDown() async throws {
        if let app {
            if app.state == .runningForeground {
                UITestPresentation.dismissAnyPresentation(in: app)
            }
            app.terminate()
        }
        app = nil
    }

    // MARK: Test

    func testFiltersOffersAVolumeIndexedWhileSearchIsOnScreen() throws {
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: Self.patience),
                      "The Search tab shows no search field")
        XCTAssertFalse(filtersOffersTheVolume(), """
            Filters offers the seeded volume before its download has finished, though the launch \
            un-indexed it (FRUS_UI_TEST_COLD_SEEDED_VOLUME). Something else indexed it, so what \
            follows would pass whatever Search does.
            """)
        send(.finishSeededDownload)

        // The app's own post-download closure indexes the volume. Once it has, a keyword search for
        // the fixture's phrase lists its documents.
        let documents = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", Self.documentTitlePrefix))
        let deadline = Date().addingTimeInterval(4 * Self.patience)
        repeat {
            search(for: Self.fixturePhrase)
        } while !documents.firstMatch.waitForExistence(timeout: 10) && Date() < deadline
        XCTAssertTrue(documents.firstMatch.exists,
                      "The seeded volume's download was finished and the index never listed its documents")

        XCTAssertTrue(filtersOffersTheVolume(), """
            The index holds the seeded volume, and Filters ▸ Limit to Volumes does not offer it: the \
            panel's volume list is still the one the tab read when it appeared, before the volume \
            was indexed. On an iPhone or iPad that holds no other indexed volume, Limit to Volumes \
            and the other groups the list gates are not drawn at all.
            """)
    }

    // MARK: Steps

    /// Sends `signal` to the app as a Darwin notification. The app registered for it at boot.
    private func send(_ signal: SeamSignal) {
        XCTAssertTrue(notify_post(signal.rawValue) == NOTIFY_STATUS_OK,
                      "The system refused to post \(signal.rawValue), so the volume will never be indexed")
    }

    /// Replaces the field's text with `text` and submits it, emptying the field with its Clear text
    /// button (see `MeaningResultsSeamTests.submit`).
    private func search(for text: String) {
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: Self.patience), "The Search tab shows no search field")
        field.tap()
        if let typed = field.value as? String, !typed.isEmpty, typed != field.placeholderValue {
            let clear = field.buttons["Clear text"].firstMatch
            XCTAssertTrue(clear.waitForExistence(timeout: Self.patience),
                          "The search field holds \"\(typed)\" and shows no Clear text button")
            clear.tap()
            field.tap()
        }
        field.typeText(text + "\n")
    }

    /// Whether Filters ▸ Limit to Volumes ▸ Volumes lists the seeded volume. Opens Filters and closes it.
    ///
    /// Limit to Volumes is drawn only while some volume is indexed, above Person; on an iPhone it can
    /// be below the fold. So the panel is swiped until its Volumes row or the Person header is on
    /// screen, and the Person header with no Volumes row above it means the group is not drawn.
    private func filtersOffersTheVolume() -> Bool {
        let filters = app.descendants(matching: .any).matching(identifier: "search.actions.filter").firstMatch
        XCTAssertTrue(filters.waitForExistence(timeout: Self.patience), "The actions bar has no Filters control")
        filters.tap()
        let panel = app.navigationBars["Filters"]
        XCTAssertTrue(panel.waitForExistence(timeout: Self.patience), "Filters did not open")
        defer {
            let done = panel.buttons["Done"].firstMatch
            if done.waitForExistence(timeout: Self.patience) { done.tap() }
            let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: panel)
            XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: Self.patience), .completed, "Filters did not close")
        }

        let volumesRow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Volumes'")).firstMatch
        let personHeader = app.staticTexts["Person"].firstMatch
        var swipes = 0
        while !volumesRow.exists && !personHeader.exists && swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        guard volumesRow.exists else { return false }
        volumesRow.tap()
        let list = app.navigationBars["Volumes"]
        XCTAssertTrue(list.waitForExistence(timeout: Self.patience), "Filters ▸ Volumes did not open")
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", Self.volumeTitle)).firstMatch
        let offered = row.waitForExistence(timeout: 5)
        // Back to the panel's root, where its Done is.
        list.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(panel.waitForExistence(timeout: Self.patience), "Filters ▸ Volumes did not go back")
        return offered
    }
}

// MARK: - MeaningStripFitTests

/// Search in Meaning mode at five text sizes on the two iPhone widths: the Keywords | Meaning control, the actions bar
/// and the Meaning strip under the search field, and a result between them and the tab shell's banner; and at AX5 the
/// whole caption, a tap away.
///
/// ## The defect it guards
/// The Meaning strip (`SemanticModeStrip`) is drawn in the top inset under the actions bar, and its sentences grew with
/// the reader's text size. A Meaning search adds to its opening what the run could not do, and the fixture's near
/// question gives it its longest caption: "77 close matches are not listed…" and "720 possible matches in 248 volumes
/// could not be scored…" (the `MeaningResultsSeamTests` header says why). At the accessibility sizes the inset was then
/// taller than the screen, and SwiftUI centres a view taller than its room, so the control and the actions bar went
/// above the screen and the list below it. Found by #1577 lane 7 on an iPhone 17 (iOS 27.0): the More menu at y −394 at
/// AX5, and no result row on screen at AX3 or AX5. A reader at those sizes could reach none of More, Sort or Filters in
/// Meaning mode. On the code before the fix this suite failed at AX3 and AX5 on an iPhone 17, the strip 857 and 1,530
/// points tall, and at AX1, AX3 and AX5 on an iPhone SE, 404, 896 and 1,785.
///
/// ## What it requires
/// Once the near question has listed the fixture's three, with the keyboard put away (the tab shell's banner gives way
/// to a keyboard, #1070): the control and the bar's five controls inside the window and under the search field's foot,
/// the bar under the control and above the banner; the strip starting under the bar and above the banner, with every
/// sentence of its caption in what VoiceOver reads; and the first result between the strip and the banner. At the
/// accessibility sizes the strip is one row, its ⓘ inside it and the window and 44 points each way, no less, as a
/// target, and no more, since the row is drawn at XXXL at most, and the row no taller than its ⓘ; at the standard
/// sizes the strip is the whole caption and offers no ⓘ. It requires the banner, which a simulator with no
/// iCloud account always shows, as `ResultSelectionBarFitTests` does. Each accessibility size proves it took effect by
/// the search field's height, and every run prints `[Meaning strip]` lines with the frames, pass or fail, and attaches
/// a screenshot of what it measured.
///
/// A sixth test opens the ⓘ at AX5 and requires the sheet to hold the whole caption, a paragraph to each part, starting
/// under its navigation bar, and its Done to close it.
///
/// Every frame is read from one accessibility snapshot (`XCUIElement.snapshot()`), as `TabShellBannerClearanceTests`
/// reads its lists: a query per frame costs 4 to 13 s under Xcode 27.1 (`SearchLayerBaseRowFitTests`).
///
/// ## Devices
/// An iPhone 17 (402 pt) and an iPhone SE (3rd generation, 375 pt, iOS 27), as for the other suites that measure
/// Search's top inset. It skips on an iPad.
///
/// Version history:
///   1.0 — the Meaning strip at the accessibility sizes: initial implementation
@MainActor
final class MeaningStripFitTests: XCTestCase {

    private var app: XCUIApplication!
    private lazy var navigator = TabBarNavigator { [unowned self] in self.app }

    /// The search field's height at the default text size, measured once per run.
    private static var defaultFieldHeight: CGFloat = 0
    private static let phoneOnlyReason =
        "iPhone-only: the suites that measure Search's top inset run on the two iPhone widths, where it is tightest"
    /// How every caption of the strip begins, and the row's own words at the accessibility sizes.
    private static let stripOpening = "Meaning search (experimental)"
    /// What only the near question's run that listed the fixture's three adds to the strip: of its 80 hits in the real
    /// volume the fixture holds three, and 720 of its 800 candidates lie in volumes the seam has no match file for.
    private static let disclosures = ["77 close matches are not listed",
                                      "720 possible matches in 248 volumes could not be scored"]
    /// The actions bar's controls, in the order the row lays them out.
    private static let barIdentifiers = ["search.actions.filter", "search.actions.examine", "search.actions.checklist",
                                         "search.actions.sort", "search.actions.more"]
    /// The title of the sheet the strip's ⓘ opens (`SemanticModeStrip.sheetTitle`).
    private static let sheetTitle = "Meaning Search"

    override func tearDown() async throws {
        if let app {
            LayerScreen(app: app).leave()
            app.terminate()
        }
        app = nil
    }

    func testMeaningStripFitsAtStandardSize() throws { try assertMeaningScreenFits(at: nil, named: "L") }
    func testMeaningStripFitsAtLargestStandardSize() throws {
        try assertMeaningScreenFits(at: "UICTContentSizeCategoryXXXL", named: "XXXL")
    }
    func testMeaningStripFitsAtFirstAccessibilitySize() throws {
        try assertMeaningScreenFits(at: "UICTContentSizeCategoryAccessibilityM", named: "AX1")
    }
    func testMeaningStripFitsAtMiddleAccessibilitySize() throws {
        try assertMeaningScreenFits(at: "UICTContentSizeCategoryAccessibilityXL", named: "AX3")
    }
    func testMeaningStripFitsAtLargestAccessibilitySize() throws {
        try assertMeaningScreenFits(at: "UICTContentSizeCategoryAccessibilityXXXL", named: "AX5")
    }

    /// The strip's ⓘ at AX5 opens the whole caption at the reader's size, a paragraph to each part.
    func testTheWholeCaptionOpensFromTheStripAtLargestAccessibilitySize() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, Self.phoneOnlyReason)
        launch(at: "UICTContentSizeCategoryAccessibilityXXXL")
        let screen = LayerScreen(app: app)
        screen.chooseMeaning()
        askUntilTheStripDiscloses(screen, at: "AX5")
        screen.putTheKeyboardAway()

        let more = screen.element("search.meaning.strip.more")
        XCTAssertTrue(more.waitForExistence(timeout: LayerScreen.patience), "The strip offers no ⓘ at AX5")
        XCTAssertEqual(more.label, "About Meaning search", "The ⓘ's name for VoiceOver")
        more.tap()
        let sheet = app.navigationBars[Self.sheetTitle]
        XCTAssertTrue(sheet.waitForExistence(timeout: LayerScreen.patience), "The ⓘ opened no \(Self.sheetTitle) sheet")

        // Each part of the caption is a paragraph of its own, the opening first. The paragraphs are read by their
        // identifier and from one snapshot: the row behind the sheet begins with the opening's words too.
        let part = app.staticTexts.matching(identifier: "search.meaning.strip.sheet.part")
        XCTAssertTrue(part.element(boundBy: Self.disclosures.count).waitForExistence(timeout: LayerScreen.patience),
                      "The sheet does not hold the opening and the \(Self.disclosures.count) disclosures as paragraphs")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "The whole caption at AX5"
        shot.lifetime = .keepAlways
        add(shot)
        var paragraphs: [(frame: CGRect, label: String)] = []
        func collect(_ node: XCUIElementSnapshot) {
            if node.identifier == "search.meaning.strip.sheet.part" { paragraphs.append((node.frame, node.label)) }
            node.children.forEach(collect)
        }
        collect(try app.snapshot())
        let barFoot = sheet.frame.maxY
        print("[Meaning strip] sheet: bar foot \(Int(barFoot)), paragraphs at y "
              + paragraphs.map { Self.span($0.frame) }.joined(separator: ", "))
        XCTAssertEqual(paragraphs.count, 1 + Self.disclosures.count, "The sheet's paragraphs: \(paragraphs.map(\.label))")
        for (paragraph, start) in zip(paragraphs, [Self.stripOpening] + Self.disclosures) {
            XCTAssertTrue(paragraph.label.hasPrefix(start), "A paragraph of the sheet begins \"\(paragraph.label.prefix(40))\", "
                          + "where the caption's part begins \"\(start)\"")
        }
        let opening = try XCTUnwrap(paragraphs.first).frame
        XCTAssertGreaterThanOrEqual(opening.minY, barFoot - 0.5, "The sheet's opening is behind its navigation bar")
        XCTAssertLessThan(opening.minY, app.windows.firstMatch.frame.maxY, "The sheet's opening is below the screen")
        XCTAssertTrue(zip(paragraphs, paragraphs.dropFirst()).allSatisfy { $0.frame.maxY <= $1.frame.minY + 0.5 },
                      "The sheet's paragraphs are not one under another, in the caption's order")
        // Done closes it.
        sheet.buttons["Done"].firstMatch.tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: sheet)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: LayerScreen.patience), .completed, "Done left the sheet open")
    }

    private func assertMeaningScreenFits(at category: String?, named size: String) throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, Self.phoneOnlyReason)
        if Self.defaultFieldHeight == 0 {
            launch(at: nil)
            let field = app.searchFields.firstMatch
            XCTAssertTrue(field.waitForExistence(timeout: LayerScreen.patience), "The Search tab shows no search field")
            Self.defaultFieldHeight = field.frame.height
        }
        launch(at: category)
        let screen = LayerScreen(app: app)
        screen.chooseMeaning()
        askUntilTheStripDiscloses(screen, at: size)
        // The layout a reader reads the list in: the keyboard the search raised put away, and the banner back.
        screen.putTheKeyboardAway()
        // Up for as long as no iCloud account syncs, so always on a test simulator with the keyboard away:
        // `ResultSelectionBarFitTests` relies on it the same way.
        XCTAssertTrue(screen.element("tabShell.syncBanner").waitForExistence(timeout: LayerScreen.patience),
                      "The tab shell's banner is not showing, so nothing here is measured against it")

        let reading = try MeaningScreenReading(app.snapshot(), stripOpening: Self.stripOpening,
                                               barIdentifiers: Self.barIdentifiers)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Meaning strip at \(size)"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let window = reading.window
        let barFrames = Self.barIdentifiers.compactMap { identifier in reading.bar[identifier].map { (identifier, $0) } }
        let barTop = barFrames.map(\.1.minY).min() ?? 0
        let barFoot = barFrames.map(\.1.maxY).max() ?? 0
        // The measurement record, printed before anything is required of it.
        print("[Meaning strip] \(size) window \(Int(window.width))x\(Int(window.height)) "
              + "field foot \(reading.field.map { String(Int($0.maxY)) } ?? "none") "
              + "control y \(Self.span(reading.picker)) bar y \(Int(barTop))–\(Int(barFoot)) "
              + "x \(Int(barFrames.map(\.1.minX).min() ?? 0))–\(Int(barFrames.map(\.1.maxX).max() ?? 0)) "
              + "more y \(Self.span(reading.bar["search.actions.more"])) "
              + "strip y \(Self.span(reading.stripFrame)) (\(reading.stripFrame.map { String(Int($0.height)) } ?? "no") pt) "
              + "ⓘ \(reading.wholeCaptionButton.map { "x \(Int($0.minX))–\(Int($0.maxX)) \(Int($0.width))x\(Int($0.height))" } ?? "none") "
              + "banner top \(reading.banner.map { String(Int($0.minY)) } ?? "none") "
              + "first row top \(reading.firstRowTop.map { String(Int($0)) } ?? "none")")
        let field = try XCTUnwrap(reading.field, "The snapshot holds no search field at \(size)")
        let picker = try XCTUnwrap(reading.picker, "The snapshot holds no Keywords | Meaning control at \(size)")
        XCTAssertEqual(barFrames.map(\.0), Self.barIdentifiers, "The snapshot does not hold the whole actions bar at \(size)")
        let strip = try XCTUnwrap(reading.stripFrame, "The snapshot holds no Meaning strip at \(size)")
        let speech = try XCTUnwrap(reading.stripSpeech, "Nothing VoiceOver reads begins \"\(Self.stripOpening)\" at \(size)")
        let bannerTop = try XCTUnwrap(reading.banner, "The snapshot holds no banner at \(size)").minY

        // The control and the bar inside the window, under the search field, the bar under the control.
        for (name, frame) in [("the Keywords | Meaning control", picker)] + barFrames {
            XCTAssertGreaterThanOrEqual(frame.minY, field.maxY - 0.5,
                                        "\(name) is above the screen or behind the search field at \(size): \(frame)")
            XCTAssertGreaterThanOrEqual(frame.minX, 0, "\(name) runs off the leading edge at \(size): \(frame)")
            XCTAssertLessThanOrEqual(frame.maxX, window.maxX + 0.5, "\(name) runs off the trailing edge at \(size): \(frame)")
            XCTAssertGreaterThan(frame.width, 0, "\(name) has no width at \(size)")
        }
        XCTAssertGreaterThanOrEqual(barTop, picker.maxY - 0.5,
                                    "The actions bar is drawn over the Keywords | Meaning control at \(size)")
        XCTAssertLessThanOrEqual(barFoot, bannerTop + 0.5, "The actions bar is under the banner at \(size)")
        // The strip starts under the bar, on screen, and VoiceOver reads the whole of it.
        XCTAssertGreaterThanOrEqual(strip.minY, barFoot - 0.5, "The strip is drawn over the actions bar at \(size)")
        XCTAssertLessThan(strip.minY, bannerTop, "The strip starts under the banner at \(size)")
        for disclosure in Self.disclosures {
            XCTAssertTrue(speech.contains(disclosure),
                          "VoiceOver does not read \"\(disclosure)\" in the strip at \(size): \(speech)")
        }
        // At the accessibility sizes the strip is one row with its ⓘ in it; at the standard sizes it is the caption.
        if let category, category.contains("Accessibility") {
            let more = try XCTUnwrap(reading.wholeCaptionButton, "The strip offers no ⓘ at \(size)")
            XCTAssertGreaterThanOrEqual(more.minX, 0, "The ⓘ runs off the leading edge at \(size): \(more)")
            XCTAssertLessThanOrEqual(more.maxX, window.maxX + 0.5, "The ⓘ runs off the trailing edge at \(size): \(more)")
            XCTAssertGreaterThanOrEqual(more.width, 44 - 0.5, "The ⓘ is under 44 points wide at \(size)")
            XCTAssertGreaterThanOrEqual(more.height, 44 - 0.5, "The ⓘ is under 44 points tall at \(size)")
            XCTAssertGreaterThanOrEqual(more.minY, strip.minY - 0.5, "The ⓘ is above the strip at \(size)")
            XCTAssertLessThanOrEqual(more.maxY, strip.maxY + 0.5, "The ⓘ is below the strip at \(size)")
            // Drawn at XXXL at most, the row keeps to its ⓘ's 44 points. Uncapped, the ⓘ grew to 62 points at AX5 on
            // an iPhone SE and the row's words were cut to "Meaning…", which no frame shows; at AX3 the row took 77.
            XCTAssertLessThanOrEqual(max(more.width, more.height), 44 + 0.5,
                                     "The ⓘ grew past 44 points at \(size): the row is not drawn at XXXL at most")
            XCTAssertLessThanOrEqual(strip.height, more.height + 0.5,
                                     "The row is taller than its ⓘ at \(size): its words take more than one line")
        } else {
            XCTAssertNil(reading.wholeCaptionButton, "The strip offers its ⓘ at \(size), a standard size")
        }
        // A result starts between the strip and the banner.
        let rowTop = try XCTUnwrap(reading.firstRowTop, "no result row is in the tree at \(size)")
        XCTAssertGreaterThanOrEqual(rowTop, strip.maxY - 0.5, "the first result is drawn over the strip at \(size)")
        XCTAssertLessThan(rowTop, bannerTop, "no result starts above the banner at \(size)")

        // The category really applied.
        if let category, category.contains("Accessibility") {
            XCTAssertGreaterThan(field.height, Self.defaultFieldHeight + 1, """
                \(size) rendered the search field at its default height (\(field.height) vs \(Self.defaultFieldHeight)): \
                the content-size category did not take effect, so this run says nothing
                """)
        }
    }

    /// Submits the near question until the strip says what only the run that listed the fixture's three says. The
    /// fixture is indexed during launch, and a Meaning search that runs first lists none of it, with every one of its
    /// 80 hits not listed. The wait is on the strip and not on the rows: on the code before the fix the list was below
    /// the screen at AX3 and AX5, and a list draws only the rows near the screen, so there was no row to wait for.
    private func askUntilTheStripDiscloses(_ screen: LayerScreen, at size: String,
                                           file: StaticString = #filePath, line: UInt = #line) {
        // Any element: at the accessibility sizes the caption is what VoiceOver reads of the row's words, not the
        // words drawn.
        let disclosed = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", Self.disclosures[0])).firstMatch
        for _ in 1...5 {
            screen.submit(LayerScreen.nearQuestion, file: file, line: line)
            if disclosed.waitForExistence(timeout: 12) { return }
        }
        XCTFail("At \(size) the strip never said \"\(Self.disclosures[0])\"; texts on screen: "
                + app.staticTexts.allElementsBoundByIndex.prefix(40).map { "\"\($0.label)\"" }.joined(separator: ", "),
                file: file, line: line)
    }

    private func launch(at category: String?) {
        if let app {
            LayerScreen(app: app).leave()
            app.terminate()
        }
        app = LayerScreen.launch(contentSizeCategory: category)
        XCTAssertTrue(navigator.select(.search, resolveTimeout: 15).tapped,
                      "Could not open the Search tab, so this suite would read another screen")
    }

    /// A frame's vertical extent, to the point, or "none".
    private static func span(_ frame: CGRect?) -> String {
        frame.map { "\(Int($0.minY))–\(Int($0.maxY))" } ?? "none"
    }
}

/// What `MeaningStripFitTests` measures, read from one accessibility snapshot of the app.
@MainActor
private struct MeaningScreenReading {
    /// The window's frame.
    private(set) var window: CGRect = .zero
    /// The search field's frame.
    private(set) var field: CGRect?
    /// The Keywords | Meaning control's frame.
    private(set) var picker: CGRect?
    /// The actions bar's controls' frames, by identifier.
    private(set) var bar: [String: CGRect] = [:]
    /// The Meaning strip's frame: the row's at the accessibility sizes, the caption's otherwise.
    var stripFrame: CGRect? { row ?? caption?.frame }
    /// What VoiceOver reads of the strip: the caption's label, at the accessibility sizes the row's words'.
    var stripSpeech: String? { caption?.label }
    /// The ⓘ that opens the whole caption, which the strip offers at the accessibility sizes.
    private(set) var wholeCaptionButton: CGRect?
    /// The tab shell's banner's frame.
    private(set) var banner: CGRect?
    /// The top of the highest fixture row in the tree.
    private(set) var firstRowTop: CGFloat?

    /// The strip's row, at the accessibility sizes.
    private var row: CGRect?
    /// The first element whose label begins as the strip does, and that label.
    private var caption: (frame: CGRect, label: String)?
    private let stripOpening: String
    private let barIdentifiers: Set<String>

    init(_ root: XCUIElementSnapshot, stripOpening: String, barIdentifiers: [String]) {
        self.stripOpening = stripOpening
        self.barIdentifiers = Set(barIdentifiers)
        window = root.children.first { $0.elementType == .window }?.frame ?? root.frame
        visit(root)
    }

    /// Takes each element the first time the walk meets it, in the tree's order, as a query's `firstMatch` does.
    private mutating func visit(_ node: XCUIElementSnapshot) {
        let frame = node.frame
        if field == nil, node.elementType == .searchField { field = frame }
        if picker == nil, node.elementType == .segmentedControl,
           node.children.contains(where: { $0.identifier == "Keywords" || $0.label == "Keywords" }) {
            picker = frame
        }
        if barIdentifiers.contains(node.identifier), bar[node.identifier] == nil { bar[node.identifier] = frame }
        if row == nil, node.identifier == "search.meaning.strip" { row = frame }
        if caption == nil, node.label.hasPrefix(stripOpening) { caption = (frame, node.label) }
        if wholeCaptionButton == nil, node.identifier == "search.meaning.strip.more" { wholeCaptionButton = frame }
        if banner == nil, node.identifier == "tabShell.syncBanner" { banner = frame }
        if node.elementType == .button, node.label.hasPrefix(LayerScreen.titlePrefix) {
            firstRowTop = min(firstRowTop ?? frame.minY, frame.minY)
        }
        for child in node.children { visit(child) }
    }
}
