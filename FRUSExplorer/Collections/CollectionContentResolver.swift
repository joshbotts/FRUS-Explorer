// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - CollectionResolveError

/// Errors thrown while resolving a collection into export items. Each case carries the
/// same user-facing message the export sheet showed before the resolver extraction, so
/// `error.localizedDescription` presents identically in the UI.
///
/// Version history:
///   1.0 — Session 2026-07-02 (Collections Authoring Phase 2a): extracted from the
///          inline `exportError` assignments in `ExportSheetView.runExport()`
enum CollectionResolveError: Error, LocalizedError {
    /// The FTS5-backed `SearchService` was unavailable while resolving a smart collection.
    case searchServiceUnavailable
    /// The smart collection's linked `SavedSearch` no longer exists.
    case savedSearchMissing
    /// An `.export` resolve found `.summaryOnly` documents but the collection has no
    /// summarization prompt configured.
    case summaryPromptMissing

    /// User-facing description — the exact strings the export sheet showed pre-extraction.
    var errorDescription: String? {
        switch self {
        case .searchServiceUnavailable:
            return String(localized: "export.smart.noSearchService",
                          defaultValue: "Search service unavailable. Please try again.")
        case .savedSearchMissing:
            return String(localized: "export.smart.missingSearch",
                          defaultValue: "The linked saved search could not be found. It may have been deleted.")
        case .summaryPromptMissing:
            return String(localized: "export.summaryNoPrompt",
                          defaultValue: "Choose a summarization prompt in the collection's Composition section to export summaries.")
        }
    }
}

// MARK: - CollectionContentResolver

/// Resolves a `Collection` (static or smart) into the ordered `[CollectionExportItem]`
/// that exporters — and, from Phase 2b, the live preview — consume. This is the single
/// resolution pipeline for collection content: the export sheet keeps only UI and file
/// delivery, and every format (PDF/HTML/DOCX/Zotero/BibTeX) sees identical resolved items.
///
/// ## Unified smart path (Phase 2a behavior change)
/// Smart (saved-search) collections previously resolved through a near-clone that dropped
/// research notes, highlights, and source notes. They now run through the same per-document
/// pipeline as static entries, so **collection-level composition is honored**: `includeNotes`
/// (every research note attached to the document travels on `noteTexts`), `applyHighlights`,
/// `footnoteStyle == .sourceNoteOnly`, and the collection's default body depth (including
/// `.summaryOnly`). *Per-entry* overrides still don't apply to smart collections — their
/// entries are synthesized from search results and carry no overrides or note selections.
///
/// ## Render-model cache
/// Parsed documents are served from the app-wide `DocumentASTCache` actor
/// (`appState.documentASTCache`), keyed `(volumeId, documentId)`, so repeated resolves in a
/// session skip the expensive SAX re-parse; cache misses parse once and store back. The AST —
/// not the converted render model — is cached deliberately: `DocumentASTCache` is already
/// invalidated on volume deletion/re-index by `FRUSExplorerApp`, and the resolver always runs
/// a fresh `ASTToRenderNodeConverter` over the cached AST, so a stale render model can never
/// be served. `ASTToRenderNodeConverter.renderingVersion(for:)` is *not* used for validation
/// here: that hash detects staleness across converter-version bumps (i.e. across app builds)
/// for *persisted* highlights, which cannot occur inside a purely in-memory, per-launch cache.
///
/// ## Purpose
/// `.export` behaves as the pre-extraction export flow did: missing volumes are downloaded
/// and indexed first, and `.summaryOnly` documents get on-demand AI summary generation.
/// `.preview` **never downloads volumes and never generates summaries** — documents from
/// un-downloaded volumes resolve to citation-only items (empty body, no render model), and
/// `.summaryOnly` documents keep a `nil` summary unless one is already stored (the preview
/// renders placeholders for those, Phase 2b).
///
/// ## Cooperative cancellation (v1.1)
/// The per-document loops — the batch-context load and the per-entry resolve pass — check
/// `Task.isCancelled` and stop early, so a superseded preview resolve does not SAX-parse
/// documents nobody will render. The loops themselves stay non-throwing and return a
/// *partial-safe* result (fewer loaded contexts / fewer items — never junk); the throwing
/// entry points (`resolve`, `resolve(smartRefs:…)`, `resolveDocuments`) then convert the
/// cancellation into a thrown `CancellationError` so no caller can mistake a truncated
/// result for a complete one.
///
/// Version history:
///   1.0 — Session 2026-07-02 (Collections Authoring Phase 2a): extracted from
///          `ExportSheetView` (`resolveItems`, `resolveDocuments`, `resolveSmartDocuments`,
///          `resolveSummaries`, `prepareVolumes`, render-model helpers); smart path unified
///          with the static per-document pipeline; AST-cache-backed render models;
///          `purpose` gating; per-item incremental API for the Phase 2b preview
///   1.1 — Authoring Phase 2b (preview-review fixes): cooperative cancellation in the
///          per-document loops with `CancellationError` surfaced by the throwing entry
///          points; `smartRefs(for:)` exposed and `resolve(smartRefs:…)` added so the
///          preview can cap the smart result list *before* per-document resolution
///   1.2 — Authoring Phase 4: the flat `currentSectionDepth` tracking replaced with
///          `CollectionOutline.sectionBodyDepthOverrides` (nearest-*ancestor* heading by
///          level — behavior-identical for all-level-1 collections); `EntryRef` snapshots
///          the heading `level`, defensively clamped by the outline's resolution so a
///          synced out-of-range value degrades instead of corrupting
@MainActor
class CollectionContentResolver {

    // MARK: - ResolvePurpose

