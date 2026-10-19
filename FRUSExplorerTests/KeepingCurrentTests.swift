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

// MARK: - Fixtures

/// A folder of the test's own, removed when the body returns. It runs on the caller's actor, so a
/// main-actor suite's closure is not sent anywhere (as `FigureTestImages.withLibrary` does).
private func withScratchVolumes(isolation: isolated (any Actor)? = #isolation,
                                _ body: (URL) async throws -> Void) async throws {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("KeepingCurrent-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    try await body(dir)
}

/// A defaults suite of the test's own, so no test reads another's hash cache or side-load record.
private func scratchDefaults() -> UserDefaults {
    UserDefaults(suiteName: "frus.test.keepingCurrent.\(UUID().uuidString)")!
}

/// A catalogue entry for `volumeId`.
private func catalogueEntry(_ volumeId: String, provenance: VolumeOrigin = .publishedCatalogue) -> VolumeManifestEntry {
    var entry = VolumeManifestEntry(
        volumeId: volumeId,
        filename: "\(volumeId).xml",
        subseries: "1900",
        title: "Papers Relating to the Foreign Relations of the United States, \(volumeId)",
        dateRange: DateRange(earliest: nil, latest: nil),
        publicationDate: nil,
        status: .published,
        editors: [],
        generalEditor: nil,
        sizeBytes: 100,
        tags: []
    )
    entry.provenance = provenance
    return entry
}

/// A transfer that answers `content` after `delay`, failing first with `URLError(.timedOut)` for
/// as many attempts as `failures` says, and counting every attempt.
private actor ScriptedTransfer {
    private(set) var attempts = 0
    private let failures: Int
    private let content: String
    private let delay: Duration

    init(failures: Int = 0, content: String = "<new/>", delay: Duration = .milliseconds(10)) {
        self.failures = failures
        self.content = content
        self.delay = delay
    }

    private func nextAttempt() -> Int {
        attempts += 1
        return attempts
    }

    nonisolated var task: DownloadManager.DownloadTask {
        { request in
            let attempt = await self.nextAttempt()
            try await Task.sleep(for: self.delay)
            if attempt <= self.failures { throw URLError(.timedOut) }
            let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".xml")
            try self.content.write(to: file, atomically: true, encoding: .utf8)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
            return (file, response)
        }
    }
}

/// What `onTransferFinished` reported, in order.
@MainActor
private final class TransferReports {
    private(set) var reports: [(volumeId: String, outcome: DownloadTransferOutcome)] = []
    func record(_ volumeId: String, _ outcome: DownloadTransferOutcome) { reports.append((volumeId, outcome)) }
}

/// Polls `condition` on the main actor until it holds or `timeout` passes.
@MainActor
private func eventually(timeout: Duration = .seconds(10), _ condition: @MainActor () -> Bool) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while clock.now < deadline {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return condition()
}

/// A manager whose reports reach `model` as the app's do, with retries a few milliseconds apart.
@MainActor
private func managerFeeding(_ model: KeepingCurrentModel, in dir: URL, transfer: @escaping DownloadManager.DownloadTask,
                            defaults: UserDefaults) -> DownloadManager {
    DownloadManager(
        volumesDirectory: dir,
        concurrencyLimit: 4,
        downloadTask: transfer,
        onStateChanged: { @MainActor state in model.downloadStateDidChange(state) },
        preferences: defaults,
        onTransferFinished: { @MainActor volumeId, outcome in model.transferDidFinish(volumeId, outcome: outcome) },
        retryBackoff: .milliseconds(10)
    )
}

// MARK: - The download manager's part (#1660)

/// What the download manager now says and does for Keeping Current (#1660, the owner's answers of
/// 2026-10-16): what it did with a request, how each transfer ended, an update's retries, a
/// cancel that keeps the old copy, hashes tied to their file, and the side-load record.
@Suite("Keeping Current: the download manager's outcomes, retries, hashes and side-load record (#1660)")
@MainActor
struct KeepingCurrentDownloadTests {

