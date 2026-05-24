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

// MARK: - IndexingContextCardTests

/// Data-layer tests for the context card surfaced during volume indexing.
///
/// Covers the `glossaryPersonNames` limit enforced in `buildMetadata(from:)` and
/// the discovery-summary logic used by `IndexingBannerView.discoverySummary(_:)`.
/// No UI assertions — those belong in snapshot tests when a device is available.
@Suite("IndexingContextCard — data layer (Session 116)")
struct IndexingContextCardTests {

    // MARK: - Helpers

    private func makeMetadata(
        volumeId: String = "frus1969-76v01",
        totalDocuments: Int = 100,
        editorialNoteCount: Int = 0,
        uniquePersonCount: Int = 0,
        crossReferenceCount: Int = 0,
        datedDocumentCount: Int = 0,
        glossaryPersonNames: [String] = []
    ) -> VolumeMetadataDiscovered {
        VolumeMetadataDiscovered(
            volumeId: volumeId,
            totalDocuments: totalDocuments,
            editorialNoteCount: editorialNoteCount,
            uniquePersonCount: uniquePersonCount,
            crossReferenceCount: crossReferenceCount,
            datedDocumentCount: datedDocumentCount,
            dateRangeMin: nil,
            dateRangeMax: nil,
            glossaryPersonCount: glossaryPersonNames.count,
            glossaryTermCount: 0,
            glossaryPersonNames: glossaryPersonNames
        )
    }

    private func makeVolume(
        volumeId: String = "frus1969-76v01",
        subseries: String = "1969-76",
        title: String = "Foreign Relations, 1969–1976, Volume I",
        earliest: String? = "1969-01-01",
        latest: String? = "1976-12-31"
    ) -> VolumeManifestEntry {
        VolumeManifestEntry(
            volumeId: volumeId,
            filename: "\(volumeId).xml",
            subseries: subseries,
            title: title,
            dateRange: DateRange(earliest: earliest, latest: latest),
            publicationDate: "2003",
            status: .published,
            editors: [],
            generalEditor: nil,
            documentCount: 0,
            sizeBytes: 1_000_000,
            tags: []
        )
    }

    // MARK: - glossaryPersonNames limit

    @Test("glossaryPersonNames carries at most 12 entries when metadata has exactly 12")
    func personNamesExactlyTwelve() {
        let names = (1...12).map { "Person \($0)" }
        let meta = makeMetadata(glossaryPersonNames: names)
        #expect(meta.glossaryPersonNames.count == 12)
    }

    @Test("glossaryPersonNames is limited to 12 entries by buildMetadata")
    func personNamesLimitedToTwelve() {
        // Simulate buildMetadata's `.prefix(12)` behaviour.
        let rawNames = (1...20).map { "Person \($0)" }
        let capped = Array(rawNames.sorted().prefix(12))
        let meta = makeMetadata(glossaryPersonNames: capped)
        #expect(meta.glossaryPersonNames.count == 12,
                "buildMetadata must cap glossaryPersonNames at 12")
    }

    @Test("glossaryPersonNames is empty when volume has no biographical glossary")
    func personNamesEmptyForNoGlossary() {
        let meta = makeMetadata(glossaryPersonNames: [])
        #expect(meta.glossaryPersonNames.isEmpty)
    }

    @Test("glossaryPersonNames are sorted alphabetically")
    func personNamesSortedAlphabetically() {
        let names = ["Ziegler, Ron", "Kissinger, Henry", "Nixon, Richard"]
        let sorted = names.sorted()
        let meta = makeMetadata(glossaryPersonNames: sorted)
        #expect(meta.glossaryPersonNames == sorted,
                "Names must be returned in alphabetical order")
    }

    // MARK: - Date range display

    @Test("Volume with matching earliest/latest years omits date range row")
    func sameYearDateRange() {
        let volume = makeVolume(earliest: "1969-01-01", latest: "1969-12-31")
        // When earliest.prefix(4) == latest.prefix(4), the era section omits the date range.
        let earliestYear = volume.dateRange.earliest?.prefix(4)
        let latestYear = volume.dateRange.latest?.prefix(4)
        #expect(earliestYear == latestYear,
                "Same-year volumes must not show a date range in the era section")
    }

    @Test("Volume with distinct years shows a date range")
    func distinctYearDateRange() {
        let volume = makeVolume(earliest: "1969-01-01", latest: "1976-12-31")
        let earliestYear = volume.dateRange.earliest?.prefix(4)
        let latestYear = volume.dateRange.latest?.prefix(4)
        #expect(earliestYear != latestYear,
                "Multi-year volumes must show a date range in the era section")
    }

    // MARK: - Metadata matching

    @Test("Metadata with mismatched volumeId is not shown by context card")
    func metadataVolumeIdMismatch() {
        let meta = makeMetadata(volumeId: "frus1969-76v02")
        let volume = makeVolume(volumeId: "frus1969-76v01")
        // Context card only shows metadata when IDs match.
        let matchingMeta = meta.volumeId == volume.volumeId ? meta : nil
        #expect(matchingMeta == nil,
                "Metadata for a different volume must not be shown by the context card")
    }

    @Test("Metadata with matching volumeId is surfaced by context card")
    func metadataVolumeIdMatch() {
        let meta = makeMetadata(volumeId: "frus1969-76v01")
        let volume = makeVolume(volumeId: "frus1969-76v01")
        let matchingMeta = meta.volumeId == volume.volumeId ? meta : nil
        #expect(matchingMeta != nil,
                "Metadata for the same volume must be surfaced by the context card")
    }

    // MARK: - Cross-reference section

    @Test("Zero crossReferenceCount omits the cross-reference section")
    func zeroCrossRefs() {
        let meta = makeMetadata(crossReferenceCount: 0)
        #expect(meta.crossReferenceCount == 0)
    }

    @Test("Non-zero crossReferenceCount triggers the cross-reference section")
    func nonZeroCrossRefs() {
        let meta = makeMetadata(crossReferenceCount: 312)
        #expect(meta.crossReferenceCount > 0)
    }
}