    /// What the resolved items are for. Gates the side-effecting phases of a resolve.
    enum ResolvePurpose {
        /// Full export behavior: missing volumes are downloaded and indexed before
        /// resolution, and `.summaryOnly` documents generate summaries on demand.
        case export
        /// Read-only resolution for the live preview: never downloads volumes and never
        /// triggers AI generation. Un-downloaded volumes yield citation-only items;
        /// `.summaryOnly` documents attach a stored summary when one exists, else `nil`.
        case preview
    }

    // MARK: - SmartDocumentRef

    /// Lightweight document reference used for smart-collection resolution — one search
    /// result to resolve. Avoids creating SwiftData model instances outside a context.
    struct SmartDocumentRef: Sendable {
        /// The FRUS document identifier (e.g. `"d12"`).
        let documentId: String
        /// The containing volume identifier.
        let volumeId: String
        /// Position within the result set (ascending).
        let sortOrder: Int

        /// Creates a smart-collection document reference.
        init(documentId: String, volumeId: String, sortOrder: Int) {
            self.documentId = documentId
            self.volumeId = volumeId
            self.sortOrder = sortOrder
        }
    }

    // MARK: - Dependencies

    /// Source of the shared services used during resolution: manifest store, indexing
    /// pipeline, download manager, AST cache, summarization service, and active project.
    private let appState: AppState

    /// SwiftData context for fetching highlights, prompts, stored summaries, saved
    /// searches, and Zotero tag/note lookups.
    private let modelContext: ModelContext

    /// Reports volume-preparation progress messages (nil clears). Driven only during
    /// `.export` resolves; the export sheet binds this to its `preparingMessage` state.
    private let onPreparingStatus: ((String?) -> Void)?

    /// Reports on-demand summary-generation progress messages (nil clears). Driven only
    /// during `.export` resolves; the export sheet binds this to its
    /// `summaryGeneratingMessage` state.
    private let onSummaryStatus: ((String?) -> Void)?

    /// Creates a resolver bound to the app's shared services.
    ///
    /// - Parameters:
    ///   - appState: Provides the manifest store, indexing pipeline, download manager,
    ///     document AST cache, and summarization service.
    ///   - modelContext: SwiftData context for user-data lookups during resolution.
    ///   - onPreparingStatus: Optional volume-preparation progress callback (export only).
    ///   - onSummaryStatus: Optional summary-generation progress callback (export only).
    init(
        appState: AppState,
        modelContext: ModelContext,
        onPreparingStatus: ((String?) -> Void)? = nil,
        onSummaryStatus: ((String?) -> Void)? = nil
    ) {
        self.appState = appState
        self.modelContext = modelContext
        self.onPreparingStatus = onPreparingStatus
        self.onSummaryStatus = onSummaryStatus
    }

    // MARK: - Public API

    /// Resolves a collection's content into ordered export items.
    ///
    /// Smart collections (non-nil `savedSearchId`) execute their linked saved search and
    /// resolve every result through the unified per-document pipeline (see the type doc for
    /// the composition semantics). Static collections resolve their `entries`, preserving
    /// authored structure: headings and prose pass through, and the Phase 3c body-depth
    /// cascade (entry override → section override → collection default) applies per document.
    ///
    /// For `.export`, missing volumes are downloaded/indexed first (static collections only —
    /// smart results come from the index, so their volumes are present by construction) and
    /// `.summaryOnly` documents generate summaries on demand. For `.preview`, neither
    /// side-effecting phase runs.
    ///
    /// - Parameters:
    ///   - collection: The collection to resolve.
    ///   - entries: The collection's entries (ignored for smart collections).
    ///   - allNotes: All research notes, for resolving entry note links and (smart path)
    ///     per-document note attachment.
    ///   - purpose: Gates volume preparation and summary generation (see `ResolvePurpose`).
    /// - Returns: Ordered export items ready for any `CollectionExporter`.
    /// - Throws: `CollectionResolveError` for smart-resolution and summary-prompt failures,
    ///   `ExportError.renderingFailed` when on-demand summary generation is impossible,
    ///   `CancellationError` when the surrounding task was cancelled mid-resolve (v1.1).
    func resolve(
        collection: Collection,
        entries: [CollectionEntry],
        allNotes: [ResearchNote],
        purpose: ResolvePurpose
    ) async throws -> [CollectionExportItem] {
        let items = try await resolveWithoutSummaries(
            collection: collection, entries: entries, allNotes: allNotes, purpose: purpose)
        // A cancelled pass returned partial-safe items — surface the cancellation instead
        // of handing a truncated result to a caller that expected the whole collection.
        try Task.checkCancellation()
        return try await applySummaryPhase(to: items, collection: collection, purpose: purpose)
    }

    /// Resolves a pre-fetched (and possibly capped) smart-reference list into export items,
    /// including the summary phase — the preview's smart path (v1.1). The preview fetches
    /// the lightweight refs with `smartRefs(for:)`, caps them to its render limit, and only
    /// then pays per-document resolution here, so at most the cap is ever parsed.
    ///
    /// - Parameters:
    ///   - refs: The smart-collection document references to resolve, in order.
    ///   - collection: The owning collection (composition + default body depth).
    ///   - allNotes: All research notes, for per-document note attachment.
    ///   - purpose: Gates the summary phase (see `ResolvePurpose`).
    /// - Returns: Ordered export items for exactly the given refs.
    /// - Throws: `CancellationError` when the surrounding task was cancelled mid-resolve;
    ///   summary-phase errors for `.export` (see `applySummaryPhase`).
    func resolve(
        smartRefs refs: [SmartDocumentRef],
        collection: Collection,
        allNotes: [ResearchNote],
        purpose: ResolvePurpose
    ) async throws -> [CollectionExportItem] {
        let items = await resolveSmartItems(refs, collection: collection, allNotes: allNotes)
        try Task.checkCancellation()
        return try await applySummaryPhase(to: items, collection: collection, purpose: purpose)
    }

