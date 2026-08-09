// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import CollectionUsageIndexGeneratorCore
import CollectionAuthorityGeneratorCore
import SourceExplorerExportGeneratorCore

// MARK: - CollectionUsageIndexGeneratorTests

/// The aggregation behind `collection-usage-index.json` (#763), driven over a fixture corpus.
///
/// The fixtures are real TEI shapes with real citation grammar, not hand-built accumulator
/// dictionaries: the whole value of this generator is that it runs the *app's* parser, class
/// gate, and authority lookup, so a test that skipped them would pin nothing that matters.
///
/// Version history:
///   1.0 — Session 2026-08-08: #763
@Suite("Collection usage index — generator")
struct CollectionUsageIndexGeneratorTests {

    // MARK: - Fixtures

    /// Two collections the fixture notes resolve to, by two different lookup steps.
    private func fixtureAuthority() -> AuthorityLookup {
        AuthorityLookup(collections: [
            AuthorityCollection(id: "lot:64D199", name: "Conference Files",
                                lotFileNorm: "64D199", naId: "1000"),
            AuthorityCollection(id: "txt:johnson library|national security file",
                                name: "National Security File",
                                repository: "Johnson Library", naId: "2000"),
        ])
    }

    /// One volume whose documents carry `notes` as their source notes.
    private func volume(_ id: String, notes: [String], in directory: URL) throws -> URL {
        let documents = notes.enumerated().map { index, note in
            """
              <div type="document" xml:id="d\(index + 1)">
                <head>Document \(index + 1)</head>
                <note type="source">\(note)</note>
                <p>Body.</p>
              </div>
            """
        }.joined(separator: "\n")
        let xml = """
        <TEI xmlns:frus="http://history.state.gov/frus/ns/1.0">
          <text><body>
        \(documents)
          </body></text>
        </TEI>
        """
        let url = directory.appendingPathComponent("\(id).xml")
        try Data(xml.utf8).write(to: url)
        return url
    }

    /// A corpus directory holding the three fixture volumes, plus its file list in scan order.
    private func fixtureCorpus() throws -> [URL] {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("usage-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return [
            try volume("frus1952-54v01", notes: [
                "Source: Department of State, Conference Files: Lot 64 D 199, CF 100.",
                "Source: Department of State, Conference Files: Lot 64 D 199, CF 101.",
                // The exact decimal shape SourceNoteParserGrammarTests pins, en dash and all.
                "Source: Department of State, Central Files, 611.41/3–553. Secret.",
            ], in: root),
            try volume("frus1964-68v02", notes: [
                "Source: Johnson Library, National Security File, Country File, Vietnam.",
                "Source: Department of State, Conference Files: Lot 64 D 199, CF 200.",
            ], in: root),
            // A volume with no source notes at all — 51 shippable volumes are like this.
            try volume("frus1969-76v03", notes: [], in: root),
        ]
    }

    private func build(_ files: [URL]) throws -> CollectionUsageIndex {
        try CollectionUsageIndexRunner.build(files: files, authority: fixtureAuthority(),
                                             authorityCollectionCount: 2,
                                             generated: "2026-08-08")
    }

    // MARK: - Aggregation