    @Test("A request says what was done with it: queued, already queued, already on disk, or no address")
    func enqueueSaysWhatItDid() async throws {
        try await withScratchVolumes { dir in
            // Suspended (never resumed), so a queued request stays pending.
            let dm = DownloadManager(volumesDirectory: dir, downloadTask: ScriptedTransfer().task,
                                     onStateChanged: { _ in }, preferences: scratchDefaults())
            #expect(await dm.enqueueDownload(catalogueEntry("frus1900")) == .queued)
            #expect(await dm.enqueueDownload(catalogueEntry("frus1900"), force: true) == .alreadyQueued,
                    "a forced request for a volume already waiting was not reported as already queued")

            try "<old/>".write(to: dm.volumeURL(for: "frus1901"), atomically: true, encoding: .utf8)
            #expect(await dm.enqueueDownload(catalogueEntry("frus1901")) == .alreadyDownloaded)
            #expect(await dm.enqueueDownload(catalogueEntry("frus1901"), force: true) == .queued)

            #expect(await dm.enqueueDownload(catalogueEntry("frus1902", provenance: .sideloaded), force: true)
                    == .noCatalogueURL)
            #expect(await dm.currentState.pendingVolumeIds == ["frus1900", "frus1901"])
        }
    }

    /// Before #1660, `retryDownload` declined any volume on disk, and an update's old copy always
    /// is: the transfer was tried once, failed, and nothing said so.
    @Test("An update whose download fails is retried as a first download is, and its end is reported once")
    func anUpdateIsRetried() async throws {
        try await withScratchVolumes { dir in
            let reports = TransferReports()
            let transfer = ScriptedTransfer(failures: 2)
            let dm = DownloadManager(volumesDirectory: dir, downloadTask: transfer.task,
                                     onStateChanged: { _ in }, preferences: scratchDefaults(),
                                     onTransferFinished: { @MainActor id, outcome in reports.record(id, outcome) },
                                     retryBackoff: .milliseconds(10))
            try "<old/>".write(to: dm.volumeURL(for: "frus1900"), atomically: true, encoding: .utf8)
            await dm.resumeQueuedDownloads()
            #expect(await dm.enqueueDownload(catalogueEntry("frus1900"), force: true) == .queued)

            #expect(await eventually { reports.reports.count == 1 })
            #expect(reports.reports.first?.outcome == .succeeded)
            #expect(await transfer.attempts == 3, "the update was not tried again after its first two failures")
            #expect(try String(contentsOf: dm.volumeURL(for: "frus1900"), encoding: .utf8) == "<new/>")
            try await Task.sleep(for: .milliseconds(100))
            #expect(reports.reports.count == 1, "a transfer's end was reported more than once")
        }
    }

    @Test("An update whose download keeps failing is reported failed once its retries are spent, and the old copy stays")
    func aFailingUpdateIsReportedFailed() async throws {
        try await withScratchVolumes { dir in
            let reports = TransferReports()
            let transfer = ScriptedTransfer(failures: .max)
            let dm = DownloadManager(volumesDirectory: dir, downloadTask: transfer.task,
                                     onStateChanged: { _ in }, preferences: scratchDefaults(),
                                     onTransferFinished: { @MainActor id, outcome in reports.record(id, outcome) },
                                     retryBackoff: .milliseconds(10))
            try "<old/>".write(to: dm.volumeURL(for: "frus1900"), atomically: true, encoding: .utf8)
            await dm.resumeQueuedDownloads()
            await dm.enqueueDownload(catalogueEntry("frus1900"), force: true)

            #expect(await eventually { reports.reports.count == 1 })
            guard case .failed(let failure)? = reports.reports.first?.outcome else {
                Issue.record("expected a failure, got \(String(describing: reports.reports.first?.outcome))")
                return
            }
            #expect(failure.urlErrorCode == .timedOut)
            #expect(await transfer.attempts == 1 + DownloadManager.maxRetryCount)
            #expect(try String(contentsOf: dm.volumeURL(for: "frus1900"), encoding: .utf8) == "<old/>")
        }
    }

    @Test("Cancelling an update is reported, and keeps the old copy")
    func aCancelIsReported() async throws {
        try await withScratchVolumes { dir in
            let reports = TransferReports()
            let dm = DownloadManager(volumesDirectory: dir, downloadTask: ScriptedTransfer().task,
                                     onStateChanged: { _ in }, preferences: scratchDefaults(),
                                     onTransferFinished: { @MainActor id, outcome in reports.record(id, outcome) })
            try "<old/>".write(to: dm.volumeURL(for: "frus1900"), atomically: true, encoding: .utf8)
            await dm.enqueueDownload(catalogueEntry("frus1900"), force: true)
            await dm.cancelDownload(volumeId: "frus1900")
            // Cancelling what is not queued says nothing.
            await dm.cancelDownload(volumeId: "frus1901")

            #expect(await eventually { reports.reports.count == 1 })
            #expect(reports.reports.first?.volumeId == "frus1900")
            #expect(reports.reports.first?.outcome == .cancelled)
            #expect(try String(contentsOf: dm.volumeURL(for: "frus1900"), encoding: .utf8) == "<old/>")
        }
    }

    /// The owner's answer of 2026-10-16: a hash is kept with its file's size and modification
    /// date. The file is replaced here directly, as a path that never invalidated the cache did,
    /// and with the same size, so only the date tells the copies apart.
    @Test("A cached hash is taken again when its file is replaced by any path, and the unstamped cache is not trusted")
    func aHashFollowsItsFile() async throws {
        try await withScratchVolumes { dir in
            let defaults = scratchDefaults()
            defaults.set(["frus1900": "stale-hash-from-before-1660"], forKey: "frus.downloadedVolumeBlobSHA")
            let dm = DownloadManager(volumesDirectory: dir, downloadTask: ScriptedTransfer().task,
                                     onStateChanged: { _ in }, preferences: defaults)
            let url = dm.volumeURL(for: "frus1900")
            try "<a/>".write(to: url, atomically: true, encoding: .utf8)

            #expect(await dm.blobSHA(for: "frus1900") == DownloadManager.gitBlobSHA1(for: Data("<a/>".utf8)),
                    "the unstamped cache's entry was trusted")
            #expect(defaults.object(forKey: "frus.downloadedVolumeBlobSHA") == nil,
                    "the unstamped cache was left behind")
            // Asked again, the stamped entry answers.
            #expect(await dm.blobSHA(for: "frus1900") == DownloadManager.gitBlobSHA1(for: Data("<a/>".utf8)))

            try "<b/>".write(to: url, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(60)],
                                                  ofItemAtPath: url.path)
            #expect(await dm.blobSHA(for: "frus1900") == DownloadManager.gitBlobSHA1(for: Data("<b/>".utf8)),
                    "the replaced file was given the hash of the copy it replaced")
        }
    }

    @Test("A side-loaded volume is recorded until a download of it, or its removal, ends the record")
    func theSideloadRecord() async throws {
        try await withScratchVolumes { dir in
            let reports = TransferReports()
            let dm = DownloadManager(volumesDirectory: dir, downloadTask: ScriptedTransfer().task,
                                     onStateChanged: { _ in }, preferences: scratchDefaults(),
                                     onTransferFinished: { @MainActor id, outcome in reports.record(id, outcome) })
            try "<mine/>".write(to: dm.volumeURL(for: "frus1900"), atomically: true, encoding: .utf8)
            #expect(await dm.isSideloaded("frus1900") == false)
            await dm.markSideloaded("frus1900")
            #expect(await dm.isSideloaded("frus1900"))

            await dm.resumeQueuedDownloads()
            await dm.enqueueDownload(catalogueEntry("frus1900"), force: true)
            #expect(await eventually { reports.reports.count == 1 })
            #expect(await dm.isSideloaded("frus1900") == false, "the published copy is still marked as the reader's")

            await dm.markSideloaded("frus1900")
            try await dm.deleteVolume(volumeId: "frus1900")
            #expect(await dm.isSideloaded("frus1900") == false, "a removed volume is still marked side-loaded")
        }
    }

    #if DEBUG
    @Test("A transfer that finished in an earlier process is reported as succeeded and ends the side-load record")
    func anUntrackedFinishIsReported() async throws {
        try await withScratchVolumes { dir in
            let reports = TransferReports()
            let dm = DownloadManager(volumesDirectory: dir, downloadTask: ScriptedTransfer().task,
                                     onStateChanged: { _ in }, preferences: scratchDefaults(),
                                     onTransferFinished: { @MainActor id, outcome in reports.record(id, outcome) })
            try "<new/>".write(to: dm.volumeURL(for: "frus1900"), atomically: true, encoding: .utf8)
            await dm.markSideloaded("frus1900")
            await dm.replayFinishedTransferForUITest(volumeId: "frus1900")

            #expect(await eventually { reports.reports.count == 1 })
            #expect(reports.reports.first?.outcome == .succeeded)
            #expect(await dm.isSideloaded("frus1900") == false)
        }
    }
    #endif

    @Test("The check carries the side-load record onto the volume it lists")
    func theCheckCarriesTheSideloadRecord() async throws {
        try await withScratchVolumes { dir in
            let dm = DownloadManager(volumesDirectory: dir, downloadTask: ScriptedTransfer().task,
                                     onStateChanged: { _ in }, preferences: scratchDefaults())
            for id in ["frus1900", "frus1901"] {
                try "<mine/>".write(to: dm.volumeURL(for: id), atomically: true, encoding: .utf8)
            }
            await dm.markSideloaded("frus1901")
            let live = LiveVolumeInfo(sha: "0000000000000000000000000000000000000000", sizeBytes: 7)
            let found = await VolumeUpdateChecker.updatableVolumes(
                known: [catalogueEntry("frus1900"), catalogueEntry("frus1901")],
                liveInfoByVolumeId: ["frus1900": live, "frus1901": live],
                downloadManager: dm)
            #expect(found.map(\.id) == ["frus1900", "frus1901"])
            #expect(found.map(\.isSideloaded) == [false, true])
        }
    }
}

