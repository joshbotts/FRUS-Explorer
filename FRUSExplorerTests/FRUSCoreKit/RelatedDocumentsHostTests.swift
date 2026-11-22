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
// SHA-256 is CryptoKit's on Apple platforms; on Linux the web edition supplies swift-crypto's Crypto.
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

// MARK: - RelatedDocumentsHostTests

/// Related Documents' engine called as a host outside the app calls it (FRUS Explorer Light's S23a):
/// over an index the kit's pipeline builds from a fixture volume, with dependencies of the host's own —
/// a cross-reference source and a manifest, no person store and no subject index — and with and without
/// a semantic axis. The suite imports the kit `@testable`, so it cannot show that the engine is public;
/// a host's own build does. Its semantic stand-in builds its pool and its leads through `@testable`
/// too: the leads' initialisers stay internal until a host has a semantic stack of its own.
///
/// The fixture's anchor is `d1`. The cross-reference source cites `d3` twice and `d4` once; nothing
/// else generates, since no document carries a source note and the lexical axis ships at weight 0.
/// `d1`, `d2` and `d3` share a chapter and `d4` sits in another, and the four are dated 1971, 1971,
/// 1972 and 1975.
///
/// Since #1907 the shown rows' lines read a reader's summaries where a host keeps them: over the app's
/// index, where the app writes them, and over a copy stripped of the writing and opened read-only, as
/// such a host serves one, with and without a store of its readers' writing attached (`HostServedIndex`).
/// From the index, the default, the lines' statement is the one the engine ran before it took a source,
/// by the pipeline's statement trace and a pin taken at `v2` `21c77370`.
///
/// Version history:
///   1.0 — 2026-11-08 (FRUS Explorer Light S23a): initial implementation
///   1.1 — 2026-11-22 (FRUS Explorer Light, #1907): the lines' user source
@Suite("FRUSCoreKit — Related Documents' engine, as a host calls it")
struct RelatedDocumentsHostTests {

    private static let volumeId = "frus1971v01"

    private static func key(_ documentId: String) -> DocumentKey {
        DocumentKey(volumeId: volumeId, documentId: documentId)
    }

