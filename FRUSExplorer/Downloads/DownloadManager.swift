// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import CryptoKit
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
///   2.1 — Session 154: `enqueueDownload` gained a `force` parameter so the
///          "Update" action in Downloads settings can re-queue an already-downloaded
///          volume; added `blobSHA(for:)` / `localVolumeInfo(for:)` /
///          `gitBlobSHA1(for:)` for `VolumeUpdateChecker`, with a UserDefaults-backed
///          cache invalidated on delete and re-download.
///   2.2 — #1301 round 4: DEBUG-only `replayFinishedTransferForUITest(volumeId:)` hands a volume
///          a UI test has already put on disk to the completion router, so the automatic
///          post-download index can be started while a compilation is on screen. Absent from
///          AppStore and DirectDistribution builds.
///   2.3 — #1516 (owner decision D3, option (f)4): a volume's figure images are fetched after
///          its XML and kept beside it (`FigureImageLibrary`), removed with it, and counted in
///          `storageReport`. See "Figure Images" below.
///   2.4 — #1516 review, round 1: `fetchMissingFigureImages(among:)`, the pass that brings the
///          volumes already on the device up to their images — at launch and whenever the device
///          comes back online — and tries again what an earlier run could not fetch; a volume
///          whose run ended with nothing left to fetch is recorded
///          (`FigureImageLibrary.completionRecordName`) and not scanned again until its text changes.
///
/// ## Figure Images (#1516)
/// When a volume's download finishes, `fetchFigureImages(for:)` reads the names its `<figure>`s
/// give their `<graphic>`s and fetches each from
/// `https://static.history.state.gov/frus/{volumeId}/{name}.png` into
/// `{Volumes}/{volumeId}.figures/`. Only figure images: never a page's scan — a `<graphic>` too,
/// but in a `<facsimile>`'s `<surface>`, of which the 553 manifest volumes hold 1,143,043 — and
/// not a title page's figure, which sits outside every `<div>` — so in no document the app
/// parses — and which history.state.gov does not serve.
///
/// A volume that was on the device before this existed, and one whose run was cut short or left a
/// transfer failed, is brought up to its images by `fetchMissingFigureImages(among:)`, which the
/// app runs at launch and each time the device comes back online. Until that pass reaches a
/// volume, the reader and the PDF, Word and HTML exports fetch the one image they need
/// (`fetchFigureImage(volumeId:fileName:)`, through `FigureImageStore`).
///
/// These transfers do not go through `BackgroundDownloadEngine`, for the reasons
/// `SemanticShardFetcher` gives: the engine hardcodes its destination as `{volumeId}.xml`, keys a
/// transfer by its volume alone, and exists for one multi-megabyte file — a volume's images are
/// many small ones (553 corpus-wide, 141.0 MB in all, a median of 328 KB per volume that has any;
/// measured 2026-10-01).
public actor DownloadManager {

    // MARK: - Types

    /// The function signature used for the actual network transfer in **tests**.
    /// When non-nil, it replaces the background engine entirely.
    public typealias DownloadTask = @Sendable (URLRequest) async throws -> (URL, URLResponse)

    /// How one figure image is fetched (#1516): the request's body and its response. Production
    /// uses a `URLSession`; a test injects a closure answering from fixtures.
    public typealias FigureTransfer = @Sendable (URLRequest) async throws -> (Data, URLResponse)

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

    /// Fetches one figure image (#1516), or `nil` when this manager fetches none: a manager a
    /// test built with its own `downloadTask` and no `figureTransfer`, so that no unit test
    /// reaches the network.
    private let figureTransfer: FigureTransfer?

    /// Where figure images are kept, and how they are named (#1516).
    public nonisolated let figureLibrary: FigureImageLibrary

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

    /// One whole-volume figure fetch (#1516): a volume, and which of its texts the run read.
    private struct FigureRun: Hashable {
        let volumeId: String
        let text: Int
    }

    /// The running whole-volume figure fetch per run (#1516), so the download hook and a
    /// reader's request cannot both walk the same text.
    private var figureFetches: [FigureRun: Task<FigureFetchOutcome, Never>] = [:]

    /// How many downloads of each volume have finished in this process (#1516). A whole-volume
    /// figure fetch takes its names from the text it found; when an update replaces that text,
    /// the run stops asking for the old text's names and the update's own run reads the new ones.
    private var figureTexts: [String: Int] = [:]

    /// Where the reader's download settings are read from: `.standard` everywhere but a test.
    private let preferences: UserDefaults

    /// The running fetch per single image, keyed `volumeId/fileName` (#1516).
    private var figureImageFetches: [String: Task<FigureImageFetch, Never>] = [:]

    /// Image file names history.state.gov refused this session, per volume (#1516): 13 of the
    /// 566 names the corpus's figures give outside title pages are not served (measured
    /// 2026-10-01), and asking again on every page view would not change the answer. Forgotten at
    /// the next launch, so a name the Office of the Historian starts serving is picked up when
    /// the reader or an export next asks for it.
    private var figuresRefused: [String: Set<String>] = [:]

    /// The running pass over the volumes on the device (#1516 review, round 1), so the launch's
    /// pass and a reconnect's cannot both walk the library.
    private var figureBackfill: Task<[String], Never>?

    /// How many volumes in a row may have every transfer fail before
    /// ``fetchMissingFigureImages(among:)`` stops: the host is not answering, or the connection
    /// is one the reader's settings keep image requests off. More than one, so that a single
    /// volume whose one missing image keeps failing does not end every pass at itself.
    static let figureBackfillPatience = 3

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
    ///   - figureTransfer: How a figure image is fetched (#1516). Default `nil`: the production
    ///     manager (no `downloadTask`) uses `FigureImageLibrary.session`, and a test's manager
    ///     fetches no image at all unless the test supplies this.
    ///   - preferences: Where Allow Cellular Downloads is read from. Default `.standard`; a test
    ///     passes a suite of its own, so it changes no setting another test reads.
    public init(
        volumesDirectory: URL,
        concurrencyLimit: Int = 4,
        downloadTask: DownloadTask? = nil,
        onStateChanged: @escaping @MainActor (DownloadManagerState) -> Void,
        onVolumeDownloaded: (@Sendable (String) async -> Void)? = nil,
        onVolumeDeleted: (@Sendable (String) async -> Void)? = nil,
        figureTransfer: FigureTransfer? = nil,
        preferences: UserDefaults = .standard
    ) {
        self.volumesDirectory = volumesDirectory
        self.preferences = preferences
        self.figureLibrary = FigureImageLibrary(volumesDirectory: volumesDirectory)
        if let figureTransfer {
            self.figureTransfer = figureTransfer
        } else if downloadTask == nil {
            self.figureTransfer = { request in try await FigureImageLibrary.session.data(for: request) }
        } else {
            self.figureTransfer = nil
        }
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
    /// no-op — unless `force` is `true`, which re-queues an already-downloaded volume
    /// (the transfer engine overwrites the existing file on completion). Downloads start
    /// immediately if the manager is enabled and below the concurrency limit; otherwise
    /// the entry waits in the persisted pending queue.
    ///
    /// - Parameters:
    ///   - volumeId: The stable volume identifier (e.g. `"frus1969-76v01"`).
    ///   - downloadUrl: The direct download URL from the GitHub API listing.
    ///   - force: If `true`, bypasses the "already downloaded" check so an existing
    ///     volume is re-downloaded and overwritten. Used by the "Update" action in
    ///     Downloads settings (Session 154). Default `false`.
    /// Enqueues a catalogue volume, and silently declines anything the app cannot fetch.
    ///
    /// The entry-taking overload exists so no caller has to remember the #777 case. A side-loaded
    /// volume's `downloadUrl` is `nil`, and there is nothing to enqueue: the app never had a URL
    /// for it, and inventing one from the filename would either 404 or — worse — one day resolve
    /// to a *different* volume published under that name. Every "Download" affordance in the app
    /// routes through here, so declining is a single decision rather than twelve.
    ///
    /// Version history:
    ///   1.0 — Session 2026-08-09: #777
    public func enqueueDownload(_ entry: VolumeManifestEntry, force: Bool = false) {
        guard let url = entry.downloadUrl else {
            #if DEBUG
            print("[DownloadManager] Declined \(entry.volumeId): side-loaded, no catalogue URL")
            #endif
            return
        }
        enqueueDownload(volumeId: entry.volumeId, downloadUrl: url, force: force)
    }

    public func enqueueDownload(volumeId: String, downloadUrl: String, force: Bool = false) {
        guard (force || !isVolumeDownloaded(volumeId)),
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
        // And the images of the copy that file replaced, when this cancels an update (#1516): no
        // volume is left for them to illustrate.
        discardFigureImages(for: volumeId)

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
        // #926 item 3: the guard is about the XML, and ONLY the XML. It used to return
        // here, which skipped the teardown callback — so any path that removed the file
        // first (or called delete twice) left the volume's semantic shard on disk for a
        // volume the user no longer has, and its index rows uncollected. Teardown of the
        // other artifacts must not depend on which of them happens to be removed first.
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
            Self.invalidateBlobSHA(for: volumeId)
        }
        // #1516: the volume's figure images go with it — outside the guard, for the reason the
        // callback below is: whichever of a volume's files is removed first, none may outlive it.
        discardFigureImages(for: volumeId)

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
                // #1516: the volume's figure images, kept beside its XML and counted with it.
                perVolume.append(VolumeStorageEntry(volumeId: volumeId, volumeFileBytes: bytes,
                                                    figureBytes: figureLibrary.bytes(for: volumeId)))
            }
        }

        let totalVolumes = perVolume.reduce(0) { $0 + $1.volumeFileBytes }
        let totalFigures = perVolume.reduce(0) { $0 + $1.figureBytes }

        // #926 item 2: `Volumes/` and `SemanticVectors/` are CHILDREN of the index
        // directory, and the recursive walk counted both — so volume XML was counted
        // twice in the hero figure (once as itself, once inside "Index") for as long as
        // the walk has existed, and shard bytes joined the double-count when vectors
        // shipped. The index figure now excludes the two children, and vectors are
        // measured once, as their own figure.
        var indexBytes = 0
        var vectorBytes = 0
        if let indexDir = indexDirectory {
            let vectorsDir = indexDir.appendingPathComponent("SemanticVectors", isDirectory: true)
            var excluded = [vectorsDir]
            excluded.append(volumesDirectory)
            indexBytes = Self.directorySize(at: indexDir, excludingSubdirectories: excluded)
            vectorBytes = Self.directorySize(at: vectorsDir)
        }

        return StorageReport(
            totalVolumesBytes: totalVolumes,
            totalIndexBytes: indexBytes,
            totalSummariesBytes: 0,
            totalVectorBytes: vectorBytes,
            totalFigureBytes: totalFigures,
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

    // MARK: - Update Detection (Session 154)

    /// On-disk facts about a downloaded volume for `VolumeUpdateChecker`. Returns
    /// `nil` if the volume is not downloaded.
    public func localVolumeInfo(for volumeId: String) -> LocalVolumeInfo? {
        let url = volumeURL(for: volumeId)
        guard let size = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int else {
            return nil
        }
        return LocalVolumeInfo(sha: blobSHA(for: volumeId), sizeBytes: size)
    }

    /// Returns the git blob SHA-1 of a downloaded volume's XML file, in the same
    /// form GitHub's contents API reports for the same file
    /// (`gitBlobSHA1(for:)`), or `nil` if the volume is not downloaded.
    ///
    /// Cached in `UserDefaults` keyed by `volumeId` so repeat checks (e.g. opening
    /// the Downloads settings pane) avoid re-hashing large files. The cache is
    /// invalidated whenever the volume is deleted or re-downloaded.
    public func blobSHA(for volumeId: String) -> String? {
        if let cached = Self.loadBlobSHACache()[volumeId] {
            return cached
        }
        guard let data = try? Data(contentsOf: volumeURL(for: volumeId)) else { return nil }
        let sha = Self.gitBlobSHA1(for: data)
        var cache = Self.loadBlobSHACache()
        cache[volumeId] = sha
        Self.saveBlobSHACache(cache)
        return sha
    }

    /// Computes the git blob SHA-1 of `data`, in the same form GitHub's contents API
    /// reports for repository files: `sha1("blob <byte length>\0" + data)`.
    public nonisolated static func gitBlobSHA1(for data: Data) -> String {
        var hasher = Insecure.SHA1()
        hasher.update(data: Data("blob \(data.count)\0".utf8))
        hasher.update(data: data)
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static let blobSHACacheKey = "frus.downloadedVolumeBlobSHA"

    private static func loadBlobSHACache() -> [String: String] {
        (UserDefaults.standard.dictionary(forKey: blobSHACacheKey) as? [String: String]) ?? [:]
    }

    private static func saveBlobSHACache(_ cache: [String: String]) {
        UserDefaults.standard.set(cache, forKey: blobSHACacheKey)
    }

    private static func invalidateBlobSHA(for volumeId: String) {
        var cache = loadBlobSHACache()
        cache.removeValue(forKey: volumeId)
        saveBlobSHACache(cache)
    }

    // MARK: - Private Queue Processing

    /// Starts as many pending downloads as the concurrency limit allows.
    /// Only runs when `isEnabled` is `true`.
    private func processQueue() {
        guard isEnabled else { return }

        // Read once per call so every transfer started in this pass uses a
        // consistent snapshot of the preference (Session 154 cellular policy).
        // `object(forKey:)` distinguishes "unset" from "explicitly false" —
        // `bool(forKey:)` would default an unset key to `false`.
        let allowsCellular = (preferences.object(forKey: SettingsKeys.allowCellularDownloads) as? Bool) ?? true

        while activeVolumeIds.count < concurrencyLimit, !pendingQueue.isEmpty {
            let volumeId = pendingQueue.removeFirst()
            guard let urlString = pendingUrls[volumeId],
                  let url = URL(string: urlString) else {
                pendingUrls.removeValue(forKey: volumeId)
                continue
            }
            activeVolumeIds.insert(volumeId)

            if usesBackgroundEngine {
                BackgroundDownloadEngine.shared.startDownload(volumeId: volumeId, from: url, allowsCellular: allowsCellular)
            } else {
                testTasks[volumeId] = Task {
                    do {
                        try await self.performTestDownload(volumeId: volumeId, downloadUrl: url, allowsCellular: allowsCellular)
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
    nonisolated private func performTestDownload(volumeId: String, downloadUrl: URL, allowsCellular: Bool) async throws {
        guard let downloadTask else { throw URLError(.unknown) }
        var request = URLRequest(url: downloadUrl)
        request.setValue("FRUSExplorer/2.0", forHTTPHeaderField: "User-Agent")
        request.allowsCellularAccess = allowsCellular

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
            if error == nil { figureTextDidChange(for: volumeId) }
            return
        }
        if let error {
            downloadDidFail(volumeId: volumeId, error: error)
        } else {
            downloadDidSucceed(volumeId: volumeId)
        }
    }

    #if DEBUG
    /// Delivers a finished, successful transfer for `volumeId` the way `BackgroundDownloadEngine`
    /// delivers every one — through `transferDidComplete(volumeId:error:)` — for a volume a UI test
    /// has already put on disk (#1301 round 4).
    ///
    /// Nothing is downloaded and nothing below this call is simulated. The router takes its branch
    /// for a transfer this instance does not track and runs the `onVolumeDownloaded` closure
    /// `FRUSExplorerApp` supplied — the same closure a tracked success runs — which is the automatic
    /// post-download index. `CompilationView`'s progress kick is the only thing that fills a
    /// compilation opened before that index finishes, and until this existed no test could start
    /// the index while one was on screen. Called from `UITestBrowseSeams`, and from the unit test
    /// that pins that same branch's figure fetch (#1516, `FigureImageDownloadTests`).
    ///
    /// - Parameter volumeId: A volume whose file is already in ``volumesDirectory``.
    func replayFinishedTransferForUITest(volumeId: String) {
        transferDidComplete(volumeId: volumeId, error: nil)
    }
    #endif

    private func downloadDidSucceed(volumeId: String) {
        activeVolumeIds.remove(volumeId)
        testTasks.removeValue(forKey: volumeId)
        pendingUrls.removeValue(forKey: volumeId)
        retryCounts.removeValue(forKey: volumeId)

        // The on-disk content just changed (fresh download or "Update" overwrite);
        // drop any cached blob SHA so the next update check re-hashes the new file.
        Self.invalidateBlobSHA(for: volumeId)

        // Trigger post-download indexing (or any other action) without blocking the actor.
        // The callback runs in an unstructured Task so it does not delay queue processing
        // and does not hold the DownloadManager actor for the duration of indexing.
        if let callback = onVolumeDownloaded {
            Task { await callback(volumeId) }
        }

        // #1516: the volume's figure images, beside its XML. After an update this also drops the
        // images the new text no longer names and fetches the ones it newly does.
        figureTextDidChange(for: volumeId)

        processQueue()
    }

    // MARK: - Figure Images (#1516)

    /// A download of `volumeId` has just finished, so its text is new: a figure fetch still
    /// walking the names of the text it replaced stops (`performFigureFetch`), and a run over
    /// the new text starts.
    private func figureTextDidChange(for volumeId: String) {
        figureTexts[volumeId, default: 0] += 1
        startFigureFetch(for: volumeId)
    }

    /// Starts fetching `volumeId`'s figure images without holding the caller: the download queue
    /// moves on, and indexing does not wait for images.
    private func startFigureFetch(for volumeId: String) {
        guard figureTransfer != nil else { return }
        Task { _ = await self.fetchFigureImages(for: volumeId) }
    }

    /// Fetches every figure image `volumeId`'s text names that is not on the device, and removes
    /// any image file its text no longer names.
    ///
    /// Idempotent and de-duplicated: an image already on disk is not asked for again, and a call
    /// made while one is running over the same text of the volume returns that run's outcome. A
    /// name the server refuses is remembered for the session; a transfer that fails is left to
    /// the next call, which ``fetchMissingFigureImages(among:)`` makes at the next launch or
    /// reconnect. A run that ends with nothing failed records the volume complete for its text.
    /// A run stops asking when an update replaces the text it read, and an image that lands
    /// after its volume was removed is not kept (`fetchFigureImage`).
    ///
    /// - Parameter volumeId: A volume whose XML is in ``volumesDirectory``.
    /// - Returns: What the run found and did. All zeroes when this manager fetches no images, the
    ///   volume is not on disk, or its XML could not be read.
    @discardableResult
    public func fetchFigureImages(for volumeId: String) async -> FigureFetchOutcome {
        guard figureTransfer != nil, isVolumeDownloaded(volumeId) else { return FigureFetchOutcome() }
        let run = FigureRun(volumeId: volumeId, text: figureTexts[volumeId, default: 0])
        if let running = figureFetches[run] { return await running.value }
        // The run takes itself off the list as its last step, on this actor, before its outcome
        // reaches anyone waiting for it — so a call made once a run has ended always starts a new
        // one, and retries what that run could not fetch, instead of being handed its outcome.
        let task = Task {
            let outcome = await self.performFigureFetch(run)
            self.figureFetches[run] = nil
            return outcome
        }
        figureFetches[run] = task
        return await task.value
    }

    /// One whole-volume run: see ``fetchFigureImages(for:)``.
    private func performFigureFetch(_ run: FigureRun) async -> FigureFetchOutcome {
        let volumeId = run.volumeId
        var outcome = FigureFetchOutcome()
        let xmlURL = volumeURL(for: volumeId)
        // Which file the names are read from, taken before it is read: the record below is of
        // this text, and a file that changes under the scan no longer matches it.
        let stamp = FigureImageLibrary.textStamp(ofVolumeAt: xmlURL)
        // Off the actor: a volume is several megabytes of XML.
        let scanned = await Task.detached(priority: .utility) {
            FigureImageLibrary.graphicNames(inVolumeAt: xmlURL)
        }.value
        // An unreadable volume names nothing — and prunes nothing, or a parse failure would
        // delete every image the volume has.
        guard let names = scanned else { return outcome }
        let fileNames = names.compactMap(FigureImageName.fileName(forGraphic:))
        outcome.named = fileNames.count
        figureLibrary.removeImages(notIn: Set(fileNames), for: volumeId)

        for fileName in fileNames {
            // An update has replaced the text these names came from: the update's own run reads
            // the new text, and a name only the old one gave must not be fetched after that run
            // has dropped it.
            guard figureTexts[volumeId, default: 0] == run.text else { return outcome }
            switch await fetchFigureImage(volumeId: volumeId, fileName: fileName, thenTheRest: false) {
            case .onDevice: outcome.present += 1
            case .stored:   outcome.stored += 1
            case .refused:  outcome.refused += 1
            case .failed:   outcome.failed += 1
            }
        }
        // Nothing is left to fetch for this text — every name is on the device or the host has
        // none — so the pass over the library need not scan it again. A run that left a transfer
        // failed records nothing, and the next pass tries again.
        if outcome.failed == 0, let stamp {
            figureLibrary.recordComplete(volumeId, stamp: stamp)
        }
        #if DEBUG
        print("[DownloadManager] Figures for \(volumeId): \(outcome)")
        #endif
        return outcome
    }

    /// Brings the volumes already on the device up to their figure images (#1516 review, round 1).
    ///
    /// Owner decision D3 is that a volume's images are downloaded with it and readable offline.
    /// The download hook does that for a volume downloaded from now on; this pass does it for
    /// every other: a volume downloaded before figure images existed, one whose run was cut
    /// short when the app was suspended or quit, and one a transfer failed for. The app calls it
    /// at launch and each time the device comes back online.
    ///
    /// It walks the downloaded volumes among `catalogueVolumeIds` in id order, one at a time,
    /// skipping every volume recorded complete for the text it holds now
    /// (`FigureImageLibrary.isRecordedComplete`), and runs ``fetchFigureImages(for:)`` for each
    /// of the rest. So a library is scanned once, not at every launch: a volume is read again
    /// only after its text changes or while something of its is still to fetch.
    ///
    /// The pass stops when the manager is suspended (the device went offline), and after
    /// ``figureBackfillPatience`` volumes in a row whose transfers all failed — the host is not
    /// answering, or the connection is cellular with Allow Cellular Downloads off — so a launch
    /// that cannot fetch does not read the whole library's XML to find that out.
    ///
    /// - Parameter catalogueVolumeIds: The volumes the app has an address for on
    ///   history.state.gov: the catalogue's ids (`DownloadedVolumesListModel.redownloadableVolumeIds`).
    ///   A side-loaded volume is not among them (#777).
    /// - Returns: The volumes a run was made for, in order. A call made while a pass is running
    ///   returns that pass's.
    @discardableResult
    public func fetchMissingFigureImages(among catalogueVolumeIds: Set<String>) async -> [String] {
        guard figureTransfer != nil, isEnabled else { return [] }
        if let running = figureBackfill { return await running.value }
        let task = Task {
            let visited = await self.performFigureBackfill(among: catalogueVolumeIds)
            self.figureBackfill = nil
            return visited
        }
        figureBackfill = task
        return await task.value
    }

    /// One pass over the library: see ``fetchMissingFigureImages(among:)``.
    private func performFigureBackfill(among catalogueVolumeIds: Set<String>) async -> [String] {
        let onDevice = ((try? FileManager.default.contentsOfDirectory(
            at: volumesDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? [])
            .filter { $0.pathExtension == "xml" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .filter(catalogueVolumeIds.contains)
            .sorted()
        var visited: [String] = []
        var unanswered = 0
        for volumeId in onDevice {
            guard isEnabled else { break }
            guard !figureLibrary.isRecordedComplete(volumeId, at: volumeURL(for: volumeId)) else { continue }
            let outcome = await fetchFigureImages(for: volumeId)
            visited.append(volumeId)
            if outcome.stored > 0 {
                unanswered = 0
            } else if outcome.failed > 0 {
                unanswered += 1
                if unanswered >= Self.figureBackfillPatience { break }
            }
        }
        #if DEBUG
        print("[DownloadManager] Figure pass: \(visited.count) of \(onDevice.count) volumes on the device read.")
        #endif
        return visited
    }

    /// Fetches one figure image if it is not on the device: what the reader or an export asks
    /// for when it needs an image ``fetchMissingFigureImages(among:)`` has not yet reached.
    ///
    /// - Parameters:
    ///   - volumeId: The volume the image belongs to. Its XML must be on the device.
    ///   - fileName: The image's file name (`FigureImageName.fileName`).
    /// - Returns: Whether the image is on the device when the call returns.
    public func fetchFigureImage(volumeId: String, fileName: String) async -> Bool {
        switch await fetchFigureImage(volumeId: volumeId, fileName: fileName, thenTheRest: true) {
        case .onDevice, .stored: return true
        case .refused, .failed: return false
        }
    }

    /// Fetches one image, de-duplicated by volume and file name.
    ///
    /// - Parameter thenTheRest: After a fetch asked for by the reader or an export, whether to go
    ///   on to the rest of the volume's images in the background — so a volume the pass over
    ///   the library has not reached is complete, and readable offline, after its first figure
    ///   is looked at.
    private func fetchFigureImage(volumeId: String, fileName: String,
                                  thenTheRest: Bool) async -> FigureImageFetch {
        guard let destination = figureLibrary.fileURL(volumeId: volumeId, fileName: fileName),
              isVolumeDownloaded(volumeId) else { return .failed }
        if FileManager.default.fileExists(atPath: destination.path) { return .onDevice }
        if figuresRefused[volumeId]?.contains(fileName) == true { return .refused }
        guard let transfer = figureTransfer,
              let remote = FigureImageLibrary.remoteURL(volumeId: volumeId, fileName: fileName) else {
            return .failed
        }
        let key = "\(volumeId)/\(fileName)"
        if let running = figureImageFetches[key] { return await running.value }

        let allowsCellular = (preferences.object(forKey: SettingsKeys.allowCellularDownloads) as? Bool) ?? true
        let library = figureLibrary
        let task = Task<FigureImageFetch, Never> {
            var request = URLRequest(url: remote)
            request.setValue("FRUSExplorer/2.0", forHTTPHeaderField: "User-Agent")
            request.allowsCellularAccess = allowsCellular
            do {
                let (data, response) = try await transfer(request)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                // 403 is what the image host answers for a file it does not have. A 200 that is
                // not a PNG is some other page — a network's sign-in page, say — so it is not
                // kept, and not remembered as a refusal either: the next request may be answered.
                if status == 403 || status == 404 { return .refused }
                guard (200..<300).contains(status), FigureImageLibrary.isPNG(data) else { return .failed }
                return library.store(data, volumeId: volumeId, fileName: fileName) ? .stored : .failed
            } catch {
                return .failed
            }
        }
        figureImageFetches[key] = task
        let result = await task.value
        figureImageFetches[key] = nil
        if result == .refused { figuresRefused[volumeId, default: []].insert(fileName) }
        // A volume removed while its image was in flight keeps none of them.
        if result == .stored, !isVolumeDownloaded(volumeId) {
            figureLibrary.removeImages(for: volumeId)
            return .failed
        }
        if thenTheRest, result == .stored { startFigureFetch(for: volumeId) }
        return result
    }

    /// Removes `volumeId`'s figure images: called wherever the volume's XML is removed. A fetch
    /// still running finds no volume to fetch for, and the one image it may have in flight is
    /// removed when it lands (`fetchFigureImage`).
    private func discardFigureImages(for volumeId: String) {
        figureLibrary.removeImages(for: volumeId)
        figureLibrary.recordComplete(volumeId, stamp: nil)
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
                self.retryDownload(volumeId: volumeId, downloadUrl: urlString)
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

    /// Recursively sums file sizes under a directory, optionally skipping whole
    /// subdirectories (compared by standardized path, descendants included).
    ///
    /// The exclusion exists for one measured reason (#926 item 2): the index directory
    /// CONTAINS the volumes and semantic-vector directories, so an unexcluded walk
    /// counts their bytes into the index figure — which double-counts them against the
    /// figures that report those directories directly. Internal + static so the rule is
    /// unit-testable against a real temp tree.
    nonisolated static func directorySize(
        at url: URL,
        excludingSubdirectories excluded: [URL] = []
    ) -> Int {
        let excludedPaths = Set(excluded.map { $0.standardizedFileURL.path })
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: .skipsHiddenFiles
        ) else { return 0 }
        var total = 0
        while let item = enumerator.nextObject() {
            guard let fileURL = item as? URL else { continue }
            let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
            if values?.isDirectory == true {
                if excludedPaths.contains(fileURL.standardizedFileURL.path) {
                    enumerator.skipDescendants()
                }
                continue
            }
            total += values?.fileSize ?? 0
        }
        return total
    }
}

// MARK: - Figure Images (#1516)

/// What one whole-volume figure fetch found and did (`DownloadManager.fetchFigureImages(for:)`).
///
/// Version history:
///   1.0 — #1516: initial implementation
public struct FigureFetchOutcome: Sendable, Equatable {
    /// Images the volume's text names outside its title page.
    public var named = 0
    /// Of those, already on the device.
    public var present = 0
    /// Fetched and written by this run.
    public var stored = 0
    /// Refused by the server: it has no such file (HTTP 403 or 404). Not asked for again this session.
    public var refused = 0
    /// Not fetched: the transfer failed, the server answered with an error or with something
    /// that is no PNG, or the image could not be written. The next run asks again.
    public var failed = 0

    /// Creates an outcome of all zeroes.
    public init() {}
}

/// How one figure image's fetch ended.
enum FigureImageFetch: Sendable, Equatable {
    /// It was already on the device; nothing was asked for.
    case onDevice
    /// Fetched and written.
    case stored
    /// The server has none (HTTP 403 or 404).
    case refused
    /// The transfer failed, the answer was an error or no PNG, or the image could not be written.
    case failed
}

/// Where a volume's figure images are kept on the device, where history.state.gov serves them,
/// and which images a volume's text names (#1516, owner decision D3 option (f)4).
///
/// ## On the device
/// `{Volumes}/{volumeId}.figures/{name}.png` — beside the volume's XML, as the decision asks.
/// Everything that sweeps the volumes directory looks for `.xml` files (`storageReport`,
/// `IndexingPipeline.findDownloadedVolumes`, `LocalVolumeCatalog`, `ResetService`,
/// `OnboardingViewModel.hasDownloadedVolumes`), so a `.figures` folder is none of theirs, and
/// each place that removes a volume's XML removes its folder by name: `DownloadManager`'s
/// `deleteVolume` and `cancelDownload`, and `ResetService.resetLocalData` through
/// ``removeAllImages()``. The folder is excluded from backups, as the XML is: both can be
/// fetched again.
///
/// ## On history.state.gov
/// `https://static.history.state.gov/frus/{volumeId}/{name}.png`, where `name` is the
/// `<graphic url>` and `.png` is added to every one. Measured 2026-10-01 by HEAD request over the
/// 553 manifest volumes at corpus `8e5da08c1`: the corpus's `<figure>`s name 968 distinct images;
/// 402 are on title pages, not one of which is served and none of which the app draws (a title
/// page is outside every `<div>`); of the other 566, in 99 volumes, **553 are served — 140,994,857 bytes (141.0 MB) in 96 volumes** —
/// and 13 are refused with HTTP 403. Per volume that has any: a median of 328 KB (328,492.5
/// bytes, the mean of the 48th and 49th of the 96), the largest `frus1943CairoTehran` at 25.4 MB;
/// the largest single image is 3.6 MB. Every one of the 553 opens with the PNG signature (their
/// first 24 bytes read 2026-10-01), `OpenPitMine.jpg.png` among them; the widest is 19,043
/// pixels (`frus1958-60v03mSupp`'s `eq_03.png`) and the tallest 5,536.
///
/// ## Which volumes are complete
/// `{Volumes}/.figure-images-complete.json` records, per volume, the size and modification date
/// of the XML whose every named image is on the device or refused by the host
/// (``recordComplete(_:stamp:)``). `DownloadManager.fetchMissingFigureImages(among:)` skips a
/// volume whose record matches the file it holds now, so the library's XML is scanned once and
/// not at every launch. The record is a hidden file — no sweep of the directory sees it — and
/// is removed with the images by ``removeAllImages()``.
///
/// Version history:
///   1.0 — #1516: initial implementation
///   1.1 — #1516 review, round 1: the completion record
public struct FigureImageLibrary: Sendable {

    /// The app's volumes directory.
    public let volumesDirectory: URL

    /// Creates a library over `volumesDirectory`.
    public init(volumesDirectory: URL) {
        self.volumesDirectory = volumesDirectory
    }

    /// The root history.state.gov serves a volume's images under.
    public static let remoteBase = URL(string: "https://static.history.state.gov/frus")!

    /// The session figure images are fetched with: nothing cached or stored beyond the file the
    /// app writes itself, and a request that makes no progress for 30 seconds gives up rather
    /// than hold the reader's placeholder indefinitely.
    static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()

    // MARK: Names and places

    /// Whether `component` can be one path component: a volume id or an image's file name. A
    /// value holding a separator, or naming the folder itself or its parent, is refused, so
    /// neither a volume's markup nor a `frusexplorer://figure/` URL can reach outside the folder.
    ///
    /// The rule is the kit's `FRUSURLScheme.isSafeComponent(_:)` (FRUSCoreKit), which the reader's
    /// figure URLs are checked by too.
    public static func isSafeComponent(_ component: String) -> Bool {
        FRUSURLScheme.isSafeComponent(component)
    }

    /// The folder `volumeId`'s images are kept in, whether or not it exists.
    public func directory(for volumeId: String) -> URL {
        volumesDirectory.appendingPathComponent("\(volumeId).figures", isDirectory: true)
    }

    /// Where the image named `fileName` in `volumeId` is kept, whether or not it is there; `nil`
    /// when either name is not a safe path component.
    public func fileURL(volumeId: String, fileName: String) -> URL? {
        guard Self.isSafeComponent(volumeId), Self.isSafeComponent(fileName) else { return nil }
        return directory(for: volumeId).appendingPathComponent(fileName, isDirectory: false)
    }

    /// Where `image` is kept, whether or not it is there; `nil` when its volume is unknown or
    /// its name is no file name.
    public func fileURL(for image: FigureImageName) -> URL? {
        guard let volumeId = image.volumeId, let fileName = image.fileName else { return nil }
        return fileURL(volumeId: volumeId, fileName: fileName)
    }

    /// The address history.state.gov serves `fileName` of `volumeId` at; `nil` when either name
    /// is not a safe path component. A name with a space (`Document A.1.png`) is percent-encoded.
    public static func remoteURL(volumeId: String, fileName: String) -> URL? {
        guard isSafeComponent(volumeId), isSafeComponent(fileName) else { return nil }
        return remoteBase.appendingPathComponent(volumeId).appendingPathComponent(fileName)
    }

    // MARK: Reading and writing

    /// The bytes of the image named `fileName` in `volumeId`, or `nil` when it is not on the device.
    public func data(volumeId: String, fileName: String) -> Data? {
        guard let url = fileURL(volumeId: volumeId, fileName: fileName) else { return nil }
        return try? Data(contentsOf: url, options: .mappedIfSafe)
    }

    /// `image`'s bytes, or `nil` when it is not on the device.
    public func data(for image: FigureImageName) -> Data? {
        guard let url = fileURL(for: image) else { return nil }
        return try? Data(contentsOf: url, options: .mappedIfSafe)
    }

    /// Whether `data` opens with the PNG signature. Every image the corpus names is served as
    /// `image/png`; anything else the transfer returned is not an image to keep.
    public static func isPNG(_ data: Data) -> Bool {
        data.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    }

    /// The pixel size a PNG states in its header, or `nil` when `data` is no PNG: what the Word
    /// export sizes an image by without decoding it.
    public static func pngPixelSize(_ data: Data) -> (width: Int, height: Int)? {
        guard isPNG(data), data.count >= 24 else { return nil }
        let bytes = [UInt8](data.prefix(24))
        // The IHDR chunk is first: its width and height are big-endian at offsets 16 and 20.
        let width = bytes[16..<20].reduce(0) { $0 << 8 | Int($1) }
        let height = bytes[20..<24].reduce(0) { $0 << 8 | Int($1) }
        return width > 0 && height > 0 ? (width, height) : nil
    }

    /// Writes `data` as the image named `fileName` in `volumeId`, creating the volume's folder.
    ///
    /// - Returns: Whether the file was written.
    @discardableResult
    func store(_ data: Data, volumeId: String, fileName: String) -> Bool {
        guard let destination = fileURL(volumeId: volumeId, fileName: fileName) else { return false }
        let folder = directory(for: volumeId)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            // Re-downloadable, like the volume's XML: no place in a backup.
            try? (folder as NSURL).setResourceValue(true, forKey: .isExcludedFromBackupKey)
            try data.write(to: destination, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    /// The total size of `volumeId`'s images on the device.
    public func bytes(for volumeId: String) -> Int {
        let folder = directory(for: volumeId)
        guard FileManager.default.fileExists(atPath: folder.path) else { return 0 }
        return DownloadManager.directorySize(at: folder)
    }

    /// Removes every image of `volumeId`, and its folder.
    public func removeImages(for volumeId: String) {
        try? FileManager.default.removeItem(at: directory(for: volumeId))
    }

    /// Removes the images of `volumeId` whose file names are not in `fileNames`: what an updated
    /// volume's text no longer names. The folder goes too when nothing is left to name.
    func removeImages(notIn fileNames: Set<String>, for volumeId: String) {
        let folder = directory(for: volumeId)
        guard let present = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return }
        for name in present where !fileNames.contains(name) {
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(name))
        }
        if fileNames.isEmpty { try? FileManager.default.removeItem(at: folder) }
    }

    /// Removes every volume's images: Reset Local Data's sweep, which deletes the XML files
    /// directly rather than through `DownloadManager.deleteVolume`.
    public func removeAllImages() {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: volumesDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else { return }
        for url in contents where url.pathExtension == "figures" {
            try? FileManager.default.removeItem(at: url)
        }
        try? FileManager.default.removeItem(at: completionRecordURL)
    }

    // MARK: Which volumes are complete

    /// The name of the file, in the volumes directory, that records which volumes need no
    /// further figure fetch. Hidden, so nothing that lists the directory meets it.
    static let completionRecordName = ".figure-images-complete.json"

    /// Where the completion record is kept.
    var completionRecordURL: URL {
        volumesDirectory.appendingPathComponent(Self.completionRecordName, isDirectory: false)
    }

    /// What identifies the text of the volume at `url` without reading it: the file's size and
    /// its modification date. `nil` when the file is not there. Whatever replaces a volume's
    /// XML — an update, a side-loaded copy under a catalogue id — writes a new file, so the
    /// stamp changes with the text.
    static func textStamp(ofVolumeAt url: URL) -> String? {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
              let size = values.fileSize, let modified = values.contentModificationDate else { return nil }
        return "\(size)-\(modified.timeIntervalSinceReferenceDate)"
    }

    /// The record: the stamp of each volume's text whose images are complete.
    private func completionRecord() -> [String: String] {
        guard let data = try? Data(contentsOf: completionRecordURL),
              let record = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return record
    }

    /// Whether `volumeId` is recorded complete for the text now at `url`.
    func isRecordedComplete(_ volumeId: String, at url: URL) -> Bool {
        guard let stamp = Self.textStamp(ofVolumeAt: url) else { return false }
        return completionRecord()[volumeId] == stamp
    }

    /// Records `volumeId` complete for the text stamped `stamp`, or with `nil` forgets it.
    /// Called only on `DownloadManager`'s actor, so two writes cannot interleave.
    func recordComplete(_ volumeId: String, stamp: String?) {
        var record = completionRecord()
        guard record[volumeId] != stamp else { return }
        record[volumeId] = stamp
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(record) else { return }
        try? data.write(to: completionRecordURL, options: .atomic)
        // Not for a backup: the XML it describes is excluded from one, so restored it would
        // describe volumes that are not there. (An atomic write replaces the file, so each time.)
        try? (completionRecordURL as NSURL).setResourceValue(true, forKey: .isExcludedFromBackupKey)
    }

    // MARK: Which images a volume names

    /// The `<graphic url>` of every `<figure>` in the volume at `url` that is not on its title
    /// page, in document order, each once — or `nil` when the file cannot be read or parsed.
    ///
    /// Only figures. A page's scan is a `<graphic>` as well, in a `<facsimile>`'s `<surface>`:
    /// measured 2026-10-01 at corpus `8e5da08c1`, 1,143,043 of them in 551 of the 553 manifest
    /// volumes, against 992 `<graphic>`s in figures and none anywhere else — so the rule is "in a
    /// `<figure>`", never "every `<graphic>`", and a scan is never fetched. No figure names two.
    /// A title page's `<figure>` (403 of the 553 volumes have one; 402 name a graphic, and
    /// `frus1865p4`'s is empty) is left out because the app draws no title page — all 403 sit
    /// outside every `<div>`, so in no document the parser returns — and history.state.gov
    /// serves none of them. Two more figures sit outside every `<div>`, directly in `<front>`
    /// (`frus1931-41v02`'s `figure_0007`, served, 284,620 bytes; `frus1952-54v04`'s
    /// `figure_0001`, refused): the scan does name those, though no document draws them.
    public static func graphicNames(inVolumeAt url: URL) -> [String]? {
        guard let parser = XMLParser(contentsOf: url) else { return nil }
        let scanner = FigureGraphicScanner()
        parser.delegate = scanner
        parser.shouldResolveExternalEntities = false
        guard parser.parse() else { return nil }
        return scanner.names
    }
}

/// Collects the graphics a volume's figures name (`FigureImageLibrary.graphicNames(inVolumeAt:)`).
private final class FigureGraphicScanner: NSObject, XMLParserDelegate {
    /// The names met so far, in document order, each once.
    private(set) var names: [String] = []
    private var seen = Set<String>()
    private var figureDepth = 0
    private var titlePageDepth = 0

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        switch elementName {
        case "figure": figureDepth += 1
        case "titlePage": titlePageDepth += 1
        case "graphic":
            guard figureDepth > 0, titlePageDepth == 0, let name = attributeDict["url"],
                  !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  seen.insert(name).inserted else { return }
            names.append(name)
        default: break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        switch elementName {
        case "figure": figureDepth = max(0, figureDepth - 1)
        case "titlePage": titlePageDepth = max(0, titlePageDepth - 1)
        default: break
        }
    }
}

/// The app's figure images, for everything that draws one: the reader's scheme handler and the
/// PDF, Word and HTML exports (#1516).
///
/// One per process, configured at boot with the library and a way to fetch an image that is not
/// on the device. Until then it has no image and fetches none, so every figure prints its
/// placeholder — and so it stays in a unit test's host: the tests run inside the app, whose boot
/// would otherwise point this store at the simulator's own volumes and at the network, so
/// `FRUSExplorerApp.bootDownloadManager` leaves it unconfigured there (``isUnitTestHost(_:)``).
/// A test that wants images passes a store of its own.
///
/// ## Why a shared instance
/// The reader's web view is built by a representable that is handed a render model and nothing
/// else, and `FRUSURLSchemeHandler` answers its image requests on WebKit's call; neither has an
/// `AppState` to ask, and a view in a window opened without one in its environment must not
/// declare that it needs one. The exporters are built by a factory that is handed a format and
/// nothing else (`CollectionExportFormat.makeExporter()`). Each of them takes a store as a
/// parameter defaulting to this one, so a test passes its own.
///
/// Version history:
///   1.0 — #1516: initial implementation
///   1.1 — #1516 review, round 1: `isUnitTestHost(_:)`; `fetchAbsent` stops when its task is cancelled
final class FigureImageStore: @unchecked Sendable {

    /// The process-wide store.
    static let shared = FigureImageStore()

    /// Fetches the image named `fileName` in `volumeId`, returning whether it is then on the device.
    typealias Fetch = @Sendable (_ volumeId: String, _ fileName: String) async -> Bool

    private let lock = NSLock()
    private var library: FigureImageLibrary?
    private var fetch: Fetch?

    /// Creates a store with no library: every image is absent until ``configure(library:fetch:)``.
    init() {}

    /// Creates a configured store.
    convenience init(library: FigureImageLibrary, fetch: Fetch? = nil) {
        self.init()
        configure(library: library, fetch: fetch)
    }

    /// Points the store at the device's figure images.
    ///
    /// - Parameters:
    ///   - library: Where the images are kept.
    ///   - fetch: How an absent image is fetched, or `nil` to fetch none.
    func configure(library: FigureImageLibrary, fetch: Fetch?) {
        lock.lock()
        self.library = library
        self.fetch = fetch
        lock.unlock()
    }

    private var configuration: (library: FigureImageLibrary?, fetch: Fetch?) {
        lock.lock()
        defer { lock.unlock() }
        return (library, fetch)
    }

    /// `image`'s bytes, or `nil` when it is not on the device.
    func data(for image: FigureImageName) -> Data? {
        configuration.library?.data(for: image)
    }

    /// The bytes of the image named `fileName` in `volumeId`, or `nil` when it is not on the device.
    func data(volumeId: String, fileName: String) -> Data? {
        configuration.library?.data(volumeId: volumeId, fileName: fileName)
    }

    /// Whether the app may fetch a figure image of `volumeId` that is not on the device: only
    /// while online, and only for a catalogue volume. A side-loaded volume has no address the app
    /// knows on history.state.gov, and its id need not be one the site publishes under (#777).
    ///
    /// - Parameters:
    ///   - volumeId: The volume the image belongs to.
    ///   - isOnline: `AppState.isOnline`.
    ///   - catalogueVolumeIds: `DownloadedVolumesListModel.redownloadableVolumeIds(in:)`.
    static func mayFetch(volumeId: String, isOnline: Bool, catalogueVolumeIds: Set<String>) -> Bool {
        isOnline && catalogueVolumeIds.contains(volumeId)
    }

    /// Whether this process is a unit test's host: the app, launched by XCTest to run the unit
    /// target inside it. The app's store is left unconfigured there and the pass over the
    /// library is not started, so no unit test reads the simulator's figures or reaches
    /// history.state.gov through a default. A UI test's app is not one: XCTest sets this
    /// variable in the process that runs the tests, which for a UI test is the runner.
    ///
    /// - Parameter environment: `ProcessInfo.processInfo.environment`.
    static func isUnitTestHost(_ environment: [String: String]) -> Bool {
        environment["XCTestConfigurationFilePath"] != nil
    }

    /// Fetches the image named `fileName` in `volumeId` unless it is on the device.
    ///
    /// - Returns: Whether the image is on the device when the call returns.
    func fetchIfAbsent(volumeId: String, fileName: String) async -> Bool {
        let (library, fetch) = configuration
        guard let library, let url = library.fileURL(volumeId: volumeId, fileName: fileName) else { return false }
        if FileManager.default.fileExists(atPath: url.path) { return true }
        guard let fetch else { return false }
        return await fetch(volumeId, fileName)
    }

    /// Fetches each of `images` that is not on the device, one after another: what a PDF, Word
    /// or HTML export does before it prints, so a volume whose images are not yet on the device
    /// exports with them. Stops between images when its task is cancelled.
    func fetchAbsent(_ images: [FigureImageName]) async {
        var asked = Set<FigureImageName>()
        for image in images where asked.insert(image).inserted {
            if Task.isCancelled { return }
            guard let volumeId = image.volumeId, let fileName = image.fileName else { continue }
            _ = await fetchIfAbsent(volumeId: volumeId, fileName: fileName)
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
