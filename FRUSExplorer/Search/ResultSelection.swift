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

// MARK: - ResultSelection

/// The search results a reader has picked, to act on several at once (#1576 lane 3).
///
/// ## What a selection is
///
/// A set of `SearchResult.id` keys drawn from **the results shown for the search on screen**: the
/// loaded results less whatever Checklist Mode hides. It is written on the shown set and not the
/// loaded one because Checklist Mode hides a row the moment its document is opened: on the loaded
/// set an opened row would stay picked and out of sight, and a command would act on a document
/// the reader has no way to see. So the owner of a selection prunes it whenever the shown set
/// shrinks (``prune(toShown:)``), and a row that comes back, by Undo or by turning Checklist Mode
/// off, comes back unpicked.
///
/// ## How long it lasts
///
/// For the search on screen. A page turn and a sort keep the picks. A re-run of the same search
/// (a filter or a facet changed) keeps the picks still shown. A new search, a Keywords/Meaning
/// flip, an emptied list and Done end it (``end()``).
///
/// ## What it is not
///
/// It holds keys, never rows: the rows are resolved from the list when a command is chosen
/// (``resolved(in:)``), in the order on screen, and frozen into the command's request. In memory,
/// for the session, like the checklist's marks.
///
/// Version history:
///   1.0 — #1576 lane 3: initial implementation
struct ResultSelection: Equatable, Sendable {

    /// Whether the list is in selection. On iPhone and iPad a tap on a row then picks it where it
    /// opened its document; on the Mac every row has a checkbox, and a click on the row still opens.
    private(set) var isSelecting = false

    /// The picked results' ids (`SearchResult.id`).
    private(set) var keys: Set<String> = []

    /// How many results are picked.
    var count: Int { keys.count }

    /// Whether a result is picked.
    ///
    /// - Parameter key: The result's id.
    func contains(_ key: String) -> Bool { keys.contains(key) }

    /// Enters selection. Choosing Select on a row's menu enters with that row picked; Select
    /// Results in the More menu enters with none.
    ///
    /// - Parameter key: The id of the row the reader chose Select on, or `nil`.
    mutating func begin(picking key: String? = nil) {
        isSelecting = true
        if let key { keys.insert(key) }
    }

    /// Leaves selection and forgets the picks.
    mutating func end() {
        isSelecting = false
        keys = []
    }

    /// Picks a result, or un-picks it. Outside selection it does nothing.
    ///
    /// - Parameter key: The result's id.
    mutating func toggle(_ key: String) {
        guard isSelecting else { return }
        if keys.remove(key) == nil { keys.insert(key) }
    }

    /// Adds results to the picks: This Page, and All Shown. Outside selection it does nothing.
    ///
    /// - Parameter newKeys: The results' ids.
    mutating func pick(_ newKeys: some Sequence<String>) {
        guard isSelecting else { return }
        keys.formUnion(newKeys)
    }

    /// Un-picks everything and stays in selection: None.
    mutating func clear() {
        keys = []
    }

    /// Drops every pick that is not among the results shown.
    ///
    /// - Parameter shown: The ids of the results the list shows now.
    /// - Returns: How many picks were dropped.
    @discardableResult
    mutating func prune(toShown shown: Set<String>) -> Int {
        let before = keys.count
        keys.formIntersection(shown)
        return before - keys.count
    }

    /// The picked results, in the order the list shows them.
    ///
    /// - Parameter shown: The results the list shows, in its order.
    /// - Returns: The rows a command acts on.
    func resolved(in shown: [SearchResult]) -> [SearchResult] {
        guard !keys.isEmpty else { return [] }
        return shown.filter { keys.contains($0.id) }
    }
}

// MARK: - BulkOutcome

