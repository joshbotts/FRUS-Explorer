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
import SourceProvenanceIndexGeneratorCore

// MARK: - CollectionUsageIndexRunner

/// Builds `collection-usage-index.json` (#763) — the document-weighted half of the archival
/// analytics substrate.
///
/// One pass over the shippable corpus, reusing the surfaces `SourceExplorerExportGenerator`
/// already pins to the app: `DocumentNoteExtractor` for the note text the app itself stores,
/// `SourceNoteParser` for the parse, `ProvenanceCategory.from` for the category, `AuthorityLookup`
/// for the collection (the app's four-step lookup, ported), and
/// `ExportClassification.derivedKeys` for the class key (gated exactly as the app gates it). The
/// export writes one record per document; this writes the aggregate, so the two agree by
/// construction rather than by review.
///
/// Entirely offline and deterministic: filename-sorted scan, sorted vocabularies, rows sorted by
/// key, `.sortedKeys` on the encoder.
///
/// **Rebuild it, never derive it from an existing export.** The committed export is a snapshot,
/// and the authority is re-clustered independently — measured on the 2026-07-29 export against
/// the 2026-08-06 authority, 28 collection ids no longer existed (2,040 documents, including the
/// largest presidential-library collection), because #696 folded `president's ` to
/// `presidential `. An aggregate joined across that gap loses whole collections silently.
///
/// Version history:
///   1.0 — Session 2026-08-08: #763
public enum CollectionUsageIndexRunner {

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
            outputPath: env["OUTPUT"] ?? "FRUSExplorer/Resources/collection-usage-index.json",
            generated: generatorDateStamp(override: env["GENERATED_DATE"]))
    }

    /// The parameterized build, callable from tests without touching the environment.
    public static func run(volumesDir: URL, manifestPath: String,
                           collectionAuthorityPath: String, outputPath: String,
                           generated: String) throws {
        let authorityURL = URL(fileURLWithPath: collectionAuthorityPath)
        let authority = try AuthorityLookup(indexURL: authorityURL)
        let authorityCount = try authorityRecordCount(at: authorityURL)
        let shippable = try shippableVolumeIds(manifestPath: manifestPath)

        let allFiles = try VolumeCorpusEnumerator.volumeFiles(in: volumesDir)
        let files = allFiles.filter { shippable.contains(VolumeCorpusEnumerator.volumeId(for: $0)) }
        guard !files.isEmpty else { throw GeneratorError.noVolumes(volumesDir.path) }
        generatorLog("[CollectionUsage] \(files.count) shippable volumes of \(allFiles.count) on disk")

        let index = try build(files: files, authority: authority,
                              authorityCollectionCount: authorityCount, generated: generated)

        // Compact, not pretty: this artifact is machine-read and shipped in the bundle, and
        // pretty-printing it costs 68% more bytes for a file nobody reads by eye.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(index)
        try data.write(to: URL(fileURLWithPath: outputPath))

        generatorLog("""
        [CollectionUsage] done — \(data.count) bytes
          volumes:     \(index.volumes.count) scanned, \(index.coverage.volumesWithNotes) with notes
          notes:       \(index.coverage.noteCount)
          collections: \(index.collections.count) reached of \(authorityCount) in the authority \
        (\(percent(index.coverage.authorityCollectionsReached, of: authorityCount)))
          classes:     \(index.classes.count)
          in a collection: \(index.coverage.notesInACollection) \
        (\(percent(index.coverage.notesInACollection, of: index.coverage.noteCount)))
          with a class:    \(index.coverage.notesWithAClassKey) \
        (\(percent(index.coverage.notesWithAClassKey, of: index.coverage.noteCount)))
          output: \(outputPath)
        """)
    }

    // MARK: - The build

    /// Scans `files` and aggregates. Pure apart from reading the volume bytes, so tests drive it
    /// over a fixture corpus.
    public static func build(files: [URL], authority: AuthorityLookup,
                             authorityCollectionCount: Int,
                             generated: String) throws -> CollectionUsageIndex {
        let parser = SourceNoteParser()

        // (key, volumeId) → document count, accumulated over the whole scan.
        var byCollection: [String: [String: Int]] = [:]
        var byClass: [String: [String: Int]] = [:]
        var byCategory: [String: [String: Int]] = [:]
        var notesPerVolume: [String: Int] = [:]
        var volumeIds: [String] = []
        var noteCount = 0
        var notesInACollection = 0
        var notesWithAClassKey = 0

        for file in files {
            // An unreadable volume fails the run. A skipped one would silently shrink every
            // count in the artifact while the build still reported success.
            let data = try Data(contentsOf: file)
            let volumeId = VolumeCorpusEnumerator.volumeId(for: file)
            volumeIds.append(volumeId)

            let notes = DocumentNoteExtractor.extract(fromXML: data)
            notesPerVolume[volumeId] = notes.count
            noteCount += notes.count

            for note in notes {
                let parsed = parser.parse(note.note)
                byCategory[ProvenanceCategory.from(parsed).rawValue, default: [:]][volumeId,
                                                                                  default: 0] += 1
                if let record = authority.record(forParsed: parsed, note: note.note) {
                    byCollection[record.id, default: [:]][volumeId, default: 0] += 1
                    notesInACollection += 1
                }
                if let classKey = ExportClassification
                    .derivedKeys(for: parsed, note: note.note).decimalClass {
                    byClass[classKey, default: [:]][volumeId, default: 0] += 1
                    notesWithAClassKey += 1
                }
            }
        }

        // A run that resolves nothing is a broken join, not an empty corpus — and an artifact of
        // zeroes would disable the feature while the build exited 0. (The first LotClaimants run
        // shipped exactly that shape; the guard is why this one cannot.)
        guard !byCollection.isEmpty, !byClass.isEmpty else {
            throw CollectionUsageError.brokenJoin(
                collections: byCollection.count, classes: byClass.count,
                notes: noteCount, volumes: files.count)
        }

        let volumes = volumeIds.sorted()
        let volumeIndex = Dictionary(uniqueKeysWithValues: volumes.enumerated().map { ($1, $0) })
        let collectionIds = byCollection.keys.sorted()
        let classKeys = byClass.keys.sorted()
        let categories = ProvenanceCategory.orderedCases.map(\.rawValue)

        return CollectionUsageIndex(
            schemaVersion: schemaVersion,
            generated: generated,
            volumes: volumes,
            volumeNoteCounts: volumes.map { notesPerVolume[$0] ?? 0 },
            collectionIds: collectionIds,
            classKeys: classKeys,
            categories: categories,
            collections: rows(byCollection, keys: collectionIds, volumeIndex: volumeIndex),
            classes: rows(byClass, keys: classKeys, volumeIndex: volumeIndex),
            volumeCategories: rows(byCategory, keys: categories, volumeIndex: volumeIndex),
            coverage: CollectionUsageIndex.Coverage(
                volumesScanned: volumes.count,
                volumesWithNotes: notesPerVolume.values.filter { $0 > 0 }.count,
                noteCount: noteCount,
                notesInACollection: notesInACollection,
                notesWithAClassKey: notesWithAClassKey,
                authorityCollectionCount: authorityCollectionCount,
                authorityCollectionsReached: collectionIds.count))
    }

    /// Interns one accumulator into sorted ``CollectionUsageIndex/UsageRow`` values.
    ///
    /// Keys with no documents are dropped rather than stored empty — the category vocabulary is
    /// fixed at ten, and a category the corpus never uses should not occupy a row.
    private static func rows(_ accumulator: [String: [String: Int]], keys: [String],
                             volumeIndex: [String: Int]) -> [CollectionUsageIndex.UsageRow] {
        keys.enumerated().compactMap { keyIndex, key in
            guard let perVolume = accumulator[key], !perVolume.isEmpty else { return nil }
            let ordered = perVolume
                .compactMap { volumeId, count in volumeIndex[volumeId].map { ($0, count) } }
                .sorted { $0.0 < $1.0 }
            guard !ordered.isEmpty else { return nil }
            return CollectionUsageIndex.UsageRow(key: keyIndex,
                                                 volumes: ordered.map(\.0),
                                                 counts: ordered.map(\.1))
        }
    }

    // MARK: - Support

    /// The manifest's shippable volume-id set (the app's universe).
    static func shippableVolumeIds(manifestPath: String) throws -> Set<String> {
        struct ManifestVolume: Decodable { let volumeId: String }
        let url = URL(fileURLWithPath: manifestPath)
        let volumes = try JSONDecoder().decode([ManifestVolume].self, from: Data(contentsOf: url))
        return Set(volumes.map(\.volumeId))
    }

    /// How many records the authority carries — the denominator for "reached".
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

// MARK: - CollectionUsageError

/// The one fatal condition this generator adds to ``GeneratorError``.
public enum CollectionUsageError: Error, CustomStringConvertible {
    /// The scan finished with nothing joined — a broken lookup, not an empty corpus.
    case brokenJoin(collections: Int, classes: Int, notes: Int, volumes: Int)

    public var description: String {
        switch self {
        case .brokenJoin(let collections, let classes, let notes, let volumes):
            return """
            Refusing to write an empty index: \(notes) notes across \(volumes) volumes produced \
            \(collections) collections and \(classes) classes. An artifact of zeroes disables the \
            feature while the build exits 0 — check the authority path and the corpus first.
            """
        }
    }
}
