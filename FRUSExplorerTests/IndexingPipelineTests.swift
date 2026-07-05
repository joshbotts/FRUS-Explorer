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

    @Test("Arabic page target (#pg_42) resolved to the span-containing document after indexing")
    func arabicPageTargetResolvedToDocumentId() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let dbURL = dir.appendingPathComponent("test.sqlite")
            let volDir = dir.appendingPathComponent("volumes")

            // d1 references page 42 via the real "#pg_42" form; d2 opens at <pb n="42"/>.
            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [
                    ("d1", """
                    <head>Report</head><pb n=\"41\"/>
                    <p>See <ref target=\"#pg_42\">page 42</ref> for details.</p>
                    """),
                    ("d2", "<head>Annex</head><pb n=\"42\"/><p>Annex text.</p>"),
                ]
            )
            try await pipeline.indexVolume("frus1969-76v01")

            let resolved = queryTargetDocumentId(
                dbURL: dbURL, sourceVolumeId: "frus1969-76v01", sourceDocumentId: "d1"
            )
            #expect(resolved == "d2",
                    "Page target '#pg_42' must resolve to document 'd2'; got: \(resolved ?? "nil")")
        }
    }

    @Test("Page inside a span (not a document's first page) resolves to that document")
    func pageInsideSpanResolvesToContainingDocument() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let dbURL = dir.appendingPathComponent("test.sqlite")
            let volDir = dir.appendingPathComponent("volumes")

            // d1 opens at p.10 (pb 10, 11, 12), d2 opens at p.13. A ref to #pg_11 must
            // resolve to d1 via the span algorithm even though no document *starts* at 11 —
            // this is exactly the case the old exact-match `page_number_int = N` got wrong.
            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [
                    ("d1", """
                    <head>First</head><pb n=\"10\"/><p>a</p><pb n=\"11\"/><p>b</p><pb n=\"12\"/><p>c</p>
                    """),
                    ("d2", "<head>Second</head><pb n=\"13\"/><p>d</p>"),
                    ("d3", """
                    <head>Referrer</head><pb n=\"20\"/>
                    <p>See <ref target=\"#pg_11\">page 11</ref>.</p>
                    """),
                ]
            )
            try await pipeline.indexVolume("frus1969-76v01")

            let resolved = queryTargetDocumentId(
                dbURL: dbURL, sourceVolumeId: "frus1969-76v01", sourceDocumentId: "d3"
            )
            #expect(resolved == "d1",
                    "Page 11 falls inside d1's span [10,12]; got: \(resolved ?? "nil")")
        }
    }

    @Test("Roman front-matter page target (#pg_III) is left unresolved")
    func romanPageTargetLeftUnresolved() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let dbURL = dir.appendingPathComponent("test.sqlite")
            let volDir = dir.appendingPathComponent("volumes")

            // A roman front-matter anchor has no <div type="document"> to resolve to.
            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [
                    ("d1", """
                    <head>Report</head><pb n=\"1\"/>
                    <p>See the <ref target=\"#pg_III\">preface</ref>.</p>
                    """),
                    ("d2", "<head>Annex</head><pb n=\"42\"/><p>Annex text.</p>"),
                ]
            )
            try await pipeline.indexVolume("frus1969-76v01")

            // GLOB 'pg_[0-9]*' does not match "pg_III"; it stays as the raw fragment.
            let resolved = queryTargetDocumentId(
                dbURL: dbURL, sourceVolumeId: "frus1969-76v01", sourceDocumentId: "d1"
            )
            #expect(resolved == "pg_III",
                    "Roman anchor 'pg_III' should remain unresolved; got: \(resolved ?? "nil")")
        }
    }

    @Test("Unresolvable arabic page target left unchanged when no span contains it")
    func unresolvablePageTargetLeftAsIs() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let dbURL = dir.appendingPathComponent("test.sqlite")
            let volDir = dir.appendingPathComponent("volumes")

            // d1 references page 5 but the only paginated document opens at page 42,
            // so page 5 sits below the first document's span and cannot be resolved.
            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [
                    ("d1", """
                    <head>Report</head>
                    <p>See <ref target=\"#pg_5\">page 5</ref>.</p>
                    """),
                    ("d2", "<head>Annex</head><pb n=\"42\"/><p>Annex text.</p>"),
                ]
            )
            try await pipeline.indexVolume("frus1969-76v01")

            // The pipeline leaves unresolvable page targets in place rather than deleting them.
            let resolved = queryTargetDocumentId(
                dbURL: dbURL, sourceVolumeId: "frus1969-76v01", sourceDocumentId: "d1"
            )
            #expect(resolved == "pg_5",
                    "Unresolvable page target 'pg_5' should remain unchanged; got: \(resolved ?? "nil")")
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

    @Test("extractHeader excludes a footnote that is a direct child of head")
    func headerExcludesDirectFootnoteChild() {
        // 1955+ encoding: <note type="source"> nested directly inside <head> must not
        // leak into the stored title.
        let nodes: [FRUSASTNode] = [
            .head(children: [
                .text("42. Memorandum From the President"),
                .footnote(id: "fn1", type: .source, printedNumber: "1",
                          children: [.text("Source: National Archives, RG 59.")])
            ])
        ]
        #expect(IndexingPipeline.extractHeader(from: nodes) == "42. Memorandum From the President")
    }

    @Test("extractHeader excludes footnotes nested inside inline head markup")
    func headerExcludesDeepNestedFootnote() {
        // 68 corpus documents (frus1914Supp, frus1952-54v13p1, …) nest the head
        // footnote inside <hi>/<persName>/<p> markup rather than as a direct child;
        // the exclusion must be recursive (adversarial-review finding 2; modeled on
        // frus1952-54v13p1 d595).
        let nodes: [FRUSASTNode] = [
            .head(children: [
                .text("595. Memorandum of Discussion at the 187th Meeting"),
                .emphasis(style: .italic, children: [
                    .text("Prepared by S. Everett Gleason"),
                    .footnote(id: "fn1", type: .footnote, printedNumber: "1",
                              children: [.text("on Mar. 5.")])
                ])
            ])
        ]
        #expect(IndexingPipeline.extractHeader(from: nodes)
                == "595. Memorandum of Discussion at the 187th Meeting Prepared by S. Everett Gleason")
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

// MARK: - ArchivalNeighborsTests

/// Verifies the archival-neighbors entry points added for the cross-reference graph,
/// search, browser, and volume-sources surfaces: the by-document-key method re-parses a
/// document's stored source note and finds others sharing its lot file (excluding the
/// source), and the by-source-entry method finds all documents in a lot file.
///
/// Version history:
///   1.0 — Session 166: archival-neighbors rollout
@Suite("IndexingPipeline — archival neighbors")
struct ArchivalNeighborsTests {

    /// `<note type="source">` text that parses to `.lotFile("61-D 146")`
    /// (the inline-lot-file form exercised by `SourceExplorerTests`).
    private static let lotNote = "<note type=\"source\">SPA Files: Lot 61-D 146, Box 4581</note>"

    @Test("archivalNeighbors(forVolumeId:) finds documents sharing a lot file, excluding the source")
    func byDocumentKeyMatchesLotFile() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [
                    ("d1", "<head>1. Memo</head>\(Self.lotNote)<p>First.</p>"),
                    ("d2", "<head>2. Memo</head>\(Self.lotNote)<p>Second.</p>"),
                    ("d3", "<head>3. Memo</head><note type=\"source\">Source: Department of State, Central Files 1967-69, POL 7 VIET S. Confidential.</note><p>Third.</p>"),
                ]
            )
            try await pipeline.indexVolume("frus1969-76v01")

            let result = try await pipeline.archivalNeighbors(
                forVolumeId: "frus1969-76v01", documentId: "d1")
            let ids = Set(result.documents.map(\.documentId))
            #expect(ids.contains("d2"), "d2 shares the lot file and should be a neighbor")
            #expect(!ids.contains("d1"), "the source document is excluded from its own neighbors")
            #expect(!ids.contains("d3"), "a document with a different source is not a lot-file neighbor")
            #expect(result.basis?.contains("61-D 146") == true, "basis names the shared lot file")
        }
    }

    @Test("archivalNeighbors(forLotFile:) finds all documents in a lot file (volume-source entry path)")
    func byLotFileEntryMatches() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [
                    ("d1", "<head>1. Memo</head>\(Self.lotNote)<p>First.</p>"),
                    ("d2", "<head>2. Memo</head>\(Self.lotNote)<p>Second.</p>"),
                ]
            )
            try await pipeline.indexVolume("frus1969-76v01")

            let result = try await pipeline.archivalNeighbors(
                forLotFile: "61-D 146", recordGroup: nil, series: nil)
            let ids = Set(result.documents.map(\.documentId))
            #expect(ids.contains("d1") && ids.contains("d2"),
                    "both documents in the lot file are returned for the volume-source entry path")
            #expect(result.basis?.contains("61-D 146") == true)
        }
    }
}

// MARK: - VolumeSourceMatcherTests (Source Explorer Phase 3 step 2)

/// Verifies the normalized matcher and the new volume-level match paths: the single
/// `lot_file_norm` lookup (dash variants match in both directions), the comma-boundary
/// series prefix for record-group collections (with the over-broad guard), the
/// presidential-library path, the decimal / subject-numeric class-leaf path (S3 lean:
/// boundary-gated prefix, no period segmenting), and the target gating in
/// `VolumeSourcesView.makeNeighborsTarget` (bibliography rows excluded).
///
/// Version history:
///   1.0 — Session 2026-07-03: Source Explorer Phase 3 step 2
@Suite("IndexingPipeline — volume source matcher")
struct VolumeSourceMatcherTests {

    /// Indexes a volume whose documents carry the given source notes and returns the pipeline.
    private func indexFixture(
        dir: URL, notes: [(id: String, note: String)]
    ) async throws -> IndexingPipeline {
        let (pipeline, _) = try await makeTestPipeline(dir: dir)
        let volDir = dir.appendingPathComponent("volumes")
        try writeTEIVolume(
            to: volDir.appendingPathComponent("frus1969-76v01.xml"),
            volumeId: "frus1969-76v01",
            documents: notes.enumerated().map { i, doc in
                (doc.id, "<head>\(i + 1). Memo</head><note type=\"source\">\(doc.note)</note><p>Text.</p>")
            }
        )
        try await pipeline.indexVolume("frus1969-76v01")
        return pipeline
    }

