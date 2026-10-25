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

// MARK: - SearchStatementTextTests

/// The statements the app's search runs on its user half, held to their text and binds byte for byte.
///
/// FRUS Explorer Light's S17a lets a search read its user half, the notes and summaries its words
/// match, the tags its filter, its rows and its tag counts read, and the texts its exact-word filter
/// reads among them, from a store a host attaches (`SearchUserSource`). The app passes no source, and
/// reads the index's own `user_content` and `document_cache` columns as it did. This suite runs every
/// route to those statements over an index of the app's, through the app's calls, records each
/// statement the pipeline ran as SQLite expanded it with its bound values
/// (`IndexingPipeline.setStatementTraceForTesting(_:)`), and pins the record by SHA-256 and count.
///
/// The pin was taken by running this file, with the trace hook alone copied in, against `v2` at
/// `9fa4375d`, the tree before S17a: so it says the app's statements are the text and binds they were.
/// A change to one of them fails it, by design, as `ReaderPageTests`' pins fail on a change to the
/// page: re-take the pin from the failure, which writes the statements to a file to compare, and say
/// why above it.
///
/// Version history:
///   1.0 — FRUS Explorer Light S17a: initial implementation
@Suite("FRUSCoreKit — the app's search statements on its user half, by their text")
struct SearchStatementTextTests {

    static let volume = "frus1970v01"
    static let tagA = "AAAAAAAA-0000-4000-8000-000000000001"
    static let tagB = "BBBBBBBB-0000-4000-8000-000000000002"

    /// The searches every route runs: each scope of the user half alone and with the corpus, a refusal,
    /// the exact-word filter over each, the tag filter alone and beside a document gate, every other
    /// filter the clause renders, and the filter-only path a person, a rollup or a subject runs.
    static let searches: [SearchParameters] = {
        func search(_ keywords: String?, documents: Bool = true, summaries: Bool = true, notes: Bool = true,
                    _ edit: (inout SearchParameters) -> Void = { _ in }) -> SearchParameters {
            var parameters = SearchParameters(keywords: keywords, includeDocumentText: documents,
                                              includeSummaries: summaries, includeNotes: notes)
            edit(&parameters)
            return parameters
        }
        let key = { (document: String) in "\(volume)/\(document)" }
        return [
            search("telegram"),
            search("telegram", summaries: false, notes: false),
            search("zanzibar", documents: false),
            search("zanzibar", documents: false, summaries: false),
            search("quixotic", documents: false, notes: false),
            search("telegram OR quixotic", notes: false),
            search("=Telegram"),
            search("=Zanzibar", documents: false),
            search("=Zanzibar =cable", summaries: false),
            search("berlin") { $0.userTagIds = [tagA] },
            search("berlin") { $0.userTagIds = [tagA, tagB] },
            search("berlin", documents: false) { $0.userTagIds = [tagA.lowercased()] },
            search("berlin") { $0.documentIds = [key("d2"), key("d6"), key("d9")] },
            search("berlin") { $0.documentIds = [key("d2"), key("d6")]; $0.userTagIds = [tagA] },
            search("=Berlin") { $0.documentIds = [key("d2"), key("d4")] },
            search("berlin") { $0.documentIds = [] },
            search("talks") {
                $0.volumeIds = [volume]
                $0.dateRange = DateRange(earliest: "1960-01-01", latest: "1975-12-31")
                $0.yearKeys = ["1970"]
                $0.documentTypeFilter = .documentsOnly
                $0.includeFrontMatter = false
                $0.excludeDocumentIds = [key("d3")]
            },
            search(nil) { $0.personRef = "p1"; $0.userTagIds = [tagA] },
            search(nil) { $0.personRollupId = 7 },
            search(nil) { $0.subjectRef = "rec_none"; $0.subjectName = "None" },
            search("telegram") { $0.subjectBucketKey = "None/None" },
            search("-telegram"),
        ]
    }()

