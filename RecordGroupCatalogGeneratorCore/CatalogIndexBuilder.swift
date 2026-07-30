// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - RecordGroupSummary

/// One record group's line in the manifest.
///
/// Version history:
///   1.0 — Session 2026-07-29: initial implementation
public struct RecordGroupSummary: Codable, Sendable, Equatable {

    /// Record group number.
    public var recordGroup: Int
    /// NAID of the group's own catalog node, from its `recordGroup`-level record.
    public var naId: String?
    /// The group's title **as NARA states it**. Never a value this tool guessed.
    public var title: String?
    /// Depth this group was harvested at.
    public var depth: HarvestDepth
    /// Catalog deep link to the group node.
    public var catalogURL: String?

    // MARK: Completeness

    /// NARA's own `seriesCount` from the group node — the authoritative expected total.
    ///
    /// This is what makes a short harvest self-detecting without any external table. Verified on
    /// RG 486: the group node states `seriesCount: 11` and the shards contain exactly 11 series.
    public var expectedSeriesCount: Int?
    /// Series actually projected.
    public var harvestedSeriesCount: Int
    /// File units projected (zero unless the group's depth included them).
    public var harvestedFileUnitCount: Int
    /// Item-level records projected (zero unless depth was `all`).
    public var harvestedItemCount: Int
    /// `harvestedSeriesCount − expectedSeriesCount`. `nil` when NARA states no count.
    public var seriesCountDelta: Int?

    /// Sum of NARA's own `fileUnitCount` across the harvested series — the expected file-unit total.
    ///
    /// The `seriesCount` device one level down, and the reason it is worth having: the owner's
    /// escalation path is per-record-group file units, and until now a file-unit pass had nothing to
    /// check itself against. `nil` when no harvested series stated a count.
    public var expectedFileUnitCount: Int?
    /// `harvestedFileUnitCount − expectedFileUnitCount`, and only meaningful at a depth that
    /// collected file units. `nil` otherwise.
    public var fileUnitCountDelta: Int?

    // MARK: Payload coverage — the two priority fields

    /// Records carrying at least one creator.
    public var recordsWithCreators: Int
    /// Records carrying at least one variant control number.
    public var recordsWithControlNumbers: Int
    /// Records carrying at least one contributor.
    public var recordsWithContributors: Int
    /// Records carrying a `localIdentifier` — the agency-assigned identifier that sits outside
    /// `variantControlNumbers` entirely.
    public var recordsWithLocalIdentifier: Int
    /// Distinct creator NAIDs referenced.
    public var distinctCreators: Int
    /// Distinct control-number types observed.
    public var distinctControlNumberTypes: Int

    // MARK: Harvest mechanics

    public var shardsListed: Int
    public var shardsRead: Int
    public var bytesRead: Int
    public var rawRecordsStored: Int
    public var snapshotLastModified: String?
    public var state: RecordGroupHarvestOutcome.State

    // MARK: Data-quality counters

    /// Records refused by an invariant, by reason.
    public var invariantViolations: [String: Int]
    /// A few example refusals, for the review block.
    public var invariantExamples: [String]
    /// NDJSON lines that failed to decode.
    public var malformedLines: Int
    /// Raw record keys the projection did not map, with occurrence counts — the schema-drift
    /// tripwire, surfaced per group rather than only in aggregate.
    public var unprojectedKeyCounts: [String: Int]

