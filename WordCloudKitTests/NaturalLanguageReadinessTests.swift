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
import NaturalLanguage
import os
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

// MARK: - #1539: the engine's lifecycle, driven through fakes

/// A stand-in for the framework an engine calls: asset requests that answer when the test says, a
/// canary that returns what the test says, and a record of every event the engine reports (#1539).
final class FakeLanguageFramework: Sendable {

    /// How a scheme's request answers.
    enum Reply: Sendable {
        /// At once, inside the request call.
        case now(NaturalLanguageWarmUp.AssetAnswer)
        /// After `seconds`, from another thread.
        case after(Double, NaturalLanguageWarmUp.AssetAnswer)
        /// Not until the test calls ``FakeLanguageFramework/answer(_:with:)``.
        case never
    }

    private struct State: Sendable {
        var replies: [String: Reply]
        var outstanding: [String: [@Sendable (NaturalLanguageWarmUp.AssetAnswer) -> Void]] = [:]
        var requests: [String] = []
        var canaryResults: [NaturalLanguageHealth]
        var canaryRuns = 0
        var events: [NaturalLanguageReadiness.Event] = []
        var statusChanges = 0
    }

    private let state: OSAllocatedUnfairLock<State>

    /// - Parameters:
    ///   - replies: How each scheme (by raw value) answers; a scheme left out answers `available` at once.
    ///   - canary: What successive canary runs return; the last repeats.
    init(replies: [String: Reply] = [:], canary: [NaturalLanguageHealth] = [.fullyWorking]) {
        state = OSAllocatedUnfairLock(initialState: State(replies: replies, canaryResults: canary))
    }

    /// Changes how `scheme`'s later requests answer.
    func setReply(_ reply: Reply, for scheme: String) {
        state.withLock { $0.replies[scheme] = reply }
    }

    /// Answers every outstanding request for `scheme`.
    func answer(_ scheme: String, with answer: NaturalLanguageWarmUp.AssetAnswer) {
        let callbacks = state.withLock { state in
            let callbacks = state.outstanding[scheme] ?? []
            state.outstanding[scheme] = []
            return callbacks
        }
        for callback in callbacks { callback(answer) }
    }

    /// How many requests have been made for `scheme`.
    func requests(for scheme: String) -> Int { state.withLock { $0.requests.filter { $0 == scheme }.count } }
    /// Every request, in order, by scheme.
    var allRequests: [String] { state.withLock { $0.requests } }
    /// How many times the canary has run.
    var canaryRuns: Int { state.withLock { $0.canaryRuns } }
    /// Every event the engine reported, in order.
    var events: [NaturalLanguageReadiness.Event] { state.withLock { $0.events } }
    /// How many times the engine announced a change of status.
    var statusChanges: Int { state.withLock { $0.statusChanges } }

    /// Dependencies for an engine with a foreground budget of `budget` seconds per scheme.
    func dependencies(budget: TimeInterval, asks: Bool = true) -> NaturalLanguageReadinessEngine.Dependencies {
        NaturalLanguageReadinessEngine.Dependencies(
            listSchemes: { ["Lemma", "LexicalClass", "NameType"] },
            requestAssets: { scheme, callback in
                let reply = self.state.withLock { state -> Reply in
                    state.requests.append(scheme.rawValue)
                    let reply = state.replies[scheme.rawValue] ?? .now(.available)
                    if case .never = reply { state.outstanding[scheme.rawValue, default: []].append(callback) }
                    return reply
                }
                switch reply {
                case .now(let answer): callback(answer)
                case .after(let seconds, let answer):
                    DispatchQueue.global().asyncAfter(deadline: .now() + seconds) { callback(answer) }
                case .never: break
                }
            },
            canary: {
                self.state.withLock { state in
                    let index = min(state.canaryRuns, state.canaryResults.count - 1)
                    state.canaryRuns += 1
                    return state.canaryResults[index]
                }
            },
            asksForAssets: asks,
            budget: budget,
            processAge: { 1.5 },
            report: { event in self.state.withLock { $0.events.append(event) } },
            statusDidChange: { self.state.withLock { $0.statusChanges += 1 } })
    }
}

