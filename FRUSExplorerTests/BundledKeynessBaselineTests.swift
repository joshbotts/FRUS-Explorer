// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import Testing

@testable import FRUSExplorer

// MARK: - BundledKeynessBaselineTests

/// The keyness baseline loader, and the distinction it must never blur: "no baseline" is not
/// "an empty corpus".
///
/// `.serialized` because every case here mutates one static: two cases interleaving at an
/// `await` would see each other's injected file, and the failure would look like a loader bug.
@Suite("Bundled keyness baseline", .serialized)
@MainActor
struct BundledKeynessBaselineTests {

    private static let lexiconsDigest = "aaa111"
    private static let stopwordsDigest = "bbb222"

    private func makeFile(lenses: [WordCloudLens: (Int, Int, [String: Int])],
                          tuning: WordCloudTuning = .standard,
                          includeDiplomatic: Bool = true) -> KeynessBaselineFile {
        var packed: [String: KeynessBaselineFile.Lens] = [:]
        for (lens, v) in lenses {
            packed[lens.rawValue] = KeynessBaselineFile.Lens(
                totalTokens: v.0, distinctTerms: v.1, terms: v.2,
                cutoffCount: v.2.values.min() ?? 0)
        }
        return KeynessBaselineFile(
            version: 1, generated: "2026-07-30",
            provenance: CloudVectorsFile.Provenance(
                volumeCount: 552, documentCount: 314_479,
                tuning: .standard, topTermsPerList: 50),
            termsPerLens: 20_000,
            configuration: .init(tuning: tuning, includeDiplomatic: includeDiplomatic,
                                 lexiconsDigest: Self.lexiconsDigest,
                                 stopwordsDigest: Self.stopwordsDigest),
            lenses: packed)
    }

    /// Injects a file plus digests that MATCH it, so a case that is not about configuration is not
    /// accidentally testing the configuration guard.
    private func inject(_ file: KeynessBaselineFile?) {
        BundledKeynessBaseline.injectForTesting(
            file, digests: (lexicons: Self.lexiconsDigest, stopwords: Self.stopwordsDigest))
    }

    /// Asks under the artifact's own configuration, so only the thing under test can fail.
    private func ask(_ lens: WordCloudLens,
                     tuning: WordCloudTuning = .standard,
                     includeDiplomatic: Bool = true,
                     languageAnalysis: NaturalLanguageHealth = .fullyWorking)
    -> BundledKeynessBaseline.Availability {
        BundledKeynessBaseline.baseline(for: lens, tuning: tuning,
                                        includeDiplomatic: includeDiplomatic,
                                        languageAnalysis: languageAnalysis)
    }

    // MARK: - Absence

