// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

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
}
