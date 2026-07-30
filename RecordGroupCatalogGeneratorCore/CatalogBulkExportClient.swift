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

// MARK: - CatalogBulkTransport

/// The one network operation this harvester performs: fetch the whole body of an HTTPS URL.
///
/// Abstracted so the entire pipeline — listing, sharding, streaming, projection, census, writing —
/// is exercised by tests with no network at all. The repo has no `URLProtocol` stub anywhere and
/// its existing catalog client leaves `session:` injectable but untested, so end-to-end coverage of
/// paging and caching has never existed here; a one-method protocol is the cheapest way to change
/// that without inventing a stubbing framework.
public protocol CatalogBulkTransport: Sendable {
    /// Fetches the complete body of `url`, or throws.
    func body(of url: URL) async throws -> Data
}

// MARK: - URLSessionBulkTransport

/// The live transport: plain unauthenticated HTTPS GETs against NARA's public S3 bucket, with
/// bounded retry on transient failures.
///
/// No credentials and no API key — the bucket is public (`s3:GetObject`/`s3:ListBucket` for
/// everyone), which is the property this whole design rests on.
public struct URLSessionBulkTransport: CatalogBulkTransport {

    private let session: URLSession
    private let maxAttempts: Int
    private let throttleNanoseconds: UInt64

    /// - Parameters:
    ///   - session: URLSession to use.
    ///   - maxAttempts: Total attempts per URL, including the first.
    ///   - throttleMilliseconds: Delay before every request. S3 does not throttle the way the
    ///     Catalog API does (whose comments record "a wall of 503s" under rapid fire), so this
    ///     defaults to 0 — but it is here because the same knob was needed once already.
    public init(session: URLSession = .shared,
                maxAttempts: Int = 4,
                throttleMilliseconds: UInt64 = 0) {
        self.session = session
        self.maxAttempts = max(1, maxAttempts)
        self.throttleNanoseconds = throttleMilliseconds * 1_000_000
    }

    public func body(of url: URL) async throws -> Data {
        var lastError: Error = CatalogBulkError.exhaustedRetries(url.absoluteString, 0)
        for attempt in 0..<maxAttempts {
            if throttleNanoseconds > 0 { try? await Task.sleep(nanoseconds: throttleNanoseconds) }
            do {
                var request = URLRequest(url: url)
                request.setValue("FRUSExplorer/RecordGroupCatalogGenerator 1.0",
                                 forHTTPHeaderField: "User-Agent")
                // 10 minutes: a single RG-59 shard is ~44 MB and a slow link legitimately needs
                // minutes for it. The default 60 s would turn a slow connection into a hard
                // failure part-way through a 400-shard group.
                request.timeoutInterval = 600
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw CatalogBulkError.unexpectedResponseType(url.absoluteString)
                }
                guard (200..<300).contains(http.statusCode) else {
                    throw CatalogBulkError.badHTTPStatus(url.absoluteString, http.statusCode)
                }
                return data
            } catch {
                lastError = error
                // Only a transport-level or 5xx/429 failure is worth retrying; a 403/404 means the
                // key does not exist and retrying just wastes time.
                if case CatalogBulkError.badHTTPStatus(_, let status) = error,
                   ![429, 500, 502, 503, 504].contains(status) {
                    throw error
                }
                guard attempt < maxAttempts - 1 else { break }
                let backoffMs = UInt64(500 * (1 << attempt))   // 0.5s, 1s, 2s
                try? await Task.sleep(nanoseconds: backoffMs * 1_000_000)
            }
        }
        throw lastError
    }
}

// MARK: - CatalogBulkError

/// A bulk-export transport or listing failure.
public enum CatalogBulkError: Error, Sendable, Equatable, CustomStringConvertible {
    case invalidURL(String)
    case badHTTPStatus(String, Int)
    case unexpectedResponseType(String)
    case exhaustedRetries(String, Int)
    case emptyShardListing(Int)

