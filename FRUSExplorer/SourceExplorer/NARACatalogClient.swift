// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - NARACatalogResult

/// A single result from the NARA Catalog API.
///
/// Version history:
///   1.0 — Session 23: initial implementation
///   1.1 — Session 130: added `recordGroupNumber`, `seriesTitle`, `dateRange`
public struct NARACatalogResult: Sendable {
    /// NARA unique identifier.
    public let naId: String
    /// Title of the record series or description.
    public let title: String
    /// Deep-link URL to the NARA Catalog record.
    public let catalogURL: URL
    /// Short description or scope note if available.
    public let scopeNote: String?
    /// Record group number when the result is RG-specific (e.g. "59").
    public let recordGroupNumber: String?
    /// Series title when available.
    public let seriesTitle: String?
    /// Date range of the records (e.g. "1963–1966").
    public let dateRange: String?
}

// MARK: - NARACatalogError

public enum NARACatalogError: Error, LocalizedError {
    case missingAPIKey
    case networkError(underlying: Error)
    case unexpectedResponse(statusCode: Int)
    case decodingError

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return String(localized: "nara.error.missingKey",
                          defaultValue: "No NARA Catalog API key is stored. Add one in Settings.")
        case .networkError(let e):
            return String(localized: "nara.error.network",
                          defaultValue: "Network error: \(e.localizedDescription)")
        case .unexpectedResponse(let code):
            return String(localized: "nara.error.response",
                          defaultValue: "Unexpected response from NARA Catalog (HTTP \(code)).")
        case .decodingError:
            return String(localized: "nara.error.decoding",
                          defaultValue: "Could not interpret the NARA Catalog response.")
        }
    }
}

// MARK: - NARACatalogClient

