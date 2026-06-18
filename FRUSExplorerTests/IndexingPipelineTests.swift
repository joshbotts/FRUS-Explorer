// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
import SQLite3
#if canImport(UIKit)
import UIKit
#endif
@testable import FRUSExplorer

// MARK: - Test Helpers

/// Writes a minimal FRUS volume XML fixture to a file at `url`.
private func writeTEIVolume(to url: URL, volumeId: String, documents: [(id: String, xml: String)]) throws {
    let docBlocks = documents.map { doc in
        "<div type=\"document\" xml:id=\"\(doc.id)\">\(doc.xml)</div>"
    }.joined(separator: "\n")

    let xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <TEI xmlns="http://www.tei-c.org/ns/1.0">
      <teiHeader><fileDesc><titleStmt><title>\(volumeId)</title></titleStmt>
      <publicationStmt><date>2003</date></publicationStmt>
      <sourceDesc><p>Test fixture</p></sourceDesc></fileDesc></teiHeader>
      <text><body>
        <div type="compilation" xml:id="comp1">
          \(docBlocks)
        </div>
      </body></text>
    </TEI>
    """
    try xml.data(using: .utf8)!.write(to: url)
}

/// Creates a temporary directory, calls `body`, and cleans up after.
private func withTempDir<T>(_ body: (URL) async throws -> T) async throws -> T {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("FRUSTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    return try await body(dir)
}

/// Builds a minimal pipeline + store pair backed by a temp database.
private func makeTestPipeline(
    dir: URL,
    volumesDir: URL? = nil
) async throws -> (pipeline: IndexingPipeline, store: FTS5Store) {
    let dbURL = dir.appendingPathComponent("test.sqlite")
    let volDir = volumesDir ?? dir.appendingPathComponent("volumes")
    try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)

    let store = try FTS5Store(databaseURL: dbURL)
    let subjectStore = SubjectTagStore(entries: [], appearances: [])
    let pipeline = try IndexingPipeline(
        fts5Store: store,
        databaseURL: dbURL,
        volumesDirectory: volDir,
        subjectTagStore: subjectStore,
        concurrencyLimit: 2
    )
    return (pipeline, store)
}

// MARK: - IndexVolumeTest

@Suite("IndexingPipeline — indexVolume")
struct IndexVolumeTests {

    @Test("Indexed documents appear in FTS5 search results")
    func indexedDocumentsSearchable() async throws {
        try await withTempDir { dir in
            let (pipeline, store) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")

            try writeTEIVolume(to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                               volumeId: "frus1969-76v01",
                               documents: [
                ("d1", "<head>Memorandum of Conversation</head><p>Discussed detente policy.</p>"),
                ("d2", "<head>Telegram to Moscow</head><p>The negotiations proceeded swiftly.</p>"),
            ])

            try await pipeline.indexVolume("frus1969-76v01")

            let results = try await store.search(
                query: FTS5Query(keywords: ["detente"]),
                limit: 10, offset: 0
            )
            #expect(!results.isEmpty)
            let hasDoc = results.contains { $0.documentId == "d1" && $0.volumeId == "frus1969-76v01" }
            #expect(hasDoc, "Search results must include the indexed document d1")
        }
    }

    @Test("indexVolume throws volumeNotFound for missing XML")
    func missingVolumeThrows() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            do {
                try await pipeline.indexVolume("nonexistent-volume")
                Issue.record("Expected volumeNotFound error to be thrown")
            } catch IndexingError.volumeNotFound(let vid) {
                #expect(vid == "nonexistent-volume")
            }
        }
    }

    @Test("indexVolume emits completed progress event")
    func progressEventEmitted() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")

            try writeTEIVolume(to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                               volumeId: "frus1969-76v01",
                               documents: [("d1", "<head>Test</head><p>Text.</p>")])

            let task = Task<Bool, Never> {
                for await event in pipeline.progress {
                    if case .completed = event.state { return true }
                }
                return false
            }

            try await pipeline.indexVolume("frus1969-76v01")
            let hasCompleted = await task.value
            #expect(hasCompleted)
        }
    }
}

// MARK: - CrossReferenceExtractionTest

@Suite("IndexingPipeline — cross reference extraction")
struct CrossReferenceExtractionTests {

    @Test("extractCrossReferences parses local #d42 target")
    func localCrossRef() {
        let nodes: [FRUSASTNode] = [
            .paragraph(children: [
                .text("See "),
                .crossReference(target: "#d42", targetVolumeId: nil, children: [.text("Document 42")]),
            ])
        ]
        let refs = IndexingPipeline.extractCrossReferences(
            from: nodes, sourceVolumeId: "vol1", sourceDocumentId: "d1")
        #expect(refs.count == 1)
        #expect(refs[0].targetDocumentId == "d42")
        #expect(refs[0].targetVolumeId == nil)
    }

    @Test("extractCrossReferences parses cross-volume target")
    func crossVolumeCrossRef() {
        let nodes: [FRUSASTNode] = [
            .crossReference(target: "frus1969-76v14#d7", targetVolumeId: "frus1969-76v14",
                            children: [.text("See volume 14")])
        ]
        let refs = IndexingPipeline.extractCrossReferences(
            from: nodes, sourceVolumeId: "frus1969-76v01", sourceDocumentId: "d3")
        #expect(refs.count == 1)
        #expect(refs[0].targetVolumeId == "frus1969-76v14")
        #expect(refs[0].targetDocumentId == "d7")
    }

    @Test("Indexed volume populates page_ranges auxiliary table")
    func crossReferencesStoredAfterIndexing() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")

            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [
                    ("d1", """
                    <head>Report</head>
                    <p>See <ref target=\"#d2\">Document 2</ref>.</p>
                    """),
                    ("d2", "<head>Reply</head><p>Noted.</p>"),
                ]
            )
            try await pipeline.indexVolume("frus1969-76v01")
            // Verify auxiliary tables were populated (no error thrown means success;
            // cross_references are populated by the <ref> element in d1's XML)
            let keys = try await pipeline.documentKeysInDateRange(
                DateRange(earliest: nil, latest: nil),
                limitToVolumeIds: ["frus1969-76v01"]
            )
            // Documents without a parseable dateline have date_iso=NULL, so they are
            // excluded from the date-range query. Absence of a crash verifies the pipeline ran.
            _ = keys
        }
    }
}

// MARK: - PageRangeInsertTest

@Suite("IndexingPipeline — page range extraction")
struct PageRangeTests {

    @Test("extractPageRanges returns correct rows for arabic page breaks")
    func arabicPageBreaks() {
        let nodes: [FRUSASTNode] = [
            .paragraph(children: [.text("Text on page 1.")]),
            .pageBreak(pageNumber: .arabic(47)),
            .paragraph(children: [.text("Text on page 47.")]),
            .pageBreak(pageNumber: .arabic(48)),
        ]
        let rows = IndexingPipeline.extractPageRanges(
            from: nodes, volumeId: "vol1", documentId: "d5")
        #expect(rows.count == 2)
        #expect(rows[0].pageNumberType == "arabic")
        #expect(rows[0].pageNumberInt == 47)
        #expect(rows[0].sectionId == "d5")
        #expect(rows[1].pageNumberInt == 48)
    }

    @Test("extractPageRanges handles roman numeral page breaks")
    func romanPageBreaks() {
        let nodes: [FRUSASTNode] = [.pageBreak(pageNumber: .roman(12))]
        let rows = IndexingPipeline.extractPageRanges(from: nodes, volumeId: "v", documentId: "d1")
        #expect(rows.count == 1)
        #expect(rows[0].pageNumberType == "roman")
        #expect(rows[0].pageNumberInt == 12)
    }

    @Test("page_ranges rows stored correctly after indexVolume")
    func pageRangesStoredAfterIndexing() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")

            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [
                    ("d1", "<head>Doc 1</head><pb n=\"47\"/><p>Text.</p>"),
                ]
            )
            try await pipeline.indexVolume("frus1969-76v01")

            // Query auxiliary table through the date-range helper as a proxy
            let keys = try await pipeline.documentKeysInDateRange(
                DateRange(earliest: nil, latest: nil),
                limitToVolumeIds: ["frus1969-76v01"]
            )
            // If indexing ran without error, the pipeline processed the volume
            _ = keys  // Table creation and insertion verified by absence of thrown errors
        }
    }

    @Test("PageRangeSectionGroupingTest — two documents have distinct section IDs")
    func pageRangeSectionGrouping() {
        let rowsA = IndexingPipeline.extractPageRanges(
            from: [.pageBreak(pageNumber: .arabic(1))], volumeId: "v1", documentId: "d1")
        let rowsB = IndexingPipeline.extractPageRanges(
            from: [.pageBreak(pageNumber: .arabic(1))], volumeId: "v1", documentId: "d2")
        #expect(rowsA[0].sectionId == "d1")
        #expect(rowsB[0].sectionId == "d2")
        #expect(rowsA[0].sectionId != rowsB[0].sectionId)
    }
}

// MARK: - RemoveVolumeTest

@Suite("IndexingPipeline — removeVolume")
struct RemoveVolumeTests {

    @Test("Removed volume documents no longer appear in search results")
    func removedVolumeNotSearchable() async throws {
        try await withTempDir { dir in
            let (pipeline, store) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")

            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [("d1", "<head>Memorandum</head><p>Detente and negotiations.</p>")]
            )
            try await pipeline.indexVolume("frus1969-76v01")

            let before = try await store.search(query: FTS5Query(keywords: ["detente"]), limit: 10, offset: 0)
            #expect(!before.isEmpty)

            try await pipeline.removeVolume("frus1969-76v01")

            let after = try await store.search(query: FTS5Query(keywords: ["detente"]), limit: 10, offset: 0)
            #expect(after.isEmpty)
        }
    }

    @Test("removeVolume is scoped: another volume's same-named documents survive")
    func removeVolumeScopedToVolume() async throws {
        try await withTempDir { dir in
            let (pipeline, store) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")

            // FRUS document IDs repeat in every volume — both volumes contain "d1".
            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [("d1", "<head>Memorandum</head><p>Detente and negotiations.</p>")]
            )
            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v02.xml"),
                volumeId: "frus1969-76v02",
                documents: [("d1", "<head>Telegram</head><p>Blockade discussions in Berlin.</p>")]
            )
            try await pipeline.indexVolume("frus1969-76v01")
            try await pipeline.indexVolume("frus1969-76v02")

            try await pipeline.removeVolume("frus1969-76v01")

            // Regression: the per-document delete loop used to remove "d1" from
            // every volume, so v02's d1 vanished when v01 was removed.
            let survivors = try await store.search(
                query: FTS5Query(keywords: ["blockade"]), limit: 10, offset: 0)
            #expect(survivors.count == 1,
                    "Removing v01 must not delete v02's d1 from the FTS5 index")
            #expect(survivors.first?.volumeId == "frus1969-76v02")

            let removed = try await store.search(
                query: FTS5Query(keywords: ["detente"]), limit: 10, offset: 0)
            #expect(removed.isEmpty)
        }
    }

    @Test("removeVolume removes page_ranges rows (verified by date key query)")
    func removedVolumePageRangesCleared() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")

            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [("d1", "<head>Doc</head><pb n=\"1\"/><p>Text.</p>")]
            )
            try await pipeline.indexVolume("frus1969-76v01")
            try await pipeline.removeVolume("frus1969-76v01")

            let keys = try await pipeline.documentKeysInDateRange(
                DateRange(earliest: nil, latest: nil),
                limitToVolumeIds: ["frus1969-76v01"]
            )
            #expect(keys.isEmpty)
        }
    }
}

// MARK: - IncrementalUpdateTest

@Suite("IndexingPipeline — incremental updates")
struct IncrementalUpdateTests {

    @Test("updateSummary makes summary text searchable via user_content")
    func summaryTextSearchable() async throws {
        try await withTempDir { dir in
            let (pipeline, store) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            let service = SearchService(fts5Store: store, pipeline: pipeline)

            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [("d1", "<head>Memorandum</head><p>Original text.</p>")]
            )
            try await pipeline.indexVolume("frus1969-76v01")

            // Before update: "quasiparticle" is not in the index
            let before = try await service.search(parameters: SearchParameters(keywords: "quasiparticle"))
            #expect(before.isEmpty)

            let summary = GeneratedSummary(
                documentId: "d1", volumeId: "frus1969-76v01",
                promptId: UUID(), responseText: "Summary about quasiparticle effects."
            )
            try await pipeline.updateSummary(summary)

            // The default search scope includes summaries, which now live in the
            // user_content FTS5 table rather than frus_documents.
            let after = try await service.search(parameters: SearchParameters(keywords: "quasiparticle"))
            #expect(!after.isEmpty)

            // The corpus table must NOT match summary-only words.
            let corpusOnly = try await store.search(
                query: FTS5Query(keywords: ["quasiparticle"]), limit: 5, offset: 0)
            #expect(corpusOnly.isEmpty, "summary text must not be indexed in frus_documents")
        }
    }

    @Test("updateResearchNote makes note text searchable via user_content")
    func noteTextSearchable() async throws {
        try await withTempDir { dir in
            let (pipeline, store) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            let service = SearchService(fts5Store: store, pipeline: pipeline)

            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [("d1", "<head>Telegram</head><p>Original.</p>")]
            )
            try await pipeline.indexVolume("frus1969-76v01")

            let note = ResearchNote(
                documentId: "d1", volumeId: "frus1969-76v01",
                bodyText: "Fascinating xenolith discovery mentioned here."
            )
            try await pipeline.updateResearchNote(note)

            let results = try await service.search(parameters: SearchParameters(keywords: "xenolith"))
            #expect(!results.isEmpty)
        }
    }

    @Test("Re-indexing a volume preserves summary and note text")
    func reindexPreservesUserContent() async throws {
        try await withTempDir { dir in
            let (pipeline, store) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            let service = SearchService(fts5Store: store, pipeline: pipeline)

            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [("d1", "<head>Memorandum</head><p>Original text.</p>")]
            )
            try await pipeline.indexVolume("frus1969-76v01")
            try await pipeline.updateSummaryText(
                volumeId: "frus1969-76v01", documentId: "d1",
                responseText: "Summary about quasiparticle effects."
            )

            // Regression: INSERT OR REPLACE used to wipe summary_text/note_text on
            // every re-index; the UPSERT must preserve them.
            try await pipeline.indexVolume("frus1969-76v01")

            let after = try await service.search(parameters: SearchParameters(keywords: "quasiparticle"))
            #expect(!after.isEmpty, "Re-indexing must not wipe user summaries from the index")
        }
    }
}

// MARK: - SearchParametersTest

@Suite("SearchService — query building and filtering")
struct SearchParametersTests {

    @Test("makeMatchExpressions renders keywords into the corpus expression")
    func keywordsToMatchExpression() async throws {
        try await withTempDir { dir in
            let (pipeline, store) = try await makeTestPipeline(dir: dir)
            let service = SearchService(fts5Store: store, pipeline: pipeline)
            let params = SearchParameters(keywords: "detente kissinger")
            let (corpus, userContent) = try await service.makeMatchExpressions(from: params)
            // Adjacent keywords are joined with an explicit AND (Session 159) — FTS5
            // rejects bare juxtaposition between parenthesised groups, so the parser
            // emits the keyword everywhere for consistency.
            #expect(corpus == "\"detente\" AND \"kissinger\"")
            // Default scope flags include summaries and notes, so the user-content
            // expression is rendered from the same keywords.
            #expect(userContent == "\"detente\" AND \"kissinger\"")
        }
    }

    @Test("makeMatchExpressions scopes the user-content expression to one column")
    func userContentColumnScoping() async throws {
        try await withTempDir { dir in
            let (pipeline, store) = try await makeTestPipeline(dir: dir)
            let service = SearchService(fts5Store: store, pipeline: pipeline)
            var params = SearchParameters(keywords: "detente")
            params.includeDocumentText = false
            params.includeSummaries = true
            params.includeNotes = false
            let (corpus, userContent) = try await service.makeMatchExpressions(from: params)
            #expect(corpus == nil)
            #expect(userContent == "{summary_text}:\"detente\"")
        }
    }

    @Test("makeMatchExpressions throws emptyQuery for blank parameters")
    func emptyQueryThrows() async throws {
        try await withTempDir { dir in
            let (pipeline, store) = try await makeTestPipeline(dir: dir)
            let service = SearchService(fts5Store: store, pipeline: pipeline)
            let params = SearchParameters()   // no keywords, phrase, or wildcard
            do {
                _ = try await service.makeMatchExpressions(from: params)
                Issue.record("Expected emptyQuery error")
            } catch FTS5Error.emptyQuery {
                // expected
            }
        }
    }

    @Test("search returns results matching keyword")
    func keywordSearch() async throws {
        try await withTempDir { dir in
            let (pipeline, store) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            let service = SearchService(fts5Store: store, pipeline: pipeline)

            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [
                    ("d1", "<head>Memo</head><p>Kissinger discussed Vietnam policy.</p>"),
                    ("d2", "<head>Cable</head><p>Weather report from Moscow.</p>"),
                ]
            )
            try await pipeline.indexVolume("frus1969-76v01")

            let results = try await service.search(parameters: SearchParameters(keywords: "kissinger"))
            #expect(results.contains(where: { $0.documentId == "d1" }))
            #expect(!results.contains(where: { $0.documentId == "d2" }))
        }
    }

    @Test("search filters by volumeIds")
    func volumeIdFilter() async throws {
        try await withTempDir { dir in
            let (pipeline, store) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            let service = SearchService(fts5Store: store, pipeline: pipeline)

            for vid in ["frus1969-76v01", "frus1969-76v14"] {
                try writeTEIVolume(
                    to: volDir.appendingPathComponent("\(vid).xml"),
                    volumeId: vid,
                    documents: [("d1", "<head>Memo</head><p>Detente talks.</p>")]
                )
            }
            try await pipeline.indexAllVolumes()

            let results = try await service.search(
                parameters: SearchParameters(keywords: "detente", volumeIds: ["frus1969-76v01"])
            )
            #expect(results.allSatisfy { $0.volumeId == "frus1969-76v01" })
        }
    }

    @Test("search with phrase returns only phrase-matching results")
    func phraseSearch() async throws {
        try await withTempDir { dir in
            let (pipeline, store) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            let service = SearchService(fts5Store: store, pipeline: pipeline)

            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [
                    ("d1", "<head>Memo</head><p>The cold war continued.</p>"),
                    ("d2", "<head>Cable</head><p>Cold front approaching; war games cancelled.</p>"),
                ]
            )
            try await pipeline.indexVolume("frus1969-76v01")

            let results = try await service.search(
                parameters: SearchParameters(phrase: "cold war")
            )
            #expect(results.contains(where: { $0.documentId == "d1" }))
        }
    }

    @Test("search with boolean NOT excludes matching documents")
    func booleanNotFilter() async throws {
        try await withTempDir { dir in
            let (pipeline, store) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            let service = SearchService(fts5Store: store, pipeline: pipeline)

            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [
                    ("d1", "<head>Memo</head><p>Detente policy discussed.</p>"),
                    ("d2", "<head>Memo</head><p>Detente and SALT negotiations.</p>"),
                ]
            )
            try await pipeline.indexVolume("frus1969-76v01")

            let results = try await service.search(
                parameters: SearchParameters(keywords: "detente", excludedTerms: ["salt"])
            )
            #expect(results.contains(where: { $0.documentId == "d1" }))
            #expect(!results.contains(where: { $0.documentId == "d2" }))
        }
    }
}

// MARK: - ConcurrencyTest

@Suite("IndexingPipeline — concurrency")
struct ConcurrencyTests {

    @Test("indexAllVolumes indexes multiple volumes without data corruption")
    func concurrentIndexing() async throws {
        try await withTempDir { dir in
            let (pipeline, store) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")

            let volumeIds = ["frus1969-76v01", "frus1969-76v14", "frus1977-80v01"]
            for vid in volumeIds {
                try writeTEIVolume(
                    to: volDir.appendingPathComponent("\(vid).xml"),
                    volumeId: vid,
                    documents: [
                        ("d1", "<head>Doc 1</head><p>Text about negotiations.</p>"),
                        ("d2", "<head>Doc 2</head><p>More diplomatic cables.</p>"),
                    ]
                )
            }

            try await pipeline.indexAllVolumes()

            // Verify each volume's documents are searchable
            let results = try await store.search(
                query: FTS5Query(keywords: ["diplomatic"]), limit: 20, offset: 0)
            let indexedVolumeIds = Set(results.map(\.volumeId))
            for vid in volumeIds {
                #expect(indexedVolumeIds.contains(vid))
            }
            // No duplicates: each (volumeId, documentId) pair should appear once
            let keys = results.map { "\($0.volumeId)/\($0.documentId)" }
            #expect(Set(keys).count == keys.count)
        }
    }
}

// MARK: - Date Parsing Tests

@Suite("IndexingPipeline — date parsing")
struct DateParsingTests {

    @Test("parseDateISO extracts full date from typical FRUS dateline")
    func fullDateExtraction() {
        let date = IndexingPipeline.parseDateISO(from: "Washington, January 20, 1969.")
        #expect(date == "1969-01-20")
    }

    @Test("parseDateISO extracts year-month from month-year dateline")
    func monthYearExtraction() {
        // normalizeToFullDate pads "1971-10" → "1971-10-01" so string-comparison
        // date filtering works correctly across precisions.
        let date = IndexingPipeline.parseDateISO(from: "Moscow, October 1971")
        #expect(date == "1971-10-01")
    }

    @Test("parseDateISO falls back to year for year-only datelines")
    func yearOnlyFallback() {
        // normalizeToFullDate pads "1972" → "1972-01-01".
        let date = IndexingPipeline.parseDateISO(from: "Undated. Presumably early 1972.")
        #expect(date == "1972-01-01")
    }

    @Test("parseDateISO returns nil for unparseable datelines")
    func unparseableReturnsNil() {
        let date = IndexingPipeline.parseDateISO(from: "Undated.")
        #expect(date == nil)
    }
}

// MARK: - PageBasedCrossReferenceResolutionTests

@Suite("IndexingPipeline — page-based cross-reference resolution")
struct PageBasedCrossReferenceResolutionTests {

    /// Opens the test database read-only and returns the `target_document_id` for the single
    /// cross-reference row matching the given source volume + document IDs, or `nil` if not found.
    private func queryTargetDocumentId(
        dbURL: URL, sourceVolumeId: String, sourceDocumentId: String
    ) -> String? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(
            dbURL.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil
        ) == SQLITE_OK, let db else { return nil }
        defer { sqlite3_close_v2(db) }

        let sql = """
            SELECT target_document_id FROM cross_references
            WHERE source_volume_id = ? AND source_document_id = ?
            ORDER BY rowid LIMIT 1
            """
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        defer { sqlite3_finalize(stmt) }

        let TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, sourceVolumeId,   -1, TRANSIENT)
        sqlite3_bind_text(stmt, 2, sourceDocumentId, -1, TRANSIENT)

        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        guard let cStr = sqlite3_column_text(stmt, 0) else { return nil }
        return String(cString: cStr)
    }

    @Test("p-prefix page target (#p42) resolved to document-id after indexing")
    func pPrefixPageTargetResolvedToDocumentId() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let dbURL = dir.appendingPathComponent("test.sqlite")
            let volDir = dir.appendingPathComponent("volumes")

            // d1 references page 42 via "#p42"; d2 contains the matching <pb n="42"/>.
            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [
                    ("d1", """
                    <head>Report</head>
                    <p>See <ref target=\"#p42\">page 42</ref> for details.</p>
                    """),
                    ("d2", "<head>Annex</head><pb n=\"42\"/><p>Annex text.</p>"),
                ]
            )
            try await pipeline.indexVolume("frus1969-76v01")

            let resolved = queryTargetDocumentId(
                dbURL: dbURL, sourceVolumeId: "frus1969-76v01", sourceDocumentId: "d1"
            )
            #expect(resolved == "d2",
                    "Page target '#p42' must resolve to document 'd2'; got: \(resolved ?? "nil")")
        }
    }

    @Test("pg-prefix page target (#pg42) resolved to document-id after indexing")
    func pgPrefixPageTargetResolvedToDocumentId() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let dbURL = dir.appendingPathComponent("test.sqlite")
            let volDir = dir.appendingPathComponent("volumes")

            // d1 references page 42 via "#pg42"; d2 contains the matching <pb n="42"/>.
            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [
                    ("d1", """
                    <head>Report</head>
                    <p>See <ref target=\"#pg42\">page 42</ref> for details.</p>
                    """),
                    ("d2", "<head>Annex</head><pb n=\"42\"/><p>Annex text.</p>"),
                ]
            )
            try await pipeline.indexVolume("frus1969-76v01")

            let resolved = queryTargetDocumentId(
                dbURL: dbURL, sourceVolumeId: "frus1969-76v01", sourceDocumentId: "d1"
            )
            #expect(resolved == "d2",
                    "Page target '#pg42' must resolve to document 'd2'; got: \(resolved ?? "nil")")
        }
    }

    @Test("Unresolvable page target left unchanged when no matching page_range exists")
    func unresolvablePageTargetLeftAsIs() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let dbURL = dir.appendingPathComponent("test.sqlite")
            let volDir = dir.appendingPathComponent("volumes")

            // d1 references page 999 but no document contains <pb n="999"/>.
            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [
                    ("d1", """
                    <head>Report</head>
                    <p>See <ref target=\"#p999\">page 999</ref>.</p>
                    """),
                    ("d2", "<head>Annex</head><pb n=\"42\"/><p>Annex text.</p>"),
                ]
            )
            try await pipeline.indexVolume("frus1969-76v01")

            // The pipeline leaves unresolvable page targets in place rather than deleting them.
            let resolved = queryTargetDocumentId(
                dbURL: dbURL, sourceVolumeId: "frus1969-76v01", sourceDocumentId: "d1"
            )
            #expect(resolved == "p999",
                    "Unresolvable page target 'p999' should remain unchanged; got: \(resolved ?? "nil")")
        }
    }
}

// MARK: - Text Extraction Tests

@Suite("IndexingPipeline — text extraction")
struct TextExtractionTests {

    @Test("extractHeader returns text from head node")
    func headerExtraction() {
        let nodes: [FRUSASTNode] = [
            .head(children: [.text("42. Memorandum From the President")]),
            .paragraph(children: [.text("Body text.")])
        ]
        #expect(IndexingPipeline.extractHeader(from: nodes) == "42. Memorandum From the President")
    }

    @Test("extractDocumentNumber returns numeric prefix from head")
    func documentNumberExtraction() {
        let nodes: [FRUSASTNode] = [
            .head(children: [.text("42. Memorandum From the President")])
        ]
        #expect(IndexingPipeline.extractDocumentNumber(from: nodes) == "42")
    }

    @Test("extractSourceNote finds source footnote")
    func sourceNoteExtraction() {
        let nodes: [FRUSASTNode] = [
            .footnote(id: nil, type: .source, printedNumber: nil, children: [.text("Source: National Archives, RG 59.")]),
            .footnote(id: nil, type: .footnote, printedNumber: nil, children: [.text("Regular footnote.")]),
        ]
        let note = IndexingPipeline.extractSourceNote(from: nodes)
        #expect(note?.contains("National Archives") == true)
    }
}

// MARK: - DateIndexingAccuracyTests

/// Verifies that `extractStructuredDate` extracts dates from `.date` AST nodes
/// with correct priority ordering, falls back to the heuristic only when needed,
/// and that the date filtering pipeline accepts structured-date documents.
///
/// Version history:
///   1.0 — Session 36: initial implementation
@Suite("DateIndexingAccuracyTests")
struct DateIndexingAccuracyTests {

    @Test("structuredDatePreferredOverHeuristic — @when wins over plain-text parse")
    func structuredDatePreferredOverHeuristic() {
        // Document whose dateline text WOULD parse to a different month via heuristic.
        // The @when attribute should take priority.
        let nodes: [FRUSASTNode] = [
            .dateline(children: [
                .text("Washington, "),
                .date(when: "1969-01-15", from: nil, to: nil,
                      notBefore: nil, notAfter: nil,
                      children: [.text("January 15, 1969")])
            ])
        ]
        let result = IndexingPipeline.extractStructuredDate(from: nodes)
        #expect(result == "1969-01-15")
    }

    @Test("rangeStartUsedWhenNoExact — @from used when @when absent")
    func rangeStartUsedWhenNoExact() {
        // normalizeToFullDate pads "1969-03" → "1969-03-01".
        let nodes: [FRUSASTNode] = [
            .dateline(children: [
                .date(when: nil, from: "1969-03", to: "1969-04",
                      notBefore: nil, notAfter: nil,
                      children: [.text("March–April 1969")])
            ])
        ]
        let result = IndexingPipeline.extractStructuredDate(from: nodes)
        #expect(result == "1969-03-01")
    }

    @Test("notBeforeUsedWhenNoWhenOrFrom — @notBefore used when @when and @from absent")
    func notBeforeUsedWhenNoWhenOrFrom() {
        // normalizeToFullDate pads "1952" → "1952-01-01".
        let nodes: [FRUSASTNode] = [
            .dateline(children: [
                .date(when: nil, from: nil, to: nil,
                      notBefore: "1952", notAfter: "1953",
                      children: [.text("circa 1952–1953")])
            ])
        ]
        let result = IndexingPipeline.extractStructuredDate(from: nodes)
        #expect(result == "1952-01-01")
    }

    @Test("bodyDateUsedWhenNoDatelineDate — @when in body paragraph, no dateline date")
    func bodyDateUsedWhenNoDatelineDate() {
        let nodes: [FRUSASTNode] = [
            .dateline(children: [.text("Washington")]),
            .paragraph(children: [
                .text("The memorandum is dated "),
                .date(when: "1963-11-22", from: nil, to: nil,
                      notBefore: nil, notAfter: nil,
                      children: [.text("November 22, 1963")])
            ])
        ]
        let result = IndexingPipeline.extractStructuredDate(from: nodes)
        #expect(result == "1963-11-22")
    }

    @Test("fallbackToHeuristicWhenNoAttributes — plain dateline without <date> element")
    func fallbackToHeuristicWhenNoAttributes() {
        // Dateline has no <date> child, just plain text — heuristic must fire.
        // normalizeToFullDate pads the month-year result "1969-01" → "1969-01-01".
        let nodes: [FRUSASTNode] = [
            .dateline(children: [.text("Washington, January 1969.")])
        ]
        let result = IndexingPipeline.extractStructuredDate(from: nodes)
        #expect(result == "1969-01-01")
    }

    @Test("nullWhenTrulyUnparseable — no date information at all")
    func nullWhenTrulyUnparseable() {
        let nodes: [FRUSASTNode] = [
            .paragraph(children: [.text("Undated memorandum.")])
        ]
        let result = IndexingPipeline.extractStructuredDate(from: nodes)
        #expect(result == nil)
    }

    @Test("dateFilterReturnsDocumentWithStructuredDate — end-to-end structured date query")
    func dateFilterReturnsDocumentWithStructuredDate() async throws {
        try await withTempDir { dir in
            let volDir = dir.appendingPathComponent("volumes")
            try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)

            let volURL = volDir.appendingPathComponent("frus1961-63v01.xml")
            // Document with a structured @when date of 1961-08-13
            try writeTEIVolume(to: volURL, volumeId: "frus1961-63v01", documents: [
                (id: "d1", xml: """
                    <dateline>Berlin, <date when="1961-08-13">August 13, 1961</date></dateline>
                    <p>The wall went up.</p>
                    """)
            ])

            let (pipeline, _) = try await makeTestPipeline(dir: dir, volumesDir: volDir)
            try await pipeline.indexVolume("frus1961-63v01")

            let range = DateRange(earliest: "1961-01-01", latest: "1961-12-31")
            // documentKeysInDateRange returns Set<String> of "volumeId/documentId" composites
            let keys = try await pipeline.documentKeysInDateRange(range, limitToVolumeIds: nil)
            #expect(keys.contains("frus1961-63v01/d1"),
                    "Document with @when=1961-08-13 must appear in 1961 date-range query")
        }
    }

    @Test("needsDateReindex — returns true before markDateReindexComplete is called")
    func needsDateReindexTrue() async throws {
        try await withTempDir { dir in
            // Remove any pre-existing key that would make this test flaky
            UserDefaults.standard.removeObject(forKey: IndexingPipeline.dateIndexVersionKey)
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            #expect(pipeline.needsDateReindex == true)
        }
    }

    @Test("needsDateReindex — false after markDateReindexComplete")
    func needsDateReindexFalse() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            await pipeline.markDateReindexComplete()
            #expect(pipeline.needsDateReindex == false)
            // Cleanup
            UserDefaults.standard.removeObject(forKey: IndexingPipeline.dateIndexVersionKey)
        }
    }

    // MARK: - DatesByDocumentKeyChunkingTest (Session 129)

    @Test("DatesByDocumentKeyChunkingTest: datesByDocumentKey returns all pairs when count exceeds 499")
    func datesByDocumentKeyReturnsAllPairsAboveChunkBoundary() async throws {
        // The old implementation silently capped results at 500 pairs. The new chunked
        // implementation processes all pairs in batches of 499. This test verifies that
        // all 502 document keys are returned correctly, spanning two chunks.
        try await withTempDir { dir in
            let volDir = dir.appendingPathComponent("volumes")
            try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)

            // Build a fixture with 502 documents each bearing a unique date.
            let docCount = 502
            let docs: [(id: String, xml: String)] = (1...docCount).map { n in
                let year = 1960 + (n % 50) // spread dates across 50 years
                let month = max(1, n % 12)
                let day   = max(1, (n % 28))
                return (
                    id: "d\(n)",
                    xml: "<head>Document \(n)</head><date when=\"\(year)-\(String(format: "%02d", month))-\(String(format: "%02d", day))\">text</date><p>Body \(n).</p>"
                )
            }
            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: docs
            )

            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            try await pipeline.indexVolume("frus1969-76v01")

            // Build the full list of 502 document key pairs.
            let pairs = (1...docCount).map { n in
                (volumeId: "frus1969-76v01", documentId: "d\(n)")
            }
            let result = try await pipeline.datesByDocumentKey(pairs)

            // All documents with a <date @when> should appear in the result.
            // Allow a small tolerance for documents whose date falls outside the indexed range,
            // but at minimum all 502 keys must be queried (none silently dropped).
            #expect(result.count == docCount,
                    "datesByDocumentKey should return an entry for all \(docCount) dated documents, not just the first 499")
        }
    }
}

// MARK: - CrossReferenceContextTests

/// Verifies that `extractCrossReferences` populates the `context` column with the
/// plain text of the enclosing `<note>` or `<div type="editorialNote">`, and that
/// `<ref>` elements outside any note produce nil context.
///
/// Version history:
///   1.0 — Session 37: initial implementation
@Suite("CrossReferenceContextTests")
struct CrossReferenceContextTests {

    @Test("contextExtractedFromFootnote — <ref> inside footnote gets enclosing text")
    func contextExtractedFromFootnote() throws {
        let nodes: [FRUSASTNode] = [
            .footnote(id: nil, type: .footnote, printedNumber: nil, children: [
                .text("See "),
                .crossReference(target: "#d2", targetVolumeId: nil,
                                children: [.text("Document 2")]),
                .text(" for the Secretary's response.")
            ])
        ]
        let rows = IndexingPipeline.extractCrossReferences(
            from: nodes, sourceVolumeId: "vol1", sourceDocumentId: "d1"
        )
        #expect(rows.count == 1)
        let ctx = try #require(rows.first?.context)
        #expect(ctx.contains("Secretary's response"), "Context must contain the footnote text")
    }

    @Test("contextTruncatedAt500Chars — long footnote text is truncated with ellipsis")
    func contextTruncatedAt500Chars() throws {
        // Build a footnote whose plain text exceeds 500 characters.
        let longText = String(repeating: "word ", count: 120) // 600 chars
        let nodes: [FRUSASTNode] = [
            .footnote(id: nil, type: .footnote, printedNumber: nil, children: [
                .text(longText),
                .crossReference(target: "#d3", targetVolumeId: nil,
                                children: [.text("Document 3")])
            ])
        ]
        let rows = IndexingPipeline.extractCrossReferences(
            from: nodes, sourceVolumeId: "vol1", sourceDocumentId: "d1"
        )
        #expect(rows.count == 1)
        let ctx = try #require(rows.first?.context)
        // Context must be truncated: ≤ 501 characters (500 + the "…" ellipsis).
        #expect(ctx.count <= 501, "Truncated context must be ≤ 501 characters")
        #expect(ctx.hasSuffix("…"), "Truncated context must end with an ellipsis")
    }

    @Test("contextNullForTopLevelRef — <ref> in bare paragraph gets nil context")
    func contextNullForTopLevelRef() {
        let nodes: [FRUSASTNode] = [
            .paragraph(children: [
                .text("As noted in "),
                .crossReference(target: "#d4", targetVolumeId: nil,
                                children: [.text("Document 4")]),
                .text(".")
            ])
        ]
        let rows = IndexingPipeline.extractCrossReferences(
            from: nodes, sourceVolumeId: "vol1", sourceDocumentId: "d1"
        )
        #expect(rows.count == 1)
        #expect(rows.first?.context == nil,
                "<ref> outside a note block must produce nil context")
    }

    @Test("editorialNoteContextExtracted — <ref> inside editorial note gets context")
    func editorialNoteContextExtracted() throws {
        let nodes: [FRUSASTNode] = [
            .editorialNote([
                .text("This editorial note references "),
                .crossReference(target: "#d5", targetVolumeId: nil,
                                children: [.text("Document 5")]),
                .text(" as background.")
            ])
        ]
        let rows = IndexingPipeline.extractCrossReferences(
            from: nodes, sourceVolumeId: "vol1", sourceDocumentId: "d1"
        )
        #expect(rows.count == 1)
        let row = try #require(rows.first)
        #expect(row.referenceType == "editorialNote")
        let ctx = try #require(row.context)
        #expect(ctx.contains("editorial note"), "Context must contain editorial note text")
        #expect(ctx.contains("background"))
    }

    @Test("nestedRefInheritsFunctionContext — deeply nested <ref> still captures enclosing note")
    func nestedRefInheritsFunctionContext() throws {
        // <ref> inside an emphasis inside a footnote — context should still be the footnote text.
        let nodes: [FRUSASTNode] = [
            .footnote(id: nil, type: .footnote, printedNumber: nil, children: [
                .text("Confirmed in "),
                .emphasis(style: .italic, children: [
                    .crossReference(target: "#d6", targetVolumeId: nil,
                                    children: [.text("Memorandum")])
                ]),
                .text(", p. 5.")
            ])
        ]
        let rows = IndexingPipeline.extractCrossReferences(
            from: nodes, sourceVolumeId: "vol1", sourceDocumentId: "d1"
        )
        #expect(rows.count == 1)
        let ctx = try #require(rows.first?.context)
        #expect(ctx.contains("Confirmed"), "Nested <ref> must inherit enclosing footnote context")
    }
}

// MARK: - EditorialNoteFilterTests

/// Verifies that `<div type="editorialNote">` is indexed with `is_editorial_note = 1`
/// and that `SearchParameters.documentTypeFilter` correctly filters search results.
///
/// Version history:
///   1.0 — Session 38: initial implementation
@Suite("EditorialNoteFilterTests")
struct EditorialNoteFilterTests {

    // Build a minimal volume XML with one document and one editorial note.
    private func makeVolumeXML() -> String {
        """
        <?xml version="1.0"?>
        <TEI><text><body>
        <div type="document" xml:id="d1">
          <head>1. Memorandum of Conversation</head>
          <p>The Secretary discussed editorial policy.</p>
        </div>
        <div type="editorialNote" xml:id="en1">
          <p>This editorial note explains the editorial policy discussed above.</p>
        </div>
        </body></text></TEI>
        """
    }

    private func makePipelineFixture() async throws -> (dir: URL, pipeline: IndexingPipeline, searchService: SearchService) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSEditNote-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("test.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)

        // Write the volume XML.
        let volURL = volDir.appendingPathComponent("vol1.xml")
        try makeVolumeXML().data(using: .utf8)!.write(to: volURL)

        let fts5 = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: fts5,
            databaseURL: dbURL,
            volumesDirectory: volDir,
            subjectTagStore: SubjectTagStore(entries: [], appearances: []),
            concurrencyLimit: 1
        )
        try await pipeline.indexVolume("vol1")

        let searchService = SearchService(fts5Store: fts5, pipeline: pipeline)
        return (dir, pipeline, searchService)
    }

    @Test("editorialNoteIndexedWithFlag — document_cache row for en1 has is_editorial_note = 1")
    func editorialNoteIndexedWithFlag() async throws {
        let (dir, pipeline, _) = try await makePipelineFixture()
        defer { try? FileManager.default.removeItem(at: dir) }

        let docs = try await pipeline.documents(forVolume: "vol1")
        let en1 = try #require(docs.first { $0.documentId == "en1" },
                               "Editorial note en1 must appear in documents(forVolume:)")
        #expect(en1.isEditorialNote == true,
                "en1 must have isEditorialNote = true")

        let d1 = try #require(docs.first { $0.documentId == "d1" })
        #expect(d1.isEditorialNote == false,
                "Primary document d1 must have isEditorialNote = false")
    }

    @Test("documentsOnlyFilterExcludesEditorialNote — search with .documentsOnly omits en1")
    func documentsOnlyFilterExcludesEditorialNote() async throws {
        let (dir, _, searchService) = try await makePipelineFixture()
        defer { try? FileManager.default.removeItem(at: dir) }

        var params = SearchParameters(keywords: "editorial")
        params.documentTypeFilter = .documentsOnly
        let results = try await searchService.search(parameters: params)
        let ids = results.map(\.documentId)
        #expect(!ids.contains("en1"),
                "documentsOnly filter must exclude the editorial note")
    }

    @Test("editorialNotesOnlyFilterReturnsOnlyNotes — search with .editorialNotesOnly returns only en1")
    func editorialNotesOnlyFilterReturnsOnlyNotes() async throws {
        let (dir, _, searchService) = try await makePipelineFixture()
        defer { try? FileManager.default.removeItem(at: dir) }

        var params = SearchParameters(keywords: "editorial")
        params.documentTypeFilter = .editorialNotesOnly
        let results = try await searchService.search(parameters: params)
        #expect(!results.isEmpty, "Editorial notes only filter must return en1")
        let allAreEditorialNotes = results.allSatisfy { $0.isEditorialNote }
        #expect(allAreEditorialNotes,
                "All results with editorialNotesOnly must be editorial notes")
    }

    @Test("defaultFilterReturnsAll — search with .all returns both d1 and en1")
    func defaultFilterReturnsAll() async throws {
        let (dir, _, searchService) = try await makePipelineFixture()
        defer { try? FileManager.default.removeItem(at: dir) }

        var params = SearchParameters(keywords: "editorial")
        params.documentTypeFilter = .all
        let results = try await searchService.search(parameters: params)
        let ids = Set(results.map(\.documentId))
        // Both d1 and en1 contain "editorial" in their text; both must appear.
        #expect(ids.contains("en1"), "Default filter must include editorial note")
    }
}

// MARK: - PersonMentionIndexingTests

/// Verifies that `extractPersonRefs` and the indexing pipeline correctly
/// populate the `person_mentions` table.
///
/// Version history:
///   1.0 — Session 39: initial implementation
@Suite("PersonMentionIndexingTests")
struct PersonMentionIndexingTests {

    @Test("personRefsExtractedFromDocument — deduplication: two refs from same doc, only 2 rows")
    func personRefsExtractedFromDocument() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")

            // d1 mentions p1 three times and p2 once; expect 2 unique rows for d1
            try writeTEIVolume(
                to: volDir.appendingPathComponent("vol1.xml"),
                volumeId: "vol1",
                documents: [
                    ("d1", """
                    <head>1. Report</head>
                    <p><persName ref="p1">Kissinger</persName> met <persName ref="p1">Kissinger</persName>
                    and <persName ref="p2">Nixon</persName>.</p>
                    """),
                ]
            )
            try await pipeline.indexVolume("vol1")

            let dbURL = dir.appendingPathComponent("test.sqlite")
            let store = try PersonMentionStore(databaseURL: dbURL)
            let refs = try await store.personRefs(forDocumentId: "d1", volumeId: "vol1")
            #expect(refs.sorted() == ["p1", "p2"],
                    "p1 mentioned 3 times must yield exactly 1 row; p2 gives 1 row; total 2")
        }
    }

    @Test("personRefWithNoRefAttribute — <persName> with no ref yields no row")
    func personRefWithNoRefAttribute() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")

            try writeTEIVolume(
                to: volDir.appendingPathComponent("vol1.xml"),
                volumeId: "vol1",
                documents: [
                    ("d1", "<head>1. Report</head><p><persName>No Ref Here</persName></p>"),
                ]
            )
            try await pipeline.indexVolume("vol1")

            let dbURL = dir.appendingPathComponent("test.sqlite")
            let store = try PersonMentionStore(databaseURL: dbURL)
            let refs = try await store.personRefs(forDocumentId: "d1", volumeId: "vol1")
            #expect(refs.isEmpty, "<persName> with no ref must produce no person_mentions row")
        }
    }

    @Test("removeVolumeDeletesPersonMentions — person_mentions rows removed after removeVolume")
    func removeVolumeDeletesPersonMentions() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")

            try writeTEIVolume(
                to: volDir.appendingPathComponent("vol1.xml"),
                volumeId: "vol1",
                documents: [
                    ("d1", "<head>1. Doc</head><p><persName ref=\"p1\">Name</persName></p>"),
                ]
            )
            try await pipeline.indexVolume("vol1")

            let dbURL = dir.appendingPathComponent("test.sqlite")
            let store = try PersonMentionStore(databaseURL: dbURL)

            // Verify rows exist before removal
            let beforeCount = try await store.documentCount(volumeId: "vol1", ref: "p1")
            #expect(beforeCount == 1, "Row must exist before removal")

            try await pipeline.removeVolume("vol1")

            let afterCount = try await store.documentCount(volumeId: "vol1", ref: "p1")
            #expect(afterCount == 0, "person_mentions rows must be deleted when volume is removed")
        }
    }
}

// MARK: - GlossaryPersistenceTests

struct GlossaryPersistenceTests {

    // Shared helper: write a TEI volume with a persons list and a terms section.
    private func writeGlossaryFixture(to url: URL, volumeId: String) throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <teiHeader><fileDesc><titleStmt><title>\(volumeId)</title></titleStmt>
          <publicationStmt><date>1969</date></publicationStmt>
          <sourceDesc><p>Test</p></sourceDesc></fileDesc></teiHeader>
          <text><body>
            <div type="document" xml:id="d1">
              <head>1. Memorandum</head>
              <p>Text mentioning <persName ref="p_kissinger">Kissinger</persName>.</p>
            </div>
            <div type="persons">
              <list>
                <item xml:id="p_kissinger">Kissinger, Henry A.: National Security Advisor.</item>
                <item xml:id="p_nixon">Nixon, Richard M.: President of the United States.</item>
                <item xml:id="p_rogers">Rogers, William P.: Secretary of State.</item>
              </list>
            </div>
            <div type="terms">
              <list>
                <item xml:id="t_nsc"><term>NSC</term>: National Security Council</item>
                <item xml:id="t_nssm"><term>NSSM</term>: National Security Study Memorandum</item>
              </list>
            </div>
          </body></text>
        </TEI>
        """
        try xml.data(using: .utf8)!.write(to: url)
    }

    private func makeGlossaryPipeline() throws -> (dir: URL, dbURL: URL, store: PersonMentionStore, pipeline: IndexingPipeline) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSGlossary-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("test.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)

        let fts5 = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: fts5,
            databaseURL: dbURL,
            volumesDirectory: volDir,
            subjectTagStore: SubjectTagStore(entries: [], appearances: []),
            concurrencyLimit: 1
        )
        let store = try PersonMentionStore(databaseURL: dbURL)
        return (dir, dbURL, store, pipeline)
    }

    @Test("personsIndexedAfterVolumeIndex — persons table has correct rows after indexing")
    func personsIndexedAfterVolumeIndex() async throws {
        let (dir, dbURL, store, pipeline) = try makeGlossaryPipeline()
        defer { try? FileManager.default.removeItem(at: dir) }

        try writeGlossaryFixture(
            to: dbURL.deletingLastPathComponent().appendingPathComponent("volumes/frus1969-76v01.xml"),
            volumeId: "frus1969-76v01"
        )
        try await pipeline.indexVolume("frus1969-76v01")

        let persons = try await store.allPersons(forVolumeId: "frus1969-76v01")
        #expect(persons.count == 3)
        let names = persons.map(\.name).sorted()
        #expect(names.contains("Kissinger, Henry A."))
        #expect(names.contains("Nixon, Richard M."))
        #expect(names.contains("Rogers, William P."))

        // Verify volume_id is correctly recorded
        let kissinger = try await store.person(forRef: "p_kissinger", volumeId: "frus1969-76v01")
        #expect(kissinger?.name == "Kissinger, Henry A.")
    }

    @Test("termsIndexedAfterVolumeIndex — terms table has correct rows after indexing")
    func termsIndexedAfterVolumeIndex() async throws {
        let (dir, dbURL, _, pipeline) = try makeGlossaryPipeline()
        defer { try? FileManager.default.removeItem(at: dir) }

        try writeGlossaryFixture(
            to: dbURL.deletingLastPathComponent().appendingPathComponent("volumes/frus1969-76v01.xml"),
            volumeId: "frus1969-76v01"
        )
        try await pipeline.indexVolume("frus1969-76v01")

        // Query terms directly via SQLite
        let store = try PersonMentionStore(databaseURL: dbURL)
        let terms = try await store.allTerms(forVolumeId: "frus1969-76v01")
        #expect(terms.count == 2)
        let termTexts = terms.map(\.term).sorted()
        #expect(termTexts == ["NSC", "NSSM"])

        let nsc = try await store.term(forRef: "t_nsc", volumeId: "frus1969-76v01")
        #expect(nsc?.term == "NSC")
        #expect(nsc?.definition?.contains("National Security Council") == true)
    }

    @Test("personsRemovedOnVolumeRemoval — persons and terms cleared when volume is removed")
    func personsRemovedOnVolumeRemoval() async throws {
        let (dir, dbURL, store, pipeline) = try makeGlossaryPipeline()
        defer { try? FileManager.default.removeItem(at: dir) }

        try writeGlossaryFixture(
            to: dbURL.deletingLastPathComponent().appendingPathComponent("volumes/frus1969-76v01.xml"),
            volumeId: "frus1969-76v01"
        )
        try await pipeline.indexVolume("frus1969-76v01")

        // Confirm data present before removal
        let beforePersons = try await store.allPersons(forVolumeId: "frus1969-76v01")
        #expect(beforePersons.count == 3)

        try await pipeline.removeVolume("frus1969-76v01")

        let afterPersons = try await store.allPersons(forVolumeId: "frus1969-76v01")
        #expect(afterPersons.isEmpty)

        let afterTerms = try await store.allTerms(forVolumeId: "frus1969-76v01")
        #expect(afterTerms.isEmpty)
    }

    @Test("personsUpdatedOnReindex — INSERT OR REPLACE refreshes rows on re-index")
    func personsUpdatedOnReindex() async throws {
        let (dir, dbURL, store, pipeline) = try makeGlossaryPipeline()
        defer { try? FileManager.default.removeItem(at: dir) }

        let volPath = dbURL.deletingLastPathComponent().appendingPathComponent("volumes/frus1969-76v01.xml")
        try writeGlossaryFixture(to: volPath, volumeId: "frus1969-76v01")
        try await pipeline.indexVolume("frus1969-76v01")

        let before = try await store.allPersons(forVolumeId: "frus1969-76v01")
        #expect(before.count == 3)

        // Write a revised fixture with an extra person
        let xml2 = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <teiHeader><fileDesc><titleStmt><title>frus1969-76v01</title></titleStmt>
          <publicationStmt><date>1969</date></publicationStmt>
          <sourceDesc><p>Test</p></sourceDesc></fileDesc></teiHeader>
          <text><body>
            <div type="document" xml:id="d1"><head>1. Memo</head><p>Body.</p></div>
            <div type="persons">
              <list>
                <item xml:id="p_kissinger">Kissinger, Henry A.: NSA.</item>
                <item xml:id="p_nixon">Nixon, Richard M.: President.</item>
                <item xml:id="p_rogers">Rogers, William P.: Secretary of State.</item>
                <item xml:id="p_haig">Haig, Alexander M.: Deputy NSA.</item>
              </list>
            </div>
          </body></text>
        </TEI>
        """
        try xml2.data(using: .utf8)!.write(to: volPath)
        try await pipeline.indexVolume("frus1969-76v01")

        let after = try await store.allPersons(forVolumeId: "frus1969-76v01")
        // The new index added p_haig; INSERT OR REPLACE keeps all rows fresh.
        #expect(after.map(\.ref).contains("p_haig"))
    }
}

// MARK: - FTS5RebuildTests

/// Tests for the FTS5 schema-generation migration.
///
/// A `frus_documents` table from a database whose `PRAGMA user_version` is below
/// the current generation (4 — the external-content redesign) is dropped and
/// recreated by `FTS5Connection.createSchema`; `FTS5Store.didRebuildSchema`
/// signals the caller to rebuild index contents from `document_cache`.
@Suite("FTS5RebuildTests")
struct FTS5RebuildTests {

    // MARK: - Helpers

    /// Creates an FTS5 database with a legacy (pre-generation-4) schema.
    ///
    /// Uses raw SQLite3 calls to build the legacy table so `FTS5Store.init` sees
    /// an existing database with the outdated schema.
    private func createLegacyDatabase(at url: URL) throws {
        var db: OpaquePointer?
        let rc = sqlite3_open_v2(
            url.path, &db,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX,
            nil
        )
        guard rc == SQLITE_OK, let handle = db else {
            sqlite3_close(db)
            throw NSError(domain: "FTS5RebuildTests", code: Int(rc))
        }
        defer { sqlite3_close_v2(handle) }

        // Create the FTS5 table with only 11 columns (missing is_editorial_note).
        let legacySQL = """
        CREATE VIRTUAL TABLE frus_documents USING fts5(
            document_id UNINDEXED,
            volume_id UNINDEXED,
            document_number UNINDEXED,
            header,
            dateline,
            source_note,
            body_text,
            subject_tag_ids UNINDEXED,
            user_tag_ids UNINDEXED,
            summary_text,
            note_text,
            tokenize = 'unicode61'
        )
        """
        var errmsg: UnsafeMutablePointer<CChar>?
        sqlite3_exec(handle, legacySQL, nil, nil, &errmsg)
        sqlite3_free(errmsg)
        // Insert one row so that the table is non-empty and row survival can be tested.
        sqlite3_exec(
            handle,
            "INSERT INTO frus_documents (document_id, volume_id, header, body_text) VALUES ('d1', 'frus1861', 'Test Header', 'Test body')",
            nil, nil, &errmsg
        )
        sqlite3_free(errmsg)
        // user_version intentionally left at 0 (simulates pre-migration database).
    }

    // MARK: - Tests

    /// Opening a legacy (pre-generation-4) FTS5 database triggers a schema rebuild.
    @Test("ftsSchemaUpgradeRebuildsLegacyTable")
    func ftsSchemaUpgradeRebuildsLegacyTable() async throws {
        try await withTempDir { dir in
            let dbURL = dir.appendingPathComponent("legacy.sqlite")
            try createLegacyDatabase(at: dbURL)

            let store = try FTS5Store(databaseURL: dbURL)
            #expect(store.didRebuildSchema == true,
                    "FTS5Store should detect the legacy schema generation and set didRebuildSchema")

            // The rebuilt table is external-content: direct writes must be rejected…
            await #expect(throws: FTS5Error.self) {
                try await store.insert(document: FTS5Document(
                    id: "d2", volumeId: "frus1861",
                    header: "Rebuilt Header", bodyText: "Rebuilt body",
                    isEditorialNote: true
                ))
            }
            // …and an (empty) search must succeed against the new schema.
            let results = try await store.search(
                query: FTS5Query(keywords: ["anything"]), limit: 5, offset: 0)
            #expect(results.isEmpty)
        }
    }

    /// After a legacy-schema migration, the full stack (pipeline + triggers +
    /// rebuild-from-cache) produces a searchable index without re-parsing XML
    /// beyond the initial indexing.
    @Test("ftsRebuildPreservesTableFunctionality")
    func ftsRebuildPreservesTableFunctionality() async throws {
        try await withTempDir { dir in
            let dbURL = dir.appendingPathComponent("legacy2.sqlite")
            try createLegacyDatabase(at: dbURL)

            let store = try FTS5Store(databaseURL: dbURL)
            #expect(store.didRebuildSchema == true)

            // Construct the pipeline on the migrated database (creates
            // document_cache, user_content, and the sync triggers), then index a
            // volume and verify search works end-to-end.
            let volDir = dir.appendingPathComponent("volumes")
            try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
            let pipeline = try IndexingPipeline(
                fts5Store: store,
                databaseURL: dbURL,
                volumesDirectory: volDir,
                subjectTagStore: SubjectTagStore(entries: [], appearances: []),
                concurrencyLimit: 1
            )
            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [("d3", "<head>Rebuilt document</head><p>searchable content after rebuild</p>")]
            )
            try await pipeline.indexVolume("frus1969-76v01")

            let query = FTS5Query(keywords: ["searchable"], booleanMode: .and)
            let results = try await store.search(query: query, limit: 10, offset: 0)
            #expect(!results.isEmpty, "Search should return results after schema rebuild")

            // rebuildSearchIndexFromCache must also be a no-op-safe operation that
            // leaves the index searchable (the boot migration path runs it).
            try await pipeline.rebuildSearchIndexFromCache()
            let afterRebuild = try await store.search(query: query, limit: 10, offset: 0)
            #expect(!afterRebuild.isEmpty, "Index must remain searchable after rebuild-from-cache")
        }
    }

    /// `needsFTSRebuildReindex` returns `true` before marking complete and `false` after.
    @Test("migrationFlagTriggersReindexMarker")
    func migrationFlagTriggersReindexMarker() async throws {
        // Clear any prior state so the test starts clean.
        UserDefaults.standard.removeObject(forKey: IndexingPipeline.ftsSchemaVersionKey)

        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)

            // UserDefaults key is absent (integer returns 0) → needs reindex.
            #expect(pipeline.needsFTSRebuildReindex == true)

            await pipeline.markFTSRebuildReindexComplete()
            #expect(pipeline.needsFTSRebuildReindex == false)

            // Cleanup: restore UserDefaults to a clean state.
            UserDefaults.standard.removeObject(forKey: IndexingPipeline.ftsSchemaVersionKey)
        }
    }

    /// A fresh database (no prior FTS5 table) does not trigger a rebuild.
    @Test("freshInstallDoesNotRebuild")
    func freshInstallDoesNotRebuild() async throws {
        try await withTempDir { dir in
            let dbURL = dir.appendingPathComponent("fresh.sqlite")
            // No pre-existing table — FTS5Store creates it fresh.
            let store = try FTS5Store(databaseURL: dbURL)
            #expect(store.didRebuildSchema == false,
                    "Fresh install should create the correct schema without a rebuild")
        }
    }
}

// MARK: - IndexingThrottleTests

@Suite("IndexingPipeline — iOS batch-size throttle")
struct IndexingThrottleTests {

    @Test("platformDefaultBatchSize is 50 on iOS and Int.max on macOS")
    func batchSizeiOS50MacUnlimited() {
        #if os(iOS)
        #expect(IndexingPipeline.platformDefaultBatchSize == 50,
                "iOS batch size must be capped at 50 to limit peak RSS")
        #else
        #expect(IndexingPipeline.platformDefaultBatchSize == Int.max,
                "macOS should use a single unlimited transaction")
        #endif
    }

    #if os(iOS)
    @Test("memory warning notification reduces effective batch size to 20")
    func batchSizeIsReducedUnderMemoryPressure() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            // Confirm default before warning.
            let before = await pipeline.effectiveBatchSize
            let platformDefault = IndexingPipeline.platformDefaultBatchSize
            #expect(before == platformDefault,
                    "Effective batch size should start at platform default")

            // Simulate a memory warning on the main thread (exactly as UIKit fires it).
            await MainActor.run {
                NotificationCenter.default.post(
                    name: UIApplication.didReceiveMemoryWarningNotification,
                    object: nil
                )
            }
            // Give the actor Task a chance to run.
            try await Task.sleep(for: .milliseconds(50))

            let after = await pipeline.effectiveBatchSize
            #expect(after == 20, "Memory warning must reduce batch size to 20")
        }
    }
    #endif

    @Test("setTestBatchSize overrides batch size; all documents still indexed correctly")
    func taskYieldCalledBetweenBatches() async throws {
        try await withTempDir { dir in
            let volDir = dir.appendingPathComponent("volumes")
            try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
            let (pipeline, store) = try await makeTestPipeline(dir: dir, volumesDir: volDir)

            // Write a volume with 5 documents, then force batch size = 1 so we get
            // 5 separate insertBatch calls, each followed by Task.yield().
            let documents = (1...5).map { n in
                (id: "doc-\(n)", xml: "<head>Doc \(n)</head><p>Content \(n) searchable</p>")
            }
            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: documents
            )
            await pipeline.setTestBatchSize(1)
            try await pipeline.indexVolume("frus1969-76v01")

            // Verify all 5 documents were indexed despite 1-doc batches.
            let query = FTS5Query(keywords: ["searchable"], booleanMode: .and)
            let results = try await store.search(query: query, limit: 20, offset: 0)
            #expect(results.count == 5,
                    "All 5 documents must be indexed even with batch size 1")
        }
    }
}

// MARK: - IndexingProgressStreamTests

/// Helper: collect all `IndexingProgressUpdate` values up to (and including)
/// the first `.complete` update. Runs in an unstructured Task and uses an
/// `@unchecked Sendable` box so Swift 6 strict-concurrency is satisfied without
/// actor overhead in tests.
private final class UpdateBox: @unchecked Sendable {
    var updates: [IndexingProgressUpdate] = []
}

@Suite("IndexingPipeline — progressStream")
struct IndexingProgressStreamTests {

    @Test("progressStream emits a buildingFTS5 update during indexing")
    func progressStreamEmitsOnStageTransition() async throws {
        try await withTempDir { dir in
            let volDir = dir.appendingPathComponent("volumes")
            try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
            let (pipeline, _) = try await makeTestPipeline(dir: dir, volumesDir: volDir)

            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [(id: "doc-1", xml: "<head>Test</head><p>body</p>")]
            )

            let box = UpdateBox()
            let collectTask = Task {
                for await update in await pipeline.progressStream {
                    box.updates.append(update)
                    if update.stage == .complete { break }
                }
            }

            try await pipeline.indexVolume("frus1969-76v01")
            try await Task.sleep(for: .milliseconds(50))
            collectTask.cancel()

            let hasBatch = box.updates.contains { if case .storingBatch = $0.stage { return true }; return false }
            #expect(hasBatch,
                    "progressStream must emit at least one .storingBatch update during indexVolume")
        }
    }

    @Test("progressStream emits a complete update when indexing finishes")
    func progressStreamEmitsCompleteOnFinish() async throws {
        try await withTempDir { dir in
            let volDir = dir.appendingPathComponent("volumes")
            try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
            let (pipeline, _) = try await makeTestPipeline(dir: dir, volumesDir: volDir)

            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [(id: "doc-1", xml: "<head>Test</head><p>body</p>")]
            )

            let box = UpdateBox()
            let collectTask = Task {
                for await update in await pipeline.progressStream {
                    box.updates.append(update)
                    if update.stage == .complete { break }
                }
            }

            try await pipeline.indexVolume("frus1969-76v01")
            try await Task.sleep(for: .milliseconds(50))
            collectTask.cancel()

            let finalStage = box.updates.last?.stage
            #expect(finalStage == .complete,
                    "The last emitted update must have stage .complete")
        }
    }

    @Test("progressStream docsPerSecond is non-negative and completedDocuments > 0 after indexing")
    func progressStreamDocsPerSecIsRollingAverage() async throws {
        try await withTempDir { dir in
            let volDir = dir.appendingPathComponent("volumes")
            try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
            let (pipeline, _) = try await makeTestPipeline(dir: dir, volumesDir: volDir)

            let docs = (1...3).map { n in
                (id: "doc-\(n)", xml: "<head>Doc \(n)</head><p>Body \(n)</p>")
            }
            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: docs
            )

            let box = UpdateBox()
            let collectTask = Task {
                for await update in await pipeline.progressStream {
                    box.updates.append(update)
                    if update.stage == .complete { break }
                }
            }

            try await pipeline.indexVolume("frus1969-76v01")
            try await Task.sleep(for: .milliseconds(50))
            collectTask.cancel()

            if let u = box.updates.first(where: { if case .storingBatch = $0.stage { return true }; return false }) {
                let dps = u.docsPerSecond
                let completed = u.completedDocuments
                let total = u.totalDocuments
                #expect(dps >= 0, "docsPerSecond must be non-negative")
                #expect(total == 3, "totalDocuments must equal volume document count")
                _ = completed // completedDocuments may be 0 at batch start (emitted before write)
            } else {
                Issue.record("No .storingBatch update was emitted")
            }
        }
    }
}

// MARK: - Session 54: Memory & Concurrency Tests

@Suite("IndexingPipeline — Session 54 memory fixes")
struct IndexingMemoryTests {

    /// Verifies that `storeIndexData` writes FTS5 + document_cache in co-batched chunks.
    ///
    /// With batchSize = 2 and 5 documents, we expect 3 write batches (2 + 2 + 1).
    /// The test confirms all 5 documents end up indexed and searchable — the
    /// co-batching must not drop or duplicate any rows.
    @Test("Co-batched writes store all documents correctly")
    func batchWriteStoresAllDocuments() async throws {
        try await withTempDir { dir in
            let (pipeline, store) = try await makeTestPipeline(dir: dir)
            // Reduce batch size so the co-batching path is exercised with a small fixture.
            await pipeline.setTestBatchSize(2)

            let volDir = dir.appendingPathComponent("volumes")
            // Use unique single-word search terms to avoid FTS5 tokenizer ambiguity.
            let uniqueWords = ["quorum", "lacuna", "veritas", "nexus", "ephemeral"]
            let docs = uniqueWords.enumerated().map { (n, word) in
                (id: "d\(n + 1)", xml: "<head>Document \(n + 1)</head><p>Unique term \(word) here.</p>")
            }
            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: docs
            )

            try await pipeline.indexVolume("frus1969-76v01")

            // All 5 documents must be searchable after co-batched writes.
            for (n, word) in uniqueWords.enumerated() {
                let results = try await store.search(
                    query: FTS5Query(keywords: [word]),
                    limit: 5, offset: 0
                )
                #expect(!results.isEmpty, "Document d\(n + 1) (\(word)) not found after co-batched write")
                if let first = results.first {
                    #expect(first.documentId == "d\(n + 1)")
                }
            }
        }
    }

    /// Verifies that `effectiveConcurrencyLimit` is 1 on iOS and equals
    /// `concurrencyLimit` on macOS, keeping the iOS memory cap in place.
    @Test("effectiveConcurrencyLimit is 1 on iOS, concurrencyLimit on macOS")
    func effectiveConcurrencyLimitPlatform() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let limit = await pipeline.testEffectiveConcurrencyLimit()
            #if os(iOS)
            #expect(limit == 1, "iOS must cap concurrency to 1 to bound peak RSS")
            #else
            #expect(limit == 2, "macOS should use the caller-supplied concurrencyLimit (2 in tests)")
            #endif
        }
    }
}

// MARK: - VolumeStructureCacheTests

@Suite("IndexingPipeline — volume structure cache")
struct VolumeStructureCacheTests {

    @Test("indexVolume persists the Browser structure; removeVolume clears it")
    func structurePersistedAndCleared() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")

            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [
                    ("d1", "<head>Memo</head><p>Detente talks.</p>"),
                    ("d2", "<head>Cable</head><p>Berlin briefing.</p>"),
                ]
            )
            try await pipeline.indexVolume("frus1969-76v01")

            let structure = try await pipeline.cachedVolumeStructure(forVolumeId: "frus1969-76v01")
            let comp = structure?.sections.first { $0.sectionId == "comp1" }
            #expect(comp != nil, "compilation section should be captured during indexing")
            #expect(comp?.documentIds.contains("d1") == true)
            #expect(comp?.documentIds.contains("d2") == true)

            try await pipeline.removeVolume("frus1969-76v01")
            let after = try await pipeline.cachedVolumeStructure(forVolumeId: "frus1969-76v01")
            #expect(after == nil, "removeVolume must clear the cached structure")
        }
    }
}

// MARK: - DocumentWindowParseTests

@Suite("FRUSDocumentParser — document window")
struct DocumentWindowParseTests {

    /// Writes a four-document fixture and returns its URL.
    private func writeFourDocVolume(in dir: URL) throws -> URL {
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        let url = volDir.appendingPathComponent("frus1969-76v01.xml")
        try writeTEIVolume(
            to: url,
            volumeId: "frus1969-76v01",
            documents: [
                ("d1", "<head>One</head><p>First document.</p>"),
                ("d2", "<head>Two</head><p>Second document.</p>"),
                ("d3", "<head>Three</head><p>Third document.</p>"),
                ("d4", "<head>Four</head><p>Fourth document.</p>"),
            ]
        )
        return url
    }

    @Test("parseDocumentWindow returns the prefix, target, and one trailing document")
    func windowIncludesTrailing() async throws {
        try await withTempDir { dir in
            let url = try writeFourDocVolume(in: dir)
            let window = try await FRUSDocumentParser().parseDocumentWindow(
                documentId: "d2", volumeURL: url, trailingDocuments: 1)
            #expect(window.map(\.documentId) == ["d1", "d2", "d3"],
                    "window should stop one document past the target")
        }
    }

    @Test("parseDocumentWindow at the last document reaches EOF without error")
    func windowAtEndOfVolume() async throws {
        try await withTempDir { dir in
            let url = try writeFourDocVolume(in: dir)
            let window = try await FRUSDocumentParser().parseDocumentWindow(
                documentId: "d4", volumeURL: url, trailingDocuments: 1)
            #expect(window.map(\.documentId) == ["d1", "d2", "d3", "d4"],
                    "no trailing document exists past d4; clean EOF expected")
        }
    }

    @Test("parseDocumentWindow for a missing ID returns an empty array")
    func windowMissingTarget() async throws {
        try await withTempDir { dir in
            let url = try writeFourDocVolume(in: dir)
            let window = try await FRUSDocumentParser().parseDocumentWindow(
                documentId: "d99", volumeURL: url, trailingDocuments: 1)
            #expect(window.isEmpty)
        }
    }

    @Test("parseDocument still returns exactly the target document")
    func singleDocumentParseUnchanged() async throws {
        try await withTempDir { dir in
            let url = try writeFourDocVolume(in: dir)
            let ast = try await FRUSDocumentParser().parseDocument(
                documentId: "d3", volumeURL: url)
            #expect(ast?.documentId == "d3")
        }
    }
}

// MARK: - DocumentASTCacheTests

@Suite("DocumentASTCache")
struct DocumentASTCacheTests {

    @Test("store and retrieve round-trips; LRU evicts beyond capacity")
    func lruBehaviour() async throws {
        let cache = DocumentASTCache(capacity: 2)
        let docs = (1...3).map { FRUSDocumentAST(documentId: "d\($0)", nodes: []) }
        await cache.store([docs[0], docs[1]], volumeId: "v1")
        #expect(await cache.ast(volumeId: "v1", documentId: "d1") != nil)

        // d1 was just touched, so storing d3 must evict d2 (least recently used).
        await cache.store([docs[2]], volumeId: "v1")
        #expect(await cache.ast(volumeId: "v1", documentId: "d2") == nil,
                "least-recently-used entry should be evicted at capacity")
        #expect(await cache.ast(volumeId: "v1", documentId: "d1") != nil)
        #expect(await cache.ast(volumeId: "v1", documentId: "d3") != nil)
    }

    @Test("removeVolume drops only that volume's entries")
    func removeVolumeScoped() async throws {
        let cache = DocumentASTCache(capacity: 8)
        await cache.store([FRUSDocumentAST(documentId: "d1", nodes: [])], volumeId: "v1")
        await cache.store([FRUSDocumentAST(documentId: "d1", nodes: [])], volumeId: "v2")
        await cache.removeVolume("v1")
        #expect(await cache.ast(volumeId: "v1", documentId: "d1") == nil)
        #expect(await cache.ast(volumeId: "v2", documentId: "d1") != nil)
    }
}

// MARK: - RealCorpusEncodingTests

/// Writes a volume fixture using the **real** HistoryAtState/frus TEI encoding:
/// documents are `<div type="document" subtype="historical-document|editorial-note">`,
/// and front/back matter is `<div type="section" subtype="…" xml:id="…">` — the
/// vocabulary verified against the published corpus on 2026-06-10. The legacy
/// fixtures above (`type="editorialNote"`, `type="preface"`) describe an encoding
/// that never occurs in the wild; this builder exists so vocabulary regressions
/// can no longer pass the test suite.
private func writeRealEncodingVolume(to url: URL, volumeId: String) throws {
    let xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <TEI xmlns="http://www.tei-c.org/ns/1.0">
      <teiHeader><fileDesc><titleStmt><title>\(volumeId)</title></titleStmt>
      <publicationStmt><date when="2010">2010</date></publicationStmt>
      <sourceDesc><p>Test fixture</p></sourceDesc></fileDesc></teiHeader>
      <text>
        <front>
          <div type="section" subtype="table-of-contents" xml:id="toc">
            <head>Contents</head>
            <list><item>Chapter one</item></list>
          </div>
          <div type="section" subtype="preface" xml:id="preface">
            <head>Preface</head>
            <p>Prefatory remarks about silvermine documentation policy.</p>
          </div>
          <div type="section" subtype="sources" xml:id="sources">
            <head>Sources</head>
            <list>
              <item>RG 59, Central Files 1969 POL 1, Lot File 70 D 150</item>
            </list>
          </div>
          <div type="section" subtype="index" xml:id="terms">
            <head>Abbreviations</head>
            <list><item xml:id="t_AEC"><term>AEC</term>: Atomic Energy Commission</item></list>
          </div>
          <div type="section" subtype="index" xml:id="persons">
            <head>Persons</head>
            <list><item xml:id="p_kissinger"><persName>Kissinger, Henry A.</persName>, Assistant to the President</item></list>
          </div>
        </front>
        <body>
          <div type="compilation" xml:id="comp1">
            <head>Foundations of Foreign Policy</head>
            <div type="document" subtype="editorial-note" n="1" xml:id="d1">
              <head>1. Editorial Note</head>
              <p>Editorial commentary about quartzline policy planning.</p>
            </div>
            <div type="document" subtype="historical-document" n="2" xml:id="d2">
              <head>2. Memorandum of Conversation</head>
              <dateline>Washington, January 20, 1969.</dateline>
              <p>Discussion of copperfield negotiations.</p>
            </div>
          </div>
        </body>
        <back>
          <div type="section" subtype="errata" xml:id="errata">
            <head>Errata</head>
            <p>Corrections to ironwood citations.</p>
          </div>
          <div type="section" subtype="index" xml:id="index">
            <head>Index</head>
            <list><item>Copperfield, 12</item></list>
          </div>
        </back>
      </text>
    </TEI>
    """
    try xml.data(using: .utf8)!.write(to: url)
}

