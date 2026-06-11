// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - BackgroundDownloadEngine

/// Delegate-based wrapper around a background `URLSession` for volume downloads.
///
/// ## Why a background session
/// `URLSession.shared.download(for:)` transfers run in-process: they die when iOS
/// suspends or terminates the app, and the previous `DownloadManager` documented
/// exactly that limitation ("active downloads that were in flight when the app was
/// killed are not automatically re-queued"). A background session hands the
/// transfer to the system download daemon — it continues while the app is
/// suspended, survives termination, and is re-attached on the next launch via the
/// shared session identifier.
///
/// ## Architecture
/// One shared engine per process (the session identifier must be unique per
/// session object). `DownloadManager` attaches a completion callback at boot and
/// submits/cancels transfers; the engine owns the file move into the volumes
/// directory (which must happen synchronously inside
/// `urlSession(_:downloadTask:didFinishDownloadingTo:)` — the temporary file is
/// deleted when that delegate method returns).
///
/// Each download task carries its `volumeId` in `taskDescription`, which the
/// session persists — after an app relaunch the re-attached tasks still know which
/// volume they belong to.
///
/// ## Background launches (iOS)
/// When all of a background session's events have been delivered after the system
/// relaunched the app, UIKit requires the stored
/// `handleEventsForBackgroundURLSession` completion handler to be called.
/// `FRUSAppDelegate` stores it via `storeBackgroundCompletionHandler(_:)`; the
/// engine calls it from `urlSessionDidFinishEvents(forBackgroundURLSession:)`.
/// Files downloaded during such a launch are moved into place even though
/// `DownloadManager` is not attached yet; indexing for them is reconciled at the
/// next full app boot.
///
/// Version history:
///   1.0 — Session 2026-06-09: initial implementation (Phase 3c download hardening)
final class BackgroundDownloadEngine: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {

    // MARK: - Shared Instance

    /// The process-wide engine. Shared because a background session identifier may
    /// only be in use by one `URLSession` at a time, and because the engine must be
    /// constructible from `FRUSAppDelegate` during a background launch, before
    /// `DownloadManager` exists.
    static let shared = BackgroundDownloadEngine()

    /// Background session identifier (stable across launches — this is how the
    /// system re-associates in-flight transfers with the relaunched app).
    static let sessionIdentifier = "bottsywattsy.FRUS-Explorer.volume-downloads"

    // MARK: - State

    /// Guards the mutable callback properties; delegate callbacks arrive on the
    /// session's serial delegate queue while attach/store calls arrive elsewhere.
    private let lock = NSLock()

    /// Set by `DownloadManager` at boot. Receives `(volumeId, error)` after each
    /// transfer finishes (file already moved into place when `error == nil`).
    private var onTransferComplete: (@Sendable (String, Error?) -> Void)?

    /// Stored `handleEventsForBackgroundURLSession` completion handler (iOS).
    private var backgroundCompletionHandler: (@Sendable () -> Void)?

    /// Destination directory for completed volume files:
    /// `{Application Support}/FRUSExplorer/Volumes/`.
    private let volumesDirectory: URL

    /// The background session. Created lazily on first use so merely referencing
    /// `shared` (e.g. to store a completion handler) does not spin up the daemon
    /// connection before it is needed.
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        config.sessionSendsLaunchEvents = true
        config.waitsForConnectivity = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    // MARK: - Init

    /// Creates the engine with the standard volumes directory. Private — use `shared`.
    private override init() {
        self.volumesDirectory = Self.makeVolumesDirectory()
        super.init()
    }

