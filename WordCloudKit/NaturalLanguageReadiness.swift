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
/// - **A scheme that fails on its first use in a process kept failing for the rest of it** on the
///   iOS 27.0 simulators. No later call — `availableTagSchemes`, `requestAssets`, waiting —
///   brought it back there. Whether a physical device behaves the same is what #1539's re-check
///   and its release log find out (see ``NaturalLanguageReadiness``).
/// - **`availableTagSchemes` is not a guard.** Before any tagging it lists `Lemma` and omits
///   `LexicalClass` on a runtime where both then work; after a failed tagging it lists both and
///   neither works.
///
/// So ``NaturalLanguageReadiness`` tags ``NaturalLanguageReadiness/canaryWordSentence`` and
/// ``NaturalLanguageReadiness/canaryNameSentence`` after its warm-up, and again with fresh taggers
/// whenever the app returns to the foreground while a capability is missing (#1539), and records here
/// what came back. The three capabilities fail independently — measured on a freshly booted iOS 27.0
/// simulator, the first process lost its lemmatiser while its lexical classes and names worked —
/// so they are three flags, not one.
///
/// Version history:
///   1.0 — #1373: initial implementation
///   1.1 — #1539: ``improves(on:)``, the rule a re-check's verdict must pass to replace this one
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

    /// Whether this verdict keeps every capability `other` has and adds at least one (#1539).
    ///
    /// The rule a re-check's verdict must pass to replace the process's verdict. A verdict that gains
    /// one capability and loses another is not adopted: a lens that was drawing would stop part way
    /// through a session for a gain somewhere else, and nothing measured says the later reading is
    /// the truer one.
    /// - Parameter other: The verdict the process holds now.
    /// - Returns: `true` when this verdict is a strict improvement on `other`.
    public func improves(on other: NaturalLanguageHealth) -> Bool {
        self != other
            && (lemmatizes || !other.lemmatizes)
            && (classifiesWords || !other.classifiesWords)
            && (recognizesNames || !other.recognizesNames)
    }

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

/// What the warm-up (or a later re-check) did before the canary ran, kept so a test and the
/// release log can say which step answered and which did not.
///
/// Version history:
///   1.0 — #1373: initial implementation
///   1.1 — #1373 review round 1: `notAsked` answers below 27; `requestedAtLaunch` and `processAge`
///   1.2 — #1539: ``trigger`` (replacing `requestedAtLaunch`), ``applicationState``, and each
///          request's ``AssetRequest/reasked`` count
public struct NaturalLanguageWarmUp: Sendable, Equatable {

    /// How `NLTagger.requestAssets(for:tagScheme:)` answered one scheme.
    public enum AssetAnswer: String, Sendable, Equatable {
        /// The framework reports the scheme's assets are on this device.
        case available
        /// The framework reports they are not, and will not be fetched.
        case notAvailable
        /// The request failed with an error.
        case error
        /// No answer arrived within ``NaturalLanguageReadiness/assetWaitBudget``. In a warm-up the app
        /// was in the foreground the whole time (a trip to the background keeps the request waiting
        /// instead); in a re-check it may have left, since a re-check keeps the verdict it has.
        case timedOut
        /// Not asked: this runtime predates the failure the requests guard against, so waiting on
        /// them could only cost time (see ``NaturalLanguageReadiness/asksForAssets(onMajorVersion:)``).
        case notAsked
    }

    /// What started a warm-up or a re-check (#1539).
    public enum Trigger: String, Sendable, Equatable {
        /// The app asked at launch — the Mac's `FRUSExplorerApp.init`, which is never a background
        /// launch.
        case launch
        /// The app's first time in the foreground on iPhone and iPad, so a background launch (a
        /// CloudKit push, a background task, a download finishing) never starts it.
        case firstForeground
        /// A tagger or the verdict was asked for before the app started it — a generator, a test,
        /// or a surface reached before the app's first foreground.
        case firstUse
        /// A later return to the foreground, checking again a verdict that lacked a capability.
        case recheck
    }

    /// Where the app was in its lifecycle, as the app last reported it (#1539).
    public enum ApplicationState: String, Sendable, Equatable {
        /// In the foreground: the app's last report was that it became active.
        case active
        /// The app's last report was that it entered the background.
        case background
        /// Nothing has reported a lifecycle: a generator, a test before its host is active, or a
        /// Mac before its first activation.
        case unreported
    }

    /// One scheme's `requestAssets` call or calls, and the answer.
    public struct AssetRequest: Sendable, Equatable {
        /// The tag scheme's raw value (`LexicalClass`, `NameType`, `Lemma`).
        public let scheme: String
        /// How the request was answered.
        public let answer: AssetAnswer
        /// Seconds from the first call to its answer, or to the deadline when it timed out —
        /// including any time the app spent in the background while it waited.
        public let seconds: Double
        /// How many times the request was made again because the app came back to the foreground
        /// while it was unanswered (#1539). Zero for a request that answered or timed out within
        /// its first budget.
        public let reasked: Int

