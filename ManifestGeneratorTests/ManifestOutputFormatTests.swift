// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import ManifestGeneratorCore

/// Tests that the manifest JSON output format round-trips cleanly.
struct ManifestOutputFormatTests {

    @Test("VolumeManifestEntry round-trips through JSON encoding and decoding")
    func roundTrip() throws {
        let entry = VolumeManifestEntry(
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
            tags: ["kissinger-henry-a", "iran"]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode([entry])

        let decoded = try JSONDecoder().decode([VolumeManifestEntry].self, from: data)
        #expect(decoded.count == 1)
        #expect(decoded[0].volumeId == "frus1969-76v01")
        #expect(decoded[0].tags == ["kissinger-henry-a", "iran"])
        #expect(decoded[0].status == .published)
        #expect(decoded[0].dateRange.earliest == "1969-01-01")
        #expect(decoded[0].generalEditor == "Edward C. Keefer")
    }

    @Test("VolumeManifestEntry with nil optional fields round-trips correctly")
    func roundTripNilFields() throws {
        let entry = VolumeManifestEntry(
            volumeId: "frus1861",
            filename: "frus1861.xml",
            subseries: "1861",
            title: "Foreign Relations of the United States, 1861",
            dateRange: DateRange(earliest: nil, latest: nil),
            publicationDate: nil,
            status: .published,
            editors: [],
            generalEditor: nil,
            documentCount: 0,
            sizeBytes: 500_000,
            tags: []
        )

        let data = try JSONEncoder().encode([entry])
        let decoded = try JSONDecoder().decode([VolumeManifestEntry].self, from: data)
        #expect(decoded[0].publicationDate == nil)
        #expect(decoded[0].generalEditor == nil)
        #expect(decoded[0].tags.isEmpty)
        #expect(decoded[0].dateRange.earliest == nil)
    }

    @Test("VolumeStatus raw values match specification")
    func volumeStatusRawValues() {
        #expect(VolumeStatus.published.rawValue == "published")
        #expect(VolumeStatus.partiallyPublished.rawValue == "partiallyPublished")
        #expect(VolumeStatus.planned.rawValue == "planned")
    }
}