    /// Documents-only resolution — for callers that need a flat document list and no
    /// summary phase (e.g. the Zotero RIS/Web-API send paths, which render citations and
    /// notes, never body content). Matches the pre-extraction `resolvedZoteroDocuments()`
    /// behavior: headings and prose are dropped, and `.summaryOnly` depths pass through
    /// without triggering generation.
    ///
    /// - Parameters: See `resolve(collection:entries:allNotes:purpose:)`.
    /// - Returns: The resolved `.document` payloads, in collection order.
    /// - Throws: `CollectionResolveError` for smart-resolution failures, `CancellationError`
    ///   when the surrounding task was cancelled mid-resolve (v1.1).
    func resolveDocuments(
        collection: Collection,
        entries: [CollectionEntry],
        allNotes: [ResearchNote],
        purpose: ResolvePurpose
    ) async throws -> [CollectionExportDocument] {
        let documents = try await resolveWithoutSummaries(
            collection: collection, entries: entries, allNotes: allNotes, purpose: purpose)
            .documents
        // Same discipline as `resolve`: never hand back a cancellation-truncated list.
        try Task.checkCancellation()
        return documents
    }

    /// Resolves a single entry into its export item — the incremental API for the Phase 2b
    /// preview's refresh path. Shares the per-entry pipeline with the batch resolve, so a
    /// re-resolved row is guaranteed to match what a full resolve would produce.
    ///
    /// This path is inherently preview-safe: it never downloads volumes and never generates
    /// summaries. A `.summaryOnly` document attaches a stored summary when one exists for
    /// the collection's prompt; otherwise `summaryText` stays `nil`.
    ///
    /// - Parameters:
    ///   - entry: The entry to resolve (document, heading, or prose).
    ///   - collection: The owning collection (composition + default body depth).
    ///   - allNotes: All research notes, for resolving the entry's note links.
    ///   - sectionBodyDepth: The `bodyDepthOverride` of the nearest preceding heading, if
    ///     any — the caller tracks section state, since a single entry can't know it.
    /// - Returns: The resolved item, or `nil` for `.unrecognized` kinds and malformed
    ///   document entries (empty ids), which a full resolve would also skip.
    func resolveItem(
        _ entry: CollectionEntry,
        collection: Collection,
        allNotes: [ResearchNote],
        sectionBodyDepth: String? = nil
    ) async -> CollectionExportItem? {
        let ref = EntryRef(entry)
        let batch = await loadBatchContext(for: [ref], collection: collection, allNotes: allNotes)
        guard let item = await resolveEntry(ref, sectionDepth: sectionBodyDepth, batch: batch) else {
            return nil
        }
        // Attach a stored summary when available; never generate (preview semantics).
        if case .document(let doc) = item, doc.bodyDepth == .summaryOnly,
           let promptId = collection.summaryPromptId,
           let stored = storedSummary(volumeId: doc.volumeId, documentId: doc.documentId,
                                      promptId: promptId) {
            return .document(doc.withSummary(stored))
        }
        return item
    }

    // MARK: - Core resolution (shared by both public entry points)

    /// Runs the full resolution *except* the summary phase — the shared body of
    /// `resolve` (which adds summaries) and `resolveDocuments` (which must not).
    private func resolveWithoutSummaries(
        collection: Collection,
        entries: [CollectionEntry],
        allNotes: [ResearchNote],
        purpose: ResolvePurpose
    ) async throws -> [CollectionExportItem] {
        // Smart collection path: resolve documents via the linked SavedSearch, then run
        // them through the unified per-document pipeline.
        if collection.savedSearchId != nil {
            let refs = try await smartRefs(for: collection)
            return await resolveSmartItems(refs, collection: collection, allNotes: allNotes)
        }

        // Static collection path.
        // Export only: ensure every referenced volume is downloaded and indexed first.
        // Preview must never trigger downloads — un-downloaded volumes resolve to
        // citation-only items instead.
        if purpose == .export {
            await prepareVolumesForExport(Set(entries.map(\.volumeId)))
        }

        let refs = entries.map(EntryRef.init)
        let batch = await loadBatchContext(for: refs, collection: collection, allNotes: allNotes)
        return await resolveItems(from: refs, batch: batch)
    }

    /// Executes a smart collection's linked saved search and returns one reference per
    /// result, in relevance order. Mirrors the pre-extraction smart export flow, including
    /// the full-result-set fetch (`SearchViewModel.searchHardLimit`, not the default page).
    ///
    /// Internal (v1.1) so the live preview can fetch the *lightweight* result list, cap it
    /// to its render limit, and resolve only the capped refs via `resolve(smartRefs:…)` —
    /// the refs are cheap (an FTS5 query); per-document resolution is what parses XML.
    ///
    /// - Parameter collection: The smart collection whose saved search to execute.
    /// - Returns: One reference per search result, `sortOrder` ascending.
    /// - Throws: `CollectionResolveError.searchServiceUnavailable` /
    ///   `.savedSearchMissing`, or any search execution error.
    func smartRefs(for collection: Collection) async throws -> [SmartDocumentRef] {
        guard let searchId = collection.savedSearchId else { return [] }
        guard let searchService = appState.searchService else {
            throw CollectionResolveError.searchServiceUnavailable
        }
        let descriptor = FetchDescriptor<SavedSearch>(
            predicate: #Predicate { $0.id == searchId }
        )
        guard let savedSearch = try? modelContext.fetch(descriptor).first else {
            throw CollectionResolveError.savedSearchMissing
        }
        // Resolve the full result set (not just the first page) — the default `search`
        // limit is `defaultPageSize` (20), which silently truncated smart-collection
        // exports. Mirror the live saved search's hard limit.
        let results = try await searchService.search(
            parameters: savedSearch.searchParameters,
            limit: SearchViewModel.searchHardLimit
        )
        return results.enumerated().map { i, r in
            SmartDocumentRef(documentId: r.documentId, volumeId: r.volumeId, sortOrder: i)
        }
    }

