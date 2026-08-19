// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

// MARK: - Test Helpers

/// Creates a temporary directory scoped to the test, cleaned up after the test body returns.
private func withTempDirectory(_ body: (URL) async throws -> Void) async throws {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("FRUSTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    try await body(dir)
}

/// A mock download task that writes minimal XML to a temporary file and returns it.
/// Simulates a successful network response with an arbitrary short delay.
private func makeMockDownloadTask(
    delay: Duration = .milliseconds(10),
    content: String = "<volumes/>"
) -> DownloadManager.DownloadTask {
    return { request in
        try await Task.sleep(for: delay)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".xml")
        try content.write(to: tempURL, atomically: true, encoding: .utf8)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        return (tempURL, response)
    }
}

/// A mock download task that always fails with the given error.
private func makeFailing(_ error: Error = URLError(.timedOut)) -> DownloadManager.DownloadTask {
    return { _ in throw error }
}

/// Records the `URLRequest` passed to a mock download task so tests can assert on
/// per-request flags such as `allowsCellularAccess` (Session 154 cellular policy).
private actor RequestCapture {
    private(set) var lastRequest: URLRequest?
    func record(_ request: URLRequest) { lastRequest = request }
}

/// Like `makeMockDownloadTask`, but records the incoming request via `capture`
/// before returning a successful response.
private func makeCapturingDownloadTask(
    capture: RequestCapture,
    delay: Duration = .milliseconds(10)
) -> DownloadManager.DownloadTask {
    return { request in
        await capture.record(request)
        try await Task.sleep(for: delay)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".xml")
        try "<volumes/>".write(to: tempURL, atomically: true, encoding: .utf8)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        return (tempURL, response)
    }
}

/// A shared UserDefaults suite isolated per test to prevent cross-test contamination.
private func makeTestUserDefaults() -> UserDefaults {
    let suite = "frus.test.\(UUID().uuidString)"
    return UserDefaults(suiteName: suite)!
}

/// Removes any cached blob SHA for `volumeId` from the shared `UserDefaults`-backed
/// cache (`DownloadManager.blobSHA(for:)`), so update-detection tests that reuse a
/// volumeId across runs never read a stale value (Session 154).
private func clearBlobSHACache(for volumeId: String) {
    let key = "frus.downloadedVolumeBlobSHA"
    var cache = (UserDefaults.standard.dictionary(forKey: key) as? [String: String]) ?? [:]
    cache.removeValue(forKey: volumeId)
    UserDefaults.standard.set(cache, forKey: key)
}

// MARK: - Suite

/// Tests for `DownloadManager` covering queue management, concurrency, persistence,
/// storage reporting, and volume deletion.
struct DownloadManagerTests {

    // MARK: - Enqueue and Download

    @Test("Enqueuing a volume starts the download when enabled")
    func enqueueStartsDownloadWhenEnabled() async throws {
        try await withTempDirectory { dir in
            let dm = DownloadManager(
                volumesDirectory: dir,
                concurrencyLimit: 4,
                downloadTask: makeMockDownloadTask(),
                onStateChanged: { _ in }
            )
            await dm.resumeQueuedDownloads()
            await dm.enqueueDownload(volumeId: "frus1969-76v01", downloadUrl: "https://example.com/frus1969-76v01.xml")

            // Poll until the file appears (download is async).
            let dest = dm.volumeURL(for: "frus1969-76v01")
            var attempts = 0
            while !FileManager.default.fileExists(atPath: dest.path), attempts < 50 {
                try await Task.sleep(for: .milliseconds(20))
                attempts += 1
            }
            #expect(FileManager.default.fileExists(atPath: dest.path), "Volume XML should be on disk after download completes")
        }
    }

    @Test("Enqueuing an already-downloaded volume is a no-op")
    func enqueueAlreadyDownloadedIsNoOp() async throws {
        try await withTempDirectory { dir in
            // Pre-create the file.
            let existing = dir.appendingPathComponent("frus1969-76v01.xml")
            try "<volumes/>".write(to: existing, atomically: true, encoding: .utf8)

            actor CallCounter { var count = 0; func increment() { count += 1 } }
            let counter = CallCounter()
            let dm = DownloadManager(
                volumesDirectory: dir,
                concurrencyLimit: 4,
                downloadTask: { _ in
                    await counter.increment()
                    throw URLError(.cancelled)
                },
                onStateChanged: { _ in }
            )
            await dm.resumeQueuedDownloads()
            await dm.enqueueDownload(volumeId: "frus1969-76v01", downloadUrl: "https://example.com/frus1969-76v01.xml")
            try await Task.sleep(for: .milliseconds(30))
            #expect(await counter.count == 0, "Download task must not be called for an already-downloaded volume")
        }
    }

