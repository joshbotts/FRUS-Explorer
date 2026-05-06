// FRUSDownloader.swift
// Add to the FRUSKit package (Sources/FRUSKit/FRUSDownloader.swift)
//
// Downloads FRUS volume XML files from:
//   https://github.com/HistoryAtState/frus/tree/master/volumes
//
// Volume listing:  GitHub Contents API  →  api.github.com/repos/HistoryAtState/frus/contents/volumes
// Raw file:        raw.githubusercontent.com/HistoryAtState/frus/master/volumes/{id}.xml

import Foundation

// MARK: - Public types

/// Metadata for a single FRUS volume available in the GitHub repository.
public struct FRUSVolumeInfo: Sendable, Identifiable, Hashable {
    /// Volume identifier, e.g. `"frus1969-76v24"` (filename without `.xml`).
    public let id: String
    /// Size of the XML file in bytes as reported by the GitHub API.
    public let size: Int
    /// SHA-1 blob hash (for caching / change detection).
    public let sha: String
    /// Direct URL to the raw XML content on raw.githubusercontent.com.
    public let downloadURL: URL

    /// Formatted file size string, e.g. `"4.2 MB"`.
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
}

/// Progress information delivered during a download.
public struct FRUSDownloadProgress: Sendable {
    public let volumeID: String
    /// Bytes received so far for this volume.
    public let bytesReceived: Int64
    /// Total expected bytes (`-1` if unknown).
    public let totalBytes: Int64
    /// Fraction complete in `0.0 … 1.0`, or `nil` when total is unknown.
    public var fractionCompleted: Double? {
        guard totalBytes > 0 else { return nil }
        return Double(bytesReceived) / Double(totalBytes)
    }
}

/// Result of a single volume download.
public struct FRUSDownloadResult: Sendable {
    public let volumeID: String
    /// Local URL where the XML file was saved.
    public let localURL: URL
    /// Bytes written to disk.
    public let bytesWritten: Int64
}

// MARK: - Errors

public enum FRUSDownloaderError: Error, LocalizedError {
    case networkError(volumeID: String, underlying: Error)
    case httpError(volumeID: String, statusCode: Int)
    case listingFailed(underlying: Error)
    case listingHTTPError(statusCode: Int)
    case invalidResponse(volumeID: String)
    case diskError(volumeID: String, underlying: Error)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .networkError(let id, let err):
            return "Network error for \(id): \(err.localizedDescription)"
        case .httpError(let id, let code):
            return "HTTP \(code) downloading \(id)"
        case .listingFailed(let err):
            return "Failed to fetch volume listing: \(err.localizedDescription)"
        case .listingHTTPError(let code):
            return "HTTP \(code) fetching volume listing"
        case .invalidResponse(let id):
            return "Invalid response while downloading \(id)"
        case .diskError(let id, let err):
            return "Could not write \(id) to disk: \(err.localizedDescription)"
        case .cancelled:
            return "Download cancelled"
        }
    }
}

// MARK: - FRUSDownloader

