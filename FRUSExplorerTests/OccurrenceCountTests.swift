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

// MARK: - OccurrenceAvailabilityTests

/// Which query shapes can be counted by occurrence — the classification that decides whether a
/// number is shown at all.
///
/// Every unavailable case is a shape where an instance-mode count would be *wrong rather than
/// missing*, so the classification is the correctness boundary, not a convenience.
@Suite("Occurrence availability")
struct OccurrenceAvailabilityTests {

    /// A stem resolver that mimics SQLite's tokenizer for the fixtures used here.
    private func resolver(_ map: [String: String] = [:]) -> (String) -> String? {
        { word in map[word.lowercased()] ?? word.lowercased() }
    }

    @Test("A single word is countable, and carries the stem the tokenizer produced")
    func singleWordIsAvailable() {
        let a = OccurrenceAvailability.classify(term: "containment",
                                                resolveStem: resolver(["containment": "contain"]))
        #expect(a == .available(stem: "contain"))
        #expect(a.isAvailable)
        #expect(a.stem == "contain")
        #expect(a.reason == nil)
    }

    @Test("Exact-word is refused, and is checked BEFORE operand shape")
    func exactWordIsRefusedFirst() {
        // `=containment` parses as an ordinary word operand, so a shape-first classifier would call
        // it available and count the stem — reintroducing the exact defect PR-A removed from the
        // document numerator. Ordering is the assertion here.
        let a = OccurrenceAvailability.classify(term: "=containment",
                                                resolveStem: resolver(["containment": "contain"]))
        #expect(a.reason == .exactWord)
        #expect(!a.isAvailable)
        #expect(a.stem == nil, "An unavailable classification must not leak a countable stem")
    }

    @Test("Phrases, prefixes and proximity operands are refused as multi-term")
    func multiTermOperandsAreRefused() {
        for term in ["\"defense materials\"", "navig*", "NEAR(military europe, 5)"] {
            let a = OccurrenceAvailability.classify(term: term, resolveStem: resolver())
            #expect(a.reason == .multiTermOperand, "\(term) should be multiTermOperand, got \(String(describing: a.reason))")
        }
    }

    @Test("More than one positive operand is refused as composite, never summed")
    func compositeQueriesAreRefused() {
        for term in ["treaty alliance", "treaty OR alliance", "treaty AND alliance"] {
            let a = OccurrenceAvailability.classify(term: term, resolveStem: resolver())
            #expect(a.reason == .compositeQuery, "\(term) should be compositeQuery, got \(String(describing: a.reason))")
        }
    }

    @Test("A negated operand does not count as something to measure")
    func negationsAreNotCounted() {
        // One positive plus one negative is still a single measurable term.
        let mixed = OccurrenceAvailability.classify(term: "treaty -alliance", resolveStem: resolver())
        #expect(mixed == .available(stem: "treaty"),
                "The exclusion narrows the population but the countable term is still `treaty`")

        // Exclusions only: nothing positive exists to count.
        let onlyNegative = OccurrenceAvailability.classify(term: "-alliance", resolveStem: resolver())
        #expect(onlyNegative.reason == .noPositiveTerm)
    }

    @Test("A word the tokenizer cannot reduce to one term is refused")
    func multiTokenWordsAreRefused() {
        let a = OccurrenceAvailability.classify(term: "U.S.S.R.", resolveStem: { _ in nil })
        #expect(a.reason == .notASingleToken)
    }

    @Test("An empty query has nothing to count")
    func emptyQueryIsRefused() {
        #expect(OccurrenceAvailability.classify(term: "", resolveStem: resolver()).reason == .noPositiveTerm)
        #expect(OccurrenceAvailability.classify(term: "   ", resolveStem: resolver()).reason == .noPositiveTerm)
    }

    @Test("Every reason states something, and no two reasons say the same thing")
    func everyReasonExplainsItself() {
        var seen: Set<String> = []
        for reason in OccurrenceAvailability.Reason.allCases {
            let text = reason.explanation
            #expect(!text.isEmpty, "\(reason) has no explanation")
            // A reason that duplicates another's wording is a reason the UI cannot distinguish, which
            // defeats the point of carrying the reason at all rather than a bare `nil`.
            #expect(seen.insert(text).inserted, "\(reason) repeats another reason's wording")
        }
    }
}

