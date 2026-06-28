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
///   1.1 — Session 32: added `summarizeDiscarding` helper used by `BackgroundSummarizationService`
///          to avoid returning a non-`Sendable` `GeneratedSummary` across actor boundaries
///   1.2 — Optional `IndexingPipeline` injected at init; `summarize` pushes each new summary
///          into FTS5 immediately after SwiftData save for in-session searchability
actor SummarizationService {

    // MARK: - Init

    private let modelContainer: ModelContainer
    private let indexingPipeline: IndexingPipeline?

    init(modelContainer: ModelContainer, indexingPipeline: IndexingPipeline? = nil) {
        self.modelContainer = modelContainer
        self.indexingPipeline = indexingPipeline
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
        // Budget the *content* portion of each call conservatively: subtract the
        // prompt template's own tokens (so a long structured prompt doesn't push a
        // chunk over the window) plus a safety margin for token-estimate drift. This
        // same budget bounds both the per-chunk (map) and synthesis (reduce) calls.
        let budget = documentBudget(promptText: prompt.promptText,
                                    responseFormat: prompt.responseFormat,
                                    limit: tokenLimit)
        let estimatedTokens = estimateTokens(documentText)

        let resultText: String
        let wasChunked: Bool

        if estimatedTokens <= budget {
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
            let chunks = chunk(text: documentText, maxTokens: budget)
            #if DEBUG
            print("[SummarizationService] Chunked into \(chunks.count) pieces (budget=\(budget))")
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
                volumeId: volumeId,
                budget: budget
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

        // Push the new summary into FTS5 immediately so it is searchable in this session.
        let vid = summary.volumeId
        let did = summary.documentId
        let text = summary.responseText
        try? await indexingPipeline?.updateSummaryText(volumeId: vid, documentId: did, responseText: text)

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

    /// The conservative content-token budget for one model call, given the prompt
    /// template that wraps the content.
    ///
    /// Starts from the provider's window limit, then subtracts the template's own
    /// tokens (everything except the `{{DOCUMENT}}` placeholder), a proportional
    /// safety margin for token-estimate drift, and — for structured prompts — an
    /// allowance for the runtime `GenerationSchema` field descriptions, which aren't
    /// part of `promptText`. Floored so a pathologically long template still leaves a
    /// usable budget.
    func documentBudget(promptText: String, responseFormat: ResponseFormat, limit: Int) -> Int {
        let templateTokens = estimateTokens(
            promptText.replacingOccurrences(of: "{{DOCUMENT}}", with: ""))
        var reserve = limit / 6                          // safety margin (~17%)
        if case .structured = responseFormat { reserve += limit / 12 }  // schema overhead
        let floor = max(64, limit / 4)
        return max(floor, limit - templateTokens - reserve)
    }

    /// Splits `text` into chunks that each fit `maxTokens`.
    ///
    /// Accumulates whole paragraphs (`\n\n`-separated) until the next would exceed the
    /// budget. A paragraph that alone exceeds the budget is hard-split — first at
    /// sentence boundaries, then by character count for a runaway sentence — so **no
    /// chunk can exceed `maxTokens`** (a giant table or unbroken block can't overflow
    /// the model window).
    func chunk(text: String, maxTokens: Int) -> [String] {
        let paragraphs = text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var chunks: [String] = []
        var current: [String] = []
        var currentTokens = 0

        func flush() {
            if !current.isEmpty {
                chunks.append(current.joined(separator: "\n\n"))
                current = []
                currentTokens = 0
            }
        }

        for para in paragraphs {
            let paraTokens = estimateTokens(para)
            if paraTokens > maxTokens {
                // Oversized single paragraph: flush the accumulator, then split it.
                flush()
                chunks.append(contentsOf: splitOversized(para, maxTokens: maxTokens))
                continue
            }
            if !current.isEmpty && currentTokens + paraTokens > maxTokens {
                flush()
            }
            current.append(para)
            currentTokens += paraTokens
        }
        flush()

        return chunks.isEmpty ? [text] : chunks
    }

    /// Splits a paragraph that exceeds `maxTokens` into fitting pieces — at sentence
    /// boundaries where possible, falling back to a character split for a single
    /// sentence that still overflows.
    func splitOversized(_ paragraph: String, maxTokens: Int) -> [String] {
        var sentences: [String] = []
        paragraph.enumerateSubstrings(
            in: paragraph.startIndex..<paragraph.endIndex, options: .bySentences
        ) { substring, _, _, _ in
            if let substring, !substring.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                sentences.append(substring)
            }
        }
        if sentences.isEmpty { sentences = [paragraph] }

        var pieces: [String] = []
        var current = ""
        var currentTokens = 0

        func flush() {
            let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { pieces.append(trimmed) }
            current = ""
            currentTokens = 0
        }

        for sentence in sentences {
            let sentenceTokens = estimateTokens(sentence)
            if sentenceTokens > maxTokens {
                flush()
                pieces.append(contentsOf: hardSplit(sentence, maxTokens: maxTokens))
                continue
            }
            if !current.isEmpty && currentTokens + sentenceTokens > maxTokens {
                flush()
            }
            current += sentence
            currentTokens += sentenceTokens
        }
        flush()
        return pieces.isEmpty ? [paragraph] : pieces
    }

    /// Last-resort character split for text with no usable sentence boundaries.
    func hardSplit(_ text: String, maxTokens: Int) -> [String] {
        let maxChars = max(1, maxTokens * 4)
        var pieces: [String] = []
        var index = text.startIndex
        while index < text.endIndex {
            let end = text.index(index, offsetBy: maxChars, limitedBy: text.endIndex) ?? text.endIndex
            pieces.append(String(text[index..<end]))
            index = end
        }
        return pieces
    }

    // MARK: - Background use

    /// Runs `summarize` and discards the result, returning `Void`.
    ///
    /// Used by `BackgroundSummarizationService` to avoid crossing actor boundaries
    /// with the non-`Sendable` `GeneratedSummary` result.
    func summarizeDiscarding(
        documentId: String,
        volumeId: String,
        documentText: String,
        prompt: SummarizationPromptSnapshot,
        provider: any SummarizationProvider,
        activeProjectId: UUID?
    ) async throws {
        _ = try await summarize(
            documentId: documentId,
            volumeId: volumeId,
            documentText: documentText,
            prompt: prompt,
            provider: provider,
            activeProjectId: activeProjectId
        )
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

    /// Combines per-chunk partial summaries into one final summary.
    ///
    /// The naive approach — concatenating *all* partials into a single synthesis call —
    /// overflows the model window once a document is long enough (the original
    /// `frus1950v01/d85` failure). Instead this reduces **hierarchically**: while the
    /// joined partials exceed `budget`, they're grouped into batches that each fit, and
    /// each batch is synthesised into an intermediate summary; the process repeats on
    /// the intermediates until they fit, then one final synthesis produces the result.
    /// Every model call therefore stays within the window, for a document of any length.
    private func synthesize(
        partialSummaries: [String],
        prompt: SummarizationPromptSnapshot,
        provider: any SummarizationProvider,
        documentId: String,
        volumeId: String,
        budget: Int
    ) async throws -> String {
        do {
            var level = partialSummaries
            // Reduce level-by-level until everything fits one synthesis call.
            while level.count > 1,
                  estimateTokens(level.joined(separator: "\n\n")) > budget {
                let batches = batch(level, maxTokens: budget)
                // No progress possible (each summary already fills a batch on its own):
                // stop and let the final force-fit handle it, rather than looping.
                if batches.count >= level.count { break }
                #if DEBUG
                print("[SummarizationService] Reduce level: \(level.count) → \(batches.count) batches")
                #endif
                var next: [String] = []
                for group in batches {
                    let req = SummarizationRequest(
                        documentId: documentId, volumeId: volumeId,
                        chunks: group, isSynthesisPass: true)
                    next.append(try await provider.summarize(request: req, prompt: prompt).text)
                }
                level = next
            }

            // Final synthesis over the (now-fitting) summaries. If a degenerate level
            // still exceeds budget, fold it to a single capped entry so the call can't
            // overflow — graceful degradation rather than failure.
            if estimateTokens(level.joined(separator: "\n\n")) > budget {
                level = [String(level.joined(separator: "\n\n").prefix(max(1, budget * 4)))]
            }
            let req = SummarizationRequest(
                documentId: documentId, volumeId: volumeId,
                chunks: level, isSynthesisPass: true)
            return try await provider.summarize(request: req, prompt: prompt).text
        } catch {
            throw SummarizationError.synthesisFailed(underlying: error)
        }
    }

    /// Groups summaries into batches whose joined token estimate each stays within
    /// `maxTokens`. A single summary larger than the budget is character-capped so it
    /// can fit, guaranteeing the reduce always makes progress.
    func batch(_ summaries: [String], maxTokens: Int) -> [[String]] {
        var batches: [[String]] = []
        var current: [String] = []
        var currentTokens = 0

        for summary in summaries {
            var piece = summary
            var pieceTokens = estimateTokens(piece)
            if pieceTokens > maxTokens {
                piece = String(piece.prefix(max(1, maxTokens * 4)))
                pieceTokens = estimateTokens(piece)
            }
            if !current.isEmpty && currentTokens + pieceTokens > maxTokens {
                batches.append(current)
                current = []
                currentTokens = 0
            }
            current.append(piece)
            currentTokens += pieceTokens
        }
        if !current.isEmpty { batches.append(current) }
        return batches.isEmpty ? [summaries] : batches
    }
}