/// What the last command on a selection did, kept above the results until the next command, the
/// next completed search or Done (#1576 lane 3).
///
/// The rows change without a sound, and a sheet that added thirty documents has closed by the
/// time the reader looks back at the list. So the outcome is a line that stays, with an Undo
/// where there is something to take back, and it is announced to VoiceOver when it is set.
///
/// Version history:
///   1.0 — #1576 lane 3: initial implementation
///   1.1 — #1576 lane 5: an Add Tags' outcome and its Undo
struct BulkOutcome: Equatable, Sendable {

    /// What Undo takes back.
    enum Undo: Equatable, Sendable {
        /// The collection entries an Add to Collection inserted, by id, and the collection's
        /// name for the line that follows. By id, because the entries are re-fetched: one that
        /// is gone by then was removed some other way and is already undone.
        case collectionEntries(ids: [UUID], collectionName: String)
        /// The last bulk Mark Reviewed (`ReviewedMarks.undoLastBulk`).
        case reviewedMarks
        /// The assignment rows an Add Tags inserted, by id, and the tags' names for the line
        /// that follows (#1576 lane 5). By id, for the reason the collection's entries are.
        case tagAssignments(ids: [UUID], tagNames: [String])
    }

    /// The line shown above the results.
    let message: String
    /// What Undo takes back, or `nil` when there is nothing to: nothing was changed, or the
    /// line reports an undo.
    let undo: Undo?

    /// Whether the outcome a host counted as `serial` is still to be announced: there is one,
    /// and it is newer than the last one spoken. The view that announces is taken off screen and
    /// put back, by a document opened over the list or by another tab, and the task that posts
    /// the announcement starts again each time; without this the same outcome is spoken again.
    ///
    /// - Parameters:
    ///   - serial: The host's count of outcomes.
    ///   - lastAnnounced: The count whose announcement was last posted.
    ///   - message: The outcome's words, or `nil` when no outcome is showing.
    /// - Returns: Whether to post the announcement.
    static func owesAnnouncement(serial: Int, lastAnnounced: Int, message: String?) -> Bool {
        message != nil && serial > lastAnnounced
    }
}

// MARK: - ResultSelectionSession

/// A selection with what follows it for as long as it lasts: the search it was made in, what its
/// last command did, and the picks a re-run of that search dropped (#1576 lane 4).
///
/// ## Why it is a value apart from the view models
///
/// The iPhone's and the Mac's search view models are twins kept by hand, and nothing runs the
/// Mac's. In lane 3 these rules were `SearchViewModel`'s own. They are here so that the two hold
/// one copy of them, and so that the tests which drive `SearchViewModel` run the rules the Mac's
/// window uses. A view model keeps what only it knows: which rows it shows, when one of its
/// searches completes, and how its checklist marks.
///
/// ## The order a host calls it in
///
/// When the host's results are replaced it calls ``resultsWereReplaced(nowEmpty:shown:)``, and
/// when the search that replaced them completes it calls ``settle(for:)``. The first counts the
/// picks the new list does not show; the second decides, by the search's anchor, whether they
/// were dropped by a re-run of the same search (which it says) or by another search (which ends
/// selection). When Checklist Mode hides a row the host calls ``prune(toShown:)``.
///
/// Version history:
///   1.0 — #1576 lane 4: the rules moved here from `SearchViewModel`, which lane 3 gave them to
///   1.1 — #1576 lane 4, review: a mark is recorded in selection only, as an add is
///   1.2 — #1576 lane 5: `recordTagging`, and Undo takes a bulk tag back
struct ResultSelectionSession: Equatable, Sendable {

    /// The picks, and whether the list is in selection.
    private(set) var selection = ResultSelection()

    /// What the last command on the selection did, shown above the results until the next
    /// command, the next completed search or Done.
    private(set) var outcome: BulkOutcome?

    /// Counts the outcomes set, so that a host can announce each one. Two commands in a row can
    /// leave the same words ("25 results marked reviewed" for one full page and then the next),
    /// and a change of value is then no signal that anything happened.
    private(set) var outcomeSerial = 0

    /// The search the picks were made in. A completed search that is the same search keeps the
    /// picks it still shows; another ends selection (``settle(for:)``).
    private var anchor: ChecklistAnchor?

