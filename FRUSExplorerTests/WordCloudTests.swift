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
        // is the lemma scheme lost every noun for the rest of its life (#1373). This test is that
        // order whenever it is the first in its process to tag.
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
    /// lemma. On iOS 27.0 those two requests answered in every launch measured, including the
    /// launches that lost their lemmatiser, so the guard holds on every run there. It cannot fail on
    /// an iPhone 17 running iOS 26.3, where no request answers and nothing tags at all.
    ///
    /// **Where it did not answer** — iOS 26.3 — the lens must keep something exactly when the canary
    /// says it is supported, which is what lets the Word Cloud say "unavailable on this device"
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

    @Test("Zero terms from more than zero documents never renders a bare canvas, under any lens or verdict")
    func zeroTermsFromDocumentsIsNeverACanvas() {
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
            #expect(resolve(.empty, lens: lens, analysis: nameless) == .lensUnavailable(lens))
            #expect(resolve(.empty, lens: lens, analysis: unclassified) == .noIndexedText)
        }
        for lens in [WordCloudLens.topics, .actions, .descriptors] {
            #expect(resolve(.empty, lens: lens, analysis: unclassified) == .lensUnavailable(lens))
            #expect(resolve(.empty, lens: lens, analysis: nameless) == .noIndexedText)
        }
        // No lemmatiser leaves every lens available: it counts printed forms instead.
        let unlemmatised = NaturalLanguageHealth(lemmatizes: false, classifiesWords: true, recognizesNames: true)
        for lens in WordCloudLens.allCases {
            #expect(resolve(result(terms: 30, documents: 9), lens: lens, analysis: unlemmatised) == .terms)
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
        #expect(WordCloudDisplayState.lensUnavailable(.topics).showsCloudChrome)
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
        let messages = WordCloudLens.allCases.map { WordCloudView.noTermsDetail(for: $0) }
        #expect(Set(messages).count == WordCloudLens.allCases.count, "two lenses share a message")
        for message in messages {
            #expect(message.contains("were read"),
                    "a 'nothing found' message must say the documents WERE read: \(message)")
            #expect(!message.contains("no indexed text"))
        }
    }

    @Test("The header hides its count only for a lens that was never counted")
    func headerCountHiddenOnlyForUnavailableLens() {
        #expect(WordCloudView.isLensUnavailable(.lensUnavailable(.topics)))
        #expect(!WordCloudView.isLensUnavailable(.noTerms(.topics)))
        #expect(!WordCloudView.isLensUnavailable(.terms))
    }

    @Test("'Counted as printed' shows exactly for a word lens whose own stamp says the lemmatiser failed")
    func countedAsPrintedConditions() {
        let unlemmatised = NaturalLanguageHealth(lemmatizes: false, classifiesWords: true, recognizesNames: true)
        // The one case that shows it…
        #expect(WordCloudView.countedAsPrinted(result(terms: 5, documents: 2, analysis: unlemmatised),
                                               lens: .allTerms))
        // …and one fixture per condition that withholds it.
        #expect(!WordCloudView.countedAsPrinted(result(terms: 5, documents: 2, analysis: unlemmatised),
                                                lens: .people),
                "entity lenses never lemmatise, so the caption would say nothing true")
        #expect(!WordCloudView.countedAsPrinted(result(terms: 5, documents: 2, analysis: .fullyWorking),
                                                lens: .allTerms))
        #expect(!WordCloudView.countedAsPrinted(result(terms: 5, documents: 2, analysis: nil),
                                                lens: .allTerms),
                "an unstamped result is unknown, not unlemmatised")
        #expect(!WordCloudView.countedAsPrinted(result(terms: 0, documents: 2, analysis: unlemmatised),
                                                lens: .allTerms),
                "nothing was counted, so there is nothing to caption")
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

    @Test("A result is written to disk only when every tagger its lens reads worked")
    func diskWriteNeedsAWorkingTagger() {
        #expect(WordFrequencyService.isPersistable(countedUnder: .fullyWorking, lens: .topics))
        #expect(!WordFrequencyService.isPersistable(countedUnder: unclassified, lens: .topics))
        #expect(!WordFrequencyService.isPersistable(countedUnder: unlemmatised, lens: .allTerms))
        #expect(WordFrequencyService.isPersistable(countedUnder: unlemmatised, lens: .people))
    }

    @Test("The stamp survives the disk cache's JSON round trip, and an old entry decodes without one")
    func stampRoundTrips() throws {
        let data = try JSONEncoder().encode(stamped(unlemmatised))
        let decoded = try JSONDecoder().decode(WordCloudResult.self, from: data)
        #expect(decoded.languageAnalysis == unlemmatised)
        let legacy = Data(#"{"terms":[],"documentCount":1,"totalTokenCount":0}"#.utf8)
        #expect(try JSONDecoder().decode(WordCloudResult.self, from: legacy).languageAnalysis == nil)
    }

    @Test("Hiding a word keeps both stamps, so the keyness gate still reads the result's own verdict")
    func hidingAWordKeepsTheStamps() {
        let hidden = stamped(unlemmatised, lens: .allTerms).removingTerm("TREATY")
        #expect(hidden.terms.isEmpty)
        #expect(hidden.documentCount == 2)
        #expect(hidden.totalTokenCount == 9)
        #expect(hidden.lens == .allTerms)
        #expect(hidden.languageAnalysis == unlemmatised)
    }
}

