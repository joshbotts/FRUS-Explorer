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

// MARK: - WordCloudBenchTests

/// Tests the Word Cloud settings bench (S-5b) — the "Keeps N of M terms" arithmetic and the
/// canned sample it falls back to.
///
/// The point of the bench is that a threshold visibly costs something. These tests are mostly
/// assertions that each control actually moves the number, which is exactly the property that
/// failed the first time it was built: the sample was the *head* of a cached cloud, where every
/// count is in the hundreds, so no threshold could touch it.
struct WordCloudBenchTests {

    private func evaluate(_ sample: [TermCount],
                          minLength: Int = 3,
                          minCount: Int = 1,
                          filterMarkings: Bool = true,
                          includeDiplomatic: Bool = true,
                          extraStopwords: Set<String> = [],
                          lens: WordCloudLens = .allTerms) -> WordCloudBench {
        WordCloudBench.evaluate(
            sample: sample,
            tuning: WordCloudTuning(minimumLength: minLength,
                                    minimumCount: minCount,
                                    foldPlurals: true,
                                    filterMarkings: filterMarkings),
            lens: lens,
            includeDiplomatic: includeDiplomatic,
            extraStopwords: extraStopwords,
            isFromUserCorpus: false)
    }

    // MARK: - The controls bite

    /// Raising the minimum length must drop terms, or the control is decoration.
    @Test("Minimum length removes shorter terms")
    func minimumLengthBites() {
        let sample = [TermCount(term: "war", count: 10),
                      TermCount(term: "treaty", count: 10),
                      TermCount(term: "negotiation", count: 10)]
        #expect(evaluate(sample, minLength: 3).keptCount == 3)
        #expect(evaluate(sample, minLength: 4).keptCount == 2)
        #expect(evaluate(sample, minLength: 7).keptCount == 1)
        #expect(evaluate(sample, minLength: 20).keptCount == 0)
    }

    /// The occurrence threshold applies to the sample's own counts.
    @Test("Minimum occurrences removes low-count terms")
    func minimumCountBites() {
        let sample = [TermCount(term: "treaty", count: 9),
                      TermCount(term: "armistice", count: 4),
                      TermCount(term: "blockade", count: 1)]
        #expect(evaluate(sample, minCount: 1).keptCount == 3)
        #expect(evaluate(sample, minCount: 5).keptCount == 1)
        #expect(evaluate(sample, minCount: 10).keptCount == 0)
    }

    /// A word the user has hidden must not appear in the preview of what is kept.
    @Test("The user's hidden words are removed")
    func hiddenWordsBite() {
        let sample = [TermCount(term: "treaty", count: 9), TermCount(term: "armistice", count: 9)]
        #expect(evaluate(sample).keptCount == 2)
        let trimmed = evaluate(sample, extraStopwords: ["treaty"])
        #expect(trimmed.keptCount == 1)
        #expect(trimmed.kept.first?.term == "armistice")
    }

    /// Classification markings are what the markings filter exists to remove. "confidential" is
    /// pinned as present in the bundled markings layer by `WordCloudCriteriaTests`.
    @Test("The markings filter removes classification chrome")
    func markingsBite() {
        let sample = [TermCount(term: "confidential", count: 9),
                      TermCount(term: "armistice", count: 9)]
        #expect(evaluate(sample, filterMarkings: true, includeDiplomatic: false).keptCount == 1)
        #expect(evaluate(sample, filterMarkings: false, includeDiplomatic: false).keptCount == 2)
    }

