// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import CrossRefKit
import CrossRefValidationGeneratorCore
import FRUSCoreKit
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

/// Builds `resolved-edge-index.json` (#262): every cross-volume citation of a document in the
/// shippable corpus, grouped by the document cited.
///
/// A citation is a reference to a document, or to a note in one (`RefDestination.citedDocument`),
/// from a row the app's index holds: a document, or the text a section prints at its own level.
/// - **From a document**: the validator's `RefHarvester` with `CrossRefGrammar` and #764's
///   `DocumentIdInventory`, so an edge here is an edge in the cross-reference report and in the
///   provenance flow matrix, and the funnel's document counts are that matrix's.
/// - **From a section** (#1693): the rows the kit's own parser gives a section — a division's
///   own text (#1536), a container's (#1510), a prose section such as an introduction or an
///   errata list — which is how the index decides them, so a section cites here under the id the
///   app's local table stores it under, and `CrossReferenceStore.completingInboundEdges` merges the
///   two as one citer. A reference in a section holds no document, so `RefHarvester` never gives
///   it one and the two passes cannot count a reference twice.
///
/// Entirely offline and deterministic: a filename-sorted scan, sorted vocabularies, rows sorted by
/// key, and `sortedKeys` on the encoder.
///
/// Version history:
///   1.0 — Session 2026-08-09: #262
///   1.1 — #1693: a reference to a note is a citation of its document under the grammar's
///          `.footnote` case, and a section's row cites (`sectionReferences(in:)`), counted in the
///          funnel's three section fields; `build` is `async`, for the kit's parser
public enum ResolvedEdgeIndexRunner {

