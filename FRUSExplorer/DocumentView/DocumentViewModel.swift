// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Observation
import SwiftData

// MARK: - DocumentViewModel

/// Manages state for the Document view: loading the rendered document, subject tags,
/// person/gloss lookup tables, and research-note cross-project indicator.
///
/// ## Loading Sequence
/// 1. `load()` is called on appear with the volume URL.
/// 2. Parses the document AST and persons/terms in parallel.
/// 3. Converts the AST to a `FRUSDocumentRenderModel` with person/gloss lookup closures.
/// 4. Fetches subject tags from `SubjectTagStore`.
/// 5. `recordReadingHistory()` inserts a `ReadingHistoryEntry` into SwiftData.
///
/// ## persName / gloss Sheets
/// `selectedPerson` and `selectedGloss` are set by the renderer callbacks and drive
/// sheet presentation. Cross-reference navigation appends a new `.document` level to
/// `BrowserViewModel.navigationPath`.
///
/// ## Summarization
/// `generateSummary(prompt:provider:service:activeProjectId:context:)` builds a
/// `SummarizationPromptSnapshot` on the main actor (safe for `@Model` access), then
/// calls `SummarizationService.summarize` across the actor boundary.
/// `documentPlainText` is populated during `load()` from `FRUSASTNode.plainText`.
///
/// Version history:
///   1.0 — Session 12: initial implementation
///   1.1 — Session 20: add documentPlainText, isSummarizing, showSummarizeSheet, generateSummary
///   1.2 — Session 40: personMentionStore dependency; selectedPersonMentionCount; loadPersonMentionCount
///   1.3 — Session 41: persons/terms resolved from SQLite first; XML parse kept as fallback
///   1.4 — Session 66: `documentTitle` stored property added; set from first `<head>` element
///          after load so cross-reference targets (created with `header: ""`) can supply
///          a meaningful navigation title once the document has been parsed
@Observable
@MainActor
public final class DocumentViewModel {

    // MARK: - Document State

    /// The fully-rendered model, set after a successful load.
    public var renderModel: FRUSDocumentRenderModel?

    /// Plain-text document title extracted from the first `<head>` element, set
    /// after a successful load.  Used as the navigation title when the
    /// `DocumentBrowserEntry` was created without a header (e.g. cross-reference
    /// targets, which are constructed with `header: ""` because the title is not
    /// known until the XML is parsed).
    public var documentTitle: String?

    /// `true` while the document is being parsed/converted.
    public var isLoading: Bool = false

    /// Non-nil if loading failed.
    public var loadError: Error? = nil

    // MARK: - Person / Gloss Lookup Tables

    /// Persons from the volume's `<listPerson>`, indexed by `ref` attribute.
    public var personsByRef: [String: PersonEntry] = [:]

    /// Glossary terms from the volume's `<glossary>`, indexed by `ref` attribute.
    public var termsByRef: [String: GlossEntry] = [:]

    // MARK: - Tag State

    /// Subject tags for this document (curated + string-match), loaded after parse.
    public var subjectTags: [SubjectTag] = []

    // MARK: - Sheet State

    /// Person selected via a `<persName>` tap; drives the List of Persons sheet.
    public var selectedPerson: PersonEntry? = nil

    /// Gloss entry selected via a `<gloss>` tap; drives the Terms sheet.
    public var selectedGloss: GlossEntry? = nil

    /// Count of indexed documents that mention the currently-selected person.
    /// Set to 0 when no person is selected or when `personMentionStore` is nil.
    public var selectedPersonMentionCount: Int = 0

    // MARK: - Research Note Indicator

    /// Count of research notes attached to this document that belong to a
    /// project OTHER than the currently active project.
    public var crossProjectNoteCount: Int = 0

    /// The actual notes counted above, stored for cross-project reveal UI.
    var crossProjectNotes: [ResearchNote] = []

    // MARK: - Summaries

    /// Summaries for this document, ordered newest-first.
    var summaries: [GeneratedSummary] = []

    /// Index of the summary currently displayed (0 = most recent).
    public var activeSummaryIndex: Int = 0