        /// Creates a record of one scheme's request.
        /// - Parameters:
        ///   - scheme: The tag scheme's raw value.
        ///   - answer: How it was answered.
        ///   - seconds: Seconds from the first call to the answer or the deadline.
        ///   - reasked: How many times it was made again on a return to the foreground.
        public init(scheme: String, answer: AssetAnswer, seconds: Double, reasked: Int = 0) {
            self.scheme = scheme
            self.answer = answer
            self.seconds = seconds
            self.reasked = reasked
        }
    }

    /// What started this warm-up or re-check.
    public let trigger: Trigger
    /// Where the app was, by its last report, when this started.
    public let applicationState: ApplicationState
    /// What `NLTagger.availableTagSchemes(for: .word, language: .english)` listed, sorted.
    public let schemesListed: [String]
    /// Every asset request, in the order made.
    public let assetRequests: [AssetRequest]
    /// Seconds the whole warm-up took.
    public let seconds: Double
    /// Seconds from this process's start to the warm-up's, read from the kernel's record of the
    /// process; `nil` if that could not be read. It is what let #1373's launch measurement say how
    /// early each arrangement ran — see the "When it starts" section of ``NaturalLanguageReadiness``.
    public let processAge: Double?

    /// `true` when every scheme was requested and every request answered ``AssetAnswer/available``.
    public var everyAssetAvailable: Bool {
        assetRequests.count == NaturalLanguageReadiness.warmedSchemes.count
            && assetRequests.allSatisfy { $0.answer == .available }
    }

    /// Whether the request for `scheme` answered ``AssetAnswer/available`` within the budget.
    ///
    /// Measured on iOS 27.0, per scheme, **in processes where nothing had tagged before the
    /// warm-up** — which the gate in ``NaturalLanguageReadiness/tagger(tagSchemes:)`` guarantees in the
    /// app: every request that answered `available` was followed by that scheme working, and every
    /// lemma request that did not answer was followed by no lemmas — in the command-line probe after
    /// fresh boots and in the app alike — while the other two schemes of the same process worked. So
    /// a test may hold a scheme to working exactly when its own request answered, which is a sharper
    /// guard than requiring all three.
    ///
    /// The precondition is load-bearing, and it is why that guard can fail at all: with the gate
    /// disabled, so that a test tagged before the warm-up, every request still answered `available`
    /// on both iOS 27.0 simulators and the canary then found no lemmas and no lexical classes. A
    /// request's answer says the assets are on the device, not that a scheme which already failed in
    /// this process will work.
    public func answeredAvailable(for scheme: NLTagScheme) -> Bool {
        assetRequests.contains { $0.scheme == scheme.rawValue && $0.answer == .available }
    }
}

// MARK: - NaturalLanguageReadiness

