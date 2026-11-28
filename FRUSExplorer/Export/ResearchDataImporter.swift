// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// Import from JSON's app half (#1915, L24). FRUSCoreKit decides what a file does to a library
// (`ResearchImportFile`, `ResearchLibrarySnapshot`, `ResearchImportPlan`, L23); this file writes the
// plan into the app's SwiftData store and brings everything a save of those records updates up to
// date, the search index's user half among them. The screen is `ResearchDataImportView.swift`.

// MARK: - ResearchDataImporter

/// Imports a research data export: reads the file, plans it against the library, writes the plan in
/// batches, and runs what a save of each written type runs (#1915, L24).
///
/// ## Where the writes are saved, and the dates they keep
/// The plan is written on a context of its own (`ModelContext(container)`), never the app's main
/// context, so `ModelModificationStamper`, which observes the main context alone, never re-dates
/// what the import writes. A record the import replaces keeps the file's `lastModified`, as FRUS
/// Explorer Light's import keeps it. That date is what "a newer copy wins" compares, so it has to be
/// the copy's own: dated by the import, a restored copy would outrank every later edit of the record
/// made before the import, in a second import and in a merge of copies alike. A second import of the
/// same file therefore finds every record as new as its own and plans nothing.
///
/// The one exception is the synced preferences, which have no id: their item is written on the main
/// context, which `SettingsSyncCoordinator` reads, after the rest (``writeSyncedPreferences(_:in:)``).
/// The stamper does not stamp them (`SyncedPreferences` keeps `updatedAt`, not `lastModified`).
///
/// ## Batches
/// ``ResearchImportWriter`` saves every `batchSize` records and pauses between batches, so the
/// screen draws its progress and the main context merges each batch, as it merges a CloudKit import.
/// A batch saved is kept whatever happens after it: an import stopped part-way leaves its saved
/// batches, and importing the file again adds the rest and keeps the rest.
///
/// Version history:
///   1.0 — #1915 (L24): initial implementation
@MainActor
enum ResearchDataImporter {

    /// Records written between two saves. Measured on the Mac in L24's walk; the log entry has the
    /// figures.
    static let batchSize = 500

    /// Reads and decodes the file the reader picked, through the kit's tolerant decoder.
    ///
    /// Off the main actor: a large export takes a moment to decode. A URL from `fileImporter` is
    /// security-scoped on iOS and in the Mac's sandbox, so it is opened for the read and closed after.
    ///
    /// - Parameter url: The file.
    /// - Throws: ``ReadError`` when the file cannot be read, and `ResearchImportFile`'s errors when it
    ///   is not an export of a version this build reads.
    nonisolated static func readFile(at url: URL) throws -> ResearchImportFile {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let data: Data
        do {
            data = try Data(contentsOf: url, options: .mappedIfSafe)
        } catch {
            throw ReadError.unreadable(error.localizedDescription)
        }
        return try ResearchImportFile(data: data)
    }

    /// A file the importer could not read.
    enum ReadError: Error, Equatable {
        /// The file could not be opened or read; the system's description.
        case unreadable(String)
    }

    /// What the library holds, as the plan compares it with a file: every record's id and stamp,
    /// read from an export of the library with its summaries, as the plan reads the file's, and the
    /// standard prompts, which an export leaves out but the library holds.
    ///
    /// - Parameter context: The context to read.
    /// - Returns: The snapshot.
    static func snapshot(of context: ModelContext) throws -> ResearchLibrarySnapshot {
        var snapshot = ResearchLibrarySnapshot(try ResearchDataExporter.makeEnvelope(
            modelContext: context, includeGeneratedSummaries: true))
        // The export writes the researcher's own prompts alone (`ResearchLibrarySnapshot.init(_:)`
        // says so), so a file's prompt that shares a standard prompt's id is never planned as new.
        for prompt in try context.fetch(FetchDescriptor<SummarizationPrompt>()) where prompt.isStandard {
            snapshot.insert(.summarizationPrompt, id: prompt.id,
                            stamp: prompt.lastModified ?? prompt.createdAt)
        }
        return snapshot
    }

    /// Plans `file` against the library as it is saved now: the main context is saved first, so the
    /// plan sees an edit the reader has not yet saved, and the library is read on a context of the
    /// import's own, the one the plan is then written on.
    ///
    /// - Parameters:
    ///   - file: The file.
    ///   - mainContext: The app's main context.
    /// - Returns: The plan, and the context it was made on.
    static func plan(_ file: ResearchImportFile,
                     mainContext: ModelContext) throws -> (plan: ResearchImportPlan, context: ModelContext) {
        try mainContext.save()
        let context = ModelContext(mainContext.container)
        let plan = ResearchImportPlan(file: file, library: try snapshot(of: context))
        return (plan, context)
    }

    /// Imports `file`: plans it against the library as it is now (which the report the reader saw
    /// was made from moments before), writes the plan in batches, writes the synced preferences,
    /// and runs the passes a save of each written type runs (``refresh(after:container:pipeline:settingsSync:)``).
    ///
    /// - Parameters:
    ///   - file: The file.
    ///   - mainContext: The app's main context.
    ///   - pipeline: The search index, or `nil` when it is not open; the launch's replay then
    ///     brings the index up to the imported records instead.
    ///   - settingsSync: The settings sync coordinator, which applies imported synced preferences
    ///     when this device syncs settings.
    ///   - batchSize: Records written between two saves.
    ///   - progress: Called after each batch with the records written and the records to write.
    /// - Returns: What the import did.
    static func importFile(_ file: ResearchImportFile,
                           mainContext: ModelContext,
                           pipeline: IndexingPipeline?,
                           settingsSync: SettingsSyncCoordinator?,
                           batchSize: Int = ResearchDataImporter.batchSize,
                           progress: (_ written: Int, _ total: Int) -> Void = { _, _ in }) async throws
        -> ResearchImportOutcome {
        let (plan, context) = try plan(file, mainContext: mainContext)
        let writer = ResearchImportWriter(context: context)
        try await writer.write(plan, batchSize: batchSize, progress: progress)
        var outcome = writer.outcome
        if let item = plan.syncedPreferences, try writeSyncedPreferences(item, in: mainContext) {
            outcome.record(item.action, of: .syncedPreferences)
        }
        outcome.kept = plan.report.kept
        outcome.reviewLedgerChanged = await refresh(after: outcome.writtenTypes,
                                                    container: mainContext.container,
                                                    pipeline: pipeline, settingsSync: settingsSync)
        return outcome
    }

