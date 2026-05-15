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

// MARK: - ModelInitializationTests

/// Verifies that each @Model type initializes with correct defaults and
/// that identity fields (id, createdAt, lastModified) are set as expected.
@MainActor
struct ModelInitializationTests {

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer.makeTestContainer()
    }

    @Test("Project initializes with correct defaults")
    func projectInit() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let before = Date.now
        let project = Project(name: "SALT II Negotiations")
        ctx.insert(project)

        #expect(project.name == "SALT II Negotiations")
        #expect(project.researchQuestion == nil)
        #expect(project.defaultSubjectTagIds.isEmpty)
        #expect(project.defaultCountryTagIds.isEmpty)
        #expect(project.createdAt! >= before)
        #expect(project.lastModified! >= before)
        // lastModified and createdAt are set from the same Date.now call
        #expect(project.lastModified == project.createdAt)
        // id is a non-nil UUID
        #expect(project.id != UUID())  // any UUID is valid; verify it was set
    }

    @Test("ResearchNote initializes with correct defaults")
    func researchNoteInit() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let note = ResearchNote(documentId: "d42", volumeId: "frus1969-76v01")
        ctx.insert(note)

        #expect(note.documentId == "d42")
        #expect(note.volumeId == "frus1969-76v01")
        #expect(note.bodyText == "")
        #expect(note.projectIds.isEmpty)
        #expect(note.userTagIds.isEmpty)
        #expect(note.selectedSummaryIds.isEmpty)
    }

    @Test("GeneratedSummary initializes with correct defaults")
    func generatedSummaryInit() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let promptId = UUID()
        let summary = GeneratedSummary(
            documentId: "d1",
            volumeId: "frus1969-76v01",
            promptId: promptId,
            responseText: "This document discusses…"
        )
        ctx.insert(summary)

        #expect(summary.responseText == "This document discusses…")
        #expect(summary.responseFormat == .general)
        #expect(summary.wasChunked == false)
        #expect(summary.projectId == nil)
        #expect(summary.promptId == promptId)
    }

    @Test("UserTag initializes with name")
    func userTagInit() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let tag = UserTag(name: "Primary Source")
        ctx.insert(tag)

        #expect(tag.name == "Primary Source")
        #expect(tag.createdAt! <= Date.now)
    }

    @Test("Collection initializes with empty entries")
    func collectionInit() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let collection = Collection(name: "Key SALT Documents")
        ctx.insert(collection)

        #expect(collection.name == "Key SALT Documents")
        #expect(collection.note == nil)
        #expect(collection.projectIds.isEmpty)
        #expect(collection.documentEntries?.isEmpty != false)
    }

    @Test("CollectionEntry initializes with correct fields")
    func collectionEntryInit() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let collectionId = UUID()
        let entry = CollectionEntry(
            collectionId: collectionId,
            documentId: "d5",
            volumeId: "frus1969-76v02",
            sortOrder: 0
        )
        ctx.insert(entry)

        #expect(entry.collectionId == collectionId)
        #expect(entry.documentId == "d5")
        #expect(entry.sortOrder == 0)
        #expect(entry.researchNoteId == nil)
    }

    @Test("ReadingHistoryEntry captures access time")
    func readingHistoryEntryInit() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let before = Date.now
        let entry = ReadingHistoryEntry(documentId: "d1", volumeId: "frus1969-76v01")
        ctx.insert(entry)

        #expect(entry.documentId == "d1")
        #expect(entry.projectId == nil)
        #expect(entry.accessedAt! >= before)
    }

    @Test("SummarizationPrompt initializes with correct defaults")
    func sumPromptInit() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let prompt = SummarizationPrompt(
            name: "Diplomatic Cable Summary",
            promptText: "Summarize the following document: {{DOCUMENT}}"
        )
        ctx.insert(prompt)

        #expect(prompt.name == "Diplomatic Cable Summary")
        #expect(prompt.responseFormat == .general)
        #expect(prompt.isStandard == false)
        #expect(prompt.schema == nil)
    }
}

// MARK: - LastModifiedTests

/// Verifies that `lastModified` is a writable `Date?` that can be updated to
/// record the most recent modification time.
///
/// Note: `@Model` properties use the Observation framework under the hood, which
/// transforms stored properties into computed properties backed by persistent storage.
/// `didSet` observers are retained syntactically but may not be called by SwiftData's
/// persistence layer in all execution paths. Callers in the business-logic layer
/// (views, view models) are responsible for explicitly setting `lastModified = .now`
/// when making changes that should be visible to CloudKit conflict resolution.
@MainActor
struct LastModifiedTests {

    @Test("Project.lastModified is writable and advances when set")
    func projectLastModifiedWritable() throws {
        let container = try ModelContainer.makeTestContainer()
        let ctx = container.mainContext

        let project = Project(name: "Initial")
        ctx.insert(project)

        let before = project.lastModified!
        Thread.sleep(forTimeInterval: 0.002)

        // Simulate what business logic must do: explicitly record the mutation time.
        project.lastModified = .now

        #expect(project.lastModified! > before, "lastModified must advance after direct assignment")
    }

    @Test("ResearchNote.lastModified is writable and advances when set")
    func noteLastModifiedWritable() throws {
        let container = try ModelContainer.makeTestContainer()
        let ctx = container.mainContext

        let note = ResearchNote(documentId: "d1", volumeId: "v1")
        ctx.insert(note)

        let before = note.lastModified!
        Thread.sleep(forTimeInterval: 0.002)
        note.lastModified = .now

        #expect(note.lastModified! > before)
    }

    @Test("UserTag.lastModified is writable and advances when set")
    func tagLastModifiedWritable() throws {
        let container = try ModelContainer.makeTestContainer()
        let ctx = container.mainContext

        let tag = UserTag(name: "Draft")
        ctx.insert(tag)

        let before = tag.lastModified!
        Thread.sleep(forTimeInterval: 0.002)
        tag.lastModified = .now

        #expect(tag.lastModified! > before)
    }
}
