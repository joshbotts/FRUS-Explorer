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

// MARK: - LotClaimantsIndexRunner

/// Builds `lot-claimants-index.json`: every NARA series that claims a FRUS lot number, for the
/// lots where **more than one** does (#675 / N-8b).
///
/// ## What it is for
/// NARA rearranges records after they leave the originating agency — consolidating several lot
/// files into one series, and **dividing one lot file across several**. The bundled
/// `central-files-index.json` stores a single `naId` per lot, so wherever NARA divided a lot the
/// app names one series and silently drops the rest. Measured over the shipped bundle: **109
/// lots, 1,710 FRUS documents, up to 13 claiming series on a single lot** (`61D146`), and six
/// bundle rows collapse to the same naId — those citations are indistinguishable in the UI.
///
/// The defect is an *undisclosed* pick, not a wrong one. Every claimant is NARA's own assertion
/// (see `LotResolutionAcceptance`), so the fix is to carry them all and let Source Explorer show
/// them as candidates, which is the grammar #669 already ships.
///
/// ## Why this is a separate artifact
/// `central-files-index.json` is rebuilt by the keyed harvest, which replaces its whole `lotFiles`
/// array. A field added there would survive until the next run. This file is built **offline from
/// the record-group harvest** — no API key — and read alongside it, exactly as
/// `curated-lot-resolutions.json` is.
///
/// ## Why the generator is Swift rather than a script
/// It imports `LotResolutionAcceptance.foldControlNumber` and matches with the **shipped** rule.
/// Three separate analysis errors in this workstream came from measuring with a Python proxy that
/// tokenised differently from the code — one under-reported the defect by 3.9×, one missed NARA's
/// `Lot File NNNNN` spelling, one reported a prose scan as false-positive-free when it was not.
/// There is no second implementation here to drift.
///
/// Env: `HARVEST_DIR` (default `/Users/jbotts/Development/nara-record-group-catalog`),
/// `CENTRAL_FILES_INDEX`, `OUTPUT`, `GENERATED_DATE`.
///
/// Version history:
///   1.0 — Session 2026-08-05: #675 / N-8b
public enum LotClaimantsIndexRunner {

    /// One NARA series that claims a lot number.
    public struct Claimant: Codable, Sendable, Equatable {
        public let naId: String
        public let title: String
        public let recordGroup: String?
        public let hmsMlrEntryNumbers: [String]?
        public let dateRange: String?
        /// `"controlNumber"` or `"consolidationNote"` — which channel established the claim,
        /// so the app can say how it knows rather than asserting a flat resolution.
        public let evidence: String
    }

    /// Every claimant for one lot, in a stable order.
    public struct LotClaimants: Codable, Sendable {
        public let lotNumber: String
        public let claimants: [Claimant]
    }

    /// The emitted artifact.
    public struct Index: Codable, Sendable {
        public let schemaVersion: Int
        public let generated: String
        public let note: String
        /// Provenance of the harvest this was derived from.
        public let harvestGenerated: String?
        public let lots: [LotClaimants]
    }

    /// Current schema version.
    public static let currentSchemaVersion = 1

    /// Runs the generator.
    public static func run(environment: [String: String] = ProcessInfo.processInfo.environment) throws {
        let harvestDir = environment["HARVEST_DIR"]
            ?? "/Users/jbotts/Development/nara-record-group-catalog"
        let indexPath = environment["CENTRAL_FILES_INDEX"]
            ?? "FRUSExplorer/Resources/central-files-index.json"
        let outputPath = environment["OUTPUT"]
            ?? "FRUSExplorer/Resources/lot-claimants-index.json"

        let bundledLots = try bundledLotNumbers(at: indexPath)
        generatorLog("Bundled lots: \(bundledLots.count)")

        let seriesDir = URL(fileURLWithPath: harvestDir).appending(path: "series")
        let shards = try FileManager.default
            .contentsOfDirectory(at: seriesDir, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("rg_") && $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }   // deterministic
        guard !shards.isEmpty else { throw GeneratorError.missingFile(seriesDir.path) }
        generatorLog("Shards: \(shards.count)")

        // lot key -> claimants, accumulated across every shard.
        var byLot: [String: [Claimant]] = [:]
        var harvestGenerated: String?
        for shard in shards {
            let (records, generated) = try HarvestShardReader.read(shard)
            harvestGenerated = harvestGenerated ?? generated
            for record in records {
                guard record.levelOfDescription != LotResolutionAcceptance.fileUnitLevel else { continue }
                for lot in bundledLots {
                    guard let evidence = LotResolutionAcceptance.evidence(
                        recordGroup: record.recordGroupNumber ?? "",
                        normalizedLot: lot,
                        candidateRecordGroup: record.recordGroupNumber,
                        levelOfDescription: record.levelOfDescription,
                        variantControlNumbers: record.variantControlNumbers,
                        controlNumberNotes: record.controlNumberNotes)
                    else { continue }
                    byLot[lot, default: []].append(Claimant(
                        naId: record.naId, title: record.title,
                        recordGroup: record.recordGroupNumber,
                        hmsMlrEntryNumbers: record.hmsMlrEntryNumbers.isEmpty
                            ? nil : record.hmsMlrEntryNumbers,
                        dateRange: record.dateRange,
                        evidence: evidence == .controlNumber ? "controlNumber" : "consolidationNote"))
                }
            }
            generatorLog("  \(shard.lastPathComponent): running total \(byLot.count) lots")
        }

        // Only lots NARA divided need this file; a single claimant is already correct in
        // central-files-index.json and carrying it here would double the artifact for nothing.
        let divided = byLot
            .filter { $0.value.count > 1 }
            .map { LotClaimants(lotNumber: $0.key,
                                claimants: $0.value.sorted { $0.naId < $1.naId }) }
            .sorted { $0.lotNumber < $1.lotNumber }

        let index = Index(
            schemaVersion: currentSchemaVersion,
            generated: generatorDateStamp(override: environment["GENERATED_DATE"]),
            note: "NARA series that claim a FRUS lot number, for the lots where more than one "
                + "does. NARA divides lot files across series and consolidates several into one, "
                + "so a lot with several claimants has several correct answers; Source Explorer "
                + "shows them as candidates rather than picking. Built offline from the "
                + "record-group harvest with the app's own LotResolutionAcceptance rule.",
            harvestGenerated: harvestGenerated,
            lots: divided)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(index).write(to: URL(fileURLWithPath: outputPath))

        let docs = divided.reduce(0) { $0 + $1.claimants.count }
        generatorLog("✓ wrote \(outputPath): \(divided.count) divided lots, \(docs) claimants "
                     + "(max \(divided.map(\.claimants.count).max() ?? 0) on one lot)")
        if divided.isEmpty {
            // An empty artifact would silently disable the feature. The measured figure is 109.
            throw GeneratorError.missingFile(
                "no divided lots found — the harvest or the fold is wrong; expected ~109")
        }
    }

    /// The lot keys in the shipped bundle, folded with the shipped rule.
    static func bundledLotNumbers(at path: String) throws -> [String] {
        guard let data = FileManager.default.contents(atPath: path) else {
            throw GeneratorError.missingFile(path)
        }
        struct Shape: Decodable { struct Lot: Decodable { let lotNumber: String }
                                  let lotFiles: [Lot] }
        let decoded = try JSONDecoder().decode(Shape.self, from: data)
        return decoded.lotFiles
            .map { LotResolutionAcceptance.foldControlNumber($0.lotNumber) }
            .filter { !$0.isEmpty }
            .sorted()
    }
}
