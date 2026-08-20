// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import CollectionAuthorityGeneratorCore
import CentralFilesIndexGeneratorCore
import GeneratorKit
import SourceNoteKit
import SourceProvenanceIndexGeneratorCore
import VolumeSourcesIndexGeneratorCore

// MARK: - SourceExplorerExportRunner

/// Builds the corpus-wide Source Explorer data export (#335): one record per document source
/// note across the shippable corpus — the canonical id, the raw stored note, the parsed value
/// handed to Source Explorer logic, the strategy, and the dictionary of offline resolution
/// results — plus a committed aggregate summary and a deterministic sample.
///
/// Entirely offline: the bundled `central-files-index.json`, `volume-sources-index.json`, and
/// `collection-authority.json` are the resolution surfaces; the live NARA Catalog route the
/// app UI would offer is **recorded, never executed**. Extraction is the parity-pinned
/// `DocumentNoteExtractor` (the exact note text the app stores), parsing is the shared
/// `SourceNoteParser`, and strategies are `ProvenanceCategory` slugs — so every column agrees
/// with the app by construction.
///
/// Outputs (to `OUTPUT_DIR`):
/// - `source-explorer-export.json` — the full export (~266k records; too large to commit,
///   gitignored; streamed volume-by-volume so memory stays bounded)
/// - `source-explorer-export-summary.json` — committed aggregates
/// - `source-explorer-export-sample.json` — every 200th record, committed for review
///
/// Version history:
///   1.0 — #335: initial implementation
public enum SourceExplorerExportRunner {

    /// The export schema version.
    public static let schemaVersion = 1
    /// Every Nth record lands in the committed sample.
    public static let sampleStride = 200

    /// Reads configuration from the environment and runs the export.
    public static func run() throws {
        let env = ProcessInfo.processInfo.environment
        try run(
            volumesDir: URL(fileURLWithPath: env["VOLUMES_DIR"]
                ?? "/Users/jbotts/Development/frus/volumes", isDirectory: true),
            manifestPath: env["MANIFEST"] ?? "FRUSExplorer/Resources/manifest.json",
            centralFilesIndexPath: env["CENTRAL_FILES_INDEX"]
                ?? "FRUSExplorer/Resources/central-files-index.json",
            volumeSourcesIndexPath: env["VOLUME_SOURCES_INDEX"]
                ?? "FRUSExplorer/Resources/volume-sources-index.json",
            collectionAuthorityPath: env["COLLECTION_AUTHORITY"]
                ?? "FRUSExplorer/Resources/collection-authority.json",
            outputDir: URL(fileURLWithPath: env["OUTPUT_DIR"]
                ?? "Planning/source-explorer-export", isDirectory: true),
            generated: generatorDateStamp(override: env["GENERATED_DATE"]))
    }

    /// The parameterized run, callable from tests without touching the environment.
    public static func run(volumesDir: URL, manifestPath: String,
                           centralFilesIndexPath: String, volumeSourcesIndexPath: String,
                           collectionAuthorityPath: String,
                           outputDir: URL, generated: String) throws {
        // Resolution surfaces (all offline, all bundled artifacts).
        let lotResolver = try BundledLotResolver(
            indexURL: URL(fileURLWithPath: centralFilesIndexPath))
        let centralFiles = try JSONDecoder().decode(
            CentralFilesIndex.self,
            from: Data(contentsOf: URL(fileURLWithPath: centralFilesIndexPath)))
        let volumeSources = try JSONDecoder().decode(
            VolumeSourcesIndex.self,
            from: Data(contentsOf: URL(fileURLWithPath: volumeSourcesIndexPath)))
        let authority = try AuthorityLookup(
            indexURL: URL(fileURLWithPath: collectionAuthorityPath))
        let shippable = try shippableVolumeIds(manifestPath: manifestPath)

        // The shippable corpus, filename-sorted (the determinism anchor).
        let allFiles = try VolumeCorpusEnumerator.volumeFiles(in: volumesDir)
        let files = allFiles.filter { shippable.contains(VolumeCorpusEnumerator.volumeId(for: $0)) }
        let outsideManifest = allFiles.count - files.count
        guard !files.isEmpty else { throw GeneratorError.noVolumes(volumesDir.path) }
        generatorLog("[SourceExplorerExport] \(files.count) shippable volumes (\(outsideManifest) outside manifest), lot bundle \(lotResolver.lotFileCount) entries")

        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        let exportURL = outputDir.appendingPathComponent("source-explorer-export.json")
        FileManager.default.createFile(atPath: exportURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: exportURL)
        defer { try? handle.close() }

        // Compact record encoder (the full export must stay lean); the summary and sample
        // add .prettyPrinted below (human-facing report convention).
        let recordEncoder = JSONEncoder()
        recordEncoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]

        try handle.write(contentsOf: Data(
            "{\"schemaVersion\":\(schemaVersion),\"generated\":\"\(generated)\",\"records\":[".utf8))

