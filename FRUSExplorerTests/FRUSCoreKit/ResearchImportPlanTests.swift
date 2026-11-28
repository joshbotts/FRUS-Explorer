// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif

// MARK: - ResearchImportPlanTests

/// Import from JSON's rules (#1915), over `ResearchDataFixtures`' file of each format version and a
/// file FRUS Explorer Light wrote: a file planned into an empty library adds every record, and a
/// second import of it plans nothing; a newer copy replaces only what its version carries, and an
/// older one replaces nothing; nothing is planned for deletion; a new record takes the app's
/// defaults; what an older file does not say is read as the app reads it; and the web's key is in
/// the report.
///
/// The plans are applied by `ImportTestLibrary`, which writes each item as a host does: an addition's
/// whole record, a replacement's `written(over:)` of the library's copy, and nothing for a record
/// kept. So a rule that a plan states but a host could not apply would fail here too.
///
/// Inside `#expect` a collection is mapped with a closure, never a key path: Xcode's expansion of
/// the macro reads a key path passed to a `rethrows` method as a call that can throw.
///
/// Version history:
///   1.0 — #1915 (L23): initial implementation
@Suite("Research import plan")
struct ResearchImportPlanTests {

    private typealias Plan = ResearchImportPlan

    /// A fixture's id.
    private static func id(_ number: Int) -> UUID {
        ResearchDataFixtures.id(number)
    }

    /// A time, as the fixtures write one.
    private static func date(_ text: String) throws -> Date {
        try #require(ISO8601DateFormatter().date(from: text))
    }

    /// Later than every time a fixture holds.
    private static func later() throws -> Date {
        try date("2026-11-01T00:00:00Z")
    }

    /// The fixture of `version`.
    private static func json(version: Int) throws -> String {
        if version == ResearchDataEnvelope.currentFormatVersion { return ResearchDataFixtures.version8 }
        return try #require(ResearchDataFixtures.earlierVersions.first { $0.version == version }?.json)
    }

    /// The fixture of `version`, read as an import reads a file.
    private static func file(version: Int) throws -> ResearchImportFile {
        try ResearchImportFile(data: Data(try json(version: version).utf8))
    }

    /// The fixture of `version`'s envelope, to change before it is planned.
    private static func envelope(version: Int) throws -> ResearchDataEnvelope {
        try file(version: version).envelope
    }

    /// A library holding the version-7 fixture, imported into an empty one.
    private static func libraryOfVersion7() throws -> ImportTestLibrary {
        var library = ImportTestLibrary()
        library.apply(Plan(file: try file(version: 7), library: ResearchLibrarySnapshot()))
        return library
    }

    /// The records a fixture of `version` holds, by type: one of each type its version carried, with
    /// version 6's second entry (the one with no document) and version 7's five entries and second
    /// summary (the headnote draft).
    private static func fixtureCounts(version: Int) -> [Plan.ModelType: Int] {
        var counts: [Plan.ModelType: Int] = [
            .researchNote: 1, .userTag: 1, .documentTagAssignment: 1, .documentHighlight: 1,
            .collection: 1, .collectionEntry: 1, .summarizationPrompt: 1, .project: 1,
            .generatedSummary: 1,
        ]
        if version >= 3 {
            counts[.readingHistoryEntry] = 1
            counts[.searchHistoryEntry] = 1
            counts[.exportHistoryEntry] = 1
        }
        if version >= 6 {
            counts[.archiveVisitPlan] = 1
            counts[.archiveVisitDocument] = 1
            counts[.archiveVisitTarget] = 1
            counts[.collectionEntry] = 2
        }
        if version >= 7 {
            counts[.collectionEntry] = 5
            counts[.generatedSummary] = 2
            for model: Plan.ModelType in [.savedSearch, .workingCorpus, .customVolumeScope,
                                          .documentClassificationOverride, .personClusterOverride,
                                          .annotationReview, .projectLeadEntry, .syncedPreferences] {
                counts[model] = 1
            }
        }
        return counts
    }

