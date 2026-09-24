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
import NaturalLanguage
import os

// MARK: - NaturalLanguageHealth

/// What this process's on-device language tagger actually does, measured by tagging two fixed
/// sentences — never by asking the framework what it has.
///
/// ## Why it is measured (#1373)
/// On the iOS 27.0 simulators a Topics cloud read "0 terms from 4,591 documents": `NLTagger`
/// tagged every word `OtherWord` and returned no lemma, and nothing in the app could tell. Two
/// facts make a *check* necessary rather than a fix alone:
///
/// - **A scheme that fails on its first use in a process keeps failing for the rest of it.** No
///   later call — `availableTagSchemes`, `requestAssets`, waiting — brings it back. So the only
///   honest thing a process can do after a failed first use is say so.
/// - **`availableTagSchemes` is not a guard.** Before any tagging it lists `Lemma` and omits
///   `LexicalClass` on a runtime where both then work; after a failed tagging it lists both and
///   neither works.
///
/// So ``NaturalLanguageReadiness`` tags ``NaturalLanguageReadiness/canaryWordSentence`` and
/// ``NaturalLanguageReadiness/canaryNameSentence`` once, after its warm-up, and records here what
/// came back. The three capabilities fail independently — measured on a freshly booted iOS 27.0
/// simulator, the first process lost its lemmatiser while its lexical classes and names worked —
/// so they are three flags, not one.
///
/// Version history:
///   1.0 — #1373: initial implementation
public struct NaturalLanguageHealth: Sendable, Equatable, Codable {

    /// The lemmatiser reduced at least one word of the canary sentence to a different dictionary
    /// form ("informed" → "inform"). Without it every lens counts words as printed, and those
    /// counts are not comparable with the bundled keyness reference, which was counted in lemmas.
    public let lemmatizes: Bool

    /// The lexical-class tagger found a noun in the canary sentence. The Topics, Actions and
    /// Descriptors lenses keep only words it classifies, so without it they count nothing.
    public let classifiesWords: Bool

    /// The name-type tagger found a person, place or organization in the canary sentence. The
    /// People, Places and Organizations lenses keep only what it recognises.
    public let recognizesNames: Bool

    /// Creates a verdict from the three measured capabilities.
    /// - Parameters:
    ///   - lemmatizes: Whether the lemmatiser produced a dictionary form.
    ///   - classifiesWords: Whether the lexical-class tagger found a noun.
    ///   - recognizesNames: Whether the name-type tagger found a name.
    public init(lemmatizes: Bool, classifiesWords: Bool, recognizesNames: Bool) {
        self.lemmatizes = lemmatizes
        self.classifiesWords = classifiesWords
        self.recognizesNames = recognizesNames
    }

    /// A tagger whose three capabilities all work — the verdict on the macOS host and on a warmed
    /// iOS 27.0 simulator.
    public static let fullyWorking = NaturalLanguageHealth(
        lemmatizes: true, classifiesWords: true, recognizesNames: true)

    /// `true` when all three capabilities work.
    public var isFullyWorking: Bool { lemmatizes && classifiesWords && recognizesNames }

    /// Whether `lens` can draw a cloud in this process.
    ///
    /// The entity lenses need names and the part-of-speech lenses need lexical classes: without
    /// them each keeps nothing, which is the zero cloud #1373 found. All Terms, Concepts and
    /// Sentiment need neither — without a lemmatiser they still count every word as printed, which
    /// is a true count of a different thing, so they stay available and the view says how they
    /// were counted. Exhaustive on purpose: a new lens has to decide which tagger it depends on.
    public func supports(_ lens: WordCloudLens) -> Bool {
        switch lens {
        case .people, .places, .organizations: return recognizesNames
        case .topics, .actions, .descriptors: return classifiesWords
        case .allTerms, .concepts, .sentiment: return true
        }
    }