        let parser = SourceNoteParser()
        var summary = SourceExplorerExportSummary(
            schemaVersion: schemaVersion, generated: generated,
            volumeCount: files.count, volumesOutsideManifest: outsideManifest,
            recordCount: 0, documentsWithoutId: 0,
            byStrategy: [:], byStrategyOutcome: [:], byDecade: [:], byOutcome: [:])
        var sample: [SourceExplorerExportRecord] = []
        var wroteFirstChunk = false
        var scanned = 0

        for file in files {
            // An unreadable volume must fail the run, never silently reshape the export.
            let data = try Data(contentsOf: file)
            let volumeId = VolumeCorpusEnumerator.volumeId(for: file)
            let notes = DocumentNoteExtractor.extract(fromXML: data)
            let years = DocumentYearExtractor.extract(fromXML: data)

            var records: [SourceExplorerExportRecord] = []
            records.reserveCapacity(notes.count)
            for note in notes {
                let record = exportRecord(
                    volumeId: volumeId, documentId: note.documentId, rawNote: note.note,
                    documentYear: note.documentId.isEmpty ? nil : years[note.documentId],
                    parser: parser, lotResolver: lotResolver, centralFiles: centralFiles,
                    volumeSources: volumeSources, authority: authority)
                if note.documentId.isEmpty { summary.documentsWithoutId += 1 }
                accumulate(record, into: &summary)
                if summary.recordCount % Self.sampleStride == 1 { sample.append(record) }
                records.append(record)
            }
            if !records.isEmpty {
                // Encode the volume's records as an array, then splice the elements into the
                // streaming top-level array (strip the encoder's own brackets).
                let chunk = try recordEncoder.encode(records).dropFirst().dropLast()
                if wroteFirstChunk { try handle.write(contentsOf: Data(",".utf8)) }
                try handle.write(contentsOf: chunk)
                wroteFirstChunk = true
            }

            scanned += 1
            if scanned % 100 == 0 {
                generatorLog("[SourceExplorerExport] \(scanned)/\(files.count) volumes, \(summary.recordCount) records")
            }
        }
        try handle.write(contentsOf: Data("]}".utf8))
        try handle.close()

