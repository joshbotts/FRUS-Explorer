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
}
