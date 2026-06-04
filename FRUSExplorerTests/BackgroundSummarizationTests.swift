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

// MARK: - Fixture Helpers

private func makeManifestEntry(
    volumeId: String,
    subseries: String = "1969-76",
    earliest: String? = "1969-01-01",
    latest: String? = "1976-12-31"
) -> VolumeManifestEntry {
    VolumeManifestEntry(
        volumeId: volumeId,
        filename: "\(volumeId).xml",
        subseries: subseries,
        title: "Volume \(volumeId)",
        dateRange: DateRange(earliest: earliest, latest: latest),
        publicationDate: "2000",
        status: .published,
        editors: [],
        generalEditor: nil,
        documentCount: 0,
        sizeBytes: 0,
        tags: []
    )
}

private func makeService(container: ModelContainer) async -> BackgroundSummarizationService {
    let summarizationService = SummarizationService(modelContainer: container)
    let progress = await BackgroundSummarizationProgress()
    return BackgroundSummarizationService(
        summarizationService: summarizationService,
        modelContainer: container,
        progress: progress
    )
}

// MARK: - BackgroundSummarizationTests

struct BackgroundSummarizationTests {

    // MARK: - ScopeResolutionTest

    @Test("ScopeResolutionTest: volume scope resolves to correct single volumeId")
    func scopeResolutionVolume() async throws {
        let container = try ModelContainer.makeTestContainer()
        let service = await makeService(container: container)

        let entries = [
            makeManifestEntry(volumeId: "vol1", subseries: "1969-76"),
            makeManifestEntry(volumeId: "vol2", subseries: "1969-76"),
            makeManifestEntry(volumeId: "vol3", subseries: "1977-80"),
        ]
        let downloaded: Set<String> = ["vol1", "vol2", "vol3"]

        let resolved = await service.resolvedVolumeIds(
            for: .volume(volumeId: "vol1"),
            in: entries,
            downloadedVolumeIds: downloaded
        )
        #expect(resolved == ["vol1"])
    }

    @Test("ScopeResolutionTest: subseries scope returns only downloaded volumes in that subseries")
    func scopeResolutionSubseries() async throws {
        let container = try ModelContainer.makeTestContainer()
        let service = await makeService(container: container)

        let entries = [
            makeManifestEntry(volumeId: "vol1", subseries: "1969-76"),
            makeManifestEntry(volumeId: "vol2", subseries: "1969-76"),
            makeManifestEntry(volumeId: "vol3", subseries: "1977-80"),
        ]
        // vol3 is not downloaded
        let downloaded: Set<String> = ["vol1", "vol2"]

        let resolved = await service.resolvedVolumeIds(
            for: .subseries(subseries: "1969-76"),
            in: entries,
            downloadedVolumeIds: downloaded
        )
        #expect(Set(resolved) == Set(["vol1", "vol2"]))
        #expect(!resolved.contains("vol3"))
    }

    @Test("ScopeResolutionTest: dateRange scope returns volumes whose range overlaps")
    func scopeResolutionDateRange() async throws {
        let container = try ModelContainer.makeTestContainer()
        let service = await makeService(container: container)

        let entries = [
            makeManifestEntry(volumeId: "vol1", earliest: "1969-01-01", latest: "1972-12-31"),
            makeManifestEntry(volumeId: "vol2", earliest: "1973-01-01", latest: "1976-12-31"),
            makeManifestEntry(volumeId: "vol3", earliest: "1980-01-01", latest: "1984-12-31"),
        ]
        let downloaded: Set<String> = ["vol1", "vol2", "vol3"]

        // Scope covers 1969–1973, should include vol1 and vol2 but not vol3
        let resolved = await service.resolvedVolumeIds(
            for: .dateRange(earliest: "1969-01-01", latest: "1973-06-01"),
            in: entries,
            downloadedVolumeIds: downloaded
        )
        #expect(Set(resolved) == Set(["vol1", "vol2"]))
        #expect(!resolved.contains("vol3"))
    }

    // MARK: - SkipExistingTest

    @Test("SkipExistingTest: shouldSkip returns true when summary exists for document + prompt")
    func skipExistingReturnsTrueWhenSummaryExists() async throws {
        let container = try ModelContainer.makeTestContainer()
        let service = await makeService(container: container)
        let context = ModelContext(container)

        let promptId = UUID()
        let summary = GeneratedSummary(
            documentId: "d1",
            volumeId: "vol1",
            promptId: promptId,
            responseText: "Existing summary.",
            wasChunked: false
        )
        context.insert(summary)
        try context.save()

        let shouldSkip = await service.shouldSkip(
            volumeId: "vol1",
            documentId: "d1",
            promptId: promptId,
            context: context
        )
        #expect(shouldSkip == true)
    }

