// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - CollectionContentResolver

// `CollectionResolveError` moved to FRUSCoreKit for FRUS Explorer Light (S18b), unchanged but public, with the
// assembly that throws it: `FRUSCoreKit/Collections/CollectionContentAssembly.swift`.

/// Resolves a `Collection` (static or smart) into the ordered `[CollectionExportItem]`
/// that exporters — and, from Phase 2b, the live preview — consume. This is the single
/// resolution pipeline for collection content: the export sheet keeps only UI and file
/// delivery, and every format (PDF/HTML/DOCX/Zotero/BibTeX) sees identical resolved items.
///
/// ## The assembly is FRUSCoreKit's
/// Since FRUS Explorer Light's S18b the resolution itself — which notes and highlights an entry
/// takes, the overrides cascaded through sections, body depth, headnotes, excerpts, the
/// related-documents line, the apparatus blocks, the Zotero items, the summary phase — is
/// `CollectionContentAssembly`, over values. This class keeps its API and builds one per resolve:
/// the collection and its entries as their values (`CollectionExport`, `CollectionContentAssembly.Entry`,
/// each prose block decoded by `CollectionProse.paragraphs(fromRTF:)`), the notes as
/// `ResearchNoteExport`, and itself as the `CollectionContentDataSource`, reading SwiftData through
/// `modelContext` and the library through `appState`. What the app's services do stays here: the
/// saved search's run (`smartRefs(for:)`), and the three things only an export does, the volumes'
/// download (`prepareVolumesForExport`), the figure images' fetch and Apple Intelligence's
/// summaries. A static export downloads its missing volumes before it reads the collection's values,
/// as it always read them after, and a smart collection's own entries are not read at all. See the
/// assembly's doc for the smart path, the purposes and cancellation.
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
///   1.11 — #1406: every citation names the volume's printed number. The batch reads the
///          stored `document_number` for its documents, excerpts and membership in one query
///          (`BatchContext.documentNumbers`), and the document heading, the excerpt source line,
///          the "See also:" line and the blocks resolve it through `CitableDocumentNumber` —
///          `d373a` was cited with no number because only `d` + an integer had one
///   1.12 — #1465: an export leaves out every Section heading saved with no text, with documents under it or none,
///          and lifts each named heading under it a level (`CollectionOutline.exportLevels`); the preview keeps it,
///          and the HTML renderer prints it as "Untitled section". The Section defaults it sets still reach the
///          documents beneath it, because the cascades run over the whole outline
///   1.13 — #1516: each render model names its figures' images by its document's volume, and an export that prints
///          images — PDF, Word, HTML (`ExportFormat.printsFigureImages`) — fetches the ones not on the device once its
///          items are resolved, for the documents resolved at full body depth only. BibTeX, RIS and the Zotero send
///          fetch none; nor does the preview
///   1.14 — 2026-10-25 (FRUS Explorer Light, S18a): a prose block and the introduction resolve to the spans every
///          format renders (`CollectionProse.paragraphs(fromRTF:)`, the decoder each exporter called before), since the
///          exporters' payloads are FRUSCoreKit's and take spans, not RTF
///   1.15 — 2026-10-27 (FRUS Explorer Light, S18b): the assembly is FRUSCoreKit's `CollectionContentAssembly`, over the
///          collection's values and a `CollectionContentDataSource`, which this class implements with SwiftData and
///          `AppState`; every entry point keeps its signature and forwards. What the app's services do stays here, as
///          the data source's last four methods: the saved search's run and, for an export only, the volumes'
///          download, the figure images' fetch and Apple Intelligence's summaries; a static export still downloads
///          its volumes before the collection is read. `CollectionResolveError` moved with the assembly, the generated
///          blocks' live data source is the assembly's, and `ResolvePurpose` and `SmartDocumentRef` name the kit's
///          types
///   1.16 — 2026-10-31: the data source's `generateSummaries` answers with each summary's record, stored or
///          generated, so a structured summary's format reaches the exporters, which print its fields
@MainActor
class CollectionContentResolver {

    // MARK: - ResolvePurpose

    /// What the resolved items are for, which gates the side-effecting phases of a resolve:
    /// FRUSCoreKit's `CollectionContentAssembly.Purpose` since FRUS Explorer Light's S18b.
    typealias ResolvePurpose = CollectionContentAssembly.Purpose

