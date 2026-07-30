// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - HarvestCheckpoint

/// Per-record-group resume state.
///
/// ## Why per-shard and not per-group
/// A group's shards must be streamed in full even for a series-only harvest, because series are
/// scattered evenly through every shard rather than gathered at the front (measured on RG 59:
/// shards 1, 200 and 400 each carry 7–10 series per 3 MB). RG 59 is 17.2 GB of the ~22 GB total, so
/// "re-run the group from the start" is not an acceptable recovery from an interruption at 90%.
/// The checkpoint therefore records the last **shard** completed, and a resumed run refetches
/// nothing before it.
///
/// ## Why a depth change refuses rather than resumes
/// The shard filter is the only difference between a series harvest and a series-plus-file-units
/// harvest. Resuming a `seriesAndFileUnits` run on top of a `series` checkpoint would skip the
/// already-read shards and so miss every file unit in them, producing an index that claims a depth
/// it does not have. That is worse than re-reading, so it is refused with an actionable message.
///
/// Version history:
///   1.0 — Session 2026-07-29: initial implementation
public struct HarvestCheckpoint: Codable, Sendable, Equatable {
    /// Record group this checkpoint belongs to.
    public var recordGroup: Int
    /// Depth the recorded shards were filtered at.
    public var depth: HarvestDepth
    /// Highest shard index fully processed. `0` means none.
    public var lastCompletedShardIndex: Int
    /// Shards the listing reported when the harvest began — a change means the export was
    /// re-published mid-harvest and the checkpoint no longer describes the same corpus.
    public var shardCount: Int
    /// Raw records written to the NDJSON store so far.
    public var recordsWritten: Int
    /// Bytes fetched so far.
    public var bytesRead: Int
    /// `Last-Modified` of the first shard, as an export-snapshot fingerprint.
    public var snapshotLastModified: String?

    /// Byte length of the raw NDJSON store at the moment this checkpoint was written — i.e. the end
    /// of the last **fully processed** shard.
    ///
    /// ## Why a byte offset and not just a shard index
    /// The checkpoint is written *after* a shard's records are appended, so a process killed partway
    /// through shard N leaves the store holding some of shard N's records while the checkpoint still
    /// names shard N−1. Resuming from the index alone re-reads shard N and appends its records a
    /// second time, and the duplicates are not harmless: they inflate `harvestedSeriesCount` past
    /// NARA's own `seriesCount`, and the completeness check only tests for a *shortfall*, so the run
    /// would pass while shipping duplicated records.
    ///
    /// Recording the store's length lets a resume truncate the partial tail first, which makes the
    /// re-read of shard N correct rather than additive. `nil` on a checkpoint written before this
    /// field existed; such a checkpoint resumes without truncation, exactly as it used to, and the
    /// builder's naId de-duplication is the backstop.
    public var ndjsonByteLength: Int?

    public init(recordGroup: Int, depth: HarvestDepth, lastCompletedShardIndex: Int = 0,
                shardCount: Int = 0, recordsWritten: Int = 0, bytesRead: Int = 0,
                snapshotLastModified: String? = nil, ndjsonByteLength: Int? = nil) {
        self.recordGroup = recordGroup
        self.depth = depth
        self.lastCompletedShardIndex = lastCompletedShardIndex
        self.shardCount = shardCount
        self.recordsWritten = recordsWritten
        self.bytesRead = bytesRead
        self.snapshotLastModified = snapshotLastModified
        self.ndjsonByteLength = ndjsonByteLength
    }

    /// Whether this checkpoint can be resumed for a run at `depth` over `shardCount` shards.
    public func resumability(depth: HarvestDepth, shardCount: Int) -> Resumability {
        if self.depth != depth { return .refuseDepthChanged(from: self.depth, to: depth) }
        if self.shardCount != shardCount { return .refuseShardCountChanged(from: self.shardCount, to: shardCount) }
        if lastCompletedShardIndex >= shardCount { return .complete }
        return .resume(fromShardIndexAfter: lastCompletedShardIndex)
    }

    /// What a resume attempt may do.
    public enum Resumability: Sendable, Equatable {
        case complete
        case resume(fromShardIndexAfter: Int)
        case refuseDepthChanged(from: HarvestDepth, to: HarvestDepth)
        case refuseShardCountChanged(from: Int, to: Int)