    /// Returns (and creates if necessary) the volumes storage directory.
    /// Mirrors `FRUSExplorerApp.makeVolumesDirectory()` so the engine can resolve
    /// the destination during background launches, before the app UI exists.
    static func makeVolumesDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("FRUSExplorer/Volumes", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - DownloadManager Interface

    /// Attaches the completion callback that routes finished transfers back into
    /// `DownloadManager`. Called once at boot; replaces any prior callback.
    func attach(onTransferComplete: @escaping @Sendable (String, Error?) -> Void) {
        lock.lock()
        self.onTransferComplete = onTransferComplete
        lock.unlock()
    }

    /// Submits a volume download to the background session.
    ///
    /// The `volumeId` rides along in `taskDescription`, which the session persists
    /// across app relaunches. `allowsCellular` is applied per-request — the
    /// background session's `URLSessionConfiguration` is immutable once created,
    /// but `URLRequest.allowsCellularAccess` is honoured by background transfers
    /// (Session 154 cellular download policy).
    func startDownload(volumeId: String, from url: URL, allowsCellular: Bool = true) {
        var request = URLRequest(url: url)
        request.setValue("FRUSExplorer/2.0", forHTTPHeaderField: "User-Agent")
        request.allowsCellularAccess = allowsCellular
        let task = session.downloadTask(with: request)
        task.taskDescription = volumeId
        task.resume()
    }

    /// Cancels the in-flight transfer for a volume, if any.
    func cancelDownload(volumeId: String) {
        session.getAllTasks { tasks in
            for task in tasks where task.taskDescription == volumeId {
                task.cancel()
            }
        }
    }

    /// Volume IDs with transfers currently registered with the session — including
    /// transfers started before the last app termination, which the background
    /// daemon kept alive. `DownloadManager` adopts these at boot so they are
    /// reflected in queue state instead of being silently lost.
    func inFlightVolumeIds() async -> [String] {
        let (_, _, downloadTasks) = await session.tasks
        return downloadTasks.compactMap(\.taskDescription)
    }

    // MARK: - Background Launch Plumbing (iOS)

    /// Stores the completion handler from
    /// `application(_:handleEventsForBackgroundURLSession:completionHandler:)` and
    /// ensures the session exists so pending events are delivered.
    func storeBackgroundCompletionHandler(_ handler: @escaping @Sendable () -> Void) {
        lock.lock()
        backgroundCompletionHandler = handler
        lock.unlock()
        // Touch the lazy session: recreating it with the shared identifier is what
        // triggers delivery of the queued background events.
        _ = session
    }

    // MARK: - URLSessionDownloadDelegate

    /// Moves the finished download into the volumes directory.
    ///
    /// Must complete synchronously — `location` is deleted when this method
    /// returns. Non-2xx HTTP responses are treated as failures and reported via
    /// `didCompleteWithError` semantics below.
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let volumeId = downloadTask.taskDescription else { return }

        if let http = downloadTask.response as? HTTPURLResponse,
           !(200..<300).contains(http.statusCode) {
            notify(volumeId: volumeId, error: URLError(.badServerResponse))
            return
        }

        let destURL = volumesDirectory.appendingPathComponent("\(volumeId).xml")
        do {
            // Remove any stale file before moving the new one into place.
            try? FileManager.default.removeItem(at: destURL)
            try FileManager.default.moveItem(at: location, to: destURL)
            // Exclude from iCloud backup — volume XML is re-downloadable.
            try? (destURL as NSURL).setResourceValue(true, forKey: .isExcludedFromBackupKey)
            notify(volumeId: volumeId, error: nil)
        } catch {
            notify(volumeId: volumeId, error: error)
        }
    }

    /// Reports transport-level failures (timeouts, connectivity, cancellation).
    /// Success is reported from `didFinishDownloadingTo`, so only the error path
    /// notifies here.
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error, let volumeId = task.taskDescription else { return }
        notify(volumeId: volumeId, error: error)
    }

    /// Calls the stored background-launch completion handler once all events for
    /// the background session have been delivered (iOS requirement).
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        lock.lock()
        let handler = backgroundCompletionHandler
        backgroundCompletionHandler = nil
        lock.unlock()
        if let handler {
            DispatchQueue.main.async { handler() }
        }
    }

    // MARK: - Private

    /// Routes a transfer result to the attached `DownloadManager` callback, if any.
    /// During background launches no manager is attached; the file (on success) is
    /// already in place and indexing is reconciled at the next full boot.
    private func notify(volumeId: String, error: Error?) {
        lock.lock()
        let callback = onTransferComplete
        lock.unlock()
        callback?(volumeId, error)
    }
}
