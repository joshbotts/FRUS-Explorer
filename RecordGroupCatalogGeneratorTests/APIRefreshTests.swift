// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import RecordGroupCatalogGeneratorCore

// MARK: - ScriptedAPITransport

/// An in-memory ``CatalogAPITransport`` serving canned responses in order, with a request log.
final class ScriptedAPITransport: CatalogAPITransport, @unchecked Sendable {

    /// Queued `(body, status)` responses, consumed in order.
    private var queue: [(String, Int)]
    private let lock = NSLock()
    private var _requests: [String] = []
    private var _keys: [String] = []

    var requests: [String] { lock.withLock { _requests } }
    var keysSeen: [String] { lock.withLock { _keys } }

    init(responses: [(String, Int)]) {
        self.queue = responses
    }

    func get(_ url: URL, apiKey: String) async throws -> (body: Data, status: Int) {
        lock.withLock {
            _requests.append(url.absoluteString)
            _keys.append(apiKey)
        }
        let next: (String, Int)? = lock.withLock {
            queue.isEmpty ? nil : queue.removeFirst()
        }
        guard let next else { throw CatalogAPIError.badHTTPStatus(599) }
        return (Data(next.0.utf8), next.1)
    }
}

// MARK: - Response fixtures

extension ScriptedAPITransport {

    /// A v2-shaped page: `body.hits.hits[]._source.record`, cursor in each hit's `sort`.
    ///
    /// `sortIncludesScore` reproduces NARA's own published example, `[83.65, "417180915"]` — a
    /// relevance score followed by the identifier. Taking `sort[0]` there would feed the score back as
    /// a cursor, which is exactly the trap this fixture exists to pin.
    static func page(naIds: [Int], recordGroup: Int = 486, total: Int? = nil,
                     sortIncludesScore: Bool = true) -> String {
        let hits = naIds.map { naId in
            let sort = sortIncludesScore ? "[83.65058, \"\(naId)\"]" : "[\"\(naId)\"]"
            return """
            {"_source":{"record":{"naId":\(naId),"title":"Series \(naId)",
              "levelOfDescription":"series",
              "creators":[{"naId":10514123,"heading":"Trade and Development Program",
                "authorityType":"organization","creatorType":"Most Recent"}],
              "variantControlNumbers":[{"number":"P \(naId)","type":"HMS/MLR Entry Number"}],
              "ancestors":[{"distance":1,"levelOfDescription":"recordGroup","naId":22345815,
                "recordGroupNumber":\(recordGroup),"title":"RG"}]}},
             "sort":\(sort)}
            """
        }.joined(separator: ",")
        let totalBlock = total.map { ",\"total\":{\"value\":\($0)}" } ?? ""
        return """
        {"statusCode":200,"body":{"hits":{"hits":[\(hits)]\(totalBlock)}}}
        """
    }

    static let emptyPage = """
    {"statusCode":200,"body":{"hits":{"hits":[]}}}
    """

    /// A page containing only the record group's own node — what the refresh asks for first, to
    /// recover NARA's `seriesCount` for the completeness check.
    static func groupNodePage(recordGroup: Int = 486, seriesCount: Int? = 3,
                              naId: Int = 22345815) -> String {
        let countBlock = seriesCount.map { ",\"seriesCount\":\($0)" } ?? ""
        return """
        {"statusCode":200,"body":{"hits":{"hits":[
          {"_source":{"record":{"naId":\(naId),
            "title":"Records of the U.S. Trade and Development Agency",
            "levelOfDescription":"recordGroup","recordGroupNumber":\(recordGroup)\(countBlock)}},
           "sort":["\(naId)"]}
        ]}}}
        """
    }
}

// MARK: - CatalogAPIClientDecodeTests

/// Tests the envelope probing — the part that turns four unknowns into report lines.
struct CatalogAPIClientDecodeTests {

    private func decode(_ json: String, status: Int = 200, limit: Int = 100) throws
        -> CatalogAPIClient.Page {
        try CatalogAPIClient.decode(Data(json.utf8), httpStatus: status, requestedLimit: limit)
    }

