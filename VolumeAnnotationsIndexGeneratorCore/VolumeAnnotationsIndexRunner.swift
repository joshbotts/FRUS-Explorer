// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import FRUSCoreKit
import FTS5Store
import Foundation
import GeneratorKit

// MARK: - VolumeAnnotationsIndexError

/// Why the generator refuses to write.
public enum VolumeAnnotationsIndexError: Error, CustomStringConvertible, Equatable {
    /// `CORPUS_COMMIT` is not set: the file records the corpus it was read at.
    case missingCorpusCommit
    /// Manifest volumes with no file in `VOLUMES_DIR`.
    case missingVolumes([String])
    /// A volume whose subseries begins before the first era band.
    case noEra(volumeId: String, subseries: String)
    /// `INDEX_DB` names no file.
    case noIndex(String)
    /// The index was built at another index version, or its documents at several.
    case staleIndex(found: String, current: Int)
    /// SQLite could not open or read the index.
    case unreadableIndex(path: String, message: String)
    /// No volume carries people tagging, which no real corpus lacks: the input is wrong.
    case noPeopleTagging

    /// The refusal, as the run prints it.
    public var description: String {
        switch self {
        case .missingCorpusCommit:
            return "CORPUS_COMMIT is required: the file records the corpus commit it was read at"
        case .missingVolumes(let ids):
            return "\(ids.count) manifest volume(s) missing from VOLUMES_DIR: \(ids.prefix(10).joined(separator: ", "))"
        case .noEra(let volumeId, let subseries):
            return "\(volumeId): subseries \(subseries) begins before the first era band"
        case .noIndex(let path):
            return "INDEX_DB names \(path), which is not a file"
        case .staleIndex(let found, let current):
            return "the index's documents are stamped at version \(found); the current index version is \(current)"
        case .unreadableIndex(let path, let message):
            return "cannot read the index (\(path)): \(message)"
        case .noPeopleTagging:
            return "no volume carries people tagging; refusing to write a file that says so"
        }
    }
}

// MARK: - VolumeAnnotationsIndexConfiguration

/// What one run reads and writes, from the environment.
public struct VolumeAnnotationsIndexConfiguration: Sendable {
    /// Where the full index comes from.
    public enum IndexSource: Sendable, Equatable {
        /// Build one through the kit's pipeline: in this folder, kept, or in a temporary folder,
        /// removed after the run.
        case build(keptIn: URL?)
        /// Read one already built at the current index version (`INDEX_DB`).
        case existing(URL)
    }

    /// The corpus's volume files (`VOLUMES_DIR`).
    public var volumesDirectory: URL
    /// The catalogue (`MANIFEST`), whose volumes the file covers.
    public var manifest: URL
    /// Where the file is written (`OUTPUT`).
    public var output: URL
    /// The corpus commit the volumes are read at (`CORPUS_COMMIT`, required).
    public var corpusCommit: String
    /// The day stamped into the file (`GENERATED_DATE`, else today).
    public var generated: String
    /// The full index (`INDEX_DB`, or `INDEX_DIR` to keep the one built).
    public var index: IndexSource

    /// Creates a configuration.
    public init(volumesDirectory: URL, manifest: URL, output: URL, corpusCommit: String,
                generated: String, index: IndexSource) {
        self.volumesDirectory = volumesDirectory
        self.manifest = manifest
        self.output = output
        self.corpusCommit = corpusCommit
        self.generated = generated
        self.index = index
    }

    /// Reads a configuration from `environment`.
    public init(environment: [String: String]) throws {
        guard let commit = environment["CORPUS_COMMIT"]?.trimmingCharacters(in: .whitespaces),
              !commit.isEmpty else {
            throw VolumeAnnotationsIndexError.missingCorpusCommit
        }
        let index: IndexSource
        if let existing = environment["INDEX_DB"] {
            index = .existing(URL(fileURLWithPath: existing))
        } else {
            index = .build(keptIn: environment["INDEX_DIR"].map { URL(fileURLWithPath: $0, isDirectory: true) })
        }
        self.init(
            volumesDirectory: URL(fileURLWithPath:
                environment["VOLUMES_DIR"] ?? "/Users/jbotts/Development/frus/volumes", isDirectory: true),
            manifest: URL(fileURLWithPath: environment["MANIFEST"] ?? "FRUSExplorer/Resources/manifest.json"),
            output: URL(fileURLWithPath:
                environment["OUTPUT"] ?? "FRUSExplorer/Resources/volume-annotations-index.json"),
            corpusCommit: commit,
            generated: generatorDateStamp(override: environment["GENERATED_DATE"]),
            index: index)
    }
}

