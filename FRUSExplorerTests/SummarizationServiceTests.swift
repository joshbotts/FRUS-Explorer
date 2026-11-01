// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
import SwiftData
@testable import FRUSExplorer

// MARK: - MockSummarizationProvider

/// Controllable test double for `SummarizationProvider`.
///
/// Responds with a preset `responseText`. Tracks call count, synthesis calls,
/// and the last request received so tests can assert on those values.
private actor MockSummarizationProvider: SummarizationProvider {

    var isAvailable: Bool
    var contextWindowTokenLimit: Int
    var responseText: String

    private(set) var callCount: Int = 0
    private(set) var synthesisCalls: Int = 0
    private(set) var lastRequest: SummarizationRequest?
    /// Every call's request and the prompt it ran under, in call order.
    private(set) var calls: [(request: SummarizationRequest, prompt: SummarizationPromptSnapshot)] = []

    init(
        isAvailable: Bool = true,
        tokenLimit: Int = 3_072,
        responseText: String = "Mock summary."
    ) {
        self.isAvailable = isAvailable
        self.contextWindowTokenLimit = tokenLimit
        self.responseText = responseText
    }

    func summarize(
        request: SummarizationRequest,
        prompt: SummarizationPromptSnapshot
    ) async throws -> SummarizationResult {
        guard isAvailable else { throw SummarizationError.providerUnavailable }
        callCount += 1
        lastRequest = request
        calls.append((request: request, prompt: prompt))
        if request.isSynthesisPass { synthesisCalls += 1 }
        return SummarizationResult(
            text: responseText,
            responseFormat: prompt.responseFormat,
            wasChunked: false
        )
    }
}

// MARK: - StepRecorder

/// Collects the `SummarizationStep`s a run emits.
///
/// The callback is `@Sendable` and fires from whatever context the service is on, so the storage is
/// lock-guarded rather than a bare array.
private final class StepRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [SummarizationStep] = []

    /// Records one step.
    func record(_ step: SummarizationStep) {
        lock.lock(); defer { lock.unlock() }
        storage.append(step)
    }

    /// Every step recorded so far, in order.
    var steps: [SummarizationStep] {
        lock.lock(); defer { lock.unlock() }
        return storage
    }
}

// MARK: - Fixture Helpers

/// Returns document text whose token estimate (`⌈chars/4⌉`) exceeds `tokenLimit`.
private func makeOversizedText(tokenLimit: Int) -> String {
    let targetChars = tokenLimit * 4 * 5
    let paraLen = max(1, targetChars / 3)
    let word = "diplomatic "
    var para = ""
    while para.count < paraLen { para += word }
    para = String(para.prefix(paraLen))
    return [para, para, para].joined(separator: "\n\n")
}

private func makePromptSnapshot(
    responseFormat: ResponseFormat = .general,
    promptText: String = "Summarize the following document: {{DOCUMENT}}"
) -> SummarizationPromptSnapshot {
    SummarizationPromptSnapshot(
        id: UUID(),
        promptText: promptText,
        responseFormat: responseFormat
    )
}

// MARK: - SummarizationServiceTests

struct SummarizationServiceTests {

    // MARK: - Sub-document progress (#560 PR B)

    /// Drives the **real** emitter, not the label.
    ///
    /// An earlier version of this coverage only exercised `SummarizationStepLabel`, which takes an
    /// index it is handed — so emitting `i` instead of `i + 1` from `summarizeChunks` passed the
    /// whole suite and would have shipped "part 0 of 131" as the first thing a user saw on every
    /// long document.
    @Test("A chunked document reports 1-based parts, in order, then the synthesis")
    func chunkedDocumentEmitsSteps() async throws {
        let container = try ModelContainer.makeTestContainer()
        let service = SummarizationService(modelContainer: container)
        let provider = MockSummarizationProvider(tokenLimit: 512, responseText: "Partial.")
        let prompt = makePromptSnapshot()

        let recorder = StepRecorder()
        _ = try await service.generateSummaryText(
            documentText: makeOversizedText(tokenLimit: 512),
            prompt: prompt,
            provider: provider,
            documentId: "d39",
            volumeId: "frus1872p2v4",
            onStep: { step in recorder.record(step) }
        )

        let steps = recorder.steps
        let chunks = steps.compactMap { step -> (Int, Int)? in
            if case .chunk(let index, let total) = step { return (index, total) }
            return nil
        }
        // `try #require` rather than `#expect`: `Array(1...0)` traps, so an implementation that
        // emits no steps at all would crash the test host instead of failing this test — which
        // reads as the simulator wedge rather than as a bug.
        try #require(chunks.count > 1, "the fixture must actually chunk, or this asserts nothing")

        // 1-based, contiguous, ascending — the properties a reader depends on.
        #expect(chunks.first?.0 == 1, "the first part must be 1, not 0")
        #expect(chunks.map(\.0) == Array(1...chunks.count))
        #expect(chunks.allSatisfy { $0.1 == chunks.count }, "every step must report the same total")
        #expect(chunks.last?.0 == chunks.last?.1, "the last part must equal the total")

        // And the reduce pass is reported, after the map pass.
        let synthesisIndex = steps.firstIndex { if case .synthesizing = $0 { return true }; return false }
        #expect(synthesisIndex != nil, "the synthesis pass is minutes of silence if unreported")
        if let synthesisIndex {
            let lastChunkIndex = steps.lastIndex { if case .chunk = $0 { return true }; return false }
            #expect(lastChunkIndex != nil && lastChunkIndex! < synthesisIndex)
        }
    }

    /// A document that fits one call must not emit chunk steps — "part 1 of 1" on every ordinary
    /// document would make a healthy run look like it was struggling.
    @Test("A short document emits only the single-call step")
    func shortDocumentEmitsNoParts() async throws {
        let container = try ModelContainer.makeTestContainer()
        let service = SummarizationService(modelContainer: container)
        let provider = MockSummarizationProvider(tokenLimit: 3_072)
        let recorder = StepRecorder()

        _ = try await service.generateSummaryText(
            documentText: "Short enough.",
            prompt: makePromptSnapshot(),
            provider: provider,
            documentId: "d1",
            volumeId: "vol1",
            onStep: { step in recorder.record(step) }
        )

        #expect(recorder.steps == [.singleCall])
        #expect(SummarizationStepLabel.detail(for: .singleCall) == nil)
    }