// MARK: - OccurrenceCountServiceTests

/// The occurrence numerator against a real index, and the population invariants that decide whether
/// its numbers can sit beside the document counts.
@Suite("Occurrence counts over a real index")
struct OccurrenceCountServiceTests {

    @Test("Occurrences per year sum to the corpus total, and exceed the document count")
    func occurrencesSumToCorpusTotalAndExceedDocuments() async throws {
        try await withAnalyticsTempDir { dir in
            let (pipeline, store) = try await makeAnalyticsPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            // "treaty" three times in one 1971 document, once in another, none in a third.
            try writeAnalyticsVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [
                    ("d1", "<head>1. Memo</head><dateline><date when=\"1971-03-01\">March 1, 1971</date></dateline><p>The treaty was signed. A second treaty clause. A third treaty note.</p>"),
                    ("d2", "<head>2. Memo</head><dateline><date when=\"1972-06-01\">June 1, 1972</date></dateline><p>A treaty draft.</p>"),
                    ("d3", "<head>3. Memo</head><dateline><date when=\"1971-09-01\">Sept 1, 1971</date></dateline><p>Economic policy only.</p>"),
                ]
            )
            try await pipeline.indexVolume("frus1969-76v01")
            let service = CorpusAnalyticsService(fts5Store: store, pipeline: pipeline)

            let occurrences = try await service.termOccurrencesByYear(term: "treaty")
            let documents = try await service.termFrequencyByYear(term: "treaty")

            // 1971 holds one document with three occurrences; 1972 one with one.
            #expect(occurrences.first { $0.year == 1971 }?.count == 3)
            #expect(occurrences.first { $0.year == 1972 }?.count == 1)
            #expect(documents.first { $0.year == 1971 }?.count == 1)

            // PARITY against the cheap row-mode scalar — the invariant that catches a population or
            // scope mistake in the numerator. Asserting the series against itself would not.
            let stem = try #require(await service.occurrenceAvailability(for: "treaty").stem)
            let profile = try #require(await store.vocabularyEntry(stem: stem))
            #expect(occurrences.reduce(0) { $0 + $1.count } == profile.occurrences,
                    "Per-year occurrences must sum to fts5vocab's corpus total; a short sum means documents were dropped")

