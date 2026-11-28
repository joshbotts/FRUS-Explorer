// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// Import from JSON's rules (#1915): what a research data export does to a library, decided over
// values, so that the app on iOS and macOS and FRUS Explorer Light on Linux import a file alike. A
// host decodes the file (`ResearchImportFile`), says what its library holds
// (`ResearchLibrarySnapshot`) and asks for the plan (`ResearchImportPlan`): each of the file's
// records, added, replaced or kept, with the report a screen shows before anything is written. The
// host then writes each record through its own save paths. Nothing here reads or writes a store.

// MARK: - ResearchImportPlan

/// What importing a research data export does to a library: each of the file's records, added,
/// replaced or kept, and a report of it, decided before anything is written (#1915).
///
/// ## The rules
/// The web edition's import of the app's file (its `MacImport` and `UserResearchImport`, S16c)
/// follows the same ones, so that research moves between the two alike.
/// - **Ids.** A record keeps its id. The library's record with that id is the one an import may
///   replace.
/// - **Newer wins.** A record the library holds is replaced only by a newer copy: one whose
///   ``ResearchImportRecord/importStamp`` is later than the library's. A copy as new or older is
///   kept, and so is a copy that gives no time at all.
/// - **Only what the file's version carries.** A replacement writes the fields the file's format
///   version carries and keeps the library's for the rest (``Fields``), so an older file never
///   blanks what it could not say. One exception follows the app's own rule for text: a field
///   that describes a text does not outlive the text. A note's formatting is the formatting of its
///   text, so a file before version 7 that replaces the text leaves the note plain, as the app's
///   note editor leaves one whose text is replaced wholesale; a summary's authorship says who
///   wrote its text, so a file before version 5 that replaces the text leaves the summary
///   AI-generated, as the app reads a summary that names no author; and a headnote's writer's name
///   (version 8) likewise goes with a text a file before version 8 replaces.
/// - **Defaults.** A new record takes the app's defaults for what the file's version cannot carry:
///   each model property's initial value, which a host gets by writing the whole of ``Item/record``.
/// - **No deletions.** An export carries none, so a record the library holds and the file lacks is
///   untouched, and ``Action`` has no deletion.
/// - **What an older file does not say**, read as the app reads it:
///   - before version 7, a summary is a collection's headnote draft when its prompt is the one
///     every draft carries (``GeneratedSummaryExport/headnoteDraftPromptId``);
///   - before version 7, an entry with no document, which version 6 wrote for a heading, a prose
///     block and an apparatus block alike, is added as `CollectionEntryKind.unrecognized`, a kind
///     the app treats as inert;
///   - a collection's saved search is kept as the file names it, even when neither the library nor
///     the file holds that search, and the report names each such collection
///     (``Report/unlinkedCollections``);
///   - of two sets of synced preferences, the earliest made is read, as the app reads its own, and
///     the rest are set aside.
/// - **Corrections.** Classification and person-cluster overrides are the researcher's own in the
///   app, so they are planned like any other record. (In the web edition they belong to the
///   instance, and only a curator imports them: that rule is the web edition's own.)
/// - **A record the file gives twice** is planned once: the newer copy, or of two as new the
///   first, in the first one's place (``TypeCount/repeated``).
///
/// ## Applying it
/// For each item: an ``Action/add`` writes the whole of ``Item/record`` into a new record of the
/// type, its id included; a ``Action/replace`` writes ``Item/written(over:)`` of the library's
/// copy over that copy, every field; a ``Action/keep`` writes nothing. A collection's entries and
/// an archive visit's documents and targets are records of their own, each item naming its parent
/// in ``Item/parentId``, so a collection or a visit is written without them.
///
/// Version history:
///   1.0 — #1915 (L23): initial implementation
public struct ResearchImportPlan: Equatable, Sendable {

    /// The file's `formatVersion`, which decides what it carries.
    public let formatVersion: Int

    /// The file's notes, in its order.
    public let notes: [Item<ResearchNoteExport>]
    /// The file's tags.
    public let tags: [Item<UserTagExport>]
    /// The file's tag assignments.
    public let tagAssignments: [Item<DocumentTagAssignmentExport>]
    /// The file's highlights.
    public let highlights: [Item<DocumentHighlightExport>]
    /// The file's collections, each without its entries, which ``collectionEntries`` plans.
    public let collections: [Item<CollectionExport>]
    /// Every collection's entries, collection by collection, each naming its collection in
    /// ``Item/parentId``.
    public let collectionEntries: [Item<CollectionEntryExport>]
    /// The file's prompts: the researcher's own, the only ones an export carries.
    public let prompts: [Item<SummarizationPromptExport>]
    /// The file's projects.
    public let projects: [Item<ProjectExport>]
    /// The file's summaries: none when the export left them out, which the app's file does not
    /// say and the web edition's key does (``ResearchImportFile/WebKey/includesGeneratedSummaries``).
    public let summaries: [Item<GeneratedSummaryExport>]
    /// The file's recorded document visits.
    public let readingHistory: [Item<ReadingHistoryEntryExport>]
    /// The file's recorded searches.
    public let searchHistory: [Item<SearchHistoryEntryExport>]
    /// The file's recorded collection exports.
    public let exportHistory: [Item<ExportHistoryEntryExport>]
    /// The file's archive visit plans, each without its documents and targets, which
    /// ``archiveVisitDocuments`` and ``archiveVisitTargets`` plan.
    public let archiveVisits: [Item<ArchiveVisitPlanExport>]
    /// Every plan's seeded documents, each naming its plan in ``Item/parentId``.
    public let archiveVisitDocuments: [Item<ArchiveVisitDocumentExport>]
    /// Every plan's stored targets, orphans included, each naming its plan in ``Item/parentId``.
    public let archiveVisitTargets: [Item<ArchiveVisitTargetExport>]
    /// The file's saved searches.
    public let savedSearches: [Item<SavedSearchExport>]
    /// The file's working corpora.
    public let workingCorpora: [Item<WorkingCorpusExport>]
    /// The file's custom volume scopes.
    public let customVolumeScopes: [Item<CustomVolumeScopeExport>]
    /// The file's corrections of whether a document is an editorial note.
    public let classificationOverrides: [Item<DocumentClassificationOverrideExport>]
    /// The file's person corrections.
    public let personClusterOverrides: [Item<PersonClusterOverrideExport>]
    /// The file's reviewed passages.
    public let annotationReviews: [Item<AnnotationReviewExport>]
    /// The file's Suggested Next leads.
    public let projectLeads: [Item<ProjectLeadEntryExport>]
    /// The set of synced preferences the import reads, the file's earliest made, or `nil` when the
    /// file holds none. The set has no id: a replacement writes over the set the app reads, the
    /// library's earliest made.
    public let syncedPreferences: Item<SyncedPreferencesExport>?

    /// What the plan does, for a screen to show before anything is written.
    public let report: Report

