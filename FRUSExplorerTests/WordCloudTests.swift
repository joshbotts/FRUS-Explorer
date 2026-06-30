// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import CoreGraphics
import Foundation
import Testing
@testable import FRUSExplorer

// MARK: - WordCloudTokenizerTests

/// Verifies tokenisation, lemmatisation, and stopword filtering for the word-cloud
/// pipeline.
struct WordCloudTokenizerTests {

    @Test("WordCloudTokenizer: drops stopwords and short tokens, counts the rest")
    func filtersAndCounts() {
        let tokenizer = WordCloudTokenizer(stopwords: ["the", "and", "of"])
        var counts: [String: Int] = [:]
        let added = tokenizer.accumulate(
            from: "The treaty and the negotiation of the treaty.",
            into: &counts
        )
        // "the", "and", "of" are stopped; "a"/short words none here.
        #expect(counts["treaty"] == 2)
        #expect(counts["negotiation"] == 1)
        #expect(counts["the"] == nil)
        #expect(counts["and"] == nil)
        #expect(added == 3) // treaty, negotiation, treaty
    }

    @Test("WordCloudTokenizer: case-folds identical words into one bucket")
    func caseFolds() {
        let tokenizer = WordCloudTokenizer(stopwords: [])
        var counts: [String: Int] = [:]
        // Normalisation lowercases, so differing case must not fragment a term.
        tokenizer.accumulate(from: "Treaty treaty TREATY", into: &counts)
        #expect(counts["treaty"] == 3)
        #expect(counts.count == 1)
    }

    @Test("WordCloudTokenizer: rejects numbers and punctuation-only tokens")
    func rejectsNonAlphabetic() {
        let tokenizer = WordCloudTokenizer(stopwords: [])
        var counts: [String: Int] = [:]
        tokenizer.accumulate(from: "1969 42nd —— diplomacy 12/15", into: &counts)
        #expect(counts["1969"] == nil)
        #expect(counts["diplomacy"] == 1)
        // No purely numeric or symbolic tokens survive.
        #expect(counts.keys.allSatisfy { $0.contains(where: { $0.isLetter }) })
    }

    @Test("WordCloudTokenizer: singularize folds common plurals, spares exceptions")
    func singularizeRules() {
        #expect(WordCloudTokenizer.singularize("treaties") == "treaty")
        #expect(WordCloudTokenizer.singularize("policies") == "policy")
        #expect(WordCloudTokenizer.singularize("documents") == "document")
        #expect(WordCloudTokenizer.singularize("boxes") == "box")
        #expect(WordCloudTokenizer.singularize("churches") == "church")
        // Exceptions and risky endings are left alone.
        #expect(WordCloudTokenizer.singularize("series") == "series")
        #expect(WordCloudTokenizer.singularize("crisis") == "crisis")
        #expect(WordCloudTokenizer.singularize("congress") == "congress")
        #expect(WordCloudTokenizer.singularize("analysis") == "analysis")
    }

    @Test("WordCloudTokenizer: plural fold merges singular and plural counts")
    func pluralFoldMerges() {
        let tokenizer = WordCloudTokenizer(stopwords: [])
        var counts: [String: Int] = [:]
        tokenizer.accumulate(from: "treaty treaties treaties", into: &counts)
        #expect(counts["treaty"] == 3)
        #expect(counts["treaties"] == nil)
    }

    @Test("WordCloudTokenizer: folding can be disabled")
    func pluralFoldDisabled() {
        let tokenizer = WordCloudTokenizer(stopwords: [], foldPlurals: false)
        var counts: [String: Int] = [:]
        tokenizer.accumulate(from: "treaties", into: &counts)
        // With folding off and no lemma, the surface plural is kept.
        #expect(counts["treaties"] == 1)
    }

    @Test("WordCloudTokenizer: empty text contributes nothing")
    func emptyText() {
        let tokenizer = WordCloudTokenizer(stopwords: [])
        var counts: [String: Int] = [:]
        let added = tokenizer.accumulate(from: "", into: &counts)
        #expect(added == 0)
        #expect(counts.isEmpty)
    }
}

// MARK: - WordCloudStopwordsTests

/// Verifies the bundled stopword resource loads and layers correctly.
struct WordCloudStopwordsTests {

    @Test("WordCloudStopwords: English layer is non-empty and always active")
    func englishLayerLoads() {
        #expect(!WordCloudStopwords.english.isEmpty)
        #expect(WordCloudStopwords.english.contains("the"))
    }

