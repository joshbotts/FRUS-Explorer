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
///   7.0 — FRUS Explorer Light (in FRUSCoreKit): the eight model types version 6 left out —
///          `savedSearches`, `workingCorpora`, `customVolumeScopes`, `classificationOverrides`,
///          `personClusterOverrides`, `annotationReviews`, `projectLeads` and
///          `syncedPreferences` — each defaulting to empty in the tolerant decoder; and what 6
///          dropped from the types it carried: a note's rich text, a collection's front matter,
///          composition and settings, each entry's kind, level, text, rich text, excerpt anchors,
///          block type and overrides, a project's focus tags and lead weights, and a summary's
///          headnote flag, each optional on its record, so version-6-and-earlier files still decode
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

    // MARK: - The rest of the researcher's data (format version 7)

    /// Every saved search, with the search it runs and its last run. Empty on a version-6 file,
    /// which could not carry them, as for every array below.
    public var savedSearches: [SavedSearchExport] = []

    /// Every working corpus, its documents and how it was captured.
    public var workingCorpora: [WorkingCorpusExport] = []

    /// Every custom volume scope (Settings ▸ Volume Scopes).
    public var customVolumeScopes: [CustomVolumeScopeExport] = []

    /// Every correction of whether a document is an editorial note.
    public var classificationOverrides: [DocumentClassificationOverrideExport] = []

    /// Every person correction, a merge of two records or a split of one.
    public var personClusterOverrides: [PersonClusterOverrideExport] = []

    /// Every changed passage the researcher has reviewed, the ledger the Review Changes sheet keeps.
    public var annotationReviews: [AnnotationReviewExport] = []

    /// Every project's Suggested Next leads, with their dismissals.
    public var projectLeads: [ProjectLeadEntryExport] = []

    /// The settings that sync across the researcher's devices. One record, the earliest-created
    /// first, as the app reads it; more only while iCloud has not yet merged a second device's.
    public var syncedPreferences: [SyncedPreferencesExport] = []

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
        archiveVisits: [ArchiveVisitPlanExport] = [],
        savedSearches: [SavedSearchExport] = [],
        workingCorpora: [WorkingCorpusExport] = [],
        customVolumeScopes: [CustomVolumeScopeExport] = [],
        classificationOverrides: [DocumentClassificationOverrideExport] = [],
        personClusterOverrides: [PersonClusterOverrideExport] = [],
        annotationReviews: [AnnotationReviewExport] = [],
        projectLeads: [ProjectLeadEntryExport] = [],
        syncedPreferences: [SyncedPreferencesExport] = []
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
        self.savedSearches = savedSearches
        self.workingCorpora = workingCorpora
        self.customVolumeScopes = customVolumeScopes
        self.classificationOverrides = classificationOverrides
        self.personClusterOverrides = personClusterOverrides
        self.annotationReviews = annotationReviews
        self.projectLeads = projectLeads
        self.syncedPreferences = syncedPreferences
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
        case savedSearches, workingCorpora, customVolumeScopes, classificationOverrides
        case personClusterOverrides, annotationReviews, projectLeads, syncedPreferences
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
    /// Only the three trail arrays, the archive-visits array (format 6) and the eight arrays of
    /// format 7 are tolerant.
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
        savedSearches =
            try container.decodeIfPresent([SavedSearchExport].self, forKey: .savedSearches) ?? []
        workingCorpora =
            try container.decodeIfPresent([WorkingCorpusExport].self, forKey: .workingCorpora) ?? []
        customVolumeScopes =
            try container.decodeIfPresent([CustomVolumeScopeExport].self,
                                          forKey: .customVolumeScopes) ?? []
        classificationOverrides =
            try container.decodeIfPresent([DocumentClassificationOverrideExport].self,
                                          forKey: .classificationOverrides) ?? []
        personClusterOverrides =
            try container.decodeIfPresent([PersonClusterOverrideExport].self,
                                          forKey: .personClusterOverrides) ?? []
        annotationReviews =
            try container.decodeIfPresent([AnnotationReviewExport].self,
                                          forKey: .annotationReviews) ?? []
        projectLeads =
            try container.decodeIfPresent([ProjectLeadEntryExport].self, forKey: .projectLeads) ?? []
        syncedPreferences =
            try container.decodeIfPresent([SyncedPreferencesExport].self,
                                          forKey: .syncedPreferences) ?? []
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

    /// The note's formatting (format version 7): RTF, as the app keeps it beside `bodyText`, which
    /// stays the note's plain text. Base64 in the file. `nil` when the note has no formatting, and
    /// in a file written before version 7.
    public var richText: Data?

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
        lastModified: Date? = nil,
        richText: Data? = nil
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
        self.richText = richText
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
///
/// Through format version 6 it carried only an entry's document, order and notes, so a heading, a
/// prose block or an apparatus block (whose `documentId` is `""`) was written as an entry with no
/// document, and an excerpt as the document it quotes. Version 7 carries the whole entry: its
/// kind, level and text, its rich text, an excerpt's anchors, an apparatus block's type, and every
/// override. Each of those is optional here so a version-6 file still decodes; a file at version 7
/// always carries `kind`, `level` and `selectedHighlightIds`, and the others when the entry has
/// them, so `nil` means what it means on the model ("inherit", "none") and, in an earlier file,
/// that the file predates the field.
public struct CollectionEntryExport: Codable, Equatable, Sendable {
    public var id: UUID
    public var documentId: String
    public var volumeId: String
    public var sortOrder: Int
    public var researchNoteId: UUID?
    public var selectedNoteIds: [UUID]
    public var createdAt: Date?
    public var lastModified: Date?