    /// Plans the import of `file` into a library that holds what `library` describes.
    ///
    /// - Parameters:
    ///   - file: The export, decoded.
    ///   - library: What the library holds: each record's id and when it was last changed.
    public init(file: ResearchImportFile, library: ResearchLibrarySnapshot) {
        let envelope = file.envelope
        let version = envelope.formatVersion
        var planner = Planner(formatVersion: version, library: library)

        notes = planner.plan(envelope.notes, id: \.id)
        tags = planner.plan(envelope.tags, id: \.id)
        tagAssignments = planner.plan(envelope.tagAssignments, id: \.id)
        highlights = planner.plan(envelope.highlights, id: \.id)
        collections = planner.plan(envelope.collections, id: \.id)
        collectionEntries = planner.plan(children: envelope.collections.flatMap { collection in
            collection.entries.map { (record: $0, parentId: collection.id) }
        }, id: \.id)
        prompts = planner.plan(envelope.prompts, id: \.id)
        projects = planner.plan(envelope.projects, id: \.id)
        summaries = planner.plan(envelope.summaries, id: \.id)
        readingHistory = planner.plan(envelope.readingHistory, id: \.id)
        searchHistory = planner.plan(envelope.searchHistory, id: \.id)
        exportHistory = planner.plan(envelope.exportHistory, id: \.id)
        archiveVisits = planner.plan(envelope.archiveVisits, id: \.id)
        archiveVisitDocuments = planner.plan(children: envelope.archiveVisits.flatMap { plan in
            plan.documents.map { (record: $0, parentId: plan.id) }
        }, id: \.id)
        archiveVisitTargets = planner.plan(children: envelope.archiveVisits.flatMap { plan in
            plan.targets.map { (record: $0, parentId: plan.id) }
        }, id: \.id)
        savedSearches = planner.plan(envelope.savedSearches, id: \.id)
        workingCorpora = planner.plan(envelope.workingCorpora, id: \.id)
        customVolumeScopes = planner.plan(envelope.customVolumeScopes, id: \.id)
        classificationOverrides = planner.plan(envelope.classificationOverrides, id: \.id)
        personClusterOverrides = planner.plan(envelope.personClusterOverrides, id: \.id)
        annotationReviews = planner.plan(envelope.annotationReviews, id: \.id)
        projectLeads = planner.plan(envelope.projectLeads, id: \.id)
        syncedPreferences = planner.plan(preferences: envelope.syncedPreferences)

        // What the file's older versions do not say, as the report counts it.
        let fileSummaries = Planner.unique(envelope.summaries.map { (record: $0, parentId: nil) },
                                           id: \.id).records.map(\.record)
        let fileSearchIds = Set(envelope.savedSearches.map(\.id))
        let unlinked = collections.compactMap { item -> UnlinkedCollection? in
            guard item.action != .keep, let searchId = item.record.savedSearchId,
                  !fileSearchIds.contains(searchId),
                  !library.holds(.savedSearch, id: searchId) else { return nil }
            return UnlinkedCollection(id: item.record.id, name: item.record.name,
                                      savedSearchId: searchId)
        }
        formatVersion = version
        report = Report(
            formatVersion: version,
            exportedAt: envelope.exportedAt,
            webKey: file.webKey,
            types: ModelType.allCases.map { planner.counts[$0] ?? TypeCount(model: $0, formatVersion: version) },
            headnoteDrafts: summaries.filter { $0.record.isHeadnoteDraft == true }.count,
            summariesWithoutAuthorship: fileSummaries.filter {
                version < Fields.summaryAuthorship.since || $0.authorship == nil
            }.count,
            inertEntries: collectionEntries.filter {
                $0.action == .add && version < Fields.collectionEntryContent.since
                    && $0.record.documentId.isEmpty
            }.count,
            unlinkedCollections: unlinked)
    }

    /// Whether the file's format version carries `fields`. A replacement writes them only when it
    /// does; a new record takes the app's defaults for them when it does not.
    ///
    /// - Parameter fields: The fields a later format version added to their type.
    /// - Returns: `true` when the file is of that version or later.
    public func carries(_ fields: Fields) -> Bool {
        formatVersion >= fields.since
    }
}

// MARK: - ResearchImportPlan.ModelType

extension ResearchImportPlan {

    /// A model type an export carries: each of the app's 23 `@Model` types that hold the
    /// researcher's work, named as the app names it, in the order the envelope lists them.
    ///
    /// Version history:
    ///   1.0 — #1915 (L23): initial implementation
    public enum ModelType: String, CaseIterable, Codable, Sendable {
        /// `ResearchNote`.
        case researchNote = "ResearchNote"
        /// `UserTag`.
        case userTag = "UserTag"
        /// `DocumentTagAssignment`.
        case documentTagAssignment = "DocumentTagAssignment"
        /// `DocumentHighlight`.
        case documentHighlight = "DocumentHighlight"
        /// `Collection`.
        case collection = "Collection"
        /// `CollectionEntry`.
        case collectionEntry = "CollectionEntry"
        /// `SummarizationPrompt`, the researcher's own.
        case summarizationPrompt = "SummarizationPrompt"
        /// `Project`.
        case project = "Project"
        /// `GeneratedSummary`.
        case generatedSummary = "GeneratedSummary"
        /// `ReadingHistoryEntry`.
        case readingHistoryEntry = "ReadingHistoryEntry"
        /// `SearchHistoryEntry`.
        case searchHistoryEntry = "SearchHistoryEntry"
        /// `ExportHistoryEntry`.
        case exportHistoryEntry = "ExportHistoryEntry"
        /// `ArchiveVisitPlan`.
        case archiveVisitPlan = "ArchiveVisitPlan"
        /// `ArchiveVisitDocument`.
        case archiveVisitDocument = "ArchiveVisitDocument"
        /// `ArchiveVisitTarget`.
        case archiveVisitTarget = "ArchiveVisitTarget"
        /// `SavedSearch`.
        case savedSearch = "SavedSearch"
        /// `WorkingCorpus`.
        case workingCorpus = "WorkingCorpus"
        /// `CustomVolumeScope`.
        case customVolumeScope = "CustomVolumeScope"
        /// `DocumentClassificationOverride`.
        case documentClassificationOverride = "DocumentClassificationOverride"
        /// `PersonClusterOverride`.
        case personClusterOverride = "PersonClusterOverride"
        /// `AnnotationReview`.
        case annotationReview = "AnnotationReview"
        /// `ProjectLeadEntry`.
        case projectLeadEntry = "ProjectLeadEntry"
        /// `SyncedPreferences`, the one type with no id.
        case syncedPreferences = "SyncedPreferences"

        /// The first format version whose file carries the type: an earlier file holds none of it.
        public var since: Int {
            switch self {
            case .researchNote, .userTag, .documentTagAssignment, .documentHighlight, .collection,
                 .collectionEntry, .summarizationPrompt, .project, .generatedSummary:
                return 1
            case .readingHistoryEntry, .searchHistoryEntry, .exportHistoryEntry:
                return 3
            case .archiveVisitPlan, .archiveVisitDocument, .archiveVisitTarget:
                return 6
            case .savedSearch, .workingCorpus, .customVolumeScope, .documentClassificationOverride,
                 .personClusterOverride, .annotationReview, .projectLeadEntry, .syncedPreferences:
                return 7
            }
        }
    }
}

// MARK: - ResearchImportPlan.Fields

extension ResearchImportPlan {

