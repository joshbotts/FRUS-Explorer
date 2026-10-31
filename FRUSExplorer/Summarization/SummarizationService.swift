// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - SummarizationStep

/// Where a single document's summarization has got to (#560).
///
/// A document long enough to be chunked is the case where a bulk run looks frozen: the run's own
/// counter cannot move until the whole document finishes, and `frus1872p2v4/d39` — 1,282,843
/// characters, 131 chunks — takes many minutes during which nothing above it changes. Reporting the
/// step turns that silence into visible movement without pretending the work is faster.
///
/// Emitted once per model call, so a caller must expect these at whatever rate the model returns
/// and coalesce before touching the UI.
///
/// Version history:
///   1.0 — #560 PR B: initial implementation
public enum SummarizationStep: Sendable, Equatable {
    /// The document fits one call; there is no sub-document progress to report.
    case singleCall
    /// The map pass: chunk `index` of `total`, both 1-based.
    case chunk(index: Int, of: Int)
    /// The reduce pass, combining `parts` partial summaries.
    case synthesizing(parts: Int)
}

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
///   1.3 — 2026-10-31: a synthesis call wraps the reader's prompt and labels each partial summary
///          with its part, so a long document's summary covers the whole document
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
        activeProjectId: UUID?,
        onStep: (@Sendable (SummarizationStep) -> Void)? = nil
    ) async throws -> GeneratedSummary {
        #if DEBUG
        print("[SummarizationService] Starting summarization for \(volumeId)/\(documentId)")
        #endif

        // R-5 P3b-2 (design Q-8 d-cloud): the hash of the text being summarised, read BEFORE the
        // provider call. A chunked document takes minutes and a download can re-index mid-run, so
        // reading it afterwards would stamp the summary with the hash of text it never saw. `nil`
        // when the document is not indexed on this device — never `""`, which would read as a
        // hash and compare unequal to every real one.
        var sourceContentHash: String? = nil
        if let pipeline = indexingPipeline,
           let row = try? await pipeline.documentRevision(volumeId: volumeId, documentId: documentId),
           !row.contentHash.isEmpty {
            sourceContentHash = row.contentHash
        }

        let (resultText, wasChunked) = try await generateSummaryText(
            documentText: documentText,
            prompt: prompt,
            provider: provider,
            documentId: documentId,
            volumeId: volumeId,
            onStep: onStep
        )

        let summary = GeneratedSummary(
            documentId: documentId,
            volumeId: volumeId,
            promptId: prompt.id,
            responseText: resultText,
            responseFormat: prompt.responseFormat,
            wasChunked: wasChunked,
            projectId: activeProjectId,
            sourceContentHash: sourceContentHash
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

    /// Produces summary text for a document body **without persisting anything** — the full
    /// token-budget → chunk → synthesize pipeline, returning the text and whether chunking was
    /// applied.
    ///
    /// `summarize(...)` wraps this to persist a document `GeneratedSummary` (and push it into
    /// FTS5). Callers that own their own storage — e.g. a Collections headnote draft, which must
    /// stay out of the document's summary carousel — call this directly so no stray document
    /// summary or search-index row is created.
    ///
    /// - Parameters:
    ///   - documentText: Plain text of the document body, paragraph-separated by `\n\n`.
    ///   - prompt: A `Sendable` snapshot of the prompt template and response-format.
    ///   - provider: The AI backend to use for inference calls.
    ///   - documentId: The FRUS document identifier (passed to the provider request for context).
    ///   - volumeId: The volume identifier (passed to the provider request for context).
    /// - Returns: The generated summary text and whether the document was chunked to fit the window.
    func generateSummaryText(
        documentText: String,
        prompt: SummarizationPromptSnapshot,
        provider: any SummarizationProvider,
        documentId: String,
        volumeId: String,
        onStep: (@Sendable (SummarizationStep) -> Void)? = nil
    ) async throws -> (text: String, wasChunked: Bool) {
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

        if estimatedTokens <= budget {
            let req = SummarizationRequest(
                documentId: documentId,
                volumeId: volumeId,
                chunks: [documentText],
                isSynthesisPass: false
            )
            onStep?(.singleCall)
            let result = try await provider.summarize(request: req, prompt: prompt)
            return (result.text, false)
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
                provider: provider,
                onStep: onStep
            )
            let resultText = try await synthesize(
                partialSummaries: partials,
                prompt: prompt,
                provider: provider,
                documentId: documentId,
                volumeId: volumeId,
                tokenLimit: tokenLimit,
                onStep: onStep
            )
            return (resultText, true)
        }
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
    /// allowance for the fields' headings and descriptions in the session's instructions
    /// (`StructuredSectionAnswer`), which aren't part of `promptText`. Floored so a
    /// pathologically long template still leaves a usable budget.
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

    // MARK: - Shared summariser input

    /// The document text a summariser reads, from a parsed AST.
    ///
    /// Lifted here in R-5 P3b-7 so every caller builds the SAME string. `GeneratedSummary`'s own
    /// doc comment complains that "three different recipes feed that text"; this collapses the
    /// three that matter — the document view, the background runner's two job lists, and now the
    /// review sheet — into one, so a summary made from the sheet is the summary the document view
    /// would have made.
    ///
    /// The blank-line join is load-bearing, not cosmetic: ``chunk`` partitions on `"\n\n"`, so a
    /// body joined into one line (the index's `body_text` recipe, which sets a block apart with a
    /// single space) arrives as a single paragraph and falls through to sentence-splitting — a
    /// different summary of the same document from the same prompt. That is why the sheet parses
    /// rather than reading the cheaper indexed text. Within each top-level node the text is joined
    /// as the page prints it (`FRUSASTNode.plainText`, #1421), so the model reads "(Kennan)" where it
    /// used to read "( Kennan )".
    nonisolated static func documentText(from nodes: [FRUSASTNode]) -> String {
        nodes
            .map(\.plainText)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n")
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
        activeProjectId: UUID?,
        onStep: (@Sendable (SummarizationStep) -> Void)? = nil
    ) async throws {
        _ = try await summarize(
            documentId: documentId,
            volumeId: volumeId,
            documentText: documentText,
            prompt: prompt,
            provider: provider,
            activeProjectId: activeProjectId,
            onStep: onStep
        )
    }

    // MARK: - Private

    private func summarizeChunks(
        _ chunks: [String],
        documentId: String,
        volumeId: String,
        prompt: SummarizationPromptSnapshot,
        provider: any SummarizationProvider,
        onStep: (@Sendable (SummarizationStep) -> Void)? = nil
    ) async throws -> [String] {
        var partials: [String] = []
        for (i, chunkText) in chunks.enumerated() {
            #if DEBUG
            print("[SummarizationService] Summarizing chunk \(i + 1)/\(chunks.count)")
            #endif
            onStep?(.chunk(index: i + 1, of: chunks.count))
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
    /// joined partials exceed the budget, they're grouped into batches that each fit, and
    /// each batch is synthesised into an intermediate summary; the process repeats on
    /// the intermediates until they fit, then one final synthesis produces the result.
    /// Every model call therefore stays within the window, for a document of any length.
    ///
    /// Every synthesis call runs the reader's prompt inside ``synthesisPromptText(wrapping:firstPart:lastPart:partCount:)``,
    /// over summaries labelled by ``synthesisLabel(firstPart:lastPart:partCount:)`` with the span
    /// of the document's parts each stands for, so an intermediate summary of parts 1 to 6 is
    /// labelled as such at the next level. The budget is the wrapped prompt's, which is longer
    /// than the reader's own.
    private func synthesize(
        partialSummaries: [String],
        prompt: SummarizationPromptSnapshot,
        provider: any SummarizationProvider,
        documentId: String,
        volumeId: String,
        tokenLimit: Int,
        onStep: (@Sendable (SummarizationStep) -> Void)? = nil
    ) async throws -> String {
        do {
            // Reported once, at the top: the reduce pass is a single logical phase from the
            // reader's point of view, and its own level-by-level detail would flicker.
            onStep?(.synthesizing(parts: partialSummaries.count))
            let partCount = partialSummaries.count
            let budget = documentBudget(
                promptText: Self.synthesisPromptText(
                    wrapping: prompt.promptText, firstPart: 1, lastPart: partCount, partCount: partCount),
                responseFormat: prompt.responseFormat,
                limit: tokenLimit)
            // Each entry of a reduce level, with the first and last of the document's parts it covers.
            var level = partialSummaries.enumerated().map { (text: $0.element, first: $0.offset + 1, last: $0.offset + 1) }
            func labelled(_ entries: [(text: String, first: Int, last: Int)]) -> [String] {
                entries.map {
                    Self.synthesisLabel(firstPart: $0.first, lastPart: $0.last, partCount: partCount) + "\n" + $0.text
                }
            }
            func wrapped(firstPart: Int, lastPart: Int) -> SummarizationPromptSnapshot {
                SummarizationPromptSnapshot(
                    id: prompt.id,
                    promptText: Self.synthesisPromptText(
                        wrapping: prompt.promptText, firstPart: firstPart, lastPart: lastPart, partCount: partCount),
                    responseFormat: prompt.responseFormat)
            }

            // Reduce level-by-level until everything fits one synthesis call.
            while level.count > 1,
                  estimateTokens(labelled(level).joined(separator: "\n\n")) > budget {
                let batches = batch(labelled(level), maxTokens: budget)
                // No progress possible (each summary already fills a batch on its own):
                // stop and let the final force-fit handle it, rather than looping.
                if batches.count >= level.count { break }
                #if DEBUG
                print("[SummarizationService] Reduce level: \(level.count) → \(batches.count) batches")
                #endif
                // `batch` keeps the order and puts every entry in exactly one batch, so the
                // spans follow from the batch sizes.
                var next: [(text: String, first: Int, last: Int)] = []
                var start = 0
                for group in batches {
                    let first = level[start].first
                    let last = level[start + group.count - 1].last
                    start += group.count
                    let req = SummarizationRequest(
                        documentId: documentId, volumeId: volumeId,
                        chunks: group, isSynthesisPass: true)
                    let text = try await provider.summarize(
                        request: req, prompt: wrapped(firstPart: first, lastPart: last)).text
                    next.append((text: text, first: first, last: last))
                }
                level = next
            }

            // Final synthesis over the (now-fitting) summaries, which cover every part. If a
            // degenerate level still exceeds budget, fold it to a single capped entry so the
            // call can't overflow — graceful degradation rather than failure.
            var chunks = labelled(level)
            if estimateTokens(chunks.joined(separator: "\n\n")) > budget {
                chunks = [String(chunks.joined(separator: "\n\n").prefix(max(1, budget * 4)))]
            }
            let req = SummarizationRequest(
                documentId: documentId, volumeId: volumeId,
                chunks: chunks, isSynthesisPass: true)
            return try await provider.summarize(
                request: req, prompt: wrapped(firstPart: 1, lastPart: partCount)).text
        } catch {
            throw SummarizationError.synthesisFailed(underlying: error)
        }
    }

    // MARK: - Synthesis prompt

    /// The prompt a synthesis call runs: the reader's own prompt, without its `{{DOCUMENT}}`, inside
    /// an instruction that says the input is the summaries of one document's parts, in order.
    ///
    /// Until 2026-10-31 a synthesis call ran the reader's prompt over the joined partial summaries
    /// as it stood, so the on-device model read them as one short document and answered for one of
    /// them. Measured on a Mac under macOS 27.2 with a throwaway harness that ran this service's
    /// chunking and reduce, and #1765's guardrails, over six long documents under the Standard Summary
    /// (17 runs; each run's partials synthesised both ways): one part supplied more than half of the
    /// final summary in 7 of 14 runs of documents of more than two parts, and none of the Long
    /// Telegram's (`frus1946v06/d475`) three named the Chargé, while two of three of
    /// `frus1961-63v05/d87`'s ended on the lunch that closes the record. Under this instruction it was
    /// 1 of 14, the Long Telegram named the Chargé in 3 of 3, and the Standard Summary's two to four
    /// sentences mostly held. Framing the summaries without restating the request made the model
    /// copy every summary back, and the same framing as session instructions still answered for the
    /// last part, which is why the request is restated inside it. The owner adopted it for every
    /// prompt, plain-text and structured, on 2026-10-31.
    ///
    /// The wording is the measured wording: a change to it is a change the measurement no longer
    /// covers. It is model-facing and never shown, so it is not localized.
    nonisolated static func synthesisPromptText(
        wrapping promptText: String, firstPart: Int, lastPart: Int, partCount: Int
    ) -> String {
        let request = promptText
            .replacingOccurrences(of: "{{DOCUMENT}}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return """
            Below are summaries of parts \(firstPart) to \(lastPart), in order, of one long document \
            that was read in \(partCount) consecutive parts. Read them as one document, then carry out \
            this request for all of it. Answer once, at the length the request asks for: combine the \
            parts into the main line of the document from beginning to end, rather than going through \
            them one by one or listing every detail, and keep the names the summaries give.

            \(request)

            {{DOCUMENT}}
            """
    }

    /// The line above a summary in a synthesis call: "Summary of part 3 of 5:", or "Summary of part
    /// 1–6 of 18:" for an intermediate summary of several parts.
    ///
    /// Not "Part 3 of 5:", which was measured: over one set of a structured prompt's partials
    /// (`frus1961-63v09/d194`, Meeting Record) those labels made Apple's default guardrails refuse
    /// the synthesis call every time, 6 of 6 inside the wrapper and 2 of 2 with the reader's prompt
    /// alone, where the same calls without labels passed. This label passed there, and no synthesis
    /// measured was refused with it where the unwrapped call passed.
    nonisolated static func synthesisLabel(firstPart: Int, lastPart: Int, partCount: Int) -> String {
        let span = firstPart == lastPart ? "\(firstPart)" : "\(firstPart)–\(lastPart)"
        return "Summary of part \(span) of \(partCount):"
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

// MARK: - SummarizationStepLabel

/// Renders a ``SummarizationStep`` as the phrase shown beside the document being summarized (#560).
///
/// Shared rather than duplicated because two surfaces show it — the batch sheet and the global
/// active-task chip — and this repo has a documented history of parallel implementations drifting
/// apart (`project_dual_settings_views`, and #617's Mac-unreachable toggle).
///
/// Returns `nil` for a document that fits one model call. Most documents do, and "part 1 of 1" is
/// noise that would make a normal run look like it was struggling.
///
/// Version history:
///   1.0 — #560 PR B: initial implementation
enum SummarizationStepLabel {

    /// The phrase for `step`, or `nil` when there is nothing worth saying.
    static func detail(for step: SummarizationStep?) -> String? {
        switch step {
        case nil, .singleCall:
            return nil
        case .chunk(let index, let total):
            return String(format: String(localized: "bg.summarizer.step.chunk %lld %lld",
                                         defaultValue: "part %lld of %lld"),
                          Int64(index), Int64(total))
        case .synthesizing(let parts):
            return String(format: String(localized: "bg.summarizer.step.synthesizing %lld",
                                         defaultValue: "combining %lld parts"),
                          Int64(parts))
        }
    }
}
