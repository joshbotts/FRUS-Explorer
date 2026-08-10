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

// MARK: - CitationBlockSplitterTests

/// Turning a pasted footnote block into citations (#263).
///
/// Version history:
///   1.0 — Session 2026-08-10: #263 (F-10)
@Suite("Citation block splitter (#263)")
struct CitationBlockSplitterTests {

    @Test("A numbered footnote list splits per marker")
    func numberedList() {
        let block = """
        1. Memorandum of Conversation, FRUS 1969–1976, vol. I, doc. 12.
        2. Telegram 1234 from Saigon, FRUS 1964–1968, vol. IV, doc. 305.
        3. Editorial Note, FRUS 1958–1960, vol. III, doc. 88.
        """
        let entries = CitationBlockSplitter.split(block)
        #expect(entries.count == 3)
        #expect(entries.map(\.marker) == ["1", "2", "3"])
        #expect(entries[0].text.hasPrefix("Memorandum of Conversation"),
                "the marker must be stripped before the parser sees it")
        #expect(entries.map(\.index) == [1, 2, 3])
    }

    @Test("A footnote wrapped across lines stays one citation")
    func wrappedFootnoteIsRejoined() {
        // The shape a two-column PDF or a narrow word-processor measure produces. Splitting per
        // line would yield three unparseable fragments instead of one good citation.
        let block = """
        1. Memorandum of Conversation, Washington, March 4, 1970,
        FRUS 1969–1976, vol. I,
        doc. 12.
        2. Editorial Note, FRUS 1958–1960, vol. III, doc. 88.
        """
        let entries = CitationBlockSplitter.split(block)
        #expect(entries.count == 2, "got \(entries.map(\.text))")
        #expect(entries[0].text.contains("vol. I"))
        #expect(entries[0].text.contains("doc. 12"))
        // Joined with a space, not a newline — the parser should see the citation as printed.
        #expect(!entries[0].text.contains("\n"))
    }

    @Test("Bracketed and parenthesised markers are recognised")
    func markerVariants() {
        #expect(CitationBlockSplitter.leadingMarker("[3] Editorial Note.") == "3")
        #expect(CitationBlockSplitter.leadingMarker("12) Telegram 5.") == "12")
        #expect(CitationBlockSplitter.leadingMarker("7. Memorandum.") == "7")
        #expect(CitationBlockSplitter.leadingMarker("Memorandum of Conversation.") == nil)
    }

    @Test("A citation opening with a year is not eaten as a marker")
    func yearIsNotAMarker() {
        // The reason the marker is bounded to three digits: an unbounded rule turns
        // "1969. Memorandum…" into marker 1969, and worse, silently removes the year.
        #expect(CitationBlockSplitter.leadingMarker("1969. Memorandum of Conversation.") == nil)
        let entries = CitationBlockSplitter.split("1969. Memorandum of Conversation, vol. I.")
        #expect(entries.count == 1)
        #expect(entries[0].text.hasPrefix("1969."), "the year must survive intact")
        #expect(entries[0].marker == nil)
    }

    @Test("An unmarked list is one citation per line")
    func unmarkedLinesEachStandAlone() {
        let block = """
        Memorandum of Conversation, FRUS 1969–1976, vol. I, doc. 12.
        Editorial Note, FRUS 1958–1960, vol. III, doc. 88.
        """
        let entries = CitationBlockSplitter.split(block)
        #expect(entries.count == 2)
        #expect(entries.allSatisfy { $0.marker == nil })
    }

    @Test("Blank lines separate citations under either rule")
    func blankLinesSeparate() {
        let marked = CitationBlockSplitter.split("1. First.\n\n2. Second.")
        #expect(marked.count == 2)
        let unmarked = CitationBlockSplitter.split("First citation.\n\n\nSecond citation.")
        #expect(unmarked.count == 2, "consecutive blank lines must not mint empty rows")
    }

    @Test("Empty and whitespace-only input yields nothing, not a blank row")
    func emptyInput() {
        #expect(CitationBlockSplitter.split("").isEmpty)
        #expect(CitationBlockSplitter.split("   \n\n  \t ").isEmpty)
    }

    @Test("A single citation with no marker is one entry")
    func singleCitation() {
        let entries = CitationBlockSplitter.split("FRUS 1969–1976, vol. I, doc. 12.")
        #expect(entries.count == 1)
        #expect(entries[0].index == 1)
    }

    @Test("Indices are contiguous from 1 regardless of blank lines")
    func indicesAreContiguous() {
        let entries = CitationBlockSplitter.split("1. A.\n\n\n2. B.\n\n3. C.")
        #expect(entries.map(\.index) == [1, 2, 3],
                "the table's order must match the paste even after blank lines")
    }
}