        /// Operator-facing explanation, naming the flag that clears the refusal.
        public var refusalMessage: String? {
            switch self {
            case .complete, .resume:
                return nil
            // Both messages scope REFRESH with RECORD_GROUPS deliberately: REFRESH applies to every
            // group in the run, so a bare `REFRESH=1` on the default 22-group plan would discard all
            // 22 raw stores — around 22 GB of completed download — to re-harvest one group.
            case .refuseDepthChanged(let from, let to):
                return "checkpoint was harvested at depth '\(from.rawValue)' but this run asks for "
                    + "'\(to.rawValue)'; the shallower pass never read the deeper levels, so "
                    + "resuming would silently omit them — re-harvest just this group with "
                    + "RECORD_GROUPS=<this rg> REFRESH=1"
            case .refuseShardCountChanged(let from, let to):
                return "checkpoint recorded \(from) shards but the export now lists \(to); NARA has "
                    + "re-published the snapshot — re-harvest just this group with "
                    + "RECORD_GROUPS=<this rg> REFRESH=1"
            }
        }
    }
}

// MARK: - RawRecordStore

/// Append-only NDJSON store for the raw records a harvest matched.
///
/// Serves three purposes at once, which is why it is not optional:
/// 1. **Resume state.** Paired with ``HarvestCheckpoint``, it is what makes an interrupted 17 GB
///    group resumable.
/// 2. **The re-projection source.** If a projection turns out to be wrong or incomplete, `PROJECT_ONLY`
///    rebuilds the index and every census from these bytes with no network at all. Nothing about a
///    schema correction requires re-downloading the export.
/// 3. **The lossless record.** The typed index contains what the projector understood; this
///    contains what NARA sent.
///
/// It lives under the cache directory, which `.gitignore` describes as regenerable scratch — true of
/// the bytes, but regenerating them costs the whole download again, so the runbook says so plainly.
///
/// Version history:
///   1.0 — Session 2026-07-29: initial implementation
public struct RawRecordStore: Sendable {

    /// Directory holding `rg_<N>.ndjson`.
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    /// Path for one record group's store.
    public func url(recordGroup: Int) -> URL {
        directory.appendingPathComponent("rg_\(recordGroup).ndjson")
    }

    /// Path for a group's **staging** store — written during a fetch, swapped in only on success.
    func stagingURL(recordGroup: Int) -> URL {
        directory.appendingPathComponent("rg_\(recordGroup).ndjson.partial")
    }

    /// Opens an appending writer against the staging path, discarding any earlier partial.
    ///
    /// ## Why staging exists
    /// The API harvest used to `reset()` the live store and then fetch into it. A fetch that failed
    /// part-way therefore **destroyed the previous good data** — which is exactly what happened when RG
    /// 59's first file-unit page returned HTTP 500: the reset had already wiped 4,449 successfully
    /// harvested series, and the run died having written only the record-group node. That directly
    /// contradicts the property the raw store is supposed to have, namely being the thing you can
    /// always fall back on.
    ///
    /// Now a fetch writes to `.partial` and the caller calls ``commitStaging(recordGroup:)`` only once
    /// the fetch has succeeded. A failure leaves the previous store untouched.
    public func openStagingWriter(recordGroup: Int) throws -> Writer {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = stagingURL(recordGroup: recordGroup)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        return Writer(handle: handle)
    }

    /// Atomically replaces the live store with the staged one.
    public func commitStaging(recordGroup: Int) throws {
        let staging = stagingURL(recordGroup: recordGroup)
        guard FileManager.default.fileExists(atPath: staging.path) else { return }
        let live = url(recordGroup: recordGroup)
        if FileManager.default.fileExists(atPath: live.path) {
            try FileManager.default.removeItem(at: live)
        }
        try FileManager.default.moveItem(at: staging, to: live)
    }

    /// Throws away a staged fetch, leaving the live store as it was.
    public func discardStaging(recordGroup: Int) throws {
        let staging = stagingURL(recordGroup: recordGroup)
        if FileManager.default.fileExists(atPath: staging.path) {
            try FileManager.default.removeItem(at: staging)
        }
    }