    @Test("Finds the v2 envelope and reports the path it used")
    func findsV2Envelope() throws {
        let page = try decode(ScriptedAPITransport.page(naIds: [1, 2], total: 11))
        #expect(page.records.count == 2)
        #expect(page.observation.hitsPath == "body.hits.hits")
        #expect(page.observation.recordPath == "_source.record")
        #expect(page.observation.totalHits == 11)
        #expect(page.observation.returnedHitCount == 2)
        #expect(page.records[0]["title"]?.stringValue == "Series 1")
    }

    @Test("Finds a bare Elasticsearch envelope and a v1-style one, reporting each path")
    func findsAlternativeEnvelopes() throws {
        // The repo's own two clients disagree about the envelope — the harvest client reads
        // body.hits.hits, the runtime client reads opaResponse.results.result. Probing means a wrong
        // guess is a report line, not an empty refresh.
        let bare = try decode("""
        {"hits":{"hits":[{"_source":{"record":{"naId":5,"title":"T"}},"sort":["5"]}]}}
        """)
        #expect(bare.observation.hitsPath == "hits.hits")
        #expect(bare.records.count == 1)

        let v1 = try decode("""
        {"opaResponse":{"results":{"result":[{"record":{"naId":6,"title":"U"}}]}}}
        """)
        #expect(v1.observation.hitsPath == "opaResponse.results.result")
        #expect(v1.observation.recordPath == "record")
    }

    @Test("An unrecognisable envelope throws and names the keys it did see")
    func throwsOnUnknownEnvelope() {
        #expect(throws: CatalogAPIError.unrecognisedEnvelope(
            observedTopLevelKeys: ["message", "somethingElse"])) {
            _ = try CatalogAPIClient.decode(
                Data("{\"message\":\"hi\",\"somethingElse\":1}".utf8),
                httpStatus: 200, requestedLimit: 100)
        }
    }

    @Test("The cursor is the LAST sort element, not the first")
    func takesLastSortElement() throws {
        // NARA's published example is [83.65058, "417180915"]. sort[0] is a relevance score.
        let withScore = try decode(ScriptedAPITransport.page(naIds: [7, 8], sortIncludesScore: true))
        #expect(withScore.nextCursor == "8")
        #expect(withScore.observation.sortArity == 2)
        #expect(withScore.observation.lastSortArray == ["83.65058", "8"])

        let withoutScore = try decode(
            ScriptedAPITransport.page(naIds: [7, 9], sortIncludesScore: false))
        #expect(withoutScore.nextCursor == "9")
        #expect(withoutScore.observation.sortArity == 1)

        // The arity-2 warning is what tells the owner which case they are in.
        #expect(withScore.observation.reportLines.contains { $0.contains("arity ≥ 2") })
        #expect(!withoutScore.observation.reportLines.contains { $0.contains("arity ≥ 2") })
    }

    @Test("HTTP 200 with a failing statusCode inside the body throws")
    func throwsOnBodyStatusCode() {
        // A shape the v2 API really does use — a 200 that is not a success.
        #expect(throws: CatalogAPIError.apiErrorStatus(429)) {
            _ = try CatalogAPIClient.decode(
                Data("{\"statusCode\":429,\"body\":{}}".utf8),
                httpStatus: 200, requestedLimit: 100)
        }
    }

    @Test("A 4xx is returned for the caller to interpret, not thrown")
    func returns4xxForInspection() throws {
        // The survey must be able to SEE a 400 to answer "is q required?".
        let page = try decode("{\"message\":\"q is required\"}", status: 400)
        #expect(page.records.isEmpty)
        #expect(page.observation.httpStatus == 400)
    }

    @Test("A hit with no locatable record is counted as dropped, not silently skipped")
    func countsDroppedHits() throws {
        let page = try decode("""
        {"statusCode":200,"body":{"hits":{"hits":[
          {"_source":{"record":{"naId":1,"title":"good"}},"sort":["1"]},
          {"_source":{"somethingElse":true},"sort":["2"]}
        ]}}}
        """)
        #expect(page.records.count == 1)
        #expect(page.observation.returnedHitCount == 2)
        #expect(page.observation.droppedHitCount == 1)
    }

    @Test("Clamping is distinguished from 'that is all there is' using totalHits")
    func distinguishesClampingFromExhaustion() throws {
        // The 2026-07-30 survey's first run could not answer the clamping question for RG 486 — 11
        // records return 11 whether the limit is 100 or 1000 — and the report's hedge said as much.
        // With totalHits known, the two cases are separable.
        let exhausted = try decode(
            ScriptedAPITransport.page(naIds: [1], total: 1), limit: 1000)
        #expect(exhausted.observation.reportLines.contains { $0.contains("NOT clamped") })

        let clamped = try decode(
            ScriptedAPITransport.page(naIds: [1], total: 500), limit: 1000)
        #expect(clamped.observation.reportLines.contains {
            $0.contains("fewer than available — clamped")
        })

        let full = try decode(
            ScriptedAPITransport.page(naIds: Array(1...5), total: 50), limit: 5)
        #expect(full.observation.reportLines.contains { $0.contains("limit honoured in full") })
    }

    @Test("An empty terminator page is reported as end-of-results, not as a missing field")
    func reportsEmptyPageHonestly() throws {
        // The survey's page 2 was a legitimate end-of-results page, and the report called its absent
        // recordPath "*** NOT FOUND ***" — making a healthy terminator look like a decode failure.
        let empty = try decode(ScriptedAPITransport.emptyPage, limit: 1000)
        #expect(empty.observation.returnedHitCount == 0)
        #expect(empty.observation.reportLines.contains { $0.contains("end of results") })
        #expect(!empty.observation.reportLines.contains { $0.contains("NOT FOUND") })
    }
}