    @Test("isVolumeDownloaded returns true after download, false before")
    func isVolumeDownloadedReflectsFilePresence() async throws {
        try await withTempDirectory { dir in
            let dm = DownloadManager(
                volumesDirectory: dir,
                concurrencyLimit: 4,
                downloadTask: makeMockDownloadTask(),
                onStateChanged: { _ in }
            )
            #expect(dm.isVolumeDownloaded("frus1969-76v01") == false)
            await dm.resumeQueuedDownloads()
            await dm.enqueueDownload(volumeId: "frus1969-76v01", downloadUrl: "https://example.com/frus1969-76v01.xml")

            let dest = dm.volumeURL(for: "frus1969-76v01")
            var attempts = 0
            while !FileManager.default.fileExists(atPath: dest.path), attempts < 50 {
                try await Task.sleep(for: .milliseconds(20))
                attempts += 1
            }
            #expect(dm.isVolumeDownloaded("frus1969-76v01") == true)
        }
    }

    // MARK: - Offline Queue

    @Test("Enqueue while offline holds downloads in pending queue")
    func enqueueWhileOfflineHoldsInPending() async throws {
        try await withTempDirectory { dir in
            let dm = DownloadManager(
                volumesDirectory: dir,
                concurrencyLimit: 4,
                downloadTask: makeMockDownloadTask(),
                onStateChanged: { _ in }
            )
            // Not calling resumeQueuedDownloads → isEnabled remains false.
            await dm.enqueueDownload(volumeId: "frus1969-76v01", downloadUrl: "https://example.com/frus1969-76v01.xml")
            await dm.enqueueDownload(volumeId: "frus1977-80v01", downloadUrl: "https://example.com/frus1977-80v01.xml")

            try await Task.sleep(for: .milliseconds(50))

            let state = await dm.currentState
            #expect(state.activeVolumeIds.isEmpty, "No downloads should be active while offline")
            #expect(state.pendingVolumeIds.count == 2, "Both volumes should be in the pending queue")
        }
    }

    @Test("Resuming after offline starts the pending queue")
    func resumeAfterOfflineStartsQueue() async throws {
        try await withTempDirectory { dir in
            let dm = DownloadManager(
                volumesDirectory: dir,
                concurrencyLimit: 4,
                downloadTask: makeMockDownloadTask(delay: .milliseconds(20)),
                onStateChanged: { _ in }
            )
            await dm.enqueueDownload(volumeId: "frus1969-76v01", downloadUrl: "https://example.com/frus1969-76v01.xml")
            await dm.resumeQueuedDownloads()

            let dest = dm.volumeURL(for: "frus1969-76v01")
            var attempts = 0
            while !FileManager.default.fileExists(atPath: dest.path), attempts < 50 {
                try await Task.sleep(for: .milliseconds(20))
                attempts += 1
            }
            #expect(FileManager.default.fileExists(atPath: dest.path), "Download should start after resumeQueuedDownloads is called")
        }
    }

    // MARK: - Concurrency Limit

    @Test("No more than concurrencyLimit downloads run simultaneously")
    func concurrencyLimitEnforced() async throws {
        try await withTempDirectory { dir in
            let limit = 3
            let total = 9

            // Track peak concurrency using an actor to avoid data races.
            actor ConcurrencyCounter {
                var current = 0
                var peak = 0
                func enter() { current += 1; peak = max(peak, current) }
                func leave() { current -= 1 }
            }
            let counter = ConcurrencyCounter()

            let mockTask: DownloadManager.DownloadTask = { request in
                await counter.enter()
                defer { Task { await counter.leave() } }
                try await Task.sleep(for: .milliseconds(40))
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString + ".xml")
                try "<volumes/>".write(to: tempURL, atomically: true, encoding: .utf8)
                return (tempURL, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
            }

            let dm = DownloadManager(
                volumesDirectory: dir,
                concurrencyLimit: limit,
                downloadTask: mockTask,
                onStateChanged: { _ in }
            )
            await dm.resumeQueuedDownloads()

            for i in 0..<total {
                await dm.enqueueDownload(
                    volumeId: "frus-v\(String(format: "%02d", i))",
                    downloadUrl: "https://example.com/frus-v\(i).xml"
                )
            }

            // Wait for all downloads to complete.
            var done = false
            var attempts = 0
            while !done, attempts < 100 {
                try await Task.sleep(for: .milliseconds(50))
                let state = await dm.currentState
                done = state.activeVolumeIds.isEmpty && state.pendingVolumeIds.isEmpty
                attempts += 1
            }

            let peak = await counter.peak
            #expect(peak <= limit, "Peak concurrent downloads (\(peak)) must not exceed limit (\(limit))")
        }
    }