/// Makes the language tagger ready before this process first tags anything, reports what it can
/// then actually do, and checks again when the app returns to the foreground without it.
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
/// ## The verdict can be replaced (#1539)
/// On the owner's iPhone and iPad (iOS 27.0, build 48) Search's Collocates refused for want of a
/// lemmatiser, and after a force-quit and relaunch it worked on both — so the assets were on the
/// devices and the refusal came from a verdict fixed earlier in a long-lived process. Until #1539
/// the verdict was a `static let`, made once and kept for the life of the process. Now, whenever the
/// app becomes active while the verdict lacks a capability, the engine asks for the assets again and
/// runs the canary again with fresh taggers, and adopts the new verdict if it
/// ``NaturalLanguageHealth/improves(on:)`` the old one. So every caller reads the verdict per
/// operation (``verdictWhenReady()``, ``health``, ``settledVerdict``) and never keeps one.
/// ``revision`` counts the replacements, and ``verdictDidChangeNotification`` announces every change
/// of ``status``. Whether a re-check restores a scheme that failed earlier in the same process was
/// not measured on a device; on the iOS 27.0 simulators it did not (see ``NaturalLanguageHealth``).
/// The release log records every re-check, which is how the answer will be read.
///
/// ## When it starts (#1539)
/// On the Mac, `FRUSExplorerApp.init` calls ``beginWarmUp()`` first, as #1373 did on both
/// platforms. On iPhone and iPad it waits for the app's first time in the foreground
/// (``applicationDidBecomeActive()``): a CloudKit push, a background task or a finished download
/// launches the app in the background and runs its `init`, and a warm-up started there could be
/// suspended mid-wait and resumed hours later — the background-launch hypothesis #1539's triage
/// gave, which the owner's device result supports. A surface that asks for a tagger or the verdict
/// before then starts it itself (``NaturalLanguageWarmUp/Trigger/firstUse``); no background path in
/// the app tags, so in practice that is a generator or a test.
///
/// #1373 measured where the warm-up starts and found it made no difference it could see:
/// re-measured 2026-09-24 on the same iPhone 17e simulator (iOS 27.0, build 24A434) over 75 launches,
/// one per test run, with three arrangements rotated launch by launch rather than in blocks —
/// started from `FRUSExplorerApp.init()` (1.8–3.4 s into the process), from the search boot where
/// `WordFrequencyService` is created (2.0–6.8 s), and on the test's first use (2.4–4.7 s) — the
/// lemmatiser was lost in **7 of 25, 5 of 25 and 6 of 25** launches respectively, every time
/// because `availableTagSchemes` listed no `Lemma` and the lemma request never answered, and the
/// losses ran through the whole 27 minutes measured (2 to 28 minutes after the simulator booted).
/// Lexical classes and names worked in all 75. None of those launches was a background launch.
/// `Planning/DEVELOPMENT-PLAN.md`'s #1373 entry records the counts per arrangement.
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
///    one at a time, each awaited for up to ``assetWaitBudget`` of its own.** When the list names
///    `Lemma`, each answers `available` in 4–34 ms. After a fresh boot the first answer took
///    12.2–14.3 s on an idle machine and 26.0 s while the host was building (six boots), and the
///    lemma request did not answer at all in that process — not in 30 s (three boots), not in 120 s
///    (one) — while the next process got all three at once. Lemma is asked last because it is the
///    one that hangs. Firing the three **without** awaiting them, and without step 1, was measured
///    and rejected: the tagger then ran while they were in flight and lost its lemmas (two of two
///    processes).
/// 3. **The canary** (``runCanary()``), after both — never instead of them, since a failed first
///    use cannot be undone.
///
/// ## A request still in flight (#1539)
/// The budget is per scheme since #1539 (it was one 30 s budget shared by all three, so a slow
/// lexical-class answer left the lemma request less time), and what happens when it runs out
/// depends on where the app spent the wait:
/// - **In the background, for any part of it** — the app reported entering the background after the
///   request was made, or is there now — the verdict stays pending and the canary does not run:
///   tagging while a request is in flight is the order measured to lose lemmas, and on a device a
///   suspended process's deadline keeps running, so its wait "times out" on resume whether or not
///   the assets were ever slow. The engine waits for the answer or for the app's return to the
///   foreground, whichever comes first, and on a return asks again with a fresh budget
///   (``NaturalLanguageWarmUp/AssetRequest/reasked``). Callers awaiting the verdict wait with it.
/// - **In the foreground throughout** — the request is recorded
///   ``NaturalLanguageWarmUp/AssetAnswer/timedOut`` and the canary runs, as before #1539. That is
///   the measured case where waiting longer bought nothing (the one lemma request watched past
///   30 s did not answer in 120 s; the next process got it), and holding every tagging surface on a spinner for the
///   rest of the process would also withhold the lexical classes and names those processes kept,
///   and would hang the unit-test host in the iOS 27.0 launches that lose the lemma request. The
///   re-check above is what gives such a process another chance, on its next return to the
///   foreground.
///
/// Below 27 the requests are not made (``asksForAssets(onMajorVersion:)``): on the iOS 26.3
/// simulator no request answered in 30 s, and nothing — neither call, in either order — made that
/// runtime tag at all; the 26.4 and 26.5 simulators behave the same. Those runtimes' verdict is
/// "nothing works", and the canary says so.
///
/// ## The release log (#1539)
/// Every start, every request left pending, every verdict and every re-check is written to the
/// unified log under subsystem `bottsywattsy.FRUS-Explorer`, category `NaturalLanguageReadiness`, at
/// the default (`notice`) level, so it is kept in a release build and appears in Console and a
/// sysdiagnose. ``logLine(for:)`` builds each line from enums, scheme names, counts and seconds —
/// nothing a reader wrote or read — so the whole line is public.
///
/// Not measured: a physical device. The macOS host tags normally with or without either call.
///
/// Version history:
///   1.0 — #1373: initial implementation
///   1.1 — #1373 review round 1: `beginWarmUp()`, which the app calls at launch; no asset requests
///          below 27 (`asksForAssets(onMajorVersion:)`)
///   1.2 — #1539: the verdict lives in a ``NaturalLanguageReadinessEngine`` and can be replaced by a
///          re-check on the app's return to the foreground; iPhone and iPad start the warm-up on
///          the first foreground; a request left unanswered by a trip to the background keeps the
///          verdict pending; a budget per scheme; the release log; ``status`` and ``revision``
public enum NaturalLanguageReadiness {

    /// The schemes the warm-up asks for, in the order asked. Lemma last: after a fresh boot it is
    /// the request that never answers, and asking it first would spend its budget before the two
    /// that do answer had been asked.
    public static let warmedSchemes: [NLTagScheme] = [.lexicalClass, .nameType, .lemma]

    /// The longest the warm-up waits for one scheme's asset answer while the app stays in the
    /// foreground, before it records the request as timed out.
    ///
    /// Thirty seconds covers the slowest answer measured to arrive at all: the first request after a
    /// fresh boot answered in 12.2–14.3 s on an idle machine and in 26.0 s while the host was
    /// building (six boots). Waiting longer buys nothing measured: the request that did not answer
    /// in 30 s did not answer in 120 s either. A warm simulator answers each request in 4–34 ms.
    ///
    /// Per scheme since #1539, so the worst case is three budgets. Spent only where the requests
    /// are asked at all (``asksForAssets(onMajorVersion:)``), and in the background of the app's
    /// launch or first foreground, so a reader meets it only by opening a tagging surface within it
    /// — and then as a spinner, not a blocked main thread, since those callers await
    /// ``verdictWhenReady()``.
    public static let assetWaitBudget: TimeInterval = 30