    public var description: String {
        switch self {
        case .invalidURL(let s):              return "Could not build a URL from '\(s)'"
        case .badHTTPStatus(let s, let code): return "HTTP \(code) for \(s)"
        case .unexpectedResponseType(let s):  return "Non-HTTP response for \(s)"
        case .exhaustedRetries(let s, let n): return "Gave up on \(s) after \(n) attempts"
        case .emptyShardListing(let rg):
            return "RG \(rg): the bulk export lists no shards — check the record group number"
        }
    }
}

// MARK: - BulkShard

/// One JSONL object in NARA's export.
public struct BulkShard: Sendable, Equatable {
    /// Full S3 key, e.g. `descriptions/record-groups/rg_486/rg_486-3.jsonl`.
    public let key: String
    /// Object size in bytes, from the listing.
    public let size: Int
    /// `Last-Modified` from the listing — the export snapshot date, recorded in the manifest so a
    /// consumer can tell how stale the index is. Measured 2026-04-09 for the current snapshot.
    public let lastModified: String?
    /// S3 ETag, recorded for provenance.
    public let eTag: String?

    public init(key: String, size: Int, lastModified: String? = nil, eTag: String? = nil) {
        self.key = key
        self.size = size
        self.lastModified = lastModified
        self.eTag = eTag
    }

    /// The trailing shard index (`…-3.jsonl` → 3), used to sort a listing numerically.
    ///
    /// Necessary because S3 lists keys **lexicographically**, which interleaves the shards
    /// (`rg_486-1`, `rg_486-10`, `rg_486-11`, `rg_486-2`, …). Harvest order must be numeric for
    /// checkpoint ranges to mean what they say.
    public var shardIndex: Int {
        guard let dash = key.lastIndex(of: "-") else { return 0 }
        let tail = key[key.index(after: dash)...]
        let digits = tail.prefix { $0.isNumber }
        return Int(digits) ?? 0
    }
}

// MARK: - CatalogBulkExportClient

/// Lists and streams NARA's public bulk-export shards.
///
/// ## The source
/// ```
/// https://nara-national-archives-catalog.s3.us-east-2.amazonaws.com/
///     descriptions/record-groups/rg_<N>/rg_<N>-<1…400>.jsonl
///     authority-records/{organization,person,…}/<type>-<1…400>.jsonl
/// ```
/// Public, unauthenticated, listable. Each line is one JSON object shaped
/// `{"record": { … }}` — the same object the live API returns at `_source.record`.
///
/// ## Why this rather than the Catalog API
/// Three reasons, in order of weight:
/// 1. **No API key.** The v2 search API rejects unauthenticated requests (it serves the site's
///    HTML shell), and its documented quota is 10,000 queries/month. The bucket has neither
///    requirement, so this harvest can be run and verified today.
/// 2. **Every level in one pass.** The shards interleave series, file units and items, so the
///    owner's "file units per record group later" is a filter change, not a second harvest
///    design.
/// 3. **It carries its own completeness check.** Each group's `recordGroup`-level record has a
///    `seriesCount` field — NARA's own count — so a short harvest is detectable without an
///    external table. Verified on RG 486: `seriesCount: 11`, and exactly 11 series in the shards.
///
/// The cost is bandwidth: series are scattered evenly across every shard (RG 59 shard 1, 200 and
/// 400 each hold 7–10 series per 3 MB), so a series-only harvest still streams the whole group.
/// RG 59 is 17.2 GB of the ~22 GB total. There is no gzip on the objects. Hence the per-group
/// selection, the byte budget and the checkpointing.
///
/// ## Log prefix
/// `[RecordGroupCatalogGenerator]`
///
/// Version history:
///   1.0 — Session 2026-07-29: initial implementation
public struct CatalogBulkExportClient: Sendable {

    /// Public HTTPS origin for the bucket. Region-qualified because the bare
    /// `nara-national-archives-catalog.s3.amazonaws.com` form relies on a redirect.
    public static let defaultBaseURL = "https://nara-national-archives-catalog.s3.us-east-2.amazonaws.com"

    /// Prefix holding one record group's description shards.
    public static func descriptionPrefix(recordGroup: Int) -> String {
        "descriptions/record-groups/rg_\(recordGroup)/"
    }

