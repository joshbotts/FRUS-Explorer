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

// MARK: - BrowseCorporaTests

/// Pure-logic tests for the working-corpora browse axis and its R-3 document drill
/// (#1051 B-4, A-6): the per-volume grouping, the three-tier date ordering, the
/// degraded-row action decider, and the three-state truncation disclosure.
///
/// Version history:
///   1.0 — #1051 B-4: initial implementation
struct BrowseCorporaTests {

    // MARK: Grouping

    @Test func volumeSectionsGroupByVolumeInIdOrderAndSkipMalformedKeys() {
        let sections = CorporaAxis.volumeSections(from: [
            "frus1969-76v01/d5",
            "frus1861/d2",
            "frus1969-76v01/d1",
            "malformed-no-slash",
            "frus1861/d9",
        ])
        #expect(sections.map(\.volumeId) == ["frus1861", "frus1969-76v01"])
        #expect(sections[0].documents.map(\.documentId).sorted() == ["d2", "d9"])
        #expect(sections[1].documents.map(\.documentId).sorted() == ["d1", "d5"])
        // The malformed key is skipped, never invented into a row.
        #expect(sections.flatMap(\.documents).count == 4)
    }

    @Test func documentIdsMayThemselvesContainSlashes() {
        // maxSplits: 1 — only the FIRST separator splits, so an exotic id survives whole.
        let sections = CorporaAxis.volumeSections(from: ["frus1861/d2/appendix"])
        #expect(sections.first?.documents.first?.documentId == "d2/appendix")
    }

    // MARK: The three-tier date order (the Collections precedent)

    @Test func perDocumentDateBeatsVolumeDateBeatsSentinel() {
        #expect(CorporaAxis.sortKey(dateISO: "1969-03-01", volumeEarliest: "1861-01-01")
                == "1969-03-01")
        #expect(CorporaAxis.sortKey(dateISO: nil, volumeEarliest: "1861-01-01") == "1861-01-01")
        #expect(CorporaAxis.sortKey(dateISO: nil, volumeEarliest: nil) == "9999")
    }

    @Test func orderedSortsByDate_idOrderWouldInvertIt() {
        // Ids ASCEND against date, so an id sort gives the opposite order — only the
        // date rule yields chronology.
        let refs = [
            CorporaAxis.DocumentRef(key: "v/dA", volumeId: "v", documentId: "dA"),
            CorporaAxis.DocumentRef(key: "v/dB", volumeId: "v", documentId: "dB"),
        ]
        let ordered = CorporaAxis.ordered(refs,
                                          dates: ["v/dA": "1970-01-01", "v/dB": "1961-01-01"],
                                          volumeEarliest: nil)
        #expect(ordered.map(\.documentId) == ["dB", "dA"])
    }

    @Test func orderedTieBreaksByDocumentId_datesEqualSoOnlyIdDecides() {
        let refs = [
            CorporaAxis.DocumentRef(key: "v/dZ", volumeId: "v", documentId: "dZ"),
            CorporaAxis.DocumentRef(key: "v/dA", volumeId: "v", documentId: "dA"),
        ]
        let ordered = CorporaAxis.ordered(refs, dates: [:], volumeEarliest: "1950-01-01")
        #expect(ordered.map(\.documentId) == ["dA", "dZ"])
    }

    @Test func datelessDocumentsSinkBehindDatedOnes() {
        let refs = [
            CorporaAxis.DocumentRef(key: "v/dA", volumeId: "v", documentId: "dA"),
            CorporaAxis.DocumentRef(key: "v/dB", volumeId: "v", documentId: "dB"),
        ]
        // dA has no per-document date and the volume has none either → sentinel; dB dated.
        let ordered = CorporaAxis.ordered(refs, dates: ["v/dB": "1970-01-01"],
                                          volumeEarliest: nil)
        #expect(ordered.map(\.documentId) == ["dB", "dA"])
    }

    // MARK: The R-3 action decider

    @Test func rowStateFollowsVolumeMembershipNeverHeaders() {
        #expect(CorporaAxis.rowState(volumeIndexed: true, volumeDownloaded: true) == .open)
        // Indexed beats a missing file check — indexedness is the openability oracle.
        #expect(CorporaAxis.rowState(volumeIndexed: true, volumeDownloaded: false) == .open)
        #expect(CorporaAxis.rowState(volumeIndexed: false, volumeDownloaded: true) == .needsIndex)
        #expect(CorporaAxis.rowState(volumeIndexed: false, volumeDownloaded: false) == .needsDownload)
    }

    // MARK: Truncation disclosure (three states, never two)

    @Test func truncationLineStatesAllThreeCases() {
        // Interpolated Ints localize with grouping separators ("7,500") in the test host.
        let line = CorporaAxis.truncationLine(.truncated(total: 9212), documentCount: 7500)
        #expect(line?.contains(7500.formatted()) == true)
        #expect(line?.contains(9212.formatted()) == true)
        #expect(CorporaAxis.truncationLine(.truncated(total: nil), documentCount: 7500) != nil)
        #expect(CorporaAxis.truncationLine(.complete, documentCount: 100) == nil)
        // Unrecorded is said out loud, never collapsed into complete.
        #expect(CorporaAxis.truncationLine(.unrecorded, documentCount: 100) != nil)
    }

    // MARK: Captions

    @Test func rowCaptionPrefersSourceDescriptionOverQuery() {
        let described = WorkingCorpus(name: "A", documentKeys: ["v/d1"],
                                      sourceQuery: "berlin", sourceDescription: "Search results")
        #expect(CorporaAxis.rowCaption(described).contains("Search results"))
        #expect(!CorporaAxis.rowCaption(described).contains("berlin"))
        let queried = WorkingCorpus(name: "B", documentKeys: ["v/d1"], sourceQuery: "berlin")
        #expect(CorporaAxis.rowCaption(queried).contains("berlin"))
    }

    @Test func untitledCorporaGetThePlaceholderName() {
        let corpus = WorkingCorpus(name: "", documentKeys: [])
        #expect(!CorporaAxis.displayName(corpus).isEmpty)
    }
}