    var activeSummary: GeneratedSummary? {
        guard !summaries.isEmpty, summaries.indices.contains(activeSummaryIndex) else { return nil }
        return summaries[activeSummaryIndex]
    }

    // MARK: - Summarization

    /// Plain text of the document body, set during `load()`. Used as input to `SummarizationService`.
    public var documentPlainText: String = ""

    /// `true` while a summarization request is in flight.
    public var isSummarizing: Bool = false

    // MARK: - Source Explorer

    /// Raw plain-text source note extracted during `load()`. `nil` if the document has no source note.
    public var sourceNote: String? = nil

    // MARK: - Citation

    /// The formatted citation string, available when a volume entry was supplied at init.
    public var formattedCitation: String? {
        guard let volumeEntry else { return nil }
        let docMeta = FRUSDocumentMetadata(entry)
        let volMeta = FRUSVolumeMetadata(volumeEntry)
        return HistoryAtStateCitationFormatter().format(document: docMeta, volume: volMeta)
    }

    // MARK: - Dependencies

    public let entry: DocumentBrowserEntry
    /// Volume manifest entry used for citation generation. `nil` when not found in manifest.
    public let volumeEntry: VolumeManifestEntry?
    private let parser: FRUSDocumentParser
    private let subjectTagStore: SubjectTagStore
    /// Person mention store for "Find all mentions" feature. Optional — `nil` if the
    /// database could not be opened at boot or in test contexts that don't need it.
    private let personMentionStore: PersonMentionStore?

    // MARK: - Init

    public init(
        entry: DocumentBrowserEntry,
        volumeEntry: VolumeManifestEntry?,
        parser: FRUSDocumentParser,
        subjectTagStore: SubjectTagStore,
        personMentionStore: PersonMentionStore? = nil
    ) {
        self.entry = entry
        self.volumeEntry = volumeEntry
        self.parser = parser
        self.subjectTagStore = subjectTagStore
        self.personMentionStore = personMentionStore
    }

    // MARK: - Loading

    /// Parses the document, populates lookup tables, converts to a render model,
    /// and fetches subject tags. Idempotent if already loaded.
    public func load(volumeURL: URL) async {
        guard renderModel == nil else { return }
        isLoading = true
        loadError = nil
        do {
            // Parse document AST concurrently with SQLite glossary lookup.
            // For indexed volumes the SQLite path is fast and avoids re-parsing the
            // full volume XML. The XML parse is kept as a fallback for volumes that
            // are downloaded but not yet indexed.
            async let astResult = parser.parseDocument(documentId: entry.documentId,
                                                       volumeURL: volumeURL)

            // SQLite-first persons lookup
            let persons: [PersonEntry]
            let sqlPersons = (try? await personMentionStore?.allPersons(forVolumeId: entry.volumeId)) ?? []
            if sqlPersons.isEmpty {
                persons = (try? await parser.parsePersons(volumeURL: volumeURL)) ?? []
            } else {
                persons = sqlPersons
            }

            // SQLite-first terms lookup
            let terms: [GlossEntry]
            let sqlTerms = (try? await personMentionStore?.allTerms(forVolumeId: entry.volumeId)) ?? []
            if sqlTerms.isEmpty {
                terms = (try? await parser.parseTerms(volumeURL: volumeURL)) ?? []
            } else {
                terms = sqlTerms
            }

            guard let ast = try await astResult else {
                loadError = DocumentLoadError.documentNotFound(entry.documentId)
                isLoading = false
                return
            }

            // Build lookup tables
            var pByRef: [String: PersonEntry] = [:]
            for p in persons { pByRef[p.ref] = p }
            var tByRef: [String: GlossEntry] = [:]
            for t in terms { tByRef[t.ref] = t }
            personsByRef = pByRef
            termsByRef   = tByRef

            // Extract document title from the first <head> element.
            // Needed when this DocumentView was created via a cross-reference
            // (entry.header == "") and must show a meaningful navigation title.
            for node in ast.nodes {
                if case .head(let c) = node {
                    let t = c.map(\.plainText).joined(separator: " ")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !t.isEmpty { documentTitle = t }
                    break
                }
            }

            // Store plain text for summarization before converting to render model
            documentPlainText = ast.nodes
                .map(\.plainText)
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .joined(separator: "\n\n")

            // Extract source note for Source Explorer
            sourceNote = extractSourceNote(from: ast.nodes)

            // Convert AST → render model with lookup closures
            var converter = ASTToRenderNodeConverter(
                personLookup: { [pByRef] ref in pByRef[ref] },
                glossLookup:  { [tByRef] ref in tByRef[ref] }
            )
            renderModel = converter.convert(ast)

            // Fetch subject tags
            subjectTags = await subjectTagStore.tags(forDocumentId: entry.documentId)

            #if DEBUG
            print("[DocumentView] Loaded \(entry.volumeId)/\(entry.documentId) " +
                  "bodyNodes=\(renderModel?.bodyNodes.count ?? 0) " +
                  "subjectTags=\(subjectTags.count)")
            #endif
        } catch {
            loadError = error
            #if DEBUG
            print("[DocumentView] Load failed for \(entry.documentId): \(error)")
            #endif
        }
        isLoading = false
    }

