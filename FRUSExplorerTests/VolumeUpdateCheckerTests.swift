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

/// Creates a temporary directory scoped to the test, cleaned up after the test body returns.
private func withTempDirectory(_ body: (URL) async throws -> Void) async throws {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("FRUSTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    try await body(dir)
}

/// A `DownloadTask` that is never expected to run — `updatableVolumes` only reads
/// files already present on disk, it never enqueues a transfer.
private func unusedDownloadTask() -> DownloadManager.DownloadTask {
    return { _ in throw URLError(.cancelled) }
}

private func makeManifestEntry(volumeId: String) -> VolumeManifestEntry {
    VolumeManifestEntry(
        volumeId: volumeId,
        filename: "\(volumeId).xml",
        subseries: "1990-92",
        title: "Sample Volume \(volumeId)",
        dateRange: DateRange(earliest: "1990-01-01", latest: "1992-12-31"),
        publicationDate: "2020",
        status: .published,
        editors: [],
        generalEditor: nil,
        documentCount: 0,
        sizeBytes: 1_000,
        tags: []
    )
}

/// Tests for `VolumeUpdateChecker.hasUpdate(local:live:)`,
/// `DownloadManager.gitBlobSHA1(for:)`, and `VolumeUpdateChecker.updatableVolumes(...)`
/// (Session 154 upstream update detection).
@Suite("VolumeUpdateChecker")
struct VolumeUpdateCheckerTests {

    // MARK: - gitBlobSHA1

    @Test("gitBlobSHA1 matches `git hash-object --stdin` for an empty file")
    func gitBlobSHA1MatchesKnownEmptyValue() {
        #expect(DownloadManager.gitBlobSHA1(for: Data()) == "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    }

    @Test("gitBlobSHA1 matches `git hash-object --stdin` for a single-line file")
    func gitBlobSHA1MatchesKnownHelloValue() {
        #expect(DownloadManager.gitBlobSHA1(for: Data("hello\n".utf8)) == "ce013625030ba8dba906f756967f9e9ca394464a")
    }

    // MARK: - hasUpdate fixture comparisons

    @Test("hasUpdate is false when the local and live SHAs match")
    func hasUpdateFalseWhenShaUnchanged() {
        let local = LocalVolumeInfo(sha: "abc123", sizeBytes: 1_000)
        let live = LiveVolumeInfo(sha: "abc123", sizeBytes: 1_000)
        #expect(VolumeUpdateChecker.hasUpdate(local: local, live: live) == false)
    }

    @Test("hasUpdate is true when the live SHA differs, even if size is unchanged")
    func hasUpdateTrueWhenShaChanged() {
        let local = LocalVolumeInfo(sha: "abc123", sizeBytes: 1_000)
        let live = LiveVolumeInfo(sha: "def456", sizeBytes: 1_000)
        #expect(VolumeUpdateChecker.hasUpdate(local: local, live: live) == true)
    }

    @Test("hasUpdate falls back to a size comparison when no local SHA is available")
    func hasUpdateUsesSizeFallbackWhenShaMissing() {
        let unchanged = LocalVolumeInfo(sha: nil, sizeBytes: 1_000)
        let changed = LocalVolumeInfo(sha: nil, sizeBytes: 999)
        let live = LiveVolumeInfo(sha: "irrelevant-because-no-local-sha", sizeBytes: 1_000)

        #expect(VolumeUpdateChecker.hasUpdate(local: unchanged, live: live) == false)
        #expect(VolumeUpdateChecker.hasUpdate(local: changed, live: live) == true)
    }

    @Test("hasUpdate is false when neither a local SHA nor size is available")
    func hasUpdateFalseWhenLocalInfoUnavailable() {
        let local = LocalVolumeInfo(sha: nil, sizeBytes: nil)
        let live = LiveVolumeInfo(sha: "abc123", sizeBytes: 1_000)
        #expect(VolumeUpdateChecker.hasUpdate(local: local, live: live) == false)
    }

    // MARK: - updatableVolumes orchestration

    @Test("updatableVolumes flags only downloaded volumes whose live copy changed")
    func updatableVolumesFiltersCorrectly() async throws {
        try await withTempDirectory { dir in
            let unchangedId = "frus1990-92v97"
            let changedId = "frus1990-92v98"
            let notDownloadedId = "frus1990-92v99"

            let unchangedContent = "<volumes>unchanged</volumes>"
            let changedContent = "<volumes>changed locally</volumes>"
            try unchangedContent.write(to: dir.appendingPathComponent("\(unchangedId).xml"), atomically: true, encoding: .utf8)
            try changedContent.write(to: dir.appendingPathComponent("\(changedId).xml"), atomically: true, encoding: .utf8)

            let dm = DownloadManager(
                volumesDirectory: dir,
                concurrencyLimit: 4,
                downloadTask: unusedDownloadTask(),
                onStateChanged: { _ in }
            )

            let unchangedSha = DownloadManager.gitBlobSHA1(for: Data(unchangedContent.utf8))
            let liveInfo: [String: LiveVolumeInfo] = [
                unchangedId: LiveVolumeInfo(sha: unchangedSha, sizeBytes: unchangedContent.utf8.count),
                changedId: LiveVolumeInfo(sha: "different-sha-from-upstream", sizeBytes: changedContent.utf8.count + 1),
                notDownloadedId: LiveVolumeInfo(sha: "anything", sizeBytes: 1)
            ]

            let known = [unchangedId, changedId, notDownloadedId].map(makeManifestEntry(volumeId:))

            let updatable = await VolumeUpdateChecker.updatableVolumes(
                known: known,
                liveInfoByVolumeId: liveInfo,
                downloadManager: dm
            )

            #expect(updatable.map(\.id) == [changedId])
        }
    }
}
