// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
import CryptoKit
@testable import FRUSExplorer

/// The query-encoder model store's validation and lifecycle (V-5 s2), against real temp
/// directories — the store's whole point is filesystem truth, so faking the filesystem would
/// test a different type.
///
/// The pinned SHA in these tests is a FIXTURE hash of small fixture bytes, not the real 229 MB
/// pin: the store's rules (length before digest, marker after copy, purge on pin change) are
/// size-independent, and a suite that needed the real file would be a suite nobody runs.
///
/// Version history:
///   1.0 — V-5 s2
@Suite("Semantic model store")
struct SemanticModelStoreTests {

    /// Fixture bytes standing in for the model, with their real digest.
    private static let fixtureBytes = Data("not a real gguf, but honestly hashed".utf8)
    private static var fixtureSHA: String {
        SHA256.hash(data: fixtureBytes).map { String(format: "%02x", $0) }.joined()
    }

    private func makeDirectory() throws -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("model-store-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func writeFixture(_ data: Data = fixtureBytes, in dir: URL) throws -> URL {
        let url = dir.appendingPathComponent("incoming.gguf")
        try data.write(to: url)
        return url
    }

    // MARK: - The settings status

    /// **The status carries the verified URL, so the view never asks the actor.**
    ///
    /// `SemanticModelSection`'s path row used to call `SemanticModelStore.verifiedModelURL()`
    /// straight from its body: an actor-isolated call from a synchronous MainActor context — a
    /// strict-concurrency warning the project's standards forbid — and two filesystem stats on
    /// every body evaluation. `semanticModelStatus()` was already awaiting that same actor and
    /// throwing the URL away.
    ///
    /// Driven end to end through a real store and a real adopt, not through a hand-built status,
    /// so the assertion covers the hop the view depends on rather than a copy of it.
    @Test("The status carries the verified URL, and presence is that same fact")
    @MainActor
    func statusCarriesTheVerifiedURL() async throws {
        let dir = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SemanticModelStore(
            directory: dir, expectedSHA256: Self.fixtureSHA,
            expectedBytes: Self.fixtureBytes.count)
        let state = AppState()
        state.semanticModelStore = store

        var status = await state.semanticModelStatus()
        #expect(status.isAvailable)
        #expect(status.verifiedURL == nil, "nothing adopted yet")
        #expect(!status.isPresent)

        try await store.adoptModel(from: writeFixture(in: dir))

        status = await state.semanticModelStatus()
        #expect(status.verifiedURL == store.modelFileURL)
        #expect(status.isPresent, "presence and the URL are one fact and cannot disagree")
        #expect(status.bytesOnDisk == Self.fixtureBytes.count)
    }

    /// The stack-not-booted state names no file, and is not "downloaded".
    @Test("An unavailable status has no URL and is not present")
    func unavailableStatusNamesNoFile() {
        #expect(AppState.SemanticModelStatus.unavailable.verifiedURL == nil)
        #expect(!AppState.SemanticModelStatus.unavailable.isPresent)
        #expect(!AppState.SemanticModelStatus.unavailable.isAvailable)
    }

