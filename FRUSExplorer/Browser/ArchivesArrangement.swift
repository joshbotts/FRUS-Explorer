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
/// ## Source Explorer keeps its own order
/// ``CollectionBrowserView`` serves three hosts. Only the Browse Archives axis offers these
/// controls; the two Source Explorer hosts pass no arrangement and get
/// ``sourceExplorerSections(records:)`` — the ordering they have always had, moved here verbatim so
/// the list has one render path and that ordering has a test for the first time.
///
/// Version history:
///   1.0 — 2026-09-10: sorting for both counting lenses, and record-group grouping for Collections
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
            }
        }
    }

    /// A grouping and a sort — everything the Browse host hands the collection list.
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
        /// Stable identity — the grouping's own key, never the display title.
        let id: String
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

    /// The collection list, grouped and ordered for the Browse Archives axis.
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
        var buckets: [String: [CollectionRow]] = [:]
        var remainder: [CollectionRow] = []
        for record in records {
            let row = CollectionRow(record: record, documents: documents(record.id))
            let key: String?
            switch arrangement.grouping {
            case .repository: key = record.repository
            case .recordGroup: key = record.recordGroup
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
        case .repository:
            switch a.localizedStandardCompare(b) {
            case .orderedAscending: return true
            case .orderedDescending: return false
            case .orderedSame: return a < b
            }
        }
    }

    // MARK: - Source Explorer's order

    /// The collection list as Source Explorer has always shown it: by repository, each section's
    /// collections by citing-volume count, largest first, and the sections by how many collections
    /// they hold, unattributed last.
    ///
    /// Moved here verbatim from `CollectionBrowserView.loadGroups` so the list has one render path.
    /// **Deliberately not re-expressed as an ``Sort``**: its key is the volume count, which the
    /// Browse controls do not offer, and its tie-breaks use plain character order where the
    /// arrangement uses a reader's — folding it into the new rules would have changed a surface
    /// nobody asked to change.
    ///
    /// - Parameter records: The authority's collections.
    /// - Returns: The sections.
    static func sourceExplorerSections(records: [AuthorityCollectionRecord]) -> [CollectionSection] {
        let unattributed = unattributedTitle
        var buckets: [String: [AuthorityCollectionRecord]] = [:]
        for record in records {
            buckets[record.repository ?? unattributed, default: []].append(record)
        }
        return buckets
            .map { name, records in
                (name: name,
                 records: records.sorted {
                     ($0.volumeIds.count, $1.name) > ($1.volumeIds.count, $0.name)
                 })
            }
            .sorted {
                if ($0.name == unattributed) != ($1.name == unattributed) {
                    return $1.name == unattributed
                }
                return ($0.records.count, $1.name) > ($1.records.count, $0.name)
            }
            .map { group in
                CollectionSection(
                    id: group.name, title: group.name, groupKey: group.name,
                    isRemainder: group.name == unattributed,
                    rows: group.records.map { CollectionRow(record: $0, documents: 0) })
            }
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
                id: section.id, title: section.title, groupKey: section.groupKey,
                isRemainder: section.isRemainder, rows: rows)
        }
    }
}
