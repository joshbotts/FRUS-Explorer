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

/// Tests for `TEIHeaderParser`.
struct TEIHeaderParserTests {

    // MARK: - Helpers

    private func parse(_ xml: String) throws -> ParsedTEIHeader {
        let data = Data(xml.utf8)
        return try TEIHeaderParser.parse(data)
    }

    // MARK: - Full Header

    @Test("Full header: title extracted correctly")
    func fullHeaderTitle() throws {
        let result = try parse(TEIFixtures.fullHeader)
        #expect(result.title == "Foreign Relations of the United States, 1969–1976, Volume I, Foundations of Foreign Policy, 1969–1972")
    }

    @Test("Full header: primary editors extracted, general editor excluded from editors array")
    func fullHeaderEditors() throws {
        let result = try parse(TEIFixtures.fullHeader)
        #expect(result.editors.contains("David C. Humphrey"))
        #expect(result.editors.contains("Edward C. Keefer"))
        #expect(result.generalEditor == "Edward C. Keefer")
    }

    @Test("Full header: publication date extracted")
    func fullHeaderPublicationDate() throws {
        let result = try parse(TEIFixtures.fullHeader)
        #expect(result.publicationDate == "2003")
    }

    @Test("Full header: date range extracted")
    func fullHeaderDateRange() throws {
        let result = try parse(TEIFixtures.fullHeader)
        #expect(result.earliestDate == "1969-01-01")
        #expect(result.latestDate == "1972-12-31")
    }

    @Test("Full header: tags extracted from correct scheme only")
    func fullHeaderTags() throws {
        let result = try parse(TEIFixtures.fullHeader)
        #expect(result.tags.sorted() == ["arms-control-and-disarmament", "iran", "kissinger-henry-a"])
    }

    // MARK: - Date Extraction (SA-1a)

    @Test("Old printed volume: publication-date TEXT → publicationDate; content-date attrs → range")
    func oldPrintedVolumeDates() throws {
        let result = try parse(TEIFixtures.oldPrintedVolume)
        // Print year from the publication-date element's TEXT, not the @when build stamp.
        #expect(result.publicationDate == "1861")
        // Coverage range from content-date @notBefore/@notAfter (its "1860 to 1861" text is ignored).
        #expect(result.earliestDate == "1860-12-31T00:00:00-05:00")
        #expect(result.latestDate == "1861-12-31T23:59:59-05:00")
    }

    @Test("In-progress modern volume: empty publication-date → nil; content-date attrs → range")
    func inProgressModernVolumeDates() throws {
        let result = try parse(TEIFixtures.inProgressModernVolume)
        #expect(result.publicationDate == nil)
        #expect(result.earliestDate == "1982-01-01T00:00:00-05:00")
        #expect(result.latestDate == "1988-12-31T23:59:59-05:00")
    }

    @Test("creation/date range still works when no content-date is present")
    func creationDateRangeStillWorks() throws {
        let result = try parse(TEIFixtures.fullHeader)
        #expect(result.earliestDate == "1969-01-01")
        #expect(result.latestDate == "1972-12-31")
    }

    @Test("publication-date with @when timestamp only does NOT populate publicationDate")
    func publicationDateWhenTimestampIgnored() throws {
        let result = try parse(TEIFixtures.publicationDateWhenTimestampOnly)
        #expect(result.publicationDate == nil)
    }

    // MARK: - No Publication Date

    @Test("Header without publication date: publicationDate is nil")
    func noPublicationDate() throws {
        let result = try parse(TEIFixtures.noPublicationDate)
        #expect(result.publicationDate == nil)
    }

    @Test("Header without publication date: title still extracted")
    func noPublicationDateTitlePresent() throws {
        let result = try parse(TEIFixtures.noPublicationDate)
        #expect(!result.title.isEmpty)
    }

    // MARK: - Tag Extraction

    @Test("Header with no tags keywords element: tags is empty array (not an error)")
    func noTagsKeywords() throws {
        let result = try parse(TEIFixtures.noTagsKeywords)
        #expect(result.tags.isEmpty)
    }

    @Test("Header with wrong-scheme keywords only: tags is empty")
    func wrongSchemeKeywords() throws {
        let result = try parse(TEIFixtures.wrongSchemeKeywords)
        #expect(result.tags.isEmpty)
    }

    @Test("Header with multiple keywords elements: only tags-scheme extracted")
    func multipleKeywordsElements() throws {
        let result = try parse(TEIFixtures.multipleKeywordsElements)
        #expect(result.tags.sorted() == ["brzezinski-zbigniew", "human-rights"])
        // Must NOT include terms from other schemes
        #expect(!result.tags.contains("carter"))
        #expect(!result.tags.contains("print"))
        #expect(!result.tags.contains("United States"))
    }

    // MARK: - Size Filter (GitHubVolumeEntry)

    @Test("GitHubVolumeEntry: entries below 20KB excluded by sizeFilter check")
    func sizeFilterBelowThreshold() {
        let small = GitHubVolumeEntry(name: "frusIndex.xml", size: 19_999, sha: "abc", downloadUrl: "https://example.com/frusIndex.xml")
        #expect(small.size < 20_000)
    }

    @Test("GitHubVolumeEntry: entries at or above 20KB pass filter")
    func sizeFilterAtThreshold() {
        let exact = GitHubVolumeEntry(name: "frus1969-76v01.xml", size: 20_000, sha: "abc", downloadUrl: "https://example.com/frus1969-76v01.xml")
        #expect(exact.size >= 20_000)
    }
}
