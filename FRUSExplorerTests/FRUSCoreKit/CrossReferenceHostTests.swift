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

// MARK: - CrossReferenceHostTests

/// The cross-reference store as a host outside the app opens it: over an index copied as an export is
/// made, read-only and immutable, with the host's own copies of the two bundled files, or with neither;
/// and the two files read where the store uses them, never when it opens.
///
/// The fixture is the Long Telegram (`frus1946v06` d475), a document of its volume citing it (d710), one
/// citing that (d800), and the telegram's note's reference to p. 531 of 1943 vol. III, which the index
/// leaves on that volume (#1799). The bundled citation index adds the telegram's citers from other
/// volumes.
///
/// Version history:
///   1.0 — 2026-11-10 (FRUS Explorer Light, S23b): initial implementation, when the store moved into
///          FRUSCoreKit and took the two files from its host
@Suite("FRUSCoreKit — the cross-reference store, as a host opens it")
@MainActor
struct CrossReferenceHostTests {

    /// How often a provider was read.
    final class Reads: @unchecked Sendable {
        private let lock = NSLock()
        private var value = 0
        var count: Int { lock.lock(); defer { lock.unlock() }; return value }
        func note() { lock.lock(); value += 1; lock.unlock() }
    }

    private func withTempDir<T>(_ body: (URL) async throws -> T) async throws -> T {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSCrossRefHost-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        return try await body(dir)
    }

    /// The fixture's index, in the pipeline's schema, built read-write.
    private func buildIndex(in dir: URL) throws -> URL {
        let built = dir.appendingPathComponent("built.sqlite")
        let volumes = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        do {
            let fts5 = try FTS5Store(databaseURL: built)
            _ = try IndexingPipeline(fts5Store: fts5, databaseURL: built, volumesDirectory: volumes, concurrencyLimit: 1)
        }
        var db: OpaquePointer?
        try #require(sqlite3_open_v2(built.path, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK)
        defer { sqlite3_close_v2(db) }
        let documents = """
            INSERT INTO document_cache (volume_id, document_id, document_number, header, dateline, source_note,
                                        body_text, subject_tag_ids, user_tag_ids, summary_text, note_text)
            VALUES (?, ?, ?, ?, NULL, NULL, '', NULL, NULL, NULL, NULL)
            """
        for sql in [
            documents.replacingOccurrences(of: "VALUES (?, ?, ?, ?,", with:
                "VALUES ('frus1946v06', 'd475', '475', 'The Chargé in the Soviet Union (Kennan) to the Secretary of State',"),
            documents.replacingOccurrences(of: "VALUES (?, ?, ?, ?,", with:
                "VALUES ('frus1946v06', 'd710', '710', 'The Ambassador in the Soviet Union to the Secretary of State',"),
            documents.replacingOccurrences(of: "VALUES (?, ?, ?, ?,", with:
                "VALUES ('frus1946v06', 'd800', '800', 'Memorandum by the Secretary of State',"),
            "INSERT INTO document_dates (volume_id, document_id, date_iso) VALUES ('frus1946v06', 'd475', '1946-02-22')",
            "INSERT INTO document_dates (volume_id, document_id, date_iso) VALUES ('frus1946v06', 'd710', '1946-03-01')",
            "INSERT INTO document_dates (volume_id, document_id, date_iso) VALUES ('frus1946v06', 'd800', '1946-03-05')",
            """
            INSERT INTO cross_references (source_volume_id, source_document_id, target_volume_id, target_document_id,
                                          reference_type, context)
            VALUES ('frus1946v06', 'd710', NULL, 'd475', 'footnote', 'See the telegram.'),
                   ('frus1946v06', 'd800', NULL, 'd710', 'footnote', 'See the Ambassador''s telegram.'),
                   ('frus1946v06', 'd475', 'frus1943v03', 'pg_531', 'footnote', 'see Foreign Relations, 1943, vol. III, p. 531.')
            """,
        ] {
            try #require(sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK, "fixture: \(String(cString: sqlite3_errmsg(db)))")
        }
        return built
    }

