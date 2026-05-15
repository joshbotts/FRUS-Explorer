// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - SummarizationService

/// Orchestrates the full summarization lifecycle:
/// token estimation → chunking → per-chunk summarization → synthesis → persistence.
///
/// The pipeline is provider-agnostic. Any `SummarizationProvider` actor benefits from
/// chunking automatically; only the leaf `summarize(request:prompt:)` call differs
/// between providers.
///
/// ## Chunking algorithm
/// Text is split at paragraph boundaries (`\n\n` separators, matching the output of
/// `FRUSASTNode.plainText`). Paragraphs are accumulated until adding the next paragraph
/// would exceed `maxTokens`; at that point the accumulated text is saved as a chunk and
/// a new accumulation begins. This preserves paragraph integrity. Paragraphs that exceed
/// `maxTokens` individually are placed in their own chunk rather than split mid-sentence.
///
/// ## Token estimation
/// Token count is approximated as `⌈characters ÷ 4⌉` — a common English-prose heuristic
/// (~250 words ≈ 1 000 tokens, 4 characters per word on average). The heuristic is
/// intentionally conservative: underestimating causes unnecessary chunking rather than
/// context-window errors.
///
/// ## Sendability
/// The public `summarize` method accepts a `SummarizationPromptSnapshot` (a `Sendable`
/// value type) rather than the `SummarizationPrompt` SwiftData model. Callers on the
/// `@MainActor` create the snapshot from the model before crossing into this actor.
///
/// ## Persistence
/// Each successful call inserts a `GeneratedSummary` into a new `ModelContext` created
/// from the injected `ModelContainer`. The service owns its own context to avoid
/// cross-actor `ModelContext` sharing.
///
/// ## Log prefix
/// `[SummarizationService]`
///
/// Version history:
///   1.0 — Session 19: initial implementation
actor SummarizationService {

    // MARK: - Init

    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    // MARK: - Public

    /// Summarizes a document, persists the result, and returns the saved model.
    ///
    /// - Parameters:
    ///   - documentId: The FRUS document identifier (e.g. `"d42"`).
    ///   - volumeId: The volume identifier (e.g. `"frus1969-76v01"`).
    ///   - documentText: Plain text of the document body, paragraph-separated by `\n\n`.
    ///   - prompt: A `Sendable` snapshot of the prompt template and response-format.
    ///   - provider: The AI backend to use for inference calls.
    ///   - activeProjectId: The project context at generation time; `nil` for global context.
    func summarize(
        documentId: String,
        volumeId: String,
        documentText: String,
        prompt: SummarizationPromptSnapshot,
        provider: any SummarizationProvider,
        activeProjectId: UUID?
    ) async throws -> GeneratedSummary {
        #if DEBUG
        print("[SummarizationService] Starting summarization for \(volumeId)/\(documentId)")
        #endif

        guard !documentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SummarizationError.emptyDocumentText
        }

        let tokenLimit = await provider.contextWindowTokenLimit
        let estimatedTokens = estimateTokens(documentText)

        let resultText: String
        let wasChunked: Bool

        if estimatedTokens <= tokenLimit {
            let req = SummarizationRequest(
                documentId: documentId,
                volumeId: volumeId,
                chunks: [documentText],
                isSynthesisPass: false
            )
            let result = try await provider.summarize(request: req, prompt: prompt)
            resultText = result.text
            wasChunked = false
        } else {
            let chunks = chunk(text: documentText, maxTokens: tokenLimit)
            #if DEBUG
            print("[SummarizationService] Chunked into \(chunks.count) pieces")
            #endif
            let partials = try await summarizeChunks(
                chunks,
                documentId: documentId,
                volumeId: volumeId,
                prompt: prompt,
                provider: provider
            )
            resultText = try await synthesize(
                partialSummaries: partials,
                prompt: prompt,
                provider: provider,
                documentId: documentId,
                volumeId: volumeId
            )
            wasChunked = true
        }

        let summary = GeneratedSummary(
            documentId: documentId,
            volumeId: volumeId,
            promptId: prompt.id,
            responseText: resultText,
            responseFormat: prompt.responseFormat,
            wasChunked: wasChunked,
            projectId: activeProjectId
        )

        let context = ModelContext(modelContainer)
        context.insert(summary)
        try context.save()

        #if DEBUG
        print("[SummarizationService] Saved summary \(summary.id) wasChunked=\(wasChunked)")
        #endif
        return summary
    }

    // MARK: - Internal (visible for tests)

    /// Estimates token count using the 4-characters-per-token heuristic.
    func estimateTokens(_ text: String) -> Int {
        Int((Double(text.count) / 4.0).rounded(.up))
    }

    /// Splits `text` at paragraph boundaries, accumulating paragraphs until the next
    /// addition would exceed `maxTokens`. Oversized single paragraphs get their own chunk.
    func chunk(text: String, maxTokens: Int) -> [String] {
        let paragraphs = text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var chunks: [String] = []
        var current: [String] = []
        var currentTokens = 0

        for para in paragraphs {
            let paraTokens = estimateTokens(para)
            if !current.isEmpty && currentTokens + paraTokens > maxTokens {
                chunks.append(current.joined(separator: "\n\n"))
                current = []
                currentTokens = 0
            }
            current.append(para)
            currentTokens += paraTokens
        }

        if !current.isEmpty {
            chunks.append(current.joined(separator: "\n\n"))
        }

        return chunks.isEmpty ? [text] : chunks
    }

    // MARK: - Private

    private func summarizeChunks(
        _ chunks: [String],
        documentId: String,
        volumeId: String,
        prompt: SummarizationPromptSnapshot,
        provider: any SummarizationProvider
    ) async throws -> [String] {
        var partials: [String] = []
        for (i, chunkText) in chunks.enumerated() {
            #if DEBUG
            print("[SummarizationService] Summarizing chunk \(i + 1)/\(chunks.count)")
            #endif
            let req = SummarizationRequest(
                documentId: documentId,
                volumeId: volumeId,
                chunks: [chunkText],
                isSynthesisPass: false
            )
            let result = try await provider.summarize(request: req, prompt: prompt)
            partials.append(result.text)
        }
        return partials
    }

    private func synthesize(
        partialSummaries: [String],
        prompt: SummarizationPromptSnapshot,
        provider: any SummarizationProvider,
        documentId: String,
        volumeId: String
    ) async throws -> String {
        do {
            let req = SummarizationRequest(
                documentId: documentId,
                volumeId: volumeId,
                chunks: partialSummaries,
                isSynthesisPass: true
            )
            let result = try await provider.summarize(request: req, prompt: prompt)
            return result.text
        } catch {
            throw SummarizationError.synthesisFailed(underlying: error)
        }
    }
}