    // MARK: - Cancellation

    @Test("Cancelling a pending download removes it from the queue")
    func cancelPendingRemovesFromQueue() async throws {
        try await withTempDirectory { dir in
            let dm = DownloadManager(
                volumesDirectory: dir,
                concurrencyLimit: 4,
                downloadTask: makeMockDownloadTask(),
                onStateChanged: { _ in }
            )
            // Offline — stays pending.
            await dm.enqueueDownload(volumeId: "frus1969-76v01", downloadUrl: "https://example.com/frus1969-76v01.xml")
            await dm.cancelDownload(volumeId: "frus1969-76v01")

            let state = await dm.currentState
            #expect(!state.pendingVolumeIds.contains("frus1969-76v01"))
            #expect(!state.activeVolumeIds.contains("frus1969-76v01"))
        }
    }

    // MARK: - Deletion

    @Test("deleteVolume removes the XML file from disk")
    func deleteVolumeRemovesFile() async throws {
        try await withTempDirectory { dir in
            let dest = dir.appendingPathComponent("frus1969-76v01.xml")
            try "<volumes/>".write(to: dest, atomically: true, encoding: .utf8)

            let dm = DownloadManager(
                volumesDirectory: dir,
                concurrencyLimit: 4,
                downloadTask: makeMockDownloadTask(),
                onStateChanged: { _ in }
            )
            #expect(dm.isVolumeDownloaded("frus1969-76v01") == true)
            try await dm.deleteVolume(volumeId: "frus1969-76v01")
            #expect(dm.isVolumeDownloaded("frus1969-76v01") == false)
        }
    }

    @Test("deleteVolume posts frusVolumeDeleted notification")
    func deleteVolumePostsNotification() async throws {
        try await withTempDirectory { dir in
            let dest = dir.appendingPathComponent("frus1969-76v01.xml")
            try "<volumes/>".write(to: dest, atomically: true, encoding: .utf8)

            let dm = DownloadManager(
                volumesDirectory: dir,
                concurrencyLimit: 4,
                downloadTask: makeMockDownloadTask(),
                onStateChanged: { _ in }
            )

            actor ReceivedVolumeId { var value: String?; func set(_ v: String) { value = v } }
            let received = ReceivedVolumeId()
            let token = NotificationCenter.default.addObserver(
                forName: .frusVolumeDeleted, object: nil, queue: nil
            ) { note in
                if let id = note.userInfo?["volumeId"] as? String {
                    Task { await received.set(id) }
                }
            }
            defer { NotificationCenter.default.removeObserver(token) }

            try await dm.deleteVolume(volumeId: "frus1969-76v01")
            // Allow the Task inside the notification handler to complete.
            try await Task.sleep(for: .milliseconds(20))
            #expect(await received.value == "frus1969-76v01", "frusVolumeDeleted notification must carry the deleted volumeId")
        }
    }

    @Test("deleteVolume on a non-existent file is a no-op")
    func deleteNonExistentVolumeIsNoOp() async throws {
        try await withTempDirectory { dir in
            let dm = DownloadManager(
                volumesDirectory: dir,
                concurrencyLimit: 4,
                downloadTask: makeMockDownloadTask(),
                onStateChanged: { _ in }
            )
            // Should not throw.
            try await dm.deleteVolume(volumeId: "frus-does-not-exist")
        }
    }

    // MARK: - Storage Report

    @Test("storageReport sums downloaded file sizes correctly")
    func storageReportSumsFileSizes() async throws {
        try await withTempDirectory { dir in
            let content100 = String(repeating: "X", count: 100)
            let content200 = String(repeating: "Y", count: 200)
            try content100.write(to: dir.appendingPathComponent("frus1969-76v01.xml"), atomically: true, encoding: .utf8)
            try content200.write(to: dir.appendingPathComponent("frus1977-80v01.xml"), atomically: true, encoding: .utf8)

            let dm = DownloadManager(
                volumesDirectory: dir,
                concurrencyLimit: 4,
                downloadTask: makeMockDownloadTask(),
                onStateChanged: { _ in }
            )
            let report = try await dm.storageReport()
            #expect(report.perVolume.count == 2)
            #expect(report.totalVolumesBytes == report.perVolume.reduce(0) { $0 + $1.volumeFileBytes })
            #expect(report.totalVolumesBytes > 0, "Total should be non-zero with fixture files on disk")
            #expect(report.totalIndexBytes == 0, "Index bytes are 0 until Session 09 wires the index directory")
        }
    }

