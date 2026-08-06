// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import PresidentialLibraryCatalogGeneratorCore

/// Pins the harvest's two load-bearing behaviours: reading the series→collection link out of the
/// **ancestry**, and refusing to write a short harvest.
///
/// Version history:
///   1.0 — Session 2026-08-06: #681
@Suite("Presidential library catalog harvest")
struct PresidentialLibraryCatalogTests {

    /// The finding the whole design rests on: a series does not carry `collectionIdentifier`,
    /// only `ancestors[].collectionIdentifier`. Reading the top level yields a catalogue of
    /// collections with no series under any of them — and it would look like a successful run.
    @Test("A series is linked to its collection through the ancestry")
    func seriesLinkComesFromAncestry() {
        let series: [String: Any] = [
            "naId": 7763260,
            "title": "Special Head of State Correspondence Files",
            "levelOfDescription": "series",
            "ancestors": [["collectionIdentifier": "LBJ-NSF", "levelOfDescription": "collection"]],
            "inclusiveStartDate": ["year": 1963],
            "inclusiveEndDate": ["year": 1969],
        ]
        #expect(series["collectionIdentifier"] == nil, "fixture guard: the field really is absent")
        #expect(PresidentialLibraryCatalogRunner.collectionIdentifier(ofDescendant: series) == "LBJ-NSF")
        #expect(PresidentialLibraryCatalogRunner.dateSpan(series) == "1963–1969")
    }

    @Test("Series are grouped under their collection and sorted")
    func projectionGroupsAndSorts() throws {
        let collections: [[String: Any]] = [
            ["collectionIdentifier": "LBJ-NSF", "naId": 567979,
             "title": "National Security Files", "seriesCount": 2],
            ["collectionIdentifier": "LBJ-WHCF", "naId": 566962,
             "title": "White House Central Files", "seriesCount": 0],
        ]
        let series: [[String: Any]] = [
            ["naId": 900, "title": "Later", "ancestors": [["collectionIdentifier": "LBJ-NSF"]]],
            ["naId": 100, "title": "Earlier", "ancestors": [["collectionIdentifier": "LBJ-NSF"]]],
        ]
        let library = PresidentialLibraryCatalogRunner.project(
            prefix: "LBJ", citedAs: "Johnson Library", collections: collections, series: series)
        #expect(library.collections.map(\.identifier) == ["LBJ-NSF", "LBJ-WHCF"])
        let nsf = try #require(library.collections.first)
        #expect(nsf.series.map(\.naId) == [100, 900], "sorted by NAID")
        #expect(nsf.isComplete == true, "2 harvested, 2 stated")
        #expect(library.collections.last?.series.isEmpty == true)
    }

