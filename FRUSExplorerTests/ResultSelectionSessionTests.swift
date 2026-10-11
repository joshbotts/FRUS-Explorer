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
import Testing
@testable import FRUSExplorer

// MARK: - ResultSelectionSessionTests

/// The selection's rules as a value (#1576 lane 4): the type the iPhone's and the Mac's search view
/// models both hold.
///
/// `SearchSelectionModelTests` drives the same rules through `SearchViewModel` and a real search.
/// These hold them one at a time, with nothing else in the way, because the Mac's view model has
/// no test that runs: what it does with a selection is what this type does.
///
/// Version history:
///   1.0 — #1576 lane 4: initial implementation
///   1.1 — #1576 lane 4, review: three assertions that passed with their rule removed now do not
@Suite("Result selection session (#1576 lane 4)")
struct ResultSelectionSessionTests {

    private static func anchor(_ query: String) -> ChecklistAnchor {
        ChecklistAnchor(query: query, parameters: SearchParameters())
    }

    /// A session in selection, anchored to "alpha", with `keys` picked.
    private static func selecting(_ keys: [String] = []) -> ResultSelectionSession {
        var session = ResultSelectionSession()
        session.begin(anchor: anchor("alpha"))
        session.pick(keys)
        return session
    }

    private struct Refused: LocalizedError {
        var errorDescription: String? { "The disk is full." }
    }

    /// The tag half of an Undo, for a test whose command gave no tag: it must not be asked.
    private static func noTagUndo(_ ids: [UUID]) -> Int {
        Issue.record("no tag assignment is involved")
        return 0
    }

    @Test("Beginning enters selection with the row picked; a second begin adds its row and keeps the search and the line")
    func beginEnters() {
        var session = ResultSelectionSession()
        #expect(!session.selection.isSelecting)
        session.begin(picking: "v/d1", anchor: Self.anchor("alpha"))
        #expect(session.selection.isSelecting)
        #expect(session.selection.keys == ["v/d1"])

        // A second begin, from another row's menu, adds that row and keeps what is there.
        session.recordMark(hidden: 2)
        session.begin(picking: "v/d2", anchor: Self.anchor("beta"))
        #expect(session.selection.keys == ["v/d1", "v/d2"])
        #expect(session.outcome != nil, "entering a selection that is already on keeps its line")
        // The anchor is still the first search's: a re-run of "alpha" keeps the picks.
        session.settle(for: Self.anchor("alpha"))
        #expect(session.selection.isSelecting)
    }

    @Test("Ending forgets the picks and the line, and a new selection starts clean")
    func endForgets() {
        var session = Self.selecting(["v/d1"])
        session.recordMark(hidden: 1)
        let counted = session.outcomeSerial
        session.end()
        #expect(!session.selection.isSelecting)
        #expect(session.selection.count == 0)
        #expect(session.outcome == nil)
        #expect(session.outcomeSerial == counted, "the count of outcomes never goes back")

        session.begin(anchor: Self.anchor("beta"))
        session.settle(for: Self.anchor("alpha"))
        #expect(!session.selection.isSelecting, "the new selection is anchored to its own search")

        // Picks a replaced list dropped are forgotten with the rest: Done before the search
        // completes, and the next selection is not told of picks it never had.
        var dropped = Self.selecting(["v/d1", "v/d2"])
        dropped.resultsWereReplaced(nowEmpty: false, shown: ["v/d1"])
        dropped.end()
        dropped.begin(anchor: Self.anchor("alpha"))
        dropped.settle(for: Self.anchor("alpha"))
        #expect(dropped.selection.isSelecting)
        #expect(dropped.outcome == nil)
    }

    @Test("Outside selection nothing is picked")
    func picksNeedSelection() {
        var session = ResultSelectionSession()
        session.toggle("v/d1")
        session.pick(["v/d2", "v/d3"])
        #expect(session.selection.count == 0)

        session.begin(anchor: Self.anchor("alpha"))
        session.toggle("v/d1")
        session.pick(["v/d2", "v/d3"])
        #expect(session.selection.count == 3)
        session.toggle("v/d1")
        #expect(session.selection.keys == ["v/d2", "v/d3"])
        session.clear()
        #expect(session.selection.count == 0)
        #expect(session.selection.isSelecting, "None clears the picks and stays in selection")
    }

    @Test("A thousand picks can be added, one more cannot, and none cannot")
    func addLimit() {
        let limit = CollectionDocumentDiscovery.bulkDocumentLimit
        #expect(limit == 1_000, "fixture: the owner's decision 5")
        let none = Self.selecting()
        #expect(!none.canAdd && !none.exceedsAddLimit)
        let atLimit = Self.selecting((0..<limit).map { "v/d\($0)" })
        #expect(atLimit.canAdd && !atLimit.exceedsAddLimit)
        let over = Self.selecting((0...limit).map { "v/d\($0)" })
        #expect(!over.canAdd && over.exceedsAddLimit)
    }

    @Test("Each outcome is counted, the same words twice included")
    func outcomesAreCounted() {
        var session = Self.selecting()
        session.recordMark(hidden: 25)
        session.recordMark(hidden: 25)
        #expect(session.outcomeSerial == 2)
        #expect(session.outcome?.message == ChecklistCopy.markedAnnouncement(25))
    }

    @Test("A mark is recorded in selection only; one that hid rows offers its Undo, and one that hid none does not")
    func markOutcome() {
        // Outside selection no line is kept, which is why a new selection starts with none.
        var outside = ResultSelectionSession()
        outside.recordMark(hidden: 3)
        #expect(outside.outcome == nil && outside.outcomeSerial == 0)
        outside.begin(anchor: Self.anchor("alpha"))
        #expect(outside.outcome == nil)

        var session = Self.selecting()
        session.recordMark(hidden: 3)
        #expect(session.outcome == BulkOutcome(message: ChecklistCopy.markedAnnouncement(3), undo: .reviewedMarks))
        session.recordMark(hidden: 0)
        #expect(session.outcome?.undo == nil)
    }