    /// Each type's count adds up: every record of the file is added, replaced, kept, set aside or a
    /// repeat, once.
    private static func expectCountsAddUp(_ report: Plan.Report) {
        for count in report.types {
            #expect(count.inFile == count.added + count.replaced + count.kept + count.setAside
                        + count.repeated, "\(count.model.rawValue)")
        }
        let models = report.types.map(\.model)
        #expect(models == Plan.ModelType.allCases)
    }

    // MARK: - A round trip

    /// Each version's file, planned into an empty library, adds every record it holds, and its
    /// report counts them by type, with the file's version and date.
    @Test("Into an empty library, a file of every version plans each of its records as added",
          arguments: 1...8)
    func everyRecordIsAddedIntoAnEmptyLibrary(version: Int) throws {
        let file = try Self.file(version: version)
        let plan = Plan(file: file, library: ResearchLibrarySnapshot())
        let items = plan.everyItem
        let expected = Self.fixtureCounts(version: version)
        let expectedTotal = expected.values.reduce(0, +)

        #expect(items.count == expectedTotal)
        #expect(items.allSatisfy { $0.action == .add })
        for count in plan.report.types {
            #expect(count.inFile == (expected[count.model] ?? 0), "\(count.model.rawValue)")
            #expect(count.added == count.inFile, "\(count.model.rawValue)")
            #expect(count.replaced == 0 && count.kept == 0 && count.setAside == 0 && count.repeated == 0)
            #expect(count.carried == (version >= count.model.since), "\(count.model.rawValue)")
        }
        #expect(plan.report.formatVersion == version)
        #expect(plan.report.exportedAt == file.envelope.exportedAt)
        #expect(plan.report.webKey == nil, "the app's own file carries no web key")
        #expect(plan.report.added == expectedTotal)
        #expect(plan.report.replaced == 0 && plan.report.kept == 0)
        #expect(plan.formatVersion == version)
        Self.expectCountsAddUp(plan.report)
    }

    /// The same file imported again, into the library the first import left, plans every record
    /// as kept; and so does the file planned against the library an export of it describes.
    @Test("A second import of the same file plans nothing: every record is kept", arguments: 1...8)
    func aSecondImportPlansNothing(version: Int) throws {
        let file = try Self.file(version: version)
        let first = Plan(file: file, library: ResearchLibrarySnapshot())
        var library = ImportTestLibrary()
        library.apply(first)

        let second = Plan(file: file, library: library.snapshot)
        #expect(second.everyItem.count == first.everyItem.count)
        #expect(second.everyItem.allSatisfy { $0.action == .keep })
        #expect(second.report.added == 0 && second.report.replaced == 0)
        #expect(second.report.kept == first.report.added)
        Self.expectCountsAddUp(second.report)

        // A library is unchanged by a plan that keeps everything.
        let before = library
        library.apply(second)
        #expect(library == before)

        let againstAnExport = Plan(file: file, library: ResearchLibrarySnapshot(file.envelope))
        #expect(againstAnExport.everyItem.allSatisfy { $0.action == .keep })
    }

    /// A file of the current version, 8, says everything, so its records are added as the file
    /// writes them: a collection without its entries and a plan without its documents and targets,
    /// which are added as records of their own under their parent. (Version 7's file was the
    /// current one until L43; what it cannot say is `version8FieldsSurviveAVersion7Copy`'s.)
    @Test("A version-8 file's records are added as the file writes them, each child under its parent")
    func aCurrentFileIsAddedAsWritten() throws {
        let envelope = try Self.envelope(version: 8)
        let plan = Plan(file: try ResearchImportFile(envelope: envelope),
                        library: ResearchLibrarySnapshot())
        let collectionsWithoutEntries = envelope.collections.map { collection in
            var copy = collection
            copy.entries = []
            return copy
        }
        let entryParents = envelope.collections.flatMap { collection in
            collection.entries.map { _ in Optional(collection.id) }
        }
        let visitsWithoutChildren = envelope.archiveVisits.map { visit in
            var copy = visit
            copy.documents = []
            copy.targets = []
            return copy
        }

        #expect(plan.notes.map { $0.record } == envelope.notes)
        #expect(plan.collections.map { $0.record } == collectionsWithoutEntries)
        #expect(plan.collectionEntries.map { $0.record } == envelope.collections.flatMap { $0.entries })
        #expect(plan.collectionEntries.map { $0.parentId } == entryParents)
        #expect(plan.projects.map { $0.record } == envelope.projects)
        #expect(plan.summaries.map { $0.record } == envelope.summaries)
        #expect(plan.searchHistory.map { $0.record } == envelope.searchHistory)
        #expect(plan.archiveVisits.map { $0.record } == visitsWithoutChildren)
        #expect(plan.archiveVisitDocuments.map { $0.record }
                    == envelope.archiveVisits.flatMap { $0.documents })
        #expect(plan.archiveVisitTargets.map { $0.record } == envelope.archiveVisits.flatMap { $0.targets })
        #expect(plan.archiveVisitDocuments.map { $0.parentId } == [Self.id(14)])
        #expect(plan.archiveVisitTargets.map { $0.parentId } == [Self.id(14)])
        #expect(plan.notes.map { $0.parentId } == [nil], "only a child names a parent")
        #expect(plan.savedSearches.map { $0.record } == envelope.savedSearches)
        #expect(plan.projectLeads.map { $0.record } == envelope.projectLeads)
        #expect(plan.syncedPreferences?.record == envelope.syncedPreferences.first)
        #expect(plan.report.fieldsNotCarried.isEmpty)
        #expect(Plan.Fields.allCases.allSatisfy { plan.carries($0) })
    }

    // MARK: - Newer wins

    /// An older copy never replaces a newer one, and a copy as new, or one that gives no time, is
    /// kept; a library copy that gives no time is replaced by one that does. One fixture for each
    /// condition the rule tests.
    @Test("A copy older than the library's, as new as it, or with no time is kept; a newer one replaces it")
    func anOlderCopyNeverReplacesANewerOne() throws {
        var envelope = try Self.envelope(version: 7)
        let fileTime = try Self.date("2026-09-01T00:00:00Z")
        let earlier = try Self.date("2026-08-01T00:00:00Z")
        envelope.notes[0].lastModified = fileTime
        let noteId = Self.id(3)

        func action(libraryStamp: Date?, fileNote: ResearchNoteExport? = nil) throws -> Plan.Action? {
            var changed = envelope
            if let fileNote { changed.notes = [fileNote] }
            var snapshot = ResearchLibrarySnapshot()
            snapshot.insert(.researchNote, id: noteId, stamp: libraryStamp)
            return Plan(file: try ResearchImportFile(envelope: changed), library: snapshot)
                .notes.first?.action
        }

        let older = try action(libraryStamp: try Self.date("2026-10-01T00:00:00Z"))
        #expect(older == .keep, "the file's copy is older")
        let asNew = try action(libraryStamp: fileTime)
        #expect(asNew == .keep, "the file's copy is as new")
        let newer = try action(libraryStamp: earlier)
        #expect(newer == .replace, "the file's copy is newer")
        let libraryTimeless = try action(libraryStamp: nil)
        #expect(libraryTimeless == .replace, "the library's copy gives no time")
        var timeless = envelope.notes[0]
        timeless.lastModified = nil
        timeless.createdAt = nil
        let fileTimeless = try action(libraryStamp: nil, fileNote: timeless)
        #expect(fileTimeless == .keep, "a file copy with no time never replaces")
        timeless.createdAt = fileTime
        let madeOnly = try action(libraryStamp: earlier, fileNote: timeless)
        #expect(madeOnly == .replace, "with no modification date, when it was made stands for it")

        // And applied: the library's newer note is as it was.
        var library = try Self.libraryOfVersion7()
        var olderFile = try Self.envelope(version: 7)
        olderFile.notes[0].lastModified = try Self.date("2026-01-01T00:00:00Z")
        olderFile.notes[0].bodyText = "An older text."
        let before = library.notes[noteId]
        let plan = Plan(file: try ResearchImportFile(envelope: olderFile), library: library.snapshot)
        #expect(plan.notes.map { $0.action } == [.keep])
        library.apply(plan)
        #expect(library.notes[noteId] == before)
        #expect(library.notes[noteId]?.bodyText == "Key turning point in the negotiations.")
    }

    /// A newer copy from a version-6 file writes what version 6 carries and keeps what it could not
    /// say: a note's formatting, a collection's settings, an entry's kind and text, a project's
    /// focus.
    @Test("A newer version-6 copy replaces only what version 6 carries, and keeps the library's formatting, settings, kind and focus")
    func aNewerVersion6CopyKeepsWhatVersion6CannotSay() throws {
        var library = try Self.libraryOfVersion7()
        let version7 = library
        var envelope = try Self.envelope(version: 6)
        let later = try Self.later()
        envelope.notes[0].lastModified = later
        envelope.notes[0].projectIds = []
        envelope.collections[0].lastModified = later
        envelope.collections[0].name = "The Paris talks, revisited"
        envelope.collections[0].entries[0].lastModified = later
        envelope.collections[0].entries[0].sortOrder = 9
        envelope.projects[0].lastModified = later
        envelope.projects[0].name = "Détente"

        let plan = Plan(file: try ResearchImportFile(envelope: envelope), library: library.snapshot)
        #expect(plan.notes.map { $0.action } == [.replace])
        #expect(plan.collections.map { $0.action } == [.replace])
        #expect(plan.collectionEntries.map { $0.action } == [.replace, .keep])
        #expect(plan.projects.map { $0.action } == [.replace])
        #expect(plan.report.fieldsNotCarried == [.noteFormatting, .collectionSettings,
                                                 .collectionEntryContent, .projectFocus,
                                                 .collectionCitationStyle, .collectionOpening, .collectionWording,
                                                 .collectionSeeAlso, .entryDateLine, .sectionHeadnoteDefault,
                                                 .headnoteWriter])
        #expect(!plan.carries(.noteFormatting) && plan.carries(.summaryAuthorship))
        library.apply(plan)

        let note = try #require(library.notes[Self.id(3)])
        let noteBefore = try #require(version7.notes[Self.id(3)])
        #expect(note.projectIds == [], "a field version 6 carries is written")
        #expect(note.richText == noteBefore.richText, "the formatting version 6 cannot carry is kept")
        #expect(note.richText != nil)
        #expect(note.lastModified == later)

        let collection = try #require(library.collections[Self.id(6)])
        let collectionBefore = try #require(version7.collections[Self.id(6)])
        #expect(collection.name == "The Paris talks, revisited")
        #expect(collection.subtitle == "The Paris talks")
        #expect(collection.introductionRichText == collectionBefore.introductionRichText)
        #expect(collection.includeColophon == true && collection.summaryPromptId == Self.id(9))
        var settingsOnly = collection
        settingsOnly.name = collectionBefore.name
        settingsOnly.lastModified = collectionBefore.lastModified
        #expect(settingsOnly == collectionBefore, "every setting is the library's")

        let heading = try #require(library.collectionEntries[Self.id(8)])
        #expect(heading.sortOrder == 9)
        #expect(heading.kind == CollectionEntryKind.heading.rawValue, "the library's kind, not inert")
        #expect(heading.text == "Chapter 3" && heading.level == 1)
        #expect(library.collectionEntries.parent(of: Self.id(8)) == Self.id(6))

        let project = try #require(library.projects[Self.id(1)])
        #expect(project.name == "Détente")
        #expect(project.defaultUserTagIds == [Self.id(2)])
        #expect(project.leadAxisWeights == "subject=0.5;person=0.3;crossref=0.2")
    }

    /// A newer copy from a version-7 file says everything, so it writes everything, a field it
    /// leaves empty included.
    @Test("A newer version-7 copy replaces every field, the formatting and settings included")
    func aNewerVersion7CopyReplacesEveryField() throws {
        var library = try Self.libraryOfVersion7()
        var envelope = try Self.envelope(version: 7)
        let later = try Self.later()
        envelope.notes[0].lastModified = later
        envelope.notes[0].richText = nil
        envelope.collections[0].lastModified = later
        envelope.collections[0].subtitle = nil
        envelope.collections[0].includeColophon = false
        envelope.projects[0].lastModified = later
        envelope.projects[0].defaultUserTagIds = []

        library.apply(Plan(file: try ResearchImportFile(envelope: envelope), library: library.snapshot))
        #expect(library.notes[Self.id(3)]?.richText == nil, "version 7 says the note has no formatting")
        #expect(library.collections[Self.id(6)]?.subtitle == nil)
        #expect(library.collections[Self.id(6)]?.includeColophon == false)
        #expect(library.projects[Self.id(1)]?.defaultUserTagIds == [])
    }

    /// A note's formatting is of its text: a version-6 copy that replaces the text cannot keep
    /// formatting made for another, and the note reads as its plain text, as the app's editor
    /// leaves one whose text it replaces.
    @Test("A newer version-6 copy that changes a note's text leaves it plain: the formatting was the old text's")
    func aNewTextFromVersion6LeavesTheNotePlain() throws {
        var library = try Self.libraryOfVersion7()
        var envelope = try Self.envelope(version: 6)
        envelope.notes[0].lastModified = try Self.later()
        envelope.notes[0].bodyText = "A turning point, read again."

        library.apply(Plan(file: try ResearchImportFile(envelope: envelope), library: library.snapshot))
        let note = try #require(library.notes[Self.id(3)])
        #expect(note.bodyText == "A turning point, read again.")
        #expect(note.richText == nil)
    }

    /// A summary's authorship says who wrote its text: a version-4 copy, which names no author,
    /// keeps the library's while the text is the library's, and with a new text reads as the app
    /// reads a summary that names none.
    @Test("A newer version-4 summary keeps the library's authorship for the same text, and reads as AI-generated with a new one")
    func aVersion4SummaryKeepsAuthorshipOnlyForTheSameText() throws {
        let cases: [(text: String, authorship: SummaryAuthorship)] = [
            ("This document discusses...", .aiEdited),
            ("A text written elsewhere.", .aiGenerated),
        ]
        for (text, authorship) in cases {
            var library = try Self.libraryOfVersion7()
            var envelope = try Self.envelope(version: 4)
            envelope.summaries[0].lastModified = try Self.later()
            envelope.summaries[0].responseText = text
            let plan = Plan(file: try ResearchImportFile(envelope: envelope), library: library.snapshot)
            #expect(plan.summaries.map { $0.action } == [.replace])
            library.apply(plan)
            let summary = try #require(library.summaries[Self.id(10)])
            #expect(summary.responseText == text)
            #expect(summary.authorship == authorship, "\(text)")
            #expect(summary.isHeadnoteDraft == false)
        }
    }

    /// A version-3 copy of a recorded search keeps the capture provenance version 4 added.
    @Test("A newer version-3 search keeps the library's capture provenance")
    func aVersion3SearchKeepsItsProvenance() throws {
        var library = try Self.libraryOfVersion7()
        let before = try #require(library.searchHistory[Self.id(12)])
        var envelope = try Self.envelope(version: 3)
        envelope.searchHistory[0].executedAt = try Self.later()
        envelope.searchHistory[0].resultCount = 4

        library.apply(Plan(file: try ResearchImportFile(envelope: envelope), library: library.snapshot))
        let search = try #require(library.searchHistory[Self.id(12)])
        #expect(search.resultCount == 4)
        #expect(search.fetchLimit == 7500 && search.indexedVolumeCount == 553)
        #expect(search.renderedExpression == before.renderedExpression)
        #expect(search.scopeSignature == "text+summaries+notes")
    }

    // MARK: - No deletions

    /// A plan holds the file's records alone: a record the library holds and the file lacks is
    /// in no item, an import has no way to delete one, and after it the library holds every record
    /// it held.
    @Test("Nothing is planned for deletion: a record the file lacks is in no item, and stays")
    func nothingIsPlannedForDeletion() throws {
        #expect(Plan.Action.allCases == [.add, .replace, .keep])
        var library = try Self.libraryOfVersion7()
        let before = library
        let version1 = try Self.file(version: 1)
        let plan = Plan(file: version1, library: library.snapshot)

        let fileKeys = Set(ResearchLibrarySnapshot(version1.envelope).everyKey)
        let plannedKeys = Set(plan.everyItem.map { $0.key })
        #expect(plannedKeys == fileKeys)
        #expect(!plannedKeys.contains("SavedSearch/\(Self.id(22).uuidString)"),
                "a saved search, which version 1 cannot carry")
        library.apply(plan)
        #expect(library.snapshot.everyKey == before.snapshot.everyKey)
        #expect(library.savedSearches[Self.id(22)] == before.savedSearches[Self.id(22)])
        #expect(library.syncedPreferences == before.syncedPreferences)
    }

    // MARK: - Defaults

    /// A new record from a file before the version that added a field takes the app's default
    /// for it: no formatting, the default settings and entry fields, no focus, AI authorship, no
    /// capture provenance.
    @Test("A new record from an older file takes the app's defaults for what its version cannot carry",
          arguments: 1...6)
    func aNewRecordTakesTheDefaults(version: Int) throws {
        let plan = Plan(file: try Self.file(version: version), library: ResearchLibrarySnapshot())

        #expect(plan.notes.first?.record.richText == nil)

        let collection = try #require(plan.collections.first?.record)
        #expect(collection.subtitle == nil && collection.authorLine == nil)
        #expect(collection.introductionText == nil && collection.introductionRichText == nil)
        #expect(collection.includeColophon == false && collection.includeProjectProvenance == false)
        #expect(collection.includeMethodAppendix == false)
        #expect(collection.defaultBodyDepth == "full" && collection.footnoteStyle == "all")
        #expect(collection.includeFootnotes == nil && collection.includeSourceNote == nil)
        #expect(collection.tocStyle == "citation" && collection.applyHighlights == false)
        #expect(collection.includeNotes == true && collection.includeWordCloud == false)
        #expect(collection.defaultIncludeHeadnote == false && collection.summaryPromptId == nil)

        let document = try #require(plan.collectionEntries.first { $0.record.id == Self.id(7) }?.record)
        #expect(document.kind == CollectionEntryKind.document.rawValue)
        #expect(document.level == 1 && document.selectedHighlightIds == [])
        #expect(document.text == nil && document.richText == nil && document.titleOverride == nil)
        #expect(document.excerptStart == nil && document.generatedBlockType == nil)
        #expect(document.includeHeadnote == nil && document.headnoteSummaryId == nil)
        #expect(document.researchNoteId == Self.id(3), "what version 1 carries is the file's")

        let project = try #require(plan.projects.first?.record)
        #expect(project.defaultUserTagIds == [] && project.leadAxisWeights == nil)

        let summary = try #require(plan.summaries.first?.record)
        #expect(summary.authorship == (version >= 5 ? .aiEdited : .aiGenerated))
        #expect(summary.isHeadnoteDraft == false)

        if version >= 3 {
            let search = try #require(plan.searchHistory.first?.record)
            #expect((search.fetchLimit != nil) == (version >= 4))
            #expect((search.renderedExpression != nil) == (version >= 4))
            #expect(search.resultCount == 0)
        }
        #expect(plan.report.fieldsNotCarried.contains(.summaryAuthorship) == (version < 5))
        #expect(plan.report.fieldsNotCarried.contains(.searchCaptureProvenance) == (version < 4))
        #expect(plan.report.summariesWithoutAuthorship == (version < 5 ? 1 : 0))
    }

    // MARK: - Version 8 (L43)

    /// A newer copy from a version-7 file cannot say a collection's own facts, an entry's date line or section
    /// headnote default, or a headnote's writer, so a replacement keeps the library's: an older file never blanks
    /// what it could not say. A version-8 copy writes them all, a cleared one included.
    @Test("A newer version-7 copy keeps the library's version-8 fields; a newer version-8 copy writes them")
    func version8FieldsSurviveAVersion7Copy() throws {
        var library = ImportTestLibrary()
        library.apply(Plan(file: try Self.file(version: 8), library: ResearchLibrarySnapshot()))
        let later = try Self.later()

        var older = try Self.envelope(version: 7)
        older.collections[0].lastModified = later
        older.collections[0].name = "Renamed by an older file"
        for index in older.collections[0].entries.indices { older.collections[0].entries[index].lastModified = later }
        older.summaries[1].lastModified = later
        let plan = Plan(file: try ResearchImportFile(envelope: older), library: library.snapshot)
        #expect(plan.collections.map(\.action) == [.replace])
        #expect(plan.report.fieldsNotCarried.suffix(7) == [.collectionCitationStyle, .collectionOpening,
                                                          .collectionWording, .collectionSeeAlso, .entryDateLine,
                                                          .sectionHeadnoteDefault, .headnoteWriter])
        library.apply(plan)
        let collection = try #require(library.collections[Self.id(6)])
        #expect(collection.name == "Renamed by an older file", "what version 7 carries is written")
        #expect(collection.citationStyle == "chicago" && collection.opening == "volumeHeading")
        #expect(collection.labelsJSON?.contains("Commentary") == true)
        #expect(collection.defaultIncludeRelatedDocuments == true)
        #expect(library.collectionEntries[Self.id(7)]?.dateLine == "Paris, 27 January 1973")
        #expect(library.collectionEntries[Self.id(8)]?.headnoteDefault == true)
        #expect(library.summaries[Self.id(21)]?.writerName == "A. Researcher", "the same text keeps its writer")

        // A version-7 copy with a new text cannot say who wrote it: the writer goes with the old text.
        var rewritten = try Self.envelope(version: 7)
        rewritten.summaries[1].lastModified = try Self.date("2026-12-01T00:00:00Z")
        rewritten.summaries[1].responseText = "Another text."
        library.apply(Plan(file: try ResearchImportFile(envelope: rewritten), library: library.snapshot))
        #expect(library.summaries[Self.id(21)]?.writerName == nil)

        // A newer version-8 copy says everything, a cleared field included.
        var newer = try Self.envelope(version: 8)
        newer.collections[0].lastModified = try Self.date("2026-12-02T00:00:00Z")
        newer.collections[0].citationStyle = nil
        newer.collections[0].defaultIncludeRelatedDocuments = false
        library.apply(Plan(file: try ResearchImportFile(envelope: newer), library: library.snapshot))
        #expect(library.collections[Self.id(6)]?.citationStyle == nil)
        #expect(library.collections[Self.id(6)]?.defaultIncludeRelatedDocuments == false)
    }

    /// A new record from a file before version 8 takes the app's defaults for the fields version 8 added: no style,
    /// opening or words of its own, See also off, no date line, no section headnote default and no writer.
    @Test("A new record from a version-7 file takes the defaults for what version 8 added")
    func aNewRecordFromVersion7TakesTheVersion8Defaults() throws {
        let plan = Plan(file: try Self.file(version: 7), library: ResearchLibrarySnapshot())
        let collection = try #require(plan.collections.first?.record)
        #expect(collection.citationStyle == nil && collection.opening == nil && collection.labelsJSON == nil)
        #expect(collection.defaultIncludeRelatedDocuments == false)
        #expect(plan.collectionEntries.allSatisfy { $0.record.dateLine == nil && $0.record.headnoteDefault == nil })
        #expect(plan.summaries.allSatisfy { $0.record.writerName == nil })
        let fromVersion8 = Plan(file: try Self.file(version: 8), library: ResearchLibrarySnapshot())
        #expect(fromVersion8.collections.first?.record.citationStyle == "chicago")
        #expect(fromVersion8.summaries.last?.record.writerName == "A. Researcher")
    }

    // MARK: - What an older file does not say

    /// Before version 7 the flag is read from the prompt every draft carries; from version 7 the
    /// file says it, whatever the prompt.
    @Test("Before version 7 a summary is a headnote draft by its prompt; from version 7 as the file says")
    func aHeadnoteDraftIsReadFromItsPromptBeforeVersion7() throws {
        var envelope = try Self.envelope(version: 6)
        var draft = envelope.summaries[0]
        draft.id = Self.id(40)
        draft.promptId = GeneratedSummaryExport.headnoteDraftPromptId
        envelope.summaries.append(draft)
        let version6 = Plan(file: try ResearchImportFile(envelope: envelope),
                            library: ResearchLibrarySnapshot())
        #expect(version6.summaries.map { $0.record.isHeadnoteDraft } == [false, true])
        #expect(version6.report.headnoteDrafts == 1)

        // Version 7's draft carries an ordinary prompt and says it is a draft.
        var version7Envelope = try Self.envelope(version: 7)
        #expect(version7Envelope.summaries[1].promptId != GeneratedSummaryExport.headnoteDraftPromptId)
        var notADraft = version7Envelope.summaries[0]
        notADraft.id = Self.id(41)
        notADraft.promptId = GeneratedSummaryExport.headnoteDraftPromptId
        notADraft.isHeadnoteDraft = false
        version7Envelope.summaries.append(notADraft)
        let version7 = Plan(file: try ResearchImportFile(envelope: version7Envelope),
                            library: ResearchLibrarySnapshot())
        #expect(version7.summaries.map { $0.record.isHeadnoteDraft } == [false, true, false])
        #expect(version7.report.headnoteDrafts == 1)
    }

    /// Version 6 wrote a heading, a prose block and an apparatus block as an entry with no document,
    /// and did not say which: added, it is inert; replacing, it keeps the library's kind.
    @Test("Before version 7 an entry with no document is added inert, and a replacement keeps the library's kind")
    func anEntryWithNoDocumentIsAddedInert() throws {
        let added = Plan(file: try Self.file(version: 6), library: ResearchLibrarySnapshot())
        #expect(added.collectionEntries.map { $0.record.kind }
                    == [CollectionEntryKind.unrecognized.rawValue, CollectionEntryKind.document.rawValue])
        #expect(added.report.inertEntries == 1)

        var library = try Self.libraryOfVersion7()
        var envelope = try Self.envelope(version: 6)
        envelope.collections[0].entries[0].lastModified = try Self.later()
        let replaced = Plan(file: try ResearchImportFile(envelope: envelope), library: library.snapshot)
        #expect(replaced.collectionEntries.map { $0.action } == [.replace, .keep])
        #expect(replaced.report.inertEntries == 0, "only an entry the import adds is made inert")
        library.apply(replaced)
        #expect(library.collectionEntries[Self.id(8)]?.kind == CollectionEntryKind.heading.rawValue)

        // A later file that names no kind is read by the same rule.
        var version7 = try Self.envelope(version: 7)
        version7.collections[0].entries[0].kind = nil
        version7.collections[0].entries[1].kind = nil
        let unnamed = Plan(file: try ResearchImportFile(envelope: version7), library: ResearchLibrarySnapshot())
        #expect(unnamed.collectionEntries.prefix(2).map { $0.record.kind }
                    == [CollectionEntryKind.unrecognized.rawValue, CollectionEntryKind.document.rawValue])
    }

    /// The link is the file's, kept even when its search is nowhere; the report names a collection
    /// the import writes whose search neither the library nor the file holds, and no other.
    @Test("A collection's saved search is kept as the file names it, and the report names it when neither side holds the search")
    func aCollectionKeepsItsSavedSearch() throws {
        let missing = Self.id(77)
        func plan(naming search: UUID, libraryHolds: Bool = false,
                  libraryNewer: Bool = false) throws -> Plan {
            var envelope = try Self.envelope(version: 7)
            envelope.collections[0].savedSearchId = search
            var snapshot = ResearchLibrarySnapshot()
            if libraryHolds { snapshot.insert(.savedSearch, id: search, stamp: nil) }
            if libraryNewer { snapshot.insert(.collection, id: Self.id(6), stamp: try Self.later()) }
            return Plan(file: try ResearchImportFile(envelope: envelope), library: snapshot)
        }

        let unlinked = try plan(naming: missing)
        #expect(unlinked.collections.first?.record.savedSearchId == missing)
        #expect(unlinked.report.unlinkedCollections
                    == [Plan.UnlinkedCollection(id: Self.id(6), name: "Vietnam Negotiations",
                                                savedSearchId: missing)])
        let inTheFile = try plan(naming: Self.id(22))
        #expect(inTheFile.report.unlinkedCollections.isEmpty, "the file holds it")
        let inTheLibrary = try plan(naming: missing, libraryHolds: true)
        #expect(inTheLibrary.report.unlinkedCollections.isEmpty, "the library holds it")
        let kept = try plan(naming: missing, libraryNewer: true)
        #expect(kept.report.unlinkedCollections.isEmpty, "a collection the import keeps is not its doing")
    }

    /// Of two sets of synced preferences, the earliest made is read, of two made at once the first,
    /// and the rest set aside; the library's set is the earliest it holds.
    @Test("Of two sets of synced preferences the earliest made is read and the other set aside")
    func theEarliestSetOfPreferencesIsRead() throws {
        var envelope = try Self.envelope(version: 7)
        let first = envelope.syncedPreferences[0]
        var second = first
        second.createdAt = try Self.date("2026-05-01T00:00:00Z")
        second.citationStyleRaw = "mla"
        envelope.syncedPreferences = [first, second]

        let plan = Plan(file: try ResearchImportFile(envelope: envelope), library: ResearchLibrarySnapshot())
        #expect(plan.syncedPreferences?.record.citationStyleRaw == "mla", "the earliest made")
        let count = plan.report.count(of: .syncedPreferences)
        #expect(count.inFile == 2 && count.added == 1 && count.setAside == 1)

        var tie = first
        tie.citationStyleRaw = "apa"
        envelope.syncedPreferences = [first, tie]
        let tied = Plan(file: try ResearchImportFile(envelope: envelope), library: ResearchLibrarySnapshot())
        #expect(tied.syncedPreferences?.record.citationStyleRaw == "chicago", "of two at once, the first")

        // The library's set is its earliest made: newer than it, the file's set replaces it.
        var library = ResearchLibrarySnapshot()
        let libraryStamp = try Self.date("2026-02-01T00:00:00Z")
        library.insertSyncedPreferences(createdAt: try Self.date("2026-07-01T00:00:00Z"),
                                        updatedAt: try Self.later())
        library.insertSyncedPreferences(createdAt: try Self.date("2026-01-01T00:00:00Z"),
                                        updatedAt: libraryStamp)
        envelope.syncedPreferences = [first]
        let replaced = Plan(file: try ResearchImportFile(envelope: envelope), library: library)
        #expect(replaced.syncedPreferences?.action == .replace)
        #expect(library.syncedPreferencesStamp == libraryStamp)
        #expect(library.count(of: .syncedPreferences) == 1)
    }

    /// The two corrections are the researcher's own in the app, so they are planned as any record.
    @Test("Classification and person corrections are planned as any record: the researcher's own")
    func correctionsAreImported() throws {
        let plan = Plan(file: try Self.file(version: 7), library: ResearchLibrarySnapshot())
        #expect(plan.classificationOverrides.map { $0.action } == [.add])
        #expect(plan.personClusterOverrides.map { $0.action } == [.add])
        #expect(plan.report.count(of: .documentClassificationOverride).setAside == 0)
        #expect(plan.report.count(of: .personClusterOverride).setAside == 0)
    }

    // MARK: - A file the web edition wrote

    /// FRUS Explorer Light writes the envelope with its key beside it: the file imports as the app's
    /// own does, and the key is in the report.
    @Test("A file FRUS Explorer Light wrote imports, and its key is in the report")
    func aWebFileImportsWithItsKey() throws {
        #expect(ResearchDataFixtures.webEditionVersion7 != ResearchDataFixtures.version7)
        let web = try ResearchImportFile(data: Data(ResearchDataFixtures.webEditionVersion7.utf8))
        let app = try ResearchImportFile(data: Data(ResearchDataFixtures.version7.utf8))
        let key = ResearchImportFile.WebKey(formatVersion: 1, includesGeneratedSummaries: true,
                                            includesCorrections: true)
        #expect(web.webKey == key)
        #expect(app.webKey == nil)
        #expect(web.envelope == app.envelope, "the key is beside the envelope, not in it")

        let plan = Plan(file: web, library: ResearchLibrarySnapshot())
        let fixtureTotal = Self.fixtureCounts(version: 7).values.reduce(0, +)
        #expect(plan.report.webKey == key)
        #expect(plan.report.added == fixtureTotal)
        #expect(plan.everyItem.allSatisfy { $0.action == .add })

        // The report reads back as it was written, the key in it.
        let encoded = try ResearchDataEnvelope.makeEncoder().encode(plan.report)
        let decoded = try ResearchDataEnvelope.makeDecoder().decode(Plan.Report.self, from: encoded)
        #expect(decoded == plan.report)
    }

    /// The envelope's decoder has always passed the key over; one an import cannot read is passed
    /// over too, rather than refusing a file the app can read.
    @Test("A web key that cannot be read is passed over, and the file still imports")
    func anUnreadableWebKeyIsPassedOver() throws {
        let unreadable = ResearchDataFixtures.version7.replacingOccurrences(
            of: "\n  \"formatVersion\" : 7,\n",
            with: "\n  \"formatVersion\" : 7,\n  \"frusExplorerLight\" : \"a later shape\",\n")
        #expect(unreadable != ResearchDataFixtures.version7)
        let file = try ResearchImportFile(data: Data(unreadable.utf8))
        #expect(file.webKey == nil)
        let plan = Plan(file: file, library: ResearchLibrarySnapshot())
        #expect(plan.report.added > 0)
    }

    // MARK: - The file

    /// A file a later build wrote is refused with the reason, whether or not it decodes as this
    /// build's; a version no build wrote is refused; a file that is not an export fails to decode.
    @Test("A file of a later format version is refused, whether or not it decodes, and so is one of no version")
    func aLaterFormatVersionIsRefused() throws {
        let version9 = ResearchDataFixtures.version8.replacingOccurrences(
            of: "\"formatVersion\" : 8,", with: "\"formatVersion\" : 9,")
        #expect(throws: ResearchImportFile.FormatError.newerFormatVersion(9)) {
            try ResearchImportFile(data: Data(version9.utf8))
        }
        let laterShape = #"{ "formatVersion" : 10, "notes" : { "shape" : "of a later build" } }"#
        #expect(throws: ResearchImportFile.FormatError.newerFormatVersion(10)) {
            try ResearchImportFile(data: Data(laterShape.utf8))
        }
        let version0 = ResearchDataFixtures.version1.replacingOccurrences(
            of: "\"formatVersion\" : 1,", with: "\"formatVersion\" : 0,")
        #expect(throws: ResearchImportFile.FormatError.unknownFormatVersion(0)) {
            try ResearchImportFile(data: Data(version0.utf8))
        }
        #expect(throws: DecodingError.self) {
            try ResearchImportFile(data: Data("[]".utf8))
        }
        #expect(ResearchImportFile.supportedFormatVersions == 1...8)
    }

    /// The same record twice in one file is planned once: the newer copy in the first one's place,
    /// or of two as new the first.
    @Test("A record the file gives twice is planned once: the newer copy, or of two as new the first")
    func aRepeatedRecordIsPlannedOnce() throws {
        var envelope = try Self.envelope(version: 7)
        var newer = envelope.notes[0]
        newer.bodyText = "The newer copy."
        newer.lastModified = try Self.later()
        var tag = envelope.tags[0]
        tag.name = "A copy as new"
        envelope.notes.append(newer)
        envelope.tags.append(tag)

        let plan = Plan(file: try ResearchImportFile(envelope: envelope), library: ResearchLibrarySnapshot())
        #expect(plan.notes.map { $0.record.bodyText } == ["The newer copy."])
        #expect(plan.tags.map { $0.record.name } == ["Primary Source"])
        let notes = plan.report.count(of: .researchNote)
        #expect(notes.inFile == 2 && notes.added == 1 && notes.repeated == 1)
        Self.expectCountsAddUp(plan.report)
    }

    // MARK: - The library

    /// A record stored as copies under one id is held at the copy the app reads, the one last
    /// changed; a copy with no time counts as the oldest; and the library tells "holds a record
    /// with no time" from "holds none".
    @Test("A library's copies under one id are held at the latest stamp, and one with none counts as the oldest")
    func copiesUnderOneIdAreHeldAtTheLatest() throws {
        let noteId = Self.id(3)
        let earlier = try Self.date("2026-06-01T00:00:00Z")
        let latest = try Self.date("2026-07-01T00:00:00Z")
        var snapshot = ResearchLibrarySnapshot()
        snapshot.insert(.researchNote, id: noteId, stamp: nil)
        #expect(snapshot.holds(.researchNote, id: noteId))
        #expect(snapshot.stamp(of: .researchNote, id: noteId) == nil)
        snapshot.insert(.researchNote, id: noteId, stamp: earlier)
        snapshot.insert(.researchNote, id: noteId, stamp: latest)
        snapshot.insert(.researchNote, id: noteId, stamp: earlier)
        snapshot.insert(.researchNote, id: noteId, stamp: nil)
        #expect(snapshot.stamp(of: .researchNote, id: noteId) == latest)
        #expect(snapshot.count(of: .researchNote) == 1)
        #expect(snapshot.ids(of: .researchNote) == [noteId])
        #expect(!snapshot.holds(.userTag, id: noteId), "a type's ids are its own")
        #expect(!snapshot.holdsSyncedPreferences && snapshot.syncedPreferencesStamp == nil)
    }

    /// Each type's stamp is the date the web edition's import compares: the modification date,
    /// else when it was made; the event's time for the trail and the ledger; a lead's last run.
    @Test("Each type's stamp is its modification date, else when it was made, or its own event's time")
    func eachTypesStamp() throws {
        let envelope = try Self.envelope(version: 7)
        #expect(envelope.notes[0].importStamp == envelope.notes[0].lastModified)
        var made = envelope.notes[0]
        made.lastModified = nil
        #expect(made.importStamp == made.createdAt)
        #expect(envelope.highlights[0].importStamp == envelope.highlights[0].createdAt)
        #expect(envelope.tagAssignments[0].importStamp == envelope.tagAssignments[0].createdAt)
        #expect(envelope.readingHistory[0].importStamp == envelope.readingHistory[0].accessedAt)
        #expect(envelope.searchHistory[0].importStamp == envelope.searchHistory[0].executedAt)
        #expect(envelope.exportHistory[0].importStamp == envelope.exportHistory[0].exportedAt)
        #expect(envelope.annotationReviews[0].importStamp == envelope.annotationReviews[0].reviewedAt)
        #expect(envelope.projectLeads[0].importStamp == envelope.projectLeads[0].lastComputedAt)
        #expect(envelope.syncedPreferences[0].importStamp == envelope.syncedPreferences[0].updatedAt)
        #expect(envelope.classificationOverrides[0].importStamp
                    == envelope.classificationOverrides[0].createdAt)
        #expect(envelope.personClusterOverrides[0].importStamp == envelope.personClusterOverrides[0].createdAt)
        #expect(Plan.ModelType.allCases.count == 23)
        let fieldModels = Plan.Fields.allCases.map(\.model)
        #expect(fieldModels == [.researchNote, .collection, .collectionEntry, .project,
                                .searchHistoryEntry, .generatedSummary,
                                // Version 8's (L43).
                                .collection, .collection, .collection, .collection,
                                .collectionEntry, .collectionEntry, .generatedSummary])
    }
}

