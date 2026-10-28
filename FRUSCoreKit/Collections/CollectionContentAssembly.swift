// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CollectionResolveError

/// Errors thrown while resolving a collection into export items. Each case carries the
/// same user-facing message the export sheet showed before the resolver extraction, so
/// `error.localizedDescription` presents identically in the UI.
///
/// Version history:
///   1.0 — Session 2026-07-02 (Collections Authoring Phase 2a): extracted from the
///          inline `exportError` assignments in `ExportSheetView.runExport()`
///   1.1 — 2026-10-27 (FRUS Explorer Light, S18b): moved into FRUSCoreKit with the assembly that throws
///          `summaryPromptMissing`, public, so a host outside the app shows the app's messages
public enum CollectionResolveError: Error, LocalizedError {
    /// The FTS5-backed `SearchService` was unavailable while resolving a smart collection.
    case searchServiceUnavailable
    /// The smart collection's linked `SavedSearch` no longer exists.
    case savedSearchMissing
    /// An `.export` resolve found `.summaryOnly` documents but the collection has no
    /// summarization prompt configured.
    case summaryPromptMissing

    /// User-facing description — the exact strings the export sheet showed pre-extraction.
    public var errorDescription: String? {
        switch self {
        case .searchServiceUnavailable:
            return String(localized: "export.smart.noSearchService.v2",
                          defaultValue: "Search is not ready yet. Try again in a moment.")
        case .savedSearchMissing:
            return String(localized: "export.smart.missingSearch",
                          defaultValue: "The linked saved search could not be found. It may have been deleted.")
        case .summaryPromptMissing:
            return String(localized: "export.summaryNoPrompt",
                          defaultValue: "Choose a summarization prompt in the collection’s Composition section to export summaries.")
        }
    }
}

// MARK: - CollectionContentDataSource

/// Everything `CollectionContentAssembly` reads that is not the collection itself: the library (the
/// manifest, the index, the volumes' TEI, the cross-references, the people rollup and the archival
/// indexes), the researcher's store (highlights, summaries and tags; the notes come with the
/// collection), a smart collection's saved search, and the three things only an export does. The
/// app's is `CollectionContentResolver`'s, over SwiftData and `AppState`; a host outside the app
/// implements it over its own index and store. Like the assembly, it is main-actor isolated, as the
/// app's resolver always was.
///
/// The store's answers are the research data export's records (`DocumentHighlightExport`,
/// `GeneratedSummaryExport`, `UserTagExport`, `DocumentTagAssignmentExport`), the values a host's rows
/// already map to. Every read is **read-only**: only the three export methods may download, fetch or
/// generate anything, and the assembly calls them only for `.export`.
///
/// Version history:
///   1.0 — 2026-10-27 (FRUS Explorer Light, S18b): the reads `CollectionContentResolver` made of `AppState`
///          and its model context, behind a protocol
@MainActor
public protocol CollectionContentDataSource {

    // MARK: The library

    /// The volume catalogue citations and titles are made from: the manifest's known entries, else its
    /// bundled copy. Read once per batch.
    var manifestEntries: [VolumeManifestEntry] { get }

    /// The index a document's plain body, printed number, source note, dates and parsed archival
    /// sources are read from, and its editorial-note flags; `nil` before one is open, when each of
    /// those reads answers nothing.
    var indexingPipeline: IndexingPipeline? { get }

    /// A document's parsed TEI, or `nil` when its volume is not here (a preview of a volume not
    /// downloaded) or the document cannot be parsed. The app's comes from its shared AST cache, and a
    /// miss is parsed once and stored back.
    func documentAST(volumeId: String, documentId: String) async -> FRUSDocumentAST?

    /// The documents a document's outbound cross-references point at, in any order, duplicates
    /// allowed; `nil` when the host keeps no cross-references, which leaves the "See also:" line empty.
    func crossReferenceTargets(volumeId: String, documentId: String) async
        -> [(volumeId: String, documentId: String)]?

    /// The People browser's materialised rollup, which the Persons Index reads, or `nil` when there is
    /// none, which lists no one.
    var personMentionStore: PersonMentionStore? { get }

    /// The indexes the Sources & Archives block links a lot through (`ArchivalResolver`).
    var archivalIndexes: ArchivalIndexes { get }

    // MARK: The researcher's store

    /// A document's highlights, in the store's order.
    func highlights(volumeId: String, documentId: String) -> [DocumentHighlightExport]

    /// The stored summary with `id`, if there is one.
    func summary(id: UUID) -> GeneratedSummaryExport?

    /// A document's stored summaries other than headnote drafts, in the store's order: where a
    /// headnote falls back to when its own summary is gone. A draft belongs to the entry that chose it.
    func headnoteSummaries(volumeId: String, documentId: String) -> [GeneratedSummaryExport]

    /// The first summary stored for a document under `promptId`, a headnote draft included, if any.
    func summary(volumeId: String, documentId: String, promptId: UUID) -> GeneratedSummaryExport?

    /// The names a document's Zotero item lists as its tags.
    func zoteroTags(volumeId: String, documentId: String) -> [String]

    /// Every user tag, which the Thematic Index lists where a tag reaches a member.
    func userTags() -> [UserTagExport]

    /// Every direct tag assignment, which the Thematic Index reads with the notes' tags.
    func tagAssignments() -> [DocumentTagAssignmentExport]

    // MARK: The saved search

    /// One reference per result of the collection's saved search, in relevance order — the app's runs
    /// `SmartCollectionSnapshot.documentRefs` — or the search's error, `CollectionResolveError` when it
    /// cannot run. Asked for a smart collection's full resolve in either purpose
    /// (`resolve(entries:introduction:purpose:printsFigureImages:)`, `resolveDocuments`); a capped preview
    /// runs the search itself and resolves the refs it keeps (`resolve(smartRefs:introduction:purpose:fullRefs:)`).
    func smartDocumentRefs() async throws -> [SmartCollectionDocumentRef]

    // MARK: What only an export does

    /// Makes the volumes of a static collection's document entries ready to resolve: the app downloads
    /// and indexes the missing ones, reporting progress. Asked only for `.export`.
    func prepareVolumesForExport(_ volumeIds: Set<String>) async

    /// Fetches those of `images` that are not here, each printed by a document resolved at full body
    /// depth. Asked only for an `.export` whose format prints images; an image never fetched prints its
    /// placeholder.
    func fetchAbsentFigureImages(_ images: [FigureImageName]) async

    /// The summaries the `.summaryOnly` documents of an export print under `promptId`, keyed
    /// `"volumeId/documentId"`: a stored one where there is one, else one generated, or the reason none
    /// can be — the app throws `ExportError.renderingFailed` when Apple Intelligence is unavailable.
    /// `bodyTexts` holds each document's plain body, keyed the same way. Asked only for `.export`.
    func generateSummaries(for documents: [CollectionExportDocument], promptId: UUID,
                           bodyTexts: [String: String]) async throws -> [String: String]
}

// MARK: - CollectionEntryExport.entryKind

extension CollectionEntryExport {