    /// Whether the warm-up asks for the tagger's assets on a runtime whose major version is `major`.
    ///
    /// Only from 27, because that is where the failure the requests guard against was measured: an
    /// iOS 27.0 scheme whose first use in a process fails stays failed, and the requests are part of
    /// what prevents it. Below 27 they bought nothing in any runtime measured and cost the whole
    /// ``assetWaitBudget``: on the iOS 26.3, 26.4 and 26.5 simulators (iPhone 17) no request answered
    /// — not in 30 s on 26.3, not in 10 s each on 26.4 and 26.5 — and nothing tagged, whether the
    /// process tagged first or listed the schemes and asked for the assets first. So the warm-up
    /// spent 30 s of every process there to reach the verdict the canary reaches at once. Below 27
    /// the warm-up still lists the schemes and the canary still runs, so the verdict is as honest
    /// as above the line; it is only reached without the wait. The macOS host answers every request
    /// in milliseconds, so a Mac pays nothing either way.
    ///
    /// Not measured: a physical device on either side of the line.
    ///
    /// - Parameter major: The operating system's major version.
    /// - Returns: `true` when the warm-up should request and await the assets.
    public static func asksForAssets(onMajorVersion major: Int) -> Bool {
        major >= 27
    }

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

    /// The warm-up (or the re-check that replaced it) and the canary's verdict, taken together
    /// because the canary must follow the warm-up.
    public struct Verdict: Sendable, Equatable {
        /// What the warm-up or re-check did.
        public let warmUp: NaturalLanguageWarmUp
        /// What the canary found the tagger could then do.
        public let health: NaturalLanguageHealth

        /// Creates a verdict.
        /// - Parameters:
        ///   - warmUp: What the warm-up or re-check did.
        ///   - health: What the canary found.
        public init(warmUp: NaturalLanguageWarmUp, health: NaturalLanguageHealth) {
            self.warmUp = warmUp
            self.health = health
        }
    }

    /// Where the readiness gate is now (#1539).
    public enum Status: Sendable, Equatable {
        /// Nothing has started the warm-up yet: on iPhone and iPad, the app has not been in the
        /// foreground.
        case notStarted
        /// The warm-up is listing the schemes, waiting on an asset request, or running the canary.
        case warmingUp
        /// A request outlived its budget while the app was in the background; the verdict is pending
        /// until it answers or the app returns to the foreground.
        case waitingForAssets(scheme: String)
        /// A verdict exists. A re-check may be running; it replaces this only with a better one.
        case settled(Verdict)
    }

    /// One thing the release log records (#1539).
    public enum Event: Sendable, Equatable {
        /// A warm-up started.
        case started(NaturalLanguageWarmUp.Trigger, NaturalLanguageWarmUp.ApplicationState,
                     processAge: Double?)
        /// A request outlived its budget while the app was in the background; the verdict stays
        /// pending.
        case pending(scheme: String, seconds: Double)
        /// The warm-up's verdict.
        case settled(Verdict)
        /// A re-check finished. `found` is `nil` when a request did not answer, so the canary did
        /// not run; `adopted` says whether its verdict replaced the process's.
        case rechecked(NaturalLanguageWarmUp, found: NaturalLanguageHealth?, adopted: Bool)
    }

    /// Posted, on no particular thread, whenever ``status`` changes — the warm-up starting, a request
    /// left pending, the verdict settling, or a re-check replacing it. The app's
    /// `LanguageAnalysisMonitor` republishes it on the main actor.
    public static let verdictDidChangeNotification =
        Notification.Name("NaturalLanguageReadiness.verdictDidChange")

    /// The engine behind this facade, built from the live framework calls.
    static let engine = NaturalLanguageReadinessEngine(dependencies: .live)

    /// The release log (#1539). See the type's "The release log" section.
    private static let log = Logger(subsystem: "bottsywattsy.FRUS-Explorer",
                                    category: "NaturalLanguageReadiness")

    // MARK: - Public surface

    /// Starts the warm-up and the canary on a background queue and returns at once.
    ///
    /// The Mac's `FRUSExplorerApp.init` calls it first thing — see the "When it starts" section of
    /// the type's documentation. Idempotent: the work runs once however often this is called, and a
    /// tagger asked for meanwhile waits for it.
    public static func beginWarmUp() {
        engine.start(.launch)
    }

    /// The app became active (#1539): on iPhone and iPad this starts the warm-up the first time, and
    /// on both platforms it wakes a request left pending by a trip to the background, or starts a
    /// re-check when the verdict lacks a capability. Returns at once; the work runs on a background
    /// queue. Called by the app's `LanguageAnalysisLifecycle` for
    /// `UIApplication.didBecomeActiveNotification` and `NSApplication.didBecomeActiveNotification`.
    public static func applicationDidBecomeActive() {
        engine.applicationDidBecomeActive()
    }

    /// The app entered the background (#1539), so a request whose budget runs out from now on keeps
    /// the verdict pending rather than letting the canary tag while it is in flight. Called by the
    /// app's `LanguageAnalysisLifecycle` for `UIApplication.didEnterBackgroundNotification`.
    public static func applicationDidEnterBackground() {
        engine.applicationDidEnterBackground()
    }