/// Actor that queries the NARA Catalog API (v2) and constructs static NARA URLs.
///
/// ## Authentication
/// The NARA Catalog API requires an `x-api-key` request header. The key is
/// retrieved from `KeychainStore` on each call, so it is always current.
///
/// ## RG-59 Central Files (no API call)
/// State Dept. central file identifiers are resolved by constructing a static
/// NARA Catalog search URL. No API key is required for this path.
///
/// ## Endpoints used
/// - v2 Search: `GET https://catalog.archives.gov/api/v2/records/search`
///   Structured filter: `description.recordGroupNumber`, free-text `q`
/// - v1 fallback: `GET https://catalog.archives.gov/api/v1/search` (for backward compat)
///
/// ## Query strategy (matched to ParsedSourceNote cases)
/// | Case | Method | NARA query approach |
/// |---|---|---|
/// | `.naraCollection` | `searchByRecordGroup` | RG filter + series/lot keywords |
/// | `.lotFile` | `searchByLotFile` | Free-text lot number search |
/// | `.presidentialLibrary` | `searchByPresidentialMaterials` | Library + collection keywords |
/// | `.centralFiles` | `resolveRG59CentralFiles` | Static URL (no API key) |
///
/// ## Log prefix
/// `[SourceExplorer]`
///
/// Version history:
///   1.0 — Session 23: initial implementation
///   1.1 — Session 94: recordAPICall() called after each successful NARA API response
///   1.2 — Session 130: v2 API support; structured RG queries; new method overloads
///          matching the expanded ParsedSourceNote cases
public actor NARACatalogClient {

    // MARK: - Dependencies

    private let keychainStore: KeychainStore
    private let urlSession: URLSession

    // MARK: - Constants

    private static let apiV2Base   = "https://catalog.archives.gov/api/v2"
    private static let apiV1Base   = "https://catalog.archives.gov/api/v1"
    private static let catalogBase = "https://catalog.archives.gov"

    /// naId for the RG-59 Central Foreign Policy Files parent description.
    private static let rg59NaId = "302028"

    // MARK: - Init

    public init(
        keychainStore: KeychainStore = .shared,
        urlSession: URLSession = .shared
    ) {
        self.keychainStore = keychainStore
        self.urlSession    = urlSession
    }

    // MARK: - RG-59 Central Files (static URL — no API call)

    /// Returns the NARA Catalog search URL for the given State Dept. central file identifier.
    ///
    /// No API key is required. The URL opens a pre-filtered search on the
    /// RG-59 Central Foreign Policy Files parent description.
    public nonisolated func resolveRG59CentralFiles(fileIdentifier: String) -> URL {
        var components = URLComponents(string: "\(Self.catalogBase)/search")!
        components.queryItems = [
            URLQueryItem(name: "q",                       value: fileIdentifier),
            URLQueryItem(name: "f.parentDescriptionNaId", value: Self.rg59NaId),
        ]
        return components.url ?? URL(string: "\(Self.catalogBase)/search?q=\(fileIdentifier)")!
    }

    // MARK: - Structured Queries (v2 API)

    /// Searches for a specific National Archives series using a record group number
    /// and optional keywords derived from the series name or lot file number.
    ///
    /// This is the primary query path for `.naraCollection` source notes.
    /// Results are ordered by relevance and filtered to `series` / `recordGroup` level.
    ///
    /// - Parameters:
    ///   - recordGroup: e.g. `"59"`, `"330"`, `"306"`.
    ///   - keywords: e.g. `"Central Files"`, `"Lot 64 D 199"`. Passed as free-text `q`.
    ///   - maxResults: Maximum results to return. Default 3 (series-level queries return few useful hits).
    /// - Returns: Matching catalog descriptions at series level.
    public func searchByRecordGroup(
        _ recordGroup: String,
        keywords: String,
        maxResults: Int = 3
    ) async throws -> [NARACatalogResult] {
        let apiKey = try await fetchAPIKey()
        // v2 supports structured filter by record group number alongside free-text query.
        var components = URLComponents(string: "\(Self.apiV2Base)/records/search")!
        components.queryItems = [
            URLQueryItem(name: "q",                              value: keywords),
            URLQueryItem(name: "description.recordGroupNumber",  value: recordGroup),
            URLQueryItem(name: "resultType",                     value: "description"),
            URLQueryItem(name: "rows",                           value: "\(maxResults)"),
        ]
        guard let url = components.url else { throw NARACatalogError.decodingError }
        return try await executeSearch(url: url, apiKey: apiKey)
    }

    /// Searches for a State Department lot file series by lot number.
    ///
    /// Primary query path for `.lotFile` source notes.
    ///
    /// - Parameters:
    ///   - recordGroup: Typically `"59"` for State Dept. lot files.
    ///   - lotNumber: e.g. `"64 D 199"`, `"72D415"`.
    /// - Returns: The best-matching series description, or `nil` if not found.
    public func searchByLotFile(
        recordGroup: String,
        lotNumber: String
    ) async throws -> NARACatalogResult? {
        // Quote the lot number to encourage phrase matching.
        let keywords = "\"\(lotNumber)\""
        let results = try await searchByRecordGroup(recordGroup, keywords: keywords, maxResults: 1)
        return results.first
    }

    /// Queries the NARA Catalog for a State Dept. lot file series record.
    /// Backward-compatible entry point for existing callers.
    ///
    /// - Parameter lotNumber: e.g. `"61-D 146"`.
    public func resolveLotFile(lotNumber: String) async throws -> NARACatalogResult? {
        try await searchByLotFile(recordGroup: "59", lotNumber: lotNumber)
    }

    /// Searches for Presidential Library materials using library name and collection keywords.
    ///
    /// Primary query path for `.presidentialLibrary` source notes. Presidential Library
    /// holdings transferred to NARA can appear in the catalog.
    ///
    /// - Parameters:
    ///   - library: e.g. `"Kennedy Library"`, `"Carter Library"`.
    ///   - collection: e.g. `"National Security Files, Vietnam Country Series"`.
    ///   - maxResults: Default 3.
    public func searchByPresidentialMaterials(
        library: String,
        collection: String,
        maxResults: Int = 3
    ) async throws -> [NARACatalogResult] {
        let apiKey = try await fetchAPIKey()
        let q = [library, collection].filter { !$0.isEmpty }.joined(separator: " ")
        var components = URLComponents(string: "\(Self.apiV2Base)/records/search")!
        components.queryItems = [
            URLQueryItem(name: "q",          value: q),
            URLQueryItem(name: "resultType", value: "description"),
            URLQueryItem(name: "rows",       value: "\(maxResults)"),
        ]
        guard let url = components.url else { throw NARACatalogError.decodingError }
        return try await executeSearch(url: url, apiKey: apiKey)
    }

    /// Backward-compatible Presidential Library resolution.
    public func resolvePresidentialLibrary(
        library: String,
        collection: String
    ) async throws -> NARACatalogResult? {
        try await searchByPresidentialMaterials(library: library, collection: collection, maxResults: 1).first
    }

    // MARK: - Generic Search (v1 fallback)

    /// General-purpose free-text search using the v1 API.
    ///
    /// Used when structured parameters are unavailable. Prefer the structured
    /// v2 methods (`searchByRecordGroup`, `searchByLotFile`) when possible.
    func searchCatalog(query: String) async throws -> NARACatalogResult? {
        let apiKey = try await fetchAPIKey()
        var components = URLComponents(string: "\(Self.apiV1Base)/search")!
        components.queryItems = [
            URLQueryItem(name: "q",          value: query),
            URLQueryItem(name: "resultType", value: "description"),
            URLQueryItem(name: "rows",       value: "1"),
        ]
        guard let url = components.url else { throw NARACatalogError.decodingError }
        return try await executeSearch(url: url, apiKey: apiKey).first
    }

    // MARK: - Internal Execution

    private func executeSearch(url: URL, apiKey: String) async throws -> [NARACatalogResult] {
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        #if DEBUG
        print("[SourceExplorer] NARA Catalog query: \(url)")
        #endif

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw NARACatalogError.networkError(underlying: error)
        }

        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw NARACatalogError.unexpectedResponse(statusCode: httpResponse.statusCode)
        }

        // Record successful API hit for 30-day usage tracking displayed in Settings.
        await MainActor.run { NARAAPIKeyStore.shared.recordAPICall() }

        return decodeResults(from: data)
    }

    // MARK: - JSON Decoding (handles both v1 and v2 response shapes)

    private func decodeResults(from data: Data) -> [NARACatalogResult] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }

        // v2 response: {"opaResponse": {"results": {"result": [...]}}}
        // v1 response: {"body": {"hits": {"hits": [...]}}}
        let records: [[String: Any]]

        if let opaResponse = json["opaResponse"] as? [String: Any],
           let results     = opaResponse["results"] as? [String: Any] {
            // v2 format
            if let resultArray = results["result"] as? [[String: Any]] {
                records = resultArray
            } else if let single = results["result"] as? [String: Any] {
                records = [single]
            } else {
                return []
            }
        } else if let body = json["body"] as? [String: Any],
                  let hits = body["hits"] as? [String: Any],
                  let hitArray = hits["hits"] as? [[String: Any]] {
            // v1 format
            records = hitArray.compactMap { $0["_source"] as? [String: Any] }
                              .compactMap { $0["record"] as? [String: Any] }
        } else {
            return []
        }

        return records.compactMap { buildResult(from: $0) }
    }

    private func buildResult(from record: [String: Any]) -> NARACatalogResult? {
        // Field names vary between v1 and v2 responses
        let naId: String
        if let id = record["naId"] as? String, !id.isEmpty {
            naId = id
        } else if let id = record["naId"] as? Int {
            naId = String(id)
        } else if let desc = record["description"] as? [String: Any],
                  let id = desc["naId"] as? String {
            naId = id
        } else {
            return nil
        }

        let title = record["title"] as? String
            ?? (record["description"] as? [String: Any])?["title"] as? String
            ?? ""

        let scopeNote = record["scopeContent"] as? String
            ?? (record["description"] as? [String: Any])?["scopeAndContentNote"] as? String

        let rgNumber = record["recordGroupNumber"].flatMap { "\($0)" }
            ?? (record["description"] as? [String: Any])?["recordGroupNumber"].flatMap { "\($0)" }

        let seriesTitle = record["seriesTitle"] as? String
            ?? (record["description"] as? [String: Any])?["seriesTitle"] as? String

        let dateRange: String?
        if let coverageStartDate = record["coverageStartDate"] as? String,
           let coverageEndDate   = record["coverageEndDate"]   as? String {
            let start = String(coverageStartDate.prefix(4))
            let end   = String(coverageEndDate.prefix(4))
            dateRange = start == end ? start : "\(start)–\(end)"
        } else {
            dateRange = nil
        }

        let catalogURL = URL(string: "\(Self.catalogBase)/id/\(naId)")
            ?? URL(string: Self.catalogBase)!

        return NARACatalogResult(
            naId: naId, title: title, catalogURL: catalogURL,
            scopeNote: scopeNote, recordGroupNumber: rgNumber,
            seriesTitle: seriesTitle, dateRange: dateRange
        )
    }

    // MARK: - API Key

    private func fetchAPIKey() async throws -> String {
        guard let key = try await keychainStore.getNARACatalogAPIKey(), !key.isEmpty else {
            throw NARACatalogError.missingAPIKey
        }
        return key
    }

    /// Returns `true` if an API key is currently stored in the keychain.
    public func hasAPIKey() async -> Bool {
        (try? await keychainStore.getNARACatalogAPIKey() != nil) ?? false
    }
}
