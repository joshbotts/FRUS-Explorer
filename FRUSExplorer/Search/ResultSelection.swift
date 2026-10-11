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

    /// Whether the list is in selection: a tap on a row picks it where it opened its document.
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
struct BulkOutcome: Equatable, Sendable {

    /// What Undo takes back.
    enum Undo: Equatable, Sendable {
        /// The collection entries an Add to Collection inserted, by id, and the collection's
        /// name for the line that follows. By id, because the entries are re-fetched: one that
        /// is gone by then was removed some other way and is already undone.
        case collectionEntries(ids: [UUID], collectionName: String)
        /// The last bulk Mark Reviewed (`ReviewedMarks.undoLastBulk`).
        case reviewedMarks
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

// MARK: - ResultSelectionCopy

/// The words of selection: the bar, its two menus, the commands and their outcomes, apart from
/// the views so that a test can read them off the main actor (#1576 lane 3).
///
/// Version history:
///   1.0 — #1576 lane 3: initial implementation
enum ResultSelectionCopy {

    /// The More menu's item that enters selection.
    static var selectResults: String {
        String(localized: "search.selection.enter", defaultValue: "Select Results")
    }

    /// A row menu's item that enters selection with that row picked.
    static var selectRow: String {
        String(localized: "search.selection.enter.row", defaultValue: "Select")
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

    /// Why Add to Collection is dimmed: more results are picked than one add takes.
    ///
    /// - Parameters:
    ///   - limit: The most documents one add takes (`CollectionDocumentDiscovery.bulkDocumentLimit`).
    ///   - locale: The locale that groups the count; the user's own unless a test passes one.
    static func overLimit(_ limit: Int, locale: Locale = .autoupdatingCurrent) -> String {
        String(format: String(localized: "search.selection.overLimit %@",
                              defaultValue: "Select %@ or fewer to add them to a collection."),
               CountCopy.documents(limit, locale: locale))
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