    /// A volume of four dated documents in two chapters.
    private static let volumeXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0" xmlns:frus="http://history.state.gov/frus/ns/1.0">
          <teiHeader><fileDesc><titleStmt><title>frus1971v01</title></titleStmt>
          <publicationStmt><date>1975</date></publicationStmt>
          <sourceDesc><p>Test fixture</p></sourceDesc></fileDesc></teiHeader>
          <text><body>
            <div type="chapter" xml:id="ch1"><head>Talks in Paris</head>
              <div type="document" xml:id="d1" n="1"
                   frus:doc-dateTime-min="1971-01-05" frus:doc-dateTime-max="1971-01-05">
                <head>1. Telegram From the Embassy in France</head>
                <p>The Ambassador met the Foreign Minister on the question of access.</p></div>
              <div type="document" xml:id="d2" n="2"
                   frus:doc-dateTime-min="1971-02-01" frus:doc-dateTime-max="1971-02-01">
                <head>2. Memorandum for the Record</head>
                <p>The Minister asked for time to consult the allies.</p></div>
              <div type="document" xml:id="d3" n="3"
                   frus:doc-dateTime-min="1972-06-01" frus:doc-dateTime-max="1972-06-01">
                <head>3. Letter From the President</head>
                <p>The President set out the terms of the agreement on access.</p></div>
            </div>
            <div type="chapter" xml:id="ch2"><head>Afterwards</head>
              <div type="document" xml:id="d4" n="4"
                   frus:doc-dateTime-min="1975-03-01" frus:doc-dateTime-max="1975-03-01">
                <head>4. Editorial Note</head>
                <p>The agreement entered into force.</p></div>
            </div>
          </body></text>
        </TEI>
        """

    /// The volume, indexed by the kit's pipeline into a temporary directory, for `body`.
    @MainActor
    private func withIndex<T>(_ body: (IndexingPipeline) async throws -> T) async throws -> T {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSRelatedHost-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let volumes = dir.appendingPathComponent("volumes", isDirectory: true)
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        try Data(Self.volumeXML.utf8).write(to: volumes.appendingPathComponent("\(Self.volumeId).xml"))
        let database = dir.appendingPathComponent("index.db")
        let pipeline = try IndexingPipeline(fts5Store: try FTS5Store(databaseURL: database), databaseURL: database,
                                            volumesDirectory: volumes, resources: .none,
                                            defaults: InMemoryIndexingStampStore())
        try await pipeline.indexVolume(Self.volumeId)
        return try await body(pipeline)
    }

    /// The host's cross-reference query: `d3` cited twice and `d4` once, whatever the anchor.
    private struct CitationSource: RelatedCitationSource {
        func relatedByCitation(forDocumentId documentId: String, volumeId: String,
                               scopeVolumeIds: Set<String>?, limit: Int) async throws -> [RelatedCitationCandidate] {
            [RelatedCitationCandidate(volumeId: RelatedDocumentsHostTests.volumeId, documentId: "d3",
                                      header: "3. Letter From the President", dateline: nil,
                                      documentNumber: "3", isEditorialNote: false, citationCount: 2),
             RelatedCitationCandidate(volumeId: RelatedDocumentsHostTests.volumeId, documentId: "d4",
                                      header: "4. Editorial Note", dateline: nil,
                                      documentNumber: "4", isEditorialNote: true, citationCount: 1)]
        }
    }

    /// The host's manifest, which knows no volume, so no candidate shares a subseries by it.
    private struct EmptyManifest: VolumeManifestLookup {
        func entry(forVolumeId id: String) -> VolumeManifestEntry? { nil }
    }

    /// Counts what the engine asks of a semantic axis, and vends `d2` at 0.8.
    @MainActor
    private final class SemanticStandIn: SemanticSimilaritySource {
        var candidateCalls = 0
        var offIndexCalls = 0
        var reScores: [(candidates: Set<DocumentKey>, floor: Double)] = []
        let leads = SemanticOffIndexLeads(documentCount: 7, volumes: [.init(volumeID: "frus1969-76v01", count: 7)],
                                          isCapped: false)

        func candidates(for anchor: DocumentKey, anchorYear: Int?, limit: Int,
                        scopeVolumeIds: Set<String>?) async throws -> GeneratedPool {
            candidateCalls += 1
            return GeneratedPool(candidates: [GeneratedCandidate(
                key: RelatedDocumentsHostTests.key("d2"),
                record: CandidateRecord(header: "2. Memorandum for the Record", dateline: nil,
                                        documentNumber: "2", isEditorialNote: false),
                strength: 0.8, evidenceLabel: SemanticSimilarityGenerator.evidenceLabel(for: 0.8))])
        }

        func offIndexSection(for anchor: DocumentKey, limit: Int,
                             scopeVolumeIds: Set<String>?) async -> SemanticOffIndexLeads {
            offIndexCalls += 1
            return leads
        }

        func reScore(anchor: DocumentKey, candidates: Set<DocumentKey>,
                     floor: Double) async -> [DocumentKey: Double] {
            reScores.append((candidates, floor))
            return [:]
        }
    }

    /// Counts the reads of the subject index, which answers none.
    @MainActor
    private final class SubjectIndexReads {
        var count = 0
        func read() -> DocumentSubjectIndex? {
            count += 1
            return nil
        }
    }

    @MainActor
    private func dependencies(_ pipeline: IndexingPipeline,
                              semantic: (any SemanticSimilaritySource)? = nil,
                              subjectReads: SubjectIndexReads = SubjectIndexReads()) -> RelatedDocumentsDependencies {
        RelatedDocumentsDependencies(
            indexingPipeline: pipeline,
            crossReferenceStore: CitationSource(),
            personMentionStore: nil,
            documentSubjectIndex: subjectReads.read(),
            manifestStore: EmptyManifest(),
            searchService: nil,
            indexedVolumeIds: [Self.volumeId],
            lexicalStopwords: [],
            semantic: semantic)
    }

    @MainActor
    @Test("Over the kit's index and a host's stores, the engine ranks the cited documents by citations, date and placement, with their evidence and lines")
    func ranksOverTheKitsIndex() async throws {
        try await withIndex { pipeline in
            let result = await RelatedDocumentsEngine.rank(
                anchor: Self.key("d1"), anchorYear: nil, weights: .default, scopeVolumeIds: nil,
                limit: 30, dependencies: dependencies(pipeline))

            #expect(result.rows.map(\.key) == [Self.key("d3"), Self.key("d4")])
            #expect(result.totalBeforeLimit == 2)
            #expect(result.poolCutFrom == nil, "the citation source reports no total, so no cut is claimed")
            #expect(result.offIndexLeads == .none, "with no semantic axis there are no off-index leads")

            let d3 = try #require(result.rows.first)
            let d4 = try #require(result.rows.last)
            // The citations, damped and normalised by the anchor's strongest: d3's two, d4's one.
            #expect(d3.axisScores[.crossReference] == 1.0)
            #expect(abs((d4.axisScores[.crossReference] ?? 0) - 1 / ProximityMath.logDampedMultiplicity(2)) < 1e-12)
            #expect(d3.axisEvidence[.crossReference] == 2)
            #expect(d3.whyRelatedChips.contains { $0.axis == .crossReference && $0.chip == .citations(2) })
            // The years from the index's dates: 1972 and 1975 against the anchor's 1971.
            #expect(d3.axisScores[.dateProximity] == ProximityMath.dateDecay(deltaYears: 1, tau: DateProximityScorer.tau))
            #expect(d4.axisScores[.dateProximity] == ProximityMath.dateDecay(deltaYears: 4, tau: DateProximityScorer.tau))
            // Placement from the index's volume structure: the same volume, d3 in the anchor's chapter.
            let d3Placement = try #require(d3.axisScores[.subseries])
            let d4Placement = try #require(d4.axisScores[.subseries])
            #expect((SubseriesScorer.sameVolumeFloor...1).contains(d3Placement))
            #expect((SubseriesScorer.sameVolumeFloor...1).contains(d4Placement))
            #expect(d3Placement > d4Placement, "d3 shares the anchor's chapter and d4 does not")
            // No person store, no subject index and no semantic axis: those axes say nothing.
            for row in result.rows {
                #expect(Set(row.axisScores.keys) == [.crossReference, .dateProximity, .subseries])
                #expect(row.snippet?.isEmpty == false, "each shown row carries its line from the index")
            }
        }
    }

    @MainActor
    @Test("The engine asks the semantic axis for candidates, a re-score and the off-index leads only when it has weight, and ranks what it vends with the rest")
    func asksTheSemanticAxisOnlyAtWeight() async throws {
        try await withIndex { pipeline in
            let semantic = SemanticStandIn()
            let result = await RelatedDocumentsEngine.rank(
                anchor: Self.key("d1"), anchorYear: nil, weights: .default, scopeVolumeIds: nil,
                limit: 30, dependencies: dependencies(pipeline, semantic: semantic))
            #expect(semantic.candidateCalls == 1)
            #expect(semantic.offIndexCalls == 1)
            #expect(result.offIndexLeads == semantic.leads)
            // The re-score is asked for the other axes' candidates, floored at the axis's own weakest.
            #expect(semantic.reScores.count == 1)
            #expect(semantic.reScores.first?.candidates == [Self.key("d3"), Self.key("d4")])
            #expect(semantic.reScores.first?.floor == 0.8)
            let d2 = try #require(result.rows.first { $0.key == Self.key("d2") })
            #expect(d2.axisScores[.semanticSimilarity] == 0.8, "a self-normalising axis enters the sum as it is")

            // A background caller's opt-out leaves the off-index scan alone.
            _ = await RelatedDocumentsEngine.rank(
                anchor: Self.key("d1"), anchorYear: nil, weights: .default, scopeVolumeIds: nil,
                limit: 30, includeOffIndexLeads: false, dependencies: dependencies(pipeline, semantic: semantic))
            #expect(semantic.candidateCalls == 2)
            #expect(semantic.offIndexCalls == 1)

            // At weight 0 the axis is asked nothing at all: the consent gate.
            var off = AxisWeights.default
            off[.semanticSimilarity] = 0
            let quiet = await RelatedDocumentsEngine.rank(
                anchor: Self.key("d1"), anchorYear: nil, weights: off, scopeVolumeIds: nil,
                limit: 30, dependencies: dependencies(pipeline, semantic: semantic))
            #expect(semantic.candidateCalls == 2)
            #expect(semantic.offIndexCalls == 1)
            #expect(semantic.reScores.count == 2)
            #expect(quiet.rows.map(\.key) == [Self.key("d3"), Self.key("d4")])
        }
    }

    @MainActor
    @Test("The subject index is read only when the shared-subjects scorer runs, as the app's lazily decoded file was")
    func readsTheSubjectIndexOnlyWhenScoring() async throws {
        try await withIndex { pipeline in
            var off = AxisWeights.default
            off[.sharedSubjects] = 0
            let unread = SubjectIndexReads()
            _ = await RelatedDocumentsEngine.rank(
                anchor: Self.key("d1"), anchorYear: nil, weights: off, scopeVolumeIds: nil,
                limit: 30, dependencies: dependencies(pipeline, subjectReads: unread))
            #expect(unread.count == 0, "a zero-weighted scorer never runs, so it reads nothing")

            let read = SubjectIndexReads()
            _ = await RelatedDocumentsEngine.rank(
                anchor: Self.key("d1"), anchorYear: nil, weights: .default, scopeVolumeIds: nil,
                limit: 30, dependencies: dependencies(pipeline, subjectReads: read))
            #expect(read.count == 1)
        }
    }

    @MainActor
    @Test("With no index, the engine answers the empty result and asks nothing else")
    func noIndexIsEmpty() async {
        let semantic = SemanticStandIn()
        let result = await RelatedDocumentsEngine.rank(
            anchor: Self.key("d1"), anchorYear: nil, weights: .default, scopeVolumeIds: nil, limit: 30,
            dependencies: RelatedDocumentsDependencies(
                indexingPipeline: nil, crossReferenceStore: CitationSource(), personMentionStore: nil,
                documentSubjectIndex: nil, manifestStore: EmptyManifest(), searchService: nil,
                indexedVolumeIds: [], lexicalStopwords: [], semantic: semantic))
        #expect(result.rows.isEmpty)
        #expect(result.totalBeforeLimit == 0)
        #expect(semantic.candidateCalls == 0)
    }

    // MARK: A row's line, with a reader's summaries in a store (#1907)

    /// d3's summary, as the app writes one into its index and as the first reader's row of a host's
    /// store holds it; and its line, folded.
    private static let d3Summary = "The President's letter,\n  summarised   in brief. "
    private static let d3SummaryLine = "The President's letter, summarised in brief."

    /// d3's and d4's lines from their text, which the index stores from the head on.
    private static let d3TextLine = "3. Letter From the President The President set out the terms of the agreement on access."
    private static let d4TextLine = "4. Editorial Note The agreement entered into force."

    /// The first reader summarised d3, as the app's index holds it, and noted d4; the other reader noted
    /// d3 and summarised d4.
    private static let storeRows = [
        HostStoreRow(user: "reader-a", volumeId: volumeId, documentId: "d3", summary: d3Summary, note: "On the letter."),
        HostStoreRow(user: "reader-a", volumeId: volumeId, documentId: "d4", summary: nil, note: "Only a note."),
        HostStoreRow(user: "reader-b", volumeId: volumeId, documentId: "d3", summary: nil, note: "The other reader's note."),
        HostStoreRow(user: "reader-b", volumeId: volumeId, documentId: "d4", summary: "The other reader's summary of the note.", note: nil),
    ]

    /// The app's index of the volume, with d3's summary written into it, the files a host copies it from,
    /// and a host's store of its readers' writing.
    private struct AppIndexAndStore {
        let app: IndexingPipeline
        let database: URL
        let volumes: URL
        let store: URL
        let dir: URL
    }

    /// The volume indexed read-write by the kit's pipeline, as the app's index is built, with d3's summary
    /// written into it as the app writes one, and a host's store holding `storeRows`, for `body`.
    @MainActor
    private func withAppIndexAndStore<T>(_ body: (AppIndexAndStore) async throws -> T) async throws -> T {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSRelatedHost-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let volumes = dir.appendingPathComponent("volumes", isDirectory: true)
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        try Data(Self.volumeXML.utf8).write(to: volumes.appendingPathComponent("\(Self.volumeId).xml"))
        let database = dir.appendingPathComponent("index.db")
        let pipeline = try IndexingPipeline(fts5Store: try FTS5Store(databaseURL: database), databaseURL: database,
                                            volumesDirectory: volumes, resources: .none,
                                            defaults: InMemoryIndexingStampStore())
        try await pipeline.indexVolume(Self.volumeId)
        try await pipeline.updateSummaryText(volumeId: Self.volumeId, documentId: "d3", responseText: Self.d3Summary)
        let store = dir.appendingPathComponent("app-data/app.db")
        try HostServedIndex.writeStore(at: store, rows: Self.storeRows)
        return try await body(AppIndexAndStore(app: pipeline, database: database, volumes: volumes, store: store, dir: dir))
    }

    /// `d1`'s related documents over `pipeline`, at the default weights: with no source passed, as the
    /// app's calls make it, or with `userSource`.
    @MainActor
    private func related(over pipeline: IndexingPipeline, userSource: SearchUserSource? = nil,
                         includeSnippets: Bool = true) async -> RelatedDocumentsResult {
        guard let userSource else {
            return await RelatedDocumentsEngine.rank(
                anchor: Self.key("d1"), anchorYear: nil, weights: .default, scopeVolumeIds: nil, limit: 30,
                includeSnippets: includeSnippets, dependencies: dependencies(pipeline))
        }
        return await RelatedDocumentsEngine.rank(
            anchor: Self.key("d1"), anchorYear: nil, weights: .default, scopeVolumeIds: nil, limit: 30,
            includeSnippets: includeSnippets, userSource: userSource, dependencies: dependencies(pipeline))
    }

    /// The rows with their lines left out: which documents, in which order, with what scores and evidence.
    private static func withoutLines(_ rows: [RelatedDocumentRow]) -> [RelatedDocumentRow] {
        rows.map { row in
            var row = row
            row.snippet = nil
            return row
        }
    }

    @MainActor
    @Test("With a reader's store attached to a host's copy, a shown row's line is that reader's summary, row for row as on the app's index, or else the document's text; another reader's is never read")
    func withAStoreARowsLineIsTheReadersSummary() async throws {
        try await withAppIndexAndStore { fixture in
            let served = try HostServedIndex.servedCopy(of: fixture.database, volumes: fixture.volumes, in: fixture.dir,
                                                        userStore: fixture.store)
            let app = await related(over: fixture.app)
            #expect(app.rows.map(\.key) == [Self.key("d3"), Self.key("d4")])
            #expect(app.rows.map(\.snippet) == [Self.d3SummaryLine, Self.d4TextLine])

            // The first reader's summary of d3 is the app's index's, so the rows are the app's, line for line:
            // d3's summary, folded, and d4's text, which they only noted.
            let reader = await related(over: served, userSource: .attachedStore(userId: "reader-a"))
            #expect(reader.rows == app.rows)
            #expect(reader.totalBeforeLimit == app.totalBeforeLimit)

            // The other reader's line for d4 is their summary, and for d3, which they noted, the text.
            let other = await related(over: served, userSource: .attachedStore(userId: "reader-b"))
            #expect(other.rows.map(\.snippet) == [Self.d3TextLine, "The other reader's summary of the note."])
            #expect(Self.withoutLines(other.rows) == Self.withoutLines(app.rows))

            // From the index, the default, whose summaries the strip emptied, each line is the document's text,
            // as before; a reader with no rows reads the same, and so does passing the index.
            let index = await related(over: served)
            #expect(index.rows.map(\.snippet) == [Self.d3TextLine, Self.d4TextLine])
            #expect(Self.withoutLines(index.rows) == Self.withoutLines(app.rows))
            #expect(await related(over: served, userSource: .attachedStore(userId: "reader-c")).rows == index.rows)
            #expect(await related(over: served, userSource: .index).rows == index.rows)
        }
    }

    @MainActor
    @Test("Asked for a reader's summaries with no store attached, the rows are ranked as before and carry no lines, not the index's")
    func withNoStoreTheRowsCarryNoLines() async throws {
        try await withAppIndexAndStore { fixture in
            // The app's own index, which holds d3's summary and has no store attached.
            let app = await related(over: fixture.app)
            let refused = await related(over: fixture.app, userSource: .attachedStore(userId: "reader-a"))
            #expect(Self.withoutLines(refused.rows) == Self.withoutLines(app.rows))
            #expect(refused.rows.map(\.snippet) == [nil, nil])
        }
    }

    @MainActor
    @Test("With no lines asked for, a reader's source reads nothing: no statement the engine runs names the store, and no row has a line")
    func withNoLinesTheSourceReadsNothing() async throws {
        try await withAppIndexAndStore { fixture in
            let served = try HostServedIndex.servedCopy(of: fixture.database, volumes: fixture.volumes, in: fixture.dir,
                                                        userStore: fixture.store)
            let trace = StatementTraceForTesting()
            await served.setStatementTraceForTesting(trace)
            let quiet = await related(over: served, userSource: .attachedStore(userId: "reader-a"), includeSnippets: false)
            await served.setStatementTraceForTesting(nil)
            #expect(quiet.rows.map(\.key) == [Self.key("d3"), Self.key("d4")])
            #expect(quiet.rows.allSatisfy { $0.snippet == nil })
            #expect(!trace.statements.isEmpty)
            #expect(!trace.statements.contains { $0.contains("user_search") }, "\(trace.statements)")

            // Asked for lines, the same source reads the store once, in the lines' statement.
            let read = StatementTraceForTesting()
            await served.setStatementTraceForTesting(read)
            _ = await related(over: served, userSource: .attachedStore(userId: "reader-a"))
            await served.setStatementTraceForTesting(nil)
            #expect(read.statements.filter { $0.contains("user_search") }.count == 1, "\(read.statements)")
        }
    }

    @MainActor
    @Test("From the index, the default, the shown rows' lines are read by the statement the engine read them by before it took a source, and passing the index reads the same")
    func fromTheIndexTheLinesStatementIsItsText() async throws {
        try await withIndex { pipeline in
            let trace = StatementTraceForTesting()
            await pipeline.setStatementTraceForTesting(trace)
            _ = await RelatedDocumentsEngine.rank(
                anchor: Self.key("d1"), anchorYear: nil, weights: .default, scopeVolumeIds: nil,
                limit: 30, dependencies: dependencies(pipeline))
            await pipeline.setStatementTraceForTesting(nil)
            let lines = trace.statements.filter { $0.contains("dc.summary_text, dc.body_text") }
            let text = lines.joined(separator: "\n")
            let digest = SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
            // Taken at `v2` 21c77370, the tree before #1907, by running this rank with the engine as it was
            // there: so it says the lines' statement is the text and binds it was.
            let pinned = (count: 1, sha256: "94145263bcd958c40d322472d06c54749c71d9778ad6df90766994e50c8bc668")
            if lines.count != pinned.count || digest != pinned.sha256 {
                Issue.record("""
                    \(lines.count) statements, SHA-256 \(digest), where the pin is \(pinned.count) and \(pinned.sha256):
                    \(text)
                    """)
            }

            let explicit = StatementTraceForTesting()
            await pipeline.setStatementTraceForTesting(explicit)
            _ = await RelatedDocumentsEngine.rank(
                anchor: Self.key("d1"), anchorYear: nil, weights: .default, scopeVolumeIds: nil,
                limit: 30, userSource: .index, dependencies: dependencies(pipeline))
            await pipeline.setStatementTraceForTesting(nil)
            #expect(explicit.statements.filter { $0.contains("dc.summary_text, dc.body_text") } == lines)
        }
    }
}
