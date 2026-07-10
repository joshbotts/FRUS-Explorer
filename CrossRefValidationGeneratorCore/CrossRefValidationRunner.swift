// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import CrossRefKit
import GeneratorKit

/// Validates every `<ref target>` across the local FRUS corpus and writes three artifacts:
///
///   - `broken-refs-report.csv` — the OH-submittable spreadsheet (one row per broken ref, sorted
///     by source volume then line, with precise location);
///   - `broken-refs-report.json` — the machine copy with aggregate metadata + full records;
///   - `broken-refs-index.json` — the *candidate* bundled exclusion index for Session 7 (compact
///     composite-keyed records; the runner prints its measured size and which detail branch it took).
///
/// Entirely offline and deterministic (filename-sorted scan + explicit record sorts + sorted JSON
/// keys). Adds no app coupling: nothing is written into the app bundle or `project.yml` — that
/// wiring, and the `is_broken` retroactive update, are Session 7's job.
///
/// Configuration (environment variables):
/// - `VOLUMES_DIR` — corpus directory of `*.xml` files (default `/Users/jbotts/Development/frus/volumes`)
/// - `MANIFEST` — app manifest path, defines the shippable series set (default `FRUSExplorer/Resources/manifest.json`)
/// - `OUTPUT_DIR` — directory for the three artifacts (default `Planning/cross-ref-validation`)
/// - `GENERATED_DATE` — override the `generated` stamp (default: today, `yyyy-MM-dd`)
public enum CrossRefValidationRunner {

    /// The composite-key bundled index stays full-detail while it fits under this many bytes; above
    /// it, the runner drops `rv`/`ra` to the compact exclusion-key-only form (the full detail
    /// remains in `broken-refs-report.json`).
    static let bundledSizeThreshold = 1_500_000

    /// Entry point: reads configuration from the environment, then runs the validation.
    public static func run() throws {
        let env = ProcessInfo.processInfo.environment
        try run(volumesDir: URL(fileURLWithPath: env["VOLUMES_DIR"] ?? "/Users/jbotts/Development/frus/volumes"),
                manifestPath: env["MANIFEST"] ?? "FRUSExplorer/Resources/manifest.json",
                outputDir: URL(fileURLWithPath: env["OUTPUT_DIR"] ?? "Planning/cross-ref-validation"),
                generated: generatorDateStamp(override: env["GENERATED_DATE"]))
    }

    /// The parameterized run, callable directly from tests without touching the environment.
    ///
    /// - Parameters:
    ///   - volumesDir: Corpus directory of `*.xml` files.
    ///   - manifestPath: App manifest path (defines the shippable series set).
    ///   - outputDir: Directory to write the three artifacts (created if absent).
    ///   - generated: The `generated` date stamp.
    public static func run(volumesDir: URL, manifestPath: String, outputDir: URL, generated: String) throws {
        let files = try VolumeCorpusEnumerator.volumeFiles(in: volumesDir)
        guard !files.isEmpty else { throw GeneratorError.noVolumes(volumesDir.path) }

        let manifestURL = URL(fileURLWithPath: manifestPath)
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw GeneratorError.missingFile(manifestPath)
        }
        let manifest = try ManifestLoader.load(from: manifestURL)
        let seriesVolumeIds = Set(manifest.map(\.volumeId))
        generatorLog("Manifest: \(seriesVolumeIds.count) series volumes; corpus: \(files.count) files")

        // MARK: Pass A — xml:id inventory for every corpus volume.
        var inventories: [String: Set<String>] = [:]
        inventories.reserveCapacity(files.count)
        var totalIds = 0
        for (index, file) in files.enumerated() {
            let volumeId = VolumeCorpusEnumerator.volumeId(for: file)
            guard let data = try? Data(contentsOf: file) else { continue }
            let ids = AnchorInventory.xmlIds(in: data)
            inventories[volumeId] = ids
            totalIds += ids.count
            if (index + 1) % 100 == 0 { generatorLog("  Pass A: \(index + 1)/\(files.count) volumes") }
        }
        let corpusVolumeIds = Set(inventories.keys)
        generatorLog("Pass A complete: \(totalIds) xml:ids across \(corpusVolumeIds.count) volumes")

        // MARK: Pass B + C — harvest refs and validate each.
        let validator = CrossRefValidator(inventories: inventories,
                                          corpusVolumeIds: corpusVolumeIds,
                                          seriesVolumeIds: seriesVolumeIds)
        var broken: [BrokenRef] = []
        var totalRefs = 0
        var reasonCounts: [BrokenRefReason: Int] = [:]
        var externalCount = 0, wholeVolumeCount = 0, resolvedCount = 0, notInSnapshotCount = 0
        var nonShippableTargets: [String: Int] = [:]

        for (index, file) in files.enumerated() {
            let volumeId = VolumeCorpusEnumerator.volumeId(for: file)
            let filename = file.lastPathComponent
            guard let data = try? Data(contentsOf: file) else { continue }
            let refs = RefHarvester.harvest(from: data)
            totalRefs += refs.count
            for ref in refs {
                switch validator.validate(ref, sourceVolume: volumeId, sourceFilename: filename) {
                case .resolved:            resolvedCount += 1
                case .external:            externalCount += 1
                case .wholeVolumeRef:      wholeVolumeCount += 1
                case .volumeNotInSnapshot: notInSnapshotCount += 1
                case .nonShippable(let v): nonShippableTargets[v, default: 0] += 1
                case .broken(let record):
                    broken.append(record)
                    reasonCounts[record.reason, default: 0] += 1
                }
            }
            if (index + 1) % 100 == 0 { generatorLog("  Pass B/C: \(index + 1)/\(files.count) volumes, \(broken.count) broken so far") }
        }