    /// Resolves smart-collection references through the unified per-document pipeline.
    ///
    /// This replaces the former `resolveSmartDocuments` near-clone: the same per-entry
    /// body now serves both paths, so smart documents carry composition-driven content
    /// (notes, highlights, source notes) they previously dropped. Synthetic entries have
    /// no per-entry overrides or note selections, so the collection default body depth
    /// applies and note attachment falls back to *every* research note on the document
    /// (matching what the smart Zotero items already carried).
    ///
    /// Internal (not private) so tests can exercise the unified pipeline without standing
    /// up a live FTS5 search service.
    func resolveSmartItems(
        _ refs: [SmartDocumentRef],
        collection: Collection,
        allNotes: [ResearchNote]
    ) async -> [CollectionExportItem] {
        let entryRefs = refs.map(EntryRef.init)
        let batch = await loadBatchContext(for: entryRefs, collection: collection, allNotes: allNotes)
        return await resolveItems(from: entryRefs, batch: batch)
    }

    /// Runs the ordered per-entry loop: sorts by `sortOrder`, resolves each position's
    /// effective section body-depth override via `CollectionOutline` (the nearest
    /// *ancestor* heading's override by level — Phase 4's extension of the Phase 3c
    /// "nearest preceding heading" rule, identical for all-level-1 collections), and
    /// delegates each entry to `resolveEntry`. Out-of-range heading levels are clamped
    /// inside the outline resolution, never persisted back.
    ///
    /// Cooperative cancellation (v1.1): a cancelled task stops the loop early and returns
    /// the items resolved so far (partial-safe — every returned item is complete); the
    /// throwing entry points convert the truncation into a thrown `CancellationError`.
    private func resolveItems(from refs: [EntryRef], batch: BatchContext) async -> [CollectionExportItem] {
        let ordered = refs.sorted { $0.sortOrder < $1.sortOrder }
        // Single-linearizer discipline: the ancestor cascade is computed by
        // CollectionOutline, never re-derived here.
        let sectionDepths = CollectionOutline.sectionBodyDepthOverrides(ordered.map {
            CollectionOutline.StructuralRef(isHeading: $0.kind == .heading,
                                            level: $0.level,
                                            bodyDepthOverride: $0.bodyDepthOverride)
        })
        var items: [CollectionExportItem] = []
        for (i, ref) in ordered.enumerated() {
            if Task.isCancelled { break }
            if let item = await resolveEntry(ref, sectionDepth: sectionDepths[i], batch: batch) {
                items.append(item)
            }
        }
        return items
    }

    // MARK: - EntryRef

    /// How a resolved document's research-note texts are determined.
    private enum NoteResolution {
        /// Static entries: the entry's own selection — `selectedNoteIds`, falling back to
        /// the legacy single `researchNoteId` link.
        case entrySelection(selectedNoteIds: [UUID], legacyNoteId: UUID?)
        /// Synthetic smart-collection entries carry no selection: every research note
        /// attached to the document travels (the pre-unification smart Zotero behavior).
        case allDocumentNotes
    }

    /// Value snapshot of one entry — real (`CollectionEntry`) or synthetic (smart search
    /// result) — fed to the shared per-entry pipeline, so the pipeline itself never
    /// touches SwiftData model instances it didn't fetch.
    private struct EntryRef {
        /// The entry kind (document/heading/prose/unrecognized).
        let kind: CollectionEntryKind
        /// The FRUS document identifier; empty for heading/prose entries.
        let documentId: String
        /// The containing volume identifier; empty for heading/prose entries.
        let volumeId: String
        /// Position within the collection (ascending).
        let sortOrder: Int
        /// Heading title text (`.heading` entries only).
        let text: String?
        /// Heading nesting level (`.heading` entries only; raw model value — clamped by
        /// `CollectionOutline` during resolution, never trusted directly).
        let level: Int
        /// Prose body as export-ready RTF (`.prose` entries only), produced by
        /// `ProseRichText.exportRTF(from:)` at snapshot time.
        let proseRTF: Data?
        /// The entry's own body-depth override raw value, if any.
        let bodyDepthOverride: String?
        /// How research-note texts are resolved for this entry.
        let noteResolution: NoteResolution

        /// Snapshots a real collection entry. Prose entries are converted to export RTF
        /// here (which also heals legacy Phase 3b blobs in place — see `ProseRichText`).
        init(_ entry: CollectionEntry) {
            kind = entry.entryKind
            documentId = entry.documentId
            volumeId = entry.volumeId
            sortOrder = entry.sortOrder
            text = entry.text
            level = entry.level
            proseRTF = entry.entryKind == .prose ? ProseRichText.exportRTF(from: entry) : nil
            bodyDepthOverride = entry.bodyDepthOverride
            noteResolution = .entrySelection(selectedNoteIds: entry.selectedNoteIds,
                                             legacyNoteId: entry.researchNoteId)
        }