// MARK: - The plan's items, for counting

/// One item of a plan, as a test counts it.
private struct PlannedRecord: Equatable {
    /// The record's type.
    let model: ResearchImportPlan.ModelType
    /// Its id; `nil` for the synced preferences.
    let id: UUID?
    /// What the import does with it.
    let action: ResearchImportPlan.Action

    /// The record's type and id, as `ResearchLibrarySnapshot.everyKey` writes them.
    var key: String {
        "\(model.rawValue)/\(id?.uuidString ?? "")"
    }
}

extension ResearchImportPlan {

    /// Every item, type by type in the plan's order.
    fileprivate var everyItem: [PlannedRecord] {
        func rows<Record>(_ items: [Item<Record>], _ id: KeyPath<Record, UUID>) -> [PlannedRecord] {
            items.map { PlannedRecord(model: Record.importModel, id: $0.record[keyPath: id],
                                      action: $0.action) }
        }
        var all = rows(notes, \.id) + rows(tags, \.id) + rows(tagAssignments, \.id)
        all += rows(highlights, \.id) + rows(collections, \.id) + rows(collectionEntries, \.id)
        all += rows(prompts, \.id) + rows(projects, \.id) + rows(summaries, \.id)
        all += rows(readingHistory, \.id) + rows(searchHistory, \.id) + rows(exportHistory, \.id)
        all += rows(archiveVisits, \.id) + rows(archiveVisitDocuments, \.id)
        all += rows(archiveVisitTargets, \.id) + rows(savedSearches, \.id)
        all += rows(workingCorpora, \.id) + rows(customVolumeScopes, \.id)
        all += rows(classificationOverrides, \.id) + rows(personClusterOverrides, \.id)
        all += rows(annotationReviews, \.id) + rows(projectLeads, \.id)
        if let preferences = syncedPreferences {
            all.append(PlannedRecord(model: .syncedPreferences, id: nil, action: preferences.action))
        }
        return all
    }
}