    /// The callback is optional and defaults to nil, so every existing caller — notably the
    /// single-document path in `DocumentViewModel` — is untouched.
    @Test("Summarizing without a callback still works")
    func callbackIsOptional() async throws {
        let container = try ModelContainer.makeTestContainer()
        let service = SummarizationService(modelContainer: container)
        let provider = MockSummarizationProvider(tokenLimit: 512)
        let (text, wasChunked) = try await service.generateSummaryText(
            documentText: makeOversizedText(tokenLimit: 512),
            prompt: makePromptSnapshot(),
            provider: provider,
            documentId: "d1",
            volumeId: "vol1"
        )
        #expect(!text.isEmpty)
        #expect(wasChunked)
    }

    // MARK: - ProviderAvailabilityTest

    @Test("ProviderAvailabilityTest: unavailable provider causes providerUnavailable error")
    func unavailableProviderThrows() async throws {
        let container = try ModelContainer.makeTestContainer()
        let service = SummarizationService(modelContainer: container)
        let provider = MockSummarizationProvider(isAvailable: false)
        let prompt = makePromptSnapshot()

        await #expect(throws: SummarizationError.providerUnavailable) {
            _ = try await service.summarize(
                documentId: "d1",
                volumeId: "vol1",
                documentText: "Some text.",
                prompt: prompt,
                provider: provider,
                activeProjectId: nil
            )
        }