/// #1539: how the readiness engine starts, waits, re-checks and replaces its verdict, driven
/// through ``FakeLanguageFramework`` so every rule runs on any host in a second or two.
///
/// ## What each test guards, and the unfixed behaviour it fails on
/// Before #1539 the verdict was a `static let` made once per process at the app's launch, under one
/// 30 s budget shared by the three requests, with the canary run whenever that budget ran out, and
/// nothing ever checked it again. Each test below names the part of that it fails on. Two are
/// controls — the foreground timeout and the first-use start, which #1539 keeps — and say so.
///
/// Version history:
///   1.0 — #1539: initial implementation
@Suite("WordCloudKit — the readiness engine's lifecycle (#1539)")
struct NaturalLanguageReadinessEngineTests {

    private static let lemmaOnlyFailing = NaturalLanguageHealth(lemmatizes: false, classifiesWords: true,
                                                                 recognizesNames: true)

    /// Polls `condition` every 10 ms until it holds or `seconds` pass; `true` when it held.
    private func eventually(within seconds: Double = 5, _ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    @Test("The app's first time in the foreground starts the warm-up and says so in the record")
    func firstForegroundStartsTheWarmUp() async throws {
        // Fails on the unfixed code, where nothing but a launch call or a first use started it: a
        // foreground started nothing.
        let fake = FakeLanguageFramework()
        let engine = NaturalLanguageReadinessEngine(dependencies: fake.dependencies(budget: 5))
        #expect(engine.status == .notStarted)
        engine.applicationDidBecomeActive()
        #expect(await eventually { engine.settledVerdict != nil }, "the first foreground did not start the warm-up")
        let verdict = try #require(engine.settledVerdict)
        #expect(verdict.warmUp.trigger == .firstForeground)
        #expect(verdict.warmUp.applicationState == .active)
        #expect(fake.allRequests == ["LexicalClass", "NameType", "Lemma"])
        #expect(fake.events.first == .started(.firstForeground, .active, processAge: 1.5))
        #expect(fake.events.last == .settled(verdict))
    }

    @Test("A first use before the app's first foreground starts the warm-up itself (control)")
    func firstUseStartsTheWarmUp() async {
        // A CONTROL: #1373's lazy start, kept for the generators and tests. Its record names it.
        let fake = FakeLanguageFramework()
        let engine = NaturalLanguageReadinessEngine(dependencies: fake.dependencies(budget: 5))
        let verdict = await engine.verdictWhenReady()
        #expect(verdict.warmUp.trigger == .firstUse)
        #expect(verdict.warmUp.applicationState == .unreported)
        #expect(engine.waitForVerdict() == verdict)
    }

    @Test("Each scheme gets a budget of its own, so two slow answers leave the lemma request its full wait")
    func budgetIsPerScheme() async throws {
        // Each answer takes 0.6 of a budget. With the unfixed code's one shared budget the name
        // request's deadline falls before its answer and the lemma request is asked after the
        // deadline, so both time out; with a budget each, all three answer.
        let budget = 2.0
        let fake = FakeLanguageFramework(replies: [
            "LexicalClass": .after(budget * 0.6, .available),
            "NameType": .after(budget * 0.6, .available),
            "Lemma": .after(budget * 0.6, .available),
        ])
        let engine = NaturalLanguageReadinessEngine(dependencies: fake.dependencies(budget: budget))
        engine.applicationDidBecomeActive()
        #expect(await eventually(within: 10) { engine.settledVerdict != nil })
        let verdict = try #require(engine.settledVerdict)
        #expect(verdict.warmUp.assetRequests.map(\.answer) == [.available, .available, .available],
                "answers: \(verdict.warmUp.assetRequests)")
    }