extension ResearchLibrarySnapshot {

    /// Every record the library holds, as its type and id, sorted, for comparing two libraries.
    fileprivate var everyKey: [String] {
        let records = ResearchImportPlan.ModelType.allCases.flatMap { model in
            ids(of: model).map { "\(model.rawValue)/\($0.uuidString)" }
        }
        return (records + (holdsSyncedPreferences ? ["SyncedPreferences/"] : [])).sorted()
    }
}

// MARK: - ImportTestLibrary

/// A library as a host that applies a plan keeps one: each type's records, as their items were
/// written. An addition writes the item's record, a replacement `written(over:)` of the library's
/// copy, and a record kept nothing.
private struct ImportTestLibrary: Equatable {
    var notes = ImportTestStore<ResearchNoteExport>(id: \.id)
    var tags = ImportTestStore<UserTagExport>(id: \.id)
    var tagAssignments = ImportTestStore<DocumentTagAssignmentExport>(id: \.id)
    var highlights = ImportTestStore<DocumentHighlightExport>(id: \.id)
    var collections = ImportTestStore<CollectionExport>(id: \.id)
    var collectionEntries = ImportTestStore<CollectionEntryExport>(id: \.id)
    var prompts = ImportTestStore<SummarizationPromptExport>(id: \.id)
    var projects = ImportTestStore<ProjectExport>(id: \.id)
    var summaries = ImportTestStore<GeneratedSummaryExport>(id: \.id)
    var readingHistory = ImportTestStore<ReadingHistoryEntryExport>(id: \.id)
    var searchHistory = ImportTestStore<SearchHistoryEntryExport>(id: \.id)
    var exportHistory = ImportTestStore<ExportHistoryEntryExport>(id: \.id)
    var archiveVisits = ImportTestStore<ArchiveVisitPlanExport>(id: \.id)
    var archiveVisitDocuments = ImportTestStore<ArchiveVisitDocumentExport>(id: \.id)
    var archiveVisitTargets = ImportTestStore<ArchiveVisitTargetExport>(id: \.id)
    var savedSearches = ImportTestStore<SavedSearchExport>(id: \.id)
    var workingCorpora = ImportTestStore<WorkingCorpusExport>(id: \.id)
    var customVolumeScopes = ImportTestStore<CustomVolumeScopeExport>(id: \.id)
    var classificationOverrides = ImportTestStore<DocumentClassificationOverrideExport>(id: \.id)
    var personClusterOverrides = ImportTestStore<PersonClusterOverrideExport>(id: \.id)
    var annotationReviews = ImportTestStore<AnnotationReviewExport>(id: \.id)
    var projectLeads = ImportTestStore<ProjectLeadEntryExport>(id: \.id)
    var syncedPreferences: SyncedPreferencesExport?

