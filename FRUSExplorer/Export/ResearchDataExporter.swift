// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData
import SQLite3

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
struct ResearchDataEnvelope: Codable, Equatable, Sendable {

    /// Schema version of this export. See `ResearchDataExporter.currentFormatVersion`.
    var formatVersion: Int

    /// When this export was generated.
    var exportedAt: Date

    /// The name of the project active when this export was generated, if any (#377 Phase 4) — a
    /// convenience pointer to *which* project this backup was made under. `nil` in Global Context.
    /// Distinct from the full `projects` array below (which is the complete project backup, always
    /// present); this is just a header. Optional so pre-Phase-4 files still decode.
    var exportedForProjectName: String?
    /// The research question of that active project, if it has one set (#377 Phase 4).
    var exportedForProjectResearchQuestion: String?

    var notes: [ResearchNoteExport]
    var tags: [UserTagExport]
    var tagAssignments: [DocumentTagAssignmentExport]
    var highlights: [DocumentHighlightExport]
    var collections: [CollectionExport]

    /// User-created prompts only — standard prompts ship with the app and are
    /// excluded (`SummarizationPrompt.isStandard == false`).
    var prompts: [SummarizationPromptExport]

    var projects: [ProjectExport]

    /// Empty unless the caller opts in via `includeGeneratedSummaries` — AI
    /// output can be large and is excluded by default.
    var summaries: [GeneratedSummaryExport]

    // MARK: - The research trail (Wave R-5)

    /// Every recorded document visit, oldest first. See the type's *Why the trail is in here*.
    var readingHistory: [ReadingHistoryEntryExport] = []

    /// Every recorded search — the query text and the hit count it returned — oldest first.
    /// This is the method appendix's raw material.
    var searchHistory: [SearchHistoryEntryExport] = []

    /// Every recorded collection export, oldest first.
    var exportHistory: [ExportHistoryEntryExport] = []

    // MARK: - Archive visits (format version 6)

    /// Every archive visit plan — header, seeds, tiers, and all stored target state, orphans
    /// included. Empty on files written before the feature existed.
    var archiveVisits: [ArchiveVisitPlanExport] = []
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
    ///
    /// - Parameter decoder: The decoder to read from.
    init(from decoder: any Decoder) throws {
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
struct ResearchNoteExport: Codable, Equatable, Sendable {
    var id: UUID
    var documentId: String
    var volumeId: String
    var bodyText: String
    var projectIds: [UUID]
    var userTagIds: [UUID]
    var selectedSummaryIds: [UUID]

    /// IDs of `DocumentHighlight` records whose `noteId` points back at this note.
    var linkedHighlightIds: [UUID]

    var createdAt: Date?
    var lastModified: Date?
}

// MARK: - UserTagExport

/// Export DTO mirroring `UserTag`.
struct UserTagExport: Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var createdAt: Date?
    var lastModified: Date?
}

// MARK: - DocumentTagAssignmentExport

/// Export DTO mirroring `DocumentTagAssignment`.
struct DocumentTagAssignmentExport: Codable, Equatable, Sendable {
    var id: UUID
    var volumeId: String
    var documentId: String
    var tagId: UUID
    var createdAt: Date?
}

// MARK: - DocumentHighlightExport

/// Export DTO mirroring `DocumentHighlight`.
struct DocumentHighlightExport: Codable, Equatable, Sendable {
    var id: UUID
    var volumeId: String
    var documentId: String
    var startOffset: Int
    var endOffset: Int
    var colorTag: String
    var noteId: UUID?
    var selectedText: String
    var renderingVersion: String
    var createdAt: Date?
}

// MARK: - CollectionEntryExport

/// Export DTO mirroring `CollectionEntry`.
struct CollectionEntryExport: Codable, Equatable, Sendable {
    var id: UUID
    var documentId: String
    var volumeId: String
    var sortOrder: Int
    var researchNoteId: UUID?
    var selectedNoteIds: [UUID]
    var createdAt: Date?
    var lastModified: Date?
}

// MARK: - CollectionExport

/// Export DTO mirroring `Collection`, including its ordered `CollectionEntry` items.
struct CollectionExport: Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var note: String?
    var projectIds: [UUID]
    var savedSearchId: UUID?

    /// Sorted by `CollectionEntry.sortOrder` ascending.
    var entries: [CollectionEntryExport]

    var createdAt: Date?
    var lastModified: Date?
}

// MARK: - SummarizationPromptExport

/// Export DTO mirroring a user-created `SummarizationPrompt`
/// (`isStandard == false`).
struct SummarizationPromptExport: Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var promptText: String
    var responseFormat: ResponseFormat
    var schema: StructuredSummarySchema?
    var createdAt: Date?
    var lastModified: Date?
}