// MARK: - The model (#1660)

/// Keeping Current's rows: where each listed volume's update stands, and what the section shows.
@Suite("Keeping Current: each listed volume's row and where its update stands (#1660)")
@MainActor
struct KeepingCurrentModelTests {

    private static func listed(_ ids: [String], sideloaded: Set<String> = []) -> [UpdatableVolume] {
        ids.map { UpdatableVolume(entry: catalogueEntry($0), isSideloaded: sideloaded.contains($0)) }
    }

    private static func status(_ model: KeepingCurrentModel, _ volumeId: String) -> KeepingCurrentModel.Status? {
        model.rows.first { $0.id == volumeId }?.status
    }

    @Test("A check lists what differs, offers Update, and lists a volume already in the queue as already downloading")
    func aCheckLists() {
        let model = KeepingCurrentModel()
        model.downloadStateDidChange(DownloadManagerState(activeVolumeIds: [], pendingVolumeIds: ["frus1901"]))
        model.listed(Self.listed(["frus1900", "frus1901"], sideloaded: ["frus1900"]))
        #expect(model.hasChecked)
        #expect(model.rows.map(\.status) == [.available, .alreadyDownloading])
        #expect(model.rows.map(\.isSideloaded) == [true, false])
        #expect(model.offersUpdateAll)
    }