    /// Fields a later format version added to a type an earlier one already carried: what a
    /// replacement from an older file leaves as the library has it, and a new record from one takes
    /// the app's defaults for. Every other field of a type is carried whenever the type is.
    ///
    /// A summary's headnote flag, which version 7 added, is not among them: before version 7 it is
    /// read from the summary's prompt, so every file says it.
    ///
    /// Version history:
    ///   1.0 — #1915 (L23): initial implementation
    ///   1.1 — L43: seven cases of version 8, one for each property L43 stores
    public enum Fields: String, CaseIterable, Codable, Sendable {
        /// A note's formatting, `richText` (version 7).
        case noteFormatting
        /// A collection's front matter, composition and export settings, from `subtitle` to
        /// `summaryPromptId` (version 7).
        case collectionSettings
        /// An entry's kind, level, text, rich text, excerpt anchors, apparatus block type and every
        /// override (version 7).
        case collectionEntryContent
        /// A project's focus tags and lead weights (version 7).
        case projectFocus
        /// A recorded search's capture provenance, from `loadedCount` to `renderedExpression`
        /// (version 4).
        case searchCaptureProvenance
        /// A summary's authorship (version 5).
        case summaryAuthorship
        /// A collection's citation style, `citationStyle` (version 8; L43).
        case collectionCitationStyle
        /// Which line leads a collection's documents, `opening` (version 8; L43).
        case collectionOpening
        /// A collection's own words for its labels, `labelsJSON` (version 8; L43).
        case collectionWording
        /// A collection's See also default, `defaultIncludeRelatedDocuments` (version 8; L43).
        case collectionSeeAlso
        /// A document entry's date line, `dateLine` (version 8; L43).
        case entryDateLine
        /// A section's headnote default, `headnoteDefault` (version 8; L43).
        case sectionHeadnoteDefault
        /// A headnote's writer's name, `writerName` (version 8; L43).
        case headnoteWriter

        /// The type the fields belong to.
        public var model: ModelType {
            switch self {
            case .noteFormatting: return .researchNote
            case .collectionSettings: return .collection
            case .collectionEntryContent: return .collectionEntry
            case .projectFocus: return .project
            case .searchCaptureProvenance: return .searchHistoryEntry
            case .summaryAuthorship: return .generatedSummary
            case .collectionCitationStyle, .collectionOpening, .collectionWording, .collectionSeeAlso:
                return .collection
            case .entryDateLine, .sectionHeadnoteDefault: return .collectionEntry
            case .headnoteWriter: return .generatedSummary
            }
        }

        /// The format version that added them.
        public var since: Int {
            switch self {
            case .noteFormatting, .collectionSettings, .collectionEntryContent, .projectFocus:
                return 7
            case .searchCaptureProvenance:
                return 4
            case .summaryAuthorship:
                return 5
            case .collectionCitationStyle, .collectionOpening, .collectionWording, .collectionSeeAlso,
                 .entryDateLine, .sectionHeadnoteDefault, .headnoteWriter:
                return 8
            }
        }
    }
}

// MARK: - ResearchImportPlan.Action and Item

extension ResearchImportPlan {

    /// What an import does with one of the file's records. There is no deletion: an export carries
    /// none.
    public enum Action: String, CaseIterable, Codable, Sendable {
        /// The library does not hold the record: it is written as a new one, with the file's id.
        case add
        /// The library holds an older copy: the file's copy is written over it.
        case replace
        /// The library holds a copy as new or newer: nothing is written.
        case keep
    }

    /// One of the file's records, with what the import does with it.
    ///
    /// Version history:
    ///   1.0 — #1915 (L23): initial implementation
    public struct Item<Record: ResearchImportRecord>: Equatable, Sendable {

        /// What the import does with the record.
        public let action: Action

        /// The file's copy as the import adds it: what the file's version cannot carry holds the
        /// app's defaults, and what an older file does not say holds the app's reading of it
        /// (``ResearchImportRecord/resolvedForImport(fromFormatVersion:)``). A collection holds no
        /// entries here, and an archive visit plan no documents or targets: each is an item of its
        /// own. Write all of it for an ``Action/add``; for an ``Action/replace``, write
        /// ``written(over:)`` instead, which keeps what the file could not say.
        public let record: Record

        /// The record this one belongs to: an entry's collection, or an archive visit document's or
        /// target's plan. `nil` for every other type.
        public let parentId: UUID?

        /// The file's format version, which decides what a replacement writes.
        public let formatVersion: Int

        /// The record as the library holds it once the import is applied over `current`, the
        /// library's copy: for a replacement, the file's copy with what its version cannot carry
        /// kept from `current` (``ResearchImportRecord/writtenForImport(over:fromFormatVersion:)``);
        /// for an addition, ``record``; for a record kept, `current`.
        ///
        /// - Parameter current: The library's copy of the record.
        /// - Returns: Every field of the record as it is to be written.
        public func written(over current: Record) -> Record {
            switch action {
            case .add:
                return record
            case .replace:
                return record.writtenForImport(over: current, fromFormatVersion: formatVersion)
            case .keep:
                return current
            }
        }
    }
}

// MARK: - ResearchImportPlan.Report

extension ResearchImportPlan {

    /// What a plan does, for the screen that shows it before anything is written: per type, what
    /// the file holds and what becomes of it, with the file's version, when it was made, the web
    /// edition's key, and what the import made of what an older file does not say.
    ///
    /// Version history:
    ///   1.0 — #1915 (L23): initial implementation
    public struct Report: Codable, Equatable, Sendable {

        /// The file's `formatVersion`.
        public let formatVersion: Int

        /// When the file was written, its `exportedAt`.
        public let exportedAt: Date

        /// What the web edition's key says, for a file FRUS Explorer Light wrote; `nil` for the
        /// app's own, which carries none.
        public let webKey: ResearchImportFile.WebKey?

        /// Every model type, in ``ModelType``'s order, those the file holds none of included.
        public let types: [TypeCount]

        /// Of the file's summaries, those that are a collection's headnote draft, which no list or
        /// search shows: as a file of version 7 says, and before it by the prompt every draft
        /// carries.
        public let headnoteDrafts: Int

        /// Of the file's summaries, those that name no authorship, as no file before version 5
        /// does: read as AI-generated, as the app reads a summary that names none.
        public let summariesWithoutAuthorship: Int

        /// The collection entries the import adds as a kind the app treats as inert: those with no
        /// document in a file before version 7, which wrote a heading, a prose block and an
        /// apparatus block alike and did not say which.
        public let inertEntries: Int

        /// The collections the import writes that name a saved search neither the library nor the
        /// file holds, in the plan's order. Each keeps the link, and the app shows it as it shows
        /// a collection whose saved search was deleted.
        public let unlinkedCollections: [UnlinkedCollection]

        /// The count for `model`.
        ///
        /// - Parameter model: A model type.
        /// - Returns: Its count, or zeros when the report lists none.
        public func count(of model: ModelType) -> TypeCount {
            types.first { $0.model == model } ?? TypeCount(model: model, formatVersion: formatVersion)
        }

        /// The records the import adds, of every type.
        public var added: Int { types.reduce(0) { $0 + $1.added } }

        /// The records the import replaces, of every type.
        public var replaced: Int { types.reduce(0) { $0 + $1.replaced } }

        /// The records the import keeps as the library has them, of every type.
        public var kept: Int { types.reduce(0) { $0 + $1.kept } }

        /// The fields the file's version cannot carry, which the import leaves as the library has
        /// them, in ``Fields``' order. Empty for a file of the current version.
        public var fieldsNotCarried: [Fields] {
            Fields.allCases.filter { formatVersion < $0.since }
        }
    }

    /// What became of one model type's records.
    ///
    /// The file's records are each counted once: `inFile == added + replaced + kept + setAside +
    /// repeated`.
    ///
    /// Version history:
    ///   1.0 — #1915 (L23): initial implementation
    public struct TypeCount: Codable, Equatable, Sendable {

        /// The model type.
        public let model: ModelType

        /// Whether a file of this format version can carry the type: one that cannot holds none of
        /// it, which is not the same as a file that holds none.
        public let carried: Bool

        /// The file's records of the type.
        public let inFile: Int

        /// Records the library does not hold, which the import adds.
        public let added: Int

        /// Records of which the library holds an older copy, which the import replaces.
        public let replaced: Int

        /// Records of which the library holds a copy as new or newer, which the import keeps.
        public let kept: Int

        /// Records the import does not read: the synced preferences after the earliest made.
        public let setAside: Int