    /// The entry's kind as `CollectionEntry.entryKind` reads its stored raw value: a raw value this
    /// build does not know (written by a newer version) reads as `.unrecognized`, never as a junk
    /// document. A record with no kind (a research data export before format version 7) is a
    /// document, as that format wrote only documents.
    public var entryKind: CollectionEntryKind {
        CollectionEntryKind(rawValue: kind ?? CollectionEntryKind.document.rawValue) ?? .unrecognized
    }
}

// MARK: - CollectionContentAssembly

/// Resolves a collection (static or smart) into the ordered `[CollectionExportItem]` that exporters —
/// and the live preview — consume, from the collection's values and a `CollectionContentDataSource`.
/// This is the single resolution pipeline for collection content: every format (PDF/HTML/DOCX/Zotero/
/// BibTeX) sees identical resolved items. The app's `CollectionContentResolver` builds one per resolve,
/// over its SwiftData models and `AppState`, and forwards every resolve here; a host outside the app
/// does the same over its own store.
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
/// ## Render models
/// Each document's render model is converted from the AST the data source hands back
/// (`documentAST(volumeId:documentId:)`) by a fresh `ASTToRenderNodeConverter` at every resolve, so a
/// stale render model is never served; the app's data source keeps the AST, not the render model, in
/// its cache for that reason.
///
/// ## Purpose
/// `.export` behaves as the pre-extraction export flow did: missing volumes are downloaded
/// and indexed first, and `.summaryOnly` documents get on-demand AI summary generation.
/// `.preview` **never downloads volumes and never generates summaries** — documents from
/// un-downloaded volumes resolve to citation-only items (empty body, no render model), and
/// `.summaryOnly` documents keep a `nil` summary unless one is already stored (the preview
/// renders placeholders for those, Phase 2b).
///
/// ## Cooperative cancellation
/// The per-document loops — the batch-context load and the per-entry resolve pass — check
/// `Task.isCancelled` and stop early, so a superseded preview resolve does not SAX-parse
/// documents nobody will render. The loops themselves stay non-throwing and return a
/// *partial-safe* result (fewer loaded contexts / fewer items — never junk); the throwing
/// entry points (`resolve`, `resolve(smartRefs:…)`, `resolveDocuments`) then convert the
/// cancellation into a thrown `CancellationError` so no caller can mistake a truncated
/// result for a complete one.
///
/// ## The main actor
/// The assembly and its data source are main-actor isolated, as the app's resolver and the blocks' data
/// source were; a host resolves a collection on the main actor, and the heavy work runs inside the awaited
/// parses and index reads.
///
/// ## The collection's values
/// The collection comes as the research data export's record of it (`CollectionExport`, its `entries`
/// every entry in `sortOrder`), read once when the assembly is made: its composition, its default body
/// depth, its summary prompt, its whole document membership (the A10 universe and the blocks') and its
/// apparatus entries. The entries to resolve come as `Entry` values, a prose block's paragraphs
/// decoded by the host, since the kit reads no RTF; the notes as `ResearchNoteExport` records.
///
/// Version history:
///   1.0 — 2026-10-27 (FRUS Explorer Light, S18b): `CollectionContentResolver`'s assembly, moved into
///          FRUSCoreKit over values and a data source, unchanged in what it resolves: which notes and
///          highlights an entry takes, the overrides cascaded through sections, body depth, headnotes,
///          excerpts, the related-documents line, the five apparatus blocks, the Zotero items and the
///          summary phase. The resolver's own history, 1.0 to 1.14, is in `CollectionContentResolver.swift`
@MainActor
public struct CollectionContentAssembly {

    // MARK: - Purpose

    /// What the resolved items are for. Gates the side-effecting phases of a resolve.
    public enum Purpose: Sendable {
        /// Full export behavior: missing volumes are downloaded and indexed before
        /// resolution, and `.summaryOnly` documents generate summaries on demand.
        case export
        /// Read-only resolution for the live preview: never downloads volumes and never
        /// triggers AI generation. Un-downloaded volumes yield citation-only items;
        /// `.summaryOnly` documents attach a stored summary when one exists, else `nil`.
        case preview
    }

    // MARK: - Dependencies

    /// The collection's values: composition, default body depth, summary prompt, saved search and
    /// every entry (the membership and the apparatus).
    private let collection: CollectionExport

    /// All research notes, for resolving entry note links and (smart path) per-document note
    /// attachment, and for the Thematic Index's note tags.
    private let notes: [ResearchNoteExport]

    /// The library and the researcher's store.
    private let source: any CollectionContentDataSource

    /// The locale the Chronology block's dates print in.
    private let locale: Locale

    /// Creates the assembly for one collection.
    ///
    /// - Parameters:
    ///   - collection: The collection's values, `entries` every one of its entries (in any order;
    ///     each use sorts by `sortOrder`).
    ///   - notes: All research notes, in the order the host lists them.
    ///   - source: The library and the researcher's store.
    ///   - locale: The locale the Chronology block's dates print in: the device's by default, as the
    ///     app's always have.
    public init(collection: CollectionExport, notes: [ResearchNoteExport],
                source: any CollectionContentDataSource, locale: Locale = .autoupdatingCurrent) {
        self.collection = collection
        self.notes = notes
        self.source = source
        self.locale = locale
    }

    // MARK: - Public API

    /// Resolves the collection's content into ordered export items.
    ///
    /// Smart collections (non-nil `savedSearchId`) execute their linked saved search
    /// (`smartDocumentRefs()`) and resolve every result through the unified per-document pipeline (see
    /// the type doc for the composition semantics). Static collections resolve `entries`, preserving
    /// authored structure: headings and prose pass through, and the Phase 3c body-depth
    /// cascade (entry override → section override → collection default) applies per document.
    ///
    /// For `.export`, missing volumes are made ready first (static collections only —
    /// smart results come from the index, so their volumes are present by construction) and
    /// `.summaryOnly` documents generate summaries on demand. For `.preview`, neither
    /// side-effecting phase runs.
    ///
    /// - Parameters:
    ///   - entries: The entries to resolve (ignored for smart collections) — all of the collection's,
    ///     or a capped prefix of them.
    ///   - introduction: The collection's introduction, as the paragraphs the host decoded from its
    ///     rich text, or `nil` when it has none. A set introduction leads the items as one `.prose`.
    ///   - purpose: Gates volume preparation and summary generation (see `Purpose`).
    ///   - printsFigureImages: Whether what the items are resolved for prints a figure's image
    ///     (#1516) — PDF, Word and HTML. Only then, and only for `.export`, are the images that are
    ///     not here fetched first. Default `false`: BibTeX prints citations, and the preview must
    ///     fetch nothing.
    /// - Returns: Ordered export items ready for any `CollectionExporter`.
    /// - Throws: `CollectionResolveError` for smart-resolution and summary-prompt failures,
    ///   the data source's summary errors, `CancellationError` when the surrounding task was
    ///   cancelled mid-resolve.
    public func resolve(
        entries: [Entry],
        introduction: [[ProseFormattedSpan]]?,
        purpose: Purpose,
        printsFigureImages: Bool = false
    ) async throws -> [CollectionExportItem] {
        let items = try await resolveWithoutSummaries(
            entries: entries, purpose: purpose,
            fetchesAbsentFigures: purpose == .export && printsFigureImages)
        // A cancelled pass returned partial-safe items — surface the cancellation instead
        // of handing a truncated result to a caller that expected the whole collection.
        try Task.checkCancellation()
        let framed = Self.introductionItems(introduction) + items
        return try await applySummaryPhase(to: framed, purpose: purpose)
    }

