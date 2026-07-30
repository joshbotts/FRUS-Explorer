// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - CatalogAPITransport

/// One authenticated GET against the NARA Catalog v2 API.
///
/// Separate from ``CatalogBulkTransport`` because this one carries a key and the bulk one must never
/// be given the opportunity: the whole point of the bulk path is that it works with no credential.
public protocol CatalogAPITransport: Sendable {
    /// Fetches `url` with the API key attached. Returns the body and the HTTP status.
    func get(_ url: URL, apiKey: String) async throws -> (body: Data, status: Int)
}

// MARK: - URLSessionAPITransport

/// The live API transport: throttled, with bounded retry on transient failures.
public struct URLSessionAPITransport: CatalogAPITransport {

    private let session: URLSession
    private let maxAttempts: Int
    private let throttleNanoseconds: UInt64

    /// - Parameters:
    ///   - throttleMilliseconds: Delay before every request. Defaults to **150 ms**, up from the 60 ms
    ///     the repo's existing catalog client uses, because that client's own comment records that
    ///     rapid-fire requests "drew a wall of 503s from the catalog". A refresh is a few hundred
    ///     calls at most, so the extra 90 ms each is free.
    public init(session: URLSession = .shared,
                maxAttempts: Int = 4,
                throttleMilliseconds: UInt64 = 150) {
        self.session = session
        self.maxAttempts = max(1, maxAttempts)
        self.throttleNanoseconds = throttleMilliseconds * 1_000_000
    }

    public func get(_ url: URL, apiKey: String) async throws -> (body: Data, status: Int) {
        var lastStatus = 0
        var lastError: Error?
        for attempt in 0..<maxAttempts {
            if throttleNanoseconds > 0 { try? await Task.sleep(nanoseconds: throttleNanoseconds) }
            do {
                var request = URLRequest(url: url)
                request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.setValue("FRUSExplorer/RecordGroupCatalogGenerator 1.0",
                                 forHTTPHeaderField: "User-Agent")
                request.timeoutInterval = 60

                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw CatalogAPIError.unexpectedResponseType
                }
                lastStatus = http.statusCode
                // 4xx is returned to the caller rather than thrown: the survey needs to SEE a 400 to
                // answer "is `q` required?", and a 403 must be reported as a key problem rather than
                // retried as a hiccup.
                if (200..<300).contains(http.statusCode) || (400..<500).contains(http.statusCode) {
                    return (data, http.statusCode)
                }
                throw CatalogAPIError.badHTTPStatus(http.statusCode)
            } catch {
                lastError = error
                let transient: Set<Int> = [429, 500, 502, 503, 504]
                guard transient.contains(lastStatus), attempt < maxAttempts - 1 else {
                    throw error
                }
                let backoffMs = UInt64(500 * (1 << attempt))   // 0.5s, 1s, 2s
                try? await Task.sleep(nanoseconds: backoffMs * 1_000_000)
            }
        }
        throw lastError ?? CatalogAPIError.badHTTPStatus(lastStatus)
    }
}

// MARK: - CatalogAPIError

public enum CatalogAPIError: Error, Sendable, Equatable, CustomStringConvertible {
    case missingAPIKey
    case invalidURL(String)
    case unexpectedResponseType
    case badHTTPStatus(Int)
    /// HTTP 200 with a non-2xx `statusCode` inside the body — a shape the v2 API really does use.
    case apiErrorStatus(Int)
    /// No recognised hits container in the response.
    case unrecognisedEnvelope(observedTopLevelKeys: [String])
    /// The cursor did not advance, so paging would loop forever.
    case cursorDidNotAdvance(String)

    public var description: String {
        switch self {
        case .missingAPIKey:            return "CATALOG_API_KEY is not set"
        case .invalidURL(let s):        return "Could not build a URL from '\(s)'"
        case .unexpectedResponseType:   return "Non-HTTP response"
        case .badHTTPStatus(let c):     return "HTTP \(c)"
        case .apiErrorStatus(let c):    return "HTTP 200 with body statusCode \(c)"
        case .unrecognisedEnvelope(let keys):
            return "No known hits container; response top-level keys: \(keys.joined(separator: ", "))"
        case .cursorDidNotAdvance(let cursor):
            return "Cursor '\(cursor)' repeated — paging would loop; aborting rather than burning quota"
        }
    }
}

