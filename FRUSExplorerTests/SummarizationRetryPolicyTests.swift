// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
import FoundationModels
@testable import FRUSExplorer

/// Whether this system has `LanguageModelError`, which the framework throws from iOS and macOS 27.
private let systemHasLanguageModelError: Bool = {
    if #available(iOS 27.0, macOS 27.0, *) { return true }
    return false
}()

// MARK: - SummarizationRetryPolicyTests

/// The #560 retry classification.
///
/// Apple Intelligence is not available in the test host, so nothing here runs the model. What *is*
/// testable — and is where the risk actually lives — is the policy's shape: that the default is to
/// retry, that the `.synthesisFailed` wrapper is unwrapped before anything is judged, and that the
/// errors this app raises itself are classified correctly. The framework's errors are built from their
/// public initialisers (#1765), which need no model.
///
/// Version history:
///   1.0 — #560: initial implementation
///   1.1 — #1765: `contentRefused`, and both framework error families
///   1.2 — 2026-10-31: a structured answer without its headings is a refusal; the structured sentence
///          without its stricter-rules clause
///   1.3 — 2026-11-01: an answer that ran past the window is terminal for the document, is told from a
///          prompt over it, and reads as a plain sentence
@Suite("Summarization retry policy")
struct SummarizationRetryPolicyTests {

    /// An error type the policy has never seen.
    private struct MysteryError: Error {}

