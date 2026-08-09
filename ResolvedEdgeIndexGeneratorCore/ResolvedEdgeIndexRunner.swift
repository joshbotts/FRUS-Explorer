// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import CrossRefKit
import CrossRefValidationGeneratorCore
import Foundation
import GeneratorKit
import ProvenanceFlowIndexGeneratorCore

// MARK: - ResolvedEdgeError

/// Why a run refused to write.
public enum ResolvedEdgeError: Error, CustomStringConvertible {
    /// The scan produced no cross-volume edges at all.
    case noEdges(documentEdges: Int, volumes: Int)

    public var description: String {
        switch self {
        case .noEdges(let documentEdges, let volumes):
            return """
                Refusing to write an empty resolved-edge index: \(documentEdges) document edges \
                across \(volumes) volumes yielded no cross-volume citation. The corpus is known to \
                carry roughly 8,600 of them, so this is a broken harvest — an empty artifact would \
                disable inbound-citation completion while the build exits 0.
                """
        }
    }
}

// MARK: - ResolvedEdgeIndexRunner

/// Builds `resolved-edge-index.json` (#262): every cross-volume document-to-document citation in
/// the shippable corpus, grouped by the document cited.
///
/// Reuses the validator's `RefHarvester` and `CrossRefGrammar` and #764's `DocumentIdInventory`,
/// so an edge here is an edge in the cross-reference report and in the provenance flow matrix.
/// Entirely offline and deterministic: a filename-sorted scan, sorted vocabularies, rows sorted by
/// key, and `sortedKeys` on the encoder.
///
/// Version history:
///   1.0 — Session 2026-08-09: #262
public enum ResolvedEdgeIndexRunner {

    /// Runs the generator from the environment.
    public static func run() throws {
        let environment = ProcessInfo.processInfo.environment
        let volumesDirectory = URL(fileURLWithPath:
            environment["VOLUMES_DIR"] ?? "/Users/jbotts/Development/frus/volumes")
        let manifest = URL(fileURLWithPath:
            environment["MANIFEST"] ?? "FRUSExplorer/Resources/manifest.json")
        let output = URL(fileURLWithPath:
            environment["OUTPUT"] ?? "FRUSExplorer/Resources/resolved-edge-index.json")
        let generated = environment["GENERATED_DATE"] ?? Self.today()

        // The manifest defines the shippable set, the same filter every sibling generator uses —
        // an edge into a volume the app cannot show is not a citation the reader can follow.
        let shippable = try Self.shippableVolumeIds(manifest: manifest)
        let files = try VolumeCorpusEnumerator.volumeFiles(in: volumesDirectory)
            .filter { shippable.contains(VolumeCorpusEnumerator.volumeId(for: $0)) }
        print("[ResolvedEdgeIndex] scanning \(files.count) volumes…")
        let index = try build(files: files, generated: generated)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(index).write(to: output)
        let size = (try? Data(contentsOf: output).count) ?? 0
        print("""
            [ResolvedEdgeIndex] \(index.coverage.storedEdges) cross-volume edges into \
            \(index.coverage.targetCount) documents, cited from \
            \(index.coverage.citingVolumeCount) volumes.
            [ResolvedEdgeIndex] \(index.coverage.documentEdges) document edges scanned; \
            \(index.coverage.sameVolumeEdges) same-volume edges excluded (the local table already \
            holds them).
            [ResolvedEdgeIndex] wrote \(size / 1024) KB to \(output.path)
            """)
    }