    /// Writes the plan's synced preferences, the one type with no id, on `context`, the main
    /// context, which `SettingsSyncCoordinator` reads: an addition as a new set, and a replacement
    /// over the set the app reads, the earliest made.
    ///
    /// A replacement keeps that set's `createdAt`. The set has no id, and the earliest made is the
    /// one the app reads (`SettingsSyncCoordinator.resolveCanonical`), which deletes the rest when it
    /// next reads them; written with a later file's `createdAt`, the replaced set could stop being
    /// the earliest and be deleted as a duplicate, taking the import with it.
    ///
    /// - Parameters:
    ///   - item: The plan's item.
    ///   - context: The main context.
    /// - Returns: Whether anything was written.
    @discardableResult
    static func writeSyncedPreferences(_ item: ResearchImportPlan.Item<SyncedPreferencesExport>,
                                       in context: ModelContext) throws -> Bool {
        switch item.action {
        case .keep:
            return false
        case .add:
            let preferences = SyncedPreferences()
            preferences.writeImport(item.record)
            context.insert(preferences)
        case .replace:
            let sets = try context.fetch(FetchDescriptor<SyncedPreferences>(
                sortBy: [SortDescriptor(\.createdAt)]))
            if let current = sets.first {
                var written = item.written(over: SyncedPreferencesExport(current))
                written.createdAt = current.createdAt
                current.writeImport(written)
            } else {
                let preferences = SyncedPreferences()
                preferences.writeImport(item.record)
                context.insert(preferences)
            }
        }
        try context.save()
        return true
    }

    /// What a save of each written type runs, after an import: the search index's user half (note
    /// text, summary text, the tag column and the tag names), the two corrections, the review
    /// ledger, and this device's settings. Each is the app's own pass, value-guarded and idempotent.
    ///
    /// The note and tag passes write only; their sweeps, which clear rows no record accounts for,
    /// are the launch's and the CloudKit import-settle's, since an import deletes nothing.
    ///
    /// - Parameters:
    ///   - written: The types the import wrote.
    ///   - container: The model container.
    ///   - pipeline: The search index, or `nil` when it is not open.
    ///   - settingsSync: The settings sync coordinator.
    /// - Returns: Whether the review ledger changed what a reader shows, for
    ///   `AppState.revisionReviewToken`.
    @discardableResult
    static func refresh(after written: Set<ResearchImportPlan.ModelType>,
                        container: ModelContainer,
                        pipeline: IndexingPipeline?,
                        settingsSync: SettingsSyncCoordinator?) async -> Bool {
        // Lets the main context merge the import's last batch before anything reads it.
        await Task.yield()
        if written.contains(.syncedPreferences) {
            // A pull now, not at the next foreground: the coordinator pushes this device's settings
            // up at its next change of any setting, which would write them over the imported set.
            settingsSync?.syncNowIfEnabled()
        }
        guard let pipeline else { return false }
        if written.contains(.researchNote) {
            await ResearchNote.reconcileNoteText(container: container, pipeline: pipeline,
                                                 sweepingStaleRows: false)
        }
        if written.contains(.generatedSummary) {
            await GeneratedSummary.reconcileSummaryText(container: container, pipeline: pipeline)
        }
        if written.contains(.documentTagAssignment) {
            await DocumentTagAssignment.reconcileTagColumn(container: container, pipeline: pipeline,
                                                           sweepingStaleRows: false)
        }
        if written.contains(.userTag) {
            // Every tag, wholesale, as the launch mirrors them (W-19 row L-3).
            let tags = (try? ModelContext(container).fetch(FetchDescriptor<UserTag>())) ?? []
            try? await pipeline.replaceUserTagNames(tags.map { (id: $0.id.uuidString, name: $0.name) })
        }
        if written.contains(.documentClassificationOverride) {
            let overrides = DocumentClassificationOverrideStore.snapshot(context: ModelContext(container))
            try? await pipeline.applyClassificationOverrides(overrides)
        }
        if written.contains(.personClusterOverride) {
            let overrides = PersonClusterOverrideStore.snapshot(context: ModelContext(container))
            try? await pipeline.consolidatePersonRollup(overrides: overrides, forceReload: false)
        }
        if written.contains(.annotationReview) {
            return await AnnotationReviewStore.reconcile(container: container, pipeline: pipeline)
                .changedAnything
        }
        return false
    }
}

// MARK: - ResearchImportOutcome

/// What an import did, for the line the screen shows when it is done (#1915, L24).
///
/// Version history:
///   1.0 — #1915 (L24): initial implementation
struct ResearchImportOutcome: Equatable, Sendable {

    /// Records written as new.
    var added = 0

    /// Records whose newer copy was written over the library's.
    var replaced = 0

    /// Records the library held as new or newer, which were left as they were.
    var kept = 0

    /// Notes whose text a file before format version 7 replaced, and whose formatting went with it:
    /// such a file cannot carry formatting, and a note's formatting is the formatting of its text.
    var notesMadePlain = 0

    /// Summaries whose text a file before format version 5 replaced, and which read as AI-generated
    /// since: such a file cannot say who wrote a summary.
    var summariesMadeAIGenerated = 0

    /// The types the import wrote, which decide the passes after it.
    var writtenTypes: Set<ResearchImportPlan.ModelType> = []

