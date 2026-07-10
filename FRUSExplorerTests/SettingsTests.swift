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

// MARK: - SettingsTests

struct SettingsTests {

    // MARK: - SideloadValidationTest

    @Test("SideloadValidationTest: valid FRUS XML is accepted and returns volumeId")
    func sideloadValidXMLAccepted() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("frus-sideload-valid-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        // Volumes dir (destination)
        let volDir = dir.appendingPathComponent("Volumes")

        // Source file
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <volume volumeId="frus1969-76v01" xmlns:frus="http://history.state.gov/frus">
          <teiHeader/>
          <text><body><div type="document" xml:id="d1"><p>Test</p></div></body></text>
        </volume>
        """
        let src = dir.appendingPathComponent("frus1969-76v01.xml")
        try xml.write(to: src, atomically: true, encoding: .utf8)

        let validator = SideloadValidator()
        let volumeId = try validator.validate(url: src, volumesDirectory: volDir)

        #expect(volumeId == "frus1969-76v01")
        let dest = volDir.appendingPathComponent("frus1969-76v01.xml")
        #expect(FileManager.default.fileExists(atPath: dest.path))
    }

    @Test("SideloadValidationTest: non-XML file is rejected with notXML error")
    func sideloadNonXMLRejected() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("frus-sideload-nonxml-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let volDir = dir.appendingPathComponent("Volumes")

        let notXML = "This is just plain text, not XML at all."
        let src = dir.appendingPathComponent("notxml.xml")
        try notXML.write(to: src, atomically: true, encoding: .utf8)

        let validator = SideloadValidator()
        do {
            _ = try validator.validate(url: src, volumesDirectory: volDir)
            Issue.record("Expected SideloadError.notXML to be thrown")
        } catch SideloadError.notXML {
            // Expected
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("SideloadValidationTest: valid XML with unexpected root element is rejected with notFRUSVolume")
    func sideloadInvalidFRUSXMLRejected() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("frus-sideload-invalid-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let volDir = dir.appendingPathComponent("Volumes")

        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <html><body><p>Not a FRUS volume</p></body></html>
        """
        let src = dir.appendingPathComponent("notfrus.xml")
        try xml.write(to: src, atomically: true, encoding: .utf8)

        let validator = SideloadValidator()
        do {
            _ = try validator.validate(url: src, volumesDirectory: volDir)
            Issue.record("Expected SideloadError.notFRUSVolume to be thrown")
        } catch SideloadError.notFRUSVolume {
            // Expected
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("SideloadValidationTest: duplicate volume is rejected with duplicateVolume error")
    func sideloadDuplicateVolumeRejected() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("frus-sideload-dup-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let volDir = dir.appendingPathComponent("Volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)

        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <volume volumeId="frus1969-76v01"/>
        """
        let src = dir.appendingPathComponent("frus1969-76v01.xml")
        try xml.write(to: src, atomically: true, encoding: .utf8)

        // Pre-place a file at the destination to simulate a duplicate
        let existingDest = volDir.appendingPathComponent("frus1969-76v01.xml")
        try xml.write(to: existingDest, atomically: true, encoding: .utf8)

        let validator = SideloadValidator()
        do {
            _ = try validator.validate(url: src, volumesDirectory: volDir)
            Issue.record("Expected SideloadError.duplicateVolume to be thrown")
        } catch SideloadError.duplicateVolume(let id) {
            #expect(id == "frus1969-76v01")
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    // MARK: - StorageReportDisplayTest

    @Test("StorageReportDisplayTest: formattedBytes formats byte counts correctly")
    func formattedBytesIsCorrect() {
        // 0 bytes
        let zero = formattedBytes(0)
        #expect(zero.contains("0") || zero.contains("Zero"))

        // ~1 MB — ByteCountFormatter should produce something with "MB"
        let oneMB = formattedBytes(1_048_576)
        #expect(oneMB.contains("MB"))

        // ~2.5 GB
        let twoGB = formattedBytes(2_684_354_560)
        #expect(twoGB.contains("GB"))
    }

    @Test("StorageReportDisplayTest: StorageReport grandTotalBytes sums correctly")
    func storageReportGrandTotal() {
        let entry = VolumeStorageEntry(volumeId: "frus1969-76v01", volumeFileBytes: 200_000)
        let report = StorageReport(
            totalVolumesBytes: 500_000,
            totalIndexBytes: 100_000,
            totalSummariesBytes: 50_000,
            perVolume: [entry]
        )
        #expect(report.grandTotalBytes == 650_000)
        #expect(report.perVolume.first?.volumeFileBytes == 200_000)

        let formattedTotal = formattedBytes(report.grandTotalBytes)
        #expect(!formattedTotal.isEmpty)
    }

    // MARK: - ReindexTriggerTest

    @Test("ReindexTriggerTest: IndexingPipeline.indexAllVolumes completes on empty directory")
    func reindexOnEmptyDirectoryCompletes() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("frus-reindex-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let dbURL = tmpDir.appendingPathComponent("test.sqlite")
        let volDir = tmpDir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)

        let fts5 = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: fts5,
            databaseURL: dbURL,
            volumesDirectory: volDir
        )

        // indexAllVolumes on an empty directory should complete without error
        try await pipeline.indexAllVolumes()

        // Verify progress emitted completed with 0 volumes
        var completedVolumeCount: Int? = nil
        for await event in pipeline.progress {
            if case .completed(let volumes, _) = event.state {
                completedVolumeCount = volumes
                break
            }
        }
        #expect(completedVolumeCount == 0)
    }

    // MARK: - NARAPIKeyTest

    @Test("NARAPIKeyTest: key stored via KeychainStore is retrievable")
    func naraKeyStoreAndRetrieve() async throws {
        let store = KeychainStore(
            service: "test.settings.nara.\(UUID().uuidString)",
            accessGroup: nil
        )
        let testKey = "test-api-key-\(UUID().uuidString)"

        // Store the key
        try await store.setNARACatalogAPIKey(testKey)

        // Retrieve and verify
        let retrieved = try await store.getNARACatalogAPIKey()
        #expect(retrieved == testKey)

        // Verify hasAPIKey returns true
        let hasKey = await store.hasAPIKey()
        #expect(hasKey == true)

        // Clean up
        try await store.deleteNARACatalogAPIKey()
        let afterDelete = try await store.getNARACatalogAPIKey()
        #expect(afterDelete == nil)
    }

    @Test("NARAPIKeyTest: replacing an existing key stores the new value")
    func naraKeyReplacement() async throws {
        let store = KeychainStore(
            service: "test.settings.nara.replace.\(UUID().uuidString)",
            accessGroup: nil
        )
        let firstKey = "first-key"
        let secondKey = "second-key"

        try await store.setNARACatalogAPIKey(firstKey)
        #expect(try await store.getNARACatalogAPIKey() == firstKey)

        try await store.setNARACatalogAPIKey(secondKey)
        #expect(try await store.getNARACatalogAPIKey() == secondKey)

        try await store.deleteNARACatalogAPIKey()
    }
}
