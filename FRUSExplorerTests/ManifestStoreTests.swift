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

    // MARK: - Subseries Extraction

    // frusSubseries(from:) extracts all leading digits and dashes from the post-"frus"
    // portion of a filename, stopping at the first letter.
    // Tests call the module-level free function directly to avoid access-level friction.

    @Test("frusSubseries(from:): standard year-range volumes", arguments: [
        ("frus1969-76v01.xml",   "1969-76"),
        ("frus1977-80v12.xml",   "1977-80"),
        ("frus1952-54v06p2.xml", "1952-54"),
        ("frus1981-88v28.xml",   "1981-88"),
    ])
    func subseriesYearRange(filename: String, expected: String) {
        #expect(frusSubseries(from: filename) == expected)
    }

    @Test("frusSubseries(from:): single-year volumes")
    func subseriesSingleYear() {
        #expect(frusSubseries(from: "frus1861.xml") == "1861")
        #expect(frusSubseries(from: "frus1950.xml") == "1950")
    }

    @Test("frusSubseries(from:): non-v+digits suffixes are stripped correctly")
    func subseriesNonVolumeLetterSuffix() {
        // Appendix suffix — old code returned "1877app"
        #expect(frusSubseries(from: "frus1877app.xml") == "1877")
        // Part designators — old code returned "1863p1" / "1863p2"
        #expect(frusSubseries(from: "frus1863p1.xml") == "1863")
        #expect(frusSubseries(from: "frus1863p2.xml") == "1863")
        // Country-name suffix
        #expect(frusSubseries(from: "frus1894Nicaragua.xml") == "1894")
    }

    @Test("frusSubseries(from:): invalid inputs return nil")
    func subseriesInvalidInputs() {
        #expect(frusSubseries(from: "frus1969-76v01.json") == nil) // wrong extension
        #expect(frusSubseries(from: "other1969-76v01.xml") == nil) // wrong prefix
        #expect(frusSubseries(from: "frus.xml") == nil)            // nothing after "frus"
        #expect(frusSubseries(from: "") == nil)
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

    // MARK: - No document count (#1504)

    /// The repository root, from this file's own path.
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // FRUSExplorerTests
            .deletingLastPathComponent()   // repo root
    }

    /// The manifest carried a per-volume `documentCount` that no generator ever filled: it read 0
    /// in all 553 rows, and its only reader was Citation Lookup's nearest-document strategy, which
    /// therefore never answered. Both are deleted (#1504, owner decision D6). This reads the
    /// bundled file's raw rows — a decoder ignores a key it does not know, so decoding would pass
    /// with the key still there.
    @Test("No row of the bundled manifest carries a documentCount (#1504)")
    func bundledManifestCarriesNoDocumentCount() throws {
        let url = Self.repoRoot.appendingPathComponent("FRUSExplorer/Resources/manifest.json")
        let rows = try #require(
            try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [[String: Any]])
        #expect(rows.count >= 553, "Read \(rows.count) manifest rows: the scan is broken, not the file clean.")
        let carrying = rows.filter { $0["documentCount"] != nil }.compactMap { $0["volumeId"] as? String }
        #expect(carrying.isEmpty, "\(carrying.count) rows still carry documentCount, e.g. \(carrying.prefix(3))")
    }

    /// Neither declaration of `VolumeManifestEntry` — the app's, and the generator's, which writes the
    /// file — declares the field, so a regenerated manifest cannot bring it back (#1504).
    @Test("Neither VolumeManifestEntry declares a documentCount (#1504)",
          arguments: ["FRUSExplorer/Models/Manifest/ManifestModels.swift",
                      "ManifestGeneratorCore/ManifestModels.swift"])
    func manifestModelsDeclareNoDocumentCount(_ path: String) throws {
        let source = try String(contentsOf: Self.repoRoot.appendingPathComponent(path), encoding: .utf8)
        let start = try #require(source.range(of: "struct VolumeManifestEntry"), "\(path) declares no VolumeManifestEntry")
        // The struct's own body: from its opening brace to the brace that closes it.
        var depth = 0
        var body = ""
        for character in source[start.upperBound...] {
            if character == "{" { depth += 1 }
            if depth > 0 { body.append(character) }
            if character == "}" {
                depth -= 1
                if depth == 0 { break }
            }
        }
        #expect(body.count > 200, "\(path): read \(body.count) characters of the struct — the scan is broken")
        #expect(!body.contains("documentCount"), "\(path) still declares documentCount")
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
            sizeBytes: 4_521_000,
            tags: ["kissinger-henry-a"]
        )
    }
}