    @Test("A wrong-length file is refused before any hashing, and nothing lands")
    func wrongLengthRefused() async throws {
        let dir = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        // The default pin is the real 229 MB length; fixture bytes can never match it.
        let store = SemanticModelStore(directory: dir, expectedSHA256: Self.fixtureSHA)
        let source = try writeFixture(in: dir)

        await #expect(throws: SemanticModelError.self) {
            try await store.adoptModel(from: source)
        }
        #expect(await !store.isModelPresent())
        #expect(FileManager.default.fileExists(atPath: source.path),
                "the source is the fetcher's to clean up, not the store's")
    }

    @Test("Right length, wrong bytes: refused on the digest, and nothing lands")
    func wrongDigestRefused() async throws {
        let dir = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SemanticModelStore(
            directory: dir, expectedSHA256: Self.fixtureSHA,
            expectedBytes: Self.fixtureBytes.count)
        var corrupted = Self.fixtureBytes
        corrupted[0] ^= 0xFF
        let source = try writeFixture(corrupted, in: dir)

        await #expect(throws: SemanticModelError.self) {
            try await store.adoptModel(from: source)
        }
        #expect(await !store.isModelPresent())
    }

    @Test("The happy path: adopt verifies, lands the file, writes the marker, opens the door")
    func adoptHappyPath() async throws {
        let dir = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SemanticModelStore(
            directory: dir, expectedSHA256: Self.fixtureSHA,
            expectedBytes: Self.fixtureBytes.count)
        let source = try writeFixture(in: dir)

        try await store.adoptModel(from: source)
        #expect(await store.isModelPresent())
        #expect(await store.verifiedModelURL() != nil)
        #expect(await store.bytesOnDisk() == Self.fixtureBytes.count)
        // Same pin, so a boot-time purge leaves the adopted file alone.
        #expect(await !store.purgeIfPinChanged())
    }

    @Test("The verified door opens only when marker, file, and length all agree")
    func verifiedDoorNeedsAllThree() async throws {
        let dir = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SemanticModelStore(directory: dir, expectedSHA256: Self.fixtureSHA)

        // Nothing on disk: closed.
        #expect(await store.verifiedModelURL() == nil)

        // A file with no marker: closed — nothing vouched for it.
        try Self.fixtureBytes.write(to: store.modelFileURL)
        #expect(await store.verifiedModelURL() == nil)
    }

    @Test("Remove is idempotent and clears both file and marker")
    func removeIsIdempotent() async throws {
        let dir = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SemanticModelStore(directory: dir, expectedSHA256: Self.fixtureSHA)
        try Self.fixtureBytes.write(to: store.modelFileURL)

        await store.removeModel()
        await store.removeModel()
        #expect(await store.bytesOnDisk() == 0)
    }

    @Test("A pin change purges the stored file; the same pin leaves it alone")
    func pinChangePurges() async throws {
        let dir = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Simulate an adopted file from generation A: file + marker recording pin A.
        try Self.fixtureBytes.write(to: dir.appendingPathComponent(SemanticModelStore.fileName))
        try Self.fixtureSHA.write(
            to: dir.appendingPathComponent(".sha256"), atomically: true, encoding: .utf8)

        // Same pin: nothing happens.
        let sameStore = SemanticModelStore(directory: dir, expectedSHA256: Self.fixtureSHA)
        #expect(await !sameStore.purgeIfPinChanged())
        #expect(await sameStore.bytesOnDisk() > 0)

        // A moved pin (a new artifact generation): the file goes.
        let movedStore = SemanticModelStore(
            directory: dir, expectedSHA256: String(repeating: "0", count: 64))
        #expect(await movedStore.purgeIfPinChanged())
        #expect(await movedStore.bytesOnDisk() == 0)
    }

    @Test("A file with NO marker is purged — unverifiable is stale, the shard store's rule")
    func absentMarkerPurges() async throws {
        let dir = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        try Self.fixtureBytes.write(to: dir.appendingPathComponent(SemanticModelStore.fileName))

        let store = SemanticModelStore(directory: dir, expectedSHA256: Self.fixtureSHA)
        #expect(await store.purgeIfPinChanged(),
                "a 229 MB file nothing vouched for must not be kept and counted")
        #expect(await store.bytesOnDisk() == 0)
    }

    @Test("An empty directory purges nothing and reports false")
    func emptyDirectoryIsQuiet() async throws {
        let dir = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SemanticModelStore(directory: dir, expectedSHA256: Self.fixtureSHA)
        #expect(await !store.purgeIfPinChanged())
    }

    @Test("The streamed hash agrees with a one-shot CryptoKit hash")
    func streamedHashAgrees() throws {
        let dir = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        // Larger than one 4 MB slice, so the loop actually loops.
        var data = Data(capacity: 5 << 20)
        for index in 0..<(5 << 20) { data.append(UInt8(truncatingIfNeeded: index)) }
        let url = dir.appendingPathComponent("big.bin")
        try data.write(to: url)

        let oneShot = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        #expect(try SemanticModelStore.sha256Hex(of: url) == oneShot)
    }
}

/// The model section is mounted by BOTH hand-maintained hub twins, and neither hub carries its
/// own copy of the strings — the `SemanticStorageSection` parity rule extended to the new
/// section.
@Suite("Semantic model section parity")
struct SemanticModelSectionParityTests {

    private static func hubSource(_ name: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        return try String(
            contentsOf: root.appendingPathComponent("FRUSExplorer/Settings/\(name)"),
            encoding: .utf8)
    }

    @Test("Both hubs mount SemanticModelSection")
    func bothHubsMount() throws {
        for hub in ["VolumesStorageHubView.swift", "MacVolumesStorageHub.swift"] {
            let source = try Self.hubSource(hub)
            #expect(source.contains("SemanticModelSection()"),
                    "\(hub) must mount the shared section — a per-hub copy is the drift #900 exists to prevent")
        }
    }

    @Test("Neither hub carries settings.model strings of its own")
    func noModelStringsInHubs() throws {
        for hub in ["VolumesStorageHubView.swift", "MacVolumesStorageHub.swift"] {
            let source = try Self.hubSource(hub)
            #expect(!source.contains("settings.model."),
                    "\(hub) must not re-declare the model section's copy")
        }
    }
}