    // MARK: - The entry itself (format version 7)

    /// `CollectionEntry.kind`, the `CollectionEntryKind` raw value as stored (`document`,
    /// `heading`, `prose`, `excerpt`, `generated`, or a newer build's value).
    public var kind: String?
    /// A heading's nesting depth, as stored (1 on every other kind).
    public var level: Int?
    /// A heading's title, a prose block's plain text, or an excerpt's frozen passage.
    public var text: String?
    /// A prose block's rich text, as the app stores it: RTF, or the JSON-encoded
    /// `AttributedString` of a Phase 3b build that has not been migrated. Base64 in the file.
    public var richText: Data?
    /// An excerpt's UTF-16 start offset in its document's flat text.
    public var excerptStart: Int?
    /// An excerpt's UTF-16 end offset, exclusive.
    public var excerptEnd: Int?
    /// The document's rendering version when the excerpt was taken.
    public var excerptRenderingVersion: String?
    /// The colour of the highlight an excerpt was taken from.
    public var excerptColorTag: String?
    /// An apparatus block's `CollectionGeneratedBlockType` raw value.
    public var generatedBlockType: String?

    // MARK: - Overrides (format version 7)

    /// A document entry's title, replacing the derived one in the table of contents and heading.
    public var titleOverride: String?
    /// A `CollectionBodyDepth` raw value overriding the collection's default.
    public var bodyDepthOverride: String?
    public var applyHighlightsOverride: Bool?
    public var includeNotesOverride: Bool?
    public var includeSourceNoteOverride: Bool?
    public var includeFootnotesOverride: Bool?
    public var summaryPromptIdOverride: UUID?
    /// The highlights to include; empty means all of them.
    public var selectedHighlightIds: [UUID]?
    public var includeRelatedDocuments: Bool?
    /// The entry's headnote setting: `nil` inherits the collection's default.
    public var includeHeadnote: Bool?
    /// The summary the headnote renders.
    public var headnoteSummaryId: UUID?