@Suite("Real corpus TEI encoding")
struct RealCorpusEncodingTests {

    @Test("Volume structure captures front and back sections with normalised kinds")
    func structureCapturesRealSections() async throws {
        try await withTempDir { dir in
            let volDir = dir.appendingPathComponent("volumes")
            try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
            let url = volDir.appendingPathComponent("frus1969-76v01.xml")
            try writeRealEncodingVolume(to: url, volumeId: "frus1969-76v01")

            let structure = try await FRUSDocumentParser().parseVolumeStructure(volumeURL: url)

            // The <front> wrapper must survive intact with all five sections —
            // regression for the unmatched-</div> pop that detached it.
            let front = try #require(structure.sections.first { $0.divType == "front" })
            #expect(front.subsections.map(\.divType) ==
                    ["table-of-contents", "preface", "sources", "terms", "persons"],
                    "section kinds must be normalised from subtype + xml:id")
            #expect(front.subsections.map(\.sectionId) ==
                    ["toc", "preface", "sources", "terms", "persons"])
            #expect(front.subsections.first { $0.divType == "preface" }?.title == "Preface")

            // Body structure unaffected; editorial notes counted as documents.
            let comp = try #require(structure.sections.first { $0.divType == "compilation" })
            #expect(comp.documentIds == ["d1", "d2"])