    @Test("An absent artifact reports unavailable — never an empty corpus")
    func absentIsUnavailable() {
        inject(nil)
        defer { inject(nil) }
        #expect(!BundledKeynessBaseline.isAvailable)
        #expect(ask(.allTerms) == .unavailable(.noArtifact),
                "Returning empty counts would score EVERY scope term as unique to the scope — a keyness list that is entirely wrong and entirely plausible-looking")
    }

    @Test("A lens the generator does not emit is unavailable, not empty")
    func missingLensIsUnavailable() {
        inject(makeFile(lenses: [.allTerms: (1000, 5000, ["treaty": 40])]))
        defer { inject(nil) }
        #expect(ask(.allTerms) != .unavailable(.noArtifact))
        // `.people` is an entity lens the multi-lens tokenizer refuses, so it can never be priced.
        #expect(ask(.people) == .unavailable(.lensNotPriced(.people)))
    }

    @Test("A zero-token lens is unavailable, because it is a division by zero waiting to happen")
    func zeroTotalIsUnavailable() {
        inject(makeFile(lenses: [.topics: (0, 0, [:])]))
        defer { inject(nil) }
        #expect(ask(.topics) == .unavailable(.lensNotPriced(.topics)))
    }

    // MARK: - Values

    @Test("Counts, the true total, the cutoff and the coverage all come through intact")
    func valuesRoundTrip() throws {
        inject(makeFile(lenses: [.allTerms: (1_000_000, 45_000, ["treaty": 400, "morale": 12])]))
        defer { inject(nil) }

        guard case .available(let reference) = ask(.allTerms) else {
            Issue.record("expected a baseline"); return
        }
        #expect(reference.terms["treaty"] == 400)
        #expect(reference.terms["morale"] == 12)
        // The denominator must be the artifact's true total, NOT the sum of the two terms present.
        #expect(reference.totalTokens == 1_000_000)
        #expect(reference.totalTokens != reference.terms.values.reduce(0, +))
        #expect(reference.cutoffCount == 12)

        // The coverage and the stamp travel with the counts since #1608, in the one value.
        #expect(reference.terms.count == 2)
        #expect(reference.distinctTerms == 45_000,
                "Coverage has to state what fraction of the corpus vocabulary is priced, so a keyness view can disclose it")
        #expect(reference.generated == "2026-07-30")
        #expect(reference.wordForm == .dictionary)
    }

    // MARK: - Configuration guard

    @Test("Turning boilerplate exclusion off makes the reference incomparable, and says so")
    func diplomaticLayerMismatch() {
        inject(makeFile(lenses: [.allTerms: (1000, 100, ["treaty": 40])]))
        defer { inject(nil) }
        // The one-tap case: the word cloud's overflow menu. With the layer off the scope fills with
        // `department`/`telegram`/`washington`, none of which this reference counted — they would
        // score as the corpus's most distinctive words.
        #expect(ask(.allTerms, includeDiplomatic: false)
                == .unavailable(.configurationMismatch([.diplomaticLayer])))
    }

    @Test("Only the settings that ADD unpriceable terms are treated as mismatches")
    func asymmetricTuningCheck() {
        inject(makeFile(lenses: [.allTerms: (1000, 100, ["treaty": 40])]))
        defer { inject(nil) }

        // Folding plurals differently splits `treaty`/`treaties` on one side only — a term with a
        // reference count of zero appears in the scope. Mismatch.
        #expect(ask(.allTerms, tuning: .init(foldPlurals: false))
                == .unavailable(.configurationMismatch([.foldPlurals])))
        // Keeping classification markings the reference dropped. Mismatch.
        #expect(ask(.allTerms, tuning: .init(filterMarkings: false))
                == .unavailable(.configurationMismatch([.filterMarkings])))
        // A SHORTER minimum admits two-letter tokens the reference never saw. Mismatch.
        #expect(ask(.allTerms, tuning: .init(minimumLength: 2))
                == .unavailable(.configurationMismatch([.minimumLength])))

        // A LONGER minimum, or a higher minimum count, only removes terms from the scope. Every
        // term that survives still has a reference. Refusing these would withhold keyness from a
        // user whose settings cost nothing.
        if case .unavailable(let reason) = ask(.allTerms, tuning: .init(minimumLength: 5)) {
            Issue.record("a longer minimumLength should not block keyness — got \(reason)")
        }
        if case .unavailable(let reason) = ask(.allTerms, tuning: .init(minimumCount: 9)) {
            Issue.record("a higher minimumCount should not block keyness — got \(reason)")
        }
    }

    @Test("A changed lexicon or stopword payload blocks keyness until the baseline is rebuilt")
    func payloadDigestMismatch() {
        BundledKeynessBaseline.injectForTesting(
            makeFile(lenses: [.concepts: (1000, 100, ["security": 40])]),
            digests: (lexicons: "EDITED-SINCE", stopwords: Self.stopwordsDigest))
        defer { inject(nil) }
        // Add a concept to word-cloud-lexicons.json without rerunning the 50-minute generator and
        // every new concept gets a reference count of zero and tops the ranking, in every scope,
        // in every build.
        #expect(ask(.concepts) == .unavailable(.configurationMismatch([.lexicons])))

        BundledKeynessBaseline.injectForTesting(
            makeFile(lenses: [.concepts: (1000, 100, ["security": 40])]),
            digests: (lexicons: Self.lexiconsDigest, stopwords: "EDITED-SINCE"))
        #expect(ask(.concepts) == .unavailable(.configurationMismatch([.stopwords])))
    }

    @Test("The configuration check runs BEFORE the lens check, so the actionable reason wins")
    func configurationCheckPrecedesLens() {
        inject(makeFile(lenses: [.allTerms: (1000, 100, ["treaty": 40])]))
        defer { inject(nil) }
        // `.people` is unpriceable AND the configuration is wrong. The user can fix one of those.
        #expect(ask(.people, includeDiplomatic: false)
                == .unavailable(.configurationMismatch([.diplomaticLayer])))
    }

    // MARK: - #1373: the tagger the scope was counted with
    //
    // `inject` loads the dictionary-form reference alone. Since #1608 a scope counted without the
    // lemmatiser reads the reference counted as printed (`PrintedFormReferenceSelectionTests`);
    // with that file not loaded it is refused as it was, which is what the first test holds.

    @Test("With only the dictionary-form reference loaded, a scope counted without the lemmatiser has no comparable reference, on every word lens (#1373, #1608)")
    func noLemmatiserWithholdsEveryWordLens() {
        inject(makeFile(lenses: [.allTerms: (1000, 100, ["treaty": 40]),
                                 .topics: (1000, 100, ["treaty": 40]),
                                 .concepts: (1000, 100, ["sovereignty": 40])]))
        defer { inject(nil) }
        let unlemmatised = NaturalLanguageHealth(lemmatizes: false, classifiesWords: true,
                                                 recognizesNames: true)
        for lens in [WordCloudLens.allTerms, .topics, .concepts] {
            // The control first: the same lens with a working tagger is priced — `.available`, not
            // merely some other refusal, or the control would pass on a fixture that priced nothing.
            guard case .available = ask(lens) else {
                Issue.record("\(lens.rawValue): the control is not priced with a working tagger — \(ask(lens))")
                continue
            }
            #expect(ask(lens, languageAnalysis: unlemmatised)
                    == .unavailable(.languageAnalysisUnavailable),
                    "\(lens.rawValue): printed forms scored against lemma counts")
        }
    }

    @Test("A part-of-speech lens counted without lexical classes has no comparable reference")
    func noLexicalClassesWithholdsPartOfSpeechLenses() {
        inject(makeFile(lenses: [.allTerms: (1000, 100, ["treaty": 40]),
                                 .topics: (1000, 100, ["treaty": 40])]))
        defer { inject(nil) }
        let unclassified = NaturalLanguageHealth(lemmatizes: true, classifiesWords: false,
                                                 recognizesNames: true)
        #expect(ask(.topics, languageAnalysis: unclassified)
                == .unavailable(.languageAnalysisUnavailable))
        // All terms does not read the lexical classes, so the same verdict leaves it priced.
        let allTerms = ask(.allTerms, languageAnalysis: unclassified)
        guard case .available = allTerms else {
            Issue.record("All terms should stay priced without lexical classes — \(allTerms)")
            return
        }
    }

    @Test("An entity lens stays 'not priced' when names fail: that is its answer whatever the tagger does")
    func entityLensKeepsItsStructuralAnswer() {
        inject(makeFile(lenses: [.allTerms: (1000, 100, ["treaty": 40])]))
        defer { inject(nil) }
        let nameless = NaturalLanguageHealth(lemmatizes: true, classifiesWords: true,
                                             recognizesNames: false)
        #expect(ask(.people, languageAnalysis: nameless) == .unavailable(.lensNotPriced(.people)))
    }

    @Test("The tagger check runs BEFORE the configuration check: no setting would fix it")
    func languageAnalysisPrecedesConfiguration() {
        inject(makeFile(lenses: [.allTerms: (1000, 100, ["treaty": 40]),
                                 .topics: (1000, 100, ["treaty": 40])]))
        defer { inject(nil) }
        // A part-of-speech lens counted without lexical classes, under a setting that differs: both
        // are wrong. A mismatch message would tell the reader to restore a setting, and restoring
        // it would only reveal the second refusal.
        //
        // Until #1608 this test asked with no lemmatiser, and passed since for another reason: its
        // fixture loads no printed-form reference (the next test). The case in which the order of
        // the two checks decides the answer is this one.
        let unclassified = NaturalLanguageHealth(lemmatizes: true, classifiesWords: false,
                                                 recognizesNames: true)
        // The controls, one for each wrong thing: priced when neither is wrong, and refused for
        // the setting when only the setting is.
        guard case .available = ask(.topics) else {
            Issue.record("Topics is not priced under a working tagger and the artifact's settings")
            return
        }
        #expect(ask(.topics, includeDiplomatic: false)
                == .unavailable(.configurationMismatch([.diplomaticLayer])))
        #expect(ask(.topics, includeDiplomatic: false, languageAnalysis: unclassified)
                == .unavailable(.languageAnalysisUnavailable))
    }

    @Test("With only the dictionary-form reference loaded, a scope counted without the lemmatiser is refused for the tagger and not for a setting (#1608)")
    func missingPrintedReferencePrecedesConfiguration() {
        inject(makeFile(lenses: [.allTerms: (1000, 100, ["treaty": 40])]))
        defer { inject(nil) }
        let unlemmatised = NaturalLanguageHealth(lemmatizes: false, classifiesWords: true,
                                                 recognizesNames: true)
        // With the reference counted as printed loaded, this scope reads it, and a setting that
        // differs is a mismatch like any other
        // (`PrintedFormReferenceSelectionTests.settingsStillApplyToThePrintedReference`). With it
        // not loaded there is nothing the settings could be compared with: restoring the setting
        // would rank nothing, so the refusal is the one no setting fixes.
        #expect(ask(.allTerms, includeDiplomatic: false, languageAnalysis: unlemmatised)
                == .unavailable(.languageAnalysisUnavailable))
    }

    @Test("A missing artifact still reads as missing, whatever the tagger did")
    func absenceStillWinsOverTheTagger() {
        inject(nil)
        let unlemmatised = NaturalLanguageHealth(lemmatizes: false, classifiesWords: false,
                                                 recognizesNames: false)
        #expect(ask(.allTerms, languageAnalysis: unlemmatised) == .unavailable(.noArtifact))
    }
}

