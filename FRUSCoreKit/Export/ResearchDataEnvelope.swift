// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// The research data export's file: the envelope, its records and its tolerant decoder, the format
// version, and the encoder's settings. Moved here unchanged, but `public`, from the app's
// `Export/ResearchDataExporter.swift`, whose `makeEnvelope(modelContext:)` reads SwiftData and
// fills it, so that FRUS Explorer Light, the web edition, reads and writes the app's own file.

// MARK: - ResearchDataEnvelope

/// A versioned snapshot of the user's research data — notes, tags, highlights,
/// collections, user-created prompts, projects, and the research trail — suitable
/// for backup or as an exit ramp from the app.
///
/// `formatVersion` exists so a future importer can detect and migrate older
/// exports. Import itself is out of scope for Session 154.
///
/// ## Why the trail is in here (Wave R-5)
/// Through format version 2 this envelope carried no history at all: every document the user had
/// opened, every search they had run, and every collection they had exported was omitted from the
/// one file the app offers as a way to get their work out. That is not a completeness tick. The
/// Wave R contract's decision **D5** declines to auto-prune the trail *because* Q&CA exports the
/// query log as a **method appendix** — a recorded query with its real hit count, including the
/// zeros, is what makes a claim of absence checkable — and an export that omits the trail cannot
/// serve that purpose. The three arrays are unconditional for the same reason: an appendix behind
/// an opt-out is not an appendix.
///
/// The appendix header is already here and needed nothing new. Q&CA §I-2 asks that the project
/// `name` + `researchQuestion` head the exported appendix exactly as #454/#455 head collection
/// exports; ``exportedForProjectName`` / ``exportedForProjectResearchQuestion`` (#377 Phase 4)
/// are that header, stamped from the active project at export time.
///
/// Version history:
///   1.0 — Session 154: initial implementation
///   2.0 — #377 Phase 4: `exportedForProjectName` / `exportedForProjectResearchQuestion`
///          (the active project this backup was generated under; both optional, so pre-Phase-4
///          files still decode)
///   3.0 — Wave R-5: `readingHistory` / `searchHistory` / `exportHistory` — the three typed
///          research-trail tables. A custom `init(from:)` (see the extension below) defaults all
///          three to empty, so version-1 and version-2 files still decode
///   4.0 — M-2: seven capture-provenance fields on `SearchHistoryEntryExport` (loaded/match/limit,
///          indexed-volume denominator, scope signature, applied corpus, compiled expression). All
///          optional, so a version-3 file still decodes; the bump is what lets a reader tell "this
///          file predates capture provenance" from "these searches recorded none"
///   5.0 — `GeneratedSummaryExport.authorship` — who wrote each summary. Optional so a version-4
///          file still decodes; a file this build writes always carries it, so `nil` on read means
///          only "predates the field". Until now the one export offered as a COMPLETE copy of the
///          researcher's data was the single surface where machine and human text arrived
///          indistinguishable, while every other export path labelled it
///   6.0 — Archive Visits Phase 2: `archiveVisits` — each plan's header, its seeded documents
///          with their contribution flags, its tier definitions, and **every stored target
///          state including orphans** (a stored row whose key no longer derives is still the
///          user's work). Never the derived packet, which is a rendering and not data. Defaults
///          to empty in the tolerant decoder, so version-5-and-earlier files still decode
public struct ResearchDataEnvelope: Codable, Equatable, Sendable {

    /// Schema version of this export. See `ResearchDataEnvelope.currentFormatVersion`.
    public var formatVersion: Int

    /// When this export was generated.
    public var exportedAt: Date

    /// The name of the project active when this export was generated, if any (#377 Phase 4) — a
    /// convenience pointer to *which* project this backup was made under. `nil` in Global Context.
    /// Distinct from the full `projects` array below (which is the complete project backup, always
    /// present); this is just a header. Optional so pre-Phase-4 files still decode.
    public var exportedForProjectName: String?
    /// The research question of that active project, if it has one set (#377 Phase 4).
    public var exportedForProjectResearchQuestion: String?