    @Test("Documents are counted per collection and per volume, through the app's own lookup")
    func aggregatesByCollectionAndVolume() throws {
        let index = try build(try fixtureCorpus())

        let conference = try #require(row(index.collections, forKey: "lot:64D199",
                                          in: index.collectionIds))
        #expect(total(conference) == 3, "three documents cite Lot 64 D 199 across two volumes")
        #expect(volumeIds(conference, in: index) == ["frus1952-54v01", "frus1964-68v02"])
        #expect(conference.counts == [2, 1])

        let nsf = try #require(row(index.collections,
                                   forKey: "txt:johnson library|national security file",
                                   in: index.collectionIds))
        #expect(total(nsf) == 1)
        #expect(volumeIds(nsf, in: index) == ["frus1964-68v02"])
    }

    @Test("A central-file citation contributes its class, and a lot citation does not")
    func aggregatesClasses() throws {
        let index = try build(try fixtureCorpus())
        #expect(index.classKeys == ["611.41"], """
            The class vocabulary should hold exactly the one decimal class in the fixture. \
            Lot-file citations must not contribute a class — the gate is central-files-shaped \
            parses only (CollectionKeying.centralFilesClass). Got: \(index.classKeys)
            """)
        let cls = try #require(index.classes.first)
        #expect(cls.counts == [1])
        #expect(volumeIds(cls, in: index) == ["frus1952-54v01"])
    }

    @Test("Every scanned volume appears with its note total, including the ones with none")
    func volumeDenominatorsAreComplete() throws {
        let index = try build(try fixtureCorpus())
        #expect(index.volumes == ["frus1952-54v01", "frus1964-68v02", "frus1969-76v03"])
        #expect(index.volumeNoteCounts == [3, 2, 0], """
            A volume with no source notes must still appear, with zero. Dropping it would make \
            every per-volume share silently exclude it from the denominator.
            """)
        #expect(index.coverage.volumesScanned == 3)
        #expect(index.coverage.volumesWithNotes == 2)
        #expect(index.coverage.noteCount == 5)
    }

    @Test("Categories are counted for every note, including notes that resolve to nothing")
    func categoriesCoverEveryNote() throws {
        let index = try build(try fixtureCorpus())
        let counted = index.volumeCategories.reduce(0) { $0 + total($1) }
        #expect(counted == index.coverage.noteCount, """
            Every note has exactly one provenance category, so the category table must total the \
            note count — \(counted) vs \(index.coverage.noteCount). A note that resolved to no \
            collection and no class still belongs to a category, and that is the only table that \
            can carry it.
            """)
        #expect(index.coverage.notesInACollection == 4)
        #expect(index.coverage.notesWithAClassKey == 1)
    }

    @Test("Coverage reports what the scan reached, not what exists")
    func coverageIsHonest() throws {
        let index = try build(try fixtureCorpus())
        #expect(index.coverage.authorityCollectionCount == 2)
        #expect(index.coverage.authorityCollectionsReached == 2)
        #expect(index.coverage.notesInACollection < index.coverage.noteCount,
                "the fixture includes a note that resolves to no collection — the gap is the point")
    }

    // MARK: - Shape and determinism

    @Test("Rows are sorted, volume indices ascend, and the parallel arrays agree")
    func shapeInvariants() throws {
        let index = try build(try fixtureCorpus())
        for (label, rows) in [("collections", index.collections), ("classes", index.classes),
                              ("categories", index.volumeCategories)] {
            #expect(rows.map(\.key) == rows.map(\.key).sorted(),
                    "\(label) rows are not sorted by key — the diff would churn on every rebuild")
            for row in rows {
                #expect(row.volumes.count == row.counts.count, "\(label) row \(row.key) is ragged")
                #expect(row.volumes == row.volumes.sorted(), "\(label) row \(row.key) is unsorted")
                #expect(!row.volumes.isEmpty, "\(label) row \(row.key) is empty and should be absent")
                #expect(row.counts.allSatisfy { $0 > 0 }, "\(label) row \(row.key) stores a zero")
            }
        }
        #expect(index.volumes == index.volumes.sorted())
        #expect(index.collectionIds == index.collectionIds.sorted())
        #expect(index.classKeys == index.classKeys.sorted())
        #expect(index.volumeNoteCounts.count == index.volumes.count)
    }

    @Test("The same corpus in a different file order produces the same bytes")
    func buildIsDeterministic() throws {
        let files = try fixtureCorpus()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let forward = try encoder.encode(try build(files))
        let reversed = try encoder.encode(try build(files.reversed()))
        #expect(forward == reversed, """
            Scan order changed the artifact. Every rebuild would then produce a diff nobody can \
            review, and two machines would disagree about the same corpus.
            """)
    }

    @Test("A ragged row is refused on decode rather than read short")
    func raggedRowIsRefused() throws {
        let json = """
        {"categories":[],"classKeys":[],"classes":[],"collectionIds":["a"],
         "collections":[{"k":0,"n":[1],"v":[0,1]}],
         "coverage":{"authorityCollectionCount":1,"authorityCollectionsReached":1,
           "noteCount":1,"notesInACollection":1,"notesWithAClassKey":0,
           "volumesScanned":1,"volumesWithNotes":1},
         "generated":"2026-08-08","schemaVersion":1,"volumeCategories":[],
         "volumeNoteCounts":[1,1],"volumes":["v1","v2"]}
        """
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode(CollectionUsageIndex.self, from: Data(json.utf8))
        }
    }

    // MARK: - The refusal

    @Test("A corpus that joins to nothing throws instead of writing an index of zeroes")
    func brokenJoinThrows() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("usage-empty-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        // Notes that parse, but resolve to no collection in this authority and carry no class.
        let file = try volume("frus1900v01", notes: [
            "Printed from an unsigned copy.", "The original is in an unnamed private collection.",
        ], in: root)
        #expect(throws: CollectionUsageError.self) {
            _ = try CollectionUsageIndexRunner.build(
                files: [file], authority: self.fixtureAuthority(),
                authorityCollectionCount: 2, generated: "2026-08-08")
        }
    }

    // MARK: - Helpers

    private func row(_ rows: [CollectionUsageIndex.UsageRow], forKey key: String,
                     in vocabulary: [String]) -> CollectionUsageIndex.UsageRow? {
        guard let index = vocabulary.firstIndex(of: key) else { return nil }
        return rows.first { $0.key == index }
    }

    private func total(_ row: CollectionUsageIndex.UsageRow) -> Int { row.counts.reduce(0, +) }

    private func volumeIds(_ row: CollectionUsageIndex.UsageRow,
                           in index: CollectionUsageIndex) -> [String] {
        row.volumes.map { index.volumes[$0] }
    }
}
