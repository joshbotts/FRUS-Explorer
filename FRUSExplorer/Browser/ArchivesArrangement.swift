// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ArchivesArrangement

/// How the Archives axis's two counting lenses are grouped and ordered: Collections by repository or
/// record group, Classes by filing era, and both by document count or by name in either direction.
///
/// Pure and nonisolated, so the rules are driven by tests instead of being read off a view — and
/// three of them are traps that produce a plausible list rather than an error:
///
/// - **A class number is not a string of numbers.** Decimal file numbers are decimal FRACTIONS
///   after the point, so `711.11` files before `711.2`; subject-numeric designators are integers,
///   so `POL 3` files before `POL 24`. No single comparison gets both right. See
///   ``classKeyPrecedes(_:_:)``.
/// - **A record group is a number.** Compared as text, `RG 330` files before `RG 40`.
/// - **The bucket a grouping cannot place stays last in both directions.** Reversing the order
///   must not float 2,381 collections with no record group to the top of the list.
///
/// ## Every host gets the same controls
/// ``CollectionBrowserView`` serves three hosts — the Browse Archives axis, and Source Explorer on
/// both platforms — and draws these controls itself, so the three cannot drift apart. Each host
/// stores its own choices (``CollectionListHost``): grouping Browse by record group is not a request
/// to regroup Source Explorer.
///
/// Version history:
///   1.0 — 2026-09-10: sorting for both counting lenses, and record-group grouping for Collections
///   1.1 — 2026-09-10: an Ungrouped option, collapsible sections, and the same controls in Source
///          Explorer — whose volume-count order, kept apart in 1.0, is retired with its function
enum ArchivesArrangement {

    // MARK: - Sort

    /// What a lens is ordered by.
    enum SortKey: String, CaseIterable, Identifiable, Sendable {
        /// Documents whose printed source note names the collection or class.
        case documents
        /// A collection's canonical name, or a class number in filing order.
        case name

        var id: String { rawValue }

        /// The direction a reader expects on first choosing this key: the most documents first,
        /// and names from the start of the alphabet — or of the file.
        var naturallyAscending: Bool { self == .name }

        /// The menu label on the Collections lens.
        var collectionLabel: String {
            switch self {
            case .documents:
                return String(localized: "browser.archives.sort.documents",
                              defaultValue: "Document Count")
            case .name:
                return String(localized: "browser.archives.sort.name", defaultValue: "Name")
            }
        }

        /// The menu label on the Classes lens.
        var classLabel: String {
            switch self {
            case .documents:
                return String(localized: "browser.archives.sort.documents",
                              defaultValue: "Document Count")
            case .name:
                return String(localized: "browser.archives.sort.classNumber",
                              defaultValue: "Class Number")
            }
        }
    }

    /// A sort key and a direction.
    struct Sort: Equatable, Hashable, Sendable {
        /// What the list is ordered by.
        var key: SortKey
        /// Whether the smallest count or the earliest name comes first.
        var ascending: Bool

        /// The most documents first — the order both lenses shipped in.
        static let standard = Sort(key: .documents, ascending: false)

        /// This sort with a different key, in that key's natural direction.
        ///
        /// Choosing **Name** should read A to Z, not Z to A because the count happened to be
        /// descending before. Re-choosing the key already in force changes nothing, so a menu that
        /// re-sends its current selection cannot flip the direction behind the reader's back.
        ///
        /// - Parameter key: The newly chosen key.
        /// - Returns: The new sort.
        func selecting(_ key: SortKey) -> Sort {
            guard key != self.key else { return self }
            return Sort(key: key, ascending: key.naturallyAscending)
        }

        /// The direction's menu label.
        static func directionLabel(ascending: Bool) -> String {
            ascending
                ? String(localized: "browser.archives.sort.ascending", defaultValue: "Ascending")
                : String(localized: "browser.archives.sort.descending", defaultValue: "Descending")
        }
    }

    /// The sort button's text — `Document Count, Descending`.
    static func sortSummary(_ sort: Sort, label: (SortKey) -> String) -> String {
        String(format: String(localized: "browser.archives.sort.summary %@ %@",
                              defaultValue: "%1$@, %2$@"),
               label(sort.key), Sort.directionLabel(ascending: sort.ascending))
    }