    public var notes: [ResearchNoteExport]
    public var tags: [UserTagExport]
    public var tagAssignments: [DocumentTagAssignmentExport]
    public var highlights: [DocumentHighlightExport]
    public var collections: [CollectionExport]

    /// User-created prompts only — standard prompts ship with the app and are
    /// excluded (`SummarizationPrompt.isStandard == false`).
    public var prompts: [SummarizationPromptExport]

    public var projects: [ProjectExport]

    /// Empty unless the caller opts in via `includeGeneratedSummaries` — AI
    /// output can be large and is excluded by default.
    public var summaries: [GeneratedSummaryExport]

    // MARK: - The research trail (Wave R-5)

    /// Every recorded document visit, oldest first. See the type's *Why the trail is in here*.
    public var readingHistory: [ReadingHistoryEntryExport] = []

    /// Every recorded search — the query text and the hit count it returned — oldest first.
    /// This is the method appendix's raw material.
    public var searchHistory: [SearchHistoryEntryExport] = []

    /// Every recorded collection export, oldest first.
    public var exportHistory: [ExportHistoryEntryExport] = []

    // MARK: - Archive visits (format version 6)

    /// Every archive visit plan — header, seeds, tiers, and all stored target state, orphans
    /// included. Empty on files written before the feature existed.
    public var archiveVisits: [ArchiveVisitPlanExport] = []

    /// The memberwise initialiser, spelled out because a synthesized one is never `public`.
    public init(
        formatVersion: Int,
        exportedAt: Date,
        exportedForProjectName: String? = nil,
        exportedForProjectResearchQuestion: String? = nil,
        notes: [ResearchNoteExport],
        tags: [UserTagExport],
        tagAssignments: [DocumentTagAssignmentExport],
        highlights: [DocumentHighlightExport],
        collections: [CollectionExport],
        prompts: [SummarizationPromptExport],
        projects: [ProjectExport],
        summaries: [GeneratedSummaryExport],
        readingHistory: [ReadingHistoryEntryExport] = [],
        searchHistory: [SearchHistoryEntryExport] = [],
        exportHistory: [ExportHistoryEntryExport] = [],
        archiveVisits: [ArchiveVisitPlanExport] = []
    ) {
        self.formatVersion = formatVersion
        self.exportedAt = exportedAt
        self.exportedForProjectName = exportedForProjectName
        self.exportedForProjectResearchQuestion = exportedForProjectResearchQuestion
        self.notes = notes
        self.tags = tags
        self.tagAssignments = tagAssignments
        self.highlights = highlights
        self.collections = collections
        self.prompts = prompts
        self.projects = projects
        self.summaries = summaries
        self.readingHistory = readingHistory
        self.searchHistory = searchHistory
        self.exportHistory = exportHistory
        self.archiveVisits = archiveVisits
    }
}

// MARK: - ResearchDataEnvelope + backward-compatible decoding

extension ResearchDataEnvelope {

    /// The envelope's JSON keys, spelled out rather than synthesized.
    ///
    /// Explicit because ``init(from:)`` below is explicit, and because
    /// `ResearchDataExporterTests.exportJSONDataKeysMatchSchema` pins this exact set — a key that
    /// silently appeared or vanished would otherwise change the published file format without
    /// showing up in a diff anyone reads.
    enum CodingKeys: String, CodingKey {
        case formatVersion, exportedAt
        case exportedForProjectName, exportedForProjectResearchQuestion
        case notes, tags, tagAssignments, highlights, collections, prompts, projects, summaries
        case readingHistory, searchHistory, exportHistory
        case archiveVisits
    }