// MARK: - CatalogAPIPagingTests

/// Tests paging, budget and the query shape.
struct CatalogAPIPagingTests {

    private func client(_ responses: [(String, Int)], pageSize: Int = 100)
        -> (CatalogAPIClient, ScriptedAPITransport) {
        let transport = ScriptedAPITransport(responses: responses)
        return (CatalogAPIClient(apiKey: "test-key", pageSize: pageSize, transport: transport),
                transport)
    }

    @Test("Pages until a page returns zero RAW hits")
    func pagesToExhaustion() async throws {
        let (api, transport) = client([
            (ScriptedAPITransport.page(naIds: [1, 2]), 200),
            (ScriptedAPITransport.page(naIds: [3]), 200),
            (ScriptedAPITransport.emptyPage, 200),
        ])
        var collected: [String] = []
        let result = try await api.harvestGroup(recordGroup: 486, level: "series", maxRequests: 10) {
            collected.append($0["naId"]?.stringValue ?? "")
        }
        #expect(collected == ["1", "2", "3"])
        #expect(result.requestsSpent == 3)
        #expect(transport.keysSeen.allSatisfy { $0 == "test-key" })
    }

    @Test("The query uses the top-level recordGroupNumber facet, not the description-prefixed form")
    func usesTopLevelRecordGroupFacet() async throws {
        // The repo has a scar here: `description.recordGroupNumber` filters DESCENDANTS and was
        // silently ignored on a record-group query, collapsing every group to the first hit.
        let (api, transport) = client([(ScriptedAPITransport.emptyPage, 200)])
        _ = try await api.harvestGroup(recordGroup: 486, level: "series", maxRequests: 1) { _ in }
        let url = try #require(transport.requests.first)
        #expect(url.contains("recordGroupNumber=486"))
        #expect(!url.contains("description.recordGroupNumber"))
        #expect(url.contains("levelOfDescription=series"))
        #expect(url.contains("limit=100"))
        // No `q` by default — NARA's own scripts omit it, and the 2026-07-30 survey confirmed a
        // q-less request returns HTTP 200.
        #expect(!url.contains("&q=") && !url.contains("?q="))
    }