    /// Prefix holding one authority-record kind's shards.
    public static func authorityPrefix(kind: String) -> String {
        "authority-records/\(kind)/"
    }

    private let baseURL: String
    private let transport: any CatalogBulkTransport

    public init(baseURL: String = CatalogBulkExportClient.defaultBaseURL,
                transport: any CatalogBulkTransport) {
        self.baseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        self.transport = transport
    }

    // MARK: Listing

    /// Lists every object under `prefix`, following continuation tokens.
    ///
    /// Returns shards sorted by ``BulkShard/shardIndex`` then key, so harvest order is numeric and
    /// deterministic rather than S3's lexicographic order.
    public func listShards(prefix: String) async throws -> [BulkShard] {
        var shards: [BulkShard] = []
        var continuationToken: String? = nil

        repeat {
            var components = URLComponents(string: baseURL + "/")
            var items = [
                URLQueryItem(name: "list-type", value: "2"),
                URLQueryItem(name: "prefix", value: prefix),
                URLQueryItem(name: "max-keys", value: "1000"),
            ]
            if let continuationToken {
                items.append(URLQueryItem(name: "continuation-token", value: continuationToken))
            }
            components?.queryItems = items
            guard let url = components?.url else {
                throw CatalogBulkError.invalidURL(baseURL + " " + prefix)
            }

            let xml = try await transport.body(of: url)
            let page = S3ListingParser.parse(xml)
            // Directory-marker keys (the prefix itself, size 0) are not shards.
            shards.append(contentsOf: page.shards.filter {
                $0.key != prefix && $0.size > 0 && $0.key.hasSuffix(".jsonl")
            })
            continuationToken = page.isTruncated ? page.nextContinuationToken : nil
        } while continuationToken != nil

        return shards.sorted { ($0.shardIndex, $0.key) < ($1.shardIndex, $1.key) }
    }

    /// Lists one record group's description shards, throwing if the group has none (which almost
    /// always means the number is wrong — a real group always has at least its own node).
    public func listDescriptionShards(recordGroup: Int) async throws -> [BulkShard] {
        let shards = try await listShards(prefix: Self.descriptionPrefix(recordGroup: recordGroup))
        guard !shards.isEmpty else { throw CatalogBulkError.emptyShardListing(recordGroup) }
        return shards
    }

    // MARK: Streaming

    /// Fetches one shard and hands each decoded record to `body`, in file order.
    ///
    /// Records are streamed rather than accumulated: a shard is up to ~44 MB and RG 256's
    /// individual file-unit records run to megabytes each, so nothing here holds more than one
    /// shard's bytes plus one record's tree.
    ///
    /// A line that fails to decode is reported through `onMalformedLine` and skipped rather than
    /// aborting the shard — one bad line in a 17 GB group must not cost the whole harvest — but it
    /// is counted, so "we skipped 40,000 lines" can never pass for a clean run.
    ///
    /// - Returns: the raw byte count consumed, for the budget ledger.
    @discardableResult
    public func streamRecords(
        shard: BulkShard,
        onMalformedLine: (Int, Error) -> Void = { _, _ in },
        body: (CatalogJSONValue) throws -> Void
    ) async throws -> Int {
        guard let url = URL(string: baseURL + "/" + shard.key) else {
            throw CatalogBulkError.invalidURL(shard.key)
        }
        let data = try await transport.body(of: url)
        try Self.forEachRecord(inNDJSON: data, onMalformedLine: onMalformedLine, body: body)
        return data.count
    }