    /// Removes a group's store, for a `REFRESH` re-harvest.
    public func reset(recordGroup: Int) throws {
        let url = url(recordGroup: recordGroup)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    /// Opens an appending writer for one group, creating the file and directory if needed.
    public func openWriter(recordGroup: Int) throws -> Writer {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = url(recordGroup: recordGroup)
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        return Writer(handle: handle)
    }

    /// An appending NDJSON writer.
    ///
    /// Not `Sendable`: it wraps a file handle with position state and is used from one place at a
    /// time within a group's harvest.
    public final class Writer {
        private let handle: FileHandle
        private let encoder: JSONEncoder

        init(handle: FileHandle) {
            self.handle = handle
            self.encoder = JSONEncoder()
            // Sorted keys so the store itself is byte-stable — which is what lets the end-to-end
            // determinism test compare two full runs rather than only comparing re-encodes.
            self.encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        }

        /// Appends one record as a single NDJSON line.
        public func append(_ record: CatalogJSONValue) throws {
            var data = try encoder.encode(record)
            data.append(0x0A)
            try handle.write(contentsOf: data)
        }

        /// Flushes buffered bytes to disk without closing, so the file's on-disk length is accurate
        /// for a checkpoint taken right after.
        public func flush() throws {
            try handle.synchronize()
        }

        /// Flushes and closes.
        public func close() throws {
            try handle.synchronize()
            try handle.close()
        }
    }

    /// Streams a group's stored records back, in write order.
    public func forEachRecord(
        recordGroup: Int,
        onMalformedLine: (Int, Error) -> Void = { _, _ in },
        body: (CatalogJSONValue) throws -> Void
    ) throws {
        let url = url(recordGroup: recordGroup)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        try CatalogBulkExportClient.forEachRecord(
            inNDJSON: data, onMalformedLine: onMalformedLine, body: body)
    }

    /// Whether a group has a store on disk.
    public func exists(recordGroup: Int) -> Bool {
        FileManager.default.fileExists(atPath: url(recordGroup: recordGroup).path)
    }

    /// Current byte length of a group's store, or 0 if absent.
    public func byteLength(recordGroup: Int) -> Int {
        let path = url(recordGroup: recordGroup).path
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attributes[.size] as? Int else { return 0 }
        return size
    }

    /// Truncates a group's store to `length`, discarding the partial tail a killed process left
    /// behind. See ``HarvestCheckpoint/ndjsonByteLength``.
    ///
    /// Only ever shrinks: if the store is already at or below `length` there is nothing to undo, and
    /// growing it would fabricate bytes.
    public func truncate(recordGroup: Int, to length: Int) throws {
        let url = url(recordGroup: recordGroup)
        guard FileManager.default.fileExists(atPath: url.path),
              byteLength(recordGroup: recordGroup) > length else { return }
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.truncate(atOffset: UInt64(length))
    }
}

// MARK: - CheckpointStore

/// Reads and writes ``HarvestCheckpoint`` files.
public struct CheckpointStore: Sendable {

    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    private func url(recordGroup: Int) -> URL {
        directory.appendingPathComponent("rg_\(recordGroup).json")
    }

    /// Loads a checkpoint, treating an unreadable or truncated file as absent.
    ///
    /// A half-written checkpoint is indistinguishable from no checkpoint for recovery purposes, and
    /// treating it as corrupt state to be reported would only stall a run that can simply start the
    /// group again. Writes are atomic, so this should not arise — but a crash mid-write is exactly
    /// the moment the recovery path has to be forgiving.
    public func load(recordGroup: Int) -> HarvestCheckpoint? {
        guard let data = try? Data(contentsOf: url(recordGroup: recordGroup)) else { return nil }
        return try? JSONDecoder().decode(HarvestCheckpoint.self, from: data)
    }

    /// Saves a checkpoint atomically.
    public func save(_ checkpoint: HarvestCheckpoint) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        try encoder.encode(checkpoint).write(to: url(recordGroup: checkpoint.recordGroup),
                                             options: .atomic)
    }

    /// Deletes a checkpoint, for a `REFRESH` re-harvest.
    public func reset(recordGroup: Int) throws {
        let url = url(recordGroup: recordGroup)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}

// MARK: - RecordGroupHarvestOutcome

/// What happened to one record group's harvest pass.
public struct RecordGroupHarvestOutcome: Sendable, Equatable {
    public var recordGroup: Int
    public var depth: HarvestDepth
    /// Shards the listing reported.
    public var shardsListed: Int
    /// Shards fetched during *this* pass (0 on a fully-resumed group).
    public var shardsRead: Int
    /// Bytes fetched during this pass.
    public var bytesRead: Int
    /// Raw records now in the store for this group.
    public var recordsStored: Int
    /// NDJSON lines that failed to decode, with the first few reported.
    public var malformedLines: Int
    public var malformedExamples: [String]
    /// The export snapshot fingerprint.
    public var snapshotLastModified: String?
    /// Terminal state of the pass.
    public var state: State

