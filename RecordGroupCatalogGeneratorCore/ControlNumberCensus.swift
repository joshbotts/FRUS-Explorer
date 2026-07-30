// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ControlNumberCensus

/// The `(type × note × record group)` cross-tab of every `variantControlNumbers` entry harvested —
/// the direct answer to "which agency-specific variant control numbers exist in these record
/// groups".
///
/// ## Why a cross-tab rather than a filter
/// The obvious design is to pick out the control-number types worth keeping. That design is wrong
/// here, and measurably so. State Department lot-file numbers are recorded under **at least two**
/// different `type` values — `"State Department Lot File Number"` and the entirely generic
/// `"Agency-Assigned Identifier"` — and under the generic one they are distinguishable only by the
/// free-text `note`, which appears in several different spellings. Any filter written against
/// `type` alone therefore silently loses a large share of exactly the numbers a researcher wants.
///
/// So nothing is filtered and nothing is rewritten. Every `(type, note)` pair is reported with its
/// exact strings, its occurrence and record counts, its example numbers, and the set of record
/// groups it appears in. `noteClass` is added *alongside* the raw note as a convenience for
/// grouping the spellings; the raw note is always present in its own column, so a wrong
/// classification is visible and correctable rather than baked into the data.
///
/// ## "Agency-specific"
/// A type confined to one or two record groups is specific to those agencies' records; a type
/// spread across most of them is a NARA-wide vocabulary term. ``TypeSummary/recordGroups`` is what
/// makes that distinction answerable from the artifact instead of from intuition, and it is
/// reported rather than thresholded — the line between "agency-specific" and "widespread" is the
/// researcher's call, not this tool's.
///
/// Version history:
///   1.0 — Session 2026-07-29: initial implementation
public struct ControlNumberCensus: Sendable, Equatable {

    /// Cross-tab key. All three components are the values NARA shipped, untouched apart from
    /// whitespace trimming.
    public struct Key: Sendable, Equatable, Hashable, Comparable {
        /// `variantControlNumbers[].type`, verbatim. `nil` for the entries that carry no type.
        public let type: String?
        /// `variantControlNumbers[].note`, verbatim. `nil` when absent.
        public let note: String?
        /// The record group the entry was harvested under.
        public let recordGroup: Int

        public init(type: String?, note: String?, recordGroup: Int) {
            self.type = type
            self.note = note
            self.recordGroup = recordGroup
        }

        public static func < (a: Key, b: Key) -> Bool {
            if a.type != b.type { return (a.type ?? "\u{10FFFF}") < (b.type ?? "\u{10FFFF}") }
            if a.note != b.note { return (a.note ?? "") < (b.note ?? "") }
            return a.recordGroup < b.recordGroup
        }
    }

    /// Counts and examples for one cross-tab cell.
    public struct Cell: Sendable, Equatable {
        /// Total entries in this cell (a record with four numbers of one type contributes 4).
        public var occurrences: Int = 0
        /// Distinct records contributing to this cell.
        public var recordsWithValue: Int = 0
        /// Up to ``exampleCap`` example control numbers, first-seen order, so the reader can see
        /// what the numbers actually look like rather than inferring it from the type label.
        public var exampleNumbers: [String] = []
    }

    /// Per-type roll-up across record groups.
    public struct TypeSummary: Sendable, Equatable {
        public var type: String?
        public var occurrences: Int = 0
        public var recordGroups: Set<Int> = []
        public var distinctNotes: Set<String> = []
    }

    /// Example control numbers retained per cell.
    public static let exampleCap = 4

    /// Cross-tab cells.
    public private(set) var cells: [Key: Cell] = [:]
    /// Per-type roll-ups, keyed by the raw type string (`""` for a missing type).
    public private(set) var typeSummaries: [String: TypeSummary] = [:]
    /// Records that carried at least one control number.
    public private(set) var recordsWithAnyControlNumber = 0
    /// Total entries seen.
    public private(set) var totalEntries = 0

    public init() {}

    // MARK: Ingest