    /// The memberwise initialiser, spelled out because a synthesized one is never `public`.
    public init(
        id: UUID,
        documentId: String,
        volumeId: String,
        sortOrder: Int,
        researchNoteId: UUID? = nil,
        selectedNoteIds: [UUID],
        createdAt: Date? = nil,
        lastModified: Date? = nil,
        kind: String? = nil,
        level: Int? = nil,
        text: String? = nil,
        richText: Data? = nil,
        excerptStart: Int? = nil,
        excerptEnd: Int? = nil,
        excerptRenderingVersion: String? = nil,
        excerptColorTag: String? = nil,
        generatedBlockType: String? = nil,
        titleOverride: String? = nil,
        bodyDepthOverride: String? = nil,
        applyHighlightsOverride: Bool? = nil,
        includeNotesOverride: Bool? = nil,
        includeSourceNoteOverride: Bool? = nil,
        includeFootnotesOverride: Bool? = nil,
        summaryPromptIdOverride: UUID? = nil,
        selectedHighlightIds: [UUID]? = nil,
        includeRelatedDocuments: Bool? = nil,
        includeHeadnote: Bool? = nil,
        headnoteSummaryId: UUID? = nil
    ) {
        self.id = id
        self.documentId = documentId
        self.volumeId = volumeId
        self.sortOrder = sortOrder
        self.researchNoteId = researchNoteId
        self.selectedNoteIds = selectedNoteIds
        self.createdAt = createdAt
        self.lastModified = lastModified
        self.kind = kind
        self.level = level
        self.text = text
        self.richText = richText
        self.excerptStart = excerptStart
        self.excerptEnd = excerptEnd
        self.excerptRenderingVersion = excerptRenderingVersion
        self.excerptColorTag = excerptColorTag
        self.generatedBlockType = generatedBlockType
        self.titleOverride = titleOverride
        self.bodyDepthOverride = bodyDepthOverride
        self.applyHighlightsOverride = applyHighlightsOverride
        self.includeNotesOverride = includeNotesOverride
        self.includeSourceNoteOverride = includeSourceNoteOverride
        self.includeFootnotesOverride = includeFootnotesOverride
        self.summaryPromptIdOverride = summaryPromptIdOverride
        self.selectedHighlightIds = selectedHighlightIds
        self.includeRelatedDocuments = includeRelatedDocuments
        self.includeHeadnote = includeHeadnote
        self.headnoteSummaryId = headnoteSummaryId
    }
}

// MARK: - CollectionExport

