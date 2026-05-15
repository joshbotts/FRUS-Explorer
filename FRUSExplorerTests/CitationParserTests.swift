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

// MARK: - CitationParserTests

struct CitationParserTests {

    private let parser = CitationParser()

    // MARK: - FullCitationTest

    @Test("CitationParserTest: parse history.state.gov recommended style")
    func fullCitationTest() {
        let raw = "Foreign Relations of the United States, 1969–1976, Volume I, Foundations of Foreign Policy, 1969–1972, eds. David Patterson (Washington: GPO, 2003), Document 15."
        let result = parser.parse(raw)
        #expect(result.subseries == "1969-76")
        #expect(result.volumeNumber == "I")
        #expect(result.documentNumber == 15)
        #expect(result.parserConfidence == .high)
    }

    // MARK: - ChicagoShortTest

    @Test("CitationParserTest: parse Chicago short footnote")
    func chicagoShortTest() {
        let raw = "FRUS, 1969–76, I, doc. 15"
        let result = parser.parse(raw)
        #expect(result.subseries == "1969-76")
        #expect(result.volumeNumber == "I")
        #expect(result.documentNumber == 15)
        #expect(result.pageNumber == nil)
    }

    // MARK: - ChicagoFullTest

    @Test("CitationParserTest: parse Chicago full footnote with page number")
    func chicagoFullTest() {
        let raw = "Foreign Relations of the United States, 1969–1976, vol. I, doc. 15, p. 47"
        let result = parser.parse(raw)
        #expect(result.subseries == "1969-76")
        #expect(result.volumeNumber == "I")
        #expect(result.documentNumber == 15)
        #expect(result.pageNumber == 47)
    }

    // MARK: - PageOnlyTest

    @Test("CitationParserTest: parse page-only citation (no document number)")
    func pageOnlyTest() {
        let raw = "FRUS, 1952–1954, vol. XIV, p. 847"
        let result = parser.parse(raw)
        #expect(result.subseries == "1952-54")
        #expect(result.pageNumber == 847)
        #expect(result.documentNumber == nil)
    }

    // MARK: - InformalTest

    @Test("CitationParserTest: parse informal citation with Arabic volume and 'no.' prefix")
    func informalTest() {
        let raw = "FRUS 1969-76, vol. 1, no. 15"
        let result = parser.parse(raw)
        #expect(result.subseries == "1969-76")
        // Arabic "1" should be normalized to Roman "I"
        #expect(result.volumeNumber == "I")
        #expect(result.documentNumber == 15)
    }

    // MARK: - HyphenVariantTest

    @Test("CitationParserTest: hyphen, en dash, and full-year variants all extract same subseries")
    func hyphenVariantTest() {
        let hyphen    = parser.extractSubseries(from: "FRUS 1969-76, vol. I")
        let enDash    = parser.extractSubseries(from: "FRUS 1969–76, vol. I")
        let fullYear  = parser.extractSubseries(from: "FRUS 1969–1976, vol. I")

        #expect(hyphen == "1969-76")
        #expect(enDash == "1969-76")
        #expect(fullYear == "1969-76")
        #expect(hyphen == enDash)
        #expect(hyphen == fullYear)
    }

    // MARK: - VolumeNormalizationTest

    @Test("CitationParserTest: 'vol. I', 'v. I', 'vol. 1', 'Volume I' all normalize to 'I'")
    func volumeNormalizationTest() {
        let forms = [
            "FRUS, 1969–76, vol. I, doc. 1",
            "FRUS, 1969–76, v. I, doc. 1",
            "FRUS, 1969–76, vol. 1, doc. 1",
            "FRUS, 1969–76, Volume I, doc. 1",
        ]
        let volumes = forms.compactMap { parser.extractVolumeNumber(from: $0) }
        #expect(volumes.count == 4, "Expected all 4 forms to parse")
        let unique = Set(volumes)
        #expect(unique.count == 1, "Expected all forms to normalize to the same value, got \(unique)")
        #expect(unique.first == "I")
    }

    // MARK: - MalformedTest

    @Test("CitationParserTest: malformed/OCR-corrupted citation still extracts partial fields")
    func malformedTest() {
        // Simulated OCR artifact: missing comma, extra spaces, wrong en-dash encoding
        let raw = "Foreign Relations United States 1969 1976  vol I  doc15"
        let result = parser.parse(raw)
        // Should extract year even from malformed text
        #expect(result.subseries != nil || result.volumeNumber != nil || result.documentNumber != nil,
                "Expected at least one field extracted from malformed text")
        // Confidence should reflect poor parse
        #expect(result.parserConfidence == .low || result.parserConfidence == .medium)
    }

    // MARK: - RealTimeTest

    @Test("CitationParserTest: incremental parsing — final result matches full parse")
    func realTimeTest() {
        let full = "FRUS, 1969–76, vol. I, doc. 15"
        let finalResult = parser.parse(full)

        // Parse progressively longer substrings — none should crash
        for end in stride(from: 1, through: full.count, by: 1) {
            let idx = full.index(full.startIndex, offsetBy: end)
            let partial = String(full[..<idx])
            let _ = parser.parse(partial) // must not crash
        }

        #expect(finalResult.subseries == "1969-76")
        #expect(finalResult.documentNumber == 15)
    }

    // MARK: - SingleYearTest

    @Test("CitationParserTest: single-year subseries (e.g. 1861) is extracted correctly")
    func singleYearSubseriesTest() {
        let result = parser.parse("FRUS 1861, vol. I, doc. 3")
        #expect(result.subseries == "1861")
    }

    // MARK: - VolumeXIVTest

    @Test("CitationParserTest: multi-digit Roman numeral volume XIV extracted correctly")
    func volumeXIVTest() {
        let vol = parser.extractVolumeNumber(from: "FRUS, 1952–54, vol. XIV, p. 847")
        #expect(vol == "XIV")
    }
}