    /// Resolves a pre-fetched (and possibly capped) smart-reference list into export items,
    /// including the summary phase — the preview's smart path. The preview fetches the
    /// lightweight refs, caps them to its render limit, and only then pays per-document
    /// resolution here, so at most the cap is ever parsed.
    ///
    /// - Parameters:
    ///   - refs: The smart-collection document references to resolve, in order.
    ///   - introduction: As for `resolve(entries:introduction:purpose:printsFigureImages:)`.
    ///   - purpose: Gates the summary phase (see `Purpose`).
    ///   - fullRefs: The *uncapped* result set, when `refs` is a capped prefix of it. Membership-wide
    ///     computations — generated apparatus blocks and the A10 related-documents universe — use this
    ///     list, so a capped preview's blocks match the export's. `nil` (default) means `refs` IS the
    ///     full result set.
    /// - Returns: Ordered export items for exactly the given refs (plus the collection's
    ///   generated apparatus blocks — see `resolveSmartItems`).
    /// - Throws: `CancellationError` when the surrounding task was cancelled mid-resolve;
    ///   summary-phase errors for `.export` (see `applySummaryPhase`).
    public func resolve(
        smartRefs refs: [SmartCollectionDocumentRef],
        introduction: [[ProseFormattedSpan]]?,
        purpose: Purpose,
        fullRefs: [SmartCollectionDocumentRef]? = nil
    ) async throws -> [CollectionExportItem] {
        let items = await resolveSmartItems(refs, fullRefs: fullRefs)
        try Task.checkCancellation()
        let framed = Self.introductionItems(introduction) + items
        return try await applySummaryPhase(to: framed, purpose: purpose)
    }

    /// The collection's front-matter items (Authoring Phase 4): the introduction as a
    /// leading `.prose` item when set, else nothing — so a collection without one resolves to
    /// exactly the pre-Phase-4 item list. The introduction renders through the same path every
    /// prose block takes, so its formatting survives HTML, PDF, DOCX and the live preview. Title page
    /// and colophon are metadata-driven instead (see `CollectionExportMetadata`), keeping the item
    /// stream pure content.
    ///
    /// - Parameter introduction: The introduction's paragraphs, or `nil` when none is set.
    /// - Returns: `[.prose(introduction)]`, or `[]`.
    public static func introductionItems(_ introduction: [[ProseFormattedSpan]]?) -> [CollectionExportItem] {
        guard let introduction else { return [] }
        return [.prose(introduction)]
    }

    /// Documents-only resolution — for callers that need a flat document list and no
    /// summary phase (e.g. the Zotero RIS/Web-API send paths, which render citations and
    /// notes, never body content). Headings and prose are dropped, and `.summaryOnly` depths
    /// pass through without triggering generation. No figure image is fetched (#1516): a citation
    /// prints none.
    ///
    /// - Parameters: See `resolve(entries:introduction:purpose:printsFigureImages:)`.
    /// - Returns: The resolved `.document` payloads, in collection order.
    /// - Throws: `CollectionResolveError` for smart-resolution failures, `CancellationError`
    ///   when the surrounding task was cancelled mid-resolve.
    public func resolveDocuments(entries: [Entry], purpose: Purpose) async throws -> [CollectionExportDocument] {
        let documents = try await resolveWithoutSummaries(
            entries: entries, purpose: purpose, fetchesAbsentFigures: false)
            .documents
        // Same discipline as `resolve`: never hand back a cancellation-truncated list.
        try Task.checkCancellation()
        return documents
    }