    /// Writes `plan`'s items.
    mutating func apply(_ plan: ResearchImportPlan) {
        notes.apply(plan.notes)
        tags.apply(plan.tags)
        tagAssignments.apply(plan.tagAssignments)
        highlights.apply(plan.highlights)
        collections.apply(plan.collections)
        collectionEntries.apply(plan.collectionEntries)
        prompts.apply(plan.prompts)
        projects.apply(plan.projects)
        summaries.apply(plan.summaries)
        readingHistory.apply(plan.readingHistory)
        searchHistory.apply(plan.searchHistory)
        exportHistory.apply(plan.exportHistory)
        archiveVisits.apply(plan.archiveVisits)
        archiveVisitDocuments.apply(plan.archiveVisitDocuments)
        archiveVisitTargets.apply(plan.archiveVisitTargets)
        savedSearches.apply(plan.savedSearches)
        workingCorpora.apply(plan.workingCorpora)
        customVolumeScopes.apply(plan.customVolumeScopes)
        classificationOverrides.apply(plan.classificationOverrides)
        personClusterOverrides.apply(plan.personClusterOverrides)
        annotationReviews.apply(plan.annotationReviews)
        projectLeads.apply(plan.projectLeads)
        if let item = plan.syncedPreferences {
            switch item.action {
            case .add:
                syncedPreferences = item.record
            case .replace:
                guard let current = syncedPreferences else {
                    Issue.record("a replacement of synced preferences the library does not hold")
                    return
                }
                syncedPreferences = item.written(over: current)
            case .keep:
                break
            }
        }
    }