    /// The single most important property. The policy is a **blocklist**: it refuses to retry only
    /// what it knows to be deterministic. An allowlist would silently stop retrying a transient
    /// failure the author did not anticipate — a much quieter regression than a wasted 30 seconds,
    /// because it turns a recoverable hiccup into a lost document.
    @Test("An unrecognised error stays retryable")
    func unknownErrorsAreRetryable() {
        #expect(SummarizationRetryPolicy.isRetryable(MysteryError()))
        #expect(SummarizationRetryPolicy.isRetryable(
            NSError(domain: "SomeFrameworkNobodyAnticipated", code: 42)))
        #expect(SummarizationRetryPolicy.isRetryable(
            NSError(domain: NSCocoaErrorDomain, code: 134_060)))   // a SwiftData save failure
    }

    /// Both are properties of the request, not of the moment. Retrying spends 30 seconds of backoff
    /// — with a concurrency permit held — to arrive at the same answer.
    @Test("Provider unavailability and empty text are terminal")
    func appErrorsAreTerminal() {
        #expect(!SummarizationRetryPolicy.isRetryable(SummarizationError.providerUnavailable))
        #expect(!SummarizationRetryPolicy.isRetryable(SummarizationError.emptyDocumentText))
    }

    /// `SummarizationService.synthesize` wraps **every** error it catches, including
    /// `CancellationError`. Without unwrapping first, a cancelled run's synthesis error reads as an
    /// unrecognised error and gets retried four times with backoff — so pressing Cancel during a
    /// long document would appear to do nothing for half a minute.
    @Test("The synthesisFailed wrapper is unwrapped before judging")
    func wrapperIsUnwrapped() {
        #expect(!SummarizationRetryPolicy.isRetryable(
            SummarizationError.synthesisFailed(underlying: CancellationError())))
        #expect(!SummarizationRetryPolicy.isRetryable(
            SummarizationError.synthesisFailed(underlying: SummarizationError.providerUnavailable)))
        // …and a wrapped transient error is still transient.
        #expect(SummarizationRetryPolicy.isRetryable(
            SummarizationError.synthesisFailed(underlying: MysteryError())))
        // Nested twice, since synthesize can wrap something that was already wrapped.
        #expect(!SummarizationRetryPolicy.isRetryable(
            SummarizationError.synthesisFailed(
                underlying: SummarizationError.synthesisFailed(
                    underlying: SummarizationError.emptyDocumentText))))
    }

    @Test("Cancellation is never retried")
    func cancellationIsTerminal() {
        #expect(!SummarizationRetryPolicy.isRetryable(CancellationError()))
    }

    /// The provider's translation of a guardrail stop or refusal (#1765) is as deterministic as the
    /// framework errors it replaces, whichever pass met it.
    @Test("A refused document is not retried, in either pass")
    func refusalsAreTerminal() {
        let refused = SummarizationError.contentRefused(structured: false)
        #expect(!SummarizationRetryPolicy.isRetryable(refused))
        #expect(!SummarizationRetryPolicy.isRetryable(SummarizationError.synthesisFailed(underlying: refused)))
    }

    /// `SummarizationService` has already made that call a second time (2026-11-01): retrying the
    /// document would re-run every call before it to reach the same one.
    @Test("An answer that ran past the window twice is not retried, in either pass")
    func overrunsAreTerminal() {
        let overran = SummarizationError.answerOverranWindow
        #expect(!SummarizationRetryPolicy.isRetryable(overran))
        #expect(!SummarizationRetryPolicy.isRetryable(SummarizationError.synthesisFailed(underlying: overran)))
    }

    /// iOS and macOS 26 throw `GenerationError`; the arms for it were never run before #1765, since the
    /// errors were thought impossible to build in a test.
    @Test("GenerationError's guardrail stop and refusal are terminal, its rate limit is not")
    func generationErrorsAreClassified() {
        let context = LanguageModelSession.GenerationError.Context(debugDescription: "test")
        #expect(!SummarizationRetryPolicy.isRetryable(
            LanguageModelSession.GenerationError.guardrailViolation(context)))
        #expect(!SummarizationRetryPolicy.isRetryable(
            LanguageModelSession.GenerationError.refusal(.init(transcriptEntries: []), context)))
        #expect(SummarizationRetryPolicy.isRetryable(
            LanguageModelSession.GenerationError.rateLimited(context)))
    }

    /// An app built with the 27 SDKs is thrown `LanguageModelError` on a 27 system (measured on macOS
    /// 27.2, #1765). Before 1.1 the policy did not know the type, so every one was retried four times.
    @Test("LanguageModelError is classified as GenerationError is",
          .enabled(if: systemHasLanguageModelError, "LanguageModelError is iOS 27 and later"))
    func languageModelErrorsAreClassified() {
        guard #available(iOS 27.0, macOS 27.0, *) else { return }
        #expect(!SummarizationRetryPolicy.isRetryable(
            LanguageModelError.guardrailViolation(.init(debugDescription: "test"))))
        #expect(!SummarizationRetryPolicy.isRetryable(
            LanguageModelError.refusal(.init(explanation: "No.", debugDescription: "test"))))
        #expect(!SummarizationRetryPolicy.isRetryable(
            LanguageModelError.contextSizeExceeded(.init(contextSize: 4_096, tokenCount: 5_000,
                                                         debugDescription: "test"))))
        #expect(SummarizationRetryPolicy.isRetryable(
            LanguageModelError.rateLimited(.init(resetDate: nil, debugDescription: "test"))))
        #expect(SummarizationRetryPolicy.isRetryable(
            LanguageModelError.timeout(.init(debugDescription: "test"))))
        #expect(SummarizationRetryPolicy.describe(
            LanguageModelError.guardrailViolation(.init(debugDescription: "test")))
            .hasPrefix("LanguageModelError."))
    }

    /// The failure list is diagnostic, so it has to say something usable for every error — an empty
    /// or identical string for two different failures would make the list worthless.
    @Test("Every error describes itself distinguishably")
    func descriptionsAreUseful() {
        let cases: [any Error] = [
            SummarizationError.providerUnavailable,
            SummarizationError.emptyDocumentText,
            SummarizationError.contentRefused(structured: false),
            SummarizationError.answerOverranWindow,
            SummarizationError.synthesisFailed(underlying: MysteryError()),
            CancellationError(),
            MysteryError(),
        ]
        var seen: Set<String> = []
        for error in cases {
            let description = SummarizationRetryPolicy.describe(error)
            #expect(!description.isEmpty, "no description for \(error)")
            seen.insert(description)
        }
        #expect(seen.count == cases.count, "two different errors described identically: \(seen)")
        // The wrapper names what it wrapped, or the list says "synthesisFailed" 900 times.
        #expect(SummarizationRetryPolicy
            .describe(SummarizationError.synthesisFailed(underlying: MysteryError()))
            .contains("MysteryError"))
    }
}

