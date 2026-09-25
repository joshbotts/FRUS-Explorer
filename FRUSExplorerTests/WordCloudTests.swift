// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import CoreGraphics
import Foundation
import NaturalLanguage
import SwiftUI
import Testing
#if canImport(UIKit)
import UIKit
#endif
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
        // A nonsense plural guarantees the lemmatiser has no entry, isolating the
        // fold-disabled fallback path. (A real word like "treaties" is unreliable
        // here: whether NLTagger lemmatises a bare token varies with the OS's
        // NaturalLanguage assets, and a lemma always wins regardless of the flag.)
        tokenizer.accumulate(from: "zorbeliers", into: &counts)
        // With folding off and no lemma, the surface plural is kept.
        #expect(counts["zorbeliers"] == 1)
        #expect(counts["zorbelier"] == nil)
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

/// Removes disk-cache entries a test wrote into the host's real `Caches/WordCloud/`, and records an
/// issue for any that survives (#1373 review round 3).
///
/// An entry left behind is not inert: the Word Cloud settings bench samples the newest All-terms
/// entry it finds there (`WordCloudDiskCache.mostRecent(lens:where:)`), so a planted test cloud
/// could stand in for the reader's own. Every test that writes an entry calls this in a `defer`.
func discardWordCloudDiskEntries(_ keys: [String], sourceLocation: SourceLocation = #_sourceLocation) {
    for key in keys {
        WordCloudDiskCache.remove(key: key)
        #expect(WordCloudDiskCache.load(key: key) == nil,
                "a test left its word-cloud disk-cache entry behind", sourceLocation: sourceLocation)
    }
}