// MARK: - ProjectExport

/// Export DTO mirroring `Project`.
struct ProjectExport: Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var researchQuestion: String?
    var defaultDateRangeStart: Date?
    var defaultDateRangeEnd: Date?
    var defaultSubjectTagIds: [String]
    var defaultCountryTagIds: [String]
    var createdAt: Date?
    var lastModified: Date?
}

// MARK: - GeneratedSummaryExport

/// Export DTO mirroring `GeneratedSummary`. Only populated when the caller opts
/// into `includeGeneratedSummaries` — see `ResearchDataEnvelope.summaries`.
struct GeneratedSummaryExport: Codable, Equatable, Sendable {
    var id: UUID
    var documentId: String
    var volumeId: String
    var promptId: UUID
    var responseText: String
    var responseFormat: ResponseFormat
    var wasChunked: Bool
    var projectId: UUID?
    var createdAt: Date?
    var lastModified: Date?

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
    /// `.aiGenerated`. The mapping below does the same, so an exported file never has to be
    /// decoded through a rule the reader cannot see.
    var authorship: SummaryAuthorship?
}

// MARK: - ReadingHistoryEntryExport

/// Export DTO mirroring `ReadingHistoryEntry` — one recorded document visit (Wave R-5).
struct ReadingHistoryEntryExport: Codable, Equatable, Sendable {
    var id: UUID
    var documentId: String
    var volumeId: String

    /// The document's title as captured at read time, or `nil` on entries written before that
    /// field existed — those display as `volumeId · documentId`.
    var displayTitle: String?

    /// The project active when the document was opened, or `nil` for global context. Stamped at
    /// write time: switching projects later does not re-attribute it.
    var projectId: UUID?

    var accessedAt: Date?
}

// MARK: - SearchHistoryEntryExport

/// Export DTO mirroring `SearchHistoryEntry` — one recorded search (Wave R-5).
///
/// This is the row the Q&CA method appendix is built from: the query as submitted, and the hit
/// count it actually returned. A recorded **zero** is the point, not an omission — it is what
/// turns "I found nothing on this" into a checkable claim.
struct SearchHistoryEntryExport: Codable, Equatable, Sendable {
    var id: UUID

    /// The submitted query text, trimmed.
    var queryText: String

    /// The headline number both platforms display, at execution time — not now.
    ///
    /// On its own this cannot be read safely: a macOS row of 7,500 may be a total or a floor. The
    /// M-2 fields below are what tell those apart, and `QueryMethodAppendix` is where they are
    /// rendered as a statement a reader can check. Kept unchanged so version-3 files still decode.
    var resultCount: Int

    var projectId: UUID?
    var executedAt: Date?

    // MARK: - Capture provenance (format version 4, M-2)

    /// What the fetch returned, capped at ``fetchLimit`` — the Q wave's **loaded**.
    var loadedCount: Int?

    /// Every document matching the query — the Q wave's **match**. `nil` where the count was
    /// unavailable *or* the row predates M-2; ``fetchLimit`` tells those apart.
    var matchCount: Int?

    /// The fetch ceiling in force (1,000 on iOS, 7,500 on macOS), and the legacy discriminator:
    /// `nil` if and only if the row was written before M-2.
    var fetchLimit: Int?

    /// How many volumes the device had indexed when the search ran — the denominator.
    var indexedVolumeCount: Int?

    /// The canonical, non-localized scope key. See `SearchScopeSignature`.
    var scopeSignature: String?

    /// The working corpus the search ran inside, by id.
    var appliedCorpusId: UUID?

    /// The FTS5 expression the query compiled to.
    var renderedExpression: String?
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
struct ArchiveVisitPlanExport: Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var inquiryText: String?
    var projectIds: [UUID]
    var tiers: [ArchiveVisitTier]
    var deliverables: ArchiveVisitDeliverables
    var documents: [ArchiveVisitDocumentExport]
    /// Every stored per-target state row — **orphans included**: a row whose key no longer
    /// derives from the seeds is still the user's tier and note.
    var targets: [ArchiveVisitTargetExport]
    var createdAt: Date?
    var lastModified: Date?
}

// MARK: - ArchiveVisitDocumentExport

/// Export DTO mirroring `ArchiveVisitDocument` — one seed with its contribution flags.
struct ArchiveVisitDocumentExport: Codable, Equatable, Sendable {
    var id: UUID
    var documentKey: String
    var includeSource: Bool
    var includeExternalRefs: Bool
    var createdAt: Date?
    var lastModified: Date?
}

// MARK: - ArchiveVisitTargetExport