    /// The owner's answer of 2026-10-16: the row stays and shows its update's progress. Before
    /// #1660 the hub removed it the moment Update was pressed.
    @Test("Update keeps the row, which follows its download and its re-index to Updated")
    func anUpdateIsFollowed() async throws {
        try await withScratchVolumes { dir in
            let model = KeepingCurrentModel()
            let dm = managerFeeding(model, in: dir, transfer: ScriptedTransfer(delay: .milliseconds(50)).task,
                                    defaults: scratchDefaults())
            try "<old/>".write(to: dm.volumeURL(for: "frus1900"), atomically: true, encoding: .utf8)
            await dm.resumeQueuedDownloads()
            model.listed(Self.listed(["frus1900"]))

            await model.update("frus1900", downloads: dm)
            #expect(model.rows.count == 1, "the row was removed when Update was pressed")
            #expect(Self.status(model, "frus1900") != .available)
            #expect(model.offersUpdateAll == false, "Update All still offered a volume whose update is under way")

            #expect(await eventually { Self.status(model, "frus1900") == .indexing })
            #expect(try String(contentsOf: dm.volumeURL(for: "frus1900"), encoding: .utf8) == "<new/>")
            model.indexingDidFinish("frus1900", failure: nil)
            #expect(Self.status(model, "frus1900") == .updated)
        }
    }

