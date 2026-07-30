// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - HarvestDepth

/// Which levels of description a record group's harvest keeps.
///
/// The depth is **per record group**, not global: the owner's stated plan is series everywhere
/// now, with file units added for chosen record groups in later runs. Because NARA's bulk export
/// ships every level interleaved in the same shards (measured: RG 59 shard 1 holds 7 series, 466
/// file units and 14 items in its first 3 MB), raising a group's depth changes only this filter —
/// it needs no new query, no new endpoint, and no second transport.
///
/// Version history:
///   1.0 — Session 2026-07-29: initial implementation
public enum HarvestDepth: String, Sendable, Equatable, CaseIterable, Codable {
    /// Series records only. The default, and the whole of the first harvest.
    case series
    /// Series plus file units. The per-group opt-in for a later run.
    case seriesAndFileUnits
    /// Every level the export carries, item records included.
    ///
    /// Item level is where the export's bulk lives — an item record can carry
    /// `digitalObjects.completeExtractedText`, which is why RG 59's shards total 17.2 GB — so this
    /// is offered for completeness rather than recommended.
    case all

    /// The `levelOfDescription` values this depth admits.
    ///
    /// `recordGroup` is admitted at every depth and never counted as a harvested record: the
    /// group's own node is what supplies the authoritative title, NAID and `seriesCount` used for
    /// the completeness check, so it must survive the filter even in a series-only run.
    public var admittedLevels: Set<String> {
        switch self {
        case .series:            return ["series"]
        case .seriesAndFileUnits: return ["series", "fileUnit"]
        case .all:               return ["series", "fileUnit", "item", "collection"]
        }
    }

    /// The admitted levels in **hierarchy order**, coarsest first: series → fileUnit → item.
    ///
    /// Order matters, and sorting them alphabetically was a real bug: `"fileUnit" < "series"`, so a
    /// `seriesAndFileUnits` harvest attempted the file-unit level FIRST. When RG 59's first file-unit
    /// page failed (HTTP 500 — a ~20 MB mean response at `limit=1000`, with individual file-unit
    /// records running to 4.24 MB), the group aborted before the cheap, known-good series level had
    /// been fetched at all. Coarsest-first means a failure at a deeper level can never cost a
    /// shallower one.
    public var orderedLevels: [String] {
        ["series", "fileUnit", "item", "collection"].filter { admittedLevels.contains($0) }
    }

    /// Whether `level` is kept at this depth.
    public func admits(_ level: String?) -> Bool {
        guard let level else { return false }
        return admittedLevels.contains(level)
    }
}

// MARK: - RecordGroupPlan

/// One record group's harvest instruction: which group, and how deep.
public struct RecordGroupPlan: Sendable, Equatable {
    /// NARA record group number (e.g. `59`).
    public let number: Int
    /// Levels to keep for this group.
    public let depth: HarvestDepth

    public init(number: Int, depth: HarvestDepth) {
        self.number = number
        self.depth = depth
    }

    /// The S3 key prefix holding this group's description shards.
    public var shardPrefix: String { "descriptions/record-groups/rg_\(number)/" }
}

// MARK: - RecordGroupHarvestPlan

/// Resolves the set of record groups to harvest and each one's depth.
///
/// Version history:
///   1.0 — Session 2026-07-29: initial implementation
public struct RecordGroupHarvestPlan: Sendable, Equatable {

    /// The record groups in plan order.
    public let groups: [RecordGroupPlan]

    public init(groups: [RecordGroupPlan]) {
        self.groups = groups
    }

    /// The 22 record groups this tool was commissioned for — the foreign-affairs cluster: State's
    /// own two groups (59, 84), the negotiating and claims commissions (43, 76, 239, 256, 268,
    /// 278), the wartime information and economic-warfare agencies (63, 169, 182, 208, 229), the
    /// Cold War information, aid and arms-control apparatus (286, 306, 353, 383, 466, 469, 490),
    /// and two later trade-and-investment finance agencies (420, 486).
    ///
    /// Numbers only, deliberately: no titles are baked in. Each group's authoritative title, NAID
    /// and series count are read from its own `recordGroup`-level record in the export, so the
    /// manifest cannot disagree with NARA and a title this file guessed wrongly cannot ship.
    public static let defaultRecordGroupNumbers: [Int] = [
        43, 59, 63, 76, 84, 169, 182, 208, 229, 239, 256,
        268, 278, 286, 306, 353, 383, 420, 466, 469, 486, 490,
    ]

