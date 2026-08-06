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
    func projectionGroupsAndSorts() {
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
        #expect(library.collections[0].series.map(\.naId) == [100, 900], "sorted by NAID")
        #expect(library.collections[0].isComplete == true, "2 harvested, 2 stated")
        #expect(library.collections[1].series.isEmpty)
    }

    /// NARA states each collection's `seriesCount`, which is what makes a short harvest
    /// self-detecting rather than silently plausible.
    @Test("A collection short of NARA's stated count reports incomplete")
    func shortHarvestIsDetected() {
        let library = PresidentialLibraryCatalogRunner.project(
            prefix: "RR", citedAs: "Reagan Library",
            collections: [["collectionIdentifier": "RR-EXSEC", "naId": 1,
                           "title": "Executive Secretariat, NSC", "seriesCount": 21]],
            series: [["naId": 5, "title": "One", "ancestors": [["collectionIdentifier": "RR-EXSEC"]]]])
        #expect(library.collections[0].isComplete == false, "1 harvested against 21 stated")
        // A collection NARA states no count for cannot be judged, and must not claim to be.
        let unstated = PresidentialLibraryCatalogRunner.project(
            prefix: "RR", citedAs: "Reagan Library",
            collections: [["collectionIdentifier": "RR-X", "naId": 2, "title": "X"]], series: [])
        #expect(unstated.collections[0].isComplete == nil)
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