    // MARK: - Reading History

    /// Inserts a `ReadingHistoryEntry` into the SwiftData context.
    /// Call this once after a successful load, passing the active project ID.
    public func recordReadingHistory(projectId: UUID?, in context: ModelContext) {
        let record = ReadingHistoryEntry(
            documentId: entry.documentId,
            volumeId: entry.volumeId,
            displayTitle: entry.header.isEmpty ? nil : entry.header,
            projectId: projectId
        )
        context.insert(record)
        #if DEBUG
        print("[DocumentView] ReadingHistoryEntry recorded: \(entry.volumeId)/\(entry.documentId)")
        #endif
    }

    // MARK: - Cross-Project Notes

    /// Refreshes `crossProjectNoteCount` from SwiftData.
    ///
    /// A note is "cross-project" if it is attached to this document and does NOT
    /// include the current active project in its `projectIds` list.
    public func refreshCrossProjectNoteCount(activeProjectId: UUID?, context: ModelContext) {
        let docId = entry.documentId
        let volId = entry.volumeId
        let descriptor = FetchDescriptor<ResearchNote>(
            predicate: #Predicate { note in
                note.documentId == docId && note.volumeId == volId
            }
        )
        let all = (try? context.fetch(descriptor)) ?? []
        if let pid = activeProjectId {
            let foreign = all.filter { !$0.projectIds.contains(pid) }
            crossProjectNoteCount = foreign.count
            crossProjectNotes = foreign
        } else {
            crossProjectNoteCount = 0
            crossProjectNotes = []
        }
    }

    // MARK: - Summaries

    /// Loads summaries for this document from SwiftData, ordered newest-first.
    public func loadSummaries(context: ModelContext) {
        let docId = entry.documentId
        let volId = entry.volumeId
        var descriptor = FetchDescriptor<GeneratedSummary>(
            predicate: #Predicate { s in
                s.documentId == docId && s.volumeId == volId
            }
        )
        descriptor.fetchLimit = 20
        summaries = ((try? context.fetch(descriptor)) ?? [])
            .sorted { ($0.lastModified ?? .distantPast) > ($1.lastModified ?? .distantPast) }
        activeSummaryIndex = 0
    }

    /// Generates a summary for the current document using the given prompt and provider.
    ///
    /// Creates a `SummarizationPromptSnapshot` on the main actor before crossing into
    /// the `SummarizationService` actor, satisfying Swift 6 Sendable requirements.
    /// Reloads `summaries` and resets `activeSummaryIndex` to 0 on completion.
    func generateSummary(
        prompt: SummarizationPrompt,
        provider: any SummarizationProvider,
        service: SummarizationService,
        activeProjectId: UUID?,
        context: ModelContext
    ) async {
        guard !documentPlainText.isEmpty, !isSummarizing else { return }
        isSummarizing = true

        // Build snapshot on main actor before crossing actor boundary
        let snapshot = SummarizationPromptSnapshot(from: prompt)

        do {
            try await service.summarizeDiscarding(
                documentId: entry.documentId,
                volumeId: entry.volumeId,
                documentText: documentPlainText,
                prompt: snapshot,
                provider: provider,
                activeProjectId: activeProjectId
            )
            loadSummaries(context: context)
            #if DEBUG
            print("[SummarizationUI] Summary generated for \(entry.volumeId)/\(entry.documentId)")
            #endif
        } catch {
            #if DEBUG
            print("[SummarizationUI] Generation failed for \(entry.documentId): \(error)")
            #endif
        }

        isSummarizing = false
    }

    // MARK: - Source Note Extraction

    private func extractSourceNote(from nodes: [FRUSASTNode]) -> String? {
        extractSourceNote(from: nodes)
    }

    // MARK: - Person Mention Count

    /// Fetches and stores the number of indexed documents that mention `person`.
    /// Resets to 0 if `personMentionStore` is nil (e.g. during testing).
    public func loadPersonMentionCount(for person: PersonEntry) async {
        guard let store = personMentionStore else {
            selectedPersonMentionCount = 0
            return
        }
        selectedPersonMentionCount = (try? await store.documentCount(forPersonRef: person.ref)) ?? 0
    }
}