    /// A per-collection shortfall is **reported, never thrown** — because it is not necessarily
    /// ours. Measured in the first keyed run: `RR-0121` (Records of the Crisis Management Center)
    /// states `seriesCount: 1` while the catalogue holds no record carrying `RR-0121` at any
    /// level but the collection itself. NARA describes the collection; its contents are not
    /// catalogued. Throwing would make the harvest unrunnable for a reason nobody can fix.
    ///
    /// The check that *can* only fail because of our own paging is the level-total one in
    /// `CatalogSearchClient.streamRecords`, and that one throws.
    @Test("A collection short of NARA's stated count reports incomplete")
    func shortHarvestIsDetected() throws {
        let library = PresidentialLibraryCatalogRunner.project(
            prefix: "RR", citedAs: "Reagan Library",
            collections: [["collectionIdentifier": "RR-EXSEC", "naId": 1,
                           "title": "Executive Secretariat, NSC", "seriesCount": 21]],
            series: [["naId": 5, "title": "One", "ancestors": [["collectionIdentifier": "RR-EXSEC"]]]])
        let short = try #require(library.collections.first, "the collection must survive at all")
        #expect(short.isComplete == false, "1 harvested against 21 stated")
        // A collection NARA states no count for cannot be judged, and must not claim to be.
        let unstated = PresidentialLibraryCatalogRunner.project(
            prefix: "RR", citedAs: "Reagan Library",
            collections: [["collectionIdentifier": "RR-X", "naId": 2, "title": "X"]], series: [])
        let noCount = try #require(unstated.collections.first,
                                   "a collection with no series must still be kept")
        #expect(noCount.isComplete == nil)
    }

    /// The real `RR-0121` shape, pinned: a collection NARA states a series for, with no series
    /// in the catalogue carrying its identifier. The projection must still produce the
    /// collection — dropping it, or refusing the whole harvest, would lose a real holding over
    /// a gap in somebody else's cataloguing.
    @Test("A collection NARA has described but not catalogued still lands")
    func describedButUncataloguedCollectionSurvives() throws {
        let library = PresidentialLibraryCatalogRunner.project(
            prefix: "RR", citedAs: "Reagan Library",
            collections: [["collectionIdentifier": "RR-0121", "naId": 364672879,
                           "title": "Records of the Crisis Management Center (CMC), NSC",
                           "seriesCount": 1]],
            series: [])
        let collection = try #require(library.collections.first,
                                      "the collection is kept, not dropped")
        #expect(collection.identifier == "RR-0121")
        #expect(collection.naId == 364672879)
        #expect(collection.series.isEmpty)
        #expect(collection.isComplete == false, "reported as short…")
        #expect(library.collections.count == 1, "…and the harvest still yields it")
    }

    /// Both routes must build the same query — the only permitted difference is the host.
    @Test("Both routes issue the same query shape")
    func routesShareTheQuery() throws {
        let v2 = try #require(CatalogSearchClient.pageURL(
            base: CatalogRoute.apiV2.base, collectionIdentifier: "LBJ-*",
            level: "series", limit: 1000, searchAfter: "*"))
        let proxy = try #require(CatalogSearchClient.pageURL(
            base: CatalogRoute.publicProxy.base, collectionIdentifier: "LBJ-*",
            level: "series", limit: 1000, searchAfter: "*"))
        #expect(v2.query == proxy.query, "the routes differ in host, never in query")
        #expect(v2.query?.contains("collectionIdentifier=LBJ-*") == true)
        #expect(v2.query?.contains("levelOfDescription=series") == true)
        #expect(CatalogRoute.apiV2.needsKey)
        #expect(!CatalogRoute.publicProxy.needsKey)
    }

    /// Paging is by cursor because `offset` is not a parameter this endpoint has — and it
    /// ignores parameters it does not know, so an offset-paged harvest silently re-fetches
    /// page 1. Measured before this was fixed: "harvested 2000 of 1281".
    @Test("The query pages by cursor, never by offset")
    func pagingIsByCursor() throws {
        let url = try #require(CatalogSearchClient.pageURL(
            base: CatalogRoute.apiV2.base, collectionIdentifier: "HST-*",
            level: "series", limit: 1000, searchAfter: "12345"))
        let query = try #require(url.query)
        #expect(query.contains("searchAfter=12345"))
        #expect(!query.contains("offset="), "offset is ignored by this endpoint, so sending it lies")
        #expect(!query.contains("page="))
    }

    @Test("The envelope is unwrapped with its cursor, and a foreign one is refused")
    func envelopeDecoding() throws {
        let good = Data("""
        {"body":{"hits":{"total":{"value":2},"hits":[
          {"_source":{"record":{"naId":1,"title":"A"}},"sort":[10]},
          {"_source":{"record":{"naId":2,"title":"B"}},"sort":[20]}]}}}
        """.utf8)
        let (records, total, cursor) = try CatalogSearchClient.decodePage(good)
        #expect(total == 2)
        #expect(records.compactMap { $0["naId"] as? Int } == [1, 2])
        #expect(cursor == "20", "the cursor is the LAST hit's sort value")
        #expect(throws: (any Error).self) {
            try CatalogSearchClient.decodePage(Data(#"{"results":[]}"#.utf8))
        }
    }

    /// A rate-limited caller gets the website's HTML shell under an HTTP 200. Treating that as
    /// an empty page would end a harvest early and report success.
    @Test("An HTML body is refused, not read as an empty page")
    func htmlBodyIsRefused() {
        let html = Data("<!doctype html><html lang=\"en\"><head><script>…".utf8)
        var message = ""
        #expect(throws: (any Error).self) {
            do { _ = try CatalogSearchClient.decodePage(html) }
            catch { message = "\(error)"; throw error }
        }
        #expect(message.contains("HTML"), "the error must name the cause, not just 'unrecognised'")
    }

    @Test("Every harvested library has a distinct prefix and a cited name")
    func libraryTableIsWellFormed() {
        let prefixes = PresidentialLibraryCatalog.harvestedLibraries.map(\.prefix)
        #expect(Set(prefixes).count == prefixes.count, "duplicate prefix")
        #expect(prefixes.allSatisfy { !$0.isEmpty && $0 == $0.uppercased() })
        #expect(PresidentialLibraryCatalog.harvestedLibraries.allSatisfy { !$0.citedAs.isEmpty })
        #expect(prefixes.contains("LBJ") && prefixes.contains("RN") && prefixes.contains("JFK"))
    }
}

// MARK: - LevelStoreTests

/// Pins the on-disk store that makes a ~950,000-record harvest survivable (#681).
///
/// Version history:
///   1.0 — Session 2026-08-06: #681, DEPTH=all
@Suite("Level store — append, resume, completeness")
struct LevelStoreTests {

    private func tempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "plc-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("Pages append rather than overwrite, and are counted without decoding")
    func appendsAndCounts() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = LevelStore(cacheDir: dir, library: "LBJ", level: "fileUnit")
        try store.append([["naId": 1], ["naId": 2]], cursor: "2")
        try store.append([["naId": 3]], cursor: "3")
        #expect(try store.count() == 3, "the second page must append, not replace")
        #expect(try store.load().compactMap { $0["naId"] as? Int } == [1, 2, 3])
    }

    /// A store with no `.done` is known-partial, and the cursor is what lets a run of nearly a
    /// million records pick up instead of starting over.
    @Test("An interrupted slice is resumable and never reads as complete")
    func interruptedSliceResumes() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = LevelStore(cacheDir: dir, library: "GB", level: "fileUnit")
        #expect(store.savedCursor == nil, "nothing stored yet")
        try store.append([["naId": 7]], cursor: "cursor-7")
        #expect(!store.isComplete)
        #expect(store.savedCursor == "cursor-7")

        try store.markComplete()
        #expect(store.isComplete)
        #expect(store.savedCursor == nil, "a complete slice has nothing to resume from")
    }

    @Test("Reset clears a partial slice so a fresh run does not append to it")
    func resetClears() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = LevelStore(cacheDir: dir, library: "RR", level: "series")
        try store.append([["naId": 1]], cursor: "1")
        try store.reset()
        #expect(try store.count() == 0)
        #expect(store.savedCursor == nil)
        #expect(!store.isComplete)
    }

    /// The write order is page-then-cursor on purpose: a crash between them costs a repeated
    /// page on resume, which the harvest tolerates, rather than a skipped one, which it cannot
    /// detect.
    @Test("The cursor is never ahead of the data it describes")
    func cursorTrailsTheData() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = LevelStore(cacheDir: dir, library: "JC", level: "item")
        try store.append([["naId": 1], ["naId": 2]], cursor: nil)
        #expect(try store.count() == 2, "data lands even when no cursor follows")
        #expect(store.savedCursor == nil)
    }
}