    /// Picks that a replaced result list no longer held, counted until the search that replaced
    /// it completes and ``settle(for:)`` reports or discards them.
    private var droppedByRerun = 0

    /// Whether more results are picked than one Add to Collection takes (the owner's decision 5).
    /// Mark Reviewed has no limit.
    var exceedsAddLimit: Bool {
        selection.count > CollectionDocumentDiscovery.bulkDocumentLimit
    }

    /// Whether Add to Collection can run: something is picked, and no more than one add takes.
    var canAdd: Bool {
        selection.count > 0 && !exceedsAddLimit
    }

    /// Enters selection, with one row picked when the reader chose Select on it. Entering an
    /// existing selection again keeps its search, its outcome and its picks, and adds the row.
    ///
    /// A new selection starts with no line and nothing counted because none is kept outside one:
    /// ``end()`` forgets both, and nothing is recorded outside selection.
    ///
    /// - Parameters:
    ///   - key: The id of the row whose menu was used, or `nil`.
    ///   - anchor: The search the rows on screen came from.
    mutating func begin(picking key: String? = nil, anchor: ChecklistAnchor) {
        if !selection.isSelecting { self.anchor = anchor }
        selection.begin(picking: key)
    }

    /// Leaves selection: Done, another search, a change of engine, an emptied list, an error.
    mutating func end() {
        selection.end()
        anchor = nil
        droppedByRerun = 0
        outcome = nil
    }

    /// Picks a row, or un-picks it.
    mutating func toggle(_ key: String) {
        selection.toggle(key)
    }

    /// Adds rows to the picks: This Page, and All Shown.
    mutating func pick(_ keys: some Sequence<String>) {
        selection.pick(keys)
    }

    /// Un-picks everything and stays in selection.
    mutating func clear() {
        selection.clear()
    }

    /// Sets the outcome line and counts it.
    private mutating func setOutcome(_ outcome: BulkOutcome) {
        self.outcome = outcome
        outcomeSerial &+= 1
    }

    /// Withdraws a line that offers to undo a bulk mark, when that mark has been replaced, taken
    /// back or forgotten some other way: by the checklist strip's own Mark Page Reviewed or Undo,
    /// or by the checklist starting again, as it does when Checklist Mode is turned off and when
    /// another search is run.
    mutating func withdrawOutcomeOfferingToUndoMarks() {
        if outcome?.undo == .reviewedMarks { outcome = nil }
    }

    /// Records what a Mark Reviewed of the selection did. Outside selection nothing shows an
    /// outcome, and none is kept.
    ///
    /// - Parameter hidden: How many rows left the list.
    mutating func recordMark(hidden: Int) {
        guard selection.isSelecting else { return }
        setOutcome(BulkOutcome(message: ChecklistCopy.markedAnnouncement(hidden),
                               undo: hidden > 0 ? .reviewedMarks : nil))
    }

    /// Records what an Add to Collection did while selecting: the selection's, or one row's from
    /// its own menu, which is then the last command and takes the line. Outside selection nothing
    /// shows an outcome, and the picker's checkmark is the feedback.
    ///
    /// - Parameters:
    ///   - append: What `CollectionDocumentDiscovery.appendDocuments` answered.
    ///   - collectionName: The collection's name as its row shows it.
    mutating func recordAdd(_ append: CollectionDocumentAppend, collectionName: String) {
        guard selection.isSelecting else { return }
        setOutcome(BulkOutcome(
            message: ResultSelectionCopy.added(append.insertedCount, alreadyPresent: append.alreadyPresent,
                                               to: collectionName),
            undo: append.insertedEntryIds.isEmpty
                ? nil : .collectionEntries(ids: append.insertedEntryIds, collectionName: collectionName)))
    }