    /// What the library holds, as an import compares it.
    var snapshot: ResearchLibrarySnapshot {
        var snapshot = ResearchLibrarySnapshot()
        notes.insert(into: &snapshot)
        tags.insert(into: &snapshot)
        tagAssignments.insert(into: &snapshot)
        highlights.insert(into: &snapshot)
        collections.insert(into: &snapshot)
        collectionEntries.insert(into: &snapshot)
        prompts.insert(into: &snapshot)
        projects.insert(into: &snapshot)
        summaries.insert(into: &snapshot)
        readingHistory.insert(into: &snapshot)
        searchHistory.insert(into: &snapshot)
        exportHistory.insert(into: &snapshot)
        archiveVisits.insert(into: &snapshot)
        archiveVisitDocuments.insert(into: &snapshot)
        archiveVisitTargets.insert(into: &snapshot)
        savedSearches.insert(into: &snapshot)
        workingCorpora.insert(into: &snapshot)
        customVolumeScopes.insert(into: &snapshot)
        classificationOverrides.insert(into: &snapshot)
        personClusterOverrides.insert(into: &snapshot)
        annotationReviews.insert(into: &snapshot)
        projectLeads.insert(into: &snapshot)
        if let preferences = syncedPreferences {
            snapshot.insertSyncedPreferences(createdAt: preferences.createdAt,
                                             updatedAt: preferences.updatedAt)
        }
        return snapshot
    }
}