    @Test("An add is recorded in selection only, with its Undo when it inserted something")
    func addOutcome() {
        let ids = [UUID(), UUID()]
        var outside = ResultSelectionSession()
        outside.recordAdd(CollectionDocumentAppend(insertedEntryIds: ids, alreadyPresent: 0), collectionName: "Chile")
        #expect(outside.outcome == nil && outside.outcomeSerial == 0)

        var session = Self.selecting(["v/d1", "v/d2", "v/d3"])
        session.recordAdd(CollectionDocumentAppend(insertedEntryIds: ids, alreadyPresent: 1), collectionName: "Chile")
        #expect(session.outcome == BulkOutcome(
            message: ResultSelectionCopy.added(2, alreadyPresent: 1, to: "Chile"),
            undo: .collectionEntries(ids: ids, collectionName: "Chile")))
        #expect(session.selection.count == 3, "the picks stay after an add")

        session.recordAdd(CollectionDocumentAppend(insertedEntryIds: [], alreadyPresent: 3), collectionName: "Chile")
        #expect(session.outcome == BulkOutcome(
            message: ResultSelectionCopy.added(0, alreadyPresent: 3, to: "Chile"), undo: nil))
    }

    @Test("Undo of an add removes the entries by id, says how many went, and offers no second Undo")
    func undoOfAnAdd() {
        let ids = [UUID(), UUID()]
        var session = Self.selecting(["v/d1"])
        session.recordAdd(CollectionDocumentAppend(insertedEntryIds: ids, alreadyPresent: 0), collectionName: "Chile")
        var asked: [UUID] = []
        var marksRestored = 0
        session.undo(removingEntries: { asked = $0; return 1 }, removingTagAssignments: Self.noTagUndo,
                     restoringMarks: { marksRestored += 1; return 0 })
        #expect(asked == ids)
        #expect(marksRestored == 0, "an add's Undo does not touch the marks")
        #expect(session.outcome == BulkOutcome(message: ResultSelectionCopy.removed(1, from: "Chile"), undo: nil))
    }

    @Test("An Undo that throws says it did not finish, and offers no second try")
    func undoThatThrows() {
        var session = Self.selecting(["v/d1"])
        session.recordAdd(CollectionDocumentAppend(insertedEntryIds: [UUID()], alreadyPresent: 0), collectionName: "Chile")
        session.undo(removingEntries: { _ in throw Refused() }, removingTagAssignments: Self.noTagUndo,
                     restoringMarks: { 0 })
        #expect(session.outcome == BulkOutcome(message: "Undo did not finish: The disk is full.", undo: nil))
    }

    @Test("Undo of a mark restores the marks and says how many rows came back")
    func undoOfAMark() {
        var session = Self.selecting()
        session.recordMark(hidden: 4)
        var removed = 0
        session.undo(removingEntries: { _ in removed += 1; return 0 },
                     removingTagAssignments: { _ in removed += 1; return 0 }, restoringMarks: { 4 })
        #expect(removed == 0, "a mark's Undo removes nothing from a collection")
        #expect(session.outcome == BulkOutcome(message: ChecklistCopy.undoneAnnouncement(4), undo: nil))
    }

    // MARK: Tagging (#1576 lane 5)

    private static func doc(_ documentId: String) -> CollectionDocumentRef {
        CollectionDocumentRef(volumeId: "v", documentId: documentId)
    }

    @Test("A tagging is recorded in selection only, with its Undo when it inserted something")
    func taggingOutcome() {
        let ids = [UUID(), UUID()]
        let tagged = UserTagAssign(insertedAssignmentIds: ids, taggedDocuments: [Self.doc("d1"), Self.doc("d2")],
                                   alreadyTagged: 1, tagIdsByDocument: [:])
        var outside = ResultSelectionSession()
        outside.recordTagging(tagged, tagNames: ["Chile"])
        #expect(outside.outcome == nil && outside.outcomeSerial == 0)

        var session = Self.selecting(["v/d1", "v/d2", "v/d3"])
        session.recordTagging(tagged, tagNames: ["Chile"])
        #expect(session.outcome == BulkOutcome(
            message: ResultSelectionCopy.tagged(2, alreadyTagged: 1, tagNames: ["Chile"]),
            undo: .tagAssignments(ids: ids, tagNames: ["Chile"])))
        #expect(session.selection.count == 3, "the picks stay after a tagging")

        session.recordTagging(UserTagAssign(insertedAssignmentIds: [], taggedDocuments: [], alreadyTagged: 3,
                                            tagIdsByDocument: [:]), tagNames: ["Chile"])
        #expect(session.outcome == BulkOutcome(
            message: ResultSelectionCopy.tagged(0, alreadyTagged: 3, tagNames: ["Chile"]), undo: nil))
    }

    @Test("Undo of a tagging removes the rows by id, says how many documents lost the tag, and offers no second Undo")
    func undoOfATagging() {
        let ids = [UUID(), UUID(), UUID()]
        var session = Self.selecting(["v/d1"])
        session.recordTagging(UserTagAssign(insertedAssignmentIds: ids,
                                            taggedDocuments: [Self.doc("d1"), Self.doc("d2"), Self.doc("d3")],
                                            alreadyTagged: 0, tagIdsByDocument: [:]),
                              tagNames: ["Chile", "Copper"])
        var asked: [UUID] = []
        var others = 0
        session.undo(removingEntries: { _ in others += 1; return 0 },
                     removingTagAssignments: { asked = $0; return 2 },
                     restoringMarks: { others += 1; return 0 })
        #expect(asked == ids)
        #expect(others == 0, "a tagging's Undo touches neither a collection nor the marks")
        #expect(session.outcome == BulkOutcome(
            message: ResultSelectionCopy.untagged(2, tagNames: ["Chile", "Copper"]), undo: nil))
    }

    @Test("A tagging's Undo that throws says it did not finish, and offers no second try")
    func taggingUndoThatThrows() {
        var session = Self.selecting(["v/d1"])
        session.recordTagging(UserTagAssign(insertedAssignmentIds: [UUID()], taggedDocuments: [Self.doc("d1")],
                                            alreadyTagged: 0, tagIdsByDocument: [:]), tagNames: ["Chile"])
        session.undo(removingEntries: { _ in 0 }, removingTagAssignments: { _ in throw Refused() },
                     restoringMarks: { 0 })
        #expect(session.outcome == BulkOutcome(message: "Undo did not finish: The disk is full.", undo: nil))
    }

    @Test("A tagging's line is no business of the checklist's, and stays when the marks change")
    func taggingLineIsNotWithdrawn() {
        var session = Self.selecting(["v/d1"])
        session.recordTagging(UserTagAssign(insertedAssignmentIds: [UUID()], taggedDocuments: [Self.doc("d1")],
                                            alreadyTagged: 0, tagIdsByDocument: [:]), tagNames: ["Chile"])
        let line = session.outcome
        session.withdrawOutcomeOfferingToUndoMarks()
        #expect(session.outcome == line)
    }

    @Test("With nothing to undo, Undo does nothing")
    func undoWithNothingToUndo() {
        var session = Self.selecting()
        session.recordMark(hidden: 0)
        let counted = session.outcomeSerial
        var called = 0
        session.undo(removingEntries: { _ in called += 1; return 0 },
                     removingTagAssignments: { _ in called += 1; return 0 },
                     restoringMarks: { called += 1; return 0 })
        #expect(called == 0)
        #expect(session.outcomeSerial == counted)
    }

    /// The checklist strip marks pages and undoes them by itself. A line here that offered to
    /// undo an earlier mark would then name the wrong rows; a line about an add is no business
    /// of the strip's.
    @Test("Only a line that offers to undo a mark is withdrawn when the marks change elsewhere")
    func withdrawal() {
        var marked = Self.selecting()
        marked.recordMark(hidden: 2)
        marked.withdrawOutcomeOfferingToUndoMarks()
        #expect(marked.outcome == nil)

        var added = Self.selecting(["v/d1"])
        added.recordAdd(CollectionDocumentAppend(insertedEntryIds: [UUID()], alreadyPresent: 0), collectionName: "Chile")
        let line = added.outcome
        added.withdrawOutcomeOfferingToUndoMarks()
        #expect(added.outcome == line)

        var undone = Self.selecting()
        undone.recordMark(hidden: 0)
        undone.withdrawOutcomeOfferingToUndoMarks()
        #expect(undone.outcome != nil, "a line with no Undo stays")
    }

    @Test("A replaced list drops the picks it does not show, and an emptied one ends selection")
    func replacedList() {
        var session = Self.selecting(["v/d1", "v/d2", "v/d3"])
        session.resultsWereReplaced(nowEmpty: false, shown: ["v/d1", "v/d9"])
        #expect(session.selection.keys == ["v/d1"])
        #expect(session.selection.isSelecting)

        // A list that holds rows and shows none, because Checklist Mode hides them all, is not
        // an emptied list: selection stays, with nothing picked, and the picks are counted.
        session.resultsWereReplaced(nowEmpty: false, shown: [])
        #expect(session.selection.isSelecting)
        #expect(session.selection.count == 0)
        session.settle(for: Self.anchor("alpha"))
        #expect(session.outcome == BulkOutcome(message: ResultSelectionCopy.dropped(3), undo: nil),
                "two picks went with the first list and one with the second")

        // An emptied list ends selection, and is not asked what it shows.
        var read = 0
        session.pick(["v/d7"])
        session.resultsWereReplaced(nowEmpty: true, shown: { read += 1; return ["v/d7"] }())
        #expect(!session.selection.isSelecting)
        #expect(read == 0)
    }

    @Test("Outside selection a replaced list is not even read")
    func replacedListOutsideSelection() {
        var session = ResultSelectionSession()
        var read = 0
        session.resultsWereReplaced(nowEmpty: false, shown: { read += 1; return Set<String>() }())
        session.prune(toShown: { read += 1; return Set<String>() }())
        #expect(read == 0, "the shown set is built from a sorted, filtered list: not for nothing")

        // In selection with no picks, a hidden row is nothing to prune either.
        session.begin(anchor: Self.anchor("alpha"))
        session.prune(toShown: { read += 1; return Set<String>() }())
        #expect(read == 0)
    }

    @Test("A row Checklist Mode hides leaves the picks, and is not counted as dropped by a re-run")
    func hiddenRowIsPruned() {
        var session = Self.selecting(["v/d1", "v/d2"])
        session.prune(toShown: ["v/d2"])
        #expect(session.selection.keys == ["v/d2"])
        session.settle(for: Self.anchor("alpha"))
        #expect(session.outcome == nil, "a hidden row is not a dropped pick: the re-run dropped none")
    }

    @Test("The same search, completed, keeps the picks and says how many it dropped, once")
    func sameSearchSettles() {
        var session = Self.selecting(["v/d1", "v/d2", "v/d3"])
        session.resultsWereReplaced(nowEmpty: false, shown: ["v/d1"])
        session.settle(for: Self.anchor("alpha"))
        #expect(session.selection.isSelecting)
        #expect(session.selection.keys == ["v/d1"])
        #expect(session.outcome == BulkOutcome(message: ResultSelectionCopy.dropped(2), undo: nil))

        // The next completed run of the same search dropped nothing: the line goes.
        session.resultsWereReplaced(nowEmpty: false, shown: ["v/d1"])
        session.settle(for: Self.anchor("alpha"))
        #expect(session.outcome == nil)
        #expect(session.selection.keys == ["v/d1"])
    }

    @Test("A completed search ends the last command's line and its Undo")
    func completedSearchEndsTheLine() {
        var session = Self.selecting(["v/d1"])
        session.recordMark(hidden: 1)
        session.settle(for: Self.anchor("alpha"))
        #expect(session.outcome == nil)
        #expect(session.selection.isSelecting)
    }

    @Test("Another search, completed, ends selection")
    func anotherSearchEnds() {
        var session = Self.selecting(["v/d1"])
        session.resultsWereReplaced(nowEmpty: false, shown: ["v/d1"])
        session.settle(for: Self.anchor("beta"))
        #expect(!session.selection.isSelecting)
        #expect(session.selection.count == 0)
    }

    @Test("Outside selection a completed search changes nothing, before a selection and after one")
    func settleOutsideSelection() {
        var session = ResultSelectionSession()
        session.settle(for: Self.anchor("alpha"))
        #expect(session == ResultSelectionSession())

        // After a selection that set a line: the count of outcomes stays, and nothing comes back.
        var ended = Self.selecting(["v/d1"])
        ended.recordMark(hidden: 1)
        ended.end()
        let before = ended
        ended.settle(for: Self.anchor("alpha"))
        #expect(ended == before)
        #expect(ended.outcomeSerial == 1)
    }
}

