// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif
#if canImport(FTS5Store)
import FTS5Store
#endif
#if canImport(SQLite3)
import SQLite3
#else
import CSQLite
#endif

// MARK: - DocumentRevisionsTests

/// The `document_revisions` table (Volume-Update-Annotation-Integrity design, P1).
///
/// Every case here indexes a volume through the real `IndexingPipeline.indexVolume`, rewrites the
/// same TEI file, indexes it again, and reads the table back through the pipeline's own
/// `documentRevisions(forVolumeId:)`. Nothing is mocked: the parse, the hashes, the store pass and
/// the SQL `CASE` upsert are the shipped code, because the claim under test — *this document
/// changed, and here is whether your offsets moved* — is one a reader will act on.
///
/// The two hashes are the design's §3: `contentHash` moves for any visible change, footnotes and
/// source notes included; `bodyHash` is `renderingVersion`, the highlight coordinate space, and
/// moves only when offsets can have. The test that pins the second against an independently
/// computed `renderingVersion` is the one that makes "your highlights moved" a true sentence.
///
/// Version history:
///   1.0 — R-5 P1: initial implementation
///   1.1 — Session 2026-11-08 (FRUS Explorer Light, S21a): moved to `FRUSCoreKit/`, so the package
///          runs it too, since what it tests is the kit's indexer. Two pieces stay Xcode's: the test of
///          `updateSummary(_:)`, which takes the app's `GeneratedSummary`, and one assertion about the
///          app's `DocumentChangeBanner`, inside a test the package runs
///   1.2 — 2026-11-17 (#1909): the file also holds `IndexedVolumeFileTests`, the record of the file
///          each volume was indexed from, the per-volume half of what an index records about its TEI
@Suite("Document revisions — the change set recorded at index time")
struct DocumentRevisionsTests {

    // MARK: - Fixture

    struct Doc {
        var id: String
        var head: String
        var body: String
        var footnote: String? = nil
        var sourceNote: String? = nil
    }

    /// A temp corpus + a live pipeline, so one test can index, rewrite, and re-index.
    final class Harness {
        let dir: URL
        let volumesDir: URL
        let pipeline: IndexingPipeline
        init() throws {
            dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("document-revisions-\(UUID().uuidString)", isDirectory: true)
            volumesDir = dir.appendingPathComponent("volumes")
            try FileManager.default.createDirectory(at: volumesDir, withIntermediateDirectories: true)
            let dbURL = dir.appendingPathComponent("test.sqlite")
            let store = try FTS5Store(databaseURL: dbURL)
            pipeline = try IndexingPipeline(fts5Store: store, databaseURL: dbURL,
                                            volumesDirectory: volumesDir, concurrencyLimit: 2)
        }
        deinit { try? FileManager.default.removeItem(at: dir) }

        /// A raw read of one `document_cache` column, for pinning what the pipeline wrote.
        func cacheColumn(_ column: String, _ volumeId: String, _ documentId: String) -> String? {
            var db: OpaquePointer?
            guard sqlite3_open(dir.appendingPathComponent("test.sqlite").path, &db) == SQLITE_OK else { return nil }
            defer { sqlite3_close(db) }
            var stmt: OpaquePointer?
            let sql = "SELECT \(column) FROM document_cache WHERE volume_id = ? AND document_id = ?"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, volumeId, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(stmt, 2, documentId, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            guard sqlite3_step(stmt) == SQLITE_ROW, let c = sqlite3_column_text(stmt, 0) else { return nil }
            return String(cString: c)
        }

        /// A raw read of one `document_revisions` column, for pinning the migration itself —
        /// `DocumentRevision` does not surface `index_version` and should not.
        func revisionColumn(_ column: String, _ volumeId: String, _ documentId: String) -> String? {
            var db: OpaquePointer?
            guard sqlite3_open(dir.appendingPathComponent("test.sqlite").path, &db) == SQLITE_OK
            else { return nil }
            defer { sqlite3_close(db) }
            var stmt: OpaquePointer?
            let sql = "SELECT \(column) FROM document_revisions WHERE volume_id = ? AND document_id = ?"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, volumeId, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(stmt, 2, documentId, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            guard sqlite3_step(stmt) == SQLITE_ROW, let c = sqlite3_column_text(stmt, 0) else { return nil }
            return String(cString: c)
        }

        /// Runs one raw statement against the database — to plant a fixture the pipeline would never
        /// write. Returns SQLite's result code, so a test can assert the plant itself took (the
        /// first version swallowed a NOT NULL violation and then "failed" on the read).
        @discardableResult
        func raw(_ sql: String) -> Int32 {
            var db: OpaquePointer?
            guard sqlite3_open(dir.appendingPathComponent("test.sqlite").path, &db) == SQLITE_OK else { return -1 }
            defer { sqlite3_close(db) }
            return sqlite3_exec(db, sql, nil, nil, nil)
        }

        /// A second pipeline on the same database — what a relaunch does, `setupDatabase` included.
        func reopen() throws -> IndexingPipeline {
            let dbURL = dir.appendingPathComponent("test.sqlite")
            let store = try FTS5Store(databaseURL: dbURL)
            return try IndexingPipeline(fts5Store: store, databaseURL: dbURL,
                                        volumesDirectory: volumesDir, concurrencyLimit: 2)
        }

        func write(_ volumeId: String, _ docs: [Doc]) throws {
            let divs = docs.map { d in
                let note = d.sourceNote.map { "<note type=\"source\">\($0)</note>" } ?? ""
                let fn = d.footnote.map { "<note xml:id=\"\(d.id)fn1\" type=\"footnote\">\($0)</note>" } ?? ""
                return """
                <div type="document" xml:id="\(d.id)"><head>\(d.head)</head>
                \(note)
                <p>\(d.body)\(fn)</p></div>
                """
            }.joined(separator: "\n")
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
            try Data(xml.utf8).write(to: volumesDir.appendingPathComponent("\(volumeId).xml"))
        }

        /// Index (or re-index) and read the table back, keyed by document id.
        func index(_ volumeId: String) async throws -> [String: IndexingPipeline.DocumentRevision] {
            try await pipeline.indexVolume(volumeId)
            let rows = try await pipeline.documentRevisions(forVolumeId: volumeId)
            return Dictionary(uniqueKeysWithValues: rows.map { ($0.documentId, $0) })
        }

        /// `renderingVersion` computed the way `DocumentView` computes it, from the file on disk.
        func independentBodyHash(_ volumeId: String, _ documentId: String) async throws -> String {
            let url = volumesDir.appendingPathComponent("\(volumeId).xml")
            let ast = try #require(try await FRUSDocumentParser().parse(volumeURL: url)
                .first { $0.documentId == documentId })
            var converter = ASTToRenderNodeConverter()
            return ASTToRenderNodeConverter.renderingVersion(for: converter.convert(ast))
        }
    }

    private let vol = "frus1958-60v01"
    private var base: [Doc] {
        [Doc(id: "d1", head: "Memorandum of Conversation", body: "The Ambassador called at noon.",
             footnote: "See Document 4.", sourceNote: "Department of State, Central Files, 611.51/1-1558."),
         Doc(id: "d2", head: "Telegram From the Embassy", body: "Nothing to report from Paris."),
         Doc(id: "d3", head: "Editorial Note", body: "The conference adjourned without result.")]
    }

    // MARK: - First index