        /// Synthesizes an entry for one smart-collection search result: always a
        /// `.document`, with no overrides and all-document note resolution.
        init(_ ref: SmartDocumentRef) {
            kind = .document
            documentId = ref.documentId
            volumeId = ref.volumeId
            sortOrder = ref.sortOrder
            text = nil
            level = 1
            proseRTF = nil
            bodyDepthOverride = nil
            noteResolution = .allDocumentNotes
        }
    }

    // MARK: - BatchContext

    /// Per-resolve immutable inputs shared by every entry in one pass: composition
    /// options, manifest lookups, pre-loaded body texts and render models, editorial-note
    /// flags, and the note pool.
    private struct BatchContext {
        /// Composition options derived from the collection (highlights, footnote style,
        /// summary prompt). Used for resolution gating only — exporters receive the export
        /// sheet's own options, which add the format-dependent word-cloud gate.
        let options: CollectionExportOptions
        /// Manifest entries keyed by volume id, for citations and volume titles.
        let manifestMap: [String: VolumeManifestEntry]
        /// Formats history.state.gov-style citations.
        let formatter: HistoryAtStateCitationFormatter
        /// Pre-loaded plain body texts keyed `"volumeId/documentId"`.
        let bodyTexts: [String: String]
        /// Pre-loaded render models keyed `"volumeId/documentId"`.
        let renderModels: [String: FRUSDocumentRenderModel]
        /// `true` per key for documents that are editorial notes (Zotero `extra` line).
        let editorialNoteFlags: [String: Bool]
        /// The collection's default body depth raw value (cascade fallback).
        let collectionDefaultBodyDepth: String
        /// All research notes, for entry note-link resolution.
        let allNotes: [ResearchNote]
    }

    /// Pre-loads everything the per-entry pipeline needs for a batch of refs: body texts
    /// (SQLite document cache first, cached-AST extraction as the XML fallback), render
    /// models (via the shared `DocumentASTCache` — see the type doc for the cache design),
    /// editorial-note flags, and the manifest map.
    ///
    /// Cooperative cancellation (v1.1): the per-document load loop — where each miss costs
    /// a SAX parse — stops early when the task is cancelled. The partially loaded context
    /// is safe (unloaded documents would merely resolve with empty bodies), and the
    /// throwing entry points surface `CancellationError` before any such result escapes.
    private func loadBatchContext(
        for refs: [EntryRef],
        collection: Collection,
        allNotes: [ResearchNote]
    ) async -> BatchContext {
        let manifest = appState.manifestStore.diffResult?.known
            ?? appState.manifestStore.bundledEntries
        let manifestMap = Dictionary(manifest.map { ($0.volumeId, $0) },
                                     uniquingKeysWith: { first, _ in first })

        var bodyTexts: [String: String] = [:]
        var renderModels: [String: FRUSDocumentRenderModel] = [:]

        let docRefs = refs.filter {
            $0.kind == .document && !$0.volumeId.isEmpty && !$0.documentId.isEmpty
        }
        for ref in docRefs {
            if Task.isCancelled { break }
            let key = "\(ref.volumeId)/\(ref.documentId)"

            // SQLite cache path (fast) for the plain body text.
            if bodyTexts[key] == nil, let pipeline = appState.indexingPipeline,
               let text = try? await pipeline.fetchDocumentBodyText(
                   volumeId: ref.volumeId, documentId: ref.documentId) {
                bodyTexts[key] = text
            }

            // One AST per document — LRU cache hit, else a single parse — feeds both the
            // structured render model and the XML body-text fallback.
            if renderModels[key] == nil,
               let ast = await cachedAST(volumeId: ref.volumeId, documentId: ref.documentId) {
                var converter = ASTToRenderNodeConverter()
                renderModels[key] = converter.convert(ast)
                if bodyTexts[key] == nil {
                    bodyTexts[key] = IndexingPipeline.extractBodyText(from: ast.nodes)
                }
            }
        }

        // Editorial-note flags from the index, so collection-level Zotero items
        // carry the same "Editorial note" extra line as document-level exports.
        let editorialNoteFlags = await ZoteroJSONExporter.editorialNoteFlags(
            volumeIds: Set(docRefs.map(\.volumeId)), pipeline: appState.indexingPipeline)

        return BatchContext(
            options: resolutionOptions(for: collection),
            manifestMap: manifestMap,
            formatter: HistoryAtStateCitationFormatter(),
            bodyTexts: bodyTexts,
            renderModels: renderModels,
            editorialNoteFlags: editorialNoteFlags,
            collectionDefaultBodyDepth: collection.defaultBodyDepth,
            allNotes: allNotes
        )
    }

    /// Returns the parsed AST for a document — shared `DocumentASTCache` hit when
    /// available, else a fresh parse that is stored back into the cache. Returns `nil`
    /// when the volume XML is unavailable (e.g. `.preview` of an un-downloaded volume)
    /// or the document cannot be parsed.
    private func cachedAST(volumeId: String, documentId: String) async -> FRUSDocumentAST? {
        if let hit = await appState.documentASTCache.ast(volumeId: volumeId, documentId: documentId) {
            return hit
        }
        guard let dm = appState.downloadManager else { return nil }
        let volumeURL = dm.volumeURL(for: volumeId)
        guard FileManager.default.fileExists(atPath: volumeURL.path) else { return nil }
        guard let ast = try? await FRUSDocumentParser().parseDocument(
            documentId: documentId, volumeURL: volumeURL) else { return nil }
        await appState.documentASTCache.store([ast], volumeId: volumeId)
        #if DEBUG
        print("[CollectionContentResolver] Parsed and cached \(volumeId)/\(documentId)")
        #endif
        return ast
    }

