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
/// A text's tokens are estimated by ``estimateTokens(_:)``: a quarter of a token a character, as
/// `⌈characters ÷ 4⌉` was, except that a decimal digit costs a whole token and a punctuation mark
/// half of one. Prose is overestimated: the model's own count runs to about four fifths of it.
/// That way an error makes an extra chunk rather than exceeding the context window.
///
/// ## An answer that runs past the window
/// The budget bounds a call's prompt only; the answer shares the model's window with it, and now and
/// then the model writes on until the window ends it. A provider throws
/// `SummarizationError.answerOverranWindow` for such an answer, and every model call this service
/// makes goes through ``answer(from:request:prompt:)``, which asks for that one answer once more. So
/// one runaway costs one more call, not the run. Measured on a Mac under macOS 27.2 (2026-11-01): the
/// one answer of 644 calls that ran past the window, in NSC 68's first reduce at a 7,168 budget, came
/// after 119 s, and the same prompt asked five more times fitted every time, in 28 to 51 s. The model
/// samples, so a second answer is a fresh draw.
///
/// ## An answer that copies the document
/// Now and then the model answers a part of a transcript by writing the transcript out: a Standard
/// answer pastes its speaker turns after its own paragraph, a Meeting Record fills Key Participants with
/// them. ``answer(from:request:prompt:)`` drops that copy from the answer to a part of the document
/// (``CopiedPassages``), under a built-in template only. Asking again would not help: the copy belongs
/// to the part, not the draw.
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
///   1.4 — 2026-10-31: `summarize` pushes the summary's `indexedText` (a structured summary's fields as
///          plain text) into FTS5, where it pushed the stored JSON
///   1.5 — 2026-10-31: `estimateTokens` costs a digit a token and a punctuation mark half of one, and
///          every split and cap cuts by the estimate, where they assumed four characters a token
///   1.6 — 2026-11-01: a call whose answer ran past the model's window is made once more
///          (``answer(from:request:prompt:)``)
///   1.7 — 2026-11-01: a built-in template's answer to a part of the document loses what it copied of
///          that part word for word (``CopiedPassages``)
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
        let text = summary.indexedText
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
            let result = try await answer(from: provider, request: req, prompt: prompt)
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

    /// Estimates a text's tokens on the on-device model: the sum of its scalars' ``tokenWeight(of:)``,
    /// rounded up.
    ///
    /// Letters and spaces cost a quarter of a token each, as under `⌈characters ÷ 4⌉`, the estimate
    /// this replaced on 2026-10-31. The digits and punctuation are what that missed. FRUS prints many
    /// tables as running text: claims schedules, tariff schedules, relief tonnages. These cost the model
    /// about a token a digit, and by its own `tokenCount(for:)` one such chunk of 9,377 characters was
    /// 5,400 tokens, 2.30× characters ÷ 4. On a 4,096-token window that prompt is refused. Over 4,456
    /// chunks of 655 documents from 149 volumes, the model's count was at most 1.23× this estimate, which
    /// ``documentBudget(promptText:responseFormat:limit:)``'s one-sixth reserve covers, and at the median
    /// 0.78×. Prose takes 3–5% more chunks than under characters ÷ 4.
    func estimateTokens(_ text: String) -> Int {
        Int(text.unicodeScalars.reduce(0.0) { $0 + Self.tokenWeight(of: $1) }.rounded(.up))
    }

    /// What one Unicode scalar costs in ``estimateTokens(_:)``: a decimal digit 1, a punctuation mark ½,
    /// anything else ¼.
    static func tokenWeight(of scalar: Unicode.Scalar) -> Double {
        if CharacterSet.decimalDigits.contains(scalar) { return 1 }
        if CharacterSet.punctuationCharacters.contains(scalar) { return 0.5 }
        return 0.25
    }

    /// The end of the longest run of `text` from `start` whose estimate fits `maxTokens`, and never
    /// less than one character, so a split always makes progress.
    private func endOfFittingRun(in text: String, from start: String.Index, maxTokens: Int) -> String.Index {
        let limit = Double(max(1, maxTokens))
        var weight = 0.0
        var index = start
        while index < text.endIndex {
            let characterWeight = text[index].unicodeScalars.reduce(0.0) { $0 + Self.tokenWeight(of: $1) }
            if index > start && weight + characterWeight > limit { break }
            weight += characterWeight
            index = text.index(after: index)
        }
        return index
    }

    /// The longest prefix of `text` whose estimate fits `maxTokens`.
    func prefix(of text: String, fittingTokens maxTokens: Int) -> String {
        String(text[..<endOfFittingRun(in: text, from: text.startIndex, maxTokens: maxTokens)])
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
    /// sentence boundaries, then by the estimate for a runaway sentence — so **no
    /// chunk's estimate exceeds `maxTokens`**, and a giant table or unbroken block is cut
    /// to fit like any other text (``estimateTokens(_:)`` says how near the model's own
    /// count the estimate stays).
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
    /// boundaries where possible, falling back to ``hardSplit(_:maxTokens:)`` for a single
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

    /// Last-resort split for text with no usable sentence boundaries: pieces whose estimate fits
    /// `maxTokens`, so a run of digits is cut shorter than prose.
    func hardSplit(_ text: String, maxTokens: Int) -> [String] {
        var pieces: [String] = []
        var index = text.startIndex
        while index < text.endIndex {
            let end = endOfFittingRun(in: text, from: index, maxTokens: maxTokens)
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

    /// One model call, made once more when its answer ran past the model's window
    /// (`SummarizationError.answerOverranWindow`; see the type's *An answer that runs past the window*),
    /// with what it copied of the document dropped (``CopiedPassages/dropped(from:request:prompt:)``).
    ///
    /// A second overrun is thrown, and the retry policy does not repeat the document for it. Any other
    /// error is thrown at once, as before: a prompt over the window is the framework's own error, which
    /// would be refused again.
    private func answer(
        from provider: any SummarizationProvider,
        request: SummarizationRequest,
        prompt: SummarizationPromptSnapshot
    ) async throws -> SummarizationResult {
        let result: SummarizationResult
        do {
            result = try await provider.summarize(request: request, prompt: prompt)
        } catch SummarizationError.answerOverranWindow {
            #if DEBUG
            print("[SummarizationService] An answer ran past the model's window; asking once more")
            #endif
            try Task.checkCancellation()
            result = try await provider.summarize(request: request, prompt: prompt)
        }
        return CopiedPassages.dropped(from: result, request: request, prompt: prompt)
    }

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
            let result = try await answer(from: provider, request: req, prompt: prompt)
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
                    let text = try await answer(
                        from: provider, request: req, prompt: wrapped(firstPart: first, lastPart: last)).text
                    next.append((text: text, first: first, last: last))
                }
                level = next
            }

            // Final synthesis over the (now-fitting) summaries, which cover every part. If a
            // degenerate level still exceeds budget, fold it to a single capped entry so the
            // call can't overflow — graceful degradation rather than failure.
            var chunks = labelled(level)
            if estimateTokens(chunks.joined(separator: "\n\n")) > budget {
                chunks = [prefix(of: chunks.joined(separator: "\n\n"), fittingTokens: budget)]
            }
            let req = SummarizationRequest(
                documentId: documentId, volumeId: volumeId,
                chunks: chunks, isSynthesisPass: true)
            return try await answer(
                from: provider, request: req, prompt: wrapped(firstPart: 1, lastPart: partCount)).text
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
    /// `maxTokens`. A single summary larger than the budget is cut to the budget's estimate so
    /// it can fit, guaranteeing the reduce always makes progress.
    func batch(_ summaries: [String], maxTokens: Int) -> [[String]] {
        var batches: [[String]] = []
        var current: [String] = []
        var currentTokens = 0

        for summary in summaries {
            var piece = summary
            var pieceTokens = estimateTokens(piece)
            if pieceTokens > maxTokens {
                piece = prefix(of: piece, fittingTokens: maxTokens)
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

// MARK: - CopiedPassages

/// What an answer copied, word for word, of the part of the document its call read, and the answer
/// without it (the owner's decision of 2026-11-01).
///
/// ## What counts as copied
/// A **run** is ten words in a row (``runLength``), a text's words being its letters and digits,
/// lowercased, cut at every other character. A word of an answer is *copied* when it sits in a run of
/// the answer that the part also holds, and an answer's *share* is the fraction of its runs the part
/// holds.
///
/// ## What is dropped
/// - A plain answer loses each paragraph at least half of whose runs the part holds
///   (``paragraphShare``): a paragraph of under ten words has no run and stays. The model's own
///   paragraph comes first, and stays. An answer every paragraph of which would go is kept as it is; no
///   answer measured was one.
/// - A structured answer's field is left empty when ``fieldWords`` or more of its words are copied and
///   the part holds half its runs or more (``fieldShare``). Its other fields stay as they are.
///
/// ## What it was measured on (2026-11-01, an M5 Mac under macOS 27.2)
/// 107 documents from 1861 to 1992, Standard over all of them and Meeting Record over the 35 verbatim
/// records and transcripts, at the prompt budgets of an 8,192-token window and of a 4,096-token one:
/// 521 answers to parts of documents. One copied, at the smaller budget: the Johnson–Russell telephone
/// conversation of 27 May 1964 (`frus1964-68v27/d52`), its Meeting Record's Key Participants 818 words
/// of the transcript's speaker turns. The ExComm meeting of 16 October 1962 (`frus1961-63v11/d21`)
/// did the same at that budget in one of two runs (1,328 words). Drawn again, a part that copied
/// copied again: d52's in 8 draws of 10; and the two parts of d21 that copied under the estimate used
/// before 2026-10-31, its Meeting Record part in 4 of 10 and its Standard part in all 6 (from 128 to
/// 1,931 words, pasted after the model's own paragraph). So asking once more would not help. Every
/// copied field was 315 copied words or more at a share of 0.68 or more. What the rules leave: no
/// paragraph of 540 Standard answers reached a share of 0.5 (the highest was 0.43, 68 of 104 words); a
/// Meeting Record copies participants lists and the texts a meeting agreed, 125 words at most at a
/// share of 0.5 or more and 255 at any; Relevance Assessment's 137 answers, asked for "specific content
/// from the document", copied 26 words at most. An instruction to answer in its own words did not stop
/// the copying (8 of 10 draws of d21's Standard part still copied), and made the other summaries about
/// 13% shorter.
///
/// ## Built-in templates only
/// Only under a prompt whose text and format are a built-in template's (``applies(to:)``), the prompts
/// it was measured under. A reader's own prompt may ask for a quotation, and keeps it.
///
/// ## Not a synthesis
/// A synthesis call reads the parts' summaries, not the document, and carrying their words into its
/// answer is its work, so it is left as it is.
///
/// ## Log prefix
/// `[CopiedPassages]`
///
/// Version history:
///   1.0 — 2026-11-01: initial implementation
enum CopiedPassages {

    /// The words in a row that make a run.
    static let runLength = 10

    /// The fraction of a plain answer's paragraph's runs, held by the part read, at which the paragraph
    /// is dropped.
    static let paragraphShare = 0.5

    /// The copied words at which a structured field may be emptied: between the most a field copied
    /// legitimately with half its runs or more held by the part (125, a participants list) and the
    /// least a copy did (315).
    static let fieldWords = 200

    /// The fraction of a structured field's runs, held by the part read, at which a field of
    /// ``fieldWords`` copied words or more is emptied.
    static let fieldShare = 0.5

    /// How much of a text sits in runs another text holds.
    struct Measure: Equatable {
        /// The text's words.
        let words: Int
        /// The text's words that sit in a run the other text holds.
        let copiedWords: Int
        /// The fraction of the text's runs the other text holds: 0 for a text shorter than a run.
        let share: Double
    }

    /// `result` without what it copied of the part `request` read, or `result` itself for a synthesis,
    /// under a prompt that is not a built-in template's, or when nothing is to go.
    static func dropped(
        from result: SummarizationResult,
        request: SummarizationRequest,
        prompt: SummarizationPromptSnapshot
    ) -> SummarizationResult {
        guard !request.isSynthesisPass, applies(to: prompt) else { return result }
        let held = runs(in: request.chunks.joined(separator: "\n\n"))
        guard !held.isEmpty else { return result }
        let text: String
        switch result.responseFormat {
        case .general:
            text = withoutCopiedParagraphs(result.text, held: held)
        case .structured(let schema):
            text = withoutCopiedFields(result.text, schema: schema, held: held)
        }
        guard text != result.text else { return result }
        #if DEBUG
        print("[CopiedPassages] An answer copied its part; \(result.text.count) characters became \(text.count)")
        #endif
        return SummarizationResult(text: text, responseFormat: result.responseFormat, wasChunked: result.wasChunked)
    }

    /// Whether `prompt` is a built-in template's: its text and format those of one of
    /// `SummarizationPromptSeeder.standardTemplates`, to which the seeder brings every standard prompt
    /// at launch (`refreshStandardPrompts(context:)`). A reader's copy of a template made with Use
    /// Template is one too, until its text is edited.
    static func applies(to prompt: SummarizationPromptSnapshot) -> Bool {
        SummarizationPromptSeeder.standardTemplates.contains {
            $0.promptText == prompt.promptText && $0.responseFormat == prompt.responseFormat
        }
    }

    /// `answer` without each paragraph (lines between blank lines) at least ``paragraphShare`` of whose
    /// runs are in `held`, rejoined by blank lines; or `answer` as it is when no paragraph would go, or
    /// every one would.
    static func withoutCopiedParagraphs(_ answer: String, held: Set<String>) -> String {
        var paragraphs: [String] = []
        var lines: [Substring] = []
        for line in answer.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.allSatisfy(\.isWhitespace) {
                if !lines.isEmpty { paragraphs.append(lines.joined(separator: "\n")) }
                lines = []
            } else {
                lines.append(line)
            }
        }
        if !lines.isEmpty { paragraphs.append(lines.joined(separator: "\n")) }

        let kept = paragraphs.filter { measure($0, against: held).share < paragraphShare }
        guard kept.count < paragraphs.count, !kept.isEmpty else { return answer }
        return kept.joined(separator: "\n\n")
    }

    /// `json`, a structured summary's object, with each field that copied ``fieldWords`` words or more
    /// at a share of ``fieldShare`` or more left empty, its members in `schema`'s order
    /// (`StructuredSectionAnswer.jsonString(_:schema:)`); or `json` as it is when no field would be
    /// emptied, or it is not an object of strings.
    static func withoutCopiedFields(_ json: String, schema: StructuredSummarySchema, held: Set<String>) -> String {
        guard let data = json.data(using: .utf8),
              let values = (try? JSONSerialization.jsonObject(with: data)) as? [String: String]
        else { return json }
        var kept = values
        for field in schema.fields {
            guard let value = values[field.name] else { continue }
            let measure = measure(value, against: held)
            if measure.copiedWords >= fieldWords && measure.share >= fieldShare { kept[field.name] = "" }
        }
        guard kept != values else { return json }
        return StructuredSectionAnswer.jsonString(kept, schema: schema)
    }

    /// How much of `text` sits in runs `held` holds.
    static func measure(_ text: String, against held: Set<String>) -> Measure {
        let words = words(in: text)
        guard words.count >= runLength else { return Measure(words: words.count, copiedWords: 0, share: 0) }
        let runCount = words.count - runLength + 1
        var copied = [Bool](repeating: false, count: words.count)
        var found = 0
        for start in 0..<runCount where held.contains(words[start..<start + runLength].joined(separator: " ")) {
            found += 1
            for index in start..<start + runLength { copied[index] = true }
        }
        return Measure(words: words.count, copiedWords: copied.filter { $0 }.count,
                       share: Double(found) / Double(runCount))
    }

    /// Every run of ``runLength`` words in `text`, each its words joined by spaces.
    static func runs(in text: String) -> Set<String> {
        let words = words(in: text)
        guard words.count >= runLength else { return [] }
        return Set((0...(words.count - runLength)).map { words[$0..<$0 + runLength].joined(separator: " ") })
    }

    /// `text`'s words: its runs of letters and digits, lowercased.
    static func words(in text: String) -> [String] {
        var words: [String] = []
        var current = ""
        for character in text.lowercased() {
            if character.isLetter || character.isNumber {
                current.append(character)
            } else if !current.isEmpty {
                words.append(current)
                current = ""
            }
        }
        if !current.isEmpty { words.append(current) }
        return words
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
