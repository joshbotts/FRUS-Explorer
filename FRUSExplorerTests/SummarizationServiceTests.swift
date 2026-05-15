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

        let synthCalls = await provider.synthesisCalls
        #expect(synthCalls == 1, "Expected exactly one synthesis pass, got \(synthCalls)")

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
}