        /// Records whose id the file already gave: the same record twice, planned once.
        public let repeated: Int

        /// A count.
        init(model: ModelType, formatVersion: Int, inFile: Int = 0, added: Int = 0,
             replaced: Int = 0, kept: Int = 0, setAside: Int = 0, repeated: Int = 0) {
            self.model = model
            self.carried = formatVersion >= model.since
            self.inFile = inFile
            self.added = added
            self.replaced = replaced
            self.kept = kept
            self.setAside = setAside
            self.repeated = repeated
        }
    }

    /// A collection the import writes that names a saved search neither the library nor the file
    /// holds.
    public struct UnlinkedCollection: Codable, Equatable, Sendable {
        /// The collection's id.
        public let id: UUID
        /// The collection's name.
        public let name: String
        /// The saved search it names.
        public let savedSearchId: UUID
    }
}

// MARK: - ResearchImportPlan.Planner

extension ResearchImportPlan {

    /// Plans each type's records in turn, and counts them.
    private struct Planner {

        /// The file's format version.
        let formatVersion: Int

        /// What the library holds.
        let library: ResearchLibrarySnapshot

        /// Each planned type's count.
        var counts: [ModelType: TypeCount] = [:]

        /// Plans `records`, a type with no parent.
        mutating func plan<Record: ResearchImportRecord>(_ records: [Record],
                                                         id: KeyPath<Record, UUID>) -> [Item<Record>] {
            plan(children: records.map { (record: $0, parentId: nil) }, id: id)
        }

        /// Plans `records`, each with its parent's id, in their order.
        mutating func plan<Record: ResearchImportRecord>(
            children records: [(record: Record, parentId: UUID?)],
            id: KeyPath<Record, UUID>
        ) -> [Item<Record>] {
            let model = Record.importModel
            let unique = Self.unique(records, id: id)
            var added = 0, replaced = 0, kept = 0
            let items = unique.records.map { entry -> Item<Record> in
                let action = Self.action(for: entry.record, id: entry.record[keyPath: id],
                                         in: library)
                switch action {
                case .add: added += 1
                case .replace: replaced += 1
                case .keep: kept += 1
                }
                return Item(action: action,
                            record: entry.record.resolvedForImport(fromFormatVersion: formatVersion),
                            parentId: entry.parentId, formatVersion: formatVersion)
            }
            counts[model] = TypeCount(model: model, formatVersion: formatVersion,
                                      inFile: records.count, added: added, replaced: replaced,
                                      kept: kept, repeated: unique.repeated)
            return items
        }

        /// Plans the synced preferences: the earliest made, of two made at once the first, set
        /// against the set the library reads; the rest set aside.
        mutating func plan(preferences sets: [SyncedPreferencesExport]) -> Item<SyncedPreferencesExport>? {
            let earliest = sets.enumerated().min {
                ($0.element.createdAt, $0.offset) < ($1.element.createdAt, $1.offset)
            }?.element
            var action: Action?
            if let earliest {
                if !library.holdsSyncedPreferences {
                    action = .add
                } else if let stamp = earliest.importStamp,
                          stamp > (library.syncedPreferencesStamp ?? .distantPast) {
                    action = .replace
                } else {
                    action = .keep
                }
            }
            counts[.syncedPreferences] = TypeCount(
                model: .syncedPreferences, formatVersion: formatVersion, inFile: sets.count,
                added: action == .add ? 1 : 0, replaced: action == .replace ? 1 : 0,
                kept: action == .keep ? 1 : 0, setAside: max(0, sets.count - 1))
            guard let earliest, let action else { return nil }
            return Item(action: action,
                        record: earliest.resolvedForImport(fromFormatVersion: formatVersion),
                        parentId: nil, formatVersion: formatVersion)
        }

        /// What the import does with `record`, whose id is `id`: add it when the library does not
        /// hold it, replace the library's copy when the file's is newer, and otherwise keep it.
        static func action<Record: ResearchImportRecord>(for record: Record, id: UUID,
                                                         in library: ResearchLibrarySnapshot) -> Action {
            let model = Record.importModel
            guard library.holds(model, id: id) else { return .add }
            guard let stamp = record.importStamp,
                  stamp > (library.stamp(of: model, id: id) ?? .distantPast) else { return .keep }
            return .replace
        }

        /// `records` with one copy of each id, in the order their ids first appear: the newer
        /// copy, by ``ResearchImportRecord/importStamp``, a copy with none counting as the oldest,
        /// and of two as new the first.
        ///
        /// - Returns: The copies, and how many records repeated an id given before them.
        static func unique<Record: ResearchImportRecord>(
            _ records: [(record: Record, parentId: UUID?)],
            id: KeyPath<Record, UUID>
        ) -> (records: [(record: Record, parentId: UUID?)], repeated: Int) {
            var kept: [(record: Record, parentId: UUID?)] = []
            var position: [UUID: Int] = [:]
            var repeated = 0
            for entry in records {
                let key = entry.record[keyPath: id]
                guard let index = position[key] else {
                    position[key] = kept.count
                    kept.append(entry)
                    continue
                }
                repeated += 1
                if (entry.record.importStamp ?? .distantPast)
                    > (kept[index].record.importStamp ?? .distantPast) {
                    kept[index] = entry
                }
            }
            return (kept, repeated)
        }
    }
}

// MARK: - ResearchImportFile

/// A research data export as an import reads it: the envelope, of any format version from 1 to the
/// current one, through the kit's tolerant decoder, and the web edition's key when the file carries
/// one (#1915).
///
/// Version history:
///   1.0 — #1915 (L23): initial implementation
public struct ResearchImportFile: Equatable, Sendable {

    /// The export.
    public let envelope: ResearchDataEnvelope

    /// What FRUS Explorer Light's key says, for a file it wrote; `nil` for the app's own file, and
    /// for a key that cannot be read, which the envelope's decoder passes over as it always has.
    public let webKey: WebKey?

    /// The format versions an import reads: every one an export has been written at, through the
    /// current one.
    public static let supportedFormatVersions = 1...ResearchDataEnvelope.currentFormatVersion

    /// An export already decoded.
    ///
    /// - Parameters:
    ///   - envelope: The export.
    ///   - webKey: The web edition's key, when the file carried one.
    /// - Throws: ``FormatError`` when the envelope's version is none an import reads.
    public init(envelope: ResearchDataEnvelope, webKey: WebKey? = nil) throws {
        if envelope.formatVersion > Self.supportedFormatVersions.upperBound {
            throw FormatError.newerFormatVersion(envelope.formatVersion)
        }
        guard Self.supportedFormatVersions.contains(envelope.formatVersion) else {
            throw FormatError.unknownFormatVersion(envelope.formatVersion)
        }
        self.envelope = envelope
        self.webKey = webKey
    }

    /// An export's bytes, decoded once: the envelope by `ResearchDataEnvelope`'s tolerant decoder
    /// through ``ResearchDataEnvelope/makeDecoder()``, and the web edition's key beside it.
    ///
    /// - Parameter data: The file.
    /// - Throws: ``FormatError/newerFormatVersion(_:)`` for a file a later build wrote, which this
    ///   one may not read whole, even where it fails to decode; otherwise the decoder's error for
    ///   a file that is not an export or is damaged, and ``FormatError`` for a version none wrote.
    public init(data: Data) throws {
        let decoder = ResearchDataEnvelope.makeDecoder()
        let contents: Contents
        do {
            contents = try decoder.decode(Contents.self, from: data)
        } catch {
            // A later build's file may not decode as this build's: say so, rather than what failed.
            if let head = try? decoder.decode(Head.self, from: data),
               head.formatVersion > Self.supportedFormatVersions.upperBound {
                throw FormatError.newerFormatVersion(head.formatVersion)
            }
            throw error
        }
        try self.init(envelope: contents.envelope, webKey: contents.webKey)
    }

