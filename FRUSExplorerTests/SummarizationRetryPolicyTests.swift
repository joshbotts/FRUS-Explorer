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
