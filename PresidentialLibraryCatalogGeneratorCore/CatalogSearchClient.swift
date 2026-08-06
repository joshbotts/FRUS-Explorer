// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import GeneratorKit

// MARK: - CatalogRoute

/// Which NARA endpoint a harvest talks to.
///
/// The two exist because the survey on #681 could only be run keylessly, and the field it found
/// could only be *verified* keylessly. They share one query builder below so a difference between
/// them can only ever be the host and the auth header — never the filter being tested.
public enum CatalogRoute: String, Sendable {

    /// The documented v2 API. Requires `CATALOG_API_KEY`. The default, and the right dependency
    /// for a tool in the repository.
    case apiV2

    /// The catalogue website's own search endpoint, which needs no key.
    ///
    /// **Survey only — not for harvesting.** It is an internal route of a public website: it can
    /// change without notice, and measured, it starts returning the site's HTML shell instead of
    /// JSON once a run has made a few hundred requests. That is the site correctly declining to
    /// be used as a bulk API, and a harvest that ignored it would silently write nothing.
    ///
    /// It is kept because it is how `collectionIdentifier` was **verified** at all (the survey on
    /// #681 had no key), and it stays useful for cheap one-off probes. `LIBRARIES` exists partly
    /// so a single small library can be re-checked through it without a key.
    case publicProxy

    var base: String {
        switch self {
        case .apiV2:       return "https://catalog.archives.gov/api/v2/records/search"
        case .publicProxy: return "https://catalog.archives.gov/proxy/records/search"
        }
    }

    var needsKey: Bool { self == .apiV2 }
}

// MARK: - CatalogSearchClient

/// Pages the NARA Catalog for the records under a `collectionIdentifier`.
public struct CatalogSearchClient: Sendable {

    let route: CatalogRoute
    let apiKey: String?
    /// Seconds to wait between requests. The harvest is ~40 calls, but it is somebody else's
    /// server either way.
    let politenessDelay: Double
    let session: URLSession

    public init(route: CatalogRoute, apiKey: String?, politenessDelay: Double = 0.4,
                session: URLSession = .shared) {
        self.route = route; self.apiKey = apiKey
        self.politenessDelay = politenessDelay; self.session = session
    }

    /// The query for one page. Shared by both routes — see `CatalogRoute`.
    ///
    /// `collectionIdentifier` takes **one value per request**: repeating the parameter returns
    /// HTTP 422, measured. Wildcards are accepted (`LBJ-*`), and a bare prefix is not — the match
    /// is exact unless a `*` says otherwise.
    /// Paging is by **cursor**, not by offset.
    ///
    /// `offset` is not a parameter this endpoint has, and the catalogue *silently ignores*
    /// parameters it does not know — so an offset-paged harvest re-fetches page 1 forever and
    /// stops only when its running total passes the stated one. Measured: a Truman run
    /// "harvested 2000 of 1281", i.e. the same 1000 records twice. The cursor is the `sort`
    /// value of the last hit, seeded `*` on the first request, which is the shape the
    /// record-group harvester's own API survey established.
    static func pageURL(base: String, collectionIdentifier: String, level: String,
                        limit: Int, searchAfter: String) -> URL? {
        var c = URLComponents(string: base)
        c?.queryItems = [
            URLQueryItem(name: "collectionIdentifier", value: collectionIdentifier),
            URLQueryItem(name: "levelOfDescription",   value: level),
            URLQueryItem(name: "limit",                value: "\(limit)"),
            URLQueryItem(name: "searchAfter",          value: searchAfter),
        ]
        return c?.url
    }