    /// Copies the index at `built` page for page with SQLite's backup API into a folder of its own and
    /// takes the copy out of write-ahead-log mode, as an export is made.
    private func exportCopy(of built: URL, in dir: URL) throws -> URL {
        let served = dir.appendingPathComponent("served", isDirectory: true)
        try FileManager.default.createDirectory(at: served, withIntermediateDirectories: true)
        let copy = served.appendingPathComponent("frus.db")
        var source: OpaquePointer?, target: OpaquePointer?
        try #require(sqlite3_open_v2(built.path, &source, SQLITE_OPEN_READONLY, nil) == SQLITE_OK)
        try #require(sqlite3_open_v2(copy.path, &target, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK)
        let backup = try #require(sqlite3_backup_init(target, "main", source, "main"))
        #expect(sqlite3_backup_step(backup, -1) == SQLITE_DONE)
        sqlite3_backup_finish(backup)
        #expect(sqlite3_exec(target, "PRAGMA journal_mode=DELETE", nil, nil, nil) == SQLITE_OK)
        #expect(sqlite3_close(target) == SQLITE_OK && sqlite3_close(source) == SQLITE_OK)
        try? FileManager.default.removeItem(at: served.appendingPathComponent("frus.db-shm"))
        return copy
    }

    /// What a store answers about the telegram, as text: its graph at one and two hops, every node's
    /// title and dates, its related documents and its connection counts.
    private func answers(_ store: CrossReferenceStore) async throws -> [String] {
        var out: [String] = []
        for degree in [1, 2] {
            let graph = try await store.expandedGraph(forDocumentId: "d475", volumeId: "frus1946v06", degree: degree,
                                                      downloadedVolumeIds: ["frus1946v06"])
            out.append("degree \(degree): in \(graph.inboundEdges.map { "\($0.sourceVolumeId)/\($0.sourceDocumentId)" }.sorted())"
                       + " out \(graph.outboundEdges.map { "\($0.targetVolumeId)/\($0.targetDocumentId)" }.sorted())"
                       + " extended \(graph.extendedEdges.count) undownloaded \(graph.undownloadedCitingVolumeIds)")
            for (key, node) in graph.nodeMetadata.sorted(by: { $0.key < $1.key }) {
                out.append("\(key): \(node.header ?? "-") | \(node.dateISO ?? "-") | \(node.dateISOMax ?? "-") | "
                           + "\(node.dating.map { "\($0)" } ?? "-") | \(node.citedPage.map(String.init) ?? "-")")
            }
        }
        let related = try await store.relatedByCitation(forDocumentId: "d475", volumeId: "frus1946v06", limit: 10)
        out.append("related: \(related.map { "\($0.volumeId)/\($0.documentId) \($0.citationCount)" })")
        let counts = try await store.connectionCounts(forKeys: [(volumeId: "frus1946v06", documentId: "d475"),
                                                                (volumeId: "frus1946v06", documentId: "d710")])
        out.append("counts: \(counts.sorted { $0.key < $1.key })")
        return out
    }

    @Test("Opened immutable with a host's own copies of the two bundled files, the store answers as the app's open does")
    func immutableOpenAnswersAsTheAppsOpen() async throws {
        try await withTempDir { dir in
            let built = try buildIndex(in: dir)
            let catalogue = try crossReferenceTestCatalogue()
            #expect(ResolvedEdgeIndexStore.shared != nil && CitedPageMapStore.shared != nil,
                    "the app's two bundled files, or the package's copies of them, must decode")
            let appStore = try CrossReferenceStore(databaseURL: built, volumes: catalogue)
            #expect(!appStore.isImmutable)
            let expected = try await answers(appStore)
            // The bundled index adds the telegram's citers from volumes the fixture does not hold.
            #expect(expected.contains { $0.hasPrefix("degree 1:") && !$0.hasSuffix("undownloaded []") }, "\(expected)")
            #expect(expected.contains("frus1943v03/pg_531: 1943, vol. III, p. 531 | 1942-05-30 | 1944-03-24 | volume | 531"),
                    "\(expected)")