    /// A file an import does not read.
    public enum FormatError: Error, Equatable, Sendable {
        /// A file written at a format version later than this build reads: one from a later build,
        /// which may carry what this one cannot store. The fix is to update.
        case newerFormatVersion(Int)
        /// A format version no build has written.
        case unknownFormatVersion(Int)
    }

    /// The envelope and the web edition's key, decoded from one parse of the file.
    private struct Contents: Decodable {
        /// The export.
        let envelope: ResearchDataEnvelope
        /// The web edition's key, if the file carries a readable one.
        let webKey: WebKey?

        /// The key the web edition writes its key under.
        enum CodingKeys: String, CodingKey {
            case frusExplorerLight
        }

        /// Decodes the envelope from the file's top level, and the key beside it.
        init(from decoder: any Decoder) throws {
            envelope = try ResearchDataEnvelope(from: decoder)
            let container = try decoder.container(keyedBy: CodingKeys.self)
            webKey = try? container.decodeIfPresent(WebKey.self, forKey: .frusExplorerLight)
        }
    }

    /// The file's format version alone, read when the file does not decode.
    private struct Head: Decodable {
        /// The file's `formatVersion`.
        let formatVersion: Int
    }
}

// MARK: - ResearchImportFile.WebKey

extension ResearchImportFile {

    /// What FRUS Explorer Light adds to an export it writes, under its one key, `frusExplorerLight`
    /// (its `WebExportKey`): what the file leaves out by choice, which the envelope cannot say.
    ///
    /// Each of its fields is optional here, so that a later key that changes one still reads.
    ///
    /// Version history:
    ///   1.0 — #1915 (L23): initial implementation, reading the key's version 1
    public struct WebKey: Codable, Equatable, Sendable {

        /// The key's own version.
        public let formatVersion: Int?

        /// Whether the file carries the user's summaries: an empty `summaries` can mean either.
        public let includesGeneratedSummaries: Bool?

        /// Whether the file carries the instance's two corrections, which only a curator's export
        /// does.
        public let includesCorrections: Bool?

        /// A key.
        ///
        /// - Parameters:
        ///   - formatVersion: The key's own version.
        ///   - includesGeneratedSummaries: Whether the file carries the user's summaries.
        ///   - includesCorrections: Whether it carries the instance's corrections.
        public init(formatVersion: Int?, includesGeneratedSummaries: Bool?,
                    includesCorrections: Bool?) {
            self.formatVersion = formatVersion
            self.includesGeneratedSummaries = includesGeneratedSummaries
            self.includesCorrections = includesCorrections
        }
    }
}

// MARK: - ResearchLibrarySnapshot

/// What a library holds, as an import compares it with a file (#1915): for each model type, each
/// record's id and when its copy was last changed, and for the synced preferences, which have no
/// id, the set the app reads.
///
/// A host describes its library with ``init(_:)`` from an export of it, which reads every record's
/// stamp as the plan reads the file's, or with ``insert(_:id:stamp:)`` and
/// ``insertSyncedPreferences(createdAt:updatedAt:)``. A record stored as several copies under one id
/// is held at the latest of their stamps, the copy the app reads; a copy with no stamp counts as the
/// oldest. The snapshot should list every record the library holds of each type, so that an id the
/// library holds is never planned as an addition.
///
/// Version history:
///   1.0 — #1915 (L23): initial implementation
public struct ResearchLibrarySnapshot: Equatable, Sendable {

    /// By model type, each record's id and stamp.
    private var stamps: [ResearchImportPlan.ModelType: [UUID: Held]] = [:]

    /// The set of synced preferences the app reads, the earliest made.
    private var preferences: HeldPreferences?

    /// An empty library.
    public init() {}

    /// The library an export of it describes: every record's id, with its stamp read as the plan
    /// reads the file's (``ResearchImportRecord/importStamp``).
    ///
    /// An export holds one copy of each record, the one the app reads, and none of the standard
    /// prompts, so a host that may hold a standard prompt's id should insert its prompts itself.
    ///
    /// - Parameter envelope: An export of the library, with its summaries.
    public init(_ envelope: ResearchDataEnvelope) {
        insertAll(envelope.notes, id: \.id)
        insertAll(envelope.tags, id: \.id)
        insertAll(envelope.tagAssignments, id: \.id)
        insertAll(envelope.highlights, id: \.id)
        insertAll(envelope.collections, id: \.id)
        insertAll(envelope.collections.flatMap(\.entries), id: \.id)
        insertAll(envelope.prompts, id: \.id)
        insertAll(envelope.projects, id: \.id)
        insertAll(envelope.summaries, id: \.id)
        insertAll(envelope.readingHistory, id: \.id)
        insertAll(envelope.searchHistory, id: \.id)
        insertAll(envelope.exportHistory, id: \.id)
        insertAll(envelope.archiveVisits, id: \.id)
        insertAll(envelope.archiveVisits.flatMap(\.documents), id: \.id)
        insertAll(envelope.archiveVisits.flatMap(\.targets), id: \.id)
        insertAll(envelope.savedSearches, id: \.id)
        insertAll(envelope.workingCorpora, id: \.id)
        insertAll(envelope.customVolumeScopes, id: \.id)
        insertAll(envelope.classificationOverrides, id: \.id)
        insertAll(envelope.personClusterOverrides, id: \.id)
        insertAll(envelope.annotationReviews, id: \.id)
        insertAll(envelope.projectLeads, id: \.id)
        for set in envelope.syncedPreferences {
            insertSyncedPreferences(createdAt: set.createdAt, updatedAt: set.updatedAt)
        }
    }

    /// Records that the library holds a record.
    ///
    /// - Parameters:
    ///   - model: The record's type; never ``ResearchImportPlan/ModelType/syncedPreferences``,
    ///     which has no id (``insertSyncedPreferences(createdAt:updatedAt:)``).
    ///   - id: The record's id.
    ///   - stamp: When the copy was last changed, read as ``ResearchImportRecord/importStamp``
    ///     reads the type's record: the modification date where the type keeps one, else when it
    ///     was made, and for the research trail and the review ledger the event's own time.
    public mutating func insert(_ model: ResearchImportPlan.ModelType, id: UUID, stamp: Date?) {
        precondition(model != .syncedPreferences,
                     "Synced preferences have no id: use insertSyncedPreferences(createdAt:updatedAt:)")
        if let held = stamps[model]?[id], (held.stamp ?? .distantPast) >= (stamp ?? .distantPast) {
            return
        }
        stamps[model, default: [:]][id] = Held(stamp: stamp)
    }

    /// Records a set of synced preferences the library holds. Of several, the earliest made is the
    /// one the app reads (`SettingsSyncCoordinator`), and of two made at once the first recorded.
    ///
    /// - Parameters:
    ///   - createdAt: When the set was made.
    ///   - updatedAt: When it was last changed, its stamp.
    public mutating func insertSyncedPreferences(createdAt: Date, updatedAt: Date) {
        if let held = preferences, held.createdAt <= createdAt { return }
        preferences = HeldPreferences(createdAt: createdAt, updatedAt: updatedAt)
    }

    /// Whether the library holds a record of `model` with `id`.
    public func holds(_ model: ResearchImportPlan.ModelType, id: UUID) -> Bool {
        stamps[model]?[id] != nil
    }

