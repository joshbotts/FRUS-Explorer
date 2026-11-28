// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Testing
import Foundation
import SwiftData
@testable import FRUSExplorer

// MARK: - ResearchDataImporterTests

/// Import from JSON written into the app's store (#1915, L24): FRUSCoreKit's plan, applied by
/// `ResearchDataImporter` to an in-memory container, gives back what was exported, plans nothing a
/// second time, keeps a replaced record's own date, and reaches every copy and the search index's
/// user half.
///
/// The files are `ResearchDataFixtures`' (`FRUSExplorerTests/FRUSCoreKit/`): one of each format
/// version from 1 to 7, each holding one record of every type its version carried, so an import of
/// each, exported again, holds every field of every type's mapping to account for.
///
/// Version history:
///   1.0 — #1915 (L24): initial implementation
@MainActor
@Suite("Import from JSON: the plan written into the app's store")
struct ResearchDataImporterTests {

    // MARK: Fixtures

    /// The fixture of `version`.
    private static func json(version: Int) throws -> String {
        if version == ResearchDataEnvelope.currentFormatVersion { return ResearchDataFixtures.version8 }
        return try #require(ResearchDataFixtures.earlierVersions.first { $0.version == version }?.json)
    }

    /// The fixture of `version`, read as the screen reads a file.
    private static func file(version: Int) throws -> ResearchImportFile {
        try ResearchImportFile(data: Data(try json(version: version).utf8))
    }

    /// A time, as the fixtures write one.
    private static func date(_ text: String) throws -> Date {
        try #require(ISO8601DateFormatter().date(from: text))
    }

    /// Imports `file` into `container` as the screen does, with no search index.
    @discardableResult
    private static func importFile(_ file: ResearchImportFile, into container: ModelContainer,
                                   batchSize: Int = ResearchDataImporter.batchSize,
                                   progress: (Int, Int) -> Void = { _, _ in }) async throws
        -> ResearchImportOutcome {
        try await ResearchDataImporter.importFile(file, mainContext: container.mainContext,
                                                  pipeline: nil, settingsSync: nil,
                                                  batchSize: batchSize, progress: progress)
    }

    /// The library's export, with its summaries, as a fresh context reads the saved store.
    private static func export(_ container: ModelContainer) throws -> ResearchDataEnvelope {
        try ResearchDataExporter.makeEnvelope(modelContext: ModelContext(container),
                                              includeGeneratedSummaries: true)
    }

    /// `envelope` with what two exports of one library need not share cleared (when and under which
    /// project each was made, and its version), and every list in one order: by id, a collection's
    /// entries by their place, a note's highlights sorted.
    private static func normalized(_ envelope: ResearchDataEnvelope) -> ResearchDataEnvelope {
        var envelope = envelope
        envelope.formatVersion = ResearchDataEnvelope.currentFormatVersion
        envelope.exportedAt = .distantPast
        envelope.exportedForProjectName = nil
        envelope.exportedForProjectResearchQuestion = nil
        func byId<Record: IdentifiedImportRecord>(_ records: [Record]) -> [Record] {
            records.sorted { $0.id.uuidString < $1.id.uuidString }
        }
        envelope.notes = byId(envelope.notes).map { note in
            var note = note
            note.linkedHighlightIds.sort { $0.uuidString < $1.uuidString }
            return note
        }
        envelope.tags = byId(envelope.tags)
        envelope.tagAssignments = byId(envelope.tagAssignments)
        envelope.highlights = byId(envelope.highlights)
        envelope.collections = byId(envelope.collections).map { collection in
            var collection = collection
            collection.entries.sort { ($0.sortOrder, $0.id.uuidString) < ($1.sortOrder, $1.id.uuidString) }
            return collection
        }
        envelope.prompts = byId(envelope.prompts)
        envelope.projects = byId(envelope.projects)
        envelope.summaries = byId(envelope.summaries)
        envelope.readingHistory = byId(envelope.readingHistory)
        envelope.searchHistory = byId(envelope.searchHistory)
        envelope.exportHistory = byId(envelope.exportHistory)
        envelope.archiveVisits = byId(envelope.archiveVisits).map { plan in
            var plan = plan
            plan.documents.sort { $0.documentKey < $1.documentKey }
            plan.targets.sort { $0.targetKey < $1.targetKey }
            return plan
        }
        envelope.savedSearches = byId(envelope.savedSearches)
        envelope.workingCorpora = byId(envelope.workingCorpora)
        envelope.customVolumeScopes = byId(envelope.customVolumeScopes)
        envelope.classificationOverrides = byId(envelope.classificationOverrides)
        envelope.personClusterOverrides = byId(envelope.personClusterOverrides)
        envelope.annotationReviews = byId(envelope.annotationReviews)
        envelope.projectLeads = byId(envelope.projectLeads)
        envelope.syncedPreferences.sort { $0.createdAt < $1.createdAt }
        return envelope
    }

