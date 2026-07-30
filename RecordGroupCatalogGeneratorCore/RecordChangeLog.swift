// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import GeneratorKit

// MARK: - RecordChange

/// How one record differs between the bulk snapshot and the API refresh.
public enum RecordChange: String, Sendable, Equatable, Codable, CaseIterable {
    /// In the refresh only — new in the catalog since the snapshot.
    case added
    /// In both, and the raw record differs.
    case modified
    /// In both, byte-for-byte identical after normalisation.
    case unchanged
    /// In both, and the only differences are outside the fields this index projects.
    ///
    /// ## Why this state has to exist
    /// Comparing raw trees alone made the changelog useless. Measured on RG 486, 2026-07-30: **all 11**
    /// records came back `modified`, and the entire difference was two fields the projection
    /// deliberately ignores —
    /// - `dataControlGroup.groupCd`/`groupId`, an internal reference-unit code that had shifted
    ///   `RRAT` → `RRAR` since the April snapshot while `groupName` stayed identical, and
    /// - `physicalOccurrences[].referenceUnits[].mailCode`, which the bulk export carries (`"RR2"`)
    ///   and the search API omits.
    ///
    /// Neither touches anything a researcher would notice. Left as `modified`, every record in the
    /// corpus would be flagged on every refresh forever, and a real change would be indistinguishable
    /// from the noise it was buried in. So the classification now asks the useful question — did
    /// anything *in the index* change? — and reports incidental drift separately rather than
    /// discarding it.
    case unchangedOutsideIndex
    /// In the snapshot but **not** in the refresh.
    ///
    /// The interesting case, and the reason re-paging beats a hypothetical "changed since" filter: a
    /// date-based delta structurally cannot report a record that has *gone*. Deliberately named
    /// `missingFromRefresh` rather than `withdrawn` — a record can be absent because NARA withdrew it,
    /// **or** because the refresh query was narrower than the snapshot, or truncated by a request
    /// ceiling. The tool cannot tell those apart, so it does not pretend to.
    case missingFromRefresh
}

// MARK: - RecordChangeLog

/// The bulk-vs-API diff for one run.
///
/// Version history:
///   1.0 — Session 2026-07-30: initial implementation
public struct RecordChangeLog: Sendable, Equatable {

    /// One changed record. `unchanged` records are counted but not enumerated — there are tens of
    /// thousands of them and they are the boring case.
    public struct Entry: Sendable, Equatable {
        public var recordGroup: Int
        public var naId: String
        public var change: RecordChange
        public var title: String?

        public init(recordGroup: Int, naId: String, change: RecordChange, title: String? = nil) {
            self.recordGroup = recordGroup
            self.naId = naId
            self.change = change
            self.title = title
        }
    }

    /// Enumerated non-`unchanged` entries.
    public private(set) var entries: [Entry] = []
    /// Counts per change kind, per record group.
    public private(set) var counts: [Int: [RecordChange: Int]] = [:]

    public init() {}

    /// Records one classification.
    public mutating func note(recordGroup: Int, naId: String, change: RecordChange,
                              title: String? = nil) {
        counts[recordGroup, default: [:]][change, default: 0] += 1
        // Neither no-change state is enumerated per record — together they are the overwhelming
        // majority, and the CSV exists for the records that actually moved.
        guard change != .unchanged, change != .unchangedOutsideIndex else { return }
        entries.append(Entry(recordGroup: recordGroup, naId: naId, change: change, title: title))
    }

    /// Merges another group's log in.
    public mutating func merge(_ other: RecordChangeLog) {
        entries.append(contentsOf: other.entries)
        for (group, kinds) in other.counts {
            for (kind, count) in kinds {
                counts[group, default: [:]][kind, default: 0] += count
            }
        }
    }

    /// Total for one change kind across all groups.
    public func total(_ change: RecordChange) -> Int {
        counts.values.reduce(0) { $0 + ($1[change] ?? 0) }
    }

    /// Whether anything the index cares about differed.
    ///
    /// `unchangedOutsideIndex` does not count: it exists precisely to keep incidental drift out of this
    /// answer.
    public var hasChanges: Bool {
        RecordChange.allCases.contains {
            $0 != .unchanged && $0 != .unchangedOutsideIndex && total($0) > 0
        }
    }

    /// CSV rows, sorted by record group, then change kind, then NAID — stable across runs.
    public func csvRows() -> [[String]] {
        entries
            .sorted {
                ($0.recordGroup, $0.change.rawValue, $0.naId)
                    < ($1.recordGroup, $1.change.rawValue, $1.naId)
            }
            .map { [String($0.recordGroup), $0.naId, $0.change.rawValue, $0.title ?? ""] }
    }

    /// Column names for ``csvRows()``.
    public static let csvHeader = ["recordGroup", "naId", "change", "title"]

    /// Per-group summary lines for the report.
    public func reportLines() -> [String] {
        counts.keys.sorted().map { group in
            let kinds = counts[group] ?? [:]
            let parts = RecordChange.allCases
                .compactMap { kind -> String? in
                    guard let count = kinds[kind], count > 0 else { return nil }
                    return "\(kind.rawValue)=\(count)"
                }
            return "  RG \(group): " + (parts.isEmpty ? "no records compared" : parts.joined(separator: " "))
        }
    }
}