    public enum State: String, Sendable, Equatable, Codable {
        /// Every shard read.
        case complete
        /// Already complete before this run; nothing fetched.
        case resumedComplete
        /// Stopped by the byte budget with a checkpoint written; re-running continues.
        case budgetExhausted
        /// Refused: the checkpoint is incompatible with this run's request.
        case refused
        /// Re-projected from a raw store that holds an **incomplete** harvest.
        ///
        /// Distinct from `resumedComplete` because `PROJECT_ONLY` cannot tell how much of the export
        /// a store covers by looking at the records — only the checkpoint knows. Labelling a partial
        /// store `resumedComplete` would put "complete" in the manifest for a group that is missing
        /// most of its shards.
        case partial

        /// Whether this state means the group is knowingly incomplete, so a shortfall against NARA's
        /// own series count is expected rather than evidence of silent truncation.
        public var isKnowinglyIncomplete: Bool {
            self == .budgetExhausted || self == .partial
        }
    }

    public init(recordGroup: Int, depth: HarvestDepth, shardsListed: Int = 0, shardsRead: Int = 0,
                bytesRead: Int = 0, recordsStored: Int = 0, malformedLines: Int = 0,
                malformedExamples: [String] = [], snapshotLastModified: String? = nil,
                state: State = .complete) {
        self.recordGroup = recordGroup
        self.depth = depth
        self.shardsListed = shardsListed
        self.shardsRead = shardsRead
        self.bytesRead = bytesRead
        self.recordsStored = recordsStored
        self.malformedLines = malformedLines
        self.malformedExamples = malformedExamples
        self.snapshotLastModified = snapshotLastModified
        self.state = state
    }
}

// MARK: - RecordGroupHarvester

/// Streams one record group's bulk-export shards into the raw store, checkpointing as it goes.
///
/// The harvest phase is deliberately dumb: it filters by level and writes bytes. All
/// interpretation — projection, invariants, censuses — happens in the offline build phase over the
/// stored NDJSON, so a mistake in interpretation costs a re-projection rather than a re-download.
///
/// ## Log prefix
/// `[RecordGroupCatalogGenerator]`
///
/// Version history:
///   1.0 — Session 2026-07-29: initial implementation
public struct RecordGroupHarvester: Sendable {

    private let client: CatalogBulkExportClient
    private let rawStore: RawRecordStore
    private let checkpoints: CheckpointStore
    private let log: @Sendable (String) -> Void

    /// Malformed-line examples retained per group.
    static let malformedExampleCap = 5

    public init(client: CatalogBulkExportClient,
                rawStore: RawRecordStore,
                checkpoints: CheckpointStore,
                log: @escaping @Sendable (String) -> Void = { _ in }) {
        self.client = client
        self.rawStore = rawStore
        self.checkpoints = checkpoints
        self.log = log
    }