    /// Whether the review ledger's pass changed what a reader shows, so the caller bumps
    /// `AppState.revisionReviewToken`, as the launch's pass does.
    var reviewLedgerChanged = false

    /// Counts one written record.
    mutating func record(_ action: ResearchImportPlan.Action, of model: ResearchImportPlan.ModelType) {
        switch action {
        case .add: added += 1
        case .replace: replaced += 1
        case .keep: return
        }
        writtenTypes.insert(model)
    }
}

// MARK: - ResearchImportWriter

/// Writes a plan's records into one context, a batch at a time (#1915, L24): for an addition, the
/// whole of the item's record into a new model, its id included; for a replacement, the item's
/// record written over the library's copy (`Item.written(over:)`) into every stored copy of it, as an
/// edit is written to each (`ResearchNote.copies(of:in:)`); for a record kept, nothing. A collection
/// entry and an archive visit's document and target join the parent the item names.
///
/// Version history:
///   1.0 — #1915 (L24): initial implementation
@MainActor
final class ResearchImportWriter {

    /// The context the plan is written on, never the main context (``ResearchDataImporter``).
    let context: ModelContext

    /// What has been written so far.
    private(set) var outcome = ResearchImportOutcome()

    /// The plan's format version, set by ``write(_:batchSize:pause:progress:)``.
    private var formatVersion = ResearchDataEnvelope.currentFormatVersion

    /// By model type, the library's records by id, every stored copy, read once when a type is
    /// first written.
    private var stored: [ObjectIdentifier: Any] = [:]

    /// A writer over `context`.
    init(context: ModelContext) {
        self.context = context
    }

    /// Writes every addition and replacement in `plan`, saving after every `batchSize` of them and
    /// pausing after each save. The synced preferences are not among them
    /// (``ResearchDataImporter/writeSyncedPreferences(_:in:)``).
    ///
    /// - Parameters:
    ///   - plan: The plan, made on this writer's context.
    ///   - batchSize: Records written between two saves.
    ///   - pause: Awaited after each save: a short sleep, so the screen draws and the main context
    ///     merges the batch.
    ///   - progress: Called after each save with the records written and the records to write.
    func write(_ plan: ResearchImportPlan, batchSize: Int = ResearchDataImporter.batchSize,
               pause: () async -> Void = { try? await Task.sleep(for: .milliseconds(10)) },
               progress: (_ written: Int, _ total: Int) -> Void = { _, _ in }) async throws {
        formatVersion = plan.formatVersion
        let steps = self.steps(plan)
        var written = 0
        progress(0, steps.count)
        for start in stride(from: 0, to: steps.count, by: max(1, batchSize)) {
            for step in steps[start..<min(start + max(1, batchSize), steps.count)] {
                step()
            }
            try context.save()
            written = min(start + max(1, batchSize), steps.count)
            progress(written, steps.count)
            await pause()
        }
    }

    /// One write for each addition and replacement, parents before their children: the plan lists
    /// a collection before its entries and an archive visit before its documents and targets.
    private func steps(_ plan: ResearchImportPlan) -> [() -> Void] {
        var steps: [() -> Void] = []
        func add<Model: ResearchImportable>(_ items: [ResearchImportPlan.Item<Model.ImportRecord>],
                                            as model: Model.Type,
                                            parent: ((Model, UUID) -> Void)? = nil) {
            for item in items where item.action != .keep {
                steps.append { [unowned self] in self.write(item, as: model, parent: parent) }
            }
        }
        add(plan.tags, as: UserTag.self)
        add(plan.notes, as: ResearchNote.self)
        add(plan.tagAssignments, as: DocumentTagAssignment.self)
        add(plan.highlights, as: DocumentHighlight.self)
        add(plan.prompts, as: SummarizationPrompt.self)
        add(plan.projects, as: Project.self)
        add(plan.collections, as: Collection.self)
        add(plan.collectionEntries, as: CollectionEntry.self) { [unowned self] entry, collectionId in
            entry.collectionId = collectionId
            if entry.collection?.id != collectionId {
                entry.collection = self.copyTheAppReads(of: collectionId, as: Collection.self)
            }
        }
        add(plan.summaries, as: GeneratedSummary.self)
        add(plan.readingHistory, as: ReadingHistoryEntry.self)
        add(plan.searchHistory, as: SearchHistoryEntry.self)
        add(plan.exportHistory, as: ExportHistoryEntry.self)
        add(plan.archiveVisits, as: ArchiveVisitPlan.self)
        add(plan.archiveVisitDocuments, as: ArchiveVisitDocument.self) { [unowned self] document, planId in
            document.planId = planId
            if document.plan?.id != planId {
                document.plan = self.copyTheAppReads(of: planId, as: ArchiveVisitPlan.self)
            }
        }
        add(plan.archiveVisitTargets, as: ArchiveVisitTarget.self) { [unowned self] target, planId in
            target.planId = planId
            if target.plan?.id != planId {
                target.plan = self.copyTheAppReads(of: planId, as: ArchiveVisitPlan.self)
            }
        }
        add(plan.savedSearches, as: SavedSearch.self)
        add(plan.workingCorpora, as: WorkingCorpus.self)
        add(plan.customVolumeScopes, as: CustomVolumeScope.self)
        add(plan.classificationOverrides, as: DocumentClassificationOverride.self)
        add(plan.personClusterOverrides, as: PersonClusterOverride.self)
        add(plan.annotationReviews, as: AnnotationReview.self)
        add(plan.projectLeads, as: ProjectLeadEntry.self)
        return steps
    }