    @Test("SkipExistingTest: shouldSkip returns false when no summary exists")
    func skipExistingReturnsFalseWhenNoSummaryExists() async throws {
        let container = try ModelContainer.makeTestContainer()
        let service = await makeService(container: container)
        let context = ModelContext(container)

        let shouldSkip = await service.shouldSkip(
            volumeId: "vol1",
            documentId: "d99",
            promptId: UUID(),
            context: context
        )
        #expect(shouldSkip == false)
    }

    // MARK: - RateLimitRetryTest

    @Test("RateLimitRetryTest: withRetry calls operation up to maxAttempts; succeeds when operation eventually succeeds")
    func rateLimitRetryEventuallySucceeds() async throws {
        let container = try ModelContainer.makeTestContainer()
        let service = await makeService(container: container)

        let provider = RetryTestProvider(failCount: 2, successText: "Retried summary.")

        // withRetry is internal — call it directly with a zero-delay override (maxAttempts only)
        // We override with maxAttempts=3 (2 failures + 1 success) and a 0-ns base delay
        // by passing a custom operation that delegates to the provider.
        let result: SummarizationResult = try await service.withRetry(
            maxAttempts: 3,
            baseDelayNanoseconds: 0
        ) {
            try await provider.summarize(
                request: SummarizationRequest(
                    documentId: "d1", volumeId: "vol1",
                    chunks: ["Test content."], isSynthesisPass: false
                ),
                prompt: SummarizationPromptSnapshot(
                    id: UUID(),
                    promptText: "Summarize: {{DOCUMENT}}",
                    responseFormat: .general
                )
            )
        }

        let callCount = await provider.callCount
        #expect(callCount == 3)
        #expect(result.text == "Retried summary.")
    }

    // MARK: - CompletionNotificationTest

    @Test("CompletionNotificationTest: progress state reaches .completed after empty scope")
    func completionStateReachedAfterEmptyScope() async throws {
        let container = try ModelContainer.makeTestContainer()
        let progress = await BackgroundSummarizationProgress()
        let summarizationService = SummarizationService(modelContainer: container)
        let service = BackgroundSummarizationService(
            summarizationService: summarizationService,
            modelContainer: container,
            progress: progress
        )

        let prompt = SummarizationPrompt(
            name: "Test",
            promptText: "Summarize: {{DOCUMENT}}",
            isStandard: false
        )

        // Scope that resolves to no downloaded volumes → completes immediately with 0
        await service.start(
            scope: .volume(volumeId: "nonexistent"),
            promptSnapshot: SummarizationPromptSnapshot(from: prompt),
            provider: MockSummarizationProvider(),
            concurrencyLimit: 1,
            downloadedVolumeURLs: [:],
            manifestEntries: [],
            activeProjectId: nil
        )

        // Allow the async task to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s

        let state = await progress.state
        if case .completed(let processed) = state {
            #expect(processed == 0)
        } else {
            Issue.record("Expected .completed, got \(state)")
        }
    }
}

// MARK: - RetryTestProvider

/// Mock provider that fails `failCount` times with a generic error, then succeeds.
private actor RetryTestProvider: SummarizationProvider {
    var isAvailable: Bool = true
    var contextWindowTokenLimit: Int = 3_072

    private(set) var callCount: Int = 0
    private let failCount: Int
    private let successText: String

    init(failCount: Int, successText: String) {
        self.failCount = failCount
        self.successText = successText
    }

    func summarize(
        request: SummarizationRequest,
        prompt: SummarizationPromptSnapshot
    ) async throws -> SummarizationResult {
        callCount += 1
        if callCount <= failCount {
            throw RetryTestError.simulatedFailure
        }
        return SummarizationResult(
            text: successText,
            responseFormat: prompt.responseFormat,
            wasChunked: false
        )
    }
}

private enum RetryTestError: Error {
    case simulatedFailure
}

// MARK: - MockSummarizationProvider (re-exported for this test file)

private actor MockSummarizationProvider: SummarizationProvider {
    var isAvailable: Bool = true
    var contextWindowTokenLimit: Int = 3_072

    func summarize(
        request: SummarizationRequest,
        prompt: SummarizationPromptSnapshot
    ) async throws -> SummarizationResult {
        return SummarizationResult(text: "Mock.", responseFormat: .general, wasChunked: false)
    }
}