    public init(
        recordGroup: Int, naId: String? = nil, title: String? = nil, depth: HarvestDepth,
        catalogURL: String? = nil, expectedSeriesCount: Int? = nil, harvestedSeriesCount: Int = 0,
        harvestedFileUnitCount: Int = 0, harvestedItemCount: Int = 0, seriesCountDelta: Int? = nil,
        expectedFileUnitCount: Int? = nil, fileUnitCountDelta: Int? = nil,
        recordsWithCreators: Int = 0, recordsWithControlNumbers: Int = 0,
        recordsWithContributors: Int = 0, recordsWithLocalIdentifier: Int = 0,
        distinctCreators: Int = 0,
        distinctControlNumberTypes: Int = 0, shardsListed: Int = 0, shardsRead: Int = 0,
        bytesRead: Int = 0, rawRecordsStored: Int = 0, snapshotLastModified: String? = nil,
        state: RecordGroupHarvestOutcome.State = .complete,
        invariantViolations: [String: Int] = [:], invariantExamples: [String] = [],
        malformedLines: Int = 0, unprojectedKeyCounts: [String: Int] = [:]
    ) {
        self.recordGroup = recordGroup
        self.naId = naId
        self.title = title
        self.depth = depth
        self.catalogURL = catalogURL
        self.expectedSeriesCount = expectedSeriesCount
        self.harvestedSeriesCount = harvestedSeriesCount
        self.harvestedFileUnitCount = harvestedFileUnitCount
        self.harvestedItemCount = harvestedItemCount
        self.seriesCountDelta = seriesCountDelta
        self.expectedFileUnitCount = expectedFileUnitCount
        self.fileUnitCountDelta = fileUnitCountDelta
        self.recordsWithCreators = recordsWithCreators
        self.recordsWithControlNumbers = recordsWithControlNumbers
        self.recordsWithContributors = recordsWithContributors
        self.recordsWithLocalIdentifier = recordsWithLocalIdentifier
        self.distinctCreators = distinctCreators
        self.distinctControlNumberTypes = distinctControlNumberTypes
        self.shardsListed = shardsListed
        self.shardsRead = shardsRead
        self.bytesRead = bytesRead
        self.rawRecordsStored = rawRecordsStored
        self.snapshotLastModified = snapshotLastModified
        self.state = state
        self.invariantViolations = invariantViolations
        self.invariantExamples = invariantExamples
        self.malformedLines = malformedLines
        self.unprojectedKeyCounts = unprojectedKeyCounts
    }

    /// Whether the harvested series count is materially short of NARA's own.
    ///
    /// A shortfall is the signature of silent truncation, which is the failure this whole design is
    /// most exposed to. Reported at any non-zero delta; the runner escalates a large one to a
    /// non-zero exit.
    public var isMateriallyShort: Bool {
        guard let expected = expectedSeriesCount, expected > 0 else { return false }
        return Double(harvestedSeriesCount) < Double(expected) * 0.9
    }
}

// MARK: - RecordGroupCatalogManifest

/// The committed manifest: provenance, per-group summaries, and the run's own self-assessment.
///
/// The index shards are large and gitignored; this is the small file that describes them, and it is
/// what a reviewer reads to decide whether a harvest is trustworthy.
///
/// Version history:
///   1.0 — Session 2026-07-29: initial implementation
public struct RecordGroupCatalogManifest: Codable, Sendable, Equatable {

    /// Manifest schema version.
    public var schemaVersion: Int
    /// `yyyy-MM-dd` generation stamp.
    public var generated: String
    /// Where the data came from.
    public var source: Source
    /// Run totals.
    public var totals: Totals
    /// Per-group summaries, ordered by record group number.
    public var recordGroups: [RecordGroupSummary]
    /// Which key spelling matched for each projected field, and where none did.
    public var fieldAliasReport: [AliasReportEntry]
    /// Human-readable warnings the run wants a reader to see.
    public var reviewNotes: [String]

    /// Current schema version emitted by this generator.
    public static let currentSchemaVersion = 1

    /// Provenance of the harvest.
    public struct Source: Codable, Sendable, Equatable {
        /// `s3-bulk-export`.
        public var kind: String
        /// Bucket origin used.
        public var baseURL: String
        /// Distinct shard `Last-Modified` values seen — the export snapshot date(s). A harvest that
        /// straddles a re-publication shows more than one, which is worth knowing before trusting
        /// cross-group comparisons.
        public var snapshotLastModified: [String]
        /// Why this source rather than the v2 search API.
        public var note: String

        public init(kind: String, baseURL: String, snapshotLastModified: [String], note: String) {
            self.kind = kind
            self.baseURL = baseURL
            self.snapshotLastModified = snapshotLastModified
            self.note = note
        }
    }

    /// Run totals.
    public struct Totals: Codable, Sendable, Equatable {
        public var recordGroupCount: Int
        public var expectedSeriesCount: Int
        public var harvestedSeriesCount: Int
        public var harvestedFileUnitCount: Int
        public var harvestedItemCount: Int
        public var recordsWithCreators: Int
        public var recordsWithControlNumbers: Int
        public var distinctCreators: Int
        public var distinctControlNumberTypes: Int
        public var shardsRead: Int
        public var bytesRead: Int
        public var malformedLines: Int
        public var invariantViolations: Int