    @Test("A row never moves backward, whatever order the reports arrive in")
    func reportsOutOfOrder() async throws {
        try await withScratchVolumes { dir in
            let model = KeepingCurrentModel()
            // Suspended, so the request stays queued until the reports below move it.
            let dm = DownloadManager(volumesDirectory: dir, downloadTask: ScriptedTransfer().task,
                                     onStateChanged: { _ in }, preferences: scratchDefaults())
            try "<old/>".write(to: dm.volumeURL(for: "frus1900"), atomically: true, encoding: .utf8)
            model.listed(Self.listed(["frus1900"]))
            await model.update("frus1900", downloads: dm)
            #expect(Self.status(model, "frus1900") == .queued)

            model.downloadStateDidChange(DownloadManagerState(activeVolumeIds: ["frus1900"], pendingVolumeIds: []))
            #expect(Self.status(model, "frus1900") == .downloading)
            model.transferDidFinish("frus1900", outcome: .succeeded)
            #expect(Self.status(model, "frus1900") == .indexing)
            // A late queue report, and a late answer to the request, change nothing now.
            model.downloadStateDidChange(DownloadManagerState(activeVolumeIds: ["frus1900"], pendingVolumeIds: []))
            model.enqueued("frus1900", outcome: .queued)
            #expect(Self.status(model, "frus1900") == .indexing)
            model.indexingDidFinish("frus1900", failure: nil)
            model.transferDidFinish("frus1900", outcome: .succeeded)
            #expect(Self.status(model, "frus1900") == .updated)

            // The re-index's end may arrive before the transfer's.
            let early = KeepingCurrentModel()
            early.listed(Self.listed(["frus1901"]))
            try "<old/>".write(to: dm.volumeURL(for: "frus1901"), atomically: true, encoding: .utf8)
            await early.update("frus1901", downloads: dm)
            early.indexingDidFinish("frus1901", failure: nil)
            early.transferDidFinish("frus1901", outcome: .succeeded)
            #expect(Self.status(early, "frus1901") == .updated)
        }
    }

    /// The owner's answer of 2026-10-16: a volume already downloading says so and follows that
    /// download. Before #1660 the decline was silent and the row vanished.
    @Test("Update on a volume already downloading says so, and follows that download")
    func alreadyDownloading() async throws {
        try await withScratchVolumes { dir in
            let model = KeepingCurrentModel()
            let dm = managerFeeding(model, in: dir, transfer: ScriptedTransfer().task, defaults: scratchDefaults())
            try "<old/>".write(to: dm.volumeURL(for: "frus1900"), atomically: true, encoding: .utf8)
            model.listed(Self.listed(["frus1900"]))
            // Another path queues it first; the manager is suspended, so it waits.
            await dm.enqueueDownload(catalogueEntry("frus1900"), force: true)

            await model.update("frus1900", downloads: dm)
            #expect(Self.status(model, "frus1900") == .alreadyDownloading)

            await dm.resumeQueuedDownloads()
            #expect(await eventually { Self.status(model, "frus1900") == .indexing })
        }
    }