// MARK: - ChecklistShownSearchTests

/// Whether a checklist is on the search whose rows are on screen (#1576 lane 4): the question the
/// Mac's window asks before it marks a selection reviewed. It anchors its checklist to a search
/// when the search is sent, and shows the last search's rows until the new ones arrive.
///
/// Version history:
///   1.0 — #1576 lane 4, review: initial implementation
@Suite("A checklist and the rows on screen (#1576 lane 4)")
struct ChecklistShownSearchTests {

    private static func anchor(_ query: String, _ parameters: SearchParameters = SearchParameters()) -> ChecklistAnchor {
        ChecklistAnchor(query: query, parameters: parameters)
    }

    @Test("The same words are the same search, and other words are not")
    func words() {
        let checklist = Self.anchor("berlin")
        #expect(checklist.isOnTheSearch(shown: Self.anchor("berlin")))
        // A filter changed is the same search with words: its rows are this checklist's.
        #expect(checklist.isOnTheSearch(shown: Self.anchor("berlin", SearchParameters(personRef: "p_KHA1"))))
        // "berlin wall" has been sent and anchors the checklist; "berlin"'s rows are still shown.
        #expect(!Self.anchor("berlin wall").isOnTheSearch(shown: checklist),
                "the checklist is already the next search's, and the rows are still the last one's")
    }

    @Test("With no completed search to compare, nothing is known against a mark")
    func nothingCompleted() {
        #expect(Self.anchor("berlin").isOnTheSearch(shown: nil))
    }

    /// The direction. A checklist keeps its anchor through a narrowing of the same browse, so
    /// the rows on screen can be of a narrower search than the anchor names. Asked the other way
    /// round, every such checklist would refuse its own rows.
    @Test("A checklist anchored to a browse is on a narrowing of it, and not the other way round")
    func narrowing() {
        let person = Self.anchor("", SearchParameters(personRef: "p_KHA1"))
        let narrowed = Self.anchor("", SearchParameters(personRef: "p_KHA1", subjectRef: "rec_korean_war"))
        #expect(person.isOnTheSearch(shown: narrowed))
        #expect(!narrowed.isOnTheSearch(shown: person))
        #expect(!person.isOnTheSearch(shown: Self.anchor("", SearchParameters(personRef: "p_RWP1"))))
    }
}

