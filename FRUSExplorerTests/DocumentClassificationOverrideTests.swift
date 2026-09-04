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
import SwiftData
import Testing
@testable import FRUSExplorer

// MARK: - Fixture helpers

/// Writes a minimal FRUS volume with one ordinary document and one REAL-CORPUS-SHAPED
/// editorial note (`type="document" subtype="editorial-note"` — the encoding the parser
/// wraps in `.editorialNote`, which is what `document_cache.is_editorial_note` is read from).
private func writeClassificationFixture(to url: URL, volumeId: String) throws {
    let xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <TEI xmlns="http://www.tei-c.org/ns/1.0">
      <teiHeader><fileDesc><titleStmt><title>\(volumeId)</title></titleStmt>
      <publicationStmt><date>2003</date></publicationStmt>
      <sourceDesc><p>Test fixture</p></sourceDesc></fileDesc></teiHeader>
      <text><body>
        <div type="compilation" xml:id="comp1">
          <div type="document" xml:id="d1" n="1"><head>1. A Document</head><p>Ordinary telegram prose.</p></div>
          <div type="document" subtype="editorial-note" xml:id="d2" n="2"><head>2. Editorial Note</head><p>The editors explain something.</p></div>
        </div>
      </body></text>
    </TEI>
    """
    try xml.data(using: .utf8)!.write(to: url)
}

/// Creates a temporary directory, calls `body`, and cleans up after.
private func withTempDir<T>(_ body: (URL) async throws -> T) async throws -> T {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("FRUSClassificationTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    return try await body(dir)
}

// MARK: - Store

/// The override store's upsert/ordering/removal contract (#279 / W-4).
@Suite("DocumentClassificationOverride store")
@MainActor
struct DocumentClassificationOverrideStoreTests {

    private func container() throws -> ModelContainer {
        try ModelContainer(
            for: DocumentClassificationOverride.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }

    @Test("setOverride upserts — a second call updates the one record, never stacks a second")
    func upsertKeepsOneRecord() throws {
        let container = try container()
        let context = container.mainContext

        DocumentClassificationOverrideStore.setOverride(
            volumeId: "v1", documentId: "d1",
            isEditorialNote: true, parsedIsEditorialNote: false, context: context)
        // R-5 P3b-5: the second call passes a DIFFERENT parsed value. It used to pass `false`
        // twice, so the assertion below held whichever call had won and the comment described a
        // behaviour the test could not detect.
        DocumentClassificationOverrideStore.setOverride(
            volumeId: "v1", documentId: "d1",
            isEditorialNote: false, parsedIsEditorialNote: true, context: context)

        let all = DocumentClassificationOverrideStore.fetchAll(context: context)
        #expect(all.count == 1)
        #expect(all[0].isEditorialNote == false)
        // The parsed snapshot from the FIRST call survives — it is the restore value, and
        // the second call is a revision of the assertion, not a fresh observation.
        #expect(all[0].parsedIsEditorialNote == false)
    }

    @Test("A different document is a different record")
    func distinctAnchorsAreDistinctRecords() throws {
        let container = try container()
        let context = container.mainContext
        DocumentClassificationOverrideStore.setOverride(
            volumeId: "v1", documentId: "d1",
            isEditorialNote: true, parsedIsEditorialNote: false, context: context)
        DocumentClassificationOverrideStore.setOverride(
            volumeId: "v1", documentId: "d2",
            isEditorialNote: true, parsedIsEditorialNote: false, context: context)
        #expect(DocumentClassificationOverrideStore.fetchAll(context: context).count == 2)
        #expect(DocumentClassificationOverrideStore.override(
            volumeId: "v1", documentId: "d2", context: context) != nil)
    }

    @Test("snapshot() is OLDEST first, so the newest assertion wins the last-write apply")
    func snapshotIsOldestFirst() throws {
        let container = try container()
        let context = container.mainContext
        let older = DocumentClassificationOverrideStore.setOverride(
            volumeId: "v1", documentId: "dOld",
            isEditorialNote: true, parsedIsEditorialNote: false, context: context)
        let newer = DocumentClassificationOverrideStore.setOverride(
            volumeId: "v1", documentId: "dNew",
            isEditorialNote: true, parsedIsEditorialNote: false, context: context)
        older.createdAt = Date(timeIntervalSince1970: 0)
        newer.createdAt = Date(timeIntervalSince1970: 1_000_000)

        let snapshot = DocumentClassificationOverrideStore.snapshot(context: context)
        #expect(snapshot.map(\.documentId) == ["dOld", "dNew"])
    }

    @Test("remove deletes the record")
    func removeDeletes() throws {
        let container = try container()
        let context = container.mainContext
        let override = DocumentClassificationOverrideStore.setOverride(
            volumeId: "v1", documentId: "d1",
            isEditorialNote: true, parsedIsEditorialNote: false, context: context)
        DocumentClassificationOverrideStore.remove(override, context: context)
        #expect(DocumentClassificationOverrideStore.fetchAll(context: context).isEmpty)
    }
}

// MARK: - AST transform

/// The body-restyle transform (#279, the owner's "also restyle the body" decision).
/// The live-parse rule R-5 P3b-5 added, and the two refusals that make it safe to call from a
/// Settings row that may be looking at a volume this device no longer holds.
///
/// Version history:
///   1.0 — R-5 P3b-5: initial implementation
@Suite("Classification override — the live parse")
struct ClassificationLiveParseTests {

    /// No download manager and no file are the same answer: there is nothing to read, so the
    /// caller keeps the stored snapshot rather than being handed a fabricated `false`.
    @Test("A missing volume yields nil, never a default")
    @MainActor
    func absentVolumeYieldsNil() async {
        #expect(await DocumentClassificationOverrideStore.liveParsedIsEditorialNote(
            volumeId: "frus1969v01", documentId: "d1", volumeURL: nil) == nil)
        let missing = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("frus-p3b5-does-not-exist-\(UUID().uuidString).xml")
        #expect(await DocumentClassificationOverrideStore.liveParsedIsEditorialNote(
            volumeId: "frus1969v01", documentId: "d1", volumeURL: missing) == nil)
    }

    /// The rule's ANSWER, against a real TEI volume — without this every nil-path test above still
    /// passes when the body is replaced by `return nil`, which is exactly the shape that would make
    /// the Settings half of Q-11 (i) inert while the build stayed green.
    // Deliberately NOT `@MainActor`: `withTempDir` takes a non-Sendable closure, so isolating the
    // test would make the closure MainActor-isolated and unsendable. The awaits below hop to the
    // store's actor on their own, which is how `ClassificationPipelineTests` does it too.
    @Test("The rule reads the TEI's own shape: a document is false, an editorial note is true")
    func readsTheParsedShape() async throws {
        try await withTempDir { dir in
            let url = dir.appendingPathComponent("frus1969-76v01.xml")
            try writeClassificationFixture(to: url, volumeId: "frus1969-76v01")
            // The fixture's own contract: d1 is a document, d2 an editorial note.
            #expect(await DocumentClassificationOverrideStore.liveParsedIsEditorialNote(
                volumeId: "frus1969-76v01", documentId: "d1", volumeURL: url) == false)
            #expect(await DocumentClassificationOverrideStore.liveParsedIsEditorialNote(
                volumeId: "frus1969-76v01", documentId: "d2", volumeURL: url) == true)
            // A document the volume no longer contains — the vanished case — is nil, not a verdict.
            #expect(await DocumentClassificationOverrideStore.liveParsedIsEditorialNote(
                volumeId: "frus1969-76v01", documentId: "d99", volumeURL: url) == nil)
        }
    }

    /// A file that exists but is not a volume must also yield nil rather than throwing or
    /// asserting a classification from a failed parse.
    @Test("An unparseable file yields nil rather than a verdict")
    @MainActor
    func unparseableVolumeYieldsNil() async throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("frus-p3b5-not-tei-\(UUID().uuidString).xml")
        try "not a TEI document at all".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(await DocumentClassificationOverrideStore.liveParsedIsEditorialNote(
            volumeId: "frus1969v01", documentId: "d1", volumeURL: url) == nil)
    }
}

@Suite("Classification override AST transform")
struct ClassificationASTTransformTests {

    private func documentAST() -> FRUSDocumentAST {
        FRUSDocumentAST(documentId: "d1",
                        nodes: [.paragraph(children: [.text("Telegram prose.")])],
                        dateTimeMin: "1950-01-01T00:00:00Z",
                        printedNumber: "17")
    }

    private func noteAST() -> FRUSDocumentAST {
        FRUSDocumentAST(documentId: "d2",
                        nodes: [.editorialNote([.paragraph(children: [.text("The editors explain.")])])])
    }

    @Test("isShapedAsEditorialNote mirrors the index-time rule")
    func shapeDetection() {
        #expect(documentAST().isShapedAsEditorialNote == false)
        #expect(noteAST().isShapedAsEditorialNote == true)
    }

    @Test("Overriding a document to an editorial note wraps the whole body")
    func wrapToNote() {
        let transformed = documentAST().applyingClassificationOverride(isEditorialNote: true)
        #expect(transformed.isShapedAsEditorialNote)
        #expect(transformed.nodes.count == 1)
        guard case .editorialNote(let children) = transformed.nodes[0] else {
            Issue.record("expected a single .editorialNote wrapper")
            return
        }
        #expect(children.count == 1)
        // Metadata rides through untouched.
        #expect(transformed.documentId == "d1")
        #expect(transformed.dateTimeMin == "1950-01-01T00:00:00Z")
        #expect(transformed.printedNumber == "17")
    }

    @Test("Overriding a note to a document splices the wrapper's children in place")
    func unwrapToDocument() {
        let transformed = noteAST().applyingClassificationOverride(isEditorialNote: false)
        #expect(transformed.isShapedAsEditorialNote == false)
        #expect(transformed.nodes.count == 1)
        guard case .paragraph = transformed.nodes[0] else {
            Issue.record("expected the wrapped paragraph spliced to the top level")
            return
        }
    }

    @Test("A matching override is the identity — callers apply the effective flag unconditionally")
    func idempotent() {
        let doc = documentAST()
        #expect(doc.applyingClassificationOverride(isEditorialNote: false).nodes.count == doc.nodes.count)
        let note = noteAST()
        let same = note.applyingClassificationOverride(isEditorialNote: true)
        #expect(same.isShapedAsEditorialNote)
        #expect(same.nodes.count == 1)
    }

    @Test("Wrap then unwrap round-trips the body")
    func roundTrip() {
        let doc = documentAST()
        let back = doc
            .applyingClassificationOverride(isEditorialNote: true)
            .applyingClassificationOverride(isEditorialNote: false)
        #expect(back.nodes.count == doc.nodes.count)
        #expect(back.isShapedAsEditorialNote == false)
    }
}

// MARK: - Pipeline apply/replay

/// The one-seam apply and the replay-not-clobber contract (#279 / W-4): overrides write
/// into `document_cache.is_editorial_note`, a re-index restores the parsed TEI value by
/// design, and the per-volume replay re-asserts the cached override set.
@Suite("Classification override pipeline apply")
struct ClassificationPipelineTests {

    @Test("Applying an override flips the effective flag; the fixture's parse is the baseline")
    func applyFlipsColumn() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            try writeClassificationFixture(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01")
            try await pipeline.indexVolume("frus1969-76v01")

            // The parse: d1 is a document, d2 an editorial note.
            #expect(try await pipeline.effectiveIsEditorialNote(
                volumeId: "frus1969-76v01", documentId: "d1") == false)
            #expect(try await pipeline.effectiveIsEditorialNote(
                volumeId: "frus1969-76v01", documentId: "d2") == true)

            // Override both directions.
            let overrides = [
                DocumentClassificationOverrideData(
                    volumeId: "frus1969-76v01", documentId: "d1",
                    isEditorialNote: true, parsedIsEditorialNote: false),
                DocumentClassificationOverrideData(
                    volumeId: "frus1969-76v01", documentId: "d2",
                    isEditorialNote: false, parsedIsEditorialNote: true),
            ]
            try await pipeline.applyClassificationOverrides(overrides)
            #expect(try await pipeline.effectiveIsEditorialNote(
                volumeId: "frus1969-76v01", documentId: "d1") == true)
            #expect(try await pipeline.effectiveIsEditorialNote(
                volumeId: "frus1969-76v01", documentId: "d2") == false)
        }
    }

    @Test("A re-index restores the parse, and the per-volume replay re-asserts the override")
    func reindexReplaysCachedOverrides() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            try writeClassificationFixture(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01")
            try await pipeline.indexVolume("frus1969-76v01")

            // A whole-set apply caches the set on the actor for the per-volume replay.
            try await pipeline.applyClassificationOverrides([
                DocumentClassificationOverrideData(
                    volumeId: "frus1969-76v01", documentId: "d1",
                    isEditorialNote: true, parsedIsEditorialNote: false),
            ])
            #expect(try await pipeline.effectiveIsEditorialNote(
                volumeId: "frus1969-76v01", documentId: "d1") == true)

            // Re-index: the upsert restores the parsed value, then the tail replay
            // re-asserts the cached override — so the flag survives.
            try await pipeline.indexVolume("frus1969-76v01")
            #expect(try await pipeline.effectiveIsEditorialNote(
                volumeId: "frus1969-76v01", documentId: "d1") == true)

            // Clear the cached set (the store's tail after a removal) and re-index:
            // nothing replays, so the parse wins again.
            try await pipeline.applyClassificationOverrides([])
            try await pipeline.indexVolume("frus1969-76v01")
            #expect(try await pipeline.effectiveIsEditorialNote(
                volumeId: "frus1969-76v01", documentId: "d1") == false)
        }
    }

    @Test("The restore entry (volume-scoped) puts the parsed value back without caching")
    func restoreEntryRestoresWithoutCaching() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            try writeClassificationFixture(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01")
            try await pipeline.indexVolume("frus1969-76v01")

            try await pipeline.applyClassificationOverrides([
                DocumentClassificationOverrideData(
                    volumeId: "frus1969-76v01", documentId: "d1",
                    isEditorialNote: true, parsedIsEditorialNote: false),
            ])

            // The un-override path: the restore entry through the VOLUME-SCOPED call
            // (which must not cache), then the surviving whole set (empty).
            try await pipeline.applyClassificationOverrides([
                DocumentClassificationOverrideData(
                    volumeId: "frus1969-76v01", documentId: "d1",
                    isEditorialNote: false, parsedIsEditorialNote: false),
            ], volumeId: "frus1969-76v01")
            try await pipeline.applyClassificationOverrides([])

            #expect(try await pipeline.effectiveIsEditorialNote(
                volumeId: "frus1969-76v01", documentId: "d1") == false)
            // The volume-scoped call did NOT cache the restore entry: a re-index replays
            // nothing, so the flag stays at the parse.
            try await pipeline.indexVolume("frus1969-76v01")
            #expect(try await pipeline.effectiveIsEditorialNote(
                volumeId: "frus1969-76v01", documentId: "d1") == false)
        }
    }

    @Test("An override for an unindexed volume is a silent no-op, and the lookup returns nil")
    func unindexedVolumeIsSilentNoOp() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            try await pipeline.applyClassificationOverrides([
                DocumentClassificationOverrideData(
                    volumeId: "frus-not-here", documentId: "d1",
                    isEditorialNote: true, parsedIsEditorialNote: false),
            ])
            #expect(try await pipeline.effectiveIsEditorialNote(
                volumeId: "frus-not-here", documentId: "d1") == nil)
        }
    }

    @Test("The override reaches the search type filter through the one seam")
    func overrideReachesSearchFilter() async throws {
        try await withTempDir { dir in
            let (pipeline, store) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            try writeClassificationFixture(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01")
            try await pipeline.indexVolume("frus1969-76v01")
            let service = SearchService(fts5Store: store, pipeline: pipeline)

            var params = SearchParameters()
            params.keywords = "prose"
            params.documentTypeFilter = .editorialNotesOnly
            // d1's prose is a document, so the notes-only filter excludes it.
            #expect(try await service.searchCount(parameters: params) == 0)

            try await pipeline.applyClassificationOverrides([
                DocumentClassificationOverrideData(
                    volumeId: "frus1969-76v01", documentId: "d1",
                    isEditorialNote: true, parsedIsEditorialNote: false),
            ])
            // After the override, the same query finds it — no per-consumer change needed.
            #expect(try await service.searchCount(parameters: params) == 1)
        }
    }
}
