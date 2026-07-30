// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - FieldCensus

/// Walks raw record trees and reports **every** key path observed, with counts, JSON types and
/// example values.
///
/// This is the artifact that makes the harvest honest. The typed ``HarvestedRecord`` can only
/// contain fields the projector was told about; the census is derived from the raw tree and
/// therefore reports fields nobody anticipated — including any field NARA adds after this tool was
/// written. Read together, "the census shows `creators[].heading` on 20,126 records" and "the index
/// contains 20,126 creator headings" are a closed loop; without the census, an empty `creators`
/// array in the index is indistinguishable from a record group that genuinely has no creators.
///
/// ## Path syntax
/// Array nesting collapses to `[]`, so every element of a list shares one path:
/// ```
/// creators[].heading
/// variantControlNumbers[].type
/// physicalOccurrences[].holdingsMeasurements[].type
/// accessRestriction.specificAccessRestrictions[].restriction
/// ```
/// Collapsing is what makes the output readable: without it, a 30-element array would produce 30
/// indexed paths and the census would describe one record instead of a corpus.
///
/// ## Determinism
/// Object keys are walked in sorted order and every emitted list is explicitly sorted, so two runs
/// over the same bytes produce byte-identical output. Dictionary iteration order is the classic
/// leak here, and it is the reason the end-to-end test compares bytes across two full runs rather
/// than merely encoding the same value twice.
///
/// Version history:
///   1.0 — Session 2026-07-29: initial implementation
public struct FieldCensus: Sendable, Equatable {

    /// What was observed at one key path.
    public struct PathStat: Sendable, Equatable {
        /// Total leaf occurrences (a 3-element array contributes 3).
        public var occurrences: Int = 0
        /// Distinct records in which the path appeared at least once.
        public var recordsWithPath: Int = 0
        /// Observed JSON type names (`string`, `int`, `double`, `bool`, `null`, `array`, `object`).
        public var types: Set<String> = []
        /// Up to ``exampleCap`` distinct example values, in first-seen order.
        public var examples: [String] = []
        /// Distinct values seen, capped — used to decide whether a path is enum-ish.
        public var distinctValueCount: Int = 0
        /// Whether ``distinctValueCount`` hit its cap and is therefore a floor, not a count.
        public var distinctValueCapped = false
    }

    /// Maximum example values retained per path.
    public static let exampleCap = 3
    /// Maximum characters of an example value.
    public static let exampleLength = 120
    /// Distinct-value ceiling per path. Beyond this the path is free text, not a vocabulary, and
    /// counting further costs memory for no insight.
    public static let distinctValueCap = 500

    /// Key path → observations.
    public private(set) var paths: [String: PathStat] = [:]
    /// Records walked.
    public private(set) var recordCount = 0

    /// Distinct values per path, retained only while under ``distinctValueCap``.
    private var distinctValues: [String: Set<String>] = [:]

    public init() {}

    // MARK: Ingest

    /// Walks one record, updating every path it touches.
    public mutating func ingest(_ record: CatalogJSONValue) {
        recordCount += 1
        var seenThisRecord = Set<String>()
        walk(record, path: "", seenThisRecord: &seenThisRecord)
    }

    /// Recursive walker.
    ///
    /// `seenThisRecord` is what separates ``PathStat/occurrences`` from
    /// ``PathStat/recordsWithPath``: the first counts leaves, the second counts records. They
    /// diverge exactly where the interesting fields live — a series with four control numbers
    /// contributes 4 and 1 — and reporting only one of them would misstate coverage.
    private mutating func walk(
        _ value: CatalogJSONValue, path: String, seenThisRecord: inout Set<String>
    ) {
        switch value {
        case .object(let members):
            if !path.isEmpty { note(path: path, type: "object", scalar: nil, seen: &seenThisRecord) }
            for key in members.keys.sorted() {
                guard let child = members[key] else { continue }
                let childPath = path.isEmpty ? key : path + "." + key
                walk(child, path: childPath, seenThisRecord: &seenThisRecord)
            }

        case .array(let elements):
            // Record the array itself (so an always-empty array is visible as a path with zero
            // element occurrences), then descend into a single collapsed `[]` path.
            note(path: path, type: "array", scalar: nil, seen: &seenThisRecord)
            for element in elements {
                walk(element, path: path + "[]", seenThisRecord: &seenThisRecord)
            }

        case .string(let s):
            note(path: path, type: "string", scalar: s, seen: &seenThisRecord)
        case .int(let i):
            note(path: path, type: "int", scalar: String(i), seen: &seenThisRecord)
        case .double(let d):
            note(path: path, type: "double", scalar: String(d), seen: &seenThisRecord)
        case .bool(let b):
            note(path: path, type: "bool", scalar: b ? "true" : "false", seen: &seenThisRecord)
        case .null:
            note(path: path, type: "null", scalar: nil, seen: &seenThisRecord)
        }
    }