    /// Decodes an envelope, tolerating files written before the trail existed.
    ///
    /// ## Why this is hand-written
    /// Swift's synthesized `Decodable` **ignores a property's default value** — `var
    /// readingHistory: [ReadingHistoryEntryExport] = []` still makes the key mandatory, so adding
    /// the three arrays to a synthesized decoder would have made every version-1 and version-2
    /// file undecodable. That is not hypothetical: `ResearchDataExporterTests.legacyJSONDecodes`
    /// decodes exactly such a file, and #377 Phase 4 took the same care with the two header
    /// fields (by making them `Optional`, which the synthesizer does honour). An array that is
    /// semantically "none recorded" should not have to be `nil` to say so, hence `decodeIfPresent
    /// … ?? []` instead.
    ///
    /// Only the three trail arrays and the archive-visits array (format 6) are tolerant.
    /// Everything else stays required, so a truncated or corrupt file still fails loudly rather
    /// than decoding into a plausible-looking empty backup.
    ///
    /// `encode(to:)` remains synthesized — this initializer lives in an extension precisely so the
    /// memberwise initializer survives for ``ResearchDataExporter/makeEnvelope(modelContext:includeGeneratedSummaries:activeProjectId:)``.
    /// (In FRUSCoreKit that initializer is spelled out on the type, since a synthesized one is never
    /// `public`.)
    ///
    /// - Parameter decoder: The decoder to read from.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        formatVersion = try container.decode(Int.self, forKey: .formatVersion)
        exportedAt = try container.decode(Date.self, forKey: .exportedAt)
        exportedForProjectName =
            try container.decodeIfPresent(String.self, forKey: .exportedForProjectName)
        exportedForProjectResearchQuestion =
            try container.decodeIfPresent(String.self, forKey: .exportedForProjectResearchQuestion)
        notes = try container.decode([ResearchNoteExport].self, forKey: .notes)
        tags = try container.decode([UserTagExport].self, forKey: .tags)
        tagAssignments =
            try container.decode([DocumentTagAssignmentExport].self, forKey: .tagAssignments)
        highlights = try container.decode([DocumentHighlightExport].self, forKey: .highlights)
        collections = try container.decode([CollectionExport].self, forKey: .collections)
        prompts = try container.decode([SummarizationPromptExport].self, forKey: .prompts)
        projects = try container.decode([ProjectExport].self, forKey: .projects)
        summaries = try container.decode([GeneratedSummaryExport].self, forKey: .summaries)
        readingHistory =
            try container.decodeIfPresent([ReadingHistoryEntryExport].self,
                                          forKey: .readingHistory) ?? []
        searchHistory =
            try container.decodeIfPresent([SearchHistoryEntryExport].self,
                                          forKey: .searchHistory) ?? []
        exportHistory =
            try container.decodeIfPresent([ExportHistoryEntryExport].self,
                                          forKey: .exportHistory) ?? []
        archiveVisits =
            try container.decodeIfPresent([ArchiveVisitPlanExport].self,
                                          forKey: .archiveVisits) ?? []
    }
}

// MARK: - ResearchNoteExport

/// Export DTO mirroring `ResearchNote`.
public struct ResearchNoteExport: Codable, Equatable, Sendable {
    public var id: UUID
    public var documentId: String
    public var volumeId: String
    public var bodyText: String
    public var projectIds: [UUID]
    public var userTagIds: [UUID]
    public var selectedSummaryIds: [UUID]

    /// IDs of `DocumentHighlight` records whose `noteId` points back at this note.
    public var linkedHighlightIds: [UUID]

    public var createdAt: Date?
    public var lastModified: Date?

    /// The memberwise initialiser, spelled out because a synthesized one is never `public`.
    public init(
        id: UUID,
        documentId: String,
        volumeId: String,
        bodyText: String,
        projectIds: [UUID],
        userTagIds: [UUID],
        selectedSummaryIds: [UUID],
        linkedHighlightIds: [UUID],
        createdAt: Date? = nil,
        lastModified: Date? = nil
    ) {
        self.id = id
        self.documentId = documentId
        self.volumeId = volumeId
        self.bodyText = bodyText
        self.projectIds = projectIds
        self.userTagIds = userTagIds
        self.selectedSummaryIds = selectedSummaryIds
        self.linkedHighlightIds = linkedHighlightIds
        self.createdAt = createdAt
        self.lastModified = lastModified
    }
}

