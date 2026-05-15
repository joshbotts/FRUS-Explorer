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
/// the actor's executor. The actual network transfer runs off the actor via a `nonisolated`
/// helper so multiple downloads proceed concurrently without blocking the actor.
///
/// ## Offline Behaviour
/// When the app is offline, `enqueueDownload` accepts requests and persists them but does
/// not start transfers. Call `resumeQueuedDownloads()` when connectivity is restored
/// (done automatically by `FRUSExplorerApp` via `AppState.isOnline`).
///
/// ## App Termination
/// Pending (not-yet-started) downloads are persisted and resume on the next launch.
/// Active downloads that were in flight when the app was killed are **not** automatically
/// re-queued — the user must re-initiate them from the Browser view.
///
/// ## Storage Location
/// All volume XML files are written to:
///   `{Application Support}/FRUSExplorer/Volumes/{volumeId}.xml`
/// Each file has `isExcludedFromBackupKey` set to prevent iCloud backup of large XML files.
///
/// ## Dependency Injection
/// The `downloadTask` parameter replaces the real URLSession call in tests. Inject a
/// closure that writes fixture XML to a temporary file and returns its URL.
///
/// ## Session 09 Hook
/// `deleteVolume` fires `Notification.Name.frusVolumeDeleted` so the FTS5 index pipeline
/// can remove the volume's entries. The search index observer is registered in Session 09.
///
/// Version history:
///   1.0 — Session 05: initial implementation
public actor DownloadManager {

    // MARK: - Types

    /// The function signature used for the actual network transfer.
    /// Default: `URLSession.shared.download(for:)`. Override in tests.
    public typealias DownloadTask = @Sendable (URLRequest) async throws -> (URL, URLResponse)

    // MARK: - Immutable Configuration

    /// Root directory where all downloaded XML files are stored.
    public let volumesDirectory: URL

    /// Maximum number of simultaneous downloads.
    public let concurrencyLimit: Int

    private let downloadTask: DownloadTask
    private let onStateChanged: @MainActor (DownloadManagerState) -> Void

    // MARK: - Mutable Queue State

    /// Ordered list of volumeIds waiting to start (FIFO).
    private var pendingQueue: [String] = []

    /// volumeId → download URL string, for both pending and active entries.
    private var pendingUrls: [String: String] = [:]

    /// Running Tasks, keyed by volumeId.
    private var activeDownloads: [String: Task<Void, Never>] = [:]

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
    ///   - downloadTask: URLSession replacement for tests. Default uses `URLSession.shared`.
    ///   - onStateChanged: Called on the MainActor whenever active/pending queues change.
    public init(
        volumesDirectory: URL,
        concurrencyLimit: Int = 4,
        downloadTask: DownloadTask? = nil,
        onStateChanged: @escaping @MainActor (DownloadManagerState) -> Void
    ) {
        self.volumesDirectory = volumesDirectory
        self.concurrencyLimit = concurrencyLimit
        self.downloadTask = downloadTask ?? { request in
            try await URLSession.shared.download(for: request)
        }
        self.onStateChanged = onStateChanged

        // Restore persisted pending queue from the previous app session.
        let restored = Self.loadPersistedQueue()
        self.pendingQueue = restored.map(\.volumeId)
        self.pendingUrls = Dictionary(uniqueKeysWithValues: restored.map { ($0.volumeId, $0.downloadUrl) })

        // Ensure storage directory exists.
        try? FileManager.default.createDirectory(at: volumesDirectory, withIntermediateDirectories: true)

        #if DEBUG
        print("[DownloadManager] Initialised. volumesDir=\(volumesDirectory.path) pending=\(self.pendingQueue.count)")
        #endif
    }

    // MARK: - Public API

    /// A snapshot of the current queue state. Safe to read from any context via `await`.
    public var currentState: DownloadManagerState {
        DownloadManagerState(
            activeVolumeIds: Array(activeDownloads.keys),
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
              activeDownloads[volumeId] == nil,
              !pendingQueue.contains(volumeId) else { return }

        pendingQueue.append(volumeId)
        pendingUrls[volumeId] = downloadUrl
        persistQueue()

        #if DEBUG
        print("[DownloadManager] Enqueued \(volumeId). pending=\(pendingQueue.count) active=\(activeDownloads.count)")
        #endif

        processQueue()
    }

    /// Cancels a download that is active or pending.
    ///
    /// If the volume file was partially written it is removed. If the volume was only
    /// pending (not yet started) it is removed from the persisted queue.
    public func cancelDownload(volumeId: String) {
        // Cancel running task.
        activeDownloads[volumeId]?.cancel()
        activeDownloads.removeValue(forKey: volumeId)

        // Remove from pending queue.
        pendingQueue.removeAll { $0 == volumeId }
        pendingUrls.removeValue(forKey: volumeId)

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
    /// Posts `Notification.Name.frusVolumeDeleted` so the FTS5 index pipeline (Session 09)
    /// can remove the volume's search entries. Throws if the file cannot be removed.
    public func deleteVolume(volumeId: String) throws {
        let dest = volumeURL(for: volumeId)
        guard FileManager.default.fileExists(atPath: dest.path) else { return }
        try FileManager.default.removeItem(at: dest)

        // Session 09 hook: the FTS5 index observer listens for this notification and
        // removes the volume's rows from the frus_documents FTS5 table.
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

    /// Enables the manager and starts processing the pending queue.
    ///
    /// Call this when the device comes online. Safe to call multiple times.
    public func resumeQueuedDownloads() {
        isEnabled = true
        processQueue()

        #if DEBUG
        print("[DownloadManager] Resumed. pending=\(pendingQueue.count) active=\(activeDownloads.count)")
        #endif
    }

    /// Disables new downloads without cancelling active ones.
    ///
    /// Call this when the device goes offline. Active transfers finish normally; new
    /// entries from `enqueueDownload` are held in the persisted pending queue.
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
        while activeDownloads.count < concurrencyLimit, !pendingQueue.isEmpty {
            let volumeId = pendingQueue.removeFirst()
            guard let urlString = pendingUrls[volumeId],
                  let url = URL(string: urlString) else {
                pendingUrls.removeValue(forKey: volumeId)
                continue
            }
            activeDownloads[volumeId] = Task {
                do {
                    try await self.performDownload(volumeId: volumeId, downloadUrl: url)
                    await self.downloadDidSucceed(volumeId: volumeId)
                } catch {
                    await self.downloadDidFail(volumeId: volumeId, error: error)
                }
            }
        }
        persistQueue()
        notifyStateChanged()
    }

    /// Performs the actual network transfer. Runs off the actor's executor so concurrent
    /// downloads proceed without blocking the actor for the duration of each transfer.
    ///
    /// The `volumesDirectory` and `downloadTask` are immutable `let` properties and can
    /// therefore be accessed from this `nonisolated` context without data races.
    nonisolated private func performDownload(volumeId: String, downloadUrl: URL) async throws {
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

    private func downloadDidSucceed(volumeId: String) {
        activeDownloads.removeValue(forKey: volumeId)
        pendingUrls.removeValue(forKey: volumeId)
        processQueue()
    }

    private func downloadDidFail(volumeId: String, error: Error) {
        activeDownloads.removeValue(forKey: volumeId)
        pendingUrls.removeValue(forKey: volumeId)

        #if DEBUG
        let isCancelled = (error as? CancellationError) != nil
        if !isCancelled {
            print("[DownloadManager] ✗ \(volumeId) failed: \(error)")
        }
        #endif

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
    /// The FTS5 index observer (Session 09) removes the volume's search entries on receipt.
    static let frusVolumeDeleted = Notification.Name("frus.volumeDeleted")
}