    /// Writes one item: an addition as a new model, a replacement into every stored copy. A record
    /// the plan replaces but the library no longer holds (deleted since the plan) is added, as an
    /// import brings back what was deleted.
    private func write<Model: ResearchImportable>(_ item: ResearchImportPlan.Item<Model.ImportRecord>,
                                                  as model: Model.Type,
                                                  parent: ((Model, UUID) -> Void)?) {
        let id = item.record.id
        let copies = item.action == .replace ? storedCopies(of: id, as: model) : []
        guard let current = Self.copyTheAppReads(copies) else {
            let created = Model.newForImport(item.record)
            context.insert(created)
            if let parentId = item.parentId { parent?(created, parentId) }
            remember(created)
            outcome.record(.add, of: Model.ImportRecord.importModel)
            return
        }
        let before = current.importRecord
        let written = item.written(over: before)
        for copy in copies {
            copy.writeImport(written)
            if let parentId = item.parentId { parent?(copy, parentId) }
        }
        countTextChange(from: before, to: written)
        outcome.record(.replace, of: Model.ImportRecord.importModel)
    }

    /// Counts a note made plain and a summary made AI-generated by an older file's new text: what
    /// `Item.written(over:)` decides, and only a write can see.
    private func countTextChange<Record: IdentifiedImportRecord>(from before: Record, to written: Record) {
        if let before = before as? ResearchNoteExport, let written = written as? ResearchNoteExport,
           formatVersion < ResearchImportPlan.Fields.noteFormatting.since,
           before.richText != nil, written.richText == nil {
            outcome.notesMadePlain += 1
        }
        if let before = before as? GeneratedSummaryExport,
           let written = written as? GeneratedSummaryExport,
           formatVersion < ResearchImportPlan.Fields.summaryAuthorship.since,
           (before.authorship ?? .aiGenerated) != .aiGenerated, written.authorship == .aiGenerated {
            outcome.summariesMadeAIGenerated += 1
        }
    }

    /// Every stored copy of the record `id` of `model`, the type read whole the first time.
    private func storedCopies<Model: ResearchImportable>(of id: UUID, as model: Model.Type) -> [Model] {
        table(of: model)[id] ?? []
    }

    /// The copy the app reads of the record `id` of `model`: the one last changed
    /// (``copyTheAppReads(_:)``), or `nil` when the library holds none.
    private func copyTheAppReads<Model: ResearchImportable>(of id: UUID, as model: Model.Type) -> Model? {
        Self.copyTheAppReads(table(of: model)[id] ?? [])
    }

    /// Of `copies`, the one the app reads: the one last changed, and of copies changed at the same
    /// moment, or of a type that records no change, the first, as `DuplicateCopies.oneEach` keeps
    /// one copy of each record.
    static func copyTheAppReads<Model: ResearchImportable>(_ copies: [Model]) -> Model? {
        var kept: Model?
        for copy in copies {
            guard let current = kept else {
                kept = copy
                continue
            }
            if (copy.importCopyDate ?? .distantPast) > (current.importCopyDate ?? .distantPast) {
                kept = copy
            }
        }
        return kept
    }

    /// The library's records of `model` by id, read once.
    private func table<Model: ResearchImportable>(of model: Model.Type) -> [UUID: [Model]] {
        let key = ObjectIdentifier(model)
        if let table = stored[key] as? [UUID: [Model]] { return table }
        let all = (try? context.fetch(FetchDescriptor<Model>())) ?? []
        let table = Dictionary(grouping: all, by: \.importId)
        stored[key] = table
        return table
    }

    /// Adds a new model to its type's table, once the table has been read, so a later child finds
    /// a parent the import added.
    private func remember<Model: ResearchImportable>(_ model: Model) {
        let key = ObjectIdentifier(Model.self)
        guard var table = stored[key] as? [UUID: [Model]] else { return }
        table[model.importId, default: []].append(model)
        stored[key] = table
    }
}

// MARK: - ResearchImportable

/// A record of an export that names its id: every one but the synced preferences.
protocol IdentifiedImportRecord: ResearchImportRecord {
    /// The record's id, the model's own.
    var id: UUID { get }
}

extension ResearchNoteExport: IdentifiedImportRecord {}
extension UserTagExport: IdentifiedImportRecord {}
extension DocumentTagAssignmentExport: IdentifiedImportRecord {}
extension DocumentHighlightExport: IdentifiedImportRecord {}
extension CollectionExport: IdentifiedImportRecord {}
extension CollectionEntryExport: IdentifiedImportRecord {}
extension SummarizationPromptExport: IdentifiedImportRecord {}
extension ProjectExport: IdentifiedImportRecord {}
extension GeneratedSummaryExport: IdentifiedImportRecord {}
extension ReadingHistoryEntryExport: IdentifiedImportRecord {}
extension SearchHistoryEntryExport: IdentifiedImportRecord {}
extension ExportHistoryEntryExport: IdentifiedImportRecord {}
extension ArchiveVisitPlanExport: IdentifiedImportRecord {}
extension ArchiveVisitDocumentExport: IdentifiedImportRecord {}
extension ArchiveVisitTargetExport: IdentifiedImportRecord {}
extension SavedSearchExport: IdentifiedImportRecord {}
extension WorkingCorpusExport: IdentifiedImportRecord {}
extension CustomVolumeScopeExport: IdentifiedImportRecord {}
extension DocumentClassificationOverrideExport: IdentifiedImportRecord {}
extension PersonClusterOverrideExport: IdentifiedImportRecord {}
extension AnnotationReviewExport: IdentifiedImportRecord {}
extension ProjectLeadEntryExport: IdentifiedImportRecord {}

/// A model Import from JSON writes (#1915, L24): how its record becomes a model, and the model its
/// record again, as the export maps it (`ResearchDataExporter.swift`, "The records the models map
/// to").
///
/// `writeImport(_:)` writes every field the record carries and leaves the rest as they are: a
/// model's own fields no export carries (a summary's `sourceContentHash`, a prompt's `isStandard`,
/// an archive visit row's `stateData`) keep the library's value in a replacement and the model's
/// default in an addition. The dates are written last.
///
/// Version history:
///   1.0 — #1915 (L24): initial implementation
protocol ResearchImportable: PersistentModel {
    /// The type's record in the export.
    associatedtype ImportRecord: IdentifiedImportRecord