    @Test("WordCloudStopwords: diplomatic layer only applies when requested")
    func diplomaticLayerOptional() {
        let withoutDiplomatic = WordCloudStopwords.active(includeDiplomatic: false)
        let withDiplomatic = WordCloudStopwords.active(includeDiplomatic: true)
        #expect(!withoutDiplomatic.contains("telegram"))
        #expect(withDiplomatic.contains("telegram"))
        #expect(withDiplomatic.isSuperset(of: withoutDiplomatic))
    }
}

// MARK: - WordCloudLayoutTests

/// Verifies the spiral packing produces non-overlapping, in-bounds placements with
/// frequency-proportional sizing.
struct WordCloudLayoutTests {

    private func sampleTerms() -> [TermCount] {
        [
            TermCount(term: "diplomacy", count: 100),
            TermCount(term: "treaty", count: 60),
            TermCount(term: "embassy", count: 40),
            TermCount(term: "summit", count: 20),
            TermCount(term: "accord", count: 5)
        ]
    }

    @Test("WordCloudLayout: most frequent term gets the largest font")
    func frequencyDrivesFontSize() {
        let placed = WordCloudLayout.place(
            terms: sampleTerms(), in: CGSize(width: 800, height: 600)
        )
        let byTerm = Dictionary(uniqueKeysWithValues: placed.map { ($0.term, $0.fontSize) })
        if let top = byTerm["diplomacy"], let bottom = byTerm["accord"] {
            #expect(top > bottom)
        } else {
            Issue.record("Expected both extreme terms to be placed")
        }
    }

    @Test("WordCloudLayout: placements stay within the canvas bounds")
    func staysInBounds() {
        let size = CGSize(width: 800, height: 600)
        let placed = WordCloudLayout.place(terms: sampleTerms(), in: size)
        #expect(!placed.isEmpty)
        for word in placed {
            #expect(word.center.x >= 0 && word.center.x <= size.width)
            #expect(word.center.y >= 0 && word.center.y <= size.height)
        }
    }

    @Test("WordCloudLayout: empty input yields no placements")
    func emptyInput() {
        let placed = WordCloudLayout.place(terms: [], in: CGSize(width: 400, height: 400))
        #expect(placed.isEmpty)
    }

    @Test("WordCloudLayout: zero-area canvas yields no placements")
    func zeroCanvas() {
        let placed = WordCloudLayout.place(terms: sampleTerms(), in: .zero)
        #expect(placed.isEmpty)
    }
}

// MARK: - WordCloudDiskCacheTests

/// Verifies the on-disk word-cloud cache round-trips and is fingerprint-sensitive.
struct WordCloudDiskCacheTests {

    private func sampleResult() -> WordCloudResult {
        WordCloudResult(
            terms: [TermCount(term: "diplomacy", count: 9), TermCount(term: "treaty", count: 4)],
            documentCount: 3, totalTokenCount: 42
        )
    }

    @Test("WordCloudDiskCache: saves and loads a result for the same key")
    func roundTrips() {
        let key = WordCloudDiskCache.key(
            signature: "test-\(UUID().uuidString)", limit: 100,
            includeDiplomatic: true, fingerprint: 7
        )
        WordCloudDiskCache.save(sampleResult(), key: key)
        let loaded = WordCloudDiskCache.load(key: key)
        #expect(loaded?.documentCount == 3)
        #expect(loaded?.totalTokenCount == 42)
        #expect(loaded?.terms.first?.term == "diplomacy")
        #expect(loaded?.terms.first?.count == 9)
    }

    @Test("WordCloudDiskCache: a changed fingerprint misses the cache")
    func fingerprintInvalidates() {
        let signature = "test-\(UUID().uuidString)"
        let key1 = WordCloudDiskCache.key(signature: signature, limit: 100,
                                          includeDiplomatic: true, fingerprint: 1)
        WordCloudDiskCache.save(sampleResult(), key: key1)
        // Same scope/params but a different index fingerprint → different key → miss.
        let key2 = WordCloudDiskCache.key(signature: signature, limit: 100,
                                          includeDiplomatic: true, fingerprint: 2)
        #expect(WordCloudDiskCache.load(key: key2) == nil)
    }
}

// MARK: - WordCloudScopeTests

/// Verifies scope signatures are stable and distinct.
struct WordCloudScopeTests {