    @Test("A budget that runs out with the app in the background keeps the verdict pending, runs no canary, and asks again on the return")
    func backgroundTimeoutKeepsTheVerdictPending() async throws {
        // Fails on the unfixed code, which ran the canary — tagging while the request was in flight,
        // the order measured to lose lemmas — as soon as the deadline passed, however the time was spent.
        let fake = FakeLanguageFramework(replies: ["Lemma": .never])
        let engine = NaturalLanguageReadinessEngine(dependencies: fake.dependencies(budget: 1.0))
        engine.applicationDidBecomeActive()
        #expect(await eventually { fake.requests(for: "Lemma") == 1 }, "the lemma request was never made")
        engine.applicationDidEnterBackground()
        #expect(await eventually { engine.status == .waitingForAssets(scheme: "Lemma") },
                "status \(engine.status) after the budget ran out in the background")
        try await Task.sleep(for: .seconds(0.6))
        #expect(fake.canaryRuns == 0, "the canary ran while the lemma request was in flight")
        #expect(engine.settledVerdict == nil, "a verdict settled while the lemma request was in flight")
        #expect(fake.events.contains {
            if case .pending(scheme: "Lemma", _) = $0 { return true } else { return false }
        }, "the log did not record the pending request: \(fake.events)")

        engine.applicationDidBecomeActive()
        #expect(await eventually { fake.requests(for: "Lemma") == 2 }, "the return did not ask again")
        fake.answer("Lemma", with: .available)
        #expect(await eventually { engine.settledVerdict != nil })
        let verdict = try #require(engine.settledVerdict)
        let lemma = try #require(verdict.warmUp.assetRequests.last)
        #expect(lemma.scheme == "Lemma" && lemma.answer == .available && lemma.reasked == 1, "\(lemma)")
        #expect(fake.canaryRuns == 1)
    }

    @Test("A late answer that arrives while the app is still in the background settles the verdict")
    func lateAnswerInTheBackgroundSettles() async throws {
        // The pending wait's other way out: the answer, not the foreground. Fails on the unfixed
        // code, which had already timed the request out and run the canary.
        let fake = FakeLanguageFramework(replies: ["Lemma": .never])
        let engine = NaturalLanguageReadinessEngine(dependencies: fake.dependencies(budget: 1.0))
        engine.applicationDidBecomeActive()
        #expect(await eventually { fake.requests(for: "Lemma") == 1 })
        engine.applicationDidEnterBackground()
        #expect(await eventually { engine.status == .waitingForAssets(scheme: "Lemma") })
        #expect(fake.canaryRuns == 0)
        fake.answer("Lemma", with: .available)
        #expect(await eventually { engine.settledVerdict != nil })
        let lemma = try #require(engine.settledVerdict?.warmUp.assetRequests.last)
        #expect(lemma.answer == .available && lemma.reasked == 0, "\(lemma)")
        #expect(fake.requests(for: "Lemma") == 1)
    }

    @Test("A budget that runs out with the app in the foreground throughout is recorded timed out, and the canary runs (control)")
    func foregroundTimeoutRunsTheCanary() async throws {
        // A CONTROL: the measured case where waiting longer buys nothing, kept from #1373 so a
        // process whose lemma request never answers does not hold every surface on a spinner.
        let fake = FakeLanguageFramework(replies: ["Lemma": .never], canary: [Self.lemmaOnlyFailing])
        let engine = NaturalLanguageReadinessEngine(dependencies: fake.dependencies(budget: 0.3))
        engine.applicationDidBecomeActive()
        #expect(await eventually { engine.settledVerdict != nil })
        let verdict = try #require(engine.settledVerdict)
        #expect(verdict.warmUp.assetRequests.last?.answer == .timedOut)
        #expect(verdict.health == Self.lemmaOnlyFailing)
        #expect(!fake.events.contains { if case .pending = $0 { return true } else { return false } })
    }

    @Test("A return to the foreground re-checks a verdict that lacks a capability, with fresh requests and canary, and adopts a better one")
    func recheckAdoptsABetterVerdict() async throws {
        // Fails on the unfixed code, whose verdict was a `static let`: nothing ever ran again.
        let fake = FakeLanguageFramework(canary: [Self.lemmaOnlyFailing, .fullyWorking])
        let engine = NaturalLanguageReadinessEngine(dependencies: fake.dependencies(budget: 5))
        engine.applicationDidBecomeActive()
        #expect(await eventually { engine.settledVerdict != nil })
        #expect(engine.settledVerdict?.health == Self.lemmaOnlyFailing)
        #expect(engine.revision == 0)

        engine.applicationDidEnterBackground()
        engine.applicationDidBecomeActive()
        #expect(await eventually { engine.revision == 1 }, "the re-check did not adopt the better verdict")
        let verdict = try #require(engine.settledVerdict)
        #expect(verdict.health == .fullyWorking)
        #expect(verdict.warmUp.trigger == .recheck)
        #expect(fake.allRequests.count == 6, "a re-check asks for every scheme again: \(fake.allRequests)")
        #expect(fake.canaryRuns == 2)
        // Read per operation: a waiter after the replacement gets the new verdict.
        #expect(await engine.verdictWhenReady().health == .fullyWorking)
        #expect(fake.events.contains(.rechecked(verdict.warmUp, found: .fullyWorking, adopted: true)))
    }

    @Test("A re-check whose verdict gains one capability and loses another keeps the old verdict")
    func recheckKeepsAVerdictThatIsNotBetter() async throws {
        // Fails on a re-check that adopts whatever it finds (and, like every re-check test, on the
        // unfixed code, which never re-checked and so reports nothing).
        let traded = NaturalLanguageHealth(lemmatizes: true, classifiesWords: false, recognizesNames: true)
        let fake = FakeLanguageFramework(canary: [Self.lemmaOnlyFailing, traded])
        let engine = NaturalLanguageReadinessEngine(dependencies: fake.dependencies(budget: 5))
        engine.applicationDidBecomeActive()
        #expect(await eventually { engine.settledVerdict != nil })
        engine.applicationDidBecomeActive()
        #expect(await eventually { fake.events.contains {
            if case .rechecked(_, found: traded, adopted: false) = $0 { return true } else { return false }
        } }, "no kept re-check was reported: \(fake.events)")
        #expect(engine.settledVerdict?.health == Self.lemmaOnlyFailing)
        #expect(engine.revision == 0)
    }

    @Test("A fully working verdict is never re-checked")
    func fullyWorkingVerdictIsNotRechecked() async throws {
        // Fails on a re-check that runs on every return to the foreground.
        let fake = FakeLanguageFramework(canary: [.fullyWorking])
        let engine = NaturalLanguageReadinessEngine(dependencies: fake.dependencies(budget: 5))
        engine.applicationDidBecomeActive()
        #expect(await eventually { engine.settledVerdict != nil })
        engine.applicationDidEnterBackground()
        engine.applicationDidBecomeActive()
        try await Task.sleep(for: .milliseconds(300))
        #expect(fake.allRequests.count == 3, "requests: \(fake.allRequests)")
        #expect(fake.canaryRuns == 1)
    }

    @Test("A re-check whose request does not answer runs no canary and keeps the verdict")
    func recheckWithARequestInFlightKeepsTheVerdict() async throws {
        // Fails on a re-check that tags while its request is in flight (and on the unfixed code,
        // which never re-checked).
        let fake = FakeLanguageFramework(canary: [Self.lemmaOnlyFailing, .fullyWorking])
        let engine = NaturalLanguageReadinessEngine(dependencies: fake.dependencies(budget: 0.3))
        engine.applicationDidBecomeActive()
        #expect(await eventually { engine.settledVerdict != nil })
        fake.setReply(.never, for: "Lemma")
        engine.applicationDidBecomeActive()
        #expect(await eventually { fake.events.contains {
            if case .rechecked(_, found: nil, adopted: false) = $0 { return true } else { return false }
        } }, "no re-check without a canary was reported: \(fake.events)")
        #expect(fake.canaryRuns == 1, "the re-check ran the canary while the lemma request was in flight")
        #expect(engine.settledVerdict?.health == Self.lemmaOnlyFailing)
    }

    @Test("A verdict improves on another only by keeping every capability and adding one", arguments: [
        // (candidate, held, improves) — one fixture per clause of the rule.
        (NaturalLanguageHealth(lemmatizes: false, classifiesWords: true, recognizesNames: true),
         NaturalLanguageHealth(lemmatizes: false, classifiesWords: true, recognizesNames: true), false),
        (NaturalLanguageHealth(lemmatizes: false, classifiesWords: true, recognizesNames: true),
         NaturalLanguageHealth(lemmatizes: true, classifiesWords: false, recognizesNames: true), false),
        (NaturalLanguageHealth(lemmatizes: true, classifiesWords: false, recognizesNames: true),
         NaturalLanguageHealth(lemmatizes: true, classifiesWords: true, recognizesNames: false), false),
        (NaturalLanguageHealth(lemmatizes: true, classifiesWords: true, recognizesNames: false),
         NaturalLanguageHealth(lemmatizes: false, classifiesWords: true, recognizesNames: true), false),
        (NaturalLanguageHealth(lemmatizes: true, classifiesWords: true, recognizesNames: true),
         NaturalLanguageHealth(lemmatizes: false, classifiesWords: true, recognizesNames: true), true),
        (NaturalLanguageHealth(lemmatizes: false, classifiesWords: false, recognizesNames: true),
         NaturalLanguageHealth(lemmatizes: false, classifiesWords: false, recognizesNames: false), true),
    ])
    func improvesOn(candidate: NaturalLanguageHealth, held: NaturalLanguageHealth, improves: Bool) {
        #expect(candidate.improves(on: held) == improves, "\(candidate) over \(held)")
    }

    @Test("The release log writes enums, scheme names, counts and seconds for every event")
    func logLinesCarryTheRecord() {
        let record = NaturalLanguageWarmUp(
            trigger: .firstForeground, applicationState: .active,
            schemesListed: ["Lemma", "LexicalClass"],
            assetRequests: [
                .init(scheme: "LexicalClass", answer: .available, seconds: 0.004),
                .init(scheme: "NameType", answer: .error, seconds: 0.01),
                .init(scheme: "Lemma", answer: .available, seconds: 41.25, reasked: 2),
            ],
            seconds: 41.5, processAge: 2.75)
        let verdict = NaturalLanguageReadiness.Verdict(warmUp: record, health: Self.lemmaOnlyFailing)
        #expect(NaturalLanguageReadiness.logLine(for: .started(.firstForeground, .active, processAge: 2.75))
                == "warm-up started; trigger=firstForeground app=active age=2.750s")
        #expect(NaturalLanguageReadiness.logLine(for: .started(.firstUse, .unreported, processAge: nil))
                == "warm-up started; trigger=firstUse app=unreported age=unknown")
        #expect(NaturalLanguageReadiness.logLine(for: .pending(scheme: "Lemma", seconds: 30.5))
                == "Lemma unanswered after 30.500s with the app in the background; verdict pending until it answers or the app returns")
        let described = "trigger=firstForeground app=active age=2.750s took=41.500s listed=[Lemma,LexicalClass] "
            + "assets LexicalClass=available@0.004s NameType=error@0.010s Lemma=available@41.250s(reasked 2)"
        #expect(NaturalLanguageReadiness.logLine(for: .settled(verdict))
                == "verdict " + described + "; canary lemmas=false classes=true names=true")
        #expect(NaturalLanguageReadiness.logLine(for: .rechecked(record, found: .fullyWorking, adopted: true))
                == "re-check " + described + "; canary lemmas=true classes=true names=true; adopted")
        #expect(NaturalLanguageReadiness.logLine(for: .rechecked(record, found: Self.lemmaOnlyFailing, adopted: false))
                == "re-check " + described + "; canary lemmas=false classes=true names=true; kept the earlier verdict")
        #expect(NaturalLanguageReadiness.logLine(for: .rechecked(record, found: nil, adopted: false))
                == "re-check " + described + "; canary not run, a request is unanswered; kept the earlier verdict")
    }

    @Test("Every change of status is announced: the start, a pending request, its end, and the verdict")
    func statusChangesAreAnnounced() async throws {
        // The app's monitor refreshes on these, so a pending request and its end must each announce.
        let fake = FakeLanguageFramework(replies: ["Lemma": .never])
        let engine = NaturalLanguageReadinessEngine(dependencies: fake.dependencies(budget: 1.0))
        engine.applicationDidBecomeActive()
        #expect(await eventually { fake.statusChanges == 1 }, "the start was not announced")
        #expect(await eventually { fake.requests(for: "Lemma") == 1 })
        engine.applicationDidEnterBackground()
        #expect(await eventually { fake.statusChanges == 2 }, "the pending request was not announced")
        fake.answer("Lemma", with: .available)
        #expect(await eventually { engine.settledVerdict != nil })
        // The pending wait's end and the verdict: four in all.
        #expect(await eventually { fake.statusChanges == 4 }, "announced \(fake.statusChanges) changes")
    }
}