    /// Whether counts made under `lens` in this process are the counts the lens is designed to
    /// make: every tagger the lens reads worked.
    ///
    /// Stricter than ``supports(_:)`` for the word lenses, which also read the lemmatiser. A word
    /// cloud counted without lemmas is a true count of printed forms, but it is not what the same
    /// scope yields on a device whose lemmatiser works, so it must not be cached for another
    /// process to reuse, and it is not comparable with the bundled keyness reference, which was
    /// counted in lemmas — `negotiations` would score as a word the corpus never used. The entity
    /// lenses do not lemmatise, so for them this is ``supports(_:)``.
    public func countsAsDesigned(for lens: WordCloudLens) -> Bool {
        supports(lens) && (lens.isEntity || lemmatizes)
    }
}

// MARK: - NaturalLanguageWarmUp

/// What the warm-up did before this process tagged anything, kept so a test and a log can
/// say which step answered and which did not.
///
/// Version history:
///   1.0 — #1373: initial implementation
public struct NaturalLanguageWarmUp: Sendable, Equatable {

    /// How `NLTagger.requestAssets(for:tagScheme:)` answered one scheme.
    public enum AssetAnswer: String, Sendable, Equatable {
        /// The framework reports the scheme's assets are on this device.
        case available
        /// The framework reports they are not, and will not be fetched.
        case notAvailable
        /// The request failed with an error.
        case error
        /// No answer arrived before ``NaturalLanguageReadiness/assetWaitBudget`` ran out.
        case timedOut
    }

    /// One `requestAssets` call and its answer.
    public struct AssetRequest: Sendable, Equatable {
        /// The tag scheme's raw value (`LexicalClass`, `NameType`, `Lemma`).
        public let scheme: String
        /// How the request was answered.
        public let answer: AssetAnswer
        /// Seconds from the call to its answer, or to the deadline when it timed out.
        public let seconds: Double
    }

    /// What `NLTagger.availableTagSchemes(for: .word, language: .english)` listed, sorted.
    public let schemesListed: [String]
    /// Every asset request, in the order made.
    public let assetRequests: [AssetRequest]
    /// Seconds the whole warm-up took.
    public let seconds: Double

    /// `true` when every scheme was requested and every request answered ``AssetAnswer/available``.
    public var everyAssetAvailable: Bool {
        assetRequests.count == NaturalLanguageReadiness.warmedSchemes.count
            && assetRequests.allSatisfy { $0.answer == .available }
    }

    /// Whether the request for `scheme` answered ``AssetAnswer/available`` within the budget.
    ///
    /// Measured on iOS 27.0, per scheme: every request that answered `available` was followed by
    /// that scheme working, and every lemma request that did not answer was followed by no lemmas —
    /// in the command-line probe after fresh boots and in the app alike — while the other two
    /// schemes of the same process worked. So a test may hold a scheme to working exactly when its
    /// own request answered, which is a sharper guard than requiring all three.
    public func answeredAvailable(for scheme: NLTagScheme) -> Bool {
        assetRequests.contains { $0.scheme == scheme.rawValue && $0.answer == .available }
    }
}

// MARK: - NaturalLanguageReadiness