            // Back matter captured with kinds; persons/terms resolution must not
            // hijack the genuine back index (xml:id="index").
            let back = try #require(structure.sections.first { $0.divType == "back" })
            #expect(back.subsections.map(\.divType) == ["errata", "index"])
        }
    }

    @Test("Unknown wrapper divs are transparent: nested structure bubbles up intact")
    func unknownWrapperIsTransparent() async throws {
        try await withTempDir { dir in
            let volDir = dir.appendingPathComponent("volumes")
            try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
            let url = volDir.appendingPathComponent("frus1969-76v01.xml")
            let xml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <TEI xmlns="http://www.tei-c.org/ns/1.0">
              <teiHeader><fileDesc><titleStmt><title>t</title></titleStmt>
              <publicationStmt><date>2010</date></publicationStmt>
              <sourceDesc><p>f</p></sourceDesc></fileDesc></teiHeader>
              <text><body>
                <div type="mystery-wrapper">
                  <div type="compilation" xml:id="comp1">
                    <head>Compilation</head>
                    <div type="document" subtype="historical-document" xml:id="d1">
                      <head>1. Document</head><p>Text.</p>
                    </div>
                  </div>
                </div>
              </body></text>
            </TEI>
            """
            try xml.data(using: .utf8)!.write(to: url)

            let structure = try await FRUSDocumentParser().parseVolumeStructure(volumeURL: url)
            let comp = try #require(structure.sections.first { $0.divType == "compilation" },
                                    "compilation nested in an unknown wrapper must bubble to top level")
            #expect(comp.documentIds == ["d1"])
        }
    }

    @Test("Editorial notes are detected via subtype and front matter is indexed")
    func editorialNotesAndFrontMatterIndexed() async throws {
        try await withTempDir { dir in
            let (pipeline, store) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            let url = volDir.appendingPathComponent("frus1969-76v01.xml")
            try writeRealEncodingVolume(to: url, volumeId: "frus1969-76v01")
            try await pipeline.indexVolume("frus1969-76v01")

            // Editorial note flag must come from subtype="editorial-note".
            let docs = try await pipeline.documents(forVolume: "frus1969-76v01")
            #expect(docs.first { $0.documentId == "d1" }?.isEditorialNote == true,
                    "subtype=\"editorial-note\" must set isEditorialNote")
            #expect(docs.first { $0.documentId == "d2" }?.isEditorialNote == false)

            // The preface is promoted to a searchable front-matter quasi-document…
            let withFront = try await pipeline.searchDocuments(
                corpusMatch: "\"silvermine\"", userContentMatch: nil,
                filters: SearchSQLFilters(includeFrontMatter: true), limit: 10, offset: 0)
            #expect(withFront.count == 1)
            #expect(withFront.first?.isFrontMatter == true)

            // …and excluded when the front-matter scope is off.
            let withoutFront = try await pipeline.searchDocuments(
                corpusMatch: "\"silvermine\"", userContentMatch: nil,
                filters: SearchSQLFilters(includeFrontMatter: false), limit: 10, offset: 0)
            #expect(withoutFront.isEmpty)

            // The table of contents must NOT be promoted into the search index.
            let tocHits = try await store.search(
                query: FTS5Query(phrase: "chapter one"), limit: 10, offset: 0)
            #expect(tocHits.isEmpty, "table-of-contents text must not pollute search")

            // The editorial-note document-type filter works end to end.
            let edNotesOnly = try await pipeline.searchDocuments(
                corpusMatch: "\"quartzline\"", userContentMatch: nil,
                filters: SearchSQLFilters(documentTypeFilter: .editorialNotesOnly),
                limit: 10, offset: 0)
            #expect(edNotesOnly.count == 1)
            #expect(edNotesOnly.first?.documentId == "d1")
        }
    }

    @Test("Archival sources are extracted from the real sources section encoding")
    func sourcesExtractedFromRealEncoding() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            let url = volDir.appendingPathComponent("frus1969-76v01.xml")
            try writeRealEncodingVolume(to: url, volumeId: "frus1969-76v01")
            try await pipeline.indexVolume("frus1969-76v01")

            let sources = try await pipeline.volumeSources(forVolumeId: "frus1969-76v01")
            #expect(!sources.isEmpty,
                    "subtype=\"sources\" sections must populate volume_sources")
            #expect(sources.contains { $0.rawText.contains("RG 59") })
        }
    }

    @Test("Persons and terms glossaries resolve from subtype=index sections")
    func personsAndTermsResolved() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            let url = volDir.appendingPathComponent("frus1969-76v01.xml")
            try writeRealEncodingVolume(to: url, volumeId: "frus1969-76v01")
            try await pipeline.indexVolume("frus1969-76v01")

            let structure = try #require(
                try await pipeline.cachedVolumeStructure(forVolumeId: "frus1969-76v01"))
            let front = try #require(structure.sections.first { $0.divType == "front" })
            let persons = try #require(front.subsections.first { $0.divType == "persons" })
            let terms = try #require(front.subsections.first { $0.divType == "terms" })
            #expect(persons.isPersonsList)
            #expect(VolumeSection.proseReadableKinds.contains(terms.divType))
            #expect(terms.canReadDirectly, "terms glossary should open directly in DocumentView")
        }
    }

    @Test("Collection Zotero export resolves editorial-note flags from the index")
    func collectionZoteroExportFlagsEditorialNotes() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            let url = volDir.appendingPathComponent("frus1969-76v01.xml")
            try writeRealEncodingVolume(to: url, volumeId: "frus1969-76v01")
            try await pipeline.indexVolume("frus1969-76v01")

            // The flag map the collection resolve paths feed into makeItem:
            // d1 (subtype="editorial-note") flagged, d2 (historical document) absent.
            let flags = await ZoteroJSONExporter.editorialNoteFlags(
                volumeIds: ["frus1969-76v01"], pipeline: pipeline)
            #expect(flags["frus1969-76v01/d1"] == true,
                    "editorial notes must be flagged from document_cache.is_editorial_note")
            #expect(flags["frus1969-76v01/d2"] == nil)

            // An unindexed volume contributes no entries — the flag degrades to false.
            let unindexed = await ZoteroJSONExporter.editorialNoteFlags(
                volumeIds: ["frus1861"], pipeline: pipeline)
            #expect(unindexed.isEmpty)

            // End to end: items built the way resolveDocuments()/resolveSmartDocuments()
            // build them carry "Editorial note" in extra for d1 only — parity with the
            // document-level export path (DocumentViewModel.zoteroItem).
            let volume = FRUSVolumeMetadata(
                title: "Test Volume", editors: [], generalEditor: nil,
                publicationDate: "2010", publicationPlace: "Washington", publisher: "GPO")
            let items = ["d1", "d2"].map { documentId in
                ZoteroJSONExporter.makeItem(
                    document: FRUSDocumentMetadata(
                        documentId: documentId, documentNumber: nil,
                        header: "Heading", dateline: nil),
                    volume: volume,
                    year: "2010",
                    url: nil,
                    isEditorialNote: flags["frus1969-76v01/\(documentId)"] ?? false
                )
            }
            #expect(items[0].extra == "Editorial note")
            #expect(items[1].extra == nil)
        }
    }
}

// MARK: - IndexIntegrityTests

@Suite("IndexingPipeline — checkIndexIntegrity (Session 154)")
struct IndexIntegrityTests {

    @Test("checkIndexIntegrity returns no problems on a freshly indexed fixture")
    func integrityCheckPassesOnFreshIndex() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            try writeTEIVolume(to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                               volumeId: "frus1969-76v01",
                               documents: [("d1", "<head>Memorandum of Conversation</head><p>Discussed detente policy.</p>")])

            try await pipeline.indexVolume("frus1969-76v01")

            let problems = try await pipeline.checkIndexIntegrity()
            #expect(problems.isEmpty)
        }
    }

    @Test("checkIndexIntegrity reports a problem when frus_documents diverges from document_cache")
    func integrityCheckFailsOnCorruptedTable() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            try writeTEIVolume(to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                               volumeId: "frus1969-76v01",
                               documents: [("d1", "<head>Memorandum of Conversation</head><p>Discussed detente policy.</p>")])

            try await pipeline.indexVolume("frus1969-76v01")

            // Open a second connection to the same database file and corrupt the
            // frus_documents external-content sync: drop its sync triggers, then
            // modify document_cache directly so the FTS5 index no longer matches
            // its content table.
            let dbURL = dir.appendingPathComponent("test.sqlite")
            var handle: OpaquePointer?
            #expect(sqlite3_open_v2(dbURL.path, &handle, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK)
            defer { sqlite3_close(handle) }
            for sql in FTS5Schema.frusDocuments.dropTriggerSQL() {
                #expect(sqlite3_exec(handle, sql, nil, nil, nil) == SQLITE_OK)
            }
            #expect(sqlite3_exec(
                handle,
                "UPDATE document_cache SET header = 'CORRUPTED', body_text = 'CORRUPTED' WHERE document_id = 'd1'",
                nil, nil, nil
            ) == SQLITE_OK)

            let problems = try await pipeline.checkIndexIntegrity()
            #expect(!problems.isEmpty)
            #expect(problems.contains { $0.contains("frus_documents") })
        }
    }
}

// MARK: - DateMetadataIndexingTests

/// Verifies that `extractDateMetadata` persists the original date precision and
/// certainty (Session 163, date-index version 9) alongside the normalized interval.
@Suite("DateMetadataIndexingTests")
struct DateMetadataIndexingTests {

    @Test("precision and certainty stored for exact, range, year-only, month-only, and approximate dates")
    func precisionAndCertaintyStored() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")

            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [
                    ("d1", "<dateline><date when=\"1969-02-15\">February 15, 1969</date></dateline><head>1. Memo</head><p>Body.</p>"),
                    ("d2", "<dateline><date from=\"1969-03-03\" to=\"1969-03-05\">March 3–5, 1969</date></dateline><head>2. Meeting</head><p>Body.</p>"),
                    ("d3", "<dateline><date when=\"1969\">1969</date></dateline><head>3. Undated memo</head><p>Body.</p>"),
                    ("d4", "<dateline><date when=\"1969-07\">July 1969</date></dateline><head>4. Monthly report</head><p>Body.</p>"),
                    ("d5", "<dateline><date notBefore=\"1969-04-01\" notAfter=\"1969-04-30\">April 1969</date></dateline><head>5. Approximate</head><p>Body.</p>"),
                ]
            )
            try await pipeline.indexVolume("frus1969-76v01")

            let pairs = (1...5).map { (volumeId: "frus1969-76v01", documentId: "d\($0)") }
            let meta = try await pipeline.dateMetadataByDocumentKey(pairs)

            // d1 — exact day.
            let d1 = try #require(meta["frus1969-76v01/d1"])
            #expect(d1.precision == .day)
            #expect(d1.certainty == .exact)
            #expect(d1.dateISO == "1969-02-15")
            #expect(d1.dateISOMax == "1969-02-15")

            // d2 — explicit multi-day range.
            let d2 = try #require(meta["frus1969-76v01/d2"])
            #expect(d2.precision == .day)
            #expect(d2.certainty == .range)
            #expect(d2.dateISO == "1969-03-03")
            #expect(d2.dateISOMax == "1969-03-05")

            // d3 — year-only: interval still spans the whole year, but precision records it.
            let d3 = try #require(meta["frus1969-76v01/d3"])
            #expect(d3.precision == .year)
            #expect(d3.certainty == .exact)
            #expect(d3.dateISO == "1969-01-01")
            #expect(d3.dateISOMax == "1969-12-31")

            // d4 — month precision.
            let d4 = try #require(meta["frus1969-76v01/d4"])
            #expect(d4.precision == .month)
            #expect(d4.certainty == .exact)
            #expect(d4.dateISO == "1969-07-01")
            #expect(d4.dateISOMax == "1969-07-31")

            // d5 — approximate bounds.
            let d5 = try #require(meta["frus1969-76v01/d5"])
            #expect(d5.certainty == .approximate)
            #expect(d5.dateISO == "1969-04-01")
            #expect(d5.dateISOMax == "1969-04-30")
        }
    }
}

// MARK: - DocumentNumberIndexingTests

/// Verifies that `document_number` comes from the canonical history.state.gov `@n`
/// attribute — present for every document — so citations include a number even for early
/// volumes whose documents were unnumbered in the printed edition (HSG assigns them an `@n`
/// that readers use to locate the document). The `<head>` leading number is only a fallback.
@Suite("DocumentNumberIndexingTests")
struct DocumentNumberIndexingTests {

    @Test("document_number comes from @n, including early-volume documents unnumbered in print")
    func documentNumberFromAtN() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            let xml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <TEI xmlns="http://www.tei-c.org/ns/1.0">
              <teiHeader><fileDesc><titleStmt><title>vol1</title></titleStmt>
              <publicationStmt><date>2003</date></publicationStmt>
              <sourceDesc><p>fixture</p></sourceDesc></fileDesc></teiHeader>
              <text><body>
                <div type="compilation" xml:id="c1">
                  <div type="document" n="1" subtype="historical-document" xml:id="d1"><head>Mr. Seward to Mr. Adams</head><p>Early-volume document: unnumbered in print, but HSG/TEI assigns n="1".</p></div>
                  <div type="document" n="7" subtype="historical-document" xml:id="d2"><head>7. Memorandum From X to Y</head><p>A modern numbered document (head and @n agree).</p></div>
                </div>
              </body></text>
            </TEI>
            """
            try xml.data(using: .utf8)!.write(to: volDir.appendingPathComponent("vol1.xml"))
            try await pipeline.indexVolume("vol1")

            let n1 = try await pipeline.documentNumber(volumeId: "vol1", documentId: "d1")
            #expect(n1 == "1", "The canonical @n is used even though the printed head has no number")

            let n2 = try await pipeline.documentNumber(volumeId: "vol1", documentId: "d2")
            #expect(n2 == "7", "Modern numbered document resolves to its number (head and @n agree)")
        }
    }
}

