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

// MARK: - ResearchDataExporterTests

/// Tests for `ResearchDataExporter` (Session 154 Task 2 — Research Data Export).
@MainActor
struct ResearchDataExporterTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Project.self,
            ResearchNote.self,
            Collection.self,
            CollectionEntry.self,
            UserTag.self,
            DocumentTagAssignment.self,
            DocumentHighlight.self,
            GeneratedSummary.self,
            SummarizationPrompt.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    /// Seeds one record of every exported type, with cross-references
    /// (highlight → note, collection → entry) so the round trip can verify them.
    @discardableResult
    private func seedFixtures(in context: ModelContext) -> (note: ResearchNote, highlight: DocumentHighlight) {
        let project = Project(name: "Cold War Diplomacy")
        context.insert(project)

        let tag = UserTag(name: "Primary Source")
        context.insert(tag)

        let note = ResearchNote(
            documentId: "d1",
            volumeId: "frus1969-76v01",
            bodyText: "Key turning point in the negotiations.",
            projectIds: [project.id],
            userTagIds: [tag.id]
        )
        context.insert(note)

        let highlight = DocumentHighlight(
            volumeId: "frus1969-76v01",
            documentId: "d1",
            startOffset: 10,
            endOffset: 42,
            colorTag: "yellow",
            noteId: note.id,
            selectedText: "a key turning point",
            renderingVersion: "abc123"
        )
        context.insert(highlight)

        let assignment = DocumentTagAssignment(volumeId: "frus1969-76v01", documentId: "d2", tagId: tag.id)
        context.insert(assignment)

        let collection = Collection(name: "Vietnam Negotiations", projectIds: [project.id])
        context.insert(collection)
        let entry = CollectionEntry(collectionId: collection.id, documentId: "d1", volumeId: "frus1969-76v01", sortOrder: 0)
        entry.collection = collection
        context.insert(entry)

        let userPrompt = SummarizationPrompt(name: "My Prompt", promptText: "Summarize {{DOCUMENT}}", isStandard: false)
        context.insert(userPrompt)

        let standardPrompt = SummarizationPrompt(name: "Standard Prompt", promptText: "Standard {{DOCUMENT}}", isStandard: true)
        context.insert(standardPrompt)

        let summary = GeneratedSummary(
            documentId: "d1",
            volumeId: "frus1969-76v01",
            promptId: userPrompt.id,
            responseText: "This document discusses..."
        )
        context.insert(summary)

        return (note, highlight)
    }

    // MARK: - makeEnvelope

    @Test("makeEnvelope excludes GeneratedSummary by default and excludes standard prompts")
    func makeEnvelopeDefaultExcludesSummariesAndStandardPrompts() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedFixtures(in: context)

        let envelope = try ResearchDataExporter.makeEnvelope(modelContext: context, includeGeneratedSummaries: false)

        #expect(envelope.formatVersion == ResearchDataExporter.currentFormatVersion)
        #expect(envelope.notes.count == 1)
        #expect(envelope.tags.count == 1)
        #expect(envelope.tagAssignments.count == 1)
        #expect(envelope.highlights.count == 1)
        #expect(envelope.collections.count == 1)
        #expect(envelope.collections.first?.entries.count == 1)
        #expect(envelope.projects.count == 1)
        #expect(envelope.prompts.count == 1)
        #expect(envelope.prompts.first?.name == "My Prompt")
        #expect(envelope.summaries.isEmpty)
    }

    @Test("makeEnvelope includes GeneratedSummary when opted in")
    func makeEnvelopeIncludesSummariesWhenRequested() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedFixtures(in: context)

        let envelope = try ResearchDataExporter.makeEnvelope(modelContext: context, includeGeneratedSummaries: true)

        #expect(envelope.summaries.count == 1)
        #expect(envelope.summaries.first?.responseText == "This document discusses...")
    }

    @Test("makeEnvelope links highlights back to their note via linkedHighlightIds")
    func makeEnvelopeLinksHighlightsToNotes() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let fixtures = seedFixtures(in: context)

        let envelope = try ResearchDataExporter.makeEnvelope(modelContext: context, includeGeneratedSummaries: false)

        let exportedNote = try #require(envelope.notes.first)
        #expect(exportedNote.id == fixtures.note.id)
        #expect(exportedNote.linkedHighlightIds == [fixtures.highlight.id])
    }

    // MARK: - JSON round trip

    @Test("exportJSONData round-trips through JSONDecoder and preserves the envelope")
    func exportJSONDataRoundTrips() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedFixtures(in: context)

        let envelope = try ResearchDataExporter.makeEnvelope(modelContext: context, includeGeneratedSummaries: true)
        let data = try ResearchDataExporter.exportJSONData(envelope)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ResearchDataEnvelope.self, from: data)

        #expect(decoded.formatVersion == envelope.formatVersion)
        #expect(decoded.notes.map(\.id) == envelope.notes.map(\.id))
        #expect(decoded.tags.map(\.id) == envelope.tags.map(\.id))
        #expect(decoded.tagAssignments.map(\.id) == envelope.tagAssignments.map(\.id))
        #expect(decoded.highlights.map(\.id) == envelope.highlights.map(\.id))
        #expect(decoded.collections.map(\.id) == envelope.collections.map(\.id))
        #expect(decoded.prompts.map(\.id) == envelope.prompts.map(\.id))
        #expect(decoded.projects.map(\.id) == envelope.projects.map(\.id))
        #expect(decoded.summaries.map(\.id) == envelope.summaries.map(\.id))

        // ISO 8601 without fractional seconds rounds Date fields to whole
        // seconds, so a single round trip can differ from `envelope` (which
        // carries `Date.now`'s sub-second precision). Verify the JSON format
        // itself is lossless: re-encoding `decoded` and decoding again should
        // be idempotent.
        let decodedAgain = try decoder.decode(ResearchDataEnvelope.self, from: try ResearchDataExporter.exportJSONData(decoded))
        #expect(decodedAgain == decoded)
    }

    // MARK: - #377 Phase 4: active-project header

    @Test("makeEnvelope stamps the active project's name/question header; nil/non-matching id → none; projects[] unchanged")
    func makeEnvelopeStampsActiveProject() throws {
        let container = try makeContainer()
        let context = container.mainContext
        _ = seedFixtures(in: context)
        let project = try #require(try context.fetch(FetchDescriptor<Project>()).first)
        project.researchQuestion = "How did détente evolve?"
        try context.save()

        // With the active project id → the header carries its name + question…
        let withProject = try ResearchDataExporter.makeEnvelope(
            modelContext: context, includeGeneratedSummaries: false, activeProjectId: project.id)
        #expect(withProject.exportedForProjectName == "Cold War Diplomacy")
        #expect(withProject.exportedForProjectResearchQuestion == "How did détente evolve?")
        #expect(withProject.projects.count == 1)   // …and the full project backup array is unchanged.

        // No active project (Global Context) → no header project.
        let noProject = try ResearchDataExporter.makeEnvelope(
            modelContext: context, includeGeneratedSummaries: false, activeProjectId: nil)
        #expect(noProject.exportedForProjectName == nil)
        #expect(noProject.exportedForProjectResearchQuestion == nil)
        #expect(noProject.projects.count == 1)

        // A stale/non-matching id → no header project (not a crash).
        let bad = try ResearchDataExporter.makeEnvelope(
            modelContext: context, includeGeneratedSummaries: false, activeProjectId: UUID())
        #expect(bad.exportedForProjectName == nil)
    }

    @Test("A pre-Phase-4 JSON (no header-project keys) still decodes")
    func legacyJSONDecodes() throws {
        let json = Data(#"{"formatVersion":1,"exportedAt":"2024-01-01T00:00:00Z","notes":[],"tags":[],"tagAssignments":[],"highlights":[],"collections":[],"prompts":[],"projects":[],"summaries":[]}"#.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ResearchDataEnvelope.self, from: json)
        #expect(decoded.formatVersion == 1)
        #expect(decoded.exportedForProjectName == nil)
        #expect(decoded.exportedForProjectResearchQuestion == nil)
    }

    @Test("exportJSONData top-level keys match the documented envelope schema")
    func exportJSONDataKeysMatchSchema() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedFixtures(in: context)

        let envelope = try ResearchDataExporter.makeEnvelope(modelContext: context, includeGeneratedSummaries: false)
        let data = try ResearchDataExporter.exportJSONData(envelope)

        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let expectedKeys: Set<String> = [
            "formatVersion", "exportedAt", "notes", "tags", "tagAssignments",
            "highlights", "collections", "prompts", "projects", "summaries",
        ]
        #expect(Set(json.keys) == expectedKeys)
    }

    // MARK: - Markdown export

    @Test("markdownExports renders YAML front matter with canonical URL and tags, without a citation when unindexed")
    func markdownExportsRenderFrontMatter() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let fixtures = seedFixtures(in: context)

        let allTags = try context.fetch(FetchDescriptor<UserTag>())
        let appState = AppState()

        let exports = await ResearchDataExporter.markdownExports(notes: [fixtures.note], tags: allTags, appState: appState)

        let export = try #require(exports.first)
        #expect(export.id == fixtures.note.id)
        #expect(export.filename == "frus1969-76v01-d1-\(fixtures.note.id.uuidString.prefix(8)).md")
        #expect(export.content.contains("documentId: d1"))
        #expect(export.content.contains("volumeId: frus1969-76v01"))
        #expect(export.content.contains("url: https://history.state.gov/historicaldocuments/frus1969-76v01/d1"))
        // Tag names are quoted YAML scalars (Session 158): user-authored names
        // can contain ':'/'"'/']', which break unquoted flow-sequence entries.
        #expect(export.content.contains("tags: [\"Primary Source\"]"))
        #expect(export.content.contains("Key turning point in the negotiations."))
        #expect(!export.content.contains("citation:"))
    }
}