// MARK: - APIEnvelopeObservation

/// What the client actually saw in a response — the survey's payload.
///
/// Every field here exists because it is a documented *unknown* rather than a known fact. The bulk
/// path could be verified before shipping; the API path cannot, so instead of guessing, the client
/// reports what it found and one cheap survey run turns each guess into a fact.
public struct APIEnvelopeObservation: Sendable, Equatable {
    /// Dotted path at which the hits array was found (e.g. `body.hits.hits`).
    public var hitsPath: String?
    /// Dotted path within a hit at which the record object was found (e.g. `_source.record`).
    public var recordPath: String?
    /// The raw `sort` array of the last hit, stringified — the cursor question.
    public var lastSortArray: [String]
    /// How many elements that array had. **2 means the first element is a relevance score**, not the
    /// cursor: NARA's own published example is `[83.65, "417180915"]`, and taking `sort[0]` would feed
    /// a score back as a cursor.
    public var sortArity: Int
    /// Total hits, if the response reports one.
    public var totalHits: Int?
    /// Rows requested vs returned — answers "is `limit` honoured or silently clamped?".
    public var requestedLimit: Int
    public var returnedHitCount: Int
    /// Hits dropped because no record object could be found inside them.
    public var droppedHitCount: Int
    /// HTTP status, and the body's own `statusCode` when it carries one.
    public var httpStatus: Int
    public var bodyStatusCode: Int?
    /// Whether the request omitted `q`, and whether a `q`-less request was rejected.
    public var omittedQ: Bool
    public var rejectedWithoutQ: Bool
    /// Top-level response keys, so an unrecognised envelope is diagnosable from the report alone.
    public var topLevelKeys: [String]

    public init(hitsPath: String? = nil, recordPath: String? = nil, lastSortArray: [String] = [],
                sortArity: Int = 0, totalHits: Int? = nil, requestedLimit: Int = 0,
                returnedHitCount: Int = 0, droppedHitCount: Int = 0, httpStatus: Int = 0,
                bodyStatusCode: Int? = nil, omittedQ: Bool = true, rejectedWithoutQ: Bool = false,
                topLevelKeys: [String] = []) {
        self.hitsPath = hitsPath
        self.recordPath = recordPath
        self.lastSortArray = lastSortArray
        self.sortArity = sortArity
        self.totalHits = totalHits
        self.requestedLimit = requestedLimit
        self.returnedHitCount = returnedHitCount
        self.droppedHitCount = droppedHitCount
        self.httpStatus = httpStatus
        self.bodyStatusCode = bodyStatusCode
        self.omittedQ = omittedQ
        self.rejectedWithoutQ = rejectedWithoutQ
        self.topLevelKeys = topLevelKeys
    }