    /// The export a plan's records make once written into an empty library: each addition's record,
    /// a collection's entries and a visit's documents and targets nested in their parent again, and a
    /// note's highlights read from the highlights that name it, as the export reads them.
    private static func envelope(of plan: ResearchImportPlan) -> ResearchDataEnvelope {
        func added<Record: ResearchImportRecord>(_ items: [ResearchImportPlan.Item<Record>]) -> [Record] {
            items.filter { $0.action == .add }.map(\.record)
        }
        let highlights = added(plan.highlights)
        let entries = Dictionary(grouping: plan.collectionEntries.filter { $0.action == .add },
                                 by: { $0.parentId })
        let documents = Dictionary(grouping: plan.archiveVisitDocuments.filter { $0.action == .add },
                                   by: { $0.parentId })
        let targets = Dictionary(grouping: plan.archiveVisitTargets.filter { $0.action == .add },
                                 by: { $0.parentId })
        return ResearchDataEnvelope(
            formatVersion: plan.formatVersion, exportedAt: .distantPast,
            notes: added(plan.notes).map { note in
                var note = note
                note.linkedHighlightIds = highlights.filter { $0.noteId == note.id }.map(\.id)
                return note
            },
            tags: added(plan.tags),
            tagAssignments: added(plan.tagAssignments),
            highlights: highlights,
            collections: added(plan.collections).map { collection in
                var collection = collection
                collection.entries = (entries[collection.id] ?? []).map(\.record)
                return collection
            },
            prompts: added(plan.prompts),
            projects: added(plan.projects),
            summaries: added(plan.summaries),
            readingHistory: added(plan.readingHistory),
            searchHistory: added(plan.searchHistory),
            exportHistory: added(plan.exportHistory),
            archiveVisits: added(plan.archiveVisits).map { visit in
                var visit = visit
                visit.documents = (documents[visit.id] ?? []).map(\.record)
                visit.targets = (targets[visit.id] ?? []).map(\.record)
                return visit
            },
            savedSearches: added(plan.savedSearches),
            workingCorpora: added(plan.workingCorpora),
            customVolumeScopes: added(plan.customVolumeScopes),
            classificationOverrides: added(plan.classificationOverrides),
            personClusterOverrides: added(plan.personClusterOverrides),
            annotationReviews: added(plan.annotationReviews),
            projectLeads: added(plan.projectLeads),
            syncedPreferences: plan.syncedPreferences.map { [$0.record] } ?? [])
    }

    // MARK: - A round trip

    /// Each version's file, imported into an empty library and exported again, is every record the
    /// plan resolved, field for field: what the file's version carries as the file has it, and the
    /// rest as the app's defaults.
    @Test("A file of each format version imports into an empty library as the plan resolves it",
          arguments: 1...8)
    func eachVersionImportsAsThePlanResolvesIt(version: Int) async throws {
        let container = try ModelContainer.makeTestContainer()
        let file = try Self.file(version: version)
        let plan = ResearchImportPlan(file: file, library: ResearchLibrarySnapshot())
        let outcome = try await Self.importFile(file, into: container)

        let exported = try Self.export(container)
        #expect(Self.normalized(exported) == Self.normalized(Self.envelope(of: plan)))
        #expect(outcome.added == plan.report.added && outcome.replaced == 0)
        #expect(outcome.added > 0)
    }