/// Export DTO mirroring `ArchiveVisitTarget` — one stored target state.
struct ArchiveVisitTargetExport: Codable, Equatable, Sendable {
    var id: UUID
    var targetKey: String
    var tierId: UUID?
    var included: Bool
    var userNote: String?
    var createdAt: Date?
    var lastModified: Date?
}

// MARK: - ExportHistoryEntryExport

/// Export DTO mirroring `ExportHistoryEntry` — one recorded collection export (Wave R-5).
struct ExportHistoryEntryExport: Codable, Equatable, Sendable {
    var id: UUID

    /// `ExportFormat.rawValue`, or `"zotero-api"` for the Zotero Web-API push — the one value
    /// that is not a member of that enum, kept verbatim so migrated and live rows read alike.
    var format: String

    var documentCount: Int

    /// The collection's name at export time, or `nil`. Absent on rows migrated from the retired
    /// `SessionEvent`, whose payload carried only the format and the count.
    var collectionName: String?

    var projectId: UUID?
    var exportedAt: Date?
}

// MARK: - ResearchNoteMarkdownExport

/// A single rendered Markdown file for a `ResearchNote`, with YAML front matter
/// linking back to the source document.
///
/// Produced by `ResearchDataExporter.markdownExports(notes:tags:appState:)` for
/// the per-note, Obsidian-style export.
struct ResearchNoteMarkdownExport: Identifiable, Sendable {

    /// The source `ResearchNote.id`.
    let id: UUID

    /// Suggested filename, unique per note.
    let filename: String

    /// Full file contents: YAML front matter followed by the note body.
    let content: String
}

// MARK: - ResearchDataExporter

/// Builds and serializes a `ResearchDataEnvelope` from the user's SwiftData store,
/// and renders per-note Markdown files for interop with Obsidian-style tools.
///
/// Entry point: `DataExportSections`, the **Contents** and export rows at the top of
/// Settings ▸ System ▸ **Data & Recovery** (`DataRecoveryView`). One declaration on both
/// platforms — the separate macOS `SettingsDataPane` this comment used to name was folded into
/// `DataRecoveryView` by S-4b and no longer exists.
///
/// Version history:
///   1.0 — Session 154: initial implementation
///   1.1 — Wave R-5: the envelope carries the research trail, and the stale `SettingsDataPane`
///          entry point above was corrected
@MainActor
enum ResearchDataExporter {

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
    static let currentFormatVersion = 6