    /// The record's id, the model's `id`.
    var importId: UUID { get }

    /// When this copy was last changed, for choosing the copy the app reads among copies stored
    /// under one id; `nil` for a type that records no change.
    var importCopyDate: Date? { get }

    /// A new model holding the whole of `record`, its id included.
    static func newForImport(_ record: ImportRecord) -> Self

    /// Writes every field `record` carries into this model, the dates last.
    func writeImport(_ record: ImportRecord)

    /// The model as its record, as the export writes it: the library's copy that
    /// `Item.written(over:)` is given. A collection's entries and an archive visit's documents and
    /// targets are left out: an import writes them as records of their own.
    var importRecord: ImportRecord { get }
}

extension ResearchNote: ResearchImportable {
    var importId: UUID { id }
    var importCopyDate: Date? { lastModified }
    static func newForImport(_ record: ResearchNoteExport) -> ResearchNote {
        let note = ResearchNote(documentId: record.documentId, volumeId: record.volumeId)
        note.writeImport(record)
        return note
    }
    func writeImport(_ record: ResearchNoteExport) {
        id = record.id
        documentId = record.documentId
        volumeId = record.volumeId
        bodyText = record.bodyText
        richText = record.richText
        projectIds = record.projectIds
        userTagIds = record.userTagIds
        selectedSummaryIds = record.selectedSummaryIds
        // The highlights a note links are the highlights' own `noteId`, written with them.
        createdAt = record.createdAt
        lastModified = record.lastModified
    }
    var importRecord: ResearchNoteExport { ResearchNoteExport(self, linkedHighlightIds: []) }
}

extension UserTag: ResearchImportable {
    var importId: UUID { id }
    var importCopyDate: Date? { lastModified }
    static func newForImport(_ record: UserTagExport) -> UserTag {
        let tag = UserTag(name: record.name)
        tag.writeImport(record)
        return tag
    }
    func writeImport(_ record: UserTagExport) {
        id = record.id
        name = record.name
        createdAt = record.createdAt
        lastModified = record.lastModified
    }
    var importRecord: UserTagExport { UserTagExport(self) }
}

extension DocumentTagAssignment: ResearchImportable {
    var importId: UUID { id }
    var importCopyDate: Date? { nil }
    static func newForImport(_ record: DocumentTagAssignmentExport) -> DocumentTagAssignment {
        let assignment = DocumentTagAssignment(volumeId: record.volumeId, documentId: record.documentId,
                                               tagId: record.tagId)
        assignment.writeImport(record)
        return assignment
    }
    func writeImport(_ record: DocumentTagAssignmentExport) {
        id = record.id
        volumeId = record.volumeId
        documentId = record.documentId
        tagId = record.tagId
        createdAt = record.createdAt
    }
    var importRecord: DocumentTagAssignmentExport { DocumentTagAssignmentExport(self) }
}

extension DocumentHighlight: ResearchImportable {
    var importId: UUID { id }
    var importCopyDate: Date? { nil }
    static func newForImport(_ record: DocumentHighlightExport) -> DocumentHighlight {
        let highlight = DocumentHighlight(volumeId: record.volumeId, documentId: record.documentId,
                                          startOffset: record.startOffset, endOffset: record.endOffset,
                                          renderingVersion: record.renderingVersion)
        highlight.writeImport(record)
        return highlight
    }
    func writeImport(_ record: DocumentHighlightExport) {
        id = record.id
        volumeId = record.volumeId
        documentId = record.documentId
        startOffset = record.startOffset
        endOffset = record.endOffset
        colorTag = record.colorTag
        noteId = record.noteId
        selectedText = record.selectedText
        renderingVersion = record.renderingVersion
        createdAt = record.createdAt
    }
    var importRecord: DocumentHighlightExport { DocumentHighlightExport(self) }
}

extension Collection: ResearchImportable {
    var importId: UUID { id }
    var importCopyDate: Date? { lastModified }
    static func newForImport(_ record: CollectionExport) -> Collection {
        let collection = Collection(name: record.name)
        collection.writeImport(record)
        return collection
    }
    func writeImport(_ record: CollectionExport) {
        id = record.id
        name = record.name
        note = record.note
        projectIds = record.projectIds
        savedSearchId = record.savedSearchId
        subtitle = record.subtitle
        authorLine = record.authorLine
        introductionText = record.introductionText
        introductionRichText = record.introductionRichText
        // The plan resolves each setting the model keeps without an optional, so `nil` here would
        // be a record no plan makes: the model's value is left as it is.
        if let value = record.includeColophon { includeColophon = value }
        if let value = record.includeProjectProvenance { includeProjectProvenance = value }
        if let value = record.includeMethodAppendix { includeMethodAppendix = value }
        if let value = record.defaultBodyDepth { defaultBodyDepth = value }
        if let value = record.footnoteStyle { footnoteStyle = value }
        includeFootnotes = record.includeFootnotes
        includeSourceNote = record.includeSourceNote
        if let value = record.tocStyle { tocStyle = value }
        if let value = record.applyHighlights { applyHighlights = value }
        if let value = record.includeNotes { includeNotes = value }
        if let value = record.includeWordCloud { includeWordCloud = value }
        if let value = record.defaultIncludeHeadnote { defaultIncludeHeadnote = value }
        summaryPromptId = record.summaryPromptId
        // The collection's own facts (format version 8, L43). From an older file the plan has already given a
        // replacement the library's values and a new record the defaults, so nothing here writes a blank over a value.
        citationStyle = record.citationStyle
        opening = record.opening
        labelsJSON = record.labelsJSON
        if let value = record.defaultIncludeRelatedDocuments { defaultIncludeRelatedDocuments = value }
        // The entries are records of their own (`ResearchImportPlan.collectionEntries`).
        createdAt = record.createdAt
        lastModified = record.lastModified
    }
    var importRecord: CollectionExport { CollectionExport(self, entries: []) }
}