// MARK: - ResultSelectionMacCopyTests

/// The words the Mac's selection adds (#1576 lane 4).
///
/// Version history:
///   1.0 — #1576 lane 4: initial implementation
@Suite("Result selection, the Mac's words (#1576 lane 4)")
struct ResultSelectionMacCopyTests {

    private static let enUS = Locale(identifier: "en_US")

    @Test("The toolbar's toggle, and what it says it does in each state")
    func toggle() {
        #expect(ResultSelectionCopy.selectToggle == "Select")
        #expect(ResultSelectionCopy.selectToggleOnHelp
                == "Select results, to add several to a collection or mark them reviewed at once")
        #expect(ResultSelectionCopy.selectToggleOffHelp == "Leave selection and clear the checkboxes")
        // Compiled for the Mac, where `macTextNeverSaysTap` refuses the word.
        for text in [ResultSelectionCopy.selectToggleOnHelp, ResultSelectionCopy.selectToggleOffHelp] {
            #expect(!text.lowercased().contains("tap"))
        }
    }

    @Test("A checked row's menu says how many the command is for")
    func addSelected() {
        #expect(ResultSelectionCopy.addSelectedToCollection(12, locale: Self.enUS) == "Add 12 Selected to Collection…")
        #expect(ResultSelectionCopy.addSelectedToCollection(1_250, locale: Self.enUS)
                == "Add 1,250 Selected to Collection…")
        #expect(ResultSelectionCopy.addTagsToSelected(12, locale: Self.enUS) == "Add Tags to 12 Selected…")
        #expect(ResultSelectionCopy.addTagsToSelected(1_250, locale: Self.enUS) == "Add Tags to 1,250 Selected…")
    }
}

// MARK: - ResultTaggingCopyTests

/// The words of Add Tags on search results (#1576 lane 5).
///
/// Version history:
///   1.0 — #1576 lane 5: initial implementation
@Suite("Result tagging, the words (#1576 lane 5)")
struct ResultTaggingCopyTests {

    private static let enUS = Locale(identifier: "en_US")

    @Test("The command's name, on a row and in the two selection bars")
    func command() {
        #expect(BulkResultCopy.addTags == "Add Tags…")
    }

