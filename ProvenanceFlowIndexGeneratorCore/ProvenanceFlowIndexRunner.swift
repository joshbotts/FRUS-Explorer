// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import CollectionAuthorityGeneratorCore
import CrossRefKit
import CrossRefValidationGeneratorCore
import GeneratorKit
import SourceExplorerExportGeneratorCore
import SourceNoteKit

// MARK: - ProvenanceFlowIndexRunner

/// Builds `provenance-flow-index.json` (#764): the archival units FRUS's editors sent readers
/// *between* when they cross-referenced one document from another.
///
/// Two passes over the shippable corpus, both reusing code the app is already pinned to:
/// `DocumentNoteExtractor` + `SourceNoteParser` + `AuthorityLookup` +
/// `ExportClassification.derivedKeys` for each document's archival unit (the same four surfaces
/// `CollectionUsageIndexGenerator` uses, so the two artifacts agree on what a document belongs
/// to), and `RefHarvester` + `CrossRefGrammar` for the references (the same two the validator
/// uses, so an edge here is an edge there).
///
/// Entirely offline and deterministic.
///
/// Version history:
///   1.0 — Session 2026-08-08: #764
public enum ProvenanceFlowIndexRunner {

    /// The artifact schema version.
    public static let schemaVersion = 1

    /// Reads configuration from the environment and runs the build.
    public static func run() throws {
        let env = ProcessInfo.processInfo.environment
        try run(
            volumesDir: URL(fileURLWithPath: env["VOLUMES_DIR"]
                ?? "/Users/jbotts/Development/frus/volumes", isDirectory: true),
            manifestPath: env["MANIFEST"] ?? "FRUSExplorer/Resources/manifest.json",
            collectionAuthorityPath: env["COLLECTION_AUTHORITY"]
                ?? "FRUSExplorer/Resources/collection-authority.json",
            outputPath: env["OUTPUT"] ?? "FRUSExplorer/Resources/provenance-flow-index.json",
            generated: generatorDateStamp(override: env["GENERATED_DATE"]))
    }

    /// The parameterized build.
    public static func run(volumesDir: URL, manifestPath: String,
                           collectionAuthorityPath: String, outputPath: String,
                           generated: String) throws {
        let authority = try AuthorityLookup(
            indexURL: URL(fileURLWithPath: collectionAuthorityPath))
        let shippable = try shippableVolumeIds(manifestPath: manifestPath)
        let allFiles = try VolumeCorpusEnumerator.volumeFiles(in: volumesDir)
        let files = allFiles.filter { shippable.contains(VolumeCorpusEnumerator.volumeId(for: $0)) }
        guard !files.isEmpty else { throw GeneratorError.noVolumes(volumesDir.path) }
        generatorLog("[ProvenanceFlow] \(files.count) shippable volumes")

        let index = try build(files: files, authority: authority, generated: generated)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(index)
        try data.write(to: URL(fileURLWithPath: outputPath))

        let coverage = index.coverage
        generatorLog("""
        [ProvenanceFlow] done — \(data.count) bytes
          references:  \(coverage.referencesScanned) scanned, \
        \(coverage.referencesInsideDocuments) inside a document
          edges:       \(coverage.documentEdges) document-to-document, \
        \(coverage.footnoteEdges) of them in footnotes, from \(coverage.volumesWithEdges) volumes
          collections: \(coverage.collections.joinedReferences) joined, \
        \(coverage.collections.betweenUnitReferences) between units, \
        \(coverage.collections.pairCount) pairs over \(coverage.collections.unitCount) units
          classes:     \(coverage.classes.joinedReferences) joined, \
        \(coverage.classes.betweenUnitReferences) between units, \
        \(coverage.classes.pairCount) pairs over \(coverage.classes.unitCount) units
          output: \(outputPath)
        """)
    }

    // MARK: - The build