        public init(recordGroupCount: Int = 0, expectedSeriesCount: Int = 0,
                    harvestedSeriesCount: Int = 0, harvestedFileUnitCount: Int = 0,
                    harvestedItemCount: Int = 0, recordsWithCreators: Int = 0,
                    recordsWithControlNumbers: Int = 0, distinctCreators: Int = 0,
                    distinctControlNumberTypes: Int = 0, shardsRead: Int = 0, bytesRead: Int = 0,
                    malformedLines: Int = 0, invariantViolations: Int = 0) {
            self.recordGroupCount = recordGroupCount
            self.expectedSeriesCount = expectedSeriesCount
            self.harvestedSeriesCount = harvestedSeriesCount
            self.harvestedFileUnitCount = harvestedFileUnitCount
            self.harvestedItemCount = harvestedItemCount
            self.recordsWithCreators = recordsWithCreators
            self.recordsWithControlNumbers = recordsWithControlNumbers
            self.distinctCreators = distinctCreators
            self.distinctControlNumberTypes = distinctControlNumberTypes
            self.shardsRead = shardsRead
            self.bytesRead = bytesRead
            self.malformedLines = malformedLines
            self.invariantViolations = invariantViolations
        }
    }

    /// One field's alias outcome.
    public struct AliasReportEntry: Codable, Sendable, Equatable {
        public var field: String
        /// Spelling → match count. Empty means nothing matched anywhere.
        public var matchedAliases: [String: Int]
        public var presentButEmpty: Int
        public var absent: Int
        /// `true` when this field is one whose total absence fails the run.
        public var required: Bool

        public init(field: String, matchedAliases: [String: Int],
                    presentButEmpty: Int, absent: Int, required: Bool) {
            self.field = field
            self.matchedAliases = matchedAliases
            self.presentButEmpty = presentButEmpty
            self.absent = absent
            self.required = required
        }
    }

    public init(schemaVersion: Int = RecordGroupCatalogManifest.currentSchemaVersion,
                generated: String, source: Source, totals: Totals,
                recordGroups: [RecordGroupSummary],
                fieldAliasReport: [AliasReportEntry] = [],
                reviewNotes: [String] = []) {
        self.schemaVersion = schemaVersion
        self.generated = generated
        self.source = source
        self.totals = totals
        self.recordGroups = recordGroups.sorted { $0.recordGroup < $1.recordGroup }
        self.fieldAliasReport = fieldAliasReport.sorted { $0.field < $1.field }
        self.reviewNotes = reviewNotes
    }
}

// MARK: - RecordGroupIndexShard

/// One record group's harvested records — the index proper, written per group.
///
/// Sharded per group rather than emitted as one file for three reasons: RG 59 alone would dominate
/// any combined artifact, a later per-group file-unit pass rewrites exactly one shard and leaves the
/// rest byte-identical, and a consumer interested in one agency reads one file.
public struct RecordGroupIndexShard: Codable, Sendable, Equatable {
    public var schemaVersion: Int
    public var generated: String
    public var recordGroup: Int
    public var title: String?
    public var depth: HarvestDepth
    /// Records, sorted by NAID (digit-aware) for a stable diff.
    public var records: [HarvestedRecord]

    /// Current schema version emitted by this generator.
    public static let currentSchemaVersion = 1

    public init(schemaVersion: Int = RecordGroupIndexShard.currentSchemaVersion,
                generated: String, recordGroup: Int, title: String?, depth: HarvestDepth,
                records: [HarvestedRecord]) {
        self.schemaVersion = schemaVersion
        self.generated = generated
        self.recordGroup = recordGroup
        self.title = title
        self.depth = depth
        self.records = records.sorted {
            $0.naId.compare($1.naId, options: .numeric) == .orderedAscending
        }
    }
}

// MARK: - GroupBuildResult

/// The offline build output for one record group.
public struct GroupBuildResult: Sendable {
    public var summary: RecordGroupSummary
    public var records: [HarvestedRecord]
    public var fieldCensus: FieldCensus
    public var valueCensus: ValueCensus
    public var controlNumberCensus: ControlNumberCensus
    public var creatorCensus: CreatorCensus
    public var aliasLedger: FieldAliasLedger
    /// Bulk-vs-refresh diff for this group. Empty when no overlay was supplied.
    public var changeLog: RecordChangeLog
}

