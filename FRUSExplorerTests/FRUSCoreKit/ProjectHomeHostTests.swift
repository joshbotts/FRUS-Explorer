// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif
// The package builds FTS5Store as a module of its own; Xcode compiles it into the app.
#if canImport(FTS5Store)
import FTS5Store
#endif
// SQLite3 is the system's on Apple platforms; on Linux the web edition supplies CSQLite.
#if canImport(SQLite3)
import SQLite3
#else
import CSQLite
#endif

// MARK: - ProjectHomeHostTests

/// Project Home's focus subjects and the line under each of its leads, read through the kit as a
/// host outside the app reads them (FRUS Explorer Light's S17f): the subject vocabulary decoded from
/// the bundled file, a project's focus subjects taken from it as `ProjectHomeView` takes them, the
/// subjects their editor suggests (`ProjectFocusSuggestions`), and each lead's line from
/// `IndexingPipeline.documentSnippets(forKeys:maxLength:)` over an index opened read-only, as such a
/// host serves the app's exported index.
///
/// Version history:
///   1.0 — 2026-10-28 (FRUS Explorer Light S17f): initial implementation
@Suite("FRUSCoreKit — Project Home's subjects and lead lines, read as a host reads them")
struct ProjectHomeHostTests {

    // MARK: The subject vocabulary

    /// A profiles file of the bundled file's shape: four subjects, three of them on a volume's
    /// profile, and one profile row whose index is out of range.
    private static let fixtureJSON = """
        {
          "schemaVersion": 1,
          "generated": "2026-06-16",
          "provenance": "test",
          "vocab": [
            {"r": "blockade", "n": "Naval Blockade", "c": "Warfare", "s": "General"},
            {"r": "diplomacy", "n": "Diplomacy", "c": "Bilateral Relations", "s": "General"},
            {"r": "armistice", "n": "Armistice", "c": "Politico-Military Issues", "s": "Peace"},
            {"r": "unprofiled", "n": "Aviation", "c": "Science and Technology", "s": "Aviation"}
          ],
          "profiles": [
            {"v": "frus_v1", "e": [{"i": 0, "w": 0.83}, {"i": 1, "w": 0.37}, {"i": 9, "w": 0.30}]},
            {"v": "frus_v2", "e": [{"i": 2, "w": 0.94}, {"i": 1, "w": 0.56}]}
          ]
        }
        """

    /// The bundled file, read from the repository as a host reads its own copy of it.
    private static func bundledProfiles() throws -> VolumeSubjectProfiles {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/Resources/volume-subject-profiles-index.json")
        return try JSONDecoder().decode(VolumeSubjectProfiles.self, from: Data(contentsOf: url))
    }

    @Test("The vocabulary lists each profiled subject once, by category, subcategory and name, with the volumes it reaches")
    func theVocabularyIsEachProfiledSubjectOnce() throws {
        let profiles = try JSONDecoder().decode(VolumeSubjectProfiles.self, from: Data(Self.fixtureJSON.utf8))
        let subjects = profiles.allSubjects
        #expect(subjects.map(\.ref) == ["diplomacy", "armistice", "blockade"])
        #expect(subjects.map(\.id) == subjects.map(\.ref))
        #expect(subjects.map(\.name) == ["Diplomacy", "Armistice", "Naval Blockade"])
        #expect(subjects.map(\.category) == ["Bilateral Relations", "Politico-Military Issues", "Warfare"])
        #expect(subjects.map(\.subcategory) == ["General", "Peace", "General"])
        // "diplomacy" is on both profiles; a subject on none is not offered, and the row whose index
        // names no subject counts for nothing.
        #expect(subjects.map(\.volumeCount) == [2, 1, 1])
    }

    @Test("A file that holds nothing decodes to an empty vocabulary")
    func anEmptyFileDecodesToNoSubjects() throws {
        let profiles = try JSONDecoder().decode(VolumeSubjectProfiles.self, from: Data("{}".utf8))
        #expect(profiles.allSubjects.isEmpty)
    }

    @Test("A project's focus subjects are the vocabulary's that it chose, in the vocabulary's order, a ref it no longer names left out")
    func aProjectsFocusSubjectsAreTheVocabularys() throws {
        let profiles = try JSONDecoder().decode(VolumeSubjectProfiles.self, from: Data(Self.fixtureJSON.utf8))
        // `ProjectHomeView.focusSubjectsSection`'s filter, over a project's `defaultSubjectTagIds`.
        let chosen = ["blockade", "retired-ref", "diplomacy"]
        let subjects = profiles.allSubjects.filter { chosen.contains($0.ref) }
        #expect(subjects.map(\.name) == ["Diplomacy", "Naval Blockade"])
    }

