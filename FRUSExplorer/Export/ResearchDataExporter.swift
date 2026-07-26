// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

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
    /// Only the three trail arrays are tolerant. Everything else stays required, so a truncated or
    /// corrupt file still fails loudly rather than decoding into a plausible-looking empty backup.
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

    /// Matches at execution time, not now. The two producers derive it differently and the
    /// difference shows only on very broad queries — macOS records the true uncapped total, iOS
    /// the result count capped at its 1,000-row hard limit. See `SearchHistoryEntry.resultCount`.
    var resultCount: Int

    var projectId: UUID?
    var executedAt: Date?
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
    /// otherwise make indistinguishable.)
    static let currentFormatVersion = 3

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
                    lastModified: summary.lastModified
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
                    executedAt: search.executedAt
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
