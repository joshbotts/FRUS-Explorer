// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import GeneratorKit

// MARK: - RecordGroupCatalogWriter

/// Writes every artifact this generator produces, deterministically.
///
/// ## What is committed and what is not
/// Following the precedent of `Planning/source-explorer-export/` (whose 182 MB full export is
/// gitignored while its summary and sample are committed) and `Planning/cross-ref-validation/`:
///
/// | Artifact | Size | Committed |
/// |---|---|---|
/// | `manifest.json` | ~40 KB | yes — the provenance and self-assessment |
/// | `census/*.csv` | ~100 KB–1 MB | yes — the field, value, control-number and creator inventories |
/// | `harvest-report.txt` | ~10 KB | yes — the human review block |
/// | `series/rg_<N>.json` | **~4.5 GB total** at `seriesAndFileUnits` | **no** — regenerate; `rg_59.json` alone is **3.56 GB** |
/// | `series-sample.json` | ~1 MB | yes — every Nth record, so the shape is reviewable in a diff |
/// | `creators/creator-authority.json` | a few MB | yes — small, and the creator prose is the point |
///
/// ## Determinism
/// Every encoder sets `.sortedKeys`, every emitted collection is explicitly sorted, and the
/// `generated` stamp is passed in rather than read from the clock. This is what allows the
/// end-to-end test to run the whole pipeline twice and compare bytes — the only form of the check
/// that catches dictionary-iteration order leaking out of a census.
///
/// Version history:
///   1.0 — Session 2026-07-29: initial implementation
public struct RecordGroupCatalogWriter: Sendable {

    /// Root output directory.
    public let outputDirectory: URL
    /// Sampling interval for the committed record sample.
    public let sampleEvery: Int

    /// Hard ceiling on records in the committed sample.
    ///
    /// A fixed *interval* does not bound a committed artifact. At series-only depth, 1-in-25 of 20,188
    /// records was ~800 records and about 1 MB. At file-unit depth the same interval selected 30,075 of
    /// 751,880 much larger records and produced a **250 MB** file — which would have gone into git,
    /// since the sample is committed by design. The interval still decides *which* records are
    /// candidates; this decides how many survive.
    public static let sampleCap = 500

    /// Human-facing JSON: pretty-printed so a reviewer can read a diff.
    static let prettyEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    /// Bulk JSON: compact, because the index shards are large and nobody reads them by eye.
    static let compactEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    public init(outputDirectory: URL, sampleEvery: Int = 25) {
        self.outputDirectory = outputDirectory
        self.sampleEvery = max(1, sampleEvery)
    }

    // MARK: Paths

    public var seriesDirectory: URL { outputDirectory.appendingPathComponent("series") }
    public var censusDirectory: URL { outputDirectory.appendingPathComponent("census") }
    public var creatorsDirectory: URL { outputDirectory.appendingPathComponent("creators") }
    public var manifestURL: URL { outputDirectory.appendingPathComponent("manifest.json") }
    public var reportURL: URL { outputDirectory.appendingPathComponent("harvest-report.txt") }
    public var sampleURL: URL { outputDirectory.appendingPathComponent("series-sample.json") }