    /// Writes a volume of twelve documents: d1, d6 and d11 with "Telegram" in their heads, and d3,
    /// d6, d9 and d12 with "telegrams" in their text; every one on Berlin.
    static func writeVolume(in volumes: URL) throws {
        let documents = (1...12).map { n in
            "<div type=\"document\" xml:id=\"d\(n)\" n=\"\(n)\"><head>\(n). \(n % 5 == 1 ? "Telegram" : "Memorandum")</head>"
                + "<p>Text \(n) on Berlin and \(n % 3 == 0 ? "telegrams" : "talks").</p></div>"
        }.joined(separator: "\n")
        let xml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <TEI xmlns="http://www.tei-c.org/ns/1.0">
              <teiHeader><fileDesc><titleStmt><title>\(volume)</title></titleStmt>
              <publicationStmt><date>1970</date></publicationStmt>
              <sourceDesc><p>Test fixture</p></sourceDesc></fileDesc></teiHeader>
              <text><body><div type="compilation" xml:id="comp1">\(documents)</div></body></text>
            </TEI>
            """
        try Data(xml.utf8).write(to: volumes.appendingPathComponent("\(volume).xml"))
    }

    @Test("With no source passed, each statement a search, count, key set, facet match or tag count runs on the user half is the text and binds it was before S17a")
    func theAppsStatementsAreTheirText() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSStatementText-\(UUID().uuidString)", isDirectory: true)
        let volumes = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try Self.writeVolume(in: volumes)
        let database = dir.appendingPathComponent("index.db")
        let store = try FTS5Store(databaseURL: database)
        let pipeline = try IndexingPipeline(fts5Store: store, databaseURL: database, volumesDirectory: volumes,
                                            resources: .none, defaults: InMemoryIndexingStampStore())
        try await pipeline.indexVolume(Self.volume)
        // The user half as the app's writers keep it in the index.
        try await pipeline.updateNoteText(volumeId: Self.volume, documentId: "d2", bodyText: "Zanzibar cable on the Berlin talks")
        try await pipeline.updateSummaryText(volumeId: Self.volume, documentId: "d4", responseText: "A quixotic proposal about Berlin")
        try await pipeline.updateNoteText(volumeId: Self.volume, documentId: "d6", bodyText: "Telegram about Zanzibar")
        try await pipeline.updateUserTagIds(volumeId: Self.volume, documentId: "d2", userTagIds: "\(Self.tagA) \(Self.tagB)")
        try await pipeline.updateUserTagIds(volumeId: Self.volume, documentId: "d6", userTagIds: Self.tagA)
        let service = SearchService(fts5Store: store, pipeline: pipeline)
        let tags = [Self.tagA, Self.tagB, "CCCCCCCC-0000-4000-8000-000000000003"]
        let keys = [(volumeId: Self.volume, documentId: "d2"), (volumeId: Self.volume, documentId: "d6"),
                    (volumeId: Self.volume, documentId: "d40")]

        let trace = StatementTraceForTesting()
        await pipeline.setStatementTraceForTesting(trace)
        for parameters in Self.searches {
            _ = try? await service.searchCount(parameters: parameters)
            _ = try? await service.matchKeys(parameters: parameters)
            _ = try? await service.filterKeySet(parameters: parameters)
            _ = try? await service.resultSetFacets(parameters: parameters, request: FacetRequest(sections: []))
            guard let expressions = try? await service.matchExpressions(for: parameters) else { continue }
            let filters = await service.filtersForTesting(parameters)
            // The search's statement, with the expressions and filters `search(parameters:limit:offset:)`
            // passes it. The search's snippet pass is left out: it asks the vocabulary about each term in
            // the order of a `Set`, which is another in each process, and reads nothing of the user half.
            for (limit, offset) in [(20, 0), (5, 5)] {
                _ = try? await pipeline.searchDocuments(corpusMatch: expressions.corpus, userContentMatch: expressions.userContent,
                                                        filters: filters, limit: limit, offset: offset)
            }
            // The filter sheet's tag counts, by the app's route (`SearchViewModel.loadUserTagCounts`), and
            // the parity shapes the suites keep, which take the same match and filters.
            _ = try? await pipeline.userTagCounts(corpusMatch: expressions.corpus, userContentMatch: expressions.userContent,
                                                  filters: filters, tagIds: tags)
            _ = try? await pipeline.userTagCountsJoinedMaterializationForTesting(
                corpusMatch: expressions.corpus, userContentMatch: expressions.userContent, filters: filters, tagIds: tags)
            _ = try? await pipeline.resultSetFacetsJoinedMaterializationForTesting(
                corpusMatch: expressions.corpus, userContentMatch: expressions.userContent, filters: filters,
                request: FacetRequest(sections: []))
            _ = try? await pipeline.searchDocumentsSinglePhaseForTesting(
                corpusMatch: expressions.corpus, userContentMatch: expressions.userContent, filters: filters, limit: 20, offset: 0)
            _ = try? await pipeline.searchDocumentsGateByKeyForTesting(
                corpusMatch: expressions.corpus, userContentMatch: expressions.userContent, filters: filters, limit: 20, offset: 0)
            _ = try? await pipeline.searchDocumentsCountGateByKeyForTesting(
                corpusMatch: expressions.corpus, userContentMatch: expressions.userContent, filters: filters)
        }
        // A meaning search's routes: its tag counts over its keys, its rows, and the other readers of a
        // document's tags.
        _ = try await pipeline.userTagCounts(corpusMatch: nil, userContentMatch: nil, filters: SearchSQLFilters(),
                                             tagIds: tags, documentKeys: keys)
        _ = try await service.semanticResultRows(forKeys: keys)
        _ = try await pipeline.documentKeys(forUserTagId: Self.tagA)
        _ = try await pipeline.currentUserTagIds(volumeId: Self.volume, documentId: "d2")
        await pipeline.setStatementTraceForTesting(nil)

        let statements = trace.statements
        let text = statements.joined(separator: "\n")
        let digest = SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
        // Taken at `v2` 9fa4375d with the trace hook copied in, and nothing else changed: the property
        // `statementTrace`, `setStatementTraceForTesting(_:)`, the line in `auxPrepare` that notes each
        // statement prepared, and `StatementTraceForTesting`.
        let pinned = (count: 365, sha256: "c80c2976ba5d98412cea13e3254dfebcbdff44783f76be08ceb55af3c48a2fbb")
        if statements.count != pinned.count || digest != pinned.sha256 {
            let record = FileManager.default.temporaryDirectory
                .appendingPathComponent("SearchStatementText-\(digest.prefix(12)).txt")
            try? Data(text.utf8).write(to: record)
            Issue.record("""
                \(statements.count) statements, SHA-256 \(digest), where the pin is \(pinned.count) and \(pinned.sha256). \
                They are written to \(record.path), to compare with the same file from the tree the pin was taken at.
                """)
        }
        // Each route ran, so the pin holds what it says it holds.
        #expect(statements.contains { $0.contains("bm25(user_content)") && $0.contains("UNION ALL") })
        #expect(statements.contains { $0.hasPrefix("WITH tv(id) AS (VALUES") })
        #expect(statements.contains { $0.contains("frus_exact_word(dc.note_text,") })
        #expect(statements.contains { $0.contains("LIKE ('% ' || '\(Self.tagA.lowercased())' || ' %')") })
        #expect(statements.contains { $0.contains("WITH wanted(v, d) AS (VALUES") })
        #expect(statements.contains { $0.contains("FROM document_cache\nWHERE (' ' || COALESCE(user_tag_ids, '')") })
    }
}