    /// Records what an Add Tags did while selecting: the selection's, or one row's from its own
    /// menu (#1576 lane 5). Outside selection nothing shows an outcome, and the tag on the row is
    /// the feedback.
    ///
    /// - Parameters:
    ///   - assign: What `UserTagAdmin.assign` answered.
    ///   - tagNames: The names of the tags given, as the picker showed them.
    mutating func recordTagging(_ assign: UserTagAssign, tagNames: [String]) {
        guard selection.isSelecting else { return }
        setOutcome(BulkOutcome(
            message: ResultSelectionCopy.tagged(assign.taggedDocuments.count,
                                                alreadyTagged: assign.alreadyTagged, tagNames: tagNames),
            undo: assign.insertedAssignmentIds.isEmpty
                ? nil : .tagAssignments(ids: assign.insertedAssignmentIds, tagNames: tagNames)))
    }

    /// Takes the last command back and says what that did.
    ///
    /// The marks are the host's to restore, and collection entries and tag assignments the
    /// store's, so the host passes all three in.
    ///
    /// - Parameters:
    ///   - removingEntries: Removes the collection entries with these ids and answers how many
    ///     it removed (`CollectionDocumentDiscovery.removeEntries`).
    ///   - removingTagAssignments: Removes the tag assignments with these ids and answers how
    ///     many documents lost one (`UserTagAdmin.removeAssignments`).
    ///   - restoringMarks: Takes the last bulk mark back and answers how many rows returned.
    mutating func undo(removingEntries: ([UUID]) throws -> Int,
                       removingTagAssignments: ([UUID]) throws -> Int,
                       restoringMarks: () -> Int) {
        guard let undo = outcome?.undo else { return }
        switch undo {
        case .tagAssignments(let ids, let tagNames):
            do {
                let documents = try removingTagAssignments(ids)
                setOutcome(BulkOutcome(message: ResultSelectionCopy.untagged(documents, tagNames: tagNames),
                                       undo: nil))
            } catch {
                // No second try, for the reason an add's Undo offers none.
                setOutcome(BulkOutcome(message: ResultSelectionCopy.undoFailed(error), undo: nil))
            }
        case .collectionEntries(let ids, let collectionName):
            do {
                let removed = try removingEntries(ids)
                setOutcome(BulkOutcome(message: ResultSelectionCopy.removed(removed, from: collectionName),
                                       undo: nil))
            } catch {
                // No second try is offered. A removal whose save failed has already taken the
                // entries out in memory, so another would find none and report nothing removed.
                setOutcome(BulkOutcome(message: ResultSelectionCopy.undoFailed(error), undo: nil))
            }
        case .reviewedMarks:
            let restored = restoringMarks()
            setOutcome(BulkOutcome(message: ChecklistCopy.undoneAnnouncement(restored), undo: nil))
        }
    }

    /// Follows a replaced result list. An emptied list ends selection; otherwise the picks the
    /// new list does not show are dropped and counted, for the completed search to settle.
    ///
    /// - Parameters:
    ///   - nowEmpty: Whether the new list holds no result at all.
    ///   - shown: The ids of the results the list shows now. Read only while selecting.
    mutating func resultsWereReplaced(nowEmpty: Bool, shown: @autoclosure () -> Set<String>) {
        guard selection.isSelecting else { return }
        guard !nowEmpty else { end(); return }
        droppedByRerun += selection.prune(toShown: shown())
    }

    /// Drops the picks the list no longer shows: a row Checklist Mode has just hidden, because
    /// its document was opened or it was marked reviewed.
    ///
    /// - Parameter shown: The ids of the results the list shows now. Read only with picks to drop.
    mutating func prune(toShown shown: @autoclosure () -> Set<String>) {
        guard selection.isSelecting, selection.count > 0 else { return }
        selection.prune(toShown: shown())
    }