    // MARK: - SmartDocumentRef

    /// Lightweight document reference used for smart-collection resolution — one search
    /// result to resolve: FRUSCoreKit's `SmartCollectionDocumentRef` since FRUS Explorer Light's S18b.
    typealias SmartDocumentRef = SmartCollectionDocumentRef

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

    /// Where an export's absent figure images are fetched through (#1516). The app's store; a
    /// test sets its own.
    var figureImages: FigureImageStore = .shared

    /// Shown while an export fetches the figure images it lacks (`fetchAbsentFigureImages`).
    static var fetchingFiguresStatus: String {
        String(localized: "collection.export.status.fetchingFigures", defaultValue: "Fetching figure images…")
    }

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

    /// Resolves a collection's content into ordered export items: FRUSCoreKit's
    /// `CollectionContentAssembly.resolve(entries:introduction:purpose:printsFigureImages:)` over the
    /// collection's values, with this resolver as its data source.
    ///
    /// Smart collections (non-nil `savedSearchId`) execute their linked saved search
    /// (`smartRefs(for:)`) and resolve every result through the unified per-document pipeline.
    /// Static collections resolve their `entries`, preserving authored structure: headings and
    /// prose pass through, and the Phase 3c body-depth cascade (entry override → section override →
    /// collection default) applies per document.
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
    ///   - printsFigureImages: Whether what the items are resolved for prints a figure's image
    ///     (#1516): `ExportFormat.printsFigureImages` — PDF, Word and HTML. Only then, and only
    ///     for `.export`, are the images that are not on the device fetched first. Default
    ///     `false`: BibTeX prints citations, and the preview must fetch nothing.
    /// - Returns: Ordered export items ready for any `CollectionExporter`.
    /// - Throws: `CollectionResolveError` for smart-resolution and summary-prompt failures,
    ///   `ExportError.renderingFailed` when on-demand summary generation is impossible,
    ///   `CancellationError` when the surrounding task was cancelled mid-resolve (v1.1).
    func resolve(
        collection: Collection,
        entries: [CollectionEntry],
        allNotes: [ResearchNote],
        purpose: ResolvePurpose,
        printsFigureImages: Bool = false
    ) async throws -> [CollectionExportItem] {
        let volumesReady = await readyVolumes(of: collection, entries: entries, purpose: purpose)
        return try await assembly(for: collection, allNotes: allNotes, volumesReady: volumesReady)
            .resolve(entries: Self.entries(entries, of: collection), introduction: Self.introduction(of: collection),
                     purpose: purpose, printsFigureImages: printsFigureImages)
    }

    /// Resolves a pre-fetched (and possibly capped) smart-reference list into export items,
    /// including the summary phase — the preview's smart path (v1.1): FRUSCoreKit's
    /// `CollectionContentAssembly.resolve(smartRefs:introduction:purpose:fullRefs:)`. The preview
    /// fetches the lightweight refs with `smartRefs(for:)`, caps them to its render limit, and only
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
    ///   generated apparatus blocks).
    /// - Throws: `CancellationError` when the surrounding task was cancelled mid-resolve;
    ///   summary-phase errors for `.export`.
    func resolve(
        smartRefs refs: [SmartDocumentRef],
        collection: Collection,
        allNotes: [ResearchNote],
        purpose: ResolvePurpose,
        fullRefs: [SmartDocumentRef]? = nil
    ) async throws -> [CollectionExportItem] {
        try await assembly(for: collection, allNotes: allNotes)
            .resolve(smartRefs: refs, introduction: Self.introduction(of: collection), purpose: purpose,
                     fullRefs: fullRefs)
    }