    /// Every text the sort button can show.
    ///
    /// The button reserves the widest of these, so choosing a sort never changes its width. That is
    /// the whole fix for a reflow the review confirmed: "Name, Ascending" growing into "Document
    /// Count, Descending" pushed the row into another layout, rebuilt the menu the reader was using,
    /// moved the list and dropped VoiceOver and keyboard focus. It only works if this set really
    /// holds every label, which a test checks.
    static func sortSummaries(label: (SortKey) -> String) -> [String] {
        SortKey.allCases.flatMap { key in
            [true, false].map { sortSummary(Sort(key: key, ascending: $0), label: label) }
        }
    }

    // MARK: - Classes

    /// Whether one central-file class key files before another.
    ///
    /// **The two filing systems need two comparisons, and the obvious single one misfiles the
    /// larger.** A decimal file number is a decimal FRACTION after its point — `711.2` files after
    /// `711.11`, because `.2` is more than `.11` — so decimal keys compare character by
    /// character. A numeric-aware comparison, the kind Finder uses, reads `11`
    /// as eleven and files `711.2` first; the test beside this pins that the trap is real rather
    /// than asserted. Subject-numeric designators are the opposite case: `POL 24` and `POL 3` are
    /// integers, and character order would file `POL 24` first, and `POL 23-10` before `POL 23-7`.
    ///
    /// The system is told apart by `CollectionKeying.isSubjectNumericClass` — the same test the
    /// Classes lens admits keys to an era by — so the comparison can never disagree with the
    /// section a key sits in. An era holds one system only; across two, decimal files first,
    /// which is the order the two files were kept in.
    ///
    /// - Parameters:
    ///   - lhs: A class key.
    ///   - rhs: A class key.
    /// - Returns: Whether `lhs` files before `rhs`.
    static func classKeyPrecedes(_ lhs: String, _ rhs: String) -> Bool {
        let lhsSubjectNumeric = CollectionKeying.isSubjectNumericClass(lhs)
        let rhsSubjectNumeric = CollectionKeying.isSubjectNumericClass(rhs)
        if lhsSubjectNumeric != rhsSubjectNumeric { return !lhsSubjectNumeric }
        guard lhsSubjectNumeric else {
            // Decimal: plain character order IS filing order. Every key opens with a three-digit
            // class number, and what follows the point is a fraction read digit by digit.
            return lhs < rhs
        }
        switch lhs.compare(rhs, options: [.numeric]) {
        case .orderedAscending: return true
        case .orderedDescending: return false
        // `.numeric` treats `POL 3` and `POL 03` as equal; character order keeps the sort total.
        case .orderedSame: return lhs < rhs
        }
    }

    /// An era's class rows in the chosen order.
    ///
    /// Ties on document count fall back to filing order, ascending, whichever direction the count
    /// runs — a tie-break that followed the direction would reverse the file inside every run of
    /// equal counts, and 1,962 of the 1910–49 era's classes have exactly one document.
    ///
    /// - Parameters:
    ///   - rows: The rows, in any order.
    ///   - sort: The key and direction.
    /// - Returns: The rows, ordered.
    static func sortedClassRows(_ rows: [ArchivesClassAxis.ClassRow],
                                by sort: Sort) -> [ArchivesClassAxis.ClassRow] {
        rows.sorted { a, b in
            switch sort.key {
            case .documents:
                if a.documents != b.documents {
                    return sort.ascending ? a.documents < b.documents : a.documents > b.documents
                }
                return classKeyPrecedes(a.key, b.key)
            case .name:
                return sort.ascending ? classKeyPrecedes(a.key, b.key) : classKeyPrecedes(b.key, a.key)
            }
        }
    }

    // MARK: - Collections

    /// What the Collections lens is grouped by.
    enum CollectionGrouping: String, CaseIterable, Identifiable, Sendable {
        /// The institution FRUS's citations name — a presidential library, the Department, NARA.
        case repository
        /// The National Archives record group the citations name.
        case recordGroup
        /// One list, no sections — the only arrangement in which a document-count sort ranks every
        /// collection against every other. Named `ungrouped` and never `none`: on an optional
        /// grouping, `.none` silently means nil.
        case ungrouped