        // Deterministic order: source volume, then line, then byte offset.
        broken.sort {
            if $0.sourceVolume != $1.sourceVolume { return $0.sourceVolume < $1.sourceVolume }
            if $0.line != $1.line { return $0.line < $1.line }
            return $0.charOffset < $1.charOffset
        }

        let unknownVolumeIds = Set(broken.filter { $0.reason == .unknownVolume }
                                    .compactMap(\.resolvedVolume)).sorted()
        let nonShippableVolumeIds = nonShippableTargets.keys.sorted()
        let nonShippableRefCount = nonShippableTargets.values.reduce(0, +)

        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        // MARK: Report JSON (repo-committed, OH-submittable machine copy).
        let report = CrossRefValidationReport(
            schemaVersion: 1,
            generated: generated,
            generator: "CrossRefValidationGenerator",
            corpusVolumeCount: corpusVolumeIds.count,
            seriesVolumeCount: seriesVolumeIds.count,
            totalRefsScanned: totalRefs,
            totalBroken: broken.count,
            totalsByReason: Dictionary(uniqueKeysWithValues: reasonCounts.map { ($0.key.rawValue, $0.value) }),
            informationalCounts: [
                "external": externalCount,
                "wholeVolumeRef": wholeVolumeCount,
                "resolved": resolvedCount,
                "volumeNotInSnapshot": notInSnapshotCount,
            ],
            unknownVolumeIds: unknownVolumeIds,
            nonShippableVolumeRefCount: nonShippableRefCount,
            nonShippableVolumeIds: nonShippableVolumeIds,
            records: broken)

        let reportEncoder = JSONEncoder()
        reportEncoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try reportEncoder.encode(report)
            .write(to: outputDir.appendingPathComponent("broken-refs-report.json"))

        // MARK: Report CSV (the OH-facing spreadsheet).
        let header = ["source_volume", "source_document", "line", "char_offset",
                      "raw_target", "reason", "resolved_volume", "resolved_anchor", "source_filename"]
        let rows = broken.map { r in
            [r.sourceVolume, r.sourceDocument ?? "", String(r.line), String(r.charOffset),
             r.rawTarget, r.reason.rawValue, r.resolvedVolume ?? "", r.resolvedAnchor ?? "", r.sourceFilename]
        }
        try Data(CSVWriter.document(header: header, rows: rows).utf8)
            .write(to: outputDir.appendingPathComponent("broken-refs-report.csv"))

        // MARK: Bundled index (candidate for Session 7) with measured size-threshold branch.
        try writeBundledIndex(broken: broken, generated: generated,
                              corpusVolumeCount: corpusVolumeIds.count,
                              seriesVolumeCount: seriesVolumeIds.count,
                              to: outputDir.appendingPathComponent("broken-refs-index.json"))

        generatorLog("""

        cross-reference validation complete → \(outputDir.path)
          refs scanned:      \(totalRefs)
          broken:            \(broken.count)  \(reasonSummary(reasonCounts))
          informational:     external \(externalCount) · wholeVolume \(wholeVolumeCount) · notInSnapshot \(notInSnapshotCount) · resolved \(resolvedCount)
          non-shippable:     \(nonShippableRefCount) refs → \(nonShippableVolumeIds.count) volumes \(nonShippableVolumeIds.isEmpty ? "" : "(\(nonShippableVolumeIds.joined(separator: ", ")))")
          unknown volumes:   \(unknownVolumeIds.isEmpty ? "none" : unknownVolumeIds.joined(separator: ", "))
        """)
    }

    // MARK: - Bundled index writer

    private static func writeBundledIndex(broken: [BrokenRef], generated: String,
                                          corpusVolumeCount: Int, seriesVolumeCount: Int,
                                          to url: URL) throws {
        func records(fullDetail: Bool) -> [BrokenRefsIndexRecord] {
            broken.map {
                BrokenRefsIndexRecord(sv: $0.sourceVolume,
                                      sd: $0.sourceDocument ?? "",
                                      t: $0.rawTarget,
                                      r: $0.reason.rawValue,
                                      rv: fullDetail ? $0.resolvedVolume : nil,
                                      ra: fullDetail ? $0.resolvedAnchor : nil)
            }.sorted {
                if $0.sv != $1.sv { return $0.sv < $1.sv }
                if $0.sd != $1.sd { return $0.sd < $1.sd }
                return $0.t < $1.t
            }
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]

        func encoded(fullDetail: Bool) throws -> Data {
            let index = BrokenRefsIndex(schemaVersion: 1, generated: generated,
                                        corpusVolumeCount: corpusVolumeCount,
                                        seriesVolumeCount: seriesVolumeCount,
                                        totalBroken: broken.count,
                                        fullDetail: fullDetail,
                                        records: records(fullDetail: fullDetail))
            return try encoder.encode(index)
        }

        var data = try encoded(fullDetail: true)
        var fullDetail = true
        if data.count > bundledSizeThreshold {
            data = try encoded(fullDetail: false)
            fullDetail = false
        }
        try data.write(to: url)
        generatorLog("  bundled index: \(data.count) bytes (\(fullDetail ? "full-detail" : "compact — rv/ra dropped, threshold \(bundledSizeThreshold) exceeded"))")
    }

    private static func reasonSummary(_ counts: [BrokenRefReason: Int]) -> String {
        let parts = BrokenRefReason.allCases.compactMap { reason -> String? in
            guard let c = counts[reason], c > 0 else { return nil }
            return "\(reason.rawValue) \(c)"
        }
        return parts.isEmpty ? "" : "(" + parts.joined(separator: " · ") + ")"
    }
}
