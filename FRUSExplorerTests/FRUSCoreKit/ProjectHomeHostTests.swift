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

/// What Project Home's focus subjects, their editor's suggestions and the line under each lead read
/// of the kit, called as a host outside the app calls it (FRUS Explorer Light's S17f): the subject
/// vocabulary decoded from the bundled file, the suggestions over it (`ProjectFocusSuggestions`), and
/// `IndexingPipeline.documentSnippets(forKeys:maxLength:)` over the app's own index and over a copy
/// stripped of the writing and opened read-only, as such a host serves one. The suite imports the kit
/// `@testable`, so it cannot show that these are public; a host's own build does.
///
/// Version history:
///   1.0 — 2026-10-28 (FRUS Explorer Light S17f): initial implementation
@Suite("FRUSCoreKit — Project Home's subjects and lead lines, as a host calls them")
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

    private static func decode(_ json: String) throws -> VolumeSubjectProfiles {
        try JSONDecoder().decode(VolumeSubjectProfiles.self, from: Data(json.utf8))
    }

    @Test("The vocabulary lists each profiled subject once, by category, subcategory and name, with the volumes it reaches")
    func theVocabularyIsEachProfiledSubjectOnce() throws {
        let subjects = try Self.decode(Self.fixtureJSON).allSubjects
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
        #expect(try Self.decode("{}").allSubjects.isEmpty)
    }

    @Test("The editor suggests the subjects of the volumes a project engages: the most recurrent first, then the highest scored, then by name, none it chose, eight at most")
    func theEditorsSuggestions() throws {
        let profiles = try Self.decode(Self.fixtureJSON)
        func suggested(_ volumes: Set<String>, excluding chosen: Set<String> = []) -> [String] {
            ProjectFocusSuggestions.suggestions(engagedVolumeIds: volumes, profiles: profiles, excluding: chosen)
                .map(\.ref)
        }
        // "diplomacy" is on both volumes' profiles; then armistice's 0.94 before the blockade's 0.83.
        #expect(suggested(["frus_v1", "frus_v2"]) == ["diplomacy", "armistice", "blockade"])
        #expect(suggested(["frus_v1"]) == ["blockade", "diplomacy"])
        #expect(suggested(["frus_v1", "frus_v2"], excluding: ["diplomacy"]) == ["armistice", "blockade"])
        #expect(ProjectFocusSuggestions.suggestions(engagedVolumeIds: ["frus_v1", "frus_v2"], profiles: profiles,
                                                    excluding: [], limit: 1).map(\.ref) == ["diplomacy"])
        // A volume with no profile suggests nothing.
        #expect(suggested(["frus_v9"]).isEmpty)

        let tied = try Self.decode("""
            {"vocab": [{"r": "b", "n": "Beta", "c": "X", "s": "Y"}, {"r": "a", "n": "Alpha", "c": "X", "s": "Y"}],
             "profiles": [{"v": "v1", "e": [{"i": 0, "w": 0.5}, {"i": 1, "w": 0.5}]}]}
            """)
        #expect(ProjectFocusSuggestions.suggestions(engagedVolumeIds: ["v1"], profiles: tied, excluding: [])
                    .map(\.name) == ["Alpha", "Beta"])

        // The editor passes no limit: of a volume's ten subjects, the eight highest scored.
        let vocabulary = (0..<10).map { #"{"r": "s\#($0)", "n": "Subject \#($0)", "c": "X", "s": "Y"}"# }
        let entries = (0..<10).map { #"{"i": \#($0), "w": \#(Double(10 - $0) / 10)}"# }
        let ten = try Self.decode(#"{"vocab": [\#(vocabulary.joined(separator: ","))], "#
            + #""profiles": [{"v": "v1", "e": [\#(entries.joined(separator: ","))]}]}"#)
        #expect(ProjectFocusSuggestions.suggestions(engagedVolumeIds: ["v1"], profiles: ten, excluding: [])
                    .map(\.ref) == (0..<8).map { "s\($0)" })
    }

    /// The bundled file as its generator writes it, read without the kit: each vocabulary row's ref
    /// and name, and each profile's volume and the rows it names.
    private struct RawFile: Decodable {
        struct Vocab: Decodable { let r: String; let n: String; let c: String; let s: String }
        struct Profile: Decodable {
            struct Entry: Decodable { let i: Int }
            let v: String
            let e: [Entry]
        }
        let vocab: [Vocab]
        let profiles: [Profile]
    }

    @Test("The bundled vocabulary decodes from its file: each subject its profiles name, once, in order, with the volumes it reaches")
    func theBundledVocabularyDecodes() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/Resources/volume-subject-profiles-index.json")
        let data = try Data(contentsOf: url)
        let subjects = try JSONDecoder().decode(VolumeSubjectProfiles.self, from: data).allSubjects

        // What the file itself says, counted here: the volumes whose profile names each ref.
        let raw = try JSONDecoder().decode(RawFile.self, from: data)
        var volumes: [String: Set<String>] = [:]
        for profile in raw.profiles {
            for entry in profile.e where raw.vocab.indices.contains(entry.i) {
                volumes[raw.vocab[entry.i].r, default: []].insert(profile.v)
            }
        }
        #expect(subjects.count > 100, "\(subjects.count) subjects")
        // Each ref once, which `ProjectFocusSuggestions` relies on: it keys the vocabulary by ref.
        #expect(Set(subjects.map(\.ref)).count == subjects.count, "a ref is listed twice")
        #expect(Set(subjects.map(\.ref)) == Set(volumes.keys))
        #expect(subjects.allSatisfy { !$0.name.isEmpty && !$0.category.isEmpty })
        let order = subjects.map { [$0.category, $0.subcategory, $0.name] }
        #expect(order == order.sorted { $0.lexicographicallyPrecedes($1) })
        for subject in subjects {
            #expect(subject.volumeCount == volumes[subject.ref]?.count, "\(subject.ref): \(subject.volumeCount)")
        }
    }

    // MARK: A lead's line

    private static let volumeId = "frus1971v01"

    private static func key(_ documentId: String) -> String { "\(volumeId)/\(documentId)" }

    /// d1's two paragraphs, which together run past a lead's 240 characters.
    private static let longParagraphs = [
        "The Ambassador called on the Foreign Minister this morning to convey the President's views "
            + "on the forthcoming conference, and stressed that the United States would not accept "
            + "any arrangement that left the question of access unsettled.",
        "The Minister replied that his government shared that concern, but asked for time to consult "
            + "its allies before the ministers met in Brussels next week.",
    ]

    /// d1's line: its text, which the index stores from the head on and which runs to 397 characters,
    /// stopped at the last word within 240.
    private static let d1Line = "1. Telegram The Ambassador called on the Foreign Minister this morning to convey "
        + "the President's views on the forthcoming conference, and stressed that the United States would not "
        + "accept any arrangement that left the question of access…"

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

    /// Indexes the volume read-write, as the app's index is built, and writes d3's summary and d4's
    /// empty one into it, as the app writes a summary into its index.
    private func appIndex(in dir: URL) async throws -> (pipeline: IndexingPipeline, database: URL, volumes: URL) {
        let database = dir.appendingPathComponent("built.db")
        let volumes = dir.appendingPathComponent("volumes", isDirectory: true)
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        try writeVolume(in: volumes)
        let pipeline = try IndexingPipeline(fts5Store: try FTS5Store(databaseURL: database), databaseURL: database,
                                            volumesDirectory: volumes, resources: .none,
                                            defaults: InMemoryIndexingStampStore())
        try await pipeline.indexVolume(Self.volumeId)
        try await pipeline.updateSummaryText(volumeId: Self.volumeId, documentId: "d3",
                                             responseText: "  A summary,\n  in its own   words.  ")
        try await pipeline.updateSummaryText(volumeId: Self.volumeId, documentId: "d4", responseText: "")
        return (pipeline, database, volumes)
    }

    /// Copies the app's index page for page with SQLite's backup API, out of write-ahead-log mode,
    /// strips the copy with `ResearchDatabaseStrip.steps` on one connection, as an export made without
    /// the writing is stripped and as FRUS Explorer Light strips one made with it, and opens it
    /// read-only, as such a host serves it.
    private func servedCopy(of built: URL, volumes: URL, in dir: URL) throws -> IndexingPipeline {
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
        for step in ResearchDatabaseStrip.steps {
            #expect(sqlite3_exec(target, step.sql, nil, nil, nil) == SQLITE_OK, "\(step.action)")
        }
        #expect(sqlite3_close(target) == SQLITE_OK && sqlite3_close(source) == SQLITE_OK)
        try? FileManager.default.removeItem(at: served.appendingPathComponent("frus.db-shm"))

        let pipeline = try IndexingPipeline(readingIndexAt: database, fts5Store: try FTS5Store(readingDatabaseAt: database),
                                            resources: .none, volumesDirectory: volumes)
        #expect(pipeline.isReadOnly)
        return pipeline
    }

    @Test("On the app's index a lead's line is its summary, folded, or else its text from the head on, cut at a word; a document the index lacks has none")
    func onTheAppsIndexALeadsLineIsItsSummaryOrItsText() async throws {
        try await withTempDir { dir in
            let pipeline = try await appIndex(in: dir).pipeline
            let keys = ["d1", "d2", "d3", "d4", "d99"].map { (volumeId: Self.volumeId, documentId: $0) }
                + [(volumeId: "frus1971v02", documentId: "d1")]
            // Neither the document the volume lacks nor the volume the index lacks has a line, and an
            // empty summary is none, so d4's line is its text.
            #expect(try await pipeline.documentSnippets(forKeys: keys) == [
                Self.key("d1"): Self.d1Line,
                Self.key("d2"): "2. Memorandum Short text, on two lines.",
                Self.key("d3"): "A summary, in its own words.",
                Self.key("d4"): "4. Note Text four.",
            ])
        }
    }

    @Test("On a host's copy, stripped of the writing and opened read-only, every lead's line is its text: the summary went with the writing")
    func onAServedCopyEveryLeadsLineIsItsText() async throws {
        try await withTempDir { dir in
            let built = try await appIndex(in: dir)
            let pipeline = try servedCopy(of: built.database, volumes: built.volumes, in: dir)
            let keys = ["d1", "d2", "d3", "d4", "d99"].map { (volumeId: Self.volumeId, documentId: $0) }
            #expect(try await pipeline.documentSnippets(forKeys: keys) == [
                Self.key("d1"): Self.d1Line,
                Self.key("d2"): "2. Memorandum Short text, on two lines.",
                Self.key("d3"): "3. Letter The letter's own text.",
                Self.key("d4"): "4. Note Text four.",
            ])
        }
    }

    @Test("A shorter line stops at a word too, keys past the first 400 are read, and no keys read nothing")
    func aShorterLineAndManyKeys() async throws {
        try await withTempDir { dir in
            let built = try await appIndex(in: dir)
            let pipeline = try servedCopy(of: built.database, volumes: built.volumes, in: dir)
            let short = try await pipeline.documentSnippets(forKeys: [(volumeId: Self.volumeId, documentId: "d2")],
                                                            maxLength: 20)
            #expect(short == [Self.key("d2"): "2. Memorandum Short…"])

            // 446 documents the index lacks, then the four it has: the statement reads 400 keys at a
            // time, so the four are in its second read.
            let keys = (1...446).map { (volumeId: Self.volumeId, documentId: "missing\($0)") }
                + ["d1", "d2", "d3", "d4"].map { (volumeId: Self.volumeId, documentId: $0) }
            let lines = try await pipeline.documentSnippets(forKeys: keys)
            #expect(lines.keys.sorted() == ["d1", "d2", "d3", "d4"].map(Self.key))

            #expect(try await pipeline.documentSnippets(forKeys: []).isEmpty)
        }
    }
}