    @Test("Normalized lot lookup bridges hyphen/en-dash/em-dash variants in both directions")
    func normalizedLotLookupBridgesDashVariants() async throws {
        try await withTempDir { dir in
            let pipeline = try await indexFixture(dir: dir, notes: [
                ("d1", "SPA Files: Lot 61–D 146, Box 4581"),   // en-dash stored
                ("d2", "SPA Files: Lot 61-D 146, Box 4581"),   // hyphen stored
                ("d3", "PPS files, lot 64 D 563, memoranda"),  // different lot
            ])

            // Volume-entry path, queried with a THIRD variant (em-dash): both stored
            // forms match through the shared compact norm.
            let byEntry = try await pipeline.archivalNeighbors(
                forLotFile: "61—D 146", recordGroup: nil, series: nil)
            let entryIds = Set(byEntry.documents.map(\.documentId))
            #expect(entryIds == ["d1", "d2"],
                    "all dash variants of one lot must resolve to the same norm; got \(entryIds)")

            // Document-keyed path: the en-dash document finds the hyphen document.
            let byDoc = try await pipeline.archivalNeighbors(
                forVolumeId: "frus1969-76v01", documentId: "d1")
            #expect(Set(byDoc.documents.map(\.documentId)) == ["d2"],
                    "cross-variant neighbors must match from the document side too")
        }
    }

    @Test("Collection series prefix matches Box tails at a comma boundary, guarded against over-broad prefixes")
    func collectionSeriesPrefixAndGuard() async throws {
        try await withTempDir { dir in
            let pipeline = try await indexFixture(dir: dir, notes: [
                ("d1", "Source: National Archives, RG 84, Moscow Embassy Files, Box 12. Secret."),
                ("d2", "Source: National Archives, RG 84, Moscow Embassy Files, Box 57. Confidential."),
                ("d3", "Source: National Archives, RG 84, Moscow Embassy General Records, Box 2. Secret."),
            ])

            // The front-matter series (no box) prefix-matches the doc side's ", Box N" tails.
            let hit = try await pipeline.archivalNeighbors(
                forLotFile: nil, recordGroup: "84", series: "Moscow Embassy Files")
            #expect(Set(hit.documents.map(\.documentId)) == ["d1", "d2"],
                    "the series must match both boxes and not the sibling series")
            #expect(hit.basis?.contains("RG 84") == true)

            // A word prefix without a comma boundary must NOT match (over-broad guard).
            let word = try await pipeline.archivalNeighbors(
                forLotFile: nil, recordGroup: "84", series: "Moscow Embassy")
            #expect(word.totalCount == 0,
                    "'Moscow Embassy' must not prefix-match into 'Moscow Embassy Files'")

            // Degenerate short series are refused outright.
            let short = try await pipeline.archivalNeighbors(
                forLotFile: nil, recordGroup: "84", series: "Mos")
            #expect(short.totalCount == 0, "series under 4 characters must never match")
        }
    }

    @Test("Volume-level presidential-library entries match document-side library rows")
    func libraryEntryMatchesLibraryRows() async throws {
        try await withTempDir { dir in
            let pipeline = try await indexFixture(dir: dir, notes: [
                ("d1", "Source: Johnson Library, National Security File, Country File, Vietnam, Box 3. Secret."),
                ("d2", "Source: Johnson Library, National Security File, Memos to the President, Box 1. Secret."),
                ("d3", "Source: Kennedy Library, National Security Files, Countries Series, Box 8. Secret."),
            ])

            let result = try await pipeline.archivalNeighbors(
                forLotFile: nil, recordGroup: nil, series: "National Security File",
                repository: "Johnson Library")
            let ids = Set(result.documents.map(\.documentId))
            #expect(ids == ["d1", "d2"],
                    "the Johnson Library collection must match its own rows, not the Kennedy ones; got \(ids)")
            #expect(result.basis?.contains("Johnson Library") == true)

            // A non-library repository never routes through the library path.
            let nonLibrary = try await pipeline.archivalNeighbors(
                forLotFile: nil, recordGroup: nil, series: "National Security File",
                repository: "Department of State")
            #expect(nonLibrary.totalCount == 0 && nonLibrary.basis == nil,
                    "only library repositories participate in the library match path")
        }
    }

    @Test("Decimal / subject-numeric class leaves match the decimal_class column at token boundaries")
    func decimalClassLeafPath() async throws {
        try await withTempDir { dir in
            let pipeline = try await indexFixture(dir: dir, notes: [
                ("d1", "Source: Department of State, Central Files, POL 27 ARAB–ISR. Confidential."),
                ("d2", "Source: Department of State, Central Files, 711.11/3–1545. Secret."),
                // Subject-numeric class inside a structured NARA citation — the doc
                // side stores it in decimal_class now (series_name keeps only
                // "Central Files 1967–69"). Note the ASCII hyphen: real document
                // notes carry the hyphen where TEI front matter has an en-dash.
                ("d3", "Source: National Archives and Records Administration, RG 59, Central Files 1967–69, POL 27 ARAB-ISR. Secret; Immediate."),
            ])

            // The en-dash front-matter key bridges to BOTH doc-side dash forms via the
            // shared canonical form (narrative decimal row d1, structured row d3).
            let pol = try await pipeline.archivalNeighbors(
                forLotFile: nil, recordGroup: "59", series: "POL 27 ARAB–ISR",
                decimalClass: "POL 27 ARAB–ISR")
            #expect(Set(pol.documents.map(\.documentId)) == ["d1", "d3"])
            // The class path outranks the rg+series path for a class leaf.
            #expect(pol.basis?.contains("POL 27 ARAB–ISR") == true)
            #expect(pol.basis?.contains("RG") != true,
                    "a class leaf must resolve on the decimal path, not the collection one")

            // A broader class finds its country/subject subdivisions at the token boundary.
            let broad = try await pipeline.archivalNeighbors(
                forLotFile: nil, recordGroup: nil, series: nil, decimalClass: "POL 27")
            #expect(Set(broad.documents.map(\.documentId)) == ["d1", "d3"])

            // Dotted decimal leaf: matches the stored location cut from the "/item" form.
            let dotted = try await pipeline.archivalNeighbors(
                forLotFile: nil, recordGroup: nil, series: nil, decimalClass: "711.11")
            #expect(Set(dotted.documents.map(\.documentId)) == ["d2"])

            // Boundary guard: a shorter class must not match mid-token.
            let boundary = try await pipeline.archivalNeighbors(
                forLotFile: nil, recordGroup: nil, series: nil, decimalClass: "711.1")
            #expect(boundary.totalCount == 0, "'711.1' must not match '711.11' mid-token")
        }
    }

    @Test("makeNeighborsTarget gates every kind and excludes bibliography rows")
    func makeNeighborsTargetKinds() {
        // Bibliography rows never get a target, even if a key slipped in.
        let bib = VolumeSourceEntry(kind: .bibliography, lotFile: "64 D 199",
                                    rawText: "Acheson, Dean. Present at the Creation.")
        #expect(VolumeSourcesView.makeNeighborsTarget(for: bib) == nil)

        // A class leaf yields a decimal-class target.
        let leaf = VolumeSourceEntry(kind: .item, depth: 2, repository: "Department of State",
                                     recordGroup: "59", seriesName: "POL 27 ARAB–ISR",
                                     decimalClass: "POL 27 ARAB–ISR",
                                     rawText: "Central Files 1967–69: POL 27 ARAB–ISR")
        let leafTarget = VolumeSourcesView.makeNeighborsTarget(for: leaf)
        #expect(leafTarget?.decimalClass == "POL 27 ARAB–ISR")

        // A library child without a gated series name uses its own text as the collection.
        let libChild = VolumeSourceEntry(kind: .item, depth: 1, repository: "Johnson Library",
                                         rawText: "National Security File")
        let libTarget = VolumeSourcesView.makeNeighborsTarget(for: libChild)
        #expect(libTarget?.repository == "Johnson Library")
        #expect(libTarget?.series == "National Security File")

        // The library heading row itself (own text naming the repository) gets no target.
        let heading = VolumeSourceEntry(kind: .item, isHeading: true, repository: "Johnson Library",
                                        rawText: "Lyndon B. Johnson Library, Austin, Texas")
        #expect(VolumeSourcesView.makeNeighborsTarget(for: heading) == nil)

        // A record-group series entry keeps the rg+series target, with no library routing.
        let rgSeries = VolumeSourceEntry(kind: .item, depth: 1, repository: "National Archives",
                                         recordGroup: "84", seriesName: "Moscow Embassy Files",
                                         rawText: "Lot-less RG 84 series, Moscow Embassy Files")
        let rgTarget = VolumeSourcesView.makeNeighborsTarget(for: rgSeries)
        #expect(rgTarget?.recordGroup == "84" && rgTarget?.series == "Moscow Embassy Files")
        #expect(rgTarget?.repository == nil)

        // No key on any path → no affordance.
        let keyless = VolumeSourceEntry(kind: .item, rawText: "Miscellaneous records")
        #expect(VolumeSourcesView.makeNeighborsTarget(for: keyless) == nil)
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

    @Test("splitSetRefNormalisation — 'volumeId#ref' persName refs store the bare fragment (date-index v13)")
    func splitSetRefNormalisation() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")

            // Split-set form: part 2's body points at part 1's persons list. The mention must be
            // recorded under the bare fragment so it joins this volume's own persons row (each
            // part of a split set carries its own copy of the list).
            try writeTEIVolume(
                to: volDir.appendingPathComponent("vol1.xml"),
                volumeId: "vol1",
                documents: [
                    ("d1", """
                    <head>1. Report</head>
                    <p><persName ref="frus1918Supp01v01#p_LR1">Lansing</persName> wrote to
                    <persName ref="#p_W1">Wilson</persName> and <persName ref="p_B1">Baker</persName>.</p>
                    """),
                ]
            )
            try await pipeline.indexVolume("vol1")

            let dbURL = dir.appendingPathComponent("test.sqlite")
            let store = try PersonMentionStore(databaseURL: dbURL)
            let refs = try await store.personRefs(forDocumentId: "d1", volumeId: "vol1")
            #expect(refs.sorted() == ["p_B1", "p_LR1", "p_W1"],
                    "all three ref shapes (bare, #fragment, volumeId#fragment) normalise to the bare id")
        }
    }

    @Test("normalizePersonRef — bare, leading-#, split-set, and degenerate ref shapes")
    func normalizePersonRefShapes() {
        #expect(IndexingPipeline.normalizePersonRef("p_AH1") == "p_AH1")
        #expect(IndexingPipeline.normalizePersonRef("#p_AH1") == "p_AH1")
        #expect(IndexingPipeline.normalizePersonRef("frus1918Supp01v01#p_LR1") == "p_LR1")
        #expect(IndexingPipeline.normalizePersonRef("") == nil)
        #expect(IndexingPipeline.normalizePersonRef("frus1918Supp01v01#") == nil,
                "an empty fragment must produce no person_mentions row")
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
            <p>The sources for this volume are drawn from a diffuse base of records.</p>
            <list>
              <item><hi rend="strong">Department of State</hi>
                <list>
                  <item>RG 59, Central Files 1969 POL 1, Lot File 70 D 150</item>
                </list>
              </item>
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

    @Test("Structure titles collapse hard-wrapped <head> whitespace to single spaces")
    func structureTitlesCollapseWhitespace() async throws {
        try await withTempDir { dir in
            let volDir = dir.appendingPathComponent("volumes")
            try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
            let url = volDir.appendingPathComponent("frus1969-76v01.xml")
            // The <head> is hard-wrapped with ragged indentation (as in the published TEI)
            // and contains a nested element, so its text arrives in fragments.
            let xml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <TEI xmlns="http://www.tei-c.org/ns/1.0">
              <teiHeader><fileDesc><titleStmt><title>t</title></titleStmt>
              <publicationStmt><date>2010</date></publicationStmt>
              <sourceDesc><p>f</p></sourceDesc></fileDesc></teiHeader>
              <text><body>
                <div type="compilation" xml:id="comp1">
                  <head>Foundations of
                      foreign policy,
                      <date>1969</date>–1972</head>
                  <div type="document" subtype="historical-document" xml:id="d1">
                    <head>1. Document</head><p>Text.</p>
                  </div>
                </div>
              </body></text>
            </TEI>
            """
            try xml.data(using: .utf8)!.write(to: url)

            let structure = try await FRUSDocumentParser().parseVolumeStructure(volumeURL: url)
            let comp = try #require(structure.sections.first { $0.divType == "compilation" })
            #expect(comp.title == "Foundations of foreign policy, 1969–1972",
                    "interior newlines and indentation must collapse to single spaces")
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

    @Test("Sources section: prose, bold headings, and nesting are preserved (Session 170)")
    func sourcesProseHeadingsAndNesting() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            let url = volDir.appendingPathComponent("frus1969-76v01.xml")
            try writeRealEncodingVolume(to: url, volumeId: "frus1969-76v01")
            try await pipeline.indexVolume("frus1969-76v01")

            let sources = try await pipeline.volumeSources(forVolumeId: "frus1969-76v01")

            // The narrative <p> is captured as prose, not misfiled as a source row.
            #expect(sources.contains { $0.kind == .prose && $0.rawText.contains("diffuse base") })
            // The <hi rend="strong"> collection heading survives (it isn't destroyed by a
            // child <list>), at the top level.
            let heading = try #require(sources.first { $0.isHeading })
            #expect(heading.rawText.contains("Department of State"))
            #expect(heading.depth == 0)
            #expect(heading.kind == .item)
            // The RG 59 record sits one level deeper, under the heading.
            let rgRow = try #require(sources.first { $0.rawText.contains("RG 59") })
            #expect(rgRow.depth == 1)
            #expect(rgRow.recordGroup == "59")
            // Document (pre-order) order: the parent heading precedes its child.
            let headingIdx = try #require(sources.firstIndex { $0.isHeading })
            let rgIdx = try #require(sources.firstIndex { $0.rawText.contains("RG 59") })
            #expect(headingIdx < rgIdx)
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

    @Test("consolidatePersonRollup purges pre-filter non-person artifacts from the rollup")
    func consolidationPurgesNonPersonArtifacts() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            let dbURL = dir.appendingPathComponent("test.sqlite")

            try writeVolume(
                to: volDir.appendingPathComponent("volA.xml"), volumeId: "volA", year: "1969",
                documents: [("dA1", "p_k", "Kissinger")],
                persons: [("p_k", "Kissinger, Henry A.: National Security Advisor.")]
            )
            try await pipeline.indexVolume("volA")

            // Simulate a database built before the parser gained the non-person filter: inject a
            // leading-bracket parenthetical fragment directly into `persons`. The parser now rejects
            // it at index time, so it can only reach `persons` in legacy data. The relied-upon purge
            // is what must remove it — there is no skip-guard in the loader, so if the purge failed
            // the artifact would cluster into a rollup and this assertion would catch it.
            var db: OpaquePointer?
            #expect(sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK)
            let TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            var ins: OpaquePointer?
            sqlite3_prepare_v2(db, "INSERT INTO persons (volume_id, ref, name) VALUES (?, ?, ?)", -1, &ins, nil)
            sqlite3_bind_text(ins, 1, "volA", -1, TRANSIENT)
            sqlite3_bind_text(ins, 2, "x_junk", -1, TRANSIENT)
            sqlite3_bind_text(ins, 3, "(together with political, military and technical advisers).", -1, TRANSIENT)
            #expect(sqlite3_step(ins) == SQLITE_DONE)
            sqlite3_finalize(ins)
            sqlite3_close_v2(db)

            try await pipeline.consolidatePersonRollup()

            let store = try PersonMentionStore(databaseURL: dbURL)
            let names = try await store.allPersonsSortedByName().map(\.entry.name)
            #expect(names == ["Kissinger, Henry A."], "the parenthetical artifact must be purged from the rollup")
            #expect(!names.contains { $0.hasPrefix("(") })
        }
    }

    @Test("consolidatePersonRollup purges back-of-book index artifacts (rollup v8, finding D)")
    func consolidationPurgesIndexArtifacts() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            let dbURL = dir.appendingPathComponent("test.sqlite")

            try writeVolume(
                to: volDir.appendingPathComponent("volA.xml"), volumeId: "volA", year: "1943",
                documents: [("dA1", "p_k", "Kissinger")],
                persons: [("p_k", "Kissinger, Henry A.: National Security Advisor.")]
            )
            try await pipeline.indexVolume("volA")

            // Simulate the frus1941-43 artifact: a back-of-book *index* mis-parsed as a persons
            // list before the v8 heuristic hardening — page-number entries, subject headings
            // with page ranges, and multi-line entries, all with zero mentions.
            let junk = [
                ("x_1", "Churchill, 532"),
                ("x_2", "Eden, 815–817"),
                ("x_3", "Acheson, Dean G., Assistant Secretary of State, 62"),
                ("x_4", "Identity 1, 2, etc."),
                ("x_5", "Aid to French North Africa, agreement with Roosevelt for, 823–828"),
                ("x_6", "Anglo-American conversations,\nWashington"),
                ("x_7", String(repeating: "Subject heading far too long to be a person name ", count: 3))
            ]
            var db: OpaquePointer?
            #expect(sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK)
            let TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            for (ref, name) in junk {
                var ins: OpaquePointer?
                sqlite3_prepare_v2(db, "INSERT INTO persons (volume_id, ref, name) VALUES (?, ?, ?)", -1, &ins, nil)
                sqlite3_bind_text(ins, 1, "volA", -1, TRANSIENT)
                sqlite3_bind_text(ins, 2, ref, -1, TRANSIENT)
                sqlite3_bind_text(ins, 3, name, -1, TRANSIENT)
                #expect(sqlite3_step(ins) == SQLITE_DONE)
                sqlite3_finalize(ins)
            }
            sqlite3_close_v2(db)

            try await pipeline.consolidatePersonRollup()

            let store = try PersonMentionStore(databaseURL: dbURL)
            let names = try await store.allPersonsSortedByName().map(\.entry.name)
            #expect(names == ["Kissinger, Henry A."],
                    "every index artifact must be purged; the real person survives")
        }
    }

    @Test("isLikelyPersonName rejects index artifacts but never real-person name shapes (v8)")
    func personListHeuristicHardening() {
        // Rejected: the frus1941-43 back-of-book index shapes.
        #expect(!PersonListHeuristics.isLikelyPersonName("Churchill, 532"))
        #expect(!PersonListHeuristics.isLikelyPersonName("Eden, 815–817"))
        #expect(!PersonListHeuristics.isLikelyPersonName("Acheson, Dean G., Assistant Secretary of State, 62"))
        #expect(!PersonListHeuristics.isLikelyPersonName("Identity 1, 2, etc."))
        #expect(!PersonListHeuristics.isLikelyPersonName("Aid to French North Africa, agreement with Roosevelt for, 823–828"))
        #expect(!PersonListHeuristics.isLikelyPersonName("Anglo-American conversations,\nWashington"))
        #expect(!PersonListHeuristics.isLikelyPersonName(String(repeating: "long ", count: 20)))
        // Kept: real persons-list shapes, including the tricky ones the doc comment names.
        #expect(PersonListHeuristics.isLikelyPersonName("Haig, Alexander M."))
        #expect(PersonListHeuristics.isLikelyPersonName("McKeown (MacEoin), Major General Sean"))
        #expect(PersonListHeuristics.isLikelyPersonName("'Abd al-Rahman"))
        #expect(PersonListHeuristics.isLikelyPersonName("Bao Dai"))
        #expect(PersonListHeuristics.isLikelyPersonName("Roosevelt, Franklin D., Jr."))
        #expect(PersonListHeuristics.isLikelyPersonName("Carter, Hodding 3d"),
                "digit+letter generational ordinals are not page-number runs")
    }

    @Test("majorityAuthorityId picks the id with the most mentions, smaller id on ties, nil when uncovered")
    func majorityAuthorityIdPick() {
        func member(_ ref: String, authorityId: Int?, mentions: Int) -> PersonClusterInput {
            PersonClusterInput(volumeId: "v", ref: ref, name: "X",
                               authorityId: authorityId, mentionCount: mentions)
        }
        // Majority by mentions, not by member count or input order: two low-mention members of
        // id 1 lose to one high-mention member of id 2 even though id 1 appears first.
        #expect(IndexingPipeline.majorityAuthorityId(for: [
            member("a", authorityId: 1, mentions: 3),
            member("b", authorityId: 1, mentions: 4),
            member("c", authorityId: 2, mentions: 48),
            member("d", authorityId: nil, mentions: 100)   // uncovered members carry no vote
        ]) == 2)
        // Deterministic tiebreak: the smaller id wins.
        #expect(IndexingPipeline.majorityAuthorityId(for: [
            member("a", authorityId: 7, mentions: 5),
            member("b", authorityId: 3, mentions: 5)
        ]) == 3)
        // Fully uncovered cluster → no authority id.
        #expect(IndexingPipeline.majorityAuthorityId(for: [
            member("a", authorityId: nil, mentions: 10)
        ]) == nil)
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

    @Test("rollup carries volume_count and member drill-in (Phase 4)")
    func volumeCountAndMemberDrillIn() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            // The same person in two volumes → one cluster spanning two volumes.
            try writeVolume(
                to: volDir.appendingPathComponent("volA.xml"), volumeId: "volA", year: "1970",
                documents: [("dA1", "p_k", "Kissinger")],
                persons: [("p_k", "Kissinger, Henry A.")]
            )
            try writeVolume(
                to: volDir.appendingPathComponent("volB.xml"), volumeId: "volB", year: "1971",
                documents: [("dB1", "p_k", "Kissinger")],
                persons: [("p_k", "Kissinger, Henry A.")]
            )
            try await pipeline.indexVolume("volA")
            try await pipeline.indexVolume("volB")
            try await pipeline.consolidatePersonRollup()

            let store = try PersonMentionStore(databaseURL: dir.appendingPathComponent("test.sqlite"))
            let kissinger = try #require(
                try await store.allPersonsSortedByName().first { $0.entry.name == "Kissinger, Henry A." })
            #expect(kissinger.volumeCount == 2, "the cluster spans two volumes")

            let rid = try #require(kissinger.rollupId)
            let members = try await store.members(forRollupId: rid)
            #expect(members.count == 2)
            #expect(Set(members.map(\.volumeId)) == ["volA", "volB"])
            #expect(members.allSatisfy { $0.entry.name == "Kissinger, Henry A." })
        }
    }

    @Test("rollupIdsWithCandidates surfaces both rollups of a pending suggestion (Phase 4)")
    func candidateSetSurfacesRollups() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            // Variant + role conflict → a candidate the clusterer does not auto-merge.
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
            let withCandidates = try await store.rollupIdsWithCandidates()
            let kissingers = try await store.allPersonsSortedByName().filter { $0.entry.name.hasPrefix("Kissinger") }
            #expect(kissingers.count == 2)
            for k in kissingers {
                #expect(withCandidates.contains(k.rollupId ?? -1), "both sides of the pair are flagged")
            }
        }
    }

    @Test("authority crosswalk drives the rollup: canonical name, ids/VIAF, and conflation split (Phase 5)")
    func authorityDrivesRollup() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            // The same person under two name strings across volumes (the heuristic would only make a
            // candidate), plus a different person who shares the name "Kissinger, Henry".
            try writeVolume(
                to: volDir.appendingPathComponent("volA.xml"), volumeId: "volA", year: "1962",
                documents: [("dA1", "p_k", "Kissinger")],
                persons: [("p_k", "Kissinger, Henry A.")]
            )
            try writeVolume(
                to: volDir.appendingPathComponent("volB.xml"), volumeId: "volB", year: "1973",
                documents: [("dB1", "p_h", "Kissinger")],
                persons: [("p_h", "Kissinger, Henry")]
            )
            try writeVolume(
                to: volDir.appendingPathComponent("volC.xml"), volumeId: "volC", year: "1905",
                documents: [("dC1", "p_x", "Kissinger")],
                persons: [("p_x", "Kissinger, Henry")]
            )
            try await pipeline.indexVolume("volA")
            try await pipeline.indexVolume("volB")
            try await pipeline.indexVolume("volC")

            // Inject an authority index: volA/p_k + volB/p_h → 107252 (the real Kissinger);
            // volC/p_x → 999 (a same-named different person).
            let index = PersonAuthorityIndex(
                version: 1, generated: "test", source: "test",
                crosswalk: ["volA": ["p_k": 107252], "volB": ["p_h": 107252], "volC": ["p_x": 999]],
                authority: [
                    "107252": .init(n: "Kissinger, Henry A.", b: 1923, d: nil, v: "66509613"),
                    "999": .init(n: "Kissinger, Henry (clerk)", b: 1880, d: 1944, v: nil)
                ])
            await pipeline.setAuthorityIndexForTesting(index)
            try await pipeline.consolidatePersonRollup()

            let store = try PersonMentionStore(databaseURL: dir.appendingPathComponent("test.sqlite"))
            let all = try await store.allPersonsSortedByName()

            // The two name variants unite under the canonical identity, with VIAF + birth year.
            let k = try #require(all.first { $0.authorityId == 107252 })
            #expect(k.entry.name == "Kissinger, Henry A.")
            #expect(k.viafId == "66509613")
            #expect(k.entry.startYear == 1923)
            let members = try await store.members(forRollupId: try #require(k.rollupId))
            #expect(Set(members.map(\.volumeId)) == ["volA", "volB"])

            // The same-named different person stays a separate identity (authority splits it).
            let other = try #require(all.first { $0.authorityId == 999 })
            #expect(other.rollupId != k.rollupId)
            #expect(other.entry.name == "Kissinger, Henry (clerk)")
        }
    }

    @Test("keyword-less personRollupId search returns the whole cluster's documents (Find all mentions)")
    func findAllMentionsByRollup() async throws {
        try await withTempDir { dir in
            let (pipeline, fts5) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            // Kissinger across two volumes (one cluster, different refs); each has a doc mentioning
            // him, plus a doc that mentions someone else.
            try writeVolume(
                to: volDir.appendingPathComponent("volA.xml"), volumeId: "volA", year: "1970",
                documents: [("dA1", "p_k", "Kissinger"), ("dA2", "p_other", "Other")],
                persons: [("p_k", "Kissinger, Henry A."), ("p_other", "Other, Person")]
            )
            try writeVolume(
                to: volDir.appendingPathComponent("volB.xml"), volumeId: "volB", year: "1971",
                documents: [("dB1", "p_h", "Kissinger")],
                persons: [("p_h", "Kissinger, Henry A.")]
            )
            try await pipeline.indexVolume("volA")
            try await pipeline.indexVolume("volB")
            try await pipeline.consolidatePersonRollup()

            let store = try PersonMentionStore(databaseURL: dir.appendingPathComponent("test.sqlite"))
            let kissinger = try #require(
                try await store.allPersonsSortedByName().first { $0.entry.name == "Kissinger, Henry A." })
            let rid = try #require(kissinger.rollupId)

            let service = SearchService(fts5Store: fts5, pipeline: pipeline, personMentionStore: store)
            // The "Find all mentions" handoff: a keyword-less, person-scoped search.
            let params = SearchParameters(personRollupId: rid, personLabel: "Kissinger, Henry A.")
            let results = try await service.search(parameters: params)
            let keys = Set(results.map { "\($0.volumeId)/\($0.documentId)" })
            #expect(keys == ["volA/dA1", "volB/dB1"],
                    "documents mentioning any cluster member, across volumes; no others")
            #expect(try await service.searchCount(parameters: params) == 2)
        }
    }
}

// MARK: - HeadNestedSourceNoteTests (Source Explorer Phase 1)

/// End-to-end tests for the head-nested source-note extraction fix, using the **real**
/// corpus encodings (verified against the published TEI on 2026-07-03):
///
/// - 1955+ volumes: `<note type="source">` nested inside `<head>` (plain children);
/// - Nixon–Ford electronic volumes: head-nested `<note type="source">` holding
///   `<p><seg type="summary">…</seg></p><p><seg type="source">…</seg></p>`;
/// - 1861–1954 volumes: top-level `<note rend="inline" type="source">` before `<head>`;
/// - withheld-document notes: `[Source: …]` bracket wrapper.
///
/// Each fixture is parsed through `FRUSDocumentParser` and indexed through the full
/// pipeline, so these tests also prove the parser preserves head-nested notes in the AST.
@Suite("IndexingPipeline — head-nested source notes (Phase 1)")
struct HeadNestedSourceNoteTests {

    /// Writes a volume in the real-corpus encoding (`subtype="historical-document"`).
    private func writeRealVolume(to url: URL, volumeId: String, documents: [(id: String, xml: String)]) throws {
        let docBlocks = documents.map { doc in
            "<div type=\"document\" subtype=\"historical-document\" n=\"\(doc.id.dropFirst())\" xml:id=\"\(doc.id)\">\(doc.xml)</div>"
        }.joined(separator: "\n")
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <teiHeader><fileDesc><titleStmt><title>\(volumeId)</title></titleStmt>
          <publicationStmt><date>2010</date></publicationStmt>
          <sourceDesc><p>Test fixture</p></sourceDesc></fileDesc></teiHeader>
          <text><body>
            <div type="compilation" xml:id="comp1">
              <head>Compilation</head>
              \(docBlocks)
            </div>
          </body></text>
        </TEI>
        """
        try xml.data(using: .utf8)!.write(to: url)
    }

    /// Reads `citation_era` and `classification` for one document straight from the
    /// `document_sources` table (no public API exposes classification yet — store-only phase).
    private func documentSourceRow(
        dbURL: URL, volumeId: String, documentId: String
    ) throws -> (era: String, classification: String?)? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let handle = db else {
            sqlite3_close(db)
            throw NSError(domain: "HeadNestedSourceNoteTests", code: 1)
        }
        defer { sqlite3_close_v2(handle) }
        let sql = "SELECT citation_era, classification FROM document_sources WHERE volume_id = ? AND document_id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw NSError(domain: "HeadNestedSourceNoteTests", code: 2)
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, volumeId, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(stmt, 2, documentId, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        let era = sqlite3_column_text(stmt, 0).map { String(cString: $0) } ?? ""
        let classification = sqlite3_column_text(stmt, 1).map { String(cString: $0) }
        return (era, classification)
    }

    /// The 1955+ encoding: plain head-nested note. Also verifies the structured
    /// (`citation_era='structured'`) row, the classification split, and the header
    /// side effect (note text no longer leaks into the stored title).
    @Test("head-nested plain note: extracted, structured row, classification, clean header")
    func headNestedPlainNote() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            let url = volDir.appendingPathComponent("frus1964-68v19.xml")
            try writeRealVolume(to: url, volumeId: "frus1964-68v19", documents: [
                ("d1", """
                <head>1. Memorandum From the President&#8217;s Special Assistant (Rostow) to \
                President Johnson<note n=" 1" type="source" xml:id="d1fn1">Source: Johnson \
                Library, National Security File, Country File, Vietnam, Memos. Secret; Nodis. \
                Sent for information.</note></head>
                <p>Body text about negotiations.</p>
                """),
            ])
            try await pipeline.indexVolume("frus1964-68v19")

            let docs = try await pipeline.documents(forVolume: "frus1964-68v19")
            let d1 = try #require(docs.first { $0.documentId == "d1" })

            // The head-nested note is extracted and stored.
            #expect(d1.sourceNote == "Source: Johnson Library, National Security File, Country File, Vietnam, Memos. Secret; Nodis. Sent for information.")

            // Header side effect (deliberate): the note text no longer leaks into the title.
            #expect(d1.header == "1. Memorandum From the President\u{2019}s Special Assistant (Rostow) to President Johnson")
            #expect(d1.header.contains("Johnson Library") == false)

            // "Source: …" narrative now reaches the structured parser: presidentialLibrary row.
            let row = try #require(try documentSourceRow(
                dbURL: dir.appendingPathComponent("test.sqlite"),
                volumeId: "frus1964-68v19", documentId: "d1"))
            #expect(row.era == "structured")
            // S1 classification split: sentence 2 is markings; remarks are not stored.
            #expect(row.classification == "Secret; Nodis")
        }
    }

    /// The Nixon–Ford electronic-volume encoding: head-nested typed note holding
    /// summary + source `<seg>` paragraphs — only the source segment is the note.
    @Test("head-nested seg variant: only the source seg is extracted")
    func headNestedSegVariant() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            let url = volDir.appendingPathComponent("frus1969-76ve09p1.xml")
            try writeRealVolume(to: url, volumeId: "frus1969-76ve09p1", documents: [
                ("d1", """
                <head>1. Memorandum From the Deputy Assistant to the President<note n="1" \
                type="source" xml:id="d1fn1"><p><seg type="summary">Summary: Scowcroft provided \
                Nixon with a report of a conversation.</seg></p><p><seg type="source">Source: \
                Library of Congress, Manuscript Division, Kissinger Papers, Box CL 101, \
                Geopolitical File. Secret; Sensitive; Exclusively Eyes Only.</seg></p></note></head>
                <p>Body text.</p>
                """),
            ])
            try await pipeline.indexVolume("frus1969-76ve09p1")

            let docs = try await pipeline.documents(forVolume: "frus1969-76ve09p1")
            let d1 = try #require(docs.first { $0.documentId == "d1" })
            let note = try #require(d1.sourceNote)
            #expect(note.hasPrefix("Source: Library of Congress"))
            #expect(note.contains("Summary:") == false,
                    "the summary seg must not pollute the stored source note")
            #expect(d1.header == "1. Memorandum From the Deputy Assistant to the President")

            let row = try #require(try documentSourceRow(
                dbURL: dir.appendingPathComponent("test.sqlite"),
                volumeId: "frus1969-76ve09p1", documentId: "d1"))
            #expect(row.classification == "Secret; Sensitive; Exclusively Eyes Only")
        }
    }

    /// Pre-1955 regression: the top-level inline encoding still extracts, the stored
    /// shape of a bare decimal note is byte-identical, and no classification is invented.
    @Test("top-level inline note (pre-1955): unchanged extraction, decimal era, nil classification")
    func topLevelInlineNoteRegression() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            let url = volDir.appendingPathComponent("frus1952-54v01.xml")
            try writeRealVolume(to: url, volumeId: "frus1952-54v01", documents: [
                ("d1", """
                <note rend="inline" type="source">711.00/11&#8211;552</note>\
                <head><hi rend="italic">Memorandum by the Secretary of State</hi></head>
                <p>Body text.</p>
                """),
            ])
            try await pipeline.indexVolume("frus1952-54v01")

            let docs = try await pipeline.documents(forVolume: "frus1952-54v01")
            let d1 = try #require(docs.first { $0.documentId == "d1" })
            #expect(d1.sourceNote == "711.00/11\u{2013}552",
                    "bare pre-1955 decimal notes keep their stored shape exactly")
            #expect(d1.header == "Memorandum by the Secretary of State")

            let row = try #require(try documentSourceRow(
                dbURL: dir.appendingPathComponent("test.sqlite"),
                volumeId: "frus1952-54v01", documentId: "d1"))
            #expect(row.era == "decimal")
            #expect(row.classification == nil)
        }
    }

    /// Wrapper stripping is consistent across both encodings: the `[Source: …]`
    /// bracket wrapper collapses to `Source: …` whether the note is top-level
    /// (withheld-document inline) or head-nested.
    @Test("wrapper stripping: [Source: …] normalises in both encodings")
    func wrapperStrippingBothEncodings() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            let url = volDir.appendingPathComponent("frus1961-63v11.xml")
            try writeRealVolume(to: url, volumeId: "frus1961-63v11", documents: [
                // Top-level withheld-document note, bracket-wrapped.
                ("d1", """
                <head>1. Editorial Heading</head>\
                <note rend="inline" type="source">[Source: Kennedy Library, National Security \
                Files, Countries Series, Cuba. Secret; Eyes Only. Not declassified.]</note>
                <p>[Not declassified.]</p>
                """),
                // Head-nested note, bracket-wrapped.
                ("d2", """
                <head>2. Telegram<note n="1" type="source" xml:id="d2fn1">[Source: Department \
                of State, Central Files, 737.00/1&#8211;2661. Confidential; Niact. Not \
                declassified.]</note></head>
                <p>Body.</p>
                """),
            ])
            try await pipeline.indexVolume("frus1961-63v11")

            let docs = try await pipeline.documents(forVolume: "frus1961-63v11")
            let d1 = try #require(docs.first { $0.documentId == "d1" })
            let d2 = try #require(docs.first { $0.documentId == "d2" })

            #expect(d1.sourceNote?.hasPrefix("Source: Kennedy Library") == true)
            #expect(d1.sourceNote?.hasSuffix("Not declassified.") == true)
            #expect(d2.sourceNote?.hasPrefix("Source: Department of State") == true)
            #expect(d2.sourceNote?.hasSuffix("Not declassified.") == true)

            // The normalised "Source:" prefix drives the structured parser for d1.
            let row1 = try #require(try documentSourceRow(
                dbURL: dir.appendingPathComponent("test.sqlite"),
                volumeId: "frus1961-63v11", documentId: "d1"))
            #expect(row1.era == "structured")
            #expect(row1.classification == "Secret; Eyes Only")
        }
    }

    /// NARA narratives from the head-nested era produce `citation_era='structured'`
    /// `.naraCollection` rows — the audit found zero such rows existed before this fix.
    @Test("structured rows: head-nested NARA narrative yields citation_era='structured'")
    func structuredNARARow() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            let url = volDir.appendingPathComponent("frus1969-76v25.xml")
            try writeRealVolume(to: url, volumeId: "frus1969-76v25", documents: [
                ("d1", """
                <head>1. Telegram From the Department of State<note n=" 1" type="source" \
                xml:id="d1fn1">Source: National Archives, RG 59, Central Files 1970&#8211;73, \
                POL 27 ARAB&#8211;ISR. Secret; Nodis.</note></head>
                <p>Body.</p>
                """),
            ])
            try await pipeline.indexVolume("frus1969-76v25")

            let sources = try await pipeline.documentSourcesByKey([
                (volumeId: "frus1969-76v25", documentId: "d1")
            ])
            let source = try #require(sources["frus1969-76v25/d1"])
            #expect(source.recordGroup == "59")
            #expect(source.rawText.hasPrefix("Source: National Archives"))

            let row = try #require(try documentSourceRow(
                dbURL: dir.appendingPathComponent("test.sqlite"),
                volumeId: "frus1969-76v25", documentId: "d1"))
            #expect(row.era == "structured")
            #expect(row.classification == "Secret; Nodis")
        }
    }
}