    /// A document cannot have changed before the reader had it.
    @Test("The first index writes hashes and stamps no change")
    func firstIndexStampsNothing() async throws {
        let h = try Harness()
        try h.write(vol, base)
        let rows = try await h.index(vol)
        #expect(rows.count == 3)
        for (id, row) in rows {
            #expect(row.changedAt == nil, "\(id) was stamped on first index")
            #expect(row.changeKind == nil, "\(id) has a kind on first index")
            #expect(row.contentHash.count == 64, "\(id) content hash is not SHA-256 hex")
            #expect(row.bodyHash.count == 16, "\(id) body hash is not a renderingVersion")
        }
    }

    /// **The hash highlights carry.** `body_hash` must be the exact `renderingVersion` a highlight
    /// on this document would store, or "your offsets moved" is wrong in both directions.
    @Test("body_hash IS renderingVersion, computed independently")
    func bodyHashIsRenderingVersion() async throws {
        let h = try Harness()
        try h.write(vol, base)
        let rows = try await h.index(vol)
        for id in ["d1", "d2", "d3"] {
            let expected = try await h.independentBodyHash(vol, id)
            #expect(rows[id]?.bodyHash == expected, "\(id): \(rows[id]?.bodyHash ?? "nil") vs \(expected)")
        }
    }

    // MARK: - Re-index

    /// Nothing changed, nothing recorded — a re-index that moved no characters leaves no trace,
    /// which is what lets a reader's disposition survive the next update.
    @Test("An identical re-index changes no row")
    func identicalReindexIsSilent() async throws {
        let h = try Harness()
        try h.write(vol, base)
        let first = try await h.index(vol)
        try h.write(vol, base)
        let second = try await h.index(vol)
        #expect(second == first)
        #expect(second.values.allSatisfy { $0.changedAt == nil })
    }

    /// **The §3 case.** A footnote correction moves the content hash and not the body hash: the
    /// document changed, the offsets did not, and the kind says which.
    @Test("A footnote-only change is 'apparatus': content moves, body does not")
    func footnoteChangeIsApparatus() async throws {
        let h = try Harness()
        try h.write(vol, base)
        let first = try await h.index(vol)
        var edited = base
        edited[0].footnote = "See Document 5, not 4."
        try h.write(vol, edited)
        let second = try await h.index(vol)
        let d1 = try #require(second["d1"])
        #expect(d1.contentHash != first["d1"]?.contentHash, "a footnote change must move content_hash")
        #expect(d1.bodyHash == first["d1"]?.bodyHash, "a footnote change must NOT move body_hash")
        #expect(d1.changeKind == "apparatus")
        #expect(d1.changedAt != nil)
        // The untouched neighbours are untouched.
        #expect(second["d2"] == first["d2"])
        #expect(second["d3"] == first["d3"])
    }

    /// A source-note correction is the other apparatus case, and the one an archive visit is
    /// built on.
    @Test("A source-note change is 'apparatus'")
    func sourceNoteChangeIsApparatus() async throws {
        let h = try Harness()
        try h.write(vol, base)
        let first = try await h.index(vol)
        var edited = base
        edited[0].sourceNote = "Department of State, Central Files, 611.51/1-1658."
        try h.write(vol, edited)
        let second = try await h.index(vol)
        #expect(second["d1"]?.changeKind == "apparatus")
        #expect(second["d1"]?.bodyHash == first["d1"]?.bodyHash)
    }

    /// A body edit moves both hashes, is 'body', and the new body hash is again the exact
    /// `renderingVersion` — so the amber highlight and this row agree.
    @Test("A body change is 'body', and the new body_hash is still renderingVersion")
    func bodyChangeIsBody() async throws {
        let h = try Harness()
        try h.write(vol, base)
        let first = try await h.index(vol)
        var edited = base
        edited[1].body = "Nothing to report from Paris, except the rain."
        try h.write(vol, edited)
        let second = try await h.index(vol)
        let d2 = try #require(second["d2"])
        #expect(d2.changeKind == "body")
        #expect(d2.bodyHash != first["d2"]?.bodyHash)
        #expect(d2.contentHash != first["d2"]?.contentHash)
        #expect(d2.bodyHash == (try await h.independentBodyHash(vol, "d2")))
    }

    /// **§4's last row: whitespace moves no characters and must not warn.** Extra spaces and a
    /// line break inside the body are folded by the stored text's normalisation and by the
    /// render conversion alike.

