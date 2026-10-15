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
/// Until this suite no UI test reached a Meaning result: a Meaning search needs the 229 MB query
/// encoder, which no simulator has and no test may download. `FRUS_UI_TEST_SEED_MEANING` stands in
/// for the encoder and gives the searcher a match-file store of the seam's own, holding one file,
/// made for the seeded fixture volume. The searcher's code, the backend, the bundled index and the
/// bundled sign bits are the app's own. So these rows are what a reader's would be, for a question
/// whose answer the test knows.
///
/// The store is the seam's own so that the simulator's state cannot reach these rows: a match file
/// the simulator's app had fetched for another volume would score that volume's candidates, and a
/// far question's 800 candidates lie in 134 volumes. The launch also turns the reader's automatic
/// match-file download off, which keeps the run offline.
///
/// ## The two questions, and why there are two
/// Every question is answered as if it were the fixture's second document, so a plain Meaning
/// search lists the fixture's three documents that have vectors, that one first: 100, 65 and 61
/// percent. They are three of 78 hits. The real volume has 120 documents, 78 of whose rows are
/// among the question's 800 candidates, and the seam's match file scores them all; the fixture
/// holds three, so the strip above the list says that 75 close matches are not listed and that 722
/// possible matches could not be scored.
///
/// A question that holds the word "afield" is answered as a document of another volume, far from
/// all three: a plain search then lists none of them, and a search **inside a working corpus** of
/// them lists all three, at 24, 24 and 16 percent. That last is what #1577 lane 1 changed. Before
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
/// this lane gave it: the row's label is its heading alone.
///
/// Version history:
///   1.0 — #1577 lane 3: initial implementation
///   1.1 — 2026-10-15: `submit` empties the field with its Clear text button and waits for the list to
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
                       ["Semantic match 100 percent", "Semantic match 65 percent", "Semantic match 61 percent"])
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
        // file for. The near question leaves 722 unscored, so this figure is the far question's own.
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
                       ["UI Test Document Two", "UI Test Document Three", "UI Test Document One"],
                       "Inside the corpus the three members with vectors are ranked, closest first")
        XCTAssertEqual(rows.map(\.score),
                       ["Semantic match 24 percent", "Semantic match 24 percent", "Semantic match 16 percent"])
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
    /// and read them while they were being replaced: Three, Two, One, on the same iPhone.
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
            .map { (title: $0.label, score: ($0.value as? String) ?? "") }
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