// MARK: - VolumeAnnotationsIndexRunner

/// Writes `volume-annotations-index.json`: what editorial annotation each catalogue volume carries
/// (`Planning/Editors-Annotations-Design-2026-11-06.md`, §4).
///
/// One full index of the catalogue, built through the kit's own pipeline or read from `INDEX_DB`,
/// answers every category the app reads; one SAX pass over each volume's TEI answers the rest.
/// Deterministic for a pinned corpus, `GENERATED_DATE` and index version. Refuses to write on a
/// manifest volume missing from `VOLUMES_DIR`, an index at another version, or a corpus where no
/// volume carries people tagging.
///
/// Version history:
///   1.0 — 2026-11-06: the editors' annotations design, lane A
///   1.1 — 2026-11-08: reports the volumes that print no publication date, and the editorial
///          omissions the 1925 gate leaves uncarried (Lane 1 of the follow-ups plan)
public enum VolumeAnnotationsIndexRunner {

    /// One manifest volume: the fields the run reads.
    struct ManifestEntry: Decodable, Sendable {
        /// The volume's id, `frus1969-76v17`.
        let volumeId: String
        /// Its file in `VOLUMES_DIR`.
        let filename: String
        /// Its subseries, whose first year gives its era ("1969-76").
        let subseries: String
    }

    /// Runs the generator from the environment.
    public static func run() async throws {
        let configuration = try VolumeAnnotationsIndexConfiguration(
            environment: ProcessInfo.processInfo.environment)
        let index = try await build(configuration)
        let data = try index.shippingData()
        try data.write(to: configuration.output)
        report(index, bytes: data.count, to: configuration.output)
    }