/// Makes the language tagger ready before this process first tags anything, and reports what it
/// can then actually do.
///
/// ## Every `NLTagger` in the app comes from here
/// ``tagger(tagSchemes:)`` waits for the warm-up and the canary before it hands out a tagger, so
/// no tagging can be the process's first — and the only other constructor, used by the canary
/// itself, is private to this file. `NaturalLanguageReadinessScanTests` fails the suite if an
/// `NLTagger` is constructed anywhere else in the app's sources. The app's callers that tag —
/// the Word Cloud's load, `WordFrequencyService`, the Search collocation panel (iOS and macOS), the
/// related documents' shared terms and the collection exports' word cloud — await
/// ``verdictWhenReady()`` first, so the warm-up never holds a thread they care about, the main
/// thread above all; ``tagger(tagSchemes:)`` is what makes the order a guarantee for anything that
/// does not (the generator, a test).
///
/// ## Not at launch, on purpose
/// #1373 proposed starting the warm-up first thing at launch. Measured in the app on the iOS 27.0
/// iPhone 17e simulator (one launch per test run, `NaturalLanguageReadinessWarmUpTests` printing
/// what the warm-up saw, the two arrangements run in alternating blocks on the same simulator),
/// starting it from `FRUSExplorerApp.init()` lost the lemmatiser in 7 of 14 launches:
/// `availableTagSchemes` listed no `Lemma`, the lemma request never answered, and the canary found
/// no lemmas. Run on first use instead, it lost it in 1 of the 14 launches whose warm-up was
/// recorded (a further block of six went unrecorded, and one of those took the full 30 s budget,
/// which is what a lost lemma request costs). Lexical classes and names answered in all 28 recorded
/// launches. So the warm-up runs on first use, and the section below is what it does then. It is
/// not a cure: the canary is what catches the launches it does not save.
///
/// ## What the warm-up does, and what each step was measured to do
/// Measured 2026-09-24 with a command-line probe spawned in the simulators, one fresh process per
/// run (so the process's first tagging was under the probe's control):
///
/// 1. **`availableTagSchemes(for: .word, language: .english)`, synchronously.** On an iOS 27.0
///    simulator that had been up for some minutes, calling it first restored every scheme in 40 of
///    41 processes, where tagging words first lost them in 20 of 20; the one exception listed no
///    `Lemma`. It is not enough right after a boot: in the first two processes after each of three
///    fresh boots it listed no `Lemma`, and every scheme failed in all six.
/// 2. **`requestAssets(for: .english, tagScheme:)` for `.lexicalClass`, `.nameType` and `.lemma`,
///    one at a time, each awaited.** When the list names `Lemma`, each answers `available` in
///    4–34 ms. After a fresh boot the first answer took 12.2–13.9 s (four boots) and the lemma
///    request did not answer at all in that process — not in 30 s (three boots), not in 120 s
///    (one) — while the next process got all three at once. So after a fresh boot this step saves
///    lexical classes and names for the current process, and the lemmatiser for the next one.
///    Lemma is asked last because it is the one that hangs. Firing the three **without** awaiting
///    them, and without step 1, was measured and rejected: the tagger then ran while they were in
///    flight and lost its lemmas (two of two processes).
/// 3. **The canary** (``runCanary()``), after both — never instead of them, since a failed first
///    use cannot be undone.
///
/// What is left for the canary to catch is therefore the first process after a simulator boots
/// (above), a runtime whose assets never answer (iOS 26.3, below), and whatever a physical device
/// does, which was not measured. `Planning/DEVELOPMENT-PLAN.md`'s #1373 entry has every count.
///
/// The wait is bounded by ``assetWaitBudget`` in total, because the answer may never come: on the
/// iOS 26.3 simulator no request answered in 30 s, and nothing — neither call, in either order —
/// made that runtime tag at all. That runtime's verdict is "nothing works", and the canary says so.
///
/// Not measured: a physical device. The macOS host tags normally with or without either call.
///
/// Version history:
///   1.0 — #1373: initial implementation
public enum NaturalLanguageReadiness {

    /// The schemes the warm-up asks for, in the order asked. Lemma last: after a fresh boot it is
    /// the request that never answers, and asking it first would spend the whole budget on it
    /// before the two that do answer.
    public static let warmedSchemes: [NLTagScheme] = [.lexicalClass, .nameType, .lemma]

    /// The longest the warm-up waits for asset answers, in total, before it tags anyway.
    ///
    /// Thirty seconds covers the slowest answer measured to arrive at all: the first request after a
    /// fresh boot answered in 12.2–14.3 s on an idle machine and in 26.0 s while the host was
    /// building (six boots). Waiting longer buys nothing measured: the request that did not answer
    /// in 30 s did not answer in 120 s either. The wait is felt once per process, by whatever first
    /// needs the tagger — a Word Cloud's spinner, not a blocked main thread, since those callers
    /// await ``verdictWhenReady()``. A warm simulator answers all three in under 35 ms; the iOS 26.3
    /// simulator, where nothing ever answers, spends the whole budget every process.
    public static let assetWaitBudget: TimeInterval = 30