    /// **R-5 §8.2 Q-9 — a volume removed and re-downloaded across a parse change is rebaselined,
    /// not stamped.**
    ///
    /// `.rebaseline` is passed from exactly one site, `indexAllVolumes`, so a SINGLE-volume
    /// re-download always took the `.stamp` path. If the parse version had moved while the volume
    /// was off the device, every document in it came back as "changed by an update" — hashes
    /// computed by a different parser, compared against hashes the old one wrote.
    ///
    /// The fixture plants a stale `index_version` rather than editing the document, because that
    /// is the whole claim: the CONTENT is what a different parser produced, and only the version
    /// column can tell that apart from an editorial correction.
    @Test("A row written by a different parse version is rebaselined, not stamped as changed")
    func staleIndexVersionRebaselines() async throws {
        let h = try Harness()
        try h.write(vol, base)
        _ = try await h.index(vol)

        // The row now carries the current version. Age it, and change the text underneath it —
        // exactly the state a re-download after a parse bump produces.
        #expect(h.raw("UPDATE document_revisions SET index_version = -1") == SQLITE_OK)
        var edited = base
        edited[1].body = "Nothing to report from Paris, except the rain."
        try h.write(vol, edited)
        let second = try await h.index(vol)

        let d2 = try #require(second["d2"])
        #expect(d2.changeKind == nil, """
            A parse-version change must rebaseline: the hashes are overwritten and nothing is \
            stamped. Got changeKind=\(d2.changeKind ?? "nil").
            """)
        #expect(d2.changedAt == nil)
        // And the rebaseline really did take the new hashes, or the next index would stamp it.
        #expect(d2.bodyHash == (try await h.independentBodyHash(vol, "d2")))
    }

    /// The guard is on the VERSION, not on any change: a normal edit at the current version still
    /// stamps. Without this the test above passes against a writer that never stamps at all.
    @Test("At an unchanged parse version a body change still stamps")
    func currentVersionStillStamps() async throws {
        let h = try Harness()
        try h.write(vol, base)
        _ = try await h.index(vol)
        var edited = base
        edited[1].body = "Nothing to report from Paris, except the rain."
        try h.write(vol, edited)
        let second = try await h.index(vol)
        #expect(try #require(second["d2"]).changeKind == "body")
    }

    @Test("A whitespace-only change is not a change")
    func whitespaceIsNotAChange() async throws {
        let h = try Harness()
        try h.write(vol, base)
        let first = try await h.index(vol)
        var edited = base
        edited[2].body = "The conference   adjourned\n   without result."
        try h.write(vol, edited)
        let second = try await h.index(vol)
        #expect(second["d3"] == first["d3"], "whitespace re-serialisation was flagged as a change")
    }

    // MARK: - Vanished

    /// **The worst case, recorded before the delete.** A document the new TEI no longer contains
    /// keeps its row, stamped 'vanished' — the only record that it ever existed on this device,
    /// and the anchor every annotation on it now lacks.
    @Test("A removed document's row survives as 'vanished'")
    func removedDocumentIsVanished() async throws {
        let h = try Harness()
        try h.write(vol, base)
        let first = try await h.index(vol)
        try h.write(vol, Array(base.dropLast()))        // d3 is gone
        let second = try await h.index(vol)
        let d3 = try #require(second["d3"], "the vanished document's row was deleted with its cache row")
        #expect(d3.changeKind == "vanished")
        #expect(d3.changedAt != nil)
        #expect(d3.contentHash == first["d3"]?.contentHash, "the last-known hashes are kept")
        #expect(second["d1"] == first["d1"])
        #expect(second["d2"] == first["d2"])
    }

    /// A document that vanishes and then returns under the same id is a change again, not a
    /// silent restoration — and its kind comes from its hashes, not from the stale 'vanished'.
    @Test("A vanished document that reappears is re-stamped from its hashes")
    func reappearingDocumentIsRestamped() async throws {
        let h = try Harness()
        try h.write(vol, base)
        _ = try await h.index(vol)
        try h.write(vol, Array(base.dropLast()))
        let gone = try await h.index(vol)
        #expect(gone["d3"]?.changeKind == "vanished")
        try h.write(vol, base)                           // d3 is back, identical
        let back = try await h.index(vol)
        let d3 = try #require(back["d3"])
        #expect(d3.changeKind != "vanished", "a document that is present is not vanished")
        #expect(d3.changedAt != nil, "its return is itself a change the reader should see")
        #expect(d3.reviewedAt == nil)
    }


    /// **Presence is a fact, not a hash comparison, so the version guard must not suppress it.**
    ///
    /// A first cut of the Q-9 guard sat above the `'vanished'` clause in all three CASE
    /// expressions, so a document that came back under a different parse version stayed marked
    /// vanished — the reader told a document was missing while looking at it.
    @Test("A vanished document that returns under a different parse version is still un-vanished")
    func reappearingUnderANewVersionIsNotVanished() async throws {
        let h = try Harness()
        try h.write(vol, base)
        _ = try await h.index(vol)
        try h.write(vol, Array(base.dropLast()))
        #expect(try await h.index(vol)["d3"]?.changeKind == "vanished")

        // The parse version moves while d3 is away — the re-download case, on a vanished row.
        #expect(h.raw("UPDATE document_revisions SET index_version = -1") == SQLITE_OK)
        try h.write(vol, base)
        let back = try await h.index(vol)

        let d3 = try #require(back["d3"])
        #expect(d3.changeKind == "apparatus", """
            A returning document is present whatever parser last wrote its row. Got \
            \(d3.changeKind ?? "nil").
            """)
        #expect(d3.changedAt != nil, "its return is itself a change the reader should see")
        #expect(d3.reviewedAt == nil)
    }

    /// The migration and its backfill, which the fresh-database harness would otherwise never
    /// exercise — every test above starts from a `CREATE TABLE` that already has the column.
    ///
    /// Without the backfill every pre-migration row reads as a version mismatch, so the first
    /// re-index of every volume on every existing install would rebaseline and swallow whatever
    /// the editors had actually changed.
    @Test("The migration backfills existing rows to the current version, so nothing rebaselines once")
    func migrationBackfillsExistingRows() async throws {
        let h = try Harness()
        try h.write(vol, base)
        _ = try await h.index(vol)

        // The state a pre-migration database is in the instant the column is added.
        #expect(h.raw("UPDATE document_revisions SET index_version = NULL") == SQLITE_OK)
        #expect(h.revisionColumn("index_version", vol, "d2") == nil)

        // A relaunch runs setupDatabase, hence the migration and its backfill.
        _ = try h.reopen()
        #expect(h.revisionColumn("index_version", vol, "d2")
                == String(IndexingPipeline.currentDateIndexVersion), """
            A NULL row must be claimed for the CURRENT version, or the next stamp reads it as a \
            mismatch and rebaselines a change the reader should have seen.
            """)

        // And with the row backfilled, an ordinary edit still stamps.
        var edited = base
        edited[1].body = "Nothing to report from Paris, except the rain."
        try h.write(vol, edited)
        #expect(try await h.index(vol)["d2"]?.changeKind == "body")
    }

    // MARK: - The P2 read APIs

    /// `unreviewedDocumentRevisions()` is what the Research filter and the hub summary read: every
    /// stamped, unreviewed row across ALL volumes, each carrying its volume id. Two volumes are
    /// indexed and one document in each is changed differently, so the set has to hold both ids.
    @Test("unreviewedDocumentRevisions lists stamped rows across volumes, with their volume ids")
    func unreviewedAcrossVolumes() async throws {
        let h = try Harness()
        let vol2 = "frus1958-60v02"
        try h.write(vol, base)
        try h.write(vol2, base)
        _ = try await h.index(vol)
        _ = try await h.index(vol2)
        // Nothing has changed yet: the first index stamps nothing.
        #expect(try await h.pipeline.unreviewedDocumentRevisions().isEmpty)

        var edited = base
        edited[1].body = "Nothing to report from Paris, except the rain."
        try h.write(vol, edited)
        _ = try await h.index(vol)
        var edited2 = base
        edited2[0].footnote = "See Document 5."
        try h.write(vol2, edited2)
        _ = try await h.index(vol2)

        let rows = try await h.pipeline.unreviewedDocumentRevisions()
        let keyed = Set(rows.map { "\($0.volumeId)/\($0.documentId):\($0.changeKind ?? "nil")" })
        #expect(keyed == ["\(vol)/d2:body", "\(vol2)/d1:apparatus"])
        #expect(rows.allSatisfy { $0.changedAt != nil && $0.reviewedAt == nil })
    }

    @Test("documentRevision(volumeId:documentId:) returns the row, nil for an unknown document")
    func singleRowRead() async throws {
        let h = try Harness()
        try h.write(vol, base)
        _ = try await h.index(vol)
        let first = try #require(try await h.pipeline.documentRevision(volumeId: vol, documentId: "d2"))
        #expect(first.volumeId == vol)
        #expect(first.documentId == "d2")
        #expect(first.changedAt == nil)
        #expect(try await h.pipeline.documentRevision(volumeId: vol, documentId: "d99") == nil)
        #expect(try await h.pipeline.documentRevision(volumeId: "frus-none", documentId: "d2") == nil)

        var edited = base
        edited[1].body = "Nothing to report from Paris, except the rain."
        try h.write(vol, edited)
        _ = try await h.index(vol)
        let changed = try #require(try await h.pipeline.documentRevision(volumeId: vol, documentId: "d2"))
        #expect(changed.changeKind == "body")
        #expect(changed.changedAt != nil)
        #expect(changed.bodyHash != first.bodyHash)
    }

    // MARK: - The P3 review writes

    /// The first write to `reviewed_at` the app has ever made. Stamping once drops the row from
    /// the unreviewed set, keeps it readable with its kind, survives an identical re-index, and is
    /// re-opened by the next real change — the `CASE` branch P1 wrote and never exercised.
    @Test("markDocumentRevisionReviewed: stamps once, survives an identical re-index, re-opens on change")
    func markReviewed() async throws {
        let h = try Harness()
        try h.write(vol, base)
        _ = try await h.index(vol)
        #expect(try await h.pipeline.markDocumentRevisionReviewed(volumeId: vol, documentId: "d2") == false)

        var edited = base
        edited[1].body = "Nothing to report from Paris, except the rain."
        try h.write(vol, edited)
        _ = try await h.index(vol)
        #expect(try await h.pipeline.unreviewedDocumentRevisions().map(\.documentId) == ["d2"])

        #expect(try await h.pipeline.markDocumentRevisionReviewed(volumeId: vol, documentId: "d2") == true)
        #expect(try await h.pipeline.markDocumentRevisionReviewed(volumeId: vol, documentId: "d2") == false)
        #expect(try await h.pipeline.unreviewedDocumentRevisions().isEmpty)
        let reviewed = try #require(try await h.pipeline.documentRevision(volumeId: vol, documentId: "d2"))
        #expect(reviewed.reviewedAt != nil)
        #expect(reviewed.changeKind == "body")
        #expect(reviewed.changedAt != nil)

        // An identical re-index keeps the disposition.
        let again = try await h.index(vol)
        #expect(again["d2"]?.reviewedAt == reviewed.reviewedAt)

        // The next real change re-opens the row.
        edited[1].footnote = "See Document 9."
        try h.write(vol, edited)
        let reopened = try await h.index(vol)
        #expect(reopened["d2"]?.reviewedAt == nil)
        #expect(try await h.pipeline.unreviewedDocumentRevisions().map(\.documentId) == ["d2"])
    }

    @Test("markVolumeRevisionsReviewed stamps every unreviewed row in the volume, and only that volume")
    func markVolumeReviewed() async throws {
        let h = try Harness()
        let vol2 = "frus1958-60v02"
        try h.write(vol, base)
        try h.write(vol2, base)
        _ = try await h.index(vol)
        _ = try await h.index(vol2)
        var edited = base
        edited[0].footnote = "See Document 5."
        edited[1].body = "Nothing to report from Paris, except the rain."
        try h.write(vol, edited)
        try h.write(vol2, edited)
        _ = try await h.index(vol)
        _ = try await h.index(vol2)
        #expect(try await h.pipeline.unreviewedDocumentRevisions().count == 4)

        #expect(try await h.pipeline.markVolumeRevisionsReviewed(volumeId: vol) == 2)
        #expect(try await h.pipeline.markVolumeRevisionsReviewed(volumeId: vol) == 0)
        let left = try await h.pipeline.unreviewedDocumentRevisions()
        #expect(Set(left.map(\.volumeId)) == [vol2])
        #expect(left.count == 2)
    }

    /// Q-5's escalation, now real: an apparatus-only correction landing on an unreviewed body
    /// change keeps the row `'body'`, because the highlight space DID move since the reader last
    /// looked. Once reviewed, the same correction reads as what it is.
    @Test("An apparatus change after an unreviewed body change keeps 'body'; after review it is 'apparatus'")
    func bodyWinsUntilReviewed() async throws {
        let h = try Harness()
        try h.write(vol, base)
        _ = try await h.index(vol)
        var edited = base
        edited[1].body = "Nothing to report from Paris, except the rain."
        try h.write(vol, edited)
        #expect(try await h.index(vol)["d2"]?.changeKind == "body")

        edited[1].footnote = "See Document 9."
        try h.write(vol, edited)
        let stacked = try await h.index(vol)
        #expect(stacked["d2"]?.changeKind == "body")
        #expect(stacked["d2"]?.reviewedAt == nil)

        _ = try await h.pipeline.markDocumentRevisionReviewed(volumeId: vol, documentId: "d2")
        edited[1].footnote = "See Document 10."
        try h.write(vol, edited)
        let afterReview = try await h.index(vol)
        #expect(afterReview["d2"]?.changeKind == "apparatus")
        #expect(afterReview["d2"]?.reviewedAt == nil)
    }

    /// A whole-index pass follows no file change, so hashes that move there moved because the
    /// parse did. `indexAllVolumes` re-baselines: the new hashes are written, nothing is stamped,
    /// an earlier stamp is untouched — and the NEXT per-volume index stamps against the new baseline.
    @Test("indexAllVolumes rebaselines: hashes move, nothing is stamped, earlier stamps survive")
    func rebaseline() async throws {
        let h = try Harness()
        try h.write(vol, base)
        _ = try await h.index(vol)
        var edited = base
        edited[1].body = "Nothing to report from Paris, except the rain."
        try h.write(vol, edited)
        let stamped = try await h.index(vol)
        #expect(stamped["d2"]?.changeKind == "body")

        // Simulate a parse change: d3's text differs on disk, but the pass is a whole-index one.
        edited[2].body = "The conference adjourned without result, twice."
        try h.write(vol, edited)
        try await h.pipeline.indexAllVolumes()
        let rows = Dictionary(uniqueKeysWithValues:
            try await h.pipeline.documentRevisions(forVolumeId: vol).map { ($0.documentId, $0) })
        #expect(rows["d3"]?.changedAt == nil)
        #expect(rows["d3"]?.changeKind == nil)
        #expect(rows["d3"]?.bodyHash != stamped["d3"]?.bodyHash)
        #expect(rows["d3"]?.bodyHash == (try await h.independentBodyHash(vol, "d3")))
        #expect(rows["d2"]?.changeKind == "body")
        #expect(rows["d2"]?.changedAt == stamped["d2"]?.changedAt)

        // The baseline moved: a further change to d3 is now measured against it.
        edited[2].body = "The conference adjourned without result, thrice."
        try h.write(vol, edited)
        #expect(try await h.index(vol)["d3"]?.changeKind == "body")
    }

    /// A whole-index pass that stops emitting a document records that it left the index and stamps
    /// no change, as it stamps no hash change (#1510 review round 1). Such a pass follows no file
    /// change, so the document is still in its volume's file and still opens by id: index v63
    /// leaves 162 heading-only containers out of unchanged files, and each one stamped as an
    /// unreviewed `'vanished'` made both storage hubs say "Updates changed documents … in N updated
    /// volumes", and an opened container say it was "no longer in the volume" over its own text.
    /// The row keeps its kind, which `ExcerptVerifier` reads, and its hashes. A per-volume index that
    /// removes a document still stamps and raises it.
    @Test("A document a whole-index pass stops emitting is 'vanished' with no change stamped, and nothing raises it")
    func reParseLeavingADocumentOutStampsNoChange() async throws {
        let h = try Harness()
        try h.write(vol, base)
        let first = try await h.index(vol)
        // A parse change that stops emitting d3: the pass is a whole-index one, as after a version bump.
        try h.write(vol, Array(base.dropLast()))
        try await h.pipeline.indexAllVolumes()
        let rows = Dictionary(uniqueKeysWithValues:
            try await h.pipeline.documentRevisions(forVolumeId: vol).map { ($0.documentId, $0) })
        let d3 = try #require(rows["d3"], "the row is kept")
        #expect(d3.changeKind == "vanished", "it left the index")
        #expect(d3.changedAt == nil, "no update removed it")
        #expect(d3.reviewedAt == nil)
        #expect(d3.contentHash == first["d3"]?.contentHash, "the last-known hashes are kept")
        #expect(try await h.pipeline.unreviewedDocumentRevisions().isEmpty, "the update review counts it")
        #expect(try await h.pipeline.vanishedDocumentKeys().isEmpty, "Research routes it as removed")
        #if !SWIFT_PACKAGE // DocumentChangeBanner is the app's view
        let banner = await MainActor.run { DocumentChangeBanner.line(revision: d3, highlightsStale: false) }
        #expect(banner == nil, "the banner says it is no longer in the volume")
        #endif
        #expect(!d3.recordsRemoval, "the review sheet treats it as removed (review round 2)")
        #expect(try await h.pipeline.markVolumeRevisionsReviewed(volumeId: vol) == 0, "there is nothing to review")

        // A per-volume index — a volume update — that removes d2 stamps it and raises it as before,
        // and leaves d3's row as it was.
        try h.write(vol, Array(base.prefix(1)))
        let updated = try await h.index(vol)
        #expect(updated["d2"]?.changeKind == "vanished")
        #expect(updated["d2"]?.changedAt != nil)
        #expect(updated["d2"]?.recordsRemoval == true)
        #expect(updated["d3"] == d3)
        #expect(try await h.pipeline.unreviewedDocumentRevisions().map(\.documentId) == ["d2"])
        #expect(try await h.pipeline.vanishedDocumentKeys() == ["\(vol)/d2"])
    }

    /// The same, down the Q-9 path: a volume removed before a parse change and downloaded again
    /// after it is indexed alone, as a `.stamp` pass, and its rows still carry the old parse's
    /// version. The upsert rebaselines such a row rather than stamp a change a different parser
    /// produced (`staleIndexVersionRebaselines`), and a document that parser stops emitting is no
    /// different: `frus1919Parisv13` freed before index v63 and fetched again after it would
    /// otherwise raise its 17 heading-only containers as removed by an update (#1510 review round 1).
    @Test("A document gone from a row written by a different parse version is 'vanished' with no change stamped")
    func vanishingAcrossAParseVersionStampsNoChange() async throws {
        let h = try Harness()
        try h.write(vol, base)
        _ = try await h.index(vol)
        #expect(h.raw("UPDATE document_revisions SET index_version = -1 WHERE document_id = 'd3'") == SQLITE_OK)
        try h.write(vol, Array(base.dropLast()))
        let back = try await h.index(vol)
        let d3 = try #require(back["d3"])
        #expect(d3.changeKind == "vanished")
        #expect(d3.changedAt == nil, "a different parser's row records no change")
        #expect(try await h.pipeline.unreviewedDocumentRevisions().isEmpty)
        #expect(try await h.pipeline.vanishedDocumentKeys().isEmpty)
        // The control, `removedDocumentIsVanished`: at the current version the same removal stamps.
    }

    // MARK: - P3b-1: removed volumes, the erase clear, the vanished source row

    /// Design Q-9 (c): a removed volume's rows leave the unreviewed read but are KEPT, and return
    /// intact — pending review included — when the volume is indexed again; a document dropped
    /// while the volume was gone reads as vanished on return.
    @Test("A removed volume's rows hide from the unreviewed read and return intact on re-index")
    func removedVolumeRowsHideAndReturn() async throws {
        let h = try Harness()
        try h.write(vol, base)
        _ = try await h.index(vol)
        var edited = base
        edited[1].body = "Nothing to report from Paris, except the rain."
        try h.write(vol, edited)
        _ = try await h.index(vol)
        #expect(try await h.pipeline.unreviewedDocumentRevisions().map(\.documentId) == ["d2"])

        try await h.pipeline.removeVolume(vol)
        #expect(try await h.pipeline.unreviewedDocumentRevisions().isEmpty)
        #expect(try await h.pipeline.documentRevisions(forVolumeId: vol).count == 3, "the rows are kept")

        _ = try await h.index(vol)     // identical re-index: the pending review is back
        #expect(try await h.pipeline.unreviewedDocumentRevisions().map(\.documentId) == ["d2"])

        try await h.pipeline.removeVolume(vol)
        edited.remove(at: 2)           // d3 disappears while the volume is off the device
        try h.write(vol, edited)
        let back = try await h.index(vol)
        #expect(back["d3"]?.changeKind == "vanished")
        #expect(Set(try await h.pipeline.unreviewedDocumentRevisions().map(\.documentId)) == ["d2", "d3"])
    }

    /// Design Q-9 (d): the clear is for Erase Everything alone; the rebuild wipe must leave the
    /// table, because `indexAllVolumes` then rebaselines to keep stamps and dispositions.
    @Test("clearDocumentRevisions empties the table; removeAllVolumesFromIndex leaves it intact")
    func clearIsNotTheRebuildWipe() async throws {
        let h = try Harness()
        try h.write(vol, base)
        _ = try await h.index(vol)
        var edited = base
        edited[1].body = "Nothing to report from Paris, except the rain."
        try h.write(vol, edited)
        _ = try await h.index(vol)
        try await h.pipeline.removeAllVolumesFromIndex()
        let kept = try await h.pipeline.documentRevisions(forVolumeId: vol)
        #expect(kept.count == 3)
        #expect(kept.first { $0.documentId == "d2" }?.changeKind == "body")
        try await h.pipeline.clearDocumentRevisions()
        #expect(try await h.pipeline.documentRevisions(forVolumeId: vol).isEmpty)
    }

    /// Design Q-11 (f): the vanished document's source row goes with its cache row, so an
    /// archive-visit plan stops deriving a target from a document that no longer exists.
    @Test("A vanished document's document_sources row is deleted with its cache row")
    func vanishedDocumentLosesItsSourceRow() async throws {
        let h = try Harness()
        try h.write(vol, base)     // d1 carries a source note
        _ = try await h.index(vol)
        #expect(!(try await h.pipeline.documentSourcesByKey([(volumeId: vol, documentId: "d1")])).isEmpty)
        try h.write(vol, Array(base.dropFirst()))
        let after = try await h.index(vol)
        #expect(after["d1"]?.changeKind == "vanished")
        #expect((try await h.pipeline.documentSourcesByKey([(volumeId: vol, documentId: "d1")])).isEmpty)
    }

    // MARK: - P3b-1 review fixes

    /// The EXISTS must be CORRELATED: with two volumes indexed, removing one must hide only its
    /// rows — an uncorrelated EXISTS survived the single-volume test because the cache was either
    /// wholly empty or wholly present.
    @Test("Removing one of two volumes hides only its rows, and re-indexing it brings them back")
    func removalIsPerVolume() async throws {
        let h = try Harness()
        let vol2 = "frus1958-60v02"
        try h.write(vol, base); try h.write(vol2, base)
        _ = try await h.index(vol); _ = try await h.index(vol2)
        var edited = base
        edited[1].body = "Nothing to report from Paris, except the rain."
        try h.write(vol, edited); try h.write(vol2, edited)
        _ = try await h.index(vol); _ = try await h.index(vol2)
        #expect(Set(try await h.pipeline.unreviewedDocumentRevisions().map(\.volumeId)) == [vol, vol2])
        try await h.pipeline.removeVolume(vol)
        #expect(Set(try await h.pipeline.unreviewedDocumentRevisions().map(\.volumeId)) == [vol2])
        _ = try await h.index(vol)
        #expect(Set(try await h.pipeline.unreviewedDocumentRevisions().map(\.volumeId)) == [vol, vol2])
    }

    /// Design Q-11 (h): vanished-ness outlives review. The keys survive a Mark Reviewed and
    /// follow the same volume-grain rule as the unreviewed read.
    @Test("vanishedDocumentKeys survives a review stamp and hides with its volume")
    func vanishedKeysOutliveReview() async throws {
        let h = try Harness()
        try h.write(vol, base)
        _ = try await h.index(vol)
        try h.write(vol, Array(base.dropLast()))
        _ = try await h.index(vol)
        #expect(try await h.pipeline.vanishedDocumentKeys() == ["\(vol)/d3"])
        #expect(try await h.pipeline.markDocumentRevisionReviewed(volumeId: vol, documentId: "d3") == true)
        #expect(try await h.pipeline.unreviewedDocumentRevisions().isEmpty)
        #expect(try await h.pipeline.vanishedDocumentKeys() == ["\(vol)/d3"], "reviewed, but still gone")
        try await h.pipeline.removeVolume(vol)
        #expect(try await h.pipeline.vanishedDocumentKeys().isEmpty)
        _ = try await h.index(vol)
        #expect(try await h.pipeline.vanishedDocumentKeys() == ["\(vol)/d3"])
    }

    /// Design Q-8 (g): the column can be emptied, and a NULL column stays NULL.
    @Test("clearSummaryText empties summary_text; updateSummaryText refills it")
    func clearSummaryText() async throws {
        let h = try Harness()
        try h.write(vol, base)
        _ = try await h.index(vol)
        try await h.pipeline.updateSummaryText(volumeId: vol, documentId: "d1", responseText: "draft words")
        #expect(h.cacheColumn("summary_text", vol, "d1") == "draft words")
        try await h.pipeline.clearSummaryText(volumeId: vol, documentId: "d1")
        #expect(h.cacheColumn("summary_text", vol, "d1") == nil)
        try await h.pipeline.clearSummaryText(volumeId: vol, documentId: "d1")   // idempotent
        #expect(h.cacheColumn("summary_text", vol, "d1") == nil)
        try await h.pipeline.updateSummaryText(volumeId: vol, documentId: "d1", responseText: "fresh")
        #expect(h.cacheColumn("summary_text", vol, "d1") == "fresh")
    }

    #if !SWIFT_PACKAGE // `updateSummary(_:)` takes `GeneratedSummary`, the app's SwiftData model (IndexingPipeline+App.swift)
    /// 2026-10-31: the column holds what the reader reads. A structured summary's JSON put its keys in
    /// the index, so a search over summaries matched `KeyParticipants`, and Related Documents' rows and
    /// Suggested Next's lines showed the braces.
    @Test("updateSummary writes a structured summary's fields as plain text, and a prose summary as it is")
    func updateSummaryWritesFields() async throws {
        let h = try Harness()
        try h.write(vol, base)
        _ = try await h.index(vol)
        let schema = StructuredSummarySchema(fields: [.init(name: "KeyParticipants", description: ""),
                                                      .init(name: "Topics", description: "")])
        let structured = GeneratedSummary(documentId: "d1", volumeId: vol, promptId: UUID(),
                                          responseText: #"{"Topics": "Tariffs.", "KeyParticipants": "The Minister."}"#,
                                          responseFormat: .structured(schema: schema))
        try await h.pipeline.updateSummary(structured)
        #expect(h.cacheColumn("summary_text", vol, "d1") == "Key Participants: The Minister.\n\nTopics: Tariffs.")
        let prose = GeneratedSummary(documentId: "d1", volumeId: vol, promptId: UUID(),
                                     responseText: "The Minister discussed tariffs.")
        try await h.pipeline.updateSummary(prose)
        #expect(h.cacheColumn("summary_text", vol, "d1") == "The Minister discussed tariffs.")
    }
    #endif

    /// Design Q-11 (f), for indexes built before the vanished-row delete reached this table: a
    /// source row with no cache row is swept on the next open, and a legitimate row is not.
    @Test("A ghost document_sources row is swept when the database is reopened")
    func ghostSourceRowSweptOnOpen() async throws {
        let h = try Harness()
        try h.write(vol, base)
        _ = try await h.index(vol)
        let rc = h.raw("INSERT INTO document_sources (volume_id, document_id, citation_era, raw_text) VALUES ('\(vol)', 'ghost', 'unrecognized', 'Ghost source note.')")
        #expect(rc == SQLITE_OK, "the plant must take")
        #expect(!(try await h.pipeline.documentSourcesByKey([(volumeId: vol, documentId: "ghost")])).isEmpty, "planted")
        let reopened = try h.reopen()
        #expect((try await reopened.documentSourcesByKey([(volumeId: vol, documentId: "ghost")])).isEmpty, "swept")
        #expect(!(try await reopened.documentSourcesByKey([(volumeId: vol, documentId: "d1")])).isEmpty, "the real row stays")
    }
}

// MARK: - IndexedVolumeFileTests

/// The file each volume was indexed from (#1909, index version 75): the git blob SHA-1 of the
/// bytes its store pass parsed and their length, on the `volume_structures` row that records the
/// pass finished (#1566).
///
/// Every case indexes through the real `indexVolume(_:)` or `indexAllVolumes()` and reads the
/// record back through the pipeline's own `indexedVolumeFiles()`, or through a read-only open of a
/// copy made as an export's is, which is how FRUS Explorer Light reads it. The expected hashes are
/// git's (`git hash-object` of the fixture's bytes), not the kit's function run a second time, so
/// they also pin that the record is the hash GitHub reports for the same file.
///
/// Version history:
///   1.0 — 2026-11-17 (#1909): initial implementation
@Suite("FRUSCoreKit — the file each volume was indexed from (#1909)")
struct IndexedVolumeFileTests {

    /// The volume most cases index.
    private static let volumeId = "frus1970v01"

    /// A volume of `documents` documents, each holding `text`. One line after the XML
    /// declaration, so the bytes, and the hashes pinned below, are the same on every platform.
    private static func volumeBytes(_ text: String, documents: Int = 1) -> Data {
        let divs = (1...documents).map { n in
            "<div type=\"document\" xml:id=\"d\(n)\" n=\"\(n)\"><head>\(n). Telegram</head><p>\(text)</p></div>"
        }.joined()
        return Data(("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
                     + "<TEI xmlns=\"http://www.tei-c.org/ns/1.0\"><text><body>"
                     + "<div type=\"compilation\" xml:id=\"comp1\">\(divs)</div></body></text></TEI>\n").utf8)
    }

    /// `git hash-object` of `volumeBytes("First text.")`, 245 bytes.
    private static let firstSHA = "a5f54507456b6fbca376afab4af69a1ba4e64604"
    /// `git hash-object` of `volumeBytes("Second text, a little longer.")`, 263 bytes.
    private static let secondSHA = "b66b8c9132b9c652c4b9f53bcc30e98996d1640a"

    /// The record of `firstSHA`'s bytes as `volumeId`, or another volume.
    private static func first(_ volumeId: String = volumeId) -> IndexedVolumeFile {
        IndexedVolumeFile(volumeId: volumeId, blobSHA1: firstSHA, sizeBytes: 245)
    }

    /// The record of `secondSHA`'s bytes as `volumeId`, or another volume.
    private static func second(_ volumeId: String = volumeId) -> IndexedVolumeFile {
        IndexedVolumeFile(volumeId: volumeId, blobSHA1: secondSHA, sizeBytes: 263)
    }

    /// A folder holding a `volumes` folder and an index, with a read-write pipeline over them.
    private struct Harness {
        let volumes: URL
        let database: URL
        let pipeline: IndexingPipeline

        init(dir: URL) throws {
            volumes = dir.appendingPathComponent("volumes", isDirectory: true)
            try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
            database = dir.appendingPathComponent("built.db")
            pipeline = try IndexingPipeline(fts5Store: try FTS5Store(databaseURL: database),
                                            databaseURL: database, volumesDirectory: volumes,
                                            resources: .none, defaults: InMemoryIndexingStampStore())
        }

        /// Writes `bytes` as `volumeId`'s file, replacing it as a download or an update does.
        func write(_ bytes: Data, as volumeId: String = IndexedVolumeFileTests.volumeId) throws {
            try bytes.write(to: volumes.appendingPathComponent("\(volumeId).xml"), options: .atomic)
        }
    }

    /// A temporary directory for `body`, removed after it.
    private func withTempDir<T>(_ body: (URL) async throws -> T) async throws -> T {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSIndexedFile-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        return try await body(dir)
    }

    /// Copies the index at `built` page for page with SQLite's backup API, out of write-ahead-log
    /// mode, into a folder of its own, as Export Research Database… makes its copy before any strip.
    private func exportCopy(of built: URL, in dir: URL) throws -> URL {
        let folder = dir.appendingPathComponent("export", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let copy = folder.appendingPathComponent("frus.db")
        var source: OpaquePointer?, target: OpaquePointer?
        try #require(sqlite3_open_v2(built.path, &source, SQLITE_OPEN_READONLY, nil) == SQLITE_OK)
        try #require(sqlite3_open_v2(copy.path, &target, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK)
        let backup = try #require(sqlite3_backup_init(target, "main", source, "main"))
        #expect(sqlite3_backup_step(backup, -1) == SQLITE_DONE)
        sqlite3_backup_finish(backup)
        #expect(sqlite3_exec(target, "PRAGMA journal_mode=DELETE", nil, nil, nil) == SQLITE_OK)
        #expect(sqlite3_close(target) == SQLITE_OK && sqlite3_close(source) == SQLITE_OK)
        try? FileManager.default.removeItem(at: folder.appendingPathComponent("frus.db-shm"))
        return copy
    }

    /// Runs `sql` on its own connection to `database`.
    private func exec(_ database: URL, _ sql: String) throws {
        var db: OpaquePointer?
        try #require(sqlite3_open_v2(database.path, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK)
        defer { sqlite3_close(db) }
        var message: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(db, sql, nil, nil, &message)
        let text = message.map { String(cString: $0) } ?? ""
        sqlite3_free(message)
        try #require(rc == SQLITE_OK, "\(text)")
    }

    @Test("A volume's record is git's blob SHA-1 of the file indexed and its size, which the corrections check computes too")
    func theRecordIsTheGitBlobOfTheFileIndexed() async throws {
        try await withTempDir { dir in
            let h = try Harness(dir: dir)
            let bytes = Self.volumeBytes("First text.")
            try h.write(bytes)
            #expect(try h.pipeline.indexedVolumeFile(forVolumeId: Self.volumeId) == nil, "nothing is indexed yet")
            try await h.pipeline.indexVolume(Self.volumeId)

            #expect(try h.pipeline.indexedVolumeFile(forVolumeId: Self.volumeId) == Self.first())
            #expect(try h.pipeline.indexedVolumeFiles() == [Self.first()])
            // The corrections check's own function over the file on disk gives the same hash, so
            // the app may read the index for it, and a host hashing a mounted file compares the two.
            let onDisk = try Data(contentsOf: h.volumes.appendingPathComponent("\(Self.volumeId).xml"))
            #expect(onDisk == bytes)
            #expect(VolumeUpdateChecker.gitBlobSHA1(for: onDisk) == Self.firstSHA)
            #expect(try await h.pipeline.document(forDocumentId: "d1", inVolume: Self.volumeId)?.header
                    == "1. Telegram", "the bytes hashed were parsed and stored")
            #expect(try h.pipeline.indexedVolumeFile(forVolumeId: "frus1970v99") == nil)
        }
    }

    @Test("A changed file indexed again replaces its record, by one volume's pass or the whole index's")
    func aChangedFileIndexedAgainReplacesItsRecord() async throws {
        try await withTempDir { dir in
            let h = try Harness(dir: dir)
            try h.write(Self.volumeBytes("First text."))
            try await h.pipeline.indexVolume(Self.volumeId)
            #expect(try h.pipeline.indexedVolumeFile(forVolumeId: Self.volumeId) == Self.first())

            try h.write(Self.volumeBytes("Second text, a little longer."))
            try await h.pipeline.indexVolume(Self.volumeId)
            #expect(try h.pipeline.indexedVolumeFiles() == [Self.second()], "one record a volume, the last pass's")

            // The batch pass, the launch's re-index at a new version, records each volume it stores.
            try h.write(Self.volumeBytes("First text."))
            try h.write(Self.volumeBytes("Second text, a little longer."), as: "frus1970v02")
            try await h.pipeline.indexAllVolumes()
            #expect(try h.pipeline.indexedVolumeFiles() == [Self.first(), Self.second("frus1970v02")])
        }
    }

    @Test("Removing a volume removes its record, and removing every volume removes every record")
    func removingAVolumeRemovesItsRecord() async throws {
        try await withTempDir { dir in
            let h = try Harness(dir: dir)
            try h.write(Self.volumeBytes("First text."))
            try h.write(Self.volumeBytes("Second text, a little longer."), as: "frus1970v02")
            try await h.pipeline.indexAllVolumes()
            #expect(try h.pipeline.indexedVolumeFiles().count == 2)

            try await h.pipeline.removeVolume(Self.volumeId)
            #expect(try h.pipeline.indexedVolumeFile(forVolumeId: Self.volumeId) == nil)
            #expect(try h.pipeline.indexedVolumeFiles() == [Self.second("frus1970v02")])

            try await h.pipeline.removeAllVolumesFromIndex()
            #expect(try h.pipeline.indexedVolumeFiles().isEmpty)
        }
    }

    @Test("A pass cut short leaves no record, not the last pass's, and the pass that finishes it records the file")
    func aPassCutShortLeavesNoRecord() async throws {
        try await withTempDir { dir in
            let h = try Harness(dir: dir)
            try h.write(Self.volumeBytes("First text."))
            try await h.pipeline.indexVolume(Self.volumeId)
            #expect(try h.pipeline.indexedVolumeFile(forVolumeId: Self.volumeId) == Self.first())

            // A corrected file of three documents, whose pass stops after its first batch, as a
            // quit leaves one (#1566). The old record would name a file the index no longer holds
            // whole, so it must go with the row that says the pass finished.
            let corrected = Self.volumeBytes("Corrected text.", documents: 3)
            try h.write(corrected)
            await h.pipeline.setTestBatchSize(1)
            await h.pipeline.setStopsBetweenBatchesWhenCancelled(true)
            await h.pipeline.setDocumentBatchStoredTestHook { _, batch in
                if batch == 1 { withUnsafeCurrentTask { $0?.cancel() } }
            }
            let pipeline = h.pipeline
            let pass = Task { try await pipeline.indexVolume(Self.volumeId) }
            await #expect(throws: CancellationError.self) { try await pass.value }
            #expect(try h.pipeline.isStoreUnfinished(Self.volumeId))
            #expect(try h.pipeline.indexedVolumeFile(forVolumeId: Self.volumeId) == nil)
            #expect(try h.pipeline.indexedVolumeFiles().isEmpty)

            await h.pipeline.setDocumentBatchStoredTestHook(nil)
            #expect(await h.pipeline.finishIndexing(of: [Self.volumeId]) == [Self.volumeId])
            #expect(try h.pipeline.indexedVolumeFile(forVolumeId: Self.volumeId)
                    == IndexedVolumeFile(volumeId: Self.volumeId,
                                         blobSHA1: VolumeUpdateChecker.gitBlobSHA1(for: corrected),
                                         sizeBytes: corrected.count))
        }
    }

    @Test("Both read-only opens read the records the index holds: an export's copy, immutable, and the live index beside its writer")
    func theReadOnlyOpensReadTheRecords() async throws {
        try await withTempDir { dir in
            let h = try Harness(dir: dir)
            try h.write(Self.volumeBytes("First text."))
            try h.write(Self.volumeBytes("Second text, a little longer."), as: "frus1970v02")
            try await h.pipeline.indexAllVolumes()
            let written = try h.pipeline.indexedVolumeFiles()
            #expect(written == [Self.first(), Self.second("frus1970v02")])

            // FRUS Explorer Light's server, serving an export.
            let copy = try exportCopy(of: h.database, in: dir)
            let exported = try IndexingPipeline(readingIndexAt: copy, fts5Store: try FTS5Store(readingDatabaseAt: copy),
                                                resources: .none)
            #expect(exported.isReadOnly)
            #expect(try exported.indexedVolumeFiles() == written)
            #expect(try exported.indexedVolumeFile(forVolumeId: "frus1970v02") == Self.second("frus1970v02"))

            // Its Standalone server, reading the index its indexing job writes.
            let live = try IndexingPipeline(readingLiveIndexAt: h.database,
                                            fts5Store: try FTS5Store(readingLiveDatabaseAt: h.database),
                                            resources: .none)
            #expect(try live.indexedVolumeFiles() == written)
            try h.write(Self.volumeBytes("Second text, a little longer."))
            try await h.pipeline.indexVolume(Self.volumeId)
            #expect(try live.indexedVolumeFile(forVolumeId: Self.volumeId) == Self.second(),
                    "the live open reads what the writer committed after it opened")
        }
    }

    @Test("An index from before version 75 holds no record: read-only it answers with none, and a read-write open adds the columns empty")
    func anIndexFromBeforeVersion75HoldsNoRecord() async throws {
        try await withTempDir { dir in
            let h = try Harness(dir: dir)
            try h.write(Self.volumeBytes("First text."))
            try await h.pipeline.indexVolume(Self.volumeId)
            // The table as version 74 and earlier wrote it.
            try exec(h.database, """
                CREATE TABLE volume_structures_74 (volume_id TEXT PRIMARY KEY, structure_json TEXT NOT NULL);
                INSERT INTO volume_structures_74 SELECT volume_id, structure_json FROM volume_structures;
                DROP TABLE volume_structures;
                ALTER TABLE volume_structures_74 RENAME TO volume_structures;
                """)

            // An export from before 75, opened read-only, where no migration runs: no record, and
            // no error, so a host compares every volume as it did before.
            let copy = try exportCopy(of: h.database, in: dir)
            let exported = try IndexingPipeline(readingIndexAt: copy, fts5Store: try FTS5Store(readingDatabaseAt: copy),
                                                resources: .none)
            #expect(try exported.indexedVolumeFiles().isEmpty)
            #expect(try exported.indexedVolumeFile(forVolumeId: Self.volumeId) == nil)
            #expect(try !exported.isStoreUnfinished(Self.volumeId), "the volume's pass still reads as finished")

            // The app's own open migrates the table: the columns are there, empty until the
            // version's re-index writes the row again.
            let reopened = try IndexingPipeline(fts5Store: try FTS5Store(databaseURL: h.database),
                                                databaseURL: h.database, volumesDirectory: h.volumes,
                                                resources: .none, defaults: InMemoryIndexingStampStore())
            #expect(try reopened.indexedVolumeFiles().isEmpty)
            try await reopened.indexVolume(Self.volumeId)
            #expect(try reopened.indexedVolumeFiles() == [Self.first()])
        }
    }

    @Test("A volume's bytes parse as its file does: the same documents, text, hashes, people, terms, sources and outline")
    func theBytesParseAsTheFileDoes() async throws {
        try await withTempDir { dir in
            let url = dir.appendingPathComponent("frus1969-76v99.xml")
            try Data("""
                <?xml version="1.0" encoding="UTF-8"?>
                <TEI xmlns="http://www.tei-c.org/ns/1.0">
                  <teiHeader><fileDesc><titleStmt><title>Fixture</title></titleStmt>
                  <publicationStmt><date type="publication-date">2010</date></publicationStmt>
                  <sourceDesc><p>Fixture</p></sourceDesc></fileDesc></teiHeader>
                  <text>
                    <front>
                      <div type="section" subtype="sources" xml:id="sources"><head>Sources</head>
                        <list><item><hi rend="strong">Central Intelligence Agency</hi>
                          <list><item>Job 79–R01012A (Registry of National Intelligence Estimates)</item></list>
                        </item></list>
                      </div>
                      <div type="section" subtype="terms" xml:id="terms"><head>Abbreviations and Terms</head>
                        <list><item><term xml:id="t_NSC1">NSC</term>, National Security Council</item></list>
                      </div>
                      <div type="section" subtype="persons" xml:id="persons"><head>Persons</head>
                        <list><item><persName xml:id="p_KHA1">Kissinger, Henry A.</persName>, Assistant to the President</item></list>
                      </div>
                    </front>
                    <body><div type="compilation" xml:id="comp1"><head>Arms Control</head>
                      <pb n="1" xml:id="pg_1"/>
                      <div type="document" xml:id="d1" n="1"><head>1. Memorandum From <persName corresp="#p_KHA1">Kissinger</persName><note n="1" type="source" xml:id="d1fn1">Source: Central Intelligence Agency, Job 79–R01012A, Box 1. Secret.</note></head>
                        <dateline><placeName>Washington</placeName>, <date when="1970-03-02">March 2, 1970</date>.</dateline>
                        <p>The <gloss target="#t_NSC1">NSC</gloss> met; see <ref target="#d2">Document 2</ref>.<note n="2" xml:id="d1fn2">A footnote, “quoted” &amp; escaped.</note></p>
                        <pb n="2" xml:id="pg_2"/>
                        <p>Text continues on page 2.</p></div>
                      <div type="document" xml:id="d2" n="2"><head>2. Telegram</head><p>Short.</p></div>
                    </div></body>
                  </text>
                </TEI>
                """.utf8).write(to: url)
            let parser = FRUSDocumentParser()
            let fromFile = try await parser.parseVolumeFull(volumeURL: url)
            let fromBytes = try await parser.parseVolumeFull(volumeData: try Data(contentsOf: url),
                                                             named: url.lastPathComponent)

            func documents(_ result: VolumeFullParseResult) -> [String] {
                result.documents.map { doc in
                    [doc.documentId, doc.printedNumber ?? "-", doc.startPage.map(String.init(describing:)) ?? "-",
                     doc.isFrontMatter ? "front" : "body",
                     IndexingPipeline.extractHeader(from: doc.nodes),
                     IndexingPipeline.extractDateline(from: doc.nodes) ?? "-",
                     IndexingPipeline.extractSourceNote(from: doc.nodes) ?? "-",
                     IndexingPipeline.extractBodyText(from: doc.nodes),
                     IndexingPipeline.bodyHash(for: doc)].joined(separator: " | ")
                }
            }
            // The two documents, and the front matter's sections the parse keeps as rows of their own.
            #expect(Set(["d1", "d2"]).isSubset(of: fromFile.documents.map(\.documentId)),
                    "\(fromFile.documents.map(\.documentId))")
            #expect(documents(fromBytes) == documents(fromFile))
            #expect(String(describing: fromBytes.persons) == String(describing: fromFile.persons))
            #expect(String(describing: fromBytes.terms) == String(describing: fromFile.terms))
            #expect(String(describing: fromBytes.volumeSources) == String(describing: fromFile.volumeSources))
            #expect(fromFile.volumeSources.contains { $0.jobNumber != nil }, "the fixture's Sources hold a job")
            #expect(fromBytes.structureSections == fromFile.structureSections)
        }
    }
}