// MARK: - UserTagExport

/// Export DTO mirroring `UserTag`.
public struct UserTagExport: Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var createdAt: Date?
    public var lastModified: Date?

    /// The memberwise initialiser, spelled out because a synthesized one is never `public`.
    public init(id: UUID, name: String, createdAt: Date? = nil, lastModified: Date? = nil) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.lastModified = lastModified
    }
}

// MARK: - DocumentTagAssignmentExport

/// Export DTO mirroring `DocumentTagAssignment`.
public struct DocumentTagAssignmentExport: Codable, Equatable, Sendable {
    public var id: UUID
    public var volumeId: String
    public var documentId: String
    public var tagId: UUID
    public var createdAt: Date?

    /// The memberwise initialiser, spelled out because a synthesized one is never `public`.
    public init(
        id: UUID,
        volumeId: String,
        documentId: String,
        tagId: UUID,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.volumeId = volumeId
        self.documentId = documentId
        self.tagId = tagId
        self.createdAt = createdAt
    }
}

// MARK: - DocumentHighlightExport

/// Export DTO mirroring `DocumentHighlight`.
public struct DocumentHighlightExport: Codable, Equatable, Sendable {
    public var id: UUID
    public var volumeId: String
    public var documentId: String
    public var startOffset: Int
    public var endOffset: Int
    public var colorTag: String
    public var noteId: UUID?
    public var selectedText: String
    public var renderingVersion: String
    public var createdAt: Date?

    /// The memberwise initialiser, spelled out because a synthesized one is never `public`.
    public init(
        id: UUID,
        volumeId: String,
        documentId: String,
        startOffset: Int,
        endOffset: Int,
        colorTag: String,
        noteId: UUID? = nil,
        selectedText: String,
        renderingVersion: String,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.volumeId = volumeId
        self.documentId = documentId
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.colorTag = colorTag
        self.noteId = noteId
        self.selectedText = selectedText
        self.renderingVersion = renderingVersion
        self.createdAt = createdAt
    }
}

// MARK: - CollectionEntryExport

/// Export DTO mirroring `CollectionEntry`.
public struct CollectionEntryExport: Codable, Equatable, Sendable {
    public var id: UUID
    public var documentId: String
    public var volumeId: String
    public var sortOrder: Int
    public var researchNoteId: UUID?
    public var selectedNoteIds: [UUID]
    public var createdAt: Date?
    public var lastModified: Date?

    /// The memberwise initialiser, spelled out because a synthesized one is never `public`.
    public init(
        id: UUID,
        documentId: String,
        volumeId: String,
        sortOrder: Int,
        researchNoteId: UUID? = nil,
        selectedNoteIds: [UUID],
        createdAt: Date? = nil,
        lastModified: Date? = nil
    ) {
        self.id = id
        self.documentId = documentId
        self.volumeId = volumeId
        self.sortOrder = sortOrder
        self.researchNoteId = researchNoteId
        self.selectedNoteIds = selectedNoteIds
        self.createdAt = createdAt
        self.lastModified = lastModified
    }
}

// MARK: - CollectionExport

/// Export DTO mirroring `Collection`, including its ordered `CollectionEntry` items.
public struct CollectionExport: Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var note: String?
    public var projectIds: [UUID]
    public var savedSearchId: UUID?

    /// Sorted by `CollectionEntry.sortOrder` ascending.
    public var entries: [CollectionEntryExport]

    public var createdAt: Date?
    public var lastModified: Date?

    /// The memberwise initialiser, spelled out because a synthesized one is never `public`.
    public init(
        id: UUID,
        name: String,
        note: String? = nil,
        projectIds: [UUID],
        savedSearchId: UUID? = nil,
        entries: [CollectionEntryExport],
        createdAt: Date? = nil,
        lastModified: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.note = note
        self.projectIds = projectIds
        self.savedSearchId = savedSearchId
        self.entries = entries
        self.createdAt = createdAt
        self.lastModified = lastModified
    }
}

