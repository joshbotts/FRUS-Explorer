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
    /// The record's **HMS/MLR Entry Number(s)** — the citation identifier NARA staff ask
    /// researchers to quote when requesting original records (#315).
    ///
    /// Filtered from the response's `variantControlNumbers` by an **exact** match on
    /// `type == "HMS/MLR Entry Number"` (`Self.hmsMlrEntryType`). Exactness is the point:
    /// a real record carries several control-number types, and the neighbours of this one
    /// are precisely the values a researcher must NOT be handed — `"Former HMS/MLR Entry
    /// Number"` (superseded, which this issue calls out by name) and `"HMS Record Entry
    /// ID"` (an internal identifier, e.g. `HS1-301519541`). A substring or prefix test
    /// would sweep both in. Verified against a live record 2026-07-15 (see #315).
    ///
    /// Usually empty or one element; the array admits the multi-entry case rather than
    /// silently keeping the first.
    public let hmsMlrEntryNumbers: [String]

    /// NAID of the record's enclosing **series**, from its ancestor chain (#315).
    ///
    /// Only meaningful for records below series level: NARA's hierarchy is
    /// `recordGroup > series > fileUnit`, so a file unit's distance-1 ancestor is its series.
    /// Verified live 2026-07-15 across three differently-shaped file units — every one
    /// carried a `series` ancestor with its title, in the same response, at no extra cost.
    /// `nil` on a record that *is* the series (its ancestors are the record group / collection).
    public let seriesAncestorNaId: String?
    /// Title of the enclosing series — the **"file series name"** #315 asks to display for
    /// records that are not themselves series. Free: it rides in the same response.
    public let seriesAncestorTitle: String?
    /// The levels of the record's ancestors, outermost value included (e.g.
    /// `["recordGroup", "series"]`, or `["collection", "series"]` for a presidential-library
    /// record). Captured for a data-quality check the ancestor spike surfaced: a lot filed
    /// under RG 59/84 whose chain contains **no** `recordGroup` is a candidate
    /// mis-resolution, because `resolveLotFile`'s last-resort `firstAccepted` fallback
    /// accepts a record with no exposed record group.
    public let ancestorLevels: [String]

    /// The exact `variantControlNumbers.type` that denotes a current HMS/MLR entry number.
    /// Not a prefix and not a pattern — see `hmsMlrEntryNumbers`.
    public static let hmsMlrEntryType = "HMS/MLR Entry Number"
    /// The `levelOfDescription` value denoting a series record.
    public static let seriesLevel = "series"

    public init(
        naId: String,
        title: String,
        levelOfDescription: String? = nil,
        parentFileUnitNaId: String? = nil,
        parentFileUnitTitle: String? = nil,
        recordGroupNumber: String? = nil,
        hmsMlrEntryNumbers: [String] = [],
        seriesAncestorNaId: String? = nil,
        seriesAncestorTitle: String? = nil,
        ancestorLevels: [String] = []
    ) {
        self.naId = naId
        self.title = title
        self.levelOfDescription = levelOfDescription
        self.parentFileUnitNaId = parentFileUnitNaId
        self.parentFileUnitTitle = parentFileUnitTitle
        self.recordGroupNumber = recordGroupNumber
        self.hmsMlrEntryNumbers = hmsMlrEntryNumbers
        self.seriesAncestorNaId = seriesAncestorNaId
        self.seriesAncestorTitle = seriesAncestorTitle
        self.ancestorLevels = ancestorLevels
    }

    /// Extracts the current HMS/MLR entry numbers from a decoded `variantControlNumbers`
    /// list. Factored out so it is unit-testable without a network round trip.
    ///
    /// The result is **naturally sorted** — see `sortedNaturally(_:)`. NARA returns these in
    /// an arbitrary order (measured over the real corpus: 50 of the 61 multi-entry records
    /// come back unsorted), so sorting is what makes the bundled artifact deterministic
    /// rather than a transcript of one response's whims.
    static func hmsMlrEntries(from variants: [(number: String?, type: String?)]) -> [String] {
        sortedNaturally(
            variants
                .filter { $0.type == hmsMlrEntryType }
                .compactMap { $0.number?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }

    /// Sorts entry numbers in **natural** (digit-aware) order, deterministically.
    ///
    /// Plain lexicographic sorting is deterministic but reads as broken to the researcher who
    /// has to scan the list: lot `78D237` carries 30 entry numbers, and lexicographic order
    /// puts `UD-WX 1152` first while burying `UD-WX 54-A` at position 27. Numeric-aware
    /// comparison gives `UD-WX 54-A, UD-WX 253, … UD-WX 1502`, which is the order the numbers
    /// actually mean.
    ///
    /// `locale: nil` is deliberate: locale-aware collation (`localizedStandardCompare`) would
    /// make the bundled artifact depend on the machine that generated it. The `.orderedSame`
    /// tiebreak on the raw string guarantees a total order, so the sort can never be unstable
    /// for values the numeric comparison considers equal (e.g. `UD 007` vs `UD 7`).
    static func sortedNaturally(_ entries: [String]) -> [String] {
        entries.sorted { a, b in
            switch a.compare(b, options: [.numeric], range: nil, locale: nil) {
            case .orderedAscending:  return true
            case .orderedDescending: return false
            case .orderedSame:       return a < b
            }
        }
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

    /// Fetches one record **by NAID** — the enrichment route (#315).
    ///
    /// Why NAID rather than the control-number spellings `resolveLotFile` uses: the NAIDs are
    /// already in the bundled indexes and are stable, whereas the control-number index is not.
    /// A 2026-07-15 spike found that lot `64D171` now matches only its *compact* spelling —
    /// the spaced and mixed forms return zero hits, though they resolved during the June
    /// harvest. Re-running control-number queries to enrich would therefore silently lose
    /// records that are perfectly reachable by the NAID we already hold.
    ///
    /// The plain `records/search?naId=` route returns the full description — including
    /// `variantControlNumbers` — so no record-level endpoint is needed. Verified live against
    /// NAID 40967113 (see #315); the query shape here is exactly the one that spike proved.
    ///
    /// - Returns: the record, or `nil` if the NAID returned no hit. The result is checked to
    ///   have the requested NAID, so a fuzzy or shifted match can never be silently accepted.
    public func fetchRecord(naId: String) async throws -> CatalogRecord? {
        let results = try await search(queryItems: [URLQueryItem(name: "naId", value: naId)])
        return results.first { $0.naId == naId }
    }

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
        // Pick the first result whose own record group matches the expected one. NARA's
        // RG query filter does not constrain free-text results, and the top hit for a lot
        // string is often a giant wrong-RG series (census/military/court) — so we scan the
        // page and take the first RG-59/84 record, not blindly the #1 result.
        //
        // #321: the former last-resort fallback — accept the first record with NO exposed RG —
        // is REMOVED. A record parented by a `collection` rather than a `recordGroup` exposes no
        // RG number, so that fallback let presidential-library staff files (FDR/Ford/Reagan/…)
        // resolve as if they were RG-59/84 lots. Measured precision was 0/16 (every flagged
        // record was wrong), so an unmatched lot now stays honestly UNRESOLVED rather than
        // wrongly resolved. The enrichment pass's `ancestryLacksRecordGroup` flag remains a
        // secondary guard for any bundle harvested before this change.
        func firstAccepted(_ results: [CatalogRecord]) -> CatalogRecord? {
            results.first { $0.recordGroupNumber == recordGroup }
        }
        func cache(_ record: CatalogRecord, _ matchType: String) -> ResolvedLot {
            writeLotCache(LotResolution(naId: record.naId, title: record.title, matchType: matchType),
                          normalized: normalized, recordGroup: recordGroup)
            return ResolvedLot(record: record, matchType: matchType)
        }

        // Exact match on NARA's indexed control number, across spellings. The bundled
        // index is control-only: a free-text phrase fallback was tried but produced mostly
        // false positives even after RG verification (RG-59/84 records that coincidentally
        // contain the lot token), which is unacceptable for a trusted, unattended index.
        // The app keeps its live phrase fallback at runtime for bundle misses, where a
        // human evaluates the result.
        for form in Self.lotVariants(normalized) {
            if let record = firstAccepted(try await searchVariant(form, recordGroup: recordGroup)) {
                return cache(record, "control")
            }
        }
        writeLotCache(LotResolution(naId: "", title: "", matchType: nil),
                      normalized: normalized, recordGroup: recordGroup)
        return nil
    }

    // MARK: Record-group resolution

    /// One cached RG resolution. `naId` empty marks a confirmed miss (so it isn't re-queried).
    private struct RGResolution: Codable { let naId: String; let title: String }

    /// Resolves a record-group *number* (`"59"`, `"84"`, `"330"`) to its own NARA Catalog
    /// record-group record (NAID + title). Used to give a volume's `<hi rend="strong">`
    /// record-group headers a catalog link.
    ///
    /// Query shape (confirmed against the live v2 API, 2026-07): the record-group node is
    /// found by filtering to `levelOfDescription=recordGroup` (a top-level facet — *not*
    /// `description.levelOfDescription`) and narrowing by number, then by the heading's title
    /// text as a fallback. **Only a `recordGroup`-level hit is accepted** — never a descendant
    /// series/item — so a header is left unresolved rather than mislinked. An unconstrained
    /// `description.recordGroupNumber` is rejected by the API, so it is always paired with the
    /// level filter. Every outcome (hit or confirmed miss) is cached per RG number.
    ///
    /// - Parameter title: the heading's descriptive text (e.g. "Records of the Department of
    ///   State"), used as a relevance fallback when the numeric filter finds nothing.
    public func resolveRecordGroup(number: String, title: String? = nil,
                                   retryMisses: Bool = false) async throws -> CatalogRecord? {
        let rg = number.trimmingCharacters(in: .whitespaces)
        guard !rg.isEmpty else { return nil }
        if let cached = cachedRG(number: rg), !refresh {
            if cached.naId.isEmpty {
                if !retryMisses { return nil }
            } else {
                return CatalogRecord(naId: cached.naId, title: cached.title,
                                     levelOfDescription: "recordGroup", recordGroupNumber: rg)
            }
        }
        // Primary: exact numeric filter at the record-group level. Confirmed against the live
        // v2 API (2026-07): `recordGroupNumber` is the top-level facet (NO `description.`
        // prefix — the prefixed form filters *descendants*, so it was silently ignored on the
        // RG-node query and collapsed every group to the first record-group record). Returns
        // hits:1 for a valid RG (RG 59 → 388, RG 84 → 413).
        var hit = try? await recordGroupHit(queryItems: [
            URLQueryItem(name: "recordGroupNumber", value: rg),
            URLQueryItem(name: "levelOfDescription", value: "recordGroup"),
            URLQueryItem(name: "rows", value: "3"),
        ])
        // Fallback: title relevance among record-group-level nodes. Strip the leading
        // "Record Group N," / "RG N," from the heading so the query targets the descriptive
        // title (e.g. "Records of the Department of State") rather than the number token.
        if hit == nil, let title {
            let q = title.replacingOccurrences(
                of: #"^\s*(record group|rg)\s+\S+[,.:]?\s*"#,
                with: "", options: [.regularExpression, .caseInsensitive])
                .trimmingCharacters(in: .whitespaces)
            if !q.isEmpty {
                hit = try? await recordGroupHit(queryItems: [
                    URLQueryItem(name: "q", value: q),
                    URLQueryItem(name: "levelOfDescription", value: "recordGroup"),
                    URLQueryItem(name: "rows", value: "8"),
                ])
            }
        }
        if let hit {
            writeRGCache(RGResolution(naId: hit.naId, title: hit.title), number: rg)
            return hit
        }
        writeRGCache(RGResolution(naId: "", title: ""), number: rg)
        return nil
    }

    /// Runs a search and returns the first genuine `recordGroup`-level record, or `nil`.
    /// Never falls back to a non-record-group hit (which would mislink a header to a series).
    private func recordGroupHit(queryItems: [URLQueryItem]) async throws -> CatalogRecord? {
        try await search(queryItems: queryItems).first { $0.levelOfDescription == "recordGroup" }
    }

    private func rgCacheURL(number: String) -> URL? {
        cacheDirectory?.appendingPathComponent("rgs", isDirectory: true)
            .appendingPathComponent("\(number).json")
    }
    private func cachedRG(number: String) -> RGResolution? {
        guard let url = rgCacheURL(number: number), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(RGResolution.self, from: data)
    }
    private func writeRGCache(_ resolution: RGResolution, number: String) {
        guard let url = rgCacheURL(number: number) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(resolution) { try? data.write(to: url, options: .atomic) }
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

    /// Rows fetched per lot query — enough to scan past wrong-RG free-text hits to the
    /// genuine RG-59/84 record (the caller selects the first record-group match).
    private static let lotSearchRows = "20"

    private func searchVariant(_ form: String, recordGroup: String) async throws -> [CatalogRecord] {
        try await search(queryItems: [
            URLQueryItem(name: "variantControlNumber_is",       value: form),
            URLQueryItem(name: "description.recordGroupNumber", value: recordGroup),
            URLQueryItem(name: "resultType",                    value: "description"),
            URLQueryItem(name: "rows",                          value: Self.lotSearchRows),
        ])
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
            // Retry transient gateway/throttle errors with exponential backoff.
            let transient: Set<Int> = [429, 502, 503, 504]
            guard transient.contains(http.statusCode), attempt < maxAttempts - 1 else {
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
            // The enclosing series (#315): for a record below series level this is the
            // "file series name" to display. Free — it is already in this response.
            let seriesAncestor = record.ancestors?.first {
                $0.levelOfDescription == CatalogRecord.seriesLevel
            }
            return CatalogRecord(
                naId: naId,
                title: title,
                levelOfDescription: record.levelOfDescription,
                parentFileUnitNaId: parent?.naId?.stringValue,
                parentFileUnitTitle: parent?.title,
                recordGroupNumber: rg,
                hmsMlrEntryNumbers: CatalogRecord.hmsMlrEntries(
                    from: (record.variantControlNumbers ?? []).map { ($0.number, $0.type) }),
                seriesAncestorNaId: seriesAncestor?.naId?.stringValue,
                seriesAncestorTitle: seriesAncestor?.title,
                ancestorLevels: (record.ancestors ?? []).compactMap(\.levelOfDescription))
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
            /// Every control number NARA indexes for this record — lot-file numbers,
            /// declassification project numbers, HMS/MLR entry numbers, and more. Decoded
            /// as of #315; before that this mirror dropped the field, which is why the
            /// entry numbers could not be recovered offline and a re-query was required.
            let variantControlNumbers: [VariantControlNumber]?
        }
        /// One entry of `variantControlNumbers`. `type` is the discriminator that decides
        /// whether `number` is a current HMS/MLR entry number — see
        /// `CatalogRecord.hmsMlrEntryNumbers`.
        struct VariantControlNumber: Decodable {
            let number: String?
            let type: String?
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
