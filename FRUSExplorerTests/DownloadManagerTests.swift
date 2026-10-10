// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
import CoreGraphics
import ImageIO
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

// MARK: - Figure images (#1516)

/// Fixtures the figure-image suites share: real PNG bytes, a figure store in a folder of the
/// test's own, and a volume whose figures cover what `FigureImageLibrary.graphicNames` must and
/// must not name.
enum FigureTestImages {

    /// A real PNG of one colour, `width` by `height` pixels.
    static func png(width: Int, height: Int,
                    red: CGFloat = 1, green: CGFloat = 0, blue: CGFloat = 0) throws -> Data {
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(red: red, green: green, blue: blue, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination), "the PNG was not written")
        return data as Data
    }

    /// Runs `body` with a figure library over a volumes directory of its own, removed afterwards.
    /// It runs on the caller's actor, so a main-actor suite's closure is not sent anywhere.
    static func withLibrary(isolation: isolated (any Actor)? = #isolation,
                            _ body: (FigureImageLibrary) async throws -> Void) async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSFigures-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try await body(FigureImageLibrary(volumesDirectory: directory))
    }

    /// Collects strings from concurrent closures, in arrival order.
    actor Counter {
        private(set) var values: [String] = []
        func add(_ value: String) { values.append(value) }
        func count(of value: String) -> Int { values.filter { $0 == value }.count }
    }

    /// A volume holding `frus1946v01` d587's three maps and, around them, everything the name scan
    /// must leave out: the title page's figure, a page's scan (the `<graphic>` in the
    /// `<facsimile>`'s `<surface>`, as `frus1946v01` carries one for each page, and its `<pb facs>`),
    /// a `<graphic>` outside any figure, a figure in a comment, an embedded video (which names no
    /// image), an empty figure, a figure naming nothing — and a second figure naming `figure_1162`
    /// again.
    static let volumeXML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <TEI xmlns="http://www.tei-c.org/ns/1.0" xmlns:frus="http://history.state.gov/frus/ns/1.0">
      <teiHeader><fileDesc><titleStmt><title>Test</title></titleStmt>
        <publicationStmt><p/></publicationStmt>
        <sourceDesc><p><graphic url="in_the_header"/></p></sourceDesc></fileDesc></teiHeader>
      <facsimile>
        <surface start="#pg_1">
          <graphic height="5424px" mimeType="image/tiff" url="https://static.history.state.gov/frus/frus1946v01/tiff/0011.tif" width="3367px"/>
          <graphic height="800px" mimeType="image/png" url="https://static.history.state.gov/frus/frus1946v01/medium/0011.png" width="497px"/>
        </surface>
      </facsimile>
      <text>
        <front>
          <titlePage><figure><graphic url="figure_0001"/></figure></titlePage>
        </front>
        <body>
          <pb facs="0011" n="1" xml:id="pg_1"/>
          \(FigureFixtures.d587)
          <!-- <figure><graphic url="commented_out"/></figure> -->
          <div type="document" subtype="historical-document" n="588" xml:id="d588">
            <p>The same map again: <figure><graphic url="figure_1162"/></figure></p>
            <p>An empty one <figure/> and one naming nothing <figure><graphic url=" "/></figure>.</p>
            <p>A graphic that is no figure's: <graphic url="loose_graphic"/></p>
          </div>
          \(FigureFixtures.appendix1)
        </body>
      </text>
    </TEI>
    """

    /// The names `volumeXML`'s figures give their images, in document order, each once.
    static let volumeNames = ["figure_1162", "figure_1163", "figure_1166", "Appendix A.1"]

    /// A transfer that answers as history.state.gov answers for two of these names — `figure_1162`
    /// a PNG, `figure_1163` HTTP 403 (it is one of the 13 the host does not serve) — fails
    /// `figure_1166`'s first request and then serves it, and answers `Appendix A.1` as a network's
    /// sign-in page would: HTTP 200 and no image. Every request's URL is recorded in `asked`.
    static func transfer(png: Data, asked: Counter) -> DownloadManager.FigureTransfer {
        return { request in
            let url = try #require(request.url)
            await asked.add(url.absoluteString)
            func response(_ status: Int) -> HTTPURLResponse {
                HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
            }
            switch url.lastPathComponent {
            case "figure_1162.png": return (png, response(200))
            case "figure_1163.png": return (Data("<Error><Code>AccessDenied</Code></Error>".utf8), response(403))
            case "figure_1166.png":
                if await asked.count(of: url.absoluteString) == 1 { throw URLError(.timedOut) }
                return (png, response(200))
            default: return (Data("<html><body>Sign in to this network</body></html>".utf8), response(200))
            }
        }
    }

    /// A manager over `library`'s directory whose volume transfers write `volumeXML`.
    static func manager(_ library: FigureImageLibrary, png: Data, asked: Counter) -> DownloadManager {
        DownloadManager(
            volumesDirectory: library.volumesDirectory,
            concurrencyLimit: 1,
            downloadTask: makeMockDownloadTask(content: volumeXML),
            onStateChanged: { _ in },
            figureTransfer: transfer(png: png, asked: asked))
    }

    /// Writes `volumeXML` as `volumeId`'s file in `library`'s directory.
    static func seedVolume(_ volumeId: String, in library: FigureImageLibrary) throws {
        try volumeXML.write(to: library.volumesDirectory.appendingPathComponent("\(volumeId).xml"),
                            atomically: true, encoding: .utf8)
    }

    /// Holds whoever waits at it until it is opened, so a test decides what happens while a
    /// transfer is in flight instead of racing a sleep.
    actor Gate {
        private var isOpen = false
        private var waiting: [CheckedContinuation<Void, Never>] = []

        /// Returns at once when the gate is open, and otherwise when it is opened.
        func wait() async {
            if isOpen { return }
            await withCheckedContinuation { waiting.append($0) }
        }

        /// Opens the gate, for everyone waiting and everyone who comes after.
        func open() {
            isOpen = true
            waiting.forEach { $0.resume() }
            waiting = []
        }
    }

    /// `volumeXML` as an update leaves it: `figure_1162` is still named, the other three names
    /// are gone, and `figure_2000` is new.
    static let updatedVolumeXML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <TEI xmlns="http://www.tei-c.org/ns/1.0">
      <text><body>
        <div type="document" n="587" xml:id="d587">
          <p><figure><graphic url="figure_1162"/></figure></p>
          <p><figure><graphic url="figure_2000"/></figure></p>
        </div>
      </body></text>
    </TEI>
    """

    /// A transfer that records each request's file name in `asked`, waits at `gate`, and then
    /// serves `png`.
    static func heldTransfer(png: Data, asked: Counter, gate: Gate) -> DownloadManager.FigureTransfer {
        return { request in
            let url = try #require(request.url)
            await asked.add(url.lastPathComponent)
            await gate.wait()
            return (png, HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!)
        }
    }

    /// Polls until `condition` holds, for at most twenty seconds. Returns whether it came to hold.
    ///
    /// Twenty, not three (#1516 review, round 1): what these polls wait for starts with a scan of
    /// the volume's XML in a detached utility-priority task, and in the first run of a newly built
    /// test host, with twelve suites running, a five-second wait of the same shape timed out once
    /// (`FigureReaderTests`). A wait that holds returns at once, so the budget costs nothing.
    static func eventually(_ condition: () async -> Bool) async -> Bool {
        for _ in 0..<1_000 {
            if await condition() { return true }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return await condition()
    }
}

