// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - SummarizationRequest

/// Input to a single `SummarizationProvider.summarize` call.
///
/// For short documents, `chunks` contains one element (the full body text).
/// For long documents chunked by `SummarizationService`, each element is one chunk.
/// On a synthesis pass, `chunks` contains the per-chunk partial summaries;
/// `isSynthesisPass` distinguishes this from a normal content call.
///
/// Version history:
///   1.0 — Session 19: initial implementation
struct SummarizationRequest: Sendable {
    let documentId: String
    let volumeId: String
    /// Pre-chunked text pieces. Single element for short documents.
    let chunks: [String]
    /// `true` when this call combines partial chunk summaries into a final result.
    let isSynthesisPass: Bool
}

// MARK: - SummarizationResult

/// Output from a single `SummarizationProvider.summarize` call.
///
/// `wasChunked` is always `false` from the provider's perspective. Providers process
/// one request at a time and have no knowledge of chunking. `SummarizationService`
/// sets `GeneratedSummary.wasChunked = true` when it applied the chunking pipeline.
///
/// Version history:
///   1.0 — Session 19: initial implementation
struct SummarizationResult: Sendable {
    let text: String
    let responseFormat: ResponseFormat
    /// Always `false` from a provider; `SummarizationService` sets the final flag.
    let wasChunked: Bool
}

// MARK: - SummarizationPromptSnapshot

/// A `Sendable` value capturing the fields needed from `SummarizationPrompt`.
///
/// `SummarizationPrompt` is a SwiftData `@Model` class and not `Sendable`. Callers
/// on the `@MainActor` (or wherever the prompt is accessible) create a snapshot before
/// crossing into any actor boundary. This lets `SummarizationService` and
/// `SummarizationProvider` implementations remain purely actor-isolated without
/// holding a non-`Sendable` reference to the SwiftData model.
///
/// Version history:
///   1.0 — Session 19: initial implementation
struct SummarizationPromptSnapshot: Sendable {
    let id: UUID
    let promptText: String
    let responseFormat: ResponseFormat

    init(from prompt: SummarizationPrompt) {
        id = prompt.id
        promptText = prompt.promptText
        responseFormat = prompt.responseFormat
    }

    init(id: UUID, promptText: String, responseFormat: ResponseFormat) {
        self.id = id
        self.promptText = promptText
        self.responseFormat = responseFormat
    }
}

// MARK: - SummarizationError

/// Errors that can occur during summarization.
///
/// Version history:
///   1.0 — Session 19: initial implementation
enum SummarizationError: Error, LocalizedError {
    /// The device does not have Apple Intelligence hardware or model assets available.
    case providerUnavailable
    /// The document contains no extractable text.
    case emptyDocumentText
    /// The synthesis pass after chunking failed.
    case synthesisFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .providerUnavailable:
            return String(
                localized: "summ.error.unavailable",
                defaultValue: "Apple Intelligence is not available on this device."
            )
        case .emptyDocumentText:
            return String(
                localized: "summ.error.empty",
                defaultValue: "The document contains no text to summarize."
            )
        case .synthesisFailed(let err):
            return String(
                localized: "summ.error.synthesis",
                defaultValue: "Summary synthesis failed: \(err.localizedDescription)"
            )
        }
    }
}
