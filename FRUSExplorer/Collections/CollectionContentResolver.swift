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
            return String(localized: "export.smart.noSearchService.v2",
                          defaultValue: "Search is not ready yet. Try again in a moment.")
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
/// `effectiveIncludeSourceNote`, and the collection's default body depth (including
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
///   1.3 — Authoring Phase 4 (exporter frame): `.heading` items carry their
///          `CollectionOutline`-resolved level; a set collection introduction is emitted
///          as the leading `.prose` item by the two full-resolve entry points (reusing
///          the shared RTF prose path, so formatting survives every format and the
///          preview for free — an unset introduction adds nothing, keeping no-frame
///          collections byte-identical)
///   1.4 — Authoring Phase 5 (footnote pair + headnotes): the source note now resolves
///          whenever `effectiveIncludeSourceNote` (previously gated on the legacy
///          `footnoteStyle == .sourceNoteOnly` — the nil-pair derivation reproduces that
///          behavior exactly); document entries with `includeHeadnote` attach a stored
///          `GeneratedSummary` as `headnoteText` (the chosen `headnoteSummaryId`, else
///          the collection's prompt's summary, else any stored one). Headnote resolution
///          **never generates** — in either purpose — so a missing stored summary renders
///          a placeholder note (generation-on-demand stays exclusive to `.summaryOnly`
///          bodies, exactly as today; headnote generation-on-demand is out of scope)
///   1.5 — Authoring Phase 5 (excerpts): `.excerpt` entries resolve to
///          `CollectionExportItem.excerpt` — the frozen passage plus a citation built
///          through the same manifest + `HistoryAtStateCitationFormatter` path document
///          items use (no volume XML needed, so excerpts render fully even when the
///          source volume isn't downloaded). Per A9 the stored offsets/renderingVersion
///          are NOT read here — the frozen `text` is the rendering source of truth
///   1.6 — Authoring Phase 5 (overrides + related documents): the per-entry overrides
///          resolve HERE and only here — entry override → nearest ancestor heading's
///          (via `CollectionOutline.sectionOverrideValues`, the generic cascade) →
///          collection default. Highlights honor `selectedHighlightIds` (A8: empty =
///          all); the source-note fetch gates on the cascaded flag; footnote/notes/
///          highlight decisions travel to renderers as resolved payload overrides
///          (`doc.x ?? options.x`); the summary phase groups by each document's
///          effective prompt. `includeRelatedDocuments` (A10) computes the "See also:"
///          line from outbound `cross_references` edges whose targets are also in the
///          collection (in collection order, deduped, self excluded). Smart-collection
///          entries are synthesized with no overrides, so smart behavior is unchanged
///   1.7 — Authoring Phase 5 review fixes: static resolves compute the A10 membership
///          from the owning collection's full entry list (`collectionDocumentRefs`),
///          not the passed entries — the capped preview passes a prefix, which silently
///          dropped "See also:" targets past the cap that the export showed
///   1.8 — Authoring Phase 6 (generated apparatus): `.generated` entries resolve to
///          `CollectionExportItem.generated` via the `CollectionGeneratedBlocks` seam,
///          computed from the batch's `collectionDocuments` (the same resolved
///          membership the A10 line uses — the full static collection, or the smart
///          result set). Block resolution is read-only and purpose-independent, so
///          `.preview` and `.export` render identical blocks. An entry whose
///          `generatedBlockType` this build doesn't know resolves to `nil` (skipped —
///          degraded, never corrupted), mirroring the `.unrecognized` kind guard
///   1.9 — Authoring Phase 6 (blocks): `LiveGeneratedBlockDataSource` feeds the real
///          block resolvers — citations via the document items' own manifest/formatter
///          path, `document_dates` metadata, `document_sources` + the bundled NARA
///          resolution index, the People-browser rollup, and the notes/assignments tag
///          union. All read-only; every accessor degrades to empty (→ the blocks'
///          "nothing to list" row) when its backing service is unavailable
///   1.10 — Authoring Phase 6 review fixes: the smart path now resolves the collection's
///          `.generated` entries too — front-matter blocks before the smart items,
///          back-matter blocks after (per `defaultPosition`; smart documents come from
///          the search, so authored positions between them don't exist), fed the smart
///          result set as membership. `resolve(smartRefs:…)` gains `fullRefs` so the
///          capped preview computes blocks (and the A10 membership) from the FULL
///          result set, matching what the export shows. `fullCitation` deleted: the
///          history.state.gov formatter never reads header/dateline, so it was provably
///          byte-identical to `shortCitation` while paying a render-model walk per row
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
        let framed = introductionItems(for: collection) + items
        return try await applySummaryPhase(to: framed, collection: collection, purpose: purpose)
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
    ///   - fullRefs: The *uncapped* result set, when `refs` is a capped prefix of it
    ///     (v1.10). Membership-wide computations — generated apparatus blocks and the
    ///     A10 related-documents universe — use this list, so a capped preview's blocks
    ///     match the export's. `nil` (default) means `refs` IS the full result set.
    /// - Returns: Ordered export items for exactly the given refs (plus the collection's
    ///   generated apparatus blocks — see `resolveSmartItems`).
    /// - Throws: `CancellationError` when the surrounding task was cancelled mid-resolve;
    ///   summary-phase errors for `.export` (see `applySummaryPhase`).
    func resolve(
        smartRefs refs: [SmartDocumentRef],
        collection: Collection,
        allNotes: [ResearchNote],
        purpose: ResolvePurpose,
        fullRefs: [SmartDocumentRef]? = nil
    ) async throws -> [CollectionExportItem] {
        let items = await resolveSmartItems(refs, collection: collection, allNotes: allNotes,
                                            fullRefs: fullRefs)
        try Task.checkCancellation()
        let framed = introductionItems(for: collection) + items
        return try await applySummaryPhase(to: framed, collection: collection, purpose: purpose)
    }

    /// The collection's front-matter items (Authoring Phase 4): the introduction as a
    /// leading `.prose` item when set, else nothing. Reuses the entry-prose RTF path
    /// (`ProseRichText`/`CollectionProse`), so introduction formatting survives HTML,
    /// PDF, DOCX, and the live preview through the exact same code every prose block
    /// takes. Title page and colophon are metadata-driven instead (see
    /// `CollectionExportMetadata`), keeping the item stream pure content.
    ///
    /// - Parameter collection: The collection whose introduction to snapshot.
    /// - Returns: `[.prose(introductionRTF)]`, or `[]` when no introduction is set —
    ///   so a collection without one resolves to exactly the pre-Phase-4 item list.
    private func introductionItems(for collection: Collection) -> [CollectionExportItem] {
        guard let rtf = ProseRichText.exportRTF(richText: collection.introductionRichText,
                                                plainText: collection.introductionText) else {
            return []
        }
        return [.prose(rtf)]
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
    ///     The Phase 5 section-level override defaults are likewise whole-list context a
    ///     single-entry resolve cannot have: they resolve as unset here (entry override →
    ///     collection default), exactly the body-depth limitation this parameter documents.
    ///   - headingLevel: The entry's outline-resolved heading level, when the caller has
    ///     run `CollectionOutline` over the full list. `nil` (default) clamps the entry's
    ///     raw level to `1...maxLevel` — correct except for orphan-jump correction, which
    ///     needs whole-list context a single-entry resolve cannot have.
    /// - Returns: The resolved item, or `nil` for `.unrecognized` kinds and malformed
    ///   document entries (empty ids), which a full resolve would also skip.
    func resolveItem(
        _ entry: CollectionEntry,
        collection: Collection,
        allNotes: [ResearchNote],
        sectionBodyDepth: String? = nil,
        headingLevel: Int? = nil
    ) async -> CollectionExportItem? {
        let ref = EntryRef(entry)
        let level = headingLevel ?? min(max(ref.level, 1), CollectionOutline.maxLevel)
        // Related-documents membership (A10) comes from the owning collection's entry
        // list, so a single-entry resolve matches what a full resolve would compute.
        let batch = await loadBatchContext(
            for: [ref], collection: collection, allNotes: allNotes,
            collectionDocuments: Self.collectionDocumentRefs(of: collection))
        guard let item = await resolveEntry(ref,
                                            section: SectionOverrides(bodyDepth: sectionBodyDepth),
                                            headingLevel: level, batch: batch) else {
            return nil
        }
        // Attach a stored summary when available; never generate (preview semantics).
        // The entry's effective prompt (override, else the collection's) picks it.
        if case .document(let doc) = item, doc.bodyDepth == .summaryOnly,
           let promptId = doc.summaryPromptIdOverride ?? collection.summaryPromptId,
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
            // Document entries only: excerpts carry a real volumeId as provenance but
            // render from their frozen text (A9), so they never require the volume.
            await prepareVolumesForExport(Set(
                entries.filter { $0.entryKind == .document }.map(\.volumeId)))
        }

        let refs = entries.map(EntryRef.init)
        // Related-documents membership (A10) comes from the owning collection's full
        // entry list, NOT the passed entries — the preview passes a capped prefix, and
        // computing the universe from it would silently drop "See also:" targets past
        // the cap that the export (full list) shows. Matches `resolveItem`'s sourcing.
        let batch = await loadBatchContext(
            for: refs, collection: collection, allNotes: allNotes,
            collectionDocuments: Self.collectionDocumentRefs(of: collection))
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
    /// Generated apparatus blocks (v1.10): the collection's static `.generated` entries
    /// resolve here too, fed the smart result set as their membership — front-matter
    /// blocks (per `CollectionGeneratedBlockType.defaultPosition`) before the smart
    /// items, back-matter blocks after, each group in `sortOrder` order. Smart documents
    /// come from the saved search, so a hand-authored position *between* them cannot
    /// exist; the default position is the only meaningful placement.
    ///
    /// Internal (not private) so tests can exercise the unified pipeline without standing
    /// up a live FTS5 search service.
    ///
    /// - Parameter fullRefs: The uncapped result set when `refs` is a capped prefix
    ///   (see `resolve(smartRefs:…)`); `nil` means `refs` is the full set.
    func resolveSmartItems(
        _ refs: [SmartDocumentRef],
        collection: Collection,
        allNotes: [ResearchNote],
        fullRefs: [SmartDocumentRef]? = nil
    ) async -> [CollectionExportItem] {
        let entryRefs = refs.map(EntryRef.init)
        // Membership-wide computations (generated blocks, A10 universe) see the FULL
        // result set even when per-document resolution was capped by the preview.
        let membership = Self.documentRefs(in: (fullRefs ?? refs).map(EntryRef.init))
        let batch = await loadBatchContext(
            for: entryRefs, collection: collection, allNotes: allNotes,
            collectionDocuments: membership)
        let items = await resolveItems(from: entryRefs, batch: batch)
        let (front, back) = await generatedItems(for: collection, batch: batch)
        return front + items + back
    }

    /// Resolves the collection's `.generated` entries for the smart path (v1.10),
    /// partitioned by their type's `defaultPosition` — `(front matter, back matter)`,
    /// each in `sortOrder` order. Unknown block types are skipped (the same
    /// newer-version guard as `resolveEntry`); a cancelled task returns the blocks
    /// resolved so far (partial-safe, matching the per-entry loops).
    private func generatedItems(
        for collection: Collection,
        batch: BatchContext
    ) async -> (front: [CollectionExportItem], back: [CollectionExportItem]) {
        var front: [CollectionExportItem] = []
        var back: [CollectionExportItem] = []
        let generatedEntries = (collection.documentEntries ?? [])
            .filter { $0.entryKind == .generated }
            .sorted { $0.sortOrder < $1.sortOrder }
        for entry in generatedEntries {
            if Task.isCancelled { break }
            guard let raw = entry.generatedBlockType,
                  let blockType = CollectionGeneratedBlockType(rawValue: raw) else { continue }
            let block = await CollectionGeneratedBlocks.resolve(
                type: blockType, documents: batch.collectionDocuments,
                dataSource: LiveGeneratedBlockDataSource(resolver: self, batch: batch))
            switch blockType.defaultPosition {
            case .frontMatter: front.append(.generated(block))
            case .backMatter:  back.append(.generated(block))
            }
        }
        return (front, back)
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
        // Single-linearizer discipline: the ancestor cascade AND the emitted heading
        // levels are computed by CollectionOutline, never re-derived here — so items
        // always carry clamped, orphan-corrected depths, whatever the synced raw levels.
        let structuralRefs = ordered.map {
            CollectionOutline.StructuralRef(isHeading: $0.kind == .heading,
                                            level: $0.level,
                                            bodyDepthOverride: $0.bodyDepthOverride)
        }
        let sectionDepths = CollectionOutline.sectionBodyDepthOverrides(structuralRefs)
        let resolvedLevels = CollectionOutline.resolvedDepths(structuralRefs)
        // Phase 5 override cascades: one generic outline walk per field, heading values
        // only (a document's own override never leaks into the section defaults).
        func headingValues<Value>(_ value: (EntryRef) -> Value?) -> [Value?] {
            ordered.map { $0.kind == .heading ? value($0) : nil }
        }
        let secHighlights = CollectionOutline.sectionOverrideValues(
            structuralRefs, headingValues: headingValues { $0.applyHighlightsOverride })
        let secNotes = CollectionOutline.sectionOverrideValues(
            structuralRefs, headingValues: headingValues { $0.includeNotesOverride })
        let secSourceNote = CollectionOutline.sectionOverrideValues(
            structuralRefs, headingValues: headingValues { $0.includeSourceNoteOverride })
        let secFootnotes = CollectionOutline.sectionOverrideValues(
            structuralRefs, headingValues: headingValues { $0.includeFootnotesOverride })
        let secPrompt = CollectionOutline.sectionOverrideValues(
            structuralRefs, headingValues: headingValues { $0.summaryPromptIdOverride })
        let secRelated = CollectionOutline.sectionOverrideValues(
            structuralRefs, headingValues: headingValues { $0.includeRelatedDocuments })
        var items: [CollectionExportItem] = []
        for (i, ref) in ordered.enumerated() {
            if Task.isCancelled { break }
            let section = SectionOverrides(
                bodyDepth: sectionDepths[i],
                applyHighlights: secHighlights[i],
                includeNotes: secNotes[i],
                includeSourceNote: secSourceNote[i],
                includeFootnotes: secFootnotes[i],
                summaryPromptId: secPrompt[i],
                includeRelatedDocuments: secRelated[i])
            if let item = await resolveEntry(ref, section: section,
                                             headingLevel: max(resolvedLevels[i], 1),
                                             batch: batch) {
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
        /// The entry's per-document title override (M3, D4; document entries only; `nil`
        /// on smart refs). Drives both the ToC label and the export heading.
        let titleOverride: String?
        /// Per-entry headnote opt-in (`nil` = Default = inherit the collection default). Resolved
        /// against `CollectionExportOptions.includeHeadnoteDefault` at pack time (Composer redesign).
        let includeHeadnote: Bool?
        /// The chosen `GeneratedSummary.id` for the headnote; `nil` = fallback pick.
        let headnoteSummaryId: UUID?
        /// The source highlight's colour raw value (`.excerpt` entries only, Phase 5).
        let excerptColorTag: String?
        /// The apparatus block type raw value (`.generated` entries only, Phase 6).
        let generatedBlockType: String?
        /// Per-entry highlight override (Phase 5; `nil` = inherit; section default on
        /// headings). See `CollectionEntry.applyHighlightsOverride`.
        let applyHighlightsOverride: Bool?
        /// Per-entry research-notes override (Phase 5; `nil` = inherit).
        let includeNotesOverride: Bool?
        /// Per-entry source-note override (Phase 5; `nil` = inherit).
        let includeSourceNoteOverride: Bool?
        /// Per-entry footnote override (Phase 5; `nil` = inherit).
        let includeFootnotesOverride: Bool?
        /// Per-entry summary-prompt override (Phase 5; `nil` = inherit).
        let summaryPromptIdOverride: UUID?
        /// The highlights to include when highlights apply (A8; empty = all).
        let selectedHighlightIds: [UUID]
        /// Per-entry related-documents opt-in (A10; `nil` = inherit, ultimately off).
        let includeRelatedDocuments: Bool?
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
            titleOverride = entry.titleOverride
            includeHeadnote = entry.includeHeadnote
            headnoteSummaryId = entry.headnoteSummaryId
            excerptColorTag = entry.entryKind == .excerpt ? entry.excerptColorTag : nil
            generatedBlockType = entry.entryKind == .generated ? entry.generatedBlockType : nil
            applyHighlightsOverride = entry.applyHighlightsOverride
            includeNotesOverride = entry.includeNotesOverride
            includeSourceNoteOverride = entry.includeSourceNoteOverride
            includeFootnotesOverride = entry.includeFootnotesOverride
            summaryPromptIdOverride = entry.summaryPromptIdOverride
            selectedHighlightIds = entry.selectedHighlightIds
            includeRelatedDocuments = entry.includeRelatedDocuments
            noteResolution = .entrySelection(selectedNoteIds: entry.selectedNoteIds,
                                             legacyNoteId: entry.researchNoteId)
        }

        /// Synthesizes an entry for one smart-collection search result: always a
        /// `.document`, with no overrides and all-document note resolution — smart
        /// collections keep collection-level behavior by construction.
        init(_ ref: SmartDocumentRef) {
            kind = .document
            documentId = ref.documentId
            volumeId = ref.volumeId
            sortOrder = ref.sortOrder
            text = nil
            level = 1
            proseRTF = nil
            bodyDepthOverride = nil
            titleOverride = nil
            includeHeadnote = nil
            headnoteSummaryId = nil
            excerptColorTag = nil
            generatedBlockType = nil
            applyHighlightsOverride = nil
            includeNotesOverride = nil
            includeSourceNoteOverride = nil
            includeFootnotesOverride = nil
            summaryPromptIdOverride = nil
            selectedHighlightIds = []
            includeRelatedDocuments = nil
            noteResolution = .allDocumentNotes
        }
    }

    // MARK: - SectionOverrides

    /// The section-level defaults in effect at one position — each field the value of
    /// the nearest ancestor heading that sets it (`CollectionOutline`'s generic
    /// ancestor cascade, one walk per field), `nil` when no ancestor does. The per-entry
    /// resolution rule everywhere is `entry override ?? section value ?? collection
    /// default` — computed only in this resolver (Authoring Phase 5).
    private struct SectionOverrides {
        /// Section body depth (the Phase 3c/4 cascade, unchanged).
        var bodyDepth: String? = nil
        /// Section highlight default (Phase 5).
        var applyHighlights: Bool? = nil
        /// Section research-notes default (Phase 5).
        var includeNotes: Bool? = nil
        /// Section source-note default (Phase 5).
        var includeSourceNote: Bool? = nil
        /// Section footnote default (Phase 5).
        var includeFootnotes: Bool? = nil
        /// Section summary-prompt default (Phase 5).
        var summaryPromptId: UUID? = nil
        /// Section related-documents default (A10, Phase 5).
        var includeRelatedDocuments: Bool? = nil
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
        /// The collection's document membership — `(volumeId, documentId)` in collection
        /// order, deduplicated — the A10 universe for the related-documents line (only
        /// cross-reference targets in this list ever appear on it).
        let collectionDocuments: [(volumeId: String, documentId: String)]
    }

    /// The ordered, deduplicated `(volumeId, documentId)` list of a batch's document
    /// entries — the related-documents membership for smart resolves, where the passed
    /// refs ARE the true membership. Static resolves use `collectionDocumentRefs(of:)`
    /// instead: their refs may be a capped preview prefix of the real membership.
    private static func documentRefs(in refs: [EntryRef]) -> [(volumeId: String, documentId: String)] {
        var seen = Set<String>()
        return refs.sorted { $0.sortOrder < $1.sortOrder }
            .filter { $0.kind == .document && !$0.volumeId.isEmpty && !$0.documentId.isEmpty }
            .compactMap { ref in
                seen.insert("\(ref.volumeId)/\(ref.documentId)").inserted
                    ? (ref.volumeId, ref.documentId) : nil
            }
    }

    /// The ordered, deduplicated document membership of a live collection — the
    /// related-documents membership for static resolves (full, capped-preview, and
    /// single-entry `resolveItem`), so every static pass agrees on the A10 universe
    /// regardless of how its entry list was capped.
    private static func collectionDocumentRefs(of collection: Collection) -> [(volumeId: String, documentId: String)] {
        var seen = Set<String>()
        return (collection.documentEntries ?? [])
            .sorted { $0.sortOrder < $1.sortOrder }
            .filter { $0.entryKind == .document && !$0.volumeId.isEmpty && !$0.documentId.isEmpty }
            .compactMap { entry in
                seen.insert("\(entry.volumeId)/\(entry.documentId)").inserted
                    ? (entry.volumeId, entry.documentId) : nil
            }
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
        allNotes: [ResearchNote],
        collectionDocuments: [(volumeId: String, documentId: String)]
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
            allNotes: allNotes,
            collectionDocuments: collectionDocuments
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
    ///
    /// Internal (not private) so tests can assert the legacy `footnoteStyle` → Bool-pair
    /// mapping end-to-end without standing up a full resolve.
    func resolutionOptions(for collection: Collection) -> CollectionExportOptions {
        CollectionExportOptions(
            tocStyle:          CollectionToCStyle(rawValue: collection.tocStyle) ?? .citation,
            includeFootnotes:  collection.effectiveIncludeFootnotes,
            includeSourceNote: collection.effectiveIncludeSourceNote,
            applyHighlights:   collection.applyHighlights,
            includeNotes:      collection.includeNotes,
            summaryPromptId:   collection.summaryPromptId,
            includeWordCloud:  collection.includeWordCloud,
            includeHeadnoteDefault: collection.defaultIncludeHeadnote
        )
    }

    // MARK: - Per-entry pipeline

    /// Resolves one entry into its export item — the shared per-entry body used by both
    /// the batch loop and the incremental `resolveItem` API. Heading and prose entries
    /// pass through as structural items; document entries are fully resolved (citation,
    /// body, notes, highlights, source note, related documents, Zotero item) per the
    /// override cascade: entry override → `section` value → collection default.
    ///
    /// - Parameters:
    ///   - section: The section-level defaults in effect at this position (the outline
    ///     ancestor cascade's output — see `SectionOverrides`).
    ///   - headingLevel: The outline-resolved level emitted on `.heading` items
    ///     (already clamped/orphan-corrected by the caller via `CollectionOutline`).
    /// - Returns: `nil` for `.unrecognized` kinds (written by a newer app version — this
    ///   build cannot render them), for `.generated` entries whose block type this build
    ///   doesn't know (same newer-version guard), and for document entries with empty
    ///   ids (malformed sync payloads) — all skipped rather than emitted as junk items.
    private func resolveEntry(
        _ ref: EntryRef,
        section: SectionOverrides,
        headingLevel: Int,
        batch: BatchContext
    ) async -> CollectionExportItem? {
        switch ref.kind {
        case .heading:
            return .heading(ref.text ?? "", level: headingLevel)
        case .prose:
            return .prose(ref.proseRTF ?? Data())
        case .excerpt:
            return excerptItem(for: ref, batch: batch)
        case .generated:
            // Generated apparatus (Phase 6): resolve the block from the collection's
            // resolved document membership via the single block-resolution seam,
            // fed by the live data source (index, rollup, NARA index, SwiftData).
            // Read-only in both purposes — preview and export render identical blocks.
            // An unknown block type (a newer build's vocabulary) is skipped, mirroring
            // the `.unrecognized` kind guard: degraded, never corrupted.
            guard let raw = ref.generatedBlockType,
                  let blockType = CollectionGeneratedBlockType(rawValue: raw) else { return nil }
            return await .generated(CollectionGeneratedBlocks.resolve(
                type: blockType, documents: batch.collectionDocuments,
                dataSource: LiveGeneratedBlockDataSource(resolver: self, batch: batch)))
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
                // Un-migrated legacy single-note link: honored only while no multi-note
                // selection exists (write paths migrate legacy → array on first edit).
                resolvedNoteTexts = legacyNote.bodyText.isEmpty ? [] : [legacyNote.bodyText]
            } else {
                // D5: an empty selection with no legacy link means **all** of the
                // document's notes (mirroring `selectedHighlightIds` and `.allDocumentNotes`),
                // so future notes auto-flow in and enabling notes on an untouched entry
                // actually exports them. Populated only on the first inspector deselect.
                resolvedNoteTexts = batch.allNotes
                    .filter { $0.documentId == ref.documentId && $0.volumeId == ref.volumeId }
                    .map(\.bodyText)
                    .filter { !$0.isEmpty }
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
        // section override (nearest ancestor heading), else the collection default.
        // Drives per-document rendering and gates inline highlights.
        let effectiveDepth = CollectionBodyDepth.resolve(
            entryOverride: ref.bodyDepthOverride,
            sectionOverride: section.bodyDepth,
            collectionDefault: batch.collectionDefaultBodyDepth)

        // Phase 5 cascaded overrides: entry ?? section (nil = inherit the collection
        // default, which renderers read from `options`). The entry-or-section value —
        // not the fully-collapsed Bool — travels on the payload so renderers apply
        // `doc.x ?? options.x` and untouched documents keep collection behavior.
        let highlightsOverride = ref.applyHighlightsOverride ?? section.applyHighlights
        let notesOverride = ref.includeNotesOverride ?? section.includeNotes
        let sourceNoteOverride = ref.includeSourceNoteOverride ?? section.includeSourceNote
        let footnotesOverride = ref.includeFootnotesOverride ?? section.includeFootnotes
        let promptOverride = ref.summaryPromptIdOverride ?? section.summaryPromptId

        // Highlights (when highlights apply here and body is full). The entry's
        // selectedHighlightIds filter the set (A8): empty means all.
        let resolvedHighlights: [ExportHighlight]
        if (highlightsOverride ?? batch.options.applyHighlights) && effectiveDepth == .full {
            let allHL = (try? modelContext.fetch(FetchDescriptor<DocumentHighlight>())) ?? []
            resolvedHighlights = allHL
                .filter { $0.volumeId == ref.volumeId && $0.documentId == ref.documentId }
                .filter { ref.selectedHighlightIds.isEmpty
                    || ref.selectedHighlightIds.contains($0.id) }
                .map { ExportHighlight(startOffset: $0.startOffset,
                                      endOffset:   $0.endOffset,
                                      color:       $0.color) }
        } else {
            resolvedHighlights = []
        }

        // Source note — resolved whenever the cascaded include-source-note flag is on
        // (Authoring Phase 5; the collection default previously gated on the legacy
        // tri-state's `.sourceNoteOnly`, which the nil-pair derivation reproduces).
        let resolvedSourceNote: String?
        if sourceNoteOverride ?? batch.options.includeSourceNote {
            resolvedSourceNote = try? await appState.indexingPipeline?
                .fetchDocumentSourceNote(volumeId: ref.volumeId,
                                         documentId: ref.documentId)
        } else {
            resolvedSourceNote = nil
        }

        // Headnote (Authoring Phase 5): a stored GeneratedSummary rendered above the
        // body. Stored summaries only — never generated, in either purpose; renderers
        // show a placeholder when the entry asked for one and none is stored. The
        // fallback pick prefers the entry's effective prompt.
        // Headnote resolves through the two-tier cascade (Composer redesign): the entry's own
        // opt-in, else the collection default. Headings do not carry a headnote section default.
        let effectiveHeadnote = ref.includeHeadnote ?? batch.options.includeHeadnoteDefault
        let resolvedHeadnotePair = effectiveHeadnote
            ? headnoteText(volumeId: ref.volumeId, documentId: ref.documentId,
                           summaryId: ref.headnoteSummaryId,
                           preferredPromptId: promptOverride ?? batch.options.summaryPromptId)
            : nil
        let resolvedHeadnote = resolvedHeadnotePair?.text
        // The headnote's provenance drives its export attribution (a user-edited/-written headnote
        // is not labeled AI). Absent a stored summary, .aiGenerated is inert (no attribution shows).
        let resolvedHeadnoteAuthorship = resolvedHeadnotePair?.authorship ?? .aiGenerated

        // Related documents (A10): outbound cross-reference targets that are also in
        // this collection, rendered as a "See also:" citation line. Off unless the
        // cascade turns it on; empty when the store is unavailable (e.g. tests).
        let relatedCitations: [String]
        if ref.includeRelatedDocuments ?? section.includeRelatedDocuments ?? false,
           let store = appState.crossReferenceStore {
            let edges = (try? await store.outboundEdges(
                forDocumentId: ref.documentId, volumeId: ref.volumeId)) ?? []
            let targets = Self.relatedDocumentTargets(
                outboundTargets: edges.map { (volumeId: $0.targetVolumeId,
                                              documentId: $0.targetDocumentId) },
                selfVolumeId: ref.volumeId, selfDocumentId: ref.documentId,
                collectionDocuments: batch.collectionDocuments)
            relatedCitations = targets.map {
                shortCitation(volumeId: $0.volumeId, documentId: $0.documentId, batch: batch)
            }
        } else {
            relatedCitations = []
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
            titleOverride: ref.titleOverride,
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
            includeHeadnote: effectiveHeadnote,
            headnoteText: resolvedHeadnote,
            headnoteAuthorship: resolvedHeadnoteAuthorship,
            applyHighlightsOverride: highlightsOverride,
            includeNotesOverride: notesOverride,
            includeFootnotesOverride: footnotesOverride,
            summaryPromptIdOverride: promptOverride,
            relatedDocumentCitations: relatedCitations,
            zoteroItem: zoteroItem
        ))
    }

    // MARK: - Related documents (A10)

    /// The A10 pure core, internal for tests: of a document's outbound cross-reference
    /// targets, keep only those **also in the collection**, returned in collection
    /// order, deduplicated, with the document itself excluded. `collectionDocuments`
    /// (ordered, deduped) is the single membership universe, so the line is bounded by
    /// the artifact's own contents — never the full cross-reference fan-out.
    ///
    /// - Parameters:
    ///   - outboundTargets: The targets of the document's outbound edges (any order,
    ///     duplicates allowed).
    ///   - selfVolumeId: The referencing document's volume id (self-references dropped).
    ///   - selfDocumentId: The referencing document's document id.
    ///   - collectionDocuments: The collection's document membership in collection order.
    /// - Returns: The in-collection targets, in collection order.
    nonisolated static func relatedDocumentTargets(
        outboundTargets: [(volumeId: String, documentId: String)],
        selfVolumeId: String,
        selfDocumentId: String,
        collectionDocuments: [(volumeId: String, documentId: String)]
    ) -> [(volumeId: String, documentId: String)] {
        let selfKey = "\(selfVolumeId)/\(selfDocumentId)"
        let targetKeys = Set(outboundTargets.map { "\($0.volumeId)/\($0.documentId)" })
        return collectionDocuments.filter {
            let key = "\($0.volumeId)/\($0.documentId)"
            return key != selfKey && targetKeys.contains(key)
        }
    }

    /// Resolves an `.excerpt` entry into its export item (Authoring Phase 5): the frozen
    /// verbatim passage plus a source citation built through the exact citation path
    /// document items use (`manifestMap` + `HistoryAtStateCitationFormatter`). No volume
    /// XML is touched — the passage was frozen at creation — so an excerpt renders fully
    /// even when its source volume isn't downloaded (in exports and the preview alike).
    ///
    /// - Returns: The `.excerpt` item, or `nil` when the entry carries no passage text
    ///   (a malformed sync payload — nothing to quote, so it is skipped defensively,
    ///   matching the empty-ids document guard).
    private func excerptItem(for ref: EntryRef, batch: BatchContext) -> CollectionExportItem? {
        guard let passage = ref.text, !passage.isEmpty else { return nil }
        let citation: String
        if !ref.volumeId.isEmpty, !ref.documentId.isEmpty {
            citation = shortCitation(volumeId: ref.volumeId, documentId: ref.documentId,
                                     batch: batch)
        } else {
            // No provenance (defensive): renderers omit the source line for an
            // empty citation rather than printing a junk reference.
            citation = ""
        }
        return .excerpt(CollectionExportExcerpt(
            text: passage,
            documentId: ref.documentId,
            volumeId: ref.volumeId,
            citation: citation,
            colorTag: ref.excerptColorTag))
    }

    /// The history.state.gov-style citation for a document reference — the same
    /// manifest + formatter path document items use, without needing the volume XML
    /// (`HistoryAtStateCitationFormatter` reads only volume metadata and the document
    /// number, never the document header/dateline, so this IS the full citation).
    /// Shared by the excerpt source line, the related-documents "See also:" line, and
    /// the generated-blocks data source; falls back to `"volumeId/documentId"` when
    /// the manifest doesn't know the volume.
    private func shortCitation(volumeId: String, documentId: String,
                               batch: BatchContext) -> String {
        let docNum: String? = documentId.hasPrefix("d")
            ? Int(documentId.dropFirst()).map { String($0) }
            : nil
        let docMeta = FRUSDocumentMetadata(
            documentId: documentId, documentNumber: docNum,
            header: "", dateline: nil)
        return batch.manifestMap[volumeId]
            .map { batch.formatter.format(document: docMeta, volume: FRUSVolumeMetadata($0)) }
            ?? "\(volumeId)/\(documentId)"
    }

    // MARK: - Live generated-block data source (Phase 6)

    /// The production `CollectionGeneratedBlockDataSource`: wires the block resolvers to
    /// the FTS5 index (`document_dates`, `document_sources`), the materialised People-
    /// browser rollup (`PersonMentionStore`), the bundled NARA resolution index
    /// (`VolumeSourcesIndexStore`), and SwiftData tags — all read-only, so blocks answer
    /// identically for `.preview` and `.export`. Every accessor degrades to empty when
    /// its backing service is unavailable (e.g. tests without a pipeline), which the
    /// blocks render as their localized "nothing to list" row.
    private struct LiveGeneratedBlockDataSource: CollectionGeneratedBlockDataSource {
        /// The owning resolver — supplies the citation path and the shared services.
        let resolver: CollectionContentResolver
        /// The batch whose manifest map / formatter / render models serve citations.
        let batch: BatchContext

        func citation(volumeId: String, documentId: String) -> String {
            // The single citation path: header-independent (the formatter never reads
            // header/dateline), so block rows match the document items' citations and
            // capped previews match exports by construction (v1.10).
            resolver.shortCitation(volumeId: volumeId, documentId: documentId, batch: batch)
        }

        func dateMetadata(
            for documents: [(volumeId: String, documentId: String)]
        ) async -> [String: DocumentDateMetadata] {
            guard let pipeline = resolver.appState.indexingPipeline else { return [:] }
            return (try? await pipeline.dateMetadataByDocumentKey(documents)) ?? [:]
        }

        func documentSources(
            for documents: [(volumeId: String, documentId: String)]
        ) async -> [CollectionGeneratedBlocks.SourceRecord] {
            guard let pipeline = resolver.appState.indexingPipeline else { return [] }
            let rows = (try? await pipeline.documentSourcesByKey(documents)) ?? [:]
            return rows.values.map {
                CollectionGeneratedBlocks.SourceRecord(
                    volumeId: $0.volumeId, documentId: $0.documentId,
                    repository: $0.repository, recordGroup: $0.recordGroup,
                    lotFile: $0.lotFile, seriesName: $0.seriesName, rawText: $0.rawText)
            }
        }

        // #372/N-5: a document citation resolves through its LOT and nothing else —
        // `documentResolution` does not take a record group, so this block can no longer
        // answer "740.00119 (Potsdam)/5-2446" with a link to the whole of RG 59. The record
        // group still appears in the row's label; only the hyperlink is withheld. The lot half
        // is central-files first, volume-sources second. See `ArchivalResolver`.
        //
        // `recordGroup` stays in the signature because `CollectionGeneratedBlocks` groups and
        // labels by it — it is simply not part of the resolution any more.
        func archivalResolution(recordGroup: String?, lotFile: String?)
            -> CollectionGeneratedBlocks.ArchivalLink? {
            ArchivalResolver.documentResolution(lotFile: lotFile)
                .map { CollectionGeneratedBlocks.ArchivalLink(title: $0.title,
                                                              urlString: $0.catalogURL) }
        }

        func personMentions(
            for documents: [(volumeId: String, documentId: String)]
        ) async -> [CollectionGeneratedBlocks.PersonMention] {
            guard let store = resolver.appState.personMentionStore else { return [] }
            let mentions = (try? await store.rollupMentions(forDocuments: documents)) ?? []
            return mentions.map {
                CollectionGeneratedBlocks.PersonMention(
                    identityKey: "r\($0.rollupId)", name: $0.canonicalName,
                    description: $0.description, role: $0.role,
                    volumeId: $0.volumeId, documentId: $0.documentId)
            }
        }

        func tagRecords() async -> [CollectionGeneratedBlocks.TagRecord] {
            let tags = (try? resolver.modelContext.fetch(FetchDescriptor<UserTag>())) ?? []
            guard !tags.isEmpty else { return [] }
            let assignments = (try? resolver.modelContext.fetch(
                FetchDescriptor<DocumentTagAssignment>())) ?? []
            // The batch already carries every research note — the same pool entry
            // note-links resolve against — so no second fetch is needed.
            return tags.map { tag in
                let refs = CollectionDocumentDiscovery.tagDocumentRefs(
                    tagId: tag.id, notes: batch.allNotes, assignments: assignments)
                return CollectionGeneratedBlocks.TagRecord(
                    name: tag.name,
                    documents: refs.map { (volumeId: $0.volumeId, documentId: $0.documentId) })
            }
        }
    }

    /// Resolves the stored `GeneratedSummary` text for a headnote: the explicitly chosen
    /// `summaryId` when set (and non-empty), else the document's summary for
    /// `preferredPromptId` (the collection's prompt), else any non-empty stored summary.
    /// Returns `nil` when nothing is stored — headnote resolution **never** generates
    /// (renderers emit a placeholder note instead; see the type doc, v1.4).
    private func headnoteText(
        volumeId: String,
        documentId: String,
        summaryId: UUID?,
        preferredPromptId: UUID?
    ) -> (text: String, authorship: SummaryAuthorship)? {
        // Capture scalars — #Predicate can't use struct fields.
        let vid = volumeId
        let did = documentId
        if let sid = summaryId {
            let descriptor = FetchDescriptor<GeneratedSummary>(
                predicate: #Predicate<GeneratedSummary> { $0.id == sid }
            )
            if let chosen = try? modelContext.fetch(descriptor).first,
               !chosen.responseText.isEmpty {
                return (chosen.responseText, chosen.authorship ?? .aiGenerated)
            }
            // The chosen summary no longer exists (deleted / not yet synced): fall
            // through to the stored-summary fallback rather than silently dropping
            // the requested headnote.
        }
        // Exclude headnote drafts from the fallback: a draft is a per-entry private summary reachable
        // ONLY via its owning entry's explicit `headnoteSummaryId` (handled above). Without this,
        // a second entry for the same document with no headnote of its own could fall back onto the
        // first entry's private draft.
        let descriptor = FetchDescriptor<GeneratedSummary>(
            predicate: #Predicate<GeneratedSummary> { s in
                s.volumeId == vid && s.documentId == did && s.isHeadnoteDraft == false
            }
        )
        let stored = ((try? modelContext.fetch(descriptor)) ?? [])
            .filter { !$0.responseText.isEmpty }
        if let pid = preferredPromptId, let preferred = stored.first(where: { $0.promptId == pid }) {
            return (preferred.responseText, preferred.authorship ?? .aiGenerated)
        }
        return stored.first.map { ($0.responseText, $0.authorship ?? .aiGenerated) }
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
                // #777: `manifest` is the catalogue, so a side-loaded volume is not in it — and
                // a volume whose file has been removed cannot be re-fetched either way. The
                // `downloadUrl` guard makes that explicit rather than depending on the lookup miss.
                if let entry = manifest.first(where: { $0.volumeId == vid }),
                   let url = entry.downloadUrl {
                    toDownload.append((vid, url))
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
    ///
    /// Documents are grouped by their **effective prompt** (the cascaded
    /// `summaryPromptIdOverride`, else the collection's `summaryPromptId` — Phase 5), so
    /// one collection can mix prompts; a collection with no overrides forms exactly one
    /// group under the collection prompt, reproducing the prior behavior including the
    /// `summaryPromptMissing` error when none is configured.
    private func applySummaryPhase(
        to items: [CollectionExportItem],
        collection: Collection,
        purpose: ResolvePurpose
    ) async throws -> [CollectionExportItem] {
        let summaryDocs = items.documents.filter { $0.bodyDepth == .summaryOnly }
        guard !summaryDocs.isEmpty else { return items }

        /// The prompt that supplies this document's summary (cascade, else collection).
        func effectivePrompt(_ doc: CollectionExportDocument) -> UUID? {
            doc.summaryPromptIdOverride ?? collection.summaryPromptId
        }
        /// Summary lookup key: document identity + effective prompt, so the same
        /// document under two different prompts attaches two different summaries.
        func summaryKey(_ doc: CollectionExportDocument) -> String {
            "\(doc.volumeId)/\(doc.documentId)|\(effectivePrompt(doc)?.uuidString ?? "")"
        }

        var summaries: [String: String] = [:]
        switch purpose {
        case .export:
            // Deterministic group order (by prompt id) so progress and failures are stable.
            let groups = Dictionary(grouping: summaryDocs, by: { effectivePrompt($0) })
                .sorted { ($0.key?.uuidString ?? "") < ($1.key?.uuidString ?? "") }
            for (promptId, docs) in groups {
                guard let promptId else {
                    throw CollectionResolveError.summaryPromptMissing
                }
                // uniquingKeysWith: the same document may legitimately appear in a
                // collection more than once; the duplicate pairs are identical.
                let bodyTexts = Dictionary(
                    docs.map { ("\($0.volumeId)/\($0.documentId)", $0.bodyText) },
                    uniquingKeysWith: { first, _ in first })
                let generated = try await resolveSummaries(for: docs, promptId: promptId,
                                                           bodyTexts: bodyTexts)
                for (docKey, text) in generated {
                    summaries["\(docKey)|\(promptId.uuidString)"] = text
                }
            }
        case .preview:
            // Never generate: attach stored summaries where they exist; a summary-depth
            // document without one — or with no effective prompt — keeps a nil summary
            // (the preview renders a placeholder).
            for doc in summaryDocs {
                guard let promptId = effectivePrompt(doc) else { continue }
                let key = summaryKey(doc)
                if summaries[key] == nil,
                   let text = storedSummary(volumeId: doc.volumeId, documentId: doc.documentId,
                                            promptId: promptId) {
                    summaries[key] = text
                }
            }
        }

        return items.map { item in
            guard case .document(let doc) = item, doc.bodyDepth == .summaryOnly,
                  let text = summaries[summaryKey(doc)] else { return item }
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
             .crossRefLink(_, _, _, let c):
            return renderNodePlainText(c)
        case .formulaText(let s):
            return s
        case .lineBreak:
            return " "
        case .footnoteMarker(_, _, _, let label):
            // #985: an unnumbered note contributes nothing to plain text. This walk reaches
            // document heads and datelines, where a head-nested source note previously emitted a
            // fabricated "[1]" into the exported title.
            return label.map { "[\($0)]" } ?? ""
        case .listBlock(_, let items):
            return items.map { renderNodePlainText($0) }.joined(separator: " ")
        case .tableBlock(let rows):
            return rows.map { row in row.map { renderNodePlainText($0.children) }.joined(separator: " | ") }.joined(separator: "\n")
        case .footnoteBody, .pageBreak, .figureBlock:
            return ""
        }
    }
}