    /// The issue's app test: an export of a library, imported into an empty one, gives back what
    /// was exported, every record and every field, from the app's file and from the web edition's.
    @Test("An export imported into an empty library gives back what was exported",
          arguments: [false, true])
    func anExportComesBackAsExported(fromTheWebEdition: Bool) async throws {
        // A library holding one record of every type, every field set: the version-7 fixture.
        let library = try ModelContainer.makeTestContainer()
        let seed = fromTheWebEdition
            ? try ResearchImportFile(data: Data(ResearchDataFixtures.webEditionVersion7.utf8))
            : try Self.file(version: 7)
        #expect((seed.webKey != nil) == fromTheWebEdition)
        try await Self.importFile(seed, into: library)
        let exported = try Self.export(library)
        #expect(exported.syncedPreferences.count == 1 && exported.archiveVisits.first?.targets.count == 1)

        // Its file, through the encoder and the import's decoder, into an empty library.
        let file = try ResearchImportFile(data: try ResearchDataExporter.exportJSONData(exported))
        let empty = try ModelContainer.makeTestContainer()
        let outcome = try await Self.importFile(file, into: empty)

        #expect(Self.normalized(try Self.export(empty)) == Self.normalized(exported))
        let records = file.envelope
        let counts: [Int] = [
            records.notes.count, records.tags.count, records.tagAssignments.count,
            records.highlights.count, records.collections.count,
            records.collections.flatMap(\.entries).count, records.prompts.count,
            records.projects.count, records.summaries.count, records.readingHistory.count,
            records.searchHistory.count, records.exportHistory.count, records.archiveVisits.count,
            records.archiveVisits.flatMap(\.documents).count,
            records.archiveVisits.flatMap(\.targets).count, records.savedSearches.count,
            records.workingCorpora.count, records.customVolumeScopes.count,
            records.classificationOverrides.count, records.personClusterOverrides.count,
            records.annotationReviews.count, records.projectLeads.count,
            records.syncedPreferences.count,
        ]
        #expect(outcome.added == counts.reduce(0, +), "every record is added, once")
    }

    /// A collection's entries and an archive visit's documents and targets join their parent: the
    /// relationship the export reads them through, and the parent's id beside it.
    @Test("Children join the parent their item names")
    func childrenJoinTheirParents() async throws {
        let container = try ModelContainer.makeTestContainer()
        try await Self.importFile(try Self.file(version: 7), into: container)
        let context = ModelContext(container)
        let collection = try #require(try context.fetch(FetchDescriptor<Collection>()).first)
        let entries = collection.documentEntries ?? []
        #expect(entries.count == 5 && entries.allSatisfy { $0.collectionId == collection.id })
        let visit = try #require(try context.fetch(FetchDescriptor<ArchiveVisitPlan>()).first)
        #expect((visit.documents ?? []).count == 1 && (visit.targets ?? []).count == 1)
        #expect((visit.documents ?? []).allSatisfy { $0.planId == visit.id })
        #expect((visit.targets ?? []).allSatisfy { $0.planId == visit.id })
    }

    // MARK: - A second import

    /// Imported twice, a file plans nothing the second time: every record is as new as its own.
    @Test("A second import of the same file plans nothing", arguments: 1...8)
    func aSecondImportPlansNothing(version: Int) async throws {
        let container = try ModelContainer.makeTestContainer()
        let file = try Self.file(version: version)
        try await Self.importFile(file, into: container)

        let again = try ResearchDataImporter.plan(file, mainContext: container.mainContext).plan
        #expect(again.report.added == 0 && again.report.replaced == 0)
        #expect(again.report.kept > 0)
        let outcome = try await Self.importFile(file, into: container)
        #expect(outcome.added == 0 && outcome.replaced == 0)
        #expect(outcome.writtenTypes.isEmpty)
    }

    // MARK: - The dates