    @Test("storageReport returns empty report when no volumes are downloaded")
    func storageReportEmptyWhenNoVolumes() async throws {
        try await withTempDirectory { dir in
            let dm = DownloadManager(
                volumesDirectory: dir,
                concurrencyLimit: 4,
                downloadTask: makeMockDownloadTask(),
                onStateChanged: { _ in }
            )
            let report = try await dm.storageReport()
            #expect(report.perVolume.isEmpty)
            #expect(report.grandTotalBytes == 0)
        }
    }

    // MARK: - Backup Exclusion

    @Test("Downloaded volume XML is excluded from iCloud backup")
    func downloadedVolumeIsExcludedFromBackup() async throws {
        try await withTempDirectory { dir in
            let dm = DownloadManager(
                volumesDirectory: dir,
                concurrencyLimit: 4,
                downloadTask: makeMockDownloadTask(delay: .milliseconds(10)),
                onStateChanged: { _ in }
            )
            await dm.resumeQueuedDownloads()
            await dm.enqueueDownload(volumeId: "frus1969-76v01", downloadUrl: "https://example.com/frus1969-76v01.xml")

            let dest = dm.volumeURL(for: "frus1969-76v01")
            var attempts = 0
            while !FileManager.default.fileExists(atPath: dest.path), attempts < 50 {
                try await Task.sleep(for: .milliseconds(20))
                attempts += 1
            }
            let values = try dest.resourceValues(forKeys: [.isExcludedFromBackupKey])
            #expect(values.isExcludedFromBackup == true, "Volume XML must be excluded from iCloud backup")
        }
    }

    // MARK: - onStateChanged Callback

    @Test("onStateChanged is called when volumes are enqueued and when downloads complete")
    func onStateChangedFires() async throws {
        try await withTempDirectory { dir in
            actor CallLog { var calls: [DownloadManagerState] = []; func record(_ s: DownloadManagerState) { calls.append(s) } }
            let log = CallLog()

            let dm = DownloadManager(
                volumesDirectory: dir,
                concurrencyLimit: 4,
                downloadTask: makeMockDownloadTask(delay: .milliseconds(10)),
                onStateChanged: { @MainActor state in
                    Task { await log.record(state) }
                }
            )
            await dm.resumeQueuedDownloads()
            await dm.enqueueDownload(volumeId: "frus1969-76v01", downloadUrl: "https://example.com/frus1969-76v01.xml")

            // Wait for download to finish and callbacks to deliver.
            var attempts = 0
            while await log.calls.count < 2, attempts < 50 {
                try await Task.sleep(for: .milliseconds(20))
                attempts += 1
            }

            let calls = await log.calls
            #expect(calls.count >= 2, "onStateChanged must fire at least twice: once on enqueue, once on completion")
        }
    }

    // MARK: - Cellular Download Policy

    @Test("Downloads allow cellular access by default")
    func cellularAllowedByDefault() async throws {
        try await withTempDirectory { dir in
            UserDefaults.standard.removeObject(forKey: SettingsKeys.allowCellularDownloads)
            defer { UserDefaults.standard.removeObject(forKey: SettingsKeys.allowCellularDownloads) }

            let capture = RequestCapture()
            let dm = DownloadManager(
                volumesDirectory: dir,
                concurrencyLimit: 4,
                downloadTask: makeCapturingDownloadTask(capture: capture),
                onStateChanged: { _ in }
            )
            await dm.resumeQueuedDownloads()
            await dm.enqueueDownload(volumeId: "frus1969-76v01", downloadUrl: "https://example.com/frus1969-76v01.xml")

            var attempts = 0
            while await capture.lastRequest == nil, attempts < 50 {
                try await Task.sleep(for: .milliseconds(20))
                attempts += 1
            }

            let request = await capture.lastRequest
            #expect(request?.allowsCellularAccess == true, "Cellular downloads should be allowed when the preference is unset (default true)")
        }
    }