    /// Ingests one record's control numbers.
    ///
    /// Takes the already-projected values rather than the raw tree, because the projection is
    /// verbatim for these three strings — so census and index cannot disagree about what was found.
    public mutating func ingest(_ numbers: [CatalogControlNumber], recordGroup: Int) {
        guard !numbers.isEmpty else { return }
        recordsWithAnyControlNumber += 1

        // Records-per-cell must count records, not entries, so a record carrying three numbers of
        // the same (type, note) increments `recordsWithValue` once and `occurrences` three times.
        var cellsTouchedByThisRecord = Set<Key>()

        for number in numbers {
            totalEntries += 1
            let key = Key(type: number.type, note: number.note, recordGroup: recordGroup)
            var cell = cells[key] ?? Cell()
            cell.occurrences += 1
            if cellsTouchedByThisRecord.insert(key).inserted { cell.recordsWithValue += 1 }
            if let raw = number.number,
               cell.exampleNumbers.count < Self.exampleCap,
               !cell.exampleNumbers.contains(raw) {
                cell.exampleNumbers.append(raw)
            }
            cells[key] = cell

            let typeKey = number.type ?? ""
            var summary = typeSummaries[typeKey] ?? TypeSummary(type: number.type)
            summary.occurrences += 1
            summary.recordGroups.insert(recordGroup)
            if let note = number.note { summary.distinctNotes.insert(note) }
            typeSummaries[typeKey] = summary
        }
    }

    /// Merges another census in.
    public mutating func merge(_ other: ControlNumberCensus) {
        recordsWithAnyControlNumber += other.recordsWithAnyControlNumber
        totalEntries += other.totalEntries
        for (key, incoming) in other.cells {
            var existing = cells[key] ?? Cell()
            existing.occurrences += incoming.occurrences
            existing.recordsWithValue += incoming.recordsWithValue
            for example in incoming.exampleNumbers
            where existing.exampleNumbers.count < Self.exampleCap
                && !existing.exampleNumbers.contains(example) {
                existing.exampleNumbers.append(example)
            }
            cells[key] = existing
        }
        for (typeKey, incoming) in other.typeSummaries {
            var existing = typeSummaries[typeKey] ?? TypeSummary(type: incoming.type)
            existing.occurrences += incoming.occurrences
            existing.recordGroups.formUnion(incoming.recordGroups)
            existing.distinctNotes.formUnion(incoming.distinctNotes)
            typeSummaries[typeKey] = existing
        }
    }

    // MARK: Note classification

    /// Groups the spellings of a free-text note without altering it.
    ///
    /// Purely additive: the raw note travels in its own CSV column, and this is a second column
    /// beside it. The rule is deliberately crude — case-folded, punctuation-stripped, whitespace-
    /// collapsed — because a clever normaliser that merged two genuinely different notes would be
    /// worse than a dumb one that leaves them apart, and the raw column is always there to check
    /// against.
    public static func noteClass(_ note: String?) -> String {
        guard let note, !note.isEmpty else { return "" }
        let folded = note.lowercased()
            .replacingOccurrences(of: "[^a-z0-9 ]", with: " ", options: .regularExpression)
        return folded.split(separator: " ").joined(separator: " ")
    }

    // MARK: Reporting

    /// Cross-tab CSV rows, sorted by type, then note, then record group.
    public func crossTabRows() -> [[String]] {
        cells.keys.sorted().map { key in
            let cell = cells[key]!
            return [
                key.type ?? "(no type)",
                key.note ?? "",
                Self.noteClass(key.note),
                String(key.recordGroup),
                String(cell.occurrences),
                String(cell.recordsWithValue),
                cell.exampleNumbers.joined(separator: " ⁝ "),
            ]
        }
    }

    /// Column names for ``crossTabRows()``.
    public static let crossTabHeader = [
        "type", "note", "noteClass", "recordGroup",
        "occurrences", "recordsWithValue", "exampleNumbers",
    ]

    /// Per-type summary rows, most frequent first — the "which types exist, and are they
    /// agency-specific" table.
    public func typeSummaryRows() -> [[String]] {
        typeSummaries.values
            .sorted { a, b in
                a.occurrences == b.occurrences
                    ? (a.type ?? "") < (b.type ?? "")
                    : a.occurrences > b.occurrences
            }
            .map { summary in
                let groups = summary.recordGroups.sorted()
                return [
                    summary.type ?? "(no type)",
                    String(summary.occurrences),
                    String(groups.count),
                    groups.map(String.init).joined(separator: " "),
                    String(summary.distinctNotes.count),
                    summary.distinctNotes.sorted().prefix(3)
                        .map(FieldCensus.truncate).joined(separator: " ⁝ "),
                ]
            }
    }