    /// Documents-only resolution — for callers that need a flat document list and no
    /// summary phase (e.g. the Zotero RIS/Web-API send paths, which render citations and
    /// notes, never body content): FRUSCoreKit's `CollectionContentAssembly.resolveDocuments`.
    /// Headings and prose are dropped, and `.summaryOnly` depths pass through without triggering
    /// generation. No figure image is fetched (#1516): a citation prints none.
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
        let volumesReady = await readyVolumes(of: collection, entries: entries, purpose: purpose)
        return try await assembly(for: collection, allNotes: allNotes, volumesReady: volumesReady)
            .resolveDocuments(entries: Self.entries(entries, of: collection), purpose: purpose)
    }

    /// Resolves a single entry into its export item — the incremental API for the Phase 2b
    /// preview's refresh path: FRUSCoreKit's `CollectionContentAssembly.resolveItem`, which shares the
    /// per-entry pipeline with the batch resolve, so a re-resolved row is guaranteed to match what a
    /// full resolve would produce.
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
        await assembly(for: collection, allNotes: allNotes)
            .resolveItem(Self.entry(entry), sectionBodyDepth: sectionBodyDepth, headingLevel: headingLevel)
    }

    /// Resolves smart-collection references through the unified per-document pipeline, with the
    /// collection's generated apparatus blocks around them: FRUSCoreKit's
    /// `CollectionContentAssembly.resolveSmartItems`.
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
        await assembly(for: collection, allNotes: allNotes).resolveSmartItems(refs, fullRefs: fullRefs)
    }

    /// Executes a smart collection's linked saved search and returns one reference per
    /// result, in relevance order. Mirrors the pre-extraction smart export flow, including
    /// the full-result-set fetch (`SearchViewModel.searchHardLimit`, not the default page), through
    /// FRUSCoreKit's `SmartCollectionSnapshot.documentRefs`.
    ///
    /// Internal (v1.1) so the live preview can fetch the *lightweight* result list, cap it
    /// to its render limit, and resolve only the capped refs via `resolve(smartRefs:…)` —
    /// the refs are cheap (an FTS5 query); per-document resolution is what parses XML. A full
    /// resolve of a smart collection asks for them here too, through the data source, so a test's
    /// override stands in for the search.
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
        // exports. Mirror the live saved search's hard limit, through FRUSCoreKit's run (S18b).
        return try await SmartCollectionSnapshot.documentRefs(
            parameters: savedSearch.searchParameters, searchService: searchService,
            limit: SearchViewModel.searchHardLimit)
    }

    /// The figure images `items` print, each once, in reading order: FRUSCoreKit's
    /// `CollectionContentAssembly.printedFigureImages(in:)` (#1516).
    nonisolated static func printedFigureImages(in items: [CollectionExportItem]) -> [FigureImageName] {
        CollectionContentAssembly.printedFigureImages(in: items)
    }

    /// Composition options derived from the collection's persisted settings, used to gate
    /// resolution work (highlights, source notes, summary prompt). The word-cloud flag is
    /// format-dependent and irrelevant to resolution; exporters receive the options the export
    /// sheet takes from `ExportFormat.exportOptions(for:)`, which applies that gate. The model's
    /// `init(composing:)` reads FRUSCoreKit's over the collection's values, which the assembly reads,
    /// so the two cannot differ.
    ///
    /// Internal (not private) so tests can assert the legacy `footnoteStyle` → Bool-pair
    /// mapping end-to-end without standing up a full resolve.
    func resolutionOptions(for collection: Collection) -> CollectionExportOptions {
        CollectionExportOptions(composing: collection)
    }

    /// The A10 pure core, internal for tests: FRUSCoreKit's
    /// `CollectionContentAssembly.relatedDocumentTargets`.
    nonisolated static func relatedDocumentTargets(
        outboundTargets: [(volumeId: String, documentId: String)],
        selfVolumeId: String,
        selfDocumentId: String,
        collectionDocuments: [(volumeId: String, documentId: String)]
    ) -> [(volumeId: String, documentId: String)] {
        CollectionContentAssembly.relatedDocumentTargets(
            outboundTargets: outboundTargets, selfVolumeId: selfVolumeId, selfDocumentId: selfDocumentId,
            collectionDocuments: collectionDocuments)
    }

    /// Recursively extracts plain text from an array of `FRUSRenderNode` values: FRUSCoreKit's
    /// `CollectionContentAssembly.renderNodePlainText`.
    ///
    /// `nonisolated static` since #1371 so a test can pin the list branch; it reads no
    /// resolver state.
    nonisolated static func renderNodePlainText(_ nodes: [FRUSRenderNode]) -> String {
        CollectionContentAssembly.renderNodePlainText(nodes)
    }

    /// Recursively extracts plain text from a single `FRUSRenderNode`: FRUSCoreKit's
    /// `CollectionContentAssembly.renderNodePlainText`.
    nonisolated static func renderNodePlainText(_ node: FRUSRenderNode) -> String {
        CollectionContentAssembly.renderNodePlainText(node)
    }

    // MARK: - The values the assembly reads

    /// The assembly for one resolve of `collection`: its values with every entry, `allNotes` as
    /// their records, and this resolver, over `collection`, as the data source.
    ///
    /// - Parameter volumesReady: Whether this resolve already readied the volumes an export needs
    ///   (`readyVolumes(of:entries:purpose:)`), so the assembly's own ask has nothing left to do.
    private func assembly(for collection: Collection, allNotes: [ResearchNote],
                          volumesReady: Bool = false) -> CollectionContentAssembly {
        CollectionContentAssembly(
            collection: CollectionExport(collection),
            notes: allNotes.map(Self.noteValues),
            source: AppContentSource(resolver: self, collection: collection, volumesReady: volumesReady))
    }

    /// Readies a static collection's volumes for an export before anything of the collection is read:
    /// the volumes of its document entries, as the assembly would ask for them, downloaded and indexed
    /// where they are missing. The resolver always read the collection after this step, which can wait
    /// minutes, so an edit synced in meanwhile still reaches the export. Returns whether it ran; a
    /// preview and a smart collection ready nothing.
    private func readyVolumes(of collection: Collection, entries: [CollectionEntry],
                              purpose: ResolvePurpose) async -> Bool {
        guard collection.savedSearchId == nil, purpose == .export else { return false }
        // Document entries only: excerpts carry a real volumeId as provenance but render from their
        // frozen text (A9), so they never require the volume.
        await prepareVolumesForExport(Set(entries.filter { $0.entryKind == .document }.map(\.volumeId)))
        return true
    }

    /// The entries the assembly resolves: each one's values, for a static collection. A smart
    /// collection resolves its saved search's results and none of its own entries, so none is read,
    /// and no legacy prose blob of one is healed.
    private static func entries(_ entries: [CollectionEntry],
                                of collection: Collection) -> [CollectionContentAssembly.Entry] {
        collection.savedSearchId == nil ? entries.map(entry) : []
    }

    /// A collection entry as the assembly reads it: its values, and a prose block's paragraphs, decoded
    /// from its export RTF (which also heals a legacy Phase 3b blob in place — see `ProseRichText`).
    private static func entry(_ entry: CollectionEntry) -> CollectionContentAssembly.Entry {
        let paragraphs = entry.entryKind == .prose
            ? CollectionProse.paragraphs(fromRTF: ProseRichText.exportRTF(from: entry)) : nil
        return CollectionContentAssembly.Entry(CollectionEntryExport(entry), proseParagraphs: paragraphs)
    }

    /// The collection's introduction (Authoring Phase 4) as the paragraphs the assembly leads with:
    /// its RTF (`ProseRichText.exportRTF(richText:plainText:)`) decoded by `CollectionProse`, through
    /// the exact path every prose block takes, or `nil` when no introduction is set — so a collection
    /// without one resolves to exactly the pre-Phase-4 item list.
    private static func introduction(of collection: Collection) -> [[ProseFormattedSpan]]? {
        ProseRichText.exportRTF(richText: collection.introductionRichText,
                                plainText: collection.introductionText)
            .map { CollectionProse.paragraphs(fromRTF: $0) }
    }

    /// The fields of a research note the assembly reads: its identity, its document, its text and its
    /// tags (for the Thematic Index). The rest of the record is left empty.
    private static func noteValues(_ note: ResearchNote) -> ResearchNoteExport {
        ResearchNoteExport(id: note.id, documentId: note.documentId, volumeId: note.volumeId,
                           bodyText: note.bodyText, projectIds: [], userTagIds: note.userTagIds,
                           selectedSummaryIds: [], linkedHighlightIds: [])
    }

    // MARK: - The data source

    /// The app's `CollectionContentDataSource`: the library through `AppState` (the manifest store,
    /// the indexing pipeline, the AST cache over the download manager's volumes, the cross-reference
    /// and person-mention stores, the bundled archival indexes) and the researcher's store through the
    /// resolver's SwiftData context. Every read answers what the resolver read before the assembly
    /// moved into FRUSCoreKit, from the same fetch; the export steps forward to the resolver, so a test
    /// subclass's `smartRefs(for:)` and `prepareVolumesForExport(_:)` stand in for them.
    private struct AppContentSource: CollectionContentDataSource {
        /// The resolver whose services and context answer.
        let resolver: CollectionContentResolver
        /// The collection being resolved, whose saved search a smart resolve runs.
        let collection: Collection
        /// Whether the resolver readied this export's volumes before the collection was read.
        let volumesReady: Bool

        var manifestEntries: [VolumeManifestEntry] {
            resolver.appState.manifestStore.diffResult?.known
                ?? resolver.appState.manifestStore.bundledEntries
        }

        var indexingPipeline: IndexingPipeline? { resolver.appState.indexingPipeline }

        func documentAST(volumeId: String, documentId: String) async -> FRUSDocumentAST? {
            await resolver.cachedAST(volumeId: volumeId, documentId: documentId)
        }

        func crossReferenceTargets(volumeId: String, documentId: String) async
            -> [(volumeId: String, documentId: String)]? {
            guard let store = resolver.appState.crossReferenceStore else { return nil }
            let edges = (try? await store.outboundEdges(forDocumentId: documentId, volumeId: volumeId)) ?? []
            return edges.map { (volumeId: $0.targetVolumeId, documentId: $0.targetDocumentId) }
        }

        var personMentionStore: PersonMentionStore? { resolver.appState.personMentionStore }

        var archivalIndexes: ArchivalIndexes { .bundled }

        func highlights(volumeId: String, documentId: String) -> [DocumentHighlightExport] {
            let all = (try? resolver.modelContext.fetch(FetchDescriptor<DocumentHighlight>())) ?? []
            return all
                .filter { $0.volumeId == volumeId && $0.documentId == documentId }
                .map {
                    DocumentHighlightExport(id: $0.id, volumeId: $0.volumeId, documentId: $0.documentId,
                                            startOffset: $0.startOffset, endOffset: $0.endOffset,
                                            colorTag: $0.colorTag, noteId: $0.noteId,
                                            selectedText: $0.selectedText,
                                            renderingVersion: $0.renderingVersion, createdAt: $0.createdAt)
                }
        }

        func summary(id: UUID) -> GeneratedSummaryExport? {
            let descriptor = FetchDescriptor<GeneratedSummary>(
                predicate: #Predicate<GeneratedSummary> { $0.id == id }
            )
            return (try? resolver.modelContext.fetch(descriptor).first).map(Self.values)
        }

        func headnoteSummaries(volumeId: String, documentId: String) -> [GeneratedSummaryExport] {
            // Capture scalars — #Predicate can't use struct fields.
            let vid = volumeId
            let did = documentId
            let descriptor = FetchDescriptor<GeneratedSummary>(
                predicate: #Predicate<GeneratedSummary> { s in
                    s.volumeId == vid && s.documentId == did && s.isHeadnoteDraft == false
                }
            )
            return ((try? resolver.modelContext.fetch(descriptor)) ?? []).map(Self.values)
        }

        func summary(volumeId: String, documentId: String, promptId: UUID) -> GeneratedSummaryExport? {
            resolver.storedSummaryRecord(volumeId: volumeId, documentId: documentId, promptId: promptId)
                .map(Self.values)
        }

        func zoteroTags(volumeId: String, documentId: String) -> [String] {
            ZoteroJSONExporter.fetchTagsAndNotes(documentId: documentId, volumeId: volumeId,
                                                 context: resolver.modelContext).tags
        }

        func userTags() -> [UserTagExport] {
            ((try? resolver.modelContext.fetch(FetchDescriptor<UserTag>())) ?? [])
                .map { UserTagExport(id: $0.id, name: $0.name) }
        }

        func tagAssignments() -> [DocumentTagAssignmentExport] {
            ((try? resolver.modelContext.fetch(FetchDescriptor<DocumentTagAssignment>())) ?? [])
                .map { DocumentTagAssignmentExport(id: $0.id, volumeId: $0.volumeId,
                                                   documentId: $0.documentId, tagId: $0.tagId) }
        }

        func smartDocumentRefs() async throws -> [SmartCollectionDocumentRef] {
            try await resolver.smartRefs(for: collection)
        }

        func prepareVolumesForExport(_ volumeIds: Set<String>) async {
            // The resolver readied these before it read the collection (`readyVolumes`), the same set.
            guard !volumesReady else { return }
            await resolver.prepareVolumesForExport(volumeIds)
        }

        func fetchAbsentFigureImages(_ images: [FigureImageName]) async {
            await resolver.fetchAbsentFigureImages(images)
        }

        func generateSummaries(for documents: [CollectionExportDocument], promptId: UUID,
                               bodyTexts: [String: String]) async throws -> [String: GeneratedSummaryExport] {
            try await resolver.resolveSummaries(for: documents, promptId: promptId, bodyTexts: bodyTexts)
                .mapValues(Self.values)
        }

        /// A stored summary's values: what the assembly reads of it is its text, its prompt and its
        /// authorship; the rest is carried as stored.
        private static func values(_ summary: GeneratedSummary) -> GeneratedSummaryExport {
            GeneratedSummaryExport(id: summary.id, documentId: summary.documentId, volumeId: summary.volumeId,
                                   promptId: summary.promptId, responseText: summary.responseText,
                                   responseFormat: summary.responseFormat, wasChunked: summary.wasChunked,
                                   projectId: summary.projectId, createdAt: summary.createdAt,
                                   lastModified: summary.lastModified, authorship: summary.authorship,
                                   isHeadnoteDraft: summary.isHeadnoteDraft)
        }
    }

    // MARK: - Figure images (export only)

    /// Fetches those of `images` that are not on the device (#1516), each printed by a document
    /// resolved at full body depth. An image that cannot be fetched prints its placeholder. Reports
    /// `fetchingFiguresStatus` through `onPreparingStatus` while it asks, and nothing when every image
    /// is on the device; stops when the task is cancelled.
    private func fetchAbsentFigureImages(_ images: [FigureImageName]) async {
        let absent = images.filter { figureImages.data(for: $0) == nil }
        guard !absent.isEmpty, !Task.isCancelled else { return }
        onPreparingStatus?(Self.fetchingFiguresStatus)
        await figureImages.fetchAbsent(absent)
        onPreparingStatus?(nil)
    }

    // MARK: - Parsed documents

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

    // MARK: - Summary generation (export only)

    /// The first `GeneratedSummary` stored for a document under `promptId`, a headnote draft included,
    /// or `nil` when none exists — the record the data source's `summary(volumeId:documentId:promptId:)`
    /// answers with and `storedSummary` reads.
    private func storedSummaryRecord(volumeId: String, documentId: String, promptId: UUID) -> GeneratedSummary? {
        // Capture scalars — #Predicate can't use struct fields.
        let vid = volumeId
        let did = documentId
        let pid = promptId
        let descriptor = FetchDescriptor<GeneratedSummary>(
            predicate: #Predicate<GeneratedSummary> { s in
                s.volumeId == vid && s.documentId == did && s.promptId == pid
            }
        )
        return try? modelContext.fetch(descriptor).first
    }

    /// Returns the stored `GeneratedSummary` for a document under `promptId`, or
    /// `nil` when none exists (or its text is empty). Never generates.
    private func storedSummary(volumeId: String, documentId: String, promptId: UUID) -> GeneratedSummary? {
        guard let existing = storedSummaryRecord(volumeId: volumeId, documentId: documentId, promptId: promptId),
              !existing.responseText.isEmpty else { return nil }
        return existing
    }

    /// Generates or fetches summaries for all entries when bodyDepth == .summaryOnly.
    /// Returns a [key: summary] map, each summary's text and format what its document prints.
    /// Throws if any generation fails. Export only —
    /// `.preview` uses `storedSummary` and never reaches this path. The data source's
    /// `generateSummaries(for:promptId:bodyTexts:)`, which the assembly's summary phase calls for each
    /// group of documents under one prompt.
    private func resolveSummaries(
        for docs: [CollectionExportDocument],
        promptId: UUID,
        bodyTexts: [String: String]
    ) async throws -> [String: GeneratedSummary] {
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

        var result: [String: GeneratedSummary] = [:]
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
            result[key] = generated
        }
        onSummaryStatus?(nil)
        return result
    }
}