    /// Settles the selection against a search that has just completed. The same search keeps the
    /// picks it still shows and says how many it does not; another search ends selection.
    ///
    /// - Parameter anchor: The anchor of the search that ran.
    mutating func settle(for anchor: ChecklistAnchor) {
        // Outside selection there is no anchor, and this ends a selection that is not on.
        guard self.anchor?.isSameSearch(as: anchor) == true else { end(); return }
        // A completed search ends the last command's line and its Undo, as the next command
        // does. What takes its place, when the re-run dropped picks, is how many.
        if droppedByRerun > 0 {
            setOutcome(BulkOutcome(message: ResultSelectionCopy.dropped(droppedByRerun), undo: nil))
        } else {
            outcome = nil
        }
        droppedByRerun = 0
    }
}

// MARK: - A row with the tags the store has now

extension SearchResult {

    /// This result with another set of the reader's tags and nothing else changed (#1576 lane 5).
    ///
    /// A row's tags are read from the index when its search runs. After an Add Tags, or its
    /// Undo, the store knows the document's tags and the row does not, and a view model swaps
    /// the row for this one so that the chip shows without another search.
    ///
    /// The ids are written in the order `DocumentTagAssignment.tagColumnValue` writes the index's
    /// column in, which is the order a later search lists them in once the rewrite has run.
    /// `SearchResult` is the kit's and every field is a `let`; this is the one place the app
    /// copies one, and `SearchResultTagRefreshTests` fails if a field is added and not carried.
    ///
    /// - Parameter tagIds: Every tag the document carries now.
    /// - Returns: The same result, carrying those tags.
    func replacingUserTagIds(_ tagIds: Set<UUID>) -> SearchResult {
        SearchResult(
            documentId: documentId,
            volumeId: volumeId,
            documentNumber: documentNumber,
            header: header,
            dateline: dateline,
            dateISO: dateISO,
            sourceNote: sourceNote,
            snippet: snippet,
            bm25Score: bm25Score,
            semanticScore: semanticScore,
            subjectTagIds: subjectTagIds,
            userTagIds: tagIds.map(\.uuidString).sorted(),
            isEditorialNote: isEditorialNote,
            isFrontMatter: isFrontMatter)
    }
}

// MARK: - ResultSelectionCopy

/// The words of selection: the bar, its two menus, the commands and their outcomes, apart from
/// the views so that a test can read them off the main actor (#1576 lane 3).
///
/// Version history:
///   1.0 — #1576 lane 3: initial implementation
///   1.1 — #1683: `overLimit` is said beside the two commands it dims, and says only what to do
enum ResultSelectionCopy {

    /// The More menu's item that enters selection.
    static var selectResults: String {
        String(localized: "search.selection.enter", defaultValue: "Select Results")
    }

    /// A row menu's item that enters selection with that row picked.
    static var selectRow: String {
        String(localized: "search.selection.enter.row", defaultValue: "Select")
    }

    /// The Mac toolbar's toggle that enters and leaves selection, beside Checklist.
    static var selectToggle: String {
        String(localized: "search.selection.toggle", defaultValue: "Select")
    }

    /// The toggle's help while selection is off.
    static var selectToggleOnHelp: String {
        String(localized: "search.selection.toggle.on.help",
               defaultValue: "Select results, to add several to a collection or mark them reviewed at once")
    }

    /// The toggle's help while selection is on.
    static var selectToggleOffHelp: String {
        String(localized: "search.selection.toggle.off.help",
               defaultValue: "Leave selection and clear the checkboxes")
    }

    /// "Add 12 Selected to Collection…": a checked row's menu item on the Mac, when more than one
    /// row is checked. One form: it is offered for two or more.
    ///
    /// - Parameters:
    ///   - count: Results checked.
    ///   - locale: The locale that groups the count; the user's own unless a test passes one.
    static func addSelectedToCollection(_ count: Int, locale: Locale = .autoupdatingCurrent) -> String {
        let form = String(localized: "search.selection.row.addSelected %@",
                          defaultValue: "Add %@ Selected to Collection…")
        return CountCopy.phrase(count, one: form, many: form, locale: locale)
    }