    /// Records one observation at `path`.
    private mutating func note(
        path: String, type: String, scalar: String?, seen: inout Set<String>
    ) {
        guard !path.isEmpty else { return }
        var stat = paths[path] ?? PathStat()
        stat.occurrences += 1
        stat.types.insert(type)
        if seen.insert(path).inserted { stat.recordsWithPath += 1 }

        if let scalar {
            let trimmed = Self.truncate(scalar)
            if var values = distinctValues[path] {
                if values.count < Self.distinctValueCap {
                    values.insert(trimmed)
                    distinctValues[path] = values
                } else {
                    stat.distinctValueCapped = true
                }
                stat.distinctValueCount = values.count
            } else {
                distinctValues[path] = [trimmed]
                stat.distinctValueCount = 1
            }
            if stat.examples.count < Self.exampleCap, !stat.examples.contains(trimmed) {
                stat.examples.append(trimmed)
            }
        }
        paths[path] = stat
    }

    /// Truncates an example value and collapses its whitespace, so a 40 KB scope-and-content note
    /// cannot land in a CSV cell.
    static func truncate(_ s: String) -> String {
        let flat = s.replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespaces)
        guard flat.count > exampleLength else { return flat }
        return String(flat.prefix(exampleLength)) + "…"
    }

    // MARK: Merge

    /// Merges another census in, so per-record-group censuses roll up to a run total.
    ///
    /// Distinct-value sets are merged too, which is why the merged `distinctValueCount` is a real
    /// corpus-wide count rather than the largest per-group count.
    public mutating func merge(_ other: FieldCensus) {
        recordCount += other.recordCount
        for (path, incoming) in other.paths {
            var existing = paths[path] ?? PathStat()
            existing.occurrences += incoming.occurrences
            existing.recordsWithPath += incoming.recordsWithPath
            existing.types.formUnion(incoming.types)
            for example in incoming.examples
            where existing.examples.count < Self.exampleCap && !existing.examples.contains(example) {
                existing.examples.append(example)
            }
            existing.distinctValueCapped = existing.distinctValueCapped || incoming.distinctValueCapped
            paths[path] = existing
        }
        for (path, values) in other.distinctValues {
            var merged = distinctValues[path] ?? []
            merged.formUnion(values)
            if merged.count > Self.distinctValueCap {
                paths[path]?.distinctValueCapped = true
                merged = Set(merged.sorted().prefix(Self.distinctValueCap))
            }
            distinctValues[path] = merged
            paths[path]?.distinctValueCount = merged.count
        }
    }

    // MARK: Reporting

    /// Percentage of walked records carrying `path`, to one decimal place.
    public func presencePercent(_ path: String) -> Double {
        guard recordCount > 0, let stat = paths[path] else { return 0 }
        return (Double(stat.recordsWithPath) / Double(recordCount) * 1000).rounded() / 10
    }

    /// The distinct values at `path`, sorted — the value census for one path.
    ///
    /// Returns `nil` when the path exceeded ``distinctValueCap`` (free text, not a vocabulary), so
    /// a caller cannot mistake a truncated set for a complete one.
    public func distinctValues(at path: String) -> [String]? {
        guard let stat = paths[path], !stat.distinctValueCapped else { return nil }
        return distinctValues[path]?.sorted()
    }

    /// Every observed path, sorted.
    public var sortedPaths: [String] { paths.keys.sorted() }

    /// CSV rows for the field census, one per path, sorted by path.
    public func csvRows() -> [[String]] {
        sortedPaths.map { path in
            let stat = paths[path]!
            return [
                path,
                String(stat.occurrences),
                String(stat.recordsWithPath),
                String(format: "%.1f", presencePercent(path)),
                stat.types.sorted().joined(separator: "|"),
                stat.distinctValueCapped ? ">\(Self.distinctValueCap)" : String(stat.distinctValueCount),
                stat.examples.joined(separator: " ⁝ "),
            ]
        }
    }

    /// Column names for ``csvRows()``.
    public static let csvHeader = [
        "keyPath", "occurrences", "recordsWithPath", "presencePct",
        "jsonTypes", "distinctValues", "examples",
    ]
}

// MARK: - ValueCensus

/// Distinct values, with counts, for the paths whose vocabulary matters.
///
/// A field census says `variantControlNumbers[].type` exists on 89% of records; a value census says
/// *which* types those are and how often each occurs. The second is what the owner asked for — an
/// inventory of the agency-specific control-number types — and it is also the only way to notice
/// that an open vocabulary has grown a value this tool has never seen.
///
/// Paths are configured rather than inferred: censusing every scalar path's full value set would
/// mean holding every distinct title and scope note in memory.
///
/// Version history:
///   1.0 — Session 2026-07-29: initial implementation
public struct ValueCensus: Sendable, Equatable {