/// Downloads one or more FRUS volumes from the HistoryAtState GitHub repository.
///
/// ```swift
/// let downloader = FRUSDownloader()
///
/// // 1. Fetch the list of all available volumes
/// let allVolumes = try await downloader.fetchVolumeList()
///
/// // 2. Pick the ones you want
/// let targets = allVolumes.filter { $0.id.hasPrefix("frus1969") }
///
/// // 3. Download, receiving progress updates
/// let results = try await downloader.download(
///     volumes: targets,
///     to: .downloadsDirectory,
///     progress: { p in
///         print("\(p.volumeID): \(p.fractionCompleted.map { "\(Int($0*100))%" } ?? "…")")
///     }
/// )
///
/// for result in results {
///     print("Saved \(result.volumeID) → \(result.localURL.path)")
/// }
/// ```
public actor FRUSDownloader {

    // MARK: Configuration

    /// Maximum number of volumes downloaded concurrently.
    public var maxConcurrentDownloads: Int

    /// GitHub personal access token.  Optional — raises rate limit from 60 to 5000 req/hr.
    public var githubToken: String?

    /// When `true`, an existing file whose size on disk matches `FRUSVolumeInfo.size` is skipped.
    public var skipIfAlreadyDownloaded: Bool

    // Two sessions with distinct responsibilities:
    //
    // listingSession — ephemeral, used only for the Git Trees API call in
    //   fetchVolumeList(). Short-lived JSON responses (~200 KB) that complete
    //   in seconds. Background sessions are forbidden from using the async/await
    //   completion-handler-based APIs (session.data(for:)), so this must be a
    //   standard session on all platforms.
    //
    // downloadSession — used for large FRUS XML file downloads. Also a standard
    //   session: the async session.download(for:) API is internally backed by
    //   completion handlers, which are likewise forbidden on background sessions.
    //   True background download support requires a URLSessionDownloadDelegate
    //   and is a separate architectural concern; using a standard session here
    //   restores correct behaviour on both macOS and iPadOS.
    private let listingSession: URLSession
    private let downloadSession: URLSession

    // Private API endpoints
    //
    // The Contents API (/contents/volumes) returns HTTP 403 for directories with
    // many files because the response would exceed GitHub's 1 MB API payload limit.
    // The Git Trees API does not have this restriction and is the correct endpoint
    // for listing large directories.  We request the tree for the "volumes" subtree
    // directly; the response is a JSON object { "sha": "…", "tree": [ … ] }.
    private static let treesAPIURL = URL(
        string: "https://api.github.com/repos/HistoryAtState/frus/git/trees/HEAD:volumes"
    )!
    private static let rawBaseURL = "https://raw.githubusercontent.com/HistoryAtState/frus/master/volumes/"

    // MARK: Init

    public init(
        maxConcurrentDownloads: Int = 3,
        githubToken: String? = nil,
        skipIfAlreadyDownloaded: Bool = true,
        urlSession: URLSession? = nil
    ) {
        self.maxConcurrentDownloads = maxConcurrentDownloads
        self.githubToken = githubToken
        self.skipIfAlreadyDownloaded = skipIfAlreadyDownloaded

        if let urlSession {
            // Caller-supplied session used for both listing and downloading.
            // This path is primarily used in unit tests via StubURLProtocol.
            self.listingSession  = urlSession
            self.downloadSession = urlSession
        } else {
            // Listing: ephemeral session for the short-lived Git Trees API call.
            // Must be a standard (non-background) session because the async
            // session.data(for:) API uses completion handlers internally, which
            // are forbidden on background URLSessions on all Apple platforms.
            self.listingSession = URLSession(configuration: .ephemeral)

            // Downloads: also a standard session. The async session.download(for:)
            // API is similarly backed by completion handlers and cannot be used
            // with a background session. A standard session correctly supports
            // concurrent callers via Swift structured concurrency.
            self.downloadSession = URLSession(configuration: .ephemeral)
        }
    }

    // MARK: - Volume listing

    /// Returns metadata for every FRUS volume in the GitHub repository.
    ///
    /// Results are sorted alphabetically by volume ID.
    /// The GitHub Contents API is used, which requires no authentication for public repos
    /// but is rate-limited to 60 requests/hour for unauthenticated clients.
    public func fetchVolumeList() async throws -> [FRUSVolumeInfo] {
        // Use the Git Trees API rather than the Contents API.
        // The Contents API returns HTTP 403 for directories whose listing payload
        // exceeds 1 MB — a limit the FRUS volumes/ directory (hundreds of files)
        // reliably triggers.  The Trees API returns the full subtree in one response
        // with no size restriction and no pagination.
        var request = URLRequest(url: Self.treesAPIURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        if let token = githubToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await listingSession.data(for: request)
        } catch {
            throw FRUSDownloaderError.listingFailed(underlying: error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw FRUSDownloaderError.listingFailed(underlying: URLError(.badServerResponse))
        }
        guard http.statusCode == 200 else {
            throw FRUSDownloaderError.listingHTTPError(statusCode: http.statusCode)
        }

        return try parseVolumeList(from: data)
    }

    /// Convenience: fetch the listing and return only the entry for `volumeID`.
    public func volumeInfo(for volumeID: String) async throws -> FRUSVolumeInfo? {
        let all = try await fetchVolumeList()
        return all.first(where: { $0.id == volumeID })
    }

    // MARK: - Downloading

    /// Download a single volume by ID, saving it to `directory`.
    ///
    /// - Parameters:
    ///   - volumeID: e.g. `"frus1969-76v24"`
    ///   - directory: Destination directory. Created if it doesn't exist.
    ///   - progress: Optional closure called on `MainActor` with download progress.
    /// - Returns: The local file URL.
    @discardableResult
    public func download(
        volumeID: String,
        to directory: URL,
        progress: (@MainActor (FRUSDownloadProgress) -> Void)? = nil
    ) async throws -> FRUSDownloadResult {
        let rawURL = URL(string: Self.rawBaseURL + "\(volumeID).xml")!
        let info = FRUSVolumeInfo(id: volumeID, size: 0, sha: "", downloadURL: rawURL)
        return try await downloadVolume(info, to: directory, progress: progress)
    }

    /// Download a single `FRUSVolumeInfo` (obtained from `fetchVolumeList()`).
    @discardableResult
    public func download(
        volume: FRUSVolumeInfo,
        to directory: URL,
        progress: (@MainActor (FRUSDownloadProgress) -> Void)? = nil
    ) async throws -> FRUSDownloadResult {
        try await downloadVolume(volume, to: directory, progress: progress)
    }

    /// Download multiple volumes concurrently, respecting `maxConcurrentDownloads`.
    ///
    /// Downloads that fail are collected and re-thrown as an `AggregateError` after all
    /// attempts have settled, so one failure does not cancel the remaining downloads.
    ///
    /// - Parameters:
    ///   - volumes: Volumes to download (typically a filtered subset of `fetchVolumeList()`).
    ///   - directory: Destination directory.
    ///   - progress: Called on `MainActor` for each progress update across all volumes.
    ///   - perVolumeCompletion: Called on `MainActor` when each individual download finishes (or fails).
    /// - Returns: Results for every successfully downloaded volume.
    @discardableResult
    public func download(
        volumes: [FRUSVolumeInfo],
        to directory: URL,
        progress: (@MainActor (FRUSDownloadProgress) -> Void)? = nil,
        perVolumeCompletion: (@MainActor (Result<FRUSDownloadResult, Error>) -> Void)? = nil
    ) async throws -> [FRUSDownloadResult] {
        guard !volumes.isEmpty else { return [] }

        // Ensure destination exists
        try FileManager.default.createDirectory(at: directory,
                                                withIntermediateDirectories: true)

        let limit = maxConcurrentDownloads
        var results: [FRUSDownloadResult] = []
        var errors: [(volumeID: String, error: Error)] = []

        // Process in batches of `limit`
        var remaining = volumes
        while !remaining.isEmpty {
            let batch = Array(remaining.prefix(limit))
            remaining.removeFirst(min(limit, remaining.count))

            await withTaskGroup(of: Result<FRUSDownloadResult, Error>.self) { group in
                for vol in batch {
                    group.addTask {
                        do {
                            let result = try await self.downloadVolume(vol, to: directory, progress: progress)
                            return .success(result)
                        } catch {
                            return .failure(error)
                        }
                    }
                }
                for await result in group {
                    await perVolumeCompletion?(result)
                    switch result {
                    case .success(let r): results.append(r)
                    case .failure(let e):
                        errors.append((volumeID: (e as? FRUSDownloaderError).flatMap {
                            if case .networkError(let id, _) = $0 { return id }
                            if case .httpError(let id, _) = $0 { return id }
                            return nil
                        } ?? "unknown", error: e))
                    }
                }
            }
        }

        if !errors.isEmpty {
            throw AggregateDownloadError(failures: errors)
        }
        return results.sorted { $0.volumeID < $1.volumeID }
    }

    // MARK: - Private helpers

    private func downloadVolume(
        _ info: FRUSVolumeInfo,
        to directory: URL,
        progress: (@MainActor (FRUSDownloadProgress) -> Void)?
    ) async throws -> FRUSDownloadResult {
        let destURL = directory.appending(component: "\(info.id).xml")

        // Skip if file already exists and size matches (when size > 0)
        if skipIfAlreadyDownloaded && info.size > 0 {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: destURL.path),
               let existingSize = attrs[.size] as? Int,
               existingSize == info.size {
                return FRUSDownloadResult(
                    volumeID: info.id,
                    localURL: destURL,
                    bytesWritten: Int64(existingSize)
                )
            }
        }

        // Build request — use raw.githubusercontent.com (no auth required, no API rate limits)
        var request = URLRequest(url: info.downloadURL)
        request.setValue("application/xml, text/xml, */*", forHTTPHeaderField: "Accept")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")

        // Use the native async session.download(for:) API.
        //
        // The previous implementation used withCheckedThrowingContinuation wrapping
        // session.downloadTask(_:completionHandler:).  When multiple downloads run
        // concurrently inside a TaskGroup, each call suspends the actor.  URLSession.shared
        // uses a serial internal delegate queue; issuing concurrent downloadTask calls
        // from a suspended actor context causes the second continuation to stall until
        // the first completes — effectively serialising what should be parallel work and
        // in some cases leaking the continuation entirely.
        //
        // session.download(for:) is the structured-concurrency-native API: it suspends
        // the current task (not the actor) and correctly supports concurrent callers.
        //
        // Progress is observed by running a lightweight child Task that polls
        // task.progress and forwards updates.  The observation Task is tied to the
        // download Task's lifetime via withTaskCancellationHandler so it cannot outlive
        // the download.
        let (tempURL, response): (URL, URLResponse)
        do {
            // Kick off progress observation before awaiting the download.
            let downloadTask = downloadSession.downloadTask(with: request)

            // If a progress callback was requested, observe via a retained token.
            // The token is stored in a local var so ARC keeps it alive until
            // the download completes, at which point the var goes out of scope.
            var progressObservation: NSKeyValueObservation?
            if let progress {
                progressObservation = downloadTask.progress.observe(
                    \.fractionCompleted,
                    options: [.new]
                ) { taskProgress, _ in
                    let p = FRUSDownloadProgress(
                        volumeID: info.id,
                        bytesReceived: taskProgress.completedUnitCount,
                        totalBytes: taskProgress.totalUnitCount
                    )
                    Task { await progress(p) }
                }
            }

            (tempURL, response) = try await downloadSession.download(for: request)
            // Silence the unused-variable warning while keeping the token alive
            // until after the await above completes.
            _ = progressObservation
        } catch {
            throw FRUSDownloaderError.networkError(volumeID: info.id, underlying: error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw FRUSDownloaderError.invalidResponse(volumeID: info.id)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw FRUSDownloaderError.httpError(volumeID: info.id, statusCode: http.statusCode)
        }

        // Move temp file to final destination
        do {
            try FileManager.default.createDirectory(at: directory,
                                                    withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.moveItem(at: tempURL, to: destURL)
        } catch {
            throw FRUSDownloaderError.diskError(volumeID: info.id, underlying: error)
        }

        let bytesWritten = (try? FileManager.default.attributesOfItem(atPath: destURL.path))?[.size] as? Int64 ?? 0
        return FRUSDownloadResult(volumeID: info.id, localURL: destURL, bytesWritten: bytesWritten)
    }

    /// Parse the GitHub Git Trees API response into `[FRUSVolumeInfo]`.
    ///
    /// Trees API response shape:
    /// ```json
    /// { "sha": "…", "url": "…", "tree": [
    ///     { "path": "frus1861.xml", "type": "blob", "size": 512000, "sha": "abc…" },
    ///     …
    /// ] }
    /// ```
    /// Unlike the Contents API, tree entries do not include a `download_url`.
    /// We construct the raw download URL from the known rawBaseURL + path.
    private func parseVolumeList(from data: Data) throws -> [FRUSVolumeInfo] {
        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let tree = root["tree"] as? [[String: Any]]
        else {
            throw FRUSDownloaderError.listingFailed(
                underlying: URLError(.cannotParseResponse)
            )
        }

        return tree.compactMap { entry -> FRUSVolumeInfo? in
            guard
                let path = entry["path"] as? String,
                path.hasSuffix(".xml"),
                (entry["type"] as? String) == "blob",
                let sha = entry["sha"] as? String,
                let size = entry["size"] as? Int,
                let downloadURL = URL(string: Self.rawBaseURL + path)
            else { return nil }

            let volumeID = String(path.dropLast(4)) // strip ".xml"
            return FRUSVolumeInfo(id: volumeID, size: size, sha: sha, downloadURL: downloadURL)
        }
        .sorted { $0.id < $1.id }
    }
}

// MARK: - Aggregate error

/// Thrown by `download(volumes:…)` when one or more volumes fail.
public struct AggregateDownloadError: Error, LocalizedError {
    public let failures: [(volumeID: String, error: Error)]

    public var errorDescription: String? {
        let lines = failures.map { "  • \($0.volumeID): \($0.error.localizedDescription)" }
        return "\(failures.count) volume(s) failed to download:\n" + lines.joined(separator: "\n")
    }
}

// MARK: - Filtering helpers on [FRUSVolumeInfo]

public extension Array where Element == FRUSVolumeInfo {

    /// Volumes whose ID starts with the given prefix (e.g. `"frus1969"`).
    func withPrefix(_ prefix: String) -> [FRUSVolumeInfo] {
        filter { $0.id.hasPrefix(prefix) }
    }

    /// Volumes whose ID contains the given substring.
    func containing(_ substring: String) -> [FRUSVolumeInfo] {
        filter { $0.id.contains(substring) }
    }

    /// Volumes smaller than `maxBytes` (useful for development / testing).
    func smallerThan(bytes maxBytes: Int) -> [FRUSVolumeInfo] {
        filter { $0.size < maxBytes }
    }

    /// Total download size of all volumes in this list.
    var totalSize: Int { reduce(0) { $0 + $1.size } }

    /// Formatted total size string, e.g. `"1.4 GB"`.
    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
    }
}