/// Export DTO mirroring `Collection`, including its ordered `CollectionEntry` items.
///
/// Through format version 6 it carried a collection's name, note, projects, saved search and
/// entries. Version 7 adds its front matter, its composition and its export settings, each
/// optional here so a version-6 file still decodes. A file at version 7 always carries the ones
/// the model stores with a default, and the optional ones when they are set: `includeFootnotes`
/// and `includeSourceNote` are `nil` on a collection that has not set them, which the app reads
/// from `footnoteStyle`, as on the model.
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

    // MARK: - Front matter (format version 7)

    public var subtitle: String?
    public var authorLine: String?
    /// The introduction's plain text.
    public var introductionText: String?
    /// The introduction's rich text, RTF as the app stores it. Base64 in the file.
    public var introductionRichText: Data?
    public var includeColophon: Bool?
    public var includeProjectProvenance: Bool?
    public var includeMethodAppendix: Bool?

    // MARK: - Composition (format version 7)

    /// A `CollectionBodyDepth` raw value.
    public var defaultBodyDepth: String?
    /// The legacy `CollectionFootnoteStyle` raw value, which `includeFootnotes` and
    /// `includeSourceNote` supersede where they are set.
    public var footnoteStyle: String?
    public var includeFootnotes: Bool?
    public var includeSourceNote: Bool?
    /// A `CollectionToCStyle` raw value.
    public var tocStyle: String?
    public var applyHighlights: Bool?
    public var includeNotes: Bool?
    public var includeWordCloud: Bool?
    public var defaultIncludeHeadnote: Bool?
    /// The prompt whose summaries a summary-only body uses.
    public var summaryPromptId: UUID?

    /// The memberwise initialiser, spelled out because a synthesized one is never `public`.
    public init(
        id: UUID,
        name: String,
        note: String? = nil,
        projectIds: [UUID],
        savedSearchId: UUID? = nil,
        entries: [CollectionEntryExport],
        createdAt: Date? = nil,
        lastModified: Date? = nil,
        subtitle: String? = nil,
        authorLine: String? = nil,
        introductionText: String? = nil,
        introductionRichText: Data? = nil,
        includeColophon: Bool? = nil,
        includeProjectProvenance: Bool? = nil,
        includeMethodAppendix: Bool? = nil,
        defaultBodyDepth: String? = nil,
        footnoteStyle: String? = nil,
        includeFootnotes: Bool? = nil,
        includeSourceNote: Bool? = nil,
        tocStyle: String? = nil,
        applyHighlights: Bool? = nil,
        includeNotes: Bool? = nil,
        includeWordCloud: Bool? = nil,
        defaultIncludeHeadnote: Bool? = nil,
        summaryPromptId: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.note = note
        self.projectIds = projectIds
        self.savedSearchId = savedSearchId
        self.entries = entries
        self.createdAt = createdAt
        self.lastModified = lastModified
        self.subtitle = subtitle
        self.authorLine = authorLine
        self.introductionText = introductionText
        self.introductionRichText = introductionRichText
        self.includeColophon = includeColophon
        self.includeProjectProvenance = includeProjectProvenance
        self.includeMethodAppendix = includeMethodAppendix
        self.defaultBodyDepth = defaultBodyDepth
        self.footnoteStyle = footnoteStyle
        self.includeFootnotes = includeFootnotes
        self.includeSourceNote = includeSourceNote
        self.tocStyle = tocStyle
        self.applyHighlights = applyHighlights
        self.includeNotes = includeNotes
        self.includeWordCloud = includeWordCloud
        self.defaultIncludeHeadnote = defaultIncludeHeadnote
        self.summaryPromptId = summaryPromptId
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

    // MARK: - Project Focus (format version 7)

    /// The project's focus tags, the user tags Project Focus pre-selects. Optional only so a
    /// version-6 file still decodes; a file at version 7 always carries it.
    public var defaultUserTagIds: [UUID]?
    /// Suggested Next's axis weights for the project, as the app stores them, or `nil` when the
    /// project uses the defaults.
    public var leadAxisWeights: String?

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
        lastModified: Date? = nil,
        defaultUserTagIds: [UUID]? = nil,
        leadAxisWeights: String? = nil
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
        self.defaultUserTagIds = defaultUserTagIds
        self.leadAxisWeights = leadAxisWeights
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

    /// Whether the summary is a collection entry's headnote draft (format version 7), which the
    /// app keeps out of the document's own summaries. Optional only so a version-6 file still
    /// decodes; a file at version 7 always carries it.
    public var isHeadnoteDraft: Bool?

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
        authorship: SummaryAuthorship? = nil,
        isHeadnoteDraft: Bool? = nil
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
        self.isHeadnoteDraft = isHeadnoteDraft
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

// MARK: - SavedSearchExport

/// Export DTO mirroring `SavedSearch` (format version 7).
///
/// The search is exported as the kit's `SearchParameters`, the value `SavedSearch.searchParameters`
/// gives the app when it runs the search: the stored snapshot, or for a record older than the
/// snapshot, the search rebuilt from its scalar columns. Those columns are written from the
/// parameters, so they are not exported beside them, and nor is the stored `sortOrder`, which is
/// always "relevance" and nothing reads. The run watermark is exported as its three values rather
/// than as the stored blob, so a reader needs no knowledge of the blob's shape.
public struct SavedSearchExport: Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    /// The search, as the app runs it.
    public var parameters: SearchParameters
    /// When the search was last run, or `nil` if it never was.
    public var lastRunAt: Date?
    /// What that run matched, the baseline of "+N since last run".
    public var matchCountAtLastRun: Int?
    /// How many volumes were indexed on the device that ran it.
    public var indexedVolumeCountAtLastRun: Int?
    public var createdAt: Date?
    public var lastModified: Date?

    /// The memberwise initialiser, spelled out because a synthesized one is never `public`.
    public init(
        id: UUID,
        name: String,
        parameters: SearchParameters,
        lastRunAt: Date? = nil,
        matchCountAtLastRun: Int? = nil,
        indexedVolumeCountAtLastRun: Int? = nil,
        createdAt: Date? = nil,
        lastModified: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.parameters = parameters
        self.lastRunAt = lastRunAt
        self.matchCountAtLastRun = matchCountAtLastRun
        self.indexedVolumeCountAtLastRun = indexedVolumeCountAtLastRun
        self.createdAt = createdAt
        self.lastModified = lastModified
    }
}

// MARK: - WorkingCorpusExport

/// Export DTO mirroring `WorkingCorpus` — a saved set of documents, with how it was captured
/// (format version 7).
public struct WorkingCorpusExport: Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    /// The members, as `volumeId/documentId` keys, sorted and unique as the model keeps them.
    public var documentKeys: [String]
    public var capturedAt: Date?
    public var sourceQuery: String?
    public var sourceDescription: String?
    public var indexedVolumeCountAtCapture: Int?
    /// Whether the capture was cut short at the search's ceiling: `nil` when it was not recorded.
    public var wasTruncatedAtCapture: Bool?
    public var totalMatchCountAtCapture: Int?
    public var createdAt: Date?
    public var lastModified: Date?

    /// The memberwise initialiser, spelled out because a synthesized one is never `public`.
    public init(
        id: UUID,
        name: String,
        documentKeys: [String],
        capturedAt: Date? = nil,
        sourceQuery: String? = nil,
        sourceDescription: String? = nil,
        indexedVolumeCountAtCapture: Int? = nil,
        wasTruncatedAtCapture: Bool? = nil,
        totalMatchCountAtCapture: Int? = nil,
        createdAt: Date? = nil,
        lastModified: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.documentKeys = documentKeys
        self.capturedAt = capturedAt
        self.sourceQuery = sourceQuery
        self.sourceDescription = sourceDescription
        self.indexedVolumeCountAtCapture = indexedVolumeCountAtCapture
        self.wasTruncatedAtCapture = wasTruncatedAtCapture
        self.totalMatchCountAtCapture = totalMatchCountAtCapture
        self.createdAt = createdAt
        self.lastModified = lastModified
    }
}

