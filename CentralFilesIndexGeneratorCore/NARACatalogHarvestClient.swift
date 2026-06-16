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

// MARK: - CatalogRecord

/// A single descendant record returned by the NARA Catalog v2 search.
///
/// `naId` and `title` identify the record; the catalog deep link is derived from `naId`.
/// `levelOfDescription` and the parent file-unit (from `ancestors`, distance 1) let the
/// Phase 2 builder reconstruct the series → file-unit (country) → item (roll) hierarchy.
public struct CatalogRecord: Sendable, Equatable {
    /// NARA unique identifier (always stringified, even when the API returns a number).
    public let naId: String
    /// Record title (e.g. `Numerical File: 7179-7187`).
    public let title: String
    /// `series` / `fileUnit` / `item`, when present.
    public let levelOfDescription: String?
    /// NAID of the immediate parent file unit (ancestor at distance 1), when present.
    public let parentFileUnitNaId: String?
    /// Title of the immediate parent file unit, when present.
    public let parentFileUnitTitle: String?
    /// The record's own record group number (from its `recordGroup`-level ancestor), used
    /// to verify a lot-file match really belongs to RG 59/84 rather than a coincidental
    /// free-text hit in another record group (census, military, court records).
    public let recordGroupNumber: String?

    public init(
        naId: String,
        title: String,
        levelOfDescription: String? = nil,
        parentFileUnitNaId: String? = nil,
        parentFileUnitTitle: String? = nil,
        recordGroupNumber: String? = nil
    ) {
        self.naId = naId
        self.title = title
        self.levelOfDescription = levelOfDescription
        self.parentFileUnitNaId = parentFileUnitNaId
        self.parentFileUnitTitle = parentFileUnitTitle
        self.recordGroupNumber = recordGroupNumber
    }
}

// MARK: - NARACatalogHarvestError

public enum NARACatalogHarvestError: Error, Sendable {
    case missingAPIKey
    case badHTTPStatus(Int)
    case apiErrorStatus(Int)
    case unexpectedResponseType
    case invalidURL
}

// MARK: - NARACatalogHarvestClient

