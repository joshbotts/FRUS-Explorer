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

// MARK: - CitationMatchingEngineTests

struct CitationMatchingEngineTests {

    // MARK: - Helpers

    /// Returns a minimal `VolumeManifestEntry` for test fixtures.
    private static func makeVolume(
        volumeId: String,
        subseries: String,
        title: String,
        documentCount: Int = 50
    ) -> VolumeManifestEntry {
        VolumeManifestEntry(
            volumeId: volumeId,
            filename: "\(volumeId).xml",
            subseries: subseries,
            title: title,
            dateRange: DateRange(earliest: "1969-01-01", latest: "1969-12-31"),
            publicationDate: "1969",
            status: .published,
            editors: [],
            generalEditor: nil,
            documentCount: documentCount,
            sizeBytes: 0,
            tags: []
        )
    }

    private static func makeManifestStore(volumes: [VolumeManifestEntry]) -> ManifestStore {
        ManifestStore(bundledEntries: volumes)
    }

    // MARK: - Era Detection Tests

    @Test("CitationMatchingEngineTest: isPreModernVolume — pre-1955 volume identified correctly")
    func preModernVolumeDetectionTest() async {
        let engine = CitationMatchingEngine(
            manifestStore: makeManifestStore(volumes: []),
            searchService: nil,
            pageRangeStore: nil,
            downloadedVolumeIds: []
        )
        let oldVol  = makeVolume(volumeId: "frus1861v01", subseries: "1861", title: "FRUS 1861")
        let newVol  = makeVolume(volumeId: "frus1969-76v01", subseries: "1969-76", title: "FRUS 1969-76 Vol I")
        let oldVol2 = makeVolume(volumeId: "frus1950v01", subseries: "1950", title: "FRUS 1950")

        await #expect(engine.isPreModernVolume(oldVol))
        await #expect(!engine.isPreModernVolume(newVol))
        await #expect(engine.isPreModernVolume(oldVol2))
    }

    @Test("CitationMatchingEngineTest: isMicroficheSupplement — microfiche volumes detected")
    func microficheDetectionTest() async {
        let engine = CitationMatchingEngine(
            manifestStore: makeManifestStore(volumes: []),
            searchService: nil,
            pageRangeStore: nil,
            downloadedVolumeIds: []
        )
        let micro  = makeVolume(volumeId: "frus1969-76v01micro", subseries: "1969-76",
                                title: "FRUS 1969-76 Vol I Microfiche Supplement")
        let normal = makeVolume(volumeId: "frus1969-76v01", subseries: "1969-76",
                                title: "FRUS 1969-76 Vol I")

        await #expect(engine.isMicroficheSupplement(micro))
        await #expect(!engine.isMicroficheSupplement(normal))
    }

    // MARK: - Volume Resolution Tests

    @Test("CitationMatchingEngineTest: resolveVolume — exact subseries match narrows candidates")
    func volumeResolutionSubseriesTest() async {
        let v1 = makeVolume(volumeId: "frus1969-76v01", subseries: "1969-76", title: "FRUS 1969-76 Vol I")
        let v2 = makeVolume(volumeId: "frus1977-80v01", subseries: "1977-80", title: "FRUS 1977-80 Vol I")
        let engine = CitationMatchingEngine(
            manifestStore: makeManifestStore(volumes: [v1, v2]),
            searchService: nil,
            pageRangeStore: nil,
            downloadedVolumeIds: []
        )

        let candidates = await engine.resolveVolume(subseries: "1969-76", volumeNumber: nil, titleFragment: nil)
        #expect(candidates.count == 1)
        #expect(candidates.first?.volumeId == "frus1969-76v01")
    }

    @Test("CitationMatchingEngineTest: resolveVolume — title fragment narrows ambiguous volume list")
    func volumeResolutionTitleFragmentTest() async {
        let v1 = makeVolume(volumeId: "frus1969-76v01", subseries: "1969-76",
                            title: "FRUS 1969-76 Vol I Foundations of Foreign Policy")
        let v2 = makeVolume(volumeId: "frus1969-76v02", subseries: "1969-76",
                            title: "FRUS 1969-76 Vol II Vietnam")
        let engine = CitationMatchingEngine(
            manifestStore: makeManifestStore(volumes: [v1, v2]),
            searchService: nil,
            pageRangeStore: nil,
            downloadedVolumeIds: []
        )

        let candidates = await engine.resolveVolume(
            subseries: "1969-76",
            volumeNumber: nil,
            titleFragment: "Vietnam"
        )
        #expect(candidates.count == 1)
        #expect(candidates.first?.volumeId == "frus1969-76v02")
    }