    /// The stamper observes the main context and re-dates every changed model it saves; the import
    /// writes on a context of its own, so a replaced record keeps the file's date and a second
    /// import of the file finds it as new as its own.
    @Test("A replaced record keeps the file's date while the stamper observes the main context")
    func aReplacementKeepsTheFilesDate() async throws {
        let container = try ModelContainer.makeTestContainer()
        let stamper = ModelModificationStamper()
        stamper.start(observing: container.mainContext)
        defer { stamper.stop() }

        let older = try Self.date("2026-06-01T09:10:00Z")
        let note = ResearchNote(documentId: "d1", volumeId: "frus1969-76v01", bodyText: "An older text.")
        note.id = ResearchDataFixtures.id(3)
        note.createdAt = older
        note.lastModified = older
        container.mainContext.insert(note)
        try container.mainContext.save()
        #expect(note.lastModified == older, "an insert is not stamped")

        let file = try Self.file(version: 7)
        let fileNote = try #require(file.envelope.notes.first)
        let outcome = try await Self.importFile(file, into: container)
        #expect(outcome.replaced == 1)

        let stored = try ModelContext(container).fetch(FetchDescriptor<ResearchNote>())
        #expect(stored.count == 1)
        #expect(stored.first?.bodyText == fileNote.bodyText)
        #expect(stored.first?.lastModified == fileNote.lastModified, "the file's date, not the save's")
        #expect(container.mainContext.hasChanges == false)

        let again = try ResearchDataImporter.plan(file, mainContext: container.mainContext).plan
        #expect(again.report.count(of: .researchNote).kept == 1 && again.report.replaced == 0)
    }

    // MARK: - Copies under one id

    /// A note stored as two copies under one id takes the file's newer copy in both, as an edit is
    /// written to each, so the copies keep one text.
    @Test("A replacement is written to every stored copy")
    func aReplacementReachesEveryCopy() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let older = try Self.date("2026-06-01T09:10:00Z")
        for offset in [0.0, 60] {
            let copy = ResearchNote(documentId: "d1", volumeId: "frus1969-76v01", bodyText: "Old \(offset)")
            copy.id = ResearchDataFixtures.id(3)
            copy.createdAt = older
            copy.lastModified = older.addingTimeInterval(offset)
            context.insert(copy)
        }
        try context.save()

        let file = try Self.file(version: 7)
        let fileNote = try #require(file.envelope.notes.first)
        let outcome = try await Self.importFile(file, into: container)
        #expect(outcome.replaced == 1, "one record, written to both its copies")

