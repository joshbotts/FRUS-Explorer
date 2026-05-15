// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// Errors thrown by `TaxonomyFetcher`.
public enum TaxonomyFetcherError: Error, Sendable {
    case badHTTPStatus(Int)
    case unexpectedResponseType
    case decodingFailed
}

/// Fetches the HTML source of the tag taxonomy page from history.state.gov.
///
/// ## Source URL
/// `https://history.state.gov/tags/all`
///
/// This page lists all volume-level subject tags in a three-level hierarchy
/// (People / Places / Topics → subcategory → individual tag). The page is
/// expected to be UTF-8 encoded HTML.
///
/// Version history:
///   1.0 — Session 02: initial implementation
public struct TaxonomyFetcher {

    public static let taxonomyURL = "https://history.state.gov/tags/all"

    private init() {}

    /// Fetches the taxonomy page and returns its HTML content as a `String`.
    ///
    /// - Parameters:
    ///   - urlString: The URL to fetch. Defaults to `taxonomyURL`.
    ///   - session: URLSession to use. Defaults to `.shared`.
    /// - Returns: UTF-8 decoded HTML string.
    public static func fetch(
        urlString: String = taxonomyURL,
        session: URLSession = .shared
    ) async throws -> String {
        guard let url = URL(string: urlString) else {
            preconditionFailure("[TaxonomyGenerator] Invalid taxonomy URL: \(urlString)")
        }

        var request = URLRequest(url: url)
        request.setValue("FRUSExplorer/TaxonomyGenerator 2.0", forHTTPHeaderField: "User-Agent")

        #if DEBUG
        print("[TaxonomyGenerator] Fetching taxonomy from \(urlString)")
        #endif

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw TaxonomyFetcherError.unexpectedResponseType
        }
        guard (200..<300).contains(http.statusCode) else {
            throw TaxonomyFetcherError.badHTTPStatus(http.statusCode)
        }
        guard let html = String(data: data, encoding: .utf8) else {
            throw TaxonomyFetcherError.decodingFailed
        }

        return html
    }
}