/// One type's records in an `ImportTestLibrary`, in the order they were added, each with its parent.
private struct ImportTestStore<Record: ResearchImportRecord>: Equatable {

    /// One record and its parent.
    struct Stored: Equatable {
        /// The record.
        var record: Record
        /// Its collection's or plan's id, for a child.
        var parentId: UUID?
    }

    /// A record's id.
    let id: KeyPath<Record, UUID>

    /// The records.
    private(set) var stored: [Stored] = []

    /// An empty store of records identified by `id`.
    init(id: KeyPath<Record, UUID>) {
        self.id = id
    }

    /// The record with `key`, or `nil`.
    subscript(_ key: UUID) -> Record? {
        stored.first { $0.record[keyPath: id] == key }?.record
    }

    /// The parent of the record with `key`.
    func parent(of key: UUID) -> UUID? {
        stored.first { $0.record[keyPath: id] == key }?.parentId
    }

    /// Writes `items` as a host does.
    mutating func apply(_ items: [ResearchImportPlan.Item<Record>]) {
        for item in items {
            let key = item.record[keyPath: id]
            switch item.action {
            case .add:
                stored.append(Stored(record: item.record, parentId: item.parentId))
            case .replace:
                guard let index = stored.firstIndex(where: { $0.record[keyPath: id] == key }) else {
                    Issue.record("a replacement of a record the library does not hold")
                    continue
                }
                stored[index].record = item.written(over: stored[index].record)
                stored[index].parentId = item.parentId
            case .keep:
                break
            }
        }
    }