    @Test("Disabling cellular downloads is applied per-request")
    func cellularDownloadsCanBeDisabled() async throws {
        try await withTempDirectory { dir in
            UserDefaults.standard.set(false, forKey: SettingsKeys.allowCellularDownloads)
            defer { UserDefaults.standard.removeObject(forKey: SettingsKeys.allowCellularDownloads) }

            let capture = RequestCapture()
            let dm = DownloadManager(
                volumesDirectory: dir,
                concurrencyLimit: 4,
                downloadTask: makeCapturingDownloadTask(capture: capture),
                onStateChanged: { _ in }
            )
            await dm.resumeQueuedDownloads()
            await dm.enqueueDownload(volumeId: "frus1969-76v01", downloadUrl: "https://example.com/frus1969-76v01.xml")

            var attempts = 0
            while await capture.lastRequest == nil, attempts < 50 {
                try await Task.sleep(for: .milliseconds(20))
                attempts += 1
            }

            let request = await capture.lastRequest
            #expect(request?.allowsCellularAccess == false, "Disabling the preference must set allowsCellularAccess = false on the download request")
        }
    }

    // MARK: - Update Detection (Session 154)

    @Test("blobSHA computes the git blob SHA-1 of a downloaded volume's contents")
    func blobSHAMatchesGitBlobHash() async throws {
        try await withTempDirectory { dir in
            let volumeId = "frus1990-92v01"
            clearBlobSHACache(for: volumeId)
            defer { clearBlobSHACache(for: volumeId) }

            let content = "<volumes>blob sha fixture</volumes>"
            let dm = DownloadManager(
                volumesDirectory: dir,
                concurrencyLimit: 4,
                downloadTask: makeMockDownloadTask(content: content),
                onStateChanged: { _ in }
            )
            await dm.resumeQueuedDownloads()
            await dm.enqueueDownload(volumeId: volumeId, downloadUrl: "https://example.com/\(volumeId).xml")

            let dest = dm.volumeURL(for: volumeId)
            var attempts = 0
            while !FileManager.default.fileExists(atPath: dest.path), attempts < 50 {
                try await Task.sleep(for: .milliseconds(20))
                attempts += 1
            }

            let expected = DownloadManager.gitBlobSHA1(for: Data(content.utf8))
            #expect(await dm.blobSHA(for: volumeId) == expected)
        }
    }

    @Test("blobSHA and localVolumeInfo return nil for a volume that is not downloaded")
    func blobSHANilWhenNotDownloaded() async throws {
        try await withTempDirectory { dir in
            let dm = DownloadManager(
                volumesDirectory: dir,
                concurrencyLimit: 4,
                downloadTask: makeMockDownloadTask(),
                onStateChanged: { _ in }
            )
            #expect(await dm.blobSHA(for: "frus-does-not-exist") == nil)
            #expect(await dm.localVolumeInfo(for: "frus-does-not-exist") == nil)
        }
    }

    @Test("localVolumeInfo reports the on-disk size and git blob SHA-1")
    func localVolumeInfoReportsSizeAndSha() async throws {
        try await withTempDirectory { dir in
            let volumeId = "frus1990-92v02"
            clearBlobSHACache(for: volumeId)
            defer { clearBlobSHACache(for: volumeId) }

            let content = "<volumes>local volume info fixture</volumes>"
            let dm = DownloadManager(
                volumesDirectory: dir,
                concurrencyLimit: 4,
                downloadTask: makeMockDownloadTask(content: content),
                onStateChanged: { _ in }
            )
            await dm.resumeQueuedDownloads()
            await dm.enqueueDownload(volumeId: volumeId, downloadUrl: "https://example.com/\(volumeId).xml")

            let dest = dm.volumeURL(for: volumeId)
            var attempts = 0
            while !FileManager.default.fileExists(atPath: dest.path), attempts < 50 {
                try await Task.sleep(for: .milliseconds(20))
                attempts += 1
            }

            let info = await dm.localVolumeInfo(for: volumeId)
            #expect(info?.sizeBytes == content.utf8.count)
            #expect(info?.sha == DownloadManager.gitBlobSHA1(for: Data(content.utf8)))
        }
    }