    /// Splits NDJSON bytes on newlines and decodes each line.
    ///
    /// Factored out and internal so the line splitter and envelope unwrapping are testable against
    /// literal bytes — including the awkward cases: no trailing newline, CRLF, blank lines, and a
    /// line that is valid JSON but not an object.
    static func forEachRecord(
        inNDJSON data: Data,
        onMalformedLine: (Int, Error) -> Void = { _, _ in },
        body: (CatalogJSONValue) throws -> Void
    ) throws {
        var lineNumber = 0
        var start = data.startIndex
        let newline = UInt8(0x0A)
        let carriageReturn = UInt8(0x0D)

        while start < data.endIndex {
            let end = data[start...].firstIndex(of: newline) ?? data.endIndex
            var lineEnd = end
            // Tolerate CRLF: trim a trailing \r so the JSON decoder is not handed one.
            if lineEnd > start, data[data.index(before: lineEnd)] == carriageReturn {
                lineEnd = data.index(before: lineEnd)
            }
            if lineEnd > start {
                lineNumber += 1
                let line = data[start..<lineEnd]
                // Decode and consume are deliberately separated. A single `do` around both would
                // catch errors thrown by `body` — a failed NDJSON write, say — and report them
                // through `onMalformedLine` as though NARA had sent a bad line, while the harvest
                // carried on and checkpointed the shard complete. That turns silent data loss into a
                // reassuring "3 malformed source lines" note. Only decode failures are tolerated
                // here; anything `body` throws propagates and aborts the shard.
                var decoded: CatalogJSONValue?
                do {
                    decoded = try CatalogJSONValue.decodeRecordLine(Data(line))
                } catch {
                    onMalformedLine(lineNumber, error)
                    decoded = nil
                }
                if let record = decoded { try body(record) }
            }
            guard end < data.endIndex else { break }
            start = data.index(after: end)
        }
    }
}

// MARK: - S3ListingParser

/// Minimal parser for the S3 `ListObjectsV2` XML response.
///
/// Hand-rolled rather than `XMLParser`-delegate-based because the shape needed is four element
/// names deep in a flat list, and a 40-line scanner is easier to verify than a delegate with
/// mutable parse state. Only the elements the harvester uses are recognised.
struct S3ListingParser {

    struct Page: Equatable {
        var shards: [BulkShard] = []
        var isTruncated = false
        var nextContinuationToken: String? = nil
    }

    /// Parses one listing page.
    static func parse(_ data: Data) -> Page {
        let xml = String(decoding: data, as: UTF8.self)
        var page = Page()
        page.isTruncated = value(of: "IsTruncated", in: xml)?.lowercased() == "true"
        page.nextContinuationToken = value(of: "NextContinuationToken", in: xml)

        for contents in elements(named: "Contents", in: xml) {
            guard let key = value(of: "Key", in: contents) else { continue }
            page.shards.append(BulkShard(
                key: decodeEntities(key),
                size: value(of: "Size", in: contents).flatMap { Int($0) } ?? 0,
                lastModified: value(of: "LastModified", in: contents),
                // The ETag arrives entity-escaped AND quote-wrapped (`&quot;abc123&quot;`), so the
                // entities must be decoded before the quotes are trimmed — trimming first leaves
                // the literal `&quot;` in place, which is what this did until a test caught it.
                eTag: value(of: "ETag", in: contents)
                    .map(decodeEntities)?
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))))
        }
        return page
    }

    /// Returns the text of the first `<name>…</name>` in `xml`.
    private static func value(of name: String, in xml: String) -> String? {
        guard let open = xml.range(of: "<\(name)>"),
              let close = xml.range(of: "</\(name)>", range: open.upperBound..<xml.endIndex)
        else { return nil }
        return String(xml[open.upperBound..<close.lowerBound])
    }

    /// Returns the inner text of every `<name>…</name>` in `xml`.
    private static func elements(named name: String, in xml: String) -> [String] {
        var out: [String] = []
        var cursor = xml.startIndex
        while let open = xml.range(of: "<\(name)>", range: cursor..<xml.endIndex),
              let close = xml.range(of: "</\(name)>", range: open.upperBound..<xml.endIndex) {
            out.append(String(xml[open.upperBound..<close.lowerBound]))
            cursor = close.upperBound
        }
        return out
    }

    /// Decodes the five XML predefined entities. S3 escapes keys, and an unescaped `&amp;` in a
    /// key would produce a URL that 404s.
    private static func decodeEntities(_ s: String) -> String {
        s.replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
}