    @Test("A failed update offers Retry with its reason, and Update All takes only the rows that offer Update or Retry")
    func failuresAndUpdateAll() async throws {
        try await withScratchVolumes { dir in
            let model = KeepingCurrentModel()
            let ids = ["frus1900", "frus1901", "frus1902", "frus1903"]
            let setup = DownloadManager(volumesDirectory: dir, downloadTask: ScriptedTransfer().task,
                                        onStateChanged: { _ in }, preferences: scratchDefaults())
            for id in ids { try "<old/>".write(to: setup.volumeURL(for: id), atomically: true, encoding: .utf8) }
            model.listed(Self.listed(ids))
            for id in ids.dropFirst() { await model.update(id, downloads: setup) }
            let timedOut = DownloadFailure(urlErrorCode: .timedOut, description: "The request timed out.")
            model.transferDidFinish("frus1901", outcome: .failed(timedOut))
            model.transferDidFinish("frus1903", outcome: .succeeded)
            model.indexingDidFinish("frus1903", failure: nil)
            #expect(model.rows.map(\.status) == [.available, .failed(.download(timedOut)), .queued, .updated])
            #expect(KeepingCurrentCopy.failure(.download(timedOut)) == "The download failed: it timed out.")

            let fresh = DownloadManager(volumesDirectory: dir, downloadTask: ScriptedTransfer().task,
                                        onStateChanged: { _ in }, preferences: scratchDefaults())
            await model.updateAll(downloads: fresh)
            #expect(await fresh.currentState.pendingVolumeIds == ["frus1900", "frus1901"],
                    "Update All asked for a row whose update was under way or done, or missed one")
            #expect(model.rows.map(\.status) == [.queued, .queued, .queued, .updated])
            #expect(model.offersUpdateAll == false)
        }
    }

    @Test("A cancelled update offers Update again, and a re-check keeps a row whose update is under way")
    func cancelAndRecheck() async throws {
        try await withScratchVolumes { dir in
            let model = KeepingCurrentModel()
            let dm = DownloadManager(volumesDirectory: dir, downloadTask: ScriptedTransfer().task,
                                     onStateChanged: { _ in }, preferences: scratchDefaults())
            for id in ["frus1900", "frus1901", "frus1902"] {
                try "<old/>".write(to: dm.volumeURL(for: id), atomically: true, encoding: .utf8)
            }
            model.listed(Self.listed(["frus1900", "frus1901", "frus1902"]))
            for id in ["frus1900", "frus1901", "frus1902"] { await model.update(id, downloads: dm) }
            model.transferDidFinish("frus1900", outcome: .cancelled)
            #expect(Self.status(model, "frus1900") == .available)

            // frus1901 is being indexed (its new file matches, so a check no longer finds it), and
            // frus1902 is updated (current, so not found either).
            model.transferDidFinish("frus1901", outcome: .succeeded)
            model.transferDidFinish("frus1902", outcome: .succeeded)
            model.indexingDidFinish("frus1902", failure: nil)
            model.listed(Self.listed(["frus1900", "frus1903"]))
            #expect(model.rows.map(\.id) == ["frus1900", "frus1903", "frus1901"])
            #expect(model.rows.map(\.status) == [.available, .available, .indexing])
        }
    }

    @Test("Why the published list could not be read is named: offline, GitHub's limit, an error status, or the system's reason")
    func listProblems() {
        let reset = Date(timeIntervalSince1970: 1_792_000_000)
        let url = URL(string: "https://api.github.com/repos/HistoryAtState/frus/contents/volumes")!
        let limited = LiveListingError(response: HTTPURLResponse(
            url: url, statusCode: 403, httpVersion: nil,
            headerFields: ["X-RateLimit-Remaining": "0", "X-RateLimit-Reset": "1792000000"])!)
        #expect(limited.isRateLimited)
        #expect(limited.retryAfter == reset)
        let forbidden = LiveListingError(response: HTTPURLResponse(
            url: url, statusCode: 403, httpVersion: nil, headerFields: ["X-RateLimit-Remaining": "12"])!)
        #expect(forbidden.isRateLimited == false)
        let now = Date(timeIntervalSince1970: 1_000)
        let secondary = LiveListingError(response: HTTPURLResponse(
            url: url, statusCode: 429, httpVersion: nil, headerFields: ["Retry-After": "60"])!, now: now)
        #expect(secondary.isRateLimited)
        #expect(secondary.retryAfter == now.addingTimeInterval(60))

        #expect(KeepingCurrentModel.problem(for: limited, isOnline: true) == .rateLimited(until: reset))
        #expect(KeepingCurrentModel.problem(for: forbidden, isOnline: true) == .server(status: 403))
        #expect(KeepingCurrentModel.problem(for: URLError(.notConnectedToInternet), isOnline: true) == .offline)
        #expect(KeepingCurrentModel.problem(for: limited, isOnline: false) == .offline)
        if case .other(let description) = KeepingCurrentModel.problem(for: URLError(.timedOut), isOnline: true) {
            #expect(description == URLError(.timedOut).localizedDescription)
        } else {
            Issue.record("a timeout was not read as the system's reason")
        }
        #expect(KeepingCurrentCopy.listProblem(.server(status: 502)) == "GitHub answered with error 502. Try again later.")
    }

    @Test("Check for Corrections with no published list and no connection says so, and lists nothing")
    func checkOffline() async throws {
        try await withScratchVolumes { dir in
            let model = KeepingCurrentModel()
            let dm = DownloadManager(volumesDirectory: dir, downloadTask: ScriptedTransfer().task,
                                     onStateChanged: { _ in }, preferences: scratchDefaults())
            let manifest = ManifestStore()
            #expect(manifest.diffResult == nil)
            await model.check(manifest: manifest, downloads: dm, isOnline: false)
            #expect(model.listProblem == .offline)
            #expect(model.rows.isEmpty)
            #expect(model.hasChecked == false)
            #expect(model.isChecking == false)
        }
    }
}