    /// The verdict, waiting for it if the warm-up is still running. Blocks the calling thread for
    /// as long as the warm-up takes — up to one ``assetWaitBudget`` per scheme in the foreground,
    /// longer while a request is pending in the background — so never call it from the main thread;
    /// use ``verdictWhenReady()`` there. Read it per operation: a re-check can replace it.
    public static var current: Verdict { verdict }

    /// What the tagger can do in this process, waiting for the verdict if necessary (see
    /// ``current`` for the blocking caveat).
    public static var health: NaturalLanguageHealth { verdict.health }

    /// The verdict if it has settled, without waiting; `nil` while the first warm-up is still running.
    public static var settledVerdict: Verdict? { engine.settledVerdict }

    /// Where the gate is now, without waiting (#1539).
    public static var status: Status { engine.status }

    /// How many times a re-check has replaced the verdict in this process: 0 until one does (#1539).
    /// A surface that shows a language-analysis refusal keys its rebuild on it.
    public static var revision: Int { engine.revision }

    /// The verdict, awaited without blocking the caller's thread. Read it per operation: a re-check
    /// can replace it.
    public static func verdictWhenReady() async -> Verdict {
        await engine.verdictWhenReady()
    }

    /// A tagger for `tagSchemes`, handed out only after the warm-up and the canary have run.
    ///
    /// The one way the app constructs an `NLTagger`. Waiting here is what guarantees the warm-up
    /// precedes the process's first tagging even when a tokenizer is the first thing to run.
    ///
    /// No runtime test reliably sees this wait any more: the warm-up starts at launch or at the
    /// first foreground, and in most test launches it has finished before the first test asks for a
    /// tagger, so in those launches deleting the read below fails nothing that runs.
    /// `NaturalLanguageReadinessScanTests.taggerReadsTheVerdictBeforeItBuilds` pins the order where
    /// it is written instead — inside this body, `verdict` before `makeTagger`.
    public static func tagger(tagSchemes: [NLTagScheme]) -> NLTagger {
        _ = verdict
        return makeTagger(tagSchemes: tagSchemes)
    }

    /// The verdict, waiting for the first one and starting the warm-up if nothing has.
    private static var verdict: Verdict { engine.waitForVerdict() }

    // MARK: - The release log

    /// The line the release log writes for `event` (#1539): enums, scheme names, counts and
    /// seconds, never anything a reader wrote or read.
    ///
    /// A started warm-up names its trigger, where the app was and how far into the process it began;
    /// a verdict adds what `availableTagSchemes` listed, each request's answer, seconds and re-asks,
    /// and the canary's three flags. Internal so a test reads the exact text the log writes.
    /// - Parameter event: What happened.
    /// - Returns: One line, prefixed with nothing (the log's category names the type).
    static func logLine(for event: Event) -> String {
        switch event {
        case .started(let trigger, let state, let age):
            return "warm-up started; trigger=\(trigger.rawValue) app=\(state.rawValue)"
                + (age.map { " age=" + seconds($0) } ?? " age=unknown")
        case .pending(let scheme, let elapsed):
            return "\(scheme) unanswered after \(seconds(elapsed)) with the app in the background; "
                + "verdict pending until it answers or the app returns"
        case .settled(let verdict):
            return "verdict " + describe(verdict.warmUp) + "; " + describe(verdict.health)
        case .rechecked(let record, let found, let adopted):
            let outcome: String
            if let found {
                outcome = describe(found) + (adopted ? "; adopted" : "; kept the earlier verdict")
            } else {
                outcome = "canary not run, a request is unanswered; kept the earlier verdict"
            }
            return "re-check " + describe(record) + "; " + outcome
        }
    }

    /// A warm-up record as the log writes it.
    private static func describe(_ record: NaturalLanguageWarmUp) -> String {
        "trigger=\(record.trigger.rawValue) app=\(record.applicationState.rawValue)"
            + (record.processAge.map { " age=" + seconds($0) } ?? " age=unknown")
            + " took=" + seconds(record.seconds)
            + " listed=[" + record.schemesListed.joined(separator: ",") + "]"
            + " assets " + record.assetRequests.map {
                "\($0.scheme)=\($0.answer.rawValue)@" + seconds($0.seconds)
                    + ($0.reasked > 0 ? "(reasked \($0.reasked))" : "")
            }.joined(separator: " ")
    }

    /// A canary verdict as the log writes it.
    private static func describe(_ health: NaturalLanguageHealth) -> String {
        "canary lemmas=\(health.lemmatizes) classes=\(health.classifiesWords) names=\(health.recognizesNames)"
    }

    /// Seconds to three places with a unit, the way every figure in the log is written.
    private static func seconds(_ value: Double) -> String {
        String(format: "%.3fs", value)
    }

    /// Writes `event` to the release log, and to the console in a debug build.
    static func record(_ event: Event) {
        let line = logLine(for: event)
        log.notice("\(line, privacy: .public)")
        #if DEBUG
        print("[NaturalLanguageReadiness] \(line)")
        #endif
    }