    /// "Add Tags to 12 Selected…": a checked row's menu item on the Mac, when more than one row
    /// is checked (#1576 lane 5). One form: it is offered for two or more.
    ///
    /// - Parameters:
    ///   - count: Results checked.
    ///   - locale: The locale that groups the count; the user's own unless a test passes one.
    static func addTagsToSelected(_ count: Int, locale: Locale = .autoupdatingCurrent) -> String {
        let form = String(localized: "search.selection.row.tagSelected %@",
                          defaultValue: "Add Tags to %@ Selected…")
        return CountCopy.phrase(count, one: form, many: form, locale: locale)
    }

    /// The selection bar's button that leaves selection.
    static var done: String {
        String(localized: "search.selection.done", defaultValue: "Done")
    }

    /// "37 selected": the bar's count.
    ///
    /// - Parameters:
    ///   - count: Results picked.
    ///   - locale: The locale that groups the count; the user's own unless a test passes one.
    static func selected(_ count: Int, locale: Locale = .autoupdatingCurrent) -> String {
        // One form: "selected" does not change with the number.
        let form = String(localized: "search.selection.count %@", defaultValue: "%@ selected")
        return CountCopy.phrase(count, one: form, many: form, locale: locale)
    }

    /// The Select menu's label.
    static var selectMenu: String {
        String(localized: "search.selection.menu", defaultValue: "Select")
    }

    /// The Select menu's item that picks the page on screen.
    static var thisPage: String {
        String(localized: "search.selection.menu.page", defaultValue: "This Page")
    }

    /// "All 975 Shown": the Select menu's item that picks every result the list shows.
    ///
    /// - Parameters:
    ///   - count: Results shown: the loaded results less those Checklist Mode hides.
    ///   - locale: The locale that groups the count; the user's own unless a test passes one.
    static func allShown(_ count: Int, locale: Locale = .autoupdatingCurrent) -> String {
        let form = String(localized: "search.selection.menu.allShown %@", defaultValue: "All %@ Shown")
        return CountCopy.phrase(count, one: form, many: form, locale: locale)
    }

    /// The Select menu's item that un-picks everything.
    static var none: String {
        String(localized: "search.selection.menu.none", defaultValue: "None")
    }

    /// The name of the menu that holds the commands on a selection. The menu is drawn as a
    /// glyph, so this is what VoiceOver and the Large Content Viewer say. Its first item, the one
    /// that opens the collection picker, is a result row's own (`BulkResultCopy.addToCollection`).
    static var actions: String {
        String(localized: "search.selection.actions", defaultValue: "Actions")
    }

    /// The command that hides the picked results as reviewed, in Checklist Mode.
    static var markReviewed: String {
        String(localized: "search.selection.markReviewed", defaultValue: "Mark Reviewed")
    }

    /// The outcome line's button.
    static var undo: String {
        String(localized: "search.selection.undo", defaultValue: "Undo")
    }

    /// What the Undo beside an outcome takes back, for VoiceOver: the checklist's strip has an
    /// Undo of its own in the same rows, and after an add the two take back different things.
    ///
    /// - Parameter undo: What the outcome's Undo takes back.
    static func undoHint(for undo: BulkOutcome.Undo) -> String {
        switch undo {
        case .collectionEntries:
            String(localized: "search.selection.undo.hint.add",
                   defaultValue: "Takes the documents this command added back out of the collection")
        case .reviewedMarks:
            String(localized: "search.selection.undo.hint.mark",
                   defaultValue: "Brings back the results this command hid")
        case .tagAssignments:
            String(localized: "search.selection.undo.hint.tag",
                   defaultValue: "Takes the tags this command added back off the documents")
        }
    }

    /// A row's VoiceOver hint while the list is in selection. It says what activating the row
    /// does and names no gesture: the row is compiled for the Mac too, where it is not a tap.
    static var rowHint: String {
        String(localized: "search.selection.row.hint", defaultValue: "Selects or deselects this result")
    }

    /// The row menu's item that opens the document while the row's tap is picking.
    static var open: String {
        String(localized: "search.selection.row.open", defaultValue: "Open")
    }

