// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import FRUSExplorer

// MARK: - DecimalNeighbourSpaceTests

/// The whitespace mismatch that gave a decimal citation no archival neighbours at all.
///
/// ## The bug
/// `relatedByDecimal(ref:)` — the path the Source Explorer neighbours list takes for a
/// central-files note — matches `document_sources.series_name` against `location + "/%"`.
/// `DecimalFileSegment.location(from:)` **trims** the whitespace a citation may leave before
/// the item slash, while `series_name` stores the file number verbatim. So a note reading
/// `751G.5 MSP /10–553` is stored with that space, the trimmed prefix `751G.5 MSP/%` matches
/// none of its 41 siblings, and the document shows nothing.
///
/// Reported on `frus1952-54v13p1/d416`. 2,224 decimal rows (1.2%) carry the space.
///
/// These test the location derivation and the prefix arithmetic, which is what actually went
/// wrong; the SQL itself is exercised by the owner's index and the visual review.
///
/// Version history:
///   1.0 — Session 2026-08-05: #353 / N-1a follow-up
@Suite("Decimal neighbour spacing")
struct DecimalNeighbourSpaceTests {

    @Test("location() trims the space that series_name keeps")
    func locationTrimsWhatStorageKeeps() {
        // This asymmetry is the bug in one line: the two sides of the comparison disagree
        // about whether the space exists.
        #expect(DecimalFileSegment.location(from: "751G.5 MSP /10–553") == "751G.5 MSP")
        #expect(DecimalFileSegment.location(from: "751G.5 MSP/10–553") == "751G.5 MSP")
        #expect(DecimalFileSegment.location(from: "740.00119 EW /8–2644") == "740.00119 EW")
    }

    @Test("The spaced prefix matches a stored file number that keeps the space")
    func spacedPrefixMatchesStoredForm() {
        // A stand-in for the SQL `LIKE`: the pattern the query now also binds must match the
        // stored form. Only `location + " /%"` does.
        let stored = "751G.5 MSP /10–553"
        let location = DecimalFileSegment.location(from: stored)
        #expect(!stored.hasPrefix(location + "/"), "the shipped prefix cannot match — this is the bug")
        #expect(stored.hasPrefix(location + " /"), "the added prefix must match")
    }

    @Test("The unspaced form still matches, so the fix only adds")
    func unspacedFormUnaffected() {
        let stored = "611.61/1–2355"
        let location = DecimalFileSegment.location(from: stored)
        #expect(stored.hasPrefix(location + "/"))
    }

    @Test("Every affected shape in the corpus keys through the spaced prefix")
    func realCorpusShapes() {
        // The most affected locations, measured on the owner's index: 501. BC (183 rows),
        // 740.00119 EW (87), 357. AC (59), 396.1– ISG (56), 751.5 MSP (47), 751G.5 MSP (42).
        for stored in ["501. BC /1–2045", "740.00119 EW /8–2644", "357. AC /3–1148",
                       "396.1– ISG /5–1155", "751.5 MSP /2–355", "774.5 MSP /11–1253"] {
            let location = DecimalFileSegment.location(from: stored)
            #expect(stored.hasPrefix(location + " /"),
                    "\(stored) does not key through the spaced prefix")
            #expect(!location.hasSuffix(" "), "\(location) should already be trimmed")
        }
    }
}