    /// The paste-back block: everything needed to correct the query shape in one screenful.
    public var reportLines: [String] {
        var out: [String] = []
        out.append("  httpStatus            \(httpStatus)"
                   + (bodyStatusCode.map { ", body.statusCode \($0)" } ?? ""))
        out.append("  hitsPath              \(hitsPath ?? "*** NOT FOUND ***")")
        // An empty page has no hits to locate a record inside, so a missing recordPath there is the
        // correct end-of-results outcome — not a failure to find the field. Reporting it as
        // "*** NOT FOUND ***" made a perfectly healthy terminator page look broken.
        if returnedHitCount == 0 {
            out.append("  recordPath            (n/a — empty page, end of results)")
        } else {
            out.append("  recordPath            \(recordPath ?? "*** NOT FOUND ***")")
        }
        out.append("  topLevelKeys          \(topLevelKeys.joined(separator: ", "))")
        // With `totalHits` known, "fewer than requested" is answerable rather than ambiguous: if the
        // page returned everything that exists, the limit was not clamped.
        let shortfallNote: String
        if requestedLimit > 0, returnedHitCount < requestedLimit {
            if let totalHits, returnedHitCount >= totalHits {
                shortfallNote = "  (that is all there is — totalHits \(totalHits); NOT clamped)"
            } else if returnedHitCount == 0 {
                shortfallNote = "  (empty page — end of results)"
            } else {
                shortfallNote = "  (fewer than requested AND fewer than available — clamped)"
            }
        } else {
            shortfallNote = requestedLimit > 0 ? "  (limit honoured in full)" : ""
        }
        out.append("  requested/returned    limit=\(requestedLimit) → \(returnedHitCount) hits"
                   + shortfallNote)
        out.append("  totalHits             \(totalHits.map(String.init) ?? "(not reported)")")
        out.append("  droppedHits           \(droppedHitCount)")
        out.append("  sort array (last hit) [\(lastSortArray.joined(separator: ", "))]  arity=\(sortArity)")
        if sortArity >= 2 {
            out.append("      ⚠ arity ≥ 2 — element 0 is probably a relevance score, NOT the cursor."
                       + " This client takes the LAST element.")
        }
        out.append("  q omitted             \(omittedQ)"
                   + (rejectedWithoutQ ? "  ⚠ REJECTED without q — a permissive q is required" : ""))
        return out
    }
}

// MARK: - CatalogAPIClient

/// Pages the NARA Catalog v2 search API for one record group's records.
///
/// ## Why this exists alongside the bulk path
/// The bulk export is a **snapshot** (2026-04-09 at the time of writing, republished roughly twice a
/// year). This is the refresh path: it re-pages the current catalog and diffs against the
/// bulk-derived store.
///
/// ## Why it re-pages everything rather than fetching a delta
/// Because there is no delta to fetch. A census of 513 real records found **no `modified`, `updated`,
/// `version` or `created` field anywhere** in the description payload, so "everything changed since
/// date X" is not expressible — there is nothing to filter on.
///
/// That turns out to be fine, and arguably better. The series layer across the 22 record groups is
/// ~20,126 records: roughly 40 calls at `limit=1000`, ~250 at `limit=100`, against a documented
/// 10,000/month quota. And re-paging detects something a date filter structurally cannot —
/// **withdrawals**, records that have disappeared from the catalog since the snapshot.
///
/// ## What is verified and what is not
/// Nothing here is verified against the live API: it needs a key this tool was built without. The
/// query shape follows the repo's hard-won `CentralFilesIndexGeneratorCore` experience (notably that
/// `recordGroupNumber` is a **top-level** facet — the `description.`-prefixed form filters
/// *descendants* and was silently ignored on a record-group query), and every remaining unknown is
/// reported rather than assumed. Run the survey first; see
/// `Planning/nara-record-group-catalog-runbook.md`.
///
/// ## Log prefix
/// `[RecordGroupCatalogGenerator]`
///
/// Version history:
///   1.0 — Session 2026-07-30: initial implementation (query shape UNVERIFIED — survey first)
public struct CatalogAPIClient: Sendable {

    /// The v2 search endpoint.
    public static let defaultEndpoint = "https://catalog.archives.gov/api/v2/records/search"

    /// Candidate dotted paths for the hits array, most likely first.
    ///
    /// Three because the repo's own two clients disagree: the harvest client reads
    /// `body.hits.hits`, while the runtime client reads a v1-style `opaResponse.results.result`.
    /// Probing rather than assuming means a wrong guess is a report line, not an empty refresh.
    static let hitsPathCandidates = ["body.hits.hits", "hits.hits", "opaResponse.results.result"]

    /// Candidate dotted paths for the record object inside one hit.
    static let recordPathCandidates = ["_source.record", "_source", "record"]

    /// Seed for the first request's `searchAfter`. See the comment in ``fetchPage``.
    public static let firstCursorSeed = "*"

    private let endpoint: String
    private let apiKey: String
    private let pageSize: Int
    private let transport: any CatalogAPITransport
    private let log: @Sendable (String) -> Void