        let reportEncoder = JSONEncoder()
        reportEncoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes, .prettyPrinted]
        try reportEncoder.encode(summary)
            .write(to: outputDir.appendingPathComponent("source-explorer-export-summary.json"))
        try reportEncoder.encode(sample)
            .write(to: outputDir.appendingPathComponent("source-explorer-export-sample.json"))

        generatorLog("""
        [SourceExplorerExport] done — \(summary.recordCount) records from \(files.count) volumes
          outcomes: \(summary.byOutcome.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " "))
          export:  \(exportURL.path)
          summary: \(outputDir.appendingPathComponent("source-explorer-export-summary.json").path)
          sample:  \(outputDir.appendingPathComponent("source-explorer-export-sample.json").path) (every \(Self.sampleStride)th record)
        """)
    }

    // MARK: - Record construction

    /// Builds one export record: parse → strategy → derived keys → offline resolutions.
    static func exportRecord(volumeId: String, documentId: String, rawNote: String,
                             documentYear: Int?, parser: SourceNoteParser,
                             lotResolver: BundledLotResolver,
                             centralFiles: CentralFilesIndex,
                             volumeSources: VolumeSourcesIndex,
                             authority: AuthorityLookup) -> SourceExplorerExportRecord {
        let parsed = parser.parse(rawNote)
        let strategy = ProvenanceCategory.from(parsed).rawValue
        let derived = ExportClassification.derivedKeys(for: parsed, note: rawNote)
        let route = ExportClassification.liveLookupRoute(for: parsed)

        // Bundled lot resolution (#321 guard inside BundledLotResolver); on a miss,
        // distinguish "flagged" from "not in bundle" via the unguarded mirror accessor.
        var lotBundle: ResolvedNAID?
        var lotBundleMiss: String?
        if let rawLot = ExportClassification.rawLot(of: parsed) {
            lotBundle = lotResolver.resolve(rawLot: rawLot)
            if lotBundle == nil {
                let norm = BundledLotResolver.normalizeLot(rawLot)
                lotBundleMiss = centralFiles.lotFile(normalized: norm)?.ancestryLacksRecordGroup == true
                    ? "flaggedAncestryLacksRecordGroup" : "notInBundle"
            }
        }

        // 1906–1910 Numerical File rolls — the same gate the app applies
        // (SourceExplorerView.swift:468: .centralFiles fileIdentifier + documentYear window).
        var rolls: [NumericalRollRef]?
        var coverageGap: Bool?
        if case .centralFiles(_, let fileIdentifier?) = parsed,
           let year = documentYear, (1906...1910).contains(year) {
            if let caseNumber = NumericalFileIndex.caseNumber(fromFileNumber: fileIdentifier) {
                let hits = centralFiles.numericalFile.rolls(containingCaseNumber: caseNumber)
                rolls = hits.isEmpty ? nil
                    : hits.map { NumericalRollRef(naId: $0.naId, title: $0.title, catalogURL: $0.catalogURL) }
                coverageGap = hits.isEmpty ? true : nil
            } else {
                coverageGap = true
            }
        }

        // Volume-sources index, consulted with the parse's lot/RG keys. Lot-over-record-group
        // precedence mirrors the app's VolumeSourcesIndex.resolution(recordGroup:lotFile:)
        // (VolumeSourcesIndex.swift:57): a lot-carrying parse resolves ONLY through its lot.
        // (In the app this index backs the front-matter surface; the export applies it at
        // document grain as a diagnostic.)
        //
        // #372 item 3 proposed deleting this whole arm as a duplicate of central-files. After
        // item 1's fold the two halves have opposite standing, so it is kept and re-scoped:
        //   • the RECORD-GROUP half is the live one — 31 headers central-files has no map for
        //     at all, and the only offline answer a lot-less citation gets here;
        //   • the LOT half resolves nothing today, because the fold emptied `lots`. It stays as
        //     a TRIPWIRE, not as redundancy: `lotsToWrite`'s carry-forward can refill that map
        //     from any future harvest, and this arm is what would report the new orphan instead
        //     of silently classifying it `resolvedAuthorityOnly`. Both halves are pinned by
        //     injected fixtures (`volumeSourcesLot`, `centralFilesRG`), so neither depends on
        //     what the shipped artifact happens to contain.
        var vsResolution: ResolvedNAID?
        var vsKey: String?
        if let rawLot = ExportClassification.rawLot(of: parsed) {
            let norm = BundledLotResolver.normalizeLot(rawLot)
            vsResolution = volumeSources.lots[norm]
            vsKey = vsResolution != nil ? "lot:\(norm)" : nil
        } else if let bareRG = bareRecordGroup(of: parsed) {
            vsResolution = volumeSources.recordGroups[bareRG]
            vsKey = vsResolution != nil ? "rg:\(bareRG)" : nil
        }

        // Collection-authority record (the app's 4-step lookup, ported in AuthorityLookup).
        let authorityRecord = authority.record(forParsed: parsed, note: rawNote)
        let authorityRef = authorityRecord.map {
            AuthorityRef(id: $0.id, name: $0.name, naId: $0.naId, catalogURL: $0.catalogURL)
        }

        let outcome: OfflineOutcome
        if lotBundle != nil {
            outcome = .resolvedLotBundle
        } else if rolls?.isEmpty == false {
            outcome = .resolvedNumericalFile
        } else if vsResolution != nil {
            outcome = .resolvedVolumeSources
        } else if authorityRef?.naId != nil {
            outcome = .resolvedAuthorityOnly
        } else if route != "noCatalogRoute" {
            outcome = .liveRouteOnly
        } else {
            outcome = .noResolution
        }

        return SourceExplorerExportRecord(
            id: "\(volumeId)/\(documentId)",
            rawNote: rawNote,
            documentYear: documentYear,
            parsed: ExportClassification.describe(parsed),
            strategy: strategy,
            derived: derived,
            resolution: ResolutionResults(
                liveLookupRoute: route,
                lotBundle: lotBundle, lotBundleMiss: lotBundleMiss,
                numericalFileRolls: rolls, numericalFileCoverageGap: coverageGap,
                volumeSources: vsResolution, volumeSourcesKey: vsKey,
                collectionAuthority: authorityRef),
            offlineOutcome: outcome.rawValue)
    }

    /// The bare record-group number a parse carries, for the volume-sources RG map (keyed by
    /// bare numbers): the parser's `"RG-59"` form is bridged via `CollectionKeying.bareRG`;
    /// `naraCollection` already carries the bare number.
    static func bareRecordGroup(of parsed: ParsedSourceNote) -> String? {
        switch parsed {
        case .centralFiles(let recordGroup, _):
            return CollectionKeying.bareRG(recordGroup)
        case .naraCollection(let recordGroup, _, _, _):
            return CollectionKeying.bareRG(recordGroup)
        case .lotFile(let recordGroup?, _, _):
            return CollectionKeying.bareRG(recordGroup)
        default:
            return nil
        }
    }

    // MARK: - Support

    /// Accumulates one record into the summary counters.
    private static func accumulate(_ record: SourceExplorerExportRecord,
                                   into summary: inout SourceExplorerExportSummary) {
        summary.recordCount += 1
        summary.byStrategy[record.strategy, default: 0] += 1
        summary.byOutcome[record.offlineOutcome, default: 0] += 1
        summary.byStrategyOutcome["\(record.strategy)|\(record.offlineOutcome)", default: 0] += 1
        let decade = record.documentYear.map { String(($0 / 10) * 10) } ?? "unknown"
        summary.byDecade[decade, default: 0] += 1
    }

    /// The manifest's shippable volume-id set (the app's universe).
    static func shippableVolumeIds(manifestPath: String) throws -> Set<String> {
        struct ManifestVolume: Decodable { let volumeId: String }
        let url = URL(fileURLWithPath: manifestPath)
        let volumes = try JSONDecoder().decode([ManifestVolume].self, from: Data(contentsOf: url))
        return Set(volumes.map(\.volumeId))
    }
}