// MARK: - CatalogIndexBuilder

/// Projects a record group's stored raw NDJSON into the index and the censuses.
///
/// Entirely offline — no network, no API key. This is the phase a schema correction re-runs
/// (`PROJECT_ONLY=1`): the raw bytes are already on disk, so fixing a projection costs seconds
/// rather than another 22 GB.
///
/// One group is built at a time and its records handed straight to the writer, so peak memory is one
/// group's projection rather than the whole corpus. That matters at `DEPTH=all`, where RG 59's item
/// records run into the millions.
///
/// Version history:
///   1.0 — Session 2026-07-29: initial implementation
public struct CatalogIndexBuilder: Sendable {

    /// Invariant-violation examples retained per group.
    static let invariantExampleCap = 10

    private let rawStore: RawRecordStore
    private let projector: RecordProjector

    public init(rawStore: RawRecordStore, projector: RecordProjector = RecordProjector()) {
        self.rawStore = rawStore
        self.projector = projector
    }

    /// Builds one record group from its stored raw records.
    ///
    /// - Parameters:
    ///   - outcome: the harvest outcome, whose mechanics carry into the summary.
    ///   - censusEveryRecord: when `false`, the field census samples rather than walking every
    ///     record. Walking every record is the default and correct for a series harvest (20k
    ///     records); an item-level harvest of RG 59 would spend most of its time in the walker for
    ///     no additional insight, since a census converges long before a million records.
    /// - Parameter overlay: a second raw store whose records **supersede** the base store's, matched by
    ///   NAID. This is how the API refresh layers over the bulk snapshot: the refresh is newer, so it
    ///   wins, and the differences are classified into ``GroupBuildResult/changeLog`` rather than
    ///   silently applied.
    public func build(
        outcome: RecordGroupHarvestOutcome,
        overlay: RawRecordStore? = nil,
        censusEveryRecord: Bool = true,
        censusSampleEvery: Int = 25
    ) throws -> GroupBuildResult {

        let recordGroup = outcome.recordGroup
        var summary = RecordGroupSummary(
            recordGroup: recordGroup, depth: outcome.depth,
            shardsListed: outcome.shardsListed, shardsRead: outcome.shardsRead,
            bytesRead: outcome.bytesRead, rawRecordsStored: outcome.recordsStored,
            snapshotLastModified: outcome.snapshotLastModified, state: outcome.state,
            malformedLines: outcome.malformedLines)

        var records: [HarvestedRecord] = []
        var fieldCensus = FieldCensus()
        var valueCensus = ValueCensus()
        var controlNumberCensus = ControlNumberCensus()
        var creatorCensus = CreatorCensus()
        var ledger = FieldAliasLedger()
        var violations: [String: Int] = [:]
        var violationExamples: [String] = []
        var unprojectedCounts: [String: Int] = [:]
        var seen = 0
        var seenNaIds = Set<String>()
        var statedFileUnits = 0
        var sawFileUnitCount = false
        var changeLog = RecordChangeLog()

        // Load the overlay first, keyed by NAID. Held in memory because the comparison needs random
        // access by NAID: for a series-level group that is a few thousand records (RG 59, the largest,
        // is ~4,400), so tens of megabytes at worst.
        var overlayRecords: [String: CatalogJSONValue] = [:]
        if let overlay, overlay.exists(recordGroup: recordGroup) {
            try overlay.forEachRecord(recordGroup: recordGroup) { raw in
                guard let naId = raw["naId"]?.nonEmptyString else { return }
                overlayRecords[naId] = raw
            }
        }
        var overlayNaIdsSeenInBase = Set<String>()
        var duplicateRecords = 0
        var duplicateExamples: [String] = []

        // Declared as a named closure so the base stream and the overlay pass share one code path —
        // two copies of the projection/census logic would drift.
        // `isOverlay` is load-bearing. The supersede/missing classification below must run only while
        // streaming the BASE store: an overlay record is itself a member of `overlayRecords`, so
        // without this flag the overlay pass matched every record against itself, returned early, and
        // projected nothing at all — leaving an index of only the records the refresh did NOT mention.
        func ingest(_ raw: CatalogJSONValue, isOverlay: Bool = false) throws {
            seen += 1

            // The group node: authoritative title, NAID and NARA's own series count.
            if raw["levelOfDescription"]?.nonEmptyString == "recordGroup" {
                summary.naId = raw["naId"]?.nonEmptyString
                summary.title = raw["title"]?.nonEmptyString
                summary.expectedSeriesCount = raw["seriesCount"]?.intValue
                if let naId = summary.naId {
                    summary.catalogURL = RecordProjector.catalogIDBase + naId
                }
                return
            }

            // Overlay supersedes base. The classification asks whether anything IN THE INDEX changed,
            // with raw-only differences reported separately — see RecordChange.unchangedOutsideIndex
            // for the measurement that forced this. Comparing raw trees alone flagged all 11 of RG
            // 486's records as modified over two fields the projection ignores.
            if !isOverlay, let naId = raw["naId"]?.nonEmptyString, let fresher = overlayRecords[naId] {
                overlayNaIdsSeenInBase.insert(naId)
                let change: RecordChange
                if fresher == raw {
                    change = .unchanged
                } else {
                    // Project both sides through a throwaway ledger — this comparison must not
                    // pollute the run's alias observations, which describe the harvest rather than
                    // the diff.
                    var scratch = FieldAliasLedger()
                    let before = projector.project(raw, recordGroup: recordGroup,
                                                   depth: outcome.depth, ledger: &scratch)
                    let after = projector.project(fresher, recordGroup: recordGroup,
                                                  depth: outcome.depth, ledger: &scratch)
                    if case .projected(let b) = before, case .projected(let a) = after {
                        change = b == a ? .unchangedOutsideIndex : .modified
                    } else {
                        // One side no longer projects at all (an invariant now fails, say). That is a
                        // real change by any reading.
                        change = .modified
                    }
                }
                changeLog.note(recordGroup: recordGroup, naId: naId, change: change,
                               title: raw["title"]?.nonEmptyString)
                return
            }
            if !isOverlay, !overlayRecords.isEmpty,
               let naId = raw["naId"]?.nonEmptyString,
               raw["levelOfDescription"]?.nonEmptyString != "recordGroup" {
                // In the snapshot, absent from the refresh. Could be a withdrawal, or a narrower or
                // truncated refresh query — the tool cannot tell, and says so.
                changeLog.note(recordGroup: recordGroup, naId: naId, change: .missingFromRefresh,
                               title: raw["title"]?.nonEmptyString)
            }

            if censusEveryRecord || seen % censusSampleEvery == 0 {
                fieldCensus.ingest(raw)
                valueCensus.ingest(raw, recordGroup: recordGroup)
            }

            switch projector.project(raw, recordGroup: recordGroup,
                                     depth: outcome.depth, ledger: &ledger) {
            case .projected(let record):
                // De-duplicate by NAID. The truncate-on-resume path should make this unnecessary, but
                // it is the backstop that keeps the index correct by construction: a duplicate would
                // otherwise inflate `harvestedSeriesCount` *past* NARA's `seriesCount`, and the
                // completeness check only tests for a shortfall — so duplicates would pass unnoticed.
                // Counted and reported, never silently absorbed.
                guard seenNaIds.insert(record.naId).inserted else {
                    duplicateRecords += 1
                    if duplicateExamples.count < Self.invariantExampleCap {
                        duplicateExamples.append("naId \(record.naId) appeared more than once")
                    }
                    return
                }
                records.append(record)
                // Identity fallback: every record's ancestry carries the record group's own NAID and
                // title, so those two are recoverable even when the group node itself is not in the
                // stored set (a depth-filtered re-projection, or a budget-truncated harvest that has
                // not yet reached the shard holding it). `seriesCount` is not recoverable this way —
                // it exists only on the group node — so it stays nil and the completeness check
                // honestly reports "unknown" rather than defaulting to zero.
                if summary.naId == nil,
                   let ancestor = record.ancestors.first(where: {
                       $0.levelOfDescription == "recordGroup"
                   }) {
                    summary.naId = ancestor.naId
                    summary.title = ancestor.title
                    if let naId = ancestor.naId {
                        summary.catalogURL = RecordProjector.catalogIDBase + naId
                    }
                }
                switch record.levelOfDescription {
                case "series":   summary.harvestedSeriesCount += 1
                case "fileUnit": summary.harvestedFileUnitCount += 1
                case "item":     summary.harvestedItemCount += 1
                default:         break
                }
                if !record.creators.isEmpty { summary.recordsWithCreators += 1 }
                if !record.variantControlNumbers.isEmpty { summary.recordsWithControlNumbers += 1 }
                if !record.contributors.isEmpty { summary.recordsWithContributors += 1 }
                if record.localIdentifier != nil { summary.recordsWithLocalIdentifier += 1 }
                // Only series state a fileUnitCount, so the expected total is their sum.
                if record.levelOfDescription == "series", let stated = record.fileUnitCount {
                    statedFileUnits += stated
                    sawFileUnitCount = true
                }
                controlNumberCensus.ingest(record.variantControlNumbers, recordGroup: recordGroup)
                // Contributors go through the same census and therefore the same authority join:
                // `CatalogCreator.role` reports `Producer`/`Originator` where a creator reports
                // `Most Recent`, so both are visible and distinguishable in one table.
                creatorCensus.ingest(record.creators + record.contributors,
                                     recordGroup: recordGroup)
                for key in record.unprojectedKeys { unprojectedCounts[key, default: 0] += 1 }

            case .levelNotAdmitted:
                // Expected and uninteresting: the shards interleave levels, so a series-only
                // harvest of a stored file unit simply skips it.
                break

            case .rejected(let violation):
                let reason = Self.reasonKey(violation)
                violations[reason, default: 0] += 1
                if violationExamples.count < Self.invariantExampleCap {
                    violationExamples.append(violation.auditLine)
                }
            }
        }

        // Base pass: the bulk snapshot.
        try rawStore.forEachRecord(recordGroup: recordGroup) { try ingest($0) }

        // Overlay pass: these records win, and any NAID the base never had is an addition.
        for naId in overlayRecords.keys.sorted() {
            guard let raw = overlayRecords[naId] else { continue }
            // The group's own node carries the metadata (title, seriesCount), not content. The base
            // pass returns early on it without marking it seen, so without this guard it would be
            // reported as a newly ADDED record on every refresh.
            let isGroupNode = raw["levelOfDescription"]?.nonEmptyString == "recordGroup"
            if !isGroupNode, !overlayNaIdsSeenInBase.contains(naId) {
                changeLog.note(recordGroup: recordGroup, naId: naId, change: .added,
                               title: raw["title"]?.nonEmptyString)
            }
            try ingest(raw, isOverlay: true)
        }


        if let expected = summary.expectedSeriesCount {
            summary.seriesCountDelta = summary.harvestedSeriesCount - expected
        }
        if sawFileUnitCount {
            summary.expectedFileUnitCount = statedFileUnits
            // Only a delta at a depth that actually collected file units; at series depth the
            // harvested count is zero by design and a "delta" would read as a shortfall.
            if outcome.depth != .series {
                summary.fileUnitCountDelta = summary.harvestedFileUnitCount - statedFileUnits
            }
        }
        summary.distinctCreators = creatorCensus.entries.count
        summary.distinctControlNumberTypes = controlNumberCensus.typeSummaries.count
        if duplicateRecords > 0 {
            violations["duplicateRecord"] = duplicateRecords
            violationExamples.append(contentsOf: duplicateExamples)
        }
        summary.invariantViolations = violations
        summary.invariantExamples = violationExamples
        summary.unprojectedKeyCounts = unprojectedCounts

        return GroupBuildResult(
            summary: summary, records: records, fieldCensus: fieldCensus,
            valueCensus: valueCensus, controlNumberCensus: controlNumberCensus,
            creatorCensus: creatorCensus, aliasLedger: ledger, changeLog: changeLog)
    }

    /// Stable key for a violation reason, for the counters.
    static func reasonKey(_ violation: RecordInvariantViolation) -> String {
        switch violation {
        case .missingNaId:             return "missingNaId"
        case .missingTitle:            return "missingTitle"
        case .noRecordGroupAncestor:   return "noRecordGroupAncestor"
        case .recordGroupMismatch:     return "recordGroupMismatch"
        }
    }
}