        var id: String { rawValue }

        /// The menu label.
        var label: String {
            switch self {
            case .repository:
                return String(localized: "browser.archives.group.repository",
                              defaultValue: "Repository")
            case .recordGroup:
                return String(localized: "browser.archives.group.recordGroup",
                              defaultValue: "Record Group")
            case .ungrouped:
                return String(localized: "browser.archives.group.ungrouped",
                              defaultValue: "Ungrouped")
            }
        }

        /// The menu button's text — `By Repository`, `By Record Group`, and plain `Ungrouped`,
        /// because "By Ungrouped" is not English.
        var summary: String {
            guard self != .ungrouped else { return label }
            return String(format: String(localized: "browser.archives.group.summary %@",
                                         defaultValue: "By %@"), label)
        }

        /// Whether the list has sections a reader can collapse.
        var hasSections: Bool { self != .ungrouped }
    }

    /// A grouping and a sort — what the collection list builds its sections from, read from its
    /// host's stored choices.
    struct CollectionArrangement: Equatable, Hashable, Sendable {
        /// What the list is grouped by.
        var grouping: CollectionGrouping
        /// What each section, and the sections themselves, are ordered by.
        var sort: Sort
    }

    /// One collection as the list shows it.
    struct CollectionRow: Identifiable, Sendable {
        /// The authority record.
        let record: AuthorityCollectionRecord
        /// Documents whose printed source note names it. Zero for a collection cited only in a
        /// volume's front matter — 2,599 of the 4,432 in the shipped authority.
        let documents: Int

        var id: String { record.id }
    }

    /// One section of the collection list.
    struct CollectionSection: Identifiable, Sendable {
        /// Stable identity — the grouping's own key, never the display title. It carries the
        /// grouping, so a section collapsed under one grouping is remembered, not confused with
        /// another's.
        let id: String
        /// The grouping that built it. The view reads THIS, not the menu's current choice, so a list
        /// still showing the previous grouping mid-rebuild draws that grouping's headers.
        let grouping: CollectionGrouping
        /// The header.
        let title: String
        /// The group's key: a repository name or a bare record-group number. Empty for the
        /// remainder.
        let groupKey: String
        /// Whether this is the bucket of collections the grouping cannot place.
        let isRemainder: Bool
        /// The collections, ordered.
        let rows: [CollectionRow]

        /// The documents across the section, which is what a document-count sort orders
        /// sections by.
        var documents: Int { rows.reduce(0) { $0 + $1.documents } }
    }

    /// The header for collections whose citations name no repository.
    static var unattributedTitle: String {
        String(localized: "collection.browser.unattributed", defaultValue: "(Unattributed)")
    }

    /// The single section's title when the list is ungrouped. Never drawn as a header; it is the
    /// section's name for anything that reads one.
    static var allCollectionsTitle: String {
        String(localized: "browser.archives.group.allCollections", defaultValue: "All Collections")
    }

    /// The header for collections whose citations name no record group.
    static var noRecordGroupTitle: String {
        String(localized: "browser.archives.group.noRecordGroup", defaultValue: "(No Record Group)")
    }

    /// A record-group section's header: the number, and NARA's own title for it where the bundle
    /// has one.
    ///
    /// - Parameters:
    ///   - number: The bare record-group number, e.g. `"59"`.
    ///   - title: The authority title, e.g. *General Records of the Department of State*.
    /// - Returns: `RG 59 · General Records of the Department of State`, or `Record Group 59`.
    static func recordGroupTitle(_ number: String, title: String?) -> String {
        if let title, !title.isEmpty {
            return String(format: String(localized: "browser.archives.group.rgTitle %@ %@",
                                         defaultValue: "RG %1$@ · %2$@"), number, title)
        }
        return String(format: String(localized: "browser.archives.group.rgNumber %@",
                                     defaultValue: "Record Group %@"), number)
    }