// MARK: - CustomVolumeScopeExport

/// Export DTO mirroring `CustomVolumeScope` — a named set of volumes (format version 7).
public struct CustomVolumeScopeExport: Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var volumeIds: [String]
    public var createdAt: Date?
    public var lastModified: Date?

    /// The memberwise initialiser, spelled out because a synthesized one is never `public`.
    public init(id: UUID, name: String, volumeIds: [String], createdAt: Date? = nil,
                lastModified: Date? = nil) {
        self.id = id
        self.name = name
        self.volumeIds = volumeIds
        self.createdAt = createdAt
        self.lastModified = lastModified
    }
}

// MARK: - DocumentClassificationOverrideExport

/// Export DTO mirroring `DocumentClassificationOverride` — the researcher's correction of whether
/// a document is an editorial note, with what the parser said (format version 7).
public struct DocumentClassificationOverrideExport: Codable, Equatable, Sendable {
    public var id: UUID
    public var volumeId: String
    public var documentId: String
    /// What the researcher says the document is.
    public var isEditorialNote: Bool
    /// What the parser said when the correction was made.
    public var parsedIsEditorialNote: Bool
    public var createdAt: Date?

    /// The memberwise initialiser, spelled out because a synthesized one is never `public`.
    public init(id: UUID, volumeId: String, documentId: String, isEditorialNote: Bool,
                parsedIsEditorialNote: Bool, createdAt: Date? = nil) {
        self.id = id
        self.volumeId = volumeId
        self.documentId = documentId
        self.isEditorialNote = isEditorialNote
        self.parsedIsEditorialNote = parsedIsEditorialNote
        self.createdAt = createdAt
    }
}

// MARK: - PersonClusterOverrideExport

/// Export DTO mirroring `PersonClusterOverride` — a person correction (format version 7).
public struct PersonClusterOverrideExport: Codable, Equatable, Sendable {
    public var id: UUID
    /// `PersonClusterOverrideKind`'s raw value as stored: `merge` or `split`, or a newer build's.
    public var kind: String
    public var volumeIdA: String
    public var refA: String
    /// The second record of a merge; `nil` for a split.
    public var volumeIdB: String?
    public var refB: String?
    public var createdAt: Date?

    /// The memberwise initialiser, spelled out because a synthesized one is never `public`.
    public init(id: UUID, kind: String, volumeIdA: String, refA: String, volumeIdB: String? = nil,
                refB: String? = nil, createdAt: Date? = nil) {
        self.id = id
        self.kind = kind
        self.volumeIdA = volumeIdA
        self.refA = refA
        self.volumeIdB = volumeIdB
        self.refB = refB
        self.createdAt = createdAt
    }
}

// MARK: - AnnotationReviewExport

/// Export DTO mirroring `AnnotationReview` — one changed passage the researcher has reviewed
/// (format version 7). Its `id` is derived from its other fields, as the model's is.
public struct AnnotationReviewExport: Codable, Equatable, Sendable {
    public var id: UUID
    /// `AnnotationReviewKind`'s raw value as stored.
    public var annotationType: String
    /// The note, tag or collection entry reviewed, or `nil` for a review of the whole document,
    /// the only kind the app writes today.
    public var annotationId: UUID?
    public var volumeId: String
    public var documentId: String
    /// The revision of the text the review answered.
    public var contentHash: String
    public var changeKind: String?
    public var reviewedAt: Date?

    /// The memberwise initialiser, spelled out because a synthesized one is never `public`.
    public init(id: UUID, annotationType: String, annotationId: UUID? = nil, volumeId: String,
                documentId: String, contentHash: String, changeKind: String? = nil,
                reviewedAt: Date? = nil) {
        self.id = id
        self.annotationType = annotationType
        self.annotationId = annotationId
        self.volumeId = volumeId
        self.documentId = documentId
        self.contentHash = contentHash
        self.changeKind = changeKind
        self.reviewedAt = reviewedAt
    }
}