    @Test("The editor suggests the subjects of the volumes a project engages: the most recurrent first, then the highest scored, then by name, none it chose")
    func theEditorsSuggestions() throws {
        let profiles = try JSONDecoder().decode(VolumeSubjectProfiles.self, from: Data(Self.fixtureJSON.utf8))
        func suggested(_ volumes: Set<String>, excluding chosen: Set<String> = [], limit: Int = 8) -> [String] {
            ProjectFocusSuggestions.suggestions(engagedVolumeIds: volumes, profiles: profiles, excluding: chosen,
                                                limit: limit).map(\.ref)
        }
        // "diplomacy" is on both volumes' profiles; then armistice's 0.94 before the blockade's 0.83.
        #expect(suggested(["frus_v1", "frus_v2"]) == ["diplomacy", "armistice", "blockade"])
        #expect(suggested(["frus_v1"]) == ["blockade", "diplomacy"])
        #expect(suggested(["frus_v1", "frus_v2"], excluding: ["diplomacy"]) == ["armistice", "blockade"])
        #expect(suggested(["frus_v1", "frus_v2"], limit: 1) == ["diplomacy"])
        // A volume with no profile suggests nothing.
        #expect(suggested(["frus_v9"]).isEmpty)

        let tied = try JSONDecoder().decode(VolumeSubjectProfiles.self, from: Data("""
            {"vocab": [{"r": "b", "n": "Beta", "c": "X", "s": "Y"}, {"r": "a", "n": "Alpha", "c": "X", "s": "Y"}],
             "profiles": [{"v": "v1", "e": [{"i": 0, "w": 0.5}, {"i": 1, "w": 0.5}]}]}
            """.utf8))
        #expect(ProjectFocusSuggestions.suggestions(engagedVolumeIds: ["v1"], profiles: tied, excluding: [])
                    .map(\.name) == ["Alpha", "Beta"])
    }

    @Test("The bundled vocabulary decodes from its file, each subject once and in order, each reaching a volume")
    func theBundledVocabularyDecodes() throws {
        let profiles = try Self.bundledProfiles()
        let subjects = profiles.allSubjects
        #expect(subjects.count > 100, "\(subjects.count) subjects")
        #expect(Set(subjects.map(\.ref)).count == subjects.count, "a ref is listed twice")
        #expect(subjects.allSatisfy { !$0.ref.isEmpty && !$0.name.isEmpty && !$0.category.isEmpty })
        let keys = subjects.map { [$0.category, $0.subcategory, $0.name] }
        #expect(keys == keys.sorted { $0.lexicographicallyPrecedes($1) })
        for subject in subjects {
            #expect(subject.volumeCount >= 1
                    && subject.volumeCount == Set(profiles.volumesBySubjectRef[subject.ref] ?? []).count,
                    "\(subject.ref): \(subject.volumeCount)")
        }
    }

    // MARK: A lead's line

    private static let volumeId = "frus1971v01"

    /// d1's two paragraphs, which together run past a lead's 240 characters.
    private static let longParagraphs = [
        "The Ambassador called on the Foreign Minister this morning to convey the President's views "
            + "on the forthcoming conference, and stressed that the United States would not accept "
            + "any arrangement that left the question of access unsettled.",
        "The Minister replied that his government shared that concern, but asked for time to consult "
            + "its allies before the ministers met in Brussels next week.",
    ]

    /// A temporary directory for `body`, removed after it.
    private func withTempDir<T>(_ body: (URL) async throws -> T) async throws -> T {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSProjectHome-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        return try await body(dir)
    }

    /// Writes a volume of four documents: d1 long, d2 short with its text broken over lines, d3 and
    /// d4 with a summary written below.
    private func writeVolume(in volumes: URL) throws {
        let paragraphs = Self.longParagraphs.map { "<p>\($0)</p>" }.joined(separator: "\n      ")
        let xml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <TEI xmlns="http://www.tei-c.org/ns/1.0">
              <teiHeader><fileDesc><titleStmt><title>\(Self.volumeId)</title></titleStmt>
              <publicationStmt><date>1971</date></publicationStmt>
              <sourceDesc><p>Test fixture</p></sourceDesc></fileDesc></teiHeader>
              <text><body><div type="compilation" xml:id="comp1">
                <div type="document" xml:id="d1" n="1"><head>1. Telegram</head>
                  \(paragraphs)</div>
                <div type="document" xml:id="d2" n="2"><head>2. Memorandum</head>
                  <p>Short   text,
                     on two lines.</p></div>
                <div type="document" xml:id="d3" n="3"><head>3. Letter</head><p>The letter's own text.</p></div>
                <div type="document" xml:id="d4" n="4"><head>4. Note</head><p>Text four.</p></div>
              </div></body></text>
            </TEI>
            """
        try Data(xml.utf8).write(to: volumes.appendingPathComponent("\(Self.volumeId).xml"))
    }

    /// Indexes the volume read-write and writes d3's summary and d4's empty one, then copies the index
    /// page for page with SQLite's backup API, out of write-ahead-log mode, as an export is made, and
    /// opens the copy read-only, as a host serves it.
    private func servedPipeline(in dir: URL) async throws -> IndexingPipeline {
        let built = dir.appendingPathComponent("built.db")
        let volumes = dir.appendingPathComponent("volumes", isDirectory: true)
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        try writeVolume(in: volumes)
        let writer = try IndexingPipeline(fts5Store: try FTS5Store(databaseURL: built), databaseURL: built,
                                          volumesDirectory: volumes, resources: .none,
                                          defaults: InMemoryIndexingStampStore())
        try await writer.indexVolume(Self.volumeId)
        try await writer.updateSummaryText(volumeId: Self.volumeId, documentId: "d3",
                                           responseText: "  A summary,\n  in its own   words.  ")
        try await writer.updateSummaryText(volumeId: Self.volumeId, documentId: "d4", responseText: "")

        let served = dir.appendingPathComponent("served", isDirectory: true)
        try FileManager.default.createDirectory(at: served, withIntermediateDirectories: true)
        let database = served.appendingPathComponent("frus.db")
        var source: OpaquePointer?, target: OpaquePointer?
        try #require(sqlite3_open_v2(built.path, &source, SQLITE_OPEN_READONLY, nil) == SQLITE_OK)
        try #require(sqlite3_open_v2(database.path, &target, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK)
        let backup = try #require(sqlite3_backup_init(target, "main", source, "main"))
        #expect(sqlite3_backup_step(backup, -1) == SQLITE_DONE)
        sqlite3_backup_finish(backup)
        #expect(sqlite3_exec(target, "PRAGMA journal_mode=DELETE", nil, nil, nil) == SQLITE_OK)
        #expect(sqlite3_close(target) == SQLITE_OK && sqlite3_close(source) == SQLITE_OK)
        try? FileManager.default.removeItem(at: served.appendingPathComponent("frus.db-shm"))

        let pipeline = try IndexingPipeline(readingIndexAt: database, fts5Store: try FTS5Store(readingDatabaseAt: database),
                                            resources: .none, volumesDirectory: volumes)
        #expect(pipeline.isReadOnly)
        return pipeline
    }

    @Test("A lead's line is its summary, or else its opening text, whitespace folded and cut at a word, keyed volume/document")
    func aLeadsLineIsItsSummaryOrItsOpeningText() async throws {
        try await withTempDir { dir in
            let pipeline = try await servedPipeline(in: dir)
            let keys = ["d1", "d2", "d3", "d4", "d99"].map { (volumeId: Self.volumeId, documentId: $0) }
                + [(volumeId: "frus1971v02", documentId: "d1")]
            let lines = try await pipeline.documentSnippets(forKeys: keys)

            // Neither the document the volume lacks nor the volume the index lacks has a line.
            #expect(lines.keys.sorted() == ["d1", "d2", "d3", "d4"].map { "\(Self.volumeId)/\($0)" })
            // A summary, folded; an empty one is no summary, so d4's line is its text, which the index
            // stores from its head on, as the page prints it.
            #expect(lines["\(Self.volumeId)/d3"] == "A summary, in its own words.")
            #expect(lines["\(Self.volumeId)/d4"] == "4. Note Text four.")
            #expect(lines["\(Self.volumeId)/d2"] == "2. Memorandum Short text, on two lines.")
            // d1's text runs to 397 characters: its line stops at the last word within 240.
            #expect(lines["\(Self.volumeId)/d1"] == "1. Telegram The Ambassador called on the Foreign Minister "
                        + "this morning to convey the President's views on the forthcoming conference, and stressed "
                        + "that the United States would not accept any arrangement that left the question of access…")
        }
    }

    @Test("A shorter line stops at a word too, keys past the first 400 are read, and no keys read nothing")
    func aShorterLineAndManyKeys() async throws {
        try await withTempDir { dir in
            let pipeline = try await servedPipeline(in: dir)
            let short = try await pipeline.documentSnippets(forKeys: [(volumeId: Self.volumeId, documentId: "d2")],
                                                            maxLength: 20)
            #expect(short == ["\(Self.volumeId)/d2": "2. Memorandum Short…"])

            // 446 documents the index lacks, then the four it has: the statement reads 400 keys at a
            // time, so the four are in its second read.
            let keys = (1...446).map { (volumeId: Self.volumeId, documentId: "missing\($0)") }
                + ["d1", "d2", "d3", "d4"].map { (volumeId: Self.volumeId, documentId: $0) }
            let lines = try await pipeline.documentSnippets(forKeys: keys)
            #expect(lines.keys.sorted() == ["d1", "d2", "d3", "d4"].map { "\(Self.volumeId)/\($0)" })

            #expect(try await pipeline.documentSnippets(forKeys: []).isEmpty)
        }
    }
}