    /// The sentence the word canary tags. A working tagger (measured on the macOS host) classes
    /// `Secretary`, `Ambassador` and `negotiations` as nouns and reduces four words to dictionary
    /// forms that differ from the printed ones: `informed`, `negotiations`, `had`, `failed`.
    public static let canaryWordSentence =
        "The Secretary informed the Ambassador that the negotiations had failed."

    /// The sentence the name canary tags, naming two people and a place. The canary asks only that
    /// some name be tagged: a working recognizer (measured on the macOS host) tags `Eisenhower` as
    /// a person but `Churchill` as a place and `London` as an organization, so a check on which kind
    /// of name would be testing the model's accuracy, not whether it runs.
    public static let canaryNameSentence =
        "President Eisenhower met Prime Minister Churchill in London."

    /// The warm-up and the canary's verdict, taken together because the canary must follow the
    /// warm-up and neither may run twice.
    public struct Verdict: Sendable, Equatable {
        /// What the warm-up did.
        public let warmUp: NaturalLanguageWarmUp
        /// What the canary found the tagger could then do.
        public let health: NaturalLanguageHealth
    }

    /// The verdict once it exists; read without blocking by ``settledVerdict``.
    private static let settled = OSAllocatedUnfairLock<Verdict?>(initialState: nil)

    /// The warm-up and the canary, run exactly once per process.
    ///
    /// A `static let` because Swift runs its initialiser once and makes every concurrent reader
    /// wait for it — which is precisely the "nothing tags before this finishes" rule.
    private static let verdict: Verdict = {
        let warmUp = performWarmUp()
        let health = runCanary()
        let result = Verdict(warmUp: warmUp, health: health)
        settled.withLock { $0 = result }
        #if DEBUG
        print("[NaturalLanguageReadiness] listed \(warmUp.schemesListed); assets "
              + warmUp.assetRequests.map { "\($0.scheme)=\($0.answer.rawValue)@\(String(format: "%.3f", $0.seconds))s" }
                  .joined(separator: " ")
              + "; canary lemmas=\(health.lemmatizes) classes=\(health.classifiesWords) names=\(health.recognizesNames)")
        #endif
        return result
    }()

    // MARK: - Public surface

    /// The verdict, waiting for it if the warm-up is still running. Blocks the calling thread for
    /// at most ``assetWaitBudget`` plus the canary; never call it from the main thread — use
    /// ``verdictWhenReady()`` there.
    public static var current: Verdict { verdict }

    /// What the tagger can do in this process, waiting for the verdict if necessary (see
    /// ``current`` for the blocking caveat).
    public static var health: NaturalLanguageHealth { verdict.health }

    /// The verdict if it has settled, without waiting; `nil` while the warm-up is still running.
    public static var settledVerdict: Verdict? { settled.withLock { $0 } }