    /// The stamp of the library's copy of a record: `nil` when the copy has none, or when the
    /// library does not hold the record (``holds(_:id:)`` tells the two apart).
    public func stamp(of model: ResearchImportPlan.ModelType, id: UUID) -> Date? {
        stamps[model]?[id]?.stamp
    }

    /// How many records of `model` the library holds, each id once: for the synced preferences,
    /// 1 when it holds a set.
    public func count(of model: ResearchImportPlan.ModelType) -> Int {
        model == .syncedPreferences ? (preferences == nil ? 0 : 1) : (stamps[model]?.count ?? 0)
    }

    /// The ids of the records of `model` the library holds: none for the synced preferences, which
    /// have no id.
    public func ids(of model: ResearchImportPlan.ModelType) -> Set<UUID> {
        stamps[model].map { Set($0.keys) } ?? []
    }

    /// Whether the library holds a set of synced preferences.
    public var holdsSyncedPreferences: Bool {
        preferences != nil
    }

    /// When the set of synced preferences the app reads was last changed, or `nil` when the library
    /// holds none.
    public var syncedPreferencesStamp: Date? {
        preferences?.updatedAt
    }

    /// Records each of `records`.
    private mutating func insertAll<Record: ResearchImportRecord>(_ records: [Record],
                                                                  id: KeyPath<Record, UUID>) {
        for record in records {
            insert(Record.importModel, id: record[keyPath: id], stamp: record.importStamp)
        }
    }

    /// A record's stamp, which may be none.
    private struct Held: Equatable, Sendable {
        /// When the copy was last changed.
        var stamp: Date?
    }

    /// The set of synced preferences the app reads.
    private struct HeldPreferences: Equatable, Sendable {
        /// When it was made.
        var createdAt: Date
        /// When it was last changed.
        var updatedAt: Date
    }
}

// MARK: - ResearchImportRecord

/// A record of a research data export, as an import plans it (#1915): every `…Export` type the
/// envelope carries conforms.
///
/// Version history:
///   1.0 — #1915 (L23): initial implementation
public protocol ResearchImportRecord: Equatable, Sendable {

    /// The model type a record of this kind is.
    static var importModel: ResearchImportPlan.ModelType { get }

    /// When this copy was last changed, as an import compares two copies of one record: the
    /// modification date where the type keeps one, else when it was made; for the research trail
    /// and the review ledger, the event's own time; for a Suggested Next lead, when it was last
    /// computed. `nil` when the copy gives none, which counts as older than any that does. The web
    /// edition's import reads the same dates (its `ImportStamp`).
    var importStamp: Date? { get }

    /// This record as an import adds it from a file of `version`: what that version cannot carry
    /// takes the app's defaults, each model property's initial value, and what an older file does
    /// not say takes the app's reading of it. A record of a type with nothing to resolve is itself.
    ///
    /// - Parameter version: The file's format version.
    /// - Returns: The record to write.
    func resolvedForImport(fromFormatVersion version: Int) -> Self

    /// This record, resolved, written over `current`, the library's copy, by a file of `version`:
    /// the fields that version carries from this record, and the rest from `current`, but for a
    /// field that describes a text the file replaces. A record of a type a file always carries
    /// whole is itself.
    ///
    /// - Parameters:
    ///   - current: The library's copy.
    ///   - version: The file's format version.
    /// - Returns: The record to write over `current`.
    func writtenForImport(over current: Self, fromFormatVersion version: Int) -> Self
}

extension ResearchImportRecord {

    /// The record as the file gives it: a type with nothing to resolve.
    public func resolvedForImport(fromFormatVersion version: Int) -> Self {
        self
    }

    /// The file's copy, whole: a type every version that carries it carries in full.
    public func writtenForImport(over current: Self, fromFormatVersion version: Int) -> Self {
        self
    }
}

// MARK: - The records

extension ResearchNoteExport: ResearchImportRecord {

    /// `ResearchNote`.
    public static let importModel = ResearchImportPlan.ModelType.researchNote

    /// When the note was last modified, else when it was made.
    public var importStamp: Date? { lastModified ?? createdAt }

    /// From a file before version 7, a note with no formatting, the model's default.
    public func resolvedForImport(fromFormatVersion version: Int) -> Self {
        guard version < ResearchImportPlan.Fields.noteFormatting.since else { return self }
        var note = self
        note.richText = nil
        return note
    }

    /// From a file before version 7, the library's formatting, while the file's text is the
    /// library's. A note's formatting is the formatting of its text, so with a new text it goes,
    /// and the note reads as its plain text, as the app's note editor leaves a note whose text it
    /// replaces wholesale (`ResearchNoteEditorViewModel.replaceBody(with:)`): a stale copy would
    /// show the reader their old prose, and its first keystroke would write that prose back.
    public func writtenForImport(over current: Self, fromFormatVersion version: Int) -> Self {
        guard version < ResearchImportPlan.Fields.noteFormatting.since else { return self }
        var note = self
        note.richText = bodyText == current.bodyText ? current.richText : nil
        return note
    }
}

extension UserTagExport: ResearchImportRecord {

    /// `UserTag`.
    public static let importModel = ResearchImportPlan.ModelType.userTag

    /// When the tag was last modified, else when it was made.
    public var importStamp: Date? { lastModified ?? createdAt }
}

extension DocumentTagAssignmentExport: ResearchImportRecord {

    /// `DocumentTagAssignment`.
    public static let importModel = ResearchImportPlan.ModelType.documentTagAssignment

    /// When the assignment was made: it records no change.
    public var importStamp: Date? { createdAt }
}

extension DocumentHighlightExport: ResearchImportRecord {

    /// `DocumentHighlight`.
    public static let importModel = ResearchImportPlan.ModelType.documentHighlight

    /// When the highlight was made: it records no change, so the library's copy of one is kept.
    public var importStamp: Date? { createdAt }
}

extension CollectionExport: ResearchImportRecord {

    /// `Collection`.
    public static let importModel = ResearchImportPlan.ModelType.collection

    /// When the collection was last modified, else when it was made.
    public var importStamp: Date? { lastModified ?? createdAt }

    /// The collection without its entries, which are items of their own. Its settings from a file
    /// before version 7, and its own facts from a file before version 8, are the app's defaults; from
    /// a later file, a setting the model keeps without an optional and the file leaves out is its
    /// default.
    public func resolvedForImport(fromFormatVersion version: Int) -> Self {
        var collection = self
        collection.entries = []
        let defaults = CollectionExport(id: id, name: name, projectIds: [], entries: [])
        if version < ResearchImportPlan.Fields.collectionSettings.since {
            collection.takeSettings(of: defaults)
        }
        if version < ResearchImportPlan.Fields.collectionCitationStyle.since {
            collection.takeFacts(of: defaults)
        }
        collection.fillMissingSettings()
        return collection
    }

    /// From a file before version 7, the library's settings, and from one before version 8 the library's own
    /// facts: its citation style, opening, wording and See also default (L43), which an older file cannot say.
    /// The entries are always the library's: writing a collection never writes its entries.
    public func writtenForImport(over current: Self, fromFormatVersion version: Int) -> Self {
        var collection = self
        collection.entries = current.entries
        if version < ResearchImportPlan.Fields.collectionSettings.since {
            collection.takeSettings(of: current)
        }
        if version < ResearchImportPlan.Fields.collectionCitationStyle.since {
            collection.takeFacts(of: current)
        }
        return collection
    }