        let copies = ResearchNote.copies(of: ResearchDataFixtures.id(3), in: ModelContext(container))
        #expect(copies.count == 2)
        #expect(copies.allSatisfy { $0.bodyText == fileNote.bodyText && $0.richText == fileNote.richText })
        #expect(copies.allSatisfy { $0.lastModified == fileNote.lastModified })
    }

    // MARK: - An earlier file's new text

    /// A file before version 7 cannot carry a note's formatting, and one before 5 cannot say who
    /// wrote a summary: a new text from such a file leaves the note plain and the summary
    /// AI-generated, and the done line counts both.
    @Test("An earlier file's new text makes a formatted note plain and a summary AI-generated, counted")
    func anEarlierFilesNewTextIsCounted() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let older = try Self.date("2026-01-01T00:00:00Z")
        let note = ResearchNote(documentId: "d1", volumeId: "frus1969-76v01", bodyText: "Mine.")
        note.id = ResearchDataFixtures.id(3)
        note.richText = Data(#"{\rtf1\ansi {\b Mine}.}"#.utf8)
        note.createdAt = older
        note.lastModified = older
        context.insert(note)
        let summary = GeneratedSummary(documentId: "d1", volumeId: "frus1969-76v01", promptId: UUID(),
                                       responseText: "My own words.", authorship: .userWritten)
        summary.id = ResearchDataFixtures.id(10)
        summary.createdAt = older
        summary.lastModified = older
        context.insert(summary)
        try context.save()

        var envelope = try Self.file(version: 7).envelope
        envelope.formatVersion = 4
        envelope.notes[0].bodyText = "A new text."
        let index = try #require(envelope.summaries.firstIndex { $0.id == ResearchDataFixtures.id(10) })
        envelope.summaries[index].responseText = "A new summary."
        let outcome = try await Self.importFile(try ResearchImportFile(envelope: envelope), into: container)

        #expect(outcome.notesMadePlain == 1 && outcome.summariesMadeAIGenerated == 1)
        let read = ModelContext(container)
        let storedNote = try #require(ResearchNote.copies(of: ResearchDataFixtures.id(3), in: read).first)
        #expect(storedNote.bodyText == "A new text." && storedNote.richText == nil)
        let summaries = try read.fetch(FetchDescriptor<GeneratedSummary>())
        let storedSummary = try #require(summaries.first { $0.id == ResearchDataFixtures.id(10) })
        #expect(storedSummary.responseText == "A new summary." && storedSummary.authorship == .aiGenerated)
    }

    // MARK: - The synced preferences

    /// The set has no id: a newer file's set is written over the set the app reads, the earliest
    /// made, which keeps its own `createdAt`, so it stays the set the app reads.
    @Test("A replaced set of synced preferences keeps the library set's creation and takes the file's values")
    func theSyncedPreferencesReplaceTheSetTheAppReads() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let created = try Self.date("2026-01-01T00:00:00Z")
        let preferences = SyncedPreferences()
        preferences.createdAt = created
        preferences.updatedAt = created
        preferences.citationStyleRaw = "mla"
        context.insert(preferences)
        try context.save()

        let file = try Self.file(version: 7)
        let fileSet = try #require(file.envelope.syncedPreferences.first)
        let outcome = try await Self.importFile(file, into: container)
        #expect(outcome.writtenTypes.contains(.syncedPreferences))

        let sets = try ModelContext(container).fetch(FetchDescriptor<SyncedPreferences>())
        #expect(sets.count == 1)
        #expect(sets.first?.createdAt == created, "still the set the app reads")
        #expect(sets.first?.updatedAt == fileSet.updatedAt)
        #expect(sets.first?.citationStyleRaw == fileSet.citationStyleRaw
                    && sets.first?.wcGlobalStopwordsJSON == fileSet.wcGlobalStopwordsJSON)
    }

    // MARK: - Batches

    /// A file is written a batch at a time, each batch saved before the next, with the progress
    /// after each, and every record reaches the main context.
    @Test("A large file is saved in batches, with the progress after each")
    func aLargeFileIsSavedInBatches() async throws {
        let container = try ModelContainer.makeTestContainer()
        let made = try Self.date("2026-06-01T09:00:00Z")
        let notes = (0..<1_234).map { index in
            ResearchNoteExport(id: UUID(), documentId: "d\(index)", volumeId: "frus1969-76v01",
                               bodyText: "Note \(index)", projectIds: [], userTagIds: [],
                               selectedSummaryIds: [], linkedHighlightIds: [], createdAt: made,
                               lastModified: made)
        }
        let file = try ResearchImportFile(envelope: ResearchDataEnvelope(
            formatVersion: 7, exportedAt: made, notes: notes, tags: [], tagAssignments: [],
            highlights: [], collections: [], prompts: [], projects: [], summaries: []))

        let saves = SaveCount()
        let observer = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave, object: nil, queue: nil) { _ in saves.add() }
        defer { NotificationCenter.default.removeObserver(observer) }
        var reports: [Int] = []
        let outcome = try await Self.importFile(file, into: container, batchSize: 500) { written, total in
            #expect(total == 1_234)
            reports.append(written)
        }

        #expect(reports == [0, 500, 1_000, 1_234])
        #expect(saves.value >= 3, "a save for each batch")
        #expect(outcome.added == 1_234)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<ResearchNote>()) == 1_234,
                "the main context reads every batch")
    }

    // MARK: - The reserved field

    /// `AnnotationReview.annotationId` is reserved: its CloudKit identifier has never been deployed
    /// to Production, so the import writes no value into it, even one a file carries, and the
    /// review keeps `nil` (`CloudKitSchemaInventoryTests` holds every writer to the same rule).
    @Test("An imported review never takes a file's annotationId, a field awaiting its CloudKit deploy")
    func aReviewTakesNoAnnotationId() async throws {
        let container = try ModelContainer.makeTestContainer()
        var envelope = try Self.file(version: 7).envelope
        let index = try #require(envelope.annotationReviews.indices.first)
        envelope.annotationReviews[index].annotationId = UUID()
        try await Self.importFile(try ResearchImportFile(envelope: envelope), into: container)

        let reviews = try ModelContext(container).fetch(FetchDescriptor<AnnotationReview>())
        #expect(reviews.count == 1)
        #expect(reviews.first?.annotationId == nil)
        #expect(reviews.first?.contentHash == envelope.annotationReviews[index].contentHash)
    }

    // MARK: - The standard prompts

    /// An export leaves the standard prompts out, and the library holds them: the snapshot holds
    /// their ids, so a file's prompt with one is never added beside it.
    @Test("The library's standard prompts are in the snapshot")
    func theStandardPromptsAreHeld() throws {
        let container = try ModelContainer.makeTestContainer()
        let standard = SummarizationPrompt(name: "Standard", promptText: "Summarize {{DOCUMENT}}",
                                           isStandard: true)
        container.mainContext.insert(standard)
        try container.mainContext.save()
        let snapshot = try ResearchDataImporter.snapshot(of: ModelContext(container))
        #expect(snapshot.holds(.summarizationPrompt, id: standard.id))
    }

    // MARK: - The search index's user half

    /// Imported notes, summaries and tags reach the index as a save of each does: a note's words and
    /// a summary's are found by a search of the reader's own text, and a tagged document's row
    /// carries its tag.
    @Test("An import reaches the search index's user half")
    func anImportReachesTheSearchIndex() async throws {
        let (dir, service, pipeline) = try await Self.indexedFixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let container = try ModelContainer.makeTestContainer()
        let made = try Self.date("2026-06-01T09:00:00Z")
        let tagId = UUID()
        let file = try ResearchImportFile(envelope: ResearchDataEnvelope(
            formatVersion: 7, exportedAt: made,
            notes: [ResearchNoteExport(id: UUID(), documentId: "d1", volumeId: "vol1",
                                       bodyText: "Zanzibar was the crux.", projectIds: [], userTagIds: [],
                                       selectedSummaryIds: [], linkedHighlightIds: [], createdAt: made,
                                       lastModified: made)],
            tags: [UserTagExport(id: tagId, name: "Islands", createdAt: made, lastModified: made)],
            tagAssignments: [DocumentTagAssignmentExport(id: UUID(), volumeId: "vol1", documentId: "d1",
                                                         tagId: tagId, createdAt: made)],
            highlights: [], collections: [], prompts: [], projects: [],
            summaries: [GeneratedSummaryExport(id: UUID(), documentId: "d2", volumeId: "vol1",
                                               promptId: UUID(), responseText: "A quokka summary.",
                                               responseFormat: .general, wasChunked: false,
                                               createdAt: made, lastModified: made,
                                               authorship: .aiGenerated, isHeadnoteDraft: false)]))

        _ = try await ResearchDataImporter.importFile(file, mainContext: container.mainContext,
                                                      pipeline: pipeline, settingsSync: nil)

        #expect(try await Self.userTextSearch(service, "zanzibar", notes: true) == ["d1"])
        #expect(try await Self.userTextSearch(service, "quokka", notes: false) == ["d2"])
        let tagged = try pipeline.documentsWithUserTagIds()
        #expect(tagged.map(\.documentId) == ["d1"] && tagged.first?.userTagIds == tagId.uuidString)
    }

    /// A real index over two documents, as `NoteTextPerDocumentTests` builds one.
    private static func indexedFixture() async throws
        -> (dir: URL, service: SearchService, pipeline: IndexingPipeline) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSImport-\(UUID().uuidString)", isDirectory: true)
        let volumes = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        try Data("""
            <?xml version="1.0" encoding="UTF-8"?>
            <TEI xmlns="http://www.tei-c.org/ns/1.0">
            <teiHeader><fileDesc><titleStmt><title>Test Volume</title></titleStmt>
            <publicationStmt><p>Test</p></publicationStmt>
            <sourceDesc><p>Test</p></sourceDesc></fileDesc></teiHeader>
            <text><body>
            <div type="document" xml:id="d1"><head>1. Memorandum</head><p>The first body.</p></div>
            <div type="document" xml:id="d2"><head>2. Telegram</head><p>The second body.</p></div>
            </body></text></TEI>
            """.utf8).write(to: volumes.appendingPathComponent("vol1.xml"))
        let database = dir.appendingPathComponent("test.sqlite")
        let fts5 = try FTS5Store(databaseURL: database)
        let pipeline = try IndexingPipeline(fts5Store: fts5, databaseURL: database,
                                            volumesDirectory: volumes, concurrencyLimit: 1)
        try await pipeline.indexVolume("vol1")
        return (dir, SearchService(fts5Store: fts5, pipeline: pipeline), pipeline)
    }

    /// The documents a search of the reader's notes, or of the summaries, finds for `keywords`.
    private static func userTextSearch(_ service: SearchService, _ keywords: String,
                                       notes: Bool) async throws -> Set<String> {
        var parameters = SearchParameters(keywords: keywords)
        parameters.includeDocumentText = false
        parameters.includeSummaries = !notes
        parameters.includeNotes = notes
        return Set(try await service.search(parameters: parameters, limit: 100).map(\.documentId))
    }

    // MARK: - The screen's words

    /// The report names a file a later build wrote, one no build wrote, and one that is not an
    /// export, each in its own words.
    @Test("Each file the import cannot read is named for what it is")
    func eachProblemIsNamed() {
        let newer = ResearchImportCopy.problem(ResearchImportFile.FormatError.newerFormatVersion(9))
        #expect(newer.contains("9") && newer.contains("Update the app"))
        let unknown = ResearchImportCopy.problem(ResearchImportFile.FormatError.unknownFormatVersion(0))
        #expect(unknown.contains("no version of FRUS Explorer"))
        let decoding = DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "not JSON"))
        #expect(ResearchImportCopy.problem(decoding).contains("not a research export"))
        #expect(ResearchImportCopy.problem(ResearchDataImporter.ReadError.unreadable("No such file."))
                    .contains("No such file."))
    }

    /// Each type's line gives its non-zero parts, and the whole file's every part.
    @Test("The report's counts read as the plan's")
    func theCountsReadAsThePlans() throws {
        let plan = ResearchImportPlan(file: try Self.file(version: 8), library: ResearchLibrarySnapshot())
        let notes = plan.report.count(of: .researchNote)
        #expect(ResearchImportCopy.counts(notes) == "1 to add")
        #expect(ResearchImportCopy.counts(added: 3, replaced: 0, kept: 2)
                    == "3 to add, 0 to replace, and 2 already here")
        #expect(ResearchImportCopy.olderFileFooter(plan.report) == nil, "a version-8 file carries all")
        // A version-7 file names what L43 added, and nothing earlier.
        let seven = ResearchImportPlan(file: try Self.file(version: 7), library: ResearchLibrarySnapshot())
        #expect(ResearchImportCopy.olderFileFooter(seven.report)?.contains("a collection’s citation style") == true)
        #expect(ResearchImportCopy.olderFileFooter(seven.report)?.contains("a note’s formatting") == false)
        let older = ResearchImportPlan(file: try Self.file(version: 3), library: ResearchLibrarySnapshot())
        #expect(ResearchImportCopy.olderFileFooter(older.report)?.contains("a note’s formatting") == true)
        #expect(ResearchImportCopy.olderFileFooter(older.report)?.contains("Saved Searches") == true)
    }
}

// MARK: - SaveCount

/// Counts `ModelContext.didSave` notifications, which arrive on the thread that saves.
private final class SaveCount: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    /// Counts one save.
    func add() {
        lock.lock()
        count += 1
        lock.unlock()
    }

    /// The saves counted.
    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }
}