    /// Why Add to Collection and Add Tags are dimmed: more results are picked than one of them
    /// takes. Shown beside each of the two, under its name (decision 69, #1683): in the Actions menu on
    /// iPhone and iPad and a checked row's menu on the Mac, and under the Mac strip's two buttons. It
    /// was a line above the results, away from the commands it explained, and said what they were for;
    /// re-keyed when it lost those words. Re-keyed in #1576 lane 5 too, when it came to speak for two
    /// commands.
    ///
    /// - Parameters:
    ///   - limit: The most documents one command takes (`CollectionDocumentDiscovery.bulkDocumentLimit`).
    ///   - locale: The locale that groups the count; the user's own unless a test passes one.
    static func overLimit(_ limit: Int, locale: Locale = .autoupdatingCurrent) -> String {
        String(format: String(localized: "search.selection.overLimit.v3 %@",
                              defaultValue: "Select %@ or fewer"),
               CountCopy.documents(limit, locale: locale))
    }

    /// What an Add Tags did: "Added “Chile” to 31 documents. 6 already had it." With more than
    /// one tag the tags are counted and not named: "Added 3 tags to 31 documents."
    ///
    /// - Parameters:
    ///   - documents: Documents that gained at least one tag.
    ///   - alreadyTagged: Documents that carried every tag asked for already.
    ///   - tagNames: The names of the tags given.
    ///   - locale: The locale that groups the counts; the user's own unless a test passes one.
    static func tagged(_ documents: Int, alreadyTagged: Int, tagNames: [String],
                       locale: Locale = .autoupdatingCurrent) -> String {
        let single = tagNames.count == 1 ? tagNames[0] : nil
        guard documents > 0 else {
            if let single {
                return CountCopy.phrase(
                    alreadyTagged,
                    one: String(localized: "search.selection.outcome.noneTagged.one %@ %@",
                                defaultValue: "Nothing added: %1$@ document already had “%2$@”."),
                    many: String(localized: "search.selection.outcome.noneTagged.many %@ %@",
                                 defaultValue: "Nothing added: %1$@ documents already had “%2$@”."),
                    then: [single], locale: locale)
            }
            return CountCopy.phrase(
                alreadyTagged,
                one: String(localized: "search.selection.outcome.noneTagged.tags.one %@",
                            defaultValue: "Nothing added: %@ document already had those tags."),
                many: String(localized: "search.selection.outcome.noneTagged.tags.many %@",
                             defaultValue: "Nothing added: %@ documents already had those tags."),
                locale: locale)
        }
        let added: String
        if let single {
            added = String(format: String(localized: "search.selection.outcome.tagged %@ %@",
                                          defaultValue: "Added “%1$@” to %2$@."),
                           single, CountCopy.documents(documents, locale: locale))
        } else {
            added = String(format: String(localized: "search.selection.outcome.tagged.tags %@ %@",
                                          defaultValue: "Added %1$@ tags to %2$@."),
                           tagNames.count.formatted(.number.locale(locale)),
                           CountCopy.documents(documents, locale: locale))
        }
        guard alreadyTagged > 0 else { return added }
        // One form for one and for many: "6 already had it" and "1 already had it".
        let already = single != nil
            ? String(localized: "search.selection.outcome.alreadyTagged %@", defaultValue: "%@ already had it.")
            : String(localized: "search.selection.outcome.alreadyTagged.tags %@",
                     defaultValue: "%@ already had them.")
        return added + " " + CountCopy.phrase(alreadyTagged, one: already, many: already, locale: locale)
    }

