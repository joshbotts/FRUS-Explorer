// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - PendingStoreReset

/// Clears the app's SwiftData stores at the next launch, before anything opens them.
///
/// Backs Settings ▸ Data & Recovery ▸ **Fix iCloud Sync**: the local copy of synced data goes,
/// CloudKit's copy is untouched, and the next launch pulls everything down again.
///
/// ## Why the work is deferred to launch
/// The obvious implementation deletes the store files when the button is tapped. That cannot work.
/// By the time any UI exists the container is open on those files, so a delete unlinks the file
/// from under a live SQLite connection: the session keeps writing to an inode with no name, every
/// save after the tap is lost, and CloudKit's mirroring metadata is torn mid-flight. Doing it at
/// launch — before ``ModelContainer/makeFRUSContainer()`` builds a configuration — is the only
/// point where no connection exists. The cost is that the user must quit and reopen, which the
/// confirmation dialog says plainly.
///
/// ## Why the file list is explicit
/// This deletes files inside the same Application Support directory that holds `frus.db`, the FTS5
/// index — 6.3 GB on the owner's Mac, rebuildable only by re-parsing every volume — and the
/// `volumes/` directory of downloaded XML. So it never enumerates a directory and never matches on
/// a pattern. It takes the two store URLs it is given, appends the five suffixes SwiftData and
/// CloudKit mirroring are known to create, and deletes exactly those paths. Anything not on that
/// list survives by construction rather than by a guard someone has to keep correct.
///
/// The predecessor did match on a pattern, and matched the wrong one: it deleted files whose
/// extension was `sqlite`, while the stores on disk are `default.store` and
/// `FRUSExplorerLocal.store`. Both loops found nothing on every platform, so the button had never
/// once cleared a store — it only sent the user back through onboarding, which made it look like
/// it had worked.
///
/// Version history:
///   1.0 — replaces the extension-matching reset that could not match the real store names
enum PendingStoreReset {

    /// `UserDefaults` key holding the request. Namespaced so it cannot collide with an
    /// `@AppStorage` key elsewhere in the app.
    static let requestKey = "frus.pendingStoreReset"

    /// Suffixes appended to a store's path to form the full set of files SwiftData and CloudKit
    /// mirroring create alongside it.
    ///
    /// `-wal` and `-shm` are SQLite's write-ahead log and shared-memory index. Leaving a WAL behind
    /// next to a deleted store is how a "reset" resurrects rows.
    private static let storeFileSuffixes = ["", "-wal", "-shm"]

    // MARK: - The request

    /// Records that the stores should be cleared at the next launch.
    ///
    /// - Parameter defaults: injectable so tests never touch the real domain.
    static func request(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: requestKey)
    }

    /// `true` when a reset is waiting for the next launch.
    static func isRequested(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: requestKey)
    }

    /// Withdraws a pending request.
    static func cancel(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: requestKey)
    }

    // MARK: - The reset

    /// What a reset actually did, so the caller can log it rather than assume it.
    struct Outcome: Sendable, Equatable {
        /// File names removed.
        var removed: [String] = []
        /// File names that existed but could not be removed, with the reason.
        var failed: [String] = []
        /// `true` when every artifact that existed was removed.
        var isClean: Bool { failed.isEmpty }
    }

    /// Performs a requested reset, then clears the request.
    ///
    /// Call **before opening any store**. Returns `nil` when no reset was requested, so the normal
    /// launch path costs one `UserDefaults` read.
    ///
    /// The request is cleared whether or not every delete succeeded: a reset that partly failed
    /// must not silently retry on every subsequent launch. ``Outcome/failed`` carries what did not
    /// go, and the caller logs it.
    ///
    /// - Parameters:
    ///   - storeURLs: the stores to clear — pass ``ModelContainer/managedStoreURLs``.
    ///   - fileManager: injectable for tests.
    ///   - defaults: injectable for tests.
    @discardableResult
    static func performIfRequested(
        storeURLs: [URL],
        fileManager: FileManager = .default,
        defaults: UserDefaults = .standard
    ) -> Outcome? {
        guard isRequested(defaults: defaults) else { return nil }
        defer { cancel(defaults: defaults) }

        var outcome = Outcome()
        for storeURL in storeURLs {
            for path in artifactPaths(for: storeURL) {
                guard fileManager.fileExists(atPath: path.path) else { continue }
                do {
                    try fileManager.removeItem(at: path)
                    outcome.removed.append(path.lastPathComponent)
                } catch {
                    outcome.failed.append("\(path.lastPathComponent) (\(error.localizedDescription))")
                }
            }
        }
        return outcome
    }

    /// Every path belonging to one store: the store file, its two SQLite sidecars, and the two
    /// directories CloudKit mirroring keeps beside it.
    ///
    /// For `…/default.store` that is `default.store`, `default.store-wal`, `default.store-shm`,
    /// `default_ckAssets/`, and `.default_SUPPORT/`. The last two hold mirroring's asset spool and
    /// change-tracking state; a store deleted without them can come back up believing it has
    /// already caught up, and then never re-downloads — the failure mode this button exists to
    /// fix. They are derived from the store's own base name, not hardcoded, so a rename cannot
    /// leave them orphaned.
    static func artifactPaths(for storeURL: URL) -> [URL] {
        let directory = storeURL.deletingLastPathComponent()
        let fileName = storeURL.lastPathComponent
        let baseName = storeURL.deletingPathExtension().lastPathComponent
        var paths = storeFileSuffixes.map { directory.appending(path: fileName + $0) }
        paths.append(directory.appending(path: "\(baseName)_ckAssets"))
        paths.append(directory.appending(path: ".\(baseName)_SUPPORT"))
        return paths
    }
}
