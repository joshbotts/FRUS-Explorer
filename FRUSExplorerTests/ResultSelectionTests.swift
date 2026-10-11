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

import Foundation
import SwiftData
import Testing
@testable import FRUSExplorer

// MARK: - ResultSelectionTests

/// The picks themselves (#1576 lane 3). One fixture per rule of ``ResultSelection``.
///
/// Version history:
///   1.0 — #1576 lane 3: initial implementation
@Suite("Result selection")
struct ResultSelectionTests {

    private func row(_ documentId: String) -> SearchResult {
        SearchResult(documentId: documentId, volumeId: "v1", header: documentId, snippet: "", bm25Score: 0)
    }

    @Test("Outside selection nothing is picked, and a toggle or a pick does nothing")
    func nothingHappensOutsideSelection() {
        var selection = ResultSelection()
        #expect(!selection.isSelecting)
        selection.toggle("v1/d1")
        selection.pick(["v1/d1", "v1/d2"])
        #expect(selection.count == 0)
        #expect(!selection.isSelecting, "neither enters selection")
    }

    @Test("Select Results enters with nothing picked; Select on a row enters with that row picked")
    func twoWaysIn() {
        var fromMenu = ResultSelection()
        fromMenu.begin()
        #expect(fromMenu.isSelecting)
        #expect(fromMenu.count == 0)

        var fromRow = ResultSelection()
        fromRow.begin(picking: "v1/d3")
        #expect(fromRow.isSelecting)
        #expect(fromRow.keys == ["v1/d3"])

        // Select on a second row, already in selection, adds that row and keeps the first.
        fromRow.begin(picking: "v1/d4")
        #expect(fromRow.keys == ["v1/d3", "v1/d4"])
    }

    @Test("A toggle picks a row and a second toggle un-picks it")
    func toggle() {
        var selection = ResultSelection()
        selection.begin()
        selection.toggle("v1/d1")
        selection.toggle("v1/d2")
        #expect(selection.keys == ["v1/d1", "v1/d2"])
        #expect(selection.contains("v1/d1"))
        selection.toggle("v1/d1")
        #expect(selection.keys == ["v1/d2"])
        #expect(!selection.contains("v1/d1"))
    }

    @Test("This Page and All Shown add to the picks; None clears them and stays in selection")
    func pickAndClear() {
        var selection = ResultSelection()
        selection.begin(picking: "v1/d9")
        selection.pick(["v1/d1", "v1/d2"])
        #expect(selection.keys == ["v1/d9", "v1/d1", "v1/d2"], "a page picked keeps what was picked before it")
        selection.pick(["v1/d2", "v1/d3"])
        #expect(selection.count == 4)

        selection.clear()
        #expect(selection.count == 0)
        #expect(selection.isSelecting, "None un-picks; it is not Done")
    }

    @Test("Done forgets the picks")
    func end() {
        var selection = ResultSelection()
        selection.begin(picking: "v1/d1")
        selection.end()
        #expect(!selection.isSelecting)
        #expect(selection.count == 0)
        #expect(selection == ResultSelection())
    }

    @Test("A prune drops the picks that are not shown and answers how many")
    func prune() {
        var selection = ResultSelection()
        selection.begin()
        selection.pick(["v1/d1", "v1/d2", "v1/d3"])
        #expect(selection.prune(toShown: ["v1/d1", "v1/d3", "v1/d7"]) == 1)
        #expect(selection.keys == ["v1/d1", "v1/d3"], "a shown row that was not picked is not picked by a prune")
        #expect(selection.prune(toShown: ["v1/d1", "v1/d3"]) == 0)
        #expect(selection.prune(toShown: []) == 2)
        #expect(selection.isSelecting, "a prune to nothing leaves selection on; its owner decides to end it")
    }

    /// A command acts on the rows in the order the list shows them, whatever order they were
    /// picked in.
    @Test("The picks resolve to rows in the list's order")
    func resolvedInDisplayOrder() {
        var selection = ResultSelection()
        selection.begin()
        selection.toggle("v1/d3")
        selection.toggle("v1/d1")
        selection.toggle("v1/d8")       // picked, and not in the list handed over
        let shown = ["d1", "d2", "d3", "d4"].map(row)
        #expect(selection.resolved(in: shown).map(\.documentId) == ["d1", "d3"])
        #expect(ResultSelection().resolved(in: shown).isEmpty)
    }
}

// MARK: - ResultSelectionCopyTests

/// The words of selection.
///
/// Version history:
///   1.0 — #1576 lane 3: initial implementation
@Suite("Result selection, the words")
struct ResultSelectionCopyTests {

    private static let enUS = Locale(identifier: "en_US")

    @Test("The count and the All Shown item group their numbers")
    func counts() {
        #expect(ResultSelectionCopy.selected(0, locale: Self.enUS) == "0 selected")
        #expect(ResultSelectionCopy.selected(1, locale: Self.enUS) == "1 selected")
        #expect(ResultSelectionCopy.selected(1_250, locale: Self.enUS) == "1,250 selected")
        #expect(ResultSelectionCopy.allShown(975, locale: Self.enUS) == "All 975 Shown")
        #expect(ResultSelectionCopy.allShown(7_500, locale: Self.enUS) == "All 7,500 Shown")
    }

