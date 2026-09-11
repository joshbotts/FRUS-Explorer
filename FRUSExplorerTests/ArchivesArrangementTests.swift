// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing

@testable import FRUSExplorer

// MARK: - ArchivesArrangementTests

/// Sorting the Archives axis's two counting lenses, and grouping its collections.
///
/// **Every ordering fixture here is named AGAINST the expectation.** A sort with a tie-break is only
/// tested if the tie-break alone would produce a different list; otherwise deleting the primary key
/// passes. So each fixture's counts run against its names, and the comment beside it says which
/// wrong implementation it tells apart.
///
/// Version history:
///   1.0 — 2026-09-10: initial implementation
@Suite("Archives — sorting both counting lenses, and grouping collections")
struct ArchivesArrangementTests {

    private typealias Arrangement = ArchivesArrangement
    private typealias Sort = ArchivesArrangement.Sort

    // MARK: Filing order

    @Test("Decimal class numbers file as decimal fractions, which a numeric-aware sort gets wrong")
    func decimalKeysFileAsFractions() throws {
        let shuffled = ["711.2", "711.11", "711.002", "711.00"]
        let filed = shuffled.sorted(by: Arrangement.classKeyPrecedes)
        #expect(filed == ["711.00", "711.002", "711.11", "711.2"])

        // The trap is real rather than asserted: Finder's comparison reads `11` as eleven.
        let finder = shuffled.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        let two = try #require(finder.firstIndex(of: "711.2"))
        let eleven = try #require(finder.firstIndex(of: "711.11"))
        #expect(two < eleven, """
            If a numeric-aware comparison ever filed 711.11 first, the comment on \
            `classKeyPrecedes` would be describing a trap that does not exist. Got \(finder).
            """)
    }

    @Test("Subject-numeric designators file by their numbers, which character order gets wrong")
    func subjectNumericKeysFileByNumber() {
        let shuffled = ["POL 24", "POL 3", "POL 23-10", "POL 23-7"]
        let filed = shuffled.sorted(by: Arrangement.classKeyPrecedes)
        #expect(filed == ["POL 3", "POL 23-7", "POL 23-10", "POL 24"])
        // Character order files POL 23-10 before POL 23-7, and POL 24 before POL 3.
        #expect(shuffled.sorted() != filed)
    }

    @Test("Across the two filing systems, decimal files first")
    func decimalBeforeSubjectNumeric() {
        // This pins the OUTCOME, and says plainly that it cannot pin the explicit system rule:
        // digits already sort before letters in character order, so deleting that rule leaves this
        // green. The rule is kept so the answer does not rest on how `.numeric` compares a letter
        // with a digit, which Foundation does not document. Both argument orders are asserted, so
        // the relation is at least antisymmetric across the boundary.
        #expect(Arrangement.classKeyPrecedes("999.99", "AE 6"))
        #expect(!Arrangement.classKeyPrecedes("AE 6", "999.99"))
        #expect(Arrangement.classKeyPrecedes("100.00", "E 1 US"))
    }

    // MARK: Class rows

    private static func classRow(_ key: String, _ documents: Int) -> ArchivesClassAxis.ClassRow {
        ArchivesClassAxis.ClassRow(key: key, gloss: nil, glossAlternates: [],
                                   documents: documents, volumeIds: ["frus1950v01"])
    }

    /// Filing order is 100.00 < 711.11 < 711.2 < 900.00; the counts run 5, 9, 9, 1 — against it.
    private static let classFixture = [
        classRow("900.00", 1), classRow("711.2", 9), classRow("100.00", 5), classRow("711.11", 9),
    ]

    @Test("Class rows order by count both ways, and a tie keeps filing order either way")
    func classRowsByDocuments() {
        let descending = Arrangement.sortedClassRows(
            Self.classFixture, by: Sort(key: .documents, ascending: false)).map(\.key)
        // 711.11 before 711.2 at the tie: a tie-break that followed the direction would reverse
        // them, and a numeric-aware one would too.
        #expect(descending == ["711.11", "711.2", "100.00", "900.00"])

        let ascending = Arrangement.sortedClassRows(
            Self.classFixture, by: Sort(key: .documents, ascending: true)).map(\.key)
        #expect(ascending == ["900.00", "100.00", "711.11", "711.2"])
    }

    @Test("A subject-numeric tie on count keeps the numeric filing order, not character order")
    func subjectNumericTiesFileByNumber() {
        // POL 27 and POL 7 tie at five. Character order would put POL 27 first (`2` < `7`); the
        // fixture on decimal keys alone could not tell the two tie-breaks apart.
        let rows = [Self.classRow("POL 3 OAU", 1), Self.classRow("POL 27 VIET S", 5),
                    Self.classRow("POL 7 US", 5)]
        let descending = Arrangement.sortedClassRows(
            rows, by: Sort(key: .documents, ascending: false)).map(\.key)
        #expect(descending == ["POL 7 US", "POL 27 VIET S", "POL 3 OAU"])
    }

    @Test("Class-number order runs both ways")
    func classRowsByNumber() {
        let ascending = Arrangement.sortedClassRows(
            Self.classFixture, by: Sort(key: .name, ascending: true)).map(\.key)
        #expect(ascending == ["100.00", "711.11", "711.2", "900.00"])
        let descending = Arrangement.sortedClassRows(
            Self.classFixture, by: Sort(key: .name, ascending: false)).map(\.key)
        #expect(descending == ["900.00", "711.2", "711.11", "100.00"])
    }

    // MARK: Choosing a key

    @Test("Choosing a key picks its natural direction, and re-choosing the current one changes nothing")
    func selectingAKey() {
        #expect(Sort.standard == Sort(key: .documents, ascending: false))
        #expect(Sort.standard.selecting(.name) == Sort(key: .name, ascending: true), """
            Choosing Name after a descending count must read A to Z, not inherit the direction.
            """)
        #expect(Sort(key: .name, ascending: true).selecting(.documents)
                    == Sort(key: .documents, ascending: false))
        // A reader who flipped the count to ascending and re-picks Document Count keeps their flip.
        let flipped = Sort(key: .documents, ascending: true)
        #expect(flipped.selecting(.documents) == flipped)
    }

    // MARK: Collections

    private static func record(_ id: String, _ name: String, repository: String? = nil,
                               recordGroup: String? = nil, volumes: Int = 1,
                               aliases: [String] = [], lot: String? = nil)
        -> AuthorityCollectionRecord {
        AuthorityCollectionRecord(id: id, name: name, repository: repository,
                                  recordGroup: recordGroup, lotFileNorm: lot, aliases: aliases,
                                  volumeIds: (0..<volumes).map { "frus\($0)" })
    }

    @Test("Record groups order by number, not as text, and the ungrouped stay last both ways")
    func recordGroupsByNumber() {
        let records = [
            Self.record("a", "Alpha", recordGroup: "330"),
            Self.record("b", "Beta", recordGroup: "40"),
            Self.record("c", "Gamma", recordGroup: "59"),
            Self.record("d", "Delta"),
        ]
        for ascending in [true, false] {
            let sections = Arrangement.collectionSections(
                records: records, documents: { _ in 0 },
                arrangement: .init(grouping: .recordGroup,
                                   sort: Sort(key: .name, ascending: ascending)),
                recordGroupTitles: [:])
            // As text these would run 330, 40, 59 — and reversed, 59, 40, 330.
            #expect(sections.map(\.groupKey) == (ascending ? ["40", "59", "330", ""]
                                                            : ["330", "59", "40", ""]))
            #expect(sections.last?.isRemainder == true)
            #expect(sections.last?.title == Arrangement.noRecordGroupTitle)
        }
    }

    @Test("By documents, sections order by their totals and rows by their own counts")
    func collectionsByDocuments() {
        // Section totals: Mid 20, Zeta 11, Alpha 6 — against their names, in both directions.
        // The unattributed bucket holds the most documents of all and must stay last anyway.
        let records = [
            Self.record("z1", "Yankee", repository: "Zeta Library"),
            Self.record("z2", "Xray", repository: "Zeta Library"),
            Self.record("a1", "Bravo", repository: "Alpha Archive"),
            Self.record("a2", "Able", repository: "Alpha Archive"),
            Self.record("m1", "Charlie", repository: "Mid Library"),
            Self.record("m2", "Echo", repository: "Mid Library"),
            Self.record("u1", "Unplaced"),
        ]
        let counts = ["z1": 10, "z2": 1, "a1": 3, "a2": 3, "m1": 15, "m2": 5, "u1": 100]
        func sections(ascending: Bool) -> [Arrangement.CollectionSection] {
            Arrangement.collectionSections(
                records: records, documents: { counts[$0] ?? 0 },
                arrangement: .init(grouping: .repository,
                                   sort: Sort(key: .documents, ascending: ascending)),
                recordGroupTitles: [:])
        }

        let descending = sections(ascending: false)
        #expect(descending.map(\.title)
                    == ["Mid Library", "Zeta Library", "Alpha Archive", Arrangement.unattributedTitle])
        #expect(descending.first { $0.groupKey == "Zeta Library" }?.rows.map(\.record.name)
                    == ["Yankee", "Xray"])
        // Bravo and Able tie at 3: the name decides, ascending, in either direction.
        #expect(descending.first { $0.groupKey == "Alpha Archive" }?.rows.map(\.record.name)
                    == ["Able", "Bravo"])

        let ascending = sections(ascending: true)
        #expect(ascending.map(\.title)
                    == ["Alpha Archive", "Zeta Library", "Mid Library", Arrangement.unattributedTitle])
        #expect(ascending.first { $0.groupKey == "Mid Library" }?.rows.map(\.record.name)
                    == ["Echo", "Charlie"])
        #expect(ascending.first { $0.groupKey == "Mid Library" }?.rows.map(\.documents) == [5, 15])
    }

    @Test("Sections with equal totals keep name order, and the remainder's rows are sorted too")
    func sectionTiesAndTheRemainder() {
        // Zeta and Alpha both total 5 and Mid totals 9. A tie-break that followed the direction
        // would put Zeta before Alpha in the descending list.
        let records = [
            Self.record("z", "Zed", repository: "Zeta"), Self.record("a", "Ay", repository: "Alpha"),
            Self.record("m", "Em", repository: "Mid"),
            // The remainder is 2,381 collections in the shipped authority and was never tested for
            // order at all: its rows run against their names here.
            Self.record("r1", "Aaron"), Self.record("r2", "Zachary"),
        ]
        let counts = ["z": 5, "a": 5, "m": 9, "r1": 1, "r2": 7]
        func sections(ascending: Bool) -> [Arrangement.CollectionSection] {
            Arrangement.collectionSections(
                records: records, documents: { counts[$0] ?? 0 },
                arrangement: .init(grouping: .repository,
                                   sort: Sort(key: .documents, ascending: ascending)),
                recordGroupTitles: [:])
        }
        #expect(sections(ascending: false).map(\.groupKey) == ["Mid", "Alpha", "Zeta", ""])
        #expect(sections(ascending: true).map(\.groupKey) == ["Alpha", "Zeta", "Mid", ""])
        #expect(sections(ascending: false).last?.rows.map(\.record.name) == ["Zachary", "Aaron"])
        #expect(sections(ascending: true).last?.rows.map(\.record.name) == ["Aaron", "Zachary"])
    }

    @Test("A section's weight is the SUM of its collections, not its heaviest one")
    func sectionWeightIsASum() {
        // Pair holds two collections of 6 (sum 12, largest 6); Solo holds one of 10 (sum 10,
        // largest 10). Ordered by sum, Pair leads; by largest row, Solo would. The review found every
        // earlier fixture ordered the same way under both rules, so this is the one that tells them
        // apart.
        let records = [
            Self.record("p1", "One", repository: "Pair"), Self.record("p2", "Two", repository: "Pair"),
            Self.record("s1", "Only", repository: "Solo"),
        ]
        let counts = ["p1": 6, "p2": 6, "s1": 10]
        let sections = Arrangement.collectionSections(
            records: records, documents: { counts[$0] ?? 0 },
            arrangement: .init(grouping: .repository, sort: Sort(key: .documents, ascending: false)),
            recordGroupTitles: [:])
        #expect(sections.map(\.groupKey) == ["Pair", "Solo"])
        #expect(sections.map(\.documents) == [12, 10])
    }

    @Test("By name, repositories and collections read A to Z and back, the remainder last")
    func collectionsByName() {
        let records = [
            Self.record("1", "Zulu", repository: "Nixon"),
            Self.record("2", "alpha", repository: "Nixon"),        // lower case: a reader's order
            Self.record("3", "Mike", repository: "Carter Library"),
            Self.record("4", "Kilo"),
        ]
        func sections(ascending: Bool) -> [Arrangement.CollectionSection] {
            Arrangement.collectionSections(
                records: records, documents: { _ in 0 },
                arrangement: .init(grouping: .repository, sort: Sort(key: .name, ascending: ascending)),
                recordGroupTitles: [:])
        }
        #expect(sections(ascending: true).map(\.groupKey) == ["Carter Library", "Nixon", ""])
        #expect(sections(ascending: false).map(\.groupKey) == ["Nixon", "Carter Library", ""])
        // Character order would put "Zulu" before "alpha", since `Z` < `a`.
        #expect(sections(ascending: true).first { $0.groupKey == "Nixon" }?.rows.map(\.record.name)
                    == ["alpha", "Zulu"])
        #expect(sections(ascending: false).first { $0.groupKey == "Nixon" }?.rows.map(\.record.name)
                    == ["Zulu", "alpha"])
    }

    @Test("A record group with a bundled title names it, and one without says its number")
    func recordGroupTitles() {
        #expect(Arrangement.recordGroupTitle("59", title: "General Records of the Department of State")
                    == "RG 59 · General Records of the Department of State")
        #expect(Arrangement.recordGroupTitle("9999", title: nil) == "Record Group 9999")
        #expect(Arrangement.recordGroupTitle("9999", title: "") == "Record Group 9999")
    }

    // MARK: Search

    @Test("Search matches a name, an alias or a lot key, and keeps the built order")
    func searchKeepsTheBuiltOrder() {
        let records = [
            Self.record("n", "Policy Planning Staff Files", repository: "Department of State"),
            Self.record("a", "Records of Dean Rusk", repository: "Department of State",
                        aliases: ["Rusk Files, policy"]),
            Self.record("l", "Lot 64 D 199", repository: "National Archives", lot: "64D199"),
            Self.record("x", "Whitman File", repository: "Eisenhower Library"),
        ]
        let built = Arrangement.collectionSections(
            records: records, documents: { _ in 0 },
            arrangement: .init(grouping: .repository, sort: Sort(key: .name, ascending: false)),
            recordGroupTitles: [:])

        // One fixture per route: the name, the alias, and the lot key each find exactly one record.
        #expect(Arrangement.filter(built, query: "planning").flatMap { $0.rows.map(\.id) } == ["n"])
        #expect(Arrangement.filter(built, query: "rusk files").flatMap { $0.rows.map(\.id) } == ["a"])
        #expect(Arrangement.filter(built, query: "64d199").flatMap { $0.rows.map(\.id) } == ["l"])

        // "policy" hits a name in one record and an alias in another: both survive, in the order
        // they were built (a descending name sort), and the sections with no match are dropped.
        let policy = Arrangement.filter(built, query: "policy")
        #expect(policy.map(\.groupKey) == ["Department of State"])
        // And the other half of the search-grouping rule: a searched GROUPED list keeps its headers.
        #expect(policy.map(\.grouping) == [.repository])
        #expect(policy.first?.rows.map(\.id) == ["a", "n"])
        #expect(Arrangement.filter(built, query: "   ").map(\.id) == built.map(\.id))
    }

    // MARK: Ungrouped

    @Test("Ungrouped is one ranked list: every collection against every other, and no remainder")
    func ungroupedIsOneRankedList() {
        // The counts run against the names AND across the groups these would have sat in: grouped,
        // Zulu (RG 59) and Alpha (no record group at all) could never be neighbours.
        let records = [
            Self.record("a", "Alpha"),
            Self.record("m", "Mike", repository: "Johnson Library"),
            Self.record("z", "Zulu", repository: "Department of State", recordGroup: "59"),
        ]
        let counts = ["a": 40, "m": 5, "z": 90]
        func sections(_ sort: Sort) -> [Arrangement.CollectionSection] {
            Arrangement.collectionSections(
                records: records, documents: { counts[$0] ?? 0 },
                arrangement: .init(grouping: .ungrouped, sort: sort), recordGroupTitles: [:])
        }
        let byCount = sections(Sort(key: .documents, ascending: false))
        #expect(byCount.count == 1)
        #expect(byCount.first?.grouping == .ungrouped)
        #expect(byCount.first?.isRemainder == false, "ungrouped has nothing left over to put last")
        #expect(byCount.first?.rows.map(\.record.name) == ["Zulu", "Alpha", "Mike"])
        #expect(sections(Sort(key: .name, ascending: false)).first?.rows.map(\.record.name)
                    == ["Zulu", "Mike", "Alpha"])
        // A search rebuilds each section it keeps. If that rebuild forgot the grouping, the searched
        // ungrouped list would suddenly draw a header — the view reads the section's grouping, not
        // the menu's. The mutation sweep found nothing pinned it.
        let searched = Arrangement.filter(byCount, query: "zulu")
        #expect(searched.map(\.grouping) == [.ungrouped])
        #expect(searched.first?.rows.map(\.record.name) == ["Zulu"])
        #expect(Arrangement.collectionSections(
            records: [], documents: { _ in 0 },
            arrangement: .init(grouping: .ungrouped, sort: .standard),
            recordGroupTitles: [:]).isEmpty, "no records is no section, not an empty one")
    }

    // MARK: Expanding and collapsing

    @Test("A search shows every match, even inside a closed section — and only a real query does")
    func searchOverridesCollapse() {
        let collapsed: Set<String> = ["repository:Nixon"]
        // One fixture per conjunct of `query is non-empty || section is not collapsed`.
        #expect(!Arrangement.isExpanded("repository:Nixon", collapsed: collapsed, query: ""))
        #expect(Arrangement.isExpanded("repository:Nixon", collapsed: collapsed, query: "nsc"))
        #expect(Arrangement.isExpanded("repository:Carter Library", collapsed: collapsed, query: ""))
        // Whitespace is not a search — the filter ignores it, so the collapse must hold too.
        #expect(!Arrangement.isExpanded("repository:Nixon", collapsed: collapsed, query: "   "))
    }

    @Test("Expand All and Collapse All touch only the sections on screen")
    func expandAndCollapseAllAreScopedToTheScreen() {
        let onScreen = ["recordGroup:59", "recordGroup:84"]
        // Closed under the OTHER grouping, and remembered so switching back restores it.
        let remembered = "repository:Nixon"

        #expect(!Arrangement.allCollapsed([], collapsed: [remembered]),
                "an empty screen is not all-collapsed")
        #expect(!Arrangement.allCollapsed(onScreen, collapsed: ["recordGroup:59", remembered]))
        #expect(Arrangement.allCollapsed(onScreen, collapsed: Set(onScreen + [remembered])))

        // One still open → Collapse All closes the rest, and keeps the remembered one.
        #expect(Arrangement.togglingAll(onScreen, collapsed: ["recordGroup:59", remembered])
                    == Set(onScreen + [remembered]))
        // All closed → Expand All opens the ones on screen and STILL keeps the remembered one.
        #expect(Arrangement.togglingAll(onScreen, collapsed: Set(onScreen + [remembered]))
                    == [remembered])

        #expect(Arrangement.toggling("recordGroup:84", collapsed: [remembered])
                    == ["recordGroup:84", remembered])
        #expect(Arrangement.toggling("recordGroup:84", collapsed: ["recordGroup:84", remembered])
                    == [remembered])
    }

    // MARK: Headers, ids and host wiring

    @Test("Grouped sections carry their grouping, and ids that cannot collide across groupings")
    func groupedSectionsCarryTheirGroupingAndIDs() {
        // The header switch and the collapse memory both read these. A grouped section tagged
        // ungrouped loses its header and its chevron; two groupings' remainders sharing an id would
        // close each other. Every earlier assertion used hand-written ids.
        let records = [
            Self.record("s", "State Files", repository: "Department of State", recordGroup: "59"),
            Self.record("u", "Unplaced"),
        ]
        func sections(_ grouping: Arrangement.CollectionGrouping) -> [Arrangement.CollectionSection] {
            Arrangement.collectionSections(
                records: records, documents: { _ in 0 },
                arrangement: .init(grouping: grouping, sort: .standard), recordGroupTitles: [:])
        }
        let byRepository = sections(.repository)
        let byRecordGroup = sections(.recordGroup)
        #expect(byRepository.map(\.grouping) == [.repository, .repository])
        #expect(byRecordGroup.map(\.grouping) == [.recordGroup, .recordGroup])
        #expect(Arrangement.CollectionGrouping.repository.hasSections)
        #expect(Arrangement.CollectionGrouping.recordGroup.hasSections)
        #expect(!Arrangement.CollectionGrouping.ungrouped.hasSections)
        #expect(byRepository.map(\.id) == ["repository:Department of State", "repository:"])
        #expect(byRecordGroup.map(\.id) == ["recordGroup:59", "recordGroup:"])
        #expect(Set(byRepository.map(\.id)).isDisjoint(with: byRecordGroup.map(\.id)),
                "the two remainders must not share an id, or closing one closes the other")
    }

    @Test("Mid-rebuild the expand button still describes the sections on screen; only a grouping change disables it")
    func expansionStateTellsTheTruthMidRebuild() {
        let records = [Self.record("n", "NSC Files", repository: "Nixon"),
                       Self.record("c", "Subject File", repository: "Carter Library")]
        func built(_ grouping: Arrangement.CollectionGrouping) -> [Arrangement.CollectionSection] {
            Arrangement.collectionSections(
                records: records, documents: { _ in 0 },
                arrangement: .init(grouping: grouping, sort: .standard), recordGroupTitles: [:])
        }
        let byRepository = built(.repository)
        let ids = byRepository.map(\.id)

        // A SORT change: ids carry the grouping, not the sort, so the sections on screen are still the
        // right ones — the button keeps its ids and stays usable. With every section closed it goes on
        // reading Expand All, where the first version flipped to "Collapse All".
        let sortChange = Arrangement.expansionState(
            onScreen: byRepository, builtGrouping: .repository, current: .repository, searching: false)
        #expect(sortChange.sectionIDs == ids)
        #expect(!sortChange.isDisabled)
        #expect(Arrangement.allCollapsed(sortChange.sectionIDs, collapsed: Set(ids)))

        // A GROUPING change, mid-rebuild: the sections on screen are the old grouping's. Disabled — but
        // the ids, and so the label, still describe what is drawn.
        let groupingChange = Arrangement.expansionState(
            onScreen: byRepository, builtGrouping: .repository, current: .recordGroup, searching: false)
        #expect(groupingChange.sectionIDs == ids)
        #expect(groupingChange.isDisabled)

        // One fixture per remaining conjunct.
        #expect(Arrangement.expansionState(
            onScreen: byRepository, builtGrouping: .repository, current: .repository,
            searching: true).isDisabled, "a search already shows every match")
        #expect(Arrangement.expansionState(
            onScreen: [], builtGrouping: .repository, current: .repository,
            searching: false).isDisabled, "nothing on screen to act on")
        // Ungrouped's single section is not collapsible, so it contributes no id.
        let ungrouped = Arrangement.expansionState(
            onScreen: built(.ungrouped), builtGrouping: .ungrouped, current: .ungrouped, searching: false)
        #expect(ungrouped.sectionIDs.isEmpty)
        #expect(ungrouped.isDisabled)
    }

    @Test("Each host passes its own storage, and each stored setting reads its own key")
    func hostWiringIsPinned() throws {
        // The persistence test below pins the key STRINGS. This pins that the right host reaches
        // them and that no setting reads another's key: the host and the three keys are all plain
        // values of one type, so a swap compiles, every other test stays green, and a reader's
        // saved choice silently resets. Comments are stripped so a note naming a call is not
        // mistaken for the call.
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent()
        func code(_ path: String) throws -> String {
            try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { line in line.range(of: "//").map { String(line[..<$0.lowerBound]) } ?? String(line) }
                .joined(separator: "\n")
        }
        let browse = try code("FRUSExplorer/Browser/ArchivesBrowseView.swift")
        #expect(browse.contains("CollectionBrowserView(\n            host: .browseArchives,"))
        #expect(!browse.contains("host: .sourceExplorer"))
        for path in ["FRUSExplorer/App/SupportingViews.swift",
                     "FRUSExplorer/SourceExplorer/SourceExplorerView.swift"] {
            let text = try code(path)
            #expect(text.contains("CollectionBrowserView(host: .sourceExplorer"), "\(path)")
            #expect(!text.contains("host: .browseArchives"), "\(path)")
        }
        // Both hosts that tear the list down on a lens or mode switch hold its closed groups, so the
        // switch does not reopen them. The iOS Source Explorer list is a pushed screen, and leaving it
        // is meant to.
        #expect(browse.contains("collapsed: $collapsedCollectionGroups"))
        #expect(try code("FRUSExplorer/App/SupportingViews.swift")
                    .contains("CollectionBrowserView(host: .sourceExplorer, collapsed: $collapsedCollectionGroups)"))
        let list = try code("FRUSExplorer/SourceExplorer/CollectionBrowserView.swift")
        #expect(list.contains("rawValue, host.groupingKey)"))
        #expect(list.contains("Sort.standard.key.rawValue, host.sortKeyKey)"))
        #expect(list.contains("Sort.standard.ascending, host.ascendingKey)"))
    }

    @Test("Every button reserves room for every label it can show, so a choice never reflows the row")
    func buttonsReserveEveryLabel() {
        // The review confirmed that "Name, Ascending" growing into "Document Count, Descending" pushed
        // the row into another layout, rebuilt the menu the reader was using, moved the list and
        // dropped focus. The buttons now reserve their widest label — which only works if the
        // reserved set really contains every label a button can show.
        let lenses: [(Arrangement.SortKey) -> String] = [{ $0.collectionLabel }, { $0.classLabel }]
        for label in lenses {
            let reserved = Arrangement.sortSummaries(label: label)
            #expect(Set(reserved).count == 4)
            for key in Arrangement.SortKey.allCases {
                for ascending in [true, false] {
                    let shown = Arrangement.sortSummary(Sort(key: key, ascending: ascending), label: label)
                    #expect(reserved.contains(shown), "\(shown) is not reserved")
                }
            }
        }
        #expect(Arrangement.sortSummary(.standard, label: { $0.collectionLabel })
                    == "Document Count, Descending")
        #expect(Arrangement.expansionTitle(allCollapsed: true) == "Expand All")
        #expect(Arrangement.expansionTitle(allCollapsed: false) == "Collapse All")
        #expect(Set(Arrangement.expansionTitles) == ["Expand All", "Collapse All"])
    }

    // MARK: Persistence and labels

    @Test("The stored names do not drift, and Browse keeps the keys #1270 shipped")
    func persistenceTokensAreStable() {
        #expect(Arrangement.CollectionGrouping.allCases.map(\.rawValue)
                    == ["repository", "recordGroup", "ungrouped"])
        #expect(Arrangement.SortKey.allCases.map(\.rawValue) == ["documents", "name"])
        let browse = Arrangement.CollectionListHost.browseArchives
        let browseKeys = [browse.groupingKey, browse.sortKeyKey, browse.ascendingKey]
        #expect(browseKeys == ["browse.archives.collections.grouping",
                               "browse.archives.collections.sortKey",
                               "browse.archives.collections.ascending"],
                "renaming these silently resets every reader's saved choice")
        let explorer = Arrangement.CollectionListHost.sourceExplorer
        #expect(Set([explorer.groupingKey, explorer.sortKeyKey, explorer.ascendingKey])
                    .isDisjoint(with: browseKeys),
                "Source Explorer must not share Browse's stored choices")
    }

    @Test("The menu and header labels read as English")
    func labelsReadAsEnglish() {
        #expect(Arrangement.CollectionGrouping.repository.summary == "By Repository")
        #expect(Arrangement.CollectionGrouping.recordGroup.summary == "By Record Group")
        #expect(Arrangement.CollectionGrouping.ungrouped.summary == "Ungrouped", "not \"By Ungrouped\"")
        #expect(Arrangement.collectionCountLabel(1) == "1 collection")
        #expect(Arrangement.collectionCountLabel(2) == "2 collections")
        #expect(Arrangement.classCountLabel(1) == "1 class")
        #expect(Arrangement.classCountLabel(2) == "2 classes")
    }

    @Test("Only the record-group grouping explains where its remainder went")
    func captionFollowsTheGrouping() {
        let repository = Arrangement.collectionCaption(grouping: .repository)
        #expect(Arrangement.collectionCaption(grouping: .ungrouped) == repository)
        #expect(!repository.contains("listed together last"))
        let recordGroup = Arrangement.collectionCaption(grouping: .recordGroup)
        #expect(recordGroup.hasPrefix(repository))
        #expect(recordGroup.contains("listed together last"))
    }

    // MARK: The shipped data

    @Test("Over the shipped authority every collection lands exactly once, grouped either way")
    func shippedAuthorityPartitions() throws {
        let authority = try #require(CollectionAuthorityStore.shared)
        let usage = try #require(CollectionUsageIndexStore.shared)
        let titles = try #require(VolumeSourcesIndexStore.shared).recordGroups.mapValues(\.title)

        // The two groupings that HAVE sections and a remainder; ungrouped has its own test below.
        for grouping in [Arrangement.CollectionGrouping.repository, .recordGroup] {
            let sections = Arrangement.collectionSections(
                records: authority.collections,
                documents: { usage.documentCount(forCollectionId: $0) },
                arrangement: .init(grouping: grouping, sort: .standard),
                recordGroupTitles: titles)
            let ids = sections.flatMap { $0.rows.map(\.id) }
            #expect(ids.count == authority.collections.count)
            #expect(Set(ids).count == ids.count, "a collection listed twice under \(grouping)")
            #expect(sections.filter(\.isRemainder).count == 1)
            #expect(sections.last?.isRemainder == true)

            let placed = sections.filter { !$0.isRemainder }
            #expect(placed.count > 20, "only \(placed.count) \(grouping) sections")
            #expect(placed.map(\.documents) == placed.map(\.documents).sorted(by: >))
        }

        let byRecordGroup = Arrangement.collectionSections(
            records: authority.collections,
            documents: { usage.documentCount(forCollectionId: $0) },
            arrangement: .init(grouping: .recordGroup, sort: .standard),
            recordGroupTitles: titles)
        let rg59 = try #require(byRecordGroup.first { $0.groupKey == "59" })
        #expect(rg59.title == "RG 59 · General Records of the Department of State")
        // Measured: every record group the authority names has a title in the bundle. A section
        // falling back to its bare number means the two artifacts have drifted apart.
        let untitled = byRecordGroup.filter { !$0.isRemainder && !$0.title.hasPrefix("RG ") }
        #expect(untitled.isEmpty, "no bundled title for \(untitled.map(\.groupKey))")
        #expect(rg59.documents == byRecordGroup.map(\.documents).max(), """
            RG 59 carries the most sourced documents of any record group; if another section \
            outweighs it, the document join has broken.
            """)
    }

    @Test("Ungrouped over the shipped authority ranks all 4,432 collections, heaviest first")
    func shippedUngroupedRanksEveryCollection() throws {
        let authority = try #require(CollectionAuthorityStore.shared)
        let usage = try #require(CollectionUsageIndexStore.shared)
        let sections = Arrangement.collectionSections(
            records: authority.collections,
            documents: { usage.documentCount(forCollectionId: $0) },
            arrangement: .init(grouping: .ungrouped, sort: .standard), recordGroupTitles: [:])
        #expect(sections.count == 1)
        // One section of every collection is not the same thing as one leftover bucket of them: the
        // sweep sent ungrouped through the grouping loop, every record fell into "(Unattributed)",
        // and every other assertion here still held.
        #expect(sections.first?.grouping == .ungrouped)
        #expect(sections.first?.isRemainder == false)
        let rows = try #require(sections.first).rows
        #expect(rows.count == authority.collections.count)
        #expect(rows.map(\.documents) == rows.map(\.documents).sorted(by: >))
        let heaviest = authority.collections.map { usage.documentCount(forCollectionId: $0.id) }.max()
        #expect(rows.first?.documents == heaviest)
        #expect((rows.first?.documents ?? 0) > 10_000,
                "the heaviest collection, Central Files, carries 17,606 documents")
    }

    @Test("No era is cut short, and the real file's numbers come out in filing order")
    func shippedClassesAreUncappedAndFiled() throws {
        let usage = try #require(CollectionUsageIndexStore.shared)
        let url = try #require(Bundle.main.url(forResource: "manifest", withExtension: "json"))
        let entries = try JSONDecoder().decode([VolumeManifestEntry].self,
                                               from: Data(contentsOf: url))
        let coverage = ArchivalVolumeCoverage.map(from: entries)
        let eras = ArchivesClassAxis.eras()

        let early = try #require(eras.first { $0.system == .decimal && $0.span.upperBound == 1949 })
        let earlyRows = ArchivesClassAxis.rows(inEra: early, usage: usage, coverage: coverage)
        #expect(earlyRows.count > 1_000, """
            The 1910–49 era carries 6,118 classes. At or under 200 the old cap is back, and a \
            sorted list would be ordering the wrong slice.
            """)

        // Both traps, on the shipped keys rather than on a fixture — and counted PER SYSTEM.
        //
        // A mutation sweep found the first version of this check hollow for subject-numeric keys:
        // it listed `POL 3`/`POL 24`, which never occur together in one era, so a single counter
        // passed on the decimal pair alone and replacing the numeric comparison with character
        // order left this test green. Every pair below is one where the two orders DISAGREE on
        // keys that really are in the index: character order files `POL 27 VIET S` before
        // `POL 7 US` (`2` < `7`) and `DEF 12-5 JORDAN` before `DEF 4 NATO`.
        var checkedDecimal = 0
        var checkedSubjectNumeric = 0
        for era in eras {
            let filed = ArchivesArrangement.sortedClassRows(
                ArchivesClassAxis.rows(inEra: era, usage: usage, coverage: coverage),
                by: Sort(key: .name, ascending: true)).map(\.key)
            let position = Dictionary(filed.enumerated().map { ($1, $0) },
                                      uniquingKeysWith: { first, _ in first })
            let pairs: [(earlier: String, later: String, decimal: Bool)] = [
                ("711.11", "711.2", true),
                ("POL 7 US", "POL 27 VIET S", false),
                ("DEF 4 NATO", "DEF 12-5 JORDAN", false),
            ]
            for pair in pairs {
                guard let e = position[pair.earlier], let l = position[pair.later] else { continue }
                if pair.decimal { checkedDecimal += 1 } else { checkedSubjectNumeric += 1 }
                #expect(e < l, "\(pair.earlier) should file before \(pair.later) in \(era.title)")
            }
        }
        #expect(checkedDecimal > 0, "no decimal pair occurs in any era — that half tested nothing")
        #expect(checkedSubjectNumeric > 0, """
            no subject-numeric pair occurs in any era — that half tested nothing, which is exactly \
            how the first version of this check let character order through
            """)
    }
}