    public init(endpoint: String = CatalogAPIClient.defaultEndpoint,
                apiKey: String,
                pageSize: Int = 1000,
                transport: any CatalogAPITransport,
                log: @escaping @Sendable (String) -> Void = { _ in }) {
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.pageSize = pageSize
        self.transport = transport
        self.log = log
    }

    // MARK: One page

    /// One decoded page.
    public struct Page: Sendable {
        public var records: [CatalogJSONValue]
        public var nextCursor: String?
        public var observation: APIEnvelopeObservation
    }

    /// Fetches and decodes one page.
    ///
    /// - Parameters:
    ///   - recordGroup: record group to filter to.
    ///   - level: `levelOfDescription` to filter to, or `nil` for all levels.
    ///   - cursor: `searchAfter` value; `nil` for the first page.
    ///   - includeQ: send a permissive `q=*`. The spec marks `q` required while NARA's own scripts
    ///     omit it, so the client omits it and retries once with it if the API says otherwise.
    public func fetchPage(
        recordGroup: Int,
        level: String?,
        cursor: String?,
        includeQ: Bool = false
    ) async throws -> Page {
        var items = [
            // Top-level facet, NOT `description.recordGroupNumber` — the prefixed form filters
            // descendants and was silently ignored on a record-group query (see the #321-era comments
            // in NARACatalogHarvestClient.resolveRecordGroup).
            URLQueryItem(name: "recordGroupNumber", value: String(recordGroup)),
            URLQueryItem(name: "limit", value: String(pageSize)),
        ]
        if let level { items.append(URLQueryItem(name: "levelOfDescription", value: level)) }
        // `searchAfter` is sent on EVERY request, seeded with `*` on the first — matching the repo's
        // existing, proven client (NARACatalogHarvestClient enumerated 1,241 rolls this way).
        //
        // This is not cosmetic. Omitting it on the first request makes that request RELEVANCE-sorted
        // while every subsequent one is naId-sorted, and the 2026-07-30 survey caught exactly that:
        // page 1 came back with `sort: [14.285818, 32161988]` (arity 2 — a score plus an naId) and
        // page 2 with `sort: [22345695]` (arity 1). Feeding the last hit of a relevance-ordered page
        // back as an naId cursor skips and duplicates arbitrarily — the survey pulled 11 hits then 3
        // more from a result set of 11. Seeding forces one consistent sort for the whole sequence.
        items.append(URLQueryItem(name: "searchAfter", value: cursor ?? Self.firstCursorSeed))
        if includeQ { items.append(URLQueryItem(name: "q", value: "*")) }

        guard var components = URLComponents(string: endpoint) else {
            throw CatalogAPIError.invalidURL(endpoint)
        }
        components.queryItems = items
        guard let url = components.url else { throw CatalogAPIError.invalidURL(endpoint) }

        let (body, status) = try await transport.get(url, apiKey: apiKey)
        var page = try Self.decode(body, httpStatus: status, requestedLimit: pageSize)
        page.observation.omittedQ = !includeQ

        // If a q-less request was rejected, say so loudly and retry once WITH q. A permissive `q`
        // changes relevance scoring and therefore the `sort` array, which interacts with the cursor
        // question — so this must never happen silently.
        if status == 400, !includeQ {
            log("[RecordGroupCatalogGenerator] ⚠ API rejected a q-less request (HTTP 400) — "
                + "retrying with q=*; note this changes relevance scoring and thus the sort array")
            var retried = try await fetchPage(recordGroup: recordGroup, level: level,
                                              cursor: cursor, includeQ: true)
            retried.observation.rejectedWithoutQ = true
            return retried
        }
        return page
    }

    // MARK: Decoding