    /// Takes the collection's own facts of `other`: the fields version 8 added
    /// (``ResearchImportPlan/Fields/collectionCitationStyle``, ``ResearchImportPlan/Fields/collectionOpening``,
    /// ``ResearchImportPlan/Fields/collectionWording`` and ``ResearchImportPlan/Fields/collectionSeeAlso``).
    private mutating func takeFacts(of other: CollectionExport) {
        citationStyle = other.citationStyle
        opening = other.opening
        labelsJSON = other.labelsJSON
        defaultIncludeRelatedDocuments = other.defaultIncludeRelatedDocuments
    }

    /// Takes the front matter, composition and export settings of `other`: the fields version 7
    /// added (``ResearchImportPlan/Fields/collectionSettings``).
    private mutating func takeSettings(of other: CollectionExport) {
        subtitle = other.subtitle
        authorLine = other.authorLine
        introductionText = other.introductionText
        introductionRichText = other.introductionRichText
        includeColophon = other.includeColophon
        includeProjectProvenance = other.includeProjectProvenance
        includeMethodAppendix = other.includeMethodAppendix
        defaultBodyDepth = other.defaultBodyDepth
        footnoteStyle = other.footnoteStyle
        includeFootnotes = other.includeFootnotes
        includeSourceNote = other.includeSourceNote
        tocStyle = other.tocStyle
        applyHighlights = other.applyHighlights
        includeNotes = other.includeNotes
        includeWordCloud = other.includeWordCloud
        defaultIncludeHeadnote = other.defaultIncludeHeadnote
        summaryPromptId = other.summaryPromptId
    }

    /// Gives each setting the model keeps without an optional, and the record leaves out, its
    /// default: the `Collection` property's initial value. The settings the model keeps optional
    /// (the front matter's text, `includeFootnotes`, `includeSourceNote`, `summaryPromptId`)
    /// default to none.
    private mutating func fillMissingSettings() {
        includeColophon = includeColophon ?? false
        includeProjectProvenance = includeProjectProvenance ?? false
        includeMethodAppendix = includeMethodAppendix ?? false
        defaultBodyDepth = defaultBodyDepth ?? "full"
        footnoteStyle = footnoteStyle ?? "all"
        tocStyle = tocStyle ?? "citation"
        applyHighlights = applyHighlights ?? false
        includeNotes = includeNotes ?? true
        includeWordCloud = includeWordCloud ?? false
        defaultIncludeHeadnote = defaultIncludeHeadnote ?? false
        defaultIncludeRelatedDocuments = defaultIncludeRelatedDocuments ?? false
    }
}

extension CollectionEntryExport: ResearchImportRecord {

    /// `CollectionEntry`.
    public static let importModel = ResearchImportPlan.ModelType.collectionEntry

    /// When the entry was last modified, else when it was made.
    public var importStamp: Date? { lastModified ?? createdAt }

    /// From a file before version 7, the app's defaults for the entry's kind, text and overrides,
    /// its kind read from its document: `document`, or for an entry with no document, which version
    /// 6 wrote for a heading, a prose block and an apparatus block alike,
    /// `CollectionEntryKind.unrecognized`, which the app treats as inert. From a later file, a field
    /// the model keeps without an optional and the file leaves out takes the same default.
    public func resolvedForImport(fromFormatVersion version: Int) -> Self {
        var entry = self
        if version < ResearchImportPlan.Fields.collectionEntryContent.since {
            entry.takeContent(of: CollectionEntryExport(id: id, documentId: documentId,
                                                        volumeId: volumeId, sortOrder: sortOrder,
                                                        selectedNoteIds: []))
        }
        if version < ResearchImportPlan.Fields.entryDateLine.since {
            entry.dateLine = nil
            entry.headnoteDefault = nil
        }
        entry.fillMissingContent()
        return entry
    }

    /// From a file before version 7, the library's kind, text and overrides; from one before version 8, the
    /// library's date line and section headnote default (L43).
    public func writtenForImport(over current: Self, fromFormatVersion version: Int) -> Self {
        var entry = self
        if version < ResearchImportPlan.Fields.collectionEntryContent.since {
            entry.takeContent(of: current)
        }
        if version < ResearchImportPlan.Fields.entryDateLine.since {
            entry.dateLine = current.dateLine
            entry.headnoteDefault = current.headnoteDefault
        }
        return entry
    }

    /// Takes the kind, level, text, rich text, excerpt anchors, apparatus block type and overrides
    /// of `other`: the fields version 7 added (``ResearchImportPlan/Fields/collectionEntryContent``).
    private mutating func takeContent(of other: CollectionEntryExport) {
        kind = other.kind
        level = other.level
        text = other.text
        richText = other.richText
        excerptStart = other.excerptStart
        excerptEnd = other.excerptEnd
        excerptRenderingVersion = other.excerptRenderingVersion
        excerptColorTag = other.excerptColorTag
        generatedBlockType = other.generatedBlockType
        titleOverride = other.titleOverride
        bodyDepthOverride = other.bodyDepthOverride
        applyHighlightsOverride = other.applyHighlightsOverride
        includeNotesOverride = other.includeNotesOverride
        includeSourceNoteOverride = other.includeSourceNoteOverride
        includeFootnotesOverride = other.includeFootnotesOverride
        summaryPromptIdOverride = other.summaryPromptIdOverride
        selectedHighlightIds = other.selectedHighlightIds
        includeRelatedDocuments = other.includeRelatedDocuments
        includeHeadnote = other.includeHeadnote
        headnoteSummaryId = other.headnoteSummaryId
    }

    /// Gives each field the model keeps without an optional, and the record leaves out, its
    /// default: the `CollectionEntry` property's initial value, but for the kind of an entry with
    /// no document, which is inert.
    private mutating func fillMissingContent() {
        kind = kind ?? (documentId.isEmpty ? CollectionEntryKind.unrecognized.rawValue
                                           : CollectionEntryKind.document.rawValue)
        level = level ?? 1
        selectedHighlightIds = selectedHighlightIds ?? []
    }
}

extension SummarizationPromptExport: ResearchImportRecord {

    /// `SummarizationPrompt`.
    public static let importModel = ResearchImportPlan.ModelType.summarizationPrompt

    /// When the prompt was last modified, else when it was made.
    public var importStamp: Date? { lastModified ?? createdAt }
}

extension ProjectExport: ResearchImportRecord {

    /// `Project`.
    public static let importModel = ResearchImportPlan.ModelType.project

    /// When the project was last modified, else when it was made.
    public var importStamp: Date? { lastModified ?? createdAt }

    /// From a file before version 7, no focus tags and the default lead weights, the model's
    /// defaults; from a later file that leaves the focus tags out, none.
    public func resolvedForImport(fromFormatVersion version: Int) -> Self {
        var project = self
        if version < ResearchImportPlan.Fields.projectFocus.since {
            project.defaultUserTagIds = nil
            project.leadAxisWeights = nil
        }
        project.defaultUserTagIds = project.defaultUserTagIds ?? []
        return project
    }

    /// From a file before version 7, the library's focus tags and lead weights.
    public func writtenForImport(over current: Self, fromFormatVersion version: Int) -> Self {
        guard version < ResearchImportPlan.Fields.projectFocus.since else { return self }
        var project = self
        project.defaultUserTagIds = current.defaultUserTagIds
        project.leadAxisWeights = current.leadAxisWeights
        return project
    }
}

extension GeneratedSummaryExport: ResearchImportRecord {

    /// `GeneratedSummary`.
    public static let importModel = ResearchImportPlan.ModelType.generatedSummary

    /// The prompt id every headnote draft carries, which no prompt has: the app stamps it on each
    /// draft it makes (`CollectionEntryInspector`), and copies it with the draft. Before version 7
    /// a file has no headnote flag, and this is how the flag is read.
    public static let headnoteDraftPromptId = UUID(uuidString: "0EAD0000-0000-4000-8000-000000000001")!

