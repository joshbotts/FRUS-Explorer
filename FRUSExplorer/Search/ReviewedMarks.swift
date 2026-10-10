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

// MARK: - ReviewedMarks

/// The results a reader has marked reviewed in a Checklist Mode session: every mark, and the last
/// bulk mark apart, so that it can be undone (#1576 lane 1).
///
/// ## Why the last batch is kept apart
///
/// A mark made on one row is a deliberate act with one row's consequence. **Mark Page Reviewed**
/// hides a page at a stroke, and a stroke made on the wrong page had no remedy: nothing un-marks a
/// row, so the only way back was to turn Checklist Mode off and lose every mark. So the keys a
/// bulk mark newly hid are remembered, and Undo takes exactly those back. It takes back no hand
/// mark, and no earlier bulk mark: one level, the last.
///
/// ## What it is not
///
/// In memory, for the session, as checklist state has always been. Nothing here is stored, and a
/// document the reader *opened* is hidden by another route (`readSinceEnabledKeys`), which this
/// type knows nothing of.
///
/// Both search view models hold one, so iPhone, iPad and Mac cannot differ on what a bulk mark
/// hides or what Undo restores. Keys are `SearchViewModel.reviewedKey(volumeId:documentId:)`'s.
///
/// Version history:
///   1.0 — #1576 lane 1: initial implementation
struct ReviewedMarks: Equatable, Sendable {

    /// Every key marked reviewed, by hand or in bulk.
    private(set) var keys: Set<String> = []

    /// The keys the last bulk mark newly hid, which Undo restores. Empty when there is nothing to
    /// undo: before any bulk mark, after an Undo, and after ``reset()``.
    private(set) var lastBulkBatch: Set<String> = []

    /// Whether a bulk mark can be undone.
    var canUndoBulk: Bool { !lastBulkBatch.isEmpty }

    /// How many of the loaded results Undo would bring back to the list: those the last bulk mark
    /// hides and nothing else does.
    ///
    /// The batch is not that number. It outlives a re-run of its search, and the re-run may load
    /// fewer of the page's results than were marked, or none; and a result of the batch that was
    /// opened since is hidden on that account as well. Counting the batch would promise rows that
    /// do not return, and leave Undo live where pressing it changes nothing on screen.
    ///
    /// - Parameters:
    ///   - loadedKeys: The reviewed keys of the results the search loaded.
    ///   - otherwiseHidden: Keys hidden for another reason: documents opened since the mode came on.
    /// - Returns: The rows an Undo would restore; zero when there is no bulk mark to undo.
    func undoableCount(among loadedKeys: some Sequence<String>, otherwiseHidden: Set<String>) -> Int {
        guard canUndoBulk else { return 0 }
        return loadedKeys.reduce(into: 0) { count, key in
            if lastBulkBatch.contains(key), !otherwiseHidden.contains(key) { count += 1 }
        }
    }

    /// Marks one result by hand.
    ///
    /// A hand mark is never undone by Undo, so a key of the last bulk batch that is then marked by
    /// hand leaves the batch. (A row the batch hid cannot be reached to mark; the rule is stated so
    /// the type is whole without the screen.)
    ///
    /// - Parameter key: The result's reviewed key.
    mutating func mark(_ key: String) {
        keys.insert(key)
        lastBulkBatch.remove(key)
    }

    /// Marks several results at once and remembers the ones it newly hid.
    ///
    /// A key already marked is left as it was and is not part of the batch, so Undo cannot take
    /// back a mark the reader made by hand. A bulk mark that hides nothing new changes nothing,
    /// and the batch before it stays the one Undo restores.
    ///
    /// - Parameter newKeys: The results' reviewed keys.
    /// - Returns: The keys newly marked.
    @discardableResult
    mutating func markBulk(_ newKeys: some Sequence<String>) -> Set<String> {
        let fresh = Set(newKeys).subtracting(keys)
        guard !fresh.isEmpty else { return [] }
        keys.formUnion(fresh)
        lastBulkBatch = fresh
        return fresh
    }

    /// Takes back the last bulk mark, and only that.
    ///
    /// - Returns: The keys no longer marked; empty when there was no bulk mark to undo.
    @discardableResult
    mutating func undoLastBulk() -> Set<String> {
        let batch = lastBulkBatch
        keys.subtract(batch)
        lastBulkBatch = []
        return batch
    }

    /// Clears every mark and the batch: Checklist Mode turned on or off, or a new search.
    mutating func reset() {
        keys = []
        lastBulkBatch = []
    }
}

// MARK: - ChecklistAnchor