            let copy = try exportCopy(of: built, in: dir)
            let edges = try ResolvedEdgeIndex(contentsOf: sourceExplorerShippedFile("resolved-edge-index"))
            let pages = try JSONDecoder().decode(CitedPageMap.self,
                                                 from: Data(contentsOf: sourceExplorerShippedFile("cited-page-map")))
            let host = try CrossReferenceStore(readingDatabaseAt: copy, volumes: catalogue,
                                               resolvedEdgeIndex: edges, citedPageMap: pages)
            #expect(host.isImmutable)
            #expect(try await answers(host) == expected)
        }
    }

    @Test("A host with neither bundled file gets the local table's citations alone, and a page dated by its volume")
    func withNeitherFile() async throws {
        try await withTempDir { dir in
            let copy = try exportCopy(of: try buildIndex(in: dir), in: dir)
            let host = try CrossReferenceStore(readingDatabaseAt: copy, volumes: try crossReferenceTestCatalogue(),
                                               resolvedEdgeIndex: nil, citedPageMap: nil)
            let graph = try await host.graph(forDocumentId: "d475", volumeId: "frus1946v06",
                                             downloadedVolumeIds: ["frus1946v06"])
            #expect(graph.inboundEdges.map { "\($0.sourceVolumeId)/\($0.sourceDocumentId)" } == ["frus1946v06/d710"])
            #expect(graph.undownloadedCitingVolumeIds.isEmpty && !graph.hasUndownloadedSources)
            let page = try #require(graph.nodeMetadata["frus1943v03/pg_531"])
            #expect(page.dating == .volume && page.dateISO == "1942-05-30" && page.dateISOMax == "1944-03-24")
            #expect(page.header == "1943, vol. III, p. 531" && page.citedPage == 531)
        }
    }

    @Test("The store reads the two files where it uses them, never when it opens")
    func filesAreReadWhereUsed() async throws {
        try await withTempDir { dir in
            let built = try buildIndex(in: dir)
            let edgeReads = Reads(), pageReads = Reads()
            let edges = try ResolvedEdgeIndex(contentsOf: sourceExplorerShippedFile("resolved-edge-index"))
            let pages = try JSONDecoder().decode(CitedPageMap.self,
                                                 from: Data(contentsOf: sourceExplorerShippedFile("cited-page-map")))
            @Sendable func index() -> ResolvedEdgeIndex? { edgeReads.note(); return edges }
            @Sendable func map() -> CitedPageMap? { pageReads.note(); return pages }
            let store = try CrossReferenceStore(databaseURL: built, volumes: try crossReferenceTestCatalogue(),
                                                resolvedEdgeIndexProvider: index, citedPageMapProvider: map)
            #expect(edgeReads.count == 0 && pageReads.count == 0, "the store read a file when it opened")

            _ = try await store.documentTitleFacts(for: [(volumeId: "frus1946v06", documentId: "d475")])
            _ = try await store.topDocumentsByInDegree(limit: 5)
            _ = try await store.relatedByCitation(forDocumentId: "d475", volumeId: "frus1946v06", limit: 5)
            #expect(edgeReads.count == 0 && pageReads.count == 0, "a query that needs neither file read one")

            let graph = try await store.graph(forDocumentId: "d475", volumeId: "frus1946v06",
                                              downloadedVolumeIds: ["frus1946v06"])
            #expect(edgeReads.count == 1, "a graph reads the citation index once")
            let endpoints = graph.nodeMetadata.keys.map { key -> (volumeId: String, documentId: String) in
                let parts = key.split(separator: "/", maxSplits: 1).map(String.init)
                return (volumeId: parts[0], documentId: parts[1])
            }
            let held = try await store.indexedDocumentKeys(for: endpoints)
            #expect(held == ["frus1946v06/d475", "frus1946v06/d710"])
            #expect(pageReads.count == graph.nodeMetadata.count - held.count && pageReads.count > 1, """
                The page map is read once for each node the index holds no row for, where the store dated \
                such a node by it: \(pageReads.count) reads for \(graph.nodeMetadata.count - held.count) nodes.
                """)
        }
    }

    @Test("A host draws the graph the app draws: widened one hop, with its archival nodes, on the timeline")
    func aHostDrawsTheAppsGraph() async throws {
        try await withTempDir { dir in
            let copy = try exportCopy(of: try buildIndex(in: dir), in: dir)
            let pages = try JSONDecoder().decode(CitedPageMap.self,
                                                 from: Data(contentsOf: sourceExplorerShippedFile("cited-page-map")))
            // The local table alone, so the telegram's graph at one hop is a sparse star of two.
            let store = try CrossReferenceStore(readingDatabaseAt: copy, volumes: try crossReferenceTestCatalogue(),
                                                resolvedEdgeIndex: nil, citedPageMap: pages)
            let central = "frus1946v06/d475"
            let downloaded: Set<String> = ["frus1946v06"]
            let star = try await store.expandedGraph(forDocumentId: "d475", volumeId: "frus1946v06", degree: 1,
                                                     downloadedVolumeIds: downloaded)
            #expect(star.edgeCount == 2)
            #expect(CrossReferenceGraphDisplay.widensSparseGraph(loadedAtDegree: 1, edgeCount: star.edgeCount))
            #expect(!CrossReferenceGraphDisplay.widensSparseGraph(loadedAtDegree: 2, edgeCount: star.edgeCount))
            #expect(!CrossReferenceGraphDisplay.widensSparseGraph(loadedAtDegree: 1, edgeCount: 0)
                    && !CrossReferenceGraphDisplay.widensSparseGraph(loadedAtDegree: 1, edgeCount: 4))
            let widened = try await store.expandedGraph(forDocumentId: "d475", volumeId: "frus1946v06", degree: 2,
                                                        downloadedVolumeIds: downloaded)
            #expect(CrossReferenceGraphDisplay.keepsWidenedGraph(widened, over: star), "d800's reference to d710 is the hop")
            #expect(!CrossReferenceGraphDisplay.keepsWidenedGraph(star, over: star))

            let built = CrossReferenceGraphDisplay.buildDisplayNodesAndEdges(
                graph: widened, centralKey: central, expandedClusterKeys: [], downloadedVolumeIds: downloaded)
            let extended = try #require(built.nodes.first { $0.id == "frus1946v06/d800" })
            if case .extended = extended.kind {} else { Issue.record("d800 is \(extended.kind), not two hops out") }

            // The archival pointers: a lot the authority holds, twice, a central-file class, twice, a lot it
            // does not hold, and a pointer from a document that is not on the canvas.
            let authority = try CollectionAuthorityIndex(contentsOf: sourceExplorerShippedFile("collection-authority"))
            func pointer(lot: String? = nil, decimalClass: String? = nil, _ ordinal: Int) -> ExternalCitation {
                ExternalCitation(anchor: decimalClass == nil ? "lotFile" : "centralFileClass",
                                 repository: "Department of State", collection: nil, lotFile: lot, lotFileNorm: lot,
                                 fileId: nil, inherited: false, rawText: "Not printed.", noteOrdinal: ordinal,
                                 decimalClass: decimalClass)
            }
            let rows: [String: [ExternalCitation]] = [
                central: [pointer(lot: "00D239", 0), pointer(lot: "00D239", 1), pointer(decimalClass: "861.00", 2),
                          pointer(decimalClass: "861.00", 3), pointer(lot: "99Z999", 4)],
                "frus1946v06/dOffTheCanvas": [pointer(lot: "00D239", 0)],
            ]
            let units = CrossReferenceGraphDisplay.unitNodes(rowsByDocument: rows, authority: authority)
            #expect(units[central]?.map(\.id) == ["unit/frus1946v06/d475/lot:00D239", "class/frus1946v06/d475/861.00"],
                    "each unit and class once, and nothing for the lot no record holds: \(units[central]?.map(\.id) ?? [])")
            let unit = try #require(units[central]?.first)
            #expect(unit.unitCollectionId == "lot:00D239" && unit.isDownloaded && unit.terminatesWalk && unit.metadata == nil)
            let (nodes, edges) = CrossReferenceGraphDisplay.attachingUnits(units, to: built.nodes, edges: built.edges)
            #expect(nodes.count == built.nodes.count + 2, "a document off the canvas brings no unit")
            #expect(edges.contains { $0.source == central && $0.target == unit.id && $0.referenceType == .footnote })

            // The timeline: the page before the telegram, its citers after it, the archival nodes parked.
            let values = CrossReferenceGraphDisplay.buildDateValues(for: nodes)
            #expect(CrossReferenceGraphDisplay.isTimelineEligible(centralKey: central, dateValues: values, nodes: nodes))
            #expect(!CrossReferenceGraphDisplay.isTimelineEligible(centralKey: "frus1946v06/dUndated", dateValues: values,
                                                                   nodes: nodes))
            let clustered = CrossReferenceGraphDisplay.dateClusteredDisplay(
                nodes: nodes, edges: edges, dateValues: values, canvasWidth: 1055, expandedKeys: [])
            let layout = CrossReferenceGraphDisplay.timelineLayout(
                nodes: clustered.nodes, dateValues: values.merging(clustered.clusterDateValues) { base, _ in base },
                centralKey: central, canvasWidth: 1055, canvasHeight: 861)
            #expect(layout.positions.count == clustered.nodes.count && layout.hasParkedNodes && !layout.ticks.isEmpty)
            func x(_ key: String) -> Double { layout.positions[key]?.x ?? .nan }
            #expect(x("frus1943v03/pg_531") < x(central) && x(central) < x("frus1946v06/d710")
                    && x("frus1946v06/d710") < x("frus1946v06/d800"), "\(layout.positions)")
        }
    }
}
