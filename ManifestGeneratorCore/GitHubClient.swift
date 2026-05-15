// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// Errors thrown by `GitHubClient`.
public enum GitHubClientError: Error, Sendable {
    case badHTTPStatus(Int)
    case unexpectedResponseType
    case rateLimited(retryAfter: Int?)
}

/// Fetches FRUS volume file listings from the GitHub Contents API.
///
/// The HistoryAtState/frus repository hosts all FRUS volume XML files in a `volumes/`
/// subdirectory. This client retrieves the directory listing to discover filenames, file
/// sizes (used for the download size estimate), SHAs, and download URLs.
///
/// ## API Endpoint
/// ```
/// GET https://api.github.com/repos/HistoryAtState/frus/contents/volumes
/// ```
/// This endpoint returns up to 1,000 entries per request. At ~550 FRUS volumes, no
/// pagination is needed. If the volume count approaches 1,000, add pagination support
/// using the `Link` response header.
///
/// ## Rate Limits
/// Unauthenticated: 60 requests/hour. Authenticated (token in `GITHUB_TOKEN` env var):
/// 5,000 requests/hour. The generator fetches one listing call plus one header fetch per
/// volume (~550 calls total), so a token is required for production use.
///
/// Version history:
///   1.0 — Session 02: initial implementation
public actor GitHubClient {

    public static let volumesEndpoint = "https://api.github.com/repos/HistoryAtState/frus/contents/volumes"
    private static let minimumFileSizeBytes = 20_000

    private let session: URLSession
    private let token: String?

    /// Creates a client.
    ///
    /// - Parameters:
    ///   - session: URLSession to use for requests. Defaults to `.shared`.
    ///   - token: Optional GitHub personal access token. If nil, reads `GITHUB_TOKEN`
    ///     from the environment. Unauthenticated calls are limited to 60/hour.
    public init(session: URLSession = .shared, token: String? = nil) {
        self.session = session
        self.token = token ?? ProcessInfo.processInfo.environment["GITHUB_TOKEN"]
    }

    /// Fetches the volume directory listing and returns entries with `size >= 20,000` bytes.
    ///
    /// Entries smaller than 20 KB are index or placeholder files — not real FRUS volumes —
    /// and are excluded from download functionality per the specification.
    ///
    /// - Returns: Array of `GitHubVolumeEntry`, filtered to `.xml` files ≥ 20 KB.
    public func fetchVolumeEntries() async throws -> [GitHubVolumeEntry] {
        guard let url = URL(string: Self.volumesEndpoint) else {
            preconditionFailure("[ManifestGenerator] Invalid volumes endpoint URL")
        }

        var request = URLRequest(url: url)
        request.setValue("FRUSExplorer/ManifestGenerator 2.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        #if DEBUG
        print("[ManifestGenerator] Fetching volume listing from \(Self.volumesEndpoint)")
        #endif

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw GitHubClientError.unexpectedResponseType
        }
        guard http.statusCode != 429 else {
            let retryAfter = (http.value(forHTTPHeaderField: "Retry-After")).flatMap(Int.init)
            throw GitHubClientError.rateLimited(retryAfter: retryAfter)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw GitHubClientError.badHTTPStatus(http.statusCode)
        }

        let decoder = JSONDecoder()
        let all = try decoder.decode([GitHubVolumeEntry].self, from: data)

        let filtered = all.filter { entry in
            entry.name.hasSuffix(".xml") && entry.size >= Self.minimumFileSizeBytes
        }

        #if DEBUG
        let skipped = all.count - filtered.count
        print("[ManifestGenerator] GitHub listing: \(all.count) total, \(filtered.count) usable, \(skipped) skipped (< 20 KB or non-XML)")
        #endif

        return filtered
    }
}