    /// Column names for ``typeSummaryRows()``.
    public static let typeSummaryHeader = [
        "type", "occurrences", "recordGroupCount", "recordGroups",
        "distinctNoteCount", "exampleNotes",
    ]
}

// MARK: - CreatorCensus

/// The creator inventory: every creating organization or person referenced by a harvested record,
/// with its occurrence count and the record groups it creates records in.
///
/// The counterpart to ``ControlNumberCensus`` for the harvest's other priority payload. Where the
/// index answers "who created this series", this answers "who are the creators across these 22
/// record groups, and which of them span more than one agency's records" — which is the question a
/// researcher tracing an office through successive reorganisations actually has.
///
/// Version history:
///   1.0 — Session 2026-07-29: initial implementation
public struct CreatorCensus: Sendable, Equatable {

    /// One creator's roll-up.
    public struct Entry: Sendable, Equatable {
        public var naId: String?
        public var heading: String?
        public var authorityType: String?
        /// Occurrences per `creatorType` (`Most Recent` / `Predecessor`), kept apart because the
        /// same organization is routinely both, and collapsing them would hide the succession
        /// structure that makes the creator data worth having.
        public var creatorTypeCounts: [String: Int] = [:]
        public var recordGroups: Set<Int> = []
        public var recordCount = 0
    }

    /// Creator key (NAID when present, else the heading) → roll-up.
    public private(set) var entries: [String: Entry] = [:]
    /// Records carrying at least one creator.
    public private(set) var recordsWithAnyCreator = 0

    public init() {}

    /// Ingests one record's creators.
    public mutating func ingest(_ creators: [CatalogCreator], recordGroup: Int) {
        guard !creators.isEmpty else { return }
        recordsWithAnyCreator += 1
        for creator in creators {
            let key = creator.naId ?? creator.heading ?? ""
            guard !key.isEmpty else { continue }
            var entry = entries[key] ?? Entry(
                naId: creator.naId, heading: creator.heading,
                authorityType: creator.authorityType)
            // A heading arriving where one was previously missing fills the gap; a differing
            // heading for the same NAID is left alone (the first wins) so the census does not
            // churn on NARA's date-span punctuation.
            if entry.heading == nil { entry.heading = creator.heading }
            if entry.authorityType == nil { entry.authorityType = creator.authorityType }
            entry.creatorTypeCounts[creator.role ?? "(none)", default: 0] += 1
            entry.recordGroups.insert(recordGroup)
            entry.recordCount += 1
            entries[key] = entry
        }
    }

    /// Merges another creator census in.
    public mutating func merge(_ other: CreatorCensus) {
        recordsWithAnyCreator += other.recordsWithAnyCreator
        for (key, incoming) in other.entries {
            var existing = entries[key] ?? Entry(
                naId: incoming.naId, heading: incoming.heading,
                authorityType: incoming.authorityType)
            if existing.heading == nil { existing.heading = incoming.heading }
            if existing.authorityType == nil { existing.authorityType = incoming.authorityType }
            for (type, count) in incoming.creatorTypeCounts {
                existing.creatorTypeCounts[type, default: 0] += count
            }
            existing.recordGroups.formUnion(incoming.recordGroups)
            existing.recordCount += incoming.recordCount
            entries[key] = existing
        }
    }

    /// Every creator NAID referenced — the join key set for ``CreatorAuthorityIndex``.
    public var referencedNaIds: Set<String> {
        Set(entries.values.compactMap(\.naId))
    }

    /// Census rows, most-referenced first.
    public func csvRows() -> [[String]] {
        entries.values
            .sorted { a, b in
                a.recordCount == b.recordCount
                    ? (a.heading ?? "") < (b.heading ?? "")
                    : a.recordCount > b.recordCount
            }
            .map { entry in
                let groups = entry.recordGroups.sorted()
                let types = entry.creatorTypeCounts.keys.sorted()
                    .map { "\($0)=\(entry.creatorTypeCounts[$0] ?? 0)" }
                    .joined(separator: " ")
                return [
                    entry.naId ?? "",
                    entry.heading ?? "",
                    entry.authorityType ?? "",
                    String(entry.recordCount),
                    String(groups.count),
                    groups.map(String.init).joined(separator: " "),
                    types,
                ]
            }
    }

    /// Column names for ``csvRows()``.
    public static let csvHeader = [
        "creatorNaId", "heading", "authorityType", "recordCount",
        "recordGroupCount", "recordGroups", "creatorTypes",
    ]
}
