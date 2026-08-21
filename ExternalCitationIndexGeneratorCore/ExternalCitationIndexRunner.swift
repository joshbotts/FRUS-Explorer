// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import CollectionAuthorityGeneratorCore
import GeneratorKit
import SourceExplorerExportGeneratorCore
import SourceNoteKit

// MARK: - ExternalCitationIndexRunner

/// Builds `external-citation-index.json` (#784) — where FRUS's editorial footnotes point outside
/// the printed record.
///
/// One pass over the shippable corpus, reusing the surfaces already pinned to the app:
/// `DocumentFootnoteExtractor` for the body footnotes, `FootnoteCitationScanner` for the
/// anchor-first grammar and its `Ibid.` state, `DocumentNoteExtractor` + `SourceNoteParser` for the
/// *citing* document's own unit, and `AuthorityLookup` for both ends of every pair. The local
/// `external_citations` table the app writes at index time runs the same grammar over the same
/// notes, so a row there is a reference here.
///
/// Entirely offline and deterministic: filename-sorted scan, sorted vocabularies, rows sorted by
/// key, `.sortedKeys` on the encoder.
///
/// Version history:
///   1.0 — Session 2026-08-10: #784
public enum ExternalCitationIndexRunner {

    /// The artifact schema version.
    public static let schemaVersion = 1

    /// Reads configuration from the environment and runs the build.
    ///
    /// `MEASURE_DECIMAL=1` diverts to #834's measurement pass instead, which writes a report to
    /// `Planning/` and touches no bundled artifact. It is a separate mode rather than an extra
    /// output of the build because the two have different denominators and different scopes, and
    /// a run that quietly did both would invite the measurement's numbers into the artifact's
    /// coverage block.
    public static func run() throws {
        let env = ProcessInfo.processInfo.environment
        if env["MEASURE_DECIMAL"] == "1" {
            try DecimalChannelMeasurement.run(
                volumesDir: URL(fileURLWithPath: env["VOLUMES_DIR"]
                    ?? "/Users/jbotts/Development/frus/volumes", isDirectory: true),
                manifestPath: env["MANIFEST"] ?? "FRUSExplorer/Resources/manifest.json",
                labelsPath: env["DECIMAL_LABELS"]
                    ?? "FRUSExplorer/Resources/decimal-class-labels.json",
                reportPath: env["MEASURE_OUTPUT"]
                    ?? "Planning/decimal-channel-measurement.json",
                samplePath: env["SAMPLE_OUTPUT"],
                sampleEvery: Int(env["SAMPLE_EVERY"] ?? "") ?? 200,
                generated: generatorDateStamp(override: env["GENERATED_DATE"]))
            return
        }
        try run(
            volumesDir: URL(fileURLWithPath: env["VOLUMES_DIR"]
                ?? "/Users/jbotts/Development/frus/volumes", isDirectory: true),
            manifestPath: env["MANIFEST"] ?? "FRUSExplorer/Resources/manifest.json",
            collectionAuthorityPath: env["COLLECTION_AUTHORITY"]
                ?? "FRUSExplorer/Resources/collection-authority.json",
            outputPath: env["OUTPUT"] ?? "FRUSExplorer/Resources/external-citation-index.json",
            samplePath: env["SAMPLE_OUTPUT"],
            sampleEvery: Int(env["SAMPLE_EVERY"] ?? "") ?? 200,
            generated: generatorDateStamp(override: env["GENERATED_DATE"]))
    }