extension CollectionEntry: ResearchImportable {
    var importId: UUID { id }
    var importCopyDate: Date? { lastModified }
    static func newForImport(_ record: CollectionEntryExport) -> CollectionEntry {
        // The collection is the item's parent, which the writer joins.
        let entry = CollectionEntry(collectionId: UUID(), documentId: record.documentId,
                                    volumeId: record.volumeId, sortOrder: record.sortOrder)
        entry.writeImport(record)
        return entry
    }
    func writeImport(_ record: CollectionEntryExport) {
        id = record.id
        documentId = record.documentId
        volumeId = record.volumeId
        sortOrder = record.sortOrder
        researchNoteId = record.researchNoteId
        selectedNoteIds = record.selectedNoteIds
        if let value = record.kind { kind = value }
        if let value = record.level { level = value }
        text = record.text
        richText = record.richText
        excerptStart = record.excerptStart
        excerptEnd = record.excerptEnd
        excerptRenderingVersion = record.excerptRenderingVersion
        excerptColorTag = record.excerptColorTag
        generatedBlockType = record.generatedBlockType
        titleOverride = record.titleOverride
        bodyDepthOverride = record.bodyDepthOverride
        applyHighlightsOverride = record.applyHighlightsOverride
        includeNotesOverride = record.includeNotesOverride
        includeSourceNoteOverride = record.includeSourceNoteOverride
        includeFootnotesOverride = record.includeFootnotesOverride
        summaryPromptIdOverride = record.summaryPromptIdOverride
        if let value = record.selectedHighlightIds { selectedHighlightIds = value }
        includeRelatedDocuments = record.includeRelatedDocuments
        includeHeadnote = record.includeHeadnote
        headnoteSummaryId = record.headnoteSummaryId
        // The entry's own facts (format version 8, L43).
        dateLine = record.dateLine
        headnoteDefault = record.headnoteDefault
        createdAt = record.createdAt
        lastModified = record.lastModified
    }
    var importRecord: CollectionEntryExport { CollectionEntryExport(self) }
}

extension SummarizationPrompt: ResearchImportable {
    var importId: UUID { id }
    var importCopyDate: Date? { lastModified }
    static func newForImport(_ record: SummarizationPromptExport) -> SummarizationPrompt {
        let prompt = SummarizationPrompt(name: record.name, promptText: record.promptText)
        prompt.writeImport(record)
        return prompt
    }
    func writeImport(_ record: SummarizationPromptExport) {
        id = record.id
        name = record.name
        promptText = record.promptText
        responseFormat = record.responseFormat
        schema = record.schema
        createdAt = record.createdAt
        lastModified = record.lastModified
    }
    var importRecord: SummarizationPromptExport { SummarizationPromptExport(self) }
}

extension Project: ResearchImportable {
    var importId: UUID { id }
    var importCopyDate: Date? { lastModified }
    static func newForImport(_ record: ProjectExport) -> Project {
        let project = Project(name: record.name)
        project.writeImport(record)
        return project
    }
    func writeImport(_ record: ProjectExport) {
        id = record.id
        name = record.name
        researchQuestion = record.researchQuestion
        defaultDateRangeStart = record.defaultDateRangeStart
        defaultDateRangeEnd = record.defaultDateRangeEnd
        defaultSubjectTagIds = record.defaultSubjectTagIds
        defaultCountryTagIds = record.defaultCountryTagIds
        if let value = record.defaultUserTagIds { defaultUserTagIds = value }
        leadAxisWeights = record.leadAxisWeights
        createdAt = record.createdAt
        lastModified = record.lastModified
    }
    var importRecord: ProjectExport { ProjectExport(self) }
}

extension GeneratedSummary: ResearchImportable {
    var importId: UUID { id }
    var importCopyDate: Date? { lastModified }
    static func newForImport(_ record: GeneratedSummaryExport) -> GeneratedSummary {
        let summary = GeneratedSummary(documentId: record.documentId, volumeId: record.volumeId,
                                       promptId: record.promptId, responseText: record.responseText)
        summary.writeImport(record)
        return summary
    }
    func writeImport(_ record: GeneratedSummaryExport) {
        id = record.id
        documentId = record.documentId
        volumeId = record.volumeId
        promptId = record.promptId
        responseText = record.responseText
        responseFormat = record.responseFormat
        wasChunked = record.wasChunked
        projectId = record.projectId
        authorship = record.authorship
        if let value = record.isHeadnoteDraft { isHeadnoteDraft = value }
        writerName = record.writerName
        createdAt = record.createdAt
        lastModified = record.lastModified
    }
    var importRecord: GeneratedSummaryExport { GeneratedSummaryExport(self) }
}

extension ReadingHistoryEntry: ResearchImportable {
    var importId: UUID { id }
    var importCopyDate: Date? { nil }
    static func newForImport(_ record: ReadingHistoryEntryExport) -> ReadingHistoryEntry {
        let visit = ReadingHistoryEntry(documentId: record.documentId, volumeId: record.volumeId)
        visit.writeImport(record)
        return visit
    }
    func writeImport(_ record: ReadingHistoryEntryExport) {
        id = record.id
        documentId = record.documentId
        volumeId = record.volumeId
        displayTitle = record.displayTitle
        projectId = record.projectId
        accessedAt = record.accessedAt
    }
    var importRecord: ReadingHistoryEntryExport { ReadingHistoryEntryExport(self) }
}