    /// Decodes a response by *probing* for the envelope rather than assuming it, recording what it
    /// found in the observation.
    static func decode(
        _ data: Data, httpStatus: Int, requestedLimit: Int
    ) throws -> Page {
        let root = try JSONDecoder().decode(CatalogJSONValue.self, from: data)
        var observation = APIEnvelopeObservation(requestedLimit: requestedLimit,
                                                httpStatus: httpStatus)
        observation.topLevelKeys = (root.objectValue?.keys).map { Array($0).sorted() } ?? []
        observation.bodyStatusCode = root["statusCode"]?.intValue

        // The v2 API really does return HTTP 200 with a failing statusCode inside the body.
        if let bodyStatus = observation.bodyStatusCode, !(200..<300).contains(bodyStatus) {
            throw CatalogAPIError.apiErrorStatus(bodyStatus)
        }
        guard (200..<300).contains(httpStatus) else {
            // A 4xx is handed back for the caller to interpret (the `q` question), not thrown.
            return Page(records: [], nextCursor: nil, observation: observation)
        }

        guard let (hitsPath, hits) = Self.locateArray(in: root, candidates: hitsPathCandidates) else {
            throw CatalogAPIError.unrecognisedEnvelope(
                observedTopLevelKeys: observation.topLevelKeys)
        }
        observation.hitsPath = hitsPath
        observation.returnedHitCount = hits.count
        observation.totalHits = Self.value(at: "body.hits.total.value", in: root)?.intValue
            ?? Self.value(at: "hits.total.value", in: root)?.intValue
            ?? Self.value(at: "body.hits.total", in: root)?.intValue

        var records: [CatalogJSONValue] = []
        var dropped = 0
        for hit in hits {
            guard let (recordPath, record) = Self.locateObject(
                in: hit, candidates: recordPathCandidates) else {
                dropped += 1
                continue
            }
            if observation.recordPath == nil { observation.recordPath = recordPath }
            records.append(record)
        }
        observation.droppedHitCount = dropped

        // Cursor: the LAST element of the last hit's `sort`. NARA's published example is
        // `[83.65, "417180915"]` — a relevance score followed by the identifier — so `sort[0]` would
        // feed the score back as a cursor. The full array and its arity are reported either way.
        if let sort = hits.last?["sort"]?.arrayValue {
            observation.lastSortArray = sort.compactMap(\.stringValue)
            observation.sortArity = sort.count
        }
        let cursor = observation.lastSortArray.last
        return Page(records: records,
                    nextCursor: (cursor?.isEmpty == false) ? cursor : nil,
                    observation: observation)
    }

    /// Resolves a dotted path to a value.
    static func value(at path: String, in root: CatalogJSONValue) -> CatalogJSONValue? {
        var node: CatalogJSONValue? = root
        for component in path.split(separator: ".") {
            node = node?[String(component)]
            if node == nil { return nil }
        }
        return node
    }

    /// Returns the first candidate path that resolves to an array.
    static func locateArray(
        in root: CatalogJSONValue, candidates: [String]
    ) -> (path: String, array: [CatalogJSONValue])? {
        for path in candidates {
            if let array = value(at: path, in: root)?.arrayValue { return (path, array) }
        }
        return nil
    }

    /// Returns the first candidate path that resolves to an object carrying a `naId`.
    ///
    /// The `naId` requirement matters: `_source` resolves to an object for almost any response shape,
    /// so without it the probe would "succeed" on a wrapper and hand the projector a tree with no
    /// record in it.
    static func locateObject(
        in hit: CatalogJSONValue, candidates: [String]
    ) -> (path: String, object: CatalogJSONValue)? {
        for path in candidates {
            if let object = value(at: path, in: hit),
               object.objectValue != nil,
               object["naId"] != nil {
                return (path, object)
            }
        }
        return nil
    }

    // MARK: Paging