    /// The parameterized build, callable from tests without touching the environment.
    ///
    /// - Parameters:
    ///   - samplePath: When set, every `sampleEvery`-th harvested reference is written here as
    ///     JSON. This is the review artifact: #784's safety verdict rests on reading samples, and
    ///     a grammar whose output nobody can read is a grammar nobody can check.
    public static func run(volumesDir: URL, manifestPath: String,
                           collectionAuthorityPath: String, outputPath: String,
                           samplePath: String?, sampleEvery: Int,
                           generated: String) throws {
        let authorityURL = URL(fileURLWithPath: collectionAuthorityPath)
        let authority = try AuthorityLookup(indexURL: authorityURL)
        let authorityCount = try authorityRecordCount(at: authorityURL)
        let shippable = try shippableVolumeIds(manifestPath: manifestPath)

        let allFiles = try VolumeCorpusEnumerator.volumeFiles(in: volumesDir)
        let files = allFiles.filter { shippable.contains(VolumeCorpusEnumerator.volumeId(for: $0)) }
        guard !files.isEmpty else { throw GeneratorError.noVolumes(volumesDir.path) }
        generatorLog("[ExternalCitations] \(files.count) shippable volumes of \(allFiles.count) on disk")

        let result = try build(files: files, authority: authority,
                               authorityCollectionCount: authorityCount,
                               sampleEvery: samplePath == nil ? 0 : max(1, sampleEvery),
                               generated: generated)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(result.index)
        try data.write(to: URL(fileURLWithPath: outputPath))

        if let samplePath {
            let sampleEncoder = JSONEncoder()
            sampleEncoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes, .prettyPrinted]
            try sampleEncoder.encode(result.samples)
                .write(to: URL(fileURLWithPath: samplePath))
            generatorLog("[ExternalCitations] \(result.samples.count) samples → \(samplePath)")
        }