    /// Creates the output tree.
    public func prepare() throws {
        for directory in [outputDirectory, seriesDirectory, censusDirectory, creatorsDirectory] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    // MARK: Index shards

    /// Whether a shard already exists for this group.
    public func shardExists(recordGroup: Int) -> Bool {
        FileManager.default.fileExists(
            atPath: seriesDirectory.appendingPathComponent("rg_\(recordGroup).json").path)
    }

    /// Errors the shard writer can raise.
    public enum ShardWriteError: Error, Equatable {
        /// The `"records":[]` marker did not occur exactly once in the empty-records skeleton, so
        /// the split point is not decidable.
        ///
        /// **This cannot be triggered by data, and that is worth knowing rather than assuming.** A
        /// `title` set to the literal `records":[]` was tried and did *not* collide: JSON escapes
        /// the embedded quote, so the encoded form is `records\":[]` and the marker stays unique.
        /// What the guard actually protects against is a change to ``compactEncoder``'s
        /// `outputFormatting` — `.prettyPrinted` emits `"records" : []`, which matches **zero**
        /// times, and without this guard the writer would happily produce a truncated shard. The
        /// zero case is the reachable one.
        case ambiguousRecordsMarker(occurrences: Int)
    }

    /// Path for a shard's **staging** file — written during the encode, swapped in only on success.
    ///
    /// The extension is `.json.partial`, and that is load-bearing rather than cosmetic. Three
    /// generators enumerate this directory, and two of them filter on `pathExtension == "json"`
    /// with **no `rg_` prefix guard** (`SeriesFactsIndexRunner.swift:429`,
    /// `AccessionSeriesIndexRunner.swift:211`; only `LotClaimantsIndexRunner.swift:96` checks the
    /// prefix). Worse, `AccessionSeriesIndexRunner.swift:218-220` derives the record group from the
    /// file *name*, so a staging file called `rg_59.tmp.json` would be read as record group
    /// `"59.tmp"` and would silently corrupt every key in a shipped artifact. The `pathExtension`
    /// of `rg_59.json.partial` is `partial`, which all three filters skip.
    func stagingURL(recordGroup: Int) -> URL {
        seriesDirectory.appendingPathComponent("rg_\(recordGroup).json.partial")
    }

    /// Splits an empty-records skeleton into the bytes that go before and after the record list.
    ///
    /// Extracted so the guard below is reachable from a test. Left inline it was **provably
    /// untestable**: `occurrences` is always exactly 1 for any shard, because a string value that
    /// contained the marker would have its quotes escaped — a mutation weakening the guard survived
    /// a nine-mutation sweep for precisely that reason. Given a skeleton this function can be handed
    /// one the encoder would never produce, which is the case worth guarding.
    ///
    /// - Parameter emptyRecordsSkeleton: a shard encoded with `records == []`.
    /// - Returns: the bytes up to and including `[`, and the bytes from `]` onward.
    /// - Throws: ``ShardWriteError/ambiguousRecordsMarker(occurrences:)`` when the marker does not
    ///   occur exactly once — which is what happens if `compactEncoder`'s `outputFormatting` ever
    ///   gains `.prettyPrinted`, since that emits `"records" : []` and matches **zero** times.
    static func split(emptyRecordsSkeleton bytes: Data) throws -> (Data, Data) {
        let marker = Data("\"records\":[]".utf8)
        var occurrences = 0
        var markerStart: Data.Index?
        var search = bytes.startIndex..<bytes.endIndex
        while let found = bytes.range(of: marker, in: search) {
            occurrences += 1
            if markerStart == nil { markerStart = found.lowerBound }
            search = found.upperBound..<bytes.endIndex
        }
        guard occurrences == 1, let markerStart else {
            throw ShardWriteError.ambiguousRecordsMarker(occurrences: occurrences)
        }
        // Split BETWEEN the `[` and the `]`, so the empty-records case emits `[]` with no separator
        // and needs no special branch.
        let split = markerStart + marker.count - 1
        return (bytes[bytes.startIndex..<split], bytes[split..<bytes.endIndex])
    }

    /// Writes one record group's index shard, one record at a time.
    ///
    /// ## Why this does not encode the shard whole
    /// `JSONEncoder.encode(shard)` builds an intermediate representation for every record before a
    /// byte reaches disk, then materialises the finished bytes as one `Data`. Measured on these
    /// types against three shipped shards, that transient is **3.98–5.09× the output size**:
    ///
    /// | shard | JSON out | records array | peak, whole encode | peak, streamed | ratio |
    /// |---|---|---|---|---|---|
    /// | `rg_239` | 78.3 MiB | 197.1 MiB | 474.4 MiB | 200.8 MiB | 2.36× |
    /// | `rg_469` | 163.1 MiB | 728.3 MiB | 1,558.6 MiB | 728.7 MiB | 2.14× |
    /// | `rg_306` | 212.5 MiB | 830.6 MiB | 1,799.2 MiB | 831.6 MiB | 2.16× |
    /// | `rg_84` | 293.3 MiB | 1,004.9 MiB | 2,171.1 MiB | 1,011.8 MiB | 2.15× |
    ///
    /// A **2.14–2.36× cut in peak footprint**. The streamed peak lands within **0.7–6.9 MiB** of
    /// the resident records array, which is the claim that matters: the transient really is one
    /// record, not one shard.
    ///
    /// **Measure one arm per process.** Taking both in sequence understates the win badly — malloc
    /// does not return the first arm's high-water mark to the OS, so the streamed peak inherits it
    /// and `rg_306` reads 1.43× instead of 2.16×. `phys_footprint` sampled at 0.3 ms; the input
    /// shard mapped `.alwaysMapped` so file pages are not charged.
    ///
    /// ## What this does NOT fix, stated because the plan row claimed otherwise
    /// The records array stays resident, and it must: ``RecordGroupIndexShard/init`` sorts by NAID
    /// for a stable diff, and `RecordGroupCatalogRunner` walks the sorted array *after* this
    /// returns to build `series-sample.json`. At a measured 3.4–4.4× the output bytes that array is
    /// the other half of the peak, and it is linear in the group's size. Applying the measured ratio
    /// to CLAUDE.md's ~18.5 GB full-build figure gives roughly **8.6 GB — a 53% cut, not a fix** —
    /// though treat that as an extrapolation and not a measurement: `rg_59.json` is 3,394 MiB,
    /// twelve times the largest shard measured above, and it could not be run here because the raw
    /// store this generator harvests into no longer exists. **`DEPTH=all` is still not finishable.**
    /// Removing the array needs an external sort over spilled per-record blobs — retain
    /// `(naId, offset, length)` per record, sort the keys, copy blobs in order — which makes peak
    /// independent of group size and is a different, larger piece of work.
    ///
    /// ## Why the bytes cannot drift
    /// The prologue and epilogue are **not hand-written**. The shard is encoded once with an empty
    /// records array through the same ``compactEncoder``, and that skeleton is split at its literal
    /// `"records":[]`. So `.sortedKeys` ordering, the omission of a nil `title`, number formatting
    /// and every escaping rule are decided by the encoder that produced today's artifacts — and stay
    /// decided by it if a field is ever added to the shard header. Every conformance in the shard
    /// tree is synthesized (no `CodingKeys`, no custom `encode(to:)` anywhere under
    /// `HarvestedRecord`), so encoding one record yields exactly the bytes the array encode would
    /// have produced for that element.
    ///
    /// ## Atomicity is preserved, and its loss would have been quiet
    /// The previous `.atomic` write is what made a crash mid-write leave the last good shard
    /// intact, and the runner's materially-short guard above depends on that. A truncated shard
    /// does not fail its consumers loudly: `SeriesFactsIndexRunner` throws only when creators
    /// resolve to *zero* and `AccessionSeriesIndexRunner` only when the map is *empty*, so a 60%
    /// shard yields a 60% artifact and exit 0. Hence the stage-then-rename below, the same shape
    /// `RecordGroupHarvester.openStagingWriter` uses sixty lines away.
    ///
    /// - Returns: the number of bytes actually written, which the runner prints in its log line.
    @discardableResult
    public func writeShard(_ shard: RecordGroupIndexShard) throws -> Int {
        var skeleton = shard
        skeleton.records = []
        let skeletonBytes = try Self.compactEncoder.encode(skeleton)
        let (prologue, epilogue) = try Self.split(emptyRecordsSkeleton: skeletonBytes)

        let url = seriesDirectory.appendingPathComponent("rg_\(shard.recordGroup).json")
        let staging = stagingURL(recordGroup: shard.recordGroup)
        if FileManager.default.fileExists(atPath: staging.path) {
            try FileManager.default.removeItem(at: staging)
        }
        FileManager.default.createFile(atPath: staging.path, contents: nil)
        let handle = try FileHandle(forWritingTo: staging)

        var written = 0
        do {
            try handle.write(contentsOf: prologue)
            written += prologue.count
            let separator = Data(",".utf8)
            for (offset, record) in shard.records.enumerated() {
                if offset > 0 {
                    try handle.write(contentsOf: separator)
                    written += separator.count
                }
                let encoded = try Self.compactEncoder.encode(record)
                try handle.write(contentsOf: encoded)
                written += encoded.count
            }
            try handle.write(contentsOf: epilogue)
            written += epilogue.count
            try handle.synchronize()
            try handle.close()
        } catch {
            // Leave the previous good shard in place, and leave no `.partial` behind for an
            // operator to mistake for a live file.
            try? handle.close()
            try? FileManager.default.removeItem(at: staging)
            throw error
        }

        // The swap is inside the same failure discipline as the write: a throwing `moveItem` would
        // otherwise leave the previous good shard in place (correct) but strand a `.partial` an
        // operator cannot distinguish from a live staging file (not correct).
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            try FileManager.default.moveItem(at: staging, to: url)
        } catch {
            try? FileManager.default.removeItem(at: staging)
            throw error
        }
        return written
    }

