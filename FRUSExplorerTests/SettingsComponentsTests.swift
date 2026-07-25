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

// MARK: - StorageUsageBreakdownTests

/// Tests the usage bar's arithmetic (S-2a).
///
/// The view is a few rectangles; the part that can be wrong is the maths — and its awkward cases
/// are all real states of this app. A fresh install has no bytes at all, summaries are zero until
/// the first summary is generated, and a device that has downloaded but not indexed has one
/// segment carrying everything.
struct StorageUsageBreakdownTests {

    @Test("Shares are proportional and sum to one")
    func proportionalShares() {
        let b = StorageUsageBreakdown.make(volumeBytes: 100, indexBytes: 280, summaryBytes: 20)
        #expect(b.totalBytes == 400)
        #expect(b.segments.count == 3)
        #expect(abs(b.segments.reduce(0) { $0 + $1.share } - 1.0) < 0.0001)
        #expect(abs((b.segments.first { $0.id == "xml" }?.share ?? 0) - 0.25) < 0.0001)
        #expect(abs((b.segments.first { $0.id == "index" }?.share ?? 0) - 0.70) < 0.0001)
    }

    /// Summaries are zero until the user generates one — by far the most common real state — and a
    /// zero-width segment would draw as a hairline artifact and add a meaningless legend entry.
    @Test("A zero-byte segment is dropped, not drawn at zero width")
    func zeroSegmentDropped() {
        let b = StorageUsageBreakdown.make(volumeBytes: 100, indexBytes: 280, summaryBytes: 0)
        #expect(b.segments.count == 2)
        #expect(!b.segments.contains { $0.id == "summaries" })
        #expect(abs(b.segments.reduce(0) { $0 + $1.share } - 1.0) < 0.0001)
    }

    /// Fresh install: nothing stored. The bar must report empty so the caller can omit it rather
    /// than render an empty track, and nothing may divide by zero.
    @Test("An all-zero report is empty and divides by nothing")
    func freshInstall() {
        let b = StorageUsageBreakdown.make(volumeBytes: 0, indexBytes: 0, summaryBytes: 0)
        #expect(b.isEmpty)
        #expect(b.totalBytes == 0)
        #expect(b.segments.isEmpty)
    }

    /// Downloaded but not yet indexed — one segment holds the whole bar.
    @Test("A single non-zero segment takes the full width")
    func singleSegment() {
        let b = StorageUsageBreakdown.make(volumeBytes: 512, indexBytes: 0, summaryBytes: 0)
        #expect(b.segments.count == 1)
        #expect(abs(b.segments[0].share - 1.0) < 0.0001)
        #expect(!b.isEmpty)
    }

    /// Defensive: a negative figure from a failed measurement must not produce a negative width.
    @Test("Negative input is clamped to zero")
    func negativeClamped() {
        let b = StorageUsageBreakdown.make(volumeBytes: -50, indexBytes: 100, summaryBytes: 0)
        #expect(b.totalBytes == 100)
        #expect(b.segments.count == 1)
        #expect(b.segments[0].id == "index")
    }

    @Test("Segments keep their declared draw order")
    func drawOrder() {
        let b = StorageUsageBreakdown.make(volumeBytes: 1, indexBytes: 1, summaryBytes: 1)
        #expect(b.segments.map(\.id) == ["xml", "index", "summaries"])
    }
}

// MARK: - LibraryStatusSummaryTests

/// Tests the hub hero's status sentence (S-2a).
///
/// This one line is what a reader checks to know where their library stands, so each state has to
/// read correctly — including the two that are easy to get wrong: nothing downloaded at all, and
/// everything downloaded but something interrupted.
struct LibraryStatusSummaryTests {

    @Test("The settled happy path reads as designed")
    func happyPath() {
        let s = LibraryStatusSummary(downloadedCount: 12, catalogCount: 540,
                                     indexedCount: 12, interruptedCount: 0)
        #expect(s.text == "12 of 540 downloaded · all indexed · nothing needs attention")
        #expect(!s.needsAttention)
    }

    /// A partially-indexed library names the remainder, because that is the number the
    /// "Index Remaining" action acts on.
    @Test("A partly-indexed library names how many remain")
    func partiallyIndexed() {
        let s = LibraryStatusSummary(downloadedCount: 12, catalogCount: 540,
                                     indexedCount: 9, interruptedCount: 0)
        #expect(s.text.contains("3 not yet indexed"))
        #expect(!s.text.contains("all indexed"))
    }

    /// Fresh install: "0 of 0 indexed" would be vacuous, so the clause changes shape.
    @Test("An empty library does not claim an index state it cannot have")
    func emptyLibrary() {
        let s = LibraryStatusSummary(downloadedCount: 0, catalogCount: 540,
                                     indexedCount: 0, interruptedCount: 0)
        #expect(s.text == "0 of 540 downloaded · nothing indexed yet")
        // No attention clause at all when there is nothing to attend to.
        #expect(!s.text.contains("needs attention"))
        #expect(!s.needsAttention)
    }

    /// Interruptions replace the reassurance clause and flip the hero's tint.
    @Test("Interrupted volumes are surfaced and flag attention")
    func interrupted() {
        let s = LibraryStatusSummary(downloadedCount: 12, catalogCount: 540,
                                     indexedCount: 10, interruptedCount: 2)
        #expect(s.text.contains("2 needs attention"))
        #expect(!s.text.contains("nothing needs attention"))
        #expect(s.needsAttention)
    }

    /// Indexed can legitimately exceed downloaded (a volume removed while its index rows linger
    /// until the next vacuum); that must read as "all indexed", not as a negative remainder.
    @Test("Indexed exceeding downloaded still reads as fully indexed")
    func indexedExceedsDownloaded() {
        let s = LibraryStatusSummary(downloadedCount: 5, catalogCount: 540,
                                     indexedCount: 7, interruptedCount: 0)
        #expect(s.text.contains("all indexed"))
        #expect(!s.text.contains("-2"))
    }

    /// The clause order is the designed reading order: scale, then searchability, then trouble.
    @Test("Clauses stay in the designed order")
    func clauseOrder() {
        let s = LibraryStatusSummary(downloadedCount: 3, catalogCount: 540,
                                     indexedCount: 1, interruptedCount: 1)
        let parts = s.text.components(separatedBy: " · ")
        #expect(parts.count == 3)
        #expect(parts[0].contains("downloaded"))
        #expect(parts[1].contains("not yet indexed"))
        #expect(parts[2].contains("needs attention"))
    }
}