    /// Records each record in `snapshot`.
    func insert(into snapshot: inout ResearchLibrarySnapshot) {
        for entry in stored {
            snapshot.insert(Record.importModel, id: entry.record[keyPath: id],
                            stamp: entry.record.importStamp)
        }
    }
}

#if !SWIFT_PACKAGE // the app's models
// MARK: - ResearchImportDefaultsTests

/// The defaults a new record takes for what its file's version cannot carry are the app's models'
/// own: each record the plan resolves from a file before the version that added a field equals, in
/// that field, a fresh model's, mapped as the app's exporter maps it.
///
/// Version history:
///   1.0 — #1915 (L23): initial implementation
@Suite("Research import plan: the app's defaults")
struct ResearchImportDefaultsTests {

    /// A new collection, entry, project, note, summary and search, against the plan's defaults.
    @Test("A new record from an older file takes a fresh model's own values for what its version cannot carry")
    func theDefaultsAreTheModelsOwn() {
        let collection = Collection(name: "A collection")
        let fresh = CollectionExport(collection, entries: [])
        let resolved = CollectionExport(id: collection.id, name: collection.name, projectIds: [],
                                        entries: []).resolvedForImport(fromFormatVersion: 6)
        #expect(resolved.subtitle == fresh.subtitle && resolved.authorLine == fresh.authorLine)
        #expect(resolved.introductionText == fresh.introductionText)
        #expect(resolved.introductionRichText == fresh.introductionRichText)
        #expect(resolved.includeColophon == fresh.includeColophon)
        #expect(resolved.includeProjectProvenance == fresh.includeProjectProvenance)
        #expect(resolved.includeMethodAppendix == fresh.includeMethodAppendix)
        #expect(resolved.defaultBodyDepth == fresh.defaultBodyDepth)
        #expect(resolved.footnoteStyle == fresh.footnoteStyle)
        #expect(resolved.includeFootnotes == fresh.includeFootnotes)
        #expect(resolved.includeSourceNote == fresh.includeSourceNote)
        #expect(resolved.tocStyle == fresh.tocStyle && resolved.applyHighlights == fresh.applyHighlights)
        #expect(resolved.includeNotes == fresh.includeNotes)
        #expect(resolved.includeWordCloud == fresh.includeWordCloud)
        #expect(resolved.defaultIncludeHeadnote == fresh.defaultIncludeHeadnote)
        #expect(resolved.summaryPromptId == fresh.summaryPromptId)

        let entry = CollectionEntry(collectionId: collection.id, documentId: "d1",
                                    volumeId: "frus1969-76v01", sortOrder: 0)
        var freshEntry = CollectionEntryExport(entry)
        let resolvedEntry = CollectionEntryExport(id: entry.id, documentId: "d1", volumeId: "frus1969-76v01",
                                                  sortOrder: 0, selectedNoteIds: [])
            .resolvedForImport(fromFormatVersion: 6)
        freshEntry.createdAt = nil
        freshEntry.lastModified = nil
        #expect(resolvedEntry == freshEntry, "every field of a new entry, its kind, level and overrides")

        let project = Project(name: "A project")
        let resolvedProject = ProjectExport(id: project.id, name: project.name, defaultSubjectTagIds: [],
                                            defaultCountryTagIds: []).resolvedForImport(fromFormatVersion: 6)
        #expect(resolvedProject.defaultUserTagIds == project.defaultUserTagIds)
        #expect(resolvedProject.leadAxisWeights == project.leadAxisWeights)

        let note = ResearchNote(documentId: "d1", volumeId: "frus1969-76v01")
        let resolvedNote = ResearchNoteExport(id: note.id, documentId: "d1", volumeId: "frus1969-76v01",
                                              bodyText: "", projectIds: [], userTagIds: [],
                                              selectedSummaryIds: [], linkedHighlightIds: [],
                                              richText: Data("{\\rtf1 }".utf8))
            .resolvedForImport(fromFormatVersion: 6)
        #expect(resolvedNote.richText == note.richText)

        let summary = GeneratedSummary(documentId: "d1", volumeId: "frus1969-76v01", promptId: UUID(),
                                       responseText: "A summary.")
        let resolvedSummary = GeneratedSummaryExport(id: summary.id, documentId: "d1",
                                                     volumeId: "frus1969-76v01", promptId: summary.promptId,
                                                     responseText: "A summary.", responseFormat: .general,
                                                     wasChunked: false)
            .resolvedForImport(fromFormatVersion: 4)
        #expect(resolvedSummary.authorship == summary.authorship)
        #expect(resolvedSummary.isHeadnoteDraft == summary.isHeadnoteDraft)

        let search = SearchHistoryEntry(queryText: "détente")
        let resolvedSearch = SearchHistoryEntryExport(id: search.id, queryText: "détente", resultCount: 0,
                                                      fetchLimit: 7500, renderedExpression: "détente")
            .resolvedForImport(fromFormatVersion: 3)
        #expect(resolvedSearch.loadedCount == search.loadedCount && resolvedSearch.matchCount == search.matchCount)
        #expect(resolvedSearch.fetchLimit == search.fetchLimit)
        #expect(resolvedSearch.indexedVolumeCount == search.indexedVolumeCount)
        #expect(resolvedSearch.scopeSignature == search.scopeSignature)
        #expect(resolvedSearch.appliedCorpusId == search.appliedCorpusId)
        #expect(resolvedSearch.renderedExpression == search.renderedExpression)
    }
}
#endif
