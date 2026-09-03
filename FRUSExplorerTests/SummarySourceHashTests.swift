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

// MARK: - HashTestProvider

/// A provider that answers instantly, so the test exercises the service's own bookkeeping.
private actor HashTestProvider: SummarizationProvider {
    var isAvailable: Bool = true
    var contextWindowTokenLimit: Int = 3_072
    func summarize(request: SummarizationRequest,
                   prompt: SummarizationPromptSnapshot) async throws -> SummarizationResult {
        SummarizationResult(text: "A summary.", responseFormat: prompt.responseFormat, wasChunked: false)
    }
}

// MARK: - SummarySourceHashTests

/// `GeneratedSummary.sourceContentHash` — which text a summary describes (R-5 P3b-2, design Q-8
/// d-cloud).
///
/// **These cases inject a LIVE `IndexingPipeline`, which no existing summarization test does.**
/// Every construction in `SummarizationServiceTests` passes no pipeline, so a case asserting
/// `sourceContentHash == nil` there would pass whether the feature existed or not — and would
/// keep passing against a deleted write.
///
/// Version history:
///   1.0 — R-5 P3b-2: initial implementation
@Suite("Summary source hash — the text a summary describes")
struct SummarySourceHashTests {

    private let vol = "frus1958-60v01"
    private var base: [DocumentRevisionsTests.Doc] {
        [.init(id: "d1", head: "Memorandum of Conversation", body: "The Ambassador called at noon.",
               sourceNote: "Department of State, Central Files, 611.51/1-1558."),
         .init(id: "d2", head: "Telegram From the Embassy", body: "Nothing to report from Paris.")]
    }

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(for: GeneratedSummary.self,
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }

    private func prompt() -> SummarizationPromptSnapshot {
        SummarizationPromptSnapshot(id: UUID(), promptText: "Summarize: {{DOCUMENT}}", responseFormat: .general)
    }

    /// The stored value is the revision row's own hash — not a hash of the text handed to the
    /// summariser, which could never compare equal because `contentHash` hashes the stored
    /// columns instead.
    @Test("A summary records the indexed document's content hash")
    @MainActor
    func recordsTheRevisionHash() async throws {
        let h = try DocumentRevisionsTests.Harness()
        try h.write(vol, base)
        _ = try await h.index(vol)
        let expected = try #require(try await h.pipeline.documentRevision(volumeId: vol, documentId: "d2")?.contentHash)
        #expect(!expected.isEmpty)

        let container = try makeContainer()
        let service = SummarizationService(modelContainer: container, indexingPipeline: h.pipeline)
        let summary = try await service.summarize(
            documentId: "d2", volumeId: vol, documentText: "Nothing to report from Paris.",
            prompt: prompt(), provider: HashTestProvider(), activeProjectId: nil)
        #expect(summary.sourceContentHash == expected)
        #expect(summary.sourceContentHash != nil)
    }

    /// A document this device has not indexed has no hash to record, and `nil` is the honest
    /// value — `""` would read as a hash and compare unequal to every real one for ever.
    @Test("An unindexed document yields nil, never an empty string")
    @MainActor
    func unindexedYieldsNil() async throws {
        let h = try DocumentRevisionsTests.Harness()
        try h.write(vol, base)
        _ = try await h.index(vol)
        let container = try makeContainer()
        let service = SummarizationService(modelContainer: container, indexingPipeline: h.pipeline)
        let summary = try await service.summarize(
            documentId: "d99", volumeId: vol, documentText: "Text of a document not in the index.",
            prompt: prompt(), provider: HashTestProvider(), activeProjectId: nil)
        #expect(summary.sourceContentHash == nil)
    }

    /// The hash moves with the text, so a summary made before a correction and one made after
    /// carry different values — which is what lets a later phase say which describes the current
    /// text.
    @Test("A correction changes the hash a later summary records")
    @MainActor
    func hashFollowsTheText() async throws {
        let h = try DocumentRevisionsTests.Harness()
        try h.write(vol, base)
        _ = try await h.index(vol)
        let container = try makeContainer()
        let service = SummarizationService(modelContainer: container, indexingPipeline: h.pipeline)
        let before = try await service.summarize(
            documentId: "d2", volumeId: vol, documentText: "Nothing to report from Paris.",
            prompt: prompt(), provider: HashTestProvider(), activeProjectId: nil)

        var edited = base
        edited[1].body = "Nothing to report from Paris, except the rain."
        try h.write(vol, edited)
        _ = try await h.index(vol)
        let after = try await service.summarize(
            documentId: "d2", volumeId: vol, documentText: "Nothing to report from Paris, except the rain.",
            prompt: prompt(), provider: HashTestProvider(), activeProjectId: nil)

        #expect(before.sourceContentHash != nil)
        #expect(after.sourceContentHash != nil)
        #expect(before.sourceContentHash != after.sourceContentHash)
        #expect(after.sourceContentHash
                == (try await h.pipeline.documentRevision(volumeId: vol, documentId: "d2")?.contentHash))
    }

    /// A headnote draft is the reader's own text and must not claim to describe a version of the
    /// document — the field-by-field duplicate declines it in writing.
    @Test("A headnote draft carries no source hash")
    @MainActor
    func draftsCarryNoHash() throws {
        let draft = GeneratedSummary(documentId: "d1", volumeId: "v1", promptId: UUID(),
                                     responseText: "my own words", isHeadnoteDraft: true)
        #expect(draft.sourceContentHash == nil)
    }
}