// MARK: - SummarizationPromptExport

/// Export DTO mirroring a user-created `SummarizationPrompt`
/// (`isStandard == false`).
public struct SummarizationPromptExport: Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var promptText: String
    public var responseFormat: ResponseFormat
    public var schema: StructuredSummarySchema?
    public var createdAt: Date?
    public var lastModified: Date?

    /// The memberwise initialiser, spelled out because a synthesized one is never `public`.
    public init(
        id: UUID,
        name: String,
        promptText: String,
        responseFormat: ResponseFormat,
        schema: StructuredSummarySchema? = nil,
        createdAt: Date? = nil,
        lastModified: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.promptText = promptText
        self.responseFormat = responseFormat
        self.schema = schema
        self.createdAt = createdAt
        self.lastModified = lastModified
    }
}

// MARK: - ProjectExport

/// Export DTO mirroring `Project`.
public struct ProjectExport: Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var researchQuestion: String?
    public var defaultDateRangeStart: Date?
    public var defaultDateRangeEnd: Date?
    public var defaultSubjectTagIds: [String]
    public var defaultCountryTagIds: [String]
    public var createdAt: Date?
    public var lastModified: Date?

    /// The memberwise initialiser, spelled out because a synthesized one is never `public`.
    public init(
        id: UUID,
        name: String,
        researchQuestion: String? = nil,
        defaultDateRangeStart: Date? = nil,
        defaultDateRangeEnd: Date? = nil,
        defaultSubjectTagIds: [String],
        defaultCountryTagIds: [String],
        createdAt: Date? = nil,
        lastModified: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.researchQuestion = researchQuestion
        self.defaultDateRangeStart = defaultDateRangeStart
        self.defaultDateRangeEnd = defaultDateRangeEnd
        self.defaultSubjectTagIds = defaultSubjectTagIds
        self.defaultCountryTagIds = defaultCountryTagIds
        self.createdAt = createdAt
        self.lastModified = lastModified
    }
}

// MARK: - GeneratedSummaryExport

/// Export DTO mirroring `GeneratedSummary`. Only populated when the caller opts
/// into `includeGeneratedSummaries` — see `ResearchDataEnvelope.summaries`.
public struct GeneratedSummaryExport: Codable, Equatable, Sendable {
    public var id: UUID
    public var documentId: String
    public var volumeId: String
    public var promptId: UUID
    public var responseText: String
    public var responseFormat: ResponseFormat
    public var wasChunked: Bool
    public var projectId: UUID?
    public var createdAt: Date?
    public var lastModified: Date?

    /// Who wrote this text — machine, machine-then-edited, or the researcher.
    ///
    /// ## Why this is not optional in practice
    /// The app labels AI-generated content wherever it is displayed or exported: the collection
    /// exporters branch on exactly this value to decide whether an artifact carries an AI
    /// attribution line, and `.userWritten` deliberately carries none. This file shipped without
    /// it, so the one export a researcher is told is their **complete** data — the exit ramp —
    /// was the single surface where machine and human text arrived indistinguishable.
    ///
    /// Declared `Optional` **only** so a version-4-or-earlier file still decodes: Swift's
    /// synthesized `Decodable` ignores a property's default, so a non-optional field here would
    /// make the key mandatory and break every existing export. A file this build *writes* always
    /// carries a value, so `nil` on read means exactly one thing — the file predates this field.
    ///
    /// The model's own property is optional for an unrelated reason (a legacy CloudKit NULL would
    /// trap a non-optional enum getter), and every read site in the app coerces that `nil` to
    /// `.aiGenerated`. The app's mapping (`ResearchDataExporter.makeEnvelope`) does the same, so an
    /// exported file never has to be decoded through a rule the reader cannot see.
    public var authorship: SummaryAuthorship?

