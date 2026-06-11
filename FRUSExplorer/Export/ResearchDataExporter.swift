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
/// collections, user-created prompts, and projects — suitable for backup or as
/// an exit ramp from the app.
///
/// `formatVersion` exists so a future importer can detect and migrate older
/// exports. Import itself is out of scope for Session 154.
///
/// Version history:
///   1.0 — Session 154: initial implementation
struct ResearchDataEnvelope: Codable, Equatable, Sendable {

    /// Schema version of this export. See `ResearchDataExporter.currentFormatVersion`.
    var formatVersion: Int

    /// When this export was generated.
    var exportedAt: Date

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
/// Entry points: iOS `ResearchDataExportView` (Settings → Export Research Data…)
/// and macOS `SettingsDataPane`.
///
/// Version history:
///   1.0 — Session 154: initial implementation
@MainActor
enum ResearchDataExporter {

    /// Current `ResearchDataEnvelope.formatVersion`. Bump when making a breaking
    /// change to the export schema; a future importer can branch on this value.
    static let currentFormatVersion = 1

    /// Builds an envelope from the current contents of `modelContext`.
    ///
    /// - Parameters:
    ///   - modelContext: The SwiftData context to read from.
    ///   - includeGeneratedSummaries: When `true`, populates `summaries` from
    ///     all `GeneratedSummary` records.
    static func makeEnvelope(
        modelContext: ModelContext,
        includeGeneratedSummaries: Bool
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

        let highlightsByNoteId = Dictionary(grouping: highlights, by: \.noteId)

        return ResearchDataEnvelope(
            formatVersion: currentFormatVersion,
            exportedAt: .now,
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
            }
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