    // MARK: - Canary

    /// Tags the two canary sentences with the tokenizer's own schemes and options and reports what
    /// came back.
    ///
    /// The word walk is `WordCloudTokenizer`'s: `.lemma` enumeration by word with the lexical
    /// class read per token. The name walk is its entity path, `.nameType` with `.joinNames`.
    /// Each call builds fresh taggers, which is what a re-check needs (#1539). Internal rather than
    /// private so a test can run it again and compare it with the verdict.
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

    /// Seconds since this process started, from the kernel's record of its start time, or `nil`
    /// when that cannot be read.
    static func processAge() -> Double? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0) == 0, size > 0 else { return nil }
        let start = info.kp_proc.p_un.__p_starttime
        guard start.tv_sec > 0 else { return nil }
        var now = timeval()
        gettimeofday(&now, nil)
        return Double(now.tv_sec - start.tv_sec) + Double(now.tv_usec - start.tv_usec) / 1_000_000
    }
}

// MARK: - NaturalLanguageReadinessEngine

/// The warm-up, the canary and the verdict's life in a process, behind the seams a test drives
/// (#1539).
///
/// ``NaturalLanguageReadiness`` is a facade over one engine built from the live framework calls
/// (``Dependencies/live``); `NaturalLanguageReadinessEngineTests` builds engines from fakes — asset
/// requests that answer when the test says, a canary that returns what the test says — so the
/// lifecycle rules can be driven on any host. See ``NaturalLanguageReadiness`` for the rules and
/// what each was measured to do.
///
/// Thread-safe: all state is behind one lock, and every wait happens outside it.
///
/// Version history:
///   1.0 — #1539: initial implementation, replacing #1373's `static let verdict`
final class NaturalLanguageReadinessEngine: Sendable {

    /// What the engine calls out to: the framework on a device, fakes in a test.
    struct Dependencies: Sendable {
        /// Lists the tag schemes (`NLTagger.availableTagSchemes`), for its side effect and the record.
        var listSchemes: @Sendable () -> [String]
        /// Asks for one scheme's assets and calls back with the answer, on any thread, at most once.
        var requestAssets: @Sendable (NLTagScheme, @escaping @Sendable (NaturalLanguageWarmUp.AssetAnswer) -> Void) -> Void
        /// Tags the canary sentences with fresh taggers.
        var canary: @Sendable () -> NaturalLanguageHealth
        /// Whether this runtime asks for the assets at all.
        var asksForAssets: Bool
        /// One scheme's foreground budget, in seconds.
        var budget: TimeInterval
        /// Seconds since the process started, if known.
        var processAge: @Sendable () -> Double?
        /// Records one event (the release log).
        var report: @Sendable (NaturalLanguageReadiness.Event) -> Void
        /// Announces a change of status.
        var statusDidChange: @Sendable () -> Void

        /// The framework's calls, the release log and the notification.
        static var live: Dependencies {
            Dependencies(
                listSchemes: {
                    NLTagger.availableTagSchemes(for: .word, language: .english).map(\.rawValue)
                },
                requestAssets: { scheme, answer in
                    NLTagger.requestAssets(for: .english, tagScheme: scheme) { result, _ in
                        switch result {
                        case .available: answer(.available)
                        case .notAvailable: answer(.notAvailable)
                        default: answer(.error)
                        }
                    }
                },
                canary: { NaturalLanguageReadiness.runCanary() },
                asksForAssets: NaturalLanguageReadiness.asksForAssets(
                    onMajorVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion),
                budget: NaturalLanguageReadiness.assetWaitBudget,
                processAge: { NaturalLanguageReadiness.processAge() },
                report: { NaturalLanguageReadiness.record($0) },
                statusDidChange: {
                    NotificationCenter.default.post(
                        name: NaturalLanguageReadiness.verdictDidChangeNotification, object: nil)
                })
        }
    }

    /// Everything that changes, behind ``state``'s lock.
    private struct State: Sendable {
        var started = false
        var status: NaturalLanguageReadiness.Status = .notStarted
        var verdict: NaturalLanguageReadiness.Verdict?
        var revision = 0
        var lifecycle: NaturalLanguageWarmUp.ApplicationState = .unreported
        /// Counts the app's reports of entering the background, so a wait can tell whether one
        /// happened while it waited.
        var backgroundEntries = 0
        var rechecking = false
        var waiters: [CheckedContinuation<NaturalLanguageReadiness.Verdict, Never>] = []
        /// The semaphores of requests pending in the background, signalled on a return to the
        /// foreground.
        var wakers: [ObjectIdentifier: DispatchSemaphore] = [:]
    }

    /// One request's answer, delivered once, and the semaphore its waiter sleeps on.
    private final class AnswerBox: Sendable {
        private let answer = OSAllocatedUnfairLock<NaturalLanguageWarmUp.AssetAnswer?>(initialState: nil)
        /// Signalled by the first answer, and by a return to the foreground while pending.
        let signal = DispatchSemaphore(value: 0)

        /// The answer, if one has arrived.
        var value: NaturalLanguageWarmUp.AssetAnswer? { answer.withLock { $0 } }

