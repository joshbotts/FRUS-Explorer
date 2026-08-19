// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import GeneratorKit
import SourceNoteKit

/// Builds the bundled `source-provenance-index.json` (SA-3a): parses every locally
/// downloaded FRUS volume's per-document source notes with the app's real
/// `SourceNoteParser`, maps each parse to a stable `ProvenanceCategory`, and aggregates
/// the counts by coverage decade (from the enriched `manifest.json` date ranges).
///
/// Schema 2 (#267) additionally emits `byVolume` — the per-volume breakdown this runner already
/// accumulated in order to count distinct volumes per decade, and then discarded. Every volume
/// belongs to exactly one coverage decade, so a decade bucket is the sum of its volumes and any
/// subset rolls up exactly; that is what lets SA-3 offer a real subseries scope instead of the
/// approximation Session 3 refused to ship.
///
/// Entirely offline and deterministic. Configuration (environment variables):
/// - `VOLUMES_DIR` — directory of volume `*.xml` files (default `/Users/jbotts/Development/frus/volumes`)
/// - `MANIFEST` — bundled manifest path (default `FRUSExplorer/Resources/manifest.json`)
/// - `OUTPUT` — output path (default `FRUSExplorer/Resources/source-provenance-index.json`)
/// - `GENERATED_DATE` — override the `generated` stamp (default: today, `yyyy-MM-dd`)
public enum SourceProvenanceIndexRunner {

    /// One decade's mutable accumulator.
    private struct DecadeAccumulator {
        var totalNotes = 0
        var volumeIds: Set<String> = []
        var counts: [ProvenanceCategory: Int] = [:]
    }

    /// Runs the generator.
    public static func run() throws {
        let env = ProcessInfo.processInfo.environment
        let volumesDir = URL(fileURLWithPath: env["VOLUMES_DIR"] ?? "/Users/jbotts/Development/frus/volumes")
        let manifestPath = env["MANIFEST"] ?? "FRUSExplorer/Resources/manifest.json"
        let outputPath = env["OUTPUT"] ?? "FRUSExplorer/Resources/source-provenance-index.json"
        let generated = generatorDateStamp(override: env["GENERATED_DATE"])

        // MARK: Load manifest → volumeId → coverage decade.
        let manifestData = try Data(contentsOf: URL(fileURLWithPath: manifestPath))
        let manifest = try JSONDecoder().decode([ManifestVolumeEntry].self, from: manifestData)
        var decadeByVolume: [String: Int] = [:]
        for entry in manifest {
            if let decade = coverageDecade(for: entry.dateRange) {
                decadeByVolume[entry.volumeId] = decade
            }
        }
        generatorLog("Loaded manifest: \(manifest.count) entries, \(decadeByVolume.count) with a coverage decade")

        // MARK: Iterate every volume XML.
        let xmls = try VolumeCorpusEnumerator.volumeFiles(in: volumesDir)
        guard !xmls.isEmpty else { throw GeneratorError.noVolumes(volumesDir.path) }

        let scan = build(xmls: xmls, decadeByVolume: decadeByVolume, generated: generated)
        let output = scan.index
        let totalNotes = output.totalSourceNotes
        let volumesCovered = output.volumesCovered
        let byDecade = output.byDecade
        let skippedNoDecade = scan.skippedNoDecade
        let skippedNoNotes = scan.skippedNoNotes

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(output).write(to: URL(fileURLWithPath: outputPath))

        generatorLog("""
        source-provenance-index.json written to \(outputPath)
          schema:               2 (byDecade + byVolume)
          volumes covered:      \(volumesCovered) / \(xmls.count)
          total source notes:   \(totalNotes)
          decades:              \(byDecade.count)
          skipped (no decade):  \(skippedNoDecade)
          skipped (no notes):   \(skippedNoNotes)
        """)
    }

    /// What one scan produced.
    public struct ScanResult: Sendable {
        /// The assembled artifact.
        public let index: SourceProvenanceIndex
        /// Volumes on disk with no manifest coverage decade.
        public let skippedNoDecade: Int
        /// Volumes with a decade but no source notes at all.
        public let skippedNoNotes: Int
    }