    /// Every record at `level` under `collectionIdentifier`, handed to `onPage` a page at a
    /// time and never accumulated here.
    ///
    /// Streaming rather than returning an array is the difference between a bounded harvest and
    /// the record-group harvester's known 18.5 GB peak, which comes from holding a whole group's
    /// projection and encoding it in one `Data`. The biggest library file-unit level here is
    /// ~224,000 records; at a page at a time it costs nothing.
    ///
    /// - Parameters:
    ///   - resumeAfter: cursor from an interrupted run, or `nil` to start at the beginning.
    ///   - onPage: receives each page and the cursor that follows it, so the caller can persist
    ///     both and resume from exactly there.
    /// - Returns: the total the endpoint stated, for the completeness check.
    @discardableResult
    public func streamRecords(
        collectionIdentifier: String,
        level: String,
        limit: Int = 1000,
        resumeAfter: String? = nil,
        alreadyHave: Int = 0,
        onPage: ([[String: Any]], String?) throws -> Void
    ) async throws -> Int? {
        var cursor = resumeAfter ?? "*"
        var stated: Int? = nil
        var count = alreadyHave
        while true {
            guard let url = Self.pageURL(base: route.base, collectionIdentifier: collectionIdentifier,
                                         level: level, limit: limit, searchAfter: cursor) else {
                throw HarvestError("could not build a query URL")
            }
            var request = URLRequest(url: url)
            if let apiKey { request.setValue(apiKey, forHTTPHeaderField: "x-api-key") }
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw HarvestError("no HTTP response for \(collectionIdentifier)/\(level)")
            }
            guard (200..<300).contains(http.statusCode) else {
                throw HarvestError(
                    "HTTP \(http.statusCode) for \(collectionIdentifier)/\(level)"
                    + (route.needsKey && http.statusCode == 403
                       ? " — CATALOG_API_KEY missing or rejected" : ""))
            }
            let (page, total, next) = try Self.decodePage(data)
            stated = stated ?? total
            if page.isEmpty { break }
            count += page.count
            // A cursor that does not advance means the endpoint ignored it — the failure an
            // offset-paged version hid behind a rising count of duplicates.
            guard let next, next != cursor else {
                throw HarvestError(
                    "\(collectionIdentifier)/\(level): the paging cursor did not advance after "
                    + "\(count) records. The endpoint is ignoring `searchAfter`, so this harvest "
                    + "would loop on page 1.")
            }
            try onPage(page, next)
            cursor = next
            if let stated, count >= stated { break }
            if politenessDelay > 0 {
                try await Task.sleep(nanoseconds: UInt64(politenessDelay * 1_000_000_000))
            }
        }
        // The endpoint states how many records match this query, so a disagreement here is
        // arithmetic about OUR paging and nothing else — short means it stopped early, over means
        // it double-counted. That is why this throws while a per-collection shortfall only
        // reports: this check can only fail because of a bug in this file, and it is what caught
        // the offset-paging bug ("harvested 2000 of 1281"). See
        // `PresidentialLibraryCatalog.Collection.isComplete` for the check that cannot.
        if let stated, count != stated {
            throw HarvestError(
                "\(collectionIdentifier)/\(level): harvested \(count) against a stated "
                + "\(stated) — a harvest that does not match NARA's own count must not be written")
        }
        return stated
    }

    /// Unwraps the Elasticsearch envelope both routes return —
    /// `body.hits.hits[]._source.record` — plus the stated total and the next page cursor.
    ///
    /// The cursor is the last hit's `sort` array. Refusing a non-JSON body is not pedantry: the
    /// public-proxy route answers a rate-limited caller with the website's HTML shell under a
    /// 200, and treating that as an empty page would end a harvest early and call it done.
    static func decodePage(_ data: Data) throws -> ([[String: Any]], Int?, String?) {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let body = root["body"] as? [String: Any],
              let hits = body["hits"] as? [String: Any]
        else {
            let head = String(decoding: data.prefix(60), as: UTF8.self)
            throw HarvestError(
                "unrecognised response envelope — got \(head.trimmingCharacters(in: .whitespacesAndNewlines))"
                + (head.contains("<!doctype") ? " (an HTML page, not JSON: the endpoint is "
                   + "refusing this caller — see CatalogRoute.publicProxy)" : ""))
        }
        let total = (hits["total"] as? [String: Any])?["value"] as? Int
        let rows = (hits["hits"] as? [[String: Any]]) ?? []
        let records = rows.compactMap { ($0["_source"] as? [String: Any])?["record"] as? [String: Any] }
        let cursor = (rows.last?["sort"] as? [Any])?
            .map { "\($0)" }.joined(separator: ",")
        return (records, total, (cursor?.isEmpty == false) ? cursor : nil)
    }
}