extension SearchHistoryEntry: ResearchImportable {
    var importId: UUID { id }
    var importCopyDate: Date? { nil }
    static func newForImport(_ record: SearchHistoryEntryExport) -> SearchHistoryEntry {
        let search = SearchHistoryEntry(queryText: record.queryText)
        search.writeImport(record)
        return search
    }
    func writeImport(_ record: SearchHistoryEntryExport) {
        id = record.id
        queryText = record.queryText
        resultCount = record.resultCount
        projectId = record.projectId
        loadedCount = record.loadedCount
        matchCount = record.matchCount
        fetchLimit = record.fetchLimit
        indexedVolumeCount = record.indexedVolumeCount
        scopeSignature = record.scopeSignature
        appliedCorpusId = record.appliedCorpusId
        renderedExpression = record.renderedExpression
        executedAt = record.executedAt
    }
    var importRecord: SearchHistoryEntryExport { SearchHistoryEntryExport(self) }
}

extension ExportHistoryEntry: ResearchImportable {
    var importId: UUID { id }
    var importCopyDate: Date? { nil }
    static func newForImport(_ record: ExportHistoryEntryExport) -> ExportHistoryEntry {
        let export = ExportHistoryEntry(format: record.format)
        export.writeImport(record)
        return export
    }
    func writeImport(_ record: ExportHistoryEntryExport) {
        id = record.id
        format = record.format
        documentCount = record.documentCount
        collectionName = record.collectionName
        projectId = record.projectId
        exportedAt = record.exportedAt
    }
    var importRecord: ExportHistoryEntryExport { ExportHistoryEntryExport(self) }
}

extension ArchiveVisitPlan: ResearchImportable {
    var importId: UUID { id }
    var importCopyDate: Date? { lastModified }
    static func newForImport(_ record: ArchiveVisitPlanExport) -> ArchiveVisitPlan {
        // Through the factory every plan is made by (#1366), with no project: the file's projects
        // and inquiry are written over what the factory seeds.
        let plan = ArchiveVisitPlan.make(name: record.name, activeProject: nil)
        plan.writeImport(record)
        return plan
    }
    func writeImport(_ record: ArchiveVisitPlanExport) {
        id = record.id
        name = record.name
        inquiryText = record.inquiryText
        projectIds = record.projectIds
        tiers = record.tiers
        deliverables = record.deliverables
        // The documents and targets are records of their own.
        createdAt = record.createdAt
        lastModified = record.lastModified
    }
    var importRecord: ArchiveVisitPlanExport { ArchiveVisitPlanExport(self, documents: [], targets: []) }
}

extension ArchiveVisitDocument: ResearchImportable {
    var importId: UUID { id }
    var importCopyDate: Date? { lastModified }
    static func newForImport(_ record: ArchiveVisitDocumentExport) -> ArchiveVisitDocument {
        // The plan is the item's parent, which the writer joins.
        let document = ArchiveVisitDocument(planId: UUID(), documentKey: record.documentKey)
        document.writeImport(record)
        return document
    }
    func writeImport(_ record: ArchiveVisitDocumentExport) {
        id = record.id
        documentKey = record.documentKey
        includeSource = record.includeSource
        includeExternalRefs = record.includeExternalRefs
        createdAt = record.createdAt
        lastModified = record.lastModified
    }
    var importRecord: ArchiveVisitDocumentExport { ArchiveVisitDocumentExport(self) }
}

extension ArchiveVisitTarget: ResearchImportable {
    var importId: UUID { id }
    var importCopyDate: Date? { lastModified }
    static func newForImport(_ record: ArchiveVisitTargetExport) -> ArchiveVisitTarget {
        // The plan is the item's parent, which the writer joins.
        let target = ArchiveVisitTarget(planId: UUID(), targetKey: record.targetKey)
        target.writeImport(record)
        return target
    }
    func writeImport(_ record: ArchiveVisitTargetExport) {
        id = record.id
        targetKey = record.targetKey
        tierId = record.tierId
        included = record.included
        userNote = record.userNote
        createdAt = record.createdAt
        lastModified = record.lastModified
    }
    var importRecord: ArchiveVisitTargetExport { ArchiveVisitTargetExport(self) }
}

extension SavedSearch: ResearchImportable {
    var importId: UUID { id }
    var importCopyDate: Date? { lastModified }
    static func newForImport(_ record: SavedSearchExport) -> SavedSearch {
        let search = SavedSearch(name: record.name, parameters: record.parameters)
        search.writeImport(record)
        return search
    }
    func writeImport(_ record: SavedSearchExport) {
        id = record.id
        name = record.name
        storeParameters(record.parameters)
        if record.lastRunAt == nil, record.matchCountAtLastRun == nil,
           record.indexedVolumeCountAtLastRun == nil {
            freshnessData = nil
        } else {
            freshnessData = SavedSearchFreshness(
                lastRunAt: record.lastRunAt, matchCountAtLastRun: record.matchCountAtLastRun,
                indexedVolumeCountAtLastRun: record.indexedVolumeCountAtLastRun).encoded
        }
        createdAt = record.createdAt
        lastModified = record.lastModified
    }
    var importRecord: SavedSearchExport { SavedSearchExport(self) }
}

extension WorkingCorpus: ResearchImportable {
    var importId: UUID { id }
    var importCopyDate: Date? { lastModified }
    static func newForImport(_ record: WorkingCorpusExport) -> WorkingCorpus {
        let corpus = WorkingCorpus(name: record.name, documentKeys: record.documentKeys)
        corpus.writeImport(record)
        return corpus
    }
    func writeImport(_ record: WorkingCorpusExport) {
        id = record.id
        name = record.name
        documentKeys = record.documentKeys
        capturedAt = record.capturedAt
        sourceQuery = record.sourceQuery
        sourceDescription = record.sourceDescription
        indexedVolumeCountAtCapture = record.indexedVolumeCountAtCapture
        wasTruncatedAtCapture = record.wasTruncatedAtCapture
        totalMatchCountAtCapture = record.totalMatchCountAtCapture
        createdAt = record.createdAt
        lastModified = record.lastModified
    }
    var importRecord: WorkingCorpusExport { WorkingCorpusExport(self) }
}