    @Test("A non-advancing cursor throws instead of paging forever")
    func throwsOnStalledCursor() async throws {
        // Otherwise this burns the monthly quota with nothing to show for it.
        let samePage = ScriptedAPITransport.page(naIds: [1])
        let (api, _) = client([(samePage, 200), (samePage, 200), (samePage, 200)])
        await #expect(throws: CatalogAPIError.cursorDidNotAdvance("1")) {
            _ = try await api.harvestGroup(recordGroup: 486, level: "series",
                                           maxRequests: 10) { _ in }
        }
    }

    @Test("Levels are harvested coarsest-first, so a deep failure cannot cost a shallow one")
    func harvestsLevelsHierarchically() {
        // `admittedLevels.sorted()` put "fileUnit" before "series" alphabetically. When RG 59's first
        // file-unit page returned HTTP 500, the group aborted having harvested ZERO series — losing a
        // level that had worked reliably at limit=1000 minutes earlier.
        #expect(HarvestDepth.seriesAndFileUnits.orderedLevels == ["series", "fileUnit"])
        #expect(HarvestDepth.all.orderedLevels == ["series", "fileUnit", "item", "collection"])
        #expect(HarvestDepth.series.orderedLevels == ["series"])
        // The old alphabetical order really did invert it.
        #expect(Array(HarvestDepth.seriesAndFileUnits.admittedLevels.sorted()) == ["fileUnit", "series"])
    }

    @Test("Default page size is level-aware, because record size differs by orders of magnitude")
    func pageSizeIsLevelAware() {
        // Measured on RG 59 from the bulk export: a series record averages 3,100 bytes; a fileUnit has
        // a median of 1,889 but a mean of 20,878 and a max of 4.24 MB. One number cannot serve both.
        #expect(CatalogAPIClient.defaultPageSize(forLevel: "series") == 1000)
        #expect(CatalogAPIClient.defaultPageSize(forLevel: "fileUnit") == 250)
        #expect(CatalogAPIClient.defaultPageSize(forLevel: "item") == 100)
    }

    @Test("A failing page halves the limit and retries the same cursor")
    func halvesPageSizeOnFailure() async throws {
        // Note the scripted transport RETURNS the 500 rather than throwing, exactly as `decode` hands a
        // non-2xx back — which is how the latent "4xx reads as end-of-results" truncation was found.
        // The RG 59 fix: ride over an over-large page instead of aborting the group.
        let (api, transport) = client([
            ("{\"message\":\"boom\"}", 500),                                  // limit=250 fails
            (ScriptedAPITransport.page(naIds: [1, 2], total: 2), 200),        // limit=125 works
        ], pageSize: 250)
        var collected: [String] = []
        let result = try await api.harvestGroup(
            recordGroup: 59, level: "fileUnit", maxRequests: 10, startingPageSize: 250) {
            collected.append($0["naId"]?.stringValue ?? "")
        }
        #expect(collected == ["1", "2"])
        // Both attempts are charged, and the retry used half the limit against the SAME cursor.
        #expect(result.requestsSpent == 2)
        try #require(transport.requests.count >= 2)
        #expect(transport.requests[0].contains("limit=250"))
        #expect(transport.requests[1].contains("limit=125"))
        #expect(transport.requests[1].contains("searchAfter=%2A")
                || transport.requests[1].contains("searchAfter=*"))
    }

    @Test("Below the adaptive floor the error surfaces with full context, not a bare HTTP 500")
    func reportsContextAtTheFloor() async throws {
        // A bare "HTTP 500" is what the first RG 59 attempt produced, and locating it meant counting
        // records in the on-disk store. Not a diagnosis path anyone should need.
        let failing = Array(repeating: ("{\"message\":\"boom\"}", 500), count: 12)
        let (api, _) = client(failing, pageSize: 50)
        do {
            _ = try await api.harvestGroup(recordGroup: 59, level: "fileUnit",
                                           maxRequests: 20, startingPageSize: 50) { _ in }
            Issue.record("expected a throw at the adaptive floor")
        } catch let error as CatalogAPIError {
            let text = error.description
            #expect(text.contains("RG 59"))
            #expect(text.contains("fileUnit"))
            #expect(text.contains("not a response-size problem"))
        }
    }

    @Test("The per-group request ceiling stops paging")
    func respectsRequestCeiling() async throws {
        let (api, transport) = client([
            (ScriptedAPITransport.page(naIds: [1]), 200),
            (ScriptedAPITransport.page(naIds: [2]), 200),
            (ScriptedAPITransport.page(naIds: [3]), 200),
        ])
        let result = try await api.harvestGroup(recordGroup: 486, level: "series",
                                                maxRequests: 2) { _ in }
        #expect(result.requestsSpent == 2)
        #expect(transport.requests.count == 2)
    }

    @Test("A q-less rejection retries once with q and records that it happened")
    func retriesWithQOnRejection() async throws {
        // The spec marks `q` required; NARA's own scripts omit it. If the spec is right, every
        // filter-only request 400s — and a permissive `q` changes relevance scoring and therefore the
        // sort array, so the fallback must be recorded rather than silent.
        let (api, transport) = client([
            ("{\"message\":\"q is required\"}", 400),
            (ScriptedAPITransport.page(naIds: [1]), 200),
        ])
        let page = try await api.fetchPage(recordGroup: 486, level: "series", cursor: nil)
        #expect(page.records.count == 1)
        #expect(page.observation.rejectedWithoutQ)
        #expect(transport.requests.count == 2)
        #expect(transport.requests[0].contains("q=") == false)
        #expect(transport.requests[1].contains("q=%2A") || transport.requests[1].contains("q=*"))
    }

    @Test("searchAfter is sent on EVERY request, seeded on the first")
    func seedsCursorOnFirstRequest() async throws {
        // Measured on 2026-07-30: omitting the seed makes request 1 relevance-sorted
        // (`sort: [14.285818, 32161988]`, arity 2) while request 2 is naId-sorted (arity 1), so the
        // naId taken from page 1 is not a valid cursor — the survey pulled 11 hits then 3 more from a
        // result set of 11. Seeding with `*` matches the repo's proven client and forces one ordering.
        let (api, transport) = client([
            (ScriptedAPITransport.page(naIds: [1]), 200),
            (ScriptedAPITransport.emptyPage, 200),
        ])
        _ = try await api.harvestGroup(recordGroup: 486, level: "series", maxRequests: 5) { _ in }
        #expect(transport.requests[0].contains("searchAfter=*")
                || transport.requests[0].contains("searchAfter=%2A"))
        #expect(transport.requests[1].contains("searchAfter=1"))
    }

    @Test("The record-group node is fetched, and reports its seriesCount")
    func fetchesRecordGroupNode() async throws {
        // The API-only harvest's completeness check depends on this one call: levelOfDescription=series
        // necessarily excludes the recordGroup-level record that states seriesCount.
        let (api, transport) = client([(ScriptedAPITransport.groupNodePage(seriesCount: 11), 200)])
        let node = try await api.fetchRecordGroupNode(recordGroup: 486)
        #expect(node?["seriesCount"]?.intValue == 11)
        #expect(node?["levelOfDescription"]?.stringValue == "recordGroup")
        #expect(transport.requests[0].contains("levelOfDescription=recordGroup"))
    }

    @Test("A node for the wrong record group is rejected rather than trusted")
    func rejectsWrongGroupNode() async throws {
        // A fuzzy hit must not supply a seriesCount belonging to a different group.
        let (api, _) = client([(ScriptedAPITransport.groupNodePage(recordGroup: 59,
                                                                  seriesCount: 4449), 200)])
        #expect(try await api.fetchRecordGroupNode(recordGroup: 486) == nil)
    }

    @Test("Records duplicated across pages are dropped, not counted twice")
    func deduplicatesAcrossPages() async throws {
        // The failure mode the survey exposed: overlapping pages. A duplicate would push the count
        // PAST NARA's own total, and the completeness check only tests for a shortfall — so it would
        // sail through.
        let (api, _) = client([
            (ScriptedAPITransport.page(naIds: [1, 2, 3]), 200),
            (ScriptedAPITransport.page(naIds: [2, 3, 4]), 200),
            (ScriptedAPITransport.emptyPage, 200),
        ])
        var collected: [String] = []
        let result = try await api.harvestGroup(recordGroup: 486, level: "series",
                                                maxRequests: 5) {
            collected.append($0["naId"]?.stringValue ?? "")
        }
        #expect(collected == ["1", "2", "3", "4"])
        #expect(result.recordCount == 4)
    }

    @Test("Paging stops once totalHits is reached, even if pages keep coming")
    func stopsAtTotalHits() async throws {
        // Directly the survey's symptom: page 1 returned all 11 of 11, and page 2 still returned 3
        // more. Knowing the total is what makes that terminable.
        let (api, transport) = client([
            (ScriptedAPITransport.page(naIds: [1, 2, 3], total: 3), 200),
            (ScriptedAPITransport.page(naIds: [4, 5], total: 3), 200),
        ])
        let result = try await api.harvestGroup(recordGroup: 486, level: "series",
                                                maxRequests: 5) { _ in }
        #expect(result.recordCount == 3)
        // Only one request was needed; the second page was never fetched.
        #expect(transport.requests.count == 1)
    }
}