    @Test("An add says how many went in and how many were there already")
    func addOutcome() {
        #expect(ResultSelectionCopy.added(31, alreadyPresent: 6, to: "Chile", locale: Self.enUS)
                == "Added 31 documents to “Chile”. 6 were already in it.")
        #expect(ResultSelectionCopy.added(1, alreadyPresent: 1, to: "Chile", locale: Self.enUS)
                == "Added 1 document to “Chile”. 1 was already in it.")
        #expect(ResultSelectionCopy.added(1_200, alreadyPresent: 0, to: "Chile", locale: Self.enUS)
                == "Added 1,200 documents to “Chile”.")
        #expect(ResultSelectionCopy.added(0, alreadyPresent: 6, to: "Chile", locale: Self.enUS)
                == "Nothing added: 6 were already in “Chile”.")
        #expect(ResultSelectionCopy.added(0, alreadyPresent: 1, to: "Chile", locale: Self.enUS)
                == "Nothing added: 1 was already in “Chile”.")
    }

    @Test("An undone add, a dropped pick and the limit")
    func otherLines() {
        #expect(ResultSelectionCopy.removed(31, from: "Chile", locale: Self.enUS) == "Removed 31 documents from “Chile”.")
        #expect(ResultSelectionCopy.removed(1, from: "Chile", locale: Self.enUS) == "Removed 1 document from “Chile”.")
        #expect(ResultSelectionCopy.dropped(1, locale: Self.enUS) == "1 selected result is not in this list now.")
        #expect(ResultSelectionCopy.dropped(12, locale: Self.enUS) == "12 selected results are not in this list now.")
        #expect(ResultSelectionCopy.overLimit(1_000, locale: Self.enUS)
                == "Select 1,000 documents or fewer to add them to a collection.")
    }

    private struct Refused: LocalizedError {
        var errorDescription: String? { "The disk is full." }
    }

    /// The line must not say that nothing changed: a removal whose save failed has taken the
    /// entries out of the collection in memory.
    @Test("A failed Undo says it did not finish, and gives the reason")
    func undoFailure() {
        #expect(ResultSelectionCopy.undoFailed(Refused()) == "Undo did not finish: The disk is full.")
    }

    /// The row is compiled for the Mac too, where `macTextNeverSaysTap` refuses the word, and a
    /// VoiceOver hint says what activating does and names no gesture.
    @Test("A row's hint names no gesture")
    func rowHintNamesNoGesture() {
        #expect(ResultSelectionCopy.rowHint == "Selects or deselects this result")
        #expect(!ResultSelectionCopy.rowHint.lowercased().contains("tap"))
    }

    /// Two buttons named Undo sit in the rows above the results in Checklist Mode: this one and
    /// the strip's. After an add they take back different things, and the hint is what tells a
    /// VoiceOver reader which this is.
    @Test("The outcome's Undo says what it takes back, and names no gesture")
    func undoHints() {
        let add = ResultSelectionCopy.undoHint(for: .collectionEntries(ids: [], collectionName: "Chile"))
        let mark = ResultSelectionCopy.undoHint(for: .reviewedMarks)
        #expect(add == "Takes the documents this command added back out of the collection")
        #expect(mark == "Brings back the results this command hid")
        #expect(add != mark)
        #expect(!add.lowercased().contains("tap") && !mark.lowercased().contains("tap"))
    }

    /// The bar is taken off screen and put back, by a document opened over the list or by
    /// another tab, and its task starts again each time.
    @Test("An outcome is announced once: not again when the bar comes back, and not without words")
    func outcomeIsAnnouncedOnce() {
        // A new outcome.
        #expect(BulkOutcome.owesAnnouncement(serial: 1, lastAnnounced: 0, message: "Added 2 documents"))
        #expect(BulkOutcome.owesAnnouncement(serial: 5, lastAnnounced: 4, message: "Added 2 documents"))
        // The bar came back with the outcome it has already spoken.
        #expect(!BulkOutcome.owesAnnouncement(serial: 1, lastAnnounced: 1, message: "Added 2 documents"))
        // No outcome is showing: before any command, and after a search or Done cleared the line.
        #expect(!BulkOutcome.owesAnnouncement(serial: 0, lastAnnounced: 0, message: nil))
        #expect(!BulkOutcome.owesAnnouncement(serial: 3, lastAnnounced: 2, message: nil))
    }

    /// The commands' menu is drawn as a glyph, so its name is all VoiceOver has; and its first
    /// item is the one a result row's own menu has, which opens the same sheet.
    @Test("The commands' menu has a name, and its items' words")
    func menuWords() {
        #expect(ResultSelectionCopy.actions == "Actions")
        #expect(ResultSelectionCopy.markReviewed == "Mark Reviewed")
        #expect(BulkResultCopy.addToCollection == "Add to Collection…")
        #expect(ResultSelectionCopy.selectMenu == "Select")
        #expect(ResultSelectionCopy.thisPage == "This Page")
        #expect(ResultSelectionCopy.none == "None")
    }
}

// MARK: - SearchSelectionModelTests

/// Selection as `SearchViewModel` holds it: pruned against the shown results, lasting as long as
/// the search, and carrying its commands' outcomes (#1576 lane 3).
///
/// Version history:
///   1.0 — #1576 lane 3: initial implementation
@Suite("Search selection, in the view model")
@MainActor
struct SearchSelectionModelTests {

    /// A view model over an empty index, for tests that assign `results` themselves.
    private func makeVM() throws -> (vm: SearchViewModel, dir: URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSSelection-\(UUID().uuidString)", isDirectory: true)
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("s.sqlite")
        let store = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(fts5Store: store, databaseURL: dbURL, volumesDirectory: volDir,
                                            concurrencyLimit: 1)
        return (SearchViewModel(searchService: SearchService(fts5Store: store, pipeline: pipeline)), dir)
    }