extension CustomVolumeScope: ResearchImportable {
    var importId: UUID { id }
    var importCopyDate: Date? { lastModified }
    static func newForImport(_ record: CustomVolumeScopeExport) -> CustomVolumeScope {
        let scope = CustomVolumeScope(name: record.name)
        scope.writeImport(record)
        return scope
    }
    func writeImport(_ record: CustomVolumeScopeExport) {
        id = record.id
        name = record.name
        volumeIds = record.volumeIds
        createdAt = record.createdAt
        lastModified = record.lastModified
    }
    var importRecord: CustomVolumeScopeExport { CustomVolumeScopeExport(self) }
}

extension DocumentClassificationOverride: ResearchImportable {
    var importId: UUID { id }
    var importCopyDate: Date? { nil }
    static func newForImport(_ record: DocumentClassificationOverrideExport) -> DocumentClassificationOverride {
        let override = DocumentClassificationOverride(
            volumeId: record.volumeId, documentId: record.documentId,
            isEditorialNote: record.isEditorialNote, parsedIsEditorialNote: record.parsedIsEditorialNote)
        override.writeImport(record)
        return override
    }
    func writeImport(_ record: DocumentClassificationOverrideExport) {
        id = record.id
        volumeId = record.volumeId
        documentId = record.documentId
        isEditorialNote = record.isEditorialNote
        parsedIsEditorialNote = record.parsedIsEditorialNote
        createdAt = record.createdAt
    }
    var importRecord: DocumentClassificationOverrideExport { DocumentClassificationOverrideExport(self) }
}

extension PersonClusterOverride: ResearchImportable {
    var importId: UUID { id }
    var importCopyDate: Date? { nil }
    static func newForImport(_ record: PersonClusterOverrideExport) -> PersonClusterOverride {
        let override = PersonClusterOverride(kind: .merge, volumeIdA: record.volumeIdA, refA: record.refA)
        override.writeImport(record)
        return override
    }
    func writeImport(_ record: PersonClusterOverrideExport) {
        id = record.id
        // The stored raw value, so a kind a later build wrote travels as written.
        kind = record.kind
        volumeIdA = record.volumeIdA
        refA = record.refA
        volumeIdB = record.volumeIdB
        refB = record.refB
        createdAt = record.createdAt
    }
    var importRecord: PersonClusterOverrideExport { PersonClusterOverrideExport(self) }
}

extension AnnotationReview: ResearchImportable {
    var importId: UUID { id }
    var importCopyDate: Date? { nil }
    static func newForImport(_ record: AnnotationReviewExport) -> AnnotationReview {
        let review = AnnotationReview(kind: .document, annotationId: nil,
                                      volumeId: record.volumeId, documentId: record.documentId,
                                      contentHash: record.contentHash, changeKind: record.changeKind)
        review.writeImport(record)
        return review
    }
    /// Writes every field but `annotationId`. That field is reserved: no build writes it, and its
    /// CloudKit identifier (`CD_AnnotationReview.CD_annotationId`) has never been deployed to
    /// Production, so the first value written to it would be a schema change
    /// (`CloudKitSchemaInventory.identifiersAwaitingWriter`). No export carries one but `nil`, and
    /// the import writes none, so a review keeps the `nil` its kinds read today.
    func writeImport(_ record: AnnotationReviewExport) {
        id = record.id
        // The stored raw value, so a kind a later build wrote travels as written.
        annotationType = record.annotationType
        volumeId = record.volumeId
        documentId = record.documentId
        contentHash = record.contentHash
        changeKind = record.changeKind
        reviewedAt = record.reviewedAt
    }
    var importRecord: AnnotationReviewExport { AnnotationReviewExport(self) }
}

extension ProjectLeadEntry: ResearchImportable {
    var importId: UUID { id }
    var importCopyDate: Date? { lastComputedAt }
    static func newForImport(_ record: ProjectLeadEntryExport) -> ProjectLeadEntry {
        let lead = ProjectLeadEntry(projectId: record.projectId, volumeId: record.volumeId,
                                    documentId: record.documentId, aggregateScore: record.aggregateScore,
                                    contributingSeedKeys: record.contributingSeedKeys)
        lead.writeImport(record)
        return lead
    }
    func writeImport(_ record: ProjectLeadEntryExport) {
        id = record.id
        projectId = record.projectId
        volumeId = record.volumeId
        documentId = record.documentId
        aggregateScore = record.aggregateScore
        contributingSeedKeys = record.contributingSeedKeys
        header = record.header
        documentNumber = record.documentNumber
        isEditorialNote = record.isEditorialNote
        dismissed = record.dismissed
        firstSurfacedAt = record.firstSurfacedAt
        lastComputedAt = record.lastComputedAt
    }
    var importRecord: ProjectLeadEntryExport { ProjectLeadEntryExport(self) }
}

extension SyncedPreferences {
    /// Writes every field of `record`: the set has no id, so the caller says which set it is
    /// (``ResearchDataImporter/writeSyncedPreferences(_:in:)``). The dates are written last.
    func writeImport(_ record: SyncedPreferencesExport) {
        wcMinLength = record.wcMinLength
        wcMinCount = record.wcMinCount
        wcFoldPlurals = record.wcFoldPlurals
        wcFilterMarkings = record.wcFilterMarkings
        wcExcludeBoilerplate = record.wcExcludeBoilerplate
        wcGlobalStopwordsJSON = record.wcGlobalStopwordsJSON
        wcLensStopwordsJSON = record.wcLensStopwordsJSON
        citationStyleRaw = record.citationStyleRaw
        defaultDocumentModeRaw = record.defaultDocumentModeRaw
        researchLoggingEnabled = record.researchLoggingEnabled
        listOrderJSON = record.listOrderJSON
        createdAt = record.createdAt
        updatedAt = record.updatedAt
    }
}