// MARK: - KeynessBaselineArtifactTests

/// The shipped `keyness-baseline.json` itself.
///
/// This suite exists because the loader's own tests inject their fixtures and so cannot see the
/// bundle at all. The artifact reaches the app through an XcodeGen resource enrolment, and a
/// resource that never got enrolled produces no build error, no warning and no crash — only a
/// keyness feature that silently reports itself unavailable on every device. Reading it here is
/// the only thing that fails when that happens. (Verified by doing it: with the file removed and
/// the project regenerated, both platforms still built and only this suite went red.)
///
/// It decodes the file directly rather than through ``BundledKeynessBaseline``, so it shares no
/// state with the injection suite above and cannot be perturbed by it.
@Suite("Keyness baseline artifact")
struct KeynessBaselineArtifactTests {

    private func bundledData(_ resource: String) throws -> Data {
        let url = try #require(
            Bundle.main.url(forResource: resource, withExtension: "json"),
            "\(resource).json is not in the app bundle. If it was just regenerated, it needs `xcodegen generate` to be enrolled — followed by `git checkout -- FRUSExplorer.xcodeproj/xcshareddata/xcschemes/`."
        )
        return try Data(contentsOf: url)
    }

    private func loadBundledFile() throws -> KeynessBaselineFile {
        try JSONDecoder().decode(KeynessBaselineFile.self, from: bundledData("keyness-baseline"))
    }

    @Test("The bundled artifact decodes and covers every lens the tokenizer can price")
    func bundledArtifactDecodes() throws {
        let file = try loadBundledFile()
        #expect(file.version == 1)
        // `.allTerms` is the lens `WordCloudView` opens on and `.descriptors` is one the picker
        // offers; either missing would mean keyness is silently unavailable on a lens a researcher
        // can select. The three entity lenses are absent by construction.
        #expect(Set(file.lenses.keys)
                == Set(["allTerms", "descriptors", "concepts", "topics", "actions", "sentiment"]))
        for entity in [WordCloudLens.people, .places, .organizations] {
            #expect(file.lenses[entity.rawValue] == nil,
                    "\(entity) is an entity lens the multi-lens tokenizer refuses; a baseline for it would mean the generator changed")
        }
    }

    @Test("It was generated over the WHOLE corpus, not a subset")
    func generatedOverTheWholeCorpus() throws {
        let file = try loadBundledFile()
        struct Entry: Decodable { let volumeId: String }
        let manifest = try JSONDecoder().decode([Entry].self, from: bundledData("manifest"))
        // The real guard against a partial VOLUMES_DIR. A magnitude threshold cannot do this job:
        // scaled linearly, every lens clears any plausible token floor at a quarter of the corpus.
        #expect(file.provenance.volumeCount == manifest.count,
                "the baseline covers \(file.provenance.volumeCount) of the manifest's \(manifest.count) shippable volumes")
        #expect(file.provenance.tuning == .standard)
        #expect(file.configuration.includeDiplomatic)
        #expect(file.configuration.tuning == .standard)
    }

    @Test("It is the companion of the shipped cloud vectors, not a piecemeal refresh")
    func matchesTheCloudVectors() throws {
        let file = try loadBundledFile()
        let core = try JSONDecoder().decode(CloudVectorsFile.self, from: bundledData("cloud-vectors-core"))
        // All three come out of one `pack()` call. A divergence means someone refreshed one artifact
        // of the set — which is exactly how the reference and the cloud stop describing one corpus.
        #expect(file.generated == core.generated)
        #expect(file.provenance == core.provenance)
    }

    @Test("The configuration is pinned to the payloads actually in the bundle")
    func configurationPinsTheBundledPayloads() throws {
        let file = try loadBundledFile()
        #expect(file.configuration.lexiconsDigest
                == WordCloudPayloadDigest.digest(of: try bundledData("word-cloud-lexicons")),
                "word-cloud-lexicons.json has changed since the baseline was generated — rerun CloudVectorsGenerator, or every term added to the lexicon will score against a reference count of zero")
        #expect(file.configuration.stopwordsDigest
                == WordCloudPayloadDigest.digest(of: try bundledData("word-cloud-stopwords")),
                "word-cloud-stopwords.json has changed since the baseline was generated — rerun CloudVectorsGenerator")
    }

    @Test("Every lens has a real corpus behind it, with a frequency-only membership rule")
    func lensesAreWellFormed() throws {
        let file = try loadBundledFile()
        #expect(file.termsPerLens == 20_000,
                "the retention budget is a shipped property, not an implementation detail — a test that reads it from the constant it is testing proves nothing")
        for (name, lens) in file.lenses {
            #expect(!lens.terms.isEmpty, "\(name) retained no terms")
            #expect(lens.distinctTerms >= lens.terms.count)
            #expect(lens.totalTokens >= lens.terms.values.reduce(0, +))
            // The tie band is retained whole, so a lens may hold slightly MORE than the budget —
            // never dramatically more, and never fewer unless its whole vocabulary fits.
            #expect(lens.terms.count >= min(file.termsPerLens, lens.distinctTerms))
            #expect(lens.terms.count <= file.termsPerLens * 2)
            // Membership depends only on frequency: everything retained is at or above the cutoff.
            #expect(lens.terms.values.min() == lens.cutoffCount,
                    "\(name): the cut did not land on a count boundary")
        }
    }

    @Test("The head of the distribution is priced, not the tail")
    func retainsTheHead() throws {
        let file = try loadBundledFile()
        let allTerms = try #require(file.lenses["allTerms"])
        // Truncation keeps the most frequent terms. Measured on the shipped artifact this is
        // 0.981; a sort-direction slip produces ~0.0002. The gate is tight because a loose one
        // (0.80) would also pass an artifact truncated at ~2,200 terms — a 9x silent reduction.
        let priced = Double(allTerms.terms.values.reduce(0, +)) / Double(allTerms.totalTokens)
        #expect(priced > 0.97, "the retained terms price only \(priced) of the corpus")
    }

    @Test("The generator's bytes are exactly what the app reads back")
    func writerReaderByteParity() throws {
        let onDisk = try bundledData("keyness-baseline")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]        // what CloudVectorsRunner.writeBaseline uses
        let reEncoded = try encoder.encode(try loadBundledFile())
        // Decode-then-encode reproducing the file byte for byte is the only thing that would catch a
        // field the writer emits and the reader silently drops. A fixture round-trip cannot: with
        // synthesized Codable and no CodingKeys, encode∘decode is identity by construction.
        #expect(reEncoded == onDisk,
                "re-encoding the decoded artifact did not reproduce it — the app's model and the generator's output have diverged")
    }
}