// MARK: - The published list (#1660)

/// Answers the GitHub listing from a scenario, counting requests. One suite uses it, serialized,
/// so its scenario is never another test's.
final class StubVolumeListing: URLProtocol, @unchecked Sendable {

    /// What the listing answers.
    struct Scenario {
        var status = 200
        var headers: [String: String] = [:]
        var body = Data()
        var delay: TimeInterval = 0
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var scenario = Scenario()
    nonisolated(unsafe) private static var requests = 0

    /// Sets what the listing answers, and starts the count again.
    static func answer(with scenario: Scenario) {
        lock.lock(); defer { lock.unlock() }
        self.scenario = scenario
        requests = 0
    }

    /// How many requests reached the listing since `answer(with:)`.
    static var requestCount: Int {
        lock.lock(); defer { lock.unlock() }
        return requests
    }

    /// A session whose requests this answers.
    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubVolumeListing.self]
        return URLSession(configuration: configuration)
    }

    /// A listing of one volume, as GitHub's contents API gives it.
    static func listing(_ filename: String, sha: String, size: Int = 30_000) -> Data {
        let entry: [String: Any] = ["name": filename, "size": size, "sha": sha,
                                    "download_url": "https://raw.githubusercontent.com/HistoryAtState/frus/master/volumes/\(filename)"]
        return try! JSONSerialization.data(withJSONObject: [entry])
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self.requests += 1
        let scenario = Self.scenario
        Self.lock.unlock()
        let respond: @Sendable () -> Void = { [self] in
            let response = HTTPURLResponse(url: request.url!, statusCode: scenario.status,
                                           httpVersion: nil, headerFields: scenario.headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: scenario.body)
            client?.urlProtocolDidFinishLoading(self)
        }
        if scenario.delay > 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + scenario.delay, execute: respond)
        } else {
            respond()
        }
    }

    override func stopLoading() {}
}