// MARK: - SummarizationRefusalTests

/// How a guardrail stop or refusal reaches the reader, and how a structured answer that is not one is
/// told apart (#1765; 2026-10-31). The model is not run: the framework's errors are built from their
/// public initialisers.
@Suite("Summarization refusals (#1765)")
struct SummarizationRefusalTests {

    /// An error the translation must leave alone.
    private struct MysteryError: Error {}

    /// The owner's decision of 2026-10-31: a structured prompt is answered as plain text under its
    /// fields' headings and read back into them. A refusal written as the answer carries no heading,
    /// and storing it would put the refusal in the summary, so it reads as the structured refusal.
    @Test("A structured answer is read into its fields; one without the headings is a refusal")
    func structuredAnswerOrRefusal() throws {
        let schema = StructuredSummarySchema(fields: [
            StructuredSummarySchema.Field(name: "Decision", description: "The decision made"),
            StructuredSummarySchema.Field(name: "Rationale", description: "Key justifications cited"),
        ])
        let json = try AppleIntelligenceProvider.structuredJSON(
            fromAnswer: "## Decision\nNone is recorded.\n\n## Rationale\nThe gold outflow.", schema: schema)
        #expect(json == #"{"Decision": "None is recorded.", "Rationale": "The gold outflow."}"#)

        #expect(throws: SummarizationError.contentRefused(structured: true)) {
            try AppleIntelligenceProvider.structuredJSON(
                fromAnswer: "I’m sorry, but I can’t help with that request.", schema: schema)
        }
        #expect(throws: SummarizationError.contentRefused(structured: true)) {
            try AppleIntelligenceProvider.structuredJSON(fromAnswer: "## Decision\nNone.", schema: schema)
        }
    }

    @Test("GenerationError's guardrail stop and refusal become contentRefused; other errors pass through")
    func generationErrorTranslation() {
        let context = LanguageModelSession.GenerationError.Context(debugDescription: "test")
        let stopped = AppleIntelligenceProvider.translatingRefusal(
            LanguageModelSession.GenerationError.guardrailViolation(context), structured: true)
        #expect(stopped as? SummarizationError == .contentRefused(structured: true))
        let refused = AppleIntelligenceProvider.translatingRefusal(
            LanguageModelSession.GenerationError.refusal(.init(transcriptEntries: []), context), structured: false)
        #expect(refused as? SummarizationError == .contentRefused(structured: false))

        let tooLong = AppleIntelligenceProvider.translatingRefusal(
            LanguageModelSession.GenerationError.exceededContextWindowSize(context), structured: false)
        #expect(tooLong is LanguageModelSession.GenerationError)
        let mystery = AppleIntelligenceProvider.translatingRefusal(MysteryError(), structured: false)
        #expect(mystery is MysteryError)
    }

    /// What macOS 27.2 threw for the Long Telegram under the default guardrails.
    @Test("LanguageModelError's guardrail stop and refusal become contentRefused",
          .enabled(if: systemHasLanguageModelError, "LanguageModelError is iOS 27 and later"))
    func languageModelErrorTranslation() {
        guard #available(iOS 27.0, macOS 27.0, *) else { return }
        let stopped = AppleIntelligenceProvider.translatingRefusal(
            LanguageModelError.guardrailViolation(.init(debugDescription: "May contain unsafe content")),
            structured: false)
        #expect(stopped as? SummarizationError == .contentRefused(structured: false))

        let refused = AppleIntelligenceProvider.translatingRefusal(
            LanguageModelError.refusal(.init(explanation: "I can’t help with that.", debugDescription: "test")),
            structured: true)
        #expect(refused as? SummarizationError == .contentRefused(structured: true))

        let tooLong = AppleIntelligenceProvider.translatingRefusal(
            LanguageModelError.contextSizeExceeded(.init(contextSize: 4_096, tokenCount: 5_000,
                                                         debugDescription: "test")),
            structured: false)
        #expect(tooLong is LanguageModelError)
    }

    /// The reader used to see the framework's own sentence, *The model's safety guardrails were
    /// triggered.*: what stopped it, in the framework's words, and nothing about what to do.
    @Test("A refusal reads as a plain sentence, the same whichever pass met it")
    func refusalMessages() throws {
        let plain = try #require(SummarizationError.contentRefused(structured: false).errorDescription)
        #expect(plain == "Apple Intelligence declined to summarize this document. Its on-device safety rules stopped the request; nothing is wrong with the document or the app.")
        #expect(!plain.localizedCaseInsensitiveContains("guardrail"))

        let structured = try #require(SummarizationError.contentRefused(structured: true).errorDescription)
        #expect(structured == "Apple Intelligence declined to summarize this document with a structured prompt. A plain-text prompt such as “Standard Summary” may succeed.")
        // A structured prompt is answered as plain text on the same guardrails since 2026-10-31, so the
        // sentence no longer says the model holds it to stricter rules.
        #expect(!structured.contains("stricter"))

        let inSynthesis = SummarizationError.synthesisFailed(
            underlying: SummarizationError.contentRefused(structured: false))
        #expect(inSynthesis.errorDescription == plain)
        #expect(inSynthesis.localizedDescription == plain)
    }
}