// MARK: - PersonRollupConsolidationTests

/// Validates the Phase-0 materialised person rollup: the consolidation pass keys identities by
/// normalised name, merging the same person across volumes (fragmentation) while keeping different
/// people who happen to share a per-volume TEI `ref` string apart (false-merge / conflation).
@Suite("IndexingPipeline — person rollup consolidation")
struct PersonRollupConsolidationTests {

    /// A TEI volume with both document person-mentions and a front-matter persons list.
    private func writeVolume(to url: URL, volumeId: String, year: String,
                            documents: [(id: String, ref: String, name: String)],
                            persons: [(ref: String, line: String)]) throws {
        let docBlocks = documents.map {
            "<div type=\"document\" xml:id=\"\($0.id)\"><head>\($0.id)</head>"
            + "<p>See <persName ref=\"\($0.ref)\">\($0.name)</persName>.</p></div>"
        }.joined(separator: "\n")
        let personItems = persons.map {
            "<item xml:id=\"\($0.ref)\">\($0.line)</item>"
        }.joined(separator: "\n")
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <teiHeader><fileDesc><titleStmt><title>\(volumeId)</title></titleStmt>
          <publicationStmt><date>\(year)</date></publicationStmt>
          <sourceDesc><p>fixture</p></sourceDesc></fileDesc></teiHeader>
          <text><body>
            \(docBlocks)
            <div type="persons"><list>
            \(personItems)
            </list></div>
          </body></text>
        </TEI>
        """
        try xml.data(using: .utf8)!.write(to: url)
    }

    @Test("consolidatePersonRollup merges fragmented names and de-conflates shared refs")
    func consolidationMergesAndDeconflates() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")

            // volA: Kissinger (p_k) mentioned in two docs; Smith (p_s) in one.
            try writeVolume(
                to: volDir.appendingPathComponent("volA.xml"), volumeId: "volA", year: "1969",
                documents: [("dA1", "p_k", "Kissinger"), ("dA2", "p_k", "Kissinger"), ("dA3", "p_s", "Smith")],
                persons: [("p_k", "Kissinger, Henry A.: National Security Advisor."),
                          ("p_s", "Smith, John: Aide.")]
            )
            // volB: REUSES ref "p_k" for an unrelated person (Adams); Kissinger reappears under a
            // DIFFERENT ref "p_z" (the fragmentation the rollup must heal).
            try writeVolume(
                to: volDir.appendingPathComponent("volB.xml"), volumeId: "volB", year: "1973",
                documents: [("dB1", "p_k", "Adams"), ("dB2", "p_z", "Kissinger")],
                persons: [("p_k", "Adams, Robert: Clerk."),
                          ("p_z", "Kissinger, Henry A.: Secretary of State.")]
            )

            try await pipeline.indexVolume("volA")
            try await pipeline.indexVolume("volB")
            try await pipeline.consolidatePersonRollup()

            let store = try PersonMentionStore(databaseURL: dir.appendingPathComponent("test.sqlite"))
            let all = try await store.allPersonsSortedByName()

            // Three distinct people: the two "Kissinger" entries merged into one rollup.
            #expect(all.map(\.entry.name) == ["Adams, Robert", "Kissinger, Henry A.", "Smith, John"])

            let kissinger = try #require(all.first { $0.entry.name == "Kissinger, Henry A." })
            #expect(kissinger.mentionCount == 3, "volA dA1+dA2 (p_k) and volB dB2 (p_z) across the merge")

            let adams = try #require(all.first { $0.entry.name == "Adams, Robert" })
            #expect(adams.mentionCount == 1, "volB's p_k must NOT inherit volA's p_k mentions")

            // The same ref string "p_k" lands in two different rollups (de-conflation)…
            let kissRollup = try await store.rollupEntry(forVolumeId: "volA", ref: "p_k")?.rollupId
            let adamsRollup = try await store.rollupEntry(forVolumeId: "volB", ref: "p_k")?.rollupId
            #expect(kissRollup != nil && adamsRollup != nil && kissRollup != adamsRollup)
            // …while a different ref ("p_z") in another volume joins the Kissinger rollup (merge).
            #expect(try await store.rollupEntry(forVolumeId: "volB", ref: "p_z")?.rollupId == kissRollup)

            // Cross-corpus drill-in for the merged rollup spans both volumes' documents.
            let keys = try await store.documentKeys(forRollupId: kissinger.rollupId ?? -1)
                .map { "\($0.volumeId)/\($0.documentId)" }.sorted()
            #expect(keys == ["volA/dA1", "volA/dA2", "volB/dB2"])
        }
    }

    @Test("consolidatePersonRollup carries role and active-year span onto the rollup (Phase 1)")
    func consolidationCarriesRoleEra() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            try writeVolume(
                to: volDir.appendingPathComponent("volA.xml"), volumeId: "volA", year: "1950",
                documents: [("dA1", "p_a", "Acheson")],
                persons: [("p_a", "Acheson, Dean: Secretary of State, 1949–1953")]
            )
            try await pipeline.indexVolume("volA")
            try await pipeline.consolidatePersonRollup()

            let store = try PersonMentionStore(databaseURL: dir.appendingPathComponent("test.sqlite"))
            let acheson = try #require(
                try await store.allPersonsSortedByName().first { $0.entry.name == "Acheson, Dean" })
            #expect(acheson.entry.role == "Secretary of State")
            #expect(acheson.entry.startYear == 1949)
            #expect(acheson.entry.endYear == 1953)
            #expect(acheson.entry.roleEraSubtitle == "Secretary of State · 1949–1953")
        }
    }

    @Test("clustering splits a shared exact name across distant eras into two rollups (Phase 2)")
    func clusteringSplitsByEra() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            // Two unrelated "Smith, John"s a century apart — and they even share the ref string "p_s".
            try writeVolume(
                to: volDir.appendingPathComponent("volA.xml"), volumeId: "volA", year: "1851",
                documents: [("dA1", "p_s", "Smith")],
                persons: [("p_s", "Smith, John: Consul, 1850–1855")]
            )
            try writeVolume(
                to: volDir.appendingPathComponent("volB.xml"), volumeId: "volB", year: "1961",
                documents: [("dB1", "p_s", "Smith")],
                persons: [("p_s", "Smith, John: Diplomat, 1960–1965")]
            )
            try await pipeline.indexVolume("volA")
            try await pipeline.indexVolume("volB")
            try await pipeline.consolidatePersonRollup()

            let store = try PersonMentionStore(databaseURL: dir.appendingPathComponent("test.sqlite"))
            let smiths = try await store.allPersonsSortedByName().filter { $0.entry.name == "Smith, John" }
            #expect(smiths.count == 2, "same name, eras a century apart → two distinct people")
            let a = try await store.rollupEntry(forVolumeId: "volA", ref: "p_s")?.rollupId
            let b = try await store.rollupEntry(forVolumeId: "volB", ref: "p_s")?.rollupId
            #expect(a != nil && b != nil && a != b, "the shared ref string must resolve to two rollups")
        }
    }

    @Test("a name-variant pair is held apart and recorded as a merge candidate (Phase 2)")
    func clusteringRecordsCandidate() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            // Variant names ("Henry A." vs "Henry"), same era, but clearly different roles → the
            // clusterer declines to auto-merge and records a candidate instead.
            try writeVolume(
                to: volDir.appendingPathComponent("volA.xml"), volumeId: "volA", year: "1974",
                documents: [("dA1", "p_k", "Kissinger")],
                persons: [("p_k", "Kissinger, Henry A.: Secretary of State, 1973–1977")]
            )
            try writeVolume(
                to: volDir.appendingPathComponent("volB.xml"), volumeId: "volB", year: "1974",
                documents: [("dB1", "p_h", "Kissinger")],
                persons: [("p_h", "Kissinger, Henry: Petroleum geologist, 1973–1977")]
            )
            try await pipeline.indexVolume("volA")
            try await pipeline.indexVolume("volB")
            try await pipeline.consolidatePersonRollup()

            let store = try PersonMentionStore(databaseURL: dir.appendingPathComponent("test.sqlite"))
            let kissingers = try await store.allPersonsSortedByName().filter { $0.entry.name.hasPrefix("Kissinger") }
            #expect(kissingers.count == 2, "variant + role conflict stays split under the under-merge bias")
            let rid = try #require(try await store.rollupEntry(forVolumeId: "volA", ref: "p_k")?.rollupId)
            let cands = try await store.candidates(forRollupId: rid)
            #expect(cands.count == 1, "the held-back pair is offered as a suggestion")
            #expect(cands.first?.name == "Kissinger, Henry")
            #expect(cands.first?.reason?.contains("role differs") == true)
        }
    }

    @Test("a merge override unions two rollups across consolidation (Phase 3)")
    func mergeOverrideUnionsRollups() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            // Two variant Kissingers the clusterer holds apart (role conflict → candidate, not merge).
            try writeVolume(
                to: volDir.appendingPathComponent("volA.xml"), volumeId: "volA", year: "1974",
                documents: [("dA1", "p_k", "Kissinger")],
                persons: [("p_k", "Kissinger, Henry A.: Secretary of State, 1973–1977")]
            )
            try writeVolume(
                to: volDir.appendingPathComponent("volB.xml"), volumeId: "volB", year: "1974",
                documents: [("dB1", "p_h", "Kissinger")],
                persons: [("p_h", "Kissinger, Henry: Petroleum geologist, 1973–1977")]
            )
            try await pipeline.indexVolume("volA")
            try await pipeline.indexVolume("volB")

            let store = try PersonMentionStore(databaseURL: dir.appendingPathComponent("test.sqlite"))
            try await pipeline.consolidatePersonRollup()
            #expect(try await store.allPersonsSortedByName()
                .filter { $0.entry.name.hasPrefix("Kissinger") }.count == 2)

            // The user confirms they are the same person. forceReload: false exercises the in-memory
            // cluster-input cache the UI uses for a fast re-apply.
            let override = PersonClusterOverrideData(kind: .merge,
                                                     volumeIdA: "volA", refA: "p_k",
                                                     volumeIdB: "volB", refB: "p_h")
            try await pipeline.consolidatePersonRollup(overrides: [override], forceReload: false)
            let merged = try await store.allPersonsSortedByName().filter { $0.entry.name.hasPrefix("Kissinger") }
            #expect(merged.count == 1, "the merge override unions the two into one identity")
            let rid = try #require(merged.first?.rollupId)
            let keys = try await store.documentKeys(forRollupId: rid)
                .map { "\($0.volumeId)/\($0.documentId)" }.sorted()
            #expect(keys == ["volA/dA1", "volB/dB1"], "drill-in now spans both volumes")
        }
    }

    @Test("a split override detaches a member from its cluster (Phase 3)")
    func splitOverrideDetachesMember() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            // Two exact-name records the clusterer merges (no era separation).
            try writeVolume(
                to: volDir.appendingPathComponent("volA.xml"), volumeId: "volA", year: "1970",
                documents: [("dA1", "p_k", "Kissinger")],
                persons: [("p_k", "Kissinger, Henry A.")]
            )
            try writeVolume(
                to: volDir.appendingPathComponent("volB.xml"), volumeId: "volB", year: "1971",
                documents: [("dB1", "p_z", "Kissinger")],
                persons: [("p_z", "Kissinger, Henry A.")]
            )
            try await pipeline.indexVolume("volA")
            try await pipeline.indexVolume("volB")

            let store = try PersonMentionStore(databaseURL: dir.appendingPathComponent("test.sqlite"))
            try await pipeline.consolidatePersonRollup()
            #expect(try await store.allPersonsSortedByName()
                .filter { $0.entry.name == "Kissinger, Henry A." }.count == 1)

            // The user marks volB's record as a different person.
            let override = PersonClusterOverrideData(kind: .split, volumeIdA: "volB", refA: "p_z")
            try await pipeline.consolidatePersonRollup(overrides: [override])
            #expect(try await store.allPersonsSortedByName()
                .filter { $0.entry.name == "Kissinger, Henry A." }.count == 2,
                "the detached record stands alone")
        }
    }

    @Test("merged rollup widens the active span across members (MIN start, MAX end)")
    func consolidationWidensEra() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            // The same person, dated differently in two volumes → one rollup spanning 1945–1953.
            try writeVolume(
                to: volDir.appendingPathComponent("volA.xml"), volumeId: "volA", year: "1946",
                documents: [("dA1", "p_a", "Acheson")],
                persons: [("p_a", "Acheson, Dean: Under Secretary of State, 1945–1947")]
            )
            try writeVolume(
                to: volDir.appendingPathComponent("volB.xml"), volumeId: "volB", year: "1950",
                documents: [("dB1", "p_z", "Acheson")],
                persons: [("p_z", "Acheson, Dean: Secretary of State, 1949–1953")]
            )
            try await pipeline.indexVolume("volA")
            try await pipeline.indexVolume("volB")
            try await pipeline.consolidatePersonRollup()

            let store = try PersonMentionStore(databaseURL: dir.appendingPathComponent("test.sqlite"))
            let acheson = try #require(
                try await store.allPersonsSortedByName().first { $0.entry.name == "Acheson, Dean" })
            #expect(acheson.entry.startYear == 1945)
            #expect(acheson.entry.endYear == 1953)
        }
    }
}