    /// Writes the committed sample.
    ///
    /// Takes records **already sampled** by the caller rather than the full corpus. The earlier
    /// signature accepted every projected record of every group and filtered here, which meant the
    /// runner had to retain the whole run in memory — fine for 20,000 series, but it contradicted the
    /// "peak memory is one group's projection" property and would have been ruinous at `DEPTH=all` on
    /// RG 59.
    ///
    /// - Parameters:
    ///   - sampled: every ``sampleEvery``-th record, in group then NAID order.
    ///   - totalRecords: how many records the sample was drawn from.
    public func writeSample(_ sampled: [HarvestedRecord], totalRecords: Int,
                            generated: String) throws {
        // Sub-sample evenly rather than truncating, so the file stays a cross-section of the whole
        // corpus instead of the first 500 records of the lowest-numbered record group.
        let capped: [HarvestedRecord]
        if sampled.count > Self.sampleCap {
            let stride = Double(sampled.count) / Double(Self.sampleCap)
            capped = (0..<Self.sampleCap).map { sampled[Int(Double($0) * stride)] }
        } else {
            capped = sampled
        }

        struct Sample: Codable {
            let generated: String
            let sampleEvery: Int
            let totalRecords: Int
            /// Records actually written, after ``RecordGroupCatalogWriter/sampleCap``.
            let sampledRecords: Int
            let records: [HarvestedRecord]
        }
        let sample = Sample(generated: generated, sampleEvery: sampleEvery,
                            totalRecords: totalRecords, sampledRecords: capped.count,
                            records: capped)
        try Self.prettyEncoder.encode(sample).write(to: sampleURL, options: .atomic)
    }

