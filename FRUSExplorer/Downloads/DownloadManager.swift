// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// DownloadManager coordinates all FRUS volume download activity.
///
/// It manages a concurrent download queue capped at a configurable limit (default 4),
/// persists the pending queue to UserDefaults so downloads survive app termination, and
/// stores downloaded XML files in Application Support.
///
/// ## Thread Safety
/// `DownloadManager` is a Swift actor. All mutations to queue state are serialised on
/// the actor's executor. Transfers run out-of-process via `BackgroundDownloadEngine`
/// (production) or off the actor via an injected `downloadTask` closure (tests).
///
/// ## Transfer Engine
/// Production transfers use a **background `URLSession`** (`BackgroundDownloadEngine`):
/// they continue while the app is suspended, survive app termination, and are
/// re-adopted on the next launch via `resumeQueuedDownloads()`. Failed transfers
/// (other than user cancellation) are retried up to `maxRetryCount` times with a
/// short backoff before being dropped.
///
/// ## Offline Behaviour
/// When the app is offline, `enqueueDownload` accepts requests and persists them but
/// does not start transfers. Call `resumeQueuedDownloads()` when connectivity is
/// restored (done automatically by `FRUSExplorerApp` via `AppState.isOnline`). The
/// background session additionally waits for connectivity on its own
/// (`waitsForConnectivity`), so a transfer started just before going offline resumes
/// by itself.
///
/// ## Storage Location
/// All volume XML files are written to:
///   `{Application Support}/FRUSExplorer/Volumes/{volumeId}.xml`
/// Each file has `isExcludedFromBackupKey` set to prevent iCloud backup of large XML files.
///
/// ## Dependency Injection
/// The `downloadTask` parameter replaces the background engine in tests. Inject a
/// closure that writes fixture XML to a temporary file and returns its URL; the
/// manager then performs the move itself, in-process.
///
/// ## Post-Download Hook
/// `onVolumeDownloaded` is called (via an unstructured `Task`) immediately after a volume
/// file is confirmed on disk. `FRUSExplorerApp` supplies a closure that calls
/// `IndexingPipeline.indexVolume(_:)`, so search indexing begins automatically without
/// any user action. `DownloadManager` has no direct reference to `IndexingPipeline`;
/// the closure is the only coupling point.
///
/// ## Deletion Hook
/// `deleteVolume` calls `onVolumeDeleted` (via an unstructured `Task`) after the XML file
/// is removed from disk. `FRUSExplorerApp` supplies a closure that calls
/// `IndexingPipeline.removeVolume(_:)`, so the volume's FTS5 rows, auxiliary-table rows,
/// and Spotlight items are cleaned up no matter which UI path triggered the deletion.
/// `Notification.Name.frusVolumeDeleted` is also posted for any additional observers.
///
/// Version history:
///   1.0 — Session 05: initial implementation
///   1.1 — Session 33: added `onVolumeDownloaded` callback for automatic post-download indexing
///   1.2 — Session 2026-06-09: added `onVolumeDeleted` callback so every deletion path
///          cleans up the search index. Previously `.frusVolumeDeleted` had no observer,
///          so the iOS Downloads settings delete path orphaned the volume's index data.
///   2.0 — Session 2026-06-09: background `URLSession` transfers via
///          `BackgroundDownloadEngine` — downloads survive app suspension and
///          termination and are re-adopted at the next launch; failed downloads are
///          retried with backoff instead of silently vanishing from the queue.
public actor DownloadManager {

    // MARK: - Types

    /// The function signature used for the actual network transfer in **tests**.
    /// When non-nil, it replaces the background engine entirely.
    public typealias DownloadTask = @Sendable (URLRequest) async throws -> (URL, URLResponse)

    // MARK: - Immutable Configuration

    /// Root directory where all downloaded XML files are stored.
    public let volumesDirectory: URL

    /// Maximum number of simultaneous downloads. Updatable at runtime via
    /// `setConcurrencyLimit(_:)`.
    public private(set) var concurrencyLimit: Int

    /// Maximum automatic retries for a failed (non-cancelled) download.
    public static let maxRetryCount = 2

    private let downloadTask: DownloadTask?
    private let onStateChanged: @MainActor (DownloadManagerState) -> Void

    /// Called on an unstructured `Task` immediately after a volume file is written to disk.
    /// `nil` if no post-download action is needed (e.g. indexing is unavailable).
    private let onVolumeDownloaded: (@Sendable (String) async -> Void)?

    /// Called on an unstructured `Task` after `deleteVolume` removes a volume file from
    /// disk. `FRUSExplorerApp` supplies a closure that removes the volume's search-index
    /// data via `IndexingPipeline.removeVolume(_:)`. `nil` if no cleanup is needed.
    private let onVolumeDeleted: (@Sendable (String) async -> Void)?

    /// `true` when transfers go through the shared `BackgroundDownloadEngine`
    /// (production); `false` when a test injected `downloadTask`.
    private let usesBackgroundEngine: Bool

    // MARK: - Mutable Queue State

    /// Ordered list of volumeIds waiting to start (FIFO).
    private var pendingQueue: [String] = []

    /// volumeId → download URL string, for both pending and active entries.
    private var pendingUrls: [String: String] = [:]

    /// Volume IDs with a transfer currently in flight.
    private var activeVolumeIds: Set<String> = []

    /// Running in-process Tasks for the **test** path, keyed by volumeId.
    /// Empty in production (the background engine owns transfer lifecycle).
    private var testTasks: [String: Task<Void, Never>] = [:]

    /// Automatic retry attempts per volumeId for the current failure streak.
    private var retryCounts: [String: Int] = [:]

    /// Whether downloads should start. Set to `true` by `resumeQueuedDownloads()`,
    /// `false` by `suspend()`. Guards `processQueue()` when offline.
    private var isEnabled: Bool = false

    // MARK: - UserDefaults Key

    private static let queueKey = "frus.downloadQueue"

    // MARK: - Init

    /// Creates a DownloadManager.
    ///
    /// - Parameters:
    ///   - volumesDirectory: Where XML files are written. Created if absent.
    ///   - concurrencyLimit: Max simultaneous downloads. Default 4.
    ///   - downloadTask: Test replacement for the background engine. Default `nil`
    ///     (production) routes transfers through `BackgroundDownloadEngine.shared`.
    ///   - onStateChanged: Called on the MainActor whenever active/pending queues change.
    ///   - onVolumeDownloaded: Called (via an unstructured `Task`) once a volume file is
    ///     confirmed on disk. Use this to trigger indexing without coupling `DownloadManager`
    ///     directly to `IndexingPipeline`. Pass `nil` if no post-download action is needed.
    ///   - onVolumeDeleted: Called (via an unstructured `Task`) after `deleteVolume` removes
    ///     a volume file from disk. Use this to remove the volume's search-index data
    ///     without coupling `DownloadManager` directly to `IndexingPipeline`. Pass `nil`
    ///     if no post-delete cleanup is needed.
    public init(
        volumesDirectory: URL,
        concurrencyLimit: Int = 4,
        downloadTask: DownloadTask? = nil,
        onStateChanged: @escaping @MainActor (DownloadManagerState) -> Void,
        onVolumeDownloaded: (@Sendable (String) async -> Void)? = nil,
        onVolumeDeleted: (@Sendable (String) async -> Void)? = nil
    ) {
        self.volumesDirectory = volumesDirectory
        self.concurrencyLimit = concurrencyLimit
        self.downloadTask = downloadTask
        self.usesBackgroundEngine = (downloadTask == nil)
        self.onStateChanged = onStateChanged
        self.onVolumeDownloaded = onVolumeDownloaded
        self.onVolumeDeleted = onVolumeDeleted

        // Restore persisted pending queue from the previous app session.
        let restored = Self.loadPersistedQueue()
        self.pendingQueue = restored.map(\.volumeId)
        self.pendingUrls = Dictionary(uniqueKeysWithValues: restored.map { ($0.volumeId, $0.downloadUrl) })

        // Ensure storage directory exists.
        try? FileManager.default.createDirectory(at: volumesDirectory, withIntermediateDirectories: true)

        #if DEBUG
        print("[DownloadManager] Initialised. volumesDir=\(volumesDirectory.path) pending=\(restored.count) engine=\(self.usesBackgroundEngine)")
        #endif

        // Route background-engine completions back into this actor. Only the
        // production path attaches — tests own their transfer lifecycle and must
        // not receive callbacks meant for another manager instance. Last statement
        // in init: capturing self in an escaping closure ends the initializer's
        // isolated access to stored properties.
        if usesBackgroundEngine {
            BackgroundDownloadEngine.shared.attach { [weak self] volumeId, error in
                guard let self else { return }
                Task { await self.transferDidComplete(volumeId: volumeId, error: error) }
            }
        }
    }

    // MARK: - Public API

    /// A snapshot of the current queue state. Safe to read from any context via `await`.
    public var currentState: DownloadManagerState {
        DownloadManagerState(
            activeVolumeIds: Array(activeVolumeIds),
            pendingVolumeIds: pendingQueue
        )
    }

    /// Returns `true` if the volume XML file exists on disk.
    public nonisolated func isVolumeDownloaded(_ volumeId: String) -> Bool {
        FileManager.default.fileExists(atPath: volumeURL(for: volumeId).path)
    }

    /// The on-disk URL for the volume, regardless of whether the file exists.
    public nonisolated func volumeURL(for volumeId: String) -> URL {
        volumesDirectory.appendingPathComponent("\(volumeId).xml")
    }

    /// Adds a volume to the download queue.
    ///
    /// If the volume is already downloaded, already active, or already pending, this is a
    /// no-op. Downloads start immediately if the manager is enabled and below the
    /// concurrency limit; otherwise the entry waits in the persisted pending queue.
    ///
    /// - Parameters:
    ///   - volumeId: The stable volume identifier (e.g. `"frus1969-76v01"`).
    ///   - downloadUrl: The direct download URL from the GitHub API listing.
    public func enqueueDownload(volumeId: String, downloadUrl: String) {
        guard !isVolumeDownloaded(volumeId),
              !activeVolumeIds.contains(volumeId),
              !pendingQueue.contains(volumeId) else { return }

        pendingQueue.append(volumeId)
        pendingUrls[volumeId] = downloadUrl
        retryCounts.removeValue(forKey: volumeId)
        persistQueue()

        #if DEBUG
        print("[DownloadManager] Enqueued \(volumeId). pending=\(pendingQueue.count) active=\(activeVolumeIds.count)")
        #endif

        processQueue()
    }

    /// Cancels a download that is active or pending.
    ///
    /// If the volume file was partially written it is removed. If the volume was only
    /// pending (not yet started) it is removed from the persisted queue.
    public func cancelDownload(volumeId: String) {
        // Cancel the running transfer.
        if usesBackgroundEngine {
            BackgroundDownloadEngine.shared.cancelDownload(volumeId: volumeId)
        }
        testTasks[volumeId]?.cancel()
        testTasks.removeValue(forKey: volumeId)
        activeVolumeIds.remove(volumeId)

        // Remove from pending queue.
        pendingQueue.removeAll { $0 == volumeId }
        pendingUrls.removeValue(forKey: volumeId)
        retryCounts.removeValue(forKey: volumeId)

        // Remove any partially written file.
        let dest = volumeURL(for: volumeId)
        try? FileManager.default.removeItem(at: dest)

        persistQueue()
        notifyStateChanged()

        #if DEBUG
        print("[DownloadManager] Cancelled \(volumeId).")
        #endif
    }

    /// Deletes a fully downloaded volume XML file from disk.
    ///
    /// Calls `onVolumeDeleted` (via an unstructured `Task`) so the search index removes
    /// the volume's FTS5 rows, auxiliary-table rows, and Spotlight items, and also posts
    /// `Notification.Name.frusVolumeDeleted` for any additional observers. Throws if the
    /// file cannot be removed.
    public func deleteVolume(volumeId: String) throws {
        let dest = volumeURL(for: volumeId)
        guard FileManager.default.fileExists(atPath: dest.path) else { return }
        try FileManager.default.removeItem(at: dest)

        // Index cleanup runs in an unstructured Task so file deletion returns
        // immediately; IndexingPipeline.removeVolume is idempotent, so callers that
        // already removed the index themselves (e.g. the storage management sheet)
        // are unaffected by the second pass.
        if let callback = onVolumeDeleted {
            Task { await callback(volumeId) }
        }

        NotificationCenter.default.post(
            name: .frusVolumeDeleted,
            object: nil,
            userInfo: ["volumeId": volumeId]
        )

        #if DEBUG
        print("[DownloadManager] Deleted volume \(volumeId).")
        #endif
    }

    /// Computes a breakdown of disk usage for all managed storage.
    ///
    /// - Parameter indexDirectory: The FTS5 database directory (supplied in Session 09).
    ///   Pass `nil` until the search index is wired up; `totalIndexBytes` will be `0`.
    /// - Returns: A `StorageReport` with per-volume XML sizes and aggregate totals.
    public func storageReport(indexDirectory: URL? = nil) throws -> StorageReport {
        var perVolume: [VolumeStorageEntry] = []

        if FileManager.default.fileExists(atPath: volumesDirectory.path) {
            let contents = try FileManager.default.contentsOfDirectory(
                at: volumesDirectory,
                includingPropertiesForKeys: [.fileSizeKey],
                options: .skipsHiddenFiles
            )
            for url in contents where url.pathExtension == "xml" {
                let volumeId = url.deletingPathExtension().lastPathComponent
                let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                perVolume.append(VolumeStorageEntry(volumeId: volumeId, volumeFileBytes: bytes))
            }
        }

        let totalVolumes = perVolume.reduce(0) { $0 + $1.volumeFileBytes }

        var indexBytes = 0
        if let indexDir = indexDirectory {
            indexBytes = directorySize(at: indexDir)
        }

        return StorageReport(
            totalVolumesBytes: totalVolumes,
            totalIndexBytes: indexBytes,
            totalSummariesBytes: 0,
            perVolume: perVolume.sorted { $0.volumeId < $1.volumeId }
        )
    }

    /// Enables the manager, adopts transfers the background daemon kept alive
    /// across the last app termination, and starts processing the pending queue.
    ///
    /// Call this when the device comes online. Safe to call multiple times.
    public func resumeQueuedDownloads() async {
        isEnabled = true

        // Adopt transfers still registered with the background session — they were
        // started before the last suspension/termination and have been progressing
        // (or waiting for connectivity) under the system daemon ever since.
        if usesBackgroundEngine {
            let inFlight = await BackgroundDownloadEngine.shared.inFlightVolumeIds()
            for volumeId in inFlight {
                activeVolumeIds.insert(volumeId)
                pendingQueue.removeAll { $0 == volumeId }
            }
            if !inFlight.isEmpty {
                persistQueue()
                #if DEBUG
                print("[DownloadManager] Adopted \(inFlight.count) in-flight background transfers.")
                #endif
            }
        }

        processQueue()

        #if DEBUG
        print("[DownloadManager] Resumed. pending=\(pendingQueue.count) active=\(activeVolumeIds.count)")
        #endif
    }

    /// Updates the maximum number of simultaneous downloads (clamped to 1…8)
    /// and immediately starts any pending entries a higher limit now allows.
    /// Active transfers are never cancelled by a lower limit — it applies as
    /// transfers finish. Persisting the choice is the Settings pane's job
    /// (`SettingsKeys.concurrentDownloadLimit`).
    public func setConcurrencyLimit(_ limit: Int) {
        concurrencyLimit = max(1, min(limit, 8))
        processQueue()

        #if DEBUG
        print("[DownloadManager] Concurrency limit set to \(concurrencyLimit).")
        #endif
    }

    /// Disables new downloads without cancelling active ones.
    ///
    /// Call this when the device goes offline. Active transfers finish normally (the
    /// background session waits for connectivity by itself); new entries from
    /// `enqueueDownload` are held in the persisted pending queue.
    public func suspend() {
        isEnabled = false

        #if DEBUG
        print("[DownloadManager] Suspended. active downloads will complete normally.")
        #endif
    }

    // MARK: - Private Queue Processing

    /// Starts as many pending downloads as the concurrency limit allows.
    /// Only runs when `isEnabled` is `true`.
    private func processQueue() {
        guard isEnabled else { return }
        while activeVolumeIds.count < concurrencyLimit, !pendingQueue.isEmpty {
            let volumeId = pendingQueue.removeFirst()
            guard let urlString = pendingUrls[volumeId],
                  let url = URL(string: urlString) else {
                pendingUrls.removeValue(forKey: volumeId)
                continue
            }
            activeVolumeIds.insert(volumeId)

            if usesBackgroundEngine {
                BackgroundDownloadEngine.shared.startDownload(volumeId: volumeId, from: url)
            } else {
                testTasks[volumeId] = Task {
                    do {
                        try await self.performTestDownload(volumeId: volumeId, downloadUrl: url)
                        self.transferDidComplete(volumeId: volumeId, error: nil)
                    } catch {
                        self.transferDidComplete(volumeId: volumeId, error: error)
                    }
                }
            }
        }
        persistQueue()
        notifyStateChanged()
    }

    /// Performs an in-process transfer using the injected test closure. Runs off the
    /// actor's executor so concurrent test downloads proceed without blocking the actor.
    nonisolated private func performTestDownload(volumeId: String, downloadUrl: URL) async throws {
        guard let downloadTask else { throw URLError(.unknown) }
        var request = URLRequest(url: downloadUrl)
        request.setValue("FRUSExplorer/2.0", forHTTPHeaderField: "User-Agent")

        let (tempURL, response) = try await downloadTask(request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let destURL = volumesDirectory.appendingPathComponent("\(volumeId).xml")
        // Remove any stale file before moving the new one into place.
        try? FileManager.default.removeItem(at: destURL)
        try FileManager.default.moveItem(at: tempURL, to: destURL)

        // Exclude the volume XML from iCloud backup — these are re-downloadable.
        try (destURL as NSURL).setResourceValue(true, forKey: .isExcludedFromBackupKey)

        #if DEBUG
        let bytes = (try? destURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        print("[DownloadManager] ✓ \(volumeId) saved (\(bytes) bytes).")
        #endif
    }

    /// Routes a finished transfer (engine or test path) to success/failure handling.
    private func transferDidComplete(volumeId: String, error: Error?) {
        guard activeVolumeIds.contains(volumeId) || testTasks[volumeId] != nil else {
            // Completion for a transfer this instance no longer tracks (e.g. a
            // background transfer that finished during a previous process). The
            // file is already on disk; trigger the post-download hook so the
            // volume gets indexed.
            if error == nil, let callback = onVolumeDownloaded {
                Task { await callback(volumeId) }
            }
            return
        }
        if let error {
            downloadDidFail(volumeId: volumeId, error: error)
        } else {
            downloadDidSucceed(volumeId: volumeId)
        }
    }

    private func downloadDidSucceed(volumeId: String) {
        activeVolumeIds.remove(volumeId)
        testTasks.removeValue(forKey: volumeId)
        pendingUrls.removeValue(forKey: volumeId)
        retryCounts.removeValue(forKey: volumeId)

        // Trigger post-download indexing (or any other action) without blocking the actor.
        // The callback runs in an unstructured Task so it does not delay queue processing
        // and does not hold the DownloadManager actor for the duration of indexing.
        if let callback = onVolumeDownloaded {
            Task { await callback(volumeId) }
        }

        processQueue()
    }

    private func downloadDidFail(volumeId: String, error: Error) {
        activeVolumeIds.remove(volumeId)
        testTasks.removeValue(forKey: volumeId)

        let isCancelled = (error as? CancellationError) != nil
            || (error as? URLError)?.code == .cancelled

        // Retry transient failures with a short backoff; give up (and forget the
        // URL) after maxRetryCount attempts or on user cancellation.
        if !isCancelled,
           let urlString = pendingUrls[volumeId],
           retryCounts[volumeId, default: 0] < Self.maxRetryCount {
            let attempt = retryCounts[volumeId, default: 0] + 1
            retryCounts[volumeId] = attempt
            #if DEBUG
            print("[DownloadManager] ✗ \(volumeId) failed (attempt \(attempt)): \(error). Retrying…")
            #endif
            Task {
                // Linear backoff: 5 s, 10 s. Modest by design — the background
                // session already retried transport-level hiccups internally.
                try? await Task.sleep(for: .seconds(5 * attempt))
                await self.retryDownload(volumeId: volumeId, downloadUrl: urlString)
            }
        } else {
            pendingUrls.removeValue(forKey: volumeId)
            retryCounts.removeValue(forKey: volumeId)
            #if DEBUG
            if !isCancelled {
                print("[DownloadManager] ✗ \(volumeId) failed permanently: \(error)")
            }
            #endif
        }

        processQueue()
    }

    /// Re-enqueues a failed download at the back of the pending queue, preserving
    /// its retry count.
    private func retryDownload(volumeId: String, downloadUrl: String) {
        guard !isVolumeDownloaded(volumeId),
              !activeVolumeIds.contains(volumeId),
              !pendingQueue.contains(volumeId) else { return }
        pendingQueue.append(volumeId)
        pendingUrls[volumeId] = downloadUrl
        persistQueue()
        processQueue()
    }

    // MARK: - Persistence

    private struct PersistedEntry: Codable {
        let volumeId: String
        let downloadUrl: String
    }

    private func persistQueue() {
        let entries = pendingQueue.compactMap { volumeId -> PersistedEntry? in
            guard let url = pendingUrls[volumeId] else { return nil }
            return PersistedEntry(volumeId: volumeId, downloadUrl: url)
        }
        let data = try? JSONEncoder().encode(entries)
        UserDefaults.standard.set(data, forKey: Self.queueKey)
    }

    private static func loadPersistedQueue() -> [PersistedEntry] {
        guard let data = UserDefaults.standard.data(forKey: queueKey) else { return [] }
        return (try? JSONDecoder().decode([PersistedEntry].self, from: data)) ?? []
    }

    // MARK: - State Notification

    private func notifyStateChanged() {
        let state = currentState
        Task { @MainActor [onStateChanged] in
            onStateChanged(state)
        }
    }

    // MARK: - Helpers

    /// Recursively sums file sizes under a directory. Returns 0 if the directory
    /// does not exist or cannot be enumerated.
    nonisolated private func directorySize(at url: URL) -> Int {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: .skipsHiddenFiles
        ) else { return 0 }
        return enumerator.reduce(0) { total, item in
            guard let fileURL = item as? URL,
                  let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
            else { return total }
            return total + size
        }
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    /// Posted by `DownloadManager.deleteVolume` when a volume is removed from disk.
    /// `userInfo["volumeId"]` contains the deleted volume identifier.
    /// Search-index cleanup is handled by the `onVolumeDeleted` callback, not this
    /// notification; it remains available for auxiliary observers (e.g. UI refresh).
    static let frusVolumeDeleted = Notification.Name("frus.volumeDeleted")
}