    @Test("WordCloudScope: distinct scopes have distinct signatures")
    func distinctSignatures() {
        let id = UUID()
        let scopes: [WordCloudScope] = [
            .document(volumeId: "v1", documentId: "d1"),
            .volume(volumeId: "v1"),
            .subseries(subseriesId: "1969-76"),
            .corpus,
            .collection(id: id),
            .userTag(id: id),
            .savedSearch(id: id)
        ]
        let signatures = Set(scopes.map(\.signature))
        #expect(signatures.count == scopes.count)
    }

    @Test("WordCloudScope: signature is stable for equal scopes")
    func stableSignature() {
        #expect(WordCloudScope.volume(volumeId: "v1").signature
                == WordCloudScope.volume(volumeId: "v1").signature)
        #expect(WordCloudScope.corpus.id == "corpus")
    }

    @Test("WordCloudScope: reconstructs from its signature (round-trip)")
    func signatureRoundTrip() {
        let id = UUID()
        let scopes: [WordCloudScope] = [
            .document(volumeId: "frus1969-76v01", documentId: "d42"),
            .volume(volumeId: "frus1969-76v01"),
            .subseries(subseriesId: "1969-76"),
            .corpus,
            .collection(id: id),
            .userTag(id: id),
            .savedSearch(id: id),
            .dateRange(startISO: "1969-01-01", endISO: "1969-12-31")
        ]
        for scope in scopes {
            #expect(WordCloudScope(signature: scope.signature) == scope)
        }
    }

    @Test("WordCloudScope: rejects malformed signatures")
    func rejectsBadSignatures() {
        #expect(WordCloudScope(signature: "bogus") == nil)
        #expect(WordCloudScope(signature: "col:not-a-uuid") == nil)
        #expect(WordCloudScope(signature: "") == nil)
        #expect(WordCloudScope(signature: "daterange:1969-01-01") == nil)
        #expect(WordCloudScope(signature: "daterange:") == nil)
    }

    @Test("WordCloudScope: date-range signature encodes both ISO bounds")
    func dateRangeSignature() {
        let scope = WordCloudScope.dateRange(startISO: "1962-10-16", endISO: "1962-10-28")
        #expect(scope.signature == "daterange:1962-10-16..1962-10-28")
        // ISO day helpers round-trip through the canonical UTC formatter.
        let day = WordCloudScope.day(fromISO: "1962-10-16")
        #expect(day != nil)
        if let day { #expect(WordCloudScope.isoDay(from: day) == "1962-10-16") }
    }
}

// MARK: - WordCloudLensTests

/// Verifies the semantic-lens enum and that a part-of-speech lens narrows the
/// result to a subset of the all-terms tokens (it shares the same normalisation,
/// just adds a class filter — robust regardless of the tagger's exact accuracy).
struct WordCloudLensTests {

    @Test("WordCloudLens: entity lenses are flagged; all-cases present")
    func lensProperties() {
        #expect(WordCloudLens.people.isEntity)
        #expect(WordCloudLens.places.isEntity)
        #expect(WordCloudLens.organizations.isEntity)
        #expect(!WordCloudLens.allTerms.isEntity)
        #expect(!WordCloudLens.topics.isEntity)
        #expect(WordCloudLens.allCases.count == 9)
        for lens in WordCloudLens.allCases {
            #expect(!lens.label.isEmpty)
            #expect(!lens.systemImage.isEmpty)
        }
        // Signal-dependent lenses get an "insufficient signal" threshold; the
        // bread-and-butter lenses always display.
        #expect(WordCloudLens.concepts.isSignalDependent)
        #expect(WordCloudLens.sentiment.isSignalDependent)
        #expect(WordCloudLens.people.isSignalDependent)
        #expect(!WordCloudLens.allTerms.isSignalDependent)
        #expect(!WordCloudLens.topics.isSignalDependent)
        #expect(WordCloudLens.concepts.minimumSignalTerms > 0)
        #expect(WordCloudLens.allTerms.minimumSignalTerms == 0)
        // Only the sentiment lens recolours by polarity.
        #expect(WordCloudLens.sentiment.colorsBySentiment)
        #expect(!WordCloudLens.concepts.colorsBySentiment)
    }