    // MARK: - Manifest-Only Tests

    @Test("CitationMatchingEngineTest: undownloaded volume returns requiresDownload = true")
    func undownloadedVolumeTest() async throws {
        let v1 = makeVolume(volumeId: "frus1969-76v01", subseries: "1969-76",
                            title: "FRUS 1969-76 Vol I", documentCount: 50)
        let engine = CitationMatchingEngine(
            manifestStore: makeManifestStore(volumes: [v1]),
            searchService: nil,
            pageRangeStore: nil,
            downloadedVolumeIds: []  // not downloaded
        )

        let input = CitationInput(subseries: "1969-76", volumeNumber: "I", documentNumber: 10)
        let results = try await engine.match(input: input)

        #expect(!results.isEmpty)
        let first = results.first
        #expect(first?.requiresDownload == true)
        #expect(first?.volumeManifestEntry != nil)
        #expect(first?.matchStrategy == .manifestOnly)
    }

    // MARK: - No-Match Tests

    @Test("CitationMatchingEngineTest: completely unresolvable citation returns empty results")
    func noMatchTest() async throws {
        let engine = CitationMatchingEngine(
            manifestStore: makeManifestStore(volumes: []),
            searchService: nil,
            pageRangeStore: nil,
            downloadedVolumeIds: []
        )

        let input = CitationInput(subseries: "1999-00", volumeNumber: "XXII", documentNumber: 5)
        let results = try await engine.match(input: input)
        // Either empty or a best-guess with no real document
        let hasRealDocuments = results.contains { !$0.documentId.isEmpty && !$0.requiresDownload }
        #expect(!hasRealDocuments)
    }

    // MARK: - Non-Actionable Input Test

    @Test("CitationMatchingEngineTest: non-actionable input returns empty results without error")
    func nonActionableInputTest() async throws {
        let engine = CitationMatchingEngine(
            manifestStore: makeManifestStore(volumes: []),
            searchService: nil,
            pageRangeStore: nil,
            downloadedVolumeIds: []
        )

        let input = CitationInput()  // no fields set
        let results = try await engine.match(input: input)
        #expect(results.isEmpty)
    }

    // MARK: - Subseries Normalization Tests

    @Test("CitationMatchingEngineTest: subseries with en dash normalizes to match hyphen in manifest")
    func subseriesNormalizationTest() async {
        let v1 = makeVolume(volumeId: "frus1969-76v01", subseries: "1969-76",
                            title: "FRUS 1969-76 Vol I")
        let engine = CitationMatchingEngine(
            manifestStore: makeManifestStore(volumes: [v1]),
            searchService: nil,
            pageRangeStore: nil,
            downloadedVolumeIds: []
        )

        // En dash variant should still resolve
        let candidates = await engine.resolveVolume(subseries: "1969–76", volumeNumber: nil, titleFragment: nil)
        #expect(!candidates.isEmpty)
        #expect(candidates.first?.volumeId == "frus1969-76v01")
    }

    // MARK: - Pre-Modern Label Test

    @Test("CitationMatchingEngineTest: pre-modern volume detection returns correct era bool")
    func preModernEraTest() async {
        let v1955 = makeVolume(volumeId: "frus1955-57v01", subseries: "1955-57", title: "FRUS 1955-57 Vol I")
        let v1954 = makeVolume(volumeId: "frus1952-54v01", subseries: "1952-54", title: "FRUS 1952-54 Vol I")
        let engine = CitationMatchingEngine(
            manifestStore: makeManifestStore(volumes: []),
            searchService: nil,
            pageRangeStore: nil,
            downloadedVolumeIds: []
        )

        // 1955-57 straddles the boundary: subseries starts at 1955, not before 1955
        await #expect(!engine.isPreModernVolume(v1955))
        // 1952-54 is pre-modern
        await #expect(engine.isPreModernVolume(v1954))
    }
}