/// Enumerates all digitized descendant records under a NARA Catalog series, paging
/// through the v2 search API and caching every raw page to disk.
///
/// ## Request shape (matches NARA's own bulk-download scripts)
/// ```
/// GET https://catalog.archives.gov/api/v2/records/search
///     ?limit=<n>&searchAfter=<cursor>&availableOnline=true&ancestorNaId=<series>
/// header: x-api-key: <CATALOG_API_KEY>
/// ```
/// Pagination is cursor-based: each page's last hit carries a `sort` array whose first
/// element becomes the next request's `searchAfter`; the first request uses `*`.
///
/// ## Disk caching (required)
/// The initial harvest is large (the Numerical File alone is ~1,241 rolls) and the
/// NARA Catalog is "flaky" under load, so every raw page response is written to
/// `cacheDirectory` keyed by `<ancestorNaId>_<pageIndex>.json`. On a re-run the cached
/// page is read instead of re-querying, so parser iteration costs zero API calls. Pass
/// `refresh: true` to bypass the cache and re-fetch.
///
/// ## Rate limits
/// NARA's default is 10,000 queries/month per key; a higher limit was granted
/// (2026-06-12) for the one-time harvest. The cache makes repeated development runs free.
///
/// ## Log prefix
/// `[CentralFilesIndexGenerator]`
///
/// Version history:
///   1.0 — Session 2026-06-15: initial implementation
public actor NARACatalogHarvestClient {

    // MARK: Constants

    private static let searchEndpoint = "https://catalog.archives.gov/api/v2/records/search"

    /// Base for roll/item catalog deep links.
    public static let catalogIDBase = "https://catalog.archives.gov/id/"

    // MARK: Dependencies

    private let apiKey: String
    private let pageSize: Int
    private let cacheDirectory: URL?
    private let refresh: Bool
    private let session: URLSession

    /// Creates a harvest client.
    ///
    /// - Parameters:
    ///   - apiKey: NARA Catalog API key. Read from `CATALOG_API_KEY` by the runner.
    ///   - pageSize: Rows per request. NARA's scripts use 25; the first survey run can
    ///     try a larger value (e.g. 100) to cut enumeration cost — confirm the API
    ///     accepts it by inspecting the cached page sizes.
    ///   - cacheDirectory: Directory for raw page JSON. `nil` disables caching.
    ///   - refresh: When `true`, ignore cached pages and re-fetch from the network.
    ///   - session: URLSession to use. Defaults to `.shared`.
    public init(
        apiKey: String,
        pageSize: Int = 25,
        cacheDirectory: URL? = nil,
        refresh: Bool = false,
        session: URLSession = .shared
    ) {
        self.apiKey = apiKey
        self.pageSize = pageSize
        self.cacheDirectory = cacheDirectory
        self.refresh = refresh
        self.session = session
    }

    // MARK: Enumeration

    /// Enumerates every digitized (`availableOnline=true`) descendant of `ancestorNaId`.
    ///
    /// Pages until a request returns no hits. Each page is cached to disk.
    ///
    /// - Parameter ancestorNaId: The series NAID to enumerate (e.g. `654171`).
    /// - Returns: All descendant records, in catalog sort order.
    public func enumerateDescendants(ancestorNaId: String) async throws -> [CatalogRecord] {
        var records: [CatalogRecord] = []
        var searchAfter = "*"
        var pageIndex = 0

        while true {
            let data = try await fetchPage(ancestorNaId: ancestorNaId,
                                           searchAfter: searchAfter,
                                           pageIndex: pageIndex)
            let page = try Self.decodePage(data)

            if page.records.isEmpty { break }
            records.append(contentsOf: page.records)

            guard let cursor = page.nextCursor else { break }
            searchAfter = cursor
            pageIndex += 1

            #if DEBUG
            print("[CentralFilesIndexGenerator] page \(pageIndex): \(records.count) records so far")
            #endif
        }

        return records
    }

    // MARK: Page fetch (with cache)

    /// Returns the raw JSON bytes for one page, reading from / writing to the cache.
    private func fetchPage(ancestorNaId: String, searchAfter: String, pageIndex: Int) async throws -> Data {
        if let cached = cachedPage(ancestorNaId: ancestorNaId, pageIndex: pageIndex), !refresh {
            return cached
        }

        guard var components = URLComponents(string: Self.searchEndpoint) else {
            throw NARACatalogHarvestError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "limit",          value: "\(pageSize)"),
            URLQueryItem(name: "searchAfter",     value: searchAfter),
            URLQueryItem(name: "availableOnline", value: "true"),
            URLQueryItem(name: "ancestorNaId",    value: ancestorNaId),
        ]
        guard let url = components.url else { throw NARACatalogHarvestError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("FRUSExplorer/CentralFilesIndexGenerator 1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NARACatalogHarvestError.unexpectedResponseType
        }
        guard (200..<300).contains(http.statusCode) else {
            throw NARACatalogHarvestError.badHTTPStatus(http.statusCode)
        }

        writeCache(data, ancestorNaId: ancestorNaId, pageIndex: pageIndex)
        return data
    }

    // MARK: Lot-file resolution (variantControlNumber_is)

    /// How a lot resolved, for the app's confidence cue. `control` is an exact match on
    /// NARA's indexed control number (high confidence); `phrase` is the free-text fallback
    /// (lower confidence — still RG-verified).
    public struct ResolvedLot: Sendable, Equatable {
        public let record: CatalogRecord
        public let matchType: String   // "control" | "phrase"
    }

    /// One cached lot resolution. `naId` empty marks a confirmed miss (so it isn't re-queried).
    private struct LotResolution: Codable { let naId: String; let title: String; let matchType: String? }

    /// Resolves a normalized lot number to its NARA Catalog series record by matching
    /// `variantControlNumber_is` against NARA's indexed lot identifiers — the same approach
    /// the app uses at runtime, but harvested once and bundled.
    ///
    /// Tries the compact, spaced, and mixed spellings (`63D135`, `63 D 135`, `63 D135`);
    /// the first non-empty hit wins. The outcome (hit or confirmed miss) is cached to disk
    /// per lot, so re-runs and partial failures never re-query.
    ///
    /// - Parameter retryMisses: when `true`, a cached *miss* is ignored and re-queried
    ///   (cached hits are still reused) — use after improving the resolver to re-attempt
    ///   only the previously-unresolved lots without re-querying the resolved ones.
    /// - Returns: the resolved record + match type, or `nil` when no spelling matched.
    public func resolveLotFile(normalized: String, recordGroup: String,
                               retryMisses: Bool = false) async throws -> ResolvedLot? {
        if let cached = cachedLot(normalized: normalized, recordGroup: recordGroup), !refresh {
            if cached.naId.isEmpty {
                if !retryMisses { return nil }   // else fall through and re-query
            } else {
                return ResolvedLot(record: CatalogRecord(naId: cached.naId, title: cached.title),
                                   matchType: cached.matchType ?? "control")
            }
        }
        // Accept a candidate only when its own record group matches the expected one — the
        // catalog's RG query filter does not constrain free-text results, so a phrase hit
        // can land on a census/military/court record in another RG. A nil RG (not exposed)
        // is trusted (real lot-file series carry the RG ancestor).
        func accepted(_ record: CatalogRecord?) -> CatalogRecord? {
            guard let record else { return nil }
            if let rg = record.recordGroupNumber, rg != recordGroup { return nil }
            return record
        }
        func cache(_ record: CatalogRecord, _ matchType: String) -> ResolvedLot {
            writeLotCache(LotResolution(naId: record.naId, title: record.title, matchType: matchType),
                          normalized: normalized, recordGroup: recordGroup)
            return ResolvedLot(record: record, matchType: matchType)
        }

        // 1. Exact match on NARA's indexed control number, across spellings.
        for form in Self.lotVariants(normalized) {
            if let record = accepted(try await searchVariant(form, recordGroup: recordGroup)) {
                return cache(record, "control")
            }
        }
        // 2. Free-text phrase fallback (mirrors the app's runtime safety net): the bare,
        //    quoted lot number — compact then spaced — within the record group.
        for phrase in Self.lotVariants(normalized).prefix(2) {  // compact, spaced
            if let record = accepted(try await searchLotPhrase(phrase, recordGroup: recordGroup)) {
                return cache(record, "phrase")
            }
        }
        writeLotCache(LotResolution(naId: "", title: "", matchType: nil),
                      normalized: normalized, recordGroup: recordGroup)
        return nil
    }

    /// Generates compact / spaced / mixed spellings from a compact lot (`63D135`).
    static func lotVariants(_ compact: String) -> [String] {
        guard let r = compact.range(of: #"^(\d{2,3})([A-Z])(\d+)$"#, options: .regularExpression) else {
            return [compact]
        }
        let s = String(compact[r])
        // Re-split via the same pattern groups.
        let scalars = Array(s)
        guard let letterIdx = scalars.firstIndex(where: { $0.isLetter }) else { return [compact] }
        let digits1 = String(scalars[..<letterIdx])
        let letter = String(scalars[letterIdx])
        let digits2 = String(scalars[(letterIdx + 1)...])
        return ["\(digits1)\(letter)\(digits2)",
                "\(digits1) \(letter) \(digits2)",
                "\(digits1) \(letter)\(digits2)"]
    }

    private func searchVariant(_ form: String, recordGroup: String) async throws -> CatalogRecord? {
        try await search(queryItems: [
            URLQueryItem(name: "variantControlNumber_is",       value: form),
            URLQueryItem(name: "description.recordGroupNumber", value: recordGroup),
            URLQueryItem(name: "resultType",                    value: "description"),
            URLQueryItem(name: "rows",                          value: "1"),
        ]).first
    }

    /// Free-text phrase fallback: searches the bare quoted lot number (`"63 D 135"`)
    /// within the record group — the app's runtime safety net for lots not indexed under a
    /// control number.
    private func searchLotPhrase(_ form: String, recordGroup: String) async throws -> CatalogRecord? {
        try await search(queryItems: [
            URLQueryItem(name: "q",                             value: "\"\(form)\""),
            URLQueryItem(name: "description.recordGroupNumber", value: recordGroup),
            URLQueryItem(name: "resultType",                    value: "description"),
            URLQueryItem(name: "rows",                          value: "1"),
        ]).first
    }

    /// Runs a v2 search with retry-and-backoff on transient 503/429 responses.
    private func search(queryItems: [URLQueryItem]) async throws -> [CatalogRecord] {
        guard var components = URLComponents(string: Self.searchEndpoint) else {
            throw NARACatalogHarvestError.invalidURL
        }
        components.queryItems = queryItems
        guard let url = components.url else { throw NARACatalogHarvestError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("FRUSExplorer/CentralFilesIndexGenerator 1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30

        // Gentle baseline throttle on every live lot query — rapid-fire requests drew a
        // wall of 503s from the catalog. Only affects network calls (cached lots skip this).
        try? await Task.sleep(nanoseconds: 60_000_000)  // 60 ms

        let maxAttempts = 4
        var lastStatus = 0
        for attempt in 0..<maxAttempts {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw NARACatalogHarvestError.unexpectedResponseType
            }
            if (200..<300).contains(http.statusCode) {
                return try Self.decodePage(data).records
            }
            lastStatus = http.statusCode
            // Retry transient server/throttle errors with exponential backoff.
            guard http.statusCode == 503 || http.statusCode == 429, attempt < maxAttempts - 1 else {
                throw NARACatalogHarvestError.badHTTPStatus(http.statusCode)
            }
            let backoffMs = UInt64(500 * (1 << attempt))  // 0.5s, 1s, 2s
            try? await Task.sleep(nanoseconds: backoffMs * 1_000_000)
        }
        throw NARACatalogHarvestError.badHTTPStatus(lastStatus)
    }

    private func lotCacheURL(normalized: String, recordGroup: String) -> URL? {
        cacheDirectory?
            .appendingPathComponent("lots", isDirectory: true)
            .appendingPathComponent("\(recordGroup)_\(normalized).json")
    }

    private func cachedLot(normalized: String, recordGroup: String) -> LotResolution? {
        guard let url = lotCacheURL(normalized: normalized, recordGroup: recordGroup),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(LotResolution.self, from: data)
    }

    private func writeLotCache(_ resolution: LotResolution, normalized: String, recordGroup: String) {
        guard let url = lotCacheURL(normalized: normalized, recordGroup: recordGroup) else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(resolution) { try? data.write(to: url, options: .atomic) }
    }

    // MARK: Cache helpers

    private func cacheURL(ancestorNaId: String, pageIndex: Int) -> URL? {
        cacheDirectory?.appendingPathComponent("\(ancestorNaId)_\(pageIndex).json")
    }

    private func cachedPage(ancestorNaId: String, pageIndex: Int) -> Data? {
        guard let url = cacheURL(ancestorNaId: ancestorNaId, pageIndex: pageIndex) else { return nil }
        return try? Data(contentsOf: url)
    }

    private func writeCache(_ data: Data, ancestorNaId: String, pageIndex: Int) {
        guard let url = cacheURL(ancestorNaId: ancestorNaId, pageIndex: pageIndex) else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    // MARK: - Response decoding

    /// One decoded page: its records plus the cursor for the next page (if any).
    struct DecodedPage: Equatable {
        let records: [CatalogRecord]
        let nextCursor: String?
    }

    /// Decodes a raw v2 search response.
    ///
    /// Shape (per NARA's bulk scripts):
    /// ```
    /// { "statusCode": 200,
    ///   "body": { "hits": { "hits": [
    ///       { "_source": { "record": { "naId": 19779414, "title": "Numerical File: 7179-7187" } },
    ///         "sort": [ <cursor> ] } ] } } }
    /// ```
    /// `naId` and the `sort` cursor may be encoded as either numbers or strings; both are
    /// normalised to `String`. Records missing a `naId` or `title` are dropped.
    static func decodePage(_ data: Data) throws -> DecodedPage {
        let decoder = JSONDecoder()
        let response = try decoder.decode(SearchResponse.self, from: data)

        if let status = response.statusCode, !(200..<300).contains(status) {
            throw NARACatalogHarvestError.apiErrorStatus(status)
        }

        let hits = response.body?.hits?.hits ?? []
        let records: [CatalogRecord] = hits.compactMap { hit in
            guard let record = hit._source?.record,
                  let naId = record.naId?.stringValue, !naId.isEmpty,
                  let title = record.title, !title.isEmpty
            else { return nil }
            // The immediate parent file unit is the ancestor at distance 1 whose level is
            // a file unit (the country/post grouping for the 3-level diplomatic series).
            let parent = record.ancestors?.first {
                $0.distance == 1 && $0.levelOfDescription == "fileUnit"
            }
            // The record's record group: the recordGroup-level ancestor's number.
            let rg = record.ancestors?.first {
                $0.levelOfDescription == "recordGroup"
            }?.recordGroupNumber?.stringValue
            return CatalogRecord(
                naId: naId,
                title: title,
                levelOfDescription: record.levelOfDescription,
                parentFileUnitNaId: parent?.naId?.stringValue,
                parentFileUnitTitle: parent?.title,
                recordGroupNumber: rg)
        }
        let nextCursor = hits.last?.sort?.first?.stringValue
        return DecodedPage(records: records, nextCursor: nextCursor)
    }

    // MARK: Decodable mirror of the v2 response

    private struct SearchResponse: Decodable {
        let statusCode: Int?
        let body: Body?
        struct Body: Decodable { let hits: Hits? }
        struct Hits: Decodable { let hits: [Hit]? }
        struct Hit: Decodable {
            let _source: Source?
            let sort: [CatalogScalar]?
        }
        struct Source: Decodable { let record: Record? }
        struct Record: Decodable {
            let naId: CatalogScalar?
            let title: String?
            let levelOfDescription: String?
            let ancestors: [Ancestor]?
        }
        struct Ancestor: Decodable {
            let naId: CatalogScalar?
            let title: String?
            let distance: Int?
            let levelOfDescription: String?
            let recordGroupNumber: CatalogScalar?
        }
    }
}

// MARK: - CatalogScalar

/// Decodes a JSON scalar that may be a string, integer, or floating-point number into a
/// canonical `String`. NARA's API encodes `naId` and `sort` cursors inconsistently.
struct CatalogScalar: Decodable, Equatable {
    let stringValue: String

    init(stringValue: String) { self.stringValue = stringValue }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) {
            stringValue = s
        } else if let i = try? container.decode(Int.self) {
            stringValue = String(i)
        } else if let d = try? container.decode(Double.self) {
            // NARA sort cursors are integral; drop any spurious fractional part.
            stringValue = String(Int(d))
        } else {
            stringValue = ""
        }
    }
}