    /// Runs the generator from the environment.
    public static func run() async throws {
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
        let index = try await build(files: files, generated: generated)

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
            [ResolvedEdgeIndex] \(index.coverage.referencesInSections) references in sections' own \
            rows; \(index.coverage.sectionEdges) of them cite a document, \
            \(index.coverage.sameVolumeSectionEdges) in their own volume.
            [ResolvedEdgeIndex] wrote \(size / 1024) KB to \(output.path)
            """)
    }

    /// The pure build, so tests can drive it over a fixture corpus.
    public static func build(files: [URL], generated: String) async throws -> ResolvedEdgeIndex {
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

        /// Where `rawTarget`, written in `sourceVolume`, cites a document of a shippable volume, or
        /// `nil`: the target must be a real document div, not merely what the grammar reads as one.
        func citedEndpoint(_ rawTarget: String, in sourceVolume: String) -> Endpoint? {
            guard let (volumeOverride, targetDocument) =
                    CrossRefGrammar.resolveDestination(rawTarget, volumeId: sourceVolume).citedDocument
            else { return nil }
            let targetVolume = volumeOverride ?? sourceVolume
            guard documentIds[targetVolume]?.contains(targetDocument) == true else { return nil }
            return Endpoint(volume: targetVolume, document: targetDocument)
        }

        /// Keeps one citation from `source`, which a reader counting "documents that cite this"
        /// counts once however often it cites (a Set).
        func keep(_ source: Endpoint, cites target: Endpoint, fromNote isInsideNote: Bool) {
            sourcesByTarget[target, default: []].insert(source)
            if isInsideNote { footnoteSourcesByTarget[target, default: []].insert(source) }
            citingVolumes.insert(source.volume)
        }

        for file in files {
            let data = try Data(contentsOf: file)
            let sourceVolume = VolumeCorpusEnumerator.volumeId(for: file)
            let refs = RefHarvester.harvest(from: data)
            referencesScanned += refs.count
            for ref in refs {
                guard let sourceDocument = ref.enclosingDocument else { continue }
                referencesInsideDocuments += 1
                guard let target = citedEndpoint(ref.rawTarget, in: sourceVolume) else { continue }
                documentEdges += 1
                guard target.volume != sourceVolume else {
                    sameVolumeEdges += 1
                    continue
                }
                keep(Endpoint(volume: sourceVolume, document: sourceDocument), cites: target,
                     fromNote: ref.isInsideNote)
            }
        }

        // Pass 3 (#1693): the rows the index holds for sections. A row the parser gives a document
        // div was harvested above; every other row is a section's.
        var referencesInSections = 0
        var sectionEdges = 0
        var sameVolumeSectionEdges = 0
        let sectionRows = try await sectionReferences(in: files)
        for file in files {
            let sourceVolume = VolumeCorpusEnumerator.volumeId(for: file)
            let documentsHere = documentIds[sourceVolume] ?? []
            for row in sectionRows[sourceVolume] ?? []
            where !row.rowId.isEmpty && !documentsHere.contains(row.rowId) {
                referencesInSections += row.references.count
                for reference in row.references {
                    guard let target = citedEndpoint(reference.target, in: sourceVolume)
                    else { continue }
                    sectionEdges += 1
                    guard target.volume != sourceVolume else {
                        sameVolumeSectionEdges += 1
                        continue
                    }
                    keep(Endpoint(volume: sourceVolume, document: row.rowId), cites: target,
                         fromNote: reference.isInsideNote)
                }
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
                referencesInSections: referencesInSections, sectionEdges: sectionEdges,
                sameVolumeSectionEdges: sameVolumeSectionEdges,
                targetCount: targets.count, citingVolumeCount: citingVolumes.count))
    }

    // MARK: - Sections' rows (#1693)

    /// One row the kit's parser emits for a volume, with the `<ref>`s it holds.
    struct ParsedRowReferences: Sendable {
        /// The row's id: a document div's `xml:id`, or the section's.
        let rowId: String
        /// The row's references, in document order.
        let references: [SectionReference]
    }

    /// One `<ref>` in a parsed row.
    struct SectionReference: Sendable, Equatable {
        /// The verbatim `target`.
        let target: String
        /// Whether a `<note>` holds it, as `HarvestedRef.isInsideNote` says of a document's.
        let isInsideNote: Bool
    }

    /// Every row the kit's parser emits for each volume, by volume id, with its references.
    ///
    /// The parse is `FRUSDocumentParser.parse(volumeURL:)`, the whole-volume parse whose rows the
    /// app's index stores, so a section here is a section there: since index version 68 a
    /// division that holds documents and prints text of its own is a row of that text alone, a
    /// container of sections with text of its own is a row of it (#1510), and a prose section is a
    /// row whole. Six volumes are parsed at a time; the result is keyed, not ordered, so it does
    /// not depend on which finishes first.
    static func sectionReferences(in files: [URL]) async throws -> [String: [ParsedRowReferences]] {
        let concurrency = 6
        return try await withThrowingTaskGroup(
            of: (String, [ParsedRowReferences]).self
        ) { group in
            var result: [String: [ParsedRowReferences]] = [:]
            var pending = files.makeIterator()
            func addNext() -> Bool {
                guard let file = pending.next() else { return false }
                group.addTask {
                    let rows = try await FRUSDocumentParser().parse(volumeURL: file)
                    return (VolumeCorpusEnumerator.volumeId(for: file), rows.map { row in
                        ParsedRowReferences(rowId: row.documentId,
                                            references: references(in: row.nodes))
                    })
                }
                return true
            }
            for _ in 0..<concurrency where !addNext() { break }
            while let (volumeId, rows) = try await group.next() {
                result[volumeId] = rows
                _ = addNext()
            }
            return result
        }
    }

    /// The `<ref>`s in `nodes`, in document order, walked as the index's walk
    /// (`IndexingPipeline.collectDocumentRefs`) walks them: a `<ref>` inside another one included,
    /// and a `.footnote` node a `<note>`. An empty or external target is kept here and cites
    /// nothing later, as the index stores no row for it.
    static func references(in nodes: [FRUSASTNode],
                           insideNote: Bool = false) -> [SectionReference] {
        var found: [SectionReference] = []
        for node in nodes {
            switch node {
            case .crossReference(let target, _, let children):
                found.append(SectionReference(target: target, isInsideNote: insideNote))
                found.append(contentsOf: references(in: children, insideNote: insideNote))
            case .footnote(_, _, _, let children):
                found.append(contentsOf: references(in: children, insideNote: true))
            default:
                found.append(contentsOf: references(in: node.children, insideNote: insideNote))
            }
        }
        return found
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
