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

    public init(
        naId: String,
        title: String,
        levelOfDescription: String? = nil,
        parentFileUnitNaId: String? = nil,
        parentFileUnitTitle: String? = nil
    ) {
        self.naId = naId
        self.title = title
        self.levelOfDescription = levelOfDescription
        self.parentFileUnitNaId = parentFileUnitNaId
        self.parentFileUnitTitle = parentFileUnitTitle
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
            return CatalogRecord(
                naId: naId,
                title: title,
                levelOfDescription: record.levelOfDescription,
                parentFileUnitNaId: parent?.naId?.stringValue,
                parentFileUnitTitle: parent?.title)
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