    /// The memberwise initialiser, spelled out because a synthesized one is never `public`.
    public init(
        id: UUID,
        documentId: String,
        volumeId: String,
        promptId: UUID,
        responseText: String,
        responseFormat: ResponseFormat,
        wasChunked: Bool,
        projectId: UUID? = nil,
        createdAt: Date? = nil,
        lastModified: Date? = nil,
        authorship: SummaryAuthorship? = nil
    ) {
        self.id = id
        self.documentId = documentId
        self.volumeId = volumeId
        self.promptId = promptId
        self.responseText = responseText
        self.responseFormat = responseFormat
        self.wasChunked = wasChunked
        self.projectId = projectId
        self.createdAt = createdAt
        self.lastModified = lastModified
        self.authorship = authorship
    }
}

// MARK: - ReadingHistoryEntryExport

/// Export DTO mirroring `ReadingHistoryEntry` — one recorded document visit (Wave R-5).
public struct ReadingHistoryEntryExport: Codable, Equatable, Sendable {
    public var id: UUID
    public var documentId: String
    public var volumeId: String

    /// The document's title as captured at read time, or `nil` on entries written before that
    /// field existed — those display as `volumeId · documentId`.
    public var displayTitle: String?

    /// The project active when the document was opened, or `nil` for global context. Stamped at
    /// write time: switching projects later does not re-attribute it.
    public var projectId: UUID?

    public var accessedAt: Date?

    /// The memberwise initialiser, spelled out because a synthesized one is never `public`.
    public init(
        id: UUID,
        documentId: String,
        volumeId: String,
        displayTitle: String? = nil,
        projectId: UUID? = nil,
        accessedAt: Date? = nil
    ) {
        self.id = id
        self.documentId = documentId
        self.volumeId = volumeId
        self.displayTitle = displayTitle
        self.projectId = projectId
        self.accessedAt = accessedAt
    }
}

// MARK: - SearchHistoryEntryExport

/// Export DTO mirroring `SearchHistoryEntry` — one recorded search (Wave R-5).
///
/// This is the row the Q&CA method appendix is built from: the query as submitted, and the hit
/// count it actually returned. A recorded **zero** is the point, not an omission — it is what
/// turns "I found nothing on this" into a checkable claim.
public struct SearchHistoryEntryExport: Codable, Equatable, Sendable {
    public var id: UUID

    /// The submitted query text, trimmed.
    public var queryText: String

    /// The headline number both platforms display, at execution time — not now.
    ///
    /// On its own this cannot be read safely: a macOS row of 7,500 may be a total or a floor. The
    /// M-2 fields below are what tell those apart, and `QueryMethodAppendix` is where they are
    /// rendered as a statement a reader can check. Kept unchanged so version-3 files still decode.
    public var resultCount: Int

    public var projectId: UUID?
    public var executedAt: Date?

    // MARK: - Capture provenance (format version 4, M-2)

    /// What the fetch returned, capped at ``fetchLimit`` — the Q wave's **loaded**.
    public var loadedCount: Int?

    /// Every document matching the query — the Q wave's **match**. `nil` where the count was
    /// unavailable *or* the row predates M-2; ``fetchLimit`` tells those apart.
    public var matchCount: Int?

    /// The fetch ceiling in force (1,000 on iOS, 7,500 on macOS), and the legacy discriminator:
    /// `nil` if and only if the row was written before M-2.
    public var fetchLimit: Int?

    /// How many volumes the device had indexed when the search ran — the denominator.
    public var indexedVolumeCount: Int?

    /// The canonical, non-localized scope key. See `SearchScopeSignature`.
    public var scopeSignature: String?

    /// The working corpus the search ran inside, by id.
    public var appliedCorpusId: UUID?

