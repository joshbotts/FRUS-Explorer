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

import Testing
import Foundation
@testable import WordCloudKit

/// #1373: the tagger warm-up, its canary, and the lens rules read from the canary's verdict.
///
/// ## What this suite can and cannot catch, and where
/// It runs under `swift test` on the macOS host, where `NLTagger` tags normally with or without a
/// warm-up — so the runtime tests here are CONTROLS on the host: they pin that the warm-up asks for
/// all three schemes in the measured order and that the canary agrees with the tokenizer, but they
/// cannot fail for the iOS 27.0 first-use bug itself. That guard is
/// `FRUSExplorerTests/WordCloudLensTests`, which runs in the app on an iOS 27.0 simulator.
///
/// The rule tests (``supports``, ``countsAsDesigned`` and which runtimes ask for the assets) are
/// pure and fail anywhere.
///
/// Version history:
///   1.0 — #1373: initial implementation
///   1.1 — #1373 review round 1: which runtimes ask for the assets; the scheme list is pinned on the
///          host; the canary's re-run reads the verdict first
@Suite("WordCloudKit — tagger readiness and the lens rules (#1373)")
struct NaturalLanguageReadinessTests {

    // MARK: - The lens rules, one fixture per failed capability

    @Test("Without names, only the three entity lenses are unsupported")
    func namesFailureRemovesOnlyEntityLenses() {
        let health = NaturalLanguageHealth(lemmatizes: true, classifiesWords: true, recognizesNames: false)
        let unsupported = WordCloudLens.allCases.filter { !health.supports($0) }
        #expect(Set(unsupported) == [.people, .places, .organizations])
    }

    @Test("Without lexical classes, only the three part-of-speech lenses are unsupported")
    func classesFailureRemovesOnlyPartOfSpeechLenses() {
        let health = NaturalLanguageHealth(lemmatizes: true, classifiesWords: false, recognizesNames: true)
        let unsupported = WordCloudLens.allCases.filter { !health.supports($0) }
        #expect(Set(unsupported) == [.topics, .actions, .descriptors])
    }

    @Test("Without lemmas every lens is still supported — it counts printed forms — but no word lens counts as designed")
    func lemmaFailureKeepsLensesButNotTheirDesign() {
        let health = NaturalLanguageHealth(lemmatizes: false, classifiesWords: true, recognizesNames: true)
        #expect(WordCloudLens.allCases.allSatisfy { health.supports($0) })
        let asDesigned = Set(WordCloudLens.allCases.filter { health.countsAsDesigned(for: $0) })
        // The entity lenses never lemmatise, so a lemma failure leaves them exactly as designed.
        #expect(asDesigned == [.people, .places, .organizations])
    }