    /// The collection list, grouped and ordered — the same function for every host.
    ///
    /// - Parameters:
    ///   - records: The authority's collections.
    ///   - documents: Documents whose source note names a collection id — zero when none does.
    ///   - arrangement: The grouping and sort.
    ///   - recordGroupTitles: NARA's title for each record-group number the bundle knows.
    /// - Returns: The sections, remainder last.
    static func collectionSections(
        records: [AuthorityCollectionRecord],
        documents: (String) -> Int,
        arrangement: CollectionArrangement,
        recordGroupTitles: [String: String]
    ) -> [CollectionSection] {
        if arrangement.grouping == .ungrouped {
            let rows = records
                .map { CollectionRow(record: $0, documents: documents($0.id)) }
                .sorted { rowPrecedes($0, $1, by: arrangement.sort) }
            guard !rows.isEmpty else { return [] }
            return [CollectionSection(id: "ungrouped:", grouping: .ungrouped,
                                      title: allCollectionsTitle, groupKey: "",
                                      isRemainder: false, rows: rows)]
        }
        var buckets: [String: [CollectionRow]] = [:]
        var remainder: [CollectionRow] = []
        for record in records {
            let row = CollectionRow(record: record, documents: documents(record.id))
            let key: String?
            switch arrangement.grouping {
            case .repository: key = record.repository
            case .recordGroup: key = record.recordGroup
            case .ungrouped: key = nil        // returned above; here only so the switch is total
            }
            if let key = key?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty {
                buckets[key, default: []].append(row)
            } else {
                remainder.append(row)
            }
        }

        let sort = arrangement.sort
        var sections = buckets.map { key, rows in
            CollectionSection(
                id: "\(arrangement.grouping.rawValue):\(key)",
                grouping: arrangement.grouping,
                title: arrangement.grouping == .recordGroup
                    ? recordGroupTitle(key, title: recordGroupTitles[key])
                    : key,
                groupKey: key,
                isRemainder: false,
                rows: rows.sorted { rowPrecedes($0, $1, by: sort) })
        }
        sections.sort { sectionPrecedes($0, $1, grouping: arrangement.grouping, by: sort) }
        if !remainder.isEmpty {
            sections.append(CollectionSection(
                id: "\(arrangement.grouping.rawValue):",
                grouping: arrangement.grouping,
                title: arrangement.grouping == .recordGroup ? noRecordGroupTitle : unattributedTitle,
                groupKey: "",
                isRemainder: true,
                rows: remainder.sorted { rowPrecedes($0, $1, by: sort) }))
        }
        return sections
    }

    /// Whether one collection row comes before another.
    ///
    /// Equal counts fall back to the name, ascending, in either direction — 2,599 collections share
    /// a count of zero, and reversing their names along with the count would make a descending
    /// list end Z to A for no reason a reader could see.
    static func rowPrecedes(_ a: CollectionRow, _ b: CollectionRow, by sort: Sort) -> Bool {
        switch sort.key {
        case .documents:
            if a.documents != b.documents {
                return sort.ascending ? a.documents < b.documents : a.documents > b.documents
            }
            return namePrecedes(a.record, b.record)
        case .name:
            return sort.ascending ? namePrecedes(a.record, b.record) : namePrecedes(b.record, a.record)
        }
    }

    /// Name order for collections, as a reader expects it — case- and digit-aware — with the id as
    /// the last word so two identically named collections still sort the same way on every launch.
    private static func namePrecedes(_ a: AuthorityCollectionRecord,
                                     _ b: AuthorityCollectionRecord) -> Bool {
        switch a.name.localizedStandardCompare(b.name) {
        case .orderedAscending: return true
        case .orderedDescending: return false
        case .orderedSame: return a.id < b.id
        }
    }

    /// Whether one section comes before another. The remainder is not passed here — it is
    /// appended after the sort, which is what keeps it last in both directions.
    static func sectionPrecedes(_ a: CollectionSection, _ b: CollectionSection,
                                grouping: CollectionGrouping, by sort: Sort) -> Bool {
        switch sort.key {
        case .documents:
            if a.documents != b.documents {
                return sort.ascending ? a.documents < b.documents : a.documents > b.documents
            }
            return groupKeyPrecedes(a.groupKey, b.groupKey, grouping: grouping)
        case .name:
            return sort.ascending
                ? groupKeyPrecedes(a.groupKey, b.groupKey, grouping: grouping)
                : groupKeyPrecedes(b.groupKey, a.groupKey, grouping: grouping)
        }
    }