    /// The FTS5 expression the query compiled to.
    public var renderedExpression: String?

    /// The memberwise initialiser, spelled out because a synthesized one is never `public`.
    public init(
        id: UUID,
        queryText: String,
        resultCount: Int,
        projectId: UUID? = nil,
        executedAt: Date? = nil,
        loadedCount: Int? = nil,
        matchCount: Int? = nil,
        fetchLimit: Int? = nil,
        indexedVolumeCount: Int? = nil,
        scopeSignature: String? = nil,
        appliedCorpusId: UUID? = nil,
        renderedExpression: String? = nil
    ) {
        self.id = id
        self.queryText = queryText
        self.resultCount = resultCount
        self.projectId = projectId
        self.executedAt = executedAt
        self.loadedCount = loadedCount
        self.matchCount = matchCount
        self.fetchLimit = fetchLimit
        self.indexedVolumeCount = indexedVolumeCount
        self.scopeSignature = scopeSignature
        self.appliedCorpusId = appliedCorpusId
        self.renderedExpression = renderedExpression
    }
}

// MARK: - ArchiveVisitPlanExport

/// Export DTO mirroring `ArchiveVisitPlan`, with its seeds, tiers, and stored target state
/// (format version 6).
///
/// Carries the user's WORK, never the derived packet: the rendered artifact is a rendering,
/// re-derivable from these seeds against any index, and freezing one into the backup would
/// present a stale rendering as data. `tiers` reuses `ArchiveVisitTier` directly — it is
/// already the pure `Codable` value the plan stores — and `deliverables` exports the RESOLVED
/// toggles rather than the raw blob, so a reader needs no knowledge of the app's defaults.
public struct ArchiveVisitPlanExport: Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var inquiryText: String?
    public var projectIds: [UUID]
    public var tiers: [ArchiveVisitTier]
    public var deliverables: ArchiveVisitDeliverables
    public var documents: [ArchiveVisitDocumentExport]
    /// Every stored per-target state row — **orphans included**: a row whose key no longer
    /// derives from the seeds is still the user's tier and note.
    public var targets: [ArchiveVisitTargetExport]
    public var createdAt: Date?
    public var lastModified: Date?

    /// The memberwise initialiser, spelled out because a synthesized one is never `public`.
    public init(
        id: UUID,
        name: String,
        inquiryText: String? = nil,
        projectIds: [UUID],
        tiers: [ArchiveVisitTier],
        deliverables: ArchiveVisitDeliverables,
        documents: [ArchiveVisitDocumentExport],
        targets: [ArchiveVisitTargetExport],
        createdAt: Date? = nil,
        lastModified: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.inquiryText = inquiryText
        self.projectIds = projectIds
        self.tiers = tiers
        self.deliverables = deliverables
        self.documents = documents
        self.targets = targets
        self.createdAt = createdAt
        self.lastModified = lastModified
    }
}

// MARK: - ArchiveVisitDocumentExport

/// Export DTO mirroring `ArchiveVisitDocument` — one seed with its contribution flags.
public struct ArchiveVisitDocumentExport: Codable, Equatable, Sendable {
    public var id: UUID
    public var documentKey: String
    public var includeSource: Bool
    public var includeExternalRefs: Bool
    public var createdAt: Date?
    public var lastModified: Date?

    /// The memberwise initialiser, spelled out because a synthesized one is never `public`.
    public init(
        id: UUID,
        documentKey: String,
        includeSource: Bool,
        includeExternalRefs: Bool,
        createdAt: Date? = nil,
        lastModified: Date? = nil
    ) {
        self.id = id
        self.documentKey = documentKey
        self.includeSource = includeSource
        self.includeExternalRefs = includeExternalRefs
        self.createdAt = createdAt
        self.lastModified = lastModified
    }
}

// MARK: - ArchiveVisitTargetExport