    @Test("A fully working tagger supports every lens as designed, and nothing else does")
    func fullyWorkingSupportsEverything() {
        #expect(NaturalLanguageHealth.fullyWorking.isFullyWorking)
        #expect(WordCloudLens.allCases.allSatisfy {
            NaturalLanguageHealth.fullyWorking.supports($0)
                && NaturalLanguageHealth.fullyWorking.countsAsDesigned(for: $0)
        })
        let partial = [
            NaturalLanguageHealth(lemmatizes: false, classifiesWords: true, recognizesNames: true),
            NaturalLanguageHealth(lemmatizes: true, classifiesWords: false, recognizesNames: true),
            NaturalLanguageHealth(lemmatizes: true, classifiesWords: true, recognizesNames: false),
        ]
        #expect(partial.allSatisfy { !$0.isFullyWorking })
    }

    @Test("Only a runtime from 27 on asks for the tagger's assets; below it the warm-up does not wait")
    func assetRequestsStartAtTwentySeven() {
        // One fixture each side of the line, and the line itself: iOS 26.3 is where no request
        // ever answered and the warm-up spent its whole 30 s budget in every process.
        #expect(!NaturalLanguageReadiness.asksForAssets(onMajorVersion: 26))
        #expect(NaturalLanguageReadiness.asksForAssets(onMajorVersion: 27))
        #expect(NaturalLanguageReadiness.asksForAssets(onMajorVersion: 28))
    }

    // MARK: - The warm-up and the canary, as run in this process

    @Test("The warm-up asks for all three schemes, lemma last, before the canary")
    func warmUpAsksForEverySchemeLemmaLast() {
        let warmUp = NaturalLanguageReadiness.current.warmUp
        #expect(warmUp.assetRequests.map(\.scheme) == ["LexicalClass", "NameType", "Lemma"])
        // The budget is a bound, not a target: a request that answers must not be recorded as
        // having waited for the whole of it.
        for request in warmUp.assetRequests where request.answer != .timedOut {
            #expect(request.seconds < NaturalLanguageReadiness.assetWaitBudget)
        }
    }

    @Test("On the macOS host every asset answers and the canary finds every capability")
    func macOSHostIsFullyWorking() {
        // A CONTROL on the host (see the suite note): the issue measured the macOS host tagging
        // normally, and the generator refuses to run when this is false.
        let verdict = NaturalLanguageReadiness.current
        // The line written out, not read from `asksForAssets`, so a rule that moved it fails here.
        if ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27 {
            #expect(verdict.warmUp.everyAssetAvailable,
                    "asset answers: \(verdict.warmUp.assetRequests)")
        } else {
            #expect(verdict.warmUp.assetRequests.allSatisfy { $0.answer == .notAsked },
                    "a host below 27 must not ask: \(verdict.warmUp.assetRequests)")
        }
        #expect(verdict.health == .fullyWorking)
        // The warm-up's first step, `availableTagSchemes`, is kept for its side effect — on iOS 27.0
        // it is what restored tagging — and nothing reads its answer but the record. The host lists
        // schemes, so an empty record here means the call was dropped.
        #expect(!verdict.warmUp.schemesListed.isEmpty,
                "availableTagSchemes listed nothing: \(verdict.warmUp.schemesListed)")
    }

    @Test("The canary reads the same state a second time: a verdict is sticky within a process")
    func canaryIsStable() {
        // The verdict FIRST: `runCanary()` tags through the private factory, which does not wait for
        // the warm-up, so reading it first could make the canary this process's first tagging —
        // the order the warm-up exists to prevent.
        let settled = NaturalLanguageReadiness.health
        #expect(NaturalLanguageReadiness.runCanary() == settled)
    }

    @Test("The settled verdict is readable without waiting once it exists, and equals the awaited one")
    func settledVerdictMatches() async {
        let awaited = await NaturalLanguageReadiness.verdictWhenReady()
        #expect(NaturalLanguageReadiness.settledVerdict == awaited)
    }

    /// A sentence per lens, dense in what the lens keeps.
    static let obviousSentences: [(WordCloudLens, String)] = [
        (.topics, "The diplomats negotiated a difficult treaty in Geneva."),
        (.actions, "The ministers negotiated, signed and ratified the treaty, then departed."),
        (.descriptors, "The difficult, protracted and bitter negotiations produced a fragile, temporary settlement."),
        (.people, "President Eisenhower met Prime Minister Churchill and Secretary Dulles."),
        (.places, "The delegation travelled from Washington to Geneva, then to Paris and Moscow."),
        (.organizations, "The United Nations, NATO and the World Bank debated the proposal."),
    ]

    @Test("The tokenizer keeps something exactly when the canary says the lens is supported",
          arguments: obviousSentences)
    func tokenizerAgreesWithCanary(lens: WordCloudLens, text: String) {
        var counts: [String: Int] = [:]
        WordCloudTokenizer(stopwords: [], lens: lens).accumulate(from: text, into: &counts)
        let supported = NaturalLanguageReadiness.health.supports(lens)
        #expect(!counts.isEmpty == supported,
                "\(lens.rawValue): the canary says supported=\(supported) but the tokenizer kept \(counts)")
    }
}
