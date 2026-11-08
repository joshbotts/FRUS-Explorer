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
/// Version history:
///   1.0 — 2026-11-08 (FRUS Explorer Light S23a): initial implementation
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
}