    /// Group-key order: record groups by NUMBER, repositories by name.
    private static func groupKeyPrecedes(_ a: String, _ b: String,
                                         grouping: CollectionGrouping) -> Bool {
        switch grouping {
        case .recordGroup:
            // Compared as text, RG 330 files before RG 40.
            switch (Int(a), Int(b)) {
            case let (x?, y?) where x != y: return x < y
            case (_?, nil): return true
            case (nil, _?): return false
            default: return a < b
            }
        case .repository, .ungrouped:
            switch a.localizedStandardCompare(b) {
            case .orderedAscending: return true
            case .orderedDescending: return false
            case .orderedSame: return a < b
            }
        }
    }

    // MARK: - Hosts

    /// Which host a collection list serves, and so where its choices are stored.
    ///
    /// Each host keeps its own, the way each Archives lens keeps its own sort: a reader who groups
    /// Browse by record group has not asked Source Explorer to change.
    enum CollectionListHost: String, Sendable {
        /// Browse ▸ Archives ▸ Collections.
        case browseArchives
        /// Source Explorer's collection list, on both platforms.
        case sourceExplorer

        /// The namespace. **Browse keeps the keys #1270 shipped**, so no reader's saved choice
        /// resets; renaming them would do exactly that, silently.
        var storagePrefix: String {
            switch self {
            case .browseArchives: return "browse.archives.collections"
            case .sourceExplorer: return "sourceExplorer.collections"
            }
        }

        /// The stored grouping.
        var groupingKey: String { "\(storagePrefix).grouping" }
        /// The stored sort key.
        var sortKeyKey: String { "\(storagePrefix).sortKey" }
        /// The stored direction.
        var ascendingKey: String { "\(storagePrefix).ascending" }
    }

    // MARK: - Captions and counts

    /// What the list's counts are — and, grouped by record group, where the collections with none
    /// went.
    ///
    /// - Parameter grouping: The grouping on screen.
    /// - Returns: The caption.
    static func collectionCaption(grouping: CollectionGrouping) -> String {
        let counts = String(localized: "browser.archives.collections.counts",
                            defaultValue: "Counts are documents whose printed source note names the collection; one cited only in a volume’s front matter shows its volumes alone.")
        guard grouping == .recordGroup else { return counts }
        let remainder = String(localized: "browser.archives.collections.noRecordGroup",
                               defaultValue: "Record groups are the National Archives’ own divisions. Collections whose citations name none — nearly every presidential-library collection among them — are listed together last.")
        return "\(counts) \(remainder)"
    }

    /// A collection section header's size — `1 collection`, `4,432 collections` — so a collapsed
    /// section still says what it holds.
    static func collectionCountLabel(_ count: Int) -> String {
        count == 1
            ? String(localized: "browser.archives.header.oneCollection", defaultValue: "1 collection")
            : String(format: String(localized: "browser.archives.header.collections %@",
                                    defaultValue: "%@ collections"), count.formatted())
    }

    /// A filing era header's size — `1 class`, `6,118 classes`.
    static func classCountLabel(_ count: Int) -> String {
        count == 1
            ? String(localized: "browser.archives.header.oneClass", defaultValue: "1 class")
            : String(format: String(localized: "browser.archives.header.classes %@",
                                    defaultValue: "%@ classes"), count.formatted())
    }

    // MARK: - Expanding and collapsing