    @Test("One tag is named, and the documents that had it already are counted")
    func oneTag() {
        #expect(ResultSelectionCopy.tagged(31, alreadyTagged: 0, tagNames: ["Chile"], locale: Self.enUS)
                == "Added “Chile” to 31 documents.")
        #expect(ResultSelectionCopy.tagged(1, alreadyTagged: 0, tagNames: ["Chile"], locale: Self.enUS)
                == "Added “Chile” to 1 document.")
        #expect(ResultSelectionCopy.tagged(31, alreadyTagged: 6, tagNames: ["Chile"], locale: Self.enUS)
                == "Added “Chile” to 31 documents. 6 already had it.")
        #expect(ResultSelectionCopy.tagged(1_200, alreadyTagged: 1, tagNames: ["Chile"], locale: Self.enUS)
                == "Added “Chile” to 1,200 documents. 1 already had it.")
    }

    @Test("Several tags are counted, not named")
    func severalTags() {
        #expect(ResultSelectionCopy.tagged(31, alreadyTagged: 0, tagNames: ["Chile", "Copper", "ITT"], locale: Self.enUS)
                == "Added 3 tags to 31 documents.")
        #expect(ResultSelectionCopy.tagged(31, alreadyTagged: 6, tagNames: ["Chile", "Copper"], locale: Self.enUS)
                == "Added 2 tags to 31 documents. 6 already had them.")
    }

    @Test("Nothing added says who had the tags already")
    func nothingAdded() {
        #expect(ResultSelectionCopy.tagged(0, alreadyTagged: 1, tagNames: ["Chile"], locale: Self.enUS)
                == "Nothing added: 1 document already had “Chile”.")
        #expect(ResultSelectionCopy.tagged(0, alreadyTagged: 37, tagNames: ["Chile"], locale: Self.enUS)
                == "Nothing added: 37 documents already had “Chile”.")
        #expect(ResultSelectionCopy.tagged(0, alreadyTagged: 1, tagNames: ["Chile", "Copper"], locale: Self.enUS)
                == "Nothing added: 1 document already had those tags.")
        #expect(ResultSelectionCopy.tagged(0, alreadyTagged: 37, tagNames: ["Chile", "Copper"], locale: Self.enUS)
                == "Nothing added: 37 documents already had those tags.")
    }

    @Test("An undone tagging, and what its Undo says it takes back")
    func undone() {
        #expect(ResultSelectionCopy.untagged(31, tagNames: ["Chile"], locale: Self.enUS)
                == "Removed “Chile” from 31 documents.")
        #expect(ResultSelectionCopy.untagged(1, tagNames: ["Chile"], locale: Self.enUS)
                == "Removed “Chile” from 1 document.")
        #expect(ResultSelectionCopy.untagged(31, tagNames: ["Chile", "Copper"], locale: Self.enUS)
                == "Removed 2 tags from 31 documents.")
        let hint = ResultSelectionCopy.undoHint(for: .tagAssignments(ids: [], tagNames: ["Chile"]))
        #expect(hint == "Takes the tags this command added back off the documents")
        #expect(!hint.lowercased().contains("tap"), "compiled for the Mac, where `macTextNeverSaysTap` refuses the word")
    }

    @Test("The limit's line speaks for both commands it dims")
    func overLimit() {
        #expect(ResultSelectionCopy.overLimit(1_000, locale: Self.enUS)
                == "Select 1,000 documents or fewer to add them to a collection or to tag them.")
    }
}

// MARK: - MacResultSelectionWiringTests

/// The Mac Search window's selection, read from source (#1576 lane 4). Nothing runs this half:
/// both test targets are iOS's. So the rules are ``ResultSelectionSession``'s, which the suites
/// above and `SearchSelectionModelTests` run, and these scans hold the Mac's view model and
/// window to calling them, each matched on the call.
///
/// A scan holds the source to a shape. What the window then does was read from the running Mac
/// check copy on 2026-10-10 and is in the lane's pull request; no test here runs it.
///
/// Version history:
///   1.0 — #1576 lane 4: initial implementation
///   1.1 — #1576 lane 4, review: the marks are forgotten in one place; Mark Reviewed waits for the
///         rows it would mark; the toggle is not dimmed while on; the checkbox is named once;
///         Space acts once for each press; titles say what a scan reads, not what the window does
@Suite("Result selection on the Mac, the wiring (#1576 lane 4)")
struct MacResultSelectionWiringTests {

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

    private static let macModel = "FRUSExplorer/App/MacSearchViewModel.swift"
    private static let iOSModel = "FRUSExplorer/Search/SearchViewModel.swift"
    private static let window = "FRUSExplorer/App/SearchSheet.swift"

    /// The members a view reads or calls, the two that follow the list, and the one that forgets
    /// the checklist's marks. Each is the same text in the two view models, so a twin that drifts
    /// is a twin that differs here. Most are one call into the session; `beginSelecting`,
    /// `undoBulkOutcome`, `forgetReviewedMarks` and lane 5's two for tags are a few lines each.
    private static let twins = [
        "var resultSelection: ResultSelection {",
        "var bulkOutcome: BulkOutcome? {",
        "var bulkOutcomeSerial: Int {",
        "var selectedResults: [SearchResult] {",
        "var selectionExceedsAddLimit: Bool {",
        "var canAddSelectionToCollection: Bool {",
        "func beginSelecting(with result: SearchResult? = nil) {",
        "func endSelecting() {",
        "func toggleSelection(of result: SearchResult) {",
        "func selectPage() {",
        "func selectAllShown() {",
        "func selectNone() {",
        "func recordCollectionAdd(_ outcome: CollectionDocumentAppend, collectionName: String) {",
        "func undoBulkOutcome(removingEntries: ([UUID]) throws -> Int,",
        "func recordTagAssign(_ outcome: UserTagAssign, tagNames: [String]) {",
        "func refreshUserTags(_ tagIdsByDocument: [String: Set<UUID>]) {",
        "private func selectionFollowsReplacedResults() {",
        "private func pruneSelection() {",
        "private func forgetReviewedMarks() {",
    ]

    /// A one-line declaration (`var x: T { … }`) or a braced one, whichever `header` opens.
    private static func member(_ header: String, in source: String) throws -> String {
        let start = try #require(source.range(of: header), "\(header) is gone: moved or renamed?")
        let lineEnd = source[start.upperBound...].firstIndex(of: "\n") ?? source.endIndex
        let line = String(source[start.lowerBound..<lineEnd])
        if line.hasSuffix("}") { return line }
        return try declaration(header, in: source)
    }