// MARK: - RecordChangeLogTests

/// Tests the bulk-vs-refresh diff.
struct RecordChangeLogTests {

    @Test("Counts and enumerates changes, but only counts the unchanged")
    func countsAndEnumerates() {
        var log = RecordChangeLog()
        log.note(recordGroup: 486, naId: "1", change: .added, title: "New")
        log.note(recordGroup: 486, naId: "2", change: .modified, title: "Changed")
        log.note(recordGroup: 486, naId: "3", change: .unchanged, title: "Same")
        log.note(recordGroup: 420, naId: "4", change: .missingFromRefresh, title: "Gone")

        #expect(log.total(.added) == 1)
        #expect(log.total(.unchanged) == 1)
        // Unchanged records are counted but not listed — there are tens of thousands of them.
        #expect(log.entries.count == 3)
        #expect(!log.entries.contains { $0.change == .unchanged })
        #expect(log.hasChanges)
    }

    @Test("Incidental drift outside the indexed fields is not a change")
    func incidentalDriftIsNotAChange() {
        // Measured on RG 486: all 11 records differed, entirely in dataControlGroup's internal code
        // (RRAT -> RRAR) and referenceUnits[].mailCode. Counting those as changes would flag the whole
        // corpus on every refresh forever and bury any real change in the noise.
        var log = RecordChangeLog()
        for naId in 1...11 {
            log.note(recordGroup: 486, naId: String(naId), change: .unchangedOutsideIndex)
        }
        #expect(log.total(.unchangedOutsideIndex) == 11)
        #expect(!log.hasChanges)
        // Not enumerated per record either — the CSV is for records that actually moved.
        #expect(log.csvRows().isEmpty)

        // One real change alongside the drift still registers.
        log.note(recordGroup: 486, naId: "12", change: .modified)
        #expect(log.hasChanges)
        #expect(log.csvRows().count == 1)
    }

    @Test("A run with only unchanged records reports no changes")
    func detectsNoChanges() {
        var log = RecordChangeLog()
        log.note(recordGroup: 486, naId: "1", change: .unchanged)
        #expect(!log.hasChanges)
        #expect(log.csvRows().isEmpty)
    }

    @Test("CSV rows are sorted for a stable diff")
    func sortsRows() {
        var log = RecordChangeLog()
        log.note(recordGroup: 486, naId: "9", change: .added)
        log.note(recordGroup: 420, naId: "1", change: .modified)
        log.note(recordGroup: 486, naId: "2", change: .added)
        let rows = log.csvRows()
        #expect(rows.map { $0[0] } == ["420", "486", "486"])
        #expect(rows[1][1] == "2")
        #expect(rows[2][1] == "9")
    }

    @Test("Merging keeps per-group counts apart")
    func merges() {
        var a = RecordChangeLog()
        a.note(recordGroup: 486, naId: "1", change: .added)
        var b = RecordChangeLog()
        b.note(recordGroup: 420, naId: "2", change: .added)
        a.merge(b)
        #expect(a.total(.added) == 2)
        #expect(a.counts[486]?[.added] == 1)
        #expect(a.counts[420]?[.added] == 1)
    }
}