    /// The pure build, so tests can drive it over a fixture corpus.
    public static func build(files: [URL], generated: String) throws -> ResolvedEdgeIndex {
        // Pass 1: every volume's real document ids. The narrower inventory, not the validator's
        // anchor inventory — 49,799 index-entry anchors resolve as documents under the grammar
        // and would mint phantom citations (#764's finding, and it applies identically here).
        var documentIds: [String: Set<String>] = [:]
        var volumeOrder: [String] = []
        for file in files {
            let volumeId = VolumeCorpusEnumerator.volumeId(for: file)
            documentIds[volumeId] = DocumentIdInventory.documentIds(in: try Data(contentsOf: file))
            volumeOrder.append(volumeId)
        }

        // Pass 2: harvest, resolve, and keep only what crosses a volume boundary.
        struct Endpoint: Hashable { let volume: String; let document: String }
        var sourcesByTarget: [Endpoint: Set<Endpoint>] = [:]
        var footnoteSourcesByTarget: [Endpoint: Set<Endpoint>] = [:]
        var referencesScanned = 0
        var referencesInsideDocuments = 0
        var documentEdges = 0
        var sameVolumeEdges = 0
        var citingVolumes = Set<String>()

        for file in files {
            let data = try Data(contentsOf: file)
            let sourceVolume = VolumeCorpusEnumerator.volumeId(for: file)
            let refs = RefHarvester.harvest(from: data)
            referencesScanned += refs.count
            for ref in refs {
                guard let sourceDocument = ref.enclosingDocument else { continue }
                referencesInsideDocuments += 1
                guard case .document(let volumeOverride, let targetDocument) =
                        CrossRefGrammar.resolveDestination(ref.rawTarget, volumeId: sourceVolume)
                else { continue }
                let targetVolume = volumeOverride ?? sourceVolume
                guard documentIds[targetVolume]?.contains(targetDocument) == true else { continue }
                documentEdges += 1
                guard targetVolume != sourceVolume else {
                    sameVolumeEdges += 1
                    continue
                }
                let target = Endpoint(volume: targetVolume, document: targetDocument)
                let source = Endpoint(volume: sourceVolume, document: sourceDocument)
                // A Set: the same source document may reference the same target several times,
                // and a reader counting "documents that cite this" means documents, not mentions.
                sourcesByTarget[target, default: []].insert(source)
                if ref.isInsideNote { footnoteSourcesByTarget[target, default: []].insert(source) }
                citingVolumes.insert(sourceVolume)
            }
        }

        guard !sourcesByTarget.isEmpty else {
            throw ResolvedEdgeError.noEdges(documentEdges: documentEdges, volumes: files.count)
        }

        // Only volumes and documents that actually appear at an endpoint are interned, so the
        // vocabulary is the artifact's own and not a copy of the manifest.
        var used: [String: Set<String>] = [:]
        for (target, sources) in sourcesByTarget {
            used[target.volume, default: []].insert(target.document)
            for source in sources { used[source.volume, default: []].insert(source.document) }
        }
        let volumes = used.keys.sorted()
        let volumeIndex = Dictionary(uniqueKeysWithValues: volumes.enumerated().map { ($1, $0) })
        let documents = volumes.map { (used[$0] ?? []).sorted() }
        let documentIndex: [[String: Int]] = documents.map { row in
            Dictionary(uniqueKeysWithValues: row.enumerated().map { ($1, $0) })
        }

        func pair(_ endpoint: Endpoint) -> (Int, Int)? {
            guard let volume = volumeIndex[endpoint.volume],
                  let document = documentIndex[volume][endpoint.document] else { return nil }
            return (volume, document)
        }

        let targets = sourcesByTarget
            .compactMap { target, sources -> ResolvedEdgeIndex.TargetEdges? in
                guard let (volume, document) = pair(target) else { return nil }
                let footnotes = footnoteSourcesByTarget[target] ?? []
                let ordered = sources.compactMap(pair).sorted { $0 < $1 }
                return ResolvedEdgeIndex.TargetEdges(
                    volume: volume, document: document,
                    sources: ordered.flatMap { [$0.0, $0.1] },
                    footnoteSources: footnotes.count)
            }
            .sorted { a, b in
                if a.volume != b.volume { return a.volume < b.volume }
                return a.document < b.document
            }

        return ResolvedEdgeIndex(
            schemaVersion: 1, generated: generated, volumes: volumes, documents: documents,
            targets: targets,
            coverage: ResolvedEdgeIndex.Coverage(
                volumesScanned: files.count, referencesScanned: referencesScanned,
                referencesInsideDocuments: referencesInsideDocuments,
                documentEdges: documentEdges, sameVolumeEdges: sameVolumeEdges,
                targetCount: targets.count, citingVolumeCount: citingVolumes.count))
    }

    /// The manifest's shippable volume-id set — the same filter every sibling generator applies.
    ///
    /// Decoded through a minimal shape rather than the app's `VolumeManifestEntry`: this target
    /// needs one field, and depending on the app's model to read it would couple the generator to
    /// every future change in the manifest's other columns.
    static func shippableVolumeIds(manifest: URL) throws -> Set<String> {
        struct Entry: Decodable { let volumeId: String }
        let entries = try JSONDecoder().decode([Entry].self, from: try Data(contentsOf: manifest))
        return Set(entries.map(\.volumeId))
    }

    private static func today() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }
}