// MARK: - SummarizationOverflowTests

/// How the provider tells an answer that ran past the model's window from a prompt that was over it,
/// and how the first reaches the reader (2026-11-01). The model is not run: the framework's errors are
/// built from their public initialisers, and the counts are the ones measured on a Mac under macOS 27.2.
@Suite("Summarization window overflows")
struct SummarizationOverflowTests {

    /// An error that is not an overflow.
    private struct MysteryError: Error {}

    @Test("GenerationError's window overflow is an overflow; its other errors are not")
    func generationErrorOverflow() {
        let context = LanguageModelSession.GenerationError.Context(debugDescription: "test")
        #expect(AppleIntelligenceProvider.isContextOverflow(
            LanguageModelSession.GenerationError.exceededContextWindowSize(context)))
        #expect(!AppleIntelligenceProvider.isContextOverflow(
            LanguageModelSession.GenerationError.guardrailViolation(context)))
        #expect(!AppleIntelligenceProvider.isContextOverflow(
            LanguageModelSession.GenerationError.rateLimited(context)))
        #expect(!AppleIntelligenceProvider.isContextOverflow(MysteryError()))
        #expect(!AppleIntelligenceProvider.isContextOverflow(SummarizationError.answerOverranWindow))
    }

    @Test("LanguageModelError's window overflow is an overflow; its other errors are not",
          .enabled(if: systemHasLanguageModelError, "LanguageModelError is iOS 27 and later"))
    func languageModelErrorOverflow() {
        guard #available(iOS 27.0, macOS 27.0, *) else { return }
        #expect(AppleIntelligenceProvider.isContextOverflow(
            LanguageModelError.contextSizeExceeded(.init(contextSize: 8_192, tokenCount: 8_194,
                                                         debugDescription: "test"))))
        #expect(!AppleIntelligenceProvider.isContextOverflow(
            LanguageModelError.refusal(.init(explanation: "No.", debugDescription: "test"))))
        #expect(!AppleIntelligenceProvider.isContextOverflow(
            LanguageModelError.timeout(.init(debugDescription: "test"))))
    }

    /// Measured: a prompt of 13,194 tokens was refused in 0.1 s as `contextSizeExceeded(8192, 13248)`;
    /// one of 8,023 failed after 11.1 s as `contextSizeExceeded(8192, 8194)`, and NSC 68's reduce prompt
    /// of 3,598 after 119 s as `(8192, 8193)`.
    @Test("An overflow is the answer's when the prompt's own count is under the window")
    func answerOrPrompt() {
        #expect(AppleIntelligenceProvider.answerOverranWindow(promptTokens: 8_023, contextSize: 8_192))
        #expect(AppleIntelligenceProvider.answerOverranWindow(promptTokens: 3_598, contextSize: 8_192))
        #expect(!AppleIntelligenceProvider.answerOverranWindow(promptTokens: 13_194, contextSize: 8_192))
        #expect(!AppleIntelligenceProvider.answerOverranWindow(promptTokens: 8_192, contextSize: 8_192))
        #expect(AppleIntelligenceProvider.answerOverranWindow(promptTokens: 2_900, contextSize: 4_096))
        #expect(!AppleIntelligenceProvider.answerOverranWindow(promptTokens: 5_400, contextSize: 4_096))
    }

    /// Before iOS and macOS 26.4 the model cannot count a prompt, and `GenerationError` carries no
    /// counts; a command-line tool in the iOS 27.0 simulator read the window as 0. A wrong guess costs
    /// one more refusal, measured at 0.1 s.
    @Test("With no count, or no window stated, the overflow is taken as the answer's")
    func noCountMeansTheAnswer() {
        #expect(AppleIntelligenceProvider.answerOverranWindow(promptTokens: nil, contextSize: 4_096))
        #expect(AppleIntelligenceProvider.answerOverranWindow(promptTokens: 5_000, contextSize: 0))
    }

    @Test("An answer that ran past the window reads as a plain sentence, the same whichever pass met it")
    func overrunMessage() throws {
        let plain = try #require(SummarizationError.answerOverranWindow.errorDescription)
        #expect(plain == "Apple Intelligence wrote more than it can hold while summarizing this document, and did again when asked once more. Summarizing it again may succeed.")
        #expect(!plain.localizedCaseInsensitiveContains("context"))
        #expect(!plain.localizedCaseInsensitiveContains("token"))

        let inSynthesis = SummarizationError.synthesisFailed(underlying: SummarizationError.answerOverranWindow)
        #expect(inSynthesis.errorDescription == plain)
        #expect(inSynthesis.localizedDescription == plain)
    }
}