        /// Records `answer` if it is the first, and wakes the waiter.
        func deliver(_ newAnswer: NaturalLanguageWarmUp.AssetAnswer) {
            let first = answer.withLock { stored -> Bool in
                guard stored == nil else { return false }
                stored = newAnswer
                return true
            }
            if first { signal.signal() }
        }

        /// Waits until an answer arrives or `deadline` passes; `true` when an answer has arrived.
        func wait(until deadline: DispatchTime) -> Bool {
            while value == nil {
                if signal.wait(timeout: deadline) == .timedOut { return value != nil }
            }
            return true
        }
    }

    private let dependencies: Dependencies
    private let state = OSAllocatedUnfairLock(initialState: State())
    /// Entered at creation and left when the first verdict settles, so a synchronous waiter sleeps
    /// until then.
    private let firstVerdict = DispatchGroup()

    /// Creates an engine that has not started.
    /// - Parameter dependencies: What it calls out to.
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
        firstVerdict.enter()
    }

    // MARK: - Reading

    /// The verdict, or `nil` before the first settles.
    var settledVerdict: NaturalLanguageReadiness.Verdict? { state.withLock { $0.verdict } }

    /// Where the engine is now.
    var status: NaturalLanguageReadiness.Status { state.withLock { $0.status } }

    /// How many times a re-check has replaced the verdict.
    var revision: Int { state.withLock { $0.revision } }

    /// The verdict, blocking until the first settles and starting the warm-up if nothing has.
    func waitForVerdict() -> NaturalLanguageReadiness.Verdict {
        if let verdict = settledVerdict { return verdict }
        start(.firstUse)
        firstVerdict.wait()
        guard let verdict = settledVerdict else {
            preconditionFailure("the first-verdict group was left before a verdict was stored")
        }
        return verdict
    }

    /// The verdict, suspending until the first settles and starting the warm-up if nothing has.
    func verdictWhenReady() async -> NaturalLanguageReadiness.Verdict {
        if let verdict = settledVerdict { return verdict }
        start(.firstUse)
        return await withCheckedContinuation { continuation in
            let ready = state.withLock { state -> NaturalLanguageReadiness.Verdict? in
                if let verdict = state.verdict { return verdict }
                state.waiters.append(continuation)
                return nil
            }
            if let ready { continuation.resume(returning: ready) }
        }
    }

    // MARK: - Lifecycle

    /// Starts the warm-up on a background queue unless something already has.
    func start(_ trigger: NaturalLanguageWarmUp.Trigger) {
        let begins = state.withLock { state -> Bool in
            guard !state.started else { return false }
            state.started = true
            state.status = .warmingUp
            return true
        }
        guard begins else { return }
        dependencies.statusDidChange()
        DispatchQueue.global(qos: .userInitiated).async { self.warmUp(trigger) }
    }

    /// The app became active: start the warm-up the first time, wake a request pending in the
    /// background, or re-check a verdict that lacks a capability.
    func applicationDidBecomeActive() {
        enum Next { case start, recheck, nothing }
        let (next, wakers) = state.withLock { state -> (Next, [DispatchSemaphore]) in
            state.lifecycle = .active
            let wakers = Array(state.wakers.values)
            guard state.started else { return (.start, wakers) }
            guard case .settled(let verdict) = state.status, !verdict.health.isFullyWorking,
                  !state.rechecking else { return (.nothing, wakers) }
            state.rechecking = true
            return (.recheck, wakers)
        }
        for waker in wakers { waker.signal() }
        switch next {
        case .start: start(.firstForeground)
        case .recheck: DispatchQueue.global(qos: .utility).async { self.recheck() }
        case .nothing: break
        }
    }

    /// The app entered the background.
    func applicationDidEnterBackground() {
        state.withLock { state in
            state.lifecycle = .background
            state.backgroundEntries += 1
        }
    }

    // MARK: - Warm-up and re-check

    /// The warm-up: list, request each scheme in turn, run the canary, settle.
    private func warmUp(_ trigger: NaturalLanguageWarmUp.Trigger) {
        let began = DispatchTime.now()
        let applicationState = state.withLock { $0.lifecycle }
        let age = dependencies.processAge()
        dependencies.report(.started(trigger, applicationState, processAge: age))
        let listed = dependencies.listSchemes().sorted()
        let requests = NaturalLanguageReadiness.warmedSchemes.map { request($0, pendsInBackground: true) }
        let health = dependencies.canary()
        let verdict = NaturalLanguageReadiness.Verdict(
            warmUp: NaturalLanguageWarmUp(trigger: trigger, applicationState: applicationState,
                                          schemesListed: listed, assetRequests: requests,
                                          seconds: Self.seconds(from: began), processAge: age),
            health: health)
        settle(verdict, isReplacement: false)
        dependencies.report(.settled(verdict))
    }

    /// The re-check: list, request each scheme, and run the canary only if every request answered;
    /// adopt its verdict only if it improves on the one the process holds.
    private func recheck() {
        defer { state.withLock { $0.rechecking = false } }
        let began = DispatchTime.now()
        let applicationState = state.withLock { $0.lifecycle }
        let age = dependencies.processAge()
        let listed = dependencies.listSchemes().sorted()
        let requests = NaturalLanguageReadiness.warmedSchemes.map { request($0, pendsInBackground: false) }
        let record = NaturalLanguageWarmUp(trigger: .recheck, applicationState: applicationState,
                                           schemesListed: listed, assetRequests: requests,
                                           seconds: Self.seconds(from: began), processAge: age)
        guard let previous = settledVerdict else { return }
        // A request still in flight: tagging now is the order measured to lose lemmas, and this
        // process has a verdict to keep, so the canary waits for another return to the foreground.
        guard !requests.contains(where: { $0.answer == .timedOut }) else {
            dependencies.report(.rechecked(record, found: nil, adopted: false))
            return
        }
        let health = dependencies.canary()
        let adopted = health.improves(on: previous.health)
        if adopted {
            settle(NaturalLanguageReadiness.Verdict(warmUp: record, health: health), isReplacement: true)
        }
        dependencies.report(.rechecked(record, found: health, adopted: adopted))
    }

    /// Asks for `scheme`'s assets and waits for the answer — see "A request still in flight" in
    /// ``NaturalLanguageReadiness``'s documentation.
    /// - Parameters:
    ///   - scheme: The scheme to ask for.
    ///   - pendsInBackground: Whether a budget that ran out while the app was in the background
    ///     keeps waiting (the warm-up, which has no verdict to fall back on) or times out (a
    ///     re-check, which keeps the verdict it has).
    private func request(_ scheme: NLTagScheme, pendsInBackground: Bool) -> NaturalLanguageWarmUp.AssetRequest {
        guard dependencies.asksForAssets else {
            return .init(scheme: scheme.rawValue, answer: .notAsked, seconds: 0)
        }
        let box = AnswerBox()
        let firstAsked = DispatchTime.now()
        var reasked = 0
        var asked = firstAsked
        var backgroundEntriesWhenAsked = state.withLock { $0.backgroundEntries }
        dependencies.requestAssets(scheme) { box.deliver($0) }
        while true {
            if box.wait(until: asked + dependencies.budget), let answer = box.value {
                return .init(scheme: scheme.rawValue, answer: answer,
                             seconds: Self.seconds(from: firstAsked), reasked: reasked)
            }
            let entriesWhenAsked = backgroundEntriesWhenAsked
            let wentAway = state.withLock {
                $0.lifecycle == .background || $0.backgroundEntries != entriesWhenAsked
            }
            guard pendsInBackground, wentAway else {
                return .init(scheme: scheme.rawValue, answer: .timedOut,
                             seconds: Self.seconds(from: firstAsked), reasked: reasked)
            }
            dependencies.report(.pending(scheme: scheme.rawValue, seconds: Self.seconds(from: firstAsked)))
            if let answer = waitForAnswerOrForeground(box, scheme: scheme.rawValue) {
                return .init(scheme: scheme.rawValue, answer: answer,
                             seconds: Self.seconds(from: firstAsked), reasked: reasked)
            }
            // Back in the foreground with no answer: ask again, with a fresh budget.
            reasked += 1
            asked = DispatchTime.now()
            backgroundEntriesWhenAsked = state.withLock { $0.backgroundEntries }
            dependencies.requestAssets(scheme) { box.deliver($0) }
        }
    }

    /// Waits, with no deadline, until `box` is answered (returning the answer) or the app is in the
    /// foreground again (returning `nil`). The verdict is pending meanwhile.
    private func waitForAnswerOrForeground(_ box: AnswerBox, scheme: String)
    -> NaturalLanguageWarmUp.AssetAnswer? {
        let key = ObjectIdentifier(box)
        let inForeground = state.withLock { state -> Bool in
            guard state.lifecycle == .background else { return true }
            state.wakers[key] = box.signal
            state.status = .waitingForAssets(scheme: scheme)
            return false
        }
        if inForeground { return box.value }
        dependencies.statusDidChange()
        defer {
            state.withLock { state in
                state.wakers[key] = nil
                if case .waitingForAssets = state.status { state.status = .warmingUp }
            }
            dependencies.statusDidChange()
        }
        while true {
            box.signal.wait()
            if let answer = box.value { return answer }
            if state.withLock({ $0.lifecycle != .background }) { return nil }
        }
    }

    /// Stores `verdict`, wakes everyone waiting for one, and announces the change.
    private func settle(_ verdict: NaturalLanguageReadiness.Verdict, isReplacement: Bool) {
        let (waiters, isFirst) = state.withLock { state -> ([CheckedContinuation<NaturalLanguageReadiness.Verdict, Never>], Bool) in
            let isFirst = state.verdict == nil
            state.verdict = verdict
            state.status = .settled(verdict)
            if isReplacement { state.revision += 1 }
            let waiters = state.waiters
            state.waiters = []
            return (waiters, isFirst)
        }
        if isFirst { firstVerdict.leave() }
        for waiter in waiters { waiter.resume(returning: verdict) }
        dependencies.statusDidChange()
    }

    /// Seconds elapsed since `start`.
    private static func seconds(from start: DispatchTime) -> Double {
        Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000
    }
}
