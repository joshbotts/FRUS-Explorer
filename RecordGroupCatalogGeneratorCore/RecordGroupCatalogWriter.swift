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
/// | `series/rg_<N>.json` | ~165 MB total | **no** — regenerate; RG 59 alone is tens of MB |
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

    /// Writes one record group's index shard.
    @discardableResult
    public func writeShard(_ shard: RecordGroupIndexShard) throws -> Int {
        let data = try Self.compactEncoder.encode(shard)
        let url = seriesDirectory.appendingPathComponent("rg_\(shard.recordGroup).json")
        try data.write(to: url, options: .atomic)
        return data.count
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
        struct Sample: Codable {
            let generated: String
            let sampleEvery: Int
            let totalRecords: Int
            let records: [HarvestedRecord]
        }
        let sample = Sample(generated: generated, sampleEvery: sampleEvery,
                            totalRecords: totalRecords, records: sampled)
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
        line("Export snapshot: \(manifest.source.snapshotLastModified.joined(separator: ", "))")
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