    @Test("enqueueDownload(force:) re-downloads and overwrites an already-downloaded volume")
    func forceEnqueueOverwritesExistingVolume() async throws {
        try await withTempDirectory { dir in
            let volumeId = "frus1990-92v03"
            let dest = dir.appendingPathComponent("\(volumeId).xml")
            try "<old/>".write(to: dest, atomically: true, encoding: .utf8)

            let dm = DownloadManager(
                volumesDirectory: dir,
                concurrencyLimit: 4,
                downloadTask: makeMockDownloadTask(content: "<new/>"),
                onStateChanged: { _ in }
            )
            await dm.resumeQueuedDownloads()
            await dm.enqueueDownload(volumeId: volumeId, downloadUrl: "https://example.com/\(volumeId).xml", force: true)

            var attempts = 0
            while attempts < 50 {
                if let text = try? String(contentsOf: dest, encoding: .utf8), text == "<new/>" { break }
                try await Task.sleep(for: .milliseconds(20))
                attempts += 1
            }

            #expect(try String(contentsOf: dest, encoding: .utf8) == "<new/>")
        }
    }

    @Test("enqueueDownload without force is a no-op for an already-downloaded volume")
    func enqueueWithoutForceLeavesExistingVolumeUntouched() async throws {
        try await withTempDirectory { dir in
            let volumeId = "frus1990-92v04"
            let dest = dir.appendingPathComponent("\(volumeId).xml")
            try "<old/>".write(to: dest, atomically: true, encoding: .utf8)

            let dm = DownloadManager(
                volumesDirectory: dir,
                concurrencyLimit: 4,
                downloadTask: makeMockDownloadTask(content: "<new/>"),
                onStateChanged: { _ in }
            )
            await dm.resumeQueuedDownloads()
            await dm.enqueueDownload(volumeId: volumeId, downloadUrl: "https://example.com/\(volumeId).xml")
            try await Task.sleep(for: .milliseconds(30))

            #expect(try String(contentsOf: dest, encoding: .utf8) == "<old/>")
        }
    }

    // MARK: - #926 items 2 and 3

    /// The index walk must not count the volumes or vectors directories — they are its
    /// CHILDREN on disk, and counting them is how the hero figure double-counted volume
    /// XML for as long as the walk existed.
    @Test("directorySize excludes named subdirectories, descendants included")
    func directorySizeExcludesSubdirectories() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("walk-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let volumes = dir.appendingPathComponent("Volumes", isDirectory: true)
        let vectors = dir.appendingPathComponent("SemanticVectors", isDirectory: true)
        let nested = vectors.appendingPathComponent("nested", isDirectory: true)
        for d in [volumes, nested] {
            try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        }
        try Data(count: 1_000).write(to: dir.appendingPathComponent("index.sqlite"))
        try Data(count: 700).write(to: volumes.appendingPathComponent("frus1900.xml"))
        try Data(count: 300).write(to: vectors.appendingPathComponent("frus1900.vec"))
        try Data(count: 200).write(to: nested.appendingPathComponent("deep.vec"))

        #expect(DownloadManager.directorySize(at: dir) == 2_200, "unexcluded walk sums all")
        #expect(DownloadManager.directorySize(
            at: dir, excludingSubdirectories: [volumes, vectors]) == 1_000, """
            The exclusion must remove the child directories AND their descendants from \
            the index figure — this is #926 item 2, the hero double-count.
            """)
        #expect(DownloadManager.directorySize(at: vectors) == 500,
                "the vectors figure counts the excluded tree once, on its own")
    }

    /// #926 item 3: the missing-XML guard used to return before the teardown callback,
    /// so any path that removed the file first left the volume's semantic shard and
    /// index rows behind. Teardown must not depend on which artifact vanished first.
    @Test("deleteVolume fires teardown even when the XML is already gone")
    func deleteVolumeFiresTeardownWithoutXML() async throws {
        try await withTempDirectory { dir in
            actor Seen { var ids: [String] = []; func add(_ v: String) { ids.append(v) } }
            let seen = Seen()
            let dm = DownloadManager(
                volumesDirectory: dir,
                concurrencyLimit: 1,
                downloadTask: makeMockDownloadTask(),
                onStateChanged: { _ in },
                onVolumeDeleted: { id in await seen.add(id) }
            )
            #expect(dm.isVolumeDownloaded("frus1969-76v01") == false)
            try await dm.deleteVolume(volumeId: "frus1969-76v01")
            // The callback runs in an unstructured Task; give it a beat.
            try await Task.sleep(nanoseconds: 200_000_000)
            #expect(await seen.ids == ["frus1969-76v01"], """
                deleteVolume with no XML on disk skipped the teardown callback — the \
                shard and index rows for the volume outlive the volume (#926 item 3).
                """)
        }
    }
}
