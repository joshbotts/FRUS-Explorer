// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import FoundationModels

// MARK: - SummarizationRetryPolicy

/// Decides whether a summarization error is worth trying again (#560).
///
/// `withRetry` used to retry everything that was not a `CancellationError`, at 2 + 4 + 8 + 16 = 30
/// seconds of sleep per permanently-failing document — **while holding a concurrency permit**. A
/// document the model will never accept therefore cost half a minute and a slot, and in a run where
/// the model had become unavailable every remaining document paid it in turn while the progress bar
/// kept advancing.
///
/// ## Blocklist, not allowlist
/// ``isRetryable(_:)`` returns `true` for anything it does not recognise, so an error type nobody
/// anticipated keeps exactly the behaviour it has today. Only errors that are *known* to be
/// deterministic are refused. A guess in the other direction would silently stop retrying a
/// genuinely transient failure, which is a worse and much quieter regression than a wasted sleep.
///
/// The `FoundationModels` error enums are Apple-owned and not frozen, so every `switch` over them
/// carries a `default` arm that falls through to retryable.
///
/// Version history:
///   1.0 — #560: initial implementation
enum SummarizationRetryPolicy {

    /// Whether retrying `error` could plausibly succeed.
    ///
    /// - Returns: `false` only for errors known to be deterministic — the model refusing the
    ///   content, a document that cannot fit, a schema the model cannot honour, or the provider
    ///   being unavailable. `true` for everything else, including unrecognised errors.
    static func isRetryable(_ error: any Error) -> Bool {
        // `SummarizationService.synthesize` wraps *every* error — including `CancellationError` —
        // in `.synthesisFailed`, so the wrapper has to be unwrapped before anything else can be
        // classified. Without this, a cancelled run's synthesis error reads as an unrecognised
        // error and is retried four times with backoff while the user waits for Cancel to take.
        if case .synthesisFailed(let underlying)? = error as? SummarizationError {
            return isRetryable(underlying)
        }

        if error is CancellationError { return false }

        if let summarization = error as? SummarizationError {
            switch summarization {
            case .providerUnavailable:
                // Retrying cannot turn Apple Intelligence back on within 30 seconds, and the run
                // loop stops the whole run on this rather than grinding through the remainder.
                return false
            case .emptyDocumentText:
                // A property of the document. It will be empty on every attempt.
                return false
            case .synthesisFailed:
                return true   // unreachable: unwrapped above, but the switch must stay total
            }
        }

        if let generation = error as? LanguageModelSession.GenerationError {
            switch generation {
            case .exceededContextWindowSize,
                 .guardrailViolation,
                 .unsupportedGuide,
                 .unsupportedLanguageOrLocale,
                 .decodingFailure,
                 .refusal:
                // All properties of this prompt or this content, not of the moment.
                return false
            case .assetsUnavailable:
                // The model's assets are not on the device. Not a 30-second problem.
                return false
            case .rateLimited, .concurrentRequests:
                return true
            @unknown default:
                return true
            }
        }

        // A schema the model cannot compile is a property of the user's prompt template.
        if error is GenerationSchema.SchemaError { return false }

        return true
    }

    /// A short, non-localized description for the run's failure list.
    ///
    /// Deliberately not localized: this is diagnostic text that goes into a debug log and a
    /// developer-facing failure list, not user-facing copy.
    static func describe(_ error: any Error) -> String {
        if case .synthesisFailed(let underlying)? = error as? SummarizationError {
            return "synthesisFailed(\(describe(underlying)))"
        }
        if let summarization = error as? SummarizationError {
            return String(describing: summarization)
        }
        if let generation = error as? LanguageModelSession.GenerationError {
            return "GenerationError.\(String(describing: generation))"
        }
        return String(describing: type(of: error))
    }
}