    /// Resolves a single entry into its export item — the incremental API for the
    /// preview's refresh path. Shares the per-entry pipeline with the batch resolve, so a
    /// re-resolved row is guaranteed to match what a full resolve would produce.
    ///
    /// This path is inherently preview-safe: it never makes volumes ready and never generates
    /// summaries. A `.summaryOnly` document attaches a stored summary when one exists for
    /// its effective prompt; otherwise `summaryText` stays `nil`.
    ///
    /// - Parameters:
    ///   - entry: The entry to resolve (document, heading, prose, excerpt or generated).
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
    public func resolveItem(
        _ entry: Entry,
        sectionBodyDepth: String? = nil,
        headingLevel: Int? = nil
    ) async -> CollectionExportItem? {
        let level = headingLevel ?? min(max(entry.level, 1), CollectionOutline.maxLevel)
        // Related-documents membership (A10) comes from the owning collection's entry
        // list, so a single-entry resolve matches what a full resolve would compute.
        let batch = await loadBatchContext(for: [entry], collectionDocuments: collectionDocumentRefs())
        guard let item = await resolveEntry(entry,
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
    ///
    /// - Parameter fetchesAbsentFigures: Whether to fetch, once the items are resolved, the
    ///   figure images they print that are not here (#1516). One place for both the
    ///   smart and the static path, so neither can be wired without the other.
    private func resolveWithoutSummaries(
        entries: [Entry],
        purpose: Purpose,
        fetchesAbsentFigures: Bool
    ) async throws -> [CollectionExportItem] {
        let items = try await resolveItemsWithoutSummaries(entries: entries, purpose: purpose)
        if fetchesAbsentFigures { await fetchAbsentFigureImages(printedBy: items) }
        return items
    }

    /// Asks the data source for the figure images `items` print (#1516): those of the documents
    /// resolved at full body depth, which the host fetches where they are not here. A summary-only or
    /// index entry prints no body, so none of its document's images is asked for. Nothing is asked
    /// once the task is cancelled, or when no image is printed.
    private func fetchAbsentFigureImages(printedBy items: [CollectionExportItem]) async {
        let printed = Self.printedFigureImages(in: items)
        guard !printed.isEmpty, !Task.isCancelled else { return }
        await source.fetchAbsentFigureImages(printed)
    }

    /// The figure images `items` print, each once, in reading order: those in the render model
    /// of each document resolved at `.full` body depth (#1516).
    public nonisolated static func printedFigureImages(in items: [CollectionExportItem]) -> [FigureImageName] {
        var seen = Set<FigureImageName>()
        return items.documents
            .filter { $0.bodyDepth == .full }
            .flatMap { $0.renderModel?.figureImages ?? [] }
            .filter { seen.insert($0).inserted }
    }

    /// The items of a collection, smart or static, before the summary phase and before any
    /// figure image is fetched: see ``resolveWithoutSummaries``.
    private func resolveItemsWithoutSummaries(
        entries: [Entry],
        purpose: Purpose
    ) async throws -> [CollectionExportItem] {
        // Smart collection path: resolve documents via the linked saved search, then run
        // them through the unified per-document pipeline.
        if collection.savedSearchId != nil {
            let refs = try await source.smartDocumentRefs()
            return await resolveSmartItems(refs)
        }

        // Static collection path.
        // Export only: ensure every referenced volume is ready first.
        // Preview must never trigger downloads — un-downloaded volumes resolve to
        // citation-only items instead.
        if purpose == .export {
            // Document entries only: excerpts carry a real volumeId as provenance but
            // render from their frozen text (A9), so they never require the volume.
            await source.prepareVolumesForExport(Set(
                entries.filter { $0.kind == .document }.map(\.volumeId)))
        }

        // Related-documents membership (A10) comes from the owning collection's full
        // entry list, NOT the passed entries — the preview passes a capped prefix, and
        // computing the universe from it would silently drop "See also:" targets past
        // the cap that the export (full list) shows. Matches `resolveItem`'s sourcing.
        let batch = await loadBatchContext(for: entries, collectionDocuments: collectionDocumentRefs())
        // #1465: an export leaves out every heading saved with no text; the preview shows it ("Untitled section").
        return await resolveItems(from: entries, batch: batch, dropsUntitledHeadings: purpose == .export)
    }

    /// Resolves smart-collection references through the unified per-document pipeline.
    ///
    /// The same per-entry body serves both paths, so smart documents carry composition-driven
    /// content (notes, highlights, source notes). Synthetic entries have no per-entry overrides or
    /// note selections, so the collection default body depth applies and note attachment falls back
    /// to *every* research note on the document (matching what the smart Zotero items already
    /// carried).
    ///
    /// Generated apparatus blocks: the collection's static `.generated` entries resolve here too,
    /// fed the smart result set as their membership — front-matter blocks (per
    /// `CollectionGeneratedBlockType.defaultPosition`) before the smart items, back-matter blocks
    /// after, each group in `sortOrder` order. Smart documents come from the saved search, so a
    /// hand-authored position *between* them cannot exist; the default position is the only
    /// meaningful placement.
    ///
    /// - Parameter fullRefs: The uncapped result set when `refs` is a capped prefix
    ///   (see `resolve(smartRefs:…)`); `nil` means `refs` is the full set.
    public func resolveSmartItems(
        _ refs: [SmartCollectionDocumentRef],
        fullRefs: [SmartCollectionDocumentRef]? = nil
    ) async -> [CollectionExportItem] {
        let entries = refs.map(Entry.init)
        // Membership-wide computations (generated blocks, A10 universe) see the FULL
        // result set even when per-document resolution was capped by the preview.
        let membership = Self.documentRefs(in: (fullRefs ?? refs).map(Entry.init))
        let batch = await loadBatchContext(for: entries, collectionDocuments: membership)
        // A smart collection's entries are search results, never headings, so there is nothing to drop.
        let items = await resolveItems(from: entries, batch: batch, dropsUntitledHeadings: false)
        let (front, back) = await generatedItems(batch: batch)
        return front + items + back
    }

    /// Resolves the collection's `.generated` entries for the smart path,
    /// partitioned by their type's `defaultPosition` — `(front matter, back matter)`,
    /// each in `sortOrder` order. Unknown block types are skipped (the same
    /// newer-version guard as `resolveEntry`); a cancelled task returns the blocks
    /// resolved so far (partial-safe, matching the per-entry loops).
    private func generatedItems(
        batch: BatchContext
    ) async -> (front: [CollectionExportItem], back: [CollectionExportItem]) {
        var front: [CollectionExportItem] = []
        var back: [CollectionExportItem] = []
        let generatedEntries = collection.entries
            .filter { $0.entryKind == .generated }
            .sorted { $0.sortOrder < $1.sortOrder }
        for entry in generatedEntries {
            if Task.isCancelled { break }
            guard let raw = entry.generatedBlockType,
                  let blockType = CollectionGeneratedBlockType(rawValue: raw) else { continue }
            let block = await CollectionGeneratedBlocks.resolve(
                type: blockType, documents: batch.collectionDocuments,
                dataSource: AssembledBlockDataSource(assembly: self, batch: batch), locale: locale)
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
    /// Cooperative cancellation: a cancelled task stops the loop early and returns
    /// the items resolved so far (partial-safe — every returned item is complete); the
    /// throwing entry points convert the truncation into a thrown `CancellationError`.
    ///
    /// - Parameter dropsUntitledHeadings: Whether to leave out each heading saved with no text, lifting the named
    ///   headings under it a level (`CollectionOutline.exportLevels`) — `true` for an export, `false` for the preview,
    ///   which shows the heading as "Untitled section" (#1465, decision D4). The section cascades run over the whole
    ///   outline either way, so the documents under a dropped heading keep its Section defaults.
    private func resolveItems(from refs: [Entry], batch: BatchContext,
                              dropsUntitledHeadings: Bool) async -> [CollectionExportItem] {
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
        // #1465: the levels the items carry — an untitled heading's is nil in an export, which leaves it out.
        let emittedLevels: [Int?] = dropsUntitledHeadings
            ? CollectionOutline.exportLevels(structuralRefs, untitled: ordered.map {
                $0.kind == .heading
                    && ($0.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            })
            : CollectionOutline.resolvedDepths(structuralRefs).map(Optional.init)
        // Phase 5 override cascades: one generic outline walk per field, heading values
        // only (a document's own override never leaks into the section defaults).
        func headingValues<Value>(_ value: (Entry) -> Value?) -> [Value?] {
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
            // A heading the export leaves out (#1465): its Section defaults are already in the cascades above.
            guard let level = emittedLevels[i] else { continue }
            let section = SectionOverrides(
                bodyDepth: sectionDepths[i],
                applyHighlights: secHighlights[i],
                includeNotes: secNotes[i],
                includeSourceNote: secSourceNote[i],
                includeFootnotes: secFootnotes[i],
                summaryPromptId: secPrompt[i],
                includeRelatedDocuments: secRelated[i])
            if let item = await resolveEntry(ref, section: section,
                                             headingLevel: max(level, 1),
                                             batch: batch) {
                items.append(item)
            }
        }
        return items
    }

    // MARK: - Entry

    /// How a resolved document's research-note texts are determined.
    enum NoteResolution: Sendable {
        /// Static entries: the entry's own selection — `selectedNoteIds`, falling back to
        /// the legacy single `researchNoteId` link.
        case entrySelection(selectedNoteIds: [UUID], legacyNoteId: UUID?)
        /// Synthetic smart-collection entries carry no selection: every research note
        /// attached to the document travels (the pre-unification smart Zotero behavior).
        case allDocumentNotes
    }

    /// Value snapshot of one entry — real (a collection entry's values) or synthetic (smart search
    /// result) — fed to the shared per-entry pipeline.
    public struct Entry: Sendable {
        /// The entry kind (document/heading/prose/excerpt/generated/unrecognized).
        public let kind: CollectionEntryKind
        /// The FRUS document identifier; empty for heading/prose entries.
        public let documentId: String
        /// The containing volume identifier; empty for heading/prose entries.
        public let volumeId: String
        /// Position within the collection (ascending).
        public let sortOrder: Int
        /// Heading title text (`.heading` entries), or an excerpt's frozen passage.
        public let text: String?
        /// Heading nesting level (`.heading` entries only; raw model value — clamped by
        /// `CollectionOutline` during resolution, never trusted directly).
        public let level: Int
        /// A prose block's paragraphs (`.prose` entries only), decoded by the host from the
        /// block's rich text when it snapshots the entry.
        public let proseParagraphs: [[ProseFormattedSpan]]?
        /// The entry's own body-depth override raw value, if any.
        public let bodyDepthOverride: String?
        /// The entry's per-document title override (M3, D4; document entries only; `nil`
        /// on smart refs). Drives both the ToC label and the export heading.
        public let titleOverride: String?
        /// Per-entry headnote opt-in (`nil` = Default = inherit the collection default). Resolved
        /// against `CollectionExportOptions.includeHeadnoteDefault` at pack time (Composer redesign).
        public let includeHeadnote: Bool?
        /// The chosen summary's id for the headnote; `nil` = fallback pick.
        public let headnoteSummaryId: UUID?
        /// The source highlight's colour raw value (`.excerpt` entries only, Phase 5).
        public let excerptColorTag: String?
        /// The apparatus block type raw value (`.generated` entries only, Phase 6).
        public let generatedBlockType: String?
        /// Per-entry highlight override (Phase 5; `nil` = inherit; section default on
        /// headings).
        public let applyHighlightsOverride: Bool?
        /// Per-entry research-notes override (Phase 5; `nil` = inherit).
        public let includeNotesOverride: Bool?
        /// Per-entry source-note override (Phase 5; `nil` = inherit).
        public let includeSourceNoteOverride: Bool?
        /// Per-entry footnote override (Phase 5; `nil` = inherit).
        public let includeFootnotesOverride: Bool?
        /// Per-entry summary-prompt override (Phase 5; `nil` = inherit).
        public let summaryPromptIdOverride: UUID?
        /// The highlights to include when highlights apply (A8; empty = all).
        public let selectedHighlightIds: [UUID]
        /// Per-entry related-documents opt-in (A10; `nil` = inherit, ultimately off).
        public let includeRelatedDocuments: Bool?
        /// How research-note texts are resolved for this entry.
        let noteResolution: NoteResolution

        /// Snapshots a collection entry from its values. A prose block's paragraphs are the host's,
        /// decoded from the entry's rich text (or its plain text) as the app's exporters read it;
        /// they are ignored on every other kind.
        ///
        /// - Parameters:
        ///   - entry: The entry's values, as the research data export records them.
        ///   - proseParagraphs: A `.prose` entry's paragraphs; `nil` on every other kind.
        public init(_ entry: CollectionEntryExport, proseParagraphs: [[ProseFormattedSpan]]?) {
            let kind = entry.entryKind
            self.kind = kind
            documentId = entry.documentId
            volumeId = entry.volumeId
            sortOrder = entry.sortOrder
            text = entry.text
            level = entry.level ?? 1
            self.proseParagraphs = kind == .prose ? proseParagraphs : nil
            bodyDepthOverride = entry.bodyDepthOverride
            titleOverride = entry.titleOverride
            includeHeadnote = entry.includeHeadnote
            headnoteSummaryId = entry.headnoteSummaryId
            excerptColorTag = kind == .excerpt ? entry.excerptColorTag : nil
            generatedBlockType = kind == .generated ? entry.generatedBlockType : nil
            applyHighlightsOverride = entry.applyHighlightsOverride
            includeNotesOverride = entry.includeNotesOverride
            includeSourceNoteOverride = entry.includeSourceNoteOverride
            includeFootnotesOverride = entry.includeFootnotesOverride
            summaryPromptIdOverride = entry.summaryPromptIdOverride
            selectedHighlightIds = entry.selectedHighlightIds ?? []
            includeRelatedDocuments = entry.includeRelatedDocuments
            noteResolution = .entrySelection(selectedNoteIds: entry.selectedNoteIds,
                                             legacyNoteId: entry.researchNoteId)
        }

        /// Synthesizes an entry for one smart-collection search result: always a
        /// `.document`, with no overrides and all-document note resolution — smart
        /// collections keep collection-level behavior by construction.
        public init(_ ref: SmartCollectionDocumentRef) {
            kind = .document
            documentId = ref.documentId
            volumeId = ref.volumeId
            sortOrder = ref.sortOrder
            text = nil
            level = 1
            proseParagraphs = nil
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
    /// default` — computed only in this assembly (Authoring Phase 5).
    struct SectionOverrides {
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
    /// flags, the membership and the printed numbers. The notes are the assembly's.
    struct BatchContext {
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
        /// The collection's document membership — `(volumeId, documentId)` in collection
        /// order, deduplicated — the A10 universe for the related-documents line (only
        /// cross-reference targets in this list ever appear on it).
        let collectionDocuments: [(volumeId: String, documentId: String)]
        /// The printed document numbers the index stores (`document_cache.document_number`),
        /// keyed `"volumeId/documentId"`, for every document this batch can cite — its document
        /// and excerpt entries and the whole membership (#1406). Read through
        /// `CitableDocumentNumber.resolve`, never directly.
        let documentNumbers: [String: String]
    }

    /// The ordered, deduplicated `(volumeId, documentId)` list of a batch's document
    /// entries — the related-documents membership for smart resolves, where the passed
    /// refs ARE the true membership. Static resolves use `collectionDocumentRefs()`
    /// instead: their refs may be a capped preview prefix of the real membership.
    private static func documentRefs(in refs: [Entry]) -> [(volumeId: String, documentId: String)] {
        var seen = Set<String>()
        return refs.sorted { $0.sortOrder < $1.sortOrder }
            .filter { $0.kind == .document && !$0.volumeId.isEmpty && !$0.documentId.isEmpty }
            .compactMap { ref in
                seen.insert("\(ref.volumeId)/\(ref.documentId)").inserted
                    ? (ref.volumeId, ref.documentId) : nil
            }
    }

    /// The ordered, deduplicated document membership of the collection — the
    /// related-documents membership for static resolves (full, capped-preview, and
    /// single-entry `resolveItem`), so every static pass agrees on the A10 universe
    /// regardless of how its entry list was capped.
    private func collectionDocumentRefs() -> [(volumeId: String, documentId: String)] {
        var seen = Set<String>()
        return collection.entries
            .sorted { $0.sortOrder < $1.sortOrder }
            .filter { $0.entryKind == .document && !$0.volumeId.isEmpty && !$0.documentId.isEmpty }
            .compactMap { entry in
                seen.insert("\(entry.volumeId)/\(entry.documentId)").inserted
                    ? (entry.volumeId, entry.documentId) : nil
            }
    }

    /// Pre-loads everything the per-entry pipeline needs for a batch of refs: body texts
    /// (the index's document cache first, the AST's extraction as the XML fallback), render
    /// models (converted from the data source's AST — see the type doc), editorial-note flags,
    /// and the manifest map.
    ///
    /// Cooperative cancellation: the per-document load loop — where each miss costs
    /// a SAX parse — stops early when the task is cancelled. The partially loaded context
    /// is safe (unloaded documents would merely resolve with empty bodies), and the
    /// throwing entry points surface `CancellationError` before any such result escapes.
    ///
    /// Figure images (#1516): each render model names its figures' images by this document's
    /// volume, so the exporters find them. Nothing is fetched here; an export that
    /// prints images asks for the ones it lacks once its items are resolved
    /// (`fetchAbsentFigureImages(printedBy:)`).
    private func loadBatchContext(
        for refs: [Entry],
        collectionDocuments: [(volumeId: String, documentId: String)]
    ) async -> BatchContext {
        let manifest = source.manifestEntries
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

            // The index's document cache (fast) for the plain body text.
            if bodyTexts[key] == nil, let pipeline = source.indexingPipeline,
               let text = try? await pipeline.fetchDocumentBodyText(
                   volumeId: ref.volumeId, documentId: ref.documentId) {
                bodyTexts[key] = text
            }

            // One AST per document — the data source's cache hit, else a single parse — feeds both
            // the structured render model and the XML body-text fallback.
            if renderModels[key] == nil,
               let ast = await source.documentAST(volumeId: ref.volumeId, documentId: ref.documentId) {
                var converter = ASTToRenderNodeConverter(volumeId: ref.volumeId)
                renderModels[key] = converter.convert(ast)
                if bodyTexts[key] == nil {
                    bodyTexts[key] = IndexingPipeline.extractBodyText(from: ast.nodes)
                }
            }
        }

        // Editorial-note flags from the index, so collection-level Zotero items
        // carry the same "Editorial note" extra line as document-level exports.
        let editorialNoteFlags = await ZoteroJSONExporter.editorialNoteFlags(
            volumeIds: Set(docRefs.map(\.volumeId)), pipeline: source.indexingPipeline)

        // The printed numbers every citation in this batch names (#1406): the document entries,
        // the excerpts (their source line cites the excerpted document) and the membership (the
        // "See also:" line cites its members). One batched read; an unindexed document is absent
        // and falls back to its id where the id spells a number.
        var citable = refs
            .filter { ($0.kind == .document || $0.kind == .excerpt)
                && !$0.volumeId.isEmpty && !$0.documentId.isEmpty }
            .map { (volumeId: $0.volumeId, documentId: $0.documentId) }
        citable += collectionDocuments
        let documentNumbers = (try? await source.indexingPipeline?
            .documentNumbersByKey(citable)) ?? [:]

        return BatchContext(
            options: CollectionExportOptions(composing: collection),
            manifestMap: manifestMap,
            formatter: HistoryAtStateCitationFormatter(),
            bodyTexts: bodyTexts,
            renderModels: renderModels,
            editorialNoteFlags: editorialNoteFlags,
            collectionDefaultBodyDepth: collection.defaultBodyDepth ?? CollectionBodyDepth.full.rawValue,
            collectionDocuments: collectionDocuments,
            documentNumbers: documentNumbers
        )
    }

    // MARK: - Per-entry pipeline

    /// Resolves one entry into its export item — the shared per-entry body used by both
    /// the batch loop and the incremental `resolveItem` API. A heading passes through as a
    /// structural item, and a prose entry as the spans the host decoded; document entries are
    /// fully resolved (citation, body, notes, highlights, source note, related documents, Zotero
    /// item) per the override cascade: entry override → `section` value → collection default.
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
        _ ref: Entry,
        section: SectionOverrides,
        headingLevel: Int,
        batch: BatchContext
    ) async -> CollectionExportItem? {
        switch ref.kind {
        case .heading:
            return .heading(ref.text ?? "", level: headingLevel)
        case .prose:
            return .prose(ref.proseParagraphs ?? [])
        case .excerpt:
            return excerptItem(for: ref, batch: batch)
        case .generated:
            // Generated apparatus (Phase 6): resolve the block from the collection's
            // resolved document membership via the single block-resolution seam,
            // fed by the assembled data source (index, rollup, archival indexes, store).
            // Read-only in both purposes — preview and export render identical blocks.
            // An unknown block type (a newer build's vocabulary) is skipped, mirroring
            // the `.unrecognized` kind guard: degraded, never corrupted.
            guard let raw = ref.generatedBlockType,
                  let blockType = CollectionGeneratedBlockType(rawValue: raw) else { return nil }
            return await .generated(CollectionGeneratedBlocks.resolve(
                type: blockType, documents: batch.collectionDocuments,
                dataSource: AssembledBlockDataSource(assembly: self, batch: batch), locale: locale))
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
        let (header, dateline) = Self.renderModelHeadAndDateline(renderModel)

        // The volume's printed number (#1406) — `373a`, `ETA–1` — not the id's integer, which
        // `d373a` does not have.
        let docNum = CitableDocumentNumber.resolve(printed: batch.documentNumbers[key],
                                                   documentId: ref.documentId)
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
                    notes.first { $0.id == nid }?.bodyText
                }.filter { !$0.isEmpty }
            } else if let legacyNote = legacyNoteId.flatMap({ nid in
                notes.first { $0.id == nid }
            }) {
                // Un-migrated legacy single-note link: honored only while no multi-note
                // selection exists (write paths migrate legacy → array on first edit).
                resolvedNoteTexts = legacyNote.bodyText.isEmpty ? [] : [legacyNote.bodyText]
            } else {
                // D5: an empty selection with no legacy link means **all** of the
                // document's notes (mirroring `selectedHighlightIds` and `.allDocumentNotes`),
                // so future notes auto-flow in and enabling notes on an untouched entry
                // actually exports them. Populated only on the first inspector deselect.
                resolvedNoteTexts = notes
                    .filter { $0.documentId == ref.documentId && $0.volumeId == ref.volumeId }
                    .map(\.bodyText)
                    .filter { !$0.isEmpty }
            }
        case .allDocumentNotes:
            // Smart entries: every research note on the document travels, matching what
            // the pre-unification smart Zotero items carried.
            resolvedNoteTexts = notes
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
        // selectedHighlightIds filter the set (A8): empty means all. A highlight's colour reads
        // its stored tag as `DocumentHighlight.color` does: yellow for a tag this build does not know.
        let resolvedHighlights: [ExportHighlight]
        if (highlightsOverride ?? batch.options.applyHighlights) && effectiveDepth == .full {
            resolvedHighlights = source.highlights(volumeId: ref.volumeId, documentId: ref.documentId)
                .filter { ref.selectedHighlightIds.isEmpty
                    || ref.selectedHighlightIds.contains($0.id) }
                .map { ExportHighlight(startOffset: $0.startOffset,
                                      endOffset:   $0.endOffset,
                                      color:       HighlightColor(rawValue: $0.colorTag) ?? .yellow) }
        } else {
            resolvedHighlights = []
        }

        // Source note — resolved whenever the cascaded include-source-note flag is on
        // (Authoring Phase 5; the collection default previously gated on the legacy
        // tri-state's `.sourceNoteOnly`, which the nil-pair derivation reproduces).
        let resolvedSourceNote: String?
        if sourceNoteOverride ?? batch.options.includeSourceNote {
            resolvedSourceNote = try? await source.indexingPipeline?
                .fetchDocumentSourceNote(volumeId: ref.volumeId,
                                         documentId: ref.documentId)
        } else {
            resolvedSourceNote = nil
        }

        // Headnote (Authoring Phase 5): a stored summary rendered above the
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
        // cascade turns it on; empty when the host keeps no cross-references (e.g. tests).
        let relatedCitations: [String]
        if ref.includeRelatedDocuments ?? section.includeRelatedDocuments ?? false,
           let outbound = await source.crossReferenceTargets(volumeId: ref.volumeId,
                                                             documentId: ref.documentId) {
            let targets = Self.relatedDocumentTargets(
                outboundTargets: outbound,
                selfVolumeId: ref.volumeId, selfDocumentId: ref.documentId,
                collectionDocuments: batch.collectionDocuments)
            relatedCitations = targets.map {
                shortCitation(volumeId: $0.volumeId, documentId: $0.documentId,
                              printedNumber: batch.documentNumbers["\($0.volumeId)/\($0.documentId)"],
                              batch: batch)
            }
        } else {
            relatedCitations = []
        }

        // Zotero JSON item (for ExportFormat.zoteroJSON)
        let zoteroItem: ZoteroJSONExporter.Item?
        if let volMeta {
            let year = FRUSVolumeMetadata.firstYear(in: volMeta.publicationDate).map(String.init) ?? "n.d."
            let tags = source.zoteroTags(volumeId: ref.volumeId, documentId: ref.documentId)
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

    /// The A10 pure core: of a document's outbound cross-reference
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
    public nonisolated static func relatedDocumentTargets(
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
    private func excerptItem(for ref: Entry, batch: BatchContext) -> CollectionExportItem? {
        guard let passage = ref.text, !passage.isEmpty else { return nil }
        let citation: String
        if !ref.volumeId.isEmpty, !ref.documentId.isEmpty {
            citation = shortCitation(volumeId: ref.volumeId, documentId: ref.documentId,
                                     printedNumber: batch.documentNumbers[
                                        "\(ref.volumeId)/\(ref.documentId)"],
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
    ///
    /// `printedNumber` is what the index stores for the document (`batch.documentNumbers`, or the
    /// block's own `documentNumbers(for:)` read), resolved through `CitableDocumentNumber` (#1406).
    private func shortCitation(volumeId: String, documentId: String, printedNumber: String?,
                               batch: BatchContext) -> String {
        let docNum = CitableDocumentNumber.resolve(printed: printedNumber, documentId: documentId)
        let docMeta = FRUSDocumentMetadata(
            documentId: documentId, documentNumber: docNum,
            header: "", dateline: nil)
        return batch.manifestMap[volumeId]
            .map { batch.formatter.format(document: docMeta, volume: FRUSVolumeMetadata($0)) }
            ?? "\(volumeId)/\(documentId)"
    }

    // MARK: - Assembled generated-block data source (Phase 6)

    /// The `CollectionGeneratedBlockDataSource` every resolve hands the block resolvers: citations
    /// through the batch's own manifest/formatter path, the batch's printed numbers, and the data
    /// source's index (`document_dates`, `document_sources`), people rollup (`PersonMentionStore`),
    /// archival indexes (`ArchivalResolver`) and tags — all read-only, so blocks answer identically
    /// for `.preview` and `.export`. Every accessor degrades to empty when its backing service is
    /// unavailable (e.g. tests without a pipeline), which the blocks render as their localized
    /// "nothing to list" row.
    private struct AssembledBlockDataSource: CollectionGeneratedBlockDataSource {
        /// The owning assembly — supplies the citation path, the notes and the data source.
        let assembly: CollectionContentAssembly
        /// The batch whose manifest map / formatter / numbers serve citations.
        let batch: BatchContext

        func citation(volumeId: String, documentId: String, printedNumber: String?) -> String {
            // The single citation path: header-independent (the formatter never reads
            // header/dateline), so block rows match the document items' citations and
            // capped previews match exports by construction.
            assembly.shortCitation(volumeId: volumeId, documentId: documentId,
                                   printedNumber: printedNumber, batch: batch)
        }

        /// Read from the batch rather than the index a second time: both block call sites resolve
        /// over `batch.collectionDocuments`, whose numbers `loadBatchContext` already fetched.
        func documentNumbers(
            for documents: [(volumeId: String, documentId: String)]
        ) async -> [String: String] {
            let requested = Set(documents.map { "\($0.volumeId)/\($0.documentId)" })
            return batch.documentNumbers.filter { requested.contains($0.key) }
        }

        func dateMetadata(
            for documents: [(volumeId: String, documentId: String)]
        ) async -> [String: DocumentDateMetadata] {
            guard let pipeline = assembly.source.indexingPipeline else { return [:] }
            return (try? await pipeline.dateMetadataByDocumentKey(documents)) ?? [:]
        }

        func documentSources(
            for documents: [(volumeId: String, documentId: String)]
        ) async -> [CollectionGeneratedBlocks.SourceRecord] {
            guard let pipeline = assembly.source.indexingPipeline else { return [] }
            let rows = (try? await pipeline.documentSourcesByKey(documents)) ?? [:]
            return rows.values.map {
                CollectionGeneratedBlocks.SourceRecord(
                    volumeId: $0.volumeId, documentId: $0.documentId,
                    repository: $0.repository, recordGroup: $0.recordGroup,
                    lotFile: $0.lotFile, seriesName: $0.seriesName, rawText: $0.rawText,
                    citationEra: $0.citationEra)
            }
        }

        // #372/N-5: a document citation resolves through its LOT and nothing else —
        // `documentResolution` does not take a record group, so this block can no longer
        // answer "740.00119 (Potsdam)/5-2446" with a link to the whole of RG 59. The record
        // group still appears in the row's label; only the hyperlink is withheld. The lot half
        // is central-files first, volume-sources second, over the indexes the host passed in.
        // See `ArchivalResolver`.
        //
        // `recordGroup` stays in the signature because `CollectionGeneratedBlocks` groups and
        // labels by it — it is simply not part of the resolution any more.
        func archivalResolution(recordGroup: String?, lotFile: String?)
            -> CollectionGeneratedBlocks.ArchivalLink? {
            ArchivalResolver.documentResolution(lotFile: lotFile, indexes: assembly.source.archivalIndexes)
                .map { CollectionGeneratedBlocks.ArchivalLink(title: $0.title,
                                                              urlString: $0.catalogURL) }
        }

        func personMentions(
            for documents: [(volumeId: String, documentId: String)]
        ) async -> [CollectionGeneratedBlocks.PersonMention] {
            guard let store = assembly.source.personMentionStore else { return [] }
            let mentions = (try? await store.rollupMentions(forDocuments: documents)) ?? []
            return mentions.map {
                CollectionGeneratedBlocks.PersonMention(
                    identityKey: "r\($0.rollupId)", name: $0.canonicalName,
                    description: $0.description, role: $0.role,
                    volumeId: $0.volumeId, documentId: $0.documentId)
            }
        }

        func tagRecords() async -> [CollectionGeneratedBlocks.TagRecord] {
            let tags = assembly.source.userTags()
            guard !tags.isEmpty else { return [] }
            let assignments = assembly.source.tagAssignments()
                .map { (volumeId: $0.volumeId, documentId: $0.documentId, tagId: $0.tagId) }
            // The assembly already carries every research note — the same pool entry
            // note-links resolve against — so no second read is needed.
            let noteTags = assembly.notes
                .map { (volumeId: $0.volumeId, documentId: $0.documentId, tagIds: $0.userTagIds) }
            return tags.map { tag in
                let refs = CollectionGeneratedBlocks.tagDocumentRefs(
                    tagId: tag.id, noteTags: noteTags, assignments: assignments)
                return CollectionGeneratedBlocks.TagRecord(
                    name: tag.name,
                    documents: refs.map { (volumeId: $0.volumeId, documentId: $0.documentId) })
            }
        }
    }

    /// Resolves the stored summary text for a headnote: the explicitly chosen
    /// `summaryId` when set (and non-empty), else the document's summary for
    /// `preferredPromptId` (the collection's prompt), else any non-empty stored summary.
    /// Returns `nil` when nothing is stored — headnote resolution **never** generates
    /// (renderers emit a placeholder note instead; see the type doc).
    private func headnoteText(
        volumeId: String,
        documentId: String,
        summaryId: UUID?,
        preferredPromptId: UUID?
    ) -> (text: String, authorship: SummaryAuthorship)? {
        if let sid = summaryId {
            if let chosen = source.summary(id: sid), !chosen.responseText.isEmpty {
                return (chosen.responseText, chosen.authorship ?? .aiGenerated)
            }
            // The chosen summary no longer exists (deleted / not yet synced): fall
            // through to the stored-summary fallback rather than silently dropping
            // the requested headnote.
        }
        // Headnote drafts are out of the fallback (`headnoteSummaries` leaves them out): a draft is
        // a per-entry private summary reachable ONLY via its owning entry's explicit
        // `headnoteSummaryId` (handled above). Without this, a second entry for the same document
        // with no headnote of its own could fall back onto the first entry's private draft.
        let stored = source.headnoteSummaries(volumeId: volumeId, documentId: documentId)
            .filter { !$0.responseText.isEmpty }
        if let pid = preferredPromptId, let preferred = stored.first(where: { $0.promptId == pid }) {
            return (preferred.responseText, preferred.authorship ?? .aiGenerated)
        }
        return stored.first.map { ($0.responseText, $0.authorship ?? .aiGenerated) }
    }

    // MARK: - Summary phase

    /// Applies the summary phase to resolved items: for every document whose effective
    /// body depth is `.summaryOnly`, attaches summary text per the purpose — `.export`
    /// asks the data source to generate on demand (pre-extraction behavior, error-for-error),
    /// `.preview` attaches stored summaries only and leaves the rest `nil` for placeholder
    /// rendering.
    ///
    /// Documents are grouped by their **effective prompt** (the cascaded
    /// `summaryPromptIdOverride`, else the collection's `summaryPromptId` — Phase 5), so
    /// one collection can mix prompts; a collection with no overrides forms exactly one
    /// group under the collection prompt, reproducing the prior behavior including the
    /// `summaryPromptMissing` error when none is configured.
    public func applySummaryPhase(
        to items: [CollectionExportItem],
        purpose: Purpose
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
                let generated = try await source.generateSummaries(for: docs, promptId: promptId,
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

    /// Returns the stored summary text for a document under `promptId`, or
    /// `nil` when none exists (or it is empty). Never generates.
    private func storedSummary(volumeId: String, documentId: String, promptId: UUID) -> String? {
        guard let existing = source.summary(volumeId: volumeId, documentId: documentId, promptId: promptId),
              !existing.responseText.isEmpty else { return nil }
        return existing.responseText
    }

    // MARK: - Render Model Extraction Helpers

    /// Extracts the first heading and first dateline from a render model's body nodes.
    private static func renderModelHeadAndDateline(_ model: FRUSDocumentRenderModel?) -> (header: String, dateline: String?) {
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
    ///
    /// `nonisolated static` since #1371 so a test can pin the list branch below; it reads no
    /// assembly state.
    public nonisolated static func renderNodePlainText(_ nodes: [FRUSRenderNode]) -> String {
        nodes.map { renderNodePlainText($0) }.joined()
    }

    /// Recursively extracts plain text from a single `FRUSRenderNode`.
    public nonisolated static func renderNodePlainText(_ node: FRUSRenderNode) -> String {
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
             .crossRefLink(_, _, _, _, let c):
            return renderNodePlainText(c)
        case .formulaText(let s):
            return s
        case .lineBreak, .elementSpace:
            // `.elementSpace` (#1516 fold-in): the space between two inline elements, so an
            // exported dateline reads "Washington, February 28, 1861" as the reader draws it.
            return " "
        case .footnoteMarker(_, _, _, let label):
            // #985: an unnumbered note contributes nothing to plain text. This walk reaches
            // document heads and datelines, where a head-nested source note previously emitted a
            // fabricated "[1]" into the exported title.
            return label.map { "[\($0)]" } ?? ""
        case .listBlock(_, let heading, let items, let trailing):
            // #1371: the printed text in order — heading, then each item after its label and any
            // other list child — as the reader draws it. Plain text, so no offset space to keep.
            // Defensive today: no document head or dateline in the corpus holds a list outside a
            // footnote (measured 0 at `550a8c5c5`), and a footnote's body is not walked here.
            let lead = { (parts: [ListLead]) -> [String] in
                parts.map { part in
                    switch part {
                    case .label(let c), .other(let c): return renderNodePlainText(c)
                    }
                }
            }
            let pieces = [heading.map { renderNodePlainText($0) } ?? ""]
                + items.flatMap { lead($0.lead) + [renderNodePlainText($0.children)] }
                + lead(trailing)
            return pieces.filter { !$0.isEmpty }.joined(separator: " ")
        case .tableBlock(let caption, let rows):
            let body = rows.map { row in row.map { renderNodePlainText($0.children) }.joined(separator: " | ") }
                .joined(separator: "\n")
            // #1495: the caption the volume printed, on a line of its own above the rows, as the
            // reader draws it. Defensive, as the list branch is: no document head or dateline in
            // the corpus holds a table outside a footnote (measured 0 at `550a8c5c5`).
            guard let caption else { return body }
            return renderNodePlainText(caption) + "\n" + body
        case .footnoteBody, .pageBreak, .figureBlock:
            return ""
        }
    }
}