    /// The verdict, awaited without blocking the caller's thread.
    public static func verdictWhenReady() async -> Verdict {
        if let settledVerdict { return settledVerdict }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: verdict)
            }
        }
    }

    /// A tagger for `tagSchemes`, handed out only after the warm-up and the canary have run.
    ///
    /// The one way the app constructs an `NLTagger`. Waiting here is what guarantees the warm-up
    /// precedes the process's first tagging even when a tokenizer is the first thing to run.
    public static func tagger(tagSchemes: [NLTagScheme]) -> NLTagger {
        _ = verdict
        return makeTagger(tagSchemes: tagSchemes)
    }

    // MARK: - Warm-up

    /// Runs the two warm-up calls in the measured order. See the type's documentation.
    private static func performWarmUp() -> NaturalLanguageWarmUp {
        let started = DispatchTime.now()
        let listed = NLTagger.availableTagSchemes(for: .word, language: .english)
            .map(\.rawValue).sorted()

        let deadline = started + assetWaitBudget
        var requests: [NaturalLanguageWarmUp.AssetRequest] = []
        for scheme in warmedSchemes {
            let asked = DispatchTime.now()
            let answer = OSAllocatedUnfairLock<NLTagger.AssetsResult?>(initialState: nil)
            let answered = DispatchSemaphore(value: 0)
            NLTagger.requestAssets(for: .english, tagScheme: scheme) { result, _ in
                answer.withLock { $0 = result }
                answered.signal()
            }
            let outcome: NaturalLanguageWarmUp.AssetAnswer
            if answered.wait(timeout: deadline) == .timedOut {
                outcome = .timedOut
            } else {
                switch answer.withLock({ $0 }) {
                case .available?: outcome = .available
                case .notAvailable?: outcome = .notAvailable
                default: outcome = .error
                }
            }
            requests.append(.init(scheme: scheme.rawValue, answer: outcome,
                                  seconds: seconds(from: asked)))
        }
        return NaturalLanguageWarmUp(schemesListed: listed, assetRequests: requests,
                                     seconds: seconds(from: started))
    }

    /// Seconds elapsed since `start`.
    private static func seconds(from start: DispatchTime) -> Double {
        Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000
    }

    // MARK: - Canary

    /// Tags the two canary sentences with the tokenizer's own schemes and options and reports what
    /// came back.
    ///
    /// The word walk is `WordCloudTokenizer`'s: `.lemma` enumeration by word with the lexical
    /// class read per token. The name walk is its entity path, `.nameType` with `.joinNames`.
    /// Internal rather than private so a test can run it again and compare it with the verdict;
    /// the result is sticky within a process, so a second run reads the same state.
    static func runCanary() -> NaturalLanguageHealth {
        var lemmatizes = false
        var classifiesWords = false
        let words = canaryWordSentence
        let wordTagger = makeTagger(tagSchemes: [.lemma, .lexicalClass])
        wordTagger.string = words
        wordTagger.setLanguage(.english, range: words.startIndex..<words.endIndex)
        wordTagger.enumerateTags(
            in: words.startIndex..<words.endIndex, unit: .word, scheme: .lemma,
            options: [.omitPunctuation, .omitWhitespace, .omitOther]
        ) { tag, range in
            if let lemma = tag?.rawValue, !lemma.isEmpty,
               lemma.lowercased() != words[range].lowercased() {
                lemmatizes = true
            }
            if wordTagger.tag(at: range.lowerBound, unit: .word, scheme: .lexicalClass).0 == .noun {
                classifiesWords = true
            }
            return true
        }

        var recognizesNames = false
        let names = canaryNameSentence
        let nameTagger = makeTagger(tagSchemes: [.nameType])
        nameTagger.string = names
        nameTagger.setLanguage(.english, range: names.startIndex..<names.endIndex)
        nameTagger.enumerateTags(
            in: names.startIndex..<names.endIndex, unit: .word, scheme: .nameType,
            options: [.omitPunctuation, .omitWhitespace, .omitOther, .joinNames]
        ) { tag, _ in
            if tag == .personalName || tag == .placeName || tag == .organizationName {
                recognizesNames = true
            }
            return true
        }
        return NaturalLanguageHealth(lemmatizes: lemmatizes, classifiesWords: classifiesWords,
                                     recognizesNames: recognizesNames)
    }

    /// The only `NLTagger` initialiser call in the app. Private: everything outside this file goes
    /// through ``tagger(tagSchemes:)``, which waits for the warm-up first.
    private static func makeTagger(tagSchemes: [NLTagScheme]) -> NLTagger {
        NLTagger(tagSchemes: tagSchemes)
    }
}