        let c = result.index.coverage
        generatorLog("""
        [ExternalCitations] done — \(data.count) bytes
          volumes:    \(c.volumesScanned) scanned, \(c.volumesWithReferences) with references
          documents:  \(c.documentsScanned); body footnotes \(c.footnotesScanned), \
        \(c.footnotesExcluded) notes excluded \
        (\(c.headNestedExcluded) head-nested, \(c.headNestedExcludedWithAnchor) with an anchor)
          references: \(c.referencesFound) found — \(c.lotReferences) lot, \
        \(c.libraryReferences) library, \(c.referencesInherited) inherited via Ibid.
          refused:    \(c.absenceClaimsRefused) absence claims
          joined:     \(c.referencesJoined) to the authority \
        (\(percent(c.referencesJoined, of: c.referencesFound))), \
        \(result.index.targetIds.count) distinct units of \(c.authorityCollectionCount)
          pairs:      \(result.index.pairs.count) over \(c.referencesWithBothEnds) two-ended \
        references, \(c.sameUnitReferences) of them same-unit
          output: \(outputPath)
        """)
    }

    /// The index plus the review samples.
    public struct BuildResult: Sendable {
        /// The artifact.
        public let index: ExternalCitationIndex
        /// Every `sampleEvery`-th harvested reference, for reading.
        public let samples: [Sample]
    }

    /// One harvested reference, in a shape a human can check against the volume.
    public struct Sample: Codable, Sendable {
        /// Volume id.
        public let volumeId: String
        /// Document id.
        public let documentId: String
        /// `lotFile` or `presidentialLibrary`.
        public let anchor: String
        /// The clause the anchor was read from.
        public let citation: String
        /// Whether an `Ibid.` supplied the unit.
        public let inherited: Bool
        /// The authority collection it joined to, or `nil`.
        public let unitId: String?
        /// That collection's display name, or `nil`.
        public let unitName: String?
    }

    // MARK: - The build

    /// Scans `files` and aggregates. Pure apart from reading the volume bytes.
    public static func build(files: [URL], authority: AuthorityLookup,
                             authorityCollectionCount: Int, sampleEvery: Int,
                             generated: String) throws -> BuildResult {
        let parser = SourceNoteParser()

        var byTarget: [String: [String: Int]] = [:]
        var byPair: [PairKey: Int] = [:]
        var volumesWithReferences: Set<String> = []
        var sourceIdSet: Set<String> = []
        var samples: [Sample] = []

        var documentsScanned = 0
        var footnotesScanned = 0
        var footnotesExcluded = 0
        var headNestedExcluded = 0
        var headNestedExcludedWithAnchor = 0
        var referencesFound = 0
        var referencesInherited = 0
        var absenceClaimsRefused = 0
        var lotReferences = 0
        var libraryReferences = 0
        var referencesJoined = 0
        var referencesWithBothEnds = 0
        var sameUnitReferences = 0

        for file in files {
            // An unreadable volume fails the run: a skipped one would shrink every count in the
            // artifact while the build still reported success.
            let data = try Data(contentsOf: file)
            let volumeId = VolumeCorpusEnumerator.volumeId(for: file)

            // The citing document's own archival unit — the source end of every pair. Keyed by
            // document id, exactly as the app's `document_sources` row is.
            var sourceUnit: [String: String] = [:]
            for note in DocumentNoteExtractor.extract(fromXML: data) where !note.documentId.isEmpty {
                if let record = authority.record(forParsed: parser.parse(note.note),
                                                 note: note.note) {
                    sourceUnit[note.documentId] = record.id
                }
            }

            var scanner = FootnoteCitationScanner()
            for document in DocumentFootnoteExtractor.extract(fromXML: data) {
                documentsScanned += 1
                footnotesScanned += document.footnotes.count
                footnotesExcluded += document.excluded.count
                // Split by reason: a `type="source"` note carrying an archival anchor is a source
                // note doing its job, not a citation this harvest lost. The head-nested count is
                // the one that measures a judgement call.
                for note in document.excluded where note.reason == .headNested {
                    headNestedExcluded += 1
                    if FootnoteCitationScanner.carriesArchivalAnchor(note.text) {
                        headNestedExcludedWithAnchor += 1
                    }
                }

                let before = scanner.absenceBlockedCount
                scanner.beginDocument()
                for note in document.footnotes {
                    for citation in scanner.scan(note: note) {
                        referencesFound += 1
                        if citation.inherited { referencesInherited += 1 }
                        switch citation.anchor {
                        case .lotFile: lotReferences += 1
                        case .presidentialLibrary: libraryReferences += 1
                        }
                        let record = authority.record(forParsed: citation.parsed,
                                                      note: citation.citation)
                        if sampleEvery > 0, referencesFound % sampleEvery == 0 {
                            samples.append(Sample(volumeId: volumeId,
                                                  documentId: document.documentId,
                                                  anchor: citation.anchor.rawValue,
                                                  citation: citation.citation,
                                                  inherited: citation.inherited,
                                                  unitId: record?.id, unitName: record?.name))
                        }
                        guard let record else { continue }
                        referencesJoined += 1
                        volumesWithReferences.insert(volumeId)
                        byTarget[record.id, default: [:]][volumeId, default: 0] += 1
                        if let source = sourceUnit[document.documentId] {
                            referencesWithBothEnds += 1
                            sourceIdSet.insert(source)
                            if source == record.id { sameUnitReferences += 1 }
                            byPair[PairKey(source: source, target: record.id), default: 0] += 1
                        }
                    }
                }
                absenceClaimsRefused += scanner.absenceBlockedCount - before
            }
        }

        // A run that joins nothing is a broken lookup, not an empty corpus — and an artifact of
        // zeroes disables the feature while the build exits 0.
        guard !byTarget.isEmpty, !byPair.isEmpty else {
            throw ExternalCitationError.brokenJoin(
                targets: byTarget.count, pairs: byPair.count,
                references: referencesFound, volumes: files.count)
        }

        let volumes = volumesWithReferences.sorted()
        let volumeIndex = Dictionary(uniqueKeysWithValues: volumes.enumerated().map { ($1, $0) })
        let targetIds = byTarget.keys.sorted()
        let targetIndex = Dictionary(uniqueKeysWithValues: targetIds.enumerated().map { ($1, $0) })
        let sourceIds = sourceIdSet.sorted()
        let sourceIndex = Dictionary(uniqueKeysWithValues: sourceIds.enumerated().map { ($1, $0) })

        let targets: [ExternalCitationIndex.UnitRow] = targetIds.enumerated().compactMap { i, id in
            guard let perVolume = byTarget[id], !perVolume.isEmpty else { return nil }
            let ordered = perVolume
                .compactMap { volumeId, count in volumeIndex[volumeId].map { ($0, count) } }
                .sorted { $0.0 < $1.0 }
            guard !ordered.isEmpty else { return nil }
            return ExternalCitationIndex.UnitRow(key: i, volumes: ordered.map(\.0),
                                                 counts: ordered.map(\.1))
        }

        let pairs: [ExternalCitationIndex.Pair] = byPair
            .compactMap { key, count in
                guard let source = sourceIndex[key.source],
                      let target = targetIndex[key.target] else { return nil }
                return ExternalCitationIndex.Pair(source: source, target: target, count: count)
            }
            .sorted { ($0.source, $0.target) < ($1.source, $1.target) }

        let index = ExternalCitationIndex(
            schemaVersion: schemaVersion, generated: generated,
            volumes: volumes, targetIds: targetIds, sourceIds: sourceIds,
            targets: targets, pairs: pairs,
            coverage: ExternalCitationIndex.Coverage(
                volumesScanned: files.count,
                volumesWithReferences: volumes.count,
                documentsScanned: documentsScanned,
                footnotesScanned: footnotesScanned,
                footnotesExcluded: footnotesExcluded,
                headNestedExcluded: headNestedExcluded,
                headNestedExcludedWithAnchor: headNestedExcludedWithAnchor,
                referencesFound: referencesFound,
                referencesInherited: referencesInherited,
                absenceClaimsRefused: absenceClaimsRefused,
                lotReferences: lotReferences,
                libraryReferences: libraryReferences,
                referencesJoined: referencesJoined,
                referencesWithBothEnds: referencesWithBothEnds,
                sameUnitReferences: sameUnitReferences,
                authorityCollectionCount: authorityCollectionCount))
        return BuildResult(index: index, samples: samples)
    }

    /// A (source, target) accumulator key.
    struct PairKey: Hashable, Sendable {
        let source: String
        let target: String
    }

    // MARK: - Support

    /// The manifest's shippable volume-id set (the app's universe).
    static func shippableVolumeIds(manifestPath: String) throws -> Set<String> {
        struct ManifestVolume: Decodable { let volumeId: String }
        let url = URL(fileURLWithPath: manifestPath)
        let volumes = try JSONDecoder().decode([ManifestVolume].self, from: Data(contentsOf: url))
        return Set(volumes.map(\.volumeId))
    }

    /// How many records the authority carries.
    static func authorityRecordCount(at url: URL) throws -> Int {
        struct Envelope: Decodable {
            struct Record: Decodable { let id: String }
            let collections: [Record]
        }
        return try JSONDecoder().decode(Envelope.self, from: Data(contentsOf: url)).collections.count
    }

    /// `"42.0%"`, or `"—"` when the denominator is zero.
    private static func percent(_ value: Int, of total: Int) -> String {
        guard total > 0 else { return "—" }
        return String(format: "%.1f%%", Double(value) / Double(total) * 100)
    }
}

// MARK: - ExternalCitationError

/// The one fatal condition this generator adds to ``GeneratorError``.
public enum ExternalCitationError: Error, CustomStringConvertible {
    /// The scan finished with nothing joined — a broken lookup, not an empty corpus.
    case brokenJoin(targets: Int, pairs: Int, references: Int, volumes: Int)

    public var description: String {
        switch self {
        case .brokenJoin(let targets, let pairs, let references, let volumes):
            return """
            Refusing to write an empty index: \(references) references across \(volumes) volumes \
            produced \(targets) target units and \(pairs) pairs. An artifact of zeroes disables \
            the feature while the build exits 0 — check the authority path and the corpus first.
            """
        }
    }
}