    /// Builds an envelope from the current contents of `modelContext`.
    ///
    /// - Parameters:
    ///   - modelContext: The SwiftData context to read from.
    ///   - includeGeneratedSummaries: When `true`, populates `summaries` from
    ///     all `GeneratedSummary` records.
    ///   - activeProjectId: The active project (#377 Phase 4), recorded in the envelope header as
    ///     the project this backup was generated under. `nil` (Global Context) → no header project.
    static func makeEnvelope(
        modelContext: ModelContext,
        includeGeneratedSummaries: Bool,
        activeProjectId: UUID? = nil
    ) throws -> ResearchDataEnvelope {
        let notes = try modelContext.fetch(FetchDescriptor<ResearchNote>())
        let tags = try modelContext.fetch(FetchDescriptor<UserTag>())
        let tagAssignments = try modelContext.fetch(FetchDescriptor<DocumentTagAssignment>())
        let highlights = try modelContext.fetch(FetchDescriptor<DocumentHighlight>())
        let collections = try modelContext.fetch(FetchDescriptor<Collection>())
        let prompts = try modelContext.fetch(FetchDescriptor<SummarizationPrompt>())
        let projects = try modelContext.fetch(FetchDescriptor<Project>())
        let summaries = includeGeneratedSummaries
            ? try modelContext.fetch(FetchDescriptor<GeneratedSummary>())
            : []

        // The research trail (Wave R-5). Unconditional — see `ResearchDataEnvelope`'s note on D5.
        // Sorted oldest-first in the fetch rather than after the fact: an appendix is read forward
        // in time, and sorting in the descriptor also makes the file deterministic, which raw
        // fetch order (which CloudKit can reorder between runs) is not. Rows with a `nil`
        // timestamp — possible only via the optional-for-CloudKit columns — sort to the front.
        let readingHistory = try modelContext.fetch(
            FetchDescriptor<ReadingHistoryEntry>(sortBy: [SortDescriptor(\.accessedAt)]))
        let searchHistory = try modelContext.fetch(
            FetchDescriptor<SearchHistoryEntry>(sortBy: [SortDescriptor(\.executedAt)]))
        let exportHistory = try modelContext.fetch(
            FetchDescriptor<ExportHistoryEntry>(sortBy: [SortDescriptor(\.exportedAt)]))

        // Archive visits (format version 6). Sorted by name-then-id so the file is
        // deterministic, like the trail fetches above.
        let archiveVisits = try modelContext.fetch(
            FetchDescriptor<ArchiveVisitPlan>(sortBy: [SortDescriptor(\.name),
                                                       SortDescriptor(\.createdAt)]))

        let highlightsByNoteId = Dictionary(grouping: highlights, by: \.noteId)

        // The active project's header pointer (#377 Phase 4) — resolved against the already-fetched
        // `projects`, so no extra fetch. `nil` id or no match → no header project.
        let activeProject = activeProjectId.flatMap { id in projects.first { $0.id == id } }

        return ResearchDataEnvelope(
            formatVersion: currentFormatVersion,
            exportedAt: .now,
            exportedForProjectName: activeProject?.name,
            exportedForProjectResearchQuestion: activeProject?.researchQuestion,
            notes: notes.map { note in
                ResearchNoteExport(
                    id: note.id,
                    documentId: note.documentId,
                    volumeId: note.volumeId,
                    bodyText: note.bodyText,
                    projectIds: note.projectIds,
                    userTagIds: note.userTagIds,
                    selectedSummaryIds: note.selectedSummaryIds,
                    linkedHighlightIds: (highlightsByNoteId[note.id] ?? []).map(\.id),
                    createdAt: note.createdAt,
                    lastModified: note.lastModified
                )
            },
            tags: tags.map { tag in
                UserTagExport(
                    id: tag.id,
                    name: tag.name,
                    createdAt: tag.createdAt,
                    lastModified: tag.lastModified
                )
            },
            tagAssignments: tagAssignments.map { assignment in
                DocumentTagAssignmentExport(
                    id: assignment.id,
                    volumeId: assignment.volumeId,
                    documentId: assignment.documentId,
                    tagId: assignment.tagId,
                    createdAt: assignment.createdAt
                )
            },
            highlights: highlights.map { highlight in
                DocumentHighlightExport(
                    id: highlight.id,
                    volumeId: highlight.volumeId,
                    documentId: highlight.documentId,
                    startOffset: highlight.startOffset,
                    endOffset: highlight.endOffset,
                    colorTag: highlight.colorTag,
                    noteId: highlight.noteId,
                    selectedText: highlight.selectedText,
                    renderingVersion: highlight.renderingVersion,
                    createdAt: highlight.createdAt
                )
            },
            collections: collections.map { collection in
                CollectionExport(
                    id: collection.id,
                    name: collection.name,
                    note: collection.note,
                    projectIds: collection.projectIds,
                    savedSearchId: collection.savedSearchId,
                    entries: (collection.documentEntries ?? [])
                        .sorted { $0.sortOrder < $1.sortOrder }
                        .map { entry in
                            CollectionEntryExport(
                                id: entry.id,
                                documentId: entry.documentId,
                                volumeId: entry.volumeId,
                                sortOrder: entry.sortOrder,
                                researchNoteId: entry.researchNoteId,
                                selectedNoteIds: entry.selectedNoteIds,
                                createdAt: entry.createdAt,
                                lastModified: entry.lastModified
                            )
                        },
                    createdAt: collection.createdAt,
                    lastModified: collection.lastModified
                )
            },
            prompts: prompts.filter { !$0.isStandard }.map { prompt in
                SummarizationPromptExport(
                    id: prompt.id,
                    name: prompt.name,
                    promptText: prompt.promptText,
                    responseFormat: prompt.responseFormat,
                    schema: prompt.schema,
                    createdAt: prompt.createdAt,
                    lastModified: prompt.lastModified
                )
            },
            projects: projects.map { project in
                ProjectExport(
                    id: project.id,
                    name: project.name,
                    researchQuestion: project.researchQuestion,
                    defaultDateRangeStart: project.defaultDateRangeStart,
                    defaultDateRangeEnd: project.defaultDateRangeEnd,
                    defaultSubjectTagIds: project.defaultSubjectTagIds,
                    defaultCountryTagIds: project.defaultCountryTagIds,
                    createdAt: project.createdAt,
                    lastModified: project.lastModified
                )
            },
            summaries: summaries.map { summary in
                GeneratedSummaryExport(
                    id: summary.id,
                    documentId: summary.documentId,
                    volumeId: summary.volumeId,
                    promptId: summary.promptId,
                    responseText: summary.responseText,
                    responseFormat: summary.responseFormat,
                    wasChunked: summary.wasChunked,
                    projectId: summary.projectId,
                    createdAt: summary.createdAt,
                    lastModified: summary.lastModified,
                    // Coerced, not passed through: a legacy NULL *means* `.aiGenerated` everywhere
                    // else in the app, and exporting `null` would tell a reader the provenance was
                    // unknown when the app treats it as known. Never write an ambiguity the reader
                    // has to resolve with a rule they do not have.
                    authorship: summary.authorship ?? .aiGenerated
                )
            },
            readingHistory: readingHistory.map { visit in
                ReadingHistoryEntryExport(
                    id: visit.id,
                    documentId: visit.documentId,
                    volumeId: visit.volumeId,
                    displayTitle: visit.displayTitle,
                    projectId: visit.projectId,
                    accessedAt: visit.accessedAt
                )
            },
            searchHistory: searchHistory.map { search in
                SearchHistoryEntryExport(
                    id: search.id,
                    queryText: search.queryText,
                    resultCount: search.resultCount,
                    projectId: search.projectId,
                    executedAt: search.executedAt,
                    loadedCount: search.loadedCount,
                    matchCount: search.matchCount,
                    fetchLimit: search.fetchLimit,
                    indexedVolumeCount: search.indexedVolumeCount,
                    scopeSignature: search.scopeSignature,
                    appliedCorpusId: search.appliedCorpusId,
                    renderedExpression: search.renderedExpression
                )
            },
            exportHistory: exportHistory.map { export in
                ExportHistoryEntryExport(
                    id: export.id,
                    format: export.format,
                    documentCount: export.documentCount,
                    collectionName: export.collectionName,
                    projectId: export.projectId,
                    exportedAt: export.exportedAt
                )
            },
            archiveVisits: archiveVisits.map { plan in
                ArchiveVisitPlanExport(
                    id: plan.id,
                    name: plan.name,
                    inquiryText: plan.inquiryText,
                    projectIds: plan.projectIds,
                    tiers: plan.tiers,
                    deliverables: plan.deliverables,
                    documents: (plan.documents ?? [])
                        .sorted { $0.documentKey < $1.documentKey }
                        .map { document in
                            ArchiveVisitDocumentExport(
                                id: document.id,
                                documentKey: document.documentKey,
                                includeSource: document.includeSource,
                                includeExternalRefs: document.includeExternalRefs,
                                createdAt: document.createdAt,
                                lastModified: document.lastModified
                            )
                        },
                    // EVERY stored row, orphans included: whether a key still derives from the
                    // seeds is a render-time question this export deliberately does not ask.
                    targets: (plan.targets ?? [])
                        .sorted { $0.targetKey < $1.targetKey }
                        .map { target in
                            ArchiveVisitTargetExport(
                                id: target.id,
                                targetKey: target.targetKey,
                                tierId: target.tierId,
                                included: target.included,
                                userNote: target.userNote,
                                createdAt: target.createdAt,
                                lastModified: target.lastModified
                            )
                        },
                    createdAt: plan.createdAt,
                    lastModified: plan.lastModified
                )
            }
        )
    }