    @Test("Tokenizer: concept lens keeps only lexicon terms")
    func conceptLensFiltersToLexicon() {
        let text = "The question of sovereignty and legitimacy shaped the kitchen table talk."
        var counts: [String: Int] = [:]
        WordCloudTokenizer(stopwords: [], lens: .concepts,
                           lexicon: WordCloudLexicons.concepts)
            .accumulate(from: text, into: &counts)
        // Concept words survive; ordinary nouns ("kitchen", "table") do not.
        #expect(counts["sovereignty"] != nil)
        #expect(counts["legitimacy"] != nil)
        #expect(counts["kitchen"] == nil)
        #expect(counts["table"] == nil)
        // Every surviving term is a member of the concept lexicon.
        for key in counts.keys { #expect(WordCloudLexicons.concepts.contains(key)) }
    }

    @Test("Tokenizer: sentiment lens keeps only polarity terms; lexicon polarity resolves")
    func sentimentLensFiltersAndPolarity() {
        let text = "The crisis brought conflict, but cooperation and peace offered hope."
        var counts: [String: Int] = [:]
        WordCloudTokenizer(stopwords: [], lens: .sentiment,
                           lexicon: WordCloudLexicons.sentimentAll)
            .accumulate(from: text, into: &counts)
        for key in counts.keys { #expect(WordCloudLexicons.sentimentAll.contains(key)) }
        #expect(WordCloudLexicons.polarity(of: "crisis") == .negative)
        #expect(WordCloudLexicons.polarity(of: "cooperation") == .positive)
        #expect(WordCloudLexicons.polarity(of: "kitchen") == nil)
        // The lens filter helper maps each lens to the right membership set.
        #expect(WordCloudLexicons.filter(for: .concepts) == WordCloudLexicons.concepts)
        #expect(WordCloudLexicons.filter(for: .sentiment) == WordCloudLexicons.sentimentAll)
        #expect(WordCloudLexicons.filter(for: .allTerms) == nil)
    }

    @Test("Tokenizer: entity terms are presented in Title Case")
    func entityTitleCasing() {
        // The name recogniser is best-effort; assert only that any surviving entity
        // key is title-cased (no all-lowercase words), never raw lowercase.
        var counts: [String: Int] = [:]
        WordCloudTokenizer(stopwords: [], lens: .places)
            .accumulate(from: "The delegation travelled from Washington to Geneva and back to Washington.",
                        into: &counts)
        for key in counts.keys {
            let firstWord = key.split(separator: " ").first.map(String.init) ?? key
            #expect(firstWord.first?.isUppercase == true)
        }
    }

    @Test("Tokenizer: topics (nouns) lens yields a subset of all-terms tokens")
    func topicsIsSubsetOfAllTerms() {
        let text = "The diplomats negotiated a difficult treaty in Geneva."
        var all: [String: Int] = [:]
        WordCloudTokenizer(stopwords: [], lens: .allTerms).accumulate(from: text, into: &all)
        var topics: [String: Int] = [:]
        WordCloudTokenizer(stopwords: [], lens: .topics).accumulate(from: text, into: &topics)
        // The POS filter can only remove tokens, never add or rename them.
        for key in topics.keys { #expect(all[key] != nil) }
        #expect(topics.count <= all.count)
    }

    @Test("Tokenizer: all-terms path unchanged (regression)")
    func allTermsRegression() {
        var counts: [String: Int] = [:]
        WordCloudTokenizer(stopwords: ["the", "a"], lens: .allTerms)
            .accumulate(from: "The treaty and a treaty.", into: &counts)
        #expect(counts["treaty"] == 2)
        #expect(counts["the"] == nil)
    }
}

// MARK: - WordCloudLayoutRotationTests

struct WordCloudLayoutRotationTests {

    private func sampleTerms(_ n: Int) -> [TermCount] {
        (0..<n).map { TermCount(term: "term\($0)word", count: 100 - $0) }
    }

    @Test("WordCloudLayout: placements are horizontal or vertical (0/90), and some rotate")
    func rotationAssignment() {
        let placed = WordCloudLayout.place(terms: sampleTerms(30),
                                           in: CGSize(width: 1000, height: 800))
        #expect(!placed.isEmpty)
        #expect(placed.allSatisfy { $0.rotationDegrees == 0 || $0.rotationDegrees == 90 })
        #expect(placed.contains { $0.rotationDegrees == 90 })   // vertical words exist
        #expect(placed.prefix(3).allSatisfy { $0.rotationDegrees == 0 }) // largest stay horizontal
    }

    @Test("WordCloudLayout: rotation assignment is deterministic across runs")
    func rotationDeterministic() {
        let size = CGSize(width: 900, height: 700)
        let a = WordCloudLayout.place(terms: sampleTerms(25), in: size)
        let b = WordCloudLayout.place(terms: sampleTerms(25), in: size)
        let aRot = Dictionary(uniqueKeysWithValues: a.map { ($0.term, $0.rotationDegrees) })
        for word in b { #expect(aRot[word.term] == word.rotationDegrees) }
    }
}

// MARK: - WordCloudCriteriaTests

/// Covers the criteria tightening: the bundled markings layer, markings filtering in
/// both the word and entity paths, and the tunable cache token.
struct WordCloudCriteriaTests {

    @Test("Markings layer loads from the bundle")
    func markingsLayerLoads() {
        #expect(WordCloudStopwords.markings.contains("top secret"))
        #expect(WordCloudStopwords.markings.contains("confidential"))
        #expect(WordCloudStopwords.markings.contains("priority"))
    }

    @Test("Tokenizer: markings drop document-chrome words from word lenses")
    func wordMarkingsExclude() {
        var counts: [String: Int] = [:]
        WordCloudTokenizer(stopwords: [], lens: .allTerms, markings: ["secret", "confidential"])
            .accumulate(from: "secret confidential treaty treaty", into: &counts)
        #expect(counts["secret"] == nil)
        #expect(counts["confidential"] == nil)
        #expect(counts["treaty"] == 2)
    }

    @Test("Tokenizer: markings can only remove an entity, never add one")
    func entityMarkingsExclude() {
        let text = "The delegation travelled to Paris for the talks."
        var plain: [String: Int] = [:]
        WordCloudTokenizer(stopwords: [], lens: .places)
            .accumulate(from: text, into: &plain)
        var filtered: [String: Int] = [:]
        WordCloudTokenizer(stopwords: [], lens: .places, markings: ["paris"])
            .accumulate(from: text, into: &filtered)
        #expect(filtered["Paris"] == nil)
        #expect(filtered.count <= plain.count)
    }

    @Test("Tokenizer: entity terms with digits are rejected")
    func entityRejectsDigits() {
        // A pure-digit / digit-bearing token must never count as a name even if the
        // recogniser tags it.
        var counts: [String: Int] = [:]
        WordCloudTokenizer(stopwords: [], lens: .organizations)
            .accumulate(from: "Article 19 and Resolution 242 were cited.", into: &counts)
        for key in counts.keys { #expect(!key.contains(where: { $0.isNumber })) }
    }

    @Test("Tuning cache token reflects each criterion")
    func tuningCacheToken() {
        let base = WordCloudTuning.standard.cacheToken
        #expect(WordCloudTuning(minimumLength: 5).cacheToken != base)
        #expect(WordCloudTuning(minimumCount: 3).cacheToken != base)
        #expect(WordCloudTuning(foldPlurals: false).cacheToken != base)
        #expect(WordCloudTuning(filterMarkings: false).cacheToken != base)
        #expect(WordCloudTuning.standard.filterMarkings) // markings on by default
    }
}

// MARK: - WordCloudSettingsStoreTests

/// Round-trips the user-managed stop lists and verifies the revision bump that
/// drives recompute.
struct WordCloudSettingsStoreTests {

    @Test("Settings store: global and per-lens stop lists round-trip and bump revision")
    func stopListRoundTrip() {
        let global = "zzqq-global-probe"
        let lensWord = "zzqq-lens-probe"
        // Start clean in case a prior run left state.
        WordCloudSettings.removeGlobalStopword(global)
        WordCloudSettings.removeLensStopword(lensWord, lens: .people)

        let beforeRevision = WordCloudSettings.revision
        WordCloudSettings.addGlobalStopword(global)
        #expect(WordCloudSettings.globalStopwords.contains(global))
        // The global list is shared by every lens's assembled extras.
        #expect(WordCloudSettings.extraStopwords(for: .topics).contains(global))
        #expect(WordCloudSettings.revision > beforeRevision)

        WordCloudSettings.addLensStopword(lensWord, lens: .people)
        #expect(WordCloudSettings.lensStopwords(.people).contains(lensWord))
        #expect(!WordCloudSettings.lensStopwords(.places).contains(lensWord))
        #expect(WordCloudSettings.extraStopwords(for: .people).contains(lensWord))
        #expect(!WordCloudSettings.extraStopwords(for: .places).contains(lensWord))

        // Cleanup.
        WordCloudSettings.removeGlobalStopword(global)
        WordCloudSettings.removeLensStopword(lensWord, lens: .people)
        #expect(!WordCloudSettings.globalStopwords.contains(global))
        #expect(!WordCloudSettings.lensStopwords(.people).contains(lensWord))
    }

    @Test("Settings store: tuning clamps to safe minimums")
    func tuningClamps() {
        // Defaults are sane even when nothing is stored.
        let tuning = WordCloudSettings.tuning
        #expect(tuning.minimumLength >= 2)
        #expect(tuning.minimumCount >= 1)
    }
}