    /// Harvests one record group.
    ///
    /// - Parameters:
    ///   - plan: which group, at what depth.
    ///   - refresh: discard any existing store and checkpoint and start over.
    ///   - byteBudget: remaining bytes this run may fetch, across all groups. When it runs out the
    ///     group stops with a checkpoint and `state == .budgetExhausted`, which is a *successful*
    ///     partial run — re-running continues from there.
    /// - Returns: the outcome, and the bytes consumed (for the caller's running budget).
    public func harvest(
        plan: RecordGroupPlan,
        refresh: Bool,
        byteBudget: Int?
    ) async throws -> RecordGroupHarvestOutcome {

        if refresh {
            try rawStore.reset(recordGroup: plan.number)
            try checkpoints.reset(recordGroup: plan.number)
        }

        log("[RecordGroupCatalogGenerator] RG \(plan.number): listing shards…")
        let shards = try await client.listDescriptionShards(recordGroup: plan.number)
        let snapshot = shards.first?.lastModified
        let totalBytes = shards.reduce(0) { $0 + $1.size }
        // Logged before the first fetch, not after the 25th. A fresh RG 59 pass is 400 shards and
        // 17.2 GB; silence until shard 25 reads as a hung process, and the operator has no way to
        // know how much is coming.
        log("[RecordGroupCatalogGenerator] RG \(plan.number): \(shards.count) shards, "
            + "\(Self.formatBytes(totalBytes)) to stream at depth '\(plan.depth.rawValue)'")
        var outcome = RecordGroupHarvestOutcome(
            recordGroup: plan.number, depth: plan.depth,
            shardsListed: shards.count, snapshotLastModified: snapshot)

        // Resume decision.
        var startAfterShardIndex = 0
        var recordsStored = 0
        var cumulativeBytes = 0
        if let existing = checkpoints.load(recordGroup: plan.number) {
            switch existing.resumability(depth: plan.depth, shardCount: shards.count) {
            case .complete:
                log("[RecordGroupCatalogGenerator] RG \(plan.number): already complete "
                    + "(\(existing.recordsWritten) records) — skipping")
                outcome.recordsStored = existing.recordsWritten
                outcome.state = .resumedComplete
                return outcome
            case .resume(let after):
                startAfterShardIndex = after
                recordsStored = existing.recordsWritten
                cumulativeBytes = existing.bytesRead
                // Discard any partial tail from a shard that was interrupted mid-write, so re-reading
                // it replaces those records instead of duplicating them.
                if let recorded = existing.ndjsonByteLength {
                    let actual = rawStore.byteLength(recordGroup: plan.number)
                    if actual > recorded {
                        try rawStore.truncate(recordGroup: plan.number, to: recorded)
                        log("[RecordGroupCatalogGenerator] RG \(plan.number): discarded "
                            + "\(actual - recorded) bytes of a partially-written shard before resuming")
                    }
                }
                log("[RecordGroupCatalogGenerator] RG \(plan.number): resuming after shard "
                    + "\(after)/\(shards.count) (\(recordsStored) records already stored)")
            case let refusal:
                log("[RecordGroupCatalogGenerator] ✗ RG \(plan.number): "
                    + (refusal.refusalMessage ?? "checkpoint refused"))
                outcome.state = .refused
                return outcome
            }
        }

        let writer = try rawStore.openWriter(recordGroup: plan.number)
        defer { try? writer.close() }

        var malformed = 0
        var malformedExamples: [String] = []
        var bytesThisRun = 0
        var shardsThisRun = 0

        for shard in shards where shard.shardIndex > startAfterShardIndex {
            if let byteBudget, bytesThisRun >= byteBudget {
                log("[RecordGroupCatalogGenerator] RG \(plan.number): byte budget reached at shard "
                    + "\(shard.shardIndex)/\(shards.count) — checkpointed, re-run to continue")
                outcome.state = .budgetExhausted
                break
            }

            let bytes = try await client.streamRecords(
                shard: shard,
                onMalformedLine: { line, error in
                    malformed += 1
                    if malformedExamples.count < Self.malformedExampleCap {
                        malformedExamples.append("\(shard.key):\(line): \(error)")
                    }
                },
                body: { record in
                    let level = record["levelOfDescription"]?.nonEmptyString
                    // The group's own node is kept regardless of depth: it carries the
                    // authoritative title and NARA's own `seriesCount`, which is the completeness
                    // check. Dropping it here would mean the build phase had nothing to check
                    // against.
                    guard level == "recordGroup" || plan.depth.admits(level) else { return }
                    try writer.append(record)
                    recordsStored += 1
                })

            bytesThisRun += bytes
            cumulativeBytes += bytes
            shardsThisRun += 1

            // Flush before recording the store's length, or the checkpoint would name a length the
            // file has not actually reached and a later resume would truncate real records away.
            try writer.flush()
            try checkpoints.save(HarvestCheckpoint(
                recordGroup: plan.number, depth: plan.depth,
                lastCompletedShardIndex: shard.shardIndex, shardCount: shards.count,
                recordsWritten: recordsStored, bytesRead: cumulativeBytes,
                snapshotLastModified: snapshot,
                ndjsonByteLength: rawStore.byteLength(recordGroup: plan.number)))

            // Log the first shard too, so progress is visible immediately rather than at shard 25.
            if shardsThisRun == 1 || shardsThisRun % 25 == 0 || shard.shardIndex == shards.count {
                log("[RecordGroupCatalogGenerator] RG \(plan.number): shard "
                    + "\(shard.shardIndex)/\(shards.count), \(recordsStored) records, "
                    + "\(Self.formatBytes(cumulativeBytes))")
            }
        }

        outcome.shardsRead = shardsThisRun
        outcome.bytesRead = bytesThisRun
        outcome.recordsStored = recordsStored
        outcome.malformedLines = malformed
        outcome.malformedExamples = malformedExamples
        if outcome.state == .complete {
            log("[RecordGroupCatalogGenerator] RG \(plan.number): complete — \(recordsStored) "
                + "records from \(shards.count) shards (\(Self.formatBytes(cumulativeBytes)))")
        }
        return outcome
    }

    /// Human-readable byte count for progress lines.
    static func formatBytes(_ bytes: Int) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var unit = 0
        while value >= 1024, unit < units.count - 1 {
            value /= 1024
            unit += 1
        }
        return unit == 0 ? "\(bytes) B" : String(format: "%.1f %@", value, units[unit])
    }
}