/// #1516 (owner decision D3, option (f)4): a volume's figure images are fetched with it, kept
/// beside its XML, removed with it and counted in Volumes & Storage.
///
/// Every test drives `DownloadManager` itself over a temporary volumes directory, with an injected
/// transfer answering as history.state.gov does: nothing here reaches the network, and a manager
/// built the way every other test builds one fetches no image at all.
@Suite("A volume's figure images are fetched with it, kept beside it and removed with it (#1516)")
struct FigureImageDownloadTests {

    private static let host = "https://static.history.state.gov/frus"

    @Test("The names are the figures' graphics outside the title page, each once, and each is served as its name and .png")
    func namesAndAddresses() async throws {
        try await FigureTestImages.withLibrary { library in
            try FigureTestImages.seedVolume("frus1946v01", in: library)
            let url = library.volumesDirectory.appendingPathComponent("frus1946v01.xml")
            #expect(FigureImageLibrary.graphicNames(inVolumeAt: url) == FigureTestImages.volumeNames)
            // An unreadable volume names nothing, which is not the same as naming no images.
            #expect(FigureImageLibrary.graphicNames(
                inVolumeAt: library.volumesDirectory.appendingPathComponent("absent.xml")) == nil)
            try "<TEI><text><figure><graphic url=\"a\"/></text>".write(
                to: library.volumesDirectory.appendingPathComponent("broken.xml"), atomically: true, encoding: .utf8)
            #expect(FigureImageLibrary.graphicNames(
                inVolumeAt: library.volumesDirectory.appendingPathComponent("broken.xml")) == nil)
        }
        // Every url takes .png, whatever it ends in: measured, OpenPitMine.jpg is served under no other name.
        #expect(FigureImageName.fileName(forGraphic: "figure_1162") == "figure_1162.png")
        #expect(FigureImageName.fileName(forGraphic: "OpenPitMine.jpg") == "OpenPitMine.jpg.png")
        #expect(FigureImageLibrary.remoteURL(volumeId: "frus1946v01", fileName: "figure_1162.png")?.absoluteString
                == "\(Self.host)/frus1946v01/figure_1162.png")
        #expect(FigureImageLibrary.remoteURL(volumeId: "frus1917-72PubDip", fileName: "Document A.1.png")?.absoluteString
                == "\(Self.host)/frus1917-72PubDip/Document%20A.1.png")
        // A name that is not one path component names no file, here or on the device.
        for unsafe in ["", " ", ".", "..", "../frus1946v01", "a/b", "a\\b"] {
            #expect(FigureImageName.fileName(forGraphic: unsafe) == nil, "\(unsafe.debugDescription) became a file name")
        }
        #expect(FigureImageLibrary.remoteURL(volumeId: "..", fileName: "figure_1162.png") == nil)
        #expect(FigureImageLibrary.remoteURL(volumeId: "frus1946v01", fileName: "../x.png") == nil)
        let library = FigureImageLibrary(volumesDirectory: URL(fileURLWithPath: "/tmp/Volumes"))
        #expect(library.fileURL(volumeId: "frus1946v01", fileName: "figure_1162.png")?.path
                == "/tmp/Volumes/frus1946v01.figures/figure_1162.png")
        #expect(library.fileURL(volumeId: "frus1946v01", fileName: "../frus1946v01.xml") == nil)
        #expect(library.fileURL(for: FigureImageName(volumeId: nil, graphic: "figure_1162")) == nil)
    }

    @Test("A finished download fetches the volume's figure images into the folder beside its XML")
    func aDownloadFetchesItsFigures() async throws {
        try await FigureTestImages.withLibrary { library in
            let png = try FigureTestImages.png(width: 40, height: 30)
            let asked = FigureTestImages.Counter()
            let dm = FigureTestImages.manager(library, png: png, asked: asked)
            await dm.resumeQueuedDownloads()
            await dm.enqueueDownload(volumeId: "frus1946v01", downloadUrl: "https://example.com/frus1946v01.xml")

            let stored = library.volumesDirectory.appendingPathComponent("frus1946v01.figures/figure_1162.png")
            #expect(await FigureTestImages.eventually { FileManager.default.fileExists(atPath: stored.path) },
                    "the download did not fetch the volume's figure images")
            #expect(try Data(contentsOf: stored) == png)
            // The run asks for every name once before it ends.
            #expect(await FigureTestImages.eventually { await asked.values.count >= 4 })
            let requests = await asked.values
            #expect(Set(requests) == [
                "\(Self.host)/frus1946v01/figure_1162.png", "\(Self.host)/frus1946v01/figure_1163.png",
                "\(Self.host)/frus1946v01/figure_1166.png", "\(Self.host)/frus1946v01/Appendix%20A.1.png",
            ], "asked: \(requests)")
            // Neither the refused name nor the page that is no image is kept as a file. Two more
            // runs: the first may join the download's own, still under way, and whichever run
            // follows that one asks again for figure_1166, whose first transfer failed.
            // (A sign-in page answered as an image would be a file here: "Appendix A.1.png".)
            _ = await dm.fetchFigureImages(for: "frus1946v01")
            let outcome = await dm.fetchFigureImages(for: "frus1946v01")
            let files = try FileManager.default.contentsOfDirectory(
                atPath: library.directory(for: "frus1946v01").path).sorted()
            #expect(files == ["figure_1162.png", "figure_1166.png"], "\(files) after \(outcome)")
        }
    }

    @Test("A refused name is not asked for again this session; a failed transfer, and an answer that is no image, are")
    func refusedIsRememberedAndFailedIsRetried() async throws {
        try await FigureTestImages.withLibrary { library in
            let png = try FigureTestImages.png(width: 40, height: 30)
            let asked = FigureTestImages.Counter()
            let dm = FigureTestImages.manager(library, png: png, asked: asked)
            try FigureTestImages.seedVolume("frus1946v01", in: library)

            var expected = FigureFetchOutcome()
            expected.named = 4; expected.stored = 1; expected.refused = 1; expected.failed = 2
            #expect(await dm.fetchFigureImages(for: "frus1946v01") == expected)

            expected.present = 1; expected.stored = 1; expected.failed = 1
            #expect(await dm.fetchFigureImages(for: "frus1946v01") == expected)

            #expect(await asked.count(of: "\(Self.host)/frus1946v01/figure_1162.png") == 1)
            #expect(await asked.count(of: "\(Self.host)/frus1946v01/figure_1163.png") == 1,
                    "a name the host refused was asked for again")
            #expect(await asked.count(of: "\(Self.host)/frus1946v01/Appendix%20A.1.png") == 2,
                    "a name answered with a page that is no image must be asked for again: the page may be a network's")
            #expect(library.data(volumeId: "frus1946v01", fileName: "Appendix A.1.png") == nil,
                    "a page that is no image was kept as one")
            #expect(await asked.count(of: "\(Self.host)/frus1946v01/figure_1166.png") == 2,
                    "a transfer that failed must be tried again")
        }
    }

    @Test("Volumes & Storage counts a volume's figure images, and removing the volume removes them")
    func storageCountsThemAndRemovalRemovesThem() async throws {
        try await FigureTestImages.withLibrary { library in
            let png = try FigureTestImages.png(width: 40, height: 30)
            let dm = FigureTestImages.manager(library, png: png, asked: FigureTestImages.Counter())
            try FigureTestImages.seedVolume("frus1946v01", in: library)
            try "<TEI/>".write(to: library.volumesDirectory.appendingPathComponent("frus1861.xml"),
                               atomically: true, encoding: .utf8)
            _ = await dm.fetchFigureImages(for: "frus1946v01")
            _ = await dm.fetchFigureImages(for: "frus1946v01")

            let report = try await dm.storageReport()
            let entry = try #require(report.perVolume.first { $0.volumeId == "frus1946v01" })
            #expect(entry.figureBytes == png.count * 2)
            #expect(entry.volumeFileBytes == FigureTestImages.volumeXML.utf8.count)
            #expect(entry.totalBytes == entry.volumeFileBytes + png.count * 2)
            #expect(report.perVolume.first { $0.volumeId == "frus1861" }?.figureBytes == 0)
            // The figures folder is no volume, and its bytes are counted once.
            #expect(report.perVolume.map(\.volumeId) == ["frus1861", "frus1946v01"])
            #expect(report.totalVolumesBytes == FigureTestImages.volumeXML.utf8.count + 6, "the XML alone")
            #expect(report.totalFigureBytes == png.count * 2)
            #expect(report.grandTotalBytes == report.totalVolumesBytes + png.count * 2)

            try await dm.deleteVolume(volumeId: "frus1946v01")
            #expect(!FileManager.default.fileExists(atPath: library.directory(for: "frus1946v01").path),
                    "the volume's figure images outlived it")
            #expect(library.bytes(for: "frus1946v01") == 0)
        }
    }

    @Test("Removing a volume whose XML is already gone still removes its figure images")
    func removalWithoutTheXMLStillRemovesTheImages() async throws {
        try await FigureTestImages.withLibrary { library in
            let png = try FigureTestImages.png(width: 8, height: 8)
            let dm = FigureTestImages.manager(library, png: png, asked: FigureTestImages.Counter())
            #expect(library.store(png, volumeId: "frus1946v01", fileName: "figure_1162.png"))
            #expect(!dm.isVolumeDownloaded("frus1946v01"))
            try await dm.deleteVolume(volumeId: "frus1946v01")
            #expect(!FileManager.default.fileExists(atPath: library.directory(for: "frus1946v01").path))
        }
    }

    @Test("An updated volume drops the images its text no longer names and keeps the rest")
    func anUpdateDropsWhatTheTextNoLongerNames() async throws {
        try await FigureTestImages.withLibrary { library in
            let png = try FigureTestImages.png(width: 8, height: 8)
            let dm = FigureTestImages.manager(library, png: png, asked: FigureTestImages.Counter())
            try FigureTestImages.seedVolume("frus1946v01", in: library)
            #expect(library.store(png, volumeId: "frus1946v01", fileName: "figure_0999.png"))
            #expect(library.store(png, volumeId: "frus1946v01", fileName: "figure_1162.png"))
            let outcome = await dm.fetchFigureImages(for: "frus1946v01")
            #expect(outcome.present == 1, "\(outcome)")
            let files = try FileManager.default.contentsOfDirectory(
                atPath: library.directory(for: "frus1946v01").path).sorted()
            #expect(files == ["figure_1162.png"], "\(files)")
        }
    }

    @Test("Asking for one image of a volume downloaded before fetches it, and then the rest of the volume's")
    func oneImageOnDemandThenTheRest() async throws {
        try await FigureTestImages.withLibrary { library in
            let png = try FigureTestImages.png(width: 8, height: 8)
            let asked = FigureTestImages.Counter()
            let dm = FigureTestImages.manager(library, png: png, asked: asked)
            try FigureTestImages.seedVolume("frus1946v01", in: library)

            #expect(await dm.fetchFigureImage(volumeId: "frus1946v01", fileName: "figure_1162.png"))
            #expect(library.data(volumeId: "frus1946v01", fileName: "figure_1162.png") == png)
            // The rest of the volume follows without being asked for: figure_1166 fails once, so
            // the run that follows asks for it and the next one stores it.
            #expect(await FigureTestImages.eventually {
                await asked.count(of: "\(Self.host)/frus1946v01/figure_1166.png") >= 1
            }, "the rest of the volume's images were not fetched")
            // A refused name answers false, and one already on the device is not asked for again.
            #expect(await dm.fetchFigureImage(volumeId: "frus1946v01", fileName: "figure_1163.png") == false)
            #expect(await dm.fetchFigureImage(volumeId: "frus1946v01", fileName: "figure_1162.png"))
            #expect(await asked.count(of: "\(Self.host)/frus1946v01/figure_1162.png") == 1)
            // A volume that is not on the device has no images to fetch.
            #expect(await dm.fetchFigureImage(volumeId: "frus1861", fileName: "figure_1162.png") == false)
            #expect(await dm.fetchFigureImage(volumeId: "frus1946v01", fileName: "../frus1946v01.xml") == false)
        }
    }

    @Test("A volume removed while its images are being fetched keeps none of them")
    func aVolumeRemovedMidFetchKeepsNoImages() async throws {
        try await FigureTestImages.withLibrary { library in
            let png = try FigureTestImages.png(width: 8, height: 8)
            let asked = FigureTestImages.Counter()
            let gate = FigureTestImages.Gate()
            let dm = DownloadManager(
                volumesDirectory: library.volumesDirectory,
                downloadTask: makeMockDownloadTask(),
                onStateChanged: { _ in },
                figureTransfer: FigureTestImages.heldTransfer(png: png, asked: asked, gate: gate))
            try FigureTestImages.seedVolume("frus1946v01", in: library)
            let fetch = Task { await dm.fetchFigureImages(for: "frus1946v01") }
            // The first image is in flight, and held there, when the volume is removed.
            #expect(await FigureTestImages.eventually { await asked.values == ["figure_1162.png"] })
            try await dm.deleteVolume(volumeId: "frus1946v01")
            await gate.open()
            let outcome = await fetch.value
            #expect(!FileManager.default.fileExists(atPath: library.directory(for: "frus1946v01").path),
                    "an image written after its volume was removed was kept")
            // The image that landed is reported as not fetched, and nothing more was asked for.
            #expect(outcome.stored == 0 && outcome.failed == 4, "\(outcome)")
            #expect(await asked.values == ["figure_1162.png"])
        }
    }

    @Test("An update that lands while a volume's images are being fetched stops the old text's names and fetches the new text's")
    func anUpdateMidFetchReadsTheNewText() async throws {
        try await FigureTestImages.withLibrary { library in
            let png = try FigureTestImages.png(width: 8, height: 8)
            let asked = FigureTestImages.Counter()
            let gate = FigureTestImages.Gate()
            let dm = DownloadManager(
                volumesDirectory: library.volumesDirectory,
                concurrencyLimit: 1,
                downloadTask: makeMockDownloadTask(content: FigureTestImages.updatedVolumeXML),
                onStateChanged: { _ in },
                figureTransfer: FigureTestImages.heldTransfer(png: png, asked: asked, gate: gate))
            try FigureTestImages.seedVolume("frus1946v01", in: library)
            let first = Task { await dm.fetchFigureImages(for: "frus1946v01") }
            #expect(await FigureTestImages.eventually { await asked.values == ["figure_1162.png"] })

            // The update lands — its transfer is this manager's own — while figure_1162 is held.
            await dm.resumeQueuedDownloads()
            await dm.enqueueDownload(volumeId: "frus1946v01",
                                     downloadUrl: "https://example.com/frus1946v01.xml", force: true)
            let xml = library.volumesDirectory.appendingPathComponent("frus1946v01.xml")
            #expect(await FigureTestImages.eventually {
                let onDisk = try? String(contentsOf: xml, encoding: .utf8)
                let state = await dm.currentState
                return onDisk == FigureTestImages.updatedVolumeXML && state.activeVolumeIds.isEmpty
            }, "the update did not finish")

            await gate.open()
            _ = await first.value
            let added = library.directory(for: "frus1946v01").appendingPathComponent("figure_2000.png")
            #expect(await FigureTestImages.eventually { FileManager.default.fileExists(atPath: added.path) },
                    "the image only the new text names was not fetched")
            // The old text's other three names were never asked for, and figure_1162 once.
            #expect(await asked.values == ["figure_1162.png", "figure_2000.png"])
            let files = try FileManager.default.contentsOfDirectory(
                atPath: library.directory(for: "frus1946v01").path).sorted()
            #expect(files == ["figure_1162.png", "figure_2000.png"], "\(files)")
        }
    }

    /// An image is written through a temporary file in its volume's folder, under a name no text
    /// gives (`store`'s atomic write: `figure_1162.png.sb-…`, seen in the simulator on 2026-10-09).
    /// A run that prunes the folder while that file is there must leave it: removing it fails
    /// the write, and the image is reported as not fetched. That is how
    /// `anUpdateMidFetchReadsTheNewText` failed 2 runs in 12 until the prune was held to images:
    /// the held image's write, made off the manager, met the update's own run pruning the folder.
    @Test("A prune of the folder removes images the text no longer names, and nothing that is not an image")
    func aPruneLeavesWhatIsNotAnImage() async throws {
        try await FigureTestImages.withLibrary { library in
            let png = try FigureTestImages.png(width: 8, height: 8)
            #expect(library.store(png, volumeId: "frus1946v01", fileName: "figure_1162.png"))
            #expect(library.store(png, volumeId: "frus1946v01", fileName: "figure_1163.png"))
            let folder = library.directory(for: "frus1946v01")
            // The temporary file of a write in progress, as the system names one.
            try png.write(to: folder.appendingPathComponent("figure_2000.png.sb-b670e519-2iWkdT"))

            library.removeImages(notIn: ["figure_1162.png", "figure_2000.png"], for: "frus1946v01")
            #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
                    == ["figure_1162.png", "figure_2000.png.sb-b670e519-2iWkdT"])

            // A text that names nothing still takes the whole folder.
            library.removeImages(notIn: [], for: "frus1946v01")
            #expect(!FileManager.default.fileExists(atPath: folder.path))
        }
    }

    /// The race itself, run: one task stores an image again and again while another prunes the
    /// folder as an update's run does. Every store must succeed. Before the prune was held to
    /// images this lost stores whenever the prune listed the folder during a write.
    @Test("An image stored while its folder is being pruned is stored every time")
    func aStoreBesideAPruneIsNotLost() async throws {
        try await FigureTestImages.withLibrary { library in
            let png = try FigureTestImages.png(width: 256, height: 256)
            #expect(library.store(png, volumeId: "frus1946v01", fileName: "figure_2000.png"))
            let pruning = Task.detached {
                var passes = 0
                while !Task.isCancelled {
                    library.removeImages(notIn: ["figure_1162.png", "figure_2000.png"], for: "frus1946v01")
                    passes += 1
                }
                return passes
            }
            var lost = 0
            for _ in 0..<400 where !library.store(png, volumeId: "frus1946v01", fileName: "figure_1162.png") {
                lost += 1
            }
            pruning.cancel()
            let passes = await pruning.value
            // The prune has to have run beside the stores, or nothing was tried.
            #expect(passes > 50, "the prune ran \(passes) times beside 400 stores")
            #expect(lost == 0, "\(lost) of 400 stores were lost to the prune")
        }
    }

    @Test("A download that finished in an earlier process has its figure images fetched when its completion arrives")
    func anUntrackedCompletionFetchesTheFigures() async throws {
        try await FigureTestImages.withLibrary { library in
            let png = try FigureTestImages.png(width: 8, height: 8)
            let dm = FigureTestImages.manager(library, png: png, asked: FigureTestImages.Counter())
            try FigureTestImages.seedVolume("frus1946v01", in: library)
            // The router's branch for a transfer this instance never tracked.
            await dm.replayFinishedTransferForUITest(volumeId: "frus1946v01")
            let stored = library.directory(for: "frus1946v01").appendingPathComponent("figure_1162.png")
            #expect(await FigureTestImages.eventually { FileManager.default.fileExists(atPath: stored.path) },
                    "the completion of an untracked transfer fetched no figure image")
        }
    }

    @Test("A 404 is a refusal, remembered like a 403, and a 500 is a failure, asked for again")
    func statusesOtherThanTheHostsOwn() async throws {
        try await FigureTestImages.withLibrary { library in
            let png = try FigureTestImages.png(width: 8, height: 8)
            let asked = FigureTestImages.Counter()
            let dm = DownloadManager(
                volumesDirectory: library.volumesDirectory,
                downloadTask: makeMockDownloadTask(),
                onStateChanged: { _ in },
                figureTransfer: { request in
                    let url = try #require(request.url)
                    await asked.add(url.lastPathComponent)
                    func response(_ status: Int) -> HTTPURLResponse {
                        HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
                    }
                    switch url.lastPathComponent {
                    case "figure_1162.png": return (Data("Not Found".utf8), response(404))
                    // A server error whose body happens to be an image is still no image to keep.
                    case "figure_1163.png": return (png, response(500))
                    default: return (png, response(200))
                    }
                })
            try FigureTestImages.seedVolume("frus1946v01", in: library)

            var expected = FigureFetchOutcome()
            expected.named = 4; expected.stored = 2; expected.refused = 1; expected.failed = 1
            #expect(await dm.fetchFigureImages(for: "frus1946v01") == expected)
            expected.present = 2; expected.stored = 0
            #expect(await dm.fetchFigureImages(for: "frus1946v01") == expected)
            #expect(await asked.count(of: "figure_1162.png") == 1, "a 404 was asked for again")
            #expect(await asked.count(of: "figure_1163.png") == 2, "a 500 must be tried again")
            let files = try FileManager.default.contentsOfDirectory(
                atPath: library.directory(for: "frus1946v01").path).sorted()
            #expect(files == ["Appendix A.1.png", "figure_1166.png"], "\(files)")
        }
    }

    @Test("A figure image's request allows cellular access only while Allow Cellular Downloads is on")
    func figureRequestsFollowTheCellularSetting() async throws {
        // Whether each of a volume's four image requests allowed cellular access, under a settings
        // suite of the test's own holding `setting` — or nothing, when it is nil.
        func cellularAccess(with setting: Bool?) async throws -> [String] {
            // The suite is opened anew for each use: `UserDefaults` is not Sendable, and the one
            // handed to the manager is the manager's from then on.
            let suiteName = "FRUSFigures-\(UUID().uuidString)"
            defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }
            if let setting {
                try #require(UserDefaults(suiteName: suiteName)).set(setting, forKey: SettingsKeys.allowCellularDownloads)
            }
            let allowed = FigureTestImages.Counter()
            try await FigureTestImages.withLibrary { library in
                let png = try FigureTestImages.png(width: 8, height: 8)
                let preferences = try #require(UserDefaults(suiteName: suiteName))
                let dm = DownloadManager(
                    volumesDirectory: library.volumesDirectory,
                    downloadTask: makeMockDownloadTask(),
                    onStateChanged: { _ in },
                    figureTransfer: { request in
                        let url = try #require(request.url)
                        await allowed.add("\(request.allowsCellularAccess)")
                        return (png, HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!)
                    },
                    preferences: preferences)
                try FigureTestImages.seedVolume("frus1946v01", in: library)
                _ = await dm.fetchFigureImages(for: "frus1946v01")
            }
            return await allowed.values
        }
        #expect(try await cellularAccess(with: false) == ["false", "false", "false", "false"])
        #expect(try await cellularAccess(with: true) == ["true", "true", "true", "true"])
        // Never set, the setting is on — as it is for the volume's own download.
        #expect(try await cellularAccess(with: nil) == ["true", "true", "true", "true"])
    }

    @Test("A manager built with a test's volume transfer and no figure transfer fetches no image")
    func aTestManagerFetchesNothing() async throws {
        try await FigureTestImages.withLibrary { library in
            let dm = DownloadManager(volumesDirectory: library.volumesDirectory,
                                     downloadTask: makeMockDownloadTask(content: FigureTestImages.volumeXML),
                                     onStateChanged: { _ in })
            try FigureTestImages.seedVolume("frus1946v01", in: library)
            #expect(await dm.fetchFigureImages(for: "frus1946v01") == FigureFetchOutcome())
            #expect(await dm.fetchFigureImage(volumeId: "frus1946v01", fileName: "figure_1162.png") == false)
            #expect(!FileManager.default.fileExists(atPath: library.directory(for: "frus1946v01").path))
        }
    }

    @Test("The figure store serves what is on the device, fetches what is not, and without a library has nothing")
    func theStoreServesAndFetches() async throws {
        let image = FigureImageName(volumeId: "frus1946v01", graphic: "figure_1162")
        let unconfigured = FigureImageStore()
        #expect(unconfigured.data(for: image) == nil)
        #expect(await unconfigured.fetchIfAbsent(volumeId: "frus1946v01", fileName: "figure_1162.png") == false)

        try await FigureTestImages.withLibrary { library in
            let png = try FigureTestImages.png(width: 8, height: 8)
            let asked = FigureTestImages.Counter()
            let store = FigureImageStore(library: library) { volumeId, fileName in
                await asked.add("\(volumeId)/\(fileName)")
                return library.store(png, volumeId: volumeId, fileName: fileName)
            }
            #expect(store.data(for: image) == nil)
            // An export asks once per image, however many figures name it, and skips a name it cannot place.
            await store.fetchAbsent([image, image, FigureImageName(volumeId: nil, graphic: "figure_1163"),
                                     FigureImageName(volumeId: "frus1946v01", graphic: "../x")])
            #expect(await asked.values == ["frus1946v01/figure_1162.png"])
            #expect(store.data(for: image) == png)
            #expect(store.data(volumeId: "frus1946v01", fileName: "figure_1162.png") == png)
            // On the device: answered without a fetch.
            #expect(await store.fetchIfAbsent(volumeId: "frus1946v01", fileName: "figure_1162.png"))
            #expect(await asked.values.count == 1)
            // No way to fetch: an absent image stays absent.
            let offline = FigureImageStore(library: library)
            #expect(await offline.fetchIfAbsent(volumeId: "frus1946v01", fileName: "figure_1166.png") == false)
        }
    }

    @Test("An absent image is fetched only while online and only for a catalogue volume, and the app's store asks that first")
    func theAppFetchesOnlyOnlineAndOnlyCatalogueVolumes() throws {
        let catalogue: Set<String> = ["frus1946v01"]
        #expect(FigureImageStore.mayFetch(volumeId: "frus1946v01", isOnline: true, catalogueVolumeIds: catalogue))
        #expect(!FigureImageStore.mayFetch(volumeId: "frus1946v01", isOnline: false, catalogueVolumeIds: catalogue))
        // A side-loaded volume: on the device, and in no catalogue.
        #expect(!FigureImageStore.mayFetch(volumeId: "frus2001v99", isOnline: true, catalogueVolumeIds: catalogue))

        // The store the reader and the exports use is configured at boot with a fetch that asks.
        let source = try String(contentsOf: URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/App/FRUSExplorerApp.swift"), encoding: .utf8)
        #expect(source.components(separatedBy: "FigureImageStore.shared.configure(").count == 2,
                "the app must configure its figure store exactly once")
        let call = try #require(source.range(of: "FigureImageStore.shared.configure("))
        let fetch = try #require(WindowTargetingTests.balancedBlock(in: source, from: call.upperBound))
        #expect(fetch.contains("FigureImageStore.mayFetch("), "the boot-time fetch does not ask whether it may:\n\(fetch)")
        #expect(fetch.contains("isOnline: appState.isOnline"))
        #expect(fetch.contains("DownloadedVolumesListModel.redownloadableVolumeIds(in: appState.manifestStore)"))
        let refusal = try #require(fetch.range(of: "guard allowed else { return false }"))
        let transfer = try #require(fetch.range(of: "dm.fetchFigureImage(volumeId: volumeId, fileName: fileName)"))
        #expect(refusal.lowerBound < transfer.lowerBound, "the fetch is made before it is refused")
    }

    @Test("Reset Local Data's sweep removes every volume's figure images and nothing else")
    func resetSweepsEveryFiguresFolder() async throws {
        try await FigureTestImages.withLibrary { library in
            let png = try FigureTestImages.png(width: 8, height: 8)
            #expect(library.store(png, volumeId: "frus1946v01", fileName: "figure_1162.png"))
            #expect(library.store(png, volumeId: "frus1861", fileName: "figure1.png"))
            try FigureTestImages.seedVolume("frus1946v01", in: library)
            try "{}".write(to: library.volumesDirectory.appendingPathComponent("local.frusmeta.json"),
                           atomically: true, encoding: .utf8)
            library.removeAllImages()
            let left = try FileManager.default.contentsOfDirectory(atPath: library.volumesDirectory.path).sorted()
            #expect(left == ["frus1946v01.xml", "local.frusmeta.json"], "\(left)")
        }
        // `resetLocalData` deletes the XML files itself, not through `deleteVolume`, so it must call the sweep.
        let source = try String(contentsOf: URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/Settings/ResetService.swift"), encoding: .utf8)
        let start = try #require(source.range(of: "static func resetLocalData(appState: AppState) async {"))
        var depth = 0
        var body = ""
        for character in source[start.upperBound...] {
            if character == "{" { depth += 1 }
            if character == "}" {
                if depth == 0 { break }
                depth -= 1
            }
            body.append(character)
        }
        #expect(body.count > 500, "resetLocalData's body was not read")
        #expect(body.contains("dm.figureLibrary.removeAllImages()"),
                "Reset Local Data no longer removes the figure images beside the volumes it deletes")
    }

    @Test("A PNG's header gives its pixel size, and nothing else is a PNG")
    func pngHeader() throws {
        let png = try FigureTestImages.png(width: 120, height: 80)
        #expect(FigureImageLibrary.isPNG(png))
        let size = try #require(FigureImageLibrary.pngPixelSize(png))
        #expect(size.width == 120 && size.height == 80)
        #expect(!FigureImageLibrary.isPNG(Data("<html>".utf8)))
        #expect(FigureImageLibrary.pngPixelSize(Data("<html>".utf8)) == nil)
        #expect(FigureImageLibrary.pngPixelSize(png.prefix(12)) == nil, "a truncated header has no size")
    }

    // MARK: The pass over the volumes already on the device (#1516 review, round 1)

    /// A one-document volume whose figures name `graphics`.
    private static func volumeXML(naming graphics: [String]) -> String {
        let figures = graphics.map { "<p><figure><graphic url=\"\($0)\"/></figure></p>" }.joined()
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0"><text><body>
          <div type="document" n="1" xml:id="d1"><p>Text.</p>\(figures)</div>
        </body></text></TEI>
        """
    }

    /// Writes `xml` as `volumeId`'s file in `library`'s directory.
    private static func seed(_ volumeId: String, _ xml: String, in library: FigureImageLibrary) throws {
        try xml.write(to: library.volumesDirectory.appendingPathComponent("\(volumeId).xml"),
                      atomically: true, encoding: .utf8)
    }

    /// A manager whose every image request is recorded in `asked` as `volume/file` and answered by
    /// `serves`: `true` a PNG, `false` a transfer that fails as an offline one does.
    private static func passManager(_ library: FigureImageLibrary, png: Data, asked: FigureTestImages.Counter,
                                    serves: @escaping @Sendable (_ volumeId: String) -> Bool) -> DownloadManager {
        DownloadManager(
            volumesDirectory: library.volumesDirectory,
            downloadTask: makeMockDownloadTask(),
            onStateChanged: { _ in },
            figureTransfer: { request in
                let url = try #require(request.url)
                let volumeId = url.deletingLastPathComponent().lastPathComponent
                await asked.add("\(volumeId)/\(url.lastPathComponent)")
                guard serves(volumeId) else { throw URLError(.notConnectedToInternet) }
                return (png, HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!)
            })
    }

    /// The completion record on disk: which volumes are recorded as needing no further fetch.
    private static func recordedComplete(in library: FigureImageLibrary) throws -> [String] {
        let url = library.volumesDirectory.appendingPathComponent(".figure-images-complete.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try JSONDecoder().decode([String: String].self, from: Data(contentsOf: url)).keys.sorted()
    }

    @Test("The pass fetches the images of volumes already on the device, catalogue volumes only, and tries again what failed")
    func thePassBringsVolumesOnTheDeviceUpToTheirImages() async throws {
        try await FigureTestImages.withLibrary { library in
            let png = try FigureTestImages.png(width: 8, height: 8)
            let asked = FigureTestImages.Counter()
            let dm = FigureTestImages.manager(library, png: png, asked: asked)
            // Three volumes on the device, none of them downloaded by this manager: a catalogue
            // volume with figures, one with none, and a side-loaded one — on the device, in no
            // catalogue (#777) — that names a figure.
            try FigureTestImages.seedVolume("frus1946v01", in: library)
            try Self.seed("frus1861", Self.volumeXML(naming: []), in: library)
            try Self.seed("frus2001v99", Self.volumeXML(naming: ["side_loaded"]), in: library)
            let catalogue: Set<String> = ["frus1946v01", "frus1861", "frus1900"]

            // A suspended manager — the device is offline — reads nothing and asks for nothing.
            #expect(await dm.fetchMissingFigureImages(among: catalogue) == [])
            #expect(await asked.values.isEmpty)
            #expect(!FileManager.default.fileExists(atPath: library.directory(for: "frus1946v01").path))

            await dm.resumeQueuedDownloads()
            #expect(await dm.fetchMissingFigureImages(among: catalogue) == ["frus1861", "frus1946v01"])
            #expect(library.data(volumeId: "frus1946v01", fileName: "figure_1162.png") == png,
                    "a volume that was already on the device did not get its figure images")
            let firstPass = await asked.values
            #expect(firstPass.allSatisfy { !$0.contains("frus2001v99") },
                    "a side-loaded volume's image was asked for: \(firstPass)")
            #expect(!FileManager.default.fileExists(atPath: library.directory(for: "frus2001v99").path))
            // frus1861 names no image, so nothing is left to fetch for it; frus1946v01's
            // figure_1166 failed once and its Appendix A.1 was answered with a sign-in page.
            #expect(try Self.recordedComplete(in: library) == ["frus1861"])

            // The next launch's pass reads only the volume that still lacks something, and
            // fetches what failed.
            #expect(await dm.fetchMissingFigureImages(among: catalogue) == ["frus1946v01"])
            #expect(library.data(volumeId: "frus1946v01", fileName: "figure_1166.png") == png,
                    "a transfer that failed was not tried again by the next pass")
            #expect(await dm.fetchMissingFigureImages(among: catalogue) == ["frus1946v01"],
                    "a volume with an image still to fetch must be read again")
            #expect(await asked.count(of: "\(Self.host)/frus1946v01/figure_1162.png") == 1)
            #expect(await asked.count(of: "\(Self.host)/frus1946v01/figure_1163.png") == 1, "a refused name was asked for again")
            #expect(try Self.recordedComplete(in: library) == ["frus1861"])
        }
    }

    @Test("A volume with nothing left to fetch is not read again until its text changes, and removing it forgets the record")
    func aCompleteVolumeIsReadAgainOnlyWhenItsTextChanges() async throws {
        try await FigureTestImages.withLibrary { library in
            let png = try FigureTestImages.png(width: 8, height: 8)
            let asked = FigureTestImages.Counter()
            let dm = Self.passManager(library, png: png, asked: asked) { _ in true }
            await dm.resumeQueuedDownloads()
            try Self.seed("frus1946v01", Self.volumeXML(naming: ["figure_1162", "figure_1163"]), in: library)
            let catalogue: Set<String> = ["frus1946v01"]

            #expect(await dm.fetchMissingFigureImages(among: catalogue) == ["frus1946v01"])
            #expect(try Self.recordedComplete(in: library) == ["frus1946v01"])
            #expect(await dm.fetchMissingFigureImages(among: catalogue) == [], "a complete volume's XML was read again")
            #expect(await asked.values == ["frus1946v01/figure_1162.png", "frus1946v01/figure_1163.png"])

            // Its text is replaced by a writer the manager never hears from — a side-loaded copy
            // under the catalogue's id, say. The file is new, so the record no longer matches it.
            try Self.seed("frus1946v01", Self.volumeXML(naming: ["figure_1162", "figure_2000", "figure_2001"]), in: library)
            #expect(await dm.fetchMissingFigureImages(among: catalogue) == ["frus1946v01"],
                    "a volume whose text changed was not read again")
            let files = try FileManager.default.contentsOfDirectory(
                atPath: library.directory(for: "frus1946v01").path).sorted()
            #expect(files == ["figure_1162.png", "figure_2000.png", "figure_2001.png"], "\(files)")
            #expect(await asked.count(of: "frus1946v01/figure_1162.png") == 1)

            try await dm.deleteVolume(volumeId: "frus1946v01")
            #expect(try Self.recordedComplete(in: library) == [], "a removed volume is still recorded complete")
        }
    }

    @Test("The pass stops after three volumes in a row whose transfers all fail, and one that is served starts the count again")
    func thePassStopsWhenTheHostDoesNotAnswer() async throws {
        try await FigureTestImages.withLibrary { library in
            let png = try FigureTestImages.png(width: 8, height: 8)
            let asked = FigureTestImages.Counter()
            // Only these two volumes' images are served.
            let dm = Self.passManager(library, png: png, asked: asked) { ["frus1903", "frus1907"].contains($0) }
            await dm.resumeQueuedDownloads()
            // frus1901 names no image: it is neither a failure nor an answer.
            for year in 1900...1907 {
                try Self.seed("frus\(year)", Self.volumeXML(naming: year == 1901 ? [] : ["figure_1"]), in: library)
            }
            let catalogue = Set((1900...1907).map { "frus\($0)" })
            #expect(DownloadManager.figureBackfillPatience == 3)

            // 1900 and 1902 fail (two in a row, 1901 between them counting for nothing), 1903 is
            // served and starts the count again, 1904–1906 fail: three in a row, and the pass
            // stops before 1907, whose image the host would have served.
            #expect(await dm.fetchMissingFigureImages(among: catalogue)
                    == ["frus1900", "frus1901", "frus1902", "frus1903", "frus1904", "frus1905", "frus1906"])
            #expect(await asked.values == [
                "frus1900/figure_1.png", "frus1902/figure_1.png", "frus1903/figure_1.png",
                "frus1904/figure_1.png", "frus1905/figure_1.png", "frus1906/figure_1.png",
            ])
            #expect(library.data(volumeId: "frus1903", fileName: "figure_1.png") == png)
            #expect(try Self.recordedComplete(in: library) == ["frus1901", "frus1903"])

            // The next pass skips the two complete volumes and stops at its third failure.
            #expect(await dm.fetchMissingFigureImages(among: catalogue) == ["frus1900", "frus1902", "frus1904"])
            #expect(library.data(volumeId: "frus1907", fileName: "figure_1.png") == nil)
        }
    }

    @Test("Cancelling a download removes the volume's file and, with it, the images of the copy it was updating")
    func cancellingADownloadRemovesItsImages() async throws {
        try await FigureTestImages.withLibrary { library in
            let png = try FigureTestImages.png(width: 8, height: 8)
            let dm = FigureTestImages.manager(library, png: png, asked: FigureTestImages.Counter())
            try FigureTestImages.seedVolume("frus1946v01", in: library)
            #expect(library.store(png, volumeId: "frus1946v01", fileName: "figure_1162.png"))
            // An update of the volume is queued (the manager is suspended, so it does not start).
            await dm.enqueueDownload(volumeId: "frus1946v01",
                                     downloadUrl: "https://example.com/frus1946v01.xml", force: true)
            #expect(await dm.currentState.pendingVolumeIds == ["frus1946v01"])

            await dm.cancelDownload(volumeId: "frus1946v01")
            #expect(!dm.isVolumeDownloaded("frus1946v01"), "cancelDownload removes the file at the destination")
            #expect(!FileManager.default.fileExists(atPath: library.directory(for: "frus1946v01").path),
                    "the images of a volume whose file a cancel removed were left behind")
        }
    }

    @Test("The app starts the pass at launch and on reconnect, once downloads are resumed, and not in a unit test's host")
    func theAppStartsThePass() throws {
        #expect(FigureImageStore.isUnitTestHost(["XCTestConfigurationFilePath": "/tmp/x.xctestconfiguration"]))
        #expect(!FigureImageStore.isUnitTestHost(["HOME": "/var/mobile"]))
        #expect(!FigureImageStore.isUnitTestHost([:]))

        let source = try String(contentsOf: URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/App/FRUSExplorerApp.swift"), encoding: .utf8)
        // Twice: in `bootDownloadManager`, and where the device comes back online — each time
        // straight after the manager is resumed, inside the same online branch.
        let start = "Self.fetchMissingFigureImages(with: dm, appState: appState)"
        #expect(source.components(separatedBy: start).count == 3, "the pass must be started at launch and on reconnect")
        let resumed = "await dm.resumeQueuedDownloads()\n"
        var cursor = source.startIndex
        var resumes = 0
        var followed = 0
        while let resume = source.range(of: resumed, range: cursor..<source.endIndex) {
            cursor = resume.upperBound
            resumes += 1
            if source[cursor...].drop(while: { $0 == " " }).hasPrefix(start) { followed += 1 }
        }
        #expect(resumes == 2 && followed == 2,
                "each of the \(resumes) resumes of the download queue must be followed by the pass: \(followed) are")

        // What it starts: the manager's pass, over the catalogue's ids, and nothing in a test's host.
        let declaration = try #require(source.range(of: "static func fetchMissingFigureImages(with dm: DownloadManager, appState: AppState)"))
        let body = try #require(WindowTargetingTests.balancedBlock(in: source, from: declaration.upperBound))
        let refusal = try #require(body.range(
            of: "guard !FigureImageStore.isUnitTestHost(ProcessInfo.processInfo.environment) else { return }"))
        let pass = try #require(body.range(of: "await dm.fetchMissingFigureImages(among: catalogue)"))
        #expect(refusal.lowerBound < pass.lowerBound)
        #expect(body.contains("let catalogue = DownloadedVolumesListModel.redownloadableVolumeIds(in: appState.manifestStore)"))

        // The store the reader and the exports default to is left unconfigured in a test's host.
        let gate = try #require(source.range(of: "if !FigureImageStore.isUnitTestHost(ProcessInfo.processInfo.environment)"))
        let gated = try #require(WindowTargetingTests.balancedBlock(in: source, from: gate.upperBound))
        #expect(gated.contains("FigureImageStore.shared.configure(library: dm.figureLibrary)"),
                "the app's figure store is configured outside the unit-test gate")
    }
}

/// How Volumes & Storage shows a volume's figure images (#1516): in the row's size, and in what
/// Free Up Space says removing the volume recovers — once, not multiplied by the index factor.
@Suite("Volumes & Storage counts figure images in a volume's size and in what removing it frees (#1516)")
@MainActor
struct FigureStorageDisplayTests {

    @Test("A row's size is its XML and its figure images together")
    func theRowShowsTheWholeSize() {
        let model = DownloadedVolumesListModel()
        let entry = VolumeStorageEntry(volumeId: "frus1943CairoTehran", volumeFileBytes: 4_000_000,
                                       figureBytes: 25_443_143)
        model.report = StorageReport(totalVolumesBytes: entry.volumeFileBytes, totalIndexBytes: 0,
                                     totalSummariesBytes: 0, totalVectorBytes: 0,
                                     totalFigureBytes: entry.figureBytes, perVolume: [entry])
        let whole = ByteCountFormatter.string(fromByteCount: 29_443_143, countStyle: .file)
        let xmlAlone = ByteCountFormatter.string(fromByteCount: 4_000_000, countStyle: .file)
        #expect(whole != xmlAlone)
        #expect(model.statusLine(for: entry).contains(whole), "\(model.statusLine(for: entry))")
        #expect(model.heroContent(catalogCount: 553, interruptedCount: 0).value == whole)
    }

    @Test("The storage bar draws the figure images as a segment of their own, after the XML")
    func theBarHasAFiguresSegment() {
        let bar = StorageUsageBreakdown.make(volumeBytes: 600, indexBytes: 300, summaryBytes: 0,
                                             vectorBytes: 0, figureBytes: 100)
        #expect(bar.segments.map(\.id) == ["xml", "figures", "index"])
        #expect(bar.segments.map(\.label) == ["XML", "Figures", "Index"])
        #expect(bar.segments[1].bytes == 100 && bar.segments[1].share == 0.1)
        #expect(bar.totalBytes == 1_000)
        // A library with no figure images draws no such segment, as before.
        let without = StorageUsageBreakdown.make(volumeBytes: 600, indexBytes: 300, summaryBytes: 0)
        #expect(without.segments.map(\.id) == ["xml", "index"])
    }

    @Test("Free Up Space counts a volume's figure images once, beside its XML and the index the XML took")
    func recoveryCountsTheImagesOnce() {
        let entry = VolumeStorageEntry(volumeId: "frus1943CairoTehran", volumeFileBytes: 1_000_000,
                                       figureBytes: 500_000)
        let plan = StorageRemovalPlan.make(entries: [entry], protectedVolumeIds: [],
                                           redownloadableVolumeIds: ["frus1943CairoTehran"],
                                           lastOpenedByVolumeId: [:])
        let indexed = Int(Double(1_000_000) * StorageReport.indexOverheadFactor)
        #expect(plan.candidates.first?.estimatedBytes == 1_000_000 + indexed + 500_000)
        #expect(plan.estimatedRecovery(for: ["frus1943CairoTehran"]) == 1_000_000 + indexed + 500_000)
    }

    /// Both hubs are hand-maintained twins, and the model tests above cannot see either: a hub
    /// that built its bar without the figure bytes would draw no Figures segment under a hero
    /// total that counts them, and one whose inline rows read the XML alone would show a size the
    /// full list contradicts.
    @Test("Each storage hub hands the bar its figure bytes and sizes its inline rows by the whole volume",
          arguments: ["MacVolumesStorageHub.swift", "VolumesStorageHubView.swift"])
    func bothHubsCountTheImages(file: String) throws {
        let source = try String(contentsOf: URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/Settings/\(file)"), encoding: .utf8)
        // The bar: the one call that builds it from a report, with the report's figure bytes.
        // (The other call draws the empty bar a hub shows before its report is measured.)
        let fromAReport = "StorageUsageBreakdown.make(volumeBytes: report.totalVolumesBytes"
        #expect(source.components(separatedBy: fromAReport).count == 2, "\(file) builds its bar from a report once")
        let make = try #require(source.range(of: fromAReport))
        let arguments = try #require(WindowTargetingTests.balancedBlock(in: source, from: make.lowerBound, open: "(", close: ")"))
        #expect(arguments.contains("figureBytes: report.totalFigureBytes"),
                "\(file) draws its storage bar without the figure images: \(arguments)")
        // The inline rows: every byte count formatted from a per-volume entry is the whole volume's.
        let formatted = source.matches(of: /fromByteCount: Int64\(entry\.([A-Za-z]+)\)/).map { String($0.output.1) }
        #expect(formatted == ["totalBytes"], "\(file) sizes a volume's row by \(formatted)")
    }
}