    /// How many rows each trail table holds, for the **Contents** inventory.
    ///
    /// Three `fetchCount`s, deliberately not three `@Query` properties. The trail grows without
    /// bound by design (contract D5 — nothing prunes it), and a `@Query` would load every row of
    /// it into the Data & Recovery pane and re-run on each iCloud sync. That is the exact fault
    /// the History window was fixed for; the inventory only ever needed the numbers.
    ///
    /// - Parameter modelContext: The SwiftData context to read from.
    /// - Returns: The per-table counts, in the order the inventory lists them.
    static func trailCounts(modelContext: ModelContext)
        -> (visits: Int, searches: Int, exports: Int) {
        (
            (try? modelContext.fetchCount(FetchDescriptor<ReadingHistoryEntry>())) ?? 0,
            (try? modelContext.fetchCount(FetchDescriptor<SearchHistoryEntry>())) ?? 0,
            (try? modelContext.fetchCount(FetchDescriptor<ExportHistoryEntry>())) ?? 0
        )
    }

    /// Builds the query-log method appendix from the stored trail (M-2).
    ///
    /// Fetched here rather than through a `@Query` for the reason `DataExportSections` gives about
    /// the trail counts: the table grows without bound by design, so it is read in the same pass
    /// that writes the file and not held on a Settings screen.
    ///
    /// - Parameters:
    ///   - modelContext: the context to read from.
    ///   - activeProjectId: the project heading the appendix, or `nil` in global context.
    ///   - generatedAt: the export timestamp.
    /// - Returns: the appendix, or one with no rows if the fetch fails — an empty appendix says
    ///   "no searches recorded", which is a true statement about a trail nothing could be read from.
    static func methodAppendix(modelContext: ModelContext,
                               activeProjectId: UUID?,
                               generatedAt: Date = Date()) -> QueryMethodAppendix {
        let searches = (try? modelContext.fetch(FetchDescriptor<SearchHistoryEntry>())) ?? []
        let corpora = (try? modelContext.fetch(FetchDescriptor<WorkingCorpus>())) ?? []
        let project = activeProjectId.flatMap { id in
            (try? modelContext.fetch(FetchDescriptor<Project>()))?.first { $0.id == id }
        }
        return QueryMethodAppendix.make(
            searches: searches,
            corpusNames: Dictionary(corpora.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first }),
            projectName: project?.name,
            researchQuestion: project?.researchQuestion,
            generatedAt: generatedAt
        )
    }

    /// The method-appendix lines for a collection export, or `[]` (M-2).
    ///
    /// One helper rather than the same six lines at each construction site: the export sheet and
    /// the live preview must agree, or the researcher approves a preview that is not what ships.
    ///
    /// Returns early when the collection has not opted in, so a collection that never enables the
    /// appendix pays no fetch — the trail table grows without bound and this runs on every preview
    /// keystroke.
    ///
    /// - Parameters:
    ///   - enabled: `Collection.includeMethodAppendix`.
    ///   - modelContext: the context to read the trail from.
    ///   - activeProject: the project the export is generated under. `nil` narrows to nothing —
    ///     see ``QueryMethodAppendix/scoped(toProject:)``.
    @MainActor
    static func collectionMethodAppendixLines(enabled: Bool,
                                              modelContext: ModelContext,
                                              activeProject: Project?) -> [String] {
        guard enabled else { return [] }
        let appendix = methodAppendix(modelContext: modelContext,
                                      activeProjectId: activeProject?.id)
            .scoped(toProject: activeProject?.id)
        return CollectionExportMetadata.methodAppendix(enabled: true, appendix: appendix)
    }

    /// Serializes an envelope as pretty-printed, key-sorted JSON with ISO-8601 dates.
    static func exportJSONData(_ envelope: ResearchDataEnvelope) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(envelope)
    }

    /// Renders one Markdown file per note, with YAML front matter containing the
    /// document citation, canonical `history.state.gov` URL, and tag names.
    ///
    /// Citations are looked up via `appState.indexingPipeline` and
    /// `appState.manifestStore`; a note's front matter omits `citation` if the
    /// source volume hasn't been indexed.
    static func markdownExports(
        notes: [ResearchNote],
        tags: [UserTag],
        appState: AppState
    ) async -> [ResearchNoteMarkdownExport] {
        // uniquingKeysWith: CloudKit sync can transiently surface duplicate ids;
        // uniqueKeysWithValues would crash on them.
        let tagNamesById = Dictionary(tags.map { ($0.id, $0.name) },
                                      uniquingKeysWith: { first, _ in first })
        var results: [ResearchNoteMarkdownExport] = []
        results.reserveCapacity(notes.count)
        for note in notes {
            let citation = await citation(forVolumeId: note.volumeId, documentId: note.documentId, appState: appState)
            results.append(markdownExport(for: note, citation: citation, tagNamesById: tagNamesById))
        }
        return results
    }

    /// Looks up a formatted history.state.gov citation for a document, or `nil`
    /// if the volume isn't indexed or isn't in the manifest.
    private static func citation(forVolumeId volumeId: String, documentId: String, appState: AppState) async -> String? {
        guard let pipeline = appState.indexingPipeline,
              let volumeEntry = appState.manifestStore.entry(forVolumeId: volumeId),
              let documents = try? await pipeline.documents(forVolume: volumeId),
              let documentEntry = documents.first(where: { $0.documentId == documentId })
        else { return nil }

        return HistoryAtStateCitationFormatter().format(
            document: FRUSDocumentMetadata(documentEntry),
            volume: FRUSVolumeMetadata(volumeEntry)
        )
    }

    /// Builds a single Markdown export for `note`.
    private static func markdownExport(
        for note: ResearchNote,
        citation: String?,
        tagNamesById: [UUID: String]
    ) -> ResearchNoteMarkdownExport {
        let canonicalURL = "https://history.state.gov/historicaldocuments/\(note.volumeId)/\(note.documentId)"
        let tagNames = note.userTagIds.compactMap { tagNamesById[$0] }

        var frontMatter: [String] = ["---"]
        frontMatter.append("documentId: \(note.documentId)")
        frontMatter.append("volumeId: \(note.volumeId)")
        frontMatter.append("url: \(canonicalURL)")
        if let citation {
            frontMatter.append("citation: \(yamlQuoted(citation))")
        }
        if !tagNames.isEmpty {
            frontMatter.append("tags: [\(tagNames.map(yamlQuoted).joined(separator: ", "))]")
        }
        if let createdAt = note.createdAt {
            frontMatter.append("created: \(ISO8601DateFormatter().string(from: createdAt))")
        }
        if let lastModified = note.lastModified {
            frontMatter.append("modified: \(ISO8601DateFormatter().string(from: lastModified))")
        }
        frontMatter.append("---")

        let content = frontMatter.joined(separator: "\n") + "\n\n" + note.bodyText + "\n"
        let shortId = note.id.uuidString.prefix(8)
        let filename = "\(note.volumeId)-\(note.documentId)-\(shortId).md"

        return ResearchNoteMarkdownExport(id: note.id, filename: filename, content: content)
    }

    /// Wraps `value` in a double-quoted YAML scalar, escaping backslashes and
    /// quotes — user-authored tag names and citation text can contain `:`/`"`/`]`,
    /// which break unquoted YAML.
    private static func yamlQuoted(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}