/// Export DTO mirroring `ArchiveVisitTarget` — one stored target state.
public struct ArchiveVisitTargetExport: Codable, Equatable, Sendable {
    public var id: UUID
    public var targetKey: String
    public var tierId: UUID?
    public var included: Bool
    public var userNote: String?
    public var createdAt: Date?
    public var lastModified: Date?

    /// The memberwise initialiser, spelled out because a synthesized one is never `public`.
    public init(
        id: UUID,
        targetKey: String,
        tierId: UUID? = nil,
        included: Bool,
        userNote: String? = nil,
        createdAt: Date? = nil,
        lastModified: Date? = nil
    ) {
        self.id = id
        self.targetKey = targetKey
        self.tierId = tierId
        self.included = included
        self.userNote = userNote
        self.createdAt = createdAt
        self.lastModified = lastModified
    }
}

// MARK: - ExportHistoryEntryExport

/// Export DTO mirroring `ExportHistoryEntry` — one recorded collection export (Wave R-5).
public struct ExportHistoryEntryExport: Codable, Equatable, Sendable {
    public var id: UUID

    /// `ExportFormat.rawValue`, or `"zotero-api"` for the Zotero Web-API push — the one value
    /// that is not a member of that enum, kept verbatim so migrated and live rows read alike.
    public var format: String

    public var documentCount: Int

    /// The collection's name at export time, or `nil`. Absent on rows migrated from the retired
    /// `SessionEvent`, whose payload carried only the format and the count.
    public var collectionName: String?

    public var projectId: UUID?
    public var exportedAt: Date?

    /// The memberwise initialiser, spelled out because a synthesized one is never `public`.
    public init(
        id: UUID,
        format: String,
        documentCount: Int,
        collectionName: String? = nil,
        projectId: UUID? = nil,
        exportedAt: Date? = nil
    ) {
        self.id = id
        self.format = format
        self.documentCount = documentCount
        self.collectionName = collectionName
        self.projectId = projectId
        self.exportedAt = exportedAt
    }
}

// MARK: - ResearchDataEnvelope + format version and encoding

extension ResearchDataEnvelope {

    /// Current `ResearchDataEnvelope.formatVersion`. Bump when making a breaking
    /// change to the export schema; a future importer can branch on this value.
    ///
    /// (No importer exists yet. Every reader is nonetheless kept working in both directions: the
    /// Phase-4 header fields are optional and the Wave R-5 trail arrays default to empty, so a
    /// v1 or v2 file still decodes here — and a v3 file read by something that ignores the three
    /// new keys is unaffected. The bump to 3 is what lets such a reader tell "this file predates
    /// the trail" from "this user's trail was empty", which a purely additive change would
    /// otherwise make indistinguishable. The bump to 4 carries the same argument for M-2's
    /// capture-provenance fields: an all-`nil` v4 row means the searches were recorded without it,
    /// while a v3 file means the format could not carry it. The bump to 5 is the same argument once
    /// more, and a sharper one: summary `authorship` is never `nil` in a file this build writes, so
    /// the version is the *only* thing that distinguishes an unattributed old export from a new
    /// one. The bump to 6 carries Archive Visits: an empty v6 `archiveVisits` array means the
    /// user had no plans, while a v5 file means the format could not carry them.)
    ///
    /// Declared here, beside the envelope, since FRUS Explorer Light moved the envelope into
    /// FRUSCoreKit; the app's `ResearchDataExporter.currentFormatVersion` is this value.
    public static let currentFormatVersion = 6

    /// The encoder an export is written with: pretty-printed, key-sorted JSON with ISO-8601 dates.
    ///
    /// The app's `ResearchDataExporter.exportJSONData(_:)` writes with it, so a host outside the app
    /// writes the same bytes for the same envelope.
    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    /// The decoder that reads an export back: ISO-8601 dates, as `makeEncoder()` writes them.
    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// This envelope as an export's JSON, written by `makeEncoder()`.
    public func jsonData() throws -> Data {
        try Self.makeEncoder().encode(self)
    }
}