    /// Whether a section's rows are shown.
    ///
    /// **A search overrides the collapse.** A reader typing a name wants every match, and a match
    /// hidden inside a closed section would read as "no such collection". The collapse is kept, not
    /// cleared, so ending the search restores the sections the reader had closed. Whitespace is not a
    /// search — the filter ignores it, so the collapse holds.
    ///
    /// - Parameters:
    ///   - sectionID: The section.
    ///   - collapsed: The ids the reader has closed.
    ///   - query: The search text.
    /// - Returns: Whether its rows are drawn.
    static func isExpanded(_ sectionID: String, collapsed: Set<String>, query: String) -> Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty || !collapsed.contains(sectionID)
    }

    /// Whether every section on screen is closed — what decides between Expand All and Collapse All.
    ///
    /// Ids closed under ANOTHER grouping do not count: the set remembers them so switching back
    /// restores that grouping's state, but they are not sections on screen. An empty screen is not
    /// "all collapsed".
    static func allCollapsed(_ sectionIDs: [String], collapsed: Set<String>) -> Bool {
        !sectionIDs.isEmpty && sectionIDs.allSatisfy(collapsed.contains)
    }

    /// The collapse state after Expand All or Collapse All.
    ///
    /// Opens every section on screen when all are closed, otherwise closes them all — touching only
    /// the sections on screen, so another grouping's remembered state survives either way.
    static func togglingAll(_ sectionIDs: [String], collapsed: Set<String>) -> Set<String> {
        allCollapsed(sectionIDs, collapsed: collapsed)
            ? collapsed.subtracting(sectionIDs)
            : collapsed.union(sectionIDs)
    }

    /// What the Expand All / Collapse All button acts on, and whether it can act at all.
    ///
    /// **The ids are always the sections ON SCREEN, even while it is disabled**, because they decide
    /// the button's label as well as its action, and an empty list reads "Collapse All". The
    /// completeness critic found the first version withholding them for every rebuild: after Collapse
    /// All, a sort change made a fully closed list offer to collapse itself, and VoiceOver announced
    /// the name changing twice for one choice.
    ///
    /// **It is disabled only while those sections belong to another grouping** — not for every
    /// rebuild. A section's id carries its grouping and not its sort, so part-way through a sort change
    /// the ids on screen are already the right ones to act on.
    ///
    /// - Parameters:
    ///   - onScreen: The sections drawn, or `nil` before the first build.
    ///   - builtGrouping: The grouping those sections were built for.
    ///   - current: The grouping the menu has chosen.
    ///   - searching: Whether a search is showing every match regardless.
    /// - Returns: The ids to label and act on, and whether the button is disabled.
    static func expansionState(onScreen: [CollectionSection]?,
                               builtGrouping: CollectionGrouping?,
                               current: CollectionGrouping,
                               searching: Bool) -> (sectionIDs: [String], isDisabled: Bool) {
        let ids = (onScreen ?? []).filter(\.grouping.hasSections).map(\.id)
        return (ids, searching || builtGrouping != current || ids.isEmpty)
    }

    /// The Expand All / Collapse All button's text.
    static func expansionTitle(allCollapsed: Bool) -> String {
        allCollapsed
            ? String(localized: "browser.archives.expandAll", defaultValue: "Expand All")
            : String(localized: "browser.archives.collapseAll", defaultValue: "Collapse All")
    }

    /// Both of the button's texts, which it reserves for the reason ``sortSummaries(label:)`` gives.
    static var expansionTitles: [String] {
        [expansionTitle(allCollapsed: true), expansionTitle(allCollapsed: false)]
    }

    /// The collapse state after one section's header is tapped.
    static func toggling(_ sectionID: String, collapsed: Set<String>) -> Set<String> {
        var next = collapsed
        if next.remove(sectionID) == nil { next.insert(sectionID) }
        return next
    }

    // MARK: - Search

    /// Whether a collection matches a search: its canonical name, any alias form, or its lot key.
    ///
    /// - Parameters:
    ///   - record: The collection.
    ///   - query: The search text.
    /// - Returns: Whether it matches. An empty query matches everything.
    static func collectionMatches(_ record: AuthorityCollectionRecord, query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        return record.name.localizedCaseInsensitiveContains(query)
            || record.aliases.contains { $0.localizedCaseInsensitiveContains(query) }
            || record.lotFileNorm?.localizedCaseInsensitiveContains(query) == true
    }

    /// The sections narrowed to a search, in the order they were built.
    ///
    /// Filtering keeps the order computed over the whole authority rather than re-sorting the
    /// matches, so a section does not jump position while the reader is still typing.
    ///
    /// - Parameters:
    ///   - sections: The built sections.
    ///   - query: The search text.
    /// - Returns: The sections with at least one match.
    static func filter(_ sections: [CollectionSection], query: String) -> [CollectionSection] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return sections }
        return sections.compactMap { section in
            let rows = section.rows.filter { collectionMatches($0.record, query: query) }
            return rows.isEmpty ? nil : CollectionSection(
                id: section.id, grouping: section.grouping, title: section.title,
                groupKey: section.groupKey,
                isRemainder: section.isRemainder, rows: rows)
        }
    }
}
