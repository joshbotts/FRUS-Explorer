// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import SQLite3
import Testing
@testable import FRUSExplorer

// MARK: - FootnoteCitationContainmentTests

/// `document_sources` holds a document's **own** archival provenance, and nothing else.
///
/// Editorial-note body citations used to be written here with `citation_era = "footnote"`. Every
/// provenance query over the table counts rows without filtering the era — `localCollectionStats`,
/// the archival-neighbour clauses, the search facet's provenance section — so the collection
/// detail's "N documents in M of your indexed volumes cite this collection" silently blended two
/// different claims: documents *drawn from* an archive, and documents whose editor *mentioned* one
/// in a footnote.
///
/// The two tests below are the containment: nothing writes such a row now, and an index built
/// before the fix loses the ones it has on its next open rather than needing a reindex.
///
/// Version history:
///   1.0 — Session 2026-08-08: containment fix ahead of the footnote-citation feature
@Suite("Footnote citations stay out of document_sources")
struct FootnoteCitationContainmentTests {

    // MARK: - Fixtures

    /// Writes a volume whose documents carry the given raw inner XML.
    private func writeVolume(_ volumeId: String, documents: [(id: String, xml: String)],
                             to directory: URL) throws {
        let divs = documents.map { "<div type=\"document\" \($0.xml)" }.joined(separator: "\n")
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <teiHeader><fileDesc><titleStmt><title>\(volumeId)</title></titleStmt>
          <publicationStmt><date>2003</date></publicationStmt>
          <sourceDesc><p>Test fixture</p></sourceDesc></fileDesc></teiHeader>
          <text><body><div type="compilation" xml:id="comp1">
        \(divs)
          </div></body></text>
        </TEI>
        """
        try Data(xml.utf8).write(to: directory.appendingPathComponent("\(volumeId).xml"))
    }

    private func withTemporaryDirectory<T>(_ body: (URL) async throws -> T) async throws -> T {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("footnote-containment-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        return try await body(dir)
    }

    /// Every `citation_era` present for a volume, with its row count.
    private func eras(inDatabase url: URL, volumeId: String) throws -> [String: Int] {
        var handle: OpaquePointer?
        guard sqlite3_open_v2(url.path, &handle, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let db = handle else {
            sqlite3_close(handle)
            throw NSError(domain: "FootnoteContainment", code: 1)
        }
        defer { sqlite3_close_v2(db) }
        var statement: OpaquePointer?
        let sql = """
            SELECT citation_era, COUNT(*) FROM document_sources WHERE volume_id = ?
            GROUP BY citation_era
            """
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw NSError(domain: "FootnoteContainment", code: 2)
        }
        defer { sqlite3_finalize(statement) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(statement, 1, volumeId, -1, transient)
        var result: [String: Int] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            let era = sqlite3_column_text(statement, 0).map { String(cString: $0) } ?? ""
            result[era] = Int(sqlite3_column_int(statement, 1))
        }
        return result
    }

    // MARK: - Nothing writes a footnote row

    @Test("An editorial note citing an archive does not become a source-note row")
    func editorialNoteCitationIsNotProvenance() async throws {
        try await withTemporaryDirectory { dir in
            let volumes = dir.appendingPathComponent("volumes")
            try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
            // The citation shape must be one `extractCitations` actually recognises — it matches
            // only "National Archives, RG N, …" and "<Name> Library, <collection>…". A fixture
            // citing a bare lot number produces no row either way and would prove nothing.
            try writeVolume("frus1969-76v01", documents: [
                // A real document drawn from the collection: this one IS provenance.
                (id: "d1", xml: """
                    xml:id="d1"><head>1. Memorandum</head>
                    <note type="source">Source: Johnson Library, National Security File, Country File, Vietnam.</note>
                    <p>Text.</p></div>
                    """),
                // An editorial note that *mentions* the same collection. Before the fix this
                // produced a second `document_sources` row and the count read 2.
                (id: "d2", xml: """
                    xml:id="d2" subtype="editorial-note"><head>2. Editorial Note</head>
                    <p>The record of the conversation is in the Johnson Library, National Security
                    File, Country File, Vietnam, and was not printed.</p></div>
                    """),
            ], to: volumes)

            let dbURL = dir.appendingPathComponent("test.sqlite")
            let store = try FTS5Store(databaseURL: dbURL)
            let pipeline = try IndexingPipeline(fts5Store: store, databaseURL: dbURL,
                                                volumesDirectory: volumes, concurrencyLimit: 2)
            try await pipeline.indexVolume("frus1969-76v01")

            let stats = try await pipeline.localCollectionStats(
                lotFileNorm: nil, repository: "Johnson Library",
                recordGroup: nil, names: ["National Security File"])
            #expect(stats.documentCount == 1, """
                The collection's local count is \(stats.documentCount). Only d1 was drawn from \
                the National Security File; d2 is an editorial note that mentions it. Counting \
                both makes "N documents cite this collection" mean two things at once.
                """)
            #expect(stats.volumeCount == 1)

            let counts = try eras(inDatabase: dbURL, volumeId: "frus1969-76v01")
            #expect(counts["footnote"] == nil, """
                A `citation_era = 'footnote'` row was written: \(counts). The table's primary key \
                is (volume_id, document_id), one row per document, so it cannot hold the several \
                archives a footnote may cite — the old code kept the first and dropped the rest.
                """)
            #expect(counts.values.reduce(0, +) == 1, "only the source-note document belongs here")
        }
    }

    // MARK: - An index built before the fix repairs itself

    @Test("Footnote rows left by an older build are removed on the next open")
    func legacyFootnoteRowsAreCleanedUp() async throws {
        try await withTemporaryDirectory { dir in
            let volumes = dir.appendingPathComponent("volumes")
            try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
            try writeVolume("frus1969-76v01", documents: [
                (id: "d1", xml: """
                    xml:id="d1"><head>1. Memorandum</head>
                    <note type="source">Source: Department of State, Conference Files: Lot 64 D 199, CF 1.</note>
                    <p>Text.</p></div>
                    """),
            ], to: volumes)

            let dbURL = dir.appendingPathComponent("test.sqlite")
            do {
                let store = try FTS5Store(databaseURL: dbURL)
                let pipeline = try IndexingPipeline(fts5Store: store, databaseURL: dbURL,
                                                    volumesDirectory: volumes, concurrencyLimit: 2)
                try await pipeline.indexVolume("frus1969-76v01")
            }

            // Simulate what a pre-fix build left behind.
            var handle: OpaquePointer?
            #expect(sqlite3_open_v2(dbURL.path, &handle, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK)
            let legacy = """
                INSERT OR REPLACE INTO document_sources
                    (volume_id, document_id, repository, record_group, lot_file, lot_file_norm,
                     series_name, citation_era, raw_text)
                VALUES ('frus1969-76v01', 'd2', 'Department of State', '59',
                        'Lot 64 D 199', '64D199', NULL, 'footnote', 'mentioned in a footnote')
                """
            #expect(sqlite3_exec(handle, legacy, nil, nil, nil) == SQLITE_OK)
            sqlite3_close_v2(handle)
            #expect(try eras(inDatabase: dbURL, volumeId: "frus1969-76v01")["footnote"] == 1,
                    "fixture did not install the legacy row — the cleanup would be untested")

            // Re-opening the pipeline runs the schema pass, which removes them.
            let store = try FTS5Store(databaseURL: dbURL)
            let pipeline = try IndexingPipeline(fts5Store: store, databaseURL: dbURL,
                                                volumesDirectory: volumes, concurrencyLimit: 2)
            let counts = try eras(inDatabase: dbURL, volumeId: "frus1969-76v01")
            #expect(counts["footnote"] == nil, """
                The legacy row survived re-opening: \(counts). Users who already have an index \
                would keep the inflated counts until a full reindex, which nothing prompts them \
                to do.
                """)
            #expect(counts.values.reduce(0, +) == 1, "the genuine source-note row must survive")

            let stats = try await pipeline.localCollectionStats(
                lotFileNorm: "64D199", repository: "Department of State",
                recordGroup: "59", names: [])
            #expect(stats.documentCount == 1)
        }
    }
}
