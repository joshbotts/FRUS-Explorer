// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

// MARK: - SummarizationRetryPolicyTests

/// The #560 retry classification.
///
/// Apple Intelligence is not available in the test host, so nothing here can exercise a real
/// `GenerationError`. What *is* testable — and is where the risk actually lives — is the policy's
/// shape: that the default is to retry, that the `.synthesisFailed` wrapper is unwrapped before
/// anything is judged, and that the errors this app raises itself are classified correctly.
///
/// Version history:
///   1.0 — #560: initial implementation
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

    /// The failure list is diagnostic, so it has to say something usable for every error — an empty
    /// or identical string for two different failures would make the list worthless.
    @Test("Every error describes itself distinguishably")
    func descriptionsAreUseful() {
        let cases: [any Error] = [
            SummarizationError.providerUnavailable,
            SummarizationError.emptyDocumentText,
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