        // Provider must not increment callCount (guard fires before summarize)
        let calls = await provider.callCount
        #expect(calls == 0)
    }

    // MARK: - ShortDocumentTest

    @Test("ShortDocumentTest: document fitting in context window is not chunked")
    func shortDocumentProducesSinglePassResult() async throws {
        let container = try ModelContainer.makeTestContainer()
        let service = SummarizationService(modelContainer: container)
        let provider = MockSummarizationProvider(tokenLimit: 3_072, responseText: "Short summary.")
        let prompt = makePromptSnapshot()

        let summary = try await service.summarize(
            documentId: "d2",
            volumeId: "vol2",
            documentText: "A brief diplomatic note.",
            prompt: prompt,
            provider: provider,
            activeProjectId: nil
        )

        #expect(!summary.wasChunked)
        #expect(summary.responseText == "Short summary.")

        let calls = await provider.callCount
        #expect(calls == 1)

        let synthCalls = await provider.synthesisCalls
        #expect(synthCalls == 0)
    }

    // MARK: - LongDocumentChunkingTest

    @Test("LongDocumentChunkingTest: oversized document is chunked; synthesis pass is called")
    func longDocumentTriggersChunkingAndSynthesis() async throws {
        let tokenLimit = 100
        let container = try ModelContainer.makeTestContainer()
        let service = SummarizationService(modelContainer: container)
        let provider = MockSummarizationProvider(
            tokenLimit: tokenLimit,
            responseText: "Partial summary."
        )
        let prompt = makePromptSnapshot()
        let longText = makeOversizedText(tokenLimit: tokenLimit)

        let summary = try await service.summarize(
            documentId: "d3",
            volumeId: "vol3",
            documentText: longText,
            prompt: prompt,
            provider: provider,
            activeProjectId: nil
        )

        #expect(summary.wasChunked)

        let calls = await provider.callCount
        #expect(calls >= 2, "Expected chunk calls + synthesis call, got \(calls)")

        // Hierarchical reduce may run more than one synthesis pass for a very long
        // document; the contract is that at least one runs and the last call is one.
        let synthCalls = await provider.synthesisCalls
        #expect(synthCalls >= 1, "Expected at least one synthesis pass, got \(synthCalls)")

        let lastReq = await provider.lastRequest
        #expect(lastReq?.isSynthesisPass == true)
    }

    // MARK: - StructuredOutputTest

    @Test("StructuredOutputTest: structured prompt result contains expected field names")
    func structuredPromptStoresJsonResult() async throws {
        let schema = StructuredSummarySchema(fields: [
            .init(name: "Background", description: "Diplomatic context"),
            .init(name: "KeyDecision", description: "Main policy decision"),
        ])
        let jsonResponse = #"{"Background":"Cold War context","KeyDecision":"Escalate response"}"#
        let container = try ModelContainer.makeTestContainer()
        let service = SummarizationService(modelContainer: container)
        let provider = MockSummarizationProvider(responseText: jsonResponse)
        let prompt = makePromptSnapshot(responseFormat: .structured(schema: schema))

        let summary = try await service.summarize(
            documentId: "d4",
            volumeId: "vol4",
            documentText: "Telegram from Ambassador.",
            prompt: prompt,
            provider: provider,
            activeProjectId: nil
        )

        #expect(summary.responseText.contains("Background"))
        #expect(summary.responseText.contains("KeyDecision"))
        if case .structured = summary.responseFormat { } else {
            Issue.record("Expected .structured responseFormat, got \(summary.responseFormat)")
        }
    }

    // MARK: - PersistenceTest

    @Test("PersistenceTest: completed summary is saved to SwiftData with correct fields")
    func summaryPersistedWithCorrectFields() async throws {
        let projectId = UUID()
        let container = try ModelContainer.makeTestContainer()
        let service = SummarizationService(modelContainer: container)
        let provider = MockSummarizationProvider(responseText: "Persisted summary text.")
        let promptId = UUID()
        let prompt = SummarizationPromptSnapshot(
            id: promptId,
            promptText: "Summarize: {{DOCUMENT}}",
            responseFormat: .general
        )

        let returned = try await service.summarize(
            documentId: "d5",
            volumeId: "vol5",
            documentText: "Cabinet meeting minutes.",
            prompt: prompt,
            provider: provider,
            activeProjectId: projectId
        )

        // Fetch from a fresh context to confirm persistence (not just in-memory state)
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<GeneratedSummary>(
            predicate: #Predicate { $0.documentId == "d5" }
        )
        descriptor.fetchLimit = 1
        let fetched = try context.fetch(descriptor)

        #expect(fetched.count == 1)
        let saved = try #require(fetched.first)
        #expect(saved.id == returned.id)
        #expect(saved.documentId == "d5")
        #expect(saved.volumeId == "vol5")
        #expect(saved.responseText == "Persisted summary text.")
        #expect(saved.promptId == promptId)
        #expect(saved.projectId == projectId)
        #expect(!saved.wasChunked)
    }

    // MARK: - GenerateSummaryText (no-persistence path)

    @Test("GenerateSummaryText: returns text WITHOUT persisting a summary (headnote-draft path)")
    func generateSummaryTextDoesNotPersist() async throws {
        let container = try ModelContainer.makeTestContainer()
        let service = SummarizationService(modelContainer: container)
        let provider = MockSummarizationProvider(responseText: "Headnote takeaway.")
        let prompt = makePromptSnapshot()

        let (text, wasChunked) = try await service.generateSummaryText(
            documentText: "A brief diplomatic note.",
            prompt: prompt,
            provider: provider,
            documentId: "d6",
            volumeId: "vol6"
        )

        #expect(text == "Headnote takeaway.")
        #expect(!wasChunked)

        // The whole point of the headnote-draft path: no document summary is written to the
        // store (and so nothing lands in the document's summary carousel or FTS5 index).
        let context = ModelContext(container)
        let fetched = try context.fetch(FetchDescriptor<GeneratedSummary>())
        #expect(fetched.isEmpty, "generateSummaryText must not persist a GeneratedSummary")

        let calls = await provider.callCount
        #expect(calls == 1)
    }

    @Test("GenerateSummaryText: an oversized document is chunked + synthesized, still without persisting")
    func generateSummaryTextChunksWithoutPersisting() async throws {
        let tokenLimit = 100
        let container = try ModelContainer.makeTestContainer()
        let service = SummarizationService(modelContainer: container)
        let provider = MockSummarizationProvider(tokenLimit: tokenLimit, responseText: "Partial.")
        let prompt = makePromptSnapshot()
        let longText = makeOversizedText(tokenLimit: tokenLimit)

        let (_, wasChunked) = try await service.generateSummaryText(
            documentText: longText,
            prompt: prompt,
            provider: provider,
            documentId: "d7",
            volumeId: "vol7"
        )

        #expect(wasChunked, "Oversized text should still chunk on the text-only path")
        let synthCalls = await provider.synthesisCalls
        #expect(synthCalls >= 1, "Expected at least one synthesis pass, got \(synthCalls)")

        let context = ModelContext(container)
        let fetched = try context.fetch(FetchDescriptor<GeneratedSummary>())
        #expect(fetched.isEmpty, "The chunked text-only path must not persist a GeneratedSummary")
    }

    @Test("GenerateSummaryText: empty document text throws emptyDocumentText")
    func generateSummaryTextEmptyThrows() async throws {
        let container = try ModelContainer.makeTestContainer()
        let service = SummarizationService(modelContainer: container)
        let provider = MockSummarizationProvider()

        await #expect(throws: SummarizationError.emptyDocumentText) {
            _ = try await service.generateSummaryText(
                documentText: "   \n ",
                prompt: makePromptSnapshot(),
                provider: provider,
                documentId: "d8",
                volumeId: "vol8"
            )
        }
    }

    // MARK: - Context-overflow mitigation

    @Test("DocumentBudget: template tokens and structured overhead shrink the budget")
    func documentBudgetIsTemplateAware() async throws {
        let service = SummarizationService(modelContainer: try ModelContainer.makeTestContainer())
        let limit = 3_072
        let short = await service.documentBudget(
            promptText: "Summarize: {{DOCUMENT}}", responseFormat: .general, limit: limit)
        let longTemplate = "Summarize: {{DOCUMENT}}" + String(repeating: "context ", count: 400)
        let long = await service.documentBudget(
            promptText: longTemplate, responseFormat: .general, limit: limit)
        // A longer template leaves less room for content.
        #expect(long < short)
        #expect(short <= limit)
        // Structured prompts reserve extra for the runtime schema.
        let schema = StructuredSummarySchema(fields: [.init(name: "A", description: "x")])
        let structured = await service.documentBudget(
            promptText: "Summarize: {{DOCUMENT}}", responseFormat: .structured(schema: schema), limit: limit)
        #expect(structured < short)
    }

    @Test("Chunking: an oversized unbroken block is hard-split so no chunk exceeds the budget")
    func oversizedBlockIsHardSplit() async throws {
        let service = SummarizationService(modelContainer: try ModelContainer.makeTestContainer())
        // ~2 750 tokens, a single "paragraph" with no sentence boundaries.
        let block = String(repeating: "diplomatic ", count: 1_000)
        let budget = 200
        let chunks = await service.chunk(text: block, maxTokens: budget)
        #expect(chunks.count > 1)
        for piece in chunks {
            #expect(await service.estimateTokens(piece) <= budget)
        }
    }

    @Test("Batching: every batch fits the budget and an oversized summary is capped")
    func batchingFitsBudget() async throws {
        let service = SummarizationService(modelContainer: try ModelContainer.makeTestContainer())
        let big = String(repeating: "x", count: 4_000)   // ~1 000 tokens
        let budget = 200
        let batches = await service.batch([big, big, "tiny", "tiny"], maxTokens: budget)
        for group in batches {
            #expect(await service.estimateTokens(group.joined(separator: "\n\n")) <= budget)
        }
    }

    @Test("Long document with many chunks: hierarchical reduce terminates with a non-empty summary")
    func hierarchicalReduceTerminates() async throws {
        let container = try ModelContainer.makeTestContainer()
        let service = SummarizationService(modelContainer: container)
        // Small window + non-trivial partials → many chunks whose synthesis would
        // overflow a single pass; the reduce must batch and still return.
        let provider = MockSummarizationProvider(tokenLimit: 80, responseText: "Concise partial summary text.")
        let prompt = makePromptSnapshot()

        let summary = try await service.summarize(
            documentId: "dLong",
            volumeId: "volLong",
            documentText: makeOversizedText(tokenLimit: 80),
            prompt: prompt,
            provider: provider,
            activeProjectId: nil
        )

        #expect(summary.wasChunked)
        #expect(!summary.responseText.isEmpty)
        let synthCalls = await provider.synthesisCalls
        #expect(synthCalls >= 1)
    }

    // MARK: - Synthesis prompt (2026-10-31)

    /// Drives the real reduce through the mock and reads what each call was given: the map calls
    /// run the reader's prompt as it stands, and the synthesis call runs it wrapped, under the same
    /// prompt id and response format, over the partials labelled 1 to n in order.
    @Test("Synthesis wraps the reader's prompt and labels each partial with its part, in order")
    func synthesisWrapsPromptAndLabelsParts() async throws {
        let schema = StructuredSummarySchema(fields: [.init(name: "Parties", description: "Who")])
        for format in [ResponseFormat.general, .structured(schema: schema)] {
            let service = SummarizationService(modelContainer: try ModelContainer.makeTestContainer())
            let provider = MockSummarizationProvider(tokenLimit: 512, responseText: "Partial.")
            let prompt = makePromptSnapshot(responseFormat: format)

            _ = try await service.generateSummaryText(
                documentText: makeOversizedText(tokenLimit: 512),
                prompt: prompt,
                provider: provider,
                documentId: "d475",
                volumeId: "frus1946v06"
            )

            let calls = await provider.calls
            let map = calls.filter { !$0.request.isSynthesisPass }
            let synthesis = calls.filter { $0.request.isSynthesisPass }
            let n = map.count
            try #require(n > 1, "the fixture must chunk, or this asserts nothing")
            try #require(synthesis.count == 1, "these partials fit one synthesis call")

            #expect(map.allSatisfy { $0.prompt.promptText == prompt.promptText },
                    "the map pass runs the reader's prompt unchanged")
            let call = synthesis[0]
            #expect(call.prompt.promptText == SummarizationService.synthesisPromptText(
                wrapping: prompt.promptText, firstPart: 1, lastPart: n, partCount: n))
            #expect(call.prompt.id == prompt.id)
            #expect(call.prompt.responseFormat == format)
            #expect(call.request.chunks == (1...n).map { "Summary of part \($0) of \(n):\nPartial." })
        }
    }

    /// The wrapper's wording is the wording measured on 2026-10-31 (see
    /// `SummarizationService.synthesisPromptText`). This pin is the reminder that a change to it is a
    /// change the measurement no longer covers: re-measure, then bring the pin to the new text.
    @Test("Synthesis prompt: the measured wording, with the reader's request and one placeholder")
    func synthesisPromptWording() {
        let text = SummarizationService.synthesisPromptText(
            wrapping: "Summarize the following document in two to four sentences.\n\n{{DOCUMENT}}\n",
            firstPart: 1, lastPart: 5, partCount: 5)
        #expect(text == """
            Below are summaries of parts 1 to 5, in order, of one long document that was read in 5 \
            consecutive parts. Read them as one document, then carry out this request for all of it. \
            Answer once, at the length the request asks for: combine the parts into the main line of \
            the document from beginning to end, rather than going through them one by one or listing \
            every detail, and keep the names the summaries give.

            Summarize the following document in two to four sentences.

            {{DOCUMENT}}
            """)
        #expect(text.components(separatedBy: "{{DOCUMENT}}").count == 2,
                "one placeholder: the reader's own is removed")

        #expect(SummarizationService.synthesisLabel(firstPart: 3, lastPart: 3, partCount: 5)
                == "Summary of part 3 of 5:")
        #expect(SummarizationService.synthesisLabel(firstPart: 1, lastPart: 6, partCount: 18)
                == "Summary of part 1–6 of 18:")
    }

    /// A hierarchical reduce labels an intermediate summary with the span of parts it stands for,
    /// and names that span in its own call's wrapper; the final call's spans run from part 1 to the
    /// last without a gap.
    @Test("Synthesis: a hierarchical reduce carries each summary's span of parts to the next level")
    func hierarchicalReduceCarriesSpans() async throws {
        let service = SummarizationService(modelContainer: try ModelContainer.makeTestContainer())
        let provider = MockSummarizationProvider(tokenLimit: 80, responseText: "Concise partial summary text.")
        let prompt = makePromptSnapshot()

        _ = try await service.generateSummaryText(
            documentText: makeOversizedText(tokenLimit: 80),
            prompt: prompt,
            provider: provider,
            documentId: "dLong",
            volumeId: "volLong"
        )

        let calls = await provider.calls
        let n = calls.filter { !$0.request.isSynthesisPass }.count
        let synthesis = calls.filter { $0.request.isSynthesisPass }
        try #require(synthesis.count > 1, "the fixture must need a reduce level, or this asserts nothing")

        func spans(_ chunks: [String]) -> [(Int, Int)] {
            chunks.compactMap { chunk in
                let label = chunk.prefix { $0 != "\n" }
                guard let match = label.wholeMatch(of: /Summary of part (\d+)(?:–(\d+))? of (\d+):/),
                      let first = Int(match.1), Int(match.3) == n else { return nil }
                return (first, match.2.flatMap { Int($0) } ?? first)
            }
        }
        for call in synthesis {
            let s = spans(call.request.chunks)
            try #require(s.count == call.request.chunks.count, "every summary is labelled with its part")
            #expect(zip(s, s.dropFirst()).allSatisfy { $0.1 + 1 == $1.0 }, "spans are contiguous")
            #expect(call.prompt.promptText == SummarizationService.synthesisPromptText(
                wrapping: prompt.promptText, firstPart: s[0].0, lastPart: s[s.count - 1].1, partCount: n))
        }
        let last = spans(synthesis[synthesis.count - 1].request.chunks)
        #expect(last.first?.0 == 1 && last.last?.1 == n, "the final call covers every part")
    }

    /// The wrapper is longer than the reader's prompt, so it is counted against the synthesis budget.
    /// The fixture's five partials are sized to fit the reader's prompt's budget and not the wrapped
    /// prompt's: counted, they take a reduce level; not counted, one call over the window's limit.
    @Test("Synthesis: the wrapper is counted, so every synthesis call fits the window")
    func synthesisBudgetCountsTheWrapper() async throws {
        let limit = 3_072
        let service = SummarizationService(modelContainer: try ModelContainer.makeTestContainer())
        let prompt = makePromptSnapshot()
        let mapBudget = await service.documentBudget(
            promptText: prompt.promptText, responseFormat: .general, limit: limit)
        let wrappedBudget = await service.documentBudget(
            promptText: SummarizationService.synthesisPromptText(
                wrapping: prompt.promptText, firstPart: 1, lastPart: 5, partCount: 5),
            responseFormat: .general, limit: limit)
        try #require(wrappedBudget + 40 < mapBudget, "the wrapper must cost the budget something")

        // Five paragraphs, each nearly a whole map budget, so each is its own chunk.
        let paragraph = String(repeating: "x", count: (mapBudget - 10) * 4)
        let document = Array(repeating: paragraph, count: 5).joined(separator: "\n\n")
        // Partials whose five labelled entries, joined, fall midway between the two budgets.
        let label = SummarizationService.synthesisLabel(firstPart: 1, lastPart: 1, partCount: 5) + "\n"
        let entryChars = ((wrappedBudget + mapBudget) / 2 * 4 - 4 * 2) / 5
        let provider = MockSummarizationProvider(
            tokenLimit: limit, responseText: String(repeating: "y", count: entryChars - label.count))

        _ = try await service.generateSummaryText(
            documentText: document, prompt: prompt, provider: provider,
            documentId: "d1", volumeId: "vol1")

        let calls = await provider.calls
        try #require(calls.filter { !$0.request.isSynthesisPass }.count == 5)
        let synthesis = calls.filter { $0.request.isSynthesisPass }
        #expect(synthesis.count > 1, "five such partials need a reduce level once the wrapper is counted")
        for call in synthesis {
            let filled = call.prompt.promptText
                .replacingOccurrences(of: "{{DOCUMENT}}", with: call.request.chunks.joined(separator: "\n\n"))
            // The window less its safety margin; 2 for the estimate's rounding and a span's digits.
            #expect(await service.estimateTokens(filled) <= limit - limit / 6 + 2)
        }
    }

    // MARK: - Token estimate (2026-10-31)

    @Test("Estimate: a letter or space costs a quarter of a token, a digit one, a punctuation mark half")
    func estimateWeighsDigitsAndPunctuation() async throws {
        let service = SummarizationService(modelContainer: try ModelContainer.makeTestContainer())
        #expect(await service.estimateTokens("abcd") == 1)
        #expect(await service.estimateTokens("diplomatic note") == 4)    // 15 characters, as ⌈15 ÷ 4⌉
        #expect(await service.estimateTokens("1234") == 4)
        #expect(await service.estimateTokens(",;.:") == 2)
        #expect(await service.estimateTokens("$507 50") == 6)            // 5 digits and 2 others: 5.5
    }

    /// A claims schedule printed as running text, the form that broke `⌈characters ÷ 4⌉`: by its
    /// characters it fits one call at the 3,072 limit, and by its digits, which the model counts about a
    /// token each, it does not. The old estimate sent it whole, a prompt over a 4,096-token window.
    @Test("A number table is chunked by what its digits cost, so each chunk's estimate fits the budget")
    func numberTableIsChunkedByItsDigits() async throws {
        let service = SummarizationService(modelContainer: try ModelContainer.makeTestContainer())
        let row = "No. 561. Leo Tsock Yen, 989 50; 627. Leo Seh Tim, 123 75; 562. Leo Yew Lung, 1,821 10. "
        let table = String(repeating: row, count: 100)
        let prompt = makePromptSnapshot()
        let budget = await service.documentBudget(
            promptText: prompt.promptText, responseFormat: .general, limit: 3_072)
        try #require(table.count / 4 < budget, "by characters ÷ 4 the table is one call")

        let provider = MockSummarizationProvider(tokenLimit: 3_072, responseText: "Claims.")
        let result = try await service.generateSummaryText(
            documentText: table, prompt: prompt, provider: provider, documentId: "d65", volumeId: "frus1886")
        #expect(result.wasChunked)
        for call in await provider.calls where !call.request.isSynthesisPass {
            #expect(await service.estimateTokens(call.request.chunks.joined(separator: "\n\n")) <= budget)
        }
    }

    @Test("Hard split: a run of digits is cut shorter than prose, and every piece fits the budget")
    func hardSplitCutsByTheEstimate() async throws {
        let service = SummarizationService(modelContainer: try ModelContainer.makeTestContainer())
        let digits = await service.hardSplit(String(repeating: "7", count: 1_000), maxTokens: 100)
        let prose = await service.hardSplit(String(repeating: "x", count: 1_000), maxTokens: 100)
        #expect(digits.map(\.count) == Array(repeating: 100, count: 10))
        #expect(prose.map(\.count) == [400, 400, 200])
        let capped = await service.prefix(of: String(repeating: "1,", count: 500), fittingTokens: 30)
        #expect(await service.estimateTokens(capped) <= 30)
        #expect(capped.count == 40)
    }
}

// MARK: - Apple Intelligence's prompt budget (2026-10-31)

/// Three quarters of the window the model states, from 3,072 to 6,144: the rule the owner chose on
/// 2026-10-31 after the budget comparison in `Planning/DEVELOPMENT-PLAN.md`.
struct AppleIntelligenceTokenLimitTests {

    @Test("The budget is three quarters of an 8,192- or 4,096-token window")
    func threeQuartersOfTheWindow() {
        #expect(AppleIntelligenceProvider.tokenLimit(forContextSize: 8_192) == 6_144)
        #expect(AppleIntelligenceProvider.tokenLimit(forContextSize: 4_096) == 3_072)
        #expect(AppleIntelligenceProvider.tokenLimit(forContextSize: 6_000) == 4_500)
    }

    /// A command-line tool spawned in the iOS 27.0 simulator read a window of 0, and still answered a
    /// prompt of 7,414 tokens; a window larger than 8,192 has not been measured.
    @Test("A window stated as 0 or under 4,096 keeps 3,072, and one over 8,192 is held to 6,144")
    func theBudgetIsBounded() {
        #expect(AppleIntelligenceProvider.tokenLimit(forContextSize: 0) == 3_072)
        #expect(AppleIntelligenceProvider.tokenLimit(forContextSize: 2_048) == 3_072)
        #expect(AppleIntelligenceProvider.tokenLimit(forContextSize: 16_384) == 6_144)
    }

    @Test("The live provider's budget is the one its model's window gives")
    func theLiveProviderReadsItsModel() async {
        let expected = AppleIntelligenceProvider.tokenLimit(
            forContextSize: AppleIntelligenceProvider.model.contextSize)
        #expect(await AppleIntelligenceProvider.shared.contextWindowTokenLimit == expected)
    }
}

// MARK: - An answer past the window (2026-11-01)

/// A provider whose answers to the calls it is told run past the model's window, as
/// `AppleIntelligenceProvider` reports one: `SummarizationError.answerOverranWindow`.
private actor OverrunningProvider: SummarizationProvider {

    var isAvailable: Bool { true }
    let contextWindowTokenLimit: Int
    /// The calls, counted from 1, whose answer runs past the window.
    let overrunningCalls: Set<Int>
    /// Every call's request, in call order.
    private(set) var requests: [SummarizationRequest] = []

    init(tokenLimit: Int, overrunningCalls: Set<Int>) {
        self.contextWindowTokenLimit = tokenLimit
        self.overrunningCalls = overrunningCalls
    }

    func summarize(
        request: SummarizationRequest,
        prompt: SummarizationPromptSnapshot
    ) async throws -> SummarizationResult {
        requests.append(request)
        if overrunningCalls.contains(requests.count) { throw SummarizationError.answerOverranWindow }
        return SummarizationResult(text: "Partial.", responseFormat: prompt.responseFormat, wasChunked: false)
    }
}

/// The owner's decision of 2026-11-01: a call whose answer ran past the model's window is made once
/// more, and a second overrun fails the summary with a sentence of its own. Measured, the one answer of
/// 644 calls that ran past the window came after 119 s of a run that was then lost; asked again five
/// times, it fitted every time.
struct SummarizationAnswerOverrunTests {

    /// The prompt budget these tests run at, which makes each paragraph of ``threeParts`` a call.
    private let tokenLimit = 100

    /// Three paragraphs of 60 estimated tokens each, each opening with its own word so their calls can
    /// be told apart: a 75-token budget takes one at a time, so the document is three map calls and one
    /// synthesis.
    private var threeParts: String {
        ["alpha", "bravo", "delta"].map { $0 + " " + String(repeating: "word ", count: 47) }
            .joined(separator: "\n\n")
    }

    @Test("An answer that ran past the window is asked for once more, and the run goes on")
    func oneOverrunCostsOneCall() async throws {
        let service = SummarizationService(modelContainer: try ModelContainer.makeTestContainer())
        let prompt = makePromptSnapshot()
        #expect(await service.documentBudget(promptText: prompt.promptText, responseFormat: .general,
                                             limit: tokenLimit) == 75)
        try #require(await service.chunk(text: threeParts, maxTokens: 75).count == 3)

        let provider = OverrunningProvider(tokenLimit: tokenLimit, overrunningCalls: [2])
        let result = try await service.generateSummaryText(
            documentText: threeParts, prompt: prompt, provider: provider, documentId: "d1", volumeId: "v")
        #expect(result.text == "Partial.")
        #expect(result.wasChunked)

        // Map 1, map 2 overrunning, map 2 again, map 3, the synthesis: the first part is not repeated.
        let requests = await provider.requests
        try #require(requests.count == 5)
        #expect(requests[1].chunks == requests[2].chunks)
        #expect(requests[0].chunks != requests[1].chunks)
        #expect(requests.map(\.isSynthesisPass) == [false, false, false, false, true])
    }

    @Test("A second overrun of the same call fails the summary, and nothing after it is asked")
    func aSecondOverrunFails() async throws {
        let service = SummarizationService(modelContainer: try ModelContainer.makeTestContainer())
        let provider = OverrunningProvider(tokenLimit: tokenLimit, overrunningCalls: [2, 3])
        await #expect(throws: SummarizationError.answerOverranWindow) {
            _ = try await service.generateSummaryText(
                documentText: threeParts, prompt: makePromptSnapshot(), provider: provider,
                documentId: "d1", volumeId: "v")
        }
        let requests = await provider.requests
        try #require(requests.count == 3)
        #expect(requests[1].chunks == requests[2].chunks)
        // The background run does not repeat the document for it: the call was already made twice.
        #expect(!SummarizationRetryPolicy.isRetryable(SummarizationError.answerOverranWindow))
    }

    @Test("The synthesis is asked once more too, and a second overrun reads as the same sentence")
    func theSynthesisIsRetried() async throws {
        let service = SummarizationService(modelContainer: try ModelContainer.makeTestContainer())
        let once = OverrunningProvider(tokenLimit: tokenLimit, overrunningCalls: [4])
        let result = try await service.generateSummaryText(
            documentText: threeParts, prompt: makePromptSnapshot(), provider: once, documentId: "d1", volumeId: "v")
        #expect(result.text == "Partial.")
        let requests = await once.requests
        try #require(requests.map(\.isSynthesisPass) == [false, false, false, true, true])
        #expect(requests[3].chunks == requests[4].chunks)

        let twice = OverrunningProvider(tokenLimit: tokenLimit, overrunningCalls: [4, 5])
        do {
            _ = try await service.generateSummaryText(
                documentText: threeParts, prompt: makePromptSnapshot(), provider: twice, documentId: "d1", volumeId: "v")
            Issue.record("a second overrun of the synthesis did not fail the summary")
        } catch {
            // `==` on `synthesisFailed` ignores what it wraps, so the wrapped error is read.
            let wrapped = try #require(error as? SummarizationError)
            guard case .synthesisFailed(let underlying) = wrapped else {
                Issue.record("expected synthesisFailed, got \(wrapped)")
                return
            }
            #expect(underlying as? SummarizationError == .answerOverranWindow)
            #expect(wrapped.errorDescription == SummarizationError.answerOverranWindow.errorDescription)
            #expect(!SummarizationRetryPolicy.isRetryable(wrapped))
        }
        #expect(await twice.requests.count == 5)
    }

    @Test("A document of one call is asked once more, and is not chunked for it")
    func aSingleCallIsRetried() async throws {
        let service = SummarizationService(modelContainer: try ModelContainer.makeTestContainer())
        let provider = OverrunningProvider(tokenLimit: 3_072, overrunningCalls: [1])
        let result = try await service.generateSummaryText(
            documentText: "A short telegram.", prompt: makePromptSnapshot(), provider: provider,
            documentId: "d1", volumeId: "v")
        #expect(result.text == "Partial.")
        #expect(!result.wasChunked)
        #expect(await provider.requests.count == 2)
    }
}

// MARK: - An answer that copies the document (2026-11-01)

/// A provider that answers every part with `partAnswer` and every synthesis with `synthesisAnswer`.
private actor PartsAndSynthesisProvider: SummarizationProvider {

    var isAvailable: Bool { true }
    let contextWindowTokenLimit: Int
    let partAnswer: String
    let synthesisAnswer: String
    /// Every call's request, in call order.
    private(set) var requests: [SummarizationRequest] = []

    init(tokenLimit: Int, partAnswer: String, synthesisAnswer: String) {
        self.contextWindowTokenLimit = tokenLimit
        self.partAnswer = partAnswer
        self.synthesisAnswer = synthesisAnswer
    }

    func summarize(
        request: SummarizationRequest,
        prompt: SummarizationPromptSnapshot
    ) async throws -> SummarizationResult {
        requests.append(request)
        return SummarizationResult(text: request.isSynthesisPass ? synthesisAnswer : partAnswer,
                                   responseFormat: prompt.responseFormat, wasChunked: false)
    }
}

/// The owner's decision of 2026-11-01: under a built-in template, an answer to a part of the document
/// loses what it copied of that part word for word. A plain answer loses each paragraph at least half
/// of whose ten-word runs the part holds; a structured answer, each field of 200 copied words or more
/// at that share. Measured, the copies were transcripts' speaker turns, pasted after the model's own
/// paragraph or filling a Meeting Record's Key Participants (``CopiedPassages``).
struct CopiedPassageTests {

    /// Four speaker turns of a meeting.
    private let transcript = """
        Rusk: We have to decide tonight whether the message goes to Havana before the President speaks.

        McNamara: The air strike cannot be ready before Saturday morning, and the blockade needs the fleet in position first.

        Bundy: If we send word to Castro we lose surprise, and the missiles may be operational by the time he answers.

        Martin: We will give him a day to respond, and we will keep close surveillance of every site meanwhile.
        """

    /// The model's own paragraph about ``transcript``, which shares no run with it.
    private let own = "The meeting weighs warning Castro before acting against the Soviet missiles, and settles on a "
        + "deadline of one day while reconnaissance of the sites goes on."

    /// The last three turns of ``transcript``, word for word, as the model pastes them.
    private var pasted: String { transcript.components(separatedBy: "\n\n").dropFirst().joined(separator: "\n\n") }

    /// Twenty-one turns of fourteen words, each turn naming its own question.
    private var longTranscript: String {
        let speakers = ["Rusk", "McNamara", "Bundy", "Taylor"]
        let questions = ["first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth",
                         "tenth", "eleventh", "twelfth", "thirteenth", "fourteenth", "fifteenth", "sixteenth",
                         "seventeenth", "eighteenth", "nineteenth", "twentieth", "last"]
        return questions.enumerated().map { index, question in
            "\(speakers[index % speakers.count]): On the \(question) question the department holds that the reply must wait."
        }.joined(separator: "\n\n")
    }

    /// A built-in template, Standard Summary or Meeting Record, as the prompt the service is handed.
    private func builtIn(meeting: Bool) throws -> SummarizationPromptSnapshot {
        let template = try #require(SummarizationPromptSeeder.standardTemplates.first {
            meeting ? $0.fields.contains { $0.name == "KeyParticipants" } : $0.fields.isEmpty
        })
        return SummarizationPromptSnapshot(id: UUID(), promptText: template.promptText,
                                           responseFormat: template.responseFormat)
    }

    /// The summary of `document` when every call is answered `answer`, and the provider that answered.
    private func summary(
        of document: String,
        answer: String,
        prompt: SummarizationPromptSnapshot
    ) async throws -> (text: String, provider: MockSummarizationProvider) {
        let service = SummarizationService(modelContainer: try ModelContainer.makeTestContainer())
        let provider = MockSummarizationProvider(responseText: answer)
        let result = try await service.generateSummaryText(
            documentText: document, prompt: prompt, provider: provider, documentId: "d21", volumeId: "frus1961-63v11")
        return (result.text, provider)
    }

    @Test("A run is ten words in a row, a text's words its letters and digits, lowercased")
    func theMeasure() {
        #expect(CopiedPassages.words(in: "Rusk: We’ve—uh, DECIDED 24 hours.") == ["rusk", "we", "ve", "uh", "decided", "24", "hours"])
        let held = CopiedPassages.runs(in: transcript)
        let copy = CopiedPassages.measure(pasted, against: held)
        #expect(copy.share == 1)
        #expect(copy.copiedWords == copy.words)
        let mine = CopiedPassages.measure(own, against: held)
        #expect(mine.share == 0 && mine.copiedWords == 0)
        // Under ten words there is no run, so nothing in it counts as copied.
        let short = CopiedPassages.measure("Rusk: We have to decide tonight.", against: held)
        #expect(short == .init(words: 6, copiedWords: 0, share: 0))
    }

    @Test("Every built-in template is checked, and no other prompt")
    func whichPromptsAreChecked() throws {
        for template in SummarizationPromptSeeder.standardTemplates {
            let prompt = SummarizationPromptSnapshot(id: UUID(), promptText: template.promptText,
                                                     responseFormat: template.responseFormat)
            #expect(CopiedPassages.applies(to: prompt), "\(template.name)")
        }
        let meeting = try builtIn(meeting: true)
        #expect(!CopiedPassages.applies(to: SummarizationPromptSnapshot(
            id: UUID(), promptText: meeting.promptText, responseFormat: .general)))
        #expect(!CopiedPassages.applies(to: makePromptSnapshot()))
    }

    @Test("A Standard answer loses the turns it pasted after its own paragraph")
    func aStandardAnswerLosesItsPaste() async throws {
        let (text, provider) = try await summary(of: transcript, answer: own + "\n\n" + pasted,
                                                 prompt: try builtIn(meeting: false))
        #expect(text == own)
        #expect(await provider.callCount == 1)
    }

    /// A reader's own prompt may ask for a quotation, and was not measured.
    @Test("A reader's own prompt, or a template edited, keeps what its answer copied")
    func aReadersPromptKeepsItsQuotation() async throws {
        let answer = own + "\n\n" + pasted
        #expect(try await summary(of: transcript, answer: answer, prompt: makePromptSnapshot()).text == answer)
        let template = try builtIn(meeting: false)
        let edited = SummarizationPromptSnapshot(
            id: UUID(), promptText: template.promptText + "\nQuote the passage that decides it.", responseFormat: .general)
        #expect(try await summary(of: transcript, answer: answer, prompt: edited).text == answer)
    }

    @Test("A paragraph that quotes a little of the part stays, and an answer that is all copy is kept whole")
    func whatStays() async throws {
        let prompt = try builtIn(meeting: false)
        // Two turns quoted in a paragraph of the model's own: a share above the most a measured Standard
        // paragraph reached (0.43), and under the rule's.
        let quoting = "The meeting weighs warning Castro before acting against the Soviet missiles. McNamara put it "
            + "plainly: the air strike cannot be ready before Saturday morning, and the blockade needs the fleet in "
            + "position first. Bundy added that if we send word to Castro we lose surprise, and the missiles may be "
            + "operational by the time he answers."
        let share = CopiedPassages.measure(quoting, against: CopiedPassages.runs(in: transcript)).share
        try #require(share > 0.43 && share < CopiedPassages.paragraphShare)
        // After a paragraph of the model's own, so dropping it would not leave the answer empty.
        let answer = own + "\n\n" + quoting
        #expect(try await summary(of: transcript, answer: answer, prompt: prompt).text == answer)
        #expect(try await summary(of: transcript, answer: pasted, prompt: prompt).text == pasted)
    }

    @Test("A Meeting Record field of 200 copied words or more is emptied, and its other fields stay")
    func aCopiedFieldIsEmptied() async throws {
        let prompt = try builtIn(meeting: true)
        guard case .structured(let schema) = prompt.responseFormat else {
            Issue.record("the Meeting Record template is not structured")
            return
        }
        let turns = longTranscript.components(separatedBy: "\n\n")
        let held = CopiedPassages.runs(in: longTranscript)
        var values = ["KeyParticipants": turns.prefix(16).joined(separator: " "), "Topics": own,
                      "Agreements": "A deadline of one day.", "Disagreements": "Whether to warn Castro at all."]
        try #require(CopiedPassages.measure(values["KeyParticipants"] ?? "", against: held).copiedWords >= CopiedPassages.fieldWords)

        let text = try await summary(of: longTranscript, answer: StructuredSectionAnswer.jsonString(values, schema: schema),
                                     prompt: prompt).text
        values["KeyParticipants"] = ""
        #expect(text == StructuredSectionAnswer.jsonString(values, schema: schema))
        #expect(StructuredSummaryDisplay.plainText(responseText: text, format: prompt.responseFormat)
                    .hasPrefix("Key Participants:\n\nTopics: " + own))

        // A participants list the document prints, copied whole but short, stays.
        values["KeyParticipants"] = turns.prefix(8).joined(separator: " ")
        let short = CopiedPassages.measure(values["KeyParticipants"] ?? "", against: held)
        try #require(short.share == 1 && short.copiedWords < CopiedPassages.fieldWords)
        let listed = StructuredSectionAnswer.jsonString(values, schema: schema)
        #expect(try await summary(of: longTranscript, answer: listed, prompt: prompt).text == listed)
    }

    @Test("Each part's answer is measured against that part, and the synthesis is left as it is")
    func eachPartAgainstItsOwnText() async throws {
        let prompt = try builtIn(meeting: false)
        let service = SummarizationService(modelContainer: try ModelContainer.makeTestContainer())
        let tokenLimit = 3_072
        let budget = await service.documentBudget(promptText: prompt.promptText, responseFormat: .general,
                                                  limit: tokenLimit)
        // Three paragraphs of over half the budget each, so each is a part of its own. Each phrase is
        // eight words, so every run of a part holds that part's marker.
        var parts: [String] = []
        for marker in ["alpha", "bravo", "delta"] {
            let phrase = "\(marker) told the committee the reply must wait. "
            let perPhrase = await service.estimateTokens(phrase)
            let repeats = budget * 3 / 5 / perPhrase
            parts.append(String(repeating: phrase, count: repeats).trimmingCharacters(in: .whitespaces))
        }
        let document = parts.joined(separator: "\n\n")
        try #require(await service.chunk(text: document, maxTokens: budget).count == 3)

        let copied = String(repeating: "alpha told the committee the reply must wait. ", count: 3)
            .trimmingCharacters(in: .whitespaces)
        let answer = own + "\n\n" + copied
        // A paragraph of its own, then the parts' words: checked like a part's, it would lose the second.
        let combinedAnswer = "Across its three parts the record has the committee waiting on the reply.\n\n" + copied
        let provider = PartsAndSynthesisProvider(tokenLimit: tokenLimit, partAnswer: answer,
                                                 synthesisAnswer: combinedAnswer)
        let result = try await service.generateSummaryText(
            documentText: document, prompt: prompt, provider: provider, documentId: "d1", volumeId: "v")
        #expect(result.text == combinedAnswer)

        let requests = await provider.requests
        try #require(requests.map(\.isSynthesisPass) == [false, false, false, true])
        let combined = requests[3].chunks
        try #require(combined.count == 3)
        // The first part's answer lost its copy of the first part; the others hold none of theirs.
        #expect(combined[0].hasSuffix("\n" + own))
        #expect(combined[1].hasSuffix("\n" + answer))
        #expect(combined[2].hasSuffix("\n" + answer))
    }
}