    // MARK: Manifest

    /// Writes the manifest.
    public func writeManifest(_ manifest: RecordGroupCatalogManifest) throws {
        try Self.prettyEncoder.encode(manifest).write(to: manifestURL, options: .atomic)
    }

    // MARK: Creator authority

    /// Writes the creator-authority index.
    public func writeCreatorAuthority(_ index: CreatorAuthorityIndex) throws {
        try Self.prettyEncoder.encode(index)
            .write(to: creatorsDirectory.appendingPathComponent("creator-authority.json"),
                   options: .atomic)
    }

    // MARK: Censuses

    /// Writes all four census CSVs.
    public func writeCensuses(
        fieldCensus: FieldCensus,
        valueCensus: ValueCensus,
        controlNumberCensus: ControlNumberCensus,
        creatorCensus: CreatorCensus
    ) throws {
        try write(csv: CSVWriter.document(header: FieldCensus.csvHeader,
                                          rows: fieldCensus.csvRows()),
                  to: "field-census.csv")
        try write(csv: CSVWriter.document(header: ValueCensus.csvHeader,
                                          rows: valueCensus.csvRows()),
                  to: "value-census.csv")
        try write(csv: CSVWriter.document(header: ControlNumberCensus.crossTabHeader,
                                          rows: controlNumberCensus.crossTabRows()),
                  to: "control-number-census.csv")
        try write(csv: CSVWriter.document(header: ControlNumberCensus.typeSummaryHeader,
                                          rows: controlNumberCensus.typeSummaryRows()),
                  to: "control-number-types.csv")
        try write(csv: CSVWriter.document(header: CreatorCensus.csvHeader,
                                          rows: creatorCensus.csvRows()),
                  to: "creator-census.csv")
    }

    private func write(csv: String, to filename: String) throws {
        try Data(csv.utf8).write(to: censusDirectory.appendingPathComponent(filename),
                                options: .atomic)
    }

    // MARK: Report

    /// Writes the bulk-vs-refresh changelog.
    public func writeChangeLog(_ changeLog: RecordChangeLog) throws {
        try write(csv: CSVWriter.document(header: RecordChangeLog.csvHeader,
                                          rows: changeLog.csvRows()),
                  to: "refresh-changelog.csv")
    }

    /// Writes the human-readable report.
    public func writeReport(_ text: String) throws {
        try Data(text.utf8).write(to: reportURL, options: .atomic)
    }
}

// MARK: - HarvestReportBuilder

