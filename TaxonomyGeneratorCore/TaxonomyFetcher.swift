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

/// Fetches a source of the tag taxonomy as text: the page on history.state.gov, or the file the
/// page is drawn from (`TaxonomySource`).
///
/// ## The page
/// `https://history.state.gov/tags/all`
///
/// This page lists all volume-level subject tags in a three-level hierarchy
/// (People / Places / Topics → subcategory → individual tag). The page is
/// expected to be UTF-8 encoded HTML.
///
/// ## The file
/// `taxonomy/taxonomy.xml` in the public HistoryAtState/tags repository, UTF-8 XML, read from
/// the head of the repository's default branch.
///
/// Version history:
///   1.0 — Session 02: initial implementation
///   1.1 — #1622: the address comes from `TaxonomySource`; `taxonomyURL` is the page's
public struct TaxonomyFetcher {

    /// The page's address.
    public static let taxonomyURL = TaxonomySource.page.url

    private init() {}

    /// Fetches a source and returns its content as a `String`.
    ///
    /// - Parameters:
    ///   - urlString: The URL to fetch. Defaults to `taxonomyURL`, the page.
    ///   - session: URLSession to use. Defaults to `.shared`.
    /// - Returns: The UTF-8 decoded text.
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