    /// Scans the given volume files and assembles the artifact.
    ///
    /// Split out of ``run()`` so the aggregation is callable from tests over a fixture corpus.
    /// Everything that decides what the artifact *says* lives here; `run()` only resolves paths,
    /// encodes, and logs.
    ///
    /// - Parameters:
    ///   - xmls: Volume files, in scan order (the caller sorts; the output is sorted regardless).
    ///   - decadeByVolume: Volume id → coverage decade, from the manifest. A volume absent from
    ///     this map is skipped — it is not in the shippable set.
    ///   - generated: The `generated` stamp to record.
    public static func build(xmls: [URL], decadeByVolume: [String: Int],
                             generated: String) -> ScanResult {
        let parser = SourceNoteParser()
        var accumulators: [Int: DecadeAccumulator] = [:]
        var volumeBuckets: [SourceProvenanceIndex.VolumeBucket] = []
        var totalNotes = 0
        var volumesCovered = 0
        var skippedNoDecade = 0
        var skippedNoNotes = 0

        for url in xmls {
            let volumeId = VolumeCorpusEnumerator.volumeId(for: url)
            guard let decade = decadeByVolume[volumeId] else {
                skippedNoDecade += 1
                continue
            }
            guard let data = try? Data(contentsOf: url) else { continue }
            let noteTexts = SourceNoteExtractor.extract(fromXML: data)
            guard !noteTexts.isEmpty else {
                skippedNoNotes += 1
                continue
            }

            var acc = accumulators[decade] ?? DecadeAccumulator()
            var volumeCounts: [ProvenanceCategory: Int] = [:]
            for text in noteTexts {
                let category = ProvenanceCategory.from(parser.parse(text))
                acc.counts[category, default: 0] += 1
                volumeCounts[category, default: 0] += 1
                acc.totalNotes += 1
            }
            acc.volumeIds.insert(volumeId)
            accumulators[decade] = acc
            volumeBuckets.append(SourceProvenanceIndex.VolumeBucket(
                volumeId: volumeId, decade: decade, totalNotes: noteTexts.count,
                counts: volumeCounts.reduce(into: [:]) { $0[$1.key.rawValue] = $1.value }))
            totalNotes += noteTexts.count
            volumesCovered += 1
        }

        // MARK: Assemble the output model.
        let byDecade = accumulators
            .sorted { $0.key < $1.key }
            .map { decade, acc -> SourceProvenanceIndex.DecadeBucket in
                var counts: [String: Int] = [:]
                for (category, count) in acc.counts where count > 0 {
                    counts[category.rawValue] = count
                }
                return SourceProvenanceIndex.DecadeBucket(
                    decade: decade,
                    totalNotes: acc.totalNotes,
                    volumeCount: acc.volumeIds.count,
                    counts: counts)
            }

        let output = SourceProvenanceIndex(
            schemaVersion: 2,
            generated: generated,
            totalSourceNotes: totalNotes,
            volumesCovered: volumesCovered,
            categories: ProvenanceCategory.orderedCases.map(\.rawValue),
            byDecade: byDecade,
            // Sorted by id, not by scan order: the scan is already filename-sorted, but stating
            // the sort makes the artifact's determinism a property of the writer rather than of
            // the directory listing.
            byVolume: volumeBuckets.sorted { $0.volumeId < $1.volumeId })

        return ScanResult(index: output, skippedNoDecade: skippedNoDecade,
                          skippedNoNotes: skippedNoNotes)
    }

    // MARK: - Helpers

    // #270: today()/log()/RunError were character-for-character duplicates of
    // GeneratorKit's generatorDateStamp/generatorLog/GeneratorError (identical format, locale,
    // UTC, stderr, and even the noVolumes message text). Duplicates that must stay identical
    // are the drift this migration removes; the writer is untouched, and the migration was
    // verified byte-identical by regenerating against the committed artifact under a pinned
    // GENERATED_DATE.
}