    /// The paths whose values are enumerated.
    ///
    /// Chosen for being closed (or nearly closed) vocabularies that a consumer would want to switch
    /// on — plus the two restriction-status paths, where knowing the value set is the difference
    /// between "this series is restricted" and a guess.
    public static let censusedPaths: [String] = [
        "levelOfDescription",
        "recordType",
        "variantControlNumbers[].type",
        "creators[].authorityType",
        "creators[].creatorType",
        "contributors[].authorityType",
        "contributors[].contributorType",
        "digitalObjects[].objectType",
        "soundType",
        "subjects[].authorityType",
        "accessRestriction.status",
        "accessRestriction.specificAccessRestrictions[].restriction",
        // Nested one level deeper than the block, alongside `restriction` — not a block member.
        "accessRestriction.specificAccessRestrictions[].securityClassification",
        "useRestriction.status",
        // Bare strings, NOT objects keyed `restriction`: the two restriction blocks are shaped
        // differently, and censusing this at `[].restriction` reported nothing at all.
        "useRestriction.specificUseRestrictions[]",
        "findingAids[].findingAidType",
        "physicalOccurrences[].copyStatus",
        "physicalOccurrences[].holdingsMeasurements[].type",
        "physicalOccurrences[].mediaOccurrences[].specificMediaType",
        "physicalOccurrences[].mediaOccurrences[].generalMediaTypes[]",
        "physicalOccurrences[].referenceUnits[].name",
        "generalRecordsTypes[].recordType",
        "generalRecordsTypes[]",
        "languages[]",
        "audiovisual",
    ]

    /// `path → value → (occurrences, distinct record groups)`.
    public private(set) var counts: [String: [String: Int]] = [:]
    /// `path → value → record groups it appeared in`. What makes "agency-specific" answerable:
    /// a value confined to one record group is specific to that agency's records, and a value
    /// spread across twenty is a NARA-wide vocabulary term.
    public private(set) var recordGroups: [String: [String: Set<Int>]] = [:]

    public init() {}

    /// Ingests one record's values for the censused paths, attributed to `recordGroup`.
    public mutating func ingest(_ record: CatalogJSONValue, recordGroup: Int) {
        for path in Self.censusedPaths {
            for value in Self.values(at: path, in: record) {
                counts[path, default: [:]][value, default: 0] += 1
                recordGroups[path, default: [:]][value, default: []].insert(recordGroup)
            }
        }
    }

    /// Merges another value census in.
    public mutating func merge(_ other: ValueCensus) {
        for (path, values) in other.counts {
            for (value, count) in values {
                counts[path, default: [:]][value, default: 0] += count
            }
        }
        for (path, values) in other.recordGroups {
            for (value, groups) in values {
                recordGroups[path, default: [:]][value, default: []].formUnion(groups)
            }
        }
    }

    /// Resolves a `[]`-collapsed path against a record, returning every scalar it reaches.
    ///
    /// Shared with ``ControlNumberCensus`` and used by the tests, so the census and the projector
    /// agree on what a path means.
    static func values(at path: String, in record: CatalogJSONValue) -> [String] {
        var frontier: [CatalogJSONValue] = [record]
        for component in path.split(separator: ".", omittingEmptySubsequences: false) {
            var key = String(component)
            var descendIntoArray = false
            while key.hasSuffix("[]") {
                key = String(key.dropLast(2))
                descendIntoArray = true
            }
            var next: [CatalogJSONValue] = []
            for node in frontier {
                let child: CatalogJSONValue? = key.isEmpty ? node : node[key]
                guard let child else { continue }
                if descendIntoArray {
                    next.append(contentsOf: child.asArray)
                } else {
                    next.append(child)
                }
            }
            frontier = next
            if frontier.isEmpty { return [] }
        }
        return frontier.compactMap(\.nonEmptyString)
    }

    /// CSV rows: one per `(path, value)`, sorted by path then descending count then value.
    public func csvRows() -> [[String]] {
        var rows: [[String]] = []
        for path in counts.keys.sorted() {
            let values = counts[path] ?? [:]
            let ordered = values.keys.sorted { a, b in
                let ca = values[a] ?? 0, cb = values[b] ?? 0
                return ca == cb ? a < b : ca > cb
            }
            for value in ordered {
                let groups = (recordGroups[path]?[value] ?? []).sorted()
                rows.append([
                    path,
                    FieldCensus.truncate(value),
                    String(values[value] ?? 0),
                    String(groups.count),
                    groups.map(String.init).joined(separator: " "),
                ])
            }
        }
        return rows
    }

    /// Column names for ``csvRows()``.
    public static let csvHeader = [
        "keyPath", "value", "occurrences", "recordGroupCount", "recordGroups",
    ]
}