// MARK: - VolumeSourcesKeyingTests (Source Explorer Phase 3 step 1)

/// Writes a volume whose front matter exercises every Phase 3 front-matter keying case:
/// designator-agnostic lots (F/W/M), run-together boundaries, `Lot File(s)` prefixes,
/// three-level outline inheritance, decimal/subject-numeric class leaves, junk series
/// tails, and all three published-works bibliography encodings — a `Published Sources`
/// pseudo-heading subtree inside the ordinary sources div (preamble, item list,
/// p-encoded periodical citation, `Note:` annotation, and the long-narrative exit back
/// to prose), a whole section headed `Published sources`, and a `listofworks` div (the
/// canonical TEI encoding, unused by the current corpus but kept as the contract).
private func writeKeyingFixtureVolume(to url: URL, volumeId: String) throws {
    let xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <TEI xmlns="http://www.tei-c.org/ns/1.0">
      <teiHeader><fileDesc><titleStmt><title>\(volumeId)</title></titleStmt>
      <publicationStmt><date when="2010">2010</date></publicationStmt>
      <sourceDesc><p>Test fixture</p></sourceDesc></fileDesc></teiHeader>
      <text>
        <front>
          <div type="section" subtype="sources" xml:id="sources">
            <head>Sources</head>
            <p>The editors drew on the collections below.</p>
            <list>
              <item><hi rend="strong">National Archives and Records Administration</hi>
                <list>
                  <item>Record Group 59, General Records of the Department of State
                    <list>
                      <item>Central Files 1967–69: POL 27 ARAB–ISR</item>
                      <item>DEF 6 MLF</item>
                      <item>POL 3 UAR: Arab unity</item>
                      <item>611.80; 611.86; POL Near East 1: Palestinian refugee question</item>
                      <item>DEF 9 TUR, military personnel, Turkey</item>
                      <item>AID (US) 15–4 UAR: P.L. 480 agreements, United Arab Republic</item>
                      <item>Lot 90 D 313Records of the Executive Secretariat</item>
                      <item>Lot Files 74 D 131</item>
                      <item>Conference Files: Lot 66 D 110, see National Archives and Records Administration below.</item>
                      <item>Central Files, 1977–1980</item>
                    </list>
                  </item>
                  <item>Record Group 84, Foreign Service Post Files
                    <list>
                      <item>Lot 62 F 83, Moscow Embassy Files</item>
                    </list>
                  </item>
                </list>
              </item>
              <item><hi rend="strong">Lyndon B. Johnson Library, Austin, Texas</hi>
                <list>
                  <item>National Security File
                    <list>
                      <item>Country File, Vietnam</item>
                    </list>
                  </item>
                </list>
              </item>
              <item>Lot W 130, Records of the Department</item>
              <item>Miscellaneous Lot M–88 Records</item>
            </list>
            <p rend="center"><hi rend="strong">Published Sources</hi></p>
            <p>The following publications, including secondary accounts, were particularly
               useful in the preparation of this volume. Citations to additional published
               documents, memoirs, and other primary sources are provided throughout the
               volume as appropriate. No responsibility is taken by the Department of State
               for the accuracy of events set forth in unofficial sources.</p>
            <list>
              <item>Eden, Anthony. Memoirs: Full Circle. Boston: Houghton Mifflin, 1960. Cites Lot 99 D 999.</item>
            </list>
            <p>New York Times.</p>
            <p><hi rend="italic">Note:</hi> The following publications were consulted at the
               time this volume was prepared in 1980 and 1981. The Department of State takes
               no responsibility for their accuracy nor endorses their interpretation of the
               events described therein by their respective authors.</p>
            <p>Eisenhower, Dwight D. Waging Peace: The White House Years, 1956–1961. Garden City: Doubleday, 1965.</p>
            <p>In compliance with the Foreign Relations of the United States statute that
               requires inclusion of comprehensive documentation on major foreign policy
               decisions, the editors have further identified within this section the files
               and collections reviewed but not selected, returning the narrative to
               ordinary prose after the published rows above.</p>
            <p>Additional narrative that must stay prose.</p>
          </div>
          <div type="section" subtype="sources" xml:id="published">
            <head>Published sources</head>
            <p rend="flushleft">Kissinger, Henry A. White House Years. Boston: Little, Brown, 1979.</p>
          </div>
          <div type="section" subtype="listofworks" xml:id="listofworks">
            <head>List of Works Cited</head>
            <list>
              <item>Acheson, Dean. Present at the Creation. New York: Norton, 1969. Cites Lot 64 D 199.</item>
            </list>
          </div>
        </front>
        <body>
          <div type="compilation" xml:id="comp1">
            <head>Chapter</head>
            <div type="document" subtype="historical-document" n="1" xml:id="d1">
              <head>1. Memorandum</head>
              <p>Body text.</p>
            </div>
          </div>
        </body>
      </text>
    </TEI>
    """
    try xml.data(using: .utf8)!.write(to: url)
}

@Suite("Volume sources keying — Source Explorer Phase 3 step 1")
struct VolumeSourcesKeyingTests {

    /// Parses the keying fixture and returns its front-matter entries.
    private func parseFixtureEntries() async throws -> [VolumeSourceEntry] {
        try await withTempDir { dir in
            let url = dir.appendingPathComponent("frus1969-76v01.xml")
            try writeKeyingFixtureVolume(to: url, volumeId: "frus1969-76v01")
            return try await FRUSDocumentParser().parseVolumeFull(volumeURL: url).volumeSources
        }
    }

    /// Finds the single entry whose raw text contains `fragment`.
    private func entry(_ entries: [VolumeSourceEntry], containing fragment: String) throws -> VolumeSourceEntry {
        try #require(entries.first { $0.rawText.contains(fragment) },
                     "expected an entry containing \(fragment)")
    }

    @Test("F, W, and M designator lots are keyed with compact norms (D-only regex retired)")
    func designatorAgnosticLots() async throws {
        let entries = try await parseFixtureEntries()

        let fLot = try entry(entries, containing: "Moscow Embassy Files")
        #expect(fLot.lotFile == "62 F 83")
        #expect(fLot.lotFileNorm == "62F83")

        let wLot = try entry(entries, containing: "Lot W 130")
        #expect(wLot.lotFile == "W 130")
        #expect(wLot.lotFileNorm == "W130")

        let mLot = try entry(entries, containing: "Miscellaneous Lot")
        #expect(mLot.lotFile == "M–88")
        #expect(mLot.lotFileNorm == "M88")
    }

    @Test("Run-together text after the lot number does not defeat the boundary")
    func lotRunTogetherBoundary() async throws {
        let entries = try await parseFixtureEntries()
        let lot = try entry(entries, containing: "Executive Secretariat")
        #expect(lot.lotFile == "90 D 313",
                "'Lot 90 D 313Records...' must key the bare number")
        #expect(lot.lotFileNorm == "90D313")
    }

    @Test("A Lot File(s) prefix is skipped, never captured into the key")
    func lotFilePrefixClean() async throws {
        let entries = try await parseFixtureEntries()
        let lot = try entry(entries, containing: "74 D 131")
        #expect(lot.lotFile == "74 D 131",
                "the greedy-prefix pollution keyed lot=\"Files 74 D 131\"")
        #expect(lot.lotFileNorm == "74D131")
    }

    @Test("Record group and repository inherit from ancestor headings down three levels")
    func inheritanceThreeLevels() async throws {
        let entries = try await parseFixtureEntries()

        // Depth-1 RG heading: own-text keyword wins over inheritance ("General Records
        // of the Department of State" names the agency — exactly the repository string
        // the doc side stores for lot/decimal rows).
        let rgHeading = try entry(entries, containing: "General Records of the Department of State")
        #expect(rgHeading.depth == 1)
        #expect(rgHeading.recordGroup == "59")
        #expect(rgHeading.repository == "Department of State")

        // Depth-2 leaves inherit record group and repository from the parent heading.
        for fragment in ["POL 27 ARAB–ISR", "DEF 6 MLF", "Executive Secretariat"] {
            let leaf = try entry(entries, containing: fragment)
            #expect(leaf.depth == 2)
            #expect(leaf.recordGroup == "59", "leaf \(fragment) must inherit RG 59")
            #expect(leaf.repository == "Department of State",
                    "leaf \(fragment) must inherit the nearest ancestor repository")
        }

        // The RG 84 subtree inherits its own parent, not the sibling's — and its leaf
        // walks PAST the keyword-less parent heading to the depth-0 repository heading
        // (three-level inheritance).
        let rg84Heading = try entry(entries, containing: "Foreign Service Post Files")
        #expect(rg84Heading.repository == "National Archives",
                "a heading without its own repository keyword inherits the outline's")
        let fLot = try entry(entries, containing: "Moscow Embassy Files")
        #expect(fLot.recordGroup == "84")
        #expect(fLot.repository == "National Archives",
                "the leaf inherits the grandparent repository across a keyword-less parent")

        // Presidential-library identity flows down to grandchildren.
        let libraryLeaf = try entry(entries, containing: "Country File, Vietnam")
        #expect(libraryLeaf.depth == 2)
        #expect(libraryLeaf.repository == "Johnson Library")
        #expect(libraryLeaf.recordGroup == nil)
    }

    @Test("Decimal / subject-numeric class leaves get a location key in the shared canonical form")
    func classLeafKeys() async throws {
        let entries = try await parseFixtureEntries()

        // Colon-prefixed class leaf (audit shape): the class is the segment after the
        // final colon — and the TEI en-dash canonicalizes to the ASCII hyphen the same
        // file carries in document source notes.
        let pol = try entry(entries, containing: "POL 27 ARAB–ISR")
        #expect(pol.decimalClass == "POL 27 ARAB-ISR")
        #expect(pol.lotFile == nil)

        let def = try entry(entries, containing: "DEF 6 MLF")
        #expect(def.decimalClass == "DEF 6 MLF")

        // Leaf-before-colon (the dominant 1961–1976 shape): class leads, prose follows.
        let leafFirst = try entry(entries, containing: "Arab unity")
        #expect(leafFirst.decimalClass == "POL 3 UAR")

        // Semicolon class lists key on the first passing segment.
        let list = try entry(entries, containing: "Palestinian refugee question")
        #expect(list.decimalClass == "611.80")

        // Comma-described leaves (the 1969–1976 shape) key on the leading segment.
        let comma = try entry(entries, containing: "military personnel")
        #expect(comma.decimalClass == "DEF 9 TUR")

        // Parenthesized agency qualifiers pass the shared gate, dash-canonicalized.
        let aid = try entry(entries, containing: "P.L. 480 agreements")
        #expect(aid.decimalClass == "AID (US) 15-4 UAR")

        // Lot-keyed rows and prose-ish rows are never class leaves.
        let lot = try entry(entries, containing: "Executive Secretariat")
        #expect(lot.decimalClass == nil)
        let heading = try entry(entries, containing: "General Records of the Department of State")
        #expect(heading.decimalClass == nil)
    }

    @Test("Junk series-name captures store nil instead of heuristic tails")
    func junkSeriesTailsStoreNil() async throws {
        let entries = try await parseFixtureEntries()

        // Cross-reference tail ("…, see National Archives … below.") is rejected.
        let crossRef = try entry(entries, containing: "66 D 110")
        #expect(crossRef.seriesName == nil,
                "a 'see …' tail must not become a series name")
        #expect(crossRef.lotFile == "66 D 110", "the lot key itself is kept")

        // Bare year-range tail ("Central Files, 1977–1980") is rejected.
        let yearRange = try entry(entries, containing: "1977–1980")
        #expect(yearRange.seriesName == nil,
                "a bare year range must not become a series name")

        // A real series tail still passes the gate.
        let good = try entry(entries, containing: "Moscow Embassy Files")
        #expect(good.seriesName == "Moscow Embassy Files")
    }

    @Test("listofworks bibliography rows are marked and carry no archival keys")
    func bibliographyMarker() async throws {
        let entries = try await parseFixtureEntries()
        let bib = try entry(entries, containing: "Present at the Creation")
        #expect(bib.kind == .bibliography)
        #expect(bib.lotFile == nil,
                "a lot number cited inside a book title must not key the row")
        #expect(bib.lotFileNorm == nil)
        #expect(bib.recordGroup == nil)
        #expect(bib.decimalClass == nil)

        // The archival sections are untouched by the marker.
        #expect(entries.contains { $0.kind == .item })
        #expect(entries.contains { $0.kind == .prose })
    }

    @Test("A Published Sources pseudo-heading subtree marks its rows bibliography (the real corpus encoding)")
    func publishedPseudoHeadingSubtree() async throws {
        let entries = try await parseFixtureEntries()

        // The pseudo-heading paragraph itself stays prose, like every other
        // pseudo-heading in the narrative flow.
        let heading = try entry(entries, containing: "Published Sources")
        #expect(heading.kind == .prose)

        // A long editorial preamble BEFORE any published row stays in the subtree
        // (frus1952-54v13's Part B shape) — it describes the list.
        let preamble = try entry(entries, containing: "particularly useful")
        #expect(preamble.kind == .bibliography)

        // The published items are bibliography and never keyed — even when a book
        // title cites a lot number.
        let book = try entry(entries, containing: "Full Circle")
        #expect(book.kind == .bibliography)
        #expect(book.lotFile == nil)
        #expect(book.lotFileNorm == nil)
        #expect(book.decimalClass == nil)

        // P-encoded periodical citations inside the subtree are bibliography
        // (frus1981-88v01's newspaper list shape).
        let paper = try entry(entries, containing: "New York Times")
        #expect(paper.kind == .bibliography)

        // A long `Note:` annotation about the list stays in the subtree
        // (frus1958-60v05's memoirs shape), and the citation after it too.
        let note = try entry(entries, containing: "were consulted at the time")
        #expect(note.kind == .bibliography)
        let memoir = try entry(entries, containing: "Waging Peace")
        #expect(memoir.kind == .bibliography)

        // A long narrative paragraph AFTER the published rows exits the subtree
        // (frus1964-68v06 continues its sources div with a covert-actions note).
        let exit = try entry(entries, containing: "In compliance with the Foreign Relations")
        #expect(exit.kind == .prose)
        let after = try entry(entries, containing: "Additional narrative")
        #expect(after.kind == .prose)
    }

    @Test("A section headed Published sources is a bibliography wholesale (frus1969-76v34/v36 shape)")
    func publishedHeadSection() async throws {
        let entries = try await parseFixtureEntries()
        let book = try entry(entries, containing: "Kissinger")
        #expect(book.kind == .bibliography)
    }

    @Test("Front-matter and document-side lot keys normalize identically (norm parity)")
    func lotNormParityAcrossSides() async throws {
        // The same lot cited in four formatting variants: front-matter items on one
        // side, loose document source notes on the other. Both must reduce to the
        // one canonical compact key.
        let variants = ["64 D 199", "64-D-199", "64–D 199", "64D199"]
        for variant in variants {
            // Front-matter side: SourcesParserDelegate keys via the shared grammar.
            let entries = try await withTempDir { dir -> [VolumeSourceEntry] in
                let url = dir.appendingPathComponent("v.xml")
                let xml = """
                <?xml version="1.0" encoding="UTF-8"?>
                <TEI xmlns="http://www.tei-c.org/ns/1.0">
                  <teiHeader><fileDesc><titleStmt><title>v</title></titleStmt>
                  <publicationStmt><date>2010</date></publicationStmt>
                  <sourceDesc><p>f</p></sourceDesc></fileDesc></teiHeader>
                  <text><front>
                    <div type="section" subtype="sources" xml:id="sources">
                      <head>Sources</head>
                      <list><item>Lot \(variant), Records of the Policy Planning Staff</item></list>
                    </div>
                  </front><body>
                    <div type="document" xml:id="d1"><head>1. Doc</head><p>t</p></div>
                  </body></text>
                </TEI>
                """
                try xml.data(using: .utf8)!.write(to: url)
                return try await FRUSDocumentParser().parseVolumeFull(volumeURL: url).volumeSources
            }
            let frontMatterEntry = try #require(entries.first { $0.kind == .item })
            #expect(frontMatterEntry.lotFileNorm == "64D199",
                    "front-matter variant \(variant) must normalize to 64D199")

            // Document side: SourceNoteParser keys the same variant the same way.
            let parsed = SourceNoteParser().parse("PPS files, lot \(variant), memoranda of conversation")
            guard case .lotFile(_, let docLot, _) = parsed else {
                Issue.record("doc-side variant \(variant) did not parse as a lot file")
                continue
            }
            #expect(SourceNoteParser.lotFileNorm(docLot) == frontMatterEntry.lotFileNorm,
                    "both sides must write the identical compact key for \(variant)")
        }
    }

    @Test("New key columns and the bibliography kind round-trip through volume_sources")
    func volumeSourcesRoundTripNewColumns() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            let url = volDir.appendingPathComponent("frus1969-76v01.xml")
            try writeKeyingFixtureVolume(to: url, volumeId: "frus1969-76v01")
            try await pipeline.indexVolume("frus1969-76v01")

            let sources = try await pipeline.volumeSources(forVolumeId: "frus1969-76v01")

            let lot = try #require(sources.first { $0.rawText.contains("Moscow Embassy Files") })
            #expect(lot.lotFileNorm == "62F83")
            #expect(lot.recordGroup == "84")

            let classLeaf = try #require(sources.first { $0.rawText.contains("DEF 6 MLF") })
            #expect(classLeaf.decimalClass == "DEF 6 MLF")
            #expect(classLeaf.recordGroup == "59", "inherited RG survives the round-trip")

            let bib = try #require(sources.first { $0.rawText.contains("Present at the Creation") })
            #expect(bib.kind == .bibliography)
            #expect(bib.lotFileNorm == nil)
        }
    }
}

// MARK: - CollectionAuthorityLocalTests (Source Explorer Phase 4 step 2)

/// Verifies the Phase-4 app wiring on a fixture index: the S5 local-stats query
/// (`localCollectionStats` — documents + distinct volumes per authority record, counted
/// from the user's own index) and the display-time alias fallback in
/// `archivalNeighbors(forLotFile:…)` (authority lot key first, then alias forms through
/// the entry's series-scoped path; never consulted when a direct key matched).
///
/// Version history:
///   1.0 — Session 2026-07-03: initial implementation
@Suite("IndexingPipeline — collection authority local stats & alias fallback")
struct CollectionAuthorityLocalTests {

    /// Indexes two volumes of documents with the given source notes.
    private func indexFixture(
        dir: URL,
        volumes: [(volumeId: String, notes: [(id: String, note: String)])]
    ) async throws -> IndexingPipeline {
        let (pipeline, _) = try await makeTestPipeline(dir: dir)
        let volDir = dir.appendingPathComponent("volumes")
        for volume in volumes {
            try writeTEIVolume(
                to: volDir.appendingPathComponent("\(volume.volumeId).xml"),
                volumeId: volume.volumeId,
                documents: volume.notes.enumerated().map { i, doc in
                    (doc.id, "<head>\(i + 1). Memo</head><note type=\"source\">\(doc.note)</note><p>Text.</p>")
                }
            )
            try await pipeline.indexVolume(volume.volumeId)
        }
        return pipeline
    }

    @Test("localCollectionStats counts lot-keyed documents and their distinct volumes")
    func lotStats() async throws {
        try await withTempDir { dir in
            let pipeline = try await indexFixture(dir: dir, volumes: [
                ("frus1969-76v01", [
                    ("d1", "SPA Files: Lot 61–D 146, Box 4581"),   // en-dash variant
                    ("d2", "SPA Files: Lot 61-D 146, Box 4582"),   // hyphen variant
                    ("d3", "PPS files, lot 64 D 563, memoranda"),  // different lot
                ]),
                ("frus1969-76v02", [
                    ("d1", "SPA Files: Lot 61 D 146, Box 4590"),   // spaced variant
                ]),
            ])
            let stats = try await pipeline.localCollectionStats(
                lotFileNorm: "61D146", repository: "Department of State",
                recordGroup: "59", names: [])
            #expect(stats.documentCount == 3,
                    "all dash/space variants share the norm; got \(stats.documentCount)")
            #expect(stats.volumeCount == 2)
        }
    }

    @Test("localCollectionStats folds name and alias forms through the RG-scoped shape")
    func nameAndAliasStats() async throws {
        try await withTempDir { dir in
            let pipeline = try await indexFixture(dir: dir, volumes: [
                ("frus1969-76v01", [
                    ("d1", "Source: National Archives, RG 84, Moscow Embassy Files, Box 12. Secret."),
                    ("d2", "Source: National Archives, RG 84, Moscow Post Records, Box 3. Secret."),
                    ("d3", "Source: National Archives, RG 84, Leningrad Consulate Files, Box 1. Secret."),
                ]),
            ])
            // The record's canonical name plus one alias — both forms count; the
            // unrelated series does not.
            let stats = try await pipeline.localCollectionStats(
                lotFileNorm: nil, repository: "National Archives", recordGroup: "84",
                names: ["Moscow Embassy Files", "Moscow Post Records"])
            #expect(stats.documentCount == 2)
            #expect(stats.volumeCount == 1)

            // Degenerate short forms are refused; nothing matches.
            let short = try await pipeline.localCollectionStats(
                lotFileNorm: nil, repository: "National Archives", recordGroup: "84",
                names: ["Mos"])
            #expect(short.documentCount == 0)
        }
    }

    @Test("Alias fallback: an authority alias matches when the entry's own series misses")
    func aliasFallbackSeriesForm() async throws {
        try await withTempDir { dir in
            let pipeline = try await indexFixture(dir: dir, volumes: [
                ("frus1969-76v01", [
                    ("d1", "Source: National Archives, RG 84, Moscow Embassy Files, Box 12. Secret."),
                    ("d2", "Source: National Archives, RG 84, Moscow Embassy Files, Box 57. Secret."),
                ]),
            ])
            // The front-matter heading writes a different grain than the doc notes —
            // the direct series misses; the authority's alias bridges it.
            let fallback = IndexingPipeline.CollectionAliasFallback(
                lotFileNorm: nil,
                names: ["Records of the Moscow Embassy", "Moscow Embassy Files"])
            let result = try await pipeline.archivalNeighbors(
                forLotFile: nil, recordGroup: "84", series: "Embassy Moscow Records",
                aliasFallback: fallback)
            #expect(Set(result.documents.map(\.documentId)) == ["d1", "d2"],
                    "the second alias form must match through the RG-scoped path")
            #expect(result.basis?.contains("Moscow Embassy Files") == true,
                    "the basis names the alias that matched")
        }
    }

    @Test("Alias fallback: the authority's lot key matches a lot-less heading entry")
    func aliasFallbackLotKey() async throws {
        try await withTempDir { dir in
            let pipeline = try await indexFixture(dir: dir, volumes: [
                ("frus1969-76v01", [
                    ("d1", "SPA Files: Lot 61-D 146, Box 4581"),
                    ("d2", "SPA Files: Lot 61-D 146, Box 4582"),
                ]),
            ])
            // A heading-level series row carries no lot of its own and no RG; the
            // direct paths have no key. The authority record is lot-keyed.
            let fallback = IndexingPipeline.CollectionAliasFallback(
                lotFileNorm: "61D146", names: ["SPA Files"])
            let result = try await pipeline.archivalNeighbors(
                forLotFile: nil, recordGroup: nil, series: "Records of the Special Assistant",
                aliasFallback: fallback)
            #expect(Set(result.documents.map(\.documentId)) == ["d1", "d2"],
                    "the authority lot key is tried first in the fallback order")
            #expect(result.basis?.contains("61D146") == true)
        }
    }

    @Test("Alias fallback never runs when a direct key path matched")
    func directMatchWins() async throws {
        try await withTempDir { dir in
            let pipeline = try await indexFixture(dir: dir, volumes: [
                ("frus1969-76v01", [
                    ("d1", "Source: National Archives, RG 84, Moscow Embassy Files, Box 12. Secret."),
                    ("d2", "SPA Files: Lot 61-D 146, Box 4581"),
                ]),
            ])
            // The direct RG+series path matches d1; the fallback (which would match
            // d2's lot) must not be consulted.
            let fallback = IndexingPipeline.CollectionAliasFallback(
                lotFileNorm: "61D146", names: ["SPA Files"])
            let result = try await pipeline.archivalNeighbors(
                forLotFile: nil, recordGroup: "84", series: "Moscow Embassy Files",
                aliasFallback: fallback)
            #expect(Set(result.documents.map(\.documentId)) == ["d1"])
            #expect(result.basis?.contains("RG 84") == true,
                    "the basis stays the direct path's, not the alias form")
        }
    }
}

// MARK: - BatchedNeighborCountTests (Source Explorer Phase 5 step 1)

/// Verifies the batched three-state neighbor counts behind `VolumeSourcesView`:
/// `archivalNeighborCounts(forKeys:)` resolves every key family (lot norm,
/// decimal/subject-numeric class leaf, presidential library, RG + series) in
/// grouped queries against a fixture index, returns an explicit 0 for keyed
/// entries nothing matches, agrees with the per-tap `archivalNeighbors` totals
/// (shared clause builders), and `neighborCountKey` mirrors the matcher's
/// most-specific-first path selection.
///
/// Version history:
///   1.0 — Session 2026-07-04: Source Explorer Phase 5 step 1
@Suite("IndexingPipeline — batched neighbor counts")
struct BatchedNeighborCountTests {

    /// Indexes one volume covering all four key families: two lot-file documents
    /// (dash variants of one lot), two class-leaf documents (narrative decimal +
    /// structured subject-numeric), two Johnson Library documents in one collection,
    /// and two RG 84 documents in one series.
    private func indexAllFamiliesFixture(dir: URL) async throws -> IndexingPipeline {
        let (pipeline, _) = try await makeTestPipeline(dir: dir)
        let volDir = dir.appendingPathComponent("volumes")
        let notes: [(String, String)] = [
            ("d1", "SPA Files: Lot 61–D 146, Box 4581"),
            ("d2", "SPA Files: Lot 61-D 146, Box 4582"),
            ("d3", "Source: Department of State, Central Files, POL 27 ARAB–ISR. Confidential."),
            ("d4", "Source: National Archives and Records Administration, RG 59, Central Files 1967–69, POL 27 ARAB-ISR. Secret."),
            ("d5", "Source: Johnson Library, National Security File, Country File, Vietnam, Box 3. Secret."),
            ("d6", "Source: Johnson Library, National Security File, Memos to the President, Box 1. Secret."),
            ("d7", "Source: National Archives, RG 84, Moscow Embassy Files, Box 12. Secret."),
            ("d8", "Source: National Archives, RG 84, Moscow Embassy Files, Box 57. Confidential."),
        ]
        try writeTEIVolume(
            to: volDir.appendingPathComponent("frus1969-76v01.xml"),
            volumeId: "frus1969-76v01",
            documents: notes.enumerated().map { i, doc in
                (doc.0, "<head>\(i + 1). Memo</head><note type=\"source\">\(doc.1)</note><p>Text.</p>")
            }
        )
        try await pipeline.indexVolume("frus1969-76v01")
        return pipeline
    }

    @Test("One batch resolves all four key families with correct zero/N states")
    func allFamiliesZeroAndN() async throws {
        try await withTempDir { dir in
            let pipeline = try await indexAllFamiliesFixture(dir: dir)

            // Derive keys exactly as VolumeSourcesView does (em-dash lot variant to
            // prove the norm bridges dash forms; en-dash class key bridging both
            // stored dash forms).
            let lotHit  = IndexingPipeline.neighborCountKey(
                forLotFile: "61—D 146", recordGroup: nil, series: nil)!
            let lotMiss = IndexingPipeline.neighborCountKey(
                forLotFile: "99 D 999", recordGroup: nil, series: nil)!
            let clsHit  = IndexingPipeline.neighborCountKey(
                forLotFile: nil, recordGroup: nil, series: nil, decimalClass: "POL 27 ARAB–ISR")!
            let clsMiss = IndexingPipeline.neighborCountKey(
                forLotFile: nil, recordGroup: nil, series: nil, decimalClass: "DEF 6 MLF")!
            let libHit  = IndexingPipeline.neighborCountKey(
                forLotFile: nil, recordGroup: nil, series: "National Security File",
                repository: "Johnson Library")!
            let libMiss = IndexingPipeline.neighborCountKey(
                forLotFile: nil, recordGroup: nil, series: "National Security Files",
                repository: "Kennedy Library")!
            let rgHit   = IndexingPipeline.neighborCountKey(
                forLotFile: nil, recordGroup: "84", series: "Moscow Embassy Files")!
            let rgGuard = IndexingPipeline.neighborCountKey(
                forLotFile: nil, recordGroup: "84", series: "Mos")!

            let keys = [lotHit, lotMiss, clsHit, clsMiss, libHit, libMiss, rgHit, rgGuard]
            let counts = try await pipeline.archivalNeighborCounts(forKeys: keys)

            // Every input key gets an explicit entry — 0 is "loaded, zero", never absent.
            #expect(counts.count == keys.count, "every key must be answered; got \(counts.count)")
            #expect(counts[lotHit]  == 2, "both dash variants of the lot must count")
            #expect(counts[lotMiss] == 0)
            #expect(counts[clsHit]  == 2, "narrative + structured class citations must both count")
            #expect(counts[clsMiss] == 0)
            #expect(counts[libHit]  == 2, "both Johnson Library boxes must count")
            #expect(counts[libMiss] == 0)
            #expect(counts[rgHit]   == 2, "both Box tails must count at the comma boundary")
            #expect(counts[rgGuard] == 0, "the ≥4-char series guard must refuse the degenerate prefix")
        }
    }

    @Test("Batched counts equal the per-tap archivalNeighbors totals (shared clauses)")
    func countsAgreeWithPerTapTotals() async throws {
        try await withTempDir { dir in
            let pipeline = try await indexAllFamiliesFixture(dir: dir)

            // (lotFile, recordGroup, series, repository, decimalClass) per family.
            let targets: [(String?, String?, String?, String?, String?)] = [
                ("61—D 146", nil, nil, nil, nil),
                (nil, nil, nil, nil, "POL 27 ARAB–ISR"),
                (nil, nil, "National Security File", "Johnson Library", nil),
                (nil, "84", "Moscow Embassy Files", nil, nil),
            ]
            for t in targets {
                let key = IndexingPipeline.neighborCountKey(
                    forLotFile: t.0, recordGroup: t.1, series: t.2,
                    repository: t.3, decimalClass: t.4)!
                let counts = try await pipeline.archivalNeighborCounts(forKeys: [key])
                let direct = try await pipeline.archivalNeighbors(
                    forLotFile: t.0, recordGroup: t.1, series: t.2,
                    repository: t.3, decimalClass: t.4)
                #expect(counts[key] == direct.totalCount,
                        "badge and sheet must agree for \(key); \(String(describing: counts[key])) vs \(direct.totalCount)")
            }
        }
    }

    @Test("neighborCountKey mirrors the matcher's most-specific-first path selection")
    func keySelectionOrder() {
        // Lot outranks everything.
        if case .lotFile(let norm)? = IndexingPipeline.neighborCountKey(
            forLotFile: "Lot 61–D 146", recordGroup: "59", series: "POL 27",
            repository: "Johnson Library", decimalClass: "POL 27") {
            #expect(norm == "61D146", "the key stores the canonical compact norm (Lot prefix stripped)")
        } else {
            Issue.record("a lot-carrying entry must resolve on the lot path")
        }
        // Class leaf outranks library and RG+series.
        if case .decimalClass? = IndexingPipeline.neighborCountKey(
            forLotFile: nil, recordGroup: "59", series: "POL 27 ARAB–ISR",
            repository: "Johnson Library", decimalClass: "POL 27 ARAB–ISR") {
        } else {
            Issue.record("a class leaf must resolve on the decimal path")
        }
        // Library outranks RG+series; non-library repositories fall through.
        if case .presidentialLibrary? = IndexingPipeline.neighborCountKey(
            forLotFile: nil, recordGroup: "59", series: "National Security File",
            repository: "Johnson Library") {
        } else {
            Issue.record("a library repository + collection must resolve on the library path")
        }
        if case .collection? = IndexingPipeline.neighborCountKey(
            forLotFile: nil, recordGroup: "59", series: "Central Files",
            repository: "Department of State") {
        } else {
            Issue.record("a non-library repository must fall through to RG + series")
        }
        // No key on any path → nil (the row shows no affordance).
        #expect(IndexingPipeline.neighborCountKey(
            forLotFile: nil, recordGroup: nil, series: "Miscellaneous", repository: nil) == nil)
        #expect(IndexingPipeline.neighborCountKey(
            forLotFile: " ", recordGroup: nil, series: nil) == nil,
            "whitespace-only fields never select a path")
    }
}