    /// Scans `files` and aggregates. Pure apart from reading the volume bytes.
    public static func build(files: [URL], authority: AuthorityLookup,
                             generated: String) throws -> ProvenanceFlowIndex {
        let parser = SourceNoteParser()

        // Pass 1: every document's archival unit, and every volume's document-id inventory.
        var collectionOf: [String: String] = [:]      // "volume/document" → authority id
        var classOf: [String: String] = [:]           // "volume/document" → class key
        var documentIds: [String: Set<String>] = [:]  // volume → document xml:ids
        for file in files {
            let data = try Data(contentsOf: file)
            let volumeId = VolumeCorpusEnumerator.volumeId(for: file)
            documentIds[volumeId] = DocumentIdInventory.documentIds(in: data)
            for note in DocumentNoteExtractor.extract(fromXML: data) where !note.documentId.isEmpty {
                let key = "\(volumeId)/\(note.documentId)"
                let parsed = parser.parse(note.note)
                if let record = authority.record(forParsed: parsed, note: note.note) {
                    collectionOf[key] = record.id
                }
                if let cls = ExportClassification
                    .derivedKeys(for: parsed, note: note.note).decimalClass {
                    classOf[key] = cls
                }
            }
        }

        // Pass 2: every reference, resolved to a target document and joined to both units.
        var collectionFlows: [Pair: Int] = [:]
        var classFlows: [Pair: Int] = [:]
        var referencesScanned = 0
        var referencesInsideDocuments = 0
        var documentEdges = 0
        var sameVolumeEdges = 0
        var footnoteEdges = 0
        var volumesWithEdges = 0
        var collectionJoined = 0, collectionSame = 0
        var classJoined = 0, classSame = 0

        for file in files {
            let data = try Data(contentsOf: file)
            let sourceVolume = VolumeCorpusEnumerator.volumeId(for: file)
            let refs = RefHarvester.harvest(from: data)
            referencesScanned += refs.count
            var edgesHere = 0

            for ref in refs {
                guard let sourceDocument = ref.enclosingDocument else { continue }
                referencesInsideDocuments += 1
                guard case .document(let volumeOverride, let targetDocument) =
                        CrossRefGrammar.resolveDestination(ref.rawTarget, volumeId: sourceVolume)
                else { continue }
                let targetVolume = volumeOverride ?? sourceVolume
                // The target must be a real document div in a shippable volume. Without this the
                // index-entry anchors the grammar reports as documents become phantom nodes.
                guard documentIds[targetVolume]?.contains(targetDocument) == true else { continue }

                documentEdges += 1
                edgesHere += 1
                if targetVolume == sourceVolume { sameVolumeEdges += 1 }
                // A footnote reference is the editor annotating the source document, not the
                // document's own text citing another. Counted because it is 95% of the corpus and
                // it is what the matrix actually measures.
                if ref.isInsideNote { footnoteEdges += 1 }

                let sourceKey = "\(sourceVolume)/\(sourceDocument)"
                let targetKey = "\(targetVolume)/\(targetDocument)"
                if let from = collectionOf[sourceKey], let to = collectionOf[targetKey] {
                    collectionJoined += 1
                    if from == to { collectionSame += 1 }
                    collectionFlows[Pair(from: from, to: to), default: 0] += 1
                }
                if let from = classOf[sourceKey], let to = classOf[targetKey] {
                    classJoined += 1
                    if from == to { classSame += 1 }
                    classFlows[Pair(from: from, to: to), default: 0] += 1
                }
            }
            if edgesHere > 0 { volumesWithEdges += 1 }
        }

        // A run that joins nothing is a broken lookup, not an empty corpus.
        guard !collectionFlows.isEmpty else {
            throw ProvenanceFlowError.noFlows(edges: documentEdges, volumes: files.count)
        }

        let (collectionIds, collectionRows) = intern(collectionFlows)
        let (classKeys, classRows) = intern(classFlows)

        return ProvenanceFlowIndex(
            schemaVersion: schemaVersion,
            generated: generated,
            collectionIds: collectionIds,
            classKeys: classKeys,
            collectionFlows: collectionRows,
            classFlows: classRows,
            coverage: ProvenanceFlowIndex.Coverage(
                volumesScanned: files.count,
                volumesWithEdges: volumesWithEdges,
                referencesScanned: referencesScanned,
                referencesInsideDocuments: referencesInsideDocuments,
                documentEdges: documentEdges,
                sameVolumeEdges: sameVolumeEdges,
                footnoteEdges: footnoteEdges,
                collections: ProvenanceFlowIndex.AxisCoverage(
                    joinedReferences: collectionJoined, sameUnitReferences: collectionSame,
                    pairCount: collectionRows.count, unitCount: collectionIds.count),
                classes: ProvenanceFlowIndex.AxisCoverage(
                    joinedReferences: classJoined, sameUnitReferences: classSame,
                    pairCount: classRows.count, unitCount: classKeys.count)))
    }

    // MARK: - Support

    /// An ordered unit pair, before interning.
    struct Pair: Hashable {
        let from: String
        let to: String
    }

    /// Interns a flow accumulator into a sorted vocabulary and sorted rows.
    static func intern(_ flows: [Pair: Int]) -> ([String], [ProvenanceFlowIndex.Flow]) {
        var units: Set<String> = []
        for pair in flows.keys {
            units.insert(pair.from)
            units.insert(pair.to)
        }
        let vocabulary = units.sorted()
        let indexOf = Dictionary(uniqueKeysWithValues: vocabulary.enumerated().map { ($1, $0) })
        let rows = flows
            .compactMap { pair, count -> ProvenanceFlowIndex.Flow? in
                guard let from = indexOf[pair.from], let to = indexOf[pair.to] else { return nil }
                return ProvenanceFlowIndex.Flow(source: from, target: to, count: count)
            }
            .sorted { ($0.source, $0.target) < ($1.source, $1.target) }
        return (vocabulary, rows)
    }

    /// The manifest's shippable volume-id set.
    static func shippableVolumeIds(manifestPath: String) throws -> Set<String> {
        struct ManifestVolume: Decodable { let volumeId: String }
        let url = URL(fileURLWithPath: manifestPath)
        return Set(try JSONDecoder().decode([ManifestVolume].self,
                                            from: Data(contentsOf: url)).map(\.volumeId))
    }
}

// MARK: - ProvenanceFlowError

/// The one fatal condition this generator adds.
public enum ProvenanceFlowError: Error, CustomStringConvertible {
    /// The scan produced no joined flows at all.
    case noFlows(edges: Int, volumes: Int)

    public var description: String {
        switch self {
        case .noFlows(let edges, let volumes):
            return """
            Refusing to write an empty flow index: \(edges) document-to-document references across \
            \(volumes) volumes joined to no collection pair at all. Check the authority path — an \
            index of zeroes disables the feature while the build exits 0.
            """
        }
    }
}