/// Renders the human-readable harvest report.
///
/// The report exists because the manifest is machine-shaped and a reviewer needs the three
/// questions answered at the top of a file: did every group finish, is anything materially short of
/// NARA's own count, and did the two priority fields actually arrive. Everything else is detail
/// below the fold.
///
/// Version history:
///   1.0 — Session 2026-07-29: initial implementation
public struct HarvestReportBuilder: Sendable {

    public init() {}

    /// Renders the report for a completed run.
    public func render(
        manifest: RecordGroupCatalogManifest,
        controlNumberCensus: ControlNumberCensus,
        creatorCensus: CreatorCensus,
        fieldCensus: FieldCensus,
        creatorAuthority: CreatorAuthorityHarvester.Result?,
        changeLog: RecordChangeLog? = nil,
        apiObservation: APIEnvelopeObservation? = nil
    ) -> String {
        var out = ""
        func line(_ s: String = "") { out += s + "\n" }
        func rule() { line(String(repeating: "─", count: 78)) }

        line("NARA Catalog — Record Group Catalog Harvest")
        line("Generated: \(manifest.generated)")
        line("Source: \(manifest.source.kind) — \(manifest.source.baseURL)")
        // An API harvest has no snapshot — it reads the live catalog — so an empty list is correct
        // here and must say so rather than trailing off after the colon.
        line("Export snapshot: " + (manifest.source.snapshotLastModified.isEmpty
                                    ? "(none — live API harvest)"
                                    : manifest.source.snapshotLastModified.joined(separator: ", ")))
        rule()

        // MARK: Headline
        let totals = manifest.totals
        line("RECORD GROUPS      \(totals.recordGroupCount)")
        // Only groups whose own node was read state a count, so the expected total is qualified by
        // how many groups it covers. Printing a bare sum would let "0" read as "NARA says there are
        // none" when it means "no group told us".
        let withKnownCount = manifest.recordGroups.filter { $0.expectedSeriesCount != nil }.count
        if withKnownCount == 0 {
            line("SERIES HARVESTED   \(totals.harvestedSeriesCount) "
                 + "(NARA's own count unknown — no record-group node was read)")
        } else if withKnownCount == totals.recordGroupCount {
            line("SERIES HARVESTED   \(totals.harvestedSeriesCount) "
                 + "(NARA states \(totals.expectedSeriesCount))")
        } else {
            line("SERIES HARVESTED   \(totals.harvestedSeriesCount) "
                 + "(NARA states \(totals.expectedSeriesCount) across "
                 + "\(withKnownCount) of \(totals.recordGroupCount) groups)")
        }
        if totals.harvestedFileUnitCount > 0 {
            line("FILE UNITS         \(totals.harvestedFileUnitCount)")
        }
        if totals.harvestedItemCount > 0 {
            line("ITEMS              \(totals.harvestedItemCount)")
        }
        line("BYTES READ         \(RecordGroupHarvester.formatBytes(totals.bytesRead)) "
             + "over \(totals.shardsRead) shards")
        rule()

        // MARK: The two priority payloads
        line("PRIORITY PAYLOADS")
        let seriesTotal = max(1, totals.harvestedSeriesCount + totals.harvestedFileUnitCount
                              + totals.harvestedItemCount)
        line(String(format: "  creators                 %d records (%.1f%%), %d distinct creators",
                    totals.recordsWithCreators,
                    Double(totals.recordsWithCreators) / Double(seriesTotal) * 100,
                    totals.distinctCreators))
        line(String(format: "  variantControlNumbers    %d records (%.1f%%), %d distinct types",
                    totals.recordsWithControlNumbers,
                    Double(totals.recordsWithControlNumbers) / Double(seriesTotal) * 100,
                    totals.distinctControlNumberTypes))
        let withContributors = manifest.recordGroups.map(\.recordsWithContributors).reduce(0, +)
        let withLocalId = manifest.recordGroups.map(\.recordsWithLocalIdentifier).reduce(0, +)
        line(String(format: "  contributors             %d records (%.1f%%)",
                    withContributors, Double(withContributors) / Double(seriesTotal) * 100))
        line(String(format: "  localIdentifier          %d records (%.1f%%) — agency-assigned, and "
                    + "NOT part of variantControlNumbers",
                    withLocalId, Double(withLocalId) / Double(seriesTotal) * 100))
        if let authority = creatorAuthority {
            line("  creator authority        \(authority.records.count) resolved, "
                 + "\(authority.unresolvedNaIds.count) unresolved")
        } else {
            line("  creator authority        not run (set CREATOR_AUTHORITY=1)")
        }
        rule()

        // MARK: Alias report — the schema tripwire
        line("FIELD ALIAS REPORT (which key spelling matched)")
        for entry in manifest.fieldAliasReport {
            let matched = entry.matchedAliases.keys.sorted()
                .map { "\($0)=\(entry.matchedAliases[$0] ?? 0)" }
                .joined(separator: " ")
            let flag = entry.matchedAliases.isEmpty && entry.required ? "  *** NO ALIAS MATCHED ***" : ""
            line("  \(entry.field.padding(toLength: 26, withPad: " ", startingAt: 0))"
                 + "\(matched.isEmpty ? "(none)" : matched)"
                 + "  presentButEmpty=\(entry.presentButEmpty) absent=\(entry.absent)\(flag)")
        }
        rule()

        // MARK: Per-group table
        line("PER-RECORD-GROUP")
        line("   RG  series  NARA  delta  creators  ctrlNums  state       title")
        for group in manifest.recordGroups {
            let expected = group.expectedSeriesCount.map(String.init) ?? "?"
            let delta = group.seriesCountDelta.map { $0 == 0 ? "0" : String(format: "%+d", $0) } ?? "?"
            let marker = group.isMateriallyShort ? " ⚠" : ""
            line("  \(String(group.recordGroup).leftPadded(to: 3))"
                 + "  \(String(group.harvestedSeriesCount).leftPadded(to: 6))"
                 + "  \(expected.leftPadded(to: 4))"
                 + "  \(delta.leftPadded(to: 5))"
                 + "  \(String(group.recordsWithCreators).leftPadded(to: 8))"
                 + "  \(String(group.recordsWithControlNumbers).leftPadded(to: 8))"
                 + "  \(group.state.rawValue.padding(toLength: 11, withPad: " ", startingAt: 0))"
                 + " \((group.title ?? "?").prefix(40))\(marker)")
        }
        rule()

        // MARK: Control-number types — the agency-specific inventory
        line("CONTROL-NUMBER TYPES (most frequent first; recordGroups shows spread)")
        for row in controlNumberCensus.typeSummaryRows().prefix(40) {
            line("  \(row[1].leftPadded(to: 7))  \(row[2].leftPadded(to: 3)) RG  "
                 + "\(row[0].prefix(46))")
        }
        if controlNumberCensus.typeSummaryRows().count > 40 {
            line("  … \(controlNumberCensus.typeSummaryRows().count - 40) more — see "
                 + "census/control-number-types.csv")
        }
        rule()

        // MARK: Review blocks
        let short = manifest.recordGroups.filter(\.isMateriallyShort)
        if !short.isEmpty {
            line("⚠ MATERIALLY SHORT OF NARA'S OWN SERIES COUNT")
            line("  A shortfall here is the signature of a truncated harvest, not of a small group.")
            for group in short {
                line("  RG \(group.recordGroup): \(group.harvestedSeriesCount) of "
                     + "\(group.expectedSeriesCount ?? 0) — state \(group.state.rawValue)")
            }
            rule()
        }

        // The file-unit self-check, for a depth that collected them.
        let fileUnitChecked = manifest.recordGroups.filter { $0.fileUnitCountDelta != nil }
        if !fileUnitChecked.isEmpty {
            line("FILE-UNIT COMPLETENESS (harvested vs NARA's own fileUnitCount)")
            for group in fileUnitChecked {
                let delta = group.fileUnitCountDelta ?? 0
                line("  RG \(group.recordGroup): \(group.harvestedFileUnitCount) harvested vs "
                     + "\(group.expectedFileUnitCount ?? 0) stated"
                     + (delta == 0 ? "  ✓" : String(format: "  (%+d)", delta)))
            }
            rule()
        }

        let over = manifest.recordGroups.filter { ($0.seriesCountDelta ?? 0) > 0 }
        if !over.isEmpty {
            line("⚠ MORE SERIES THAN NARA'S OWN COUNT")
            line("  Either NARA's seriesCount is stale, or records were counted twice. Check the")
            line("  duplicateRecord row in the invariant block below before trusting the totals.")
            for group in over {
                line("  RG \(group.recordGroup): \(group.harvestedSeriesCount) harvested vs "
                     + "\(group.expectedSeriesCount ?? 0) stated (+\(group.seriesCountDelta ?? 0))")
            }
            rule()
        }

        // Tallied per group and, until a review caught it, never printed anywhere — so a harvest that
        // skipped forty thousand undecodable lines read as clean.
        let malformed = manifest.recordGroups.filter { $0.malformedLines > 0 }
        if !malformed.isEmpty {
            line("⚠ UNDECODABLE SOURCE LINES (skipped, and therefore missing from the index)")
            for group in malformed {
                line("  RG \(group.recordGroup): \(group.malformedLines) lines")
            }
            rule()
        }

        let withViolations = manifest.recordGroups.filter { !$0.invariantViolations.isEmpty }
        if !withViolations.isEmpty {
            line("INVARIANT VIOLATIONS (records refused, never silently accepted)")
            for group in withViolations {
                let counts = group.invariantViolations.keys.sorted()
                    .map { "\($0)=\(group.invariantViolations[$0] ?? 0)" }
                    .joined(separator: " ")
                line("  RG \(group.recordGroup): \(counts)")
                for example in group.invariantExamples.prefix(3) { line("      \(example)") }
            }
            rule()
        }

        let unprojected = manifest.recordGroups
            .flatMap { $0.unprojectedKeyCounts.map { ($0.key, $0.value) } }
            .reduce(into: [String: Int]()) { $0[$1.0, default: 0] += $1.1 }
        if !unprojected.isEmpty {
            line("UNPROJECTED RAW KEYS (present in the data, absent from the typed index)")
            line("  Not necessarily a problem — but a new key here means NARA's schema has moved.")
            for key in unprojected.keys.sorted() {
                line("  \(key) — \(unprojected[key] ?? 0) records")
            }
            rule()
        }

        if let changeLog {
            line("API REFRESH vs BULK SNAPSHOT")
            if changeLog.hasChanges {
                line("  added=\(changeLog.total(.added))  modified=\(changeLog.total(.modified))  "
                     + "unchanged=\(changeLog.total(.unchanged))  "
                     + "missingFromRefresh=\(changeLog.total(.missingFromRefresh))")
                if changeLog.total(.unchangedOutsideIndex) > 0 {
                    line("  \(changeLog.total(.unchangedOutsideIndex)) record(s) differed ONLY outside")
                    line("  the indexed fields — measured culprits are dataControlGroup's internal")
                    line("  reference-unit code and referenceUnits[].mailCode, neither of which the")
                    line("  index projects. Not counted as changes.")
                }
                line("  'missingFromRefresh' means present in the snapshot and absent from the")
                line("  refresh. That can be a withdrawal OR a narrower/truncated refresh query —")
                line("  this tool cannot tell which, so it does not claim to. See")
                line("  census/refresh-changelog.csv for the per-record list.")
                for row in changeLog.reportLines() { line(row) }
            } else {
                line("  no indexed field changed — the snapshot matches the live catalog for these")
                line("  groups")
                if changeLog.total(.unchangedOutsideIndex) > 0 {
                    line("  \(changeLog.total(.unchangedOutsideIndex)) record(s) differed outside the "
                         + "indexed fields only — incidental")
                    line("  catalog housekeeping (dataControlGroup's internal code, "
                         + "referenceUnits[].mailCode).")
                }
            }
            rule()
        }

        if let apiObservation {
            line("API QUERY SHAPE AS OBSERVED ON THIS RUN")
            for row in apiObservation.reportLines { line(row) }
            rule()
        }

        if !manifest.reviewNotes.isEmpty {
            line("NOTES")
            for note in manifest.reviewNotes { line("  • \(note)") }
            rule()
        }

        line("Field census: \(fieldCensus.paths.count) distinct key paths over "
             + "\(fieldCensus.recordCount) records — see census/field-census.csv")
        line("Creator census: \(creatorCensus.entries.count) distinct creators — "
             + "see census/creator-census.csv")

        return out
    }
}

// MARK: - String padding

extension String {
    /// Right-aligns to `width` for the report's fixed-width tables. Left as-is when already longer,
    /// so a wide value pushes the column rather than being truncated into ambiguity.
    func leftPadded(to width: Int) -> String {
        count >= width ? self : String(repeating: " ", count: width - count) + self
    }
}