// MARK: - #1373: nothing tags before the warm-up

/// Where the app gets its taggers, and when the warm-up starts.
///
/// The scans are the structural half; the runtime half is `WordCloudLensTests` on an iOS 27.0
/// simulator and `NaturalLanguageReadinessWarmUpTests` below.
struct NaturalLanguageReadinessScanTests {

    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()

    /// Every directory `project.yml` compiles into the app targets.
    private static let appSourceDirectories = [
        "FRUSExplorer", "FTS5Store", "WordCloudKit", "SemanticVectorsKit", "SourceNoteKit", "TEIHeaderKit",
    ]

    /// `source` with each line's `//` comment removed, so a comment naming a call is not a call.
    private static func code(_ source: String) -> String {
        source.components(separatedBy: "\n").map { line -> String in
            guard let slashes = line.range(of: "//") else { return line }
            return String(line[..<slashes.lowerBound])
        }.joined(separator: "\n")
    }

    /// The body of the first brace block that follows `start`, braces balanced.
    private static func braceBody(in text: String, after start: String.Index) -> Range<String.Index>? {
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
                for (number, line) in text.components(separatedBy: "\n").enumerated()
                where line.contains("NLTagger(") {
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

    @Test("Nothing on the launch path starts the warm-up: it runs on first use (#1373)")
    func warmUpIsNotStartedAtLaunch() throws {
        // #1373 proposed starting it in `FRUSExplorerApp.init()`. Measured on the iOS 27.0 iPhone
        // 17e, that lost the lemmatiser in 7 of 14 launches, against 1 of 14 recorded launches that
        // ran it on first use — see `NaturalLanguageReadiness`'s "Not at launch" note. This keeps
        // the obvious fix from being re-applied. The launch path is the App's inits and the AppState
        // they construct.
        var linesRead = 0
        var sites: [String] = []
        for path in ["FRUSExplorer/App/FRUSExplorerApp.swift", "FRUSExplorer/App/AppState.swift"] {
            let lines = Self.code(try String(contentsOf: Self.repoRoot.appending(path: path), encoding: .utf8))
                .components(separatedBy: "\n")
            linesRead += lines.count
            for (number, line) in lines.enumerated() where line.contains("NaturalLanguageReadiness") {
                sites.append("\(path):\(number + 1)")
            }
        }
        #expect(linesRead > 2_000, "read only \(linesRead) lines of the launch path")
        #expect(sites.isEmpty, "the launch path reaches the tagger warm-up at \(sites)")
    }

    /// The app's two main-actor functions that tokenize, each named by its file and declaration.
    private static let mainActorTaggers: [(path: String, declaration: String)] = [
        ("FRUSExplorer/Analytics/WordCloud/WordCloudExport.swift", "static func collectionCloudImage("),
        ("FRUSExplorer/RelatedDocuments/SemanticSharedTerms.swift", "static func sharedTerms("),
    ]

    @Test("A main-actor function that tokenizes awaits the warm-up before it builds a tokenizer (#1373)",
          arguments: mainActorTaggers.map(\.path))
    func mainActorTaggersAwaitTheWarmUp(path: String) throws {
        // Tokenizing waits for the warm-up when it is the process's first tagging — up to the 30 s
        // asset budget on a runtime whose requests never answer. On the main thread that is a
        // frozen app, so these two await the verdict first and then find it settled. Deleting the
        // await compiles, passes every other test, and freezes only the first export or related
        // list of a launch — which is why the order is pinned here.
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

/// The warm-up as it actually ran in this test process, on its first use here.
///
/// The printed line is the measurement record: it is how the iOS 27.0 launches in #1373's
/// DEVELOPMENT-PLAN entry were counted.
struct NaturalLanguageReadinessWarmUpTests {

    @Test("The warm-up asked for every scheme, lemma last, and each scheme whose request answered works (#1373)")
    func warmUpRanAndAnswered() {
        let verdict = NaturalLanguageReadiness.current
        print("[#1373] \(ProcessInfo.processInfo.operatingSystemVersionString): listed "
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
    }
}
