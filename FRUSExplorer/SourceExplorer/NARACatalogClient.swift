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
public struct NARACatalogResult: Sendable {
    /// NARA unique identifier.
    public let naId: String
    /// Title of the record series or description.
    public let title: String
    /// Deep-link URL to the NARA Catalog record.
    public let catalogURL: URL
    /// Short description or scope note if available.
    public let scopeNote: String?
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

/// Actor that queries the NARA Catalog API and constructs static NARA URLs.
///
/// ## Authentication
/// The NARA Catalog API requires an `x-api-key` request header. The key is
/// retrieved from `KeychainStore` on each call, so it is always current without
/// requiring the actor to cache it.
///
/// ## RG-59 Central Files (no API call)
/// State Dept. central file identifiers are resolved by constructing a static
/// NARA Catalog search URL. No API key is required for this path.
///
/// ## Endpoints used
/// - Search: `GET https://catalog.archives.gov/api/v1/search`
///   Parameters: `q` (query string), `resultType=description`
///
/// ## Log prefix
/// `[SourceExplorer]`
///
/// Version history:
///   1.0 — Session 23: initial implementation
///   1.1 — Session 94: recordAPICall() now called after each successful NARA API response
///          so the 30-day usage counter in NARAAPIKeyStore is actually populated
public actor NARACatalogClient {

    // MARK: - Dependencies

    private let keychainStore: KeychainStore
    private let urlSession: URLSession

    // MARK: - Constants

    private static let apiBase = "https://catalog.archives.gov/api/v1"
    private static let catalogBase = "https://catalog.archives.gov"

    // RG-59 parent description naId — State Dept. Central Foreign Policy Files series
    private static let rg59NaId = "302028"

    // MARK: - Init

    public init(
        keychainStore: KeychainStore = .shared,
        urlSession: URLSession = .shared
    ) {
        self.keychainStore = keychainStore
        self.urlSession = urlSession
    }

    // MARK: - RG-59 Central Files (static URL — no API call)

    /// Returns the NARA Catalog search URL for the given State Dept. central file identifier.
    ///
    /// No API key is required. The URL opens to a pre-filtered search on the
    /// RG-59 Central Foreign Policy Files parent description.
    public nonisolated func resolveRG59CentralFiles(fileIdentifier: String) -> URL {
        var components = URLComponents(string: "\(Self.catalogBase)/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: fileIdentifier),
            URLQueryItem(name: "f.parentDescriptionNaId", value: Self.rg59NaId),
        ]
        return components.url ?? URL(string: "\(Self.catalogBase)/search?q=\(fileIdentifier)")!
    }

    // MARK: - Lot File Resolution

    /// Queries the NARA Catalog for a State Dept. lot file series record.
    ///
    /// - Parameter lotNumber: e.g. `"61-D 146"`.
    /// - Returns: The best-matching catalog result, or `nil` if none found.
    /// - Throws: `NARACatalogError.missingAPIKey` if no key is stored.
    public func resolveLotFile(lotNumber: String) async throws -> NARACatalogResult? {
        let query = "State Department Lot File \(lotNumber)"
        return try await searchCatalog(query: query)
    }

    // MARK: - Presidential Library Resolution

    /// Queries the NARA Catalog for a Presidential Library file series.
    ///
    /// - Parameters:
    ///   - library: e.g. `"Kennedy Library"`.
    ///   - collection: e.g. `"National Security Files, Vietnam Country Series"`.
    /// - Returns: The best-matching catalog result, or `nil` if none found.
    /// - Throws: `NARACatalogError.missingAPIKey` if no key is stored.
    public func resolvePresidentialLibrary(
        library: String,
        collection: String
    ) async throws -> NARACatalogResult? {
        let query = "\(library) \(collection)"
        return try await searchCatalog(query: query)
    }

    // MARK: - Internal Search

    func searchCatalog(query: String) async throws -> NARACatalogResult? {
        let apiKey = try await fetchAPIKey()

        var components = URLComponents(string: "\(Self.apiBase)/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "resultType", value: "description"),
            URLQueryItem(name: "rows", value: "1"),
        ]
        guard let url = components.url else { throw NARACatalogError.decodingError }

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

        return try decodeResult(from: data)
    }

    // MARK: - JSON Decoding

    private func decodeResult(from data: Data) throws -> NARACatalogResult? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let body = json["body"] as? [String: Any],
              let hits = body["hits"] as? [String: Any],
              let hitArray = hits["hits"] as? [[String: Any]],
              let first = hitArray.first,
              let source = first["_source"] as? [String: Any],
              let record = source["record"] as? [String: Any] else {
            // No results or unexpected shape — return nil rather than throw
            return nil
        }

        let naId = (record["naId"] as? String) ?? (record["naId"] as? Int).map(String.init) ?? ""
        let title = record["title"] as? String ?? ""
        let scopeNote = record["scopeContent"] as? String

        guard !naId.isEmpty else { return nil }

        let catalogURL = URL(string: "\(Self.catalogBase)/id/\(naId)")
            ?? URL(string: Self.catalogBase)!

        return NARACatalogResult(
            naId: naId,
            title: title,
            catalogURL: catalogURL,
            scopeNote: scopeNote
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
