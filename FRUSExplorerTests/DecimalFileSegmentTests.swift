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

/// Tests the decimal-file location/segment parsing that drives decimal-file archival
/// neighbors, using the exact examples from the feature definition.
struct DecimalFileSegmentTests {

    @Test("Location is the classification before the first slash")
    func location() {
        #expect(DecimalFileSegment.location(from: "711.654/11-543") == "711.654")
        #expect(DecimalFileSegment.location(from: "711.01/6-742") == "711.01")
        #expect(DecimalFileSegment.location(from: "862S.01") == "862S.01")  // no suffix
    }

    @Test("Suffix year is the last two digits of a date-form suffix")
    func suffixYear() {
        #expect(DecimalFileSegment.suffixYear(from: "711.654/11-543") == 1943)
        #expect(DecimalFileSegment.suffixYear(from: "711.654/3-1342") == 1942)
        #expect(DecimalFileSegment.suffixYear(from: "711.654/8-147") == 1947)
        #expect(DecimalFileSegment.suffixYear(from: "862S.01/10-1646") == 1946)
        // Sequential (pre-1940) suffix has no embedded year.
        #expect(DecimalFileSegment.suffixYear(from: "711.654/123") == nil)
        #expect(DecimalFileSegment.suffixYear(from: "711.654") == nil)
    }

    @Test("Years map to the correct decimal-file period segment")
    func segmentForYear() {
        #expect(DecimalFileSegment.segment(forYear: 1943) == "1940–1944")
        #expect(DecimalFileSegment.segment(forYear: 1942) == "1940–1944")
        #expect(DecimalFileSegment.segment(forYear: 1947) == "1945–1949")
        #expect(DecimalFileSegment.segment(forYear: 1925) == "1910–1929")
        #expect(DecimalFileSegment.segment(forYear: 1962) == "1960–1963")
        #expect(DecimalFileSegment.segment(forYear: 1905) == nil)  // outside decimal era
    }

    @Test("The feature's worked example resolves to the right neighbor verdicts")
    func workedExample() {
        // 711.654/11-543 (1943) is a neighbor of 711.654/3-1342 (1942) — same location, segment.
        let a = (DecimalFileSegment.location(from: "711.654/11-543"),
                 DecimalFileSegment.segment(for: "711.654/11-543", fallbackYear: nil))
        let b = (DecimalFileSegment.location(from: "711.654/3-1342"),
                 DecimalFileSegment.segment(for: "711.654/3-1342", fallbackYear: nil))
        let c = (DecimalFileSegment.location(from: "711.654/8-147"),
                 DecimalFileSegment.segment(for: "711.654/8-147", fallbackYear: nil))
        let d = (DecimalFileSegment.location(from: "711.01/6-742"),
                 DecimalFileSegment.segment(for: "711.01/6-742", fallbackYear: nil))
        #expect(a == b)        // neighbors
        #expect(a != c)        // different segment (1945–1949)
        #expect(a != d)        // different location
    }

    @Test("Pre-1940 sequential refs fall back to the document's own year")
    func sequentialFallback() {
        // "711.654/123" has no suffix year; the document's 1925 date places it in 1910–1929.
        #expect(DecimalFileSegment.segment(for: "711.654/123", fallbackYear: 1925) == "1910–1929")
        // No suffix year and no fallback → no segment (caller does location-only matching).
        #expect(DecimalFileSegment.segment(for: "711.654/123", fallbackYear: nil) == nil)
    }
}