// MARK: - BatchRunTallyTests

/// The tally's arithmetic. Small, but it is the type the whole fix rests on.
@Suite("Batch run tally")
struct BatchRunTallyTests {

    @Test("finished counts both outcomes, not attempts in flight")
    func finished() {
        #expect(BatchRunTally(succeeded: 3, failed: 2, attemptable: 10).finished == 5)
        #expect(BatchRunTally.zero.finished == 0)
    }

    /// The state a re-run lands in, and the one that used to be indistinguishable from having
    /// failed every document.
    @Test("A wholly-skipped scope is recognisable as such")
    func entirelySkipped() {
        #expect(BatchRunTally(skipped: 1_400, attemptable: 0).isEntirelySkipped)
        // Not the same as a scope with genuinely nothing in it…
        #expect(!BatchRunTally.zero.isEntirelySkipped)
        // …nor as a partial re-run, which has real work to do.
        #expect(!BatchRunTally(skipped: 900, attemptable: 500).isEntirelySkipped)
    }

    /// The invariant the UI depends on: the numerator cannot exceed the denominator, so the bar
    /// cannot overfill and cannot stop short because of documents that were never attempted.
    @Test("Skipped documents are outside the denominator")
    func skippedAreOutsideTheDenominator() {
        let tally = BatchRunTally(succeeded: 500, failed: 0, skipped: 900, attemptable: 500)
        #expect(tally.finished == tally.attemptable, "a finished run must reach its total")
        #expect(tally.finished <= tally.attemptable)
    }
}

// MARK: - SummarizationStepLabelTests

/// Sub-document progress (#560 PR B) — the only thing that moves while a long document is working.
///
/// `frus1872p2v4/d39` is 1,282,843 characters and chunks into 131 parts. During it the run's own
/// counter cannot advance at all, which is what made a working run read as frozen.
@Suite("Summarization step label")
struct SummarizationStepLabelTests {