    /// Builds a plan from the environment contract.
    ///
    /// - Parameters:
    ///   - recordGroups: `RECORD_GROUPS` — comma-separated group numbers. Empty/absent selects
    ///     ``defaultRecordGroupNumbers``.
    ///   - depth: `DEPTH` — the baseline depth applied to every group. Invalid values throw
    ///     rather than silently degrading to `series`, because a typo'd `DEPTH=fileUnits` that
    ///     quietly harvested series only would look like a successful run.
    ///   - depthOverrides: `DEPTH_OVERRIDES` — comma-separated `<rg>:<depth>` pairs, the
    ///     per-group escalation path (e.g. `486:seriesAndFileUnits,268:seriesAndFileUnits`).
    public static func resolve(
        recordGroups: String?,
        depth: String?,
        depthOverrides: String?
    ) throws -> RecordGroupHarvestPlan {
        let numbers = try parseGroupNumbers(recordGroups)
        let baseline = try parseDepth(depth) ?? .series
        let overrides = try parseOverrides(depthOverrides)

        if let stray = overrides.keys.first(where: { !numbers.contains($0) }) {
            throw RecordGroupHarvestPlanError.overrideForUnselectedGroup(stray)
        }

        return RecordGroupHarvestPlan(groups: numbers.map {
            RecordGroupPlan(number: $0, depth: overrides[$0] ?? baseline)
        })
    }

    /// Parses `RECORD_GROUPS`, preserving first-appearance order and dropping duplicates.
    static func parseGroupNumbers(_ raw: String?) throws -> [Int] {
        guard let raw, !raw.trimmingCharacters(in: .whitespaces).isEmpty else {
            return defaultRecordGroupNumbers
        }
        var seen = Set<Int>()
        var out: [Int] = []
        for token in raw.split(whereSeparator: { $0 == "," || $0 == " " }) {
            let trimmed = token.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            guard let n = Int(trimmed), n > 0 else {
                throw RecordGroupHarvestPlanError.invalidRecordGroup(trimmed)
            }
            if seen.insert(n).inserted { out.append(n) }
        }
        guard !out.isEmpty else { throw RecordGroupHarvestPlanError.emptyRecordGroupList }
        return out
    }

    /// Parses a depth token, accepting the enum's own spelling case-insensitively.
    static func parseDepth(_ raw: String?) throws -> HarvestDepth? {
        guard let raw, !raw.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        let token = raw.trimmingCharacters(in: .whitespaces)
        if let match = HarvestDepth.allCases.first(where: {
            $0.rawValue.lowercased() == token.lowercased()
        }) { return match }
        throw RecordGroupHarvestPlanError.invalidDepth(token)
    }

    /// Parses `DEPTH_OVERRIDES` (`<rg>:<depth>` pairs).
    static func parseOverrides(_ raw: String?) throws -> [Int: HarvestDepth] {
        guard let raw, !raw.trimmingCharacters(in: .whitespaces).isEmpty else { return [:] }
        var out: [Int: HarvestDepth] = [:]
        for pair in raw.split(separator: ",") {
            let parts = pair.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else {
                throw RecordGroupHarvestPlanError.malformedOverride(String(pair))
            }
            let numberToken = parts[0].trimmingCharacters(in: .whitespaces)
            guard let number = Int(numberToken), number > 0 else {
                throw RecordGroupHarvestPlanError.invalidRecordGroup(numberToken)
            }
            guard let depth = try parseDepth(String(parts[1])) else {
                throw RecordGroupHarvestPlanError.malformedOverride(String(pair))
            }
            out[number] = depth
        }
        return out
    }
}

// MARK: - RecordGroupHarvestPlanError

/// A malformed harvest plan. Every case is a configuration typo that must stop the run: a plan
/// this tool "helpfully" corrected would spend a long download producing the wrong index.
public enum RecordGroupHarvestPlanError: Error, Sendable, Equatable, CustomStringConvertible {
    case invalidRecordGroup(String)
    case emptyRecordGroupList
    case invalidDepth(String)
    case malformedOverride(String)
    case overrideForUnselectedGroup(Int)

    public var description: String {
        switch self {
        case .invalidRecordGroup(let token):
            return "RECORD_GROUPS: '\(token)' is not a positive record group number"
        case .emptyRecordGroupList:
            return "RECORD_GROUPS was set but contained no record group numbers"
        case .invalidDepth(let token):
            return "DEPTH: '\(token)' is not one of "
                + HarvestDepth.allCases.map(\.rawValue).joined(separator: ", ")
        case .malformedOverride(let pair):
            return "DEPTH_OVERRIDES: '\(pair)' is not a <recordGroup>:<depth> pair"
        case .overrideForUnselectedGroup(let rg):
            return "DEPTH_OVERRIDES names RG \(rg), which RECORD_GROUPS does not select"
        }
    }
}