    /// Multi-word markings only ever reach a cloud through the entity path — the word path
    /// rejects anything containing a space before the markings check is even consulted. That is
    /// exactly the false positive the filter was written for ("Top Secret" tagged as a place),
    /// so it is worth pinning at the grain where it happens.
    @Test("Multi-word markings are dropped from entity lenses")
    func multiWordMarkingsInEntityLenses() {
        let sample = [TermCount(term: "top secret", count: 9), TermCount(term: "havana", count: 9)]
        let filtered = evaluate(sample, filterMarkings: true,
                                includeDiplomatic: false, lens: .places)
        #expect(filtered.keptCount == 1)
        #expect(filtered.kept.first?.term == "havana")
        #expect(evaluate(sample, filterMarkings: false,
                         includeDiplomatic: false, lens: .places).keptCount == 2)
    }

    /// The diplomatic-boilerplate layer is opt-in and strictly additive; "telegram" is its probe
    /// word, pinned by `WordCloudStopwordsTests`.
    @Test("The diplomatic layer removes boilerplate")
    func diplomaticLayerBites() {
        let sample = [TermCount(term: "telegram", count: 9), TermCount(term: "armistice", count: 9)]
        #expect(evaluate(sample, includeDiplomatic: true).keptCount == 1)
        #expect(evaluate(sample, includeDiplomatic: false).keptCount == 2)
    }

    // MARK: - Agreement with the tokenizer

    /// The bench must not claim a term survives when the cloud would drop it. Both sides run the
    /// same predicate; this pins that they are wired to the same one.
    @Test("Kept terms are exactly those the tokenizer accepts")
    func agreesWithTokenizer() {
        let sample = WordCloudBench.canonicalSample
        let tuning = WordCloudTuning(minimumLength: 5, minimumCount: 2,
                                     foldPlurals: true, filterMarkings: true)
        let tokenizer = WordCloudTokenizer.configured(
            tuning: tuning, lens: .allTerms, includeDiplomatic: true, extraStopwords: [])
        let bench = WordCloudBench.evaluate(sample: sample, tuning: tuning, lens: .allTerms,
                                            includeDiplomatic: true, extraStopwords: [],
                                            isFromUserCorpus: false)
        let expected = sample.filter { $0.count >= 2 && tokenizer.accepts($0.term.lowercased()) }
        #expect(bench.kept == expected)
    }

    // MARK: - The canned sample

    /// The fallback sample exists to make every control visibly move. If it stops doing that it
    /// has stopped earning its place, so each claim in its doc comment is asserted here.
    @Test("The canned sample exercises every control")
    func cannedSampleIsUseful() {
        let sample = WordCloudBench.canonicalSample
        let baseline = evaluate(sample, minLength: 3, minCount: 1,
                                filterMarkings: false, includeDiplomatic: false)

        #expect(evaluate(sample, minLength: 5, minCount: 1,
                         filterMarkings: false, includeDiplomatic: false).keptCount
                < baseline.keptCount, "minimum length does not bite the canned sample")
        #expect(evaluate(sample, minLength: 3, minCount: 3,
                         filterMarkings: false, includeDiplomatic: false).keptCount
                < baseline.keptCount, "minimum occurrences does not bite the canned sample")
        #expect(evaluate(sample, minLength: 3, minCount: 1,
                         filterMarkings: true, includeDiplomatic: false).keptCount
                < baseline.keptCount, "the markings filter does not bite the canned sample")
        #expect(evaluate(sample, minLength: 3, minCount: 1,
                         filterMarkings: false, includeDiplomatic: true).keptCount
                < baseline.keptCount, "the diplomatic layer does not bite the canned sample")
    }

    /// Under the shipped defaults the sample must still show *something* — a preview that is
    /// empty out of the box would read as a broken feature.
    @Test("The canned sample keeps terms under the default criteria")
    func cannedSampleSurvivesDefaults() {
        let bench = WordCloudBench.evaluate(
            sample: WordCloudBench.canonicalSample,
            tuning: .standard,
            lens: .allTerms,
            includeDiplomatic: true,
            extraStopwords: [],
            isFromUserCorpus: false)
        #expect(bench.keptCount > 5)
        #expect(bench.sampleSize == WordCloudBench.canonicalSample.count)
    }

    // MARK: - Copy

    /// The consequence line names both numbers and scopes itself to the sample.
    @Test("The summary reports kept and total")
    func summaryWording() {
        let bench = WordCloudBench(kept: [TermCount(term: "treaty", count: 1)],
                                   sampleSize: 4, isFromUserCorpus: false)
        #expect(bench.summary == "Keeps 1 of 4 terms in this sample")
        #expect(bench.droppedCount == 3)
    }

    /// Before the first read there is nothing to report, and the line must not claim "0 of 0".
    @Test("An unloaded bench says it is still measuring")
    func pendingWording() {
        #expect(WordCloudBench.empty.summary == "Measuring…")
        #expect(WordCloudBench.empty.sampleSize == 0)
    }

    /// The provenance line must distinguish the user's own terms from the stand-in, or the
    /// numbers read as a corpus statistic when they are not.
    @Test("Provenance distinguishes real terms from the stand-in")
    func provenanceWording() {
        let mine = WordCloudBench(kept: [], sampleSize: 1, isFromUserCorpus: true)
        let canned = WordCloudBench(kept: [], sampleSize: 1, isFromUserCorpus: false)
        #expect(mine.provenance != canned.provenance)
        #expect(mine.provenance.contains("your most recent"))
    }
}