    /// Most documents fit one model call. "part 1 of 1" on every ordinary document would be noise,
    /// and would make a healthy run look like it was struggling.
    @Test("A document that fits one call reports nothing")
    func singleCallIsSilent() {
        #expect(SummarizationStepLabel.detail(for: nil) == nil)
        #expect(SummarizationStepLabel.detail(for: .singleCall) == nil)
    }

    @Test("A chunked document reports its position")
    func chunkPosition() {
        let detail = SummarizationStepLabel.detail(for: .chunk(index: 12, of: 131))
        #expect(detail == "part 12 of 131")
    }

    @Test("The reduce pass says what it is doing")
    func synthesizing() {
        let detail = SummarizationStepLabel.detail(for: .synthesizing(parts: 131))
        #expect(detail?.contains("131") == true)
        #expect(detail?.contains("combining") == true)
        // Distinguishable from the map pass, or the two phases look like one stalled counter.
        #expect(detail != SummarizationStepLabel.detail(for: .chunk(index: 131, of: 131)))
    }

    /// The chunk indices are 1-based on the wire, because they are shown to a person. An off-by-one
    /// here reads as "part 0 of 131" on the first chunk of every long document.
    @Test("Chunk indices are 1-based at the boundary")
    func oneBased() {
        #expect(SummarizationStepLabel.detail(for: .chunk(index: 1, of: 131)) == "part 1 of 131")
        #expect(SummarizationStepLabel.detail(for: .chunk(index: 131, of: 131)) == "part 131 of 131")
    }
}

// MARK: - SummarizationSettingsPersistenceTests

/// The two settings defects in #560 PR B, both of which are only visible by reading the source:
/// a `@State` that silently discards the user's choice, and a hint that promised something the
/// system does not do.
@Suite("Bulk summarization settings")
struct SummarizationSettingsPersistenceTests {

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appending(path: path), encoding: .utf8)
        #expect(text.count > 1_000, "\(path) is implausibly small — did it move?")
        return text
    }

    /// It was `@State`, so SwiftUI discarded it on every sheet dismissal and every run silently
    /// restarted at 2. No runtime test in this bundle can open the sheet twice.
    @Test("The concurrency limit is persisted, under its own key")
    func concurrencyIsPersisted() throws {
        let view = try Self.source("FRUSExplorer/Summarization/BackgroundSummarizationSettingsView.swift")
        #expect(view.contains("@AppStorage(SettingsKeys.summarizationConcurrencyLimit) private var concurrencyLimit"),
                "the user's choice must survive the sheet closing")
        #expect(!view.contains("@State private var concurrencyLimit"))

        // Its own key. Reusing the downloads key would make one slider move the other.
        let settings = try Self.source("FRUSExplorer/Settings/SettingsView.swift")
        #expect(settings.contains(#"static let summarizationConcurrencyLimit = "frus.summarization.concurrencyLimit""#))
        #expect(settings.contains(#"static let concurrentDownloadLimit = "frus.concurrentDownloadLimit""#),
                "the downloads key must still be distinct")
    }

    /// "Higher values summarize faster but may exceed the model's rate limit" was wrong twice over:
    /// on-device generation serialises, and the app pattern-matches no rate-limit error anywhere.
    @Test("The concurrency hint no longer promises a rate limit")
    func hintIsHonest() throws {
        let view = try Self.source("FRUSExplorer/Summarization/BackgroundSummarizationSettingsView.swift")
        #expect(!view.contains("may exceed the model's rate limit"))
        #expect(!view.contains(#""bg.summarizer.concurrency.hint""#),
                "the old key must go with the old text, or a translation could resurrect it")
        #expect(view.contains("one summary at a time"))
    }

    /// The run is honestly hours. Saying so at the point of commitment is what separates a long
    /// wait from a wait that reads as a hang.
    @Test("The start control admits how long a large run takes")
    func durationIsStated() throws {
        let view = try Self.source("FRUSExplorer/Summarization/BackgroundSummarizationSettingsView.swift")
        #expect(view.contains("several hours"))
        // But no estimate: per-document time varies by two orders of magnitude with length.
        #expect(!view.contains("estimatedMinutes"))
        #expect(!view.contains("timeRemaining"))
    }
}