    @Test("The Mac's view model holds the session and each of its selection functions is its twin's")
    func viewModelIsItsTwins() throws {
        let mac = try Self.source(Self.macModel)
        let iOS = try Self.source(Self.iOSModel)
        #expect(mac.contains("private var selectionSession = ResultSelectionSession()"))
        #expect(iOS.contains("private var selectionSession = ResultSelectionSession()"))
        var compared = 0
        for header in Self.twins {
            let macBody = Self.squeezedCode(try Self.member(header, in: mac))
            let iOSBody = Self.squeezedCode(try Self.member(header, in: iOS))
            #expect(macBody == iOSBody, "\(header) differs between the two view models")
            compared += 1
        }
        #expect(compared == 19)
    }

    /// A line in the strip that offers to undo a mark is true only while the mark can be undone.
    /// Read from the running window before this: with a selection marked reviewed and Checklist
    /// Mode then turned off, the rows came back and the line stayed, and its Undo said that no
    /// result was back in the list.
    @Test("Each view model resets its marks in one function, which withdraws the line that offered to undo them")
    func marksAreForgottenInOnePlace() throws {
        for path in [Self.macModel, Self.iOSModel] {
            let source = try Self.source(path)
            #expect(Self.squeezedCode(try Self.declaration("private func forgetReviewedMarks() {", in: source))
                .contains(Self.squeezed("""
                    reviewedMarks.reset()
                    selectionSession.withdrawOutcomeOfferingToUndoMarks()
                    """)), "\(path)")
            let code = source.split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            #expect(code.filter { $0.contains("reviewedMarks.reset()") }.count == 1,
                    "\(path): a reset anywhere else leaves the line behind")
            #expect(code.filter { $0.contains("forgetReviewedMarks()") && !$0.contains("func ") }.count == 3,
                    "\(path): Checklist Mode turned on, turned off, and another search")
        }
    }

    /// The two that are not word for word the same, each for a reason of its platform, and the
    /// one the iPhone has no twin of.
    @Test("The Mac marks through its own bulk mark, only on the search whose rows it shows, and records the search with the rows")
    func theTwoThatDiffer() throws {
        let mac = try Self.source(Self.macModel)
        #expect(Self.squeezedCode(try Self.declaration("func markSelectionReviewed() {", in: mac))
            .contains(Self.squeezed("""
                guard canMarkSelectionReviewed else { return }
                let hidden = markReviewed(selectedResults)
                selectionSession.recordMark(hidden: hidden)
                """)), "marked first and recorded after, so the two writes to the session do not overlap")
        // The rule is `ChecklistAnchor.isOnTheSearch(shown:)`, which `ChecklistShownSearchTests` runs.
        #expect(Self.squeezedCode(try Self.declaration("var canMarkSelectionReviewed: Bool {", in: mac))
            .contains(Self.squeezed("""
                checklistMode && (checklistAnchor?.isOnTheSearch(shown: lastCompletedSearchAnchor) ?? true)
                """)), "this window anchors its checklist to a search before the search's rows arrive")
        #expect(!(try Self.source(Self.iOSModel)).contains("canMarkSelectionReviewed"),
                "the iPhone settles its checklist with the rows, and has no gap to guard")
        #expect(Self.squeezedCode(try Self.declaration(
            "private func settleSelection(for anchor: ChecklistAnchor) {", in: mac))
            .contains(Self.squeezed("""
                lastCompletedSearchAnchor = anchor
                selectionSession.settle(for: anchor)
                """)), "the Mac settles its checklist before a search runs, so the selection keeps the anchor itself")
    }

    @Test("Six properties of the Mac's view model take rows off its list, and each tells the selection")
    func observersFollowTheList() throws {
        let code = Self.squeezedCode(try Self.source(Self.macModel))
        #expect(code.contains(Self.squeezed("""
            var results: [SearchResult] = [] {
                didSet { selectionFollowsReplacedResults() }
            }
            """)))
        #expect(code.contains(Self.squeezed("""
            var searchError: Error? = nil {
                didSet { if searchError != nil { endSelecting() } }
            }
            """)))
        #expect(code.contains(Self.squeezed("""
            var searchMode: SearchMode = .keywords {
                didSet { if searchMode != oldValue { endSelecting() } }
            }
            """)))
        for property in ["var checklistMode: Bool = false {",
                         "var readSinceEnabledKeys: Set<String> = [] {",
                         "private(set) var reviewedMarks = ReviewedMarks() {"] {
            #expect(code.contains(Self.squeezed(property + " didSet { clampCurrentPage(); pruneSelection() } }")),
                    "\(property) must prune the selection when it changes")
        }
    }

    @Test("The strip's own mark and Undo withdraw a line that offered the same undo")
    func stripWithdrawsTheLine() throws {
        let mac = try Self.source(Self.macModel)
        #expect(Self.squeezedCode(try Self.declaration("func markReviewed(_ results: [SearchResult]) -> Int {", in: mac))
            .contains(Self.squeezed("selectionSession.withdrawOutcomeOfferingToUndoMarks() return hidden")))
        #expect(Self.squeezedCode(try Self.declaration("func undoLastBulkMark() -> Int {", in: mac))
            .contains(Self.squeezed("""
                reviewedMarks.undoLastBulk()
                selectionSession.withdrawOutcomeOfferingToUndoMarks()
                return restored
                """)))
    }

    /// With the rows and before the next suspension: between the two the window could draw
    /// another search's rows under this one's selection.
    @Test("Both Mac search paths settle the selection as the rows arrive, by the search that was sent")
    func bothPathsSettle() throws {
        let mac = try Self.source(Self.macModel)
        let keyword = Self.squeezedCode(try Self.declaration("func performSearch(service: SearchService?) async {", in: mac))
        #expect(keyword.contains(Self.squeezed("""
            results = fetched
            settleSelection(for: ChecklistAnchor(query: query, parameters: params))
            """)))
        let meaning = Self.squeezedCode(try Self.declaration("private func performMeaningSearch() async {", in: mac))
        #expect(meaning.contains(Self.squeezed("""
            let sentAnchor = ChecklistAnchor(query: query, parameters: parameters)
            do {
                let outcome = try await backend.run(query: query, parameters: parameters)
                results = outcome.results
                settleSelection(for: sentAnchor)
            """)), "the anchor is taken before the run: the filters can change while it is under way")
        let code = mac.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
        #expect(code.filter { $0.contains("settleSelection(for:") && !$0.contains("func ") }.count == 2,
                "the two search paths, and no third place, settle the selection")
    }

    @Test("The toolbar has a titled Select toggle after Checklist, for the list reading and no error")
    func toolbarToggle() throws {
        let window = try Self.source(Self.window)
        let toolbar = try Self.declaration("private var searchToolbar: some ToolbarContent {", in: window)
        let checklist = try #require(toolbar.range(of: "searchVM.setChecklistMode(!searchVM.checklistMode)"))
        let select = try #require(toolbar.range(of: "ResultSelectionCopy.selectToggle"))
        let facets = try #require(toolbar.range(of: "showFacetPanel.toggle()"))
        #expect(checklist.upperBound < select.lowerBound && select.upperBound < facets.lowerBound,
                "Select is beside Checklist, before Facets, which stays trailing")
        #expect(Self.squeezedCode(toolbar).contains(Self.squeezed("""
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if searchVM.resultSelection.isSelecting {
                        searchVM.endSelecting()
                    } else {
                        searchVM.beginSelecting()
                    }
                } label: {
                    Label(ResultSelectionCopy.selectToggle, systemImage: "checkmark.circle")
                }
                .labelStyle(.titleAndIcon)
                .foregroundStyle(searchVM.resultSelection.isSelecting ? Color.accentColor : Color.secondary)
                .disabled(!searchVM.resultSelection.isSelecting
                          && (searchVM.displayedResults.isEmpty || activeReading != .list
                              || searchVM.searchError != nil))
            """)), """
            titled, since macOS draws a toolbar Label icon-only unless told; dimmed with no rows to \
            check; and never dimmed while on, or a selection marked reviewed to its last row could \
            not be left from the toolbar
            """)
        // Its neighbour Checklist carries the same two modifiers. The running toolbar gives
        // accessibility the Label's own title and this value: "Select", and "On" or "Off".
        #expect(Self.squeezedCode(toolbar).contains(Self.squeezed("""
            .accessibilityLabel(ResultSelectionCopy.selectResults)
            .accessibilityValue(searchVM.resultSelection.isSelecting
            """)))
    }

    @Test("The strip is above the checklist's, built from the view model, and its Undo removes entries by id")
    func stripIsMounted() throws {
        let window = try Self.source(Self.window)
        #expect(Self.squeezedCode(window).contains(Self.squeezed("""
            overCapAdvisory
            selectionStrip
            checklistHiddenBanner
            """)))
        let strip = Self.squeezedCode(try Self.declaration("private var selectionStrip: some View {", in: window))
        #expect(strip.contains(Self.squeezed("""
            if searchVM.resultSelection.isSelecting {
                ResultSelectionStrip(
                    count: searchVM.resultSelection.count,
                    pageRowCount: searchVM.pagedResults.count,
                    shownCount: searchVM.displayedResults.count,
                    canAdd: searchVM.canAddSelectionToCollection,
                    showsMarkReviewed: searchVM.checklistMode,
                    canMarkReviewed: searchVM.canMarkSelectionReviewed,
                    addRefusal: searchVM.selectionExceedsAddLimit
                        ? ResultSelectionCopy.overLimit(CollectionDocumentDiscovery.bulkDocumentLimit) : nil,
                    outcome: searchVM.bulkOutcome,
                    outcomeSerial: searchVM.bulkOutcomeSerial,
                    done: { searchVM.endSelecting() },
            """)))
        #expect(strip.contains(Self.squeezed("""
            addToCollection: { bulkRequest = selectionAddRequest },
            addTags: { bulkRequest = selectionTagRequest },
            markReviewed: { searchVM.markSelectionReviewed() },
            undo: {
                searchVM.undoBulkOutcome(removingEntries: { ids in
                    try CollectionDocumentDiscovery.removeEntries(withIds: ids, modelContext: modelContext)
                }, removingTagAssignments: { ids in
                    try UserTagAdmin.removeAssignmentsAndIndex(
                        withIds: ids, context: modelContext, pipeline: appState.indexingPipeline)
                })
            })
            """)))
        #expect(Self.squeezedCode(window).contains(Self.squeezed("""
            private var selectionTagRequest: BulkResultRequest? {
                BulkResultRequest(.addTags, results: searchVM.selectedResults,
                                  fromMeaningSearch: searchVM.resultsAreSemantic)
            }
            """)), "the tag request is made from the checked rows, as the collection's is (#1576 lane 5)")
        #expect(Self.squeezedCode(window).contains(Self.squeezed("""
            private var selectionAddRequest: BulkResultRequest? {
                BulkResultRequest(.addToCollection, results: searchVM.selectedResults,
                                  fromMeaningSearch: searchVM.resultsAreSemantic)
            }
            """)), "the request is made from the checked rows as the list shows them now")
        #expect(Self.squeezedCode(window).contains(Self.squeezed("""
            .bulkResultSheets($bulkRequest, indexingPipeline: appState.indexingPipeline,
                              onAdded: { outcome, collection in
                searchVM.recordCollectionAdd(
                    outcome, collectionName: CollectionEditorNaming.listName(savedName: collection.name))
            }, onTagged: { outcome, tagNames in
                searchVM.recordTagAssign(outcome, tagNames: tagNames)
            })
            """)))
    }

    /// The checkbox is beside the row. `SearchResultRow` is private and `InAppCitationNumberTests`
    /// reads it, and the click that opens a document must stay the row's own. In the running
    /// window a click on the checkbox checked it and opened nothing, and a click on the row's
    /// title opened the document and left the checkbox as it was.
    ///
    /// The checkbox's name is its hidden label. Read with the accessibility API from the running
    /// window, its `AXAttributedDescription` is the result's heading; with an `.accessibilityLabel`
    /// of the heading added it was the heading twice over, which VoiceOver would say twice.
    /// (System Events shows no name either way: it cannot read an attributed description.)
    @Test("A row's checkbox is beside the row, outside the tap that opens it, and is named once, by its hidden label")
    func checkboxIsBesideTheRow() throws {
        let window = try Self.source(Self.window)
        let list = Self.squeezedCode(try Self.declaration("private var resultsList: some View {", in: window))
        #expect(list.contains(Self.squeezed("""
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                if searchVM.resultSelection.isSelecting {
                    Toggle(isOn: Binding(
                        get: { searchVM.resultSelection.contains(result.id) },
                        set: { _ in searchVM.toggleSelection(of: result) })) {
                        Text(result.header)
                    }
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                    .help(ResultSelectionCopy.rowHint)
                }
                SearchResultRow(result: result, userTags: allUserTags)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedResultId = result.id
                        navigateToResult(result)
                    }
            }
            """)), "the tap that opens is on the row, inside the stack, so the checkbox is outside its reach")
        #expect(!list.contains(".accessibilityLabel(result.header)"),
                "the hidden label names the checkbox already: said again, the heading is read twice")
        let row = try Self.declaration("private struct SearchResultRow: View {", in: window)
        #expect(!row.contains("resultSelection") && !row.contains("Toggle("),
                "the row itself knows nothing of selection")
    }

    /// In the running window Space checked the highlighted row and, pressed again after ↓,
    /// cleared the next. The scan holds the handler to that shape, and to one toggle for each
    /// press: a held key repeats.
    @Test("Space is wired to toggle the highlighted row while selecting, once for each press, and is handed back otherwise")
    func spaceChecksTheHighlightedRow() throws {
        let list = Self.squeezedCode(try Self.declaration("private var resultsList: some View {",
                                                          in: try Self.source(Self.window)))
        #expect(list.contains(Self.squeezed("""
            .onKeyPress(.space, phases: .down) { _ in
                guard searchVM.resultSelection.isSelecting,
                      let id = selectedResultId,
                      let result = searchVM.pagedResults.first(where: { $0.id == id })
                else { return .ignored }
                searchVM.toggleSelection(of: result)
                return .handled
            }
            """)))
        #expect(list.contains(Self.squeezed(".onKeyPress(.return) {")), "Return still opens the highlighted row")
    }

    @Test("A checked row's menu adds the selection when others are checked too, and the row alone otherwise")
    func menuBranchesOnMembership() throws {
        let window = try Self.source(Self.window)
        let list = Self.squeezedCode(try Self.declaration("private var resultsList: some View {", in: window))
        #expect(list.contains(Self.squeezed("""
            if checkedTogether(with: result) {
                Button {
                    bulkRequest = selectionAddRequest
                } label: {
                    Label(ResultSelectionCopy.addSelectedToCollection(searchVM.resultSelection.count),
                          systemImage: "plus.circle")
                }
                .disabled(!searchVM.canAddSelectionToCollection)
                Button {
                    bulkRequest = selectionTagRequest
                } label: {
                    Label(ResultSelectionCopy.addTagsToSelected(searchVM.resultSelection.count),
                          systemImage: "tag")
                }
                .disabled(!searchVM.canAddSelectionToCollection)
            } else {
                Button {
                    bulkRequest = addToCollectionRequest(for: result)
                } label: {
                    Label(BulkResultCopy.addToCollection, systemImage: "plus.circle")
                }
                Button {
                    bulkRequest = addTagsRequest(for: result)
                } label: {
                    Label(BulkResultCopy.addTags, systemImage: "tag")
                }
            }
            """)), "both commands are the selection's on a checked row among others, and the row's own otherwise (lane 5 for the tags)")
        #expect(Self.squeezedCode(window).contains(Self.squeezed("""
            private func checkedTogether(with result: SearchResult) -> Bool {
                searchVM.resultSelection.contains(result.id) && searchVM.resultSelection.count > 1
            }
            """)))
    }

    @Test("A reading that is not the list ends selection")
    func readingChangeEndsSelection() throws {
        let window = try Self.source(Self.window)
        let binding = Self.squeezedCode(try Self.declaration(
            "private var readingSelection: Binding<ResultReading> {", in: window))
        #expect(binding.contains(Self.squeezed("""
            showCollocates = flags.collocates
            if selected != .list { searchVM.endSelecting() }
            """)))
    }

    @Test("The strip holds the commands as buttons, dims them by the values it is given, and posts an outcome once for each count")
    func stripView() throws {
        let views = try Self.source("FRUSExplorer/Search/ResultSelectionViews.swift")
        let strip = Self.squeezedCode(try Self.declaration("struct ResultSelectionStrip: View {", in: views))
        #expect(strip.contains(Self.squeezed("""
            Button(BulkResultCopy.addToCollection, action: addToCollection)
                .disabled(!canAdd)
            """)))
        #expect(strip.contains(Self.squeezed("""
            Button(BulkResultCopy.addTags, action: addTags)
                .disabled(!canAdd)
            """)), "Add Tags is beside Add to Collection and dimmed by the same limit (#1576 lane 5)")
        #expect(strip.contains(Self.squeezed("""
            if showsMarkReviewed {
                Button(ResultSelectionCopy.markReviewed, action: markReviewed)
                    .disabled(count == 0 || !canMarkReviewed)
            """)))
        #expect(strip.contains(Self.squeezed("Button(ResultSelectionCopy.done, action: done)")))
        #expect(strip.contains(Self.squeezed("""
            .task(id: outcomeSerial) {
                guard BulkOutcome.owesAnnouncement(serial: outcomeSerial, lastAnnounced: announcedSerial,
                                                   message: outcome?.message),
                      let message = outcome?.message else { return }
                do { try await Task.sleep(for: ResultSelectionBar.announcementDelay) } catch { return }
                announcedSerial = outcomeSerial
                AccessibilityNotification.Announcement(TransientToast.announcement(message)).post()
            }
            """)))
        #expect(strip.contains(Self.squeezed(".help(ResultSelectionCopy.undoHint(for: kind))")),
                "the checklist's strip under this one has an Undo of its own")
    }
}