    /// What undoing an Add Tags did: "Removed “Chile” from 31 documents."
    ///
    /// - Parameters:
    ///   - documents: Documents a tag was taken back off. Fewer than were tagged when some of
    ///     the tags were removed another way.
    ///   - tagNames: The names of the tags the command gave.
    ///   - locale: The locale that groups the counts; the user's own unless a test passes one.
    static func untagged(_ documents: Int, tagNames: [String],
                         locale: Locale = .autoupdatingCurrent) -> String {
        if tagNames.count == 1 {
            return String(format: String(localized: "search.selection.outcome.untagged %@ %@",
                                         defaultValue: "Removed “%1$@” from %2$@."),
                          tagNames[0], CountCopy.documents(documents, locale: locale))
        }
        return String(format: String(localized: "search.selection.outcome.untagged.tags %@ %@",
                                     defaultValue: "Removed %1$@ tags from %2$@."),
                      tagNames.count.formatted(.number.locale(locale)),
                      CountCopy.documents(documents, locale: locale))
    }

    /// What an Add to Collection did: "Added 31 documents to “Chile”. 6 were already in it."
    ///
    /// - Parameters:
    ///   - inserted: Documents added.
    ///   - alreadyPresent: Documents the collection held already.
    ///   - collectionName: The collection's name as its row shows it.
    ///   - locale: The locale that groups the counts; the user's own unless a test passes one.
    static func added(_ inserted: Int, alreadyPresent: Int, to collectionName: String,
                      locale: Locale = .autoupdatingCurrent) -> String {
        guard inserted > 0 else {
            return CountCopy.phrase(
                alreadyPresent,
                one: String(localized: "search.selection.outcome.noneAdded.one %@ %@",
                            defaultValue: "Nothing added: %1$@ was already in “%2$@”."),
                many: String(localized: "search.selection.outcome.noneAdded.many %@ %@",
                             defaultValue: "Nothing added: %1$@ were already in “%2$@”."),
                then: [collectionName], locale: locale)
        }
        let added = String(format: String(localized: "search.selection.outcome.added %@ %@",
                                          defaultValue: "Added %1$@ to “%2$@”."),
                           CountCopy.documents(inserted, locale: locale), collectionName)
        guard alreadyPresent > 0 else { return added }
        return added + " " + CountCopy.phrase(
            alreadyPresent,
            one: String(localized: "search.selection.outcome.already.one %@",
                        defaultValue: "%@ was already in it."),
            many: String(localized: "search.selection.outcome.already.many %@",
                         defaultValue: "%@ were already in it."),
            locale: locale)
    }

    /// What undoing an Add to Collection did: "Removed 31 documents from “Chile”."
    ///
    /// - Parameters:
    ///   - removed: Entries removed. Fewer than were added when some were removed another way.
    ///   - collectionName: The collection's name.
    ///   - locale: The locale that groups the count; the user's own unless a test passes one.
    static func removed(_ removed: Int, from collectionName: String,
                        locale: Locale = .autoupdatingCurrent) -> String {
        String(format: String(localized: "search.selection.outcome.removed %@ %@",
                              defaultValue: "Removed %1$@ from “%2$@”."),
               CountCopy.documents(removed, locale: locale), collectionName)
    }

    /// What a re-run of the same search dropped: "3 selected results are not in this list now."
    ///
    /// - Parameters:
    ///   - count: Picks the re-run's results did not hold.
    ///   - locale: The locale that groups the count; the user's own unless a test passes one.
    static func dropped(_ count: Int, locale: Locale = .autoupdatingCurrent) -> String {
        CountCopy.phrase(
            count,
            one: String(localized: "search.selection.outcome.dropped.one %@",
                        defaultValue: "%@ selected result is not in this list now."),
            many: String(localized: "search.selection.outcome.dropped.many %@",
                         defaultValue: "%@ selected results are not in this list now."),
            locale: locale)
    }

    /// What an Undo that threw says in the outcome line. It does not say that nothing changed:
    /// a removal whose save failed has taken the entries out of the collection in memory, and
    /// they go for good with the next save that succeeds.
    ///
    /// - Parameter error: What the removal threw.
    static func undoFailed(_ error: any Error) -> String {
        String(format: String(localized: "search.selection.outcome.undoFailed %@",
                              defaultValue: "Undo did not finish: %@"),
               error.localizedDescription)
    }
}