// MARK: - Index database export (W-19 row L-2)

/// Copies the SQLite search index to a destination the reader chooses, optionally without the
/// reader's own writing.
///
/// This is what `Docs/Agentic-Analysis-Guide.md` §2 and §11 teach by hand, made a button. The
/// guide's audience is a researcher pointing an outside AI agent at the index; getting a *correct*
/// copy out of a live WAL database, and deciding what of their own goes with it, are the two things
/// that recipe exists to get right, and both are easy to get wrong by hand.
///
/// Three properties are load-bearing and each one is a documented trap:
///
/// 1. **`sqlite3_backup`, never a file copy.** The database runs in WAL mode, so recent writes may
///    live entirely in the `-wal` sidecar. Copying `frus.db` alone yields a stale or torn database.
///    The backup API reads through an open connection and therefore sees the WAL.
/// 2. **`VACUUM` only when stripping, and always followed by a rebuild of BOTH FTS tables — as
///    insurance, not as a demonstrated repair.** `document_cache` declares
///    `PRIMARY KEY (volume_id, document_id)`, so its rowid is not an `INTEGER PRIMARY KEY` alias
///    and SQLite reserves the right to renumber it on `VACUUM`, while `frus_documents` and
///    `user_content` are FTS5 *external-content* tables keyed on that rowid — so a renumbering
///    would leave every full-text match pointing at the wrong document, at plausible scores, with
///    nothing failing.
///
///    **Measured 2026-08-31, and the measurement is why this comment is hedged:** on this SQLite
///    build `VACUUM` did *not* renumber, even over a table with deleted rows and a rowid gap, and
///    an FTS match resolved correctly afterwards without any rebuild. The rebuild is kept because
///    the guarantee is SQLite's to withdraw and the cost here is one statement on a file the reader
///    is already waiting on — but no test in this suite can prove it necessary, and none pretends
///    to. Do not let a green suite be read as evidence that removing it is safe.
/// 3. **The strip is only an erase because of the `VACUUM`.** Nulling the columns removes the words
///    from the live rows and the rebuild removes them from the index — but they remain in pages
///    SQLite has freed and not reused, and a page-level backup copies those faithfully. On the
///    author's own store 56.2% of the file is freelist. Offering a consent checkbox over a file that
///    still contains the text would be worse than offering no checkbox at all.
///
/// Version history:
///   1.0 — W-19 L-2: initial implementation
enum IndexDatabaseExporter {