    /// A view model over two indexed volumes: `v01` holds `d1` and `d2`, `v02` holds `d3`. All
    /// three hold "alpha" and "beta".
    private func makeIndexedVM() async throws -> (vm: SearchViewModel, dir: URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSSelectionIndexed-\(UUID().uuidString)", isDirectory: true)
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("s.sqlite")
        let store = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(fts5Store: store, databaseURL: dbURL, volumesDirectory: volDir,
                                            concurrencyLimit: 1)
        for (volumeId, documentIds) in [("frus1969-76v01", ["d1", "d2"]), ("frus1969-76v02", ["d3"])] {
            let blocks = documentIds.map {
                "<div type=\"document\" xml:id=\"\($0)\"><head>Doc \($0)</head><p>alpha beta \($0).</p></div>"
            }.joined(separator: "\n")
            let xml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <TEI xmlns="http://www.tei-c.org/ns/1.0">
              <teiHeader><fileDesc><titleStmt><title>\(volumeId)</title></titleStmt>
              <publicationStmt><date>2003</date></publicationStmt>
              <sourceDesc><p>Test fixture</p></sourceDesc></fileDesc></teiHeader>
              <text><body><div type="compilation" xml:id="comp1">\(blocks)</div></body></text>
            </TEI>
            """
            try Data(xml.utf8).write(to: volDir.appendingPathComponent("\(volumeId).xml"))
            try await pipeline.indexVolume(volumeId)
        }
        return (SearchViewModel(searchService: SearchService(fts5Store: store, pipeline: pipeline)), dir)
    }

    private func rows(_ n: Int) -> [SearchResult] {
        (1...n).map { SearchResult(documentId: "d\($0)", volumeId: "v1", header: "Doc \($0)", snippet: "", bm25Score: 0) }
    }

    private func key(_ documentId: String) -> String { "v1/\(documentId)" }

    // MARK: Entering and picking

    @Test("With no results there is nothing to select")
    func selectingNeedsRows() throws {
        let (vm, dir) = try makeVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.beginSelecting()
        #expect(!vm.resultSelection.isSelecting)
    }

    @Test("Select on a row enters selection with that row picked")
    func rowMenuEntersWithThatRowPicked() throws {
        let (vm, dir) = try makeVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.results = rows(30)
        vm.beginSelecting(with: vm.results[4])
        #expect(vm.resultSelection.isSelecting)
        #expect(vm.resultSelection.keys == [key("d5")])
        #expect(vm.selectedResults.map(\.documentId) == ["d5"])
    }

    /// Sixty results are pages of 25, 25 and 10. This Page is the page on screen; All Shown is
    /// every result the list shows, and never more than was loaded.
    @Test("This Page picks the page on screen, a page turn keeps the picks, and All Shown picks every result shown")
    func pageAndAllShown() throws {
        let (vm, dir) = try makeVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.results = rows(60)
        vm.beginSelecting()

        vm.selectPage()
        #expect(vm.resultSelection.count == 25)
        #expect(vm.resultSelection.contains(key("d25")) && !vm.resultSelection.contains(key("d26")))

        vm.currentPage = 2
        #expect(vm.resultSelection.count == 25, "a page turn keeps the picks")
        vm.selectPage()
        #expect(vm.resultSelection.count == 35, "the last page's ten join the first page's twenty-five")
        #expect(vm.selectedResults.map(\.documentId).first == "d1")
        #expect(vm.selectedResults.map(\.documentId).last == "d60")

        vm.selectAllShown()
        #expect(vm.resultSelection.count == 60)

        vm.selectNone()
        #expect(vm.resultSelection.count == 0)
        #expect(vm.resultSelection.isSelecting)

        vm.endSelecting()
        #expect(!vm.resultSelection.isSelecting)
    }

    // MARK: Pruned against the shown results

    /// Rule 1. Checklist Mode hides a row the moment it is marked; a picked row that is hidden
    /// would stay picked and out of sight. And a row that comes back comes back unpicked.
    @Test("A picked row that Checklist Mode hides leaves the selection, and comes back unpicked")
    func aHiddenRowLeavesTheSelection() throws {
        let (vm, dir) = try makeVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.results = rows(10)
        vm.setChecklistMode(true)
        vm.beginSelecting()
        vm.toggleSelection(of: vm.results[0])
        vm.toggleSelection(of: vm.results[1])
        #expect(vm.resultSelection.count == 2)

        vm.markReviewed(volumeId: "v1", documentId: "d1")
        #expect(vm.resultSelection.keys == [key("d2")], "the hidden row is no longer picked")
        #expect(vm.selectedResults.map(\.documentId) == ["d2"])

        vm.setChecklistMode(false)
        #expect(vm.displayedResults.count == 10, "the row is back")
        #expect(vm.resultSelection.keys == [key("d2")], "and it is back unpicked")
    }

    @Test("A picked row whose document is opened in Checklist Mode leaves the selection")
    func anOpenedRowLeavesTheSelection() throws {
        let (vm, dir) = try makeVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.results = rows(10)
        vm.setChecklistMode(true)
        vm.beginSelecting()
        vm.toggleSelection(of: vm.results[2])
        vm.toggleSelection(of: vm.results[3])

        vm.readSinceEnabledKeys = [SearchViewModel.reviewedKey(volumeId: "v1", documentId: "d3")]
        #expect(vm.resultSelection.keys == [key("d4")])
    }

    /// With Checklist Mode off nothing is hidden, so opening a document changes no pick.
    @Test("With Checklist Mode off an opened document stays picked")
    func openingWithoutChecklistKeepsThePick() throws {
        let (vm, dir) = try makeVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.results = rows(10)
        vm.beginSelecting()
        vm.toggleSelection(of: vm.results[2])
        vm.readSinceEnabledKeys = [SearchViewModel.reviewedKey(volumeId: "v1", documentId: "d3")]
        #expect(vm.resultSelection.keys == [key("d3")])
    }

    @Test("A replaced list drops the picks it does not hold, and an emptied list ends selection")
    func aReplacedListDropsWhatItDoesNotHold() throws {
        let (vm, dir) = try makeVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.results = rows(10)
        vm.beginSelecting()
        vm.selectAllShown()

        vm.results = Array(rows(10).prefix(4))
        #expect(vm.resultSelection.count == 4)
        #expect(vm.resultSelection.isSelecting)

        vm.results = []
        #expect(!vm.resultSelection.isSelecting, "there is no selection of an empty list")
        #expect(vm.bulkOutcome == nil)
    }

    // MARK: As long as the search

    /// The same words under a narrower scope are the same search: the picks it still shows stay,
    /// and a line says how many it does not.
    @Test("A re-run of the same search keeps the picks still shown and says how many it dropped")
    func sameSearchRerunKeepsThePicksStillShown() async throws {
        let (vm, dir) = try await makeIndexedVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.keywords = "alpha"
        await vm.search()
        try #require(vm.results.count == 3)
        vm.beginSelecting()
        vm.selectAllShown()
        #expect(vm.resultSelection.count == 3)

        vm.selectedVolumeIds = ["frus1969-76v01"]
        await vm.search()
        try #require(vm.searchError == nil)
        try #require(vm.results.count == 2, "the scope leaves the first volume's two documents")
        #expect(vm.resultSelection.isSelecting)
        #expect(vm.resultSelection.keys == ["frus1969-76v01/d1", "frus1969-76v01/d2"])
        #expect(vm.bulkOutcome?.message == ResultSelectionCopy.dropped(1))
        #expect(vm.bulkOutcome?.undo == nil)

        // The same search again, with nothing more to drop, keeps the picks; and a completed
        // search ends the line before it, as the next command would.
        await vm.search()
        #expect(vm.resultSelection.count == 2)
        #expect(vm.bulkOutcome == nil)
    }

    /// "Until the next command, the next search or Done." A re-run of the same search is a
    /// search: the line and its Undo go, whether or not it dropped a pick.
    @Test("A completed search ends the last command's line and its Undo")
    func aCompletedSearchEndsTheLine() async throws {
        let (vm, dir) = try await makeIndexedVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.keywords = "alpha"
        await vm.search()
        try #require(vm.results.count == 3)
        vm.beginSelecting()
        vm.selectAllShown()
        vm.recordCollectionAdd(CollectionDocumentAppend(insertedEntryIds: [UUID()], alreadyPresent: 0),
                               collectionName: "Chile")
        try #require(vm.bulkOutcome?.undo != nil)

        await vm.search()
        #expect(vm.resultSelection.count == 3, "the same search keeps the picks")
        #expect(vm.bulkOutcome == nil, "and ends the line the command before it left")
    }

    /// A search that is refused sets an error and leaves `results` as it was. The error is
    /// drawn where the rows were, so the picks would be of rows the reader cannot see.
    @Test("A refused search ends selection, though the rows it leaves are still loaded")
    func aRefusedSearchEndsSelection() async throws {
        let (vm, dir) = try await makeIndexedVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.keywords = "alpha"
        await vm.search()
        try #require(vm.results.count == 3)
        vm.beginSelecting()
        vm.selectAllShown()

        vm.keywords = ""
        await vm.search()
        try #require(vm.searchError != nil, "precondition: a search with no terms is refused")
        try #require(vm.results.count == 3, "precondition: the refusal leaves the loaded rows")
        #expect(!vm.resultSelection.isSelecting)
        #expect(vm.selectedResults.isEmpty)

        // And none can be begun under the error.
        vm.beginSelecting(with: vm.results[0])
        #expect(!vm.resultSelection.isSelecting)
    }

    /// The Meaning path settles the selection by the same rule, with the question as its words.
    @Test("In Meaning mode the same question keeps the picks and another question ends selection")
    func meaningSearchSettlesTheSelection() async throws {
        let (vm, dir) = try makeVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.semanticBackend = SelectionMeaningStub()
        vm.searchMode = .meaning
        vm.keywords = "why did the talks fail"
        await vm.search()
        try #require(vm.results.count == 3)
        vm.beginSelecting()
        vm.selectAllShown()

        await vm.search()
        #expect(vm.resultSelection.count == 3, "the same question is the same search")

        vm.keywords = "who opposed the treaty"
        await vm.search()
        try #require(vm.results.count == 3)
        #expect(!vm.resultSelection.isSelecting, "another question is another search")
    }

    @Test("A new query ends selection")
    func aNewQueryEndsSelection() async throws {
        let (vm, dir) = try await makeIndexedVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.keywords = "alpha"
        await vm.search()
        try #require(vm.results.count == 3)
        vm.beginSelecting()
        vm.selectAllShown()

        // Other words, and every document matches them too: the rows are the same and the
        // search is not.
        vm.keywords = "beta"
        await vm.search()
        try #require(vm.results.count == 3)
        #expect(!vm.resultSelection.isSelecting)
        #expect(vm.resultSelection.count == 0)
    }

    @Test("A flip between Keywords and Meaning ends selection")
    func aModeFlipEndsSelection() throws {
        let (vm, dir) = try makeVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.results = rows(10)
        vm.beginSelecting(with: vm.results[0])
        _ = vm.switchSearchMode(to: .meaning)
        #expect(!vm.resultSelection.isSelecting)
    }

    /// The picker is one writer of the engine. A hand-off and a restored search set it directly,
    /// and the same words can then run in the other engine, which the search's anchor does not
    /// tell apart.
    @Test("The engine changed by any writer ends selection")
    func anEngineChangeEndsSelection() throws {
        let (vm, dir) = try makeVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.results = rows(10)
        vm.beginSelecting(with: vm.results[0])
        vm.searchMode = .meaning
        #expect(!vm.resultSelection.isSelecting)

        // Set to what it already is, nothing ends.
        vm.beginSelecting(with: vm.results[0])
        vm.searchMode = .meaning
        #expect(vm.resultSelection.isSelecting)
    }

    @Test("An error ends selection, and none begins under one")
    func anErrorEndsSelection() throws {
        let (vm, dir) = try makeVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.results = rows(10)
        vm.beginSelecting(with: vm.results[0])
        vm.searchError = "The search could not run."
        #expect(!vm.resultSelection.isSelecting)

        vm.beginSelecting()
        #expect(!vm.resultSelection.isSelecting, "the error is drawn where the rows were")

        vm.searchError = nil
        vm.beginSelecting()
        #expect(vm.resultSelection.isSelecting)
    }

    // MARK: Commands and their outcomes

    @Test("Mark Reviewed hides the selection, which leaves it, and Undo brings the rows back unpicked")
    func markSelectionReviewed() throws {
        let (vm, dir) = try makeVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.results = rows(30)
        vm.setChecklistMode(true)
        vm.beginSelecting()
        for index in [0, 5, 28] { vm.toggleSelection(of: vm.results[index]) }

        vm.markSelectionReviewed()

        #expect(vm.displayedResults.count == 27)
        #expect(vm.resultSelection.count == 0, "what was hidden is no longer picked")
        #expect(vm.resultSelection.isSelecting)
        #expect(vm.bulkOutcome == BulkOutcome(message: ChecklistCopy.markedAnnouncement(3), undo: .reviewedMarks))

        vm.undoBulkOutcome { _ in Issue.record("no collection entry is involved"); return 0 }
        #expect(vm.displayedResults.count == 30)
        #expect(vm.resultSelection.count == 0, "the rows come back unpicked")
        #expect(vm.bulkOutcome == BulkOutcome(message: ChecklistCopy.undoneAnnouncement(3), undo: nil))
    }

    /// The picked rows are scattered down the list and the reader is among them. Mark Page
    /// Reviewed sends the list to its top, because the page under it is new; this must not.
    @Test("Marking a selection reviewed leaves the list where it is")
    func markingASelectionDoesNotMoveTheList() throws {
        let (vm, dir) = try makeVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.results = rows(30)
        vm.setChecklistMode(true)
        vm.beginSelecting()
        vm.toggleSelection(of: vm.results[12])
        let generation = vm.bulkMarkGeneration

        vm.markSelectionReviewed()
        try #require(vm.displayedResults.count == 29)
        #expect(vm.bulkMarkGeneration == generation)
    }

    /// The checklist strip has an Undo of its own. Once it has taken the selection's mark back,
    /// the selection's line would offer to undo a mark that is gone.
    @Test("The checklist strip's Undo withdraws the line that offered the same undo")
    func theStripsUndoWithdrawsTheLine() throws {
        let (vm, dir) = try makeVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.results = rows(30)
        vm.setChecklistMode(true)
        vm.beginSelecting(with: vm.results[3])
        vm.markSelectionReviewed()
        try #require(vm.bulkOutcome?.undo == .reviewedMarks)

        #expect(vm.undoLastBulkMark() == 1)
        #expect(vm.bulkOutcome == nil)
    }

    /// Two full pages marked one after the other leave the same words. The bar announces on
    /// this count, since a line that did not change is no signal that anything happened.
    @Test("Each outcome is counted, the same words twice included")
    func eachOutcomeIsCounted() throws {
        let (vm, dir) = try makeVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.results = rows(60)
        vm.setChecklistMode(true)
        vm.beginSelecting()
        let start = vm.bulkOutcomeSerial

        vm.selectPage()
        vm.markSelectionReviewed()
        let first = try #require(vm.bulkOutcome)
        #expect(vm.bulkOutcomeSerial == start + 1)

        vm.selectPage()
        vm.markSelectionReviewed()
        #expect(vm.bulkOutcome == first, "the second page's line reads as the first's did")
        #expect(vm.bulkOutcomeSerial == start + 2, "and is counted as a new outcome all the same")

        vm.endSelecting()
        #expect(vm.bulkOutcomeSerial == start + 2, "clearing the line is not an outcome")
    }

    @Test("Mark Reviewed with nothing picked hides nothing and offers no Undo")
    func markNothingReviewed() throws {
        let (vm, dir) = try makeVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.results = rows(5)
        vm.setChecklistMode(true)
        vm.beginSelecting()
        vm.markSelectionReviewed()
        #expect(vm.displayedResults.count == 5)
        #expect(vm.bulkOutcome?.undo == nil)
    }

    /// The strip's own Mark Page Reviewed replaces the batch Undo takes back. A line still
    /// offering to undo the selection's mark would then bring back the page instead.
    @Test("A page marked from the checklist strip withdraws a line that offered to undo an earlier mark")
    func aLaterBulkMarkWithdrawsTheEarlierUndo() throws {
        let (vm, dir) = try makeVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.results = rows(60)
        vm.setChecklistMode(true)
        vm.beginSelecting(with: vm.results[59])
        vm.markSelectionReviewed()
        try #require(vm.bulkOutcome?.undo == .reviewedMarks)

        vm.markReviewed(vm.pagedResults)
        #expect(vm.bulkOutcome == nil)
    }

    @Test("An add's outcome stays with its Undo, and Undo says how many were removed")
    func collectionAddOutcomeAndUndo() throws {
        let (vm, dir) = try makeVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.results = rows(10)
        vm.beginSelecting()
        vm.selectAllShown()
        let ids = [UUID(), UUID(), UUID()]

        vm.recordCollectionAdd(CollectionDocumentAppend(insertedEntryIds: ids, alreadyPresent: 7),
                               collectionName: "Chile")
        #expect(vm.bulkOutcome == BulkOutcome(
            message: ResultSelectionCopy.added(3, alreadyPresent: 7, to: "Chile"),
            undo: .collectionEntries(ids: ids, collectionName: "Chile")))
        #expect(vm.resultSelection.count == 10, "the picks stay after an add")

        var asked: [UUID] = []
        vm.undoBulkOutcome { asked = $0; return 2 }
        #expect(asked == ids, "Undo removes the entries the add inserted, by id")
        #expect(vm.bulkOutcome == BulkOutcome(message: ResultSelectionCopy.removed(2, from: "Chile"), undo: nil),
                "two were removed: the third was gone already, which is not an error")

        // With nothing left to undo, Undo does nothing.
        vm.undoBulkOutcome { _ in Issue.record("there is nothing to undo"); return 0 }
        #expect(vm.bulkOutcome?.message == ResultSelectionCopy.removed(2, from: "Chile"))
    }

    @Test("An add that inserted nothing has no Undo")
    func nothingAddedHasNoUndo() throws {
        let (vm, dir) = try makeVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.results = rows(3)
        vm.beginSelecting()
        vm.recordCollectionAdd(CollectionDocumentAppend(insertedEntryIds: [], alreadyPresent: 3),
                               collectionName: "Chile")
        #expect(vm.bulkOutcome == BulkOutcome(message: ResultSelectionCopy.added(0, alreadyPresent: 3, to: "Chile"),
                                              undo: nil))
    }

    private struct RemovalRefused: Error {}

    /// A removal whose save failed has already taken the entries out in memory. A second try
    /// would find none, remove none and say "Removed 0 documents", so none is offered.
    @Test("An Undo that fails says so and offers no second try")
    func aFailedUndoOffersNoSecondTry() throws {
        let (vm, dir) = try makeVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.results = rows(3)
        vm.beginSelecting()
        vm.recordCollectionAdd(CollectionDocumentAppend(insertedEntryIds: [UUID()], alreadyPresent: 0),
                               collectionName: "Chile")

        vm.undoBulkOutcome { _ in throw RemovalRefused() }
        #expect(vm.bulkOutcome?.undo == nil)
        #expect(vm.bulkOutcome?.message == ResultSelectionCopy.undoFailed(RemovalRefused()))
        #expect(vm.bulkOutcome?.message.hasPrefix("Undo did not finish: ") == true)
    }

    /// Outside selection there is no bar to show an outcome in: a single row's add from its menu
    /// is confirmed by the picker's checkmark.
    @Test("Outside selection an add records no outcome")
    func outsideSelectionAnAddRecordsNothing() throws {
        let (vm, dir) = try makeVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.results = rows(3)
        vm.recordCollectionAdd(CollectionDocumentAppend(insertedEntryIds: [UUID()], alreadyPresent: 0),
                               collectionName: "Chile")
        #expect(vm.bulkOutcome == nil)
    }

    @Test("Done forgets the outcome with the picks")
    func doneForgetsTheOutcome() throws {
        let (vm, dir) = try makeVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.results = rows(3)
        vm.beginSelecting()
        vm.recordCollectionAdd(CollectionDocumentAppend(insertedEntryIds: [UUID()], alreadyPresent: 0),
                               collectionName: "Chile")
        vm.endSelecting()
        #expect(vm.bulkOutcome == nil)
        // And a selection begun again starts with none.
        vm.beginSelecting()
        #expect(vm.bulkOutcome == nil)
    }

    /// Decision 5. Add to Collection takes a thousand; Mark Reviewed has no limit.
    @Test("More than a thousand picks is over the add's limit, and a thousand is not")
    func overTheAddLimit() throws {
        let (vm, dir) = try makeVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.results = rows(1_001)
        vm.beginSelecting()
        vm.selectAllShown()
        #expect(vm.resultSelection.count == 1_001)
        #expect(vm.selectionExceedsAddLimit)

        vm.toggleSelection(of: vm.results[0])
        #expect(vm.resultSelection.count == 1_000)
        #expect(!vm.selectionExceedsAddLimit)
    }

    /// The command is live for one pick and for a thousand, and dimmed for none and for a
    /// thousand and one.
    @Test("Add to Collection can run with something picked and no more than the limit")
    func whenTheAddCanRun() throws {
        let (vm, dir) = try makeVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        vm.results = rows(1_001)
        vm.beginSelecting()
        #expect(!vm.canAddSelectionToCollection, "nothing is picked")
        vm.toggleSelection(of: vm.results[0])
        #expect(vm.canAddSelectionToCollection)
        vm.selectAllShown()
        #expect(!vm.canAddSelectionToCollection, "a thousand and one is over the limit")
        vm.toggleSelection(of: vm.results[0])
        #expect(vm.canAddSelectionToCollection, "a thousand is at it")
    }

    /// A command acts on the rows in the order the list shows them. Under a date sort that is
    /// not the order the search returned them in.
    @Test("The selection resolves in the list's order under a sort, not in the order loaded")
    func selectedResultsFollowTheSort() throws {
        let (vm, dir) = try makeVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        // Loaded newest first; sorted oldest first, the list shows them reversed.
        vm.results = [("d1", "1973-01-01"), ("d2", "1972-01-01"), ("d3", "1971-01-01")].map {
            SearchResult(documentId: $0.0, volumeId: "v1", header: $0.0, dateISO: $0.1, snippet: "", bm25Score: 0)
        }
        vm.sortOrder = .dateAscending
        try #require(vm.displayedResults.map(\.documentId) == ["d3", "d2", "d1"])
        vm.beginSelecting()
        vm.toggleSelection(of: vm.results[0])       // d1
        vm.toggleSelection(of: vm.results[2])       // d3
        #expect(vm.selectedResults.map(\.documentId) == ["d3", "d1"])
    }
}

/// A Meaning engine that answers every question with the same three rows, so that a view-model
/// test can run the Meaning path with no model and no vectors.
@MainActor
private struct SelectionMeaningStub: MeaningSearchRunning {
    func run(query: String, parameters: SearchParameters) async throws -> SemanticSearchBackend.Outcome {
        SemanticSearchBackend.Outcome(
            results: (1...3).map {
                SearchResult(documentId: "d\($0)", volumeId: "v1", header: "Doc \($0)", snippet: "",
                             bm25Score: -0.5, semanticScore: 0.5)
            },
            beyondLibrary: [],
            disclosure: SemanticSearchBackend.Disclosure(
                unscoredCandidates: 0, unscoredVolumes: 0, downloadingVolumes: 0,
                filtersApplied: false, filteredOut: 0, beyondUncheckedByFilters: false))
    }
}

// MARK: - ResultSelectionWiringTests

/// The wiring of selection that nothing hosts, read from source and matched on the call
/// (#1576 lane 3). `SearchBulkActionsTests` drives the same wiring in the app on iPhone and iPad.
///
/// Version history:
///   1.0 — #1576 lane 3: initial implementation
@Suite("Result selection, the wiring")
struct ResultSelectionWiringTests {

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// `source` without its comment lines and with every run of whitespace removed.
    private static func squeezedCode(_ source: String) -> String {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
            .filter { !$0.isWhitespace }
    }

    private static func squeezed(_ text: String) -> String { text.filter { !$0.isWhitespace } }

    /// The declaration that opens with `header`, to the line that closes it at the header's own
    /// indentation.
    private static func declaration(_ header: String, in source: String) throws -> String {
        let start = try #require(source.range(of: header), "\(header) is gone: moved or renamed?")
        let lineStart = source[..<start.lowerBound].lastIndex(of: "\n").map(source.index(after:)) ?? source.startIndex
        let indent = source[lineStart..<start.lowerBound]
        let close = try #require(source.range(of: "\n\(indent)}\n", range: start.upperBound..<source.endIndex))
        return String(source[start.lowerBound..<close.upperBound])
    }

    private static let view = "FRUSExplorer/Search/SearchView.swift"

    /// The five-control bar is not given a sixth: selection takes its slot.
    @Test("The selection bar takes the actions bar's slot while selecting")
    func selectionBarTakesTheSlot() throws {
        let code = Self.squeezedCode(try Self.source(Self.view))
        #expect(code.contains(Self.squeezed("""
            searchModePicker
            if vm.resultSelection.isSelecting {
                selectionBar
            } else {
                searchActionsBar
            }
            """)))
        let bar = Self.squeezedCode(try Self.declaration("private var searchActionsBar: some View {",
                                                         in: try Self.source(Self.view)))
        #expect(!bar.contains("Selection"), "the actions bar itself must not carry a selection control")
    }

    /// After the two save items, which stay adjacent, and before the saved searches; on iPhone
    /// and iPad only; and only where there are rows of the list reading to pick.
    @Test("Select Results is in the More menu after the save items, for the list reading")
    func moreMenuEntersSelection() throws {
        let more = try Self.declaration("private var moreMenu: some View {", in: try Self.source(Self.view))
        let corpus = try #require(more.range(of: "\"search.corpus.save\""))
        let select = try #require(more.range(of: "ResultSelectionCopy.selectResults"))
        let saved = try #require(more.range(of: "\"search.savedSearches.a11y\""))
        #expect(corpus.upperBound < select.lowerBound && select.upperBound < saved.lowerBound)
        #expect(Self.squeezedCode(more).contains(Self.squeezed("""
            #if os(iOS)
            Button {
                vm.beginSelecting()
            } label: {
                Label(ResultSelectionCopy.selectResults, systemImage: "checkmark.circle")
            }
            .disabled(vm.displayedResults.isEmpty || activeReading != .list || vm.searchError != nil)
            #endif
            """)), "Select Results is dimmed with no rows, outside the list reading, and under an error")
        #expect(more.contains("\"search.moreActions.help.v3\""), "the help names the menu's contents, so it is re-keyed")
        #expect(!more.contains("\"search.moreActions.help.v2\""))
    }

    @Test("In selection a row's tap picks it, its swipe is off, and its menu opens it")
    func rowsPickWhileSelecting() throws {
        let rows = Self.squeezedCode(try Self.declaration("private var resultRows: some View {",
                                                          in: try Self.source(Self.view)))
        #expect(rows.contains(Self.squeezed("""
            Button {
                if vm.resultSelection.isSelecting {
                    vm.toggleSelection(of: result)
                } else {
                    openResult(vm.makeEntry(from: result))
                }
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    if vm.resultSelection.isSelecting {
                        ResultSelectionMark(isSelected: vm.resultSelection.contains(result.id))
                    }
            """)), "the row's button must toggle the pick while selecting, and show the mark")
        #expect(rows.contains(Self.squeezed(
            ".accessibilityAddTraits(vm.resultSelection.contains(result.id) ? .isSelected : [])")),
            "the selected trait is what tells VoiceOver a row is picked")
        #expect(rows.contains(Self.squeezed("if vm.checklistMode && !vm.resultSelection.isSelecting {")),
                "the swipe is off while selecting")
        #expect(rows.contains(Self.squeezed("""
            .contextMenu {
                if vm.resultSelection.isSelecting {
                    Button {
                        openResult(vm.makeEntry(from: result))
                    } label: {
                        Label(ResultSelectionCopy.open, systemImage: "arrow.up.right.square")
                    }
            """)), "in selection the row's menu is how its document is opened")
        #expect(rows.contains(Self.squeezed("""
            Button {
                vm.beginSelecting(with: result)
            } label: {
                Label(ResultSelectionCopy.selectRow, systemImage: "checkmark.circle")
            }
            """)), "outside selection the row's menu enters it with that row picked")
        // A chip is part of its row while selecting: it must not narrow the search.
        #expect(rows.contains(Self.squeezed("""
            guard !vm.resultSelection.isSelecting else {
                vm.toggleSelection(of: result)
                return
            }
            """)))
    }

    /// The command acts on a frozen list: the request is made from the picked rows when the
    /// command is chosen, in the list's order, and the sheet reads the request.
    @Test("The commands are a menu in the selection bar, and Add to Collection makes its request from the picks")
    func commandsAreAMenuInTheBar() throws {
        let view = try Self.source(Self.view)
        // The plan's rule, applied: a bar at the foot of the results could not clear the tab
        // shell's banner at 375 pt and the largest text size, so nothing is attached there.
        #expect(!view.contains(".safeAreaInset(edge: .bottom"),
                "nothing is attached at the foot of the results: the commands are the bar's Actions menu")
        #expect(!view.contains("keyboardWillShowNotification"), "with no bar at the foot there is no keyboard to step aside for")

        let bar = Self.squeezedCode(try Self.declaration("private var selectionBar: some View {", in: view))
        #expect(bar.contains(Self.squeezed("canAdd: vm.canAddSelectionToCollection,")),
                "the command's enablement is the view model's rule, which a test runs")
        #expect(bar.contains(Self.squeezed("showsMarkReviewed: vm.checklistMode,")))
        #expect(bar.contains(Self.squeezed("""
            addToCollection: {
                bulkRequest = BulkResultRequest(.addToCollection, results: vm.selectedResults,
                                                fromMeaningSearch: vm.resultsAreSemantic)
            },
            markReviewed: { vm.markSelectionReviewed() })
            """)))

        let views = try Self.source("FRUSExplorer/Search/ResultSelectionViews.swift")
        let menu = Self.squeezedCode(try Self.declaration("private var actionsMenu: some View {", in: views))
        #expect(menu.contains(Self.squeezed("""
            Menu {
                Button(action: addToCollection) {
                    Label(BulkResultCopy.addToCollection, systemImage: "plus.circle")
                }
                .disabled(!canAdd)
                if showsMarkReviewed {
                    Button(action: markReviewed) {
                        Label(ResultSelectionCopy.markReviewed, systemImage: "checkmark.circle")
                    }
                    .disabled(count == 0)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: rowGlyphSize))
            }
            """)), "Add to Collection first, then Mark Reviewed in Checklist Mode only, under the actions bar's glyph")
        // A glyph has no words: the name is what VoiceOver and the Large Content Viewer say.
        #expect(menu.contains(Self.squeezed(".accessibilityLabel(ResultSelectionCopy.actions)")))
        #expect(menu.contains(Self.squeezed("""
            .accessibilityShowsLargeContentViewer {
                Label(ResultSelectionCopy.actions, systemImage: "ellipsis.circle")
            }
            """)))
        #expect(menu.contains(Self.squeezed(".accessibilityIdentifier(\"search.selection.actions\")")))
        #expect(!Self.squeezedCode(views).contains("ResultCommandBar"), "the bar at the foot is gone, not kept beside the menu")
    }

    /// The bar is one row: a line under it that grew with the reader's text made the stack
    /// attached above the results taller than its room. The lines are rows above the results,
    /// which give way.
    @Test("What a command did, and why Add to Collection is dimmed, are rows above the results")
    func statusLinesAreRowsAboveTheResults() throws {
        let view = try Self.source(Self.view)
        let status = Self.squeezedCode(try Self.declaration("private var selectionStatus: some View {", in: view))
        #expect(status.contains(Self.squeezed("""
            if vm.resultSelection.isSelecting {
                ResultSelectionStatus(
                    addRefusal: vm.selectionExceedsAddLimit
                        ? ResultSelectionCopy.overLimit(CollectionDocumentDiscovery.bulkDocumentLimit) : nil,
                    outcome: vm.bulkOutcome,
            """)), "nothing outside selection, and both lines from the view model")
        let rows = Self.squeezedCode(try Self.declaration("private var resultsFixedRows: some View {", in: view))
        #expect(rows.contains(Self.squeezed("""
            VStack {
                #if os(iOS)
                selectionStatus
                #endif
                resultCountHeader
                checklistHiddenBanner
            }
            """)), "the selection's lines are the first of the rows that scroll where they do not fit")
        let bar = Self.squeezedCode(try Self.declaration("private var selectionBar: some View {", in: view))
        #expect(!bar.contains("undo:") && !bar.contains("addRefusal:"),
                "the bar draws neither line: it is one row, as tall as the actions bar's")
        let barView = Self.squeezedCode(try Self.declaration("struct ResultSelectionBar: View {",
                                                             in: try Self.source("FRUSExplorer/Search/ResultSelectionViews.swift")))
        #expect(!barView.contains("outcome.message") && !barView.contains("VStack"),
                "ResultSelectionBar is the row alone")
    }

    /// `ResultSelectionBarFitTests` cannot read the app's constants, and works the count's room
    /// out from copies of these two. A change here is a change there.
    @Test("The row's spacing and the count's smallest scale are the figures the fit suite measures with")
    func rowFiguresMatchTheFitSuite() throws {
        let barView = try Self.declaration(
            "struct ResultSelectionBar: View {", in: try Self.source("FRUSExplorer/Search/ResultSelectionViews.swift"))
        #expect(barView.contains("static let spacing: CGFloat = 8"))
        #expect(barView.contains("static let countMinimumScale: CGFloat = 0.6"))
        let code = Self.squeezedCode(barView)
        #expect(code.contains(Self.squeezed("HStack(spacing: Self.spacing) {")))
        #expect(code.contains(Self.squeezed(".minimumScaleFactor(Self.countMinimumScale)")))
        // The count is the one control with no name to magnify: it shows itself.
        #expect(code.contains(Self.squeezed("""
            Text(ResultSelectionCopy.selected(count))
                .accessibilityShowsLargeContentViewer()
            """)))
        let fit = try Self.source("FRUSExplorerUITests/SearchBulkActionsTests.swift")
        #expect(fit.contains("private static let rowSpacing: CGFloat = 8"))
        #expect(fit.contains("private static let countMinimumScale: CGFloat = 0.6"))
    }

    @Test("An add's outcome reaches the bar, and its Undo removes the entries by id")
    func outcomeAndUndoAreWired() throws {
        let view = try Self.source(Self.view)
        let code = Self.squeezedCode(view)
        #expect(code.contains(Self.squeezed("""
            .bulkResultSheets($bulkRequest, onAdded: { outcome, collection in
                vm.recordCollectionAdd(
                    outcome, collectionName: CollectionEditorNaming.listName(savedName: collection.name))
            })
            """)))
        let status = Self.squeezedCode(try Self.declaration("private var selectionStatus: some View {", in: view))
        #expect(status.contains(Self.squeezed("""
            undo: {
                vm.undoBulkOutcome { ids in
                    try CollectionDocumentDiscovery.removeEntries(withIds: ids, modelContext: modelContext)
                }
            })
            """)))
        let bar = Self.squeezedCode(try Self.declaration("private var selectionBar: some View {", in: view))
        #expect(bar.contains(Self.squeezed(
            "outcomeMessage: vm.bulkOutcome?.message, outcomeSerial: vm.bulkOutcomeSerial,")))
        #expect(bar.contains(Self.squeezed("done: { vm.endSelecting() },")))

        // The bar announces each outcome the host counts, late and at high priority. The bar and
        // not the line: the line's view is replaced when the rows above the results start or
        // stop scrolling, and a task on it would speak the same outcome again.
        let views = try Self.source("FRUSExplorer/Search/ResultSelectionViews.swift")
        let barView = Self.squeezedCode(try Self.declaration("struct ResultSelectionBar: View {", in: views))
        #expect(barView.contains(Self.squeezed("""
            .task(id: outcomeSerial) {
                guard BulkOutcome.owesAnnouncement(serial: outcomeSerial, lastAnnounced: announcedSerial,
                                                   message: outcomeMessage),
                      let outcomeMessage else { return }
                do { try await Task.sleep(for: Self.announcementDelay) } catch { return }
                announcedSerial = outcomeSerial
                AccessibilityNotification.Announcement(TransientToast.announcement(outcomeMessage)).post()
            }
            """)), "each outcome once: the rule is asked, and the count spoken is kept before the post")
        #expect(barView.contains(Self.squeezed("@State private var announcedSerial = 0")),
                "kept in the bar's own state, which outlives its time off screen")
        // The outcome's Undo says what it takes back: the strip's Undo is a few rows below it.
        #expect(Self.squeezedCode(try Self.declaration("struct ResultSelectionStatus: View {", in: views))
            .contains(Self.squeezed("""
                if let kind = outcome.undo {
                    Button(ResultSelectionCopy.undo, action: undo)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .accessibilityHint(ResultSelectionCopy.undoHint(for: kind))
                """)))
        let statusView = Self.squeezedCode(try Self.declaration("struct ResultSelectionStatus: View {", in: views))
        #expect(!statusView.contains(".task("), "the line does not announce: the bar does")
        // A new outcome brings the scrolling rows back to their top, where its line is.
        #expect(Self.squeezedCode(view).contains(Self.squeezed("""
            ScrollView { rows }
                .scrollBounceBehavior(.basedOnSize)
                .id(vm.bulkOutcomeSerial)
            """)))

        // The picker tells its host after an add that was saved, and before it closes.
        let picker = Self.squeezedCode(try Self.source("FRUSExplorer/Collections/CollectionPickerSheet.swift"))
        #expect(picker.contains(Self.squeezed("""
            let outcome = try CollectionDocumentDiscovery.appendDocuments(
                documents, to: collection, modelContext: modelContext)
            addedCollectionId = collection.id
            onAdded?(outcome, collection)
            """)))
    }

    @Test("The view model settles the selection where it settles the checklist, and a mode flip ends it")
    func viewModelSettlesTheSelection() throws {
        let model = try Self.source("FRUSExplorer/Search/SearchViewModel.swift")
        let code = Self.squeezedCode(model)
        #expect(code.contains(Self.squeezed("""
            settleChecklist(for: ChecklistAnchor(query: submittedQuery, parameters: params))
            settleSelection(for: ChecklistAnchor(query: submittedQuery, parameters: params))
            """)), "the keyword path")
        #expect(code.contains(Self.squeezed("""
            settleChecklist(for: checklistAnchorOfThisRun)
            settleSelection(for: checklistAnchorOfThisRun)
            """)), "the Meaning path")
        // Ended by the properties themselves, so that no writer of either can leave picks behind.
        #expect(code.contains(Self.squeezed("""
            var searchMode: SearchMode = .keywords {
                didSet { if searchMode != oldValue { endSelecting() } }
            }
            """)))
        #expect(code.contains(Self.squeezed("""
            var searchError: String? = nil {
                didSet { if searchError != nil { endSelecting() } }
            }
            """)))
    }

    @Test("Boot writes or removes the bulk volume, and brings its index to match, beside the storage rows")
    func bootPreparesTheBulkVolume() throws {
        let app = Self.squeezedCode(try Self.source("FRUSExplorer/App/FRUSExplorerApp.swift"))
        #expect(app.contains(Self.squeezed("""
            UITestVolumeSeeder.prepareStorageRowsIfRequested(in: volumesDir)
            UITestVolumeSeeder.prepareBulkVolumeIfRequested(in: volumesDir)
            """)))
        #expect(app.contains(Self.squeezed("""
            await UITestVolumeSeeder.prepareStorageRowIndex(pipeline: pipeline)
            await UITestVolumeSeeder.prepareBulkVolumeIndex(pipeline: pipeline)
            """)))
    }
}

// MARK: - CollectionEntryRemovalTests

/// The Undo of a bulk add: `CollectionDocumentDiscovery.removeEntries` on a real store.
///
/// Version history:
///   1.0 — #1576 lane 3: initial implementation
@Suite("Collection entries, removed by id")
@MainActor
struct CollectionEntryRemovalTests {

    private func ref(_ documentId: String) -> CollectionDocumentRef {
        CollectionDocumentRef(volumeId: "v1", documentId: documentId)
    }

    @Test("Undo removes exactly the entries the add inserted, and saves")
    func removesTheInsertedEntries() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let collection = Collection(name: "Chile")
        context.insert(collection)
        try CollectionDocumentDiscovery.appendDocuments([ref("d1")], to: collection, modelContext: context)
        let added = try CollectionDocumentDiscovery.appendDocuments(
            [ref("d1"), ref("d2"), ref("d3")], to: collection, modelContext: context)
        try #require(added.insertedCount == 2)

        let removed = try CollectionDocumentDiscovery.removeEntries(withIds: added.insertedEntryIds,
                                                                    modelContext: context)

        #expect(removed == 2)
        #expect(collection.documentCount == 1)
        #expect(!context.hasChanges)
        let saved = try ModelContext(container).fetch(FetchDescriptor<CollectionEntry>())
        #expect(saved.map(\.documentId) == ["d1"], "the document the collection held before the add stays")
    }

    /// One of the three was removed in the editor in the meantime. That entry is already undone.
    @Test("An entry that is gone already is not an error, and is not counted")
    func aMissingEntryIsAlreadyUndone() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let collection = Collection(name: "Chile")
        context.insert(collection)
        let added = try CollectionDocumentDiscovery.appendDocuments(
            [ref("d1"), ref("d2"), ref("d3")], to: collection, modelContext: context)
        let gone = try #require(collection.documentEntries?.first { $0.documentId == "d2" })
        gone.collection = nil
        context.delete(gone)
        try context.save()

        let removed = try CollectionDocumentDiscovery.removeEntries(withIds: added.insertedEntryIds,
                                                                    modelContext: context)
        #expect(removed == 2)
        #expect(try ModelContext(container).fetch(FetchDescriptor<CollectionEntry>()).isEmpty)

        // A second Undo finds nothing, removes nothing and writes nothing.
        #expect(try CollectionDocumentDiscovery.removeEntries(withIds: added.insertedEntryIds,
                                                              modelContext: context) == 0)
        #expect(try CollectionDocumentDiscovery.removeEntries(withIds: [], modelContext: context) == 0)
    }

    /// More ids than one fetch takes: the removal walks them in batches.
    @Test("A thousand entries are removed across batches")
    func removesAcrossBatches() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let collection = Collection(name: "Large")
        context.insert(collection)
        let added = try CollectionDocumentDiscovery.appendDocuments(
            (1...1_000).map { ref("d\($0)") }, to: collection, modelContext: context)
        try #require(added.insertedCount == 1_000)

        #expect(try CollectionDocumentDiscovery.removeEntries(withIds: added.insertedEntryIds,
                                                              modelContext: context) == 1_000)
        #expect(collection.documentCount == 0)
        #expect(try ModelContext(container).fetch(FetchDescriptor<CollectionEntry>()).isEmpty)
    }

    private struct SaveRefused: Error {}

    /// The function's own doc says what a failed save leaves: the entries deleted in the context
    /// and not on disk. The caller's line must therefore not say that nothing changed.
    @Test("A removal whose save fails throws, with the entries out of the collection and unsaved")
    func aFailedSaveLeavesTheRemovalPending() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let collection = Collection(name: "Chile")
        context.insert(collection)
        let added = try CollectionDocumentDiscovery.appendDocuments([ref("d1"), ref("d2")], to: collection,
                                                                    modelContext: context)

        #expect(throws: SaveRefused.self) {
            try CollectionDocumentDiscovery.removeEntries(withIds: added.insertedEntryIds, modelContext: context,
                                                          save: { _ in throw SaveRefused() })
        }
        #expect(collection.documentCount == 0, "the entries are out of the collection in memory")
        #expect(try ModelContext(container).fetch(FetchDescriptor<CollectionEntry>()).count == 2,
                "and still on disk")
        // A second try finds none to remove, which is why the caller offers none.
        #expect(try CollectionDocumentDiscovery.removeEntries(withIds: added.insertedEntryIds,
                                                              modelContext: context) == 0)
        // The next save that succeeds writes the removal.
        try context.save()
        #expect(try ModelContext(container).fetch(FetchDescriptor<CollectionEntry>()).isEmpty)
    }

    @Test("An entry of another collection, not named, is left alone")
    func leavesOtherEntries() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let chile = Collection(name: "Chile")
        let berlin = Collection(name: "Berlin")
        context.insert(chile)
        context.insert(berlin)
        let inChile = try CollectionDocumentDiscovery.appendDocuments([ref("d1")], to: chile, modelContext: context)
        try CollectionDocumentDiscovery.appendDocuments([ref("d1")], to: berlin, modelContext: context)

        #expect(try CollectionDocumentDiscovery.removeEntries(withIds: inChile.insertedEntryIds,
                                                              modelContext: context) == 1)
        #expect(chile.documentCount == 0)
        #expect(berlin.documentCount == 1)
    }
}

// MARK: - UITestBulkVolumeSeederTests

#if DEBUG
/// The thirty-document volume the bulk-actions UI suite searches (#1576 lane 3).
///
/// Version history:
///   1.0 — #1576 lane 3: initial implementation
@Suite("UI-test bulk volume")
struct UITestBulkVolumeSeederTests {

    private func makeVolumesDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("frus-bulk-volume-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("A launch that asks writes the volume, and one that does not removes it and nothing else")
    func writtenWhenAskedAndRemovedWhenNot() throws {
        let dir = try makeVolumesDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let other = dir.appendingPathComponent("frus1961-63v06.xml")
        try Data("<TEI/>".utf8).write(to: other)
        let bulk = dir.appendingPathComponent("\(UITestVolumeSeeder.bulkVolumeId).xml")

        #expect(!UITestVolumeSeeder.prepareBulkVolume(requested: false, in: dir), "nothing to remove yet")
        #expect(UITestVolumeSeeder.prepareBulkVolume(requested: true, in: dir))
        #expect(FileManager.default.fileExists(atPath: bulk.path))

        #expect(UITestVolumeSeeder.prepareBulkVolume(requested: false, in: dir))
        #expect(!FileManager.default.fileExists(atPath: bulk.path))
        #expect(FileManager.default.fileExists(atPath: other.path), "another volume's file is not the seed's to remove")
    }

    @Test("The volume holds thirty documents, each with the query word and a title of its own")
    func fixtureShape() {
        let xml = UITestVolumeSeeder.bulkVolumeXML()
        #expect(UITestVolumeSeeder.bulkDocumentCount == 30)
        #expect(xml.components(separatedBy: "<div type=\"document\"").count - 1 == 30)
        #expect(xml.components(separatedBy: UITestVolumeSeeder.bulkQueryWord).count - 1 == 30)
        #expect(xml.contains("<head>UI Test Bulk Document 01</head>"))
        #expect(xml.contains("<head>UI Test Bulk Document 30</head>"))
        // The browse fixture's suites match its titles by substring; none of these may hold one.
        #expect(!xml.contains("UI Test Document"))
        #expect(!UITestVolumeSeeder.fixtureXML(volumeId: "frus1961-63v06").contains(UITestVolumeSeeder.bulkQueryWord),
                "the query word must list this volume's documents and no other fixture's")
    }

    /// Driven against a real pipeline: indexed when asked for, and a search for the word lists
    /// the thirty; un-indexed on the next launch that does not ask.
    @Test("The index follows the launch, and a search for the word lists the thirty documents")
    func indexFollowsTheLaunch() async throws {
        let dir = try makeVolumesDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let dbURL = dir.appendingPathComponent("frus.db")
        let store = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(fts5Store: store, databaseURL: dbURL, volumesDirectory: dir,
                                            concurrencyLimit: 1)
        let service = SearchService(fts5Store: store, pipeline: pipeline)
        let query = SearchParameters(keywords: UITestVolumeSeeder.bulkQueryWord)

        UITestVolumeSeeder.prepareBulkVolume(requested: true, in: dir)
        await UITestVolumeSeeder.prepareBulkVolumeIndex(pipeline: pipeline, requested: true)
        #expect(try pipeline.isVolumeIndexed(UITestVolumeSeeder.bulkVolumeId))
        let listed = try await service.search(parameters: query, limit: 100)
        #expect(listed.count == 30)
        #expect(Set(listed.map(\.header)).count == 30, "each row has its own title")
        #expect(listed.allSatisfy { $0.header.hasPrefix("UI Test Bulk Document ") })

        UITestVolumeSeeder.prepareBulkVolume(requested: false, in: dir)
        await UITestVolumeSeeder.prepareBulkVolumeIndex(pipeline: pipeline, requested: false)
        #expect(try !pipeline.isVolumeIndexed(UITestVolumeSeeder.bulkVolumeId))
        #expect(try await service.search(parameters: query, limit: 100).isEmpty)
    }
}
#endif