            // The invariant that catches a body-only or wrong-population numerator: a document
            // containing a term contains it at least once, so occurrences can never be fewer.
            let docsByYear = Dictionary(uniqueKeysWithValues: documents.map { ($0.year, $0.count) })
            for entry in occurrences {
                #expect(entry.count >= (docsByYear[entry.year] ?? 0),
                        "\(entry.year): \(entry.count) occurrences < \(docsByYear[entry.year] ?? 0) documents")
            }
        }
    }

    @Test("An UNDATED document's occurrences land in the volume start year, not nowhere")
    func undatedDocumentsUseTheVolumeStartYearFallback() async throws {
        try await withAnalyticsTempDir { dir in
            let (pipeline, store) = try await makeAnalyticsPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            // One dated 1919 document and one with NO date element at all, both containing the term.
            try writeAnalyticsVolume(
                to: volDir.appendingPathComponent("frus1919Parisv13.xml"),
                volumeId: "frus1919Parisv13",
                documents: [
                    ("d1", "<head>1. Memo</head><dateline><date when=\"1919-05-01\">May 1, 1919</date></dateline><p>A mandate question. Another mandate.</p>"),
                    ("d2", "<head>2. Undated memo</head><p>A mandate discussed at length: mandate, mandate, mandate.</p>"),
                ]
            )
            try await pipeline.indexVolume("frus1919Parisv13")
            let service = CorpusAnalyticsService(fts5Store: store, pipeline: pipeline)

            let occurrences = try await service.termOccurrencesByYear(term: "mandate")
            let stem = try #require(await service.occurrenceAvailability(for: "mandate").stem)
            let profile = try #require(await store.vocabularyEntry(stem: stem))

            // This is the trap the method is written around. A SQL `GROUP BY date_iso` would drop the
            // undated document's four occurrences while its DOCUMENT stayed in the other series —
            // manufacturing an "occurrences per document fell" trend, the mirror image of the CA-4 bug.
            #expect(occurrences.reduce(0) { $0 + $1.count } == profile.occurrences,
                    "Undated documents' occurrences must be bucketed at the volume start year, not discarded")
            #expect(occurrences.count == 1 && occurrences[0].year == 1919,
                    "Both documents belong to 1919 — the dated one by its date, the undated one by the volume's start year")
        }
    }

    @Test("The volume scope filters occurrences the same way it filters documents")
    func scopeAppliesToOccurrences() async throws {
        try await withAnalyticsTempDir { dir in
            let (pipeline, store) = try await makeAnalyticsPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            try writeAnalyticsVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [("d1", "<head>1. Memo</head><dateline><date when=\"1971-03-01\">March 1, 1971</date></dateline><p>A treaty, and another treaty.</p>")]
            )
            try writeAnalyticsVolume(
                to: volDir.appendingPathComponent("frus1969-76v02.xml"),
                volumeId: "frus1969-76v02",
                documents: [("d1", "<head>1. Memo</head><dateline><date when=\"1971-06-01\">June 1, 1971</date></dateline><p>A treaty mentioned once.</p>")]
            )
            try await pipeline.indexVolume("frus1969-76v01")
            try await pipeline.indexVolume("frus1969-76v02")
            let service = CorpusAnalyticsService(fts5Store: store, pipeline: pipeline)

            let all = try await service.termOccurrencesByYear(term: "treaty")
            #expect(all.first { $0.year == 1971 }?.count == 3, "Corpus-wide: 2 + 1")

            let scoped = try await service.termOccurrencesByYear(
                term: "treaty", volumeIds: ["frus1969-76v01"])
            #expect(scoped.first { $0.year == 1971 }?.count == 2,
                    "Scoped to v01 the count must drop to that volume's 2 — an unscoped numerator beside a scoped document count is the same class of lie as an unscoped denominator")
        }
    }

    @Test("An un-countable query returns no series, and says why")
    func uncountableQueriesReturnNothingAndExplain() async throws {
        try await withAnalyticsTempDir { dir in
            let (pipeline, store) = try await makeAnalyticsPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            try writeAnalyticsVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [("d1", "<head>1. Memo</head><dateline><date when=\"1971-03-01\">March 1, 1971</date></dateline><p>The containment doctrine and a treaty.</p>")]
            )
            try await pipeline.indexVolume("frus1969-76v01")
            let service = CorpusAnalyticsService(fts5Store: store, pipeline: pipeline)

            // Control: the countable form does produce a series, so the assertions below are about
            // the query shape and not about a fixture that matches nothing.
            #expect(!(try await service.termOccurrencesByYear(term: "treaty")).isEmpty)

            for term in ["=containment", "\"containment doctrine\"", "contain*",
                         "treaty OR containment", "NEAR(containment treaty, 5)"] {
                let series = try await service.termOccurrencesByYear(term: term)
                #expect(series.isEmpty, "\(term) must yield no occurrence series")
                let availability = await service.occurrenceAvailability(for: term)
                #expect(availability.reason != nil,
                        "\(term) must carry a REASON — an empty series with no reason is indistinguishable from a zero count")
            }
        }
    }
}