    /// What an export produced, for the surface to report honestly.
    struct Report: Sendable, Equatable {
        /// Size of the written file in bytes.
        var byteCount: Int64
        /// Whether the reader's own writing was removed.
        var strippedWriting: Bool
        /// Problems the post-export integrity check found. Empty is the expected result; a
        /// non-empty list means the copy is not trustworthy and the surface must say so rather
        /// than presenting a file that looks fine.
        var integrityProblems: [String]
    }

    /// Why an export could not be produced.
    enum ExportError: LocalizedError, Equatable {
        /// The source database could not be opened for reading.
        case cannotOpenSource(String)
        /// The destination could not be created or written.
        case cannotOpenDestination(String)
        /// `sqlite3_backup` reported a failure part-way through.
        case backupFailed(String)
        /// A statement in the strip or verification sequence failed.
        case sqlFailed(step: String, message: String)

        var errorDescription: String? {
            switch self {
            case .cannotOpenSource(let m):
                return String(localized: "export.database.error.source",
                              defaultValue: "Could not read the search index: \(m)")
            case .cannotOpenDestination(let m):
                return String(localized: "export.database.error.destination",
                              defaultValue: "Could not write the export: \(m)")
            case .backupFailed(let m):
                return String(localized: "export.database.error.backup",
                              defaultValue: "Copying the index failed: \(m)")
            case .sqlFailed(let step, let m):
                return String(localized: "export.database.error.sql",
                              defaultValue: "The export failed while \(step): \(m)")
            }
        }
    }