    /// Builds the index's file contents for `configuration`, without writing them.
    public static func build(_ configuration: VolumeAnnotationsIndexConfiguration) async throws
        -> VolumeAnnotationsIndex {
        let entries = try JSONDecoder().decode(
            [ManifestEntry].self, from: Data(contentsOf: configuration.manifest))
        let files = entries.map { configuration.volumesDirectory.appendingPathComponent($0.filename) }
        let missing = zip(entries, files)
            .filter { !FileManager.default.fileExists(atPath: $0.1.path) }.map { $0.0.volumeId }
        guard missing.isEmpty else { throw VolumeAnnotationsIndexError.missingVolumes(missing) }

        let facts = try await indexFacts(of: files, from: configuration.index)
        let current = IndexingPipeline.currentDateIndexVersion
        guard let versions = facts.indexVersions, versions.lowerBound == current,
              versions.upperBound == current else {
            throw VolumeAnnotationsIndexError.staleIndex(
                found: facts.indexVersions.map { "\($0.lowerBound)…\($0.upperBound)" } ?? "none",
                current: current)
        }

        var volumes: [String: VolumeAnnotations] = [:]
        var unindexed = 0
        var despatchNotes: [String: Int] = [:]
        var undated: [String] = []
        for (entry, file) in zip(entries, files) {
            guard let year = Int(entry.subseries.prefix(4)),
                  let era = AnnotationEra.era(subseriesStartYear: year, volumeId: entry.volumeId) else {
                throw VolumeAnnotationsIndexError.noEra(volumeId: entry.volumeId, subseries: entry.subseries)
            }
            let scan = try TEIAnnotationScanner.scan(file: file)
            let counted = VolumeAnnotationsAssembly.annotations(
                scan: scan, facts: facts.volumes[entry.volumeId] ?? IndexVolumeFacts(), era: era)
            volumes[entry.volumeId] = counted.annotations
            unindexed += counted.unindexed
            if scan.publicationYear == nil { undated.append(entry.volumeId) }
            if counted.despatchNotes > 0 { despatchNotes[entry.volumeId] = counted.despatchNotes }
        }
        guard volumes.values.contains(where: { $0.carries(.people) }) else {
            throw VolumeAnnotationsIndexError.noPeopleTagging
        }
        if unindexed > 0 {
            generatorLog("[VolumeAnnotationsIndex] \(unindexed) documents have no row in the index; they count only by the TEI rule")
        }
        if !despatchNotes.isEmpty {
            let listed = despatchNotes.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }
            generatorLog("[VolumeAnnotationsIndex] source notes read as despatch numbers, not counted: \(listed.joined(separator: ", "))")
        }
        if !undated.isEmpty {
            generatorLog("[VolumeAnnotationsIndex] \(undated.count) volume(s) print no publication date, so the 1925 gate does not apply to them: \(undated.prefix(10).joined(separator: ", "))")
        }
        return VolumeAnnotationsIndex(generated: configuration.generated,
                                      corpusCommit: configuration.corpusCommit,
                                      indexVersion: current, volumes: volumes)
    }

    /// Reads the facts of a full index: built through the kit's pipeline, or the one at `INDEX_DB`.
    static func indexFacts(of files: [URL],
                           from source: VolumeAnnotationsIndexConfiguration.IndexSource) async throws -> IndexFacts {
        switch source {
        case .existing(let database):
            guard FileManager.default.fileExists(atPath: database.path) else {
                throw VolumeAnnotationsIndexError.noIndex(database.path)
            }
            return try IndexAnnotationReader.read(database: database)
        case .build(let kept):
            let folder = kept ?? FileManager.default.temporaryDirectory
                .appendingPathComponent("volume-annotations-index-\(UUID().uuidString)", isDirectory: true)
            defer { if kept == nil { try? FileManager.default.removeItem(at: folder) } }
            let database = try await buildIndex(of: files, in: folder)
            return try IndexAnnotationReader.read(database: database)
        }
    }

    /// Builds a full index of `files` in `folder` through the kit's own pipeline, at the current
    /// index version, as `ResolvedEdgeIndexRunner.buildIndex` does: the files are cloned into
    /// `folder/volumes`, since the pipeline indexes a folder, and no bundled resources are passed,
    /// since none reaches a row this generator reads.
    static func buildIndex(of files: [URL], in folder: URL) async throws -> URL {
        let volumes = folder.appendingPathComponent("volumes", isDirectory: true)
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        for file in files {
            let copy = volumes.appendingPathComponent(file.lastPathComponent)
            if FileManager.default.fileExists(atPath: copy.path) {
                try FileManager.default.removeItem(at: copy)
            }
            try FileManager.default.copyItem(at: file, to: copy)
        }
        let database = folder.appendingPathComponent("frus.db")
        let store = try FTS5Store(databaseURL: database)
        let pipeline = try IndexingPipeline(
            fts5Store: store, databaseURL: database, volumesDirectory: volumes,
            resources: .none, concurrencyLimit: 6, defaults: InMemoryIndexingStampStore())
        generatorLog("[VolumeAnnotationsIndex] indexing \(files.count) volumes at version \(IndexingPipeline.currentDateIndexVersion) in \(folder.path)…")
        let started = Date()
        try await pipeline.indexAllVolumes()
        generatorLog("[VolumeAnnotationsIndex] indexed in \(Int(Date().timeIntervalSince(started))) s")
        return database
    }

    /// Prints what the file holds: each category's carriers and onset.
    static func report(_ index: VolumeAnnotationsIndex, bytes: Int, to output: URL) {
        let documents = index.volumes.values.reduce(0) { $0 + $1.documents }
        generatorLog("[VolumeAnnotationsIndex] \(index.volumes.count) volumes, \(documents) documents, index version \(index.indexVersion)")
        for category in AnnotationCategory.allCases {
            let carriers = index.volumes.values.filter { $0.carries(category) }.count
            let carrying = index.volumes.values.reduce(0) { $0 + $1.count(category) }
            let onset = index.onset(of: category)?.rawValue ?? "-"
            generatorLog("[VolumeAnnotationsIndex]   \(category.rawValue): \(carriers) volumes, \(carrying) documents, onset \(onset)")
        }
        let sourceNotes = index.volumes.values.filter(\.carriesSourceNotes).count
        generatorLog("[VolumeAnnotationsIndex]   source notes (either form): \(sourceNotes) volumes, onset \(index.onset(where: \.carriesSourceNotes)?.rawValue ?? "-")")
        let gated = index.volumes.values.filter { $0.publishedBeforeEditorialOmissionsOrder && $0.count(.editorialOmissions) > 0 }
        generatorLog("[VolumeAnnotationsIndex]   editorial omissions counted and not carried, published before \(VolumeAnnotations.editorialOmissionsFromYear): \(gated.count) volumes, \(gated.reduce(0) { $0 + $1.count(.editorialOmissions) }) documents")
        generatorLog("[VolumeAnnotationsIndex] wrote \(bytes) bytes to \(output.path)")
    }
}