/// The published list: one read at a time, GitHub's limit kept, and a check that reads it itself.
@Suite("Keeping Current: reading the published list (#1660)", .serialized)
@MainActor
struct KeepingCurrentListingTests {

    /// Before #1660 a second call returned at once while the first was under way, so Check for
    /// Corrections, pressed while the pane's own read was running, found no list.
    @Test("A read asked for while one is under way waits for it, and only one request is made")
    func aSecondReadWaits() async throws {
        StubVolumeListing.answer(with: .init(body: StubVolumeListing.listing("frus1900.xml", sha: "abc"), delay: 0.3))
        let manifest = ManifestStore()
        let session = StubVolumeListing.session()
        let first = Task { await manifest.fetchLiveManifest(session: session) }
        #expect(await eventually { manifest.isFetchingLive })
        await manifest.fetchLiveManifest(session: session)
        #expect(manifest.diffResult != nil, "the second read returned before the first had read the list")
        await first.value
        #expect(StubVolumeListing.requestCount == 1)
    }

    @Test("GitHub's limit is kept as the read's error, and named as the reason")
    func theLimitIsKept() async throws {
        StubVolumeListing.answer(with: .init(status: 403,
                                             headers: ["X-RateLimit-Remaining": "0", "X-RateLimit-Reset": "1792000000"]))
        let manifest = ManifestStore()
        await manifest.fetchLiveManifest(session: StubVolumeListing.session())
        #expect(manifest.diffResult == nil)
        let error = try #require(manifest.liveFetchError as? LiveListingError)
        #expect(error.isRateLimited)
        #expect(KeepingCurrentModel.problem(for: error, isOnline: true)
                == .rateLimited(until: Date(timeIntervalSince1970: 1_792_000_000)))
    }

    /// The owner's answer of 2026-10-16: Check for Corrections reads the list itself when the
    /// launch has none. Before #1660 its button was disabled until the list had been read.
    @Test("Check for Corrections reads the list when it has none, lists the volume that differs, and says when it cannot")
    func theCheckReadsTheList() async throws {
        try await withScratchVolumes { dir in
            // A catalogue volume, so the bundled manifest knows it.
            let volumeId = "frus1900"
            let model = KeepingCurrentModel()
            let dm = DownloadManager(volumesDirectory: dir, downloadTask: ScriptedTransfer().task,
                                     onStateChanged: { _ in }, preferences: scratchDefaults())
            try "<mine/>".write(to: dm.volumeURL(for: volumeId), atomically: true, encoding: .utf8)
            await dm.markSideloaded(volumeId)

            StubVolumeListing.answer(with: .init(status: 503))
            let failing = ManifestStore()
            await model.check(manifest: failing, downloads: dm, isOnline: true, session: StubVolumeListing.session())
            #expect(model.listProblem == .server(status: 503))
            #expect(model.hasChecked == false)

            StubVolumeListing.answer(with: .init(body: StubVolumeListing.listing("\(volumeId).xml", sha: "abc")))
            let manifest = ManifestStore()
            await model.check(manifest: manifest, downloads: dm, isOnline: true, session: StubVolumeListing.session())
            #expect(StubVolumeListing.requestCount == 1)
            #expect(model.listProblem == nil)
            #expect(model.rows.map(\.id) == [volumeId])
            #expect(model.rows.first?.isSideloaded == true)
            #expect(model.rows.first?.status == .available)
        }
    }
}