// MARK: - ProjectLeadEntryExport

/// Export DTO mirroring `ProjectLeadEntry` — one of a project's Suggested Next leads, with whether
/// the researcher dismissed it (format version 7).
public struct ProjectLeadEntryExport: Codable, Equatable, Sendable {
    public var id: UUID
    public var projectId: UUID
    public var volumeId: String
    public var documentId: String
    /// The lead's score when last computed. Always a finite number in the file: the app writes 0
    /// for a stored score that is not one, which JSON cannot carry.
    public var aggregateScore: Double
    /// The project documents the lead was found from.
    public var contributingSeedKeys: [String]
    public var header: String
    public var documentNumber: String?
    public var isEditorialNote: Bool
    public var firstSurfacedAt: Date
    public var lastComputedAt: Date
    public var dismissed: Bool

    /// The memberwise initialiser, spelled out because a synthesized one is never `public`.
    public init(
        id: UUID,
        projectId: UUID,
        volumeId: String,
        documentId: String,
        aggregateScore: Double,
        contributingSeedKeys: [String],
        header: String,
        documentNumber: String? = nil,
        isEditorialNote: Bool,
        firstSurfacedAt: Date,
        lastComputedAt: Date,
        dismissed: Bool
    ) {
        self.id = id
        self.projectId = projectId
        self.volumeId = volumeId
        self.documentId = documentId
        self.aggregateScore = aggregateScore
        self.contributingSeedKeys = contributingSeedKeys
        self.header = header
        self.documentNumber = documentNumber
        self.isEditorialNote = isEditorialNote
        self.firstSurfacedAt = firstSurfacedAt
        self.lastComputedAt = lastComputedAt
        self.dismissed = dismissed
    }
}

// MARK: - SyncedPreferencesExport

/// Export DTO mirroring `SyncedPreferences` — the settings that sync across the researcher's
/// devices (format version 7). The three JSON lists are exported as the strings the app stores.
public struct SyncedPreferencesExport: Codable, Equatable, Sendable {
    public var createdAt: Date
    public var updatedAt: Date
    public var wcMinLength: Int
    public var wcMinCount: Int
    public var wcFoldPlurals: Bool
    public var wcFilterMarkings: Bool
    public var wcExcludeBoilerplate: Bool
    public var wcGlobalStopwordsJSON: String
    public var wcLensStopwordsJSON: String
    public var citationStyleRaw: String
    public var defaultDocumentModeRaw: String
    public var researchLoggingEnabled: Bool
    public var listOrderJSON: String

    /// The memberwise initialiser, spelled out because a synthesized one is never `public`.
    public init(
        createdAt: Date,
        updatedAt: Date,
        wcMinLength: Int,
        wcMinCount: Int,
        wcFoldPlurals: Bool,
        wcFilterMarkings: Bool,
        wcExcludeBoilerplate: Bool,
        wcGlobalStopwordsJSON: String,
        wcLensStopwordsJSON: String,
        citationStyleRaw: String,
        defaultDocumentModeRaw: String,
        researchLoggingEnabled: Bool,
        listOrderJSON: String
    ) {
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.wcMinLength = wcMinLength
        self.wcMinCount = wcMinCount
        self.wcFoldPlurals = wcFoldPlurals
        self.wcFilterMarkings = wcFilterMarkings
        self.wcExcludeBoilerplate = wcExcludeBoilerplate
        self.wcGlobalStopwordsJSON = wcGlobalStopwordsJSON
        self.wcLensStopwordsJSON = wcLensStopwordsJSON
        self.citationStyleRaw = citationStyleRaw
        self.defaultDocumentModeRaw = defaultDocumentModeRaw
        self.researchLoggingEnabled = researchLoggingEnabled
        self.listOrderJSON = listOrderJSON
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
    /// user had no plans, while a v5 file means the format could not carry them. The bump to 7
    /// carries the eight model types 6 left out and the fields 6 dropped from the types it carried,
    /// by the same argument: an empty v7 `savedSearches` means none were saved, and a `nil`
    /// `richText` on a v7 note means it has no formatting, where on a v6 note it means the format
    /// could not carry it.)
    ///
    /// Declared here, beside the envelope, since FRUS Explorer Light moved the envelope into
    /// FRUSCoreKit; the app's `ResearchDataExporter.currentFormatVersion` is this value.
    public static let currentFormatVersion = 7

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