// MARK: - BatchCitationOutcomeTests

/// Classifying a batch row (#263).
///
/// Version history:
///   1.0 — Session 2026-08-10: #263 (F-10)
@Suite("Batch citation outcome (#263)")
struct BatchCitationOutcomeTests {

    private func match(rank: Int) -> CitationMatch {
        CitationMatch(documentId: "d\(rank)", volumeId: "frus1969-76v01", rank: rank,
                      matchStrategy: .exactDocumentNumber, confidenceLabel: "Exact",
                      correctionNote: nil, requiresDownload: false, volumeManifestEntry: nil)
    }

    @Test("Zero, one and many are three different answers")
    func classification() {
        #expect(BatchCitationOutcome.classify(matches: []) == .missing)
        #expect(BatchCitationOutcome.classify(matches: [match(rank: 1)]) == .resolved)
        #expect(BatchCitationOutcome.classify(matches: [match(rank: 1), match(rank: 2)])
                == .ambiguous(count: 2))
    }

    @Test("The ambiguous count is carried, because 3 and 12 are different problems")
    func ambiguousCarriesCount() {
        let many = (1...12).map { match(rank: $0) }
        #expect(BatchCitationOutcome.classify(matches: many) == .ambiguous(count: 12))
    }

    @Test("Triage order puts what needs work first")
    func triageOrder() {
        let ordered: [BatchCitationOutcome] = [
            .failed(reason: "x"), .missing, .ambiguous(count: 2), .resolved,
        ]
        #expect(ordered.map(\.triageOrder) == [0, 1, 2, 3])
        // The whole point of the table is finding what needs attention; resolved rows sort last.
        #expect(BatchCitationOutcome.resolved.triageOrder
                > BatchCitationOutcome.missing.triageOrder)
    }

    @Test("Failed is not missing")
    func failedIsDistinctFromMissing() {
        // "We looked and found nothing" and "we could not look" send a researcher to different
        // next steps — the first to a different volume, the second to fixing the citation text.
        #expect(BatchCitationOutcome.failed(reason: "unparseable") != .missing)
    }
}

// MARK: - BatchTriageSortTests

/// Worst-first ordering, and its stability (#263).
///
/// Version history:
///   1.0 — Session 2026-08-10: #263 (F-10)
@Suite("Batch triage sort (#263)")
struct BatchTriageSortTests {

    /// Mirrors `CitationLookupView.sortedBatchRows`. The view's copy needs an `@Environment`
    /// AppState and cannot be called from a test; this pins the rule the view applies.
    private func triageSorted(_ outcomes: [BatchCitationOutcome]) -> [Int] {
        outcomes.enumerated()
            .sorted {
                $0.element.triageOrder == $1.element.triageOrder
                    ? $0.offset < $1.offset
                    : $0.element.triageOrder < $1.element.triageOrder
            }
            .map(\.offset)
    }

    @Test("Unresolved rows come first, resolved last")
    func worstFirst() {
        let order = triageSorted([.resolved, .missing, .ambiguous(count: 2), .failed(reason: "x")])
        #expect(order == [3, 1, 2, 0], "got \(order)")
    }

    @Test("Rows in the same bucket keep paste order")
    func stableWithinBucket() {
        // Paste order is the reader's own footnote numbering. Two `missing` rows swapping places
        // between renders would make the table impossible to check against the manuscript.
        let order = triageSorted([.missing, .missing, .missing])
        #expect(order == [0, 1, 2])
        let mixed = triageSorted([.resolved, .missing, .resolved, .missing])
        #expect(mixed == [1, 3, 0, 2], "got \(mixed)")
    }
}