    /// Composition options derived from the collection's persisted settings, used to gate
    /// resolution work (highlights, source notes, summary prompt). The word-cloud flag is
    /// format-dependent and irrelevant to resolution; exporters receive the export sheet's
    /// own `CollectionExportOptions`, which applies that gate.
    private func resolutionOptions(for collection: Collection) -> CollectionExportOptions {
        CollectionExportOptions(
            tocStyle:        CollectionToCStyle(rawValue: collection.tocStyle) ?? .citation,
            footnoteStyle:   CollectionFootnoteStyle(rawValue: collection.footnoteStyle) ?? .all,
            applyHighlights: collection.applyHighlights,
            includeNotes:    collection.includeNotes,
            summaryPromptId: collection.summaryPromptId,
            includeWordCloud: collection.includeWordCloud
        )
    }

    // MARK: - Per-entry pipeline

    /// Resolves one entry into its export item — the shared per-entry body used by both
    /// the batch loop and the incremental `resolveItem` API. Heading and prose entries
    /// pass through as structural items; document entries are fully resolved (citation,
    /// body, notes, highlights, source note, Zotero item) per the Phase 3c depth cascade.
    ///
    /// - Returns: `nil` for `.unrecognized` kinds (written by a newer app version — this
    ///   build cannot render them) and for document entries with empty ids (malformed
    ///   sync payloads), both of which are skipped rather than emitted as junk items.
    private func resolveEntry(
        _ ref: EntryRef,
        sectionDepth: String?,
        batch: BatchContext
    ) async -> CollectionExportItem? {
        switch ref.kind {
        case .heading:
            return .heading(ref.text ?? "")
        case .prose:
            return .prose(ref.proseRTF ?? Data())
        case .unrecognized:
            // Written by a newer app version — this build cannot render it.
            // Skip rather than emit a junk document item (Authoring Phase 1 guard).
            return nil
        case .document:
            break
        }
        // Defensive: a document entry without ids (e.g. malformed sync payload from a
        // future build) can produce nothing useful downstream.
        guard !ref.volumeId.isEmpty, !ref.documentId.isEmpty else { return nil }

        let manifestEntry = batch.manifestMap[ref.volumeId]
        let volMeta = manifestEntry.map { FRUSVolumeMetadata($0) }
        let key = "\(ref.volumeId)/\(ref.documentId)"
        let renderModel = batch.renderModels[key]

        // Extract header and dateline from the render model when available.
        let (header, dateline) = renderModelHeadAndDateline(renderModel)

        let docNum: String? = ref.documentId.hasPrefix("d")
            ? Int(ref.documentId.dropFirst()).map { String($0) }
            : nil
        let docMeta = FRUSDocumentMetadata(
            documentId: ref.documentId, documentNumber: docNum,
            header: header, dateline: dateline)
        let citation = volMeta.map { batch.formatter.format(document: docMeta, volume: $0) }
            ?? "\(ref.volumeId)/\(ref.documentId)"
        let urlString = "https://history.state.gov/historicaldocuments/\(ref.volumeId)/\(ref.documentId)"
        let volumeTitle = manifestEntry?.title ?? ref.volumeId
        let bodyText = batch.bodyTexts[key] ?? ""

        // Resolve note texts per the entry's note-resolution mode.
        let resolvedNoteTexts: [String]
        switch ref.noteResolution {
        case .entrySelection(let selectedNoteIds, let legacyNoteId):
            // selectedNoteIds takes precedence over the legacy researchNoteId link.
            if !selectedNoteIds.isEmpty {
                resolvedNoteTexts = selectedNoteIds.compactMap { nid in
                    batch.allNotes.first { $0.id == nid }?.bodyText
                }.filter { !$0.isEmpty }
            } else if let legacyNote = legacyNoteId.flatMap({ nid in
                batch.allNotes.first { $0.id == nid }
            }) {
                resolvedNoteTexts = legacyNote.bodyText.isEmpty ? [] : [legacyNote.bodyText]
            } else {
                resolvedNoteTexts = []
            }
        case .allDocumentNotes:
            // Smart entries: every research note on the document travels, matching what
            // the pre-unification smart Zotero items carried.
            resolvedNoteTexts = batch.allNotes
                .filter { $0.documentId == ref.documentId && $0.volumeId == ref.volumeId }
                .map(\.bodyText)
                .filter { !$0.isEmpty }
        }

        // Effective body depth cascade (Phase 3c): the entry's own override, else the
        // section override (nearest preceding heading), else the collection default.
        // Drives per-document rendering and gates inline highlights.
        let effectiveDepth = CollectionBodyDepth.resolve(
            entryOverride: ref.bodyDepthOverride,
            sectionOverride: sectionDepth,
            collectionDefault: batch.collectionDefaultBodyDepth)

        // Highlights (when applyHighlights and body is full)
        let resolvedHighlights: [ExportHighlight]
        if batch.options.applyHighlights && effectiveDepth == .full {
            let allHL = (try? modelContext.fetch(FetchDescriptor<DocumentHighlight>())) ?? []
            resolvedHighlights = allHL
                .filter { $0.volumeId == ref.volumeId && $0.documentId == ref.documentId }
                .map { ExportHighlight(startOffset: $0.startOffset,
                                      endOffset:   $0.endOffset,
                                      color:       $0.color) }
        } else {
            resolvedHighlights = []
        }

        // Source note (footnoteStyle == .sourceNoteOnly)
        let resolvedSourceNote: String?
        if batch.options.footnoteStyle == .sourceNoteOnly {
            resolvedSourceNote = try? await appState.indexingPipeline?
                .fetchDocumentSourceNote(volumeId: ref.volumeId,
                                         documentId: ref.documentId)
        } else {
            resolvedSourceNote = nil
        }

        // Zotero JSON item (for ExportFormat.zoteroJSON)
        let zoteroItem: ZoteroJSONExporter.Item?
        if let volMeta {
            let year = FRUSVolumeMetadata.firstYear(in: volMeta.publicationDate).map(String.init) ?? "n.d."
            let (tags, _) = ZoteroJSONExporter.fetchTagsAndNotes(
                documentId: ref.documentId, volumeId: ref.volumeId, context: modelContext)
            zoteroItem = ZoteroJSONExporter.makeItem(
                document: docMeta,
                volume: volMeta,
                year: year,
                url: urlString,
                isEditorialNote: batch.editorialNoteFlags[key] ?? false,
                tags: tags,
                notes: resolvedNoteTexts
            )
        } else {
            zoteroItem = nil
        }

        return .document(CollectionExportDocument(
            documentId: ref.documentId,
            volumeId: ref.volumeId,
            sortOrder: ref.sortOrder,
            bodyDepth: effectiveDepth,
            title: "\(volumeTitle) — \(ref.documentId)",
            date: manifestEntry?.dateRange.earliest,
            bodyText: bodyText,
            noteTexts: resolvedNoteTexts,
            citation: citation,
            historyStateGovURL: urlString,
            renderModel: renderModel,
            header: header,
            dateline: dateline,
            highlights: resolvedHighlights,
            sourceNoteText: resolvedSourceNote,
            zoteroItem: zoteroItem
        ))
    }

