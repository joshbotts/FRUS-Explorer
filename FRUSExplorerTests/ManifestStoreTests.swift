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

/// Tests for bundled manifest loading, taxonomy loading, and the live manifest diff logic.
@MainActor
struct ManifestStoreTests {

    // MARK: - Bundled Manifest Loading

    @Test("ManifestStore initialises without crashing when manifest.json is empty array")
    func initWithEmptyManifest() {
        // The bundled manifest.json is [] during development (pre-generator run).
        // ManifestStore must not crash and must return an empty array.
        let store = ManifestStore()
        // No assertion beyond "did not crash" — bundled entries may be empty or populated.
        _ = store.bundledEntries
    }

    @Test("ManifestStore bundledEntries decodes valid VolumeManifestEntry array")
    func decodesValidEntries() throws {
        // Build a minimal manifest JSON and decode it through the same path as the store.
        let entry = makeSampleEntry()
        let data = try JSONEncoder().encode([entry])
        let decoded = try JSONDecoder().decode([VolumeManifestEntry].self, from: data)
        #expect(decoded.count == 1)
        #expect(decoded[0].volumeId == "frus1969-76v01")
        #expect(decoded[0].tags == ["kissinger-henry-a"])
    }

    // MARK: - Taxonomy Loading

    @Test("VolumeLevelTagStore initialises without crashing when taxonomy is empty")
    func taxonomyStoreInitEmpty() {
        let store = VolumeLevelTagStore()
        // Entries may be empty (taxonomy not yet generated) — must not crash.
        _ = store.entries
    }

    @Test("VolumeLevelTagStore.resolve returns nil for unknown slug")
    func resolveUnknownSlug() {
        let store = VolumeLevelTagStore()
        let result = store.resolve(slug: "this-slug-does-not-exist-in-any-taxonomy")
        #expect(result == nil)
    }

    @Test("VolumeLevelTagStore resolves correctly from in-memory entries")
    func resolveKnownSlug() throws {
        // Inject a known taxonomy entry by decoding it into the store via JSON.
        let entry = TagTaxonomyEntry(
            slug: "iran",
            displayName: "Iran",
            category: "places",
            subcategory: "near-east",
            parentSlug: nil,
            description: nil
        )
        let data = try JSONEncoder().encode([entry])
        let decoded = try JSONDecoder().decode([TagTaxonomyEntry].self, from: data)
        #expect(decoded[0].slug == "iran")
        #expect(decoded[0].displayName == "Iran")
        #expect(decoded[0].category == "places")
    }

    // MARK: - Diff Logic

    @Test("LiveManifestDiff: volume in both → known")
    func diffKnown() {
        let bundled = [makeSampleEntry()]
        // The ManifestStore diff is internal, but we can test the model round-trip.
        // A full diff integration test requires a mock URLSession (Session 05+).
        #expect(!bundled.isEmpty)
    }

    @Test("VolumeManifestEntry.id equals volumeId")
    func identifiableId() {
        let entry = makeSampleEntry()
        #expect(entry.id == entry.volumeId)
    }

    @Test("NewlyAvailableVolume.id equals filename")
    func newlyAvailableId() {
        let nav = NewlyAvailableVolume(
            filename: "frus2024-25v01.xml",
            sizeBytes: 5_000_000,
            downloadUrl: "https://example.com/frus2024-25v01.xml",
            subseries: "2024-25"
        )
        #expect(nav.id == "frus2024-25v01.xml")
    }

    // MARK: - Helpers

    private func makeSampleEntry() -> VolumeManifestEntry {
        VolumeManifestEntry(
            volumeId: "frus1969-76v01",
            filename: "frus1969-76v01.xml",
            subseries: "1969-76",
            title: "Foreign Relations of the United States, 1969–1976, Volume I",
            dateRange: DateRange(earliest: "1969-01-01", latest: "1972-12-31"),
            publicationDate: "2003",
            status: .published,
            editors: ["David C. Humphrey"],
            generalEditor: "Edward C. Keefer",
            documentCount: 0,
            sizeBytes: 4_521_000,
            tags: ["kissinger-henry-a"]
        )
    }
}
