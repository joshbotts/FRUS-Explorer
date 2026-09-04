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

// MARK: - SummarizationUITests

@MainActor
struct SummarizationUITests {

    // MARK: - PromptCreationTest

    @Test("PromptCreationTest: user prompt is saved to SwiftData with correct fields")
    func userPromptSavedWithCorrectFields() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)

        let prompt = SummarizationPrompt(
            name: "My Custom Prompt",
            promptText: "Summarize this: {{DOCUMENT}}",
            responseFormat: .general,
            isStandard: false,
            schema: nil
        )
        context.insert(prompt)
        try context.save()

        let descriptor = FetchDescriptor<SummarizationPrompt>(
            predicate: #Predicate { $0.isStandard == false }
        )
        let fetched = try context.fetch(descriptor)

        #expect(fetched.count == 1)
        let saved = try #require(fetched.first)
        #expect(saved.name == "My Custom Prompt")
        #expect(saved.promptText == "Summarize this: {{DOCUMENT}}")
        #expect(saved.isStandard == false)
        if case .general = saved.responseFormat { } else {
            Issue.record("Expected .general responseFormat, got \(saved.responseFormat)")
        }
    }

    // MARK: - TemplateSelectionTest

    @Test("TemplateSelectionTest: Meeting Record template pre-populates correct schema fields")
    func meetingRecordTemplateHasCorrectFields() throws {
        let template = try #require(
            SummarizationPromptSeeder.standardTemplates.first { $0.name.contains("Meeting") }
        )

        #expect(!template.fields.isEmpty)
        #expect(template.fields.count == 4)

        let names = template.fields.map(\.name)
        #expect(names.contains("KeyParticipants"))
        #expect(names.contains("Topics"))
        #expect(names.contains("Agreements"))
        #expect(names.contains("Disagreements"))

        if case .structured(let schema) = template.responseFormat {
            #expect(schema.fields.count == 4)
        } else {
            Issue.record("Expected .structured responseFormat for Meeting Record template")
        }
    }

    // MARK: - SummaryDisplayTest — RETIRED (R-5 P3b-6)
    //
    // This suite carried a `summaryDisplayCyclesBetweenSummaries` test whose body opened with
    // "// Simulate what DocumentViewModel.loadSummaries does" and then re-implemented it: the same
    // predicate, the same `fetchLimit = 20`, the same in-memory sort. It could not fail for
    // anything the real function did, and it had already drifted from it — the copy dropped the
    // `!isHeadnoteDraft` predicate production carries, so it asserted an order over rows the app
    // would never have shown.
    //
    // `SummaryCarouselOrderTests` replaces it by CALLING `loadSummaries` on a real
    // `DocumentViewModel`, which is why the P3b-6 ordering fix is pinned at all: against this
    // mirror, changing the descriptor's sort was invisible.

    @Test("PromotionTest: promoteSummary inserts text into note body and records summary ID")
    func summaryPromotionInsertsTextAndRecordsId() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)

        let summary = GeneratedSummary(
            documentId: "d2", volumeId: "vol2",
            promptId: UUID(), responseText: "Summary to promote.",
            wasChunked: false
        )
        context.insert(summary)
        try context.save()

        let vm = ResearchNoteEditorViewModel(
            documentId: "d2",
            volumeId: "vol2",
            activeProjectId: nil,
            noteToEdit: nil
        )
        vm.load(context: context)

        #expect(vm.availableSummaries.count == 1)

        vm.promoteSummary(summary)

        #expect(vm.bodyText == "Summary to promote.")
        #expect(vm.selectedSummaryIds.contains(summary.id))
    }

    // MARK: - SeederTest

    @Test("SeederTest: seed inserts correct number of standard prompts; idempotent on second call")
    func seederInsertsStandardPromptsOnce() async throws {
        let container = try ModelContainer.makeTestContainer()

        SummarizationPromptSeeder.seed(in: container)

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<SummarizationPrompt>(
            predicate: #Predicate { $0.isStandard == true }
        )
        let afterFirst = try context.fetch(descriptor)
        #expect(afterFirst.count == SummarizationPromptSeeder.standardTemplates.count)

        // Second call must not duplicate
        SummarizationPromptSeeder.seed(in: container)
        let afterSecond = try context.fetch(descriptor)
        #expect(afterSecond.count == afterFirst.count)
    }
}