    // MARK: - Volume preparation (export only)

    /// Downloads and indexes any referenced volumes that are not yet available locally,
    /// reporting live progress via `onPreparingStatus`. Called only for `.export` resolves
    /// of static collections — `.preview` must never trigger downloads.
    ///
    /// Internal and overridable so tests can observe the purpose gating without real
    /// downloads (the production seam: `appState.downloadManager` / `indexingPipeline`).
    func prepareVolumesForExport(_ neededVolumeIds: Set<String>) async {
        guard let dm = appState.downloadManager,
              let pipeline = appState.indexingPipeline else { return }

        let manifest = appState.manifestStore.diffResult?.known
            ?? appState.manifestStore.bundledEntries

        // Classify each needed volume.
        var toDownload: [(volumeId: String, downloadUrl: String)] = []
        var toIndex: [String] = []
        for vid in neededVolumeIds {
            if !dm.isVolumeDownloaded(vid) {
                if let entry = manifest.first(where: { $0.volumeId == vid }) {
                    toDownload.append((vid, entry.downloadUrl))
                }
            } else if (try? !pipeline.isVolumeIndexed(vid)) == true {
                toIndex.append(vid)
            }
        }

        guard !toDownload.isEmpty || !toIndex.isEmpty else { return }

        let totalNeeded = toDownload.count + toIndex.count
        onPreparingStatus?(String(
            localized: "export.preparing.volumes",
            defaultValue: "Preparing \(totalNeeded) volume\(totalNeeded == 1 ? "" : "s")…"
        ))

        // Kick off indexing for downloaded-but-unindexed volumes.
        for vid in toIndex {
            Task { try? await pipeline.indexVolume(vid) }
        }
        // Enqueue downloads; indexing follows automatically via onVolumeDownloaded.
        for (vid, url) in toDownload {
            await dm.enqueueDownload(volumeId: vid, downloadUrl: url)
        }

        // Poll until every needed volume is indexed (or we time out after ~5 min).
        let waitSet = Set(toDownload.map(\.volumeId) + toIndex)
        var remaining = waitSet
        var elapsedMs = 0
        let pollInterval = 1_000_000_000   // 1 second in nanoseconds
        let timeoutMs   = 300_000          // 5 minutes

        while !remaining.isEmpty && elapsedMs < timeoutMs {
            try? await Task.sleep(nanoseconds: UInt64(pollInterval))
            elapsedMs += 1_000
            remaining = remaining.filter { vid in
                (try? !pipeline.isVolumeIndexed(vid)) != false
            }
            let ready = waitSet.count - remaining.count
            let total = waitSet.count
            onPreparingStatus?(String(
                localized: "export.preparing.progress",
                defaultValue: "Preparing volumes: \(ready) of \(total) ready…"
            ))
        }

        onPreparingStatus?(nil)
    }

    // MARK: - Summary phase

    /// Applies the summary phase to resolved items: for every document whose effective
    /// body depth is `.summaryOnly`, attaches summary text per the purpose — `.export`
    /// generates on demand (pre-extraction behavior, error-for-error), `.preview` attaches
    /// stored summaries only and leaves the rest `nil` for placeholder rendering.
    private func applySummaryPhase(
        to items: [CollectionExportItem],
        collection: Collection,
        purpose: ResolvePurpose
    ) async throws -> [CollectionExportItem] {
        let summaryDocs = items.documents.filter { $0.bodyDepth == .summaryOnly }
        guard !summaryDocs.isEmpty else { return items }

        let summaries: [String: String]
        switch purpose {
        case .export:
            guard let promptId = collection.summaryPromptId else {
                throw CollectionResolveError.summaryPromptMissing
            }
            // uniquingKeysWith: the same document may legitimately appear in a collection
            // more than once; the duplicate pairs are identical, so keep the first.
            let bodyTexts = Dictionary(
                summaryDocs.map { ("\($0.volumeId)/\($0.documentId)", $0.bodyText) },
                uniquingKeysWith: { first, _ in first })
            summaries = try await resolveSummaries(for: summaryDocs, promptId: promptId,
                                                   bodyTexts: bodyTexts)
        case .preview:
            // Never generate: attach stored summaries where they exist; a summary-depth
            // document without one keeps a nil summary (the preview renders a placeholder).
            guard let promptId = collection.summaryPromptId else { return items }
            var stored: [String: String] = [:]
            for doc in summaryDocs {
                let key = "\(doc.volumeId)/\(doc.documentId)"
                if stored[key] == nil,
                   let text = storedSummary(volumeId: doc.volumeId, documentId: doc.documentId,
                                            promptId: promptId) {
                    stored[key] = text
                }
            }
            summaries = stored
        }

        return items.map { item in
            guard case .document(let doc) = item, doc.bodyDepth == .summaryOnly,
                  let text = summaries["\(doc.volumeId)/\(doc.documentId)"] else { return item }
            return .document(doc.withSummary(text))
        }
    }