    /// Pages every record for one group at `level`, writing each into `sink`.
    ///
    /// - Parameters:
    ///   - maxRequests: hard ceiling on HTTP calls for this group, so a paging bug cannot drain the
    ///     monthly quota. Counted in requests issued, not pages decoded.
    /// - Returns: records written, requests spent, and the first page's observation.
    @discardableResult
    public func harvestGroup(
        recordGroup: Int,
        level: String?,
        maxRequests: Int,
        sink: (CatalogJSONValue) throws -> Void
    ) async throws -> (recordCount: Int, requestsSpent: Int, observation: APIEnvelopeObservation?) {

        var cursor: String? = nil
        var issuedCursors = Set<String>()
        var recordCount = 0
        var requests = 0
        var duplicates = 0
        var seenNaIds = Set<String>()
        var totalHits: Int?
        var firstObservation: APIEnvelopeObservation?

        while requests < maxRequests {
            let page = try await fetchPage(recordGroup: recordGroup, level: level, cursor: cursor)
            requests += 1
            if firstObservation == nil { firstObservation = page.observation }
            if totalHits == nil { totalHits = page.observation.totalHits }

            // Terminate on RAW hits, not on projected records. The repo's existing client breaks on
            // the post-projection count, so one page whose hits all fail to yield a record reads as
            // end-of-results and truncates the harvest silently.
            if page.observation.returnedHitCount == 0 { break }

            for record in page.records {
                // De-duplicate across pages. The seeded cursor should make overlap impossible, but
                // the survey proved the sort can shift underneath us, and a silently duplicated
                // record inflates the count PAST NARA's own total — which the completeness check,
                // testing only for a shortfall, would wave through.
                guard let naId = record["naId"]?.nonEmptyString else { continue }
                guard seenNaIds.insert(naId).inserted else {
                    duplicates += 1
                    continue
                }
                try sink(record)
                recordCount += 1
            }

            // Stop once we hold everything the API says exists. Without this, an overlapping page
            // sequence keeps paging long after the result set is exhausted.
            if let totalHits, recordCount >= totalHits { break }

            guard let next = page.nextCursor else { break }
            // A non-advancing cursor would page forever, burning quota with nothing to show.
            guard issuedCursors.insert(next).inserted else {
                throw CatalogAPIError.cursorDidNotAdvance(next)
            }
            cursor = next
        }

        if duplicates > 0 {
            log("[RecordGroupCatalogGenerator] RG \(recordGroup): \(duplicates) duplicate record(s) "
                + "across pages were dropped — the API's page ordering is not stable for this query")
        }
        if let totalHits, recordCount < totalHits {
            log("[RecordGroupCatalogGenerator] ⚠ RG \(recordGroup): collected \(recordCount) of "
                + "\(totalHits) records the API reports — this refresh is INCOMPLETE")
        }

        if requests >= maxRequests {
            log("[RecordGroupCatalogGenerator] ⚠ RG \(recordGroup): hit the \(maxRequests)-request "
                + "ceiling for this group; the refresh for it is INCOMPLETE")
        }
        return (recordCount, requests, firstObservation)
    }

    // MARK: Survey

    /// Spends a handful of calls answering the four open questions about the live query shape.
    ///
    /// Deliberately tiny — one page from the smallest record group, plus one page at a larger `limit`
    /// to detect clamping. Everything it learns is printed for paste-back.
    public func survey(recordGroup: Int, level: String?) async throws -> [APIEnvelopeObservation] {
        var out: [APIEnvelopeObservation] = []
        let first = try await fetchPage(recordGroup: recordGroup, level: level, cursor: nil)
        out.append(first.observation)
        // A second page, if there is one, is the only way to learn whether the cursor actually works.
        if let cursor = first.nextCursor {
            let second = try await fetchPage(recordGroup: recordGroup, level: level, cursor: cursor)
            out.append(second.observation)
        }
        return out
    }

    /// One request at a large `limit` against a record group big enough to fill it — the only way to
    /// settle whether `limit` is honoured or clamped.
    ///
    /// A small group cannot answer the question: RG 486 has 11 series, so `limit=100` and `limit=1000`
    /// both return 11 and the "fewer than requested" note is uninformative. RG 59 has ~4,435 series, so
    /// a single request either returns 1,000 (honoured) or fewer (clamped).
    public func surveyPageSizeLimit(recordGroup: Int, level: String?) async throws
        -> APIEnvelopeObservation {
        let probe = CatalogAPIClient(endpoint: endpoint, apiKey: apiKey, pageSize: 1000,
                                    transport: transport, log: log)
        return try await probe.fetchPage(recordGroup: recordGroup, level: level, cursor: nil)
            .observation
    }
}