/// Verifies the on-disk word-cloud cache round-trips and is fingerprint-sensitive, and that every
/// entry these tests write is taken out again.
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
        defer { discardWordCloudDiskEntries([key]) }
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
        defer { discardWordCloudDiskEntries([key1]) }
        WordCloudDiskCache.save(sampleResult(), key: key1)
        // Same scope/params but a different index fingerprint → different key → miss.
        let key2 = WordCloudDiskCache.key(signature: signature, limit: 100,
                                          includeDiplomatic: true, fingerprint: 2)
        #expect(WordCloudDiskCache.load(key: key2) == nil)
    }

    @Test("WordCloudDiskCache: remove takes an entry out, so a test can leave nothing behind (#1373)")
    func removeTakesTheEntryOut() {
        let key = WordCloudDiskCache.key(signature: "test-remove-\(UUID().uuidString)", limit: 100,
                                         includeDiplomatic: true, fingerprint: 7)
        WordCloudDiskCache.save(sampleResult(), key: key)
        #expect(WordCloudDiskCache.load(key: key) != nil, "control: the entry was not written")
        WordCloudDiskCache.remove(key: key)
        #expect(WordCloudDiskCache.load(key: key) == nil, "remove(key:) left the entry on disk")
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
            .savedSearch(id: id),
            .customScope(id: id),
            .subjectCategory(category: "Warfare", subcategory: nil),
            .subjectCategory(category: "Warfare", subcategory: "Vietnam Conflict")
        ]
        // The UUID-backed cases share one id on purpose: distinctness must come
        // from the signature PREFIX, so a collection and a custom scope with the
        // same underlying UUID can never collide in a cache.
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
            .customScope(id: id),
            .dateRange(startISO: "1969-01-01", endISO: "1969-12-31"),
            .subjectCategory(category: "Warfare", subcategory: nil),
            .subjectCategory(category: "Warfare", subcategory: "Vietnam Conflict"),
            // A category label containing a colon must survive: init splits on the FIRST
            // ":" (the prefix), so the value can carry any subsequent ":" or "/".
            .subjectCategory(category: "Politico-Military: Arms", subcategory: "SALT/ABM")
        ]
        for scope in scopes {
            #expect(WordCloudScope(signature: scope.signature) == scope)
        }
    }

    @Test("WordCloudScope: rejects malformed signatures")
    func rejectsBadSignatures() {
        #expect(WordCloudScope(signature: "bogus") == nil)
        #expect(WordCloudScope(signature: "col:not-a-uuid") == nil)
        #expect(WordCloudScope(signature: "scope:not-a-uuid") == nil)
        #expect(WordCloudScope(signature: "") == nil)
        #expect(WordCloudScope(signature: "daterange:1969-01-01") == nil)
        #expect(WordCloudScope(signature: "daterange:") == nil)
    }

    /// #258 Phase 5: the custom-scope signature encodes the RECORD id (reference,
    /// never a copied member list), so the precompute queue and result caches key on
    /// it and a deleted record simply resolves to an explicitly empty cloud.
    @Test("WordCloudScope: custom-scope signature encodes the record id")
    func customScopeSignature() {
        let id = UUID()
        let scope = WordCloudScope.customScope(id: id)
        #expect(scope.signature == "scope:\(id.uuidString)")
        #expect(WordCloudScope(signature: scope.signature) == scope)
    }

    /// #308 Phase 1 (F6): the subject-category signature carries the category and, when
    /// present, the sub-category joined by U+001F (a delimiter absent from taxonomy labels).
    /// A whole-category scope carries no delimiter; both round-trip.
    @Test("WordCloudScope: subject-category signature encodes category and optional sub-category")
    func subjectCategorySignature() {
        let whole = WordCloudScope.subjectCategory(category: "Warfare", subcategory: nil)
        #expect(whole.signature == "subject:Warfare")
        #expect(WordCloudScope(signature: whole.signature) == whole)

        let pair = WordCloudScope.subjectCategory(category: "Warfare", subcategory: "Vietnam Conflict")
        #expect(pair.signature == "subject:Warfare\u{1f}Vietnam Conflict")
        #expect(WordCloudScope(signature: pair.signature) == pair)

        // An empty trailing sub-category segment ("subject:Cat␟") decodes to the whole
        // category, never a subcategory of "".
        #expect(WordCloudScope(signature: "subject:Warfare\u{1f}")
                == .subjectCategory(category: "Warfare", subcategory: nil))
        // An empty category is rejected.
        #expect(WordCloudScope(signature: "subject:") == nil)
    }

    @Test("WordCloudScope: date-range signature encodes both ISO bounds")
    func dateRangeSignature() {
        let scope = WordCloudScope.dateRange(startISO: "1962-10-16", endISO: "1962-10-28")
        #expect(scope.signature == "daterange:1962-10-16..1962-10-28")
        // ISO day helpers round-trip through the local-calendar formatter.
        let day = WordCloudScope.day(fromISO: "1962-10-16")
        #expect(day != nil)
        if let day {
            #expect(WordCloudScope.isoDay(from: day) == "1962-10-16")
            // The parsed Date must be a *local* start of day: every consumer
            // (DatePickers, Chronology's startOfDay normalisation) works in the
            // local calendar, so a UTC-anchored Date would shift the displayed
            // and re-encoded day for non-UTC users.
            #expect(Calendar.current.startOfDay(for: day) == day)
            #expect(WordCloudScope.isoDay(from: Calendar.current.startOfDay(for: day)) == "1962-10-16")
        }
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

    @Test("Tokenizer: topics (nouns) lens yields a subset of all-terms tokens, and not an empty one")
    func topicsIsSubsetOfAllTerms() {
        let text = "The diplomats negotiated a difficult treaty in Geneva."
        // All terms FIRST, on purpose: on the iOS 27.0 simulators a process whose first tagging
        // is the lemma scheme lost every noun for the rest of its life (#1373). Since the gate this
        // test is never the process's first tagging — the canary is, after the warm-up the app
        // starts at launch — so the order no longer decides anything here; it is kept as the order
        // #1373 was found in. `taggerReadsTheVerdictBeforeItBuilds` is what pins the gate.
        var all: [String: Int] = [:]
        WordCloudTokenizer(stopwords: [], lens: .allTerms).accumulate(from: text, into: &all)
        var topics: [String: Int] = [:]
        WordCloudTokenizer(stopwords: [], lens: .topics).accumulate(from: text, into: &topics)
        // The POS filter can only remove tokens, never add or rename them.
        for key in topics.keys { #expect(all[key] != nil) }
        #expect(topics.count <= all.count)
        // Both assertions above hold for an EMPTY result, which is how #1373 passed this test.
        Self.expectKeepsSomething(topics, lens: .topics, text: text)
    }

    /// A sentence per lens, dense in what the lens keeps.
    static let obviousSentences: [(WordCloudLens, String)] = [
        (.actions, "The ministers negotiated, signed and ratified the treaty, then departed."),
        (.descriptors, "The difficult, protracted and bitter negotiations produced a fragile, temporary settlement."),
        (.people, "President Eisenhower met Prime Minister Churchill and Secretary Dulles."),
        (.places, "The delegation travelled from Washington to Geneva, then to Paris and Moscow."),
        (.organizations, "The United Nations, NATO and the World Bank debated the proposal."),
    ]

    @Test("Tokenizer: each part-of-speech and entity lens keeps something from a sentence full of it (#1373)",
          arguments: obviousSentences)
    func lensKeepsObviousMembers(lens: WordCloudLens, text: String) {
        var counts: [String: Int] = [:]
        WordCloudTokenizer(stopwords: [], lens: lens).accumulate(from: text, into: &counts)
        Self.expectKeepsSomething(counts, lens: lens, text: text)
    }

    /// #1373's assertion, stated for the device it runs on.
    ///
    /// **Where the warm-up's request for the scheme this lens reads answered `available`** — the
    /// lexical classes for Topics, Actions and Descriptors, the name recogniser for the entity
    /// lenses — the lens must keep something. That is the guard: on the pre-fix tree the same
    /// non-empty assertion failed in the app for Topics, Actions and Descriptors on both iOS 27.0
    /// simulators (iPad Pro 13-inch (M5), iPhone 17e), the process's first tagging having been a
    /// lemma. On iOS 27.0 those two requests answered `available` in every launch whose warm-up line
    /// was recorded — the first attempt's 28 and review round 1's 75 (counted from their printed
    /// lines in review round 3), all on one iPhone 17e simulator — including the 26 that lost their
    /// lemmatiser, so the guard held on every run recorded there. It cannot fail on the iOS 26
    /// simulators, where nothing tags at all and, since #1373's review round 1, the warm-up does not
    /// ask for the assets (it records `notAsked`).
    ///
    /// **Where it did not answer, or was not asked** — iOS 26 — the lens must keep something exactly
    /// when the canary says it is supported, which is what lets the Word Cloud say "unavailable on this device"
    /// instead of drawing a zero. That is a real assertion there too: a canary claiming support on
    /// iOS 26.3 would fail it.
    static func expectKeepsSomething(_ counts: [String: Int], lens: WordCloudLens, text: String) {
        let verdict = NaturalLanguageReadiness.current
        let scheme: NLTagScheme = lens.isEntity ? .nameType : .lexicalClass
        if verdict.warmUp.answeredAvailable(for: scheme) {
            #expect(!counts.isEmpty, """
                \(lens.rawValue) kept nothing from “\(text)” although the \(scheme.rawValue) request \
                answered available — canary: \(verdict.health)
                """)
        } else {
            #expect(counts.isEmpty == !verdict.health.supports(lens), """
                \(lens.rawValue): the canary says supported=\(verdict.health.supports(lens)) but the \
                tokenizer kept \(counts) — assets: \(verdict.warmUp.assetRequests)
                """)
        }
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

/// `WordCloudResult.visibleTerms(excluding:)` — the pure filter behind the #233
/// non-persistent "Hide in this word cloud" action.
struct WordCloudSessionHideTests {

    private func result() -> WordCloudResult {
        WordCloudResult(
            terms: [
                TermCount(term: "Diplomacy", count: 100),
                TermCount(term: "treaty", count: 60),
                TermCount(term: "Embassy", count: 40),
            ],
            documentCount: 5,
            totalTokenCount: 200
        )
    }

    @Test("visibleTerms: empty hidden set returns the terms unchanged (identity)")
    func emptyHiddenReturnsAll() {
        let r = result()
        let visible = r.visibleTerms(excluding: [])
        #expect(visible.map(\.term) == ["Diplomacy", "treaty", "Embassy"])
    }

    @Test("visibleTerms: hiding is case-insensitive on the bare term")
    func caseInsensitive() {
        let r = result()
        // Hidden words are stored lowercased; a differently-cased term still drops.
        let visible = r.visibleTerms(excluding: ["diplomacy", "embassy"])
        #expect(visible.map(\.term) == ["treaty"])
    }

    @Test("visibleTerms: preserves order and count of the surviving terms")
    func preservesOrderAndCount() {
        let r = result()
        let visible = r.visibleTerms(excluding: ["treaty"])
        #expect(visible.map(\.term) == ["Diplomacy", "Embassy"])
        #expect(visible.map(\.count) == [100, 40])
    }

    @Test("visibleTerms: a hidden word not present is a no-op")
    func unknownHiddenIsNoOp() {
        let r = result()
        let visible = r.visibleTerms(excluding: ["summit"])
        #expect(visible.count == r.terms.count)
    }

    @Test("visibleTerms: hiding everything visible yields an empty list")
    func hideAll() {
        let r = result()
        let visible = r.visibleTerms(excluding: ["diplomacy", "treaty", "embassy"])
        #expect(visible.isEmpty)
    }
}

// MARK: - #1373: what the Word Cloud shows when a lens keeps nothing

/// `WordCloudDisplayState.resolve` — the decision `WordCloudView`'s body renders from.
///
/// Pure, so it fails on any destination. Against the pre-#1373 decision (an empty result reached
/// the "No Terms" screen only under All terms, and fell through to the cloud canvas otherwise) the
/// first test failed for Topics, Actions and Descriptors — the three lenses that are not
/// signal-dependent, so nothing else caught their zero.
struct WordCloudDisplayStateTests {

    private func result(terms: Int, documents: Int, analysis: NaturalLanguageHealth? = .fullyWorking)
    -> WordCloudResult {
        var r = WordCloudResult(
            terms: (0..<terms).map { TermCount(term: "term\($0)word", count: 100 - $0) },
            documentCount: documents, totalTokenCount: terms * 10)
        r.languageAnalysis = analysis
        return r
    }

    private func resolve(_ result: WordCloudResult, lens: WordCloudLens,
                         analysis: NaturalLanguageHealth? = .fullyWorking,
                         service: Bool = true, loading: Bool = false,
                         error: String? = nil) -> WordCloudDisplayState {
        WordCloudDisplayState.resolve(serviceAvailable: service, isLoading: loading,
                                      errorMessage: error, result: result, lens: lens,
                                      languageAnalysis: analysis)
    }

    /// A tagger that lost its lexical classes and kept everything else.
    private static let unclassified = NaturalLanguageHealth(lemmatizes: true, classifiesWords: false,
                                                            recognizesNames: true)

    /// The decision half of the plan's view-state test; `WordCloudMainAreaRenderTests` renders it.
    @Test("Zero terms from more than zero documents is never the terms state, under any lens or verdict")
    func zeroTermsFromDocumentsIsNeverTheTermsState() {
        let verdicts: [NaturalLanguageHealth?] = [
            nil, .fullyWorking,
            NaturalLanguageHealth(lemmatizes: false, classifiesWords: true, recognizesNames: true),
            NaturalLanguageHealth(lemmatizes: true, classifiesWords: false, recognizesNames: true),
            NaturalLanguageHealth(lemmatizes: true, classifiesWords: true, recognizesNames: false),
        ]
        var checked = 0
        for lens in WordCloudLens.allCases {
            for verdict in verdicts {
                let state = resolve(result(terms: 0, documents: 4_591), lens: lens, analysis: verdict)
                #expect(state != .terms,
                        "\(lens.rawValue) under \(String(describing: verdict)) would draw an empty canvas")
                checked += 1
            }
        }
        #expect(checked == WordCloudLens.allCases.count * verdicts.count)
    }

    @Test("A working tagger's empty result from documents is 'no terms', named for the lens")
    func workingTaggerEmptyIsNoTerms() {
        for lens in WordCloudLens.allCases {
            #expect(resolve(result(terms: 0, documents: 12), lens: lens) == .noTerms(lens))
        }
    }

    @Test("No indexed documents is its own screen, under every lens")
    func noDocumentsIsNoIndexedText() {
        for lens in WordCloudLens.allCases {
            #expect(resolve(result(terms: 0, documents: 0), lens: lens) == .noIndexedText)
        }
        // Before the verdict has settled too: an empty scope is empty whatever the tagger does.
        #expect(resolve(result(terms: 0, documents: 0), lens: .topics, analysis: nil) == .noIndexedText)
    }

    @Test("A lens the tagger cannot serve says so — before the empty checks, since it was never counted")
    func unsupportedLensIsUnavailable() {
        let nameless = NaturalLanguageHealth(lemmatizes: true, classifiesWords: true, recognizesNames: false)
        let unclassified = NaturalLanguageHealth(lemmatizes: true, classifiesWords: false, recognizesNames: true)
        for lens in [WordCloudLens.people, .places, .organizations] {
            // `.empty` is what `load()` leaves for a lens it did not compute: 0 documents, which the
            // no-indexed-text check would otherwise have blamed on the scope.
            #expect(resolve(.empty, lens: lens, analysis: nameless) == .lensUnavailable(lens, nameless))
            #expect(resolve(.empty, lens: lens, analysis: unclassified) == .noIndexedText)
        }
        for lens in [WordCloudLens.topics, .actions, .descriptors] {
            #expect(resolve(.empty, lens: lens, analysis: unclassified) == .lensUnavailable(lens, unclassified))
            #expect(resolve(.empty, lens: lens, analysis: nameless) == .noIndexedText)
        }
        // No lemmatiser leaves every lens available: it counts printed forms instead.
        let unlemmatised = NaturalLanguageHealth(lemmatizes: false, classifiesWords: true, recognizesNames: true)
        for lens in WordCloudLens.allCases {
            #expect(resolve(result(terms: 30, documents: 9), lens: lens, analysis: unlemmatised) == .terms)
        }
    }

    @Test("An unavailable lens's message offers exactly the lenses the failure in hand leaves working (#1373)")
    func unavailableMessageOffersTheLensesThatStillWork() {
        // The two taggers fail independently, so which lenses still work depends on which one
        // failed: without names, Topics, Actions and Descriptors still draw; without lexical
        // classes, People, Places and Organizations do; without either, only the three lenses that
        // read neither. A fixed list — "All terms, Concepts and Sentiment" — was right only for
        // the third shape. Two lenses per shape, and each case checks every other lens both ways.
        let nameless = NaturalLanguageHealth(lemmatizes: true, classifiesWords: true, recognizesNames: false)
        let neither = NaturalLanguageHealth(lemmatizes: false, classifiesWords: false, recognizesNames: false)
        let cases: [(lens: WordCloudLens, health: NaturalLanguageHealth, working: Set<WordCloudLens>)] = [
            (.people, nameless, [.allTerms, .topics, .actions, .descriptors, .concepts, .sentiment]),
            (.organizations, nameless, [.allTerms, .topics, .actions, .descriptors, .concepts, .sentiment]),
            (.topics, Self.unclassified, [.allTerms, .people, .places, .organizations, .concepts, .sentiment]),
            (.descriptors, Self.unclassified, [.allTerms, .people, .places, .organizations, .concepts, .sentiment]),
            (.places, neither, [.allTerms, .concepts, .sentiment]),
            (.actions, neither, [.allTerms, .concepts, .sentiment]),
        ]
        for (lens, health, working) in cases {
            let message = WordCloudDisplayState.lensUnavailableDetail(for: lens, health: health)
            // The lens in hand is named once, in quotation marks; what is left is the offer.
            let quoted = "“\(lens.label)”"
            #expect(message.components(separatedBy: quoted).count == 2,
                    "\(lens.rawValue): the message must name the lens it cannot draw once — \(message)")
            let offer = message.replacingOccurrences(of: quoted, with: "")
            for other in WordCloudLens.allCases where other != lens {
                #expect(offer.contains(other.label) == working.contains(other),
                        "\(lens.rawValue) under \(health): \(other.label) \(working.contains(other) ? "still works and is not offered" : "does not work and is offered") — \(message)")
            }
            // Which tagger failed is the lens's own, so the explanation follows the lens.
            #expect(message.contains(lens.isEntity ? "recognizing names" : "nouns, verbs and adjectives"),
                    "\(lens.rawValue): \(message)")
        }
    }

    @Test("An unknown verdict never reports a lens unavailable — it has not been measured yet")
    func unknownVerdictIsNotUnavailable() {
        for lens in WordCloudLens.allCases {
            #expect(resolve(result(terms: 30, documents: 9), lens: lens, analysis: nil) == .terms)
        }
    }

    @Test("A few terms under a signal-dependent lens is 'not enough signal'; one term elsewhere is a cloud")
    func signalThresholdStillApplies() {
        for lens in WordCloudLens.allCases {
            let state = resolve(result(terms: 1, documents: 9), lens: lens)
            #expect(state == (lens.isSignalDependent ? .insufficientSignal(lens) : .terms),
                    "\(lens.rawValue): \(state)")
        }
        #expect(resolve(result(terms: WordCloudLens.people.minimumSignalTerms, documents: 9),
                        lens: .people) == .terms)
    }

    @Test("Service, loading and failure come first, in that order")
    func wholeScreenStatesComeFirst() {
        let r = result(terms: 0, documents: 9)
        #expect(resolve(r, lens: .topics, service: false, loading: true, error: "x") == .serviceUnavailable)
        #expect(resolve(r, lens: .topics, loading: true, error: "x") == .loading)
        #expect(resolve(r, lens: .topics, error: "x") == .failed("x"))
    }

    @Test("Only the whole-screen states drop the lens chips: an empty or unavailable lens keeps them")
    func chromeFramesEveryLensState() {
        #expect(WordCloudDisplayState.lensUnavailable(.topics, Self.unclassified).showsCloudChrome)
        #expect(WordCloudDisplayState.noTerms(.topics).showsCloudChrome)
        #expect(WordCloudDisplayState.insufficientSignal(.people).showsCloudChrome)
        #expect(WordCloudDisplayState.terms.showsCloudChrome)
        #expect(!WordCloudDisplayState.serviceUnavailable.showsCloudChrome)
        #expect(!WordCloudDisplayState.loading.showsCloudChrome)
        #expect(!WordCloudDisplayState.failed("x").showsCloudChrome)
        #expect(!WordCloudDisplayState.noIndexedText.showsCloudChrome)
    }

    @Test("Every lens's 'nothing found' message is its own, and says the documents were read")
    func noTermsMessagesAreWordedForTheLens() {
        let messages = WordCloudLens.allCases.map { WordCloudDisplayState.noTermsDetail(for: $0) }
        #expect(Set(messages).count == WordCloudLens.allCases.count, "two lenses share a message")
        for message in messages {
            #expect(message.contains("were read"),
                    "a 'nothing found' message must say the documents WERE read: \(message)")
            #expect(!message.contains("no indexed text"))
        }
    }

    @Test("The header hides its count only for a lens that was never counted")
    func headerCountHiddenOnlyForUnavailableLens() {
        #expect(WordCloudDisplayState.lensUnavailable(.topics, Self.unclassified).isLensUnavailable)
        #expect(!WordCloudDisplayState.noTerms(.topics).isLensUnavailable)
        #expect(!WordCloudDisplayState.terms.isLensUnavailable)
    }

    @Test("'Counted as printed' shows exactly for a word lens whose own stamp says the lemmatiser failed")
    func countedAsPrintedConditions() {
        let unlemmatised = NaturalLanguageHealth(lemmatizes: false, classifiesWords: true, recognizesNames: true)
        // The one case that shows it…
        #expect(WordCloudDisplayState.countedAsPrinted(result(terms: 5, documents: 2, analysis: unlemmatised),
                                               lens: .allTerms))
        // …and one fixture per condition that withholds it.
        #expect(!WordCloudDisplayState.countedAsPrinted(result(terms: 5, documents: 2, analysis: unlemmatised),
                                                lens: .people),
                "entity lenses never lemmatise, so the caption would say nothing true")
        #expect(!WordCloudDisplayState.countedAsPrinted(result(terms: 5, documents: 2, analysis: .fullyWorking),
                                                lens: .allTerms))
        #expect(!WordCloudDisplayState.countedAsPrinted(result(terms: 5, documents: 2, analysis: nil),
                                                lens: .allTerms),
                "an unstamped result is unknown, not unlemmatised")
        #expect(!WordCloudDisplayState.countedAsPrinted(result(terms: 0, documents: 2, analysis: unlemmatised),
                                                lens: .allTerms),
                "nothing was counted, so there is nothing to caption")
    }

    @Test("Every surface's 'counted as printed' wording appears exactly when the rule says so, and says what it means")
    func countedAsPrintedWordingFollowsTheRule() {
        let unlemmatised = NaturalLanguageHealth(lemmatizes: false, classifiesWords: true, recognizesNames: true)
        let wordings: [(String, (WordCloudResult, WordCloudLens) -> String?)] = [
            ("header note", WordCloudDisplayState.countedAsPrintedNote),
            ("CSV caveat", WordCloudDisplayState.countedAsPrintedCaveat),
            ("image caption segment", WordCloudDisplayState.countedAsPrintedCaptionSegment),
            ("collection plate line", WordCloudDisplayState.countedAsPrintedPlateLine),
        ]
        let cases: [(WordCloudResult, WordCloudLens)] = [
            (result(terms: 5, documents: 2, analysis: unlemmatised), .allTerms),
            (result(terms: 5, documents: 2, analysis: unlemmatised), .concepts),
            (result(terms: 5, documents: 2, analysis: unlemmatised), .people),
            (result(terms: 5, documents: 2, analysis: .fullyWorking), .allTerms),
            (result(terms: 5, documents: 2, analysis: nil), .allTerms),
            (result(terms: 0, documents: 2, analysis: unlemmatised), .allTerms),
        ]
        var shown = 0
        for (name, wording) in wordings {
            for (counted, lens) in cases {
                let text = wording(counted, lens)
                #expect((text != nil) == WordCloudDisplayState.countedAsPrinted(counted, lens: lens),
                        "\(name) under \(lens.rawValue): \(String(describing: text))")
                if let text {
                    shown += 1
                    #expect(text.localizedCaseInsensitiveContains("counted as printed"),
                            "\(name) must name the method: \(text)")
                }
            }
        }
        // Two cases show it (All terms and Concepts counted without lemmas), for each of four wordings.
        #expect(shown == 8)
        // The CSV caveat is the one a reader meets without the app: it has to say what differs.
        let caveat = WordCloudDisplayState.countedAsPrintedCaveat(
            result(terms: 5, documents: 2, analysis: unlemmatised), lens: .allTerms) ?? ""
        #expect(caveat.contains("dictionary forms") && caveat.contains("cannot be compared"), "\(caveat)")
    }

    @Test("The header's count line is withheld only for a lens that was never counted")
    func headerCountLineWithheldOnlyForUnavailableLens() {
        #expect(WordCloudDisplayState.headerCountLine(for: .lensUnavailable(.topics, Self.unclassified), shownTerms: 0,
                                                      documentCount: 0) == nil)
        for state: WordCloudDisplayState in [.noTerms(.topics), .insufficientSignal(.people), .terms] {
            let line = WordCloudDisplayState.headerCountLine(for: state, shownTerms: 12, documentCount: 4_591)
            #expect(line?.contains("12") == true && line?.contains("4591") == true,
                    "\(state): \(String(describing: line))")
        }
    }
}

// MARK: - #1373: what the main area actually draws

/// Renders `WordCloudMainArea` — the view `WordCloudView` draws its main area with — and looks at the
/// pixels, so the test sees what is drawn and not only the decision (#1373).
///
/// The terms surface is a magenta fill no system view draws. #1373's blank panel was the terms
/// surface drawn for a state with nothing to draw; here it would show as magenta. And a state that
/// drew nothing at all would be a blank panel too, so each empty state must also put ink down.
///
/// Rendered in a window of the test host's scene, through UIKit's `drawHierarchy`, not with
/// `ImageRenderer`: `ContentUnavailableView` is UIKit-backed on iOS, and `ImageRenderer` drew every
/// empty state as zero pixels — measured on the iPhone 17 (iOS 26.3) — which would have made "draws
/// its message" unassertable.
@Suite("Word cloud — what the main area draws (#1373)")
@MainActor
struct WordCloudMainAreaRenderTests {

    private static let size = CGSize(width: 320, height: 320)

    /// Renders `state` with a magenta terms surface, in light mode on a white window, and counts the
    /// magenta pixels and the inked ones (anything not the white ground).
    private func render(_ state: WordCloudDisplayState) throws -> (magenta: Int, inked: Int) {
        #if canImport(UIKit)
        let scene = try #require(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first,
            "The test host has no window scene to render in")
        let view = WordCloudMainArea(state: state) { Color(red: 1, green: 0, blue: 1) }
            .frame(width: Self.size.width, height: Self.size.height)
            .background(Color.white)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: Self.size)
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = UIHostingController(rootView: view)
        window.isHidden = false
        window.layoutIfNeeded()
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
            _ = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let cgImage = try #require(image.cgImage, "no image for \(state)")
        let width = cgImage.width, height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = try #require(CGContext(
            data: &pixels, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        var magenta = 0, inked = 0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let (r, g, b) = (pixels[index], pixels[index + 1], pixels[index + 2])
            if r < 235 || g < 235 || b < 235 { inked += 1 }
            if r > 240 && g < 16 && b > 240 { magenta += 1 }
        }
        return (magenta, inked)
        #else
        Issue.record("rendering needs UIKit")
        return (0, 0)
        #endif
    }

    @Test("Zero terms from more than zero documents never renders the terms surface, under any lens or verdict — and draws its message instead")
    func zeroTermsFromDocumentsNeverRendersTheCanvas() throws {
        // The control first: the terms state does draw the surface, or the render proves nothing.
        let terms = try render(.terms)
        #expect(terms.magenta > Int(Self.size.width * Self.size.height) / 2,
                "the terms state drew \(terms.magenta) magenta pixels — the surface is not reaching the render")

        let verdicts: [NaturalLanguageHealth?] = [
            nil, .fullyWorking,
            NaturalLanguageHealth(lemmatizes: false, classifiesWords: true, recognizesNames: true),
            NaturalLanguageHealth(lemmatizes: true, classifiesWords: false, recognizesNames: true),
            NaturalLanguageHealth(lemmatizes: true, classifiesWords: true, recognizesNames: false),
        ]
        var rendered = 0
        for lens in WordCloudLens.allCases {
            for verdict in verdicts {
                var empty = WordCloudResult(terms: [], documentCount: 4_591, totalTokenCount: 0)
                empty.languageAnalysis = verdict
                let state = WordCloudDisplayState.resolve(
                    serviceAvailable: true, isLoading: false, errorMessage: nil, result: empty,
                    lens: lens, languageAnalysis: verdict)
                let drawn = try render(state)
                #expect(drawn.magenta == 0,
                        "\(lens.rawValue) under \(String(describing: verdict)) → \(state) drew the terms surface")
                #expect(drawn.inked > 200,
                        "\(lens.rawValue) → \(state) drew nothing (\(drawn.inked) pixels): the reader would see a blank panel")
                rendered += 1
            }
        }
        #expect(rendered == WordCloudLens.allCases.count * verdicts.count)
    }

    @Test("A lens the tagger cannot serve, and a thin signal-dependent lens, draw their messages and not the surface")
    func unavailableAndThinLensesDrawTheirMessages() throws {
        let unclassified = NaturalLanguageHealth(lemmatizes: true, classifiesWords: false, recognizesNames: true)
        let nameless = NaturalLanguageHealth(lemmatizes: true, classifiesWords: true, recognizesNames: false)
        for state: WordCloudDisplayState in [.lensUnavailable(.topics, unclassified), .lensUnavailable(.people, nameless),
                                             .insufficientSignal(.concepts)] {
            let drawn = try render(state)
            #expect(drawn.magenta == 0, "\(state) drew the terms surface")
            #expect(drawn.inked > 200, "\(state) drew nothing")
        }
    }
}

// MARK: - #1373: the verdict travels with the result

/// A result carries the tagger verdict it was counted under, and the disk cache trusts only that.
struct WordCloudLanguageAnalysisStampTests {

    private let unlemmatised = NaturalLanguageHealth(lemmatizes: false, classifiesWords: true, recognizesNames: true)
    private let unclassified = NaturalLanguageHealth(lemmatizes: true, classifiesWords: false, recognizesNames: true)

    private func stamped(_ analysis: NaturalLanguageHealth?, lens: WordCloudLens = .topics) -> WordCloudResult {
        var r = WordCloudResult(terms: [TermCount(term: "treaty", count: 4)],
                                documentCount: 2, totalTokenCount: 9)
        r.lens = lens
        r.languageAnalysis = analysis
        return r
    }

    @Test("A stored result is reused only when its own stamp says the lens was counted as designed")
    func diskReuseNeedsAGoodStamp() {
        #expect(WordFrequencyService.isReusable(stamped(.fullyWorking), for: .topics))
        #expect(!WordFrequencyService.isReusable(stamped(nil), for: .topics),
                "an entry written before #1373 cannot say whether its tagger worked")
        #expect(!WordFrequencyService.isReusable(stamped(unclassified), for: .topics))
        #expect(!WordFrequencyService.isReusable(stamped(unlemmatised), for: .allTerms))
        // Entity lenses never lemmatise, so a lemma failure does not disqualify them.
        #expect(WordFrequencyService.isReusable(stamped(unlemmatised, lens: .people), for: .people))
    }

    /// #1421 review: the disk key fingerprints the index by its document count, which the v59
    /// re-index left unchanged while it rewrote 313,949 bodies. The index stamp is what tells a count
    /// read from the old text from one read from the new, so a result is reused only at the version
    /// it was counted at — one per conjunct: an older version, a newer one, and no stamp at all.
    @Test("A stored result is reused only at the index version it was counted at (#1421 review)")
    func diskReuseNeedsTheInstalledIndexVersion() {
        var current = stamped(.fullyWorking)
        current.indexVersion = 59
        #expect(WordFrequencyService.isReusable(current, for: .topics, indexVersion: 59),
                "control: a good tagger stamp at the installed version must be reused")
        #expect(!WordFrequencyService.isReusable(current, for: .topics, indexVersion: 60),
                "a count read from the text an older index held was reused after the re-index")
        var newer = current
        newer.indexVersion = 60
        #expect(!WordFrequencyService.isReusable(newer, for: .topics, indexVersion: 59))
        #expect(!WordFrequencyService.isReusable(stamped(.fullyWorking), for: .topics, indexVersion: 59),
                "an entry written before the index stamp cannot say which text it counted")
        var badTagger = stamped(unclassified)
        badTagger.indexVersion = 59
        #expect(!WordFrequencyService.isReusable(badTagger, for: .topics, indexVersion: 59),
                "the index stamp must not excuse a tagger that failed the lens")
    }

    @Test("A result is written to disk only when every tagger its lens reads worked")
    func diskWriteNeedsAWorkingTagger() {
        #expect(WordFrequencyService.isPersistable(countedUnder: .fullyWorking, lens: .topics))
        #expect(!WordFrequencyService.isPersistable(countedUnder: unclassified, lens: .topics))
        #expect(!WordFrequencyService.isPersistable(countedUnder: unlemmatised, lens: .allTerms))
        #expect(WordFrequencyService.isPersistable(countedUnder: unlemmatised, lens: .people))
    }

    @Test("The stamp survives the disk cache's JSON round trip, and an old entry decodes without one")
    func stampRoundTrips() throws {
        var result = stamped(unlemmatised)
        result.indexVersion = 59
        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(WordCloudResult.self, from: data)
        #expect(decoded.languageAnalysis == unlemmatised)
        #expect(decoded.indexVersion == 59, "the index stamp (#1421 review) must survive the disk")
        let legacy = Data(#"{"terms":[],"documentCount":1,"totalTokenCount":0}"#.utf8)
        #expect(try JSONDecoder().decode(WordCloudResult.self, from: legacy).languageAnalysis == nil)
        #expect(try JSONDecoder().decode(WordCloudResult.self, from: legacy).indexVersion == nil)
    }

    @Test("Hiding a word keeps every stamp, so the keyness gate still reads the result's own verdict")
    func hidingAWordKeepsTheStamps() {
        var counted = stamped(unlemmatised, lens: .allTerms)
        counted.indexVersion = 59
        let hidden = counted.removingTerm("TREATY")
        #expect(hidden.terms.isEmpty)
        #expect(hidden.documentCount == 2)
        #expect(hidden.totalTokenCount == 9)
        #expect(hidden.lens == .allTerms)
        #expect(hidden.languageAnalysis == unlemmatised)
        #expect(hidden.indexVersion == 59)
    }
}

// MARK: - #1373: nothing tags before the warm-up

/// Where the app gets its taggers, and when the warm-up starts.
///
/// The scans are the structural half; the runtime half is `WordCloudLensTests` on an iOS 27.0
/// simulator and `NaturalLanguageReadinessWarmUpTests` below.
struct NaturalLanguageReadinessScanTests {

    static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()

    /// Every directory `project.yml` compiles into the app targets.
    private static let appSourceDirectories = [
        "FRUSExplorer", "FTS5Store", "WordCloudKit", "SemanticVectorsKit", "SourceNoteKit", "TEIHeaderKit",
    ]

    /// `source` with each line's `//` comment removed, so a comment naming a call is not a call.
    static func code(_ source: String) -> String {
        source.components(separatedBy: "\n").map { line -> String in
            guard let slashes = line.range(of: "//") else { return line }
            return String(line[..<slashes.lowerBound])
        }.joined(separator: "\n")
    }

    /// The body of the first brace block that follows `start`, braces balanced.
    static func braceBody(in text: String, after start: String.Index) -> Range<String.Index>? {
        guard let open = text[start...].firstIndex(of: "{") else { return nil }
        var depth = 0
        var index = open
        while index < text.endIndex {
            if text[index] == "{" { depth += 1 }
            if text[index] == "}" {
                depth -= 1
                if depth == 0 { return text.index(after: open)..<index }
            }
            index = text.index(after: index)
        }
        return nil
    }

    @Test("The app constructs an NLTagger in exactly one place: the gate's private factory")
    func nlTaggerIsConstructedOnlyBehindTheGate() throws {
        var filesScanned = 0
        var sites: [String] = []
        for directory in Self.appSourceDirectories {
            let root = Self.repoRoot.appending(path: directory)
            let urls = (FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?
                .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" } ?? [])
            for url in urls {
                filesScanned += 1
                let text = Self.code(try String(contentsOf: url, encoding: .utf8))
                // `NLTagger(`, `NLTagger.init(` and either spelled with spaces: every way to call the
                // initialiser, not only the usual one.
                for (number, line) in text.components(separatedBy: "\n").enumerated()
                where line.range(of: #"NLTagger\s*(\.\s*init\s*)?\("#, options: .regularExpression) != nil {
                    sites.append("\(directory)/\(url.lastPathComponent):\(number + 1)")
                }
            }
        }
        #expect(filesScanned > 500, "scanned only \(filesScanned) files — the walk is not reaching the app")
        #expect(sites.count == 1 && sites.first?.hasPrefix("WordCloudKit/NaturalLanguageReadiness.swift:") == true,
                "NLTagger( constructed at \(sites) — every tagger must come from NaturalLanguageReadiness.tagger(tagSchemes:), after the warm-up")

        // …and that one place is the private factory, which only the gate and the canary call.
        let gate = Self.code(try String(contentsOf: Self.repoRoot.appending(
            path: "WordCloudKit/NaturalLanguageReadiness.swift"), encoding: .utf8))
        let declaration = try #require(gate.range(of: "private static func makeTagger("))
        let body = try #require(Self.braceBody(in: gate, after: declaration.upperBound))
        #expect(gate[body].contains("NLTagger(tagSchemes:"), "the one NLTagger( is not inside makeTagger")
    }

    @Test("The gate reads the verdict before it builds a tagger (#1373)")
    func taggerReadsTheVerdictBeforeItBuilds() throws {
        // The gate is one line — `_ = verdict` inside `tagger(tagSchemes:)` — and no runtime test
        // reliably sees it any more. The warm-up starts in `FRUSExplorerApp.init`, 1.8–3.4 s into
        // the process on the iPhone 17e, and a test's first tagging comes 2.4–4.7 s in, so in most
        // launches the verdict has settled before any test asks for a tagger and deleting the line
        // fails nothing that tags. So the order is pinned where it is written, scoped to that
        // one function's body: a read of `verdict` (not `settledVerdict`, which does not wait), and
        // then the call to `makeTagger`.
        let gate = Self.code(try String(contentsOf: Self.repoRoot.appending(
            path: "WordCloudKit/NaturalLanguageReadiness.swift"), encoding: .utf8))
        let declaration = try #require(
            gate.range(of: "public static func tagger(tagSchemes: [NLTagScheme]) -> NLTagger"),
            "tagger(tagSchemes:) is no longer declared as expected")
        let body = String(gate[try #require(Self.braceBody(in: gate, after: declaration.upperBound))])
        let build = try #require(body.range(of: "makeTagger("),
                                 "tagger(tagSchemes:) no longer builds its tagger through makeTagger")
        let wait = try #require(body.range(of: #"\bverdict\b"#, options: .regularExpression),
                                "tagger(tagSchemes:) no longer reads the verdict, so nothing makes the warm-up precede the process's first tagging")
        #expect(wait.upperBound <= build.lowerBound,
                "tagger(tagSchemes:) builds its tagger before it reads the verdict")
    }

    @Test("Both app inits start the warm-up as their first statement, at launch (#1373)")
    func warmUpStartsFirstInBothInits() throws {
        // The plan's design: at launch, before any tagging, so the warm-up's wait is paid in the
        // background rather than by the first cloud a reader opens. An earlier attempt moved it to
        // first use on a block-by-block measurement that a launch-by-launch rotation did not
        // reproduce — see `NaturalLanguageReadiness`'s "At launch" section. The gate still orders
        // the warm-up before any tagging wherever it starts; this pins WHEN it starts.
        let app = Self.code(try String(contentsOf: Self.repoRoot.appending(
            path: "FRUSExplorer/App/FRUSExplorerApp.swift"), encoding: .utf8))
        var inits = 0
        var searchFrom = app.startIndex
        while let found = app.range(of: "    init() {", range: searchFrom..<app.endIndex) {
            inits += 1
            let body = try #require(Self.braceBody(in: app, after: found.lowerBound))
            let first = app[body].components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .first { !$0.isEmpty }
            let line = app[..<found.lowerBound].components(separatedBy: "\n").count
            #expect(first == "NaturalLanguageReadiness.beginWarmUp()",
                    "FRUSExplorerApp.swift:\(line) init() starts with \(first ?? "nothing")")
            searchFrom = found.upperBound
        }
        #expect(inits == 2, "expected the iOS and the macOS init, found \(inits)")
    }

    /// The app's two main-actor functions that tokenize, each named by its file and declaration.
    private static let mainActorTaggers: [(path: String, declaration: String)] = [
        ("FRUSExplorer/Analytics/WordCloud/WordCloudExport.swift", "static func collectionCloudImage("),
        ("FRUSExplorer/RelatedDocuments/SemanticSharedTerms.swift", "static func sharedTerms("),
    ]

    @Test("A main-actor function that tokenizes awaits the warm-up before it builds a tokenizer (#1373)",
          arguments: mainActorTaggers.map(\.path))
    func mainActorTaggersAwaitTheWarmUp(path: String) throws {
        // Tokenizing waits for the warm-up while it runs — it starts at launch, and can wait out the
        // 30 s asset budget when the lemma request does not answer (18 of 75 launches of the one
        // iPhone 17e simulator measured launch by launch, iOS 27.0, over the half hour after it
        // booted). On the main thread that is a frozen app, so these two await the verdict first and
        // then find it settled. Deleting the await compiles, passes every other test, and freezes
        // only an export or related list opened while the warm-up waits — which is why the order is
        // pinned here.
        let entry = try #require(Self.mainActorTaggers.first { $0.path == path })
        let source = Self.code(try String(contentsOf: Self.repoRoot.appending(path: path), encoding: .utf8))
        let declaration = try #require(source.range(of: entry.declaration),
                                       "\(entry.declaration) is no longer in \(path)")
        // Its OWN attribute: the nearest non-blank line above the declaration (comments are already
        // blanked by `code`), not any `@MainActor` earlier in the file.
        let attribute = source[source.startIndex..<declaration.lowerBound]
            .components(separatedBy: "\n").dropLast()
            .last { !$0.trimmingCharacters(in: .whitespaces).isEmpty }?
            .trimmingCharacters(in: .whitespaces)
        #expect(attribute == "@MainActor",
                "\(entry.declaration) is not main-actor any more (\(attribute ?? "nil")) — drop it from this list rather than weaken the check")
        let body = try #require(Self.braceBody(in: source, after: declaration.upperBound))
        let text = String(source[body])
        let awaited = try #require(text.range(of: "await NaturalLanguageReadiness.verdictWhenReady()"),
                                   "\(path): \(entry.declaration) tokenizes without awaiting the warm-up")
        let tokenizer = try #require(text.range(of: "WordCloudTokenizer"),
                                     "\(path): \(entry.declaration) no longer builds a tokenizer")
        #expect(awaited.upperBound <= tokenizer.lowerBound,
                "\(path): the tokenizer is built before the warm-up is awaited")
    }
}

/// The warm-up as it actually ran in this test host — started at launch by the app's init, unless a
/// test reached a tagger first.
///
/// The printed line is the measurement record: it is how the iOS 27.0 launches in #1373's
/// DEVELOPMENT-PLAN entry were counted, and it says which started the warm-up and how far into the
/// process.
struct NaturalLanguageReadinessWarmUpTests {

    @Test("The warm-up asked for every scheme, lemma last, and each scheme whose request answered works (#1373)")
    func warmUpRanAndAnswered() {
        let verdict = NaturalLanguageReadiness.current
        print("[#1373] \(ProcessInfo.processInfo.operatingSystemVersionString): started "
              + (verdict.warmUp.requestedAtLaunch ? "at launch" : "on first use")
              + (verdict.warmUp.processAge.map { String(format: " %.3fs into the process", $0) } ?? "")
              + " and took \(String(format: "%.3f", verdict.warmUp.seconds))s; listed "
              + "\(verdict.warmUp.schemesListed); "
              + verdict.warmUp.assetRequests
                  .map { "\($0.scheme)=\($0.answer.rawValue)@\(String(format: "%.3f", $0.seconds))s" }
                  .joined(separator: " ")
              + "; canary \(verdict.health)")
        #expect(verdict.warmUp.assetRequests.map(\.scheme) == ["LexicalClass", "NameType", "Lemma"])
        // Per scheme, because the three are independent: on iOS 27.0 a launch can lose its lemma
        // request while the other two answer, and those two must then work. See
        // `NaturalLanguageWarmUp.answeredAvailable(for:)` for what was measured.
        let capabilities: [(NLTagScheme, Bool)] = [
            (.lexicalClass, verdict.health.classifiesWords),
            (.nameType, verdict.health.recognizesNames),
            (.lemma, verdict.health.lemmatizes),
        ]
        for (scheme, works) in capabilities where verdict.warmUp.answeredAvailable(for: scheme) {
            #expect(works, "the \(scheme.rawValue) request answered available, yet the canary found \(verdict.health)")
        }
        // The first step, kept for its side effect (it is what restored tagging on iOS 27.0). Every
        // runtime measured lists at least `Language`, `Script` and `TokenType`, so an empty record
        // means the call was dropped.
        #expect(!verdict.warmUp.schemesListed.isEmpty, "availableTagSchemes listed nothing")
        // Below 27 the requests are not made, so the warm-up does not spend its budget: on the iOS
        // 26.3 simulator it used to wait the full 30 s in every process for answers that never came.
        // The line is written out here rather than read from `asksForAssets`, so a rule that moves
        // it fails this test instead of steering it.
        if ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27 {
            #expect(!verdict.warmUp.assetRequests.contains { $0.answer == .notAsked },
                    "a runtime from 27 on must ask for every scheme: \(verdict.warmUp.assetRequests)")
        } else {
            #expect(verdict.warmUp.assetRequests.allSatisfy { $0.answer == .notAsked },
                    "a runtime below 27 asked for assets: \(verdict.warmUp.assetRequests)")
            #expect(verdict.warmUp.seconds < 5,
                    "the warm-up took \(verdict.warmUp.seconds) s on a runtime whose assets never answer")
        }
    }
}

// MARK: - #1373: every surface a cloud reaches asks the same rules

/// Where each Word Cloud surface asks `WordCloudDisplayState`'s rules — the counted-as-printed
/// wording, the header's count line, the main area's drawing (#1373).
///
/// The rules are tested above as pure functions and the main area by rendering; these pin the CALLS,
/// because a surface that stops asking compiles, passes every other test, and silently exports a
/// cloud counted as printed as though it were not. Each needle is matched inside its own
/// declaration's body with whitespace ignored, so a call moved elsewhere in the file does not count.
struct WordCloudRuleWiringTests {

    private typealias Scan = NaturalLanguageReadinessScanTests

    /// One call a surface must make: the file, the declaration whose body holds it, and the call.
    struct Site: CustomTestStringConvertible, Sendable {
        let path: String
        let declaration: String
        let needles: [String]
        var testDescription: String { "\(path.split(separator: "/").last ?? "") · \(declaration)" }
    }

    static let sites: [Site] = [
        Site(path: "FRUSExplorer/Analytics/WordCloud/WordCloudView.swift",
             declaration: "private var cloudProvenance: AnalyticsProvenance",
             needles: ["if let printed = WordCloudDisplayState.countedAsPrintedCaveat(result, lens: lens) {\n caveats.append(printed)\n }"]),
        Site(path: "FRUSExplorer/Analytics/WordCloud/WordCloudView.swift",
             declaration: "private func cloudFigureCaption(drawnTerms: Int) -> String",
             needles: ["WordCloudDisplayState.countedAsPrintedCaptionSegment(result, lens: lens),",
                       ".compactMap { $0 }.joined(separator: \" · \")"]),
        Site(path: "FRUSExplorer/Analytics/WordCloud/WordCloudView.swift",
             declaration: "private var scopeHeader: some View",
             needles: ["if let count = WordCloudDisplayState.headerCountLine(\n for: displayState,",
                       "if let printed = WordCloudDisplayState.countedAsPrintedNote(result, lens: lens) {\n Text(printed)"]),
        Site(path: "FRUSExplorer/Analytics/WordCloud/WordCloudView.swift",
             declaration: "private var content: some View",
             needles: ["WordCloudMainArea(state: displayState) {"]),
        Site(path: "FRUSExplorer/Analytics/WordCloud/WordCloudComparisonView.swift",
             declaration: "private var header: some View",
             needles: ["if let printed = WordCloudDisplayState.countedAsPrintedNote(result, lens: .allTerms) {\n Text(printed)"]),
        Site(path: "FRUSExplorer/Analytics/WordCloud/WordCloudExport.swift",
             declaration: "static func collectionCloudImage(",
             needles: ["let languageAnalysis = await NaturalLanguageReadiness.verdictWhenReady().health",
                       "counted.languageAnalysis = languageAnalysis",
                       "let methodLine = WordCloudDisplayState.countedAsPrintedPlateLine(counted, lens: .allTerms)",
                       "provenanceLine: methodLine"]),
    ]

    /// `text` with every whitespace character removed.
    private static func squeezed(_ text: some StringProtocol) -> String {
        String(text.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) }
            .map(Character.init))
    }

    @Test("Each Word Cloud surface asks the shared rule for what it shows and exports (#1373)",
          arguments: sites)
    func surfaceAsksTheRule(site: Site) throws {
        let source = Scan.code(try String(contentsOf: Scan.repoRoot.appending(path: site.path),
                                          encoding: .utf8))
        let declaration = try #require(source.range(of: site.declaration),
                                       "\(site.declaration) is no longer in \(site.path)")
        let body = Self.squeezed(source[try #require(Scan.braceBody(in: source, after: declaration.upperBound))])
        for needle in site.needles {
            #expect(body.contains(Self.squeezed(needle)),
                    "\(site.path): \(site.declaration) no longer makes the call \(needle)")
        }
    }
}

// MARK: - #1373: the disk cache's stamp rules, where the service applies them

/// `WordFrequencyService.topTerms` driven for real, over an empty index, so the disk cache's stamp
/// rules are tested where the service applies them (#1373). `WordCloudLanguageAnalysisStampTests`
/// pins the rules themselves; a service that stopped asking them would pass those.
///
/// The disk key is rebuilt here from the service's own recipe, and the stamped control proves it is
/// the key the service reads: if the recipe drifts, the control fails before anything else is
/// believed. Every entry a test writes, or makes the service write, is removed when it ends.
struct WordFrequencyServiceStampWiringTests {

    private static let limit = 50

    /// A service over a fresh, empty index in a temporary directory, whose installed index version
    /// is `installedVersion` in a defaults suite of its own (#1421 review) — the host's own stamp
    /// is whatever its last launch left, and a parallel test must not move it.
    private func withService(installedVersion: Int = IndexingPipeline.currentDateIndexVersion,
                             _ body: (WordFrequencyService, IndexingPipeline) async throws -> Void)
    async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSWordFrequency1373-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let dbURL = dir.appendingPathComponent("test.sqlite")
        let volumes = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        let store = try FTS5Store(databaseURL: dbURL)
        let suite = "FRUSWordFrequency1421.\(UUID().uuidString)"
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.set(installedVersion, forKey: IndexingPipeline.dateIndexVersionKey)
        let pipeline = try IndexingPipeline(fts5Store: store, databaseURL: dbURL,
                                            volumesDirectory: volumes, concurrencyLimit: 2,
                                            defaults: defaults)
        try await body(WordFrequencyService(pipeline: pipeline), pipeline)
    }

    /// The disk key `topTerms` builds for an All-terms cloud of `signature` with the defaults below.
    private func diskKey(_ signature: String, pipeline: IndexingPipeline) async throws -> String {
        WordCloudDiskCache.key(signature: signature, limit: Self.limit, includeDiplomatic: true,
                               extras: "", tuning: WordCloudTuning.standard.cacheToken,
                               fingerprint: try await pipeline.documentCacheCount())
    }

    /// A persistent All-terms count of `signature` over no documents.
    private func count(_ service: WordFrequencyService, _ signature: String) async throws -> WordCloudResult {
        try await service.topTerms(signature: signature, keys: [], limit: Self.limit,
                                   includeDiplomaticStopwords: true, persistent: true)
    }

    /// A stored All-terms cloud of one planted word, stamped with `analysis`, counted at the
    /// installed index version unless `indexVersion` says otherwise.
    private func planted(_ word: String, analysis: NaturalLanguageHealth?,
                         indexVersion: Int? = IndexingPipeline.currentDateIndexVersion) -> WordCloudResult {
        var stored = WordCloudResult(terms: [TermCount(term: word, count: 9)], documentCount: 3,
                                     totalTokenCount: 9)
        stored.lens = .allTerms
        stored.languageAnalysis = analysis
        stored.indexVersion = indexVersion
        return stored
    }

    @Test("A stored cloud is served back only when its own stamp says it was counted as designed, and a fresh one carries this process's verdict")
    func storedCloudServedOnlyWithAGoodStamp() async throws {
        try await withService { service, pipeline in
            // The control: a stamped entry at the rebuilt key IS served, so the key is the service's.
            let good = "test-1373-stamped-\(UUID().uuidString)"
            let old = "test-1373-unstamped-\(UUID().uuidString)"
            let goodKey = try await diskKey(good, pipeline: pipeline)
            let oldKey = try await diskKey(old, pipeline: pipeline)
            // Both keys, because the service may write its fresh count over the unstamped one.
            defer { discardWordCloudDiskEntries([goodKey, oldKey]) }
            WordCloudDiskCache.save(planted("plantedstamped", analysis: .fullyWorking), key: goodKey)
            let served = try await count(service, good)
            #expect(served.terms.map(\.term) == ["plantedstamped"],
                    "the stamped entry was not served — the rebuilt key is not the service's, so nothing below proves anything")

            // An entry written before #1373 carries no stamp: it is recounted, not served.
            WordCloudDiskCache.save(planted("plantedunstamped", analysis: nil), key: oldKey)
            let fresh = try await count(service, old)
            #expect(!fresh.terms.contains { $0.term == "plantedunstamped" },
                    "an unstamped stored cloud was served as though its tagger had worked")
            #expect(fresh.languageAnalysis == NaturalLanguageReadiness.health,
                    "a fresh count must carry the verdict it was counted under, got \(String(describing: fresh.languageAnalysis))")
        }
    }

    /// #1421 review, driven through the service: the v59 re-index rewrote 313,949 bodies and kept
    /// every `document_cache` row, so a corpus cloud counted from the v58 text sat under exactly the
    /// key the service builds after it. The stamped control at the installed version proves the key
    /// is the service's; the entry stamped one version back must be counted again, and the fresh
    /// count must carry the installed version, so the next open can reuse it.
    @Test("A stored cloud counted before a re-index is counted again, not served (#1421 review)")
    func storedCloudFromAnOlderIndexIsRecounted() async throws {
        let installed = IndexingPipeline.currentDateIndexVersion
        try await withService(installedVersion: installed) { service, pipeline in
            #expect(pipeline.installedDateIndexVersion == installed)
            let current = "test-1421-current-\(UUID().uuidString)"
            let stale = "test-1421-previous-\(UUID().uuidString)"
            let currentKey = try await diskKey(current, pipeline: pipeline)
            let staleKey = try await diskKey(stale, pipeline: pipeline)
            defer { discardWordCloudDiskEntries([currentKey, staleKey]) }
            WordCloudDiskCache.save(planted("plantedcurrent", analysis: .fullyWorking,
                                            indexVersion: installed), key: currentKey)
            #expect(try await count(service, current).terms.map(\.term) == ["plantedcurrent"],
                    "control: an entry at the installed version was not served, so the key is not the service's")

            WordCloudDiskCache.save(planted("plantedprevious", analysis: .fullyWorking,
                                            indexVersion: installed - 1), key: staleKey)
            let fresh = try await count(service, stale)
            #expect(!fresh.terms.contains { $0.term == "plantedprevious" },
                    "a cloud counted from the text of index v\(installed - 1) was served after the re-index to v\(installed)")
            #expect(fresh.indexVersion == installed,
                    "a fresh count must carry the version it read, got \(String(describing: fresh.indexVersion))")
        }
    }

    @Test("A fresh count is written to disk exactly when this process's tagger counted its lens as designed")
    func freshCountPersistedOnlyWhenCountedAsDesigned() async throws {
        // Discriminates on a runtime whose lemmatiser fails — the iOS 26 simulators, or an iOS 27.0
        // launch that lost its lemma request — where the count must NOT be written. Where the tagger
        // works both outcomes of the rule write it, so there it is a control.
        try await withService { service, pipeline in
            let signature = "test-1373-persist-\(UUID().uuidString)"
            let key = try await diskKey(signature, pipeline: pipeline)
            defer { discardWordCloudDiskEntries([key]) }
            _ = try await count(service, signature)
            let expected = NaturalLanguageReadiness.health.countsAsDesigned(for: .allTerms)
            #expect((WordCloudDiskCache.load(key: key) != nil) == expected,
                    "written=\(WordCloudDiskCache.load(key: key) != nil) under \(NaturalLanguageReadiness.health)")
        }
    }
}