    /// Copies `source` to `destination`, optionally stripping the reader's own writing.
    ///
    /// Synchronous and potentially long: the author's own store is ~6.3 GiB including freelist.
    /// Call it off the main actor.
    ///
    /// - Parameters:
    ///   - source: The live index. Read only; never modified.
    ///   - destination: Written, replacing any existing file.
    ///   - includeMyWriting: When `false`, summaries, notes and tag names are removed from the copy
    ///     and the freed pages reclaimed. When `true` the copy is byte-faithful in content.
    /// - Returns: A `Report` describing what was written.
    static func export(from source: URL, to destination: URL, includeMyWriting: Bool) throws -> Report {
        try? FileManager.default.removeItem(at: destination)

        var src: OpaquePointer?
        guard sqlite3_open_v2(source.path, &src, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let src else {
            let message = src.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            sqlite3_close(src)
            throw ExportError.cannotOpenSource(message)
        }
        defer { sqlite3_close(src) }

        var dst: OpaquePointer?
        guard sqlite3_open_v2(destination.path, &dst,
                              SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK,
              let dst else {
            let message = dst.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            sqlite3_close(dst)
            throw ExportError.cannotOpenDestination(message)
        }
        defer { sqlite3_close(dst) }

        // The page copy. `-1` copies every remaining page in one call; the source is read through
        // its connection, so WAL content is included and no checkpoint of the live database is
        // needed — this must never write to the file the app is using.
        guard let backup = sqlite3_backup_init(dst, "main", src, "main") else {
            throw ExportError.backupFailed(String(cString: sqlite3_errmsg(dst)))
        }
        let stepResult = sqlite3_backup_step(backup, -1)
        let finishResult = sqlite3_backup_finish(backup)
        guard stepResult == SQLITE_DONE, finishResult == SQLITE_OK else {
            throw ExportError.backupFailed(String(cString: sqlite3_errmsg(dst)))
        }

        if !includeMyWriting {
            try strip(dst)
        }

        let problems = verify(dst)
        let size = (try? FileManager.default.attributesOfItem(atPath: destination.path)[.size]) as? Int64
        return Report(byteCount: size ?? 0,
                      strippedWriting: !includeMyWriting,
                      integrityProblems: problems)
    }

    /// Removes the reader's own writing from an already-copied database.
    ///
    /// The order is the whole correctness argument: null the columns, drop the tag names, reclaim
    /// the freed pages, and only then rebuild both external-content indexes against the rowids
    /// `VACUUM` may have renumbered.
    private static func strip(_ db: OpaquePointer) throws {
        try exec(db, step: "removing your notes and summaries", sql: """
            UPDATE document_cache SET summary_text = NULL, note_text = NULL, user_tag_ids = NULL
            """)
        try exec(db, step: "removing your tag names", sql: "DELETE FROM user_tags")
        // Reclaims the freed pages. Without this the words survive in the file even though no row
        // and no index references them any more.
        try exec(db, step: "reclaiming freed pages", sql: "VACUUM")
        // Both, and after the VACUUM. See the type's note 2.
        try exec(db, step: "rebuilding the document index",
                 sql: "INSERT INTO frus_documents(frus_documents) VALUES('rebuild')")
        try exec(db, step: "rebuilding your-content index",
                 sql: "INSERT INTO user_content(user_content) VALUES('rebuild')")
    }

    /// Runs the same checks the app's own Index Health screen runs, against the copy.
    ///
    /// The `rank` argument on `integrity-check` is `1` deliberately: with the default the check
    /// tests only the FTS index's internal consistency and passes on an index that has drifted from
    /// its content table. Form `1` is the one that cross-checks against `document_cache`.
    ///
    /// - Returns: Human-readable problems; empty means the copy verified.
    private static func verify(_ db: OpaquePointer) -> [String] {
        var problems: [String] = []
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "PRAGMA quick_check", -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let row = String(cString: sqlite3_column_text(stmt, 0))
                if row != "ok" { problems.append("quick_check: \(row)") }
            }
        } else {
            problems.append("quick_check could not run")
        }
        sqlite3_finalize(stmt)

        for table in ["frus_documents", "user_content"] {
            do {
                try exec(db, step: "verifying \(table)",
                         sql: "INSERT INTO \(table)(\(table), rank) VALUES('integrity-check', 1)")
            } catch let ExportError.sqlFailed(_, message) {
                problems.append("\(table): \(message)")
            } catch {
                problems.append("\(table): \(error.localizedDescription)")
            }
        }
        return problems
    }

    private static func exec(_ db: OpaquePointer, step: String, sql: String) throws {
        var errmsg: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(db, sql, nil, nil, &errmsg)
        guard rc == SQLITE_OK else {
            let message = errmsg.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(errmsg)
            throw ExportError.sqlFailed(step: step, message: message)
        }
    }
}