    /// The format version that added the headnote flag, `isHeadnoteDraft`.
    private static let headnoteFlagSince = 7

    /// When the summary was last modified, else when it was made.
    public var importStamp: Date? { lastModified ?? createdAt }

    /// The authorship from a file before version 5, and from a later one that names none, is
    /// AI-generated: the model's default, and how the app reads a summary that names no author.
    /// The headnote flag, before version 7 and in a later file that leaves it out, is read from the
    /// prompt (``headnoteDraftPromptId``).
    public func resolvedForImport(fromFormatVersion version: Int) -> Self {
        var summary = self
        if version < ResearchImportPlan.Fields.summaryAuthorship.since {
            summary.authorship = nil
        }
        summary.authorship = summary.authorship ?? .aiGenerated
        if version < Self.headnoteFlagSince {
            summary.isHeadnoteDraft = nil
        }
        summary.isHeadnoteDraft = summary.isHeadnoteDraft ?? (promptId == Self.headnoteDraftPromptId)
        if version < ResearchImportPlan.Fields.headnoteWriter.since {
            summary.writerName = nil
        }
        return summary
    }

    /// From a file before version 5, the library's authorship, while the file's text is the
    /// library's. Authorship says who wrote the text, so with a new text from a file that cannot
    /// name its author, the summary reads as the app reads one that names none: AI-generated.
    /// A headnote's writer's name says the same, so from a file before version 8 it is the library's
    /// while the text is, and none with a new text (L43).
    public func writtenForImport(over current: Self, fromFormatVersion version: Int) -> Self {
        var summary = self
        if version < ResearchImportPlan.Fields.summaryAuthorship.since {
            summary.authorship = responseText == current.responseText ? current.authorship : .aiGenerated
        }
        if version < ResearchImportPlan.Fields.headnoteWriter.since {
            summary.writerName = responseText == current.responseText ? current.writerName : nil
        }
        return summary
    }
}

extension ReadingHistoryEntryExport: ResearchImportRecord {

    /// `ReadingHistoryEntry`.
    public static let importModel = ResearchImportPlan.ModelType.readingHistoryEntry

    /// When the document was opened.
    public var importStamp: Date? { accessedAt }
}

extension SearchHistoryEntryExport: ResearchImportRecord {

    /// `SearchHistoryEntry`.
    public static let importModel = ResearchImportPlan.ModelType.searchHistoryEntry

    /// When the search ran.
    public var importStamp: Date? { executedAt }

    /// From a file before version 4, no capture provenance, the model's default.
    public func resolvedForImport(fromFormatVersion version: Int) -> Self {
        guard version < ResearchImportPlan.Fields.searchCaptureProvenance.since else { return self }
        var search = self
        search.takeProvenance(of: SearchHistoryEntryExport(id: id, queryText: queryText,
                                                           resultCount: resultCount))
        return search
    }

    /// From a file before version 4, the library's capture provenance.
    public func writtenForImport(over current: Self, fromFormatVersion version: Int) -> Self {
        guard version < ResearchImportPlan.Fields.searchCaptureProvenance.since else { return self }
        var search = self
        search.takeProvenance(of: current)
        return search
    }

    /// Takes the capture provenance of `other`: the fields version 4 added
    /// (``ResearchImportPlan/Fields/searchCaptureProvenance``).
    private mutating func takeProvenance(of other: SearchHistoryEntryExport) {
        loadedCount = other.loadedCount
        matchCount = other.matchCount
        fetchLimit = other.fetchLimit
        indexedVolumeCount = other.indexedVolumeCount
        scopeSignature = other.scopeSignature
        appliedCorpusId = other.appliedCorpusId
        renderedExpression = other.renderedExpression
    }
}

extension ExportHistoryEntryExport: ResearchImportRecord {

    /// `ExportHistoryEntry`.
    public static let importModel = ResearchImportPlan.ModelType.exportHistoryEntry

    /// When the collection was exported.
    public var importStamp: Date? { exportedAt }
}

extension ArchiveVisitPlanExport: ResearchImportRecord {

    /// `ArchiveVisitPlan`.
    public static let importModel = ResearchImportPlan.ModelType.archiveVisitPlan

    /// When the plan was last modified, else when it was made.
    public var importStamp: Date? { lastModified ?? createdAt }

    /// The plan without its documents and targets, which are items of their own.
    public func resolvedForImport(fromFormatVersion version: Int) -> Self {
        var plan = self
        plan.documents = []
        plan.targets = []
        return plan
    }

    /// The library's documents and targets: writing a plan never writes them.
    public func writtenForImport(over current: Self, fromFormatVersion version: Int) -> Self {
        var plan = self
        plan.documents = current.documents
        plan.targets = current.targets
        return plan
    }
}

extension ArchiveVisitDocumentExport: ResearchImportRecord {

    /// `ArchiveVisitDocument`.
    public static let importModel = ResearchImportPlan.ModelType.archiveVisitDocument

    /// When the seed was last modified, else when it was made.
    public var importStamp: Date? { lastModified ?? createdAt }
}

extension ArchiveVisitTargetExport: ResearchImportRecord {

    /// `ArchiveVisitTarget`.
    public static let importModel = ResearchImportPlan.ModelType.archiveVisitTarget

    /// When the target's state was last modified, else when it was made.
    public var importStamp: Date? { lastModified ?? createdAt }
}

extension SavedSearchExport: ResearchImportRecord {

    /// `SavedSearch`.
    public static let importModel = ResearchImportPlan.ModelType.savedSearch

    /// When the saved search was last modified, else when it was made.
    public var importStamp: Date? { lastModified ?? createdAt }
}

extension WorkingCorpusExport: ResearchImportRecord {

    /// `WorkingCorpus`.
    public static let importModel = ResearchImportPlan.ModelType.workingCorpus

    /// When the corpus was last modified, else when it was made.
    public var importStamp: Date? { lastModified ?? createdAt }
}

extension CustomVolumeScopeExport: ResearchImportRecord {

    /// `CustomVolumeScope`.
    public static let importModel = ResearchImportPlan.ModelType.customVolumeScope

    /// When the scope was last modified, else when it was made.
    public var importStamp: Date? { lastModified ?? createdAt }
}

extension DocumentClassificationOverrideExport: ResearchImportRecord {

    /// `DocumentClassificationOverride`.
    public static let importModel = ResearchImportPlan.ModelType.documentClassificationOverride

    /// When the correction was made: it records no change, so the library's copy of one is kept.
    public var importStamp: Date? { createdAt }
}

extension PersonClusterOverrideExport: ResearchImportRecord {

    /// `PersonClusterOverride`.
    public static let importModel = ResearchImportPlan.ModelType.personClusterOverride

    /// When the correction was made: it records no change, so the library's copy of one is kept.
    public var importStamp: Date? { createdAt }
}

extension AnnotationReviewExport: ResearchImportRecord {

    /// `AnnotationReview`.
    public static let importModel = ResearchImportPlan.ModelType.annotationReview

    /// When the passage was reviewed.
    public var importStamp: Date? { reviewedAt }
}

extension ProjectLeadEntryExport: ResearchImportRecord {

    /// `ProjectLeadEntry`.
    public static let importModel = ResearchImportPlan.ModelType.projectLeadEntry

    /// When the lead was last computed.
    public var importStamp: Date? { lastComputedAt }
}

extension SyncedPreferencesExport: ResearchImportRecord {

    /// `SyncedPreferences`.
    public static let importModel = ResearchImportPlan.ModelType.syncedPreferences

    /// When the set was last changed.
    public var importStamp: Date? { updatedAt }
}