    /// Returns the stored `GeneratedSummary` text for a document under `promptId`, or
    /// `nil` when none exists (or it is empty). Never generates.
    private func storedSummary(volumeId: String, documentId: String, promptId: UUID) -> String? {
        // Capture scalars — #Predicate can't use struct fields.
        let vid = volumeId
        let did = documentId
        let pid = promptId
        let descriptor = FetchDescriptor<GeneratedSummary>(
            predicate: #Predicate<GeneratedSummary> { s in
                s.volumeId == vid && s.documentId == did && s.promptId == pid
            }
        )
        guard let existing = try? modelContext.fetch(descriptor).first,
              !existing.responseText.isEmpty else { return nil }
        return existing.responseText
    }

    /// Generates or fetches summaries for all entries when bodyDepth == .summaryOnly.
    /// Returns a [key: summaryText] map. Throws if any generation fails. Export only —
    /// `.preview` uses `storedSummary` and never reaches this path.
    private func resolveSummaries(
        for docs: [CollectionExportDocument],
        promptId: UUID,
        bodyTexts: [String: String]
    ) async throws -> [String: String] {
        guard AppleIntelligenceProvider.shared.isAvailable else {
            throw ExportError.renderingFailed
        }
        guard let service = appState.summarizationService else {
            throw ExportError.renderingFailed
        }
        guard let prompt = (try? modelContext.fetch(
            FetchDescriptor<SummarizationPrompt>(
                predicate: #Predicate { $0.id == promptId }
            )))?.first else {
            throw ExportError.renderingFailed
        }
        let snapshot = SummarizationPromptSnapshot(from: prompt)

        var result: [String: String] = [:]
        let total = docs.count

        for (i, doc) in docs.enumerated() {
            let key = "\(doc.volumeId)/\(doc.documentId)"
            onSummaryStatus?(String(
                localized: "export.summaryProgress",
                defaultValue: "Generating summaries (\(i + 1) of \(total))…"))

            // Check for existing summary first.
            if let existing = storedSummary(volumeId: doc.volumeId, documentId: doc.documentId,
                                            promptId: promptId) {
                result[key] = existing
                continue
            }

            // Generate on demand.
            let text = bodyTexts[key] ?? doc.bodyText
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ExportError.renderingFailed
            }
            let generated = try await service.summarize(
                documentId:    doc.documentId,
                volumeId:      doc.volumeId,
                documentText:  text,
                prompt:        snapshot,
                provider:      AppleIntelligenceProvider.shared,
                activeProjectId: appState.activeProjectId
            )
            result[key] = generated.responseText
        }
        onSummaryStatus?(nil)
        return result
    }

    // MARK: - Render Model Extraction Helpers

    /// Extracts the first heading and first dateline from a render model's body nodes.
    private func renderModelHeadAndDateline(_ model: FRUSDocumentRenderModel?) -> (header: String, dateline: String?) {
        guard let model else { return ("", nil) }
        var header = ""
        var dateline: String? = nil
        for node in model.bodyNodes {
            if case .heading(let c) = node, header.isEmpty {
                header = renderNodePlainText(c).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if case .dateline(let c) = node, dateline == nil {
                let text = renderNodePlainText(c).trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { dateline = text }
            }
            if !header.isEmpty && dateline != nil { break }
        }
        return (header, dateline)
    }

    /// Recursively extracts plain text from an array of `FRUSRenderNode` values.
    private func renderNodePlainText(_ nodes: [FRUSRenderNode]) -> String {
        nodes.map { renderNodePlainText($0) }.joined()
    }

    /// Recursively extracts plain text from a single `FRUSRenderNode`.
    private func renderNodePlainText(_ node: FRUSRenderNode) -> String {
        switch node {
        case .plainText(let s):
            return s
        case .boldText(let c), .italicText(let c), .smallCapsText(let c),
             .underlineText(let c), .termText(let c), .corrText(let c),
             .suppliedText(let c), .sicText(let c):
            return renderNodePlainText(c)
        case .heading(let c), .dateline(let c), .salutation(let c),
             .paragraph(let c), .attachmentHeading(let c):
            return renderNodePlainText(c)
        case .letterOpener(let c), .letterCloser(let c),
             .editorialNoteBlock(let c), .titlePageBlock(let c):
            return renderNodePlainText(c)
        case .attachmentBlock(_, let c), .unknown(_, let c):
            return renderNodePlainText(c)
        case .persNameLink(_, let c, _), .glossLink(_, let c, _),
             .crossRefLink(_, _, let c):
            return renderNodePlainText(c)
        case .formulaText(let s):
            return s
        case .lineBreak:
            return " "
        case .footnoteMarker(_, let label):
            return "[\(label)]"
        case .listBlock(_, let items):
            return items.map { renderNodePlainText($0) }.joined(separator: " ")
        case .tableBlock(let rows):
            return rows.map { row in row.map { renderNodePlainText($0.children) }.joined(separator: " | ") }.joined(separator: "\n")
        case .footnoteBody, .pageBreak, .figureBlock:
            return ""
        }
    }
}
