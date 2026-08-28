// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

/// Fetches the query-encoder model file — one 229 MB GGUF from the app-owned release — and hands
/// it to `SemanticModelStore`, which validates before it keeps (V-5 s2).
///
/// ## Why this reports progress when the shard fetcher does not
///
/// `SemanticShardFetcher` deliberately shows no per-file progress: a shard is ~294 KB and lands in
/// a fraction of a second. This file is three orders of magnitude larger — exactly the size class
/// where a silent transfer reads as a hang — so the fetch runs through a download delegate and
/// reports bytes as they arrive. It is still a FOREGROUND transfer: a background `URLSession`
/// would survive the app being backgrounded mid-fetch, but drags in relaunch-delegate plumbing for
/// a transfer that takes well under a minute on the connections that can carry it at all. If the
/// app is backgrounded mid-fetch and the transfer dies, the button is still there. A disclosed
/// trade, not an oversight.
///
/// ## Where the file comes from
///
/// A GitHub **release asset** on the same app-owned repo the shards live in. Not a git blob (the
/// file exceeds GitHub's 100 MB hard limit), not LFS (bandwidth quotas, and `raw.githubusercontent`
/// serves LFS pointers, not content) — a release asset has a stable direct URL and no quota. The
/// decision is recorded in `Planning/semantic-vectors/Gemma-Compliance-Runbook.md` §3.
///
/// Version history:
///   1.0 — V-5 s2: initial implementation
public actor SemanticModelFetcher {

    /// The published location of the pinned model file.
    public static let defaultModelURL = URL(
        string: "https://github.com/joshbotts/frus-semantic-vectors/releases/download/encoder-1/embeddinggemma-300m-qat-Q4_0.gguf")!

    private let modelURL: URL
    private let store: SemanticModelStore
    private let session: URLSession

    /// Whether a fetch is currently running (in-flight dedup, the shard fetcher's rule).
    private var inFlight = false

    /// The active transfer, kept so `cancel()` can reach it.
    private var activeTask: URLSessionDownloadTask?

    /// The last failure, remembered for the session so the storage screen can say what happened.
    /// Cleared by an explicit retry (the button), never silently.
    public private(set) var lastFailure: SemanticModelError?

    /// Creates a fetcher.
    ///
    /// - Parameters:
    ///   - modelURL: Where the file is published.
    ///   - store: The store that validates and keeps it.
    ///   - session: Injectable for tests.
    public init(
        modelURL: URL = SemanticModelFetcher.defaultModelURL,
        store: SemanticModelStore,
        session: URLSession = .shared
    ) {
        self.modelURL = modelURL
        self.store = store
        self.session = session
    }

    /// Forgets the remembered failure.
    public func clearFailure() { lastFailure = nil }

    /// Cancels the active transfer, if any. The in-flight `fetchModel` call throws `.transport`.
    public func cancel() {
        activeTask?.cancel()
    }

    /// Downloads the model file, reporting progress, and adopts it into the store.
    ///
    /// The GGUF's integrity is the store's check (length then SHA-256, at adoption); this method
    /// owns the transfer and the cellular gate. A second call while one is running returns without
    /// starting another.
    ///
    /// - Parameter onProgress: Called with (bytes received, bytes expected) as data arrives, on an
    ///   arbitrary queue — hop to the main actor before touching UI state.
    /// - Throws: `SemanticModelError` on transfer, status, or integrity failure.
    public func fetchModel(
        onProgress: @escaping @Sendable (Int64, Int64) -> Void
    ) async throws {
        guard !inFlight else { return }
        inFlight = true
        defer { inFlight = false; activeTask = nil }

        var request = URLRequest(url: modelURL)
        request.allowsCellularAccess =
            (UserDefaults.standard.object(forKey: SettingsKeys.allowCellularDownloads) as? Bool) ?? true

        let delegate = ModelDownloadDelegate(onProgress: onProgress)
        let temporary: URL
        do {
            temporary = try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    delegate.continuation = continuation
                    let task = session.downloadTask(with: request)
                    task.delegate = delegate
                    self.activeTask = task
                    task.resume()
                }
            } onCancel: {
                delegate.cancelTask()
            }
        } catch let error as SemanticModelError {
            lastFailure = error
            throw error
        } catch {
            let failure = SemanticModelError.transport("\(error)")
            lastFailure = failure
            throw failure
        }
        defer { try? FileManager.default.removeItem(at: temporary) }

        do {
            try await store.adoptModel(from: temporary)
            lastFailure = nil
        } catch let error as SemanticModelError {
            lastFailure = error
            throw error
        }
    }
}

/// The delegate bridging `URLSessionDownloadTask` callbacks into one awaited result.
///
/// `@unchecked Sendable` because URLSession serializes its delegate callbacks on its own queue,
/// which is the only place the mutable state is touched after `resume()`.
private final class ModelDownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {

    let onProgress: @Sendable (Int64, Int64) -> Void
    var continuation: CheckedContinuation<URL, Error>?
    private weak var task: URLSessionDownloadTask?
    /// Where `didFinishDownloadingTo` moved the file — that callback must relocate it before
    /// returning, because the system deletes `location` immediately after.
    private var movedTo: URL?

    init(onProgress: @escaping @Sendable (Int64, Int64) -> Void) {
        self.onProgress = onProgress
    }

    func cancelTask() { task?.cancel() }

    func urlSession(
        _ session: URLSession, downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        task = downloadTask
        onProgress(totalBytesWritten, totalBytesExpectedToWrite)
    }

    func urlSession(
        _ session: URLSession, downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("semantic-model-\(UUID().uuidString).part")
        do {
            try FileManager.default.moveItem(at: location, to: destination)
            movedTo = destination
        } catch {
            // Leave `movedTo` nil; completion reports the failure.
        }
    }

    func urlSession(
        _ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?
    ) {
        guard let continuation else { return }
        self.continuation = nil
        if let error {
            continuation.resume(throwing: SemanticModelError.transport("\(error)"))
            return
        }
        if let status = (task.response as? HTTPURLResponse)?.statusCode, status >= 400 {
            if let movedTo { try? FileManager.default.removeItem(at: movedTo) }
            continuation.resume(throwing: SemanticModelError.httpStatus(status))
            return
        }
        guard let movedTo else {
            continuation.resume(throwing: SemanticModelError.transport(
                "download completed but the file could not be kept"))
            return
        }
        continuation.resume(returning: movedTo)
    }
}