// MARK: - Source Note Extraction

/// Searches `nodes` for a FRUS provenance note, handling three placement patterns
/// found across the series:
///
/// 1. **Standard** — `<note type="source">` as a direct child of `<div type="document">`.
///    Present in all eras. Parsed as `.footnote(type: .source)` at the top level of
///    `ast.nodes`.
///
/// 2. **Nixon-Ford era electronic volumes** — a generic `<note n="1">` (no `type`
///    attribute) containing `<seg type="source">` and `<seg type="summary">` paragraph
///    children. Parsed as `.footnote(type: .unclassified)` whose children include
///    `.unknown("seg", ["type": "source"], …)` nodes. `extractSegSourceText` locates
///    the source segment.
///
/// 3. **Source note inside `<head>`** — some volumes embed the source note directly
///    within the document heading element. Parsed as a `.footnote(type: .source)` child
///    of a `.head` node. Handled by a second pass that recurses into `.head` children.
///
/// Returns the plain-text content of the first match, or `nil` if no source note is
/// found. Whitespace is trimmed; an all-whitespace match is treated as absent.
func extractSourceNote(from nodes: [FRUSASTNode]) -> String? {
    // Pass 1: top-level .footnote nodes — covers standards (1) and Nixon-Ford (2).
    for node in nodes {
        switch node {
        case .footnote(_, .source, _, let children):
            let text = children
                .map(\.plainText)
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { return text }

        case .footnote(_, .unclassified, _, let children):
            if let text = extractSegSourceText(from: children) { return text }

        default:
            break
        }
    }

    // Pass 2: recurse into <head> — covers volumes that place the source note
    // inside the document heading element rather than as a div-level sibling.
    for node in nodes {
        if case .head(let headChildren) = node {
            if let text = extractSourceNote(from: headChildren) { return text }
        }
    }

    return nil
}

/// Searches `nodes` for a `<seg type="source">` element and returns its plain-text
/// content.
///
/// `<seg>` is not a first-class AST node; the parser maps it to
/// `.unknown("seg", attributes, children)`. The source segment is typically wrapped
/// in a `<p>` element, so this function recurses into `.paragraph` children as well.
///
/// Used exclusively by `extractSourceNote` to handle the Nixon-Ford era pattern.
private func extractSegSourceText(from nodes: [FRUSASTNode]) -> String? {
    for node in nodes {
        switch node {
        case .unknown(let name, let attrs, let children)
                where name == "seg" && attrs["type"] == "source":
            let text = children
                .map(\.plainText)
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { return text }
        case .paragraph(let children):
            if let text = extractSegSourceText(from: children) { return text }
        default:
            break
        }
    }
    return nil
}

// MARK: - DocumentLoadError

public enum DocumentLoadError: LocalizedError {
    case documentNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .documentNotFound(let id):
            return "Document '\(id)' was not found in the volume."
        }
    }
}