/// The search a checklist's marks belong to (#1576 lane 1).
///
/// Reviewed marks are keyed by document, and a document recurs across searches, so a mark must not
/// outlive the search it was made in: a result hidden under one question would be silently hidden
/// under the next. Nor may it die too soon: a date range changed, a facet narrowed or a tag chip
/// tapped re-runs the *same* search, and wiping two hundred marks for that is the complaint this
/// type answers on iPhone and iPad, where every completed search used to wipe them.
///
/// ## What "the same search" is
///
/// - **With words:** the same words. The typed text is compared by the history writer's own rule
///   (`SearchHistoryWriter.isSameQuery`), so the same query in other quotation marks keeps its
///   marks as it keeps its history row (#1298), and the restored phrase, prefix and excluded terms
///   are compared as they stand. Filters may change freely. This was the Mac's rule already.
/// - **With no words** (a person's Find all mentions, a topic, a subject area): the same person
///   and subject. The typed text of every such browse is empty, so by the Mac's rule as it stood
///   two browses were one search, and marks made in one person's mentions hid documents in the
///   next person's. What the browse was of when the checklist was anchored must still be what it
///   is of: each of the person, the topic and the subject area it then named must be unchanged.
///   One it did not name may be added, which is a narrowing of the same browse, as a date range is.
///
/// Both search view models compare through this type where the Mac compared a string.
///
/// Version history:
///   1.0 — #1576 lane 1: initial implementation
struct ChecklistAnchor: Equatable, Sendable {

    /// The submitted query text, trimmed, in the spelling that anchored it.
    let query: String

    /// The restored phrase, prefix and excluded terms, which are words the search matched on and
    /// which the typed text does not hold.
    let structuredTerms: [String]

    /// What the search browsed, when it ran with no words at all; `nil` for a search with words.
    let browse: BrowseSubject?

    /// The person and subject a search with no words browses.
    struct BrowseSubject: Equatable, Sendable {
        /// The person's renumber-proof handle (`PersonRollupAnchor.signatureKey`), where captured.
        let personAnchor: String?
        /// The person's rollup slot, which a rollup rebuild renumbers.
        let personRollupId: Int?
        /// A single volume's person reference.
        let personRef: String?
        /// The topic (`SearchParameters.subjectRef`).
        let subjectRef: String?
        /// The subject area: its durable key, or its position where no key was recorded.
        let subjectBucket: String?

        /// Whether a person is named at all.
        var namesAPerson: Bool {
            personAnchor != nil || personRollupId != nil || personRef != nil
        }

        /// Whether `other` names the person this names, by the most durable handle the two share.
        ///
        /// A person filter gains its anchor after the fact (`refreshPersonRollupBinding`), and a
        /// rollup rebuild renumbers the slot, so the two sides are compared on what both carry:
        /// the anchor where both have one, else the slot, else the volume's reference.
        func namesTheSamePerson(as other: BrowseSubject) -> Bool {
            if let mine = personAnchor, let theirs = other.personAnchor { return mine == theirs }
            if let mine = personRollupId, let theirs = other.personRollupId { return mine == theirs }
            if let mine = personRef, let theirs = other.personRef { return mine == theirs }
            return false
        }

        /// Whether everything this browse was of is still what `next` is of.
        ///
        /// - Parameter next: The subject of the run that has just completed.
        /// - Returns: `true` when the person, topic and subject area named here are unchanged in
        ///   `next`. One named there and not here is a narrowing, and does not count against it.
        func isStillBrowsed(in next: BrowseSubject) -> Bool {
            if namesAPerson, !namesTheSamePerson(as: next) { return false }
            if let subjectRef, subjectRef != next.subjectRef { return false }
            if let subjectBucket, subjectBucket != next.subjectBucket { return false }
            return true
        }
    }

    /// The anchor for a search.
    ///
    /// - Parameters:
    ///   - query: The submitted query text. It is the authority on what was typed: on the Mac the
    ///     stored parameters do not carry it.
    ///   - parameters: The parameters the search ran with.
    init(query: String, parameters: SearchParameters) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        self.query = trimmed
        var ran = parameters
        ran.keywords = trimmed.isEmpty ? nil : trimmed
        structuredTerms = [ran.phrase ?? "", ran.prefixWildcard ?? ""] + ran.excludedTerms
        guard ran.runsAsFilterOnly else {
            browse = nil
            return
        }
        browse = BrowseSubject(
            personAnchor: ran.personRollupId != nil ? ran.personAnchor?.signatureKey : nil,
            personRollupId: ran.personRollupId,
            personRef: (ran.personRef ?? "").isEmpty ? nil : ran.personRef,
            subjectRef: ran.subjectRef,
            subjectBucket: ran.subjectBucketKey ?? ran.subjectBucket.map(String.init))
    }

    /// Whether a run is the search this anchor was made for, so that its marks stand.
    ///
    /// - Parameter next: The anchor of the run that has just completed.
    /// - Returns: `true` when the marks made under this anchor still belong to `next`.
    func isSameSearch(as next: ChecklistAnchor) -> Bool {
        guard SearchHistoryWriter.isSameQuery(query, next.query),
              structuredTerms == next.structuredTerms else { return false }
        switch (browse, next.browse) {
        case (nil, nil):
            // The same words. Filters are not part of what a search with words is.
            return true
        case let (mine?, theirs?):
            return mine.isStillBrowsed(in: theirs)
        default:
            // The same words, and only one of the two browses: with no words at all, a person or
            // subject was given to a search that had none (the anchor of a checklist turned on
            // before anything was searched), or taken from one that had.
            return false
        }
    }
}
